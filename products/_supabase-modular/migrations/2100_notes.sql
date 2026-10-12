-- =====================================================================
-- 2100_notes.sql
-- study-note(학습 노트 정리) 도메인. 선행: core 0000~0006, seed.sql
-- 정본 설계: docs/products/study-note/05_DATA_MODEL.md
-- 모놀리스 변환본: docs/products/study-note/supabase/monolith/migrations/0002_study_note_domain.sql
--   (이 파일에서 create schema/apps 등록을 빼고 core. / notes. 를 public. 으로 바꾼 것과 같은 본문)
--
-- 원칙 (SECURITY_BASELINE.md, DB_CONVENTIONS.md)
--   - 사용자(authenticated)가 직접 쓰는 테이블은 entries(원문 입력), user_settings(모델/테마)뿐이다.
--     상태, 결과, 크레딧, 플랜 관련 컬럼은 컬럼 GRANT + guard 트리거 + RPC 로만 바뀐다.
--   - 크레딧 선차감, 잡 생성, 실행 기록은 service_role 전용 함수(start_run, record_step, finish_run)가
--     한 트랜잭션에서 처리한다. 사용자용 RPC 안에서 크레딧을 직접 차감하지 않는다.
--   - authenticated 에 EXECUTE 를 연 DEFINER 함수(request_run_cancel)는 is_service_caller() + 멤버 검사를 쓴다.
--   - 리뷰 높음 #1(키 번들 노출): 어떤 테이블에도 api_key 류 컬럼이 없다. LLM 키는 서버 환경변수에만 둔다.
--   - 리뷰 높음 #3(동시 실행): runs 에 entry 당 활성 실행 1개 부분 유니크 인덱스 + NT002/NT003 로 차단한다.
-- SQLSTATE: NT001 상태 전이 위반, NT002 이미 실행 중, NT003 종료된 실행/단계에 대한 쓰기,
--           NT004 플랜 한도 초과(입력 길이, 모델 등급), NT005 일일 전체 예산 소진, NT006 조직 동시 실행 한도
-- =====================================================================

create schema if not exists notes;
grant usage on schema notes to anon, authenticated, service_role;
alter default privileges in schema notes grant all on tables to service_role;
alter default privileges in schema notes grant all on sequences to service_role;
alter default privileges in schema notes grant execute on functions to service_role;
alter default privileges in schema notes revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy, status)
values ('notes', 'Study Note', 'notes', 'open', 'beta')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 1. model_catalog: 서버가 허용하는 LLM 목록(화이트리스트). 모든 조직 공통, 사용자는 읽기만.
--    리뷰 #14(모델 ID 하드코딩) 대응: 목록을 코드가 아니라 DB 행으로 두어 배포 없이 비활성화한다.
-- ---------------------------------------------------------------------
create table if not exists notes.model_catalog (
  model_id         text primary key,
  display_name     text not null,
  provider         text not null,
  tier             text not null constraint model_catalog_tier_check check (tier in ('lite', 'standard', 'premium')),
  credits_per_call integer not null constraint model_catalog_credits_check check (credits_per_call between 1 and 20),
  is_free          boolean not null default false,
  is_active        boolean not null default true,
  sort_order       integer not null default 100,
  deprecated_at    timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
drop trigger if exists model_catalog_set_updated_at on notes.model_catalog;
create trigger model_catalog_set_updated_at before update on notes.model_catalog
  for each row execute function core.set_updated_at();
drop trigger if exists model_catalog_guard_write on notes.model_catalog;
create trigger model_catalog_guard_write before insert or update or delete on notes.model_catalog
  for each row execute function core.guard_privileged_write();

alter table notes.model_catalog enable row level security;
revoke all on notes.model_catalog from public, anon, authenticated;
grant select on notes.model_catalog to authenticated;
drop policy if exists model_catalog_select on notes.model_catalog;
create policy model_catalog_select on notes.model_catalog for select to authenticated
  using (is_active);

-- ---------------------------------------------------------------------
-- 2. runtime_config, cost_guard: 운영 상한. 사용자는 접근 불가(정책 없음 = 전부 거부).
-- ---------------------------------------------------------------------
create table if not exists notes.runtime_config (
  key        text primary key,
  value_int  integer not null,
  note       text,
  updated_at timestamptz not null default now()
);
drop trigger if exists runtime_config_set_updated_at on notes.runtime_config;
create trigger runtime_config_set_updated_at before update on notes.runtime_config
  for each row execute function core.set_updated_at();
drop trigger if exists runtime_config_guard_write on notes.runtime_config;
create trigger runtime_config_guard_write before insert or update or delete on notes.runtime_config
  for each row execute function core.guard_privileged_write();
alter table notes.runtime_config enable row level security;
revoke all on notes.runtime_config from public, anon, authenticated;

create table if not exists notes.cost_guard (
  day          date primary key,
  used_credits integer not null default 0 constraint cost_guard_used_check check (used_credits >= 0),
  updated_at   timestamptz not null default now()
);
drop trigger if exists cost_guard_set_updated_at on notes.cost_guard;
create trigger cost_guard_set_updated_at before update on notes.cost_guard
  for each row execute function core.set_updated_at();
drop trigger if exists cost_guard_guard_write on notes.cost_guard;
create trigger cost_guard_guard_write before insert or update or delete on notes.cost_guard
  for each row execute function core.guard_privileged_write();
alter table notes.cost_guard enable row level security;
revoke all on notes.cost_guard from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. user_settings: 사용자별 모델 3종과 테마. API Key 컬럼은 없다(리뷰 #1, #7).
-- ---------------------------------------------------------------------
create table if not exists notes.user_settings (
  org_id       uuid not null references core.organizations(id) on delete cascade,
  user_id      uuid not null,
  base_model_1 text references notes.model_catalog(model_id) on update cascade on delete set null,
  base_model_2 text references notes.model_catalog(model_id) on update cascade on delete set null,
  merge_model  text references notes.model_catalog(model_id) on update cascade on delete set null,
  theme        text not null default 'system' constraint user_settings_theme_check check (theme in ('system', 'light', 'dark')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (org_id, user_id)
);
drop trigger if exists user_settings_set_updated_at on notes.user_settings;
create trigger user_settings_set_updated_at before update on notes.user_settings
  for each row execute function core.set_updated_at();

alter table notes.user_settings enable row level security;
revoke all on notes.user_settings from public, anon, authenticated;
grant select on notes.user_settings to authenticated;
grant insert (org_id, user_id, base_model_1, base_model_2, merge_model, theme) on notes.user_settings to authenticated;
grant update (base_model_1, base_model_2, merge_model, theme) on notes.user_settings to authenticated;

drop policy if exists user_settings_select on notes.user_settings;
create policy user_settings_select on notes.user_settings for select to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id) and core.has_entitlement(org_id, 'notes'));
drop policy if exists user_settings_insert on notes.user_settings;
create policy user_settings_insert on notes.user_settings for insert to authenticated
  with check (user_id = auth.uid() and core.has_org_role(org_id, array['owner', 'admin', 'member'])
              and core.has_entitlement(org_id, 'notes'));
drop policy if exists user_settings_update on notes.user_settings;
create policy user_settings_update on notes.user_settings for update to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id))
  with check (user_id = auth.uid() and core.has_org_role(org_id, array['owner', 'admin', 'member']));

