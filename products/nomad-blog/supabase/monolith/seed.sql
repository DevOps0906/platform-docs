-- =====================================================================
-- nomad-blog 모놀리스 seed.sql
-- 앱 1행(id = 'blog'), 플랜 3종(AI 키 포함), 크레딧팩 3종, 대가성 문구 기본값(blog_top 4행), AI·음성 라우팅 기본값 12행.
-- 금액과 크레딧의 정본은 docs/products/nomad-blog/01_PRD.md 4장이다.
--   플랜 가격(0 / 29,000 / 99,000원)과 월 발행 수(10 / 50 / 무제한)는 NOMAD Shorts Maker/src/lib/plans.ts:18-71 기준,
--   월 크레딧, 채널 수 일부, 크레딧팩 금액은 "제안"(01_PRD.md 4장에 이유).
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('blog', 'NOMAD Blog', 'blog', 'open', 'active')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('blog', 'free',     'Free',     0,     'month', 20,   0, false,
   '{"posts_per_month": 10, "max_channel_accounts": 2, "channel_types": ["naver","tistory","wordpress"], "ai_modes": ["fast"], "affiliate": true, "affiliate_auto_insert": false, "brandconnect": false, "schedule": false, "automation": false, "team_members": 1, "ai_chat": true, "ai_chat_turns_per_day": 50, "voice_chat": true, "dictation": true, "rag_documents": 10, "product_wiki": false}',
   true, true, 0),
  ('blog', 'pro',      'Pro',      29000, 'month', 300,  0, false,
   '{"posts_per_month": 50, "max_channel_accounts": 10, "channel_types": ["naver","tistory","wordpress"], "ai_modes": ["fast","quality"], "affiliate": true, "affiliate_auto_insert": true, "brandconnect": true, "schedule": true, "automation": false, "team_members": 1, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "dictation": true, "rag_documents": 100, "product_wiki": true}',
   false, true, 1),
  ('blog', 'business', 'Business', 99000, 'month', 1500, 0, false,
   '{"posts_per_month": -1, "max_channel_accounts": -1, "channel_types": ["naver","tistory","wordpress","instagram"], "ai_modes": ["fast","quality"], "affiliate": true, "affiliate_auto_insert": true, "brandconnect": true, "schedule": true, "automation": true, "team_members": 5, "ai_chat": true, "ai_chat_turns_per_day": 500, "voice_chat": true, "dictation": true, "rag_documents": 1000, "product_wiki": true}',
   false, true, 2)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('blog', 'pack_100',  '100 크레딧',   100,  4900,  true, 1),
  ('blog', 'pack_500',  '500 크레딧',   500,  19900, true, 2),
  ('blog', 'pack_1500', '1,500 크레딧', 1500, 49000, true, 3)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 대가성 문구 플랫폼 기본값(org_id null). 문구는 _supabase-modular/seed.sql 의 blog_top 행과 같다.
-- 조직은 owner/admin 권한으로 편집(upsert_affiliate_disclosure)만 할 수 있고 끌 수 없다.
insert into public.affiliate_disclosures (org_id, provider, placement, body) values
  (null, 'coupang',                'blog_top', '이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_brandconnect',     'blog_top', '이 글은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 작성되었습니다.'),
  (null, 'tenping',                'blog_top', '이 글에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'blog_top', '이 글에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.')
on conflict (provider, placement) where org_id is null do update
  set body = excluded.body;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 1300_blog.sql 9절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
--   녹음 원본은 저장하지 않는다(store_audio=false). 브랜드커넥트 자동 지원과 위험 동의는 AI 계층과 무관하게 유지된다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
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

-- 체인 검사: 존재하지 않거나 종류가 다른 제공자, 오픈소스 모드의 상용 제공자가 있으면 실패한다.
do $$
declare v_bad text;
begin
  select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
  from public.ai_routing_settings s
  cross join lateral jsonb_array_elements(s.chain) as e(item)
  left join public.ai_providers p on p.id = e.item ->> 'provider'
  where s.org_id is null and s.app_id = 'blog'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'blog routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
