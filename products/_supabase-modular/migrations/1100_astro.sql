-- =====================================================================
-- 1100_astro.sql
-- astro-ai(신비로운AI) 도메인. 선행: core 0000~0006 (+ seed.sql 의 core.apps 'astro' 행은 없어도 된다)
-- 기획 문서: docs/products/astro-ai/05_DATA_MODEL.md
--
-- 테이블
--   astro.themes          PDF 테마(Taste) 레지스트리. 공개 읽기, 쓰기는 service_role
--   astro.subjects        프로필 보관함(본인/가족/지인). 이름·생년월일시는 앱 계층 AES-256-GCM 암호문만
--   astro.readings        리딩(사주/타로/통합) 1건 = 크레딧 차감 1건 = 잡 1건. 상태 전이 트리거
--   astro.reading_renders PDF 렌더 이력(최초 렌더 + 테마 변경 재생성 5cr). 상태 전이 트리거
--   astro.deliveries      발송 outbox(이메일). 재시도 5분 x 3회
--   astro.consents        동의 기록(개인정보, 제3자 생년월일시, 국외 이전, 마케팅). 증빙용
--   astro.preferences     조직별 기본 테마, 이메일 발송 on/off. 멤버가 직접 쓰는 유일한 테이블
--
-- 보안 원칙 (SECURITY_BASELINE.md)
--   - 모든 테이블 RLS ON. SELECT 는 core.is_org_member + core.has_entitlement(org,'astro').
--   - preferences 를 뺀 전 테이블은 사용자 쓰기 정책 없음 + core.guard_privileged_write 이중 잠금.
--   - subjects 의 암호문 컬럼은 authenticated 에 컬럼 GRANT 를 주지 않는다(복호화는 서버만).
--   - 사용자용 DEFINER RPC(cancel_reading)는 is_service_caller + has_org_role 로 판정한다.
--   - 크레딧은 이 파일에서 직접 차감하지 않는다. Route Handler/워커가 service_role 로 core RPC 를 호출한다.
-- 사용자 정의 SQLSTATE: AS001 상태 전이 위반, AS002 취소 불가 상태, AS003 발송 상태 불일치
-- 반복 실행해도 안전하다.
-- =====================================================================

create schema if not exists astro;
comment on schema astro is '신비로운AI: 사주/타로 리딩, 프로필 보관함, PDF 렌더, 발송';
grant usage on schema astro to anon, authenticated, service_role;
alter default privileges in schema astro grant all on tables to service_role;
alter default privileges in schema astro grant all on sequences to service_role;
alter default privileges in schema astro grant execute on functions to service_role;
alter default privileges in schema astro revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy) values ('astro', '신비로운AI', 'astro', 'open')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 1. themes: PDF 테마(ThemeConfig). MVP 2종. 마켓 업로드 테마는 Phase 3 이후(이 표에 사용자 쓰기 경로 없음)
-- ---------------------------------------------------------------------
create table if not exists astro.themes (
  key          text primary key constraint themes_key_check check (key ~ '^[a-z][a-z0-9-]{1,40}$'),
  name         text not null,
  config       jsonb not null,
  tier         text not null default 'basic' constraint themes_tier_check check (tier in ('basic', 'premium')),
  is_active    boolean not null default true,
  sort_order   integer not null default 0,
  preview_path text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint themes_config_check check (jsonb_typeof(config) = 'object')
);
drop trigger if exists themes_set_updated_at on astro.themes;
create trigger themes_set_updated_at before update on astro.themes
  for each row execute function core.set_updated_at();
