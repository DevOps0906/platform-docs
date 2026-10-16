-- =====================================================================
-- 0002_trailer_domain.sql  (모놀리스: public 스키마)
-- book-trailer 도메인. 선행: 0001_core_lite.sql
-- 모듈러 조각 docs/products/_supabase-modular/migrations/2600_trailer.sql 을 변환한 것이다.
--   변환 규칙(DB_CONVENTIONS.md 12장): (a) create schema 블록 제거, apps 행은 public 스키마명으로 등록,
--   (b) core. -> public., (c) trailer.<객체> -> public.<객체>(큐 이름·기능 키 같은 문자열은 그대로),
--   (d) 스키마 전체 GRANT/REVOKE 는 도메인 테이블·함수 목록으로 바꾼다(public 의 코어 객체 권한을 건드리지 않는다),
--   (e) 플랜/크레딧팩/AI 라우팅 기본값(@monolith-seed 블록)은 seed.sql 로 이동,
--   (f) FLORA 가져오기(import_flora_book)는 publishing 스키마가 없어 TR010 을 돌려준다.
--   앱 id 'trailer'(core.apps.id, has_entitlement 인자, 잡 큐 이름)는 바꾸지 않는다.
--   두 파일의 본문은 이 변환 외에는 같아야 한다(변환 스크립트로 동기화, 05_DATA_MODEL 8절).
-- 정본 설계: docs/products/book-trailer/05_DATA_MODEL.md
-- SQLSTATE: TR001~TR011, TR409 (모듈러 조각 머리 주석과 같음)
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('trailer', 'NOMAD Book Trailer', 'public', 'open', 'beta')
on conflict (id) do nothing;

-- =====================================================================
-- 1. 헬퍼 함수
-- =====================================================================

-- 현재 사용자가 trailer 엔타이틀먼트가 있는 조직의 활성 멤버인가(카탈로그 읽기 정책용)
create or replace function public.has_trailer_access()
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
      and e.app_id = 'trailer' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  );
$$;

-- 조직의 trailer 플랜 features. 서버 게이팅, 한도 트리거, start_render 가 쓴다. 멤버 또는 service 만.
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
  where e.org_id = p_org_id and e.app_id = 'trailer' and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now());
  return coalesce(v_features, '{}'::jsonb);
end;
$$;

-- 조직의 현재 trailer 플랜 코드(렌더 기록·보존 기간 판정용)
create or replace function public.plan_code(p_org_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.code
  from public.app_entitlements e
  join public.plans p on p.id = e.plan_id
  where e.org_id = p_org_id and e.app_id = 'trailer' and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now())
    and (public.is_service_caller() or public.is_org_member(p_org_id));
$$;

-- features 의 정수 키. 키가 없거나 숫자가 아니면 기본값(무료 플랜 값). -1 은 쓰지 않는다(PRICING_PRINCIPLES 6장 무제한 금지).
create or replace function public.feature_int(p_features jsonb, p_key text, p_default integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_features -> p_key) = 'number' then (p_features ->> p_key)::integer else p_default end;
$$;

create or replace function public.feature_bool(p_features jsonb, p_key text, p_default boolean)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_features -> p_key) = 'boolean' then (p_features ->> p_key)::boolean else p_default end;
$$;

-- features 배열 키에 값이 들어 있는가. 키가 없으면 기본 배열로 판정한다.
create or replace function public.feature_has(p_features jsonb, p_key text, p_value text, p_default text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(p_features -> p_key) = 'array' then (p_features -> p_key) ? p_value
    else p_value = any (p_default)
  end;
$$;

-- 팔레트 검사: 배열 3~6개, 각 원소 {"role": 역할, "hex": "#RRGGBB"}. 역할은 중복 불가.
create or replace function public.valid_palette(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p) = 'array'
     and jsonb_array_length(p) between 3 and 6
     and not exists (
       select 1 from jsonb_array_elements(p) as e(item)
       where jsonb_typeof(e.item) <> 'object'
          or coalesce(e.item ->> 'hex', '') !~ '^#[0-9A-Fa-f]{6}$'
          or coalesce(e.item ->> 'role', '') not in ('background', 'surface', 'text', 'accent', 'accent2', 'muted')
     )
     and (select count(distinct e.item ->> 'role') from jsonb_array_elements(p) as e(item)) = jsonb_array_length(p);
$$;

-- 해시태그 검사: 30개 이하, 각 1~50자, 공백과 # 중복 없음
create or replace function public.valid_hashtags(p text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(cardinality(p), 0) <= 30
     and not exists (select 1 from unnest(p) as u(tag) where u.tag !~ '^#?[^[:space:]#]{1,50}$');
$$;

-- =====================================================================
-- 2. 카탈로그 (플랫폼 소유. 쓰기는 service_role, 읽기는 trailer 사용자)
-- =====================================================================

-- 운영 상수. 사용자 GRANT 없음(서버·함수만 읽는다).
create table if not exists public.runtime_config (
  key        text primary key constraint runtime_config_key_check check (key ~ '^[a-z][a-z0-9_]{2,60}$'),
  value_int  integer not null,
  note       text,
  updated_at timestamptz not null default now()
);

-- 운영 상수 읽기(없으면 기본값)
create or replace function public.config_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.value_int from public.runtime_config c where c.key = p_key), p_default);
$$;

-- 장르 트레일러 문법: 이야기 구조(비트)를 정한다. 스토리보드 그래프가 읽는다(01_PRD TR-F-030, 08_DESIGN_SYSTEM 6장).
create table if not exists public.grammars (
  code             text primary key constraint grammars_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name             text not null constraint grammars_name_check check (char_length(name) between 1 and 60),
  description      text constraint grammars_description_check check (description is null or char_length(description) <= 500),
  book_genres      text[] not null default '{}',
  beats            jsonb not null,           -- [{"key":"hook","label":"훅","share_pct":15,"scene_kinds":["hook_text"]}, ...]
  narration_style  text not null default 'voiceover'
                   constraint grammars_narration_style_check check (narration_style in ('voiceover', 'quote_reading', 'none')),
  music_mood       text constraint grammars_music_mood_check check (music_mood is null or music_mood ~ '^[a-z][a-z0-9_]{1,30}$'),
  status           text not null default 'draft' constraint grammars_status_check check (status in ('draft', 'published', 'retired')),
  version          integer not null default 1 constraint grammars_version_check check (version >= 1),
  sort_order       integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint grammars_beats_check check (
    jsonb_typeof(beats) = 'array' and jsonb_array_length(beats) between 3 and 10
  ),
  constraint grammars_book_genres_check check (
    book_genres <@ array['novel', 'essay', 'poetry', 'self_help', 'nonfiction_business', 'it_tech', 'children', 'fantasy_genre', 'other']::text[]
  )
);

-- 영상 템플릿: Remotion 컴포지션 1개 = 템플릿 1개(02_ARCHITECTURE 1·4장). 포맷별 레이아웃은 컴포지션 안에서 분기한다.
create table if not exists public.templates (
  code            text primary key constraint templates_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name            text not null constraint templates_name_check check (char_length(name) between 1 and 60),
  grammar_code    text not null references public.grammars(code) on delete restrict,
  composition_id  text not null constraint templates_composition_id_check check (composition_id ~ '^[A-Za-z][A-Za-z0-9-]{1,60}$'),
  formats         text[] not null,
  tier            text not null default 'free' constraint templates_tier_check check (tier in ('free', 'premium')),
  params_schema   jsonb not null default '{}'::jsonb,
  preview_path    text,                      -- 버킷 trailer-previews (공개, 작은 미리보기만)
  status          text not null default 'draft' constraint templates_status_check check (status in ('draft', 'published', 'retired')),
  version         integer not null default 1 constraint templates_version_check check (version >= 1),
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint templates_formats_check check (
    cardinality(formats) >= 1
    and formats <@ array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5', 'cover_loop']::text[]
  )
);

