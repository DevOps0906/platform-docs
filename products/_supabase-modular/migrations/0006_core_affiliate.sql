-- =====================================================================
-- 0006_core_affiliate.sql
-- 제휴마케팅 공용 모듈(확정 결정 12). video와 blog가 함께 쓴다.
--   제공자: 쿠팡파트너스, 네이버 브랜드커넥트, 텐핑, 네이버쇼핑 커넥트(어댑터로 추가 가능)
--   - affiliate_accounts       : org별 제공자 연결(키/세션은 encrypted_credentials에만)
--   - affiliate_links          : 제휴 링크 + 단축 코드(/r/[code])
--   - affiliate_clicks         : 클릭 로그(service_role만 기록)
--   - affiliate_disclosures    : 대가성 문구 템플릿(org_id null = 플랫폼 기본값)
--   - brandconnect_applications: 네이버 브랜드커넥트 자동 지원 상태
--
-- 원칙(0000~0005와 같음)
--   - 쓰기는 service_role 또는 SECURITY DEFINER 함수만. 사용자에게는 SELECT 정책만 준다.
--   - 대가성 문구는 끌 수 없다. 편집만 허용하고, 빈 문구는 거부한다.
--   - 브랜드커넥트 완전 자동 지원은 네이버 약관 위반/계정 정지 위험이 있어,
--     owner/admin의 위험 동의(risk_consented_at)가 없으면 지원서를 만들 수 없다.
--   - 텐핑/네이버쇼핑 커넥트는 공개 API 여부 미확인. 어댑터 구현 방식은 앱 계층에서 결정한다.
--   - 사용자에게 EXECUTE를 연 SECURITY DEFINER 함수는 호출자 판정에 core.is_service_caller()를 쓴다(0000 참조).
-- 선행: 0000 ~ 0005
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. affiliate_accounts
-- ---------------------------------------------------------------------
create table if not exists core.affiliate_accounts (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  provider           text not null
                     constraint affiliate_accounts_provider_check
                     check (provider in ('coupang', 'naver_brandconnect', 'tenping', 'naver_shopping_connect')),
  credential_id      uuid references core.encrypted_credentials(id) on delete set null,
  partner_id         text,                       -- 쿠팡 파트너스 ID 등 비밀이 아닌 식별자
  label              text,
  status             text not null default 'active'
                     constraint affiliate_accounts_status_check check (status in ('active', 'paused', 'error', 'revoked')),
  risk_consented_at  timestamptz,                -- 브랜드커넥트 자동 지원 위험 동의 시각
  risk_consented_by  uuid,
  last_error         text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (org_id, provider, partner_id)
);
create index if not exists affiliate_accounts_org_idx on core.affiliate_accounts (org_id, provider);
drop trigger if exists affiliate_accounts_set_updated_at on core.affiliate_accounts;
create trigger affiliate_accounts_set_updated_at before update on core.affiliate_accounts
  for each row execute function core.set_updated_at();
drop trigger if exists affiliate_accounts_guard_write on core.affiliate_accounts;
create trigger affiliate_accounts_guard_write before insert or update or delete on core.affiliate_accounts
  for each row execute function core.guard_privileged_write();
alter table core.affiliate_accounts enable row level security;

-- ---------------------------------------------------------------------
-- 2. affiliate_links
-- ---------------------------------------------------------------------
create table if not exists core.affiliate_links (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  account_id     uuid references core.affiliate_accounts(id) on delete set null,
  provider       text not null
                 constraint affiliate_links_provider_check
                 check (provider in ('coupang', 'naver_brandconnect', 'tenping', 'naver_shopping_connect')),
  source_app     text not null references core.apps(id)
                 constraint affiliate_links_source_app_check check (source_app in ('video', 'blog')),
  source_ref     text,                           -- 예: video upload id, blog post id
  product_name   text,
  original_url   text not null,
  affiliate_url  text not null,
  short_code     text not null unique,
  utm            jsonb not null default '{}'::jsonb,
  click_count    bigint not null default 0,      -- affiliate_clicks 집계 캐시
  is_active      boolean not null default true,
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint affiliate_links_url_check check (original_url ~* '^https?://' and affiliate_url ~* '^https?://')
);
create index if not exists affiliate_links_org_idx on core.affiliate_links (org_id, created_at desc);
create index if not exists affiliate_links_source_idx on core.affiliate_links (source_app, source_ref);
drop trigger if exists affiliate_links_set_updated_at on core.affiliate_links;
create trigger affiliate_links_set_updated_at before update on core.affiliate_links
  for each row execute function core.set_updated_at();
