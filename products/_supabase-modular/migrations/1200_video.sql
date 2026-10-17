-- =====================================================================
-- 1200_video.sql
-- sceneflow (SceneFlow) 도메인. 선행: core 0000~0006 (+ seed.sql 권장)
-- 기획: docs/products/sceneflow/05_DATA_MODEL.md
--
-- 원칙 (SECURITY_BASELINE.md, DB_CONVENTIONS.md)
--   - 모든 테이블 RLS ON. 읽기는 core.is_org_member(org_id) and core.has_entitlement(org_id, 'video').
--   - 돈/권한/한도/상태 전이/외부 발행 결과가 있는 테이블은 사용자 쓰기 정책 없음 + guard_privileged_write.
--   - 순수 콘텐츠 테이블만 컬럼 단위 GRANT + with check 정책으로 사용자 쓰기를 연다.
--   - 상태 컬럼은 전이 트리거(video.enforce_status_transition)로만 바뀐다(service_role 쓰기에도 적용).
--   - authenticated에 EXECUTE를 준 SECURITY DEFINER 함수는 core.is_service_caller()와
--     core.has_org_role()(NULL-safe)로 호출자를 판정한다. is_privileged_session()은 쓰지 않는다.
--   - 크레딧 차감/환불은 이 파일의 함수에서 하지 않는다(Route Handler/워커가 service_role로 core RPC 호출).
--   - 플랜/구독/크레딧/결제/잡/자격증명/제휴 테이블을 다시 만들지 않는다. core.* 를 ALTER하지 않는다.
-- 사용자 정의 SQLSTATE: VD001~VD016 (05_DATA_MODEL.md, 04_API.md 7장)
-- 2026-10-13 개정: 네이버 클립 채널(VD-F-075, 확정 결정 18), 브랜드커넥트 클립 캠페인 연결(VD-F-063, 결정 19),
--   대행 운영(clients, client_channels, client_reviews, client_reports, VD-F-120~126, 결정 21)
-- 반복 실행 가능.
-- =====================================================================

create schema if not exists video;
comment on schema video is 'sceneflow (SceneFlow): 숏폼/롱폼/Lofi/플리 Track A~F';
grant usage on schema video to anon, authenticated, service_role;
alter default privileges in schema video grant all on tables to service_role;
alter default privileges in schema video grant all on sequences to service_role;
alter default privileges in schema video grant execute on functions to service_role;
alter default privileges in schema video revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy) values ('video', 'SceneFlow', 'video', 'open')
on conflict (id) do nothing;

-- =====================================================================
-- 1. 플랜 기능 헬퍼
-- =====================================================================

