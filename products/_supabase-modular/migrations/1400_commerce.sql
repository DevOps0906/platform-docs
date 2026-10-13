-- =====================================================================
-- 1400_commerce.sql
-- nomad-commerce(NOMAD Commerce) 도메인: 소싱 → 상품DB → AI 상세페이지(슬롯) → 마켓 변환·업로드, 엑셀/ZIP 내보내기.
-- 선행: core 0000~0006, seed.sql (core.apps 'commerce' 행과 플랜)
-- 정본 문서: docs/products/nomad-commerce/05_DATA_MODEL.md
--
-- 원칙 (SECURITY_BASELINE.md, DB_CONVENTIONS.md)
--   - 모든 테넌트 테이블은 org_id + RLS. SELECT 는 is_org_member + has_entitlement('commerce').
--   - 사용자(authenticated) 쓰기는 순수 콘텐츠 테이블(products, shipping_templates, listing_drafts, banned_words)만,
--     컬럼 단위 GRANT + with check. 돈/한도/상태/외부 발행 결과 테이블은 SELECT 만 + guard_privileged_write.
--   - 플랜 한도(상품 수, 마켓 계정 슬롯, 마켓 API 허용, 엑셀 내보내기)는 트리거가 DB 에서 강제한다(리뷰 V2 #2).
--   - 상세페이지 compliance FAIL/미확인 WARN 은 market_uploads INSERT 단계에서 DB 가 막는다.
--   - 마켓 API 키는 core.encrypted_credentials 에만. 이 스키마에 비밀값 컬럼이 없다(리뷰 V2 #3, CM #3).
--   - 사용자 EXECUTE 를 연 DEFINER 함수는 core.is_service_caller() + has_org_role 만 쓴다(규칙 1, 2).
-- SQLSTATE: CM001 상태 전이 위반, CM002 상품 수 한도, CM003 마켓 계정 슬롯 한도, CM004 compliance FAIL,
--           CM005 WARN 미확인, CM006 마켓 계정 무효, CM007 플랜 미허용 기능, CM008 상세페이지 미완료, CM009 확인할 WARN 없음
-- 모놀리스 변환: docs/products/nomad-commerce/supabase/monolith/migrations/0002_commerce_domain.sql
--   (HEADER 블록 제거, core. → public., commerce. → public., schemaname 'commerce' → 'public')
-- 반복 실행 가능.
-- =====================================================================

-- @@HEADER_BEGIN (모놀리스 변환 시 이 블록은 제거된다)
create schema if not exists commerce;
comment on schema commerce is 'NOMAD Commerce: 소싱, 상품DB, AI 상세페이지, 마켓 업로드';
grant usage on schema commerce to anon, authenticated, service_role;
alter default privileges in schema commerce grant all on tables to service_role;
alter default privileges in schema commerce grant all on sequences to service_role;
alter default privileges in schema commerce grant execute on functions to service_role;
alter default privileges in schema commerce revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy) values ('commerce', 'NOMAD Commerce', 'commerce', 'open')
on conflict (id) do nothing;
-- @@HEADER_END


-- =====================================================================
-- 1. 헬퍼: 플랜 기능 플래그, 상태 전이 표, 공용 트리거
-- =====================================================================

-- 조직의 commerce 엔타이틀먼트 플랜 features. 엔타이틀먼트가 없으면 '{}'.
create or replace function commerce.commerce_features(p_org_id uuid)
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
    where e.org_id = p_org_id and e.app_id = 'commerce' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  ), '{}'::jsonb);
$$;

-- 숫자 한도. 키가 없으면 p_default, -1 은 무제한.
create or replace function commerce.commerce_limit(p_org_id uuid, p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(commerce.commerce_features(p_org_id) ->> p_key, '')::integer, p_default);
$$;

