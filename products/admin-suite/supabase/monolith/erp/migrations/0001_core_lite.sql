-- =====================================================================
-- admin-suite / erp 모놀리스 0001_core_lite.sql
-- _platform-core/MONOLITH_CORE_LITE.sql 의 복사본이다. [필수] 절은 바꾸지 않았다.
-- 제거한 [선택] 절: SECTION 4, SECTION 6-A, SECTION 6-B, SECTION 7, SECTION 9
-- 수정: SECTION 3 confirm_payment_order 의 credit_pack 분기를 지웠다(SECTION 4 제거에 따른 lite 지침).
-- 이유는 각 제거 위치의 주석과 docs/products/admin-suite/05_DATA_MODEL.md 8절에 있다.
-- =====================================================================

-- =====================================================================
-- MONOLITH_CORE_LITE.sql
-- 제품별 단독 Supabase 프로젝트(모놀리스)용 코어. 한 파일로 묶은 축소판.
-- 원본: docs/products/_supabase-modular/migrations/0000 ~ 0006 (모듈러 core 스키마)
--
-- 스키마 선택: public
--   - ARCHITECTURE.md:10 "차이는 스키마 접두사(core. 대 public.)뿐" 원칙을 그대로 따른다.
--   - 모놀리스는 PostgREST 노출 스키마 설정 없이 바로 쓸 수 있어야 한다(public은 기본 노출).
--   - 제품 도메인 테이블도 public에 두므로 정책이 public.is_org_member(...) 하나로 통일된다.
--   - 함수 이름과 시그니처는 모듈러 core.*와 같다. 앱 코드는 SUPABASE_DB_SCHEMA 환경변수로 전환한다.
--
-- 사용법 (제품 에이전트)
--   1) 이 파일을 <제품>/supabase/monolith/migrations/0001_core_lite.sql 로 복사한다.
--   2) [선택] 표시가 붙은 절(SECTION)은 제품에 필요 없으면 절 전체를 지운다.
--      절 머리의 "의존" 표를 보고 지울 때 함께 지울 줄을 확인한다.
--   3) [필수] 절은 지우지 않는다. 바꾸지도 않는다(코어 변경은 _platform-core 담당).
--   4) 마지막 "SECTION 10 권한 정리"는 to_regclass / to_regprocedure 로 존재하는 객체에만
--      권한을 주므로 절을 지워도 그대로 동작한다.
--
-- 모듈러(0000~0006)와 다른 점 (DB_CONVENTIONS.md 9장에도 정리)
--   a) 스키마 public. Supabase가 public에 기본으로 주는 anon/authenticated 권한을 이 파일이 회수한다.
--   b) 가입 트리거: signup_app 메타데이터가 없고 apps 행이 정확히 1개면 그 앱으로 자동 부트스트랩한다.
--   c) run_monthly_credit_grants()를 run_subscription_rollover()(SECTION 2) + 크레딧 지급(SECTION 4)으로
--      나눠, 크레딧 절을 지워도 구독 기간 굴림과 해지 만료가 남는다.
--   d) RLS 정책을 테이블이 있는 절 안에 둔다(모듈러는 0004에 모아 둠). 절 단위 삭제를 위해서다.
--
-- 보안 규칙 (SECURITY_BASELINE.md)
--   - 쓰기는 service_role 또는 SECURITY DEFINER RPC만. 사용자(authenticated)에게는 SELECT 정책만.
--   - 사용자에게 EXECUTE를 연 SECURITY DEFINER 함수 안의 호출자 판정은 is_service_caller() 만 쓴다.
--     is_privileged_session()은 DEFINER 안에서 항상 true(current_user = 함수 소유자)라서 검사가 통째로 건너뛰어진다.
--   - 역할 비교는 coalesce(role, '') 로 NULL-safe 하게 한다. 비멤버의 역할은 NULL이고
--     NULL not in (...) 은 NULL이라 분기가 건너뛰어진다.
--   - EXECUTE 권한이 1차 잠금, 함수 안 검사가 2차 잠금, guard 트리거가 3차 잠금이다.
--
-- PostgreSQL 15 / Supabase 표준 객체만 사용. 반복 실행해도 안전하다.
-- =====================================================================


-- =====================================================================
-- SECTION 0. 확장, 기본 권한, 공용 헬퍼  [필수]
-- 원본: 0000_core_extensions_and_schema.sql
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;
-- pg_cron은 호스팅 대시보드에서 켠다. 로컬 선택 사항.
-- create extension if not exists pg_cron;

grant usage on schema public to anon, authenticated, service_role;

-- Supabase는 public에 만들어지는 테이블/함수/시퀀스에 anon, authenticated 전체 권한을 기본으로 준다.
-- 이 코어는 "쓰기는 service_role만" 원칙이므로 기본 권한을 회수하고 절마다 SELECT만 명시적으로 준다.
-- (모듈러 core 스키마에는 이런 기본 권한이 없어서 이 줄이 필요 없었다.)
alter default privileges in schema public revoke all on tables from anon, authenticated, public;
alter default privileges in schema public revoke all on sequences from anon, authenticated, public;
alter default privileges in schema public revoke execute on functions from anon, authenticated, public;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;

-- updated_at 갱신 트리거
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- 세션 헬퍼
--   jwt_role()              : PostgREST 요청의 JWT role ('anon' | 'authenticated' | 'service_role' | 'none')
--   is_privileged_session() : service_role 요청 또는 DB 소유 세션(마이그레이션, pg_cron, SECURITY DEFINER 내부)
--                             → guard 트리거와 "EXECUTE가 service_role에만 있는" RPC 에서만 쓴다.
--   is_service_caller()     : 실제 호출자가 service_role 이거나 JWT 없는 DB 관리 세션
--                             → authenticated 에 EXECUTE 를 연 DEFINER 함수 안에서는 반드시 이것을 쓴다.
create or replace function public.jwt_role()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
    'none'
  );
$$;

create or replace function public.is_privileged_session()
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.jwt_role() = 'service_role'
      or current_user in ('postgres', 'supabase_admin', 'supabase_auth_admin');
$$;

