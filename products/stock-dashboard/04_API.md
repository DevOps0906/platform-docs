# 04 API: Stock Dashboard

작성일 2026-10-12. 경로는 `apps/stock-dashboard/src/app/api/`(제안) 기준이다. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다. 제품 RPC 정본은 `docs/products/_supabase-modular/migrations/1900_stock.sql`(모놀리스는 `public.` 접두사, `05_DATA_MODEL.md` 8장).

2026-10-13 개정: `/api/ai/*`, `/api/voice/*`(2.1절), FastAPI 엔드포인트와 Dify 계약(6.1, 6.2절), AI 오류 코드(7절)를 추가했다. 브라우저는 Dify, FastAPI, LLM·음성 제공자를 직접 부르지 않는다. 사용자에게 나가는 모든 AI 텍스트는 투자 권유 금지 검사(`02_ARCHITECTURE.md` 5.3절)를 통과한 뒤에만 응답에 실린다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 Route Handler는 `requireSession('stock')`(`SHARED_MODULES.md:68`). 추가로 `beta_access` 활성과 최신 고지 동의를 확인한다(없으면 403 `ST_BETA` / 428 `ST_CONSENT`). 세션은 모든 인증 단계(A Mock, B Google, C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(인증 경로는 8절) |
| 읽기 | 사용자 세션 클라이언트 + RLS(`has_stock_access`). 서버가 org_id 필터를 따로 믿지 않는다 |
| 쓰기 | 제품 RPC(사용자용 5개) 또는 service_role(`createAdminClient`). service_role 사용 지점은 아래 표의 "service" 표시 행뿐 |
| 멱등 | 클라이언트가 요청마다 UUID `request_id`를 보낸다. 크레딧 `consume:stock:<request_id>`, 잡 `job:stock:<request_id>`, 주문은 `client_order_id` |
| 크레딧 | AI·음성 라우트만 선차감(`CORE_SPEC.md:172-183`). 진단·요약·브리핑은 정액, 채팅·음성은 선차감 후 정산(01_PRD 4.4절) |
| 응답 봉투 | 성공 `{ data, request_id }`, 실패 `{ error: { code, message, retry_after? }, request_id }`. 스트리밍은 NDJSON(`{"type":"status"}`, `{"type":"delta"}`, `{"type":"result"}`, `{"type":"done"}`, `{"type":"error"}`). `delta`·`result`는 투자 권유 금지 검사를 통과한 텍스트를 재생하는 것이며 모델이 만든 토큰을 그대로 흘려보내지 않는다 |
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
| `POST /api/consents` | 베타 | `{ kind: 'investment_disclaimer'\|'paper_order_risk', version }` (`ai_overseas_transfer`는 `/api/onboarding/ai-consent`로만, `voice_processing`은 `/api/voice/consent`로만) | `consents` 행 | 0 | `stock.record_consent`(사용자 세션) | 400(허용되지 않는 kind), 403, 409(버전 불일치) |
| `GET /api/connections` | 베타 | - | 연결 목록(`broker_connections` + `credential_summaries`) | 0 | RLS SELECT | - |
| `POST /api/connections` | 베타 owner/admin(service) | `{ request_id, broker, env, label?, app_key, app_secret, account_no, agree_own_account: true, agree_broker_terms: true }` | 연결(마스킹) | 0 | 어댑터 `verify` → vault `put`(`encrypted_credentials`, provider `broker:<broker>:<env>`) → INSERT `broker_connections` → `enqueue_job(stock.sync)` → audit `stock.connection.create` | 409 상한(`broker_connections_max`), 403 live 비허용, 422 키 오류, 429 |
| `DELETE /api/connections/{id}` | 베타 owner/admin | - | `{ status: 'revoked' }` | 0 | `revoke_credential`(사용자) → service UPDATE status revoked → audit | 403, 404 |
| `POST /api/connections/{id}/sync` | 베타 | `{ request_id }` | `{ job_id }` | 0 | `enqueue_job` | 429(60초), 409(연결 error/revoked) |
| `GET /api/stream-token` | 베타 | `?connections=...&symbols=...` | `{ token, expires_at, url }` | 0 | RLS로 연결 소유 확인 후 HMAC 서명 | 403, 429 |
| `GET /api/instruments/{symbol}` | 베타 | - | 종목 + 재무지표(출처·기준일) | 0 | RLS SELECT | 404 |
| `GET /api/trades/export` | 베타 | `?from&to&symbol?` | CSV 스트림(UTF-8 BOM) | 0 | RLS SELECT, audit `stock.trades.export` | 413(1만 행 초과) |
| `POST /api/ai/diagnoses` | 베타 | `{ request_id, scope_connection_id?, mode: 'quality' }` | NDJSON(`status` → `result` → `done`) | 10 | `consume_credits` → service INSERT/UPDATE `ai_reports` → 서명 토큰(scope `graph:stock.diagnosis`) + FastAPI `POST /graphs/stock.diagnosis/runs` → 실패·검사 차단 시 `refund_credits` | 402 `CR001`, 428 동의, 429 일 상한, 409 데이터 없음, 422 `ST_ADVICE_BLOCKED`(환불됨), 503 `ST_AI_UNAVAILABLE`(환불됨) |
| `GET /api/ai/diagnoses/{id}` | 베타 | - | 리포트 + 항목 | 0 | RLS SELECT | 404 |
| `GET /api/ai/reports/{id}` | 베타 | - | 리포트(kind 진단, 요약, 브리핑) + 항목 | 0 | RLS SELECT | 404 |
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

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다. 모든 라우트는 1절 원칙(`requireSession('stock')`, 베타·동의 확인)에 더해 `STOCK_AI_ENABLED`를 확인한다(false면 503 `ST_AI_UNAVAILABLE`).

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, 동의면 `stock.record_consent('ai_overseas_transfer')` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/voice/consent` | 베타 | `{ notice_version }` | 204 | 0 | 없음 | `stock.record_consent('voice_processing')` | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/ai/conversations` | 베타, `features.ai_chat` | `{ channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `core.ai_conversations` INSERT(service_role, `dify_user` = HMAC(org:user)) | 403 플랜, 428 동의 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000) }` | NDJSON `status`, `delta`(검사 통과 후 재생), `citations`, `fallback`, `usage{credits}`, `done` / `refusal`(조언 요청 거절 카드) / `error` | 선차감 5, 정산 1~8. 거절은 0 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv` = 대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 422 `ST_ADVICE_BLOCKED`(환불됨), 429 `ST_LIMIT`/`RATE_LIMITED`, 503 `ST_AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/ai/research` | 베타, `ai_research_per_day` | `{ request_id, symbols(1..5, ^[0-9A-Z]{6}$), period_days: 7\|30\|90 }` | NDJSON `status`, `result`, `done` / `error`. 완료 시 `report_id` | 8 | scope `graph:stock.research_summary`, `feat=stock.research`. FastAPI `POST /graphs/stock.research_summary/runs`(`jti` 1회) | `consume_credits`, service INSERT/UPDATE `ai_reports`(kind `research`), 실패 시 `refund_credits` | 402, 428, 429, 409 `ST_SOURCE_NONE`(근거 없음, 환불됨), 422 `ST_ADVICE_BLOCKED`(환불됨), 503 |
| `POST /api/ai/briefings` | 베타, `briefing` + `ai_research_per_day` | `{ request_id, symbols(1..10), range: 'prev_day'\|'week' }` | NDJSON `status`, `result`, `done` / `error`. 완료 시 `report_id` | 10 | 같은 그래프, 모드 `briefing` | 같음(kind `briefing`) | 같음 |
| `POST /api/voice/sessions` | 베타, `features.voice_chat` | `{ conversation_id }` | `{ session_id }` | 0 | - | `core.voice_sessions` INSERT | 403 `ST_VOICE_CONSENT` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, request_id }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'stock','voice_chat','stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `ST_VOICE_CONSENT`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/voice/briefings` | 리포트 주인, `features.briefing` | `{ report_id, request_id }`(대본은 `ai_reports(kind briefing, succeeded)`의 `output.script`에서만 읽는다) | `{ url, expires_at, provider }`(7일 서명 URL). 파일이 이미 있으면 200으로 같은 응답 | 글자 수 기준 선차감, 실제 정산 | `briefing`/`tts` 체인에서 시작 제공자 1개 고정, 대체 금지(scope `voice`) | `voice_jobs`(feature `briefing`), Storage `exports/<org_id>/stock/briefing/<report_id>.mp3`, `consume_credits`/`refund_credits`, `rate_limit_hit('stock:briefing:<org>', 5, 3600)` | 409 `ST_BRIEFING_NOT_READY`, 402, 429, 502 `BRIEFING_VOICE_FAILED`(환불됨) |
| `GET /api/voice/briefings/[report_id]` | 리포트 주인 | - | `{ url, expires_at, provider }` | 0 | - | `rate_limit_hit('stock:download:<org>', 60, 3600)` | 404 |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded, reports_closed }` | 정산 | 3분 넘게 `running`인 `ai_reports`는 FastAPI `GET /graphs/runs/{id}`(scope `graph:*`, 읽기)로 마무리 | `ai_usage`(`settled_at is null`, 10분 경과), `ai_reports`, `consume_credits`/`refund_credits` | 401 |
| `POST /api/admin/knowledge/documents` | platform_admin | multipart md(2MB 이하), `{ title }` | `{ document_id }` | 0(운영자 조직 사용량) | FastAPI `/rag/ingest`(scope `rag`, `org`=`STOCK_KNOWLEDGE_ORG_ID`) | Storage 운영자 조직 폴더, 감사 `knowledge.upload` | 409 중복, 403 |
| `POST /api/admin/knowledge/disclosures/ingest` | platform_admin | `{ symbols?: string[], from?: date }` | `{ job_id }` | 0 | 큐 `stock.ai` `stock.ai.disclosure_ingest` enqueue(소스 허용 목록 검사) | `core.jobs`, 감사 `knowledge.ingest` | 409 `ST_SOURCE_DISABLED`, 403 |
| `POST /api/admin/wiki/ingest`, `POST /api/admin/wiki/lint` | platform_admin | `{ document_ids?: uuid[] }` | `{ run_id }` | 0 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | - | 403 |
| `PATCH /api/admin/wiki/pages/[...slug]` | platform_admin | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 6절 R-7) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`). 위키는 서버 컴포넌트가 로그인 확인 뒤 운영자 조직의 `published` 페이지를 service_role로 읽어 그린다(사용자 입력이 쿼리에 들어가지 않는 slug 조회만, D-16).

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

