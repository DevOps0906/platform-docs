-- =====================================================================
-- seed.sql (모놀리스 study-note)
-- 앱 레지스트리 1행(가입 트리거가 apps 가 1개면 자동 부트스트랩), 기본 플랜, Phase 2 플랜/크레딧팩(비활성).
-- model_catalog 와 runtime_config 는 0002_study_note_domain.sql 말미에 있다(설정 데이터이므로 마이그레이션과 함께 간다).
-- 금액과 크레딧은 제안값이다. 정본은 01_PRD.md 4장. 반복 실행 가능(upsert).
-- AI·음성 키(ai_*, lecture_*, voice_chat, quiz_voice)와 기능별 AI 라우팅 기본값, org-files 버킷은 2026-10-13 추가(01_PRD.md 4.2·4.6절, 02_ARCHITECTURE.md 5.3절).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('notes', 'Study Note', 'public', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- 기본(무료) 플랜: 월 30 크레딧, 이월 없음, 가입 크레딧 없음 (모듈러 seed.sql 의 notes 행과 동일)
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('notes', 'free', 'Free', 0, 'month', 30, 0, false,
   '{"max_input_chars": 5000, "allowed_tiers": ["lite", "standard"], "history_max_entries": 50, "history_max_bytes": 5000000, "ai_chat": true, "ai_chat_turns_per_day": 30, "ai_subjects_max": 5, "ai_docs_max": 20, "ai_doc_max_chars": 20000, "lecture_note": true, "lecture_max_minutes": 20, "voice_chat": true, "quiz_voice": true}', true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- Phase 2: 베타 동안 비활성
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('notes', 'pro', 'Pro', 4900, 'month', 300, 0, false,
   '{"max_input_chars": 10000, "allowed_tiers": ["lite", "standard", "premium"], "history_max_entries": 500, "history_max_bytes": 50000000, "ai_chat": true, "ai_chat_turns_per_day": 200, "ai_subjects_max": 30, "ai_docs_max": 300, "ai_doc_max_chars": 100000, "lecture_note": true, "lecture_max_minutes": 120, "voice_chat": true, "quiz_voice": true}', false, false, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, monthly_credits = excluded.monthly_credits,
      features = excluded.features, is_active = excluded.is_active, sort_order = excluded.sort_order;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('notes', 'pack_100', '100 크레딧', 100, 2900, false, 1),
  ('notes', 'pack_300', '300 크레딧', 300, 7900, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 2100_notes.sql 14절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
--   lecture_note 는 강의자 같은 제3자 목소리가 담기므로 오픈소스 강제(상용 허용 여부는 01_PRD.md D-13).
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'notes', 'notes.organize', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"google","model":"*"}]', false),
  (null, 'notes', 'notes.quiz',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"google","model":"*"}]', false),
  (null, 'notes', 'chat',           'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"}]', false),
  (null, 'notes', 'wiki.query',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'notes', 'wiki.ingest',    'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'notes', 'wiki.lint',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'notes', 'dify.aux',       'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'notes', 'notes.knowledge','embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'notes', 'lecture_note',   'stt',       'open_source', '[{"provider":"oss-voice","model":"*"}]', true),
  (null, 'notes', 'voice_chat',     'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'notes', 'voice_chat',     'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'notes', 'quiz_voice',     'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'notes', 'quiz_voice',     'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 체인 검사: 존재하지 않거나 종류가 다른 제공자, 오픈소스 모드의 상용 제공자가 있으면 실패한다.
do $$
declare v_bad text;
begin
  select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
  from public.ai_routing_settings s
  cross join lateral jsonb_array_elements(s.chain) as e(item)
  left join public.ai_providers p on p.id = e.item ->> 'provider'
  where s.org_id is null and s.app_id = 'notes'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'notes routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;

-- 교재·노트 업로드용 비공개 버킷. 모듈러는 0005 가 만들지만 모놀리스 코어 축소판은 SECTION 8(Storage)을 제거했으므로 여기서 만든다.
-- 쓰기·읽기는 서버(service_role, 서명 업로드 URL)만 하고 사용자용 storage 정책은 두지 않는다(기본 거부). 경로 = <org_id>/notes/<...>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('org-files', 'org-files', false, 52428800, null)
on conflict (id) do nothing;
