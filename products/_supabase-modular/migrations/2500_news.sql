-- =====================================================================
-- 2500_news.sql
-- local-news(로컬뉴스 클라우드, 가칭) 도메인. 선행: core 0000~0009 (+ 선택: Multi-tenant_Theming 0011, 이 조각은 테마 객체를 참조하지 않는다)
--
-- 설계 요약 (docs/products/local-news/05_DATA_MODEL.md, 마스터 브리프 1~3장)
--   - 테넌트 = 신문사 = core.organizations 1행(is_personal=false). 신문사 1곳에 news.newspapers 1행.
--   - 편집국 = core.org_members(active) + news.staff(active, 도메인 역할 6종). 정책은 news.is_newsroom(org, roles) 하나로 판정한다.
--   - 독자 = auth 사용자 + news.readers(org_id, user_id). 독자는 조직 멤버가 아니다. 자기 행만 본다.
--   - 방문자(anon) = 공개 조건(신문사 활성 + 필요적 게재사항 완성 + 엔타이틀먼트 활성 + 게시 시각 도래 + 엠바고 해제)을
--     만족한 행의 "공개 컬럼"만 SELECT 한다(컬럼 GRANT). 본문(body)과 댓글·독자·제보는 공개 함수로만 나간다.
--   - 쓰기는 전부 SECURITY DEFINER RPC 또는 service_role 이다. 사용자에게 INSERT/UPDATE/DELETE GRANT 가 없고
--     모든 테이블에 core.guard_privileged_write 이중 잠금을 붙였다. FOR ALL 정책은 없다.
--   - 공통모듈 8개(M1~M8)는 1차로 이 스키마 안의 절로 둔다. 다른 제품이 쓰면 COMMON_MODULES_ROADMAP 3장대로 추출한다.
--
-- 보안 규칙 (SECURITY_BASELINE.md)
--   - SECURITY DEFINER 함수는 set search_path = '' 이고 모든 객체를 스키마 한정한다.
--   - authenticated 에 EXECUTE 를 연 함수 안의 호출자 판정은 core.is_service_caller() 만 쓴다(news.assert_staff).
--   - 역할 비교는 exists 를 돌려주는 헬퍼(news.has_staff_role) 또는 coalesce 로 한다(NULL-safe).
--   - 끝(12절)에서 이 스키마 모든 함수의 PUBLIC/anon EXECUTE 를 회수하고 허용 목록만 다시 준다.
--
-- 사용자 정의 SQLSTATE (05_DATA_MODEL.md 4절 표, 04_API.md 7장)
--   NW001 개설 신청 중복·슬러그 사용 중       NW002 신문사 비공개·비활성(독자 기능 불가)
--   NW003 필요적 게재사항 미완성              NW004 현재 상태에서 허용되지 않는 작업(워크플로)
--   NW005 전재 계약 없음·만료                 NW006 AI 초안 사람 승인 없음
--   NW007 선거 여론조사 공표 금지 기간        NW008 독자 미가입·차단·탈퇴
--   NW009 댓글 꺼짐(신문사·기사·선거 정책)    NW010 금칙어 포함
--   NW011 레이트 리밋                         NW012 토큰 무효·만료(뉴스레터)
--   NW013 정부광고 직판 금지                  NW014 플랜 한도 초과
--   NW015 입력 오류
--   그 밖: 42501 권한, P0002 없음, 22023 상태 전이·불변 컬럼 위반, 23514 CHECK, 23503 교차 조직 참조, 23505 중복
-- =====================================================================

create schema if not exists news;
comment on schema news is 'local-news: 지역신문 멀티테넌트 뉴스룸(편집국·독자 사이트·광고·뉴스레터·법정 준수)';

grant usage on schema news to anon, authenticated, service_role;
alter default privileges in schema news grant all on tables to service_role;
alter default privileges in schema news grant all on sequences to service_role;
alter default privileges in schema news grant execute on functions to service_role;
alter default privileges in schema news revoke execute on functions from public;

-- 검색: tsvector('simple') + pg_trgm. 한국어 형태소 분석기는 쓰지 않는다(pg_bigm 지원 여부 미확인, 결정 D-7).
create extension if not exists pg_trgm with schema extensions;

