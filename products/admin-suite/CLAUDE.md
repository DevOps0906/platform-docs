# CLAUDE.md: Admin Suite

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`(16장 AI·음성), `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |
| 2 | 이 폴더 `README.md`, `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | 맡은 작업의 SQL: `_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql`, `supabase/monolith/<app>/` |
| 4 | UI 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` admin-suite 절. 3D 히어로(`HERO_3D.md`)는 이 제품에 적용하지 않는다 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | 서버 파일에서만. 프로비저닝, `approve_profile`, Auth Admin 초대, 스케줄에만 쓴다. 도메인 쓰기는 사용자 세션 RPC |
| 크레딧 | 해당 없음. 크레딧 RPC를 호출하지 않는다 |
| 코어 재정의 금지 | 인증, 조직, 감사, storage, toss, webhooks는 `_platform-core`를 쓴다. admin-kit는 래퍼만 |
| 수정 금지 | `_platform-core/`, `_supabase-modular/`의 다른 파일, 원본 프로젝트 폴더 |
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
| 타입 생성 | `pnpm db:types --app erp\|sms\|hms` (모듈러 `--schema core,erp` 등, 모놀리스 public) |
| 디자인 토큰 | `apps/<app>/src/theme/tokens.css`(03장 3.2절, 4.3절, 의미 기반 이름). 컴포넌트 안 hex 하드코딩 금지(`bg-[#...]` 린트 차단), 이모지 아이콘 금지, `alert()` 금지 |
| SQL 변경 | 조각을 고치면 `tools/admin-suite/to-monolith.py`로 erp/sms 모놀리스를 재생성하고 체커를 돌린다 |

## 6. 테스트와 완료 조건

`06_AGENT_PLAN.md` 7절. 명령:

```
cd docs/products/_tools-sqlcheck
node check.mjs --vector mod ../_supabase-modular/migrations/0000_core_extensions_and_schema.sql ... 0009_core_voice.sql ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1600_erp.sql ../_supabase-modular/migrations/1700_sms.sql
node check.mjs --vector mono-hms ../admin-suite/supabase/monolith/hms/migrations/0001_core_lite.sql ../admin-suite/supabase/monolith/hms/migrations/0002_hms_domain.sql ../admin-suite/supabase/monolith/hms/seed.sql
pnpm test:rls && pnpm test:e2e && pnpm -r build && pnpm -r typecheck && pnpm lint
```

AI 검사 명령(2026-10-13): AI 표가 있어 체커에 `--vector`가 필요하다. 위 모듈러 명령은 0008, 0009를 포함하고 seed, 1600, 1700 순서로 넣는다. 모놀리스는 앱마다 따로 돌린다(erp, sms도 같은 형식).

