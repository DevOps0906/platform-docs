# 05 데이터 모델: Stock Dashboard

작성일 2026-10-12. 정본 SQL은 모듈러 조각 `docs/products/_supabase-modular/migrations/1900_stock.sql`(이하 `1900:줄`)이다. 모놀리스 `supabase/monolith/migrations/0002_stock_domain.sql`, `0003_stock_orders_paper.sql`은 같은 본문을 `DB_CONVENTIONS.md` 12장 규칙으로 변환한 것이다. 리뷰가 제안한 6개 테이블 초안(`broker_connections`, `holdings_snapshots`, `trades`, `ai_recommendations`, `recommendation_results`, `audit_logs`, `docs/reviews/Stock_Trader_nomad.md:69`)을 확장했다. 감사는 코어 `audit_log`를 쓰고 제품 테이블로 다시 만들지 않는다.

2026-10-13 개정(확정 결정 13~17): **제품 AI 전용 테이블은 새로 만들지 않았다.** AI 대화·실행·위키·음성은 코어 `core.ai_*`, `core.wiki_*`, `core.voice_*`를 쓰고(6절), 기존 `stock.ai_reports`의 `kind`를 `research`(리서치 요약), `briefing`(브리핑)으로 넓히고 `consents.kind`에 `voice_processing`을 더했으며, 성공 저장되는 모든 AI 결과에 `output.advice_check.passed = true`를 요구하는 CHECK를 더했다(`1900_stock.sql` 14.1절, 아래 2.7절). 기능별 라우팅 기본값 12행과 플랜 AI 키는 14.2~14.3절(모놀리스는 `seed.sql`)에 있다.

## 1. 개요와 ERD

```
core.organizations (참조만)
 |-- stock.beta_access (1:1, 초대 수락)            <- stock.beta_invites (service 전용)
 |-- stock.consents (append-only, 사용자별 동의)
 |-- stock.broker_connections --(credential_id)--> core.encrypted_credentials (참조만)
 |     |-- stock.balance_snapshots (시계열)
 |     |-- stock.holdings (현재 보유, 연결 x 종목 유일)
 |     |-- stock.trades (체결, 연결 x broker_exec_id 유일)
 |     |     |-- stock.trade_notes (사용자 메모, 유일한 사용자 쓰기 테이블)
 |     |-- stock.order_requests (P3, paper 전용)
 |           |-- stock.order_events (append-only)
 |-- stock.ai_reports --(credit_ledger_id)--> core.credit_ledger (참조만)
 |     |-- stock.ai_report_items
 |           |-- stock.idea_evaluations (P2)
 |-- stock.order_limits (P3, 조직 1행)
 |-- stock.kill_switches (P3, 전역/조직/연결)
전역 참조: stock.instruments -< stock.fundamentals, stock.daily_prices(service 전용), stock.market_calendar
```

같은 조직 안에서만 참조가 성립하도록 하위 테이블은 `(parent_id, org_id)` 복합 FK를 쓴다(`1900:237`, `:254`, `:277`, `:290`, `:345`, `:365`, `:770`, `:788`). 다른 조직의 행 id를 알아도 메모나 리포트 항목을 붙일 수 없다(스모크 테스트 `23503`).

## 2. 테이블

표준 컬럼 표기: id(uuid 또는 identity), org_id(FK cascade), created_at, updated_at(+`core.set_updated_at` 트리거), status(text+CHECK). 상세 컬럼은 SQL이 정본이며 아래는 핵심 컬럼만 적는다.

### 2.1 `beta_invites` (`1900:90`) 표준 컬럼: id, created_at, updated_at, status

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| email_normalized | text | N | - | 소문자·trim CHECK |
| token_hash | text | N | - | sha256 hex 64자, unique. 원문 미저장 |
| status | text | N | issued | issued/accepted/revoked/expired |
| expires_at | timestamptz | N | now()+14일 | 제안 |
| invited_by, accepted_user_id | uuid | Y | - | 행위자(FK 없음) |
| accepted_org_id | uuid | Y | - | organizations FK set null |

제약: 같은 이메일의 issued 초대는 1개(`beta_invites_open_email_uniq`).

### 2.2 `beta_access` (`1900:110`) PK org_id

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| org_id | uuid | N | - | PK, organizations cascade |
| invite_id | uuid | Y | - | 수락한 초대 |
| status | text | N | active | active/revoked |
| granted_at, revoked_at, revoke_reason | - | - | - | 이력 |

### 2.3 `consents` (`1900:563`) append-only

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id | bigint identity | N | - | PK |
| org_id, user_id | uuid | N | - | 동의한 사람 |
| kind | text | N | - | investment_disclaimer / ai_overseas_transfer / paper_order_risk / voice_processing(2026-10-13) |
| version | text | N | - | `YYYY-MM-DD(.n)` CHECK |
| accepted_at | timestamptz | N | now() | - |

제약: `(org_id, user_id, kind, version)` unique.

### 2.4 참조 데이터