insert into core.apps (id, name, schema_name, signup_policy, status) values ('news', 'Local News Cloud', 'news', 'invite', 'beta')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 0. 검증 헬퍼 (IMMUTABLE, CHECK 제약에서 사용)
--    Storage 경로 규칙: <org_id>/news/<folder>/<파일>. 첫 폴더가 org_id 여야 core.storage_org_id 정책이 맞는다.
-- ---------------------------------------------------------------------
create or replace function news.is_org_path(p_org uuid, p_path text, p_folder text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_org is not null and p_path is not null
     and char_length(p_path) <= 300
     and p_path like p_org::text || '/news/' || p_folder || '/%'
     and p_path ~ '^[0-9a-f-]{36}/news/[a-z]+/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$'
     and p_path !~ '(^|/)\.\.?(/|$)';
$$;

create or replace function news.are_org_paths(p_org uuid, p_paths text[], p_folder text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(news.is_org_path(p_org, x, p_folder)), true) from unnest(p_paths) as x;
$$;

-- =====================================================================
-- M1. newsroom-cms (+ M7 매체정보)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 newspaper_applications: 신문사 개설 신청(조직이 생기기 전). 승인되면 org_id 가 채워진다.
--     예외: 테넌트 생성 전 행이라 org_id 가 nullable 이다. 대신 applicant_org_id(신청자 개인 조직)가 Storage 경로의 첫 폴더다.
--     상태: pending -> approved | rejected | withdrawn
-- ---------------------------------------------------------------------
create table if not exists news.newspaper_applications (
  id                 uuid primary key default gen_random_uuid(),
  applicant_id       uuid not null,
  applicant_org_id   uuid not null references core.organizations(id) on delete cascade,
  org_id             uuid references core.organizations(id) on delete set null,
  slug               text not null constraint newspaper_applications_slug_check check (slug ~ '^[a-z][a-z0-9-]{1,30}[a-z0-9]$'),
  title              text not null constraint newspaper_applications_title_check check (char_length(btrim(title)) between 1 and 80),
  media_kind         text not null constraint newspaper_applications_media_kind_check check (media_kind in ('internet', 'daily', 'weekly', 'monthly', 'other')),
  registration_no    text not null constraint newspaper_applications_registration_no_check check (char_length(btrim(registration_no)) between 2 and 40),
  registration_date  date not null,
  publisher_name     text not null constraint newspaper_applications_publisher_name_check check (char_length(btrim(publisher_name)) between 1 and 40),
  contact_email      text not null constraint newspaper_applications_contact_email_check check (char_length(contact_email) <= 254 and contact_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  contact_phone      text not null constraint newspaper_applications_contact_phone_check check (contact_phone ~ '^[0-9+() -]{6,30}$'),
  certificate_path   text not null,
  message            text constraint newspaper_applications_message_check check (message is null or char_length(message) <= 2000),
  plan_code          text,
  status             text not null default 'pending'
                     constraint newspaper_applications_status_check check (status in ('pending', 'approved', 'rejected', 'withdrawn')),
  decided_at         timestamptz,
  decided_by         uuid,
  decision_note      text constraint newspaper_applications_decision_note_check check (decision_note is null or char_length(decision_note) <= 1000),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint newspaper_applications_certificate_path_check check (news.is_org_path(applicant_org_id, certificate_path, 'applications'))
);
create unique index if not exists newspaper_applications_pending_slug_uniq on news.newspaper_applications (slug) where status = 'pending';
create unique index if not exists newspaper_applications_pending_applicant_uniq on news.newspaper_applications (applicant_id) where status = 'pending';
create index if not exists newspaper_applications_status_idx on news.newspaper_applications (status, created_at);
comment on table news.newspaper_applications is '신문사 개설 신청. 등록증 사본은 org-files/<신청자 개인 조직>/news/applications/ 에 둔다. 승인·반려는 service_role(운영자 서버)만';

-- ---------------------------------------------------------------------
-- 1.2 newspapers: 신문사 1곳 1행. 매체정보(신문법 제21조 필요적 게재사항 + 시행령 제7조의2 청소년보호책임자).
--     profile_completed_at 은 트리거가 계산한다(사용자·서버 모두 직접 지정 불가). null 이면 독자 사이트 비공개.
--     상태: active -> suspended | closed, suspended -> active | closed
-- ---------------------------------------------------------------------
create table if not exists news.newspapers (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null unique references core.organizations(id) on delete cascade,
  application_id        uuid references news.newspaper_applications(id) on delete set null,
  status                text not null default 'active'
                        constraint newspapers_status_check check (status in ('active', 'suspended', 'closed')),
  title                 text not null constraint newspapers_title_check check (char_length(btrim(title)) between 1 and 80),
  legal_name            text constraint newspapers_legal_name_check check (legal_name is null or char_length(btrim(legal_name)) between 1 and 80),
  media_kind            text not null default 'internet'
                        constraint newspapers_media_kind_check check (media_kind in ('internet', 'daily', 'weekly', 'monthly', 'other')),
  registration_no       text constraint newspapers_registration_no_check check (registration_no is null or char_length(btrim(registration_no)) between 2 and 40),
  registration_date     date,
  publisher_name        text constraint newspapers_publisher_name_check check (publisher_name is null or char_length(btrim(publisher_name)) between 1 and 40),
  editor_name           text constraint newspapers_editor_name_check check (editor_name is null or char_length(btrim(editor_name)) between 1 and 40),
  youth_officer_name    text constraint newspapers_youth_officer_name_check check (youth_officer_name is null or char_length(btrim(youth_officer_name)) between 1 and 40),
  privacy_officer_name  text constraint newspapers_privacy_officer_name_check check (privacy_officer_name is null or char_length(btrim(privacy_officer_name)) between 1 and 40),
  publish_address       text constraint newspapers_publish_address_check check (publish_address is null or char_length(btrim(publish_address)) between 5 and 200),
  phone                 text constraint newspapers_phone_check check (phone is null or phone ~ '^[0-9+() -]{6,30}$'),
  email                 text constraint newspapers_email_check check (email is null or (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  first_published_on    date,
  ethics_code_url       text constraint newspapers_ethics_code_url_check check (ethics_code_url is null or (char_length(ethics_code_url) <= 300 and ethics_code_url ~ '^(https://[^[:space:]]{3,}|/[A-Za-z0-9/_-]{0,100})$')),
  comments_enabled      boolean not null default false,
  banned_words          text[] not null default '{}' constraint newspapers_banned_words_check check (cardinality(banned_words) <= 500),
  profile_completed_at  timestamptz,
  status_reason         text constraint newspapers_status_reason_check check (status_reason is null or char_length(status_reason) <= 500),
  created_by            uuid,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on column news.newspapers.profile_completed_at is '필요적 게재사항 10개가 모두 채워진 시각(트리거 계산). null 이면 news.is_public_newspaper = false';
comment on column news.newspapers.comments_enabled is '신문사 댓글 스위치. 기본 끔(결정 D-6). 기사별 articles.comments_enabled 와 AND';

create or replace function news.newspapers_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_complete boolean;
begin
  if tg_op = 'UPDATE' then
    if new.org_id is distinct from old.org_id then
      raise exception 'newspapers: org_id is immutable' using errcode = '22023';
    end if;
    if new.status is distinct from old.status and not (
         (old.status = 'active'    and new.status in ('suspended', 'closed'))
      or (old.status = 'suspended' and new.status in ('active', 'closed'))
    ) then
      raise exception 'newspapers: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
  end if;
  v_complete := new.title is not null and new.legal_name is not null and new.registration_no is not null
            and new.registration_date is not null and new.publisher_name is not null and new.editor_name is not null
            and new.youth_officer_name is not null and new.publish_address is not null and new.phone is not null
            and new.first_published_on is not null;
  if v_complete then
    new.profile_completed_at := case when tg_op = 'UPDATE' and old.profile_completed_at is not null then old.profile_completed_at else now() end;
  else
    new.profile_completed_at := null;
  end if;
  return new;
end;
$$;
drop trigger if exists newspapers_before_write on news.newspapers;
create trigger newspapers_before_write before insert or update on news.newspapers
  for each row execute function news.newspapers_before_write();

-- ---------------------------------------------------------------------
-- 1.3 staff: 편집국 구성원과 도메인 역할. core.org_members 와 1:1(같은 org_id, user_id).
--     코어 역할 매핑: publisher=owner, editor=admin, 나머지=member. publisher 는 조직당 1명(owner).
--     상태: invited -> active | removed, active -> removed, removed -> invited (재초대)
-- ---------------------------------------------------------------------
create table if not exists news.staff (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  user_id            uuid not null references auth.users(id) on delete cascade,
  role               text not null
                     constraint staff_role_check check (role in ('publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager')),
  status             text not null default 'invited'
                     constraint staff_status_check check (status in ('invited', 'active', 'removed')),
  byline_name        text not null constraint staff_byline_name_check check (char_length(btrim(byline_name)) between 1 and 40),
  title_label        text constraint staff_title_label_check check (title_label is null or char_length(btrim(title_label)) between 1 and 40),
  bio                text constraint staff_bio_check check (bio is null or char_length(bio) <= 500),
  photo_path         text,
  email_public       text constraint staff_email_public_check check (email_public is null or (char_length(email_public) <= 254 and email_public ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  is_public_profile  boolean not null default true,
  invited_by         uuid,
  joined_at          timestamptz,
  removed_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (org_id, user_id),
  constraint staff_photo_path_check check (photo_path is null or news.is_org_path(org_id, photo_path, 'staff'))
);
create unique index if not exists staff_one_publisher_idx on news.staff (org_id) where role = 'publisher' and status <> 'removed';
create index if not exists staff_user_idx on news.staff (user_id) where status = 'active';

create or replace function news.staff_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.user_id is distinct from old.user_id then
    raise exception 'staff: org_id/user_id are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'invited' and new.status in ('active', 'removed'))
      or (old.status = 'active'  and new.status = 'removed')
      or (old.status = 'removed' and new.status = 'invited')
    ) then
      raise exception 'staff: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'active'  then new.joined_at := coalesce(new.joined_at, now()); end if;
    if new.status = 'removed' then new.removed_at := now(); end if;
    if new.status = 'invited' then new.removed_at := null; new.joined_at := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists staff_before_update on news.staff;
create trigger staff_before_update before update on news.staff
  for each row execute function news.staff_before_update();

-- ---------------------------------------------------------------------
-- 1.4 sections / regions / tags: 분류. 삭제하지 않고 is_active=false 로 내린다(기사 FK 보존).
-- ---------------------------------------------------------------------
create table if not exists news.sections (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  slug        text not null constraint sections_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{0,39}$'),
  name        text not null constraint sections_name_check check (char_length(btrim(name)) between 1 and 40),
  parent_id   uuid,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (org_id, slug),
  unique (id, org_id),
  foreign key (parent_id, org_id) references news.sections (id, org_id)
);

create table if not exists news.regions (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  slug        text not null constraint regions_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{0,39}$'),
  name        text not null constraint regions_name_check check (char_length(btrim(name)) between 1 and 40),
  level       text not null default 'sigungu'
              constraint regions_level_check check (level in ('sido', 'sigungu', 'eupmyeondong', 'custom')),
  admin_code  text constraint regions_admin_code_check check (admin_code is null or admin_code ~ '^[0-9]{2,10}$'),
  parent_id   uuid,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (org_id, slug),
  unique (id, org_id),
  foreign key (parent_id, org_id) references news.regions (id, org_id)
);

create table if not exists news.tags (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  slug        text not null constraint tags_slug_check check (slug ~ '^[0-9a-z가-힣][0-9a-z가-힣-]{0,39}$'),
  name        text not null constraint tags_name_check check (char_length(btrim(name)) between 1 and 40),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (org_id, slug),
  unique (id, org_id)
);

-- ---------------------------------------------------------------------
-- 6.1(선행) wire_contracts: 통신사 전재 계약(M6). articles 가 참조하므로 먼저 만든다.
--     만료(ends_on < KST 오늘) 또는 terminated 이면 그 계약의 wire 기사는 공개 조건에서 빠진다.
-- ---------------------------------------------------------------------
create table if not exists news.wire_contracts (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  provider          text not null constraint wire_contracts_provider_check check (provider in ('yonhap', 'newsis', 'news1', 'other')),
  name              text not null constraint wire_contracts_name_check check (char_length(btrim(name)) between 1 and 80),
  contract_no       text constraint wire_contracts_contract_no_check check (contract_no is null or char_length(contract_no) <= 60),
  starts_on         date not null,
  ends_on           date,
  attribution_text  text not null constraint wire_contracts_attribution_text_check check (char_length(btrim(attribution_text)) between 2 and 100),
  allow_full_text   boolean not null default true,
  status            text not null default 'active' constraint wire_contracts_status_check check (status in ('active', 'terminated')),
  note              text constraint wire_contracts_note_check check (note is null or char_length(note) <= 1000),
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  constraint wire_contracts_period_check check (ends_on is null or ends_on >= starts_on)
);

-- ---------------------------------------------------------------------
-- 1.5 media_assets: 미디어 라이브러리. 저작권·출처(credit)·대체텍스트(alt) 필수(NW-F-014).
--     published_at: 공개 기사가 처음 참조한 시각(publish_article 이 기록). null 인 사진은 anon 이 목록으로 볼 수 없다.
-- ---------------------------------------------------------------------
create table if not exists news.media_assets (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  bucket            text not null default 'public-assets' constraint media_assets_bucket_check check (bucket in ('public-assets', 'org-files')),
  storage_path      text not null,
  kind              text not null default 'image' constraint media_assets_kind_check check (kind in ('image', 'video', 'audio', 'document')),
  mime              text not null constraint media_assets_mime_check check (mime ~ '^(image|video|audio|application)/[a-z0-9.+-]{1,60}$'),
  width             integer constraint media_assets_width_check check (width is null or width between 1 and 20000),
  height            integer constraint media_assets_height_check check (height is null or height between 1 and 20000),
  bytes             bigint constraint media_assets_bytes_check check (bytes is null or bytes between 1 and 524288000),
  alt_text          text not null constraint media_assets_alt_text_check check (char_length(btrim(alt_text)) between 1 and 300),
  caption           text constraint media_assets_caption_check check (caption is null or char_length(caption) <= 500),
  credit            text not null constraint media_assets_credit_check check (char_length(btrim(credit)) between 1 and 200),
  copyright_holder  text constraint media_assets_copyright_holder_check check (copyright_holder is null or char_length(copyright_holder) <= 200),
  license           text not null default 'own'
                    constraint media_assets_license_check check (license in ('own', 'wire', 'licensed', 'cc', 'reader', 'press_release', 'other')),
  ai_generated      boolean not null default false,
  ai_disclosure     text,
  status            text not null default 'active' constraint media_assets_status_check check (status in ('active', 'archived')),
  published_at      timestamptz,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  unique (bucket, storage_path),
  constraint media_assets_storage_path_check check (news.is_org_path(org_id, storage_path, 'media')),
  constraint media_assets_ai_disclosure_check check (not ai_generated or (ai_disclosure is not null and char_length(btrim(ai_disclosure)) between 5 and 300))
);
create index if not exists media_assets_org_created_idx on news.media_assets (org_id, created_at desc);

-- ---------------------------------------------------------------------
-- 1.6 articles: 기사. 워크플로(NW-F-012)는 트리거가 강제하고 누가 하는지는 RPC 가 강제한다.
--     draft -> submitted | archived
--     submitted -> approved | draft(반려·회수)
--     approved -> scheduled | published | draft
--     scheduled -> published | approved(예약 취소)
--     published -> unpublished | archived
--     unpublished -> published(재게시) | draft | archived
--     archived -> (없음)
--     유형(type): original 자체 / wire 전재 / press_release 보도자료 / contribution 기고 / sponsored 기사형 광고
--     출처(origin): human / ai_press_release(보도자료 AI 초안, type 은 press_release 고정) / import(이관). 만든 뒤 바꿀 수 없다.
-- ---------------------------------------------------------------------
create table if not exists news.articles (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  slug                text not null constraint articles_slug_check check (slug ~ '^[0-9a-z가-힣][0-9a-z가-힣-]{0,119}$'),
  title               text not null constraint articles_title_check check (char_length(btrim(title)) between 1 and 300),
  subtitle            text constraint articles_subtitle_check check (subtitle is null or char_length(subtitle) <= 300),
  summary             text constraint articles_summary_check check (summary is null or char_length(summary) <= 1000),
  body                jsonb not null default '[]'::jsonb constraint articles_body_check check (jsonb_typeof(body) = 'array' and jsonb_array_length(body) <= 2000),
  body_text           text not null default '' constraint articles_body_text_check check (char_length(body_text) <= 200000),
  type                text not null default 'original'
                      constraint articles_type_check check (type in ('original', 'wire', 'press_release', 'contribution', 'sponsored')),
  origin              text not null default 'human'
                      constraint articles_origin_check check (origin in ('human', 'ai_press_release', 'import')),
  section_id          uuid,
  author_id           uuid,
  byline              text not null constraint articles_byline_check check (char_length(btrim(byline)) between 1 and 100),
  status              text not null default 'draft'
                      constraint articles_status_check check (status in ('draft', 'submitted', 'approved', 'scheduled', 'published', 'unpublished', 'archived')),
  is_premium          boolean not null default false,
  sponsor_label       text,
  ai_assisted         boolean not null default false,
  ai_disclosure       text,
  wire_contract_id    uuid,
  source_note         text constraint articles_source_note_check check (source_note is null or char_length(source_note) <= 300),
  is_poll             boolean not null default false,
  poll_disclosure     text,
  is_breaking         boolean not null default false,
  is_live             boolean not null default false,
  comments_enabled    boolean not null default true,
  embargo_until       timestamptz,
  hero_media_id       uuid,
  media_ids           uuid[] not null default '{}' constraint articles_media_ids_check check (cardinality(media_ids) <= 200),
  seo                 jsonb not null default '{}'::jsonb constraint articles_seo_check check (jsonb_typeof(seo) = 'object'),
  review_note         text constraint articles_review_note_check check (review_note is null or char_length(review_note) <= 2000),
  submitted_at        timestamptz,
  submitted_by        uuid,
  approved_at         timestamptz,
  approved_by         uuid,
  scheduled_for       timestamptz,
  published_at        timestamptz,
  first_published_at  timestamptz,
  unpublished_at      timestamptz,
  unpublish_reason    text constraint articles_unpublish_reason_check check (unpublish_reason is null or char_length(unpublish_reason) <= 500),
  archived_at         timestamptz,
  revised_at          timestamptz,
  revision_note       text constraint articles_revision_note_check check (revision_note is null or char_length(revision_note) <= 500),
  revision_count      integer not null default 0,
  last_corrected_at   timestamptz,
  correction_count    integer not null default 0,
  legacy_id           text constraint articles_legacy_id_check check (legacy_id is null or char_length(legacy_id) <= 200),
  legacy_url          text constraint articles_legacy_url_check check (legacy_url is null or char_length(legacy_url) <= 1000),
  search_tsv          tsvector,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (org_id, slug),
  unique (id, org_id),
  foreign key (section_id, org_id) references news.sections (id, org_id),
  foreign key (wire_contract_id, org_id) references news.wire_contracts (id, org_id),
  foreign key (hero_media_id, org_id) references news.media_assets (id, org_id),
  -- 신문법 제6조 제3항: 기사형 광고는 허용 목록의 라벨이 반드시 붙고, 다른 유형에는 라벨을 붙이지 않는다
  constraint articles_sponsor_label_check check (
    (type = 'sponsored' and sponsor_label is not null and sponsor_label in ('광고', '기사형 광고', '후원 콘텐츠', '협찬', 'AD'))
    or (type <> 'sponsored' and sponsor_label is null)),
  -- AI기본법·언론계 생성형 AI 준칙: AI 보조 기사는 고지 문구 필수
  constraint articles_ai_disclosure_check check (not ai_assisted or (ai_disclosure is not null and char_length(btrim(ai_disclosure)) between 5 and 300)),
  -- 보도자료 AI 초안은 보도자료 유형과 AI 표시를 유지한다(자체기사로 세탁 금지, 결정 D-9)
  constraint articles_ai_origin_check check (origin <> 'ai_press_release' or (type = 'press_release' and ai_assisted)),
  constraint articles_wire_contract_check check (wire_contract_id is null or type = 'wire'),
  -- 공직선거법 제108조: 여론조사 보도는 조사기관·표본 등 필수 표시
  constraint articles_poll_disclosure_check check (not is_poll or (poll_disclosure is not null and char_length(btrim(poll_disclosure)) between 10 and 1000)),
  constraint articles_published_at_check check (status not in ('published', 'unpublished') or (published_at is not null and first_published_at is not null)),
  constraint articles_scheduled_for_check check (status <> 'scheduled' or scheduled_for is not null)
);
create index if not exists articles_org_status_idx on news.articles (org_id, status, updated_at desc);
create index if not exists articles_public_idx on news.articles (org_id, published_at desc) where status = 'published';
create index if not exists articles_section_public_idx on news.articles (org_id, section_id, published_at desc) where status = 'published';
create index if not exists articles_scheduled_idx on news.articles (scheduled_for) where status = 'scheduled';
create index if not exists articles_first_published_idx on news.articles (org_id, first_published_at) where first_published_at is not null;
create index if not exists articles_author_idx on news.articles (org_id, created_by, status);
create index if not exists articles_search_idx on news.articles using gin (search_tsv);
create index if not exists articles_title_trgm_idx on news.articles using gin (title extensions.gin_trgm_ops);
create unique index if not exists articles_legacy_uniq on news.articles (org_id, legacy_id) where legacy_id is not null;

create or replace function news.articles_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.org_id is distinct from old.org_id or new.origin is distinct from old.origin
       or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at then
      raise exception 'articles: org_id/origin/created_by/created_at are immutable' using errcode = '22023';
    end if;
    if old.first_published_at is not null and new.first_published_at is distinct from old.first_published_at then
      raise exception 'articles: first_published_at is immutable' using errcode = '22023';
    end if;
    if new.status is distinct from old.status then
      if not (
           (old.status = 'draft'       and new.status in ('submitted', 'archived'))
        or (old.status = 'submitted'   and new.status in ('approved', 'draft'))
        or (old.status = 'approved'    and new.status in ('scheduled', 'published', 'draft'))
        or (old.status = 'scheduled'   and new.status in ('published', 'approved'))
        or (old.status = 'published'   and new.status in ('unpublished', 'archived'))
        or (old.status = 'unpublished' and new.status in ('published', 'draft', 'archived'))
      ) then
        raise exception 'articles: invalid status transition % -> %', old.status, new.status using errcode = '22023';
      end if;
      if new.status = 'submitted' then new.submitted_at := now(); end if;
      if new.status = 'approved' and old.status = 'submitted' then new.approved_at := now(); end if;
      if new.status = 'draft' then new.approved_at := null; new.approved_by := null; new.scheduled_for := null; end if;
      if new.status = 'approved' and old.status = 'scheduled' then new.scheduled_for := null; end if;
      if new.status = 'published' then
        new.published_at := coalesce(case when old.status = 'scheduled' then old.scheduled_for end, now());
        new.first_published_at := coalesce(old.first_published_at, new.published_at);
        new.unpublished_at := null;
      end if;
      if new.status = 'unpublished' then new.unpublished_at := now(); end if;
      if new.status = 'archived' then new.archived_at := now(); end if;
    end if;
  else
    if new.status <> 'draft' then
      raise exception 'articles: new articles start as draft' using errcode = '22023';
    end if;
  end if;
  new.search_tsv :=
       setweight(to_tsvector('simple'::regconfig, coalesce(new.title, '')), 'A')
    || setweight(to_tsvector('simple'::regconfig, coalesce(new.subtitle, '') || ' ' || coalesce(new.summary, '')), 'B')
    || setweight(to_tsvector('simple'::regconfig, left(coalesce(new.body_text, ''), 100000)), 'C');
  return new;
end;
$$;
drop trigger if exists articles_before_write on news.articles;
create trigger articles_before_write before insert or update on news.articles
  for each row execute function news.articles_before_write();

-- ---------------------------------------------------------------------
-- 1.7 article_revisions: 저장·워크플로·정정 이력(append-only). is_public=true 인 행의 note 만 독자에게 보인다
--     (news.read_article 이 수정·정정 이력으로 돌려준다. NW-F-017).
-- ---------------------------------------------------------------------
create table if not exists news.article_revisions (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  article_id             uuid not null,
  kind                   text not null constraint article_revisions_kind_check check (kind in (
                           'save', 'submit', 'approve', 'reject', 'schedule', 'publish', 'unpublish', 'archive',
                           'update', 'correction', 'clarification', 'rebuttal', 'follow_up')),
  status_after           text not null,
  title                  text,
  body                   jsonb,
  note                   text constraint article_revisions_note_check check (note is null or char_length(note) <= 2000),
  is_public              boolean not null default false,
  correction_request_id  uuid,
  created_by             uuid,
  created_at             timestamptz not null default now(),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete cascade,
  constraint article_revisions_public_note_check check (not is_public or (note is not null and kind in ('update', 'correction', 'clarification', 'rebuttal', 'follow_up')))
);
create index if not exists article_revisions_article_idx on news.article_revisions (article_id, created_at desc);

create or replace function news.article_revisions_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'news.article_revisions is append-only' using errcode = '22023';
end;
$$;
drop trigger if exists article_revisions_immutable on news.article_revisions;
create trigger article_revisions_immutable before update on news.article_revisions
  for each row execute function news.article_revisions_immutable();

-- ---------------------------------------------------------------------
-- 1.8 article_regions / article_tags: 기사-지역, 기사-태그 (save_article 이 통째로 바꾼다)
-- ---------------------------------------------------------------------
create table if not exists news.article_regions (
  org_id      uuid not null references core.organizations(id) on delete cascade,
  article_id  uuid not null,
  region_id   uuid not null,
  created_at  timestamptz not null default now(),
  primary key (article_id, region_id),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete cascade,
  foreign key (region_id, org_id) references news.regions (id, org_id)
);
create index if not exists article_regions_region_idx on news.article_regions (org_id, region_id);

create table if not exists news.article_tags (
  org_id      uuid not null references core.organizations(id) on delete cascade,
  article_id  uuid not null,
  tag_id      uuid not null,
  created_at  timestamptz not null default now(),
  primary key (article_id, tag_id),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete cascade,
  foreign key (tag_id, org_id) references news.tags (id, org_id)
);
create index if not exists article_tags_tag_idx on news.article_tags (org_id, tag_id);

-- ---------------------------------------------------------------------
-- 1.9 home_layouts: 홈 편집(NW-F-013). 템플릿 traditional(A)·magazine(B)·feed(C), 블록 배열.
--     draft -> scheduled | published | archived, scheduled -> draft | published, published -> archived, archived -> (없음)
--     조직당 published 1개(부분 유니크). 새 판을 게시하면 이전 게시본은 archived.
-- ---------------------------------------------------------------------
create table if not exists news.home_layouts (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  name          text not null constraint home_layouts_name_check check (char_length(btrim(name)) between 1 and 80),
  template      text not null constraint home_layouts_template_check check (template in ('traditional', 'magazine', 'feed')),
  blocks        jsonb not null default '[]'::jsonb constraint home_layouts_blocks_check check (jsonb_typeof(blocks) = 'array' and jsonb_array_length(blocks) <= 60),
  status        text not null default 'draft' constraint home_layouts_status_check check (status in ('draft', 'scheduled', 'published', 'archived')),
  publish_at    timestamptz,
  published_at  timestamptz,
  published_by  uuid,
  version       integer not null default 0,
  archived_at   timestamptz,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint home_layouts_publish_at_check check (status <> 'scheduled' or publish_at is not null)
);
create unique index if not exists home_layouts_one_published_idx on news.home_layouts (org_id) where status = 'published';
create index if not exists home_layouts_scheduled_idx on news.home_layouts (publish_at) where status = 'scheduled';

create or replace function news.home_layouts_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'home_layouts: org_id is immutable' using errcode = '22023';
  end if;
  if old.status in ('published', 'archived') and (new.blocks is distinct from old.blocks or new.template is distinct from old.template) then
    raise exception 'home_layouts: published layouts are read-only (clone instead)' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'draft'     and new.status in ('scheduled', 'published', 'archived'))
      or (old.status = 'scheduled' and new.status in ('draft', 'published'))
      or (old.status = 'published' and new.status = 'archived')
    ) then
      raise exception 'home_layouts: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'published' then new.published_at := now(); end if;
    if new.status = 'archived'  then new.archived_at := now(); end if;
    if new.status = 'draft'     then new.publish_at := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists home_layouts_before_update on news.home_layouts;
create trigger home_layouts_before_update before update on news.home_layouts
  for each row execute function news.home_layouts_before_update();

-- ---------------------------------------------------------------------
-- 1.10 print_editions: 지면 PDF(NW-F-015, Pro). PDF 는 org-files/<org>/news/print/ (서명 URL 로 제공)
-- ---------------------------------------------------------------------
create table if not exists news.print_editions (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  edition_date  date not null,
  issue_no      integer constraint print_editions_issue_no_check check (issue_no is null or issue_no between 1 and 1000000),
  title         text constraint print_editions_title_check check (title is null or char_length(title) <= 120),
  pdf_path      text not null,
  page_count    integer constraint print_editions_page_count_check check (page_count is null or page_count between 1 and 400),
  status        text not null default 'draft' constraint print_editions_status_check check (status in ('draft', 'published', 'archived')),
  published_at  timestamptz,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint print_editions_pdf_path_check check (news.is_org_path(org_id, pdf_path, 'print') and pdf_path like '%.pdf')
);
create unique index if not exists print_editions_issue_uniq on news.print_editions (org_id, issue_no) where issue_no is not null;
create index if not exists print_editions_org_date_idx on news.print_editions (org_id, edition_date desc);

-- ---------------------------------------------------------------------
-- 1.11 live_updates: 라이브 기사 타임라인(NW-F-016)
-- ---------------------------------------------------------------------
create table if not exists news.live_updates (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  article_id  uuid not null,
  body        text not null constraint live_updates_body_check check (char_length(btrim(body)) between 1 and 5000),
  is_pinned   boolean not null default false,
  status      text not null default 'visible' constraint live_updates_status_check check (status in ('visible', 'hidden')),
  posted_at   timestamptz not null default now(),
  posted_by   uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete cascade
);
create index if not exists live_updates_article_idx on news.live_updates (article_id, posted_at desc);

-- =====================================================================
-- M2. reader-membership
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.1 readers: 신문사별 독자 행. 같은 사람이 A·B 신문의 독자가 될 수 있다(플랫폼 공통 계정). 조직 멤버가 아니다.
--     만 14세 미만 가입은 받지 않는다(is_over_14 = true 필수, 법정대리인 동의 흐름은 Phase 2).
--     상태: active -> blocked | withdrawn, blocked -> active | withdrawn, withdrawn -> active(재가입)
-- ---------------------------------------------------------------------
create table if not exists news.readers (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  user_id              uuid not null references auth.users(id) on delete cascade,
  nickname             text not null constraint readers_nickname_check check (char_length(btrim(nickname)) between 2 and 20),
  email                text constraint readers_email_check check (email is null or (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  status               text not null default 'active' constraint readers_status_check check (status in ('active', 'blocked', 'withdrawn')),
  blocked_reason       text constraint readers_blocked_reason_check check (blocked_reason is null or char_length(blocked_reason) <= 500),
  blocked_at           timestamptz,
  is_over_14           boolean not null constraint readers_is_over_14_check check (is_over_14),
  terms_version        text not null constraint readers_terms_version_check check (char_length(terms_version) between 1 and 32),
  privacy_version      text not null constraint readers_privacy_version_check check (char_length(privacy_version) between 1 and 32),
  consent_at           timestamptz not null default now(),
  marketing_opt_in     boolean not null default false,
  marketing_opt_in_at  timestamptz,
  region_id            uuid,
  last_seen_at         timestamptz,
  withdrawn_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (org_id, user_id),
  unique (id, org_id),
  foreign key (region_id, org_id) references news.regions (id, org_id)
);
create unique index if not exists readers_nickname_uniq on news.readers (org_id, lower(nickname)) where status <> 'withdrawn';
create index if not exists readers_org_created_idx on news.readers (org_id, created_at desc);

create or replace function news.readers_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.user_id is distinct from old.user_id then
    raise exception 'readers: org_id/user_id are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'active'    and new.status in ('blocked', 'withdrawn'))
      or (old.status = 'blocked'   and new.status in ('active', 'withdrawn'))
      or (old.status = 'withdrawn' and new.status = 'active')
    ) then
      raise exception 'readers: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'blocked'   then new.blocked_at := now(); end if;
    if new.status = 'active'    then new.blocked_at := null; new.blocked_reason := null; new.withdrawn_at := null; end if;
    if new.status = 'withdrawn' then new.withdrawn_at := now(); new.email := null; new.marketing_opt_in := false; end if;
  end if;
  if new.marketing_opt_in and not old.marketing_opt_in then new.marketing_opt_in_at := now(); end if;
  return new;
end;
$$;
drop trigger if exists readers_before_update on news.readers;
create trigger readers_before_update before update on news.readers
  for each row execute function news.readers_before_update();

-- ---------------------------------------------------------------------
-- 2.2 membership_tiers / memberships / donations / paywall_rules
--     결제는 신문사 자기 Toss 가맹(결정 D-4). 가맹 키는 core.encrypted_credentials(provider 'toss_merchant', app 'news')에만 둔다.
--     memberships·donations 는 service_role(결제 확인 Route Handler, 웹훅)만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists news.membership_tiers (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  code              text not null constraint membership_tiers_code_check check (code ~ '^[a-z][a-z0-9_]{1,30}$'),
  name              text not null constraint membership_tiers_name_check check (char_length(btrim(name)) between 1 and 40),
  description       text constraint membership_tiers_description_check check (description is null or char_length(description) <= 1000),
  price_krw         integer not null constraint membership_tiers_price_check check (price_krw between 1000 and 10000000),
  billing_interval  text not null default 'month' constraint membership_tiers_interval_check check (billing_interval in ('month', 'year')),
  benefits          jsonb not null default '[]'::jsonb constraint membership_tiers_benefits_check check (jsonb_typeof(benefits) = 'array'),
  is_active         boolean not null default true,
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

create table if not exists news.memberships (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  reader_id              uuid not null,
  tier_id                uuid not null,
  status                 text not null default 'pending'
                         constraint memberships_status_check check (status in ('pending', 'active', 'past_due', 'canceled', 'expired')),
  started_at             timestamptz,
  current_period_start   timestamptz,
  current_period_end     timestamptz,
  cancel_at_period_end   boolean not null default false,
  canceled_at            timestamptz,
  ended_at               timestamptz,
  provider               text not null default 'toss' constraint memberships_provider_check check (provider in ('toss')),
  billing_credential_id  uuid references core.encrypted_credentials(id) on delete set null,
  external_ref           text constraint memberships_external_ref_check check (external_ref is null or char_length(external_ref) <= 200),
  last_event_id          text,
  platform_fee_bps       integer not null default 0 constraint memberships_platform_fee_bps_check check (platform_fee_bps between 0 and 3000),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete cascade,
  foreign key (tier_id, org_id) references news.membership_tiers (id, org_id)
);
create unique index if not exists memberships_one_live_idx on news.memberships (reader_id) where status in ('pending', 'active', 'past_due');
create index if not exists memberships_org_status_idx on news.memberships (org_id, status);

create or replace function news.memberships_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.reader_id is distinct from old.reader_id then
    raise exception 'memberships: org_id/reader_id are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'pending'  and new.status in ('active', 'canceled', 'expired'))
      or (old.status = 'active'   and new.status in ('past_due', 'canceled', 'expired'))
      or (old.status = 'past_due' and new.status in ('active', 'canceled', 'expired'))
      or (old.status = 'canceled' and new.status in ('active', 'expired'))
    ) then
      raise exception 'memberships: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'active'   then new.started_at := coalesce(old.started_at, now()); new.canceled_at := null; new.cancel_at_period_end := false; end if;
    if new.status = 'canceled' then new.canceled_at := now(); end if;
    if new.status = 'expired'  then new.ended_at := now(); end if;
  end if;
  return new;
end;
$$;
drop trigger if exists memberships_before_update on news.memberships;
create trigger memberships_before_update before update on news.memberships
  for each row execute function news.memberships_before_update();

create table if not exists news.donations (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  reader_id            uuid,
  donor_display_name   text constraint donations_donor_display_name_check check (donor_display_name is null or char_length(btrim(donor_display_name)) between 1 and 40),
  is_anonymous         boolean not null default true,
  message              text constraint donations_message_check check (message is null or char_length(message) <= 300),
  amount_krw           integer not null constraint donations_amount_check check (amount_krw between 1000 and 10000000),
  kind                 text not null default 'once' constraint donations_kind_check check (kind in ('once', 'recurring')),
  status               text not null default 'pending' constraint donations_status_check check (status in ('pending', 'paid', 'failed', 'canceled', 'refunded')),
  order_id             text not null unique constraint donations_order_id_check check (order_id ~ '^[A-Za-z0-9_-]{6,64}$'),
  payment_key          text unique,
  paid_at              timestamptz,
  canceled_at          timestamptz,
  refunded_amount_krw  integer not null default 0 constraint donations_refunded_check check (refunded_amount_krw >= 0),
  platform_fee_bps     integer not null default 0 constraint donations_platform_fee_bps_check check (platform_fee_bps between 0 and 3000),
  platform_fee_krw     integer not null default 0 constraint donations_platform_fee_krw_check check (platform_fee_krw >= 0),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete set null (reader_id),
  constraint donations_refund_le_amount_check check (refunded_amount_krw <= amount_krw)
);
create index if not exists donations_org_created_idx on news.donations (org_id, created_at desc);

create or replace function news.donations_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.order_id is distinct from old.order_id or new.amount_krw is distinct from old.amount_krw then
    raise exception 'donations: org_id/order_id/amount_krw are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'pending' and new.status in ('paid', 'failed', 'canceled'))
      or (old.status = 'paid'    and new.status in ('canceled', 'refunded'))
    ) then
      raise exception 'donations: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'paid' then new.paid_at := coalesce(new.paid_at, now()); end if;
    if new.status in ('canceled', 'refunded') then new.canceled_at := now(); end if;
  end if;
  return new;
end;
$$;
drop trigger if exists donations_before_update on news.donations;
create trigger donations_before_update before update on news.donations
  for each row execute function news.donations_before_update();

create table if not exists news.paywall_rules (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null unique references core.organizations(id) on delete cascade,
  mode                     text not null default 'off' constraint paywall_rules_mode_check check (mode in ('off', 'meter', 'premium_only', 'meter_and_premium')),
  free_articles_per_month  integer not null default 10 constraint paywall_rules_free_articles_check check (free_articles_per_month between 0 and 100),
  exempt_types             text[] not null default '{press_release}'
                           constraint paywall_rules_exempt_types_check check (exempt_types <@ array['original', 'wire', 'press_release', 'contribution', 'sponsored']),
  cta_text                 text constraint paywall_rules_cta_text_check check (cta_text is null or char_length(cta_text) <= 200),
  updated_by               uuid,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- =====================================================================
-- M3. ad-manager (광고, 업소 디렉토리, 지자체 공고)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 ad_slots: IAB 고정 슬롯. 폭·높이는 레이아웃 공간 예약(CLS)용이라 필수.
-- ---------------------------------------------------------------------
create table if not exists news.ad_slots (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  code        text not null constraint ad_slots_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name        text not null constraint ad_slots_name_check check (char_length(btrim(name)) between 1 and 60),
  placement   text not null constraint ad_slots_placement_check check (placement in ('home', 'section', 'article', 'mobile', 'all')),
  width       integer not null constraint ad_slots_width_check check (width between 1 and 2000),
  height      integer not null constraint ad_slots_height_check check (height between 1 and 2000),
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (org_id, code),
  unique (id, org_id)
);

-- ---------------------------------------------------------------------
-- 3.2 advertisers: 광고주. 정부·지자체(is_government)는 직판 캠페인을 만들 수 없다(정부광고법: 언론진흥재단 대행, NW013).
-- ---------------------------------------------------------------------
create table if not exists news.advertisers (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  name           text not null constraint advertisers_name_check check (char_length(btrim(name)) between 1 and 80),
  kind           text not null default 'local_business'
                 constraint advertisers_kind_check check (kind in ('local_business', 'agency', 'institution', 'house', 'other')),
  is_government  boolean not null default false,
  business_no    text constraint advertisers_business_no_check check (business_no is null or business_no ~ '^[0-9]{3}-?[0-9]{2}-?[0-9]{5}$'),
  contact_name   text constraint advertisers_contact_name_check check (contact_name is null or char_length(contact_name) <= 40),
  contact_email  text constraint advertisers_contact_email_check check (contact_email is null or (char_length(contact_email) <= 254 and contact_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  contact_phone  text constraint advertisers_contact_phone_check check (contact_phone is null or contact_phone ~ '^[0-9+() -]{6,30}$'),
  note           text constraint advertisers_note_check check (note is null or char_length(note) <= 1000),
  status         text not null default 'active' constraint advertisers_status_check check (status in ('active', 'archived')),
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (id, org_id)
);

-- ---------------------------------------------------------------------
-- 3.3 ad_campaigns: draft -> active | canceled, active -> paused | ended, paused -> active | ended
-- ---------------------------------------------------------------------
create table if not exists news.ad_campaigns (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  advertiser_id  uuid not null,
  name           text not null constraint ad_campaigns_name_check check (char_length(btrim(name)) between 1 and 80),
  pricing        text not null default 'flat' constraint ad_campaigns_pricing_check check (pricing in ('flat', 'cpm', 'cpc', 'house')),
  price_krw      integer not null default 0 constraint ad_campaigns_price_check check (price_krw between 0 and 1000000000),
  starts_at      timestamptz not null,
  ends_at        timestamptz not null,
  priority       smallint not null default 5 constraint ad_campaigns_priority_check check (priority between 1 and 10),
  status         text not null default 'draft' constraint ad_campaigns_status_check check (status in ('draft', 'active', 'paused', 'ended', 'canceled')),
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (id, org_id),
  foreign key (advertiser_id, org_id) references news.advertisers (id, org_id),
  constraint ad_campaigns_period_check check (ends_at > starts_at)
);
create index if not exists ad_campaigns_org_status_idx on news.ad_campaigns (org_id, status, starts_at);

create or replace function news.ad_campaigns_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'ad_campaigns: org_id is immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'draft'  and new.status in ('active', 'canceled'))
    or (old.status = 'active' and new.status in ('paused', 'ended'))
    or (old.status = 'paused' and new.status in ('active', 'ended'))
  ) then
    raise exception 'ad_campaigns: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists ad_campaigns_before_update on news.ad_campaigns;
create trigger ad_campaigns_before_update before update on news.ad_campaigns
  for each row execute function news.ad_campaigns_before_update();

-- ---------------------------------------------------------------------
-- 3.4 ad_creatives: 소재. 임의 HTML 은 받지 않는다(라벨 우회·XSS 차단). 외부 광고망은 네트워크 + 단위 ID 만.
--     label 은 허용 목록(광고, AD, 협찬, 후원)만. 노출은 news.serve_ads 가 라벨과 함께만 돌려준다.
--     pending_review -> approved | rejected, approved -> archived | pending_review(수정), rejected -> pending_review
-- ---------------------------------------------------------------------
create table if not exists news.ad_creatives (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  campaign_id       uuid not null,
  slot_id           uuid not null,
  kind              text not null constraint ad_creatives_kind_check check (kind in ('image', 'text', 'external')),
  media_path        text,
  external_network  text constraint ad_creatives_external_network_check check (external_network is null or external_network in ('gam', 'adsense')),
  external_unit_id  text constraint ad_creatives_external_unit_id_check check (external_unit_id is null or external_unit_id ~ '^[A-Za-z0-9/_.-]{3,120}$'),
  headline          text constraint ad_creatives_headline_check check (headline is null or char_length(headline) <= 80),
  click_url         text constraint ad_creatives_click_url_check check (click_url is null or (char_length(click_url) <= 1000 and click_url ~ '^https://[^[:space:]<>"]{3,}$')),
  alt_text          text constraint ad_creatives_alt_text_check check (alt_text is null or char_length(alt_text) <= 200),
  label             text not null default '광고' constraint ad_creatives_label_check check (label in ('광고', 'AD', '협찬', '후원')),
  status            text not null default 'pending_review'
                    constraint ad_creatives_status_check check (status in ('pending_review', 'approved', 'rejected', 'archived')),
  reviewed_by       uuid,
  reviewed_at       timestamptz,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  foreign key (campaign_id, org_id) references news.ad_campaigns (id, org_id) on delete cascade,
  foreign key (slot_id, org_id) references news.ad_slots (id, org_id),
  constraint ad_creatives_kind_fields_check check (
       (kind = 'image'    and media_path is not null and alt_text is not null and click_url is not null and external_network is null)
    or (kind = 'text'     and headline is not null and click_url is not null and media_path is null and external_network is null)
    or (kind = 'external' and external_network is not null and external_unit_id is not null and media_path is null)),
  constraint ad_creatives_media_path_check check (media_path is null or news.is_org_path(org_id, media_path, 'ads'))
);
create index if not exists ad_creatives_campaign_idx on news.ad_creatives (campaign_id, status);

create or replace function news.ad_creatives_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'ad_creatives: org_id is immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'pending_review' and new.status in ('approved', 'rejected', 'archived'))
    or (old.status = 'approved'       and new.status in ('archived', 'pending_review'))
    or (old.status = 'rejected'       and new.status in ('pending_review', 'archived'))
  ) then
    raise exception 'ad_creatives: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists ad_creatives_before_update on news.ad_creatives;
create trigger ad_creatives_before_update before update on news.ad_creatives
  for each row execute function news.ad_creatives_before_update();

-- ---------------------------------------------------------------------
-- 3.5 ad_daily_stats: 소재별 일(KST) 집계. record_ad_stats(service_role)만 증분한다.
-- ---------------------------------------------------------------------
create table if not exists news.ad_daily_stats (
  id           bigint generated always as identity primary key,
  org_id       uuid not null references core.organizations(id) on delete cascade,
  creative_id  uuid not null,
  day          date not null,
  impressions  bigint not null default 0 constraint ad_daily_stats_impressions_check check (impressions >= 0),
  clicks       bigint not null default 0 constraint ad_daily_stats_clicks_check check (clicks >= 0),
  updated_at   timestamptz not null default now(),
  unique (creative_id, day),
  foreign key (creative_id, org_id) references news.ad_creatives (id, org_id) on delete cascade
);
create index if not exists ad_daily_stats_org_day_idx on news.ad_daily_stats (org_id, day);

-- ---------------------------------------------------------------------
-- 3.6 local_listings: 지역 업소 셀프 광고·디렉토리(NW-F-033)
--     pending -> approved | rejected | canceled, approved -> active | canceled, active -> expired | canceled
-- ---------------------------------------------------------------------
create table if not exists news.local_listings (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  reader_id          uuid,
  applicant_user_id  uuid,
  business_name      text not null constraint local_listings_business_name_check check (char_length(btrim(business_name)) between 1 and 80),
  category           text not null constraint local_listings_category_check check (category in ('restaurant', 'cafe', 'shop', 'service', 'medical', 'education', 'lodging', 'other')),
  region_id          uuid,
  address            text constraint local_listings_address_check check (address is null or char_length(address) <= 200),
  phone              text constraint local_listings_phone_check check (phone is null or phone ~ '^[0-9+() -]{6,30}$'),
  url                text constraint local_listings_url_check check (url is null or (char_length(url) <= 500 and url ~ '^https://[^[:space:]<>"]{3,}$')),
  description        text constraint local_listings_description_check check (description is null or char_length(description) <= 1000),
  photo_path         text,
  contact_email      text constraint local_listings_contact_email_check check (contact_email is null or (char_length(contact_email) <= 254 and contact_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  status             text not null default 'pending'
                     constraint local_listings_status_check check (status in ('pending', 'approved', 'rejected', 'active', 'expired', 'canceled')),
  starts_at          timestamptz,
  ends_at            timestamptz,
  paid_at            timestamptz,
  payment_order_id   text constraint local_listings_payment_order_id_check check (payment_order_id is null or payment_order_id ~ '^[A-Za-z0-9_-]{6,64}$'),
  reviewed_by        uuid,
  reviewed_at        timestamptz,
  review_note        text constraint local_listings_review_note_check check (review_note is null or char_length(review_note) <= 500),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete set null (reader_id),
  foreign key (region_id, org_id) references news.regions (id, org_id),
  constraint local_listings_photo_path_check check (photo_path is null or news.is_org_path(org_id, photo_path, 'listings')),
  constraint local_listings_active_period_check check (status <> 'active' or (starts_at is not null and ends_at is not null and ends_at > starts_at))
);
create index if not exists local_listings_org_status_idx on news.local_listings (org_id, status, ends_at);

create or replace function news.local_listings_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'local_listings: org_id is immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'pending'  and new.status in ('approved', 'rejected', 'canceled'))
    or (old.status = 'approved' and new.status in ('active', 'canceled'))
    or (old.status = 'active'   and new.status in ('expired', 'canceled'))
  ) then
    raise exception 'local_listings: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists local_listings_before_update on news.local_listings;
create trigger local_listings_before_update before update on news.local_listings
  for each row execute function news.local_listings_before_update();

-- ---------------------------------------------------------------------
-- 3.7 public_notices: 지자체 공고 게재(NW-F-034). 정부광고 대금은 언론진흥재단 경유라 결제 컬럼이 없고 청약 참조만 둔다.
--     draft -> published | archived, published -> archived
-- ---------------------------------------------------------------------
create table if not exists news.public_notices (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  issuer_name        text not null constraint public_notices_issuer_name_check check (char_length(btrim(issuer_name)) between 1 and 80),
  notice_no          text constraint public_notices_notice_no_check check (notice_no is null or char_length(notice_no) <= 60),
  title              text not null constraint public_notices_title_check check (char_length(btrim(title)) between 1 and 200),
  body               text not null constraint public_notices_body_check check (char_length(body) between 1 and 20000),
  region_id          uuid,
  attachment_path    text,
  government_ad_ref  text constraint public_notices_government_ad_ref_check check (government_ad_ref is null or char_length(government_ad_ref) <= 60),
  posted_from        timestamptz,
  posted_until       timestamptz,
  status             text not null default 'draft' constraint public_notices_status_check check (status in ('draft', 'published', 'archived')),
  published_at       timestamptz,
  archived_at        timestamptz,
  created_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  foreign key (region_id, org_id) references news.regions (id, org_id),
  constraint public_notices_attachment_path_check check (attachment_path is null or news.is_org_path(org_id, attachment_path, 'notices')),
  constraint public_notices_period_check check (posted_until is null or posted_from is null or posted_until > posted_from)
);
create index if not exists public_notices_org_status_idx on news.public_notices (org_id, status, published_at desc);

create or replace function news.public_notices_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'public_notices: org_id is immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not ((old.status = 'draft' and new.status in ('published', 'archived')) or (old.status = 'published' and new.status = 'archived')) then
      raise exception 'public_notices: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'published' then new.published_at := now(); end if;
    if new.status = 'archived'  then new.archived_at := now(); end if;
  end if;
  return new;
end;
$$;
drop trigger if exists public_notices_before_update on news.public_notices;
create trigger public_notices_before_update before update on news.public_notices
  for each row execute function news.public_notices_before_update();

-- =====================================================================
-- M4. notify-newsletter
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 newsletter_lists
-- ---------------------------------------------------------------------
create table if not exists news.newsletter_lists (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  slug             text not null constraint newsletter_lists_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{0,39}$'),
  name             text not null constraint newsletter_lists_name_check check (char_length(btrim(name)) between 1 and 60),
  description      text constraint newsletter_lists_description_check check (description is null or char_length(description) <= 500),
  kind             text not null default 'custom' constraint newsletter_lists_kind_check check (kind in ('morning_brief', 'breaking', 'weekly', 'custom')),
  is_public        boolean not null default true,
  contains_ads     boolean not null default false,
  consent_version  text not null default 'v1' constraint newsletter_lists_consent_version_check check (char_length(consent_version) between 1 and 32),
  status           text not null default 'active' constraint newsletter_lists_status_check check (status in ('active', 'archived')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (org_id, slug),
  unique (id, org_id)
);

-- ---------------------------------------------------------------------
-- 4.2 newsletter_subscriptions: 이중 동의. 토큰 원문은 저장하지 않는다(sha256 해시만). 원문은 발급 RPC 가 service_role 에게 한 번만 돌려준다.
--     reconfirm_due_at = 확인(또는 재확인) 시각 + 2년(정보통신망법 수신동의 2년 확인). 트리거가 계산한다.
--     pending -> confirmed | unsubscribed, confirmed -> unsubscribed | bounced, unsubscribed -> pending, bounced -> pending
-- ---------------------------------------------------------------------
create table if not exists news.newsletter_subscriptions (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references core.organizations(id) on delete cascade,
  list_id                 uuid not null,
  reader_id               uuid,
  email                   text constraint newsletter_subscriptions_email_check check (email is null or (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  email_hash              text not null constraint newsletter_subscriptions_email_hash_check check (email_hash ~ '^[0-9a-f]{64}$'),
  status                  text not null default 'pending'
                          constraint newsletter_subscriptions_status_check check (status in ('pending', 'confirmed', 'unsubscribed', 'bounced')),
  confirm_token_hash      text constraint newsletter_subscriptions_confirm_token_hash_check check (confirm_token_hash is null or confirm_token_hash ~ '^[0-9a-f]{64}$'),
  confirm_expires_at      timestamptz,
  confirm_sent_count      smallint not null default 0,
  unsubscribe_token_hash  text not null constraint newsletter_subscriptions_unsub_token_hash_check check (unsubscribe_token_hash ~ '^[0-9a-f]{64}$'),
  consent_version         text not null,
  consent_at              timestamptz not null default now(),
  ad_consent              boolean not null default false,
  night_consent           boolean not null default false,
  confirmed_at            timestamptz,
  reconfirmed_at          timestamptz,
  reconfirm_due_at        timestamptz,
  unsubscribed_at         timestamptz,
  unsubscribe_reason      text constraint newsletter_subscriptions_unsub_reason_check check (unsubscribe_reason is null or char_length(unsubscribe_reason) <= 200),
  source_path             text constraint newsletter_subscriptions_source_path_check check (source_path is null or (char_length(source_path) <= 200 and source_path like '/%')),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique (list_id, email_hash),
  foreign key (list_id, org_id) references news.newsletter_lists (id, org_id) on delete cascade,
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete set null (reader_id),
  constraint newsletter_subscriptions_email_present_check check (email is not null or status in ('unsubscribed', 'bounced')),
  constraint newsletter_subscriptions_pending_token_check check (status <> 'pending' or confirm_token_hash is not null)
);
create unique index if not exists newsletter_subscriptions_confirm_token_uniq on news.newsletter_subscriptions (confirm_token_hash) where confirm_token_hash is not null;
create unique index if not exists newsletter_subscriptions_unsub_token_uniq on news.newsletter_subscriptions (unsubscribe_token_hash);
create index if not exists newsletter_subscriptions_list_status_idx on news.newsletter_subscriptions (list_id, status);
create index if not exists newsletter_subscriptions_reconfirm_idx on news.newsletter_subscriptions (reconfirm_due_at) where status = 'confirmed';

create or replace function news.newsletter_subscriptions_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.org_id is distinct from old.org_id or new.list_id is distinct from old.list_id or new.email_hash is distinct from old.email_hash then
      raise exception 'newsletter_subscriptions: org_id/list_id/email_hash are immutable' using errcode = '22023';
    end if;
    if new.status is distinct from old.status then
      if not (
           (old.status = 'pending'      and new.status in ('confirmed', 'unsubscribed'))
        or (old.status = 'confirmed'    and new.status in ('unsubscribed', 'bounced'))
        or (old.status = 'unsubscribed' and new.status = 'pending')
        or (old.status = 'bounced'      and new.status = 'pending')
      ) then
        raise exception 'newsletter_subscriptions: invalid status transition % -> %', old.status, new.status using errcode = '22023';
      end if;
      if new.status = 'confirmed' then new.confirmed_at := now(); new.reconfirmed_at := null; end if;
      if new.status = 'unsubscribed' then new.unsubscribed_at := now(); new.confirm_token_hash := null; end if;
      if new.status = 'pending' then new.confirmed_at := null; new.unsubscribed_at := null; new.reconfirmed_at := null; end if;
    end if;
    if new.reconfirm_due_at is distinct from old.reconfirm_due_at then
      raise exception 'newsletter_subscriptions: reconfirm_due_at is computed' using errcode = '22023';
    end if;
  end if;
  new.reconfirm_due_at := case when new.status = 'confirmed'
                               then coalesce(new.reconfirmed_at, new.confirmed_at) + interval '2 years' end;
  return new;
end;
$$;
drop trigger if exists newsletter_subscriptions_before_write on news.newsletter_subscriptions;
create trigger newsletter_subscriptions_before_write before insert or update on news.newsletter_subscriptions
  for each row execute function news.newsletter_subscriptions_before_write();

-- ---------------------------------------------------------------------
-- 4.3 newsletter_issues: 발송 회차. 광고 포함이면 제목이 '(광고)'로 시작해야 한다(정보통신망법 제50조).
--     draft -> scheduled | canceled, scheduled -> draft | sending | canceled, sending -> sent | failed
-- ---------------------------------------------------------------------
create table if not exists news.newsletter_issues (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  list_id           uuid not null,
  subject           text not null constraint newsletter_issues_subject_check check (char_length(btrim(subject)) between 1 and 200),
  preheader         text constraint newsletter_issues_preheader_check check (preheader is null or char_length(preheader) <= 200),
  body              jsonb not null default '[]'::jsonb constraint newsletter_issues_body_check check (jsonb_typeof(body) = 'array'),
  article_ids       uuid[] not null default '{}' constraint newsletter_issues_article_ids_check check (cardinality(article_ids) <= 50),
  contains_ad       boolean not null default false,
  status            text not null default 'draft'
                    constraint newsletter_issues_status_check check (status in ('draft', 'scheduled', 'sending', 'sent', 'canceled', 'failed')),
  scheduled_at      timestamptz,
  sent_at           timestamptz,
  recipients_count  integer not null default 0,
  delivered_count   integer not null default 0,
  open_count        integer not null default 0,
  click_count       integer not null default 0,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  foreign key (list_id, org_id) references news.newsletter_lists (id, org_id) on delete cascade,
  constraint newsletter_issues_ad_subject_check check (not contains_ad or subject like '(광고)%'),
  constraint newsletter_issues_scheduled_check check (status <> 'scheduled' or scheduled_at is not null)
);
create index if not exists newsletter_issues_due_idx on news.newsletter_issues (scheduled_at) where status = 'scheduled';
create index if not exists newsletter_issues_list_idx on news.newsletter_issues (list_id, created_at desc);

create or replace function news.newsletter_issues_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.list_id is distinct from old.list_id then
    raise exception 'newsletter_issues: org_id/list_id are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'draft'     and new.status in ('scheduled', 'canceled'))
      or (old.status = 'scheduled' and new.status in ('draft', 'sending', 'canceled'))
      or (old.status = 'sending'   and new.status in ('sent', 'failed'))
    ) then
      raise exception 'newsletter_issues: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'sent' then new.sent_at := now(); end if;
  end if;
  if old.status not in ('draft', 'scheduled') and (new.subject is distinct from old.subject or new.body is distinct from old.body) then
    raise exception 'newsletter_issues: content is read-only after sending starts' using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists newsletter_issues_before_update on news.newsletter_issues;
create trigger newsletter_issues_before_update before update on news.newsletter_issues
  for each row execute function news.newsletter_issues_before_update();

-- ---------------------------------------------------------------------
-- 4.4 push_subscriptions: 속보 웹 푸시(NW-F-038). 브라우저 구독 정보라 사용자·방문자 모두 직접 접근 불가(service_role 전용).
-- ---------------------------------------------------------------------
create table if not exists news.push_subscriptions (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  reader_id      uuid,
  endpoint       text not null constraint push_subscriptions_endpoint_check check ((char_length(endpoint) <= 2000 and endpoint ~ '^https://[^[:space:]]{10,}$')),
  endpoint_hash  text not null constraint push_subscriptions_endpoint_hash_check check (endpoint_hash ~ '^[0-9a-f]{64}$'),
  p256dh         text not null constraint push_subscriptions_p256dh_check check (char_length(p256dh) between 40 and 200),
  auth_secret    text not null constraint push_subscriptions_auth_secret_check check (char_length(auth_secret) between 16 and 100),
  topics         text[] not null default '{breaking}' constraint push_subscriptions_topics_check check (topics <@ array['breaking', 'morning', 'local']),
  status         text not null default 'active' constraint push_subscriptions_status_check check (status in ('active', 'revoked')),
  failure_count  integer not null default 0,
  last_sent_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (org_id, endpoint_hash),
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete set null (reader_id)
);
create index if not exists push_subscriptions_org_active_idx on news.push_subscriptions (org_id) where status = 'active';

-- =====================================================================
-- M5. community (댓글, 신고, 제보·투고, 경조사)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1 comments: 로그인 독자만 작성. 방문자 공개 목록은 news.list_comments(닉네임만)로만 나간다.
--     visible -> hidden | temp_blocked | deleted, hidden -> visible | deleted, temp_blocked -> visible | hidden | deleted
--     temp_blocked: 정보통신망법 제44조의2 임시조치(30일 이내)
-- ---------------------------------------------------------------------
create table if not exists news.comments (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  article_id          uuid not null,
  reader_id           uuid not null,
  parent_id           uuid,
  body                text not null constraint comments_body_check check (char_length(btrim(body)) between 1 and 1000),
  status              text not null default 'visible' constraint comments_status_check check (status in ('visible', 'hidden', 'temp_blocked', 'deleted')),
  status_reason       text constraint comments_status_reason_check check (status_reason is null or char_length(status_reason) <= 200),
  temp_blocked_until  timestamptz,
  report_count        integer not null default 0,
  moderation_label    text constraint comments_moderation_label_check check (moderation_label is null or moderation_label in ('ok', 'review', 'toxic')),
  moderated_by        uuid,
  moderated_at        timestamptz,
  deleted_at          timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (id, org_id),
  unique (id, article_id),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete cascade,
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete cascade,
  foreign key (parent_id, article_id) references news.comments (id, article_id) on delete cascade,
  constraint comments_temp_block_check check (status <> 'temp_blocked' or temp_blocked_until is not null)
);
create index if not exists comments_article_idx on news.comments (article_id, created_at desc) where status = 'visible';
create index if not exists comments_org_status_idx on news.comments (org_id, status, created_at desc);
create index if not exists comments_reader_idx on news.comments (reader_id, created_at desc);

create or replace function news.comments_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.article_id is distinct from old.article_id
     or new.reader_id is distinct from old.reader_id or new.body is distinct from old.body then
    raise exception 'comments: org_id/article_id/reader_id/body are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'visible'      and new.status in ('hidden', 'temp_blocked', 'deleted'))
      or (old.status = 'hidden'       and new.status in ('visible', 'deleted'))
      or (old.status = 'temp_blocked' and new.status in ('visible', 'hidden', 'deleted'))
    ) then
      raise exception 'comments: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'deleted' then new.deleted_at := now(); end if;
    if new.status <> 'temp_blocked' then new.temp_blocked_until := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists comments_before_update on news.comments;
create trigger comments_before_update before update on news.comments
  for each row execute function news.comments_before_update();

create table if not exists news.comment_reports (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  comment_id          uuid not null,
  reporter_reader_id  uuid not null,
  reason              text not null constraint comment_reports_reason_check check (reason in ('defamation', 'privacy', 'obscene', 'hate', 'spam', 'other')),
  detail              text constraint comment_reports_detail_check check (detail is null or char_length(detail) <= 1000),
  is_rights_claim     boolean not null default false,
  status              text not null default 'open' constraint comment_reports_status_check check (status in ('open', 'actioned', 'dismissed')),
  handled_by          uuid,
  handled_at          timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (comment_id, reporter_reader_id),
  foreign key (comment_id, org_id) references news.comments (id, org_id) on delete cascade,
  foreign key (reporter_reader_id, org_id) references news.readers (id, org_id) on delete cascade
);
create index if not exists comment_reports_org_open_idx on news.comment_reports (org_id, created_at) where status = 'open';

-- ---------------------------------------------------------------------
-- 5.2 tips: 독자 제보·투고(NW-F-025). Route Handler(service_role)만 접수한다. 첨부는 org-files/<org>/news/tips/ (서버 업로드).
--     제보자 보호: 데스크 이상 + 배정된 기자만 읽는다. 첨부 폴더는 아래 Storage 제한 정책이 같은 기준으로 막는다.
--     new -> reviewing | assigned | dismissed | spam, reviewing -> assigned | used | dismissed | spam,
--     assigned -> reviewing | used | dismissed, spam -> new
-- ---------------------------------------------------------------------
create table if not exists news.tips (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  kind              text not null default 'tip' constraint tips_kind_check check (kind in ('tip', 'contribution')),
  reader_id         uuid,
  title             text not null constraint tips_title_check check (char_length(btrim(title)) between 1 and 200),
  body              text not null constraint tips_body_check check (char_length(btrim(body)) between 10 and 20000),
  contact_name      text constraint tips_contact_name_check check (contact_name is null or char_length(contact_name) <= 40),
  contact_email     text constraint tips_contact_email_check check (contact_email is null or (char_length(contact_email) <= 254 and contact_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  contact_phone     text constraint tips_contact_phone_check check (contact_phone is null or contact_phone ~ '^[0-9+() -]{6,30}$'),
  wants_anonymity   boolean not null default true,
  attachment_paths  text[] not null default '{}' constraint tips_attachment_count_check check (cardinality(attachment_paths) <= 5),
  consent_version   text not null constraint tips_consent_version_check check (char_length(consent_version) between 1 and 32),
  consent_at        timestamptz not null default now(),
  status            text not null default 'new' constraint tips_status_check check (status in ('new', 'reviewing', 'assigned', 'used', 'dismissed', 'spam')),
  assigned_to       uuid,
  staff_note        text constraint tips_staff_note_check check (staff_note is null or char_length(staff_note) <= 2000),
  retention_until   timestamptz not null default (now() + interval '1 year'),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  foreign key (reader_id, org_id) references news.readers (id, org_id) on delete set null (reader_id),
  constraint tips_attachment_paths_check check (news.are_org_paths(org_id, attachment_paths, 'tips')),
  constraint tips_assigned_check check (status <> 'assigned' or assigned_to is not null)
);
create index if not exists tips_org_status_idx on news.tips (org_id, status, created_at desc);
create index if not exists tips_assigned_idx on news.tips (assigned_to) where assigned_to is not null;

create or replace function news.tips_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id or new.body is distinct from old.body or new.consent_at is distinct from old.consent_at then
    raise exception 'tips: org_id/body/consent_at are immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'new'       and new.status in ('reviewing', 'assigned', 'dismissed', 'spam'))
    or (old.status = 'reviewing' and new.status in ('assigned', 'used', 'dismissed', 'spam'))
    or (old.status = 'assigned'  and new.status in ('reviewing', 'used', 'dismissed'))
    or (old.status = 'spam'      and new.status = 'new')
  ) then
    raise exception 'tips: invalid status transition % -> %', old.status, new.status using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists tips_before_update on news.tips;
create trigger tips_before_update before update on news.tips
  for each row execute function news.tips_before_update();

-- ---------------------------------------------------------------------
-- 5.3 life_events: 경조사(부고·인사·동정·화촉, NW-F-024). 독자 신청 → 편집국 검토 → 게재.
--     pending -> approved | rejected | withdrawn, approved -> archived
-- ---------------------------------------------------------------------
create table if not exists news.life_events (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  kind                 text not null constraint life_events_kind_check check (kind in ('obituary', 'personnel', 'people', 'wedding')),
  title                text not null constraint life_events_title_check check (char_length(btrim(title)) between 1 and 200),
  body                 text not null constraint life_events_body_check check (char_length(btrim(body)) between 1 and 5000),
  event_at             timestamptz,
  applicant_reader_id  uuid,
  applicant_name       text not null constraint life_events_applicant_name_check check (char_length(btrim(applicant_name)) between 1 and 40),
  applicant_phone      text constraint life_events_applicant_phone_check check (applicant_phone is null or applicant_phone ~ '^[0-9+() -]{6,30}$'),
  consent_version      text not null constraint life_events_consent_version_check check (char_length(consent_version) between 1 and 32),
  consent_at           timestamptz not null default now(),
  is_paid              boolean not null default false,
  paid_at              timestamptz,
  status               text not null default 'pending' constraint life_events_status_check check (status in ('pending', 'approved', 'rejected', 'withdrawn', 'archived')),
  published_at         timestamptz,
  reviewed_by          uuid,
  reviewed_at          timestamptz,
  review_note          text constraint life_events_review_note_check check (review_note is null or char_length(review_note) <= 500),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  foreign key (applicant_reader_id, org_id) references news.readers (id, org_id) on delete set null (applicant_reader_id)
);
create index if not exists life_events_org_status_idx on news.life_events (org_id, status, published_at desc);

create or replace function news.life_events_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'life_events: org_id is immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not ((old.status = 'pending' and new.status in ('approved', 'rejected', 'withdrawn')) or (old.status = 'approved' and new.status = 'archived')) then
      raise exception 'life_events: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'approved' then new.published_at := now(); end if;
  end if;
  return new;
end;
$$;
drop trigger if exists life_events_before_update on news.life_events;
create trigger life_events_before_update before update on news.life_events
  for each row execute function news.life_events_before_update();

-- =====================================================================
-- M6. distribution-seo (wire_contracts 는 1절 앞에서 만들었다)
-- =====================================================================
create table if not exists news.syndication_settings (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null unique references core.organizations(id) on delete cascade,
  rss_enabled           boolean not null default true,
  news_sitemap_enabled  boolean not null default true,
  google_news           boolean not null default false,
  naver_partnership     text not null default 'none' constraint syndication_settings_naver_check check (naver_partnership in ('none', 'search', 'content')),
  daum_partnership      text not null default 'none' constraint syndication_settings_daum_check check (daum_partnership in ('none', 'search', 'content')),
  ai_crawler_policy     text not null default 'block_training'
                        constraint syndication_settings_ai_crawler_policy_check check (ai_crawler_policy in ('allow', 'block_training', 'block_all')),
  llms_txt_enabled      boolean not null default false,
  robots_extra          text constraint syndication_settings_robots_extra_check check (robots_extra is null or (char_length(robots_extra) <= 2000 and robots_extra !~ '[<>]')),
  sns_autoshare         jsonb not null default '{}'::jsonb constraint syndication_settings_sns_check check (jsonb_typeof(sns_autoshare) = 'object'),
  updated_by            uuid,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- =====================================================================
-- M7. compliance-desk (정정·반론·추후보도 청구, 선거 기간)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7.1 correction_requests: 언론중재법 제14·15조. 접수 시각과 기한은 트리거가 정하고 바꿀 수 없다.
--     notify_due_at = received_at + 3일(수용 여부 통지 기한), publish_due_at = 수용 결정 시각 + 7일(게재 기한).
--     received -> reviewing | accepted | rejected | withdrawn, reviewing -> accepted | rejected | withdrawn,
--     accepted -> published | withdrawn
-- ---------------------------------------------------------------------
create table if not exists news.correction_requests (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  article_id             uuid,
  article_url            text constraint correction_requests_article_url_check check (article_url is null or char_length(article_url) <= 1000),
  kind                   text not null constraint correction_requests_kind_check check (kind in ('correction', 'rebuttal', 'follow_up')),
  requester_name         text not null constraint correction_requests_requester_name_check check (char_length(btrim(requester_name)) between 1 and 80),
  requester_email        text constraint correction_requests_requester_email_check check (requester_email is null or (char_length(requester_email) <= 254 and requester_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  requester_phone        text constraint correction_requests_requester_phone_check check (requester_phone is null or requester_phone ~ '^[0-9+() -]{6,30}$'),
  requester_reader_id    uuid,
  claim_text             text not null constraint correction_requests_claim_text_check check (char_length(btrim(claim_text)) between 10 and 10000),
  requested_text         text constraint correction_requests_requested_text_check check (requested_text is null or char_length(requested_text) <= 10000),
  attachment_paths       text[] not null default '{}' constraint correction_requests_attachment_count_check check (cardinality(attachment_paths) <= 5),
  channel                text not null default 'web' constraint correction_requests_channel_check check (channel in ('web', 'email', 'mail', 'phone', 'arbitration')),
  received_at            timestamptz not null default now(),
  notify_due_at          timestamptz not null,
  status                 text not null default 'received'
                         constraint correction_requests_status_check check (status in ('received', 'reviewing', 'accepted', 'rejected', 'published', 'withdrawn')),
  decided_at             timestamptz,
  decided_by             uuid,
  decision_note          text constraint correction_requests_decision_note_check check (decision_note is null or char_length(decision_note) <= 2000),
  notified_at            timestamptz,
  publish_due_at         timestamptz,
  published_at           timestamptz,
  published_revision_id  uuid,
  created_by             uuid,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (id, org_id),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete set null (article_id),
  foreign key (requester_reader_id, org_id) references news.readers (id, org_id) on delete set null (requester_reader_id),
  constraint correction_requests_target_check check (article_id is not null or article_url is not null),
  constraint correction_requests_contact_check check (requester_email is not null or requester_phone is not null),
  constraint correction_requests_attachment_paths_check check (news.are_org_paths(org_id, attachment_paths, 'corrections')),
  constraint correction_requests_publish_due_check check (status not in ('accepted', 'published') or publish_due_at is not null)
);
create index if not exists correction_requests_org_status_idx on news.correction_requests (org_id, status, received_at desc);
create index if not exists correction_requests_notify_due_idx on news.correction_requests (notify_due_at) where status in ('received', 'reviewing');
create index if not exists correction_requests_publish_due_idx on news.correction_requests (publish_due_at) where status = 'accepted';

create or replace function news.correction_requests_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'received' then
      raise exception 'correction_requests: new requests start as received' using errcode = '22023';
    end if;
    new.notify_due_at := new.received_at + interval '3 days';
    new.publish_due_at := null;
    return new;
  end if;
  if new.org_id is distinct from old.org_id or new.received_at is distinct from old.received_at
     or new.notify_due_at is distinct from old.notify_due_at or new.kind is distinct from old.kind
     or new.claim_text is distinct from old.claim_text then
    raise exception 'correction_requests: org_id/received_at/notify_due_at/kind/claim_text are immutable' using errcode = '22023';
  end if;
  if old.article_id is not null and new.article_id is distinct from old.article_id then
    raise exception 'correction_requests: linked article cannot be changed' using errcode = '22023';
  end if;
  if old.publish_due_at is not null and new.publish_due_at is distinct from old.publish_due_at then
    raise exception 'correction_requests: publish_due_at is immutable once set' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'received'  and new.status in ('reviewing', 'accepted', 'rejected', 'withdrawn'))
      or (old.status = 'reviewing' and new.status in ('accepted', 'rejected', 'withdrawn'))
      or (old.status = 'accepted'  and new.status in ('published', 'withdrawn'))
    ) then
      raise exception 'correction_requests: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status in ('accepted', 'rejected') then
      new.decided_at := now();
      new.notified_at := coalesce(new.notified_at, now());
    end if;
    if new.status = 'accepted' then new.publish_due_at := new.decided_at + interval '7 days'; end if;
    if new.status = 'published' then new.published_at := now(); end if;
  end if;
  return new;
end;
$$;
drop trigger if exists correction_requests_before_write on news.correction_requests;
create trigger correction_requests_before_write before insert or update on news.correction_requests
  for each row execute function news.correction_requests_before_write();

-- ---------------------------------------------------------------------
-- 7.2 election_periods: 선거 모드(NW-F-044). 여론조사 공표 금지 기간(공직선거법 제108조: 선거일 전 6일 ~ 투표 마감)과 댓글 정책.
--     전국 선거는 운영자 서버(service_role)가 신문사마다 행을 넣는다(source='platform').
-- ---------------------------------------------------------------------
create table if not exists news.election_periods (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  name                 text not null constraint election_periods_name_check check (char_length(btrim(name)) between 1 and 80),
  election_day         date not null,
  poll_blackout_from   timestamptz not null,
  poll_blackout_until  timestamptz not null,
  comment_policy       text not null default 'normal' constraint election_periods_comment_policy_check check (comment_policy in ('normal', 'disabled')),
  source               text not null default 'newsroom' constraint election_periods_source_check check (source in ('platform', 'newsroom')),
  status               text not null default 'active' constraint election_periods_status_check check (status in ('active', 'canceled')),
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint election_periods_blackout_check check (poll_blackout_until > poll_blackout_from)
);
create index if not exists election_periods_org_idx on news.election_periods (org_id, poll_blackout_from, poll_blackout_until) where status = 'active';

-- =====================================================================
-- M8. search-analytics
-- =====================================================================
-- 조회 집계(시간 버킷, UTC 정시). news.increment_article_views(service_role)만 증분한다.
create table if not exists news.article_view_hourly (
  org_id        uuid not null references core.organizations(id) on delete cascade,
  article_id    uuid not null,
  bucket_start  timestamptz not null constraint article_view_hourly_bucket_check check (extract(epoch from bucket_start)::bigint % 3600 = 0),
  views         bigint not null default 0 constraint article_view_hourly_views_check check (views >= 0),
  updated_at    timestamptz not null default now(),
  primary key (article_id, bucket_start),
  foreign key (article_id, org_id) references news.articles (id, org_id) on delete cascade
);
create index if not exists article_view_hourly_org_bucket_idx on news.article_view_hourly (org_id, bucket_start desc);

-- =====================================================================
-- local-life: 행사 캘린더(NW-F-023). 날씨·미세먼지는 외부 API 캐시라 테이블이 없다.
--     draft -> published | archived, published -> canceled | archived, canceled -> archived
-- =====================================================================
create table if not exists news.events (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  title        text not null constraint events_title_check check (char_length(btrim(title)) between 1 and 200),
  description  text constraint events_description_check check (description is null or char_length(description) <= 5000),
  venue        text constraint events_venue_check check (venue is null or char_length(venue) <= 120),
  address      text constraint events_address_check check (address is null or char_length(address) <= 200),
  region_id    uuid,
  starts_at    timestamptz not null,
  ends_at      timestamptz,
  is_all_day   boolean not null default false,
  url          text constraint events_url_check check (url is null or (char_length(url) <= 500 and url ~ '^https://[^[:space:]<>"]{3,}$')),
  image_path   text,
  organizer    text constraint events_organizer_check check (organizer is null or char_length(organizer) <= 80),
  price_text   text constraint events_price_text_check check (price_text is null or char_length(price_text) <= 80),
  status       text not null default 'draft' constraint events_status_check check (status in ('draft', 'published', 'canceled', 'archived')),
  published_at timestamptz,
  created_by   uuid,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  foreign key (region_id, org_id) references news.regions (id, org_id),
  constraint events_image_path_check check (image_path is null or news.is_org_path(org_id, image_path, 'events')),
  constraint events_period_check check (ends_at is null or ends_at >= starts_at)
);
create index if not exists events_org_starts_idx on news.events (org_id, starts_at) where status in ('published', 'canceled');

create or replace function news.events_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'events: org_id is immutable' using errcode = '22023';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'draft'     and new.status in ('published', 'archived'))
      or (old.status = 'published' and new.status in ('canceled', 'archived'))
      or (old.status = 'canceled'  and new.status = 'archived')
    ) then
      raise exception 'events: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'published' then new.published_at := now(); end if;
  end if;
  return new;
end;
$$;
drop trigger if exists events_before_update on news.events;
create trigger events_before_update before update on news.events
  for each row execute function news.events_before_update();

-- ---------------------------------------------------------------------
-- 공통 트리거: updated_at, 쓰기 보호(guard_privileged_write). 사용자 세션의 직접 쓰기는 GRANT 가 1차, 이 트리거가 2차로 막는다.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'newspaper_applications', 'newspapers', 'staff', 'sections', 'regions', 'tags', 'wire_contracts', 'media_assets', 'articles',
    'home_layouts', 'print_editions', 'live_updates', 'readers', 'membership_tiers', 'memberships', 'donations', 'paywall_rules',
    'ad_slots', 'advertisers', 'ad_campaigns', 'ad_creatives', 'ad_daily_stats', 'local_listings', 'public_notices',
    'newsletter_lists', 'newsletter_subscriptions', 'newsletter_issues', 'push_subscriptions', 'comments', 'comment_reports',
    'tips', 'life_events', 'syndication_settings', 'correction_requests', 'election_periods', 'article_view_hourly', 'events']
  loop
    execute format('drop trigger if exists %I_set_updated_at on news.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on news.%I for each row execute function core.set_updated_at()', t, t);
  end loop;
  foreach t in array array[
    'newspaper_applications', 'newspapers', 'staff', 'sections', 'regions', 'tags', 'wire_contracts', 'media_assets', 'articles',
    'article_revisions', 'article_regions', 'article_tags', 'home_layouts', 'print_editions', 'live_updates', 'readers',
    'membership_tiers', 'memberships', 'donations', 'paywall_rules', 'ad_slots', 'advertisers', 'ad_campaigns', 'ad_creatives',
    'ad_daily_stats', 'local_listings', 'public_notices', 'newsletter_lists', 'newsletter_subscriptions', 'newsletter_issues',
    'push_subscriptions', 'comments', 'comment_reports', 'tips', 'life_events', 'syndication_settings', 'correction_requests',
    'election_periods', 'article_view_hourly', 'events']
  loop
    execute format('drop trigger if exists %I_guard_write on news.%I', t, t);
    execute format('create trigger %I_guard_write before insert or update or delete on news.%I for each row execute function core.guard_privileged_write()', t, t);
    execute format('alter table news.%I enable row level security', t);
    execute format('revoke all on table news.%I from public, anon, authenticated', t);
  end loop;
end $$;

-- =====================================================================
-- 9. RLS 헬퍼 (SECURITY DEFINER, STABLE). 정책 안에서 org_members·staff 를 직접 조회하지 않는다(42P17 방지).
--   news.staff_role(org)               현재 사용자의 활성 도메인 역할(코어 멤버십 active + staff active). 없으면 null
--   news.has_staff_role(org, roles)    위 역할이 roles 안에 있는가(exists 의미, NULL 없음)
--   news.is_newsroom(org, roles)       has_staff_role + 엔타이틀먼트 활성. 편집국 정책의 표준 조건
--   news.is_public_newspaper(org)      신문사 active + 필요적 게재사항 완성 + 조직 미삭제 + 엔타이틀먼트 활성(anon 공개 조건)
--   news.article_is_live(...)          기사 공개 조건(게시 + 시각 도래 + 엠바고 해제 + 신문사 공개 + wire 계약 유효)
--   news.is_article_live(article_id)   위 조건을 id 로 판정(하위 테이블 공개 정책용)
--   news.can_view_article(article_id)  편집국 안의 기사 열람 범위(기고자는 자기 기사, 광고담당은 기사형 광고만)
--   news.current_reader_id(org)        현재 사용자의 활성 독자 id
-- 역할 묶음(문서 4절 표와 같은 이름):
--   ALL       publisher, editor, desk, reporter, contributor, ad_manager
--   EDITORIAL publisher, editor, desk, reporter
--   DESK      publisher, editor, desk
--   CHIEF     publisher, editor
--   ADS       publisher, editor, ad_manager
-- =====================================================================
create or replace function news.staff_role(p_org uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select s.role
  from news.staff s
  join core.org_members m on m.org_id = s.org_id and m.user_id = s.user_id and m.status = 'active'
  where s.org_id = p_org and s.user_id = auth.uid() and s.status = 'active';
$$;

create or replace function news.has_staff_role(p_org uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from news.staff s
    join core.org_members m on m.org_id = s.org_id and m.user_id = s.user_id and m.status = 'active'
    where s.org_id = p_org and s.user_id = auth.uid() and s.status = 'active' and s.role = any (p_roles)
  );
$$;

create or replace function news.is_newsroom(p_org uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select news.has_staff_role(p_org, p_roles) and core.has_entitlement(p_org, 'news');
$$;

create or replace function news.is_public_newspaper(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from news.newspapers n
    join core.organizations o on o.id = n.org_id and o.deleted_at is null
    where n.org_id = p_org and n.status = 'active' and n.profile_completed_at is not null
      and exists (select 1 from core.app_entitlements e
                  where e.org_id = p_org and e.app_id = 'news' and e.status = 'active'
                    and (e.expires_at is null or e.expires_at > now()))
  );
$$;

create or replace function news.is_profile_complete(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select n.profile_completed_at is not null from news.newspapers n where n.org_id = p_org), false);
$$;

create or replace function news.article_is_live(p_org uuid, p_status text, p_published_at timestamptz,
                                                 p_embargo_until timestamptz, p_type text, p_wire_contract_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_status = 'published'
     and p_published_at is not null and p_published_at <= now()
     and (p_embargo_until is null or p_embargo_until <= now())
     and news.is_public_newspaper(p_org)
     and (p_type <> 'wire' or exists (
           select 1 from news.wire_contracts w
           where w.id = p_wire_contract_id and w.org_id = p_org and w.status = 'active'
             and w.starts_on <= (now() at time zone 'Asia/Seoul')::date
             and (w.ends_on is null or w.ends_on >= (now() at time zone 'Asia/Seoul')::date)));
$$;

create or replace function news.is_article_live(p_article_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select news.article_is_live(a.org_id, a.status, a.published_at, a.embargo_until, a.type, a.wire_contract_id)
                   from news.articles a where a.id = p_article_id), false);
$$;

create or replace function news.can_view_article(p_article_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from news.articles a
    where a.id = p_article_id
      and core.has_entitlement(a.org_id, 'news')
      and (   news.has_staff_role(a.org_id, array['publisher', 'editor', 'desk', 'reporter'])
           or (news.has_staff_role(a.org_id, array['contributor']) and (a.created_by = auth.uid() or a.author_id = auth.uid()))
           or (news.has_staff_role(a.org_id, array['ad_manager']) and a.type = 'sponsored'))
  );
$$;

create or replace function news.current_reader_id(p_org uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select r.id from news.readers r where r.org_id = p_org and r.user_id = auth.uid() and r.status = 'active';
$$;

-- =====================================================================
-- 10. RLS 정책과 GRANT
--   - authenticated: 편집국은 news.is_newsroom 으로, 독자는 자기 행(user_id = auth.uid())으로만 SELECT.
--   - anon: 공개 조건을 만족한 행의 공개 컬럼만(컬럼 GRANT). 본문(body)·검색 벡터·내부 메모는 GRANT 에서 빠진다.
--     로그인한 독자도 공개 콘텐츠는 anon 키(쿠키 없는 서버 클라이언트, ISR 캐시 공유)로 읽는다(02장 아키텍처).
--   - INSERT/UPDATE/DELETE 정책과 GRANT 는 어느 테이블에도 없다(쓰기는 11절 RPC 와 service_role).
-- =====================================================================

-- newspaper_applications: 신청자 본인 + 플랫폼 운영자
drop policy if exists newspaper_applications_select on news.newspaper_applications;
create policy newspaper_applications_select on news.newspaper_applications for select to authenticated
  using (applicant_id = auth.uid() or core.is_platform_admin());
grant select on news.newspaper_applications to authenticated;

-- newspapers: 편집국 전원 + 운영자. 방문자는 매체정보(법정 푸터) 컬럼만
drop policy if exists newspapers_select on news.newspapers;
create policy newspapers_select on news.newspapers for select to authenticated
  using (news.has_staff_role(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']) or core.is_platform_admin());
drop policy if exists newspapers_select_public on news.newspapers;
create policy newspapers_select_public on news.newspapers for select to anon
  using (news.is_public_newspaper(org_id));
grant select on news.newspapers to authenticated;
grant select (id, org_id, title, legal_name, media_kind, registration_no, registration_date, publisher_name, editor_name,
              youth_officer_name, privacy_officer_name, publish_address, phone, email, first_published_on, ethics_code_url,
              comments_enabled, profile_completed_at)
  on news.newspapers to anon;

-- staff: 편집국 전원(같은 조직). 방문자는 공개 프로필 컬럼만(기자 페이지)
drop policy if exists staff_select on news.staff;
create policy staff_select on news.staff for select to authenticated
  using (news.has_staff_role(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']) or user_id = auth.uid());
drop policy if exists staff_select_public on news.staff;
create policy staff_select_public on news.staff for select to anon
  using (status = 'active' and is_public_profile and news.is_public_newspaper(org_id));
grant select on news.staff to authenticated;
grant select (id, org_id, role, byline_name, title_label, bio, photo_path, email_public) on news.staff to anon;

-- 분류: 편집국 전원 / 방문자는 활성 행
do $$
declare t text;
begin
  foreach t in array array['sections', 'regions', 'tags'] loop
    execute format('drop policy if exists %I_select on news.%I', t, t);
    execute format('create policy %I_select on news.%I for select to authenticated using (news.is_newsroom(org_id, array[''publisher'', ''editor'', ''desk'', ''reporter'', ''contributor'', ''ad_manager'']))', t, t);
    execute format('drop policy if exists %I_select_public on news.%I', t, t);
    execute format('create policy %I_select_public on news.%I for select to anon using (is_active and news.is_public_newspaper(org_id))', t, t);
    execute format('grant select on news.%I to authenticated, anon', t);
  end loop;
end $$;

-- wire_contracts: 편집 라인(계약 조건). 방문자 없음(공개 판정은 article_is_live 안에서)
drop policy if exists wire_contracts_select on news.wire_contracts;
create policy wire_contracts_select on news.wire_contracts for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter']));
grant select on news.wire_contracts to authenticated;

-- media_assets: 편집국 전원 / 방문자는 공개 기사가 참조한 미디어의 표시 컬럼만
drop policy if exists media_assets_select on news.media_assets;
create policy media_assets_select on news.media_assets for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']));
drop policy if exists media_assets_select_public on news.media_assets;
create policy media_assets_select_public on news.media_assets for select to anon
  using (status = 'active' and published_at is not null and news.is_public_newspaper(org_id));
grant select on news.media_assets to authenticated;
grant select (id, org_id, bucket, storage_path, kind, mime, width, height, alt_text, caption, credit, ai_generated, ai_disclosure)
  on news.media_assets to anon;

-- articles: 편집국은 역할별 범위(can_view_article 과 같은 식을 행 컬럼으로), 방문자는 공개 기사 공개 컬럼
drop policy if exists articles_select on news.articles;
create policy articles_select on news.articles for select to authenticated
  using (core.has_entitlement(org_id, 'news') and (
            news.has_staff_role(org_id, array['publisher', 'editor', 'desk', 'reporter'])
         or (news.has_staff_role(org_id, array['contributor']) and (created_by = auth.uid() or author_id = auth.uid()))
         or (news.has_staff_role(org_id, array['ad_manager']) and type = 'sponsored')));
drop policy if exists articles_select_public on news.articles;
create policy articles_select_public on news.articles for select to anon
  using (news.article_is_live(org_id, status, published_at, embargo_until, type, wire_contract_id));
grant select on news.articles to authenticated;
grant select (id, org_id, slug, title, subtitle, summary, type, section_id, byline, is_premium, sponsor_label, ai_assisted,
              ai_disclosure, source_note, is_poll, poll_disclosure, is_breaking, is_live, comments_enabled, hero_media_id, seo,
              published_at, first_published_at, revised_at, revision_note, last_corrected_at, correction_count)
  on news.articles to anon;

-- article_revisions: 그 기사를 볼 수 있는 편집국. 방문자는 read_article 이 공개 메모만 돌려준다
drop policy if exists article_revisions_select on news.article_revisions;
create policy article_revisions_select on news.article_revisions for select to authenticated
  using (news.can_view_article(article_id));
grant select on news.article_revisions to authenticated;

-- article_regions / article_tags
do $$
declare t text;
begin
  foreach t in array array['article_regions', 'article_tags'] loop
    execute format('drop policy if exists %I_select on news.%I', t, t);
    execute format('create policy %I_select on news.%I for select to authenticated using (news.can_view_article(article_id))', t, t);
    execute format('drop policy if exists %I_select_public on news.%I', t, t);
    execute format('create policy %I_select_public on news.%I for select to anon using (news.is_article_live(article_id))', t, t);
    execute format('grant select on news.%I to authenticated, anon', t);
  end loop;
end $$;

-- home_layouts: 편집 라인 / 방문자는 게시본
drop policy if exists home_layouts_select on news.home_layouts;
create policy home_layouts_select on news.home_layouts for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter']));
drop policy if exists home_layouts_select_public on news.home_layouts;
create policy home_layouts_select_public on news.home_layouts for select to anon
  using (status = 'published' and news.is_public_newspaper(org_id));
grant select on news.home_layouts to authenticated;
grant select (id, org_id, template, blocks, version, published_at) on news.home_layouts to anon;

-- print_editions: 편집 라인 / 방문자는 게시본 메타(PDF 는 서버가 서명 URL 로)
drop policy if exists print_editions_select on news.print_editions;
create policy print_editions_select on news.print_editions for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter']));
drop policy if exists print_editions_select_public on news.print_editions;
create policy print_editions_select_public on news.print_editions for select to anon
  using (status = 'published' and news.is_public_newspaper(org_id));
grant select on news.print_editions to authenticated;
grant select (id, org_id, edition_date, issue_no, title, page_count, published_at) on news.print_editions to anon;

-- live_updates
drop policy if exists live_updates_select on news.live_updates;
create policy live_updates_select on news.live_updates for select to authenticated
  using (news.can_view_article(article_id));
drop policy if exists live_updates_select_public on news.live_updates;
create policy live_updates_select_public on news.live_updates for select to anon
  using (status = 'visible' and news.is_article_live(article_id));
grant select on news.live_updates to authenticated;
grant select (id, org_id, article_id, body, is_pinned, posted_at) on news.live_updates to anon;

-- readers: 본인 행 + 발행인·편집인(개인정보 최소 접근). 독자는 조직 멤버가 아니다
drop policy if exists readers_select on news.readers;
create policy readers_select on news.readers for select to authenticated
  using (user_id = auth.uid() or news.is_newsroom(org_id, array['publisher', 'editor']));
grant select on news.readers to authenticated;

-- membership_tiers: 편집국 전원 / 방문자는 활성 등급(가격표)
drop policy if exists membership_tiers_select on news.membership_tiers;
create policy membership_tiers_select on news.membership_tiers for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']));
drop policy if exists membership_tiers_select_public on news.membership_tiers;
create policy membership_tiers_select_public on news.membership_tiers for select to anon
  using (is_active and news.is_public_newspaper(org_id));
grant select on news.membership_tiers to authenticated;
grant select (id, org_id, code, name, description, price_krw, billing_interval, benefits, sort_order) on news.membership_tiers to anon;

-- memberships / donations: 본인(독자 행 경유) + 발행인·편집인
drop policy if exists memberships_select on news.memberships;
create policy memberships_select on news.memberships for select to authenticated
  using (reader_id = news.current_reader_id(org_id) or news.is_newsroom(org_id, array['publisher', 'editor']));
grant select on news.memberships to authenticated;
drop policy if exists donations_select on news.donations;
create policy donations_select on news.donations for select to authenticated
  using ((reader_id is not null and reader_id = news.current_reader_id(org_id)) or news.is_newsroom(org_id, array['publisher', 'editor']));
grant select on news.donations to authenticated;

-- paywall_rules: 편집국 전원 / 방문자 공개(미터 안내 렌더링)
drop policy if exists paywall_rules_select on news.paywall_rules;
create policy paywall_rules_select on news.paywall_rules for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']));
drop policy if exists paywall_rules_select_public on news.paywall_rules;
create policy paywall_rules_select_public on news.paywall_rules for select to anon
  using (news.is_public_newspaper(org_id));
grant select on news.paywall_rules to authenticated;
grant select (org_id, mode, free_articles_per_month, exempt_types, cta_text) on news.paywall_rules to anon;

-- 광고: ADS 역할. 방문자는 슬롯 크기(공간 예약)만, 소재는 serve_ads 로만
drop policy if exists ad_slots_select on news.ad_slots;
create policy ad_slots_select on news.ad_slots for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'ad_manager']));
drop policy if exists ad_slots_select_public on news.ad_slots;
create policy ad_slots_select_public on news.ad_slots for select to anon
  using (is_active and news.is_public_newspaper(org_id));
grant select on news.ad_slots to authenticated;
grant select (id, org_id, code, placement, width, height, sort_order) on news.ad_slots to anon;
do $$
declare t text;
begin
  foreach t in array array['advertisers', 'ad_campaigns', 'ad_creatives', 'ad_daily_stats'] loop
    execute format('drop policy if exists %I_select on news.%I', t, t);
    execute format('create policy %I_select on news.%I for select to authenticated using (news.is_newsroom(org_id, array[''publisher'', ''editor'', ''ad_manager'']))', t, t);
    execute format('grant select on news.%I to authenticated', t);
  end loop;
end $$;

-- local_listings: ADS 역할 + 신청자 본인 / 방문자는 게재 중 업소의 공개 컬럼
drop policy if exists local_listings_select on news.local_listings;
create policy local_listings_select on news.local_listings for select to authenticated
  using (applicant_user_id = auth.uid() or news.is_newsroom(org_id, array['publisher', 'editor', 'ad_manager']));
drop policy if exists local_listings_select_public on news.local_listings;
create policy local_listings_select_public on news.local_listings for select to anon
  using (status = 'active' and starts_at <= now() and ends_at > now() and news.is_public_newspaper(org_id));
grant select on news.local_listings to authenticated;
grant select (id, org_id, business_name, category, region_id, address, phone, url, description, photo_path, starts_at, ends_at)
  on news.local_listings to anon;

-- public_notices
drop policy if exists public_notices_select on news.public_notices;
create policy public_notices_select on news.public_notices for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'ad_manager']));
drop policy if exists public_notices_select_public on news.public_notices;
create policy public_notices_select_public on news.public_notices for select to anon
  using (status = 'published' and news.is_public_newspaper(org_id));
grant select on news.public_notices to authenticated;
grant select (id, org_id, issuer_name, notice_no, title, body, region_id, attachment_path, posted_from, posted_until, published_at)
  on news.public_notices to anon;

-- 뉴스레터: 목록은 공개(활성·공개 목록), 구독은 본인(독자 행 경유) + 발행인·편집인, 회차는 편집 라인
drop policy if exists newsletter_lists_select on news.newsletter_lists;
create policy newsletter_lists_select on news.newsletter_lists for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']));
drop policy if exists newsletter_lists_select_public on news.newsletter_lists;
create policy newsletter_lists_select_public on news.newsletter_lists for select to anon
  using (status = 'active' and is_public and news.is_public_newspaper(org_id));
grant select on news.newsletter_lists to authenticated;
grant select (id, org_id, slug, name, description, kind, contains_ads, consent_version) on news.newsletter_lists to anon;
drop policy if exists newsletter_subscriptions_select on news.newsletter_subscriptions;
create policy newsletter_subscriptions_select on news.newsletter_subscriptions for select to authenticated
  using ((reader_id is not null and reader_id = news.current_reader_id(org_id)) or news.is_newsroom(org_id, array['publisher', 'editor']));
-- 토큰 해시 컬럼은 누구에게도 주지 않는다
grant select (id, org_id, list_id, reader_id, email, status, consent_version, consent_at, ad_consent, night_consent,
              confirmed_at, reconfirmed_at, reconfirm_due_at, unsubscribed_at, unsubscribe_reason, source_path, created_at, updated_at)
  on news.newsletter_subscriptions to authenticated;
drop policy if exists newsletter_issues_select on news.newsletter_issues;
create policy newsletter_issues_select on news.newsletter_issues for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk']));
grant select on news.newsletter_issues to authenticated;
-- push_subscriptions: 정책 없음(service_role 전용)

-- 댓글: 데스크 이상(모더레이션) + 작성자 본인. 방문자는 list_comments 만
drop policy if exists comments_select on news.comments;
create policy comments_select on news.comments for select to authenticated
  using (reader_id = news.current_reader_id(org_id) or news.is_newsroom(org_id, array['publisher', 'editor', 'desk']));
grant select on news.comments to authenticated;
drop policy if exists comment_reports_select on news.comment_reports;
create policy comment_reports_select on news.comment_reports for select to authenticated
  using (reporter_reader_id = news.current_reader_id(org_id) or news.is_newsroom(org_id, array['publisher', 'editor', 'desk']));
grant select on news.comment_reports to authenticated;

-- 제보: 데스크 이상 + 배정된 기자
drop policy if exists tips_select on news.tips;
create policy tips_select on news.tips for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk'])
         or (assigned_to = auth.uid() and news.is_newsroom(org_id, array['reporter'])));
grant select on news.tips to authenticated;

-- 경조사: 데스크 이상 + 신청자 본인 / 방문자는 게재 행
drop policy if exists life_events_select on news.life_events;
create policy life_events_select on news.life_events for select to authenticated
  using ((applicant_reader_id is not null and applicant_reader_id = news.current_reader_id(org_id))
         or news.is_newsroom(org_id, array['publisher', 'editor', 'desk']));
drop policy if exists life_events_select_public on news.life_events;
create policy life_events_select_public on news.life_events for select to anon
  using (status = 'approved' and news.is_public_newspaper(org_id));
grant select on news.life_events to authenticated;
grant select (id, org_id, kind, title, body, event_at, published_at) on news.life_events to anon;

-- 배포 설정: 편집국 전원 / 방문자(robots, RSS 렌더링)
drop policy if exists syndication_settings_select on news.syndication_settings;
create policy syndication_settings_select on news.syndication_settings for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']));
drop policy if exists syndication_settings_select_public on news.syndication_settings;
create policy syndication_settings_select_public on news.syndication_settings for select to anon
  using (news.is_public_newspaper(org_id));
grant select on news.syndication_settings to authenticated;
grant select (org_id, rss_enabled, news_sitemap_enabled, google_news, ai_crawler_policy, llms_txt_enabled, robots_extra)
  on news.syndication_settings to anon;

-- 정정 청구: 데스크 이상 + 청구한 독자 본인
drop policy if exists correction_requests_select on news.correction_requests;
create policy correction_requests_select on news.correction_requests for select to authenticated
  using ((requester_reader_id is not null and requester_reader_id = news.current_reader_id(org_id))
         or news.is_newsroom(org_id, array['publisher', 'editor', 'desk']));
grant select on news.correction_requests to authenticated;

-- 선거 기간: 편집국 전원
drop policy if exists election_periods_select on news.election_periods;
create policy election_periods_select on news.election_periods for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']));
grant select on news.election_periods to authenticated;

-- 조회 집계: 편집 라인(대시보드). 방문자는 most_read 만
drop policy if exists article_view_hourly_select on news.article_view_hourly;
create policy article_view_hourly_select on news.article_view_hourly for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter']));
grant select on news.article_view_hourly to authenticated;

-- 행사
drop policy if exists events_select on news.events;
create policy events_select on news.events for select to authenticated
  using (news.is_newsroom(org_id, array['publisher', 'editor', 'desk', 'reporter']));
drop policy if exists events_select_public on news.events;
create policy events_select_public on news.events for select to anon
  using (status in ('published', 'canceled') and news.is_public_newspaper(org_id));
grant select on news.events to authenticated;
grant select (id, org_id, title, description, venue, address, region_id, starts_at, ends_at, is_all_day, url, image_path,
              organizer, price_text, status) on news.events to anon;

-- 정정 기한 현황 뷰(security_invoker: correction_requests 의 RLS 를 그대로 통과한다)
create or replace view news.correction_sla with (security_invoker = true) as
  select c.id, c.org_id, c.article_id, c.kind, c.status, c.received_at, c.notify_due_at, c.notified_at,
         c.decided_at, c.publish_due_at, c.published_at,
         (c.status in ('received', 'reviewing') and now() > c.notify_due_at) as notify_overdue,
         (c.status = 'accepted' and now() > c.publish_due_at)                as publish_overdue
  from news.correction_requests c;
revoke all on news.correction_sla from public, anon, authenticated;
grant select on news.correction_sla to authenticated;

-- ---------------------------------------------------------------------
-- Storage 추가 제한(RESTRICTIVE): 코어 org-files 정책은 조직 멤버 누구에게나 조직 폴더를 연다.
-- 제보·정정 청구 첨부(<org>/news/tips|corrections/)는 데스크 이상만 읽고, 사용자 세션은 쓰지 못한다(서버가 업로드).
-- 코어 정책은 바꾸지 않고 제한 정책을 더한다(AND 로 결합).
-- ---------------------------------------------------------------------
drop policy if exists news_sensitive_files_select on storage.objects;
create policy news_sensitive_files_select on storage.objects as restrictive for select to authenticated
  using (not (bucket_id = 'org-files' and split_part(name, '/', 2) = 'news' and split_part(name, '/', 3) in ('tips', 'corrections'))
         or news.is_newsroom(core.storage_org_id(name), array['publisher', 'editor', 'desk']));
drop policy if exists news_sensitive_files_insert on storage.objects;
create policy news_sensitive_files_insert on storage.objects as restrictive for insert to authenticated
  with check (not (bucket_id = 'org-files' and split_part(name, '/', 2) = 'news' and split_part(name, '/', 3) in ('tips', 'corrections')));
drop policy if exists news_sensitive_files_update on storage.objects;
create policy news_sensitive_files_update on storage.objects as restrictive for update to authenticated
  using (not (bucket_id = 'org-files' and split_part(name, '/', 2) = 'news' and split_part(name, '/', 3) in ('tips', 'corrections')))
  with check (not (bucket_id = 'org-files' and split_part(name, '/', 2) = 'news' and split_part(name, '/', 3) in ('tips', 'corrections')));
drop policy if exists news_sensitive_files_delete on storage.objects;
create policy news_sensitive_files_delete on storage.objects as restrictive for delete to authenticated
  using (not (bucket_id = 'org-files' and split_part(name, '/', 2) = 'news' and split_part(name, '/', 3) in ('tips', 'corrections')));

-- =====================================================================
-- 11. RPC (SECURITY DEFINER). 점검표: set search_path = '' / 스키마 한정 / is_service_caller / 역할 헬퍼 / 상태 검사 / 감사 / EXECUTE 정리(12절)
--     독자가 부르는 함수(ensure_reader, post_comment 등)는 core.write_audit 를 부르지 않는다:
--     write_audit 는 조직 멤버만 기록할 수 있고 독자는 조직 멤버가 아니다. 독자 행위의 기록은 각 행의 시각 컬럼이 맡는다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 11.0 내부 헬퍼 (EXECUTE 는 service_role 만. DEFINER 함수 안에서만 쓴다)
-- ---------------------------------------------------------------------
-- 호출자가 서버면 'service', 편집국이면 도메인 역할을 돌려주고, 아니면 42501.
create or replace function news.assert_staff(p_org uuid, p_roles text[], p_ctx text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_role text;
begin
  if core.is_service_caller() then
    return 'service';
  end if;
  v_role := news.staff_role(p_org);
  if v_role is null or not (v_role = any (p_roles)) then
    raise exception '%: role not allowed', p_ctx using errcode = '42501';
  end if;
  if not core.has_entitlement(p_org, 'news') then
    raise exception '%: no entitlement', p_ctx using errcode = '42501';
  end if;
  return v_role;
end;
$$;

-- 엔타이틀먼트 플랜의 features 값(없으면 null). 조직별 덮어쓰기(tenant_feature_overrides)는 Theming 의 effective_features 몫이다.
create or replace function news.plan_feature(p_org uuid, p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select p.features -> p_key
  from core.app_entitlements e join core.plans p on p.id = e.plan_id
  where e.org_id = p_org and e.app_id = 'news' and e.status = 'active' and (e.expires_at is null or e.expires_at > now());
$$;

create or replace function news.token_hash(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(convert_to(coalesce(p_token, ''), 'UTF8'), 'sha256'), 'hex');
$$;

create or replace function news.election_blackout_active(p_org uuid, p_at timestamptz)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from news.election_periods e
                 where e.org_id = p_org and e.status = 'active'
                   and p_at >= e.poll_blackout_from and p_at < e.poll_blackout_until);
$$;

create or replace function news.wire_contract_valid(p_org uuid, p_contract_id uuid, p_on date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from news.wire_contracts w
                 where w.id = p_contract_id and w.org_id = p_org and w.status = 'active'
                   and w.starts_on <= p_on and (w.ends_on is null or w.ends_on >= p_on));
$$;

-- 허용 키 밖의 키가 있으면 NW015
create or replace function news.assert_keys(p_fields jsonb, p_allowed text[], p_ctx text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare v_bad text;
begin
  if p_fields is null or jsonb_typeof(p_fields) <> 'object' then
    raise exception '%: fields must be an object', p_ctx using errcode = 'NW015';
  end if;
  select string_agg(k, ', ') into v_bad from jsonb_object_keys(p_fields) as k where not (k = any (p_allowed));
  if v_bad is not null then
    raise exception '%: unknown fields %', p_ctx, v_bad using errcode = 'NW015';
  end if;
end;
$$;

create or replace function news.add_revision(p_article news.articles, p_kind text, p_note text, p_is_public boolean,
                                             p_snapshot boolean, p_request_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  insert into news.article_revisions (org_id, article_id, kind, status_after, title, body, note, is_public, correction_request_id, created_by)
  values (p_article.org_id, p_article.id, p_kind, p_article.status,
          case when p_snapshot then p_article.title end, case when p_snapshot then p_article.body end,
          p_note, coalesce(p_is_public, false), p_request_id, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.1 신문사 개설 (NW-F-001): request(사용자) → approve/reject(운영자 서버)
-- ---------------------------------------------------------------------
create or replace function news.request_newspaper(
  p_slug              text,
  p_title             text,
  p_media_kind        text,
  p_registration_no   text,
  p_registration_date date,
  p_publisher_name    text,
  p_contact_email     text,
  p_contact_phone     text,
  p_certificate_path  text,
  p_message           text default null
)
returns news.newspaper_applications
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_porg uuid;
  v_slug text := lower(btrim(coalesce(p_slug, '')));
  v_ok   boolean;
  v_row  news.newspaper_applications;
begin
  if v_uid is null then
    raise exception 'request_newspaper: login required' using errcode = '42501';
  end if;
  select o.id into v_porg from core.organizations o
   where o.owner_id = v_uid and o.is_personal and o.deleted_at is null order by o.created_at limit 1;
  if v_porg is null then
    raise exception 'request_newspaper: personal organization not found' using errcode = 'P0002';
  end if;
  select r.allowed into v_ok from core.rate_limit_hit('news:apply:' || v_uid::text, 5, 86400) r;
  if not v_ok then
    raise exception 'request_newspaper: rate limited' using errcode = 'NW011';
  end if;
  if v_slug in ('www', 'newsroom', 'login', 'admin', 'api', 'ops', 'app', 'mail', 'static', 'cdn', 'auth', 'help', 'status', 'news', 'assets')
     or exists (select 1 from core.organizations o where o.slug = v_slug)
     or exists (select 1 from news.newspaper_applications a where a.slug = v_slug and a.status = 'pending') then
    raise exception 'request_newspaper: slug unavailable' using errcode = 'NW001';
  end if;
  if exists (select 1 from news.newspaper_applications a where a.applicant_id = v_uid and a.status = 'pending') then
    raise exception 'request_newspaper: a pending application already exists' using errcode = 'NW001';
  end if;
  insert into news.newspaper_applications (applicant_id, applicant_org_id, slug, title, media_kind, registration_no, registration_date,
                                           publisher_name, contact_email, contact_phone, certificate_path, message)
  values (v_uid, v_porg, v_slug, btrim(p_title), p_media_kind, btrim(p_registration_no), p_registration_date,
          btrim(p_publisher_name), lower(btrim(p_contact_email)), btrim(p_contact_phone), p_certificate_path, p_message)
  returning * into v_row;
  perform core.write_audit(v_porg, 'newspaper.request', 'newspaper_application', v_row.id::text, null,
                           jsonb_build_object('slug', v_row.slug, 'title', v_row.title));
  return v_row;
end;
$$;

create or replace function news.withdraw_newspaper_request(p_application_id uuid)
returns news.newspaper_applications
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newspaper_applications;
begin
  select * into v_row from news.newspaper_applications where id = p_application_id for update;
  if not found or (not core.is_service_caller() and v_row.applicant_id is distinct from auth.uid()) then
    raise exception 'withdraw_newspaper_request: not found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'withdraw_newspaper_request: invalid state %', v_row.status using errcode = 'NW004';
  end if;
  update news.newspaper_applications set status = 'withdrawn', decided_at = now() where id = p_application_id returning * into v_row;
  return v_row;
end;
$$;

-- 운영자 승인: 조직(is_personal=false, slug) + owner 멤버십 + 구독·엔타이틀먼트(체험 30일) + 월 크레딧 + 신문사·발행인·기본 설정
create or replace function news.approve_newspaper(p_application_id uuid, p_plan_code text default 'news_trial', p_note text default null)
returns news.newspapers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app   news.newspaper_applications;
  v_plan  core.plans;
  v_org   uuid;
  v_trial boolean;
  v_end   timestamptz;
  v_sub   core.subscriptions;
  v_key   text;
  v_row   news.newspapers;
begin
  if not core.is_service_caller() then
    raise exception 'approve_newspaper: service_role only' using errcode = '42501';
  end if;
  select * into v_app from news.newspaper_applications where id = p_application_id for update;
  if not found then
    raise exception 'approve_newspaper: application not found' using errcode = 'P0002';
  end if;
  if v_app.status <> 'pending' then
    raise exception 'approve_newspaper: invalid state %', v_app.status using errcode = 'NW004';
  end if;
  select * into v_plan from core.plans where app_id = 'news' and code = coalesce(p_plan_code, 'news_trial');
  if not found then
    raise exception 'approve_newspaper: plan % not found', p_plan_code using errcode = 'P0002';
  end if;
  if exists (select 1 from core.organizations o where o.slug = v_app.slug) then
    raise exception 'approve_newspaper: slug already used' using errcode = 'NW001';
  end if;

  insert into core.organizations (name, slug, owner_id, is_personal)
  values (left(v_app.title, 80), v_app.slug, v_app.applicant_id, false)
  returning id into v_org;
  insert into core.org_members (org_id, user_id, role, status, joined_at)
  values (v_org, v_app.applicant_id, 'owner', 'active', now());

  v_trial := v_plan.code = 'news_trial';
  v_end := case when v_trial then now() + interval '30 days'
                when v_plan.billing_interval = 'month' then now() + interval '1 month'
                when v_plan.billing_interval = 'year' then now() + interval '1 year' end;
  insert into core.subscriptions (org_id, app_id, plan_id, status, current_period_start, current_period_end)
  values (v_org, 'news', v_plan.id, case when v_trial then 'trialing' else 'active' end, now(), v_end)
  returning * into v_sub;
  insert into core.app_entitlements (org_id, app_id, plan_id, status, source, expires_at, granted_by, note)
  values (v_org, 'news', v_plan.id, 'active', case when v_trial then 'trial' else 'manual' end,
          case when v_trial then v_end end, auth.uid(), p_note);
  if v_plan.monthly_credits > 0
     and to_regprocedure('core.grant_credits(uuid,integer,text,text,text,text,text,text,jsonb,uuid,boolean)') is not null then
    v_key := 'monthly:' || v_sub.id::text || ':' || to_char(v_sub.current_period_start, 'YYYY-MM-DD');
    perform core.grant_credits(v_org, v_plan.monthly_credits, 'news', 'monthly_plan_credits', 'plan',
                               'subscription', v_sub.id::text, v_key, '{}'::jsonb, null, not v_plan.carry_over);
    update core.subscriptions set last_credit_grant_key = v_key where id = v_sub.id;
  end if;

  insert into news.newspapers (org_id, application_id, title, media_kind, registration_no, registration_date, publisher_name, created_by)
  values (v_org, v_app.id, v_app.title, v_app.media_kind, v_app.registration_no, v_app.registration_date, v_app.publisher_name, auth.uid())
  returning * into v_row;
  insert into news.staff (org_id, user_id, role, status, byline_name, title_label, joined_at)
  values (v_org, v_app.applicant_id, 'publisher', 'active', v_app.publisher_name, '발행인', now());
  insert into news.syndication_settings (org_id) values (v_org) on conflict (org_id) do nothing;
  insert into news.paywall_rules (org_id) values (v_org) on conflict (org_id) do nothing;

  update news.newspaper_applications
     set status = 'approved', org_id = v_org, plan_code = v_plan.code, decided_at = now(), decided_by = auth.uid(), decision_note = p_note
   where id = v_app.id;
  perform core.write_audit(v_org, 'newspaper.approve', 'newspaper', v_row.id::text, null,
                           jsonb_build_object('slug', v_app.slug, 'plan', v_plan.code, 'application_id', v_app.id));
  return v_row;
end;
$$;

create or replace function news.reject_newspaper(p_application_id uuid, p_note text)
returns news.newspaper_applications
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newspaper_applications;
begin
  if not core.is_service_caller() then
    raise exception 'reject_newspaper: service_role only' using errcode = '42501';
  end if;
  select * into v_row from news.newspaper_applications where id = p_application_id for update;
  if not found then
    raise exception 'reject_newspaper: application not found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'reject_newspaper: invalid state %', v_row.status using errcode = 'NW004';
  end if;
  if coalesce(btrim(p_note), '') = '' then
    raise exception 'reject_newspaper: reason required' using errcode = 'NW015';
  end if;
  update news.newspaper_applications set status = 'rejected', decided_at = now(), decided_by = auth.uid(), decision_note = p_note
   where id = p_application_id returning * into v_row;
  perform core.write_audit(v_row.applicant_org_id, 'newspaper.reject', 'newspaper_application', v_row.id::text);
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.2 매체정보(NW-F-002)와 신문사 상태
-- ---------------------------------------------------------------------
create or replace function news.set_newspaper_profile(p_org uuid, p_profile jsonb)
returns news.newspapers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old news.newspapers;
  v_row news.newspapers;
  r     news.newspapers;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'set_newspaper_profile');
  perform news.assert_keys(p_profile, array['title', 'legal_name', 'media_kind', 'registration_no', 'registration_date',
    'publisher_name', 'editor_name', 'youth_officer_name', 'privacy_officer_name', 'publish_address', 'phone', 'email',
    'first_published_on', 'ethics_code_url', 'comments_enabled', 'banned_words'], 'set_newspaper_profile');
  select * into v_old from news.newspapers where org_id = p_org for update;
  if not found then
    raise exception 'set_newspaper_profile: newspaper not found' using errcode = 'P0002';
  end if;
  if v_old.status = 'closed' then
    raise exception 'set_newspaper_profile: newspaper is closed' using errcode = 'NW002';
  end if;
  r := jsonb_populate_record(null::news.newspapers, p_profile);
  update news.newspapers set
    title                = case when p_profile ? 'title'                then btrim(r.title)                else title end,
    legal_name           = case when p_profile ? 'legal_name'           then nullif(btrim(r.legal_name), '') else legal_name end,
    media_kind           = case when p_profile ? 'media_kind'           then r.media_kind                  else media_kind end,
    registration_no      = case when p_profile ? 'registration_no'      then nullif(btrim(r.registration_no), '') else registration_no end,
    registration_date    = case when p_profile ? 'registration_date'    then r.registration_date           else registration_date end,
    publisher_name       = case when p_profile ? 'publisher_name'       then nullif(btrim(r.publisher_name), '') else publisher_name end,
    editor_name          = case when p_profile ? 'editor_name'          then nullif(btrim(r.editor_name), '') else editor_name end,
    youth_officer_name   = case when p_profile ? 'youth_officer_name'   then nullif(btrim(r.youth_officer_name), '') else youth_officer_name end,
    privacy_officer_name = case when p_profile ? 'privacy_officer_name' then nullif(btrim(r.privacy_officer_name), '') else privacy_officer_name end,
    publish_address      = case when p_profile ? 'publish_address'      then nullif(btrim(r.publish_address), '') else publish_address end,
    phone                = case when p_profile ? 'phone'                then nullif(btrim(r.phone), '')    else phone end,
    email                = case when p_profile ? 'email'                then nullif(lower(btrim(r.email)), '') else email end,
    first_published_on   = case when p_profile ? 'first_published_on'   then r.first_published_on          else first_published_on end,
    ethics_code_url      = case when p_profile ? 'ethics_code_url'      then r.ethics_code_url             else ethics_code_url end,
    comments_enabled     = case when p_profile ? 'comments_enabled'     then coalesce(r.comments_enabled, false) else comments_enabled end,
    banned_words         = case when p_profile ? 'banned_words'         then coalesce(r.banned_words, '{}') else banned_words end
  where org_id = p_org
  returning * into v_row;
  perform core.write_audit(p_org, 'newspaper.profile', 'newspaper', v_row.id::text,
    jsonb_build_object('complete', v_old.profile_completed_at is not null, 'comments_enabled', v_old.comments_enabled),
    jsonb_build_object('complete', v_row.profile_completed_at is not null, 'comments_enabled', v_row.comments_enabled,
                       'fields', (select jsonb_agg(k) from jsonb_object_keys(p_profile) k where k <> 'banned_words')));
  return v_row;
end;
$$;

create or replace function news.set_newspaper_status(p_org uuid, p_status text, p_reason text default null)
returns news.newspapers
language plpgsql
security definer
set search_path = ''
as $$
declare v_old news.newspapers; v_row news.newspapers;
begin
  if not core.is_service_caller() then
    raise exception 'set_newspaper_status: service_role only' using errcode = '42501';
  end if;
  select * into v_old from news.newspapers where org_id = p_org for update;
  if not found then
    raise exception 'set_newspaper_status: newspaper not found' using errcode = 'P0002';
  end if;
  update news.newspapers set status = p_status, status_reason = p_reason where org_id = p_org returning * into v_row;
  perform core.write_audit(p_org, 'newspaper.status', 'newspaper', v_row.id::text,
                           jsonb_build_object('status', v_old.status), jsonb_build_object('status', v_row.status, 'reason', p_reason));
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.3 편집국 구성원(NW-F-004). 코어 멤버 함수(invite_member 등)를 그대로 거친다(코어 역할 검사·감사 재사용).
--      publisher 는 승인 때 한 번 만들어지고 이 함수들로는 바뀌지 않는다(소유권 이전은 core.transfer_ownership + 운영 절차).
-- ---------------------------------------------------------------------
create or replace function news.invite_staff(p_org uuid, p_user_id uuid, p_role text, p_byline_name text, p_title_label text default null)
returns news.staff
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller text;
  v_max    integer;
  v_old    news.staff;
  v_row    news.staff;
begin
  v_caller := news.assert_staff(p_org, array['publisher', 'editor'], 'invite_staff');
  if p_role is null or p_role not in ('editor', 'desk', 'reporter', 'contributor', 'ad_manager') then
    raise exception 'invite_staff: invalid role %', p_role using errcode = 'NW015';
  end if;
  if v_caller = 'editor' and p_role = 'editor' then
    raise exception 'invite_staff: editor cannot grant editor' using errcode = '42501';
  end if;
  select * into v_old from news.staff where org_id = p_org and user_id = p_user_id for update;
  if found and v_old.status <> 'removed' then
    raise exception 'invite_staff: already a staff member' using errcode = 'NW004';
  end if;
  v_max := (news.plan_feature(p_org, 'news_staff_max') #>> '{}')::integer;
  if v_max is not null and v_max >= 0
     and (select count(*) from news.staff s where s.org_id = p_org and s.status <> 'removed') >= v_max then
    raise exception 'invite_staff: staff limit % reached', v_max using errcode = 'NW014';
  end if;
  perform core.invite_member(p_org, p_user_id, case when p_role = 'editor' then 'admin' else 'member' end);
  if v_old.id is null then
    insert into news.staff (org_id, user_id, role, status, byline_name, title_label, invited_by)
    values (p_org, p_user_id, p_role, 'invited', btrim(p_byline_name), p_title_label, auth.uid())
    returning * into v_row;
  else
    update news.staff set status = 'invited', role = p_role, byline_name = btrim(p_byline_name), title_label = p_title_label, invited_by = auth.uid()
     where id = v_old.id returning * into v_row;
  end if;
  perform core.write_audit(p_org, 'staff.invite', 'user', p_user_id::text, null, jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function news.accept_staff_invite(p_org uuid)
returns news.staff
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.staff;
begin
  if auth.uid() is null then
    raise exception 'accept_staff_invite: login required' using errcode = '42501';
  end if;
  select * into v_row from news.staff where org_id = p_org and user_id = auth.uid() and status = 'invited' for update;
  if not found then
    raise exception 'accept_staff_invite: no pending invitation' using errcode = 'P0002';
  end if;
  perform core.accept_invite(p_org);
  update news.staff set status = 'active' where id = v_row.id returning * into v_row;
  perform core.write_audit(p_org, 'staff.accept', 'user', auth.uid()::text, null, jsonb_build_object('role', v_row.role));
  return v_row;
end;
$$;

create or replace function news.set_staff_role(p_org uuid, p_user_id uuid, p_role text)
returns news.staff
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller text;
  v_old    news.staff;
  v_row    news.staff;
  v_core_old text;
  v_core_new text;
begin
  v_caller := news.assert_staff(p_org, array['publisher', 'editor'], 'set_staff_role');
  if p_user_id = auth.uid() then
    raise exception 'set_staff_role: cannot change your own role' using errcode = '42501';
  end if;
  if p_role is null or p_role not in ('editor', 'desk', 'reporter', 'contributor', 'ad_manager') then
    raise exception 'set_staff_role: invalid role %', p_role using errcode = 'NW015';
  end if;
  select * into v_old from news.staff where org_id = p_org and user_id = p_user_id and status in ('invited', 'active') for update;
  if not found then
    raise exception 'set_staff_role: staff not found' using errcode = 'P0002';
  end if;
  if v_old.role = 'publisher' then
    raise exception 'set_staff_role: publisher role changes only by ownership transfer' using errcode = '42501';
  end if;
  if v_caller = 'editor' and (v_old.role = 'editor' or p_role = 'editor') then
    raise exception 'set_staff_role: editor cannot change editor roles' using errcode = '42501';
  end if;
  v_core_old := case when v_old.role = 'editor' then 'admin' else 'member' end;
  v_core_new := case when p_role = 'editor' then 'admin' else 'member' end;
  if v_core_old <> v_core_new then
    perform core.change_member_role(p_org, p_user_id, v_core_new);
  end if;
  update news.staff set role = p_role where id = v_old.id returning * into v_row;
  perform core.write_audit(p_org, 'staff.role', 'user', p_user_id::text,
                           jsonb_build_object('role', v_old.role), jsonb_build_object('role', p_role));
  return v_row;
end;
$$;

create or replace function news.remove_staff(p_org uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_caller text; v_old news.staff;
begin
  v_caller := news.assert_staff(p_org, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager'], 'remove_staff');
  select * into v_old from news.staff where org_id = p_org and user_id = p_user_id and status in ('invited', 'active') for update;
  if not found then
    raise exception 'remove_staff: staff not found' using errcode = 'P0002';
  end if;
  if v_old.role = 'publisher' then
    raise exception 'remove_staff: publisher cannot be removed' using errcode = '42501';
  end if;
  if v_caller <> 'service' and p_user_id <> auth.uid() then
    if v_caller not in ('publisher', 'editor') or (v_caller = 'editor' and v_old.role = 'editor') then
      raise exception 'remove_staff: not allowed' using errcode = '42501';
    end if;
  end if;
  perform core.remove_member(p_org, p_user_id);
  update news.staff set status = 'removed' where id = v_old.id;
  perform core.write_audit(p_org, 'staff.remove', 'user', p_user_id::text, jsonb_build_object('role', v_old.role), null);
end;
$$;

create or replace function news.update_my_staff_profile(p_org uuid, p_fields jsonb)
returns news.staff
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.staff; r news.staff;
begin
  perform news.assert_keys(p_fields, array['byline_name', 'title_label', 'bio', 'photo_path', 'email_public', 'is_public_profile'], 'update_my_staff_profile');
  if auth.uid() is null then
    raise exception 'update_my_staff_profile: login required' using errcode = '42501';
  end if;
  r := jsonb_populate_record(null::news.staff, p_fields);
  update news.staff set
    byline_name       = case when p_fields ? 'byline_name'       then btrim(r.byline_name) else byline_name end,
    title_label       = case when p_fields ? 'title_label'       then r.title_label        else title_label end,
    bio               = case when p_fields ? 'bio'               then r.bio                else bio end,
    photo_path        = case when p_fields ? 'photo_path'        then r.photo_path         else photo_path end,
    email_public      = case when p_fields ? 'email_public'      then r.email_public       else email_public end,
    is_public_profile = case when p_fields ? 'is_public_profile' then coalesce(r.is_public_profile, true) else is_public_profile end
  where org_id = p_org and user_id = auth.uid() and status = 'active'
  returning * into v_row;
  if not found then
    raise exception 'update_my_staff_profile: not an active staff member' using errcode = '42501';
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.4 분류(섹션·지역·태그): DESK
-- ---------------------------------------------------------------------
create or replace function news.upsert_taxonomy(p_org uuid, p_kind text, p_id uuid, p_fields jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; s news.sections; g news.regions; t news.tags;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'desk'], 'upsert_taxonomy');
  if p_kind = 'section' then
    perform news.assert_keys(p_fields, array['slug', 'name', 'parent_id', 'sort_order', 'is_active'], 'upsert_taxonomy');
    s := jsonb_populate_record(null::news.sections, p_fields);
    if p_id is null then
      insert into news.sections (org_id, slug, name, parent_id, sort_order, is_active)
      values (p_org, s.slug, s.name, s.parent_id, coalesce(s.sort_order, 0), coalesce(s.is_active, true)) returning id into v_id;
    else
      update news.sections set
        slug = case when p_fields ? 'slug' then s.slug else slug end, name = case when p_fields ? 'name' then s.name else name end,
        parent_id = case when p_fields ? 'parent_id' then s.parent_id else parent_id end,
        sort_order = case when p_fields ? 'sort_order' then coalesce(s.sort_order, 0) else sort_order end,
        is_active = case when p_fields ? 'is_active' then coalesce(s.is_active, true) else is_active end
      where id = p_id and org_id = p_org returning id into v_id;
    end if;
  elsif p_kind = 'region' then
    perform news.assert_keys(p_fields, array['slug', 'name', 'level', 'admin_code', 'parent_id', 'sort_order', 'is_active'], 'upsert_taxonomy');
    g := jsonb_populate_record(null::news.regions, p_fields);
    if p_id is null then
      insert into news.regions (org_id, slug, name, level, admin_code, parent_id, sort_order, is_active)
      values (p_org, g.slug, g.name, coalesce(g.level, 'sigungu'), g.admin_code, g.parent_id, coalesce(g.sort_order, 0), coalesce(g.is_active, true))
      returning id into v_id;
    else
      update news.regions set
        slug = case when p_fields ? 'slug' then g.slug else slug end, name = case when p_fields ? 'name' then g.name else name end,
        level = case when p_fields ? 'level' then g.level else level end,
        admin_code = case when p_fields ? 'admin_code' then g.admin_code else admin_code end,
        parent_id = case when p_fields ? 'parent_id' then g.parent_id else parent_id end,
        sort_order = case when p_fields ? 'sort_order' then coalesce(g.sort_order, 0) else sort_order end,
        is_active = case when p_fields ? 'is_active' then coalesce(g.is_active, true) else is_active end
      where id = p_id and org_id = p_org returning id into v_id;
    end if;
  elsif p_kind = 'tag' then
    perform news.assert_keys(p_fields, array['slug', 'name', 'is_active'], 'upsert_taxonomy');
    t := jsonb_populate_record(null::news.tags, p_fields);
    if p_id is null then
      insert into news.tags (org_id, slug, name, is_active) values (p_org, t.slug, t.name, coalesce(t.is_active, true)) returning id into v_id;
    else
      update news.tags set
        slug = case when p_fields ? 'slug' then t.slug else slug end, name = case when p_fields ? 'name' then t.name else name end,
        is_active = case when p_fields ? 'is_active' then coalesce(t.is_active, true) else is_active end
      where id = p_id and org_id = p_org returning id into v_id;
    end if;
  else
    raise exception 'upsert_taxonomy: invalid kind %', p_kind using errcode = 'NW015';
  end if;
  if v_id is null then
    raise exception 'upsert_taxonomy: not found' using errcode = 'P0002';
  end if;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.5 기사(NW-F-010~012, 017, 050)
--   save_article : 만들기(draft) 또는 고치기. 기자·기고자는 자기 draft 만, 데스크 이상은 draft/submitted/approved/published/unpublished.
--                  게시 후 수정은 change_note(공개 수정 사유) 필수 → revised_at, revision_note, 공개 이력 1행.
--                  기고자의 유형은 contribution 으로 고정. origin(ai_press_release, import)은 서버만 지정한다.
-- ---------------------------------------------------------------------
create or replace function news.save_article(p_org uuid, p_article_id uuid, p_fields jsonb)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text;
  v_old    news.articles;
  v_row    news.articles;
  r        news.articles;
  v_own    boolean;
  v_byline text;
  v_slug   text;
  v_note   text := nullif(btrim(coalesce(p_fields ->> 'change_note', '')), '');
  v_auto   boolean := coalesce((p_fields ->> 'autosave')::boolean, false);
  v_ids    uuid[];
  -- 독자에게 보이는 내용 필드. 게시 후 이 필드를 바꾸면 공개 수정 사유가 필요하다(댓글·SEO·속보 표시 같은 설정 변경은 아님)
  v_content boolean := p_fields ?| array['title', 'subtitle', 'summary', 'body', 'body_text', 'type', 'byline', 'sponsor_label',
                                         'ai_assisted', 'ai_disclosure', 'wire_contract_id', 'source_note', 'is_poll', 'poll_disclosure',
                                         'hero_media_id', 'media_ids', 'is_premium'];
  v_public_edit boolean := false;
begin
  v_role := news.assert_staff(p_org, array['publisher', 'editor', 'desk', 'reporter', 'contributor'], 'save_article');
  perform news.assert_keys(p_fields, array['slug', 'title', 'subtitle', 'summary', 'body', 'body_text', 'type', 'origin',
    'section_id', 'author_id', 'byline', 'is_premium', 'sponsor_label', 'ai_assisted', 'ai_disclosure', 'wire_contract_id',
    'source_note', 'is_poll', 'poll_disclosure', 'is_breaking', 'is_live', 'comments_enabled', 'embargo_until', 'hero_media_id',
    'media_ids', 'seo', 'legacy_id', 'legacy_url', 'region_ids', 'tag_ids', 'change_note', 'autosave'], 'save_article');
  r := jsonb_populate_record(null::news.articles, p_fields - 'region_ids' - 'tag_ids' - 'change_note' - 'autosave');
  if p_fields ? 'origin' and coalesce(r.origin, 'human') <> 'human' and v_role <> 'service' then
    raise exception 'save_article: only the server can set origin %', r.origin using errcode = '42501';
  end if;
  if p_fields ? 'author_id' and r.author_id is not null
     and not exists (select 1 from news.staff s where s.org_id = p_org and s.user_id = r.author_id and s.status = 'active') then
    raise exception 'save_article: author must be active staff' using errcode = 'NW015';
  end if;
  if r.media_ids is not null and exists (select 1 from unnest(r.media_ids) m
       where not exists (select 1 from news.media_assets x where x.id = m and x.org_id = p_org)) then
    raise exception 'save_article: media must belong to the newspaper' using errcode = '23503';
  end if;
  if v_role = 'contributor' then
    r.type := 'contribution';
  end if;

  if p_article_id is null then
    select s.byline_name into v_byline from news.staff s where s.org_id = p_org and s.user_id = coalesce(r.author_id, auth.uid());
    v_slug := coalesce(nullif(btrim(r.slug), ''), 'a' || encode(extensions.gen_random_bytes(6), 'hex'));
    insert into news.articles (org_id, slug, title, subtitle, summary, body, body_text, type, origin, section_id, author_id, byline,
      is_premium, sponsor_label, ai_assisted, ai_disclosure, wire_contract_id, source_note, is_poll, poll_disclosure,
      is_breaking, is_live, comments_enabled, embargo_until, hero_media_id, media_ids, seo, legacy_id, legacy_url, created_by)
    values (p_org, v_slug, btrim(r.title), r.subtitle, r.summary, coalesce(r.body, '[]'::jsonb), coalesce(r.body_text, ''),
      coalesce(case when v_role = 'contributor' then 'contribution' else r.type end, 'original'), coalesce(r.origin, 'human'),
      r.section_id, coalesce(r.author_id, auth.uid()), coalesce(nullif(btrim(r.byline), ''), v_byline, '편집국'),
      coalesce(r.is_premium, false), r.sponsor_label, coalesce(r.ai_assisted, false), r.ai_disclosure, r.wire_contract_id, r.source_note,
      coalesce(r.is_poll, false), r.poll_disclosure, coalesce(r.is_breaking, false), coalesce(r.is_live, false),
      coalesce(r.comments_enabled, true), r.embargo_until, r.hero_media_id, coalesce(r.media_ids, '{}'), coalesce(r.seo, '{}'::jsonb),
      r.legacy_id, r.legacy_url, auth.uid())
    returning * into v_row;
  else
    select * into v_old from news.articles where id = p_article_id and org_id = p_org for update;
    if not found then
      raise exception 'save_article: not found' using errcode = 'P0002';
    end if;
    if p_fields ? 'origin' and r.origin is distinct from v_old.origin then
      raise exception 'save_article: origin is immutable' using errcode = '22023';
    end if;
    v_own := v_old.created_by = auth.uid() or v_old.author_id = auth.uid();
    if v_role in ('reporter', 'contributor') then
      if not v_own then
        raise exception 'save_article: only your own articles' using errcode = '42501';
      end if;
      if v_old.status <> 'draft' then
        raise exception 'save_article: reporters edit drafts only (state %)', v_old.status using errcode = 'NW004';
      end if;
    elsif v_old.status in ('scheduled', 'archived') then
      raise exception 'save_article: cannot edit in state %', v_old.status using errcode = 'NW004';
    end if;
    v_public_edit := v_old.status in ('published', 'unpublished') and v_content;
    if v_public_edit and v_note is null then
      raise exception 'save_article: change_note is required after publication' using errcode = 'NW015';
    end if;
    update news.articles set
      slug             = case when p_fields ? 'slug'             then r.slug             else slug end,
      title            = case when p_fields ? 'title'            then btrim(r.title)     else title end,
      subtitle         = case when p_fields ? 'subtitle'         then r.subtitle         else subtitle end,
      summary          = case when p_fields ? 'summary'          then r.summary          else summary end,
      body             = case when p_fields ? 'body'             then coalesce(r.body, '[]'::jsonb) else body end,
      body_text        = case when p_fields ? 'body_text'        then coalesce(r.body_text, '') else body_text end,
      type             = case when v_role = 'contributor' then 'contribution' when p_fields ? 'type' then r.type else type end,
      section_id       = case when p_fields ? 'section_id'       then r.section_id       else section_id end,
      author_id        = case when p_fields ? 'author_id'        then r.author_id        else author_id end,
      byline           = case when p_fields ? 'byline'           then btrim(r.byline)    else byline end,
      is_premium       = case when p_fields ? 'is_premium'       then coalesce(r.is_premium, false) else is_premium end,
      sponsor_label    = case when p_fields ? 'sponsor_label'    then r.sponsor_label    else sponsor_label end,
      ai_assisted      = case when p_fields ? 'ai_assisted'      then coalesce(r.ai_assisted, false) else ai_assisted end,
      ai_disclosure    = case when p_fields ? 'ai_disclosure'    then r.ai_disclosure    else ai_disclosure end,
      wire_contract_id = case when p_fields ? 'wire_contract_id' then r.wire_contract_id else wire_contract_id end,
      source_note      = case when p_fields ? 'source_note'      then r.source_note      else source_note end,
      is_poll          = case when p_fields ? 'is_poll'          then coalesce(r.is_poll, false) else is_poll end,
      poll_disclosure  = case when p_fields ? 'poll_disclosure'  then r.poll_disclosure  else poll_disclosure end,
      is_breaking      = case when p_fields ? 'is_breaking'      then coalesce(r.is_breaking, false) else is_breaking end,
      is_live          = case when p_fields ? 'is_live'          then coalesce(r.is_live, false) else is_live end,
      comments_enabled = case when p_fields ? 'comments_enabled' then coalesce(r.comments_enabled, true) else comments_enabled end,
      embargo_until    = case when p_fields ? 'embargo_until'    then r.embargo_until    else embargo_until end,
      hero_media_id    = case when p_fields ? 'hero_media_id'    then r.hero_media_id    else hero_media_id end,
      media_ids        = case when p_fields ? 'media_ids'        then coalesce(r.media_ids, '{}') else media_ids end,
      seo              = case when p_fields ? 'seo'              then coalesce(r.seo, '{}'::jsonb) else seo end,
      legacy_id        = case when p_fields ? 'legacy_id'        then r.legacy_id        else legacy_id end,
      legacy_url       = case when p_fields ? 'legacy_url'       then r.legacy_url       else legacy_url end,
      revised_at       = case when v_public_edit then now() else revised_at end,
      revision_note    = case when v_public_edit then v_note else revision_note end,
      revision_count   = case when v_public_edit then revision_count + 1 else revision_count end
    where id = p_article_id
    returning * into v_row;
  end if;

  if p_fields ? 'region_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_ids from jsonb_array_elements_text(coalesce(p_fields -> 'region_ids', '[]'::jsonb)) x;
    delete from news.article_regions where article_id = v_row.id;
    insert into news.article_regions (org_id, article_id, region_id) select p_org, v_row.id, u from unnest(v_ids) u;
  end if;
  if p_fields ? 'tag_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_ids from jsonb_array_elements_text(coalesce(p_fields -> 'tag_ids', '[]'::jsonb)) x;
    delete from news.article_tags where article_id = v_row.id;
    insert into news.article_tags (org_id, article_id, tag_id) select p_org, v_row.id, u from unnest(v_ids) u;
  end if;

  if v_public_edit then
    perform news.add_revision(v_row, 'update', v_note, true, true);
  elsif not v_auto then
    perform news.add_revision(v_row, 'save', null, false, true);
  end if;
  return v_row;
end;
$$;

create or replace function news.submit_article(p_article_id uuid)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare v_role text; v_a news.articles;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'submit_article: not found' using errcode = 'P0002';
  end if;
  v_role := news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor'], 'submit_article');
  if v_role in ('reporter', 'contributor') and not (v_a.created_by = auth.uid() or v_a.author_id = auth.uid()) then
    raise exception 'submit_article: only your own articles' using errcode = '42501';
  end if;
  if v_a.status <> 'draft' then
    raise exception 'submit_article: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  update news.articles set status = 'submitted', submitted_by = auth.uid(), review_note = null where id = p_article_id returning * into v_a;
  perform news.add_revision(v_a, 'submit', null, false, false);
  return v_a;
end;
$$;

-- 데스크 승인·반려. 승인은 사람만 한다(서버·AI 단독 승인 금지, NW006). 반려는 사유 필수.
create or replace function news.review_article(p_article_id uuid, p_decision text, p_note text default null)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare v_a news.articles;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'review_article: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk'], 'review_article');
  if v_a.status <> 'submitted' then
    raise exception 'review_article: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  if p_decision = 'approve' then
    if auth.uid() is null then
      raise exception 'review_article: approval requires a human editor' using errcode = 'NW006';
    end if;
    update news.articles set status = 'approved', approved_by = auth.uid(), review_note = p_note where id = p_article_id returning * into v_a;
    perform news.add_revision(v_a, 'approve', p_note, false, true);
  elsif p_decision = 'reject' then
    if coalesce(btrim(p_note), '') = '' then
      raise exception 'review_article: rejection reason required' using errcode = 'NW015';
    end if;
    update news.articles set status = 'draft', review_note = p_note where id = p_article_id returning * into v_a;
    perform news.add_revision(v_a, 'reject', p_note, false, false);
  else
    raise exception 'review_article: decision must be approve or reject' using errcode = 'NW015';
  end if;
  perform core.write_audit(v_a.org_id, 'article.' || p_decision, 'article', p_article_id::text, null,
                           jsonb_build_object('origin', v_a.origin, 'type', v_a.type));
  return v_a;
end;
$$;

-- 게시 요건(게시·예약 공통): 매체정보 완성, 신문사 활성, 사람 승인, 전재 계약, 선거 공표 금지
create or replace function news.assert_publishable(p_a news.articles, p_at timestamptz)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_np news.newspapers;
begin
  select * into v_np from news.newspapers where org_id = p_a.org_id;
  if not found or v_np.status <> 'active' then
    raise exception 'publish: newspaper is not active' using errcode = 'NW002';
  end if;
  if v_np.profile_completed_at is null then
    raise exception 'publish: legally required newspaper information is incomplete' using errcode = 'NW003';
  end if;
  if p_a.approved_by is null then
    raise exception 'publish: human approval missing' using errcode = 'NW006';
  end if;
  if p_a.type = 'wire' and not news.wire_contract_valid(p_a.org_id, p_a.wire_contract_id, (p_at at time zone 'Asia/Seoul')::date) then
    raise exception 'publish: wire contract missing or expired' using errcode = 'NW005';
  end if;
  if p_a.is_poll and news.election_blackout_active(p_a.org_id, p_at) then
    raise exception 'publish: poll publication blackout period' using errcode = 'NW007';
  end if;
end;
$$;

create or replace function news.schedule_article(p_article_id uuid, p_at timestamptz)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare v_a news.articles;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'schedule_article: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk'], 'schedule_article');
  if v_a.status <> 'approved' then
    raise exception 'schedule_article: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  if p_at is null or p_at <= now() or p_at > now() + interval '90 days' then
    raise exception 'schedule_article: time must be within the next 90 days' using errcode = 'NW015';
  end if;
  perform news.assert_publishable(v_a, p_at);
  update news.articles set status = 'scheduled', scheduled_for = p_at where id = p_article_id returning * into v_a;
  perform news.add_revision(v_a, 'schedule', to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM-DD HH24:MI'), false, false);
  perform core.write_audit(v_a.org_id, 'article.schedule', 'article', p_article_id::text, null, jsonb_build_object('at', p_at));
  return v_a;
end;
$$;

-- 게시: 데스크 이상이 approved/unpublished 를, 서버(예약 실행)가 scheduled 를 게시한다. 서버는 approved 를 바로 게시할 수 없다.
create or replace function news.publish_article(p_article_id uuid)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare v_role text; v_a news.articles;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'publish_article: not found' using errcode = 'P0002';
  end if;
  v_role := news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk'], 'publish_article');
  if v_a.status not in ('approved', 'scheduled', 'unpublished') then
    raise exception 'publish_article: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  if v_role = 'service' and v_a.status <> 'scheduled' then
    raise exception 'publish_article: the server publishes scheduled articles only' using errcode = '42501';
  end if;
  perform news.assert_publishable(v_a, now());
  update news.articles set status = 'published' where id = p_article_id returning * into v_a;
  update news.media_assets set published_at = coalesce(published_at, now())
   where org_id = v_a.org_id and (id = v_a.hero_media_id or id = any (v_a.media_ids));
  perform news.add_revision(v_a, 'publish', null, false, true);
  perform core.write_audit(v_a.org_id, 'article.publish', 'article', p_article_id::text, null,
                           jsonb_build_object('type', v_a.type, 'origin', v_a.origin, 'published_at', v_a.published_at));
  return v_a;
end;
$$;

create or replace function news.unpublish_article(p_article_id uuid, p_reason text)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare v_a news.articles;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'unpublish_article: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk'], 'unpublish_article');
  if v_a.status <> 'published' then
    raise exception 'unpublish_article: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'unpublish_article: reason required' using errcode = 'NW015';
  end if;
  update news.articles set status = 'unpublished', unpublish_reason = p_reason where id = p_article_id returning * into v_a;
  perform news.add_revision(v_a, 'unpublish', p_reason, false, false);
  perform core.write_audit(v_a.org_id, 'article.unpublish', 'article', p_article_id::text, null, jsonb_build_object('reason', p_reason));
  return v_a;
end;
$$;

create or replace function news.archive_article(p_article_id uuid)
returns news.articles
language plpgsql
security definer
set search_path = ''
as $$
declare v_role text; v_a news.articles;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'archive_article: not found' using errcode = 'P0002';
  end if;
  v_role := news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk', 'reporter', 'contributor'], 'archive_article');
  if v_role in ('reporter', 'contributor') and not (v_a.status = 'draft' and (v_a.created_by = auth.uid() or v_a.author_id = auth.uid())) then
    raise exception 'archive_article: reporters archive their own drafts only' using errcode = '42501';
  end if;
  if v_a.status not in ('draft', 'published', 'unpublished') then
    raise exception 'archive_article: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  update news.articles set status = 'archived' where id = p_article_id returning * into v_a;
  perform news.add_revision(v_a, 'archive', null, false, false);
  return v_a;
end;
$$;

-- 정정·반론·추후보도·해명 기록(NW-F-017, 027). 공개 이력 1행 + 기사 정정 표시. 청구 건과 연결하면 청구를 published 로.
create or replace function news.record_article_correction(p_article_id uuid, p_kind text, p_note text, p_correction_request_id uuid default null)
returns news.article_revisions
language plpgsql
security definer
set search_path = ''
as $$
declare v_a news.articles; v_req news.correction_requests; v_rev_id uuid; v_rev news.article_revisions;
begin
  select * into v_a from news.articles where id = p_article_id for update;
  if not found then
    raise exception 'record_article_correction: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk'], 'record_article_correction');
  if v_a.status not in ('published', 'unpublished') then
    raise exception 'record_article_correction: invalid state %', v_a.status using errcode = 'NW004';
  end if;
  if p_kind is null or p_kind not in ('correction', 'clarification', 'rebuttal', 'follow_up') then
    raise exception 'record_article_correction: invalid kind %', p_kind using errcode = 'NW015';
  end if;
  if char_length(btrim(coalesce(p_note, ''))) < 5 then
    raise exception 'record_article_correction: public note required' using errcode = 'NW015';
  end if;
  if p_correction_request_id is not null then
    select * into v_req from news.correction_requests where id = p_correction_request_id and org_id = v_a.org_id for update;
    if not found then
      raise exception 'record_article_correction: request not found' using errcode = 'P0002';
    end if;
    if v_req.status <> 'accepted' then
      raise exception 'record_article_correction: request is not accepted (state %)', v_req.status using errcode = 'NW004';
    end if;
    if v_req.kind <> p_kind and not (v_req.kind = 'correction' and p_kind = 'clarification') then
      raise exception 'record_article_correction: kind % does not match request %', p_kind, v_req.kind using errcode = 'NW015';
    end if;
  end if;
  update news.articles set last_corrected_at = now(), correction_count = correction_count + 1 where id = p_article_id returning * into v_a;
  v_rev_id := news.add_revision(v_a, p_kind, btrim(p_note), true, true, p_correction_request_id);
  if p_correction_request_id is not null then
    update news.correction_requests set status = 'published', published_revision_id = v_rev_id, article_id = coalesce(article_id, p_article_id)
     where id = p_correction_request_id;
  end if;
  perform core.write_audit(v_a.org_id, 'article.' || p_kind, 'article', p_article_id::text, null,
                           jsonb_build_object('revision_id', v_rev_id, 'request_id', p_correction_request_id));
  select * into v_rev from news.article_revisions where id = v_rev_id;
  return v_rev;
end;
$$;

-- 예약 실행(service_role, 매분): 예약 기사 게시 + 예약 홈 편집 게시. 기사 게시가 요건 위반이면 approved 로 되돌리고 사유를 남긴다.
create or replace function news.run_scheduled_publishing()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_ok integer := 0;
  v_fail integer := 0;
  v_layouts integer := 0;
begin
  if not core.is_service_caller() then
    raise exception 'run_scheduled_publishing: service_role only' using errcode = '42501';
  end if;
  for r in select a.id from news.articles a where a.status = 'scheduled' and a.scheduled_for <= now()
           order by a.scheduled_for limit 200 for update skip locked
  loop
    begin
      perform news.publish_article(r.id);
      v_ok := v_ok + 1;
    exception when others then
      update news.articles set status = 'approved', review_note = left('예약 게시 실패(' || sqlstate || '): ' || sqlerrm, 2000) where id = r.id;
      v_fail := v_fail + 1;
    end;
  end loop;
  for r in select h.id, h.org_id from news.home_layouts h where h.status = 'scheduled' and h.publish_at <= now()
           order by h.publish_at for update skip locked
  loop
    perform news.publish_home_layout(r.id, null);
    v_layouts := v_layouts + 1;
  end loop;
  return jsonb_build_object('published', v_ok, 'failed', v_fail, 'layouts', v_layouts);
end;
$$;

-- ---------------------------------------------------------------------
-- 11.6 미디어, 홈 편집, 지면, 라이브
-- ---------------------------------------------------------------------
create or replace function news.save_media_asset(p_org uuid, p_id uuid, p_fields jsonb)
returns news.media_assets
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.media_assets; r news.media_assets;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'desk', 'reporter', 'contributor'], 'save_media_asset');
  perform news.assert_keys(p_fields, array['bucket', 'storage_path', 'kind', 'mime', 'width', 'height', 'bytes', 'alt_text', 'caption',
                                           'credit', 'copyright_holder', 'license', 'ai_generated', 'ai_disclosure', 'status'], 'save_media_asset');
  r := jsonb_populate_record(null::news.media_assets, p_fields);
  if p_id is null then
    insert into news.media_assets (org_id, bucket, storage_path, kind, mime, width, height, bytes, alt_text, caption, credit,
                                   copyright_holder, license, ai_generated, ai_disclosure, created_by)
    values (p_org, coalesce(r.bucket, 'public-assets'), r.storage_path, coalesce(r.kind, 'image'), r.mime, r.width, r.height, r.bytes,
            r.alt_text, r.caption, r.credit, r.copyright_holder, coalesce(r.license, 'own'), coalesce(r.ai_generated, false), r.ai_disclosure, auth.uid())
    returning * into v_row;
  else
    if p_fields ? 'storage_path' or p_fields ? 'bucket' then
      raise exception 'save_media_asset: file path is immutable' using errcode = '22023';
    end if;
    update news.media_assets set
      alt_text = case when p_fields ? 'alt_text' then r.alt_text else alt_text end,
      caption = case when p_fields ? 'caption' then r.caption else caption end,
      credit = case when p_fields ? 'credit' then r.credit else credit end,
      copyright_holder = case when p_fields ? 'copyright_holder' then r.copyright_holder else copyright_holder end,
      license = case when p_fields ? 'license' then r.license else license end,
      ai_generated = case when p_fields ? 'ai_generated' then coalesce(r.ai_generated, false) else ai_generated end,
      ai_disclosure = case when p_fields ? 'ai_disclosure' then r.ai_disclosure else ai_disclosure end,
      status = case when p_fields ? 'status' then r.status else status end,
      width = case when p_fields ? 'width' then r.width else width end,
      height = case when p_fields ? 'height' then r.height else height end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'save_media_asset: not found' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

create or replace function news.save_home_layout(p_org uuid, p_id uuid, p_fields jsonb)
returns news.home_layouts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.home_layouts; r news.home_layouts;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'desk'], 'save_home_layout');
  perform news.assert_keys(p_fields, array['name', 'template', 'blocks'], 'save_home_layout');
  r := jsonb_populate_record(null::news.home_layouts, p_fields);
  if p_id is null then
    insert into news.home_layouts (org_id, name, template, blocks, created_by)
    values (p_org, coalesce(r.name, '새 홈 편집'), coalesce(r.template, 'traditional'), coalesce(r.blocks, '[]'::jsonb), auth.uid())
    returning * into v_row;
  else
    update news.home_layouts set
      name = case when p_fields ? 'name' then r.name else name end,
      template = case when p_fields ? 'template' then r.template else template end,
      blocks = case when p_fields ? 'blocks' then coalesce(r.blocks, '[]'::jsonb) else blocks end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'save_home_layout: not found' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