```
node docs/products/_tools-sqlcheck/check.mjs --vector mono docs/products/admin-suite/supabase/monolith/<erp|hms|sms>/migrations/0001_core_lite.sql docs/products/admin-suite/supabase/monolith/<erp|hms|sms>/migrations/0002_<erp|hms|sms>_domain.sql docs/products/admin-suite/supabase/monolith/<erp|hms|sms>/seed.sql
pytest apps/api
pnpm test:ai
```

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: OVERRIDE 비밀번호·verify-admin, 프로필 없으면 admin, 클라이언트 PageGuard, 정책 안 자기참조 재귀와 `FOR ALL`, 브라우저 직접 update, 읽기-계산-쓰기 재고 차감, 가짜 상태·하드코딩 KPI, UTC 날짜 문자열, 루트 middleware, 빈 값 0 대체, 실 URL·키 노출, `.env` 커밋, `as any`. AI·디자인(2026-10-13): 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·역할·개인정보, 요청 본문 역할로 문서 접근 판정, 전체 컬렉션 검색 후 필터, `ai_runs`에 질문·답변 본문, 제한 컬렉션 위키 생성, hms의 상용·공용 서버·공용 Dify 사용과 장애 시 대체, 환자 식별정보의 AI 전송, 클라이언트 텍스트 그대로 TTS, `consume_credits` 호출, 3D 라이브러리 추가, "Tailwind로"만 적은 지시(v3 혼입).

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md`, 이 제품 반영은 01장 2절·8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절, 07장 6절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 Stage A(Mock 로그인). 각 앱 로컬 `.env.local`은 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 배포 환경(Vercel 미리보기, 병원 배포 포함)은 항상 `AUTH_MODE=live` |
| 단계 순서 | A(Mock, ADM-06-007) → G1 → B(ADM-06-058, P0, 첫 기관 배포 필수: erp Google + 이메일 가입, sms Google + 초대 메일, hms 초대 메일 + 이메일만) → G2 → C1 카카오(ADM-06-059)·C2 네이버(ADM-06-060). C는 erp·sms만 P2 선택(01장 D-24), hms 제외 |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`를 읽는 코드는 `packages/admin-kit/src/auth/`와 앱의 `src/app/api/dev/login/`, `src/app/auth/callback/`, `src/app/(auth)/`에만. 화면·서버 도메인 코드와 `apps/api`는 `requireSession(appId)`·`requireRole`·`session_context`만 쓴다 |
| 가드 | `isMockAuthAllowed()` = `AUTH_MODE=mock` + Supabase 호스트 루프백(`127.0.0.1`·`localhost`) + `VERCEL_ENV`·`RAILWAY_ENVIRONMENT` 없음. 거짓이면 `/api/dev/login` 404, 개발용 패널 미렌더, `AUTH_MODE=mock`인데 판정이 거짓이면 기동 실패. CI에서 `AUTH_MODE=mock VERCEL_ENV=production pnpm --filter <app> build`(3앱)가 실패해야 한다(ADM-06-007, 04장 8.1절) |
| 기관 조직 | 권한은 운영자가 만든 기관 조직에 있다. `finishLogin`은 활성 기관 멤버십을 먼저 찾고, `bootstrap_app_for_org('erp')`는 erp에서 활성 기관 멤버십이 없는 새 사용자에게만 1회 부른다(활성 구성원에게 부르면 pending으로 강등된다, 04장 8.2절 3번). sms·hms는 부르지 않는다 |
| hms | Google은 01장 D-21 확정 전 끈다(배포 `AUTH_PROVIDERS=email`, 그 밖의 값이면 기동 실패, 02장 9.3절). 카카오·네이버는 만들지 않는다(의료정보 격리). Mock은 로컬 hms 프로젝트에만 계정을 만들고 환자 데이터를 시드하지 않는다. 인증 단계 변수는 AI 서비스(`api-hms`)에 넣지 않는다 |
| 페르소나 사용법 | 앱마다 로컬 프로젝트가 따로다. `supabase start` → `supabase db reset` → `node scripts/dev/seed-users.mjs --app <app>`(`<app>`은 erp, sms, hms 중 하나, 앱 훅 포함) → `/login` 개발용 패널. 공통 키 owner, admin, member, viewer, outsider, no_app, suspended, ops, erp `pending`·`inventory_manager`·`sales_manager`·`join_requested`·`join_rejected`, sms `student`·`invited`, hms `doctor`·`lab_tech`·`invited`(05장 10절). hms 시드는 환자 데이터를 만들지 않는다 |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장한다(ADM-06-035). Google·카카오·네이버 실로그인과 초대 메일 수락은 자동화하지 않고 사람이 수동 점검표로 확인한다 |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 쓰기, 로그인 화면 역할 선택, `mock-auth`, 가짜 사용자 객체·가짜 세션, 원격 Supabase에 개발 계정 만들기, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·출력·로그에 두기, 인증 모듈 밖 `AUTH_MODE` 참조, 페르소나 이메일로 권한 분기, `next` 무검증 리다이렉트, hms에 Google 켜기(D-21 (b) 확정 전), hms에 카카오·네이버 켜기(항상 금지), 이메일 일치만으로 계정 자동 합치기(브리지) |
| 단계 전환 | 에이전트가 단계를 스스로 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 기록한 뒤에 B·C 작업을 시작한다. C는 G2 때 D-24("도입")도 함께 기록돼야 시작하고, C2 경로(`supabase_custom` 또는 `bridge`)는 스파이크 결과를 `[DECISION]`으로 남긴다(D-23) |
| 소유 경로 | 007: `packages/admin-kit/src/auth/`(아래 하위 제외), 앱 3개 `src/app/api/dev/login/`, `scripts/dev/`. 058: `packages/admin-kit/src/auth/{callback,providers,terms}/`, 앱 3개 `src/app/auth/callback/`, `src/app/(auth)/`(014·022·029에서 이어 받음). 059: `providers/kakao.ts`, `login-methods/`. 060: `providers/naver.ts`, erp·sms `src/app/auth/naver/`(브리지만), `scripts/auth/`. 개발용 패널 장착은 014·022·029, 배지 장착은 020·028·033, `db:seed-users` 스크립트 등록은 005에 1줄 요청 |
| 남은 결정 | 01장 8.1절 D-21(hms Google), D-22(카카오 이메일), D-23(네이버 경로), D-24(erp·sms Stage C 도입 여부) |

