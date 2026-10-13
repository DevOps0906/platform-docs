-- =====================================================================
-- 1300_blog.sql
-- nomad-blog 도메인(AI 블로그 원고 + 네이버/티스토리/워드프레스 발행 + 제휴 링크 매핑).
-- 선행: core 0000 ~ 0006. seed.sql 은 선택(이 파일이 apps 행과 blog 플랜을 do nothing 으로 넣는다).
--
-- 테이블
--   blog.channel_accounts      : 발행 채널 계정(네이버/티스토리/워드프레스/인스타그램). 비밀은 core.encrypted_credentials 에만.
--   blog.posts                 : 원고. 사용자는 콘텐츠 컬럼만 쓴다(컬럼 GRANT). 상태/검사/렌더 결과는 서버만.
--   blog.post_affiliate_links  : 원고 <-> core.affiliate_links 매핑. 제휴 테이블 자체는 core 에 있다(확정 결정 12).
--   blog.post_publications     : 원고 x 채널 계정 발행 1건. 상태 전이 트리거, 대가성 문구 불변식, 컴플라이언스 게이트.
--
-- 보안 규칙(SECURITY_BASELINE.md)
--   - 사용자에게 EXECUTE 를 연 SECURITY DEFINER 함수는 호출자 판정에 core.is_service_caller() 만 쓴다.
--   - 역할 비교는 core.has_org_role()(exists, NULL 없음) 또는 coalesce(role, '') 로 한다.
--   - 상태/외부 발행 결과가 있는 테이블(channel_accounts, post_affiliate_links, post_publications)은
--     SELECT 정책만 주고 core.guard_privileged_write 로 이중 잠금한다.
--   - 크레딧 차감은 이 파일에 없다. Route Handler/워커가 service_role 로 core.consume_credits 를 호출한다.
-- SQLSTATE(제품): BL001 상태 불가, BL002 취소 불가, BL003 컴플라이언스 미통과, BL005 채널 사용 불가(동의/상태)
-- 반복 실행 가능.
-- =====================================================================

create schema if not exists blog;
grant usage on schema blog to anon, authenticated, service_role;
alter default privileges in schema blog grant all on tables to service_role;
alter default privileges in schema blog grant all on sequences to service_role;
alter default privileges in schema blog grant execute on functions to service_role;
alter default privileges in schema blog revoke execute on functions from public;

-- ---------------------------------------------------------------------
-- 0. 앱 등록과 플랜(정본: docs/products/nomad-blog/01_PRD.md 4장)
--    seed.sql 이 같은 행을 upsert 하면 seed 값이 우선한다. 여기서는 없을 때만 넣는다.
-- ---------------------------------------------------------------------
insert into core.apps (id, name, schema_name, signup_policy) values ('blog', 'NOMAD Blog', 'blog', 'open')
on conflict (id) do nothing;

insert into core.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('blog', 'free',     'Free',     0,     'month', 20,   0, false,
   '{"posts_per_month": 10, "max_channel_accounts": 2, "channel_types": ["naver","tistory","wordpress"], "ai_modes": ["fast"], "affiliate": true, "affiliate_auto_insert": false, "brandconnect": false, "schedule": false, "automation": false, "team_members": 1}',
   true, true, 0),
  ('blog', 'pro',      'Pro',      29000, 'month', 300,  0, false,
   '{"posts_per_month": 50, "max_channel_accounts": 10, "channel_types": ["naver","tistory","wordpress"], "ai_modes": ["fast","quality"], "affiliate": true, "affiliate_auto_insert": true, "brandconnect": true, "schedule": true, "automation": false, "team_members": 1}',
   false, true, 1),
  ('blog', 'business', 'Business', 99000, 'month', 1500, 0, false,
   '{"posts_per_month": -1, "max_channel_accounts": -1, "channel_types": ["naver","tistory","wordpress","instagram"], "ai_modes": ["fast","quality"], "affiliate": true, "affiliate_auto_insert": true, "brandconnect": true, "schedule": true, "automation": true, "team_members": 5}',
   false, true, 2)
on conflict (app_id, code) do nothing;

insert into core.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('blog', 'pack_100',  '100 크레딧',   100,  4900,  true, 1),
  ('blog', 'pack_500',  '500 크레딧',   500,  19900, true, 2),
  ('blog', 'pack_1500', '1,500 크레딧', 1500, 49000, true, 3)
on conflict (app_id, code) do nothing;

