-- =====================================================================
-- 1000_publishing.sql
-- flora-publishing(FLORA Publishing) 도메인. 선행: core 0000~0006 (+ seed.sql 선택)
-- 기획 근거: docs/products/flora-publishing/05_DATA_MODEL.md
--
-- 원칙
--   - 모든 테이블 org_id + RLS. 정책은 core 헬퍼만 쓴다(org_members 직접 조회 금지).
--   - 사용자(authenticated)가 쓸 수 있는 것은 순수 콘텐츠뿐이다: books(컬럼 단위 GRANT), chapters, sections,
--     member_settings(본인 행), custom_personas(이름/상태). 생성 결과, 내보내기, 업로드, 잡 진행,
--     웹훅은 service_role(서버, 워커)만 쓴다(guard_privileged_write 이중 잠금).
--   - 플랜/크레딧/역할은 core 소유. 이 파일은 core.* 를 ALTER 하지 않는다.
--   - 사용자에게 EXECUTE를 연 SECURITY DEFINER 함수 안의 호출자 판정은 core.is_service_caller()만 쓴다.
--   - 제품 SQLSTATE 접두사 PB (DB_CONVENTIONS.md 1장). 상태 전이 위반은 22023.
-- 반복 실행 가능.
-- =====================================================================

create schema if not exists publishing;
grant usage on schema publishing to anon, authenticated, service_role;
alter default privileges in schema publishing grant all on tables to service_role;
alter default privileges in schema publishing grant all on sequences to service_role;
alter default privileges in schema publishing grant execute on functions to service_role;
alter default privileges in schema publishing revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy) values ('publishing', 'FLORA Publishing', 'publishing', 'open')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 0. 플랜 기능 조회 헬퍼 (정책/트리거/서버 공용, 읽기 전용)
--    features 키가 없으면 p_default(= Free 값, 01_PRD 4장)를 돌려준다. -1 = 무제한.
--    호출자가 그 조직의 멤버가 아니고 서버도 아니면 p_default 만 돌려준다(타 조직 플랜 정보 비노출).
-- ---------------------------------------------------------------------
create or replace function publishing.book_plan_limit(p_org_id uuid, p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case when jsonb_typeof(p.features -> p_key) = 'number' then (p.features ->> p_key)::integer end
    from core.app_entitlements e
    join core.plans p on p.id = e.plan_id
    where e.org_id = p_org_id and e.app_id = 'publishing' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
      and (core.is_service_caller() or core.is_org_member(p_org_id))
  ), p_default);
$$;

create or replace function publishing.book_plan_flag(p_org_id uuid, p_key text, p_default boolean)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case when jsonb_typeof(p.features -> p_key) = 'boolean' then (p.features ->> p_key)::boolean end
    from core.app_entitlements e
    join core.plans p on p.id = e.plan_id
    where e.org_id = p_org_id and e.app_id = 'publishing' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
      and (core.is_service_caller() or core.is_org_member(p_org_id))
  ), p_default);
$$;

