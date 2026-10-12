-- =====================================================================
-- 0001_core_identity.sql
-- profiles, organizations, org_members, 가입 트리거.
-- 테넌시는 org 기준이며 운영은 "1인 1워크스페이스"다. 가입 시 개인 조직을 자동 생성한다.
-- RLS 정책과 멤버 관리 함수는 0004_core_security.sql에 있다. 여기서는 RLS를 켜고 권한만 준다.
-- 선행: 0000
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles: auth.users 1:1. 권한 컬럼(platform_role, status)은 사용자가 바꿀 수 없다.
-- ---------------------------------------------------------------------
create table if not exists core.profiles (
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
comment on column core.profiles.platform_role is '플랫폼 운영자 여부. service_role만 변경 가능';
comment on column core.profiles.status is '승인제 앱에서 pending으로 시작. service_role 또는 core.approve_profile()만 변경 가능';

-- ---------------------------------------------------------------------
-- organizations: 테넌트. 개인 조직(is_personal)은 가입 트리거가 만든다.
-- ---------------------------------------------------------------------
create table if not exists core.organizations (
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
create index if not exists organizations_owner_idx on core.organizations (owner_id);

-- ---------------------------------------------------------------------
-- org_members: 조직 멤버십. 쓰기는 service_role 또는 0004의 멤버 관리 함수만.
-- ---------------------------------------------------------------------
create table if not exists core.org_members (
  org_id     uuid not null references core.organizations(id) on delete cascade,
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
create index if not exists org_members_user_active_idx on core.org_members (user_id) where status = 'active';
-- 조직당 owner는 한 명. 이전은 core.transfer_ownership()으로만.
create unique index if not exists org_members_single_owner_idx on core.org_members (org_id) where role = 'owner';

-- updated_at 트리거
drop trigger if exists profiles_set_updated_at on core.profiles;
create trigger profiles_set_updated_at before update on core.profiles
  for each row execute function core.set_updated_at();
drop trigger if exists organizations_set_updated_at on core.organizations;
create trigger organizations_set_updated_at before update on core.organizations
  for each row execute function core.set_updated_at();
drop trigger if exists org_members_set_updated_at on core.org_members;
create trigger org_members_set_updated_at before update on core.org_members
  for each row execute function core.set_updated_at();

-- RLS: 켠다. 정책은 0004. 정책이 없는 동안은 모두 거부된다(안전 기본값).
alter table core.profiles      enable row level security;
alter table core.organizations enable row level security;
alter table core.org_members   enable row level security;

-- 권한: authenticated는 SELECT와 비권한 컬럼 UPDATE만. INSERT/DELETE 없음.
grant select on core.profiles to authenticated;
grant update (display_name, avatar_url, locale, last_seen_at) on core.profiles to authenticated;
grant select on core.organizations to authenticated;
grant update (name, settings) on core.organizations to authenticated;
grant select on core.org_members to authenticated;

-- org_members 직접 쓰기는 service_role만(이중 잠금). 멤버 관리는 0004의 SECURITY DEFINER 함수로.
drop trigger if exists org_members_guard_write on core.org_members;
create trigger org_members_guard_write before insert or update or delete on core.org_members
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 가입 트리거
--   1) profiles 생성
--   2) 개인 조직 + owner 멤버십 생성
--   3) raw_user_meta_data.signup_app 이 있으면 앱 부트스트랩(무료 플랜, 엔타이틀먼트, 가입 크레딧)
-- core.on_signup_app_bootstrap()은 여기서는 빈 함수이고 0003에서 실제 구현으로 교체된다.
-- (plans/credit 테이블이 그 이후에 생기므로 런타임 바인딩으로 순서를 푼다.)
-- ---------------------------------------------------------------------
create or replace function core.on_signup_app_bootstrap(p_org_id uuid, p_user_id uuid, p_app_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- 0003_core_credits.sql 에서 교체된다.
  return;
end;
$$;

create or replace function core.handle_new_user()
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

  insert into core.profiles (id, email, display_name, avatar_url)
  values (new.id, new.email, left(v_name, 80), new.raw_user_meta_data ->> 'avatar_url')
  on conflict (id) do nothing;

  insert into core.organizations (name, slug, owner_id, is_personal)
  values (left(v_name, 80), 'u' || replace(new.id::text, '-', ''), new.id, true)
  on conflict (slug) do nothing
  returning id into v_org_id;

  if v_org_id is null then
    select id into v_org_id from core.organizations where slug = 'u' || replace(new.id::text, '-', '');
  end if;

  insert into core.org_members (org_id, user_id, role, status, joined_at)
  values (v_org_id, new.id, 'owner', 'active', now())
  on conflict (org_id, user_id) do nothing;

  -- 초대제(invite) 앱은 가입만으로 이용 권한을 만들지 않는다.
  -- 운영자가 서버(service_role)에서 bootstrap_app_for_org로 부여하거나, 초대받은 조직의 권한을 쓴다.
  if v_app is not null and to_regclass('core.apps') is not null then
    if exists (select 1 from core.apps a where a.id = v_app and a.signup_policy = 'invite') then
      v_app := null;
    end if;
  end if;

  if v_app is not null then
    perform core.on_signup_app_bootstrap(v_org_id, new.id, v_app);
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function core.handle_new_user();

-- 조직/프로필 조회 헬퍼(SECURITY INVOKER): 현재 사용자의 기본(개인) 조직 id
create or replace function core.personal_org_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select o.id
  from core.organizations o
  where o.owner_id = auth.uid() and o.is_personal and o.deleted_at is null
  order by o.created_at
  limit 1;
$$;
grant execute on function core.personal_org_id() to authenticated;