-- ---------------------------------------------------------------------
-- 1. channel_accounts: 발행 채널 계정. 쓰기는 service_role(연결/검증 워커) 또는 아래 RPC 만.
--    네이버/티스토리 세션 쿠키, 아이디/비밀번호, 워드프레스 애플리케이션 비밀번호는
--    core.encrypted_credentials(provider = 'naver_blog' | 'tistory' | 'wordpress' | 'instagram')에만 둔다.
-- ---------------------------------------------------------------------
create table if not exists blog.channel_accounts (
  id                            uuid primary key default gen_random_uuid(),
  org_id                        uuid not null references core.organizations(id) on delete cascade,
  channel                       text not null
                                constraint channel_accounts_channel_check
                                check (channel in ('naver', 'tistory', 'wordpress', 'instagram')),
  label                         text not null default ''
                                constraint channel_accounts_label_check check (length(label) <= 60),
  blog_url                      text
                                constraint channel_accounts_blog_url_check check (blog_url is null or blog_url ~* '^https://[^/@[:space:]]+'),
  external_account_id           text,                  -- 네이버 blog_id, 티스토리 블로그 이름, WP 사용자 id
  credential_id                 uuid references core.encrypted_credentials(id) on delete set null,
  status                        text not null default 'pending'
                                constraint channel_accounts_status_check
                                check (status in ('pending', 'active', 'needs_reauth', 'error', 'revoked')),
  automation_risk_consented_at  timestamptz,           -- 네이버/티스토리 Playwright 자동 게시 위험 동의
  automation_risk_consented_by  uuid,
  automation_risk_notice_version text,
  session_expires_at            timestamptz,
  last_verified_at              timestamptz,
  last_published_at             timestamptz,
  last_error                    text,
  locked_by_job                 uuid,                  -- 계정당 동시 브라우저 세션 1개(acquire_channel_lock)
  locked_until                  timestamptz,
  created_by                    uuid,
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now(),
  constraint channel_accounts_org_channel_ext_uniq unique (org_id, channel, external_account_id)
);
create index if not exists channel_accounts_org_idx on blog.channel_accounts (org_id, channel);
create index if not exists channel_accounts_credential_idx on blog.channel_accounts (credential_id) where credential_id is not null;
drop trigger if exists channel_accounts_set_updated_at on blog.channel_accounts;
create trigger channel_accounts_set_updated_at before update on blog.channel_accounts
  for each row execute function core.set_updated_at();
drop trigger if exists channel_accounts_guard_write on blog.channel_accounts;
create trigger channel_accounts_guard_write before insert or update or delete on blog.channel_accounts
  for each row execute function core.guard_privileged_write();
alter table blog.channel_accounts enable row level security;

-- ---------------------------------------------------------------------
-- 2. posts: 원고. 사용자 쓰기는 콘텐츠 컬럼만(컬럼 GRANT가 1차, 트리거가 2차 잠금).
--    body_html 은 서버 렌더러가 body_json 에서 만든 sanitize 결과만 저장한다(사용자 HTML 직접 저장 금지).
-- ---------------------------------------------------------------------
create table if not exists blog.posts (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null references core.organizations(id) on delete cascade,
  title                       text not null default ''
                              constraint posts_title_check check (length(title) <= 200),
  body_json                   jsonb not null default '{"type":"doc","content":[]}'::jsonb
                              constraint posts_body_json_check check (octet_length(body_json::text) <= 500000),
  body_html                   text,
  excerpt                     text constraint posts_excerpt_check check (excerpt is null or length(excerpt) <= 300),
  tags                        text[] not null default '{}'
                              constraint posts_tags_check check (cardinality(tags) <= 30),
  category                    text constraint posts_category_check check (category is null or length(category) <= 60),
  target_keyword              text constraint posts_target_keyword_check check (target_keyword is null or length(target_keyword) <= 100),
  template                    text not null default 'info'
                              constraint posts_template_check
                              check (template in ('info', 'compare', 'guide', 'essay', 'experience')),
  experience_note             text,                    -- experience 템플릿: 사용자 본인의 실제 사용 메모(50자 이상)
  cover_image_path            text,
  seo_score                   integer constraint posts_seo_score_check check (seo_score is null or seo_score between 0 and 100),
  seo_feedback                jsonb not null default '[]'::jsonb,
  brandconnect_application_id uuid references core.brandconnect_applications(id) on delete set null,
  status                      text not null default 'draft'
                              constraint posts_status_check
                              check (status in ('draft', 'generating', 'scheduled', 'publishing', 'published',
                                                'partially_published', 'failed', 'archived')),
  compliance_verdict          text not null default 'unchecked'
                              constraint posts_compliance_verdict_check
                              check (compliance_verdict in ('unchecked', 'pass', 'warn', 'fail')),
  compliance_issues           jsonb not null default '[]'::jsonb,
  compliance_checked_at       timestamptz,
  compliance_ack_by           uuid,
  compliance_ack_at           timestamptz,
  ai_job_id                   uuid references core.jobs(id) on delete set null,
  version                     integer not null default 1,
  last_error                  text,
  created_by                  uuid,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  archived_at                 timestamptz,
  constraint posts_experience_check
    check (template <> 'experience' or length(btrim(coalesce(experience_note, ''))) >= 50),
  constraint posts_cover_path_check
    check (cover_image_path is null or cover_image_path like (org_id::text || '/blog/%'))
);
create index if not exists posts_org_updated_idx on blog.posts (org_id, updated_at desc);
create index if not exists posts_org_status_idx on blog.posts (org_id, status);
drop trigger if exists posts_set_updated_at on blog.posts;
create trigger posts_set_updated_at before update on blog.posts
  for each row execute function core.set_updated_at();
alter table blog.posts enable row level security;