-- ---------------------------------------------------------------------
-- 4. entries: 하루치 일지 1건(원문 입력 + 최종본). 원문과 날짜만 사용자가 쓴다.
--    entry_date 는 일지의 달력 날짜(KST 기준으로 클라이언트가 계산, 리뷰 #5)이며 시각이 아니다.
-- ---------------------------------------------------------------------
create table if not exists notes.entries (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  created_by   uuid not null default auth.uid(),
  entry_date   date not null,
  input_text   text not null constraint entries_input_len_check check (char_length(input_text) between 1 and 20000),
  status       text not null default 'draft' constraint entries_status_check check (status in ('draft', 'organizing', 'organized')),
  final_text   text,
  keywords     text[] constraint entries_keywords_check check (keywords is null or cardinality(keywords) = 2),
  last_run_id  uuid,
  organized_at timestamptz,
  deleted_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists entries_org_created_idx on notes.entries (org_id, created_at desc) where deleted_at is null;
create index if not exists entries_org_date_idx on notes.entries (org_id, entry_date desc) where deleted_at is null;
create index if not exists entries_deleted_idx on notes.entries (deleted_at) where deleted_at is not null;

drop trigger if exists entries_set_updated_at on notes.entries;
create trigger entries_set_updated_at before update on notes.entries
  for each row execute function core.set_updated_at();

-- 2차 잠금: 컬럼 GRANT 가 열려도 사용자 세션이 상태/결과 컬럼을 바꾸지 못하게 한다.
create or replace function notes.guard_entry_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if core.is_privileged_session() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.status <> 'draft' or new.final_text is not null or new.keywords is not null
       or new.last_run_id is not null or new.organized_at is not null or new.deleted_at is not null then
      raise exception 'entries: result columns are server-managed' using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' then
    if new.org_id <> old.org_id or new.created_by <> old.created_by
       or new.status is distinct from old.status or new.final_text is distinct from old.final_text
       or new.keywords is distinct from old.keywords or new.last_run_id is distinct from old.last_run_id
       or new.organized_at is distinct from old.organized_at then
      raise exception 'entries: result columns are server-managed' using errcode = '42501';
    end if;
    if old.status = 'organizing' and new.input_text is distinct from old.input_text then
      raise exception 'entries: input_text is locked while organizing' using errcode = 'NT001';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
drop trigger if exists entries_guard_write on notes.entries;
create trigger entries_guard_write before insert or update or delete on notes.entries
  for each row execute function notes.guard_entry_write();

-- 상태 전이: draft -> organizing, organizing -> organized | draft, organized -> organizing (service_role 에도 적용)
create or replace function notes.check_entry_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status = 'draft' and new.status = 'organizing')
         or (old.status = 'organizing' and new.status in ('organized', 'draft'))
         or (old.status = 'organized' and new.status = 'organizing')) then
      raise exception 'entries: invalid transition % -> %', old.status, new.status using errcode = 'NT001';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists entries_status_transition on notes.entries;
create trigger entries_status_transition before update of status on notes.entries
  for each row execute function notes.check_entry_transition();

alter table notes.entries enable row level security;
revoke all on notes.entries from public, anon, authenticated;
grant select on notes.entries to authenticated;
grant insert (org_id, entry_date, input_text) on notes.entries to authenticated;
grant update (entry_date, input_text, deleted_at) on notes.entries to authenticated;
grant delete on notes.entries to authenticated;

