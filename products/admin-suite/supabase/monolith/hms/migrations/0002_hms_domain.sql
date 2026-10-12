-- =====================================================================
-- admin-suite / hms 모놀리스 0002_hms_domain.sql
-- 병원 앱(hms) 도메인. 모듈러 조각이 없다(확정 결정 2: 의료정보 격리를 위해 별도 DB로만 제공).
-- 선행: 0001_core_lite.sql (public 스키마). 기획: docs/products/admin-suite/05_DATA_MODEL.md 2.3절
--
-- 의료정보 보호 설계 (01_PRD 6.2절)
--   1) 접근 기록: 진료기록, 검사 결과, 환자 연락처/생년월일 같은 민감 항목은 테이블 SELECT 권한을 주지 않는다.
--      읽기는 SECURITY DEFINER RPC 로만 하고, RPC 가 같은 트랜잭션에서 phi_access_log 에 행을 남긴다.
--      phi_access_log 는 append-only(UPDATE 불가, DELETE 는 보존 기간이 지난 행을 service_role 파기 함수만).
--   2) 최소 권한: 역할별 화면/데이터 범위를 RLS 와 RPC 검사로 강제한다.
--        admin(core owner/admin): 직원 관리, 통계, 수납 환불. 진료기록 본문은 doctor 역할이 있어야 본다.
--        doctor: 진료 대기열, 진료기록 작성/열람, 검사 의뢰, 검사 승인.
--        staff(원무): 환자 등록/연락처, 예약, 접수, 수납. 진료기록/검사값 접근 없음.
--        lab_tech: 검사 작업 목록과 결과 입력/승인(작성자와 다른 사람). 환자 연락처 접근 없음.
--      직접 쓰기 GRANT 는 어느 테이블에도 없다. 모든 쓰기는 RPC + guard 트리거(이중 잠금).
--   3) 보존: 진료기록은 append-only(정정은 amends_id 로 새 행). 파기 대상은 retention_candidates() 로 뽑고
--      운영자 승인 뒤 서버가 처리한다. 접속기록 보존 기간 하한 730일(phi_log_retention_days check).
--   4) 암호화: 연락처, 메모, 진료기록 본문은 앱 계층 AES-256-GCM 암호문(*_ciphertext + key_version)만 저장한다.
--      키는 환경변수(HMS_PHI_KEY_V<n>)에만 있고 DB에 없다. DB 는 저장 시 디스크 암호화(Supabase 기본)에 더해 컬럼 암호문만 본다.
--      주민등록번호는 수집하지 않는다.
-- 보안 규칙: authenticated 에 EXECUTE 를 연 DEFINER 함수의 호출자 판정은 public.is_service_caller() 만,
--            역할 비교는 has_org_role(exists) 또는 coalesce 로 NULL-safe.
-- SQLSTATE: HM001 상태 전이 불가, HM002 예약 충돌, HM003 의사 불가용, HM004 검사 값 오류, HM005 동일인 승인, HM006 동의 없음
-- 반복 실행 가능.
-- =====================================================================