-- session_user 는 SECURITY DEFINER 안에서도 바뀌지 않는다. PostgREST 요청은 session_user 가
-- authenticator 이고 JWT role 이 항상 있으므로, JWT 없는 관리 세션만 두 번째 조건으로 통과한다.
create or replace function public.is_service_caller()
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.jwt_role() = 'service_role'
      or (public.jwt_role() = 'none' and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin'));
$$;

-- 쓰기 보호 트리거: service_role 또는 DB 소유 세션이 아니면 어떤 쓰기도 거부(이중 잠금)
create or replace function public.guard_privileged_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not public.is_privileged_session() then
    raise exception 'core: % on %.% is allowed only for service_role', tg_op, tg_table_schema, tg_table_name
      using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;


-- =====================================================================
-- SECTION 1. 신원: profiles, organizations, org_members, 가입 트리거  [필수]
-- 원본: 0001_core_identity.sql
-- 테넌시는 org 기준, 운영은 1인 1워크스페이스(확정 결정 5). 가입 시 개인 조직을 자동 생성한다.
-- =====================================================================

create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text,
  display_name  text not null default '',
  avatar_url    text,
  locale        text not null default 'ko',
  platform_role text not null default 'user'
                constraint profiles_platform_role_check check (platform_role in ('user', 'platform_admin')),
  status        text not null default 'active'
                constraint profiles_status_check check (status in ('active', 'pending', 'suspended')),
  last_seen_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on column public.profiles.platform_role is '플랫폼 운영자 여부. service_role만 변경 가능';
comment on column public.profiles.status is '승인제 앱에서 pending으로 시작. service_role 또는 approve_profile()만 변경 가능';

create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null constraint organizations_name_check check (char_length(name) between 1 and 80),
  slug        text not null unique constraint organizations_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  owner_id    uuid not null references auth.users(id) on delete cascade,
  is_personal boolean not null default true,
  settings    jsonb not null default '{}'::jsonb,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists organizations_owner_idx on public.organizations (owner_id);

create table if not exists public.org_members (
  org_id     uuid not null references public.organizations(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null default 'member'
             constraint org_members_role_check check (role in ('owner', 'admin', 'member', 'viewer')),
  status     text not null default 'active'
             constraint org_members_status_check check (status in ('active', 'invited', 'pending', 'suspended')),
  invited_by uuid references auth.users(id) on delete set null,
  joined_at  timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, user_id)
);
create index if not exists org_members_user_active_idx on public.org_members (user_id) where status = 'active';
create unique index if not exists org_members_single_owner_idx on public.org_members (org_id) where role = 'owner';

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
drop trigger if exists organizations_set_updated_at on public.organizations;
create trigger organizations_set_updated_at before update on public.organizations
  for each row execute function public.set_updated_at();
drop trigger if exists org_members_set_updated_at on public.org_members;
create trigger org_members_set_updated_at before update on public.org_members
  for each row execute function public.set_updated_at();

alter table public.profiles      enable row level security;
alter table public.organizations enable row level security;
alter table public.org_members   enable row level security;

-- org_members 직접 쓰기는 service_role만(이중 잠금). 멤버 관리는 SECTION 5의 함수로.
drop trigger if exists org_members_guard_write on public.org_members;
create trigger org_members_guard_write before insert or update or delete on public.org_members
  for each row execute function public.guard_privileged_write();

-- 앱 부트스트랩 스텁. SECTION 2(플랜/엔타이틀먼트), SECTION 4(크레딧)에서 순서대로 교체된다.
create or replace function public.on_signup_app_bootstrap(p_org_id uuid, p_user_id uuid, p_app_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  return;
end;
$$;

-- 가입 트리거
--   1) profiles  2) 개인 조직 + owner 멤버십  3) 앱 부트스트랩
--   모놀리스 차이: raw_user_meta_data.signup_app 이 없고 apps 행이 정확히 1개면 그 앱으로 부트스트랩한다.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_name   text;
  v_app    text;
begin
  v_name := coalesce(
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'user'
  );
  v_app := nullif(new.raw_user_meta_data ->> 'signup_app', '');

  insert into public.profiles (id, email, display_name, avatar_url)
  values (new.id, new.email, left(v_name, 80), new.raw_user_meta_data ->> 'avatar_url')
  on conflict (id) do nothing;

  insert into public.organizations (name, slug, owner_id, is_personal)
  values (left(v_name, 80), 'u' || replace(new.id::text, '-', ''), new.id, true)
  on conflict (slug) do nothing
  returning id into v_org_id;

  if v_org_id is null then
    select id into v_org_id from public.organizations where slug = 'u' || replace(new.id::text, '-', '');
  end if;

  insert into public.org_members (org_id, user_id, role, status, joined_at)
  values (v_org_id, new.id, 'owner', 'active', now())
  on conflict (org_id, user_id) do nothing;

  if v_app is null and to_regclass('public.apps') is not null then
    -- apps 행이 정확히 1개일 때만 그 앱으로. 2개 이상이면 signup_app 을 요구한다(모듈러와 같은 동작).
    select min(a.id) into v_app from public.apps a where a.status <> 'disabled'
    having count(*) = 1;
  end if;

  -- 초대제(invite) 앱은 가입만으로 이용 권한을 만들지 않는다.
  -- 운영자가 서버(service_role)에서 bootstrap_app_for_org로 부여하거나, 초대받은 조직의 권한을 쓴다.
  if v_app is not null and to_regclass('public.apps') is not null then
    if exists (select 1 from public.apps a where a.id = v_app and a.signup_policy = 'invite') then
      v_app := null;
    end if;
  end if;

  if v_app is not null then
    perform public.on_signup_app_bootstrap(v_org_id, new.id, v_app);
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 현재 사용자의 개인 조직 id (SECURITY INVOKER)
create or replace function public.personal_org_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select o.id
  from public.organizations o
  where o.owner_id = auth.uid() and o.is_personal and o.deleted_at is null
  order by o.created_at
  limit 1;
$$;


-- =====================================================================
-- SECTION 5-A. RLS 헬퍼, 권한 컬럼 보호, audit_log, 멤버 관리  [필수]
-- 원본: 0004_core_security.sql 1~4절
-- 정책이 헬퍼를 쓰므로 테이블 절(2~9)보다 먼저 둔다.
-- 헬퍼는 모두 SECURITY DEFINER + set search_path='' + STABLE. 정책 안에서 org_members 를
-- 다시 조회할 때 생기는 재귀(42P17)를 끊는다.
-- =====================================================================

create or replace function public.current_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.org_id
  from public.org_members m
  where m.user_id = auth.uid() and m.status = 'active';
$$;

create or replace function public.is_org_member(org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    where m.org_id = org and m.user_id = auth.uid() and m.status = 'active'
  );
$$;

create or replace function public.has_org_role(org uuid, roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    where m.org_id = org and m.user_id = auth.uid() and m.status = 'active' and m.role = any (roles)
  );
$$;

create or replace function public.current_org_role(org uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role from public.org_members m
  where m.org_id = org and m.user_id = auth.uid() and m.status = 'active';
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.platform_role = 'platform_admin' and p.status = 'active'
  );
$$;

-- 권한 컬럼 보호 트리거: 컬럼 단위 GRANT가 1차, 이 트리거가 2차
create or replace function public.guard_profile_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_privileged_session() then
    return new;
  end if;
  if new.platform_role is distinct from old.platform_role
     or new.status is distinct from old.status
     or new.email is distinct from old.email
     or new.id is distinct from old.id then
    raise exception 'profiles: privileged columns can only be changed by service_role' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_guard_columns on public.profiles;
create trigger profiles_guard_columns before update on public.profiles
  for each row execute function public.guard_profile_columns();

create or replace function public.guard_organization_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_privileged_session() then
    return new;
  end if;
  if tg_op = 'UPDATE' and (
       new.owner_id is distinct from old.owner_id
    or new.is_personal is distinct from old.is_personal
    or new.deleted_at is distinct from old.deleted_at
    or new.slug is distinct from old.slug
    or new.id is distinct from old.id) then
    raise exception 'organizations: privileged columns can only be changed by service_role' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists organizations_guard_columns on public.organizations;
create trigger organizations_guard_columns before update on public.organizations
  for each row execute function public.guard_organization_columns();

-- audit_log (append-only)
create table if not exists public.audit_log (
  id          bigint generated always as identity primary key,
  org_id      uuid,
  actor_id    uuid,
  actor_role  text not null default 'user' constraint audit_log_actor_role_check check (actor_role in ('user', 'service', 'system')),
  action      text not null,
  target_type text,
  target_id   text,
  before      jsonb,
  after       jsonb,
  metadata    jsonb not null default '{}'::jsonb,
  ip          inet,
  user_agent  text,
  request_id  text,
  created_at  timestamptz not null default now()
);
create index if not exists audit_log_org_created_idx on public.audit_log (org_id, created_at desc);
create index if not exists audit_log_actor_idx on public.audit_log (actor_id, created_at desc);
create index if not exists audit_log_target_idx on public.audit_log (target_type, target_id);

