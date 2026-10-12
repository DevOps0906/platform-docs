# 02 아키텍처: NOMAD Blog

작성일 2026-10-12. 공용 모듈은 `docs/products/_platform-core/SHARED_MODULES.md`를 참조만 한다. 재정의하지 않는다.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router, React, TypeScript | Next 16.x, React 19.x(원본과 같은 메이저, `latest` 금지) | `docs/reviews/NOMAD_Shorts_Maker.md:16`, `SECURITY_BASELINE.md` 13장 |
| UI | Tailwind v4, shadcn/ui, lucide 아이콘 | 원본과 같음 | `docs/reviews/NOMAD_Shorts_Maker.md:16`, `_design-guide/DESIGN_PRINCIPLES.md` 6단계 |
| 에디터 | TipTap(StarterKit, Link, Image, Table) + 제품 노드 2종(AffiliateCard, DisclosureBlock) | 원본과 같은 메이저 | `NOMAD Shorts Maker/src/components/posts/MultiChannelEditor.tsx:4-7` |
| 검증/상태 | zod, React Hook Form, TanStack Query | - | `docs/products/00_MERGE_ANALYSIS.md:79`(BS 구성) |
| HTML sanitize | 서버: 허용 목록 기반 sanitize(예: `sanitize-html`), 클라이언트 미리보기도 서버 렌더 결과만 | 구현 시 선택 | `SECURITY_BASELINE.md` 10장 |
| DB/인증 | Supabase(Postgres 15, Auth, Storage, Realtime) | - | `_supabase-modular/README.md` |
| 워커 | Node 20+ TS 프로세스 `workers/blog-worker`, `@platform/core-jobs` `runWorker`(core.jobs `SKIP LOCKED`), Playwright Chromium | Playwright는 원본과 같은 메이저 | `SHARED_MODULES.md` 16장 |
| 큐 | Redis/BullMQ 없음. `core.jobs`가 큐이자 상태 정본 | - | 제안(blog 잡은 단계가 1~2개라 FlowProducer가 필요 없음). 확정 결정 6은 video 워커 결정 |
| 결제 | Toss Payments(공용 toss 모듈) | - | 확정 결정 4 |
| 배포 | Vercel(웹), Railway(워커 컨테이너), Supabase(모듈러 통합 프로젝트) | - | 7절 |

YSM의 네이버 게시 로직은 Python(`[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py`)이지만 blog는 CA의 TS Playwright(`NOMAD Shorts Maker/src/skill/playwright-engine/*`)로 런타임을 하나로 둔다. 분석 C-1의 "Python 워커로 이식"(`docs/products/00_MERGE_ANALYSIS.md:534`)은 블로그가 video 안에 있을 때의 권고였다. blog에는 Whisper·FFmpeg 같은 Python 전용 처리가 없다.

## 2. 모듈 경계

저장소 루트는 `apps/nomad-blog/`(제안, 모노레포의 `packages/core-*`를 소비).

