# 02 아키텍처: Stay(가칭)

근거 약어는 01장과 같다. SQL = `supabase/monolith/migrations/0002_stay_domain.sql`, seed = `supabase/monolith/seed.sql`.

2026-10-20 작성. 원본은 Next.js 14 Pages Router + API Routes + 자체 JWT + service_role 단일 경로였다(`docs/reviews/Airbnb_CloneCoding.md:9-15`). 이 문서는 플랫폼 표준 스택으로 다시 짜며, 공용 설계(`docs/products/_platform-core/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, `AUTH_ROADMAP.md`)는 인용만 하고 재정의하지 않는다.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router(RSC, Server Action, Route Handler), React 19, Tailwind CSS v4, shadcn/ui | Next 16.2.x | 플랫폼 표준(`docs/develop/live-poll/live-poll_develop.md` 6장 프로필), 01장 D14. 원본 Pages Router·styled-components·Redux는 07장 3절 폐기 |
| 인증 | Supabase Auth + `@supabase/ssr`(요청 단위 서버 클라이언트, 브라우저 클라이언트) | supabase-js 2.x | `SHARED_MODULES.md` 2장, 리뷰:62-64(#8~#10), :93(#5) |
| DB | Supabase Postgres 15, 모놀리스 `public` 스키마(모듈러 `stay` 2700은 SY-06-002) | PG 15 | README 5장, 01장 D12 |
| 확장 | `btree_gist`(예약·차단 배타 제약), `pgcrypto`, `vector`(코어 AI) | Supabase 제공 | 05장 1절, SQL:22 |
| 저장소 | Supabase Storage `public-assets` 버킷(숙소 사진, 공개 읽기), `org-files`(호스트 위키 원문, 비공개) | 코어 SECTION 8 | 05장 7절 #4. 원본 S3 업로드 폐기 |
| 지도 | 지도 어댑터 인터페이스(`src/lib/maps/`) + Google Maps 구현(브라우저 키·서버 키 분리) | Maps JavaScript API, Geocoding API | 01장 D6(카카오·네이버로 교체 가능), 리뷰:70(#16) |
| 레이트 리밋 | `rate_limit_hit`(DB 고정 윈도우). Route Handler 키는 IP HMAC | 코어 SECTION 6-C | 01장 5절. Redis 없음 |
| 검증 | zod(웹 경계, 허용 목록), pydantic(FastAPI 경계) | - | `SECURITY_BASELINE.md` 10장, 05장 7절 #1 |
| 3D | three.js + React Three Fiber + drei. 동적 import(`ssr: false`), 랜딩 히어로에서만 | React 19 호환 버전(구현 시 확인) | `docs/products/_design-guide/HERO_3D.md:47-48` |
| AI 서비스 | FastAPI(Python) `apps/api`. 공용 ai-service 위에 stay 확장만 | Python 3.12(제안, 구현 시 확인) | `AI_ARCHITECTURE.md:132-160` |
| AI 오케스트레이션 | LangChain(모델, splitter), LangGraph(그래프 2개, 5.2절) | 구현 시 확인 | `AI_ARCHITECTURE.md:109-119` |
| LLM | FastAPI 라우터: 상용 `anthropic`, `openai`, `google` + 오픈소스 `oss-llm`. 기능별 체인은 5.1절 | 모델 id는 `ai_model_prices` 행 | seed:33-46 |
| RAG | pgvector(코어 `ai_chunks`), 임베딩 `oss-embed`(숙소별 컬렉션 `listing-<id>`) | 코어 SECTION 11 | 05장 6절 |
| 채팅 운영 | 공용 자체 호스팅 Dify 1개, 제품 앱 `stay-assistant`(Chatflow) | 설치 버전 문서로 확인 | `AI_ARCHITECTURE.md:58-71` |
| 음성 | `packages/core-voice`: ElevenLabs + 공용 오픈소스 음성 서버 | 구현 시 확인 | `VOICE_ARCHITECTURE.md:5-72` |
| 잡 워커 | `apps/api/app/jobs/runner.py`(코어 `claim_jobs` SKIP LOCKED), 크론 스케줄 | 코어 SECTION 7 | 4절 |
| 이메일 | 거래 메일 발송 서비스(미정, 구현 시 선택. 01장 6절 제3자 제공) | - | 01장 SY-F-024 |
| 테스트 | Vitest(웹 단위), Playwright(E2E), pytest(FastAPI, 평가셋), PGlite·로컬 Supabase SQL 스모크 | - | 06장 SY-06-030, 035, 037 |
| 패키지 | pnpm(웹, 락파일 1개), uv(Python) | - | 리뷰:78(#24) |
| 배포 | Vercel(웹, icn1), Supabase(ap-northeast-2), Railway(FastAPI·워커) | - | 7절 |

쓰지 않는 것: Pages Router, `getInitialProps`/`getServerSideProps`, Redux·next-redux-wrapper, styled-components, axios(전역 기본값 금지 규칙과 함께 fetch로 대체), `jsonwebtoken` 자체 토큰, `refresh_tokens` 테이블, aws-sdk·formidable, JSON 파일 저장소(07장 3절). 스타일은 반드시 Tailwind CSS v4(4.x 고정, `@import "tailwindcss"`, `@theme`)이고 `tailwind.config.js`와 v3 문법은 쓰지 않는다(`docs/products/_design-guide/DESIGN_SYSTEM.md:67`).

## 2. 모듈 경계

06장 1절 소유 경계의 기준이다. 웹 루트는 `apps/web/`, AI·잡은 `apps/api/`.

| 모듈 | 디렉토리 | 책임 |
|---|---|---|
| 공개 화면 | `apps/web/src/app/(public)/`(홈 `page.tsx`, `search/`, `listings/[id]/`, `listings/[id]/book/`) | 랜딩, 검색, 상세(RSC, 공개 RPC), 예약 화면. 비로그인 접근 가능 |
| 게스트 화면 | `apps/web/src/app/(guest)/`(`trips/`, `wishlist/`, `settings/ai/`) | 내 여행, 리뷰 작성, 찜, AI 설정. 로그인 필요 |
| 호스트 화면 | `apps/web/src/app/(host)/host/`(`listings/[id]/edit/`, `listings/[id]/calendar/`, `reservations/`, `wiki/`) | 등록 마법사, 달력, 예약함, 위키. 숙소가 없으면 "숙소 올리기" 진입만 |
| 인증 | `apps/web/src/app/(auth)/`, `src/app/auth/callback/`, `src/app/api/dev/login/`, `src/lib/auth/`, `src/middleware.ts` | 로그인·가입·재설정, 콜백, Mock. 인증 단계 분기는 `src/lib/auth/`·로그인 화면·콜백에만 둔다(9.2절, `AUTH_ROADMAP.md` 3.1절) |
| 온보딩 | `apps/web/src/app/onboarding/` | 약관(B 이후), AI 처리 방식(국외 이전 동의) |
| 도메인 서버 계층 | `apps/web/src/server/<도메인>/`(`listings/`, `photos/`, `reservations/`, `reviews/`, `ai/`) | zod 허용 목록, RPC 호출, SQLSTATE → 사용자 오류 변환. 화면은 이 함수만 부른다 |
| Supabase 클라이언트 | `apps/web/src/lib/supabase/`(`server.ts`, `browser.ts`, `admin.ts`) | `server.ts`는 요청마다 `cookies()`로 새로 만든다. `admin.ts`(service_role)는 잡 enqueue·크론·운영 스크립트만 import(ESLint `no-restricted-imports`로 화면·Server Action에서 금지) |
| HTTP 공통 | `apps/web/src/lib/http/` | 응답 봉투 `{ok, data}` / `{ok:false, error:{code, message}}`, 내부 오류 문자열 비노출(리뷰:69 #15) |
| 지도 어댑터 | `apps/web/src/lib/maps/`, `src/app/api/maps/` | `MapProvider` 인터페이스(지도 렌더, 지오코딩, 장소 자동완성). 서버 키는 Route Handler에서만 |
| 업로드 | `apps/web/src/app/api/uploads/` | 서명 업로드 URL 발급(경로 규칙, MIME, 크기) |
| AI 게이트 | `apps/web/src/app/api/ai/`, `src/server/ai/` | 대화 매핑, 서명 토큰 발급, 선차감·정산, Dify 중계와 장애 시 직접 경로 |
| 음성 | `apps/web/src/app/api/voice/`, `src/components/voice/` | 고지 확인, STT, TTS |
| 위키 API | `apps/web/src/app/api/host/wiki/` | 업로드, ingest enqueue, 검수·발행, 이력(FastAPI 프록시) |
| UI | `apps/web/src/components/`(`ui/`, `search/`, `listing/`, `reviews/`, `ai/`, `hero3d/`) | props만 받는 컴포넌트. 데이터 호출 없음 |
| 정적 데이터 | `apps/web/src/lib/static-data.ts` | 건물·침대·편의시설 목록(원본 `lib/staticData.ts` 이식, SY-06-045) |
| AI 서비스 | `apps/api/app/ai/`(`rag/stay_listing.py`, `graphs/stay_listing_assist.py`, `graphs/stay_review_summary.py`, `llm/stay_search_parse.py`, `wiki/stay.py`, `compliance/stay.py`) | 라우터, RAG, 그래프, 위키, 출력 규칙 |
| 잡 | `apps/api/app/jobs/` | 4절 잡 핸들러, 크론 |
| DB | `supabase/`(migrations, seed, tests, cron) | SY-06-001 소유 |
| 운영 스크립트 | `scripts/ops/`, `scripts/dev/` | 숙소 정지, 시드 페르소나 |

AI·음성·3D 경계: 브라우저는 `/api/ai/*`, `/api/voice/*`만 부르고 Dify·FastAPI·제공자를 직접 부르지 않는다. 3D 히어로는 `components/hero3d/`에서만 three.js를 import하며 다른 화면 번들에 들어가지 않는다.

## 3. 공용 모듈 사용

| 공용 모듈(`SHARED_MODULES.md`) | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| core-auth (2장) | 세션, `requireSession('stay')`, 인증 단계 제공자 계약(`packages/core-auth/providers`, 앱은 `src/lib/auth/`) | 게스트·호스트 레이아웃, Server Action, `/api/*` | 비로그인 공개 화면은 쓰지 않는다 |
| org (3장) | 호스트 개인 조직, Phase 2 공동 호스트 | 호스트 화면 | 1인 1워크스페이스 |
| toss (5장), webhooks (6장) | Phase 2 예약 결제·Host Plus | `api/billing/*`, `api/webhooks/toss`(Phase 2) | 베타 비활성(01장 D2) |
| audit (15장) | 숙소 생성·전이·삭제, 예약 생성·응답·취소 | SQL RPC 내부 `write_audit` | 게스트 행동은 게스트 개인 조직에 기록(05장 6절) |
| rate limit (`CORE_SPEC.md` 12장) | 01장 5절 수치 | SQL `stay_rate_limit`, Route Handler | 키 규약 `stay:<route>:<id>` |
| storage (14장) | 숙소 사진(`public-assets`), 위키 원문(`org-files`) | `api/uploads/*`, `api/host/wiki/*` | 경로 첫 단계 = org_id |
| credits (4장) | AI·음성 선차감과 정산, 가입 크레딧 100 | `api/ai/*`, `api/voice/*`, `jobs/settle.py` | 검색·예약·리뷰·찜 경로에서는 호출하지 않는다 |
| jobs | 4절 잡 5종 | Server Action·Route Handler(enqueue), `apps/api` 워커 | |
| ai-gateway | 대화 매핑, 서명 토큰, 선차감·정산, Dify 중계 | `src/app/api/ai/`, `src/server/ai/` | `SHARED_MODULES.md:498` |
| ai-service | 라우터, RAG, 위키, 그래프 2개, `/tools/answer` | `apps/api` | 제품 확장은 2절 `apps/api` 행 |
| dify | 앱 `stay-assistant` | `src/app/api/ai/chat` | Dify 로그 30일 |
| core-voice | STT, TTS | `src/app/api/voice/` | |
| llm-wiki | 호스트 위키 | `apps/api/app/ai/wiki/stay.py`, `(host)/host/wiki/` | 조직·앱 단위, published만 도우미 근거 |
| compliance (13장) | 공용 모듈로는 사용 안 함 | - | AI 출력 검사는 그래프 compliance 노드(`app/ai/compliance/stay.py`) |
| llm gateway, fal, weasyprint, sns, automation, affiliate, oauth(6-A) | 사용 안 함 | - | 6-A는 네이버 브리지 선택 시 재검토(06장 6절 R-5) |

## 4. 잡과 워커

페이로드 스키마는 04장 4절. 큐는 하나(`stay`)이고 워커는 `apps/api/app/jobs/runner.py`가 소비한다.

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `stay.photo.process` | `stay` | FastAPI 워커(Python, Pillow) | 없음 | 3회, 1분 간격 | 해당 없음. 최종 실패 시 원본만 표시하고 운영 알림 |
| `stay.ai.index_listing` | `stay` | FastAPI 워커 | 없음(플랫폼 예산, 01장 4.2절) | 3회, 5분 간격 | 해당 없음 |
| `stay.wiki.ingest` | `stay` | FastAPI 워커 | 문서당 3(오픈소스) / 5(상용) | 2회 | 최종 실패 시 선차감 전액 |
| `stay.ai.review_summary` | `stay` | FastAPI 워커, 매일 04:30 KST 스케줄 + 리뷰 10건 도달 시 1회 | 없음(플랫폼 예산) | 1회, 다음 날 재실행 | 해당 없음 |
| `stay.notify.email` | `stay` | FastAPI 워커 | 없음 | 3회, 1·5·15분 | 해당 없음 |

| 크론 | 주기 | 호출 | 실패 처리 |
|---|---|---|---|
| `stay_run_maintenance` | 매시간 정각 | 워커가 service_role로 `rpc('stay_run_maintenance')`(SQL:1101) | 멱등. 다음 시간 재실행. 결과 jsonb를 로그 |
| AI 정산 | 5분 | `apps/api/app/jobs/settle.py`가 `ai_usage.settled_at is null` 10분 경과 행 정산 | 멱등 키로 중복 차감 없음(SY-06-036) |
| 레이트 리밋 정리 | 매일 04:00 KST | `purge_rate_limit_buckets()` | 코어 스케줄과 같다 |
| 잡 회수 | 5분 | `reap_stale_jobs(600)` | 코어 |

| enqueue 시점 | 잡 |
|---|---|
| 사진 INSERT 직후(업로드 완료 Server Action) | `stay.photo.process` |
| `transition_listing('published')`, 게시 숙소의 공개 필드·사진 캡션 수정, unlisted 전환 | `stay.ai.index_listing`(unlisted면 `action:'deactivate'`) |
| 위키 문서 업로드 | `stay.wiki.ingest` |
| 예약 생성·응답·취소·만료 | `stay.notify.email`(정리 RPC 결과는 워커가 만료·완료 예약 id를 조회해 enqueue) |

크론 라우트를 공개 URL로 열지 않는다. 크론은 워커 프로세스 내부 스케줄러가 실행한다(`SECURITY_BASELINE.md` 13장). Vercel Cron을 쓰면 `CRON_SECRET` 헤더 검사 Route Handler 하나만 두고 그 안에서 워커에 enqueue한다(제안).

## 5. AI 라우팅

설계 정본은 `AI_ARCHITECTURE.md:73-92`(LLM 라우터), `VOICE_ARCHITECTURE.md:40-48`(음성)이다. 이 절은 stay 기능별 기본값(5.1)과 그래프(5.2), 숙소 근거 범위(5.3)만 정한다. 이미지 생성 제공자는 없다.

### 5.1 기능별 라우팅 기본값

seed:33-46과 같다. `org_id`는 모두 null(플랫폼 기본), `app_id='stay'`. 모든 값은 제안이다.

| feature | kind | mode | chain | force_open_source |
|---|---|---|---|---|
| `chat` | llm | auto | anthropic → openai → google → oss-llm | false |
| `stay.search_parse` | llm | auto | oss-llm → anthropic | false |
| `stay.listing_assist` | llm | auto | anthropic → openai → oss-llm | false |
| `stay.review_summary` | llm | open_source | oss-llm | true |
| `stay.knowledge` | embedding | open_source | oss-embed | false |
| `wiki.query` | llm | auto | oss-llm → anthropic | false |
| `wiki.ingest` | llm | auto | oss-llm → anthropic | false |
| `wiki.lint` | llm | auto | oss-llm → anthropic | false |
| `dify.aux` | llm | open_source | oss-llm | true |
| `voice_chat` | stt | auto | oss-voice → elevenlabs | false |
| `voice_chat` | tts | auto | elevenlabs → oss-voice | false |

국외 이전에 동의하지 않은 조직은 `resolve_ai_route`가 상용 제공자를 체인에서 빼므로 `auto` 행도 오픈소스만 쓴다(01장 SY-F-033). seed 끝의 체인 검사 DO 블록이 존재하지 않는 제공자·오픈소스 모드의 상용 제공자를 거부한다(seed:49-62).

### 5.2 LangGraph 그래프

| 그래프 | 노드 | 사람 승인 지점 | compliance | 실행 방식 |
|---|---|---|---|---|
| `stay.listing_assist` | `load`(숙소 공개 필드, 편의시설, 사진 캡션; service_role로 호스트 조직 숙소만) → `draft`(제목 3안 50자 이하, 설명 1안 500~1,500자) → `compliance` → 결과 | 호스트가 초안 중 하나를 고르고 고친 뒤 저장한다. 그래프는 `listings`에 쓰지 않는다 | 허위·과장, 차별 문구, 연락처·URL, 확인되지 않은 수치 검사. 걸린 문장만 1회 재작성, 재실패 시 해당 문장 삭제 | Route Handler가 `POST /graphs/stay.listing_assist/runs` 호출, SSE로 노드 진행 전달(p95 20초, 잡 아님) |
| `stay.review_summary` | `load`(보이는 리뷰 최근 100건, 리뷰어 이름 제외) → `summarize`(3~5줄) → `compliance` → `ai_runs.output` 저장 | 없음(운영자가 숨김 가능). 요약은 리뷰 원문을 대신하지 않고 상세에서 원문 목록과 함께 표시 | 이름·연락처 제거, 대표성 단정("모든 게스트") 금지, 원문 인용 1문장 이하 | 잡 `stay.ai.review_summary`. 모든 LLM 호출 오픈소스 강제(seed `force_open_source=true`) |

`stay.search_parse`는 그래프가 아니라 단일 LLM 호출(JSON 스키마 출력, pydantic 검증)이다. 실행 기록은 `ai_usage`만 남긴다.

### 5.3 숙소 도우미 근거 범위

| 근거 | 포함 | 이유 |
|---|---|---|
| 숙소 공개 필드(제목, 설명, 하우스 룰, 편의시설, 침대 구성, 체크인·아웃 시각, 지역명) | 예 | `get_listing_public`과 같은 범위 |
| 사진 캡션 | 예 | 공개 |
| 호스트 위키 published 페이지 | 예 | 호스트 검수(01장 SY-F-031) |
| `listing_private`(정확한 주소, 좌표, 체크인 안내) | 아니오 | 05장 7절 #6, 01장 D9 |
| 다른 게스트의 예약·리뷰 원문 | 아니오(리뷰는 요약만, Phase 2 검토) | 01장 6.1절 |

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 높음 7건 중 구조·설정 결함 2건(#5, #7)은 여기, 보안·데이터 결함 5건(#1, #2, #3, #4, #6)은 05장 7절에 있다. 합계 7건 = 차단 설계 7건.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Airbnb_CloneCoding.md` 3장 #5 | `docs/reviews/Airbnb_CloneCoding.md:59`, `:93` | SSR 중 `axios.defaults.headers.common.Cookie`에 요청 쿠키를 넣어 서버 프로세스 전역 상태로 사용자 간 쿠키가 섞인다 | (1) Pages Router `getInitialProps`와 axios를 버리고 App Router 서버 컴포넌트·Server Action에서 `src/lib/supabase/server.ts`가 요청마다 `cookies()`로 새 클라이언트를 만든다. 서버에서 자기 API를 HTTP로 다시 부르지 않는다(원본의 `getServerSideProps` → `/api/*` 재호출 제거). (2) 모듈 최상위에 사용자별 클라이언트·헤더·쿠키를 두지 않는다는 규칙을 ESLint `no-restricted-syntax`(전역 `defaults.headers`, 모듈 스코프 `createServerClient` 금지)와 CI grep으로 검사. (3) 동시 요청 E2E: 사용자 2명이 동시에 내 여행을 열면 각자 자기 예약만 보인다 | 2절, SY-06-004, SY-06-037 |
| 같은 문서 3장 #7 | `docs/reviews/Airbnb_CloneCoding.md:61`, `:97` | `.gitignore`가 `node_modules`뿐이고 git 인덱스에 `.env.local`(AWS 키, JWT 비밀), `node_modules`, `.next`가 올라가 있다 | (1) 새 개발 폴더는 처음부터 `.gitignore`(`.next`, `.env*`(단 `.env.example` 허용), `*.tsbuildinfo`, `.DS_Store`, `.swc`, `node_modules`)와 `.env.example`을 둔다. (2) 비밀 스캔 CI(gitleaks 등, 미확인: 도구 선택)가 푸시·PR에서 키 패턴을 차단. (3) 서비스 키는 Vercel·Railway·Supabase 대시보드 환경변수에만 둔다. (4) 원본 저장소는 커밋 전에 인덱스에서 제거하고, 원본 `.env.local`의 AWS 키·JWT 비밀을 재발급·폐기한다(07장 5절). 원본 S3 키는 새 구조에서 쓰지 않으므로 폐기 | SY-06-006, 07장 5절 |

## 7. 배포 토폴로지

| 구성 | 위치 | 네트워크 경계 |
|---|---|---|
| 웹(Next.js) | Vercel icn1 | 공개. 사용자 요청은 anon 키 + 사용자 세션(RLS). service_role 키는 서버 번들의 `admin.ts`에만(잡 enqueue, 운영) |
| DB, Auth, Storage | Supabase ap-northeast-2(단독 프로젝트) | 브라우저는 anon 키로 공개 RPC·세션 RLS 경로만. 사진은 `public-assets` 공개 URL(CDN) |
| AI 서비스 + 잡 워커(FastAPI) | Railway(미확인: 서울 인근 리전 목록), 서비스 2개(API, 워커) | API는 서명 토큰 또는 Dify 내부 키 + 대화 매핑만 수락. 아웃바운드: Supabase(service_role), 상용 AI 제공자, 오픈소스 LLM·임베딩·음성 서버, 이메일 발송 서비스 |
| 공용 Dify | 운영사 자체 호스팅 1개(`D:\WorkSpace\DEV\platform-dify\`, 제안, 설치 `docs/develop/_shared/dify/`) | Next.js·FastAPI에서만 접근. 로그 30일 |
| 공용 GPU 서버 | `D:\WorkSpace\DEV\platform-llm\`, `platform-voice\`(제안, 설치 `docs/develop/_shared/llm/`, `voice/`) | FastAPI·Next.js(서명 토큰 scope `voice`)에서만. 개발 중 미준비면 오픈소스 강제 기능(리뷰 요약, `dify.aux`)을 비활성화하고 나머지는 상용 체인만 |
| Google Maps Platform | 외부 | 브라우저 키는 HTTP 리퍼러 제한 + Maps JavaScript API만. 서버 키는 IP 제한 없이 API 제한(Geocoding, Places)만 걸고 Vercel 서버에만(미확인: Vercel 고정 IP 없음에 따른 제한 방식) |

```
브라우저 ──RSC/Server Action──> web(Vercel) ──요청 단위 세션 클라이언트──> Supabase(RLS, 공개 RPC)
브라우저 ──/api/ai/*, /api/voice/*──> web ──서명 토큰──> FastAPI(Railway) ──> LLM·음성 제공자 / 오픈소스 서버
                                        └──Dify Chat API──> Dify ──HTTP 노드(내부 키)──> FastAPI /tools/answer
web ──enqueue_job(service_role)──> Supabase jobs <──claim_jobs── 워커(Railway) ──> Storage·메일·RAG
브라우저 ──사진 PUT(서명 URL)──> Supabase Storage public-assets/<org_id>/listings/<listing_id>/...
```

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase URL | 공개 | 기동 실패 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 공개 RPC, 세션 RLS 경로 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 잡 enqueue, 크론, 운영 스크립트, FastAPI | 서버 전용(`admin.ts`, `apps/api`) | 기동 실패 |
| `SUPABASE_DB_SCHEMA`, `STAY_DB_SCHEMA` | `public`(모놀리스) / `core`, `stay`(모듈러) | 서버 | 기본 `public` |
| `NEXT_PUBLIC_APP_URL` | 콜백 origin, OG URL, `next` 검증 기준 | 공개 | 기동 실패 |
| `NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY` | 지도 렌더(리퍼러 제한) | 공개 | 지도 대신 목록만 표시 + 운영 알림 |
| `GOOGLE_MAPS_SERVER_KEY` | 지오코딩·장소 자동완성(Route Handler) | 서버 전용 | 위치 입력 단계 비활성 |
| `MAP_PROVIDER` | `google`(기본) / `kakao` / `naver`(D6) | 서버 | 기본 `google` |
| `NEXT_PUBLIC_KAKAO_MAP_KEY`, `KAKAO_REST_API_KEY` | 카카오맵 렌더(JavaScript 키, 도메인 제한) / 주소 검색(REST 키) — 변수명은 제안, 발급 절차 미확인 | 공개 / 서버 전용 | 해당 제공자 비활성 |
| `NEXT_PUBLIC_NAVER_MAP_CLIENT_ID`, `NAVER_MAP_CLIENT_SECRET` | 네이버 지도 렌더 / 지오코딩 — 변수명은 제안, 발급 절차 미확인 | 공개 / 서버 전용 | 해당 제공자 비활성 |
| `OPENWEATHER_API_KEY` | OpenWeatherMap 날씨(04장 6.5절). **키 값은 저장소·문서·디자인·로그에 넣지 않는다** | 서버 전용(Route Handler) | 날씨 위젯 숨김 + 운영 알림 |
| `FX_PROVIDER`, `FX_API_KEY` | 환율 제공자 선택·키(04장 6.6절, D19) | 서버 전용 | 환산 표기 숨김, 원화 가격만 표시 |
| `STAY_IP_HMAC_SECRET` | 비로그인 레이트 리밋 키 HMAC(32바이트 이상) | 서버 전용 | 기동 실패 |
| `CRON_SECRET` | Vercel Cron을 쓸 때만 크론 Route Handler 인증 | 서버 전용 | 크론 라우트 404 |
| `EMAIL_PROVIDER_API_KEY`, `EMAIL_FROM` | 거래 메일 | 워커 전용 | 메일 잡 실패 + 운영 알림(예약 흐름은 계속) |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY` | Phase 2 결제 | 클라이언트 키만 공개 | Phase 2부터 필수 |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` | 상용 LLM | FastAPI 전용 | 해당 제공자만 비활성(체인에서 다음으로) |
| `OSS_LLM_BASE_URL`, `OSS_EMBED_BASE_URL` | 오픈소스 LLM·임베딩 | FastAPI 전용 | 기동 실패(리뷰 요약, 숙소 색인에 필수) |
| `AI_TOKEN_PRIVATE_KEY`, `AI_TOKEN_KID` | EdDSA 서명 토큰 발급 | Next.js 서버 전용 | 기동 실패 |
| `AI_TOKEN_JWKS_URL` | 서명 토큰 공개키 | FastAPI, 오픈소스 음성 서버 | 기동 실패 |
| `AI_SERVICE_URL` | FastAPI 주소 | Next.js 서버 | AI 기능 비활성 + 오류 표시 |
| `DIFY_API_URL`, `DIFY_APP_KEY_STAY` | Dify Chat API, `stay-assistant` 앱 키 | Next.js 서버 전용 | 채팅은 FastAPI 직접 경로만 + 운영 알림 |
| `DIFY_INTERNAL_API_KEY` | Dify HTTP 노드 → FastAPI 인증 | FastAPI, Dify(비밀) | FastAPI 기동 실패 |
| `DIFY_USER_HMAC_SECRET` | `dify_user = HMAC(org:sub)` | Next.js 서버 전용 | 기동 실패 |
| `ELEVENLABS_API_KEY`, `OSS_VOICE_BASE_URL` | 상용·오픈소스 음성 | Next.js 서버 전용 | 해당 제공자 비활성. 둘 다 없으면 음성 버튼 숨김 |
| `AI_CROSS_BORDER_NOTICE_VERSION`, `STAY_VOICE_NOTICE_VERSION` | 고지문 버전 | Next.js 서버 | 기동 실패 |
| `NEXT_PUBLIC_HERO3D_ENABLED` | 3D 히어로 끄기 스위치 | 공개 | 기본 true |

원본과의 차이: 원본 `.env.local`에는 `JWT_SECRET`, `S3_BUCKET_NAME`, `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_GOOGLE_MAP_API_KEY`, `ACCESSKEY_ID`, `SECRET_ACCESSKEY_ID`만 있었고 코드가 읽는 이름과 달랐다(`docs/reviews/Airbnb_CloneCoding.md:71` #17). 새 구조에서 `JWT_*`, `S3_*`, `ACCESSKEY_*`, `NEXT_PUBLIC_API_URL`은 쓰지 않는다. 모든 변수는 기동 시 zod로 검증하고(`src/lib/env.ts`, SY-06-004) `.env.example`에 같은 목록을 둔다(SY-06-006). 인증 단계 변수는 9.3절.

## 9. 인증 단계

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`(확정 결정 22). 이 절은 airbnb(가입 정책 open)에 적용한 결과만 적는다. 로그인하는 사람은 게스트와 호스트(같은 계정)다.

### 9.1 단계표

| 단계 | 로그인 | 진입 게이트 | 이 제품 작업 | 근거 |
|---|---|---|---|---|
| A(MVP 개발) | 로컬 Supabase 시드 계정 원클릭 Mock. `signInWithPassword`로 실제 JWT | W0부터 | SY-06-003 | AUTH_ROADMAP 2장 |
| B(공개 베타 전) | Google + 이메일(가입, 로그인, 비밀번호 재설정). 배포 환경 Mock 차단 | G1 | SY-06-039 | AUTH_ROADMAP 4, 5장 |
| C1 | 카카오(Supabase 기본 제공자 `kakao`) | G2 | SY-06-040 | AUTH_ROADMAP 7.1절, 01장 D15 |
| C2 | 네이버(`custom:naver` 또는 서버 브리지, 스파이크로 결정) | G2 | SY-06-041 | AUTH_ROADMAP 7.2절, 01장 D16 |

게이트 판정은 사람이 하고 task `log.md`에 `[DECISION] G1 통과`로 남긴다(06장 8.2절).

### 9.2 구성과 제공자 콘솔 설정

| 위치 | 하는 일 | 단계 분기 허용 |
|---|---|---|
| `src/lib/auth/` | `getAuthConfig()`(env 검증), `isMockAuthAllowed()`, `listLoginOptions('stay')`, `finishLogin('stay', next)`, `providers/kakao.ts`, `providers/naver.ts` | 예 |
| `src/app/(auth)/login/`, `signup/`, `reset-password/` | 개발용 패널(A), Google 버튼·이메일 폼(B), 카카오·네이버 버튼(C) | 예 |
| `src/app/auth/callback/` | 코드 교환 → `finishLogin` | 예 |
| `src/app/api/dev/login/` | Mock 로그인(로컬 전용, 아니면 404) | 예 |
| `src/app/api/auth/naver/` | C2 브리지 경로를 택한 경우만 | 예 |
| 그 밖의 모든 코드(`(public)`, `(guest)`, `(host)`, `server/*`, `api/ai/*`, `api/voice/*`, `apps/api`) | `requireSession('stay')`·`session_context`만. `AUTH_MODE`·페르소나 이메일로 분기하지 않는다 | 아니오(CI grep, SY-06-003) |

| 콘솔 | 단계 | 설정 |
|---|---|---|
| Google Cloud | B | 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback`. 범위 `openid email profile` |
| Supabase Authentication | B·C | Providers, Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(미리보기 도메인은 명시 등록) |
| 카카오 디벨로퍼스 | C1 | REST API 키, Client Secret, Redirect URI = Supabase 콜백, 동의항목 `profile_nickname`, `profile_image`, (비즈 앱) `account_email` |
| 네이버 개발자센터 | C2 | 애플리케이션 등록·검수. Callback = Supabase 콜백(`supabase_custom`) 또는 `https://<도메인>/api/auth/naver/callback`(브리지). 원본 콜백 경로(`/api/auth/naver/callback`)와 같은 형태지만 코드는 새로 쓴다(07장 6절) |

`finishLogin` 순서(AUTH_ROADMAP 3.2절): `session_context('stay')` → `entitled=false`면 `bootstrap_app_for_org('stay')` 1회(모놀리스는 가입 트리거가 이미 부트스트랩) → `status` 분기(suspended 403) → B 이후 약관 미동의면 `/onboarding` → `next` 검증(기본 `/`) → 감사 `auth.login`.

### 9.3 단계별 환경변수 (AUTH_ROADMAP 3.3절 중 해당분. 8절 표에 더한다)

| 변수 | 단계 | 배치 | 누락 시 |
|---|---|---|---|
| `AUTH_MODE` | A·B·C | web 서버. FastAPI·워커에는 두지 않는다 | `live`. 로컬 `.env.example` 기본 `mock`. `mock`인데 Supabase 호스트가 루프백이 아니거나 `VERCEL_ENV`가 있으면 기동 실패 |
| `AUTH_PROVIDERS` | B·C | web | live에서 0개면 기동 실패. B `google,email`, C1 뒤 `kakao` 추가, 네이버 검수 뒤 `naver` 추가 |
| `DEV_SEED_PASSWORD` | A(로컬 전용) | web, `scripts/dev/` | Mock 모드 기동 실패 |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | B | 로컬 `supabase/config.toml`의 `env()`만. 원격은 Supabase 대시보드 | Google 버튼 비활성 |
| `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET` | C1 | 같은 방식 | 카카오 버튼 비활성 |
| `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`, `NAVER_AUTH_PATH` | C2 | `supabase_custom`이면 등록 스크립트만, `bridge`면 web 서버 전용 | 네이버 버튼 비활성 |
| `AUTH_BRIDGE_SECRET` | C2 브리지만 | web 서버 전용, 32바이트 이상 | 브리지면 기동 실패 |

원본의 `GOOGLE_REDIRECT_URI`, `KAKAO_REDIRECT_URI`, `NAVER_REDIRECT_URI`(앱 콜백을 앱이 직접 처리)는 쓰지 않는다. 콜백은 Supabase가 받고 앱은 `/auth/callback`에서 코드만 교환한다.

### 9.4 콜백 규칙

| 규칙 | 내용 |
|---|---|
| `next` | 내부 경로만 허용: `/`로 시작하고 `//`·`/\`로 시작하지 않으며, `new URL(next, NEXT_PUBLIC_APP_URL).origin`이 앱 origin과 같을 때만. 아니면 `/`로 |
| state·PKCE | Supabase Auth가 처리한다(원본 Google·카카오 state 누락 #9 해소, 리뷰:63) |
| 같은 이메일 | Supabase Auth의 계정 연결 정책(자동 연결 여부는 대시보드 설정, 미확인: 기본값)에 따른다. 원본처럼 유니크 위반으로 실패하지 않게 콜백 오류를 "이미 이메일로 가입한 계정입니다. 이메일로 로그인한 뒤 연결하세요"로 안내(리뷰:64 #10). 계정 연결 화면은 AUTH_ROADMAP 7.3절(C단계, P1) |
| 오류 | 콜백 실패는 `/login?error=<코드>`로. 원문 오류 메시지를 쿼리에 싣지 않는다 |
| 쿠키 | `@supabase/ssr` 세션 쿠키(HttpOnly, Secure, SameSite=Lax). 원본 `access_token`·`refresh_token` 쿠키(Secure 없음, 리뷰:74 #20)는 쓰지 않는다 |

### 9.5 비로그인 사용자 흐름

| 흐름 | 식별 | 단계와의 관계 |
|---|---|---|
| 홈·검색·상세·리뷰 목록·예약 불가 달력 | 없음. 공개 RPC 4개(05장 4절)를 anon 키로 | 단계와 무관. 레이트 리밋은 IP HMAC 키(01장 5절) |
| 예약·찜·도우미·호스트 시작 버튼 | 누르면 `/login?next=<현재 경로>`로 보내고 로그인 후 복귀 | 로그인 수단만 단계별로 다르다. 공개 화면에 로그인 버튼 외 단계별 분기 없음 |
| sitemap, robots, OG | 없음 | 단계와 무관 |