-- 상태 전이 표. 초기 상태는 from = '' 로 표현한다. 05_DATA_MODEL.md 3장과 같다.
create or replace function commerce.commerce_transition_allowed(p_table text, p_from text, p_to text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (coalesce(p_from, '') || '>' || coalesce(p_to, '')) = any (
    case p_table
      when 'import_batches' then array[
        '>uploaded', 'uploaded>parsing', 'uploaded>failed', 'parsing>completed', 'parsing>failed']
      when 'detail_pages' then array[
        '>waiting', 'waiting>queued', 'waiting>canceled',
        'queued>generating', 'queued>canceled', 'queued>failed',
        'generating>ready', 'generating>failed', 'generating>canceled',
        'ready>archived', 'archived>ready', 'failed>waiting']
      when 'detail_page_slots' then array[
        '>pending', 'pending>generating', 'pending>skipped', 'pending>failed',
        'generating>completed', 'generating>failed', 'failed>generating', 'completed>generating']
      when 'listing_drafts' then array[
        '>draft', 'draft>ready', 'ready>draft', 'draft>archived', 'ready>archived', 'archived>draft']
      when 'market_uploads' then array[
        '>queued', 'queued>validating', 'queued>canceled', 'queued>failed',
        'validating>uploading', 'validating>failed',
        'uploading>submitted', 'uploading>failed',
        'submitted>approved', 'submitted>rejected', 'submitted>failed',
        'failed>queued', 'rejected>queued']
      when 'export_files' then array[
        '>queued', 'queued>running', 'queued>canceled', 'queued>failed',
        'running>succeeded', 'running>failed', 'succeeded>expired']
      else array[]::text[]
    end
  );
$$;

-- 범용 상태 전이 트리거. service_role 쓰기에도 적용된다(DB_CONVENTIONS.md 10장 (a)).
create or replace function commerce.commerce_status_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not commerce.commerce_transition_allowed(tg_table_name, '', new.status) then
      raise exception '%: invalid initial status %', tg_table_name, new.status using errcode = 'CM001';
    end if;
  elsif new.status is distinct from old.status then
    if not commerce.commerce_transition_allowed(tg_table_name, old.status, new.status) then
      raise exception '%: invalid transition % -> %', tg_table_name, old.status, new.status using errcode = 'CM001';
    end if;
  end if;
  return new;
end;
$$;

-- 사용자 세션이 만든 행의 created_by 를 auth.uid() 로 고정한다.
create or replace function commerce.commerce_stamp_creator()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 2. import_batches: 엑셀/아마존 가져오기 실행 단위 (서버 전용 쓰기)
-- =====================================================================
create table if not exists commerce.import_batches (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  source_type   text not null
                constraint import_batches_source_type_check check (source_type in ('excel', 'amazon')),
  supplier      text not null
                constraint import_batches_supplier_check check (supplier in ('amazon', 'ownerclan', 'domeggook', 'onchannel', 'amazon_csv', 'custom')),
  file_path     text,
  column_mapping jsonb not null default '{}'::jsonb,
  status        text not null default 'uploaded'
                constraint import_batches_status_check check (status in ('uploaded', 'parsing', 'completed', 'failed')),
  total_rows    integer not null default 0 constraint import_batches_total_rows_check check (total_rows >= 0),
  imported_rows integer not null default 0 constraint import_batches_imported_rows_check check (imported_rows >= 0),
  skipped_rows  integer not null default 0 constraint import_batches_skipped_rows_check check (skipped_rows >= 0),
  failed_rows   integer not null default 0 constraint import_batches_failed_rows_check check (failed_rows >= 0),
  errors        jsonb not null default '[]'::jsonb,
  job_id        uuid references core.jobs(id) on delete set null,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  finished_at   timestamptz,
  unique (org_id, id)
);
create index if not exists import_batches_org_created_idx on commerce.import_batches (org_id, created_at desc);


-- =====================================================================
-- 3. products: 상품DB (순수 콘텐츠. 사용자 쓰기 허용, 상품 수 한도는 트리거)
-- =====================================================================
create table if not exists commerce.products (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  source_type        text not null default 'manual'
                     constraint products_source_type_check check (source_type in ('manual', 'excel', 'amazon', 'url_benchmark')),
  source_supplier    text
                     constraint products_source_supplier_check check (source_supplier is null or source_supplier in ('amazon', 'ownerclan', 'domeggook', 'onchannel', 'amazon_csv', 'custom')),
  source_ref         text,
  source_url         text,
  import_batch_id    uuid,
  title              text not null constraint products_title_check check (char_length(title) between 1 and 300),
  title_original     text,
  title_optimized    text constraint products_title_optimized_check check (title_optimized is null or char_length(title_optimized) <= 100),
  brand              text,
  manufacturer       text,
  origin_country     text,
  model_code         text,
  category_path      text,
  is_health_food     boolean not null default false,
  health_food_status text not null default 'not_applicable'
                     constraint products_health_food_status_check check (health_food_status in ('not_applicable', 'certified_hff', 'general_food', 'unknown')),
  is_overseas        boolean not null default false,
  source_price       numeric(12, 2) constraint products_source_price_check check (source_price is null or source_price >= 0),
  source_currency    text constraint products_source_currency_check check (source_currency is null or source_currency in ('KRW', 'USD', 'CAD', 'EUR', 'JPY', 'CNY')),
  sell_price_krw     integer constraint products_sell_price_check check (sell_price_krw is null or (sell_price_krw >= 0 and sell_price_krw % 10 = 0)),
  list_price_krw     integer constraint products_list_price_check check (list_price_krw is null or list_price_krw >= 0),
  stock              integer not null default 999 constraint products_stock_check check (stock >= 0),
  images             jsonb not null default '[]'::jsonb constraint products_images_check check (jsonb_typeof(images) = 'array'),
  attributes         jsonb not null default '{}'::jsonb constraint products_attributes_check check (jsonb_typeof(attributes) = 'object'),
  tags               text[] not null default '{}',
  banned_words_found text[] not null default '{}',
  status             text not null default 'active'
                     constraint products_status_check check (status in ('active', 'archived')),
  created_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz,
  unique (org_id, id),
  constraint products_import_batch_fk foreign key (org_id, import_batch_id)
    references commerce.import_batches (org_id, id) on delete set null (import_batch_id)
);
create index if not exists products_org_created_idx on commerce.products (org_id, created_at desc) where deleted_at is null;
create unique index if not exists products_source_uniq on commerce.products (org_id, source_supplier, source_ref)
  where source_ref is not null and deleted_at is null;

-- 상품 수 한도(features.products). 동시 INSERT 경쟁은 조직 단위 advisory lock 으로 직렬화한다.
create or replace function commerce.products_enforce_quota()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
  v_count integer;
begin
  if tg_op = 'UPDATE' and not (old.deleted_at is not null and new.deleted_at is null) then
    return new;
  end if;
  if new.deleted_at is not null then
    return new;
  end if;
  if not core.has_entitlement(new.org_id, 'commerce') then
    raise exception 'products: organization has no commerce entitlement' using errcode = '42501';
  end if;
  v_limit := commerce.commerce_limit(new.org_id, 'products', 0);
  if v_limit < 0 then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('commerce:products:' || new.org_id::text));
  select count(*) into v_count from commerce.products p
  where p.org_id = new.org_id and p.deleted_at is null and p.id <> new.id;
  if v_count >= v_limit then
    raise exception 'products quota exceeded (%/%)', v_count, v_limit using errcode = 'CM002';
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 4. detail_pages: AI 상세페이지 (서버 전용 쓰기. 사용자는 WARN 확인 RPC 만)
-- =====================================================================
create table if not exists commerce.detail_pages (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null references core.organizations(id) on delete cascade,
  product_id            uuid not null,
  version               integer not null default 1 constraint detail_pages_version_check check (version >= 1),
  page_type             text not null
                        constraint detail_pages_page_type_check check (page_type in ('persuasive', 'informative', 'emotional', 'social_proof', 'story', 'comparison', 'promotion', 'bundle')),
  slot_set              smallint not null default 10 constraint detail_pages_slot_set_check check (slot_set in (10, 15)),
  slots                 text[] not null
                        constraint detail_pages_slots_check check (
                          slots <@ array['T-1','T-2','T-3','T-4','T-5','D-1','D-2','D-3','D-4','D-5','D-6','D-7','D-8','D-9','D-10','L-1','L-2','L-3']
                          and slots @> array['T-1','L-3']
                          and cardinality(slots) between 3 and 18),
  template              text not null default 'simple'
                        constraint detail_pages_template_check check (template in ('simple', 'health', 'overseas')),
  target_markets        text[] not null default array['coupang', 'smartstore']
                        constraint detail_pages_target_markets_check check (target_markets <@ array['coupang', 'smartstore', 'wadiz', 'street11', 'gmarket', 'auction', 'lotteon', 'cafe24', 'imweb']),
  options               jsonb not null default '{}'::jsonb,
  status                text not null default 'waiting'
                        constraint detail_pages_status_check check (status in ('waiting', 'queued', 'generating', 'ready', 'failed', 'canceled', 'archived')),
  progress              integer not null default 0 constraint detail_pages_progress_check check (progress between 0 and 100),
  current_phase         text
                        constraint detail_pages_phase_check check (current_phase is null or current_phase in ('prepare', 'storyline', 'copy', 'images', 'compose', 'verify', 'convert', 'assemble')),
  credits_charged       integer not null default 0 constraint detail_pages_credits_check check (credits_charged >= 0),
  credit_ledger_id      bigint references core.credit_ledger(id),
  job_id                uuid references core.jobs(id) on delete set null,
  request_id            uuid unique,
  copy                  jsonb not null default '{}'::jsonb,
  html_content          text,
  geo_jsonld            jsonb,
  compliance_verdict    text constraint detail_pages_verdict_check check (compliance_verdict is null or compliance_verdict in ('pass', 'warn', 'fail')),
  compliance_issues     jsonb not null default '[]'::jsonb,
  warn_acknowledged_at  timestamptz,
  warn_acknowledged_by  uuid,
  cancel_requested_at   timestamptz,
  error_code            text,
  error_message         text,
  created_by            uuid,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  started_at            timestamptz,
  finished_at           timestamptz,
  unique (org_id, id),
  constraint detail_pages_product_fk foreign key (org_id, product_id)
    references commerce.products (org_id, id) on delete cascade
);
create index if not exists detail_pages_org_created_idx on commerce.detail_pages (org_id, created_at desc);
create index if not exists detail_pages_product_idx on commerce.detail_pages (product_id, version desc);
create index if not exists detail_pages_waiting_idx on commerce.detail_pages (org_id, created_at) where status = 'waiting';