-- 홈 편집 게시(NW-F-013). p_at 이 미래면 예약, 아니면 즉시 게시(이전 게시본은 archived, version + 1)
create or replace function news.publish_home_layout(p_layout_id uuid, p_at timestamptz default null)
returns news.home_layouts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.home_layouts; v_ver integer;
begin
  select * into v_row from news.home_layouts where id = p_layout_id for update;
  if not found then
    raise exception 'publish_home_layout: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_row.org_id, array['publisher', 'editor', 'desk'], 'publish_home_layout');
  if v_row.status not in ('draft', 'scheduled') then
    raise exception 'publish_home_layout: invalid state %', v_row.status using errcode = 'NW004';
  end if;
  if p_at is not null and p_at > now() then
    update news.home_layouts set status = 'scheduled', publish_at = p_at where id = p_layout_id returning * into v_row;
    return v_row;
  end if;
  select coalesce(max(version), 0) + 1 into v_ver from news.home_layouts where org_id = v_row.org_id;
  update news.home_layouts set status = 'archived' where org_id = v_row.org_id and status = 'published';
  update news.home_layouts set status = 'published', version = v_ver, published_by = auth.uid() where id = p_layout_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'home_layout.publish', 'home_layout', p_layout_id::text, null,
                           jsonb_build_object('version', v_ver, 'template', v_row.template));
  return v_row;
