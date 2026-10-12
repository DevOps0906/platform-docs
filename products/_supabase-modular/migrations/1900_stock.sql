-- =====================================================================
-- 1900_stock.sql
-- stock-dashboard 도메인 (모듈러 통합 DB 조각). 선행: core 0000~0006 (+ seed.sql)
-- 기획서: docs/products/stock-dashboard/05_DATA_MODEL.md
--
-- 원칙
--   - 초대제 베타(apps.signup_policy='invite'). 코어는 'invite' 정책을 강제하지 않으므로
--     (on_signup_app_bootstrap / bootstrap_app_for_org 가 누구에게나 엔타이틀먼트를 만든다)
--     제품이 stock.beta_access 로 2차 게이트를 건다. 모든 도메인 정책은 stock.has_stock_access(org_id).
--   - 증권사 키/토큰은 core.encrypted_credentials 에만. 이 스키마에는 평문 비밀 컬럼이 없다.
--     계좌번호는 마스킹 문자열 + HMAC 해시만 저장한다.
--   - 사용자 쓰기는 trade_notes(순수 메모)만 RLS 로 연다. 나머지는 service_role 또는 SECURITY DEFINER RPC.
--   - 주문은 모의투자(paper)만. env = 'paper' CHECK 로 실전 주문 행 자체가 생길 수 없다.
--     실전 주문은 별도 마이그레이션 + 법률 검토 + 사용자 결정 없이는 열지 않는다.
--   - 상태 전이는 stock.enforce_status_transition() 트리거가 강제한다(22023).
--   - "raise 뒤 UPDATE 롤백" 결함(core confirm_payment_order PM001)을 피하기 위해, 차단/만료는
--     예외가 아니라 상태(blocked/expired)로 기록하고 행을 반환한다.
-- 모놀리스 변환: @@modular-only 블록 삭제, core./stock. -> public., @@split 에서 파일 분할.
-- PostgreSQL 15. 반복 실행 가능.
-- =====================================================================

-- @@modular-only-begin
create schema if not exists stock;
grant usage on schema stock to anon, authenticated, service_role;
alter default privileges in schema stock grant all on tables to service_role;
alter default privileges in schema stock grant all on sequences to service_role;
alter default privileges in schema stock grant execute on functions to service_role;
alter default privileges in schema stock revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy, status)
values ('stock', 'Stock Dashboard', 'stock', 'invite', 'beta')
on conflict (id) do nothing;

-- 기본 플랜(default)은 seed.sql 에 있다. 베타/프로 플랜은 seed 갱신 전까지 이 조각이 보충한다.
-- pro 는 법률 검토 전까지 is_active = false (01_PRD 4장).
insert into core.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('stock', 'beta', 'Beta', 0, 'month', 300, 0, false,
   '{"ai_diagnosis_per_day": 10, "broker_connections_max": 2, "ai_modes": ["quality"], "ai_compare": false, "ideas": false, "leaderboard": false, "paper_orders": false, "history_days": 365}',
   false, true, 1),
  ('stock', 'pro', 'Pro', 9900, 'month', 600, 0, false,
   '{"ai_diagnosis_per_day": 20, "broker_connections_max": 3, "ai_modes": ["fast", "quality"], "ai_compare": true, "ideas": true, "leaderboard": true, "paper_orders": true, "history_days": 730}',
   false, false, 2)
on conflict (app_id, code) do nothing;
-- @@modular-only-end


-- =====================================================================
-- 1. 공용 트리거 함수
-- =====================================================================

-- 상태 전이 강제. 트리거 인자로 허용 전이 목록을 받는다. 'a>b' = a 에서 b 로, '>a' = INSERT 시 초기 상태 a.
create or replace function stock.enforce_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not (('>' || new.status) = any (tg_argv)) then
      raise exception '%.%: invalid initial status %', tg_table_schema, tg_table_name, new.status using errcode = '22023';
    end if;
  elsif new.status is distinct from old.status then
    if not ((old.status || '>' || new.status) = any (tg_argv)) then
      raise exception '%.%: invalid transition % -> %', tg_table_schema, tg_table_name, old.status, new.status using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;

-- append-only 로그. DELETE 는 조직 영구 삭제(core.purge_organization 의 core.allow_purge GUC) 안에서만.
create or replace function stock.reject_log_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and core.is_privileged_session() then
    return old;
  end if;
  raise exception '%.% is append-only (%)', tg_table_schema, tg_table_name, tg_op using errcode = 'ST000';
end;
$$;


-- =====================================================================
-- 2. 베타 초대와 접근 게이트
-- =====================================================================

