# CLAUDE.md: Study Note

개발 에이전트용 지침. 이 제품의 기획 정본은 같은 폴더의 01~07이다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `D:/WorkSpace/platform/docs/products/_platform-core/` 의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더의 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` (특히 02장 6절, 05장, 06장 1절) |
| 3 | DB 작업이면 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2100_notes.sql` |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 3-UI | UI 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` study-note 절, 랜딩이면 `HERO_3D.md` |

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

`06_AGENT_PLAN.md` 7절. 명령: `npm run lint`, `npx tsc --noEmit`, `npm run test`(Vitest), `npm run build`, `pytest apps/api`(토큰·조직 격리·라우팅·그래프·채팅 평가셋: NT-06-035, 039, 040, 048, 049). SQL 변경 시 `D:/WorkSpace/platform/docs/products/_tools-sqlcheck`에서 `node check.mjs mono ...`와 `node check.mjs mod ...`가 OK이고 RLS 스모크(NT-06-003)가 통과해야 한다.

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
