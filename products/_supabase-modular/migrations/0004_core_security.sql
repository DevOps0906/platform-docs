-- =====================================================================
-- 0004_core_security.sql
-- RLS 헬퍼 함수, core 전 테이블의 RLS 정책, 권한 컬럼 보호 트리거, 멤버 관리 함수,
-- audit_log, oauth_states, encrypted_credentials(암호문만), rate_limit_buckets.
--
-- 헬퍼 함수 (제품 스키마 정책에서 그대로 쓴다)
--   core.is_org_member(org uuid)                 boolean
--   core.has_org_role(org uuid, roles text[])    boolean
--   core.has_entitlement(org uuid, app text)     boolean
--   core.current_org_ids()                       setof uuid
--   core.is_platform_admin()                     boolean
--   core.current_org_role(org uuid)              text
-- 모두 SECURITY DEFINER + set search_path='' + STABLE. org_members를 정책 안에서 다시 조회해
-- 생기는 재귀(42P17)를 이 함수들이 끊는다.
-- 선행: 0000 ~ 0003
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 헬퍼 함수
-- ---------------------------------------------------------------------
create or replace function core.current_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.org_id
  from core.org_members m
  where m.user_id = auth.uid() and m.status = 'active';
$$;

create or replace function core.is_org_member(org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from core.org_members m
    where m.org_id = org and m.user_id = auth.uid() and m.status = 'active'
  );
$$;

create or replace function core.has_org_role(org uuid, roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from core.org_members m
    where m.org_id = org and m.user_id = auth.uid() and m.status = 'active' and m.role = any (roles)
  );
$$;

create or replace function core.current_org_role(org uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role from core.org_members m
  where m.org_id = org and m.user_id = auth.uid() and m.status = 'active';
$$;

create or replace function core.has_entitlement(org uuid, app text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from core.app_entitlements e
    where e.org_id = org and e.app_id = app and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  );
$$;

create or replace function core.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from core.profiles p
    where p.id = auth.uid() and p.platform_role = 'platform_admin' and p.status = 'active'
  );
$$;

-- 현재 엔타이틀먼트의 플랜 코드(서버 기능 게이팅용). 없으면 null.
create or replace function core.entitled_plan_code(org uuid, app text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.code
  from core.app_entitlements e
  join core.plans p on p.id = e.plan_id
  where e.org_id = org and e.app_id = app and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now());
$$;