-- 라이선스 음악 카탈로그. 라이선스 검증 기록 없이는 공개할 수 없다(toon-factory 리뷰 #6 계열 차단).
create table if not exists public.music_tracks (
  id                     uuid primary key default gen_random_uuid(),
  code                   text not null unique constraint music_tracks_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  title                  text not null constraint music_tracks_title_check check (char_length(title) between 1 and 80),
  mood                   text not null constraint music_tracks_mood_check check (mood ~ '^[a-z][a-z0-9_]{1,30}$'),
  bpm                    integer constraint music_tracks_bpm_check check (bpm is null or bpm between 40 and 220),
  duration_ms            integer not null constraint music_tracks_duration_check check (duration_ms between 5000 and 600000),
  tier                   text not null default 'free' constraint music_tracks_tier_check check (tier in ('free', 'premium')),
  license_source         text not null
                         constraint music_tracks_license_source_check check (license_source in ('in_house', 'commissioned', 'licensed_commercial')),
  license_ref            text not null constraint music_tracks_license_ref_check check (char_length(license_ref) between 3 and 200),
  commercial_use_allowed boolean not null default true,
  license_verified_at    timestamptz,
  license_verified_by    uuid,
  storage_path           text not null,      -- 버킷 trailer-catalog(비공개, 렌더러만)
  preview_path           text,               -- 버킷 trailer-previews(공개 30초 미리듣기)
  status                 text not null default 'draft' constraint music_tracks_status_check check (status in ('draft', 'published', 'retired')),
  sort_order             integer not null default 0,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint music_tracks_publish_license_check
    check (status <> 'published' or (license_verified_at is not null and license_verified_by is not null and commercial_use_allowed))
);

-- =====================================================================
-- 3. 콘텐츠 (조직 소유. 멤버 쓰기 + 플랜 한도 트리거)
-- =====================================================================

create table if not exists public.books (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations(id) on delete cascade,
  title               text not null constraint books_title_check check (char_length(title) between 1 and 200),
  subtitle            text constraint books_subtitle_check check (subtitle is null or char_length(subtitle) <= 200),
  author_name         text constraint books_author_name_check check (author_name is null or char_length(author_name) <= 100),
  publisher_name      text constraint books_publisher_name_check check (publisher_name is null or char_length(publisher_name) <= 100),
  genre               text not null default 'other'
                      constraint books_genre_check check (genre in
                      ('novel', 'essay', 'poetry', 'self_help', 'nonfiction_business', 'it_tech', 'children', 'fantasy_genre', 'other')),
  language            text not null default 'ko' constraint books_language_check check (language in ('ko', 'en', 'ja')),
  isbn                text constraint books_isbn_check check (isbn is null or isbn ~ '^97[89][0-9]{10}$'),
  published_on        date,
  description         text constraint books_description_check check (description is null or char_length(description) <= 2000),
  audience            text constraint books_audience_check check (audience is null or char_length(audience) <= 300),
  source              text not null default 'upload' constraint books_source_check check (source in ('upload', 'paste', 'flora')),
  flora_book_id       uuid,                  -- publishing.books.id (모듈러 전용, FK 없음: 제품 간 결합을 만들지 않는다)
  -- 원고: 버킷 org-files <org_id>/trailer/books/<book_id>/manuscript.<ext>. 원문 텍스트는 DB 에 두지 않는다.
  manuscript_path     text,
  manuscript_sha256   text constraint books_manuscript_sha_check check (manuscript_sha256 is null or manuscript_sha256 ~ '^[0-9a-f]{64}$'),
  manuscript_chars    integer not null default 0 constraint books_manuscript_chars_check check (manuscript_chars >= 0),
  cover_path          text,
  digest_status       text not null default 'none'
                      constraint books_digest_status_check check (digest_status in ('none', 'queued', 'ready', 'failed')),
  rights_ack_version  text constraint books_rights_ack_version_check check (rights_ack_version is null or rights_ack_version ~ '^rights-[0-9]{4}-[0-9]{2}-v[0-9]+$'),
  rights_ack_at       timestamptz,
  rights_ack_by       uuid,
  status              text not null default 'active' constraint books_status_check check (status in ('active', 'archived')),
  created_by          uuid default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint books_id_org_uniq unique (id, org_id),
  -- 경로는 자기 조직 폴더만(경로 조작으로 다른 조직 파일을 가리키지 못한다)
  constraint books_manuscript_path_check check (manuscript_path is null or (
    split_part(manuscript_path, '/', 1) = org_id::text
    and manuscript_path ~ '^[0-9a-f-]{36}/trailer/books/[0-9a-f-]{36}/manuscript\.(pdf|epub|docx|md|txt)$')),
  constraint books_cover_path_check check (cover_path is null or (
    split_part(cover_path, '/', 1) = org_id::text
    and cover_path ~ '^[0-9a-f-]{36}/trailer/books/[0-9a-f-]{36}/cover\.(png|jpg|jpeg|webp)$')),
  constraint books_rights_ack_check check ((rights_ack_version is null) = (rights_ack_at is null)),
  constraint books_flora_source_check check ((source = 'flora') = (flora_book_id is not null))
);
create index if not exists books_org_updated_idx on public.books (org_id, updated_at desc) where deleted_at is null;

create table if not exists public.purchase_links (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  book_id     uuid not null,
  store       text not null constraint purchase_links_store_check check (store in
              ('kyobo', 'yes24', 'aladin', 'ridibooks', 'millie', 'kdp', 'smartstore', 'own_site', 'other')),
  label       text constraint purchase_links_label_check check (label is null or char_length(label) <= 40),
  url         text not null constraint purchase_links_url_check check (url ~* '^https://[^[:space:]]+$' and char_length(url) <= 2000),
  is_affiliate boolean not null default false,
  short_code  text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
              constraint purchase_links_short_code_check check (short_code ~ '^[0-9a-z]{6,16}$'),
  click_count bigint not null default 0,     -- link_clicks 집계 캐시(service 만 갱신)
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint purchase_links_book_fk foreign key (book_id, org_id) references public.books (id, org_id) on delete cascade,
  constraint purchase_links_id_org_uniq unique (id, org_id)
);
create index if not exists purchase_links_book_idx on public.purchase_links (book_id, sort_order);

create table if not exists public.brand_kits (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  book_id       uuid,                        -- null 이면 조직 기본 키트
  name          text not null constraint brand_kits_name_check check (char_length(name) between 1 and 60),
  palette       jsonb not null constraint brand_kits_palette_check check (public.valid_palette(palette)),
  font_display  text not null default 'pretendard'
                constraint brand_kits_font_display_check check (font_display in
                ('pretendard', 'noto_sans_kr', 'noto_serif_kr', 'gowun_batang', 'nanum_myeongjo', 'black_han_sans', 'do_hyeon', 'ibm_plex_sans_kr')),
  font_body     text not null default 'pretendard'
                constraint brand_kits_font_body_check check (font_body in
                ('pretendard', 'noto_sans_kr', 'noto_serif_kr', 'gowun_batang', 'nanum_myeongjo', 'ibm_plex_sans_kr')),
  logo_path     text,
  source        text not null default 'manual' constraint brand_kits_source_check check (source in ('cover_extract', 'manual')),
  created_by    uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint brand_kits_book_fk foreign key (book_id, org_id) references public.books (id, org_id) on delete cascade,
  constraint brand_kits_id_org_uniq unique (id, org_id),
  constraint brand_kits_logo_path_check check (logo_path is null or (
    split_part(logo_path, '/', 1) = org_id::text
    and logo_path ~ '^[0-9a-f-]{36}/trailer/brand/[0-9a-f-]{36}\.(png|webp|svg)$'))
);
create index if not exists brand_kits_org_idx on public.brand_kits (org_id, book_id);

create table if not exists public.trailers (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations(id) on delete cascade,
  book_id             uuid not null,
  title               text not null constraint trailers_title_check check (char_length(title) between 1 and 120),
  grammar_code        text not null references public.grammars(code) on delete restrict,
  template_code       text not null references public.templates(code) on delete restrict,
  brand_kit_id        uuid,
  formats             text[] not null default array['vertical_9_16']::text[],
  duration_s          integer not null default 30 constraint trailers_duration_check check (duration_s in (15, 30, 45, 60, 90)),
  language            text not null default 'ko' constraint trailers_language_check check (language in ('ko', 'en', 'ja')),
  spoiler_level       text not null default 'teaser' constraint trailers_spoiler_check check (spoiler_level in ('none', 'teaser', 'light')),
  narration_mode      text not null default 'voiceover' constraint trailers_narration_mode_check check (narration_mode in ('voiceover', 'none')),
  voice_pref          text not null default 'auto' constraint trailers_voice_pref_check check (voice_pref in ('auto', 'elevenlabs', 'oss-voice')),
  -- 같은 목소리 규칙: 첫 내레이션이 끝날 때 서버가 고정한다({"provider":..., "voice_id":..., "fixed_at":...}). 사용자 쓰기 불가.
  voice               jsonb not null default '{}'::jsonb,
  music_track_id      uuid references public.music_tracks(id) on delete set null,
  music_path          text,                  -- 사용자 업로드 음악: 버킷 org-files <org_id>/trailer/music/<uuid>.(mp3|wav)
  music_rights_ack    boolean not null default false,
  music_rights_ack_at timestamptz,
  music_rights_ack_by uuid,
  current_brief_id    uuid,
  selected_hook       smallint constraint trailers_selected_hook_check check (selected_hook is null or selected_hook between 0 and 4),
  storyboard_version  integer not null default 0,
  status              text not null default 'active' constraint trailers_status_check check (status in ('active', 'approved', 'archived')),
  created_by          uuid default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint trailers_book_fk foreign key (book_id, org_id) references public.books (id, org_id) on delete cascade,
  constraint trailers_brand_kit_fk foreign key (brand_kit_id, org_id) references public.brand_kits (id, org_id) on delete set null (brand_kit_id),
  constraint trailers_id_org_uniq unique (id, org_id),
  constraint trailers_formats_check check (
    cardinality(formats) between 1 and 5
    and formats <@ array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5', 'cover_loop']::text[]
  ),
  constraint trailers_music_choice_check check (music_track_id is null or music_path is null),
  constraint trailers_music_path_check check (music_path is null or (
    split_part(music_path, '/', 1) = org_id::text
    and music_path ~ '^[0-9a-f-]{36}/trailer/music/[0-9a-f-]{36}\.(mp3|wav)$')),
  constraint trailers_voice_shape_check check (jsonb_typeof(voice) = 'object')
);
create index if not exists trailers_org_updated_idx on public.trailers (org_id, updated_at desc);
create index if not exists trailers_book_idx on public.trailers (book_id);

-- 브리프: 불변 버전. AI 버전은 service 가, 사용자 편집본은 멤버가 새 행(source='manual')으로 만든다.
create table if not exists public.briefs (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  trailer_id  uuid not null,
  version     integer not null default 0,   -- 트리거가 트레일러별 max+1 로 채운다
  source      text not null constraint briefs_source_check check (source in ('ai', 'manual')),
  -- {"logline":..., "hooks":[{"text":...}], "quotes":[{"text":..., "chapter":n, "start":i, "end":j, "verified":bool}],
  --  "audience":..., "mood":..., "keywords":[...], "themes":[...], "spoiler_notes":[...]} (04_API 4절)
  content     jsonb not null,
  ai_run_id   uuid,
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now(),
  constraint briefs_trailer_fk foreign key (trailer_id, org_id) references public.trailers (id, org_id) on delete cascade,
  constraint briefs_id_org_uniq unique (id, org_id),
  constraint briefs_trailer_version_uniq unique (trailer_id, version),
  constraint briefs_content_shape_check check (jsonb_typeof(content) = 'object' and pg_column_size(content) <= 65536),
  constraint briefs_ai_run_check check (source = 'ai' or ai_run_id is null)
);

-- current_brief_id 는 같은 조직의 브리프만(브리프가 지워지면 null)
alter table public.trailers drop constraint if exists trailers_current_brief_fk;
alter table public.trailers add constraint trailers_current_brief_fk
  foreign key (current_brief_id, org_id) references public.briefs (id, org_id) on delete set null (current_brief_id);

-- 장면(스토리보드). 엔드카드는 트리거가 만들고 사용자가 만들거나 지울 수 없다.
create table if not exists public.scenes (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  trailer_id     uuid not null,
  position       integer not null constraint scenes_position_check check (position between 0 and 39),
  kind           text not null constraint scenes_kind_check check (kind in
                 ('title_card', 'hook_text', 'quote_card', 'image_scene', 'character_scene', 'narration_card', 'cta_card', 'end_card')),
  duration_ms    integer not null default 3000 constraint scenes_duration_check check (duration_ms between 500 and 15000),
  text           text constraint scenes_text_check check (text is null or char_length(text) <= 160),
  narration      text constraint scenes_narration_check check (narration is null or char_length(narration) <= 400),
  -- 인용 위치: {"chapter": n, "start": i, "end": j}. quote_verified 는 원고 대조(apps/api)가 맞을 때 service 만 true 로 쓴다.
  quote_ref      jsonb,
  quote_verified boolean not null default false,
  -- {"prompt":..., "style":..., "motion":"ken_burns_in", "focus":"center"} (08_DESIGN_SYSTEM 7장 모션 프리셋)
  visual         jsonb not null default '{}'::jsonb,
  music_cue      text constraint scenes_music_cue_check check (music_cue is null or music_cue in ('intro', 'build', 'drop', 'calm', 'outro')),
  revision       integer not null default 1,
  created_by     uuid default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint scenes_trailer_fk foreign key (trailer_id, org_id) references public.trailers (id, org_id) on delete cascade,
  constraint scenes_id_org_uniq unique (id, org_id),
  constraint scenes_trailer_position_uniq unique (trailer_id, position) deferrable initially deferred,
  constraint scenes_visual_shape_check check (jsonb_typeof(visual) = 'object' and pg_column_size(visual) <= 16384),
  constraint scenes_quote_ref_check check (quote_ref is null or jsonb_typeof(quote_ref) = 'object'),
  constraint scenes_quote_verified_check check (not quote_verified or (kind = 'quote_card' and quote_ref is not null))
);
create unique index if not exists scenes_one_end_card_idx on public.scenes (trailer_id) where kind = 'end_card';
create index if not exists scenes_trailer_idx on public.scenes (trailer_id, position);

-- 플랫폼별 메타데이터 팩(제목·설명·해시태그·구매 링크). 제휴 링크가 있으면 대가성 문구가 설명 첫 줄이어야 한다.
create table if not exists public.metadata_packs (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  trailer_id    uuid not null,
  platform      text not null constraint metadata_packs_platform_check check (platform in
                ('youtube_shorts', 'youtube', 'instagram', 'tiktok', 'naver_clip', 'bookstore', 'generic')),
  title         text not null constraint metadata_packs_title_check check (char_length(title) between 1 and 100),
  description   text not null default '' constraint metadata_packs_description_check check (char_length(description) <= 5000),
  hashtags      text[] not null default '{}' constraint metadata_packs_hashtags_check check (public.valid_hashtags(hashtags)),
  link_ids      uuid[] not null default '{}' constraint metadata_packs_link_ids_check check (cardinality(link_ids) <= 10),
  has_affiliate boolean not null default false,   -- 트리거가 link_ids 로 계산(사용자 입력 무시)
  disclosure    text,                              -- 트리거가 넣는 대가성 문구
  source        text not null default 'manual' constraint metadata_packs_source_check check (source in ('ai', 'manual')),
  created_by    uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint metadata_packs_trailer_fk foreign key (trailer_id, org_id) references public.trailers (id, org_id) on delete cascade,
  constraint metadata_packs_trailer_platform_uniq unique (trailer_id, platform),
  constraint metadata_packs_disclosure_check check (
    not has_affiliate or (disclosure is not null and char_length(disclosure) >= 10 and left(description, char_length(disclosure)) = disclosure)
  )
);

-- =====================================================================
-- 4. 서버 기록 (쓰기는 service_role 만)
-- =====================================================================

-- 원고 분석 결과(책당 최신 1행). 원고 해시가 같으면 다시 분석하지 않는다(크레딧 1회).
create table if not exists public.book_digests (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations(id) on delete cascade,
  book_id           uuid not null,
  manuscript_sha256 text not null constraint book_digests_sha_check check (manuscript_sha256 ~ '^[0-9a-f]{64}$'),
  chapters          jsonb not null,          -- [{"n":1,"title":...,"chars":..,"summary":...,"key_passages":[{"start":i,"end":j}]}]
  characters        jsonb not null default '[]'::jsonb,
  themes            jsonb not null default '[]'::jsonb,
  settings          jsonb not null default '[]'::jsonb,
  ai_run_id         uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint book_digests_book_fk foreign key (book_id, org_id) references public.books (id, org_id) on delete cascade,
  constraint book_digests_book_uniq unique (book_id),
  constraint book_digests_chapters_check check (jsonb_typeof(chapters) = 'array' and jsonb_array_length(chapters) between 1 and 300),
  constraint book_digests_size_check check (pg_column_size(chapters) + pg_column_size(characters) + pg_column_size(themes) <= 524288)
);

create table if not exists public.link_clicks (
  id          bigint generated always as identity primary key,
  link_id     uuid not null references public.purchase_links(id) on delete cascade,
  org_id      uuid not null references public.organizations(id) on delete cascade,
  clicked_at  timestamptz not null default now(),
  referrer    text constraint link_clicks_referrer_check check (referrer is null or char_length(referrer) <= 500),
  ip_hash     text constraint link_clicks_ip_hash_check check (ip_hash is null or ip_hash ~ '^[0-9a-f]{64}$'),
  user_agent  text constraint link_clicks_ua_check check (user_agent is null or char_length(user_agent) <= 300),
  tag         text constraint link_clicks_tag_check check (tag is null or tag ~ '^[a-z0-9_:-]{1,80}$')
);
create index if not exists link_clicks_link_idx on public.link_clicks (link_id, clicked_at desc);
create index if not exists link_clicks_org_idx on public.link_clicks (org_id, clicked_at desc);

-- 장면 에셋: 이미지(AI 또는 사용자 업로드), 내레이션 오디오. 장면·슬롯(visual/audio)마다 ready 는 1개.
create table if not exists public.scene_assets (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  scene_id      uuid not null,
  kind          text not null constraint scene_assets_kind_check check (kind in ('image', 'user_image', 'narration')),
  slot          text generated always as (case when kind = 'narration' then 'audio' else 'visual' end) stored,
  status        text not null default 'ready' constraint scene_assets_status_check check (status in ('ready', 'superseded')),
  source        text not null constraint scene_assets_source_check check (source in ('ai_generated', 'upload')),
  ai_generated  boolean not null,
  provider      text,
  model         text,
  seed          bigint,
  voice_id      text,
  storage_path  text not null,             -- 버킷 trailer-media <org_id>/trailer/assets/<scene_id>/<uuid>.(png|webp|jpg|mp3|wav)
  width         integer,
  height        integer,
  duration_ms   integer constraint scene_assets_duration_check check (duration_ms is null or duration_ms between 100 and 60000),
  chars         integer constraint scene_assets_chars_check check (chars is null or chars >= 0),
  bytes         bigint not null default 0,
  rights_ack    boolean not null default false,
  run_id        uuid,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  constraint scene_assets_scene_fk foreign key (scene_id, org_id) references public.scenes (id, org_id) on delete cascade,
  -- AI 생성 표시 무결성: 출처와 플래그가 어긋날 수 없다
  constraint scene_assets_ai_source_check check ((source = 'ai_generated') = ai_generated),
  constraint scene_assets_ai_model_check check (not ai_generated or (provider is not null and model is not null)),
  constraint scene_assets_kind_source_check check ((kind = 'user_image') = (source = 'upload')),
  constraint scene_assets_upload_rights_check check (source <> 'upload' or rights_ack),
  constraint scene_assets_path_check check (
    split_part(storage_path, '/', 1) = org_id::text
    and storage_path ~ '^[0-9a-f-]{36}/trailer/assets/[0-9a-f-]{36}/[0-9a-f-]{36}\.(png|webp|jpg|mp3|wav)$')
);
create unique index if not exists scene_assets_one_ready_idx on public.scene_assets (scene_id, slot) where status = 'ready';
create index if not exists scene_assets_org_idx on public.scene_assets (org_id, created_at desc);

-- AI 실행(원고 분석, 브리프, 스토리보드, 장면 이미지, 내레이션, 메타데이터). 크레딧 원장·잡과 1:1.
create table if not exists public.generation_runs (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations(id) on delete cascade,
  kind              text not null constraint generation_runs_kind_check check (kind in
                    ('digest', 'brief', 'storyboard', 'scene_image', 'narration', 'meta')),
  book_id           uuid not null references public.books(id) on delete cascade,
  trailer_id        uuid references public.trailers(id) on delete cascade,
  scene_id          uuid references public.scenes(id) on delete cascade,
  status            text not null default 'queued'
                    constraint generation_runs_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  credits_reserved  integer not null default 0 constraint generation_runs_credits_check check (credits_reserved >= 0),
  credit_ledger_id  bigint references public.credit_ledger(id),
  idempotency_key   text not null unique,
  job_id            uuid references public.jobs(id) on delete set null,
  ai_run_id         uuid,
  payload           jsonb not null default '{}'::jsonb,
  progress          jsonb not null default '{}'::jsonb,
  error             text,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  started_at        timestamptz,
  finished_at       timestamptz,
  constraint generation_runs_target_check check (
    (kind = 'digest' and trailer_id is null and scene_id is null)
    or (kind in ('brief', 'storyboard', 'meta') and trailer_id is not null and scene_id is null)
    or (kind in ('scene_image', 'narration') and trailer_id is not null and scene_id is not null)
  )
);
create index if not exists generation_runs_org_created_idx on public.generation_runs (org_id, created_at desc);
create index if not exists generation_runs_active_idx on public.generation_runs (org_id, status) where status in ('queued', 'running');
create index if not exists generation_runs_job_idx on public.generation_runs (job_id) where job_id is not null;

-- 영상 렌더. 워터마크·AI 표시·플랜은 서버가 결정하고 사용자 입력을 받지 않는다(toon-factory 리뷰 #1 차단).
create table if not exists public.renders (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations(id) on delete cascade,
  trailer_id       uuid not null,
  format           text not null constraint renders_format_check check (format in
                   ('vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5', 'cover_loop')),
  resolution       text not null constraint renders_resolution_check check (resolution in ('480p', '720p', '1080p')),
  status           text not null default 'queued'
                   constraint renders_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  plan_code        text not null,
  watermark        boolean not null,
  ai_label         boolean not null,
  snapshot         jsonb not null,           -- 렌더 시점 장면·에셋·브랜드 키트·템플릿·책 정보(재현 가능)
  credits          integer not null default 0 constraint renders_credits_check check (credits >= 0),
  credit_ledger_id bigint references public.credit_ledger(id),
  job_id           uuid references public.jobs(id) on delete set null,
  request_id       uuid not null unique,
  output_path      text,                     -- 버킷 exports <org_id>/trailer/renders/<render_id>/trailer.mp4
  poster_path      text,
  srt_path         text,
  bytes            bigint,
  duration_ms      integer,
  error            text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  started_at       timestamptz,
  finished_at      timestamptz,
  expires_at       timestamptz,
  constraint renders_trailer_fk foreign key (trailer_id, org_id) references public.trailers (id, org_id) on delete cascade,
  constraint renders_ai_label_check check (ai_label or not coalesce((snapshot ->> 'has_ai_assets')::boolean, true)),
  constraint renders_preview_watermark_check check (resolution <> '480p' or watermark),
  constraint renders_output_check check (status <> 'succeeded' or output_path is not null)
);
create index if not exists renders_trailer_idx on public.renders (trailer_id, created_at desc);
create index if not exists renders_active_idx on public.renders (org_id, status) where status in ('queued', 'running');
create index if not exists renders_job_idx on public.renders (job_id) where job_id is not null;
create index if not exists renders_expiry_idx on public.renders (expires_at) where status = 'succeeded';

-- 외부 승인 링크(P1, publisher 플랜). 토큰 원문은 저장하지 않는다(sha256 만).
create table if not exists public.reviews (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  trailer_id      uuid not null,
  render_ids      uuid[] not null constraint reviews_render_ids_check check (cardinality(render_ids) between 1 and 5),
  token_sha256    text not null unique constraint reviews_token_check check (token_sha256 ~ '^[0-9a-f]{64}$'),
  reviewer_label  text not null constraint reviews_label_check check (char_length(reviewer_label) between 1 and 60),
  status          text not null default 'pending'
                  constraint reviews_status_check check (status in ('pending', 'approved', 'changes_requested', 'expired', 'revoked')),
  expires_at      timestamptz not null,
  decided_at      timestamptz,
  comment         text constraint reviews_comment_check check (comment is null or char_length(comment) <= 1000),
  created_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint reviews_trailer_fk foreign key (trailer_id, org_id) references public.trailers (id, org_id) on delete cascade
);
create index if not exists reviews_trailer_idx on public.reviews (trailer_id, created_at desc);

-- =====================================================================
-- 5. 트리거
-- =====================================================================

-- 5-1. updated_at
do $$
declare t text;
begin
  foreach t in array array['runtime_config', 'grammars', 'templates', 'music_tracks', 'books', 'purchase_links', 'brand_kits',
                           'trailers', 'scenes', 'metadata_packs', 'book_digests', 'generation_runs', 'renders', 'reviews'] loop
    execute format('drop trigger if exists %1$s_set_updated_at on public.%1$I', t);
    execute format('create trigger %1$s_set_updated_at before update on public.%1$I for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- 5-2. 이중 잠금: 서버 기록과 카탈로그는 사용자 세션 쓰기를 42501로 거부
do $$
declare t text;
begin
  foreach t in array array['runtime_config', 'grammars', 'templates', 'music_tracks', 'book_digests', 'link_clicks',
                           'scene_assets', 'generation_runs', 'renders', 'reviews'] loop
    execute format('drop trigger if exists %1$s_guard_write on public.%1$I', t);
    execute format('create trigger %1$s_guard_write before insert or update or delete on public.%1$I for each row execute function public.guard_privileged_write()', t);
  end loop;
end $$;

-- 5-3. 플랜 한도(책 수, 책당 트레일러 수, 브랜드 키트 수, 책당 구매 링크 수). 사용자 INSERT 에만 적용.
--      기본값은 무료 플랜 값(01_PRD 4장).
create or replace function public.enforce_plan_limits()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_features jsonb;
  v_limit    integer;
  v_count    integer;
begin
  if public.is_service_caller() then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('trailer:limits:' || new.org_id::text));
  v_features := public.plan_features(new.org_id);

  if tg_table_name = 'books' then
    v_limit := public.feature_int(v_features, 'max_books', 1);
    select count(*) into v_count from public.books b where b.org_id = new.org_id and b.deleted_at is null;
  elsif tg_table_name = 'trailers' then
    v_limit := public.feature_int(v_features, 'max_trailers_per_book', 1);
    select count(*) into v_count from public.trailers t where t.book_id = new.book_id;
  elsif tg_table_name = 'brand_kits' then
    v_limit := public.feature_int(v_features, 'brand_kits_max', 1);
    select count(*) into v_count from public.brand_kits k where k.org_id = new.org_id;
  elsif tg_table_name = 'purchase_links' then
    v_limit := 10;   -- 플랜과 무관한 고정 상한(엔드카드·설명란에 다 담을 수 없다)
    select count(*) into v_count from public.purchase_links l where l.book_id = new.book_id;
  else
    return new;
  end if;

  if v_count >= v_limit then
    raise exception 'trailer: plan limit reached on % (limit %)', tg_table_name, v_limit using errcode = 'TR005';
  end if;
  return new;
end;
$$;

drop trigger if exists books_plan_limits on public.books;
create trigger books_plan_limits before insert on public.books for each row execute function public.enforce_plan_limits();
drop trigger if exists trailers_plan_limits on public.trailers;
create trigger trailers_plan_limits before insert on public.trailers for each row execute function public.enforce_plan_limits();
drop trigger if exists brand_kits_plan_limits on public.brand_kits;
create trigger brand_kits_plan_limits before insert on public.brand_kits for each row execute function public.enforce_plan_limits();
drop trigger if exists purchase_links_plan_limits on public.purchase_links;
create trigger purchase_links_plan_limits before insert on public.purchase_links for each row execute function public.enforce_plan_limits();

-- 5-4. books: 원고가 바뀌면 분석 상태를 되돌린다. 사용자가 서버 컬럼을 바꾸면 이전 값으로 되돌린다(컬럼 GRANT 와 이중).
--      컬럼 보호 트리거의 서버 판정은 public.is_privileged_session()(service_role 또는 DEFINER RPC 안)이다.
--      사용자 RPC(acknowledge_rights)가 DEFINER 로 서버 컬럼을 쓸 수 있어야 하기 때문이다. 사용자 직접 UPDATE 는 current_user 가
--      authenticated 라 거짓이 된다(guard_privileged_write 와 같은 기준).
create or replace function public.books_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not public.is_privileged_session() then
    new.manuscript_sha256  := old.manuscript_sha256;
    new.manuscript_chars   := old.manuscript_chars;
    new.digest_status      := old.digest_status;
    new.rights_ack_version := old.rights_ack_version;
    new.rights_ack_at      := old.rights_ack_at;
    new.rights_ack_by      := old.rights_ack_by;
    new.source             := old.source;
    new.flora_book_id      := old.flora_book_id;
    new.org_id             := old.org_id;
  end if;
  if new.manuscript_path is distinct from old.manuscript_path and not public.is_privileged_session() then
    new.manuscript_sha256 := null;
    new.manuscript_chars  := 0;
    new.digest_status     := 'none';
  end if;
  return new;
end;
$$;
drop trigger if exists books_before_update on public.books;
create trigger books_before_update before update on public.books for each row execute function public.books_before_update();

-- 5-5. trailers: 승인 상태는 성공 렌더가 있어야 한다. 음악 권리 확인 기록. 서버 컬럼 보호.
create or replace function public.trailers_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_privileged_session() then
      new.voice := '{}'::jsonb;
      new.storyboard_version := 0;
      new.current_brief_id := null;
      new.status := 'active';
    end if;
  else
    if not public.is_privileged_session() then
      new.voice := old.voice;
      new.storyboard_version := old.storyboard_version;
      new.org_id := old.org_id;
      new.book_id := old.book_id;
    end if;
    if new.status = 'approved' and old.status <> 'approved'
       and not exists (select 1 from public.renders r where r.trailer_id = new.id and r.status = 'succeeded' and r.resolution <> '480p') then
      raise exception 'trailer: approve requires a finished render' using errcode = 'TR004';
    end if;
  end if;
  -- 음악: 업로드 경로가 바뀌면 권리 확인을 다시 받는다. 확인 시각과 사람은 서버가 기록한다.
  if tg_op = 'UPDATE' and new.music_path is distinct from old.music_path then
    new.music_rights_ack := false;
  end if;
  if new.music_rights_ack and (tg_op = 'INSERT' or not old.music_rights_ack) then
    new.music_rights_ack_at := now();
    new.music_rights_ack_by := auth.uid();
  elsif not new.music_rights_ack then
    new.music_rights_ack_at := null;
    new.music_rights_ack_by := null;
  elsif tg_op = 'UPDATE' then
    new.music_rights_ack_at := old.music_rights_ack_at;
    new.music_rights_ack_by := old.music_rights_ack_by;
  end if;
  return new;
end;
$$;
drop trigger if exists trailers_before_write on public.trailers;
create trigger trailers_before_write before insert or update on public.trailers for each row execute function public.trailers_before_write();

-- 5-6. 트레일러를 만들면 엔드카드 장면 1개를 만든다(사용자 정책으로는 만들 수 없어 DEFINER).
create or replace function public.create_end_card()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.scenes (org_id, trailer_id, position, kind, duration_ms, text, created_by)
  values (new.org_id, new.id, 0, 'end_card', 4000, null, new.created_by);
  return new;
end;
$$;
drop trigger if exists trailers_create_end_card on public.trailers;
create trigger trailers_create_end_card after insert on public.trailers for each row execute function public.create_end_card();

-- 5-7. scenes: revision 증가, 인용 검증 초기화, 엔드카드 보호(종류 변경·삭제 금지)
create or replace function public.scenes_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    -- 부모 트레일러가 지워지는 중(cascade)이면 허용한다. 그 외 엔드카드 삭제는 service 도 막는다.
    if old.kind = 'end_card' and exists (select 1 from public.trailers t where t.id = old.trailer_id) then
      raise exception 'trailer: end card cannot be deleted' using errcode = 'TR007';
    end if;
    return old;
  end if;
  if tg_op = 'INSERT' then
    if not public.is_privileged_session() then
      new.quote_verified := false;
      new.revision := 1;
    end if;
    return new;
  end if;
  if new.kind is distinct from old.kind and (old.kind = 'end_card' or new.kind = 'end_card') then
    raise exception 'trailer: end card kind is fixed' using errcode = 'TR007';
  end if;
  if not public.is_privileged_session() then
    new.org_id := old.org_id;
    new.trailer_id := old.trailer_id;
    new.quote_verified := old.quote_verified;
    new.quote_ref := old.quote_ref;
    -- 사용자가 인용 문장을 고치면 원고 대조가 깨진다
    if new.kind = 'quote_card' and new.text is distinct from old.text then
      new.quote_verified := false;
    end if;
  end if;
  if (new.text, new.narration, new.duration_ms, new.visual, new.position, new.kind, new.music_cue)
     is distinct from (old.text, old.narration, old.duration_ms, old.visual, old.position, old.kind, old.music_cue) then
    new.revision := old.revision + 1;
  else
    new.revision := old.revision;
  end if;
  return new;
end;
$$;
drop trigger if exists scenes_before_write on public.scenes;
create trigger scenes_before_write before insert or update or delete on public.scenes for each row execute function public.scenes_before_write();

-- 5-8. briefs: 버전 번호 부여(트레일러별 max+1). 사용자 행은 source='manual' 만(정책과 이중).
create or replace function public.briefs_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('trailer:brief:' || new.trailer_id::text));
  select coalesce(max(b.version), 0) + 1 into new.version from public.briefs b where b.trailer_id = new.trailer_id;
  if not public.is_privileged_session() then
    new.source := 'manual';
    new.ai_run_id := null;
  end if;
  return new;
end;
$$;
drop trigger if exists briefs_before_insert on public.briefs;
create trigger briefs_before_insert before insert on public.briefs for each row execute function public.briefs_before_insert();

-- 5-9. metadata_packs: 링크는 같은 조직·같은 책만. 제휴 링크가 있으면 대가성 문구를 설명 첫 줄에 넣는다.
create or replace function public.metadata_packs_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_book    uuid;
  v_bad     integer;
  v_default constant text := '이 설명에는 제휴 링크가 포함되어 있으며, 링크를 통한 구매 시 일정액의 수수료를 받을 수 있습니다.';
begin
  if tg_op = 'UPDATE' and not public.is_privileged_session() then
    new.org_id := old.org_id;
    new.trailer_id := old.trailer_id;
    new.source := old.source;
  end if;
  select t.book_id into v_book from public.trailers t where t.id = new.trailer_id and t.org_id = new.org_id;
  select count(*) into v_bad
  from unnest(new.link_ids) as u(link_id)
  where not exists (select 1 from public.purchase_links l
                    where l.id = u.link_id and l.org_id = new.org_id and l.book_id = v_book);
  if v_bad > 0 then
    raise exception 'metadata_packs: link does not belong to this book' using errcode = '23503';
  end if;
  new.has_affiliate := exists (select 1 from public.purchase_links l where l.id = any (new.link_ids) and l.is_affiliate);
  if new.has_affiliate then
    new.disclosure := coalesce(nullif(btrim(new.disclosure), ''), v_default);
    if left(new.description, char_length(new.disclosure)) <> new.disclosure then
      new.description := new.disclosure || E'\n' || new.description;
    end if;
    if char_length(new.description) > 5000 then
      raise exception 'metadata_packs: description too long after disclosure' using errcode = 'TR008';
    end if;
  else
    new.disclosure := null;
  end if;
  return new;
end;
$$;
drop trigger if exists metadata_packs_before_write on public.metadata_packs;
create trigger metadata_packs_before_write before insert or update on public.metadata_packs
  for each row execute function public.metadata_packs_before_write();

-- 5-10. 실행 상태 전이(generation_runs, renders, reviews 는 아래 별도). service_role 쓰기에도 적용된다.
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
      raise exception 'trailer: % must start as queued', tg_table_name using errcode = 'TR001';
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
    raise exception 'trailer: invalid % status transition % -> %', tg_table_name, old.status, new.status using errcode = 'TR001';
  end if;
  if new.status = 'running' then
    new.started_at := coalesce(new.started_at, now());
  end if;
  if new.status in ('succeeded', 'failed', 'canceled') then
    new.finished_at := coalesce(new.finished_at, now());
  end if;
  return new;
end;
$$;
drop trigger if exists generation_runs_status_transition on public.generation_runs;
create trigger generation_runs_status_transition before insert or update on public.generation_runs
  for each row execute function public.enforce_run_status_transition();
drop trigger if exists renders_status_transition on public.renders;
create trigger renders_status_transition before insert or update on public.renders
  for each row execute function public.enforce_run_status_transition();

-- 5-11. reviews 상태 전이: pending → approved | changes_requested | expired | revoked (종료 상태에서 바꾸지 않는다)
create or replace function public.enforce_review_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' then
      raise exception 'reviews: must start as pending' using errcode = 'TR001';
    end if;
    return new;
  end if;
  if new.status <> old.status then
    if old.status <> 'pending' then
      raise exception 'reviews: invalid transition % -> %', old.status, new.status using errcode = 'TR001';
    end if;
    if new.status in ('approved', 'changes_requested') then
      new.decided_at := now();
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists reviews_status_transition on public.reviews;
create trigger reviews_status_transition before insert or update on public.reviews
  for each row execute function public.enforce_review_transition();

-- =====================================================================
-- 6. 사용자 RPC (authenticated)
-- =====================================================================

-- 6-1. 권리 확인(원고·표지·인용·책 정보를 트레일러에 쓸 권리가 있음을 확인). 생성·렌더의 전제(TR003).
create or replace function public.acknowledge_rights(p_book_id uuid, p_version text)
returns public.books
language plpgsql
security definer
set search_path = ''
as $$
declare v_book public.books;
begin
  select * into v_book from public.books b where b.id = p_book_id and b.deleted_at is null for update;
  if not found then
    raise exception 'acknowledge_rights: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_book.org_id, array['owner', 'admin', 'member']) then
    raise exception 'acknowledge_rights: not a member' using errcode = '42501';
  end if;
  if not public.has_entitlement(v_book.org_id, 'trailer') then
    raise exception 'acknowledge_rights: no entitlement' using errcode = '42501';
  end if;
  if p_version is null or p_version !~ '^rights-[0-9]{4}-[0-9]{2}-v[0-9]+$' then
    raise exception 'acknowledge_rights: invalid notice version' using errcode = '22023';
  end if;
  update public.books
     set rights_ack_version = p_version, rights_ack_at = now(), rights_ack_by = auth.uid()
   where id = p_book_id
  returning * into v_book;
  perform public.write_audit(v_book.org_id, 'book.rights_ack', 'book', p_book_id::text, null,
                           jsonb_build_object('version', p_version));
  return v_book;
end;
$$;

-- 6-2. 장면 저장(낙관적 동시성). SECURITY INVOKER: RLS 와 컬럼 GRANT 가 그대로 적용된다.
--      p_patch 키: text, narration, duration_ms, visual, music_cue (없는 키는 그대로)
create or replace function public.save_scene(p_scene_id uuid, p_patch jsonb, p_expected_revision integer)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare v_rev integer;
begin
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'save_scene: patch must be an object' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_object_keys(p_patch) as k(key)
             where k.key not in ('text', 'narration', 'duration_ms', 'visual', 'music_cue')) then
    raise exception 'save_scene: unknown key in patch' using errcode = '22023';
  end if;
  update public.scenes s
     set text        = case when p_patch ? 'text' then p_patch ->> 'text' else s.text end,
         narration   = case when p_patch ? 'narration' then p_patch ->> 'narration' else s.narration end,
         duration_ms = case when p_patch ? 'duration_ms' then (p_patch ->> 'duration_ms')::integer else s.duration_ms end,
         visual      = case when p_patch ? 'visual' then p_patch -> 'visual' else s.visual end,
         music_cue   = case when p_patch ? 'music_cue' then p_patch ->> 'music_cue' else s.music_cue end
   where s.id = p_scene_id and s.revision = p_expected_revision
  returning s.revision into v_rev;
  if v_rev is null then
    if exists (select 1 from public.scenes s where s.id = p_scene_id) then
      raise exception 'save_scene: revision conflict' using errcode = 'TR409';
    end if;
    raise exception 'save_scene: not found' using errcode = 'P0002';
  end if;
  return v_rev;