-- 콘텐츠 변경 감지, 보호 컬럼 2차 잠금, 생성자 기록, 제휴 지원서 조직 일치 검사
create or replace function blog.posts_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_app_org uuid;
begin
  if tg_op = 'INSERT' then
    if not core.is_privileged_session() then
      new.status := 'draft';
      new.compliance_verdict := 'unchecked';
      new.body_html := null;
      new.ai_job_id := null;
      new.created_by := auth.uid();
    end if;
  else
    if not core.is_privileged_session() and (
         new.org_id is distinct from old.org_id
      or new.status is distinct from old.status
      or new.compliance_verdict is distinct from old.compliance_verdict
      or new.compliance_issues is distinct from old.compliance_issues
      or new.compliance_ack_by is distinct from old.compliance_ack_by
      or new.body_html is distinct from old.body_html
      or new.ai_job_id is distinct from old.ai_job_id
      or new.created_by is distinct from old.created_by
      or new.version is distinct from old.version
    ) then
      raise exception 'blog.posts: protected column change' using errcode = '42501';
    end if;
    if (new.title, new.body_json, new.tags, new.template, new.experience_note, new.brandconnect_application_id)
       is distinct from
       (old.title, old.body_json, old.tags, old.template, old.experience_note, old.brandconnect_application_id) then
      new.version := old.version + 1;
      -- 같은 UPDATE 에서 검사 결과를 직접 쓰지 않았으면 이전 검사는 무효
      if new.compliance_verdict is not distinct from old.compliance_verdict then
        new.compliance_verdict := 'unchecked';
        new.compliance_issues := '[]'::jsonb;
        new.compliance_checked_at := null;
        new.compliance_ack_by := null;
        new.compliance_ack_at := null;
      end if;
    end if;
  end if;
  if new.brandconnect_application_id is not null
     and (tg_op = 'INSERT' or new.brandconnect_application_id is distinct from old.brandconnect_application_id) then
    -- 블로그 원고에는 블로그형 지원서만 연결한다(클립형은 video 소유, 확정 결정 19)
    select a.org_id into v_app_org from core.brandconnect_applications a
     where a.id = new.brandconnect_application_id and a.target_kind = 'blog';
    if v_app_org is null or v_app_org <> new.org_id then
      raise exception 'blog.posts: brandconnect application belongs to another organization or is not a blog campaign' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists posts_guard on blog.posts;
create trigger posts_guard before insert or update on blog.posts
  for each row execute function blog.posts_guard();

-- 원고 상태 전이: generating 은 draft 와만 오가고, archived 는 draft 로만 복원한다.
-- 나머지 발행 집계 상태(scheduled/publishing/published/partially_published/failed)는
-- post_publications 트리거(blog.sync_post_status)가 계산한다.
create or replace function blog.posts_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if (new.status = 'generating' and old.status <> 'draft')
       or (old.status = 'generating' and new.status <> 'draft')
       or (new.status = 'archived' and old.status in ('generating', 'scheduled', 'publishing'))
       or (old.status = 'archived' and new.status <> 'draft') then
      raise exception 'blog.posts: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'archived' then
      new.archived_at := now();
    elsif old.status = 'archived' then
      new.archived_at := null;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists posts_status_transition on blog.posts;
create trigger posts_status_transition before update on blog.posts
  for each row execute function blog.posts_status_transition();

-- ---------------------------------------------------------------------
-- 3. post_affiliate_links: 원고 <-> core.affiliate_links. 쓰기는 service_role(제휴 링크 생성 라우트)만.
--    대가성 문구 필요 여부는 이 표에서 계산한다(post_publications 트리거).
-- ---------------------------------------------------------------------
create table if not exists blog.post_affiliate_links (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  post_id        uuid not null references blog.posts(id) on delete cascade,
  link_id        uuid not null references core.affiliate_links(id) on delete cascade,
  provider       text not null
                 constraint post_affiliate_links_provider_check
                 check (provider in ('coupang', 'naver_brandconnect', 'tenping', 'naver_shopping_connect')),
  placement      text not null default 'card'
                 constraint post_affiliate_links_placement_check check (placement in ('card', 'inline', 'cta')),
  position       integer not null default 0,
  card_snapshot  jsonb not null default '{}'::jsonb,   -- 삽입 시점 상품명/가격/이미지(가격 변동 표기용)
  inserted_by    text not null default 'user'
                 constraint post_affiliate_links_inserted_by_check check (inserted_by in ('user', 'auto')),
  created_by     uuid,
  created_at     timestamptz not null default now(),
  constraint post_affiliate_links_post_link_uniq unique (post_id, link_id)
);
create index if not exists post_affiliate_links_post_idx on blog.post_affiliate_links (post_id, position);
create index if not exists post_affiliate_links_link_idx on blog.post_affiliate_links (link_id);
drop trigger if exists post_affiliate_links_guard_write on blog.post_affiliate_links;
create trigger post_affiliate_links_guard_write before insert or update or delete on blog.post_affiliate_links
  for each row execute function core.guard_privileged_write();
alter table blog.post_affiliate_links enable row level security;

