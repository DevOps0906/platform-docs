# 02 아키텍처: BM-Core

작성일 2026-11-11. 근거 원본 B장 2·6·10·14·15(`research/00_SOURCE_DESIGN.md`). 원본 수치·정책은 모두 "제안"이며 정본은 `01_PRD.md`다. 스키마 `bm`, 마이그레이션 2700대, SQLSTATE 접두사 `BM`, 약어 `BM`(작업 ID `BM-06-###`). 코어(`_platform-core/CORE_SPEC.md`)가 있는 것은 다시 만들지 않는다.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router, React, TypeScript | Next.js 16(최신 stable은 착수 시 재확인), 나머지 미확인 | 원본 2장, `CORE.md` |
| UI | Tailwind CSS v4, shadcn/ui, Recharts, React Flow | 미확인(착수 시 확인) | 원본 2·C장 |
| 폼·검증 | React Hook Form, Zod(Wizard·API·AI 출력·jsonb 공용) | 미확인 | 원본 2장 |
| DB·인증 | Supabase Postgres 15, Auth, Storage, Realtime(작업 진행률) | PG 15(`DB_CONVENTIONS.md`) | 원본 2장 |
| 계산 엔진 | `packages/bm-engine`: React·Supabase 비의존 TS 패키지, Decimal 연산 | 라이브러리 미정(08#9) | 원본 6장 |
| 잡 | `core.jobs` + Worker(`workers/jobs`, TS) | 코어 규약 | `CORE_SPEC.md` 9장 |
| AI | 코어 ai-gateway 경유 OpenAI·Claude(구체 모델 `미확인`) | 5장 | 원본 2·10장 |
| 결제 | Toss Payments(코어 toss 모듈) | 확정 결정 4 | `CORE_SPEC.md` 5장 |
| 관측 | Sentry + 구조화 로그 | 미확인 | 원본 2장 |

패턴: **모듈형 모놀리스**(원본 권장). 계산과 AI 판단 분리, 증거 기반, 버전 관리, 멀티테넌트 RLS, AI·PDF 비동기, MVP 우선(원본 2장 설계 원칙). Python 런타임·3D·Dify·음성은 쓰지 않는다(해당 없음: 채팅·음성이 BM 범위에 없음, 단 AI 채팅·RAG·음성이 플랫폼 MVP 필수인지는 팀장 결정 필요 `01_PRD.md`).

## 2. 모듈 경계

`bm-core/`는 원본 14장 구조를 유지한다(플랫폼 모노레포 안의 배치 경로는 팀장 결정 필요).

| 경로 | 책임 | 하지 않는 것 |
|---|---|---|
| `apps/web/app/(marketing)` | 랜딩 | 인증 필요 데이터 |
| `apps/web/app/(auth)` | 로그인·콜백. `src/lib/auth/`만 인증 단계 분기 | 단계 분기를 다른 곳에 두기 |
| `apps/web/app/(dashboard)` | 온보딩·프로젝트·Wizard·경제성·검증·스코어·보고서 화면 | 계산 로직, 금액·점수 판정 |
| `apps/web/app/api/v1` | Route Handler. 입력 Zod 검증 → `requireSession('bm')` → 엔진·RPC 호출 | 비즈니스 계산 구현 |
| `apps/web/features/{projects,wizard,economics,experiments,scorecards,reports}` | 화면별 훅·폼·차트 | DB 직접 접근(공용 클라이언트만) |
| `packages/bm-engine` | 공식·배분·시나리오·스코어. 순수 함수. 상세 `08_CALCULATION_ENGINE.md` | I/O, React, Supabase, 시계, 난수 |
| `packages/bm-domain`, `packages/validation` | 도메인 타입, Zod 스키마(Wizard 단계·실험·증거·배분 구성), `bm-domain/diagrams/`(Diagram Engine) | 엔진 호출 |
| `packages/ai-orchestrator` | 에이전트 6종 프롬프트(버전 관리), 출력 스키마, 재시도 정책. ai-gateway 호출만 | 제공자 SDK 직접 호출·키 보유 |
| `packages/report-engine` | 저장 데이터 → 보고서 문서 모델(HTML) | 계산 재수행(저장된 `calculation_runs` 결과만 사용) |
| `packages/ui` | KPI Card·DataTable·Stepper·Scenario Selector·Evidence Drawer | |
| `workers/jobs` | `core.jobs` claim 루프, 핸들러(`report.render`, `ai.suggest`) | 도메인 판단(엔진·orchestrator 호출만) |
| `supabase/{migrations,seed.sql,tests}` | 2700대 조각, seed, RLS 스모크 | `core.*` ALTER |

Diagram Engine(원본 C장): Mermaid 문자열이 아니라 정규화 데이터가 정본이고 Mermaid 코드는 생성물이다. 구현 위치는 `packages/bm-domain/diagrams/`(Phase 2, `01_PRD.md#2`). 계산 엔진 CI 규칙: 기존 테스트 전부 통과해야 병합(원본 14장).

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth, org | 세션·조직·역할(owner/admin/member/viewer) | `requireSession('bm')`, `proxy.ts` | 원본 editor는 `member`로 대체. 조직·멤버 테이블 신규 없음 |
| credits | AI 제안 크레딧 선차감·환불, 월 플랜 크레딧 | Route Handler(service_role) | 원본 `credit_ledger` 신규 없음 |
| toss | 구독·크레딧팩 결제, 플랜 전이 | 코어 경로 그대로 | 원본 `subscriptions` 신규 없음. 요금표는 `core.plans`(app=bm) 행 |
| jobs | 보고서 PDF, AI 제안 | Route Handler `enqueue_job`, 워커 | 원본 `jobs` 신규 없음 |
| audit | 버전 잠금·승인·삭제·공유 링크 기록 | 제품 RPC 안 `write_audit` | 원본 `audit_logs` 신규 없음(코어 이름 `audit_log`) |
| storage | 증거 파일(`org-files`), PDF(`exports`) | Route Handler | 경로 `<org_id>/bm/<entity>/<uuid>.<ext>` |
| webhooks, oauth | 결제 웹훅(코어 경로) | 코어 | BM 자체 웹훅·OAuth 연동 없음 |
| ai-gateway | AI 제안 중계·`ai_usage` 기록·서명 토큰 | `/api/v1/ai/suggestions` 내부 | 브라우저는 제공자 직접 호출 금지 |
| 렌더 서비스(weasyprint) | PDF 변환 후보(`SHARED_MODULES.md` 10장) | `report.render` 워커 | 한글 폰트·차트 렌더 적합성 `미확인`(스파이크 필요) |
| rate limit | `bm:<route>:<org_id>` 키 | Route Handler | 수치 `04_API.md#1` |

제외(사용하지 않음): affiliate, sns uploader, fal, compliance, core-voice, dify, llm-wiki(해당 없음).

## 4. 잡과 워커

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `report.render` | `bm.report` | TS(+ 렌더 서비스) | 없음(플랜 한도 `features.pdf_export`만. 과금 여부 `01_PRD.md#8` D-10) | max 3(제안), 코어 지수 백오프 | 해당 없음 |
| `ai.suggest` | `bm.ai` | TS(orchestrator) | 있음. `consume:bm:<request_id>`, 단가 `01_PRD.md#4` | max 2, 스키마 검증 실패 시 제한 재시도(원본 10장) | 최종 실패 시 코어 `fail_job`이 자동 `refund_credits` |

- 상태 정본은 `core.jobs`. 진행률은 Realtime 구독(RLS). 페이로드는 `04_API.md#4`.
- 하트비트 60초 이하, `reap_stale_jobs(600)`(코어 14장). 비밀값은 payload에 넣지 않는다.
- 계산은 잡이 아니다: 단순 계산 p95 200ms 목표라 동기 Route Handler로 처리한다(원본 12장). 시나리오 일괄 계산이 느리면 `calc.batch` 잡을 추가한다(제안, 측정 후).
- Make·n8n은 알림·CRM·사전예약 수집만. 계산·핵심 데이터에 쓰지 않는다(원본 10장).

## 5. AI 라우팅

ai-gateway 모듈 사용. BM에는 LangGraph 그래프가 없다(MVP는 단일 호출 + 구조화 출력 검증). 값은 모두 제안이며 `ai_routing_settings`(org null, app=`bm`) seed와 일치시킨다.

| purpose(에이전트) | 우선순위 | 모델 등급 | 크레딧 | 폴백 | 강제 오픈소스 |
|---|---|---|---|---|---|
| `bm.problem_analyst` | P1 | fast | 미정(01_PRD#4) | 다음 상용 제공자 | 아니오 |
| `bm.pricing_analyst` | P1 | quality | 미정 | 위와 같음 | 아니오 |
| `bm.cost_auditor` | P1 | quality | 미정 | 위와 같음 | 아니오 |
| `bm.validation_planner` | P1 | fast | 미정 | 위와 같음 | 아니오 |
| `bm.score_reviewer` | P1 | quality | 미정 | 위와 같음 | 아니오 |
| `bm.report_writer` | P2 | quality | 미정 | 위와 같음 | 아니오 |

실행 흐름(원본 10장): 요청 → `core.jobs` 큐 → 권한·크레딧·입력 검증 → 데이터 조회(AI에 최소 정보만) → 프롬프트·모델 선택 → 분석 → JSON 스키마 검증(실패 시 제한 재시도, 실패 기록) → `bm.ai_suggestions`(suggested) → 사용자 승인 시 반영, 거절 시 폐기. 계산이 필요하면 AI가 아니라 엔진을 호출한다(AI 계산 금지). 국외 이전 고지·상용 제공자 사용 동의는 `01_PRD.md#6`. 모델 구체값·단가는 `미확인`.

## 6. 위험 차단 설계

리뷰 문서가 없는 신규 제품이라 "리뷰 높음 결함" 표는 해당 없음이다. 대신 원본 15장 위험 중 높음 이상을 차단 설계에 매핑한다(수 = 5).

| 위험(원본 15장) | 심각도 | 차단 설계 | 담당 |
|---|---|---|---|
| 부정확한 계산 | 매우 높음 | 순수 엔진 + Decimal + 회귀 픽스처(08#7·8), 입력·결과·엔진 버전 저장, CI 병합 조건 | `08_CALCULATION_ENGINE.md`, `05_DATA_MODEL.md#2` calculation_runs |
| 조직 간 노출 | 매우 높음 | 전 테이블 `org_id` + RLS + 복합 FK + org_id 서버 파생, RLS 스모크 | `05_DATA_MODEL.md#4`·`#7` |
| AI 허위 시장 근거 | 높음 | AI 값은 suggested 상태, 증거 등급 E, 출처·측정 방법 필수, 승인 후 반영 | `05_DATA_MODEL.md#2` ai_suggestions, evidence |
| 낮은 유료 전환 | 높음 | 린 검증 모듈(가설·실험·증거)과 스코어 blocking 조건 | `05_DATA_MODEL.md#2` |
| 범위 과다 | 높음 | P0/P1/P2 분리, AI·PDF는 P1 | `01_PRD.md#2` |

AI 비용 증가(중~높)는 크레딧 선차감·조직 단위 레이트 리밋·월 예산 상한(`ai_usage` 집계, 상한값 팀장 결정 필요)로 막는다. 지원사업 양식 변경(중간)은 템플릿 버전(P2, 범위 밖).

## 7. 배포 토폴로지

| 구성 | 배치 | 비고 |
|---|---|---|
| 웹·Route Handler | Vercel(원본 2장) | service_role 키는 서버 런타임에만 |
| DB·Auth·Storage·Realtime | Supabase(모듈러 `core` + `bm`) | `config.toml [api].schemas`에 `bm` 추가, 타입 `--schema core,bm` |
| 워커 | 상시 프로세스 호스트(플랫폼 기본값 Railway 가정, 확정은 팀장 결정 필요) | Vercel 서버리스는 claim 루프 부적합 |
| AI·렌더 | ai-gateway(Next.js 서버) → 제공자. 렌더 서비스는 워커에서 호출 | 브라우저 직접 호출 없음 |
| 스케줄 | 코어 14장 크론 그대로. BM 전용 크론 없음 | |

네트워크 경계: 브라우저 → Vercel(anon 키 + 사용자 JWT) → Supabase. 워커·결제·크레딧·계산 저장은 service_role. 가용성 99.5%/월, RPO 24h·RTO 4h는 원본 12장 제안값(Supabase·Vercel SLA와 비교 `미확인`).

## 8. 환경변수

| 변수 | 용도 | 공개(NEXT_PUBLIC) | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 클라이언트 | 예 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버·워커 전용 | 아니오 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`/`public` 전환(모듈러 기본 `core`) | 아니오 | 기동 실패 |
| `NEXT_PUBLIC_TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY` | 결제(코어 toss) | 앞 것만 예 | 결제 라우트 기동 실패 |
| `AI_TOKEN_PRIVATE_KEY` | ai-gateway 서명 토큰(Next.js만) | 아니오 | AI 라우트 기동 실패 |
| LLM 제공자 키(변수명 ai-gateway 규약 따름, `미확인`) | 상용 AI | 아니오 | AI 비활성이 아니라 기동 실패(조용한 mock 금지) |
| `SENTRY_DSN` | 오류 수집 | 예(DSN) | 경고만(제안) |
| `BM_AI_MONTHLY_BUDGET_KRW` | AI 비용 상한(제안, 값 팀장 결정 필요) | 아니오 | 상한 미적용 시 AI 비활성 |

## 9. 인증 단계

`requireSession('bm')`는 인증 단계(A Mock → B Google → C 카카오·네이버, `AUTH_ROADMAP.md`)와 무관하게 같다. 지금 단계와 제공자 구성은 `01_PRD.md`에서 정한다. 단계 분기는 `src/lib/auth/`에만 둔다. OAuth 첫 로그인은 엔타이틀먼트가 없으면 `bootstrap_app_for_org('bm')`을 콜백에서 1회 호출한다(`CORE_SPEC.md` 18장).
