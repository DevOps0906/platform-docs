# 04 API: BM-Core

작성일 2026-11-11. 근거 원본 B장 5·10·12(`research/00_SOURCE_DESIGN.md`). 수치는 모두 제안. 코어 RPC는 `_platform-core/CORE_SPEC.md`를 인용만 한다. 역할 표기: 쓰기 = owner/admin/member, 읽기 = viewer 포함. 원본 `editor`는 `member`.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 접두사 | `/api/v1`(원본 5장). Route Handler, 입력은 Zod |
| 인증 | 진입부 `requireSession('bm')`. 엔타이틀먼트 없으면 403 `forbidden`. 클라이언트가 보낸 `org_id`는 무시하고 대상 행(project·version)에서 파생한다 |
| DB 클라이언트 | 일반 읽기·쓰기는 사용자 세션 클라이언트(RLS 적용). service_role은 계산 결과 저장, 스코어 저장, 크레딧, 잡, 공유 링크에만 쓴다 |
| 멱등 | 부작용 있는 POST는 클라이언트 UUID `requestId`(본문)를 받는다. 서버가 `consume:bm:<requestId>`, `job:bm:<requestId>`를 만든다. 원본의 `idempotencyKey`를 대체한다. 같은 `requestId` 재호출은 기존 결과 반환. `calculation_runs.request_id` 유니크 |
| 낙관적 잠금 | 수정 요청은 `rowVersion`(정수)을 보낸다. 불일치는 409 `version_conflict`(`BM004`) |
| 크레딧 | 선차감은 `ai.suggest`만(`CORE_SPEC.md` 4.3절 순서). PDF·계산은 플랜 한도(`features`) 검사 |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }`(live-poll 관례). 장애를 mock으로 숨기지 않는다 |
| 페이지네이션 | 목록은 `cursor`(불투명, `created_at,id` 키셋)·`limit`(기본 20, 최대 100, 제안). 출력 `{ items, nextCursor }` |
| 레이트 리밋 | `rate_limit_hit('bm:<route>:<org_id>')`. 제안값: 쓰기 120/분, 계산 60/분, AI 제안 10/분·조직, 보고서 5/분. 초과 429 `rate_limited`(크레딧 부족과 구분) |
| 잠긴 버전 | `locked` 버전에 대한 쓰기는 409 `version_locked`(`BM001`) |

## 2. Route Handler

공통 오류(표에서 생략): 400 `bad_request`(구조), 401 `unauthorized`, 403 `forbidden`·`plan_limit`, 404 `not_found`, 429 `rate_limited`. 표의 오류 열은 추가 오류만 적는다. 크레딧·코어 RPC 열의 "-"는 해당 없음.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어/제품 RPC | 추가 오류 |
|---|---|---|---|---|---|---|
| `POST /projects` | 쓰기, 플랜 `projects_max` | `{name, currency?='KRW'}` | project + v1 draft | - | `bm.create_project_version` | `plan_limit` |
| `GET /projects` | 읽기 | `cursor, limit, status?` | `{items, nextCursor}` | - | RLS SELECT | - |
| `GET /projects/:id` | 읽기 | - | project + 버전 목록 + 최신 점수 요약 | - | RLS SELECT | - |
| `PATCH /projects/:id` | 쓰기 | `{name?, status?, rowVersion}` | project | - | RLS UPDATE | `version_conflict` |
| `POST /projects/:id/versions` | 쓰기 | `{fromVersionId?, note?, requestId}` | 새 draft 버전(복제 시 하위 데이터 포함) | - | `bm.create_project_version` | `version_conflict` |
| `GET /versions/:id` | 읽기 | `include?`(parts, scenarios, hypotheses, scorecards) | 버전 + 단계 상태 + 요청 하위 데이터 | - | RLS SELECT | - |
| `PUT /versions/:id/wizard/:step` | 쓰기 | step 1~7별 Zod(고객·가치·가격·경제성·파트·검증·평가) + `{status, rowVersion}` | 저장된 단계 + 단계 상태 | - | `bm.set_wizard_step` | `version_locked`, `step_incomplete`(422), `version_conflict` |
| `POST /versions/:id/validate` | 쓰기 | `{steps?: 1~7[]}` | `{ok, issues:[{step, field, code}]}` | - | 엔진 `validators` + `bm.check_allocation` | `validation_failed` |
| `POST /versions/:id/lock`(제안, 원본 목록에 없음) | owner/admin | `{rowVersion}` | 잠긴 버전 | - | `bm.lock_version` | `invalid_transition` |
| `POST /versions/:id/parts` | 쓰기 | `{name, type, role, costItems?[], allocationRule?}` | part | - | RLS INSERT | `version_locked`, `allocation_invalid`(422) |
| `POST /parts/:id/pricing` | 쓰기 | `{name, amount, billingPeriod, includedUsage?, overageUnitPrice?, effectiveFrom?}` | pricing_plan | - | RLS INSERT | `version_locked`, `validation_failed` |
| `POST /versions/:id/scenarios` | 쓰기, 플랜 `scenarios` | `{name, kind, parameters}` | scenario(`rowVersion`) | - | RLS INSERT | `plan_limit`, `validation_failed` |
| `POST /scenarios/:id/calculate` | 쓰기, 플랜 `economics` | `{scenarioRowVersion, mode:'simple'\|'full', requestId}` | 2절 아래 예 | - | 엔진 → `bm.calculation_runs` INSERT(service_role) | `version_conflict`, `validation_failed`(예 이탈률 음수) |
| `GET /calculations/:id` | 읽기 | - | 저장된 입력 스냅샷·결과·`engineVersion`·`warnings[]`(경고 코드)·`assumptions[]`·공식 id | - | RLS SELECT | - |
| `POST /versions/:id/hypotheses` | 쓰기 | `{statement, priority?}` | hypothesis | - | RLS INSERT | `version_locked` |
| `POST /hypotheses/:id/experiments` | 쓰기 | `{method, metric, sampleSize, passThreshold, failThreshold, durationDays, lockCriteria?}` | experiment | - | RLS INSERT, `bm.lock_experiment_criteria` | `criteria_locked`(409, `BM001`) |
| `POST /experiments/:id/evidence` | 쓰기 | `{grade, sourceType, measurementMethod, sourceNote, measuredAt?, file?\|sourceUrl?}` | evidence(+ 서명 업로드 경로) | - | RLS INSERT, Storage `org-files` | `validation_failed` |
| `POST /versions/:id/scorecards` | 쓰기, 플랜 `scorecard` | `{rubricVersion?, items:[{indicatorKey, score 0~5, rationale, evidenceIds[]}], requestId}` | scorecard(총점·축점수·`blockingHits`·상태·판정 구간: 80+ / 60~79 / 40~59 / 40 미만 보류·폐기, 08#7) | - | 엔진 `scorecard` → `bm.save_scorecard`(service_role) | `validation_failed`, `rubric_not_found` |
| `POST /scorecards/:id/decision` | owner/admin | `{decision:'approved'\|'on_hold', note}` | scorecard | - | `bm.decide_scorecard` | `decision_blocked`(409, `BM005`) |
| `POST /versions/:id/reports` | 쓰기, 플랜 `pdf_export` | `{templateKey?='default', requestId}` | `{reportId, jobId}` 202 | 없음(제안) | `enqueue_job('report.render')` | `plan_limit` |
| `GET /reports/:id` | 읽기 | - | report 상태 + 서명 URL(7일, ready일 때) | - | RLS SELECT, `exports` 서명 | - |
| `GET /jobs/:id` | 읽기 | - | `{status, progress, message, result?}` | - | RLS SELECT `core.jobs` | - |
| `POST /ai/suggestions` | 쓰기, 플랜 `ai_analysis` | `{versionId, agent, targetType, targetId?, requestId}` | `{suggestionId, jobId}` 202 | 선차감 `ai.suggest` | `consume_credits` → `enqueue_job('ai.suggest')` | `credit_insufficient`(402, `CR001`) |
| `POST /ai/suggestions/:id/decision` | 쓰기 | `{decision:'accepted'\|'rejected'}` | suggestion + 반영된 대상 | - | `bm.decide_ai_suggestion` | `suggestion_stale`(409) |
| `POST /versions/:id/share-links`(P1) | owner/admin | `{expiresInDays<=30}` | `{url, expiresAt}`(토큰은 이때만 노출) | - | service_role INSERT(해시 저장) | `version_conflict` |
| `DELETE /share-links/:id`(P1) | owner/admin | - | 204 | - | `revoked_at` 갱신 | - |

`POST /scenarios/:id/calculate` 응답 예(원본 5장 값, `idempotencyKey`는 `requestId`로 대체, `cacCeiling`·`paybackMonths`는 필드 분리로 추가한 제안):

```json
{ "ok": true, "data": { "calculationId": "uuid", "engineVersion": "1.0.0", "currency": "KRW",
  "results": { "arpu": 29000, "variableCost": 8700, "contributionMargin": 20300,
    "contributionMarginRate": 0.7, "ltv": 406000, "cac": 90000, "ltvCacRatio": 4.51,
    "cacCeiling": 135333, "paybackMonths": 4.43, "breakEvenCustomers": 148 },
  "warnings": ["UNVALIDATED_INPUTS"],
  "assumptions": [{ "key": "monthly_churn", "value": 0.05, "grade": "E" }],
  "formulaIds": ["contributionMargin", "ltv", "ltvCacRatio", "cacCeiling", "breakEvenCustomers"] } }