-- =====================================================================
-- 5. detail_page_slots: 슬롯 단위 생성 상태 (서버 전용 쓰기, Realtime)
-- =====================================================================
create table if not exists commerce.detail_page_slots (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  detail_page_id      uuid not null,
  slot_code           text not null
                      constraint detail_page_slots_code_check check (slot_code in ('T-1','T-2','T-3','T-4','T-5','D-1','D-2','D-3','D-4','D-5','D-6','D-7','D-8','D-9','D-10','L-1','L-2','L-3')),
  position            smallint not null constraint detail_page_slots_position_check check (position between 1 and 18),
  render_method       text not null
                      constraint detail_page_slots_render_check check (render_method in ('cutout', 'ai_scene', 'infographic', 'legal')),
  status              text not null default 'pending'
                      constraint detail_page_slots_status_check check (status in ('pending', 'generating', 'completed', 'failed', 'skipped')),
  copy_ko             text,
  image_prompt_en     text,
  template_data       jsonb not null default '{}'::jsonb,
  master_path         text,
  provider_request_id text unique,
  model               text,
  attempts            integer not null default 0 constraint detail_page_slots_attempts_check check (attempts >= 0),
  error_message       text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  completed_at        timestamptz,
  unique (detail_page_id, slot_code),
  constraint detail_page_slots_page_fk foreign key (org_id, detail_page_id)
    references commerce.detail_pages (org_id, id) on delete cascade
);
create index if not exists detail_page_slots_page_idx on commerce.detail_page_slots (detail_page_id, position);


-- =====================================================================
-- 6. market_images: 마켓별 변환본 (서버 전용 쓰기)
-- =====================================================================
create table if not exists commerce.market_images (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  detail_page_id uuid not null,
  slot_code      text not null,
  market         text not null
                 constraint market_images_market_check check (market in ('coupang', 'smartstore', 'wadiz', 'street11', 'gmarket', 'auction', 'lotteon', 'cafe24', 'imweb')),
  kind           text not null constraint market_images_kind_check check (kind in ('thumbnail', 'detail')),
  part_no        smallint not null default 1 constraint market_images_part_check check (part_no >= 1),
  storage_path   text not null,
  width          integer constraint market_images_width_check check (width is null or width > 0),
  height         integer constraint market_images_height_check check (height is null or height > 0),
  bytes          integer constraint market_images_bytes_check check (bytes is null or bytes > 0),
  format         text constraint market_images_format_check check (format is null or format in ('jpeg', 'png', 'gif', 'webp')),
  validation     jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  unique (detail_page_id, market, slot_code, kind, part_no),
  constraint market_images_page_fk foreign key (org_id, detail_page_id)
    references commerce.detail_pages (org_id, id) on delete cascade
);


-- =====================================================================
-- 7. market_accounts: 마켓 다계정 슬롯. 키는 core.encrypted_credentials 에만 (서버 전용 쓰기)
-- =====================================================================
create table if not exists commerce.market_accounts (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  market           text not null
                   constraint market_accounts_market_check check (market in ('coupang', 'smartstore', 'gmarket', 'auction', 'street11', 'lotteon', 'cafe24', 'imweb')),
  slot_no          smallint not null constraint market_accounts_slot_check check (slot_no >= 1),
  label            text not null constraint market_accounts_label_check check (char_length(label) between 1 and 40),
  credential_id    uuid references core.encrypted_credentials(id) on delete set null,
  vendor_id        text,
  status           text not null default 'active'
                   constraint market_accounts_status_check check (status in ('active', 'disabled', 'error')),
  last_verified_at timestamptz,
  last_error       text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (org_id, id),
  unique (org_id, market, slot_no)
);

-- 슬롯 한도(features.market_slots) + 자격증명이 같은 조직·commerce 앱 소유인지 검사.
create or replace function commerce.market_accounts_enforce()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
  v_count integer;
  v_cred_org uuid;
  v_cred_app text;
