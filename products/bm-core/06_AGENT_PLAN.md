# 06 에이전트 작업 계획: BM-Core

작성일 2026-11-11. 작업 ID는 `BM-06-###`(약어 BM, SQLSTATE 접두사 `BM` 확정, `DB_CONVENTIONS.md` 1장). `원본 §n`은 원본 설계안(2026-11-07) 장 번호(07장 참조), `S-nn`은 03_SCREENS_UX.md 화면 ID다. 12주 로드맵(`원본 §11`)은 공격적 목표이며 14~18주가 가능하다.

## 1. 원칙과 소유 경계

경로는 제품 저장소(`bm-core/`) 루트 기준이다(`원본 §14`). 플랫폼 모노레포 배치(`apps/bm-core/`)는 02장 확정 후 접두사만 바꾼다. 병렬 에이전트는 디렉토리 단위로만 쓰고 두 작업이 같은 경로를 소유하지 않는다. 공유 파일(루트 설정, `packages/*`)은 소유 작업만 고친다.

| 원칙 | 내용 |
|---|---|
| 계산 엔진 테스트 선행 | BM-06-018(테스트·픽스처)이 BM-06-019~021보다 먼저 끝난다. 기존 테스트 전부 통과해야 병합(CI) |
| 디자인 시스템 순서 | 화면 작업은 BM-06-010(4단계) 뒤에 시작한다. 3단계(BM-06-009)는 사람이 수행한다 |
| 사람 작업 | BM-06-002(린 검증 실행), 009(비주얼 검토), 036(베타 운영)은 사람이 한다. Sonnet은 정리·옮기기만 돕는다 |
| 린 게이트 | `00_LEAN.md` 게이트 통과 = W1 진입 조건(정식 개발). W0의 003~008은 설계·스키마 초안 작업이며 게이트 통과 전 병합·배포하지 않는다(1~2주 시장 검증, `원본 §11`) |
| 코어 재사용 | organizations·org_members·subscriptions·credit_ledger·jobs·audit_log는 신규 생성 금지(`core.*` 호출·핸들러만, `05_DATA_MODEL.md#6`). BM 웹훅·billing 경로 없음 |
| 공통 규약 | 멱등 키 `requestId`, 역할 owner/admin/member/viewer, 크레딧 소진 402 `CR001`·플랜 한도 403 `plan_limit`·429는 레이트 리밋 전용(조직 단위 `bm:<route>:<org_id>`), 타 조직 접근 404(`04_API.md#1`) |
| 계산과 AI 분리 | AI는 계산하지 않는다. 계산은 `packages/bm-engine`(React·Supabase 비의존) |

