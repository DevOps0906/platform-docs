-- =====================================================================
-- 0002_toon_domain.sql  (모놀리스: 단독 Supabase 프로젝트, 스키마 public)
-- toon-factory 도메인. 선행: 0001_core_lite.sql
-- 정본은 모듈러 조각 docs/products/_supabase-modular/migrations/2000_toon.sql 이다.
-- 이 파일은 DB_CONVENTIONS.md 12장 변환 규칙으로 만든다:
--   (a) create schema 블록 제거  (b) core. → public.  (c) toon.<tbl> → public.<tbl>
--   (d) 모든 도메인 테이블/뷰에 revoke all ... from public, anon, authenticated 후 필요한 GRANT 만
-- 변환은 06_AGENT_PLAN.md 의 TN-06-003(조각 → 모놀리스 변환 스크립트) 작업이 자동화한다. 손으로 고치지 않는다.
-- 스키마 public 은 사용자 최종 확인 대기(05_DATA_MODEL.md 8절).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values ('toon', 'Toon Factory', 'public', 'open', 'beta')
on conflict (id) do nothing;

-- =====================================================================
-- 1. 헬퍼 함수
-- =====================================================================

-- 현재 사용자가 toon 엔타이틀먼트가 있는 조직의 활성 멤버인가(카탈로그 읽기 정책용)
create or replace function public.has_toon_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.org_members m
    join public.app_entitlements e on e.org_id = m.org_id
    where m.user_id = auth.uid() and m.status = 'active'
      and e.app_id = 'toon' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  );
$$;
grant execute on function public.has_toon_access() to authenticated;

-- 조직의 toon 플랜 features. 서버 게이팅과 한도 트리거가 쓴다. 멤버 또는 service 만.
create or replace function public.plan_features(p_org_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_features jsonb;
begin
  if not public.is_service_caller() and not public.is_org_member(p_org_id) then
    raise exception 'plan_features: not a member' using errcode = '42501';
  end if;
  select p.features into v_features
  from public.app_entitlements e
  join public.plans p on p.id = e.plan_id
  where e.org_id = p_org_id and e.app_id = 'toon' and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now());
  return coalesce(v_features, '{}'::jsonb);
end;
$$;
grant execute on function public.plan_features(uuid) to authenticated;

-- features 의 정수 키. 키가 없거나 숫자가 아니면 기본값(무료 플랜 값). -1 은 무제한.
create or replace function public.feature_int(p_features jsonb, p_key text, p_default integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_features -> p_key) = 'number' then (p_features ->> p_key)::integer else p_default end;
$$;
grant execute on function public.feature_int(jsonb, text, integer) to authenticated;

-- =====================================================================
-- 2. 카탈로그 (플랫폼 소유. 쓰기는 service_role, 읽기는 toon 사용자)
-- =====================================================================

create table if not exists public.asset_packs (
  id                     uuid primary key default gen_random_uuid(),
  code                   text not null unique constraint asset_packs_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name                   text not null,
  description            text,
  style_preset           text not null default 'flat_line'
                         constraint asset_packs_style_preset_check check (style_preset ~ '^[a-z][a-z0-9_]{1,40}$'),
  tier                   text not null default 'free' constraint asset_packs_tier_check check (tier in ('free', 'premium')),
  license_source         text not null
                         constraint asset_packs_license_source_check check (license_source in ('in_house', 'commissioned', 'licensed_commercial')),
  license_ref            text not null constraint asset_packs_license_ref_check check (char_length(license_ref) between 3 and 200),
  commercial_use_allowed boolean not null default true,
  license_verified_at    timestamptz,
  license_verified_by    uuid,
  status                 text not null default 'draft' constraint asset_packs_status_check check (status in ('draft', 'published', 'retired')),
  sort_order             integer not null default 0,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  -- 리뷰 #6: 라이선스 검증 없이 공개할 수 없다
  constraint asset_packs_publish_license_check
    check (status <> 'published' or (license_verified_at is not null and license_verified_by is not null))
);

create table if not exists public.characters (
  id          uuid primary key default gen_random_uuid(),
  pack_id     uuid not null references public.asset_packs(id) on delete restrict,
  code        text not null constraint characters_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name        text not null,
  description text,
  status      text not null default 'draft' constraint characters_status_check check (status in ('draft', 'published', 'retired')),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (pack_id, code)
);

create table if not exists public.assets (
  id           uuid primary key default gen_random_uuid(),
  pack_id      uuid not null references public.asset_packs(id) on delete restrict,
  character_id uuid references public.characters(id) on delete restrict,
  kind         text not null
               constraint assets_kind_check check (kind in ('pose', 'expression', 'background', 'prop', 'bubble', 'effect_text', 'bgm')),
  code         text not null constraint assets_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name         text not null,
  tier         text not null default 'free' constraint assets_tier_check check (tier in ('free', 'premium')),
  storage_path text not null,            -- 버킷 toon-catalog: 원본(렌더 워커만)
  editor_path  text,                     -- 버킷 toon-catalog: 편집용 1024px(서명 URL, 등급 검사 후)
  preview_path text not null,            -- 버킷 toon-previews: 256px 썸네일(공개)
  mime         text not null constraint assets_mime_check check (mime in ('image/png', 'image/webp', 'image/svg+xml', 'audio/mpeg')),
  width        integer constraint assets_width_check check (width is null or width between 1 and 8192),
  height       integer constraint assets_height_check check (height is null or height between 1 and 8192),
  duration_ms  integer constraint assets_duration_check check (duration_ms is null or duration_ms between 1 and 600000),
  anchors      jsonb not null default '{}'::jsonb,   -- pose: {"head":{"x":0.5,"y":0.18,"r":0,"s":1}} (정규화 좌표)
  tags         text[] not null default '{}',
  status       text not null default 'draft' constraint assets_status_check check (status in ('draft', 'published', 'retired')),
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint assets_character_kind_check check ((kind in ('pose', 'expression')) = (character_id is not null)),
  constraint assets_bgm_mime_check check ((kind = 'bgm') = (mime = 'audio/mpeg')),
  constraint assets_identity_uniq unique nulls not distinct (pack_id, character_id, kind, code)
);
create index if not exists assets_pack_kind_idx on public.assets (pack_id, kind, sort_order);
create index if not exists assets_character_kind_idx on public.assets (character_id, kind) where character_id is not null;