begin
  if new.credential_id is not null then
    select c.org_id, c.app_id into v_cred_org, v_cred_app from core.encrypted_credentials c where c.id = new.credential_id;
    if v_cred_org is distinct from new.org_id or coalesce(v_cred_app, '') <> 'commerce' then
      raise exception 'market_accounts: credential belongs to another org or app' using errcode = 'CM006';
    end if;
  end if;
  if new.status <> 'active' or (tg_op = 'UPDATE' and old.status = 'active') then
    return new;
  end if;
  v_limit := commerce.commerce_limit(new.org_id, 'market_slots', 1);
  if v_limit < 0 then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('commerce:market_slots:' || new.org_id::text));
  select count(*) into v_count from commerce.market_accounts a
  where a.org_id = new.org_id and a.status = 'active' and a.id <> new.id;
  if v_count >= v_limit then
    raise exception 'market slot quota exceeded (%/%)', v_count, v_limit using errcode = 'CM003';
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 8. shipping_templates: 배송·반품 템플릿 (순수 콘텐츠, 사용자 쓰기)
--    청약철회 7일 미만, 교환·반품 제한 사유의 임의 문구를 DB 가 거부한다(리뷰 V2 #6).
--    restriction_codes 는 전자상거래법 제17조 제2항 예외 사유에 대응하는 코드만 허용(법률 검토 필요, 01_PRD 6장).
-- =====================================================================
create table if not exists commerce.shipping_templates (
  id                       uuid primary key default gen_random_uuid(),
  org_id                   uuid not null references core.organizations(id) on delete cascade,
  name                     text not null constraint shipping_templates_name_check check (char_length(name) between 1 and 60),
  template_type            text not null default 'custom'
                           constraint shipping_templates_type_check check (template_type in ('overseas_purchase', 'domestic_dropship', 'custom')),
  shipping                 jsonb not null default '{}'::jsonb constraint shipping_templates_shipping_check check (jsonb_typeof(shipping) = 'object'),
  dispatch_days            smallint not null default 3 constraint shipping_templates_dispatch_check check (dispatch_days between 1 and 30),
  return_window_days       smallint not null default 7 constraint shipping_templates_return_window_check check (return_window_days between 7 and 90),
  exchange_allowed         boolean not null default true,
  return_fee_krw           integer constraint shipping_templates_return_fee_check check (return_fee_krw is null or return_fee_krw >= 0),
  initial_shipping_fee_krw integer constraint shipping_templates_initial_fee_check check (initial_shipping_fee_krw is null or initial_shipping_fee_krw >= 0),
  restriction_codes        text[] not null default '{}'
                           constraint shipping_templates_restrictions_check check (restriction_codes <@ array['buyer_damage', 'used_or_consumed', 'time_lapse_resale', 'copyable_opened']),
  return_address           jsonb not null default '{}'::jsonb,
  contact_phone            text,
  is_default               boolean not null default false,
  created_by               uuid,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (org_id, id)
);
create unique index if not exists shipping_templates_one_default_idx on commerce.shipping_templates (org_id) where is_default;


-- =====================================================================
-- 9. listing_drafts: 마켓 등록 폼(6-Step 를 2개 마켓 필드로 축소). 사용자는 콘텐츠 컬럼만 쓴다.
--    status 와 completeness 는 서버가 계산해서 쓴다.
-- =====================================================================
create table if not exists commerce.listing_drafts (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  product_id           uuid not null,
  detail_page_id       uuid,
  market               text not null
                       constraint listing_drafts_market_check check (market in ('coupang', 'smartstore', 'gmarket', 'auction', 'street11', 'lotteon', 'cafe24', 'imweb')),
  market_account_id    uuid,
  shipping_template_id uuid,
  category_code        text,
  category_path        text,
  display_name         text constraint listing_drafts_display_name_check check (display_name is null or char_length(display_name) <= 100),
  form_data            jsonb not null default '{}'::jsonb constraint listing_drafts_form_check check (jsonb_typeof(form_data) = 'object'),
  notice_info          jsonb not null default '{}'::jsonb constraint listing_drafts_notice_check check (jsonb_typeof(notice_info) = 'object'),
  completeness_pct     smallint not null default 0 constraint listing_drafts_completeness_check check (completeness_pct between 0 and 100),
  missing_fields       text[] not null default '{}',
  status               text not null default 'draft'
                       constraint listing_drafts_status_check check (status in ('draft', 'ready', 'archived')),
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (org_id, id),
  constraint listing_drafts_product_fk foreign key (org_id, product_id)
    references commerce.products (org_id, id) on delete cascade,
  constraint listing_drafts_detail_page_fk foreign key (org_id, detail_page_id)
    references commerce.detail_pages (org_id, id) on delete set null (detail_page_id),
  constraint listing_drafts_account_fk foreign key (org_id, market_account_id)
    references commerce.market_accounts (org_id, id) on delete set null (market_account_id),
  constraint listing_drafts_template_fk foreign key (org_id, shipping_template_id)
    references commerce.shipping_templates (org_id, id) on delete set null (shipping_template_id)
);
create index if not exists listing_drafts_org_updated_idx on commerce.listing_drafts (org_id, updated_at desc);
create unique index if not exists listing_drafts_product_account_uniq on commerce.listing_drafts (product_id, market_account_id)
  where market_account_id is not null and status <> 'archived';


-- =====================================================================
-- 10. market_uploads: 마켓 API 업로드 이력 (서버 전용 쓰기, 상태 전이 + 게이트 트리거)
-- =====================================================================
create table if not exists commerce.market_uploads (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  listing_draft_id  uuid,
  product_id        uuid,
  detail_page_id    uuid,
  market            text not null
                    constraint market_uploads_market_check check (market in ('coupang', 'smartstore', 'gmarket', 'auction', 'street11', 'lotteon', 'cafe24', 'imweb')),
  market_account_id uuid,
  job_id            uuid references core.jobs(id) on delete set null,
  status            text not null default 'queued'
                    constraint market_uploads_status_check check (status in ('queued', 'validating', 'uploading', 'submitted', 'approved', 'rejected', 'failed', 'canceled')),
  market_product_id text,
  market_url        text,
  request_snapshot  jsonb not null default '{}'::jsonb,
  response_summary  jsonb not null default '{}'::jsonb,
  error_code        text,
  error_message     text,
  attempts          integer not null default 0 constraint market_uploads_attempts_check check (attempts >= 0),
  idempotency_key   text unique,
  submitted_at      timestamptz,
  decided_at        timestamptz,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint market_uploads_draft_fk foreign key (org_id, listing_draft_id)
    references commerce.listing_drafts (org_id, id) on delete set null (listing_draft_id),
  constraint market_uploads_product_fk foreign key (org_id, product_id)
    references commerce.products (org_id, id) on delete set null (product_id),
  constraint market_uploads_detail_page_fk foreign key (org_id, detail_page_id)
    references commerce.detail_pages (org_id, id) on delete set null (detail_page_id),
  constraint market_uploads_account_fk foreign key (org_id, market_account_id)
    references commerce.market_accounts (org_id, id) on delete set null (market_account_id)
);
create index if not exists market_uploads_org_created_idx on commerce.market_uploads (org_id, created_at desc);
create index if not exists market_uploads_submitted_idx on commerce.market_uploads (updated_at) where status = 'submitted';
create unique index if not exists market_uploads_external_uniq on commerce.market_uploads (market_account_id, market_product_id)
  where market_product_id is not null;

-- 업로드 게이트: 계정 유효성, 플랜 마켓 API 허용, 상세페이지 완료, compliance FAIL 차단, WARN 확인 필수.
create or replace function commerce.market_uploads_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_acc  commerce.market_accounts;
  v_page commerce.detail_pages;
begin
  select * into v_acc from commerce.market_accounts a where a.id = new.market_account_id;
  if not found or v_acc.org_id <> new.org_id or v_acc.market <> new.market or v_acc.status <> 'active'
     or v_acc.credential_id is null then
    raise exception 'market_uploads: market account is not usable' using errcode = 'CM006';
  end if;
  if not coalesce(commerce.commerce_features(new.org_id) -> 'market_api' ? new.market, false) then
    raise exception 'market_uploads: plan does not allow % api upload', new.market using errcode = 'CM007';
  end if;
  if new.detail_page_id is not null then
    select * into v_page from commerce.detail_pages d where d.id = new.detail_page_id;
    if not found or v_page.status <> 'ready' then
      raise exception 'market_uploads: detail page is not ready' using errcode = 'CM008';
    end if;
    if coalesce(v_page.compliance_verdict, 'fail') = 'fail' then
      raise exception 'market_uploads: compliance verdict fail or missing' using errcode = 'CM004';
    end if;
    if v_page.compliance_verdict = 'warn' and v_page.warn_acknowledged_at is null then
      raise exception 'market_uploads: compliance warning not acknowledged' using errcode = 'CM005';
    end if;
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 11. export_files: 엑셀(플레이오토 호환)/ZIP 내보내기 (서버 전용 쓰기)
-- =====================================================================
create table if not exists commerce.export_files (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  kind            text not null constraint export_files_kind_check check (kind in ('excel_playauto', 'zip_images')),
  market          text not null default 'all'
                  constraint export_files_market_check check (market in ('coupang', 'smartstore', 'wadiz', 'street11', 'all')),
  product_ids     uuid[] not null default '{}',
  detail_page_ids uuid[] not null default '{}',
  status          text not null default 'queued'
                  constraint export_files_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled', 'expired')),
  storage_path    text,
  file_bytes      bigint constraint export_files_bytes_check check (file_bytes is null or file_bytes >= 0),
  row_count       integer,
  expires_at      timestamptz,
  job_id          uuid references core.jobs(id) on delete set null,
  error_message   text,
  created_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint export_files_size_check check (cardinality(product_ids) <= 500 and cardinality(detail_page_ids) <= 500)
);
create index if not exists export_files_org_created_idx on commerce.export_files (org_id, created_at desc);
create index if not exists export_files_expiry_idx on commerce.export_files (expires_at) where status = 'succeeded';

create or replace function commerce.export_files_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.kind = 'excel_playauto' and not coalesce((commerce.commerce_features(new.org_id) ->> 'excel_export')::boolean, false) then
    raise exception 'export_files: plan does not allow excel export' using errcode = 'CM007';
  end if;
  if new.kind = 'zip_images' and not coalesce((commerce.commerce_features(new.org_id) ->> 'zip_export')::boolean, true) then
    raise exception 'export_files: plan does not allow zip export' using errcode = 'CM007';
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 12. banned_words: 금지어 사전. org_id null = 제품 기본 사전(읽기 전용), org 행 = 조직 추가분(owner/admin 편집)
--     compliance 공용 모듈의 checkRules 에 주입된다(SHARED_MODULES.md 13장). 매칭은 한글 경계를 고려한 앱 코드가 한다.
-- =====================================================================
create table if not exists commerce.banned_words (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid references core.organizations(id) on delete cascade,
  word        text not null constraint banned_words_word_check check (char_length(btrim(word)) between 1 and 50),
  category    text not null default 'general'
              constraint banned_words_category_check check (category in ('health_food', 'cosmetics', 'medical', 'general')),
  match_mode  text not null default 'substring'
              constraint banned_words_match_check check (match_mode in ('substring', 'token')),
  severity    text not null default 'fail'
              constraint banned_words_severity_check check (severity in ('fail', 'warn')),
  replacement text,
  note        text,
  is_active   boolean not null default true,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index if not exists banned_words_global_uniq on commerce.banned_words (category, word) where org_id is null;
create unique index if not exists banned_words_org_uniq on commerce.banned_words (org_id, category, word) where org_id is not null;


-- =====================================================================
-- 13. 전역 캐시: exchange_rates(한국수출입은행 환율), market_categories(마켓 카테고리 트리). 서버 전용 쓰기, 로그인 사용자 읽기
-- =====================================================================
create table if not exists commerce.exchange_rates (
  id         bigint generated always as identity primary key,
  currency   text not null constraint exchange_rates_currency_check check (currency in ('USD', 'CAD', 'EUR', 'JPY', 'CNY')),
  unit       integer not null default 1 constraint exchange_rates_unit_check check (unit in (1, 100)),
  rate_krw   numeric(14, 4) not null constraint exchange_rates_rate_check check (rate_krw > 0),
  source     text not null default 'koreaexim',
  rate_date  date not null,
  fetched_at timestamptz not null default now(),
  unique (currency, rate_date)
);

create table if not exists commerce.market_categories (
  market        text not null constraint market_categories_market_check check (market in ('coupang', 'smartstore', 'gmarket', 'auction', 'street11', 'lotteon', 'cafe24', 'imweb')),
  category_code text not null,
  parent_code   text,
  name          text not null,
  path          text not null,
  depth         smallint not null default 1,
  is_leaf       boolean not null default false,
  notice_type   text,
  synced_at     timestamptz not null default now(),
  primary key (market, category_code)
);


-- =====================================================================
-- 14. 트리거 연결
-- =====================================================================
-- updated_at
drop trigger if exists import_batches_set_updated_at on commerce.import_batches;
create trigger import_batches_set_updated_at before update on commerce.import_batches for each row execute function core.set_updated_at();
drop trigger if exists products_set_updated_at on commerce.products;
create trigger products_set_updated_at before update on commerce.products for each row execute function core.set_updated_at();
drop trigger if exists detail_pages_set_updated_at on commerce.detail_pages;
create trigger detail_pages_set_updated_at before update on commerce.detail_pages for each row execute function core.set_updated_at();
drop trigger if exists detail_page_slots_set_updated_at on commerce.detail_page_slots;
create trigger detail_page_slots_set_updated_at before update on commerce.detail_page_slots for each row execute function core.set_updated_at();
drop trigger if exists market_accounts_set_updated_at on commerce.market_accounts;
create trigger market_accounts_set_updated_at before update on commerce.market_accounts for each row execute function core.set_updated_at();
drop trigger if exists shipping_templates_set_updated_at on commerce.shipping_templates;
create trigger shipping_templates_set_updated_at before update on commerce.shipping_templates for each row execute function core.set_updated_at();
drop trigger if exists listing_drafts_set_updated_at on commerce.listing_drafts;
create trigger listing_drafts_set_updated_at before update on commerce.listing_drafts for each row execute function core.set_updated_at();
drop trigger if exists market_uploads_set_updated_at on commerce.market_uploads;
create trigger market_uploads_set_updated_at before update on commerce.market_uploads for each row execute function core.set_updated_at();
drop trigger if exists export_files_set_updated_at on commerce.export_files;
create trigger export_files_set_updated_at before update on commerce.export_files for each row execute function core.set_updated_at();
drop trigger if exists banned_words_set_updated_at on commerce.banned_words;
create trigger banned_words_set_updated_at before update on commerce.banned_words for each row execute function core.set_updated_at();

-- 이중 잠금: 서버 전용 테이블은 사용자 세션 쓰기를 42501 로 거부
drop trigger if exists import_batches_guard_write on commerce.import_batches;
create trigger import_batches_guard_write before insert or update or delete on commerce.import_batches for each row execute function core.guard_privileged_write();
drop trigger if exists detail_pages_guard_write on commerce.detail_pages;
create trigger detail_pages_guard_write before insert or update or delete on commerce.detail_pages for each row execute function core.guard_privileged_write();
drop trigger if exists detail_page_slots_guard_write on commerce.detail_page_slots;
create trigger detail_page_slots_guard_write before insert or update or delete on commerce.detail_page_slots for each row execute function core.guard_privileged_write();
drop trigger if exists market_images_guard_write on commerce.market_images;
create trigger market_images_guard_write before insert or update or delete on commerce.market_images for each row execute function core.guard_privileged_write();
drop trigger if exists market_accounts_guard_write on commerce.market_accounts;
create trigger market_accounts_guard_write before insert or update or delete on commerce.market_accounts for each row execute function core.guard_privileged_write();
drop trigger if exists market_uploads_guard_write on commerce.market_uploads;
create trigger market_uploads_guard_write before insert or update or delete on commerce.market_uploads for each row execute function core.guard_privileged_write();
drop trigger if exists export_files_guard_write on commerce.export_files;
create trigger export_files_guard_write before insert or update or delete on commerce.export_files for each row execute function core.guard_privileged_write();
drop trigger if exists exchange_rates_guard_write on commerce.exchange_rates;
create trigger exchange_rates_guard_write before insert or update or delete on commerce.exchange_rates for each row execute function core.guard_privileged_write();
drop trigger if exists market_categories_guard_write on commerce.market_categories;
create trigger market_categories_guard_write before insert or update or delete on commerce.market_categories for each row execute function core.guard_privileged_write();

-- 상태 전이
drop trigger if exists import_batches_status_guard on commerce.import_batches;
create trigger import_batches_status_guard before insert or update of status on commerce.import_batches for each row execute function commerce.commerce_status_guard();
drop trigger if exists detail_pages_status_guard on commerce.detail_pages;
create trigger detail_pages_status_guard before insert or update of status on commerce.detail_pages for each row execute function commerce.commerce_status_guard();
drop trigger if exists detail_page_slots_status_guard on commerce.detail_page_slots;
create trigger detail_page_slots_status_guard before insert or update of status on commerce.detail_page_slots for each row execute function commerce.commerce_status_guard();
drop trigger if exists listing_drafts_status_guard on commerce.listing_drafts;
create trigger listing_drafts_status_guard before insert or update of status on commerce.listing_drafts for each row execute function commerce.commerce_status_guard();
drop trigger if exists market_uploads_status_guard on commerce.market_uploads;
create trigger market_uploads_status_guard before insert or update of status on commerce.market_uploads for each row execute function commerce.commerce_status_guard();
drop trigger if exists export_files_status_guard on commerce.export_files;
create trigger export_files_status_guard before insert or update of status on commerce.export_files for each row execute function commerce.commerce_status_guard();

-- 한도와 게이트
drop trigger if exists products_enforce_quota on commerce.products;
create trigger products_enforce_quota before insert or update of deleted_at on commerce.products for each row execute function commerce.products_enforce_quota();
drop trigger if exists market_accounts_enforce on commerce.market_accounts;
create trigger market_accounts_enforce before insert or update of status, credential_id on commerce.market_accounts for each row execute function commerce.market_accounts_enforce();
drop trigger if exists market_uploads_gate on commerce.market_uploads;
create trigger market_uploads_gate before insert on commerce.market_uploads for each row execute function commerce.market_uploads_gate();
drop trigger if exists export_files_gate on commerce.export_files;
create trigger export_files_gate before insert on commerce.export_files for each row execute function commerce.export_files_gate();

-- 사용자 쓰기 테이블의 created_by 고정
drop trigger if exists products_stamp_creator on commerce.products;
create trigger products_stamp_creator before insert on commerce.products for each row execute function commerce.commerce_stamp_creator();
drop trigger if exists shipping_templates_stamp_creator on commerce.shipping_templates;
create trigger shipping_templates_stamp_creator before insert on commerce.shipping_templates for each row execute function commerce.commerce_stamp_creator();
drop trigger if exists listing_drafts_stamp_creator on commerce.listing_drafts;
create trigger listing_drafts_stamp_creator before insert on commerce.listing_drafts for each row execute function commerce.commerce_stamp_creator();
drop trigger if exists banned_words_stamp_creator on commerce.banned_words;
create trigger banned_words_stamp_creator before insert on commerce.banned_words for each row execute function commerce.commerce_stamp_creator();


-- =====================================================================
-- 15. 사용자 RPC: compliance WARN 확인 (FAIL 은 확인으로 넘길 수 없다)
-- =====================================================================
create or replace function commerce.acknowledge_compliance_warning(p_detail_page_id uuid, p_note text default null)
returns commerce.detail_pages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row commerce.detail_pages;
begin
  select * into v_row from commerce.detail_pages d where d.id = p_detail_page_id for update;
  if not found then
    raise exception 'acknowledge_compliance_warning: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'acknowledge_compliance_warning: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_row.org_id, 'commerce') then
    raise exception 'acknowledge_compliance_warning: no entitlement' using errcode = '42501';
  end if;
  if v_row.status <> 'ready' then
    raise exception 'acknowledge_compliance_warning: detail page is %', v_row.status using errcode = 'CM008';
  end if;
  if coalesce(v_row.compliance_verdict, '') <> 'warn' then
    raise exception 'acknowledge_compliance_warning: verdict is not warn' using errcode = 'CM009';
  end if;
  update commerce.detail_pages
     set warn_acknowledged_at = now(), warn_acknowledged_by = auth.uid()
   where id = p_detail_page_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'detail_page.compliance_warn_ack', 'detail_page', p_detail_page_id::text,
                           null, null, jsonb_build_object('note', left(coalesce(p_note, ''), 500), 'issues', v_row.compliance_issues));
  return v_row;
