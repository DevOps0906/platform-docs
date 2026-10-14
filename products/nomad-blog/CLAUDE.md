# CLAUDE.md: NOMAD Blog

개발 에이전트 지침. 작성일 2026-10-12, 2026-10-13 AI·음성·3D·디자인 시스템 규칙 추가. 이 문서와 `docs/products/_platform-core/SECURITY_BASELINE.md`가 충돌하면 SECURITY_BASELINE이 이긴다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 로그인·가입·세션 작업이면 `AUTH_ROADMAP.md`(8절) |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장, `DB_CONVENTIONS.md` 14장(pgvector) |
| 2 | 이 폴더 `01_PRD.md`(특히 4장 요금, 6장 법·금지 문구, 6.7절 AI 규칙), `02_ARCHITECTURE.md`, `04_API.md`, `05_DATA_MODEL.md` |
| 3 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 소유 디렉토리 |
| 4 | 이식 대상이면 `07_SOURCE_MIGRATION.md` 2절(수정할 점)과 4절(복사 금지) |
| 5 | UI 작업이면 `_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` blog 절, `03_SCREENS_UX.md` 3.10절·4절, 랜딩이면 `HERO_3D.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role 키 | 서버 파일(Route Handler, `src/server/**`, 워커)에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 선차감 | AI 호출 전 `consume_credits`, 실패 시 환불. 잡은 `p_credit_ledger_id`로 연결 |
| 코어 재정의 금지 | 인증, 조직, 크레딧, 결제, 웹훅, OAuth, 자격증명, 잡, Storage, 감사, 제휴 테이블·함수를 blog에 다시 만들지 않는다 |
| 수정 금지 | `_platform-core/`, `_supabase-modular/`의 다른 파일, `packages/core-*`. 필요하면 06장 6절 요청 |
| 대가성 문구 | 제휴 링크·스폰서 원고에는 글 상단 문구가 반드시 들어간다. 끄는 옵션, 숨김 스타일을 만들지 않는다 |
| 브랜드커넥트·자동 게시 | 위험 동의(owner/admin, 고지문 버전) 없이 Playwright 작업을 실행하지 않는다. CAPTCHA 우회·봇 감지 우회·프록시 순환 금지 |
| 브랜드커넥트 유형 | blog는 블로그형 지원서만 만든다(`target_kind='blog'`, `source_app='blog'`). 클립형은 video로 넘긴다(BL-F-036). `brandconnect.apply` 워커는 video 요청도 처리하므로 payload `source_app`과 지원서 `target_kind`를 함께 확인한다 |
| 생성 콘텐츠 | 사용자 메모 없는 체험담, 지어낸 수치, 가상 후기 금지(01장 6.5절) |
| 원본 | 원본 폴더를 고치지 않는다. YSM은 `git show 5f6d262:<경로>`로만 읽는다 |
| LLM 키 | FastAPI(`apps/api`)에만. Vercel과 `blog-worker`에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·채널 정보를 넣지 않는다 |
| AI 입력 | 채널 비밀번호·세션 쿠키·애플리케이션 비밀번호·제휴 키·`credential_id`·결제 정보는 어떤 AI 입력(그래프, 채팅, 프롬프트, 로그)에도 넣지 않는다. 체험 메모와 채팅 메시지는 서버가 마스킹한 뒤 보낸다 |
| 사람 승인 | 그래프(`blog.post_draft`)로 만든 원고는 `approve` 노드 승인 전에 발행·예약하지 않는다(`AI_APPROVAL_REQUIRED`). 승인 확인은 발행 라우트(BL-06-014)가 한다. 브랜드커넥트 위험 동의와 자동 지원 흐름(BL-F-030~035)은 AI 계층이 약화하지 않는다 |
| AI와 대가성 문구 | AI(그래프, 채팅)는 문구를 쓰거나 지우거나 숨기지 않는다. 삽입은 렌더러(BL-F-024)만. 끄거나 숨겨 달라는 요청은 규칙 파일(`packages/blog-rules`)로 거절한다 |
| AI 크레딧 | 그래프·채팅·음성·색인·위키는 제공자 호출 전에 선차감하고 끝나면 정산, 결과가 전달되지 않으면 전액 환불(01장 4.6절). 그래프는 정액 선차감에 묶는다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용 제공자를 쓰지 않는다 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/nomad-blog/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 BL-06-044 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고, 3D 재질 색도 토큰만. 3D 안에 글자를 그리지 않는다 |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 담당 작업 |
|---|---|---|
| `src/app/(marketing)/`, `(auth)/`, `(app)/*` | 화면 | 06장 표 |
| `src/app/api/**`, `src/app/r/` | Route Handler | 06장 표 |
| `src/server/{session,entitlements,ai,publish,affiliate,channels,compliance,brandconnect,billing,automation}/` | 서버 서비스 | 디렉토리별 1개 작업 |
| `src/features/editor/` | TipTap 확장 | BL-06-007 |
| `packages/blog-render/` | 렌더·sanitize·대가성 문구 | BL-06-008 |
| `workers/blog-worker/src/{runtime,channels/*,handlers/*,observability}/` | 워커 | 06장 표 |
| `supabase/` | 마이그레이션, 테스트 | BL-06-001, BL-06-028 |
| `apps/api/` | 공용 ai-service와 설정 045, `app/ai/products/blog/knowledge.py` 048, `wiki_config.py` 049, `app/ai/graphs/blog_post_draft.py`·`app/ai/compliance/blog.py`·`prompts/` 050, `app/ai/tools/blog/` 051, `tests/blog/security/` 056 | 045, 048, 049, 050, 051, 056 |
| `packages/blog-rules/` | 금지 표현·대화 규칙(언어 중립) | BL-06-047 |
| `src/app/api/` AI·음성 | ai(`keywords/`, `outline/` 제외)·internal·onboarding·posts/[id]/ai-approve·ai-reject 046, voice 053, materials 048, wiki 049 | 046, 048, 049, 053 |
| `src/app/` AI 화면 | onboarding 046, assistant·materials 052, wiki 049, `posts/[id]/review` 022 | 022, 046, 049, 052 |
| `src/components/` AI·3D | ai-chat·materials 052, voice 053, dictation 054, wiki 049, hero3d·`public/hero/` 055 | 049, 052~055 |
| `src/server/ai/` | `credits.ts`, `purposes.ts` 006, `schemas/` 015, `gateway/`, `pricing.ts` 046 | 006, 015, 046 |
| `src/styles/tokens.css`, `src/components/ui/`, `src/app/dev/components/` | 디자인 시스템 | BL-06-042 |
| `infra/dify/` | `blog-chat` Dify DSL(키 없음) | BL-06-051 |
| `docs/file/03-설계/디자인/` | `DESIGN.md` 1절 041, 2절 이후와 `COMPONENTS.md` 044, `review/` 043(사람) | 041, 043, 044 |

다른 작업의 디렉토리는 `index.ts` 공개 인터페이스만 import한다. 웹 코드는 워커 코드를 import하지 않는다.

## 4. 코어 사용 규칙

| 상황 | 쓸 것 |
|---|---|
| Route Handler 진입 | `requireSession('blog', { roles })` → zod 검증 |
| 플랜 판정 | `src/server/entitlements`(내부에서 `entitled_plan_code` + `plans.features`). 클라이언트 판정은 UX 보조 |
| AI 호출 | 단건은 `packages/core-ai` 래퍼 → FastAPI `/tools/blog/assist`(`withCredits` 선차감), 생성은 그래프 `blog.post_draft`. LLM을 웹·워커에서 직접 부르지 않는다. purpose는 `02_ARCHITECTURE.md` 5절 |
| 잡 | `enqueue_job(org, 'blog', queue, job_type, payload, ..., p_idempotency_key='job:blog:<request_id>')`. 큐 `blog.ai`, `blog.publish`, `blog.browser`(TS 워커), `blog.aisvc`(FastAPI 소비) |
| 발행 행 | service_role INSERT. DB 게이트(컴플라이언스, 동의, 계정 상태)가 거부하면 SQLSTATE를 04장 7절로 매핑 |
| 비밀 | `CredentialVault.put/get`. 페이로드에는 `credential_id`만 |
| 제휴 | `AffiliateApi.createShortLink(sourceApp 'blog', sourceRef post id)` + `blog.post_affiliate_links` INSERT. 문구는 `effective_disclosure(org, provider, 'blog_top')` |
| 감사 | 사용자 세션은 제품 RPC/`write_audit`, 서버는 `auditAsService`. AI 이벤트: `blog.ai.cross_border_ack`, `blog.ai.draft_approved`, `blog.ai.draft_rejected`, `blog.voice.notice_ack`, `blog.ai.document_upload`, `blog.ai.document_delete`, `blog.wiki.publish`, `blog.wiki.edit` |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인을 다시 확인. 서명 토큰은 `src/server/ai/gateway/`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'blog', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')` + 감사 `blog.ai.cross_border_ack`(같은 고지문 버전) |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. `store_audio=false`. 첫 녹음 전 고지 확인(감사 `blog.voice.notice_ack`). TTS는 DB의 assistant 메시지만 |
| 그래프 | 워커는 `/api/internal/ai-token`으로 잡 토큰을 받아 `POST /graphs/blog.post_draft/runs`. FastAPI는 `ai_runs`·`ai_run_steps`·`ai_usage`를 기록하고 `blog.posts` 쓰기와 제휴 카드 삽입은 워커가 한다. 승인·반려는 `ai-approve`·`ai-reject` 라우트 |
| 자료·위키 | 조직 컬렉션 `blog-materials`·`blog-wiki`, 임베딩 `oss-embed` 고정. `contains_pii` 자료는 위키 대상에서 제외. 위키 쓰기는 FastAPI 경유(`expected_version`) |
| 쓰기 결과 | Supabase 쓰기의 `error`를 항상 검사하고 0행 갱신을 오류로 취급 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16 App Router, React 19, TypeScript strict, Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전), TipTap, zod, TanStack Query, Playwright, three.js + React Three Fiber + drei(React 19 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| 동적 라우트 | `params`는 Promise로 받고 await |
| 타입 생성 | `supabase gen types typescript --local --schema core,blog > src/types/supabase.ts`. Supabase 결과를 `any`로 캐스팅하지 않는다 |
| 디자인 토큰 | `src/styles/tokens.css`(03장 3.10절·4.3절, 의미 기반 이름). 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안), 아이콘은 lucide, 이모지 금지 |
| Python | `apps/api`: ruff, mypy(제안), pydantic 스키마는 `src/server/ai/schemas/`의 zod 스키마와 같게. 규칙·프롬프트 파일은 복사본을 고치지 않는다(원본은 047·050 소유) |
| 파일 크기 | 컴포넌트 파일 400줄 이하 |
| 로그 | 구조화 로거, 비밀·쿠키·원고 전문 금지 |
| 문구 | 사용자 노출 문구는 한국어, 오류는 원인과 해결 방법 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -w tsc --noEmit && pnpm -w lint && pnpm -w build` | 0 오류 |
| `node docs/products/_tools-sqlcheck/check.mjs --vector mod <0000~0009> <seed> <1300_blog.sql>` | OK(AI 표가 있어 `--vector` 필수) |
| `node docs/products/_tools-sqlcheck/check.mjs --vector mono <0001_core_lite> <0002_blog_domain> <seed>` | OK |
| `pytest apps/api` | 토큰·조직 격리·라우팅·그래프·채팅 평가셋(045, 048, 050, 051, 056) |
| `pnpm test:ai` | AI 게이트 선차감·정산·환불, 승인 전 발행 409(046, 053, 056) |
| `pnpm test:rls`(BL-06-028) | 모듈러·모놀리스 0 실패 |
| `pnpm test:e2e`(BL-06-029, 030, 037) | 결제·발행·생성 통과, 대가성 문구 포함률 100% |
| 디자인 | `DESIGN_PRINCIPLES.md` 7단계 체크리스트, 디자인 시스템 4단계(BL-06-044), `HERO_3D.md` 4절 |

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약:

| 금지 | 대체 |
|---|---|
| `x-internal-call`, 자기 HTTP 호출 | 잡, 함수 직접 호출 |
| Route Handler 안 Playwright | 워커 |
| 세션 쿠키·비밀번호·키 평문 저장, 전역 env 제휴 키, 0키 폴백 | `encrypted_credentials`, 키 없으면 기동 실패 |
| 웹훅 서명 선택 검증, orderId 파싱 | 공용 webhooks, `payment_orders` |
| 발행 불확실을 성공 처리 후 자동 재시도 | `unconfirmed` + 사용자 확인 |
| 봇 감지 우회, CAPTCHA 풀이, 프록시 순환 | 일반 입력, CAPTCHA 시 중단 |
| 가상 후기 프롬프트, 폴백 가짜 데이터, Mock 응답 | 금지 지시, 오류 표시와 환불 |
| sanitize 없는 `dangerouslySetInnerHTML` | 서버 렌더 + sanitize |
| 사용자 지정 URL 무검사 fetch | 공인 https, 리다이렉트 제한 |
| 대시보드 더미 배열, 난수 지표 | 실데이터 또는 빈 상태 |
| 쿠키 역할 Mock(`mock-auth`, `nomad_role`, `nomad_plan`), 기본 역할 admin | `requireSession`, 프로필 없으면 로그아웃. 허용 Mock은 `AUTH_ROADMAP.md` 2장(로컬 시드 계정, 8절) |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | 서버 전용 키(FastAPI, Next.js 서버) |
| 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·채널 정보 | `/api/ai/*`, `/api/voice/*`, 대화 매핑 |
| 채널 비밀·세션 쿠키·제휴 키를 AI 입력에 넣기 | 입력 스키마에 필드 없음 |
| 사람 승인 없이 AI 원고 발행, AI가 대가성 문구를 쓰거나 지우기 | `approve` 노드, 렌더러만 문구 삽입 |
| 클라이언트 텍스트 그대로 TTS, 녹음 원본 저장 | DB 메시지만 낭독, `store_audio=false` |
| 토큰 밖 3D 색, 3D 안 글자, 종이비행기·파티클 | 03장 4.6절 |
| "Tailwind"만 적은 지시(v3 혼입) | Tailwind CSS v4 명시, `tailwind.config.js` 금지 |

## 8. 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`(이하 AUTH_ROADMAP), 보안 규칙은 `SECURITY_BASELINE.md` 17장이다.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 A(Mock). 로그인은 로컬 Supabase 시드 계정 원클릭 로그인뿐이고 Google·카카오·네이버 콘솔 설정과 버튼을 만들지 않는다. B·C 전환은 아래 게이트 기록이 있을 때만 |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH`를 읽는 코드는 `src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/`(콜백, C2 브리지), `src/app/api/dev/`에만. 기능 코드·워커·`apps/api`에 `if (mock)` 금지(BL-06-032가 CI로 막음). 권한은 `session_context`로만 판단하고 페르소나 이메일로 분기하지 않는다 |
| 페르소나 사용법 | `supabase start` → `supabase db reset` → `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD` → `node scripts/dev/seed-users.mjs --app blog`(제품 훅 `seed-users.blog.mjs` 포함) → `/login` 개발용 패널. 페르소나: `owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops`, blog 행 `owner_pro`(05장 10절) |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장하고 테스트는 그 상태로 시작한다(BL-06-029, 037). 실제 Google 로그인은 자동화하지 않는다(B-5) |
| 금지 패턴 | 쿠키·localStorage·헤더에 역할·플랜·사용자 id를 적는 Mock(`mock-auth`, `nomad_role`, `nomad_plan`, `dev-user`), `NEXT_PUBLIC_` 비밀번호, 원격 DB에 시드 계정 생성, 판정 거짓인데 조용히 live 전환, 콜백 `next` 무검증, 이메일 일치만으로 계정 합치기, `listUsers` 전체 조회로 사용자 찾기 |
| 채널 로그인과 혼동 금지 | 네이버·티스토리 채널 연결(Playwright 게시·브랜드커넥트, `encrypted_credentials`)은 사용자 로그인과 별개다. 로그인 작업(057~059)은 채널 코드(`src/server/channels/`, `workers/blog-worker/src/channels/`)를 건드리지 않고, 채널 작업은 `src/lib/auth/`를 건드리지 않는다 |
| 단계 전환 | G1(AUTH_ROADMAP 4장)·G2(6장)는 사람(대표님)이 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 기록한다. 에이전트가 스스로 판정하지 않는다. C2 경로도 `[DECISION]`(스파이크 결과) |
| 이 제품의 작업 ID | A: BL-06-004(W1). B: BL-06-057(P0, G1 후, W6 맨 앞). C1: BL-06-058(P1, G2 후, W7). C2: BL-06-059(P1, G2 후, W7, 네이버 블로거 비중으로 검수 신청 먼저) |