| 테이블 | 핵심 컬럼 | 제약 | 비고 |
|---|---|---|---|
| `instruments` (`1900:142`) | symbol PK(`^[0-9A-Z]{6}$`), name, market(KOSPI/KOSDAQ/KONEX/ETF/ETN/INDEX), sector, is_active, listed_on/delisted_on(date) | - | `IDXKSP` = 코스피 지수 내부 코드 |
| `fundamentals` (`1900:154`) | symbol, fiscal_period(`YYYYQn`/`YYYYFY`), per, pbr, roe_pct, eps_krw, dividend_yield_pct, source(dart/broker/manual), source_ref, as_of(date) | `(symbol, fiscal_period, source)` unique | 모달의 출처·기준일 표기 원천 |
| `daily_prices` (`1900:171`) | (symbol, trade_date) PK, open/high/low/close, volume, source(broker/krx/mock) | close > 0 | 사용자 GRANT 없음(성과 계산 전용) |
| `market_calendar` (`1900:184`) | trade_date PK, is_open, open_at/close_at(timestamptz), note | 개장일이면 시각 필수 | 장 시간 바, 동기화 주기, 성과 거래일 계산 |

### 2.5 `broker_connections` (`1900:200`) 표준 컬럼: 전부

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| broker | text | N | - | mock/kis/kiwoom/hana |
| env | text | N | paper | paper/live |
| label | text | Y | - | 40자 |
| account_masked | text | N | - | `[0-9*-]`만, `*` 필수, 숫자 5자리 연속 금지 |
| account_ref_hash | text | N | - | HMAC-SHA256 hex(중복 연결 판정) |
| credential_id | uuid | Y | - | `encrypted_credentials` FK(set null) |
| status | text | N | pending | pending/active/error/revoked |
| orders_enabled | boolean | N | false | paper에서만 true 가능 |
| last_synced_at, last_error_code, consecutive_errors | - | - | - | 동기화 상태 |
| created_by | uuid | Y | - | - |

제약: `(id, org_id)` unique(복합 FK 대상), `(org_id, broker, env, account_ref_hash)` unique, `orders_enabled → env='paper'`, `broker='mock' → env='paper'`, mock이 아니고 pending/revoked가 아니면 `credential_id` 필수.

### 2.6 동기화 결과

| 테이블 | 핵심 컬럼 | 제약 |
|---|---|---|
| `balance_snapshots` (`1900:226`) | id identity, org_id, connection_id, captured_at, cash_krw, purchase_krw, eval_krw, pnl_krw(생성 컬럼), is_sample, source(sync/mock) | 복합 FK(connection) |
| `holdings` (`1900:240`) | org_id, connection_id, symbol, name, quantity(numeric 18,4), avg_price, purchase_krw, is_sample, synced_at | `(connection_id, symbol)` unique |
| `trades` (`1900:257`) | org_id, connection_id, broker_exec_id, symbol, name, side(buy/sell), quantity, price, amount_krw, fee_krw, tax_krw, executed_at, is_sample | `(connection_id, broker_exec_id)` unique, `(id, org_id)` unique |
| `trade_notes` (`1900:281`) | org_id, trade_id, body(1~2000자), tags(최대 10), created_by(default `auth.uid()`) | 복합 FK(trade) |

### 2.7 AI

| 테이블 | 핵심 컬럼 | 제약 |
|---|---|---|
| `ai_reports` (`1900:298`) | kind(diagnosis/idea/research/briefing, 2026-10-13), scope_connection_id, status, mode, provider, model, prompt_version, input_hash(sha256), input_summary(jsonb, 계좌번호·금액 없음), output(jsonb), disclaimer_version, credits_charged, credit_ledger_id(→core.credit_ledger), request_id(unique, 멱등), error_code, started_at, finished_at | `ai_reports_no_price_targets_check`(`1900:325`): output에 `buy_price`, `entry_price`, `target_price`, `stop_price`, `stop_loss` 키 금지. succeeded면 output 필수. **`ai_reports_advice_check_passed_check`(14.1절, 2026-10-13)**: succeeded면 `output.advice_check.passed = true` 필수(없으면 `23514`). kind `research`·`briefing`의 `output`은 04장 4절 그래프 계약(요약 문장, 출처, 브리핑 대본 `script`, `advice_check`)을 jsonb로 담는다 |
| `ai_report_items` (`1900:331`) | report_id, symbol, risk_level(low/medium/high), weight_pct, factors(jsonb 배열), rationale(1000자), reference_price, reference_at | `(report_id, symbol)` unique |
| `idea_evaluations` (`1900:349`, P2) | item_id, horizon_days(5/20/60), entry_date, entry_price, eval_date, eval_price, return_pct, benchmark_return_pct, excess_pct(생성 컬럼), rule_version | `(item_id, horizon_days)` unique, eval_date > entry_date |

`reference_price`는 아이디어 생성 시점 기록용이며 매수가가 아니다. 성과 진입가는 규칙상 다음 개장일 시가(01_PRD 3.4)로 `idea_evaluations.entry_price`에 따로 둔다.

`research`, `briefing` 리포트는 `scope_connection_id`가 null이고 `input_summary`에 종목코드와 기간만 남긴다(보유 수량·금액 없음). 같은 표를 쓰는 이유는 6절 "제품 AI 표를 만들지 않은 이유"에 있다.

