# CLAUDE.md: Admin Suite

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`(16장 AI·음성), `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |
| 2 | 이 폴더 `README.md`, `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | 맡은 작업의 SQL: `_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql`, `supabase/monolith/<app>/` |
| 4 | UI 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` admin-suite 절. 3D 히어로(`HERO_3D.md`)는 이 제품에 적용하지 않는다 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | 서버 파일에서만. 프로비저닝, `approve_profile`, Auth Admin 초대, 스케줄에만 쓴다. 도메인 쓰기는 사용자 세션 RPC |
| 크레딧 | 해당 없음. 크레딧 RPC를 호출하지 않는다 |
| 코어 재정의 금지 | 인증, 조직, 감사, storage, toss, webhooks는 `_platform-core`를 쓴다. admin-kit는 래퍼만 |
| 수정 금지 | `D:/WorkSpace/platform/docs/products/_platform-core/`, `_supabase-modular/`의 다른 파일, 원본 프로젝트 폴더 |
| hms 격리 | hms 코드·키·데이터를 통합 DB나 다른 앱과 섞지 않는다. hms 조각을 만들지 않는다 |
| 역할 | 관리자 역할은 core owner/admin에서 파생. 도메인 역할은 도메인 테이블. 어떤 경로로도 사용자가 자기 역할을 바꿀 수 없다 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI는 EdDSA 서명 토큰(개인키는 앱 Next.js 서버에만), Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·역할·개인정보를 넣지 않는다 |
| AI 읽기 전용 | 어시스턴트에 쓰기 도구를 주지 않는다. FastAPI는 업무·환자 테이블을 읽지 않고(허용 목록: `ai_*`, `wiki_*`, `voice_*`, 역할 확인용 테이블), 쓰기는 `ai_*`, `wiki_*`, `voice_*`만 |
| AI 역할 판정 | 문서 접근은 요청 본문·토큰 클레임이 아니라 FastAPI가 DB에서 확정한 역할로 판정한다. 허용 컬렉션마다 `match_ai_chunks`를 컬렉션 id와 함께 부른다(전체 검색 후 필터 금지) |
| AI 코어 RLS 한계 | 코어가 `ai_documents`, `wiki_*`, `ai_runs`, `ai_run_steps`를 구성원 전원에게 열어 둔다. `ai_runs`·`ai_run_steps`에 질문·답변·청크 본문을 쓰지 않고, 위키는 "위키 대상" 컬렉션 문서로만 만든다(R-14 전) |
| AI 크레딧 | 사용하지 않는다. `consume_credits`를 부르지 않는다(모놀리스에 없음). 한도는 `features.ai_*` + `rate_limit_hit`, 원가는 `ai_usage`에 기록만 |
| 라우팅 | 기능 키와 기본 체인은 02장 5절과 seed가 정본. 제공자·모델을 코드에 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 erp·sms 조직에 상용 제공자를 쓰지 않는다 |
| hms AI | 전용 서버(`hms-llm`, `hms-embed`, `hms-voice`)만. 상용 API, 공용 GPU·음성 서버, 공용 Dify, ElevenLabs 금지. 장애 시 다른 서버로 대체하지 않고 실패. 환자 식별정보 입력은 차단, 환자 테이블은 읽지 않는다. 금지 변수(`DIFY_*`, 상용 키, 공용 URL)가 있으면 기동 실패. `HMS_PHI_KEY_*`는 AI 서비스에 전달하지 않는다 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/<app>/src/theme/tokens.css`(`@theme`)와 `packages/admin-kit/src/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 앱 화면 작업은 ADM-06-044 뒤 |
| 3D | 적용하지 않는다. three.js 계열 import 금지 |

## 3. 디렉토리와 소유 경계

`02_ARCHITECTURE.md` 2절, `06_AGENT_PLAN.md` 1절 요약: `packages/admin-kit/src/{supabase,auth,members,date,realtime,ui,audit,billing,ai,theme}`는 앱 이름을 모른다(`ai/`는 하위 경로별로 046, 049, 050, 051, 052, 053 소유). `apps/<app>/src/access.ts`가 역할·홈·매트릭스의 유일한 정의. 화면 디렉토리와 `src/server/<도메인>.ts`는 같은 작업이 소유. 토큰 파일 `apps/<app>/src/theme/tokens.css`는 042 소유. `apps/api/`, `infra/dify/`, `infra/hms-ai/`는 045, 048, 049, 050, 051, 055 소유. 작업 표에 없는 디렉토리를 만지지 않는다.

## 4. 코어 사용 규칙