-- 서버 버그로도 다른 조직의 링크를 매핑하지 못하게 한다(service_role 쓰기에도 적용).
create or replace function blog.post_affiliate_links_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_post_org uuid; v_link core.affiliate_links;
begin
  select org_id into v_post_org from blog.posts where id = new.post_id;
  select * into v_link from core.affiliate_links where id = new.link_id;
  if v_post_org is null or v_link.id is null
     or v_post_org <> new.org_id or v_link.org_id <> new.org_id then
    raise exception 'blog.post_affiliate_links: organization mismatch' using errcode = '42501';
  end if;
  if v_link.source_app <> 'blog' or v_link.provider <> new.provider then
    raise exception 'blog.post_affiliate_links: link is not a blog link of provider %', new.provider using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists post_affiliate_links_consistency on blog.post_affiliate_links;
create trigger post_affiliate_links_consistency before insert or update on blog.post_affiliate_links
  for each row execute function blog.post_affiliate_links_consistency();

-- ---------------------------------------------------------------------
-- 4. post_publications: 원고 x 채널 계정 발행 1건. 쓰기는 service_role(발행 라우트, 워커)과 아래 RPC 만.
--    상태: queued | scheduled -> publishing -> published | unconfirmed | failed | queued(재시도)
--          unconfirmed -> published | failed (사용자 확인, 자동 재시도 금지: 중복 발행 방지)
--          failed -> queued (사용자 재시도), queued | scheduled -> canceled
-- ---------------------------------------------------------------------
create table if not exists blog.post_publications (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  post_id              uuid not null references blog.posts(id) on delete cascade,
  channel_account_id   uuid references blog.channel_accounts(id) on delete set null,
  channel              text not null
                       constraint post_publications_channel_check
                       check (channel in ('naver', 'tistory', 'wordpress', 'instagram')),
  status               text not null default 'queued'
                       constraint post_publications_status_check
                       check (status in ('queued', 'scheduled', 'publishing', 'published', 'unconfirmed', 'failed', 'canceled')),
  scheduled_at         timestamptz,
  job_id               uuid references core.jobs(id) on delete set null,
  attempts             integer not null default 0,
  external_post_id     text,
  published_url        text constraint post_publications_url_check check (published_url is null or published_url ~* '^https://'),
  published_at         timestamptz,
  rendered_hash        text,                         -- 실제로 보낸 HTML 의 sha256(감사/재발행 비교)
  requires_disclosure  boolean not null default false,
  disclosure_included  boolean not null default false,
  affiliate_link_count integer not null default 0,
  last_error           text,
  idempotency_key      text unique,
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  canceled_at          timestamptz,
  -- 제휴 링크/스폰서 원고는 대가성 문구 없이 발행 단계로 들어갈 수 없다(끌 수 없음)
  constraint post_publications_disclosure_check
    check (status not in ('publishing', 'published', 'unconfirmed') or not requires_disclosure or disclosure_included),
  constraint post_publications_schedule_check
    check (status <> 'scheduled' or scheduled_at is not null)
);
create unique index if not exists post_publications_external_uniq
  on blog.post_publications (channel_account_id, external_post_id) where external_post_id is not null;
create unique index if not exists post_publications_active_uniq
  on blog.post_publications (post_id, channel_account_id)
  where status in ('queued', 'scheduled', 'publishing', 'unconfirmed');
create index if not exists post_publications_org_created_idx on blog.post_publications (org_id, created_at desc);
create index if not exists post_publications_org_schedule_idx on blog.post_publications (org_id, scheduled_at) where scheduled_at is not null;
create index if not exists post_publications_post_idx on blog.post_publications (post_id);
create index if not exists post_publications_job_idx on blog.post_publications (job_id) where job_id is not null;
drop trigger if exists post_publications_set_updated_at on blog.post_publications;
create trigger post_publications_set_updated_at before update on blog.post_publications
  for each row execute function core.set_updated_at();
drop trigger if exists post_publications_guard_write on blog.post_publications;
create trigger post_publications_guard_write before insert or update or delete on blog.post_publications
  for each row execute function core.guard_privileged_write();
alter table blog.post_publications enable row level security;

-- 발행 게이트(INSERT): 같은 조직, 채널 계정 활성 + 자동화 동의, 원고 상태, 컴플라이언스 통과.
-- 대가성 문구 필요 여부와 링크 수는 서버 값이 아니라 DB 에서 계산한다.
create or replace function blog.post_publications_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_post blog.posts; v_acc blog.channel_accounts;
begin
  select * into v_post from blog.posts where id = new.post_id;
  if v_post.id is null or v_post.org_id <> new.org_id then
    raise exception 'post_publications: post/org mismatch' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('queued', 'scheduled') then
      raise exception 'post_publications: initial status must be queued or scheduled' using errcode = '22023';
    end if;
    select * into v_acc from blog.channel_accounts where id = new.channel_account_id;
    if v_acc.id is null or v_acc.org_id <> new.org_id then
      raise exception 'post_publications: channel account/org mismatch' using errcode = '42501';
    end if;
    if v_acc.channel <> new.channel or v_acc.status <> 'active' then
      raise exception 'post_publications: channel account is % (%)', v_acc.status, v_acc.channel using errcode = 'BL005';
    end if;
    if v_acc.channel in ('naver', 'tistory') and v_acc.automation_risk_consented_at is null then
      raise exception 'post_publications: automation risk consent required for %', v_acc.channel using errcode = 'BL005';
    end if;
    if v_post.status in ('generating', 'archived') then
      raise exception 'post_publications: post is %', v_post.status using errcode = 'BL001';
    end if;
    if not (v_post.compliance_verdict = 'pass'
            or (v_post.compliance_verdict = 'warn' and v_post.compliance_ack_at is not null)) then
      raise exception 'post_publications: compliance gate not passed (%)', v_post.compliance_verdict using errcode = 'BL003';
    end if;
  end if;

  if tg_op = 'INSERT' or (new.status = 'publishing' and old.status is distinct from 'publishing') then
    select count(*) into new.affiliate_link_count from blog.post_affiliate_links l where l.post_id = new.post_id;
    new.requires_disclosure := new.affiliate_link_count > 0 or v_post.brandconnect_application_id is not null;
  end if;
  return new;