제품 AI 전용 RPC는 만들지 않았다. AI 관련 호출은 코어 RPC를 인용만 한다(`CORE_SPEC.md`와 `0008_core_ai.sql`).

| 코어 RPC | 호출자 | 용도 | 비고 |
|---|---|---|---|
| `core.set_ai_cross_border_ack(p_org_id, p_ack, p_notice_version)` | authenticated(owner/admin) | 국외 이전 동의·철회 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| `core.resolve_ai_route(p_org_id, p_app_id, p_feature, p_kind)` | service_role(FastAPI, Next.js 음성) | 기능별 제공자 체인 | 미동의 조직은 상용이 빠진다 |
| `core.match_ai_chunks(...)` | service_role(FastAPI) | 공시·위키 검색 | 지식 조직 컬렉션만 |
| `core.consume_credits`, `core.refund_credits` | service_role(Next.js 서버) | 선차감·환불·정산 | 사용자 RPC 안에서 부르지 않는다 |

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
| `stock.ai.disclosure_ingest` | `{ symbols?: string[], from?: string(date), source: 'disclosure', terms_ref: string }` | `{ documents: number, chunks: number, skipped: number }` | `"n/m 종목"` |
| `stock.ai.wiki_ingest` | `{ document_ids: uuid[] }` | `{ pages_created: number, pages_updated: number, deferred: number }` | - |
| `stock.ai.wiki_lint` | `{}` | `{ run_id: uuid, findings: number }` | - |