```

`warnings`는 문장이 아니라 08#4의 경고 코드 배열(`LTV_UNBOUNDED`, `ZERO_REVENUE`, `NO_CUSTOMERS`, `NEGATIVE_CONTRIBUTION`, `CAC_MISSING`, `UNVALIDATED_INPUTS`, `ALLOCATION_SUM_MISMATCH`). 경고로 계산 불가인 필드는 `null`(예 이탈률 0 → `ltv: null` + `LTV_UNBOUNDED`). `assumptions[]`는 결과에 쓰인 가정(키·값·증거 등급), `formulaIds[]`는 적용 공식 id로, 08#2 지표의 결과 키를 쓴다(별도 id 체계는 08에 없음, 확정은 08 몫). `GET /calculations/:id`도 같은 필드를 저장본에서 반환한다.

`cac`(90,000)는 입력한 실제 CAC 가정이고 `cacCeiling`(목표 LTV/CAC 3배의 허용 상한)은 별도 필드다. 원본의 "135,000"은 근사 표기이며 엔진 값은 135,333(08#7).

## 3. RPC (SECURITY DEFINER)

모두 `set search_path = ''`, `core.is_service_caller()` 판정, 감사 `write_audit`, `revoke execute ... from public, anon`(`DB_CONVENTIONS.md` 8.3). 코어 RPC(`consume_credits`, `enqueue_job` 등)는 `CORE_SPEC.md`를 인용만 한다.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `bm.create_project_version(p_project_id uuid default null, p_name text default null, p_from_version uuid default null, p_expected_row_version int default null)` | authenticated | 쓰기 역할, 엔타이틀먼트, `projects_max`(project 신규 시) | `bm.project_versions` | `42501`, `BM004` |
| `bm.set_wizard_step(p_version_id uuid, p_step smallint, p_status text, p_expected_row_version int)` | authenticated | 쓰기 역할, 버전 draft, 완료 조건(원본 3장 표: 고객군 1개 이상 등), 상위 단계 수정 시 하위 `needs_review` | `bm.wizard_steps` | `42501`, `BM001`, `BM003`, `BM004` |
| `bm.check_allocation(p_version_id uuid)` | authenticated | 읽기 역할. 배분 구성의 가중치 합>0, 가중치 대상 파트 존재, 규칙 미지정 비용 항목 없음 | jsonb `{ok, issues[]}` | `42501`, `BM002`(트리거 경로) |
| `bm.lock_experiment_criteria(p_experiment_id uuid)` | authenticated | 쓰기 역할, 임계값·표본·기간 입력 완료. 이후 임계값 변경 금지 | `bm.experiments` | `42501`, `BM001`, `BM003` |
| `bm.save_scorecard(p_version_id uuid, p_rubric_version text, p_items jsonb, p_total smallint, p_axis jsonb, p_blocking jsonb, p_request_id uuid)` | service_role | 루브릭 존재, 항목 20개·0~5, 증거 id가 같은 버전 소속 | `bm.scorecards` | `BM002`, `22023` |
| `bm.decide_scorecard(p_scorecard_id uuid, p_decision text, p_note text)` | authenticated | owner/admin, 상태 `ready`에서만 approved·on_hold(`05_DATA_MODEL.md#3`). `blocking_hits`가 비어 있지 않으면 approved 거부(점수와 무관) | `bm.scorecards` | `42501`, `BM003`, `BM005` |
| `bm.decide_ai_suggestion(p_suggestion_id uuid, p_decision text)` | authenticated | 쓰기 역할, 상태 suggested, 대상 행이 제안 이후 바뀌지 않음, accepted면 `target_type` 허용 목록(제안: 고객 문제, 가치 제안, 가정, 실험 기준)만 반영. 반영 세부 분기는 구현 작업에서 정한다 | `bm.ai_suggestions` | `42501`, `BM003`, `BM004` |
| `bm.lock_version(p_version_id uuid)` | authenticated | owner/admin, 모든 P0 단계 completed. `locked_at` 기록, 이후 하위 쓰기 `BM001` | `bm.project_versions` | `42501`, `BM003` |