end;
$$;

create or replace function news.save_print_edition(p_org uuid, p_id uuid, p_fields jsonb)
returns news.print_editions
language plpgsql
security definer
set search_path = ''
as $$
declare v_old news.print_editions; v_row news.print_editions; r news.print_editions;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'save_print_edition');
  perform news.assert_keys(p_fields, array['edition_date', 'issue_no', 'title', 'pdf_path', 'page_count', 'status'], 'save_print_edition');
  if coalesce((news.plan_feature(p_org, 'news_print_pdf') #>> '{}')::boolean, false) is false and not core.is_service_caller() then
    raise exception 'save_print_edition: plan does not include print PDF' using errcode = 'NW014';
  end if;
  r := jsonb_populate_record(null::news.print_editions, p_fields);
  if p_id is null then
    insert into news.print_editions (org_id, edition_date, issue_no, title, pdf_path, page_count, created_by)
    values (p_org, r.edition_date, r.issue_no, r.title, r.pdf_path, r.page_count, auth.uid()) returning * into v_row;
  else
    select * into v_old from news.print_editions where id = p_id and org_id = p_org for update;
    if not found then
      raise exception 'save_print_edition: not found' using errcode = 'P0002';
    end if;
    if p_fields ? 'status' and r.status is distinct from v_old.status and not (
         (v_old.status = 'draft' and r.status in ('published', 'archived')) or (v_old.status = 'published' and r.status = 'archived')) then
      raise exception 'save_print_edition: invalid status transition % -> %', v_old.status, r.status using errcode = '22023';
    end if;
    update news.print_editions set
      edition_date = case when p_fields ? 'edition_date' then r.edition_date else edition_date end,
      issue_no = case when p_fields ? 'issue_no' then r.issue_no else issue_no end,
      title = case when p_fields ? 'title' then r.title else title end,
      pdf_path = case when p_fields ? 'pdf_path' then r.pdf_path else pdf_path end,
      page_count = case when p_fields ? 'page_count' then r.page_count else page_count end,
      status = case when p_fields ? 'status' then r.status else status end,
      published_at = case when p_fields ? 'status' and r.status = 'published' then now() else published_at end
    where id = p_id returning * into v_row;
  end if;
  return v_row;
end;
$$;

create or replace function news.add_live_update(p_article_id uuid, p_body text, p_is_pinned boolean default false)
returns news.live_updates
language plpgsql
security definer
set search_path = ''
as $$
declare v_a news.articles; v_row news.live_updates;
begin
  select * into v_a from news.articles where id = p_article_id;
  if not found then
    raise exception 'add_live_update: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_a.org_id, array['publisher', 'editor', 'desk', 'reporter'], 'add_live_update');
  if not v_a.is_live or v_a.status = 'archived' then
    raise exception 'add_live_update: article is not a live article' using errcode = 'NW004';
  end if;
  insert into news.live_updates (org_id, article_id, body, is_pinned, posted_by)
  values (v_a.org_id, p_article_id, p_body, coalesce(p_is_pinned, false), auth.uid()) returning * into v_row;
  return v_row;
end;
$$;

create or replace function news.set_live_update_status(p_id uuid, p_status text, p_is_pinned boolean default null)
returns news.live_updates
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.live_updates; v_role text;
begin
  select * into v_row from news.live_updates where id = p_id for update;
  if not found then
    raise exception 'set_live_update_status: not found' using errcode = 'P0002';
  end if;
  v_role := news.assert_staff(v_row.org_id, array['publisher', 'editor', 'desk', 'reporter'], 'set_live_update_status');
  if v_role = 'reporter' and v_row.posted_by is distinct from auth.uid() then
    raise exception 'set_live_update_status: only your own updates' using errcode = '42501';
  end if;
  update news.live_updates set status = coalesce(p_status, status), is_pinned = coalesce(p_is_pinned, is_pinned)
   where id = p_id returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.7 독자(M2): 가입·탈퇴·차단, 멤버십·후원(서버 기록), 페이월, 기사 읽기
-- ---------------------------------------------------------------------
-- 독자 가입(NW-F-006): 그 신문사의 readers 행을 만들거나 갱신한다. 조직 멤버십은 만들지 않는다.
create or replace function news.ensure_reader(
  p_org              uuid,
  p_nickname         text,
  p_terms_version    text,
  p_privacy_version  text,
  p_is_over_14       boolean,
  p_marketing_opt_in boolean default false
)
returns news.readers
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_row news.readers; v_email text;
begin
  if v_uid is null then
    raise exception 'ensure_reader: login required' using errcode = '42501';
  end if;
  if not news.is_public_newspaper(p_org) then
    raise exception 'ensure_reader: newspaper is not public' using errcode = 'NW002';
  end if;
  if not coalesce(p_is_over_14, false) then
    raise exception 'ensure_reader: readers under 14 are not supported' using errcode = 'NW015';
  end if;
  select p.email into v_email from core.profiles p where p.id = v_uid;
  select * into v_row from news.readers where org_id = p_org and user_id = v_uid for update;
  if not found then
    insert into news.readers (org_id, user_id, nickname, email, is_over_14, terms_version, privacy_version, marketing_opt_in, marketing_opt_in_at)
    values (p_org, v_uid, btrim(p_nickname), v_email, true, p_terms_version, p_privacy_version, coalesce(p_marketing_opt_in, false),
            case when coalesce(p_marketing_opt_in, false) then now() end)
    returning * into v_row;
  elsif v_row.status = 'blocked' then
    raise exception 'ensure_reader: reader is blocked' using errcode = 'NW008';
  else
    update news.readers set
      status = 'active',
      nickname = coalesce(nullif(btrim(p_nickname), ''), nickname),
      email = coalesce(email, v_email),
      terms_version = coalesce(p_terms_version, terms_version),
      privacy_version = coalesce(p_privacy_version, privacy_version),
      consent_at = case when p_terms_version is distinct from terms_version or p_privacy_version is distinct from privacy_version then now() else consent_at end,
      marketing_opt_in = coalesce(p_marketing_opt_in, marketing_opt_in),
      last_seen_at = now()
    where id = v_row.id returning * into v_row;
  end if;
  return v_row;
end;
$$;

create or replace function news.withdraw_reader(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.readers;
begin
  select * into v_row from news.readers where org_id = p_org and user_id = auth.uid() and status <> 'withdrawn' for update;
  if not found then
    raise exception 'withdraw_reader: reader not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from news.memberships m where m.reader_id = v_row.id and m.status in ('pending', 'active', 'past_due')) then
    raise exception 'withdraw_reader: cancel the membership first' using errcode = 'NW004';
  end if;
  update news.newsletter_subscriptions set status = 'unsubscribed', unsubscribe_reason = 'reader_withdrawn'
   where reader_id = v_row.id and status in ('pending', 'confirmed');
  update news.readers set status = 'withdrawn' where id = v_row.id;
end;
$$;

create or replace function news.set_reader_status(p_reader_id uuid, p_status text, p_reason text default null)
returns news.readers
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.readers; v_old text;
begin
  select * into v_row from news.readers where id = p_reader_id for update;
  if not found then
    raise exception 'set_reader_status: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_row.org_id, array['publisher', 'editor'], 'set_reader_status');
  if p_status not in ('active', 'blocked') then
    raise exception 'set_reader_status: invalid status %', p_status using errcode = 'NW015';
  end if;
  v_old := v_row.status;
  update news.readers set status = p_status, blocked_reason = case when p_status = 'blocked' then p_reason end
   where id = p_reader_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'reader.status', 'reader', p_reader_id::text,
                           jsonb_build_object('status', v_old), jsonb_build_object('status', p_status));
  return v_row;
end;
$$;

create or replace function news.upsert_membership_tier(p_org uuid, p_id uuid, p_fields jsonb)
returns news.membership_tiers
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.membership_tiers; r news.membership_tiers;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'upsert_membership_tier');
  perform news.assert_keys(p_fields, array['code', 'name', 'description', 'price_krw', 'billing_interval', 'benefits', 'is_active', 'sort_order'], 'upsert_membership_tier');
  r := jsonb_populate_record(null::news.membership_tiers, p_fields);
  if p_id is null then
    insert into news.membership_tiers (org_id, code, name, description, price_krw, billing_interval, benefits, is_active, sort_order)
    values (p_org, r.code, r.name, r.description, r.price_krw, coalesce(r.billing_interval, 'month'), coalesce(r.benefits, '[]'::jsonb),
            coalesce(r.is_active, true), coalesce(r.sort_order, 0))
    returning * into v_row;
  else
    if p_fields ? 'price_krw' or p_fields ? 'billing_interval' or p_fields ? 'code' then
      raise exception 'upsert_membership_tier: price/interval/code are fixed; create a new tier' using errcode = '22023';
    end if;
    update news.membership_tiers set
      name = case when p_fields ? 'name' then r.name else name end,
      description = case when p_fields ? 'description' then r.description else description end,
      benefits = case when p_fields ? 'benefits' then coalesce(r.benefits, '[]'::jsonb) else benefits end,
      is_active = case when p_fields ? 'is_active' then coalesce(r.is_active, true) else is_active end,
      sort_order = case when p_fields ? 'sort_order' then coalesce(r.sort_order, 0) else sort_order end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'upsert_membership_tier: not found' using errcode = 'P0002';
    end if;
  end if;
  perform core.write_audit(p_org, 'membership_tier.save', 'membership_tier', v_row.id::text, null,
                           jsonb_build_object('code', v_row.code, 'price_krw', v_row.price_krw, 'is_active', v_row.is_active));
  return v_row;
end;
$$;

-- 멤버십 기록(service_role: 결제 승인 Route Handler, Toss 웹훅). 결제 금액 검증은 서버가 신문사 가맹 주문 기준으로 한다(04_API).
create or replace function news.record_membership(
  p_org                    uuid,
  p_reader_id              uuid,
  p_tier_id                uuid,
  p_status                 text,
  p_period_start           timestamptz default null,
  p_period_end             timestamptz default null,
  p_external_ref           text default null,
  p_event_id               text default null,
  p_billing_credential_id  uuid default null
)
returns news.memberships
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.memberships; v_fee integer;
begin
  if not core.is_service_caller() then
    raise exception 'record_membership: service_role only' using errcode = '42501';
  end if;
  if p_event_id is not null then
    select * into v_row from news.memberships where org_id = p_org and last_event_id = p_event_id;
    if found then
      return v_row;
    end if;
  end if;
  if p_billing_credential_id is not null and not exists (
       select 1 from core.encrypted_credentials c where c.id = p_billing_credential_id and c.org_id = p_org and c.app_id = 'news') then
    raise exception 'record_membership: credential must belong to the newspaper' using errcode = '23503';
  end if;
  v_fee := coalesce((news.plan_feature(p_org, 'news_reader_fee_bps') #>> '{}')::integer, 0);
  select * into v_row from news.memberships
   where org_id = p_org and reader_id = p_reader_id and status in ('pending', 'active', 'past_due') for update;
  if not found then
    insert into news.memberships (org_id, reader_id, tier_id, status, platform_fee_bps)
    values (p_org, p_reader_id, p_tier_id, 'pending', v_fee) returning * into v_row;
  end if;
  update news.memberships set
    status = coalesce(p_status, status),
    tier_id = coalesce(p_tier_id, tier_id),
    current_period_start = coalesce(p_period_start, current_period_start),
    current_period_end = coalesce(p_period_end, current_period_end),
    external_ref = coalesce(p_external_ref, external_ref),
    billing_credential_id = coalesce(p_billing_credential_id, billing_credential_id),
    platform_fee_bps = case when coalesce(p_status, status) = 'active' and status <> 'active' then v_fee else platform_fee_bps end,
    last_event_id = coalesce(p_event_id, last_event_id)
  where id = v_row.id returning * into v_row;
  perform core.write_audit(p_org, 'membership.record', 'membership', v_row.id::text, null,
                           jsonb_build_object('status', v_row.status, 'tier_id', v_row.tier_id, 'event_id', p_event_id));
  return v_row;
end;
$$;

-- 후원 기록(service_role). order_id 가 멱등 키. 금액은 처음 기록한 값과 같아야 한다.
create or replace function news.record_donation(p_org uuid, p_order_id text, p_status text, p_amount_krw integer, p_fields jsonb default '{}'::jsonb)
returns news.donations
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.donations; v_fee integer; v_reader uuid;
begin
  if not core.is_service_caller() then
    raise exception 'record_donation: service_role only' using errcode = '42501';
  end if;
  perform news.assert_keys(coalesce(p_fields, '{}'::jsonb), array['reader_user_id', 'donor_display_name', 'is_anonymous', 'message', 'kind',
                                                                  'payment_key', 'refunded_amount_krw'], 'record_donation');
  select * into v_row from news.donations where order_id = p_order_id for update;
  if not found then
    if p_fields ? 'reader_user_id' then
      select r.id into v_reader from news.readers r where r.org_id = p_org and r.user_id = (p_fields ->> 'reader_user_id')::uuid;
    end if;
    v_fee := coalesce((news.plan_feature(p_org, 'news_reader_fee_bps') #>> '{}')::integer, 0);
    insert into news.donations (org_id, reader_id, donor_display_name, is_anonymous, message, amount_krw, kind, order_id, platform_fee_bps)
    values (p_org, v_reader, p_fields ->> 'donor_display_name', coalesce((p_fields ->> 'is_anonymous')::boolean, true),
            p_fields ->> 'message', p_amount_krw, coalesce(p_fields ->> 'kind', 'once'), p_order_id, v_fee)
    returning * into v_row;
  elsif v_row.org_id <> p_org or v_row.amount_krw <> p_amount_krw then
    raise exception 'record_donation: order does not match' using errcode = 'NW015';
  end if;
  update news.donations set
    status = coalesce(p_status, status),
    payment_key = coalesce(p_fields ->> 'payment_key', payment_key),
    refunded_amount_krw = coalesce((p_fields ->> 'refunded_amount_krw')::integer, refunded_amount_krw),
    platform_fee_krw = case when coalesce(p_status, status) = 'paid' then (amount_krw::bigint * platform_fee_bps / 10000)::integer else platform_fee_krw end
  where id = v_row.id returning * into v_row;
  return v_row;
end;
$$;

create or replace function news.set_paywall_rule(p_org uuid, p_fields jsonb)
returns news.paywall_rules
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.paywall_rules; r news.paywall_rules;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'set_paywall_rule');
  perform news.assert_keys(p_fields, array['mode', 'free_articles_per_month', 'exempt_types', 'cta_text'], 'set_paywall_rule');
  r := jsonb_populate_record(null::news.paywall_rules, p_fields);
  insert into news.paywall_rules (org_id, mode, free_articles_per_month, exempt_types, cta_text, updated_by)
  values (p_org, coalesce(r.mode, 'off'), coalesce(r.free_articles_per_month, 10), coalesce(r.exempt_types, '{press_release}'), r.cta_text, auth.uid())
  on conflict (org_id) do update set
    mode = case when p_fields ? 'mode' then excluded.mode else news.paywall_rules.mode end,
    free_articles_per_month = case when p_fields ? 'free_articles_per_month' then excluded.free_articles_per_month else news.paywall_rules.free_articles_per_month end,
    exempt_types = case when p_fields ? 'exempt_types' then excluded.exempt_types else news.paywall_rules.exempt_types end,
    cta_text = case when p_fields ? 'cta_text' then excluded.cta_text else news.paywall_rules.cta_text end,
    updated_by = excluded.updated_by
  returning * into v_row;
  perform core.write_audit(p_org, 'paywall.save', 'paywall_rule', v_row.id::text, null, jsonb_build_object('mode', v_row.mode));
  return v_row;
end;
$$;

-- 기사 읽기(공개): 공개 조건을 만족한 기사만. 프리미엄 기사의 본문은 유효 멤버(또는 그 신문사 편집국)에게만 준다.
-- 미터형 페이월(월 N건)은 서버 쿠키 카운트로 보조한다(DB 강제 아님, 05장 7절 한계).
create or replace function news.read_article(p_org uuid, p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_a news.articles; v_reader uuid; v_member boolean := false; v_locked boolean;
begin
  select * into v_a from news.articles where org_id = p_org and slug = p_slug;
  if not found or not news.article_is_live(v_a.org_id, v_a.status, v_a.published_at, v_a.embargo_until, v_a.type, v_a.wire_contract_id) then
    return null;
  end if;
  if v_a.is_premium then
    v_reader := news.current_reader_id(p_org);
    v_member := (v_reader is not null and exists (
                   select 1 from news.memberships m where m.reader_id = v_reader
                     and (m.status in ('active', 'past_due') or (m.status = 'canceled' and m.current_period_end > now()))))
                or news.has_staff_role(p_org, array['publisher', 'editor', 'desk', 'reporter', 'contributor', 'ad_manager']);
  end if;
  v_locked := v_a.is_premium and not v_member;
  return jsonb_build_object(
    'id', v_a.id, 'slug', v_a.slug, 'title', v_a.title, 'subtitle', v_a.subtitle, 'summary', v_a.summary,
    'type', v_a.type, 'byline', v_a.byline, 'section_id', v_a.section_id,
    'sponsor_label', v_a.sponsor_label, 'ai_assisted', v_a.ai_assisted, 'ai_disclosure', v_a.ai_disclosure,
    'source_note', v_a.source_note, 'is_poll', v_a.is_poll, 'poll_disclosure', v_a.poll_disclosure,
    'is_premium', v_a.is_premium, 'locked', v_locked,
    'body', case when v_locked then null else v_a.body end,
    'published_at', v_a.published_at, 'revised_at', v_a.revised_at, 'revision_note', v_a.revision_note,
    'comments_enabled', v_a.comments_enabled and coalesce((select n.comments_enabled from news.newspapers n where n.org_id = p_org), false),
    'hero', (select jsonb_build_object('path', m.storage_path, 'bucket', m.bucket, 'alt', m.alt_text, 'caption', m.caption,
                                       'credit', m.credit, 'ai_generated', m.ai_generated, 'ai_disclosure', m.ai_disclosure)
             from news.media_assets m where m.id = v_a.hero_media_id),
    'wire_attribution', (select w.attribution_text from news.wire_contracts w where w.id = v_a.wire_contract_id),
    'corrections', coalesce((select jsonb_agg(jsonb_build_object('kind', r.kind, 'note', r.note, 'at', r.created_at) order by r.created_at)
                             from news.article_revisions r where r.article_id = v_a.id and r.is_public), '[]'::jsonb),
    'regions', coalesce((select jsonb_agg(jsonb_build_object('slug', g.slug, 'name', g.name))
                         from news.article_regions ar join news.regions g on g.id = ar.region_id where ar.article_id = v_a.id), '[]'::jsonb),
    'tags', coalesce((select jsonb_agg(jsonb_build_object('slug', t.slug, 'name', t.name))
                      from news.article_tags at join news.tags t on t.id = at.tag_id where at.article_id = v_a.id), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------
-- 11.8 광고(M3)
-- ---------------------------------------------------------------------
create or replace function news.upsert_ad_slot(p_org uuid, p_id uuid, p_fields jsonb)
returns news.ad_slots
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.ad_slots; r news.ad_slots;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'ad_manager'], 'upsert_ad_slot');
  perform news.assert_keys(p_fields, array['code', 'name', 'placement', 'width', 'height', 'is_active', 'sort_order'], 'upsert_ad_slot');
  r := jsonb_populate_record(null::news.ad_slots, p_fields);
  if p_id is null then
    insert into news.ad_slots (org_id, code, name, placement, width, height, is_active, sort_order)
    values (p_org, r.code, r.name, r.placement, r.width, r.height, coalesce(r.is_active, true), coalesce(r.sort_order, 0)) returning * into v_row;
  else
    update news.ad_slots set
      code = case when p_fields ? 'code' then r.code else code end, name = case when p_fields ? 'name' then r.name else name end,
      placement = case when p_fields ? 'placement' then r.placement else placement end,
      width = case when p_fields ? 'width' then r.width else width end, height = case when p_fields ? 'height' then r.height else height end,
      is_active = case when p_fields ? 'is_active' then coalesce(r.is_active, true) else is_active end,
      sort_order = case when p_fields ? 'sort_order' then coalesce(r.sort_order, 0) else sort_order end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'upsert_ad_slot: not found' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

create or replace function news.upsert_advertiser(p_org uuid, p_id uuid, p_fields jsonb)
returns news.advertisers
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.advertisers; r news.advertisers;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'ad_manager'], 'upsert_advertiser');
  perform news.assert_keys(p_fields, array['name', 'kind', 'is_government', 'business_no', 'contact_name', 'contact_email', 'contact_phone', 'note', 'status'], 'upsert_advertiser');
  r := jsonb_populate_record(null::news.advertisers, p_fields);
  if p_id is null then
    insert into news.advertisers (org_id, name, kind, is_government, business_no, contact_name, contact_email, contact_phone, note, created_by)
    values (p_org, r.name, coalesce(r.kind, 'local_business'), coalesce(r.is_government, false), r.business_no, r.contact_name,
            r.contact_email, r.contact_phone, r.note, auth.uid()) returning * into v_row;
  else
    update news.advertisers set
      name = case when p_fields ? 'name' then r.name else name end, kind = case when p_fields ? 'kind' then r.kind else kind end,
      is_government = case when p_fields ? 'is_government' then coalesce(r.is_government, false) else is_government end,
      business_no = case when p_fields ? 'business_no' then r.business_no else business_no end,
      contact_name = case when p_fields ? 'contact_name' then r.contact_name else contact_name end,
      contact_email = case when p_fields ? 'contact_email' then r.contact_email else contact_email end,
      contact_phone = case when p_fields ? 'contact_phone' then r.contact_phone else contact_phone end,
      note = case when p_fields ? 'note' then r.note else note end,
      status = case when p_fields ? 'status' then r.status else status end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'upsert_advertiser: not found' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

-- 캠페인 저장. 정부·지자체 광고주는 직판 금액을 잡을 수 없다(정부광고법, NW013).
create or replace function news.save_ad_campaign(p_org uuid, p_id uuid, p_fields jsonb)
returns news.ad_campaigns
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.ad_campaigns; r news.ad_campaigns; v_gov boolean;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'ad_manager'], 'save_ad_campaign');
  perform news.assert_keys(p_fields, array['advertiser_id', 'name', 'pricing', 'price_krw', 'starts_at', 'ends_at', 'priority', 'status'], 'save_ad_campaign');
  r := jsonb_populate_record(null::news.ad_campaigns, p_fields);
  if p_id is null then
    insert into news.ad_campaigns (org_id, advertiser_id, name, pricing, price_krw, starts_at, ends_at, priority, created_by)
    values (p_org, r.advertiser_id, r.name, coalesce(r.pricing, 'flat'), coalesce(r.price_krw, 0), r.starts_at, r.ends_at, coalesce(r.priority, 5), auth.uid())
    returning * into v_row;
    if p_fields ? 'status' and r.status <> 'draft' then
      update news.ad_campaigns set status = r.status where id = v_row.id returning * into v_row;
    end if;
  else
    update news.ad_campaigns set
      advertiser_id = case when p_fields ? 'advertiser_id' then r.advertiser_id else advertiser_id end,
      name = case when p_fields ? 'name' then r.name else name end,
      pricing = case when p_fields ? 'pricing' then r.pricing else pricing end,
      price_krw = case when p_fields ? 'price_krw' then coalesce(r.price_krw, 0) else price_krw end,
      starts_at = case when p_fields ? 'starts_at' then r.starts_at else starts_at end,
      ends_at = case when p_fields ? 'ends_at' then r.ends_at else ends_at end,
      priority = case when p_fields ? 'priority' then coalesce(r.priority, 5) else priority end,
      status = case when p_fields ? 'status' then r.status else status end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'save_ad_campaign: not found' using errcode = 'P0002';
    end if;
  end if;
  select a.is_government into v_gov from news.advertisers a where a.id = v_row.advertiser_id;
  if coalesce(v_gov, false) and v_row.price_krw > 0 then
    raise exception 'save_ad_campaign: government advertising must go through the press foundation' using errcode = 'NW013';
  end if;
  perform core.write_audit(p_org, 'ad_campaign.save', 'ad_campaign', v_row.id::text, null,
                           jsonb_build_object('status', v_row.status, 'price_krw', v_row.price_krw));
  return v_row;
end;
$$;

-- 소재 저장: 내용을 바꾸면 다시 검토 대기(pending_review)
create or replace function news.save_ad_creative(p_org uuid, p_id uuid, p_fields jsonb)
returns news.ad_creatives
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.ad_creatives; r news.ad_creatives;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'ad_manager'], 'save_ad_creative');
  perform news.assert_keys(p_fields, array['campaign_id', 'slot_id', 'kind', 'media_path', 'external_network', 'external_unit_id',
                                           'headline', 'click_url', 'alt_text', 'label'], 'save_ad_creative');
  r := jsonb_populate_record(null::news.ad_creatives, p_fields);
  if p_id is null then
    insert into news.ad_creatives (org_id, campaign_id, slot_id, kind, media_path, external_network, external_unit_id, headline,
                                   click_url, alt_text, label, created_by)
    values (p_org, r.campaign_id, r.slot_id, r.kind, r.media_path, r.external_network, r.external_unit_id, r.headline,
            r.click_url, r.alt_text, coalesce(r.label, '광고'), auth.uid())
    returning * into v_row;
  else
    update news.ad_creatives set
      slot_id = case when p_fields ? 'slot_id' then r.slot_id else slot_id end,
      kind = case when p_fields ? 'kind' then r.kind else kind end,
      media_path = case when p_fields ? 'media_path' then r.media_path else media_path end,
      external_network = case when p_fields ? 'external_network' then r.external_network else external_network end,
      external_unit_id = case when p_fields ? 'external_unit_id' then r.external_unit_id else external_unit_id end,
      headline = case when p_fields ? 'headline' then r.headline else headline end,
      click_url = case when p_fields ? 'click_url' then r.click_url else click_url end,
      alt_text = case when p_fields ? 'alt_text' then r.alt_text else alt_text end,
      label = case when p_fields ? 'label' then r.label else label end,
      status = case when status = 'approved' then 'pending_review' else status end,
      reviewed_by = null, reviewed_at = null
    where id = p_id and org_id = p_org and status <> 'archived' returning * into v_row;
    if not found then
      raise exception 'save_ad_creative: not found' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