end;
$$;

-- 6-3. 장면 순서 변경. 트레일러의 장면 id 전부를 새 순서로 받는다. 엔드카드는 마지막이어야 한다. SECURITY INVOKER.
create or replace function public.reorder_scenes(p_trailer_id uuid, p_scene_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
  v_end   uuid;
begin
  select count(*) into v_count from public.scenes s where s.trailer_id = p_trailer_id;
  if v_count = 0 then
    raise exception 'reorder_scenes: trailer not found or empty' using errcode = 'P0002';
  end if;
  if coalesce(cardinality(p_scene_ids), 0) <> v_count
     or (select count(distinct x) from unnest(p_scene_ids) as u(x)) <> v_count
     or exists (select 1 from unnest(p_scene_ids) as u(x)
                where not exists (select 1 from public.scenes s where s.id = u.x and s.trailer_id = p_trailer_id)) then
    raise exception 'reorder_scenes: id list does not match the trailer scenes' using errcode = '22023';
  end if;
  select s.id into v_end from public.scenes s where s.trailer_id = p_trailer_id and s.kind = 'end_card';
  if v_end is not null and p_scene_ids[v_count] <> v_end then
    raise exception 'reorder_scenes: end card must be last' using errcode = 'TR007';
  end if;
  update public.scenes s
     set position = o.ord - 1
    from unnest(p_scene_ids) with ordinality as o(id, ord)
   where s.id = o.id and s.trailer_id = p_trailer_id;
end;
$$;

-- =====================================================================
-- 7. 서버 RPC (service_role 전용): 실행 시작·종료, 렌더 시작·종료, 링크 클릭, 승인 링크, FLORA 가져오기
-- =====================================================================

-- 7-1. 잡만 끝난 실행 정리(public.cancel_job, 잡 정리기, fail_job 뒤). 상태가 남아 영구 차단(TR002)되는 것을 막는다.
create or replace function public.reconcile_runs(p_org_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_n integer;
begin
  if not public.is_privileged_session() then
    raise exception 'reconcile_runs: service_role only' using errcode = '42501';
  end if;
  with dead as (
    update public.generation_runs r
       set status = case when j.status = 'canceled' and r.status = 'queued' then 'canceled' else 'failed' end,
           error = coalesce(r.error, 'job ' || j.status)
      from public.jobs j
     where r.org_id = p_org_id and r.job_id = j.id and r.status in ('queued', 'running')
       and j.status in ('failed', 'canceled')
    returning r.kind, r.book_id
  )
  select count(*) into v_n from dead;
  update public.books b set digest_status = 'failed'
   where b.org_id = p_org_id and b.digest_status = 'queued'
     and not exists (select 1 from public.generation_runs r
                     where r.book_id = b.id and r.kind = 'digest' and r.status in ('queued', 'running'));
  update public.renders x
     set status = case when j.status = 'canceled' and x.status = 'queued' then 'canceled' else 'failed' end,
         error = coalesce(x.error, 'job ' || j.status)
    from public.jobs j
   where x.org_id = p_org_id and x.job_id = j.id and x.status in ('queued', 'running')
     and j.status in ('failed', 'canceled');
  return v_n;
end;
$$;

-- 7-2. AI 실행 시작: 검사 → 크레딧 선차감 → 실행 행 → 잡 enqueue 를 한 트랜잭션으로.
--      크레딧 단가는 서버 상수(apps/web/src/server/pricing.ts)가 정본이고 p_credits 로 받는다(코어는 단가를 모른다).
create or replace function public.start_run(
  p_org_id          uuid,
  p_kind            text,
  p_book_id         uuid,
  p_trailer_id      uuid,
  p_scene_id        uuid,
  p_credits         integer,
  p_idempotency_key text,
  p_actor           uuid,
  p_payload         jsonb default '{}'::jsonb
)
returns public.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run      public.generation_runs;
  v_book     public.books;
  v_trailer  public.trailers;
  v_scene    public.scenes;
  v_rid      text;
  v_max      integer;
  v_active   integer;
  v_ledger   bigint;
  v_job      public.jobs;
  v_run_id   uuid := gen_random_uuid();
begin
  if not public.is_privileged_session() then
    raise exception 'start_run: service_role only' using errcode = '42501';
  end if;
  if p_idempotency_key is null or p_idempotency_key !~ '^run:trailer:[A-Za-z0-9][A-Za-z0-9_:-]{7,119}$' then
    raise exception 'start_run: idempotency key must be run:trailer:<request_id>' using errcode = '22023';
  end if;
  if p_kind is null or p_kind not in ('digest', 'brief', 'storyboard', 'scene_image', 'narration', 'meta') then
    raise exception 'start_run: invalid kind %', p_kind using errcode = '22023';
  end if;
  if p_credits is null or p_credits < 0 then
    raise exception 'start_run: credits must be >= 0' using errcode = '22023';
  end if;
  v_rid := substring(p_idempotency_key from 13);

  perform pg_advisory_xact_lock(hashtext('trailer:run:' || p_idempotency_key));
  select * into v_run from public.generation_runs r where r.idempotency_key = p_idempotency_key;
  if found then
    if v_run.org_id <> p_org_id then
      raise exception 'start_run: idempotency key belongs to another organization' using errcode = '42501';
    end if;
    return v_run;
  end if;

  if not exists (select 1 from public.org_members m
                 where m.org_id = p_org_id and m.user_id = p_actor and m.status = 'active'
                   and coalesce(m.role, '') in ('owner', 'admin', 'member')) then
    raise exception 'start_run: not a member' using errcode = '42501';
  end if;
  if not public.has_entitlement(p_org_id, 'trailer') then
    raise exception 'start_run: no entitlement' using errcode = '42501';
  end if;

  -- 대상 확인(같은 조직, 부모-자식 일치)
  if p_kind in ('brief', 'storyboard', 'meta', 'scene_image', 'narration') then
    select * into v_trailer from public.trailers t where t.id = p_trailer_id and t.org_id = p_org_id for update;
    if not found then
      raise exception 'start_run: trailer not found' using errcode = 'P0002';
    end if;
    if v_trailer.status = 'archived' then
      raise exception 'start_run: trailer is archived' using errcode = 'TR001';
    end if;
    if p_book_id is not null and p_book_id <> v_trailer.book_id then
      raise exception 'start_run: book mismatch' using errcode = '22023';
    end if;
    p_book_id := v_trailer.book_id;
  elsif p_trailer_id is not null or p_scene_id is not null then
    raise exception 'start_run: digest takes a book only' using errcode = '22023';
  end if;
  select * into v_book from public.books b
  where b.id = p_book_id and b.org_id = p_org_id and b.deleted_at is null for update;
  if not found then
    raise exception 'start_run: book not found' using errcode = 'P0002';
  end if;
  if v_book.rights_ack_at is null then
    raise exception 'start_run: rights not acknowledged' using errcode = 'TR003';
  end if;
  if p_kind in ('scene_image', 'narration') then
    select * into v_scene from public.scenes s where s.id = p_scene_id and s.trailer_id = v_trailer.id and s.org_id = p_org_id;
    if not found then
      raise exception 'start_run: scene not found' using errcode = 'P0002';
    end if;
    if p_kind = 'scene_image' and v_scene.kind not in ('image_scene', 'character_scene', 'title_card', 'quote_card', 'hook_text') then
      raise exception 'start_run: scene kind % has no generated image', v_scene.kind using errcode = '22023';
    end if;
    if p_kind = 'narration' and coalesce(btrim(v_scene.narration), '') = '' then
      raise exception 'start_run: scene has no narration text' using errcode = 'TR004';
    end if;
    if p_kind = 'narration' and v_trailer.narration_mode = 'none' then
      raise exception 'start_run: narration is off for this trailer' using errcode = '22023';
    end if;
  elsif p_scene_id is not null then
    raise exception 'start_run: scene is only for scene_image or narration' using errcode = '22023';
  end if;

  -- 선행 단계
  if p_kind = 'digest' then
    if v_book.manuscript_path is null or v_book.manuscript_sha256 is null then
      raise exception 'start_run: manuscript is not parsed yet' using errcode = 'TR004';
    end if;
    if v_book.digest_status = 'ready' and exists (select 1 from public.book_digests d
        where d.book_id = v_book.id and d.manuscript_sha256 = v_book.manuscript_sha256) then
      raise exception 'start_run: digest is up to date' using errcode = '22023';
    end if;
  elsif p_kind = 'brief' then
    if v_book.digest_status <> 'ready' then
      raise exception 'start_run: digest is not ready' using errcode = 'TR004';
    end if;
  elsif p_kind = 'storyboard' then
    if v_trailer.current_brief_id is null then
      raise exception 'start_run: choose a brief first' using errcode = 'TR004';
    end if;
  elsif p_kind = 'meta' then
    if not exists (select 1 from public.scenes s where s.trailer_id = v_trailer.id and s.kind <> 'end_card') then
      raise exception 'start_run: storyboard is empty' using errcode = 'TR004';
    end if;
  end if;

  -- 잡만 끝난 실행을 먼저 정리한 뒤 같은 대상 중복과 조직 동시 실행 수를 본다
  perform public.reconcile_runs(p_org_id);
  if exists (select 1 from public.generation_runs r
             where r.org_id = p_org_id and r.kind = p_kind and r.status in ('queued', 'running')
               and r.book_id = v_book.id
               and r.trailer_id is not distinct from v_trailer.id
               and r.scene_id is not distinct from v_scene.id) then
    raise exception 'start_run: % already running for this target', p_kind using errcode = 'TR002';
  end if;
  v_max := public.config_int('max_active_runs_per_org', 4);
  select count(*) into v_active from public.generation_runs r where r.org_id = p_org_id and r.status in ('queued', 'running');
  if v_active >= v_max then
    raise exception 'start_run: too many active runs for this organization' using errcode = 'TR005';
  end if;

  -- 선차감(원자, 멱등). 부족하면 CR001 로 전체 롤백
  if p_credits > 0 then
    select c.ledger_id into v_ledger
    from public.consume_credits(p_org_id, p_credits, 'trailer', 'trailer.' || p_kind, 'trailer_generation_run', v_run_id::text,
                              'consume:trailer:run:' || v_rid,
                              jsonb_build_object('book_id', v_book.id, 'trailer_id', v_trailer.id, 'scene_id', v_scene.id), p_actor) c;
  end if;

  insert into public.generation_runs (id, org_id, kind, book_id, trailer_id, scene_id, credits_reserved, credit_ledger_id,
                                       idempotency_key, payload, created_by)
  values (v_run_id, p_org_id, p_kind, v_book.id, v_trailer.id, v_scene.id, p_credits, v_ledger,
          p_idempotency_key, coalesce(p_payload, '{}'::jsonb), p_actor)
  returning * into v_run;

  select * into v_job from public.enqueue_job(
    p_org_id, 'trailer', 'trailer.ai', 'trailer.' || p_kind,
    jsonb_build_object('run_id', v_run_id, 'kind', p_kind, 'book_id', v_book.id, 'trailer_id', v_trailer.id, 'scene_id', v_scene.id),
    100, now(), 2, v_ledger, 'job:trailer:run:' || v_rid, null, p_actor, true);

  update public.generation_runs set job_id = v_job.id where id = v_run_id returning * into v_run;
  if p_kind = 'digest' then
    update public.books set digest_status = 'queued' where id = v_book.id;
  end if;
  return v_run;
end;
$$;

-- 7-3. AI 실행 종료: 결과 저장 + 실행 succeeded + 잡 환불 표시 해제를 한 트랜잭션으로.
--      결과 형식은 04_API.md 4절(kind 별). 원고 대조(인용 검증)는 apps/api 가 끝낸 뒤 verified 로 넘긴다.
create or replace function public.finish_run(p_run_id uuid, p_result jsonb, p_ai_run_id uuid default null)
returns public.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run     public.generation_runs;
  v_book    public.books;
  v_trailer public.trailers;
  v_brief   public.briefs;
  v_scene   jsonb;
  v_pos     integer := 0;
  v_n       integer;
  v_pack    jsonb;
begin
  if not public.is_privileged_session() then
    raise exception 'finish_run: service_role only' using errcode = '42501';
  end if;
  if p_result is null or jsonb_typeof(p_result) <> 'object' then
    raise exception 'finish_run: result must be an object' using errcode = '22023';
  end if;
  select * into v_run from public.generation_runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'finish_run: run not found' using errcode = 'P0002';
  end if;
  if v_run.status not in ('queued', 'running') then
    raise exception 'finish_run: run is already %', v_run.status using errcode = 'TR001';
  end if;
  if v_run.status = 'queued' then
    update public.generation_runs set status = 'running' where id = p_run_id;
  end if;
  -- 결과를 넘긴 실행은 잡이 나중에 실패로 끝나도 환불하지 않는다(nomad-docs 교차검증 #4와 같은 규칙)
  if v_run.job_id is not null then
    update public.jobs set refund_on_failure = false where id = v_run.job_id and refund_on_failure;
  end if;
  select * into v_book from public.books b where b.id = v_run.book_id for update;
  if v_run.trailer_id is not null then
    select * into v_trailer from public.trailers t where t.id = v_run.trailer_id for update;
  end if;

  if v_run.kind = 'digest' then
    if coalesce(jsonb_typeof(p_result -> 'chapters'), '') <> 'array' then
      raise exception 'finish_run: digest needs chapters' using errcode = '22023';
    end if;
    insert into public.book_digests (org_id, book_id, manuscript_sha256, chapters, characters, themes, settings, ai_run_id)
    values (v_run.org_id, v_run.book_id, coalesce(p_result ->> 'manuscript_sha256', v_book.manuscript_sha256),
            p_result -> 'chapters', coalesce(p_result -> 'characters', '[]'::jsonb), coalesce(p_result -> 'themes', '[]'::jsonb),
            coalesce(p_result -> 'settings', '[]'::jsonb), p_ai_run_id)
    on conflict (book_id) do update
      set manuscript_sha256 = excluded.manuscript_sha256, chapters = excluded.chapters, characters = excluded.characters,
          themes = excluded.themes, settings = excluded.settings, ai_run_id = excluded.ai_run_id;
    update public.books set digest_status = 'ready' where id = v_run.book_id;

  elsif v_run.kind = 'brief' then
    -- 실행 1회 = 브리프 1~3안(각도별). 첫 안이 현재 브리프가 된다(이미 있으면 바꾸지 않는다).
    if coalesce(jsonb_typeof(p_result -> 'briefs'), '') <> 'array' or coalesce(jsonb_array_length(p_result -> 'briefs'), 0) not between 1 and 3 then
      raise exception 'finish_run: brief needs 1~3 briefs' using errcode = '22023';
    end if;
    for v_pack in select value from jsonb_array_elements(p_result -> 'briefs') loop
      insert into public.briefs (org_id, trailer_id, source, content, ai_run_id)
      values (v_run.org_id, v_run.trailer_id, 'ai', v_pack, p_ai_run_id)
      returning * into v_brief;
      if v_trailer.current_brief_id is null then
        update public.trailers set current_brief_id = v_brief.id where id = v_run.trailer_id
        returning * into v_trailer;
      end if;
    end loop;

  elsif v_run.kind = 'storyboard' then
    if coalesce(jsonb_typeof(p_result -> 'scenes'), '') <> 'array' or jsonb_array_length(p_result -> 'scenes') not between 1 and 39 then
      raise exception 'finish_run: storyboard needs 1~39 scenes' using errcode = '22023';
    end if;
    delete from public.scenes s where s.trailer_id = v_run.trailer_id and s.kind <> 'end_card';
    for v_scene in select value from jsonb_array_elements(p_result -> 'scenes') loop
      if coalesce(v_scene ->> 'kind', '') = 'end_card' then
        raise exception 'finish_run: storyboard must not include the end card' using errcode = 'TR007';
      end if;
      insert into public.scenes (org_id, trailer_id, position, kind, duration_ms, text, narration, quote_ref, quote_verified,
                                  visual, music_cue, created_by)
      values (v_run.org_id, v_run.trailer_id, v_pos, v_scene ->> 'kind', coalesce((v_scene ->> 'duration_ms')::integer, 3000),
              v_scene ->> 'text', v_scene ->> 'narration', v_scene -> 'quote_ref',
              coalesce((v_scene ->> 'quote_verified')::boolean, false) and (v_scene ->> 'kind') = 'quote_card',
              coalesce(v_scene -> 'visual', '{}'::jsonb), v_scene ->> 'music_cue', v_run.created_by);
      v_pos := v_pos + 1;
    end loop;
    update public.scenes set position = v_pos where trailer_id = v_run.trailer_id and kind = 'end_card';
    update public.trailers set storyboard_version = storyboard_version + 1 where id = v_run.trailer_id;

  elsif v_run.kind in ('scene_image', 'narration') then
    if coalesce(p_result ->> 'storage_path', '') = '' then
      raise exception 'finish_run: asset needs storage_path' using errcode = '22023';
    end if;
    if v_run.kind = 'narration' then
      -- 같은 목소리 규칙: 트레일러에 고정된 목소리와 다르면 거부(VOICE_ARCHITECTURE 같은 목소리)
      if v_trailer.voice ? 'provider'
         and ((v_trailer.voice ->> 'provider') is distinct from (p_result ->> 'provider')
              or (v_trailer.voice ->> 'voice_id') is distinct from (p_result ->> 'voice_id')) then
        raise exception 'finish_run: narration voice differs from the fixed voice' using errcode = '22023';
      end if;
      if not (v_trailer.voice ? 'provider') then
        update public.trailers
           set voice = jsonb_build_object('provider', p_result ->> 'provider', 'voice_id', p_result ->> 'voice_id', 'fixed_at', now())
         where id = v_run.trailer_id;
      end if;
    end if;
    update public.scene_assets set status = 'superseded'
     where scene_id = v_run.scene_id and status = 'ready'
       and slot = case when v_run.kind = 'narration' then 'audio' else 'visual' end;
    insert into public.scene_assets (org_id, scene_id, kind, source, ai_generated, provider, model, seed, voice_id, storage_path,
                                      width, height, duration_ms, chars, bytes, run_id, created_by)
    values (v_run.org_id, v_run.scene_id, case when v_run.kind = 'narration' then 'narration' else 'image' end,
            'ai_generated', true, p_result ->> 'provider', coalesce(p_result ->> 'model', p_result ->> 'provider'),
            (p_result ->> 'seed')::bigint, p_result ->> 'voice_id', p_result ->> 'storage_path',
            (p_result ->> 'width')::integer, (p_result ->> 'height')::integer, (p_result ->> 'duration_ms')::integer,
            (p_result ->> 'chars')::integer, coalesce((p_result ->> 'bytes')::bigint, 0), v_run.id, v_run.created_by);

  elsif v_run.kind = 'meta' then
    if coalesce(jsonb_typeof(p_result -> 'packs'), '') <> 'array' then
      raise exception 'finish_run: meta needs packs' using errcode = '22023';
    end if;
    for v_pack in select value from jsonb_array_elements(p_result -> 'packs') loop
      insert into public.metadata_packs (org_id, trailer_id, platform, title, description, hashtags, link_ids, source, created_by)
      values (v_run.org_id, v_run.trailer_id, v_pack ->> 'platform', v_pack ->> 'title', coalesce(v_pack ->> 'description', ''),
              coalesce(array(select jsonb_array_elements_text(v_pack -> 'hashtags')), '{}'),
              coalesce(array(select (jsonb_array_elements_text(v_pack -> 'link_ids'))::uuid), '{}'),
              'ai', v_run.created_by)
      on conflict (trailer_id, platform) do update
        set title = excluded.title, description = excluded.description, hashtags = excluded.hashtags,
            link_ids = excluded.link_ids, source = 'ai';
    end loop;
  end if;

  update public.generation_runs
     set status = 'succeeded', ai_run_id = coalesce(p_ai_run_id, ai_run_id),
         progress = jsonb_build_object('stage', 'done', 'at', now())
   where id = p_run_id
  returning * into v_run;
  return v_run;
end;
$$;

-- 7-4. AI 실행 실패 기록(환불은 public.fail_job 이 한다. 오케스트레이터는 fail_job 다음에 이것을 부른다).
create or replace function public.fail_run(p_run_id uuid, p_error text)
returns public.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare v_run public.generation_runs;
begin
  if not public.is_privileged_session() then
    raise exception 'fail_run: service_role only' using errcode = '42501';
  end if;
  update public.generation_runs
     set status = 'failed', error = left(coalesce(p_error, 'failed'), 1000)
   where id = p_run_id and status in ('queued', 'running')
  returning * into v_run;
  if not found then
    raise exception 'fail_run: run not active' using errcode = 'TR001';
  end if;
  if v_run.kind = 'digest' then
    update public.books set digest_status = 'failed' where id = v_run.book_id and digest_status = 'queued';
  end if;
  return v_run;
end;
$$;

-- 7-5. 렌더 시작: 플랜·권리·엔드카드·인용·에셋·음악을 검사하고 스냅샷을 남긴 뒤 선차감 + enqueue.
--      워터마크·AI 표시는 여기서 서버가 정한다(요청 입력 아님).
create or replace function public.start_render(
  p_org_id                 uuid,
  p_trailer_id             uuid,
  p_format                 text,
  p_resolution             text,
  p_credits                integer,
  p_request_id             uuid,
  p_actor                  uuid,
  p_allow_unverified_quotes boolean default false
)
returns public.renders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_render   public.renders;
  v_trailer  public.trailers;
  v_book     public.books;
  v_tpl      public.templates;
  v_kit      public.brand_kits;
  v_features jsonb;
  v_plan     text;
  v_total    integer;
  v_last     public.scenes;
  v_missing  integer;
  v_qsum     integer;
  v_qmax     integer;
  v_has_ai   boolean;
  v_snapshot jsonb;
  v_ledger   bigint;
  v_job      public.jobs;
  v_active   integer;
  v_render_id uuid := gen_random_uuid();
begin
  if not public.is_privileged_session() then
    raise exception 'start_render: service_role only' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'start_render: request_id required' using errcode = '22023';
  end if;
  if p_credits is null or p_credits < 0 then
    raise exception 'start_render: credits must be >= 0' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('trailer:render:' || p_request_id::text));
  select * into v_render from public.renders r where r.request_id = p_request_id;
  if found then
    if v_render.org_id <> p_org_id then
      raise exception 'start_render: request belongs to another organization' using errcode = '42501';
    end if;
    return v_render;
  end if;

  if not exists (select 1 from public.org_members m
                 where m.org_id = p_org_id and m.user_id = p_actor and m.status = 'active'
                   and coalesce(m.role, '') in ('owner', 'admin', 'member')) then
    raise exception 'start_render: not a member' using errcode = '42501';
  end if;
  if not public.has_entitlement(p_org_id, 'trailer') then
    raise exception 'start_render: no entitlement' using errcode = '42501';
  end if;

  select * into v_trailer from public.trailers t where t.id = p_trailer_id and t.org_id = p_org_id for update;
  if not found then
    raise exception 'start_render: trailer not found' using errcode = 'P0002';
  end if;
  if v_trailer.status = 'archived' then
    raise exception 'start_render: trailer is archived' using errcode = 'TR001';
  end if;
  select * into v_book from public.books b where b.id = v_trailer.book_id;
  if v_book.rights_ack_at is null then
    raise exception 'start_render: rights not acknowledged' using errcode = 'TR003';
  end if;

  -- 플랜 판정(서버가 결정)
  v_features := public.plan_features(p_org_id);
  v_plan := coalesce(public.plan_code(p_org_id), 'free');
  if p_format is null or not (p_format = any (v_trailer.formats)) then
    raise exception 'start_render: format % is not selected for this trailer', p_format using errcode = '22023';
  end if;
  if not public.feature_has(v_features, 'formats', p_format, array['vertical_9_16']) then
    raise exception 'start_render: format % needs a higher plan', p_format using errcode = 'TR005';
  end if;
  if p_resolution not in ('480p', '720p', '1080p') then
    raise exception 'start_render: invalid resolution' using errcode = '22023';
  end if;
  if p_resolution = '1080p' and coalesce(v_features ->> 'max_resolution', '720p') <> '1080p' then
    raise exception 'start_render: 1080p needs a higher plan' using errcode = 'TR005';
  end if;

  -- 장면 구조: 엔드카드가 마지막, 길이 합계는 플랜 최대 길이(+10%) 이하
  select * into v_last from public.scenes s where s.trailer_id = p_trailer_id order by s.position desc limit 1;
  if v_last.kind is distinct from 'end_card' then
    raise exception 'start_render: end card must be the last scene' using errcode = 'TR007';
  end if;
  if (select count(*) from public.scenes s where s.trailer_id = p_trailer_id) < 2 then
    raise exception 'start_render: storyboard is empty' using errcode = 'TR004';
  end if;
  select sum(s.duration_ms) into v_total from public.scenes s where s.trailer_id = p_trailer_id;
  if p_format <> 'cover_loop'
     and v_total > least(v_trailer.duration_s, public.feature_int(v_features, 'max_duration_s', 30)) * 1100 then
    raise exception 'start_render: total duration % ms exceeds the limit', v_total using errcode = 'TR005';
  end if;

  -- 인용: 원고 대조 통과(또는 사용자가 직접 쓴 문장이라고 확인), 장면당·트레일러당 글자 수 한도
  if not p_allow_unverified_quotes and exists (select 1 from public.scenes s
      where s.trailer_id = p_trailer_id and s.kind = 'quote_card' and not s.quote_verified) then
    raise exception 'start_render: unverified quote' using errcode = 'TR006';
  end if;
  v_qmax := public.config_int('max_quote_chars_each', 80);
  if exists (select 1 from public.scenes s where s.trailer_id = p_trailer_id and s.kind = 'quote_card'
             and char_length(coalesce(s.text, '')) > v_qmax) then
    raise exception 'start_render: a quote exceeds % chars', v_qmax using errcode = 'TR006';
  end if;
  select coalesce(sum(char_length(coalesce(s.text, ''))), 0) into v_qsum
  from public.scenes s where s.trailer_id = p_trailer_id and s.kind = 'quote_card';
  if v_qsum > public.config_int('max_quote_chars_per_trailer', 300) then
    raise exception 'start_render: quotes exceed % chars in total', public.config_int('max_quote_chars_per_trailer', 300) using errcode = 'TR006';
  end if;

  -- 에셋: 이미지 장면은 visual, 내레이션이 있는 장면은 audio(내레이션 모드일 때) ready 필요
  select count(*) into v_missing
  from public.scenes s
  where s.trailer_id = p_trailer_id
    and ((s.kind in ('image_scene', 'character_scene')
          and not exists (select 1 from public.scene_assets a where a.scene_id = s.id and a.slot = 'visual' and a.status = 'ready'))
      or (v_trailer.narration_mode = 'voiceover' and coalesce(btrim(s.narration), '') <> ''
          and not exists (select 1 from public.scene_assets a where a.scene_id = s.id and a.slot = 'audio' and a.status = 'ready')));
  if v_missing > 0 then
    raise exception 'start_render: % scenes are missing assets', v_missing using errcode = 'TR004';
  end if;

  -- 음악: 사용자 업로드는 권리 확인 필수, 카탈로그는 공개(라이선스 검증) 곡만
  if v_trailer.music_path is not null and not v_trailer.music_rights_ack then
    raise exception 'start_render: music rights not acknowledged' using errcode = 'TR011';
  end if;
  if v_trailer.music_track_id is not null and not exists (
      select 1 from public.music_tracks m where m.id = v_trailer.music_track_id and m.status = 'published') then
    raise exception 'start_render: music track is not available' using errcode = 'TR011';
  end if;

  select * into v_tpl from public.templates x where x.code = v_trailer.template_code;
  if v_tpl.status <> 'published' or not (p_format = any (v_tpl.formats)) then
    raise exception 'start_render: template does not support %', p_format using errcode = '22023';
  end if;
  if v_tpl.tier = 'premium' and not public.feature_bool(v_features, 'premium_templates', false) then
    raise exception 'start_render: premium template needs a higher plan' using errcode = 'TR005';
  end if;
  if v_trailer.brand_kit_id is not null then
    select * into v_kit from public.brand_kits k where k.id = v_trailer.brand_kit_id;
  end if;

  perform public.reconcile_runs(p_org_id);
  select count(*) into v_active from public.renders r where r.org_id = p_org_id and r.status in ('queued', 'running');
  if v_active >= public.config_int('max_active_renders_per_org', 2) then
    raise exception 'start_render: too many active renders' using errcode = 'TR005';
  end if;

  select exists (select 1 from public.scene_assets a join public.scenes s on s.id = a.scene_id
                 where s.trailer_id = p_trailer_id and a.status = 'ready' and a.ai_generated) into v_has_ai;

  v_snapshot := jsonb_build_object(
    'trailer', jsonb_build_object('id', v_trailer.id, 'title', v_trailer.title, 'duration_s', v_trailer.duration_s,
                                  'language', v_trailer.language, 'voice', v_trailer.voice, 'storyboard_version', v_trailer.storyboard_version),
    'book', jsonb_build_object('title', v_book.title, 'subtitle', v_book.subtitle, 'author_name', v_book.author_name,
                               'publisher_name', v_book.publisher_name, 'cover_path', v_book.cover_path, 'genre', v_book.genre),
    'template', jsonb_build_object('code', v_tpl.code, 'composition_id', v_tpl.composition_id, 'version', v_tpl.version),
    'brand_kit', case when v_kit.id is null then null else
                   jsonb_build_object('palette', v_kit.palette, 'font_display', v_kit.font_display, 'font_body', v_kit.font_body,
                                      'logo_path', v_kit.logo_path) end,
    'music', jsonb_build_object('track_id', v_trailer.music_track_id, 'path', v_trailer.music_path,
                                'storage_path', (select m.storage_path from public.music_tracks m where m.id = v_trailer.music_track_id)),
    'cta', (select jsonb_build_object('short_code', l.short_code, 'store', l.store, 'label', l.label)
              from public.purchase_links l where l.book_id = v_book.id and l.is_active order by l.sort_order, l.created_at limit 1),
    'scenes', (select jsonb_agg(jsonb_build_object(
                 'id', s.id, 'position', s.position, 'kind', s.kind, 'duration_ms', s.duration_ms, 'text', s.text,
                 'narration', s.narration, 'visual', s.visual, 'music_cue', s.music_cue, 'revision', s.revision,
                 'image', (select jsonb_build_object('path', a.storage_path, 'ai', a.ai_generated)
                             from public.scene_assets a where a.scene_id = s.id and a.slot = 'visual' and a.status = 'ready'),
                 'audio', (select jsonb_build_object('path', a.storage_path, 'duration_ms', a.duration_ms, 'ai', a.ai_generated)
                             from public.scene_assets a where a.scene_id = s.id and a.slot = 'audio' and a.status = 'ready'))
                 order by s.position)
               from public.scenes s where s.trailer_id = p_trailer_id),
    'total_ms', v_total,
    'has_ai_assets', v_has_ai
  );

  if p_credits > 0 then
    select c.ledger_id into v_ledger
    from public.consume_credits(p_org_id, p_credits, 'trailer', 'trailer.render', 'trailer_render', v_render_id::text,
                              'consume:trailer:render:' || p_request_id::text,
                              jsonb_build_object('trailer_id', p_trailer_id, 'format', p_format, 'resolution', p_resolution), p_actor) c;
  end if;

  insert into public.renders (id, org_id, trailer_id, format, resolution, plan_code, watermark, ai_label, snapshot,
                               credits, credit_ledger_id, request_id, created_by)
  values (v_render_id, p_org_id, p_trailer_id, p_format, p_resolution, v_plan,
          p_resolution = '480p' or public.feature_bool(v_features, 'watermark', true),
          v_has_ai, v_snapshot, p_credits, v_ledger, p_request_id, p_actor)
  returning * into v_render;

  select * into v_job from public.enqueue_job(
    p_org_id, 'trailer', 'trailer.render', 'render.trailer',
    jsonb_build_object('render_id', v_render_id),
    case when public.feature_bool(v_features, 'priority_render', false) then 1 else 100 end,
    now(), 2, v_ledger, 'job:trailer:render:' || p_request_id::text, null, p_actor, true);

  update public.renders set job_id = v_job.id where id = v_render_id returning * into v_render;
  return v_render;
end;
$$;

-- 7-6. 렌더 종료(성공). 경로는 그 렌더 폴더만. 보존 기간은 플랜 기준(무료 14일, 유료 90일, 제안).
create or replace function public.finish_render(
  p_render_id   uuid,
  p_output_path text,
  p_poster_path text,
  p_srt_path    text,
  p_bytes       bigint,
  p_duration_ms integer
)
returns public.renders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_render public.renders;
  v_prefix text;
  v_days   integer;
begin
  if not public.is_privileged_session() then
    raise exception 'finish_render: service_role only' using errcode = '42501';
  end if;
  select * into v_render from public.renders r where r.id = p_render_id for update;
  if not found then
    raise exception 'finish_render: not found' using errcode = 'P0002';
  end if;
  if v_render.status not in ('queued', 'running') then
    raise exception 'finish_render: render is already %', v_render.status using errcode = 'TR001';
  end if;
  v_prefix := v_render.org_id::text || '/trailer/renders/' || p_render_id::text || '/';
  if p_output_path is null or left(p_output_path, char_length(v_prefix)) <> v_prefix
     or (p_poster_path is not null and left(p_poster_path, char_length(v_prefix)) <> v_prefix)
     or (p_srt_path is not null and left(p_srt_path, char_length(v_prefix)) <> v_prefix) then
    raise exception 'finish_render: output path must be under %', v_prefix using errcode = '22023';
  end if;
  if v_render.status = 'queued' then
    update public.renders set status = 'running' where id = p_render_id;
  end if;
  if v_render.job_id is not null then
    update public.jobs set refund_on_failure = false where id = v_render.job_id and refund_on_failure;
  end if;
  v_days := case when v_render.plan_code = 'free'
                 then public.config_int('render_retention_days_free', 14)
                 else public.config_int('render_retention_days_paid', 90) end;
  update public.renders
     set status = 'succeeded', output_path = p_output_path, poster_path = p_poster_path, srt_path = p_srt_path,
         bytes = p_bytes, duration_ms = p_duration_ms, expires_at = now() + make_interval(days => v_days)
   where id = p_render_id
  returning * into v_render;
  return v_render;
end;
$$;

create or replace function public.fail_render(p_render_id uuid, p_error text)
returns public.renders
language plpgsql
security definer
set search_path = ''
as $$
declare v_render public.renders;
begin
  if not public.is_privileged_session() then
    raise exception 'fail_render: service_role only' using errcode = '42501';
  end if;
  update public.renders set status = 'failed', error = left(coalesce(p_error, 'failed'), 1000)
   where id = p_render_id and status in ('queued', 'running')
  returning * into v_render;
  if not found then
    raise exception 'fail_render: render not active' using errcode = 'TR001';
  end if;
  return v_render;
end;
$$;

-- 7-7. 구매 링크 클릭(공개 리다이렉트 /b/[code] 서버가 service 로 호출). 이동할 URL 을 돌려준다.
create or replace function public.record_link_click(
  p_code       text,
  p_referrer   text default null,
  p_ip_hash    text default null,
  p_user_agent text default null,
  p_tag        text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_link public.purchase_links;
begin
  if not public.is_privileged_session() then
    raise exception 'record_link_click: service_role only' using errcode = '42501';
  end if;
  select l.* into v_link
  from public.purchase_links l
  join public.books b on b.id = l.book_id
  where l.short_code = p_code and l.is_active and b.deleted_at is null;
  if not found then
    return null;
  end if;
  insert into public.link_clicks (link_id, org_id, referrer, ip_hash, user_agent, tag)
  values (v_link.id, v_link.org_id, left(p_referrer, 500), p_ip_hash, left(p_user_agent, 300),
          case when p_tag ~ '^[a-z0-9_:-]{1,80}$' then p_tag else null end);
  update public.purchase_links set click_count = click_count + 1 where id = v_link.id;
  return v_link.url;
end;
$$;

-- 7-8. 외부 승인 링크 열기(P1). 토큰 원문은 서버가 만들고 sha256 만 넘긴다.
create or replace function public.open_review(
  p_org_id       uuid,
  p_trailer_id   uuid,
  p_render_ids   uuid[],
  p_token_sha256 text,
  p_label        text,
  p_actor        uuid
)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare v_review public.reviews;
begin
  if not public.is_privileged_session() then
    raise exception 'open_review: service_role only' using errcode = '42501';
  end if;
  if not exists (select 1 from public.org_members m
                 where m.org_id = p_org_id and m.user_id = p_actor and m.status = 'active'
                   and coalesce(m.role, '') in ('owner', 'admin', 'member')) then
    raise exception 'open_review: not a member' using errcode = '42501';
  end if;
  if not public.feature_bool(public.plan_features(p_org_id), 'approval_links', false) then
    raise exception 'open_review: approval links need a higher plan' using errcode = 'TR005';
  end if;
  if not exists (select 1 from public.trailers t where t.id = p_trailer_id and t.org_id = p_org_id) then
    raise exception 'open_review: trailer not found' using errcode = 'P0002';
  end if;
  if coalesce(cardinality(p_render_ids), 0) = 0 or exists (
       select 1 from unnest(p_render_ids) as u(rid)
       where not exists (select 1 from public.renders r
                         where r.id = u.rid and r.trailer_id = p_trailer_id and r.org_id = p_org_id and r.status = 'succeeded')) then
    raise exception 'open_review: renders must be finished renders of this trailer' using errcode = '22023';
  end if;
  insert into public.reviews (org_id, trailer_id, render_ids, token_sha256, reviewer_label, expires_at, created_by)
  values (p_org_id, p_trailer_id, p_render_ids, p_token_sha256, p_label,
          now() + make_interval(days => public.config_int('review_link_days', 7)), p_actor)
  returning * into v_review;
  perform public.write_audit(p_org_id, 'review.open', 'review', v_review.id::text);
  return v_review;
end;
$$;

-- 7-9. 외부 승인 결정(공개 /review/[token] 서버가 토큰을 sha256 해서 service 로 호출).
create or replace function public.decide_review(p_token_sha256 text, p_decision text, p_comment text default null)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare v_review public.reviews;
begin
  if not public.is_privileged_session() then
    raise exception 'decide_review: service_role only' using errcode = '42501';
  end if;
  if p_decision not in ('approved', 'changes_requested') then
    raise exception 'decide_review: invalid decision' using errcode = '22023';
  end if;
  select * into v_review from public.reviews r where r.token_sha256 = p_token_sha256 for update;
  if not found or v_review.status <> 'pending' then
    raise exception 'decide_review: link is not valid' using errcode = 'TR009';
  end if;
  if v_review.expires_at <= now() then
    update public.reviews set status = 'expired' where id = v_review.id;
    raise exception 'decide_review: link expired' using errcode = 'TR009';
  end if;
  update public.reviews set status = p_decision, comment = left(p_comment, 1000) where id = v_review.id
  returning * into v_review;
  if p_decision = 'approved' then
    update public.trailers set status = 'approved' where id = v_review.trailer_id and status = 'active';
  end if;
  perform public.write_audit(v_review.org_id, 'review.' || p_decision, 'review', v_review.id::text);
  return v_review;
end;
$$;

-- 7-10. FLORA(publishing) 책 가져오기(P1, 모듈러 전용). 같은 조직의 책만, 원고 본문은 서버가 Storage 로 내보낸다.
--       모놀리스에는 publishing 스키마가 없으므로 TR010 을 돌려준다(05_DATA_MODEL 8절).
create or replace function public.import_flora_book(p_org_id uuid, p_flora_book_id uuid, p_actor uuid)
returns public.books
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_src  record;
  v_book public.books;
begin
  if not public.is_privileged_session() then
    raise exception 'import_flora_book: service_role only' using errcode = '42501';
  end if;
  if to_regclass('publishing.books') is null then
    raise exception 'import_flora_book: FLORA is not available in this deployment' using errcode = 'TR010';
  end if;
  if not exists (select 1 from public.org_members m
                 where m.org_id = p_org_id and m.user_id = p_actor and m.status = 'active'
                   and coalesce(m.role, '') in ('owner', 'admin', 'member')) then
    raise exception 'import_flora_book: not a member' using errcode = '42501';
  end if;
  if not public.has_entitlement(p_org_id, 'publishing') or not public.has_entitlement(p_org_id, 'trailer') then
    raise exception 'import_flora_book: both entitlements required' using errcode = 'TR010';
  end if;
  if not public.feature_bool(public.plan_features(p_org_id), 'flora_import', false) then
    raise exception 'import_flora_book: needs a higher plan' using errcode = 'TR005';
  end if;
  execute 'select b.title, b.subtitle, b.author_name, b.genre from publishing.books b
           where b.id = $1 and b.org_id = $2 and b.deleted_at is null'
    into v_src using p_flora_book_id, p_org_id;
  if v_src is null then
    raise exception 'import_flora_book: book not found' using errcode = 'P0002';
  end if;
  insert into public.books (org_id, title, subtitle, author_name, genre, source, flora_book_id, created_by)
  values (p_org_id, coalesce(v_src.title, '제목 없음'), v_src.subtitle, v_src.author_name,
          case when v_src.genre in ('novel', 'essay', 'poetry', 'self_help', 'nonfiction_business', 'it_tech', 'children', 'fantasy_genre')
               then v_src.genre else 'other' end,
          'flora', p_flora_book_id, p_actor)
  returning * into v_book;
  perform public.write_audit(p_org_id, 'book.import_flora', 'book', v_book.id::text, null,
                           jsonb_build_object('flora_book_id', p_flora_book_id));
  return v_book;
end;
$$;

-- =====================================================================
-- 8. RLS 정책과 GRANT
-- =====================================================================

alter table public.runtime_config  enable row level security;
alter table public.grammars        enable row level security;
alter table public.templates       enable row level security;
alter table public.music_tracks    enable row level security;
alter table public.books           enable row level security;
alter table public.purchase_links  enable row level security;
alter table public.brand_kits      enable row level security;
alter table public.trailers        enable row level security;
alter table public.briefs          enable row level security;
alter table public.scenes          enable row level security;
alter table public.metadata_packs  enable row level security;
alter table public.book_digests    enable row level security;
alter table public.link_clicks     enable row level security;
alter table public.scene_assets    enable row level security;
alter table public.generation_runs enable row level security;
alter table public.renders         enable row level security;
alter table public.reviews         enable row level security;

revoke all on public.book_digests from public, anon, authenticated;
revoke all on public.books from public, anon, authenticated;
revoke all on public.brand_kits from public, anon, authenticated;
revoke all on public.briefs from public, anon, authenticated;
revoke all on public.generation_runs from public, anon, authenticated;
revoke all on public.grammars from public, anon, authenticated;
revoke all on public.link_clicks from public, anon, authenticated;
revoke all on public.metadata_packs from public, anon, authenticated;
revoke all on public.music_tracks from public, anon, authenticated;
revoke all on public.purchase_links from public, anon, authenticated;
revoke all on public.renders from public, anon, authenticated;
revoke all on public.reviews from public, anon, authenticated;
revoke all on public.runtime_config from public, anon, authenticated;
revoke all on public.scene_assets from public, anon, authenticated;
revoke all on public.scenes from public, anon, authenticated;
revoke all on public.templates from public, anon, authenticated;
revoke all on public.trailers from public, anon, authenticated;  -- 모놀리스: public 의 코어 테이블 권한은 건드리지 않고 도메인 테이블만 회수

-- 8-1. 카탈로그: 공개 행만, trailer 사용자만. 운영자는 draft 도 본다. 쓰기 정책 없음. runtime_config 는 GRANT 없음.
grant select on public.grammars, public.templates to authenticated;
-- 음악 원본 경로는 사용자에게 주지 않는다(미리듣기 경로만)
grant select (id, code, title, mood, bpm, duration_ms, tier, preview_path, status, sort_order, created_at, updated_at)
  on public.music_tracks to authenticated;

drop policy if exists grammars_select on public.grammars;
create policy grammars_select on public.grammars for select to authenticated
  using ((status = 'published' and public.has_trailer_access()) or public.is_platform_admin());
drop policy if exists templates_select on public.templates;
create policy templates_select on public.templates for select to authenticated
  using ((status = 'published' and public.has_trailer_access()) or public.is_platform_admin());
drop policy if exists music_tracks_select on public.music_tracks;
create policy music_tracks_select on public.music_tracks for select to authenticated
  using ((status = 'published' and public.has_trailer_access()) or public.is_platform_admin());

-- 8-2. books: 멤버 읽기, member 이상 쓰기(서버 컬럼 제외), 삭제는 owner/admin. 사용자는 flora 출처를 만들 수 없다.
grant select on public.books to authenticated;
grant insert (id, org_id, title, subtitle, author_name, publisher_name, genre, language, isbn, published_on, description, audience,
              source, manuscript_path, cover_path) on public.books to authenticated;
grant update (title, subtitle, author_name, publisher_name, genre, language, isbn, published_on, description, audience,
              manuscript_path, cover_path, status, deleted_at) on public.books to authenticated;
grant delete on public.books to authenticated;
drop policy if exists books_select on public.books;
create policy books_select on public.books for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'trailer'));
drop policy if exists books_insert on public.books;
create policy books_insert on public.books for insert to authenticated
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'trailer')
              and source in ('upload', 'paste'));
