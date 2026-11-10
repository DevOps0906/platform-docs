# 05 데이터 모델: BM-Core

작성일 2026-11-11. 근거 원본 B장 4·7·8·10·12·C장(`research/00_SOURCE_DESIGN.md`), 규칙 `_platform-core/DB_CONVENTIONS.md`. 스키마 `bm`, 모듈러 기본(마이그레이션 2700대). 타입: 금액 `numeric(18,2)`, 비율 `numeric(12,8)`(5% = 0.05), 통화 `char(3)`, 상태 `text + CHECK`, 시각 `timestamptz`(UTC), jsonb는 Zod 검증 필수. 모든 수치는 제안.

원본 테이블 24개 중 6개(`organizations`, `organization_members`, `subscriptions`, `credit_ledger`, `jobs`, `audit_logs`)는 만들지 않고 코어를 재사용한다(6절). 신규 제안 4개(`wizard_steps`, `rubrics`, `ai_suggestions`, `share_links`)를 더해 제품 테이블은 22개다.

## 1. 개요와 ERD

ERD는 `diagrams/erd.mmd`(생성 예정, 다이어그램 요청은 보고에 기재). 텍스트 요약(`core.*`는 참조만):

```
core.organizations 1─* bm.projects 1─* bm.project_versions
  bm.project_versions 1─* wizard_steps | customer_segments | value_propositions | business_parts
                        | allocation_rules | assumptions | economic_scenarios | hypotheses | scorecards
                        | reports | ai_suggestions | share_links
  business_parts 1─* pricing_plans | cost_items(*─1 allocation_rules)
  economic_scenarios 1─* calculation_runs
  hypotheses 1─* experiments 1─* evidence *─* score_items(score_evidence)
  scorecards 1─* score_items ; scorecards *─1 rubrics(rubric_version)
  reports ─ core.jobs ; ai_suggestions ─ core.jobs, core.credit_ledger
```

공통 규칙(모든 테이블에 적용, 표에서 생략): 표준 컬럼 `id uuid pk default gen_random_uuid()`, `org_id uuid not null → core.organizations on delete cascade`, `created_at`, `created_by uuid`(FK 없음), UPDATE 가능한 테이블은 `updated_at` + `core.set_updated_at()` 트리거. `version_id`를 가진 테이블은 `(version_id, org_id) → project_versions(id, org_id)` 복합 FK로 org 불일치를 막고, `org_id`는 `bm.set_org_from_parent()` 트리거가 부모 행에서 채운다(클라이언트 값 무시).

## 2. 테이블

