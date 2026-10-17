# CLAUDE.md: FLORA Publishing

개발 에이전트 지침. 이 파일과 01~07장이 원본 프로젝트(`Flora-v2/`, `flora/`, `flora-publisher/`, SellingDocs) 문서보다 우선한다. 모든 사용자 노출 문구는 한국어.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더 `01_PRD.md`(기능 ID, 단가, features 키) → `02_ARCHITECTURE.md`(경계, 잡) → `04_API.md`(계약) → `05_DATA_MODEL.md`(테이블, RLS) |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장, `DB_CONVENTIONS.md` 14장(pgvector) |
| 3 | 화면 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `03_SCREENS_UX.md`(4.1절 레퍼런스 표), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` flora-publishing 절, 랜딩이면 `HERO_3D.md`와 `LANDING_PERSUASION.md`(2026-10-17, 03장 9절) |
| 4 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 이식 대상(`07_SOURCE_MIGRATION.md` 2절, 금지 패턴 4절) |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 서버 파일(Route Handler, 워커, 엔진)에서만. `NEXT_PUBLIC_`에 비밀 금지 |
| 크레딧 선차감 | 유료 동작은 `consume_credits` → 처리 → 실패 시 `refund_credits`(잡은 `fail_job` 자동 환불). 차감 없이 LLM·이미지·렌더 호출 금지 |
| 코어 재정의 금지 | 인증, 조직, 크레딧, Toss, 웹훅, LLM, fal, 잡, Storage, 감사, 레이트 리밋은 `packages/core-*`를 import만. 같은 기능을 제품 안에 다시 만들지 않는다 |
| 수정 금지 | `D:/WorkSpace/platform/docs/products/_platform-core/`, `_supabase-modular/`의 다른 파일, `packages/core-*`. 필요하면 06장 6절 코어 요청에 적는다 |
| DB 변경 | `1000_publishing.sql`만, PB-06-001 담당만. 모놀리스 `0002`는 변환 스크립트로 재생성 |
| 서버가 정본 | 플랜·한도·워터마크 판정은 서버. 클라이언트 잠금은 UX 보조 |
| 렌더 위치 | WeasyPrint는 `services/render-weasyprint`에서만. Vercel 코드에서 PDF를 만들지 않는다 |
| mock 금지 | 실패를 성공처럼 반환하지 않는다. 실패와 환불을 사용자에게 보여 준다. 인증 Mock은 쿠키 역할 Mock 금지, 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(배포 환경 404, 맨 끝 "인증 단계 규칙" 절) |
| LLM 키 | `api/`(FastAPI)에만. web, worker, engine에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 web 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. web → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·원고를 넣지 않는다 |
| AI 크레딧 | 채팅·음성·낭독·설정집·색인은 제공자 호출 전에 선차감하고 끝나면 정산, 결과가 전달되지 않으면 전액 환불(01장 4.6절). 초안 그래프는 소제목 정액 선차감에 묶는다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직과 오픈소스 전용 책에 상용 제공자를 쓰지 않는다 |
| 낭독 | `feature='narration'`은 작업 도중 다른 제공자로 대체하지 않는다. 실패하면 파일을 만들지 않고 환불. TTS 입력은 DB 본문·메시지만 |
| 설정집·RAG | 책별 컬렉션 `book-<book_id>`, 설정집 slug `books/<book_id>/...`. 사람 소유 블록(`<!-- owner:user -->`)을 덮어쓰지 않고 `expected_version` 없이 저장하지 않는다. 사용자 조직 데이터를 Dify 외부 지식에 두지 않는다 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `web/src/styles/tokens.css`(`@theme`)와 `web/src/components/ui/`. 피그마·문서 hex 표·MASTER.md는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 PB-06-042 뒤 |
| 3D | three.js는 `web/src/features/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고 3D 재질 색도 토큰만 |

## 3. 디렉토리와 소유 경계