-- 조직의 현재 video 엔타이틀먼트 플랜 features(jsonb). 엔타이틀먼트가 없으면 null.
-- service_role 전용(트리거와 다른 DEFINER 함수 안에서 소유자 권한으로 호출된다).
create or replace function video.plan_features(p_org uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select p.features
  from core.app_entitlements e
  join core.plans p on p.id = e.plan_id
  where e.org_id = p_org and e.app_id = 'video' and e.status = 'active'
    and (e.expires_at is null or e.expires_at > now())
  limit 1;
$$;
revoke execute on function video.plan_features(uuid) from public, anon, authenticated;
grant execute on function video.plan_features(uuid) to service_role;

-- 기능 플래그 판정(RLS 정책과 서버에서 사용).
--   p_value 가 null : 값이 true / 비어 있지 않은 배열 / 0이 아닌 숫자 면 true
--   p_value 가 있음 : 배열 값에 p_value 가 포함되면 true (예: tracks 에 'D')
-- 멤버가 아닌 조직은 항상 false(타 조직 플랜 정보 노출 방지).
create or replace function video.org_has_feature(p_org uuid, p_key text, p_value text default null)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_f jsonb;
  v_v jsonb;
begin
  if p_org is null or p_key is null then
    return false;
  end if;
  if not (core.is_service_caller() or core.is_org_member(p_org)) then
    return false;
  end if;
  v_f := video.plan_features(p_org);
  if v_f is null then
    return false;
  end if;
  v_v := v_f -> p_key;
  if v_v is null then
    return false;
  end if;
  if p_value is not null then
    return jsonb_typeof(v_v) = 'array' and v_v ? p_value;
  end if;
  return case jsonb_typeof(v_v)
    when 'boolean' then (v_v #>> '{}')::boolean
    when 'array'   then jsonb_array_length(v_v) > 0
    when 'number'  then (v_v #>> '{}')::numeric <> 0
    when 'string'  then length(v_v #>> '{}') > 0
    else false
  end;
end;
$$;
revoke execute on function video.org_has_feature(uuid, text, text) from public, anon;
grant execute on function video.org_has_feature(uuid, text, text) to authenticated, service_role;

-- =====================================================================
-- 2. 공용 트리거 함수
-- =====================================================================

-- 상태 전이 강제. 허용 (old, new) 쌍 외에는 22023. service_role 쓰기에도 적용된다.
-- 트리거 인자 0 = 검사할 컬럼 이름(기본 status). 키는 '<table>.<column>'.
create or replace function video.enforce_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_col  text := coalesce(tg_argv[0], 'status');
  v_old  text := to_jsonb(old) ->> v_col;
  v_new  text := to_jsonb(new) ->> v_col;
  v_map  constant jsonb := '{
    "channels.status":            {"active":["paused","error","revoked"], "paused":["active","error","revoked"], "error":["active","revoked"]},
    "sources.status":             {"requested":["downloading","failed"], "downloading":["ready","failed"], "failed":["requested"], "ready":["purged"]},
    "productions.status":         {"queued":["processing","failed","canceled"], "processing":["ready","partial","failed","canceled"]},
    "outputs.status":             {"pending":["ready","failed"], "failed":["pending"], "ready":["purged"]},
    "longform_projects.status":   {"draft":["storyboard","canceled"], "storyboard":["draft","generating","canceled"], "generating":["review","failed","canceled"], "review":["storyboard","encoding"], "encoding":["ready","failed"], "failed":["storyboard"]},
    "longform_sections.status":   {"draft":["image_pending"], "image_pending":["image_ready","failed"], "image_ready":["image_pending"], "failed":["image_pending"]},
    "longform_highlights.status": {"proposed":["rendering"], "rendering":["ready","failed"], "failed":["rendering"]},
    "music_tracks.status":        {"requested":["generating","failed"], "generating":["ready","failed"], "failed":["requested"], "ready":["archived"]},
    "music_tracks.distribution_status": {"none":["packaged"], "packaged":["submitted","none"], "submitted":["live","rejected"], "rejected":["packaged"], "live":["takedown"]},
    "music_library.status":       {"active":["expired","revoked"], "expired":["active","revoked"]},
    "playlists.status":           {"draft":["rendering","canceled"], "rendering":["ready","failed","draft"], "failed":["draft"], "ready":["draft"]},
    "landing_pages.status":       {"draft":["published"], "published":["unpublished"], "unpublished":["published","draft"]},
    "uploads.status":             {"draft":["checking","canceled"], "checking":["blocked","awaiting_confirm","approved","draft"], "blocked":["draft","canceled"], "awaiting_confirm":["approved","draft","canceled"], "approved":["client_review","scheduled","canceled"], "client_review":["scheduled","draft","canceled"], "scheduled":["uploading","canceled"], "uploading":["published","failed","scheduled"], "failed":["scheduled","canceled"]},
    "clients.status":             {"active":["paused","ended"], "paused":["active","ended"]},
    "client_reviews.decision":    {"pending":["approved","changes_requested","expired","canceled"]},
    "client_reports.status":      {"generating":["ready","failed"], "failed":["generating"], "ready":["sent","generating"]}
  }'::jsonb;
begin
  if v_old is distinct from v_new then
    if not coalesce((v_map -> (tg_table_name || '.' || v_col) -> v_old) ? v_new, false) then
      raise exception 'video: invalid %.% transition % -> %', tg_table_name, v_col, v_old, v_new
        using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;

-- 사용자 세션의 콘텐츠 편집을 부모/자기 상태로 잠근다(VD005). service 호출은 통과.
-- DEFINER 트리거이므로 호출자 판정은 is_service_caller()를 쓴다(규칙 1).
create or replace function video.guard_user_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_row    jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  if core.is_service_caller() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_table_name = 'longform_projects' then
    if tg_op = 'UPDATE' and old.status not in ('draft', 'storyboard', 'review') then
      raise exception 'video: longform project is locked in status %', old.status using errcode = 'VD005';
    end if;
  elsif tg_table_name = 'longform_sections' then
    select p.status into v_status from video.longform_projects p where p.id = (v_row ->> 'longform_id')::uuid;
    if coalesce(v_status, '') not in ('draft', 'storyboard', 'review') then
      raise exception 'video: longform sections are locked (project status %)', v_status using errcode = 'VD005';
    end if;
  elsif tg_table_name = 'playlists' then
    if tg_op = 'UPDATE' and old.status <> 'draft' then
      raise exception 'video: playlist is locked in status %', old.status using errcode = 'VD005';
    end if;
  elsif tg_table_name = 'playlist_items' then
    select p.status into v_status from video.playlists p where p.id = (v_row ->> 'playlist_id')::uuid;
    if coalesce(v_status, '') <> 'draft' then
      raise exception 'video: playlist items are locked (playlist status %)', v_status using errcode = 'VD005';
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

-- 참조 무결성: 자식 행과 참조 대상의 org_id 일치(VD002), 업로드 게이트(VD007, VD011), 플리 곡 출처(VD006).
-- 모든 호출자(service 포함)에 적용한다. DEFINER라서 core.affiliate_links 등 RLS 밖의 행도 대조할 수 있다.
create or replace function video.check_refs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org     uuid;
  v_status  text;
  v_cnt     integer;
  v_lib     record;
  v_ch      record;
  v_verdict text;
begin
  if tg_table_name = 'productions' then
    if new.source_id is not null then
      select org_id into v_org from video.sources where id = new.source_id;
      if v_org is distinct from new.org_id then raise exception 'video: source org mismatch' using errcode = 'VD002'; end if;
    end if;
    if new.client_id is not null then
      select org_id into v_org from video.clients where id = new.client_id;
      if v_org is distinct from new.org_id then raise exception 'video: client org mismatch' using errcode = 'VD002'; end if;
    end if;

  elsif tg_table_name = 'outputs' then
    select org_id into v_org from (
      select org_id from video.productions         where id = new.production_id
      union all select org_id from video.longform_projects  where id = new.longform_id
      union all select org_id from video.longform_highlights where id = new.highlight_id
      union all select org_id from video.music_tracks       where id = new.music_track_id
      union all select org_id from video.playlists          where id = new.playlist_id
    ) s limit 1;
    if v_org is distinct from new.org_id then raise exception 'video: output owner org mismatch' using errcode = 'VD002'; end if;

  elsif tg_table_name in ('longform_sections', 'longform_highlights') then
    select org_id into v_org from video.longform_projects where id = new.longform_id;
    if v_org is distinct from new.org_id then raise exception 'video: longform org mismatch' using errcode = 'VD002'; end if;

  elsif tg_table_name = 'playlist_items' then
    select org_id into v_org from video.playlists where id = new.playlist_id;
    if v_org is distinct from new.org_id then raise exception 'video: playlist org mismatch' using errcode = 'VD002'; end if;
    if new.music_track_id is not null then
      select org_id, status into v_org, v_status from video.music_tracks where id = new.music_track_id;
      if v_org is distinct from new.org_id then raise exception 'video: music track org mismatch' using errcode = 'VD002'; end if;
      if v_status <> 'ready' then raise exception 'video: music track is not ready (%)', v_status using errcode = 'VD006'; end if;
    end if;
    if new.library_track_id is not null then
      select org_id, status, license_expires_at, youtube_monetization_allowed into v_lib
      from video.music_library where id = new.library_track_id;
      if v_lib.org_id is distinct from new.org_id then raise exception 'video: library track org mismatch' using errcode = 'VD002'; end if;
      if v_lib.status <> 'active'
         or (v_lib.license_expires_at is not null and v_lib.license_expires_at <= now())
         or not v_lib.youtube_monetization_allowed then
        raise exception 'video: library track license is not usable' using errcode = 'VD006';
      end if;
    end if;

  elsif tg_table_name = 'landing_pages' then
    if new.production_id is not null then
      select org_id into v_org from video.productions where id = new.production_id;
      if v_org is distinct from new.org_id then raise exception 'video: production org mismatch' using errcode = 'VD002'; end if;
    end if;
    if new.primary_link_id is not null then
      select org_id into v_org from core.affiliate_links where id = new.primary_link_id;
      if v_org is distinct from new.org_id then raise exception 'video: affiliate link org mismatch' using errcode = 'VD002'; end if;
    end if;
    if cardinality(new.related_link_ids) > 0 then
      select count(*) into v_cnt from core.affiliate_links where id = any (new.related_link_ids) and org_id = new.org_id;
      if v_cnt <> cardinality(new.related_link_ids) then raise exception 'video: related link org mismatch' using errcode = 'VD002'; end if;
    end if;

  elsif tg_table_name = 'linkinbio_items' then
    select org_id into v_org from video.linkinbio_profiles where id = new.profile_id;
    if v_org is distinct from new.org_id then raise exception 'video: link-in-bio profile org mismatch' using errcode = 'VD002'; end if;
    if new.landing_page_id is not null then
      select org_id into v_org from video.landing_pages where id = new.landing_page_id;
      if v_org is distinct from new.org_id then raise exception 'video: landing org mismatch' using errcode = 'VD002'; end if;
    end if;
    if new.affiliate_link_id is not null then
      select org_id into v_org from core.affiliate_links where id = new.affiliate_link_id;
      if v_org is distinct from new.org_id then raise exception 'video: affiliate link org mismatch' using errcode = 'VD002'; end if;
    end if;

  elsif tg_table_name = 'uploads' then
    if tg_op = 'INSERT' then
      select org_id, status into v_org, v_status from video.outputs where id = new.output_id;
      if v_org is distinct from new.org_id then raise exception 'video: output org mismatch' using errcode = 'VD002'; end if;
      if v_status <> 'ready' then raise exception 'video: output is not ready (%)', v_status using errcode = 'VD008'; end if;
      select org_id, platform, status, automation_consent_version into v_ch from video.channels where id = new.channel_id;
      if v_ch.org_id is distinct from new.org_id then raise exception 'video: channel org mismatch' using errcode = 'VD002'; end if;
      if v_ch.platform <> new.platform or v_ch.status <> 'active' then
        raise exception 'video: channel is not an active % channel', new.platform using errcode = 'VD008';
      end if;
      -- 네이버 클립: 공식 업로드 API가 없어 Playwright로 게시한다. 현재 고지문 버전에 대한 owner/admin 동의가 있어야 한다(VD015).
      if new.platform = 'naver_clip' and v_ch.automation_consent_version is distinct from video.clip_notice_version() then
        raise exception 'video: naver clip automation risk consent required (%)', video.clip_notice_version() using errcode = 'VD015';
      end if;
    end if;
    if new.brandconnect_application_id is not null
       and (tg_op = 'INSERT' or new.brandconnect_application_id is distinct from old.brandconnect_application_id) then
      select org_id into v_org from core.brandconnect_applications where id = new.brandconnect_application_id;
      if v_org is distinct from new.org_id then raise exception 'video: brandconnect application org mismatch' using errcode = 'VD002'; end if;
    end if;
    if tg_op = 'UPDATE' then
      if old.has_affiliate and not new.has_affiliate
         and exists (select 1 from video.upload_links l where l.upload_id = new.id) then
        raise exception 'video: affiliate links exist; disclosure cannot be removed' using errcode = 'VD007';
      end if;
      -- compliance 게이트: approved 로 가려면 최신 검사가 PASS 이거나, WARN + 사용자 확인
      if new.status = 'approved' and old.status is distinct from 'approved' then
        if new.compliance_check_id is null then
          raise exception 'video: compliance check required' using errcode = 'VD011';
        end if;
        select verdict into v_verdict from video.compliance_checks
        where id = new.compliance_check_id and upload_id = new.id;
        if v_verdict is null or v_verdict = 'fail' or (v_verdict = 'warn' and new.compliance_ack_at is null) then
          raise exception 'video: compliance gate not satisfied (%)', coalesce(v_verdict, 'none') using errcode = 'VD011';
        end if;
      end if;
      -- 고객 승인 게이트: 검토가 필요한 고객 채널이면 approved 에서 바로 scheduled 로 갈 수 없다(VD016).
      if new.status = 'scheduled' and old.status = 'approved'
         and exists (select 1 from video.client_channels cc join video.clients c on c.id = cc.client_id
                     where cc.channel_id = new.channel_id and c.review_required) then
        raise exception 'video: client review required before scheduling' using errcode = 'VD016';
      end if;
      if new.status = 'scheduled' and old.status = 'client_review'
         and not exists (select 1 from video.client_reviews r
                         where r.upload_id = new.id and r.decision = 'approved') then
        raise exception 'video: client has not approved this upload' using errcode = 'VD016';
      end if;
    end if;

  elsif tg_table_name = 'upload_links' then
    select org_id into v_org from video.uploads where id = new.upload_id;
    if v_org is distinct from new.org_id then raise exception 'video: upload org mismatch' using errcode = 'VD002'; end if;
    if not exists (select 1 from video.uploads u where u.id = new.upload_id and u.has_affiliate) then
      raise exception 'video: upload must carry affiliate disclosure before links are attached' using errcode = 'VD007';
    end if;
    select org_id into v_org from core.affiliate_links where id = new.link_id;
    if v_org is distinct from new.org_id then raise exception 'video: affiliate link org mismatch' using errcode = 'VD002'; end if;

  elsif tg_table_name = 'client_channels' then
    select org_id into v_org from video.clients where id = new.client_id;
    if v_org is distinct from new.org_id then raise exception 'video: client org mismatch' using errcode = 'VD002'; end if;
    select org_id into v_org from video.channels where id = new.channel_id;
    if v_org is distinct from new.org_id then raise exception 'video: channel org mismatch' using errcode = 'VD002'; end if;

  elsif tg_table_name in ('client_reviews', 'client_reports') then
    select org_id into v_org from video.clients where id = new.client_id;
    if v_org is distinct from new.org_id then raise exception 'video: client org mismatch' using errcode = 'VD002'; end if;
    if tg_table_name = 'client_reviews' then
      select org_id into v_org from video.uploads where id = new.upload_id;
      if v_org is distinct from new.org_id then raise exception 'video: upload org mismatch' using errcode = 'VD002'; end if;
    end if;

  elsif tg_table_name in ('compliance_checks', 'analytics_snapshots') then
    select org_id into v_org from video.uploads where id = new.upload_id;
    if v_org is distinct from new.org_id then raise exception 'video: upload org mismatch' using errcode = 'VD002'; end if;
  end if;
  return new;
end;
$$;

-- 네이버 클립 자동 업로드 위험 고지문 현재 버전(01_PRD.md 6.5절). 바꾸면 기존 동의는 무효가 되어 재동의 전까지 업로드를 만들지 않는다.
create or replace function video.clip_notice_version()
returns text
language sql
immutable
set search_path = ''
as $$ select 'clip-2026-10-v1'::text $$;

-- 채널 한도: YouTube 활성 채널 수 <= features.max_channels, 그 외 플랫폼은 features.platforms 포함(VD003, VD004)
create or replace function video.enforce_channel_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_f   jsonb;
  v_max integer;
  v_cnt integer;
begin
  if new.status <> 'active' or (tg_op = 'UPDATE' and old.status = 'active') then
    return new;
  end if;
  v_f := video.plan_features(new.org_id);
  if v_f is null then
    raise exception 'video: organization has no video entitlement' using errcode = 'VD003';
  end if;
  if not coalesce((v_f -> 'platforms') ? new.platform, false) then
    raise exception 'video: platform % is not in the plan', new.platform using errcode = 'VD004';
  end if;
  if new.platform = 'youtube' then
    v_max := coalesce((v_f ->> 'max_channels')::integer, 0);
    select count(*) into v_cnt from video.channels c
    where c.org_id = new.org_id and c.platform = 'youtube' and c.status = 'active' and c.id <> new.id;
    if v_cnt >= v_max then
      raise exception 'video: youtube channel limit % reached', v_max using errcode = 'VD003';
    end if;
  end if;
  return new;
end;
$$;

-- =====================================================================
-- 3. 테이블
-- =====================================================================

-- 3.1 channels: 연결된 플랫폼 채널. 토큰은 core.encrypted_credentials 에만(credential_id).
create table if not exists video.channels (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  platform            text not null constraint channels_platform_check check (platform in ('youtube', 'instagram', 'tiktok', 'threads', 'naver_clip')),
  credential_id       uuid references core.encrypted_credentials(id) on delete set null,
  external_channel_id text not null,
  name                text,
  handle              text,
  role                text not null default 'main'
                      constraint channels_role_check check (role in ('main', 'commerce', 'trend', 'longform', 'lofi', 'playlist', 'insurance')),
  target_language     text not null default 'KO' constraint channels_target_language_check check (target_language in ('KO', 'JA', 'EN')),
  target_country      text not null default 'KR' constraint channels_target_country_check check (target_country in ('KR', 'JP', 'US')),
  daily_quota_units   integer not null default 10000 constraint channels_daily_quota_check check (daily_quota_units >= 0),
  quota_used_today    integer not null default 0 constraint channels_quota_used_check check (quota_used_today >= 0),
  quota_reset_at      timestamptz,
  status              text not null default 'active'
                      constraint channels_status_check check (status in ('active', 'paused', 'error', 'revoked')),
  last_error          text,
  -- 브라우저 자동화(Playwright) 채널의 위험 동의(naver_clip). video.consent_clip_automation_risk 로만 기록한다.
  automation_consent_version text,
  automation_consented_at    timestamptz,
  automation_consented_by    uuid,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (org_id, platform, external_channel_id),
  constraint channels_automation_consent_check check (
    (automation_consent_version is null) = (automation_consented_at is null))
);
create index if not exists channels_pick_idx on video.channels (org_id, platform, target_language, role) where status = 'active';

-- 3.2 trend_videos: 플레이보드/서프API 수집(플랫폼 공용 데이터, org 없음). 난수 지표 금지(growth_rate null = 미산출).
create table if not exists video.trend_videos (
  id                  bigint generated always as identity primary key,
  source              text not null constraint trend_videos_source_check check (source in ('playboard', 'serpapi', 'tiktok', 'google_trends', 'youtube_api')),
  country             text not null constraint trend_videos_country_check check (country in ('KR', 'US', 'JP')),
  category            text,
  period              text not null constraint trend_videos_period_check check (period in ('realtime', 'daily', 'weekly')),
  rank                integer,
  external_video_id   text not null,
  title               text,
  channel_external_id text,
  views               bigint,
  views_24h           bigint,
  growth_rate         numeric,
  weighted_score      numeric,
  is_estimated        boolean not null default false,
  collected_at        timestamptz not null default now(),
  unique (source, country, period, external_video_id, collected_at)
);
create index if not exists trend_videos_lookup_idx on video.trend_videos (country, period, collected_at desc, weighted_score desc);

-- 3.3 radar_reports: 채널파인더/블링/주제 점수 결과(조직별). 블링은 근거 출처 1개 이상 필수.
create table if not exists video.radar_reports (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  kind             text not null constraint radar_reports_kind_check check (kind in ('channel_finder', 'bling', 'topic_score')),
  params           jsonb not null default '{}'::jsonb,
  result           jsonb not null default '{}'::jsonb,
  citations        jsonb not null default '[]'::jsonb,
  trend_score      integer constraint radar_reports_score_check check (trend_score between 0 and 100),
  credit_ledger_id bigint references core.credit_ledger(id),
  created_by       uuid,
  created_at       timestamptz not null default now(),
  constraint radar_reports_citations_check check (jsonb_typeof(citations) = 'array' and (kind <> 'bling' or jsonb_array_length(citations) >= 1))
);
create index if not exists radar_reports_org_idx on video.radar_reports (org_id, kind, created_at desc);

-- 3.4 sources: 소싱 원본(Track A/B/C Mode2). 원본 파일은 ready 후 24시간 내 삭제(purge_after).
create table if not exists video.sources (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  track             text not null constraint sources_track_check check (track in ('A', 'B', 'C')),
  platform          text not null constraint sources_platform_check check (platform in ('douyin', 'xiaohongshu', 'youtube', 'tiktok')),
  source_url        text not null constraint sources_url_check check (source_url ~* '^https://'),
  external_video_id text,
  title_original    text,
  thumbnail_url     text,
  likes_count       integer,
  duration_sec      numeric,
  rights_basis      text not null constraint sources_rights_check check (rights_basis in ('public_free', 'creative_commons', 'licensed', 'own')),
  rights_note       text,
  phash             text,
  storage_path      text,
  status            text not null default 'requested'
                    constraint sources_status_check check (status in ('requested', 'downloading', 'ready', 'failed', 'purged')),
  trend_video_id    bigint references video.trend_videos(id) on delete set null,
  job_id            uuid references core.jobs(id) on delete set null,
  downloaded_at     timestamptz,
  purge_after       timestamptz,
  purged_at         timestamptz,
  last_error        text,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create unique index if not exists sources_dedup_uniq on video.sources (org_id, platform, external_video_id) where external_video_id is not null;
create index if not exists sources_phash_idx on video.sources (org_id, phash) where phash is not null;
create index if not exists sources_purge_idx on video.sources (purge_after) where status = 'ready';

-- 3.5 productions: 숏폼 생산 요청 1건(Track A/B/C). request_id 로 멱등.
create table if not exists video.productions (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  track            text not null constraint productions_track_check check (track in ('A', 'B', 'C')),
  mode             text constraint productions_mode_check check (mode in ('ai_generate', 're_edit')),
  source_id        uuid references video.sources(id) on delete set null,
  client_id        uuid,  -- 대행 고객(video.clients). FK는 clients 생성 뒤 3.22에서 건다.
  topic            text,
  topic_score      integer constraint productions_topic_score_check check (topic_score between 0 and 100),
  languages        text[] not null default array['KO']::text[],
  options          jsonb not null default '{}'::jsonb,
  watermark        boolean not null default false,
  status           text not null default 'queued'
                   constraint productions_status_check check (status in ('queued', 'processing', 'partial', 'ready', 'failed', 'canceled')),
  root_job_id      uuid references core.jobs(id) on delete set null,
  credit_ledger_id bigint references core.credit_ledger(id),
  credits_charged  integer not null default 0 constraint productions_credits_check check (credits_charged >= 0),
  credits_refunded integer not null default 0 constraint productions_refund_check check (credits_refunded >= 0 and credits_refunded <= credits_charged),
  request_id       uuid not null unique,
  last_error       text,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  started_at       timestamptz,
  finished_at      timestamptz,
  constraint productions_mode_track_check check ((track = 'C') = (mode is not null)),
  constraint productions_languages_check check (cardinality(languages) between 1 and 3 and languages <@ array['KO', 'JA', 'EN']::text[])
);
create index if not exists productions_org_idx on video.productions (org_id, created_at desc);
create index if not exists productions_status_idx on video.productions (org_id, status);

-- 3.6 longform_projects: Track D 롱폼(10섹션 스토리보드). 콘텐츠 컬럼만 사용자 편집.
create table if not exists video.longform_projects (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  title            text not null constraint longform_title_check check (length(btrim(title)) between 1 and 200),
  category         text not null default 'knowledge' constraint longform_category_check check (category in ('knowledge', 'radio', 'viral_remake')),
  topic            text,
  topic_score      integer constraint longform_topic_score_check check (topic_score between 0 and 100),
  languages        text[] not null default array['KO']::text[],
  storyline        text,
  target_minutes   integer not null default 10 constraint longform_minutes_check check (target_minutes between 3 and 60),
  status           text not null default 'draft'
                   constraint longform_status_check check (status in ('draft', 'storyboard', 'generating', 'review', 'encoding', 'ready', 'failed', 'canceled')),
  root_job_id      uuid references core.jobs(id) on delete set null,
  credit_ledger_id bigint references core.credit_ledger(id),
  last_error       text,
  created_by       uuid default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint longform_languages_check check (cardinality(languages) between 1 and 3 and languages <@ array['KO', 'JA', 'EN']::text[])
);
create index if not exists longform_projects_org_idx on video.longform_projects (org_id, created_at desc);

-- 3.7 longform_sections: 10섹션 정규화(jsonb 통째 갱신 경쟁 제거, BS 리뷰 #20).
create table if not exists video.longform_sections (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  longform_id      uuid not null references video.longform_projects(id) on delete cascade,
  position         integer not null constraint longform_sections_position_check check (position between 1 and 10),
  heading          text,
  script           jsonb not null default '{}'::jsonb,
  image_prompt     text,
  image_path       text,
  clip_path        text,
  narration_paths  jsonb not null default '{}'::jsonb,
  duration_sec     numeric,
  status           text not null default 'draft'
                   constraint longform_sections_status_check check (status in ('draft', 'image_pending', 'image_ready', 'failed')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (longform_id, position)
);

-- 3.8 longform_highlights: OSMU 핵심 구간(최대 3개, 각 60초 이하) → 9:16 쇼츠
create table if not exists video.longform_highlights (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  longform_id  uuid not null references video.longform_projects(id) on delete cascade,
  rank         integer not null constraint longform_highlights_rank_check check (rank between 1 and 3),
  start_sec    numeric not null constraint longform_highlights_start_check check (start_sec >= 0),
  end_sec      numeric not null,
  reason       text,
  status       text not null default 'proposed'
               constraint longform_highlights_status_check check (status in ('proposed', 'rendering', 'ready', 'failed')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (longform_id, rank),
  constraint longform_highlights_range_check check (end_sec > start_sec and end_sec - start_sec <= 60)
);

-- 3.9 music_tracks: Track E 단일 곡(관리 단위 = 곡). Suno 생성곡만. DSP 유통 상태는 별도 컬럼.
create table if not exists video.music_tracks (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  title               text not null constraint music_tracks_title_check check (length(btrim(title)) between 1 and 200),
  genre               text not null constraint music_tracks_genre_check check (genre in ('lofi', 'chill', 'ambient', 'white_noise')),
  prompt              text,
  mood                text,
  bpm                 integer constraint music_tracks_bpm_check check (bpm between 40 and 200),
  rights_basis        text not null default 'suno_generated' constraint music_tracks_rights_check check (rights_basis in ('suno_generated')),
  provider_task_id    text,
  audio_path          text,
  cover_path          text,
  duration_sec        numeric,
  status              text not null default 'requested'
                      constraint music_tracks_status_check check (status in ('requested', 'generating', 'ready', 'failed', 'archived')),
  distribution_status text not null default 'none'
                      constraint music_tracks_distribution_check check (distribution_status in ('none', 'packaged', 'submitted', 'live', 'rejected', 'takedown')),
  distribution_note   text,
  isrc                text constraint music_tracks_isrc_check check (isrc is null or isrc ~ '^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$'),
  package_path        text,
  distributed_at      timestamptz,
  job_id              uuid references core.jobs(id) on delete set null,
  credit_ledger_id    bigint references core.credit_ledger(id),
  request_id          uuid unique,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists music_tracks_org_idx on video.music_tracks (org_id, created_at desc);

-- 3.10 music_library: Track F 에 쓰는 라이선스 확보 곡(사용자 등록, 증빙 필수)
create table if not exists video.music_library (
  id                           uuid primary key default gen_random_uuid(),
  org_id                       uuid not null references core.organizations(id) on delete cascade,
  title                        text not null,
  artist                       text,
  license_type                 text not null constraint music_library_license_check check (license_type in ('purchased', 'royalty_free', 'commissioned', 'cc_by')),
  license_source               text,
  license_proof_path           text not null,
  license_expires_at           timestamptz,
  youtube_monetization_allowed boolean not null,
  attribution_text             text,
  audio_path                   text not null,
  duration_sec                 numeric constraint music_library_duration_check check (duration_sec > 0),
  status                       text not null default 'active'
                               constraint music_library_status_check check (status in ('active', 'expired', 'revoked')),
  created_by                   uuid default auth.uid(),
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  constraint music_library_attribution_check check (license_type <> 'cc_by' or attribution_text is not null)
);
create index if not exists music_library_org_idx on video.music_library (org_id, status);

-- 3.11 playlists: Track F 상황/무드 큐레이션(관리 단위 = 플레이리스트 프로젝트)
create table if not exists video.playlists (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  title                text not null constraint playlists_title_check check (length(btrim(title)) between 1 and 200),
  mood                 text not null constraint playlists_mood_check check (mood in ('cafe', 'drive', 'study', 'sleep', 'work', 'rain', 'healing', 'workout', 'other')),
  target_duration_min  integer not null constraint playlists_duration_check check (target_duration_min in (30, 60, 180)),
  language             text not null default 'KO' constraint playlists_language_check check (language in ('KO', 'JA', 'EN')),
  visual_style         text,
  cover_prompt         text,
  description_body     text,
  pinned_comment_body  text,
  tracklist            jsonb not null default '[]'::jsonb,
  thumbnail_path       text,
  status               text not null default 'draft'
                       constraint playlists_status_check check (status in ('draft', 'rendering', 'ready', 'failed', 'canceled')),
  root_job_id          uuid references core.jobs(id) on delete set null,
  credit_ledger_id     bigint references core.credit_ledger(id),
  last_error           text,
  created_by           uuid default auth.uid(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index if not exists playlists_org_idx on video.playlists (org_id, created_at desc);

-- 3.12 playlist_items: 곡 N개. Suno 자체 생성곡 또는 라이선스 곡 중 정확히 하나.
create table if not exists video.playlist_items (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  playlist_id      uuid not null references video.playlists(id) on delete cascade,
  position         integer not null constraint playlist_items_position_check check (position >= 1),
  music_track_id   uuid references video.music_tracks(id),
  library_track_id uuid references video.music_library(id),
  start_sec        numeric,
  duration_sec     numeric,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint playlist_items_position_uniq unique (playlist_id, position) deferrable initially deferred,
  constraint playlist_items_source_check check (num_nonnulls(music_track_id, library_track_id) = 1)
);

-- 3.13 outputs: 렌더 결과물(숏폼 언어판, 롱폼, OSMU 하이라이트, 단일 곡 루프 영상, 플리 영상). 소유 엔티티 정확히 1개.
create table if not exists video.outputs (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  kind             text not null constraint outputs_kind_check check (kind in ('short', 'longform', 'highlight', 'music_loop', 'playlist')),
  production_id    uuid references video.productions(id) on delete cascade,
  longform_id      uuid references video.longform_projects(id) on delete cascade,
  highlight_id     uuid references video.longform_highlights(id) on delete cascade,
  music_track_id   uuid references video.music_tracks(id) on delete cascade,
  playlist_id      uuid references video.playlists(id) on delete cascade,
  language         text constraint outputs_language_check check (language in ('KO', 'JA', 'EN')),
  aspect           text not null default '9:16' constraint outputs_aspect_check check (aspect in ('9:16', '16:9')),
  video_path       text,
  thumbnail_path   text,
  duration_sec     numeric,
  title            text,
  description_body text,
  tags             text[] not null default '{}'::text[],
  watermark        boolean not null default false,
  status           text not null default 'pending'
                   constraint outputs_status_check check (status in ('pending', 'ready', 'failed', 'purged')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint outputs_owner_check check (num_nonnulls(production_id, longform_id, highlight_id, music_track_id, playlist_id) = 1),
  constraint outputs_kind_owner_check check (
       (kind = 'short'      and production_id  is not null)
    or (kind = 'longform'   and longform_id    is not null)
    or (kind = 'highlight'  and highlight_id   is not null)
    or (kind = 'music_loop' and music_track_id is not null)
    or (kind = 'playlist'   and playlist_id    is not null))
);
create unique index if not exists outputs_short_lang_uniq on video.outputs (production_id, language) where production_id is not null;
create index if not exists outputs_org_idx on video.outputs (org_id, created_at desc);

-- 3.14 landing_pages: Track B 공개 랜딩 /landing/[slug]. 제휴 링크는 core.affiliate_links 참조만.
create table if not exists video.landing_pages (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  production_id    uuid references video.productions(id) on delete set null,
  slug             text not null unique constraint landing_pages_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{2,63}$'),
  product_name     text not null,
  headline         text,
  features         jsonb not null default '[]'::jsonb,
  youtube_video_id text,
  primary_link_id  uuid references core.affiliate_links(id) on delete set null,
  related_link_ids uuid[] not null default '{}'::uuid[],
  status           text not null default 'draft'
                   constraint landing_pages_status_check check (status in ('draft', 'published', 'unpublished')),
  view_count       bigint not null default 0,
  published_at     timestamptz,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint landing_pages_features_check check (jsonb_typeof(features) = 'array' and jsonb_array_length(features) <= 3),
  constraint landing_pages_related_check check (cardinality(related_link_ids) <= 3)
);
create index if not exists landing_pages_org_idx on video.landing_pages (org_id, created_at desc);

-- 3.15 linkinbio_profiles / linkinbio_items: 공개 /lb/[handle] (Track B 랜딩 허브)
create table if not exists video.linkinbio_profiles (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null unique references core.organizations(id) on delete cascade,
  handle       text not null unique
               constraint linkinbio_handle_check check (handle ~ '^[a-z0-9_]{3,30}$'
                 and handle not in ('admin', 'api', 'app', 'dashboard', 'login', 'signup', 'landing', 'lb', 'r', 'pricing', 'legal', 'support')),
  display_name text,
  bio          text constraint linkinbio_bio_check check (bio is null or length(bio) <= 300),
  avatar_path  text,
  is_published boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists video.linkinbio_items (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  profile_id        uuid not null references video.linkinbio_profiles(id) on delete cascade,
  kind              text not null constraint linkinbio_items_kind_check check (kind in ('link', 'landing', 'affiliate', 'video')),
  title             text not null constraint linkinbio_items_title_check check (length(btrim(title)) between 1 and 120),
  url               text constraint linkinbio_items_url_check check (url is null or url ~* '^https://'),
  landing_page_id   uuid references video.landing_pages(id) on delete cascade,
  affiliate_link_id uuid references core.affiliate_links(id) on delete cascade,
  position          integer not null default 0,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint linkinbio_items_target_check check (
       (kind in ('link', 'video') and url is not null and landing_page_id is null and affiliate_link_id is null)
    or (kind = 'landing'   and landing_page_id   is not null and affiliate_link_id is null)
    or (kind = 'affiliate' and affiliate_link_id is not null and landing_page_id is null))
);
create index if not exists linkinbio_items_profile_idx on video.linkinbio_items (profile_id, position);

-- 3.16 uploads: 플랫폼 게시 1건. 제휴 링크가 있으면 설명란 첫 줄과 고정 댓글 첫 줄에 대가성 문구가 반드시 있어야 한다.
create table if not exists video.uploads (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  output_id              uuid not null references video.outputs(id),
  channel_id             uuid not null references video.channels(id),
  platform               text not null constraint uploads_platform_check check (platform in ('youtube', 'instagram', 'tiktok', 'threads', 'naver_clip')),
  language               text constraint uploads_language_check check (language in ('KO', 'JA', 'EN')),
  title                  text not null constraint uploads_title_check check (length(btrim(title)) between 1 and 100),
  description            text not null default '',
  pinned_comment         text,
  tags                   text[] not null default '{}'::text[],
  visibility             text not null default 'public' constraint uploads_visibility_check check (visibility in ('public', 'unlisted', 'private')),
  scheduled_at           timestamptz,
  paid_promotion         boolean not null default false,
  has_affiliate          boolean not null default false,
  disclosure_description text,
  disclosure_pinned      text,
  -- naver_clip: 대가성 표시를 제목 앞과 첫 해시태그에 둔다(공정위 추천·보증 심사지침, 영상은 제목·영상 내·첫 해시태그)
  disclosure_title       text,
  disclosure_hashtag     text,
  brandconnect_application_id uuid references core.brandconnect_applications(id) on delete set null,
  status                 text not null default 'draft'
                         constraint uploads_status_check check (status in ('draft', 'checking', 'blocked', 'awaiting_confirm', 'approved', 'client_review', 'scheduled', 'uploading', 'published', 'failed', 'canceled')),
  compliance_check_id    uuid,
  compliance_ack_by      uuid,
  compliance_ack_at      timestamptz,
  job_id                 uuid references core.jobs(id) on delete set null,
  credit_ledger_id       bigint references core.credit_ledger(id),
  platform_post_id       text,
  post_url               text,
  published_at           timestamptz,
  attempts               integer not null default 0,
  last_error             text,
  request_id             uuid unique,
  created_by             uuid,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (channel_id, platform_post_id),
  -- 제휴 링크가 있거나 브랜드커넥트 선정 캠페인 영상이면 대가성 문구 필수.
  --   naver_clip: 제목 앞 문구 + 첫 해시태그 + 설명 첫 줄(고정 댓글 없음)
  --   그 외     : 설명란 첫 줄 + 고정 댓글 첫 줄(기존 규칙)
  constraint uploads_disclosure_check check (
    not (has_affiliate or brandconnect_application_id is not null) or (
      case when platform = 'naver_clip' then
            disclosure_title is not null and length(btrim(disclosure_title)) >= 2
        and starts_with(title, disclosure_title)
        and disclosure_hashtag is not null and length(btrim(disclosure_hashtag)) >= 2
        and cardinality(tags) >= 1 and tags[1] = disclosure_hashtag
        and disclosure_description is not null and length(btrim(disclosure_description)) >= 10
        and starts_with(description, disclosure_description)
      else
            disclosure_description is not null and length(btrim(disclosure_description)) >= 10
        and starts_with(description, disclosure_description)
        and disclosure_pinned is not null and length(btrim(disclosure_pinned)) >= 10
        and pinned_comment is not null and starts_with(pinned_comment, disclosure_pinned)
      end))
);
create index if not exists uploads_org_idx on video.uploads (org_id, created_at desc);
create index if not exists uploads_due_idx on video.uploads (scheduled_at) where status = 'scheduled';
create index if not exists uploads_output_idx on video.uploads (output_id);

-- 3.17 upload_links: 업로드에 삽입된 제휴 링크(core.affiliate_links) 배치 기록
create table if not exists video.upload_links (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  upload_id  uuid not null references video.uploads(id) on delete cascade,
  link_id    uuid not null references core.affiliate_links(id),
  placement  text not null constraint upload_links_placement_check check (placement in ('video_description', 'video_pinned_comment')),
  position   integer not null default 1,
  created_at timestamptz not null default now(),
  unique (upload_id, link_id, placement)
);

-- 3.18 compliance_checks: 업로드 전 검사(규칙 + LLM) 결과. append-only.
create table if not exists video.compliance_checks (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  upload_id        uuid not null references video.uploads(id) on delete cascade,
  verdict          text not null constraint compliance_checks_verdict_check check (verdict in ('pass', 'warn', 'fail')),
  stages           text[] not null default array['rules']::text[],
  issues           jsonb not null default '[]'::jsonb,
  suggestions      jsonb not null default '[]'::jsonb,
  llm_failed       boolean not null default false,
  usage_id         bigint,
  credit_ledger_id bigint references core.credit_ledger(id),
  created_at       timestamptz not null default now()
);
create index if not exists compliance_checks_upload_idx on video.compliance_checks (upload_id, created_at desc);
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'uploads_compliance_fk') then
    alter table video.uploads add constraint uploads_compliance_fk
      foreign key (compliance_check_id) references video.compliance_checks(id) on delete set null;
  end if;
end $$;

-- 3.19 analytics_snapshots: 게시물 성과 수집(YouTube Analytics 등)
create table if not exists video.analytics_snapshots (
  id             bigint generated always as identity primary key,
  org_id         uuid not null references core.organizations(id) on delete cascade,
  upload_id      uuid not null references video.uploads(id) on delete cascade,
  captured_at    timestamptz not null default now(),
  views          bigint,
  likes          bigint,
  comments       bigint,
  watch_time_sec bigint,
  unique (upload_id, captured_at)
);
create index if not exists analytics_snapshots_org_idx on video.analytics_snapshots (org_id, captured_at desc);

-- 3.20 workflows: automation-core 캔버스 저장(실행 엔진은 _platform-core automation-core). Phase 2 기능.
create table if not exists video.workflows (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  name       text not null constraint workflows_name_check check (length(btrim(name)) between 1 and 120),
  graph      jsonb not null default '{"nodes": [], "edges": []}'::jsonb,
  is_active  boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workflows_graph_check check (jsonb_typeof(graph -> 'nodes') = 'array' and jsonb_typeof(graph -> 'edges') = 'array')
);

-- 3.21 banned_words: compliance 규칙 사전의 조직 추가분(플랫폼 공통 사전은 패키지 JSON)
create table if not exists video.banned_words (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  word       text not null constraint banned_words_word_check check (length(btrim(word)) between 1 and 60),
  severity   text not null default 'warn' constraint banned_words_severity_check check (severity in ('warn', 'fail')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (org_id, word)
);

-- 3.22 clients: 대행 고객사(브랜드). 직접 대행 + 내부 도구 운영(확정 결정 21, VD-F-120). 플랜 features.agency 필요.
create table if not exists video.clients (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  name             text not null constraint clients_name_check check (length(btrim(name)) between 1 and 120),
  brand_name       text,
  business_no      text,
  contact_name     text,
  contact_email    text,
  contact_phone    text,
  brand_guide_path text,   -- org-files 버킷 경로(<org_id>/video/clients/<uuid>.pdf)
  brand_wiki_ref   text,   -- 채널·브랜드 가이드 위키(VD-F-102) 문서 키
  package_code     text constraint clients_package_check check (package_code in ('produce', 'produce_upload', 'full_ops')),
  contract_start   date,
  contract_end     date,
  monthly_quota    integer constraint clients_quota_check check (monthly_quota is null or monthly_quota >= 0),
  review_required  boolean not null default true,
  report_day       integer not null default 5 constraint clients_report_day_check check (report_day between 1 and 28),
  status           text not null default 'active' constraint clients_status_check check (status in ('active', 'paused', 'ended')),
  notes            text,
  created_by       uuid default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (org_id, name),
  constraint clients_contract_check check (contract_end is null or contract_start is null or contract_end >= contract_start)
);
create index if not exists clients_org_idx on video.clients (org_id, status);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'productions_client_fk') then
    alter table video.productions add constraint productions_client_fk
      foreign key (client_id) references video.clients(id) on delete set null;
  end if;
end $$;
create index if not exists productions_client_idx on video.productions (client_id) where client_id is not null;

-- 3.23 client_channels: 고객 ↔ 운영 채널. 한 채널은 한 고객에만 묶인다(VD-F-121).
create table if not exists video.client_channels (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  client_id  uuid not null references video.clients(id) on delete cascade,
  channel_id uuid not null references video.channels(id) on delete cascade,
  ownership  text not null default 'client' constraint client_channels_ownership_check check (ownership in ('client', 'agency')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (channel_id)
);
create index if not exists client_channels_client_idx on video.client_channels (client_id);

-- 3.24 client_reviews: 고객 승인 요청 1건(VD-F-123). 토큰 원문은 저장하지 않고 sha256 해시(hex 64자)만 둔다.
--      토큰은 서버가 만들어 고객에게 보내고, 공개 검토 화면은 Route Handler 가 레이트 리밋 뒤 service_role 로
--      video.decide_client_review 를 호출한다.
create table if not exists video.client_reviews (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  client_id      uuid not null references video.clients(id) on delete cascade,
  upload_id      uuid not null references video.uploads(id) on delete cascade,
  token_hash     text not null unique constraint client_reviews_token_check check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at     timestamptz not null,
  decision       text not null default 'pending'
                 constraint client_reviews_decision_check check (decision in ('pending', 'approved', 'changes_requested', 'expired', 'canceled')),
  reviewer_name  text,
  comment        text constraint client_reviews_comment_check check (comment is null or length(comment) <= 2000),
  decided_at     timestamptz,
  requested_by   uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists client_reviews_upload_idx on video.client_reviews (upload_id, created_at desc);
create unique index if not exists client_reviews_one_pending on video.client_reviews (upload_id) where decision = 'pending';

-- 3.25 client_reports: 고객 월간 성과 리포트(VD-F-124). analytics_snapshots 집계 → PDF(core exports 버킷). 서버 전용 쓰기.
create table if not exists video.client_reports (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  client_id    uuid not null references video.clients(id) on delete cascade,
  period_month date not null constraint client_reports_period_check check (period_month = date_trunc('month', period_month)::date),
  kpis         jsonb not null default '{}'::jsonb,  -- views, completion_rate, subscriber_gain, upload_adherence, affiliate_clicks
  summary      text,
  pdf_path     text,
  status       text not null default 'generating' constraint client_reports_status_check check (status in ('generating', 'ready', 'failed', 'sent')),
  job_id       uuid references core.jobs(id) on delete set null,
  sent_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (client_id, period_month)
);

-- =====================================================================
-- 4. 트리거 연결
-- =====================================================================
do $$
declare t text;
begin
  -- updated_at
  foreach t in array array['channels', 'sources', 'productions', 'longform_projects', 'longform_sections', 'longform_highlights',
                           'music_tracks', 'music_library', 'playlists', 'playlist_items', 'outputs', 'landing_pages',
                           'linkinbio_profiles', 'linkinbio_items', 'uploads', 'workflows',
                           'clients', 'client_reviews', 'client_reports'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on video.%I for each row execute function core.set_updated_at()', t || '_set_updated_at', t);
  end loop;
  -- 사용자 쓰기 정책이 없는 테이블: 이중 잠금
  foreach t in array array['channels', 'trend_videos', 'radar_reports', 'sources', 'productions', 'longform_highlights',
                           'outputs', 'uploads', 'upload_links', 'compliance_checks', 'analytics_snapshots',
                           'client_reviews', 'client_reports'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_guard_write', t);
    execute format('create trigger %I before insert or update or delete on video.%I for each row execute function core.guard_privileged_write()', t || '_guard_write', t);
  end loop;
  -- 상태 전이
  foreach t in array array['channels', 'sources', 'productions', 'outputs', 'longform_projects', 'longform_sections',
                           'longform_highlights', 'music_tracks', 'music_library', 'playlists', 'landing_pages', 'uploads',
                           'clients', 'client_reports'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_status_transition', t);
    execute format('create trigger %I before update of status on video.%I for each row execute function video.enforce_status_transition(''status'')', t || '_status_transition', t);
  end loop;
  -- 참조 무결성
  foreach t in array array['productions', 'outputs', 'longform_sections', 'longform_highlights', 'playlist_items', 'landing_pages',
                           'linkinbio_items', 'uploads', 'upload_links', 'compliance_checks', 'analytics_snapshots',
                           'client_channels', 'client_reviews', 'client_reports'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_check_refs', t);
    execute format('create trigger %I before insert or update on video.%I for each row execute function video.check_refs()', t || '_check_refs', t);
  end loop;
  -- 사용자 편집 잠금
  foreach t in array array['longform_projects', 'longform_sections', 'playlists', 'playlist_items'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_guard_user_edit', t);
    execute format('create trigger %I before insert or update or delete on video.%I for each row execute function video.guard_user_edit()', t || '_guard_user_edit', t);
  end loop;
end $$;

drop trigger if exists music_tracks_distribution_transition on video.music_tracks;
create trigger music_tracks_distribution_transition before update of distribution_status on video.music_tracks
  for each row execute function video.enforce_status_transition('distribution_status');

drop trigger if exists client_reviews_decision_transition on video.client_reviews;
create trigger client_reviews_decision_transition before update of decision on video.client_reviews
  for each row execute function video.enforce_status_transition('decision');

drop trigger if exists channels_limit on video.channels;
create trigger channels_limit before insert or update of status on video.channels
  for each row execute function video.enforce_channel_limit();

-- compliance_checks, analytics_snapshots, trend_videos, radar_reports, upload_links 는 UPDATE 를 쓰지 않는다(append-only 운용)

-- =====================================================================
-- 5. RLS 와 GRANT
-- =====================================================================
alter table video.channels            enable row level security;
alter table video.trend_videos        enable row level security;
alter table video.radar_reports       enable row level security;
alter table video.sources             enable row level security;
alter table video.productions         enable row level security;
alter table video.longform_projects   enable row level security;
alter table video.longform_sections   enable row level security;
alter table video.longform_highlights enable row level security;
alter table video.music_tracks        enable row level security;
alter table video.music_library       enable row level security;
alter table video.playlists           enable row level security;
alter table video.playlist_items      enable row level security;
alter table video.outputs             enable row level security;
alter table video.landing_pages       enable row level security;
alter table video.linkinbio_profiles  enable row level security;
alter table video.linkinbio_items     enable row level security;
alter table video.uploads             enable row level security;
alter table video.upload_links        enable row level security;
alter table video.compliance_checks   enable row level security;
alter table video.analytics_snapshots enable row level security;
alter table video.workflows           enable row level security;
alter table video.banned_words        enable row level security;
alter table video.clients             enable row level security;
alter table video.client_channels     enable row level security;
alter table video.client_reviews      enable row level security;
alter table video.client_reports      enable row level security;

-- SELECT: 같은 조직 멤버 + video 엔타이틀먼트 (org 테이블 전부)
do $$
declare t text;
begin
  foreach t in array array['channels', 'radar_reports', 'sources', 'productions', 'longform_projects', 'longform_sections',
                           'longform_highlights', 'music_tracks', 'music_library', 'playlists', 'playlist_items', 'outputs',
                           'landing_pages', 'linkinbio_profiles', 'linkinbio_items', 'uploads', 'upload_links',
                           'compliance_checks', 'analytics_snapshots', 'workflows', 'banned_words',
                           'clients', 'client_channels', 'client_reports'] loop
    execute format('grant select on video.%I to authenticated', t);
    execute format('drop policy if exists %I on video.%I', t || '_select', t);
    execute format('create policy %I on video.%I for select to authenticated using (core.is_org_member(org_id) and core.has_entitlement(org_id, ''video''))', t || '_select', t);
  end loop;
end $$;

-- trend_videos: 공용 데이터. 플랜에 radar.playboard 가 있는 조직의 멤버만 읽는다.
grant select on video.trend_videos to authenticated;
drop policy if exists trend_videos_select on video.trend_videos;
create policy trend_videos_select on video.trend_videos for select to authenticated
  using (exists (select 1 from core.current_org_ids() as o(id) where video.org_has_feature(o.id, 'radar', 'playboard')));

-- ---------------------------------------------------------------------
-- 사용자 쓰기를 여는 콘텐츠 테이블 (컬럼 단위 GRANT + with check). 삭제는 owner/admin.
-- 쓰기 역할: owner/admin/member (viewer 제외)
-- ---------------------------------------------------------------------

-- longform_projects (Track D 기능 필요)
grant insert (org_id, title, category, topic, languages, storyline, target_minutes) on video.longform_projects to authenticated;
grant update (title, category, topic, languages, storyline, target_minutes) on video.longform_projects to authenticated;
grant delete on video.longform_projects to authenticated;
drop policy if exists longform_projects_insert on video.longform_projects;
create policy longform_projects_insert on video.longform_projects for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video')
              and video.org_has_feature(org_id, 'tracks', 'D'));
drop policy if exists longform_projects_update on video.longform_projects;
create policy longform_projects_update on video.longform_projects for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists longform_projects_delete on video.longform_projects;
create policy longform_projects_delete on video.longform_projects for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- longform_sections
grant insert (org_id, longform_id, position, heading, script, image_prompt) on video.longform_sections to authenticated;
grant update (heading, script, image_prompt) on video.longform_sections to authenticated;
grant delete on video.longform_sections to authenticated;
drop policy if exists longform_sections_insert on video.longform_sections;
create policy longform_sections_insert on video.longform_sections for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and video.org_has_feature(org_id, 'tracks', 'D'));
drop policy if exists longform_sections_update on video.longform_sections;
create policy longform_sections_update on video.longform_sections for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists longform_sections_delete on video.longform_sections;
create policy longform_sections_delete on video.longform_sections for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- music_tracks: 제목만 사용자 편집
grant update (title) on video.music_tracks to authenticated;
drop policy if exists music_tracks_update on video.music_tracks;
create policy music_tracks_update on video.music_tracks for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));

-- music_library (Track F 기능 필요)
grant insert (org_id, title, artist, license_type, license_source, license_proof_path, license_expires_at,
              youtube_monetization_allowed, attribution_text, audio_path, duration_sec) on video.music_library to authenticated;
grant update (title, artist, license_source, license_proof_path, license_expires_at, attribution_text) on video.music_library to authenticated;
grant delete on video.music_library to authenticated;
drop policy if exists music_library_insert on video.music_library;
create policy music_library_insert on video.music_library for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and video.org_has_feature(org_id, 'tracks', 'F'));
drop policy if exists music_library_update on video.music_library;
create policy music_library_update on video.music_library for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists music_library_delete on video.music_library;
create policy music_library_delete on video.music_library for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- playlists (Track F 기능 필요)
grant insert (org_id, title, mood, target_duration_min, language, visual_style, cover_prompt, description_body) on video.playlists to authenticated;
grant update (title, mood, target_duration_min, language, visual_style, cover_prompt, description_body) on video.playlists to authenticated;
grant delete on video.playlists to authenticated;
drop policy if exists playlists_insert on video.playlists;
create policy playlists_insert on video.playlists for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and video.org_has_feature(org_id, 'tracks', 'F'));
drop policy if exists playlists_update on video.playlists;
create policy playlists_update on video.playlists for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists playlists_delete on video.playlists;
create policy playlists_delete on video.playlists for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- playlist_items
grant insert (org_id, playlist_id, position, music_track_id, library_track_id) on video.playlist_items to authenticated;
grant update (position) on video.playlist_items to authenticated;
grant delete on video.playlist_items to authenticated;
drop policy if exists playlist_items_insert on video.playlist_items;
create policy playlist_items_insert on video.playlist_items for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and video.org_has_feature(org_id, 'tracks', 'F'));
drop policy if exists playlist_items_update on video.playlist_items;
create policy playlist_items_update on video.playlist_items for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists playlist_items_delete on video.playlist_items;
create policy playlist_items_delete on video.playlist_items for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- landing_pages: 생성/상태는 서버와 RPC, 문구만 사용자 편집
grant update (product_name, headline, features) on video.landing_pages to authenticated;
drop policy if exists landing_pages_update on video.landing_pages;
create policy landing_pages_update on video.landing_pages for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));

-- linkinbio_profiles: owner/admin
grant insert (org_id, handle, display_name, bio, avatar_path, is_published) on video.linkinbio_profiles to authenticated;
grant update (handle, display_name, bio, avatar_path, is_published) on video.linkinbio_profiles to authenticated;
grant delete on video.linkinbio_profiles to authenticated;
drop policy if exists linkinbio_profiles_insert on video.linkinbio_profiles;
create policy linkinbio_profiles_insert on video.linkinbio_profiles for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'video'));
drop policy if exists linkinbio_profiles_update on video.linkinbio_profiles;
create policy linkinbio_profiles_update on video.linkinbio_profiles for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'video'));
drop policy if exists linkinbio_profiles_delete on video.linkinbio_profiles;
create policy linkinbio_profiles_delete on video.linkinbio_profiles for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- linkinbio_items
grant insert (org_id, profile_id, kind, title, url, landing_page_id, affiliate_link_id, position, is_active) on video.linkinbio_items to authenticated;
grant update (kind, title, url, landing_page_id, affiliate_link_id, position, is_active) on video.linkinbio_items to authenticated;
grant delete on video.linkinbio_items to authenticated;
drop policy if exists linkinbio_items_insert on video.linkinbio_items;
create policy linkinbio_items_insert on video.linkinbio_items for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists linkinbio_items_update on video.linkinbio_items;
create policy linkinbio_items_update on video.linkinbio_items for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists linkinbio_items_delete on video.linkinbio_items;
create policy linkinbio_items_delete on video.linkinbio_items for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- workflows
grant insert (org_id, name, graph) on video.workflows to authenticated;
grant update (name, graph) on video.workflows to authenticated;
grant delete on video.workflows to authenticated;
drop policy if exists workflows_insert on video.workflows;
create policy workflows_insert on video.workflows for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists workflows_update on video.workflows;
create policy workflows_update on video.workflows for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists workflows_delete on video.workflows;
create policy workflows_delete on video.workflows for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- banned_words
grant insert (org_id, word, severity) on video.banned_words to authenticated;
grant delete on video.banned_words to authenticated;
drop policy if exists banned_words_insert on video.banned_words;
create policy banned_words_insert on video.banned_words for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists banned_words_delete on video.banned_words;
create policy banned_words_delete on video.banned_words for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- client_reviews: 토큰 해시는 사용자에게 보이지 않는다(컬럼 단위 SELECT). 쓰기는 RPC/서버만.
grant select (id, org_id, client_id, upload_id, expires_at, decision, reviewer_name, comment, decided_at, requested_by, created_at, updated_at)
  on video.client_reviews to authenticated;
drop policy if exists client_reviews_select on video.client_reviews;
create policy client_reviews_select on video.client_reviews for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'video'));

-- clients (대행 고객, features.agency 필요). 생성·수정·삭제는 owner/admin. status 는 RPC(set_client_status)로만.
grant insert (org_id, name, brand_name, business_no, contact_name, contact_email, contact_phone, brand_guide_path, brand_wiki_ref,
              package_code, contract_start, contract_end, monthly_quota, review_required, report_day, notes) on video.clients to authenticated;
grant update (name, brand_name, business_no, contact_name, contact_email, contact_phone, brand_guide_path, brand_wiki_ref,
              package_code, contract_start, contract_end, monthly_quota, review_required, report_day, notes) on video.clients to authenticated;
grant delete on video.clients to authenticated;
drop policy if exists clients_insert on video.clients;
create policy clients_insert on video.clients for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and video.org_has_feature(org_id, 'agency'));
drop policy if exists clients_update on video.clients;
create policy clients_update on video.clients for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and video.org_has_feature(org_id, 'agency'))
  with check (core.has_org_role(org_id, array['owner', 'admin']) and video.org_has_feature(org_id, 'agency'));
drop policy if exists clients_delete on video.clients;
create policy clients_delete on video.clients for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- client_channels: owner/admin 이 고객에 채널을 묶고 푼다
grant insert (org_id, client_id, channel_id, ownership) on video.client_channels to authenticated;
grant delete on video.client_channels to authenticated;
drop policy if exists client_channels_insert on video.client_channels;
create policy client_channels_insert on video.client_channels for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and video.org_has_feature(org_id, 'agency'));
drop policy if exists client_channels_delete on video.client_channels;
create policy client_channels_delete on video.client_channels for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- =====================================================================
-- 6. 사용자용 RPC (SECURITY DEFINER, authenticated). 호출자 판정 = is_service_caller + has_org_role
-- =====================================================================

