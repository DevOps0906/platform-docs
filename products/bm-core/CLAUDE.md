# CLAUDE.md: BM-Core

개발 에이전트용 지침. 이 제품의 기획 정본은 같은 폴더의 01~07이다. 작성일 2026-11-11.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/` 의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 로그인·가입·콜백 작업이면 `AUTH_ROADMAP.md`(이 파일 2.1절) |
| 2 | 이 폴더의 `01_PRD.md` ~ `09_DIAGRAMS.md` (특히 02장 2절, 05장, 06장 1절) |
| 3-계산 | 계산 엔진 작업이면 정본 `08_CALCULATION_ENGINE.md`(공식·구간·경고 코드)와 06장 BM-06-018~020 |
| 3-다이어그램 | 다이어그램 작업이면 `09_DIAGRAMS.md` |
| 3-UI | UI 작업이면 `docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, 03장 3.6절 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 비밀 | `SUPABASE_SERVICE_ROLE_KEY`, AI 제공자 키, PG 키는 서버·Worker 전용. `NEXT_PUBLIC_` 접두사 금지. 사용자 API Key 입력 기능을 만들지 않는다 |
| 조직 경계 | 클라이언트가 보낸 `org_id`를 신뢰하지 않는다. 서버가 세션에서 조직을 판정한다. 모든 조직 소유 테이블에 RLS, 역할은 owner/admin/member/viewer(editor 없음). 타 조직 리소스는 404(존재 비노출) |
| 계산과 AI 분리 | 계산은 `packages/bm-engine`의 결정론적 코드만 한다. AI는 계산하지 않고 AI 값은 `suggested`로 두며 사용자 승인 후 반영한다 |
| 엔진 순수성 | `packages/bm-engine`은 React·Supabase에 의존하지 않는다. 금액은 Decimal, 통화별 반올림 명시. 결과는 입력 스냅샷·엔진 버전과 함께 저장한다 |
| 테스트 선행 | 계산 엔진 변경은 테스트를 먼저 쓴다. 기존 테스트가 하나라도 실패하면 병합하지 않는다 |
| 증거와 점수 | 증거 등급 A~E를 구분하고 E(AI 추정·창업자 가정)를 검증 데이터처럼 평가하지 않는다. 점수와 승인은 분리하고 blocking_conditions면 점수와 무관하게 보류한다 |
| 비동기·멱등 | AI·PDF는 작업 큐 + Worker. API는 작업 ID를 반환한다. 크레딧 차감·보고서 생성은 본문 `requestId`로 중복 실행을 막는다(`idempotencyKey` 표기 금지, `04_API.md#1`) |
| 크레딧 | 코어 크레딧 모듈 사용 확정(06장 6절 C-1). 선차감은 `apps/web/lib/credits/` 한 곳에서 코어 `consume_credits`를 호출한다. 그 밖의 Route Handler에서 직접 차감하지 않는다 |
| 코어 | organizations·members·subscriptions·credit_ledger·jobs·audit 테이블을 새로 만들지 않는다(코어 이름 `core.org_members`, `core.audit_log`). BM 웹훅·billing 경로 없음. `core.*` 재정의와 ALTER 금지. `_platform-core`와 `_supabase-modular`의 다른 파일을 수정하지 않는다. 필요한 변경은 06장 6절 요청으로 남긴다 |
| 서버 판정 | 플랜·역할·한도 판정은 서버(DB 함수)에서. 클라이언트 게이팅은 UX 보조 |
| Tailwind | 반드시 Tailwind CSS v4. CSS 우선 설정(`@theme`). `tailwind.config.js`, v3 문법 금지. 지시·문서에 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드(`tokens.css`와 `packages/ui`). 화면 작업은 BM-06-010 뒤. 색은 토큰만(hex 직접 사용 금지) |
| 문구 | 사업 성공·수익을 보장하는 표현 금지, 예시 데이터는 "예시" 라벨(01장 6절) |
| 장애 | mock 응답으로 숨기지 않는다. 실패는 작업 상태와 오류 코드로 보여 준다 |

### 2.1 인증 단계 규칙

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 정본 `01_PRD.md#8.1`: A=MVP 개발(로컬 시드 계정), B=공개 베타 전(Google+이메일), C=G2 후(카카오·네이버) |
| 분기 위치 | 인증 단계 분기는 인증 모듈(`apps/web/lib/platform/`, `app/(auth)/`) 안에서만. 밖에서 인증 모드를 읽으면 CI 실패 |
| 페르소나 | 로컬 시드 계정으로 owner/admin/member/viewer와 타 조직 사용자(outsider)를 쓴다(제안). 시드는 로컬 DB에서만 실행되고 원격이면 종료한다 |
| 금지 | 쿠키·localStorage에 역할·플랜 저장, `mock-auth.ts`, 콜백 `next` 무검증, 운영 빌드에서 Mock 허용(`AUTH_ROADMAP.md` 10장) |

