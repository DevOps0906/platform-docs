-- =====================================================================
-- 2000_toon.sql
-- toon-factory 도메인 (Toon Factory, AI 웹툰 제작). 선행: core 0000~0006 (+ seed.sql 의 toon 플랜)
-- 설계 문서: docs/products/toon-factory/05_DATA_MODEL.md
--
-- 구조
--   카탈로그(플랫폼 소유, org 없음): asset_packs → characters → assets
--   작품(조직 소유)               : series → episodes → cuts(doc jsonb = 레이어 판별 유니온)
--                                   series_characters (작품 캐스트)
--   서버 기록(쓰기는 service_role): generations(AI 생성), user_assets(채택한 생성물), exports(내보내기)
--
-- 보안 원칙 (SECURITY_BASELINE.md)
--   - 모든 테이블 RLS ON. 콘텐츠 테이블(series, episodes, cuts, series_characters)만 멤버 쓰기 정책.
--   - 돈/상태/AI 표시 무결성이 걸린 테이블(generations, user_assets, exports, 카탈로그)은 SELECT만 + guard 트리거.
--   - 테넌트 간 FK 우회를 막기 위해 하위 테이블은 (부모 id, org_id) 복합 FK를 쓴다.
--   - authenticated 에 EXECUTE 를 연 SECURITY DEFINER 함수는 core.is_service_caller() + 멤버/역할 검사.
--   - 플랜 한도(작품 수, 회차 수, 컷 수)는 BEFORE INSERT 트리거가 DB에서 강제한다(클라이언트 판정 불신).
-- 반복 실행 가능.
-- =====================================================================

create schema if not exists toon;
comment on schema toon is 'toon-factory: AI 웹툰 제작 (작품/회차/컷, 에셋 카탈로그, AI 생성, 내보내기)';
grant usage on schema toon to anon, authenticated, service_role;
alter default privileges in schema toon grant all on tables to service_role;
alter default privileges in schema toon grant all on sequences to service_role;
alter default privileges in schema toon grant execute on functions to service_role;
alter default privileges in schema toon revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy, status) values ('toon', 'Toon Factory', 'toon', 'open', 'beta')
on conflict (id) do nothing;

-- =====================================================================
-- 1. 헬퍼 함수
-- =====================================================================

-- 현재 사용자가 toon 엔타이틀먼트가 있는 조직의 활성 멤버인가(카탈로그 읽기 정책용)
create or replace function toon.has_toon_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from core.org_members m
    join core.app_entitlements e on e.org_id = m.org_id
    where m.user_id = auth.uid() and m.status = 'active'
      and e.app_id = 'toon' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  );
$$;
grant execute on function toon.has_toon_access() to authenticated;

-- 조직의 toon 플랜 features. 서버 게이팅과 한도 트리거가 쓴다. 멤버 또는 service 만.
create or replace function toon.plan_features(p_org_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_features jsonb;
begin
  if not core.is_service_caller() and not core.is_org_member(p_org_id) then
    raise exception 'plan_features: not a member' using errcode = '42501';
  end if;
  select p.features into v_features
  from core.app_entitlements e
  join core.plans p on p.id = e.plan_id
  where e.org_id = p_org_id and e.app_id = 'toon' and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now());
  return coalesce(v_features, '{}'::jsonb);
end;
$$;
grant execute on function toon.plan_features(uuid) to authenticated;

-- features 의 정수 키. 키가 없거나 숫자가 아니면 기본값(무료 플랜 값). -1 은 무제한.
create or replace function toon.feature_int(p_features jsonb, p_key text, p_default integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_features -> p_key) = 'number' then (p_features ->> p_key)::integer else p_default end;
$$;
grant execute on function toon.feature_int(jsonb, text, integer) to authenticated;

-- =====================================================================
-- 2. 카탈로그 (플랫폼 소유. 쓰기는 service_role, 읽기는 toon 사용자)
-- =====================================================================

