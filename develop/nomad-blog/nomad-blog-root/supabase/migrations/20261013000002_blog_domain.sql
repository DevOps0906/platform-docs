-- =====================================================================
-- 0002_blog_domain.sql  (nomad-blog 모놀리스, public 스키마)
-- 원본: docs/products/_supabase-modular/migrations/1300_blog.sql 를 DB_CONVENTIONS.md 12장 규칙으로 변환
--   (a) create schema 블록 제거 (b) core. -> public. (c) blog.<tbl> -> public.<tbl>
--   (d) 모든 테이블에서 public, anon, authenticated 권한 회수 후 필요한 GRANT 만
--   apps/plans/credit_packs 행은 seed.sql 로 옮겼다.
-- 선행: 0001_core_lite.sql (SECTION 0~10 전부 유지: Toss, 크레딧, OAuth/자격증명/레이트리밋, 잡, Storage, affiliate)
-- 스키마 public 은 _platform-core/MONOLITH_CORE_LITE.sql 결정을 따른다(최종 사용자 확인 대기, 05_DATA_MODEL.md 8장).
-- 반복 실행 가능.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. channel_accounts: 발행 채널 계정. 쓰기는 service_role(연결/검증 워커) 또는 아래 RPC 만.
--    네이버/티스토리 세션 쿠키, 아이디/비밀번호, 워드프레스 애플리케이션 비밀번호는
--    public.encrypted_credentials(provider = 'naver_blog' | 'tistory' | 'wordpress' | 'instagram')에만 둔다.
-- ---------------------------------------------------------------------
create table if not exists public.channel_accounts (
  id                            uuid primary key default gen_random_uuid(),
  org_id                        uuid not null references public.organizations(id) on delete cascade,
  channel                       text not null
                                constraint channel_accounts_channel_check
                                check (channel in ('naver', 'tistory', 'wordpress', 'instagram')),
  label                         text not null default ''
                                constraint channel_accounts_label_check check (length(label) <= 60),
  blog_url                      text
                                constraint channel_accounts_blog_url_check check (blog_url is null or blog_url ~* '^https://[^/@[:space:]]+'),
  external_account_id           text,                  -- 네이버 blog_id, 티스토리 블로그 이름, WP 사용자 id
  credential_id                 uuid references public.encrypted_credentials(id) on delete set null,
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
create index if not exists channel_accounts_org_idx on public.channel_accounts (org_id, channel);
create index if not exists channel_accounts_credential_idx on public.channel_accounts (credential_id) where credential_id is not null;
drop trigger if exists channel_accounts_set_updated_at on public.channel_accounts;
create trigger channel_accounts_set_updated_at before update on public.channel_accounts
  for each row execute function public.set_updated_at();
drop trigger if exists channel_accounts_guard_write on public.channel_accounts;
create trigger channel_accounts_guard_write before insert or update or delete on public.channel_accounts
  for each row execute function public.guard_privileged_write();
alter table public.channel_accounts enable row level security;

-- ---------------------------------------------------------------------
-- 2. posts: 원고. 사용자 쓰기는 콘텐츠 컬럼만(컬럼 GRANT가 1차, 트리거가 2차 잠금).
--    body_html 은 서버 렌더러가 body_json 에서 만든 sanitize 결과만 저장한다(사용자 HTML 직접 저장 금지).
-- ---------------------------------------------------------------------
create table if not exists public.posts (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null references public.organizations(id) on delete cascade,
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
  brandconnect_application_id uuid references public.brandconnect_applications(id) on delete set null,
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
  ai_job_id                   uuid references public.jobs(id) on delete set null,
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
create index if not exists posts_org_updated_idx on public.posts (org_id, updated_at desc);
create index if not exists posts_org_status_idx on public.posts (org_id, status);
drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at before update on public.posts
  for each row execute function public.set_updated_at();
alter table public.posts enable row level security;

-- 콘텐츠 변경 감지, 보호 컬럼 2차 잠금, 생성자 기록, 제휴 지원서 조직 일치 검사
create or replace function public.posts_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_app_org uuid;
begin
  if tg_op = 'INSERT' then
    if not public.is_privileged_session() then
      new.status := 'draft';
      new.compliance_verdict := 'unchecked';
      new.body_html := null;
      new.ai_job_id := null;
      new.created_by := auth.uid();
    end if;
  else
    if not public.is_privileged_session() and (
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
      raise exception 'public.posts: protected column change' using errcode = '42501';
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
    select a.org_id into v_app_org from public.brandconnect_applications a
     where a.id = new.brandconnect_application_id and a.target_kind = 'blog';
    if v_app_org is null or v_app_org <> new.org_id then
      raise exception 'public.posts: brandconnect application belongs to another organization or is not a blog campaign' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists posts_guard on public.posts;
create trigger posts_guard before insert or update on public.posts
  for each row execute function public.posts_guard();

-- 원고 상태 전이: generating 은 draft 와만 오가고, archived 는 draft 로만 복원한다.
-- 나머지 발행 집계 상태(scheduled/publishing/published/partially_published/failed)는
-- post_publications 트리거(public.sync_post_status)가 계산한다.
create or replace function public.posts_status_transition()
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
      raise exception 'public.posts: invalid status transition % -> %', old.status, new.status using errcode = '22023';
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
drop trigger if exists posts_status_transition on public.posts;
create trigger posts_status_transition before update on public.posts
  for each row execute function public.posts_status_transition();

-- ---------------------------------------------------------------------
-- 3. post_affiliate_links: 원고 <-> public.affiliate_links. 쓰기는 service_role(제휴 링크 생성 라우트)만.
--    대가성 문구 필요 여부는 이 표에서 계산한다(post_publications 트리거).
-- ---------------------------------------------------------------------
create table if not exists public.post_affiliate_links (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  post_id        uuid not null references public.posts(id) on delete cascade,
  link_id        uuid not null references public.affiliate_links(id) on delete cascade,
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
create index if not exists post_affiliate_links_post_idx on public.post_affiliate_links (post_id, position);
create index if not exists post_affiliate_links_link_idx on public.post_affiliate_links (link_id);
drop trigger if exists post_affiliate_links_guard_write on public.post_affiliate_links;
create trigger post_affiliate_links_guard_write before insert or update or delete on public.post_affiliate_links
  for each row execute function public.guard_privileged_write();
alter table public.post_affiliate_links enable row level security;

-- 서버 버그로도 다른 조직의 링크를 매핑하지 못하게 한다(service_role 쓰기에도 적용).
create or replace function public.post_affiliate_links_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_post_org uuid; v_link public.affiliate_links;
begin
  select org_id into v_post_org from public.posts where id = new.post_id;
  select * into v_link from public.affiliate_links where id = new.link_id;
  if v_post_org is null or v_link.id is null
     or v_post_org <> new.org_id or v_link.org_id <> new.org_id then
    raise exception 'public.post_affiliate_links: organization mismatch' using errcode = '42501';
  end if;
  if v_link.source_app <> 'blog' or v_link.provider <> new.provider then
    raise exception 'public.post_affiliate_links: link is not a blog link of provider %', new.provider using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists post_affiliate_links_consistency on public.post_affiliate_links;
create trigger post_affiliate_links_consistency before insert or update on public.post_affiliate_links
  for each row execute function public.post_affiliate_links_consistency();

-- ---------------------------------------------------------------------
-- 4. post_publications: 원고 x 채널 계정 발행 1건. 쓰기는 service_role(발행 라우트, 워커)과 아래 RPC 만.
--    상태: queued | scheduled -> publishing -> published | unconfirmed | failed | queued(재시도)
--          unconfirmed -> published | failed (사용자 확인, 자동 재시도 금지: 중복 발행 방지)
--          failed -> queued (사용자 재시도), queued | scheduled -> canceled
-- ---------------------------------------------------------------------
create table if not exists public.post_publications (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references public.organizations(id) on delete cascade,
  post_id              uuid not null references public.posts(id) on delete cascade,
  channel_account_id   uuid references public.channel_accounts(id) on delete set null,
  channel              text not null
                       constraint post_publications_channel_check
                       check (channel in ('naver', 'tistory', 'wordpress', 'instagram')),
  status               text not null default 'queued'
                       constraint post_publications_status_check
                       check (status in ('queued', 'scheduled', 'publishing', 'published', 'unconfirmed', 'failed', 'canceled')),
  scheduled_at         timestamptz,
  job_id               uuid references public.jobs(id) on delete set null,
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
  on public.post_publications (channel_account_id, external_post_id) where external_post_id is not null;
create unique index if not exists post_publications_active_uniq
  on public.post_publications (post_id, channel_account_id)
  where status in ('queued', 'scheduled', 'publishing', 'unconfirmed');
create index if not exists post_publications_org_created_idx on public.post_publications (org_id, created_at desc);
create index if not exists post_publications_org_schedule_idx on public.post_publications (org_id, scheduled_at) where scheduled_at is not null;
create index if not exists post_publications_post_idx on public.post_publications (post_id);
create index if not exists post_publications_job_idx on public.post_publications (job_id) where job_id is not null;
drop trigger if exists post_publications_set_updated_at on public.post_publications;
create trigger post_publications_set_updated_at before update on public.post_publications
  for each row execute function public.set_updated_at();
drop trigger if exists post_publications_guard_write on public.post_publications;
create trigger post_publications_guard_write before insert or update or delete on public.post_publications
  for each row execute function public.guard_privileged_write();
alter table public.post_publications enable row level security;

-- 발행 게이트(INSERT): 같은 조직, 채널 계정 활성 + 자동화 동의, 원고 상태, 컴플라이언스 통과.
-- 대가성 문구 필요 여부와 링크 수는 서버 값이 아니라 DB 에서 계산한다.
create or replace function public.post_publications_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_post public.posts; v_acc public.channel_accounts;
begin
  select * into v_post from public.posts where id = new.post_id;
  if v_post.id is null or v_post.org_id <> new.org_id then
    raise exception 'post_publications: post/org mismatch' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('queued', 'scheduled') then
      raise exception 'post_publications: initial status must be queued or scheduled' using errcode = '22023';
    end if;
    select * into v_acc from public.channel_accounts where id = new.channel_account_id;
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
    select count(*) into new.affiliate_link_count from public.post_affiliate_links l where l.post_id = new.post_id;
    new.requires_disclosure := new.affiliate_link_count > 0 or v_post.brandconnect_application_id is not null;
  end if;
  return new;
end;
$$;
drop trigger if exists post_publications_gate on public.post_publications;
create trigger post_publications_gate before insert or update on public.post_publications
  for each row execute function public.post_publications_gate();

-- 발행 상태 전이(service_role 쓰기에도 적용)
create or replace function public.post_publications_transition()
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
drop trigger if exists post_publications_transition on public.post_publications;
create trigger post_publications_transition before update on public.post_publications
  for each row execute function public.post_publications_transition();

-- 원고 집계 상태 계산(발행 행이 바뀔 때마다)
create or replace function public.sync_post_status()
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
    from public.post_publications p where p.post_id = new.post_id;
  v_status := case
    when v_active > 0 then 'publishing'
    when v_sched > 0 then 'scheduled'
    when v_ok > 0 and v_bad > 0 then 'partially_published'
    when v_ok > 0 then 'published'
    when v_bad > 0 then 'failed'
    else 'draft' end;
  update public.posts set status = v_status
   where id = new.post_id and status not in ('archived', 'generating') and status is distinct from v_status;
  if new.status = 'published' and new.channel_account_id is not null then
    update public.channel_accounts set last_published_at = coalesce(new.published_at, now())
     where id = new.channel_account_id;
  end if;
  return null;
end;
$$;
drop trigger if exists post_publications_sync_post on public.post_publications;
create trigger post_publications_sync_post after insert or update on public.post_publications
  for each row execute function public.sync_post_status();

-- ---------------------------------------------------------------------
-- 5. 사용자 RPC (authenticated). 호출자 판정은 is_service_caller + has_org_role.
-- ---------------------------------------------------------------------

-- 예약/대기 발행 취소. 워커가 이미 잡은 잡(running)은 public.cancel_job 이 JB002 로 거부한다.
create or replace function public.cancel_publication(p_publication_id uuid)
returns public.post_publications
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.post_publications;
begin
  select * into v_row from public.post_publications where id = p_publication_id for update;
  if not found then
    raise exception 'cancel_publication: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'cancel_publication: not a member' using errcode = '42501';
  end if;
  if v_row.status not in ('queued', 'scheduled') then
    raise exception 'cancel_publication: status % cannot be canceled', v_row.status using errcode = 'BL002';
  end if;
  if v_row.job_id is not null then
    perform public.cancel_job(v_row.job_id);
  end if;
  update public.post_publications set status = 'canceled' where id = p_publication_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'public.publication.cancel', 'post_publication', v_row.id::text);
  return v_row;
end;
$$;

-- 발행 결과 불확실(unconfirmed) 건을 사용자가 확인. URL 을 주면 published, null 이면 failed.
create or replace function public.resolve_unconfirmed_publication(p_publication_id uuid, p_published_url text default null)
returns public.post_publications
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.post_publications;
begin
  select * into v_row from public.post_publications where id = p_publication_id for update;
  if not found then
    raise exception 'resolve_unconfirmed_publication: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'resolve_unconfirmed_publication: not a member' using errcode = '42501';
  end if;
  if v_row.status <> 'unconfirmed' then
    raise exception 'resolve_unconfirmed_publication: status is %', v_row.status using errcode = 'BL001';
  end if;
  if p_published_url is not null then
    if p_published_url !~* '^https://' then
      raise exception 'resolve_unconfirmed_publication: https url required' using errcode = '22023';
    end if;
    update public.post_publications set status = 'published', published_url = p_published_url
     where id = p_publication_id returning * into v_row;
  else
    update public.post_publications set status = 'failed', last_error = 'user_marked_not_published'
     where id = p_publication_id returning * into v_row;
  end if;
  perform public.write_audit(v_row.org_id, 'public.publication.resolve', 'post_publication', v_row.id::text,
                           null, jsonb_build_object('status', v_row.status));
  return v_row;
end;
$$;

-- 컴플라이언스 WARN 확인(감사 기록). FAIL 은 확인으로 넘길 수 없다.
create or replace function public.acknowledge_compliance_warning(p_post_id uuid)
returns public.posts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.posts;
begin
  select * into v_row from public.posts where id = p_post_id for update;
  if not found then
    raise exception 'acknowledge_compliance_warning: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'acknowledge_compliance_warning: not a member' using errcode = '42501';
  end if;
  if v_row.compliance_verdict <> 'warn' then
    raise exception 'acknowledge_compliance_warning: verdict is %', v_row.compliance_verdict using errcode = 'BL003';
  end if;
  update public.posts set compliance_ack_by = auth.uid(), compliance_ack_at = now()
   where id = p_post_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'public.compliance.warn_ack', 'post', v_row.id::text,
                           null, jsonb_build_object('issues', v_row.compliance_issues));
  return v_row;
end;
$$;

-- 원고 보관/복원(사용자는 status 컬럼을 직접 바꿀 수 없다)
create or replace function public.set_post_archived(p_post_id uuid, p_archived boolean)
returns public.posts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.posts;
begin
  select * into v_row from public.posts where id = p_post_id for update;
  if not found then
    raise exception 'set_post_archived: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller()
     and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'set_post_archived: not a member' using errcode = '42501';
  end if;
  update public.posts set status = case when p_archived then 'archived' else 'draft' end
   where id = p_post_id returning * into v_row;
  perform public.write_audit(v_row.org_id, case when p_archived then 'public.post.archive' else 'public.post.restore' end,
                           'post', v_row.id::text);
  return v_row;
end;
$$;

-- 네이버/티스토리 Playwright 자동 게시 위험 동의(owner/admin). 고지문 버전을 함께 남긴다.
create or replace function public.consent_channel_automation_risk(p_account_id uuid, p_notice_version text)
returns public.channel_accounts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.channel_accounts;
begin
  select * into v_row from public.channel_accounts where id = p_account_id for update;
  if not found then
    raise exception 'consent_channel_automation_risk: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'consent_channel_automation_risk: owner/admin only' using errcode = '42501';
  end if;
  if v_row.channel not in ('naver', 'tistory') then
    raise exception 'consent_channel_automation_risk: not an automated channel' using errcode = '22023';
  end if;
  if coalesce(btrim(p_notice_version), '') = '' then
    raise exception 'consent_channel_automation_risk: notice version required' using errcode = '22023';
  end if;
  update public.channel_accounts
     set automation_risk_consented_at = now(), automation_risk_consented_by = auth.uid(),
         automation_risk_notice_version = p_notice_version
   where id = p_account_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'public.channel.automation_risk_consent', 'channel_account', v_row.id::text,
                           null, null, jsonb_build_object('notice_version', p_notice_version, 'channel', v_row.channel));
  return v_row;
end;
$$;

-- 채널 연결 해제(owner/admin). 같은 자격증명을 다른 활성 연결(예: 브랜드커넥트 계정)이 쓰면 자격증명은 남긴다.
create or replace function public.disconnect_channel_account(p_account_id uuid)
returns public.channel_accounts
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.channel_accounts; v_shared boolean;
begin
  select * into v_row from public.channel_accounts where id = p_account_id for update;
  if not found then
    raise exception 'disconnect_channel_account: not found' using errcode = 'P0002';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'disconnect_channel_account: owner/admin only' using errcode = '42501';
  end if;
  if v_row.credential_id is not null then
    select exists (select 1 from public.channel_accounts c
                    where c.credential_id = v_row.credential_id and c.id <> v_row.id and c.status <> 'revoked')
        or exists (select 1 from public.affiliate_accounts a
                    where a.credential_id = v_row.credential_id and a.status <> 'revoked')
      into v_shared;
    if not v_shared then
      perform public.revoke_credential(v_row.credential_id);
    end if;
  end if;
  update public.channel_accounts
     set status = 'revoked', credential_id = null, locked_by_job = null, locked_until = null
   where id = p_account_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'public.channel.disconnect', 'channel_account', v_row.id::text);
  return v_row;
end;
$$;

-- 이번 달(KST) 발행 사용량: 발행 행이 하나라도 살아 있는(실패/취소 아님) 원고 수
create or replace function public.monthly_post_usage(p_org_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_from timestamptz; v_count integer;
begin
  if not public.is_service_caller() and not public.is_org_member(p_org_id) then
    raise exception 'monthly_post_usage: not a member' using errcode = '42501';
  end if;
  v_from := date_trunc('month', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
  select count(distinct p.post_id) into v_count
    from public.post_publications p
   where p.org_id = p_org_id and p.created_at >= v_from and p.status not in ('failed', 'canceled');
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- 6. 워커 전용 RPC (service_role). 채널 계정당 브라우저 세션 1개를 보장하는 임대 잠금.
-- ---------------------------------------------------------------------
create or replace function public.acquire_channel_lock(p_account_id uuid, p_job_id uuid, p_ttl_seconds integer default 300)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_ok boolean;
begin
  if not public.is_privileged_session() then
    raise exception 'acquire_channel_lock: service_role only' using errcode = '42501';
  end if;
  update public.channel_accounts
     set locked_by_job = p_job_id, locked_until = now() + make_interval(secs => greatest(p_ttl_seconds, 30))
   where id = p_account_id
     and status = 'active'
     and (locked_by_job is null or locked_until < now() or locked_by_job = p_job_id)
  returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

create or replace function public.release_channel_lock(p_account_id uuid, p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_privileged_session() then
    raise exception 'release_channel_lock: service_role only' using errcode = '42501';
  end if;
  update public.channel_accounts set locked_by_job = null, locked_until = null
   where id = p_account_id and locked_by_job = p_job_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. 권한과 RLS 정책
-- ---------------------------------------------------------------------
-- 함수 EXECUTE: 기본 권한에서 PUBLIC 을 회수했지만 명시적으로 한 번 더 정리한다.
revoke execute on function public.posts_guard() from public, anon, authenticated;
revoke execute on function public.posts_status_transition() from public, anon, authenticated;
revoke execute on function public.post_affiliate_links_consistency() from public, anon, authenticated;
revoke execute on function public.post_publications_gate() from public, anon, authenticated;
revoke execute on function public.post_publications_transition() from public, anon, authenticated;
revoke execute on function public.sync_post_status() from public, anon, authenticated;
revoke execute on function public.acquire_channel_lock(uuid, uuid, integer) from public, anon, authenticated;
revoke execute on function public.release_channel_lock(uuid, uuid) from public, anon, authenticated;
grant execute on function public.acquire_channel_lock(uuid, uuid, integer) to service_role;
grant execute on function public.release_channel_lock(uuid, uuid) to service_role;

revoke execute on function public.cancel_publication(uuid) from public, anon;
revoke execute on function public.resolve_unconfirmed_publication(uuid, text) from public, anon;
revoke execute on function public.acknowledge_compliance_warning(uuid) from public, anon;
revoke execute on function public.set_post_archived(uuid, boolean) from public, anon;
revoke execute on function public.consent_channel_automation_risk(uuid, text) from public, anon;
revoke execute on function public.disconnect_channel_account(uuid) from public, anon;
revoke execute on function public.monthly_post_usage(uuid) from public, anon;
grant execute on function public.cancel_publication(uuid) to authenticated, service_role;
grant execute on function public.resolve_unconfirmed_publication(uuid, text) to authenticated, service_role;
grant execute on function public.acknowledge_compliance_warning(uuid) to authenticated, service_role;
grant execute on function public.set_post_archived(uuid, boolean) to authenticated, service_role;
grant execute on function public.consent_channel_automation_risk(uuid, text) to authenticated, service_role;
grant execute on function public.disconnect_channel_account(uuid) to authenticated, service_role;
grant execute on function public.monthly_post_usage(uuid) to authenticated, service_role;

-- 테이블 권한: anon 은 아무것도 없다. 사용자 쓰기는 posts 의 콘텐츠 컬럼만.
revoke all on public.channel_accounts, public.posts, public.post_affiliate_links, public.post_publications from public, anon, authenticated;
grant select on public.channel_accounts, public.posts, public.post_affiliate_links, public.post_publications to authenticated;
grant insert (org_id, title, body_json, excerpt, tags, category, target_keyword, template, experience_note,
              cover_image_path, brandconnect_application_id) on public.posts to authenticated;
grant update (title, body_json, excerpt, tags, category, target_keyword, template, experience_note,
              cover_image_path, brandconnect_application_id) on public.posts to authenticated;
grant delete on public.posts to authenticated;
grant all on public.channel_accounts, public.posts, public.post_affiliate_links, public.post_publications to service_role;

drop policy if exists channel_accounts_select on public.channel_accounts;
create policy channel_accounts_select on public.channel_accounts for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'blog'));

drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'blog'));
drop policy if exists posts_insert on public.posts;
create policy posts_insert on public.posts for insert to authenticated
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'blog'));
drop policy if exists posts_update on public.posts;
create policy posts_update on public.posts for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'blog')
         and status not in ('generating', 'publishing'))
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'blog'));
drop policy if exists posts_delete on public.posts;
create policy posts_delete on public.posts for delete to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']) and status in ('draft', 'failed', 'archived'));

drop policy if exists post_affiliate_links_select on public.post_affiliate_links;
create policy post_affiliate_links_select on public.post_affiliate_links for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'blog'));

drop policy if exists post_publications_select on public.post_publications;
create policy post_publications_select on public.post_publications for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'blog'));

-- Realtime: 발행 진행 상태는 public.jobs 구독이 정본이고, 목록 갱신용으로 발행 행도 내보낸다.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_publications') then
    execute 'alter publication supabase_realtime add table public.post_publications';
  end if;
end $$;
