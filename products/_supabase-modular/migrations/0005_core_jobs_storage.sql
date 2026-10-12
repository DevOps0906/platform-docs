-- =====================================================================
-- 0005_core_jobs_storage.sql
-- 범용 잡 테이블(SKIP LOCKED 클레임), 실패 시 자동 환불, Realtime 발행,
-- Storage 버킷과 "폴더 = org_id" 정책 템플릿.
--
-- 워커 규약
--   TS/Python 워커 공통: claim_jobs → (heartbeat_job)* → complete_job | fail_job
--   fail_job은 attempts < max_attempts 이면 지수 백오프로 재큐잉하고, 마지막 실패에서
--   credit_ledger_id가 있으면 core.refund_credits()로 자동 환불한다.
--   BullMQ(FlowProducer)를 쓰는 영상 파이프라인도 상태의 정본은 이 테이블에 미러링한다.
-- 선행: 0000 ~ 0004
-- =====================================================================

create table if not exists core.jobs (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  app_id            text not null references core.apps(id),
  queue             text not null default 'default',
  job_type          text not null,
  payload           jsonb not null default '{}'::jsonb,
  result            jsonb,
  status            text not null default 'queued'
                    constraint jobs_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  priority          integer not null default 100,
  attempts          integer not null default 0,
  max_attempts      integer not null default 3,
  run_after         timestamptz not null default now(),
  locked_at         timestamptz,
  locked_by         text,
  heartbeat_at      timestamptz,
  progress          integer not null default 0 constraint jobs_progress_check check (progress between 0 and 100),
  progress_message  text,
  last_error        text,
  credit_ledger_id  bigint references core.credit_ledger(id),
  refund_on_failure boolean not null default true,
  idempotency_key   text unique,
  parent_job_id     uuid references core.jobs(id) on delete set null,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  started_at        timestamptz,
  finished_at       timestamptz,
  updated_at        timestamptz not null default now()
);
create index if not exists jobs_claim_idx on core.jobs (queue, priority, run_after, created_at) where status = 'queued';
create index if not exists jobs_org_created_idx on core.jobs (org_id, created_at desc);
create index if not exists jobs_running_heartbeat_idx on core.jobs (heartbeat_at) where status = 'running';
create index if not exists jobs_parent_idx on core.jobs (parent_job_id) where parent_job_id is not null;

drop trigger if exists jobs_set_updated_at on core.jobs;
create trigger jobs_set_updated_at before update on core.jobs for each row execute function core.set_updated_at();
drop trigger if exists jobs_guard_write on core.jobs;
create trigger jobs_guard_write before insert or update or delete on core.jobs
  for each row execute function core.guard_privileged_write();

alter table core.jobs enable row level security;
grant select on core.jobs to authenticated;
drop policy if exists jobs_select on core.jobs;
create policy jobs_select on core.jobs for select to authenticated using (core.is_org_member(org_id));

-- ---------------------------------------------------------------------
-- enqueue_job (service_role). 멱등 키가 같으면 기존 잡을 돌려준다.
-- ---------------------------------------------------------------------
create or replace function core.enqueue_job(
  p_org_id            uuid,
  p_app_id            text,
  p_queue             text,
  p_job_type          text,
  p_payload           jsonb       default '{}'::jsonb,
  p_priority          integer     default 100,
  p_run_after         timestamptz default now(),
  p_max_attempts      integer     default 3,
  p_credit_ledger_id  bigint      default null,
  p_idempotency_key   text        default null,
  p_parent_job_id     uuid        default null,
  p_created_by        uuid        default null,
  p_refund_on_failure boolean     default true
)
returns core.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.jobs;
begin
  if not core.is_privileged_session() then
    raise exception 'enqueue_job: service_role only' using errcode = '42501';
  end if;
  if p_idempotency_key is not null then
    perform pg_advisory_xact_lock(hashtext('job:' || p_idempotency_key));
    select * into v_row from core.jobs j where j.idempotency_key = p_idempotency_key;
    if found then
      return v_row;
    end if;
  end if;
  insert into core.jobs (org_id, app_id, queue, job_type, payload, priority, run_after, max_attempts,
                         credit_ledger_id, idempotency_key, parent_job_id, created_by, refund_on_failure)
  values (p_org_id, p_app_id, coalesce(p_queue, 'default'), p_job_type, coalesce(p_payload, '{}'::jsonb), p_priority,
          coalesce(p_run_after, now()), greatest(p_max_attempts, 1), p_credit_ledger_id, p_idempotency_key,
          p_parent_job_id, p_created_by, p_refund_on_failure)
  returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- claim_jobs (service_role): FOR UPDATE SKIP LOCKED. 여러 워커가 같은 큐를 안전하게 나눠 가진다.
