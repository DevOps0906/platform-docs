-- =====================================================================
-- 1500_microweb.sql
-- microweb-studio 도메인: 모바일 청첩장(마이크로웹) 엔진 + 템플릿 카탈로그 + 대행 쇼룸(견적 문의, 제작 주문).
-- 선행: core 0000~0006, seed.sql(core.apps 'microweb' 행). 명세: docs/products/microweb-studio/05_DATA_MODEL.md
--
-- 보안 규칙 (docs/products/_platform-core/SECURITY_BASELINE.md 1~4장, DB_CONVENTIONS.md 7~10장)
--   - authenticated 에 EXECUTE 를 연 SECURITY DEFINER 함수의 호출자 판정은 core.is_service_caller() 만 쓴다.
--     is_privileged_session() 은 service_role 전용 함수(EXECUTE 가 service_role 에만 있음)에서만 쓴다.
--   - 역할 판정은 core.has_org_role(exists 기반, NULL 없음)로 한다.
--   - 제품 테이블 접근은 microweb.has_studio_access(org): 멤버 + 엔타이틀먼트 + 스튜디오 접근 허용(초대제 베타).
--   - anon 읽기: 게시 중 스냅샷(site_publications.is_live and expires_at > now())과 그 사이트의 공개 방명록만.
--   - 하객 쓰기(방명록, RSVP)와 견적 문의는 service_role 전용 함수로만. 함수 안에서 레이트 리밋과 스팸 검사를 한다.
--   - 돈, 상태, 게시가 걸린 컬럼은 사용자 GRANT 에서 뺀다. 상태 전이는 트리거가 강제한다(service_role 포함).
-- 모놀리스 사본: docs/products/microweb-studio/supabase/monolith/migrations/0002_microweb_domain.sql
--   (이 파일에서 '@modular-only' 블록을 빼고 core./microweb. 접두사를 public. 으로 바꾼 것)
-- 반복 실행 가능.
-- =====================================================================

-- @modular-only-begin
create schema if not exists microweb;
grant usage on schema microweb to anon, authenticated, service_role;
alter default privileges in schema microweb grant all on tables to service_role;
alter default privileges in schema microweb grant all on sequences to service_role;
alter default privileges in schema microweb grant execute on functions to service_role;
alter default privileges in schema microweb revoke execute on functions from public;

-- seed.sql 에 이미 있다(invite, beta). 조각 단독 적용을 위해 둔다.
insert into core.apps (id, name, schema_name, signup_policy, status)
values ('microweb', 'Microweb Studio', 'microweb', 'invite', 'beta')
on conflict (id) do nothing;
-- @modular-only-end


-- ---------------------------------------------------------------------
-- 1. templates: 템플릿 카탈로그(전역, 조직 없음). nexus 12개 모델이 원천. 쓰기는 service_role 만.
-- ---------------------------------------------------------------------
create table if not exists microweb.templates (
  id                    uuid primary key default gen_random_uuid(),
  code                  text not null unique
                        constraint templates_code_check check (code ~ '^[a-z][a-z0-9_]{2,40}$'),
  kind                  text not null
                        constraint templates_kind_check check (kind in (
                          'wedding', 'dol', 'obituary', 'business_card', 'mini_home', 'event',
                          'real_estate', 'portfolio', 'rolling_paper', 'qr_menu', 'pet_profile', 'gallery')),
  name                  text not null constraint templates_name_check check (char_length(name) between 1 and 60),
  summary               text,
  status                text not null default 'planned'
                        constraint templates_status_check check (status in ('planned', 'beta', 'released', 'retired')),
  release_phase         text not null default 'backlog'
                        constraint templates_release_phase_check check (release_phase in ('mvp', 'phase2', 'phase3', 'backlog')),
  agency_price_min_krw  integer constraint templates_price_min_check check (agency_price_min_krw is null or agency_price_min_krw >= 0),
  agency_price_max_krw  integer,
  price_note            text,
  self_publish_credits  integer constraint templates_self_credits_check check (self_publish_credits is null or self_publish_credits > 0),
  allowed_blocks        text[] not null default '{}',
  required_blocks       text[] not null default '{}',
  default_content       jsonb not null default '{}'::jsonb,
  preview_mockup        jsonb not null default '{}'::jsonb,
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint templates_price_range_check check (
    agency_price_max_krw is null or agency_price_min_krw is null or agency_price_max_krw >= agency_price_min_krw),
  constraint templates_required_blocks_check check (required_blocks <@ allowed_blocks)
);
create index if not exists templates_status_sort_idx on microweb.templates (status, sort_order);

-- ---------------------------------------------------------------------
-- 2. portfolio_items: 쇼룸 포트폴리오(전역). 고객 게시 동의가 없으면 published 불가(가짜 포트폴리오 차단).
-- ---------------------------------------------------------------------
create table if not exists microweb.portfolio_items (
  id                    uuid primary key default gen_random_uuid(),
  slug                  text not null unique constraint portfolio_items_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{2,58}[a-z0-9]$'),
  title                 text not null constraint portfolio_items_title_check check (char_length(title) between 1 and 80),
  category              text not null constraint portfolio_items_category_check check (category in ('microweb', 'website', 'detail_page')),
  tier                  text constraint portfolio_items_tier_check check (tier is null or tier in ('basic', 'pro', 'premium', 'custom')),
  industry              text constraint portfolio_items_industry_check check (industry is null or char_length(industry) <= 40),
  summary               text constraint portfolio_items_summary_check check (summary is null or char_length(summary) <= 300),
  external_url          text constraint portfolio_items_url_check check (external_url is null or external_url ~ '^https://'),
  image_path            text,
  client_permission_at  timestamptz,
  status                text not null default 'draft'
                        constraint portfolio_items_status_check check (status in ('draft', 'published', 'hidden')),
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint portfolio_items_publish_check check (status <> 'published' or (client_permission_at is not null and image_path is not null))
);
create index if not exists portfolio_items_status_sort_idx on microweb.portfolio_items (status, category, sort_order);

