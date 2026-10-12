-- =====================================================================
-- admin-suite / erp 모놀리스 0002_erp_domain.sql
-- 모듈러 조각 _supabase-modular/migrations/1600_erp.sql 를 DB_CONVENTIONS.md 12장 규칙으로 변환한 것이다.
--   (a) create schema / 기본 권한 블록 제거 (b) core. -> public. (c) erp. -> public.
--   (d) 모든 테이블은 revoke all from public, anon, authenticated 뒤 필요한 GRANT 만(조각에 이미 있음)
--   (e) core.apps / core.plans 등록은 seed.sql 로 옮겼다.
-- 두 파일의 도메인 모델은 같다. 조각을 고치면 이 파일을 다시 생성한다(06_AGENT_PLAN ADM-06-004).
-- 선행: 0001_core_lite.sql
-- =====================================================================

-- =====================================================================
-- 1600_erp.sql
-- admin-suite / apps/erp 도메인(재고, 판매, 인사). 선행(모놀리스): 0001_core_lite.sql
-- 기획: docs/products/admin-suite/05_DATA_MODEL.md
--
-- 설계 요약
--   - 테넌트 = public.organizations. ERP를 쓰는 조직은 public.workspaces 행이 있어야 한다(서버 프로비저닝).
--     가입 트리거가 만드는 개인 조직에는 workspaces 행이 없으므로 도메인 데이터를 만들 수 없다.
--   - 역할: master_admin = core org 역할 owner/admin(파생, 저장 안 함).
--           inventory_manager / sales_manager / staff = public.employees.erp_role.
--   - 역할 컬럼(erp_role, status)은 사용자가 직접 쓰지 못한다. GRANT 없음 + guard 트리거 + DEFINER RPC.
--     자기 역할 변경 금지, 역할 비교는 has_org_role(exists) 또는 coalesce 로 NULL-safe.
--   - 재고 수량은 RPC(record_inventory_move, record_sale, complete_sale, cancel_sale)만 바꾼다.
--     조건부 UPDATE + 이력 INSERT 를 한 트랜잭션에서(리뷰 ERP #4).
--   - authenticated 에 EXECUTE 를 연 DEFINER 함수의 호출자 판정은 public.is_service_caller() 만 쓴다.
-- 반복 실행 가능(if not exists / create or replace / drop ... if exists).
-- =====================================================================


-- =====================================================================
-- 1. 테이블
-- =====================================================================

-- workspaces: ERP를 쓰는 조직(고객사). 서버(service_role)가 프로비저닝한다.
create table if not exists public.workspaces (
  org_id               uuid primary key references public.organizations(id) on delete cascade,
  company_name         text not null constraint workspaces_company_name_check check (char_length(company_name) between 1 and 120),
  status               text not null default 'active' constraint workspaces_status_check check (status in ('active', 'suspended')),
  default_safety_stock integer not null default 10 constraint workspaces_default_safety_stock_check check (default_safety_stock between 0 and 1000000),
  low_stock_alert      boolean not null default true,
  settings             jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- join_codes: 승인제 가입 코드. 사용자 GRANT 없음(public.get_join_code, master_admin 전용).
create table if not exists public.join_codes (
  org_id     uuid primary key references public.workspaces(org_id) on delete cascade,
  join_code  text not null unique constraint join_codes_join_code_check check (join_code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  rotated_at timestamptz not null default now()
);

-- departments: 부서(트리). 순수 콘텐츠 테이블 → master_admin 쓰기 정책 허용.
create table if not exists public.departments (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations(id) on delete cascade,
  name       text not null constraint departments_name_check check (char_length(name) between 1 and 60),
  parent_id  uuid,
  sort_order integer not null default 0,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint departments_org_id_uniq unique (org_id, id),
  constraint departments_org_name_uniq unique (org_id, name),
  constraint departments_parent_fk foreign key (org_id, parent_id) references public.departments (org_id, id) on delete set null (parent_id),
  constraint departments_parent_check check (parent_id is null or parent_id <> id)
);

-- employees: 임직원 디렉토리 + ERP 역할. 쓰기는 RPC만.
create table if not exists public.employees (
  org_id        uuid not null references public.organizations(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  display_name  text not null default '' constraint employees_display_name_check check (char_length(display_name) <= 80),
  department_id uuid,
  position      text constraint employees_position_check check (position is null or char_length(position) <= 40),
  phone         text constraint employees_phone_check check (phone is null or phone ~ '^[0-9+() -]{7,20}$'),
  erp_role      text not null default 'staff'
                constraint employees_erp_role_check check (erp_role in ('inventory_manager', 'sales_manager', 'staff')),
  status        text not null default 'active' constraint employees_status_check check (status in ('active', 'suspended')),
  joined_at     timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (org_id, user_id),
  constraint employees_department_fk foreign key (org_id, department_id) references public.departments (org_id, id) on delete set null (department_id)
);
create index if not exists employees_user_idx on public.employees (user_id);

-- join_requests: 승인제 가입 요청. 신청자는 아직 조직 멤버가 아니다.
create table if not exists public.join_requests (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  user_id        uuid not null references auth.users(id) on delete cascade,
  applicant_name text not null constraint join_requests_applicant_name_check check (char_length(applicant_name) between 1 and 80),
  message        text constraint join_requests_message_check check (message is null or char_length(message) <= 500),
  status         text not null default 'pending'
                 constraint join_requests_status_check check (status in ('pending', 'approved', 'rejected', 'canceled')),
  decided_by     uuid,
  decided_at     timestamptz,
  decision_note  text constraint join_requests_decision_note_check check (decision_note is null or char_length(decision_note) <= 500),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index if not exists join_requests_pending_uniq on public.join_requests (org_id, user_id) where status = 'pending';
create index if not exists join_requests_org_status_idx on public.join_requests (org_id, status, created_at desc);

-- products: 상품. quantity 는 RPC만 바꾼다(컬럼 GRANT 제외 + 트리거).
create table if not exists public.products (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  sku           text not null constraint products_sku_check check (sku ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'),
  name          text not null constraint products_name_check check (char_length(name) between 1 and 200),
  category      text not null default '기타' constraint products_category_check check (char_length(category) between 1 and 60),
  price         numeric(12, 2) not null default 0 constraint products_price_check check (price >= 0),
  quantity      integer not null default 0 constraint products_quantity_check check (quantity >= 0),
  safety_stock  integer not null default 10 constraint products_safety_stock_check check (safety_stock >= 0),
  is_low_stock  boolean generated always as (quantity <= safety_stock) stored,
  image_path    text,
  is_active     boolean not null default true,
  created_by    uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint products_org_id_uniq unique (org_id, id),
  constraint products_org_sku_uniq unique (org_id, sku)
);
create index if not exists products_low_stock_idx on public.products (org_id) where is_low_stock and is_active;
create index if not exists products_org_category_idx on public.products (org_id, category);

-- inventory_moves: 입출고/조정/판매 이력. append-only.
create table if not exists public.inventory_moves (
  id             bigint generated always as identity primary key,
  org_id         uuid not null references public.organizations(id) on delete cascade,
  product_id     uuid not null,
  move_type      text not null constraint inventory_moves_move_type_check check (move_type in ('IN', 'OUT', 'ADJUSTMENT', 'SALE', 'SALE_CANCEL')),
  quantity_delta integer not null constraint inventory_moves_quantity_delta_check check (quantity_delta <> 0),
  quantity_after integer not null constraint inventory_moves_quantity_after_check check (quantity_after >= 0),
  reason         text constraint inventory_moves_reason_check check (reason is null or char_length(reason) <= 300),
  sale_id        uuid,
  request_id     text,
  created_by     uuid,
  created_at     timestamptz not null default now(),
  constraint inventory_moves_product_fk foreign key (org_id, product_id) references public.products (org_id, id),
  constraint inventory_moves_request_uniq unique (org_id, request_id)
);
create index if not exists inventory_moves_org_created_idx on public.inventory_moves (org_id, created_at desc);
create index if not exists inventory_moves_product_idx on public.inventory_moves (product_id, created_at desc);

-- sales: 판매. 상태 pending/completed/canceled. 전이는 트리거 + RPC.
create table if not exists public.sales (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  product_id    uuid not null,
  quantity      integer not null constraint sales_quantity_check check (quantity > 0),
  unit_price    numeric(12, 2) not null constraint sales_unit_price_check check (unit_price >= 0),
  total_price   numeric(14, 2) generated always as (unit_price * quantity) stored,
  status        text not null default 'completed' constraint sales_status_check check (status in ('pending', 'completed', 'canceled')),
  sold_by       uuid,
  sold_at       timestamptz not null default now(),
  completed_at  timestamptz,
  canceled_at   timestamptz,
  canceled_by   uuid,
  cancel_reason text constraint sales_cancel_reason_check check (cancel_reason is null or char_length(cancel_reason) <= 300),
  request_id    text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint sales_product_fk foreign key (org_id, product_id) references public.products (org_id, id),
  constraint sales_request_uniq unique (org_id, request_id),
  constraint sales_completed_at_check check (status <> 'completed' or completed_at is not null)
);
create index if not exists sales_org_completed_idx on public.sales (org_id, completed_at desc) where status = 'completed';
create index if not exists sales_org_status_idx on public.sales (org_id, status, sold_at desc);

-- updated_at 트리거
drop trigger if exists workspaces_set_updated_at on public.workspaces;
create trigger workspaces_set_updated_at before update on public.workspaces for each row execute function public.set_updated_at();
drop trigger if exists departments_set_updated_at on public.departments;
create trigger departments_set_updated_at before update on public.departments for each row execute function public.set_updated_at();
drop trigger if exists employees_set_updated_at on public.employees;
create trigger employees_set_updated_at before update on public.employees for each row execute function public.set_updated_at();
drop trigger if exists join_requests_set_updated_at on public.join_requests;
create trigger join_requests_set_updated_at before update on public.join_requests for each row execute function public.set_updated_at();
drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products for each row execute function public.set_updated_at();
drop trigger if exists sales_set_updated_at on public.sales;
create trigger sales_set_updated_at before update on public.sales for each row execute function public.set_updated_at();

-- 이중 잠금: 사용자 세션의 직접 쓰기 거부(정책/GRANT가 실수로 열려도 42501)
drop trigger if exists workspaces_guard_write on public.workspaces;
create trigger workspaces_guard_write before insert or update or delete on public.workspaces for each row execute function public.guard_privileged_write();
drop trigger if exists join_codes_guard_write on public.join_codes;
create trigger join_codes_guard_write before insert or update or delete on public.join_codes for each row execute function public.guard_privileged_write();
drop trigger if exists employees_guard_write on public.employees;
create trigger employees_guard_write before insert or update or delete on public.employees for each row execute function public.guard_privileged_write();
drop trigger if exists join_requests_guard_write on public.join_requests;
create trigger join_requests_guard_write before insert or update or delete on public.join_requests for each row execute function public.guard_privileged_write();
drop trigger if exists inventory_moves_guard_write on public.inventory_moves;
create trigger inventory_moves_guard_write before insert or update or delete on public.inventory_moves for each row execute function public.guard_privileged_write();
drop trigger if exists sales_guard_write on public.sales;
create trigger sales_guard_write before insert or update or delete on public.sales for each row execute function public.guard_privileged_write();

-- inventory_moves 는 service_role 도 UPDATE 불가(append-only). DELETE 는 조직 삭제 연쇄만.
create or replace function public.inventory_moves_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'public.inventory_moves is append-only (%)', tg_op using errcode = '42501';
end;
$$;
drop trigger if exists inventory_moves_immutable on public.inventory_moves;
create trigger inventory_moves_immutable before update on public.inventory_moves for each row execute function public.inventory_moves_immutable();

-- products: quantity 는 권한 세션(service_role 또는 DEFINER RPC)만 바꾼다. image_path 는 자기 조직 폴더만.
create or replace function public.guard_product_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.image_path is not null and new.image_path not like new.org_id::text || '/erp/product/%' then
    raise exception 'products: image_path must be under <org_id>/erp/product/' using errcode = '22023';
  end if;
  if public.is_privileged_session() then
    return new;
  end if;
  if tg_op = 'INSERT' and new.quantity <> 0 then
    raise exception 'products: initial quantity must be 0. use public.record_inventory_move' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and (new.quantity is distinct from old.quantity or new.org_id is distinct from old.org_id) then
    raise exception 'products: quantity/org_id can only be changed by RPC' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists products_guard_columns on public.products;
create trigger products_guard_columns before insert or update on public.products for each row execute function public.guard_product_columns();

-- 상태 전이 트리거: service_role 쓰기에도 적용된다(DB_CONVENTIONS 10장).
create or replace function public.sales_guard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'pending'   and new.status in ('completed', 'canceled'))
    or (old.status = 'completed' and new.status = 'canceled')) then
    raise exception 'sales: transition % -> % not allowed', old.status, new.status using errcode = '22023';
  end if;
  if new.quantity is distinct from old.quantity or new.unit_price is distinct from old.unit_price
     or new.product_id is distinct from old.product_id or new.org_id is distinct from old.org_id then
    raise exception 'sales: quantity/price/product are immutable' using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists sales_guard_transition on public.sales;
create trigger sales_guard_transition before update on public.sales for each row execute function public.sales_guard_transition();

create or replace function public.join_requests_guard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (old.status = 'pending' and new.status in ('approved', 'rejected', 'canceled')) then
    raise exception 'join_requests: transition % -> % not allowed', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists join_requests_guard_transition on public.join_requests;
create trigger join_requests_guard_transition before update on public.join_requests for each row execute function public.join_requests_guard_transition();

-- =====================================================================
-- 2. 역할 헬퍼 (SECURITY DEFINER + STABLE + search_path ''). 정책 안의 자기참조 재귀(42P17)를 끊는다.
-- =====================================================================

-- 이 조직의 ERP 데이터에 접근할 수 있는가: 활성 프로필 + 활성 워크스페이스 + 엔타이틀먼트 + 활성 멤버십
-- + (core owner/admin 이거나 활성 employees 행)
create or replace function public.has_access(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
     and exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'active')
     and exists (select 1 from public.workspaces w where w.org_id = p_org and w.status = 'active')
     and public.has_entitlement(p_org, 'erp')
     and public.is_org_member(p_org)
     and (public.has_org_role(p_org, array['owner', 'admin'])
          or exists (select 1 from public.employees e
                     where e.org_id = p_org and e.user_id = auth.uid() and e.status = 'active'));
$$;

-- ERP 역할 판정. 'master_admin' 은 core owner/admin 에서 파생한다. exists 기반이라 NULL 이 나오지 않는다.
create or replace function public.has_role(p_org uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_access(p_org)
     and (
          ('master_admin' = any (p_roles) and public.has_org_role(p_org, array['owner', 'admin']))
       or exists (select 1 from public.employees e
                  where e.org_id = p_org and e.user_id = auth.uid() and e.status = 'active'
                    and e.erp_role = any (p_roles))
     );
$$;

-- 화면 분기용 현재 역할. 접근 불가면 null.
create or replace function public.my_role(p_org uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not public.has_access(p_org) then null
    when public.has_org_role(p_org, array['owner', 'admin']) then 'master_admin'
    else (select e.erp_role from public.employees e
          where e.org_id = p_org and e.user_id = auth.uid() and e.status = 'active')
  end;
$$;

revoke execute on function public.has_access(uuid) from public, anon;
revoke execute on function public.has_role(uuid, text[]) from public, anon;
revoke execute on function public.my_role(uuid) from public, anon;
grant execute on function public.has_access(uuid) to authenticated, service_role;
grant execute on function public.has_role(uuid, text[]) to authenticated, service_role;
grant execute on function public.my_role(uuid) to authenticated, service_role;

-- =====================================================================
-- 3. RLS 정책과 GRANT
-- =====================================================================
alter table public.workspaces      enable row level security;
alter table public.join_codes      enable row level security;
alter table public.departments     enable row level security;
alter table public.employees       enable row level security;
alter table public.join_requests   enable row level security;
alter table public.products        enable row level security;
alter table public.inventory_moves enable row level security;
alter table public.sales           enable row level security;

revoke all on table public.workspaces, public.join_codes, public.departments, public.employees, public.join_requests,
                    public.products, public.inventory_moves, public.sales from public, anon, authenticated;
grant all on table public.workspaces, public.join_codes, public.departments, public.employees, public.join_requests,
                   public.products, public.inventory_moves, public.sales to service_role;

-- workspaces: 조회만. join_codes 는 정책/GRANT 없음(= 사용자 접근 불가).
grant select on public.workspaces to authenticated;
drop policy if exists workspaces_select on public.workspaces;
create policy workspaces_select on public.workspaces for select to authenticated
  using (public.has_access(org_id));

-- departments: 조회는 접근 가능한 전원, 쓰기는 master_admin
grant select, insert, update, delete on public.departments to authenticated;
drop policy if exists departments_select on public.departments;
create policy departments_select on public.departments for select to authenticated
  using (public.has_access(org_id));
drop policy if exists departments_insert on public.departments;
create policy departments_insert on public.departments for insert to authenticated
  with check (public.has_role(org_id, array['master_admin']));
drop policy if exists departments_update on public.departments;
create policy departments_update on public.departments for update to authenticated
  using (public.has_role(org_id, array['master_admin'])) with check (public.has_role(org_id, array['master_admin']));
drop policy if exists departments_delete on public.departments;
create policy departments_delete on public.departments for delete to authenticated
  using (public.has_role(org_id, array['master_admin']));

-- employees: 본인 행 + master_admin 전체. 쓰기 GRANT 없음(RPC만).
grant select on public.employees to authenticated;
drop policy if exists employees_select on public.employees;
create policy employees_select on public.employees for select to authenticated
  using ((user_id = auth.uid() and public.has_access(org_id)) or public.has_role(org_id, array['master_admin']));

-- join_requests: 신청자 본인 + master_admin
grant select on public.join_requests to authenticated;
drop policy if exists join_requests_select on public.join_requests;
create policy join_requests_select on public.join_requests for select to authenticated
  using (user_id = auth.uid() or public.has_role(org_id, array['master_admin']));

-- products: 조회는 master_admin/inventory_manager/sales_manager. staff 는 대시보드 RPC로만.
-- 쓰기는 master_admin/inventory_manager. quantity 컬럼은 GRANT 하지 않는다.
grant select on public.products to authenticated;
grant insert (org_id, sku, name, category, price, safety_stock, image_path, is_active) on public.products to authenticated;
grant update (sku, name, category, price, safety_stock, image_path, is_active) on public.products to authenticated;
grant delete on public.products to authenticated;
drop policy if exists products_select on public.products;
create policy products_select on public.products for select to authenticated
  using (public.has_role(org_id, array['master_admin', 'inventory_manager', 'sales_manager']));
drop policy if exists products_insert on public.products;
create policy products_insert on public.products for insert to authenticated
  with check (public.has_role(org_id, array['master_admin', 'inventory_manager']));
drop policy if exists products_update on public.products;
create policy products_update on public.products for update to authenticated
  using (public.has_role(org_id, array['master_admin', 'inventory_manager']))
  with check (public.has_role(org_id, array['master_admin', 'inventory_manager']));
drop policy if exists products_delete on public.products;
create policy products_delete on public.products for delete to authenticated
  using (public.has_role(org_id, array['master_admin']));

-- inventory_moves: 조회만
grant select on public.inventory_moves to authenticated;
drop policy if exists inventory_moves_select on public.inventory_moves;
create policy inventory_moves_select on public.inventory_moves for select to authenticated
  using (public.has_role(org_id, array['master_admin', 'inventory_manager', 'sales_manager']));

-- sales: 조회만 (금액 정보라 inventory_manager/staff 제외)
grant select on public.sales to authenticated;
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select to authenticated
  using (public.has_role(org_id, array['master_admin', 'sales_manager']));

-- =====================================================================
-- 4. RPC
-- =====================================================================

-- 가입 코드 생성(내부). 혼동 문자(I, O, 0, 1) 제외 32자.
create or replace function public.new_join_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alpha constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  v_code  text;
  i       integer;
begin
  for attempt in 1..5 loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    if not exists (select 1 from public.join_codes j where j.join_code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception 'new_join_code: could not generate unique code' using errcode = 'P0001';
end;
$$;
revoke execute on function public.new_join_code() from public, anon, authenticated;

-- 프로비저닝(서버 전용): 조직 생성/owner 지정/엔타이틀먼트는 서버 코드가 먼저 수행한다(05_DATA_MODEL 6절).
create or replace function public.register_workspace(p_org_id uuid, p_company_name text)
returns public.workspaces
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.workspaces;
begin
  if not public.is_privileged_session() then
    raise exception 'register_workspace: service_role only' using errcode = '42501';
  end if;
  insert into public.workspaces (org_id, company_name)
  values (p_org_id, p_company_name)
  on conflict (org_id) do update set company_name = excluded.company_name, status = 'active'
  returning * into v_row;
  insert into public.join_codes (org_id, join_code) values (p_org_id, public.new_join_code())
  on conflict (org_id) do nothing;
  perform public.write_audit(p_org_id, 'erp_workspace.register', 'organization', p_org_id::text);
  return v_row;
end;
$$;
revoke execute on function public.register_workspace(uuid, text) from public, anon, authenticated;
grant execute on function public.register_workspace(uuid, text) to service_role;

-- 가입 코드 조회/교체 (master_admin)
create or replace function public.get_join_code(p_org_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['master_admin']) then
    raise exception 'get_join_code: master_admin only' using errcode = '42501';
  end if;
  return (select j.join_code from public.join_codes j where j.org_id = p_org_id);
end;
$$;

create or replace function public.rotate_join_code(p_org_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_code text;
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['master_admin']) then
    raise exception 'rotate_join_code: master_admin only' using errcode = '42501';
  end if;
  v_code := public.new_join_code();
  update public.join_codes set join_code = v_code, rotated_at = now() where org_id = p_org_id;
  if not found then
    raise exception 'rotate_join_code: workspace not found' using errcode = 'P0002';
  end if;
  perform public.write_audit(p_org_id, 'erp_workspace.rotate_join_code', 'organization', p_org_id::text);
  return v_code;
end;
$$;

create or replace function public.update_workspace_settings(p_org_id uuid, p_company_name text, p_default_safety_stock integer, p_low_stock_alert boolean)
returns public.workspaces
language plpgsql
security definer
set search_path = ''
as $$
declare v_before public.workspaces; v_row public.workspaces;
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['master_admin']) then
    raise exception 'update_workspace_settings: master_admin only' using errcode = '42501';
  end if;
  select * into v_before from public.workspaces where org_id = p_org_id for update;
  if not found then
    raise exception 'update_workspace_settings: workspace not found' using errcode = 'P0002';
  end if;
  update public.workspaces
  set company_name = coalesce(p_company_name, company_name),
      default_safety_stock = coalesce(p_default_safety_stock, default_safety_stock),
      low_stock_alert = coalesce(p_low_stock_alert, low_stock_alert)
  where org_id = p_org_id
  returning * into v_row;
  perform public.write_audit(p_org_id, 'erp_workspace.update', 'organization', p_org_id::text,
    jsonb_build_object('company_name', v_before.company_name, 'default_safety_stock', v_before.default_safety_stock, 'low_stock_alert', v_before.low_stock_alert),
    jsonb_build_object('company_name', v_row.company_name, 'default_safety_stock', v_row.default_safety_stock, 'low_stock_alert', v_row.low_stock_alert));
  return v_row;
end;
$$;

-- 가입 요청(승인제): 로그인한 사용자(프로필 pending 포함)가 가입 코드로 요청한다.
create or replace function public.request_join(p_join_code text, p_applicant_name text, p_message text default null)
returns public.join_requests
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid; v_row public.join_requests;
begin
  if auth.uid() is null then
    raise exception 'request_join: login required' using errcode = '42501';
  end if;
  select w.org_id into v_org from public.join_codes j join public.workspaces w on w.org_id = j.org_id
  where j.join_code = upper(btrim(p_join_code)) and w.status = 'active';
  if v_org is null then
    raise exception 'request_join: invalid join code' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.org_members m where m.org_id = v_org and m.user_id = auth.uid() and m.status in ('active', 'invited')) then
    raise exception 'request_join: already a member or invited' using errcode = 'ER005';
  end if;
  select * into v_row from public.join_requests r where r.org_id = v_org and r.user_id = auth.uid() and r.status = 'pending';
  if found then
    return v_row;
  end if;
  insert into public.join_requests (org_id, user_id, applicant_name, message)
  values (v_org, auth.uid(), btrim(p_applicant_name), p_message)
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.cancel_join_request(p_request_id uuid)
returns public.join_requests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.join_requests;
begin
  update public.join_requests set status = 'canceled'
  where id = p_request_id and user_id = auth.uid() and status = 'pending'
  returning * into v_row;
  if not found then
    raise exception 'cancel_join_request: no pending request' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- 가입 요청 결정(master_admin). 승인 시 public.invite_member 로 초대 멤버십(invited)을 만들고 employees 행을 만든다.
-- 신청자는 public.accept_invite 로 활성화한다. 프로필 pending 해제(public.approve_profile)는 서버(service_role)가 이어서 수행한다.
create or replace function public.decide_join_request(
  p_request_id    uuid,
  p_approve       boolean,
  p_erp_role      text default 'staff',
  p_department_id uuid default null,
  p_note          text default null
)
returns public.join_requests
language plpgsql
security definer
set search_path = ''
as $$
declare v_req public.join_requests; v_name text;
begin
  select * into v_req from public.join_requests where id = p_request_id for update;
  if not found then
    raise exception 'decide_join_request: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_req.org_id, array['master_admin']) then
    raise exception 'decide_join_request: master_admin only' using errcode = '42501';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'decide_join_request: request is %', v_req.status using errcode = 'ER002';
  end if;

  if p_approve then
    if coalesce(p_erp_role, '') not in ('inventory_manager', 'sales_manager', 'staff') then
      raise exception 'decide_join_request: invalid erp_role' using errcode = '22023';
    end if;
    if p_department_id is not null and not exists (select 1 from public.departments d where d.id = p_department_id and d.org_id = v_req.org_id) then
      raise exception 'decide_join_request: department not in organization' using errcode = '22023';
    end if;
    perform public.invite_member(v_req.org_id, v_req.user_id, 'member');
    v_name := v_req.applicant_name;
    insert into public.employees (org_id, user_id, display_name, department_id, erp_role, status)
    values (v_req.org_id, v_req.user_id, v_name, p_department_id, p_erp_role, 'active')
    on conflict (org_id, user_id) do update
      set erp_role = excluded.erp_role, department_id = excluded.department_id, status = 'active', display_name = excluded.display_name;
    update public.join_requests set status = 'approved', decided_by = auth.uid(), decided_at = now(), decision_note = p_note
    where id = p_request_id returning * into v_req;
    perform public.write_audit(v_req.org_id, 'join_request.approve', 'user', v_req.user_id::text, null,
                             jsonb_build_object('erp_role', p_erp_role, 'department_id', p_department_id));
  else
    update public.join_requests set status = 'rejected', decided_by = auth.uid(), decided_at = now(), decision_note = p_note
    where id = p_request_id returning * into v_req;
    perform public.write_audit(v_req.org_id, 'join_request.reject', 'user', v_req.user_id::text);
  end if;
  return v_req;
end;
$$;

-- ERP 역할 변경(master_admin). 자기 자신 불가, core owner/admin 대상 불가(그들의 권한은 core 역할로 관리).
create or replace function public.set_employee_role(p_org_id uuid, p_user_id uuid, p_erp_role text)
returns public.employees
language plpgsql
security definer
set search_path = ''
as $$
declare v_before public.employees; v_row public.employees;
begin
  if not public.is_service_caller() then
    if not public.has_role(p_org_id, array['master_admin']) then
      raise exception 'set_employee_role: master_admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'set_employee_role: cannot change your own role' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_erp_role, '') not in ('inventory_manager', 'sales_manager', 'staff') then
    raise exception 'set_employee_role: invalid erp_role' using errcode = '22023';
  end if;
  select * into v_before from public.employees where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'set_employee_role: employee not found' using errcode = 'P0002';
  end if;
  update public.employees set erp_role = p_erp_role where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform public.write_audit(p_org_id, 'employee.role', 'user', p_user_id::text,
                           jsonb_build_object('erp_role', v_before.erp_role), jsonb_build_object('erp_role', p_erp_role));
  return v_row;
end;
$$;

create or replace function public.set_employee_status(p_org_id uuid, p_user_id uuid, p_status text)
returns public.employees
language plpgsql
security definer
set search_path = ''
as $$
declare v_before public.employees; v_row public.employees;
begin
  if not public.is_service_caller() then
    if not public.has_role(p_org_id, array['master_admin']) then
      raise exception 'set_employee_status: master_admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'set_employee_status: cannot change your own status' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_status, '') not in ('active', 'suspended') then
    raise exception 'set_employee_status: invalid status' using errcode = '22023';
  end if;
  if exists (select 1 from public.org_members m where m.org_id = p_org_id and m.user_id = p_user_id and m.role in ('owner', 'admin')) then
    raise exception 'set_employee_status: change the core role of owner/admin first' using errcode = '42501';
  end if;
  select * into v_before from public.employees where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'set_employee_status: employee not found' using errcode = 'P0002';
  end if;
  update public.employees set status = p_status where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform public.write_audit(p_org_id, 'employee.status', 'user', p_user_id::text,
                           jsonb_build_object('status', v_before.status), jsonb_build_object('status', p_status));
  return v_row;
end;
$$;

-- 인사 정보 수정(master_admin): 부서, 직급, 연락처, 표시 이름
create or replace function public.update_employee_profile(
  p_org_id uuid, p_user_id uuid, p_department_id uuid, p_position text, p_phone text, p_display_name text
)
returns public.employees
language plpgsql
security definer
set search_path = ''
as $$
declare v_before public.employees; v_row public.employees;
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['master_admin']) then
    raise exception 'update_employee_profile: master_admin only' using errcode = '42501';
  end if;
  if p_department_id is not null and not exists (select 1 from public.departments d where d.id = p_department_id and d.org_id = p_org_id) then
    raise exception 'update_employee_profile: department not in organization' using errcode = '22023';
  end if;
  select * into v_before from public.employees where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'update_employee_profile: employee not found' using errcode = 'P0002';
  end if;
  update public.employees
  set department_id = p_department_id, position = nullif(btrim(p_position), ''), phone = nullif(btrim(p_phone), ''),
      display_name = coalesce(nullif(btrim(p_display_name), ''), display_name)
  where org_id = p_org_id and user_id = p_user_id
  returning * into v_row;
  perform public.write_audit(p_org_id, 'employee.update', 'user', p_user_id::text,
    jsonb_build_object('department_id', v_before.department_id, 'position', v_before.position),
    jsonb_build_object('department_id', v_row.department_id, 'position', v_row.position));
  return v_row;
end;
$$;

-- 본인 연락처 수정(역할/상태/부서는 바꿀 수 없다)
create or replace function public.update_my_contact(p_org_id uuid, p_phone text)
returns public.employees
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.employees;
begin
  if not public.has_access(p_org_id) then
    raise exception 'update_my_contact: no access' using errcode = '42501';
  end if;
  update public.employees set phone = nullif(btrim(p_phone), '')
  where org_id = p_org_id and user_id = auth.uid()
  returning * into v_row;
  if not found then
    raise exception 'update_my_contact: employee not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- 입출고/조정. IN/OUT 은 양수 수량, ADJUSTMENT 는 부호 있는 수량(감소 조정 허용, 리뷰 ERP #14).
-- 권한: master_admin, inventory_manager 는 전부. sales_manager 는 OUT 만(제안, PRD 3.1 "제한적 접근").
create or replace function public.record_inventory_move(
  p_product_id uuid, p_move_type text, p_quantity integer, p_reason text default null, p_request_id text default null
)
returns public.inventory_moves
language plpgsql
security definer
set search_path = ''
as $$
declare v_prod public.products; v_delta integer; v_row public.inventory_moves;
begin
  select * into v_prod from public.products where id = p_product_id for update;
  if not found then
    raise exception 'record_inventory_move: product not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() then
    if not (public.has_role(v_prod.org_id, array['master_admin', 'inventory_manager'])
            or (p_move_type = 'OUT' and public.has_role(v_prod.org_id, array['sales_manager']))) then
      raise exception 'record_inventory_move: role not allowed' using errcode = '42501';
    end if;
  end if;
  if p_request_id is not null then
    perform pg_advisory_xact_lock(hashtext('erp:move:' || v_prod.org_id::text || ':' || p_request_id));
    select * into v_row from public.inventory_moves m where m.org_id = v_prod.org_id and m.request_id = p_request_id;
    if found then
      return v_row;
    end if;
  end if;
  if coalesce(p_move_type, '') not in ('IN', 'OUT', 'ADJUSTMENT') then
    raise exception 'record_inventory_move: move_type must be IN/OUT/ADJUSTMENT' using errcode = '22023';
  end if;
  if p_quantity is null or p_quantity = 0 or (p_move_type in ('IN', 'OUT') and p_quantity < 0) then
    raise exception 'record_inventory_move: invalid quantity' using errcode = '22023';
  end if;
  if p_move_type = 'ADJUSTMENT' and char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'record_inventory_move: reason required for ADJUSTMENT' using errcode = '22023';
  end if;
  v_delta := case p_move_type when 'OUT' then -p_quantity else p_quantity end;
  if v_prod.quantity + v_delta < 0 then
    raise exception 'record_inventory_move: insufficient stock (have %, change %)', v_prod.quantity, v_delta using errcode = 'ER001';
  end if;
  update public.products set quantity = quantity + v_delta where id = p_product_id;
  insert into public.inventory_moves (org_id, product_id, move_type, quantity_delta, quantity_after, reason, request_id, created_by)
  values (v_prod.org_id, p_product_id, p_move_type, v_delta, v_prod.quantity + v_delta, nullif(btrim(p_reason), ''), p_request_id, auth.uid())
  returning * into v_row;
  if p_move_type = 'ADJUSTMENT' then
    perform public.write_audit(v_prod.org_id, 'inventory.adjust', 'product', p_product_id::text,
                             jsonb_build_object('quantity', v_prod.quantity), jsonb_build_object('quantity', v_row.quantity_after, 'reason', v_row.reason));
  end if;
  return v_row;
end;
$$;

-- 판매 등록. completed 면 조건부 UPDATE(quantity >= n)로 원자 차감 + SALE 이력. pending 이면 재고 변화 없음.
-- 단가는 상품 단가로 고정(클라이언트 금액을 믿지 않는다). request_id 로 멱등.
create or replace function public.record_sale(p_product_id uuid, p_quantity integer, p_request_id text, p_status text default 'completed')
returns public.sales
language plpgsql
security definer
set search_path = ''
as $$
declare v_prod public.products; v_sale public.sales; v_after integer;
begin
  select * into v_prod from public.products where id = p_product_id;
  if not found then
    raise exception 'record_sale: product not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_prod.org_id, array['master_admin', 'sales_manager']) then
    raise exception 'record_sale: master_admin/sales_manager only' using errcode = '42501';
  end if;
  if p_request_id is null or char_length(p_request_id) not between 8 and 100 then
    raise exception 'record_sale: request_id required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('erp:sale:' || v_prod.org_id::text || ':' || p_request_id));
  select * into v_sale from public.sales s where s.org_id = v_prod.org_id and s.request_id = p_request_id;
  if found then
    return v_sale;
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'record_sale: quantity must be positive' using errcode = '22023';
  end if;
  if coalesce(p_status, '') not in ('completed', 'pending') then
    raise exception 'record_sale: status must be completed or pending' using errcode = '22023';
  end if;
  if not v_prod.is_active then
    raise exception 'record_sale: product is inactive' using errcode = 'ER003';
  end if;

  if p_status = 'completed' then
    update public.products set quantity = quantity - p_quantity
    where id = p_product_id and quantity >= p_quantity
    returning quantity into v_after;
    if not found then
      raise exception 'record_sale: insufficient stock' using errcode = 'ER001';
    end if;
  end if;

  insert into public.sales (org_id, product_id, quantity, unit_price, status, sold_by, completed_at, request_id)
  values (v_prod.org_id, p_product_id, p_quantity, v_prod.price, p_status, auth.uid(),
          case when p_status = 'completed' then now() end, p_request_id)
  returning * into v_sale;

  if p_status = 'completed' then
    insert into public.inventory_moves (org_id, product_id, move_type, quantity_delta, quantity_after, reason, sale_id, created_by)
    values (v_prod.org_id, p_product_id, 'SALE', -p_quantity, v_after, null, v_sale.id, auth.uid());
  end if;
  return v_sale;
end;
$$;

-- pending → completed (재고 차감)
create or replace function public.complete_sale(p_sale_id uuid)
returns public.sales
language plpgsql
security definer
set search_path = ''
as $$
declare v_sale public.sales; v_after integer;
begin
  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then
    raise exception 'complete_sale: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_sale.org_id, array['master_admin', 'sales_manager']) then
    raise exception 'complete_sale: master_admin/sales_manager only' using errcode = '42501';
  end if;
  if v_sale.status <> 'pending' then
    raise exception 'complete_sale: sale is %', v_sale.status using errcode = 'ER002';
  end if;
  update public.products set quantity = quantity - v_sale.quantity
  where id = v_sale.product_id and quantity >= v_sale.quantity
  returning quantity into v_after;
  if not found then
    raise exception 'complete_sale: insufficient stock' using errcode = 'ER001';
  end if;
  update public.sales set status = 'completed', completed_at = now() where id = p_sale_id returning * into v_sale;
  insert into public.inventory_moves (org_id, product_id, move_type, quantity_delta, quantity_after, sale_id, created_by)
  values (v_sale.org_id, v_sale.product_id, 'SALE', -v_sale.quantity, v_after, v_sale.id, auth.uid());
  return v_sale;
end;
$$;

-- 판매 취소. completed 면 재고 복원(SALE_CANCEL 이력). 사유 필수.
create or replace function public.cancel_sale(p_sale_id uuid, p_reason text)
returns public.sales
language plpgsql
security definer
set search_path = ''
as $$
declare v_sale public.sales; v_prev text; v_after integer;
begin
  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then
    raise exception 'cancel_sale: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_sale.org_id, array['master_admin', 'sales_manager']) then
    raise exception 'cancel_sale: master_admin/sales_manager only' using errcode = '42501';
  end if;
  if v_sale.status = 'canceled' then
    raise exception 'cancel_sale: already canceled' using errcode = 'ER002';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'cancel_sale: reason required' using errcode = '22023';
  end if;
  v_prev := v_sale.status;
  if v_prev = 'completed' then
    update public.products set quantity = quantity + v_sale.quantity where id = v_sale.product_id returning quantity into v_after;
    insert into public.inventory_moves (org_id, product_id, move_type, quantity_delta, quantity_after, reason, sale_id, created_by)
    values (v_sale.org_id, v_sale.product_id, 'SALE_CANCEL', v_sale.quantity, v_after, btrim(p_reason), v_sale.id, auth.uid());
  end if;
  update public.sales set status = 'canceled', canceled_at = now(), canceled_by = auth.uid(), cancel_reason = btrim(p_reason)
  where id = p_sale_id returning * into v_sale;
  perform public.write_audit(v_sale.org_id, 'sale.cancel', 'sale', p_sale_id::text,
                           jsonb_build_object('status', v_prev), jsonb_build_object('status', 'canceled', 'reason', v_sale.cancel_reason));
  return v_sale;
end;
$$;

-- 대시보드 지표(접근 가능한 전원). "오늘" = KST 자정 경계(리뷰 ERP #11).
create or replace function public.dashboard_metrics(p_org_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := (date_trunc('day', now() at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul';
  v_end   timestamptz := ((date_trunc('day', now() at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul') + interval '1 day';
  v_result jsonb;
begin
  if not public.is_service_caller() and not public.has_access(p_org_id) then
    raise exception 'dashboard_metrics: no access' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'kst_day_start', v_start,
    'today_sales_total', coalesce((select sum(s.total_price) from public.sales s
                                    where s.org_id = p_org_id and s.status = 'completed'
                                      and s.completed_at >= v_start and s.completed_at < v_end), 0),
    'today_sales_count', (select count(*) from public.sales s
                          where s.org_id = p_org_id and s.status = 'completed'
                            and s.completed_at >= v_start and s.completed_at < v_end),
    'today_canceled_count', (select count(*) from public.sales s
                             where s.org_id = p_org_id and s.status = 'canceled'
                               and s.canceled_at >= v_start and s.canceled_at < v_end),
    'sku_count', (select count(*) from public.products p where p.org_id = p_org_id and p.is_active),
    'low_stock_count', (select count(*) from public.products p where p.org_id = p_org_id and p.is_active and p.is_low_stock),
    'active_employees', (select count(*) from public.employees e where e.org_id = p_org_id and e.status = 'active'),
    'low_stock_items', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'sku', x.sku, 'name', x.name,
                                                                     'quantity', x.quantity, 'safety_stock', x.safety_stock))
                                 from (select p.id, p.sku, p.name, p.quantity, p.safety_stock from public.products p
                                       where p.org_id = p_org_id and p.is_active and p.is_low_stock
                                       order by (p.quantity - p.safety_stock), p.name limit 5) x), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

-- 판매 추이(KST 버킷). 기간 상한 366일.
create or replace function public.sales_trend(p_org_id uuid, p_from timestamptz, p_to timestamptz, p_bucket text default 'hour')
returns table (bucket_start timestamptz, total numeric, sale_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['master_admin', 'sales_manager']) then
    raise exception 'sales_trend: master_admin/sales_manager only' using errcode = '42501';
  end if;
  if coalesce(p_bucket, '') not in ('hour', 'day', 'month') or p_from is null or p_to is null
     or p_to <= p_from or p_to - p_from > interval '366 days' then
    raise exception 'sales_trend: invalid range or bucket' using errcode = '22023';
  end if;
  return query
    select (date_trunc(p_bucket, s.completed_at at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul' as bucket_start,
           sum(s.total_price) as total,
           count(*) as sale_count
    from public.sales s
    where s.org_id = p_org_id and s.status = 'completed' and s.completed_at >= p_from and s.completed_at < p_to
    group by 1
    order by 1;
end;
$$;

-- 사용자용 RPC EXECUTE 정리
do $$
declare s text;
begin
  foreach s in array array[
    'public.get_join_code(uuid)', 'public.rotate_join_code(uuid)', 'public.update_workspace_settings(uuid,text,integer,boolean)',
    'public.request_join(text,text,text)', 'public.cancel_join_request(uuid)',
    'public.decide_join_request(uuid,boolean,text,uuid,text)',
    'public.set_employee_role(uuid,uuid,text)', 'public.set_employee_status(uuid,uuid,text)',
    'public.update_employee_profile(uuid,uuid,uuid,text,text,text)', 'public.update_my_contact(uuid,text)',
    'public.record_inventory_move(uuid,text,integer,text,text)', 'public.record_sale(uuid,integer,text,text)',
    'public.complete_sale(uuid)', 'public.cancel_sale(uuid,text)',
    'public.dashboard_metrics(uuid)', 'public.sales_trend(uuid,timestamptz,timestamptz,text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', s);
    execute format('grant execute on function %s to authenticated, service_role', s);
  end loop;
end $$;

-- =====================================================================
-- 5. Realtime (RLS 하에서 postgres_changes). 채널 이름 erp:<org>:<entity>
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['products', 'inventory_moves', 'sales'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- =====================================================================
-- 6. PUBLIC EXECUTE 회수 (0007_core_function_privileges.sql 와 같은 규칙)
--   alter default privileges ... revoke from public 은 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 지우지 못한다.
--   이 스키마의 모든 함수에서 PUBLIC 을 회수한다. 위에서 authenticated/service_role 에 준 명시 GRANT 는 유지된다.
-- =====================================================================
revoke execute on all functions in schema public from public;
grant execute on all functions in schema public to service_role;
