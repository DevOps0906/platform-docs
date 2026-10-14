# 02 아키텍처: 로컬뉴스 클라우드(가칭)

작성일 2026-10-15. 신규 기획(원본 프로젝트·리뷰 없음). 공용 모듈은 `docs/products/_platform-core/SHARED_MODULES.md`(아래 SM)와 `CORE_SPEC.md`(아래 CS)를 참조만 하고, 화이트라벨은 `Multi-tenant_Theming/`(아래 MT)을 참조만 한다. 기능 ID는 `01_PRD.md` 3장, 표·RPC 이름은 `05_DATA_MODEL.md`가 정본이며 이 문서의 RPC 이름은 05장 확정 시 맞춘다. 모듈러 기준 이름(`news.*`)으로 적고, 모놀리스(1차 배포)에서는 같은 이름이 `public.*`에 있다(`docs/products/_platform-core/DB_CONVENTIONS.md` 12장).

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router(`src/proxy.ts`), React, TypeScript strict, Tailwind CSS v4(4.x 고정, `@import "tailwindcss"`, `@theme`, `@custom-variant dark`. `tailwind.config.js`·v3 문법 금지), shadcn/ui(Tailwind CSS v4 지원 버전) | Next 16.2.x, React 19.2 | `Multi-tenant_Theming/README.md:229`, `docs/products/_platform-core/DOC_TEMPLATE.md:133` |
| 앱 수 | `apps/web` 1개에 Host로 나뉘는 라우트 그룹 4개(2절). 독자 사이트·편집국·운영·마케팅이 같은 빌드 | - | 제안. 이유: 테넌트 해석·인증 모듈·토큰을 한 곳에서 관리, Vercel 프로젝트 1개에 와일드카드·커스텀 도메인을 모은다 |
| 렌더링 | 독자 사이트: ISR + 캐시 태그(`revalidateTag`), 편집국·운영: 동적 렌더. 정확한 Next 16.2 캐시 API(`"use cache"`, `cacheTag`, `unstable_cache`)는 구현 시 문서로 확인 | Next 16.2.x | `Multi-tenant_Theming/03_CODE_STRUCTURE.md:102` |
| 에디터 | 블록 에디터(Tiptap/ProseMirror 계열, 문단·소제목·사진·인용·표·임베드). 저장 형식은 블록 JSON + 서버 sanitize HTML | 2.x 고정(제안) | 01장 NW-F-010. 공용 `cms` 0800 블록 에디터가 채택되면 교체(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:65-81`) |
| TS 워커 | Node 20 + `packages/core-jobs` 워커 루프. 큐 6개(4절) | Node 20 LTS | SM 16장 |
| DB/인증/Storage | Supabase(PostgreSQL 15, Auth, Storage, Realtime). **단독 프로젝트 모놀리스**(`public` 스키마) | 15 | README 5절, `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:1-30` |
| 검색 | `pg_trgm` + `tsvector('simple')`. pg_bigm은 Supabase 지원 미확인. 외부 검색(Meilisearch/Typesense)은 P2(D-7) | - | 브리프 7절, 6절 위험 #7 |
| 화이트라벨 | `packages/core-tenancy`(제안 공용 패키지) + 코어 확장 `0011_core_tenant_theming.sql`의 모놀리스 변환본(`0002_tenant_theming.sql`) | - | `Multi-tenant_Theming/README.md:81-109`, `:128-163` |
| 결제 | Toss Payments. 플랫폼 구독(신문사 B2B)은 플랫폼 가맹, 독자 후원·멤버십은 **신문사 자기 가맹 키**(`core.encrypted_credentials`) | API v1 | 확정 결정 4, 01장 NW-F-035, D-4 |
| 메일 | 트랜잭션·뉴스레터 발송 제공자 1곳(Resend 또는 Amazon SES, 제안). Supabase Auth 메일도 같은 제공자의 SMTP | - | 제안. 이유: 발신 도메인 하나로 SPF·DKIM·DMARC 관리(`Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:63-71`) |
| 웹 푸시 | Web Push(VAPID) + 서비스 워커(독자 사이트, 테넌트 호스트별 구독) | - | 01장 NW-F-038 |
| 이미지 | 업로드 시 워커가 `sharp`로 폭 320/640/960/1280 WebP·JPEG 파생본을 만들어 Storage 공개 버킷 + CDN으로 제공(요청 시 변환을 쓰지 않음) | - | 제안. 이유: 요청 시 변환 과금(Vercel·Supabase 이미지 변환)이 속보 트래픽에 비례해 늘어남. 변환 기능 요금은 미확인 |
| AI 서비스 | FastAPI(Python) `apps/api`(공용 ai-service). 제품 확장은 `app/ai/products/news/`만 | Python 3.12(제안) | 확정 결정 13, `docs/products/_platform-core/AI_ARCHITECTURE.md:132-160` |
| AI 오케스트레이션 | LangChain, LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`) | 구현 시 확인 | `docs/products/_platform-core/AI_ARCHITECTURE.md:83`, `:114` |
| LLM | FastAPI 라우터: 상용 `anthropic`, `openai`, `google`, `openrouter` + 오픈소스 `oss-llm`(vLLM). 기능별 체인은 5.1절 | `core.ai_model_prices` 행 | 확정 결정 17, `docs/products/_platform-core/AI_ARCHITECTURE.md:73-92` |
| RAG | pgvector(HNSW, cosine, 1024차원). 신문사별 컬렉션 `news-archive`(게시 기사), `news-policy`(사내 규정) 임베딩은 `oss-embed` 고정 | pgvector 0.8 이상 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107` |
| 채팅 운영 | 공용 자체 호스팅 Dify 1개, 제품 앱 `news-assistant`(Chatflow) | 설치 버전 문서로 확인 | 확정 결정 14 |
| 음성 | `packages/core-voice`(ElevenLabs TS SDK + 공용 오픈소스 음성 서버) | 구현 시 확인 | 확정 결정 16, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48` |
| 3D | three.js + React Three Fiber + drei. **플랫폼 마케팅 랜딩에만**(독자 사이트·편집국 미적용, D-11) | React 19 호환 버전 | `docs/products/_design-guide/HERO_3D.md`, 브리프 7절 |
| 배포 | Vercel(web), Railway(TS 워커, FastAPI), Supabase(모놀리스 단독 프로젝트), 공용 Dify·GPU·음성 서버 | - | 7절 |

확정 결정 6(TS 오케스트레이션 + Python AI)을 따른다: 잡의 소유(큐, 재시도, 저장)는 TS 워커, LLM 호출은 FastAPI 그래프가 한다. web과 워커에는 LLM 키가 없다.

## 2. 모듈 경계

```
apps/web/                                  Next.js (Vercel 프로젝트 1개)
  src/proxy.ts                             Host 판별 → 그룹 재작성(10.1절) + 라우트 보호. x-tenant-*, x-host-kind 입력 헤더는 지우고 다시 쓴다
  src/app/(reader)/_t/[host]/              독자 사이트(테넌트 호스트, ISR): 홈(템플릿 A/B/C), news/[id]/[slug], section/[slug], region/[code],
                                           tag/[slug], reporter/[id], search, most-read, live/[id], print/[edition], life/(events|obituaries|people),
                                           tips/new, corrections/new, membership, newsletter/(confirm|unsubscribe), login, account,
                                           legal/(youth|privacy|ethics|corrections), rss.xml, sitemap.xml, sitemap-news.xml, robots.txt, llms.txt
  src/app/(newsroom)/                      편집국 콘솔(newsroom.<플랫폼 도메인>): dashboard, articles, desk, home-editor, media, print, sections,
                                           staff, readers, newsletter, ads, listings, notices, life-events, tips, comments, corrections, compliance,
                                           reports, import, assistant, settings/(profile|branding|domains|billing|payments|ai), apply(개설 신청)
  src/app/(ops)/                           운영 콘솔(ops.<플랫폼 도메인>, 제안): 개설 심사, 신문사, 플랜, 도메인, 잡·장애, 감사
  src/app/(marketing)/                     플랫폼 마케팅 랜딩(루트 도메인). 3D 히어로는 src/features/hero3d/ 에서만 import
  src/app/(auth)/login/                    편집국·운영 로그인(독자 로그인은 (reader)/_t/[host]/login)
  src/app/auth/(callback|confirm)/         OAuth·매직 링크 완료 → finishLogin(호스트 종류별 분기, 9.3절)
  src/app/api/r/                           독자 API(테넌트 호스트만, 04장 2.1절)
  src/app/api/newsroom/                    편집국 API(newsroom 호스트만, 04장 2.2절)
  src/app/api/ops/                         운영 API(ops 호스트만)
  src/app/api/(ai|voice)/                  AI·음성 게이트(newsroom 호스트만. 독자 Q&A는 P2)
  src/app/api/tenant/                      Theming Route Handler(core-tenancy, newsroom 호스트)
  src/app/api/webhooks/                    toss/[org_id](신문사 가맹), toss/platform, email
  src/app/api/internal/                    revalidate, ai-token, ai-settle, domains/verify(워커 키·서명)
  src/app/api/dev/login/                   Stage A(로컬 전용)
  src/lib/auth/                            인증 단계 모듈(9절). 단계 분기는 여기·로그인 화면·auth/·api/dev/login 에만
  src/lib/tenancy/                         core-tenancy 어댑터(앱 id news, 루트 도메인, 서체 레지스트리, 10절)
  src/lib/cache/tags.ts                    캐시 태그 정본(10.3절)
  src/modules/newsroom-cms/                M1  기사·워크플로·미디어·홈 편집·지면·라이브
  src/modules/reader-membership/           M2  독자·멤버십·후원·페이월
  src/modules/ad-manager/                  M3  슬롯·캠페인·소재·집계·업소·공고
  src/modules/notify-newsletter/           M4  뉴스레터·웹 푸시
  src/modules/community/                   M5  댓글·신고·제보·경조사
  src/modules/distribution-seo/            M6  RSS·사이트맵·구조화 데이터·전재 계약·AI 크롤러 정책
  src/modules/compliance-desk/             M7  필요적 게재사항·자체기사 비율·정정 청구 SLA·선거 모드
  src/modules/search-analytics/            M8  검색·조회 집계·대시보드·리포트
  src/modules/local-life/                  행사·날씨·미세먼지 블록(제품 기능)
  src/features/reader-home/                홈 템플릿 3종 + 블록 레지스트리(NW-F-020, 03장)
  src/server/ai/                           서명 토큰, dify_user HMAC, 입력 마스킹(연락처·주민번호 패턴)
  src/styles/tokens.css                    원시·의미 토큰(Tailwind CSS v4 @theme). 테넌트는 의미 토큰 허용 목록만 덮어쓴다
worker/                                    TS 워커(Railway). src/handlers/<queue>/ 큐별 핸들러(4절)
apps/api/                                  FastAPI ai-service(Railway). app/ai/products/news/(prompts, rules, knowledge.py),
                                           app/ai/graphs/news_press_to_draft.py, news_assistant.py, app/ai/compliance/news.py
infra/dify/news-assistant.yml              Dify 앱 정의(키·비밀 없음)
supabase/monolith/                         0001_core_lite, 0002_tenant_theming, 0003_local_news_domain, seed, tests
```