| 위치 | 책임 | 소유 작업 |
|---|---|---|
| `web/src/app/api/<리소스>/` | Route Handler | 06장 2절 표의 리소스별 단일 작업 |
| `web/src/server/{http,pricing,features,personas,sanitize,books}/` | 서버 공용 코드 | 007, 008, 008, 012, 013, 010 |
| `web/src/server/ai/`, `web/src/server/ai-pricing.ts` | 서명 토큰, HMAC, 입력 마스킹, AI 단가 | 044 |
| `web/src/features/{wizard,editor,books,finish,personas,settings,billing,landing}/` | 화면 | 021, 022, 023, 023, 023, 023, 009, 024 |
| `worker/src/handlers/` | TS 잡(LLM, 표지, 웹훅, purge) | 014, 019, 026, 036 |
| `engine/app/` | 파싱, HTML 조립, 프리셋, ePub, 렌더 잡 | 003, 015, 016, 018, 017 |
| `services/render-weasyprint/` | 공용 PDF 렌더 | 004 |
| `supabase/` | 마이그레이션, 테스트 | 001, 029 |
| `api/` | FastAPI AI 서비스: 공용 부분과 설정 043, `app/ai/products/publishing/knowledge.py` 045, `wiki_config.py` 046, `prompts/` 011, `app/ai/graphs/publishing_draft.py` 047, `publishing_assist.py`·`app/ai/compliance/publishing.py`·`rules/` 048, `app/ai/tools/publishing/` 049, `tests/publishing/security/` 055 | 043, 045, 046, 047, 048, 049, 055 |
| `web/src/app/api/{ai,internal,onboarding,voice}/` | AI·음성 Route Handler | ai·internal·onboarding 044, voice 052(narrations 053), wiki 046, references 045 |
| `web/src/features/{ai-chat,wiki,voice,narration,hero3d}/`, `web/public/hero/` | AI 화면, 3D 히어로 | 050, 051, 052, 053, 054 |
| `web/src/styles/`, `web/src/components/ui/`, `web/src/app/dev/components/` | 디자인 시스템 코드 | 040 |
| `infra/dify/` | Dify 앱 정의(키 없음) | 049 |
| `docs/file/03-설계/디자인/` | `DESIGN.md` 1절 039, 2절 이후와 `COMPONENTS.md` 042, `review/` 041(사람) | 039, 041, 042 |

다른 작업의 디렉토리에 파일을 만들지 않는다. 공용 설정(`web/package.json` 등)은 PB-06-002에 요청한다.

## 4. 코어 사용 규칙

| 상황 | 쓰는 것 |
|---|---|
| Route Handler 진입 | `const ctx = await requireSession('publishing')` 후 zod 검증, `rate_limit_hit` |
| 기능 게이팅 | `web/src/server/features`의 `feature(ctx, key)`(키 없으면 Free 기본값, 01장 4.4절) |
| 크레딧 | `credits.consume({ idempotencyKey: 'consume:publishing:<request_id>' })`, 동기 호출은 `withCredits` |
| 잡 | `jobs.enqueue({ queue: 'publishing.llm'\|'publishing.media'\|'publishing.doc'\|'publishing.render'\|'publishing.events', jobType, idempotencyKey: 'job:publishing:<request_id>', creditLedgerId })` |
| 진행률 | 클라이언트는 `core.jobs`, `publishing.generation_runs`, `publishing.sections` Realtime 구독 |
| 웹훅 비밀 | `CredentialVault.put/get`(provider `outbound_webhook`), 평문 컬럼 금지 |
| 감사 | 사용자 경로는 `write_audit`(RPC 내부에서 이미 기록), 서버 경로(환불, 운영자 조정, 탈퇴)는 service INSERT |
| Storage | 경로는 `orgPath({ orgId, appId: 'publishing', entity, ext })`만. 사용자 파일명은 표시용 컬럼에만 |
| DB 스키마 | 모듈러는 `supabase.schema('publishing')`, 코어는 `SUPABASE_DB_SCHEMA` |
| AI 게이트 | `packages/core-ai`(ai-gateway) 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인과 `book_id`의 조직을 다시 확인. 서명 토큰은 `web/src/server/ai/token.ts`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'publishing', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')` + 감사 기록 같은 고지문 버전 |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. `store_audio=false`. 첫 녹음 전 `voice.notice_ack` 감사 기록 확인 |
| 그래프 | 워커는 `/api/internal/ai-token`으로 잡 토큰을 받아 `POST /graphs/publishing.draft/runs`. FastAPI는 `ai_runs`·`ai_run_steps`·`ai_usage`를 기록하고 `sections`·`generation_runs`는 워커가 쓴다. 단건 생성은 web이 사용자 토큰으로 `publishing.assist` |
| 설정집 | 이용자 조직의 `core.wiki_pages`에 책별 slug로 둔다. 읽기는 RLS, 쓰기는 FastAPI 경유. 채택(`published`)된 페이지만 일관성 검사의 근거 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16.2.x, React 19.2, TS strict, Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전, `asChild` 없음, `buttonVariants()` + `<Link>`), three.js + React Three Fiber + drei(React 19 호환 버전), Node 20, Python 3.11(engine) / 3.12 제안(api), FastAPI 0.115 + LangChain/LangGraph(api) |
| 의존성 | 버전 고정 + lockfile 커밋. `latest` 금지 |
| 린트 | ESLint flat, `ruff`. raw `fetch`는 `web/src/lib/api` 밖에서 금지(린트 규칙) |
| 타입 생성 | `supabase gen types typescript --local --schema core,publishing > web/src/types/supabase.ts` |
| 입력 검증 | 모든 경계 zod(TS) / pydantic(Python). `any`로 Supabase 타입 우회 금지 |
| 디자인 토큰 | `web/src/styles/tokens.css`(03장 4.3절 토큰, 3.2절 의미 기반 이름). 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안). 아이콘은 Lucide |
| 스트리밍 | fetch POST + ReadableStream. EventSource 금지. 채팅은 SSE(POST 응답), 낭독 진행은 NDJSON |
| 문구 | 실패 문구는 원인과 다음 행동(환불 여부 포함). 금지 문구는 01장 6절 |