규칙: 비밀값을 payload에 넣지 않는다. 워커는 `broker_connections.credential_id`로 vault에서 복호화한다(`CORE_SPEC.md:306`). `stock.sync`의 org_id는 `core.jobs.org_id`와 연결의 org_id가 같아야 하며 다르면 재시도 없는 실패.

AI 그래프 계약(FastAPI `POST /graphs/{name}/runs` 입력, `GET /graphs/runs/{id}` 출력). 요청 본문의 org는 무시하고 서명 토큰의 org·app만 쓴다.

| 그래프 | 입력 | 출력(`output`) |
|---|---|---|
| `stock.research_summary` | `{ report_id, request_id, mode: 'summary'\|'briefing', symbols: string[], period_days?: 7\|30\|90, range?: 'prev_day'\|'week' }` | `{ summary: [{ symbol, items: [{ text, source_ids: string[], filed_at: date }] }], sources: [{ id, type: 'disclosure'\|'wiki', title, url, filed_at? }], script?: string(briefing만, 600~1,500자), no_source: boolean, labels: { ai_generated: true, disclaimer_version }, advice_check: { passed, rules_version, judge: { provider, model }\|null, regenerations, checked_at } }` |
| `stock.diagnosis` | `{ report_id, request_id, scope_connection_id?, snapshot: { as_of, positions: [{ symbol, name, weight_pct, pnl_pct, sector, risk_level, fundamentals? }] }, prompt_version }`(금액·수량·평단·계좌 없음) | `{ summary, concentration: { top1_pct, top3_pct, level }, sector_exposure: [{ sector, weight_pct }], items: [{ symbol, risk_level, factors: string[], rationale }], data_gaps: string[], labels, advice_check }` |