### 2.1 `bm.projects` (목적: 사업 아이디어 단위)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| name | text | N | | 1~120자 |
| status | text | N | `active` | `active`/`archived` |
| currency | char(3) | N | `KRW` | 프로젝트 통화(08#3 반올림 기준) |
| current_version_id | uuid | Y | | 최신 편집 버전(FK 지연) |
| row_version | integer | N | 1 | 낙관적 잠금 |
| deleted_at | timestamptz | Y | | 소프트 삭제 |

### 2.2 `bm.project_versions` (목적: 재현 가능한 사업 모델 스냅샷)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| project_id | uuid | N | | FK |
| version_no | integer | N | | `unique(project_id, version_no)` |
| status | text | N | `draft` | `draft`/`locked`/`archived` |
| parent_version_id | uuid | Y | | 복제 원본 |
| note | text | Y | | |
| locked_at, locked_by | timestamptz, uuid | Y | | 잠금 시각·행위자 |
| row_version | integer | N | 1 | |

제약: `unique(id, org_id)`(복합 FK 대상).

### 2.3 `bm.wizard_steps` (신규 제안. 목적: 7단계 상태)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| step | smallint | N | | 1~7 CHECK, `unique(version_id, step)` |
| status | text | N | `draft` | `draft`/`in_progress`/`completed`/`needs_review` |
| completed_at | timestamptz | Y | | 완료 = 입력 형식 완결(시장 검증 완료와 구분) |
| row_version | integer | N | 1 | |

### 2.4 `bm.customer_segments` (Wizard 1)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| persona | text | N | | 고객군 |
| problem | text | N | | 핵심 문제 |
| current_alternative | text | Y | | 현재 대안 |

### 2.5 `bm.value_propositions` (Wizard 2)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| statement | text | N | | 가치 제안(정량 표현 권장) |
| solution | text | Y | | 해결 방법 |
| differentiation | text | Y | | 차별성 |

### 2.6 `bm.business_parts` (Wizard 5)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| name | text | N | | 예 SaaS, 전자책 |
| type | text | N | | `saas`/`content`/`education`/`project`/`other` |
| role | text | Y | | `acquisition`/`core_revenue`/`growth`/`cashflow` |
| revenue_model | text | Y | | 구독·건당 등 |

### 2.7 `bm.pricing_plans` (Wizard 3)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id, part_id | uuid | N | | 복합 FK |
| name | text | N | | 요금제명 |
| amount | numeric(18,2) | N | | `>= 0` |
| billing_period | text | N | | `month`/`year`/`one_time`/`usage` |
| included_usage, overage_unit_price | numeric(18,2) | Y | | 포함 사용량·초과 단가 |
| effective_from | timestamptz | Y | | 유효 시작 |

(원본에는 `version_id`가 없었으나 RLS·잠금 판정을 위해 추가한 제안)

### 2.8 `bm.cost_items` (Wizard 4·5)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id, part_id | uuid | N | | 복합 FK |
| name | text | N | | 예 AI API, 결제수수료 |
| cost_type | text | N | | `fixed_monthly`/`variable_per_user`/`usage_based`/`one_time` |
| amount | numeric(18,2) | N | | `>= 0` |
| allocation_rule_id | uuid | Y | | 공통비면 필수(구현 검증) |

### 2.9 `bm.allocation_rules` (Wizard 5)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| name | text | N | | |
| basis | text | N | | `usage`/`revenue_share`/`time_spent`/`campaign`/`fixed_ratio`/`direct` |
| configuration | jsonb | N | | `{weights:{<part_id>:number}}`(Zod, 가중치는 비율이 아니라 원 단위 가중, 08#6) |

### 2.10 `bm.assumptions` (가정과 출처)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| metric_key | text | N | | 예 `monthly_churn`. `unique(version_id, metric_key)` |
| value | numeric(18,8) | N | | |
| unit | text | N | | `krw`/`ratio`/`count`/`month` |
| grade | text | N | `E` | A~E(7절 증거 등급). 값 출처가 AI·창업자 가정이면 E |
| evidence_id | uuid | Y | | 근거 증거 |

### 2.11 `bm.economic_scenarios` (Wizard 4)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| name | text | N | | |
| kind | text | N | `custom` | `base`/`conservative`/`optimistic`/`custom` |
| parameters | jsonb | N | | 가정 override(변동비·이탈률·고정비·CAC·고객 수 등, Zod) |
| row_version | integer | N | 1 | `calculate`의 `scenarioRowVersion` |

### 2.12 `bm.calculation_runs` (append-only)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id, scenario_id | uuid | N | | 복합 FK |
| engine_version | text | N | | 예 `1.0.0` |
| input_snapshot | jsonb | N | | 계산에 쓴 전체 입력 |
| input_hash | text | N | | 재현 검증용 |
| result | jsonb | N | | 지표 + 공식·가정 목록 |
| warnings | jsonb | N | `[]` | |
| currency | char(3) | N | | |
| request_id | uuid | N | | `unique`(멱등) |

UPDATE·DELETE 금지 트리거(SQLSTATE `22023`, 코어 원장 패턴). 조직 삭제 연쇄만 예외.

### 2.13 `bm.hypotheses` (Wizard 6)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| statement | text | N | | 예 "월 29,000원 구독" |
| status | text | N | `open` | `open`/`validated`/`rejected`/`inconclusive` |
| priority | smallint | Y | | |

### 2.14 `bm.experiments`
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id, hypothesis_id | uuid | N | | 복합 FK |
| method, metric | text | N | | 방법·지표 |
| sample_size, duration_days | integer | Y | | 표본·기간 |
| pass_threshold, fail_threshold | numeric(18,8) | Y | | 통과·실패 기준 |
| status | text | N | `planned` | `planned`/`running`/`completed` |
| result | text | Y | | `passed`/`failed`/`inconclusive`(completed에서만) |
| criteria_locked_at | timestamptz | Y | | 이후 기준 변경 `BM001` |

제약: `result is null or status='completed'`, `pass_threshold > fail_threshold`(제안).

### 2.15 `bm.evidence`
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| experiment_id | uuid | Y | | 가정 근거면 null 가능 |
| grade | text | N | | A~E |
| source_type | text | N | | 결제·로그·사전예약·인터뷰·설문·시장조사·AI·가정 등 |
| measurement_method, source_note | text | N | | 출처·측정 방법 필수(빈 문자열 CHECK) |
| measured_at | timestamptz | Y | | |
| storage_path | text | Y | | `org-files` 경로(비공개) |

### 2.16 `bm.rubrics` (신규 제안)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| org_id | uuid | Y | | null = 플랫폼 기본 |
| rubric_version | text | N | | `unique(coalesce(org_id, zero uuid), rubric_version)` |
| definition | jsonb | N | | 5축×4지표, 지표별 0~5 판정 기준 |
| blocking_rules | jsonb | N | `[]` | 예 법적 문제, 실결제 검증 0건(Zod) |
| is_active | boolean | N | true | |

쓰기는 service_role(seed·운영)만.

### 2.17 `bm.scorecards`
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| rubric_version | text | N | | 평가 당시 버전 보존 |
| total_score | smallint | N | | 0~100 |
| axis_scores | jsonb | N | | 5축별 0~20 |
| blocking_hits | jsonb | N | `[]` | 발동한 blocking 조건 |
| status | text | N | `draft` | 3절 |
| decided_by, decided_at, decision_note | | Y | | 승인·보류 |

### 2.18 `bm.score_items` / 2.19 `bm.score_evidence`
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id, scorecard_id | uuid | N | | 복합 FK |
| dimension | text | N | | `market`/`profitability`/`validation`/`feasibility`/`scalability` |
| indicator_key | text | N | | 축당 4개, `unique(scorecard_id, indicator_key)` |
| score | smallint | N | | 0~5 CHECK |
| rationale | text | Y | | 근거 문장 |

`score_evidence(score_item_id, evidence_id, org_id)`: PK 복합, 둘 다 같은 `version_id` 소속이어야 한다(트리거 `BM002`). 증거 없는 항목은 가능하나 보고서·화면에 "근거 부족"으로 표시.

### 2.20 `bm.reports`
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| template_key | text | N | `default` | 지원사업 양식 템플릿은 P2(범위 밖) |
| status | text | N | `queued` | `queued`/`rendering`/`ready`/`failed` |
| job_id | uuid | Y | | → `core.jobs` |
| storage_path | text | Y | | `exports` 버킷 |
| snapshot_hash | text | Y | | 사용한 `calculation_runs`·`scorecards` 해시 |

### 2.21 `bm.ai_suggestions` (신규 제안)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| agent | text | N | | 6종(`02_ARCHITECTURE.md#5`) |
| target_type, target_id | text, uuid | N, Y | | 반영 대상 |
| payload | jsonb | Y | | 스키마 검증을 통과한 제안만 |
| status | text | N | `queued` | 3절 |
| prompt_version | text | N | | |
| job_id, credit_ledger_id | uuid | Y | | 코어 참조(FK 없음 허용) |
| decided_by, decided_at | | Y | | 승인 이력 |

### 2.22 `bm.share_links` (신규 제안, P1)
| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| version_id | uuid | N | | FK |
| token_hash | text | N | | `unique`. 원문 토큰은 저장하지 않음 |
| expires_at | timestamptz | N | | 최대 30일(제안) |
| revoked_at | timestamptz | Y | | 철회 |

공유 링크 열람은 서버 라우트가 service_role로 해시를 검증한다(anon 테이블 접근 없음).

## 3. 상태 전이

| 테이블.컬럼 | 현재 | 허용 전이 | 누가 | 부수 효과 / 방식 |
|---|---|---|---|---|
| project_versions.status | draft | locked, archived | owner/admin(`lock_version`) | `locked_at` 기록, 하위 쓰기 `BM001`, 감사. RPC |
| | locked | archived | owner/admin | 수정하려면 새 버전 복제 |
| wizard_steps.status | draft | in_progress | 쓰기 역할 | 트리거 |
| | in_progress | completed, draft | 쓰기 역할 | 완료 조건 검사(RPC) |
| | completed | needs_review, in_progress | 시스템(상위 단계 수정 시), 쓰기 역할 | 하위 단계 마킹(제안: 1~3 수정 → 4~7). RPC |
| | needs_review | completed, in_progress | 쓰기 역할 | |
| experiments.status | planned | running | 쓰기 역할 | 기준 잠금 필수 |
| | running | completed | 쓰기 역할 | `result` 필수 |
| scorecards.status | draft | validating | 서버 | 트리거 |
| | validating | scored | 서버(`save_scorecard`) | 총점·blocking 계산 |
| | scored | on_hold, ready, needs_validation, redesign | 서버 | `blocking_hits`가 있으면 점수와 무관하게 on_hold. 없으면 08 4구간: 80+ → ready; 60~79 → needs_validation; 40~59 → redesign; 40 미만 → on_hold(보류·폐기). 경계는 하한 포함(08#7) |
| | ready | approved, on_hold | owner/admin(`decide_scorecard`) | ready는 blocking 없음이 조건. approved는 `blocking_hits` 공백 필수(`BM005`), 감사. RPC. decision enum은 `approved`\|`on_hold`(`04_API.md#2`) |
| | needs_validation, redesign, on_hold | draft | 쓰기 역할 | 재평가(새 scorecard 행) |
| reports.status | queued | rendering, failed | 워커 | |
| | rendering | ready, failed, queued(재시도) | 워커 | |
| ai_suggestions.status | queued | suggested, failed | 워커 | 검증 통과 시만 suggested |
| | suggested | accepted, rejected | 쓰기 역할(`decide_ai_suggestion`) | accepted면 대상 반영 + 감사. RPC |

위반은 트리거·RPC가 `BM003`(제안)으로 거부한다. 80점 이상이어도 blocking 조건이 있으면 `ready`가 되지 않고 `scored → on_hold`로 간다(원본 8장).

## 4. RLS 정책

기본: 전 테이블 RLS ON, `FOR ALL` 금지, 쓰기 정책엔 `with check`. 헬퍼는 코어만(`is_org_member`, `has_org_role`, `has_entitlement`). `bm.version_is_draft(version_id)`는 SECURITY DEFINER 헬퍼(정책 안에서 다른 테이블 직접 조회 금지 규칙 대응).

| 테이블 | SELECT | INSERT/UPDATE | DELETE | GRANT / 잠금 |
|---|---|---|---|---|
| projects | `is_org_member(org_id) and has_entitlement(org_id,'bm') and deleted_at is null` | 쓰기 역할 + `with check` 동일 org | owner/admin | select, insert, update, delete |
| project_versions | 위와 같음(deleted_at 제외) | INSERT·`status` 변경은 RPC만. 직접 UPDATE는 `note`만 | 없음(archived) | select. `guard_privileged_write` |
| wizard_steps | 멤버 | RPC만(`set_wizard_step`) | 없음 | select. guard |
| customer_segments, value_propositions, business_parts, pricing_plans, cost_items, allocation_rules, assumptions, economic_scenarios, hypotheses, experiments(기준 잠금 전), evidence | 멤버 + 엔타이틀먼트 | 쓰기 역할(owner/admin/member) `and bm.version_is_draft(version_id)` + `with check` 동일 | owner/admin + draft | select, insert, update, delete. 트리거 `guard_locked_version`(`BM001`, service_role 포함) |
| calculation_runs, scorecards, score_items, score_evidence | 멤버 + 엔타이틀먼트 | 없음(service_role/RPC) | 없음 | select만. guard + 불변 트리거 |
| rubrics | 인증 사용자(`org_id is null or is_org_member`) | 없음(service_role) | 없음 | select만 |
| reports | 멤버 + 엔타이틀먼트 | 없음(Route Handler service_role) | owner/admin(파일 정리는 서버) | select만. guard |
| ai_suggestions | 멤버 + 엔타이틀먼트 | 상태 변경은 RPC만 | 없음 | select만. guard |
| share_links | owner/admin | 없음(service_role) | 없음 | select만(해시 비노출 뷰 권장, 제안) |

쓰기 정책을 준 테이블(입력 데이터)의 `DB_CONVENTIONS.md` 8장 조건 충족 근거: 돈·권한·한도가 아니라 순수 콘텐츠이고, 계산 결과(금액 지표)·점수·보고서는 쓰기 정책이 없으며, 잠금 트리거가 service_role에도 적용된다. viewer는 읽기만. Storage: `org-files`는 `<org_id>/bm/evidence/...`, PDF는 `exports`에 서버만 쓰고 서명 URL 7일(`CORE_SPEC.md` 10장).

## 5. 인덱스와 성능

| 인덱스 | 용도 |
|---|---|
| `projects_org_cursor_idx (org_id, created_at desc, id) where deleted_at is null` | 목록 cursor |
| `project_versions_project_idx (project_id, version_no desc)` | 버전 목록·비교 |
| 하위 테이블마다 `<tbl>_version_idx (version_id)` | 버전 조회 |
| `calculation_runs_scenario_idx (scenario_id, created_at desc)`, `unique(request_id)` | 최근 결과, 멱등 |
| `evidence_experiment_idx (experiment_id)`, `score_items_scorecard_idx` | 증거·점수 조회 |
| `ai_suggestions_version_status_idx (version_id, status)` | 승인 대기 |
| `share_links_token_uniq (token_hash)`, `reports_version_idx (version_id, created_at desc)` | 열람·목록 |

성능 목표(원본 12장, 제안): API p95 500ms, 단순 계산 p95 200ms, Wizard 저장 p95 1s. 계산은 엔진(코드)에서 하고 DB는 입력 조회와 저장만 한다.

## 6. 코어 참조

| `core.*` 객체 | 용도 | 원본 대응 |
|---|---|---|
| `organizations`, `org_members`, `profiles` | 테넌트·역할 | organizations, organization_members |
| `apps`(id=`bm`), `plans`, `subscriptions`, `app_entitlements` | 요금제 Free/Starter/Pro/Consultant/Enterprise(금액 제안, 정본 `01_PRD.md#4`), 기능 키(`projects_max`, `scenarios`, `economics`, `scorecard`, `pdf_export`, `ai_analysis`는 제안) | subscriptions |
| `wallets`, `credit_ledger`, `credit_balances`, `ai_usage` | AI 크레딧 | credit_ledger |
| `jobs` | `report.render`, `ai.suggest` | jobs |
| `audit_log` + `write_audit` | 감사 | audit_logs |
| `payment_orders`, `payments`, `webhook_events` | Toss 결제(코어 경로) | - |
| `rate_limit_buckets`, `ai_routing_settings`, `ai_providers`, `ai_model_prices` | 레이트 리밋, AI 라우팅·단가 | - |
| 버킷 `org-files`, `exports` | 증거·PDF | - |

`core.*` ALTER 없음. AI 전용 테이블 중 코어에 없는 `ai_suggestions`만 제품 스키마에 둔다(승인 워크플로가 제품 도메인이라서). 인증 단계는 스키마 변경 없음.

## 7. 높음 결함의 차단 설계 (보안, 데이터)

리뷰 문서가 없는 신규 제품이라 해당 없음. 보안·데이터 위험의 차단은 다음과 같다.

| 위험 | 차단 | 근거 |
|---|---|---|
| 조직 간 노출(매우 높음) | org_id 서버 파생 + 복합 FK + RLS + RLS 스모크(`supabase/tests/rls_smoke.sql`: B가 A 행 0행, org_id 바꿔치기 42501) | `DB_CONVENTIONS.md` 13.3 |
| 계산 결과 위조·변조 | `calculation_runs` 사용자 쓰기 없음 + 불변 + 입력 스냅샷·엔진 버전·해시 | 2.12 |
| AI 값이 검증 데이터처럼 평가됨 | `grade` 기본 E, `ai_suggestions` 승인 전 비반영, 출처·측정 방법 NOT NULL | 2.10·2.15·2.21 |
| 통과 기준 사후 조작 | `criteria_locked_at` 이후 임계값 변경 `BM001` | 2.14 |
| 승인 우회 | 점수와 승인 분리, blocking이면 `BM005` | 3절 |

## 8. 모놀리스와 모듈러의 차이

모듈러 기본(SSO·공용 지갑). 모놀리스 변환 시 `DB_CONVENTIONS.md` 12장 규칙을 따른다(`core.`→`public.`, 스키마 제거). 이 제품에서 달라지는 것은 없다.

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `2700_bm.sql` | 스키마·`core.apps` 등록·권한, 공통 트리거 함수(`set_org_from_parent`, `guard_locked_version`, `version_is_draft`), projects, project_versions, wizard_steps |
| `2710_bm_model.sql` | customer_segments~assumptions(2.4~2.10) |
| `2720_bm_economics.sql` | economic_scenarios, calculation_runs |
| `2730_bm_validation.sql` | hypotheses, experiments, evidence, rubrics, scorecards, score_items, score_evidence, 제품 RPC |
| `2740_bm_outputs.sql` | reports, ai_suggestions, share_links, 전 테이블 RLS·GRANT·`revoke execute ... from public` |
| `seed.sql` | `core.apps` 1행(`bm`), 기본 플랜(Free 등, 금액 제안), 루브릭 `v1`(5축×4지표, blocking 규칙), `ai_routing_settings` seed, BookForge 예시 프로젝트(개발용, 운영 seed 제외) |
| `tests/rls_smoke.sql` | `DB_CONVENTIONS.md` 13.3 항목 + 잠금·승인 우회 검사 |

번호는 10단위로 올린다. 마이그레이션 체커(`check.mjs`)는 pgvector가 필요 없으므로 `--vector` 불필요.
