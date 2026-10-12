# 04 API: Stock Dashboard

작성일 2026-10-12. 경로는 `apps/stock-dashboard/src/app/api/`(제안) 기준이다. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다. 제품 RPC 정본은 `docs/products/_supabase-modular/migrations/1900_stock.sql`(모놀리스는 `public.` 접두사, `05_DATA_MODEL.md` 8장).

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 Route Handler는 `requireSession('stock')`(`SHARED_MODULES.md:68`). 추가로 `beta_access` 활성과 최신 고지 동의를 확인한다(없으면 403 `ST_BETA` / 428 `ST_CONSENT`) |
| 읽기 | 사용자 세션 클라이언트 + RLS(`has_stock_access`). 서버가 org_id 필터를 따로 믿지 않는다 |
| 쓰기 | 제품 RPC(사용자용 5개) 또는 service_role(`createAdminClient`). service_role 사용 지점은 아래 표의 "service" 표시 행뿐 |
| 멱등 | 클라이언트가 요청마다 UUID `request_id`를 보낸다. 크레딧 `consume:stock:<request_id>`, 잡 `job:stock:<request_id>`, 주문은 `client_order_id` |
| 크레딧 | AI 라우트만 선차감(`CORE_SPEC.md:172-183`) |
| 응답 봉투 | 성공 `{ data, request_id }`, 실패 `{ error: { code, message, retry_after? }, request_id }`. 스트리밍은 NDJSON(`{"type":"delta"}`, `{"type":"done"}`, `{"type":"error"}`) |
| 레이트 리밋 | `rate_limit_hit('stock:<route>:<org_id 또는 ip_hash>', ...)`, 값은 01_PRD 5장 |
| 비밀 | 응답과 로그에 키, 토큰, 계좌번호 원문을 넣지 않는다. 입력받은 계좌번호는 마스킹·HMAC 직후 버린다 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 코어/제품 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/session` | 로그인 | - | `SessionContext` + `beta`, `consents` | 0 | `session_context('stock')` | 401 |
| `POST /api/beta/invites` | platform_admin(service) | `{ email, note? }` | `{ id, invite_url }`(토큰 원문은 이 응답에서 1회만) | 0 | service INSERT `beta_invites`, `audit_log` | 403, 409(같은 이메일 미사용 초대 존재) |
| `DELETE /api/beta/invites/{id}` | platform_admin(service) | - | `{ status: 'revoked' }` | 0 | service UPDATE(issued→revoked) | 404, 409(22023) |
| `POST /api/beta/redeem` | 로그인(service) | `{ token }`(32바이트 base64url) | `{ org_id, plan: 'beta' }` | 0 | `stock.redeem_beta_invite(sha256(token), user)` → 3장 시퀀스 | 400 `ST030`, 403 `ST031`, 410(만료, null 반환) |
| `POST /api/admin/beta/{orgId}/revoke` | platform_admin(service) | `{ reason }` | `beta_access` | 0 | `stock.revoke_beta_access` | 403 |
| `POST /api/consents` | 베타 | `{ kind, version }` | `consents` 행 | 0 | `stock.record_consent`(사용자 세션) | 403, 409(버전 불일치) |
| `GET /api/connections` | 베타 | - | 연결 목록(`broker_connections` + `credential_summaries`) | 0 | RLS SELECT | - |
| `POST /api/connections` | 베타 owner/admin(service) | `{ request_id, broker, env, label?, app_key, app_secret, account_no, agree_own_account: true, agree_broker_terms: true }` | 연결(마스킹) | 0 | 어댑터 `verify` → vault `put`(`encrypted_credentials`, provider `broker:<broker>:<env>`) → INSERT `broker_connections` → `enqueue_job(stock.sync)` → audit `stock.connection.create` | 409 상한(`broker_connections_max`), 403 live 비허용, 422 키 오류, 429 |
| `DELETE /api/connections/{id}` | 베타 owner/admin | - | `{ status: 'revoked' }` | 0 | `revoke_credential`(사용자) → service UPDATE status revoked → audit | 403, 404 |
| `POST /api/connections/{id}/sync` | 베타 | `{ request_id }` | `{ job_id }` | 0 | `enqueue_job` | 429(60초), 409(연결 error/revoked) |
| `GET /api/stream-token` | 베타 | `?connections=...&symbols=...` | `{ token, expires_at, url }` | 0 | RLS로 연결 소유 확인 후 HMAC 서명 | 403, 429 |
| `GET /api/instruments/{symbol}` | 베타 | - | 종목 + 재무지표(출처·기준일) | 0 | RLS SELECT | 404 |
| `GET /api/trades/export` | 베타 | `?from&to&symbol?` | CSV 스트림(UTF-8 BOM) | 0 | RLS SELECT, audit `stock.trades.export` | 413(1만 행 초과) |
| `POST /api/ai/diagnoses` | 베타 | `{ request_id, scope_connection_id?, mode: 'quality' }` | NDJSON 스트림 | 10 | `consume_credits` → service INSERT/UPDATE `ai_reports` → llm gateway → 실패 시 `refund_credits` | 402 `CR001`, 428 동의, 429 일 상한, 409 데이터 없음 |
| `GET /api/ai/diagnoses/{id}` | 베타 | - | 리포트 + 항목 | 0 | RLS SELECT | 404 |
| `GET /api/me/export` | 베타 owner | - | JSON(연결 메타, 스냅샷, 체결, 메모, 리포트) | 0 | RLS SELECT, audit | 429(일 1회) |
| `POST /api/ai/ideas` (P2) | `ideas` | `{ request_id, horizon: 5\|20\|60 }` | NDJSON | 10 | 위와 같음, kind `idea` | 403 플랜 |
| `POST /api/ai/compare` (P2) | `ai_compare` | `{ request_id }` | NDJSON(모델별 채널) | 25 | 모델별 실패분 `refund_credits(p_amount)` | 403 |
| `GET /api/leaderboard` (P2) | `leaderboard` | `?horizon` | 모델별 집계(n<20 순위 null) | 0 | RLS SELECT `idea_evaluations` | 403 |
| `POST /api/billing/orders` (P2) | owner(service) | `{ plan_code: 'pro' }` | `PaymentOrder` | 0 | `payment_orders` INSERT(금액은 plans에서) | 409 비활성 플랜 |
| `POST /api/billing/confirm` (P2) | owner(service) | `{ orderId, paymentKey, amount }` | 결제 결과 | 0 | Toss confirm → `confirm_payment_order` | 409 `PM001/PM409/PM410`, 404 `PM404` |
| `POST /api/webhooks/toss` (P2) | 공개(서명) | raw body | 200 | 0 | `webhook_events` | 401 서명 |
| `POST /api/orders/preview` (P3) | `paper_orders` + `ORDERS_ENABLED`(service) | `{ client_order_id, connection_id, symbol, side, quantity, limit_price }` | 주문(pending_confirm 또는 blocked) | 0 | 어댑터 현재가 조회 → 비중 검사(서버) → `stock.create_paper_order` | 409 `ST010`, 428 `paper_order_risk` 동의 |
| `POST /api/orders/{id}/confirm` (P3) | 생성자 본인 | `{}` | 주문 | 0 | `stock.confirm_paper_order`(사용자 세션) → confirmed면 `enqueue_job(stock.order_submit)` | 403, 409 `ST020`, 409 expired/blocked(상태로 반환) |
| `POST /api/kill-switch` (P3) | 베타 멤버 | `{ connection_id?, reason }` | 스위치 | 0 | `stock.engage_kill_switch` | 403 |
| `DELETE /api/kill-switch/{id}` (P3) | owner/admin | - | 스위치 | 0 | `stock.release_kill_switch` | 403 |
| `PUT /api/order-limits` (P3) | owner/admin | 한도 6개 | 한도 | 0 | `stock.set_order_limits` | 422(23514 상한 초과) |
| `POST /api/admin/kill-switch/global` | platform_admin(service) | `{ active, reason }` | 스위치 | 0 | service INSERT/UPDATE `kill_switches`(scope global, source ops) | 403 |

quote-relay 워커(별도 호스트):

| 메서드 경로 | 인증 | 출력 |
|---|---|---|
| `GET /stream/quotes?token=` | 60초 HMAC 토큰(1회용) | SSE 이벤트 `tick {symbol, price, change_pct, volume, ts}`, `status {state: ok\|delayed\|stale\|closed, lag_ms}`, `ping`(15초) |
| `GET /healthz` | 없음 | `{ ok, ws_connections, sse_clients }`(개수만) |

## 3. RPC (SECURITY DEFINER)

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `stock.has_stock_access(org uuid) returns boolean` | authenticated(정책 안), service | 멤버 + 엔타이틀먼트 + 베타 활성 | boolean | - |
| `stock.record_consent(p_org_id, p_kind, p_version)` | authenticated | `auth.uid()` 필수, `is_service_caller()` 또는 `has_stock_access` | `consents` 행(재동의는 기존 행) | 42501, 23514 |
| `stock.set_order_limits(p_org_id, p_max_order_krw, p_max_daily_krw, p_max_orders_per_day, p_max_position_weight_pct, p_max_price_deviation_pct)` | authenticated | `is_service_caller()` 또는 (`has_stock_access` 그리고 `has_org_role(owner, admin)`), 범위는 CHECK | `order_limits` | 42501, 23514 |
| `stock.engage_kill_switch(p_org_id, p_connection_id default null, p_reason)` | authenticated | 베타 멤버 누구나, 연결 소속 확인 | `kill_switches`(이미 활성이면 기존 행). 대기·확인 주문을 blocked로 | 42501, 22023 |
| `stock.release_kill_switch(p_switch_id)` | authenticated | 전역·자동은 service만, 수동은 owner/admin | `kill_switches` | 42501, P0002 |
| `stock.confirm_paper_order(p_order_id)` | authenticated | 생성자 본인 + 베타, 상태 pending_confirm | 주문(confirmed / expired / blocked) | 42501, P0002, ST020 |
| `stock.redeem_beta_invite(p_token_hash, p_user_id)` | service_role | 상태 issued, 만료(만료면 expired 기록 후 null), 이메일 일치, 개인 조직 | `beta_access` 또는 null | 42501, ST030, ST031, P0002 |
| `stock.revoke_beta_access(p_org_id, p_reason)` | service_role | - | `beta_access` | 42501 |
| `stock.create_paper_order(p_org_id, p_connection_id, p_client_order_id, p_symbol, p_side, p_quantity, p_limit_price, p_ref_price, p_ref_price_at, p_actor_id, p_prefill_report_id)` | service_role | 사람 actor 필수, 멱등 잠금, 연결 paper·orders_enabled·active, 한도·킬 스위치·시세 나이 | 주문(pending_confirm 또는 blocked) | 42501, 22023, ST010 |
| `stock.apply_order_update(p_order_id, p_to, ...)` | service_role | 전이 트리거, submitted 직전 킬 스위치 재확인 | 주문 | 42501, P0002, 22023 |
| `stock.expire_pending_orders()` | service_role | - | 만료 건수 | 42501 |
| `stock.is_trading_blocked(p_org_id, p_connection_id)` | service_role(및 내부) | - | boolean | - |

규칙 1, 2 준수: 사용자용 5개(`record_consent`, `set_order_limits`, `engage_kill_switch`, `release_kill_switch`, `confirm_paper_order`)는 `core.is_service_caller()`로 호출자를 판정하고 역할은 `has_org_role`(NULL 없음)로 비교한다. service 전용 함수만 `is_privileged_session()`을 쓰고 EXECUTE는 service_role에만 있다(`SECURITY_BASELINE.md:13-25`). 모든 함수는 `set search_path = ''`.

초대 수락 서버 시퀀스(코어 쓰기는 service_role, 코어 RPC 요청은 06장 6절):

| 단계 | 호출 | 비고 |
|---|---|---|
| 1 | `stock.redeem_beta_invite(sha256(token), user_id)` | 제품 테이블만 변경 + audit |
| 2 | service UPDATE `subscriptions set plan_id = <beta>` (org, app stock) | 코어 문서의 "manual entitlement" 서버 경로(`CORE_SPEC.md:328`) |
| 3 | service UPDATE `app_entitlements set plan_id = <beta>, source = 'manual', granted_by = <invited_by>` | 같은 트랜잭션 함수가 없으므로 2~4는 순서대로 하고 실패 시 재시도(멱등) |
| 4 | `grant_credits(org, 300, 'stock', 'monthly_plan_credits', 'plan', 'subscription', sub_id, 'monthly:<sub_id>:<period_start YYYY-MM-DD>', ...)` | 월 지급 멱등 키와 같은 형식이라 이중 지급 없음 |
| 5 | audit `stock.beta.plan_switch` | - |

## 4. 잡 페이로드 계약

| `job_type` | payload | result | progress 메시지 |
|---|---|---|---|
| `stock.sync` | `{ connection_id: uuid, parts: ('balance'\|'holdings'\|'executions')[], executions_from?: string(date) }` | `{ snapshot_id?: number, holdings: number, trades_upserted: number, lag_ms: number }` | `"잔고 조회"`, `"보유 종목 반영"`, `"체결 내역 반영"` |
| `stock.fundamentals_refresh` | `{ symbols?: string[], source: 'dart' }` | `{ updated: number, missing: string[] }` | `"n/m 종목"` |
| `stock.calendar_load` | `{ year: number, source: 'krx_notice' \| 'manual', days?: { date, is_open, open_at?, close_at?, note? }[] }` | `{ days: number }` | - |
| `stock.daily_prices` | `{ trade_date: string, symbols: string[] }` | `{ inserted: number }` | - |
| `stock.idea_eval` (P2) | `{ as_of: string, rule_version: 'idea-eval-v1' }` | `{ evaluated: number, pending: number }` | - |
| `stock.order_submit` (P3) | `{ order_id: uuid }` | `{ broker_order_id?: string, status: string }` | - |

규칙: 비밀값을 payload에 넣지 않는다. 워커는 `broker_connections.credential_id`로 vault에서 복호화한다(`CORE_SPEC.md:306`). `stock.sync`의 org_id는 `core.jobs.org_id`와 연결의 org_id가 같아야 하며 다르면 재시도 없는 실패.

## 5. 웹훅

| 방향 | 제공자 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신(P2) | Toss | Toss 문서 기준(미확인, `SHARED_MODULES.md:174`) | `paymentKey + status + 발생시각` 해시(`CORE_SPEC.md:249`) | 상태 동기화만, 지급은 confirm 경로 |
| 수신 | 증권사 | 없음(증권사 푸시를 쓰지 않고 폴링·WebSocket만) | - | - |
| 발신 | 없음 | - | - | - |

PM001 처리: `confirm_payment_order`는 금액 불일치(`PM001`) 때 raise하며 같은 호출의 UPDATE는 롤백된다(계약 불변). 서버는 `PM001`을 받으면 (1) 별도 호출로 `fail_payment_order(order_id, 'amount_mismatch', {...})`(service_role, 2026-10-13 코어 반영)를 불러 주문을 `failed`로 기록, (2) Toss 결제 취소 API 호출, (3) `audit_log`에 service INSERT `payment.amount_mismatch`(order_id, 기대·실제 금액), (4) 운영 알림을 보낸다. 남은 created 주문은 만료 함수(`expire_stale_payment_orders`)가 처리한다. 제품 SQL은 같은 롤백 함정을 피하려고 차단·만료를 예외가 아닌 상태 기록으로 처리한다(05장 3절).

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| 증권사 REST(토큰, 잔고, 보유, 체결, 현재가, 주문 P3) | `src/lib/broker/<broker>/`(Route Handler `verify`, 워커) | 토큰 만료 → 1회 재발급 → 실패 시 `encrypted_credentials.status='error'`, 연결 `error`. 5xx·타임아웃(10초) → 잡 재시도. 연속 오류 5회 → 연결 error + 알림 | 미확인(spike 산출). 어댑터가 초당 호출 상한을 설정값으로 갖는다 |
| 증권사 WebSocket(시세) | `workers/quote-relay/` | 백오프 재연결, 지연 상태 이벤트 | 연결당 구독 종목 수 상한 미확인 → 토큰당 40종목(제안) |
| DART 오픈API | `workers/stock-jobs/src/reference/` | 실패 종목은 이전 값 유지, `missing` 기록 | 일 호출 한도 미확인 |
| LLM(OpenRouter/Anthropic) | llm gateway | 폴백 1회 → 환불 | 조직당 분 3회 + 일 상한 |
| Toss(P2) | core-billing | `SHARED_MODULES.md` 5장 | - |
| KRX 휴장일 공지 | 수동 적재(`stock.calendar_load`, source manual) | - | - |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| `ST000` | append-only 테이블(order_events, consents) 변경 시도 | 500(버그) |
| `ST010` | 연결이 모의주문 조건(paper, orders_enabled, active) 불충족 | 409 |
| `ST020` | 확인할 수 없는 주문 상태 | 409 |
| `ST030` | 초대 없음/사용됨/회수됨 | 400 |
| `ST031` | 초대 이메일 불일치 | 403 |
| `22023` | 상태 전이 위반(트리거) | 409 |
| `23514` | CHECK 위반(마스킹 안 된 계좌, 가격 키가 든 AI 출력, live 주문, 한도 상한 초과) | 422 |
| `23503` | 다른 조직 행 참조(복합 FK) | 403 |
| `ST_BETA`(앱) | 베타 접근 없음 | 403 |
| `ST_CONSENT`(앱) | 최신 고지·동의 없음 | 428 |
| `ST_LIMIT`(앱) | 일 진단 상한 | 429 |
| 코어 | `42501` → 403, `CR001` → 402, `P0002` → 404, `PM001/PM409` → 409 + 알림(`CORE_SPEC.md:418`) | - |

주문의 한도 위반, 킬 스위치, 시세 지연, 확인 만료는 오류 코드가 아니라 200 응답의 `status`(`blocked`/`expired`)와 `block_reason`으로 돌려준다.