-- features.themes 는 테마 그룹 배열(["basic"] 또는 ["basic","pro"]). 키가 없으면 basic 만.
create or replace function publishing.book_theme_allowed(p_org_id uuid, p_theme_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_theme_key in ('flora-dark', 'minimal-light', 'warm-serif') then true
    when p_theme_key in ('lunaris-dark', 'halo-dev', 'nitro-enterprise', 'hero-analytics') then coalesce((
      select (p.features -> 'themes') ? 'pro'
      from core.app_entitlements e
      join core.plans p on p.id = e.plan_id
      where e.org_id = p_org_id and e.app_id = 'publishing' and e.status = 'active'
        and (e.expires_at is null or e.expires_at > now())
        and (core.is_service_caller() or core.is_org_member(p_org_id))
    ), false)
    else false
  end;
$$;

revoke execute on function publishing.book_plan_limit(uuid, text, integer) from public, anon;
revoke execute on function publishing.book_plan_flag(uuid, text, boolean) from public, anon;
revoke execute on function publishing.book_theme_allowed(uuid, text) from public, anon;
grant execute on function publishing.book_plan_limit(uuid, text, integer) to authenticated, service_role;
grant execute on function publishing.book_plan_flag(uuid, text, boolean) to authenticated, service_role;
grant execute on function publishing.book_theme_allowed(uuid, text) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- 1. custom_personas: 나만의 페르소나(합성 결과). 생성은 서버(LLM 합성), 사용자는 이름/보관만.
-- ---------------------------------------------------------------------
create table if not exists publishing.custom_personas (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  name             text not null constraint custom_personas_name_check check (char_length(name) between 1 and 60),
  base_persona_ids text[] not null default '{}'
                   constraint custom_personas_base_check check (cardinality(base_persona_ids) <= 3),
  taste_config     jsonb not null,
  status           text not null default 'active'
                   constraint custom_personas_status_check check (status in ('active', 'archived')),
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (id, org_id)
);
create index if not exists custom_personas_org_idx on publishing.custom_personas (org_id, created_at desc);
drop trigger if exists custom_personas_set_updated_at on publishing.custom_personas;
create trigger custom_personas_set_updated_at before update on publishing.custom_personas
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. books: 책 1권 = 프로젝트 1개. 위저드 10단계 상태와 책 정보를 담는다.
--    사용자 쓰기는 컬럼 단위 GRANT(아래 9절)로 콘텐츠 컬럼만. is_public/slug/taste_config/word_count 는 서버 또는 RPC.
-- ---------------------------------------------------------------------
create table if not exists publishing.books (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  title             text not null default '제목 없음'
                    constraint books_title_check check (char_length(title) between 1 and 200),
  subtitle          text constraint books_subtitle_check check (char_length(subtitle) <= 200),
  author_name       text constraint books_author_name_check check (char_length(author_name) <= 100),
  genre             text constraint books_genre_check check (genre in
                    ('novel', 'essay', 'poetry', 'self_help', 'nonfiction_business', 'it_tech', 'children', 'fantasy_genre')),
  format_key        text not null default 'A5'
                    constraint books_format_key_check check (format_key in ('A6', 'B6', 'A5', 'shinkuk', 'B5', 'A4_variant')),
  persona_id        text constraint books_persona_id_check check (char_length(persona_id) <= 64),
  custom_persona_id uuid,
  taste_config      jsonb,
  tone              jsonb not null default '{}'::jsonb,
  layout_settings   jsonb not null default '{}'::jsonb,
  plan_brief        jsonb,
  book_info         jsonb not null default '{}'::jsonb,
  step_state        jsonb not null default '{}'::jsonb,
  current_step      smallint not null default 1 constraint books_current_step_check check (current_step between 1 and 10),
  source            text not null default 'wizard' constraint books_source_check check (source in ('wizard', 'upload', 'seed')),
  seed_key          text constraint books_seed_key_check check (seed_key in ('seed_01', 'seed_02', 'seed_03')),
  cover_image_id    uuid,
  status            text not null default 'draft'
                    constraint books_status_check check (status in ('draft', 'writing', 'ready', 'completed', 'archived')),
  writing_started_at timestamptz,
  completed_at      timestamptz,
  is_public         boolean not null default false,
  slug              text unique constraint books_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{2,62}$'),
  published_at      timestamptz,
  word_count        integer not null default 0 constraint books_word_count_check check (word_count >= 0),
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  unique (id, org_id),
  constraint books_custom_persona_fk foreign key (custom_persona_id, org_id)
    references publishing.custom_personas (id, org_id),
  constraint books_public_check check (not is_public or slug is not null)
);
create index if not exists books_org_updated_idx on publishing.books (org_id, updated_at desc) where deleted_at is null;
create index if not exists books_org_status_idx on publishing.books (org_id, status) where deleted_at is null;
create index if not exists books_deleted_idx on publishing.books (deleted_at) where deleted_at is not null;
drop trigger if exists books_set_updated_at on publishing.books;
create trigger books_set_updated_at before update on publishing.books
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 3. chapters / sections: 목차와 원고. sections = 소제목 단위 원고(body_html 은 서버 sanitize 후 저장, 렌더 시 재-sanitize).
-- ---------------------------------------------------------------------
create table if not exists publishing.chapters (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  book_id    uuid not null,
  position   smallint not null constraint chapters_position_check check (position between 1 and 20),
  title      text not null constraint chapters_title_check check (char_length(title) between 1 and 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (id, book_id),
  constraint chapters_book_position_uniq unique (book_id, position) deferrable initially deferred,
  constraint chapters_book_fk foreign key (book_id, org_id) references publishing.books (id, org_id) on delete cascade
);
drop trigger if exists chapters_set_updated_at on publishing.chapters;
create trigger chapters_set_updated_at before update on publishing.chapters
  for each row execute function core.set_updated_at();

create table if not exists publishing.sections (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  book_id          uuid not null,
  chapter_id       uuid not null,
  position         smallint not null constraint sections_position_check check (position between 1 and 10),
  title            text not null constraint sections_title_check check (char_length(title) between 1 and 200),
  paragraph_target smallint not null default 2 constraint sections_paragraph_target_check check (paragraph_target between 1 and 5),
  body_html        text not null default '' constraint sections_body_size_check check (octet_length(body_html) <= 200000),
  char_count       integer not null default 0,
  gen_status       text not null default 'empty'
                   constraint sections_gen_status_check check (gen_status in ('empty', 'queued', 'generating', 'generated', 'edited', 'failed')),
  last_job_id      uuid references core.jobs(id) on delete set null,
  last_error       text,
  revision         integer not null default 0,
  updated_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (id, org_id),
  constraint sections_chapter_position_uniq unique (chapter_id, position) deferrable initially deferred,
  constraint sections_chapter_fk foreign key (chapter_id, book_id) references publishing.chapters (id, book_id) on delete cascade,
  constraint sections_org_fk foreign key (book_id, org_id) references publishing.books (id, org_id) on delete cascade
);
create index if not exists sections_book_idx on publishing.sections (book_id, chapter_id, position);
drop trigger if exists sections_set_updated_at on publishing.sections;
create trigger sections_set_updated_at before update on publishing.sections
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 4. cover_images: AI 표지 후보(fal). 서버만 쓴다. 파일은 Storage org-files.
-- ---------------------------------------------------------------------
create table if not exists publishing.cover_images (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  book_id      uuid not null,
  style        text not null constraint cover_images_style_check check (style in ('illustration', 'photo', 'minimal', 'typography', 'watercolor')),
  provider     text not null default 'fal',
  model        text,
  prompt       text constraint cover_images_prompt_check check (char_length(prompt) <= 4000),
  storage_path text constraint cover_images_path_check check (storage_path is null or split_part(storage_path, '/', 1) = org_id::text),
  width        integer,
  height       integer,
  status       text not null default 'queued'
               constraint cover_images_status_check check (status in ('queued', 'running', 'succeeded', 'failed')),
  job_id       uuid references core.jobs(id) on delete set null,
  error        text,
  created_by   uuid,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (id, org_id),
  constraint cover_images_book_fk foreign key (book_id, org_id) references publishing.books (id, org_id) on delete cascade
);
create index if not exists cover_images_book_idx on publishing.cover_images (book_id, created_at desc);
drop trigger if exists cover_images_set_updated_at on publishing.cover_images;
create trigger cover_images_set_updated_at before update on publishing.cover_images
  for each row execute function core.set_updated_at();

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'books_cover_image_fk') then
    alter table publishing.books add constraint books_cover_image_fk
      foreign key (cover_image_id) references publishing.cover_images (id) on delete set null;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. manuscript_uploads: 원고 업로드. 원본 파일은 org-files(<org>/publishing/manuscripts/<uuid>.<ext>).
--    파싱은 Python 워커(job_type publishing.parse_manuscript). 서버만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists publishing.manuscript_uploads (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  book_id        uuid,
  storage_path   text not null unique
                 constraint manuscript_uploads_path_check check (split_part(storage_path, '/', 1) = org_id::text
                                                                and split_part(storage_path, '/', 2) = 'publishing'),
  original_name  text constraint manuscript_uploads_name_check check (char_length(original_name) <= 255),
  ext            text not null constraint manuscript_uploads_ext_check check (ext in ('txt', 'md', 'docx', 'pdf')),
  mime           text,
  bytes          integer constraint manuscript_uploads_bytes_check check (bytes between 1 and 20971520),
  status         text not null default 'pending_upload'
                 constraint manuscript_uploads_status_check check (status in ('pending_upload', 'uploaded', 'parsing', 'parsed', 'failed', 'expired')),
  parsed_outline jsonb,
  char_count     integer,
  error          text,
  job_id         uuid references core.jobs(id) on delete set null,
  raw_deleted_at timestamptz,
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint manuscript_uploads_book_fk foreign key (book_id, org_id) references publishing.books (id, org_id) on delete set null (book_id)
);
create index if not exists manuscript_uploads_org_idx on publishing.manuscript_uploads (org_id, created_at desc);
drop trigger if exists manuscript_uploads_set_updated_at on publishing.manuscript_uploads;
create trigger manuscript_uploads_set_updated_at before update on publishing.manuscript_uploads
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 6. book_exports: PDF/ePub 내보내기 기록. 파일은 Storage exports. 서버만 쓴다.
--    content_hash 가 같고 succeeded 이며 만료 전이면 서버가 재과금 없이 기존 파일을 돌려준다.
-- ---------------------------------------------------------------------
create table if not exists publishing.book_exports (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  book_id          uuid not null,
  format           text not null constraint book_exports_format_check check (format in ('pdf', 'epub')),
  status           text not null default 'queued'
                   constraint book_exports_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled', 'expired')),
  job_id           uuid references core.jobs(id) on delete set null,
  credit_ledger_id bigint references core.credit_ledger(id),
  content_hash     text not null,
  watermark        boolean not null,
  preset           jsonb not null,
  storage_path     text constraint book_exports_path_check check (storage_path is null or split_part(storage_path, '/', 1) = org_id::text),
  bytes            bigint,
  pages            integer,
  error            text,
  requested_by     uuid,
  created_at       timestamptz not null default now(),
  started_at       timestamptz,
  finished_at      timestamptz,
  expires_at       timestamptz,
  updated_at       timestamptz not null default now(),
  constraint book_exports_book_fk foreign key (book_id, org_id) references publishing.books (id, org_id) on delete cascade
);
create index if not exists book_exports_book_idx on publishing.book_exports (book_id, created_at desc);
create index if not exists book_exports_reuse_idx on publishing.book_exports (book_id, format, content_hash) where status = 'succeeded';
create index if not exists book_exports_org_month_idx on publishing.book_exports (org_id, created_at) where status in ('queued', 'running', 'succeeded');
create index if not exists book_exports_expiry_idx on publishing.book_exports (expires_at) where status = 'succeeded';
drop trigger if exists book_exports_set_updated_at on publishing.book_exports;
create trigger book_exports_set_updated_at before update on publishing.book_exports
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 7. generation_runs: 전체 순차 생성(write_all) / 전체 다듬기(refine_all) 실행 단위.
--    부모 잡 1개(core.jobs) + 섹션별 자식 잡. 책당 진행 중 실행 1개. 취소 요청만 사용자 RPC.
-- ---------------------------------------------------------------------
create table if not exists publishing.generation_runs (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  book_id             uuid not null,
  kind                text not null constraint generation_runs_kind_check check (kind in ('write_all', 'refine_all')),
  mode                text not null default 'fast' constraint generation_runs_mode_check check (mode in ('fast', 'quality')),
  parent_job_id       uuid references core.jobs(id) on delete set null,
  status              text not null default 'queued'
                      constraint generation_runs_status_check check (status in ('queued', 'running', 'succeeded', 'partial', 'failed', 'canceled')),
  total_sections      integer not null default 0,
  done_sections       integer not null default 0,
  failed_sections     integer not null default 0,
  skipped_sections    integer not null default 0,
  credits_estimated   integer not null default 0,
  credits_used        integer not null default 0,
  cancel_requested_at timestamptz,
  cancel_requested_by uuid,
  error               text,
  requested_by        uuid,
  created_at          timestamptz not null default now(),
  started_at          timestamptz,
  finished_at         timestamptz,
  updated_at          timestamptz not null default now(),
  constraint generation_runs_book_fk foreign key (book_id, org_id) references publishing.books (id, org_id) on delete cascade
);
create unique index if not exists generation_runs_one_active_per_book_idx on publishing.generation_runs (book_id)
  where status in ('queued', 'running');
create index if not exists generation_runs_org_idx on publishing.generation_runs (org_id, created_at desc);
drop trigger if exists generation_runs_set_updated_at on publishing.generation_runs;
create trigger generation_runs_set_updated_at before update on publishing.generation_runs
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 8. member_settings: 사용자별 화면 설정(톤앤매너 테마, 페르소나 즐겨찾기, 생성 모드). 본인 행만.
-- ---------------------------------------------------------------------
create table if not exists publishing.member_settings (
  org_id               uuid not null references core.organizations(id) on delete cascade,
  user_id              uuid not null,
  theme_key            text not null default 'flora-dark'
                       constraint member_settings_theme_check check (theme_key in
                       ('flora-dark', 'minimal-light', 'warm-serif', 'lunaris-dark', 'halo-dev', 'nitro-enterprise', 'hero-analytics')),
  favorite_persona_ids text[] not null default '{}'
                       constraint member_settings_favorites_check check (cardinality(favorite_persona_ids) <= 60),
  llm_mode             text not null default 'fast' constraint member_settings_llm_mode_check check (llm_mode in ('fast', 'quality')),
  editor_prefs         jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  primary key (org_id, user_id)
);
drop trigger if exists member_settings_set_updated_at on publishing.member_settings;
create trigger member_settings_set_updated_at before update on publishing.member_settings
  for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 9. webhook_endpoints / webhook_deliveries: 사용자 등록 아웃바운드 웹훅(Make, Zapier, n8n 수신용).
--    서명 비밀은 core.encrypted_credentials(provider = 'outbound_webhook')에만. 서버만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists publishing.webhook_endpoints (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  url                  text not null constraint webhook_endpoints_url_check check (url ~ '^https://' and char_length(url) <= 2000),
  events               text[] not null constraint webhook_endpoints_events_check check (
                         cardinality(events) >= 1
                         and events <@ array['book.completed', 'export.succeeded', 'export.failed']::text[]),
  secret_credential_id uuid not null references core.encrypted_credentials(id),
  status               text not null default 'active'
                       constraint webhook_endpoints_status_check check (status in ('active', 'disabled', 'failing')),
  consecutive_failures integer not null default 0,
  last_delivery_at     timestamptz,
  last_http_status     integer,
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  disabled_at          timestamptz
);
create index if not exists webhook_endpoints_org_idx on publishing.webhook_endpoints (org_id) where status <> 'disabled';
drop trigger if exists webhook_endpoints_set_updated_at on publishing.webhook_endpoints;
create trigger webhook_endpoints_set_updated_at before update on publishing.webhook_endpoints
  for each row execute function core.set_updated_at();

create table if not exists publishing.webhook_deliveries (
  id              bigint generated always as identity primary key,
  org_id          uuid not null references core.organizations(id) on delete cascade,
  endpoint_id     uuid not null references publishing.webhook_endpoints(id) on delete cascade,
  event_type      text not null,
  event_id        uuid not null,
  status          text not null default 'pending'
                  constraint webhook_deliveries_status_check check (status in ('pending', 'succeeded', 'failed')),
  http_status     integer,
  attempts        integer not null default 0,
  next_attempt_at timestamptz,
  last_error      text,
  created_at      timestamptz not null default now(),
  delivered_at    timestamptz,
  unique (endpoint_id, event_id)
);
create index if not exists webhook_deliveries_org_idx on publishing.webhook_deliveries (org_id, created_at desc);

-- ---------------------------------------------------------------------
-- 10. waitlist: 출시 전 대기자 명단. 테넌트 데이터가 아니므로 org_id 없음. service_role 전용.
-- ---------------------------------------------------------------------
create table if not exists publishing.waitlist (
  id                bigint generated always as identity primary key,
  email             text not null constraint waitlist_email_check check (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' and char_length(email) <= 254),
  source            text,
  consent_marketing boolean not null default false,
  ip_hash           text,
  created_at        timestamptz not null default now()
);
create unique index if not exists waitlist_email_uniq on publishing.waitlist (lower(email));

-- =====================================================================
-- 11. 트리거: 쿼터, 상태 전이, 사용자 쓰기 제한
--     트리거 함수는 SECURITY INVOKER 다(사용자 세션이면 RLS 아래에서 실행된다).
--     "사용자 경로인가"의 판정은 core.is_service_caller() 로 한다(규칙 1).
-- =====================================================================

-- books: INSERT 쿼터 + 강제값
create or replace function publishing.books_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_limit integer; v_count integer;
begin
  if not core.is_service_caller() then
    new.created_by := auth.uid();
    new.status := 'draft';
    new.is_public := false;
    new.slug := null;
    new.published_at := null;
    new.taste_config := null;
    new.word_count := 0;
    new.deleted_at := null;
    new.cover_image_id := null;
  end if;
  v_limit := publishing.book_plan_limit(new.org_id, 'max_books', 3);
  if v_limit >= 0 then
    select count(*) into v_count from publishing.books b where b.org_id = new.org_id and b.deleted_at is null;
    if v_count >= v_limit then
      raise exception 'books: plan limit reached (max_books=%)', v_limit using errcode = 'PB001';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists books_before_insert on publishing.books;
create trigger books_before_insert before insert on publishing.books
  for each row execute function publishing.books_before_insert();

-- books: UPDATE 상태 전이(서버 포함) + 사용자 경로 제한
create or replace function publishing.books_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not (
         (old.status = 'draft'     and new.status in ('writing', 'archived'))
      or (old.status = 'writing'   and new.status in ('draft', 'ready', 'archived'))
      or (old.status = 'ready'     and new.status in ('writing', 'completed', 'archived'))
      or (old.status = 'completed' and new.status in ('writing', 'archived'))
      or (old.status = 'archived'  and new.status in ('draft'))
    ) then
      raise exception 'books: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'writing' and old.writing_started_at is null then
      new.writing_started_at := now();
    end if;
    if new.status = 'completed' then
      new.completed_at := now();
    end if;
    if new.status <> 'completed' and new.is_public then
      new.is_public := false;   -- 완성 상태를 벗어나면 공개 페이지를 내린다
    end if;
  end if;

  if not core.is_service_caller() then
    if old.deleted_at is not null and new.deleted_at is null then
      raise exception 'books: restore is server-only' using errcode = 'PB010';
    end if;
    if old.status <> 'draft'
       and (new.persona_id is distinct from old.persona_id or new.custom_persona_id is distinct from old.custom_persona_id) then
      raise exception 'books: persona is locked after writing starts' using errcode = 'PB011';
    end if;
    if new.cover_image_id is distinct from old.cover_image_id and new.cover_image_id is not null then
      if not exists (select 1 from publishing.cover_images c
                     where c.id = new.cover_image_id and c.book_id = new.id and c.org_id = new.org_id and c.status = 'succeeded') then
        raise exception 'books: cover image does not belong to this book or is not ready' using errcode = 'PB006';
      end if;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists books_before_update on publishing.books;
create trigger books_before_update before update on publishing.books
  for each row execute function publishing.books_before_update();

-- chapters: INSERT 쿼터
create or replace function publishing.chapters_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_limit integer; v_count integer;
begin
  v_limit := publishing.book_plan_limit(new.org_id, 'max_chapters', 3);
  if v_limit >= 0 then
    select count(*) into v_count from publishing.chapters c where c.book_id = new.book_id;
    if v_count >= v_limit then
      raise exception 'chapters: plan limit reached (max_chapters=%)', v_limit using errcode = 'PB002';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists chapters_before_insert on publishing.chapters;
create trigger chapters_before_insert before insert on publishing.chapters
  for each row execute function publishing.chapters_before_insert();

-- sections: 쿼터(INSERT) + 단락 한도 + 사용자 경로 강제값 + 생성 중 편집 금지
create or replace function publishing.sections_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_limit integer; v_count integer;
begin
  if tg_op = 'INSERT' then
    v_limit := publishing.book_plan_limit(new.org_id, 'max_sections', 6);
    if v_limit >= 0 then
      select count(*) into v_count from publishing.sections s where s.book_id = new.book_id;
      if v_count >= v_limit then
        raise exception 'sections: plan limit reached (max_sections=%)', v_limit using errcode = 'PB003';
      end if;
    end if;
  end if;

  if tg_op = 'INSERT' or new.paragraph_target is distinct from old.paragraph_target then
    v_limit := publishing.book_plan_limit(new.org_id, 'max_paragraphs', 3);
    if v_limit >= 0 and new.paragraph_target > v_limit then
      raise exception 'sections: paragraph_target % exceeds plan limit %', new.paragraph_target, v_limit using errcode = 'PB004';
    end if;
  end if;

  new.char_count := char_length(regexp_replace(new.body_html, '<[^>]*>', '', 'g'));

  if not core.is_service_caller() then
    new.updated_by := auth.uid();
    if tg_op = 'INSERT' then
      new.gen_status := case when new.body_html = '' then 'empty' else 'edited' end;
      new.last_job_id := null;
      new.last_error := null;
      new.revision := 0;
    else
      if old.gen_status in ('queued', 'generating') and new.body_html is distinct from old.body_html then
        raise exception 'sections: section is being generated' using errcode = 'PB005';
      end if;
      new.gen_status := case when new.body_html is distinct from old.body_html then 'edited' else old.gen_status end;
      new.last_job_id := old.last_job_id;
      new.last_error := old.last_error;
      new.revision := case when new.body_html is distinct from old.body_html then old.revision + 1 else old.revision end;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists sections_before_write on publishing.sections;
create trigger sections_before_write before insert or update on publishing.sections
  for each row execute function publishing.sections_before_write();

-- book_exports: 상태 전이(서버 경로 포함)
create or replace function publishing.book_exports_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'queued'    and new.status in ('running', 'failed', 'canceled'))
    or (old.status = 'running'   and new.status in ('queued', 'succeeded', 'failed'))
    or (old.status = 'succeeded' and new.status in ('expired'))
  ) then
    raise exception 'book_exports: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  if new.status in ('succeeded', 'failed', 'canceled') and old.status <> new.status then
    new.finished_at := now();
  end if;
  if new.status = 'running' and old.status = 'queued' then
    new.started_at := coalesce(new.started_at, now());
  end if;
  return new;
