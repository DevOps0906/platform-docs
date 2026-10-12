-- =====================================================================
-- 0002_stock_domain.sql
-- stock-dashboard 도메인(조회, 동기화, AI 진단, 베타 게이트). 선행: 0001_core_lite.sql
-- 생성: _supabase-modular/migrations/1900_stock.sql 을 DB_CONVENTIONS.md 12장 규칙으로 변환(core./stock. -> public.).
-- 직접 고치지 말고 조각을 고친 뒤 06_AGENT_PLAN ST-06-002 변환 스크립트로 다시 만든다.
-- =====================================================================

-- (모놀리스: 스키마 생성, apps/plans 등록 블록은 제거. apps/plans 는 seed.sql 이 넣는다)


-- =====================================================================
-- 1. 공용 트리거 함수
-- =====================================================================

-- 상태 전이 강제. 트리거 인자로 허용 전이 목록을 받는다. 'a>b' = a 에서 b 로, '>a' = INSERT 시 초기 상태 a.
create or replace function public.enforce_status_transition()
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

-- append-only 로그. DELETE 는 조직 영구 삭제(public.purge_organization 의 public.allow_purge GUC) 안에서만.
create or replace function public.reject_log_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and public.is_privileged_session() then
    return old;
  end if;
  raise exception '%.% is append-only (%)', tg_table_schema, tg_table_name, tg_op using errcode = 'ST000';
end;
$$;


-- =====================================================================
-- 2. 베타 초대와 접근 게이트
-- =====================================================================