create table if not exists toon.asset_packs (
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

create table if not exists toon.characters (
  id          uuid primary key default gen_random_uuid(),
  pack_id     uuid not null references toon.asset_packs(id) on delete restrict,
  code        text not null constraint characters_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name        text not null,
  description text,
  status      text not null default 'draft' constraint characters_status_check check (status in ('draft', 'published', 'retired')),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (pack_id, code)
);

create table if not exists toon.assets (
  id           uuid primary key default gen_random_uuid(),
  pack_id      uuid not null references toon.asset_packs(id) on delete restrict,
  character_id uuid references toon.characters(id) on delete restrict,
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
create index if not exists assets_pack_kind_idx on toon.assets (pack_id, kind, sort_order);
create index if not exists assets_character_kind_idx on toon.assets (character_id, kind) where character_id is not null;

-- 사용자용 카탈로그 뷰: 원본/편집 경로를 뺀 컬럼만. security_invoker 라 아래 RLS 를 그대로 통과한다.
create or replace view toon.catalog_assets with (security_invoker = true) as
  select a.id, a.pack_id, a.character_id, a.kind, a.code, a.name, a.tier, a.preview_path, a.mime,
         a.width, a.height, a.duration_ms, a.anchors, a.tags, a.sort_order
  from toon.assets a
  where a.status = 'published';

-- =====================================================================
-- 3. 작품 (조직 소유 콘텐츠. 멤버 쓰기 허용 + 플랜 한도 트리거)
-- =====================================================================

create table if not exists toon.series (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  title         text not null constraint series_title_check check (char_length(title) between 1 and 80),
  format        text not null constraint series_format_check check (format in ('instatoon', 'webtoon')),
  canvas_width  integer not null constraint series_canvas_width_check check (canvas_width between 320 and 2048),
  canvas_height integer not null constraint series_canvas_height_check check (canvas_height between 320 and 4096),
  genre         text constraint series_genre_check check (genre is null or char_length(genre) <= 40),
  synopsis      text constraint series_synopsis_check check (synopsis is null or char_length(synopsis) <= 2000),
  style_pack_id uuid references toon.asset_packs(id) on delete set null,
  status        text not null default 'active' constraint series_status_check check (status in ('active', 'archived')),
  metadata      jsonb not null default '{}'::jsonb,
  created_by    uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint series_id_org_uniq unique (id, org_id)
);
create index if not exists series_org_updated_idx on toon.series (org_id, updated_at desc);

create table if not exists toon.series_characters (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  series_id    uuid not null,
  character_id uuid not null references toon.characters(id) on delete restrict,
  display_name text not null constraint series_characters_name_check check (char_length(display_name) between 1 and 40),
  role_note    text constraint series_characters_role_note_check check (role_note is null or char_length(role_note) <= 300),
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint series_characters_series_fk foreign key (series_id, org_id) references toon.series (id, org_id) on delete cascade,
  unique (series_id, character_id)
);

create table if not exists toon.episodes (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
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
  constraint episodes_series_fk foreign key (series_id, org_id) references toon.series (id, org_id) on delete cascade,
  constraint episodes_id_org_uniq unique (id, org_id),
  constraint episodes_series_number_uniq unique (series_id, number),
  constraint episodes_script_size_check check (pg_column_size(script) <= 131072)
);

create table if not exists toon.cuts (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
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
  constraint cuts_episode_fk foreign key (episode_id, org_id) references toon.episodes (id, org_id) on delete cascade,
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

create table if not exists toon.generations (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  series_id        uuid references toon.series(id) on delete set null,
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
  job_id           uuid references core.jobs(id) on delete set null,
  credit_ledger_id bigint references core.credit_ledger(id),
  credits          integer not null default 0 constraint generations_credits_check check (credits >= 0),
  fal_request_id   text unique,
  request_id       uuid not null unique,
  error            text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  finished_at      timestamptz
);
create index if not exists generations_org_created_idx on toon.generations (org_id, created_at desc);
create index if not exists generations_job_idx on toon.generations (job_id) where job_id is not null;

create table if not exists toon.user_assets (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  generation_id uuid references toon.generations(id) on delete set null,
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
create index if not exists user_assets_org_created_idx on toon.user_assets (org_id, created_at desc) where deleted_at is null;

create table if not exists toon.exports (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  episode_id       uuid references toon.episodes(id) on delete set null,
  kind             text not null constraint exports_kind_check check (kind in ('png', 'zip', 'webtoon_strip', 'mp4')),
  status           text not null default 'queued'
                   constraint exports_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  plan_code        text not null,                 -- 요청 시점 플랜(서버가 기록)
  watermark        boolean not null,              -- 서버가 플랜 features.watermark 로 결정. 클라이언트 입력 아님
  ai_label         boolean not null default false,-- 렌더 시 AI 생성 레이어가 하나라도 있으면 true
  ai_label_visible boolean not null default true, -- 가시 표기 여부. false 는 사용자가 "게시글에 직접 표기" 확인한 경우만(감사 기록)
  options          jsonb not null default '{}'::jsonb,
  job_id           uuid references core.jobs(id) on delete set null,
  credit_ledger_id bigint references core.credit_ledger(id),
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
create index if not exists exports_org_created_idx on toon.exports (org_id, created_at desc);
create index if not exists exports_org_month_idx on toon.exports (org_id, kind, created_at) where status in ('queued', 'running', 'succeeded');
create index if not exists exports_job_idx on toon.exports (job_id) where job_id is not null;

-- =====================================================================
-- 5. 트리거
-- =====================================================================

-- 5-1. updated_at
do $$
declare t text;
begin
  foreach t in array array['asset_packs', 'characters', 'assets', 'series', 'series_characters', 'episodes', 'cuts', 'generations', 'exports'] loop
    execute format('drop trigger if exists %1$s_set_updated_at on toon.%1$I', t);
    execute format('create trigger %1$s_set_updated_at before update on toon.%1$I for each row execute function core.set_updated_at()', t);
  end loop;
end $$;

-- 5-2. 이중 잠금: 서버 기록과 카탈로그는 사용자 세션 쓰기를 42501로 거부
do $$
declare t text;
begin
  foreach t in array array['asset_packs', 'characters', 'assets', 'generations', 'user_assets', 'exports'] loop
    execute format('drop trigger if exists %1$s_guard_write on toon.%1$I', t);
    execute format('create trigger %1$s_guard_write before insert or update or delete on toon.%1$I for each row execute function core.guard_privileged_write()', t);
  end loop;
end $$;

-- 5-3. 플랜 한도(작품 수, 회차 수, 컷 수). 사용자 INSERT 에만 적용. 기본값은 무료 플랜 값(01_PRD 4절).
create or replace function toon.enforce_plan_limits()
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
  if core.is_service_caller() then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('toon:limits:' || new.org_id::text));
  v_features := toon.plan_features(new.org_id);

  if tg_table_name = 'series' then
    v_limit := toon.feature_int(v_features, 'max_series', 1);
    select count(*) into v_count from toon.series s where s.org_id = new.org_id;
  elsif tg_table_name = 'episodes' then
    v_limit := toon.feature_int(v_features, 'max_episodes_per_series', 3);
    select count(*) into v_count from toon.episodes e where e.series_id = new.series_id;
  elsif tg_table_name = 'cuts' then
    v_limit := toon.feature_int(v_features, 'max_cuts_per_episode', 10);
    select s.format into v_format
    from toon.episodes e join toon.series s on s.id = e.series_id
    where e.id = new.episode_id;
    if v_format = 'instatoon' then
      v_limit := case when v_limit < 0 then 10 else least(v_limit, 10) end;  -- 인스타 캐러셀 상한(01_PRD 열린 결정)
    end if;
    select count(*) into v_count from toon.cuts c where c.episode_id = new.episode_id;
  else
    return new;
  end if;

  if v_limit >= 0 and v_count >= v_limit then
    raise exception 'toon: plan limit reached on % (limit %)', tg_table_name, v_limit using errcode = 'TN001';
  end if;
  return new;
end;
$$;

drop trigger if exists series_plan_limits on toon.series;
create trigger series_plan_limits before insert on toon.series for each row execute function toon.enforce_plan_limits();
drop trigger if exists episodes_plan_limits on toon.episodes;
create trigger episodes_plan_limits before insert on toon.episodes for each row execute function toon.enforce_plan_limits();
drop trigger if exists cuts_plan_limits on toon.cuts;
create trigger cuts_plan_limits before insert on toon.cuts for each row execute function toon.enforce_plan_limits();

-- 5-4. 컷 revision: 문서/크기/시간이 바뀔 때만 1 증가. 사용자가 revision 을 임의로 바꿀 수 없다.
create or replace function toon.bump_cut_revision()
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
drop trigger if exists cuts_bump_revision on toon.cuts;
create trigger cuts_bump_revision before update on toon.cuts for each row execute function toon.bump_cut_revision();

-- 5-5. 실행 상태 전이(generations, exports). service_role 쓰기에도 적용된다.
--   (insert) → queued
--   queued   → running | canceled | failed
--   running  → succeeded | failed | queued(재시도)
--   succeeded / failed / canceled 는 종료 상태
create or replace function toon.enforce_run_status_transition()
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
drop trigger if exists generations_status_transition on toon.generations;
create trigger generations_status_transition before insert or update on toon.generations
  for each row execute function toon.enforce_run_status_transition();
drop trigger if exists exports_status_transition on toon.exports;
create trigger exports_status_transition before insert or update on toon.exports
  for each row execute function toon.enforce_run_status_transition();

-- =====================================================================
-- 6. RPC
-- =====================================================================

-- 6-1. 컷 문서 저장(낙관적 동시성). SECURITY INVOKER: RLS 가 그대로 적용된다.
create or replace function toon.save_cut_doc(p_cut_id uuid, p_doc jsonb, p_expected_revision integer)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare v_rev integer;
begin
  update toon.cuts set doc = p_doc
  where id = p_cut_id and revision = p_expected_revision
  returning revision into v_rev;
  if v_rev is null then
    if exists (select 1 from toon.cuts c where c.id = p_cut_id) then
      raise exception 'save_cut_doc: revision conflict' using errcode = 'TN409';
    end if;
    raise exception 'save_cut_doc: not found' using errcode = 'P0002';
  end if;
  return v_rev;
end;
$$;
revoke execute on function toon.save_cut_doc(uuid, jsonb, integer) from public, anon;
grant execute on function toon.save_cut_doc(uuid, jsonb, integer) to authenticated;

-- 6-2. 컷 순서 변경. 회차의 컷 id 전부를 새 순서로 받는다. SECURITY INVOKER.
create or replace function toon.reorder_cuts(p_episode_id uuid, p_cut_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare v_count integer;
begin
  select count(*) into v_count from toon.cuts c where c.episode_id = p_episode_id;
  if v_count = 0 then
    raise exception 'reorder_cuts: episode not found or empty' using errcode = 'P0002';
  end if;
  if coalesce(cardinality(p_cut_ids), 0) <> v_count
     or (select count(distinct x) from unnest(p_cut_ids) as u(x)) <> v_count
     or exists (select 1 from unnest(p_cut_ids) as u(x)
                where not exists (select 1 from toon.cuts c where c.id = u.x and c.episode_id = p_episode_id)) then
    raise exception 'reorder_cuts: id list does not match the episode cuts' using errcode = '22023';
  end if;
  update toon.cuts c
  set position = o.ord - 1
  from unnest(p_cut_ids) with ordinality as o(id, ord)
  where c.id = o.id and c.episode_id = p_episode_id;
end;
$$;
revoke execute on function toon.reorder_cuts(uuid, uuid[]) from public, anon;
grant execute on function toon.reorder_cuts(uuid, uuid[]) to authenticated;

-- 6-3. 에셋 사용 가능 여부(플랜의 asset_tiers 기준). 서버의 서명 URL 발급과 렌더 워커가 같은 판정을 쓴다.
create or replace function toon.org_asset_access(p_org_id uuid, p_asset_ids uuid[])
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
  if not core.is_service_caller() and not core.is_org_member(p_org_id) then
    raise exception 'org_asset_access: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(p_org_id, 'toon') then
    raise exception 'org_asset_access: no toon entitlement' using errcode = '42501';
  end if;
  v_features := toon.plan_features(p_org_id);
  if jsonb_typeof(v_features -> 'asset_tiers') = 'array' then
    v_tiers := array(select jsonb_array_elements_text(v_features -> 'asset_tiers'));
  end if;
  if coalesce(cardinality(v_tiers), 0) = 0 then
    v_tiers := array['free'];
  end if;
  return query
    select a.id, a.tier, (a.status = 'published' and a.tier = any (v_tiers))
    from toon.assets a
    where a.id = any (p_asset_ids);
end;
$$;
revoke execute on function toon.org_asset_access(uuid, uuid[]) from public, anon;
grant execute on function toon.org_asset_access(uuid, uuid[]) to authenticated;

-- 6-4. 이번 달(KST) 이미지 내보내기 수. 무료 플랜 월 한도 판정용.
create or replace function toon.monthly_export_count(p_org_id uuid)
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
  if not core.is_service_caller() and not core.is_org_member(p_org_id) then
    raise exception 'monthly_export_count: not a member' using errcode = '42501';
  end if;
  v_start := date_trunc('month', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
  select count(*) into v_count
  from toon.exports x
  where x.org_id = p_org_id and x.kind in ('png', 'zip', 'webtoon_strip')
    and x.status in ('queued', 'running', 'succeeded') and x.created_at >= v_start;
  return v_count;
end;
$$;
revoke execute on function toon.monthly_export_count(uuid) from public, anon;
grant execute on function toon.monthly_export_count(uuid) to authenticated;

-- 6-5. 내 에셋 보관(소프트 삭제). 멤버 이상. 파일 삭제는 서버 정리 작업이 한다.
create or replace function toon.archive_user_asset(p_user_asset_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row toon.user_assets;
begin
  select * into v_row from toon.user_assets where id = p_user_asset_id for update;
  if not found or v_row.deleted_at is not null then
    raise exception 'archive_user_asset: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'archive_user_asset: not a member' using errcode = '42501';
  end if;
  update toon.user_assets set deleted_at = now() where id = p_user_asset_id;
  perform core.write_audit(v_row.org_id, 'user_asset.archive', 'user_asset', p_user_asset_id::text);
end;
$$;
revoke execute on function toon.archive_user_asset(uuid) from public, anon;
grant execute on function toon.archive_user_asset(uuid) to authenticated;

-- 내부 함수는 사용자에게 열지 않는다(트리거 함수는 EXECUTE 없이 트리거로만 실행된다)
revoke execute on function toon.enforce_plan_limits() from public, anon, authenticated;
revoke execute on function toon.bump_cut_revision() from public, anon, authenticated;
revoke execute on function toon.enforce_run_status_transition() from public, anon, authenticated;

-- =====================================================================
-- 7. RLS 정책과 GRANT
-- =====================================================================

alter table toon.asset_packs       enable row level security;
alter table toon.characters        enable row level security;
alter table toon.assets            enable row level security;
alter table toon.series            enable row level security;
alter table toon.series_characters enable row level security;
alter table toon.episodes          enable row level security;
alter table toon.cuts              enable row level security;
alter table toon.generations       enable row level security;
alter table toon.user_assets       enable row level security;
alter table toon.exports           enable row level security;

-- 7-1. 카탈로그: 공개된 행만, toon 사용자만. 운영자는 draft 도 본다. 쓰기 정책 없음.
grant select on toon.asset_packs, toon.characters to authenticated;
-- assets 는 원본/편집 경로 컬럼을 사용자에게 주지 않는다(리뷰 #2)
grant select (id, pack_id, character_id, kind, code, name, tier, preview_path, mime, width, height, duration_ms,
              anchors, tags, status, sort_order, created_at, updated_at) on toon.assets to authenticated;
grant select on toon.catalog_assets to authenticated;

drop policy if exists asset_packs_select on toon.asset_packs;
create policy asset_packs_select on toon.asset_packs for select to authenticated
  using ((status = 'published' and toon.has_toon_access()) or core.is_platform_admin());
drop policy if exists characters_select on toon.characters;
create policy characters_select on toon.characters for select to authenticated
  using ((status = 'published' and toon.has_toon_access()) or core.is_platform_admin());
drop policy if exists assets_select on toon.assets;
create policy assets_select on toon.assets for select to authenticated
  using ((status = 'published' and toon.has_toon_access()) or core.is_platform_admin());

-- 7-2. 콘텐츠 테이블: 멤버 + 엔타이틀먼트. 쓰기 정책에는 with check. 삭제는 owner/admin.
do $$
declare t text;
begin
  foreach t in array array['series', 'series_characters', 'episodes', 'cuts'] loop
    execute format('grant select, insert, update, delete on toon.%I to authenticated', t);
    execute format('drop policy if exists %1$s_select on toon.%1$I', t);
    execute format('create policy %1$s_select on toon.%1$I for select to authenticated using (core.is_org_member(org_id) and core.has_entitlement(org_id, %2$L))', t, 'toon');
    execute format('drop policy if exists %1$s_insert on toon.%1$I', t);
    execute format('create policy %1$s_insert on toon.%1$I for insert to authenticated with check (core.is_org_member(org_id) and core.has_entitlement(org_id, %2$L))', t, 'toon');
    execute format('drop policy if exists %1$s_update on toon.%1$I', t);
    execute format('create policy %1$s_update on toon.%1$I for update to authenticated using (core.is_org_member(org_id) and core.has_entitlement(org_id, %2$L)) with check (core.is_org_member(org_id) and core.has_entitlement(org_id, %2$L))', t, 'toon');
    execute format('drop policy if exists %1$s_delete on toon.%1$I', t);
    execute format('create policy %1$s_delete on toon.%1$I for delete to authenticated using (core.has_org_role(org_id, array[%2$L, %3$L]))', t, 'owner', 'admin');
  end loop;
end $$;
-- 사용자가 바꾸면 안 되는 컬럼: revision 은 트리거가 덮어쓴다. created_by 는 기본값 auth.uid().

-- 7-3. 서버 기록: 멤버 SELECT 만. 쓰기 GRANT 없음 + guard 트리거.
grant select on toon.generations, toon.user_assets, toon.exports to authenticated;

drop policy if exists generations_select on toon.generations;
create policy generations_select on toon.generations for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'toon'));
drop policy if exists user_assets_select on toon.user_assets;
create policy user_assets_select on toon.user_assets for select to authenticated
  using (deleted_at is null and core.is_org_member(org_id) and core.has_entitlement(org_id, 'toon'));
drop policy if exists exports_select on toon.exports;
create policy exports_select on toon.exports for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'toon'));

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
  using (bucket_id = 'toon-user-assets' and core.is_org_member(core.storage_org_id(name)));

-- =====================================================================
-- 9. 함수 EXECUTE 정리 (0007_core_function_privileges.sql 과 같은 규칙)
--   alter default privileges ... revoke ... from public 은 PostgreSQL 전역 기본 PUBLIC EXECUTE 를
--   없애지 못한다. 스키마의 모든 함수에서 PUBLIC/anon EXECUTE 를 회수하고 의도한 것만 다시 준다.
-- =====================================================================
revoke execute on all functions in schema toon from public, anon;
grant execute on all functions in schema toon to service_role;
grant execute on function toon.has_toon_access() to authenticated;
grant execute on function toon.plan_features(uuid) to authenticated;
grant execute on function toon.feature_int(jsonb, text, integer) to authenticated;
grant execute on function toon.save_cut_doc(uuid, jsonb, integer) to authenticated;
grant execute on function toon.reorder_cuts(uuid, uuid[]) to authenticated;
grant execute on function toon.org_asset_access(uuid, uuid[]) to authenticated;
grant execute on function toon.monthly_export_count(uuid) to authenticated;
grant execute on function toon.archive_user_asset(uuid) to authenticated;
revoke execute on function toon.enforce_plan_limits() from authenticated;
revoke execute on function toon.bump_cut_revision() from authenticated;
revoke execute on function toon.enforce_run_status_transition() from authenticated;

-- =====================================================================
-- 10. AI·음성 기본값 (2026-10-13, 확정 결정 13~17)
--   설계: docs/products/toon-factory/02_ARCHITECTURE.md 5절, 01_PRD.md 4.6절. 정본 규칙은 _platform-core/AI_ARCHITECTURE.md 4장,
--   VOICE_ARCHITECTURE.md 3장. 모든 값은 제안이며 이 조각과 모놀리스 seed 에서만 바꾼다(제품 화면은 set_ai_routing 을 부르지 않는다).
--   10.1 기능별 라우팅 기본값: org_id null(플랫폼 기본), app_id 'toon'. 기능 키는 소문자.
--        체인 제공자는 seed.sql 의 core.ai_providers 행이어야 하고 kind 가 맞아야 한다(10.3 검사).
--        - toon.storyboard  : 콘티 그래프의 plot·panel_split 노드. 이야기 품질이 제품 핵심이라 Claude 먼저.
--        - toon.consistency : 캐릭터 일관성 검사(설정 위키 대비 비교·판정). 비교 작업이라 오픈소스 먼저.
--        - toon.dialogue    : 대사 다듬기 3안. 말맛이 중요해 Claude 먼저.
--        - toon.prompt_en   : 배경 장면 설명 -> 영어 이미지 프롬프트(번역·정리). 오픈소스 먼저.
--        - chat             : 창작 어시스턴트 채팅(/tools/answer). 한국어 창작 품질 때문에 Claude 먼저.
--        - wiki.*           : 작품 설정 위키(캐릭터 바이블) 갱신·점검·질의. 대량 처리라 오픈소스 먼저.
--        - dify.aux         : Dify 보조 LLM 노드. 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--        - toon.knowledge(embedding): 작품 설정 컬렉션. 컬렉션마다 임베딩 모델이 하나여야 하고, 동의 여부와 무관하게
--                          같은 모델로 질의해야 하므로 국내 오픈소스 임베딩으로 고정(모델을 바꾸면 재색인).
--        - voice_chat       : 음성 질문 STT 는 오픈소스 먼저, 답변 읽어 주기 TTS 는 ElevenLabs 먼저.
--        - dialogue_voice   : 대사 음성 미리듣기 TTS. ElevenLabs 먼저(대체 허용: 미리듣기는 참고용).
--        - video_voice      : MP4 음성 입히기 TTS. 한 회차의 목소리가 같아야 하므로 작업 도중 다른 제공자로 대체하지 않는다.
--                          이 금지는 체인이 아니라 음성 어댑터(packages/core-voice, feature=video_voice)가 강제한다.
--   10.2 플랜 features 의 AI 키(있으면 병합). _supabase-modular/seed.sql 반영은 코어 요청(06_AGENT_PLAN.md 6절 요청 7).
--        서버는 누락 키를 기본값(false/0)으로 읽는다.
-- ---------------------------------------------------------------------
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'toon', 'toon.storyboard',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'toon', 'toon.consistency', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'toon.dialogue',    'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'toon', 'toon.prompt_en',   'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'chat',             'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'toon', 'wiki.query',       'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'wiki.ingest',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'wiki.lint',        'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'dify.aux',         'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'toon', 'toon.knowledge',   'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'toon', 'voice_chat',       'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'toon', 'voice_chat',       'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'toon', 'dialogue_voice',   'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'toon', 'video_voice',      'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 10.2 플랜 AI 키 병합(free: 하루 20턴, 영상 음성 없음 / pro: 하루 200턴, 영상 음성 있음). 행이 없으면 아무 일도 하지 않는다.
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 20, "voice_chat": true, "dialogue_voice": true, "video_voice": false}'::jsonb
 where app_id = 'toon' and code = 'free';
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "dialogue_voice": true, "video_voice": true}'::jsonb
 where app_id = 'toon' and code = 'pro';

-- 10.3 체인 검사: 제공자 행이 있을 때만(seed 전에 적용되는 배포 순서에서도 실패하지 않게) 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'toon'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'toon routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;

-- =====================================================================
-- 끝. PostgREST 노출: config.toml [api].schemas 에 toon 추가.
-- 타입: supabase gen types typescript --local --schema core,toon
-- =====================================================================
