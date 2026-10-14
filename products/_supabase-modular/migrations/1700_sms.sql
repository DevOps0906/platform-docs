-- =====================================================================
-- 1700_sms.sql
-- admin-suite / apps/sms 도메인(학급, 과목, 구성원, 출석). 선행: core 0000~0006 (+ seed.sql)
-- 기획: docs/products/admin-suite/05_DATA_MODEL.md
--
-- 설계 요약
--   - 테넌트 = core.organizations(학교). sms.workspaces 행이 있는 조직만 도메인 데이터를 가진다.
--   - 역할: admin = core org 역할 owner/admin(파생). teacher / student = sms.members.sms_role.
--     teacher 는 제안 역할이다(출석 체크와 조회만, 학급/과목/구성원 관리 불가).
--   - 가입은 초대제: 관리자가 sms.invite_school_member 로 초대 → 본인이 sms.accept_school_invite 로 수락.
--   - 역할/학급/상태 컬럼은 사용자가 직접 쓰지 못한다(GRANT 없음 + guard 트리거 + DEFINER RPC).
--   - 학생은 자기 출석만 본다. 출석 쓰기는 RPC(mark_attendance)만.
--   - 출석 날짜(attend_date)는 KST 수업일(date)이다. 시각이 아니라 달력 날짜라 date 를 쓴다.
-- 반복 실행 가능.
-- =====================================================================

create schema if not exists sms;
grant usage on schema sms to anon, authenticated, service_role;
alter default privileges in schema sms grant all on tables to service_role;
alter default privileges in schema sms grant all on sequences to service_role;
alter default privileges in schema sms grant execute on functions to service_role;
alter default privileges in schema sms revoke execute on functions from public;

-- 앱 등록 (seed.sql 에 이미 있으면 그대로 둔다). 가입 정책: 초대제.
insert into core.apps (id, name, schema_name, signup_policy) values ('sms', 'Admin Suite School', 'sms', 'invite')
on conflict (id) do nothing;

insert into core.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('sms', 'default',  'Default',  0,     'none',  0, 0, false, '{"max_students": 100, "max_classes": 5, "export_xlsx": false, "attendance_trend_days": 31}', true,  true, 0),
  ('sms', 'standard', 'Standard', 39000, 'month', 0, 0, false, '{"max_students": 1500, "max_classes": 60, "export_xlsx": true, "attendance_trend_days": 366}', false, true, 1)
on conflict do nothing;