| 영역 | 소유 경로 | 작업 |
|---|---|---|
| 저장소·CI | `.gitignore`, `.env.example`, `.github/workflows/bm-core-*.yml`, 루트 `package.json` | 001 |
| DB·RLS | `supabase/migrations/**`(2700~2740 `bm` 스키마만, `05_DATA_MODEL.md#9`), `supabase/seed.sql`, `supabase/tests/**` | 003, 004, 005, 006 |
| 디자인 시스템 | `packages/ui/**`, `docs/DESIGN_SYSTEM.md` | 007, 010 (009 사람) |
| 랜딩 | `apps/web/app/(marketing)/**` | 008 |
| 플랫폼 연결·인증 | `apps/web/lib/platform/**`, `apps/web/app/(auth)/**`, `apps/web/middleware.*` | 011 |
| 조직·프로젝트 API | `apps/web/app/api/v1/organizations/**`(코어 RPC 호출), `projects/**`, `versions/route*`, `versions/[id]/lock/**` | 012, 013 |
| 검증 스키마·도메인 타입 | `packages/validation/**`, `packages/bm-domain/**`(`diagrams/`는 029) | 014 |
| Wizard API | `apps/web/app/api/v1/versions/[id]/wizard/**`, `validate/**`, `parts/**` | 015 |
| 온보딩·프로젝트 화면 | `apps/web/app/(dashboard)/projects/page*`, `onboarding/**` | 016 |
| Wizard 화면 | `apps/web/features/wizard/**` | 017 |
| 계산 엔진 | `packages/bm-engine/{fixtures,tests}/**`(018), `domain/**`(019), `calculators/**`·`validators/**`(020) | 018, 019, 020 |
| 계산 API | `apps/web/app/api/v1/versions/[id]/scenarios/**`, `scenarios/**`, `calculations/**` | 021 |
| 경제성 화면 | `apps/web/features/economics/**` | 022 |
| 린 검증 | `apps/web/app/api/v1/versions/[id]/hypotheses/**`, `hypotheses/**`, `experiments/**`(API 023), `apps/web/features/experiments/**`(화면 024) | 023, 024 |
| 스코어카드 | `packages/bm-engine/domain/scorecard/**`, `apps/web/app/api/v1/versions/[id]/scorecards/**`, `scorecards/[id]/decision/**`(025), `apps/web/features/scorecards/**`(026) | 025, 026 |
| 워커 핸들러(큐는 `core.jobs`) | `workers/jobs/**`(핸들러 `report.render`·`ai.suggest`), `apps/web/app/api/v1/jobs/**`(GET만) | 027 |
| 보고서 | `packages/report-engine/**`, `apps/web/app/api/v1/versions/[id]/reports/**`, `versions/[id]/share-links/**`, `share-links/[id]/**`(028), `apps/web/features/reports/**`(033) | 028, 033 |
| Diagram Engine | `packages/bm-domain/diagrams/**`(경로 제안) | 029 |
| AI 오케스트레이터 | `packages/ai-orchestrator/**`, `apps/web/app/api/v1/ai/**` | 030 |
| 크레딧(코어 RPC 호출) | `apps/web/lib/credits/**`(마이그레이션 없음) | 031 |
| AI 화면 | `apps/web/features/ai/**` | 032 |
| 보안·E2E | `supabase/tests/security/**`, `apps/web/tests/e2e/**` | 034, 035 |
| 플랜 한도·결제 연동 | `apps/web/lib/entitlements/**`(037, billing·webhook 경로 없음), `apps/web/tests/e2e/billing/**`(038) | 037, 038 |
| 조직·결제 화면 | `apps/web/app/(dashboard)/settings/**` | 039 |
| 계측·운영 | `apps/web/lib/telemetry/**`, `workers/jobs/reports/**` | 040 |

## 2. 작업 목록