create or replace function news.review_ad_creative(p_id uuid, p_decision text)
returns news.ad_creatives
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.ad_creatives;
begin
  select * into v_row from news.ad_creatives where id = p_id for update;
  if not found then
    raise exception 'review_ad_creative: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_row.org_id, array['publisher', 'editor'], 'review_ad_creative');
  if p_decision not in ('approve', 'reject', 'archive') then
    raise exception 'review_ad_creative: invalid decision' using errcode = 'NW015';
  end if;
  update news.ad_creatives set
    status = case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' else 'archived' end,
    reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'ad_creative.' || p_decision, 'ad_creative', p_id::text, null, jsonb_build_object('label', v_row.label));
  return v_row;
end;
$$;

-- 광고 노출(공개). 승인 소재 + 진행 중 캠페인 + 활성 슬롯만, 라벨과 함께. 임의 HTML 은 없다.
create or replace function news.serve_ads(p_org uuid, p_placement text)
returns table (creative_id uuid, slot_code text, width integer, height integer, kind text, media_path text, headline text,
               click_url text, alt_text text, label text, external_network text, external_unit_id text, priority smallint)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, s.code, s.width, s.height, c.kind, c.media_path, c.headline, c.click_url, c.alt_text, c.label,
         c.external_network, c.external_unit_id, k.priority
  from news.ad_creatives c
  join news.ad_campaigns k on k.id = c.campaign_id
  join news.ad_slots s on s.id = c.slot_id
  where c.org_id = p_org and news.is_public_newspaper(p_org)
    and c.status = 'approved' and k.status = 'active' and k.starts_at <= now() and k.ends_at > now()
    and s.is_active and (s.placement = p_placement or s.placement = 'all')
  order by s.sort_order, k.priority desc, c.created_at;
