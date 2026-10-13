-- =====================================================================
-- seed.sql (toon-factory 모놀리스)
-- apps 1행, 플랜 2개(free 기본, pro), 크레딧팩 2개, 카탈로그 샘플 팩 1개(draft).
-- 금액·크레딧·features 정본: docs/products/toon-factory/01_PRD.md 4절. AI·음성 키(ai_chat, ai_chat_turns_per_day, voice_chat,
--   dialogue_voice, video_voice)와 기능별 AI 라우팅 기본값은 2026-10-13 추가(01_PRD.md 4.2·4.6절, 02_ARCHITECTURE.md 5절).
--   free/pro 의 가격과 월 크레딧은 모듈러 seed(_supabase-modular/seed.sql:43, :108-111)와 같다.
--   features 키는 01_PRD 4절에서 확장했다(모듈러 seed 갱신은 06_AGENT_PLAN.md 6절 요청 항목).
--   크레딧팩은 제안(01_PRD 4절).
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('toon', 'Toon Factory', 'public', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('toon', 'free', 'Free', 0, 'month', 10, 0, false,
   '{"watermark": true, "export": ["png"], "exports_per_month": 20, "max_series": 1, "max_episodes_per_series": 3, "max_cuts_per_episode": 10, "asset_tiers": ["free"], "commercial_use": false, "mp4_max_seconds": 0, "user_asset_storage_mb": 100, "ai_chat": true, "ai_chat_turns_per_day": 20, "voice_chat": true, "dialogue_voice": true, "video_voice": false}',
   true, true, 0),
  ('toon', 'pro', 'Pro', 14900, 'month', 300, 0, false,
   '{"watermark": false, "export": ["png", "zip", "webtoon_strip", "mp4"], "exports_per_month": -1, "max_series": 20, "max_episodes_per_series": -1, "max_cuts_per_episode": 60, "asset_tiers": ["free", "premium"], "commercial_use": true, "mp4_max_seconds": 60, "user_asset_storage_mb": 2048, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "dialogue_voice": true, "video_voice": true}',
   false, true, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('toon', 'pack_100', '100 크레딧', 100, 5900,  true, 1),
  ('toon', 'pack_300', '300 크레딧', 300, 15900, true, 2)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 카탈로그 샘플 팩(draft). 라이선스 검증(license_verified_at/by) 전에는 published 로 바꿀 수 없다(CHECK).
-- 실제 에셋 행은 운영자 일괄 등록 도구(TN-06-008)가 Storage 업로드와 함께 넣는다.
insert into public.asset_packs (code, name, description, style_preset, tier, license_source, license_ref, commercial_use_allowed, status, sort_order)
values ('starter_daily', '일상 스타터 팩', 'MVP 캐릭터 2종 x 포즈 15 x 표정 6, 배경 20, 말풍선 10, 효과 글자 10 (01_PRD 3절 TN-F-010)',
        'flat_line', 'free', 'commissioned', 'CONTRACT-PENDING', true, 'draft', 0)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 2000_toon.sql 10절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
--   video_voice 의 "작업 도중 다른 제공자로 대체 금지"는 음성 어댑터(packages/core-voice)가 강제한다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'toon', 'toon.storyboard',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'toon', 'toon.consistency', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'toon.dialogue',    'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'toon', 'toon.prompt_en',   'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'chat',             'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'toon', 'wiki.query',       'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'wiki.ingest',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'wiki.lint',        'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'toon', 'dify.aux',         'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'toon', 'toon.knowledge',   'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'toon', 'voice_chat',       'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'toon', 'voice_chat',       'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'toon', 'dialogue_voice',   'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'toon', 'video_voice',      'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
  where s.org_id is null and s.app_id = 'toon'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'toon routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