-- 사용자용 카탈로그 뷰: 원본/편집 경로를 뺀 컬럼만. security_invoker 라 아래 RLS 를 그대로 통과한다.
create or replace view public.catalog_assets with (security_invoker = true) as
  select a.id, a.pack_id, a.character_id, a.kind, a.code, a.name, a.tier, a.preview_path, a.mime,
         a.width, a.height, a.duration_ms, a.anchors, a.tags, a.sort_order
  from public.assets a
  where a.status = 'published';

-- =====================================================================
-- 3. 작품 (조직 소유 콘텐츠. 멤버 쓰기 허용 + 플랜 한도 트리거)
-- =====================================================================

create table if not exists public.series (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  title         text not null constraint series_title_check check (char_length(title) between 1 and 80),
  format        text not null constraint series_format_check check (format in ('instatoon', 'webtoon')),
  canvas_width  integer not null constraint series_canvas_width_check check (canvas_width between 320 and 2048),
  canvas_height integer not null constraint series_canvas_height_check check (canvas_height between 320 and 4096),
  genre         text constraint series_genre_check check (genre is null or char_length(genre) <= 40),
  synopsis      text constraint series_synopsis_check check (synopsis is null or char_length(synopsis) <= 2000),
  style_pack_id uuid references public.asset_packs(id) on delete set null,
  status        text not null default 'active' constraint series_status_check check (status in ('active', 'archived')),
  metadata      jsonb not null default '{}'::jsonb,
  created_by    uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint series_id_org_uniq unique (id, org_id)
);
create index if not exists series_org_updated_idx on public.series (org_id, updated_at desc);

create table if not exists public.series_characters (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations(id) on delete cascade,
  series_id    uuid not null,
  character_id uuid not null references public.characters(id) on delete restrict,
  display_name text not null constraint series_characters_name_check check (char_length(display_name) between 1 and 40),
  role_note    text constraint series_characters_role_note_check check (role_note is null or char_length(role_note) <= 300),
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint series_characters_series_fk foreign key (series_id, org_id) references public.series (id, org_id) on delete cascade,
  unique (series_id, character_id)
);