end;
$$;
drop trigger if exists book_exports_transition on publishing.book_exports;
create trigger book_exports_transition before update on publishing.book_exports
  for each row execute function publishing.book_exports_transition();

-- generation_runs: 상태 전이(서버 경로 포함)
create or replace function publishing.generation_runs_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'queued'  and new.status in ('running', 'canceled', 'failed'))
    or (old.status = 'running' and new.status in ('succeeded', 'partial', 'failed', 'canceled'))
  ) then
    raise exception 'generation_runs: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  if new.status in ('succeeded', 'partial', 'failed', 'canceled') and old.status <> new.status then
    new.finished_at := now();
  end if;
  if new.status = 'running' and old.status = 'queued' then
    new.started_at := coalesce(new.started_at, now());
  end if;
  return new;
end;
$$;
drop trigger if exists generation_runs_transition on publishing.generation_runs;
create trigger generation_runs_transition before update on publishing.generation_runs
  for each row execute function publishing.generation_runs_transition();

-- manuscript_uploads: 상태 전이
create or replace function publishing.manuscript_uploads_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not (
       (old.status = 'pending_upload' and new.status in ('uploaded', 'failed', 'expired'))
    or (old.status = 'uploaded'       and new.status in ('parsing', 'failed', 'expired'))
    or (old.status = 'parsing'        and new.status in ('parsed', 'failed', 'uploaded'))
    or (old.status = 'parsed'         and new.status in ('expired'))
    or (old.status = 'failed'         and new.status in ('expired'))
  ) then
    raise exception 'manuscript_uploads: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists manuscript_uploads_transition on publishing.manuscript_uploads;