### 2.8 모의주문(P3, `0003_stock_orders_paper.sql`)

| 테이블 | 핵심 컬럼 | 제약 |
|---|---|---|
| `order_limits` (`1900:693`) | org_id PK, max_order_krw(1만~1천만, 기본 100만), max_daily_krw(1만~5천만, 기본 500만), max_orders_per_day(1~100, 20), max_position_weight_pct(1~100, 30), max_price_deviation_pct(0.5~10, 5), max_quote_age_seconds(1~60, 10) | 일 한도 ≥ 1회 한도 |
| `kill_switches` (`1900:713`) | scope(global/org/connection), org_id, connection_id, is_active, trigger_source(manual/ops/auto_quote_stale/auto_broker_errors/auto_balance_mismatch), reason, engaged_*, released_* | 범위별 대상 CHECK, 같은 대상 활성 1개(`kill_switches_one_active_idx`) |
| `order_requests` (`1900:738`) | client_order_id(unique 멱등), env(`= 'paper'` CHECK), symbol, side, order_type(`= 'limit'`), quantity(int>0), limit_price, est_amount_krw(생성), ref_price, ref_price_at, status, limit_check(jsonb), block_reason, confirm_expires_at, confirmed_at/by, submitted_at, broker_order_id, filled_quantity, avg_fill_price, prefill_report_id, created_by(필수) | confirmed 이후 상태는 confirmed_at/by 필수, blocked는 block_reason 필수, `(connection_id, broker_order_id)` unique |
| `order_events` (`1900:776`) | order_id, event, from_status, to_status, detail(jsonb, 비밀 금지), actor_id, actor_role(user/service/system) | append-only 트리거 |

## 3. 상태 전이

모든 전이는 `stock.enforce_status_transition()` 트리거(`1900:52`)가 인자 목록으로 강제한다(위반 `22023`, service_role 쓰기에도 적용). 부수 효과가 있는 전이는 RPC가 맡는다(`DB_CONVENTIONS.md:224-225`).

| 테이블 | 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|---|
| beta_invites | (신규) | issued | service(운영자 API) | audit |
| | issued | accepted / revoked / expired | `redeem_beta_invite` / 운영자 / 만료 처리 | accepted: beta_access 생성 |
| beta_access | (신규) | active | `redeem_beta_invite` | 플랜 전환(서버) |
| | active ↔ revoked | revoked, active(재초대) | `revoke_beta_access` / 재수락 | 회수 즉시 도메인 RLS 0행 |
| broker_connections | (신규) | pending, active(mock) | service | sync enqueue |
| | pending | active / error / revoked | 워커, 사용자 해제 | revoked: `revoke_credential` |
| | active | error / revoked | 워커(연속 오류 5회) / 사용자 | 알림 |
| | error | active / revoked | 재연결 / 해제 | - |
| ai_reports | (신규) | queued | 서버 | 크레딧 선차감 |
| | queued | running / canceled / failed | 서버 | failed·canceled: 환불 |
| | running | succeeded / failed | 서버 | failed: 환불 |
| order_requests | (신규) | pending_confirm / blocked | `create_paper_order` | event created/blocked |
| | pending_confirm | confirmed / expired / canceled / blocked | `confirm_paper_order`, `expire_pending_orders`, `engage_kill_switch` | confirmed: submit 잡 |
| | confirmed | submitted / blocked / failed | `apply_order_update`(제출 직전 킬 스위치 재확인) | - |
| | submitted | accepted / rejected / failed | 워커 | - |
| | accepted | partially_filled / filled / canceled / rejected | 워커 | - |
| | partially_filled | partially_filled / filled / canceled | 워커 | - |

설계 원칙: 차단·만료는 예외로 롤백하지 않고 상태로 기록한 뒤 행을 반환한다. 코어 `confirm_payment_order`의 raise가 같은 호출의 UPDATE를 롤백하는 것(그래서 코어가 `fail_payment_order`를 별도 호출로 분리했다)과 같은 함정을 제품에서 반복하지 않기 위해서다. 스모크 테스트에서 한도 초과·괴리·시세 지연·킬 스위치 주문이 모두 `blocked` 행과 `order_events`로 남는 것을 확인했다.

## 4. RLS 정책

모든 테이블 RLS ON. `FOR ALL` 정책 없음. 사용자 쓰기 정책은 `trade_notes`만.

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| beta_invites, daily_prices | 정책 없음 | 없음 | 없음 | 없음 | 없음(42501) |
| beta_access | `core.is_org_member(org_id)` | 없음 | 없음 | 없음 | select |
| consents | `user_id = auth.uid() and is_org_member(org_id)` | RPC `record_consent`만 | 없음(append-only) | 없음 | select |
| instruments, fundamentals, market_calendar | `true`(공개 정보) | 없음 | 없음 | 없음 | select |
| broker_connections, balance_snapshots, holdings, trades, ai_reports, ai_report_items, idea_evaluations | `stock.has_stock_access(org_id)` | 없음 | 없음 | 없음 | select |
| trade_notes | `has_stock_access(org_id)` | `with check (has_stock_access(org_id) and created_by = auth.uid())` | `using/with check` 같은 식 | `has_stock_access and (created_by = auth.uid() or has_org_role(owner, admin))` | select, insert(org_id, trade_id, body, tags), update(body, tags), delete |
| order_limits, order_requests, order_events | `has_stock_access(org_id)` | RPC만 | RPC만 | 없음 | select |
| kill_switches | `scope = 'global' or has_stock_access(org_id)` | RPC만 | RPC만 | 없음 | select |