$$;

create or replace function news.record_ad_stats(p_creative_id uuid, p_day date, p_impressions bigint, p_clicks bigint)
returns news.ad_daily_stats
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid; v_row news.ad_daily_stats;
begin
  if not core.is_service_caller() then
    raise exception 'record_ad_stats: service_role only' using errcode = '42501';
  end if;
  if p_impressions not between 0 and 10000000 or p_clicks not between 0 and 10000000 or p_day > (now() at time zone 'Asia/Seoul')::date then
    raise exception 'record_ad_stats: invalid counts' using errcode = 'NW015';
  end if;
  select org_id into v_org from news.ad_creatives where id = p_creative_id;
  if v_org is null then
    raise exception 'record_ad_stats: creative not found' using errcode = 'P0002';
  end if;
  insert into news.ad_daily_stats as s (org_id, creative_id, day, impressions, clicks)
  values (v_org, p_creative_id, p_day, p_impressions, p_clicks)
  on conflict (creative_id, day) do update
    set impressions = s.impressions + excluded.impressions, clicks = s.clicks + excluded.clicks, updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

-- 업소 셀프 광고 신청(독자 로그인) → 검토(ADS) → 결제 확인 후 게재(service_role)
create or replace function news.submit_listing(p_org uuid, p_fields jsonb)
returns news.local_listings
language plpgsql
security definer
set search_path = ''
as $$
declare v_reader uuid; v_ok boolean; v_row news.local_listings; r news.local_listings;
begin
  if auth.uid() is null then
    raise exception 'submit_listing: login required' using errcode = '42501';
  end if;
  v_reader := news.current_reader_id(p_org);
  if v_reader is null then
    raise exception 'submit_listing: reader registration required' using errcode = 'NW008';
  end if;
  perform news.assert_keys(p_fields, array['business_name', 'category', 'region_id', 'address', 'phone', 'url', 'description', 'contact_email'], 'submit_listing');
  select x.allowed into v_ok from core.rate_limit_hit('news:listing:' || v_reader::text, 5, 86400) x;
  if not v_ok then
    raise exception 'submit_listing: rate limited' using errcode = 'NW011';
  end if;
  r := jsonb_populate_record(null::news.local_listings, p_fields);
  insert into news.local_listings (org_id, reader_id, applicant_user_id, business_name, category, region_id, address, phone, url, description, contact_email)
  values (p_org, v_reader, auth.uid(), r.business_name, r.category, r.region_id, r.address, r.phone, r.url, r.description, r.contact_email)
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function news.review_listing(p_id uuid, p_decision text, p_note text default null)
returns news.local_listings
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.local_listings;
begin
  select * into v_row from news.local_listings where id = p_id for update;
  if not found then
    raise exception 'review_listing: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_row.org_id, array['publisher', 'editor', 'ad_manager'], 'review_listing');
  if p_decision not in ('approve', 'reject', 'cancel', 'expire') then
    raise exception 'review_listing: invalid decision' using errcode = 'NW015';
  end if;
  update news.local_listings set
    status = case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' when 'expire' then 'expired' else 'canceled' end,
    reviewed_by = auth.uid(), reviewed_at = now(), review_note = p_note
  where id = p_id returning * into v_row;
  return v_row;
end;
$$;