-- 채널 역할/언어/국가/일시정지 변경 (owner/admin)
create or replace function video.update_channel_settings(
  p_channel_id      uuid,
  p_role            text default null,
  p_target_language text default null,
  p_target_country  text default null,
  p_status          text default null
)
returns video.channels
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row    video.channels;
  v_before jsonb;
begin
  select * into v_row from video.channels where id = p_channel_id for update;
  if not found then
    raise exception 'update_channel_settings: channel not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'update_channel_settings: owner/admin only' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_row.org_id, 'video') then
    raise exception 'update_channel_settings: no video entitlement' using errcode = '42501';
  end if;
  if p_status is not null and p_status not in ('active', 'paused') then
    raise exception 'update_channel_settings: status must be active or paused' using errcode = '22023';
  end if;
  v_before := to_jsonb(v_row);
  update video.channels
     set role            = coalesce(p_role, role),
         target_language = coalesce(p_target_language, target_language),
         target_country  = coalesce(p_target_country, target_country),
         status          = coalesce(p_status, status)
   where id = p_channel_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'channel.update', 'channel', p_channel_id::text, v_before, to_jsonb(v_row));
  return v_row;
end;
$$;
revoke execute on function video.update_channel_settings(uuid, text, text, text, text) from public, anon;
grant execute on function video.update_channel_settings(uuid, text, text, text, text) to authenticated;