drop trigger if exists affiliate_links_guard_write on core.affiliate_links;
create trigger affiliate_links_guard_write before insert or update or delete on core.affiliate_links
  for each row execute function core.guard_privileged_write();
alter table core.affiliate_links enable row level security;

-- ---------------------------------------------------------------------
-- 3. affiliate_clicks: 리다이렉트 라우트(/r/[code])가 service_role로 기록한다.
--    개인정보 최소화: IP 원문 대신 일 단위 솔트 해시만 저장.
-- ---------------------------------------------------------------------
create table if not exists core.affiliate_clicks (
  id          bigint generated always as identity primary key,
  link_id     uuid not null references core.affiliate_links(id) on delete cascade,
  org_id      uuid not null references core.organizations(id) on delete cascade,
  clicked_at  timestamptz not null default now(),
  referrer    text,
  ip_hash     text,
  user_agent  text,
  country     text
);
create index if not exists affiliate_clicks_link_idx on core.affiliate_clicks (link_id, clicked_at desc);
create index if not exists affiliate_clicks_org_idx on core.affiliate_clicks (org_id, clicked_at desc);
drop trigger if exists affiliate_clicks_guard_write on core.affiliate_clicks;
create trigger affiliate_clicks_guard_write before insert or update or delete on core.affiliate_clicks
  for each row execute function core.guard_privileged_write();
alter table core.affiliate_clicks enable row level security;

