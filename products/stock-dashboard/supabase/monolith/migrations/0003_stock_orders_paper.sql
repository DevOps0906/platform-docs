-- =====================================================================
-- 0003_stock_orders_paper.sql
-- Phase 3 모의투자 주문 안전장치(한도, 킬 스위치, 사람 확인, 이벤트 로그). 선행: 0002
-- 생성: _supabase-modular/migrations/1900_stock.sql 을 DB_CONVENTIONS.md 12장 규칙으로 변환(core./stock. -> public.).
-- 직접 고치지 말고 조각을 고친 뒤 06_AGENT_PLAN ST-06-002 변환 스크립트로 다시 만든다.
-- =====================================================================
-- =====================================================================
-- 11. 모의투자 주문 안전장치 (Phase 3. 테이블은 지금 만들되 앱 코드 경로는 Phase 3 전까지 없다)
--     - env = 'paper' CHECK: 실전 주문 행 불가
--     - 한도(order_limits), 킬 스위치(kill_switches), 멱등(client_order_id unique),
--       사람 확인(pending_confirm -> confirmed, 60초 만료, 생성자 본인만), 변경 불가 이벤트 로그(order_events)
--     - AI 는 주문을 만들지 않는다: 주문 생성 RPC 는 service_role 전용이고 actor(사람) 필수,
--       prefill_report_id 는 출처 기록일 뿐이며 확인 단계를 건너뛰지 못한다.
-- =====================================================================