drop trigger if exists themes_guard_write on astro.themes;
create trigger themes_guard_write before insert or update or delete on astro.themes
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 2. subjects: 프로필 보관함
--   name_ciphertext  : 실명(AES-256-GCM, base64). 사용자에게 보이지 않는다
--   birth_ciphertext : {"date":"YYYY-MM-DD","time":"HH:MM"|null} 원문 입력(양/음력 그대로)
--   alias            : 화면 표시용 호칭(예: 엄마). 실명 입력을 권하지 않는다
--   본인(self)이 아니면 제3자 동의 시각이 필수다
-- ---------------------------------------------------------------------
create table if not exists astro.subjects (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  alias                  text not null constraint subjects_alias_check check (char_length(alias) between 1 and 20),
  relation               text not null
                         constraint subjects_relation_check check (relation in ('self', 'family', 'partner', 'friend', 'other')),
  gender                 text not null constraint subjects_gender_check check (gender in ('male', 'female')),
  calendar_type          text not null default 'solar'
                         constraint subjects_calendar_type_check check (calendar_type in ('solar', 'lunar')),
  is_leap_month          boolean not null default false,
  birth_time_unknown     boolean not null default false,
  zi_hour_mode           text not null default 'unified'
                         constraint subjects_zi_hour_mode_check check (zi_hour_mode in ('unified', 'split')),
  birth_place_label      text constraint subjects_birth_place_label_check check (char_length(birth_place_label) <= 40),
  birth_longitude        numeric(7,4) constraint subjects_birth_longitude_check check (birth_longitude between -180 and 180),
  name_ciphertext        text not null,
  birth_ciphertext       text not null,
  key_version            smallint not null constraint subjects_key_version_check check (key_version > 0),
  third_party_consent_at timestamptz,
  consent_version        text,
  created_by             uuid,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint subjects_leap_check check (not is_leap_month or calendar_type = 'lunar'),
  constraint subjects_consent_check check (relation = 'self' or (third_party_consent_at is not null and consent_version is not null)),
  constraint subjects_id_org_uniq unique (id, org_id)
);
create unique index if not exists subjects_one_self_per_org_idx on astro.subjects (org_id) where relation = 'self';
create index if not exists subjects_org_created_idx on astro.subjects (org_id, created_at desc);

drop trigger if exists subjects_set_updated_at on astro.subjects;
create trigger subjects_set_updated_at before update on astro.subjects
  for each row execute function core.set_updated_at();
drop trigger if exists subjects_guard_write on astro.subjects;
create trigger subjects_guard_write before insert or update or delete on astro.subjects
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 3. readings: 리딩 1건. 크레딧 차감(consume:astro:<request_id>)과 잡(job:astro:<request_id>)이 1:1
--   status: queued → generating → rendering → completed / failed / canceled (전이 트리거)
--   chart   : 엔진(packages/saju-engine)이 결정적으로 계산한 원국 스냅샷. LLM 이 만든 수치는 넣지 않는다
--   content : LLM 챕터 JSON(zod 검증본). 이름은 {{호칭}} 토큰으로만 들어 있다
-- ---------------------------------------------------------------------
create table if not exists astro.readings (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  subject_id          uuid,
  kind                text not null constraint readings_kind_check check (kind in ('saju', 'tarot', 'combined')),
  theme_key           text not null references astro.themes(key),
  question_ciphertext text,
  key_version         smallint,
  tarot_cards         jsonb,
  chart               jsonb,
  engine_version      text,
  status              text not null default 'queued'
                      constraint readings_status_check
                      check (status in ('queued', 'generating', 'rendering', 'completed', 'failed', 'canceled')),
  progress            smallint not null default 0 constraint readings_progress_check check (progress between 0 and 100),
  credits_charged     integer not null constraint readings_credits_check check (credits_charged >= 0),
  credit_ledger_id    bigint references core.credit_ledger(id),
  job_id              uuid references core.jobs(id) on delete set null,
  request_id          uuid not null,
  content             jsonb,
  content_chars       integer,
  current_render_id   uuid,
  error_code          text,
  error_message       text,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  started_at          timestamptz,
  completed_at        timestamptz,
  failed_at           timestamptz,
  canceled_at         timestamptz,
  constraint readings_request_uniq unique (request_id),
  constraint readings_id_org_uniq unique (id, org_id),
  constraint readings_subject_fk foreign key (subject_id, org_id)
    references astro.subjects (id, org_id) on delete cascade,
  constraint readings_subject_required_check check (kind = 'tarot' or subject_id is not null),
  constraint readings_tarot_cards_check check (
    (kind = 'saju' and tarot_cards is null)
    or (kind in ('tarot', 'combined') and jsonb_typeof(tarot_cards) = 'array' and jsonb_array_length(tarot_cards) = 3)
  ),
  constraint readings_question_key_check check (question_ciphertext is null or key_version is not null)
);
create index if not exists readings_org_created_idx on astro.readings (org_id, created_at desc);
create index if not exists readings_subject_idx on astro.readings (subject_id) where subject_id is not null;
create index if not exists readings_active_idx on astro.readings (status, created_at) where status in ('queued', 'generating', 'rendering');