drop policy if exists entries_select on notes.entries;
create policy entries_select on notes.entries for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'notes'));   -- soft delete 된 행도 읽힌다(휴지통 30일, 복원 가능). 목록 쿼리가 deleted_at is null 로 거른다
drop policy if exists entries_insert on notes.entries;
create policy entries_insert on notes.entries for insert to authenticated
  with check (created_by = auth.uid() and core.has_org_role(org_id, array['owner', 'admin', 'member'])
              and core.has_entitlement(org_id, 'notes'));
drop policy if exists entries_update on notes.entries;
create policy entries_update on notes.entries for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'notes'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists entries_delete on notes.entries;
create policy entries_delete on notes.entries for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- ---------------------------------------------------------------------
-- 5. runs: 정리 실행 1회(2모델 병렬 + 통합). 사용자는 읽기만.
--    entry 당 활성(queued, running) 실행은 1개: 중복 실행과 중복 과금의 DB 차단(리뷰 #3).
-- ---------------------------------------------------------------------
create table if not exists notes.runs (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  entry_id            uuid not null references notes.entries(id) on delete cascade,
  created_by          uuid,
  request_id          uuid not null,
  idempotency_key     text not null unique,
  parent_run_id       uuid references notes.runs(id) on delete set null,
  retry_roles         text[],
  base_model_1        text not null,
  base_model_2        text not null,
  merge_model         text not null,
  status              text not null default 'queued'
                      constraint runs_status_check check (status in ('queued', 'running', 'succeeded', 'partial', 'failed', 'canceled')),
  credits_charged     integer not null constraint runs_credits_charged_check check (credits_charged >= 0),
  credits_refunded    integer not null default 0 constraint runs_credits_refunded_check check (credits_refunded >= 0),
  credit_ledger_id    bigint references core.credit_ledger(id),
  job_id              uuid references core.jobs(id) on delete set null,
  cancel_requested_at timestamptz,
  error_code          text,
  error_message       text,
  queued_at           timestamptz not null default now(),
  started_at          timestamptz,
  finished_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint runs_refund_le_charge_check check (credits_refunded <= credits_charged)
);
create unique index if not exists runs_one_active_per_entry_uniq on notes.runs (entry_id) where status in ('queued', 'running');
create index if not exists runs_entry_created_idx on notes.runs (entry_id, created_at desc);
create index if not exists runs_org_active_idx on notes.runs (org_id) where status in ('queued', 'running');

alter table notes.entries drop constraint if exists entries_last_run_fk;
alter table notes.entries add constraint entries_last_run_fk foreign key (last_run_id) references notes.runs(id) on delete set null;

drop trigger if exists runs_set_updated_at on notes.runs;
create trigger runs_set_updated_at before update on notes.runs
  for each row execute function core.set_updated_at();
drop trigger if exists runs_guard_write on notes.runs;
create trigger runs_guard_write before insert or update or delete on notes.runs
  for each row execute function core.guard_privileged_write();

-- 상태 전이: queued -> running | canceled | failed, running -> succeeded | partial | failed | canceled. 종료 상태는 불변.
create or replace function notes.check_run_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status = 'queued' and new.status in ('running', 'canceled', 'failed'))
         or (old.status = 'running' and new.status in ('succeeded', 'partial', 'failed', 'canceled'))) then
      raise exception 'runs: invalid transition % -> %', old.status, new.status using errcode = 'NT001';
    end if;
  elsif old.status in ('succeeded', 'partial', 'failed', 'canceled') then
    -- 종료된 실행의 다른 컬럼도 서버 보정(환불 기록 등) 외에는 바꾸지 않는다.
    if new.base_model_1 is distinct from old.base_model_1 or new.base_model_2 is distinct from old.base_model_2
       or new.merge_model is distinct from old.merge_model or new.credits_charged is distinct from old.credits_charged then
      raise exception 'runs: terminal run is immutable' using errcode = 'NT003';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists runs_status_transition on notes.runs;
create trigger runs_status_transition before update on notes.runs
  for each row execute function notes.check_run_transition();

alter table notes.runs enable row level security;
revoke all on notes.runs from public, anon, authenticated;
grant select on notes.runs to authenticated;
drop policy if exists runs_select on notes.runs;
create policy runs_select on notes.runs for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'notes'));

-- ---------------------------------------------------------------------
-- 6. run_steps: 카드 단위 결과(base1, base2, merge). 사용자는 읽기만.
-- ---------------------------------------------------------------------
create table if not exists notes.run_steps (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  run_id            uuid not null references notes.runs(id) on delete cascade,
  role              text not null constraint run_steps_role_check check (role in ('base1', 'base2', 'merge')),
  model_id          text not null,
  status            text not null default 'pending'
                    constraint run_steps_status_check check (status in ('pending', 'running', 'succeeded', 'failed', 'skipped', 'reused', 'canceled')),
  credits           integer not null default 0 constraint run_steps_credits_check check (credits >= 0),
  content           text,
  latency_ms        integer,
  prompt_tokens     integer,
  completion_tokens integer,
  ai_usage_id       bigint references core.ai_usage(id),
  error_code        text,
  error_message     text,
  started_at        timestamptz,
  finished_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (run_id, role)
);
create index if not exists run_steps_org_idx on notes.run_steps (org_id);

drop trigger if exists run_steps_set_updated_at on notes.run_steps;
create trigger run_steps_set_updated_at before update on notes.run_steps
  for each row execute function core.set_updated_at();