end;
$$;
drop trigger if exists post_publications_gate on blog.post_publications;
create trigger post_publications_gate before insert or update on blog.post_publications
  for each row execute function blog.post_publications_gate();

-- 발행 상태 전이(service_role 쓰기에도 적용)
create or replace function blog.post_publications_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not (
         (old.status in ('queued', 'scheduled') and new.status in ('publishing', 'canceled'))
      or (old.status = 'scheduled'  and new.status = 'queued')
      or (old.status = 'publishing' and new.status in ('published', 'unconfirmed', 'failed', 'queued'))
      or (old.status = 'unconfirmed' and new.status in ('published', 'failed'))
      or (old.status = 'failed'     and new.status = 'queued')
    ) then
      raise exception 'post_publications: invalid status transition % -> %', old.status, new.status using errcode = '22023';
    end if;
    if new.status = 'publishing' then
      new.attempts := old.attempts + 1;
    elsif new.status = 'published' and new.published_at is null then
      new.published_at := now();
    elsif new.status = 'canceled' then
      new.canceled_at := now();
    end if;
  end if;
  if new.post_id is distinct from old.post_id or new.org_id is distinct from old.org_id
     or new.channel is distinct from old.channel then
    raise exception 'post_publications: immutable columns' using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists post_publications_transition on blog.post_publications;
create trigger post_publications_transition before update on blog.post_publications
  for each row execute function blog.post_publications_transition();

-- 원고 집계 상태 계산(발행 행이 바뀔 때마다)
create or replace function blog.sync_post_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active int; v_sched int; v_ok int; v_bad int; v_status text;
begin
  select count(*) filter (where p.status in ('queued', 'publishing')),
         count(*) filter (where p.status = 'scheduled'),
         count(*) filter (where p.status in ('published', 'unconfirmed')),
         count(*) filter (where p.status = 'failed')
    into v_active, v_sched, v_ok, v_bad
    from blog.post_publications p where p.post_id = new.post_id;
  v_status := case
    when v_active > 0 then 'publishing'
    when v_sched > 0 then 'scheduled'
    when v_ok > 0 and v_bad > 0 then 'partially_published'
    when v_ok > 0 then 'published'
    when v_bad > 0 then 'failed'
    else 'draft' end;
  update blog.posts set status = v_status
   where id = new.post_id and status not in ('archived', 'generating') and status is distinct from v_status;
  if new.status = 'published' and new.channel_account_id is not null then
    update blog.channel_accounts set last_published_at = coalesce(new.published_at, now())
     where id = new.channel_account_id;
  end if;
  return null;
end;
$$;
drop trigger if exists post_publications_sync_post on blog.post_publications;
create trigger post_publications_sync_post after insert or update on blog.post_publications
  for each row execute function blog.sync_post_status();

-- ---------------------------------------------------------------------
-- 5. 사용자 RPC (authenticated). 호출자 판정은 is_service_caller + has_org_role.
-- ---------------------------------------------------------------------

-- 예약/대기 발행 취소. 워커가 이미 잡은 잡(running)은 core.cancel_job 이 JB002 로 거부한다.
create or replace function blog.cancel_publication(p_publication_id uuid)
returns blog.post_publications
language plpgsql
security definer
set search_path = ''
as $$
declare v_row blog.post_publications;
begin
  select * into v_row from blog.post_publications where id = p_publication_id for update;
  if not found then
    raise exception 'cancel_publication: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'cancel_publication: not a member' using errcode = '42501';
  end if;
  if v_row.status not in ('queued', 'scheduled') then
    raise exception 'cancel_publication: status % cannot be canceled', v_row.status using errcode = 'BL002';
  end if;
  if v_row.job_id is not null then
    perform core.cancel_job(v_row.job_id);
  end if;
  update blog.post_publications set status = 'canceled' where id = p_publication_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'blog.publication.cancel', 'post_publication', v_row.id::text);
  return v_row;
end;
$$;