-- ---------------------------------------------------------------------
create or replace function core.claim_jobs(
  p_queue     text,
  p_worker_id text,
  p_limit     integer default 1,
  p_job_types text[]  default null
)
returns setof core.jobs
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'claim_jobs: service_role only' using errcode = '42501';
  end if;
  return query
  with picked as (
    select j.id
    from core.jobs j
    where j.queue = p_queue
      and j.status = 'queued'
      and j.run_after <= now()
      and (p_job_types is null or j.job_type = any (p_job_types))
    order by j.priority asc, j.run_after asc, j.created_at asc
    limit greatest(p_limit, 1)
    for update skip locked
  )
  update core.jobs j
  set status       = 'running',
      locked_at    = now(),
      locked_by    = p_worker_id,
      heartbeat_at = now(),
      started_at   = coalesce(j.started_at, now()),
      attempts     = j.attempts + 1
  from picked
  where j.id = picked.id
  returning j.*;
end;
$$;

create or replace function core.heartbeat_job(p_job_id uuid, p_worker_id text, p_progress integer default null, p_message text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_ok boolean;
begin
  if not core.is_privileged_session() then
    raise exception 'heartbeat_job: service_role only' using errcode = '42501';
  end if;
  update core.jobs
  set heartbeat_at     = now(),
      progress         = coalesce(p_progress, progress),
      progress_message = coalesce(p_message, progress_message)
  where id = p_job_id and status = 'running' and locked_by = p_worker_id;
  v_ok := found;
  return v_ok;
end;
$$;

create or replace function core.complete_job(p_job_id uuid, p_worker_id text, p_result jsonb default '{}'::jsonb)
returns core.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.jobs;
begin
  if not core.is_privileged_session() then
    raise exception 'complete_job: service_role only' using errcode = '42501';
  end if;
  update core.jobs
  set status = 'succeeded', result = coalesce(p_result, '{}'::jsonb), progress = 100,
      finished_at = now(), locked_at = null, locked_by = null
  where id = p_job_id and status = 'running' and locked_by = p_worker_id
  returning * into v_row;
  if not found then
    raise exception 'complete_job: job % is not running under worker %', p_job_id, p_worker_id using errcode = 'JB001';
  end if;
  return v_row;
end;
$$;

-- 실패 처리. 재시도 가능하고 attempts < max_attempts 이면 지수 백오프로 재큐잉, 아니면 최종 실패 + 자동 환불.
create or replace function core.fail_job(
  p_job_id              uuid,
  p_worker_id           text,
  p_error               text,
  p_retryable           boolean default true,
  p_retry_delay_seconds integer default 60
)
returns core.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.jobs; v_delay interval;
begin
  if not core.is_privileged_session() then
    raise exception 'fail_job: service_role only' using errcode = '42501';
  end if;
  select * into v_row from core.jobs where id = p_job_id for update;
  if not found or v_row.status <> 'running' or v_row.locked_by is distinct from p_worker_id then
    raise exception 'fail_job: job % is not running under worker %', p_job_id, p_worker_id using errcode = 'JB001';
  end if;

  if p_retryable and v_row.attempts < v_row.max_attempts then
    v_delay := make_interval(secs => p_retry_delay_seconds * power(2, greatest(v_row.attempts - 1, 0)));
    update core.jobs
    set status = 'queued', run_after = now() + v_delay, last_error = left(p_error, 4000),
        locked_at = null, locked_by = null, heartbeat_at = null
    where id = p_job_id
    returning * into v_row;
    return v_row;
  end if;

  update core.jobs
  set status = 'failed', last_error = left(p_error, 4000), finished_at = now(),
      locked_at = null, locked_by = null
  where id = p_job_id
  returning * into v_row;

  if v_row.refund_on_failure and v_row.credit_ledger_id is not null then
    perform core.refund_credits(v_row.credit_ledger_id, 'job_failed:' || v_row.job_type, null,
                                'refund:job:' || v_row.id::text, null);
  end if;
  return v_row;
end;
$$;

-- 사용자가 대기 중인 자기 조직 잡을 취소(환불 포함). running 잡은 워커가 취소 플래그를 확인해야 하므로 여기서는 queued만.
create or replace function core.cancel_job(p_job_id uuid)
returns core.jobs
language plpgsql
security definer
set search_path = ''
as $$
declare v_row core.jobs;
begin
  select * into v_row from core.jobs where id = p_job_id for update;
  if not found then
    raise exception 'cancel_job: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.is_org_member(v_row.org_id) then
    raise exception 'cancel_job: not a member' using errcode = '42501';
  end if;
  if v_row.status <> 'queued' then
    raise exception 'cancel_job: only queued jobs can be canceled (status=%)', v_row.status using errcode = 'JB002';
  end if;
  update core.jobs set status = 'canceled', finished_at = now() where id = p_job_id returning * into v_row;
  if v_row.refund_on_failure and v_row.credit_ledger_id is not null then
    perform core.refund_credits(v_row.credit_ledger_id, 'job_canceled:' || v_row.job_type, null,
                                'refund:job:' || v_row.id::text, auth.uid());
  end if;
  perform core.write_audit(v_row.org_id, 'job.cancel', 'job', v_row.id::text);
  return v_row;
end;
$$;
grant execute on function core.cancel_job(uuid) to authenticated;

-- 하트비트가 끊긴 running 잡을 실패 처리(스케줄러가 호출)
create or replace function core.reap_stale_jobs(p_stale_seconds integer default 600)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare r record; v_count integer := 0;
begin
  if not core.is_privileged_session() then
    raise exception 'reap_stale_jobs: service_role only' using errcode = '42501';
  end if;
  for r in
    select j.id, j.locked_by from core.jobs j
    where j.status = 'running' and coalesce(j.heartbeat_at, j.locked_at) < now() - make_interval(secs => p_stale_seconds)
    for update skip locked
  loop
    perform core.fail_job(r.id, r.locked_by, 'stale heartbeat', true, 60);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Realtime: 진행률 UI는 core.jobs 변경을 RLS 하에서 구독한다(broadcast 채널 대신).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'core' and tablename = 'jobs'
  ) then
    alter publication supabase_realtime add table core.jobs;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Storage