create trigger manuscript_uploads_transition before update on publishing.manuscript_uploads
  for each row execute function publishing.manuscript_uploads_transition();

-- member_settings: 본인 강제 + 플랜 테마 잠금
create or replace function publishing.member_settings_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not core.is_service_caller() then
    if new.user_id is distinct from auth.uid() then
      raise exception 'member_settings: own row only' using errcode = '42501';
    end if;
    if (tg_op = 'INSERT' or new.theme_key is distinct from old.theme_key)
       and not publishing.book_theme_allowed(new.org_id, new.theme_key) then
      raise exception 'member_settings: theme % is not in the current plan', new.theme_key using errcode = 'PB008';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists member_settings_before_write on publishing.member_settings;
create trigger member_settings_before_write before insert or update on publishing.member_settings
  for each row execute function publishing.member_settings_before_write();

-- 서버 전용 테이블: 이중 잠금(정책/GRANT가 실수로 열려도 사용자 세션 쓰기는 42501)
do $$
declare t text;
begin
  foreach t in array array['cover_images', 'manuscript_uploads', 'book_exports', 'generation_runs',
                           'webhook_endpoints', 'webhook_deliveries', 'waitlist'] loop
    execute format('drop trigger if exists %I on publishing.%I', t || '_guard_write', t);
    execute format('create trigger %I before insert or update or delete on publishing.%I
                    for each row execute function core.guard_privileged_write()', t || '_guard_write', t);
  end loop;
end $$;

-- custom_personas: INSERT 는 서버만(정책 없음 + 트리거)
create or replace function publishing.custom_personas_guard_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not core.is_service_caller() then
    raise exception 'custom_personas: insert is server-only' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists custom_personas_guard_insert on publishing.custom_personas;
create trigger custom_personas_guard_insert before insert on publishing.custom_personas
  for each row execute function publishing.custom_personas_guard_insert();

-- =====================================================================
-- 12. 사용자 RPC (SECURITY DEFINER, authenticated EXECUTE). 규칙 1, 2 준수.
-- =====================================================================

-- 전체 생성 취소 요청. 워커가 cancel_requested_at 을 보고 남은 자식 잡을 cancel_job 한다(환불 포함).
create or replace function publishing.request_generation_cancel(p_run_id uuid)
returns publishing.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare v_row publishing.generation_runs;
begin
  select * into v_row from publishing.generation_runs where id = p_run_id for update;
  if not found then
    raise exception 'request_generation_cancel: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'request_generation_cancel: not a member' using errcode = '42501';
  end if;
  if v_row.status not in ('queued', 'running') then
    raise exception 'request_generation_cancel: run is not active (status=%)', v_row.status using errcode = 'PB007';
  end if;
  if v_row.cancel_requested_at is null then
    update publishing.generation_runs
       set cancel_requested_at = now(), cancel_requested_by = auth.uid()
     where id = p_run_id
    returning * into v_row;
    perform core.write_audit(v_row.org_id, 'generation_run.cancel_request', 'generation_run', v_row.id::text);
  end if;
  return v_row;
end;
$$;
revoke execute on function publishing.request_generation_cancel(uuid) from public, anon;
grant execute on function publishing.request_generation_cancel(uuid) to authenticated, service_role;

-- 공개 책 페이지 켜기/끄기 (Phase 2). owner/admin, 완성 상태, 플랜 기능 public_page 필요.
create or replace function publishing.set_book_visibility(p_book_id uuid, p_is_public boolean, p_slug text default null)
returns publishing.books
language plpgsql
security definer
set search_path = ''
as $$
declare v_row publishing.books;
begin
  select * into v_row from publishing.books where id = p_book_id and deleted_at is null for update;
  if not found then
    raise exception 'set_book_visibility: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'set_book_visibility: owner/admin only' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_row.org_id, 'publishing') then
    raise exception 'set_book_visibility: no entitlement' using errcode = '42501';
  end if;
  if p_is_public then
    if v_row.status <> 'completed' then
      raise exception 'set_book_visibility: book must be completed' using errcode = 'PB009';
    end if;
    if not publishing.book_plan_flag(v_row.org_id, 'public_page', false) then
      raise exception 'set_book_visibility: plan has no public_page' using errcode = 'PB009';
    end if;
    if coalesce(p_slug, v_row.slug) is null or coalesce(p_slug, v_row.slug) !~ '^[a-z0-9][a-z0-9-]{2,62}$' then
      raise exception 'set_book_visibility: invalid slug' using errcode = '22023';
    end if;
  end if;
  update publishing.books
     set is_public    = p_is_public,
         slug         = coalesce(p_slug, slug),
         published_at = case when p_is_public then coalesce(published_at, now()) else published_at end
   where id = p_book_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, case when p_is_public then 'book.publish_page' else 'book.unpublish_page' end,
                           'book', v_row.id::text);
  return v_row;