-- =====================================================================
-- 1. 테이블
-- =====================================================================
create table if not exists public.workspaces (
  org_id                 uuid primary key references public.organizations(id) on delete cascade,
  hospital_name          text not null constraint workspaces_hospital_name_check check (char_length(hospital_name) between 1 and 120),
  status                 text not null default 'active' constraint workspaces_status_check check (status in ('active', 'suspended')),
  phi_log_retention_days integer not null default 730 constraint workspaces_phi_log_retention_check check (phi_log_retention_days >= 730),
  settings               jsonb not null default '{}'::jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create table if not exists public.staff_profiles (
  org_id       uuid not null references public.organizations(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  role         text not null constraint staff_profiles_role_check check (role in ('doctor', 'staff', 'lab_tech')),
  display_name text not null default '' constraint staff_profiles_display_name_check check (char_length(display_name) <= 80),
  specialty    text constraint staff_profiles_specialty_check check (specialty is null or char_length(specialty) <= 40),
  is_available boolean not null default true,
  status       text not null default 'invited' constraint staff_profiles_status_check check (status in ('invited', 'active', 'suspended')),
  invited_by   uuid,
  joined_at    timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (org_id, user_id)
);

-- patients: 화면 목록에 필요한 최소 식별 정보(디렉토리). RLS 로 admin/doctor/staff 만 조회.
create table if not exists public.patients (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  chart_no    text not null constraint patients_chart_no_check check (chart_no ~ '^[0-9A-Za-z-]{1,20}$'),
  name        text not null constraint patients_name_check check (char_length(name) between 1 and 60),
  sex         text not null default 'U' constraint patients_sex_check check (sex in ('M', 'F', 'U')),
  birth_year  smallint constraint patients_birth_year_check check (birth_year is null or birth_year between 1900 and 2100),
  phone_last4 text constraint patients_phone_last4_check check (phone_last4 is null or phone_last4 ~ '^[0-9]{4}$'),
  has_allergy boolean not null default false,
  crm_tags    text[] not null default '{}' constraint patients_crm_tags_check check (cardinality(crm_tags) <= 10),
  last_visit_at timestamptz,
  deleted_at  timestamptz,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint patients_org_id_uniq unique (org_id, id),
  constraint patients_chart_no_uniq unique (org_id, chart_no)
);
create index if not exists patients_org_name_idx on public.patients (org_id, name) where deleted_at is null;
create index if not exists patients_org_phone_idx on public.patients (org_id, phone_last4) where deleted_at is null;

-- patient_private: 민감 항목. GRANT/정책 없음 → get_patient_detail RPC 로만 읽는다(접근 기록).
create table if not exists public.patient_private (
  patient_id         uuid primary key references public.patients(id) on delete cascade,
  org_id             uuid not null references public.organizations(id) on delete cascade,
  birth_date         date,
  phone_ciphertext   text,
  blood_type         text constraint patient_private_blood_type_check check (blood_type is null or blood_type in ('A+','A-','B+','B-','O+','O-','AB+','AB-')),
  allergies          text constraint patient_private_allergies_check check (allergies is null or char_length(allergies) <= 500),
  memo_ciphertext    text,
  key_version        integer not null default 1,
  privacy_consent_at timestamptz not null,
  updated_at         timestamptz not null default now()
);

create table if not exists public.appointments (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations(id) on delete cascade,
  patient_id         uuid not null,
  doctor_id          uuid,
  scheduled_at       timestamptz not null,
  duration_min       smallint not null default 15 constraint appointments_duration_check check (duration_min between 5 and 240),
  visit_type         text not null default 'first' constraint appointments_visit_type_check check (visit_type in ('first', 'return', 'checkup', 'procedure')),
  status             text not null default 'scheduled'
                     constraint appointments_status_check check (status in ('scheduled', 'checked_in', 'in_consultation', 'completed', 'canceled', 'no_show')),
  queue_no           integer,
  checked_in_at      timestamptz,
  consult_started_at timestamptz,
  completed_at       timestamptz,
  canceled_at        timestamptz,
  cancel_reason      text constraint appointments_cancel_reason_check check (cancel_reason is null or char_length(cancel_reason) <= 200),
  admin_note         text constraint appointments_admin_note_check check (admin_note is null or char_length(admin_note) <= 300),
  created_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint appointments_org_id_uniq unique (org_id, id),
  constraint appointments_patient_fk foreign key (org_id, patient_id) references public.patients (org_id, id),
  constraint appointments_doctor_fk foreign key (org_id, doctor_id) references public.staff_profiles (org_id, user_id) on delete set null (doctor_id)
);
create index if not exists appointments_org_time_idx on public.appointments (org_id, scheduled_at);
create index if not exists appointments_doctor_time_idx on public.appointments (org_id, doctor_id, scheduled_at);
create index if not exists appointments_queue_idx on public.appointments (org_id, status) where status in ('checked_in', 'in_consultation');
create index if not exists appointments_patient_idx on public.appointments (patient_id, scheduled_at desc);

-- medical_records: 진료기록/처방. 본문은 암호문만. append-only(정정은 amends_id 로 새 행).
create table if not exists public.medical_records (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  patient_id      uuid not null,
  appointment_id  uuid,
  author_id       uuid not null,
  record_type     text not null constraint medical_records_type_check check (record_type in ('progress', 'prescription', 'order_note')),
  body_ciphertext text not null,
  key_version     integer not null,
  amends_id       uuid references public.medical_records(id),
  created_at      timestamptz not null default now(),
  constraint medical_records_patient_fk foreign key (org_id, patient_id) references public.patients (org_id, id),
  constraint medical_records_appointment_fk foreign key (org_id, appointment_id) references public.appointments (org_id, id)
);
create index if not exists medical_records_patient_idx on public.medical_records (patient_id, created_at desc);

-- lab_test_catalog: 검사 항목과 정상 범위(Hospital/src/lib/lab-ranges.ts 이식). 전역 참조 데이터.
create table if not exists public.lab_test_catalog (
  code       text primary key constraint lab_test_catalog_code_check check (code ~ '^[A-Z0-9_]{2,20}$'),
  name       text not null,
  parameters jsonb not null constraint lab_test_catalog_parameters_check check (jsonb_typeof(parameters) = 'array'),
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.lab_tests (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations(id) on delete cascade,
  patient_id        uuid not null,
  appointment_id    uuid,
  test_code         text not null references public.lab_test_catalog(code),
  status            text not null default 'requested'
                    constraint lab_tests_status_check check (status in ('requested', 'in_progress', 'resulted', 'approved', 'canceled')),
  result_values     jsonb not null default '{}'::jsonb,
  abnormal_keys     text[] not null default '{}',
  requested_by      uuid not null,
  requested_at      timestamptz not null default now(),
  started_at        timestamptz,
  resulted_by       uuid,
  resulted_at       timestamptz,
  approved_by       uuid,
  approved_at       timestamptz,
  canceled_at       timestamptz,
  cancel_reason     text,
  correction_reason text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint lab_tests_patient_fk foreign key (org_id, patient_id) references public.patients (org_id, id),
  constraint lab_tests_appointment_fk foreign key (org_id, appointment_id) references public.appointments (org_id, id),
  constraint lab_tests_approver_check check (approved_by is null or approved_by <> resulted_by)
);
create index if not exists lab_tests_worklist_idx on public.lab_tests (org_id, status, requested_at);
create index if not exists lab_tests_patient_idx on public.lab_tests (patient_id, requested_at desc);

-- visit_charges: 진료비 수납(원무). Toss 와 무관한 병원 내부 장부.
create table if not exists public.visit_charges (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  appointment_id uuid not null,
  patient_id     uuid not null,
  amount_krw     integer not null constraint visit_charges_amount_check check (amount_krw between 0 and 100000000),
  status         text not null default 'unpaid' constraint visit_charges_status_check check (status in ('unpaid', 'paid', 'refunded', 'void')),
  method         text constraint visit_charges_method_check check (method is null or method in ('card', 'cash', 'transfer', 'other')),
  paid_at        timestamptz,
  refunded_at    timestamptz,
  refund_reason  text,
  handled_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint visit_charges_appointment_uniq unique (org_id, appointment_id),
  constraint visit_charges_appointment_fk foreign key (org_id, appointment_id) references public.appointments (org_id, id),
  constraint visit_charges_patient_fk foreign key (org_id, patient_id) references public.patients (org_id, id)
);
create index if not exists visit_charges_paid_idx on public.visit_charges (org_id, paid_at) where status = 'paid';

-- phi_access_log: 민감정보 접근(조회/작성) 기록. append-only.
create table if not exists public.phi_access_log (
  id          bigint generated always as identity primary key,
  org_id      uuid not null references public.organizations(id) on delete cascade,
  actor_id    uuid,
  actor_role  text,
  action      text not null constraint phi_access_log_action_check check (action ~ '^[a-z_]+\.[a-z_]+$'),
  patient_id  uuid,
  target_type text,
  target_id   text,
  purpose     text,
  row_count   integer,
  created_at  timestamptz not null default now()
);
create index if not exists phi_access_log_org_created_idx on public.phi_access_log (org_id, created_at desc);
create index if not exists phi_access_log_patient_idx on public.phi_access_log (patient_id, created_at desc);
create index if not exists phi_access_log_actor_idx on public.phi_access_log (actor_id, created_at desc);

-- updated_at
drop trigger if exists workspaces_set_updated_at on public.workspaces;
create trigger workspaces_set_updated_at before update on public.workspaces for each row execute function public.set_updated_at();
drop trigger if exists staff_profiles_set_updated_at on public.staff_profiles;
create trigger staff_profiles_set_updated_at before update on public.staff_profiles for each row execute function public.set_updated_at();
drop trigger if exists patients_set_updated_at on public.patients;
create trigger patients_set_updated_at before update on public.patients for each row execute function public.set_updated_at();
drop trigger if exists patient_private_set_updated_at on public.patient_private;
create trigger patient_private_set_updated_at before update on public.patient_private for each row execute function public.set_updated_at();
drop trigger if exists appointments_set_updated_at on public.appointments;
create trigger appointments_set_updated_at before update on public.appointments for each row execute function public.set_updated_at();
drop trigger if exists lab_tests_set_updated_at on public.lab_tests;
create trigger lab_tests_set_updated_at before update on public.lab_tests for each row execute function public.set_updated_at();
drop trigger if exists visit_charges_set_updated_at on public.visit_charges;
create trigger visit_charges_set_updated_at before update on public.visit_charges for each row execute function public.set_updated_at();

-- 이중 잠금: 모든 도메인 테이블에 사용자 세션 직접 쓰기 거부
do $$
declare t text;
begin
  foreach t in array array['workspaces', 'staff_profiles', 'patients', 'patient_private', 'appointments',
                           'medical_records', 'lab_test_catalog', 'lab_tests', 'visit_charges', 'phi_access_log'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_guard_write', t);
    execute format('create trigger %I before insert or update or delete on public.%I for each row execute function public.guard_privileged_write()',
                   t || '_guard_write', t);
  end loop;
end $$;

-- append-only: medical_records, phi_access_log. DELETE 는 파기 함수가 hms.allow_purge 를 켠 트랜잭션에서만.
create or replace function public.hms_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('hms.allow_purge', true) = 'on' and public.is_privileged_session() then
    return old;
  end if;
  raise exception '%.% is append-only (%)', tg_table_schema, tg_table_name, tg_op using errcode = '42501';
end;
$$;
drop trigger if exists medical_records_append_only on public.medical_records;
create trigger medical_records_append_only before update or delete on public.medical_records for each row execute function public.hms_append_only();
drop trigger if exists phi_access_log_append_only on public.phi_access_log;
create trigger phi_access_log_append_only before update or delete on public.phi_access_log for each row execute function public.hms_append_only();

-- 상태 전이 트리거 (service_role 쓰기에도 적용)
create or replace function public.appointments_guard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'scheduled'       and new.status in ('checked_in', 'canceled', 'no_show'))
    or (old.status = 'checked_in'      and new.status in ('in_consultation', 'canceled'))
    or (old.status = 'in_consultation' and new.status = 'completed')) then
    raise exception 'appointments: transition % -> % not allowed', old.status, new.status using errcode = 'HM001';
  end if;
  return new;
end;
$$;
drop trigger if exists appointments_guard_transition on public.appointments;
create trigger appointments_guard_transition before update on public.appointments for each row execute function public.appointments_guard_transition();

create or replace function public.lab_tests_guard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'requested'   and new.status in ('in_progress', 'canceled'))
    or (old.status = 'in_progress' and new.status in ('resulted', 'canceled'))
    or (old.status = 'resulted'    and new.status in ('approved', 'in_progress'))) then
    raise exception 'lab_tests: transition % -> % not allowed', old.status, new.status using errcode = 'HM001';
  end if;
  if old.status = 'approved' and (new.result_values is distinct from old.result_values) then
    raise exception 'lab_tests: approved results are immutable' using errcode = 'HM001';
  end if;
  return new;