모델은 `DOC_TEMPLATE.md` 1장 기준, 선정 이유는 수용 기준 앞의 영역(돈·권한·RLS = Fable 등)이다.

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| BM-06-001 | 저장소 위생: `.gitignore`, `.env.example`(이름만), 의존성 버전 고정(작업 시점 최신 stable 확인), lockfile, 비밀 스캔·번들 키 검사 CI | `.gitignore`, `.env.example`, `.github/workflows/bm-core-ci.yml` | 없음 | P0 | S | Haiku | `.env`에 키를 넣고 커밋하면 CI 실패. `package.json`에 `latest` 없음. `NEXT_PUBLIC_`에 비밀 이름이 있으면 CI 실패 | 원본 §14 |
| BM-06-002 | 린 검증 실행(사람): 인터뷰, 랜딩 사전예약, 10명+ 실제 사용자 프로토타입 검증, 통과 기준은 실험 전 숫자로 확정 | `products/bm-core/00_LEAN.md`(플랫폼 문서) | 없음 | P0 | M | 사람 | `00_LEAN.md`에 통과 기준(숫자)과 결과가 기록된다. 미달 시 W1에 진입하지 않는다(W0 003~008은 설계·초안만) | 원본 §11, §16 |
| BM-06-003 | DB 스키마 초안(`bm`, 코어 테이블 신규 생성 금지): 스키마·`core.apps` 등록, projects, project_versions, wizard_steps, Wizard 입력 테이블 7종(customer_segments~assumptions), 타입 규칙. 코어는 `core.organizations`·`core.org_members`·`core.jobs`·`core.audit_log` 참조만 | `supabase/migrations/2700_bm.sql`, `2710_bm_model.sql` | 001 | P0 | M | Fable | `supabase db reset` 성공. `core.*` ALTER·신규 생성 0. 금액 numeric(18,2), 비율 numeric(12,8), 상태 text+CHECK, timestamptz UTC. jsonb는 스키마 검증 대상 목록 문서화. 타입 생성 성공 | 원본 §4 |
| BM-06-004 | DB 분석 테이블 초안: economic_scenarios, calculation_runs, hypotheses, experiments, evidence, rubrics, scorecards, score_items, score_evidence, reports, ai_suggestions, share_links(subscriptions·credit_ledger 생성 금지, 코어 사용) | `supabase/migrations/2720_bm_economics.sql`, `2730_bm_validation.sql`, `2740_bm_outputs.sql` | 003 | P0 | M | Fable | calculation_runs에 입력 스냅샷·결과·엔진 버전 저장 가능(`request_id` 유니크). 마이그레이션 재적용 시 오류 없음 | 원본 §4, §6, `05_DATA_MODEL.md#2` |
| BM-06-005 | RLS 정책: 조직 소유 관계, 역할 owner/admin/member/viewer(`core.org_members` 기준), Service Role 서버·Worker 한정, 비공개 버킷 정책 | `supabase/migrations/*rls*.sql` | 004 | P0 | M | Fable | 조직 A 사용자가 조직 B 행을 조회·수정하면 0행 또는 거부. viewer 쓰기 거부. 클라이언트 org_id는 무시 | 원본 §4 |
| BM-06-006 | RLS·권한 회귀 테스트(CI 자동화): 타 조직 0행, 역할별 쓰기, 함수 EXECUTE, 상태 전이, 중복 원장 없음 | `supabase/tests/**` | 005 | P0 | M | Fable | 조직 간 접근 차단 테스트 100% 통과. 실패 시 머지 차단 | 원본 §12 |
| BM-06-007 | 디자인 시스템 1·2단계: 레퍼런스 확정, Tailwind CSS v4 `@theme` 토큰(구간별 폰트 토큰 포함), 기본 컴포넌트(KPI Card, DataTable, Stepper, Scenario Selector, Evidence Drawer) | `packages/ui/**`, `docs/DESIGN_SYSTEM.md` | 001 | P0 | M | Sonnet | 컴포넌트가 상태 표대로 미리보기에 렌더. hex 직접 사용 0, `tailwind.config.js` 0. 모바일·태블릿·데스크톱 폰트 토큰 정의 | 원본 §9, 03장 3.6절 |
| BM-06-008 | 랜딩(S-01): 비교 표, 예시 대시보드, 요금 표(가정), FAQ, 3D 히어로 대체 이미지 | `apps/web/app/(marketing)/**` | 007 | P0 | M | Sonnet | 금지 문구·미검증 수치·후기 0건. 3구간(~767/768~1199/1200~) 스크린샷. 예시 데이터에 "예시" 라벨 | 원본 §9, 03장 4절 |
| BM-06-009 | 디자인 시스템 3단계(사람): 라이트/다크, 상태, 크기 배리언트 비주얼 검토 | `docs/design/review/` | 007 | P0 | M | 사람 | 기본 컴포넌트 전부의 스크린샷과 수정 수치 기록, 대비 4.5:1·포커스 링 확인 | `DESIGN_SYSTEM.md` 4장 |
| BM-06-010 | 디자인 시스템 4단계: 코드를 정답으로 확정, 문서 재작성 | `docs/DESIGN_SYSTEM.md`, `packages/ui/**`(읽기 위주) | 009 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치. 외부 파일 링크 0 | `DESIGN_SYSTEM.md` 4장 |
| BM-06-011 | 플랫폼 연결·인증: env 검증기(필수 변수 누락 시 기동 실패), Supabase 클라이언트(브라우저·서버·서비스), 세션 확인, 인증 단계(`01_PRD.md` 기준 A=MVP, B=공개 베타 전) | `apps/web/lib/platform/**`, `apps/web/app/(auth)/**`, `apps/web/middleware.*` | 001, 003 | P0 | M | Fable | 필수 env 누락 시 기동 실패. 미인증 요청 401. 번들에 service role 키 0. 인증 모듈 밖에서 인증 모드 참조 0 | 원본 §4, `AUTH_ROADMAP.md` |
| BM-06-012 | 조직·온보딩 API는 코어 호출만(코어 `organizations`·`org_members` RPC 호출, 신규 테이블·로직 없음, 엔드포인트는 04장) | `apps/web/app/api/v1/organizations/**` | 005, 011 | P0 | S | Opus | 조직 생성 시 owner 멤버 1행(코어). admin만 역할 변경, 타 조직 요청은 404. 변경이 `core.audit_log`에 남는다 | 원본 §4 |
| BM-06-013 | 프로젝트·버전 API: POST/GET `/projects`, GET/PATCH `/projects/:id`, POST `/projects/:id/versions`, GET `/versions/:id`, POST `/versions/:id/lock`. cursor 페이지네이션, 낙관적 잠금, `requestId` 멱등 | `apps/web/app/api/v1/projects/**`, `versions/route*`, `versions/[id]/lock/**` | 005, 011, 014 | P0 | M | Opus | 같은 `requestId` 2회는 같은 결과. 오래된 버전 PATCH는 409. 잠금은 owner/admin만. 오류 코드 400/401/403/404/409 일치, 타 조직 리소스는 404 | 원본 §5 |
| BM-06-014 | Zod 스키마(Wizard 7단계)와 도메인 타입(금액·비율·통화) | `packages/validation/**`, `packages/bm-domain/**` | 001 | P0 | M | Opus | 음수 이탈률·비율 범위 초과는 422 사유 반환. 단계별 완료 조건(`원본 §3`)이 스키마 테스트로 표현된다 | 원본 §3 |
| BM-06-015 | Wizard API: PUT `/versions/:id/wizard/:step`, POST `/versions/:id/validate`, POST `/versions/:id/parts`, POST `/parts/:id/pricing`, 단계 상태 전이 | `apps/web/app/api/v1/versions/[id]/wizard/**`, `validate/**`, `parts/**` | 013, 014 | P0 | L | Opus | 7단계 입력·수정·재진입이 저장 데이터와 일치. 단계 상태 draft/in_progress/completed/needs_review 전이 규칙. 배분 합계가 원 총비용과 다르면 422. Wizard 저장 p95 1초 이하 | 원본 §3, §12 |
| BM-06-016 | 온보딩·프로젝트 목록 화면(S-03, S-04) | `apps/web/app/(dashboard)/projects/page*`, `onboarding/**` | 010, 012, 013 | P0 | M | Sonnet | 03장 1장 표 구성 블록 일치. 빈·로딩·오류 상태 표시. 3구간 레이아웃 | 03장 S-03, S-04 |
| BM-06-017 | Wizard 화면(S-06): Stepper, 자동 저장, 이전 단계 수정, 단계 상태 표시 | `apps/web/features/wizard/**` | 010, 015 | P0 | L | Sonnet | 입력 중 새로고침해도 값 유실 없음. 이전 단계 수정 후 의존 단계가 needs_review. 키보드로 끝까지 입력 가능 | 03장 S-06 |
| BM-06-018 | 계산 엔진 테스트·픽스처 선행: BookForge 기준값(공헌이익 20,300·LTV 406,000·BEP 148·LTV/CAC 4.51), 시나리오 3종(BEP 223/148/114, LTV 200,000/406,000/약 733,333), 경계값(0 나누기, 음수 공헌이익, 이탈률 0%), 배분 합계 | `packages/bm-engine/fixtures/**`, `packages/bm-engine/tests/**` | 014 | P0 | M | Opus | 구현이 없는 상태에서 테스트가 실패(Red)로 존재한다. 위 기준값과 경계값이 테스트 케이스로 전부 있다 | 원본 §6, §12 |
| BM-06-019 | 엔진 domain: money(Decimal·통화별 반올림), metrics, pricing, cost-allocation(원인 기준 우선), scenarios | `packages/bm-engine/domain/**`(scorecard 제외) | 018 | P0 | M | Fable | 금액 연산에 부동소수점 없음. 배분 합계 = 원 총비용. 통화 반올림 규칙이 코드에 명시. React·Supabase import 0 | 원본 §6 |
| BM-06-020 | 엔진 calculators·validators: contribution-margin, customer-ltv, acquisition-cost, break-even, revenue-forecast, scenario-analysis | `packages/bm-engine/calculators/**`, `validators/**` | 018, 019 | P0 | L | Opus | 018의 모든 테스트 통과. 결과마다 공식·가정 목록·경고 반환. 기존 테스트 하나라도 실패하면 CI 머지 차단. 단순 계산 p95 200ms | 원본 §6, §14 |
| BM-06-021 | 계산 API: POST `/versions/:id/scenarios`, POST `/scenarios/:id/calculate`(`requestId`, mode), GET `/calculations/:id`. 입력·결과·engineVersion 저장 | `apps/web/app/api/v1/versions/[id]/scenarios/**`, `scenarios/**`, `calculations/**` | 004, 013, 020 | P0 | M | Opus | 응답에 calculationId, engineVersion, results, warnings. 실제 CAC와 허용 CAC 상한이 별도 필드. 같은 `requestId` 재호출은 같은 calculationId. 음수 이탈률은 422 | 원본 §5 |
| BM-06-022 | 경제성 분석 화면(S-07): Scenario Selector, KPI, 차트(Recharts·워터폴), 공식·가정·경고 | `apps/web/features/economics/**` | 010, 021 | P0 | L | Sonnet | 시나리오 3종 전환 시 결과가 API 값과 일치. 경고 문구 표시. 3구간 반응형 | 03장 S-07 |
| BM-06-023 | 린 검증 API: POST `/versions/:id/hypotheses`, 실험, 증거(비공개 버킷), 증거 등급 A~E, 통과 기준 버전 잠금 | `apps/web/app/api/v1/versions/[id]/hypotheses/**`, `hypotheses/**`, `experiments/**` | 004, 013, 014 | P0 | M | Opus | 잠금된 통과 기준 수정 시 409. 전 등급(A~E) 출처·측정 방법 없으면 422. 파일 경로는 서버가 정한다 | 원본 §7 |
| BM-06-024 | 린 검증 화면(S-08): 보드, 증거 서랍, 판정 표시 | `apps/web/features/experiments/**` | 010, 023 | P0 | M | Sonnet | 가설→실험→증거→판정 추적 가능. 등급 배지에 아이콘·글자 병행. 키보드로 서랍 열기·닫기 | 03장 S-08 |
| BM-06-025 | 스코어카드 엔진·API(테스트 먼저 작성): 5축×4지표, rubric_version, blocking_conditions, POST `/scorecards/:id/decision`(owner/admin) | `packages/bm-engine/domain/scorecard/**`, `apps/web/app/api/v1/versions/[id]/scorecards/**`, `scorecards/[id]/decision/**` | 019, 023 | P0 | M | Opus | 축 만점 20·합계 100. 점수와 별개로 blocking_conditions면 보류(85점이어도). 평가 버전 보존 | 원본 §8 |
| BM-06-026 | 스코어카드·대시보드 화면(S-05, S-09): KPI 4종, 점수 구성 막대, 근거 증거 연결 | `apps/web/features/scorecards/**` | 010, 021, 025 | P0 | L | Sonnet | 대시보드 지표가 저장 데이터와 일치. 근거 없는 점수 경고 표시. 개요·경제성·평가 시각화 P0 3종 | 03장 S-05, S-09 |
| BM-06-027 | 워커 핸들러(큐·claim·재시도는 `core.jobs` 사용, 신규 구현 없음): `report.render`·`ai.suggest` 핸들러, GET `/jobs/:id`(RLS SELECT), 결과 재현 | `workers/jobs/**`, `apps/web/app/api/v1/jobs/**` | 004, 011 | P1 | M | Opus | 핸들러가 코어 claim 루프에서 1회만 실행. 실패 시 코어 `fail_job` 재처리. 작업 ID로 상태 조회. 로그에 본문·키 0 | 원본 §2, §5 |
| BM-06-028 | report-engine PDF 생성, POST `/versions/:id/reports`, 공유 링크(POST `/versions/:id/share-links`, DELETE `/share-links/:id`, 만료·철회, 플랜 `pdf_export`) | `packages/report-engine/**`, `apps/web/app/api/v1/versions/[id]/reports/**`, `versions/[id]/share-links/**`, `share-links/[id]/**` | 025, 027 | P1 | L | Opus | 보고서 내용이 저장 데이터와 일치. PDF 성공률 99% 이상(`원본 §1` 목표, 가정). 만료·철회 링크는 접근 거부. 중복 생성 방지 | 원본 §5, §12 |
| BM-06-029 | Diagram Engine: 정규화 데이터에서 Mermaid 코드 생성(개요·평가·Gantt 등) | `packages/bm-domain/diagrams/**` | 021, 023, 025 | P1 | M | Opus | 같은 입력이 항상 같은 Mermaid 코드. `mmd-check` 문법 검사 통과. Mermaid 문자열은 저장 정본이 아님 | 원본 부록 C |
| BM-06-030 | ai-orchestrator: 요청 → 큐 → 권한·크레딧·입력 검증 → 조회 → 모델 선택 → JSON 스키마 검증(제한 재시도) → 제안, POST `/ai/suggestions` | `packages/ai-orchestrator/**`, `apps/web/app/api/v1/ai/**` | 011, 021, 027, 031 | P1 | L | Opus | 스키마 위반 응답은 반영되지 않고 실패 기록. 모델별 토큰·비용 기록. 프롬프트 버전 저장. 개인정보 최소 전달 | 원본 §10 |
| BM-06-031 | 크레딧 코어 호출(원장 신규 구현 없음): `consume_credits` 선차감·`refund_credits` 호출 래퍼, 소진 시 402 `CR001`, 조직 단위 레이트 리밋(`bm:<route>:<org_id>`, 초과 429 `rate_limited`) | `apps/web/lib/credits/**` | 004, 011 | P1 | S | Fable | 같은 `requestId` 재전송은 차감 1회. 소진 시 402 `CR001`(429 아님). 실패 시 환불 1행(코어). 원장 합계 = 잔액(코어 검증 인용) | 원본 §5, §10 |
| BM-06-032 | AI 제안 화면(S-11)과 Wizard 제안 패널: suggested 표시, 승인·거절 | `apps/web/features/ai/**` | 017, 030 | P1 | M | Sonnet | 승인 전 입력값 불변. 승인 이력 저장. 예상 크레딧 표시. 크레딧 부족(402 `CR001`)·레이트 리밋(429) 각각 안내 | 03장 S-11, 2.6절 |
| BM-06-033 | 보고서 화면(S-10)과 공유 보기(S-15) | `apps/web/features/reports/**` | 010, 028 | P1 | M | Sonnet | 생성 진행·실패·재시도 표시. 만료 링크 안내. 3구간 반응형 | 03장 S-10, S-15 |
| BM-06-034 | 보안 회귀 테스트: 전 API 조직 간 차단, Service Role 번들 검사, AI 입력 최소화, 비밀 스캔(`secscan`) | `supabase/tests/security/**` | 006, 021, 023, 025 | P0 | M | Fable | 조직 간 접근 차단 테스트 100%. 번들에 service role 키·제공자 키 0. 타 조직 리소스 ID 요청은 404(존재 비노출). 028·030 대상 케이스는 P1 도입 시 추가(선행 아님) | 원본 §12, §15 |
| BM-06-035 | E2E(Playwright)·성능·접근성: Wizard→경제성→검증→스코어 P0 구간(PDF·AI 구간은 028·030·032·033 완료 시 확장), API p95 500ms, 계산 p95 200ms, 저장 p95 1초, axe 위반 0 | `apps/web/tests/e2e/**` | 017, 022, 024, 026 | P0 | L | Opus | P0 구간 시나리오 통과. 성능 목표 충족. 최신 Chrome·Edge·Safari 통과. WCAG 2.2 AA 자동 점검 위반 0 | 원본 §12 |
| BM-06-036 | 베타 운영(사람): 베타 사용자 모집, 결함 분류, 피드백 반영 | 없음 | 035 | P0 | M | 사람 | 치명 결함 0건으로 W4 종료. 결함 목록이 기록된다 | 원본 §11 |
| BM-06-037 | 플랜 한도·기능 접근 적용(결제·웹훅은 코어 Toss 경로 사용, BM billing·webhook 경로 없음): `core.app_entitlements` 키(`projects_max`, `scenarios`, `economics`, `scorecard`, `pdf_export`, `ai_analysis`) 서버 판정 | `apps/web/lib/entitlements/**` | 004, 011, 031 | P1 | M | Fable | 한도 초과·플랜 미포함은 403 `plan_limit`. 플랜 한도(프로젝트 수·기능)가 서버에서 판정된다. 클라이언트 값 무시 | 원본 §13 |
| BM-06-038 | 결제 E2E(코어 Toss 경로·테스트 모드): 성공, 취소, 금액 위조, 중복 confirm | `apps/web/tests/e2e/billing/**` | 037 | P1 | M | Opus | 4개 시나리오 통과, 잔액·원장 일치 | `DOC_TEMPLATE.md` 필수 |
| BM-06-039 | 조직 관리·결제·구독 화면(S-12, S-13) | `apps/web/app/(dashboard)/settings/**` | 010, 012, 037 | P1 | M | Sonnet | 역할별 노출 구분(owner만 결제). 플랜 부족 시 비활성 + 안내. 3구간 반응형 | 03장 S-12, S-13 |
| BM-06-040 | 계측·운영: Sentry·구조화 로그, 제품 목표 지표 이벤트(Wizard 완료율·첫 BM 시간·재방문), 백업 확인(RPO 24h, RTO 4h) | `apps/web/lib/telemetry/**`, `workers/jobs/reports/**` | 035 | P1 | M | Opus | 지표 이벤트가 대시보드 쿼리로 집계된다. 오류가 Sentry에 기록. 복구 절차 1회 리허설 기록 | 원본 §1, §12 |