end;
$$;
revoke execute on function publishing.set_book_visibility(uuid, boolean, text) from public, anon;
grant execute on function publishing.set_book_visibility(uuid, boolean, text) to authenticated, service_role;

-- 트리거 함수는 직접 호출 대상이 아니다
revoke execute on function publishing.books_before_insert() from public, anon, authenticated;
revoke execute on function publishing.books_before_update() from public, anon, authenticated;
revoke execute on function publishing.chapters_before_insert() from public, anon, authenticated;
revoke execute on function publishing.sections_before_write() from public, anon, authenticated;
revoke execute on function publishing.book_exports_transition() from public, anon, authenticated;
revoke execute on function publishing.generation_runs_transition() from public, anon, authenticated;
revoke execute on function publishing.manuscript_uploads_transition() from public, anon, authenticated;
revoke execute on function publishing.member_settings_before_write() from public, anon, authenticated;
revoke execute on function publishing.custom_personas_guard_insert() from public, anon, authenticated;

-- =====================================================================
-- 13. RLS 와 GRANT
--     SELECT: core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing')
--     콘텐츠 쓰기: owner/admin/member (viewer 제외) + with check. DELETE: books 는 owner/admin.
-- =====================================================================
alter table publishing.custom_personas    enable row level security;
alter table publishing.books              enable row level security;
alter table publishing.chapters           enable row level security;
alter table publishing.sections           enable row level security;
alter table publishing.cover_images       enable row level security;
alter table publishing.manuscript_uploads enable row level security;
alter table publishing.book_exports       enable row level security;
alter table publishing.generation_runs    enable row level security;
alter table publishing.member_settings    enable row level security;
alter table publishing.webhook_endpoints  enable row level security;
alter table publishing.webhook_deliveries enable row level security;
alter table publishing.waitlist           enable row level security;