-- 채널 연결 해제 (owner/admin): 채널 revoked + 자격증명 revoke
create or replace function video.disconnect_channel(p_channel_id uuid)
returns video.channels
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.channels;
begin
  select * into v_row from video.channels where id = p_channel_id for update;
  if not found then
    raise exception 'disconnect_channel: channel not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'disconnect_channel: owner/admin only' using errcode = '42501';
  end if;
  if v_row.status = 'revoked' then
    return v_row;
  end if;
  if v_row.credential_id is not null then
    perform core.revoke_credential(v_row.credential_id);
  end if;
  update video.channels set status = 'revoked' where id = p_channel_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'channel.disconnect', 'channel', p_channel_id::text);
  return v_row;
end;
$$;
revoke execute on function video.disconnect_channel(uuid) from public, anon;
grant execute on function video.disconnect_channel(uuid) to authenticated;

-- compliance WARN 수동 확인 (owner/admin/member). awaiting_confirm → approved, 감사 기록.
create or replace function video.acknowledge_compliance_warning(p_upload_id uuid, p_note text default null)
returns video.uploads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     video.uploads;
  v_verdict text;
begin
  select * into v_row from video.uploads where id = p_upload_id for update;
  if not found then
    raise exception 'acknowledge_compliance_warning: upload not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'acknowledge_compliance_warning: not a member' using errcode = '42501';
  end if;
  if v_row.status <> 'awaiting_confirm' then
    raise exception 'acknowledge_compliance_warning: invalid state %', v_row.status using errcode = 'VD008';
  end if;
  select verdict into v_verdict from video.compliance_checks where id = v_row.compliance_check_id;
  if coalesce(v_verdict, '') <> 'warn' then
    raise exception 'acknowledge_compliance_warning: latest verdict is %', coalesce(v_verdict, 'none') using errcode = 'VD011';
  end if;
  update video.uploads
     set compliance_ack_by = auth.uid(), compliance_ack_at = now(), status = 'approved'
   where id = p_upload_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'upload.compliance_ack', 'upload', p_upload_id::text, null, null,
                           jsonb_build_object('compliance_check_id', v_row.compliance_check_id, 'note', p_note));
  return v_row;
end;
$$;
revoke execute on function video.acknowledge_compliance_warning(uuid, text) from public, anon;
grant execute on function video.acknowledge_compliance_warning(uuid, text) to authenticated;

-- 업로드 취소 (owner/admin/member). 대기 중인 업로드 잡이면 core.cancel_job 으로 함께 취소(환불 포함).
create or replace function video.cancel_upload(p_upload_id uuid)
returns video.uploads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row        video.uploads;
  v_job_status text;
begin
  select * into v_row from video.uploads where id = p_upload_id for update;
  if not found then
    raise exception 'cancel_upload: upload not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'cancel_upload: not a member' using errcode = '42501';
  end if;
  if v_row.status not in ('draft', 'blocked', 'awaiting_confirm', 'approved', 'scheduled', 'failed') then
    raise exception 'cancel_upload: invalid state %', v_row.status using errcode = 'VD008';
  end if;
  if v_row.job_id is not null then
    select status into v_job_status from core.jobs where id = v_row.job_id;
    if v_job_status = 'running' then
      raise exception 'cancel_upload: upload is in progress' using errcode = 'VD008';
    elsif v_job_status = 'queued' then
      perform core.cancel_job(v_row.job_id);
    end if;
  end if;
  update video.uploads set status = 'canceled' where id = p_upload_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'upload.cancel', 'upload', p_upload_id::text);
  return v_row;
end;
$$;
revoke execute on function video.cancel_upload(uuid) from public, anon;
grant execute on function video.cancel_upload(uuid) to authenticated;

-- 랜딩 공개/비공개 (owner/admin/member). 공개하려면 제휴 링크와 coupang_landing 기능 필요.
create or replace function video.set_landing_status(p_landing_id uuid, p_status text)
returns video.landing_pages
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.landing_pages;
begin
  select * into v_row from video.landing_pages where id = p_landing_id for update;
  if not found then
    raise exception 'set_landing_status: landing not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'set_landing_status: not a member' using errcode = '42501';
  end if;
  if p_status not in ('draft', 'published', 'unpublished') then
    raise exception 'set_landing_status: invalid status' using errcode = '22023';
  end if;
  if p_status = 'published' then
    if not video.org_has_feature(v_row.org_id, 'coupang_landing') then
      raise exception 'set_landing_status: plan does not include landing pages' using errcode = 'VD009';
    end if;
    if v_row.primary_link_id is null then
      raise exception 'set_landing_status: affiliate link required' using errcode = 'VD001';
    end if;
  end if;
  update video.landing_pages
     set status = p_status,
         published_at = case when p_status = 'published' then now() else published_at end
   where id = p_landing_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'landing.' || p_status, 'landing_page', p_landing_id::text);
  return v_row;
end;
$$;
revoke execute on function video.set_landing_status(uuid, text) from public, anon;
grant execute on function video.set_landing_status(uuid, text) to authenticated;

-- 음원 DSP 유통 상태 수동 기록 (MVP: Distrokid 자동 배포는 Phase 2)
create or replace function video.set_music_distribution_status(
  p_track_id uuid,
  p_status   text,
  p_note     text default null,
  p_isrc     text default null
)
returns video.music_tracks
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.music_tracks;
begin
  select * into v_row from video.music_tracks where id = p_track_id for update;
  if not found then
    raise exception 'set_music_distribution_status: track not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'set_music_distribution_status: not a member' using errcode = '42501';
  end if;
  if p_status not in ('submitted', 'live', 'rejected', 'takedown') then
    raise exception 'set_music_distribution_status: status % is server-managed or invalid', p_status using errcode = '22023';
  end if;
  update video.music_tracks
     set distribution_status = p_status,
         distribution_note   = coalesce(p_note, distribution_note),
         isrc                = coalesce(p_isrc, isrc),
         distributed_at      = case when p_status = 'live' then now() else distributed_at end
   where id = p_track_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'music.distribution_' || p_status, 'music_track', p_track_id::text);
  return v_row;
end;
$$;
revoke execute on function video.set_music_distribution_status(uuid, text, text, text) from public, anon;
grant execute on function video.set_music_distribution_status(uuid, text, text, text) to authenticated;

-- 네이버 클립 자동 업로드 위험 동의 (owner/admin, VD-F-075). 고지문 버전이 현재 버전과 같아야 한다.
create or replace function video.consent_clip_automation_risk(p_channel_id uuid, p_version text)
returns video.channels
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.channels;
begin
  select * into v_row from video.channels where id = p_channel_id for update;
  if not found then
    raise exception 'consent_clip_automation_risk: channel not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'consent_clip_automation_risk: owner/admin only' using errcode = '42501';
  end if;
  if v_row.platform <> 'naver_clip' then
    raise exception 'consent_clip_automation_risk: not a naver_clip channel' using errcode = '22023';
  end if;
  if p_version is distinct from video.clip_notice_version() then
    raise exception 'consent_clip_automation_risk: notice version % is not current (%)', p_version, video.clip_notice_version()
      using errcode = 'VD015';
  end if;
  update video.channels
     set automation_consent_version = p_version, automation_consented_at = now(), automation_consented_by = auth.uid()
   where id = p_channel_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'channel.clip_risk_consent', 'channel', p_channel_id::text, null, null,
                           jsonb_build_object('notice_version', p_version));
  return v_row;
end;
$$;
revoke execute on function video.consent_clip_automation_risk(uuid, text) from public, anon;
grant execute on function video.consent_clip_automation_risk(uuid, text) to authenticated;

-- 네이버 클립 위험 동의 철회 (owner/admin). 대기 중 업로드 잡은 서버가 취소한다(01_PRD 6.5절).
create or replace function video.revoke_clip_automation_consent(p_channel_id uuid)
returns video.channels
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.channels;
begin
  select * into v_row from video.channels where id = p_channel_id for update;
  if not found then
    raise exception 'revoke_clip_automation_consent: channel not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'revoke_clip_automation_consent: owner/admin only' using errcode = '42501';
  end if;
  update video.channels
     set automation_consent_version = null, automation_consented_at = null, automation_consented_by = null
   where id = p_channel_id
  returning * into v_row;
  perform core.write_audit(v_row.org_id, 'channel.clip_risk_revoke', 'channel', p_channel_id::text);
  return v_row;
end;
$$;
revoke execute on function video.revoke_clip_automation_consent(uuid) from public, anon;
grant execute on function video.revoke_clip_automation_consent(uuid) to authenticated;

-- 대행 고객 상태 변경 (owner/admin, VD-F-120). 종료(ended)는 되돌릴 수 없다.
create or replace function video.set_client_status(p_client_id uuid, p_status text)
returns video.clients
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.clients;
begin
  select * into v_row from video.clients where id = p_client_id for update;
  if not found then
    raise exception 'set_client_status: client not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'set_client_status: owner/admin only' using errcode = '42501';
  end if;
  update video.clients set status = p_status where id = p_client_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'client.status', 'client', p_client_id::text, null, null,
                           jsonb_build_object('status', p_status));
  return v_row;
end;
$$;
revoke execute on function video.set_client_status(uuid, text) from public, anon;
grant execute on function video.set_client_status(uuid, text) to authenticated;

-- 고객 승인 요청 열기 (service_role 전용, VD-F-123). Route Handler 가 토큰을 만들어 해시만 넘긴다.
-- approved 업로드 → client_review. 이전 pending 요청은 canceled 로 닫는다.
create or replace function video.open_client_review(p_upload_id uuid, p_token_hash text, p_expires_at timestamptz,
                                                    p_requested_by uuid default null)
returns video.client_reviews
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_up     video.uploads;
  v_client uuid;
  v_row    video.client_reviews;
begin
  select * into v_up from video.uploads where id = p_upload_id for update;
  if not found then
    raise exception 'open_client_review: upload not found' using errcode = 'P0002';
  end if;
  if v_up.status not in ('approved', 'client_review') then
    raise exception 'open_client_review: invalid state %', v_up.status using errcode = 'VD008';
  end if;
  select cc.client_id into v_client from video.client_channels cc where cc.channel_id = v_up.channel_id;
  if v_client is null then
    raise exception 'open_client_review: channel is not linked to a client' using errcode = 'VD016';
  end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '14 days' then
    raise exception 'open_client_review: expires_at must be within 14 days' using errcode = '22023';
  end if;
  update video.client_reviews set decision = 'canceled' where upload_id = p_upload_id and decision = 'pending';
  insert into video.client_reviews (org_id, client_id, upload_id, token_hash, expires_at, requested_by)
  values (v_up.org_id, v_client, p_upload_id, p_token_hash, p_expires_at, p_requested_by)
  returning * into v_row;
  if v_up.status = 'approved' then
    update video.uploads set status = 'client_review' where id = p_upload_id;
  end if;
  perform core.write_audit(v_up.org_id, 'upload.client_review_open', 'upload', p_upload_id::text, null, null,
                           jsonb_build_object('review_id', v_row.id, 'expires_at', p_expires_at));
  return v_row;
end;
$$;
revoke execute on function video.open_client_review(uuid, text, timestamptz, uuid) from public, anon, authenticated;

-- 고객 결정 기록 (service_role 전용). 승인 → 업로드 scheduled 가능, 수정 요청 → 업로드 draft.
create or replace function video.decide_client_review(p_token_hash text, p_decision text, p_reviewer_name text default null,
                                                      p_comment text default null)