`has_stock_access`(`1900:124`) = `is_org_member` + `has_entitlement(org,'stock')` + `beta_access.status='active'`. 정책 안에서 `org_members`를 직접 조회하지 않고 SECURITY DEFINER 헬퍼만 쓴다(42P17 방지, `DB_CONVENTIONS.md:126`).

`trade_notes`에 쓰기 정책을 준 근거(`DB_CONVENTIONS.md` 8.1): (a) `with check`에 멤버+엔타이틀먼트(+베타) 포함, (b) 돈·권한·상태 컬럼 없는 순수 메모, (c) 상태 컬럼 없음. `created_by`는 INSERT 컬럼 GRANT에서 빠져 있어 위조할 수 없다(스모크 42501).

이중 잠금: `trade_notes`를 제외한 전 테이블에 `core.guard_privileged_write` 트리거(`1900` 6절). append-only: `order_events`, `consents`에 `stock.reject_log_mutation`(`ST000`, 조직 purge GUC만 예외).

### 4.1 RLS 스모크 테스트 결과 (2026-10-12, PGlite)

2026-10-13 변경 후 재검증 필요: 아래 75항목은 AI 보강(14.1절) 이전 결과다. ST-06-003이 자동화할 때 다음 항목을 추가한다: ① `ai_reports` kind `research`·`briefing` 성공 저장(advice_check 있음) 허용, ② `output.advice_check` 없는 성공 저장 `23514`, ③ `passed=false` 성공 저장 `23514`, ④ 가격 키 `23514`(기존), ⑤ `consents` kind `voice_processing` 기록 허용·미지 kind 거부. 이 5개는 PGlite 임시 스크립트로 모듈러·모놀리스 모두 통과를 확인했다(2026-10-13, 아래 9절).

스크립트는 저장소 밖 임시 디렉토리에서 실행했다(ST-06-003이 `supabase/tests/`로 옮긴다). 사용자 A(베타), B(다른 조직, 베타), C(초대 없음, default 엔타이틀먼트).

| 구분 | 모듈러 | 모놀리스 |
|---|---|---|
| 결과 | 75 통과 / 0 실패 | 75 통과 / 0 실패 |
| 함수 권한 | stock 함수 14개 중 PUBLIC·anon EXECUTE 0개(core 0007 규칙. 조각 끝에 `revoke execute on all functions in schema stock from public`) | 같음(함수별 revoke) |

| 주요 검사 | 기대 | 실제 |
|---|---|---|
| B가 A 조직 도메인 14개 테이블 SELECT | 0행 | 0행 |
| B `beta_invites`, `daily_prices`, `encrypted_credentials` SELECT | 42501 | 42501 |
| B A 거래에 메모 INSERT(org A) / (org B로 FK 우회) | 42501 / 23503 | 일치 |
| B A 메모 UPDATE/DELETE | 0행 | 0행 |
| B `holdings` INSERT, `broker_connections` DELETE | 42501 | 42501 |
| B RPC `engage_kill_switch`, `set_order_limits`, `confirm_paper_order`, `record_consent`(A 조직) | 42501 | 42501 |
| B RPC `redeem_beta_invite`, `revoke_beta_access`, `apply_order_update`, `expire_pending_orders` | 42501 | 42501 |
| B 자기 조직 `beta_access` INSERT(셀프 베타) | 42501 | 42501 |
| B 자기 `org_members.role`, `profiles.platform_role`, `app_entitlements.plan_id`, `subscriptions.plan_id`, `wallets` 변경, `grant_credits` | 42501 | 42501 |
| C 가입(초대 없음) 뒤 엔타이틀먼트 / 자기 `bootstrap_app_for_org('stock')` / 자기 연결 조회 / 킬 스위치 | 0행 / 42501(invite-only) / 0행 / 42501 | 2026-10-13 코어 반영 후 재실행 필요 |
| A 양성 대조(자기 holdings, 메모 INSERT, 동의 기록, 주문 확인, 킬 스위치 작동·해제) | 성공 | 성공 |
| A 메모 created_by 위조, holdings·order_limits 직접 UPDATE, `create_paper_order` 직접 호출 | 42501 | 42501 |
| 마스킹 안 된 계좌번호, mock live, live 주문, AI 출력 `target_price`, 한도 상한 초과 | 23514 | 23514 |
| ai_reports 역전이, pending→submitted 건너뛰기 | 22023 | 22023 |
| order_events UPDATE/DELETE | ST000 | ST000 |
| 1회 한도 초과 / 괴리 14% / 30초 지난 시세 / 전역 킬 스위치 뒤 주문 | blocked(사유별) | 일치 |
| 같은 client_order_id 2회 | 같은 주문 | 같음 |
| 초대 재사용 / 다른 이메일 수락 | ST030 / ST031 | 일치 |
| 베타 회수 뒤 A 자기 holdings | 0행 | 0행 |
| A가 전역 킬 스위치 해제 | 42501 | 42501 |

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `broker_connections_org_idx (org_id) where status <> 'revoked'` | 연결 목록, 상한 계산 |
| `balance_snapshots_conn_captured_idx (connection_id, captured_at desc)`, `_org_captured_idx` | 최신 스냅샷, Total 합계, 기간 차트 |
| `holdings_org_idx`, unique `(connection_id, symbol)` | 보유 그리드, 동기화 upsert |
| `trades_org_executed_idx (org_id, executed_at desc)`, `trades_org_symbol_idx` | 매매 일지 필터, CSV |
| `ai_reports_org_created_idx`, `ai_reports_org_day_idx (org_id, kind, created_at)` 부분 | 이력, 일 상한 계산 |
| `fundamentals_symbol_idx (symbol, as_of desc)` | 모달 |
| `daily_prices_date_idx` | 성과 배치 |
| `order_requests_org_created_idx`, `_pending_idx`(만료 스캔), `_open_idx` | 주문 목록, 만료 함수, 워커 |
| `order_events_order_idx`, `kill_switches_org_idx`, `kill_switches_one_active_idx` | 이벤트 타임라인, 차단 판정 |