-- 발행 결과 불확실(unconfirmed) 건을 사용자가 확인. URL 을 주면 published, null 이면 failed.
create or replace function blog.resolve_unconfirmed_publication(p_publication_id uuid, p_published_url text default null)
returns blog.post_publications
language plpgsql
security definer
set search_path = ''
as $$
declare v_row blog.post_publications;
begin
  select * into v_row from blog.post_publications where id = p_publication_id for update;
  if not found then
    raise exception 'resolve_unconfirmed_publication: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'resolve_unconfirmed_publication: not a member' using errcode = '42501';
  end if;
  if v_row.status <> 'unconfirmed' then
    raise exception 'resolve_unconfirmed_publication: status is %', v_row.status using errcode = 'BL001';
  end if;
  if p_published_url is not null then
    if p_published_url !~* '^https://' then
      raise exception 'resolve_unconfirmed_publication: https url required' using errcode = '22023';
    end if;
    update blog.post_publications set status = 'published', published_url = p_published_url
     where id = p_publication_id returning * into v_row;
  else
    update blog.post_publications set status = 'failed', last_error = 'user_marked_not_published'
     where id = p_publication_id returning * into v_row;
  end if;
  perform core.write_audit(v_row.org_id, 'blog.publication.resolve', 'post_publication', v_row.id::text,
                           null, jsonb_build_object('status', v_row.status));
  return v_row;
end;
$$;

-- 컴플라이언스 WARN 확인(감사 기록). FAIL 은 확인으로 넘길 수 없다.
create or replace function blog.acknowledge_compliance_warning(p_post_id uuid)
returns blog.posts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row blog.posts;
begin
  select * into v_row from blog.posts where id = p_post_id for update;
  if not found then
    raise exception 'acknowledge_compliance_warning: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'acknowledge_compliance_warning: not a member' using errcode = '42501';
  end if;
  if v_row.compliance_verdict <> 'warn' then
    raise exception 'acknowledge_compliance_warning: verdict is %', v_row.compliance_verdict using errcode = 'BL003';
  end if;
  update blog.posts set compliance_ack_by = auth.uid(), compliance_ack_at = now()
   where id = p_post_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'blog.compliance.warn_ack', 'post', v_row.id::text,
                           null, jsonb_build_object('issues', v_row.compliance_issues));
  return v_row;
end;
$$;

-- 원고 보관/복원(사용자는 status 컬럼을 직접 바꿀 수 없다)
create or replace function blog.set_post_archived(p_post_id uuid, p_archived boolean)
returns blog.posts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row blog.posts;
begin
  select * into v_row from blog.posts where id = p_post_id for update;
  if not found then
    raise exception 'set_post_archived: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'set_post_archived: not a member' using errcode = '42501';
  end if;
  update blog.posts set status = case when p_archived then 'archived' else 'draft' end
   where id = p_post_id returning * into v_row;
  perform core.write_audit(v_row.org_id, case when p_archived then 'blog.post.archive' else 'blog.post.restore' end,
                           'post', v_row.id::text);
  return v_row;
end;
$$;

-- 네이버/티스토리 Playwright 자동 게시 위험 동의(owner/admin). 고지문 버전을 함께 남긴다.
create or replace function blog.consent_channel_automation_risk(p_account_id uuid, p_notice_version text)
returns blog.channel_accounts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row blog.channel_accounts;
begin
  select * into v_row from blog.channel_accounts where id = p_account_id for update;
  if not found then
    raise exception 'consent_channel_automation_risk: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'consent_channel_automation_risk: owner/admin only' using errcode = '42501';
  end if;
  if v_row.channel not in ('naver', 'tistory') then
    raise exception 'consent_channel_automation_risk: not an automated channel' using errcode = '22023';
  end if;
  if coalesce(btrim(p_notice_version), '') = '' then
    raise exception 'consent_channel_automation_risk: notice version required' using errcode = '22023';
  end if;
  update blog.channel_accounts
     set automation_risk_consented_at = now(), automation_risk_consented_by = auth.uid(),
         automation_risk_notice_version = p_notice_version
   where id = p_account_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'blog.channel.automation_risk_consent', 'channel_account', v_row.id::text,
                           null, null, jsonb_build_object('notice_version', p_notice_version, 'channel', v_row.channel));
  return v_row;
end;
$$;

-- 채널 연결 해제(owner/admin). 같은 자격증명을 다른 활성 연결(예: 브랜드커넥트 계정)이 쓰면 자격증명은 남긴다.
create or replace function blog.disconnect_channel_account(p_account_id uuid)
returns blog.channel_accounts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row blog.channel_accounts; v_shared boolean;
begin
  select * into v_row from blog.channel_accounts where id = p_account_id for update;
  if not found then
    raise exception 'disconnect_channel_account: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'disconnect_channel_account: owner/admin only' using errcode = '42501';
  end if;
  if v_row.credential_id is not null then
    select exists (select 1 from blog.channel_accounts c
                    where c.credential_id = v_row.credential_id and c.id <> v_row.id and c.status <> 'revoked')
        or exists (select 1 from core.affiliate_accounts a
                    where a.credential_id = v_row.credential_id and a.status <> 'revoked')
      into v_shared;
    if not v_shared then
      perform core.revoke_credential(v_row.credential_id);
    end if;
  end if;
  update blog.channel_accounts
     set status = 'revoked', credential_id = null, locked_by_job = null, locked_until = null
   where id = p_account_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'blog.channel.disconnect', 'channel_account', v_row.id::text);
  return v_row;
end;
$$;