returns video.client_reviews
language plpgsql
security definer
set search_path = ''
as $$
declare v_row video.client_reviews;
begin
  select * into v_row from video.client_reviews where token_hash = p_token_hash for update;
  if not found then
    raise exception 'decide_client_review: review not found' using errcode = 'P0002';
  end if;
  if v_row.decision <> 'pending' then
    raise exception 'decide_client_review: already %', v_row.decision using errcode = 'VD008';
  end if;
  if v_row.expires_at <= now() then
    -- 만료: 예외로 되돌리지 않고 expired 로 닫아 돌려준다(라우트가 decision 으로 만료 화면을 보인다)
    update video.client_reviews set decision = 'expired' where id = v_row.id returning * into v_row;
    return v_row;
  end if;
  if p_decision not in ('approved', 'changes_requested') then
    raise exception 'decide_client_review: invalid decision %', p_decision using errcode = '22023';
  end if;
  update video.client_reviews
     set decision = p_decision, reviewer_name = p_reviewer_name, comment = p_comment, decided_at = now()
   where id = v_row.id
  returning * into v_row;
  if p_decision = 'changes_requested' then
    update video.uploads set status = 'draft' where id = v_row.upload_id and status = 'client_review';
  end if;
  perform core.write_audit(v_row.org_id, 'upload.client_review_decide', 'upload', v_row.upload_id::text, null, null,
                           jsonb_build_object('review_id', v_row.id, 'decision', p_decision));
  return v_row;
end;
$$;
revoke execute on function video.decide_client_review(text, text, text, text) from public, anon, authenticated;

-- =====================================================================
-- 7. 공개 읽기 RPC (anon). 공개 상태 행의 공개 컬럼만 jsonb 로 반환한다.
--    대가성 문구는 org 문구 우선, 없으면 플랫폼 기본값. 랜딩/링크인바이오는 video_description 배치 문구를 재사용(제안).
-- =====================================================================
create or replace function video.get_public_landing(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'slug', l.slug,
    'product_name', l.product_name,
    'headline', l.headline,
    'features', l.features,
    'youtube_video_id', l.youtube_video_id,
    'primary', (select jsonb_build_object('short_code', a.short_code, 'product_name', a.product_name, 'provider', a.provider)
                from core.affiliate_links a where a.id = l.primary_link_id and a.is_active),
    'related', coalesce((select jsonb_agg(jsonb_build_object('short_code', a.short_code, 'product_name', a.product_name, 'provider', a.provider)
                                          order by array_position(l.related_link_ids, a.id))
                         from core.affiliate_links a where a.id = any (l.related_link_ids) and a.is_active), '[]'::jsonb),
    'disclosure', (select d.body from core.affiliate_disclosures d
                   join core.affiliate_links a on a.id = l.primary_link_id
                   where d.provider = a.provider and d.placement = 'video_description'
                     and (d.org_id = l.org_id or d.org_id is null)
                   order by d.org_id nulls last limit 1)
  )
  from video.landing_pages l
  where l.slug = p_slug and l.status = 'published' and core.has_entitlement(l.org_id, 'video');
$$;
revoke execute on function video.get_public_landing(text) from public;
grant execute on function video.get_public_landing(text) to anon, authenticated, service_role;

create or replace function video.get_public_linkinbio(p_handle text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'handle', p.handle,
    'display_name', p.display_name,
    'bio', p.bio,
    'avatar_path', p.avatar_path,
    'items', coalesce((
      select jsonb_agg(x.item order by x.position, x.created_at)
      from (
        select i.position, i.created_at,
               jsonb_build_object(
                 'kind', i.kind, 'title', i.title, 'url', i.url,
                 'landing_slug', lp.slug,
                 'short_code', a.short_code,
                 'disclosure', case when a.id is not null then (
                    select d.body from core.affiliate_disclosures d
                    where d.provider = a.provider and d.placement = 'video_description'
                      and (d.org_id = p.org_id or d.org_id is null)
                    order by d.org_id nulls last limit 1) end
               ) as item
        from video.linkinbio_items i
        left join video.landing_pages lp on lp.id = i.landing_page_id and lp.status = 'published'
        left join core.affiliate_links a on a.id = i.affiliate_link_id and a.is_active
        where i.profile_id = p.id and i.is_active
          and (i.kind in ('link', 'video') or lp.id is not null or a.id is not null)
      ) x), '[]'::jsonb)
  )
  from video.linkinbio_profiles p
  where p.handle = p_handle and p.is_published and core.has_entitlement(p.org_id, 'video');
$$;
revoke execute on function video.get_public_linkinbio(text) from public;
grant execute on function video.get_public_linkinbio(text) to anon, authenticated, service_role;

-- =====================================================================
-- 8. service_role 전용 운영 함수
-- =====================================================================

