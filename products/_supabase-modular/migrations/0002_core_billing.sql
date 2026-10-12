-- =====================================================================
-- 0002_core_billing.sql
-- 앱 레지스트리, 플랜, 크레딧팩, 빌링키, 구독, 엔타이틀먼트, 주문, 결제, 웹훅 이벤트.
-- PG는 전 제품 Toss Payments. 결제 이행(confirm → 지급)은 0003의 core.confirm_payment_order()가 맡는다.
-- 사용자는 어떤 테이블도 직접 쓰지 못한다(플랜/구독/엔타이틀먼트 자기 변경 불가).
-- 선행: 0000, 0001
-- =====================================================================

-- ---------------------------------------------------------------------
-- apps: 제품 레지스트리. id = 모듈러 스키마 이름과 동일하게 쓴다(README 표).
-- ---------------------------------------------------------------------
create table if not exists core.apps (
  id            text primary key constraint apps_id_check check (id ~ '^[a-z][a-z0-9_]{1,30}$'),
  name          text not null,
  schema_name   text not null unique,
  signup_policy text not null default 'open'
                constraint apps_signup_policy_check check (signup_policy in ('open', 'approval', 'invite')),
  status        text not null default 'active'
                constraint apps_status_check check (status in ('active', 'beta', 'disabled')),
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- plans: 앱별 플랜. 월 크레딧(monthly_credits)과 가입 크레딧(signup_credits)을 분리한다.
-- ---------------------------------------------------------------------
create table if not exists core.plans (
  id               uuid primary key default gen_random_uuid(),
  app_id           text not null references core.apps(id) on delete cascade,
  code             text not null constraint plans_code_check check (code ~ '^[a-z][a-z0-9_]{1,30}$'),
  name             text not null,
  description      text,
  price_krw        integer not null default 0 constraint plans_price_check check (price_krw >= 0),
  billing_interval text not null default 'none'
                   constraint plans_interval_check check (billing_interval in ('none', 'month', 'year')),
  monthly_credits  integer not null default 0 constraint plans_monthly_credits_check check (monthly_credits >= 0),
  signup_credits   integer not null default 0 constraint plans_signup_credits_check check (signup_credits >= 0),
  carry_over       boolean not null default false,
  features         jsonb not null default '{}'::jsonb,
  is_default       boolean not null default false,
  is_active        boolean not null default true,
  sort_order       integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (app_id, code)
);
create unique index if not exists plans_one_default_per_app_idx on core.plans (app_id) where is_default;
comment on column core.plans.carry_over is 'false면 월 지급 시 남은 플랜 크레딧을 만료(expire)시킨다';
comment on column core.plans.features is '서버에서만 읽는 기능 플래그. 예: {"tracks":["A"],"max_channels":1}';

-- ---------------------------------------------------------------------
-- credit_packs: 일회 구매 크레딧팩
-- ---------------------------------------------------------------------
create table if not exists core.credit_packs (
  id         uuid primary key default gen_random_uuid(),
  app_id     text not null references core.apps(id) on delete cascade,
  code       text not null constraint credit_packs_code_check check (code ~ '^[a-z][a-z0-9_]{1,30}$'),
  name       text not null,
  credits    integer not null constraint credit_packs_credits_check check (credits > 0),
  price_krw  integer not null constraint credit_packs_price_check check (price_krw > 0),
  is_active  boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (app_id, code)
);

-- ---------------------------------------------------------------------
-- billing_keys: Toss 빌링키. 키 자체는 앱 계층 AES-256-GCM 암호문으로만 저장한다.
-- customer_key는 조직 id에서 결정적으로 만든다(예: 'org_' || org_id). Date.now() 금지.
-- ---------------------------------------------------------------------
create table if not exists core.billing_keys (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  customer_key           text not null,
  billing_key_ciphertext text not null,
  key_version            integer not null default 1,
  card_company           text,
  card_number_masked     text,
  status                 text not null default 'active'
                         constraint billing_keys_status_check check (status in ('active', 'revoked')),
  created_by             uuid,
  created_at             timestamptz not null default now(),
  revoked_at             timestamptz
);
create unique index if not exists billing_keys_one_active_per_org_idx on core.billing_keys (org_id) where status = 'active';

-- ---------------------------------------------------------------------
-- subscriptions: 조직 x 앱 당 1개. 상태 전이는 core.apply_subscription_transition()만 사용.
-- ---------------------------------------------------------------------
create table if not exists core.subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  app_id                 text not null references core.apps(id) on delete cascade,
  plan_id                uuid not null references core.plans(id),
  status                 text not null default 'active'
                         constraint subscriptions_status_check check (status in ('trialing', 'active', 'past_due', 'canceled', 'expired')),
  billing_key_id         uuid references core.billing_keys(id) on delete set null,
  current_period_start   timestamptz not null default now(),
  current_period_end     timestamptz,
  next_charge_at         timestamptz,
  cancel_at_period_end   boolean not null default false,
  canceled_at            timestamptz,
  failed_charge_count    integer not null default 0,
  last_credit_grant_key  text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (org_id, app_id)
);
create index if not exists subscriptions_charge_due_idx on core.subscriptions (next_charge_at)
  where status in ('active', 'past_due') and next_charge_at is not null;

