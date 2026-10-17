-- =====================================================================
-- seed.sql (sceneflow 모놀리스)
-- apps 1행, 플랜 4개(PRD_pricing.md 정본, 확정 결정 8), 크레딧팩 4개 + Advanced 20% 할인팩 4개(2026-10-14 30% → 20%), video 배치 대가성 문구 기본값.
-- 정본: NOMAD Shorts Maker/PRD_pricing.md:116-155. Track F 는 확정 결정 7 로 추가(모듈러 seed.sql:211-212 와 같게 Pro 이상).
-- features 키 해석은 docs/products/sceneflow/01_PRD.md 4장(AI 키 4개 ai_chat, ai_chat_turns_per_day, voice_chat, ai_script 는 2026-10-13 추가). 반복 실행 가능(upsert).
-- AI 라우팅 기본값 17행과 체인 검사는 파일 끝.
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('video', 'SceneFlow', 'video', 'open', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('video', 'starter',  'Starter',  0,      'none',  0,    100, false,
   '{"tracks": ["A"], "languages": ["KO"], "max_channels": 1, "watermark": true, "platforms": ["youtube"], "radar": false, "compliance": false, "team_members": 1, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "ai_script": false}',
   true, true, 0),
  ('video', 'basic',    'Basic',    49000,  'month', 1200, 0, false,
   '{"tracks": ["A","B","C"], "languages": ["KO"], "max_channels": 5, "watermark": false, "platforms": ["youtube"], "radar": ["playboard"], "compliance": true, "silence_cut": true, "coupang_landing": true, "team_members": 1, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "ai_script": true}',
   false, true, 1),
  ('video', 'pro',      'Pro',      99000,  'month', 3000, 0, false,
   '{"tracks": ["A","B","C","D","E","F"], "languages": ["KO","JA","EN"], "max_channels": 15, "watermark": false, "platforms": ["youtube","instagram","tiktok","threads","naver_clip"], "brandconnect_clip": true, "radar": ["playboard","channel_finder","bling"], "compliance": true, "silence_cut": true, "layer_composite": true, "coupang_landing": true, "suno": true, "osmu": true, "bling_monthly_limit": 20, "team_members": 1, "priority_render": true, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "ai_script": true}',
   false, true, 2),
  ('video', 'advanced', 'Advanced', 149000, 'month', 5000, 0, false,
   '{"tracks": ["A","B","C","D","E","F"], "languages": ["KO","JA","EN"], "max_channels": 40, "watermark": false, "platforms": ["youtube","instagram","tiktok","threads","naver_clip"], "brandconnect_clip": true, "radar": ["playboard","channel_finder","bling"], "compliance": true, "silence_cut": true, "layer_composite": true, "coupang_landing": true, "suno": true, "osmu": true, "react_flow_full": true, "bling_monthly_limit": 100, "team_members": 5, "api_access": true, "agency": true, "priority_render": true, "credit_discount_pct": 20, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "ai_script": true}',
   false, true, 3)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 크레딧팩: 정가 4종(PRD_pricing.md:149-154). adv_* 4종은 Advanced 20% 할인가(2026-10-14, Price_Plans/sceneflow/PRICE_PLAN.md 10장). 서버(createOrder)가 Advanced 조직에만 adv_* 를 허용한다.
insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('video', 'pack_500',      '500 크레딧',              500,  15000,  true, 1),
  ('video', 'pack_1000',     '1,000 크레딧',            1000, 28000,  true, 2),
  ('video', 'pack_3000',     '3,000 크레딧',            3000, 75000,  true, 3),
  ('video', 'pack_5000',     '5,000 크레딧',            5000, 110000, true, 4),
  ('video', 'adv_pack_500',  '500 크레딧 (Advanced)',   500,  12000,  true, 11),
  ('video', 'adv_pack_1000', '1,000 크레딧 (Advanced)', 1000, 22400,  true, 12),
  ('video', 'adv_pack_3000', '3,000 크레딧 (Advanced)', 3000, 60000,  true, 13),
  ('video', 'adv_pack_5000', '5,000 크레딧 (Advanced)', 5000, 88000,  true, 14)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 대가성 문구 기본값(org_id null). 모듈러 seed.sql:272-284 의 video 배치 8행과 같은 문구.
insert into public.affiliate_disclosures (org_id, provider, placement, body) values
  (null, 'coupang',                'video_description',    '이 영상은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'coupang',                'video_pinned_comment', '이 영상은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_brandconnect',     'video_description',    '이 영상은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 제작되었습니다.'),
  (null, 'naver_brandconnect',     'video_pinned_comment', '이 영상은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 제작되었습니다.'),
  (null, 'tenping',                'video_description',    '이 영상에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'tenping',                'video_pinned_comment', '이 영상에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'video_description',    '이 영상에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'video_pinned_comment', '이 영상에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.')
on conflict (provider, placement) where org_id is null do update
  set body = excluded.body;

-- =====================================================================
-- AI·음성 기능별 라우팅 기본값 17행 (2026-10-13). 정본 02_ARCHITECTURE.md 5.1절, 1200_video.sql 11.1절과 같다.
-- 체인 제공자는 0001_core_lite.sql SECTION 11, 12 가 먼저 넣은 ai_providers 행이어야 한다. 반복 실행 가능(upsert).
-- =====================================================================
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
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

-- 체인 검사: 존재하지 않거나 종류가 다른 제공자, 오픈소스 모드의 상용 제공자가 있으면 실패한다.
do $$
declare v_bad text;
begin
  select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
  from public.ai_routing_settings s
  cross join lateral jsonb_array_elements(s.chain) as e(item)
  left join public.ai_providers p on p.id = e.item ->> 'provider'
  where s.org_id is null and s.app_id = 'video'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'video routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;

-- =====================================================================
-- 2026-10-18 스토리보드 트랙(Track S) 데이터. 0002_video_domain.sql 12절 표의 seed(1200_video.sql 12.9절과 같은 값).
-- 템플릿 5종(VD-F-141, 제안 값)과 플랜 키. 위쪽 플랜 upsert 뒤에 병합하므로 반복 실행해도 값이 유지된다.
-- =====================================================================
--   beats.share 는 목표 길이 비율(합 1.0). kind 는 그래프가 쓸 장면 종류 기본값. 문구는 운영자가 이 seed 와 1200_video.sql 12.9절에서 함께 바꾼다.
insert into public.storyboard_templates (code, label, beats, default_scene_seconds, status) values
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
--   모놀리스는 이 파일 위쪽 플랜 upsert 가 features 를 통째로 바꾸므로 그 뒤에서 병합한다.
update public.plans
   set features = features || '{"storyboard": false, "storyboard_max_minutes": 0, "shorts_extract_max": 0}'::jsonb
 where app_id = 'video' and code = 'starter';
update public.plans
   set features = features || '{"storyboard": true, "storyboard_max_minutes": 10, "shorts_extract_max": 3}'::jsonb
 where app_id = 'video' and code = 'basic';
update public.plans
   set features = features || '{"storyboard": true, "storyboard_max_minutes": 30, "shorts_extract_max": 10}'::jsonb
 where app_id = 'video' and code = 'pro';
update public.plans
   set features = features || '{"storyboard": true, "storyboard_max_minutes": 60, "shorts_extract_max": 10}'::jsonb
 where app_id = 'video' and code = 'advanced';