end;
$$;


-- =====================================================================
-- 16. RLS 와 GRANT
-- =====================================================================
alter table commerce.import_batches     enable row level security;
alter table commerce.products           enable row level security;
alter table commerce.detail_pages       enable row level security;
alter table commerce.detail_page_slots  enable row level security;
alter table commerce.market_images      enable row level security;
alter table commerce.market_accounts    enable row level security;
alter table commerce.shipping_templates enable row level security;
alter table commerce.listing_drafts     enable row level security;
alter table commerce.market_uploads     enable row level security;
alter table commerce.export_files       enable row level security;
alter table commerce.banned_words       enable row level security;
alter table commerce.exchange_rates     enable row level security;
alter table commerce.market_categories  enable row level security;

-- 기본: 전부 회수 후 필요한 것만(모놀리스 public 기본 권한 대비. 모듈러에서는 무해)
revoke all on table commerce.import_batches, commerce.products, commerce.detail_pages, commerce.detail_page_slots,
  commerce.market_images, commerce.market_accounts, commerce.shipping_templates, commerce.listing_drafts,
  commerce.market_uploads, commerce.export_files, commerce.banned_words, commerce.exchange_rates, commerce.market_categories
  from public, anon, authenticated;
grant all on table commerce.import_batches, commerce.products, commerce.detail_pages, commerce.detail_page_slots,
  commerce.market_images, commerce.market_accounts, commerce.shipping_templates, commerce.listing_drafts,
  commerce.market_uploads, commerce.export_files, commerce.banned_words, commerce.exchange_rates, commerce.market_categories
  to service_role;