create or replace function public.audit_log_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and public.is_privileged_session() then
    return old;
  end if;
  raise exception 'audit_log is append-only (%)', tg_op using errcode = 'AU000';
end;
$$;
drop trigger if exists audit_log_immutable on public.audit_log;
create trigger audit_log_immutable before update or delete on public.audit_log
  for each row execute function public.audit_log_immutable();
drop trigger if exists audit_log_guard_write on public.audit_log;
create trigger audit_log_guard_write before insert on public.audit_log
  for each row execute function public.guard_privileged_write();
alter table public.audit_log enable row level security;

-- 사용자 세션에서 감사 기록을 남기는 유일한 경로. actor 는 auth.uid() 로 강제.
create or replace function public.write_audit(
  p_org_id      uuid,
  p_action      text,
  p_target_type text  default null,
  p_target_id   text  default null,
  p_before      jsonb default null,
  p_after       jsonb default null,
  p_metadata    jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_id bigint;
begin
  if not public.is_service_caller() then
    if auth.uid() is null or (p_org_id is not null and not public.is_org_member(p_org_id)) then
      raise exception 'write_audit: not a member of the organization' using errcode = '42501';
    end if;
  end if;
  insert into public.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, before, after, metadata)
  values (p_org_id, auth.uid(),
          case when public.jwt_role() = 'service_role' then 'service' when auth.uid() is null then 'system' else 'user' end,
          p_action, p_target_type, p_target_id, p_before, p_after, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;

-- 멤버 관리 (SECURITY DEFINER, authenticated 호출 가능, 안에서 역할 검사: is_service_caller + coalesce)
create or replace function public.invite_member(p_org_id uuid, p_user_id uuid, p_role text default 'member')
returns public.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller_role text; v_row public.org_members;
begin
  v_caller_role := public.current_org_role(p_org_id);
  if not public.is_service_caller() then
    if coalesce(v_caller_role, '') not in ('owner', 'admin') then
      raise exception 'invite_member: owner/admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'invite_member: cannot invite yourself' using errcode = '22023';
    end if;
  end if;
  if p_role not in ('admin', 'member', 'viewer') then
    raise exception 'invite_member: role must be admin/member/viewer' using errcode = '22023';
  end if;
  if v_caller_role = 'admin' and p_role = 'admin' then
    raise exception 'invite_member: admin cannot grant admin' using errcode = '42501';
  end if;

  insert into public.org_members (org_id, user_id, role, status, invited_by)
  values (p_org_id, p_user_id, p_role, 'invited', auth.uid())
  on conflict (org_id, user_id) do update
    set role = excluded.role, status = case when public.org_members.status = 'active' then 'active' else 'invited' end,
        invited_by = excluded.invited_by
  returning * into v_row;

  perform public.write_audit(p_org_id, 'org_member.invite', 'user', p_user_id::text, null, jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function public.accept_invite(p_org_id uuid)
returns public.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.org_members;
begin
  update public.org_members
  set status = 'active', joined_at = now()
  where org_id = p_org_id and user_id = auth.uid() and status = 'invited'
  returning * into v_row;
  if not found then
    raise exception 'accept_invite: no pending invitation' using errcode = 'P0002';
  end if;
  perform public.write_audit(p_org_id, 'org_member.accept', 'user', auth.uid()::text);
  return v_row;
end;
$$;

create or replace function public.approve_member(p_org_id uuid, p_user_id uuid)
returns public.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.org_members;
begin
  if not public.is_service_caller() and not public.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'approve_member: owner/admin only' using errcode = '42501';
  end if;
  update public.org_members set status = 'active', joined_at = coalesce(joined_at, now())
  where org_id = p_org_id and user_id = p_user_id and status = 'pending'
  returning * into v_row;
  if not found then
    raise exception 'approve_member: no pending member' using errcode = 'P0002';
  end if;
  perform public.write_audit(p_org_id, 'org_member.approve', 'user', p_user_id::text);
  return v_row;
end;
$$;

create or replace function public.change_member_role(p_org_id uuid, p_user_id uuid, p_role text)
returns public.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller_role text; v_target public.org_members; v_row public.org_members;
begin
  v_caller_role := public.current_org_role(p_org_id);
  if not public.is_service_caller() then
    if coalesce(v_caller_role, '') not in ('owner', 'admin') then
      raise exception 'change_member_role: owner/admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'change_member_role: cannot change your own role' using errcode = '42501';
    end if;
  end if;
  if p_role not in ('admin', 'member', 'viewer') then
    raise exception 'change_member_role: role must be admin/member/viewer' using errcode = '22023';
  end if;
  select * into v_target from public.org_members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'change_member_role: member not found' using errcode = 'P0002';
  end if;
  if v_target.role = 'owner' then
    raise exception 'change_member_role: use transfer_ownership for the owner' using errcode = '42501';
  end if;
  if v_caller_role = 'admin' and (p_role = 'admin' or v_target.role = 'admin') then
    raise exception 'change_member_role: admin cannot change admin roles' using errcode = '42501';
  end if;

  update public.org_members set role = p_role where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform public.write_audit(p_org_id, 'org_member.role', 'user', p_user_id::text,
                             jsonb_build_object('role', v_target.role), jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function public.remove_member(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller_role text; v_target public.org_members;
begin
  v_caller_role := public.current_org_role(p_org_id);
  select * into v_target from public.org_members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    return;
  end if;
  if v_target.role = 'owner' then
    raise exception 'remove_member: owner cannot be removed' using errcode = '42501';
  end if;
  if not public.is_service_caller() then
    if p_user_id <> auth.uid() and coalesce(v_caller_role, '') not in ('owner', 'admin') then
      raise exception 'remove_member: owner/admin only' using errcode = '42501';
    end if;
    if v_caller_role = 'admin' and v_target.role = 'admin' and p_user_id <> auth.uid() then
      raise exception 'remove_member: admin cannot remove admin' using errcode = '42501';
    end if;
  end if;
  delete from public.org_members where org_id = p_org_id and user_id = p_user_id;
  perform public.write_audit(p_org_id, 'org_member.remove', 'user', p_user_id::text, jsonb_build_object('role', v_target.role), null);
end;
$$;

create or replace function public.transfer_ownership(p_org_id uuid, p_new_owner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_service_caller() and coalesce(public.current_org_role(p_org_id), '') <> 'owner' then
    raise exception 'transfer_ownership: owner only' using errcode = '42501';
  end if;
  if not exists (select 1 from public.org_members where org_id = p_org_id and user_id = p_new_owner and status = 'active') then
    raise exception 'transfer_ownership: new owner must be an active member' using errcode = 'P0002';
  end if;
  update public.org_members set role = 'admin' where org_id = p_org_id and role = 'owner';
  update public.org_members set role = 'owner' where org_id = p_org_id and user_id = p_new_owner;
  update public.organizations set owner_id = p_new_owner where id = p_org_id;
  perform public.write_audit(p_org_id, 'organization.transfer_ownership', 'user', p_new_owner::text);
end;
$$;

create or replace function public.approve_profile(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_service_caller() and not public.is_platform_admin() then
    raise exception 'approve_profile: platform_admin only' using errcode = '42501';
  end if;
  update public.profiles set status = 'active' where id = p_user_id and status = 'pending';
  perform public.write_audit(null, 'profile.approve', 'user', p_user_id::text);
end;
$$;

-- SECTION 1 테이블의 RLS 정책 (읽기 + 비권한 컬럼 UPDATE)
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or public.is_platform_admin()
    or id in (select m.user_id from public.org_members m where m.org_id in (select public.current_org_ids()))
  );
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists organizations_select on public.organizations;
create policy organizations_select on public.organizations for select to authenticated
  using (deleted_at is null and (public.is_org_member(id) or public.is_platform_admin()));
drop policy if exists organizations_update_admin on public.organizations;
create policy organizations_update_admin on public.organizations for update to authenticated
  using (deleted_at is null and public.has_org_role(id, array['owner', 'admin']))
  with check (public.has_org_role(id, array['owner', 'admin']));

drop policy if exists org_members_select on public.org_members;
create policy org_members_select on public.org_members for select to authenticated
  using (public.is_org_member(org_id) or user_id = auth.uid() or public.is_platform_admin());

drop policy if exists audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log for select to authenticated
  using ((org_id is not null and public.has_org_role(org_id, array['owner', 'admin'])) or public.is_platform_admin());


-- =====================================================================
-- SECTION 2. 앱 레지스트리, 플랜, 크레딧팩, 구독, 엔타이틀먼트  [필수]
-- 원본: 0002_core_billing.sql (결제 테이블은 SECTION 3), 0003의 부트스트랩 1단계
-- 유료 플랜이 없는 제품도 apps 1행 + 기본 플랜 1행은 둔다. app_entitlements 가 기능 게이팅의 단일 출처다.
-- =====================================================================

create table if not exists public.apps (
  id            text primary key constraint apps_id_check check (id ~ '^[a-z][a-z0-9_]{1,30}$'),
  name          text not null,
  schema_name   text not null unique,
  signup_policy text not null default 'open'
                constraint apps_signup_policy_check check (signup_policy in ('open', 'approval', 'invite')),
  status        text not null default 'active'
                constraint apps_status_check check (status in ('active', 'beta', 'disabled')),
  created_at    timestamptz not null default now()
);

create table if not exists public.plans (
  id               uuid primary key default gen_random_uuid(),
  app_id           text not null references public.apps(id) on delete cascade,
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
create unique index if not exists plans_one_default_per_app_idx on public.plans (app_id) where is_default;
comment on column public.plans.carry_over is 'false면 월 지급 시 남은 플랜 크레딧을 만료(expire)시킨다';
comment on column public.plans.features is '서버에서만 읽는 기능 플래그. 예: {"tracks":["A"],"max_channels":1}';

create table if not exists public.credit_packs (
  id         uuid primary key default gen_random_uuid(),
  app_id     text not null references public.apps(id) on delete cascade,
  code       text not null constraint credit_packs_code_check check (code ~ '^[a-z][a-z0-9_]{1,30}$'),
  name       text not null,
  credits    integer not null constraint credit_packs_credits_check check (credits > 0),
  price_krw  integer not null constraint credit_packs_price_check check (price_krw > 0),
  is_active  boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (app_id, code)
);

-- billing_keys 는 SECTION 3 에 있지만 subscriptions 가 참조하므로 FK 없이 uuid 로만 둔다(모듈러와의 차이).
create table if not exists public.subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations(id) on delete cascade,
  app_id                 text not null references public.apps(id) on delete cascade,
  plan_id                uuid not null references public.plans(id),
  status                 text not null default 'active'
                         constraint subscriptions_status_check check (status in ('trialing', 'active', 'past_due', 'canceled', 'expired')),
  billing_key_id         uuid,
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
create index if not exists subscriptions_charge_due_idx on public.subscriptions (next_charge_at)
  where status in ('active', 'past_due') and next_charge_at is not null;

create table if not exists public.app_entitlements (
  org_id     uuid not null references public.organizations(id) on delete cascade,
  app_id     text not null references public.apps(id) on delete cascade,
  plan_id    uuid not null references public.plans(id),
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

drop trigger if exists plans_set_updated_at on public.plans;
create trigger plans_set_updated_at before update on public.plans for each row execute function public.set_updated_at();
drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at before update on public.subscriptions for each row execute function public.set_updated_at();
drop trigger if exists app_entitlements_set_updated_at on public.app_entitlements;
create trigger app_entitlements_set_updated_at before update on public.app_entitlements for each row execute function public.set_updated_at();

alter table public.apps             enable row level security;
alter table public.plans            enable row level security;
alter table public.credit_packs     enable row level security;
alter table public.subscriptions    enable row level security;
alter table public.app_entitlements enable row level security;

do $$
declare t text;
begin
  foreach t in array array['apps', 'plans', 'credit_packs', 'subscriptions', 'app_entitlements']
  loop
    execute format('drop trigger if exists %I_guard_write on public.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on public.%I for each row execute function public.guard_privileged_write()', t, t);
  end loop;
end $$;

-- 엔타이틀먼트 헬퍼
create or replace function public.has_entitlement(org uuid, app text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.app_entitlements e
    where e.org_id = org and e.app_id = app and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  );
$$;

create or replace function public.entitled_plan_code(org uuid, app text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.code
  from public.app_entitlements e
  join public.plans p on p.id = e.plan_id
  where e.org_id = org and e.app_id = app and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now());
$$;

-- 세션 컨텍스트: 요청당 1회. 반환 {user_id, email, display_name, platform_role, status, org, app_id, plan_code, entitled, credit_balance}
-- 프로필이 없으면 null → 호출 측은 로그아웃 처리(기본 admin 금지). credit_balance 는 wallets(SECTION 4)가 없으면 0.
create or replace function public.session_context(p_app text default null, p_org uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_profile public.profiles;
  v_org     uuid;
  v_org_row public.organizations;
  v_role    text;
  v_plan    text;
  v_balance integer;
begin
  if v_uid is null then
    return null;
  end if;
  select * into v_profile from public.profiles p where p.id = v_uid;
  if not found then
    return null;
  end if;

  v_org := coalesce(p_org, (
    select o.id from public.organizations o
    where o.owner_id = v_uid and o.is_personal and o.deleted_at is null
    order by o.created_at limit 1));

  if v_org is not null then
    select m.role into v_role from public.org_members m
    where m.org_id = v_org and m.user_id = v_uid and m.status = 'active';
    if v_role is null then
      v_org := null;
    else
      select * into v_org_row from public.organizations o where o.id = v_org and o.deleted_at is null;
      if p_app is not null then
        v_plan := public.entitled_plan_code(v_org, p_app);
      end if;
      if to_regclass('public.wallets') is not null then
        execute 'select w.plan_balance + w.pack_balance from public.wallets w where w.org_id = $1' into v_balance using v_org;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'user_id',        v_uid,
    'email',          v_profile.email,
    'display_name',   v_profile.display_name,
    'platform_role',  v_profile.platform_role,
    'status',         v_profile.status,
    'org',            case when v_org is null then null else jsonb_build_object(
                        'id', v_org, 'name', v_org_row.name, 'slug', v_org_row.slug, 'role', v_role) end,
    'app_id',         p_app,
    'plan_code',      v_plan,
    'entitled',       v_plan is not null,
    'credit_balance', coalesce(v_balance, 0)
  );
end;
$$;

-- 구독 상태 머신 (service_role 전용)
--   trialing → active | canceled | expired / active → past_due | canceled | expired
--   past_due → active | canceled | expired / canceled → active | expired / expired → active
create or replace function public.apply_subscription_transition(
  p_subscription_id uuid,
  p_to              text,
  p_reason          text default null
)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sub          public.subscriptions;
  v_allowed      boolean;
  v_default_plan uuid;
begin
  if not public.is_privileged_session() then
    raise exception 'apply_subscription_transition: service_role only' using errcode = '42501';
  end if;

  select * into v_sub from public.subscriptions where id = p_subscription_id for update;
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

  update public.subscriptions
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
    insert into public.app_entitlements (org_id, app_id, plan_id, status, source, expires_at)
    values (v_sub.org_id, v_sub.app_id, v_sub.plan_id, 'active', 'subscription', null)
    on conflict (org_id, app_id) do update
      set plan_id = excluded.plan_id, status = 'active', source = 'subscription', expires_at = null;
  elsif p_to = 'canceled' then
    update public.app_entitlements
    set expires_at = v_sub.current_period_end
    where org_id = v_sub.org_id and app_id = v_sub.app_id;
  elsif p_to = 'expired' then
    select id into v_default_plan from public.plans where app_id = v_sub.app_id and is_default and is_active limit 1;
    if v_default_plan is not null then
      insert into public.app_entitlements (org_id, app_id, plan_id, status, source, expires_at)
      values (v_sub.org_id, v_sub.app_id, v_default_plan, 'active', 'signup', null)
      on conflict (org_id, app_id) do update
        set plan_id = excluded.plan_id, status = 'active', source = 'signup', expires_at = null;
    else
      update public.app_entitlements set status = 'expired'
      where org_id = v_sub.org_id and app_id = v_sub.app_id;
    end if;
  end if;

  insert into public.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, after)
  values (v_sub.org_id, null, 'service', 'subscription.' || p_to, 'subscription', v_sub.id::text,
          jsonb_build_object('reason', p_reason, 'plan_id', v_sub.plan_id));

  return v_sub;
end;
$$;

-- 부트스트랩 1단계(크레딧 없음): 기본 플랜으로 구독 + 엔타이틀먼트. SECTION 4 가 크레딧 지급 버전으로 교체한다.
create or replace function public.on_signup_app_bootstrap(p_org_id uuid, p_user_id uuid, p_app_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app  public.apps;
  v_plan public.plans;
  v_period_end timestamptz;
begin
  select * into v_app from public.apps where id = p_app_id and status <> 'disabled';
  if not found then
    return;
  end if;
  if v_app.signup_policy = 'approval' then
    update public.profiles set status = 'pending' where id = p_user_id and status = 'active';
  end if;
  select * into v_plan from public.plans where app_id = p_app_id and is_default and is_active limit 1;
  if not found then
    return;
  end if;
  v_period_end := case v_plan.billing_interval
    when 'month' then now() + interval '1 month'
    when 'year'  then now() + interval '1 year'
    else null end;
  insert into public.subscriptions (org_id, app_id, plan_id, status, current_period_start, current_period_end)
  values (p_org_id, p_app_id, v_plan.id, 'active', now(), v_period_end)
  on conflict (org_id, app_id) do nothing;
  insert into public.app_entitlements (org_id, app_id, plan_id, status, source)
  values (p_org_id, p_app_id, v_plan.id, 'active', 'signup')
  on conflict (org_id, app_id) do nothing;
end;
$$;

-- 기존 사용자가 앱을 처음 열 때(SSO) 호출. owner/admin 만.
create or replace function public.bootstrap_app_for_org(p_app_id text, p_org_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  v_org := coalesce(p_org_id, public.personal_org_id());
  if v_org is null then
    raise exception 'bootstrap_app_for_org: no organization' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() then
    if not public.has_org_role(v_org, array['owner', 'admin']) then
      raise exception 'bootstrap_app_for_org: owner/admin only' using errcode = '42501';
    end if;
  end if;
  if not public.is_service_caller()
     and exists (select 1 from public.apps a where a.id = p_app_id and a.signup_policy = 'invite') then
    raise exception 'bootstrap_app_for_org: % is invite-only', p_app_id using errcode = '42501';
  end if;
  perform public.on_signup_app_bootstrap(v_org, auth.uid(), p_app_id);
end;
$$;

-- 구독 기간 굴림 + 해지 예약 만료 (service_role / pg_cron). 모듈러 run_monthly_credit_grants 의 1), 3) 단계.
create or replace function public.run_subscription_rollover()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare r record; v_count integer := 0;
begin
  if not public.is_privileged_session() then
    raise exception 'run_subscription_rollover: service_role only' using errcode = '42501';
  end if;

  update public.subscriptions s
  set current_period_start = s.current_period_end,
      current_period_end   = s.current_period_end + case p.billing_interval when 'year' then interval '1 year' else interval '1 month' end
  from public.plans p
  where p.id = s.plan_id
    and p.price_krw = 0
    and p.billing_interval in ('month', 'year')
    and s.status in ('active', 'trialing')
    and s.current_period_end is not null
    and s.current_period_end <= now();

  for r in
    select s.id from public.subscriptions s
    where s.status = 'canceled' and s.current_period_end is not null and s.current_period_end <= now()
  loop
    perform public.apply_subscription_transition(r.id, 'expired', 'period_end');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- RLS 정책: 가격표는 공개 읽기, 조직 데이터는 멤버 읽기, 쓰기 정책 없음
drop policy if exists apps_select on public.apps;
create policy apps_select on public.apps for select to anon, authenticated using (status <> 'disabled');
drop policy if exists plans_select on public.plans;
create policy plans_select on public.plans for select to anon, authenticated using (is_active);
drop policy if exists credit_packs_select on public.credit_packs;
create policy credit_packs_select on public.credit_packs for select to anon, authenticated using (is_active);
drop policy if exists subscriptions_select on public.subscriptions;
create policy subscriptions_select on public.subscriptions for select to authenticated using (public.is_org_member(org_id));
drop policy if exists app_entitlements_select on public.app_entitlements;
create policy app_entitlements_select on public.app_entitlements for select to authenticated using (public.is_org_member(org_id));


-- =====================================================================
-- SECTION 3. Toss Payments: 빌링키, 주문, 결제, 웹훅 이벤트, 결제 이행  [선택]
-- 원본: 0002_core_billing.sql, 0003 confirm_payment_order
-- 의존: SECTION 2(plans, subscriptions, app_entitlements). confirm_payment_order 의 credit_pack 분기는 SECTION 4 가 필요하다.
--       SECTION 4 를 지우면 confirm_payment_order 의 "if v_order.kind = 'credit_pack'" 분기도 지운다.
-- 지울 때: 이 절 전체. SECTION 2 의 subscriptions.billing_key_id 컬럼은 남겨도 무해하다.
-- =====================================================================

-- 빌링키 자체는 앱 계층 AES-256-GCM 암호문으로만. customer_key 는 'org_' || org_id 로 결정적 생성(Date.now() 금지).
create table if not exists public.billing_keys (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations(id) on delete cascade,
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
create unique index if not exists billing_keys_one_active_per_org_idx on public.billing_keys (org_id) where status = 'active';

-- 결제창을 열기 전에 서버가 먼저 저장하는 주문. 금액의 정본. orderId 파싱으로 org/plan 을 꺼내지 않는다.
create table if not exists public.payment_orders (
  id             uuid primary key default gen_random_uuid(),
  order_id       text not null unique constraint payment_orders_order_id_check check (order_id ~ '^[A-Za-z0-9_-]{6,64}$'),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  app_id         text not null references public.apps(id),
  kind           text not null constraint payment_orders_kind_check check (kind in ('subscription', 'credit_pack', 'billing_key_charge')),
  plan_id        uuid references public.plans(id),
  credit_pack_id uuid references public.credit_packs(id),
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
create index if not exists payment_orders_org_idx on public.payment_orders (org_id, created_at desc);

-- Toss 승인 결과. payment_key 유일 → 같은 승인을 두 번 지급하지 않는다.
create table if not exists public.payments (
  id                  uuid primary key default gen_random_uuid(),
  order_id            text not null references public.payment_orders(order_id),
  org_id              uuid not null references public.organizations(id) on delete cascade,
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
create index if not exists payments_org_idx on public.payments (org_id, created_at desc);

-- 인바운드 웹훅 멱등 처리. (provider, event_id) 유일. 서명 검증 실패 이벤트는 처리하지 않는다.
create table if not exists public.webhook_events (
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

drop trigger if exists payment_orders_set_updated_at on public.payment_orders;
create trigger payment_orders_set_updated_at before update on public.payment_orders for each row execute function public.set_updated_at();
drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at before update on public.payments for each row execute function public.set_updated_at();

alter table public.billing_keys   enable row level security;
alter table public.payment_orders enable row level security;
alter table public.payments       enable row level security;
alter table public.webhook_events enable row level security;

do $$
declare t text;
begin
  foreach t in array array['billing_keys', 'payment_orders', 'payments', 'webhook_events']
  loop
    execute format('drop trigger if exists %I_guard_write on public.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on public.%I for each row execute function public.guard_privileged_write()', t, t);
  end loop;
end $$;

-- 빌링키 요약 뷰(암호문 제외). 정의자 뷰이므로 멤버십 필터를 뷰 안에서 건다.
create or replace view public.billing_key_summaries as
  select b.id, b.org_id, b.customer_key, b.card_company, b.card_number_masked, b.status, b.created_at, b.revoked_at
  from public.billing_keys b
  where b.org_id in (
    select m.org_id from public.org_members m where m.user_id = auth.uid() and m.status = 'active'
  );

create or replace function public.expire_stale_payment_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if not public.is_privileged_session() then
    raise exception 'expire_stale_payment_orders: service_role only' using errcode = '42501';
  end if;
  update public.payment_orders set status = 'expired'
  where status = 'created' and expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- 결제 이행: Toss confirm 성공 후 서버가 1회 호출. 주문 잠금 → 금액 대조 → payments 기록 → 종류별 지급. 한 트랜잭션.
-- SQLSTATE: PM404 주문 없음 / PM409 다른 결제키로 재확인 / PM410 상태 불가 / PM001 금액 불일치
-- 알려진 한계(모듈러 0003:577-583 과 동일, 코어 결정 전까지 유지): PM001 분기의 "주문 failed" UPDATE 는 뒤따르는
-- raise 로 같은 트랜잭션에서 롤백된다. 앱 계층은 PM001 을 받으면 별도 호출로 주문을 failed 로 표시해야 한다.
create or replace function public.confirm_payment_order(
  p_order_id    text,
  p_payment_key text,
  p_amount_krw  integer,
  p_method      text        default null,
  p_raw         jsonb       default '{}'::jsonb,
  p_approved_at timestamptz default now()
)
returns public.payments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order   public.payment_orders;
  v_payment public.payments;
  v_plan    public.plans;
  v_sub     public.subscriptions;
  v_start   timestamptz := now();
  v_end     timestamptz;
  v_key     text;
begin
  if not public.is_privileged_session() then
    raise exception 'confirm_payment_order: service_role only' using errcode = '42501';
  end if;

  select * into v_order from public.payment_orders where order_id = p_order_id for update;
  if not found then
    raise exception 'payment order not found: %', p_order_id using errcode = 'PM404';
  end if;

  if v_order.status = 'confirmed' then
    select * into v_payment from public.payments where order_id = p_order_id;
    if v_payment.payment_key = p_payment_key then
      return v_payment;
    end if;
    raise exception 'order % already confirmed with another payment key', p_order_id using errcode = 'PM409';
  end if;

  if v_order.status <> 'created' then
    raise exception 'order % is %, cannot confirm', p_order_id, v_order.status using errcode = 'PM410';
  end if;

  if v_order.amount_krw <> p_amount_krw then
    -- 이 raise는 트랜잭션 전체를 되돌리므로 여기서 상태를 바꿔도 남지 않는다.
    -- PM001을 받은 서버는 별도 트랜잭션에서 fail_payment_order()로 주문을 failed로 남긴다.
    raise exception 'amount mismatch for order %: expected % got %', p_order_id, v_order.amount_krw, p_amount_krw
      using errcode = 'PM001';
  end if;

  insert into public.payments (order_id, org_id, payment_key, method, amount_krw, status, approved_at, raw)
  values (p_order_id, v_order.org_id, p_payment_key, p_method, p_amount_krw, 'done', p_approved_at, coalesce(p_raw, '{}'::jsonb))
  returning * into v_payment;

  update public.payment_orders set status = 'confirmed', confirmed_at = now() where order_id = p_order_id;

  -- [admin-suite 제거] credit_pack 분기: SECTION 4(크레딧)를 지웠으므로 grant_credits 호출 분기를 지웠다.
  --   이 제품은 크레딧팩을 팔지 않는다. 서버는 kind='credit_pack' 주문을 만들지 않으며, 만들어져도 여기서 거부한다.
  if v_order.kind = 'credit_pack' then
    raise exception 'credit packs are not sold in this product (order %)', p_order_id using errcode = '22023';
  end if;
    select * into v_plan from public.plans where id = v_order.plan_id;
    v_end := case v_plan.billing_interval when 'year' then v_start + interval '1 year' else v_start + interval '1 month' end;

    insert into public.subscriptions (org_id, app_id, plan_id, status, current_period_start, current_period_end, next_charge_at, failed_charge_count)
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

    insert into public.app_entitlements (org_id, app_id, plan_id, status, source, expires_at)
    values (v_order.org_id, v_order.app_id, v_plan.id, 'active', 'subscription', null)
    on conflict (org_id, app_id) do update
      set plan_id = excluded.plan_id, status = 'active', source = 'subscription', expires_at = null;

    if v_plan.monthly_credits > 0 and to_regprocedure('public.grant_credits(uuid,integer,text,text,text,text,text,text,jsonb,uuid,boolean)') is not null then
      v_key := 'monthly:' || v_sub.id::text || ':' || to_char(v_sub.current_period_start, 'YYYY-MM-DD');
      perform public.grant_credits(v_order.org_id, v_plan.monthly_credits, v_order.app_id, 'monthly_plan_credits', 'plan',
                                   'subscription', v_sub.id::text, v_key,
                                   jsonb_build_object('order_id', p_order_id, 'payment_key', p_payment_key),
                                   v_order.created_by, not v_plan.carry_over);
      update public.subscriptions set last_credit_grant_key = v_key where id = v_sub.id;
    end if;
  -- [admin-suite 제거] credit_pack 분기를 닫던 end if (위 주석 참조)

  return v_payment;
end;
$$;

-- ---------------------------------------------------------------------
-- fail_payment_order (service_role 전용): 확정하지 못한 주문을 failed로 남긴다.
--   confirm_payment_order는 PM001 등에서 raise로 끝나 상태 변경이 롤백되므로,
--   서버가 PM001을 받으면 별도 트랜잭션에서 이 함수를 호출한다.
--   created 상태에서만 바뀌고, 이미 failed면 그대로 돌려준다(멱등).
--   SQLSTATE: PM404 주문 없음 / PM410 상태 불가
-- ---------------------------------------------------------------------
create or replace function public.fail_payment_order(p_order_id text, p_reason text, p_detail jsonb default '{}'::jsonb)
returns public.payment_orders
language plpgsql
security definer
set search_path = ''
as $$
declare v_order public.payment_orders;
begin
  if not public.is_service_caller() then
    raise exception 'fail_payment_order: service_role only' using errcode = '42501';
  end if;
  select * into v_order from public.payment_orders where order_id = p_order_id for update;
  if not found then
    raise exception 'payment order not found: %', p_order_id using errcode = 'PM404';
  end if;
  if v_order.status = 'failed' then
    return v_order;
  end if;
  if v_order.status <> 'created' then
    raise exception 'order % is %, cannot mark failed', p_order_id, v_order.status using errcode = 'PM410';
  end if;
  update public.payment_orders
     set status = 'failed',
         metadata = metadata || jsonb_build_object('failure', coalesce(p_reason, 'unknown')) || coalesce(p_detail, '{}'::jsonb)
   where order_id = p_order_id
  returning * into v_order;
  insert into public.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, after)
  values (v_order.org_id, null, 'service', 'payment_order.failed', 'payment_order', p_order_id,
          jsonb_build_object('reason', p_reason));
  return v_order;
end;
$$;
revoke execute on function public.fail_payment_order(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.fail_payment_order(text, text, jsonb) to service_role;

drop policy if exists payment_orders_select on public.payment_orders;
create policy payment_orders_select on public.payment_orders for select to authenticated using (public.is_org_member(org_id));
drop policy if exists payments_select on public.payments;
create policy payments_select on public.payments for select to authenticated using (public.is_org_member(org_id));
-- billing_keys, webhook_events: 정책 없음(사용자 접근 불가). 빌링키 요약은 뷰로만.


-- =====================================================================
-- [admin-suite/erp 제거] SECTION 4. 크레딧(wallets, credit_ledger, ai_usage, consume/grant/refund, 월 지급, purge_organization)  [선택]
-- 이유: 크레딧 과금이 없다(AI 생성 기능 없음, 01_PRD 4절). 함께 지운 것: SECTION 3 의 credit_pack 분기. purge_organization 도 이 절에 있어 함께 빠진다(조직 파기는 06_AGENT_PLAN 코어 요청 항목).
-- 원본 절은 _platform-core/MONOLITH_CORE_LITE.sql 에 그대로 있다. 필요해지면 그 절을 다시 붙인다.
-- =====================================================================

-- =====================================================================
-- [admin-suite/erp 제거] SECTION 6-A. oauth_states  [선택]
-- 이유: 외부 OAuth 연동(SNS/마켓)이 없다. Google 로그인은 Supabase Auth 기본 흐름이라 이 테이블이 필요 없다.
-- 원본 절은 _platform-core/MONOLITH_CORE_LITE.sql 에 그대로 있다. 필요해지면 그 절을 다시 붙인다.
-- =====================================================================

-- =====================================================================
-- [admin-suite/erp 제거] SECTION 6-B. encrypted_credentials  [선택]
-- 이유: 보관할 외부 API 토큰이 없다.
-- 원본 절은 _platform-core/MONOLITH_CORE_LITE.sql 에 그대로 있다. 필요해지면 그 절을 다시 붙인다.
-- =====================================================================

-- =====================================================================
-- SECTION 6-C. rate_limit_buckets: 고정 윈도우 카운터 (Redis 없는 제품의 기본 레이트 리밋)  [선택]
-- 원본: 0004_core_security.sql 7절. 의존: SECTION 0 만
-- =====================================================================

create table if not exists public.rate_limit_buckets (
  key          text primary key,
  window_start timestamptz not null,
  count        integer not null default 0,
  updated_at   timestamptz not null default now()
);
alter table public.rate_limit_buckets enable row level security;
drop trigger if exists rate_limit_buckets_guard_write on public.rate_limit_buckets;
create trigger rate_limit_buckets_guard_write before insert or update or delete on public.rate_limit_buckets
  for each row execute function public.guard_privileged_write();

-- 반환: allowed, remaining, reset_at. 호출 1회 = 1 히트.
create or replace function public.rate_limit_hit(p_key text, p_limit integer, p_window_seconds integer)
returns table (allowed boolean, remaining integer, reset_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer; v_start timestamptz; v_win interval;
begin
  if not public.is_privileged_session() then
    raise exception 'rate_limit_hit: service_role only' using errcode = '42501';
  end if;
  v_win := make_interval(secs => p_window_seconds);
  insert into public.rate_limit_buckets as b (key, window_start, count)
  values (p_key, now(), 1)
  on conflict (key) do update
    set count        = case when b.window_start + v_win <= now() then 1 else b.count + 1 end,
        window_start = case when b.window_start + v_win <= now() then now() else b.window_start end,
        updated_at   = now()
  returning b.count, b.window_start into v_count, v_start;
  return query select v_count <= p_limit, greatest(p_limit - v_count, 0), v_start + v_win;
end;
$$;

create or replace function public.purge_rate_limit_buckets(p_older_than interval default interval '1 day')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if not public.is_privileged_session() then
    raise exception 'purge_rate_limit_buckets: service_role only' using errcode = '42501';
  end if;
  delete from public.rate_limit_buckets where updated_at < now() - p_older_than;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;


-- =====================================================================
-- [admin-suite/erp 제거] SECTION 7. jobs  [선택]
-- 이유: 비동기 잡이 없다(모든 쓰기가 동기 RPC). 이 절은 SECTION 4 에도 의존한다.
-- 원본 절은 _platform-core/MONOLITH_CORE_LITE.sql 에 그대로 있다. 필요해지면 그 절을 다시 붙인다.
-- =====================================================================

-- =====================================================================
-- SECTION 8. Storage: 버킷 3개 + "폴더 = org_id" 정책  [선택]
-- 원본: 0005_core_jobs_storage.sql 2절. 의존: SECTION 5-A 헬퍼
-- 경로 규칙: <org_id>/<app_id>/<entity>/<uuid>.<ext>
-- 버킷: org-files(비공개 50MB), exports(비공개 200MB, 서명 URL), public-assets(공개 읽기, 10MB 이미지)
-- =====================================================================

create or replace function public.storage_org_id(p_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid
    else null
  end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('org-files',     'org-files',     false, 52428800,  null),
  ('exports',       'exports',       false, 209715200, null),
  ('public-assets', 'public-assets', true,  10485760,  array['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml'])
on conflict (id) do nothing;

drop policy if exists org_files_select on storage.objects;
create policy org_files_select on storage.objects for select to authenticated
  using (bucket_id = 'org-files' and public.is_org_member(public.storage_org_id(name)));
drop policy if exists org_files_insert on storage.objects;
create policy org_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'org-files' and public.is_org_member(public.storage_org_id(name)));
drop policy if exists org_files_update on storage.objects;
create policy org_files_update on storage.objects for update to authenticated
  using (bucket_id = 'org-files' and public.is_org_member(public.storage_org_id(name)))
  with check (bucket_id = 'org-files' and public.is_org_member(public.storage_org_id(name)));
drop policy if exists org_files_delete on storage.objects;
create policy org_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'org-files' and (owner_id = auth.uid()::text or public.has_org_role(public.storage_org_id(name), array['owner', 'admin'])));

drop policy if exists exports_select on storage.objects;
create policy exports_select on storage.objects for select to authenticated
  using (bucket_id = 'exports' and public.is_org_member(public.storage_org_id(name)));

drop policy if exists public_assets_select on storage.objects;
create policy public_assets_select on storage.objects for select to anon, authenticated
  using (bucket_id = 'public-assets');
drop policy if exists public_assets_insert on storage.objects;
create policy public_assets_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'public-assets' and public.is_org_member(public.storage_org_id(name)));
drop policy if exists public_assets_update on storage.objects;
create policy public_assets_update on storage.objects for update to authenticated
  using (bucket_id = 'public-assets' and public.is_org_member(public.storage_org_id(name)))
  with check (bucket_id = 'public-assets' and public.is_org_member(public.storage_org_id(name)));
drop policy if exists public_assets_delete on storage.objects;
create policy public_assets_delete on storage.objects for delete to authenticated
  using (bucket_id = 'public-assets' and public.has_org_role(public.storage_org_id(name), array['owner', 'admin']));


-- =====================================================================
-- [admin-suite/erp 제거] SECTION 9. affiliate  [선택]
-- 이유: 제휴마케팅은 video/blog 전용(확정 결정 12).
-- 원본 절은 _platform-core/MONOLITH_CORE_LITE.sql 에 그대로 있다. 필요해지면 그 절을 다시 붙인다.
-- =====================================================================

-- =====================================================================
-- SECTION 10. 권한 정리  [필수]  -- 절을 지워도 동작한다(존재하는 객체에만 적용)
-- 1) public 의 모든 테이블/뷰/시퀀스/함수에서 anon, authenticated, PUBLIC 권한을 회수한다.
--    (Supabase 가 public 에 기본으로 준 권한 + 위에서 만들어진 모든 객체)
-- 2) 허용 목록만 다시 준다. 테이블은 SELECT(일부 컬럼 UPDATE), 함수는 사용자용 RPC 만.
-- 3) service_role 은 모든 것을 가진다(BYPASSRLS).
-- 이 파일은 제품 도메인 마이그레이션보다 먼저 적용되므로 이 시점의 public 객체는 코어 객체만이다.
-- =====================================================================

do $$
declare r record;
begin
  for r in select c.relname, c.relkind from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'v', 'p')
  loop
    execute format('revoke all on table public.%I from public, anon, authenticated', r.relname);
    execute format('grant all on table public.%I to service_role', r.relname);
  end loop;
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'S'
  loop
    execute format('revoke all on sequence public.%I from public, anon, authenticated', r.relname);
    execute format('grant all on sequence public.%I to service_role', r.relname);
  end loop;
  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    execute format('grant execute on function %s to service_role', r.sig);
  end loop;
end $$;

-- 허용 목록: 테이블 SELECT (+ 비권한 컬럼 UPDATE)
do $$
declare
  t text;
  v_auth_select text[] := array[
    'profiles', 'organizations', 'org_members', 'audit_log',
    'subscriptions', 'app_entitlements',
    'payment_orders', 'payments', 'billing_key_summaries',
    'wallets', 'credit_ledger', 'ai_usage', 'credit_balances',
    'credential_summaries',
    'jobs',
    'affiliate_accounts', 'affiliate_links', 'affiliate_clicks', 'affiliate_disclosures', 'brandconnect_applications'
  ];
  v_public_select text[] := array['apps', 'plans', 'credit_packs'];
begin
  foreach t in array v_auth_select loop
    if to_regclass('public.' || t) is not null then
      execute format('grant select on public.%I to authenticated', t);
    end if;
  end loop;
  foreach t in array v_public_select loop
    if to_regclass('public.' || t) is not null then
      execute format('grant select on public.%I to anon, authenticated', t);
    end if;
  end loop;
  if to_regclass('public.profiles') is not null then
    grant update (display_name, avatar_url, locale, last_seen_at) on public.profiles to authenticated;
  end if;
  if to_regclass('public.organizations') is not null then
    grant update (name, settings) on public.organizations to authenticated;
  end if;
end $$;

-- 허용 목록: 함수 EXECUTE
--   anon + authenticated : 정책 안에서 쓰는 헬퍼(SECURITY DEFINER, 읽기 전용)
--   authenticated        : 사용자용 RPC (안에서 is_service_caller + 역할 검사)
--   service_role 전용    : consume/grant/refund_credits, confirm_payment_order, enqueue/claim/heartbeat/complete/fail_job,
--                          create/consume_oauth_state, rate_limit_hit, record_affiliate_click, 스케줄 함수, purge_* (위 1)에서 이미 부여)
do $$
declare
  s text;
  v_anon_auth text[] := array[
    'public.jwt_role()', 'public.is_privileged_session()', 'public.is_service_caller()',
    'public.current_org_ids()', 'public.is_org_member(uuid)', 'public.has_org_role(uuid,text[])',
    'public.current_org_role(uuid)', 'public.is_platform_admin()',
    'public.storage_org_id(text)'
  ];
  v_auth text[] := array[
    'public.has_entitlement(uuid,text)', 'public.entitled_plan_code(uuid,text)',
    'public.personal_org_id()', 'public.session_context(text,uuid)', 'public.bootstrap_app_for_org(text,uuid)',
    'public.write_audit(uuid,text,text,text,jsonb,jsonb,jsonb)',
    'public.invite_member(uuid,uuid,text)', 'public.accept_invite(uuid)', 'public.approve_member(uuid,uuid)',
    'public.change_member_role(uuid,uuid,text)', 'public.remove_member(uuid,uuid)',
    'public.transfer_ownership(uuid,uuid)', 'public.approve_profile(uuid)',
    'public.revoke_credential(uuid)',
    'public.cancel_job(uuid)',
    'public.effective_disclosure(uuid,text,text)', 'public.upsert_affiliate_disclosure(uuid,text,text,text)',
    'public.consent_brandconnect_risk(uuid)',
    'public.create_brandconnect_application(uuid,text,text,text,text,text,text)'
  ];
begin
  foreach s in array v_anon_auth loop
    if to_regprocedure(s) is not null then
      execute format('grant execute on function %s to anon, authenticated', s);
    end if;
  end loop;
  foreach s in array v_auth loop
    if to_regprocedure(s) is not null then
      execute format('grant execute on function %s to authenticated', s);
    end if;
  end loop;
end $$;

-- =====================================================================
-- 끝. 다음 파일: 0002_<product>_domain.sql (제품 도메인 테이블. org_id FK + RLS + 명시적 GRANT)
-- seed: apps 1행(id = 제품 스키마 이름), 기본 플랜 1행(is_default), 필요하면 affiliate 기본 문구.
-- =====================================================================
