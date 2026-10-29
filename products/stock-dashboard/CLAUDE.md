# CLAUDE.md: Stock Dashboard

개발 에이전트 지침. 이 제품은 돈과 금융 규제가 걸린 초대제 베타다. 애매하면 멈추고 묻는다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`(16장 AI·음성), `DB_CONVENTIONS.md`(14장 pgvector), `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |
| 2 | 이 폴더 `01_PRD.md`(특히 6장 법·금지 문구), `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `06_AGENT_PLAN.md`(자기 작업 행), `07_SOURCE_MIGRATION.md` 4장 |
| 3 | UI 작업이면 `docs/design-module/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` stock-dashboard 절, 랜딩이면 `HERO_3D.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`, `CREDENTIALS_KEY_V<n>`, `ACCOUNT_HASH_KEY`, `STREAM_TOKEN_SECRET`는 서버·워커 전용. `NEXT_PUBLIC_` 금지. 해당 모듈은 `import 'server-only'` |
| 증권사 키 | `encrypted_credentials`에만. 평문 컬럼, localStorage, 로그, 오류 메시지, 감사 로그, 잡 payload에 넣지 않는다. 키가 없으면 기동 실패(0키 폴백 금지) |
| 계좌번호 | 입력 즉시 마스킹 + HMAC 후 원문 폐기. 화면·CSV·로그에는 마스킹 값만 |
| 조회 전용 | MVP·Phase 2에는 주문 코드 경로가 없다. Phase 3도 `env='paper'`만. 실전 주문 코드는 어떤 브랜치에도 만들지 않는다 |
| AI | 매수·매도 권유, 매수가·목표가·손절가를 생성·저장·표시하지 않는다. AI는 주문을 만들지 않는다 |
| 크레딧 | AI 호출 전 `consume_credits` 선차감, 실패 시 `refund_credits`. 사용자 RPC 안에서 차감하지 않는다 |
| 베타 게이트 | 도메인 데이터 접근은 RLS `has_stock_access`에 맡긴다. 서버에서 org_id 필터만으로 보호했다고 판단하지 않는다 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일을 수정하지 않는다. 코어 재정의 금지. 필요하면 06장 6절 요청 |
| 스키마 | 정본은 `_supabase-modular/migrations/1900_stock.sql`. 모놀리스 파일은 변환 스크립트로만 재생성 |
| 문구 | 01_PRD 6.6 금지 문구. 수익률 예시, 후기, "추천 종목", 보장 표현 금지 |
| 투자 권유 금지 | 사용자에게 보이거나 저장되는 모든 AI·음성 텍스트는 투자 권유 금지 검사(`advice_check`, 02장 5.3절)를 통과해야 한다. 검사를 실행할 수 없으면 출력하지 않는다(fail-closed). 목표가·매수가·손절가, 외부 인용 목표주가, 평가·전망 표현을 만들지 않는다. DB는 `advice_check.passed` 없는 성공 저장을 거부한다 |
| 보유 내역 비유출 | 수량·금액·평단·계좌번호를 FastAPI, Dify, LLM·음성 제공자에 보내지 않는다. 진단 입력은 비율 스냅샷, 요약·채팅·브리핑은 종목코드·기간·마스킹한 질문만 |
| LLM 키 | FastAPI(`apps/api`)에만. Vercel과 워커에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·개인정보를 넣지 않고, Dify 안에서 사용자 노출 텍스트를 모델로 만들지 않는다 |
| AI 크레딧 | 진단·요약·브리핑은 정액 선차감, 채팅·음성은 선차감 후 정산, 결과가 전달되지 않으면 전액 환불(01_PRD 4.4절). 그 밖의 파일에서 차감하지 않는다 |
| 데이터 이용 | 공시·뉴스 색인은 `STOCK_RAG_SOURCES` 허용 목록과 `docs/legal/data-sources.md` 확인 기록이 있는 소스만. 시세 틱 저장·재배포 금지 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/stock-dashboard/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿으로 1개씩 맡긴다. 화면 작업은 ST-06-037 뒤. 상승/하락 색은 미결(D-5)이므로 `--color-up`/`--color-down` 토큰만 참조 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고, 3D 재질 색도 토큰만. 장면에 수익률·`%`·상승/하락 색·실제 시세를 쓰지 않는다 |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 소유 작업 |
|---|---|---|
| `src/proxy.ts`, `src/lib/supabase/`, 루트 설정, `src/lib/auth/`, `src/app/login/`, `src/app/api/dev/`, `scripts/dev/seed-users.mjs` | 골격, 인증 모듈·Mock 로그인(Stage A). Google·콜백은 `src/components/auth/`, `src/app/auth/`(ST-06-052) | ST-06-006, 052 |
| `src/lib/security/` | 마스킹, HMAC, vault 래퍼 | ST-06-007 |
| `src/lib/broker/` | 어댑터 계약, Mock, 실증권사 | ST-06-008, 014 |
| `src/lib/quotes/` | SSE, zustand 스토어 | ST-06-016 |
| `src/lib/ai/` | 진단(021), `compare/`(030) | ST-06-021, 030 |
| `src/lib/orders/` | Phase 3 | ST-06-032 |
| `src/app/(app)/`, `(marketing)/`, `(admin)/`, `src/components/<영역>/` | 화면 | 06장 표 |
| `src/app/api/<영역>/` | Route Handler | 06장 표 |
| `workers/quote-relay/` | 시세 중계 | ST-06-015 |
| `workers/stock-jobs/src/<sync\|reference\|eval\|orders\|watchdog>/` | 잡 | 013, 019, 029, 032, 034 |
| `src/app/api/ai/`, `src/app/api/internal/`, `src/app/api/onboarding/`, `src/server/ai/` | AI 게이트(diagnoses 021, research·briefings 049, ideas 029, compare 030) | 039 |
| `src/app/api/voice/`, `src/components/voice/` | 음성(briefings는 049) | 048, 049 |
| `src/components/ai-chat/`, `src/app/(app)/chat/` | 채팅 패널 | 047 |
| `src/app/(app)/research/`, `briefing/`, `src/components/briefing/` | 리서치·브리핑 | 049 |
| `src/app/(app)/wiki/`, `src/app/(admin)/admin/wiki/`, `admin/knowledge/` | 위키 | 043, 044 |
| `src/components/hero3d/`, `public/hero/` | 3D 히어로 | 050 |
| `src/styles/`, `src/components/ui/`, `src/app/dev/components/` | 디자인 시스템 | 011 |
| `src/content/banned.json` | 금칙어 사전(언어 중립) | 026 |
| `apps/api/` | FastAPI AI 서비스(설치 038, compliance 040, 지식·수집 041, 위키 043, 그래프 045, 도구 046) | 038~046 |
| `infra/dify/`, `content/knowledge/` | Dify 앱 정의, 해설집 원고 | 046, 042 |
| `supabase/` | 마이그레이션, 테스트 | ST-06-001, 003 |

다른 작업의 디렉토리를 고치지 않는다. 공유 파일(`package.json` 등) 변경은 006 담당에게 요청한다.

## 4. 코어 사용 규칙

| 상황 | 사용 |
|---|---|
| Route Handler 진입 | `requireSession('stock')` → 베타·동의 확인 |
| 세션 정보 | `session_context('stock')` 1회 |
| 크레딧 | `withCredits({ amount: 10, reason: 'stock_diagnosis', idempotencyKey: 'consume:stock:<request_id>' }, fn)` |
| 잡 | `enqueue_job(queue 'stock.<type>', job_type 'stock.<action>', idempotency 'job:stock:<request_id>')`. payload에 비밀 금지 |
| 자격증명 | `CredentialVault.put/get`(provider `broker:<broker>:<env>`), 해제는 `revoke_credential` |
| 감사 | 사용자 경로 `write_audit`, 서버 경로 service INSERT. action `stock.<entity>.<verb>` |
| 레이트 리밋 | `rate_limit_hit('stock:<route>:<org>', limit, window)` |
| 제품 RPC | `record_consent`, `set_order_limits`, `engage_kill_switch`, `release_kill_switch`, `confirm_paper_order`(사용자), 나머지는 service |

새 SECURITY DEFINER 함수를 만들 때: `set search_path = ''`, 객체 스키마 한정, authenticated에 열면 `core.is_service_caller()` + `has_org_role`(또는 `coalesce(role,'')`), service 전용이면 `is_privileged_session()` + EXECUTE를 service_role에만. 실패를 기록해야 하는 경로는 raise 대신 상태를 남기고 반환한다.

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16.2.9, React 19, Tailwind CSS v4(4.x 고정), shadcn/ui(Tailwind v4 지원 버전), Recharts 3, zustand, zod, TanStack Query(서버 데이터만), Node 22 워커, three.js + React Three Fiber + drei(React 19 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 태그 금지, lockfile 커밋 |
| 타입 | TS strict, Supabase 생성 타입 사용, `any`로 우회 금지. `supabase gen types typescript --local > src/types/supabase.ts` |
| 린트 | ESLint flat, `latest` 버전 태그 금지, lockfile 커밋 |
| 시간 | DB는 timestamptz(UTC), 표시는 KST. "오늘"은 KST 자정 경계를 서버가 계산 |
| 숫자 | 금액은 원 단위 정수(numeric), 표시 시 천 단위 구분, 손익은 부호와 색 함께 |
| 디자인 토큰 | `src/styles/tokens.css`(03장 4.3). 컴포넌트에 hex 하드코딩 금지 |
| 모델명 | llm gateway 설정에서만. 코드·UI 문자열에 모델 버전 하드코딩 금지 |
| 샘플 | `is_sample` 또는 mock 연결 데이터에는 "샘플 데이터" 배지 |

## 6. 테스트와 완료 조건

06장 7절이 정본이다. 요약:

| 검사 | 명령(제안) |
|---|---|
| 빌드·타입·린트 | `pnpm -F stock-dashboard build typecheck lint`, 워커 `build` |
| SQL 체커 | `cd docs/products/_tools-sqlcheck && node check.mjs mono ...` / `mod ...` |
| RLS 스모크 | `pnpm test:rls`(모듈러·모놀리스 둘 다 0 실패) |
| E2E | `pnpm test:e2e` |
| AI·음성 | `pytest apps/api`(평가셋 포함), `pnpm test:ai`(선차감·정산·환불, 서명 토큰, 보유 내역 비유출, 브리핑 대체 금지), `node docs/products/_tools-sqlcheck/check.mjs --vector mod ...0000~0009 seed 1900_stock.sql`(AI 표가 있어 `--vector` 필수) |
| 비밀 번들 검사 | `pnpm check:bundle-secrets` |

## 7. 금지 패턴

07장 4절 요약: 크레딧 RPC 권한 미회수, 비원자 차감, 웹훅 서명 미검증, 토큰 평문·0키 폴백, 세션 없는 워커, `FOR ALL` 정책, 프로필 없으면 admin, 정책 자기참조, 공개 AI 프록시, `.env` 커밋, 한글 `\b` 금칙어, 증권사 키 클라이언트 노출, 계좌번호 로그, 샘플 무표시, AI의 주문 직접 생성, Vercel 장시간 SSE, `EventSource` AI 스트리밍, 시세 재배포, raise 뒤 상태 기록 기대, 스크래핑, GEO/JSON-LD 성과 노출, Context로 시세 관리, 검사 없는 AI 텍스트 노출, 보유 내역의 AI 전송, LLM 키를 Next.js·워커에 두기, Dify에서 모델 답변 생성, 임의 텍스트 TTS, 3D 장면의 수익 약속 표현.

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md`. 이 제품 적용은 `01_PRD.md` 8.1절, `02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `06_AGENT_PLAN.md` 8절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 **Stage A(Mock 로그인)**. 로컬 Supabase 시드 페르소나로 실제 JWT를 받는다. Google(B)은 G1 뒤 ST-06-052, 카카오·네이버(C)는 G2 뒤 ST-06-053·054(P2 선택, 01_PRD D-19) |
| 바뀌지 않는 것 | 초대 토큰 흐름(ST-F-001: sha256 저장, 14일 만료, `redeem_beta_invite`, 이메일 일치 `ST031`), `beta_access` 게이트, `requireSession('stock')`, `session_context`, RLS `has_stock_access`. 단계 전환은 로그인 버튼과 콜백만 바꾼다 |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH`를 읽는 코드는 `src/lib/auth/`, `src/app/login/`, `src/app/auth/`, `src/app/api/dev/`, `src/components/auth/`(초대 화면의 로그인 버튼)에만. 기능 코드·`proxy.ts`·Route Handler에 `if (mock)`·페르소나 이메일 분기 금지 |
| invite 앱 콜백 | `finishLogin`에서 `bootstrap_app_for_org`를 부르지 않는다. 엔타이틀먼트는 초대 수락만 만든다. `entitled=false`면 `/no-access`(초대 계속 중이면 `/invite/continue`) |
| 페르소나 사용 | `supabase db reset` → `node scripts/dev/seed-users.mjs --app stock`(로컬 호스트가 아니면 exit 1) → `/login` 개발용 패널. 초대 수락 `owner`, 동의 전 `fresh_beta`, 미수락 `invitee`(시드가 초대 링크 출력), `beta_revoked`, `outsider`, `no_app`, `admin`/`member`/`viewer`, `suspended`, `ops` |
| E2E | Playwright `globalSetup`이 페르소나별로 `/api/dev/login`을 불러 `storageState`를 저장한다. 실제 Google 로그인은 자동화하지 않는다(수동 점검표, B-5) |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 쓰기, `mock-auth`, `nomad_role`, `nomad_plan`, `dev-user` 우회, 인증 모듈 밖 `AUTH_MODE` 참조, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`나 배포 환경에 두기, 원격 Supabase에 시드 실행, 콜백 `next` 무검증, 초대 토큰 원문을 OAuth `redirectTo`·로그에 싣기 |
| MockBroker 구분 | 인증 Mock(`AUTH_MODE=mock`)과 증권사 `MockBroker`(`broker='mock'`, "샘플 데이터" 배지)는 다른 개념이다. 서로의 스위치를 참조하지 않고, 인증 단계 전환이 샘플 연결에 영향을 주지 않는다 |
| 단계 전환 | 사람(대표님)이 G1(`AUTH_ROADMAP.md:173-184`)·G2(`:221-229`)를 판정하고 task `log.md`에 `[DECISION] G1 통과` / `[DECISION] G2 통과`로 남긴 뒤에만 다음 단계 작업을 시작한다. 에이전트가 스스로 단계를 올리지 않는다 |
| 이 제품의 작업 ID | A: ST-06-006(인증 모듈·Mock·가드·`finishLogin`), ST-06-009(시드 제품 훅). B: ST-06-052(P0, W7 맨 앞). C1: ST-06-053(P2). C2: ST-06-054(P2) |

## 대시보드 셸·GNB 규칙 (2026-10-19)

정본: 03장 8장, 결정 대기 01장 9장(D-24~D-27). stock-dashboard 전용이며 `_design-guide` 공용 패턴과 다른 제품 문서를 고치지 않는다.

| 항목 | 규칙 |
|---|---|
| 메뉴 순서 | 03장 8.3절 표가 정본. 메뉴 배열은 `src/components/shell/nav.ts` 한 곳에 두고(제안) 화면마다 따로 만들지 않는다. 셸은 ST-06-011 소유(`src/components/shell/`)이고 다른 화면 작업은 장착 1줄을 요청한다 |
| 역할별 배열 | owner/member 배열과 platform_admin "운영" 배열은 따로 둔다(D-25). 판정은 서버 `session_context('stock')`이고 클라이언트 값(쿠키·localStorage)을 믿지 않는다. 역할 밖 메뉴는 렌더하지 않고, 직접 URL은 서버 403 |
| Phase 2·3 메뉴 | 리더보드, AI 3사 비교, 플랜·결제, 모의주문, 주문 한도, "모든 주문 멈춤" 버튼은 D-24 결정과 해당 features 전까지 GNB·헤더에 만들지 않는다. pro 판매 전 결제 링크를 셸 어디에도 두지 않는다 |
| 고지 | 하단 고정 투자 고지를 셸 레이아웃에 두어 모든 셸 화면에 보인다. 숨기거나 닫는 버튼을 만들지 않는다 |
| 색 | 토큰만(`src/styles/tokens.css`). 셸 크롬(GNB·헤더·배지)에 `--color-up`/`--color-down`을 쓰지 않는다. 동시호가 황은 경고·지연 배지와 장 시간 바 동시호가 구간만. 선택 상태 색은 D-27 결정 전까지 의미 토큰 하나로 두고 hex를 하드코딩하지 않는다 |
| 문구 | 메뉴·배지·검색 결과에 이모지, 모델명, 수익률 숫자, "추천", "AI가 고른" 같은 표현을 넣지 않는다(01장 6.6절). 샘플 연결 데이터 옆에는 "샘플 데이터" 배지 |
| 미정 자리 | AI 처리 방식·음성 자동 재생·크레딧 사용 내역은 D-26 결정 전까지 `/settings/account` 안 절로만 두고 새 경로를 만들지 않는다 |
