-- =====================================================================
-- 0011_core_tenant_theming.sql   (제안 · staged — 승인 전에는 _supabase-modular/migrations 에 넣지 않는다)
-- 멀티테넌트 테마(화이트라벨) 코어 확장.
--   테넌트 = core.organizations (기존 코어 그대로). 이 파일은 core.* 기존 객체를 ALTER 하지 않고 새 테이블만 만든다.
--
-- 만드는 것
--   tenant_themes             L1 브랜딩: 로고 슬롯, 의미 토큰(라이트/다크), 서체. draft → published → archived 버전 관리
--   tenant_settings           L1 운영 설정: 고객센터, 발신자 이름, 사업자 정보(푸터), 기본 언어. 내비게이션은 L2부터 적용
--   tenant_labels             L2 용어 바꾸기("회원" → "수강생")
--   tenant_feature_overrides  L2 플랜 features 를 조직 단위로 덮어쓰기(서버만 쓰기)
--   tenant_domains            L2 커스텀 도메인(app.고객사.com). 서브도메인은 조직 slug 로 해석하므로 행이 없다
--   tenant_extensions         L3/L4 슬롯·훅 확장 등록(서버만 쓰기). 코드는 저장소에 있고 DB 는 켜고 끄기만
--   tenant_deployments        판매 모델 A/B/C 배포 기록(운영자용)
--   함수: theming_level, effective_features, resolve_tenant, tenant_public_labels,
--         publish_tenant_theme, clone_tenant_theme, request_tenant_domain, set_tenant_domain_status
--
-- 화이트라벨 단계(theming_level, 정수 0~4)
--   0 없음(플랫폼 기본 테마) / 1 브랜딩 / 2 구성(라벨·내비게이션·커스텀 도메인) / 3 화면 슬롯 / 4 로직 훅
--   값의 출처: core.plans.features.theming_level  →  tenant_feature_overrides('theming_level') 가 있으면 그 값
--
-- 선행: 0000 ~ 0005 (0006~0009 불필요)
-- 번호: 0010 은 staged/0010_core_auth_identity_links.sql 이 쓰고 있어 0011 을 쓴다.
-- 모놀리스 변환: sed 's/core\./public./g' 한 줄. 아래 revoke 줄이 public 스키마 기본 권한을 회수하므로 그대로 동작한다.
-- 사용자 정의 SQLSTATE: TM001 초안 아님 / TM002 대비 검사 미통과 / TM003 게시본 내용 변경 / TM004 도메인 개수 초과 / TM005 이미 쓰는 도메인
-- PostgreSQL 15 / Supabase 표준 객체만. 반복 실행해도 안전하다.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. 검증 헬퍼 (IMMUTABLE, CHECK 제약에서 사용)
-- ---------------------------------------------------------------------