-- 읽기 전용(서버가 쓰는) 테넌트 테이블
grant select on table commerce.import_batches, commerce.detail_pages, commerce.detail_page_slots, commerce.market_images,
  commerce.market_accounts, commerce.market_uploads, commerce.export_files to authenticated;

drop policy if exists import_batches_select on commerce.import_batches;
create policy import_batches_select on commerce.import_batches for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists detail_pages_select on commerce.detail_pages;
create policy detail_pages_select on commerce.detail_pages for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists detail_page_slots_select on commerce.detail_page_slots;
create policy detail_page_slots_select on commerce.detail_page_slots for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists market_images_select on commerce.market_images;
create policy market_images_select on commerce.market_images for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists market_accounts_select on commerce.market_accounts;
create policy market_accounts_select on commerce.market_accounts for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists market_uploads_select on commerce.market_uploads;
create policy market_uploads_select on commerce.market_uploads for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists export_files_select on commerce.export_files;
create policy export_files_select on commerce.export_files for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));

-- products: 콘텐츠 컬럼만 INSERT/UPDATE. banned_words_found, source_type/ref, import_batch_id 는 서버 전용.
grant select on table commerce.products to authenticated;
grant insert (org_id, title, title_original, title_optimized, brand, manufacturer, origin_country, model_code, category_path,
              is_health_food, health_food_status, is_overseas, source_price, source_currency, sell_price_krw, list_price_krw,
              stock, images, attributes, tags)
  on table commerce.products to authenticated;
