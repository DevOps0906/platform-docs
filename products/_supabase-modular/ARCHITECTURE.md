# 모놀리스 vs 모듈러: DB 구조 비교와 선택

## 1. 두 구조

| 구조 | 정의 | 코어 SQL | 위치 |
|---|---|---|---|
| 모놀리스 | 제품마다 Supabase 프로젝트 1개. 공통 테이블을 `public`에 "core-lite"로 축소해 포함 | `_platform-core/MONOLITH_CORE_LITE.sql` | `<제품>/supabase/monolith/` |
| 모듈러(통합) | Supabase 프로젝트 1개에 `core` + 제품 스키마들 | `_supabase-modular/migrations/0000~0007` | `_supabase-modular/` |

두 구조는 같은 함수 이름과 같은 시그니처를 쓴다(`consume_credits`, `grant_credits`, `refund_credits`, `is_org_member`, `has_org_role`, `has_entitlement`, `current_org_ids`, `session_context`, `confirm_payment_order`). 차이는 스키마 접두사(`core.` 대 `public.`)뿐이며 앱 코드는 `SUPABASE_DB_SCHEMA` 환경변수 하나로 전환한다.

## 2. 비교표

| 기준 | 모놀리스(제품별 프로젝트) | 모듈러(통합 프로젝트) |
|---|---|---|
| 데이터 격리 | 프로젝트 경계로 물리 격리. 다른 제품의 결함이 데이터에 닿지 않음 | 스키마 + RLS 논리 격리. `core` 결함은 전 제품에 영향 |
| 운영 비용 | 프로젝트 N개: 백업, 확장, 키 관리, 모니터링, 마이그레이션 적용이 N배 | 프로젝트 1개. 운영 대상 하나, Pro 플랜 요금 1회 |
| SSO / 공유 지갑 | 불가(제품마다 계정과 결제가 따로). 크로스 셀 시 재가입 | 계정 1개, 조직 지갑 1개, 엔타이틀먼트로 앱별 플랜 관리 |
| 장애 영향 범위(blast radius) | 한 제품의 DB 장애, 잘못된 마이그레이션, 커넥션 고갈이 그 제품에만 국한 | 하나의 사고가 전 제품에 전파. `core` 마이그레이션 실패 = 전 제품 중단 |
| 마이그레이션 결합도 | 제품이 각자 속도로 배포. 코어 변경은 N번 복사(편차 재발 위험, `docs/reviews/basic-master-module.md:46`) | 코어 변경 1회 적용. 대신 코어 변경은 전 제품 회귀 테스트가 필요하고 번호 범위 충돌을 관리해야 함 |
| 확장성 | 제품별로 독립 스케일, 리전 선택 가능 | 하나의 DB 인스턴스에 부하 집중. 커넥션 풀과 Realtime 채널을 전 제품이 나눔 |
| 규제 데이터 | 의료정보처럼 분리가 요구되는 데이터에 적합 | 부적합(hms 제외 사유) |
| 개발 속도(초기) | 프로젝트 생성과 env 설정을 제품마다 반복 | 로컬 스택 하나로 전 제품 개발 |
| 비용(소규모) | 무료 티어 N개로 시작 가능하나 일시정지 정책에 걸림 | 유료 1개로 안정 |
| 테스트 | 제품 테스트만 | 코어 변경 시 전 제품 RLS/RPC 회귀 테스트 필수 |

## 3. 제품별 권장

00_MERGE_ANALYSIS.md:967-969 는 "프로젝트를 분리하고 공용 패키지만 공유"를 권했고, 확정 결정 5는 org 기준 스키마 + 1인 1워크스페이스다. 두 입장을 합치면 다음과 같다.