## 3. 디렉토리와 소유 경계

`06_AGENT_PLAN.md` 1절 표를 따른다. 자기 작업의 소유 경로만 수정한다. 요약: `apps/web/{app,features,components,lib}`, `packages/{bm-engine,bm-domain,validation,ai-orchestrator,report-engine,ui}`, `workers/jobs`, `supabase/{migrations,seed.sql,tests}`. 구성 요소와 경계는 02장 2절.

## 4. 코어 사용 규칙

SQLSTATE 접두사는 `BM`으로 확정(`04_API.md`, `02_ARCHITECTURE.md`). 앱 키는 06장 C-6 기준.

| 항목 | 규칙 |
|---|---|
| 세션 | 모든 Route Handler 진입부에서 세션을 확인하고 조직 멤버십·역할을 검사한다 |
| 크레딧 | 차감·환불은 `lib/credits` 한 곳(코어 RPC 호출). 멱등 키는 `requestId`에서 파생. 소진은 402 `CR001`, 플랜 한도는 403 `plan_limit` |
| 잡 | 작업 큐에 enqueue, payload에 원문 개인정보·비밀값을 넣지 않는다. Worker가 작업 ID를 대조 |
| 자격증명 | AI·PG 키는 서버·Worker env에서만. 로그·응답에 출력하지 않는다 |
| 감사 | 역할 변경, 공유 링크 생성·철회, 평가 승인·보류, 증거 삭제, 보고서 생성은 `core.audit_log`(`write_audit`)에 기록한다 |
| 레이트 리밋 | 조직 단위 키 `bm:<route>:<org_id>`(`04_API.md#1`), 초과는 429 `rate_limited`(크레딧 소진과 구분) |
| DEFINER 함수 | `set search_path = ''`, 스키마 한정, EXECUTE 명시 정리 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js App Router, React, TypeScript, Tailwind CSS v4, shadcn/ui, React Hook Form + Zod, Supabase, Recharts, React Flow. 버전은 BM-06-001에서 최신 stable을 확인해 고정(미확인) |
| 린트·타입 | ESLint(typescript-eslint, react-hooks), `tsc` strict. `any` Supabase 캐스팅 금지 |
| 타입 생성 | `supabase gen types typescript` 결과를 커밋한다. 마이그레이션 변경 후 반드시 재생성 |
| 데이터 타입 | uuid, 금액 numeric(18,2), 비율 numeric(12,8)(5% = 0.05), 통화 char(3), 상태 text+CHECK, timestamptz(UTC), jsonb는 Zod 스키마 검증 필수 |
| 입력 검증 | API 경계마다 Zod. 오류 코드는 400/401/402/403/404/409/422/429/500 의미를 지킨다(402 크레딧, 403 플랜 한도, 429 레이트 리밋 전용) |
| 반응형 | 3구간 ~767 / 768~1199 / 1200~, 구간별 폰트 크기는 토큰(03장 6장) |
| 디자인 토큰 | `packages/ui/` 안의 `tokens.css`(`@theme`, 위치는 BM-06-007 확정) |

## 6. 테스트와 완료 조건

완료 정의는 `06_AGENT_PLAN.md` 7절. 명령 이름(스크립트는 BM-06-001이 `package.json`에 정의, 이름은 제안).

| 명령 | 용도 |
|---|---|
| `lint`, `typecheck`, `build` | 정적 검사와 빌드 |
| `test:engine` | 계산 엔진 단위 테스트(공식·경계값·시나리오) |
| `test:rls` | RLS·권한 회귀(`supabase/tests`) |
| `test:e2e` | Playwright 전 구간, 결제는 PG 테스트 모드 |
| `secscan` | 비밀·번들 키 스캔 |

## 7. 금지 패턴

정본은 `07_SOURCE_MIGRATION.md` 4장이다. 요약: 예시 수치를 실제 값으로 시드, 허용 CAC 상한을 실제 CAC로 사용, AI 추정을 검증 증거로 평가, AI가 계산, 부동소수점 금액, 클라이언트 `org_id` 신뢰, service role 키의 번들 포함, 쿠키 역할 Mock·`mock-auth.ts`·콜백 `next` 무검증.