## 6. 테스트와 완료 조건

| 명령 | 기대 |
|---|---|
| `npm run lint && npx tsc --noEmit && npm run build` (web, worker) | 통과 |
| `pytest` (engine, services/render-weasyprint) | 통과 |
| `node check.mjs --vector mod <0000~0009> seed.sql 1000_publishing.sql` (`D:/WorkSpace/platform/docs/products/_tools-sqlcheck`, AI 표가 있어 `--vector` 필수) | 전부 OK |
| `node check.mjs --vector mono 0001_core_lite.sql 0002_publishing_domain.sql seed.sql` | 전부 OK |
| RLS 스모크(`supabase/tests/`) | 05장 9절 항목 전부 통과 |
| `pytest api` | 토큰·조직 격리·라우팅·그래프·채팅 평가셋(043, 045~049, 055) |
| `npm run test:ai` / `web/e2e/ai/` | AI 게이트 선차감·정산·환불, 낭독 대체 금지(044, 053, 055) |
| 결제 E2E, 핵심 플로우 E2E | PB-06-030, PB-06-037 통과 |

완료 정의 전체는 06장 7절.

## 7. 금지 패턴

07장 4절 요약(AI·디자인 항목은 끝에): `FOR ALL` 정책, `'1234'`/localStorage 잠금해제, 이메일 하드코딩 관리자, 무인증 LLM·업로드·내보내기, 빈 JWT secret 허용, 웹훅 서명 생략, 비원자 차감, 사용자 파일명을 경로로, 서버가 사용자 URL fetch, url_fetcher 무제한, 범용 AI 프록시, 전역 n8n 키, escape 없는 HTML/XML, mock 폴백, async 안 동기 호출, 마지막 1,000자 다듬기, EventSource POST, localStorage를 정본으로, 실키 `.env` 커밋, Windows 폰트 경로, 허위 수치.
AI·디자인(2026-10-13): LLM·음성 키를 브라우저·Vercel·워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·원고, 개인정보 포함 원고의 상용 제공자 대체 전송, 임의 텍스트 TTS, 낭독 중 제공자 대체, 참고 파일 장문 복사 생성, 사람 소유 위키 블록 덮어쓰기, 토큰 밖 3D 색·보라 그라디언트, "Tailwind"만 적은 지시(v3 혼입).

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`, 이 제품 반영은 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 Stage A(Mock 로그인). 로컬 `.env.local`은 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 배포 환경(Vercel 미리보기 포함)은 항상 `AUTH_MODE=live` |
| 단계 순서 | A(Mock, PB-06-006) → G1 → B(Google + 이메일, PB-06-056, P0, 공개 베타 필수) → G2 → C1 카카오(PB-06-057, P1)·C2 네이버(PB-06-058, P1) |
| 단계 분기 위치 | `AUTH_MODE`·제공자 목록을 읽는 코드는 `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/app/auth/`, `web/src/app/api/dev/login/`에만. 기능 코드·worker·engine·api는 `requireSession('publishing')`·`session_context`만 쓴다 |
| 페르소나 사용법 | `supabase start` → `supabase db reset` → `node scripts/dev/seed-users.mjs --app publishing`(제품 훅 포함) → `/login` 개발용 패널. 페르소나 키: owner, admin, member, viewer, outsider, no_app, suspended, ops, basic(05장 10절). 권한 확인은 페르소나를 바꿔 로그인해서 한다 |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장하고 테스트는 그 상태로 시작한다. Google·카카오·네이버 실로그인은 자동화하지 않고 사람이 수동 점검표로 확인한다 |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 쓰기, `mock-auth`, `nomad_role`, `nomad_plan`, 가짜 사용자 객체·가짜 세션, 원격 Supabase에 개발 계정 만들기, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·출력·로그에 두기, 인증 모듈 밖 `AUTH_MODE` 참조, 페르소나 이메일로 권한 분기, `next` 무검증 리다이렉트, 이메일 일치만으로 계정 자동 합치기(브리지) |
| 단계 전환 | 에이전트가 단계를 스스로 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 기록한 뒤에 B·C 작업을 시작한다. C2 경로(`supabase_custom` 또는 `bridge`)는 스파이크 결과를 `[DECISION]`으로 남긴다 |
| 소유 경로 | 006: `web/src/lib/auth/`, `web/src/app/api/dev/login/`, `web/src/components/dev-auth/`, `scripts/dev/`. 056: `web/src/app/(auth)/`(006에서 이어 받음), `web/src/app/auth/callback/`, `web/src/features/onboarding-terms/`. 057: `web/src/features/login-methods/`. 058: `web/src/app/auth/naver/`(브리지만), `scripts/auth/`. 배지 장착(레이아웃)과 `db:seed-users` 스크립트 등록은 PB-06-002에, 약관 단계 장착은 PB-06-044에 1줄 요청 |
| 이 제품의 B·C 작업 | B: PB-06-056(W7 맨 앞). C1: PB-06-057, C2: PB-06-058(W8, G2 후). 남은 결정: 01장 8.1절 D20(카카오 이메일), D21(네이버 경로), D22(이메일 가입 유지) |

## 에이전트 실행 계층 규칙 (2026-10-14 FLORA 개편)

정본은 01장 3.1절, 02장 10절, 04장 9절, 05장 2.5절. 화면은 03장 8절.

| 항목 | 규칙 |
|---|---|
| 새 엔진 금지 | 에이전트는 레지스트리(`web/src/server/agents/registry.ts`)가 기존 처리 함수를 부르는 것이다. 에이전트 이름으로 LLM·렌더·fal 호출 코드를 새로 쓰지 않는다 |
| 기록 | 유료 작업형 동작은 `withAgentTask`로 감싼다(채팅·받아쓰기·읽어 주기 제외). 같은 `request_id`로 `agent_tasks` 행을 멱등하게 만들고, 모든 크레딧 차감에 `p_ref_type='agent_task'`, `p_ref_id=<작업 id>`를 넘긴다. `agent_tasks`는 service_role만 쓰고 사용자 결정은 `decide_agent_task` RPC만 |
| 본문 금지 | `input_summary`, `result_summary`, `error_message`, 운영 콘솔 응답에 원고 본문·프롬프트·채팅 내용·키·토큰을 넣지 않는다. id·개수·상태·오류 코드만 |
| 승인 | 사용자가 쓴 본문은 승인 전에 바꾸지 않는다(단건 생성 덮어쓰기도 제안). 빈 소제목 AI 초안은 `gen_status='generated'`가 "검토 전"(01장 D26). 반영은 `PATCH sections`(revision) 후 결정 기록. 검수 대기는 잡 원고 작업만, 선택 영역 동작은 Diff 카드가 검수 |
| 재시도 | 실패·부분·취소 작업만, 작업당 한 번, 재시도 범위(실패분, 취소면 남은 것까지)만 차감. 원래 작업의 결과 없는 차감에 환불 행이 모두 있어야 한다(없으면 409 `refund_missing`, 차감이 없던 작업은 확인 생략) |
| 잡 마감 | 잡을 끝내는 코드가 페이로드의 `agent_task_id`로 행을 갱신한다(worker `worker/src/lib/agent-tasks.ts`, engine `engine/app/agent_tasks.py`, api `app/ai/products/publishing/agent_tasks.py`). 직접 SQL로 상태를 건너뛰지 않는다(전이 트리거 22023) |
| 운영 콘솔 | `/admin/*`는 `platform_admin`만, 일반 사용자 404. 조회마다 감사 `admin.view`. 원가 필드는 운영자 API에만. 데이터가 없으면 숫자 대신 "—" |
| 디자인 레이어 | 루트 레이아웃이 `data-surface`(marketing, workspace, ops)를 붙이고 토큰은 같은 의미 이름의 값만 바꾼다. 맞춤 마젠타는 marketing의 재단선·맞춤표와 교정 표시에만. 제안서 팔레트·Pretendard는 01장 D23·D24 결정 전까지 쓰지 않는다 |
| 소유 경로 | 059 `web/src/server/agents/`, `api/agents/`, `api/agent-tasks/`, `api/internal/agent-sync/` 등(06장 9.1절). 060 `features/agents/`, `(app)/dashboard/agents/`, 061 `features/ai-panel/`(에디터 3단 레이아웃은 022), 062 `app/admin/{books,agents,jobs,settings}/`·`api/admin/{tasks,trace,costs,books,settings,agents}/`, 064 `app/admin/graph/`(Phase 2). 027은 `app/admin/` 루트·`users/`·`billing/`·`audit/` |

## 설득형 랜딩 규칙 (2026-10-17, 검토용)

정본 `docs/file/03-설계/디자인/LANDING_PERSUASION.md`, 이 제품 반영은 01장 9장, 03장 9절, 06장 10절.

| 항목 | 규칙 |
|---|---|
| 주장 장부 | 랜딩·FAQ·인사이트에 나가는 문장은 `docs/flora-publishing/experiments/claims-ledger.md`에서 상태가 "검증"인 것만. 문구 상수와 장부가 다르면 `scripts/proof/check-claims.mjs`가 CI를 실패시킨다 |
| 비교 표시 | 대안은 범주 이름만(D28). 특정 회사·서비스 이름과 로고 금지. 가격 비교는 `/pricing`에서 출처·확인일·VAT 포함 여부와 함께만 |
| 증거 파일 | 샘플 PDF·ePub·미리보기는 CI가 렌더 서비스 출력에서 복사한 것만. 손으로 다듬은 파일, 연출 목업 금지 |
| 계산기 | 순수 함수, 입력값 서버 전송·수집 금지, 요금 값은 요금 상수 import(하드코딩 금지), 결과를 이메일 뒤에 숨기지 않는다 |
| 벤치마킹 원자료 | `D:/WorkSpace/platform/docs/products/_design-guide/benchmarks/a-rms/`의 문구·수치·slug·다크 글래스 비주얼을 쓰지 않는다(`LANDING_PERSUASION.md` 1장) |
| 컴포넌트 경계 | `web/src/components/marketing/`은 `(marketing)` 경로에서만 import. 앱 화면(TaskTimeline 등)은 같은 구조를 앱 토큰으로 따로 만든다 |
| 소유 경로 | 066 `web/src/features/landing-proof/`, `web/public/proof/`, `scripts/proof/`. 067 `docs/flora-publishing/experiments/{claims-ledger,v0-interviews,v1-task-timing}.md`. 068 `web/src/app/(marketing)/insight/`, `web/content/insight/`. 069 `web/src/app/(marketing)/tools/cost-compare/`, `web/src/features/cost-compare/`. 070 `web/src/components/marketing/` |
