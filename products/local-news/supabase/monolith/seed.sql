-- =====================================================================
-- seed.sql (모놀리스, local-news)
-- 정본: docs/products/local-news/01_PRD.md 4장(요금, 모두 제안), 마스터 브리프 5장(features 키)·7장(AI feature 키).
-- 모듈러 2500_news.sql 14절과 같은 값이다(이유도 그 절 주석). 반복 실행 가능(upsert).
-- 신문사·편집국·독자 행은 seed 가 아니라 RPC 로 만든다: request_newspaper(사용자) → approve_newspaper(service_role).
--   예) select public.approve_newspaper('<application uuid>', 'news_trial', '등록증 확인 2026-10-15');
-- 개발용 페르소나는 scripts/dev/seed-users.mjs --app news + 제품 훅이 만든다(05_DATA_MODEL.md 10절).
-- =====================================================================

-- 앱 1행. invite 앱이라 가입 트리거는 앱 행이 1개여도 엔타이틀먼트를 만들지 않는다(독자 가입은 엔타이틀먼트가 필요 없다).
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('news', 'Local News Cloud', 'public', 'invite', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- 플랜(VAT 별도, 무제한 값 없음). news_trial 이 기본 플랜이고 approve_newspaper 가 30일 만료로 부여한다.
-- theming_level: Starter 1, Standard 2, Pro 2, Enterprise 3. 엔터프라이즈는 계약 전용이라 is_active=false(가격표 비노출).
insert into public.plans (app_id, code, name, description, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('news', 'news_trial', '체험', 'Standard 기능 30일 체험(기자 3명)', 0, 'none', 300, 0, false,
   '{"news_staff_max": 3, "news_custom_domains": 0, "news_newsletter_monthly": 5000, "news_storage_gb": 10, "news_print_pdf": false, "news_regional_editions": false, "news_reader_fee_bps": 0, "news_api": false, "news_support_reports": false, "ai_monthly_credits": 300, "theming_level": 2}',
   true, true, 0),
  ('news', 'news_starter', '스타터', '인터넷 지역신문', 99000, 'month', 300, 0, false,
   '{"news_staff_max": 3, "news_custom_domains": 0, "news_newsletter_monthly": 5000, "news_storage_gb": 10, "news_print_pdf": false, "news_regional_editions": false, "news_reader_fee_bps": 300, "news_api": false, "news_support_reports": false, "ai_monthly_credits": 300, "theming_level": 1}',
   false, true, 1),
  ('news', 'news_standard', '스탠다드', '지역 주간지', 199000, 'month', 1500, 0, false,
   '{"news_staff_max": 10, "news_custom_domains": 1, "news_newsletter_monthly": 30000, "news_storage_gb": 50, "news_print_pdf": false, "news_regional_editions": false, "news_reader_fee_bps": 0, "news_api": false, "news_support_reports": false, "ai_monthly_credits": 1500, "theming_level": 2}',
   false, true, 2),
  ('news', 'news_pro', '프로', '지역 일간지', 390000, 'month', 4000, 0, false,
   '{"news_staff_max": 30, "news_custom_domains": 3, "news_newsletter_monthly": 100000, "news_storage_gb": 200, "news_print_pdf": true, "news_regional_editions": true, "news_reader_fee_bps": 0, "news_api": true, "news_support_reports": true, "ai_monthly_credits": 4000, "theming_level": 2}',
   false, true, 3),
  ('news', 'news_enterprise', '엔터프라이즈', '전용 DB(판매 모델 B), SLA. 계약 금액 별도', 0, 'month', 10000, 0, false,
   '{"news_staff_max": 200, "news_custom_domains": 5, "news_newsletter_monthly": 500000, "news_storage_gb": 1000, "news_print_pdf": true, "news_regional_editions": true, "news_reader_fee_bps": 0, "news_api": true, "news_support_reports": true, "ai_monthly_credits": 10000, "theming_level": 3}',
   false, false, 4)
on conflict (app_id, code) do update
  set name = excluded.name, description = excluded.description, price_krw = excluded.price_krw,
      billing_interval = excluded.billing_interval, monthly_credits = excluded.monthly_credits,
      signup_credits = excluded.signup_credits, carry_over = excluded.carry_over, features = excluded.features,
      is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 크레딧팩: 없음(제안). AI 는 플랜 월 크레딧만 쓴다. 추가 구매는 01_PRD 4장 열린 결정 D-5.

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값. 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
-- news.moderation(독자 개인정보), news.stt(취재원 목소리), dify.aux 는 오픈소스 강제.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'news', 'news.draft',     'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'news', 'news.headline',  'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"}]', false),
  (null, 'news', 'news.summary',   'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"}]', false),
  (null, 'news', 'news.proofread', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"}]', false),
  (null, 'news', 'news.alt_text',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"google","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'news', 'news.moderation','llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'news', 'news.assistant', 'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'news', 'news.knowledge', 'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'news', 'news.tts',       'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'news', 'news.stt',       'stt',       'open_source', '[{"provider":"oss-voice","model":"*"}]', true),
  (null, 'news', 'wiki.query',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'news', 'wiki.ingest',    'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'news', 'wiki.lint',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'news', 'dify.aux',       'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true)
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
  where s.org_id is null and s.app_id = 'news'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'news routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