-- ---------------------------------------------------------------------
-- app_entitlements: "이 조직이 이 앱을 어느 플랜으로 쓸 수 있는가"의 단일 출처.
-- RLS와 서버 코드는 subscriptions가 아니라 이 테이블을 본다.
-- ---------------------------------------------------------------------
create table if not exists core.app_entitlements (
  org_id     uuid not null references core.organizations(id) on delete cascade,
  app_id     text not null references core.apps(id) on delete cascade,
  plan_id    uuid not null references core.plans(id),
  status     text not null default 'active'
             constraint app_entitlements_status_check check (status in ('active', 'suspended', 'expired')),
  source     text not null default 'signup'
             constraint app_entitlements_source_check check (source in ('signup', 'subscription', 'manual', 'trial')),
  expires_at timestamptz,
  granted_by uuid,
  note       text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, app_id)
);

-- ---------------------------------------------------------------------
-- payment_orders: 결제창을 열기 전에 서버가 먼저 저장하는 주문. 금액의 정본.
-- order_id는 Toss orderId(6~64자, 영문/숫자/-/_)로 그대로 쓴다. orderId 파싱으로 org/plan을 꺼내지 않는다.
-- ---------------------------------------------------------------------
create table if not exists core.payment_orders (
  id             uuid primary key default gen_random_uuid(),
  order_id       text not null unique constraint payment_orders_order_id_check check (order_id ~ '^[A-Za-z0-9_-]{6,64}$'),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  app_id         text not null references core.apps(id),
  kind           text not null constraint payment_orders_kind_check check (kind in ('subscription', 'credit_pack', 'billing_key_charge')),
  plan_id        uuid references core.plans(id),
  credit_pack_id uuid references core.credit_packs(id),
  credits        integer constraint payment_orders_credits_check check (credits is null or credits > 0),
  amount_krw     integer not null constraint payment_orders_amount_check check (amount_krw > 0),
  currency       text not null default 'KRW',
  status         text not null default 'created'
                 constraint payment_orders_status_check check (status in ('created', 'confirmed', 'failed', 'canceled', 'refunded', 'expired')),
  customer_key   text,
  created_by     uuid,
  expires_at     timestamptz not null default (now() + interval '1 hour'),
  confirmed_at   timestamptz,
  metadata       jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint payment_orders_kind_ref_check check (
    (kind = 'credit_pack' and credit_pack_id is not null and credits is not null)
    or (kind in ('subscription', 'billing_key_charge') and plan_id is not null)
  )
);
create index if not exists payment_orders_org_idx on core.payment_orders (org_id, created_at desc);