-- =====================================================================
-- 1. 테이블
-- =====================================================================
create table if not exists sms.workspaces (
  org_id      uuid primary key references core.organizations(id) on delete cascade,
  school_name text not null constraint workspaces_school_name_check check (char_length(school_name) between 1 and 120),
  school_year integer not null default extract(year from (now() at time zone 'Asia/Seoul'))::integer
              constraint workspaces_school_year_check check (school_year between 2000 and 2100),
  status      text not null default 'active' constraint workspaces_status_check check (status in ('active', 'suspended')),
  teacher_backfill_days integer not null default 7 constraint workspaces_backfill_check check (teacher_backfill_days between 0 and 60),
  settings    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists sms.classes (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  name                text not null constraint classes_name_check check (char_length(name) between 1 and 40),
  grade               smallint not null constraint classes_grade_check check (grade between 1 and 12),
  homeroom_teacher_id uuid,
  created_by          uuid default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint classes_org_id_uniq unique (org_id, id),
  constraint classes_org_name_uniq unique (org_id, name)
);

create table if not exists sms.subjects (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  class_id   uuid not null,
  name       text not null constraint subjects_name_check check (char_length(name) between 1 and 40),
  teacher_id uuid,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subjects_org_id_uniq unique (org_id, id),
  constraint subjects_class_name_uniq unique (org_id, class_id, name),
  constraint subjects_class_fk foreign key (org_id, class_id) references sms.classes (org_id, id) on delete cascade
);

-- members: 학교 구성원(교사/학생). admin 은 core 역할이라 행이 없어도 된다.
create table if not exists sms.members (
  org_id       uuid not null references core.organizations(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  sms_role     text not null constraint members_sms_role_check check (sms_role in ('teacher', 'student')),
  display_name text not null default '' constraint members_display_name_check check (char_length(display_name) <= 80),
  class_id     uuid,
  student_no   text constraint members_student_no_check check (student_no is null or student_no ~ '^[0-9A-Za-z-]{1,20}$'),
  status       text not null default 'invited' constraint members_status_check check (status in ('invited', 'active', 'suspended')),
  invited_by   uuid,
  invited_at   timestamptz not null default now(),
  joined_at    timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (org_id, user_id),
  constraint members_class_fk foreign key (org_id, class_id) references sms.classes (org_id, id) on delete set null (class_id),
  constraint members_student_class_check check (sms_role = 'student' or (class_id is null and student_no is null))
);
create unique index if not exists members_student_no_uniq on sms.members (org_id, student_no) where student_no is not null;
create index if not exists members_class_idx on sms.members (org_id, class_id) where sms_role = 'student';
create index if not exists members_user_idx on sms.members (user_id);

create table if not exists sms.attendance (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  class_id    uuid not null,
  subject_id  uuid not null,
  student_id  uuid not null,
  attend_date date not null,
  status      text not null constraint attendance_status_check check (status in ('present', 'late', 'early_leave', 'absent')),
  note        text constraint attendance_note_check check (note is null or char_length(note) <= 200),
  marked_by   uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint attendance_uniq unique (org_id, student_id, subject_id, attend_date),
  constraint attendance_class_fk foreign key (org_id, class_id) references sms.classes (org_id, id) on delete cascade,
  constraint attendance_subject_fk foreign key (org_id, subject_id) references sms.subjects (org_id, id) on delete cascade
);
create index if not exists attendance_org_date_idx on sms.attendance (org_id, attend_date);
create index if not exists attendance_class_date_idx on sms.attendance (org_id, class_id, attend_date);
create index if not exists attendance_student_date_idx on sms.attendance (student_id, attend_date);

drop trigger if exists workspaces_set_updated_at on sms.workspaces;
create trigger workspaces_set_updated_at before update on sms.workspaces for each row execute function core.set_updated_at();
drop trigger if exists classes_set_updated_at on sms.classes;
create trigger classes_set_updated_at before update on sms.classes for each row execute function core.set_updated_at();
drop trigger if exists subjects_set_updated_at on sms.subjects;
create trigger subjects_set_updated_at before update on sms.subjects for each row execute function core.set_updated_at();
drop trigger if exists members_set_updated_at on sms.members;
create trigger members_set_updated_at before update on sms.members for each row execute function core.set_updated_at();
drop trigger if exists attendance_set_updated_at on sms.attendance;
create trigger attendance_set_updated_at before update on sms.attendance for each row execute function core.set_updated_at();

drop trigger if exists workspaces_guard_write on sms.workspaces;
create trigger workspaces_guard_write before insert or update or delete on sms.workspaces for each row execute function core.guard_privileged_write();
drop trigger if exists members_guard_write on sms.members;
create trigger members_guard_write before insert or update or delete on sms.members for each row execute function core.guard_privileged_write();
drop trigger if exists attendance_guard_write on sms.attendance;
create trigger attendance_guard_write before insert or update or delete on sms.attendance for each row execute function core.guard_privileged_write();

create or replace function sms.members_guard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'invited'   and new.status in ('active', 'suspended'))
    or (old.status = 'active'    and new.status = 'suspended')
    or (old.status = 'suspended' and new.status = 'active')) then
    raise exception 'members: transition % -> % not allowed', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists members_guard_transition on sms.members;
create trigger members_guard_transition before update on sms.members for each row execute function sms.members_guard_transition();