각 `src/modules/<M>/`은 같은 모양이다: `server/`(서버 전용 서비스: RPC 호출, zod), `components/`(화면 조각), `schema.ts`(입력 계약), `cache.ts`(그 모듈이 무효화할 태그). 모듈 사이 import는 `server/index.ts` 공개 함수만 허용한다(린트, 제안). 06장 소유 단위가 이 디렉토리다.

| 모듈 | 소유 표(05장, 1차 `news.`) | 화면(03장) | API(04장) | 하지 않는 것 |
|---|---|---|---|---|
| M1 newsroom-cms | `newspapers`, `staff`, `sections`, `regions`, `tags`, `articles`, `article_revisions`, `article_regions`, `article_tags`, `media_assets`, `home_layouts`, `print_editions`, `live_updates` | 기사 목록·에디터·데스크·홈 편집·미디어·지면 | `/api/newsroom/articles/*`, `home-layouts/*`, `media/*`, `staff/*`, `import/*` | 독자 결제, 광고 집계, 발송 |
| M2 reader-membership | `readers`, `membership_tiers`, `memberships`, `donations`, `paywall_rules` | 독자 계정·멤버십·후원, 편집국 독자 관리 | `/api/r/membership/*`, `/api/newsroom/readers/*` | 결제 승인 로직(코어 toss), 조직 멤버십 |
| M3 ad-manager | `ad_slots`, `advertisers`, `ad_campaigns`, `ad_creatives`, `ad_daily_stats`, `local_listings`, `public_notices` | 광고·업소·공고 관리, 독자 사이트 슬롯 | `/api/newsroom/ads/*`, `/api/r/ad-event`, `/api/r/listings` | 정부광고 직접 결제(언론재단 대행) |
| M4 notify-newsletter | `newsletter_lists`, `newsletter_subscriptions`, `newsletter_issues`, `push_subscriptions` | 구독 폼·확인·해지, 편집국 발송 | `/api/r/newsletter/*`, `/api/r/push/*`, `/api/newsroom/newsletter/*` | 메일 제공자 구현(어댑터는 04장 6절) |
| M5 community | `comments`, `comment_reports`, `tips`, `life_events` | 댓글·신고, 제보·투고, 경조사 신청과 편집국 검토 | `/api/r/comments/*`, `/api/r/tips`, `/api/r/life-events`, `/api/newsroom/(comments|tips|life-events)/*` | 본인확인(2012 위헌, `RESEARCH_MARKET`) |
| M6 distribution-seo | `wire_contracts`, `syndication_settings` | 전재 계약, 배포 설정 | `rss.xml`, `sitemap-news.xml`, `robots.txt`, `llms.txt`, `/api/newsroom/wire-contracts/*` | 포털 전송 API(존재 미확인, 04장 6절) |
| M7 compliance-desk | `correction_requests`, `election_periods`, 함수 `compliance_weekly_stats` | 매체정보, 법정 푸터, 정정 청구함, 자체기사 비율 대시보드, 선거 모드 | `/api/r/corrections`, `/api/newsroom/(profile|corrections|compliance|elections)/*` | 법률 판단(표시·타이머·이력만) |
| M8 search-analytics | `article_view_hourly`, 뷰·함수 | 검색, 많이 본 뉴스, 편집국 대시보드, 지원사업 리포트 | `/api/r/view`, `/api/r/search`, `/api/r/most-read`, `/api/newsroom/stats/*` | 외부 분석 도구 대체 |
| local-life | `events` | 행사 캘린더, 날씨·미세먼지 블록 | `/api/r/life/weather`, `/api/newsroom/events/*` | 외부 API 원본 저장(캐시만) |
| auth | 없음(코어) | 로그인 3종(편집국·운영·독자) | 04장 8절 | 위치: `src/lib/auth/`. `AUTH_MODE`·제공자 목록을 읽는 코드는 9.2절 4곳에만(CI 금지 검사) |
| tenancy | 코어 `tenant_*`(MT) | 브랜딩·도메인 설정 | `/api/tenant/*`(MT 03장 5절) | 테넌트 slug·org_id 리터럴 분기(린트 금지, `Multi-tenant_Theming/03_CODE_STRUCTURE.md:155-163`) |

AI 모듈 경계(`docs/products/_platform-core/AI_ARCHITECTURE.md:5-23`, 재정의하지 않음):

| 경계 | 규칙 |
|---|---|
| 브라우저 ↔ 서버 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify·FastAPI·제공자 직접 호출 금지(`docs/products/_platform-core/SECURITY_BASELINE.md:300`) |
| Next.js ↔ FastAPI·음성 서버 | EdDSA 서명 토큰 `iss=news`, `aud=platform-ai:news`, `org`=세션 조직(편집국). scope는 04장 2.4절 |
| Next.js ↔ Dify | 대화 매핑(`user=dify_user`, 입력 `platform_conversation_id`). 토큰·org·기사 원문을 넘기지 않는다 |
| Dify ↔ FastAPI | 내부 키(`DIFY_INTERNAL_API_KEY`, news 전용) + 대화 매핑 |
| 워커 ↔ FastAPI | 잡 토큰(`/api/internal/ai-token`, 잡 행의 org·사용자로 발급) |
| 독자 호스트 | MVP에서 독자 호스트에는 AI 경로가 없다(독자 Q&A NW-F-056은 P2, 방문자 모드 `AI_ARCHITECTURE.md:54-56`) |