-- ---------------------------------------------------------------------
-- payments: Toss 승인 결과. payment_key 유일 → 같은 승인을 두 번 지급하지 않는다.
-- ---------------------------------------------------------------------
create table if not exists core.payments (
  id                  uuid primary key default gen_random_uuid(),
  order_id            text not null references core.payment_orders(order_id),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  payment_key         text not null unique,
  method              text,
  amount_krw          integer not null constraint payments_amount_check check (amount_krw > 0),
  canceled_amount_krw integer not null default 0,
  status              text not null default 'done'
                      constraint payments_status_check check (status in ('done', 'canceled', 'partial_canceled', 'failed')),
  approved_at         timestamptz,
  receipt_url         text,
  raw                 jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists payments_org_idx on core.payments (org_id, created_at desc);

-- ---------------------------------------------------------------------
-- webhook_events: 인바운드 웹훅 멱등 처리. (provider, event_id) 유일.
-- 서명 검증 결과를 기록하고, 실패한 이벤트는 처리하지 않는다.
-- ---------------------------------------------------------------------
create table if not exists core.webhook_events (
  id              uuid primary key default gen_random_uuid(),
  provider        text not null,
  event_id        text not null,
  event_type      text,
  signature_valid boolean not null default false,
  payload         jsonb not null,
  status          text not null default 'received'
                  constraint webhook_events_status_check check (status in ('received', 'processed', 'ignored', 'failed')),
  attempts        integer not null default 0,
  error           text,
  received_at     timestamptz not null default now(),
  processed_at    timestamptz,
  unique (provider, event_id)
);

-- updated_at 트리거
drop trigger if exists plans_set_updated_at on core.plans;
create trigger plans_set_updated_at before update on core.plans for each row execute function core.set_updated_at();
drop trigger if exists subscriptions_set_updated_at on core.subscriptions;
create trigger subscriptions_set_updated_at before update on core.subscriptions for each row execute function core.set_updated_at();
drop trigger if exists app_entitlements_set_updated_at on core.app_entitlements;
create trigger app_entitlements_set_updated_at before update on core.app_entitlements for each row execute function core.set_updated_at();
drop trigger if exists payment_orders_set_updated_at on core.payment_orders;
create trigger payment_orders_set_updated_at before update on core.payment_orders for each row execute function core.set_updated_at();
drop trigger if exists payments_set_updated_at on core.payments;
create trigger payments_set_updated_at before update on core.payments for each row execute function core.set_updated_at();

-- RLS: 모두 켠다. 정책은 0004.
alter table core.apps             enable row level security;
alter table core.plans            enable row level security;
alter table core.credit_packs     enable row level security;
alter table core.billing_keys     enable row level security;
alter table core.subscriptions    enable row level security;
alter table core.app_entitlements enable row level security;
alter table core.payment_orders   enable row level security;
alter table core.payments         enable row level security;
alter table core.webhook_events   enable row level security;

-- 권한: 가격표는 공개 읽기, 조직 데이터는 멤버 읽기, 쓰기는 없음.
grant select on core.apps, core.plans, core.credit_packs to anon, authenticated;
grant select on core.subscriptions, core.app_entitlements, core.payment_orders, core.payments to authenticated;
-- billing_keys, webhook_events: authenticated 권한 없음. 빌링키 요약은 아래 뷰로만.

-- 이중 잠금: 사용자 세션의 쓰기를 트리거에서도 거부
do $$
declare t text;
begin
  foreach t in array array['apps', 'plans', 'credit_packs', 'billing_keys', 'subscriptions', 'app_entitlements', 'payment_orders', 'payments', 'webhook_events']
  loop
    execute format('drop trigger if exists %I_guard_write on core.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on core.%I for each row execute function core.guard_privileged_write()', t, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 빌링키 요약 뷰(암호문 제외). 정의자 뷰이므로 멤버십 필터를 뷰 안에서 건다.
-- ---------------------------------------------------------------------
create or replace view core.billing_key_summaries as
  select b.id, b.org_id, b.customer_key, b.card_company, b.card_number_masked, b.status, b.created_at, b.revoked_at
  from core.billing_keys b
  where b.org_id in (
    select m.org_id from core.org_members m where m.user_id = auth.uid() and m.status = 'active'
  );
grant select on core.billing_key_summaries to authenticated;

-- ---------------------------------------------------------------------
-- 구독 상태 머신 (service_role 전용)
--   trialing → active | canceled | expired
--   active   → past_due | canceled | expired
--   past_due → active | canceled | expired
--   canceled → active | expired          (재구독 / 기간 만료)
--   expired  → active                    (재구독)
-- 엔타이틀먼트 동기화:
--   trialing/active/past_due → active(plan_id = 구독 플랜)
--   canceled                 → 기간 종료까지 유지(cancel_at_period_end=true), 만료 잡이 expired로 전이
--   expired                  → 앱 기본 플랜으로 되돌림(source=signup)
-- ---------------------------------------------------------------------
create or replace function core.apply_subscription_transition(
  p_subscription_id uuid,
  p_to              text,
  p_reason          text default null
)
returns core.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sub          core.subscriptions;
  v_allowed      boolean;
  v_default_plan uuid;
begin
  if not core.is_privileged_session() then
    raise exception 'apply_subscription_transition: service_role only' using errcode = '42501';
  end if;

  select * into v_sub from core.subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'subscription not found: %', p_subscription_id using errcode = 'P0002';
  end if;

  v_allowed := case v_sub.status
    when 'trialing' then p_to in ('active', 'canceled', 'expired')
    when 'active'   then p_to in ('past_due', 'canceled', 'expired')
    when 'past_due' then p_to in ('active', 'canceled', 'expired')
    when 'canceled' then p_to in ('active', 'expired')
    when 'expired'  then p_to in ('active')
    else false
  end;
  if not v_allowed then
    raise exception 'invalid subscription transition % -> %', v_sub.status, p_to using errcode = 'SB001';
  end if;

  update core.subscriptions
  set status               = p_to,
      canceled_at          = case when p_to = 'canceled' then now() else canceled_at end,
      cancel_at_period_end = case when p_to = 'canceled' then true
                                  when p_to = 'active' then false
                                  else cancel_at_period_end end,
      failed_charge_count  = case when p_to = 'active' then 0 else failed_charge_count end,
      next_charge_at       = case when p_to in ('canceled', 'expired') then null else next_charge_at end
  where id = p_subscription_id
  returning * into v_sub;

  if p_to in ('trialing', 'active', 'past_due') then
    insert into core.app_entitlements (org_id, app_id, plan_id, status, source, expires_at)
    values (v_sub.org_id, v_sub.app_id, v_sub.plan_id, 'active', 'subscription', null)
    on conflict (org_id, app_id) do update
      set plan_id = excluded.plan_id, status = 'active', source = 'subscription', expires_at = null;
  elsif p_to = 'canceled' then
    update core.app_entitlements
    set expires_at = v_sub.current_period_end
    where org_id = v_sub.org_id and app_id = v_sub.app_id;
  elsif p_to = 'expired' then
    select id into v_default_plan from core.plans where app_id = v_sub.app_id and is_default and is_active limit 1;
    if v_default_plan is not null then
      insert into core.app_entitlements (org_id, app_id, plan_id, status, source, expires_at)
      values (v_sub.org_id, v_sub.app_id, v_default_plan, 'active', 'signup', null)
      on conflict (org_id, app_id) do update
        set plan_id = excluded.plan_id, status = 'active', source = 'signup', expires_at = null;
    else
      update core.app_entitlements set status = 'expired'
      where org_id = v_sub.org_id and app_id = v_sub.app_id;
    end if;
  end if;

  insert into core.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, after)
  values (v_sub.org_id, null, 'service', 'subscription.' || p_to, 'subscription', v_sub.id::text,
          jsonb_build_object('reason', p_reason, 'plan_id', v_sub.plan_id));

  return v_sub;
end;
$$;
-- audit_log는 0004에서 만들어진다. 함수 본문은 런타임에 바인딩되므로 0004 이후에만 호출할 것.

-- ---------------------------------------------------------------------
-- 주문 만료 처리(스케줄러가 호출): 1시간 넘게 confirmed 되지 않은 주문은 expired
-- ---------------------------------------------------------------------
create or replace function core.expire_stale_payment_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if not core.is_privileged_session() then
    raise exception 'expire_stale_payment_orders: service_role only' using errcode = '42501';
  end if;
  update core.payment_orders set status = 'expired'
  where status = 'created' and expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