예상 규모(베타 30조직, 제안): 스냅샷 장중 5분 x 78회/일 x 2연결 x 250일 ≈ 연 117만 행. 1년 보존 뒤 삭제 잡으로 유지. Realtime 발행: `holdings`, `balance_snapshots`, `ai_reports`, `broker_connections`, `order_requests`(RLS 하에서 구독).

## 6. 코어 참조

| core 객체 | 용도 | 변경 여부 |
|---|---|---|
| `organizations` | 모든 org_id FK | ALTER 없음 |
| `apps`, `plans` | `stock` 등록, beta/pro 플랜 보충 INSERT(`on conflict do nothing`) | 데이터만 |
| `encrypted_credentials`, `revoke_credential`, `credential_summaries` | 증권사 키 | ALTER 없음 |
| `credit_ledger`, `consume/grant/refund_credits` | AI 과금, 베타 첫 달 지급 | 호출만 |
| `subscriptions`, `app_entitlements` | 베타 플랜 전환(service) | 서버 UPDATE(guard 통과) |
| `jobs`, `enqueue_job` 등 | `stock.*` 잡 | 호출만 |
| `audit_log`, `write_audit` | 감사(service RPC는 직접 INSERT) | 호출만 |
| `is_org_member`, `has_org_role`, `has_entitlement`, `is_service_caller`, `is_privileged_session`, `guard_privileged_write`, `set_updated_at` | 정책·함수 헬퍼 | 호출만 |
| `rate_limit_hit` | 레이트 리밋 | 호출만 |
| `core.allow_purge` GUC | append-only 테이블의 조직 purge 예외 | 읽기만 |

`core.*` ALTER 없음을 확인했다(조각에 `alter table core` 0건).