P0 작업과 대응 테스트: 003·004·005 → 006, 011 → 034·035, 012·013·015 → 035·006, 014·015 → 035(+018 스키마 경계), 019·020·021 → 018(선행), 025 → 025 자체 테스트 선행·035, 016·017·022·024·026 → 035(접근성 포함), 001 → CI 자체 검사. 결제 E2E는 038, RLS 회귀는 006·034.

원본 범위 밖 항목(P2): 템플릿 관리(S-14), Report Writer, 컨설턴트·기관 B2B API는 12주 로드맵 밖이라 작업을 분해하지 않았다(팀장 결정 필요).

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 주차(`원본 §11`) | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|---|
| W0 | 1~2주 시장 검증·설계 | 001, 002, 003, 004, 005, 006, 007, 008 | 최대 4(001·002·003·007 시작) | 없음(002 게이트 통과가 W1 진입 조건. 003~008은 설계·스키마 초안 작업) | 저장소 위생, 린 검증 결과, DB·RLS 초안·회귀 테스트, 디자인 1·2단계, 랜딩 |
| W1 | 3~4주 인증·조직·프로젝트·Wizard | 009, 010, 011, 012, 013, 014, 015, 016, 017 | 최대 4 | W0 완료, 002 통과, 화면은 010 | 디자인 3·4단계, 인증, 조직·프로젝트·Wizard API, Wizard 7단계 저장 |
| W2 | 5~7주 계산·시나리오·검증·스코어 | 018, 019, 020, 021, 022, 023, 024, 025, 026 | 최대 4(018 먼저) | W1 완료 | 계산 엔진(테스트 통과), 시나리오, 린 검증, 스코어카드, 대시보드 |
| W3 | 8~9주 PDF·AI 제안·작업 큐 | 027, 028, 029, 030, 031, 032, 033 | 최대 4 | W2 완료 | 작업 큐, PDF, Diagram Engine, AI 제안, 크레딧 |
| W4 | 10~11주 보안·E2E·베타 | 034, 035, 036 | 2(036은 035 후) | W2 완료(P0 기준. W3 P1 작업은 선행 아님) | 보안 회귀, E2E·성능, 베타 |
| W5 | 12주 결제·계측·운영 | 037, 038, 039, 040 | 최대 3 | W4 완료, 치명 결함 0 | 결제, 조직·결제 화면, 계측·운영(제한적 유료 출시) |