-- 원본 24시간 보존 정책: ready 원본 중 purge_after 지난 행을 purged 로 바꾸고 Storage 경로를 돌려준다(워커가 객체 삭제).
create or replace function video.purge_expired_sources(p_limit integer default 500)
returns table (source_id uuid, org_id uuid, storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'purge_expired_sources: service_role only' using errcode = '42501';
  end if;
  return query
  with c as (
    select s.id from video.sources s
    where s.status = 'ready' and s.purge_after <= now()
    order by s.purge_after
    limit greatest(p_limit, 1)
    for update skip locked
  )
  update video.sources s
     set status = 'purged', purged_at = now()
    from c
   where s.id = c.id
  returning s.id, s.org_id, s.storage_path;
end;
$$;
revoke execute on function video.purge_expired_sources(integer) from public, anon, authenticated;
grant execute on function video.purge_expired_sources(integer) to service_role;

-- YouTube 일일 쿼터 리셋(스케줄러가 쿼터 리셋 시각에 호출)
create or replace function video.reset_channel_quotas()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_cnt integer;
begin
  if not core.is_privileged_session() then
    raise exception 'reset_channel_quotas: service_role only' using errcode = '42501';
  end if;
  update video.channels set quota_used_today = 0, quota_reset_at = now() where platform = 'youtube' and quota_used_today > 0;
  get diagnostics v_cnt = row_count;
  return v_cnt;
end;
$$;
revoke execute on function video.reset_channel_quotas() from public, anon, authenticated;
grant execute on function video.reset_channel_quotas() to service_role;

-- 랜딩 조회수 증가(공개 라우트가 레이트 리밋 뒤 service_role 로 호출)
create or replace function video.record_landing_view(p_slug text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'record_landing_view: service_role only' using errcode = '42501';
  end if;
  update video.landing_pages set view_count = view_count + 1 where slug = p_slug and status = 'published';
end;
$$;
revoke execute on function video.record_landing_view(text) from public, anon, authenticated;
grant execute on function video.record_landing_view(text) to service_role;

-- =====================================================================
-- 9. Storage: 대용량 미디어 버킷(제품 소유, core 경로 규칙 <org_id>/video/<entity>/<uuid>.<ext> 사용)
--    org-files(50MB)/exports(200MB)로는 롱폼과 3시간 플리 영상을 담을 수 없다. 쓰기는 서버(service_role)만.
--    5GB 상한은 제안(01_PRD 5장). 사용자 업로드(라이선스 증빙, 라이브러리 음원)는 core org-files 버킷을 쓴다.
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('video-media', 'video-media', false, 5368709120,
        array['video/mp4', 'video/webm', 'video/quicktime', 'audio/mpeg', 'audio/wav', 'audio/x-wav', 'audio/mp4',
              'image/png', 'image/jpeg', 'image/webp', 'text/vtt', 'text/plain', 'application/zip'])
on conflict (id) do nothing;

drop policy if exists video_media_select on storage.objects;
create policy video_media_select on storage.objects for select to authenticated
  using (bucket_id = 'video-media'
         and core.is_org_member(core.storage_org_id(name))
         and core.has_entitlement(core.storage_org_id(name), 'video'));

-- =====================================================================
-- 끝. 스케줄(워커 크론, service_role):
--   매 10분  video.purge_expired_sources()  → Storage 객체 삭제
--   매일 PT 00:00(쿼터 리셋 시각, 미확인)  video.reset_channel_quotas()
-- =====================================================================

-- =====================================================================
-- 10. 함수 EXECUTE 정리 (0007_core_function_privileges.sql 와 같은 규칙)
--     alter default privileges ... revoke 는 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 지우지 못한다.
--     스키마 전체에서 PUBLIC EXECUTE 를 회수하고, 위에서 역할별로 준 GRANT 만 남긴다.
--     트리거 함수(enforce_status_transition, guard_user_edit, check_refs, enforce_channel_limit)는 사용자 EXECUTE 가 필요 없다.
-- =====================================================================
revoke execute on all functions in schema video from public;
grant execute on function video.org_has_feature(uuid, text, text) to authenticated, service_role;
grant execute on function video.get_public_landing(text) to anon, authenticated, service_role;
grant execute on function video.get_public_linkinbio(text) to anon, authenticated, service_role;
grant execute on all functions in schema video to service_role;

-- =====================================================================
-- 11. AI·음성 기본값 (2026-10-13, 확정 결정 13~17)
--   설계: docs/products/sceneflow/02_ARCHITECTURE.md 5절, 01_PRD.md 4.1절. 정본 규칙은 _platform-core/AI_ARCHITECTURE.md 4장,
--   VOICE_ARCHITECTURE.md 3장. 모든 값은 제안이며 운영 화면이 아니라 이 조각과 모놀리스 seed 에서만 바꾼다.
--   제품 전용 AI 테이블은 만들지 않았다(05_DATA_MODEL.md 6절). 이 절은 core.* 를 ALTER 하지 않고 데이터 행만 넣는다.
--   11.1 기능별 라우팅 기본값: org_id null(플랫폼 기본), app_id 'video'. 기능 키는 소문자(core 체크 제약).
--        체인 제공자는 seed.sql 의 core.ai_providers 행이어야 하고 kind 가 맞아야 한다(11.3 검사).
--        - video.script/translate/bling, chat : 품질 우선 Claude 먼저. 채널 토큰·이메일·원본 영상/오디오는 보내지 않는다.
--                          국외 이전 동의가 없는 조직은 resolve_ai_route 가 상용을 걸러 낸다.
--        - video.analyze/compliance, wiki.*  : 단순 분류·요약·대량 처리라 오픈소스 먼저.
--        - dify.aux      : Dify 보조 LLM 노드. 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--        - video.knowledge/rag (embedding) : 운영자·조직 컬렉션 공통. 동의 변경에 임베딩 모델이 흔들리지 않게 오픈소스 고정(대체 없음).
--        - video.stt     : 파이프라인 STT(미디어 워커 Whisper). 원본은 제3자 저작물·목소리라 국외 제공자로 보내지 않는다 → 오픈소스 강제.
--        - voice_chat/dictation : 대화형 STT 는 오픈소스 먼저, 응답·대본 읽어 주기 TTS 는 ElevenLabs 먼저.
--        - narration     : 내레이션·샘플 TTS. 사용자가 생산 요청에서 엔진을 고른다. 작업 도중 다른 제공자로 대체하지 않는다.
--                          이 금지는 체인이 아니라 음성 어댑터(packages/core-voice, feature=narration)와 오케스트레이터가 강제한다.
--   11.2 플랜 features 의 AI 키. seed.sql 이 이 조각보다 나중에 실행되면 덮어써지므로 _supabase-modular/seed.sql 반영을
--        코어에 요청했다(06_AGENT_PLAN.md 6절 R-V1). 서버는 누락 키를 기본값으로 읽는다.
-- =====================================================================
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'video', 'video.script',     'llm',        'auto',         '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'video', 'video.translate',  'llm',        'auto',         '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'video', 'video.analyze',    'llm',        'auto',         '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'video', 'video.bling',      'llm',        'auto',         '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'video', 'video.compliance', 'llm',        'auto',         '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'video', 'chat',             'llm',        'auto',         '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'video', 'wiki.query',       'llm',        'auto',         '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'video', 'wiki.ingest',      'llm',        'auto',         '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'video', 'wiki.lint',        'llm',        'auto',         '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'video', 'dify.aux',         'llm',        'open_source',  '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'video', 'video.knowledge',  'embedding',  'open_source',  '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'video', 'video.rag',        'embedding',  'open_source',  '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'video', 'video.stt',        'stt',        'open_source',  '[{"provider":"oss-voice","model":"*"}]', true),
  (null, 'video', 'voice_chat',       'stt',        'auto',         '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'video', 'dictation',        'stt',        'auto',         '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'video', 'voice_chat',       'tts',        'auto',         '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'video', 'narration',        'tts',        'auto',         '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 11.2 플랜 AI 키(있으면 병합, 없으면 아무 일도 하지 않음)
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "ai_script": false}'::jsonb
 where app_id = 'video' and code = 'starter';
update core.plans
   set features = features || '{"ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "ai_script": true}'::jsonb
 where app_id = 'video' and code in ('basic', 'pro', 'advanced');

-- 11.3 체인 검사: 제공자 행이 있을 때만(seed 전에 적용되는 배포 순서에서도 실패하지 않게) 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'video'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'video routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;

-- =====================================================================
-- 2026-10-18 스토리보드 트랙(Track S)
-- 12. 스토리보드 트랙 (확정 SF-1: Track C Mode1 + Track D → Track S, VD-F-130~142)
--   기획: docs/products/sceneflow/05_DATA_MODEL.md 11장, 01_PRD.md 10장. 위쪽 절은 고치지 않았다(다른 문서가 줄 번호로 인용).
--   기존 테이블 변경(outputs 소유 FK·CHECK, productions/sources track 표시, longform 주석, 플랜 키)은 이 절의 ALTER/UPDATE 로만 한다.
--   새 테이블 6개
--     storyboard_templates  운영자 seed(5종). 사용자 쓰기 없음 + guard
--     storyboards           사용자 콘텐츠(컬럼 단위 GRANT + with check). 상태·버전·revision 은 서버/RPC 만
--     scenes                사용자 RPC(save_scene 등)로만 쓴다. 쓰기 정책 없음 + guard
--     scene_assets, storyboard_cuts, storyboard_snapshots  서버(service_role)만. 쓰기 정책 없음 + guard
--   사용자 정의 SQLSTATE 추가: VD017 장면 길이 합계 범위 밖(목표 ±10%), VD018 장면 수 범위 밖, VD019 clip 소재 권리 근거 없음,
--     VD020 렌더 중 편집, VD021 쇼츠 컷 한도 초과, VD409 낙관적 동시성 충돌(revision 불일치).
--   길이 합계(VD017)와 장면 수 하한(VD018)은 편집 중에는 막지 않는다(편집기 게이지가 표시). 그래프 결과 반영과 렌더 스냅샷에서 막는다.
--   크레딧 차감·환불은 이 절에서 하지 않는다(Route Handler/워커가 core RPC 호출).
--   잡은 core.jobs 를 그대로 쓴다(queue·kind CHECK 없음): 렌더 루트 잡 video.orchestrate 큐, FFmpeg 단계
--   media.scene_clip / media.scene_concat / media.bgm_mix 는 video.media.cpu 자식 잡(04장 새 장). storyboards.root_job_id 가 루트.
--   장면 소재 파일은 video-media 버킷 <org_id>/video/scenes/<scene_id>/<uuid>.<ext>. 사용자 업로드는 서버가 검사 뒤 이 경로로 옮긴다(제안).
-- =====================================================================

-- 12.1 헬퍼 ------------------------------------------------------------

-- 형식·목표 길이별 장면 수 범위. 쇼츠 3~12, 롱폼 분당 3~8(최대 240).
create or replace function video.scene_count_limits(p_format text, p_target_seconds integer,
                                                    out min_scenes integer, out max_scenes integer)
language sql
immutable
set search_path = ''
as $$
  select case when p_format = 'shorts' then 3 else ceil(p_target_seconds / 60.0 * 3)::integer end,
         case when p_format = 'shorts' then 12 else least(240, floor(p_target_seconds / 60.0 * 8)::integer) end;
$$;

-- 장면 출처 배열 검사(CHECK 용). [{title(1~200자, 필수), url(http/https, 선택), note(300자 이하, 선택)}], 최대 5개.
create or replace function video.valid_scene_sources(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case when p is null or jsonb_typeof(p) <> 'array' then false
              when jsonb_array_length(p) > 5 then false
              else not exists (
                select 1 from jsonb_array_elements(p) as e(item)
                where case when jsonb_typeof(e.item) <> 'object' then true
                           else jsonb_typeof(e.item -> 'title') is distinct from 'string'
                             or char_length(btrim(e.item ->> 'title')) not between 1 and 200
                             or (coalesce(jsonb_typeof(e.item -> 'url'), 'null') <> 'null'
                                 and (jsonb_typeof(e.item -> 'url') <> 'string'
                                      or (e.item ->> 'url') !~* '^https?://'
                                      or char_length(e.item ->> 'url') > 2000))
                             or (coalesce(jsonb_typeof(e.item -> 'note'), 'null') <> 'null'
                                 and (jsonb_typeof(e.item -> 'note') <> 'string'
                                      or char_length(e.item ->> 'note') > 300))
                             or exists (select 1 from jsonb_object_keys(e.item) as k(key)
                                        where k.key not in ('title', 'url', 'note'))
                      end)
         end;
$$;

-- 새 테이블 상태 전이(기존 enforce_status_transition 과 같은 방식, 표만 다름). service_role 쓰기에도 적용된다.
create or replace function video.enforce_storyboard_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_old text := to_jsonb(old) ->> 'status';
  v_new text := to_jsonb(new) ->> 'status';
  v_map constant jsonb := '{
    "storyboard_templates.status": {"active":["retired"], "retired":["active"]},
    "storyboards.status":          {"draft":["ready","archived"], "ready":["draft","rendering","archived"], "rendering":["rendered","ready"], "rendered":["ready","rendering","archived"]},
    "scene_assets.status":         {"ready":["superseded"]},
    "storyboard_cuts.status":      {"proposed":["rendering"], "rendering":["ready","failed"], "failed":["rendering"], "ready":["rendering"]}
  }'::jsonb;
begin
  if v_old is distinct from v_new then
    if not coalesce((v_map -> (tg_table_name || '.status') -> v_old) ? v_new, false) then
      raise exception 'video: invalid %.status transition % -> %', tg_table_name, v_old, v_new
        using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;

-- 12.2 테이블 ----------------------------------------------------------

-- 12.2.1 storyboard_templates: 스토리보드 템플릿(VD-F-141). 플랫폼 공용, 운영자 seed 만(12.9절).
--   beats: [{"key","label","share"(목표 길이 비율, 합 1), "kind"(scene_kind 기본값), "hint"}]
create table if not exists video.storyboard_templates (
  code                  text primary key constraint storyboard_templates_code_check check (code ~ '^[a-z][a-z0-9_]{2,39}$'),
  label                 text not null constraint storyboard_templates_label_check check (length(btrim(label)) between 1 and 60),
  beats                 jsonb not null default '[]'::jsonb,
  default_scene_seconds integer not null default 6 constraint storyboard_templates_seconds_check check (default_scene_seconds between 2 and 30),
  status                text not null default 'active' constraint storyboard_templates_status_check check (status in ('active', 'retired')),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint storyboard_templates_beats_check check (jsonb_typeof(beats) = 'array' and jsonb_array_length(beats) between 1 and 20)
);

-- 12.2.2 storyboards: 스토리보드 프로젝트 1건(VD-F-130). 롱폼 마스터 컷 + 쇼츠 컷 + 언어판의 기준.
--   version  = 마지막 렌더 스냅샷 번호(snapshot_storyboard 가 올린다, 0 = 렌더 없음)
--   revision = 장면 구성(추가·삭제·순서·전체 생성) 변경 번호. 장면 내용 충돌은 scenes.revision 으로 본다.
create table if not exists video.storyboards (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  client_id        uuid references video.clients(id) on delete set null,
  title            text not null constraint storyboards_title_check check (length(btrim(title)) between 1 and 200),
  format           text not null constraint storyboards_format_check check (format in ('shorts', 'longform')),
  aspect           text not null constraint storyboards_aspect_check check (aspect in ('9:16', '16:9')),
  target_seconds   integer not null,
  template_code    text not null references video.storyboard_templates(code),
  topic            text constraint storyboards_topic_check check (topic is null or length(topic) <= 300),
  script_ai_run_id uuid references core.ai_runs(id) on delete set null,
  languages        text[] not null default array['KO']::text[],
  -- 내레이션 목소리 고정(같은 목소리 규칙, 02장 5.3절). 장면 다시 만들기는 이 값을 따른다. 둘 다 null 이거나 둘 다 값.
  voice_provider   text constraint storyboards_voice_provider_check check (voice_provider in ('elevenlabs', 'oss')),
  voice_id         text constraint storyboards_voice_id_check check (voice_id is null or length(btrim(voice_id)) between 1 and 120),
  status           text not null default 'draft'
                   constraint storyboards_status_check check (status in ('draft', 'ready', 'rendering', 'rendered', 'archived')),
  version          integer not null default 0 constraint storyboards_version_check check (version >= 0),
  revision         integer not null default 1 constraint storyboards_revision_check check (revision >= 1),
  root_job_id      uuid references core.jobs(id) on delete set null,
  last_error       text,
  created_by       uuid default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- 형식 프리셋: 쇼츠 15/30/45/60/90초(9:16), 롱폼 3/5/10/20/30/60분(16:9)
  constraint storyboards_preset_check check (
       (format = 'shorts'   and aspect = '9:16' and target_seconds in (15, 30, 45, 60, 90))
    or (format = 'longform' and aspect = '16:9' and target_seconds in (180, 300, 600, 1200, 1800, 3600))),
  constraint storyboards_languages_check check (cardinality(languages) between 1 and 3 and languages <@ array['KO', 'JA', 'EN']::text[]),
  constraint storyboards_voice_pair_check check ((voice_provider is null) = (voice_id is null))
);
create index if not exists storyboards_org_idx on video.storyboards (org_id, created_at desc);
create index if not exists storyboards_status_idx on video.storyboards (org_id, status);
create index if not exists storyboards_client_idx on video.storyboards (client_id) where client_id is not null;

-- 12.2.3 scenes: 장면(VD-F-132). ord 1..240, 재정렬을 위해 unique 는 deferrable.
--   revision 은 내용 컬럼이 바뀔 때만 트리거가 1 올린다(ord, shorts_candidate 변경은 올리지 않음).
--   source_required 는 그래프가 사실 주장 장면에 표시한다(서버만). sources 가 비어 있으면 출처 경고(VD-F-138).
create table if not exists video.scenes (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  storyboard_id    uuid not null references video.storyboards(id) on delete cascade,
  ord              integer not null constraint scenes_ord_check check (ord between 1 and 240),
  chapter          text constraint scenes_chapter_check check (chapter is null or length(btrim(chapter)) between 1 and 80),
  kind             text not null default 'image' constraint scenes_kind_check check (kind in ('image', 'clip', 'text_card', 'title')),
  duration_ms      integer not null default 6000 constraint scenes_duration_check check (duration_ms between 1000 and 60000),
  narration        text constraint scenes_narration_check check (narration is null or char_length(narration) <= 600),
  on_screen_text   text constraint scenes_on_screen_text_check check (on_screen_text is null or char_length(on_screen_text) <= 160),
  visual_prompt    text constraint scenes_visual_prompt_check check (visual_prompt is null or char_length(visual_prompt) <= 600),
  motion_preset    text not null default 'static'
                   constraint scenes_motion_check check (motion_preset in ('zoom_in', 'zoom_out', 'pan_left', 'pan_right', 'static')),
  music_cue        text constraint scenes_music_cue_check check (music_cue is null or music_cue in ('intro', 'build', 'drop', 'calm', 'outro')),
  shorts_candidate boolean not null default false,
  sources          jsonb not null default '[]'::jsonb constraint scenes_sources_check check (video.valid_scene_sources(sources)),
  source_required  boolean not null default false,
  revision         integer not null default 1 constraint scenes_revision_check check (revision >= 1),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint scenes_ord_uniq unique (storyboard_id, ord) deferrable initially deferred
);
create index if not exists scenes_shorts_idx on video.scenes (storyboard_id, ord) where shorts_candidate;
create index if not exists scenes_source_warn_idx on video.scenes (storyboard_id) where source_required and sources = '[]'::jsonb;

-- 12.2.4 scene_assets: 장면 소재(VD-F-133, 134). 다시 만들면 이전 소재는 superseded 로 남긴다(되돌리기 P1).
--   (scene, kind, lang, aspect) 마다 ready 1개. lang 은 narration 만. aspect 는 image 필수(쇼츠용 9:16 세로 이미지를 따로 보관),
--   clip 은 선택, narration 은 없음. clip 은 rights_basis + rights_note 필수(VD019, 표는 23514).
create table if not exists video.scene_assets (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  scene_id             uuid not null references video.scenes(id) on delete cascade,
  kind                 text not null constraint scene_assets_kind_check check (kind in ('image', 'narration', 'clip')),
  lang                 text constraint scene_assets_lang_check check (lang in ('KO', 'JA', 'EN')),
  aspect               text constraint scene_assets_aspect_check check (aspect in ('16:9', '9:16')),
  status               text not null default 'ready' constraint scene_assets_status_check check (status in ('ready', 'superseded')),
  storage_path         text not null,
  rights_basis         text constraint scene_assets_rights_check check (rights_basis in ('public_free', 'creative_commons', 'licensed', 'own')),
  rights_note          text constraint scene_assets_rights_note_check check (rights_note is null or char_length(rights_note) <= 500),
  ai_generated         boolean not null default true,
  reused_from_asset_id uuid references video.scene_assets(id) on delete set null,
  meta                 jsonb not null default '{}'::jsonb,  -- provider, model, voice_id, voice_job_id, duration_ms, width, height
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint scene_assets_lang_kind_check check ((kind = 'narration') = (lang is not null)),
  constraint scene_assets_aspect_kind_check check (
    (kind = 'image' and aspect is not null) or kind = 'clip' or (kind = 'narration' and aspect is null)),
  constraint scene_assets_clip_rights_check check (
    kind <> 'clip' or (rights_basis is not null and rights_note is not null and length(btrim(rights_note)) >= 2 and not ai_generated)),
  constraint scene_assets_path_check check (
    split_part(storage_path, '/', 1) = org_id::text
    and storage_path ~ '^[0-9a-f-]{36}/video/scenes/[0-9a-f-]{36}/[0-9a-f-]{36}\.(png|jpg|jpeg|webp|mp3|wav|m4a|mp4|webm|mov)$'),
  constraint scene_assets_meta_check check (jsonb_typeof(meta) = 'object' and pg_column_size(meta) <= 4096)
);
create unique index if not exists scene_assets_one_ready_uniq on video.scene_assets (scene_id, kind, (coalesce(lang, '')), (coalesce(aspect, '')))
  where status = 'ready';
create index if not exists scene_assets_scene_idx on video.scene_assets (scene_id, created_at desc);
create index if not exists scene_assets_reuse_idx on video.scene_assets (org_id, created_at desc) where status = 'ready' and kind = 'image';

-- 12.2.5 storyboard_cuts: 렌더 단위. master 1개(스토리보드 화면비) + short 최대 10개(9:16, 연속 장면, VD-F-137).
--   상태는 렌더 진행. 출력물은 video.outputs.storyboard_cut_id 로 이어진다.
create table if not exists video.storyboard_cuts (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  storyboard_id uuid not null references video.storyboards(id) on delete cascade,
  kind          text not null constraint storyboard_cuts_kind_check check (kind in ('master', 'short')),
  aspect        text not null constraint storyboard_cuts_aspect_check check (aspect in ('9:16', '16:9')),
  scene_ids     uuid[] not null constraint storyboard_cuts_scene_ids_check check (cardinality(scene_ids) between 1 and 240),
  hook_text     text constraint storyboard_cuts_hook_check check (hook_text is null or char_length(hook_text) <= 100),
  status        text not null default 'proposed'
                constraint storyboard_cuts_status_check check (status in ('proposed', 'rendering', 'ready', 'failed')),
  ord           integer not null default 0 constraint storyboard_cuts_ord_check check (ord between 0 and 10),
  job_id        uuid references core.jobs(id) on delete set null,
  last_error    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint storyboard_cuts_kind_shape_check check (
       (kind = 'master' and ord = 0 and hook_text is null)
    or (kind = 'short'  and aspect = '9:16' and ord between 1 and 10 and cardinality(scene_ids) <= 12)),
  constraint storyboard_cuts_ord_uniq unique (storyboard_id, kind, ord)
);
create unique index if not exists storyboard_cuts_one_master on video.storyboard_cuts (storyboard_id) where kind = 'master';

-- 12.2.6 storyboard_snapshots: 렌더마다 1행(VD-F-139). 읽기 전용(UPDATE 는 service 도 거부). org_id 는 RLS 용.
create table if not exists video.storyboard_snapshots (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references core.organizations(id) on delete cascade,
  storyboard_id uuid not null references video.storyboards(id) on delete cascade,
  cut_id        uuid not null references video.storyboard_cuts(id) on delete cascade,
  version       integer not null constraint storyboard_snapshots_version_check check (version >= 1),
  snapshot      jsonb not null,
  created_at    timestamptz not null default now(),
  constraint storyboard_snapshots_version_uniq unique (storyboard_id, version),
  constraint storyboard_snapshots_shape_check check (jsonb_typeof(snapshot) = 'object' and pg_column_size(snapshot) <= 2097152)
);
create index if not exists storyboard_snapshots_cut_idx on video.storyboard_snapshots (cut_id, version desc);

-- 12.2.7 기존 테이블 변경
-- outputs: 스토리보드 컷 출력물. "소유 엔티티 정확히 1개" CHECK 에 storyboard_cut_id 를 넣는다.
--   kind 는 기존 값을 쓴다: 쇼츠 컷과 쇼츠 형식 마스터 = short, 롱폼 마스터 = longform.
alter table video.outputs add column if not exists storyboard_cut_id uuid references video.storyboard_cuts(id) on delete cascade;
alter table video.outputs drop constraint if exists outputs_owner_check;
alter table video.outputs add constraint outputs_owner_check
  check (num_nonnulls(production_id, longform_id, highlight_id, music_track_id, playlist_id, storyboard_cut_id) = 1);
alter table video.outputs drop constraint if exists outputs_kind_owner_check;
alter table video.outputs add constraint outputs_kind_owner_check check (
       (kind = 'short'      and production_id  is not null)
    or (kind = 'longform'   and longform_id    is not null)
    or (kind = 'highlight'  and highlight_id   is not null)
    or (kind = 'music_loop' and music_track_id is not null)
    or (kind = 'playlist'   and playlist_id    is not null)
    or (kind in ('short', 'longform') and storyboard_cut_id is not null));
create unique index if not exists outputs_storyboard_cut_lang_uniq on video.outputs (storyboard_cut_id, language) where storyboard_cut_id is not null;

-- productions/sources.track: 값 C 는 기존 행 호환으로 남기고 신규 생성 금지만 표시한다(제안, DB 차단 없음).
--   신규 Track S 는 productions 를 쓰지 않고 storyboards 를 쓴다. Track C Mode2(원본 재편집)는 Track A 옵션으로 흡수(SF-1).
comment on constraint productions_track_check on video.productions is
  '2026-10-18 SF-1: C 는 신규 생성 금지(기존 행 호환으로 값 유지, 제안). Track S 는 video.storyboards, C Mode2 는 Track A 옵션';
comment on constraint sources_track_check on video.sources is
  '2026-10-18 SF-1: C 는 신규 생성 금지(기존 행 호환으로 값 유지, 제안). C Mode2 원본은 Track A 로 소싱';
-- 기존 Track D 테이블은 지우지 않는다. 데이터 이전은 VD-F-142, 삭제 시점은 D-34.
comment on table video.longform_projects is 'Track D 롱폼. 2026-10-18 Track S(video.storyboards)로 대체, 신규 생성 안 함. 삭제는 D-34';
comment on table video.longform_sections is 'Track D 섹션. 2026-10-18 Track S(video.scenes)로 대체. 삭제는 D-34';
comment on table video.longform_highlights is 'Track D OSMU. 2026-10-18 Track S(video.storyboard_cuts kind=short)로 대체(VD-F-137이 VD-F-041 대체). 삭제는 D-34';

-- 12.3 트리거 함수 ------------------------------------------------------

-- 스토리보드 사용자 편집 잠금: rendering 중 수정·삭제 VD020, archived 수정 VD005. service 호출은 통과.
create or replace function video.guard_storyboard_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if core.is_service_caller() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if old.status = 'rendering' then
    raise exception 'video: storyboard is rendering' using errcode = 'VD020';
  end if;
  if tg_op = 'UPDATE' and old.status = 'archived' then
    raise exception 'video: storyboard is archived' using errcode = 'VD005';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

-- 스토리보드 플랜 한도: features.storyboard, 롱폼 목표 길이 <= storyboard_max_minutes 분(VD009). 모든 호출자에 적용.
create or replace function video.enforce_storyboard_limits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_f jsonb;
begin
  v_f := video.plan_features(new.org_id);
  if not coalesce(case when jsonb_typeof(v_f -> 'storyboard') = 'boolean' then (v_f ->> 'storyboard')::boolean end, false) then
    raise exception 'video: plan does not include storyboards' using errcode = 'VD009';
  end if;
  if new.format = 'longform'
     and new.target_seconds > coalesce((v_f ->> 'storyboard_max_minutes')::integer, 0) * 60 then
    raise exception 'video: longform storyboard over plan limit (% min)', coalesce((v_f ->> 'storyboard_max_minutes')::integer, 0)
      using errcode = 'VD009';
  end if;
  return new;
end;
$$;

-- 컷의 장면 목록 검사: 모두 그 스토리보드 장면, 중복 없음, short 는 ord 가 연속(목록 순서대로 1씩 증가).
create or replace function video.cut_scenes_valid(p_storyboard_id uuid, p_kind text, p_scene_ids uuid[])
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cnt  integer;
  v_ords integer[];
begin
  if coalesce(cardinality(p_scene_ids), 0) = 0
     or (select count(distinct x) from unnest(p_scene_ids) as u(x)) <> cardinality(p_scene_ids) then
    return false;
  end if;
  select count(*), array_agg(s.ord order by u.n) into v_cnt, v_ords
  from unnest(p_scene_ids) with ordinality as u(id, n)
  join video.scenes s on s.id = u.id and s.storyboard_id = p_storyboard_id;
  if v_cnt <> cardinality(p_scene_ids) then
    return false;
  end if;
  if p_kind = 'short' then
    for i in 2 .. v_cnt loop
      if v_ords[i] <> v_ords[1] + i - 1 then
        return false;
      end if;
    end loop;
  end if;
  return true;
end;
$$;

-- 참조 무결성(VD002)과 컷 한도(VD021). 모든 호출자에 적용한다.
create or replace function video.check_storyboard_refs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org  uuid;
  v_kind text;
  v_cnt  integer;
  v_max  integer;
begin
  if tg_table_name = 'storyboards' then
    if new.client_id is not null then
      select org_id into v_org from video.clients where id = new.client_id;
      if v_org is distinct from new.org_id then raise exception 'video: client org mismatch' using errcode = 'VD002'; end if;
    end if;
    if new.script_ai_run_id is not null then
      select org_id into v_org from core.ai_runs where id = new.script_ai_run_id;
      if v_org is distinct from new.org_id then raise exception 'video: script run org mismatch' using errcode = 'VD002'; end if;
    end if;
    if tg_op = 'UPDATE' and new.org_id is distinct from old.org_id then
      raise exception 'video: storyboard org cannot change' using errcode = '22023';
    end if;

  elsif tg_table_name = 'scenes' then
    select org_id into v_org from video.storyboards where id = new.storyboard_id;
    if v_org is distinct from new.org_id then raise exception 'video: storyboard org mismatch' using errcode = 'VD002'; end if;

  elsif tg_table_name = 'scene_assets' then
    select org_id into v_org from video.scenes where id = new.scene_id;
    if v_org is distinct from new.org_id then raise exception 'video: scene org mismatch' using errcode = 'VD002'; end if;
    if new.reused_from_asset_id is not null then
      select org_id, kind into v_org, v_kind from video.scene_assets where id = new.reused_from_asset_id;
      if v_org is distinct from new.org_id then raise exception 'video: reused asset org mismatch' using errcode = 'VD002'; end if;
      if v_kind <> 'image' or new.kind <> 'image' then
        raise exception 'video: only images can be reused' using errcode = '22023';
      end if;
    end if;

  elsif tg_table_name = 'storyboard_cuts' then
    select org_id into v_org from video.storyboards where id = new.storyboard_id;
    if v_org is distinct from new.org_id then raise exception 'video: storyboard org mismatch' using errcode = 'VD002'; end if;
    if tg_op = 'INSERT' or new.scene_ids is distinct from old.scene_ids or new.kind is distinct from old.kind then
      if not video.cut_scenes_valid(new.storyboard_id, new.kind, new.scene_ids) then
        raise exception 'video: cut scenes must be distinct % scenes of the storyboard',
          case when new.kind = 'short' then 'consecutive' else 'existing' end using errcode = '22023';
      end if;
    end if;
    if new.kind = 'short' and (tg_op = 'INSERT' or old.kind is distinct from 'short') then
      v_max := least(10, coalesce((video.plan_features(new.org_id) ->> 'shorts_extract_max')::integer, 0));
      select count(*) into v_cnt from video.storyboard_cuts c
      where c.storyboard_id = new.storyboard_id and c.kind = 'short' and c.id <> new.id;
      if v_cnt >= v_max then
        raise exception 'video: shorts cut limit % reached', v_max using errcode = 'VD021';
      end if;
    end if;

  elsif tg_table_name = 'storyboard_snapshots' then
    select org_id into v_org from video.storyboards where id = new.storyboard_id;
    if v_org is distinct from new.org_id then raise exception 'video: storyboard org mismatch' using errcode = 'VD002'; end if;
    if not exists (select 1 from video.storyboard_cuts c where c.id = new.cut_id and c.storyboard_id = new.storyboard_id) then
      raise exception 'video: cut does not belong to the storyboard' using errcode = 'VD002';
    end if;
  end if;
  return new;
end;
$$;

-- 장면 revision: 내용 컬럼이 바뀔 때만 1 올린다. 부모·조직 이동 금지. 모든 호출자에 적용.
create or replace function video.scenes_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.storyboard_id is distinct from old.storyboard_id or new.org_id is distinct from old.org_id then
    raise exception 'video: scene cannot move to another storyboard' using errcode = '22023';
  end if;
  if (new.chapter, new.kind, new.duration_ms, new.narration, new.on_screen_text, new.visual_prompt,
      new.motion_preset, new.music_cue, new.sources, new.source_required)
     is distinct from
     (old.chapter, old.kind, old.duration_ms, old.narration, old.on_screen_text, old.visual_prompt,
      old.motion_preset, old.music_cue, old.sources, old.source_required) then
    new.revision := old.revision + 1;
  else
    new.revision := old.revision;
  end if;
  return new;
end;
$$;

-- 렌더 스냅샷은 읽기 전용(service 포함).
create or replace function video.storyboard_snapshots_readonly()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'video: storyboard snapshots are read-only' using errcode = '42501';
end;
$$;

-- outputs 참조 무결성: 기존 check_refs 의 outputs 분기에 storyboard_cut_id 를 더한 함수.
--   outputs_check_refs 트리거를 이 함수로 다시 건다(4절 루프가 먼저 만든 트리거를 아래 12.4에서 교체).
create or replace function video.check_output_refs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  select org_id into v_org from (
    select org_id from video.productions                where id = new.production_id
    union all select org_id from video.longform_projects  where id = new.longform_id
    union all select org_id from video.longform_highlights where id = new.highlight_id
    union all select org_id from video.music_tracks       where id = new.music_track_id
    union all select org_id from video.playlists          where id = new.playlist_id
    union all select org_id from video.storyboard_cuts    where id = new.storyboard_cut_id
  ) s limit 1;
  if v_org is distinct from new.org_id then raise exception 'video: output owner org mismatch' using errcode = 'VD002'; end if;
  return new;
end;
$$;

-- 12.4 트리거 연결 ------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['storyboard_templates', 'storyboards', 'scenes', 'scene_assets', 'storyboard_cuts'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on video.%I for each row execute function core.set_updated_at()', t || '_set_updated_at', t);
  end loop;
  -- 사용자 쓰기 정책이 없는 테이블: 이중 잠금(사용자 RPC 는 DEFINER 소유자 권한으로 통과)
  foreach t in array array['storyboard_templates', 'scenes', 'scene_assets', 'storyboard_cuts', 'storyboard_snapshots'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_guard_write', t);
    execute format('create trigger %I before insert or update or delete on video.%I for each row execute function core.guard_privileged_write()', t || '_guard_write', t);
  end loop;
  foreach t in array array['storyboard_templates', 'storyboards', 'scene_assets', 'storyboard_cuts'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_status_transition', t);
    execute format('create trigger %I before update of status on video.%I for each row execute function video.enforce_storyboard_transition()', t || '_status_transition', t);
  end loop;
  foreach t in array array['storyboards', 'scenes', 'scene_assets', 'storyboard_cuts', 'storyboard_snapshots'] loop
    execute format('drop trigger if exists %I on video.%I', t || '_check_refs', t);
    execute format('create trigger %I before insert or update on video.%I for each row execute function video.check_storyboard_refs()', t || '_check_refs', t);
  end loop;
end $$;

drop trigger if exists storyboards_guard_user_edit on video.storyboards;
create trigger storyboards_guard_user_edit before update or delete on video.storyboards
  for each row execute function video.guard_storyboard_edit();

drop trigger if exists storyboards_limits on video.storyboards;
create trigger storyboards_limits before insert or update of format, target_seconds on video.storyboards
  for each row execute function video.enforce_storyboard_limits();

drop trigger if exists scenes_before_update on video.scenes;
create trigger scenes_before_update before update on video.scenes
  for each row execute function video.scenes_before_update();

drop trigger if exists storyboard_snapshots_readonly on video.storyboard_snapshots;
create trigger storyboard_snapshots_readonly before update on video.storyboard_snapshots
  for each row execute function video.storyboard_snapshots_readonly();

drop trigger if exists outputs_check_refs on video.outputs;
create trigger outputs_check_refs before insert or update on video.outputs
  for each row execute function video.check_output_refs();

-- 12.5 RLS 와 GRANT -----------------------------------------------------
alter table video.storyboard_templates enable row level security;
alter table video.storyboards          enable row level security;
alter table video.scenes               enable row level security;
alter table video.scene_assets         enable row level security;
alter table video.storyboard_cuts      enable row level security;
alter table video.storyboard_snapshots enable row level security;

-- SELECT: 같은 조직 멤버 + video 엔타이틀먼트
do $$
declare t text;
begin
  foreach t in array array['storyboards', 'scenes', 'scene_assets', 'storyboard_cuts', 'storyboard_snapshots'] loop
    execute format('grant select on video.%I to authenticated', t);
    execute format('drop policy if exists %I on video.%I', t || '_select', t);
    execute format('create policy %I on video.%I for select to authenticated using (core.is_org_member(org_id) and core.has_entitlement(org_id, ''video''))', t || '_select', t);
  end loop;
end $$;

-- storyboard_templates: 공용 데이터. 플랜에 storyboard 가 있는 조직의 멤버만 읽는다(trend_videos 와 같은 방식).
grant select on video.storyboard_templates to authenticated;
drop policy if exists storyboard_templates_select on video.storyboard_templates;
create policy storyboard_templates_select on video.storyboard_templates for select to authenticated
  using (exists (select 1 from core.current_org_ids() as o(id) where video.org_has_feature(o.id, 'storyboard')));

-- storyboards: 만들기·수정 owner/admin/member(storyboard 기능 필요), 삭제 owner/admin.
--   status, version, revision, script_ai_run_id, root_job_id, last_error 는 GRANT 에서 뺀다(서버·RPC 만).
--   voice_provider·voice_id 는 만들 때만 사용자가 고르고, 이후 변경은 서버만(작업 도중 목소리 대체 금지).
grant insert (org_id, client_id, title, format, aspect, target_seconds, template_code, topic, languages,
              voice_provider, voice_id) on video.storyboards to authenticated;
grant update (client_id, title, topic, languages) on video.storyboards to authenticated;
grant delete on video.storyboards to authenticated;
drop policy if exists storyboards_insert on video.storyboards;
create policy storyboards_insert on video.storyboards for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video')
              and video.org_has_feature(org_id, 'storyboard'));
drop policy if exists storyboards_update on video.storyboards;
create policy storyboards_update on video.storyboards for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'video'));
drop policy if exists storyboards_delete on video.storyboards;
create policy storyboards_delete on video.storyboards for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- 12.6 사용자용 RPC (SECURITY DEFINER, authenticated). 호출자 판정 = is_service_caller + has_org_role ----

-- 내부 공통: 스토리보드 행을 잠그고 편집 가능 여부를 확인한다(역할 42501, 기능 VD009, 렌더 중 VD020, 보관 VD005).
--   p_revision 을 주면 스토리보드 revision 과 같아야 한다(구성 변경 RPC 의 낙관적 동시성, VD409).
create or replace function video.lock_storyboard_for_edit(p_storyboard_id uuid, p_fn text, p_revision integer default null,
                                                          p_check_revision boolean default false)
returns video.storyboards
language plpgsql
security definer
set search_path = ''
as $$
declare v_sb video.storyboards;
begin
  select * into v_sb from video.storyboards where id = p_storyboard_id for update;
  if not found then
    raise exception '%: storyboard not found', p_fn using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_sb.org_id, array['owner', 'admin', 'member']) then
    raise exception '%: not a member', p_fn using errcode = '42501';
  end if;
  if not video.org_has_feature(v_sb.org_id, 'storyboard') then
    raise exception '%: plan does not include storyboards', p_fn using errcode = 'VD009';
  end if;
  if v_sb.status = 'rendering' then
    raise exception '%: storyboard is rendering', p_fn using errcode = 'VD020';
  end if;
  if v_sb.status = 'archived' then
    raise exception '%: storyboard is archived', p_fn using errcode = 'VD005';
  end if;
  if p_check_revision and v_sb.revision is distinct from p_revision then
    raise exception '%: storyboard revision conflict (current %)', p_fn, v_sb.revision using errcode = 'VD409';
  end if;
  return v_sb;