create table if not exists public.beta_invites (
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
  accepted_org_id  uuid references public.organizations(id) on delete set null,
  accepted_at      timestamptz,
  revoked_at       timestamptz,
  note             text constraint beta_invites_note_check check (note is null or char_length(note) <= 200),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index if not exists beta_invites_open_email_uniq on public.beta_invites (email_normalized) where status = 'issued';

create table if not exists public.beta_access (
  org_id        uuid primary key references public.organizations(id) on delete cascade,
  invite_id     uuid references public.beta_invites(id) on delete set null,
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
create or replace function public.has_stock_access(org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select org is not null
     and public.is_org_member(org)
     and public.has_entitlement(org, 'stock')
     and exists (select 1 from public.beta_access b where b.org_id = org and b.status = 'active');
$$;


-- =====================================================================
-- 3. 참조 데이터 (전역, 조직 무관): 종목 마스터, 재무지표, 일봉(내부 전용), 장 운영 캘린더
-- =====================================================================

create table if not exists public.instruments (
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

create table if not exists public.fundamentals (
  id                 bigint generated always as identity primary key,
  symbol             text not null references public.instruments(symbol) on delete cascade,
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
create table if not exists public.daily_prices (
  symbol     text not null references public.instruments(symbol) on delete cascade,
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

create table if not exists public.market_calendar (
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

create table if not exists public.broker_connections (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations(id) on delete cascade,
  broker             text not null constraint broker_connections_broker_check check (broker in ('mock', 'kis', 'kiwoom', 'hana')),
  env                text not null default 'paper' constraint broker_connections_env_check check (env in ('paper', 'live')),
  label              text constraint broker_connections_label_check check (label is null or char_length(label) <= 40),
  account_masked     text not null
                     constraint broker_connections_account_masked_check check (account_masked ~ '^[0-9*-]{4,24}$' and account_masked ~ '[*]' and account_masked !~ '[0-9]{5,}'),
  account_ref_hash   text not null constraint broker_connections_account_ref_check check (account_ref_hash ~ '^[0-9a-f]{64}$'),
  credential_id      uuid references public.encrypted_credentials(id) on delete set null,
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

create table if not exists public.balance_snapshots (
  id            bigint generated always as identity primary key,
  org_id        uuid not null references public.organizations(id) on delete cascade,
  connection_id uuid not null,
  captured_at   timestamptz not null default now(),
  cash_krw      numeric(18,0) not null default 0,
  purchase_krw  numeric(18,0) not null default 0 constraint balance_snapshots_purchase_check check (purchase_krw >= 0),
  eval_krw      numeric(18,0) not null default 0 constraint balance_snapshots_eval_check check (eval_krw >= 0),
  pnl_krw       numeric(18,0) generated always as (eval_krw - purchase_krw) stored,
  is_sample     boolean not null default false,
  source        text not null default 'sync' constraint balance_snapshots_source_check check (source in ('sync', 'mock')),
  foreign key (connection_id, org_id) references public.broker_connections(id, org_id) on delete cascade
);

create table if not exists public.holdings (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
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
  foreign key (connection_id, org_id) references public.broker_connections(id, org_id) on delete cascade
);

create table if not exists public.trades (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
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
  foreign key (connection_id, org_id) references public.broker_connections(id, org_id) on delete cascade
);

-- 사용자가 직접 쓰는 유일한 도메인 테이블(순수 메모, 돈/권한/상태 컬럼 없음)
create table if not exists public.trade_notes (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations(id) on delete cascade,
  trade_id   uuid not null,
  body       text not null constraint trade_notes_body_check check (char_length(body) between 1 and 2000),
  tags       text[] not null default '{}' constraint trade_notes_tags_check check (cardinality(tags) <= 10),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (trade_id, org_id) references public.trades(id, org_id) on delete cascade
);


-- =====================================================================
-- 5. AI 진단 리포트와 성과 평가 (service_role 쓰기 전용)
-- =====================================================================

create table if not exists public.ai_reports (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations(id) on delete cascade,
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
  credit_ledger_id    bigint references public.credit_ledger(id),
  request_id          uuid not null unique,
  error_code          text,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  started_at          timestamptz,
  finished_at         timestamptz,
  updated_at          timestamptz not null default now(),
  unique (id, org_id),
  foreign key (scope_connection_id, org_id) references public.broker_connections(id, org_id) on delete set null (scope_connection_id),
  -- MVP 진단은 매수가/목표가/손절가를 저장할 수 없다(리뷰 #3). 키 이름 수준의 마지막 방어선.
  constraint ai_reports_no_price_targets_check check (
    output is null or output::text !~* '"(buy_price|entry_price|target_price|stop_price|stop_loss)"[[:space:]]*:'
  ),
  constraint ai_reports_output_status_check check (status <> 'succeeded' or output is not null)
);

create table if not exists public.ai_report_items (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
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
  foreign key (report_id, org_id) references public.ai_reports(id, org_id) on delete cascade
);

-- Phase 2: 아이디어 성과(내부 리더보드). 계산 규칙은 01_PRD ST-F-013, rule_version 으로 고정.
create table if not exists public.idea_evaluations (
  id                   bigint generated always as identity primary key,
  org_id               uuid not null references public.organizations(id) on delete cascade,
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
  foreign key (item_id, org_id) references public.ai_report_items(id, org_id) on delete cascade
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
    execute format('drop trigger if exists %I_set_updated_at on public.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
  -- trade_notes 를 뺀 전 테이블: 사용자 세션 쓰기 거부(이중 잠금)
  foreach t in array array['beta_invites', 'beta_access', 'instruments', 'fundamentals', 'daily_prices', 'market_calendar',
                           'broker_connections', 'balance_snapshots', 'holdings', 'trades',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('drop trigger if exists %I_guard_write on public.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on public.%I for each row execute function public.guard_privileged_write()', t, t);
  end loop;
end $$;

drop trigger if exists beta_invites_status_transition on public.beta_invites;
create trigger beta_invites_status_transition before insert or update of status on public.beta_invites
  for each row execute function public.enforce_status_transition(
    '>issued', 'issued>accepted', 'issued>revoked', 'issued>expired');

drop trigger if exists beta_access_status_transition on public.beta_access;
create trigger beta_access_status_transition before insert or update of status on public.beta_access
  for each row execute function public.enforce_status_transition(
    '>active', 'active>revoked', 'revoked>active');

drop trigger if exists broker_connections_status_transition on public.broker_connections;
create trigger broker_connections_status_transition before insert or update of status on public.broker_connections
  for each row execute function public.enforce_status_transition(
    '>pending', '>active', 'pending>active', 'pending>error', 'pending>revoked',
    'active>error', 'active>revoked', 'error>active', 'error>revoked');

drop trigger if exists ai_reports_status_transition on public.ai_reports;
create trigger ai_reports_status_transition before insert or update of status on public.ai_reports
  for each row execute function public.enforce_status_transition(
    '>queued', 'queued>running', 'queued>canceled', 'queued>failed', 'running>succeeded', 'running>failed');


-- =====================================================================
-- 7. RPC (베타 초대)
-- =====================================================================

-- 초대 수락: service_role 전용. 서버가 토큰 원문을 sha256 으로 바꿔 넘긴다(원문은 DB 에 없다).
-- 플랜 전환(default -> beta)과 첫 달 크레딧은 서버가 코어 경로로 처리한다(04_API 3장).
create or replace function public.redeem_beta_invite(p_token_hash text, p_user_id uuid)
returns public.beta_access
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv   public.beta_invites;
  v_email text;
  v_org   uuid;
  v_row   public.beta_access;
begin
  if not public.is_privileged_session() then
    raise exception 'redeem_beta_invite: service_role only' using errcode = '42501';
  end if;
  select * into v_inv from public.beta_invites where token_hash = p_token_hash for update;
  if not found then
    raise exception 'redeem_beta_invite: invite not found' using errcode = 'ST030';
  end if;
  if v_inv.status = 'issued' and v_inv.expires_at <= now() then
    update public.beta_invites set status = 'expired' where id = v_inv.id;
    return null;                         -- 예외 대신 상태를 남기고 null 반환(롤백 방지)
  end if;
  if v_inv.status <> 'issued' then
    raise exception 'redeem_beta_invite: invite is %', v_inv.status using errcode = 'ST030';
  end if;
  select lower(p.email) into v_email from public.profiles p where p.id = p_user_id;
  if v_email is null or v_email <> v_inv.email_normalized then
    raise exception 'redeem_beta_invite: email mismatch' using errcode = 'ST031';
  end if;
  select o.id into v_org from public.organizations o
  where o.owner_id = p_user_id and o.is_personal and o.deleted_at is null
  order by o.created_at limit 1;
  if v_org is null then
    raise exception 'redeem_beta_invite: no personal organization' using errcode = 'P0002';
  end if;

  update public.beta_invites
     set status = 'accepted', accepted_user_id = p_user_id, accepted_org_id = v_org, accepted_at = now()
   where id = v_inv.id;

  insert into public.beta_access (org_id, invite_id, status, granted_at, granted_by)
  values (v_org, v_inv.id, 'active', now(), v_inv.invited_by)
  on conflict (org_id) do update
    set status = 'active', invite_id = excluded.invite_id, granted_at = now(), revoked_at = null, revoke_reason = null
  returning * into v_row;

  insert into public.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, after)
  values (v_org, p_user_id, 'service', 'public.beta.accept', 'beta_invite', v_inv.id::text,
          jsonb_build_object('org_id', v_org));
  return v_row;
end;
$$;

-- 베타 회수: service_role 전용(운영자 화면 -> 서버). 회수하면 모든 도메인 정책이 즉시 0행이 된다.
create or replace function public.revoke_beta_access(p_org_id uuid, p_reason text)
returns public.beta_access
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.beta_access;
begin
  if not public.is_privileged_session() then
    raise exception 'revoke_beta_access: service_role only' using errcode = '42501';
  end if;
  update public.beta_access
     set status = 'revoked', revoked_at = now(), revoke_reason = left(coalesce(p_reason, ''), 200)
   where org_id = p_org_id and status = 'active'
  returning * into v_row;
  if found then
    insert into public.audit_log (org_id, actor_role, action, target_type, target_id, metadata)
    values (p_org_id, 'service', 'public.beta.revoke', 'organization', p_org_id::text,
            jsonb_build_object('reason', left(coalesce(p_reason, ''), 200)));
  end if;
  return v_row;
end;
$$;


-- =====================================================================
-- 8. RLS (1부: 조회/동기화/AI)
-- =====================================================================

alter table public.beta_invites       enable row level security;
alter table public.beta_access        enable row level security;
alter table public.instruments        enable row level security;
alter table public.fundamentals       enable row level security;
alter table public.daily_prices       enable row level security;
alter table public.market_calendar    enable row level security;
alter table public.broker_connections enable row level security;
alter table public.balance_snapshots  enable row level security;
alter table public.holdings           enable row level security;
alter table public.trades             enable row level security;
alter table public.trade_notes        enable row level security;
alter table public.ai_reports         enable row level security;
alter table public.ai_report_items    enable row level security;
alter table public.idea_evaluations   enable row level security;

-- beta_invites, daily_prices: 정책 없음(= 사용자 전면 거부). service_role 만.

drop policy if exists beta_access_select on public.beta_access;
create policy beta_access_select on public.beta_access for select to authenticated
  using (public.is_org_member(org_id));

drop policy if exists instruments_select on public.instruments;
create policy instruments_select on public.instruments for select to authenticated using (true);
drop policy if exists fundamentals_select on public.fundamentals;
create policy fundamentals_select on public.fundamentals for select to authenticated using (true);
drop policy if exists market_calendar_select on public.market_calendar;
create policy market_calendar_select on public.market_calendar for select to authenticated using (true);

do $$
declare t text;
begin
  foreach t in array array['broker_connections', 'balance_snapshots', 'holdings', 'trades',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format('create policy %I_select on public.%I for select to authenticated using (public.has_stock_access(org_id))', t, t);
  end loop;
end $$;

drop policy if exists trade_notes_select on public.trade_notes;
create policy trade_notes_select on public.trade_notes for select to authenticated
  using (public.has_stock_access(org_id));
drop policy if exists trade_notes_insert on public.trade_notes;
create policy trade_notes_insert on public.trade_notes for insert to authenticated
  with check (public.has_stock_access(org_id) and created_by = auth.uid());
drop policy if exists trade_notes_update on public.trade_notes;
create policy trade_notes_update on public.trade_notes for update to authenticated
  using (public.has_stock_access(org_id) and created_by = auth.uid())
  with check (public.has_stock_access(org_id) and created_by = auth.uid());
drop policy if exists trade_notes_delete on public.trade_notes;
create policy trade_notes_delete on public.trade_notes for delete to authenticated
  using (public.has_stock_access(org_id)
         and (created_by = auth.uid() or public.has_org_role(org_id, array['owner', 'admin'])));


-- =====================================================================
-- 8-B. 동의 기록 (투자 고지, AI 국외 이전, 모의주문 위험). append-only, RPC 로만 기록.
-- =====================================================================

create table if not exists public.consents (
  id          bigint generated always as identity primary key,
  org_id      uuid not null references public.organizations(id) on delete cascade,
  user_id     uuid not null,
  kind        text not null constraint consents_kind_check check (kind in ('investment_disclaimer', 'ai_overseas_transfer', 'paper_order_risk')),
  version     text not null constraint consents_version_check check (version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}(\.[0-9]+)?$'),
  accepted_at timestamptz not null default now(),
  unique (org_id, user_id, kind, version)
);
alter table public.consents enable row level security;
drop trigger if exists consents_guard_write on public.consents;
create trigger consents_guard_write before insert or update or delete on public.consents
  for each row execute function public.guard_privileged_write();
drop trigger if exists consents_immutable on public.consents;
create trigger consents_immutable before update or delete on public.consents
  for each row execute function public.reject_log_mutation();
drop policy if exists consents_select on public.consents;
create policy consents_select on public.consents for select to authenticated
  using (user_id = auth.uid() and public.is_org_member(org_id));
create index if not exists consents_user_kind_idx on public.consents (user_id, kind, accepted_at desc);

-- 본인 동의만 기록. 베타 접근(has_stock_access)이 있는 조직에서만. 같은 버전 재동의는 기존 행 반환.
create or replace function public.record_consent(p_org_id uuid, p_kind text, p_version text)
returns public.consents
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.consents;
begin
  if auth.uid() is null then
    raise exception 'record_consent: user session required' using errcode = '42501';
  end if;
  if not public.is_service_caller() and not public.has_stock_access(p_org_id) then
    raise exception 'record_consent: no stock access' using errcode = '42501';
  end if;
  insert into public.consents (org_id, user_id, kind, version)
  values (p_org_id, auth.uid(), p_kind, p_version)
  on conflict (org_id, user_id, kind, version) do nothing
  returning * into v_row;
  if v_row.id is null then
    select * into v_row from public.consents
    where org_id = p_org_id and user_id = auth.uid() and kind = p_kind and version = p_version;
  end if;
  return v_row;
end;
$$;
revoke all on table public.consents from public, anon, authenticated;
grant all on table public.consents to service_role;
grant select on table public.consents to authenticated;
revoke all on function public.record_consent(uuid, text, text) from public, anon;
grant execute on function public.record_consent(uuid, text, text) to authenticated, service_role;


-- =====================================================================
-- 9. 인덱스, Realtime
-- =====================================================================

create index if not exists broker_connections_org_idx on public.broker_connections (org_id) where status <> 'revoked';
create index if not exists balance_snapshots_conn_captured_idx on public.balance_snapshots (connection_id, captured_at desc);
create index if not exists balance_snapshots_org_captured_idx on public.balance_snapshots (org_id, captured_at desc);
create index if not exists holdings_org_idx on public.holdings (org_id);
create index if not exists trades_org_executed_idx on public.trades (org_id, executed_at desc);
create index if not exists trades_org_symbol_idx on public.trades (org_id, symbol, executed_at desc);
create index if not exists trade_notes_trade_idx on public.trade_notes (trade_id);
create index if not exists ai_reports_org_created_idx on public.ai_reports (org_id, created_at desc);
create index if not exists ai_reports_org_day_idx on public.ai_reports (org_id, kind, created_at) where status in ('queued', 'running', 'succeeded');
create index if not exists idea_evaluations_org_idx on public.idea_evaluations (org_id, horizon_days);
create index if not exists fundamentals_symbol_idx on public.fundamentals (symbol, as_of desc);
create index if not exists daily_prices_date_idx on public.daily_prices (trade_date);
create index if not exists beta_invites_expiry_idx on public.beta_invites (expires_at) where status = 'issued';

do $$
declare t text;
begin
  foreach t in array array['holdings', 'balance_snapshots', 'ai_reports', 'broker_connections']
  loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
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
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant all on table public.%I to service_role', t);
  end loop;
  foreach t in array array['beta_access', 'instruments', 'fundamentals', 'market_calendar',
                           'broker_connections', 'balance_snapshots', 'holdings', 'trades', 'trade_notes',
                           'ai_reports', 'ai_report_items', 'idea_evaluations']
  loop
    execute format('grant select on table public.%I to authenticated', t);
  end loop;
end $$;
grant insert (org_id, trade_id, body, tags) on public.trade_notes to authenticated;
grant update (body, tags) on public.trade_notes to authenticated;
grant delete on public.trade_notes to authenticated;

revoke all on function public.enforce_status_transition() from public, anon, authenticated;
revoke all on function public.reject_log_mutation() from public, anon, authenticated;
revoke all on function public.has_stock_access(uuid) from public, anon;
grant execute on function public.has_stock_access(uuid) to authenticated, service_role;
revoke all on function public.redeem_beta_invite(text, uuid) from public, anon, authenticated;
grant execute on function public.redeem_beta_invite(text, uuid) to service_role;
revoke all on function public.revoke_beta_access(uuid, text) from public, anon, authenticated;
grant execute on function public.revoke_beta_access(uuid, text) to service_role;