create table if not exists stock.beta_invites (
  id               uuid primary key default gen_random_uuid(),
  email_normalized text not null
                   constraint beta_invites_email_check check (email_normalized = lower(btrim(email_normalized)) and position('@' in email_normalized) > 1),
  token_hash       text not null unique
                   constraint beta_invites_token_hash_check check (token_hash ~ '^[0-9a-f]{64}$'),
  status           text not null default 'issued'
                   constraint beta_invites_status_check check (status in ('issued', 'accepted', 'revoked', 'expired')),
  expires_at       timestamptz not null default (now() + interval '14 days'),
  invited_by       uuid,
  accepted_user_id uuid,
  accepted_org_id  uuid references core.organizations(id) on delete set null,
  accepted_at      timestamptz,
  revoked_at       timestamptz,
  note             text constraint beta_invites_note_check check (note is null or char_length(note) <= 200),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index if not exists beta_invites_open_email_uniq on stock.beta_invites (email_normalized) where status = 'issued';

create table if not exists stock.beta_access (
  org_id        uuid primary key references core.organizations(id) on delete cascade,
  invite_id     uuid references stock.beta_invites(id) on delete set null,
  status        text not null default 'active'
                constraint beta_access_status_check check (status in ('active', 'revoked')),
  granted_at    timestamptz not null default now(),
  granted_by    uuid,
  revoked_at    timestamptz,
  revoke_reason text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 도메인 RLS 의 단일 판정. 멤버 + 엔타이틀먼트 + 베타 접근(초대 수락) 세 조건.
create or replace function stock.has_stock_access(org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select org is not null
     and core.is_org_member(org)
     and core.has_entitlement(org, 'stock')
     and exists (select 1 from stock.beta_access b where b.org_id = org and b.status = 'active');
$$;


-- =====================================================================
-- 3. 참조 데이터 (전역, 조직 무관): 종목 마스터, 재무지표, 일봉(내부 전용), 장 운영 캘린더
-- =====================================================================

create table if not exists stock.instruments (
  symbol      text primary key constraint instruments_symbol_check check (symbol ~ '^[0-9A-Z]{6}$'),
  name        text not null,
  market      text not null constraint instruments_market_check check (market in ('KOSPI', 'KOSDAQ', 'KONEX', 'ETF', 'ETN', 'INDEX')),
  sector      text,
  is_active   boolean not null default true,
  listed_on   date,
  delisted_on date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists stock.fundamentals (
  id                 bigint generated always as identity primary key,
  symbol             text not null references stock.instruments(symbol) on delete cascade,
  fiscal_period      text not null constraint fundamentals_period_check check (fiscal_period ~ '^[0-9]{4}(Q[1-4]|FY)$'),
  per                numeric(10,2),
  pbr                numeric(10,2),
  roe_pct            numeric(8,2),
  eps_krw            numeric(14,0),
  dividend_yield_pct numeric(6,2),
  source             text not null constraint fundamentals_source_check check (source in ('dart', 'broker', 'manual')),
  source_ref         text,
  as_of              date not null,
  computed_at        timestamptz not null default now(),
  unique (symbol, fiscal_period, source)
);

-- 일봉은 성과 계산 전용. 사용자에게 GRANT 하지 않는다(시세 재배포 제한, 01_PRD 6장).
create table if not exists stock.daily_prices (
  symbol     text not null references stock.instruments(symbol) on delete cascade,
  trade_date date not null,
  open       numeric(18,2),
  high       numeric(18,2),
  low        numeric(18,2),
  close      numeric(18,2) not null constraint daily_prices_close_check check (close > 0),
  volume     bigint,
  source     text not null constraint daily_prices_source_check check (source in ('broker', 'krx', 'mock')),
  created_at timestamptz not null default now(),
  primary key (symbol, trade_date)
);

create table if not exists stock.market_calendar (
  trade_date date primary key,
  is_open    boolean not null,
  open_at    timestamptz,
  close_at   timestamptz,
  note       text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint market_calendar_hours_check check (not is_open or (open_at is not null and close_at is not null and open_at < close_at))
);


-- =====================================================================
-- 4. 증권사 연결과 동기화 결과 (service_role 쓰기 전용)
-- =====================================================================

create table if not exists stock.broker_connections (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  broker             text not null constraint broker_connections_broker_check check (broker in ('mock', 'kis', 'kiwoom', 'hana')),
  env                text not null default 'paper' constraint broker_connections_env_check check (env in ('paper', 'live')),
  label              text constraint broker_connections_label_check check (label is null or char_length(label) <= 40),
  account_masked     text not null
                     constraint broker_connections_account_masked_check check (account_masked ~ '^[0-9*-]{4,24}$' and account_masked ~ '[*]' and account_masked !~ '[0-9]{5,}'),
  account_ref_hash   text not null constraint broker_connections_account_ref_check check (account_ref_hash ~ '^[0-9a-f]{64}$'),
  credential_id      uuid references core.encrypted_credentials(id) on delete set null,
  status             text not null default 'pending'
                     constraint broker_connections_status_check check (status in ('pending', 'active', 'error', 'revoked')),
  orders_enabled     boolean not null default false,
  last_synced_at     timestamptz,
  last_error_code    text,
  consecutive_errors integer not null default 0 constraint broker_connections_errors_check check (consecutive_errors >= 0),
  created_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (id, org_id),
  unique (org_id, broker, env, account_ref_hash),
  constraint broker_connections_orders_paper_check check (not orders_enabled or env = 'paper'),
  constraint broker_connections_mock_paper_check check (broker <> 'mock' or env = 'paper'),
  constraint broker_connections_credential_check check (broker = 'mock' or status in ('pending', 'revoked') or credential_id is not null)
);

create table if not exists stock.balance_snapshots (
  id            bigint generated always as identity primary key,
  org_id        uuid not null references core.organizations(id) on delete cascade,
  connection_id uuid not null,
  captured_at   timestamptz not null default now(),
  cash_krw      numeric(18,0) not null default 0,
  purchase_krw  numeric(18,0) not null default 0 constraint balance_snapshots_purchase_check check (purchase_krw >= 0),
  eval_krw      numeric(18,0) not null default 0 constraint balance_snapshots_eval_check check (eval_krw >= 0),
  pnl_krw       numeric(18,0) generated always as (eval_krw - purchase_krw) stored,
  is_sample     boolean not null default false,
  source        text not null default 'sync' constraint balance_snapshots_source_check check (source in ('sync', 'mock')),
  foreign key (connection_id, org_id) references stock.broker_connections(id, org_id) on delete cascade
);

create table if not exists stock.holdings (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  connection_id uuid not null,
  symbol        text not null constraint holdings_symbol_check check (symbol ~ '^[0-9A-Z]{6}$'),
  name          text not null,
  quantity      numeric(18,4) not null constraint holdings_quantity_check check (quantity >= 0),
  avg_price     numeric(18,2) not null constraint holdings_avg_price_check check (avg_price >= 0),
  purchase_krw  numeric(18,0) not null constraint holdings_purchase_check check (purchase_krw >= 0),
  is_sample     boolean not null default false,
  synced_at     timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (connection_id, symbol),
  foreign key (connection_id, org_id) references stock.broker_connections(id, org_id) on delete cascade
);

create table if not exists stock.trades (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  connection_id  uuid not null,
  broker_exec_id text not null,
  symbol         text not null constraint trades_symbol_check check (symbol ~ '^[0-9A-Z]{6}$'),
  name           text not null,
  side           text not null constraint trades_side_check check (side in ('buy', 'sell')),
  quantity       numeric(18,4) not null constraint trades_quantity_check check (quantity > 0),
  price          numeric(18,2) not null constraint trades_price_check check (price >= 0),
  amount_krw     numeric(18,0) not null,
  fee_krw        numeric(18,0) not null default 0,
  tax_krw        numeric(18,0) not null default 0,
  executed_at    timestamptz not null,
  is_sample      boolean not null default false,
  synced_at      timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (id, org_id),
  unique (connection_id, broker_exec_id),
  foreign key (connection_id, org_id) references stock.broker_connections(id, org_id) on delete cascade
);

-- 사용자가 직접 쓰는 유일한 도메인 테이블(순수 메모, 돈/권한/상태 컬럼 없음)
create table if not exists stock.trade_notes (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  trade_id   uuid not null,
  body       text not null constraint trade_notes_body_check check (char_length(body) between 1 and 2000),
  tags       text[] not null default '{}' constraint trade_notes_tags_check check (cardinality(tags) <= 10),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (trade_id, org_id) references stock.trades(id, org_id) on delete cascade
);


-- =====================================================================
-- 5. AI 진단 리포트와 성과 평가 (service_role 쓰기 전용)
-- =====================================================================

create table if not exists stock.ai_reports (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  kind                text not null default 'diagnosis' constraint ai_reports_kind_check check (kind in ('diagnosis', 'idea')),
  scope_connection_id uuid,
  status              text not null default 'queued'
                      constraint ai_reports_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  mode                text not null default 'quality' constraint ai_reports_mode_check check (mode in ('fast', 'quality')),
  provider            text,
  model               text,
  prompt_version      text not null,
  input_hash          text not null constraint ai_reports_input_hash_check check (input_hash ~ '^[0-9a-f]{64}$'),
  input_summary       jsonb not null default '{}'::jsonb,
  output              jsonb,
  disclaimer_version  text not null,
  credits_charged     integer not null default 0 constraint ai_reports_credits_check check (credits_charged >= 0),
  credit_ledger_id    bigint references core.credit_ledger(id),
  request_id          uuid not null unique,
  error_code          text,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  started_at          timestamptz,
  finished_at         timestamptz,
  updated_at          timestamptz not null default now(),
  unique (id, org_id),
  foreign key (scope_connection_id, org_id) references stock.broker_connections(id, org_id) on delete set null (scope_connection_id),
  -- MVP 진단은 매수가/목표가/손절가를 저장할 수 없다(리뷰 #3). 키 이름 수준의 마지막 방어선.
  constraint ai_reports_no_price_targets_check check (
    output is null or output::text !~* '"(buy_price|entry_price|target_price|stop_price|stop_loss)"[[:space:]]*:'
  ),
  constraint ai_reports_output_status_check check (status <> 'succeeded' or output is not null)
);

create table if not exists stock.ai_report_items (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  report_id       uuid not null,
  symbol          text not null constraint ai_report_items_symbol_check check (symbol ~ '^[0-9A-Z]{6}$'),
  risk_level      text not null constraint ai_report_items_risk_check check (risk_level in ('low', 'medium', 'high')),
  weight_pct      numeric(6,2) constraint ai_report_items_weight_check check (weight_pct is null or weight_pct between 0 and 100),
  factors         jsonb not null default '[]'::jsonb constraint ai_report_items_factors_check check (jsonb_typeof(factors) = 'array'),
  rationale       text constraint ai_report_items_rationale_check check (rationale is null or char_length(rationale) <= 1000),
  reference_price numeric(18,2) constraint ai_report_items_ref_price_check check (reference_price is null or reference_price > 0),
  reference_at    timestamptz,
  created_at      timestamptz not null default now(),
  unique (id, org_id),
  unique (report_id, symbol),
  foreign key (report_id, org_id) references stock.ai_reports(id, org_id) on delete cascade
);

-- Phase 2: 아이디어 성과(내부 리더보드). 계산 규칙은 01_PRD ST-F-013, rule_version 으로 고정.
create table if not exists stock.idea_evaluations (
  id                   bigint generated always as identity primary key,
  org_id               uuid not null references core.organizations(id) on delete cascade,
  item_id              uuid not null,
  horizon_days         smallint not null constraint idea_evaluations_horizon_check check (horizon_days in (5, 20, 60)),
  entry_date           date not null,
  entry_price          numeric(18,2) not null constraint idea_evaluations_entry_check check (entry_price > 0),
  eval_date            date not null,
  eval_price           numeric(18,2) not null constraint idea_evaluations_eval_check check (eval_price > 0),
  return_pct           numeric(9,4) not null,
  benchmark_return_pct numeric(9,4) not null,
  excess_pct           numeric(9,4) generated always as (return_pct - benchmark_return_pct) stored,
  rule_version         text not null,
  computed_at          timestamptz not null default now(),
  unique (item_id, horizon_days),
  constraint idea_evaluations_dates_check check (eval_date > entry_date),
  foreign key (item_id, org_id) references stock.ai_report_items(id, org_id) on delete cascade
);


-- =====================================================================
-- 6. 트리거 (updated_at, 상태 전이, 쓰기 보호)
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array['beta_invites', 'beta_access', 'instruments', 'market_calendar', 'broker_connections',
                           'holdings', 'trades', 'trade_notes', 'ai_reports']
  loop
    execute format('drop trigger if exists %I_set_updated_at on stock.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on stock.%I for each row execute function core.set_updated_at()', t, t);
  end loop;
  -- trade_notes 를 뺀 전 테이블: 사용자 세션 쓰기 거부(이중 잠금)
  foreach t in array array['beta_invites', 'beta_access', 'instruments', 'fundamentals', 'daily_prices', 'market_calendar',
                           'broker_connections', 'balance_snapshots', 'holdings', 'trades',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('drop trigger if exists %I_guard_write on stock.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on stock.%I for each row execute function core.guard_privileged_write()', t, t);
  end loop;
end $$;

drop trigger if exists beta_invites_status_transition on stock.beta_invites;
create trigger beta_invites_status_transition before insert or update of status on stock.beta_invites
  for each row execute function stock.enforce_status_transition(
    '>issued', 'issued>accepted', 'issued>revoked', 'issued>expired');

drop trigger if exists beta_access_status_transition on stock.beta_access;
create trigger beta_access_status_transition before insert or update of status on stock.beta_access
  for each row execute function stock.enforce_status_transition(
    '>active', 'active>revoked', 'revoked>active');

drop trigger if exists broker_connections_status_transition on stock.broker_connections;
create trigger broker_connections_status_transition before insert or update of status on stock.broker_connections
  for each row execute function stock.enforce_status_transition(
    '>pending', '>active', 'pending>active', 'pending>error', 'pending>revoked',
    'active>error', 'active>revoked', 'error>active', 'error>revoked');

drop trigger if exists ai_reports_status_transition on stock.ai_reports;
create trigger ai_reports_status_transition before insert or update of status on stock.ai_reports
  for each row execute function stock.enforce_status_transition(
    '>queued', 'queued>running', 'queued>canceled', 'queued>failed', 'running>succeeded', 'running>failed');


-- =====================================================================
-- 7. RPC (베타 초대)
-- =====================================================================

-- 초대 수락: service_role 전용. 서버가 토큰 원문을 sha256 으로 바꿔 넘긴다(원문은 DB 에 없다).
-- 플랜 전환(default -> beta)과 첫 달 크레딧은 서버가 코어 경로로 처리한다(04_API 3장).
create or replace function stock.redeem_beta_invite(p_token_hash text, p_user_id uuid)
returns stock.beta_access
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv   stock.beta_invites;
  v_email text;
  v_org   uuid;
  v_row   stock.beta_access;
begin
  if not core.is_privileged_session() then
    raise exception 'redeem_beta_invite: service_role only' using errcode = '42501';
  end if;
  select * into v_inv from stock.beta_invites where token_hash = p_token_hash for update;
  if not found then
    raise exception 'redeem_beta_invite: invite not found' using errcode = 'ST030';
  end if;
  if v_inv.status = 'issued' and v_inv.expires_at <= now() then
    update stock.beta_invites set status = 'expired' where id = v_inv.id;
    return null;                         -- 예외 대신 상태를 남기고 null 반환(롤백 방지)
  end if;
  if v_inv.status <> 'issued' then
    raise exception 'redeem_beta_invite: invite is %', v_inv.status using errcode = 'ST030';
  end if;
  select lower(p.email) into v_email from core.profiles p where p.id = p_user_id;
  if v_email is null or v_email <> v_inv.email_normalized then
    raise exception 'redeem_beta_invite: email mismatch' using errcode = 'ST031';
  end if;
  select o.id into v_org from core.organizations o
  where o.owner_id = p_user_id and o.is_personal and o.deleted_at is null
  order by o.created_at limit 1;
  if v_org is null then
    raise exception 'redeem_beta_invite: no personal organization' using errcode = 'P0002';
  end if;

  update stock.beta_invites
     set status = 'accepted', accepted_user_id = p_user_id, accepted_org_id = v_org, accepted_at = now()
   where id = v_inv.id;

  insert into stock.beta_access (org_id, invite_id, status, granted_at, granted_by)
  values (v_org, v_inv.id, 'active', now(), v_inv.invited_by)
  on conflict (org_id) do update
    set status = 'active', invite_id = excluded.invite_id, granted_at = now(), revoked_at = null, revoke_reason = null
  returning * into v_row;

  insert into core.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, after)
  values (v_org, p_user_id, 'service', 'stock.beta.accept', 'beta_invite', v_inv.id::text,
          jsonb_build_object('org_id', v_org));
  return v_row;
end;
$$;

-- 베타 회수: service_role 전용(운영자 화면 -> 서버). 회수하면 모든 도메인 정책이 즉시 0행이 된다.
create or replace function stock.revoke_beta_access(p_org_id uuid, p_reason text)
returns stock.beta_access
language plpgsql
security definer
set search_path = ''
as $$
declare v_row stock.beta_access;
begin
  if not core.is_privileged_session() then
    raise exception 'revoke_beta_access: service_role only' using errcode = '42501';
  end if;
  update stock.beta_access
     set status = 'revoked', revoked_at = now(), revoke_reason = left(coalesce(p_reason, ''), 200)
   where org_id = p_org_id and status = 'active'
  returning * into v_row;
  if found then
    insert into core.audit_log (org_id, actor_role, action, target_type, target_id, metadata)
    values (p_org_id, 'service', 'stock.beta.revoke', 'organization', p_org_id::text,
            jsonb_build_object('reason', left(coalesce(p_reason, ''), 200)));
  end if;
  return v_row;
end;
$$;


-- =====================================================================
-- 8. RLS (1부: 조회/동기화/AI)
-- =====================================================================

alter table stock.beta_invites       enable row level security;
alter table stock.beta_access        enable row level security;
alter table stock.instruments        enable row level security;
alter table stock.fundamentals       enable row level security;
alter table stock.daily_prices       enable row level security;
alter table stock.market_calendar    enable row level security;
alter table stock.broker_connections enable row level security;
alter table stock.balance_snapshots  enable row level security;
alter table stock.holdings           enable row level security;
alter table stock.trades             enable row level security;
alter table stock.trade_notes        enable row level security;
alter table stock.ai_reports         enable row level security;
alter table stock.ai_report_items    enable row level security;
alter table stock.idea_evaluations   enable row level security;

-- beta_invites, daily_prices: 정책 없음(= 사용자 전면 거부). service_role 만.

drop policy if exists beta_access_select on stock.beta_access;
create policy beta_access_select on stock.beta_access for select to authenticated
  using (core.is_org_member(org_id));

drop policy if exists instruments_select on stock.instruments;
create policy instruments_select on stock.instruments for select to authenticated using (true);
drop policy if exists fundamentals_select on stock.fundamentals;
create policy fundamentals_select on stock.fundamentals for select to authenticated using (true);
drop policy if exists market_calendar_select on stock.market_calendar;
create policy market_calendar_select on stock.market_calendar for select to authenticated using (true);

do $$
declare t text;
begin
  foreach t in array array['broker_connections', 'balance_snapshots', 'holdings', 'trades',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('drop policy if exists %I_select on stock.%I', t, t);
    execute format('create policy %I_select on stock.%I for select to authenticated using (stock.has_stock_access(org_id))', t, t);
  end loop;
end $$;

drop policy if exists trade_notes_select on stock.trade_notes;
create policy trade_notes_select on stock.trade_notes for select to authenticated
  using (stock.has_stock_access(org_id));
drop policy if exists trade_notes_insert on stock.trade_notes;
create policy trade_notes_insert on stock.trade_notes for insert to authenticated
  with check (stock.has_stock_access(org_id) and created_by = auth.uid());
drop policy if exists trade_notes_update on stock.trade_notes;
create policy trade_notes_update on stock.trade_notes for update to authenticated
  using (stock.has_stock_access(org_id) and created_by = auth.uid())
  with check (stock.has_stock_access(org_id) and created_by = auth.uid());
drop policy if exists trade_notes_delete on stock.trade_notes;
create policy trade_notes_delete on stock.trade_notes for delete to authenticated
  using (stock.has_stock_access(org_id)
         and (created_by = auth.uid() or core.has_org_role(org_id, array['owner', 'admin'])));


-- =====================================================================
-- 8-B. 동의 기록 (투자 고지, AI 국외 이전, 모의주문 위험). append-only, RPC 로만 기록.
-- =====================================================================

create table if not exists stock.consents (
  id          bigint generated always as identity primary key,
  org_id      uuid not null references core.organizations(id) on delete cascade,
  user_id     uuid not null,
  kind        text not null constraint consents_kind_check check (kind in ('investment_disclaimer', 'ai_overseas_transfer', 'paper_order_risk')),
  version     text not null constraint consents_version_check check (version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}(\.[0-9]+)?$'),
  accepted_at timestamptz not null default now(),
  unique (org_id, user_id, kind, version)
);
alter table stock.consents enable row level security;
drop trigger if exists consents_guard_write on stock.consents;
create trigger consents_guard_write before insert or update or delete on stock.consents
  for each row execute function core.guard_privileged_write();
drop trigger if exists consents_immutable on stock.consents;
create trigger consents_immutable before update or delete on stock.consents
  for each row execute function stock.reject_log_mutation();
drop policy if exists consents_select on stock.consents;
create policy consents_select on stock.consents for select to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id));
create index if not exists consents_user_kind_idx on stock.consents (user_id, kind, accepted_at desc);

-- 본인 동의만 기록. 베타 접근(has_stock_access)이 있는 조직에서만. 같은 버전 재동의는 기존 행 반환.
create or replace function stock.record_consent(p_org_id uuid, p_kind text, p_version text)
returns stock.consents
language plpgsql
security definer
set search_path = ''
as $$
declare v_row stock.consents;
begin
  if auth.uid() is null then
    raise exception 'record_consent: user session required' using errcode = '42501';
  end if;
  if not core.is_service_caller() and not stock.has_stock_access(p_org_id) then
    raise exception 'record_consent: no stock access' using errcode = '42501';
  end if;
  insert into stock.consents (org_id, user_id, kind, version)
  values (p_org_id, auth.uid(), p_kind, p_version)
  on conflict (org_id, user_id, kind, version) do nothing
  returning * into v_row;
  if v_row.id is null then
    select * into v_row from stock.consents
    where org_id = p_org_id and user_id = auth.uid() and kind = p_kind and version = p_version;
  end if;
  return v_row;
end;
$$;
revoke all on table stock.consents from public, anon, authenticated;
grant all on table stock.consents to service_role;
grant select on table stock.consents to authenticated;
revoke all on function stock.record_consent(uuid, text, text) from public, anon;
grant execute on function stock.record_consent(uuid, text, text) to authenticated, service_role;


-- =====================================================================
-- 9. 인덱스, Realtime
-- =====================================================================

create index if not exists broker_connections_org_idx on stock.broker_connections (org_id) where status <> 'revoked';
create index if not exists balance_snapshots_conn_captured_idx on stock.balance_snapshots (connection_id, captured_at desc);
create index if not exists balance_snapshots_org_captured_idx on stock.balance_snapshots (org_id, captured_at desc);
create index if not exists holdings_org_idx on stock.holdings (org_id);
create index if not exists trades_org_executed_idx on stock.trades (org_id, executed_at desc);
create index if not exists trades_org_symbol_idx on stock.trades (org_id, symbol, executed_at desc);
create index if not exists trade_notes_trade_idx on stock.trade_notes (trade_id);
create index if not exists ai_reports_org_created_idx on stock.ai_reports (org_id, created_at desc);
create index if not exists ai_reports_org_day_idx on stock.ai_reports (org_id, kind, created_at) where status in ('queued', 'running', 'succeeded');
create index if not exists idea_evaluations_org_idx on stock.idea_evaluations (org_id, horizon_days);
create index if not exists fundamentals_symbol_idx on stock.fundamentals (symbol, as_of desc);
create index if not exists daily_prices_date_idx on stock.daily_prices (trade_date);
create index if not exists beta_invites_expiry_idx on stock.beta_invites (expires_at) where status = 'issued';

do $$
declare t text;
begin
  foreach t in array array['holdings', 'balance_snapshots', 'ai_reports', 'broker_connections']
  loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'stock' and tablename = t) then
      execute format('alter publication supabase_realtime add table stock.%I', t);
    end if;
  end loop;
end $$;


-- =====================================================================
-- 10. 권한 (1부). RLS 는 권한을 대신하지 않는다. 회수 후 허용 목록만.
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array['beta_invites', 'beta_access', 'instruments', 'fundamentals', 'daily_prices', 'market_calendar',
                           'broker_connections', 'balance_snapshots', 'holdings', 'trades', 'trade_notes',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('revoke all on table stock.%I from public, anon, authenticated', t);
    execute format('grant all on table stock.%I to service_role', t);
  end loop;
  foreach t in array array['beta_access', 'instruments', 'fundamentals', 'market_calendar',
                           'broker_connections', 'balance_snapshots', 'holdings', 'trades', 'trade_notes',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('grant select on table stock.%I to authenticated', t);
  end loop;
end $$;
grant insert (org_id, trade_id, body, tags) on stock.trade_notes to authenticated;
grant update (body, tags) on stock.trade_notes to authenticated;
grant delete on stock.trade_notes to authenticated;

revoke all on function stock.enforce_status_transition() from public, anon, authenticated;
revoke all on function stock.reject_log_mutation() from public, anon, authenticated;
revoke all on function stock.has_stock_access(uuid) from public, anon;
grant execute on function stock.has_stock_access(uuid) to authenticated, service_role;
revoke all on function stock.redeem_beta_invite(text, uuid) from public, anon, authenticated;
grant execute on function stock.redeem_beta_invite(text, uuid) to service_role;
revoke all on function stock.revoke_beta_access(uuid, text) from public, anon, authenticated;
grant execute on function stock.revoke_beta_access(uuid, text) to service_role;


-- @@split 0003_stock_orders_paper.sql
-- =====================================================================
-- 11. 모의투자 주문 안전장치 (Phase 3. 테이블은 지금 만들되 앱 코드 경로는 Phase 3 전까지 없다)
--     - env = 'paper' CHECK: 실전 주문 행 불가
--     - 한도(order_limits), 킬 스위치(kill_switches), 멱등(client_order_id unique),
--       사람 확인(pending_confirm -> confirmed, 60초 만료, 생성자 본인만), 변경 불가 이벤트 로그(order_events)
--     - AI 는 주문을 만들지 않는다: 주문 생성 RPC 는 service_role 전용이고 actor(사람) 필수,
--       prefill_report_id 는 출처 기록일 뿐이며 확인 단계를 건너뛰지 못한다.
-- =====================================================================

create table if not exists stock.order_limits (
  org_id                  uuid primary key references core.organizations(id) on delete cascade,
  max_order_krw           integer not null default 1000000
                          constraint order_limits_max_order_check check (max_order_krw between 10000 and 10000000),
  max_daily_krw           bigint not null default 5000000
                          constraint order_limits_max_daily_check check (max_daily_krw between 10000 and 50000000),
  max_orders_per_day      integer not null default 20
                          constraint order_limits_max_orders_check check (max_orders_per_day between 1 and 100),
  max_position_weight_pct numeric(5,2) not null default 30
                          constraint order_limits_weight_check check (max_position_weight_pct between 1 and 100),
  max_price_deviation_pct numeric(5,2) not null default 5
                          constraint order_limits_deviation_check check (max_price_deviation_pct between 0.5 and 10),
  max_quote_age_seconds   integer not null default 10
                          constraint order_limits_quote_age_check check (max_quote_age_seconds between 1 and 60),
  updated_by              uuid,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint order_limits_daily_ge_order_check check (max_daily_krw >= max_order_krw)
);

create table if not exists stock.kill_switches (
  id             uuid primary key default gen_random_uuid(),
  scope          text not null constraint kill_switches_scope_check check (scope in ('global', 'org', 'connection')),
  org_id         uuid references core.organizations(id) on delete cascade,
  connection_id  uuid references stock.broker_connections(id) on delete cascade,
  is_active      boolean not null default true,
  trigger_source text not null default 'manual'
                 constraint kill_switches_source_check check (trigger_source in ('manual', 'ops', 'auto_quote_stale', 'auto_broker_errors', 'auto_balance_mismatch')),
  reason         text not null constraint kill_switches_reason_check check (char_length(reason) between 1 and 200),
  engaged_by     uuid,
  engaged_at     timestamptz not null default now(),
  released_by    uuid,
  released_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint kill_switches_target_check check (
       (scope = 'global' and org_id is null and connection_id is null)
    or (scope = 'org' and org_id is not null and connection_id is null)
    or (scope = 'connection' and org_id is not null and connection_id is not null)),
  constraint kill_switches_release_check check (is_active or released_at is not null)
);
create unique index if not exists kill_switches_one_active_idx on stock.kill_switches
  (scope, coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(connection_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where is_active;

create table if not exists stock.order_requests (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  connection_id     uuid not null,
  client_order_id   uuid not null unique,
  env               text not null default 'paper' constraint order_requests_env_check check (env = 'paper'),
  symbol            text not null constraint order_requests_symbol_check check (symbol ~ '^[0-9A-Z]{6}$'),
  side              text not null constraint order_requests_side_check check (side in ('buy', 'sell')),
  order_type        text not null default 'limit' constraint order_requests_type_check check (order_type = 'limit'),
  quantity          integer not null constraint order_requests_quantity_check check (quantity > 0),
  limit_price       numeric(18,2) not null constraint order_requests_limit_price_check check (limit_price > 0),
  est_amount_krw    numeric(18,0) generated always as (round(quantity * limit_price)) stored,
  ref_price         numeric(18,2) not null constraint order_requests_ref_price_check check (ref_price > 0),
  ref_price_at      timestamptz not null,
  status            text not null default 'pending_confirm'
                    constraint order_requests_status_check check (status in ('pending_confirm', 'confirmed', 'submitted', 'accepted',
                      'partially_filled', 'filled', 'rejected', 'canceled', 'expired', 'blocked', 'failed')),
  limit_check       jsonb not null default '{}'::jsonb,
  block_reason      text,
  confirm_expires_at timestamptz not null,
  confirmed_at      timestamptz,
  confirmed_by      uuid,
  submitted_at      timestamptz,
  broker_order_id   text,
  filled_quantity   integer not null default 0 constraint order_requests_filled_check check (filled_quantity >= 0 and filled_quantity <= quantity),
  avg_fill_price    numeric(18,2),
  prefill_report_id uuid,
  created_by        uuid not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  unique (connection_id, broker_order_id),
  foreign key (connection_id, org_id) references stock.broker_connections(id, org_id) on delete cascade,
  constraint order_requests_confirm_check check (status not in ('confirmed', 'submitted', 'accepted', 'partially_filled', 'filled')
                                                 or (confirmed_at is not null and confirmed_by is not null)),
  constraint order_requests_block_check check (status <> 'blocked' or block_reason is not null)
);

create table if not exists stock.order_events (
  id          bigint generated always as identity primary key,
  org_id      uuid not null references core.organizations(id) on delete cascade,
  order_id    uuid not null,
  event       text not null constraint order_events_event_check check (event in ('created', 'blocked', 'confirmed', 'expired', 'canceled',
                'submitted', 'broker_response', 'accepted', 'partially_filled', 'filled', 'rejected', 'failed')),
  from_status text,
  to_status   text,
  detail      jsonb not null default '{}'::jsonb,
  actor_id    uuid,
  actor_role  text not null constraint order_events_actor_check check (actor_role in ('user', 'service', 'system')),
  created_at  timestamptz not null default now(),
  foreign key (order_id, org_id) references stock.order_requests(id, org_id) on delete cascade
);

do $$
declare t text;
begin
  foreach t in array array['order_limits', 'kill_switches', 'order_requests']
  loop
    execute format('drop trigger if exists %I_set_updated_at on stock.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on stock.%I for each row execute function core.set_updated_at()', t, t);
  end loop;
  foreach t in array array['order_limits', 'kill_switches', 'order_requests', 'order_events']
  loop
    execute format('drop trigger if exists %I_guard_write on stock.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on stock.%I for each row execute function core.guard_privileged_write()', t, t);
  end loop;
end $$;

drop trigger if exists order_requests_status_transition on stock.order_requests;
create trigger order_requests_status_transition before insert or update of status on stock.order_requests
  for each row execute function stock.enforce_status_transition(
    '>pending_confirm', '>blocked',
    'pending_confirm>confirmed', 'pending_confirm>expired', 'pending_confirm>canceled', 'pending_confirm>blocked',
    'confirmed>submitted', 'confirmed>blocked', 'confirmed>failed',
    'submitted>accepted', 'submitted>rejected', 'submitted>failed',
    'accepted>partially_filled', 'accepted>filled', 'accepted>canceled', 'accepted>rejected',
    'partially_filled>partially_filled', 'partially_filled>filled', 'partially_filled>canceled');

drop trigger if exists order_events_immutable on stock.order_events;
create trigger order_events_immutable before update or delete on stock.order_events
  for each row execute function stock.reject_log_mutation();

-- 킬 스위치 판정(전역 > 조직 > 연결). 내부/서버용.
create or replace function stock.is_trading_blocked(p_org_id uuid, p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from stock.kill_switches k
    where k.is_active
      and (k.scope = 'global'
           or (k.scope = 'org' and k.org_id = p_org_id)
           or (k.scope = 'connection' and k.connection_id = p_connection_id))
  );
$$;

-- 한도 설정: owner/admin. 범위는 CHECK 가 강제(플랫폼 상한). 사용자 RPC 이므로 is_service_caller 사용(규칙 1).
create or replace function stock.set_order_limits(
  p_org_id                  uuid,
  p_max_order_krw           integer,
  p_max_daily_krw           bigint,
  p_max_orders_per_day      integer,
  p_max_position_weight_pct numeric,
  p_max_price_deviation_pct numeric
)
returns stock.order_limits
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before stock.order_limits;
  v_row    stock.order_limits;
begin
  if not core.is_service_caller() then
    if not stock.has_stock_access(p_org_id) or not core.has_org_role(p_org_id, array['owner', 'admin']) then
      raise exception 'set_order_limits: owner/admin with stock access only' using errcode = '42501';
    end if;
  end if;
  select * into v_before from stock.order_limits where org_id = p_org_id for update;
  insert into stock.order_limits (org_id, max_order_krw, max_daily_krw, max_orders_per_day,
                                  max_position_weight_pct, max_price_deviation_pct, updated_by)
  values (p_org_id, p_max_order_krw, p_max_daily_krw, p_max_orders_per_day,
          p_max_position_weight_pct, p_max_price_deviation_pct, auth.uid())
  on conflict (org_id) do update
    set max_order_krw = excluded.max_order_krw, max_daily_krw = excluded.max_daily_krw,
        max_orders_per_day = excluded.max_orders_per_day, max_position_weight_pct = excluded.max_position_weight_pct,
        max_price_deviation_pct = excluded.max_price_deviation_pct, updated_by = excluded.updated_by
  returning * into v_row;
  perform core.write_audit(p_org_id, 'stock.order_limits.update', 'organization', p_org_id::text,
                           to_jsonb(v_before), to_jsonb(v_row));
  return v_row;
end;
$$;

-- 킬 스위치 작동: 조직의 활성 멤버 누구나(멈추는 쪽은 항상 허용). 대기/확인 주문을 즉시 무효화한다.
create or replace function stock.engage_kill_switch(p_org_id uuid, p_connection_id uuid default null, p_reason text default 'manual stop')
returns stock.kill_switches
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   stock.kill_switches;
  v_scope text := case when p_connection_id is null then 'org' else 'connection' end;
  v_actor text := case when core.is_service_caller() then 'service' else 'user' end;
  r       record;
begin
  if p_org_id is null then
    raise exception 'engage_kill_switch: org required' using errcode = '22023';
  end if;
  if not core.is_service_caller() and not stock.has_stock_access(p_org_id) then
    raise exception 'engage_kill_switch: not a member with stock access' using errcode = '42501';
  end if;
  if p_connection_id is not null
     and not exists (select 1 from stock.broker_connections c where c.id = p_connection_id and c.org_id = p_org_id) then
    raise exception 'engage_kill_switch: connection not in organization' using errcode = '42501';
  end if;

  select * into v_row from stock.kill_switches k
  where k.is_active and k.scope = v_scope and k.org_id = p_org_id
    and k.connection_id is not distinct from p_connection_id;
  if not found then
    insert into stock.kill_switches (scope, org_id, connection_id, is_active, trigger_source, reason, engaged_by)
    values (v_scope, p_org_id, p_connection_id, true, 'manual', left(coalesce(nullif(btrim(p_reason), ''), 'manual stop'), 200), auth.uid())
    returning * into v_row;
  end if;

  for r in
    select o.id, o.status from stock.order_requests o
    where o.org_id = p_org_id and o.status in ('pending_confirm', 'confirmed')
      and (p_connection_id is null or o.connection_id = p_connection_id)
    for update
  loop
    update stock.order_requests set status = 'blocked', block_reason = 'kill_switch' where id = r.id;
    insert into stock.order_events (org_id, order_id, event, from_status, to_status, detail, actor_id, actor_role)
    values (p_org_id, r.id, 'blocked', r.status, 'blocked', jsonb_build_object('kill_switch_id', v_row.id), auth.uid(), v_actor);
  end loop;

  perform core.write_audit(p_org_id, 'stock.kill_switch.engage', 'kill_switch', v_row.id::text, null, to_jsonb(v_row));
  return v_row;
end;
$$;

-- 킬 스위치 해제: 수동(manual)으로 켠 조직/연결 스위치만 owner/admin 이 해제. 자동/운영/전역은 service_role 만.
create or replace function stock.release_kill_switch(p_switch_id uuid)
returns stock.kill_switches
language plpgsql
security definer
set search_path = ''
as $$
declare v_row stock.kill_switches;
begin
  select * into v_row from stock.kill_switches where id = p_switch_id for update;
  if not found then
    raise exception 'release_kill_switch: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() then
    if v_row.scope = 'global' or v_row.trigger_source <> 'manual' then
      raise exception 'release_kill_switch: service only for % / %', v_row.scope, v_row.trigger_source using errcode = '42501';
    end if;
    if not stock.has_stock_access(v_row.org_id) or not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
      raise exception 'release_kill_switch: owner/admin only' using errcode = '42501';
    end if;
  end if;
  if not v_row.is_active then
    return v_row;
  end if;
  update stock.kill_switches set is_active = false, released_by = auth.uid(), released_at = now()
   where id = p_switch_id returning * into v_row;
  if v_row.org_id is not null then
    perform core.write_audit(v_row.org_id, 'stock.kill_switch.release', 'kill_switch', v_row.id::text);
  end if;
  return v_row;
end;
$$;

-- 주문 생성(모의투자): service_role 전용. 한도 위반/킬 스위치/시세 지연은 예외 대신 blocked 행으로 남긴다.
-- 같은 client_order_id 재호출은 기존 행을 그대로 돌려준다(멱등).
create or replace function stock.create_paper_order(
  p_org_id            uuid,
  p_connection_id     uuid,
  p_client_order_id   uuid,
  p_symbol            text,
  p_side              text,
  p_quantity          integer,
  p_limit_price       numeric,
  p_ref_price         numeric,
  p_ref_price_at      timestamptz,
  p_actor_id          uuid,
  p_prefill_report_id uuid default null
)
returns stock.order_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conn     stock.broker_connections;
  v_lim      stock.order_limits;
  v_row      stock.order_requests;
  v_amount   numeric;
  v_dev      numeric;
  v_day_from timestamptz;
  v_day_sum  numeric;
  v_day_cnt  integer;
  v_reason   text;
begin
  if not core.is_privileged_session() then
    raise exception 'create_paper_order: service_role only' using errcode = '42501';
  end if;
  if p_actor_id is null then
    raise exception 'create_paper_order: human actor required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtext('stock:order:' || p_client_order_id::text));
  select * into v_row from stock.order_requests where client_order_id = p_client_order_id;
  if found then
    return v_row;
  end if;

  select * into v_conn from stock.broker_connections where id = p_connection_id and org_id = p_org_id;
  if not found or v_conn.env <> 'paper' or not v_conn.orders_enabled or v_conn.status <> 'active' then
    raise exception 'create_paper_order: connection not eligible for paper orders' using errcode = 'ST010';
  end if;

  insert into stock.order_limits (org_id) values (p_org_id) on conflict (org_id) do nothing;
  select * into v_lim from stock.order_limits where org_id = p_org_id for update;   -- 조직 단위 직렬화

  v_amount   := round(p_quantity * p_limit_price);
  v_dev      := abs(p_limit_price - p_ref_price) / nullif(p_ref_price, 0) * 100;
  v_day_from := date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
  select coalesce(sum(o.est_amount_krw), 0), count(*) into v_day_sum, v_day_cnt
  from stock.order_requests o
  where o.org_id = p_org_id and o.created_at >= v_day_from
    and o.status not in ('blocked', 'canceled', 'expired', 'rejected', 'failed');

  v_reason := case
    when stock.is_trading_blocked(p_org_id, p_connection_id)              then 'kill_switch'
    when p_ref_price_at < now() - make_interval(secs => v_lim.max_quote_age_seconds) then 'quote_stale'
    when v_dev is null or v_dev > v_lim.max_price_deviation_pct           then 'price_deviation'
    when v_amount > v_lim.max_order_krw                                   then 'max_order_krw'
    when v_day_sum + v_amount > v_lim.max_daily_krw                       then 'max_daily_krw'
    when v_day_cnt >= v_lim.max_orders_per_day                            then 'max_orders_per_day'
    else null end;

  insert into stock.order_requests (org_id, connection_id, client_order_id, env, symbol, side, order_type, quantity,
                                    limit_price, ref_price, ref_price_at, status, limit_check, block_reason,
                                    confirm_expires_at, prefill_report_id, created_by)
  values (p_org_id, p_connection_id, p_client_order_id, 'paper', p_symbol, p_side, 'limit', p_quantity,
          p_limit_price, p_ref_price, p_ref_price_at,
          case when v_reason is null then 'pending_confirm' else 'blocked' end,
          jsonb_build_object('amount_krw', v_amount, 'deviation_pct', round(coalesce(v_dev, -1), 4),
                             'day_sum_krw', v_day_sum, 'day_count', v_day_cnt, 'limits', to_jsonb(v_lim)),
          v_reason, now() + interval '60 seconds', p_prefill_report_id, p_actor_id)
  returning * into v_row;

  insert into stock.order_events (org_id, order_id, event, from_status, to_status, detail, actor_id, actor_role)
  values (p_org_id, v_row.id, case when v_reason is null then 'created' else 'blocked' end, null, v_row.status,
          v_row.limit_check || jsonb_build_object('block_reason', v_reason), p_actor_id, 'service');
  return v_row;
end;
$$;

-- 사람의 최종 확인: 주문을 만든 본인만, 60초 안에. 만료/킬 스위치는 상태로 남기고 행을 반환한다.
create or replace function stock.confirm_paper_order(p_order_id uuid)
returns stock.order_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   stock.order_requests;
  v_from  text;
  v_actor text := case when core.is_service_caller() then 'service' else 'user' end;
begin
  select * into v_row from stock.order_requests where id = p_order_id for update;
  if not found then
    raise exception 'confirm_paper_order: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() then
    if not stock.has_stock_access(v_row.org_id) or v_row.created_by is distinct from auth.uid() then
      raise exception 'confirm_paper_order: only the requester can confirm' using errcode = '42501';
    end if;
  end if;
  if v_row.status <> 'pending_confirm' then
    raise exception 'confirm_paper_order: invalid state %', v_row.status using errcode = 'ST020';
  end if;
  v_from := v_row.status;

  if v_row.confirm_expires_at <= now() then
    update stock.order_requests set status = 'expired' where id = p_order_id returning * into v_row;
    insert into stock.order_events (org_id, order_id, event, from_status, to_status, actor_id, actor_role)
    values (v_row.org_id, v_row.id, 'expired', v_from, 'expired', auth.uid(), v_actor);
    return v_row;
  end if;

  if stock.is_trading_blocked(v_row.org_id, v_row.connection_id) then
    update stock.order_requests set status = 'blocked', block_reason = 'kill_switch' where id = p_order_id returning * into v_row;
    insert into stock.order_events (org_id, order_id, event, from_status, to_status, actor_id, actor_role)
    values (v_row.org_id, v_row.id, 'blocked', v_from, 'blocked', auth.uid(), v_actor);
    return v_row;
  end if;

  update stock.order_requests set status = 'confirmed', confirmed_at = now(), confirmed_by = coalesce(auth.uid(), v_row.created_by)
   where id = p_order_id returning * into v_row;
  insert into stock.order_events (org_id, order_id, event, from_status, to_status, actor_id, actor_role)
  values (v_row.org_id, v_row.id, 'confirmed', v_from, 'confirmed', auth.uid(), v_actor);
  perform core.write_audit(v_row.org_id, 'stock.order.confirm', 'order_request', v_row.id::text);
  return v_row;
end;
$$;

-- 워커가 증권사 응답을 반영. service_role 전용. 전이는 트리거가 검사한다.
create or replace function stock.apply_order_update(
  p_order_id        uuid,
  p_to              text,
  p_broker_order_id text default null,
  p_filled_quantity integer default null,
  p_avg_fill_price  numeric default null,
  p_detail          jsonb default '{}'::jsonb
)
returns stock.order_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row  stock.order_requests;
  v_from text;
begin
  if not core.is_privileged_session() then
    raise exception 'apply_order_update: service_role only' using errcode = '42501';
  end if;
  select * into v_row from stock.order_requests where id = p_order_id for update;
  if not found then
    raise exception 'apply_order_update: not found' using errcode = 'P0002';
  end if;
  v_from := v_row.status;
  if p_to = 'submitted' and stock.is_trading_blocked(v_row.org_id, v_row.connection_id) then
    p_to := 'blocked';
  end if;
  update stock.order_requests
     set status          = p_to,
         block_reason    = case when p_to = 'blocked' then coalesce(block_reason, 'kill_switch') else block_reason end,
         broker_order_id = coalesce(p_broker_order_id, broker_order_id),
         filled_quantity = coalesce(p_filled_quantity, filled_quantity),
         avg_fill_price  = coalesce(p_avg_fill_price, avg_fill_price),
         submitted_at    = case when p_to = 'submitted' then now() else submitted_at end
   where id = p_order_id
  returning * into v_row;
  insert into stock.order_events (org_id, order_id, event, from_status, to_status, detail, actor_role)
  values (v_row.org_id, v_row.id,
          case when p_to in ('submitted', 'accepted', 'partially_filled', 'filled', 'rejected', 'failed', 'canceled', 'blocked') then p_to
               else 'broker_response' end,
          v_from, p_to, coalesce(p_detail, '{}'::jsonb), 'service');
  return v_row;
end;
$$;

-- 확인 대기 만료(스케줄, 매 1분). service_role 전용.
create or replace function stock.expire_pending_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer := 0; r record;
begin
  if not core.is_privileged_session() then
    raise exception 'expire_pending_orders: service_role only' using errcode = '42501';
  end if;
  for r in select id, org_id from stock.order_requests
           where status = 'pending_confirm' and confirm_expires_at <= now() for update skip locked
  loop
    update stock.order_requests set status = 'expired' where id = r.id;
    insert into stock.order_events (org_id, order_id, event, from_status, to_status, actor_role)
    values (r.org_id, r.id, 'expired', 'pending_confirm', 'expired', 'system');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- RLS (2부)
alter table stock.order_limits   enable row level security;
alter table stock.kill_switches  enable row level security;
alter table stock.order_requests enable row level security;
alter table stock.order_events   enable row level security;

drop policy if exists order_limits_select on stock.order_limits;
create policy order_limits_select on stock.order_limits for select to authenticated
  using (stock.has_stock_access(org_id));
drop policy if exists kill_switches_select on stock.kill_switches;
create policy kill_switches_select on stock.kill_switches for select to authenticated
  using (scope = 'global' or stock.has_stock_access(org_id));
drop policy if exists order_requests_select on stock.order_requests;
create policy order_requests_select on stock.order_requests for select to authenticated
  using (stock.has_stock_access(org_id));
drop policy if exists order_events_select on stock.order_events;
create policy order_events_select on stock.order_events for select to authenticated
  using (stock.has_stock_access(org_id));

create index if not exists order_requests_org_created_idx on stock.order_requests (org_id, created_at desc);
create index if not exists order_requests_pending_idx on stock.order_requests (confirm_expires_at) where status = 'pending_confirm';
create index if not exists order_requests_open_idx on stock.order_requests (connection_id) where status in ('confirmed', 'submitted', 'accepted', 'partially_filled');
create index if not exists order_events_order_idx on stock.order_events (order_id, id);
create index if not exists kill_switches_org_idx on stock.kill_switches (org_id) where is_active;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'stock' and tablename = 'order_requests') then
    alter publication supabase_realtime add table stock.order_requests;
  end if;
end $$;

-- 권한 (2부)
do $$
declare t text;
begin
  foreach t in array array['order_limits', 'kill_switches', 'order_requests', 'order_events']
  loop
    execute format('revoke all on table stock.%I from public, anon, authenticated', t);
    execute format('grant all on table stock.%I to service_role', t);
    execute format('grant select on table stock.%I to authenticated', t);
  end loop;
end $$;

revoke all on function stock.is_trading_blocked(uuid, uuid) from public, anon, authenticated;
grant execute on function stock.is_trading_blocked(uuid, uuid) to service_role;
revoke all on function stock.set_order_limits(uuid, integer, bigint, integer, numeric, numeric) from public, anon;
grant execute on function stock.set_order_limits(uuid, integer, bigint, integer, numeric, numeric) to authenticated, service_role;
revoke all on function stock.engage_kill_switch(uuid, uuid, text) from public, anon;
grant execute on function stock.engage_kill_switch(uuid, uuid, text) to authenticated, service_role;
revoke all on function stock.release_kill_switch(uuid) from public, anon;
grant execute on function stock.release_kill_switch(uuid) to authenticated, service_role;
revoke all on function stock.create_paper_order(uuid, uuid, uuid, text, text, integer, numeric, numeric, timestamptz, uuid, uuid) from public, anon, authenticated;
grant execute on function stock.create_paper_order(uuid, uuid, uuid, text, text, integer, numeric, numeric, timestamptz, uuid, uuid) to service_role;
revoke all on function stock.confirm_paper_order(uuid) from public, anon;
grant execute on function stock.confirm_paper_order(uuid) to authenticated, service_role;
revoke all on function stock.apply_order_update(uuid, text, text, integer, numeric, jsonb) from public, anon, authenticated;
grant execute on function stock.apply_order_update(uuid, text, text, integer, numeric, jsonb) to service_role;
revoke all on function stock.expire_pending_orders() from public, anon, authenticated;
grant execute on function stock.expire_pending_orders() to service_role;

-- =====================================================================
-- 끝. 스케줄(service_role): stock.expire_pending_orders() 매 1분,
--     만료 초대 정리는 워커가 beta_invites(status issued, expires_at <= now()) -> expired 로 갱신.
-- =====================================================================

-- @@modular-only-begin
-- PostgreSQL 전역 기본값(PUBLIC EXECUTE)은 alter default privileges 로 지워지지 않는다(core 0007 과 같은 규칙).
-- 위에서 함수마다 revoke from public 을 했고, 스키마 단위로 한 번 더 회수한다. authenticated/service_role 부여는 유지된다.
-- (모놀리스는 함수별 revoke 가 같은 역할을 한다.)
revoke execute on all functions in schema stock from public;
-- @@modular-only-end