| 항목 | 규칙 |
|---|---|
| 진입부 | 모든 Route Handler/Server Action 첫 줄 `requireSession(appId)` → `requireRole(appId, roles)` |
| 프록시 | 앱 `src/proxy.ts`는 `createAdminProxy(access)` 한 줄. 역할 기본값 금지, 프로필 없음 로그아웃 |
| 가입 | ERP `signUp({ options: { data: { signup_app: 'erp', full_name } } })`. HMS/SMS는 초대만 |
| 감사 | 도메인 RPC가 `write_audit`를 부른다. 서버 직접 쓰기(프로비저닝)는 service INSERT로 남긴다 |
| 의료정보 | `apps/hms/src/server/phi/`만 `HMS_PHI_KEY_*`를 읽는다. 민감 읽기는 RPC(`get_patient_detail`, `get_patient_chart`, `list_lab_worklist`)만, 열람 사유 필수. 목록 화면 렌더 시 `log_phi_access('view.<screen>')` |
| 날짜 | `kstDayRange()` 등 admin-kit date만. `toISOString().split('T')` 금지 |
| Realtime | `useRealtimeTable`만, 채널명 `<app>:<org>:<entity>` |
| 결제 | Phase 2. 공용 toss 모듈. `confirm_payment_order` PM001이면 별도 호출로 `fail_payment_order`를 부른다 |

## 5. 코드 규칙

| 항목 | 값 |
|---|---|
| 스택 | Next.js 16, React 19, Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전), `@supabase/ssr` 0.12, zod, lucide-react, AI 서비스 FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 태그 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| 린트 | `pnpm lint`(`eslint .`), `no-explicit-any` 오류 |
| 타입 생성 | `pnpm db:types --app erp|sms|hms` (모듈러 `--schema core,erp` 등, 모놀리스 public) |
| 디자인 토큰 | `apps/<app>/src/theme/tokens.css`(03장 3.2절, 4.3절, 의미 기반 이름). 컴포넌트 안 hex 하드코딩 금지(`bg-[#...]` 린트 차단), 이모지 아이콘 금지, `alert()` 금지 |
| SQL 변경 | 조각을 고치면 `tools/admin-suite/to-monolith.py`로 erp/sms 모놀리스를 재생성하고 체커를 돌린다 |

## 6. 테스트와 완료 조건

`06_AGENT_PLAN.md` 7절. 명령:

```
cd D:/WorkSpace/platform/docs/products/_tools-sqlcheck
node check.mjs --vector mod ../_supabase-modular/migrations/0000_core_extensions_and_schema.sql ... 0009_core_voice.sql ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1600_erp.sql ../_supabase-modular/migrations/1700_sms.sql
node check.mjs --vector mono-hms ../admin-suite/supabase/monolith/hms/migrations/0001_core_lite.sql ../admin-suite/supabase/monolith/hms/migrations/0002_hms_domain.sql ../admin-suite/supabase/monolith/hms/seed.sql
pnpm test:rls && pnpm test:e2e && pnpm -r build && pnpm -r typecheck && pnpm lint
```

AI 검사 명령(2026-10-13): AI 표가 있어 체커에 `--vector`가 필요하다. 위 모듈러 명령은 0008, 0009를 포함하고 seed, 1600, 1700 순서로 넣는다. 모놀리스는 앱마다 따로 돌린다(erp, sms도 같은 형식).

```
node D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs --vector mono D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/<erp|hms|sms>/migrations/0001_core_lite.sql D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/<erp|hms|sms>/migrations/0002_<erp|hms|sms>_domain.sql D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/<erp|hms|sms>/seed.sql
pytest apps/api
pnpm test:ai
```

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: OVERRIDE 비밀번호·verify-admin, 프로필 없으면 admin, 클라이언트 PageGuard, 정책 안 자기참조 재귀와 `FOR ALL`, 브라우저 직접 update, 읽기-계산-쓰기 재고 차감, 가짜 상태·하드코딩 KPI, UTC 날짜 문자열, 루트 middleware, 빈 값 0 대체, 실 URL·키 노출, `.env` 커밋, `as any`. AI·디자인(2026-10-13): 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·역할·개인정보, 요청 본문 역할로 문서 접근 판정, 전체 컬렉션 검색 후 필터, `ai_runs`에 질문·답변 본문, 제한 컬렉션 위키 생성, hms의 상용·공용 서버·공용 Dify 사용과 장애 시 대체, 환자 식별정보의 AI 전송, 클라이언트 텍스트 그대로 TTS, `consume_credits` 호출, 3D 라이브러리 추가, "Tailwind로"만 적은 지시(v3 혼입).