공개 베타 조건은 W4 완료(P0 전부, 치명 결함 0)다. 결제 W5는 베타 이후이며 일정이 밀리면 W3·W5 P1 작업부터 줄인다.

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 9 (003, 004, 005, 006, 011, 019, 031, 034, 037) | 24.3% | 17/78 = 21.8% |
| Opus | 17 (010, 012, 013, 014, 015, 018, 020, 021, 023, 025, 027, 028, 029, 030, 035, 038, 040) | 45.9% | 37/78 = 47.4% |
| Sonnet | 10 (007, 008, 016, 017, 022, 024, 026, 032, 033, 039) | 27.0% | 23/78 = 29.5% |
| Haiku | 1 (001) | 2.7% | 1/78 = 1.3% |
| 합계 | 37 | 100% | 78 |

비율은 모델 작업 37개 기준이다. 사람 작업 3개(002, 009, 036, 모두 M)는 뺐다(전체 40개). Fable 몫이 큰 이유: DB·RLS·인증·크레딧·결제·계산 domain(돈·권한·정확성)이 위험도 높음이다(`DOC_TEMPLATE.md` 1장).

## 5. 리뷰 작업 흡수표

해당 없음: 신설 제품이라 원본 리뷰가 없다. 대신 원본 위험 7건(`원본 §15`)의 흡수 작업을 적는다. 원본 위험 등급 "매우 높음"은 심각도 "높음"으로 옮긴다.