트리거(함수 아님): `bm.guard_locked_version()`이 하위 테이블 쓰기를 `BM001`로 거부(service_role 포함), `bm.set_org_from_parent()`가 `org_id`를 부모 행에서 채움, `guard_privileged_write`는 계산·점수·보고서·AI 제안 테이블(`05_DATA_MODEL.md#4`).

## 4. 잡 페이로드 계약

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `report.render` | `{reportId, versionId, templateKey, locale:'ko', calculationIds:[uuid], scorecardId}` (비밀값 없음) | `{storagePath, pages, snapshotHash}` | `{step:'collect'\|'render'\|'upload', pct}` |
| `ai.suggest` | `{suggestionId, versionId, agent, targetType, targetId?, promptVersion, inputRefs:[{type,id}]}` | `{suggestionId, status:'suggested', tokens:{in,out}, model}` | `{step:'collect'\|'model'\|'validate', attempt}` |

규칙: 입력은 id 참조만(워커가 DB에서 최소 정보를 읽는다). `ai.suggest` 결과 payload는 JSON 스키마 검증 통과 후에만 `ai_suggestions.payload`에 저장한다. 재시도 소진 시 `ai_suggestions.status='failed'`, 크레딧 자동 환불. `report.render`는 저장된 `calculation_runs`·`scorecards`만 읽는다(재계산 금지: 보고서 = 저장 데이터).