-- 기본 회수 후 허용 목록만
revoke all on publishing.custom_personas, publishing.books, publishing.chapters, publishing.sections,
              publishing.cover_images, publishing.manuscript_uploads, publishing.book_exports,
              publishing.generation_runs, publishing.member_settings, publishing.webhook_endpoints,
              publishing.webhook_deliveries, publishing.waitlist
  from public, anon, authenticated;
grant all on publishing.custom_personas, publishing.books, publishing.chapters, publishing.sections,
             publishing.cover_images, publishing.manuscript_uploads, publishing.book_exports,
             publishing.generation_runs, publishing.member_settings, publishing.webhook_endpoints,
             publishing.webhook_deliveries, publishing.waitlist
  to service_role;

-- custom_personas: 읽기 멤버, 이름/보관 변경 편집자, 삭제 owner/admin, INSERT 없음(서버)
grant select, delete on publishing.custom_personas to authenticated;
grant update (name, status) on publishing.custom_personas to authenticated;
drop policy if exists custom_personas_select on publishing.custom_personas;
create policy custom_personas_select on publishing.custom_personas for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists custom_personas_update on publishing.custom_personas;
create policy custom_personas_update on publishing.custom_personas for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists custom_personas_delete on publishing.custom_personas;
create policy custom_personas_delete on publishing.custom_personas for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- books: 컬럼 단위 GRANT (org_id, status 외 서버 컬럼은 UPDATE 불가)
grant select, delete on publishing.books to authenticated;
grant insert (org_id, title, subtitle, author_name, genre, format_key, persona_id, custom_persona_id,
              tone, layout_settings, plan_brief, book_info, step_state, current_step, source, seed_key)
  on publishing.books to authenticated;