end;
$$;
drop trigger if exists lab_tests_guard_transition on public.lab_tests;
create trigger lab_tests_guard_transition before update on public.lab_tests for each row execute function public.lab_tests_guard_transition();

create or replace function public.visit_charges_guard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'unpaid' and new.status in ('paid', 'void'))
    or (old.status = 'paid'   and new.status = 'refunded')) then
    raise exception 'visit_charges: transition % -> % not allowed', old.status, new.status using errcode = 'HM001';
  end if;
  return new;
end;
$$;
drop trigger if exists visit_charges_guard_transition on public.visit_charges;
create trigger visit_charges_guard_transition before update on public.visit_charges for each row execute function public.visit_charges_guard_transition();

-- =====================================================================
-- 2. 역할 헬퍼
-- =====================================================================
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
     and public.has_entitlement(p_org, 'hms')
     and public.is_org_member(p_org)
     and (public.has_org_role(p_org, array['owner', 'admin'])
          or exists (select 1 from public.staff_profiles s
                     where s.org_id = p_org and s.user_id = auth.uid() and s.status = 'active'));
$$;

-- 'admin' 은 core owner/admin 에서 파생. doctor/staff/lab_tech 는 staff_profiles.role.
create or replace function public.has_role(p_org uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_access(p_org)
     and (
          ('admin' = any (p_roles) and public.has_org_role(p_org, array['owner', 'admin']))
       or exists (select 1 from public.staff_profiles s
                  where s.org_id = p_org and s.user_id = auth.uid() and s.status = 'active' and s.role = any (p_roles))
     );
$$;

-- 화면 분기용. admin 이면서 진료 역할이 있으면 'admin' 을 돌려주고, 진료 권한은 has_role 로 따로 판정한다.
create or replace function public.my_role(p_org uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not public.has_access(p_org) then null
    when public.has_org_role(p_org, array['owner', 'admin']) then 'admin'
    else (select s.role from public.staff_profiles s where s.org_id = p_org and s.user_id = auth.uid() and s.status = 'active')
  end;
$$;

-- 접근 기록(내부 전용. authenticated EXECUTE 없음. DEFINER RPC 안에서만 호출)
create or replace function public.log_phi(
  p_org uuid, p_action text, p_patient uuid, p_target_type text, p_target_id text, p_purpose text, p_rows integer
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.phi_access_log (org_id, actor_id, actor_role, action, patient_id, target_type, target_id, purpose, row_count)
  values (p_org, auth.uid(), coalesce(public.my_role(p_org), case when public.is_service_caller() then 'service' end),
          p_action, p_patient, p_target_type, p_target_id, p_purpose, p_rows);
end;
$$;

-- 열람 사유 검증(내부)
create or replace function public.check_purpose(p_purpose text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if coalesce(p_purpose, '') not in ('treatment', 'reception', 'billing', 'lab', 'admin_review', 'patient_request') then
    raise exception 'purpose must be one of treatment/reception/billing/lab/admin_review/patient_request' using errcode = '22023';
  end if;
end;
$$;

-- =====================================================================
-- 3. RLS 정책과 GRANT
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['workspaces', 'staff_profiles', 'patients', 'patient_private', 'appointments',
                           'medical_records', 'lab_test_catalog', 'lab_tests', 'visit_charges', 'phi_access_log'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant all on table public.%I to service_role', t);
  end loop;
end $$;

grant select on public.workspaces to authenticated;
drop policy if exists workspaces_select on public.workspaces;
create policy workspaces_select on public.workspaces for select to authenticated using (public.has_access(org_id));

-- 직원 디렉토리: 같은 병원 접근자 전원(의사 필터, 담당의 표시). 본인 초대 행은 수락 전에도 보인다.
grant select on public.staff_profiles to authenticated;
drop policy if exists staff_profiles_select on public.staff_profiles;
create policy staff_profiles_select on public.staff_profiles for select to authenticated
  using (user_id = auth.uid() or public.has_access(org_id));

-- 환자 디렉토리: admin/doctor/staff. lab_tech 는 작업 목록 RPC 의 환자 이름만.
grant select on public.patients to authenticated;
drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients for select to authenticated
  using (deleted_at is null and public.has_role(org_id, array['admin', 'doctor', 'staff']));

-- 예약/대기열: admin/doctor/staff (Realtime 대기열 구독 대상)
grant select on public.appointments to authenticated;
drop policy if exists appointments_select on public.appointments;
create policy appointments_select on public.appointments for select to authenticated
  using (public.has_role(org_id, array['admin', 'doctor', 'staff']));

-- 검사 카탈로그: 로그인 사용자 읽기
grant select on public.lab_test_catalog to authenticated;
drop policy if exists lab_test_catalog_select on public.lab_test_catalog;
create policy lab_test_catalog_select on public.lab_test_catalog for select to authenticated using (is_active);

-- 수납: admin/staff
grant select on public.visit_charges to authenticated;
drop policy if exists visit_charges_select on public.visit_charges;
create policy visit_charges_select on public.visit_charges for select to authenticated
  using (public.has_role(org_id, array['admin', 'staff']));

-- 접근 기록: admin(core owner/admin)만 열람
grant select on public.phi_access_log to authenticated;
drop policy if exists phi_access_log_select on public.phi_access_log;
create policy phi_access_log_select on public.phi_access_log for select to authenticated
  using (public.has_access(org_id) and public.has_org_role(org_id, array['owner', 'admin']));

-- patient_private, medical_records, lab_tests: GRANT 와 정책 없음 → RPC 로만 읽는다.

-- =====================================================================
-- 4. RPC: 워크스페이스와 직원
-- =====================================================================
create or replace function public.register_workspace(p_org_id uuid, p_hospital_name text)
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
  insert into public.workspaces (org_id, hospital_name) values (p_org_id, p_hospital_name)
  on conflict (org_id) do update set hospital_name = excluded.hospital_name, status = 'active'
  returning * into v_row;
  perform public.write_audit(p_org_id, 'hms_workspace.register', 'organization', p_org_id::text);
  return v_row;
end;
$$;

create or replace function public.invite_staff(p_org_id uuid, p_user_id uuid, p_role text, p_display_name text, p_specialty text default null)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.staff_profiles;
begin
  if not public.is_service_caller() then
    if not public.has_role(p_org_id, array['admin']) then
      raise exception 'invite_staff: admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'invite_staff: cannot invite yourself' using errcode = '22023';
    end if;
  end if;
  if coalesce(p_role, '') not in ('doctor', 'staff', 'lab_tech') then
    raise exception 'invite_staff: invalid role' using errcode = '22023';
  end if;
  if not exists (select 1 from public.org_members m where m.org_id = p_org_id and m.user_id = p_user_id and m.status = 'active') then
    perform public.invite_member(p_org_id, p_user_id, 'member');
  end if;
  insert into public.staff_profiles (org_id, user_id, role, display_name, specialty, status, invited_by)
  values (p_org_id, p_user_id, p_role, left(coalesce(btrim(p_display_name), ''), 80), nullif(btrim(p_specialty), ''),
          case when exists (select 1 from public.org_members m where m.org_id = p_org_id and m.user_id = p_user_id and m.status = 'active')
               then 'active' else 'invited' end, auth.uid())
  on conflict (org_id, user_id) do update
    set role = excluded.role, display_name = excluded.display_name, specialty = excluded.specialty, invited_by = excluded.invited_by
  returning * into v_row;
  perform public.write_audit(p_org_id, 'staff.invite', 'user', p_user_id::text, null, jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function public.accept_staff_invite(p_org_id uuid)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.staff_profiles;
begin
  if auth.uid() is null then
    raise exception 'accept_staff_invite: login required' using errcode = '42501';
  end if;
  select * into v_row from public.staff_profiles where org_id = p_org_id and user_id = auth.uid() and status = 'invited' for update;
  if not found then
    raise exception 'accept_staff_invite: no pending invitation' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.org_members m where m.org_id = p_org_id and m.user_id = auth.uid() and m.status = 'invited') then
    perform public.accept_invite(p_org_id);
  end if;
  update public.staff_profiles set status = 'active', joined_at = now()
  where org_id = p_org_id and user_id = auth.uid() returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.set_staff_role(p_org_id uuid, p_user_id uuid, p_role text)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare v_before public.staff_profiles; v_row public.staff_profiles;
begin
  if not public.is_service_caller() then
    if not public.has_role(p_org_id, array['admin']) then
      raise exception 'set_staff_role: admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'set_staff_role: cannot change your own role' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_role, '') not in ('doctor', 'staff', 'lab_tech') then
    raise exception 'set_staff_role: invalid role' using errcode = '22023';
  end if;
  select * into v_before from public.staff_profiles where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'set_staff_role: staff not found' using errcode = 'P0002';
  end if;
  update public.staff_profiles set role = p_role where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform public.write_audit(p_org_id, 'staff.role', 'user', p_user_id::text,
                             jsonb_build_object('role', v_before.role), jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function public.set_staff_status(p_org_id uuid, p_user_id uuid, p_status text)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare v_before public.staff_profiles; v_row public.staff_profiles;
begin
  if not public.is_service_caller() then
    if not public.has_role(p_org_id, array['admin']) then
      raise exception 'set_staff_status: admin only' using errcode = '42501';
    end if;
    if p_user_id = auth.uid() then
      raise exception 'set_staff_status: cannot change your own status' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_status, '') not in ('active', 'suspended') then
    raise exception 'set_staff_status: invalid status' using errcode = '22023';
  end if;
  select * into v_before from public.staff_profiles where org_id = p_org_id and user_id = p_user_id for update;
  if not found then
    raise exception 'set_staff_status: staff not found' using errcode = 'P0002';
  end if;
  if v_before.status = 'invited' and p_status = 'active' then
    raise exception 'set_staff_status: invited staff must accept first' using errcode = 'HM001';
  end if;
  update public.staff_profiles set status = p_status where org_id = p_org_id and user_id = p_user_id returning * into v_row;
  perform public.write_audit(p_org_id, 'staff.status', 'user', p_user_id::text,
                             jsonb_build_object('status', v_before.status), jsonb_build_object('status', p_status));
  return v_row;
end;
$$;

-- 의사 본인 가용 토글(PRD 3.3). 다른 의사의 값은 바꿀 수 없다(리뷰 Hospital #4).
create or replace function public.set_my_availability(p_org_id uuid, p_available boolean)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.staff_profiles;
begin
  if not public.has_role(p_org_id, array['doctor']) then
    raise exception 'set_my_availability: doctors only' using errcode = '42501';
  end if;
  update public.staff_profiles set is_available = coalesce(p_available, is_available)
  where org_id = p_org_id and user_id = auth.uid() and role = 'doctor' returning * into v_row;
  return v_row;
end;
$$;

-- =====================================================================
-- 5. RPC: 환자
-- =====================================================================
-- 등록(admin/staff). 개인정보 수집 동의(p_consent) 필수. 연락처는 서버가 암호화한 값과 끝 4자리를 넘긴다.
create or replace function public.register_patient(
  p_org_id uuid, p_chart_no text, p_name text, p_sex text, p_birth_date date,
  p_phone_ciphertext text, p_phone_last4 text, p_key_version integer,
  p_blood_type text default null, p_allergies text default null, p_crm_tags text[] default '{}', p_consent boolean default false
)
returns public.patients
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.patients;
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['admin', 'staff']) then
    raise exception 'register_patient: admin/staff only' using errcode = '42501';
  end if;
  if not coalesce(p_consent, false) then
    raise exception 'register_patient: privacy consent required' using errcode = 'HM006';
  end if;
  insert into public.patients (org_id, chart_no, name, sex, birth_year, phone_last4, has_allergy, crm_tags, created_by)
  values (p_org_id, btrim(p_chart_no), btrim(p_name), coalesce(p_sex, 'U'), extract(year from p_birth_date)::smallint,
          p_phone_last4, coalesce(char_length(btrim(p_allergies)), 0) > 0, coalesce(p_crm_tags, '{}'), auth.uid())
  returning * into v_row;
  insert into public.patient_private (patient_id, org_id, birth_date, phone_ciphertext, blood_type, allergies, key_version, privacy_consent_at)
  values (v_row.id, p_org_id, p_birth_date, p_phone_ciphertext, p_blood_type, nullif(btrim(p_allergies), ''), coalesce(p_key_version, 1), now());
  perform public.log_phi(p_org_id, 'patient.create', v_row.id, 'patient', v_row.id::text, 'reception', 1);
  perform public.write_audit(p_org_id, 'patient.create', 'patient', v_row.id::text);
  return v_row;
end;
$$;

create or replace function public.update_patient(
  p_patient_id uuid, p_name text, p_sex text, p_birth_date date,
  p_phone_ciphertext text, p_phone_last4 text, p_key_version integer,
  p_blood_type text, p_allergies text, p_crm_tags text[]
)
returns public.patients
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.patients;
begin
  select * into v_row from public.patients where id = p_patient_id and deleted_at is null for update;
  if not found then
    raise exception 'update_patient: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_row.org_id, array['admin', 'staff']) then
    raise exception 'update_patient: admin/staff only' using errcode = '42501';
  end if;
  update public.patients
  set name = coalesce(nullif(btrim(p_name), ''), name), sex = coalesce(p_sex, sex),
      birth_year = coalesce(extract(year from p_birth_date)::smallint, birth_year),
      phone_last4 = coalesce(p_phone_last4, phone_last4),
      has_allergy = coalesce(char_length(btrim(p_allergies)), 0) > 0,
      crm_tags = coalesce(p_crm_tags, crm_tags)
  where id = p_patient_id returning * into v_row;
  update public.patient_private
  set birth_date = coalesce(p_birth_date, birth_date), phone_ciphertext = coalesce(p_phone_ciphertext, phone_ciphertext),
      key_version = coalesce(p_key_version, key_version), blood_type = p_blood_type, allergies = nullif(btrim(p_allergies), '')
  where patient_id = p_patient_id;
  perform public.log_phi(v_row.org_id, 'patient.update', v_row.id, 'patient', v_row.id::text, 'reception', 1);
  perform public.write_audit(v_row.org_id, 'patient.update', 'patient', v_row.id::text);
  return v_row;
end;
$$;

-- 상세(민감 항목 포함, 암호문은 서버가 복호화). admin/doctor/staff. 접근 기록.
create or replace function public.get_patient_detail(p_patient_id uuid, p_purpose text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_p public.patients; v_x public.patient_private;
begin
  perform public.check_purpose(p_purpose);
  select * into v_p from public.patients where id = p_patient_id and deleted_at is null;
  if not found then
    raise exception 'get_patient_detail: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_p.org_id, array['admin', 'doctor', 'staff']) then
    raise exception 'get_patient_detail: role not allowed' using errcode = '42501';
  end if;
  select * into v_x from public.patient_private where patient_id = p_patient_id;
  perform public.log_phi(v_p.org_id, 'patient.view', v_p.id, 'patient', v_p.id::text, p_purpose, 1);
  return to_jsonb(v_p) || jsonb_build_object(
    'birth_date', v_x.birth_date, 'phone_ciphertext', v_x.phone_ciphertext, 'blood_type', v_x.blood_type,
    'allergies', v_x.allergies, 'memo_ciphertext', v_x.memo_ciphertext, 'key_version', v_x.key_version,
    'privacy_consent_at', v_x.privacy_consent_at);
end;
$$;

-- 검색(이름 접두, 차트번호, 전화 끝 4자리). 최대 50건. 검색 행위를 기록한다.
create or replace function public.search_patients(p_org_id uuid, p_query text)
returns setof public.patients
language plpgsql
security definer
set search_path = ''
as $$
declare v_q text := btrim(coalesce(p_query, '')); v_n integer;
begin
  if not public.has_role(p_org_id, array['admin', 'doctor', 'staff']) then
    raise exception 'search_patients: role not allowed' using errcode = '42501';
  end if;
  if char_length(v_q) < 1 then
    raise exception 'search_patients: query required' using errcode = '22023';
  end if;
  return query
    select * from public.patients p
    where p.org_id = p_org_id and p.deleted_at is null
      and (p.name like replace(replace(v_q, '%', ''), '_', '') || '%' or p.chart_no = v_q or p.phone_last4 = v_q)
    order by p.name limit 50;
  get diagnostics v_n = row_count;
  perform public.log_phi(p_org_id, 'patient.search', null, 'patient', null, 'reception', v_n);
end;
$$;

-- 목록 화면 접근 기록(앱이 대기열/캘린더/환자 목록을 렌더할 때 호출). action 은 view.* 만.
create or replace function public.log_phi_access(p_org_id uuid, p_action text, p_patient_id uuid default null, p_row_count integer default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_access(p_org_id) then
    raise exception 'log_phi_access: no access' using errcode = '42501';
  end if;
  if coalesce(p_action, '') !~ '^view\.[a-z_]+$' then
    raise exception 'log_phi_access: action must be view.<screen>' using errcode = '22023';
  end if;
  perform public.log_phi(p_org_id, p_action, p_patient_id, 'screen', null, null, p_row_count);
end;
$$;

-- 환자 삭제(소프트, admin). 진료기록은 보존 의무 때문에 지우지 않는다.
create or replace function public.archive_patient(p_patient_id uuid, p_reason text)
returns public.patients
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.patients;
begin
  select * into v_row from public.patients where id = p_patient_id and deleted_at is null for update;
  if not found then
    raise exception 'archive_patient: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_row.org_id, array['admin']) then
    raise exception 'archive_patient: admin only' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'archive_patient: reason required' using errcode = '22023';
  end if;
  update public.patients set deleted_at = now() where id = p_patient_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'patient.archive', 'patient', v_row.id::text, null, jsonb_build_object('reason', p_reason));
  return v_row;
end;
$$;

-- =====================================================================
-- 6. RPC: 예약과 대기열
-- =====================================================================
create or replace function public.create_appointment(
  p_org_id uuid, p_patient_id uuid, p_doctor_id uuid, p_scheduled_at timestamptz,
  p_duration_min smallint default 15, p_visit_type text default 'first', p_admin_note text default null
)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare v_doc public.staff_profiles; v_row public.appointments;
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['admin', 'staff']) then
    raise exception 'create_appointment: admin/staff only' using errcode = '42501';
  end if;
  if not exists (select 1 from public.patients p where p.id = p_patient_id and p.org_id = p_org_id and p.deleted_at is null) then
    raise exception 'create_appointment: patient not found' using errcode = 'P0002';
  end if;
  select * into v_doc from public.staff_profiles where org_id = p_org_id and user_id = p_doctor_id and role = 'doctor' and status = 'active';
  if not found then
    raise exception 'create_appointment: doctor not found' using errcode = 'P0002';
  end if;
  if not v_doc.is_available then
    raise exception 'create_appointment: doctor is unavailable' using errcode = 'HM003';
  end if;
  if p_scheduled_at < now() - interval '10 minutes' then
    raise exception 'create_appointment: past time' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('hms:doctor:' || p_doctor_id::text));
  if exists (select 1 from public.appointments a
             where a.org_id = p_org_id and a.doctor_id = p_doctor_id and a.status not in ('canceled', 'no_show')
               and tstzrange(a.scheduled_at, a.scheduled_at + make_interval(mins => a.duration_min))
                   && tstzrange(p_scheduled_at, p_scheduled_at + make_interval(mins => coalesce(p_duration_min, 15)::integer))) then
    raise exception 'create_appointment: time slot overlaps' using errcode = 'HM002';
  end if;
  insert into public.appointments (org_id, patient_id, doctor_id, scheduled_at, duration_min, visit_type, admin_note, created_by)
  values (p_org_id, p_patient_id, p_doctor_id, p_scheduled_at, coalesce(p_duration_min, 15), coalesce(p_visit_type, 'first'),
          nullif(btrim(p_admin_note), ''), auth.uid())
  returning * into v_row;
  perform public.write_audit(p_org_id, 'appointment.create', 'appointment', v_row.id::text);
  return v_row;
end;
$$;

-- 상태 전이. 누가 무엇을: 05_DATA_MODEL 3절 표.
create or replace function public.transition_appointment(p_appointment_id uuid, p_to text, p_reason text default null)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   public.appointments;
  v_start timestamptz := (date_trunc('day', now() at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul';
  v_ok    boolean;
begin
  select * into v_row from public.appointments where id = p_appointment_id for update;
  if not found then
    raise exception 'transition_appointment: not found' using errcode = 'P0002';
  end if;
  v_ok := public.is_service_caller() or case coalesce(p_to, '')
    when 'checked_in'      then public.has_role(v_row.org_id, array['admin', 'staff'])
    when 'canceled'        then public.has_role(v_row.org_id, array['admin', 'staff'])
    when 'no_show'         then public.has_role(v_row.org_id, array['admin', 'staff'])
    when 'in_consultation' then public.has_role(v_row.org_id, array['admin']) or (public.has_role(v_row.org_id, array['doctor']) and v_row.doctor_id = auth.uid())
    when 'completed'       then public.has_role(v_row.org_id, array['admin']) or (public.has_role(v_row.org_id, array['doctor']) and v_row.doctor_id = auth.uid())
    else false end;
  if not v_ok then
    raise exception 'transition_appointment: role not allowed for %', p_to using errcode = '42501';
  end if;
  if p_to = 'no_show' and v_row.scheduled_at > now() then
    raise exception 'transition_appointment: no_show only after scheduled time' using errcode = 'HM001';
  end if;
  if p_to = 'canceled' and char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'transition_appointment: cancel reason required' using errcode = '22023';
  end if;
  update public.appointments
  set status = p_to,
      checked_in_at = case when p_to = 'checked_in' then now() else checked_in_at end,
      queue_no = case when p_to = 'checked_in' then coalesce((select max(a.queue_no) from public.appointments a
                       where a.org_id = v_row.org_id and a.checked_in_at >= v_start), 0) + 1 else queue_no end,
      consult_started_at = case when p_to = 'in_consultation' then now() else consult_started_at end,
      completed_at = case when p_to = 'completed' then now() else completed_at end,
      canceled_at = case when p_to = 'canceled' then now() else canceled_at end,
      cancel_reason = case when p_to = 'canceled' then btrim(p_reason) else cancel_reason end
  where id = p_appointment_id
  returning * into v_row;
  if p_to = 'completed' then
    update public.patients set last_visit_at = now() where id = v_row.patient_id;
  end if;
  perform public.write_audit(v_row.org_id, 'appointment.' || p_to, 'appointment', v_row.id::text);
  return v_row;
end;
$$;

create or replace function public.reschedule_appointment(p_appointment_id uuid, p_scheduled_at timestamptz)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.appointments;
begin
  select * into v_row from public.appointments where id = p_appointment_id for update;
  if not found then
    raise exception 'reschedule_appointment: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_role(v_row.org_id, array['admin', 'staff']) then
    raise exception 'reschedule_appointment: admin/staff only' using errcode = '42501';
  end if;
  if v_row.status <> 'scheduled' then
    raise exception 'reschedule_appointment: only scheduled appointments' using errcode = 'HM001';
  end if;
  perform pg_advisory_xact_lock(hashtext('hms:doctor:' || v_row.doctor_id::text));
  if exists (select 1 from public.appointments a
             where a.org_id = v_row.org_id and a.doctor_id = v_row.doctor_id and a.id <> v_row.id
               and a.status not in ('canceled', 'no_show')
               and tstzrange(a.scheduled_at, a.scheduled_at + make_interval(mins => a.duration_min))
                   && tstzrange(p_scheduled_at, p_scheduled_at + make_interval(mins => v_row.duration_min::integer))) then
    raise exception 'reschedule_appointment: time slot overlaps' using errcode = 'HM002';
  end if;
  update public.appointments set scheduled_at = p_scheduled_at where id = p_appointment_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'appointment.reschedule', 'appointment', v_row.id::text);
  return v_row;
end;
$$;

-- =====================================================================
-- 7. RPC: 진료기록 (doctor)
-- =====================================================================
create or replace function public.add_medical_record(
  p_patient_id uuid, p_appointment_id uuid, p_record_type text, p_body_ciphertext text, p_key_version integer, p_amends_id uuid default null
)
returns public.medical_records
language plpgsql
security definer
set search_path = ''
as $$
declare v_p public.patients; v_row public.medical_records;
begin
  select * into v_p from public.patients where id = p_patient_id and deleted_at is null;
  if not found then
    raise exception 'add_medical_record: patient not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_p.org_id, array['doctor']) then
    raise exception 'add_medical_record: doctors only' using errcode = '42501';
  end if;
  if p_appointment_id is not null and not exists (
       select 1 from public.appointments a where a.id = p_appointment_id and a.patient_id = p_patient_id) then
    raise exception 'add_medical_record: appointment does not belong to patient' using errcode = '22023';
  end if;
  if p_amends_id is not null and not exists (
       select 1 from public.medical_records r where r.id = p_amends_id and r.patient_id = p_patient_id) then
    raise exception 'add_medical_record: amended record not found' using errcode = '22023';
  end if;
  if char_length(coalesce(p_body_ciphertext, '')) < 16 or p_key_version is null then
    raise exception 'add_medical_record: ciphertext required' using errcode = '22023';
  end if;
  insert into public.medical_records (org_id, patient_id, appointment_id, author_id, record_type, body_ciphertext, key_version, amends_id)
  values (v_p.org_id, p_patient_id, p_appointment_id, auth.uid(), p_record_type, p_body_ciphertext, p_key_version, p_amends_id)
  returning * into v_row;
  perform public.log_phi(v_p.org_id, 'chart.write', p_patient_id, 'medical_record', v_row.id::text, 'treatment', 1);
  return v_row;
end;
$$;

-- 환자 360 차트(doctor). 예약 + 진료기록 + 검사를 시간 역순 타임라인으로 병합(리뷰 Hospital 작업 #9).
create or replace function public.get_patient_chart(p_patient_id uuid, p_purpose text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_p public.patients; v_timeline jsonb;
begin
  perform public.check_purpose(p_purpose);
  select * into v_p from public.patients where id = p_patient_id and deleted_at is null;
  if not found then
    raise exception 'get_patient_chart: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_p.org_id, array['doctor']) then
    raise exception 'get_patient_chart: doctors only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(e order by (e ->> 'at')::timestamptz desc), '[]'::jsonb) into v_timeline
  from (
    select jsonb_build_object('kind', 'appointment', 'id', a.id, 'at', a.scheduled_at, 'status', a.status,
                              'visit_type', a.visit_type, 'doctor_id', a.doctor_id) as e
    from public.appointments a where a.patient_id = p_patient_id
    union all
    select jsonb_build_object('kind', 'record', 'id', r.id, 'at', r.created_at, 'record_type', r.record_type,
                              'author_id', r.author_id, 'body_ciphertext', r.body_ciphertext, 'key_version', r.key_version,
                              'amends_id', r.amends_id)
    from public.medical_records r where r.patient_id = p_patient_id
    union all
    select jsonb_build_object('kind', 'lab', 'id', t.id, 'at', coalesce(t.resulted_at, t.requested_at), 'test_code', t.test_code,
                              'status', t.status, 'result_values', t.result_values, 'abnormal_keys', to_jsonb(t.abnormal_keys))
    from public.lab_tests t where t.patient_id = p_patient_id
  ) x;
  perform public.log_phi(v_p.org_id, 'chart.view', p_patient_id, 'patient', p_patient_id::text, p_purpose, jsonb_array_length(v_timeline));
  return jsonb_build_object('patient', to_jsonb(v_p), 'timeline', v_timeline);
end;
$$;

-- =====================================================================
-- 8. RPC: 검사
-- =====================================================================
create or replace function public.request_lab_test(p_patient_id uuid, p_appointment_id uuid, p_test_code text)
returns public.lab_tests
language plpgsql
security definer
set search_path = ''
as $$
declare v_p public.patients; v_row public.lab_tests;
begin
  select * into v_p from public.patients where id = p_patient_id and deleted_at is null;
  if not found then
    raise exception 'request_lab_test: patient not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_p.org_id, array['doctor']) then
    raise exception 'request_lab_test: doctors only' using errcode = '42501';
  end if;
  if not exists (select 1 from public.lab_test_catalog c where c.code = p_test_code and c.is_active) then
    raise exception 'request_lab_test: unknown test' using errcode = '22023';
  end if;
  insert into public.lab_tests (org_id, patient_id, appointment_id, test_code, requested_by)
  values (v_p.org_id, p_patient_id, p_appointment_id, p_test_code, auth.uid())
  returning * into v_row;
  perform public.write_audit(v_p.org_id, 'lab_test.request', 'lab_test', v_row.id::text);
  return v_row;
end;
$$;

-- 작업 목록(lab_tech/doctor). 환자 이름과 차트번호만 붙인다. 조회를 기록한다.
create or replace function public.list_lab_worklist(p_org_id uuid, p_statuses text[] default array['requested', 'in_progress', 'resulted'])
returns table (id uuid, patient_id uuid, patient_name text, chart_no text, test_code text, status text,
               result_values jsonb, abnormal_keys text[], requested_at timestamptz, resulted_by uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare v_n integer;
begin
  if not public.has_role(p_org_id, array['lab_tech', 'doctor']) then
    raise exception 'list_lab_worklist: lab_tech/doctor only' using errcode = '42501';
  end if;
  return query
    select t.id, t.patient_id, p.name, p.chart_no, t.test_code, t.status, t.result_values, t.abnormal_keys, t.requested_at, t.resulted_by
    from public.lab_tests t join public.patients p on p.id = t.patient_id
    where t.org_id = p_org_id and t.status = any (p_statuses)
    order by t.requested_at
    limit 500;
  get diagnostics v_n = row_count;
  perform public.log_phi(p_org_id, 'lab.worklist', null, 'lab_test', null, 'lab', v_n);
end;
$$;

create or replace function public.start_lab_test(p_test_id uuid)
returns public.lab_tests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.lab_tests;
begin
  select * into v_row from public.lab_tests where id = p_test_id for update;
  if not found then
    raise exception 'start_lab_test: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['lab_tech']) then
    raise exception 'start_lab_test: lab_tech only' using errcode = '42501';
  end if;
  update public.lab_tests set status = 'in_progress', started_at = now() where id = p_test_id returning * into v_row;
  return v_row;
end;
$$;

-- 결과 저장(lab_tech). 모든 항목이 숫자여야 한다(빈 값 0 대체 금지, 리뷰 Hospital #15). 정상범위 이탈 키를 계산한다.
create or replace function public.save_lab_result(p_test_id uuid, p_values jsonb, p_correction_reason text default null)
returns public.lab_tests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.lab_tests; v_params jsonb; v_param jsonb; v_key text; v_abn text[] := '{}'; v_num numeric;
begin
  select * into v_row from public.lab_tests where id = p_test_id for update;
  if not found then
    raise exception 'save_lab_result: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['lab_tech']) then
    raise exception 'save_lab_result: lab_tech only' using errcode = '42501';
  end if;
  if v_row.status not in ('in_progress', 'resulted') then
    raise exception 'save_lab_result: test is %', v_row.status using errcode = 'HM001';
  end if;
  if v_row.status = 'resulted' and char_length(btrim(coalesce(p_correction_reason, ''))) < 2 then
    raise exception 'save_lab_result: correction reason required' using errcode = '22023';
  end if;
  if jsonb_typeof(p_values) <> 'object' then
    raise exception 'save_lab_result: values must be an object' using errcode = 'HM004';
  end if;
  select c.parameters into v_params from public.lab_test_catalog c where c.code = v_row.test_code;
  for v_param in select value from jsonb_array_elements(v_params) loop
    v_key := v_param ->> 'key';
    if jsonb_typeof(p_values -> v_key) is distinct from 'number' then
      raise exception 'save_lab_result: % must be a number', v_key using errcode = 'HM004';
    end if;
    v_num := (p_values ->> v_key)::numeric;
    if v_num < (v_param ->> 'min')::numeric or v_num > (v_param ->> 'max')::numeric then
      v_abn := v_abn || v_key;
    end if;
  end loop;
  if exists (select 1 from jsonb_object_keys(p_values) k
             where k not in (select e ->> 'key' from jsonb_array_elements(v_params) e)) then
    raise exception 'save_lab_result: unknown parameter' using errcode = 'HM004';
  end if;
  update public.lab_tests
  set status = 'resulted', result_values = p_values, abnormal_keys = v_abn, resulted_by = auth.uid(), resulted_at = now(),
      correction_reason = case when v_row.status = 'resulted' then btrim(p_correction_reason) else correction_reason end
  where id = p_test_id returning * into v_row;
  perform public.log_phi(v_row.org_id, 'lab.write', v_row.patient_id, 'lab_test', v_row.id::text, 'lab', 1);
  return v_row;
end;
$$;

-- 승인: lab_tech 또는 doctor, 결과 입력자와 다른 사람(제안: 이중 확인)
create or replace function public.approve_lab_result(p_test_id uuid)
returns public.lab_tests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.lab_tests;
begin
  select * into v_row from public.lab_tests where id = p_test_id for update;
  if not found then
    raise exception 'approve_lab_result: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['lab_tech', 'doctor']) then
    raise exception 'approve_lab_result: lab_tech/doctor only' using errcode = '42501';
  end if;
  if v_row.status <> 'resulted' then
    raise exception 'approve_lab_result: test is %', v_row.status using errcode = 'HM001';
  end if;
  if v_row.resulted_by = auth.uid() then
    raise exception 'approve_lab_result: approver must differ from the person who entered results' using errcode = 'HM005';
  end if;
  update public.lab_tests set status = 'approved', approved_by = auth.uid(), approved_at = now() where id = p_test_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'lab_test.approve', 'lab_test', v_row.id::text);
  return v_row;
end;
$$;

create or replace function public.reopen_lab_result(p_test_id uuid, p_reason text)
returns public.lab_tests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.lab_tests;
begin
  select * into v_row from public.lab_tests where id = p_test_id for update;
  if not found then
    raise exception 'reopen_lab_result: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['lab_tech']) then
    raise exception 'reopen_lab_result: lab_tech only' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'reopen_lab_result: reason required' using errcode = '22023';
  end if;
  update public.lab_tests set status = 'in_progress', correction_reason = btrim(p_reason) where id = p_test_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'lab_test.reopen', 'lab_test', v_row.id::text, null, jsonb_build_object('reason', p_reason));
  return v_row;
end;
$$;

create or replace function public.cancel_lab_test(p_test_id uuid, p_reason text)
returns public.lab_tests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.lab_tests;
begin
  select * into v_row from public.lab_tests where id = p_test_id for update;
  if not found then
    raise exception 'cancel_lab_test: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['doctor', 'admin']) then
    raise exception 'cancel_lab_test: doctor/admin only' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'cancel_lab_test: reason required' using errcode = '22023';
  end if;
  update public.lab_tests set status = 'canceled', canceled_at = now(), cancel_reason = btrim(p_reason)
  where id = p_test_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'lab_test.cancel', 'lab_test', v_row.id::text);
  return v_row;
end;
$$;

-- =====================================================================
-- 9. RPC: 수납 (admin/staff, 환불은 admin)
-- =====================================================================
create or replace function public.record_charge(p_appointment_id uuid, p_amount_krw integer)
returns public.visit_charges
language plpgsql
security definer
set search_path = ''
as $$
declare v_a public.appointments; v_row public.visit_charges;
begin
  select * into v_a from public.appointments where id = p_appointment_id;
  if not found then
    raise exception 'record_charge: appointment not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_a.org_id, array['admin', 'staff']) then
    raise exception 'record_charge: admin/staff only' using errcode = '42501';
  end if;
  insert into public.visit_charges (org_id, appointment_id, patient_id, amount_krw, handled_by)
  values (v_a.org_id, v_a.id, v_a.patient_id, p_amount_krw, auth.uid())
  on conflict (org_id, appointment_id) do nothing
  returning * into v_row;
  if v_row.id is null then
    select * into v_row from public.visit_charges where org_id = v_a.org_id and appointment_id = v_a.id;
  end if;
  return v_row;
end;
$$;

create or replace function public.settle_charge(p_charge_id uuid, p_method text)
returns public.visit_charges
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.visit_charges;
begin
  select * into v_row from public.visit_charges where id = p_charge_id for update;
  if not found then
    raise exception 'settle_charge: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['admin', 'staff']) then
    raise exception 'settle_charge: admin/staff only' using errcode = '42501';
  end if;
  update public.visit_charges set status = 'paid', method = p_method, paid_at = now(), handled_by = auth.uid()
  where id = p_charge_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'charge.settle', 'visit_charge', v_row.id::text, null, jsonb_build_object('amount_krw', v_row.amount_krw));
  return v_row;
end;
$$;

create or replace function public.refund_charge(p_charge_id uuid, p_reason text)
returns public.visit_charges
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.visit_charges;
begin
  select * into v_row from public.visit_charges where id = p_charge_id for update;
  if not found then
    raise exception 'refund_charge: not found' using errcode = 'P0002';
  end if;
  if not public.has_role(v_row.org_id, array['admin']) then
    raise exception 'refund_charge: admin only' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 2 then
    raise exception 'refund_charge: reason required' using errcode = '22023';
  end if;
  update public.visit_charges set status = 'refunded', refunded_at = now(), refund_reason = btrim(p_reason)
  where id = p_charge_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'charge.refund', 'visit_charge', v_row.id::text, null, jsonb_build_object('reason', p_reason));
  return v_row;
end;
$$;

-- =====================================================================
-- 10. RPC: 대시보드 (admin). 오늘/어제 = KST 자정 경계, 취소와 노쇼를 구분(리뷰 Hospital #5, #9, #11)
-- =====================================================================
create or replace function public.dashboard_metrics(p_org_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today timestamptz := (date_trunc('day', now() at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul';
  v_tomorrow timestamptz;
  v_yesterday timestamptz;
  v_month timestamptz := (date_trunc('month', now() at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul';
begin
  if not public.is_service_caller() and not public.has_role(p_org_id, array['admin']) then
    raise exception 'dashboard_metrics: admin only' using errcode = '42501';
  end if;
  v_tomorrow := v_today + interval '1 day';
  v_yesterday := v_today - interval '1 day';
  return jsonb_build_object(
    'kst_day_start', v_today,
    'appointments_today', (select count(*) from public.appointments a where a.org_id = p_org_id and a.scheduled_at >= v_today and a.scheduled_at < v_tomorrow),
    'appointments_yesterday', (select count(*) from public.appointments a where a.org_id = p_org_id and a.scheduled_at >= v_yesterday and a.scheduled_at < v_today),
    'visited_today', (select count(*) from public.appointments a where a.org_id = p_org_id and a.checked_in_at >= v_today and a.checked_in_at < v_tomorrow),
    'completed_today', (select count(*) from public.appointments a where a.org_id = p_org_id and a.completed_at >= v_today and a.completed_at < v_tomorrow),
    'canceled_today', (select count(*) from public.appointments a where a.org_id = p_org_id and a.status = 'canceled' and a.scheduled_at >= v_today and a.scheduled_at < v_tomorrow),
    'no_show_today', (select count(*) from public.appointments a where a.org_id = p_org_id and a.status = 'no_show' and a.scheduled_at >= v_today and a.scheduled_at < v_tomorrow),
    'new_patients_today', (select count(*) from public.patients p where p.org_id = p_org_id and p.created_at >= v_today and p.created_at < v_tomorrow),
    'active_patients', (select count(*) from public.patients p where p.org_id = p_org_id and p.deleted_at is null),
    'revenue_today_krw', (select coalesce(sum(c.amount_krw), 0) from public.visit_charges c where c.org_id = p_org_id and c.status = 'paid' and c.paid_at >= v_today and c.paid_at < v_tomorrow),
    'revenue_yesterday_krw', (select coalesce(sum(c.amount_krw), 0) from public.visit_charges c where c.org_id = p_org_id and c.status = 'paid' and c.paid_at >= v_yesterday and c.paid_at < v_today),
    'revenue_month_krw', (select coalesce(sum(c.amount_krw), 0) from public.visit_charges c where c.org_id = p_org_id and c.status = 'paid' and c.paid_at >= v_month),
    'by_specialty', coalesce((select jsonb_object_agg(coalesce(s.specialty, '미지정'), x.n) from (
        select a.doctor_id, count(*) n from public.appointments a
        where a.org_id = p_org_id and a.scheduled_at >= v_month and a.status <> 'canceled' group by a.doctor_id) x
        join public.staff_profiles s on s.org_id = p_org_id and s.user_id = x.doctor_id), '{}'::jsonb)
  );
end;
$$;

-- =====================================================================
-- 11. 보존과 파기 (service_role 전용)
-- =====================================================================
-- 접속기록 파기: 워크스페이스별 보존 기간(하한 730일)이 지난 행만.
create or replace function public.purge_phi_access_log()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if not public.is_privileged_session() then
    raise exception 'purge_phi_access_log: service_role only' using errcode = '42501';
  end if;
  perform set_config('hms.allow_purge', 'on', true);
  delete from public.phi_access_log l
  using public.workspaces w
  where w.org_id = l.org_id and l.created_at < now() - make_interval(days => greatest(w.phi_log_retention_days, 730));
  get diagnostics v_count = row_count;
  perform set_config('hms.allow_purge', 'off', true);
  return v_count;
end;
$$;

-- 파기 검토 대상: 마지막 진료(또는 등록)로부터 p_years(기본 10년, 진료기록부 보존 기준 제안)가 지난 보관 환자.
-- 실제 삭제는 하지 않는다. 운영자 검토와 승인 뒤 서버 스크립트가 처리한다(01_PRD 6.2절).
create or replace function public.retention_candidates(p_org_id uuid, p_years integer default 10)
returns table (patient_id uuid, chart_no text, last_activity_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_privileged_session() then
    raise exception 'retention_candidates: service_role only' using errcode = '42501';
  end if;
  if coalesce(p_years, 0) < 10 then
    raise exception 'retention_candidates: minimum 10 years' using errcode = '22023';
  end if;
  return query
    select p.id, p.chart_no, coalesce(greatest(p.last_visit_at,
             (select max(r.created_at) from public.medical_records r where r.patient_id = p.id)), p.created_at)
    from public.patients p
    where p.org_id = p_org_id
      and coalesce(greatest(p.last_visit_at, (select max(r.created_at) from public.medical_records r where r.patient_id = p.id)), p.created_at)
          < now() - make_interval(years => p_years);
end;
$$;

-- =====================================================================
-- 12. EXECUTE 정리
-- =====================================================================
do $$
declare s text;
begin
  -- 내부/서버 전용
  foreach s in array array[
    'public.log_phi(uuid,text,uuid,text,text,text,integer)', 'public.check_purpose(text)', 'public.hms_append_only()',
    'public.register_workspace(uuid,text)', 'public.purge_phi_access_log()', 'public.retention_candidates(uuid,integer)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', s);
    execute format('grant execute on function %s to service_role', s);
  end loop;
  -- 사용자 RPC와 정책 헬퍼
  foreach s in array array[
    'public.has_access(uuid)', 'public.has_role(uuid,text[])', 'public.my_role(uuid)',
    'public.invite_staff(uuid,uuid,text,text,text)', 'public.accept_staff_invite(uuid)',
    'public.set_staff_role(uuid,uuid,text)', 'public.set_staff_status(uuid,uuid,text)', 'public.set_my_availability(uuid,boolean)',
    'public.register_patient(uuid,text,text,text,date,text,text,integer,text,text,text[],boolean)',
    'public.update_patient(uuid,text,text,date,text,text,integer,text,text,text[])',
    'public.get_patient_detail(uuid,text)', 'public.search_patients(uuid,text)', 'public.log_phi_access(uuid,text,uuid,integer)',
    'public.archive_patient(uuid,text)',
    'public.create_appointment(uuid,uuid,uuid,timestamptz,smallint,text,text)', 'public.transition_appointment(uuid,text,text)',
    'public.reschedule_appointment(uuid,timestamptz)',
    'public.add_medical_record(uuid,uuid,text,text,integer,uuid)', 'public.get_patient_chart(uuid,text)',
    'public.request_lab_test(uuid,uuid,text)', 'public.list_lab_worklist(uuid,text[])', 'public.start_lab_test(uuid)',
    'public.save_lab_result(uuid,jsonb,text)', 'public.approve_lab_result(uuid)', 'public.reopen_lab_result(uuid,text)',
    'public.cancel_lab_test(uuid,text)',
    'public.record_charge(uuid,integer)', 'public.settle_charge(uuid,text)', 'public.refund_charge(uuid,text)',
    'public.dashboard_metrics(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', s);
    execute format('grant execute on function %s to authenticated, service_role', s);
  end loop;
end $$;

-- =====================================================================
-- 13. Realtime: 대기열(appointments), 직원 가용 상태. RLS 하에서 전달된다. 채널 hms:<org>:queue
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['appointments', 'staff_profiles'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- =====================================================================
-- 14. PUBLIC EXECUTE 회수: 트리거 함수 등 위에서 명시하지 않은 함수까지 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 지운다.
--     (0001 SECTION 10 은 그 시점의 코어 함수에만 적용됐다.) 명시 GRANT 는 유지된다.
-- =====================================================================
revoke execute on all functions in schema public from public;
grant execute on all functions in schema public to service_role;