| 제품 | 1차(출시) | 2차 | 이유 |
|---|---|---|---|
| nomad-video | 모듈러 | 유지 | 크레딧 지갑, 업로더, 커머스와 같은 계정을 공유해야 함(C-6) |
| nomad-blog | 모듈러 | 유지 | video와 같은 사용자층, 공용 모듈만 공유 |
| nomad-commerce | 모듈러 | 유지 | SNS 업로더(video 소유)를 소비하므로 같은 계정 체계가 유리 |
| flora-publishing | 모듈러 | 유지 | astro와 WeasyPrint 렌더 서비스 공유, 크레딧팩 모델 동일 |
| astro-ai | 모듈러 | 유지 | 위와 같음. 개인정보(생년월일시)는 제품 스키마에서 컬럼 암호화 |
| toon-factory | 모듈러 | 유지 | video 렌더 워커를 재사용(00_MERGE_ANALYSIS.md:1308) |
| study-note | 모듈러 | 유지 | 코어 인증만 필요 |
| live-poll | 모듈러 | 트래픽 급증 시 모놀리스 분리 검토 | Realtime 채널 부하가 다른 제품에 영향을 줄 수 있음 |
| microweb-studio | 모듈러 | 유지 | 대행 제작 단계에서는 데이터가 작음 |
| website-floria | 모듈러(폼 백엔드만) | 유지 | 문의/뉴스레터 테이블 1~2개 |
| stock-dashboard | 모놀리스 | 재검토 | 개인용, 증권사 키 보관, 법적 검토 전. 격리가 안전 |
| admin-suite ERP | 모듈러 | 고객사별 모놀리스 | 1개 고객사까지는 통합, 고객사가 늘면 고객사별 프로젝트 |
| admin-suite School | 모듈러 | 고객사별 모놀리스 | 위와 같음 |
| admin-suite Hospital(hms) | 모놀리스(강제) | 유지 | 의료정보 격리 |

## 4. 두 구조 사이의 이동

### 4.1 모놀리스 → 모듈러 (제품을 통합 프로젝트로 흡수)

| 단계 | 작업 |
|---|---|
| 1 | 제품 테이블을 `public`에서 제품 스키마로 옮기는 마이그레이션 작성: `alter table public.books set schema publishing;` |
| 2 | `profiles`, `organizations`, `org_members`, `credit_ledger`, `wallets`, `subscriptions`, `payments`를 `core` 대응 테이블에 적재. 사용자는 `auth.users` 내보내기/가져오기(Supabase CLI `auth` 덤프), `org_id`는 유지(uuid 그대로) |
| 3 | 원장은 합계를 맞춘 뒤 `core.grant_credits(..., p_reason='migration', p_idempotency_key='migrate:<org>')` 1회로 잔액을 이관하고 원본 원장은 제품 스키마에 `legacy_credit_ledger`로 보관 |
| 4 | 정책의 `public.is_org_member` → `core.is_org_member`로 치환(sed) |
| 5 | 앱 env `SUPABASE_DB_SCHEMA=core`, `supabase.schema('<product>')` 적용 |
| 6 | 통합 테스트(RLS, RPC 권한, 결제 confirm) 통과 후 전환. 구 프로젝트는 읽기 전용으로 2주 보관 |

### 4.2 모듈러 → 모놀리스 (제품을 분리)

| 단계 | 작업 |
|---|---|
| 1 | 새 프로젝트에 `MONOLITH_CORE_LITE.sql` 적용 |
| 2 | `pg_dump --schema=<product>` 로 제품 스키마를 덤프하고 `set schema public`으로 적재 |
| 3 | 해당 조직들의 `core.profiles/organizations/org_members`, 지갑 잔액, 활성 구독을 추출해 적재. 다른 제품에서도 쓰는 조직이면 지갑은 분할하지 않고 "크레딧 이관 금액"을 정책으로 정한다 |
| 4 | 통합 프로젝트에서는 해당 앱의 `core.app_entitlements`를 `expired`로 바꾸고 제품 스키마를 drop |

## 5. 결정 요약

| 항목 | 결정 |
|---|---|
| 기본값 | 모듈러(통합). 크레딧 지갑과 SSO가 제품 간 크로스 셀의 전제이고, 코어 보안 코드를 한 번만 고치기 위해서다 |
| 예외 | hms(규제), stock-dashboard(개인용, 법적 검토 전) |
| 코어 변경 규칙 | `core` 마이그레이션은 Fable 5.1 담당, 전 제품 RLS/RPC 회귀 테스트 통과 후에만 적용 |
| 장애 완화 | 제품별 커넥션 풀 상한, Realtime 채널 네이밍 `<app>:<org>:<entity>`, 잡 큐 이름 `<app>.<type>` 로 분리 |