grant update (title, subtitle, author_name, genre, format_key, persona_id, custom_persona_id,
              tone, layout_settings, plan_brief, book_info, step_state, current_step, cover_image_id,
              status, deleted_at)
  on publishing.books to authenticated;
drop policy if exists books_select on publishing.books;
create policy books_select on publishing.books for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists books_insert on publishing.books;
create policy books_insert on publishing.books for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists books_update on publishing.books;
create policy books_update on publishing.books for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists books_delete on publishing.books;
create policy books_delete on publishing.books for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));
-- 공개 책 페이지(Phase 2): anon 은 공개 조건을 만족한 행의 공개 컬럼만
grant select (id, slug, title, subtitle, author_name, genre, format_key, book_info, cover_image_id, published_at)
  on publishing.books to anon;
drop policy if exists books_select_public on publishing.books;
create policy books_select_public on publishing.books for select to anon
  using (is_public and status = 'completed' and deleted_at is null and slug is not null);

-- chapters / sections: 편집자 CRUD
grant select, delete on publishing.chapters to authenticated;
grant insert (org_id, book_id, position, title) on publishing.chapters to authenticated;
grant update (position, title) on publishing.chapters to authenticated;
drop policy if exists chapters_select on publishing.chapters;
create policy chapters_select on publishing.chapters for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists chapters_insert on publishing.chapters;
create policy chapters_insert on publishing.chapters for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists chapters_update on publishing.chapters;
create policy chapters_update on publishing.chapters for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists chapters_delete on publishing.chapters;
create policy chapters_delete on publishing.chapters for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']));