-- 상태 전이 강제(service_role 쓰기에도 적용). org_id, kind, 과금 컬럼은 바꿀 수 없다.
create or replace function astro.readings_check_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'queued' then
      raise exception 'readings: initial status must be queued (got %)', new.status using errcode = 'AS001';
    end if;
    return new;
  end if;
  if new.org_id <> old.org_id or new.kind <> old.kind or new.request_id <> old.request_id
     or new.credits_charged <> old.credits_charged
     or new.credit_ledger_id is distinct from old.credit_ledger_id and old.credit_ledger_id is not null then
    raise exception 'readings: immutable column changed' using errcode = 'AS001';
  end if;
  if new.status = old.status then
    return new;
  end if;
  if not (
       (old.status = 'queued'     and new.status in ('generating', 'failed', 'canceled'))
    or (old.status = 'generating' and new.status in ('rendering', 'queued', 'failed'))
    or (old.status = 'rendering'  and new.status in ('completed', 'queued', 'failed'))
  ) then
    raise exception 'readings: invalid transition % -> %', old.status, new.status using errcode = 'AS001';
  end if;
  if new.status = 'generating' and new.started_at is null then new.started_at := now(); end if;
  if new.status = 'completed' then new.completed_at := now(); new.progress := 100; end if;
  if new.status = 'failed'    then new.failed_at := now(); end if;
  if new.status = 'canceled'  then new.canceled_at := now(); end if;
  return new;
end;
$$;

drop trigger if exists readings_check_transition on astro.readings;
create trigger readings_check_transition before insert or update on astro.readings
  for each row execute function astro.readings_check_transition();
drop trigger if exists readings_set_updated_at on astro.readings;
create trigger readings_set_updated_at before update on astro.readings
  for each row execute function core.set_updated_at();
drop trigger if exists readings_guard_write on astro.readings;
create trigger readings_guard_write before insert or update or delete on astro.readings
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 4. reading_renders: PDF 렌더 이력. 최초 렌더(is_initial, 0cr) + 테마 변경 재생성(5cr)
--   status: queued → rendering → succeeded / failed, rendering → queued(재시도)
-- ---------------------------------------------------------------------
create table if not exists astro.reading_renders (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  reading_id       uuid not null,
  theme_key        text not null references astro.themes(key),
  is_initial       boolean not null default false,
  status           text not null default 'queued'
                   constraint reading_renders_status_check check (status in ('queued', 'rendering', 'succeeded', 'failed')),
  pdf_path         text constraint reading_renders_pdf_path_check check (pdf_path is null or pdf_path like (org_id::text || '/astro/pdf/%')),
  pdf_pages        integer,
  pdf_bytes        integer,
  credits_charged  integer not null default 0 constraint reading_renders_credits_check check (credits_charged >= 0),
  credit_ledger_id bigint references core.credit_ledger(id),
  job_id           uuid references core.jobs(id) on delete set null,
  request_id       uuid not null,
  error_code       text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  completed_at     timestamptz,
  constraint reading_renders_request_uniq unique (request_id),
  constraint reading_renders_id_org_uniq unique (id, org_id),
  constraint reading_renders_reading_fk foreign key (reading_id, org_id)
    references astro.readings (id, org_id) on delete cascade
);
create index if not exists reading_renders_reading_idx on astro.reading_renders (reading_id, created_at desc);
create unique index if not exists reading_renders_one_initial_idx on astro.reading_renders (reading_id) where is_initial;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'readings_current_render_fk') then
    alter table astro.readings
      add constraint readings_current_render_fk foreign key (current_render_id)
      references astro.reading_renders (id) on delete set null;
  end if;