create or replace function news.activate_listing(p_id uuid, p_starts_at timestamptz, p_ends_at timestamptz, p_payment_order_id text default null)
returns news.local_listings
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.local_listings;
begin
  if not core.is_service_caller() then
    raise exception 'activate_listing: service_role only' using errcode = '42501';
  end if;
  update news.local_listings set status = 'active', starts_at = p_starts_at, ends_at = p_ends_at,
         payment_order_id = p_payment_order_id, paid_at = case when p_payment_order_id is not null then now() end
   where id = p_id returning * into v_row;
  if not found then
    raise exception 'activate_listing: not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

create or replace function news.save_public_notice(p_org uuid, p_id uuid, p_fields jsonb)
returns news.public_notices
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.public_notices; r news.public_notices;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'desk', 'ad_manager'], 'save_public_notice');
  perform news.assert_keys(p_fields, array['issuer_name', 'notice_no', 'title', 'body', 'region_id', 'attachment_path',
                                           'government_ad_ref', 'posted_from', 'posted_until', 'status'], 'save_public_notice');
  r := jsonb_populate_record(null::news.public_notices, p_fields);
  if p_id is null then
    insert into news.public_notices (org_id, issuer_name, notice_no, title, body, region_id, attachment_path, government_ad_ref,
                                     posted_from, posted_until, created_by)
    values (p_org, r.issuer_name, r.notice_no, r.title, r.body, r.region_id, r.attachment_path, r.government_ad_ref,
            r.posted_from, r.posted_until, auth.uid())
    returning * into v_row;
  end if;
  update news.public_notices set
    issuer_name = case when p_fields ? 'issuer_name' then r.issuer_name else issuer_name end,
    notice_no = case when p_fields ? 'notice_no' then r.notice_no else notice_no end,
    title = case when p_fields ? 'title' then r.title else title end,
    body = case when p_fields ? 'body' then r.body else body end,
    region_id = case when p_fields ? 'region_id' then r.region_id else region_id end,
    attachment_path = case when p_fields ? 'attachment_path' then r.attachment_path else attachment_path end,
    government_ad_ref = case when p_fields ? 'government_ad_ref' then r.government_ad_ref else government_ad_ref end,
    posted_from = case when p_fields ? 'posted_from' then r.posted_from else posted_from end,
    posted_until = case when p_fields ? 'posted_until' then r.posted_until else posted_until end,
    status = case when p_fields ? 'status' then r.status else status end
  where id = coalesce(p_id, v_row.id) and org_id = p_org returning * into v_row;
  if not found then
    raise exception 'save_public_notice: not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.9 뉴스레터·푸시(M4)
-- ---------------------------------------------------------------------
create or replace function news.upsert_newsletter_list(p_org uuid, p_id uuid, p_fields jsonb)
returns news.newsletter_lists
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newsletter_lists; r news.newsletter_lists;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'upsert_newsletter_list');
  perform news.assert_keys(p_fields, array['slug', 'name', 'description', 'kind', 'is_public', 'contains_ads', 'consent_version', 'status'], 'upsert_newsletter_list');
  r := jsonb_populate_record(null::news.newsletter_lists, p_fields);
  if p_id is null then
    insert into news.newsletter_lists (org_id, slug, name, description, kind, is_public, contains_ads, consent_version)
    values (p_org, r.slug, r.name, r.description, coalesce(r.kind, 'custom'), coalesce(r.is_public, true), coalesce(r.contains_ads, false),
            coalesce(r.consent_version, 'v1'))
    returning * into v_row;
  else
    update news.newsletter_lists set
      slug = case when p_fields ? 'slug' then r.slug else slug end, name = case when p_fields ? 'name' then r.name else name end,
      description = case when p_fields ? 'description' then r.description else description end,
      kind = case when p_fields ? 'kind' then r.kind else kind end,
      is_public = case when p_fields ? 'is_public' then coalesce(r.is_public, true) else is_public end,
      contains_ads = case when p_fields ? 'contains_ads' then coalesce(r.contains_ads, false) else contains_ads end,
      consent_version = case when p_fields ? 'consent_version' then r.consent_version else consent_version end,
      status = case when p_fields ? 'status' then r.status else status end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'upsert_newsletter_list: not found' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