end;
$$;
revoke execute on function video.lock_storyboard_for_edit(uuid, text, integer, boolean) from public, anon, authenticated;

-- 장면 저장(VD-F-132). p_revision 이 현재 값과 다르면 VD409. 허용 키만 바꾼다.
--   내레이션 문구가 바뀌면 그 장면의 ready 내레이션 소재를 superseded 로 돌린다(다시 만들기 필요).
--   rendered 스토리보드를 고치면 ready 로 돌아간다.
create or replace function video.save_scene(p_scene_id uuid, p_revision integer, p_patch jsonb)
returns video.scenes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb_id uuid;
  v_sb    video.storyboards;
  v_old   video.scenes;
  v_row   video.scenes;
begin
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'save_scene: patch must be an object' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_object_keys(p_patch) as k(key)
             where k.key not in ('chapter', 'duration_ms', 'narration', 'on_screen_text', 'visual_prompt',
                                 'motion_preset', 'music_cue', 'sources')) then
    raise exception 'save_scene: unknown key in patch' using errcode = '22023';
  end if;
  select storyboard_id into v_sb_id from video.scenes where id = p_scene_id;
  if v_sb_id is null then
    raise exception 'save_scene: scene not found' using errcode = 'P0002';
  end if;
  v_sb := video.lock_storyboard_for_edit(v_sb_id, 'save_scene');
  select * into v_old from video.scenes where id = p_scene_id for update;
  if v_old.revision is distinct from p_revision then
    raise exception 'save_scene: revision conflict (current %)', v_old.revision using errcode = 'VD409';
  end if;
  update video.scenes s
     set chapter        = case when p_patch ? 'chapter'        then p_patch ->> 'chapter'                  else s.chapter end,
         duration_ms    = case when p_patch ? 'duration_ms'    then (p_patch ->> 'duration_ms')::integer   else s.duration_ms end,
         narration      = case when p_patch ? 'narration'      then p_patch ->> 'narration'                else s.narration end,
         on_screen_text = case when p_patch ? 'on_screen_text' then p_patch ->> 'on_screen_text'           else s.on_screen_text end,
         visual_prompt  = case when p_patch ? 'visual_prompt'  then p_patch ->> 'visual_prompt'            else s.visual_prompt end,
         motion_preset  = case when p_patch ? 'motion_preset'  then p_patch ->> 'motion_preset'            else s.motion_preset end,
         music_cue      = case when p_patch ? 'music_cue'      then p_patch ->> 'music_cue'                else s.music_cue end,
         sources        = case when p_patch ? 'sources'        then p_patch -> 'sources'                   else s.sources end
   where s.id = p_scene_id
  returning * into v_row;
  if v_row.narration is distinct from v_old.narration then
    update video.scene_assets set status = 'superseded'
     where scene_id = p_scene_id and kind = 'narration' and status = 'ready';
  end if;
  if v_sb.status = 'rendered' then
    update video.storyboards set status = 'ready' where id = v_sb.id;
  end if;
  return v_row;
end;
$$;
revoke execute on function video.save_scene(uuid, integer, jsonb) from public, anon;
grant execute on function video.save_scene(uuid, integer, jsonb) to authenticated;

-- 장면 순서 변경. 스토리보드의 장면 id 전부를 새 순서로 받는다. p_revision = 스토리보드 revision(다르면 VD409).
--   스토리보드 revision 을 올려 돌려준다.
create or replace function video.reorder_scenes(p_storyboard_id uuid, p_scene_ids uuid[], p_revision integer)
returns video.storyboards
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb    video.storyboards;
  v_count integer;
begin
  v_sb := video.lock_storyboard_for_edit(p_storyboard_id, 'reorder_scenes', p_revision, true);
  select count(*) into v_count from video.scenes s where s.storyboard_id = p_storyboard_id;
  if v_count = 0 or coalesce(cardinality(p_scene_ids), 0) <> v_count
     or (select count(distinct x) from unnest(p_scene_ids) as u(x)) <> v_count
     or exists (select 1 from unnest(p_scene_ids) as u(x)
                where not exists (select 1 from video.scenes s where s.id = u.x and s.storyboard_id = p_storyboard_id)) then
    raise exception 'reorder_scenes: id list does not match the storyboard scenes' using errcode = '22023';
  end if;
  update video.scenes s
     set ord = o.n::integer
    from unnest(p_scene_ids) with ordinality as o(id, n)
   where s.id = o.id and s.storyboard_id = p_storyboard_id and s.ord <> o.n;
  update video.storyboards
     set revision = revision + 1,
         status   = case when status = 'rendered' then 'ready' else status end
   where id = p_storyboard_id
  returning * into v_sb;
  return v_sb;
end;
$$;
revoke execute on function video.reorder_scenes(uuid, uuid[], integer) from public, anon;
grant execute on function video.reorder_scenes(uuid, uuid[], integer) to authenticated;

-- 장면 추가. p_revision = 스토리보드 revision(VD409). p_ord = 넣을 위치(1부터, null = 끝). 장면 수 상한 VD018.
--   챕터는 바로 앞 장면 값을 이어받는다.
create or replace function video.add_scene(p_storyboard_id uuid, p_revision integer, p_ord integer default null,
                                           p_kind text default 'image', p_duration_ms integer default 6000)
returns video.scenes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb      video.storyboards;
  v_count   integer;
  v_max     integer;
  v_ord     integer;
  v_chapter text;
  v_row     video.scenes;
begin
  v_sb := video.lock_storyboard_for_edit(p_storyboard_id, 'add_scene', p_revision, true);
  select count(*) into v_count from video.scenes where storyboard_id = p_storyboard_id;
  select l.max_scenes into v_max from video.scene_count_limits(v_sb.format, v_sb.target_seconds) as l;
  if v_count >= v_max then
    raise exception 'add_scene: scene limit % reached', v_max using errcode = 'VD018';
  end if;
  v_ord := coalesce(p_ord, v_count + 1);
  if v_ord < 1 or v_ord > v_count + 1 then
    raise exception 'add_scene: position out of range' using errcode = '22023';
  end if;
  select chapter into v_chapter from video.scenes where storyboard_id = p_storyboard_id and ord = v_ord - 1;
  update video.scenes set ord = ord + 1 where storyboard_id = p_storyboard_id and ord >= v_ord;
  insert into video.scenes (org_id, storyboard_id, ord, chapter, kind, duration_ms)
  values (v_sb.org_id, p_storyboard_id, v_ord, v_chapter, coalesce(p_kind, 'image'), coalesce(p_duration_ms, 6000))
  returning * into v_row;
  update video.storyboards
     set revision = revision + 1,
         status   = case when status = 'rendered' then 'ready' else status end
   where id = p_storyboard_id;
  return v_row;
end;
$$;
revoke execute on function video.add_scene(uuid, integer, integer, text, integer) from public, anon;
grant execute on function video.add_scene(uuid, integer, integer, text, integer) to authenticated;

-- 장면 삭제. p_revision = 스토리보드 revision(VD409). p_scene_revision 을 주면 장면 revision 도 맞아야 한다
--   (다른 사람이 막 고친 장면을 지우지 않게, VD409). 뒤 장면 ord 를 당긴다.
--   그 장면을 포함한 렌더 전(proposed/failed) 쇼츠 컷은 함께 지운다. ready 컷은 스냅샷이 있으므로 둔다.
create or replace function video.delete_scene(p_scene_id uuid, p_revision integer, p_scene_revision integer default null)
returns video.storyboards
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb_id uuid;
  v_sb    video.storyboards;
  v_old   video.scenes;
begin
  select storyboard_id into v_sb_id from video.scenes where id = p_scene_id;
  if v_sb_id is null then
    raise exception 'delete_scene: scene not found' using errcode = 'P0002';
  end if;
  v_sb := video.lock_storyboard_for_edit(v_sb_id, 'delete_scene', p_revision, true);
  select * into v_old from video.scenes where id = p_scene_id for update;
  if p_scene_revision is not null and v_old.revision is distinct from p_scene_revision then
    raise exception 'delete_scene: revision conflict (current %)', v_old.revision using errcode = 'VD409';
  end if;
  delete from video.storyboard_cuts c
   where c.storyboard_id = v_sb_id and c.kind = 'short' and c.status in ('proposed', 'failed') and p_scene_id = any (c.scene_ids);
  delete from video.scenes where id = p_scene_id;
  update video.scenes set ord = ord - 1 where storyboard_id = v_sb_id and ord > v_old.ord;
  update video.storyboards
     set revision = revision + 1,
         status   = case when status = 'rendered' then 'ready' else status end
   where id = v_sb_id
  returning * into v_sb;
  return v_sb;
end;
$$;
revoke execute on function video.delete_scene(uuid, integer, integer) from public, anon;
grant execute on function video.delete_scene(uuid, integer, integer) to authenticated;

-- 쇼츠 후보 표시(VD-F-137). 내용 revision 을 올리지 않는다(다른 사람의 문구 편집과 충돌하지 않게).
create or replace function video.set_shorts_candidate(p_scene_id uuid, p_value boolean)
returns video.scenes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb_id uuid;
  v_sb    video.storyboards;
  v_row   video.scenes;
begin
  if p_value is null then
    raise exception 'set_shorts_candidate: value required' using errcode = '22023';
  end if;
  select storyboard_id into v_sb_id from video.scenes where id = p_scene_id;
  if v_sb_id is null then
    raise exception 'set_shorts_candidate: scene not found' using errcode = 'P0002';
  end if;
  v_sb := video.lock_storyboard_for_edit(v_sb_id, 'set_shorts_candidate');
  update video.scenes set shorts_candidate = p_value where id = p_scene_id returning * into v_row;
  return v_row;
end;
$$;
revoke execute on function video.set_shorts_candidate(uuid, boolean) from public, anon;
grant execute on function video.set_shorts_candidate(uuid, boolean) to authenticated;

-- 12.7 service_role 전용 RPC ---------------------------------------------

-- 그래프 video.storyboard 결과 반영(VD-F-131). draft 에서만. 장면 수(VD018)·길이 합계(VD017)를 검사하고
--   기존 장면(소재 포함)과 렌더 전 컷을 지운 뒤 새 장면을 넣는다. 스토리보드 → ready, revision + 1, 감사 storyboard.generate.
--   p_scenes: [{chapter, kind, duration_ms, narration, on_screen_text, visual_prompt, motion_preset, music_cue,
--               shorts_candidate, sources, source_required}] 배열 순서 = ord. duration_ms 가 없으면 템플릿 기본 길이.
create or replace function video.apply_storyboard_result(p_storyboard_id uuid, p_scenes jsonb, p_ai_run_id uuid default null)
returns video.storyboards
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb      video.storyboards;
  v_default integer;
  v_n       integer;
  v_min     integer;
  v_max     integer;
  v_sum     bigint;