AI·음성 코어 객체(2026-10-13, `docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | stock 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 채팅 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`). 저장되는 assistant 메시지는 모두 투자 권유 금지 검사 통과분 | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `stock.research_summary`·`stock.diagnosis` 실행 기록, 위키 lint 결과. `ai_run_steps.detail`에는 위반 유형만 남기고 위반 원문은 남기지 않는다 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, Next.js 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 12행(`1900_stock.sql` 14.2절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 공시(`stock-disclosures`)·위키(`stock-wiki`) 컬렉션(운영자 지식 조직만). 문서 `source_type`은 공시 `url`(원문 URL), 해설집 `upload` | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 주식 용어·공시 해설 위키(운영자 지식 조직만) | FastAPI(쓰기), Next.js 서버(읽기) |
| `voice_sessions`, `voice_jobs` | 음성 질의, STT·TTS·브리핑 낭독 작업(`store_audio=false`) | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |

제품 AI 표를 만들지 않은 이유(`docs/products/_platform-core/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 리서치·브리핑 결과 표 | 대본을 저장하고, 가격 키와 검사 기록을 DB 수준에서 막기 | 기존 `stock.ai_reports`의 kind 확장 + advice_check CHECK. 진단과 같은 멱등 키(`request_id`), 크레딧 연결, 상태 머신, RLS, 일 상한 인덱스, Realtime을 그대로 쓴다 |
| 대화-종목 연결 표 | 채팅이 어느 종목을 다루는지 | 연결하지 않는다. 채팅은 공개 자료 질의이고 보유 내역을 넣지 않는다(01_PRD 6.7절) |
| 브리핑 음성 파일 표 | mp3 위치와 재사용 | 결정적 Storage 경로 `exports/<org_id>/stock/briefing/<report_id>.mp3` + `voice_jobs`(feature `briefing`, `characters`, `provider_id`) |
| 녹음 동의 표 | 음성 처리 고지 증빙 | `stock.consents` kind `voice_processing` |
| 공시 소스 허용 표 | 소스별 이용 조건 확인 기록 | 환경변수 `STOCK_RAG_SOURCES`(`disclosure:<확인 기록 id>`) + `docs/legal/data-sources.md`. 청크 `metadata.terms_ref`에 기록 id를 남긴다 |
| 해설집 문서 표 | 원고 관리 | `core.ai_documents`(운영자 지식 조직) + 원고 파일 `content/knowledge/` |

조각은 `core.*`를 ALTER하지 않는다. 14.3절의 `core.plans` UPDATE는 stock 자신의 beta·pro 행 `features`에 AI 키를 병합하는 데이터 변경이며 표 구조는 바꾸지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

리뷰 "높음" 6개 중 #1~#4를 여기에, #5~#6을 `02_ARCHITECTURE.md` 6장에 둔다(합계 6 = 6).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Stock_Trader_nomad.md` 3장 #1 | `docs/reviews/Stock_Trader_nomad.md:39`, `:59` | 증권사 키·토큰·계좌번호 보관 방법이 없고 스크래핑이면 ID/비밀번호·인증서까지 저장하게 된다 | (1) 키·토큰은 `core.encrypted_credentials`(AES-256-GCM, `key_version`, 사용자 SELECT 42501, `migrations/0004_core_security.sql:604-639`)에만. 제품 스키마에 평문 비밀 컬럼 0개. (2) 계좌번호는 `account_masked` CHECK(숫자 5자리 연속 금지, `1900:207`)와 HMAC 해시만. (3) 스크래핑 영구 제외: `broker` CHECK에 API 어댑터만, ID/비밀번호 입력란 없음. (4) 키는 `server-only` 모듈과 워커 메모리에만, 로그 마스킹 유틸 필수, 키 없으면 기동 실패 | `broker_connections`, ST-06-007, ST-06-012 |
| `docs/reviews/Stock_Trader_nomad.md` 3장 #2 | `docs/reviews/Stock_Trader_nomad.md:40`, `:60` | 주문 범위가 정의되지 않았고 모의/실전 구분, 한도, 중복 방지, 장애 정지, 사람 확인이 없다 | (1) MVP·Phase 2는 조회 전용. 주문 테이블은 별도 파일(`0003_stock_orders_paper.sql`)이며 `ORDERS_ENABLED=false`면 코드 경로 없음. (2) `order_requests.env = 'paper'` CHECK와 `broker_connections_orders_paper_check`로 실전 주문 행 불가(`1900:221`, `:743`). (3) 한도 6종(`order_limits`, 상한 CHECK), 멱등(`client_order_id` unique + advisory lock), 상태 머신 트리거, 사람 확인(생성자 본인, 60초), 킬 스위치(전역/조직/연결, 자동은 service만 해제), `order_events` append-only. (4) AI는 주문을 만들 수 없다: 생성 RPC는 service 전용 + 사람 actor 필수 | `order_*`, `kill_switches`, ST-06-032, ST-06-034 |
| `docs/reviews/Stock_Trader_nomad.md` 3장 #3 | `docs/reviews/Stock_Trader_nomad.md:41`, `:61` | 개별 종목 매수가·목표가·손절가 제공과 1:1 포트폴리오 분석은 유사투자자문업·투자자문업 영역이며 면책 고지가 없다 | (1) MVP AI는 상태 진단만, 위험 수준은 서버 규칙. (2) DB `ai_reports_no_price_targets_check`(`1900:325`)가 가격 키를 거부(스모크 23514). (3) 서버 금칙어 검사 → 재생성 1회 → 실패 시 환불. (4) `consents`로 고지·국외 이전 동의를 버전별 증거로 남기고, 미동의면 AI·연결 차단. (5) 초대제 무료 베타, pro는 `is_active=false`로 법률 의견 전 판매 불가 | `ai_reports`, `consents`, ST-06-005, ST-06-021 |
| `docs/reviews/Stock_Trader_nomad.md` 3장 #4 | `docs/reviews/Stock_Trader_nomad.md:42`, `:61` | 타인 다수 증권사 자산 통합은 마이데이터(허가제) 영역이고 스크래핑은 약관 위반·계정 차단 위험 | (1) 초대제 + 제품 게이트 `has_stock_access`: 코어가 `invite` 정책을 강제하지 않아도(가입·`bootstrap_app_for_org` 경로) 초대 수락 없는 조직은 도메인 0행(스모크 C 사용자). (2) 초대 수락은 초대받은 이메일 본인만(`ST031`). (3) 본인 계좌만 연결하는 구조와 동의 체크, 다른 사람 계좌 연결 기능 없음(1인 1워크스페이스). (4) 스크래핑 영구 제외. (5) 마이데이터 해당 여부는 법률 검토 항목으로 남긴다 | `beta_access`, `beta_invites`, ST-06-009 |

## 8. 모놀리스와 모듈러의 차이

`DB_CONVENTIONS.md` 12장 기준.

| 항목 | 모듈러(`1900_stock.sql`) | 모놀리스(`supabase/monolith/`) |
|---|---|---|
| 스키마 | `stock` | `public`(사용자 최종 확인 대기, 01_PRD D-1) |
| 코어 | `core.*` 0000~0006 전부 | `0001_core_lite.sql`. [선택] 절 6-A(oauth_states), 8(Storage), 9(affiliate) 제거, 3(Toss), 4(크레딧), 6-B, 6-C, 7 유지 |
| 파일 | 1개(`@@split` 표시로 1부/2부 구분) | `0002_stock_domain.sql`(1부), `0003_stock_orders_paper.sql`(2부, Phase 3에 적용 가능) |
| apps/plans | 조각 머리의 `@@modular-only` 블록이 등록·보충 | `seed.sql`(default, beta, pro, 종목 샘플) |
| 함수 이름 | `stock.has_stock_access` 등 | `public.has_stock_access` 등(이름 충돌 피하려고 `stock_` 의미를 이름에 포함) |
| 기본 권한 | stock 스키마는 기본 권한 없음 | core-lite SECTION 0이 public 기본 권한 회수. 두 형태 모두 테이블별 `revoke all ... from public, anon, authenticated` 뒤 허용 목록 GRANT |
| Realtime | `schemaname='stock'` | `schemaname='public'` |
| purge GUC | `core.allow_purge` | 같은 GUC 이름(core-lite와 동일) |
| 변환 | 정본 | 조각을 sed 규칙(`core.`/`stock.` → `public.`, `@@modular-only` 삭제, `@@split` 분할)으로 생성. 손으로 고치지 않는다(ST-06-002) |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| 구조 보강(14.1) | 조각 끝 14.1절(kind·동의 kind 확장, advice_check CHECK). 정의 자체는 표 정의에도 반영 | `0002_stock_domain.sql` 끝의 같은 블록(`public.`). 변환 스크립트(ST-06-002)는 14.1을 0002 끝으로, 14.2~14.4를 `seed.sql`로 보낸다 |
| AI 라우팅 기본값 | `1900_stock.sql` 14.2절 | `seed.sql`(같은 12행) |
| 플랜 AI 키 | 14.3절 병합 UPDATE(모듈러 `seed.sql` 반영 요청 06장 6절 R-6) | `seed.sql` beta·pro `features`에 직접 |
| 체인 검사 | 14.4절 DO 블록(제공자 행이 없으면 건너뜀) | `seed.sql` 끝 DO 블록(제공자는 0001이 먼저 넣음) |

## 9. 마이그레이션 파일

| 구분 | 파일 | 내용 |
|---|---|---|
| 모듈러 | `docs/products/_supabase-modular/migrations/1900_stock.sql` | 스키마 `stock`, apps/plans 보충, 테이블 19개, 함수 14개, RLS, 인덱스, Realtime, GRANT, 14절 AI·음성 보강(kind 확장, advice_check CHECK, 라우팅 기본값 12행, 플랜 AI 키, 체인 검사) |
| 모놀리스 | `supabase/monolith/migrations/0001_core_lite.sql` | 코어 축소판 복사본(선택 절 3개 제거, 이유 주석) |
| 모놀리스 | `supabase/monolith/migrations/0002_stock_domain.sql` | 1부: 베타, 동의, 참조, 연결, 동기화, AI, 끝에 14.1 구조 보강 |
| 모놀리스 | `supabase/monolith/migrations/0003_stock_orders_paper.sql` | 2부: 한도, 킬 스위치, 주문, 이벤트, 주문 RPC |
| 모놀리스 | `supabase/monolith/seed.sql` | apps 1행(invite, beta), 플랜 default/beta/pro(pro 비활성, AI 키 포함), 종목 샘플 6개(시세 값 없음), AI 라우팅 기본값 12행 + 체인 검사 |

검증(2026-10-12): `node check.mjs mono 0001 0002 0003 seed` OK, `node check.mjs mod 0000~0007 seed 1900` OK, 두 번 연속 적용(멱등) OK, RLS 스모크 75/75(양쪽).

2026-10-13 재검증(PGlite `--vector`, `docs/products/_tools-sqlcheck/check.mjs`):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `1900_stock.sql` | 전부 OK |
| `check.mjs --vector mono` 0001 + 0002 + 0003 + `seed.sql` | 전부 OK |
| 제품 파일 2회 반복 적용 후 `ai_routing_settings`(org null, app stock) | 12행(모듈러·모놀리스) |
| beta·pro `features` | 기존 키 + `ai_chat`, `ai_chat_turns_per_day`(100/200), `ai_research_per_day`(20/40), `voice_chat`, `briefing` |
| 미동의 조직 `resolve_ai_route` | `stock.research` = oss-llm, `stock.advice_check` = oss-llm, `briefing` tts = oss-voice |
| 동의 후 | `stock.research` = anthropic → openai → google → oss-llm, `briefing` = elevenlabs → oss-voice, `dify.aux`는 oss-llm 하나(강제) |
| `ai_reports` research·briefing 성공 저장(advice_check.passed=true) | 허용 |
| `output.advice_check` 없는 성공 저장, `passed=false`, 가격 키(`target_price`) | `23514` |
| `consents` kind `voice_processing` | 허용, 미지 kind `23514` |

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경은 없다(코어 계약·`1900_stock.sql` 그대로). 정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.2~2.3절이고, 이 절은 stock 제품 훅(`scripts/dev/seed-users.stock.mjs`)이 공통 페르소나에 더하는 것과 invite 앱이라 달라지는 기대 결과를 적는다. 실행은 `supabase db reset` 뒤 `node scripts/dev/seed-users.mjs --app stock`(로컬 Supabase 호스트가 아니면 exit 1). 계정 생성은 `auth.admin.createUser`(가입 트리거 경유), 초대·수락은 실제 경로(service INSERT `beta_invites` + 04장 3절 수락 시퀀스를 수행하는 ST-06-009의 서버 함수)로 한다. 시드는 증권사 연결을 만들지 않는다(`MockBroker` 샘플 연결은 화면의 "샘플 데이터로 둘러보기"로 만든다. 인증 Mock과 다른 개념이다).

invite 앱 차이: 가입 트리거는 stock 엔타이틀먼트를 만들지 않는다(`docs/products/_supabase-modular/migrations/0001_core_identity.sql:152`, 모놀리스 `supabase/monolith/migrations/0001_core_lite.sql:264-269`). 그래서 공통 표의 "`signup_app=<app>`으로 생성 → `entitled=true`"는 이 제품에서 "생성 → 초대 발급 → 수락"이 되어야 성립한다.

| 키 | 이메일 | 만드는 방법(RPC/서비스 경로) | 기대 `session_context('stock')`와 결과 | 쓰임 |
|---|---|---|---|---|
| `owner` | `owner@dev.test` | 생성 → service INSERT `beta_invites`(sha256, 14일) → 수락 시퀀스(`redeem_beta_invite` → 플랜 beta → 300 크레딧) → 본인 세션 `record_consent('investment_disclaimer', DISCLAIMER_VERSION)` | 개인 조직 owner, `entitled=true`, 플랜 beta, 잔액 300, `beta_access.status='active'`. 로그인 → `/dashboard` | 기본 사용자(스모크 A) |
| `fresh_beta` | `fresh_beta@dev.test` | `owner`와 같되 고지 동의 없음 | `entitled=true`, beta. 로그인 → `/onboarding/disclaimer`, API 428 `ST_CONSENT` | 온보딩·동의 리다이렉트 |
| `invitee` | `invitee@dev.test` | 생성 → service INSERT `beta_invites`(issued). 수락하지 않는다. 시드가 초대 링크(`APP_BASE_URL/invite/<token>`)를 1회 출력 | `entitled=false`, `beta_access` 없음. 로그인 → `/no-access`. 출력된 링크로 수락 → beta·300 크레딧(크레딧 1회) | 초대 미수락, 수락 플로우 E2E |
| `beta_revoked` | `beta_revoked@dev.test` | `owner`와 같게 만든 뒤 service `stock.revoke_beta_access` | `entitled=true`, `beta_access.status='revoked'`. 도메인 테이블 0행, API 403 `ST_BETA` | 베타 회수 즉시 차단(ST-F-001) |
| `outsider` | `outsider@dev.test` | `owner`와 같은 방법(별도 개인 조직, 수락·동의 완료) | 자기 조직 owner, beta. `owner` 조직 행 SELECT 0행, 복합 FK `23503` | 교차 테넌트 RLS(스모크 B). `invitee`의 초대 링크로 수락 시도 → `ST031` |
| `no_app` | `no_app@dev.test` | `signup_app` 없이 생성 | 모듈러·모놀리스 모두 `entitled=false`(invite 앱은 모놀리스 자동 부트스트랩에서도 제외). 로그인 → `/no-access`. 본인 `bootstrap_app_for_org('stock')` 호출은 `42501` | 초대 없는 계정(스모크 C) |
| `admin`, `member`, `viewer` | `admin@dev.test` 등 | 생성 → `owner`가 `invite_member(role)` → 각자 `accept_invite` | `owner` 조직의 해당 역할, beta 접근은 조직 단위로 공유 | 역할 분기만(연결 추가·해제 owner/admin, 메모 삭제 owner/admin). 제품 화면에는 멤버 초대가 없다(1인 1워크스페이스, 확정 결정 5) |
| `suspended` | `suspended@dev.test` | `owner`와 같게 만든 뒤 service로 `status=suspended` | 403 | 차단 |
| `ops` | `ops@dev.test` | 생성 후 service로 `platform_role=platform_admin`(엔타이틀먼트 없음) | 운영자. `/admin/beta`, `/admin/ops`, `/admin/wiki` 접근, 도메인 화면은 `/no-access` | 초대 발급 E2E(발급 → 링크 1회 표시) |

`pending` 페르소나는 approval 앱 전용이라 만들지 않는다. 만료 초대 검증용으로 `expired@dev.test` 초대 행(`expires_at`을 과거로, service UPDATE)을 함께 넣는다(계정 없음. 수락 시 410). 멱등: 같은 이메일의 issued 초대가 이미 있으면 새로 발급하지 않고(`beta_invites_open_email_uniq`), 수락된 페르소나는 다시 수락하지 않는다(월 지급 멱등 키로 크레딧 1회). 출력에 비밀번호는 넣지 않는다.