실행 실패 코드(`ai_runs.error`): `ADVICE_BLOCKED`(재생성 후에도 위반 또는 판정 불가), `SOURCE_NONE`(근거 없음), `SCHEMA_INVALID`, `PROVIDER_UNAVAILABLE`(체인 소진), `TIMEOUT`. Route Handler가 이를 7절 코드로 바꾸고 환불한다. 출력에 `buy_price` 등 가격 키가 있으면 `compliance` 노드와 DB CHECK가 둘 다 거부한다.

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
| LLM·임베딩 제공자(Anthropic, OpenAI, Google, OpenRouter, 오픈소스 vLLM) | FastAPI 라우터(`apps/api/app/ai/llm`)만. Next.js·워커에서 직접 호출하지 않는다(2026-10-13 변경) | 체인 다음 제공자로 대체, 소진 시 환불 | 조직당 분 3회 + 일 상한 |
| ElevenLabs, 오픈소스 음성 서버 | `packages/core-voice`(Next.js 서버) | 체인 대체(브리핑은 대체 금지), 실패 시 환불 | 미확인 |
| DART 오픈API(공시 본문 수집) | FastAPI `app/ai/products/stock/disclosures.py`, 잡 `stock.ai.disclosure_ingest` | 실패 문서 `failed` + 재시도 3회 | 일 호출 한도 미확인 |
| Toss(P2) | core-billing | `SHARED_MODULES.md` 5장 | - |
| KRX 휴장일 공지 | 수동 적재(`stock.calendar_load`, source manual) | - | - |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 stock이 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | stock 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R-7). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `research`(공시·위키 검색 + `chat` 모델), 모드 `term`(위키 + `wiki.query`). 조언 요청 의도 판정, 투자 권유 금지 검사, compliance를 거친 답변만 assistant `ai_messages`(본문, citations, 제공자, 토큰)로 FastAPI가 저장 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리(모드는 FastAPI가 분류) |
| `POST /dify/retrieval` | Dify 외부 지식 | 내부 키 | 운영자 조직의 `stock-wiki` 컬렉션만. 공시 컬렉션과 사용자 조직 데이터는 노출하지 않는다 |
| `POST /graphs/stock.research_summary/runs`, `POST /graphs/stock.diagnosis/runs`, `GET /graphs/runs/{id}` | Next.js 서버 | 서명 토큰 scope `graph:<name>`, `jti` 1회 | 4절 그래프 계약 |
| `POST /rag/ingest` | Next.js 관리자, 큐 `stock.ai` | 서명 토큰 scope `rag`(org = 지식 조직) | 해설집 색인. 공시 색인은 잡이 FastAPI 안에서 수집·색인 |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-7) | Next.js 관리자 | 서명 토큰 scope `wiki` | 위키 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`stock-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `stock-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_STOCK`(Next.js 서버 전용). 정의는 `infra/dify/stock-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID). 서명 토큰, org, 보유 내역, 계좌 정보는 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`; 분류 `research` / `term` / `advice` / `other`) → 분기 `research`·`term`: HTTP 요청 노드(`/tools/answer`, 모드만 다름) → 답변 / 분기 `advice`: **고정 거절 문구 노드(LLM 없음)** → 답변 / 분기 `other`: 고정 안내 노드. Dify 안에서 모델이 사용자에게 보이는 텍스트를 만드는 노드는 없다 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, mode }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title, filed_at? }], no_source: boolean, refusal: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }`. `advice_check`를 통과하지 못하면 `answer` 대신 오류 응답(422)을 주고 Next.js가 환불한다 |
| 분류 신뢰 | Dify 분류는 1차 필터일 뿐이다. FastAPI가 모든 요청에 의도 판정(규칙 + 판정 모델)을 다시 하므로 분류가 `research`로 잘못 나와도 조언 요청은 거절된다 |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다 |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

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
| `ST_LIMIT`(앱, 확장) | 일 채팅 턴·요약·브리핑 상한도 같은 코드 | 429 |
| `ST_ADVICE_BLOCKED`(앱) | 투자 권유 금지 검사 실패(재생성 후에도 위반 또는 판정 불가). 결과 미저장, 환불됨 | 422 |
| `ST_SOURCE_NONE`(앱) | 요약할 근거(공시)가 없음. 환불됨 | 409 |
| `ST_SOURCE_DISABLED`(앱) | 이용 조건이 확인되지 않은 소스 색인 시도(`STOCK_RAG_SOURCES`에 없음) | 409 |
| `ST_VOICE_CONSENT`(앱) | 음성 처리 고지 확인 없음 | 403 |
| `ST_BRIEFING_NOT_READY`(앱) | 브리핑이 `succeeded`가 아님(대본 없음) | 409 |
| `ST_AI_UNAVAILABLE`(앱) | AI 비상 정지, 모든 제공자 실패, 서비스 장애. 환불됨 | 503 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 조직 설정으로 풀려는 시도(`set_ai_routing`). 이 제품 화면은 `set_ai_routing`을 부르지 않으므로 운영 도구에서만 나온다 | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려는 시도. 위와 같이 운영 도구에서만 나온다. 일반 요청은 오류가 아니라 체인에서 상용이 빠진다 | 403 |
| `42501`(AI) | 다른 조직 컬렉션 요청, 위조·재사용 토큰 | 403 |
| 코어 | `42501` → 403, `CR001` → 402(선차감 부족, 잔액·필요량 포함), `P0002` → 404, `PM001/PM409` → 409 + 알림(`CORE_SPEC.md:418`) | - |