-- ---------------------------------------------------------------------
-- 3. studio_access: 초대제 베타 허용 목록. core 부트스트랩은 signup_policy='invite' 를 강제하지 않으므로
--    제품 RLS 가 이 표로 접근을 막는다. 쓰기는 service_role(운영자 초대 처리)만.
-- ---------------------------------------------------------------------
create table if not exists microweb.studio_access (
  org_id            uuid primary key references core.organizations(id) on delete cascade,
  mode              text not null default 'agency'
                    constraint studio_access_mode_check check (mode in ('agency', 'self_service')),
  max_active_sites  integer not null default 3
                    constraint studio_access_max_sites_check check (max_active_sites between 0 and 1000),
  granted_by        uuid,
  granted_at        timestamptz not null default now(),
  revoked_at        timestamptz,
  note              text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. sites: 청첩장/마이크로웹 1건(편집본). 공개 페이지는 이 표가 아니라 site_publications 스냅샷을 읽는다.
-- ---------------------------------------------------------------------
create table if not exists microweb.sites (
  id                        uuid primary key default gen_random_uuid(),
  org_id                    uuid not null references core.organizations(id) on delete cascade,
  template_id               uuid not null references microweb.templates(id),
  kind                      text not null
                            constraint sites_kind_check check (kind in (
                              'wedding', 'dol', 'obituary', 'business_card', 'mini_home', 'event',
                              'real_estate', 'portfolio', 'rolling_paper', 'qr_menu', 'pet_profile', 'gallery')),
  slug                      text not null unique
                            constraint sites_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{2,38}[a-z0-9]$' and slug !~ '--'),
  title                     text not null constraint sites_title_check check (char_length(title) between 1 and 80),
  status                    text not null default 'draft'
                            constraint sites_status_check check (status in (
                              'draft', 'review', 'publishing', 'published', 'unpublished', 'expired', 'archived')),
  content                   jsonb not null default '{}'::jsonb
                            constraint sites_content_check check (jsonb_typeof(content) = 'object' and pg_column_size(content) <= 262144),
  event_at                  timestamptz,
  expires_at                timestamptz,
  guestbook_enabled         boolean not null default true,
  rsvp_enabled              boolean not null default false,
  ai_greeting_enabled       boolean not null default false,
  noindex                   boolean not null default true,
  disclosure_consent_at     timestamptz,
  disclosure_consent_by     uuid,
  disclosure_consent_basis  text constraint sites_consent_basis_check check (
                              disclosure_consent_basis is null or disclosure_consent_basis in ('self', 'written', 'recorded_call')),
  preview_token_hash        text unique,
  preview_token_expires_at  timestamptz,
  customer_approved_at      timestamptz,
  customer_approved_name    text constraint sites_approved_name_check check (customer_approved_name is null or char_length(customer_approved_name) <= 40),
  publish_ledger_id         bigint references core.credit_ledger(id) on delete set null,
  publish_charged_at        timestamptz,
  publish_job_id            uuid references core.jobs(id) on delete set null,
  publish_requested_at      timestamptz,
  first_published_at        timestamptz,
  published_at              timestamptz,
  unpublished_at            timestamptz,
  expired_at                timestamptz,
  archived_at               timestamptz,
  created_by                uuid,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  constraint sites_expires_check check (expires_at is null or event_at is null or expires_at <= event_at + interval '365 days'),
  constraint sites_slug_reserved_check check (slug not in (
    'admin', 'api', 'studio', 'login', 'logout', 'signup', 'www', 'preview', 'static', 'assets',
    'help', 'pricing', 'portfolio', 'templates', 'simulator', 'contact'))
);
create index if not exists sites_org_status_idx on microweb.sites (org_id, status, updated_at desc);
create index if not exists sites_expiry_idx on microweb.sites (expires_at) where status in ('published', 'unpublished');
create index if not exists sites_publishing_idx on microweb.sites (publish_requested_at) where status = 'publishing';

-- ---------------------------------------------------------------------
-- 5. site_publications: 공개 스냅샷(사이트당 1행). anon 이 읽는 유일한 사이트 데이터.
--    쓰기는 finalize_publish / transition_site / expire_sites (DEFINER) 와 service_role 만.
-- ---------------------------------------------------------------------
create table if not exists microweb.site_publications (
  site_id         uuid primary key references microweb.sites(id) on delete cascade,
  org_id          uuid not null references core.organizations(id) on delete cascade,
  slug            text not null unique,
  version         integer not null default 1 constraint site_publications_version_check check (version >= 1),
  content         jsonb not null
                  constraint site_publications_content_check check (jsonb_typeof(content) = 'object' and pg_column_size(content) <= 262144),
  og_title        text constraint site_publications_og_title_check check (og_title is null or char_length(og_title) <= 80),
  og_description  text constraint site_publications_og_desc_check check (og_description is null or char_length(og_description) <= 160),
  og_image_url    text constraint site_publications_og_image_check check (og_image_url is null or og_image_url ~ '^https://'),
  is_live         boolean not null default false,
  published_at    timestamptz not null default now(),
  expires_at      timestamptz not null,
  unpublished_at  timestamptz,
  job_id          uuid references core.jobs(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists site_publications_live_idx on microweb.site_publications (slug) where is_live;

-- ---------------------------------------------------------------------
-- 6. site_assets: 업로드 사진/음원 메타. 원본은 org-files(비공개), 공개 파생본은 게시 때만 public-assets 로 복사.
-- ---------------------------------------------------------------------
create table if not exists microweb.site_assets (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  site_id        uuid not null references microweb.sites(id) on delete cascade,
  kind           text not null constraint site_assets_kind_check check (kind in ('hero', 'gallery', 'og', 'bgm', 'other')),
  storage_path   text not null unique,
  mime           text not null constraint site_assets_mime_check check (mime in ('image/jpeg', 'image/png', 'image/webp', 'audio/mpeg')),
  bytes          integer not null constraint site_assets_bytes_check check (bytes between 1 and 15728640),
  width          integer,
  height         integer,
  status         text not null default 'uploaded'
                 constraint site_assets_status_check check (status in ('uploaded', 'processing', 'ready', 'failed')),
  exif_stripped  boolean not null default false,
  variants       jsonb not null default '{}'::jsonb,
  public_paths   jsonb not null default '{}'::jsonb,
  caption        text constraint site_assets_caption_check check (caption is null or char_length(caption) <= 100),
  sort_order     integer not null default 0,
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint site_assets_path_check check (split_part(storage_path, '/', 1) = org_id::text and split_part(storage_path, '/', 2) = 'microweb'),
  constraint site_assets_kind_mime_check check ((kind = 'bgm') = (mime = 'audio/mpeg')),
  constraint site_assets_ready_check check (status <> 'ready' or exif_stripped or kind = 'bgm')
);
create index if not exists site_assets_site_idx on microweb.site_assets (site_id, kind, sort_order);

-- ---------------------------------------------------------------------
-- 7. guestbook_entries: 하객 방명록. INSERT 는 submit_guestbook_entry(service_role)만. ip_hash 는 사용자에게 안 보인다.
-- ---------------------------------------------------------------------
create table if not exists microweb.guestbook_entries (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  site_id       uuid not null references microweb.sites(id) on delete cascade,
  author_name   text not null constraint guestbook_entries_name_check check (char_length(btrim(author_name)) between 1 and 20),
  body          text not null constraint guestbook_entries_body_check check (char_length(btrim(body)) between 1 and 500),
  relation      text constraint guestbook_entries_relation_check check (
                  relation is null or relation in ('friend', 'colleague', 'family', 'acquaintance', 'other')),
  ai_assisted   boolean not null default false,
  status        text not null default 'visible'
                constraint guestbook_entries_status_check check (status in ('visible', 'hidden', 'spam')),
  ip_hash       text not null constraint guestbook_entries_ip_hash_check check (char_length(ip_hash) between 16 and 128),
  moderated_by  uuid,
  moderated_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists guestbook_entries_site_idx on microweb.guestbook_entries (site_id, created_at desc) where status = 'visible';
create index if not exists guestbook_entries_dedupe_idx on microweb.guestbook_entries (site_id, ip_hash, created_at desc);

-- ---------------------------------------------------------------------
-- 8. rsvp_responses: 참석 여부. 공개 읽기 없음(사이트 소유 조직 멤버만). INSERT 는 submit_rsvp(service_role)만.
-- ---------------------------------------------------------------------
create table if not exists microweb.rsvp_responses (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references core.organizations(id) on delete cascade,
  site_id     uuid not null references microweb.sites(id) on delete cascade,
  guest_name  text not null constraint rsvp_responses_name_check check (char_length(btrim(guest_name)) between 1 and 20),
  side        text not null default 'none' constraint rsvp_responses_side_check check (side in ('side_a', 'side_b', 'none')),
  attending   text not null constraint rsvp_responses_attending_check check (attending in ('yes', 'no', 'undecided')),
  party_size  smallint not null default 1 constraint rsvp_responses_party_check check (party_size between 1 and 10),
  meal        text constraint rsvp_responses_meal_check check (meal is null or meal in ('yes', 'no', 'undecided')),
  message     text constraint rsvp_responses_message_check check (message is null or char_length(message) <= 200),
  ip_hash     text not null constraint rsvp_responses_ip_hash_check check (char_length(ip_hash) between 16 and 128),
  created_at  timestamptz not null default now()
);
create index if not exists rsvp_responses_site_idx on microweb.rsvp_responses (site_id, created_at desc);

-- ---------------------------------------------------------------------
-- 9. leads: 견적 문의(대행 영업). org_id 는 스튜디오(대행사) 조직. INSERT 는 create_lead(service_role)만.
-- ---------------------------------------------------------------------
create table if not exists microweb.leads (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  source              text not null constraint leads_source_check check (source in ('contact_form', 'simulator', 'template_gallery', 'pricing', 'manual')),
  name                text not null constraint leads_name_check check (char_length(btrim(name)) between 1 and 40),
  phone               text constraint leads_phone_check check (phone is null or phone ~ '^0[0-9]{1,2}-?[0-9]{3,4}-?[0-9]{4}$'),
  email               text constraint leads_email_check check (email is null or (char_length(email) <= 254 and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  kind                text constraint leads_kind_check check (kind is null or kind in (
                        'wedding', 'dol', 'obituary', 'business_card', 'mini_home', 'event',
                        'real_estate', 'portfolio', 'rolling_paper', 'qr_menu', 'pet_profile', 'gallery', 'website', 'detail_page')),
  template_code       text,
  tier                text constraint leads_tier_check check (tier is null or tier in ('basic', 'pro', 'premium', 'custom')),
  industry            text constraint leads_industry_check check (industry is null or char_length(industry) <= 40),
  event_on            date,
  simulator           jsonb not null default '{}'::jsonb
                      constraint leads_simulator_check check (jsonb_typeof(simulator) = 'object' and pg_column_size(simulator) <= 8192),
  message             text constraint leads_message_check check (message is null or char_length(message) <= 2000),
  privacy_consent_at  timestamptz not null,
  status              text not null default 'new'
                      constraint leads_status_check check (status in ('new', 'contacted', 'quoted', 'won', 'lost', 'spam')),
  status_note         text constraint leads_status_note_check check (status_note is null or char_length(status_note) <= 500),
  ip_hash             text,
  contacted_at        timestamptz,
  closed_at           timestamptz,
  purge_after         timestamptz not null default (now() + interval '1 year'),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint leads_contact_check check (phone is not null or email is not null)
);
create index if not exists leads_org_status_idx on microweb.leads (org_id, status, created_at desc);
create index if not exists leads_purge_idx on microweb.leads (purge_after);

-- ---------------------------------------------------------------------
-- 10. production_orders: 대행 제작 주문(대행사 자체 장부). 플랫폼 과금(core.payment_orders)과 별개.
--     카드번호 같은 결제 민감정보는 저장하지 않는다(12자리 이상 숫자열 금지).
-- ---------------------------------------------------------------------
create table if not exists microweb.production_orders (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  lead_id            uuid references microweb.leads(id) on delete set null,
  site_id            uuid references microweb.sites(id) on delete set null,
  customer_name      text not null constraint production_orders_customer_check check (char_length(btrim(customer_name)) between 1 and 40),
  template_code      text,
  tier               text constraint production_orders_tier_check check (tier is null or tier in ('basic', 'pro', 'premium', 'custom')),
  amount_krw         integer not null constraint production_orders_amount_check check (amount_krw between 0 and 100000000),
  status             text not null default 'quoted'
                     constraint production_orders_status_check check (status in (
                       'quoted', 'paid', 'in_production', 'delivered', 'closed', 'canceled', 'refunded')),
  payment_method     text constraint production_orders_method_check check (
                       payment_method is null or payment_method in ('bank_transfer', 'toss_link', 'card_onsite', 'other')),
  payment_reference  text constraint production_orders_reference_check check (
                       payment_reference is null or (char_length(payment_reference) <= 100 and payment_reference !~ '[0-9]{12,}')),
  note               text constraint production_orders_note_check check (note is null or char_length(note) <= 1000),
  paid_at            timestamptz,
  in_production_at   timestamptz,
  delivered_at       timestamptz,
  closed_at          timestamptz,
  canceled_at        timestamptz,
  refunded_at        timestamptz,
  created_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint production_orders_paid_check check (status in ('quoted', 'canceled') or (paid_at is not null and payment_method is not null))
);
create index if not exists production_orders_org_status_idx on microweb.production_orders (org_id, status, created_at desc);
create index if not exists production_orders_site_idx on microweb.production_orders (site_id) where site_id is not null;


-- ---------------------------------------------------------------------
-- 11. updated_at 트리거 (core.set_updated_at 재사용)
-- ---------------------------------------------------------------------
drop trigger if exists templates_set_updated_at on microweb.templates;
create trigger templates_set_updated_at before update on microweb.templates for each row execute function core.set_updated_at();
drop trigger if exists portfolio_items_set_updated_at on microweb.portfolio_items;
create trigger portfolio_items_set_updated_at before update on microweb.portfolio_items for each row execute function core.set_updated_at();
drop trigger if exists studio_access_set_updated_at on microweb.studio_access;
create trigger studio_access_set_updated_at before update on microweb.studio_access for each row execute function core.set_updated_at();
drop trigger if exists sites_set_updated_at on microweb.sites;
create trigger sites_set_updated_at before update on microweb.sites for each row execute function core.set_updated_at();
drop trigger if exists site_publications_set_updated_at on microweb.site_publications;
create trigger site_publications_set_updated_at before update on microweb.site_publications for each row execute function core.set_updated_at();
drop trigger if exists site_assets_set_updated_at on microweb.site_assets;
create trigger site_assets_set_updated_at before update on microweb.site_assets for each row execute function core.set_updated_at();
drop trigger if exists guestbook_entries_set_updated_at on microweb.guestbook_entries;
create trigger guestbook_entries_set_updated_at before update on microweb.guestbook_entries for each row execute function core.set_updated_at();
drop trigger if exists leads_set_updated_at on microweb.leads;
create trigger leads_set_updated_at before update on microweb.leads for each row execute function core.set_updated_at();
drop trigger if exists production_orders_set_updated_at on microweb.production_orders;
create trigger production_orders_set_updated_at before update on microweb.production_orders for each row execute function core.set_updated_at();

-- ---------------------------------------------------------------------
-- 12. 이중 잠금: 사용자 쓰기 정책이 없는 표는 guard 트리거로 사용자 세션 쓰기를 42501 로 거부한다.
-- ---------------------------------------------------------------------
drop trigger if exists templates_guard_write on microweb.templates;
create trigger templates_guard_write before insert or update or delete on microweb.templates
  for each row execute function core.guard_privileged_write();
drop trigger if exists portfolio_items_guard_write on microweb.portfolio_items;
create trigger portfolio_items_guard_write before insert or update or delete on microweb.portfolio_items
  for each row execute function core.guard_privileged_write();
drop trigger if exists studio_access_guard_write on microweb.studio_access;
create trigger studio_access_guard_write before insert or update or delete on microweb.studio_access
  for each row execute function core.guard_privileged_write();
drop trigger if exists site_publications_guard_write on microweb.site_publications;
create trigger site_publications_guard_write before insert or update or delete on microweb.site_publications
  for each row execute function core.guard_privileged_write();
drop trigger if exists leads_guard_write on microweb.leads;
create trigger leads_guard_write before insert or update or delete on microweb.leads
  for each row execute function core.guard_privileged_write();
drop trigger if exists production_orders_guard_write on microweb.production_orders;
create trigger production_orders_guard_write before insert or update or delete on microweb.production_orders
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 13. 상태 전이 트리거 (service_role 쓰기에도 적용, 위반은 MW001)
-- ---------------------------------------------------------------------
create or replace function microweb.sites_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' then
      raise exception 'sites: new site must start as draft' using errcode = 'MW001';
    end if;
    return new;
  end if;
  if new.status is not distinct from old.status then
    return new;
  end if;
  if not (
       (old.status = 'draft'       and new.status in ('review', 'publishing', 'archived'))
    or (old.status = 'review'      and new.status in ('draft', 'publishing', 'archived'))
    or (old.status = 'publishing'  and new.status in ('published', 'draft', 'unpublished', 'expired'))
    or (old.status = 'published'   and new.status in ('publishing', 'unpublished', 'expired'))
    or (old.status = 'unpublished' and new.status in ('publishing', 'expired', 'archived'))
    or (old.status = 'expired'     and new.status in ('publishing', 'archived'))
  ) then
    raise exception 'sites: transition % -> % not allowed', old.status, new.status using errcode = 'MW001';
  end if;
  return new;
end;
$$;
drop trigger if exists sites_status_transition on microweb.sites;
create trigger sites_status_transition before insert or update on microweb.sites
  for each row execute function microweb.sites_status_transition();

-- 편집 잠금: 사용자 세션은 publishing/archived 상태를 편집할 수 없고, 만료일은 미래여야 한다.
-- 슬러그는 첫 게시 뒤 누구도 바꿀 수 없다(공유된 링크가 깨지므로).
create or replace function microweb.sites_guard_edit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.slug is distinct from old.slug and old.first_published_at is not null then
    raise exception 'sites: slug is locked after first publish' using errcode = 'MW002';
  end if;
  if not core.is_privileged_session() then
    if old.status in ('publishing', 'archived') then
      raise exception 'sites: site is locked in status %', old.status using errcode = 'MW003';
    end if;
    if new.expires_at is distinct from old.expires_at then
      if new.expires_at is null and old.first_published_at is not null then
        raise exception 'sites: published site needs expires_at' using errcode = '22023';
      end if;
      if new.expires_at is not null and new.expires_at <= now() then
        raise exception 'sites: expires_at must be in the future' using errcode = '22023';
      end if;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists sites_guard_edit on microweb.sites;
create trigger sites_guard_edit before update on microweb.sites
  for each row execute function microweb.sites_guard_edit();

-- 만료일 변경을 공개 스냅샷에 반영한다(DEFINER: 사용자 세션에서도 스냅샷 guard 를 통과해야 하므로).
create or replace function microweb.sites_sync_publication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.expires_at is distinct from old.expires_at and new.expires_at is not null then
    update microweb.site_publications set expires_at = new.expires_at where site_id = new.id;
  end if;
  return null;
end;
$$;
drop trigger if exists sites_sync_publication on microweb.sites;
create trigger sites_sync_publication after update of expires_at on microweb.sites
  for each row execute function microweb.sites_sync_publication();

create or replace function microweb.leads_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  if not (
       (old.status = 'new'       and new.status in ('contacted', 'quoted', 'lost', 'spam'))
    or (old.status = 'contacted' and new.status in ('quoted', 'won', 'lost', 'spam'))
    or (old.status = 'quoted'    and new.status in ('won', 'lost', 'spam'))
    or (old.status = 'lost'      and new.status in ('contacted'))
  ) then
    raise exception 'leads: transition % -> % not allowed', old.status, new.status using errcode = 'MW001';
  end if;
  return new;
end;
$$;
drop trigger if exists leads_status_transition on microweb.leads;
create trigger leads_status_transition before update on microweb.leads
  for each row execute function microweb.leads_status_transition();

create or replace function microweb.production_orders_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'quoted' then
      raise exception 'production_orders: new order must start as quoted' using errcode = 'MW001';
    end if;
    return new;
  end if;
  if new.status is not distinct from old.status then
    return new;
  end if;
  if not (
       (old.status = 'quoted'        and new.status in ('paid', 'canceled'))
    or (old.status = 'paid'          and new.status in ('in_production', 'refunded'))
    or (old.status = 'in_production' and new.status in ('delivered', 'refunded'))
    or (old.status = 'delivered'     and new.status in ('closed', 'refunded'))
  ) then
    raise exception 'production_orders: transition % -> % not allowed', old.status, new.status using errcode = 'MW001';
  end if;
  return new;
end;
$$;
drop trigger if exists production_orders_status_transition on microweb.production_orders;
create trigger production_orders_status_transition before insert or update on microweb.production_orders
  for each row execute function microweb.production_orders_status_transition();


-- ---------------------------------------------------------------------
-- 14. RLS 헬퍼 (DEFINER, 읽기 전용)
-- ---------------------------------------------------------------------
create or replace function microweb.has_studio_access(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select core.is_org_member(p_org_id)
     and core.has_entitlement(p_org_id, 'microweb')
     and exists (select 1 from microweb.studio_access a where a.org_id = p_org_id and a.revoked_at is null);
$$;

create or replace function microweb.is_site_live(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from microweb.site_publications p
    where p.site_id = p_site_id and p.is_live and p.expires_at > now()
  );
$$;

create or replace function microweb.is_guestbook_public(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select microweb.is_site_live(p_site_id)
     and exists (select 1 from microweb.sites s where s.id = p_site_id and s.guestbook_enabled);
$$;

-- 내부용: DEFINER 함수 안에서 호출자 역할과 스튜디오 접근을 확인한다. 규칙 1(is_service_caller) + has_org_role(NULL 없음).
create or replace function microweb.require_org_role(p_org_id uuid, p_roles text[], p_ctx text)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if core.is_service_caller() then
    return;
  end if;
  if p_org_id is null or not core.has_org_role(p_org_id, p_roles) then
    raise exception '%: role % required', p_ctx, p_roles using errcode = '42501';
  end if;
  if not microweb.has_studio_access(p_org_id) then
    raise exception '%: no studio access', p_ctx using errcode = '42501';
  end if;
end;
$$;


-- ---------------------------------------------------------------------
-- 15. 사용자 RPC (authenticated + service_role). 호출자 판정은 is_service_caller.
-- ---------------------------------------------------------------------

-- 사이트 생성: 템플릿(beta/released)만, 활성 사이트 상한(studio_access.max_active_sites), 기본 만료 = 예식 + 90일.
create or replace function microweb.create_site(
  p_org_id        uuid,
  p_template_code text,
  p_title         text,
  p_slug          text,
  p_event_at      timestamptz default null
)
returns microweb.sites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl    microweb.templates;
  v_access microweb.studio_access;
  v_active integer;
  v_row    microweb.sites;
begin
  perform microweb.require_org_role(p_org_id, array['owner', 'admin', 'member'], 'create_site');
  select * into v_access from microweb.studio_access where org_id = p_org_id and revoked_at is null;
  if not found then
    raise exception 'create_site: no studio access' using errcode = '42501';
  end if;
  if not core.has_entitlement(p_org_id, 'microweb') then
    raise exception 'create_site: no entitlement' using errcode = '42501';
  end if;
  select * into v_tpl from microweb.templates where code = p_template_code and status in ('beta', 'released');
  if not found then
    raise exception 'create_site: template % not available', p_template_code using errcode = 'MW004';
  end if;
  perform pg_advisory_xact_lock(hashtext('microweb:create_site:' || p_org_id::text));
  select count(*) into v_active from microweb.sites
  where org_id = p_org_id and status not in ('expired', 'archived');
  if v_active >= v_access.max_active_sites then
    raise exception 'create_site: active site limit % reached', v_access.max_active_sites using errcode = 'MW005';
  end if;
  insert into microweb.sites (org_id, template_id, kind, slug, title, content, event_at, expires_at, created_by)
  values (p_org_id, v_tpl.id, v_tpl.kind, lower(btrim(p_slug)), btrim(p_title), v_tpl.default_content, p_event_at,
          case when p_event_at is not null then p_event_at + interval '90 days' end, auth.uid())
  returning * into v_row;
  perform core.write_audit(p_org_id, 'site.create', 'site', v_row.id::text, null,
                           jsonb_build_object('slug', v_row.slug, 'template', p_template_code));
  return v_row;
end;
$$;

-- 사용자 상태 전이: draft <-> review (owner/admin/member), unpublished / archived (owner/admin).
-- 게시(publishing/published)와 만료(expired)는 이 함수로 바꿀 수 없다.
create or replace function microweb.transition_site(p_site_id uuid, p_to text, p_reason text default null)
returns microweb.sites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row  microweb.sites;
  v_from text;
begin
  select * into v_row from microweb.sites where id = p_site_id for update;
  if not found then
    raise exception 'transition_site: not found' using errcode = 'P0002';
  end if;
  if p_to in ('unpublished', 'archived') then
    perform microweb.require_org_role(v_row.org_id, array['owner', 'admin'], 'transition_site');
  elsif p_to in ('draft', 'review') then
    perform microweb.require_org_role(v_row.org_id, array['owner', 'admin', 'member'], 'transition_site');
  else
    raise exception 'transition_site: % is not a user transition', p_to using errcode = 'MW001';
  end if;
  v_from := v_row.status;
  update microweb.sites
     set status = p_to,
         unpublished_at = case when p_to = 'unpublished' then now() else unpublished_at end,
         archived_at = case when p_to = 'archived' then now() else archived_at end,
         preview_token_hash = case when p_to = 'archived' then null else preview_token_hash end,
         preview_token_expires_at = case when p_to = 'archived' then null else preview_token_expires_at end
   where id = p_site_id
  returning * into v_row;
  if p_to = 'unpublished' then
    update microweb.site_publications set is_live = false, unpublished_at = now() where site_id = p_site_id;
  end if;
  perform core.write_audit(v_row.org_id, 'site.' || p_to, 'site', p_site_id::text,
                           jsonb_build_object('status', v_from),
                           jsonb_build_object('status', p_to, 'reason', p_reason));
  return v_row;
end;
$$;

-- 고객 시안 확인 링크 토큰 발급. 원문은 반환값으로 한 번만 나가고 DB 에는 sha256 해시만 남는다. TTL 1~336시간.
create or replace function microweb.issue_preview_token(p_site_id uuid, p_ttl_hours integer default 168)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   microweb.sites;
  v_token text;
begin
  select * into v_row from microweb.sites where id = p_site_id for update;
  if not found then
    raise exception 'issue_preview_token: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_row.org_id, array['owner', 'admin', 'member'], 'issue_preview_token');
  if v_row.status in ('publishing', 'archived') then
    raise exception 'issue_preview_token: site is %', v_row.status using errcode = 'MW003';
  end if;
  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  update microweb.sites
     set preview_token_hash = encode(extensions.digest(v_token, 'sha256'), 'hex'),
         preview_token_expires_at = now() + make_interval(hours => least(greatest(coalesce(p_ttl_hours, 168), 1), 336))
   where id = p_site_id;
  perform core.write_audit(v_row.org_id, 'site.preview_token', 'site', p_site_id::text, null,
                           jsonb_build_object('ttl_hours', p_ttl_hours));
  return v_token;
end;
$$;

-- 계좌번호/연락처 공개 동의 기록. 게시 전 필수(request_publish 가 검사).
create or replace function microweb.confirm_disclosure_consent(p_site_id uuid, p_basis text)
returns microweb.sites
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.sites;
begin
  select * into v_row from microweb.sites where id = p_site_id for update;
  if not found then
    raise exception 'confirm_disclosure_consent: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_row.org_id, array['owner', 'admin', 'member'], 'confirm_disclosure_consent');
  if coalesce(p_basis, '') not in ('self', 'written', 'recorded_call') then
    raise exception 'confirm_disclosure_consent: invalid basis' using errcode = '22023';
  end if;
  update microweb.sites
     set disclosure_consent_at = now(), disclosure_consent_by = auth.uid(), disclosure_consent_basis = p_basis
   where id = p_site_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'site.disclosure_consent', 'site', p_site_id::text, null,
                           jsonb_build_object('basis', p_basis));
  return v_row;
end;
$$;

create or replace function microweb.moderate_guestbook_entry(p_entry_id uuid, p_status text)
returns microweb.guestbook_entries
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.guestbook_entries; v_from text;
begin
  select * into v_row from microweb.guestbook_entries where id = p_entry_id for update;
  if not found then
    raise exception 'moderate_guestbook_entry: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_row.org_id, array['owner', 'admin', 'member'], 'moderate_guestbook_entry');
  if coalesce(p_status, '') not in ('visible', 'hidden', 'spam') then
    raise exception 'moderate_guestbook_entry: invalid status' using errcode = '22023';
  end if;
  v_from := v_row.status;
  update microweb.guestbook_entries
     set status = p_status, moderated_by = auth.uid(), moderated_at = now()
   where id = p_entry_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'guestbook.' || p_status, 'guestbook_entry', p_entry_id::text,
                           jsonb_build_object('status', v_from), jsonb_build_object('status', p_status));
  return v_row;
end;
$$;

create or replace function microweb.set_lead_status(p_lead_id uuid, p_to text, p_note text default null)
returns microweb.leads
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.leads; v_from text;
begin
  select * into v_row from microweb.leads where id = p_lead_id for update;
  if not found then
    raise exception 'set_lead_status: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_row.org_id, array['owner', 'admin', 'member'], 'set_lead_status');
  v_from := v_row.status;
  update microweb.leads
     set status = p_to,
         status_note = coalesce(p_note, status_note),
         contacted_at = case when p_to = 'contacted' and contacted_at is null then now() else contacted_at end,
         closed_at = case when p_to in ('won', 'lost', 'spam') then now() else closed_at end
   where id = p_lead_id
  returning * into v_row;
  -- 감사에는 개인정보(이름, 연락처, 메시지)를 남기지 않는다.
  perform core.write_audit(v_row.org_id, 'lead.' || p_to, 'lead', p_lead_id::text,
                           jsonb_build_object('status', v_from), jsonb_build_object('status', p_to));
  return v_row;
end;
$$;

-- 개인정보 삭제 요청 처리(owner/admin). 연결된 주문의 lead_id 는 null 이 된다.
create or replace function microweb.delete_lead(p_lead_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  select org_id into v_org from microweb.leads where id = p_lead_id;
  if not found then
    raise exception 'delete_lead: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_org, array['owner', 'admin'], 'delete_lead');
  delete from microweb.leads where id = p_lead_id;
  perform core.write_audit(v_org, 'lead.delete', 'lead', p_lead_id::text);
end;
$$;

create or replace function microweb.create_order(
  p_org_id        uuid,
  p_customer_name text,
  p_amount_krw    integer,
  p_template_code text default null,
  p_tier          text default null,
  p_lead_id       uuid default null,
  p_site_id       uuid default null,
  p_note          text default null
)
returns microweb.production_orders
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.production_orders;
begin
  perform microweb.require_org_role(p_org_id, array['owner', 'admin'], 'create_order');
  if p_lead_id is not null and not exists (select 1 from microweb.leads l where l.id = p_lead_id and l.org_id = p_org_id) then
    raise exception 'create_order: lead not in organization' using errcode = '42501';
  end if;
  if p_site_id is not null and not exists (select 1 from microweb.sites s where s.id = p_site_id and s.org_id = p_org_id) then
    raise exception 'create_order: site not in organization' using errcode = '42501';
  end if;
  insert into microweb.production_orders (org_id, lead_id, site_id, customer_name, template_code, tier, amount_krw, note, created_by)
  values (p_org_id, p_lead_id, p_site_id, btrim(p_customer_name), p_template_code, p_tier, p_amount_krw, p_note, auth.uid())
  returning * into v_row;
  perform core.write_audit(p_org_id, 'order.create', 'production_order', v_row.id::text, null,
                           jsonb_build_object('amount_krw', p_amount_krw, 'tier', p_tier, 'template', p_template_code));
  return v_row;
end;
$$;

create or replace function microweb.transition_order(
  p_order_id          uuid,
  p_to                text,
  p_payment_method    text default null,
  p_payment_reference text default null,
  p_note              text default null
)
returns microweb.production_orders
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.production_orders; v_from text;
begin
  select * into v_row from microweb.production_orders where id = p_order_id for update;
  if not found then
    raise exception 'transition_order: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_row.org_id, array['owner', 'admin'], 'transition_order');
  if p_to = 'paid' and coalesce(p_payment_method, '') = '' then
    raise exception 'transition_order: payment_method required' using errcode = '22023';
  end if;
  v_from := v_row.status;
  update microweb.production_orders
     set status = p_to,
         payment_method = case when p_to = 'paid' then p_payment_method else payment_method end,
         payment_reference = case when p_to = 'paid' then p_payment_reference else payment_reference end,
         paid_at = case when p_to = 'paid' then now() else paid_at end,
         in_production_at = case when p_to = 'in_production' then now() else in_production_at end,
         delivered_at = case when p_to = 'delivered' then now() else delivered_at end,
         closed_at = case when p_to = 'closed' then now() else closed_at end,
         canceled_at = case when p_to = 'canceled' then now() else canceled_at end,
         refunded_at = case when p_to = 'refunded' then now() else refunded_at end,
         note = coalesce(p_note, note)
   where id = p_order_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'order.' || p_to, 'production_order', p_order_id::text,
                           jsonb_build_object('status', v_from),
                           jsonb_build_object('status', p_to, 'amount_krw', v_row.amount_krw, 'payment_method', v_row.payment_method));
  return v_row;
end;
$$;

create or replace function microweb.attach_order_site(p_order_id uuid, p_site_id uuid)
returns microweb.production_orders
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.production_orders;
begin
  select * into v_row from microweb.production_orders where id = p_order_id for update;
  if not found then
    raise exception 'attach_order_site: not found' using errcode = 'P0002';
  end if;
  perform microweb.require_org_role(v_row.org_id, array['owner', 'admin'], 'attach_order_site');
  if not exists (select 1 from microweb.sites s where s.id = p_site_id and s.org_id = v_row.org_id) then
    raise exception 'attach_order_site: site not in organization' using errcode = '42501';
  end if;
  update microweb.production_orders set site_id = p_site_id where id = p_order_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'order.attach_site', 'production_order', p_order_id::text, null,
                           jsonb_build_object('site_id', p_site_id));
  return v_row;
end;
$$;


-- ---------------------------------------------------------------------
-- 16. service_role 전용 함수 (Route Handler / 워커 / pg_cron). EXECUTE 1차 잠금 + is_privileged_session 2차 잠금.
-- ---------------------------------------------------------------------

-- 게시 요청. 호출자(p_actor_id)가 owner/admin 인지 다시 확인한다.
-- 대행 모드: 첫 게시는 결제된 제작 주문 + 고객 확인이 필요. 셀프 모드: 첫 게시는 microweb consume 원장(미환불, 미사용)이 필요.
create or replace function microweb.request_publish(p_site_id uuid, p_actor_id uuid, p_ledger_id bigint default null)
returns microweb.sites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row    microweb.sites;
  v_access microweb.studio_access;
begin
  if not core.is_privileged_session() then
    raise exception 'request_publish: service_role only' using errcode = '42501';
  end if;
  select * into v_row from microweb.sites where id = p_site_id for update;
  if not found then
    raise exception 'request_publish: not found' using errcode = 'P0002';
  end if;
  if p_actor_id is null or not exists (
       select 1 from core.org_members m
       where m.org_id = v_row.org_id and m.user_id = p_actor_id and m.status = 'active' and m.role in ('owner', 'admin')) then
    raise exception 'request_publish: owner/admin only' using errcode = '42501';
  end if;
  select * into v_access from microweb.studio_access where org_id = v_row.org_id and revoked_at is null;
  if not found or not core.has_entitlement(v_row.org_id, 'microweb') then
    raise exception 'request_publish: no studio access' using errcode = '42501';
  end if;
  if v_row.status not in ('draft', 'review', 'published', 'unpublished', 'expired') then
    raise exception 'request_publish: cannot publish from %', v_row.status using errcode = 'MW001';
  end if;
  if v_row.disclosure_consent_at is null then
    raise exception 'request_publish: disclosure consent required' using errcode = 'MW006';
  end if;
  if v_row.expires_at is null or v_row.expires_at <= now() then
    raise exception 'request_publish: expires_at must be in the future' using errcode = 'MW007';
  end if;
  if v_access.mode = 'agency' then
    if v_row.first_published_at is null then
      if not exists (select 1 from microweb.production_orders o
                     where o.site_id = v_row.id and o.status in ('paid', 'in_production', 'delivered', 'closed')) then
        raise exception 'request_publish: paid production order required' using errcode = 'MW008';
      end if;
      if v_row.customer_approved_at is null then
        raise exception 'request_publish: customer approval required' using errcode = 'MW009';
      end if;
    end if;
  else
    if v_row.publish_charged_at is null then
      if p_ledger_id is null or not exists (
           select 1 from core.credit_ledger l
           where l.id = p_ledger_id and l.org_id = v_row.org_id and l.app_id = 'microweb' and l.entry_type = 'consume') then
        raise exception 'request_publish: credit charge required' using errcode = 'MW008';
      end if;
      if exists (select 1 from core.credit_ledger r where r.refund_of = p_ledger_id)
         or exists (select 1 from microweb.sites s where s.publish_ledger_id = p_ledger_id and s.id <> v_row.id) then
        raise exception 'request_publish: ledger already refunded or used' using errcode = 'MW008';
      end if;
    end if;
  end if;
  update microweb.sites
     set status = 'publishing',
         publish_requested_at = now(),
         publish_ledger_id = case when v_row.publish_charged_at is null and p_ledger_id is not null then p_ledger_id else publish_ledger_id end
   where id = p_site_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'site.publish_request', 'site', p_site_id::text, null,
                           jsonb_build_object('actor', p_actor_id, 'mode', v_access.mode, 'ledger_id', p_ledger_id));
  return v_row;
end;
$$;

-- 워커가 공개 파생본 복사를 마친 뒤 호출한다. 스냅샷을 만들고 published 로 바꾼다.
create or replace function microweb.finalize_publish(
  p_site_id        uuid,
  p_job_id         uuid,
  p_content        jsonb,
  p_og_title       text default null,
  p_og_description text default null,
  p_og_image_url   text default null
)
returns microweb.site_publications
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row microweb.sites;
  v_pub microweb.site_publications;
begin
  if not core.is_privileged_session() then
    raise exception 'finalize_publish: service_role only' using errcode = '42501';
  end if;
  select * into v_row from microweb.sites where id = p_site_id for update;
  if not found then
    raise exception 'finalize_publish: not found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'publishing' then
    raise exception 'finalize_publish: site is %', v_row.status using errcode = 'MW001';
  end if;
  insert into microweb.site_publications as p
    (site_id, org_id, slug, version, content, og_title, og_description, og_image_url, is_live, published_at, expires_at, job_id)
  values
    (v_row.id, v_row.org_id, v_row.slug, 1, p_content, p_og_title, p_og_description, p_og_image_url, true, now(), v_row.expires_at, p_job_id)
  on conflict (site_id) do update
    set version = p.version + 1, slug = excluded.slug, content = excluded.content,
        og_title = excluded.og_title, og_description = excluded.og_description, og_image_url = excluded.og_image_url,
        is_live = true, published_at = now(), expires_at = excluded.expires_at, unpublished_at = null, job_id = excluded.job_id
  returning * into v_pub;
  update microweb.sites
     set status = 'published',
         published_at = now(),
         first_published_at = coalesce(first_published_at, now()),
         publish_charged_at = case when publish_ledger_id is not null then coalesce(publish_charged_at, now()) else publish_charged_at end,
         publish_job_id = p_job_id,
         unpublished_at = null,
         expired_at = null
   where id = p_site_id;
  perform core.write_audit(v_row.org_id, 'site.publish', 'site', p_site_id::text, null,
                           jsonb_build_object('version', v_pub.version, 'job_id', p_job_id));
  return v_pub;
end;
$$;

-- 게시 잡 실패. 크레딧 환불은 core.fail_job 이 jobs.credit_ledger_id 로 처리한다. 여기서는 상태만 되돌린다.
create or replace function microweb.fail_publish(p_site_id uuid, p_error text default null)
returns microweb.sites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row microweb.sites;
  v_to  text;
begin
  if not core.is_privileged_session() then
    raise exception 'fail_publish: service_role only' using errcode = '42501';
  end if;
  select * into v_row from microweb.sites where id = p_site_id for update;
  if not found then
    raise exception 'fail_publish: not found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'publishing' then
    return v_row;
  end if;
  v_to := case
    when microweb.is_site_live(p_site_id) then 'published'
    when v_row.expired_at is not null then 'expired'
    when v_row.first_published_at is not null then 'unpublished'
    else 'draft' end;
  update microweb.sites
     set status = v_to,
         publish_ledger_id = case when publish_charged_at is null then null else publish_ledger_id end
   where id = p_site_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'site.publish_failed', 'site', p_site_id::text, null,
                           jsonb_build_object('status', v_to, 'error', left(coalesce(p_error, ''), 300)));
  return v_row;
end;
$$;

-- 고객 시안 확인(공개 /p/[token] 라우트가 토큰 해시로 호출).
create or replace function microweb.record_customer_approval(p_token_hash text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_row microweb.sites;
begin
  if not core.is_privileged_session() then
    raise exception 'record_customer_approval: service_role only' using errcode = '42501';
  end if;
  select * into v_row from microweb.sites
  where preview_token_hash = p_token_hash and preview_token_expires_at > now() and status in ('draft', 'review')
  for update;
  if not found then
    raise exception 'record_customer_approval: invalid or expired token' using errcode = 'MW013';
  end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 40 then
    raise exception 'record_customer_approval: name required' using errcode = '22023';
  end if;
  update microweb.sites set customer_approved_at = now(), customer_approved_name = btrim(p_name) where id = v_row.id;
  perform core.write_audit(v_row.org_id, 'site.customer_approve', 'site', v_row.id::text);
  return v_row.id;
end;
$$;

-- 하객 방명록 등록. 예외 대신 결과 코드를 돌려줘 레이트 리밋 카운트가 롤백되지 않게 한다.
-- result: ok | closed | invalid | spam | rate_limited
create or replace function microweb.submit_guestbook_entry(
  p_slug        text,
  p_author_name text,
  p_body        text,
  p_relation    text,
  p_ai_assisted boolean,
  p_ip_hash     text
)
returns table (entry_id uuid, result text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_site    microweb.sites;
  v_name    text := btrim(coalesce(p_author_name, ''));
  v_body    text := btrim(coalesce(p_body, ''));
  v_allowed boolean;
  v_id      uuid;
begin
  if not core.is_privileged_session() then
    raise exception 'submit_guestbook_entry: service_role only' using errcode = '42501';
  end if;
  if p_ip_hash is null or char_length(p_ip_hash) < 16 then
    return query select null::uuid, 'invalid'::text; return;
  end if;
  select s.* into v_site
  from microweb.site_publications p join microweb.sites s on s.id = p.site_id
  where p.slug = lower(btrim(coalesce(p_slug, ''))) and p.is_live and p.expires_at > now();
  if not found or not v_site.guestbook_enabled then
    return query select null::uuid, 'closed'::text; return;
  end if;
  select r.allowed into v_allowed from core.rate_limit_hit('microweb:guestbook:ip:' || p_ip_hash || ':' || v_site.id::text, 3, 600) r;
  if not v_allowed then
    return query select null::uuid, 'rate_limited'::text; return;
  end if;
  select r.allowed into v_allowed from core.rate_limit_hit('microweb:guestbook:site:' || v_site.id::text, 500, 86400) r;
  if not v_allowed then
    return query select null::uuid, 'rate_limited'::text; return;
  end if;
  if char_length(v_name) not between 1 and 20 or char_length(v_body) not between 1 and 500
     or (p_relation is not null and p_relation not in ('friend', 'colleague', 'family', 'acquaintance', 'other')) then
    return query select null::uuid, 'invalid'::text; return;
  end if;
  if v_body ~* '(https?://|www\.)' or v_name ~* '(https?://|www\.)'
     or exists (select 1 from microweb.guestbook_entries g
                where g.site_id = v_site.id and g.ip_hash = p_ip_hash and g.body = v_body
                  and g.created_at > now() - interval '1 hour') then
    return query select null::uuid, 'spam'::text; return;
  end if;
  insert into microweb.guestbook_entries (org_id, site_id, author_name, body, relation, ai_assisted, ip_hash)
  values (v_site.org_id, v_site.id, v_name, v_body, p_relation, coalesce(p_ai_assisted, false), p_ip_hash)
  returning id into v_id;
  return query select v_id, 'ok'::text;
end;
$$;

-- 참석 여부 등록. result: ok | closed | invalid | rate_limited
create or replace function microweb.submit_rsvp(
  p_slug       text,
  p_guest_name text,
  p_side       text,
  p_attending  text,
  p_party_size integer,
  p_meal       text,
  p_message    text,
  p_ip_hash    text
)
returns table (rsvp_id uuid, result text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_site    microweb.sites;
  v_name    text := btrim(coalesce(p_guest_name, ''));
  v_allowed boolean;
  v_id      uuid;
begin
  if not core.is_privileged_session() then
    raise exception 'submit_rsvp: service_role only' using errcode = '42501';
  end if;
  if p_ip_hash is null or char_length(p_ip_hash) < 16 then
    return query select null::uuid, 'invalid'::text; return;
  end if;
  select s.* into v_site
  from microweb.site_publications p join microweb.sites s on s.id = p.site_id
  where p.slug = lower(btrim(coalesce(p_slug, ''))) and p.is_live and p.expires_at > now();
  if not found or not v_site.rsvp_enabled or (v_site.event_at is not null and v_site.event_at <= now()) then
    return query select null::uuid, 'closed'::text; return;
  end if;
  select r.allowed into v_allowed from core.rate_limit_hit('microweb:rsvp:ip:' || p_ip_hash || ':' || v_site.id::text, 5, 3600) r;
  if not v_allowed then
    return query select null::uuid, 'rate_limited'::text; return;
  end if;
  select r.allowed into v_allowed from core.rate_limit_hit('microweb:rsvp:site:' || v_site.id::text, 2000, 86400) r;
  if not v_allowed then
    return query select null::uuid, 'rate_limited'::text; return;
  end if;
  if char_length(v_name) not between 1 and 20
     or coalesce(p_side, 'none') not in ('side_a', 'side_b', 'none')
     or coalesce(p_attending, '') not in ('yes', 'no', 'undecided')
     or coalesce(p_party_size, 1) not between 1 and 10
     or (p_meal is not null and p_meal not in ('yes', 'no', 'undecided'))
     or (p_message is not null and char_length(p_message) > 200) then
    return query select null::uuid, 'invalid'::text; return;
  end if;
  insert into microweb.rsvp_responses (org_id, site_id, guest_name, side, attending, party_size, meal, message, ip_hash)
  values (v_site.org_id, v_site.id, v_name, coalesce(p_side, 'none'), p_attending, coalesce(p_party_size, 1), p_meal,
          nullif(btrim(coalesce(p_message, '')), ''), p_ip_hash)
  returning id into v_id;
  return query select v_id, 'ok'::text;
end;
$$;

-- 견적 문의 접수(공개 /contact). 개인정보 수집 동의 필수. result: ok | closed | invalid | spam | rate_limited
create or replace function microweb.create_lead(
  p_org_id          uuid,
  p_source          text,
  p_name            text,
  p_phone           text,
  p_email           text,
  p_kind            text,
  p_template_code   text,
  p_tier            text,
  p_industry        text,
  p_event_on        date,
  p_simulator       jsonb,
  p_message         text,
  p_privacy_consent boolean,
  p_ip_hash         text
)
returns table (lead_id uuid, result text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
  v_id      uuid;
begin
  if not core.is_privileged_session() then
    raise exception 'create_lead: service_role only' using errcode = '42501';
  end if;
  if not exists (select 1 from microweb.studio_access a where a.org_id = p_org_id and a.revoked_at is null and a.mode = 'agency') then
    return query select null::uuid, 'closed'::text; return;
  end if;
  if p_ip_hash is null or char_length(p_ip_hash) < 16 or coalesce(p_privacy_consent, false) is false then
    return query select null::uuid, 'invalid'::text; return;
  end if;
  select r.allowed into v_allowed from core.rate_limit_hit('microweb:lead:ip:' || p_ip_hash, 3, 600) r;
  if not v_allowed then
    return query select null::uuid, 'rate_limited'::text; return;
  end if;
  select r.allowed into v_allowed from core.rate_limit_hit('microweb:lead:org:' || p_org_id::text, 300, 86400) r;
  if not v_allowed then
    return query select null::uuid, 'rate_limited'::text; return;
  end if;
  if coalesce(p_message, '') ~* '(https?://|www\.).*(https?://|www\.).*(https?://|www\.)' then
    return query select null::uuid, 'spam'::text; return;
  end if;
  begin
    insert into microweb.leads (org_id, source, name, phone, email, kind, template_code, tier, industry, event_on,
                                simulator, message, privacy_consent_at, ip_hash)
    values (p_org_id, coalesce(p_source, 'contact_form'), btrim(coalesce(p_name, '')), nullif(btrim(coalesce(p_phone, '')), ''),
            nullif(lower(btrim(coalesce(p_email, ''))), ''), p_kind, p_template_code, p_tier, p_industry, p_event_on,
            coalesce(p_simulator, '{}'::jsonb), nullif(btrim(coalesce(p_message, '')), ''), now(), p_ip_hash)
    returning id into v_id;
  exception when check_violation or not_null_violation then
    return query select null::uuid, 'invalid'::text; return;
  end;
  return query select v_id, 'ok'::text;
end;
$$;

-- 만료 처리(pg_cron 또는 워커, 매 10분). 만료된 사이트 id 를 돌려주면 워커가 공개 파생본 삭제 잡을 넣는다.
-- 30분 넘게 publishing 에 머문 사이트는 fail_publish 로 되돌린다.
create or replace function microweb.expire_sites()
returns setof uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_site record;
begin
  if not core.is_privileged_session() then
    raise exception 'expire_sites: service_role only' using errcode = '42501';
  end if;
  for v_site in
    select id, org_id from microweb.sites
    where status in ('published', 'unpublished') and expires_at <= now()
    for update skip locked
  loop
    update microweb.sites set status = 'expired', expired_at = now() where id = v_site.id;
    update microweb.site_publications set is_live = false, unpublished_at = coalesce(unpublished_at, now()) where site_id = v_site.id;
    perform core.write_audit(v_site.org_id, 'site.expired', 'site', v_site.id::text);
    return next v_site.id;
  end loop;
  for v_site in
    select id from microweb.sites
    where status = 'publishing' and publish_requested_at < now() - interval '30 minutes'
    for update skip locked
  loop
    perform microweb.fail_publish(v_site.id, 'stale publishing (30 min)');
  end loop;
  return;
end;
$$;

-- 보존 기간 경과 데이터 삭제(매일). 견적 문의 purge_after, 만료 180일/보관 30일 지난 사이트의 하객 데이터.
create or replace function microweb.purge_expired_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_leads integer;
  v_guestbook integer;
  v_rsvp integer;
begin
  if not core.is_privileged_session() then
    raise exception 'purge_expired_data: service_role only' using errcode = '42501';
  end if;
  delete from microweb.leads where purge_after < now();
  get diagnostics v_leads = row_count;
  delete from microweb.guestbook_entries g using microweb.sites s
  where g.site_id = s.id
    and ((s.status = 'expired' and s.expired_at < now() - interval '180 days')
      or (s.status = 'archived' and s.archived_at < now() - interval '30 days'));
  get diagnostics v_guestbook = row_count;
  delete from microweb.rsvp_responses r using microweb.sites s
  where r.site_id = s.id
    and ((s.status = 'expired' and s.expired_at < now() - interval '180 days')
      or (s.status = 'archived' and s.archived_at < now() - interval '30 days'));
  get diagnostics v_rsvp = row_count;
  return jsonb_build_object('leads', v_leads, 'guestbook', v_guestbook, 'rsvp', v_rsvp);
end;
$$;


-- ---------------------------------------------------------------------
-- 17. RLS 와 GRANT (모든 표 RLS ON. 기본 회수 후 허용 목록만)
-- ---------------------------------------------------------------------
alter table microweb.templates         enable row level security;
alter table microweb.portfolio_items   enable row level security;
alter table microweb.studio_access     enable row level security;
alter table microweb.sites             enable row level security;
alter table microweb.site_publications enable row level security;
alter table microweb.site_assets       enable row level security;
alter table microweb.guestbook_entries enable row level security;
alter table microweb.rsvp_responses    enable row level security;
alter table microweb.leads             enable row level security;
alter table microweb.production_orders enable row level security;

revoke all on table microweb.templates, microweb.portfolio_items, microweb.studio_access, microweb.sites,
  microweb.site_publications, microweb.site_assets, microweb.guestbook_entries, microweb.rsvp_responses,
  microweb.leads, microweb.production_orders from public, anon, authenticated;
grant all on table microweb.templates, microweb.portfolio_items, microweb.studio_access, microweb.sites,
  microweb.site_publications, microweb.site_assets, microweb.guestbook_entries, microweb.rsvp_responses,
  microweb.leads, microweb.production_orders to service_role;

-- 카탈로그(공개)
grant select on microweb.templates to anon, authenticated;
drop policy if exists templates_select on microweb.templates;
create policy templates_select on microweb.templates for select to anon, authenticated
  using (status <> 'retired');

grant select on microweb.portfolio_items to anon, authenticated;
drop policy if exists portfolio_items_select on microweb.portfolio_items;
create policy portfolio_items_select on microweb.portfolio_items for select to anon, authenticated
  using (status = 'published');

-- 스튜디오 접근(자기 조직만, 읽기 전용)
grant select on microweb.studio_access to authenticated;
drop policy if exists studio_access_select on microweb.studio_access;
create policy studio_access_select on microweb.studio_access for select to authenticated
  using (core.is_org_member(org_id));

-- sites: 읽기는 스튜디오 멤버. 편집은 콘텐츠 컬럼만(상태, 게시, 동의, 과금 컬럼은 RPC 전용)
grant select on microweb.sites to authenticated;
grant update (title, content, event_at, expires_at, slug, guestbook_enabled, rsvp_enabled, ai_greeting_enabled)
  on microweb.sites to authenticated;
drop policy if exists sites_select on microweb.sites;
create policy sites_select on microweb.sites for select to authenticated
  using (microweb.has_studio_access(org_id));
drop policy if exists sites_update on microweb.sites;
create policy sites_update on microweb.sites for update to authenticated
  using (microweb.has_studio_access(org_id) and core.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (microweb.has_studio_access(org_id) and core.has_org_role(org_id, array['owner', 'admin', 'member']));

-- 공개 스냅샷: anon 은 게시 중인 행의 공개 컬럼만. 멤버는 자기 조직 행 전체.
grant select (site_id, slug, version, content, og_title, og_description, og_image_url, published_at, expires_at)
  on microweb.site_publications to anon;
grant select on microweb.site_publications to authenticated;
drop policy if exists site_publications_select_public on microweb.site_publications;
create policy site_publications_select_public on microweb.site_publications for select to anon, authenticated
  using (is_live and expires_at > now());
drop policy if exists site_publications_select_member on microweb.site_publications;
create policy site_publications_select_member on microweb.site_publications for select to authenticated
  using (microweb.has_studio_access(org_id));

-- 자산: 멤버 읽기, 캡션/순서만 편집. INSERT/DELETE 는 서버(service_role)가 Storage 와 함께 처리.
grant select on microweb.site_assets to authenticated;
grant update (caption, sort_order) on microweb.site_assets to authenticated;
drop policy if exists site_assets_select on microweb.site_assets;
create policy site_assets_select on microweb.site_assets for select to authenticated
  using (microweb.has_studio_access(org_id));
drop policy if exists site_assets_update on microweb.site_assets;
create policy site_assets_update on microweb.site_assets for update to authenticated
  using (microweb.has_studio_access(org_id) and core.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (microweb.has_studio_access(org_id) and core.has_org_role(org_id, array['owner', 'admin', 'member']));

-- 방명록: 공개 컬럼(ip_hash 제외)만. 게시 중 + 방명록 켜짐 + visible 만 공개. 삭제는 owner/admin.
grant select (id, site_id, author_name, body, relation, ai_assisted, created_at) on microweb.guestbook_entries to anon;
grant select (id, org_id, site_id, author_name, body, relation, ai_assisted, status, moderated_at, created_at)
  on microweb.guestbook_entries to authenticated;
grant delete on microweb.guestbook_entries to authenticated;
drop policy if exists guestbook_entries_select_public on microweb.guestbook_entries;
create policy guestbook_entries_select_public on microweb.guestbook_entries for select to anon, authenticated
  using (status = 'visible' and microweb.is_guestbook_public(site_id));
drop policy if exists guestbook_entries_select_member on microweb.guestbook_entries;
create policy guestbook_entries_select_member on microweb.guestbook_entries for select to authenticated
  using (microweb.has_studio_access(org_id));
drop policy if exists guestbook_entries_delete on microweb.guestbook_entries;
create policy guestbook_entries_delete on microweb.guestbook_entries for delete to authenticated
  using (microweb.has_studio_access(org_id) and core.has_org_role(org_id, array['owner', 'admin']));

-- RSVP: 공개 읽기 없음. 멤버 읽기(ip_hash 제외), 삭제는 owner/admin.
grant select (id, org_id, site_id, guest_name, side, attending, party_size, meal, message, created_at)
  on microweb.rsvp_responses to authenticated;
grant delete on microweb.rsvp_responses to authenticated;
drop policy if exists rsvp_responses_select on microweb.rsvp_responses;
create policy rsvp_responses_select on microweb.rsvp_responses for select to authenticated
  using (microweb.has_studio_access(org_id));
drop policy if exists rsvp_responses_delete on microweb.rsvp_responses;
create policy rsvp_responses_delete on microweb.rsvp_responses for delete to authenticated
  using (microweb.has_studio_access(org_id) and core.has_org_role(org_id, array['owner', 'admin']));

-- 견적 문의: 멤버 읽기(ip_hash 제외). 상태 변경/삭제는 RPC.
grant select (id, org_id, source, name, phone, email, kind, template_code, tier, industry, event_on, simulator, message,
              privacy_consent_at, status, status_note, contacted_at, closed_at, purge_after, created_at, updated_at)
  on microweb.leads to authenticated;
drop policy if exists leads_select on microweb.leads;
create policy leads_select on microweb.leads for select to authenticated
  using (microweb.has_studio_access(org_id));

-- 제작 주문: 멤버 읽기. 쓰기는 RPC.
grant select on microweb.production_orders to authenticated;
drop policy if exists production_orders_select on microweb.production_orders;
create policy production_orders_select on microweb.production_orders for select to authenticated
  using (microweb.has_studio_access(org_id));


-- ---------------------------------------------------------------------
-- 18. 함수 EXECUTE 정리
-- ---------------------------------------------------------------------
revoke all on function microweb.sites_status_transition() from public, anon, authenticated;
revoke all on function microweb.sites_guard_edit() from public, anon, authenticated;
revoke all on function microweb.sites_sync_publication() from public, anon, authenticated;
revoke all on function microweb.leads_status_transition() from public, anon, authenticated;
revoke all on function microweb.production_orders_status_transition() from public, anon, authenticated;
revoke all on function microweb.require_org_role(uuid, text[], text) from public, anon, authenticated;

-- 정책 헬퍼
revoke all on function microweb.has_studio_access(uuid) from public, anon, authenticated;
grant execute on function microweb.has_studio_access(uuid) to authenticated, service_role;
revoke all on function microweb.is_site_live(uuid) from public, anon, authenticated;
grant execute on function microweb.is_site_live(uuid) to anon, authenticated, service_role;
revoke all on function microweb.is_guestbook_public(uuid) from public, anon, authenticated;
grant execute on function microweb.is_guestbook_public(uuid) to anon, authenticated, service_role;

-- 사용자 RPC
revoke all on function microweb.create_site(uuid, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function microweb.create_site(uuid, text, text, text, timestamptz) to authenticated, service_role;
revoke all on function microweb.transition_site(uuid, text, text) from public, anon, authenticated;
grant execute on function microweb.transition_site(uuid, text, text) to authenticated, service_role;
revoke all on function microweb.issue_preview_token(uuid, integer) from public, anon, authenticated;
grant execute on function microweb.issue_preview_token(uuid, integer) to authenticated, service_role;
revoke all on function microweb.confirm_disclosure_consent(uuid, text) from public, anon, authenticated;
grant execute on function microweb.confirm_disclosure_consent(uuid, text) to authenticated, service_role;
revoke all on function microweb.moderate_guestbook_entry(uuid, text) from public, anon, authenticated;
grant execute on function microweb.moderate_guestbook_entry(uuid, text) to authenticated, service_role;
revoke all on function microweb.set_lead_status(uuid, text, text) from public, anon, authenticated;
grant execute on function microweb.set_lead_status(uuid, text, text) to authenticated, service_role;
revoke all on function microweb.delete_lead(uuid) from public, anon, authenticated;
grant execute on function microweb.delete_lead(uuid) to authenticated, service_role;
revoke all on function microweb.create_order(uuid, text, integer, text, text, uuid, uuid, text) from public, anon, authenticated;
grant execute on function microweb.create_order(uuid, text, integer, text, text, uuid, uuid, text) to authenticated, service_role;
revoke all on function microweb.transition_order(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function microweb.transition_order(uuid, text, text, text, text) to authenticated, service_role;
revoke all on function microweb.attach_order_site(uuid, uuid) from public, anon, authenticated;
grant execute on function microweb.attach_order_site(uuid, uuid) to authenticated, service_role;

-- service_role 전용
revoke all on function microweb.request_publish(uuid, uuid, bigint) from public, anon, authenticated;
grant execute on function microweb.request_publish(uuid, uuid, bigint) to service_role;
revoke all on function microweb.finalize_publish(uuid, uuid, jsonb, text, text, text) from public, anon, authenticated;
grant execute on function microweb.finalize_publish(uuid, uuid, jsonb, text, text, text) to service_role;
revoke all on function microweb.fail_publish(uuid, text) from public, anon, authenticated;
grant execute on function microweb.fail_publish(uuid, text) to service_role;
revoke all on function microweb.record_customer_approval(text, text) from public, anon, authenticated;
grant execute on function microweb.record_customer_approval(text, text) to service_role;
revoke all on function microweb.submit_guestbook_entry(text, text, text, text, boolean, text) from public, anon, authenticated;
grant execute on function microweb.submit_guestbook_entry(text, text, text, text, boolean, text) to service_role;
revoke all on function microweb.submit_rsvp(text, text, text, text, integer, text, text, text) from public, anon, authenticated;
grant execute on function microweb.submit_rsvp(text, text, text, text, integer, text, text, text) to service_role;
revoke all on function microweb.create_lead(uuid, text, text, text, text, text, text, text, text, date, jsonb, text, boolean, text) from public, anon, authenticated;
grant execute on function microweb.create_lead(uuid, text, text, text, text, text, text, text, text, date, jsonb, text, boolean, text) to service_role;
revoke all on function microweb.expire_sites() from public, anon, authenticated;
grant execute on function microweb.expire_sites() to service_role;
revoke all on function microweb.purge_expired_data() from public, anon, authenticated;
grant execute on function microweb.purge_expired_data() to service_role;

-- 전역 기본 PUBLIC EXECUTE 회수(alter default privileges 로는 지워지지 않는다. core 0007 과 같은 규칙).
-- 위에서 준 anon/authenticated/service_role 권한은 PUBLIC 과 별개라 유지된다.
revoke execute on all functions in schema microweb from public;


-- ---------------------------------------------------------------------
-- 19. 템플릿 카탈로그 기준 데이터 (nexus-micro-web-builder/frontend/data/models.ts 12개 모델)
--     가격대는 원본 기획값(대행가). self_publish_credits 는 01_PRD 4장 제안값.
-- ---------------------------------------------------------------------
insert into microweb.templates (code, kind, name, summary, status, release_phase, agency_price_min_krw, agency_price_max_krw,
                                price_note, self_publish_credits, allowed_blocks, required_blocks, sort_order)
values
  ('wedding_classic', 'wedding', '모바일 청첩장', '사진, 인사말, 달력, 오시는 길, 연락처와 계좌, 방명록을 담는 예식 안내 페이지', 'beta', 'mvp',
   80000, 250000, '기본 80,000원, 풀커스텀 250,000원', 30,
   array['hero', 'greeting', 'hosts', 'calendar', 'gallery', 'location', 'transport', 'contacts', 'accounts', 'wreath', 'guestbook', 'rsvp', 'bgm', 'notice', 'share'],
   array['hero', 'greeting', 'calendar', 'location', 'share'], 0),
  ('dol_basic', 'dol', '모바일 돌잔치 초대장', '아이 사진, 성장 타임라인, 일시와 장소 안내', 'planned', 'phase2',
   40000, 100000, '평균 50,000원, 패키지 100,000원', 20,
   array['hero', 'greeting', 'timeline', 'calendar', 'gallery', 'location', 'transport', 'contacts', 'accounts', 'guestbook', 'rsvp', 'bgm', 'notice', 'share'],
   array['hero', 'greeting', 'calendar', 'location', 'share'], 1),
  ('obituary_basic', 'obituary', '모바일 부고장', '고인 안내, 빈소와 발인 정보, 조의금 계좌', 'planned', 'phase2',
   30000, 60000, '건당 30,000원', 10,
   array['memorial', 'funeral_info', 'location', 'transport', 'contacts', 'accounts', 'guestbook', 'notice', 'share'],
   array['memorial', 'funeral_info', 'location', 'share'], 2),
  ('mini_home', 'mini_home', '소상공인 미니 홈피', '영업 정보, 메뉴/서비스, 예약과 문의 버튼', 'planned', 'phase3',
   200000, 600000, '구축 300,000원, 관리 월 30,000원', null, '{}', '{}', 3),
  ('event_notice', 'event', '행사/세미나 안내장', '행사 일정, 장소, 사전 등록 안내', 'planned', 'phase3',
   150000, 400000, '단건 200,000원', null, '{}', '{}', 4),
  ('business_card', 'business_card', '디지털 명함', '연락처와 링크를 모은 개인 페이지', 'planned', 'backlog',
   null, null, '개인 월 4,900원, 기업형 별도', null, '{}', '{}', 5),
  ('real_estate', 'real_estate', '부동산 모바일 전단', '매물 소개와 문의', 'planned', 'backlog',
   100000, 300000, '매물당 100,000원', null, '{}', '{}', 6),
  ('freelancer_portfolio', 'portfolio', '프리랜서 포트폴리오', '작업 사례와 연락처', 'planned', 'backlog',
   150000, 450000, '기본 200,000원, 커스텀 450,000원', null, '{}', '{}', 7),
  ('rolling_paper', 'rolling_paper', '온라인 롤링페이퍼', '여러 사람이 남기는 축하 메시지 모음', 'planned', 'backlog',
   0, 9900, '무료, 테마 9,900원', null, '{}', '{}', 8),
  ('qr_menu', 'qr_menu', '모바일 메뉴판(QR)', '매장 메뉴와 가격', 'planned', 'backlog',
   null, null, '세팅 150,000원, 월 15,000원', null, '{}', '{}', 9),
  ('pet_profile', 'pet_profile', '반려동물 QR 프로필', '보호자 연락처와 건강 정보', 'planned', 'backlog',
   25000, 45000, '단건 30,000원', null, '{}', '{}', 10),
  ('online_gallery', 'gallery', '온라인 전시/갤러리', '작품 소개와 도슨트', 'planned', 'backlog',
   300000, 1000000, '기본 400,000원', null, '{}', '{}', 11)
on conflict (code) do nothing;