end $$;

create or replace function astro.reading_renders_check_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'queued' then
      raise exception 'reading_renders: initial status must be queued' using errcode = 'AS001';
    end if;
    return new;
  end if;
  if new.org_id <> old.org_id or new.reading_id <> old.reading_id or new.credits_charged <> old.credits_charged then
    raise exception 'reading_renders: immutable column changed' using errcode = 'AS001';
  end if;
  if new.status = old.status then
    return new;
  end if;
  if not (
       (old.status = 'queued'    and new.status in ('rendering', 'failed'))
    or (old.status = 'rendering' and new.status in ('succeeded', 'queued', 'failed'))
  ) then
    raise exception 'reading_renders: invalid transition % -> %', old.status, new.status using errcode = 'AS001';
  end if;
  if new.status in ('succeeded', 'failed') then new.completed_at := now(); end if;
  if new.status = 'succeeded' and new.pdf_path is null then
    raise exception 'reading_renders: succeeded requires pdf_path' using errcode = 'AS001';
  end if;
  return new;
end;
$$;

drop trigger if exists reading_renders_check_transition on astro.reading_renders;
create trigger reading_renders_check_transition before insert or update on astro.reading_renders
  for each row execute function astro.reading_renders_check_transition();
drop trigger if exists reading_renders_set_updated_at on astro.reading_renders;
create trigger reading_renders_set_updated_at before update on astro.reading_renders
  for each row execute function core.set_updated_at();
drop trigger if exists reading_renders_guard_write on astro.reading_renders;
create trigger reading_renders_guard_write before insert or update or delete on astro.reading_renders
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 5. deliveries: 발송 outbox. MVP 채널은 email 만(카카오 알림톡은 Phase 2 에서 CHECK 확장)
--   status: pending → sending → sent / pending(재시도, 5분 뒤) / dead(3회 소진), pending → skipped
-- ---------------------------------------------------------------------
create table if not exists astro.deliveries (
  id                   bigint generated always as identity primary key,
  org_id               uuid not null references core.organizations(id) on delete cascade,
  reading_id           uuid not null,
  render_id            uuid not null,
  channel              text not null default 'email' constraint deliveries_channel_check check (channel in ('email')),
  status               text not null default 'pending'
                       constraint deliveries_status_check check (status in ('pending', 'sending', 'sent', 'dead', 'skipped')),
  recipient_masked     text,
  recipient_ciphertext text,
  key_version          smallint,
  attempts             integer not null default 0,
  max_attempts         integer not null default 3 constraint deliveries_max_attempts_check check (max_attempts between 1 and 10),
  next_attempt_at      timestamptz not null default now(),
  locked_by            text,
  provider_message_id  text,
  last_error           text,
  sent_at              timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint deliveries_render_channel_uniq unique (render_id, channel),
  constraint deliveries_reading_fk foreign key (reading_id, org_id)
    references astro.readings (id, org_id) on delete cascade,
  constraint deliveries_render_fk foreign key (render_id, org_id)
    references astro.reading_renders (id, org_id) on delete cascade
);
create index if not exists deliveries_due_idx on astro.deliveries (next_attempt_at) where status = 'pending';
create index if not exists deliveries_org_created_idx on astro.deliveries (org_id, created_at desc);

create or replace function astro.deliveries_check_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status not in ('pending', 'skipped') then
      raise exception 'deliveries: initial status must be pending or skipped' using errcode = 'AS001';
    end if;
    return new;
  end if;
  if new.org_id <> old.org_id or new.render_id <> old.render_id then
    raise exception 'deliveries: immutable column changed' using errcode = 'AS001';
  end if;
  if new.status = old.status then
    return new;
  end if;
  if not (
       (old.status = 'pending' and new.status in ('sending', 'skipped', 'dead'))
    or (old.status = 'sending' and new.status in ('sent', 'pending', 'dead'))
    or (old.status = 'dead'    and new.status = 'pending')
  ) then
    raise exception 'deliveries: invalid transition % -> %', old.status, new.status using errcode = 'AS001';
  end if;
  if new.status = 'sent' then new.sent_at := now(); end if;
  return new;