drop trigger if exists run_steps_guard_write on notes.run_steps;
create trigger run_steps_guard_write before insert or update or delete on notes.run_steps
  for each row execute function core.guard_privileged_write();

alter table notes.run_steps enable row level security;
revoke all on notes.run_steps from public, anon, authenticated;
grant select on notes.run_steps to authenticated;
drop policy if exists run_steps_select on notes.run_steps;
create policy run_steps_select on notes.run_steps for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'notes'));

-- 진행률 UI: runs, run_steps 변경을 RLS 하에서 구독한다(core.jobs 와 같은 방식)
do $$
declare t text;
begin
  foreach t in array array['runs', 'run_steps'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'notes' and tablename = t) then
      execute format('alter publication supabase_realtime add table notes.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. 내부 헬퍼: 조직의 현재 플랜 features (서버 전용)
-- ---------------------------------------------------------------------
create or replace function notes.org_features(p_org_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.features
    from core.app_entitlements e
    join core.plans p on p.id = e.plan_id
    where e.org_id = p_org_id and e.app_id = 'notes' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  ), '{}'::jsonb);
$$;
revoke execute on function notes.org_features(uuid) from public, anon, authenticated;
grant execute on function notes.org_features(uuid) to service_role;

-- ---------------------------------------------------------------------
-- 8. start_run (service_role 전용): 크레딧 선차감 + 실행/단계 생성 + 잡 enqueue 를 한 트랜잭션으로.
--    어느 단계에서 실패해도 전부 롤백되므로 "과금만 되고 잡이 없는" 상태가 생기지 않는다.
--    p_retry_roles: null 이면 전체 실행. {'base1'} 같은 배열이면 해당 카드만 다시 실행하고
--    나머지 base 단계는 부모 실행의 성공 결과를 복사(reused, 0 크레딧)한 뒤 merge 를 새로 실행한다.
-- ---------------------------------------------------------------------
create or replace function notes.start_run(
  p_org_id        uuid,
  p_user_id       uuid,
  p_entry_id      uuid,
  p_request_id    uuid,
  p_base_model_1  text,
  p_base_model_2  text,
  p_merge_model   text,
  p_parent_run_id uuid   default null,
  p_retry_roles   text[] default null
)
returns notes.runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key        text := 'run:notes:' || p_request_id::text;
  v_run        notes.runs;
  v_entry      notes.entries;
  v_parent     notes.runs;
  v_features   jsonb;
  v_allowed    jsonb;
  v_max_chars  integer;
  v_cap        integer;
  v_org_max    integer;
  v_active     integer;
  v_run_id     uuid := gen_random_uuid();
  v_roles      text[] := array['base1', 'base2', 'merge'];
  v_exec       text[];
  v_role       text;
  v_model      text;
  v_cat        notes.model_catalog;
  v_pstep      notes.run_steps;
  v_credits    integer := 0;
  v_cost       integer;
  v_ledger     bigint;
  v_job        core.jobs;
  v_day        date := (now() at time zone 'Asia/Seoul')::date;
  v_used       integer;