drop policy if exists books_update on public.books;
create policy books_update on public.books for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'trailer'))
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists books_delete on public.books;
create policy books_delete on public.books for delete to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']));

-- 8-3. purchase_links, brand_kits, metadata_packs: 같은 패턴(서버 컬럼 제외)
grant select on public.purchase_links to authenticated;
grant insert (id, org_id, book_id, store, label, url, is_affiliate, sort_order, is_active) on public.purchase_links to authenticated;
grant update (store, label, url, is_affiliate, sort_order, is_active) on public.purchase_links to authenticated;
grant delete on public.purchase_links to authenticated;

grant select on public.brand_kits to authenticated;
grant insert (id, org_id, book_id, name, palette, font_display, font_body, logo_path, source) on public.brand_kits to authenticated;
grant update (name, palette, font_display, font_body, logo_path) on public.brand_kits to authenticated;
grant delete on public.brand_kits to authenticated;

grant select on public.metadata_packs to authenticated;
grant insert (id, org_id, trailer_id, platform, title, description, hashtags, link_ids) on public.metadata_packs to authenticated;
grant update (title, description, hashtags, link_ids) on public.metadata_packs to authenticated;
grant delete on public.metadata_packs to authenticated;

do $$
declare t text;
begin
  foreach t in array array['purchase_links', 'brand_kits', 'metadata_packs'] loop
    execute format('drop policy if exists %1$s_select on public.%1$I', t);
    execute format('create policy %1$s_select on public.%1$I for select to authenticated using (public.is_org_member(org_id) and public.has_entitlement(org_id, %2$L))', t, 'trailer');
    execute format('drop policy if exists %1$s_insert on public.%1$I', t);
    execute format('create policy %1$s_insert on public.%1$I for insert to authenticated with check (public.has_org_role(org_id, array[%2$L, %3$L, %4$L]) and public.has_entitlement(org_id, %5$L))', t, 'owner', 'admin', 'member', 'trailer');
    execute format('drop policy if exists %1$s_update on public.%1$I', t);
    execute format('create policy %1$s_update on public.%1$I for update to authenticated using (public.has_org_role(org_id, array[%2$L, %3$L, %4$L]) and public.has_entitlement(org_id, %5$L)) with check (public.has_org_role(org_id, array[%2$L, %3$L, %4$L]))', t, 'owner', 'admin', 'member', 'trailer');
    execute format('drop policy if exists %1$s_delete on public.%1$I', t);
    execute format('create policy %1$s_delete on public.%1$I for delete to authenticated using (public.has_org_role(org_id, array[%2$L, %3$L, %4$L]))', t, 'owner', 'admin', 'member');
  end loop;