| 위험 | 심각도 | 흡수한 작업 ID |
|---|---|---|
| AI 허위 시장 근거 | 높음 | 023(증거 등급), 025, 030, 034 |
| 부정확한 계산 | 높음(원본 매우 높음) | 018, 019, 020, 021 |
| 낮은 유료 전환 | 높음 | 002(유료 사전예약·가격 실험), 037 |
| 조직 간 노출 | 높음(원본 매우 높음) | 005, 006, 034 |
| AI 비용 증가 | 중간~높음 | 030, 031, 040 |
| 지원사업 양식 변경 | 중간 | 범위 밖(P2 템플릿 관리, 2장 말미) |
| 범위 과다 | 높음 | 우선순위 P0/P1/P2 분류(2장), 웨이브 3장 |

## 6. 공용 모듈 요청

코어 변경은 제품이 하지 않는다. C-1~C-3은 확정(코어 사용)이며 003·004·027·031·037은 그 범위로 축소했다.

| ID | 요청 | 이유 | 상태 |
|---|---|---|---|
| C-1 | 코어 작업 큐·크레딧·구독 사용(BM 자체 테이블 없음) | 003·004·027·031·037 범위 축소 | 확정 |
| C-2 | 공용 결제 모듈(코어 Toss) 사용, BM 웹훅·billing 경로 없음 | 037·038 | 확정 |
| C-3 | 공용 AI 게이트웨이(코어 `ai_routing_settings`·`ai_usage`) 사용 | 030 범위(orchestrator는 호출·검증만) | 확정 |
| C-4 | 인증 단계: A=MVP, B=공개 베타 전(`01_PRD.md`), Supabase Auth 구성 | 011 | 확정(구성 세부는 011에서) |
| C-5 | `_design-guide`의 BM-Core 레퍼런스 절 추가 | 03장 4.1절 URL 근거 | 중간 |
| C-6 | SQLSTATE 접두사 `BM` 등록(`DB_CONVENTIONS.md` 1장) | 작업 ID·오류 코드 | 확정 |