begin
  if not core.is_privileged_session() then
    raise exception 'start_run: service_role only' using errcode = '42501';
  end if;
  if p_retry_roles is not null and (cardinality(p_retry_roles) = 0 or not (p_retry_roles <@ array['base1', 'base2'])) then
    raise exception 'start_run: retry_roles must be a non-empty subset of base1, base2' using errcode = '22023';
  end if;
  if (p_retry_roles is null) <> (p_parent_run_id is null) then
    raise exception 'start_run: retry_roles and parent_run_id must be given together' using errcode = '22023';
  end if;

  -- 멱등: 같은 request_id 는 같은 실행을 돌려준다
  perform pg_advisory_xact_lock(hashtext('notes:run:' || v_key));
  select * into v_run from notes.runs r where r.idempotency_key = v_key;
  if found then
    return v_run;
  end if;

  -- 호출 사용자는 조직의 활성 멤버(owner/admin/member)여야 하고 앱 엔타이틀먼트가 있어야 한다
  if not exists (select 1 from core.org_members m
                 where m.org_id = p_org_id and m.user_id = p_user_id and m.status = 'active'
                   and coalesce(m.role, '') in ('owner', 'admin', 'member')) then
    raise exception 'start_run: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(p_org_id, 'notes') then
    raise exception 'start_run: no entitlement' using errcode = '42501';
  end if;

  select * into v_entry from notes.entries e
  where e.id = p_entry_id and e.org_id = p_org_id and e.deleted_at is null for update;
  if not found then
    raise exception 'start_run: entry not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from notes.runs r where r.entry_id = p_entry_id and r.status in ('queued', 'running')) then
    raise exception 'start_run: a run is already active for this entry' using errcode = 'NT002';
  end if;

  v_features := notes.org_features(p_org_id);
  v_max_chars := coalesce((v_features ->> 'max_input_chars')::integer, 5000);
  v_allowed := coalesce(v_features -> 'allowed_tiers', '["lite", "standard"]'::jsonb);
  if char_length(v_entry.input_text) > v_max_chars then
    raise exception 'start_run: input exceeds plan limit (% > %)', char_length(v_entry.input_text), v_max_chars using errcode = 'NT004';
  end if;

  select c.value_int into v_org_max from notes.runtime_config c where c.key = 'max_active_runs_per_org';
  select count(*) into v_active from notes.runs r where r.org_id = p_org_id and r.status in ('queued', 'running');
  if v_active >= coalesce(v_org_max, 2) then
    raise exception 'start_run: too many active runs for this organization' using errcode = 'NT006';
  end if;

  if p_parent_run_id is not null then
    select * into v_parent from notes.runs r
    where r.id = p_parent_run_id and r.org_id = p_org_id and r.entry_id = p_entry_id
      and r.status in ('succeeded', 'partial', 'failed', 'canceled');
    if not found then
      raise exception 'start_run: parent run not found or not finished' using errcode = 'P0002';
    end if;
  end if;

  -- 실행할 단계 결정과 비용 계산(단계별 모델은 화이트리스트에서 검증)
  v_exec := case when p_retry_roles is null then v_roles else p_retry_roles || array['merge'] end;
  for v_role in select unnest(v_exec) loop
    v_model := case v_role when 'base1' then p_base_model_1 when 'base2' then p_base_model_2 else p_merge_model end;
    select * into v_cat from notes.model_catalog c where c.model_id = v_model and c.is_active;
    if not found then
      raise exception 'start_run: model % is not available', v_model using errcode = '22023';
    end if;
    if not (v_allowed ? v_cat.tier) then
      raise exception 'start_run: model tier % is not allowed by the plan', v_cat.tier using errcode = 'NT004';
    end if;
    v_credits := v_credits + v_cat.credits_per_call;
  end loop;

  -- 일일 전체 예산(공개 베타 비용 상한)
  select c.value_int into v_cap from notes.runtime_config c where c.key = 'daily_credit_cap';
  insert into notes.cost_guard (day, used_credits) values (v_day, v_credits)
  on conflict (day) do update set used_credits = notes.cost_guard.used_credits + excluded.used_credits
  returning used_credits into v_used;
  if v_cap is not null and v_used > v_cap then
    raise exception 'start_run: daily budget exhausted' using errcode = 'NT005';
  end if;

  -- 선차감(원자, 멱등). 부족하면 CR001 로 전체 롤백
  select c.ledger_id into v_ledger
  from core.consume_credits(p_org_id, v_credits, 'notes', 'notes.organize', 'notes_run', v_run_id::text,
                            'consume:notes:' || p_request_id::text,
                            jsonb_build_object('entry_id', p_entry_id, 'retry_roles', p_retry_roles), p_user_id) c;

  insert into notes.runs (id, org_id, entry_id, created_by, request_id, idempotency_key, parent_run_id, retry_roles,
                          base_model_1, base_model_2, merge_model, credits_charged, credit_ledger_id)
  values (v_run_id, p_org_id, p_entry_id, p_user_id, p_request_id, v_key, p_parent_run_id, p_retry_roles,
          p_base_model_1, p_base_model_2, p_merge_model, v_credits, v_ledger)
  returning * into v_run;

  foreach v_role in array v_roles loop
    if v_role = any (v_exec) then
      v_model := case v_role when 'base1' then p_base_model_1 when 'base2' then p_base_model_2 else p_merge_model end;
      select c.credits_per_call into v_cost from notes.model_catalog c where c.model_id = v_model;
      insert into notes.run_steps (org_id, run_id, role, model_id, credits) values (p_org_id, v_run_id, v_role, v_model, v_cost);
    else
      select * into v_pstep from notes.run_steps s
      where s.run_id = p_parent_run_id and s.role = v_role and s.status in ('succeeded', 'reused') and s.content is not null;
      if not found then
        raise exception 'start_run: role % has no reusable result; include it in retry_roles', v_role using errcode = '22023';
      end if;
      insert into notes.run_steps (org_id, run_id, role, model_id, status, credits, content, latency_ms, prompt_tokens, completion_tokens, finished_at)
      values (p_org_id, v_run_id, v_role, v_pstep.model_id, 'reused', 0, v_pstep.content, v_pstep.latency_ms,
              v_pstep.prompt_tokens, v_pstep.completion_tokens, now());
      -- 재사용 단계의 모델은 부모 실행의 모델로 기록한다
      if v_role = 'base1' then update notes.runs set base_model_1 = v_pstep.model_id where id = v_run_id;
      else update notes.runs set base_model_2 = v_pstep.model_id where id = v_run_id; end if;
    end if;
  end loop;

  select * into v_job from core.enqueue_job(
    p_org_id, 'notes', 'notes.organize', 'notes.organize',
    jsonb_build_object('run_id', v_run_id, 'entry_id', p_entry_id, 'exec_roles', to_jsonb(v_exec)),
    100, now(), 1, v_ledger, 'job:notes:' || p_request_id::text, null, p_user_id, true);

  update notes.runs set job_id = v_job.id where id = v_run_id returning * into v_run;
  update notes.entries set status = 'organizing', last_run_id = v_run_id where id = p_entry_id;
  return v_run;
end;
$$;