데이터 정본은 DB다. 독자 페이지는 `articles`(게시 상태)에서만 렌더하고, 편집국 미리보기는 서명된 미리보기 토큰(10분, `noindex`)으로 같은 렌더러를 쓰되 ISR 캐시에 넣지 않는다.

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 세션, `requireSession('news')`, 로그인 3종. 인증 단계 모듈 `src/lib/auth/`(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`) | `proxy.ts`, Route Handler, 로그인 화면, 콜백 | SM 2장, 20장(`docs/products/_platform-core/SHARED_MODULES.md:511-536`), 9절 |
| org | 신문사 1곳 = 회사 조직(`is_personal=false`). 편집국 초대는 `news.invite_staff`가 코어 `invite_member`를 감싼다 | M1 server | SM 3장. 독자는 조직 멤버가 아니다(브리프 2절) |
| credits | AI 기능 선차감·정산·환불 | `/api/ai/*`, `/api/voice/*`, 워커 | CS 4.3. 뉴스 B2B 플랜은 월 AI 크레딧(01장 4절) |
| toss | (1) 플랫폼 구독(신문사 → 플랫폼) (2) 독자 결제(독자 → 신문사 가맹, 신문사별 키) | `/api/newsroom/settings/billing/*`, `/api/r/membership/*` | SM 5장. 독자 결제는 `confirm_payment_order` 대신 제품 RPC로 기록(04장 3절, D-4) |
| webhooks | Toss(플랫폼·신문사별), 메일 이벤트 수신, 발신 웹훅 HMAC | `/api/webhooks/*`, 워커 `news.webhook_deliver` | SM 6장 |
| oauth(자격증명 부분) | 신문사 Toss 시크릿 키, 발신 웹훅 비밀, 외부 API 키(GAM은 키 없음) 보관 | `CredentialVault.put/get` | SM 7장. OAuth state는 쓰지 않는다 |
| ai-gateway | 대화 매핑, 서명·잡 토큰, 선차감·정산, Dify 중계 | `src/app/api/ai/`, `src/app/api/internal/`, `src/server/ai/` | SM 19장(`docs/products/_platform-core/SHARED_MODULES.md:496-509`) |
| ai-service | 라우터, RAG(`news-archive`, `news-policy`), 위키(사내 규정), 그래프 2개, `/tools/answer` | `apps/api` | 5절 |
| dify | 앱 `news-assistant` | `/api/ai/chat` | Dify DB는 조직 데이터 저장소(로그 30일, `AI_ARCHITECTURE.md:69`) |
| core-voice | 인터뷰 받아쓰기 STT(녹음 원본 미저장), 오디오 기사 TTS | `/api/voice/*`, 워커 `news.ai_tts` | `VOICE_ARCHITECTURE.md` 6장 |
| llm-wiki | 사내 규정 위키(윤리강령, 표기 규칙, 선거 보도 준칙). 조직 데이터 | `apps/api` wiki, 편집국 설정 화면 | `LLM_WIKI.md` |
| storage | `public-assets`(게시 사진 파생본·로고·지면 PDF 공개분), `org-files`(원본, 제보 첨부, 개설 신청 등록증), `exports`(데이터 내보내기, 리포트) | web 서명 URL, 워커 | SM 14장. 경로 첫 폴더 = `org_id` |
| audit | 게시·게시 취소·정정·권한 변경·임시조치·독자 데이터 내보내기·운영자 조회 | RPC 내부, 서버 경로 | SM 15장 |
| jobs | 4절 큐 6개의 상태 정본 | 전 계층 | SM 16장 |
| rate limit | 독자 쓰기(제보·댓글·구독·정정 청구·조회 비콘), 로그인, AI | Route Handler | CS 12장 |
| core-tenancy(제안 공용 패키지) | `resolve_tenant` 캐시, 테마 CSS, 서체, 자산 URL, 도메인 | `proxy.ts`, `(reader)` 레이아웃, `/api/tenant/*` | `Multi-tenant_Theming/README.md:81-109`. 이 제품이 첫 판매 적용(README 2절) |
| fal client | 쓰지 않음(MVP 이미지 생성 없음) | - | - |
| weasyprint render | 지원사업 리포트 PDF(NW-F-061, P1)에서만 소비자로 사용(제안) | 워커 `news.support_report` | SM 10장. 소유는 flora-publishing |
| 쓰지 않음 | sns uploader(NW-F-042 P2에서 재검토), automation-core, affiliate, compliance(SM 13장 대신 M7 + AI compliance 노드) | - | - |

COMMON_MODULES_ROADMAP과의 관계: M4는 `notify`(0100), M5 일부는 `support`(0700), 블록 에디터는 `cms`(0800), M8은 `analytics`의 추출 후보다(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:65-81`). 1차는 모두 `news` 스키마 안 모듈별 절이고, 두 번째 제품이 같은 기능을 요구하면 06장 6절 코어 요청으로 추출한다. 모듈 코드 경계(`src/modules/<M>/`)를 지금 나눠 두는 이유가 이것이다.

## 4. 잡과 워커

큐마다 워커 동시성을 따로 둔다(뉴스레터 대량 발송이 예약 게시를 막지 않게, 위험 #12). 페이로드는 04장 4절.

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `news.scheduled_publish` | `news.publish` | TS 워커 크론(1분). `news.run_scheduled_publishing()`(service)이 `scheduled_for <= now()` 기사와 예약 홈을 게시하고, 워커가 그 틱에 게시된 기사·홈을 조회해 `news.post_publish`를 enqueue | 0 | 크론 반복(다음 틱이 재시도) | 해당 없음. 게시 실패 기사는 DB가 `approved`로 되돌리고 `review_note`에 사유를 남김 → 데스크 알림 |
| `news.post_publish` | `news.publish` | TS. 캐시 태그 무효화(`/api/internal/revalidate`), 게시 확인 요청(버전 헤더 대조), 속보면 `news.push_send` enqueue, 발신 웹훅 enqueue, `news-archive` 색인 enqueue | 0 | 5회(코어 기본 지수 백오프) | 해당 없음 |
| `news.webhook_deliver` | `news.publish` | TS | 0 | 5회(1분, 5분, 30분, 2시간, 6시간, 제안) | 해당 없음 |
| `news.newsletter_send` | `news.newsletter` | TS. 부모: 수신자 확정(확인 완료·동의 유효·월 한도) → 500명 단위 자식 잡 | 0 | 0(부모 재시도 없음) | 해당 없음. 월 한도 초과는 enqueue 전 409 |
| `news.newsletter_batch` | `news.newsletter` | TS. 메일 제공자 배치 API, 수신자별 해지 토큰 | 0 | 3회(제공자 429·5xx만) | 해당 없음 |
| `news.push_send` | `news.newsletter` | TS. VAPID 서명, 404·410 응답 구독은 삭제 | 0 | 2회 | 해당 없음 |
| `news.reconsent` | `news.newsletter` | TS(월 1회). 동의 2년 도래 구독자에게 재확인 메일, 30일 무응답이면 구독 해지(`unsubscribed`, 사유 재확인 무응답) | 0 | 3회 | 해당 없음 |
| `news.import_run` | `news.ingest` | TS. 부모: RSS·CSV·XML·사이트맵 소스 목록화 → 100건 단위 자식 | 0 | 0 | 해당 없음. 이관 비용은 플랜(Standard 1회 무료, D-10) |
| `news.import_batch` | `news.ingest` | TS. 기사 변환·sanitize·`legacy_url` 기록(리디렉션 맵) | 0 | 3회 | 해당 없음 |
| `news.media_fetch` | `news.ingest` | TS. 원격 이미지 내려받기(허용 호스트·사설 IP 차단·10MB 상한) → 파생본 생성 | 0 | 3회 | 해당 없음 |
| `news.media_derive` | `news.ingest` | TS. 업로드 사진 파생본 4종 생성, EXIF 위치 제거 | 0 | 2회 | 해당 없음 |
| `news.export` | `news.ingest` | TS. 해지·내보내기(NW-F-064): 기사 JSON·HTML, 미디어, 독자 CSV(신문사 소유 데이터) → `exports` 7일 서명 URL | 0 | 2회 | 해당 없음 |
| `news.ai_press_draft` | `news.ai` | TS 워커 → FastAPI 그래프 `news.press_to_draft`(잡 토큰) | 01장 4절 `news.draft` 단가, enqueue 직전 | `max_attempts=2` | 그래프 `failed`·시간 초과(300초) → `fail_job` 자동 환불 |
| `news.ai_tts` | `news.ai` | TS → core-voice(`news.tts`, 대체 금지) | 01장 4절 TTS 단가(글자 수), enqueue 직전 | 1회(시작 전 제공자 오류만) | 한 구간이라도 실패하면 파일 없음 + 전액 환불 |
| `news.ai_index` | `news.ai` | Python(FastAPI 워커). 게시·수정 기사 → `news-archive`, 규정 문서 → `news-policy` | 0(제안: 게시마다 자동이고 `oss-embed` 원가가 작아 플랜 포함) | `max_attempts=3` | 해당 없음 |
| `news.ai_moderation` | `news.ai` | Python(FastAPI, `news.moderation` 오픈소스 강제). 새 댓글 위험 점수 → 편집국 검토 큐 | 0(제안: 독자 행동이라 신문사가 통제할 수 없음. 신문사당 일 1,000건 상한) | 2회 | 해당 없음. 실패해도 댓글은 기존 규칙(금칙어·신고)으로 처리 |
| `news.stats_rollup` | `news.stats` | TS(10분). 시간 버킷 합산, 많이 본 뉴스 태그 무효화, 일 단위 집계 | 0 | 3회 | 해당 없음 |
| `news.membership_renew` | `news.stats`(일 배치 큐 공유, 제안) | TS(매일 09:00 KST). 독자 정기 멤버십·후원을 **신문사 가맹 키**와 빌링키로 청구, 실패 3회면 `past_due` → 만료 | 0 | 결제 실패는 잡 재시도가 아니라 다음 날 재청구(최대 3회) | 해당 없음(크레딧 아님). 이중 청구 방지 멱등 키 `news:renew:<membership_id>:<period>` |
| `news.compliance_weekly` | `news.stats` | TS(월요일 06:00 KST). `news.compliance_weekly_stats` 스냅숏, 자체기사 30% 미만·주간 신규 0건 경고 메일 | 0 | 3회 | 해당 없음 |
| `news.correction_sla` | `news.stats` | TS(1시간). 정정 청구 3일 통지·7일 게재 기한 24시간 전 알림, 기한 경과 표시 | 0 | 3회 | 해당 없음 |
| `news.support_report` | `news.stats` | TS → 렌더 서비스(P1). 월 발행 실적·자체기사 비율·광고 비중·독자 수 | 0 | 1회 | 해당 없음 |
| `news.domain_verify` | `news.domain` | TS(10분). MT 도메인 검증 크론과 같은 일(`set_tenant_domain_status`) | 0 | 크론 반복 | 해당 없음 |
| `news.domain_auth_redirect` | `news.domain` | TS. 커스텀 도메인 `active` 직후 Supabase Auth 허용 목록에 `https://<host>/auth/callback` 등록(D-3 (a), 9.6절) | 0 | 5회 | 해당 없음. 실패 시 그 도메인의 독자 로그인을 서브도메인으로 우회(9.6절) |
| AI 정산 크론(잡 아님) | - | Next.js `/api/internal/ai-settle`(워커 5분 주기) | - | - | `ai_usage.settled_at is null` 10분 경과 행 정산·환불 |

예약 게시는 워커 크론 한 곳에서만 돌린다. SQL 주석의 pg_cron 등록 예시(`run_scheduled_publishing`)를 쓰면 DB 안에서 게시는 되지만 캐시 무효화·푸시·웹훅이 빠지므로 쓰지 않는다(제안, 05장과 맞춤). 동시 실행은 `for update skip locked`가 막고, `run_scheduled_publishing`이 게시한 id를 반환하도록 05장에 요청한다(현재 개수만 반환).

## 5. AI 라우팅

설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md:73-92`(라우터), `:109-119`(그래프), `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`(음성)이다. 이 절은 news 기능별 기본값과 그래프만 정한다.

### 5.1 기능별 라우팅 기본값

아래 표는 seed `ai_routing_settings`(org null, app `news`) 행과 같아야 한다(05장 확정 시 맞춤).

| feature | kind | 모드 | 대체 체인 | 강제 오픈소스 | 쓰는 곳 | 이유 |
|---|---|---|---|---|---|---|
| `news.draft` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `news.press_to_draft`의 `extract_facts`·`draft` 노드(NW-F-050) | 기사체 한국어 품질. 보도자료 속 담당자 연락처는 노드 전에 마스킹 |
| `news.headline` | llm | auto | oss-llm → anthropic → openai | 아니오 | 그래프 `news.assist`(headline 모드): 제목·부제·SEO 메타 추천(NW-F-051) | 짧은 생성. 비용 때문에 오픈소스 먼저(seed 정본) |
| `news.summary` | llm | auto | oss-llm → anthropic → openai | 아니오 | `news.assist`(summary 모드): 기사 요약, 뉴스레터 아침 브리핑 | 대량. 오픈소스 먼저 |
| `news.proofread` | llm | auto | oss-llm → anthropic → openai | 아니오 | `news.assist`(proofread 모드), `news.press_to_draft`의 `classify`·`style_check` 노드 | 대량·반복. 사실·고유명사 변경 금지 |
| `news.alt_text` | llm | auto | anthropic → google → openai → oss-llm | 아니오 | `news.assist`(alt_text 모드): 사진 alt·캡션 초안(NW-F-055) | 이미지 입력. 국외 동의 없는 신문사는 `oss-llm`만 남는데 오픈소스 비전 모델 등록 여부 미확인 → 등록 전에는 실패로 처리하고 기능을 숨김 |
| `news.moderation` | llm | open_source | oss-llm | 예 | 댓글 위험 점수(NW-F-026 보조) | 독자 개인정보·발화 원문 |
| `news.assistant` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `news.assistant`(편집국 채팅, NW-F-053) | 근거 기반 답변 품질 |
| `dify.aux` | llm | open_source | oss-llm | 예 | Dify 질문 분류 노드 | 조직을 알 수 없어 국외 동의를 확인할 수 없음(flora와 같은 규칙) |
| `news.knowledge` | embedding | open_source | oss-embed | 아니오(대체 없음) | `news-archive`, `news-policy` 색인·검색 | 원가, 국외 이전 동의 불필요. 모델 변경 시 재색인 |
| `news.stt` | stt | open_source | oss-voice | 예 | 인터뷰 받아쓰기(NW-F-054) | 취재원(제3자) 목소리·제보 내용. 원본 미저장(`store_audio=false`) |
| `news.tts` | tts | auto | elevenlabs → oss-voice | 아니오 | 오디오 기사(NW-F-052) | 품질 우선. 작업 도중 대체 금지(같은 목소리), 국외 동의 없으면 oss-voice로 시작 |
| `news.reader_qa`(P2, seed 행 없음) | llm | open_source | oss-llm | 예 | 독자 Q&A(NW-F-056) | 방문자 발화. P2 착수 때 seed 행 추가 |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 국외 이전 동의 | 신문사 owner가 편집국 온보딩에서 `set_ai_cross_border_ack`. 동의 전에는 체인에서 상용(국외)이 빠져 `news.draft`는 `oss-llm`만, `news.alt_text`는 비활성 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 제보 원문 금지 | `tips` 원문·첨부, 독자 개인정보, 정정 청구인 정보는 어떤 상용 기능의 입력에도 넣지 않는다. 제보를 기사로 쓰려면 기자가 사실만 옮겨 적은 메모를 입력으로 쓴다 | 브리프 7절, `docs/products/_platform-core/SECURITY_BASELINE.md:292` |
| AI 표시 | AI가 초안·제목·요약·alt·음성에 관여한 기사는 `articles.ai_assisted`·`ai_disclosure`(05장, 보조 기능 키는 감사·`ai_runs`)로 남기고 독자 화면에 고지 문구(D-9)를 렌더한다. TTS는 "AI 음성" 표시 | AI기본법 2026-01-22 시행, 언론계 생성형 AI 준칙(`RESEARCH_MARKET.md` 규제 표) |
| 기사 유형 불변 | AI 초안은 원래 유형(`press_release`)을 유지한다. AI가 `original`로 바꾸지 못한다(자체기사 비율 왜곡 방지, D-9) | 01장 NW-F-050 |
| 조직 재정의 | 제품 화면에서 `set_ai_routing`을 부르지 않는다. 신문사가 고르는 것은 국외 이전 동의뿐 | flora 5.1절과 같은 규칙 |

### 5.2 LangGraph 그래프

| 그래프 | 노드 순서 | LLM 기능 | 사람 승인 | compliance | 실행 |
|---|---|---|---|---|---|
| `news.press_to_draft` | `classify` → `mask` → `extract_facts` → `draft` → `fact_check` → `style_check` → `compliance` → `output` | `news.draft`, `news.proofread` | 2곳: (1) 기자가 초안을 채택·수정해 `submitted`로 올림 (2) 데스크 `news.review_article(approve)`. 그래프 출력은 `draft` 상태 저장까지만이고 게시 경로가 없다 | 있음(마지막 생성 노드 뒤 필수) | 워커 잡 `news.ai_press_draft`, FastAPI 비동기, thread = `ai_runs.thread_id` |
| `news.assistant` | `route` → `retrieve` → `answer` → `cite_check` → `compliance` | `news.assistant` | 없음(답변만, 쓰기 도구 없음) | 있음 | Dify HTTP 노드 → `/tools/answer`가 그래프를 동기 실행(p95 20초, 제안). Dify 장애 시 `/tools/answer-direct` |
| `news.assist`(변경 제안: 브리프 7절의 그래프 2개에 추가) | `compose` → `generate` → `compliance` | 모드별 `news.headline`·`news.summary`·`news.proofread`·`news.alt_text` | 없음(결과는 저장 전 제안. 기자가 골라 에디터에 반영) | 있음 | Route Handler 동기(p95 15초, 제안). flora `publishing.assist`와 같은 방식으로 단건 기능을 한 진입점에 묶는다 |

| 노드 | 입력 | 동작 | 출력 | LLM |
|---|---|---|---|---|
| `classify` | 보도자료 원문(붙여넣기·파일 텍스트, 30,000자 이하) | 보도자료 여부, 발신 기관, 엠바고 표기, 섹션·지역 후보 | 분류 결과. 엠바고 표기가 있으면 `embargo_until` 제안 | 있음(`news.proofread` 체인, 짧은 분류) |
| `mask` | 원문 | 전화·이메일·주민번호·계좌 패턴을 자리표시자로 치환(규칙) | 마스킹본 + 복원 표(FastAPI 메모리, 저장 안 함) | 없음 |
| `extract_facts` | 마스킹본 | 육하원칙, 수치, 날짜, 인용, 고유명사 목록(JSON) | 사실 목록 | 있음 |
| `draft` | 사실 목록, 사내 표기 규칙(`news-policy` 위키) | 리드 + 본문(사실 목록 밖 내용 금지), 제목 후보 3 | 초안 블록 JSON | 있음 |
| `fact_check` | 초안, 사실 목록 | 초안의 수치·날짜·고유명사가 원문에 있는지 대조(규칙 + 문자열). 없으면 `draft` 1회 재작성, 그래도 남으면 해당 문장에 확인 필요 표시 | 통과 / 표시 목록 | 없음 |
| `style_check` | 초안 | 맞춤법·표기 규칙. 의미·사실 변경 금지(변경 비율 15% 상한, 제안) | 교정본 | 있음 |
| `compliance` | 교정본 | `rules/news_banned.json`: 광고성 최상급 표현, 선거 기간 여론조사 수치(활성 `election_periods`면 차단), 단정적 의료·투자 표현, 실명 비방, 출력 스키마 | 통과 / 차단 사유 | 없음(규칙) |
| `output` | 통과본 | 워커에 결과 반환. 워커가 `articles`를 `draft`, `type='press_release'`, `origin='ai_press_release'`, `ai_assisted=true`, `ai_disclosure`로 저장 | 기사 id | 없음 |

`news.assistant`의 `retrieve`는 같은 신문사의 `news-archive`(게시 기사만, 비공개·초안 제외)와 `news-policy` 위키만 검색한다(`match_ai_chunks(org, 'news', ...)`). `cite_check`는 답변의 각 주장에 출처(기사 id·위키 slug)가 붙어 있는지 확인하고, 없으면 "근거 없음"으로 답한다.

## 6. 리뷰 "높음" 결함의 차단 설계

원본 리뷰가 없으므로(브리프 0절) 리뷰 "높음" 항목 대신 경쟁·업계 위험 상위 항목을 "위험 #n → 차단 설계" 표로 둔다(장 제목은 DOC_TEMPLATE 그대로). 이 절은 비보안 위험 15건이고, 보안·데이터 위험(테넌트 간 독자 데이터, 제보 개인정보, 신문사 결제 키, 댓글 임시조치 증거, 독자 계정 풀)은 `05_DATA_MODEL.md` 7절에 있다. 담당 작업 번호는 06장이 정한다.

| 위험 #n | 출처 | 위험 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| #1 | `RESEARCH_DESIGN.md` 4장(web.dev optimize-cls) | 광고 늦은 로드가 CLS 최대 원인. CWV 미달은 검색 노출 손실 | 슬롯 크기를 IAB 고정 규격으로만 등록(`ad_slots`), 슬롯마다 `min-height`·`aspect-ratio`를 서버 렌더 시 예약하고 비어도 접지 않음(하우스 광고로 채움). 팝업·전면 광고 기능 없음. 접힌 아래 슬롯은 지연 로드. 블록 레지스트리가 슬롯 위치를 고정(테넌트는 ON/OFF만). 목표 CLS ≤0.1(p75) | M3, 03장 블록 레지스트리, 06장 광고·성능 작업 |
| #2 | 브리프 7절, README 5절 이유 1 | 속보·재난·선거 때 독자 트래픽 급증 → DB 커넥션 고갈, 응답 지연 | 독자 페이지는 ISR(요청 경로에서 DB 미조회), 캐시 태그로 게시 즉시 갱신. 조회수는 비동기 비콘(`/api/r/view`)이 시간 버킷 증분만 한다(샤드 컬럼으로 행 경합 분산, 제안, 05장). 많이 본 뉴스는 60초 캐시. 단독 Supabase 프로젝트로 다른 제품과 격리, 서버는 풀러(Supavisor) 경유 | 10.3절, M8, 05장 5절 |
| #3 | 제안(뉴스 운영 특성) | 캐시 무효화 지연으로 수정·정정·게시 취소 기사가 계속 보임(법적 위험: 정정 미반영, 엠바고) | 상태를 바꾼 Route Handler가 응답 전에 태그 무효화. 워커·크론 변경은 서명된 `/api/internal/revalidate`. `news.post_publish`가 공개 URL을 요청해 `x-article-version` 헤더가 새 버전인지 확인, 다르면 재무효화 후 경보. 게시 취소 기사는 410 + 태그 무효화. 기사 페이지 최대 수명 300초(제안, 무효화 실패 대비) | M1, M6, 4절 `news.post_publish` |
| #4 | `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:63-71`, 정보통신망법 50조(`RESEARCH_MARKET.md`) | 뉴스레터가 스팸함으로 가거나 발신 도메인 평판이 한 신문사 때문에 전체가 떨어짐 | 플랫폼 발신 도메인 1개(SPF·DKIM·DMARC), 신문사별 발신 이름·`Reply-To`. 이중 동의만 발송, `List-Unsubscribe` 원클릭, 반송·수신 거부 웹훅으로 즉시 억제 목록. 신문사별 반송률 5%·신고율 0.3% 초과 시 발송 일시 중지(제안). 광고 포함 호는 제목 "(광고)", 21~08시 발송은 별도 동의자만, 2년 재확인 잡 | M4, 4절, 04장 5절 |
| #5 | `RESEARCH_MARKET.md` 포털(검색제휴는 크롤링·정량평가) | 포털·Google 수집 실패, 중복 URL로 점수 손실 | 뉴스 사이트맵(최근 2일, 파일당 1,000개), `NewsArticle` 구조화 데이터, RSS, canonical은 대표 도메인 하나(서브도메인은 대표 커스텀 도메인으로 301), 기사 URL 영구 고정(`/news/<id>/<slug>`, slug 변경 시 301). 포털 전송 API는 있다고 가정하지 않는다(미확인) | M6, 10.2절 |
| #6 | 07장(이관 계획) | 기존 CMS 이관 후 옛 URL 404 → 검색 순위·포털 링크·외부 인용 상실 | 이관 잡이 기사마다 옛 URL을 기록(리디렉션 맵, 05장 표), `proxy.ts`가 테넌트 호스트의 미매칭 경로를 맵에서 찾아 301. 이관 후 사이트맵 전수 크롤 검증 리포트(404 0건이 완료 조건). 엔디소프트 URL 패턴은 미확인(이관 1호 고객 실측) | M1 import, 07장 |
| #7 | 브리프 7절, D-7 | 한국어 형태소 분석 없음 → 검색 품질 저하(조사 붙은 단어, 2글자 검색) | 제목·부제 `pg_trgm` GIN + 본문 `tsvector('simple')`. 2글자 이하 질의는 최근 12개월 제목 `ILIKE`로 제한(제안). 결과는 최신순 가중. pg_bigm은 Supabase 지원 미확인, 기사 10만 건 초과 신문사가 생기면 Meilisearch/Typesense(P2) | M8, 05장 5절 |
| #8 | `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:38-61` | 와일드카드 서브도메인·커스텀 도메인 인증서·DNS 실패로 사이트 접속 불가 | MT 도메인 흐름(요청 → Vercel 등록 → DNS 안내 → 10분 검증 → `active`) 그대로. 활성 전에는 해석하지 않음. 대표 도메인 `failed`면 서브도메인 이동 중지. 와일드카드는 네임서버 위임 필요 여부 확인 필요. Vercel 프로젝트당 도메인 상한 미확인 → 운영 콘솔에 도메인 수 지표 | 10.4절, M7(운영) |
| #9 | 브리프 4절 NW-F-012 | 엠바고·예약 기사가 시각 전에 노출(미리보기 링크 유출, 캐시) | 미리보기는 서명 토큰 URL(10분, `noindex`, 캐시 금지), ISR은 `published`만. 예약 게시는 워커 크론 + `run_scheduled_publishing`(`skip locked`, 4절), 엠바고 시각 전 `publish_article`은 DB가 거부 | M1, 4절 |
| #10 | `RESEARCH_MARKET.md` 신문법 2조·포털 심사 | 자체기사 비율 오계산 → 포털 심사 감점·법정 요건 미달 | 기사 유형 필수, 비율 계산은 `news.compliance_weekly_stats` 함수 1곳(화면·리포트·경고가 같은 함수), AI 초안은 `press_release` 유지(D-9), 주간 경고 잡 | M7, 4절 |
| #11 | `RESEARCH_DESIGN.md` 4장 | 고해상도 사진으로 LCP 초과 | 업로드 시 파생본 4종(WebP·JPEG), `srcset`·`sizes`, 리드 사진만 `priority`, 원본 20MB·장변 6,000px 상한(제안). 목표 LCP ≤2.5s | M1 `news.media_derive`, 1절 이미지 행 |
| #12 | 제안(큐 설계) | 뉴스레터 대량 발송·이관이 예약 게시·속보 푸시를 지연 | 큐 분리(`news.publish`·`news.newsletter`·`news.ingest`), 워커 큐별 동시성(publish 우선, 4절), 이관 배치 크기 100 | 4절, 06장 워커 작업 |
| #13 | 제안(외부 광고 태그) | GAM/AdSense 태그가 INP·LCP를 악화하고 저품질 광고가 포털 감점 요인 | 외부 태그는 신문사별 스위치(NW-F-031), LCP 이후 비동기 로드, 슬롯 크기 고정(#1). 네이티브 수익배분 위젯은 제공하지 않음(`RESEARCH_MARKET.md` 경쟁 표 Taboola 행) | M3 |
| #14 | 브리프 4절 NW-F-023, D-8 | 기상청·에어코리아 API 장애·쿼터 초과 | 서버에서 지역별 30분 캐시, 실패 시 블록 숨김(가짜 값 금지), 키·쿼터·이용 조건 미확인(D-8 확정 전 P1 비활성) | local-life, 04장 6절 |
| #15 | `Multi-tenant_Theming/03_CODE_STRUCTURE.md:80-106` | ISR 캐시 키에 호스트가 빠져 다른 신문사 페이지가 섞임 | `proxy.ts`가 테넌트 요청을 `/_t/<host>/...`로 재작성해 캐시 경로에 호스트가 들어간다. 태그에 `org_id` 포함. E2E가 `acme`·`beta` 두 테넌트로 교차 확인. 데이터 접근 측 격리는 05장 7절 | 10.1절, 06장 테넌시 작업 |

## 7. 배포 토폴로지

| 구성요소 | 위치 | 공개 여부 | 호출 경로 |
|---|---|---|---|
| web | Vercel 프로젝트 `news-web` 1개. 도메인: 루트(마케팅), `newsroom.<플랫폼>`, `ops.<플랫폼>`(제안), 와일드카드 `*.<플랫폼>`(테넌트 서브도메인), 신문사 커스텀 도메인(Vercel 프로젝트 도메인 API로 추가, 확인 필요) | 공개 HTTPS | 브라우저 → web. web → Supabase(anon·세션, service_role), FastAPI(서명 토큰), Dify, 음성 서버 |
| DB/Auth/Storage/Realtime | Supabase 단독 프로젝트(모놀리스, 운영·스테이징 2개). 서버 커넥션은 풀러 경유 | Supabase 표준 | 전 계층 |
| 이미지 CDN | Supabase Storage 공개 버킷 `public-assets`(파생본, 불변 경로 + 1년 캐시) | 공개 | 브라우저 직접 |
| TS 워커 | Railway 서비스. 큐 6개, 큐별 동시성(제안: publish 4, newsletter 4, ingest 2, ai 2, stats 1, domain 1) | 비공개 | Supabase(service_role) `claim_jobs`, 메일 제공자, Web Push, Vercel API, Supabase 관리 API, FastAPI(잡 토큰), web 내부 엔드포인트 |
| AI 서비스(`apps/api`) | Railway | 공개 HTTPS, 서명 토큰·내부 키 없으면 401 | Supabase(service_role), 상용 LLM, 공용 GPU 서버 |
| Dify(공용) | 운영사 자체 호스팅 | 콘솔은 운영자만(2단계 인증) | web → Dify Chat API, Dify → FastAPI `/tools/*` |
| 공용 GPU 서버 | 운영사 자체 호스팅(`oss-llm`, `oss-embed`, `oss-voice`) | 비공개 | FastAPI, web 서버(음성) |
| ElevenLabs | 외부(국외) | - | web 서버·워커(TS SDK) |
| 메일 제공자 | Resend 또는 Amazon SES(제안) | - | 워커(뉴스레터), web(트랜잭션), Supabase Auth(SMTP). 이벤트 웹훅 → web |
| 스케줄 | 워커 크론(예약 게시 1분, 통계 10분, 도메인 10분, SLA 1시간, 주간 지표, 멤버십 청구 일 1회, 재동의 월) + 코어 스케줄(pg_cron, CS 14장) | - | CS 14장 |

```
독자 ──HTTPS──> <slug>.<플랫폼> / 커스텀 도메인 ─┐
편집국 ─────────> newsroom.<플랫폼> ──────────────┼──> web(Vercel, proxy.ts Host 분기) ──> Supabase(모놀리스)
운영자 ─────────> ops.<플랫폼> ───────────────────┘        │ enqueue / revalidate(내부)        ^ claim/complete
                                                            │                                    │
                                     서명 토큰 ──> apps/api(Railway) <── 잡 토큰 ── TS worker(Railway) ──> 메일·Web Push·Vercel API
                                                   ^ 내부 키                                         └──> Supabase 관리 API(D-3 a)
                                                 Dify(공용) <── 대화 매핑 ── web
```

## 8. 환경변수

인증 단계 변수(`AUTH_MODE`, `AUTH_PROVIDERS*`, 제공자 키 등)는 9.4절에만 적는다. "서버"는 web 서버 전용(NEXT_PUBLIC 아님)이다.

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 브라우저 클라이언트, `resolve_tenant`(anon) | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버·워커·FastAPI | 서버 전용 | 기동 실패 |
| `SUPABASE_DB_SCHEMA`, `NEWS_DB_SCHEMA` | 코어·제품 스키마(모놀리스 둘 다 `public`, 모듈러 `core`·`news`) | 서버 전용 | 기동 실패 |
| `NEXT_PUBLIC_APP_ID` | `news` 고정(MT 해석의 앱 값) | 공개 | 기동 실패 |
| `PLATFORM_ROOT_DOMAINS` | 플랫폼 루트 도메인 목록(로컬 `localhost:3000` 포함) | 서버 전용 | 기동 실패 |
| `NEWSROOM_HOST`, `OPS_HOST` | 편집국·운영 호스트(proxy 분기, 콜백 origin) | 서버 전용 | 기동 실패 |
| `RESERVED_SLUGS` | 서브도메인 예약어(`www`, `newsroom`, `ops`, `login`, `api`, `admin`, `mail`, `static` 등) | 서버 전용 | 기본 목록 사용 |
| `REVALIDATE_SECRET` | 워커 → `/api/internal/revalidate` HMAC | 서버, 워커 | 기동 실패 |
| `NEWS_WORKER_INTERNAL_KEY` | 워커 → `/api/internal/ai-token`, `ai-settle` | 서버, 워커 | 기동 실패 |
| `PREVIEW_TOKEN_SECRET` | 미리보기 서명 URL | 서버 전용 | 기동 실패 |
| `METER_COOKIE_SECRET` | 미터형 페이월 무료 건수 서명 쿠키(뉴스레터 구독 토큰은 DB가 생성·해시 저장하므로 별도 키 없음) | 서버 전용 | 페이월 미터 비활성(전체 공개) |
| `RATE_LIMIT_IP_SALT` | IP 해시 솔트 | 서버 전용 | 기동 실패 |
| `TURNSTILE_SITE_KEY` / `TURNSTILE_SECRET_KEY` | 독자 폼 봇 차단(제보·정정 청구·구독·댓글) | 사이트 키 공개(`NEXT_PUBLIC_`), 시크릿 서버 | 기동 실패 |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | 웹 푸시 | 공개키 공개, 개인키 워커 전용 | 푸시 기능 비활성 |
| `EMAIL_PROVIDER`, `EMAIL_API_KEY`, `EMAIL_FROM_DOMAIN`, `EMAIL_WEBHOOK_SECRET` | 메일 발송·이벤트 서명 | 서버, 워커 | 기동 실패 |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | 플랫폼 구독 결제(신문사 → 플랫폼) | 클라이언트 키만 공개 | 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 신문사 Toss 키·웹훅 비밀 암호화 | 서버, 워커 | 기동 실패(0키 폴백 금지) |
| `VERCEL_API_TOKEN`, `VERCEL_PROJECT_ID`, `VERCEL_TEAM_ID` | 커스텀 도메인 등록·검증 | 서버, 워커 | 커스텀 도메인 기능 비활성 + 운영 알림 |
| `KMA_API_KEY`, `AIRKOREA_API_KEY` | 날씨·미세먼지(공공데이터포털, 조건 미확인, D-8) | 서버 전용 | 블록 숨김 |
| `AI_SERVICE_URL` | FastAPI 주소 | 서버, 워커 | AI 기능 비활성 + 오류 표시 |
| `AI_TOKEN_PRIVATE_KEY`, `AI_TOKEN_KID` | EdDSA 서명 토큰 발급 | 서버 전용 | 기동 실패 |
| `AI_TOKEN_JWKS_URL` | 서명 토큰 공개키 | `apps/api`, 음성 서버 | 기동 실패 |
| `DIFY_API_URL`, `DIFY_APP_KEY_NEWS` | Dify Chat API, 앱 키 | 서버 전용 | FastAPI 직접 경로만 + 운영 알림 |
| `DIFY_INTERNAL_API_KEY` | Dify HTTP 노드 → FastAPI(news 전용 값) | `apps/api`, Dify 환경 | `apps/api` 기동 실패 |
| `DIFY_USER_HMAC_SECRET` | `dify_user = HMAC(org:sub)` | 서버 전용 | 기동 실패 |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OPENROUTER_API_KEY` | 상용 LLM | `apps/api` 전용 | 해당 제공자 비활성(체인 다음) |
| `OSS_LLM_BASE_URL`, `OSS_EMBED_BASE_URL` | 오픈소스 LLM·임베딩 | `apps/api` 전용 | `apps/api` 기동 실패(강제 오픈소스 기능 필수) |
| `ELEVENLABS_API_KEY`, `OSS_VOICE_BASE_URL` | 음성 | 서버, 워커 | ElevenLabs 비활성 / 오픈소스 없으면 기동 실패(STT 강제) |
| `NEWS_TTS_VOICE_ELEVENLABS`, `NEWS_TTS_VOICE_OSS` | 오디오 기사 보이스 id | 서버, 워커 | 기동 실패 |
| `AI_CROSS_BORDER_NOTICE_VERSION`, `VOICE_NOTICE_VERSION` | 고지문 버전 | 서버 전용 | 기동 실패 |
| `NEXT_PUBLIC_HERO3D_ENABLED` | 마케팅 랜딩 3D 끄기 스위치 | 공개 | 기본 true |
| `WORKER_ID`, `WORKER_CONCURRENCY_<QUEUE>` | 워커 식별·큐별 동시성 | 워커 | 기본값(7절) |

모든 앱은 기동 시 zod(TS)·pydantic Settings(Python) 검증을 통과해야 한다. AI 변수는 `docs/products/_platform-core/AI_ARCHITECTURE.md:160` 목록을 따르며 `NEXT_PUBLIC_HERO3D_ENABLED` 외에는 모두 서버 전용이다. `.env*`는 커밋하지 않는다.

## 9. 인증 단계 (확정 결정 22, 2026-10-15)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`와 `develop/_shared/auth/README.md`이고, 이 절은 news의 두 사용자 풀(편집국·독자)에 맞춰 옮긴 것이다. 이 제품의 행은 AUTH_ROADMAP 8장 매트릭스에 아직 없으므로 브리프 6절 표를 정본으로 쓰고 06장 6절 코어 요청으로 매트릭스 추가를 요청한다. 세션(실제 Supabase JWT), `session_context`, RLS는 단계와 무관하게 같다.

### 9.1 단계표 (이 제품 기준)

| 단계 | 편집국(`newsroom` 호스트, 가입 정책 invite) | 독자(테넌트 호스트, 신문사별 공개 가입) | 작업(번호는 06장) | 진입 게이트 |
|---|---|---|---|---|
| A | 로컬 시드 페르소나 원클릭(공통: owner=publisher, admin=editor, member=reporter, viewer, outsider=다른 신문사 발행인, no_app, suspended, ops + 제품: desk, contributor, ad_manager). 제공자 버튼 없음 | 시드 독자 페르소나(`reader`, `reader_member`, `reader_other`)를 `acme.localhost:3000`에서 원클릭. `anon`은 로그인 없는 시나리오 | 기존 인증 작업(Stage A 범위) | 없음(W0부터) |
| B | Google + 이메일(비밀번호)·초대 메일. 개설 신청자도 같은 방법으로 계정 생성 | 이메일 매직 링크 + Google | `NW-06-0xx`(Fable, M, P0) | G1(AUTH_ROADMAP 4장) |
| C1 카카오 | P2 선택 | **P1**(지역 독자 핵심) | `NW-06-0xx`(Opus, S, P1) | G2 + 01장 8.1절 카카오 이메일 결정 |
| C2 네이버 | P2 선택 | P1. 경로는 `supabase_custom` 권고(브리지는 테넌트 호스트마다 콜백 등록이 필요해 D-3 (b) 없이는 불가, 9.6절) | `NW-06-0xx`(Fable, M, P1) | G2 + 스파이크 결과 |

단계 전환은 사람(대표님)이 게이트를 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 남긴 뒤에만 한다. 독자 사이트의 방문자 흐름(기사 읽기, 검색, 구독 신청, 제보)은 로그인과 무관하다.

### 9.2 모듈 위치와 단계 분기 규칙

| 위치 | 하는 일 | 단계 분기 허용 |
|---|---|---|
| `src/lib/auth/` | 제품 주입 파일(`develop/_shared/auth/README.md:58-70`): `appId='news'`, `signupPolicy='invite'`, 호스트 종류별 `allowedProviders`, `homePath`, `firstLoginPath`, `resolveOrg`(편집국: 활성 `news.staff` 조직), 시드 훅. `getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions('news', hostKind)`, `finishLogin('news', next, hostKind)` | 예 |
| `src/app/(auth)/login/`, `src/app/(reader)/_t/[host]/login/` | `listLoginOptions` 결과로 개발용 패널(A)·버튼(B·C) 렌더. 독자 로그인 화면은 테넌트 로고·제호, 동의 화면 브랜드는 플랫폼(9.7절) | 예 |
| `src/app/auth/callback/`, `src/app/auth/confirm/` | PKCE 코드 교환, 매직 링크 `token_hash` 검증 → `finishLogin` | 예 |
| `src/app/api/dev/login/` | Stage A(로컬 전용, 판정 거짓이면 404). 호스트 종류로 편집국·독자 페르소나 목록을 나눈다 | 예 |
| `src/app/auth/naver/` | C2 브리지를 택했을 때만(9.6절 제약) | 예 |
| 그 밖의 코드(`src/modules/`, 기능 Route Handler, 화면, worker, `apps/api`) | 편집국은 `requireSession('news')`, 독자는 `requireReader()`(세션 + `news.readers` 행 확인, M2 server)만 쓴다. `AUTH_MODE`·페르소나 이메일로 분기하지 않는다 | 아니오(CI grep) |

`x-host-kind`(`reader`·`newsroom`·`ops`·`marketing`)는 `proxy.ts`만 쓰고 `src/lib/auth/`와 `core-tenancy`만 읽는다. 들어온 같은 이름 헤더는 proxy가 지운다.

### 9.3 `finishLogin` 호스트별 분기

공통 1~2단계 뒤 호스트 종류로 갈린다. AUTH_ROADMAP 3.2절 순서를 지키되, news는 invite 앱이라 `bootstrap_app_for_org`를 부르지 않는다(모놀리스 가입 트리거도 invite 앱은 부트스트랩하지 않는다, `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:260-266`, 사용자 호출은 42501, `:1037-1040`).

| 순서 | 독자(테넌트 호스트) | 편집국(newsroom 호스트) | 운영(ops 호스트) |
|---|---|---|---|
| 1 | 세션 확립: `/auth/callback` `exchangeCodeForSession`(PKCE), `/auth/confirm` `verifyOtp(token_hash)`, Mock은 `signInWithPassword`. 실패 → `/login?error=callback` | 같음 | 같음 |
| 2 | 제공자 허용 검사: 이번 로그인 제공자가 그 호스트 종류의 허용 목록(`AUTH_PROVIDERS_READER`)에 없으면 로그아웃 → `/login?error=provider`(`develop/_shared/auth/README.md:26`) | `AUTH_PROVIDERS`로 같은 검사 | `AUTH_PROVIDERS`로 같은 검사 |
| 3 | `getTenant()`(= `resolve_tenant`, 캐시). `null`(단계 0, 정지·해지)이면 로그아웃 → "서비스 일시 중지" 화면 | `resolveOrg`: 선호 조직 쿠키(`news_org`, uuid만, 권한 근거 아님) → 활성 `news.staff` 조직 → 없으면 본인 개설 신청이 있으면 `/apply/status`, 없으면 `/no-access` | `session_context('news')` |
| 4 | 그 신문사 `readers` 행을 RLS로 확인. 없으면 `/account/welcome`(6단계)로 보내고, 동의 제출 시 `news.ensure_reader(p_org, p_nickname, p_terms_version, p_privacy_version, p_is_over_14, p_marketing_opt_in)`가 행을 만든다(만 14세 미만 `NW015` 거부, 비공개 신문사 `NW002`). `blocked`면 로그아웃 → `/login?error=reader_blocked`(`NW008`) | `session_context('news', org)`: `status` pending/suspended 분기, `entitled=false`면 owner·admin은 `/settings/billing`(만료 안내), 그 밖은 `/no-access` | `platform_role <> 'platform_admin'`이면 로그아웃 + 404 |
| 5 | 프로필 `status='suspended'`면 403 | `news.staff` 활성 행과 역할 확인(없으면 `/no-access`) | - |
| 6 | 독자 행이 없으면 `/account/welcome`(닉네임, 이용약관·개인정보 동의 버전, 만 14세 이상 확인, 마케팅 수신 선택) → `POST /api/r/account/join`(04장 2.1절) | 첫 로그인이면 `/onboarding`(약관, AI 국외 이전 고지는 owner만) | - |
| 7 | `next` 화이트리스트(`/` 시작, `//`·`@`·`\` 없음). origin은 **요청 테넌트 호스트**이며 그 호스트가 해석 결과의 도메인(대표 커스텀 도메인 또는 `<slug>.<루트>`)과 같아야 한다. 기본 `/` | origin `NEWSROOM_HOST`, 기본 `/dashboard`(contributor는 `/articles/mine`) | origin `OPS_HOST`, 기본 `/` |
| 8 | `auth.login` 기록은 서버(service_role)가 남긴다(provider, `kind=reader`, `org_id`, 첫 로그인 여부. 토큰·코드 미기록). 독자는 조직 멤버가 아니라 RPC 안 `write_audit`를 쓰지 않는다(DB 설계 요약 0절) | 감사 `auth.login`(`kind=newsroom`) | 감사 `auth.login`(`kind=ops`) |

독자 계정은 플랫폼 공통 계정이다. 같은 사람이 A·B 신문사 독자가 되면 `readers` 행이 신문사마다 1개씩 생기고 신문사는 자기 행만 본다(05장 RLS). 코어 가입 트리거가 독자에게도 개인 조직을 만들지만 엔타이틀먼트가 없어 쓰이지 않는다(코어 동작, 변경 요청 없음). 인증 쿠키는 호스트 전용이라 신문사 사이트마다 따로 로그인한다(`Multi-tenant_Theming/03_CODE_STRUCTURE.md:104`).

### 9.4 환경변수 (AUTH_ROADMAP 3.3절 중 이 제품 해당분)

| 변수 | 단계 | 배치 | 값 | 없으면 |
|---|---|---|---|---|
| `AUTH_MODE` | A·B·C | web 서버 전용 | 로컬 `mock`, 배포 `live` | `live`. `mock`인데 판정 거짓이면 기동 실패 |
| `AUTH_PROVIDERS` | B·C | web 서버 | 편집국·운영: B `google,email`, C 도입 시 `kakao`, `naver` 추가 | live에서 0개면 기동 실패 |
| `AUTH_PROVIDERS_READER` | B·C | web 서버 | 독자: B `email,google`, C1 후 `kakao`, C2 검수 통과 후 `naver` | live에서 0개면 기동 실패. 제안: 공용 모듈 v1.0의 앱별 허용 목록을 호스트 종류별로 확장(코어 요청) |
| `DEV_SEED_PASSWORD` | A | web 서버(로컬), 시드 스크립트 | - | Mock 기동 실패 |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | B | 로컬 `supabase/config.toml`의 `env()`, 원격은 Supabase 대시보드만 | - | 로컬 Google 버튼 비활성 |
| `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET` | C1 | 같은 방식 | - | 카카오 버튼 비활성 |
| `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`, `NAVER_AUTH_PATH` | C2 | `supabase_custom`: 등록 스크립트만 / `bridge`: web 서버 | 기본 `supabase_custom` | 네이버 버튼 비활성 |
| `AUTH_BRIDGE_SECRET` | C2 브리지만 | web 서버, 32바이트 이상 | - | 브리지면 기동 실패 |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` | B(D-3 (a)) | 워커 전용(`news.domain_auth_redirect`) | 관리 API 토큰(권한 최소) | 커스텀 도메인 독자 로그인을 서브도메인으로 우회 |
| `LOGIN_HOST`, `LOGIN_HANDOFF_SECRET` | B(D-3 (b)를 택한 경우만) | web 서버 | `login.<플랫폼>` | (b) 선택 시 기동 실패 |

워커·`apps/api`는 로그인을 처리하지 않으므로 인증 단계 변수가 없다(`SUPABASE_ACCESS_TOKEN` 제외).

### 9.5 외부 콘솔

이 제품은 단독 Supabase 프로젝트라 AUTH-D1 (a)의 통합 "NOMAD 계정" 앱 세트를 쓰지 않고 자기 제공자 앱을 만든다(`develop/_shared/auth/README.md:18`, 단독 프로젝트 예외).

| 콘솔 | 단계 | 리디렉션 대상 | 메모 |
|---|---|---|---|
| Google Auth Platform | B | `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 이름은 플랫폼 브랜드(D-1). 승인된 JavaScript 원본에 테넌트 도메인을 모두 넣을 수 없으므로 서버 리디렉션 방식만 쓴다(원본 등록 필요 여부 미확인) |
| Supabase Auth(URL Configuration, Providers, SMTP, Email Templates) | B·C | Site URL = `https://newsroom.<플랫폼>`, Redirect URLs = 9.6절 | 메일 템플릿은 `{{ .RedirectTo }}` + `token_hash` 방식으로 각 테넌트 호스트의 `/auth/confirm`으로 돌아오게 한다(`develop/_shared/auth/README.md:27`). SMTP는 2절 메일 제공자 |
| 카카오 디벨로퍼스 | C1 | Supabase 콜백 | 비즈 앱 전환 후 `account_email` 필수 동의 권고(01장 8.1절). 앱 이름 플랫폼 브랜드 |
| 네이버 개발자센터 | C2 | `supabase_custom`: Supabase 콜백 1개 | 검수 통과 전 운영 `AUTH_PROVIDERS_READER`에 넣지 않는다(C2-6) |

### 9.6 결정 D-3: 테넌트 도메인의 리디렉션 URL

독자의 `redirectTo`(`https://<테넌트 호스트>/auth/callback`·`/auth/confirm`)는 Supabase Redirect URLs 허용 목록에 있어야 한다. 테넌트 호스트가 신문사 수만큼 늘어난다.

| 선택지 | 방식 | 장점 | 위험 | 권고 |
|---|---|---|---|---|
| (a) | 서브도메인은 와일드카드 패턴 `https://*.<플랫폼>/auth/**` 한 줄(와일드카드 지원은 Supabase 문서 기준 구현 시 확인). 커스텀 도메인은 `active` 직후 `news.domain_auth_redirect`가 관리 API(`PATCH /v1/projects/{ref}/config/auth`, `develop/_shared/auth/README.md:108`)로 `uri_allow_list`에 추가, 해지 시 제거 | 독자가 자기 신문 도메인에서 끝까지 로그인. 코드 단순 | 허용 목록 상한 미확인, 관리 토큰을 워커에 둠, 등록 실패 시 로그인 불가 | **권고**. 등록 실패·상한 도달 시 그 도메인의 로그인 버튼은 `<slug>.<플랫폼>/login`으로 보내고 완료 후 커스텀 도메인으로 일회용 코드 전달(아래 (b)의 전달부만 사용) |
| (b) | 중앙 로그인 호스트 `login.<플랫폼>`에서 로그인 → 일회용 코드(60초, 1회, `LOGIN_HANDOFF_SECRET` 서명, 대상 호스트 고정)로 테넌트 호스트 `/auth/handoff`에 세션 전달 | 허용 목록 1줄, 네이버 브리지도 가능 | 세션 전달 구현(토큰을 URL로 넘기지 않는 교환 설계 필요), 주소창 브랜드가 플랫폼으로 바뀜 | 대안 |

### 9.7 브랜드 메모(AUTH-D1 대응)

동의 화면(Google·카카오·네이버) 앱 이름과 로고는 플랫폼 브랜드(D-1 확정 전 "로컬뉴스 클라우드(가칭)")다. 독자 로그인 화면 본문에는 신문사 제호와 "로컬뉴스 클라우드 계정으로 로그인합니다. 같은 계정으로 다른 지역신문에도 로그인할 수 있습니다" 안내를 둔다. 신문사 브랜드의 동의 화면은 전용 DB(판매 모델 B, 엔터프라이즈) 신문사만 자기 프로젝트·자기 제공자 앱으로 제공한다(브리프 6절).

## 10. 멀티테넌트(화이트라벨) 적용

이 제품이 `Multi-tenant_Theming`의 첫 판매 적용 제품이다. 설계는 MT 문서를 따르고 여기서는 news에서 정한 값만 적는다. `0011_core_tenant_theming.sql`은 아직 staged이므로 모놀리스 `0002_tenant_theming.sql`(변환본)로 먼저 쓰고, 코어 승격은 06장 6절 요청으로 둔다(`Multi-tenant_Theming/README.md:225-228`).

### 10.1 `proxy.ts` 호스트 분기

| 순서 | 조건 | 동작 |
|---|---|---|
| 1 | 모든 요청 | 들어온 `x-tenant-*`, `x-host-kind` 헤더 삭제, host 정규화(소문자, 포트 제거) |
| 2 | host = 루트 도메인 또는 `www.` | `x-host-kind=marketing` → `(marketing)` |
| 3 | host = `NEWSROOM_HOST` | `x-host-kind=newsroom` → `(newsroom)`, 라우트 보호(`session_context`, 9.3절). `/api/r/*` 요청은 404 |
| 4 | host = `OPS_HOST` | `x-host-kind=ops` → `(ops)`, 비운영자 404 |
| 5 | host = `<slug>.<루트>`(예약어 제외) | `x-host-kind=reader`, `x-tenant-slug=<slug>` → `/_t/<host>/<경로>`로 재작성. `/api/newsroom/*`·`/api/ops/*`는 404 |
| 6 | 그 외 host | 커스텀 도메인 후보: `x-tenant-host=<host>` → `/_t/<host>/<경로>` |
| 7 | 테넌트 호스트의 레이아웃·Route Handler | `getTenant()`가 해석. `null`이면 "서비스 일시 중지"(410, 데이터 없음). `primary_domain`이 있고 현재 host가 서브도메인이면 같은 경로로 301. 해석 결과 `app_id`가 `news`가 아니면 404(`Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:14`) |
| 8 | 테넌트 호스트 미매칭 경로 | 이관 리디렉션 맵 조회 → 301(위험 #6), 없으면 404 |

proxy는 문자열 판별과 헤더·재작성만 하고 DB 호출은 서버 컴포넌트의 `getTenant()` 한 곳에서만 한다(`Multi-tenant_Theming/03_CODE_STRUCTURE.md:101`). 예외는 9.3절 라우트 보호(편집국·운영)뿐이다.

### 10.2 해석과 캐시

| 항목 | 값 |
|---|---|
| 해석 | `resolve_tenant(hostname, slug, 'news')`(anon 키). 요청 안은 React `cache()`, 요청 간은 태그 `tenant:<org_id>`, `host:<host>`(`Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:17-26`) |
| 해석 실패 | 300ms 초과·오류면 마지막 캐시 값, 없으면 404가 아니라 "일시적 오류" 화면(독자 사이트는 플랫폼 기본 브랜드로 신문사 콘텐츠를 보이면 안 되므로 MT 6장의 "기본 브랜드로 렌더"와 다르게 둔다, 제안) |
| 단계 0 | 구독 해지·정지 → `null` → "서비스 일시 중지". 데이터 노출 없음 |
| 법정 푸터 | 필요적 게재사항의 정본은 `news.newspapers`(M7)다. `tenant_settings.legal`은 쓰지 않는다(중복 방지, 제안). 매체정보 미완성이면 독자 사이트 공개 차단(NW-F-002) |
| 메뉴 | 독자 사이트 내비는 `news.sections`·`regions`(제품 데이터)에서 만든다. `tenant_settings.navigation`·`tenant_labels`(L2)는 MVP에서 쓰지 않는다(제안) |

### 10.3 캐시 태그 정본 (`src/lib/cache/tags.ts`)

| 태그 | 붙는 곳 | 무효화하는 동작 |
|---|---|---|
| `tenant:<org_id>`, `host:<host>` | 독자 레이아웃(테마·서체·파비콘) | 테마 게시·되돌리기, 도메인 상태 변경, 플랜 변경 |
| `news:<org>:home` | 홈 | 홈 레이아웃 게시, 톱·서브 지정 기사 게시·수정·취소, 속보 바 |
| `news:<org>:article:<id>` | 기사 상세, AMP 없음 | 기사 수정·정정·게시 취소, 댓글 설정 변경 |
| `news:<org>:section:<slug>`, `news:<org>:region:<code>`, `news:<org>:tag:<slug>`, `news:<org>:reporter:<id>` | 목록 페이지 | 해당 분류 기사 게시·취소 |
| `news:<org>:most-read` | 많이 본 뉴스(60초 최대 수명) | `news.stats_rollup` |
| `news:<org>:feeds` | RSS, 사이트맵, 뉴스 사이트맵 | 게시·취소(뉴스 사이트맵은 최근 2일 필터) |
| `news:<org>:profile` | 법정 푸터, 정책 페이지 | 매체정보 저장, 선거 모드 전환 |

### 10.4 테마 주입과 커스텀 도메인

| 항목 | 규칙 |
|---|---|
| 테마 CSS | `(reader)` 레이아웃이 `themeCss(tenant)`를 `<head>`의 nonce `<style>`로 서버 렌더(깜빡임 0). 허용 목록 의미 토큰만(`brand`, `accent`, 섹션 색은 템플릿 B만, `Multi-tenant_Theming/README.md:58-77`) |
| 서체 | 테넌트는 레지스트리 키만: `noto-serif-kr`, `source-han-serif`, `nanum-myeongjo`, `pretendard`(모두 OFL, `RESEARCH_DESIGN.md` 3장). KoPub 계열은 등록하지 않는다 |
| 자산 | 로고 3종 + 파비콘 + OG(1200x630) + 메일 머리. 제호 로고는 마스트헤드 높이 기준 |
| 편집국 콘솔 | 플랫폼 브랜드 고정(신문사 테마 미적용, 제안: 여러 신문사를 오가는 기자의 혼동 방지와 단순화). 단 조직 전환기에 신문사 로고 표시 |
| 커스텀 도메인 | MT 4장 흐름 그대로(`/api/tenant/domains` → Vercel 등록 → DNS 안내 → `news.domain_verify` → `active` → 캐시 무효화 → 완료 메일). news 추가: `active` 직후 `news.domain_auth_redirect`(9.6절), 사이트맵·canonical 대표 도메인 전환 |
| 메일 | 발신 이름 = 신문사 제호, 발신 도메인 = 플랫폼, `Reply-To` = 신문사 대표 메일(`Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:65-68`) |
| Powered by | 독자 푸터 하단에 플랫폼 표기. 숨김은 `features.hide_powered_by`(Pro 이상, 제안). 엔디소프트식 벤더 로고 강제는 하지 않는다(README 3절) |

### 10.5 플랜별 화이트라벨 단계

`theming_level`이 0이면 독자 사이트가 해석되지 않으므로 news의 모든 유효 플랜은 1 이상이어야 한다(seed 검사, 05장).

| 플랜 | `theming_level` | 쓰는 것 |
|---|---|---|
| `news_trial` | 2(seed: Standard 수준 체험) | L1. `news_custom_domains`=0이라 서브도메인만(체험 중 도메인 연결은 운영자 예외 `tenant_feature_overrides`) |
| `news_starter` | 1 | L1(로고·색·서체 프리셋·파비콘·OG), 서브도메인만 |
| `news_standard` | 2 | L1 + 커스텀 도메인(`news_custom_domains`=1) |
| `news_pro` | 2 | L1 + 커스텀 도메인 3 |
| `news_enterprise` | 3 | L2 + 슬롯(L3, 홈 전용 블록 등 건별). seed의 `news_custom_domains`=5로 MT 코어 상한(조직당 5개, TM004)에 맞췄다. 더 필요하면 코어 상한 조정을 요청한다(06장 6절). 전용 DB는 판매 모델 B |

커스텀 도메인 개수는 `news_custom_domains`를 Route Handler가 MT 코어 상한(조직당 5개, TM004)보다 먼저 검사한다(04장 2.2절 `/api/tenant/*` 행). 엔터프라이즈 10개는 위 표의 결정 전까지 5개로 동작한다.