-- =====================================================================
-- 2. 역할 헬퍼
-- =====================================================================
create or replace function sms.has_access(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
     and exists (select 1 from core.profiles p where p.id = auth.uid() and p.status = 'active')
     and exists (select 1 from sms.workspaces w where w.org_id = p_org and w.status = 'active')
     and core.has_entitlement(p_org, 'sms')
     and core.is_org_member(p_org)
     and (core.has_org_role(p_org, array['owner', 'admin'])
          or exists (select 1 from sms.members m
                     where m.org_id = p_org and m.user_id = auth.uid() and m.status = 'active'));
$$;

create or replace function sms.is_admin(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select sms.has_access(p_org) and core.has_org_role(p_org, array['owner', 'admin']);
$$;

-- 교직원(admin 또는 teacher)
create or replace function sms.is_staff(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select sms.has_access(p_org)
     and (core.has_org_role(p_org, array['owner', 'admin'])
          or exists (select 1 from sms.members m
                     where m.org_id = p_org and m.user_id = auth.uid() and m.status = 'active' and m.sms_role = 'teacher'));
$$;

create or replace function sms.my_role(p_org uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not sms.has_access(p_org) then null
    when core.has_org_role(p_org, array['owner', 'admin']) then 'admin'
    else (select m.sms_role from sms.members m where m.org_id = p_org and m.user_id = auth.uid() and m.status = 'active')
  end;
$$;

revoke execute on function sms.has_access(uuid) from public, anon;
revoke execute on function sms.is_admin(uuid) from public, anon;
revoke execute on function sms.is_staff(uuid) from public, anon;
revoke execute on function sms.my_role(uuid) from public, anon;
grant execute on function sms.has_access(uuid) to authenticated, service_role;
grant execute on function sms.is_admin(uuid) to authenticated, service_role;
grant execute on function sms.is_staff(uuid) to authenticated, service_role;
grant execute on function sms.my_role(uuid) to authenticated, service_role;

-- =====================================================================
-- 3. RLS 정책과 GRANT
-- =====================================================================
alter table sms.workspaces enable row level security;
alter table sms.classes    enable row level security;
alter table sms.subjects   enable row level security;
alter table sms.members    enable row level security;
alter table sms.attendance enable row level security;

revoke all on table sms.workspaces, sms.classes, sms.subjects, sms.members, sms.attendance from public, anon, authenticated;
grant all on table sms.workspaces, sms.classes, sms.subjects, sms.members, sms.attendance to service_role;

grant select on sms.workspaces to authenticated;
drop policy if exists workspaces_select on sms.workspaces;
create policy workspaces_select on sms.workspaces for select to authenticated using (sms.has_access(org_id));

-- classes / subjects: 조회는 접근 가능한 전원, 쓰기는 admin (순수 콘텐츠 테이블)
grant select, insert, update, delete on sms.classes to authenticated;
drop policy if exists classes_select on sms.classes;
create policy classes_select on sms.classes for select to authenticated using (sms.has_access(org_id));
drop policy if exists classes_insert on sms.classes;
create policy classes_insert on sms.classes for insert to authenticated with check (sms.is_admin(org_id));
drop policy if exists classes_update on sms.classes;
create policy classes_update on sms.classes for update to authenticated using (sms.is_admin(org_id)) with check (sms.is_admin(org_id));
drop policy if exists classes_delete on sms.classes;
create policy classes_delete on sms.classes for delete to authenticated using (sms.is_admin(org_id));

grant select, insert, update, delete on sms.subjects to authenticated;
drop policy if exists subjects_select on sms.subjects;
create policy subjects_select on sms.subjects for select to authenticated using (sms.has_access(org_id));
drop policy if exists subjects_insert on sms.subjects;
create policy subjects_insert on sms.subjects for insert to authenticated with check (sms.is_admin(org_id));
drop policy if exists subjects_update on sms.subjects;
create policy subjects_update on sms.subjects for update to authenticated using (sms.is_admin(org_id)) with check (sms.is_admin(org_id));
drop policy if exists subjects_delete on sms.subjects;
create policy subjects_delete on sms.subjects for delete to authenticated using (sms.is_admin(org_id));

-- members: 본인 행(초대 대기 포함) + 교직원 전체. 쓰기 GRANT 없음.
grant select on sms.members to authenticated;
drop policy if exists members_select on sms.members;
create policy members_select on sms.members for select to authenticated
  using (user_id = auth.uid() or sms.is_staff(org_id));

-- attendance: 교직원 전체, 학생은 자기 행만. 쓰기 GRANT 없음.
grant select on sms.attendance to authenticated;
drop policy if exists attendance_select on sms.attendance;
create policy attendance_select on sms.attendance for select to authenticated
  using (sms.is_staff(org_id) or (student_id = auth.uid() and sms.has_access(org_id)));

-- =====================================================================
-- 4. RPC
-- =====================================================================
create or replace function sms.register_workspace(p_org_id uuid, p_school_name text)
returns sms.workspaces
language plpgsql
security definer
set search_path = ''
as $$
declare v_row sms.workspaces;
begin
  if not core.is_privileged_session() then
    raise exception 'register_workspace: service_role only' using errcode = '42501';
  end if;
  insert into sms.workspaces (org_id, school_name) values (p_org_id, p_school_name)
  on conflict (org_id) do update set school_name = excluded.school_name, status = 'active'
  returning * into v_row;
  perform core.write_audit(p_org_id, 'sms_workspace.register', 'organization', p_org_id::text);
  return v_row;
end;
$$;
revoke execute on function sms.register_workspace(uuid, text) from public, anon, authenticated;
grant execute on function sms.register_workspace(uuid, text) to service_role;

create or replace function sms.update_workspace_settings(p_org_id uuid, p_school_name text, p_school_year integer, p_teacher_backfill_days integer)
returns sms.workspaces
language plpgsql
security definer
set search_path = ''
as $$
declare v_row sms.workspaces;
begin
  if not core.is_service_caller() and not sms.is_admin(p_org_id) then
    raise exception 'update_workspace_settings: admin only' using errcode = '42501';
  end if;
  update sms.workspaces
  set school_name = coalesce(p_school_name, school_name),
      school_year = coalesce(p_school_year, school_year),
      teacher_backfill_days = coalesce(p_teacher_backfill_days, teacher_backfill_days)
  where org_id = p_org_id returning * into v_row;
  if not found then
    raise exception 'update_workspace_settings: workspace not found' using errcode = 'P0002';
  end if;
  perform core.write_audit(p_org_id, 'sms_workspace.update', 'organization', p_org_id::text, null, to_jsonb(v_row) - 'settings');
  return v_row;
end;
$$;

-- 초대(admin). 미가입 이메일은 서버가 Auth Admin inviteUserByEmail 로 사용자를 먼저 만든다(service_role).
create or replace function sms.invite_school_member(
  p_org_id uuid, p_user_id uuid, p_sms_role text, p_display_name text, p_class_id uuid default null, p_student_no text default null
)
returns sms.members
language plpgsql
security definer
set search_path = ''
as $$
declare v_row sms.members;
begin
  if not core.is_service_caller() then
    if not sms.is_admin(p_org_id) then
      raise exception 'invite_school_member: admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'invite_school_member: cannot invite yourself' using errcode = '22023';
    end if;
  end if;
  if coalesce(p_sms_role, '') not in ('teacher', 'student') then
    raise exception 'invite_school_member: role must be teacher/student' using errcode = '22023';
  end if;
  if p_sms_role = 'teacher' and (p_class_id is not null or p_student_no is not null) then
    raise exception 'invite_school_member: teacher has no class_id/student_no' using errcode = '22023';
  end if;
  if p_class_id is not null and not exists (select 1 from sms.classes c where c.id = p_class_id and c.org_id = p_org_id) then
    raise exception 'invite_school_member: class not in organization' using errcode = '22023';
  end if;
  if exists (select 1 from core.org_members m where m.org_id = p_org_id and m.user_id = p_user_id and m.role in ('owner', 'admin')) then
    raise exception 'invite_school_member: target is an admin' using errcode = '22023';
  end if;

  perform core.invite_member(p_org_id, p_user_id, 'member');

  insert into sms.members (org_id, user_id, sms_role, display_name, class_id, student_no, status, invited_by)
  values (p_org_id, p_user_id, p_sms_role, left(coalesce(btrim(p_display_name), ''), 80), p_class_id, nullif(btrim(p_student_no), ''), 'invited', auth.uid())
  on conflict (org_id, user_id) do update
    set sms_role = excluded.sms_role, display_name = excluded.display_name, class_id = excluded.class_id,
        student_no = excluded.student_no, invited_by = excluded.invited_by
  returning * into v_row;
  perform core.write_audit(p_org_id, 'school_member.invite', 'user', p_user_id::text, null,
                           jsonb_build_object('sms_role', p_sms_role, 'class_id', p_class_id));
  return v_row;
end;
$$;

-- 초대 수락(본인): core 멤버십과 sms.members 를 함께 활성화한다.
create or replace function sms.accept_school_invite(p_org_id uuid)
returns sms.members
language plpgsql
security definer
set search_path = ''
as $$
declare v_row sms.members;
begin
  if auth.uid() is null then
    raise exception 'accept_school_invite: login required' using errcode = '42501';
  end if;
  select * into v_row from sms.members where org_id = p_org_id and user_id = auth.uid() and status = 'invited' for update;
  if not found then
    raise exception 'accept_school_invite: no pending invitation' using errcode = 'P0002';
  end if;
  if exists (select 1 from core.org_members m where m.org_id = p_org_id and m.user_id = auth.uid() and m.status = 'invited') then
    perform core.accept_invite(p_org_id);
  end if;
  update sms.members set status = 'active', joined_at = now()
  where org_id = p_org_id and user_id = auth.uid() returning * into v_row;
  return v_row;
end;
$$;

-- 역할 변경(admin, 자기 자신 불가). 교사로 바꾸면 학급/학번을 비운다.
create or replace function sms.set_member_role(p_org_id uuid, p_user_id uuid, p_sms_role text)
returns sms.members
language plpgsql
security definer
set search_path = ''
as $$
declare v_before sms.members; v_row sms.members;
begin
  if not core.is_service_caller() then
    if not sms.is_admin(p_org_id) then
      raise exception 'set_member_role: admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'set_member_role: cannot change your own role' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_sms_role, '') not in ('teacher', 'student') then
    raise exception 'set_member_role: role must be teacher/student' using errcode = '22023';
  end if;
  select * into v_before from sms.members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'set_member_role: member not found' using errcode = 'P0002';
  end if;
  update sms.members
  set sms_role = p_sms_role,
      class_id = case when p_sms_role = 'teacher' then null else class_id end,
      student_no = case when p_sms_role = 'teacher' then null else student_no end
  where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform core.write_audit(p_org_id, 'school_member.role', 'user', p_user_id::text,
                           jsonb_build_object('sms_role', v_before.sms_role), jsonb_build_object('sms_role', p_sms_role));
  return v_row;
end;
$$;

-- 학생 학급 배정(admin)
create or replace function sms.assign_class(p_org_id uuid, p_user_id uuid, p_class_id uuid, p_student_no text default null)
returns sms.members
language plpgsql
security definer
set search_path = ''
as $$
declare v_before sms.members; v_row sms.members;
begin
  if not core.is_service_caller() and not sms.is_admin(p_org_id) then
    raise exception 'assign_class: admin only' using errcode = '42501';
  end if;
  if p_class_id is not null and not exists (select 1 from sms.classes c where c.id = p_class_id and c.org_id = p_org_id) then
    raise exception 'assign_class: class not in organization' using errcode = '22023';
  end if;
  select * into v_before from sms.members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'assign_class: member not found' using errcode = 'P0002';
  end if;
  if v_before.sms_role <> 'student' then
    raise exception 'assign_class: only students have a class' using errcode = 'SM003';
  end if;
  update sms.members set class_id = p_class_id, student_no = coalesce(nullif(btrim(p_student_no), ''), student_no)
  where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform core.write_audit(p_org_id, 'school_member.assign_class', 'user', p_user_id::text,
                           jsonb_build_object('class_id', v_before.class_id), jsonb_build_object('class_id', p_class_id));
  return v_row;
end;
$$;

create or replace function sms.set_member_status(p_org_id uuid, p_user_id uuid, p_status text)
returns sms.members
language plpgsql
security definer
set search_path = ''
as $$
declare v_before sms.members; v_row sms.members;
begin
  if not core.is_service_caller() then
    if not sms.is_admin(p_org_id) then
      raise exception 'set_member_status: admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'set_member_status: cannot change your own status' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_status, '') not in ('active', 'suspended') then
    raise exception 'set_member_status: invalid status' using errcode = '22023';
  end if;
  select * into v_before from sms.members where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'set_member_status: member not found' using errcode = 'P0002';
  end if;
  update sms.members set status = p_status where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform core.write_audit(p_org_id, 'school_member.status', 'user', p_user_id::text,
                           jsonb_build_object('status', v_before.status), jsonb_build_object('status', p_status));
  return v_row;
end;
$$;

-- 출석 체크(admin/teacher). upsert. 학생은 그 과목 학급의 활성 학생이어야 한다.
-- 날짜: 미래 불가. teacher 는 KST 오늘 기준 workspaces.teacher_backfill_days 일 이전까지만(제안 기본 7일), admin 은 제한 없음.
create or replace function sms.mark_attendance(
  p_subject_id uuid, p_student_id uuid, p_attend_date date, p_status text, p_note text default null
)
returns sms.attendance
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_subj  sms.subjects;
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_back  integer;
  v_row   sms.attendance;
begin
  select * into v_subj from sms.subjects where id = p_subject_id;
  if not found then
    raise exception 'mark_attendance: subject not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not sms.is_staff(v_subj.org_id) then
    raise exception 'mark_attendance: admin/teacher only' using errcode = '42501';
  end if;
  if coalesce(p_status, '') not in ('present', 'late', 'early_leave', 'absent') then
    raise exception 'mark_attendance: invalid status' using errcode = '22023';
  end if;
  if p_attend_date is null or p_attend_date > v_today then
    raise exception 'mark_attendance: future date not allowed' using errcode = 'SM002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_subj.org_id, array['owner', 'admin']) then
    select w.teacher_backfill_days into v_back from sms.workspaces w where w.org_id = v_subj.org_id;
    if p_attend_date < v_today - coalesce(v_back, 7) then
      raise exception 'mark_attendance: date older than % days requires admin', coalesce(v_back, 7) using errcode = 'SM002';
    end if;
  end if;
  if not exists (select 1 from sms.members m
                 where m.org_id = v_subj.org_id and m.user_id = p_student_id and m.sms_role = 'student'
                   and m.status = 'active' and m.class_id = v_subj.class_id) then
    raise exception 'mark_attendance: student is not an active member of the subject class' using errcode = 'SM001';
  end if;

  insert into sms.attendance (org_id, class_id, subject_id, student_id, attend_date, status, note, marked_by)
  values (v_subj.org_id, v_subj.class_id, p_subject_id, p_student_id, p_attend_date, p_status, nullif(btrim(p_note), ''), auth.uid())
  on conflict (org_id, student_id, subject_id, attend_date) do update
    set status = excluded.status, note = excluded.note, marked_by = excluded.marked_by
  returning * into v_row;
  return v_row;
end;
$$;

-- 일괄 체크: p_entries = [{"student_id": "...", "status": "present", "note": null}, ...] 최대 200건
create or replace function sms.mark_attendance_bulk(p_subject_id uuid, p_attend_date date, p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare r jsonb; v_count integer := 0;
begin
  if jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) > 200 then
    raise exception 'mark_attendance_bulk: entries must be an array of at most 200' using errcode = '22023';
  end if;
  for r in select value from jsonb_array_elements(p_entries) loop
    perform sms.mark_attendance(p_subject_id, (r ->> 'student_id')::uuid, p_attend_date, r ->> 'status', r ->> 'note');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- 관리자/교사 대시보드 통계. 출석률 정의(01_PRD SMS-F-008):
--   records          = 그날 기록된 (학생 x 과목) 출석 행 수
--   attendance_rate  = (present + late + early_leave) / records
--   on_time_rate     = present / records
--   expected         = 그날 학급별 (활성 학생 수 x 과목 수) 합, unchecked = expected - records
create or replace function sms.dashboard_stats(p_org_id uuid, p_date date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_date date := coalesce(p_date, (now() at time zone 'Asia/Seoul')::date);
  v_res  jsonb;
begin
  if not core.is_service_caller() and not sms.is_staff(p_org_id) then
    raise exception 'dashboard_stats: admin/teacher only' using errcode = '42501';
  end if;
  with a as (
    select status, class_id from sms.attendance where org_id = p_org_id and attend_date = v_date
  ), cls as (
    select c.id, c.name, c.grade,
           (select count(*) from sms.members m where m.org_id = p_org_id and m.class_id = c.id and m.sms_role = 'student' and m.status = 'active') as students,
           (select count(*) from sms.subjects s where s.org_id = p_org_id and s.class_id = c.id) as subjects
    from sms.classes c where c.org_id = p_org_id
  )
  select jsonb_build_object(
    'date', v_date,
    'student_count', (select count(*) from sms.members m where m.org_id = p_org_id and m.sms_role = 'student' and m.status = 'active'),
    'class_count', (select count(*) from cls),
    'records', (select count(*) from a),
    'present', (select count(*) from a where status = 'present'),
    'late', (select count(*) from a where status = 'late'),
    'early_leave', (select count(*) from a where status = 'early_leave'),
    'absent', (select count(*) from a where status = 'absent'),
    'attendance_rate', (select case when count(*) = 0 then null
                               else round(100.0 * count(*) filter (where status <> 'absent') / count(*), 1) end from a),
    'on_time_rate', (select case when count(*) = 0 then null
                            else round(100.0 * count(*) filter (where status = 'present') / count(*), 1) end from a),
    'expected', (select coalesce(sum(students * subjects), 0) from cls),
    'unchecked', greatest((select coalesce(sum(students * subjects), 0) from cls) - (select count(*) from a), 0),
    'by_class', coalesce((select jsonb_agg(jsonb_build_object(
                    'class_id', cls.id, 'name', cls.name, 'grade', cls.grade,
                    'records', (select count(*) from a where a.class_id = cls.id),
                    'attendance_rate', (select case when count(*) = 0 then null
                                         else round(100.0 * count(*) filter (where a.status <> 'absent') / count(*), 1) end
                                        from a where a.class_id = cls.id)) order by cls.grade, cls.name) from cls), '[]'::jsonb)
  ) into v_res;
  return v_res;
end;
$$;

-- 기간별 출석 추이(admin/teacher). 최대 366일.
create or replace function sms.attendance_trend(p_org_id uuid, p_from date, p_to date, p_class_id uuid default null)
returns table (attend_date date, records bigint, attended bigint, attendance_rate numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not core.is_service_caller() and not sms.is_staff(p_org_id) then
    raise exception 'attendance_trend: admin/teacher only' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'attendance_trend: invalid range' using errcode = '22023';
  end if;
  return query
    select a.attend_date, count(*)::bigint, (count(*) filter (where a.status <> 'absent'))::bigint,
           round(100.0 * count(*) filter (where a.status <> 'absent') / count(*), 1)
    from sms.attendance a
    where a.org_id = p_org_id and a.attend_date between p_from and p_to
      and (p_class_id is null or a.class_id = p_class_id)
    group by a.attend_date
    order by a.attend_date;
end;
$$;

-- 학생 본인 요약: 이번 달(KST) 출석률, 지각/조퇴/결석 횟수, 오늘 과목
create or replace function sms.student_summary(p_org_id uuid, p_month date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from date := date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Seoul')::date))::date;
  v_to   date := (date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Seoul')::date)) + interval '1 month')::date;
  v_me   sms.members;
begin
  if not sms.has_access(p_org_id) then
    raise exception 'student_summary: no access' using errcode = '42501';
  end if;
  select * into v_me from sms.members where org_id = p_org_id and user_id = auth.uid() and sms_role = 'student' and status = 'active';
  if not found then
    raise exception 'student_summary: students only' using errcode = 'SM003';
  end if;
  return (
    with a as (select status from sms.attendance where org_id = p_org_id and student_id = auth.uid()
               and attend_date >= v_from and attend_date < v_to)
    select jsonb_build_object(
      'month', v_from,
      'records', (select count(*) from a),
      'attendance_rate', (select case when count(*) = 0 then null
                                 else round(100.0 * count(*) filter (where status <> 'absent') / count(*), 1) end from a),
      'late', (select count(*) from a where status = 'late'),
      'early_leave', (select count(*) from a where status = 'early_leave'),
      'absent', (select count(*) from a where status = 'absent'),
      'class_id', v_me.class_id,
      'today_subjects', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.name)
                                  from sms.subjects s where s.org_id = p_org_id and s.class_id = v_me.class_id), '[]'::jsonb)
    )
  );
end;
$$;

do $$
declare s text;
begin
  foreach s in array array[
    'sms.update_workspace_settings(uuid,text,integer,integer)',
    'sms.invite_school_member(uuid,uuid,text,text,uuid,text)', 'sms.accept_school_invite(uuid)',
    'sms.set_member_role(uuid,uuid,text)', 'sms.assign_class(uuid,uuid,uuid,text)', 'sms.set_member_status(uuid,uuid,text)',
    'sms.mark_attendance(uuid,uuid,date,text,text)', 'sms.mark_attendance_bulk(uuid,date,jsonb)',
    'sms.dashboard_stats(uuid,date)', 'sms.attendance_trend(uuid,date,date,uuid)', 'sms.student_summary(uuid,date)'
  ] loop
    execute format('revoke execute on function %s from public, anon', s);
    execute format('grant execute on function %s to authenticated, service_role', s);
  end loop;
end $$;

-- =====================================================================
-- 5. Realtime: 출석 보드, 학생 알림. 채널 이름 sms:<org>:attendance
-- =====================================================================
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'sms' and tablename = 'attendance') then
    alter publication supabase_realtime add table sms.attendance;
  end if;
end $$;

-- =====================================================================
-- 6. PUBLIC EXECUTE 회수 (0007_core_function_privileges.sql 와 같은 규칙)
--   alter default privileges ... revoke from public 은 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 지우지 못한다.
--   이 스키마의 모든 함수에서 PUBLIC 을 회수한다. 위에서 authenticated/service_role 에 준 명시 GRANT 는 유지된다.
-- =====================================================================
revoke execute on all functions in schema sms from public;
grant execute on all functions in schema sms to service_role;


-- =====================================================================
-- 7. AI·음성 기본값 (2026-10-13, 확정 결정 13~17)
--   설계: docs/products/admin-suite/02_ARCHITECTURE.md 5절, 01_PRD.md 3.6~3.7절. 정본 규칙은 _platform-core/AI_ARCHITECTURE.md 4장, VOICE_ARCHITECTURE.md 3장.
--   모든 값은 제안이며 이 조각과 모놀리스 seed에서만 바꾼다(운영 화면에서 바꾸지 않는다).
--   - admin.assistant : 업무 어시스턴트 그래프(admin.assistant). 기본 체인은 Claude 먼저. 국외 이전 동의가 없는 조직은 resolve_ai_route 가 상용을 걸러 낸다.
--   - wiki.*          : 기관 운영 위키(규정·매뉴얼 정리). 대량 처리라 오픈소스 먼저.
--   - dify.aux        : Dify 보조 LLM 노드. 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--   - admin.knowledge : 사내 규정·매뉴얼 컬렉션 임베딩. 질의와 문서가 같은 모델이어야 하고 동의 여부와 무관해야 하므로 국내 오픈소스 고정.
--   - voice_chat      : 업무 음성 질의. 내부 업무 내용이라 STT, TTS 모두 오픈소스 먼저(ElevenLabs 는 국외 이전 동의 후 대체).
--   크레딧 차감(consume_credits)은 쓰지 않는다. 한도는 plans.features(ai_*)와 레이트 리밋으로 건다.
-- =====================================================================
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'sms', 'admin.assistant', 'llm', 'auto', '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'sms', 'wiki.query', 'llm', 'auto', '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'sms', 'wiki.ingest', 'llm', 'auto', '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'sms', 'wiki.lint', 'llm', 'auto', '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'sms', 'dify.aux', 'llm', 'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'sms', 'admin.knowledge', 'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'sms', 'voice_chat', 'stt', 'auto', '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'sms', 'voice_chat', 'tts', 'auto', '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 플랜 features 의 AI 키 병합(있으면 갱신). 크레딧 과금은 쓰지 않으므로 키는 허용 여부와 한도뿐이다(01_PRD 4.1절).
update core.plans
   set features = features || '{"ai_assistant": true, "ai_turns_per_day": 30, "ai_turns_per_month": 100, "ai_commercial_turns_per_month": 0, "ai_voice": false, "ai_docs_max": 20, "ai_wiki": false}'::jsonb
 where app_id = 'sms' and code = 'default';
update core.plans
   set features = features || '{"ai_assistant": true, "ai_turns_per_day": 200, "ai_turns_per_month": 1500, "ai_commercial_turns_per_month": 300, "ai_voice": true, "ai_docs_max": 500, "ai_wiki": true}'::jsonb
 where app_id = 'sms' and code = 'standard';

-- AI 문서 원본 버킷: 사용자 정책을 일부러 만들지 않는다(service_role 만 접근).
-- org-files 는 같은 조직 구성원이면 읽을 수 있어, 역할별 공개 범위(audience)가 있는 규정 문서가 새어 나갈 수 있기 때문이다.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ai-docs', 'ai-docs', false, 20971520,
        array['text/plain', 'text/markdown', 'application/pdf',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do nothing;

-- 체인 검사: 제공자 행이 있을 때만 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'sms'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'sms routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;