-- 이번 달(KST) 발행 사용량: 발행 행이 하나라도 살아 있는(실패/취소 아님) 원고 수
create or replace function blog.monthly_post_usage(p_org_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_from timestamptz; v_count integer;
begin
  if not core.is_service_caller() and not core.is_org_member(p_org_id) then
    raise exception 'monthly_post_usage: not a member' using errcode = '42501';
  end if;
  v_from := date_trunc('month', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
  select count(distinct p.post_id) into v_count
    from blog.post_publications p
   where p.org_id = p_org_id and p.created_at >= v_from and p.status not in ('failed', 'canceled');
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- 6. 워커 전용 RPC (service_role). 채널 계정당 브라우저 세션 1개를 보장하는 임대 잠금.
-- ---------------------------------------------------------------------
create or replace function blog.acquire_channel_lock(p_account_id uuid, p_job_id uuid, p_ttl_seconds integer default 300)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_ok boolean;
begin
  if not core.is_privileged_session() then
    raise exception 'acquire_channel_lock: service_role only' using errcode = '42501';
  end if;
  update blog.channel_accounts
     set locked_by_job = p_job_id, locked_until = now() + make_interval(secs => greatest(p_ttl_seconds, 30))
   where id = p_account_id
     and status = 'active'
     and (locked_by_job is null or locked_until < now() or locked_by_job = p_job_id)
  returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

create or replace function blog.release_channel_lock(p_account_id uuid, p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'release_channel_lock: service_role only' using errcode = '42501';
  end if;
  update blog.channel_accounts set locked_by_job = null, locked_until = null
   where id = p_account_id and locked_by_job = p_job_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. 권한과 RLS 정책
-- ---------------------------------------------------------------------
-- 함수 EXECUTE: 기본 권한에서 PUBLIC 을 회수했지만 명시적으로 한 번 더 정리한다.
revoke execute on function blog.posts_guard() from public, anon, authenticated;
revoke execute on function blog.posts_status_transition() from public, anon, authenticated;
revoke execute on function blog.post_affiliate_links_consistency() from public, anon, authenticated;
revoke execute on function blog.post_publications_gate() from public, anon, authenticated;
revoke execute on function blog.post_publications_transition() from public, anon, authenticated;
revoke execute on function blog.sync_post_status() from public, anon, authenticated;
revoke execute on function blog.acquire_channel_lock(uuid, uuid, integer) from public, anon, authenticated;
revoke execute on function blog.release_channel_lock(uuid, uuid) from public, anon, authenticated;
grant execute on function blog.acquire_channel_lock(uuid, uuid, integer) to service_role;
grant execute on function blog.release_channel_lock(uuid, uuid) to service_role;

revoke execute on function blog.cancel_publication(uuid) from public, anon;
revoke execute on function blog.resolve_unconfirmed_publication(uuid, text) from public, anon;
revoke execute on function blog.acknowledge_compliance_warning(uuid) from public, anon;
revoke execute on function blog.set_post_archived(uuid, boolean) from public, anon;
revoke execute on function blog.consent_channel_automation_risk(uuid, text) from public, anon;
revoke execute on function blog.disconnect_channel_account(uuid) from public, anon;
revoke execute on function blog.monthly_post_usage(uuid) from public, anon;
grant execute on function blog.cancel_publication(uuid) to authenticated, service_role;
grant execute on function blog.resolve_unconfirmed_publication(uuid, text) to authenticated, service_role;
grant execute on function blog.acknowledge_compliance_warning(uuid) to authenticated, service_role;
grant execute on function blog.set_post_archived(uuid, boolean) to authenticated, service_role;
grant execute on function blog.consent_channel_automation_risk(uuid, text) to authenticated, service_role;
grant execute on function blog.disconnect_channel_account(uuid) to authenticated, service_role;
grant execute on function blog.monthly_post_usage(uuid) to authenticated, service_role;

-- 테이블 권한: anon 은 아무것도 없다. 사용자 쓰기는 posts 의 콘텐츠 컬럼만.
revoke all on blog.channel_accounts, blog.posts, blog.post_affiliate_links, blog.post_publications from anon, authenticated;
grant select on blog.channel_accounts, blog.posts, blog.post_affiliate_links, blog.post_publications to authenticated;
grant insert (org_id, title, body_json, excerpt, tags, category, target_keyword, template, experience_note,
              cover_image_path, brandconnect_application_id) on blog.posts to authenticated;
grant update (title, body_json, excerpt, tags, category, target_keyword, template, experience_note,
              cover_image_path, brandconnect_application_id) on blog.posts to authenticated;
grant delete on blog.posts to authenticated;
grant all on blog.channel_accounts, blog.posts, blog.post_affiliate_links, blog.post_publications to service_role;

drop policy if exists channel_accounts_select on blog.channel_accounts;
create policy channel_accounts_select on blog.channel_accounts for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'blog'));

drop policy if exists posts_select on blog.posts;
create policy posts_select on blog.posts for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'blog'));
drop policy if exists posts_insert on blog.posts;
create policy posts_insert on blog.posts for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'blog'));
drop policy if exists posts_update on blog.posts;
create policy posts_update on blog.posts for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'blog')
         and status not in ('generating', 'publishing'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'blog'));