end;
$$;

drop trigger if exists deliveries_check_transition on astro.deliveries;
create trigger deliveries_check_transition before insert or update on astro.deliveries
  for each row execute function astro.deliveries_check_transition();
drop trigger if exists deliveries_set_updated_at on astro.deliveries;
create trigger deliveries_set_updated_at before update on astro.deliveries
  for each row execute function core.set_updated_at();
drop trigger if exists deliveries_guard_write on astro.deliveries;
create trigger deliveries_guard_write before insert or update or delete on astro.deliveries
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 6. consents: 동의 증빙. 서버만 INSERT. 철회는 granted=false 행을 새로 남긴다(UPDATE 하지 않음)
-- ---------------------------------------------------------------------
create table if not exists astro.consents (
  id          bigint generated always as identity primary key,
  org_id      uuid not null references core.organizations(id) on delete cascade,
  user_id     uuid not null,
  subject_id  uuid references astro.subjects(id) on delete set null,
  kind        text not null constraint consents_kind_check check (kind in (
                'terms_required', 'privacy_required', 'third_party_birth', 'overseas_transfer', 'marketing_email')),
  version     text not null,
  granted     boolean not null,
  ip_hash     text,
  created_at  timestamptz not null default now()
);
create index if not exists consents_org_user_idx on astro.consents (org_id, user_id, kind, created_at desc);

drop trigger if exists consents_guard_write on astro.consents;
create trigger consents_guard_write before insert or update or delete on astro.consents
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 7. preferences: 조직별 설정(권한·과금·상태 컬럼 없음 → 멤버 쓰기 허용, DB_CONVENTIONS 8.1)
-- ---------------------------------------------------------------------
create table if not exists astro.preferences (
  org_id                 uuid primary key references core.organizations(id) on delete cascade,
  default_theme_key      text not null default 'mystical-dark' references astro.themes(key),
  email_delivery_enabled boolean not null default true,
  updated_by             uuid,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
drop trigger if exists preferences_set_updated_at on astro.preferences;
create trigger preferences_set_updated_at before update on astro.preferences
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 8. RLS 정책과 GRANT
-- ---------------------------------------------------------------------
alter table astro.themes          enable row level security;
alter table astro.subjects        enable row level security;
alter table astro.readings        enable row level security;
alter table astro.reading_renders enable row level security;
alter table astro.deliveries      enable row level security;
alter table astro.consents        enable row level security;
alter table astro.preferences     enable row level security;

-- themes: 활성 테마는 누구나 읽는다(가격표/테마 미리보기)
grant select on astro.themes to anon, authenticated;
drop policy if exists themes_select on astro.themes;
create policy themes_select on astro.themes for select to anon, authenticated using (is_active);

-- subjects: 암호문 컬럼을 뺀 컬럼만 GRANT. 쓰기는 서버(암호화가 서버에서만 가능)
revoke all on astro.subjects from anon, authenticated;
grant select (id, org_id, alias, relation, gender, calendar_type, is_leap_month, birth_time_unknown, zi_hour_mode,
              birth_place_label, birth_longitude, third_party_consent_at, consent_version, created_by, created_at, updated_at)
  on astro.subjects to authenticated;
drop policy if exists subjects_select on astro.subjects;
create policy subjects_select on astro.subjects for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));

-- readings: 질문 암호문 컬럼 제외
revoke all on astro.readings from anon, authenticated;
grant select (id, org_id, subject_id, kind, theme_key, tarot_cards, chart, engine_version, status, progress,
              credits_charged, job_id, request_id, content, content_chars, current_render_id, error_code, error_message,
              created_by, created_at, updated_at, started_at, completed_at, failed_at, canceled_at)
  on astro.readings to authenticated;
drop policy if exists readings_select on astro.readings;
create policy readings_select on astro.readings for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));

grant select on astro.reading_renders to authenticated;
drop policy if exists reading_renders_select on astro.reading_renders;
create policy reading_renders_select on astro.reading_renders for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));