end $$;

-- 8-4. trailers: member 이상 쓰기. 서버 컬럼(voice, storyboard_version, music_rights_ack_at/by)은 GRANT 없음.
grant select on public.trailers to authenticated;
grant insert (id, org_id, book_id, title, grammar_code, template_code, brand_kit_id, formats, duration_s, language, spoiler_level,
              narration_mode, voice_pref, music_track_id, music_path, music_rights_ack) on public.trailers to authenticated;
grant update (title, grammar_code, template_code, brand_kit_id, formats, duration_s, language, spoiler_level, narration_mode,
              voice_pref, music_track_id, music_path, music_rights_ack, current_brief_id, selected_hook, status) on public.trailers to authenticated;
grant delete on public.trailers to authenticated;
drop policy if exists trailers_select on public.trailers;
create policy trailers_select on public.trailers for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'trailer'));
drop policy if exists trailers_insert on public.trailers;
create policy trailers_insert on public.trailers for insert to authenticated
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'trailer'));
drop policy if exists trailers_update on public.trailers;
create policy trailers_update on public.trailers for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'trailer'))
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists trailers_delete on public.trailers;
create policy trailers_delete on public.trailers for delete to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']));

-- 8-5. briefs: 읽기는 멤버, 사용자 쓰기는 manual 새 버전 INSERT 만(불변). 수정·삭제 정책 없음.
grant select on public.briefs to authenticated;
grant insert (id, org_id, trailer_id, source, content) on public.briefs to authenticated;
drop policy if exists briefs_select on public.briefs;
create policy briefs_select on public.briefs for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'trailer'));
drop policy if exists briefs_insert on public.briefs;
create policy briefs_insert on public.briefs for insert to authenticated
  with check (source = 'manual' and public.has_org_role(org_id, array['owner', 'admin', 'member'])
              and public.has_entitlement(org_id, 'trailer'));