주문의 한도 위반, 킬 스위치, 시세 지연, 확인 만료는 오류 코드가 아니라 200 응답의 `status`(`blocked`/`expired`)와 `block_reason`으로 돌려준다.

## 8. 인증 경로 (2026-10-14 추가, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.1, 2.4, 3.2, 7.2.3절. 이 경로들은 `src/app/api/dev/login/`, `src/app/auth/`, `src/app/invite/continue/`에 있고 인증 단계 분기는 `src/lib/auth/`만 한다(`02_ARCHITECTURE.md` 9절). 초대 발급·수락 API(2절 `POST /api/beta/invites`, `POST /api/beta/redeem`)와 수락 서버 시퀀스(3절)는 바뀌지 않는다.

| 메서드 경로 | 단계 | 인증 | 입력 | 처리 | 출력 | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | 없음 | `{ persona, next? }`(persona는 `05_DATA_MODEL.md` 10절 키 목록 zod enum) | `isMockAuthAllowed()`(AUTH_MODE=mock + Supabase 호스트 127.0.0.1/localhost + `VERCEL_ENV`·`RAILWAY_ENVIRONMENT` 비어 있음) 거짓이면 404 → 서버 클라이언트 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('stock', next)` | 303 → 이동 경로 | 404(판정 거짓, 존재를 숨김), 400(모르는 persona). 레이트 리밋 대상 아님 |
| `POST /api/dev/logout` | A(로컬 전용) | 세션 | - | 판정 거짓이면 404, `signOut` | 303 `/login` | 404 |
| `GET /auth/callback` | B·C | 없음(OAuth 코드) | `?code&next` | `finishLogin('stock', next)`: ① `exchangeCodeForSession` ② `session_context('stock')` 1회(프로필 없음 → 로그아웃 후 `/login`) ③ invite 앱이므로 `bootstrap_app_for_org`를 부르지 않는다 ④ `status` suspended → 403. `entitled=false`면 `next`가 `/invite/continue`일 때만 그대로, 아니면 `/no-access` ⑤ `next` 화이트리스트(`/`로 시작, `//`·`@`·`\` 없음, origin `NEXT_PUBLIC_APP_URL` 고정) ⑥ 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 미기록) | 302 → 이동 경로 | `/login?error=callback`(코드 없음·재사용·만료) |
| `GET /invite/continue` | B·C | 세션 | 쿠키 `stock_invite`(HMAC `INVITE_CONTINUE_SECRET`, 10분, 01_PRD D-23 제안) | 쿠키 검증·삭제 → 2절 `POST /api/beta/redeem`과 같은 서버 함수(3절 시퀀스) | 302 `/onboarding/disclaimer` | 쿠키 없음·만료 → `/no-access`, `ST031` → `/no-access?error=invite_email`, `ST030`·만료 → `/no-access?error=invite_invalid`("초대가 만료되었거나 이미 사용되었습니다. 운영자에게 재발급을 요청하세요") |
| `GET /auth/naver/start` | C2(브리지 경로 채택 시만) | 없음 | `?next` | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분) → 네이버 authorize 302. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 302 | 429 |
| `GET /auth/naver/callback` | C2(브리지만) | 없음 | `?code&state` | state 상수 시간 비교 → 토큰 교환 → `/v1/nid/me` → `core.auth_identity_links` 조회 → 세션 발급(`AUTH_ROADMAP.md:286-299`) → `finishLogin` | 302 | `/login?error=state`, `/login?error=email_in_use` |

`/invite/[token]`에서 Google을 누르면 서버 액션이 토큰을 검증(존재·미사용·미만료만, 이메일 일치는 수락 때)한 뒤 `stock_invite` 쿠키를 굽고 `signInWithOAuth({ provider: 'google', options: { redirectTo: <APP_URL>/auth/callback?next=/invite/continue } })`로 보낸다. 초대 토큰 원문은 리디렉트 URL에 넣지 않는다(제안).

오류 코드(7절에 더함):

| 코드 | 의미 | HTTP / 이동 |
|---|---|---|
| `error=callback` | 콜백 코드 없음·재사용·만료·교환 실패 | 302 `/login?error=callback` |
| `error=state` | 브리지 state 불일치·없음·만료(C2) | 302 `/login?error=state` |
| `error=email_in_use` | 브리지에서 같은 이메일의 다른 수단 가입자(C2) | 302 `/login?error=email_in_use` |
| `error=invite_email` | OAuth 계정 이메일이 초대 이메일과 다름(`ST031`) | 302 `/no-access?error=invite_email` |
| 404(dev) | `/api/dev/*`를 Mock 판정이 거짓인 환경에서 호출 | 404(본문 없음) |