-- deliveries: 수신자 암호문 제외
revoke all on astro.deliveries from anon, authenticated;
grant select (id, org_id, reading_id, render_id, channel, status, recipient_masked, attempts, max_attempts,
              next_attempt_at, last_error, sent_at, created_at, updated_at)
  on astro.deliveries to authenticated;
drop policy if exists deliveries_select on astro.deliveries;
create policy deliveries_select on astro.deliveries for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));

grant select on astro.consents to authenticated;
drop policy if exists consents_select on astro.consents;
create policy consents_select on astro.consents for select to authenticated
  using (core.is_org_member(org_id));

grant select, insert, update on astro.preferences to authenticated;
drop policy if exists preferences_select on astro.preferences;
create policy preferences_select on astro.preferences for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));
drop policy if exists preferences_insert on astro.preferences;
create policy preferences_insert on astro.preferences for insert to authenticated
  with check (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));
drop policy if exists preferences_update on astro.preferences;
create policy preferences_update on astro.preferences for update to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'))
  with check (core.is_org_member(org_id) and core.has_entitlement(org_id, 'astro'));
-- DELETE 정책 없음: 조직 삭제 시 cascade 로만 지운다.

-- ---------------------------------------------------------------------
-- 9. 함수
-- ---------------------------------------------------------------------

-- 9.1 cancel_reading (authenticated). queued 상태의 리딩만 취소. core.cancel_job 이 크레딧을 환불한다.
create or replace function astro.cancel_reading(p_reading_id uuid)
returns astro.readings
language plpgsql
security definer
set search_path = ''
as $$
declare v_row astro.readings;
begin
  select * into v_row from astro.readings where id = p_reading_id for update;
  if not found then
    raise exception 'cancel_reading: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'cancel_reading: not a member' using errcode = '42501';
  end if;
  if not core.is_service_caller() and not core.has_entitlement(v_row.org_id, 'astro') then
    raise exception 'cancel_reading: no entitlement' using errcode = '42501';
  end if;
  if v_row.status <> 'queued' then
    raise exception 'cancel_reading: only queued readings can be canceled (status=%)', v_row.status using errcode = 'AS002';
  end if;
  if v_row.job_id is not null then
    perform core.cancel_job(v_row.job_id);          -- 잡 취소 + refund:job:<id> 환불 + job.cancel 감사
  end if;
  update astro.readings set status = 'canceled', error_code = 'canceled_by_user'
   where id = p_reading_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'reading.cancel', 'reading', p_reading_id::text);
  return v_row;
end;
$$;
revoke execute on function astro.cancel_reading(uuid) from public, anon;
grant execute on function astro.cancel_reading(uuid) to authenticated;

-- 9.2 claim_due_deliveries (service_role). 발송기가 due 행을 SKIP LOCKED 로 집는다.
create or replace function astro.claim_due_deliveries(p_worker_id text, p_limit integer default 20)
returns setof astro.deliveries
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'claim_due_deliveries: service_role only' using errcode = '42501';
  end if;
  return query
  update astro.deliveries d
     set status = 'sending', attempts = d.attempts + 1, locked_by = p_worker_id
   where d.id in (
     select x.id from astro.deliveries x
      where x.status = 'pending' and x.next_attempt_at <= now()
      order by x.next_attempt_at
      limit greatest(p_limit, 1)
      for update skip locked)
  returning d.*;
end;
$$;
revoke execute on function astro.claim_due_deliveries(text, integer) from public, anon, authenticated;
grant execute on function astro.claim_due_deliveries(text, integer) to service_role;