create table if not exists public.order_limits (
  org_id                  uuid primary key references public.organizations(id) on delete cascade,
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

create table if not exists public.kill_switches (
  id             uuid primary key default gen_random_uuid(),
  scope          text not null constraint kill_switches_scope_check check (scope in ('global', 'org', 'connection')),
  org_id         uuid references public.organizations(id) on delete cascade,
  connection_id  uuid references public.broker_connections(id) on delete cascade,
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
create unique index if not exists kill_switches_one_active_idx on public.kill_switches
  (scope, coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(connection_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where is_active;

create table if not exists public.order_requests (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations(id) on delete cascade,
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
  foreign key (connection_id, org_id) references public.broker_connections(id, org_id) on delete cascade,
  constraint order_requests_confirm_check check (status not in ('confirmed', 'submitted', 'accepted', 'partially_filled', 'filled')
                                                 or (confirmed_at is not null and confirmed_by is not null)),
  constraint order_requests_block_check check (status <> 'blocked' or block_reason is not null)
);

create table if not exists public.order_events (
  id          bigint generated always as identity primary key,
  org_id      uuid not null references public.organizations(id) on delete cascade,
  order_id    uuid not null,
  event       text not null constraint order_events_event_check check (event in ('created', 'blocked', 'confirmed', 'expired', 'canceled',
                'submitted', 'broker_response', 'accepted', 'partially_filled', 'filled', 'rejected', 'failed')),
  from_status text,
  to_status   text,
  detail      jsonb not null default '{}'::jsonb,
  actor_id    uuid,
  actor_role  text not null constraint order_events_actor_check check (actor_role in ('user', 'service', 'system')),
  created_at  timestamptz not null default now(),
  foreign key (order_id, org_id) references public.order_requests(id, org_id) on delete cascade
);

do $$
declare t text;
begin
  foreach t in array array['order_limits', 'kill_switches', 'order_requests']
  loop
    execute format('drop trigger if exists %I_set_updated_at on public.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
  foreach t in array array['order_limits', 'kill_switches', 'order_requests', 'order_events']
  loop
    execute format('drop trigger if exists %I_guard_write on public.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on public.%I for each row execute function public.guard_privileged_write()', t, t);
  end loop;
end $$;

drop trigger if exists order_requests_status_transition on public.order_requests;
create trigger order_requests_status_transition before insert or update of status on public.order_requests
  for each row execute function public.enforce_status_transition(
    '>pending_confirm', '>blocked',
    'pending_confirm>confirmed', 'pending_confirm>expired', 'pending_confirm>canceled', 'pending_confirm>blocked',
    'confirmed>submitted', 'confirmed>blocked', 'confirmed>failed',
    'submitted>accepted', 'submitted>rejected', 'submitted>failed',
    'accepted>partially_filled', 'accepted>filled', 'accepted>canceled', 'accepted>rejected',
    'partially_filled>partially_filled', 'partially_filled>filled', 'partially_filled>canceled');

drop trigger if exists order_events_immutable on public.order_events;
create trigger order_events_immutable before update or delete on public.order_events
  for each row execute function public.reject_log_mutation();

-- 킬 스위치 판정(전역 > 조직 > 연결). 내부/서버용.
create or replace function public.is_trading_blocked(p_org_id uuid, p_connection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.kill_switches k
    where k.is_active
      and (k.scope = 'global'
           or (k.scope = 'org' and k.org_id = p_org_id)
           or (k.scope = 'connection' and k.connection_id = p_connection_id))
  );
$$;

-- 한도 설정: owner/admin. 범위는 CHECK 가 강제(플랫폼 상한). 사용자 RPC 이므로 is_service_caller 사용(규칙 1).
create or replace function public.set_order_limits(
  p_org_id                  uuid,
  p_max_order_krw           integer,
  p_max_daily_krw           bigint,
  p_max_orders_per_day      integer,
  p_max_position_weight_pct numeric,
  p_max_price_deviation_pct numeric
)
returns public.order_limits
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before public.order_limits;
  v_row    public.order_limits;
begin
  if not public.is_service_caller() then
    if not public.has_stock_access(p_org_id) or not public.has_org_role(p_org_id, array['owner', 'admin']) then
      raise exception 'set_order_limits: owner/admin with stock access only' using errcode = '42501';
    end if;
  end if;
  select * into v_before from public.order_limits where org_id = p_org_id for update;
  insert into public.order_limits (org_id, max_order_krw, max_daily_krw, max_orders_per_day,
                                  max_position_weight_pct, max_price_deviation_pct, updated_by)
  values (p_org_id, p_max_order_krw, p_max_daily_krw, p_max_orders_per_day,
          p_max_position_weight_pct, p_max_price_deviation_pct, auth.uid())
  on conflict (org_id) do update
    set max_order_krw = excluded.max_order_krw, max_daily_krw = excluded.max_daily_krw,
        max_orders_per_day = excluded.max_orders_per_day, max_position_weight_pct = excluded.max_position_weight_pct,
        max_price_deviation_pct = excluded.max_price_deviation_pct, updated_by = excluded.updated_by
  returning * into v_row;
  perform public.write_audit(p_org_id, 'public.order_limits.update', 'organization', p_org_id::text,
                           to_jsonb(v_before), to_jsonb(v_row));
  return v_row;
end;
$$;

-- 킬 스위치 작동: 조직의 활성 멤버 누구나(멈추는 쪽은 항상 허용). 대기/확인 주문을 즉시 무효화한다.
create or replace function public.engage_kill_switch(p_org_id uuid, p_connection_id uuid default null, p_reason text default 'manual stop')
returns public.kill_switches
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   public.kill_switches;
  v_scope text := case when p_connection_id is null then 'org' else 'connection' end;
  v_actor text := case when public.is_service_caller() then 'service' else 'user' end;
  r       record;
begin
  if p_org_id is null then
    raise exception 'engage_kill_switch: org required' using errcode = '22023';
  end if;
  if not public.is_service_caller() and not public.has_stock_access(p_org_id) then
    raise exception 'engage_kill_switch: not a member with stock access' using errcode = '42501';
  end if;
  if p_connection_id is not null
     and not exists (select 1 from public.broker_connections c where c.id = p_connection_id and c.org_id = p_org_id) then
    raise exception 'engage_kill_switch: connection not in organization' using errcode = '42501';
  end if;

  select * into v_row from public.kill_switches k
  where k.is_active and k.scope = v_scope and k.org_id = p_org_id
    and k.connection_id is not distinct from p_connection_id;
  if not found then
    insert into public.kill_switches (scope, org_id, connection_id, is_active, trigger_source, reason, engaged_by)
    values (v_scope, p_org_id, p_connection_id, true, 'manual', left(coalesce(nullif(btrim(p_reason), ''), 'manual stop'), 200), auth.uid())
    returning * into v_row;
  end if;

  for r in
    select o.id, o.status from public.order_requests o
    where o.org_id = p_org_id and o.status in ('pending_confirm', 'confirmed')
      and (p_connection_id is null or o.connection_id = p_connection_id)
    for update
  loop
    update public.order_requests set status = 'blocked', block_reason = 'kill_switch' where id = r.id;
    insert into public.order_events (org_id, order_id, event, from_status, to_status, detail, actor_id, actor_role)
    values (p_org_id, r.id, 'blocked', r.status, 'blocked', jsonb_build_object('kill_switch_id', v_row.id), auth.uid(), v_actor);
  end loop;

  perform public.write_audit(p_org_id, 'public.kill_switch.engage', 'kill_switch', v_row.id::text, null, to_jsonb(v_row));
  return v_row;
end;
$$;

-- 킬 스위치 해제: 수동(manual)으로 켠 조직/연결 스위치만 owner/admin 이 해제. 자동/운영/전역은 service_role 만.
create or replace function public.release_kill_switch(p_switch_id uuid)
returns public.kill_switches
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.kill_switches;
begin
  select * into v_row from public.kill_switches where id = p_switch_id for update;
  if not found then
    raise exception 'release_kill_switch: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() then
    if v_row.scope = 'global' or v_row.trigger_source <> 'manual' then
      raise exception 'release_kill_switch: service only for % / %', v_row.scope, v_row.trigger_source using errcode = '42501';
    end if;
    if not public.has_stock_access(v_row.org_id) or not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
      raise exception 'release_kill_switch: owner/admin only' using errcode = '42501';
    end if;
  end if;
  if not v_row.is_active then
    return v_row;
  end if;
  update public.kill_switches set is_active = false, released_by = auth.uid(), released_at = now()
   where id = p_switch_id returning * into v_row;
  if v_row.org_id is not null then
    perform public.write_audit(v_row.org_id, 'public.kill_switch.release', 'kill_switch', v_row.id::text);
  end if;
  return v_row;
end;
$$;

-- 주문 생성(모의투자): service_role 전용. 한도 위반/킬 스위치/시세 지연은 예외 대신 blocked 행으로 남긴다.
-- 같은 client_order_id 재호출은 기존 행을 그대로 돌려준다(멱등).
create or replace function public.create_paper_order(
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
returns public.order_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conn     public.broker_connections;
  v_lim      public.order_limits;
  v_row      public.order_requests;
  v_amount   numeric;
  v_dev      numeric;
  v_day_from timestamptz;
  v_day_sum  numeric;
  v_day_cnt  integer;
  v_reason   text;
begin
  if not public.is_privileged_session() then
    raise exception 'create_paper_order: service_role only' using errcode = '42501';
  end if;
  if p_actor_id is null then
    raise exception 'create_paper_order: human actor required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtext('stock:order:' || p_client_order_id::text));
  select * into v_row from public.order_requests where client_order_id = p_client_order_id;
  if found then
    return v_row;
  end if;

  select * into v_conn from public.broker_connections where id = p_connection_id and org_id = p_org_id;
  if not found or v_conn.env <> 'paper' or not v_conn.orders_enabled or v_conn.status <> 'active' then
    raise exception 'create_paper_order: connection not eligible for paper orders' using errcode = 'ST010';
  end if;

  insert into public.order_limits (org_id) values (p_org_id) on conflict (org_id) do nothing;
  select * into v_lim from public.order_limits where org_id = p_org_id for update;   -- 조직 단위 직렬화

  v_amount   := round(p_quantity * p_limit_price);
  v_dev      := abs(p_limit_price - p_ref_price) / nullif(p_ref_price, 0) * 100;
  v_day_from := date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
  select coalesce(sum(o.est_amount_krw), 0), count(*) into v_day_sum, v_day_cnt
  from public.order_requests o
  where o.org_id = p_org_id and o.created_at >= v_day_from
    and o.status not in ('blocked', 'canceled', 'expired', 'rejected', 'failed');

  v_reason := case
    when public.is_trading_blocked(p_org_id, p_connection_id)              then 'kill_switch'
    when p_ref_price_at < now() - make_interval(secs => v_lim.max_quote_age_seconds) then 'quote_stale'
    when v_dev is null or v_dev > v_lim.max_price_deviation_pct           then 'price_deviation'
    when v_amount > v_lim.max_order_krw                                   then 'max_order_krw'
    when v_day_sum + v_amount > v_lim.max_daily_krw                       then 'max_daily_krw'
    when v_day_cnt >= v_lim.max_orders_per_day                            then 'max_orders_per_day'
    else null end;

  insert into public.order_requests (org_id, connection_id, client_order_id, env, symbol, side, order_type, quantity,
                                    limit_price, ref_price, ref_price_at, status, limit_check, block_reason,
                                    confirm_expires_at, prefill_report_id, created_by)
  values (p_org_id, p_connection_id, p_client_order_id, 'paper', p_symbol, p_side, 'limit', p_quantity,
          p_limit_price, p_ref_price, p_ref_price_at,
          case when v_reason is null then 'pending_confirm' else 'blocked' end,
          jsonb_build_object('amount_krw', v_amount, 'deviation_pct', round(coalesce(v_dev, -1), 4),
                             'day_sum_krw', v_day_sum, 'day_count', v_day_cnt, 'limits', to_jsonb(v_lim)),
          v_reason, now() + interval '60 seconds', p_prefill_report_id, p_actor_id)
  returning * into v_row;

  insert into public.order_events (org_id, order_id, event, from_status, to_status, detail, actor_id, actor_role)
  values (p_org_id, v_row.id, case when v_reason is null then 'created' else 'blocked' end, null, v_row.status,
          v_row.limit_check || jsonb_build_object('block_reason', v_reason), p_actor_id, 'service');
  return v_row;
end;
$$;

-- 사람의 최종 확인: 주문을 만든 본인만, 60초 안에. 만료/킬 스위치는 상태로 남기고 행을 반환한다.
create or replace function public.confirm_paper_order(p_order_id uuid)
returns public.order_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   public.order_requests;
  v_from  text;
  v_actor text := case when public.is_service_caller() then 'service' else 'user' end;
begin
  select * into v_row from public.order_requests where id = p_order_id for update;
  if not found then
    raise exception 'confirm_paper_order: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() then
    if not public.has_stock_access(v_row.org_id) or v_row.created_by is distinct from auth.uid() then
      raise exception 'confirm_paper_order: only the requester can confirm' using errcode = '42501';
    end if;
  end if;
  if v_row.status <> 'pending_confirm' then
    raise exception 'confirm_paper_order: invalid state %', v_row.status using errcode = 'ST020';
  end if;
  v_from := v_row.status;

  if v_row.confirm_expires_at <= now() then
    update public.order_requests set status = 'expired' where id = p_order_id returning * into v_row;
    insert into public.order_events (org_id, order_id, event, from_status, to_status, actor_id, actor_role)
    values (v_row.org_id, v_row.id, 'expired', v_from, 'expired', auth.uid(), v_actor);
    return v_row;
  end if;

  if public.is_trading_blocked(v_row.org_id, v_row.connection_id) then
    update public.order_requests set status = 'blocked', block_reason = 'kill_switch' where id = p_order_id returning * into v_row;
    insert into public.order_events (org_id, order_id, event, from_status, to_status, actor_id, actor_role)
    values (v_row.org_id, v_row.id, 'blocked', v_from, 'blocked', auth.uid(), v_actor);
    return v_row;
  end if;

  update public.order_requests set status = 'confirmed', confirmed_at = now(), confirmed_by = coalesce(auth.uid(), v_row.created_by)
   where id = p_order_id returning * into v_row;
  insert into public.order_events (org_id, order_id, event, from_status, to_status, actor_id, actor_role)
  values (v_row.org_id, v_row.id, 'confirmed', v_from, 'confirmed', auth.uid(), v_actor);
  perform public.write_audit(v_row.org_id, 'public.order.confirm', 'order_request', v_row.id::text);
  return v_row;
end;
$$;

-- 워커가 증권사 응답을 반영. service_role 전용. 전이는 트리거가 검사한다.
create or replace function public.apply_order_update(
  p_order_id        uuid,
  p_to              text,
  p_broker_order_id text default null,
  p_filled_quantity integer default null,
  p_avg_fill_price  numeric default null,
  p_detail          jsonb default '{}'::jsonb
)
returns public.order_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row  public.order_requests;
  v_from text;
begin
  if not public.is_privileged_session() then
    raise exception 'apply_order_update: service_role only' using errcode = '42501';
  end if;
  select * into v_row from public.order_requests where id = p_order_id for update;
  if not found then
    raise exception 'apply_order_update: not found' using errcode = 'P0002';
  end if;
  v_from := v_row.status;
  if p_to = 'submitted' and public.is_trading_blocked(v_row.org_id, v_row.connection_id) then
    p_to := 'blocked';
  end if;
  update public.order_requests
     set status          = p_to,
         block_reason    = case when p_to = 'blocked' then coalesce(block_reason, 'kill_switch') else block_reason end,
         broker_order_id = coalesce(p_broker_order_id, broker_order_id),
         filled_quantity = coalesce(p_filled_quantity, filled_quantity),
         avg_fill_price  = coalesce(p_avg_fill_price, avg_fill_price),
         submitted_at    = case when p_to = 'submitted' then now() else submitted_at end
   where id = p_order_id
  returning * into v_row;
  insert into public.order_events (org_id, order_id, event, from_status, to_status, detail, actor_role)
  values (v_row.org_id, v_row.id,
          case when p_to in ('submitted', 'accepted', 'partially_filled', 'filled', 'rejected', 'failed', 'canceled', 'blocked') then p_to
               else 'broker_response' end,
          v_from, p_to, coalesce(p_detail, '{}'::jsonb), 'service');
  return v_row;
end;
$$;

-- 확인 대기 만료(스케줄, 매 1분). service_role 전용.
create or replace function public.expire_pending_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer := 0; r record;
begin
  if not public.is_privileged_session() then
    raise exception 'expire_pending_orders: service_role only' using errcode = '42501';
  end if;
  for r in select id, org_id from public.order_requests
           where status = 'pending_confirm' and confirm_expires_at <= now() for update skip locked
  loop
    update public.order_requests set status = 'expired' where id = r.id;
    insert into public.order_events (org_id, order_id, event, from_status, to_status, actor_role)
    values (r.org_id, r.id, 'expired', 'pending_confirm', 'expired', 'system');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- RLS (2부)
alter table public.order_limits   enable row level security;
alter table public.kill_switches  enable row level security;
alter table public.order_requests enable row level security;
alter table public.order_events   enable row level security;

drop policy if exists order_limits_select on public.order_limits;
create policy order_limits_select on public.order_limits for select to authenticated
  using (public.has_stock_access(org_id));
drop policy if exists kill_switches_select on public.kill_switches;
create policy kill_switches_select on public.kill_switches for select to authenticated
  using (scope = 'global' or public.has_stock_access(org_id));
drop policy if exists order_requests_select on public.order_requests;
create policy order_requests_select on public.order_requests for select to authenticated
  using (public.has_stock_access(org_id));
drop policy if exists order_events_select on public.order_events;
create policy order_events_select on public.order_events for select to authenticated
  using (public.has_stock_access(org_id));

create index if not exists order_requests_org_created_idx on public.order_requests (org_id, created_at desc);
create index if not exists order_requests_pending_idx on public.order_requests (confirm_expires_at) where status = 'pending_confirm';
create index if not exists order_requests_open_idx on public.order_requests (connection_id) where status in ('confirmed', 'submitted', 'accepted', 'partially_filled');
create index if not exists order_events_order_idx on public.order_events (order_id, id);
create index if not exists kill_switches_org_idx on public.kill_switches (org_id) where is_active;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'order_requests') then
    alter publication supabase_realtime add table public.order_requests;
  end if;
end $$;

-- 권한 (2부)
do $$
declare t text;
begin
  foreach t in array array['order_limits', 'kill_switches', 'order_requests', 'order_events']
  loop
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant all on table public.%I to service_role', t);
    execute format('grant select on table public.%I to authenticated', t);
  end loop;
end $$;

revoke all on function public.is_trading_blocked(uuid, uuid) from public, anon, authenticated;
grant execute on function public.is_trading_blocked(uuid, uuid) to service_role;
revoke all on function public.set_order_limits(uuid, integer, bigint, integer, numeric, numeric) from public, anon;
grant execute on function public.set_order_limits(uuid, integer, bigint, integer, numeric, numeric) to authenticated, service_role;
revoke all on function public.engage_kill_switch(uuid, uuid, text) from public, anon;
grant execute on function public.engage_kill_switch(uuid, uuid, text) to authenticated, service_role;
revoke all on function public.release_kill_switch(uuid) from public, anon;
grant execute on function public.release_kill_switch(uuid) to authenticated, service_role;
revoke all on function public.create_paper_order(uuid, uuid, uuid, text, text, integer, numeric, numeric, timestamptz, uuid, uuid) from public, anon, authenticated;
grant execute on function public.create_paper_order(uuid, uuid, uuid, text, text, integer, numeric, numeric, timestamptz, uuid, uuid) to service_role;
revoke all on function public.confirm_paper_order(uuid) from public, anon;
grant execute on function public.confirm_paper_order(uuid) to authenticated, service_role;
revoke all on function public.apply_order_update(uuid, text, text, integer, numeric, jsonb) from public, anon, authenticated;
grant execute on function public.apply_order_update(uuid, text, text, integer, numeric, jsonb) to service_role;
revoke all on function public.expire_pending_orders() from public, anon, authenticated;
grant execute on function public.expire_pending_orders() to service_role;

-- =====================================================================
-- 끝. 스케줄(service_role): public.expire_pending_orders() 매 1분,
--     만료 초대 정리는 워커가 beta_invites(status issued, expires_at <= now()) -> expired 로 갱신.
-- =====================================================================

-- (모놀리스: 스키마 생성, apps/plans 등록 블록은 제거. apps/plans 는 seed.sql 이 넣는다)