create table if not exists public.episodes (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations(id) on delete cascade,
  series_id  uuid not null,
  number     integer not null constraint episodes_number_check check (number between 1 and 9999),
  title      text not null default '' constraint episodes_title_check check (char_length(title) <= 80),
  logline    text constraint episodes_logline_check check (logline is null or char_length(logline) <= 500),
  script     jsonb not null default '{}'::jsonb,       -- AI 콘티 결과 또는 사용자 작성 콘티(04_API.md 4절 스키마)
  status     text not null default 'draft'
             constraint episodes_status_check check (status in ('draft', 'storyboarded', 'editing', 'done')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint episodes_series_fk foreign key (series_id, org_id) references public.series (id, org_id) on delete cascade,
  constraint episodes_id_org_uniq unique (id, org_id),
  constraint episodes_series_number_uniq unique (series_id, number),
  constraint episodes_script_size_check check (pg_column_size(script) <= 131072)
);

create table if not exists public.cuts (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  episode_id     uuid not null,
  position       integer not null constraint cuts_position_check check (position between 0 and 999),
  width          integer not null constraint cuts_width_check check (width between 320 and 2048),
  height         integer not null constraint cuts_height_check check (height between 320 and 4096),
  -- 자체 문서 스키마(Fabric toObject 아님). {"v":1,"background":{...},"layers":[판별 유니온]} 02/05장 참조
  doc            jsonb not null default '{"v": 1, "layers": []}'::jsonb,
  duration_ms    integer not null default 2500 constraint cuts_duration_check check (duration_ms between 500 and 10000),
  revision       integer not null default 1,
  thumbnail_path text,
  created_by     uuid default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint cuts_episode_fk foreign key (episode_id, org_id) references public.episodes (id, org_id) on delete cascade,
  constraint cuts_episode_position_uniq unique (episode_id, position) deferrable initially deferred,
  constraint cuts_doc_shape_check check (
    jsonb_typeof(doc) = 'object'
    and coalesce(jsonb_typeof(doc -> 'v'), '') = 'number'
    and case when jsonb_typeof(doc -> 'layers') = 'array' then jsonb_array_length(doc -> 'layers') <= 60 else false end
  ),
  constraint cuts_doc_size_check check (pg_column_size(doc) <= 262144)
);

-- =====================================================================
-- 4. 서버 기록 (쓰기는 service_role 만)
-- =====================================================================

create table if not exists public.generations (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations(id) on delete cascade,
  series_id        uuid references public.series(id) on delete set null,
  kind             text not null constraint generations_kind_check check (kind in ('background', 'prop')),
  prompt           text not null constraint generations_prompt_check check (char_length(prompt) between 1 and 1000),
  prompt_en        text,
  negative_prompt  text,
  style_preset     text,
  model            text not null,
  seed             bigint,
  width            integer not null constraint generations_width_check check (width between 256 and 2048),
  height           integer not null constraint generations_height_check check (height between 256 and 2048),
  num_images       integer not null default 1 constraint generations_num_images_check check (num_images between 1 and 4),
  status           text not null default 'queued'
                   constraint generations_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  job_id           uuid references public.jobs(id) on delete set null,
  credit_ledger_id bigint references public.credit_ledger(id),
  credits          integer not null default 0 constraint generations_credits_check check (credits >= 0),
  fal_request_id   text unique,
  request_id       uuid not null unique,
  error            text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  finished_at      timestamptz
);
create index if not exists generations_org_created_idx on public.generations (org_id, created_at desc);
create index if not exists generations_job_idx on public.generations (job_id) where job_id is not null;

create table if not exists public.user_assets (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  generation_id uuid references public.generations(id) on delete set null,
  kind          text not null constraint user_assets_kind_check check (kind in ('background', 'prop')),
  source        text not null constraint user_assets_source_check check (source in ('ai_generated', 'upload')),
  ai_generated  boolean not null,
  model         text,
  storage_path  text not null,   -- 버킷 toon-user-assets: <org_id>/toon/user_assets/<uuid>.png (서버만 씀)
  preview_path  text not null,
  width         integer not null,
  height        integer not null,
  bytes         bigint not null default 0,
  label         text constraint user_assets_label_check check (label is null or char_length(label) <= 80),
  created_by    uuid,
  created_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  -- AI 생성 표시 무결성: 출처와 플래그가 어긋날 수 없다
  constraint user_assets_ai_source_check check ((source = 'ai_generated') = ai_generated),
  constraint user_assets_ai_model_check check (not ai_generated or model is not null)
);
create index if not exists user_assets_org_created_idx on public.user_assets (org_id, created_at desc) where deleted_at is null;

create table if not exists public.exports (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations(id) on delete cascade,
  episode_id       uuid references public.episodes(id) on delete set null,
  kind             text not null constraint exports_kind_check check (kind in ('png', 'zip', 'webtoon_strip', 'mp4')),
  status           text not null default 'queued'
                   constraint exports_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  plan_code        text not null,                 -- 요청 시점 플랜(서버가 기록)
  watermark        boolean not null,              -- 서버가 플랜 features.watermark 로 결정. 클라이언트 입력 아님
  ai_label         boolean not null default false,-- 렌더 시 AI 생성 레이어가 하나라도 있으면 true
  ai_label_visible boolean not null default true, -- 가시 표기 여부. false 는 사용자가 "게시글에 직접 표기" 확인한 경우만(감사 기록)
  options          jsonb not null default '{}'::jsonb,
  job_id           uuid references public.jobs(id) on delete set null,
  credit_ledger_id bigint references public.credit_ledger(id),
  credits          integer not null default 0 constraint exports_credits_check check (credits >= 0),
  request_id       uuid not null unique,
  output_paths     text[] not null default '{}',  -- 버킷 exports: <org_id>/toon/exports/<export_id>/...
  bytes            bigint,
  duration_ms      integer,
  error            text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  started_at       timestamptz,
  finished_at      timestamptz,
  expires_at       timestamptz,
  constraint exports_ai_label_visible_check check (ai_label_visible or ai_label)
);
create index if not exists exports_org_created_idx on public.exports (org_id, created_at desc);
create index if not exists exports_org_month_idx on public.exports (org_id, kind, created_at) where status in ('queued', 'running', 'succeeded');
create index if not exists exports_job_idx on public.exports (job_id) where job_id is not null;

-- =====================================================================
-- 5. 트리거
-- =====================================================================

-- 5-1. updated_at
do $$
declare t text;
begin
  foreach t in array array['asset_packs', 'characters', 'assets', 'series', 'series_characters', 'episodes', 'cuts', 'generations', 'exports'] loop
    execute format('drop trigger if exists %1$s_set_updated_at on public.%1$I', t);
    execute format('create trigger %1$s_set_updated_at before update on public.%1$I for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- 5-2. 이중 잠금: 서버 기록과 카탈로그는 사용자 세션 쓰기를 42501로 거부
do $$
declare t text;
begin
  foreach t in array array['asset_packs', 'characters', 'assets', 'generations', 'user_assets', 'exports'] loop
    execute format('drop trigger if exists %1$s_guard_write on public.%1$I', t);
    execute format('create trigger %1$s_guard_write before insert or update or delete on public.%1$I for each row execute function public.guard_privileged_write()', t);
  end loop;
end $$;

-- 5-3. 플랜 한도(작품 수, 회차 수, 컷 수). 사용자 INSERT 에만 적용. 기본값은 무료 플랜 값(01_PRD 4절).
create or replace function public.enforce_plan_limits()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_features jsonb;
  v_limit    integer;
  v_count    integer;
  v_format   text;
begin
  if public.is_service_caller() then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('toon:limits:' || new.org_id::text));
  v_features := public.plan_features(new.org_id);

  if tg_table_name = 'series' then
    v_limit := public.feature_int(v_features, 'max_series', 1);
    select count(*) into v_count from public.series s where s.org_id = new.org_id;
  elsif tg_table_name = 'episodes' then
    v_limit := public.feature_int(v_features, 'max_episodes_per_series', 3);
    select count(*) into v_count from public.episodes e where e.series_id = new.series_id;
  elsif tg_table_name = 'cuts' then
    v_limit := public.feature_int(v_features, 'max_cuts_per_episode', 10);
    select s.format into v_format
    from public.episodes e join public.series s on s.id = e.series_id
    where e.id = new.episode_id;
    if v_format = 'instatoon' then
      v_limit := case when v_limit < 0 then 10 else least(v_limit, 10) end;  -- 인스타 캐러셀 상한(01_PRD 열린 결정)
    end if;
    select count(*) into v_count from public.cuts c where c.episode_id = new.episode_id;
  else
    return new;
  end if;

  if v_limit >= 0 and v_count >= v_limit then
    raise exception 'toon: plan limit reached on % (limit %)', tg_table_name, v_limit using errcode = 'TN001';
  end if;
  return new;
end;
$$;

drop trigger if exists series_plan_limits on public.series;
create trigger series_plan_limits before insert on public.series for each row execute function public.enforce_plan_limits();
drop trigger if exists episodes_plan_limits on public.episodes;
create trigger episodes_plan_limits before insert on public.episodes for each row execute function public.enforce_plan_limits();
drop trigger if exists cuts_plan_limits on public.cuts;
create trigger cuts_plan_limits before insert on public.cuts for each row execute function public.enforce_plan_limits();

-- 5-4. 컷 revision: 문서/크기/시간이 바뀔 때만 1 증가. 사용자가 revision 을 임의로 바꿀 수 없다.
create or replace function public.bump_cut_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.doc is distinct from old.doc
     or new.width is distinct from old.width
     or new.height is distinct from old.height
     or new.duration_ms is distinct from old.duration_ms then
    new.revision := old.revision + 1;
  else
    new.revision := old.revision;
  end if;
  return new;
end;
$$;
drop trigger if exists cuts_bump_revision on public.cuts;
create trigger cuts_bump_revision before update on public.cuts for each row execute function public.bump_cut_revision();

-- 5-5. 실행 상태 전이(generations, exports). service_role 쓰기에도 적용된다.
--   (insert) → queued
--   queued   → running | canceled | failed
--   running  → succeeded | failed | queued(재시도)
--   succeeded / failed / canceled 는 종료 상태
create or replace function public.enforce_run_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'queued' then
      raise exception 'toon: % must start as queued', tg_table_name using errcode = '22023';
    end if;
    return new;
  end if;
  if new.status = old.status then
    return new;
  end if;
  if not (
       (old.status = 'queued'  and new.status in ('running', 'canceled', 'failed'))
    or (old.status = 'running' and new.status in ('succeeded', 'failed', 'queued'))
  ) then
    raise exception 'toon: invalid % status transition % -> %', tg_table_name, old.status, new.status using errcode = '22023';
  end if;
  if new.status in ('succeeded', 'failed', 'canceled') then
    new.finished_at := coalesce(new.finished_at, now());
  end if;
  return new;
end;
$$;
drop trigger if exists generations_status_transition on public.generations;
create trigger generations_status_transition before insert or update on public.generations
  for each row execute function public.enforce_run_status_transition();
drop trigger if exists exports_status_transition on public.exports;
create trigger exports_status_transition before insert or update on public.exports
  for each row execute function public.enforce_run_status_transition();

-- =====================================================================
-- 6. RPC
-- =====================================================================

-- 6-1. 컷 문서 저장(낙관적 동시성). SECURITY INVOKER: RLS 가 그대로 적용된다.
create or replace function public.save_cut_doc(p_cut_id uuid, p_doc jsonb, p_expected_revision integer)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare v_rev integer;
begin
  update public.cuts set doc = p_doc
  where id = p_cut_id and revision = p_expected_revision
  returning revision into v_rev;
  if v_rev is null then
    if exists (select 1 from public.cuts c where c.id = p_cut_id) then
      raise exception 'save_cut_doc: revision conflict' using errcode = 'TN409';
    end if;
    raise exception 'save_cut_doc: not found' using errcode = 'P0002';
  end if;
  return v_rev;
end;
$$;
revoke execute on function public.save_cut_doc(uuid, jsonb, integer) from public, anon;
grant execute on function public.save_cut_doc(uuid, jsonb, integer) to authenticated;

-- 6-2. 컷 순서 변경. 회차의 컷 id 전부를 새 순서로 받는다. SECURITY INVOKER.
create or replace function public.reorder_cuts(p_episode_id uuid, p_cut_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare v_count integer;
begin
  select count(*) into v_count from public.cuts c where c.episode_id = p_episode_id;
  if v_count = 0 then
    raise exception 'reorder_cuts: episode not found or empty' using errcode = 'P0002';
  end if;
  if coalesce(cardinality(p_cut_ids), 0) <> v_count
     or (select count(distinct x) from unnest(p_cut_ids) as u(x)) <> v_count
     or exists (select 1 from unnest(p_cut_ids) as u(x)
                where not exists (select 1 from public.cuts c where c.id = u.x and c.episode_id = p_episode_id)) then
    raise exception 'reorder_cuts: id list does not match the episode cuts' using errcode = '22023';
  end if;
  update public.cuts c
  set position = o.ord - 1
  from unnest(p_cut_ids) with ordinality as o(id, ord)
  where c.id = o.id and c.episode_id = p_episode_id;
end;
$$;
revoke execute on function public.reorder_cuts(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_cuts(uuid, uuid[]) to authenticated;

-- 6-3. 에셋 사용 가능 여부(플랜의 asset_tiers 기준). 서버의 서명 URL 발급과 렌더 워커가 같은 판정을 쓴다.
create or replace function public.org_asset_access(p_org_id uuid, p_asset_ids uuid[])
returns table (asset_id uuid, tier text, allowed boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_features jsonb;
  v_tiers    text[];
begin
  if not public.is_service_caller() and not public.is_org_member(p_org_id) then
    raise exception 'org_asset_access: not a member' using errcode = '42501';
  end if;
  if not public.has_entitlement(p_org_id, 'toon') then
    raise exception 'org_asset_access: no toon entitlement' using errcode = '42501';
  end if;
  v_features := public.plan_features(p_org_id);
  if jsonb_typeof(v_features -> 'asset_tiers') = 'array' then
    v_tiers := array(select jsonb_array_elements_text(v_features -> 'asset_tiers'));
  end if;
  if coalesce(cardinality(v_tiers), 0) = 0 then
    v_tiers := array['free'];
  end if;
  return query
    select a.id, a.tier, (a.status = 'published' and a.tier = any (v_tiers))
    from public.assets a
    where a.id = any (p_asset_ids);
end;
$$;
revoke execute on function public.org_asset_access(uuid, uuid[]) from public, anon;
grant execute on function public.org_asset_access(uuid, uuid[]) to authenticated;

-- 6-4. 이번 달(KST) 이미지 내보내기 수. 무료 플랜 월 한도 판정용.
create or replace function public.monthly_export_count(p_org_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start timestamptz;
  v_count integer;
begin
  if not public.is_service_caller() and not public.is_org_member(p_org_id) then
    raise exception 'monthly_export_count: not a member' using errcode = '42501';
  end if;
  v_start := date_trunc('month', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
  select count(*) into v_count
  from public.exports x
  where x.org_id = p_org_id and x.kind in ('png', 'zip', 'webtoon_strip')
    and x.status in ('queued', 'running', 'succeeded') and x.created_at >= v_start;
  return v_count;
end;
$$;
revoke execute on function public.monthly_export_count(uuid) from public, anon;
grant execute on function public.monthly_export_count(uuid) to authenticated;

-- 6-5. 내 에셋 보관(소프트 삭제). 멤버 이상. 파일 삭제는 서버 정리 작업이 한다.
create or replace function public.archive_user_asset(p_user_asset_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.user_assets;
begin
  select * into v_row from public.user_assets where id = p_user_asset_id for update;
  if not found or v_row.deleted_at is not null then
    raise exception 'archive_user_asset: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'archive_user_asset: not a member' using errcode = '42501';
  end if;
  update public.user_assets set deleted_at = now() where id = p_user_asset_id;
  perform public.write_audit(v_row.org_id, 'user_asset.archive', 'user_asset', p_user_asset_id::text);
end;
$$;
revoke execute on function public.archive_user_asset(uuid) from public, anon;
grant execute on function public.archive_user_asset(uuid) to authenticated;

-- 내부 함수는 사용자에게 열지 않는다(트리거 함수는 EXECUTE 없이 트리거로만 실행된다)
revoke execute on function public.enforce_plan_limits() from public, anon, authenticated;
revoke execute on function public.bump_cut_revision() from public, anon, authenticated;
revoke execute on function public.enforce_run_status_transition() from public, anon, authenticated;

-- =====================================================================
-- 6-9. (모놀리스 전용) 기본 권한 회수
--   Supabase 는 public 객체에 anon/authenticated 권한을 기본으로 준다. 0001 이 기본 권한을 회수했지만
--   DB_CONVENTIONS.md 12장 (d) 에 따라 도메인 테이블마다 명시적으로 한 번 더 회수한 뒤 아래 7절에서 필요한 것만 준다.
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['asset_packs', 'characters', 'assets', 'catalog_assets', 'series', 'series_characters',
                           'episodes', 'cuts', 'generations', 'user_assets', 'exports'] loop
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant all on table public.%I to service_role', t);
  end loop;
end $$;

-- =====================================================================
-- 7. RLS 정책과 GRANT
-- =====================================================================

alter table public.asset_packs       enable row level security;
alter table public.characters        enable row level security;
alter table public.assets            enable row level security;
alter table public.series            enable row level security;
alter table public.series_characters enable row level security;
alter table public.episodes          enable row level security;
alter table public.cuts              enable row level security;
alter table public.generations       enable row level security;
alter table public.user_assets       enable row level security;
alter table public.exports           enable row level security;

-- 7-1. 카탈로그: 공개된 행만, toon 사용자만. 운영자는 draft 도 본다. 쓰기 정책 없음.
grant select on public.asset_packs, public.characters to authenticated;
-- assets 는 원본/편집 경로 컬럼을 사용자에게 주지 않는다(리뷰 #2)
grant select (id, pack_id, character_id, kind, code, name, tier, preview_path, mime, width, height, duration_ms,
              anchors, tags, status, sort_order, created_at, updated_at) on public.assets to authenticated;
grant select on public.catalog_assets to authenticated;

drop policy if exists asset_packs_select on public.asset_packs;
create policy asset_packs_select on public.asset_packs for select to authenticated
  using ((status = 'published' and public.has_toon_access()) or public.is_platform_admin());
drop policy if exists characters_select on public.characters;
create policy characters_select on public.characters for select to authenticated
  using ((status = 'published' and public.has_toon_access()) or public.is_platform_admin());
drop policy if exists assets_select on public.assets;
create policy assets_select on public.assets for select to authenticated
  using ((status = 'published' and public.has_toon_access()) or public.is_platform_admin());

-- 7-2. 콘텐츠 테이블: 멤버 + 엔타이틀먼트. 쓰기 정책에는 with check. 삭제는 owner/admin.
do $$
declare t text;
begin
  foreach t in array array['series', 'series_characters', 'episodes', 'cuts'] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists %1$s_select on public.%1$I', t);
    execute format('create policy %1$s_select on public.%1$I for select to authenticated using (public.is_org_member(org_id) and public.has_entitlement(org_id, %2$L))', t, 'toon');
    execute format('drop policy if exists %1$s_insert on public.%1$I', t);
    execute format('create policy %1$s_insert on public.%1$I for insert to authenticated with check (public.is_org_member(org_id) and public.has_entitlement(org_id, %2$L))', t, 'toon');
    execute format('drop policy if exists %1$s_update on public.%1$I', t);
    execute format('create policy %1$s_update on public.%1$I for update to authenticated using (public.is_org_member(org_id) and public.has_entitlement(org_id, %2$L)) with check (public.is_org_member(org_id) and public.has_entitlement(org_id, %2$L))', t, 'toon');
    execute format('drop policy if exists %1$s_delete on public.%1$I', t);
    execute format('create policy %1$s_delete on public.%1$I for delete to authenticated using (public.has_org_role(org_id, array[%2$L, %3$L]))', t, 'owner', 'admin');
  end loop;
end $$;
-- 사용자가 바꾸면 안 되는 컬럼: revision 은 트리거가 덮어쓴다. created_by 는 기본값 auth.uid().

-- 7-3. 서버 기록: 멤버 SELECT 만. 쓰기 GRANT 없음 + guard 트리거.
grant select on public.generations, public.user_assets, public.exports to authenticated;

drop policy if exists generations_select on public.generations;
create policy generations_select on public.generations for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'));
drop policy if exists user_assets_select on public.user_assets;
create policy user_assets_select on public.user_assets for select to authenticated
  using (deleted_at is null and public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'));
drop policy if exists exports_select on public.exports;
create policy exports_select on public.exports for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'));

-- =====================================================================
-- 8. Storage (제품 전용 버킷)
--   toon-catalog     비공개. 카탈로그 원본과 편집용 이미지. 정책 없음 → service_role 만(서명 URL 은 서버가 발급)
--   toon-previews    공개 읽기. 256px 썸네일만. 쓰기 정책 없음 → service_role 만
--   toon-user-assets 비공개. AI 생성물 채택본. 멤버는 자기 조직 폴더 읽기만, 쓰기는 서버만(AI 표시 무결성)
--   내보내기 결과는 core 버킷 exports(<org_id>/toon/exports/...)를 쓴다.
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('toon-catalog',     'toon-catalog',     false, 20971520, array['image/png', 'image/webp', 'image/svg+xml', 'audio/mpeg']),
  ('toon-previews',    'toon-previews',    true,  1048576,  array['image/webp', 'image/png']),
  ('toon-user-assets', 'toon-user-assets', false, 20971520, array['image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists toon_previews_select on storage.objects;
create policy toon_previews_select on storage.objects for select to anon, authenticated
  using (bucket_id = 'toon-previews');
drop policy if exists toon_user_assets_select on storage.objects;
create policy toon_user_assets_select on storage.objects for select to authenticated
  using (bucket_id = 'toon-user-assets' and public.is_org_member(public.storage_org_id(name)));

-- =====================================================================
-- 9. 함수 EXECUTE 정리 (0007_core_function_privileges.sql 과 같은 규칙)
--   alter default privileges ... revoke ... from public 은 PostgreSQL 전역 기본 PUBLIC EXECUTE 를
--   없애지 못한다. 스키마의 모든 함수에서 PUBLIC/anon EXECUTE 를 회수하고 의도한 것만 다시 준다.
-- =====================================================================
do $$ declare r record; begin for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('has_toon_access','plan_features','feature_int','enforce_plan_limits','bump_cut_revision','enforce_run_status_transition','save_cut_doc','reorder_cuts','org_asset_access','monthly_export_count','archive_user_asset') loop execute format('revoke execute on function %s from public, anon', r.sig); execute format('grant execute on function %s to service_role', r.sig); end loop; end $$;  -- 모놀리스: public 의 코어 함수 권한은 건드리지 않고 도메인 함수만 회수
grant execute on function public.has_toon_access() to authenticated;
grant execute on function public.plan_features(uuid) to authenticated;
grant execute on function public.feature_int(jsonb, text, integer) to authenticated;
grant execute on function public.save_cut_doc(uuid, jsonb, integer) to authenticated;
grant execute on function public.reorder_cuts(uuid, uuid[]) to authenticated;
grant execute on function public.org_asset_access(uuid, uuid[]) to authenticated;
grant execute on function public.monthly_export_count(uuid) to authenticated;
grant execute on function public.archive_user_asset(uuid) to authenticated;
revoke execute on function public.enforce_plan_limits() from authenticated;
revoke execute on function public.bump_cut_revision() from authenticated;
revoke execute on function public.enforce_run_status_transition() from authenticated;

-- =====================================================================
-- 11. 벤치마킹 보강 (2026-10-13, 확정 결정 20). 모듈러 2000_toon.sql 11절을 12장 규칙으로 변환
--   설계: docs/products/toon-factory/08_BENCHMARK.md 2장, 01_PRD.md TN-F-038·TN-F-070~073, 05_DATA_MODEL.md 2.6절.
--   11-1 내보내기 플랫폼 프리셋(exports.preset). 규격 수치는 packages/toon-doc/presets 가 정본이고 DB 는 코드만 검사한다.
--   11-2 브랜디드 툰(sponsorships): 광고주 브리프 + 대가성 문구 + 승인. 승인된 협찬 회차만 최종 내보내기,
--        대가성 문구와 가상인물 표시는 서버(이 트리거)가 협찬 행에서 복사한다(요청 페이로드 불신).
--   SNS 직접 업로드(Phase 2)와 숏툰 모션(Phase 2)은 이 조각에 테이블을 만들지 않는다(01_PRD 2절).
--   (모놀리스) 11-3 플랜 키 병합은 넣지 않는다. sponsorship 키는 seed.sql 의 features 에 직접 있다.
-- =====================================================================

-- 11-1. 플랫폼 프리셋
alter table public.exports add column if not exists preset text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'exports_preset_check' and conrelid = 'public.exports'::regclass) then
    alter table public.exports add constraint exports_preset_check check (
      preset is null or preset in ('instagram_carousel', 'webtoon_canvas', 'naver_challenge', 'vertical_9x16'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'exports_preset_kind_check' and conrelid = 'public.exports'::regclass) then
    -- 프리셋과 내보내기 종류의 조합: 캐러셀은 png/zip, 웹툰 계열은 webtoon_strip, 9:16 은 mp4
    alter table public.exports add constraint exports_preset_kind_check check (
      preset is null
      or (preset = 'instagram_carousel' and kind in ('png', 'zip'))
      or (preset in ('webtoon_canvas', 'naver_challenge') and kind = 'webtoon_strip')
      or (preset = 'vertical_9x16' and kind = 'mp4'));
  end if;
end $$;

-- 11-2. 브랜디드 툰(협찬)
create table if not exists public.sponsorships (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations(id) on delete cascade,
  series_id         uuid not null,
  advertiser_name   text not null constraint sponsorships_advertiser_check check (char_length(advertiser_name) between 1 and 80),
  product_name      text constraint sponsorships_product_check check (product_name is null or char_length(product_name) <= 80),
  brief             text constraint sponsorships_brief_check check (brief is null or char_length(brief) <= 3000),
  key_messages      text[] not null default '{}' constraint sponsorships_key_messages_check check (cardinality(key_messages) <= 10),
  banned_terms      text[] not null default '{}' constraint sponsorships_banned_terms_check check (cardinality(banned_terms) <= 50),
  compensation_kind text not null
                    constraint sponsorships_compensation_check check (compensation_kind in ('paid', 'free_product', 'commission', 'other')),
  disclosure_text   text not null default '광고'
                    constraint sponsorships_disclosure_check check (char_length(btrim(disclosure_text)) between 2 and 60),
  virtual_character boolean not null default true,   -- 캐릭터(가상인물)가 상품을 추천·보증하는 형식이면 true → 가상인물 표시
  status            text not null default 'draft'
                    constraint sponsorships_status_check check (status in ('draft', 'in_review', 'changes_requested', 'approved', 'closed')),
  decided_at        timestamptz,
  decided_by        uuid,
  decision_note     text constraint sponsorships_decision_note_check check (decision_note is null or char_length(decision_note) <= 500),
  created_by        uuid default auth.uid(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint sponsorships_series_fk foreign key (series_id, org_id) references public.series (id, org_id) on delete cascade,
  constraint sponsorships_id_org_uniq unique (id, org_id),
  constraint sponsorships_decided_check check (status not in ('approved', 'changes_requested') or (decided_at is not null and decided_by is not null))
);
create index if not exists sponsorships_org_updated_idx on public.sponsorships (org_id, updated_at desc);

alter table public.episodes add column if not exists sponsorship_id uuid;
alter table public.exports  add column if not exists sponsorship_id uuid references public.sponsorships(id) on delete set null;
alter table public.exports  add column if not exists disclosure_text text;
alter table public.exports  add column if not exists virtual_character_label boolean not null default false;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'episodes_sponsorship_fk' and conrelid = 'public.episodes'::regclass) then
    alter table public.episodes add constraint episodes_sponsorship_fk
      foreign key (sponsorship_id, org_id) references public.sponsorships (id, org_id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'exports_disclosure_check' and conrelid = 'public.exports'::regclass) then
    alter table public.exports add constraint exports_disclosure_check check (sponsorship_id is null or disclosure_text is not null);
  end if;
end $$;
create index if not exists episodes_sponsorship_idx on public.episodes (sponsorship_id) where sponsorship_id is not null;

drop trigger if exists sponsorships_set_updated_at on public.sponsorships;
create trigger sponsorships_set_updated_at before update on public.sponsorships for each row execute function public.set_updated_at();

-- 협찬 상태 전이. 사용자: draft ↔ in_review, changes_requested → draft, approved → closed.
--   approved / changes_requested 는 public.decide_sponsorship(owner/admin)만 만든다.
--   승인 뒤 브리프·문구·보상 형태를 고치면 다시 in_review 로 돌아가고 결정 기록을 지운다.
create or replace function public.enforce_sponsorship_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_deciding boolean := coalesce(current_setting('public.sponsorship_decision', true), '') = 'on';
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' and not public.is_service_caller() then
      raise exception 'sponsorship: must start as draft' using errcode = '22023';
    end if;
    if not public.is_service_caller() then
      -- 플랜 게이트(01_PRD 4.2절 sponsorship). 키가 없으면 false. RLS 직접 INSERT 도 여기서 막힌다.
      if coalesce(public.plan_features(new.org_id) ->> 'sponsorship', 'false') <> 'true' then
        raise exception 'toon: sponsorship is not in this plan' using errcode = 'TN002';
      end if;
      new.decided_at := null; new.decided_by := null; new.decision_note := null;
    end if;
    return new;
  end if;
  if old.status = 'approved' and new.status = 'approved' and not v_deciding
     and (new.brief is distinct from old.brief or new.key_messages is distinct from old.key_messages
          or new.disclosure_text is distinct from old.disclosure_text or new.compensation_kind is distinct from old.compensation_kind
          or new.virtual_character is distinct from old.virtual_character or new.advertiser_name is distinct from old.advertiser_name
          or new.product_name is distinct from old.product_name) then
    new.status := 'in_review'; new.decided_at := null; new.decided_by := null;
    return new;
  end if;
  if new.status = old.status then
    if not v_deciding and not public.is_service_caller() then
      new.decided_at := old.decided_at; new.decided_by := old.decided_by; new.decision_note := old.decision_note;
    end if;
    return new;
  end if;
  if v_deciding or public.is_service_caller() then
    if not ((old.status = 'in_review' and new.status in ('approved', 'changes_requested'))
            or (old.status = 'approved' and new.status = 'closed')
            or (old.status in ('draft', 'changes_requested') and new.status = 'in_review')
            or (old.status = 'in_review' and new.status = 'draft')) then
      raise exception 'sponsorship: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    return new;
  end if;
  if not ((old.status = 'draft' and new.status = 'in_review')
          or (old.status = 'in_review' and new.status = 'draft')
          or (old.status = 'changes_requested' and new.status in ('draft', 'in_review'))
          or (old.status = 'approved' and new.status = 'closed')) then
    raise exception 'sponsorship: status % -> % needs decide_sponsorship', old.status, new.status using errcode = '42501';
  end if;
  new.decided_at := old.decided_at; new.decided_by := old.decided_by; new.decision_note := old.decision_note;
  return new;
end;
$$;
drop trigger if exists sponsorships_status on public.sponsorships;
create trigger sponsorships_status before insert or update on public.sponsorships
  for each row execute function public.enforce_sponsorship_status();

-- 승인·수정 요청 기록. 광고주(고객) 확인 결과를 owner/admin 이 기록한다(외부 검토 링크는 Phase 2).
create or replace function public.decide_sponsorship(p_sponsorship_id uuid, p_decision text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.sponsorships;
begin
  if p_decision not in ('approved', 'changes_requested') then
    raise exception 'decide_sponsorship: decision must be approved or changes_requested' using errcode = '22023';
  end if;
  select * into v_row from public.sponsorships where id = p_sponsorship_id for update;
  if not found then
    raise exception 'decide_sponsorship: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'decide_sponsorship: owner/admin only' using errcode = '42501';
  end if;
  if v_row.status <> 'in_review' then
    raise exception 'decide_sponsorship: sponsorship is not in review' using errcode = '22023';
  end if;
  perform set_config('public.sponsorship_decision', 'on', true);
  update public.sponsorships
     set status = p_decision, decided_at = now(), decided_by = auth.uid(), decision_note = left(p_note, 500)
   where id = p_sponsorship_id;
  perform set_config('public.sponsorship_decision', 'off', true);
  perform public.write_audit(v_row.org_id, 'sponsorship.' || p_decision, 'sponsorship', p_sponsorship_id::text);
end;
$$;

-- 내보내기 행(서버 기록)에 협찬 정보를 서버가 채운다. 협찬 회차는 승인 전 최종 내보내기 금지(TN008).
--   예외: options.purpose = 'review'(광고주 검토용 시안)는 승인 전에도 만들 수 있고 워터마크를 강제한다.
create or replace function public.apply_export_sponsorship()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_sp public.sponsorships;
begin
  new.sponsorship_id := null; new.disclosure_text := null; new.virtual_character_label := false;
  if new.episode_id is null then
    return new;
  end if;
  select s.* into v_sp
  from public.episodes e join public.sponsorships s on s.id = e.sponsorship_id and s.org_id = e.org_id
  where e.id = new.episode_id;
  if not found then
    return new;
  end if;
  if coalesce(new.options ->> 'purpose', '') = 'review' then
    new.watermark := true;
  elsif v_sp.status <> 'approved' then
    raise exception 'toon: sponsored episode needs an approved sponsorship before export' using errcode = 'TN008';
  end if;
  new.sponsorship_id := v_sp.id;
  new.disclosure_text := v_sp.disclosure_text;
  new.virtual_character_label := v_sp.virtual_character;
  return new;
end;
$$;
drop trigger if exists exports_apply_sponsorship on public.exports;
create trigger exports_apply_sponsorship before insert on public.exports
  for each row execute function public.apply_export_sponsorship();

-- (모놀리스 전용) 기본 권한 회수 후 필요한 GRANT 만(DB_CONVENTIONS.md 12장 (d))
revoke all on table public.sponsorships from public, anon, authenticated;
grant all on table public.sponsorships to service_role;

alter table public.sponsorships enable row level security;
grant select, insert, update, delete on public.sponsorships to authenticated;
drop policy if exists sponsorships_select on public.sponsorships;
create policy sponsorships_select on public.sponsorships for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'));
drop policy if exists sponsorships_insert on public.sponsorships;
create policy sponsorships_insert on public.sponsorships for insert to authenticated
  with check (public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'));
drop policy if exists sponsorships_update on public.sponsorships;
create policy sponsorships_update on public.sponsorships for update to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'))
  with check (public.is_org_member(org_id) and public.has_entitlement(org_id, 'toon'));
drop policy if exists sponsorships_delete on public.sponsorships;
create policy sponsorships_delete on public.sponsorships for delete to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']));

revoke execute on function public.enforce_sponsorship_status() from public, anon, authenticated;
revoke execute on function public.apply_export_sponsorship() from public, anon, authenticated;
revoke execute on function public.decide_sponsorship(uuid, text, text) from public, anon;
grant execute on function public.decide_sponsorship(uuid, text, text) to authenticated, service_role;
grant execute on function public.enforce_sponsorship_status() to service_role;
grant execute on function public.apply_export_sponsorship() to service_role;

-- =====================================================================
-- 끝. 모놀리스는 public 이 기본 노출 스키마라 설정이 필요 없다.
-- 타입: supabase gen types typescript --local (public)
-- =====================================================================