-- ---------------------------------------------------------------------
-- 9. record_step (service_role 전용): 워커가 카드 진행/결과를 기록. 종료된 실행에는 쓸 수 없다(NT003).
--    늦게 도착한 이전 응답이 새 결과를 덮어쓰는 경로를 DB 에서 닫는다(리뷰 #3).
-- ---------------------------------------------------------------------
create or replace function notes.record_step(
  p_run_id            uuid,
  p_role              text,
  p_status            text,
  p_content           text    default null,
  p_latency_ms        integer default null,
  p_prompt_tokens     integer default null,
  p_completion_tokens integer default null,
  p_ai_usage_id       bigint  default null,
  p_error_code        text    default null,
  p_error_message     text    default null,
  p_model_id          text    default null   -- 폴백으로 실제 호출된 모델(같은 등급 안). null 이면 기록된 모델 유지
)
returns notes.run_steps
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run  notes.runs;
  v_step notes.run_steps;
begin
  if not core.is_privileged_session() then
    raise exception 'record_step: service_role only' using errcode = '42501';
  end if;
  if p_status not in ('running', 'succeeded', 'failed', 'skipped', 'canceled') then
    raise exception 'record_step: invalid status %', p_status using errcode = '22023';
  end if;
  if p_status = 'succeeded' and coalesce(p_content, '') = '' then
    raise exception 'record_step: succeeded step needs content' using errcode = '22023';
  end if;

  select * into v_run from notes.runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'record_step: run not found' using errcode = 'P0002';
  end if;
  if v_run.status not in ('queued', 'running') then
    raise exception 'record_step: run % is already %', p_run_id, v_run.status using errcode = 'NT003';
  end if;

  select * into v_step from notes.run_steps s where s.run_id = p_run_id and s.role = p_role for update;
  if not found then
    raise exception 'record_step: step not found' using errcode = 'P0002';
  end if;
  if v_step.status = p_status then
    return v_step;
  end if;
  if not ((v_step.status = 'pending' and p_status in ('running', 'skipped', 'canceled', 'failed'))
       or (v_step.status = 'running' and p_status in ('succeeded', 'failed', 'canceled'))) then
    raise exception 'record_step: step % cannot go % -> %', p_role, v_step.status, p_status using errcode = 'NT003';
  end if;

  if v_run.status = 'queued' then
    update notes.runs set status = 'running', started_at = now() where id = p_run_id;
  end if;

  update notes.run_steps
  set status = p_status,
      model_id = coalesce(p_model_id, model_id),
      content = case when p_status = 'succeeded' then p_content else content end,
      latency_ms = coalesce(p_latency_ms, latency_ms),
      prompt_tokens = coalesce(p_prompt_tokens, prompt_tokens),
      completion_tokens = coalesce(p_completion_tokens, completion_tokens),
      ai_usage_id = coalesce(p_ai_usage_id, ai_usage_id),
      error_code = p_error_code,
      error_message = left(p_error_message, 500),
      started_at = case when p_status = 'running' then now() else started_at end,
      finished_at = case when p_status = 'running' then null else now() end
  where id = v_step.id
  returning * into v_step;
  return v_step;
end;
$$;

-- ---------------------------------------------------------------------
-- 10. finish_run (service_role 전용): 실행 종료 확정 + 미성공 단계 크레딧 환불 + entries 갱신.
--     status 계산: 통합 성공=succeeded / 이번에 실행한 단계 중 하나라도 성공=partial / 전부 실패=failed / 취소 요청=canceled
--     환불 멱등 키: failed 는 fail_job 자동 환불과 같은 키('refund:job:<job_id>')를 써서 이중 환불(CR003)을 막는다.
-- ---------------------------------------------------------------------
create or replace function notes.finish_run(
  p_run_id     uuid,
  p_final_text text   default null,
  p_keywords   text[] default null
)
returns notes.runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run     notes.runs;
  v_status  text;
  v_exec_ok integer;
  v_merge   boolean;
  v_refund  integer;
  v_key     text;
  v_err     text;
begin
  if not core.is_privileged_session() then
    raise exception 'finish_run: service_role only' using errcode = '42501';
  end if;
  select * into v_run from notes.runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'finish_run: run not found' using errcode = 'P0002';
  end if;
  if v_run.status not in ('queued', 'running') then
    raise exception 'finish_run: run % is already %', p_run_id, v_run.status using errcode = 'NT003';
  end if;

  select count(*) filter (where s.status = 'succeeded'),
         coalesce(bool_or(s.role = 'merge' and s.status = 'succeeded'), false)
  into v_exec_ok, v_merge
  from notes.run_steps s where s.run_id = p_run_id;

  v_status := case
    when v_merge and coalesce(p_final_text, '') <> '' then 'succeeded'
    when v_run.cancel_requested_at is not null and v_exec_ok = 0 then 'canceled'
    when v_exec_ok > 0 then 'partial'
    else 'failed'
  end;
  if v_status = 'succeeded' and (p_keywords is null or cardinality(p_keywords) <> 2) then
    raise exception 'finish_run: succeeded run needs exactly 2 keywords' using errcode = '22023';
  end if;

  -- 아직 끝나지 않은 단계 정리
  update notes.run_steps
  set status = case when status = 'running' then 'failed' when v_status = 'canceled' then 'canceled' else 'skipped' end,
      error_code = case when status = 'running' then 'aborted' else error_code end,
      finished_at = now()
  where run_id = p_run_id and status in ('pending', 'running');

  select coalesce(sum(s.credits), 0) into v_refund
  from notes.run_steps s where s.run_id = p_run_id and s.status in ('failed', 'skipped', 'canceled');

  if v_status = 'failed' then
    v_err := coalesce((select s.error_code from notes.run_steps s where s.run_id = p_run_id and s.error_code is not null
                       order by s.finished_at desc nulls last limit 1), 'all_steps_failed');
  end if;

  if v_run.status = 'queued' then
    update notes.runs set status = 'running', started_at = coalesce(started_at, now()) where id = p_run_id;
  end if;

  if v_refund > 0 and v_run.credit_ledger_id is not null then
    v_key := case when v_status = 'failed' and v_run.job_id is not null
                  then 'refund:job:' || v_run.job_id::text else 'refund:run:' || p_run_id::text end;
    perform core.refund_credits(v_run.credit_ledger_id, 'notes_run_' || v_status, v_refund, v_key, null);
  end if;

  update notes.runs
  set status = v_status, finished_at = now(), credits_refunded = v_refund,
      error_code = v_err, error_message = case when v_status = 'failed' then 'all executed steps failed' end
  where id = p_run_id
  returning * into v_run;

  if v_status = 'succeeded' then
    update notes.entries
    set status = 'organized', final_text = p_final_text, keywords = p_keywords, organized_at = now(), last_run_id = p_run_id
    where id = v_run.entry_id;
  else
    update notes.entries
    set status = case when final_text is not null then 'organized' else 'draft' end, last_run_id = p_run_id
    where id = v_run.entry_id and status = 'organizing';
  end if;

  perform notes.enforce_retention(v_run.org_id);
  return v_run;
end;
$$;

-- ---------------------------------------------------------------------
-- 11. request_run_cancel (authenticated): 사용자가 자기 조직의 실행 취소를 요청.
--     queued 는 core.cancel_job 으로 즉시 취소(환불 포함), running 은 취소 요청 플래그만 남기고 워커가 단계 경계에서 중단한다.
-- ---------------------------------------------------------------------
create or replace function notes.request_run_cancel(p_run_id uuid)
returns notes.runs
language plpgsql
security definer
set search_path = ''
as $$
declare v_run notes.runs;
begin
  select * into v_run from notes.runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'request_run_cancel: run not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_run.org_id, array['owner', 'admin', 'member']) then
    raise exception 'request_run_cancel: not a member' using errcode = '42501';
  end if;
  if v_run.status = 'queued' then
    if v_run.job_id is not null then
      perform core.cancel_job(v_run.job_id);
    end if;
    update notes.run_steps set status = 'canceled', finished_at = now() where run_id = p_run_id and status = 'pending';
    update notes.runs set status = 'canceled', finished_at = now(), cancel_requested_at = now(),
           credits_refunded = credits_charged
    where id = p_run_id returning * into v_run;
    update notes.entries
    set status = case when final_text is not null then 'organized' else 'draft' end
    where id = v_run.entry_id and status = 'organizing';
  elsif v_run.status = 'running' then
    update notes.runs set cancel_requested_at = coalesce(cancel_requested_at, now())
    where id = p_run_id returning * into v_run;
  else
    raise exception 'request_run_cancel: run is already %', v_run.status using errcode = 'NT003';
  end if;
  perform core.write_audit(v_run.org_id, 'notes_run.cancel', 'notes_run', p_run_id::text);
  return v_run;
end;
$$;

-- ---------------------------------------------------------------------
-- 12. 보존/정리 (service_role 전용, 스케줄 또는 finish_run 에서 호출)
--     enforce_retention: 플랜 features 의 history_max_entries(기본 50), history_max_bytes(기본 5,000,000)를 넘는
--                        오래된 일지를 soft delete. 최신 1건과 정리 중(organizing)인 일지는 건드리지 않는다.
--     purge_deleted: soft delete 후 유예기간(기본 30일)이 지난 일지 영구 삭제 + 오래된 cost_guard 행 정리.
-- ---------------------------------------------------------------------
create or replace function notes.enforce_retention(p_org_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_features jsonb;
  v_max_n    integer;
  v_max_b    bigint;
  v_n        integer;
begin
  if not core.is_privileged_session() then
    raise exception 'enforce_retention: service_role only' using errcode = '42501';
  end if;
  v_features := notes.org_features(p_org_id);
  v_max_n := coalesce((v_features ->> 'history_max_entries')::integer, 50);
  v_max_b := coalesce((v_features ->> 'history_max_bytes')::bigint, 5000000);

  with step_bytes as (
    select r.entry_id, coalesce(sum(octet_length(s.content)), 0) as b
    from notes.runs r join notes.run_steps s on s.run_id = r.id
    where r.org_id = p_org_id group by r.entry_id
  ), sized as (
    select e.id, e.status,
           row_number() over w as rn,
           sum(octet_length(e.input_text) + coalesce(octet_length(e.final_text), 0) + coalesce(sb.b, 0)) over (w rows between unbounded preceding and current row) as cum
    from notes.entries e left join step_bytes sb on sb.entry_id = e.id
    where e.org_id = p_org_id and e.deleted_at is null
    window w as (order by e.created_at desc, e.id desc)
  )
  update notes.entries t set deleted_at = now()
  from sized z
  where t.id = z.id and z.rn > 1 and z.status <> 'organizing' and (z.rn > v_max_n or z.cum > v_max_b);
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

create or replace function notes.purge_deleted(p_grace interval default interval '30 days')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_n integer;
begin
  if not core.is_privileged_session() then
    raise exception 'purge_deleted: service_role only' using errcode = '42501';
  end if;
  delete from notes.entries e where e.deleted_at is not null and e.deleted_at < now() - p_grace;
  get diagnostics v_n = row_count;
  delete from notes.cost_guard g where g.day < (now() at time zone 'Asia/Seoul')::date - 60;
  return v_n;
end;
$$;

-- 함수 권한: PUBLIC 회수, service_role 전용과 authenticated 허용 목록 분리
revoke execute on function notes.start_run(uuid, uuid, uuid, uuid, text, text, text, uuid, text[]) from public, anon, authenticated;
revoke execute on function notes.record_step(uuid, text, text, text, integer, integer, integer, bigint, text, text, text) from public, anon, authenticated;
revoke execute on function notes.finish_run(uuid, text, text[]) from public, anon, authenticated;
revoke execute on function notes.enforce_retention(uuid) from public, anon, authenticated;
revoke execute on function notes.purge_deleted(interval) from public, anon, authenticated;
revoke execute on function notes.request_run_cancel(uuid) from public, anon;
-- 트리거 함수는 직접 호출 대상이 아니다(트리거 발화에는 EXECUTE 가 필요 없다)
revoke execute on function notes.guard_entry_write() from public, anon, authenticated;
revoke execute on function notes.check_entry_transition() from public, anon, authenticated;
revoke execute on function notes.check_run_transition() from public, anon, authenticated;
grant execute on function notes.start_run(uuid, uuid, uuid, uuid, text, text, text, uuid, text[]) to service_role;
grant execute on function notes.record_step(uuid, text, text, text, integer, integer, integer, bigint, text, text, text) to service_role;
grant execute on function notes.finish_run(uuid, text, text[]) to service_role;
grant execute on function notes.enforce_retention(uuid) to service_role;
grant execute on function notes.purge_deleted(interval) to service_role;
grant execute on function notes.request_run_cancel(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 13. 제품 seed (설정 데이터). 모두 upsert 이므로 반복 실행 가능.
--     모델 ID 와 등급, 크레딧은 제안값이다(원본 constants.ts 13개 모델 + 등급 분류는 05_DATA_MODEL 2.1절 근거).
-- ---------------------------------------------------------------------
insert into notes.model_catalog (model_id, display_name, provider, tier, credits_per_call, is_free, sort_order) values
  ('deepseek/deepseek-v4-flash',           'DeepSeek V4 Flash',     'DeepSeek', 'lite',     1, false, 10),
  ('qwen/qwen3.5-flash-02-23',             'Qwen 3.5 Flash',        'Qwen',     'lite',     1, false, 11),
  ('google/gemini-3-flash-preview',        'Gemini 3 Flash',        'Google',   'lite',     1, false, 12),
  ('openai/gpt-5-mini',                    'GPT-5 Mini',            'OpenAI',   'lite',     1, false, 13),
  ('tencent/hy3-preview',                  'Tencent Hy3',           'Tencent',  'lite',     1, false, 14),
  ('openai/gpt-oss-120b:free',             'GPT-OSS 120B (Free)',   'OpenAI',   'lite',     1, true,  20),
  ('z-ai/glm-4.5-air:free',                'GLM 4.5 Air (Free)',    'Z-AI',     'lite',     1, true,  21),
  ('arcee-ai/trinity-large-thinking:free', 'Trinity Large (Free)',  'Arcee',    'lite',     1, true,  22),
  ('anthropic/claude-sonnet-4.6',          'Claude Sonnet 4.6',     'Anthropic','standard', 2, false, 30),
  ('moonshotai/kimi-k2.6',                 'Kimi K2.6',             'Moonshot', 'standard', 2, false, 31),
  ('qwen/qwen3.6-plus',                    'Qwen 3.6 Plus',         'Qwen',     'standard', 2, false, 32),
  ('anthropic/claude-opus-4.7',            'Claude Opus 4.7',       'Anthropic','premium',  4, false, 40),
  ('openai/gpt-5.5',                       'GPT-5.5',               'OpenAI',   'premium',  4, false, 41)
on conflict (model_id) do update
  set display_name = excluded.display_name, provider = excluded.provider, tier = excluded.tier,
      credits_per_call = excluded.credits_per_call, is_free = excluded.is_free, sort_order = excluded.sort_order;

insert into notes.runtime_config (key, value_int, note) values
  ('daily_credit_cap',         5000, '제안: 공개 베타 일일 전체 크레딧 소비 상한. 베타 실측 후 조정'),
  ('max_active_runs_per_org',  2,    '제안: 조직당 동시 활성 실행 수')
on conflict (key) do nothing;

-- 플랜 features 해석은 01_PRD 4장 표 참조. free 플랜은 seed.sql 에서 features = {} 로 만들어지므로 여기서 채운다.
update core.plans
set features = '{"max_input_chars": 5000, "allowed_tiers": ["lite", "standard"], "history_max_entries": 50, "history_max_bytes": 5000000}'::jsonb
where app_id = 'notes' and code = 'free' and features = '{}'::jsonb;

-- Phase 2 유료 플랜과 크레딧팩: 베타 동안은 비활성(is_active = false). 금액과 크레딧은 제안값이다(01_PRD 4장).
insert into core.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('notes', 'pro', 'Pro', 4900, 'month', 300, 0, false,
   '{"max_input_chars": 10000, "allowed_tiers": ["lite", "standard", "premium"], "history_max_entries": 500, "history_max_bytes": 50000000}', false, false, 1)
on conflict (app_id, code) do nothing;

insert into core.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('notes', 'pack_100', '100 크레딧', 100, 2900, false, 1),
  ('notes', 'pack_300', '300 크레딧', 300, 7900, false, 2)
on conflict (app_id, code) do nothing;