-- 8-6. scenes: 사용자는 엔드카드를 만들거나 지울 수 없다. 인용 검증·revision 은 GRANT 없음(트리거가 관리).
grant select on public.scenes to authenticated;
grant insert (id, org_id, trailer_id, position, kind, duration_ms, text, narration, visual, music_cue) on public.scenes to authenticated;
grant update (position, duration_ms, text, narration, visual, music_cue) on public.scenes to authenticated;
grant delete on public.scenes to authenticated;
drop policy if exists scenes_select on public.scenes;
create policy scenes_select on public.scenes for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'trailer'));
drop policy if exists scenes_insert on public.scenes;
create policy scenes_insert on public.scenes for insert to authenticated
  with check (kind <> 'end_card' and public.has_org_role(org_id, array['owner', 'admin', 'member'])
              and public.has_entitlement(org_id, 'trailer'));
drop policy if exists scenes_update on public.scenes;
create policy scenes_update on public.scenes for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'trailer'))
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists scenes_delete on public.scenes;
create policy scenes_delete on public.scenes for delete to authenticated
  using (kind <> 'end_card' and public.has_org_role(org_id, array['owner', 'admin', 'member']));

-- 8-7. 서버 기록: 멤버 SELECT 만. 쓰기 GRANT 없음 + guard 트리거. 승인 토큰 해시는 사용자에게 주지 않는다.
grant select on public.book_digests, public.link_clicks, public.scene_assets, public.generation_runs, public.renders to authenticated;
grant select (id, org_id, trailer_id, render_ids, reviewer_label, status, expires_at, decided_at, comment, created_by, created_at, updated_at)
  on public.reviews to authenticated;
