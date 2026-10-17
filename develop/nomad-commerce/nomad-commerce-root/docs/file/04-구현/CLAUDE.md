# CLAUDE.md: NOMAD Commerce

개발 에이전트 지침. 이 문서와 `docs/file/03-설계/공용코어/SECURITY_BASELINE.md`가 원본 프로젝트 관행보다 우선한다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 로그인·세션·시드 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더 `01_PRD.md` → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 3 | UI 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` nomad-commerce 절, 랜딩이면 `HERO_3D.md` |
| 4 | DB 정본 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1400_commerce.sql` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 서버(Route Handler, 워커)에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 선차감 | 유료 작업은 Route Handler 안에서 `consume_credits` → 작업 → 실패 시 `refund_credits`. 별도 차감 API를 만들지 않는다 |
| 플랜·모델 | `entitled_plan_code` + `plans.features`로만 판정. 요청 바디·쿠키의 plan/role/model은 무시 |
| 마켓 키 | `core.encrypted_credentials`에만. 응답은 마스킹, 로그 금지, 복호화는 워커 upload에서만 |
| compliance | FAIL은 내보내기·업로드 불가, WARN은 `acknowledge_compliance_warning` 후에만 |
| 생성 금지 | AI 후기·평점·"전문가 추천", "단순 변심 반품 불가", "이 제품은 건강기능식품이 아닙니다" 자동 문구, 허위 수치 카피 |
| 코어 | `core.*`를 ALTER하거나 commerce 스키마에 플랜·크레딧·잡 테이블을 다시 만들지 않는다. `D:/WorkSpace/platform/docs/products/_platform-core/`, `_supabase-modular/`의 다른 파일을 수정하지 않는다(필요하면 06장 6절 요청) |
| 원본 | sellingstudio 등 원본 코드는 07장 "이식" 항목만, 2절 수정과 함께 옮긴다 |
| LLM·음성 키 | LLM 제공자 키는 FastAPI(`apps/api`)에만. Vercel과 `commerce-worker`에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·마켓 키·개인정보를 넣지 않는다 |
| AI 입력 | 셀러 연락처·반품지 주소·마켓 키·사업자등록번호는 어떤 AI 요청에도 넣지 않는다. 채팅 메시지는 마스킹 후 전달 |
| AI 크레딧 | 채팅·음성·내레이션은 제공자 호출 전에 선차감하고 끝나면 정산, 결과가 전달되지 않으면 전액 환불(01장 4.6절). 상세페이지 그래프와 보조 그래프 작업은 4.2절 정액 차감에 묶는다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용 제공자를 쓰지 않는다. 요청 바디의 모델·제공자 값은 무시 |
| AI 출력 | 생성물·채팅·내레이션에 승인·반려 보장, 법률 단정, 질병 효능 단정, 가상 후기·평점을 쓰지 않는다. 규칙 근거가 없으면 "근거 자료를 찾지 못했습니다". 같은 규칙 파일(`packages/commerce-compliance/rules/`)을 TS와 FastAPI가 함께 읽는다 |
| 내레이션 | `feature='shorts_narration'`은 작업 도중 다른 제공자로 대체하지 않는다. 실패하면 파일을 만들지 않고 환불. 영상 렌더·결합은 sceneflow 워커 API 호출만(렌더 코드 0줄) |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/nomad-commerce/styles/tokens.css`(`@theme`)와 `components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 CM-06-044 뒤 |
| 3D | three.js는 `components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고, 3D 재질 색도 토큰만 |

## 3. 디렉토리와 소유 경계

| 경로 | 내용 | 소유 작업 |
|---|---|---|
| `packages/commerce-domain/` | 슬롯, phase, 규격, features, 단가, 마진 | CM-06-006 |
| `packages/commerce-compliance/` | 금지어 매처 | CM-06-017 |
| `packages/commerce-net/` | 안전 fetch | CM-06-008 |
| `packages/commerce-sourcing/{amazon,excel}/` | 소싱 | CM-06-018, 019 |
| `packages/commerce-markets/{coupang,smartstore}/` | 마켓 어댑터 | CM-06-021, 022 |
| `apps/nomad-commerce/app/api/<영역>/` | Route Handler | 06장 2절 표 |
| `apps/nomad-commerce/app/(app)/<화면>/`, `components/<영역>/` | 화면 | CM-06-027~031 |
| `services/commerce-worker/src/<영역>/handler.ts` | 워커 핸들러(자동 로드) | CM-06-012~024 |
| `apps/api/` | 공용 ai-service와 설정 045, `app/ai/products/commerce/knowledge.py` 048, `wiki_config.py` 049, `app/ai/graphs/commerce_*.py`·`app/ai/compliance/commerce.py` 051, `app/ai/tools/commerce/` 052, `tests/commerce/security/` 057 | 045, 048, 049, 051, 052, 057 |
| `apps/nomad-commerce/app/api/` AI·음성 | `ai/{conversations,chat}`·`internal`·`onboarding` 046, `ai/{names,autofill,benchmark,vision}` 011, `ai/voice-structure`·`voice`(narrations 제외) 054, `ai/shorts-script`·`voice/narrations` 055, `admin/{wiki,knowledge}` 049, `products/[id]/specs` 048 | 011, 046, 048, 049, 054, 055 |
| `apps/nomad-commerce/` AI·3D 화면과 `lib/ai/` | `components/ai-chat`·`app/(app)/chat` 053, `components/voice` 054, `components/narration`·`app/(app)/narrations` 055, `components/hero3d`·`public/hero` 056, `app/(marketing)/wiki` 050, `app/admin/{wiki,knowledge}` 049, `app/(app)/settings/ai`·`app/onboarding`(`terms/`는 058)·`lib/ai/` 046(`rag-hooks.ts` 048) | 046, 049, 050, 053~056 |
| `packages/commerce-compliance/rules/`, `fixtures/` / `packages/commerce-domain/schema/` | 언어 중립 규칙·테스트 벡터 / 그래프 출력 스키마 | 017 / 051 |
| `content/knowledge/`, `scripts/knowledge/`, `scripts/ai-routing/`, `infra/dify/` | 규칙 원고 047, 색인 048, 라우팅 스냅샷 057, Dify DSL 052 | 047, 048, 052, 057 |
| `apps/nomad-commerce/styles/tokens.css`, `components/ui/`, `app/dev/components/` / `docs/file/03-설계/디자인/` | 디자인 시스템 코드 / 문서 | 042 / 041(1절), 043(review, 사람), 044(2절 이후, COMPONENTS) |

자기 작업의 소유 경로 밖 파일은 수정하지 않는다. 공용 인덱스 파일을 만들지 않는다.

## 4. 코어 사용 규칙

| 용도 | 쓰는 것 |
|---|---|
| 세션 | `requireSession('commerce', { roles })` → `session_context` 1회 |
| 크레딧 | `credits.consume/refund/withCredits`, 멱등 키 `consume:commerce:<request_id>` |
| 잡 | `jobs.enqueue({ queue: 'commerce.<type>', jobType, idempotencyKey: 'job:commerce:<request_id>', creditLedgerId })`. 상세페이지는 `detail_pages`(waiting)만 쓰고 enqueue는 디스패처가 한다 |
| 자격증명 | `CredentialVault.put/get`, 연결 해제는 `revoke_credential` |
| 감사 | 마켓 계정 추가·삭제, 내보내기, 환불은 `auditAsService`. WARN 확인은 RPC가 기록 |
| Storage | `<org_id>/commerce/<entity>/<uuid>.<ext>`, 내보내기는 `exports` 버킷 서명 URL 7일 |
| 오류 | SQLSTATE → HTTP는 `04_API.md` 7절 |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인을 다시 확인. 서명 토큰은 `lib/ai/token.ts`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'commerce', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')`. 증빙은 코어 감사 행(제품 동의 테이블 없음) |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. `store_audio=false`. 첫 녹음 전 음성 처리 고지 확인(감사 `ai.voice_notice.ack`) |
| 그래프 | 워커는 `/api/internal/ai-token`으로 잡 토큰을 받아 `POST /graphs/commerce.detail_page/runs`. 보조 AI는 Route Handler가 서명 토큰으로 `commerce.assist`. FastAPI는 `ai_runs`·`ai_run_steps`·`ai_usage`만 쓰고 `detail_pages` 계열은 워커가 쓴다 |
| 위키·규칙 | 운영자 지식 조직(`COMMERCE_KNOWLEDGE_ORG_ID`)에만 둔다. 공개 위키는 `published`만 서버에서 읽는다. 쓰기는 FastAPI 경유 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16.2.7, React 19.2, Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전), Zustand 5(UI 상태만), zod 4, @xyflow/react 12(Phase 2), Node 22 워커, three.js + React Three Fiber + drei(React 19 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 태그 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| Next 16 | `cookies()`/`headers()`/`params` await, 미들웨어는 `proxy.ts` |
| 타입 | `any` 금지, `supabase gen types typescript --schema core,commerce > apps/nomad-commerce/types/supabase.ts` |
| 린트 | `no-explicit-any`, `no-console`(로거 사용) |
| 외부 호출 | `AbortSignal.timeout`, 응답은 zod 검증 |
| 컴포넌트 | 300줄 이하, 서버 컴포넌트 우선 |
| 디자인 토큰 | `apps/nomad-commerce/styles/tokens.css`의 `@theme`(03장 3.2절, 4.3절 색·서체; `globals.css`가 import). 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안), 이모지 아이콘 금지(Lucide) |
| Python | `apps/api`: ruff, mypy(제안), pydantic 스키마는 `packages/commerce-domain/schema/detail-page-graph.schema.json`과 같게. 프롬프트·규칙 파일 복사본을 고치지 않는다(원본 051·017 소유) |
| 의존성 | 버전 고정, lockfile 커밋 |

