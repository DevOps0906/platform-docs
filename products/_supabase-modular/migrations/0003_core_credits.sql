-- =====================================================================
-- 0003_core_credits.sql
-- 크레딧 원장(append-only) + 지갑(원자 차감) + consume/grant/refund RPC(service_role 전용)
-- + 월 크레딧 지급 잡 + 가입 부트스트랩(0001 스텁 교체) + 결제 이행(confirm → 지급).
--
-- 설계 원칙
--   1) 잔액의 정본은 core.wallets 한 행. 차감은 같은 트랜잭션에서 FOR UPDATE 잠금 후
--      "잔액 >= 요청량" 검사와 UPDATE, 원장 INSERT를 함께 수행한다(비원자 차감 금지).
--   2) 원장은 UPDATE/DELETE 불가. 환불도 새 행(refund_of)으로만 쓴다.
--   3) 세 RPC는 anon/authenticated가 실행할 수 없다(REVOKE EXECUTE). 브라우저에서 rpc('grant_credits') 호출 불가.
--   4) 멱등 키(idempotency_key)가 같으면 두 번째 호출은 첫 결과를 그대로 돌려준다.
--   5) 버킷 2개: plan(월 지급, 이월 정책 적용) / pack(구매·가입·환불). 차감은 plan부터.
-- 선행: 0000 ~ 0002
-- =====================================================================