do $$
declare t text;
begin
  foreach t in array array['book_digests', 'link_clicks', 'scene_assets', 'generation_runs', 'renders', 'reviews'] loop
    execute format('drop policy if exists %1$s_select on public.%1$I', t);
    execute format('create policy %1$s_select on public.%1$I for select to authenticated using (public.is_org_member(org_id) and public.has_entitlement(org_id, %2$L))', t, 'trailer');
  end loop;
end $$;

-- =====================================================================
-- 9. Storage (제품 전용 버킷)
--   trailer-media    비공개. 장면 에셋(AI 이미지·내레이션·사용자 이미지 정규화본). 멤버는 자기 조직 폴더 읽기만, 쓰기는 서버만.
--   trailer-catalog  비공개. 카탈로그 음악 원본·템플릿 자산. 정책 없음 → service_role 만(렌더러)
--   trailer-previews 공개 읽기. 템플릿 미리보기(작은 영상·이미지), 음악 30초 미리듣기만. 쓰기 정책 없음
--   원고·표지·사용자 음악은 core 버킷 org-files(<org_id>/trailer/...), 렌더 결과는 core 버킷 exports(<org_id>/trailer/renders/...).
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('trailer-media',    'trailer-media',    false, 52428800, array['image/png', 'image/webp', 'image/jpeg', 'audio/mpeg', 'audio/wav']),
  ('trailer-catalog',  'trailer-catalog',  false, 52428800, array['audio/mpeg', 'audio/wav', 'image/png', 'image/webp', 'font/woff2']),
  ('trailer-previews', 'trailer-previews', true,  5242880,  array['image/webp', 'image/png', 'video/mp4', 'audio/mpeg'])