begin
  if not core.is_privileged_session() then
    raise exception 'apply_storyboard_result: service_role only' using errcode = '42501';
  end if;
  select * into v_sb from video.storyboards where id = p_storyboard_id for update;
  if not found then
    raise exception 'apply_storyboard_result: storyboard not found' using errcode = 'P0002';
  end if;
  if v_sb.status <> 'draft' then
    raise exception 'apply_storyboard_result: storyboard is %', v_sb.status using errcode = 'VD005';
  end if;
  if p_scenes is null or jsonb_typeof(p_scenes) <> 'array' then
    raise exception 'apply_storyboard_result: scenes must be an array' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_scenes) as e(item) where jsonb_typeof(e.item) <> 'object')
     or exists (select 1 from jsonb_array_elements(p_scenes) as e(item), jsonb_object_keys(e.item) as k(key)
                where k.key not in ('chapter', 'kind', 'duration_ms', 'narration', 'on_screen_text', 'visual_prompt',
                                    'motion_preset', 'music_cue', 'shorts_candidate', 'sources', 'source_required')) then
    raise exception 'apply_storyboard_result: unknown scene key' using errcode = '22023';
  end if;
  select default_scene_seconds * 1000 into v_default from video.storyboard_templates where code = v_sb.template_code;
  v_n := jsonb_array_length(p_scenes);
  select l.min_scenes, l.max_scenes into v_min, v_max from video.scene_count_limits(v_sb.format, v_sb.target_seconds) as l;
  if v_n < v_min or v_n > v_max then
    raise exception 'apply_storyboard_result: % scenes is outside % ~ %', v_n, v_min, v_max using errcode = 'VD018';
  end if;
  select sum(coalesce((e.item ->> 'duration_ms')::integer, v_default)) into v_sum from jsonb_array_elements(p_scenes) as e(item);
  if v_sum < v_sb.target_seconds * 900 or v_sum > v_sb.target_seconds * 1100 then
    raise exception 'apply_storyboard_result: total % ms is outside target % s ±10%%', v_sum, v_sb.target_seconds using errcode = 'VD017';
  end if;
  delete from video.storyboard_cuts where storyboard_id = p_storyboard_id and status in ('proposed', 'failed');
  delete from video.scenes where storyboard_id = p_storyboard_id;
  insert into video.scenes (org_id, storyboard_id, ord, chapter, kind, duration_ms, narration, on_screen_text, visual_prompt,
                            motion_preset, music_cue, shorts_candidate, sources, source_required)
  select v_sb.org_id, p_storyboard_id, e.n::integer, e.item ->> 'chapter', coalesce(e.item ->> 'kind', 'image'),
         coalesce((e.item ->> 'duration_ms')::integer, v_default), e.item ->> 'narration', e.item ->> 'on_screen_text',
         e.item ->> 'visual_prompt', coalesce(e.item ->> 'motion_preset', 'static'), e.item ->> 'music_cue',
         coalesce((e.item ->> 'shorts_candidate')::boolean, false), coalesce(e.item -> 'sources', '[]'::jsonb),
         coalesce((e.item ->> 'source_required')::boolean, false)
  from jsonb_array_elements(p_scenes) with ordinality as e(item, n);
  update video.storyboards
     set status = 'ready', revision = revision + 1, root_job_id = null, last_error = null
   where id = p_storyboard_id
  returning * into v_sb;
  perform core.write_audit(v_sb.org_id, 'storyboard.generate', 'storyboard', p_storyboard_id::text, null, null,
                           jsonb_build_object('scenes', v_n, 'total_ms', v_sum, 'ai_run_id', p_ai_run_id));
  return v_sb;
end;
$$;
revoke execute on function video.apply_storyboard_result(uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function video.apply_storyboard_result(uuid, jsonb, uuid) to service_role;

-- 장면 소재 기록(VD-F-133, 134). 같은 (장면, 종류, 언어, 화면비)의 이전 ready 소재는 superseded.
--   clip 은 권리 근거와 메모가 없으면 VD019. 재사용(p_reused_from_asset_id)은 같은 조직 이미지만,
--   경로·화면비를 비우면 원본 값을 쓴다. image 화면비 기본값은 스토리보드 화면비.
create or replace function video.finish_scene_asset(
  p_scene_id             uuid,
  p_kind                 text,
  p_storage_path         text,
  p_lang                 text    default null,
  p_aspect               text    default null,
  p_ai_generated         boolean default true,
  p_rights_basis         text    default null,
  p_rights_note          text    default null,
  p_reused_from_asset_id uuid    default null,
  p_meta                 jsonb   default '{}'::jsonb
)
returns video.scene_assets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scene  video.scenes;
  v_src    video.scene_assets;
  v_row    video.scene_assets;
  v_aspect text;
begin
  if not core.is_privileged_session() then
    raise exception 'finish_scene_asset: service_role only' using errcode = '42501';
  end if;
  select * into v_scene from video.scenes where id = p_scene_id for update;
  if not found then
    raise exception 'finish_scene_asset: scene not found' using errcode = 'P0002';
  end if;
  if p_kind is null or p_kind not in ('image', 'narration', 'clip') then
    raise exception 'finish_scene_asset: invalid kind %', p_kind using errcode = '22023';
  end if;
  if p_kind = 'clip' and (p_rights_basis is null or coalesce(length(btrim(p_rights_note)), 0) < 2) then
    raise exception 'finish_scene_asset: clip needs rights basis and note' using errcode = 'VD019';
  end if;
  if p_reused_from_asset_id is not null then
    select * into v_src from video.scene_assets where id = p_reused_from_asset_id;
    if not found then
      raise exception 'finish_scene_asset: reused asset not found' using errcode = 'P0002';
    end if;
  end if;
  v_aspect := coalesce(p_aspect, v_src.aspect);
  if p_kind = 'image' and v_aspect is null then
    select b.aspect into v_aspect from video.storyboards b where b.id = v_scene.storyboard_id;
  end if;
  update video.scene_assets set status = 'superseded'
   where scene_id = p_scene_id and kind = p_kind and lang is not distinct from p_lang
     and aspect is not distinct from v_aspect and status = 'ready';
  insert into video.scene_assets (org_id, scene_id, kind, lang, aspect, storage_path, rights_basis, rights_note, ai_generated,
                                  reused_from_asset_id, meta)
  values (v_scene.org_id, p_scene_id, p_kind, p_lang, v_aspect, coalesce(p_storage_path, v_src.storage_path), p_rights_basis, p_rights_note,
          case when p_reused_from_asset_id is not null then v_src.ai_generated else coalesce(p_ai_generated, true) end,
          p_reused_from_asset_id, coalesce(p_meta, '{}'::jsonb))
  returning * into v_row;
  return v_row;
end;
$$;
revoke execute on function video.finish_scene_asset(uuid, text, text, text, text, boolean, text, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function video.finish_scene_asset(uuid, text, text, text, text, boolean, text, text, uuid, jsonb) to service_role;

-- 렌더 스냅샷(VD-F-136, 139). p_cut_id null = 마스터 컷(없으면 만든다, 장면 전체 순서대로).
--   검사: 스토리보드 ready/rendered(VD005), 마스터는 장면 수(VD018)·길이 합계 ±10%(VD017),
--         쇼츠 컷은 연속 장면(22023)·90초 이하(VD017), clip 장면은 권리 근거 있는 ready clip(VD019),
--         image 장면은 ready image(22023).
--   결과: 스냅샷 1행(version = 스토리보드 version + 1), 컷 → rendering, 마스터면 스토리보드 → rendering.
--   렌더가 끝나면 워커가 service_role 로 컷 ready/failed, 스토리보드 rendered/ready, outputs(storyboard_cut_id) 를 쓴다.
create or replace function video.snapshot_storyboard(p_storyboard_id uuid, p_cut_id uuid default null)
returns video.storyboard_snapshots
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sb      video.storyboards;
  v_cut     video.storyboard_cuts;
  v_ids     uuid[];
  v_min     integer;
  v_max     integer;
  v_sum     bigint;
  v_bad     integer;
  v_version integer;
  v_snap    jsonb;
  v_row     video.storyboard_snapshots;
begin
  if not core.is_privileged_session() then
    raise exception 'snapshot_storyboard: service_role only' using errcode = '42501';
  end if;
  select * into v_sb from video.storyboards where id = p_storyboard_id for update;
  if not found then
    raise exception 'snapshot_storyboard: storyboard not found' using errcode = 'P0002';
  end if;
  if v_sb.status not in ('ready', 'rendered') then
    raise exception 'snapshot_storyboard: storyboard is %', v_sb.status using errcode = 'VD005';
  end if;
  if p_cut_id is not null then
    select * into v_cut from video.storyboard_cuts where id = p_cut_id and storyboard_id = p_storyboard_id for update;
    if not found then
      raise exception 'snapshot_storyboard: cut not found' using errcode = 'P0002';
    end if;
  else
    select * into v_cut from video.storyboard_cuts where storyboard_id = p_storyboard_id and kind = 'master' for update;
  end if;

  if v_cut.id is null or v_cut.kind = 'master' then
    select array_agg(s.id order by s.ord), sum(s.duration_ms) into v_ids, v_sum from video.scenes s where s.storyboard_id = p_storyboard_id;
    select l.min_scenes, l.max_scenes into v_min, v_max from video.scene_count_limits(v_sb.format, v_sb.target_seconds) as l;
    if coalesce(cardinality(v_ids), 0) < v_min or coalesce(cardinality(v_ids), 0) > v_max then
      raise exception 'snapshot_storyboard: % scenes is outside % ~ %', coalesce(cardinality(v_ids), 0), v_min, v_max using errcode = 'VD018';
    end if;
    if v_sum < v_sb.target_seconds * 900 or v_sum > v_sb.target_seconds * 1100 then
      raise exception 'snapshot_storyboard: total % ms is outside target % s ±10%%', v_sum, v_sb.target_seconds using errcode = 'VD017';
    end if;
    if v_cut.id is null then
      insert into video.storyboard_cuts (org_id, storyboard_id, kind, aspect, scene_ids, status, ord)
      values (v_sb.org_id, p_storyboard_id, 'master', v_sb.aspect, v_ids, 'rendering', 0)
      returning * into v_cut;
    else
      update video.storyboard_cuts set scene_ids = v_ids, status = 'rendering', last_error = null where id = v_cut.id returning * into v_cut;
    end if;
  else
    if not video.cut_scenes_valid(p_storyboard_id, 'short', v_cut.scene_ids) then
      raise exception 'snapshot_storyboard: short cut scenes are no longer consecutive' using errcode = '22023';
    end if;
    select sum(s.duration_ms) into v_sum from video.scenes s where s.id = any (v_cut.scene_ids);
    if v_sum > 90000 then
      raise exception 'snapshot_storyboard: short cut % ms is over 90 s', v_sum using errcode = 'VD017';
    end if;
    update video.storyboard_cuts set status = 'rendering', last_error = null where id = v_cut.id returning * into v_cut;
  end if;

  select count(*) into v_bad from video.scenes s
  where s.id = any (v_cut.scene_ids) and s.kind = 'clip'
    and not exists (select 1 from video.scene_assets a where a.scene_id = s.id and a.kind = 'clip' and a.status = 'ready'
                    and a.rights_basis is not null and a.rights_note is not null);
  if v_bad > 0 then
    raise exception 'snapshot_storyboard: % clip scenes without rights basis', v_bad using errcode = 'VD019';
  end if;
  -- image: 마스터는 스토리보드 화면비 이미지가 있어야 한다. 쇼츠 컷은 9:16 이 없으면 다른 화면비를 크롭한다(D-32).
  select count(*) into v_bad from video.scenes s
  where s.id = any (v_cut.scene_ids) and s.kind = 'image'
    and not exists (select 1 from video.scene_assets a where a.scene_id = s.id and a.kind = 'image' and a.status = 'ready'
                    and (v_cut.kind = 'short' or a.aspect = v_sb.aspect));
  if v_bad > 0 then
    raise exception 'snapshot_storyboard: % image scenes without a ready image', v_bad using errcode = '22023';
  end if;

  v_version := v_sb.version + 1;
  v_snap := jsonb_build_object(
    'storyboard', jsonb_build_object('id', v_sb.id, 'title', v_sb.title, 'format', v_sb.format, 'aspect', v_sb.aspect,
                                     'target_seconds', v_sb.target_seconds, 'template_code', v_sb.template_code,
                                     'topic', v_sb.topic, 'languages', to_jsonb(v_sb.languages), 'revision', v_sb.revision,
                                     'voice_provider', v_sb.voice_provider, 'voice_id', v_sb.voice_id),
    'cut', jsonb_build_object('id', v_cut.id, 'kind', v_cut.kind, 'aspect', v_cut.aspect, 'hook_text', v_cut.hook_text),
    'scenes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'ord', s.ord, 'chapter', s.chapter, 'kind', s.kind, 'duration_ms', s.duration_ms,
               'narration', s.narration, 'on_screen_text', s.on_screen_text, 'visual_prompt', s.visual_prompt,
               'motion_preset', s.motion_preset, 'music_cue', s.music_cue, 'sources', s.sources,
               'source_required', s.source_required, 'revision', s.revision,
               'assets', coalesce((select jsonb_object_agg(a.kind || coalesce(':' || a.lang, '') || coalesce(':' || a.aspect, ''),
                                          jsonb_build_object('id', a.id, 'path', a.storage_path, 'ai_generated', a.ai_generated,
                                                             'aspect', a.aspect, 'rights_basis', a.rights_basis))
                                   from video.scene_assets a where a.scene_id = s.id and a.status = 'ready'), '{}'::jsonb))
             order by u.n)
      from unnest(v_cut.scene_ids) with ordinality as u(id, n)
      join video.scenes s on s.id = u.id), '[]'::jsonb));
  insert into video.storyboard_snapshots (org_id, storyboard_id, cut_id, version, snapshot)
  values (v_sb.org_id, p_storyboard_id, v_cut.id, v_version, v_snap)
  returning * into v_row;
  update video.storyboards
     set version = v_version,
         status  = case when v_cut.kind = 'master' then 'rendering' else status end
   where id = p_storyboard_id;
  perform core.write_audit(v_sb.org_id, 'storyboard.snapshot', 'storyboard', p_storyboard_id::text, null, null,
                           jsonb_build_object('version', v_version, 'cut_id', v_cut.id, 'cut_kind', v_cut.kind));
  return v_row;
end;
$$;
revoke execute on function video.snapshot_storyboard(uuid, uuid) from public, anon, authenticated;
grant execute on function video.snapshot_storyboard(uuid, uuid) to service_role;

-- 12.8 함수 EXECUTE 정리(10절과 같은 규칙). 이 절에서 만든 함수의 PUBLIC EXECUTE 를 회수하고 역할별 GRANT 만 남긴다.
--   트리거·CHECK 헬퍼(scene_count_limits, valid_scene_sources, cut_scenes_valid 등)는 사용자 EXECUTE 가 필요 없다.
revoke execute on all functions in schema video from public;
grant execute on function video.save_scene(uuid, integer, jsonb) to authenticated;
grant execute on function video.reorder_scenes(uuid, uuid[], integer) to authenticated;
grant execute on function video.add_scene(uuid, integer, integer, text, integer) to authenticated;
grant execute on function video.delete_scene(uuid, integer, integer) to authenticated;
grant execute on function video.set_shorts_candidate(uuid, boolean) to authenticated;
grant execute on all functions in schema video to service_role;

-- 12.9 데이터: 템플릿 5종(VD-F-141, 제안 값)과 플랜 키 -----------------------
--   beats.share 는 목표 길이 비율(합 1.0). kind 는 그래프가 쓸 장면 종류 기본값. 문구는 운영자가 이 조각에서만 바꾼다.
insert into video.storyboard_templates (code, label, beats, default_scene_seconds, status) values
  ('knowledge_explainer', '지식 해설',
   '[{"key":"hook","label":"질문 던지기","share":0.08,"kind":"title"},
     {"key":"context","label":"배경","share":0.17,"kind":"image"},
     {"key":"explain","label":"핵심 설명","share":0.45,"kind":"image"},
     {"key":"example","label":"예시·숫자","share":0.15,"kind":"text_card"},
     {"key":"recap","label":"정리","share":0.15,"kind":"text_card"}]', 6, 'active'),
  ('history_documentary', '역사 다큐',
   '[{"key":"cold_open","label":"장면으로 시작","share":0.08,"kind":"image"},
     {"key":"title","label":"제목·시대","share":0.04,"kind":"title"},
     {"key":"background","label":"시대 배경","share":0.18,"kind":"image"},
     {"key":"events","label":"사건 전개","share":0.40,"kind":"image"},
     {"key":"turning_point","label":"전환점","share":0.15,"kind":"image"},
     {"key":"legacy","label":"남긴 것·출처","share":0.15,"kind":"text_card"}]', 7, 'active'),
  ('list_topn', 'TOP N 리스트',
   '[{"key":"hook","label":"목록 예고","share":0.08,"kind":"title"},
     {"key":"items","label":"순위 항목","share":0.80,"kind":"image"},
     {"key":"outro","label":"정리","share":0.12,"kind":"text_card"}]', 5, 'active'),
  ('story_radio', '사연 라디오',
   '[{"key":"intro","label":"사연 소개","share":0.10,"kind":"title"},
     {"key":"story","label":"사연","share":0.60,"kind":"image"},
     {"key":"reflection","label":"생각 나누기","share":0.20,"kind":"text_card"},
     {"key":"outro","label":"마무리","share":0.10,"kind":"text_card"}]', 8, 'active'),
  ('product_review', '제품 리뷰',
   '[{"key":"hook","label":"한 줄 결론","share":0.08,"kind":"title"},
     {"key":"overview","label":"제품 소개","share":0.17,"kind":"image"},
     {"key":"points","label":"장점·단점","share":0.45,"kind":"image"},
     {"key":"compare","label":"비교·숫자","share":0.15,"kind":"text_card"},
     {"key":"verdict","label":"추천 대상","share":0.15,"kind":"text_card"}]', 5, 'active')
on conflict (code) do update
  set label = excluded.label, beats = excluded.beats, default_scene_seconds = excluded.default_scene_seconds;

-- 플랜 키(있으면 병합). storyboard(bool), storyboard_max_minutes, shorts_extract_max 는 제안 값(01장 10.4절).
--   seed.sql 이 이 조각보다 나중에 실행되면 덮어써지므로 모듈러 seed.sql 반영을 코어에 요청한다(11.2절 R-V1 과 같은 경로).
update core.plans
   set features = features || '{"storyboard": false, "storyboard_max_minutes": 0, "shorts_extract_max": 0}'::jsonb
 where app_id = 'video' and code = 'starter';
update core.plans
   set features = features || '{"storyboard": true, "storyboard_max_minutes": 10, "shorts_extract_max": 3}'::jsonb
 where app_id = 'video' and code = 'basic';
update core.plans
   set features = features || '{"storyboard": true, "storyboard_max_minutes": 30, "shorts_extract_max": 10}'::jsonb
 where app_id = 'video' and code = 'pro';
update core.plans
   set features = features || '{"storyboard": true, "storyboard_max_minutes": 60, "shorts_extract_max": 10}'::jsonb
 where app_id = 'video' and code = 'advanced';