## 대시보드 셸·GNB 규칙 (2026-10-19)

정본: 03장 8장, 결정 대기 01장 9장(D-25~D-28). admin-suite 전용이며 `_design-guide` 공용 패턴과 다른 제품 문서를 고치지 않는다.

| 항목 | 규칙 |
|---|---|
| 메뉴 순서 | 03장 8.3절 표(앱별 8.3.1 erp, 8.3.2 hms, 8.3.3 sms)가 정본. 메뉴 배열·묶음·역할 홈은 앱의 `src/access.ts` 한 곳에 두고(02장 2절, `defineAccess`에 묶음·순서를 함께 선언, 제안) 화면이나 AppShell 안에서 따로 만들지 않는다. 셸은 admin-kit AppShell 하나(KIT-F-008) |
| 역할 밖 메뉴 | 렌더하지 않는다. 자물쇠·흐린 메뉴·"권한 없음" 배지도 금지(KIT-F-003). 판정은 서버의 `session_context`·`my_role`과 같은 매트릭스이고 클라이언트 값을 믿지 않는다. 직접 URL은 서버 403 |
| 플랜 | 화면 단위 플랜 잠금이 없다. `ai_wiki`·`ai_assistant`가 꺼진 조직은 해당 메뉴를 숨긴다(D-25 결정 전 기본값). 판정은 서버의 `plans.features` |
| 앱 전환 | 헤더·GNB에 다른 앱(erp·hms·sms) 링크를 두지 않는다(확정 결정 2). hms 셸에 공용 서버·다른 앱 주소를 넣지 않는다 |
| 경로 | 메뉴 경로는 03장 1절 표에 있는 것만. 새 경로는 8.4절 sms `/admin/settings` 1개(D-27 기본값). 경로가 아직 없는 화면은 배열에 넣지 않는다(사이드바 링크 404 0, ADM-06-035) |
| 개수 배지 | 서버 집계 값만, 0이면 숨김. 하드코딩 금지 |
| 개인정보 | 경로 표시·메뉴 검색·개수 배지에 환자·학생·직원 이름을 넣지 않는다. 헤더 검색은 메뉴 이름만(D-28), hms 환자 검색은 `/patients` 화면에서만(접근 기록) |
| 토큰 | 셸은 `apps/<app>/src/theme/tokens.css`의 의미 기반 이름만 쓴다(03장 3.2절). 앱별 테마(ERP 코발트 라이트, HMS 야간 병동 다크, SMS 칠판 인디고 라이트)를 섞지 않고 셸 코드에 hex를 하드코딩하지 않는다 |
| 금지 | 메뉴 이모지, 알림 벨 장식, 크레딧 표시, sms student 셸의 어시스턴트·마이크 버튼 |