on conflict (id) do nothing;

drop policy if exists trailer_previews_select on storage.objects;
create policy trailer_previews_select on storage.objects for select to anon, authenticated
  using (bucket_id = 'trailer-previews');
drop policy if exists trailer_media_select on storage.objects;
create policy trailer_media_select on storage.objects for select to authenticated
  using (bucket_id = 'trailer-media' and public.is_org_member(public.storage_org_id(name))
         and public.has_entitlement(public.storage_org_id(name), 'trailer'));

-- =====================================================================
-- 10. 함수 EXECUTE 정리 (0007_core_function_privileges.sql 과 같은 규칙)
-- =====================================================================
do $$ declare r record; begin for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('acknowledge_rights','books_before_update','briefs_before_insert','config_int','create_end_card','decide_review','enforce_plan_limits','enforce_review_transition','enforce_run_status_transition','fail_render','fail_run','feature_bool','feature_has','feature_int','finish_render','finish_run','has_trailer_access','import_flora_book','metadata_packs_before_write','open_review','plan_code','plan_features','reconcile_runs','record_link_click','reorder_scenes','save_scene','scenes_before_write','start_render','start_run','trailers_before_write','valid_hashtags','valid_palette') loop execute format('revoke execute on function %s from public, anon', r.sig); execute format('grant execute on function %s to service_role', r.sig); end loop; end $$;  -- 모놀리스: public 의 코어 함수 권한은 건드리지 않고 도메인 함수만 회수
grant execute on function public.has_trailer_access() to authenticated;
grant execute on function public.plan_features(uuid) to authenticated;
grant execute on function public.plan_code(uuid) to authenticated;
grant execute on function public.feature_int(jsonb, text, integer) to authenticated;
grant execute on function public.feature_bool(jsonb, text, boolean) to authenticated;
grant execute on function public.feature_has(jsonb, text, text, text[]) to authenticated;
grant execute on function public.valid_palette(jsonb) to authenticated;
grant execute on function public.valid_hashtags(text[]) to authenticated;
grant execute on function public.acknowledge_rights(uuid, text) to authenticated;
grant execute on function public.save_scene(uuid, jsonb, integer) to authenticated;
grant execute on function public.reorder_scenes(uuid, uuid[]) to authenticated;
-- 서버 전용(service_role): config_int, reconcile_runs, start_run, finish_run, fail_run, start_render, finish_render, fail_render,
-- record_link_click, open_review, decide_review, import_flora_book. 트리거 함수는 사용자에게 열지 않는다.
revoke execute on function public.config_int(text, integer) from authenticated;
revoke execute on function public.enforce_plan_limits() from authenticated;
revoke execute on function public.books_before_update() from authenticated;
revoke execute on function public.trailers_before_write() from authenticated;
revoke execute on function public.create_end_card() from authenticated;
revoke execute on function public.scenes_before_write() from authenticated;
revoke execute on function public.briefs_before_insert() from authenticated;
revoke execute on function public.metadata_packs_before_write() from authenticated;
revoke execute on function public.enforce_run_status_transition() from authenticated;
revoke execute on function public.enforce_review_transition() from authenticated;

-- =====================================================================
-- 11. 카탈로그 seed (설정 데이터라 마이그레이션과 함께 간다. 모놀리스 0002 말미와 같은 값)
--     장르 문법 6종(08_DESIGN_SYSTEM 6장), 템플릿 6종(무료 3, 프리미엄 3), 운영 상수. 음악은 라이선스 검증 뒤 운영자가 넣는다.
-- =====================================================================
insert into public.runtime_config (key, value_int, note) values
  ('max_active_runs_per_org',       4,      '제안: 조직당 동시 AI 실행. 01_PRD 5장'),
  ('max_active_renders_per_org',    2,      '제안: 조직당 동시 렌더(렌더러 동시성 보호). 01_PRD 5장'),
  ('max_quote_chars_each',          80,     '제안: 인용 장면 1개 글자 상한. 01_PRD 6장'),
  ('max_quote_chars_per_trailer',   300,    '제안: 트레일러 1편 인용 합계 상한. 01_PRD 6장'),
  ('max_manuscript_chars',          600000, '제안: 원고 글자 상한(장편 2권 분량). 01_PRD 5장'),
  ('review_link_days',              7,      '제안: 외부 승인 링크 유효 기간(일)'),
  ('render_retention_days_free',    14,     '제안: 무료 플랜 렌더 보존(일)'),
  ('render_retention_days_paid',    90,     '제안: 유료 플랜 렌더 보존(일)')
on conflict (key) do nothing;

insert into public.grammars (code, name, description, book_genres, beats, narration_style, music_mood, status, sort_order) values
  ('novel_cinematic', '소설 시네마틱', '분위기와 인물의 갈등을 보여 주고 결말은 숨긴다',
   array['novel', 'fantasy_genre'],
   '[{"key":"atmosphere","label":"세계와 분위기","share_pct":20,"scene_kinds":["image_scene"]},
     {"key":"character","label":"인물과 욕망","share_pct":20,"scene_kinds":["character_scene","narration_card"]},
     {"key":"conflict","label":"갈등의 시작","share_pct":25,"scene_kinds":["image_scene","quote_card"]},
     {"key":"question","label":"질문 던지기","share_pct":15,"scene_kinds":["hook_text"]},
     {"key":"title","label":"제목 공개","share_pct":20,"scene_kinds":["title_card"]}]',
   'voiceover', 'cinematic_tension', 'published', 1),
  ('practical_problem', '실용서 문제 해결', '독자의 문제 → 이 책의 해법 → 얻는 결과 순서',
   array['self_help', 'nonfiction_business', 'it_tech'],
   '[{"key":"pain","label":"독자의 문제","share_pct":25,"scene_kinds":["hook_text","image_scene"]},
     {"key":"promise","label":"이 책의 약속","share_pct":20,"scene_kinds":["narration_card"]},
     {"key":"inside","label":"목차 하이라이트","share_pct":30,"scene_kinds":["narration_card","quote_card"]},
     {"key":"proof","label":"저자와 근거","share_pct":10,"scene_kinds":["title_card"]},
     {"key":"cta","label":"행동 유도","share_pct":15,"scene_kinds":["cta_card"]}]',
   'voiceover', 'upbeat_focus', 'published', 2),
  ('essay_quote', '에세이 문장', '한 문장의 여운을 길게 보여 준다',
   array['essay'],
   '[{"key":"mood","label":"정서 장면","share_pct":25,"scene_kinds":["image_scene"]},
     {"key":"line1","label":"문장 하나","share_pct":30,"scene_kinds":["quote_card"]},
     {"key":"line2","label":"문장 둘","share_pct":25,"scene_kinds":["quote_card"]},
     {"key":"title","label":"제목","share_pct":20,"scene_kinds":["title_card"]}]',
   'quote_reading', 'calm_piano', 'published', 3),
  ('poetry_typo', '시집 타이포그래피', '시 구절을 글자 움직임으로 낭독한다',
   array['poetry'],
   '[{"key":"silence","label":"여백","share_pct":15,"scene_kinds":["image_scene"]},
     {"key":"verse","label":"구절","share_pct":55,"scene_kinds":["quote_card"]},
     {"key":"title","label":"시집 제목","share_pct":30,"scene_kinds":["title_card"]}]',
   'quote_reading', 'ambient_soft', 'published', 4),
  ('children_storybook', '그림책 동화', '그림책 장면을 넘기듯 보여 준다(실존 아동 이미지 금지)',
   array['children'],
   '[{"key":"meet","label":"주인공 소개","share_pct":25,"scene_kinds":["character_scene"]},
     {"key":"adventure","label":"모험","share_pct":35,"scene_kinds":["image_scene","narration_card"]},
     {"key":"wonder","label":"궁금증","share_pct":20,"scene_kinds":["hook_text"]},
     {"key":"title","label":"제목","share_pct":20,"scene_kinds":["title_card"]}]',
   'voiceover', 'playful_light', 'published', 5),
  ('insight_hook', '인사이트 훅(숏폼)', '첫 2초 반전 질문으로 붙잡고 핵심 한 줄로 끝낸다',
   array['self_help', 'nonfiction_business', 'it_tech', 'essay', 'other'],
   '[{"key":"hook","label":"반전 질문","share_pct":20,"scene_kinds":["hook_text"]},
     {"key":"insight","label":"핵심 통찰","share_pct":45,"scene_kinds":["narration_card","quote_card"]},
     {"key":"turn","label":"그래서 이 책","share_pct":15,"scene_kinds":["title_card"]},
     {"key":"cta","label":"행동 유도","share_pct":20,"scene_kinds":["cta_card"]}]',
   'voiceover', 'upbeat_focus', 'published', 6)
on conflict (code) do nothing;

insert into public.templates (code, name, grammar_code, composition_id, formats, tier, status, sort_order) values
  ('cinematic_basic',  '시네마틱 기본',     'novel_cinematic',    'CinematicBasic',  array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5', 'cover_loop'], 'free',    'published', 1),
  ('practical_clean',  '실용서 클린',       'practical_problem',  'PracticalClean',  array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5', 'cover_loop'], 'free',    'published', 2),
  ('essay_paper',      '에세이 종이',       'essay_quote',        'EssayPaper',      array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5', 'cover_loop'], 'free',    'published', 3),
  ('poetry_ink',       '시집 잉크',         'poetry_typo',        'PoetryInk',       array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5'],               'premium', 'published', 4),
  ('storybook_page',   '그림책 페이지',     'children_storybook', 'StorybookPage',   array['vertical_9_16', 'landscape_16_9', 'square_1_1', 'portrait_4_5'],               'premium', 'published', 5),
  ('insight_kinetic',  '인사이트 키네틱',   'insight_hook',       'InsightKinetic',  array['vertical_9_16', 'square_1_1', 'portrait_4_5'],                                  'premium', 'published', 6)
on conflict (code) do nothing;



-- (플랜·크레딧팩·AI 라우팅 기본값은 seed.sql 로 이동했다. 모듈러 2600_trailer.sql 12~13절과 같은 값)
-- 마지막: (모놀리스) 10절 do 블록이 이 파일 함수의 PUBLIC EXECUTE 를 회수했다.
