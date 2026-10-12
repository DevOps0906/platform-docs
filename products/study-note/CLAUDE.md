# CLAUDE.md: Study Note

개발 에이전트용 지침. 이 제품의 기획 정본은 같은 폴더의 01~07이다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/` 의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더의 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` (특히 02장 6절, 05장, 06장 1절) |
| 3 | DB 작업이면 `docs/products/_supabase-modular/migrations/2100_notes.sql` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 비밀 | `SUPABASE_SERVICE_ROLE_KEY`, `OPENROUTER_API_KEY`는 서버/워커 전용. `NEXT_PUBLIC_`/`VITE_` 접두사 금지. 사용자 API Key 입력(BYOK) 기능을 만들지 않는다 |
| 크레딧 | 선차감은 `notes.start_run` 한 곳에서만. Route Handler나 사용자용 RPC에서 `consume_credits`를 직접 부르지 않는다 |
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
| 스택 | Next.js 16.2.9, React 19.2.6, TypeScript 6.0.3 strict, Tailwind 4.3.0. `latest` 금지, lockfile 커밋 |
| 타입 생성 | 모듈러: `supabase gen types typescript --local --schema core,notes`. 모놀리스: 기본 |
| 린트 | ESLint flat(typescript-eslint, react-hooks) |
| 디자인 토큰 | `src/styles/tokens.css` CSS 변수만 사용. 컴포넌트 안 hex 하드코딩 금지, 이모지 아이콘 금지(lucide) |
| 카피 | 01장 6.1절 금지 문구 통과. 사용자 노출 문구는 한국어 |
| 날짜 | 일지 날짜는 KST 달력 날짜 문자열(`YYYY-MM-DD`). `toISOString()`으로 날짜를 만들지 않는다 |

## 6. 테스트와 완료 조건

`06_AGENT_PLAN.md` 7절. 명령: `npm run lint`, `npx tsc --noEmit`, `npm run test`(Vitest), `npm run build`. SQL 변경 시 `docs/products/_tools-sqlcheck`에서 `node check.mjs mono ...`와 `node check.mjs mod ...`가 OK이고 RLS 스모크(NT-06-003)가 통과해야 한다.

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