-- 세션 컨텍스트를 요청당 1회로 모은다(proxy.ts, 레이아웃, Route Handler 공용).
-- 반환: {user_id, email, display_name, platform_role, status, org:{id,name,slug,role}|null, app_id, plan_code, entitled, credit_balance}
-- 비로그인 또는 프로필 없음 → null. 프로필이 없으면 호출 측은 로그아웃 처리한다(기본 admin 금지).
create or replace function core.session_context(p_app text default null, p_org uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_profile core.profiles;
  v_org     uuid;
  v_org_row core.organizations;
  v_role    text;
  v_plan    text;
  v_balance integer;
begin
  if v_uid is null then
    return null;
  end if;
  select * into v_profile from core.profiles p where p.id = v_uid;
  if not found then
    return null;
  end if;

  v_org := coalesce(p_org, (
    select o.id from core.organizations o
    where o.owner_id = v_uid and o.is_personal and o.deleted_at is null
    order by o.created_at limit 1));

  if v_org is not null then
    select m.role into v_role from core.org_members m
    where m.org_id = v_org and m.user_id = v_uid and m.status = 'active';
    if v_role is null then
      v_org := null;
    else
      select * into v_org_row from core.organizations o where o.id = v_org and o.deleted_at is null;
      if p_app is not null then
        v_plan := core.entitled_plan_code(v_org, p_app);
      end if;
      select w.plan_balance + w.pack_balance into v_balance from core.wallets w where w.org_id = v_org;
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
grant execute on function core.session_context(text, uuid) to authenticated;

grant execute on function core.current_org_ids() to anon, authenticated;
grant execute on function core.is_org_member(uuid) to anon, authenticated;
grant execute on function core.has_org_role(uuid, text[]) to anon, authenticated;
grant execute on function core.current_org_role(uuid) to anon, authenticated;
grant execute on function core.has_entitlement(uuid, text) to anon, authenticated;
grant execute on function core.is_platform_admin() to anon, authenticated;
grant execute on function core.entitled_plan_code(uuid, text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. 권한 컬럼 보호 트리거 (profiles: platform_role/status/email, organizations: owner_id/is_personal/deleted_at)
--    컬럼 단위 GRANT(0001)가 1차 방어, 이 트리거가 2차 방어다.
-- ---------------------------------------------------------------------
create or replace function core.guard_profile_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if core.is_privileged_session() then
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
drop trigger if exists profiles_guard_columns on core.profiles;
create trigger profiles_guard_columns before update on core.profiles
  for each row execute function core.guard_profile_columns();

create or replace function core.guard_organization_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if core.is_privileged_session() then
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
drop trigger if exists organizations_guard_columns on core.organizations;
create trigger organizations_guard_columns before update on core.organizations
  for each row execute function core.guard_organization_columns();

-- ---------------------------------------------------------------------
-- 3. audit_log (append-only)
-- ---------------------------------------------------------------------
create table if not exists core.audit_log (
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
create index if not exists audit_log_org_created_idx on core.audit_log (org_id, created_at desc);
create index if not exists audit_log_actor_idx on core.audit_log (actor_id, created_at desc);
create index if not exists audit_log_target_idx on core.audit_log (target_type, target_id);

create or replace function core.audit_log_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and core.is_privileged_session() then
    return old;
  end if;
  raise exception 'core.audit_log is append-only (%)', tg_op using errcode = 'AU000';
end;
$$;
drop trigger if exists audit_log_immutable on core.audit_log;
create trigger audit_log_immutable before update or delete on core.audit_log
  for each row execute function core.audit_log_immutable();
drop trigger if exists audit_log_guard_write on core.audit_log;
create trigger audit_log_guard_write before insert on core.audit_log
  for each row execute function core.guard_privileged_write();

alter table core.audit_log enable row level security;
grant select on core.audit_log to authenticated;

-- 사용자 세션에서 감사 기록을 남기는 유일한 경로. actor는 항상 auth.uid()로 강제한다.
create or replace function core.write_audit(
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
  if not core.is_service_caller() then
    if auth.uid() is null or (p_org_id is not null and not core.is_org_member(p_org_id)) then
      raise exception 'write_audit: not a member of the organization' using errcode = '42501';
    end if;
  end if;
  insert into core.audit_log (org_id, actor_id, actor_role, action, target_type, target_id, before, after, metadata)
  values (p_org_id, auth.uid(), case when core.jwt_role() = 'service_role' then 'service' when auth.uid() is null then 'system' else 'user' end,
          p_action, p_target_type, p_target_id, p_before, p_after, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function core.write_audit(uuid, text, text, text, jsonb, jsonb, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 4. 멤버 관리 함수 (SECURITY DEFINER, authenticated 호출 가능, 내부에서 역할 검사)
--    - 자기 자신의 역할은 바꿀 수 없다.
--    - owner는 transfer_ownership으로만 바뀐다.
--    - admin은 member/viewer까지만 부여할 수 있다.
-- ---------------------------------------------------------------------
create or replace function core.invite_member(p_org_id uuid, p_user_id uuid, p_role text default 'member')
returns core.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller_role text; v_row core.org_members;
begin
  v_caller_role := core.current_org_role(p_org_id);
  if not core.is_service_caller() then
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

  insert into core.org_members (org_id, user_id, role, status, invited_by)
  values (p_org_id, p_user_id, p_role, 'invited', auth.uid())
  on conflict (org_id, user_id) do update
    set role = excluded.role, status = case when core.org_members.status = 'active' then 'active' else 'invited' end,
        invited_by = excluded.invited_by
  returning * into v_row;

  perform core.write_audit(p_org_id, 'org_member.invite', 'user', p_user_id::text, null, jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function core.accept_invite(p_org_id uuid)
returns core.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.org_members;
begin
  update core.org_members
  set status = 'active', joined_at = now()
  where org_id = p_org_id and user_id = auth.uid() and status = 'invited'
  returning * into v_row;
  if not found then
    raise exception 'accept_invite: no pending invitation' using errcode = 'P0002';
  end if;
  perform core.write_audit(p_org_id, 'org_member.accept', 'user', auth.uid()::text);
  return v_row;
end;
$$;

-- 승인제: pending 멤버를 활성화 (owner/admin)
create or replace function core.approve_member(p_org_id uuid, p_user_id uuid)
returns core.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.org_members;
begin
  if not core.is_service_caller() and not core.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'approve_member: owner/admin only' using errcode = '42501';
  end if;
  update core.org_members set status = 'active', joined_at = coalesce(joined_at, now())
  where org_id = p_org_id and user_id = p_user_id and status = 'pending'
  returning * into v_row;
  if not found then
    raise exception 'approve_member: no pending member' using errcode = 'P0002';
  end if;
  perform core.write_audit(p_org_id, 'org_member.approve', 'user', p_user_id::text);
  return v_row;
end;
$$;

create or replace function core.change_member_role(p_org_id uuid, p_user_id uuid, p_role text)
returns core.org_members
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller_role text; v_target core.org_members; v_row core.org_members;
begin
  v_caller_role := core.current_org_role(p_org_id);
  if not core.is_service_caller() then
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
  select * into v_target from core.org_members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'change_member_role: member not found' using errcode = 'P0002';
  end if;
  if v_target.role = 'owner' then
    raise exception 'change_member_role: use transfer_ownership for the owner' using errcode = '42501';
  end if;
  if v_caller_role = 'admin' and (p_role = 'admin' or v_target.role = 'admin') then
    raise exception 'change_member_role: admin cannot change admin roles' using errcode = '42501';
  end if;

  update core.org_members set role = p_role where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform core.write_audit(p_org_id, 'org_member.role', 'user', p_user_id::text,
                           jsonb_build_object('role', v_target.role), jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function core.remove_member(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller_role text; v_target core.org_members;
begin
  v_caller_role := core.current_org_role(p_org_id);
  select * into v_target from core.org_members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    return;
  end if;
  if v_target.role = 'owner' then
    raise exception 'remove_member: owner cannot be removed' using errcode = '42501';
  end if;
  if not core.is_service_caller() then
    if p_user_id <> auth.uid() and coalesce(v_caller_role, '') not in ('owner', 'admin') then
      raise exception 'remove_member: owner/admin only' using errcode = '42501';
    end if;
    if v_caller_role = 'admin' and v_target.role = 'admin' and p_user_id <> auth.uid() then
      raise exception 'remove_member: admin cannot remove admin' using errcode = '42501';
    end if;
  end if;
  delete from core.org_members where org_id = p_org_id and user_id = p_user_id;
  perform core.write_audit(p_org_id, 'org_member.remove', 'user', p_user_id::text, jsonb_build_object('role', v_target.role), null);
end;
$$;

create or replace function core.transfer_ownership(p_org_id uuid, p_new_owner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_service_caller() and coalesce(core.current_org_role(p_org_id), '') <> 'owner' then
    raise exception 'transfer_ownership: owner only' using errcode = '42501';
  end if;
  if not exists (select 1 from core.org_members where org_id = p_org_id and user_id = p_new_owner and status = 'active') then
    raise exception 'transfer_ownership: new owner must be an active member' using errcode = 'P0002';
  end if;
  update core.org_members set role = 'admin' where org_id = p_org_id and role = 'owner';
  update core.org_members set role = 'owner' where org_id = p_org_id and user_id = p_new_owner;
  update core.organizations set owner_id = p_new_owner where id = p_org_id;
  perform core.write_audit(p_org_id, 'organization.transfer_ownership', 'user', p_new_owner::text);
end;
$$;

-- 플랫폼 운영자: 승인제 프로필 활성화
create or replace function core.approve_profile(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_service_caller() and not core.is_platform_admin() then
    raise exception 'approve_profile: platform_admin only' using errcode = '42501';
  end if;
  update core.profiles set status = 'active' where id = p_user_id and status = 'pending';
  perform core.write_audit(null, 'profile.approve', 'user', p_user_id::text);
end;
$$;

grant execute on function core.invite_member(uuid, uuid, text) to authenticated;
grant execute on function core.accept_invite(uuid) to authenticated;
grant execute on function core.approve_member(uuid, uuid) to authenticated;
grant execute on function core.change_member_role(uuid, uuid, text) to authenticated;
grant execute on function core.remove_member(uuid, uuid) to authenticated;
grant execute on function core.transfer_ownership(uuid, uuid) to authenticated;
grant execute on function core.approve_profile(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5. oauth_states: 서버 발급 nonce. 사용자 권한 없음. 생성/소비는 service_role만.
-- ---------------------------------------------------------------------
create table if not exists core.oauth_states (
  state         text primary key,
  user_id       uuid not null,
  org_id        uuid not null references core.organizations(id) on delete cascade,
  app_id        text not null references core.apps(id),
  provider      text not null,
  redirect_to   text,
  code_verifier text,
  expires_at    timestamptz not null default (now() + interval '10 minutes'),
  consumed_at   timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists oauth_states_expires_idx on core.oauth_states (expires_at);
alter table core.oauth_states enable row level security;
drop trigger if exists oauth_states_guard_write on core.oauth_states;
create trigger oauth_states_guard_write before insert or update or delete on core.oauth_states
  for each row execute function core.guard_privileged_write();

create or replace function core.create_oauth_state(
  p_user_id       uuid,
  p_org_id        uuid,
  p_app_id        text,
  p_provider      text,
  p_redirect_to   text    default null,
  p_code_verifier text    default null,
  p_ttl_seconds   integer default 600
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_state text;
begin
  if not core.is_privileged_session() then
    raise exception 'create_oauth_state: service_role only' using errcode = '42501';
  end if;
  if not exists (select 1 from core.org_members m where m.org_id = p_org_id and m.user_id = p_user_id and m.status = 'active') then
    raise exception 'create_oauth_state: user is not a member of org' using errcode = '42501';
  end if;
  -- redirect_to는 같은 사이트 경로만 허용('/'로 시작, '//'와 '@' 금지)
  if p_redirect_to is not null and (p_redirect_to !~ '^/[^/]' or p_redirect_to ~ '@') then
    raise exception 'create_oauth_state: redirect_to must be a relative path' using errcode = '22023';
  end if;
  v_state := encode(extensions.gen_random_bytes(32), 'hex');
  insert into core.oauth_states (state, user_id, org_id, app_id, provider, redirect_to, code_verifier, expires_at)
  values (v_state, p_user_id, p_org_id, p_app_id, p_provider, p_redirect_to, p_code_verifier,
          now() + make_interval(secs => greatest(p_ttl_seconds, 60)));
  return v_state;
end;
$$;

-- 1회 소비. 만료/재사용이면 SQLSTATE 'OA001'.
create or replace function core.consume_oauth_state(p_state text)
returns core.oauth_states
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.oauth_states;
begin
  if not core.is_privileged_session() then
    raise exception 'consume_oauth_state: service_role only' using errcode = '42501';
  end if;
  update core.oauth_states
  set consumed_at = now()
  where state = p_state and consumed_at is null and expires_at > now()
  returning * into v_row;
  if not found then
    raise exception 'oauth_state_invalid' using errcode = 'OA001';
  end if;
  return v_row;
end;
$$;

create or replace function core.purge_expired_oauth_states()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if not core.is_privileged_session() then
    raise exception 'purge_expired_oauth_states: service_role only' using errcode = '42501';
  end if;
  delete from core.oauth_states where expires_at < now() - interval '1 day';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- 6. encrypted_credentials: OAuth 토큰, 마켓 API 키 등. 암호문(AES-256-GCM, 앱 계층)만 저장.
--    키는 환경변수(버전별)로만 존재하며 DB에는 key_version만 기록한다. 평문 컬럼 없음.
-- ---------------------------------------------------------------------
create table if not exists core.encrypted_credentials (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  app_id              text not null references core.apps(id),
  provider            text not null,
  external_account_id text not null default '',
  label               text,
  ciphertext          text not null,
  key_version         integer not null,
  scopes              text[] not null default '{}',
  expires_at          timestamptz,
  status              text not null default 'active'
                      constraint encrypted_credentials_status_check check (status in ('active', 'expired', 'revoked', 'error')),
  last_refreshed_at   timestamptz,
  last_error          text,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (org_id, app_id, provider, external_account_id)
);
create index if not exists encrypted_credentials_org_idx on core.encrypted_credentials (org_id, app_id, provider);
drop trigger if exists encrypted_credentials_set_updated_at on core.encrypted_credentials;
create trigger encrypted_credentials_set_updated_at before update on core.encrypted_credentials
  for each row execute function core.set_updated_at();
alter table core.encrypted_credentials enable row level security;
drop trigger if exists encrypted_credentials_guard_write on core.encrypted_credentials;
create trigger encrypted_credentials_guard_write before insert or update or delete on core.encrypted_credentials
  for each row execute function core.guard_privileged_write();

-- 사용자에게는 암호문을 뺀 요약만(정의자 뷰 + 멤버십 필터)
create or replace view core.credential_summaries as
  select c.id, c.org_id, c.app_id, c.provider, c.external_account_id, c.label, c.scopes,
         c.expires_at, c.status, c.last_refreshed_at, c.created_at, c.updated_at
  from core.encrypted_credentials c
  where c.org_id in (select m.org_id from core.org_members m where m.user_id = auth.uid() and m.status = 'active');
grant select on core.credential_summaries to authenticated;

-- 사용자가 연결을 끊는 유일한 경로(소프트 revoke). 삭제는 service_role.
create or replace function core.revoke_credential(p_credential_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  select org_id into v_org from core.encrypted_credentials where id = p_credential_id;
  if v_org is null then
    return;
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_org, array['owner', 'admin']) then
    raise exception 'revoke_credential: owner/admin only' using errcode = '42501';
  end if;
  update core.encrypted_credentials set status = 'revoked', ciphertext = '', updated_at = now() where id = p_credential_id;
  perform core.write_audit(v_org, 'credential.revoke', 'credential', p_credential_id::text);
end;
$$;
grant execute on function core.revoke_credential(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 7. rate_limit_buckets: 고정 윈도우 카운터. Redis가 없는 제품의 기본 레이트 리밋.
-- ---------------------------------------------------------------------
create table if not exists core.rate_limit_buckets (
  key          text primary key,
  window_start timestamptz not null,
  count        integer not null default 0,
  updated_at   timestamptz not null default now()
);
alter table core.rate_limit_buckets enable row level security;
drop trigger if exists rate_limit_buckets_guard_write on core.rate_limit_buckets;
create trigger rate_limit_buckets_guard_write before insert or update or delete on core.rate_limit_buckets
  for each row execute function core.guard_privileged_write();

-- 반환: allowed, remaining, reset_at. 호출 1회 = 1 히트.
create or replace function core.rate_limit_hit(p_key text, p_limit integer, p_window_seconds integer)
returns table (allowed boolean, remaining integer, reset_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer; v_start timestamptz; v_win interval;
begin
  if not core.is_privileged_session() then
    raise exception 'rate_limit_hit: service_role only' using errcode = '42501';
  end if;
  v_win := make_interval(secs => p_window_seconds);
  insert into core.rate_limit_buckets as b (key, window_start, count)
  values (p_key, now(), 1)
  on conflict (key) do update
    set count        = case when b.window_start + v_win <= now() then 1 else b.count + 1 end,
        window_start = case when b.window_start + v_win <= now() then now() else b.window_start end,
        updated_at   = now()
  returning b.count, b.window_start into v_count, v_start;
  return query select v_count <= p_limit, greatest(p_limit - v_count, 0), v_start + v_win;
end;
$$;

create or replace function core.purge_rate_limit_buckets(p_older_than interval default interval '1 day')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if not core.is_privileged_session() then
    raise exception 'purge_rate_limit_buckets: service_role only' using errcode = '42501';
  end if;
  delete from core.rate_limit_buckets where updated_at < now() - p_older_than;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- 8. RLS 정책 (core 전 테이블). 모두 authenticated 대상, 쓰기 정책은 두지 않는다.
--    쓰기가 필요한 것은 (a) 컬럼 GRANT + UPDATE 정책(profiles/organizations) (b) SECURITY DEFINER 함수뿐.
-- ---------------------------------------------------------------------
-- profiles
drop policy if exists profiles_select on core.profiles;
create policy profiles_select on core.profiles for select to authenticated
  using (
    id = auth.uid()
    or core.is_platform_admin()
    or id in (select m.user_id from core.org_members m where m.org_id in (select core.current_org_ids()))
  );
drop policy if exists profiles_update_self on core.profiles;
create policy profiles_update_self on core.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- organizations
drop policy if exists organizations_select on core.organizations;
create policy organizations_select on core.organizations for select to authenticated
  using (deleted_at is null and (core.is_org_member(id) or core.is_platform_admin()));
drop policy if exists organizations_update_admin on core.organizations;
create policy organizations_update_admin on core.organizations for update to authenticated
  using (deleted_at is null and core.has_org_role(id, array['owner', 'admin']))
  with check (core.has_org_role(id, array['owner', 'admin']));

-- org_members (읽기만; 쓰기는 함수)
drop policy if exists org_members_select on core.org_members;
create policy org_members_select on core.org_members for select to authenticated
  using (core.is_org_member(org_id) or user_id = auth.uid() or core.is_platform_admin());

-- apps / plans / credit_packs: 공개 읽기
drop policy if exists apps_select on core.apps;
create policy apps_select on core.apps for select to anon, authenticated using (status <> 'disabled');
drop policy if exists plans_select on core.plans;
create policy plans_select on core.plans for select to anon, authenticated using (is_active);
drop policy if exists credit_packs_select on core.credit_packs;
create policy credit_packs_select on core.credit_packs for select to anon, authenticated using (is_active);

-- 조직 데이터 읽기
drop policy if exists subscriptions_select on core.subscriptions;
create policy subscriptions_select on core.subscriptions for select to authenticated using (core.is_org_member(org_id));
drop policy if exists app_entitlements_select on core.app_entitlements;
create policy app_entitlements_select on core.app_entitlements for select to authenticated using (core.is_org_member(org_id));
drop policy if exists payment_orders_select on core.payment_orders;
create policy payment_orders_select on core.payment_orders for select to authenticated using (core.is_org_member(org_id));
drop policy if exists payments_select on core.payments;
create policy payments_select on core.payments for select to authenticated using (core.is_org_member(org_id));
drop policy if exists wallets_select on core.wallets;
create policy wallets_select on core.wallets for select to authenticated using (core.is_org_member(org_id));
drop policy if exists credit_ledger_select on core.credit_ledger;
create policy credit_ledger_select on core.credit_ledger for select to authenticated using (core.is_org_member(org_id));
drop policy if exists ai_usage_select on core.ai_usage;
create policy ai_usage_select on core.ai_usage for select to authenticated using (core.is_org_member(org_id));
drop policy if exists audit_log_select on core.audit_log;
create policy audit_log_select on core.audit_log for select to authenticated
  using ((org_id is not null and core.has_org_role(org_id, array['owner', 'admin'])) or core.is_platform_admin());

-- billing_keys, webhook_events, oauth_states, encrypted_credentials, rate_limit_buckets: 정책 없음(= 사용자 접근 불가)
