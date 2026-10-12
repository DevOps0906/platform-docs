# 04 API: Study Note

작성일 2026-10-12. TypeScript 블록은 계약 예시다. 구현 파일이 아니다.

## 1. 원칙

| 항목 | 내용 |
|---|---|
| 인증 | 모든 `/api/notes/*`는 `requireSession('notes')`로 시작한다(`SHARED_MODULES.md` 2장). 미로그인 401, `pending`/`suspended` 403, `entitled=false` 402. 정리 실행 계열은 추가로 이메일 인증 필수(미인증 403 `email_not_verified`) |
| 멱등 | 클라이언트가 실행마다 UUID `request_id`를 보낸다. 서버는 `consume:notes:<request_id>`, `job:notes:<request_id>`로 쓴다(`DB_CONVENTIONS.md:215`). 같은 `request_id`는 같은 실행을 돌려준다 |
| 크레딧 선차감 위치 | Route Handler가 아니라 DB 함수 `notes.start_run` 안(service_role 호출). 차감, 실행 생성, 잡 생성이 한 트랜잭션 |
| 응답 봉투 | 성공 `{ "ok": true, "data": ... }`, 실패 `{ "ok": false, "error": { "code": "...", "message": "한국어 문장", "retryable": bool } }` |
| 레이트 리밋 | `core.rate_limit_hit('notes:<route>:<org_id>', limit, window)`. 초과는 429 + `Retry-After` |
| 서비스 키 | `createAdminClient`는 서버 파일에서만 import. 브라우저에서 `OPENROUTER_API_KEY`나 service_role에 닿는 경로가 없다 |
| 직접 조회 | 목록/상세/설정 읽기와 일지 입력 저장은 브라우저가 Supabase로 직접 한다(RLS가 정본). Route Handler는 과금, 상태 전이, 외부 호출, 감사가 필요한 것만 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/notes/runs` | owner/admin/member, 엔타이틀먼트 | `request_id: uuid`, `entry: { id?: uuid, entry_date: 'YYYY-MM-DD', input_text: 1..20000 }`, `models?: { base1, base2, merge }`(없으면 사용자 설정, 그것도 없으면 프리셋) | `{ run, steps[], estimated_credits }` | 선차감(등급 합) | 일지 upsert(사용자 세션, RLS) → `notes.start_run`(service) | 400 입력, 402 `CR001`, 403, 409 `NT002`, 422 `NT004`, 429 한도/`NT006`, 503 `NT005` |
| POST `/api/notes/runs/{id}/retry` | 같음 | `request_id`, `roles: ['base1'\|'base2'][]` | `{ run, steps[] }` | 실행 대상 단계 + 통합 | `notes.start_run(parent, retry_roles)` | 404, 409, 422 `22023`(재사용할 결과 없음) |
| POST `/api/notes/runs/{id}/cancel` | 같음 | 없음 | `{ run }` | queued는 전액 환불, running은 미실행분 환불 | `notes.request_run_cancel`(사용자 세션) | 404, 409 `NT003` |
| GET `/api/notes/runs/{id}` | 같음 | | `{ run, steps[] }` (Realtime 불가 시 폴링용, 2초 간격) | | RLS 조회 | 404 |
| GET `/api/notes/models` | 로그인 | | `{ models[], allowed_tiers, defaults }` | | `model_catalog` + `org_features` | |
| PUT `/api/notes/settings` | 로그인 | `base_model_1`, `base_model_2`, `merge_model`, `theme` | `{ settings }` | | `user_settings` upsert(RLS) | 422 등급/비활성 모델 |
| POST `/api/notes/consent` | 로그인 | `kind: 'llm'`, `version: string` | `{ ok }` | | `write_audit('notes_consent.llm')` | |
| POST `/api/notes/export` | 로그인 | 없음 | JSON 파일(전체 일지 + 카드) | | `write_audit('notes_export')` | 429(하루 3회, 제안) |
| POST `/api/notes/account/delete` | owner | `confirm: 'DELETE'` | `{ scheduled_for }` | | 조직 soft delete(service_role, 코어 요청 C-3) + 감사 | |
| POST `/api/billing/orders`, `/api/billing/confirm` (Phase 2) | owner | `core-billing` 계약(`SHARED_MODULES.md` 5장) | | | `payment_orders` INSERT, `confirm_payment_order` | 409 `PM001`: 지급 없음 + 운영 알림 |
| POST `/api/webhooks/toss` (Phase 2) | 서명 | 코어 webhooks | 200 | | `webhook_events` | 401 서명 실패 |

실행 요청 처리 순서(`POST /api/notes/runs`):

| 순서 | 동작 |
|---|---|
| 1 | 세션, 이메일 인증, zod 검증 |
| 2 | `rate_limit_hit('notes:run:<org>', 6, 60)` |
| 3 | 사용자 세션으로 일지 insert/update(RLS, 컬럼 GRANT) |
| 4 | service_role로 `notes.start_run(...)` 호출(모델 미지정 시 `user_settings` → 프리셋) |
| 5 | SQLSTATE를 7장 표대로 HTTP로 매핑 |

## 3. RPC (SECURITY DEFINER)

정본은 `docs/products/_supabase-modular/migrations/2100_notes.sql`. 모놀리스는 `public.` 접두사.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `notes.start_run(p_org_id, p_user_id, p_entry_id, p_request_id, p_base_model_1, p_base_model_2, p_merge_model, p_parent_run_id default null, p_retry_roles default null)` | service_role | 활성 멤버(owner/admin/member, NULL-safe), 엔타이틀먼트, 일지 소유, 활성 실행 없음, 입력 길이, 모델 활성/등급, 조직 동시 실행, 일일 예산, 크레딧(`CR001`) | `notes.runs` | `42501`, `P0002`, `22023`, `NT002`, `NT004`, `NT005`, `NT006`, `CR001` |
| `notes.record_step(p_run_id, p_role, p_status, p_content, p_latency_ms, p_prompt_tokens, p_completion_tokens, p_ai_usage_id, p_error_code, p_error_message, p_model_id)` | service_role | 실행이 queued/running, 단계 전이 pending→running→succeeded/failed 등 | `notes.run_steps` | `42501`, `P0002`, `22023`, `NT003` |
| `notes.finish_run(p_run_id, p_final_text, p_keywords)` | service_role | 실행이 종료 전. 상태 계산(succeeded/partial/failed/canceled), 미성공 단계 환불, 일지 갱신, 보존 정책 실행 | `notes.runs` | `42501`, `P0002`, `22023`, `NT003` |
| `notes.request_run_cancel(p_run_id)` | authenticated | `is_service_caller()` 또는 owner/admin/member(NULL-safe `has_org_role`). queued는 `core.cancel_job` 호출 | `notes.runs` | `42501`, `P0002`, `NT003` |
| `notes.enforce_retention(p_org_id)` | service_role | `features.history_max_entries/bytes` 초과분 soft delete | 삭제 건수 | `42501` |
| `notes.purge_deleted(p_grace default '30 days')` | service_role(스케줄) | 유예 지난 휴지통 영구 삭제, 오래된 `cost_guard` 정리 | 삭제 건수 | `42501` |
| `notes.org_features(p_org_id)` | service_role(내부) | | jsonb | |

코어 RPC는 `CORE_SPEC.md`를 인용만 한다: `consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `write_audit`, `rate_limit_hit`.