-- ---------------------------------------------------------------------
-- 4. affiliate_disclosures: 대가성 문구. 끄는 컬럼은 두지 않는다.
--    org_id null 행은 플랫폼 기본값(seed). org 행이 있으면 그것을 우선한다.
--    placement: blog_top(글 상단), video_description(설명란 첫 줄), video_pinned_comment
-- ---------------------------------------------------------------------
create table if not exists core.affiliate_disclosures (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid references core.organizations(id) on delete cascade,
  provider    text not null
              constraint affiliate_disclosures_provider_check
              check (provider in ('coupang', 'naver_brandconnect', 'tenping', 'naver_shopping_connect')),
  placement   text not null
              constraint affiliate_disclosures_placement_check
              check (placement in ('blog_top', 'video_description', 'video_pinned_comment')),
  body        text not null constraint affiliate_disclosures_body_check check (length(btrim(body)) >= 10),
  updated_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index if not exists affiliate_disclosures_org_uniq
  on core.affiliate_disclosures (org_id, provider, placement) where org_id is not null;
create unique index if not exists affiliate_disclosures_default_uniq
  on core.affiliate_disclosures (provider, placement) where org_id is null;
drop trigger if exists affiliate_disclosures_set_updated_at on core.affiliate_disclosures;
create trigger affiliate_disclosures_set_updated_at before update on core.affiliate_disclosures
  for each row execute function core.set_updated_at();
drop trigger if exists affiliate_disclosures_guard_write on core.affiliate_disclosures;
create trigger affiliate_disclosures_guard_write before insert or update or delete on core.affiliate_disclosures
  for each row execute function core.guard_privileged_write();
alter table core.affiliate_disclosures enable row level security;

-- ---------------------------------------------------------------------
-- 5. brandconnect_applications: 네이버 브랜드커넥트 자동 지원(blog 소유)
--    상태 전이: draft → submitting → submitted → accepted | rejected
--               submitting → failed → (재시도) submitting
--    실제 제출은 core.jobs(job_type = 'brandconnect.apply')로 워커가 처리한다.
-- ---------------------------------------------------------------------
create table if not exists core.brandconnect_applications (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  account_id      uuid not null references core.affiliate_accounts(id) on delete cascade,
  campaign_id     text not null,
  brand_name      text,
  product_name    text,
  category        text,
  blog_url        text not null,
  message         text,
  status          text not null default 'draft'
                  constraint brandconnect_applications_status_check
                  check (status in ('draft', 'submitting', 'submitted', 'accepted', 'rejected', 'failed')),
  attempts        integer not null default 0,
  job_id          uuid references core.jobs(id) on delete set null,
  external_id     text,
  last_error      text,
  submitted_at    timestamptz,
  decided_at      timestamptz,
  created_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (account_id, campaign_id)
);
create index if not exists brandconnect_applications_org_idx on core.brandconnect_applications (org_id, created_at desc);
drop trigger if exists brandconnect_applications_set_updated_at on core.brandconnect_applications;
create trigger brandconnect_applications_set_updated_at before update on core.brandconnect_applications
  for each row execute function core.set_updated_at();
drop trigger if exists brandconnect_applications_guard_write on core.brandconnect_applications;
create trigger brandconnect_applications_guard_write before insert or update or delete on core.brandconnect_applications
  for each row execute function core.guard_privileged_write();
alter table core.brandconnect_applications enable row level security;

-- 상태 전이 검증(service_role 쓰기에도 적용)
create or replace function core.brandconnect_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not (
         (old.status = 'draft'      and new.status = 'submitting')
      or (old.status = 'submitting' and new.status in ('submitted', 'failed'))
      or (old.status = 'failed'     and new.status = 'submitting')
      or (old.status = 'submitted'  and new.status in ('accepted', 'rejected'))
    ) then
      raise exception 'brandconnect: invalid status transition % -> %', old.status, new.status
        using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists brandconnect_applications_transition on core.brandconnect_applications;
create trigger brandconnect_applications_transition before update on core.brandconnect_applications
  for each row execute function core.brandconnect_status_transition();

-- ---------------------------------------------------------------------
-- 6. 함수
-- ---------------------------------------------------------------------

-- 단축 코드 생성(충돌 시 재시도). service_role이 링크를 만들 때 사용.
create or replace function core.new_affiliate_short_code(p_len integer default 8)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := 'abcdefghijkmnpqrstuvwxyz23456789';
  v_code text;
  v_bytes bytea;
  i integer;
begin
  for attempt in 1..5 loop
    v_bytes := extensions.gen_random_bytes(p_len);
    v_code := '';
    for i in 0..p_len - 1 loop
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % length(v_alphabet)) + 1, 1);
    end loop;
    if not exists (select 1 from core.affiliate_links where short_code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception 'new_affiliate_short_code: collision retries exhausted';
end;
$$;

-- 리다이렉트 라우트용: 클릭 기록 + 대상 URL 반환(service_role 전용)
create or replace function core.record_affiliate_click(
  p_short_code text, p_referrer text default null, p_ip_hash text default null,
  p_user_agent text default null, p_country text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_link core.affiliate_links;
begin
  if not core.is_service_caller() then
    raise exception 'record_affiliate_click: service_role only' using errcode = '42501';
  end if;
  select * into v_link from core.affiliate_links where short_code = p_short_code and is_active;
  if v_link.id is null then
    return null;
  end if;
  insert into core.affiliate_clicks (link_id, org_id, referrer, ip_hash, user_agent, country)
  values (v_link.id, v_link.org_id, left(p_referrer, 500), p_ip_hash, left(p_user_agent, 300), p_country);
  update core.affiliate_links set click_count = click_count + 1 where id = v_link.id;
  return v_link.affiliate_url;
end;
$$;

-- 유효 대가성 문구 조회: org 문구가 있으면 그것, 없으면 플랫폼 기본값
create or replace function core.effective_disclosure(p_org_id uuid, p_provider text, p_placement text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select d.body
  from core.affiliate_disclosures d
  where d.provider = p_provider and d.placement = p_placement
    and (d.org_id = p_org_id or d.org_id is null)
    and (core.is_service_caller() or core.is_org_member(p_org_id))
  order by (d.org_id is null)   -- org 행 우선
  limit 1;
$$;
grant execute on function core.effective_disclosure(uuid, text, text) to authenticated;

-- 문구 편집(owner/admin). 끄기는 불가, 빈 문구는 CHECK로 거부.
create or replace function core.upsert_affiliate_disclosure(
  p_org_id uuid, p_provider text, p_placement text, p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if not core.is_service_caller() and not core.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'upsert_affiliate_disclosure: owner/admin only' using errcode = '42501';
  end if;
  insert into core.affiliate_disclosures (org_id, provider, placement, body, updated_by)
  values (p_org_id, p_provider, p_placement, p_body, auth.uid())
  on conflict (org_id, provider, placement) where org_id is not null
  do update set body = excluded.body, updated_by = excluded.updated_by
  returning id into v_id;
  perform core.write_audit(p_org_id, 'affiliate.disclosure.upsert', 'affiliate_disclosure', v_id::text);
  return v_id;
end;
$$;
grant execute on function core.upsert_affiliate_disclosure(uuid, text, text, text) to authenticated;

-- 브랜드커넥트 자동 지원 위험 동의(owner/admin)
create or replace function core.consent_brandconnect_risk(p_account_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid; v_provider text;
begin
  select org_id, provider into v_org, v_provider from core.affiliate_accounts where id = p_account_id;
  if v_org is null or v_provider <> 'naver_brandconnect' then
    raise exception 'consent_brandconnect_risk: not a brandconnect account' using errcode = '22023';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_org, array['owner', 'admin']) then
    raise exception 'consent_brandconnect_risk: owner/admin only' using errcode = '42501';
  end if;
  update core.affiliate_accounts
     set risk_consented_at = now(), risk_consented_by = auth.uid()
   where id = p_account_id;
  perform core.write_audit(v_org, 'affiliate.brandconnect.risk_consent', 'affiliate_account', p_account_id::text);
end;
$$;
grant execute on function core.consent_brandconnect_risk(uuid) to authenticated;

-- 브랜드커넥트 지원서 생성(멤버). 위험 동의 없으면 거부. 제출은 service_role 워커가 한다.
create or replace function core.create_brandconnect_application(
  p_account_id uuid, p_campaign_id text, p_blog_url text,
  p_brand_name text default null, p_product_name text default null,
  p_category text default null, p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_acc core.affiliate_accounts; v_id uuid;
begin
  select * into v_acc from core.affiliate_accounts where id = p_account_id;
  if v_acc.id is null or v_acc.provider <> 'naver_brandconnect' then
    raise exception 'create_brandconnect_application: not a brandconnect account' using errcode = '22023';
  end if;
  if not core.is_service_caller() and not core.is_org_member(v_acc.org_id) then
    raise exception 'create_brandconnect_application: not a member' using errcode = '42501';
  end if;
  if v_acc.risk_consented_at is null then
    raise exception 'create_brandconnect_application: risk consent required' using errcode = '42501';
  end if;
  if v_acc.status <> 'active' then
    raise exception 'create_brandconnect_application: account is %', v_acc.status using errcode = '22023';
  end if;
  insert into core.brandconnect_applications
    (org_id, account_id, campaign_id, brand_name, product_name, category, blog_url, message, created_by)
  values
    (v_acc.org_id, p_account_id, p_campaign_id, p_brand_name, p_product_name, p_category, p_blog_url, p_message, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function core.create_brandconnect_application(uuid, text, text, text, text, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 7. 권한과 RLS 정책 (SELECT만)
-- ---------------------------------------------------------------------
grant select on core.affiliate_accounts, core.affiliate_links, core.affiliate_clicks,
                core.affiliate_disclosures, core.brandconnect_applications to authenticated;

drop policy if exists affiliate_accounts_select on core.affiliate_accounts;
create policy affiliate_accounts_select on core.affiliate_accounts for select to authenticated
  using (core.is_org_member(org_id));

drop policy if exists affiliate_links_select on core.affiliate_links;
create policy affiliate_links_select on core.affiliate_links for select to authenticated
  using (core.is_org_member(org_id));

drop policy if exists affiliate_clicks_select on core.affiliate_clicks;
create policy affiliate_clicks_select on core.affiliate_clicks for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

drop policy if exists affiliate_disclosures_select on core.affiliate_disclosures;
create policy affiliate_disclosures_select on core.affiliate_disclosures for select to authenticated
  using (org_id is null or core.is_org_member(org_id));

drop policy if exists brandconnect_applications_select on core.brandconnect_applications;
create policy brandconnect_applications_select on core.brandconnect_applications for select to authenticated
  using (core.is_org_member(org_id));
