# CLAUDE.md: Study Note

개발 에이전트용 지침. 이 제품의 기획 정본은 같은 폴더의 01~07이다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/` 의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 로그인·가입·콜백 작업이면 `AUTH_ROADMAP.md`(이 파일 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더의 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` (특히 02장 6절, 05장, 06장 1절) |
| 3 | DB 작업이면 `docs/products/_supabase-modular/migrations/2100_notes.sql` |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 3-UI | UI 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` study-note 절, 랜딩이면 `HERO_3D.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 비밀 | `SUPABASE_SERVICE_ROLE_KEY`, `OPENROUTER_API_KEY`는 서버/워커 전용. `NEXT_PUBLIC_`/`VITE_` 접두사 금지. 사용자 API Key 입력(BYOK) 기능을 만들지 않는다 |
| 크레딧 | 일지 정리의 선차감은 `notes.start_run` 한 곳에서만. AI·음성은 `POST /api/ai/organize`, `/api/ai/chat`, `/api/ai/wiki/lint`, `/api/ai/quizzes/sessions`, `/api/voice/stt`·`tts`·`lectures/[id]/chunks`와 정산 크론에서만 선차감·정산한다(04장 1·2.1절). 그 밖의 Route Handler나 사용자용 RPC에서 `consume_credits`를 직접 부르지 않는다 |
| LLM·음성 키 | LLM 키는 워커(OpenRouter, 일지)와 FastAPI(`apps/api`)에만. Vercel에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`, `/api/notes/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·개인정보를 넣지 않는다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.3절과 seed가 정본. 제공자·모델을 코드에 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용 제공자를 쓰지 않는다 |
| 강의 녹음 | `lecture_note` STT는 강제 오픈소스(상용 호출·대체 금지). 녹음 시작 전 고지 확인, 원본은 기본 폐기, 보관 시 `consent_at`·`consent_kind='third_party_notice'`·`notice_version`·`expires_at` |
| 위키 | 사용자가 고친 블록(`<!-- owner:user -->`)을 에이전트가 수정하지 않는다. 저장은 `expected_version` 필수. slug는 해시 기반 ASCII, 한글은 `title` |
| 퀴즈 | 문제 조회 응답에 정답·해설을 넣지 않는다. TTS는 서버에 저장된 메시지·퀴즈만 낭독 |
| Tailwind | 반드시 Tailwind CSS v4(4.3.0 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/study-note/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿으로 1개씩. 화면 작업은 NT-06-034 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고 3D 재질 색도 토큰만 |
| 코어 | `core.*` 재정의와 ALTER 금지. `_platform-core`와 `_supabase-modular`의 다른 파일을 수정하지 않는다. 필요한 변경은 06장 6절 요청으로 남긴다 |
| 쓰기 | 사용자 세션이 쓰는 테이블은 `entries`, `user_settings`뿐. 나머지는 service_role/RPC |
| 서버 판정 | 플랜/등급/한도 판정은 서버(DB 함수)에서. 클라이언트 게이팅은 UX 보조 |
| 장애 | mock 응답으로 숨기지 않는다. 실패는 단계 상태와 환불로 보여 준다 |

## 3. 디렉토리와 소유 경계

`06_AGENT_PLAN.md` 1절 표를 따른다. 자기 작업의 소유 경로만 수정한다. pipeline(`src/lib/pipeline`)은 순수 함수만(부수효과, fetch, env 접근 금지).

## 4. 코어 사용 규칙

| 항목 | 규칙 |
|---|---|
| 세션 | 모든 Route Handler 진입부에 `requireSession('notes')`. 실행 계열은 이메일 인증 필수 |
| 크레딧 | `notes.start_run`(service)이 차감, `finish_run`이 환불. 멱등 키는 `request_id`에서 파생 |
| 잡 | `core.jobs` 큐 `notes.organize`. payload에 원문과 비밀값을 넣지 않는다. 워커는 `runs.job_id = job.id`를 대조 |
| 감사 | 동의, 내보내기, 취소, 삭제는 `write_audit` |
| 레이트 리밋 | `core.rate_limit_hit('notes:<route>:<org_id>', ...)` |
| DEFINER 함수 | `set search_path = ''`, 스키마 한정, 사용자 호출용은 `is_service_caller()` + NULL-safe 역할 검사, EXECUTE 명시 정리 |

## 5. 코드 규칙

| 항목 | 값 |
|---|---|
| 스택 | Next.js 16.2.9, React 19.2.6, TypeScript 6.0.3 strict, Tailwind CSS v4(4.3.0), shadcn/ui(v4 지원 버전), three.js + React Three Fiber + drei(React 19 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 금지, lockfile 커밋(Python은 `uv.lock`, 제안) |
| 타입 생성 | 모듈러: `supabase gen types typescript --local --schema core,notes`. 모놀리스: 기본 |
| 린트 | ESLint flat(typescript-eslint, react-hooks) |
| 디자인 토큰 | `src/styles/tokens.css` CSS 변수만 사용. 컴포넌트 안 hex 하드코딩 금지, 이모지 아이콘 금지(lucide) |
| 카피 | 01장 6.1절 금지 문구 통과. 사용자 노출 문구는 한국어 |
| 날짜 | 일지 날짜는 KST 달력 날짜 문자열(`YYYY-MM-DD`). `toISOString()`으로 날짜를 만들지 않는다 |

## 6. 테스트와 완료 조건

`06_AGENT_PLAN.md` 7절. 명령: `npm run lint`, `npx tsc --noEmit`, `npm run test`(Vitest), `npm run build`, `pytest apps/api`(토큰·조직 격리·라우팅·그래프·채팅 평가셋: NT-06-035, 039, 040, 048, 049). SQL 변경 시 `docs/products/_tools-sqlcheck`에서 `node check.mjs mono ...`와 `node check.mjs mod ...`가 OK이고 RLS 스모크(NT-06-003)가 통과해야 한다.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약.

| 금지 | 이유 |
|---|---|
| 번들 인라인 비밀 env, 실키 `.env` 커밋 | 키 유출. 노출 의심 시 OpenRouter에서 키를 재발급하고 워커 env를 교체한다 |
| 브라우저에서 OpenRouter 호출, 무인증 프록시 | 비용 폭증 |
| 실행 중 재실행 허용, `request_id` 없는 실행 | 이중 과금 |
| 클로저 상태 기반 재시도, 초기화 안 되는 draft | 상태 불일치 |
| `toISOString()` 날짜 | KST 오류 |
| 가상 후기, 미검증 수치, 보장 표현 | 01장 6.1절 |
| AI·디자인(2026-10-13) | LLM·음성 키를 브라우저·Vercel에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보, 제3자(강의자) 음성의 상용 전송, 퀴즈 정답 선공개, 클라이언트 텍스트 그대로 TTS, 사용자 위키 블록 덮어쓰기, 토큰 밖 3D 색·파스텔 스티커, "Tailwind"만 적은 지시(v3 혼입). `07_SOURCE_MIGRATION.md` 4절 |

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본: `docs/products/_platform-core/AUTH_ROADMAP.md`. 제품 반영: 01장 NT-F-001·8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 **Stage A(Mock 로그인)**. 실제 제공자(Google·카카오·네이버) 콘솔 설정과 버튼을 만들지 않는다. 이메일 가입·인증 메일·비밀번호 재설정 화면도 B에서 만든다. 이메일 인증 가드(`email_confirmed_at`)는 A부터 서버에 둔다 |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH`를 읽는 코드는 `src/lib/auth/`, `src/app/(auth)/login/`, `src/app/auth/callback/`, `src/app/api/dev/login/`, (C2 브리지) `src/app/auth/naver/`에만. 워커·FastAPI·AI 게이트·기능 화면에 `if (mock)` 금지(CI NT-06-022) |
| 페르소나 사용 | 로컬: `supabase start` → `supabase db reset` → `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD` → `node scripts/dev/seed-users.mjs --app notes`(`npm run db:seed-users`) → `/login` 개발용 패널. 페르소나 목록은 05장 10절(`owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops`, `unverified`, `low_credit`) |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장하고 테스트는 그 상태로 시작한다(NT-06-024). 실제 Google 로그인은 자동화하지 않는다 |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 쓰기, `mock-auth`, `nomad_role`, `nomad_plan`, `dev-user` 우회, 페르소나 이메일로 권한 분기, 원격 DB에 시드, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`나 로그에, 콜백 `next` 무검증(07장 6절) |
| 배포 | 배포 환경은 `AUTH_MODE=live`. `AUTH_MODE=mock VERCEL_ENV=production` 빌드는 실패해야 하고 `/api/dev/login`은 404 |
| 단계 전환 | 에이전트가 스스로 바꾸지 않는다. 사람(대표님)이 G1(`AUTH_ROADMAP.md` 4장)·G2(6장)를 판정하고 task `log.md`에 `[DECISION] G1 통과`·`[DECISION] G2 통과`로 기록한 뒤 해당 작업을 시작한다 |
| 이 제품의 작업 ID | A: NT-06-006(범위 변경, W2). B: NT-06-053(P0, W6 맨 앞, G1 후). C1: NT-06-054(카카오, P1, W7, G2 후). C2: NT-06-055(네이버, P1, W7, G2 후) |
| 첫 제품 | study-note는 개발 순서상 첫 제품이라 Stage A 시드 스크립트 계약(`AUTH_ROADMAP.md` 2.3·2.4절)이 처음 실전 검증되는 곳이다. 계약과 다르게 동작하면 코드를 조용히 맞추지 말고 `[DECISION]`과 06장 C-12 요청으로 남긴다 |

## 대시보드 셸·GNB 규칙 (2026-10-19)

정본: 03장 8장, 결정 대기 01장 9장(D-24~D-26). study-note 전용이며 `_design-guide` 공용 패턴과 다른 제품 문서를 고치지 않는다. 이 제품의 앱 셸은 `/app` 아래(`src/app/(app)/`)다.

| 항목 | 규칙 |
|---|---|
| 메뉴 순서 | 03장 8.3절 표가 정본. 메뉴 배열은 `src/components/shell/nav.ts` 한 곳에 두고(제안) 화면마다 따로 만들지 않는다. 셸(`src/app/(app)/layout.tsx`, `src/components/shell/**`)은 06장 1절 소유 표에 없다. Header를 이식하는 NT-06-016에 더하는 것을 제안한다(06장 반영은 별도 승인 후). 그 전에는 다른 작업이 레이아웃 파일을 만들지 않는다 |
| 새 경로 | 셸 작업으로 새 경로를 만들지 않는다. `/app/quiz` 목록은 D-25, 학습 홈 `/app/home`은 D-24 결정 전까지 만들지 않는다 |
| 잠금·한도 | 플랜·등급·한도 판정은 서버(DB 함수, `plans.features`)이고 셸·GNB의 표시는 UX 보조다(2절 서버 판정). 메뉴를 플랜으로 숨기지 않는다. 크레딧·플랜은 owner 외 비활성 |
| 키 | 셸·설정 어디에도 API Key 입력란을 두지 않는다(01장 D-2, 원본 SettingsPanel의 키 입력은 폐기) |
| 채팅 패널 | 헤더 [내 노트에 묻기] 한 곳에서 연다(NT-06-041 컴포넌트를 셸이 장착). 브라우저는 `/api/ai/*`만 부른다 |
| 녹음 중 이동 | 강의 녹음 중에는 셸이 "녹음 중" 표시등 + 텍스트를 고정하고 메뉴 이동 전에 확인한다. 이미 올라간 조각은 보존 |
| 색 | 토큰만(`src/styles/tokens.css`). 셸에 hex를 하드코딩하지 않는다. 선택 상태는 `--color-accent`(교정청록), 형광노랑(`--color-highlight`)은 검색 일치 강조에만(제안). 메타 글자는 4.5:1을 넘는 토큰을 쓴다(괘선 원색은 방안지 위 3.93:1, 03장 8.8절) |
| 홈 데이터 | "오늘 처리할 일"과 한도 막대는 실제 상태(`ai_documents`, `ai_runs`, `voice_jobs`, `wiki_revisions`, `credit_balances`)에서만. 더미 배열·mock 응답·난수 지표 금지(2절 장애, 7절) |