## 4. 잡 페이로드 계약

`job_type = 'notes.organize'`, 큐 `notes.organize`. 원문과 비밀값은 payload에 넣지 않는다.

```json
{
  "payload": { "run_id": "uuid", "entry_id": "uuid", "exec_roles": ["base1", "base2", "merge"] },
  "progress": [
    { "pct": 0,   "message": "queued" },
    { "pct": 10,  "message": "base_running" },
    { "pct": 60,  "message": "base_done" },
    { "pct": 70,  "message": "merge_running" },
    { "pct": 100, "message": "done" }
  ],
  "result": { "status": "succeeded|partial|failed|canceled", "credits_refunded": 0 }
}
```

`exec_roles`는 재요청이면 `["base2","merge"]`처럼 실행 대상만 담는다. 재사용 단계는 이미 `run_steps`에 `reused`로 있다.

## 5. 웹훅

| 구분 | 내용 |
|---|---|
| 수신 | Toss(Phase 2): 코어 webhooks 모듈의 서명 검증과 `(provider, event_id)` 멱등. 지급은 confirm 경로가 정본이고 웹훅은 상태 동기화만 |
| 발신 | 없음 |

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 |
|---|---|---|
| OpenRouter Chat Completions | 워커, 코어 LLM 게이트웨이 경유 | 5절/02장 5절 매핑. 폴백 1회, 단계 단위 실패 → 환불 |
| OpenRouter 모델 목록(동기화, Phase 2) | 워커 크론 `notes.models.sync` | 엔드포인트와 응답 형식은 미확인(구현 시 문서 확인). 목록에 없는 모델만 `is_active=false`. 신규 모델 자동 추가는 하지 않는다(등급/단가는 사람이 정함) |
| Toss Payments (Phase 2) | 코어 toss 모듈 | `SHARED_MODULES.md` 5장 |

쿼터: 공급사별 레이트 리밋은 OpenRouter 키 단위로 공유되므로 워커 동시성(기본 4잡)으로 제어한다.

## 7. 오류 코드

| SQLSTATE | 의미 | HTTP | 사용자 문구 |
|---|---|---|---|
| `NT001` | 상태 전이 위반(정리 중 원문 수정 포함) | 409 | 정리 중에는 원문을 바꿀 수 없습니다 |
| `NT002` | 일지에 이미 활성 실행 | 409 | 이 일지는 정리 중입니다 |
| `NT003` | 종료된 실행/단계에 쓰기 | 409 | 이미 끝난 정리입니다 |
| `NT004` | 플랜 한도 초과(입력 길이, 모델 등급) | 422 | 선택한 모델/길이는 현재 플랜에서 사용할 수 없습니다 |
| `NT005` | 일일 전체 예산 소진 | 503 + `Retry-After` | 오늘 사용량이 가득 찼습니다 |
| `NT006` | 조직 동시 실행 한도 | 429 | 동시에 정리할 수 있는 개수를 넘었습니다 |
| `CR001` | 크레딧 부족 | 402 | 크레딧이 N 부족합니다 |
| `42501` | 권한 없음 | 403 | |
| `P0002` | 대상 없음 | 404 | |
| `22023` | 인자 오류(비활성 모델 등) | 422 | |
| `PM001`/`PM409` | 결제 금액 불일치(Phase 2) | 409 + 운영 알림 | 결제를 확인하지 못했습니다 |
| 단계 error_code | `rate_limited`, `model_unavailable`, `provider_error`, `network`, `empty_response`, `bad_format`, `timeout`, `aborted` | 단계 상태로 전달 | 02장 5절, 03장 5절 |