grant update (title, title_optimized, brand, manufacturer, origin_country, model_code, category_path,
              is_health_food, health_food_status, is_overseas, source_price, source_currency, sell_price_krw, list_price_krw,
              stock, images, attributes, tags, status, deleted_at)
  on table commerce.products to authenticated;
grant delete on table commerce.products to authenticated;
drop policy if exists products_select on commerce.products;
create policy products_select on commerce.products for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists products_insert on commerce.products;
create policy products_insert on commerce.products for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists products_update on commerce.products;
create policy products_update on commerce.products for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists products_delete on commerce.products;
create policy products_delete on commerce.products for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- shipping_templates: 순수 콘텐츠
grant select, delete on table commerce.shipping_templates to authenticated;
grant insert (org_id, name, template_type, shipping, dispatch_days, return_window_days, exchange_allowed, return_fee_krw,
              initial_shipping_fee_krw, restriction_codes, return_address, contact_phone, is_default)
  on table commerce.shipping_templates to authenticated;
grant update (name, template_type, shipping, dispatch_days, return_window_days, exchange_allowed, return_fee_krw,
              initial_shipping_fee_krw, restriction_codes, return_address, contact_phone, is_default)
  on table commerce.shipping_templates to authenticated;
drop policy if exists shipping_templates_select on commerce.shipping_templates;
create policy shipping_templates_select on commerce.shipping_templates for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists shipping_templates_insert on commerce.shipping_templates;
create policy shipping_templates_insert on commerce.shipping_templates for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists shipping_templates_update on commerce.shipping_templates;
create policy shipping_templates_update on commerce.shipping_templates for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists shipping_templates_delete on commerce.shipping_templates;
create policy shipping_templates_delete on commerce.shipping_templates for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- listing_drafts: 콘텐츠 컬럼만. status/completeness/missing_fields 는 서버 전용.
grant select, delete on table commerce.listing_drafts to authenticated;
grant insert (org_id, product_id, detail_page_id, market, market_account_id, shipping_template_id, category_code, category_path,
              display_name, form_data, notice_info)
  on table commerce.listing_drafts to authenticated;
grant update (detail_page_id, market_account_id, shipping_template_id, category_code, category_path, display_name, form_data, notice_info)
  on table commerce.listing_drafts to authenticated;
drop policy if exists listing_drafts_select on commerce.listing_drafts;
create policy listing_drafts_select on commerce.listing_drafts for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists listing_drafts_insert on commerce.listing_drafts;
create policy listing_drafts_insert on commerce.listing_drafts for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists listing_drafts_update on commerce.listing_drafts;
create policy listing_drafts_update on commerce.listing_drafts for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists listing_drafts_delete on commerce.listing_drafts;
create policy listing_drafts_delete on commerce.listing_drafts for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- banned_words: 기본 사전(org_id null)은 읽기 전용, 조직 추가분은 owner/admin 편집
grant select, delete on table commerce.banned_words to authenticated;
grant insert (org_id, word, category, match_mode, severity, replacement, note, is_active) on table commerce.banned_words to authenticated;
grant update (word, category, match_mode, severity, replacement, note, is_active) on table commerce.banned_words to authenticated;
drop policy if exists banned_words_select on commerce.banned_words;
create policy banned_words_select on commerce.banned_words for select to authenticated
  using (org_id is null or (core.is_org_member(org_id) and core.has_entitlement(org_id, 'commerce')));
drop policy if exists banned_words_insert on commerce.banned_words;
create policy banned_words_insert on commerce.banned_words for insert to authenticated
  with check (org_id is not null and core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists banned_words_update on commerce.banned_words;
create policy banned_words_update on commerce.banned_words for update to authenticated
  using (org_id is not null and core.has_org_role(org_id, array['owner', 'admin']))
  with check (org_id is not null and core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'commerce'));
drop policy if exists banned_words_delete on commerce.banned_words;
create policy banned_words_delete on commerce.banned_words for delete to authenticated
  using (org_id is not null and core.has_org_role(org_id, array['owner', 'admin']));

-- 전역 캐시: 로그인 사용자 읽기
grant select on table commerce.exchange_rates, commerce.market_categories to authenticated;
drop policy if exists exchange_rates_select on commerce.exchange_rates;
create policy exchange_rates_select on commerce.exchange_rates for select to authenticated using (true);
drop policy if exists market_categories_select on commerce.market_categories;
create policy market_categories_select on commerce.market_categories for select to authenticated using (true);


-- =====================================================================
-- 17. 함수 EXECUTE 정리
-- =====================================================================
revoke execute on function commerce.commerce_features(uuid) from public, anon, authenticated;
revoke execute on function commerce.commerce_limit(uuid, text, integer) from public, anon, authenticated;
revoke execute on function commerce.commerce_transition_allowed(text, text, text) from public, anon, authenticated;
revoke execute on function commerce.commerce_status_guard() from public, anon, authenticated;
revoke execute on function commerce.commerce_stamp_creator() from public, anon, authenticated;
revoke execute on function commerce.products_enforce_quota() from public, anon, authenticated;
revoke execute on function commerce.market_accounts_enforce() from public, anon, authenticated;
revoke execute on function commerce.market_uploads_gate() from public, anon, authenticated;
revoke execute on function commerce.export_files_gate() from public, anon, authenticated;
revoke execute on function commerce.acknowledge_compliance_warning(uuid, text) from public, anon, authenticated;
-- PostgreSQL 전역 기본값(PUBLIC EXECUTE)은 alter default privileges 로 지워지지 않는다(core 0007 과 같은 규칙).
-- 스키마의 모든 함수에서 한 번 더 회수한 뒤 아래 허용 목록만 준다.
revoke execute on all functions in schema commerce from public, anon, authenticated;

grant execute on function commerce.commerce_features(uuid) to service_role;
grant execute on function commerce.commerce_limit(uuid, text, integer) to service_role;
-- 상태 전이 트리거가 사용자 세션(listing_drafts INSERT)에서도 호출한다. 데이터를 읽지 않는 immutable 함수라 공개해도 무해.
grant execute on function commerce.commerce_transition_allowed(text, text, text) to authenticated, service_role;
grant execute on function commerce.acknowledge_compliance_warning(uuid, text) to authenticated, service_role;


-- =====================================================================
-- 18. Realtime: 진행률은 core.jobs 로 받고, 슬롯 카드/업로드/내보내기 상태는 아래 테이블 변경으로 받는다(RLS 적용)
-- =====================================================================
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['detail_pages', 'detail_page_slots', 'market_uploads', 'export_files', 'import_batches'] loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'commerce' and tablename = t) then
        execute format('alter publication supabase_realtime add table commerce.%I', t);
      end if;
    end loop;
  end if;
end $$;