## 5. 웹훅

| 구분 | 내용 |
|---|---|
| 수신 | BM 전용 웹훅 없음. 결제 웹훅은 코어 toss 경로(`CORE_SPEC.md` 5·6장) |
| 발신 | 없음(P2 이후 B2B API가 생기면 추가, 범위 밖) |
| Make·n8n | 알림·CRM·사전예약 수집만(원본 10장). 앱이 단방향 발신하며 수신 경로 없음 |

## 6. 외부 API 어댑터

| 대상 | 호출 위치 | 실패 처리 |
|---|---|---|
| LLM(OpenAI·Claude) | ai-gateway → `ai.suggest` 워커 | 제한 재시도 → 실패 기록 + 환불 + 사용자에게 실패·환불 표시 |
| 렌더 서비스 | `report.render` 워커 | 재시도 3회 → `reports.status='failed'` |
| Toss | 코어 경로 | `CORE_SPEC.md` 5장 |
| 국내 PG 외 | 없음 | - |

쿼터: LLM 제공자 한도 `미확인`. 사용자·조직 한도는 1장 레이트 리밋과 월 예산 상한(`02_ARCHITECTURE.md#8`).

## 7. 오류 코드

제품 SQLSTATE는 접두사 `BM`(`DB_CONVENTIONS.md` 1장 규약, 모두 제안). 코어 코드 매핑은 `CORE_SPEC.md` 15장.

| 코드 | 의미 | HTTP | error.code |
|---|---|---|---|
| `BM001` | 잠긴 버전·잠긴 실험 기준에 쓰기 | 409 | `version_locked` / `criteria_locked` |
| `BM002` | 배분 구성·루브릭·점수 입력 오류 | 422 | `allocation_invalid` / `validation_failed` |
| `BM003` | 허용되지 않은 상태 전이, 단계 완료 조건 미충족 | 409(조건 미충족 422 `step_incomplete`) | `invalid_transition` |
| `BM004` | `rowVersion` 불일치(낙관적 잠금) | 409 | `version_conflict` |
| `BM005` | blocking 조건이 있는데 승인 시도 | 409 | `decision_blocked` |
| `CR001` | 크레딧 부족(AI) | 402 | `credit_insufficient` |
| `42501` | 같은 조직 안의 권한·엔타이틀먼트 부족 | 403 | `forbidden` |
| `P0002` | 대상 없음 | 404 | `not_found` |
| `22023` | 인자 오류(엔진 검증: 이탈률 음수 등) | 422 | `validation_failed` |
| (앱) | 한도 초과·플랜 미포함 | 403 | `plan_limit` |
| (앱) | 레이트 리밋 | 429 | `rate_limited` |
| (앱) | 예기치 못한 오류 | 500 | `internal` |

원본의 "429 = AI 크레딧 소진"은 플랫폼 관례(`CR001` → 402)에 맞춰 402로 바꿨고, 429는 레이트 리밋 전용이다. 조직 간 접근은 RLS상 0행이므로 403이 아니라 404로 응답한다(존재 비노출, 제안).