## 7. 완료 정의

| 구분 | 조건 |
|---|---|
| 빌드·타입·린트 | 빌드, `tsc` strict, ESLint 통과. `latest` 의존성 0 |
| 테스트 | 계산 엔진 공식·경계값 전부 통과, RLS 회귀 100%, 보안 회귀 통과, E2E 통과, 결제 E2E(038) 통과 |
| 인수 기준(`원본 §12`) | Wizard 7단계 입력·수정·재진입, 자동 저장 유실 없음, 버전 조회·비교, 배분 합계 일치, 실험·증거·결과 추적, 점수 근거·평가 버전 보존, AI 스키마 검증·승인, 보고서=저장 데이터, 조직 간 접근 차단 |
| 비기능(`원본 §12`) | API p95 500ms, 단순 계산 p95 200ms, Wizard 저장 p95 1초, 가용성 99.5%/월, RPO 24h·RTO 4h, WCAG 2.2 AA, 최신 Chrome·Edge·Safari |
| 작업 | 06장 작업 40개 완료(사람 작업 002·009·036 포함). 버전 비교 화면은 03장에서 별도 화면이 없어 팀장 결정 필요 |
| 게이트 | `00_LEAN.md` 게이트 통과(002) = W1 진입 조건(W0 003~008은 설계·초안만) |