## 6. 테스트와 완료 조건

| 검사 | 명령 |
|---|---|
| 타입·린트·빌드 | `pnpm -F nomad-commerce typecheck && pnpm -F nomad-commerce lint && pnpm -F nomad-commerce build`, 워커 동일 |
| 단위 | `pnpm -F @nomad/commerce-domain test` 등 패키지별 |
| RLS | `tests/rls/`(CM-06-003) |
| E2E | `tests/e2e/billing/`, `tests/e2e/flows/` |
| SQL(AI 포함) | `cd D:/WorkSpace/platform/docs/products/_tools-sqlcheck && node check.mjs --vector mod <0000~0009> ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1400_commerce.sql` (AI 표가 있어 `--vector` 필수), 모놀리스는 `node check.mjs --vector mono <0001> <0002> <seed.sql>` |
| AI | `pytest apps/api`(토큰·조직 격리·라우팅·그래프·평가셋: 045, 048, 051, 052, 057), `pnpm test:ai`(AI 게이트 선차감·정산·환불, 내레이션 대체 금지: 046, 055, 057) |

완료 정의는 `06_AGENT_PLAN.md` 7절.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: 분리된 크레딧 차감, 비원자 차감, 바디의 plan/model, 무서명 웹훅과 `USING(true)`, 쿠키 권한, 평문 키 API, 사용자 URL 직접 fetch와 원문 HTML 저장, 요청의 테이블 이름, 한글 `\b` 정규식, `globalThis` 잡, 공개 AI 프록시, 클라이언트 한도 판단, localStorage 키, LLM 추정 환율, SSE + 브라우저 큐, env 단일 마켓 키, `FOR ALL` 정책, 반품 불가·건기식 부정 자동 문구, AI 후기, 콜백 오픈 리다이렉트, 0키 폴백, mock 응답으로 장애 숨기기. AI·디자인(2026-10-13): LLM·음성 키를 브라우저·Vercel·워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보·마켓 키, 셀러 연락처·마켓 키를 AI 요청에 포함, 클라이언트 텍스트 그대로 TTS, 내레이션 중 제공자 대체, 근거 없는 규정 단정과 승인·반려 보장 문형, 토큰 밖 3D 색·별 파티클, "Tailwind"만 적은 지시(v3 혼입).

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`. 제품 적용값은 `01_PRD.md` CM-F-001·8.1절, `02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `06_AGENT_PLAN.md` 8절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 A(Mock). 로컬 `.env.local`은 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 실제 제공자 버튼은 B(CM-06-058)부터, 카카오(기존 MVP 범위였음)는 C1(CM-06-059), 네이버는 C2(CM-06-060) |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH`는 `apps/nomad-commerce/lib/auth/`, `app/(auth)/login/`, `app/auth/callback/`, `app/api/dev/login/`, `app/auth/naver/`에서만 읽는다. 기능 코드·워커·FastAPI에 `if (mock)`·페르소나 이메일 분기 금지. 권한은 `session_context`로만 |
| 페르소나 | `supabase db reset` → `node scripts/dev/seed-users.mjs --app commerce`(로컬 Supabase 전용, 원격 URL이면 종료) → `/login` 개발용 패널. 키 `owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops` + 제품 행 `pro`, `ai_consent`(제안, `05_DATA_MODEL.md` 10절). E2E는 Playwright `globalSetup`이 `/api/dev/login`으로 페르소나별 `storageState`를 저장해 쓴다(`tests/e2e/flows/`, CM-06-035) |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 기록(`nomad_role`, `nomad_plan`, `mock-login`, `mock-auth`), `dev-user` 우회, 가짜 사용자 객체·가짜 세션 쿠키, 원격 DB에 시드 계정, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`에, 가드 없이 `/api/dev/login` 노출(판정 거짓이면 404), 콜백 `next` 무검증. CI(CM-06-036)가 grep으로 막고 `AUTH_MODE=mock VERCEL_ENV=production` 빌드가 실패해야 한다 |
| 단계 전환 | 에이전트가 스스로 단계를 올리지 않는다. 사람(대표님)이 G1(A→B)·G2(B→C) 조건(`AUTH_ROADMAP.md` 4장, 6장)을 판정하고 task `log.md`에 `[DECISION] G1 통과`·`[DECISION] G2 통과`로 남긴 뒤에만 B·C 작업을 시작한다 |
| 소유 경로 | 007: `lib/auth/`(`naver/` 제외), `app/(auth)/login/`, `app/api/dev/login/`, `proxy.ts`, `lib/session/`, `scripts/dev/`. 058: `components/auth/`(`kakao/` 제외), `app/auth/callback/`, `app/(auth)/{signup,reset-password}/`, `app/onboarding/terms/`. 059: `components/auth/kakao/`, `app/(app)/settings/login/`. 060: `lib/auth/naver/`, `app/auth/naver/`(브리지만), `scripts/auth/`. `finishLogin` 약관 단계 연결은 007 파일에, `supabase/config.toml` 제공자 블록은 001 파일에 1줄 요청(06장 8.1절) |
| 이 제품의 작업 | A: CM-06-007(W1). B: CM-06-058(P0, Fable, W7 맨 앞, G1 후). C1: CM-06-059(P1, Opus, W8, G2 후). C2: CM-06-060(P1, Fable, W8, G2 후, 브리지면 코어 요청 R-9) |
