-- =====================================================================
-- seed.sql (모놀리스, flora-publishing)
-- 정본: docs/products/flora-publishing/01_PRD.md 4장(요금과 크레딧). 확정 결정 8번 "크레딧팩 + 저가 구독".
-- 금액과 크레딧 수치는 "제안"이다(01_PRD.md 4장 근거 참조). 모듈러 seed(_supabase-modular/seed.sql:33, :95, :100-101)와
-- 금액/크레딧은 같고, features 키는 이 파일이 더 많다(서버는 키가 없으면 Free 값으로 해석한다).
-- 반복 실행 가능(upsert).
-- =====================================================================

-- 앱 1행. 모놀리스 가입 트리거는 apps 가 정확히 1행이면 signup_app 메타데이터 없이도 이 앱으로 부트스트랩한다.
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('publishing', 'FLORA Publishing', 'public', 'open', 'active')
on conflict (id) do update
  set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

-- 플랜: Free(기본) + Basic(저가 구독). -1 = 무제한.
insert into public.plans (app_id, code, name, description, price_krw, billing_interval, monthly_credits, signup_credits,
                          carry_over, features, is_default, is_active, sort_order) values
  ('publishing', 'free', 'Free', '작은 책 한 권을 체험하는 무료 플랜', 0, 'month', 20, 0, false,
   '{"watermark": true, "exports_per_month": 2, "themes": ["basic"],
     "max_books": 3, "max_chapters": 3, "max_sections": 6, "max_paragraphs": 3, "personas": 40,
     "write_all": false, "upload": false, "tone_slider": false, "writing_assist": false,
     "quality_mode": false, "persona_blend": false, "webhooks": false, "public_page": false,
     "ai_chat": true, "ai_chat_turns_per_day": 50, "book_wiki": true, "rag_files_max": 3, "voice_dictation": true, "narration": false}'::jsonb,
   true, true, 0),
  ('publishing', 'basic', 'Basic', '워터마크 없이 책을 계속 만드는 월 구독', 9900, 'month', 200, 0, false,
   '{"watermark": false, "exports_per_month": -1, "themes": ["basic", "pro"],
     "max_books": -1, "max_chapters": 20, "max_sections": 200, "max_paragraphs": 5, "personas": 60,
     "write_all": true, "upload": true, "tone_slider": true, "writing_assist": true,
     "quality_mode": true, "persona_blend": true, "webhooks": true, "public_page": true,
     "ai_chat": true, "ai_chat_turns_per_day": 300, "book_wiki": true, "rag_files_max": 20, "voice_dictation": true, "narration": true}'::jsonb,
   false, true, 1)
on conflict (app_id, code) do update
  set name = excluded.name, description = excluded.description, price_krw = excluded.price_krw,
      billing_interval = excluded.billing_interval, monthly_credits = excluded.monthly_credits,
      signup_credits = excluded.signup_credits, carry_over = excluded.carry_over, features = excluded.features,
      is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 크레딧팩(일회 결제, pack 버킷, 소멸 없음 - 01_PRD.md 4장)
insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('publishing', 'pack_100', '100 크레딧', 100, 9900,  true, 1),
  ('publishing', 'pack_500', '500 크레딧', 500, 39900, true, 2)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw,
      is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 제품 seed 없음: 페르소나 60종, 판형 프리셋 6종, 시드 원고 3종은 코드 안 JSON 단일 소스다(02_ARCHITECTURE.md 2장).

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 1000_publishing.sql 15절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
--   narration 의 "작업 도중 다른 제공자로 대체 금지"는 음성 어댑터(packages/core-voice)가 강제한다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'publishing', 'publishing.draft',     'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'publishing', 'publishing.assist',    'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'publishing', 'chat',                 'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'publishing', 'wiki.query',           'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'publishing', 'wiki.ingest',          'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'publishing', 'wiki.lint',            'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'publishing', 'dify.aux',             'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'publishing', 'publishing.knowledge', 'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'publishing', 'publishing.dictation', 'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'publishing', 'voice_chat',           'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'publishing', 'voice_chat',           'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'publishing', 'narration',            'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
  where s.org_id is null and s.app_id = 'publishing'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'publishing routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