-- 구독 신청(service_role: 확인 메일을 보내야 하므로 Route Handler 만). 토큰 원문은 반환값으로 한 번만 나가고 DB 에는 해시만 남는다.
-- 응답 문구는 상태와 무관하게 같게 만든다(구독 여부 열거 방지, 04_API).
create or replace function news.subscribe_newsletter(
  p_org             uuid,
  p_list_slug       text,
  p_email           text,
  p_consent_version text,
  p_ad_consent      boolean default false,
  p_night_consent   boolean default false,
  p_reader_user_id  uuid default null,
  p_source_path     text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_list    news.newsletter_lists;
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_hash    text;
  v_ok      boolean;
  v_row     news.newsletter_subscriptions;
  v_confirm text := encode(extensions.gen_random_bytes(32), 'hex');
  v_unsub   text := encode(extensions.gen_random_bytes(32), 'hex');
  v_reader  uuid;
  v_send    boolean := false;
begin
  if not core.is_service_caller() then
    raise exception 'subscribe_newsletter: service_role only' using errcode = '42501';
  end if;
  if not news.is_public_newspaper(p_org) then
    raise exception 'subscribe_newsletter: newspaper is not public' using errcode = 'NW002';
  end if;
  select * into v_list from news.newsletter_lists where org_id = p_org and slug = p_list_slug and status = 'active';
  if not found then
    raise exception 'subscribe_newsletter: list not found' using errcode = 'P0002';
  end if;
  if char_length(v_email) > 254 or v_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'subscribe_newsletter: invalid email' using errcode = 'NW015';
  end if;
  if p_consent_version is distinct from v_list.consent_version then
    raise exception 'subscribe_newsletter: consent missing or outdated' using errcode = 'NW015';
  end if;
  if v_list.contains_ads and not coalesce(p_ad_consent, false) then
    raise exception 'subscribe_newsletter: advertising consent required for this list' using errcode = 'NW015';
  end if;
  v_hash := news.token_hash(v_email);
  select x.allowed into v_ok from core.rate_limit_hit('news:nl:org:' || p_org::text, 300, 3600) x;
  if v_ok then
    select x.allowed into v_ok from core.rate_limit_hit('news:nl:email:' || p_org::text || ':' || v_hash, 3, 3600) x;
  end if;
  if not v_ok then
    raise exception 'subscribe_newsletter: rate limited' using errcode = 'NW011';
  end if;
  if p_reader_user_id is not null then
    select r.id into v_reader from news.readers r where r.org_id = p_org and r.user_id = p_reader_user_id and r.status = 'active';
  end if;
  select * into v_row from news.newsletter_subscriptions where list_id = v_list.id and email_hash = v_hash for update;
  if not found then
    insert into news.newsletter_subscriptions (org_id, list_id, reader_id, email, email_hash, status, confirm_token_hash, confirm_expires_at,
      confirm_sent_count, unsubscribe_token_hash, consent_version, ad_consent, night_consent, source_path)
    values (p_org, v_list.id, v_reader, v_email, v_hash, 'pending', news.token_hash(v_confirm), now() + interval '7 days', 1,
            news.token_hash(v_unsub), p_consent_version, coalesce(p_ad_consent, false), coalesce(p_night_consent, false), p_source_path)
    returning * into v_row;
    v_send := true;
  elsif v_row.status = 'pending' then
    if v_row.confirm_sent_count < 5 then
      update news.newsletter_subscriptions set confirm_token_hash = news.token_hash(v_confirm), confirm_expires_at = now() + interval '7 days',
             confirm_sent_count = confirm_sent_count + 1, unsubscribe_token_hash = news.token_hash(v_unsub),
             consent_version = p_consent_version, consent_at = now(), ad_consent = coalesce(p_ad_consent, false),
             night_consent = coalesce(p_night_consent, false), reader_id = coalesce(v_reader, reader_id)
       where id = v_row.id returning * into v_row;
      v_send := true;
    end if;
  elsif v_row.status in ('unsubscribed', 'bounced') then
    update news.newsletter_subscriptions set status = 'pending', email = v_email, confirm_token_hash = news.token_hash(v_confirm),
           confirm_expires_at = now() + interval '7 days', confirm_sent_count = 1, unsubscribe_token_hash = news.token_hash(v_unsub),
           consent_version = p_consent_version, consent_at = now(), ad_consent = coalesce(p_ad_consent, false),
           night_consent = coalesce(p_night_consent, false), source_path = p_source_path, reader_id = coalesce(v_reader, reader_id)
     where id = v_row.id returning * into v_row;
    v_send := true;
  end if;
  return jsonb_build_object('ok', true, 'subscription_id', v_row.id, 'status', v_row.status, 'send_confirmation', v_send,
                            'confirm_token', case when v_send then v_confirm end, 'unsubscribe_token', case when v_send then v_unsub end);
end;
$$;

-- 확인(이중 동의) 또는 2년 재확인. 토큰은 링크 원문이고 DB 에는 해시만 있다. 앱은 GET 으로 이 함수를 부르지 않는다(POST 버튼).
create or replace function news.confirm_newsletter(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newsletter_subscriptions;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    raise exception 'confirm_newsletter: invalid token' using errcode = 'NW012';
  end if;
  select * into v_row from news.newsletter_subscriptions where confirm_token_hash = news.token_hash(p_token) for update;
  if not found or v_row.confirm_expires_at < now() or v_row.status not in ('pending', 'confirmed') then
    raise exception 'confirm_newsletter: invalid or expired token' using errcode = 'NW012';
  end if;
  if v_row.status = 'pending' then
    update news.newsletter_subscriptions set status = 'confirmed', confirm_token_hash = null, confirm_expires_at = null
     where id = v_row.id returning * into v_row;
  else
    update news.newsletter_subscriptions set reconfirmed_at = now(), confirm_token_hash = null, confirm_expires_at = null
     where id = v_row.id returning * into v_row;
  end if;
  return jsonb_build_object('ok', true, 'status', v_row.status, 'reconfirm_due_at', v_row.reconfirm_due_at);
end;
$$;

create or replace function news.unsubscribe_newsletter(p_token text, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newsletter_subscriptions; v_changed boolean := false;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    raise exception 'unsubscribe_newsletter: invalid token' using errcode = 'NW012';
  end if;
  select * into v_row from news.newsletter_subscriptions where unsubscribe_token_hash = news.token_hash(p_token) for update;
  if not found then
    raise exception 'unsubscribe_newsletter: invalid token' using errcode = 'NW012';
  end if;
  if v_row.status in ('pending', 'confirmed') then
    update news.newsletter_subscriptions set status = 'unsubscribed', unsubscribe_reason = left(p_reason, 200) where id = v_row.id returning * into v_row;
    v_changed := true;
  end if;
  return jsonb_build_object('ok', true, 'status', v_row.status, 'changed', v_changed);
end;
$$;

-- 2년 재확인 메일용 토큰 발급(service_role). 확인된 구독에만. 원문은 반환값으로 한 번만.
create or replace function news.issue_newsletter_reconfirm(p_subscription_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_token text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  if not core.is_service_caller() then
    raise exception 'issue_newsletter_reconfirm: service_role only' using errcode = '42501';
  end if;
  update news.newsletter_subscriptions set confirm_token_hash = news.token_hash(v_token), confirm_expires_at = now() + interval '30 days'
   where id = p_subscription_id and status = 'confirmed';
  if not found then
    raise exception 'issue_newsletter_reconfirm: confirmed subscription not found' using errcode = 'P0002';
  end if;
  return v_token;
end;
$$;

create or replace function news.save_newsletter_issue(p_org uuid, p_id uuid, p_fields jsonb)
returns news.newsletter_issues
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newsletter_issues; r news.newsletter_issues;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'desk'], 'save_newsletter_issue');
  perform news.assert_keys(p_fields, array['list_id', 'subject', 'preheader', 'body', 'article_ids', 'contains_ad', 'status', 'scheduled_at'], 'save_newsletter_issue');
  r := jsonb_populate_record(null::news.newsletter_issues, p_fields);
  if p_fields ? 'status' and r.status not in ('draft', 'scheduled', 'canceled') then
    raise exception 'save_newsletter_issue: status % is set by the sender', r.status using errcode = '42501';
  end if;
  if p_fields ? 'scheduled_at' and r.scheduled_at is not null and r.scheduled_at < now() - interval '1 minute' then
    raise exception 'save_newsletter_issue: scheduled_at is in the past' using errcode = 'NW015';
  end if;
  if p_id is null then
    insert into news.newsletter_issues (org_id, list_id, subject, preheader, body, article_ids, contains_ad, scheduled_at, created_by)
    values (p_org, r.list_id, r.subject, r.preheader, coalesce(r.body, '[]'::jsonb), coalesce(r.article_ids, '{}'), coalesce(r.contains_ad, false),
            r.scheduled_at, auth.uid())
    returning * into v_row;
  end if;
  update news.newsletter_issues set
    subject = case when p_fields ? 'subject' then r.subject else subject end,
    preheader = case when p_fields ? 'preheader' then r.preheader else preheader end,
    body = case when p_fields ? 'body' then coalesce(r.body, '[]'::jsonb) else body end,
    article_ids = case when p_fields ? 'article_ids' then coalesce(r.article_ids, '{}') else article_ids end,
    contains_ad = case when p_fields ? 'contains_ad' then coalesce(r.contains_ad, false) else contains_ad end,
    scheduled_at = case when p_fields ? 'scheduled_at' then r.scheduled_at else scheduled_at end,
    status = case when p_fields ? 'status' then r.status else status end
  where id = coalesce(p_id, v_row.id) and org_id = p_org returning * into v_row;
  if not found then
    raise exception 'save_newsletter_issue: not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

create or replace function news.record_newsletter_issue_status(p_id uuid, p_status text, p_counts jsonb default '{}'::jsonb)
returns news.newsletter_issues
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.newsletter_issues;
begin
  if not core.is_service_caller() then
    raise exception 'record_newsletter_issue_status: service_role only' using errcode = '42501';
  end if;
  update news.newsletter_issues set
    status = coalesce(p_status, status),
    recipients_count = coalesce((p_counts ->> 'recipients')::integer, recipients_count),
    delivered_count = coalesce((p_counts ->> 'delivered')::integer, delivered_count),
    open_count = coalesce((p_counts ->> 'opens')::integer, open_count),
    click_count = coalesce((p_counts ->> 'clicks')::integer, click_count)
  where id = p_id returning * into v_row;
  if not found then
    raise exception 'record_newsletter_issue_status: not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

create or replace function news.register_push_subscription(p_org uuid, p_endpoint text, p_p256dh text, p_auth text,
                                                           p_topics text[] default '{breaking}', p_reader_user_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; v_reader uuid;
begin
  if not core.is_service_caller() then
    raise exception 'register_push_subscription: service_role only' using errcode = '42501';
  end if;
  if p_reader_user_id is not null then
    select r.id into v_reader from news.readers r where r.org_id = p_org and r.user_id = p_reader_user_id and r.status = 'active';
  end if;
  insert into news.push_subscriptions as s (org_id, reader_id, endpoint, endpoint_hash, p256dh, auth_secret, topics)
  values (p_org, v_reader, p_endpoint, news.token_hash(p_endpoint), p_p256dh, p_auth, coalesce(p_topics, '{breaking}'))
  on conflict (org_id, endpoint_hash) do update
    set p256dh = excluded.p256dh, auth_secret = excluded.auth_secret, topics = excluded.topics, status = 'active',
        failure_count = 0, reader_id = coalesce(excluded.reader_id, s.reader_id)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function news.revoke_push_subscription(p_org uuid, p_endpoint text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_service_caller() then
    raise exception 'revoke_push_subscription: service_role only' using errcode = '42501';
  end if;
  update news.push_subscriptions set status = 'revoked' where org_id = p_org and endpoint_hash = news.token_hash(p_endpoint);
  return found;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.10 커뮤니티(M5): 댓글·신고·임시조치, 제보·투고, 경조사
-- ---------------------------------------------------------------------
create or replace function news.post_comment(p_article_id uuid, p_body text, p_parent_id uuid default null)
returns news.comments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_a      news.articles;
  v_np     news.newspapers;
  v_reader news.readers;
  v_ok     boolean;
  v_row    news.comments;
  v_body   text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then
    raise exception 'post_comment: login required' using errcode = '42501';
  end if;
  select * into v_a from news.articles where id = p_article_id;
  if not found or not news.article_is_live(v_a.org_id, v_a.status, v_a.published_at, v_a.embargo_until, v_a.type, v_a.wire_contract_id) then
    raise exception 'post_comment: article not found' using errcode = 'P0002';
  end if;
  select * into v_reader from news.readers where org_id = v_a.org_id and user_id = auth.uid();
  if not found or v_reader.status <> 'active' then
    raise exception 'post_comment: active reader registration required' using errcode = 'NW008';
  end if;
  select * into v_np from news.newspapers where org_id = v_a.org_id;
  if not v_np.comments_enabled or not v_a.comments_enabled then
    raise exception 'post_comment: comments are off' using errcode = 'NW009';
  end if;
  if exists (select 1 from news.election_periods e where e.org_id = v_a.org_id and e.status = 'active' and e.comment_policy = 'disabled'
             and now() >= e.poll_blackout_from and now() < e.poll_blackout_until) then
    raise exception 'post_comment: comments are off during the election period' using errcode = 'NW009';
  end if;
  if char_length(v_body) not between 1 and 1000 then
    raise exception 'post_comment: invalid body' using errcode = 'NW015';
  end if;
  -- 한글은 \b 경계가 없으므로 부분 문자열로 비교한다(SECURITY_BASELINE 14장)
  if exists (select 1 from unnest(v_np.banned_words) w where btrim(w) <> '' and position(lower(btrim(w)) in lower(v_body)) > 0) then
    raise exception 'post_comment: contains a banned word' using errcode = 'NW010';
  end if;
  select x.allowed into v_ok from core.rate_limit_hit('news:cmt:min:' || v_reader.id::text, 5, 60) x;
  if v_ok then
    select x.allowed into v_ok from core.rate_limit_hit('news:cmt:day:' || v_reader.id::text, 100, 86400) x;
  end if;
  if not v_ok then
    raise exception 'post_comment: rate limited' using errcode = 'NW011';
  end if;
  if p_parent_id is not null and not exists (select 1 from news.comments c where c.id = p_parent_id and c.article_id = p_article_id and c.status = 'visible') then
    raise exception 'post_comment: parent comment not found' using errcode = 'P0002';
  end if;
  insert into news.comments (org_id, article_id, reader_id, parent_id, body)
  values (v_a.org_id, p_article_id, v_reader.id, p_parent_id, v_body) returning * into v_row;
  update news.readers set last_seen_at = now() where id = v_reader.id;
  return v_row;
end;
$$;

create or replace function news.delete_my_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_c news.comments;
begin
  select * into v_c from news.comments where id = p_comment_id for update;
  if not found or v_c.reader_id is distinct from news.current_reader_id(v_c.org_id) then
    raise exception 'delete_my_comment: not found' using errcode = 'P0002';
  end if;
  if v_c.status <> 'deleted' then
    update news.comments set status = 'deleted', status_reason = 'author' where id = p_comment_id;
  end if;
end;
$$;

-- 신고. 권리침해 주장(정보통신망법 제44조의2)은 즉시 임시조치(30일). 일반 신고 5건 누적이면 숨김(제안 수치).
create or replace function news.report_comment(p_comment_id uuid, p_reason text, p_detail text default null, p_rights_claim boolean default false)
returns news.comment_reports
language plpgsql
security definer
set search_path = ''
as $$
declare v_c news.comments; v_reader uuid; v_ok boolean; v_row news.comment_reports;
begin
  if auth.uid() is null then
    raise exception 'report_comment: login required' using errcode = '42501';
  end if;
  select * into v_c from news.comments where id = p_comment_id for update;
  if not found or v_c.status not in ('visible', 'temp_blocked') then
    raise exception 'report_comment: comment not found' using errcode = 'P0002';
  end if;
  v_reader := news.current_reader_id(v_c.org_id);
  if v_reader is null then
    raise exception 'report_comment: reader registration required' using errcode = 'NW008';
  end if;
  if v_reader = v_c.reader_id then
    raise exception 'report_comment: cannot report your own comment' using errcode = 'NW015';
  end if;
  select x.allowed into v_ok from core.rate_limit_hit('news:report:' || v_reader::text, 20, 86400) x;
  if not v_ok then
    raise exception 'report_comment: rate limited' using errcode = 'NW011';
  end if;
  insert into news.comment_reports (org_id, comment_id, reporter_reader_id, reason, detail, is_rights_claim)
  values (v_c.org_id, p_comment_id, v_reader, p_reason, p_detail, coalesce(p_rights_claim, false)) returning * into v_row;
  update news.comments set report_count = report_count + 1 where id = p_comment_id returning * into v_c;
  if coalesce(p_rights_claim, false) and v_c.status = 'visible' then
    update news.comments set status = 'temp_blocked', temp_blocked_until = now() + interval '30 days', status_reason = 'rights_claim'
     where id = p_comment_id;
  elsif v_c.status = 'visible' and v_c.report_count >= 5 then
    update news.comments set status = 'hidden', status_reason = 'reports_threshold' where id = p_comment_id;
  end if;
  return v_row;
end;
$$;

create or replace function news.moderate_comment(p_comment_id uuid, p_action text, p_reason text default null)
returns news.comments
language plpgsql
security definer
set search_path = ''
as $$
declare v_c news.comments; v_old text;
begin
  select * into v_c from news.comments where id = p_comment_id for update;
  if not found then
    raise exception 'moderate_comment: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_c.org_id, array['publisher', 'editor', 'desk'], 'moderate_comment');
  if p_action not in ('show', 'hide', 'temp_block', 'delete') then
    raise exception 'moderate_comment: invalid action' using errcode = 'NW015';
  end if;
  v_old := v_c.status;
  update news.comments set
    status = case p_action when 'show' then 'visible' when 'hide' then 'hidden' when 'temp_block' then 'temp_blocked' else 'deleted' end,
    temp_blocked_until = case when p_action = 'temp_block' then now() + interval '30 days' end,
    status_reason = left(p_reason, 200), moderated_by = auth.uid(), moderated_at = now()
  where id = p_comment_id returning * into v_c;
  update news.comment_reports set status = case when p_action = 'show' then 'dismissed' else 'actioned' end,
         handled_by = auth.uid(), handled_at = now()
   where comment_id = p_comment_id and status = 'open';
  perform core.write_audit(v_c.org_id, 'comment.' || p_action, 'comment', p_comment_id::text,
                           jsonb_build_object('status', v_old), jsonb_build_object('status', v_c.status, 'reason', p_reason));
  return v_c;
end;
$$;

-- 공개 댓글 목록: 닉네임·본문·시각만(작성자 id·이메일 없음). 탈퇴 독자는 '탈퇴한 독자'.
create or replace function news.list_comments(p_article_id uuid, p_limit integer default 50, p_before timestamptz default null)
returns table (id uuid, parent_id uuid, nickname text, body text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.parent_id, case when r.status = 'withdrawn' then '탈퇴한 독자' else r.nickname end, c.body, c.created_at
  from news.comments c join news.readers r on r.id = c.reader_id
  where c.article_id = p_article_id and c.status = 'visible' and news.is_article_live(p_article_id)
    and (p_before is null or c.created_at < p_before)
  order by c.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

-- 제보·투고 접수(service_role 경유: CAPTCHA·IP 제한·첨부 업로드를 Route Handler 가 먼저 한다)
create or replace function news.submit_tip(p_org uuid, p_fields jsonb, p_reader_user_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_ok boolean; v_reader uuid; v_row news.tips; r news.tips;
begin
  if not core.is_service_caller() then
    raise exception 'submit_tip: service_role only' using errcode = '42501';
  end if;
  if not news.is_public_newspaper(p_org) then
    raise exception 'submit_tip: newspaper is not public' using errcode = 'NW002';
  end if;
  perform news.assert_keys(p_fields, array['kind', 'title', 'body', 'contact_name', 'contact_email', 'contact_phone', 'wants_anonymity',
                                           'attachment_paths', 'consent_version'], 'submit_tip');
  select x.allowed into v_ok from core.rate_limit_hit('news:tip:' || p_org::text, 100, 3600) x;
  if not v_ok then
    raise exception 'submit_tip: rate limited' using errcode = 'NW011';
  end if;
  if p_reader_user_id is not null then
    select x.id into v_reader from news.readers x where x.org_id = p_org and x.user_id = p_reader_user_id and x.status = 'active';
  end if;
  r := jsonb_populate_record(null::news.tips, p_fields);
  insert into news.tips (org_id, kind, reader_id, title, body, contact_name, contact_email, contact_phone, wants_anonymity, attachment_paths, consent_version)
  values (p_org, coalesce(r.kind, 'tip'), v_reader, r.title, r.body, r.contact_name, r.contact_email, r.contact_phone,
          coalesce(r.wants_anonymity, true), coalesce(r.attachment_paths, '{}'), r.consent_version)
  returning * into v_row;
  return jsonb_build_object('ok', true, 'id', v_row.id, 'reference', upper(left(replace(v_row.id::text, '-', ''), 8)));
end;
$$;

create or replace function news.set_tip_status(p_id uuid, p_status text, p_assigned_to uuid default null, p_note text default null)
returns news.tips
language plpgsql
security definer
set search_path = ''
as $$
declare v_t news.tips; v_role text;
begin
  select * into v_t from news.tips where id = p_id for update;
  if not found then
    raise exception 'set_tip_status: not found' using errcode = 'P0002';
  end if;
  v_role := news.assert_staff(v_t.org_id, array['publisher', 'editor', 'desk', 'reporter'], 'set_tip_status');
  if v_role = 'reporter' and (v_t.assigned_to is distinct from auth.uid() or p_status not in ('reviewing', 'used') or p_assigned_to is not null) then
    raise exception 'set_tip_status: reporters update their assigned tips only' using errcode = '42501';
  end if;
  if p_assigned_to is not null and not exists (select 1 from news.staff s where s.org_id = v_t.org_id and s.user_id = p_assigned_to
                                                 and s.status = 'active' and s.role in ('publisher', 'editor', 'desk', 'reporter')) then
    raise exception 'set_tip_status: assignee must be editorial staff' using errcode = 'NW015';
  end if;
  update news.tips set status = coalesce(p_status, status), assigned_to = coalesce(p_assigned_to, assigned_to),
         staff_note = coalesce(p_note, staff_note)
   where id = p_id returning * into v_t;
  perform core.write_audit(v_t.org_id, 'tip.status', 'tip', p_id::text, null, jsonb_build_object('status', v_t.status, 'assigned_to', v_t.assigned_to));
  return v_t;
end;
$$;

create or replace function news.submit_life_event(p_org uuid, p_fields jsonb)
returns news.life_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_reader uuid; v_ok boolean; v_row news.life_events; r news.life_events;
begin
  if auth.uid() is null then
    raise exception 'submit_life_event: login required' using errcode = '42501';
  end if;
  v_reader := news.current_reader_id(p_org);
  if v_reader is null then
    raise exception 'submit_life_event: reader registration required' using errcode = 'NW008';
  end if;
  perform news.assert_keys(p_fields, array['kind', 'title', 'body', 'event_at', 'applicant_name', 'applicant_phone', 'consent_version'], 'submit_life_event');
  select x.allowed into v_ok from core.rate_limit_hit('news:life:' || v_reader::text, 5, 86400) x;
  if not v_ok then
    raise exception 'submit_life_event: rate limited' using errcode = 'NW011';
  end if;
  r := jsonb_populate_record(null::news.life_events, p_fields);
  insert into news.life_events (org_id, kind, title, body, event_at, applicant_reader_id, applicant_name, applicant_phone, consent_version)
  values (p_org, r.kind, r.title, r.body, r.event_at, v_reader, r.applicant_name, r.applicant_phone, r.consent_version)
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function news.review_life_event(p_id uuid, p_decision text, p_note text default null)
returns news.life_events
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.life_events;
begin
  select * into v_row from news.life_events where id = p_id for update;
  if not found then
    raise exception 'review_life_event: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_row.org_id, array['publisher', 'editor', 'desk'], 'review_life_event');
  if p_decision not in ('approve', 'reject', 'archive') then
    raise exception 'review_life_event: invalid decision' using errcode = 'NW015';
  end if;
  update news.life_events set
    status = case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' else 'archived' end,
    reviewed_by = auth.uid(), reviewed_at = now(), review_note = p_note
  where id = p_id returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.11 배포·SEO(M6)
-- ---------------------------------------------------------------------
create or replace function news.upsert_wire_contract(p_org uuid, p_id uuid, p_fields jsonb)
returns news.wire_contracts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.wire_contracts; r news.wire_contracts;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'upsert_wire_contract');
  perform news.assert_keys(p_fields, array['provider', 'name', 'contract_no', 'starts_on', 'ends_on', 'attribution_text', 'allow_full_text', 'status', 'note'], 'upsert_wire_contract');
  r := jsonb_populate_record(null::news.wire_contracts, p_fields);
  if p_id is null then
    insert into news.wire_contracts (org_id, provider, name, contract_no, starts_on, ends_on, attribution_text, allow_full_text, note, created_by)
    values (p_org, r.provider, r.name, r.contract_no, r.starts_on, r.ends_on, r.attribution_text, coalesce(r.allow_full_text, true), r.note, auth.uid())
    returning * into v_row;
  else
    update news.wire_contracts set
      provider = case when p_fields ? 'provider' then r.provider else provider end,
      name = case when p_fields ? 'name' then r.name else name end,
      contract_no = case when p_fields ? 'contract_no' then r.contract_no else contract_no end,
      starts_on = case when p_fields ? 'starts_on' then r.starts_on else starts_on end,
      ends_on = case when p_fields ? 'ends_on' then r.ends_on else ends_on end,
      attribution_text = case when p_fields ? 'attribution_text' then r.attribution_text else attribution_text end,
      allow_full_text = case when p_fields ? 'allow_full_text' then coalesce(r.allow_full_text, true) else allow_full_text end,
      status = case when p_fields ? 'status' then r.status else status end,
      note = case when p_fields ? 'note' then r.note else note end
    where id = p_id and org_id = p_org returning * into v_row;
    if not found then
      raise exception 'upsert_wire_contract: not found' using errcode = 'P0002';
    end if;
  end if;
  perform core.write_audit(p_org, 'wire_contract.save', 'wire_contract', v_row.id::text, null,
                           jsonb_build_object('provider', v_row.provider, 'ends_on', v_row.ends_on, 'status', v_row.status));
  return v_row;
end;
$$;

create or replace function news.set_syndication_settings(p_org uuid, p_fields jsonb)
returns news.syndication_settings
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.syndication_settings; r news.syndication_settings;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor'], 'set_syndication_settings');
  perform news.assert_keys(p_fields, array['rss_enabled', 'news_sitemap_enabled', 'google_news', 'naver_partnership', 'daum_partnership',
                                           'ai_crawler_policy', 'llms_txt_enabled', 'robots_extra', 'sns_autoshare'], 'set_syndication_settings');
  r := jsonb_populate_record(null::news.syndication_settings, p_fields);
  insert into news.syndication_settings (org_id) values (p_org) on conflict (org_id) do nothing;
  update news.syndication_settings set
    rss_enabled = case when p_fields ? 'rss_enabled' then coalesce(r.rss_enabled, true) else rss_enabled end,
    news_sitemap_enabled = case when p_fields ? 'news_sitemap_enabled' then coalesce(r.news_sitemap_enabled, true) else news_sitemap_enabled end,
    google_news = case when p_fields ? 'google_news' then coalesce(r.google_news, false) else google_news end,
    naver_partnership = case when p_fields ? 'naver_partnership' then r.naver_partnership else naver_partnership end,
    daum_partnership = case when p_fields ? 'daum_partnership' then r.daum_partnership else daum_partnership end,
    ai_crawler_policy = case when p_fields ? 'ai_crawler_policy' then r.ai_crawler_policy else ai_crawler_policy end,
    llms_txt_enabled = case when p_fields ? 'llms_txt_enabled' then coalesce(r.llms_txt_enabled, false) else llms_txt_enabled end,
    robots_extra = case when p_fields ? 'robots_extra' then r.robots_extra else robots_extra end,
    sns_autoshare = case when p_fields ? 'sns_autoshare' then coalesce(r.sns_autoshare, '{}'::jsonb) else sns_autoshare end,
    updated_by = auth.uid()
  where org_id = p_org returning * into v_row;
  perform core.write_audit(p_org, 'syndication.save', 'syndication_settings', v_row.id::text, null,
                           jsonb_build_object('ai_crawler_policy', v_row.ai_crawler_policy, 'rss', v_row.rss_enabled));
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.12 법정 준수(M7): 정정 청구, 주간 자체기사 지표, 선거 기간
-- ---------------------------------------------------------------------
-- 정정·반론·추후보도 청구 접수. 웹 폼은 service_role(Route Handler), 우편·전화 접수는 데스크 이상이 직접 기록한다.
-- received_at 은 서버·편집국만 과거(90일 이내)로 지정할 수 있고, 기한(notify_due_at)은 트리거가 계산한다.
create or replace function news.submit_correction_request(p_org uuid, p_fields jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_role text; v_ok boolean; v_reader uuid; v_row news.correction_requests; r news.correction_requests; v_received timestamptz;
begin
  v_role := news.assert_staff(p_org, array['publisher', 'editor', 'desk'], 'submit_correction_request');
  perform news.assert_keys(p_fields, array['article_id', 'article_url', 'kind', 'requester_name', 'requester_email', 'requester_phone',
                                           'requester_user_id', 'claim_text', 'requested_text', 'attachment_paths', 'channel', 'received_at'],
                           'submit_correction_request');
  if v_role = 'service' then
    select x.allowed into v_ok from core.rate_limit_hit('news:corr:' || p_org::text, 50, 3600) x;
    if not v_ok then
      raise exception 'submit_correction_request: rate limited' using errcode = 'NW011';
    end if;
  end if;
  r := jsonb_populate_record(null::news.correction_requests, p_fields);
  v_received := coalesce(r.received_at, now());
  if v_received > now() + interval '1 minute' or v_received < now() - interval '90 days' then
    raise exception 'submit_correction_request: received_at out of range' using errcode = 'NW015';
  end if;
  if p_fields ? 'requester_user_id' then
    select x.id into v_reader from news.readers x where x.org_id = p_org and x.user_id = (p_fields ->> 'requester_user_id')::uuid;
  end if;
  insert into news.correction_requests (org_id, article_id, article_url, kind, requester_name, requester_email, requester_phone,
    requester_reader_id, claim_text, requested_text, attachment_paths, channel, received_at, notify_due_at, created_by)
  values (p_org, r.article_id, r.article_url, r.kind, r.requester_name, lower(r.requester_email), r.requester_phone, v_reader,
          r.claim_text, r.requested_text, coalesce(r.attachment_paths, '{}'), coalesce(r.channel, 'web'), v_received, v_received, auth.uid())
  returning * into v_row;
  perform core.write_audit(p_org, 'correction_request.receive', 'correction_request', v_row.id::text, null,
                           jsonb_build_object('kind', v_row.kind, 'channel', v_row.channel, 'notify_due_at', v_row.notify_due_at));
  return jsonb_build_object('ok', true, 'id', v_row.id, 'reference', upper(left(replace(v_row.id::text, '-', ''), 8)),
                            'received_at', v_row.received_at, 'notify_due_at', v_row.notify_due_at);
end;
$$;

-- 청구 처리: reviewing / accept(7일 게재 기한 시작) / reject(사유 필수) / withdrawn. 발행인·편집인만.
create or replace function news.respond_correction_request(p_id uuid, p_decision text, p_note text default null)
returns news.correction_requests
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.correction_requests; v_old text;
begin
  select * into v_row from news.correction_requests where id = p_id for update;
  if not found then
    raise exception 'respond_correction_request: not found' using errcode = 'P0002';
  end if;
  perform news.assert_staff(v_row.org_id, array['publisher', 'editor'], 'respond_correction_request');
  if p_decision not in ('reviewing', 'accept', 'reject', 'withdrawn') then
    raise exception 'respond_correction_request: invalid decision' using errcode = 'NW015';
  end if;
  if p_decision = 'reject' and coalesce(btrim(p_note), '') = '' then
    raise exception 'respond_correction_request: rejection reason required' using errcode = 'NW015';
  end if;
  if v_row.status not in ('received', 'reviewing') and p_decision <> 'withdrawn' then
    raise exception 'respond_correction_request: invalid state %', v_row.status using errcode = 'NW004';
  end if;
  v_old := v_row.status;
  update news.correction_requests set
    status = case p_decision when 'accept' then 'accepted' when 'reject' then 'rejected' else p_decision end,
    decided_by = case when p_decision in ('accept', 'reject') then auth.uid() else decided_by end,
    decision_note = coalesce(p_note, decision_note)
  where id = p_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'correction_request.' || p_decision, 'correction_request', p_id::text,
                           jsonb_build_object('status', v_old),
                           jsonb_build_object('status', v_row.status, 'notified_at', v_row.notified_at, 'publish_due_at', v_row.publish_due_at));
  return v_row;
end;
$$;

-- 주간 자체기사 지표(NW-F-041, 신문법 시행령 제2조: 주간 게재 기사 30% 이상 자체 생산, 주간 신규 게재).
--   기간: p_week_start(월요일, KST) 00:00 부터 7일. 그 주에 처음 게시된(first_published_at) 기사.
--   분모 = original + wire + press_release + contribution (sponsored 는 광고라 제외, 제안)
--   자체기사 = type original 이고 origin 이 ai_press_release 가 아닌 것. 보도자료와 보도자료 AI 초안은 자체기사가 아니다(D-9).
--   flags: no_new_articles(주간 0건), original_ratio_below_30, press_release_ratio_high(보도자료 50% 초과, 포털 감점 경고, 제안)
create or replace function news.compliance_weekly_stats(p_org uuid, p_week_start date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from timestamptz;
  v_to   timestamptz;
  v_total integer; v_original integer; v_press integer; v_ai_press integer; v_wire integer; v_contrib integer; v_sponsored integer;
  v_ratio numeric;
  v_flags text[] := '{}';
begin
  if not (core.is_service_caller() or core.is_platform_admin()) then
    perform news.assert_staff(p_org, array['publisher', 'editor', 'desk'], 'compliance_weekly_stats');
  end if;
  if p_week_start is null or extract(isodow from p_week_start) <> 1 then
    raise exception 'compliance_weekly_stats: week_start must be a Monday' using errcode = 'NW015';
  end if;
  v_from := (p_week_start::timestamp at time zone 'Asia/Seoul');
  v_to := v_from + interval '7 days';
  select count(*) filter (where a.type <> 'sponsored'),
         count(*) filter (where a.type = 'original' and a.origin <> 'ai_press_release'),
         count(*) filter (where a.type = 'press_release'),
         count(*) filter (where a.origin = 'ai_press_release'),
         count(*) filter (where a.type = 'wire'),
         count(*) filter (where a.type = 'contribution'),
         count(*) filter (where a.type = 'sponsored')
    into v_total, v_original, v_press, v_ai_press, v_wire, v_contrib, v_sponsored
  from news.articles a
  where a.org_id = p_org and a.first_published_at >= v_from and a.first_published_at < v_to;
  v_ratio := case when v_total > 0 then round(v_original::numeric / v_total, 4) end;
  if v_total = 0 then
    v_flags := array_append(v_flags, 'no_new_articles');
  else
    if v_ratio < 0.30 then v_flags := array_append(v_flags, 'original_ratio_below_30'); end if;
    if v_press::numeric / v_total > 0.50 then v_flags := array_append(v_flags, 'press_release_ratio_high'); end if;
  end if;
  return jsonb_build_object(
    'org_id', p_org, 'week_start', p_week_start, 'from', v_from, 'to', v_to,
    'total_published', v_total, 'original_count', v_original, 'press_release_count', v_press,
    'ai_press_release_count', v_ai_press, 'wire_count', v_wire, 'contribution_count', v_contrib, 'sponsored_count', v_sponsored,
    'original_ratio', v_ratio, 'flags', to_jsonb(v_flags));
end;
$$;

create or replace function news.upsert_election_period(p_org uuid, p_id uuid, p_fields jsonb)
returns news.election_periods
language plpgsql
security definer
set search_path = ''
as $$
declare v_role text; v_row news.election_periods; r news.election_periods;
begin
  v_role := news.assert_staff(p_org, array['publisher', 'editor'], 'upsert_election_period');
  perform news.assert_keys(p_fields, array['name', 'election_day', 'poll_blackout_from', 'poll_blackout_until', 'comment_policy', 'status'], 'upsert_election_period');
  r := jsonb_populate_record(null::news.election_periods, p_fields);
  if p_id is null then
    insert into news.election_periods (org_id, name, election_day, poll_blackout_from, poll_blackout_until, comment_policy, source, created_by)
    values (p_org, r.name, r.election_day, r.poll_blackout_from, r.poll_blackout_until, coalesce(r.comment_policy, 'normal'),
            case when v_role = 'service' then 'platform' else 'newsroom' end, auth.uid())
    returning * into v_row;
  else
    update news.election_periods set
      name = case when p_fields ? 'name' then r.name else name end,
      election_day = case when p_fields ? 'election_day' then r.election_day else election_day end,
      poll_blackout_from = case when p_fields ? 'poll_blackout_from' then r.poll_blackout_from else poll_blackout_from end,
      poll_blackout_until = case when p_fields ? 'poll_blackout_until' then r.poll_blackout_until else poll_blackout_until end,
      comment_policy = case when p_fields ? 'comment_policy' then r.comment_policy else comment_policy end,
      status = case when p_fields ? 'status' then r.status else status end
    where id = p_id and org_id = p_org and (source = 'newsroom' or v_role = 'service') returning * into v_row;
    if not found then
      raise exception 'upsert_election_period: not found or platform-managed' using errcode = 'P0002';
    end if;
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 11.13 검색·분석(M8)
-- ---------------------------------------------------------------------
-- 조회수 증분(service_role 전용). 봇 필터·레이트 리밋은 /api/r/view 가 먼저 한다. 공개 기사만, 1회 최대 1,000, 48시간 안의 시각만.
create or replace function news.increment_article_views(p_article_id uuid, p_count integer default 1, p_at timestamptz default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid; v_at timestamptz := coalesce(p_at, now());
begin
  if not core.is_service_caller() then
    raise exception 'increment_article_views: service_role only' using errcode = '42501';
  end if;
  if p_count is null or p_count not between 1 and 1000 or v_at > now() + interval '5 minutes' or v_at < now() - interval '48 hours' then
    raise exception 'increment_article_views: invalid count or time' using errcode = 'NW015';
  end if;
  select a.org_id into v_org from news.articles a where a.id = p_article_id;
  if v_org is null or not news.is_article_live(p_article_id) then
    return false;
  end if;
  insert into news.article_view_hourly as v (org_id, article_id, bucket_start, views)
  values (v_org, p_article_id, date_trunc('hour', v_at, 'UTC'), p_count)
  on conflict (article_id, bucket_start) do update set views = v.views + excluded.views, updated_at = now();
  return true;
end;
$$;

-- 많이 본 뉴스(공개). 창: 1h(현재 시 + 직전 1시간 버킷) | 24h. 공개 기사만.
create or replace function news.most_read(p_org uuid, p_window text default '24h', p_limit integer default 10)
returns table (article_id uuid, slug text, title text, views bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.slug, a.title, sum(v.views)::bigint
  from news.article_view_hourly v
  join news.articles a on a.id = v.article_id
  where v.org_id = p_org
    and p_window in ('1h', '24h')
    and v.bucket_start >= date_trunc('hour', now() - case when p_window = '1h' then interval '1 hour' else interval '24 hours' end, 'UTC')
    and news.article_is_live(a.org_id, a.status, a.published_at, a.embargo_until, a.type, a.wire_contract_id)
  group by a.id, a.slug, a.title
  order by sum(v.views) desc, max(a.published_at) desc
  limit least(greatest(coalesce(p_limit, 10), 1), 50);
$$;

-- 기사 검색(공개). tsvector('simple') 일치 또는 제목 부분 일치(pg_trgm GIN 이 ILIKE 를 받친다). 공개 기사만, 본문은 돌려주지 않는다.
create or replace function news.search_articles(p_org uuid, p_query text, p_limit integer default 20, p_offset integer default 0)
returns table (article_id uuid, slug text, title text, summary text, published_at timestamptz, rank real)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_q text := btrim(coalesce(p_query, '')); v_like text;
begin
  if char_length(v_q) not between 1 and 100 then
    raise exception 'search_articles: query length must be 1..100' using errcode = 'NW015';
  end if;
  if not news.is_public_newspaper(p_org) then
    return;
  end if;
  v_like := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return query
    select a.id, a.slug, a.title, a.summary, a.published_at,
           (ts_rank(a.search_tsv, plainto_tsquery('simple'::regconfig, v_q)) + case when a.title ilike v_like then 1 else 0 end)::real
    from news.articles a
    where a.org_id = p_org and a.status = 'published'
      and (a.search_tsv @@ plainto_tsquery('simple'::regconfig, v_q) or a.title ilike v_like)
      and news.article_is_live(a.org_id, a.status, a.published_at, a.embargo_until, a.type, a.wire_contract_id)
    order by 6 desc, a.published_at desc
    limit least(greatest(coalesce(p_limit, 20), 1), 50) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- ---------------------------------------------------------------------
-- 11.14 행사(local-life)
-- ---------------------------------------------------------------------
create or replace function news.save_event(p_org uuid, p_id uuid, p_fields jsonb)
returns news.events
language plpgsql
security definer
set search_path = ''
as $$
declare v_row news.events; r news.events;
begin
  perform news.assert_staff(p_org, array['publisher', 'editor', 'desk', 'reporter'], 'save_event');
  perform news.assert_keys(p_fields, array['title', 'description', 'venue', 'address', 'region_id', 'starts_at', 'ends_at', 'is_all_day',
                                           'url', 'image_path', 'organizer', 'price_text', 'status'], 'save_event');
  r := jsonb_populate_record(null::news.events, p_fields);
  if p_id is null then
    insert into news.events (org_id, title, description, venue, address, region_id, starts_at, ends_at, is_all_day, url, image_path,
                             organizer, price_text, created_by)
    values (p_org, r.title, r.description, r.venue, r.address, r.region_id, r.starts_at, r.ends_at, coalesce(r.is_all_day, false), r.url,
            r.image_path, r.organizer, r.price_text, auth.uid())
    returning * into v_row;
  end if;
  update news.events set
    title = case when p_fields ? 'title' then r.title else title end,
    description = case when p_fields ? 'description' then r.description else description end,
    venue = case when p_fields ? 'venue' then r.venue else venue end,
    address = case when p_fields ? 'address' then r.address else address end,
    region_id = case when p_fields ? 'region_id' then r.region_id else region_id end,
    starts_at = case when p_fields ? 'starts_at' then r.starts_at else starts_at end,
    ends_at = case when p_fields ? 'ends_at' then r.ends_at else ends_at end,
    is_all_day = case when p_fields ? 'is_all_day' then coalesce(r.is_all_day, false) else is_all_day end,
    url = case when p_fields ? 'url' then r.url else url end,
    image_path = case when p_fields ? 'image_path' then r.image_path else image_path end,
    organizer = case when p_fields ? 'organizer' then r.organizer else organizer end,
    price_text = case when p_fields ? 'price_text' then r.price_text else price_text end,
    status = case when p_fields ? 'status' then r.status else status end
  where id = coalesce(p_id, v_row.id) and org_id = p_org returning * into v_row;
  if not found then
    raise exception 'save_event: not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- =====================================================================
-- 12. EXECUTE 정리: 이 스키마 모든 함수에서 PUBLIC/anon/authenticated 를 회수하고 허용 목록만 다시 준다.
--     (alter default privileges ... revoke from public 만으로는 PUBLIC 기본 EXECUTE 가 빠지지 않는다. SECURITY_BASELINE 3장)
--   anon + authenticated : is_public_newspaper, is_profile_complete, article_is_live, is_article_live, read_article,
--                          serve_ads, list_comments, most_read, search_articles, confirm_newsletter, unsubscribe_newsletter
--   authenticated        : 편집국·독자 RPC(함수 안에서 is_service_caller + 역할 + 엔타이틀먼트 검사), 정책 헬퍼
--   service_role 전용    : approve/reject_newspaper, set_newspaper_status, record_membership, record_donation, record_ad_stats,
--                          activate_listing, subscribe_newsletter, issue_newsletter_reconfirm, record_newsletter_issue_status,
--                          register/revoke_push_subscription, submit_tip, increment_article_views, run_scheduled_publishing,
--                          내부 헬퍼(assert_staff, plan_feature, add_revision, assert_keys, assert_publishable, token_hash,
--                          election_blackout_active, wire_contract_valid)
--   CHECK 헬퍼(is_org_path, are_org_paths)는 authenticated, service_role (CHECK 평가용)
--   트리거 함수는 아무에게도 주지 않는다(발동 시 EXECUTE 를 검사하지 않는다)
-- =====================================================================
-- 이름 목록으로 회수한다("all functions in schema"를 쓰지 않는 이유: 모놀리스 변환본은 public 스키마라 코어 함수 권한까지 지운다).
-- 목록은 이 파일의 create function 전부다(누락 검사: 아래 do 블록이 목록 밖 news 함수가 있으면 실패한다).
do $$
declare
  v_names text[] := array[
    'accept_staff_invite', 'activate_listing', 'ad_campaigns_before_update', 'ad_creatives_before_update', 'add_live_update',
    'add_revision', 'approve_newspaper', 'archive_article', 'are_org_paths', 'article_is_live', 'article_revisions_immutable',
    'articles_before_write', 'assert_keys', 'assert_publishable', 'assert_staff', 'can_view_article', 'comments_before_update',
    'compliance_weekly_stats', 'confirm_newsletter', 'correction_requests_before_write', 'current_reader_id',
    'delete_my_comment', 'donations_before_update', 'election_blackout_active', 'ensure_reader', 'events_before_update',
    'has_staff_role', 'home_layouts_before_update', 'increment_article_views', 'invite_staff', 'is_article_live', 'is_newsroom',
    'is_org_path', 'is_profile_complete', 'is_public_newspaper', 'issue_newsletter_reconfirm', 'life_events_before_update',
    'list_comments', 'local_listings_before_update', 'memberships_before_update', 'moderate_comment', 'most_read',
    'newsletter_issues_before_update', 'newsletter_subscriptions_before_write', 'newspapers_before_write', 'plan_feature',
    'post_comment', 'public_notices_before_update', 'publish_article', 'publish_home_layout', 'read_article',
    'readers_before_update', 'record_ad_stats', 'record_article_correction', 'record_donation', 'record_membership',
    'record_newsletter_issue_status', 'register_push_subscription', 'reject_newspaper', 'remove_staff', 'report_comment',
    'request_newspaper', 'respond_correction_request', 'review_ad_creative', 'review_article', 'review_life_event',
    'review_listing', 'revoke_push_subscription', 'run_scheduled_publishing', 'save_ad_campaign', 'save_ad_creative',
    'save_article', 'save_event', 'save_home_layout', 'save_media_asset', 'save_newsletter_issue', 'save_print_edition',
    'save_public_notice', 'schedule_article', 'search_articles', 'serve_ads', 'set_live_update_status', 'set_newspaper_profile',
    'set_newspaper_status', 'set_paywall_rule', 'set_reader_status', 'set_staff_role', 'set_syndication_settings',
    'set_tip_status', 'staff_before_update', 'staff_role', 'submit_article', 'submit_correction_request', 'submit_life_event',
    'submit_listing', 'submit_tip', 'subscribe_newsletter', 'tips_before_update', 'token_hash', 'unpublish_article',
    'unsubscribe_newsletter', 'update_my_staff_profile', 'upsert_ad_slot', 'upsert_advertiser', 'upsert_election_period',
    'upsert_membership_tier', 'upsert_newsletter_list', 'upsert_taxonomy', 'upsert_wire_contract', 'wire_contract_valid',
    'withdraw_newspaper_request', 'withdraw_reader'];
  v_missing text;
  f record;
begin
  -- @@MODULAR_ONLY_BEGIN (모놀리스는 public 에 코어 함수가 함께 있어 이 검사를 뺀다)
  select string_agg(p.proname, ', ') into v_missing
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'news' and not (p.proname = any (v_names));
  if v_missing is not null then
    raise exception 'news: function privilege list is missing %', v_missing;
  end if;
  -- @@MODULAR_ONLY_END
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'news' and p.proname = any (v_names)
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

grant execute on function news.is_public_newspaper(uuid) to anon, authenticated;
grant execute on function news.is_profile_complete(uuid) to anon, authenticated;
grant execute on function news.article_is_live(uuid, text, timestamptz, timestamptz, text, uuid) to anon, authenticated;
grant execute on function news.is_article_live(uuid) to anon, authenticated;
grant execute on function news.read_article(uuid, text) to anon, authenticated;
grant execute on function news.serve_ads(uuid, text) to anon, authenticated;
grant execute on function news.list_comments(uuid, integer, timestamptz) to anon, authenticated;
grant execute on function news.most_read(uuid, text, integer) to anon, authenticated;
grant execute on function news.search_articles(uuid, text, integer, integer) to anon, authenticated;
grant execute on function news.confirm_newsletter(text) to anon, authenticated;
grant execute on function news.unsubscribe_newsletter(text, text) to anon, authenticated;

grant execute on function news.is_org_path(uuid, text, text) to authenticated;
grant execute on function news.are_org_paths(uuid, text[], text) to authenticated;
grant execute on function news.staff_role(uuid) to authenticated;
grant execute on function news.has_staff_role(uuid, text[]) to authenticated;
grant execute on function news.is_newsroom(uuid, text[]) to authenticated;
grant execute on function news.can_view_article(uuid) to authenticated;
grant execute on function news.current_reader_id(uuid) to authenticated;

grant execute on function news.request_newspaper(text, text, text, text, date, text, text, text, text, text) to authenticated;
grant execute on function news.withdraw_newspaper_request(uuid) to authenticated;
grant execute on function news.set_newspaper_profile(uuid, jsonb) to authenticated;
grant execute on function news.invite_staff(uuid, uuid, text, text, text) to authenticated;
grant execute on function news.accept_staff_invite(uuid) to authenticated;
grant execute on function news.set_staff_role(uuid, uuid, text) to authenticated;
grant execute on function news.remove_staff(uuid, uuid) to authenticated;
grant execute on function news.update_my_staff_profile(uuid, jsonb) to authenticated;
grant execute on function news.upsert_taxonomy(uuid, text, uuid, jsonb) to authenticated;
grant execute on function news.save_article(uuid, uuid, jsonb) to authenticated;
grant execute on function news.submit_article(uuid) to authenticated;
grant execute on function news.review_article(uuid, text, text) to authenticated;
grant execute on function news.schedule_article(uuid, timestamptz) to authenticated;
grant execute on function news.publish_article(uuid) to authenticated;
grant execute on function news.unpublish_article(uuid, text) to authenticated;
grant execute on function news.archive_article(uuid) to authenticated;
grant execute on function news.record_article_correction(uuid, text, text, uuid) to authenticated;
grant execute on function news.save_media_asset(uuid, uuid, jsonb) to authenticated;
grant execute on function news.save_home_layout(uuid, uuid, jsonb) to authenticated;
grant execute on function news.publish_home_layout(uuid, timestamptz) to authenticated;
grant execute on function news.save_print_edition(uuid, uuid, jsonb) to authenticated;
grant execute on function news.add_live_update(uuid, text, boolean) to authenticated;
grant execute on function news.set_live_update_status(uuid, text, boolean) to authenticated;
grant execute on function news.ensure_reader(uuid, text, text, text, boolean, boolean) to authenticated;
grant execute on function news.withdraw_reader(uuid) to authenticated;
grant execute on function news.set_reader_status(uuid, text, text) to authenticated;
grant execute on function news.upsert_membership_tier(uuid, uuid, jsonb) to authenticated;
grant execute on function news.set_paywall_rule(uuid, jsonb) to authenticated;
grant execute on function news.upsert_ad_slot(uuid, uuid, jsonb) to authenticated;
grant execute on function news.upsert_advertiser(uuid, uuid, jsonb) to authenticated;
grant execute on function news.save_ad_campaign(uuid, uuid, jsonb) to authenticated;
grant execute on function news.save_ad_creative(uuid, uuid, jsonb) to authenticated;
grant execute on function news.review_ad_creative(uuid, text) to authenticated;
grant execute on function news.submit_listing(uuid, jsonb) to authenticated;
grant execute on function news.review_listing(uuid, text, text) to authenticated;
grant execute on function news.save_public_notice(uuid, uuid, jsonb) to authenticated;
grant execute on function news.upsert_newsletter_list(uuid, uuid, jsonb) to authenticated;
grant execute on function news.save_newsletter_issue(uuid, uuid, jsonb) to authenticated;
grant execute on function news.post_comment(uuid, text, uuid) to authenticated;
grant execute on function news.delete_my_comment(uuid) to authenticated;
grant execute on function news.report_comment(uuid, text, text, boolean) to authenticated;
grant execute on function news.moderate_comment(uuid, text, text) to authenticated;
grant execute on function news.set_tip_status(uuid, text, uuid, text) to authenticated;
grant execute on function news.submit_life_event(uuid, jsonb) to authenticated;
grant execute on function news.review_life_event(uuid, text, text) to authenticated;
grant execute on function news.upsert_wire_contract(uuid, uuid, jsonb) to authenticated;
grant execute on function news.set_syndication_settings(uuid, jsonb) to authenticated;
grant execute on function news.submit_correction_request(uuid, jsonb) to authenticated;
grant execute on function news.respond_correction_request(uuid, text, text) to authenticated;
grant execute on function news.compliance_weekly_stats(uuid, date) to authenticated;
grant execute on function news.upsert_election_period(uuid, uuid, jsonb) to authenticated;
grant execute on function news.save_event(uuid, uuid, jsonb) to authenticated;

-- =====================================================================
-- 13. 스케줄 (호스팅에서 pg_cron 을 켠 뒤 등록하거나 워커 크론이 service_role 로 호출. 로컬 검증에서는 실행하지 않는다)
--   매분                       : select news.run_scheduled_publishing();   -- 예약 기사·예약 홈 편집 게시
--   매시 5분                   : 조회 집계 롤업·오래된 시간 버킷 정리(워커, 90일 초과 버킷 삭제 제안)
--   매일 03:40 KST (40 18 * * *): 제보 보존 만료 삭제, 정정 기한 초과 알림, 수신동의 2년 재확인 대상 발송(워커)
--   -- select cron.schedule('news-scheduled-publishing', '* * * * *', $$select news.run_scheduled_publishing()$$);
-- =====================================================================

-- @@MODULAR_ONLY_BEGIN (모놀리스 변환 시 이 절은 빠지고 같은 값이 supabase/monolith/seed.sql 에 있다)
-- =====================================================================
-- 14. 플랜과 AI·음성 기본값 (모두 제안. 정본: docs/products/local-news/01_PRD.md 4장, 마스터 브리프 5장·7장)
--   14.1 플랜: VAT 별도 월 가격. features 해석은 서버만(01_PRD 4장 표). 무제한(-1) 값은 쓰지 않는다.
--        theming_level: Starter 1, Standard 2, Pro 2, Enterprise 3 (Multi-tenant_Theming README 1장). 체험은 Standard 수준.
--        news_trial 이 기본 플랜(is_default)이다. invite 앱이라 가입만으로는 쓰이지 않고 approve_newspaper 가 30일 만료로 부여한다.
--        모듈러 seed.sql 에는 news 행이 아직 없다(코어 요청 C-1, 06장). 그래서 여기서 on conflict do nothing 으로 넣는다.
-- =====================================================================
insert into core.plans (app_id, code, name, description, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('news', 'news_trial', '체험', 'Standard 기능 30일 체험(기자 3명)', 0, 'none', 300, 0, false,
   '{"news_staff_max": 3, "news_custom_domains": 0, "news_newsletter_monthly": 5000, "news_storage_gb": 10, "news_print_pdf": false, "news_regional_editions": false, "news_reader_fee_bps": 0, "news_api": false, "news_support_reports": false, "ai_monthly_credits": 300, "theming_level": 2}',
   true, true, 0),
  ('news', 'news_starter', '스타터', '인터넷 지역신문', 99000, 'month', 300, 0, false,
   '{"news_staff_max": 3, "news_custom_domains": 0, "news_newsletter_monthly": 5000, "news_storage_gb": 10, "news_print_pdf": false, "news_regional_editions": false, "news_reader_fee_bps": 300, "news_api": false, "news_support_reports": false, "ai_monthly_credits": 300, "theming_level": 1}',
   false, true, 1),
  ('news', 'news_standard', '스탠다드', '지역 주간지', 199000, 'month', 1500, 0, false,
   '{"news_staff_max": 10, "news_custom_domains": 1, "news_newsletter_monthly": 30000, "news_storage_gb": 50, "news_print_pdf": false, "news_regional_editions": false, "news_reader_fee_bps": 0, "news_api": false, "news_support_reports": false, "ai_monthly_credits": 1500, "theming_level": 2}',
   false, true, 2),
  ('news', 'news_pro', '프로', '지역 일간지', 390000, 'month', 4000, 0, false,
   '{"news_staff_max": 30, "news_custom_domains": 3, "news_newsletter_monthly": 100000, "news_storage_gb": 200, "news_print_pdf": true, "news_regional_editions": true, "news_reader_fee_bps": 0, "news_api": true, "news_support_reports": true, "ai_monthly_credits": 4000, "theming_level": 2}',
   false, true, 3),
  ('news', 'news_enterprise', '엔터프라이즈', '전용 DB(판매 모델 B), SLA. 계약 금액 별도', 0, 'month', 10000, 0, false,
   '{"news_staff_max": 200, "news_custom_domains": 5, "news_newsletter_monthly": 500000, "news_storage_gb": 1000, "news_print_pdf": true, "news_regional_editions": true, "news_reader_fee_bps": 0, "news_api": true, "news_support_reports": true, "ai_monthly_credits": 10000, "theming_level": 3}',
   false, false, 4)
on conflict (app_id, code) do nothing;

-- ---------------------------------------------------------------------
-- 14.2 AI·음성 기능별 라우팅 기본값: org_id null(플랫폼 기본), app_id 'news'. 기능 키는 소문자(마스터 브리프 7장).
--   - news.draft      : 보도자료 → 기사 초안(그래프 press_to_draft의 초안 노드). 공개 자료라 상용 먼저. 사람 승인 필수(review_article).
--   - news.headline / news.summary / news.proofread : 짧은 생성·교정. 비용 때문에 오픈소스 먼저.
--   - news.alt_text   : 사진 대체텍스트 초안(이미지 입력). 상용 먼저, 오픈소스 대체.
--   - news.moderation : 댓글 모더레이션 보조. 독자 개인정보가 들어가므로 오픈소스 강제.
--   - news.assistant  : 편집국 AI 어시스턴트(과거 기사·사내 규정 RAG). 상용 먼저(동의 없으면 resolve_ai_route 가 오픈소스로).
--   - news.knowledge(embedding) : 과거 기사·규정 컬렉션. 국내 오픈소스 임베딩 고정(컬렉션 임베딩 모델 고정 원칙).
--   - news.tts        : 오디오 기사. ElevenLabs 먼저(AI 음성 표시는 화면이 한다).
--   - news.stt        : 인터뷰 받아쓰기. 취재원(제3자) 목소리라 국외로 보내지 않는다. 오픈소스 강제, 녹음 원본 미저장.
--   - wiki.*, dify.aux : 공통 규칙과 같다(dify.aux 오픈소스 강제).
-- ---------------------------------------------------------------------
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'news', 'news.draft',     'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'news', 'news.headline',  'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"}]', false),
  (null, 'news', 'news.summary',   'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"}]', false),
  (null, 'news', 'news.proofread', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"}]', false),
  (null, 'news', 'news.alt_text',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"google","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'news', 'news.moderation','llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'news', 'news.assistant', 'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'news', 'news.knowledge', 'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'news', 'news.tts',       'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'news', 'news.stt',       'stt',       'open_source', '[{"provider":"oss-voice","model":"*"}]', true),
  (null, 'news', 'wiki.query',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'news', 'wiki.ingest',    'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'news', 'wiki.lint',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'news', 'dify.aux',       'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 14.3 체인 검사: 제공자 행이 있을 때만(seed 전에 적용되는 배포 순서에서도 실패하지 않게) 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'news'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'news routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;
-- @@MODULAR_ONLY_END