-- 테넌트가 바꿀 수 있는 의미 토큰만 허용한다(허용 목록). 값은 CSS 주입이 불가능한 문자만 통과한다.
--   형식: {"light": {"brand": "#1d4ed8", "radius-control": "8px"}, "dark": {...}}
--   색상 값: #rrggbb 또는 oklch(...) (괄호 안은 숫자·점·공백·%·/ 만). 세미콜론·중괄호·url() 은 통과할 수 없다.
--   정밀한 색 검증(실제 색 공간 범위, 대비)은 서버가 하고 결과를 contrast_report 에 남긴다.
create or replace function core.is_valid_theme_tokens(p jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_mode   text;
  v_key    text;
  v_val    jsonb;
  v_colors text[] := array[
    'brand', 'brand-foreground', 'brand-hover', 'brand-subtle',
    'accent', 'accent-foreground', 'focus-ring',
    'sidebar', 'sidebar-foreground',
    'chart-1', 'chart-2', 'chart-3', 'chart-4', 'chart-5'];
  v_sizes  text[] := array['radius-control', 'radius-card'];
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    return false;
  end if;
  for v_mode in select jsonb_object_keys(p) loop
    if v_mode not in ('light', 'dark') or jsonb_typeof(p -> v_mode) <> 'object' then
      return false;
    end if;
    for v_key, v_val in select e.key, e.value from jsonb_each(p -> v_mode) e loop
      if jsonb_typeof(v_val) <> 'string' then
        return false;
      end if;
      if v_key = any (v_colors) then
        if not ((v_val #>> '{}') ~ '^(#[0-9a-fA-F]{6}|oklch\([0-9. %/]{5,40}\))$') then
          return false;
        end if;
      elsif v_key = any (v_sizes) then
        if not ((v_val #>> '{}') ~ '^(0|[0-9]{1,2}(\.[0-9])?px|[0-9](\.[0-9]{1,3})?rem)$') then
          return false;
        end if;
      else
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;

-- 서체는 URL 이 아니라 앱의 서체 레지스트리 키만 받는다(예: pretendard, noto-sans-kr).
create or replace function core.is_valid_theme_fonts(p jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_key text;
  v_val jsonb;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    return false;
  end if;
  for v_key, v_val in select e.key, e.value from jsonb_each(p) e loop
    if v_key not in ('heading', 'body', 'mono')
       or jsonb_typeof(v_val) <> 'string'
       or not ((v_val #>> '{}') ~ '^[a-z0-9][a-z0-9-]{1,39}$') then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

-- 로고 등 자산 경로: public-assets 버킷 안 "<org_id>/theming/..." 만 허용. 다른 조직 파일, '..' 금지.
create or replace function core.is_theming_asset_path(p_org uuid, p_path text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_path is null
      or (    p_path ~ '^[0-9a-f-]{36}/theming/[A-Za-z0-9_./-]{1,200}$'
          and split_part(p_path, '/', 1) = p_org::text
          and position('..' in p_path) = 0);
$$;


-- ---------------------------------------------------------------------
-- 1. tenant_themes: L1 브랜딩
-- ---------------------------------------------------------------------
create table if not exists core.tenant_themes (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  app_id               text references core.apps(id) on delete cascade,      -- null = 조직 공통(모든 앱)
  status               text not null default 'draft'
                       constraint tenant_themes_status_check check (status in ('draft', 'published', 'archived')),
  version              integer constraint tenant_themes_version_check check (version is null or version > 0),
  name                 text not null default '기본 테마'
                       constraint tenant_themes_name_check check (char_length(name) between 1 and 60),
  brand_name           text not null
                       constraint tenant_themes_brand_name_check check (char_length(brand_name) between 1 and 60),
  logo_horizontal_path text,   -- 가로형: 헤더, 로그인 화면
  logo_mark_path       text,   -- 심볼: 접힌 사이드바, 모바일, 앱 아이콘
  logo_dark_path       text,   -- 어두운 배경용 가로형
  favicon_path         text,
  og_image_path        text,   -- 링크 공유 미리보기 1200x630
  email_header_path    text,   -- 메일 머리 이미지
  tokens               jsonb not null default '{"light": {}, "dark": {}}'::jsonb
                       constraint tenant_themes_tokens_check check (core.is_valid_theme_tokens(tokens)),
  fonts                jsonb not null default '{}'::jsonb
                       constraint tenant_themes_fonts_check check (core.is_valid_theme_fonts(fonts)),
  source               text not null default 'manual'
                       constraint tenant_themes_source_check check (source in ('manual', 'logo_extract', 'ai', 'import')),
  contrast_report      jsonb,          -- 서버만 기록. {"passed": true, "pairs": [...], "checked_by": "server"}
  contrast_checked_at  timestamptz,
  created_by           uuid,
  published_by         uuid,
  published_at         timestamptz,
  archived_at          timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint tenant_themes_assets_check check (
        core.is_theming_asset_path(org_id, logo_horizontal_path)
    and core.is_theming_asset_path(org_id, logo_mark_path)
    and core.is_theming_asset_path(org_id, logo_dark_path)
    and core.is_theming_asset_path(org_id, favicon_path)
    and core.is_theming_asset_path(org_id, og_image_path)
    and core.is_theming_asset_path(org_id, email_header_path)),
  constraint tenant_themes_publish_check check (
    status = 'draft' or (version is not null and published_at is not null))
);
comment on table core.tenant_themes is 'L1 브랜딩. 조직·범위(app_id 또는 공통)마다 게시본은 1개. 게시본·보관본은 내용 변경 불가, 복제해서 고친다';
comment on column core.tenant_themes.tokens is '의미 토큰 덮어쓰기(허용 목록). 원시 토큰과 중립색(배경, 본문 글자)은 플랫폼이 고정한다';
-- 범위마다 게시본 1개
create unique index if not exists tenant_themes_one_published_idx
  on core.tenant_themes (org_id, coalesce(app_id, '*')) where status = 'published';
create unique index if not exists tenant_themes_version_uniq
  on core.tenant_themes (org_id, coalesce(app_id, '*'), version) where version is not null;
create index if not exists tenant_themes_org_status_idx on core.tenant_themes (org_id, status);

drop trigger if exists tenant_themes_set_updated_at on core.tenant_themes;
create trigger tenant_themes_set_updated_at before update on core.tenant_themes
  for each row execute function core.set_updated_at();

-- 내용 불변·상태 전이·대비 결과 무효화
create or replace function core.tenant_themes_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_content_changed boolean;
begin
  if new.id is distinct from old.id or new.org_id is distinct from old.org_id or new.app_id is distinct from old.app_id then
    raise exception 'tenant_themes: id, org_id, app_id are immutable' using errcode = '22023';
  end if;

  v_content_changed :=
       new.name                 is distinct from old.name
    or new.brand_name           is distinct from old.brand_name
    or new.tokens               is distinct from old.tokens
    or new.fonts                is distinct from old.fonts
    or new.logo_horizontal_path is distinct from old.logo_horizontal_path
    or new.logo_mark_path       is distinct from old.logo_mark_path
    or new.logo_dark_path       is distinct from old.logo_dark_path
    or new.favicon_path         is distinct from old.favicon_path
    or new.og_image_path        is distinct from old.og_image_path
    or new.email_header_path    is distinct from old.email_header_path;

  if old.status <> 'draft' and v_content_changed then
    raise exception 'tenant_themes: published or archived theme is immutable, clone it first' using errcode = 'TM003';
  end if;

  if new.status is distinct from old.status then
    if not (   (old.status = 'draft'     and new.status in ('published', 'archived'))
            or (old.status = 'published' and new.status = 'archived')) then
      raise exception 'tenant_themes: invalid transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if not core.is_privileged_session() then
      raise exception 'tenant_themes: status changes only via publish_tenant_theme' using errcode = '42501';
    end if;
  end if;

  -- 내용이 바뀌었는데 같은 UPDATE 에서 대비 결과를 새로 쓰지 않았다면, 이전 통과 결과를 무효로 만든다.
  if v_content_changed and new.contrast_report is not distinct from old.contrast_report then
    new.contrast_report     := null;
    new.contrast_checked_at := null;
  end if;
  return new;
end;
$$;
drop trigger if exists tenant_themes_guard on core.tenant_themes;
create trigger tenant_themes_guard before update on core.tenant_themes
  for each row execute function core.tenant_themes_guard();


-- ---------------------------------------------------------------------
-- 2. tenant_settings: L1 운영 설정 (내비게이션은 L2 이상에서만 resolve_tenant 가 내보낸다)
-- ---------------------------------------------------------------------
create table if not exists core.tenant_settings (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  app_id          text references core.apps(id) on delete cascade,           -- null = 조직 공통
  support_email   text constraint tenant_settings_support_email_check
                  check (support_email is null or support_email ~ '^[^@\s<>]{1,64}@[^@\s<>]{1,190}$'),
  support_url     text constraint tenant_settings_support_url_check
                  check (support_url is null or (char_length(support_url) <= 300 and support_url ~ '^https://[^\s<>"'']{3,}$')),
  email_from_name text constraint tenant_settings_from_name_check
                  check (email_from_name is null or email_from_name ~ '^[^<>"\r\n]{1,40}$'),
  default_locale  text not null default 'ko'
                  constraint tenant_settings_locale_check check (default_locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  timezone        text not null default 'Asia/Seoul'
                  constraint tenant_settings_timezone_check check (timezone ~ '^[A-Za-z_]+(/[A-Za-z_+-]+){0,2}$'),
  legal           jsonb not null default '{}'::jsonb    -- {company_name, ceo, business_no, ecommerce_no, address, phone, privacy_url, terms_url}
                  constraint tenant_settings_legal_check check (jsonb_typeof(legal) = 'object' and pg_column_size(legal) < 4096),
  footer_links    jsonb not null default '[]'::jsonb    -- [{label, href}]
                  constraint tenant_settings_footer_check check (jsonb_typeof(footer_links) = 'array' and jsonb_array_length(footer_links) <= 12),
  navigation      jsonb not null default '[]'::jsonb    -- [{key, hidden?, order?, label_key?}] — 메뉴 키는 앱 코드의 메뉴 레지스트리 키
                  constraint tenant_settings_navigation_check check (jsonb_typeof(navigation) = 'array' and pg_column_size(navigation) < 16384),
  updated_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index if not exists tenant_settings_scope_uniq on core.tenant_settings (org_id, coalesce(app_id, '*'));
drop trigger if exists tenant_settings_set_updated_at on core.tenant_settings;
create trigger tenant_settings_set_updated_at before update on core.tenant_settings
  for each row execute function core.set_updated_at();


-- ---------------------------------------------------------------------
-- 3. tenant_labels: L2 용어 바꾸기
-- ---------------------------------------------------------------------
create table if not exists core.tenant_labels (
  org_id     uuid not null references core.organizations(id) on delete cascade,
  app_id     text not null references core.apps(id) on delete cascade,
  locale     text not null default 'ko' constraint tenant_labels_locale_check check (locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  key        text not null constraint tenant_labels_key_check check (key ~ '^[a-z][a-z0-9_.]{1,79}$'),
  value      text not null constraint tenant_labels_value_check check (char_length(value) between 1 and 200),
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, app_id, locale, key)
);
drop trigger if exists tenant_labels_set_updated_at on core.tenant_labels;
create trigger tenant_labels_set_updated_at before update on core.tenant_labels
  for each row execute function core.set_updated_at();


-- ---------------------------------------------------------------------
-- 4. tenant_feature_overrides: L2 플랜 features 덮어쓰기 (돈·한도 → 서버만 쓰기)
-- ---------------------------------------------------------------------
create table if not exists core.tenant_feature_overrides (
  org_id      uuid not null references core.organizations(id) on delete cascade,
  app_id      text not null references core.apps(id) on delete cascade,
  feature_key text not null constraint tenant_feature_overrides_key_check check (feature_key ~ '^[a-z][a-z0-9_]{1,62}$'),
  value       jsonb not null,
  reason      text,
  expires_at  timestamptz,
  granted_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (org_id, app_id, feature_key),
  constraint tenant_feature_overrides_level_check check (
    feature_key <> 'theming_level'
    or (jsonb_typeof(value) = 'number' and (value #>> '{}')::numeric in (0, 1, 2, 3, 4)))
);
drop trigger if exists tenant_feature_overrides_set_updated_at on core.tenant_feature_overrides;
create trigger tenant_feature_overrides_set_updated_at before update on core.tenant_feature_overrides
  for each row execute function core.set_updated_at();
drop trigger if exists tenant_feature_overrides_guard_write on core.tenant_feature_overrides;
create trigger tenant_feature_overrides_guard_write before insert or update or delete on core.tenant_feature_overrides
  for each row execute function core.guard_privileged_write();


-- ---------------------------------------------------------------------
-- 5. tenant_domains: L2 커스텀 도메인. 쓰기는 RPC(request_tenant_domain) 와 서버(set_tenant_domain_status)만
-- ---------------------------------------------------------------------
create table if not exists core.tenant_domains (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  app_id          text not null references core.apps(id) on delete cascade,
  hostname        text not null
                  constraint tenant_domains_hostname_check
                  check (char_length(hostname) <= 253 and hostname ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$'),
  status          text not null default 'pending'
                  constraint tenant_domains_status_check check (status in ('pending', 'verifying', 'active', 'failed', 'removed')),
  is_primary      boolean not null default false,
  verification    jsonb not null default '{}'::jsonb,   -- 호스팅(Vercel)이 돌려준 DNS 레코드 안내. 비밀값 금지
  last_error      text,
  requested_by    uuid,
  verified_at     timestamptz,
  last_checked_at timestamptz,
  removed_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
-- 제거되지 않은 도메인은 전 플랫폼에서 유일
create unique index if not exists tenant_domains_hostname_uniq on core.tenant_domains (hostname) where status <> 'removed';
create unique index if not exists tenant_domains_one_primary_idx on core.tenant_domains (org_id, app_id) where is_primary and status = 'active';
create index if not exists tenant_domains_org_idx on core.tenant_domains (org_id, app_id);
drop trigger if exists tenant_domains_set_updated_at on core.tenant_domains;
create trigger tenant_domains_set_updated_at before update on core.tenant_domains
  for each row execute function core.set_updated_at();
drop trigger if exists tenant_domains_guard_write on core.tenant_domains;
create trigger tenant_domains_guard_write before insert or update or delete on core.tenant_domains
  for each row execute function core.guard_privileged_write();


-- ---------------------------------------------------------------------
-- 6. tenant_extensions: L3 슬롯 / L4 훅 등록 (서버만 쓰기). config 는 서버만 읽는다
-- ---------------------------------------------------------------------
create table if not exists core.tenant_extensions (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  app_id        text not null references core.apps(id) on delete cascade,
  slot_key      text not null constraint tenant_extensions_slot_check check (slot_key ~ '^[a-z][a-z0-9_.-]{1,79}$'),
  extension_key text not null constraint tenant_extensions_ext_check check (extension_key ~ '^[a-z][a-z0-9_.-]{1,79}$'),
  kind          text not null default 'slot' constraint tenant_extensions_kind_check check (kind in ('slot', 'hook', 'webhook')),
  config        jsonb not null default '{}'::jsonb,   -- 비밀값 금지(자격증명은 core.encrypted_credentials)
  is_enabled    boolean not null default true,
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (org_id, app_id, slot_key)
);
drop trigger if exists tenant_extensions_set_updated_at on core.tenant_extensions;
create trigger tenant_extensions_set_updated_at before update on core.tenant_extensions
  for each row execute function core.set_updated_at();
drop trigger if exists tenant_extensions_guard_write on core.tenant_extensions;
create trigger tenant_extensions_guard_write before insert or update or delete on core.tenant_extensions
  for each row execute function core.guard_privileged_write();


-- ---------------------------------------------------------------------
-- 7. tenant_deployments: 판매 모델 A(설치형) / B(전용 Supabase 화이트라벨) / C(공유 SaaS) 배포 기록
--    컨트롤 플레인(운영자 DB)에 둔다. 모델 B 고객의 전용 DB 에도 같은 스키마가 있지만 이 표는 비어 있어도 된다.
-- ---------------------------------------------------------------------
create table if not exists core.tenant_deployments (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  app_id               text not null references core.apps(id) on delete cascade,
  deploy_model         text not null constraint tenant_deployments_model_check check (deploy_model in ('A', 'B', 'C')),
  status               text not null default 'provisioning'
                       constraint tenant_deployments_status_check check (status in ('provisioning', 'active', 'suspended', 'retired')),
  supabase_project_ref text,
  vercel_project_id    text,
  region               text,
  release_channel      text not null default 'stable'
                       constraint tenant_deployments_channel_check check (release_channel in ('canary', 'stable', 'pinned')),
  pinned_version       text,
  contract_ref         text,
  note                 text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (org_id, app_id)
);
drop trigger if exists tenant_deployments_set_updated_at on core.tenant_deployments;
create trigger tenant_deployments_set_updated_at before update on core.tenant_deployments
  for each row execute function core.set_updated_at();
drop trigger if exists tenant_deployments_guard_write on core.tenant_deployments;
create trigger tenant_deployments_guard_write before insert or update or delete on core.tenant_deployments
  for each row execute function core.guard_privileged_write();


-- ---------------------------------------------------------------------
-- 8. 단계·기능 헬퍼
-- ---------------------------------------------------------------------

-- 내부용: 호출자 검사 없이 단계를 계산한다. EXECUTE 는 service_role 만(DEFINER 함수 안에서는 소유자 권한으로 호출된다).
-- p_app 이 null 이면 조직이 가진 활성 엔타이틀먼트 중 최댓값.
create or replace function core.theming_level_unchecked(p_org uuid, p_app text default null)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(max(
           least(4, greatest(0, coalesce(
             (select (o.value #>> '{}')::numeric::integer
                from core.tenant_feature_overrides o
               where o.org_id = e.org_id and o.app_id = e.app_id and o.feature_key = 'theming_level'
                 and jsonb_typeof(o.value) = 'number'
                 and (o.expires_at is null or o.expires_at > now())),
             case when jsonb_typeof(p.features -> 'theming_level') = 'number'
                  then (p.features ->> 'theming_level')::numeric::integer end,
             0)))), 0)
  from core.app_entitlements e
  join core.plans p on p.id = e.plan_id
  join core.organizations g on g.id = e.org_id and g.deleted_at is null
  where e.org_id = p_org and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now())
    and (p_app is null or e.app_id = p_app);
$$;

-- 공개용: 멤버·운영자·서버만 실제 값, 그 외는 0
create or replace function core.theming_level(p_org uuid, p_app text default null)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when core.is_service_caller() or core.is_org_member(p_org) or core.is_platform_admin()
      then core.theming_level_unchecked(p_org, p_app)
    else 0
  end;
$$;

-- 플랜 features 와 조직 덮어쓰기를 합친 값. 서버 기능 게이팅용(멤버 또는 서버만)
create or replace function core.effective_features(p_org uuid, p_app text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_base jsonb;
  v_over jsonb;
begin
  if not (core.is_service_caller() or core.is_org_member(p_org) or core.is_platform_admin()) then
    raise exception 'effective_features: not a member' using errcode = '42501';
  end if;
  select p.features into v_base
    from core.app_entitlements e join core.plans p on p.id = e.plan_id
   where e.org_id = p_org and e.app_id = p_app and e.status = 'active'
     and (e.expires_at is null or e.expires_at > now());
  if v_base is null then
    return null;   -- 엔타이틀먼트 없음
  end if;
  select coalesce(jsonb_object_agg(o.feature_key, o.value), '{}'::jsonb) into v_over
    from core.tenant_feature_overrides o
   where o.org_id = p_org and o.app_id = p_app and (o.expires_at is null or o.expires_at > now());
  return v_base || v_over;
end;
$$;


-- ---------------------------------------------------------------------
-- 9. 요청마다 테넌트 해석 (proxy.ts / 루트 레이아웃). anon 호출 가능, 공개해도 되는 값만 돌려준다
--   우선순위: p_hostname 이 활성 커스텀 도메인이면 그 조직·앱 → 아니면 p_slug(서브도메인) + p_app
--   theming_level < 1 이면 null → 앱은 플랫폼 기본 테마를 쓴다(무료 개인 조직은 해석되지 않는다)
-- ---------------------------------------------------------------------
create or replace function core.resolve_tenant(p_hostname text default null, p_slug text default null, p_app text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_host  text := lower(split_part(coalesce(p_hostname, ''), ':', 1));
  v_org   core.organizations;
  v_app   text := p_app;
  v_level integer;
  v_theme core.tenant_themes;
  v_set   core.tenant_settings;
  v_ext   jsonb;
  v_primary text;
begin
  if v_host <> '' then
    select o.* into v_org
      from core.tenant_domains d join core.organizations o on o.id = d.org_id
     where d.hostname = v_host and d.status = 'active' and o.deleted_at is null;
    if found then
      select d.app_id into v_app from core.tenant_domains d where d.hostname = v_host and d.status = 'active';
    end if;
  end if;

  if v_org.id is null and p_slug is not null and p_app is not null then
    select o.* into v_org from core.organizations o where o.slug = lower(p_slug) and o.deleted_at is null;
  end if;

  if v_org.id is null or v_app is null then
    return null;
  end if;

  v_level := core.theming_level_unchecked(v_org.id, v_app);
  if v_level < 1 then
    return null;
  end if;

  -- 앱 전용 게시본 → 없으면 조직 공통 게시본
  select t.* into v_theme from core.tenant_themes t
   where t.org_id = v_org.id and t.status = 'published' and (t.app_id = v_app or t.app_id is null)
   order by (t.app_id is null) limit 1;

  select s.* into v_set from core.tenant_settings s
   where s.org_id = v_org.id and (s.app_id = v_app or s.app_id is null)
   order by (s.app_id is null) limit 1;

  if v_level >= 3 then
    select coalesce(jsonb_object_agg(x.slot_key, x.extension_key), '{}'::jsonb) into v_ext
      from core.tenant_extensions x
     where x.org_id = v_org.id and x.app_id = v_app and x.is_enabled
       and ((x.kind = 'slot' and v_level >= 3) or (x.kind in ('hook', 'webhook') and v_level >= 4));
  end if;

  -- 대표 커스텀 도메인(L2 이상): 서브도메인 접속을 이 도메인으로 301 이동시키는 데 쓴다
  if v_level >= 2 then
    select d.hostname into v_primary from core.tenant_domains d
     where d.org_id = v_org.id and d.app_id = v_app and d.status = 'active' and d.is_primary;
  end if;

  return jsonb_build_object(
    'org_id', v_org.id,
    'slug',   v_org.slug,
    'app_id', v_app,
    'level',  v_level,
    'primary_domain', v_primary,
    'theme', case when v_theme.id is null then null else jsonb_build_object(
      'id', v_theme.id, 'version', v_theme.version, 'brand_name', v_theme.brand_name,
      'assets', jsonb_strip_nulls(jsonb_build_object(
        'logo_horizontal', v_theme.logo_horizontal_path, 'logo_mark', v_theme.logo_mark_path,
        'logo_dark', v_theme.logo_dark_path, 'favicon', v_theme.favicon_path,
        'og_image', v_theme.og_image_path, 'email_header', v_theme.email_header_path)),
      'tokens', v_theme.tokens, 'fonts', v_theme.fonts) end,
    'settings', case when v_set.id is null then null else jsonb_build_object(
      'support_email', v_set.support_email, 'support_url', v_set.support_url,
      'email_from_name', v_set.email_from_name, 'default_locale', v_set.default_locale,
      'timezone', v_set.timezone, 'legal', v_set.legal, 'footer_links', v_set.footer_links,
      'navigation', case when v_level >= 2 then v_set.navigation else '[]'::jsonb end) end,
    'extensions', coalesce(v_ext, '{}'::jsonb));
end;
$$;

-- 공개 라벨(L2 이상). 화면 문구 사전에 덮어쓸 값만 돌려준다
create or replace function core.tenant_public_labels(p_org_id uuid, p_app_id text, p_locale text default 'ko')
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when core.theming_level_unchecked(p_org_id, p_app_id) >= 2 then
    coalesce((select jsonb_object_agg(l.key, l.value) from core.tenant_labels l
               where l.org_id = p_org_id and l.app_id = p_app_id and l.locale = p_locale), '{}'::jsonb)
  else '{}'::jsonb end;
$$;


-- ---------------------------------------------------------------------
-- 10. 테마 게시·복제 RPC
-- ---------------------------------------------------------------------
create or replace function core.publish_tenant_theme(p_theme_id uuid)
returns core.tenant_themes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     core.tenant_themes;
  v_prev    uuid;
  v_version integer;
begin
  select * into v_row from core.tenant_themes where id = p_theme_id for update;
  if not found then
    raise exception 'publish_tenant_theme: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'publish_tenant_theme: owner or admin only' using errcode = '42501';
  end if;
  if core.theming_level_unchecked(v_row.org_id, v_row.app_id) < 1 then
    raise exception 'publish_tenant_theme: theming not included in plan' using errcode = '42501';
  end if;
  if v_row.status <> 'draft' then
    raise exception 'publish_tenant_theme: not a draft (%)', v_row.status using errcode = 'TM001';
  end if;
  if coalesce(v_row.contrast_report ->> 'passed', 'false') <> 'true' then
    raise exception 'publish_tenant_theme: contrast check has not passed' using errcode = 'TM002';
  end if;

  -- 같은 범위의 이전 게시본을 보관으로(게시본 1개 유니크 인덱스 때문에 먼저)
  update core.tenant_themes
     set status = 'archived', archived_at = now()
   where org_id = v_row.org_id and coalesce(app_id, '*') = coalesce(v_row.app_id, '*') and status = 'published'
  returning id into v_prev;

  select coalesce(max(version), 0) + 1 into v_version
    from core.tenant_themes
   where org_id = v_row.org_id and coalesce(app_id, '*') = coalesce(v_row.app_id, '*');

  update core.tenant_themes
     set status = 'published', version = v_version, published_at = now(), published_by = auth.uid()
   where id = p_theme_id
  returning * into v_row;

  perform core.write_audit(v_row.org_id, 'theme.publish', 'tenant_theme', v_row.id::text,
                           case when v_prev is null then null else jsonb_build_object('archived', v_prev) end,
                           jsonb_build_object('version', v_version, 'app_id', v_row.app_id));
  return v_row;
end;
$$;

-- 게시본·보관본을 새 초안으로 복제(되돌리기, 게시본 수정의 유일한 경로). 내용이 같으므로 대비 결과도 복사한다
create or replace function core.clone_tenant_theme(p_theme_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_src core.tenant_themes;
  v_id  uuid;
begin
  select * into v_src from core.tenant_themes where id = p_theme_id;
  if not found then
    raise exception 'clone_tenant_theme: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_src.org_id, array['owner', 'admin']) then
    raise exception 'clone_tenant_theme: owner or admin only' using errcode = '42501';
  end if;
  if core.theming_level_unchecked(v_src.org_id, v_src.app_id) < 1 then
    raise exception 'clone_tenant_theme: theming not included in plan' using errcode = '42501';
  end if;
  insert into core.tenant_themes (org_id, app_id, name, brand_name,
    logo_horizontal_path, logo_mark_path, logo_dark_path, favicon_path, og_image_path, email_header_path,
    tokens, fonts, source, contrast_report, contrast_checked_at, created_by)
  values (v_src.org_id, v_src.app_id, left(v_src.name || ' (복사본)', 60), v_src.brand_name,
    v_src.logo_horizontal_path, v_src.logo_mark_path, v_src.logo_dark_path, v_src.favicon_path, v_src.og_image_path, v_src.email_header_path,
    v_src.tokens, v_src.fonts, v_src.source, v_src.contrast_report, v_src.contrast_checked_at, auth.uid())
  returning id into v_id;
  perform core.write_audit(v_src.org_id, 'theme.clone', 'tenant_theme', v_id::text, null, jsonb_build_object('from', p_theme_id));
  return v_id;
end;
$$;


-- ---------------------------------------------------------------------
-- 11. 커스텀 도메인 RPC
-- ---------------------------------------------------------------------
-- 사용자: 도메인 연결 요청(owner/admin, L2 이상, 조직당 제거되지 않은 도메인 5개까지)
create or replace function core.request_tenant_domain(p_org_id uuid, p_app_id text, p_hostname text)
returns core.tenant_domains
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_host text := lower(trim(trailing '.' from trim(coalesce(p_hostname, ''))));
  v_row  core.tenant_domains;
begin
  if not core.is_service_caller()
     and not core.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'request_tenant_domain: owner or admin only' using errcode = '42501';
  end if;
  if core.theming_level_unchecked(p_org_id, p_app_id) < 2 then
    raise exception 'request_tenant_domain: custom domain requires theming level 2' using errcode = '42501';
  end if;
  if (select count(*) from core.tenant_domains where org_id = p_org_id and status <> 'removed') >= 5 then
    raise exception 'request_tenant_domain: domain limit reached' using errcode = 'TM004';
  end if;
  if exists (select 1 from core.tenant_domains where hostname = v_host and status <> 'removed') then
    raise exception 'request_tenant_domain: hostname already in use' using errcode = 'TM005';
  end if;
  insert into core.tenant_domains (org_id, app_id, hostname, requested_by)
  values (p_org_id, p_app_id, v_host, auth.uid())
  returning * into v_row;
  perform core.write_audit(p_org_id, 'domain.request', 'tenant_domain', v_row.id::text, null, jsonb_build_object('hostname', v_host, 'app_id', p_app_id));
  return v_row;
end;
$$;

-- 서버(검증 워커): 상태 전이. 처음 활성화된 도메인은 대표 도메인이 된다
create or replace function core.set_tenant_domain_status(p_domain_id uuid, p_status text, p_verification jsonb default null, p_error text default null)
returns core.tenant_domains
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row core.tenant_domains;
begin
  if not core.is_privileged_session() then
    raise exception 'set_tenant_domain_status: service_role only' using errcode = '42501';
  end if;
  select * into v_row from core.tenant_domains where id = p_domain_id for update;
  if not found then
    raise exception 'set_tenant_domain_status: not found' using errcode = 'P0002';
  end if;
  if not (   (v_row.status = 'pending'   and p_status in ('verifying', 'failed', 'removed'))
          or (v_row.status = 'verifying' and p_status in ('active', 'failed', 'removed'))
          or (v_row.status = 'active'    and p_status in ('failed', 'removed'))
          or (v_row.status = 'failed'    and p_status in ('verifying', 'removed'))) then
    raise exception 'set_tenant_domain_status: invalid transition % -> %', v_row.status, p_status using errcode = '22023';
  end if;
  update core.tenant_domains
     set status          = p_status,
         verification    = coalesce(p_verification, verification),
         last_error      = p_error,
         last_checked_at = now(),
         verified_at     = case when p_status = 'active' then now() else verified_at end,
         removed_at      = case when p_status = 'removed' then now() else removed_at end,
         is_primary      = case
                             when p_status <> 'active' then false
                             when exists (select 1 from core.tenant_domains d
                                           where d.org_id = v_row.org_id and d.app_id = v_row.app_id
                                             and d.status = 'active' and d.is_primary and d.id <> v_row.id) then false
                             else true end
   where id = p_domain_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'domain.status', 'tenant_domain', v_row.id::text, null, jsonb_build_object('status', p_status));
  return v_row;
end;
$$;


-- ---------------------------------------------------------------------
-- 12. RLS 와 권한
--   모놀리스(public)에서는 Supabase 가 anon/authenticated 에 기본 권한을 주므로 먼저 전부 회수한다.
-- ---------------------------------------------------------------------
alter table core.tenant_themes            enable row level security;
alter table core.tenant_settings          enable row level security;
alter table core.tenant_labels            enable row level security;
alter table core.tenant_feature_overrides enable row level security;
alter table core.tenant_domains           enable row level security;
alter table core.tenant_extensions        enable row level security;
alter table core.tenant_deployments       enable row level security;

revoke all on table core.tenant_themes, core.tenant_settings, core.tenant_labels, core.tenant_feature_overrides,
                    core.tenant_domains, core.tenant_extensions, core.tenant_deployments
  from public, anon, authenticated;
grant all on table core.tenant_themes, core.tenant_settings, core.tenant_labels, core.tenant_feature_overrides,
                   core.tenant_domains, core.tenant_extensions, core.tenant_deployments
  to service_role;

-- tenant_themes: 상태·버전·대비 결과·게시 정보는 컬럼 권한에서 빠져 있어 사용자가 쓸 수 없다
grant select on core.tenant_themes to authenticated;
grant insert (org_id, app_id, name, brand_name, logo_horizontal_path, logo_mark_path, logo_dark_path,
              favicon_path, og_image_path, email_header_path, tokens, fonts, source, created_by)
  on core.tenant_themes to authenticated;
grant update (name, brand_name, logo_horizontal_path, logo_mark_path, logo_dark_path,
              favicon_path, og_image_path, email_header_path, tokens, fonts, source)
  on core.tenant_themes to authenticated;
grant delete on core.tenant_themes to authenticated;

drop policy if exists tenant_themes_select on core.tenant_themes;
create policy tenant_themes_select on core.tenant_themes for select to authenticated
  using (core.is_org_member(org_id) or core.is_platform_admin());
drop policy if exists tenant_themes_insert on core.tenant_themes;
create policy tenant_themes_insert on core.tenant_themes for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and status = 'draft'
              and core.theming_level(org_id, app_id) >= 1);
drop policy if exists tenant_themes_update on core.tenant_themes;
create policy tenant_themes_update on core.tenant_themes for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and status = 'draft')
  with check (core.has_org_role(org_id, array['owner', 'admin']) and status = 'draft'
              and core.theming_level(org_id, app_id) >= 1);
drop policy if exists tenant_themes_delete on core.tenant_themes;
create policy tenant_themes_delete on core.tenant_themes for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and status = 'draft');

-- tenant_settings
grant select on core.tenant_settings to authenticated;
grant insert (org_id, app_id, support_email, support_url, email_from_name, default_locale, timezone,
              legal, footer_links, navigation, updated_by)
  on core.tenant_settings to authenticated;
grant update (support_email, support_url, email_from_name, default_locale, timezone,
              legal, footer_links, navigation, updated_by)
  on core.tenant_settings to authenticated;
grant delete on core.tenant_settings to authenticated;

drop policy if exists tenant_settings_select on core.tenant_settings;
create policy tenant_settings_select on core.tenant_settings for select to authenticated
  using (core.is_org_member(org_id) or core.is_platform_admin());
drop policy if exists tenant_settings_insert on core.tenant_settings;
create policy tenant_settings_insert on core.tenant_settings for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.theming_level(org_id, app_id) >= 1);
drop policy if exists tenant_settings_update on core.tenant_settings;
create policy tenant_settings_update on core.tenant_settings for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']))
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.theming_level(org_id, app_id) >= 1);
drop policy if exists tenant_settings_delete on core.tenant_settings;
create policy tenant_settings_delete on core.tenant_settings for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- tenant_labels (L2)
grant select on core.tenant_labels to authenticated;
grant insert (org_id, app_id, locale, key, value, updated_by) on core.tenant_labels to authenticated;
grant update (value, updated_by) on core.tenant_labels to authenticated;
grant delete on core.tenant_labels to authenticated;

drop policy if exists tenant_labels_select on core.tenant_labels;
create policy tenant_labels_select on core.tenant_labels for select to authenticated
  using (core.is_org_member(org_id) or core.is_platform_admin());
drop policy if exists tenant_labels_insert on core.tenant_labels;
create policy tenant_labels_insert on core.tenant_labels for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.theming_level(org_id, app_id) >= 2);
drop policy if exists tenant_labels_update on core.tenant_labels;
create policy tenant_labels_update on core.tenant_labels for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']))
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.theming_level(org_id, app_id) >= 2);
drop policy if exists tenant_labels_delete on core.tenant_labels;
create policy tenant_labels_delete on core.tenant_labels for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- 서버 전용 쓰기 테이블: 읽기만
grant select on core.tenant_feature_overrides, core.tenant_domains, core.tenant_deployments to authenticated;
grant select (id, org_id, app_id, slot_key, extension_key, kind, is_enabled, note, created_at, updated_at)
  on core.tenant_extensions to authenticated;   -- config 는 서버만

drop policy if exists tenant_feature_overrides_select on core.tenant_feature_overrides;
create policy tenant_feature_overrides_select on core.tenant_feature_overrides for select to authenticated
  using (core.is_org_member(org_id) or core.is_platform_admin());
drop policy if exists tenant_domains_select on core.tenant_domains;
create policy tenant_domains_select on core.tenant_domains for select to authenticated
  using (core.is_org_member(org_id) or core.is_platform_admin());
drop policy if exists tenant_extensions_select on core.tenant_extensions;
create policy tenant_extensions_select on core.tenant_extensions for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) or core.is_platform_admin());
drop policy if exists tenant_deployments_select on core.tenant_deployments;
create policy tenant_deployments_select on core.tenant_deployments for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) or core.is_platform_admin());

-- 함수 실행 권한: PUBLIC 기본 EXECUTE 를 회수하고 필요한 역할에만 준다
revoke execute on function core.is_valid_theme_tokens(jsonb)                       from public, anon, authenticated;
revoke execute on function core.is_valid_theme_fonts(jsonb)                        from public, anon, authenticated;
revoke execute on function core.is_theming_asset_path(uuid, text)                  from public, anon, authenticated;
revoke execute on function core.tenant_themes_guard()                              from public, anon, authenticated;
revoke execute on function core.theming_level_unchecked(uuid, text)                from public, anon, authenticated;
revoke execute on function core.theming_level(uuid, text)                          from public, anon, authenticated;
revoke execute on function core.effective_features(uuid, text)                     from public, anon, authenticated;
revoke execute on function core.resolve_tenant(text, text, text)                   from public, anon, authenticated;
revoke execute on function core.tenant_public_labels(uuid, text, text)             from public, anon, authenticated;
revoke execute on function core.publish_tenant_theme(uuid)                         from public, anon, authenticated;
revoke execute on function core.clone_tenant_theme(uuid)                           from public, anon, authenticated;
revoke execute on function core.request_tenant_domain(uuid, text, text)            from public, anon, authenticated;
revoke execute on function core.set_tenant_domain_status(uuid, text, jsonb, text)  from public, anon, authenticated;

-- CHECK 제약과 트리거 안에서 쓰는 검증 함수는 테이블에 쓰는 역할이 실행할 수 있어야 한다
grant execute on function core.is_valid_theme_tokens(jsonb)      to authenticated, service_role;
grant execute on function core.is_valid_theme_fonts(jsonb)       to authenticated, service_role;
grant execute on function core.is_theming_asset_path(uuid, text) to authenticated, service_role;
grant execute on function core.tenant_themes_guard()             to authenticated, service_role;

grant execute on function core.theming_level_unchecked(uuid, text)               to service_role;
grant execute on function core.theming_level(uuid, text)                         to authenticated, service_role;
grant execute on function core.effective_features(uuid, text)                    to authenticated, service_role;
grant execute on function core.resolve_tenant(text, text, text)                  to anon, authenticated, service_role;
grant execute on function core.tenant_public_labels(uuid, text, text)            to anon, authenticated, service_role;
grant execute on function core.publish_tenant_theme(uuid)                        to authenticated, service_role;
grant execute on function core.clone_tenant_theme(uuid)                          to authenticated, service_role;
grant execute on function core.request_tenant_domain(uuid, text, text)           to authenticated, service_role;
grant execute on function core.set_tenant_domain_status(uuid, text, jsonb, text) to service_role;
