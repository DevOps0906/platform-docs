-- =====================================================================
-- 0002_website_floria_domain.sql  (모놀리스, 스키마 public)
-- 원본: _supabase-modular/migrations/2200_site.sql 을 DB_CONVENTIONS.md 12장 규칙으로 변환한 것(core.->public., site.->public.).
-- 선행: 0001_core_lite.sql
--
-- 설계 요약 (05_DATA_MODEL.md)
--   - 사이트 콘텐츠(문구, 컬렉션, 이미지)는 DB에 두지 않는다. 저장소의 src/content/*.ts 가 정본이다.
--   - DB는 "방문자가 남기는 것"만 가진다: 문의(inquiries), 뉴스레터 구독(newsletter_subscribers),
--     그리고 한 백엔드를 여러 사이트가 공유하기 위한 사이트 등록부(sites).
--   - 방문자(anon)의 유일한 쓰기 경로는 submit_inquiry RPC 하나다. 테이블 권한은 anon에게 주지 않는다.
--     RPC 안에서 레이트 리밋(public.rate_limit_hit), 허니팟, 입력 검증, 스팸 점수를 처리한다.
--   - 구독 신청/확인/해지는 이메일 발송이 필요하므로 service_role 전용 RPC다(Route Handler가 호출).
--   - 문의 목록은 조직 멤버(viewer 제외)만 읽는다. 쓰기는 RPC 또는 service_role뿐이다(테이블 쓰기 정책 없음).
--
-- 보안 규칙 (SECURITY_BASELINE.md)
--   - SECURITY DEFINER 함수는 set search_path = '' 이고 모든 객체를 스키마 한정한다.
--   - anon/authenticated 에 EXECUTE를 연 함수 안에서 호출자 판정은 public.is_service_caller() 만 쓴다.
--     (public.is_privileged_session()은 DEFINER 안에서 항상 true라서 쓰지 않는다. 단, rate_limit_hit 내부의 검사는 코어 몫이다.)
--   - 역할 비교는 public.has_org_role(...)(exists 반환, NULL 없음) 또는 coalesce(role, '')로 한다.
--   - 사용자 정의 SQLSTATE: SI001 레이트 리밋 / SI002 사이트 없음·중지 / SI003 입력 오류 / SI004 동의 누락·정책 버전 불일치
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy) values ('site', 'Website Floria', 'site', 'invite')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 1. sites: 사이트 등록부 (floria, 추후 flora_sentiment 등이 같은 폼 백엔드를 공유)
--    쓰기는 provision_site(service_role) 와 update_site_settings(owner/admin)뿐이다.
-- ---------------------------------------------------------------------
create table if not exists public.sites (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations(id) on delete cascade,
  slug                   text not null unique
                         constraint sites_slug_check check (slug ~ '^[a-z][a-z0-9-]{1,38}[a-z0-9]$'),
  name                   text not null constraint sites_name_check check (char_length(name) between 1 and 80),
  brand_key              text not null default 'floria'
                         constraint sites_brand_key_check check (brand_key ~ '^[a-z][a-z0-9_]{1,30}$'),
  allowed_origins        text[] not null default '{}'
                         constraint sites_allowed_origins_check check (cardinality(allowed_origins) <= 10),
  notify_email           text
                         constraint sites_notify_email_check check (notify_email is null or (char_length(notify_email) <= 254 and notify_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  accepts_inquiries      boolean not null default true,
  accepts_newsletter     boolean not null default true,
  accepts_ai_chat        boolean not null default false,
  accepts_voice          boolean not null default false,
  inquiry_retention_days integer not null default 365
                         constraint sites_retention_check check (inquiry_retention_days between 30 and 1095),
  privacy_policy_version text not null default 'v1'
                         constraint sites_policy_version_check check (char_length(privacy_policy_version) between 1 and 32),
  status                 text not null default 'active'
                         constraint sites_status_check check (status in ('active', 'paused')),
  created_by             uuid,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint sites_voice_needs_chat_check check (not accepts_voice or accepts_ai_chat)
);
create index if not exists sites_org_idx on public.sites (org_id);
comment on column public.sites.inquiry_retention_days is '문의 보존 일수(제안 기본 365). spam 상태는 30일. purge_expired 가 삭제한다';
comment on column public.sites.privacy_policy_version is '폼이 보여 준 개인정보 수집 동의 문구의 버전. 다르면 SI004 로 거부한다';
comment on column public.sites.accepts_ai_chat is 'AI 상담(방문자 채팅) 스위치. 기본 false. update_ai_settings 로만 바꾼다';
comment on column public.sites.accepts_voice is '음성 상담 스위치. 기본 false. accepts_ai_chat 이 true 일 때만 true 가 될 수 있다';

drop trigger if exists sites_set_updated_at on public.sites;
create trigger sites_set_updated_at before update on public.sites
  for each row execute function public.set_updated_at();
drop trigger if exists sites_guard_write on public.sites;
create trigger sites_guard_write before insert or update or delete on public.sites
  for each row execute function public.guard_privileged_write();
alter table public.sites enable row level security;

-- ---------------------------------------------------------------------
-- 2. inquiries: 문의
--    상태: new -> read -> replied -> archived, new/read -> spam, spam -> new (오탐 복구)
--    전이는 트리거가 강제하고(service_role 쓰기 포함), 사용자는 set_inquiry_status RPC로만 바꾼다.
-- ---------------------------------------------------------------------
create table if not exists public.inquiries (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations(id) on delete cascade,
  site_id            uuid not null references public.sites(id) on delete cascade,
  kind               text not null
                     constraint inquiries_kind_check check (kind in ('custom_order', 'wedding', 'corporate', 'workshop', 'subscription', 'press', 'other')),
  name               text not null constraint inquiries_name_check check (char_length(name) between 1 and 80),
  email              text not null
                     constraint inquiries_email_check check (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  phone              text constraint inquiries_phone_check check (phone is null or phone ~ '^[0-9+() -]{6,30}$'),
  message            text not null constraint inquiries_message_check check (char_length(message) between 10 and 2000),
  locale             text not null default 'ko' constraint inquiries_locale_check check (locale in ('ko', 'en')),
  source_path        text constraint inquiries_source_path_check check (source_path is null or (char_length(source_path) <= 200 and source_path like '/%')),
  consent_version    text not null,
  consent_at         timestamptz not null default now(),
  status             text not null default 'new'
                     constraint inquiries_status_check check (status in ('new', 'read', 'replied', 'archived', 'spam')),
  spam_score         smallint not null default 0 constraint inquiries_spam_score_check check (spam_score between 0 and 100),
  spam_reasons       text[] not null default '{}',
  staff_note         text constraint inquiries_staff_note_check check (staff_note is null or char_length(staff_note) <= 1000),
  notified_at        timestamptz,
  read_at            timestamptz,
  replied_at         timestamptz,
  archived_at        timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists inquiries_site_status_idx on public.inquiries (site_id, status, created_at desc);
create index if not exists inquiries_org_created_idx on public.inquiries (org_id, created_at desc);
create index if not exists inquiries_created_idx on public.inquiries (created_at);
create index if not exists inquiries_notify_idx on public.inquiries (created_at) where notified_at is null and status = 'new';

drop trigger if exists inquiries_set_updated_at on public.inquiries;
create trigger inquiries_set_updated_at before update on public.inquiries
  for each row execute function public.set_updated_at();
drop trigger if exists inquiries_guard_write on public.inquiries;
create trigger inquiries_guard_write before insert or update or delete on public.inquiries
  for each row execute function public.guard_privileged_write();
alter table public.inquiries enable row level security;

create or replace function public.inquiry_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not (
         (old.status = 'new'      and new.status in ('read', 'replied', 'spam', 'archived'))
      or (old.status = 'read'     and new.status in ('new', 'replied', 'spam', 'archived'))
      or (old.status = 'replied'  and new.status = 'archived')
      or (old.status = 'archived' and new.status = 'read')
      or (old.status = 'spam'     and new.status = 'new')
    ) then
      raise exception 'inquiry: invalid status transition % -> %', old.status, new.status
        using errcode = '22023';
    end if;
    if new.status = 'read'     and new.read_at     is null then new.read_at     := now(); end if;
    if new.status = 'replied'  then new.replied_at  := now(); if new.read_at is null then new.read_at := now(); end if; end if;
    if new.status = 'archived' then new.archived_at := now(); end if;
    if new.status = 'new'      then new.read_at := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists inquiries_transition on public.inquiries;
create trigger inquiries_transition before update on public.inquiries
  for each row execute function public.inquiry_status_transition();

-- ---------------------------------------------------------------------
-- 3. newsletter_subscribers: 뉴스레터 구독 (이중 동의: pending -> confirmed)
--    토큰은 DB에 저장하지 않는다. 확인/해지 링크는 앱 서버가 HMAC(subscriber_id, 만료)로 서명한다(04_API).
--    해지 후 30일이 지나면 email 을 비우고 email_hash 만 남겨 재발송을 막는다(purge_expired).
--    상태: pending -> confirmed | unsubscribed, confirmed -> unsubscribed, unsubscribed -> pending (재구독)
-- ---------------------------------------------------------------------
create table if not exists public.newsletter_subscribers (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations(id) on delete cascade,
  site_id             uuid not null references public.sites(id) on delete cascade,
  email               text
                      constraint newsletter_email_check check (email is null or (char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  email_hash          text not null constraint newsletter_email_hash_check check (email_hash ~ '^[0-9a-f]{64}$'),
  locale              text not null default 'ko' constraint newsletter_locale_check check (locale in ('ko', 'en')),
  status              text not null default 'pending'
                      constraint newsletter_status_check check (status in ('pending', 'confirmed', 'unsubscribed')),
  consent_version     text not null,
  consent_at          timestamptz not null default now(),
  source_path         text constraint newsletter_source_path_check check (source_path is null or (char_length(source_path) <= 200 and source_path like '/%')),
  confirm_sent_at     timestamptz,
  confirm_sent_count  smallint not null default 0,
  confirmed_at        timestamptz,
  unsubscribed_at     timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint newsletter_email_present_check check (email is not null or status = 'unsubscribed'),
  unique (site_id, email_hash)
);
create index if not exists newsletter_org_status_idx on public.newsletter_subscribers (org_id, status, created_at desc);
create index if not exists newsletter_purge_idx on public.newsletter_subscribers (status, updated_at);

drop trigger if exists newsletter_set_updated_at on public.newsletter_subscribers;
create trigger newsletter_set_updated_at before update on public.newsletter_subscribers
  for each row execute function public.set_updated_at();
drop trigger if exists newsletter_guard_write on public.newsletter_subscribers;
create trigger newsletter_guard_write before insert or update or delete on public.newsletter_subscribers
  for each row execute function public.guard_privileged_write();
alter table public.newsletter_subscribers enable row level security;

create or replace function public.newsletter_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not (
         (old.status = 'pending'      and new.status in ('confirmed', 'unsubscribed'))
      or (old.status = 'confirmed'    and new.status = 'unsubscribed')
      or (old.status = 'unsubscribed' and new.status = 'pending')
    ) then
      raise exception 'newsletter: invalid status transition % -> %', old.status, new.status
        using errcode = '22023';
    end if;
    if new.status = 'confirmed'    then new.confirmed_at := now(); end if;
    if new.status = 'unsubscribed' then new.unsubscribed_at := now(); end if;
    if new.status = 'pending'      then new.confirmed_at := null; new.unsubscribed_at := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists newsletter_transition on public.newsletter_subscribers;
create trigger newsletter_transition before update on public.newsletter_subscribers
  for each row execute function public.newsletter_status_transition();

-- ---------------------------------------------------------------------
-- 4. RLS 정책: authenticated SELECT 만. 쓰기 정책 없음(RPC/service_role).
--    문의/구독자는 개인정보라 viewer 는 읽지 못한다(owner/admin/member).
-- ---------------------------------------------------------------------
drop policy if exists sites_select on public.sites;
create policy sites_select on public.sites for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'site'));

drop policy if exists inquiries_select on public.inquiries;
create policy inquiries_select on public.inquiries for select to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'site'));

drop policy if exists newsletter_select on public.newsletter_subscribers;
create policy newsletter_select on public.newsletter_subscribers for select to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'site'));

revoke all on public.sites, public.inquiries, public.newsletter_subscribers from public, anon, authenticated;
grant select on public.sites, public.inquiries, public.newsletter_subscribers to authenticated;

-- ---------------------------------------------------------------------
-- 5. 공개 RPC: submit_inquiry (anon, authenticated, service_role)
--    방문자가 쓸 수 있는 유일한 경로. 호출자 판정이 필요 없는 공개 함수라 is_service_caller 분기가 없다.
--    레이트 리밋(사이트 전체 100/시간 + 일 500, 이메일당 3/시간 + 6/일), 허니팟, 입력 검증, 스팸 점수.
--    IP 기준 제한과 CAPTCHA 는 앞단 Route Handler 의 몫이다(04_API). 여기서는 IP 를 받지도 저장하지도 않는다.
--    반환 형식은 접수/스팸 판정/허니팟 모두 같다(봇에게 판정 결과를 알리지 않는다).
-- ---------------------------------------------------------------------
create or replace function public.submit_inquiry(
  p_site_slug       text,
  p_kind            text,
  p_name            text,
  p_email           text,
  p_phone           text,
  p_message         text,
  p_locale          text,
  p_consent_version text,
  p_source_path     text default null,
  p_honeypot        text default null,
  p_elapsed_ms      integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_site     public.sites;
  v_email    text;
  v_name     text;
  v_message  text;
  v_phone    text;
  v_hash     text;
  v_ok       boolean;
  v_score    integer := 0;
  v_reasons  text[] := '{}';
  v_links    integer;
  v_id       uuid;
begin
  select * into v_site from public.sites where slug = lower(coalesce(p_site_slug, ''));
  if not found or v_site.status <> 'active' or not v_site.accepts_inquiries
     or not public.has_entitlement(v_site.org_id, 'site') then
    raise exception 'submit_inquiry: site unavailable' using errcode = 'SI002';
  end if;

  -- 1) 사이트 단위 홍수 방어 (검증보다 먼저: 쓰레기 요청도 센다)
  select r.allowed into v_ok from public.rate_limit_hit('site:inq:flood:' || v_site.id::text, 100, 3600) r;
  if not v_ok then
    raise exception 'submit_inquiry: rate limited' using errcode = 'SI001';
  end if;

  -- 2) 허니팟: 사람이 보지 못하는 입력이 채워졌으면 저장하지 않고 정상 응답처럼 끝낸다
  if coalesce(btrim(p_honeypot), '') <> '' then
    return jsonb_build_object('ok', true, 'reference', null);
  end if;

  -- 3) 입력 검증
  v_email   := lower(btrim(coalesce(p_email, '')));
  v_name    := btrim(coalesce(p_name, ''));
  v_message := btrim(coalesce(p_message, ''));
  v_phone   := nullif(btrim(coalesce(p_phone, '')), '');
  if p_kind is null or p_kind not in ('custom_order', 'wedding', 'corporate', 'workshop', 'subscription', 'press', 'other') then
    raise exception 'submit_inquiry: invalid kind' using errcode = 'SI003';
  end if;
  if char_length(v_name) not between 1 and 80
     or char_length(v_email) > 254 or v_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
     or char_length(v_message) not between 10 and 2000
     or (v_phone is not null and v_phone !~ '^[0-9+() -]{6,30}$')
     or coalesce(p_locale, '') not in ('ko', 'en')
     or (p_source_path is not null and (char_length(p_source_path) > 200 or p_source_path not like '/%')) then
    raise exception 'submit_inquiry: invalid input' using errcode = 'SI003';
  end if;
  if p_consent_version is distinct from v_site.privacy_policy_version then
    raise exception 'submit_inquiry: consent missing or outdated' using errcode = 'SI004';
  end if;

  -- 4) 이메일 단위 제한 (해시만 키로 쓴다)
  v_hash := encode(extensions.digest(convert_to(v_email, 'UTF8'), 'sha256'), 'hex');
  select r.allowed into v_ok from public.rate_limit_hit('site:inq:email:' || v_site.id::text || ':' || v_hash, 3, 3600) r;
  if not v_ok then
    raise exception 'submit_inquiry: rate limited' using errcode = 'SI001';
  end if;
  select r.allowed into v_ok from public.rate_limit_hit('site:inq:emailday:' || v_site.id::text || ':' || v_hash, 6, 86400) r;
  if not v_ok then
    raise exception 'submit_inquiry: rate limited' using errcode = 'SI001';
  end if;
  select r.allowed into v_ok from public.rate_limit_hit('site:inq:day:' || v_site.id::text, 500, 86400) r;
  if not v_ok then
    raise exception 'submit_inquiry: rate limited' using errcode = 'SI001';
  end if;

  -- 5) 스팸 점수 (60 이상이면 status = spam 으로 저장해 검토 가능하게 둔다)
  if p_elapsed_ms is null then
    v_score := v_score + 30; v_reasons := array_append(v_reasons, 'no_timing');
  elsif p_elapsed_ms < 3000 then
    v_score := v_score + 60; v_reasons := array_append(v_reasons, 'too_fast');
  end if;
  v_links := (char_length(v_message) - char_length(replace(lower(v_message), 'http', ''))) / 4;
  if v_links > 2 then
    v_score := v_score + 50; v_reasons := array_append(v_reasons, 'many_links');
  end if;
  if v_message ~* '<[a-z/!]' then
    v_score := v_score + 50; v_reasons := array_append(v_reasons, 'html_tags');
  end if;
  v_score := least(v_score, 100);

  insert into public.inquiries (org_id, site_id, kind, name, email, phone, message, locale, source_path,
                              consent_version, status, spam_score, spam_reasons)
  values (v_site.org_id, v_site.id, p_kind, v_name, v_email, v_phone, v_message, p_locale, p_source_path,
          p_consent_version, case when v_score >= 60 then 'spam' else 'new' end, v_score, v_reasons)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'reference', upper(left(replace(v_id::text, '-', ''), 8)));
end;
$$;
revoke execute on function public.submit_inquiry(text, text, text, text, text, text, text, text, text, text, integer) from public;
grant execute on function public.submit_inquiry(text, text, text, text, text, text, text, text, text, text, integer) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. 뉴스레터 RPC (service_role 전용: 확인 메일 발송이 필요하므로 Route Handler 가 호출한다)
--    반환값으로 구독 여부를 방문자에게 그대로 알리지 않는다(계정 열거 방지). 응답 문구는 핸들러가 항상 같게 만든다.
-- ---------------------------------------------------------------------
create or replace function public.subscribe_newsletter(
  p_site_slug       text,
  p_email           text,
  p_locale          text,
  p_consent_version text,
  p_source_path     text default null,
  p_honeypot        text default null,
  p_elapsed_ms      integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_site  public.sites;
  v_email text;
  v_hash  text;
  v_ok    boolean;
  v_row   public.newsletter_subscribers;
  v_send  boolean := false;
begin
  if not public.is_service_caller() then
    raise exception 'subscribe_newsletter: service_role only' using errcode = '42501';
  end if;
  select * into v_site from public.sites where slug = lower(coalesce(p_site_slug, ''));
  if not found or v_site.status <> 'active' or not v_site.accepts_newsletter
     or not public.has_entitlement(v_site.org_id, 'site') then
    raise exception 'subscribe_newsletter: site unavailable' using errcode = 'SI002';
  end if;
  select r.allowed into v_ok from public.rate_limit_hit('site:nl:flood:' || v_site.id::text, 200, 3600) r;
  if not v_ok then
    raise exception 'subscribe_newsletter: rate limited' using errcode = 'SI001';
  end if;
  if coalesce(btrim(p_honeypot), '') <> '' or (p_elapsed_ms is not null and p_elapsed_ms < 1500) then
    return jsonb_build_object('ok', true, 'subscriber_id', null, 'status', 'pending', 'send_confirmation', false);
  end if;
  v_email := lower(btrim(coalesce(p_email, '')));
  if char_length(v_email) > 254 or v_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
     or coalesce(p_locale, '') not in ('ko', 'en')
     or (p_source_path is not null and (char_length(p_source_path) > 200 or p_source_path not like '/%')) then
    raise exception 'subscribe_newsletter: invalid input' using errcode = 'SI003';
  end if;
  if p_consent_version is distinct from v_site.privacy_policy_version then
    raise exception 'subscribe_newsletter: consent missing or outdated' using errcode = 'SI004';
  end if;
  v_hash := encode(extensions.digest(convert_to(v_email, 'UTF8'), 'sha256'), 'hex');
  select r.allowed into v_ok from public.rate_limit_hit('site:nl:email:' || v_site.id::text || ':' || v_hash, 3, 3600) r;
  if not v_ok then
    raise exception 'subscribe_newsletter: rate limited' using errcode = 'SI001';
  end if;

  select * into v_row from public.newsletter_subscribers
   where site_id = v_site.id and email_hash = v_hash for update;
  if not found then
    insert into public.newsletter_subscribers (org_id, site_id, email, email_hash, locale, status, consent_version, source_path,
                                             confirm_sent_at, confirm_sent_count)
    values (v_site.org_id, v_site.id, v_email, v_hash, p_locale, 'pending', p_consent_version, p_source_path, now(), 1)
    returning * into v_row;
    v_send := true;
  elsif v_row.status = 'pending' then
    if v_row.confirm_sent_count < 5 then
      update public.newsletter_subscribers
         set confirm_sent_at = now(), confirm_sent_count = confirm_sent_count + 1,
             consent_version = p_consent_version, consent_at = now(), locale = p_locale
       where id = v_row.id returning * into v_row;
      v_send := true;
    end if;
  elsif v_row.status = 'unsubscribed' then
    update public.newsletter_subscribers
       set status = 'pending', email = v_email, locale = p_locale, consent_version = p_consent_version, consent_at = now(),
           source_path = p_source_path, confirm_sent_at = now(), confirm_sent_count = 1
     where id = v_row.id returning * into v_row;
    v_send := true;
  end if;
  -- confirmed: 변경 없음, 확인 메일도 보내지 않는다
  return jsonb_build_object('ok', true, 'subscriber_id', v_row.id, 'status', v_row.status, 'send_confirmation', v_send);
end;
$$;

create or replace function public.confirm_newsletter(p_subscriber_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.newsletter_subscribers;
begin
  if not public.is_service_caller() then
    raise exception 'confirm_newsletter: service_role only' using errcode = '42501';
  end if;
  select * into v_row from public.newsletter_subscribers where id = p_subscriber_id for update;
  if not found then
    raise exception 'confirm_newsletter: not found' using errcode = 'P0002';
  end if;
  if v_row.status = 'pending' then
    update public.newsletter_subscribers set status = 'confirmed' where id = v_row.id returning * into v_row;
    return jsonb_build_object('ok', true, 'status', v_row.status, 'changed', true);
  end if;
  return jsonb_build_object('ok', true, 'status', v_row.status, 'changed', false);   -- confirmed: 멱등, unsubscribed: 되살리지 않는다
end;
$$;

create or replace function public.unsubscribe_newsletter(p_subscriber_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.newsletter_subscribers;
begin
  if not public.is_service_caller() then
    raise exception 'unsubscribe_newsletter: service_role only' using errcode = '42501';
  end if;
  select * into v_row from public.newsletter_subscribers where id = p_subscriber_id for update;
  if not found then
    raise exception 'unsubscribe_newsletter: not found' using errcode = 'P0002';
  end if;
  if v_row.status in ('pending', 'confirmed') then
    update public.newsletter_subscribers set status = 'unsubscribed' where id = v_row.id returning * into v_row;
    return jsonb_build_object('ok', true, 'status', v_row.status, 'changed', true);
  end if;
  return jsonb_build_object('ok', true, 'status', v_row.status, 'changed', false);
end;
$$;

-- ---------------------------------------------------------------------
-- 7. 운영 RPC (authenticated: 조직 멤버). 안에서 is_service_caller + 역할 검사 + 엔타이틀먼트.
-- ---------------------------------------------------------------------
create or replace function public.set_inquiry_status(p_id uuid, p_to text, p_note text default null)
returns public.inquiries
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.inquiries; v_from text;
begin
  select * into v_row from public.inquiries where id = p_id for update;
  if not found then
    raise exception 'set_inquiry_status: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'set_inquiry_status: not a member' using errcode = '42501';
  end if;
  if not public.is_service_caller() and not public.has_entitlement(v_row.org_id, 'site') then
    raise exception 'set_inquiry_status: no entitlement' using errcode = '42501';
  end if;
  if p_to is null or p_to not in ('new', 'read', 'replied', 'archived', 'spam') then
    raise exception 'set_inquiry_status: invalid status %', p_to using errcode = '22023';
  end if;
  if p_note is not null and char_length(p_note) > 1000 then
    raise exception 'set_inquiry_status: note too long' using errcode = '22023';
  end if;
  v_from := v_row.status;
  update public.inquiries set status = p_to, staff_note = coalesce(p_note, staff_note)
   where id = p_id returning * into v_row;
  if v_from is distinct from v_row.status then
    perform public.write_audit(v_row.org_id, 'inquiry.status', 'inquiry', p_id::text,
                             jsonb_build_object('status', v_from), jsonb_build_object('status', v_row.status));
  end if;
  return v_row;
end;
$$;

create or replace function public.delete_inquiry(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.inquiries;
begin
  select * into v_row from public.inquiries where id = p_id for update;
  if not found then
    raise exception 'delete_inquiry: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'delete_inquiry: owner/admin only' using errcode = '42501';
  end if;
  delete from public.inquiries where id = p_id;
  -- 감사 로그에는 개인정보를 남기지 않는다(종류, 상태, 접수일만)
  perform public.write_audit(v_row.org_id, 'inquiry.delete', 'inquiry', p_id::text,
                           jsonb_build_object('kind', v_row.kind, 'status', v_row.status, 'created_at', v_row.created_at), null);
end;
$$;

-- 구독자 삭제 요청: 이메일 원문을 지우고 해시와 해지 상태만 남긴다(재발송 방지용 수신거부 이력)
create or replace function public.erase_subscriber(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.newsletter_subscribers;
begin
  select * into v_row from public.newsletter_subscribers where id = p_id for update;
  if not found then
    raise exception 'erase_subscriber: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'erase_subscriber: owner/admin only' using errcode = '42501';
  end if;
  if v_row.status <> 'unsubscribed' then
    update public.newsletter_subscribers set status = 'unsubscribed' where id = p_id;
  end if;
  update public.newsletter_subscribers set email = null where id = p_id;
  perform public.write_audit(v_row.org_id, 'subscriber.erase', 'subscriber', p_id::text,
                           jsonb_build_object('status', v_row.status), jsonb_build_object('status', 'unsubscribed'));
end;
$$;

create or replace function public.update_site_settings(
  p_site_id                uuid,
  p_name                   text    default null,
  p_notify_email           text    default null,
  p_accepts_inquiries      boolean default null,
  p_accepts_newsletter     boolean default null,
  p_privacy_policy_version text    default null
)
returns public.sites
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.sites; v_before jsonb;
begin
  select * into v_row from public.sites where id = p_site_id for update;
  if not found then
    raise exception 'update_site_settings: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'update_site_settings: owner/admin only' using errcode = '42501';
  end if;
  if not public.is_service_caller() and not public.has_entitlement(v_row.org_id, 'site') then
    raise exception 'update_site_settings: no entitlement' using errcode = '42501';
  end if;
  v_before := jsonb_build_object('name', v_row.name, 'accepts_inquiries', v_row.accepts_inquiries,
                                 'accepts_newsletter', v_row.accepts_newsletter, 'privacy_policy_version', v_row.privacy_policy_version);
  update public.sites
     set name                   = coalesce(p_name, name),
         notify_email           = coalesce(p_notify_email, notify_email),
         accepts_inquiries      = coalesce(p_accepts_inquiries, accepts_inquiries),
         accepts_newsletter     = coalesce(p_accepts_newsletter, accepts_newsletter),
         privacy_policy_version = coalesce(p_privacy_policy_version, privacy_policy_version)
   where id = p_site_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'public.settings', 'site', p_site_id::text, v_before,
                           jsonb_build_object('name', v_row.name, 'accepts_inquiries', v_row.accepts_inquiries,
                                              'accepts_newsletter', v_row.accepts_newsletter, 'privacy_policy_version', v_row.privacy_policy_version));
  return v_row;
end;
$$;

-- AI 상담(방문자 채팅)과 음성 상담의 사이트별 스위치. 기본은 꺼짐(운영자가 켠다). 상담을 끄면 음성도 함께 끈다.
-- update_site_settings 의 시그니처를 바꾸지 않으려고 별도 함수로 둔다. AI 기능 키와 라우팅은 11절이 정한다.
create or replace function public.update_ai_settings(
  p_site_id          uuid,
  p_accepts_ai_chat  boolean default null,
  p_accepts_voice    boolean default null
)
returns public.sites
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.sites; v_before jsonb; v_chat boolean; v_voice boolean;
begin
  select * into v_row from public.sites where id = p_site_id for update;
  if not found then
    raise exception 'update_ai_settings: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'update_ai_settings: owner/admin only' using errcode = '42501';
  end if;
  if not public.is_service_caller() and not public.has_entitlement(v_row.org_id, 'site') then
    raise exception 'update_ai_settings: no entitlement' using errcode = '42501';
  end if;
  v_before := jsonb_build_object('accepts_ai_chat', v_row.accepts_ai_chat, 'accepts_voice', v_row.accepts_voice);
  v_chat  := coalesce(p_accepts_ai_chat, v_row.accepts_ai_chat);
  v_voice := coalesce(p_accepts_voice, v_row.accepts_voice) and v_chat;
  update public.sites set accepts_ai_chat = v_chat, accepts_voice = v_voice
   where id = p_site_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'site.ai_settings', 'site', p_site_id::text, v_before,
                           jsonb_build_object('accepts_ai_chat', v_row.accepts_ai_chat, 'accepts_voice', v_row.accepts_voice));
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 8. 운영 RPC (service_role 전용): 사이트 등록, 만료 정리
-- ---------------------------------------------------------------------
create or replace function public.provision_site(
  p_org_id          uuid,
  p_slug            text,
  p_name            text,
  p_brand_key       text    default 'floria',
  p_allowed_origins text[]  default '{}',
  p_notify_email    text    default null
)
returns public.sites
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.sites;
begin
  if not public.is_service_caller() then
    raise exception 'provision_site: service_role only' using errcode = '42501';
  end if;
  if not public.has_entitlement(p_org_id, 'site') then
    raise exception 'provision_site: organization has no site entitlement' using errcode = '42501';
  end if;
  insert into public.sites (org_id, slug, name, brand_key, allowed_origins, notify_email)
  values (p_org_id, lower(p_slug), p_name, p_brand_key, coalesce(p_allowed_origins, '{}'), p_notify_email)
  returning * into v_row;
  perform public.write_audit(p_org_id, 'public.provision', 'site', v_row.id::text, null,
                           jsonb_build_object('slug', v_row.slug, 'brand_key', v_row.brand_key));
  return v_row;
end;
$$;

-- 매일 실행 (pg_cron 또는 워커, service_role). 반환: 삭제/비식별화 건수
create or replace function public.purge_expired()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_inq integer; v_pending integer; v_unsub integer;
begin
  if not public.is_service_caller() then
    raise exception 'purge_expired: service_role only' using errcode = '42501';
  end if;
  delete from public.inquiries i using public.sites s
   where i.site_id = s.id
     and ((i.status = 'spam' and i.created_at < now() - interval '30 days')
          or i.created_at < now() - make_interval(days => s.inquiry_retention_days));
  get diagnostics v_inq = row_count;
  delete from public.newsletter_subscribers where status = 'pending' and created_at < now() - interval '7 days';
  get diagnostics v_pending = row_count;
  update public.newsletter_subscribers set email = null
   where status = 'unsubscribed' and email is not null and unsubscribed_at < now() - interval '30 days';
  get diagnostics v_unsub = row_count;
  if v_inq + v_pending + v_unsub > 0 then
    perform public.write_audit(null, 'public.purge', 'site', null, null,
                             jsonb_build_object('inquiries', v_inq, 'pending_subscribers', v_pending, 'anonymized_subscribers', v_unsub));
  end if;
  return jsonb_build_object('inquiries', v_inq, 'pending_subscribers', v_pending, 'anonymized_subscribers', v_unsub);
end;
$$;

-- ---------------------------------------------------------------------
-- 9. EXECUTE 정리: PUBLIC 회수 후 허용 목록만
--    anon, authenticated, service_role : submit_inquiry (위 5절)
--    authenticated, service_role       : set_inquiry_status, delete_inquiry, erase_subscriber, update_site_settings, update_ai_settings
--    service_role 전용                 : subscribe/confirm/unsubscribe_newsletter, provision_site, purge_expired
-- ---------------------------------------------------------------------
revoke execute on function public.set_inquiry_status(uuid, text, text) from public, anon;
revoke execute on function public.delete_inquiry(uuid) from public, anon;
revoke execute on function public.erase_subscriber(uuid) from public, anon;
revoke execute on function public.update_site_settings(uuid, text, text, boolean, boolean, text) from public, anon;
grant execute on function public.set_inquiry_status(uuid, text, text) to authenticated;
grant execute on function public.delete_inquiry(uuid) to authenticated;
grant execute on function public.erase_subscriber(uuid) to authenticated;
grant execute on function public.update_site_settings(uuid, text, text, boolean, boolean, text) to authenticated;
revoke execute on function public.update_ai_settings(uuid, boolean, boolean) from public, anon;
grant execute on function public.update_ai_settings(uuid, boolean, boolean) to authenticated;

revoke execute on function public.subscribe_newsletter(text, text, text, text, text, text, integer) from public, anon, authenticated;
revoke execute on function public.confirm_newsletter(uuid) from public, anon, authenticated;
revoke execute on function public.unsubscribe_newsletter(uuid) from public, anon, authenticated;
revoke execute on function public.provision_site(uuid, text, text, text, text[], text) from public, anon, authenticated;
revoke execute on function public.purge_expired() from public, anon, authenticated;
grant execute on function public.subscribe_newsletter(text, text, text, text, text, text, integer) to service_role;
grant execute on function public.confirm_newsletter(uuid) to service_role;
grant execute on function public.unsubscribe_newsletter(uuid) to service_role;
grant execute on function public.provision_site(uuid, text, text, text, text[], text) to service_role;
grant execute on function public.purge_expired() to service_role;

-- 트리거 함수는 직접 호출할 수 없지만(반환형 trigger) 노출 면적을 줄이기 위해 PUBLIC EXECUTE도 회수한다.
-- 참고: 위 머리의 "alter default privileges in schema site revoke execute ... from public"만으로는 PUBLIC 기본 EXECUTE가
--       빠지지 않는다(스키마 한정 기본권한은 전역 기본값을 취소하지 못한다). 그래서 모든 함수에 명시적 revoke를 둔다.
revoke execute on function public.inquiry_status_transition() from public, anon, authenticated;
revoke execute on function public.newsletter_status_transition() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 10. 스케줄 (호스팅에서 pg_cron을 켠 뒤 등록. 로컬 검증에서는 실행하지 않는다)
--   매일 03:30 KST (30 18 * * * UTC): select public.purge_expired();
--   -- select cron.schedule('site-purge-expired', '30 18 * * *', $$select public.purge_expired()$$);
-- 문의 알림 메일은 DB 함수가 아니라 워커가 처리한다:
--   select id, site_id from public.inquiries where notified_at is null and status = 'new' order by created_at limit 50;
--   (service_role) 발송 후 update public.inquiries set notified_at = now() where id = any(:ids);
-- ---------------------------------------------------------------------