-- ---------------------------------------------------------------------
-- wallets: 조직당 1행
-- ---------------------------------------------------------------------
create table if not exists core.wallets (
  org_id       uuid primary key references core.organizations(id) on delete cascade,
  plan_balance integer not null default 0 constraint wallets_plan_balance_check check (plan_balance >= 0),
  pack_balance integer not null default 0 constraint wallets_pack_balance_check check (pack_balance >= 0),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- credit_ledger: append-only
-- ---------------------------------------------------------------------
create table if not exists core.credit_ledger (
  id              bigint generated always as identity primary key,
  org_id          uuid not null references core.organizations(id) on delete cascade,
  app_id          text references core.apps(id),
  entry_type      text not null constraint credit_ledger_type_check check (entry_type in ('grant', 'consume', 'refund', 'expire', 'adjust')),
  amount          integer not null constraint credit_ledger_amount_check check (amount <> 0),
  plan_delta      integer not null default 0,
  pack_delta      integer not null default 0,
  balance_after   integer not null,
  reason          text not null,
  ref_type        text,
  ref_id          text,
  refund_of       bigint references core.credit_ledger(id),
  idempotency_key text unique,
  actor_id        uuid,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  constraint credit_ledger_delta_sum_check check (amount = plan_delta + pack_delta)
);
create index if not exists credit_ledger_org_created_idx on core.credit_ledger (org_id, created_at desc);
create index if not exists credit_ledger_ref_idx on core.credit_ledger (ref_type, ref_id);
create index if not exists credit_ledger_refund_of_idx on core.credit_ledger (refund_of) where refund_of is not null;

-- append-only: UPDATE 금지. DELETE는 조직 영구 삭제 절차(core.purge_organization)에서만 허용.
create or replace function core.credit_ledger_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and core.is_privileged_session() then
    return old;
  end if;
  raise exception 'core.credit_ledger is append-only (%)', tg_op using errcode = 'CR000';
end;
$$;
drop trigger if exists credit_ledger_immutable on core.credit_ledger;
create trigger credit_ledger_immutable before update or delete on core.credit_ledger
  for each row execute function core.credit_ledger_immutable();

-- 사용자 세션의 INSERT도 거부(이중 잠금). 원장 쓰기는 아래 RPC만.
drop trigger if exists credit_ledger_guard_write on core.credit_ledger;
create trigger credit_ledger_guard_write before insert on core.credit_ledger
  for each row execute function core.guard_privileged_write();
drop trigger if exists wallets_guard_write on core.wallets;
create trigger wallets_guard_write before insert or update or delete on core.wallets
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- ai_usage: LLM/이미지 호출 사용량 로그(게이트웨이가 기록). 과금 행과 ledger_id로 연결.
-- ---------------------------------------------------------------------
create table if not exists core.ai_usage (
  id              bigint generated always as identity primary key,
  org_id          uuid not null references core.organizations(id) on delete cascade,
  app_id          text references core.apps(id),
  provider        text not null,
  model           text not null,
  purpose         text,
  input_tokens    integer not null default 0,
  output_tokens   integer not null default 0,
  cost_usd_micros bigint not null default 0,
  credits         integer not null default 0,
  ledger_id       bigint references core.credit_ledger(id),
  latency_ms      integer,
  status          text not null default 'ok' constraint ai_usage_status_check check (status in ('ok', 'error', 'fallback')),
  error_code      text,
  request_id      text,
  created_at      timestamptz not null default now()
);
create index if not exists ai_usage_org_created_idx on core.ai_usage (org_id, created_at desc);

alter table core.wallets       enable row level security;
alter table core.credit_ledger enable row level security;
alter table core.ai_usage      enable row level security;
grant select on core.wallets, core.credit_ledger, core.ai_usage to authenticated;

-- 잔액 뷰(호출자 권한 → wallets RLS 적용)
create or replace view core.credit_balances
with (security_invoker = true) as
  select w.org_id,
         w.plan_balance,
         w.pack_balance,
         w.plan_balance + w.pack_balance as balance,
         w.updated_at
  from core.wallets w;
grant select on core.credit_balances to authenticated;

-- 원장 합계로 지갑을 검증하는 뷰(운영용; service_role)
create or replace view core.credit_ledger_reconciliation as
  select w.org_id,
         w.plan_balance + w.pack_balance as wallet_balance,
         coalesce(sum(l.amount), 0)::integer as ledger_balance,
         (w.plan_balance + w.pack_balance) - coalesce(sum(l.amount), 0)::integer as drift
  from core.wallets w
  left join core.credit_ledger l on l.org_id = w.org_id
  group by w.org_id, w.plan_balance, w.pack_balance;

-- ---------------------------------------------------------------------
-- consume_credits: 원자 차감. 부족하면 SQLSTATE 'CR001'.
-- 반환: ledger_id, new_balance, plan_used, pack_used
-- ---------------------------------------------------------------------
create or replace function core.consume_credits(
  p_org_id          uuid,
  p_amount          integer,
  p_app_id          text,
  p_reason          text,
  p_ref_type        text    default null,
  p_ref_id          text    default null,
  p_idempotency_key text    default null,
  p_metadata        jsonb   default '{}'::jsonb,
  p_actor_id        uuid    default null
)
returns table (ledger_id bigint, new_balance integer, plan_used integer, pack_used integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan      integer;
  v_pack      integer;
  v_take_plan integer;
  v_take_pack integer;
  v_row       core.credit_ledger;
begin
  if not core.is_privileged_session() then
    raise exception 'consume_credits: service_role only' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'consume_credits: amount must be positive' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    perform pg_advisory_xact_lock(hashtext('credit:' || p_idempotency_key));
    select * into v_row from core.credit_ledger l where l.idempotency_key = p_idempotency_key;
    if found then
      return query select v_row.id, v_row.balance_after, -v_row.plan_delta, -v_row.pack_delta;
      return;
    end if;
  end if;

  insert into core.wallets (org_id) values (p_org_id) on conflict (org_id) do nothing;

  select w.plan_balance, w.pack_balance into v_plan, v_pack
  from core.wallets w where w.org_id = p_org_id for update;

  if v_plan + v_pack < p_amount then
    raise exception 'insufficient_credits: balance=% required=%', v_plan + v_pack, p_amount
      using errcode = 'CR001';
  end if;

  v_take_plan := least(v_plan, p_amount);
  v_take_pack := p_amount - v_take_plan;

  update core.wallets
  set plan_balance = plan_balance - v_take_plan,
      pack_balance = pack_balance - v_take_pack,
      updated_at   = now()
  where org_id = p_org_id;

  insert into core.credit_ledger
    (org_id, app_id, entry_type, amount, plan_delta, pack_delta, balance_after,
     reason, ref_type, ref_id, idempotency_key, actor_id, metadata)
  values
    (p_org_id, p_app_id, 'consume', -p_amount, -v_take_plan, -v_take_pack, v_plan + v_pack - p_amount,
     p_reason, p_ref_type, p_ref_id, p_idempotency_key, p_actor_id, coalesce(p_metadata, '{}'::jsonb))
  returning * into v_row;

  return query select v_row.id, v_row.balance_after, v_take_plan, v_take_pack;
end;
$$;

-- ---------------------------------------------------------------------
-- grant_credits: 지급. p_bucket = 'plan' | 'pack'.
-- p_reset_plan_bucket = true 이면 지급 전 남은 plan 잔액을 expire 처리(이월 불가 플랜).
-- ---------------------------------------------------------------------
create or replace function core.grant_credits(
  p_org_id            uuid,
  p_amount            integer,
  p_app_id            text,
  p_reason            text,
  p_bucket            text    default 'pack',
  p_ref_type          text    default null,
  p_ref_id            text    default null,
  p_idempotency_key   text    default null,
  p_metadata          jsonb   default '{}'::jsonb,
  p_actor_id          uuid    default null,
  p_reset_plan_bucket boolean default false
)
returns table (ledger_id bigint, new_balance integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan integer;
  v_pack integer;
  v_row  core.credit_ledger;
begin
  if not core.is_privileged_session() then
    raise exception 'grant_credits: service_role only' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'grant_credits: amount must be positive' using errcode = '22023';
  end if;
  if p_bucket not in ('plan', 'pack') then
    raise exception 'grant_credits: bucket must be plan or pack' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    perform pg_advisory_xact_lock(hashtext('credit:' || p_idempotency_key));
    select * into v_row from core.credit_ledger l where l.idempotency_key = p_idempotency_key;
    if found then
      return query select v_row.id, v_row.balance_after;
      return;
    end if;
  end if;

  insert into core.wallets (org_id) values (p_org_id) on conflict (org_id) do nothing;

  select w.plan_balance, w.pack_balance into v_plan, v_pack
  from core.wallets w where w.org_id = p_org_id for update;

  if p_reset_plan_bucket and v_plan > 0 then
    update core.wallets set plan_balance = 0, updated_at = now() where org_id = p_org_id;
    insert into core.credit_ledger
      (org_id, app_id, entry_type, amount, plan_delta, pack_delta, balance_after, reason, ref_type, ref_id, idempotency_key, actor_id, metadata)
    values
      (p_org_id, p_app_id, 'expire', -v_plan, -v_plan, 0, v_pack, 'plan_bucket_reset', p_ref_type, p_ref_id,
       case when p_idempotency_key is null then null else p_idempotency_key || ':expire' end, p_actor_id, '{}'::jsonb);
    v_plan := 0;
  end if;

  if p_bucket = 'plan' then
    update core.wallets set plan_balance = plan_balance + p_amount, updated_at = now() where org_id = p_org_id;
    v_plan := v_plan + p_amount;
  else
    update core.wallets set pack_balance = pack_balance + p_amount, updated_at = now() where org_id = p_org_id;
    v_pack := v_pack + p_amount;
  end if;

  insert into core.credit_ledger
    (org_id, app_id, entry_type, amount, plan_delta, pack_delta, balance_after,
     reason, ref_type, ref_id, idempotency_key, actor_id, metadata)
  values
    (p_org_id, p_app_id, 'grant', p_amount,
     case when p_bucket = 'plan' then p_amount else 0 end,
     case when p_bucket = 'pack' then p_amount else 0 end,
     v_plan + v_pack, p_reason, p_ref_type, p_ref_id, p_idempotency_key, p_actor_id, coalesce(p_metadata, '{}'::jsonb))
  returning * into v_row;

  return query select v_row.id, v_row.balance_after;
end;
$$;

-- ---------------------------------------------------------------------
-- refund_credits: consume 행을 가리키는 환불. 부분 환불 가능, 누적 환불은 원 차감액을 넘지 못한다.
-- 버킷은 원래 차감된 비율대로 되돌린다.
-- ---------------------------------------------------------------------
create or replace function core.refund_credits(
  p_consume_ledger_id bigint,
  p_reason            text,
  p_amount            integer default null,
  p_idempotency_key   text    default null,
  p_actor_id          uuid    default null
)
returns table (ledger_id bigint, new_balance integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_orig       core.credit_ledger;
  v_row        core.credit_ledger;
  v_ref_plan   integer;  -- 이미 환불된 plan 합
  v_ref_pack   integer;  -- 이미 환불된 pack 합
  v_rem_plan   integer;
  v_rem_pack   integer;
  v_amount     integer;
  v_back_plan  integer;
  v_back_pack  integer;
  v_plan       integer;
  v_pack       integer;
begin
  if not core.is_privileged_session() then
    raise exception 'refund_credits: service_role only' using errcode = '42501';
  end if;

  if p_idempotency_key is not null then
    perform pg_advisory_xact_lock(hashtext('credit:' || p_idempotency_key));
    select * into v_row from core.credit_ledger l where l.idempotency_key = p_idempotency_key;
    if found then
      return query select v_row.id, v_row.balance_after;
      return;
    end if;
  end if;

  -- 같은 consume 행에 대한 동시 환불 직렬화
  perform pg_advisory_xact_lock(hashtext('refund:' || p_consume_ledger_id::text));

  select * into v_orig from core.credit_ledger l where l.id = p_consume_ledger_id;
  if not found or v_orig.entry_type <> 'consume' then
    raise exception 'refund_credits: ledger % is not a consume entry', p_consume_ledger_id using errcode = 'CR002';
  end if;

  select coalesce(sum(l.plan_delta), 0), coalesce(sum(l.pack_delta), 0)
  into v_ref_plan, v_ref_pack
  from core.credit_ledger l where l.refund_of = p_consume_ledger_id;

  v_rem_plan := (-v_orig.plan_delta) - v_ref_plan;
  v_rem_pack := (-v_orig.pack_delta) - v_ref_pack;
  v_amount   := coalesce(p_amount, v_rem_plan + v_rem_pack);

  if v_amount <= 0 or v_amount > v_rem_plan + v_rem_pack then
    raise exception 'refund_credits: amount % exceeds refundable %', v_amount, v_rem_plan + v_rem_pack using errcode = 'CR003';
  end if;

  v_back_plan := least(v_rem_plan, v_amount);
  v_back_pack := v_amount - v_back_plan;

  select w.plan_balance, w.pack_balance into v_plan, v_pack
  from core.wallets w where w.org_id = v_orig.org_id for update;

  update core.wallets
  set plan_balance = plan_balance + v_back_plan,
      pack_balance = pack_balance + v_back_pack,
      updated_at   = now()
  where org_id = v_orig.org_id;

  insert into core.credit_ledger
    (org_id, app_id, entry_type, amount, plan_delta, pack_delta, balance_after,
     reason, ref_type, ref_id, refund_of, idempotency_key, actor_id, metadata)
  values
    (v_orig.org_id, v_orig.app_id, 'refund', v_amount, v_back_plan, v_back_pack, v_plan + v_pack + v_amount,
     p_reason, v_orig.ref_type, v_orig.ref_id, p_consume_ledger_id, p_idempotency_key, p_actor_id, '{}'::jsonb)
  returning * into v_row;

  return query select v_row.id, v_row.balance_after;
end;
$$;

-- 실행 권한: service_role만. (PUBLIC 기본 EXECUTE는 0000에서 제거했지만 명시적으로 한 번 더 회수한다.)
revoke execute on function core.consume_credits(uuid, integer, text, text, text, text, text, jsonb, uuid) from public, anon, authenticated;
revoke execute on function core.grant_credits(uuid, integer, text, text, text, text, text, text, jsonb, uuid, boolean) from public, anon, authenticated;
revoke execute on function core.refund_credits(bigint, text, integer, text, uuid) from public, anon, authenticated;
grant execute on function core.consume_credits(uuid, integer, text, text, text, text, text, jsonb, uuid) to service_role;
grant execute on function core.grant_credits(uuid, integer, text, text, text, text, text, text, jsonb, uuid, boolean) to service_role;
grant execute on function core.refund_credits(bigint, text, integer, text, uuid) to service_role;

-- ---------------------------------------------------------------------
-- 가입 부트스트랩(0001 스텁 교체)
--   앱의 기본 플랜으로 구독/엔타이틀먼트를 만들고 가입 크레딧(pack)과 첫 달 플랜 크레딧(plan)을 지급한다.
--   승인제 앱이면 profiles.status = 'pending'.
-- ---------------------------------------------------------------------
create or replace function core.on_signup_app_bootstrap(p_org_id uuid, p_user_id uuid, p_app_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app    core.apps;
  v_plan   core.plans;
  v_sub    core.subscriptions;
  v_period_end timestamptz;
  v_key    text;
begin
  select * into v_app from core.apps where id = p_app_id and status <> 'disabled';
  if not found then
    return;
  end if;

  if v_app.signup_policy = 'approval' then
    update core.profiles set status = 'pending' where id = p_user_id and status = 'active';
  end if;

  select * into v_plan from core.plans where app_id = p_app_id and is_default and is_active limit 1;
  if not found then
    return;
  end if;

  v_period_end := case v_plan.billing_interval
    when 'month' then now() + interval '1 month'
    when 'year'  then now() + interval '1 year'
    else null end;

  insert into core.subscriptions (org_id, app_id, plan_id, status, current_period_start, current_period_end)
  values (p_org_id, p_app_id, v_plan.id, 'active', now(), v_period_end)
  on conflict (org_id, app_id) do nothing;

  select * into v_sub from core.subscriptions where org_id = p_org_id and app_id = p_app_id;

  insert into core.app_entitlements (org_id, app_id, plan_id, status, source)
  values (p_org_id, p_app_id, v_plan.id, 'active', 'signup')
  on conflict (org_id, app_id) do nothing;

  if v_plan.signup_credits > 0 then
    perform core.grant_credits(p_org_id, v_plan.signup_credits, p_app_id, 'signup_credits', 'pack',
                               'signup', p_user_id::text, 'signup:' || p_org_id::text || ':' || p_app_id,
                               '{}'::jsonb, null, false);
  end if;

  if v_plan.monthly_credits > 0 and v_sub.id is not null then
    v_key := 'monthly:' || v_sub.id::text || ':' || to_char(v_sub.current_period_start, 'YYYY-MM-DD');
    perform core.grant_credits(p_org_id, v_plan.monthly_credits, p_app_id, 'monthly_plan_credits', 'plan',
                               'subscription', v_sub.id::text, v_key, '{}'::jsonb, null, not v_plan.carry_over);
    update core.subscriptions set last_credit_grant_key = v_key where id = v_sub.id;
  end if;
end;
$$;

-- 기존 사용자가 다른 앱을 처음 열 때(SSO) 호출. owner/admin만. 조직은 기본값으로 개인 조직.
create or replace function core.bootstrap_app_for_org(p_app_id text, p_org_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  v_org := coalesce(p_org_id, core.personal_org_id());
  if v_org is null then
    raise exception 'bootstrap_app_for_org: no organization' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() then
    if not exists (select 1 from core.org_members m where m.org_id = v_org and m.user_id = auth.uid()
                   and m.status = 'active' and m.role in ('owner', 'admin')) then
      raise exception 'bootstrap_app_for_org: owner/admin only' using errcode = '42501';
    end if;
  end if;
  perform core.on_signup_app_bootstrap(v_org, auth.uid(), p_app_id);
end;
$$;
grant execute on function core.bootstrap_app_for_org(text, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 월 크레딧 지급 잡 (service_role / pg_cron)
--   1) 무료(0원) 월 구독의 기간을 굴린다.
--   2) 현재 기간에 아직 지급되지 않은 구독에 플랜 크레딧을 지급한다. 멱등 키 = monthly:<sub>:<period_start>
--   3) cancel_at_period_end 이고 기간이 끝난 구독을 expired로 전이한다.
-- 반환: 지급 건수
-- ---------------------------------------------------------------------
create or replace function core.run_monthly_credit_grants()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r       record;
  v_key   text;
  v_count integer := 0;
begin
  if not core.is_privileged_session() then
    raise exception 'run_monthly_credit_grants: service_role only' using errcode = '42501';
  end if;

  -- 1) 무료 구독 기간 굴리기
  update core.subscriptions s
  set current_period_start = s.current_period_end,
      current_period_end   = s.current_period_end + case p.billing_interval when 'year' then interval '1 year' else interval '1 month' end
  from core.plans p
  where p.id = s.plan_id
    and p.price_krw = 0
    and p.billing_interval in ('month', 'year')
    and s.status in ('active', 'trialing')
    and s.current_period_end is not null
    and s.current_period_end <= now();

  -- 2) 지급
  for r in
    select s.id, s.org_id, s.app_id, s.current_period_start, p.monthly_credits, p.carry_over
    from core.subscriptions s
    join core.plans p on p.id = s.plan_id
    where s.status in ('active', 'trialing')
      and p.monthly_credits > 0
      and p.billing_interval in ('month', 'year')
      and s.current_period_start <= now()
      and (s.current_period_end is null or s.current_period_end > now())
      and coalesce(s.last_credit_grant_key, '') <> 'monthly:' || s.id::text || ':' || to_char(s.current_period_start, 'YYYY-MM-DD')
  loop
    v_key := 'monthly:' || r.id::text || ':' || to_char(r.current_period_start, 'YYYY-MM-DD');
    perform core.grant_credits(r.org_id, r.monthly_credits, r.app_id, 'monthly_plan_credits', 'plan',
                               'subscription', r.id::text, v_key, '{}'::jsonb, null, not r.carry_over);
    update core.subscriptions set last_credit_grant_key = v_key where id = r.id;
    v_count := v_count + 1;
  end loop;

  -- 3) 해지 예약 구독 만료
  for r in
    select s.id from core.subscriptions s
    where s.status = 'canceled' and s.current_period_end is not null and s.current_period_end <= now()
  loop
    perform core.apply_subscription_transition(r.id, 'expired', 'period_end');
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- 결제 이행: Toss confirm 성공 후 서버가 1회 호출.
--   주문을 잠그고, 금액을 대조하고, payments를 기록하고, 종류별로 지급한다. 전부 한 트랜잭션.
--   같은 (order_id, payment_key)로 다시 호출되면 기존 payments 행을 돌려준다(멱등).
--   SQLSTATE: PM404 주문 없음 / PM409 다른 결제키로 재확인 / PM410 상태 불가 / PM001 금액 불일치
-- ---------------------------------------------------------------------
create or replace function core.confirm_payment_order(
  p_order_id    text,
  p_payment_key text,
  p_amount_krw  integer,
  p_method      text        default null,
  p_raw         jsonb       default '{}'::jsonb,
  p_approved_at timestamptz default now()
)
returns core.payments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order   core.payment_orders;
  v_payment core.payments;
  v_plan    core.plans;
  v_sub     core.subscriptions;
  v_start   timestamptz := now();
  v_end     timestamptz;
  v_key     text;
begin
  if not core.is_privileged_session() then
    raise exception 'confirm_payment_order: service_role only' using errcode = '42501';
  end if;

  select * into v_order from core.payment_orders where order_id = p_order_id for update;
  if not found then
    raise exception 'payment order not found: %', p_order_id using errcode = 'PM404';
  end if;

  if v_order.status = 'confirmed' then
    select * into v_payment from core.payments where order_id = p_order_id;
    if v_payment.payment_key = p_payment_key then
      return v_payment;
    end if;
    raise exception 'order % already confirmed with another payment key', p_order_id using errcode = 'PM409';
  end if;

  if v_order.status <> 'created' then
    raise exception 'order % is %, cannot confirm', p_order_id, v_order.status using errcode = 'PM410';
  end if;

  if v_order.amount_krw <> p_amount_krw then
    update core.payment_orders set status = 'failed',
      metadata = metadata || jsonb_build_object('failure', 'amount_mismatch', 'received', p_amount_krw)
    where order_id = p_order_id;
    raise exception 'amount mismatch for order %: expected % got %', p_order_id, v_order.amount_krw, p_amount_krw
      using errcode = 'PM001';
  end if;

  insert into core.payments (order_id, org_id, payment_key, method, amount_krw, status, approved_at, raw)
  values (p_order_id, v_order.org_id, p_payment_key, p_method, p_amount_krw, 'done', p_approved_at, coalesce(p_raw, '{}'::jsonb))
  returning * into v_payment;

  update core.payment_orders set status = 'confirmed', confirmed_at = now() where order_id = p_order_id;

  if v_order.kind = 'credit_pack' then
    perform core.grant_credits(v_order.org_id, v_order.credits, v_order.app_id, 'credit_pack_purchase', 'pack',
                               'payment_order', p_order_id, 'order:' || p_order_id,
                               jsonb_build_object('payment_key', p_payment_key, 'credit_pack_id', v_order.credit_pack_id),
                               v_order.created_by, false);

  else
    select * into v_plan from core.plans where id = v_order.plan_id;
    v_end := case v_plan.billing_interval when 'year' then v_start + interval '1 year' else v_start + interval '1 month' end;

    insert into core.subscriptions (org_id, app_id, plan_id, status, current_period_start, current_period_end, next_charge_at, failed_charge_count)
    values (v_order.org_id, v_order.app_id, v_plan.id, 'active', v_start, v_end, v_end, 0)
    on conflict (org_id, app_id) do update
      set plan_id              = excluded.plan_id,
          status               = 'active',
          current_period_start = excluded.current_period_start,
          current_period_end   = excluded.current_period_end,
          next_charge_at       = excluded.next_charge_at,
          failed_charge_count  = 0,
          cancel_at_period_end = false,
          canceled_at          = null
    returning * into v_sub;

    insert into core.app_entitlements (org_id, app_id, plan_id, status, source, expires_at)
    values (v_order.org_id, v_order.app_id, v_plan.id, 'active', 'subscription', null)
    on conflict (org_id, app_id) do update
      set plan_id = excluded.plan_id, status = 'active', source = 'subscription', expires_at = null;

    if v_plan.monthly_credits > 0 then
      v_key := 'monthly:' || v_sub.id::text || ':' || to_char(v_sub.current_period_start, 'YYYY-MM-DD');
      perform core.grant_credits(v_order.org_id, v_plan.monthly_credits, v_order.app_id, 'monthly_plan_credits', 'plan',
                                 'subscription', v_sub.id::text, v_key,
                                 jsonb_build_object('order_id', p_order_id, 'payment_key', p_payment_key),
                                 v_order.created_by, not v_plan.carry_over);
      update core.subscriptions set last_credit_grant_key = v_key where id = v_sub.id;
    end if;
  end if;

  return v_payment;
end;
$$;

-- ---------------------------------------------------------------------
-- 조직 영구 삭제(탈퇴 유예 기간 종료 후). 원장 삭제 허용 GUC를 트랜잭션 범위로 켠다.
-- ---------------------------------------------------------------------
create or replace function core.purge_organization(p_org_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'purge_organization: service_role only' using errcode = '42501';
  end if;
  if not exists (select 1 from core.organizations o where o.id = p_org_id and o.deleted_at is not null) then
    raise exception 'purge_organization: organization must be soft-deleted first' using errcode = 'P0001';
  end if;
  perform set_config('core.allow_purge', 'on', true);
  delete from core.organizations where id = p_org_id;
end;
$$;