-- =====================================================================
-- 19. 제품 기본 금지어 사전(org_id null). 출처: Nomad-AI-Factory_V.2/DETAIL_PAGE_SYSTEM.md:497-511
--     '효과' 치환은 원본 목록에 단어가 없어 동작하지 않았다(리뷰 V2 #16) → '효과가 있는'만 둔다.
--     목록 확정은 법률 검토 뒤(01_PRD 6장). 매칭은 앱 계층이 한글 경계를 고려해 수행한다(\b 금지).
-- =====================================================================
insert into commerce.banned_words (org_id, word, category, match_mode, severity, replacement) values
  (null, '치료',          'health_food', 'substring', 'fail', '관리에 도움을 줄 수 있는'),
  (null, '치유',          'health_food', 'substring', 'fail', null),
  (null, '치료제',        'health_food', 'substring', 'fail', null),
  (null, '효능',          'health_food', 'substring', 'fail', '기능성'),
  (null, '효과가 있는',   'health_food', 'substring', 'fail', null),
  (null, '의약품',        'health_food', 'substring', 'fail', null),
  (null, '약품',          'health_food', 'substring', 'warn', null),
  (null, '항암',          'health_food', 'substring', 'fail', null),
  (null, '항균',          'health_food', 'substring', 'fail', '청결 유지'),
  (null, '살균',          'health_food', 'substring', 'fail', '위생 관리'),
  (null, '멸균',          'health_food', 'substring', 'fail', null),
  (null, '탈모치료',      'health_food', 'substring', 'fail', null),
  (null, '발모',          'health_food', 'substring', 'fail', null),
  (null, '혈압강하',      'health_food', 'substring', 'fail', null),
  (null, '당뇨치료',      'health_food', 'substring', 'fail', null),
  (null, '관절치료',      'health_food', 'substring', 'fail', null),
  (null, '면역치료',      'health_food', 'substring', 'fail', null),
  (null, '암예방',        'health_food', 'substring', 'fail', null),
  (null, '암치료',        'health_food', 'substring', 'fail', null),
  (null, '콜레스테롤 낮추는', 'health_food', 'substring', 'fail', null),
  (null, '혈당 낮추는',   'health_food', 'substring', 'fail', null)
on conflict (category, word) where org_id is null do nothing;

-- =====================================================================
-- 20. AI·음성 기본값 (2026-10-13, 확정 결정 13~17)
--   설계: docs/products/nomad-commerce/02_ARCHITECTURE.md 5절, 01_PRD.md 4.6절. 정본 규칙은 _platform-core/AI_ARCHITECTURE.md 4장,
--   VOICE_ARCHITECTURE.md 3장. 모든 값은 제안이며 운영 화면이 아니라 이 조각과 모놀리스 seed 에서만 바꾼다.
--   20.1 기능별 라우팅 기본값: org_id null(플랫폼 기본), app_id 'commerce'. 기능 키는 소문자. 체인 제공자는 seed.sql 의
--        core.ai_providers 행이어야 하고 kind 가 맞아야 한다(20.3 검사).
--        - commerce.detail_page : 그래프 commerce.detail_page 의 정보 추출·카피·마켓 변환 노드. 상품 정보에는 개인정보가 없어
--                                 오픈소스 강제는 두지 않는다. 국외 이전 동의가 없는 조직은 resolve_ai_route 가 상용을 걸러 낸다.
--        - commerce.compliance  : 그래프의 마지막 compliance 노드와 편집 후 재판정. 짧은 판정이라 저비용 모델 먼저.
--        - commerce.assist      : 상품명·키워드, 고시·카테고리 자동완성, URL 벤치마킹 요약, 음성 구조화, 쇼츠 스크립트(그래프 commerce.assist).
--        - commerce.vision      : 상품 이미지 속성 분석. 멀티모달 모델이 필요해 oss-llm 은 마지막(오픈소스 멀티모달 서빙 여부는 구현 시 확인).
--        - chat                 : 셀러 어시스턴트(/tools/answer). 비용·속도 우선.
--        - wiki.*               : 운영자 조직의 마켓 규칙 위키(개인정보 없음). 대량 처리라 오픈소스 먼저.
--        - dify.aux             : Dify 보조 LLM 노드(질문 분류). 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--        - commerce.knowledge(embedding): 마켓 규칙 컬렉션과 셀러 상품 컬렉션 모두 국내 오픈소스 임베딩으로 고정(대체 없음).
--                                 동의 여부와 무관하게 질의·문서 임베딩이 같은 모델이어야 하고, 모델을 바꾸면 컬렉션 재색인.
--        - voice_chat           : 음성 질문 STT 는 오픈소스 먼저, 답변 읽어 주기 TTS 는 ElevenLabs 먼저.
--        - product_voice        : 상품 설명 음성 입력 STT. 대량·저비용이라 오픈소스 먼저.
--        - shorts_narration     : 쇼츠 내레이션 TTS. ElevenLabs 먼저. 한 작업을 같은 목소리로 만들어야 하므로 작업 도중 다른 제공자로
--                                 대체하지 않는다. 이 금지는 체인이 아니라 음성 어댑터(packages/core-voice, feature=shorts_narration)가 강제한다.
--   20.2 플랜 features 의 AI 키. seed.sql 이 이 조각보다 나중에 실행되면 덮어써지므로 _supabase-modular/seed.sql 반영을
--        코어에 요청했다(06_AGENT_PLAN.md 6.1절 R-1). 서버는 누락 키를 기본값으로 읽는다(01_PRD.md 4.4절).
-- =====================================================================
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'commerce', 'commerce.detail_page', 'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'commerce', 'commerce.compliance',  'llm',       'auto',        '[{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'commerce', 'commerce.assist',      'llm',       'auto',        '[{"provider":"google","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'commerce', 'commerce.vision',      'llm',       'auto',        '[{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'commerce', 'chat',                 'llm',       'auto',        '[{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'commerce', 'wiki.query',           'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'commerce', 'wiki.ingest',          'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'commerce', 'wiki.lint',            'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'commerce', 'dify.aux',             'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'commerce', 'commerce.knowledge',   'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'commerce', 'voice_chat',           'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'commerce', 'voice_chat',           'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'commerce', 'product_voice',        'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'commerce', 'shorts_narration',     'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 20.2 플랜 AI 키(있으면 병합, 없으면 아무 일도 하지 않음)
update core.plans set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 20, "voice_chat": false, "shorts_narration": false}'::jsonb
 where app_id = 'commerce' and code = 'free';
update core.plans set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "shorts_narration": true}'::jsonb
 where app_id = 'commerce' and code in ('starter', 'pro');
update core.plans set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 500, "voice_chat": true, "shorts_narration": true}'::jsonb
 where app_id = 'commerce' and code = 'enterprise';

-- 20.3 체인 검사: 제공자 행이 있을 때만(seed 전에 적용되는 배포 순서에서도 실패하지 않게) 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'commerce'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'commerce routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;

-- =====================================================================
-- 끝. 스케줄(워커 크론, service_role): 디스패처 5초(waiting → enqueue_job), 업로드 상태 폴링 10분,
-- 환율 갱신 평일 11:30 KST, 만료 내보내기 정리 매일. 04_API.md 4장, 02_ARCHITECTURE.md 4장.
-- =====================================================================