--   경로 규칙: <org_id>/<app_id>/<entity>/<uuid>.<ext>  (첫 폴더가 org_id)
--   버킷: org-files(비공개, 50MB), exports(비공개, 200MB, 서명 URL 7일), public-assets(공개 읽기, 10MB 이미지)
-- ---------------------------------------------------------------------
create or replace function core.storage_org_id(p_name text)
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
grant execute on function core.storage_org_id(text) to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('org-files',     'org-files',     false, 52428800,  null),
  ('exports',       'exports',       false, 209715200, null),
  ('public-assets', 'public-assets', true,  10485760,  array['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml'])
on conflict (id) do nothing;

-- org-files: 멤버 읽기/쓰기, 삭제는 owner/admin 또는 업로더 본인
drop policy if exists org_files_select on storage.objects;
create policy org_files_select on storage.objects for select to authenticated
  using (bucket_id = 'org-files' and core.is_org_member(core.storage_org_id(name)));
drop policy if exists org_files_insert on storage.objects;
create policy org_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'org-files' and core.is_org_member(core.storage_org_id(name)));
drop policy if exists org_files_update on storage.objects;
create policy org_files_update on storage.objects for update to authenticated
  using (bucket_id = 'org-files' and core.is_org_member(core.storage_org_id(name)))
  with check (bucket_id = 'org-files' and core.is_org_member(core.storage_org_id(name)));
drop policy if exists org_files_delete on storage.objects;
create policy org_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'org-files' and (owner = auth.uid() or core.has_org_role(core.storage_org_id(name), array['owner', 'admin'])));

-- exports: 서버(service_role)만 쓰고, 멤버는 읽기(서명 URL 발급용)
drop policy if exists exports_select on storage.objects;
create policy exports_select on storage.objects for select to authenticated
  using (bucket_id = 'exports' and core.is_org_member(core.storage_org_id(name)));

-- public-assets: 누구나 읽기, 멤버는 자기 조직 폴더에만 쓰기
drop policy if exists public_assets_select on storage.objects;
create policy public_assets_select on storage.objects for select to anon, authenticated
  using (bucket_id = 'public-assets');
drop policy if exists public_assets_insert on storage.objects;
create policy public_assets_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'public-assets' and core.is_org_member(core.storage_org_id(name)));
drop policy if exists public_assets_update on storage.objects;
create policy public_assets_update on storage.objects for update to authenticated
  using (bucket_id = 'public-assets' and core.is_org_member(core.storage_org_id(name)))
  with check (bucket_id = 'public-assets' and core.is_org_member(core.storage_org_id(name)));
drop policy if exists public_assets_delete on storage.objects;
create policy public_assets_delete on storage.objects for delete to authenticated
  using (bucket_id = 'public-assets' and core.has_org_role(core.storage_org_id(name), array['owner', 'admin']));