-- 9.3 finish_delivery (service_role). 성공 → sent. 실패 → 5분 뒤 재시도, attempts 소진 시 dead.
create or replace function astro.finish_delivery(
  p_delivery_id         bigint,
  p_ok                  boolean,
  p_error               text default null,
  p_provider_message_id text default null,
  p_retry_after_seconds integer default 300
)
returns astro.deliveries
language plpgsql
security definer
set search_path = ''
as $$
declare v_row astro.deliveries;
begin
  if not core.is_privileged_session() then
    raise exception 'finish_delivery: service_role only' using errcode = '42501';
  end if;
  select * into v_row from astro.deliveries where id = p_delivery_id for update;
  if not found then
    raise exception 'finish_delivery: not found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'sending' then
    raise exception 'finish_delivery: delivery is not sending (status=%)', v_row.status using errcode = 'AS003';
  end if;
  if p_ok then
    update astro.deliveries
       set status = 'sent', provider_message_id = p_provider_message_id, last_error = null, locked_by = null
     where id = p_delivery_id returning * into v_row;
  elsif v_row.attempts >= v_row.max_attempts then
    update astro.deliveries
       set status = 'dead', last_error = left(p_error, 1000), locked_by = null
     where id = p_delivery_id returning * into v_row;
  else
    update astro.deliveries
       set status = 'pending', last_error = left(p_error, 1000), locked_by = null,
           next_attempt_at = now() + make_interval(secs => greatest(p_retry_after_seconds, 30))
     where id = p_delivery_id returning * into v_row;
  end if;
  return v_row;
end;
$$;
revoke execute on function astro.finish_delivery(bigint, boolean, text, text, integer) from public, anon, authenticated;
grant execute on function astro.finish_delivery(bigint, boolean, text, text, integer) to service_role;

-- 트리거 함수는 직접 호출 대상이 아니다
revoke execute on function astro.readings_check_transition() from public, anon, authenticated;
revoke execute on function astro.reading_renders_check_transition() from public, anon, authenticated;
revoke execute on function astro.deliveries_check_transition() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 10. Realtime: 진행률은 readings / reading_renders 의 postgres_changes(RLS 적용)로 구독한다. broadcast 채널 금지
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'astro' and tablename = 'readings') then
      alter publication supabase_realtime add table astro.readings;
    end if;
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'astro' and tablename = 'reading_renders') then
      alter publication supabase_realtime add table astro.reading_renders;
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 11. 참조 데이터: MVP 기본 테마 2종(Astro AI/기획안/공통/DESIGN.md:44-51 중 2종, 00_MERGE_ANALYSIS.md:336)
--   팔레트 값은 03_SCREENS_UX.md 디자인 작업(AST-06-021)에서 확정한다. 여기 값은 초안이다.
-- ---------------------------------------------------------------------
insert into astro.themes (key, name, config, tier, is_active, sort_order) values
  ('mystical-dark', '먹과 금박', '{"colors":{"background":"#16161D","primary":"#C9A45C","accent":"#7E8FB3","text":"#EDE7DA","muted":"#9A968C","border":"#2E2D36"},"typography":{"headline":"Noto Serif CJK KR","body":"Noto Sans CJK KR"},"pdf":{"pageSize":"A4","margins":{"top":22,"right":20,"bottom":24,"left":22},"coverStyle":"pillars-grid"}}'::jsonb, 'basic', true, 1),
  ('oracle-gold',   '한지와 주묵', '{"colors":{"background":"#F3EEE3","primary":"#8C2F25","accent":"#2F4A3A","text":"#22201C","muted":"#6F6A60","border":"#D8CFBD"},"typography":{"headline":"Noto Serif CJK KR","body":"Noto Sans CJK KR"},"pdf":{"pageSize":"A4","margins":{"top":22,"right":20,"bottom":24,"left":22},"coverStyle":"seal"}}'::jsonb, 'basic', true, 2)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 12. 함수 권한 최종 정리 (0007_core_function_privileges.sql 과 같은 규칙)
--   PostgreSQL 은 함수 생성 시 PUBLIC 에 EXECUTE 를 준다. 스키마 default privileges 로는 지워지지 않으므로
--   파일 끝에서 PUBLIC 을 회수하고 의도한 권한만 다시 준다.
--   authenticated: cancel_reading 만 / service_role: 전부 / 트리거 함수는 발동 시 EXECUTE 를 검사하지 않는다
-- ---------------------------------------------------------------------
revoke execute on all functions in schema astro from public;
revoke execute on all functions in schema astro from anon, authenticated;
grant execute on all functions in schema astro to service_role;
grant execute on function astro.cancel_reading(uuid) to authenticated;