| 디렉토리 | 책임 | 다른 모듈 호출 |
|---|---|---|
| `src/app/(marketing)/` | 랜딩, 가격, 약관, 개인정보처리방침 | 없음(정적, `plans` 공개 SELECT만) |
| `src/app/(auth)/` | 로그인, 가입(`signup_app='blog'`), 대기·정지 안내 | core-auth |
| `src/app/(app)/dashboard/`, `posts/`, `calendar/` | 대시보드, 원고 목록, 캘린더 | server/* |
| `src/app/(app)/posts/[id]/` | 에디터 화면 | features/editor, server/* |
| `src/app/(app)/channels/`, `affiliate/`, `brandconnect/`, `settings/`, `billing/` | 채널, 제휴 통계, 브랜드커넥트, 설정(대가성 문구·멤버·활동 기록), 결제 | server/* |
| `src/app/api/**` | Route Handler(04장 2절). zod 검증 → `requireSession` → server 서비스 호출 | server/* |
| `src/app/r/[code]/route.ts` | 제휴 단축 링크 302 | core-affiliate `resolveClick` |
| `src/features/editor/` | TipTap 확장, 노드 뷰, 자동 저장 훅 | 없음(순수 클라이언트) |
| `src/server/entitlements/` | features 해석, 월 발행 한도, 채널 한도 | core-db |
| `src/server/ai/` | 크레딧 단가(`credits.ts`), purpose 맵(`purposes.ts`), 프롬프트(`prompts/`) | core-ai, core-billing |
| `src/server/render/` | body_json → 채널별 HTML, sanitize, 대가성 문구 삽입, 제휴 도메인 스캔, `rendered_hash` | core-affiliate `disclosure` |
| `src/server/publish/` | 발행 요청 오케스트레이션(검사 → INSERT → enqueue), 취소, 재시도 | core-jobs, render |
| `src/server/affiliate/` | 상품 검색, 링크 생성 + 매핑, 자동 추천 삽입 | core-affiliate |
| `src/server/channels/` | 채널 연결(자격증명 저장, SSRF 방지 fetch), 연결 해제 | core-auth vault |
| `src/server/compliance/` | blog 규칙 사전 + core compliance 호출, 결과 저장 | core-ai compliance |
| `src/server/brandconnect/` | 계정 연결, 동의, 지원 요청, 레이트 리밋 | core-affiliate |
| `workers/blog-worker/src/runtime/` | 워커 루프, 브라우저 풀, 채널 잠금, 타임아웃, 하트비트·취소 | core-jobs |
| `workers/blog-worker/src/channels/{naver,tistory,wordpress}/` | 채널 어댑터(`ChannelPublisher` 계약, 04장 6절) | runtime |
| `workers/blog-worker/src/handlers/` | 잡 핸들러(generate, publish, verify, brandconnect.*) | channels, server/render(공유 패키지로 추출) |
| `supabase/` | 마이그레이션(모듈러 조각 사본), 테스트 | - |

`src/server/render/`는 웹과 워커가 같이 쓰므로 `packages/blog-render`로 추출한다(06장 BL-06-008). 웹 코드가 워커 코드를 import하지 않는다.

Supabase 접근 3계층(`docs/products/00_MERGE_ANALYSIS.md:678`, `docs/reviews/NOMAD_Shorts_Maker.md:132`):

| 계층 | 클라이언트 | 쓰는 곳 |
|---|---|---|
| 브라우저 | `createBrowserClient`(anon + 세션) | 원고 콘텐츠 컬럼 저장, 목록 SELECT, Realtime 구독 |
| 서버 요청 | `createServerClient`(쿠키) | `requireSession`, 사용자 RPC |
| 백그라운드 | `createAdminClient`(service_role, 쿠키 비의존) | Route Handler의 크레딧·잡·자격증명·발행 행 쓰기, 워커 전부, `/r/[code]` |

## 3. 공용 모듈 사용

| 공용 모듈(`SHARED_MODULES.md`) | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 가입, 세션, `requireSession('blog')` | proxy.ts, 레이아웃, 모든 Route Handler | 프로필 없으면 로그아웃 |
| org | 1인 1워크스페이스, Business 팀 5인 | 설정 > 멤버 | |
| credits | AI 선차감·환불 `withCredits` | server/ai, 워커 generate | 단가는 01장 4.2절 |
| toss | 구독·팩 결제, 빌링키 | billing 라우트, 정기결제는 공용 워커 | `confirm_payment_order` 금액 불일치 시 주문이 failed로 남지 않는 코어 결함이 알려져 있다. blog는 이 상태에 의존하지 않고 PM001을 받으면 운영 알림 + Toss 취소만 한다 |
| webhooks | Toss 상태 동기화 | `/api/webhooks/toss` | 서명 필수 |
| oauth | 인스타그램(Phase 2) | channels | 워드프레스·네이버·티스토리는 OAuth가 아니다 |
| llm gateway | 모든 AI purpose | server/ai, 워커 | 모델 허용 목록 |
| fal client | AI 대표 이미지(Phase 2) | 워커 | |
| sns uploader | 인스타그램(Phase 2, video 소유) | 워커 | 소비만 |
| automation-core | n8n/Make, 발신 웹훅(Phase 2) | - | 노드 등록만 |
| compliance | 발행 전 게이트 | server/compliance | blog 규칙 사전 추가 |
| storage | 대표·본문 이미지, 내보내기 ZIP | 에디터 업로드, 내보내기 | `<org>/blog/<entity>/<uuid>.<ext>` |
| audit | 01장 BL-F-006 목록 | server/*, 제품 RPC 내부 | |
| jobs | 생성·발행·검증·브랜드커넥트 | server/publish, 워커 | |
| affiliate | 링크, 클릭, 대가성 문구, 브랜드커넥트 | server/affiliate, render, brandconnect, `/r` | 브랜드커넥트 어댑터와 Playwright 플로우는 blog 소유 |
| weasyprint | 사용 안 함 | - | |

## 4. 잡과 워커

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `blog.generate` | `blog.ai` | TS | 예(3 또는 6, 자동 삽입 시 +1) | 2회(LLM 타임아웃·5xx), 스키마 불일치 1회 | 최종 실패 시 `fail_job` 자동 환불. 결과 저장 실패는 환불 없음(`CORE_SPEC.md` 4.3절) |
| `blog.publish.wordpress` | `blog.publish` | TS(fetch) | 아니오 | 3회(네트워크, 5xx) | - |
| `blog.publish.naver` | `blog.browser` | TS + Playwright | 아니오 | 발행 버튼 전 실패만 3회. 버튼 이후 불확실은 `unconfirmed`, 재시도 없음 | - |
| `blog.publish.tistory` | `blog.browser` | TS + Playwright | 아니오 | naver와 같음 | - |
| `blog.channel.verify` | `blog.browser` | TS + Playwright | 아니오 | 1회 | - |
| `brandconnect.scan` | `blog.browser` | TS + Playwright | 아니오 | 1회 | - |
| `brandconnect.apply` | `blog.browser` | TS + Playwright | 아니오 | 제출 버튼 전 실패만 2회. 이후 불확실은 failed + 사용자 확인 | - |
| `brandconnect.sync` | `blog.browser` | TS + Playwright | 아니오 | 1회 | - |
| `blog.export` | `blog.ai` | TS | 아니오 | 2회 | - |
| `blog.publish.instagram`(Phase 2) | `blog.publish` | TS(sns-uploader) | 아니오 | 3회 | - |

워커 규약:

| 규칙 | 내용 |
|---|---|
| 루프 | `claim_jobs(queue, worker_id, limit)` → 핸들러 → `complete_job` / `fail_job(retryable)`. 하트비트 30초(제안), `reap_stale_jobs(600)`가 끊긴 잡 회수 |
| 채널 잠금 | 브라우저 잡은 시작 시 `blog.acquire_channel_lock(account, job, 300)`. false면 `fail_job(retryable=true)`로 60초 뒤 재큐. 끝나면 `release_channel_lock` |
| 발행 간격 | 같은 계정의 `last_published_at + 10분` 이전이면 `run_after`를 그 시각으로 미뤄 재큐(실패로 세지 않음). 일일 상한 초과면 다음날 00:10 KST로 |
| 타임아웃 | 브라우저 잡 전체 180초, 페이지 이동 30초, 셀렉터 대기 15초. 초과 시 브라우저 컨텍스트 강제 종료 |
| 취소 | 하트비트 반환 false면 AbortSignal → 발행 버튼 전이면 중단, 이후면 끝까지 진행 후 결과 기록 |
| 상태 반영 | 워커는 service_role로 `post_publications` 상태를 바꾼다. 원고 집계 상태는 DB 트리거가 계산한다(05장 3절) |
| 비밀 | 페이로드에 비밀 금지. `credential_id`로 복호화(`CredentialVault.get`) |
| 오류 메시지 | 사용자에게 보일 문구 코드(`NAVER_LOGIN_REQUIRED` 등)와 내부 로그를 분리. 예외 원문을 응답이나 URL에 넣지 않는다(`docs/reviews/Youtube_shots_Maker.md:88`) |
| 실패 스크린샷 | 로그인 이후 단계 실패만 `org-files/<org>/blog/debug/<job>.png`, 7일 보관(제안) |

## 5. AI 라우팅

| purpose | 모델(fast / quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `blog.keywords` | fast 모델 / - | 1 | fast 폴백 모델 1회, 실패 시 환불 + 오류 표시(단어 쪼개기 폴백 금지) |
| `blog.outline` | fast / - | 1 | 같음 |
| `blog.draft` | fast / quality | 3 / 6 | quality 실패 시 같은 등급 폴백 모델 1회. 등급을 낮춰 성공시키지 않는다(사용자가 고른 품질 보장) |
| `blog.product_extract` | fast | 1 | 실패 시 카드 없이 원고만 저장, 1크레딧 환불 |
| `blog.rewrite` | fast / quality(원고 모드 따름) | 1 | 폴백 1회 |
| `blog.tags` | fast | 1 | 폴백 1회, 기본 해시태그 폴백 금지 |
| `blog.bc_message` | fast | 1 | 폴백 1회 |
| `compliance` | core 기본 | 1 | LLM 실패 → 규칙 결과로 WARN |

모델 이름은 llm gateway의 `resolveModel(purpose, mode)` 설정으로 둔다(`SHARED_MODULES.md` 8장). 요청 바디로 모델명을 받지 않는다(`docs/reviews/Youtube_shots_Maker.md:87`). 원고 출력은 JSON 모드 + zod 스키마(`{ title, outline[], body: TipTapDoc, excerpt, tags[] }`). 마크다운·구분자 파싱(`[5f6d262] Youtube_shots_Maker/backend/services/blog_writer.py:66-82`)은 쓰지 않는다. 프롬프트 공통 금지 지시는 01장 6.5절이다.

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 "높음"은 NOMAD_Shorts_Maker 12개(#1~#12), Youtube_shots_Maker 4개(#1~#4), 합계 16개다. 구조 결함 8개는 이 절에, 보안·데이터 결함 8개는 `05_DATA_MODEL.md` 7절에 있다.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #4 | `docs/reviews/NOMAD_Shorts_Maker.md:81` | `x-internal-call` 헤더 하나로 발행·큐 실행 인증 우회 | 리뷰 #4 → 차단 설계: 자기 HTTP 호출이 없다. 예약 발행은 `core.jobs.run_after`로 워커가 직접 실행하고, 웹 라우트는 모두 `requireSession`만 받는다. 내부 호출 헤더 분기 금지(CLAUDE.md 7장), 정적 검사로 `x-internal-call` 문자열을 CI에서 거부 | 4절, BL-06-014, BL-06-032 |
| 같은 리뷰 #6 | `:83` | 미들웨어 없음, 대시보드 무인증, Mock 로그인 상시 노출 | 리뷰 #6 → 차단 설계: `src/proxy.ts`가 `(app)` 경로와 `/api/**`(웹훅, `/r` 제외)를 보호하고, 레이아웃과 라우트가 `requireSession('blog')`로 서버에서 다시 확인. Mock 로그인 파일 자체를 만들지 않는다 | BL-06-004 |
| 같은 리뷰 #8 | `:85` | 웹훅·cron·워커가 쿠키 anon 클라이언트를 써서 RLS로 0행 처리, 에러 미확인 | 리뷰 #8 → 차단 설계: 2절 3계층. 워커와 웹훅은 `createAdminClient`만 import 가능(ESLint 경계 규칙). 모든 쓰기의 `error`를 검사하고 0행 갱신을 오류로 취급하는 래퍼 사용 | BL-06-010, BL-06-003 |
| 같은 리뷰 #9 | `:86` | 단계 간 의존 없이 동시 enqueue, placeholder 전달, 즉시 done, fire-and-forget | 리뷰 #9 → 차단 설계: blog 잡은 단계 1개(생성) 또는 1개(발행)다. 상태 정본은 `core.jobs`와 `post_publications`이고, 원고 집계 상태는 발행 행 트리거가 계산한다(`1300_blog.sql:436`). 라우트는 enqueue까지만 하고 응답한다 | 4절, 05장 3절 |
| 같은 리뷰 #10 | `:87` | 워커가 `next/headers`에 의존해 독립 실행 불가, TS/Python이 같은 큐 소비 | 리뷰 #10 → 차단 설계: `workers/blog-worker`는 Next를 import하지 않는 독립 패키지(`npm run worker`), 큐 이름 `blog.ai`, `blog.publish`, `blog.browser`는 blog 워커만 소비. Python 워커 없음 | BL-06-010 |
| 같은 리뷰 #11 | `:88` | tsc 21개 오류로 빌드 실패 | 리뷰 #11 → 차단 설계: 새 저장소. 원본 파일을 통째로 복사하지 않고 07장 2절의 수정 목록을 적용해 이식. CI에서 `tsc --noEmit`, lint, build 실패 시 병합 차단 | BL-06-032 |
| 같은 리뷰 #12 | `:89` | Next 16 `params` Promise 미대응, `generateStaticParams`에서 쿠키 클라이언트, 마이그레이션에 없는 RPC 호출 | 리뷰 #12 → 차단 설계: 동적 라우트는 `params: Promise<...>`를 await하는 템플릿만 사용. 빌드 시점 데이터 조회 없음(랜딩은 정적, 플랜 표는 요청 시 anon 조회). 호출하는 RPC는 모두 `1300_blog.sql`과 core에 있으며 생성 타입(`supabase gen types`)으로만 호출 | BL-06-001, BL-06-003 |
| `docs/reviews/Youtube_shots_Maker.md` 3장 #1 | `docs/reviews/Youtube_shots_Maker.md:82` | 무관한 커밋에서 소스 109개 삭제, 잔해만 남음 | 리뷰 #1 → 차단 설계: 원본은 `git show 5f6d262:<경로>`로만 읽어 이식하고, 이식 대상 목록을 07장 1절에 고정. 아카이브 태그 `archive/youtube-shots-maker-v1`(5f6d262) 생성은 사용자 승인 후 진행. 새 저장소는 정리 커밋과 기능 커밋을 분리하는 PR 규칙 | 07장 5절, BL-06-033 |

## 7. 배포 토폴로지

| 구성 | 위치 | 네트워크 경계 |
|---|---|---|
| 웹(Next) | Vercel | Supabase anon/service 키, Toss 시크릿. Playwright 실행 금지(Route Handler `maxDuration` 안에서 브라우저를 띄우지 않는다) |
| blog-worker | Railway 컨테이너(Playwright 공식 이미지 기반, 한글 폰트 포함) 1~2개 | 외부로는 네이버·티스토리·워드프레스·LLM·쿠팡만 호출. 인바운드 포트 없음 |
| DB | Supabase 모듈러 통합 프로젝트(`blog` 스키마) | `config.toml [api].schemas`에 `blog` 추가 |
| 스케줄 | pg_cron(코어 스케줄) + 워커 내부 크론(`brandconnect.sync` 하루 1회, 세션 만료 알림 하루 1회) | `CRON_SECRET` 공개 라우트 방식 금지(`SECURITY_BASELINE.md` 13장) |
| 정기결제 | 공용 billing 워커(코어) | blog는 소비만 |

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버·워커 | 비공개 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`(모듈러) / `public`(모놀리스) | 비공개 | 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 자격증명 AES-256-GCM | 비공개 | 기동 실패(0키 폴백 금지) |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | 결제 | 클라이언트 키만 공개 | 기동 실패 |
| `OPENROUTER_API_KEY`(또는 gateway 설정 키) | LLM | 비공개 | 기동 실패 |
| `AFFILIATE_CLICK_SALT_SEED` | 클릭 IP 해시 솔트 시드 | 비공개 | 기동 실패 |
| `BLOG_PUBLIC_BASE_URL` | 단축 링크 도메인 | 공개 가능 | 기동 실패 |
| `WORKER_ID`, `WORKER_CONCURRENCY`(기본 4) | 워커 | 비공개 | 기본값 |
| `BRANDCONNECT_NOTICE_VERSION`, `CHANNEL_NOTICE_VERSION` | 현재 고지문 버전 | 공개 가능 | 기동 실패 |

쿠팡파트너스 키는 환경변수가 아니라 조직별 `encrypted_credentials`다(원본은 전역 env `COUPANG_ACCESS_KEY`, `NOMAD Shorts Maker/src/skill/channel-api/coupang-client.ts:8-11`). 환경변수 검증은 `src/lib/env.ts`의 zod 스키마 하나로 한다.
