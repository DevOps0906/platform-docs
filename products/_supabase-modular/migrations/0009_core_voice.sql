-- =====================================================================
-- 0009_core_voice.sql
-- 음성 서비스 공용 테이블(확정 결정 16). 설계: _platform-core/VOICE_ARCHITECTURE.md
--   - 음성 제공자 이원화: 상용(ElevenLabs, TypeScript 어댑터) / 오픈소스(공용 GPU 음성 서버)
--     제공자 목록·단가·라우팅은 0008의 ai_providers, ai_model_prices, ai_routing_settings(kind stt/tts)를 쓴다.
--   - voice_sessions: 음성 대화 세션(채팅 대화와 연결)
--   - voice_jobs: STT/TTS 작업 단위 기록, 크레딧 연결, 녹음 보관 여부·동의·만료
--     (강의 녹음처럼 제3자 음성이 담기면 consent_kind='third_party_notice': 녹음 당사자 고지 확인)
--   - voice-audio 버킷: 비공개, "폴더 = org_id". 녹음은 기본 저장하지 않고, 저장하는 기능만 만료 시각을 둔다.
-- 원칙: 0008과 같다(쓰기 service_role, SELECT 정책, PUBLIC EXECUTE 회수).
-- 선행: 0000 ~ 0008
-- =====================================================================

create table if not exists core.voice_sessions (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  app_id           text not null references core.apps(id),
  user_id          uuid,                                   -- 비로그인 방문자 상담이면 null
  conversation_id  uuid,
  visitor_key      text,                                   -- 비로그인 방문자(ai_conversations.visitor_key와 같은 값)
  stt_provider_id  text references core.ai_providers(id),
  tts_provider_id  text references core.ai_providers(id),
  total_seconds    numeric(10, 2) not null default 0 constraint voice_sessions_seconds_check check (total_seconds >= 0),
  status           text not null default 'active' constraint voice_sessions_status_check check (status in ('active', 'ended')),
  started_at       timestamptz not null default now(),
  ended_at         timestamptz,
  updated_at       timestamptz not null default now(),
  unique (id, org_id),
  constraint voice_sessions_owner_check check (user_id is not null or visitor_key is not null),
  foreign key (conversation_id, org_id) references core.ai_conversations(id, org_id) on delete set null (conversation_id)
);
create index if not exists voice_sessions_user_idx on core.voice_sessions (org_id, user_id, started_at desc);

create table if not exists core.voice_jobs (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  app_id            text not null references core.apps(id),
  user_id           uuid,
  session_id        uuid,
  feature           text not null default 'voice_chat',     -- 예: voice_chat, dictation, lecture_note, narration
  kind              text not null constraint voice_jobs_kind_check check (kind in ('stt', 'tts')),
  provider_id       text not null references core.ai_providers(id),
  model             text,
  voice_id          text,                                   -- TTS 보이스(상용 보이스 id 또는 오픈소스 화자 키)
  status            text not null default 'queued'
                    constraint voice_jobs_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'expired')),
  duration_seconds  numeric(10, 2) constraint voice_jobs_duration_check check (duration_seconds is null or duration_seconds >= 0),
  characters        integer constraint voice_jobs_chars_check check (characters is null or characters >= 0),
  store_audio       boolean not null default false,
  consent_at        timestamptz,                            -- 녹음 저장 동의 시각(저장하는 기능은 필수)
  consent_kind      text constraint voice_jobs_consent_kind_check check (consent_kind is null or consent_kind in ('self', 'third_party_notice')),
  notice_version    text,                                   -- 동의한 고지문 버전
  storage_path      text,
  expires_at        timestamptz,
  fallback_from     text,                                   -- 대체 실행이면 원래 제공자
  credits           integer not null default 0,
  credit_ledger_id  bigint references core.credit_ledger(id),
  error             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint voice_jobs_store_check check (not store_audio or (storage_path is not null and expires_at is not null)),
  constraint voice_jobs_no_store_check check (store_audio or storage_path is null),
  constraint voice_jobs_consent_check check (not store_audio or (consent_at is not null and consent_kind is not null)),
  foreign key (session_id, org_id) references core.voice_sessions(id, org_id) on delete set null (session_id)
);
create index if not exists voice_jobs_org_idx on core.voice_jobs (org_id, app_id, created_at desc);
create index if not exists voice_jobs_expiry_idx on core.voice_jobs (expires_at) where store_audio and status <> 'expired';

do $$
declare t text;
begin
  foreach t in array array['voice_sessions', 'voice_jobs'] loop
    execute format('drop trigger if exists %1$s_set_updated_at on core.%1$s', t);
    execute format('create trigger %1$s_set_updated_at before update on core.%1$s for each row execute function core.set_updated_at()', t);
    execute format('drop trigger if exists %1$s_guard_write on core.%1$s', t);
    execute format('create trigger %1$s_guard_write before insert or update or delete on core.%1$s for each row execute function core.guard_privileged_write()', t);
    execute format('alter table core.%s enable row level security', t);
  end loop;
end $$;

grant select on core.voice_sessions, core.voice_jobs to authenticated;
drop policy if exists voice_sessions_select on core.voice_sessions;
create policy voice_sessions_select on core.voice_sessions for select to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id));
drop policy if exists voice_jobs_select on core.voice_jobs;
create policy voice_jobs_select on core.voice_jobs for select to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id));

-- 녹음 보관 버킷: 비공개, 50MB, 오디오만. 경로 = <org_id>/<voice_job_id>.<ext>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice-audio', 'voice-audio', false, 52428800,
        array['audio/webm', 'audio/ogg', 'audio/mpeg', 'audio/wav', 'audio/mp4'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 읽기: 그 녹음의 작업 주인(본인)만. 쓰기·삭제: service_role만(정책 없음)
drop policy if exists voice_audio_select on storage.objects;
create policy voice_audio_select on storage.objects for select to authenticated
  using (bucket_id = 'voice-audio'
         and exists (select 1 from core.voice_jobs j
                     where j.storage_path = name and j.user_id = auth.uid() and core.is_org_member(j.org_id)));

-- 만료 녹음 정리(service_role / pg_cron): 만료된 작업을 expired로 바꾸고 지울 Storage 경로를 돌려준다.
-- 실제 객체 삭제는 서버가 Storage API로 한다(storage.objects 직접 삭제 금지).
create or replace function core.expire_voice_audio(p_limit integer default 500)
returns table (job_id uuid, storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'expire_voice_audio: service_role only' using errcode = '42501';
  end if;
  return query
    with due as (
      select j.id
      from core.voice_jobs j
      where j.store_audio and j.status <> 'expired' and j.expires_at <= now()
      order by j.expires_at
      limit greatest(1, least(coalesce(p_limit, 500), 5000))
      for update skip locked
    )
    update core.voice_jobs v
       set status = 'expired', error = coalesce(v.error, 'audio expired')
      from due
     where v.id = due.id
    returning v.id, v.storage_path;
end;
$$;

revoke execute on function core.expire_voice_audio(integer) from public, anon, authenticated;
grant execute on function core.expire_voice_audio(integer) to service_role;