drop policy if exists posts_delete on blog.posts;
create policy posts_delete on blog.posts for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and status in ('draft', 'failed', 'archived'));

drop policy if exists post_affiliate_links_select on blog.post_affiliate_links;
create policy post_affiliate_links_select on blog.post_affiliate_links for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'blog'));

drop policy if exists post_publications_select on blog.post_publications;
create policy post_publications_select on blog.post_publications for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'blog'));

-- Realtime: 발행 진행 상태는 core.jobs 구독이 정본이고, 목록 갱신용으로 발행 행도 내보낸다.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'blog' and tablename = 'post_publications') then
    execute 'alter publication supabase_realtime add table blog.post_publications';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 8. PUBLIC EXECUTE 최종 회수(0007_core_function_privileges.sql 규칙과 같다).
--    alter default privileges 는 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 지우지 않는다.
--    위 7절에서 authenticated/service_role 에 준 명시 GRANT 는 그대로 남는다.
-- ---------------------------------------------------------------------
revoke execute on all functions in schema blog from public;

-- ---------------------------------------------------------------------
-- 9. AI·음성 기본값 (2026-10-13, 확정 결정 13~17)
--   설계: docs/products/nomad-blog/02_ARCHITECTURE.md 5절, 01_PRD.md 4.7절. 정본 규칙은 _platform-core/AI_ARCHITECTURE.md 4장,
--   VOICE_ARCHITECTURE.md 3장. 모든 값은 제안이며 운영 화면이 아니라 이 조각과 모놀리스 seed 에서만 바꾼다.
--   9.1 기능별 라우팅 기본값: org_id null(플랫폼 기본), app_id 'blog'. 기능 키는 소문자.
--       체인 제공자는 seed.sql 의 core.ai_providers 행이어야 하고 kind 가 맞아야 한다(9.3 검사).
--       - blog.post_draft : 그래프 blog.post_draft 의 키워드·초안·제휴 점검 노드. 원고 품질이 핵심이라 Claude 먼저.
--                           사용자의 체험 메모와 브랜드 자료는 국외 이전 동의가 있어야 상용으로 간다(동의 없으면 resolve_ai_route 가 걸러 낸다).
--                           채널 비밀번호·세션 쿠키·제휴 키는 어떤 AI 입력에도 넣지 않는다(코드 규칙).
--       - blog.assist     : 구간 다시쓰기·태그·상품 키워드 추출·키워드/개요·브랜드커넥트 메시지 다듬기 단건 호출.
--       - chat            : 글쓰기 도우미 채팅(/tools/answer 모드 write).
--       - blog.compliance : 그래프 compliance 노드의 LLM 판정(규칙 사전은 LLM 없이 먼저). 후보를 3개로 줄여 판정 편차를 줄인다.
--       - wiki.*          : 조직의 토픽·키워드 위키. 대량 처리라 오픈소스 먼저.
--       - dify.aux        : Dify 보조 LLM 노드(질문 분류). 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--       - blog.knowledge(embedding): 브랜드·상품·제휴 캠페인 자료 컬렉션. 동의 없는 조직의 검색 질의도 같은 모델로
--                           임베딩해야 하므로 국내 오픈소스 임베딩으로 고정(대체 없음, 모델을 바꾸면 컬렉션 재색인).
--       - voice_chat      : 채팅 음성 질문 STT 는 오픈소스 먼저, 답변 읽어 주기 TTS 는 ElevenLabs 먼저.
--       - dictation       : 에디터 음성 받아쓰기 STT. 대량·저비용이라 오픈소스 먼저. 녹음 원본은 저장하지 않는다(store_audio=false).
--   9.2 플랜 features 의 AI 키. seed.sql 이 이 조각보다 나중에 실행되면 덮어써지므로
--       _supabase-modular/seed.sql 반영을 코어에 요청했다(06_AGENT_PLAN.md 6절 AI-R2). 서버는 누락 키를 기본값으로 읽는다.
-- ---------------------------------------------------------------------
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'blog', 'blog.post_draft',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'blog', 'blog.assist',      'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'blog', 'chat',             'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'blog', 'blog.compliance',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'blog', 'wiki.query',       'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'blog', 'wiki.ingest',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'blog', 'wiki.lint',        'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'blog', 'dify.aux',         'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'blog', 'blog.knowledge',   'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'blog', 'voice_chat',       'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'blog', 'voice_chat',       'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'blog', 'dictation',        'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 9.2 플랜 AI 키(있으면 병합, 없으면 아무 일도 하지 않음)
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 50, "voice_chat": true, "dictation": true, "rag_documents": 10, "product_wiki": false}'::jsonb
 where app_id = 'blog' and code = 'free';
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "dictation": true, "rag_documents": 100, "product_wiki": true}'::jsonb
 where app_id = 'blog' and code = 'pro';
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 500, "voice_chat": true, "dictation": true, "rag_documents": 1000, "product_wiki": true}'::jsonb
 where app_id = 'blog' and code = 'business';

-- 9.3 체인 검사: 제공자 행이 있을 때만(seed 전에 적용되는 배포 순서에서도 실패하지 않게) 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'blog'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'blog routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;