grant select, delete on publishing.sections to authenticated;
grant insert (org_id, book_id, chapter_id, position, title, paragraph_target, body_html) on publishing.sections to authenticated;
grant update (position, title, paragraph_target, body_html) on publishing.sections to authenticated;
drop policy if exists sections_select on publishing.sections;
create policy sections_select on publishing.sections for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists sections_insert on publishing.sections;
create policy sections_insert on publishing.sections for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists sections_update on publishing.sections;
create policy sections_update on publishing.sections for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists sections_delete on publishing.sections;
create policy sections_delete on publishing.sections for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']));

-- 서버 전용 테이블: 멤버 SELECT 만
grant select on publishing.cover_images, publishing.manuscript_uploads, publishing.book_exports,
                publishing.generation_runs to authenticated;
drop policy if exists cover_images_select on publishing.cover_images;
create policy cover_images_select on publishing.cover_images for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists manuscript_uploads_select on publishing.manuscript_uploads;
create policy manuscript_uploads_select on publishing.manuscript_uploads for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists book_exports_select on publishing.book_exports;
create policy book_exports_select on publishing.book_exports for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists generation_runs_select on publishing.generation_runs;
create policy generation_runs_select on publishing.generation_runs for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));

-- member_settings: 본인 행
grant select, insert, update on publishing.member_settings to authenticated;
drop policy if exists member_settings_select on publishing.member_settings;
create policy member_settings_select on publishing.member_settings for select to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id));
drop policy if exists member_settings_insert on publishing.member_settings;
create policy member_settings_insert on publishing.member_settings for insert to authenticated
  with check (user_id = auth.uid() and core.is_org_member(org_id) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists member_settings_update on publishing.member_settings;
create policy member_settings_update on publishing.member_settings for update to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id))
  with check (user_id = auth.uid() and core.is_org_member(org_id));

-- 웹훅: owner/admin 만 읽기(URL 노출 최소화). 쓰기는 서버.
grant select on publishing.webhook_endpoints, publishing.webhook_deliveries to authenticated;
drop policy if exists webhook_endpoints_select on publishing.webhook_endpoints;
create policy webhook_endpoints_select on publishing.webhook_endpoints for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'publishing'));
drop policy if exists webhook_deliveries_select on publishing.webhook_deliveries;
create policy webhook_deliveries_select on publishing.webhook_deliveries for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'publishing'));

-- waitlist: 정책 없음(service_role 전용)

-- Realtime: 진행률은 core.jobs 구독이 정본. 섹션 본문 갱신과 실행 단위 진행도 구독한다.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'publishing' and tablename = 'sections') then
      alter publication supabase_realtime add table publishing.sections;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'publishing' and tablename = 'generation_runs') then
      alter publication supabase_realtime add table publishing.generation_runs;
    end if;
  end if;
end $$;

-- =====================================================================
-- 14. 함수 EXECUTE 최종 정리 (0007_core_function_privileges.sql 와 같은 규칙)
--     alter default privileges ... revoke from public 은 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 지우지 않는다.
--     이 스키마의 모든 함수에서 PUBLIC/anon 을 회수하고, 의도한 GRANT 만 다시 준다.
--     트리거 함수는 GRANT 없이도 트리거로 실행된다(EXECUTE 검사는 CREATE TRIGGER 시점).
-- =====================================================================
do $$
declare s text;
begin
  -- 이 조각이 만든 함수 전부(모놀리스 변환 후에도 코어 함수의 기존 GRANT를 건드리지 않도록 목록으로 지정)
  foreach s in array array[
    'publishing.book_plan_limit(uuid,text,integer)', 'publishing.book_plan_flag(uuid,text,boolean)',
    'publishing.book_theme_allowed(uuid,text)', 'publishing.books_before_insert()', 'publishing.books_before_update()',
    'publishing.chapters_before_insert()', 'publishing.sections_before_write()', 'publishing.book_exports_transition()',
    'publishing.generation_runs_transition()', 'publishing.manuscript_uploads_transition()',
    'publishing.member_settings_before_write()', 'publishing.custom_personas_guard_insert()',
    'publishing.request_generation_cancel(uuid)', 'publishing.set_book_visibility(uuid,boolean,text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', s);
  end loop;
end $$;
grant execute on function publishing.book_plan_limit(uuid, text, integer) to authenticated, service_role;
grant execute on function publishing.book_plan_flag(uuid, text, boolean) to authenticated, service_role;
grant execute on function publishing.book_theme_allowed(uuid, text) to authenticated, service_role;
grant execute on function publishing.request_generation_cancel(uuid) to authenticated, service_role;
grant execute on function publishing.set_book_visibility(uuid, boolean, text) to authenticated, service_role;

-- =====================================================================
-- 끝. PostgREST 노출: config.toml [api].schemas 에 publishing 추가.
-- 타입 생성: supabase gen types typescript --local --schema core,publishing
-- =====================================================================
