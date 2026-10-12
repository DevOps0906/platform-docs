-- =====================================================================
-- seed.sql (모놀리스, nomad-commerce)
-- 선행: 0001_core_lite.sql, 0002_commerce_domain.sql
-- 정본: docs/products/nomad-commerce/01_PRD.md 4장 (확정 결정 8: V.2 가격표 + sellingstudio 크레딧 환산)
--   가격: Nomad-AI-Factory_V.2/PRD.md:296-301 / 월 크레딧: sellingstudio/PRD.md:155-158 / 크레딧팩: sellingstudio/PRD.md:160
--   features 키 해석: 01_PRD.md 4.4절. 모듈러 seed(_supabase-modular/seed.sql:37, :84-89)와 다른 값은 06_AGENT_PLAN.md 6장 요청.
-- 반복 실행 가능(upsert). 금지어 기본 사전은 0002 에 있다.
-- =====================================================================

-- 앱 1행. apps 가 정확히 1행이므로 signup_app 메타데이터가 없어도 가입 시 이 앱으로 부트스트랩된다(0001 SECTION 1).
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('commerce', 'NOMAD Commerce', 'public', 'open', 'active')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('commerce', 'free', 'Free', 0, 'month', 15, 0, false,
   '{"products": 30, "market_slots": 1, "detail_types": ["persuasive"], "slot_sets": [10], "concurrency": 1, "market_api": ["coupang", "smartstore"], "excel_export": false, "zip_export": true, "url_benchmark": false, "voice_input": false, "image_quality": "draft", "api_access": false}',
   true, true, 0),
  ('commerce', 'starter', 'Starter', 29000, 'month', 150, 0, false,
   '{"products": 300, "market_slots": 3, "detail_types": ["persuasive", "informative", "emotional"], "slot_sets": [10, 15], "concurrency": 1, "market_api": ["coupang", "smartstore"], "excel_export": true, "zip_export": true, "url_benchmark": true, "voice_input": true, "image_quality": "standard", "api_access": false}',
   false, true, 1),
  ('commerce', 'pro', 'Pro', 69000, 'month', 350, 0, false,
   '{"products": 2000, "market_slots": 10, "detail_types": ["persuasive", "informative", "emotional"], "slot_sets": [10, 15], "concurrency": 2, "market_api": ["coupang", "smartstore"], "excel_export": true, "zip_export": true, "url_benchmark": true, "voice_input": true, "image_quality": "pro", "api_access": false}',
   false, true, 2),
  ('commerce', 'enterprise', 'Enterprise', 149000, 'month', 550, 0, false,
   '{"products": -1, "market_slots": -1, "detail_types": ["persuasive", "informative", "emotional"], "slot_sets": [10, 15], "concurrency": 5, "market_api": ["coupang", "smartstore"], "excel_export": true, "zip_export": true, "url_benchmark": true, "voice_input": true, "image_quality": "ultra", "api_access": true}',
   false, true, 3)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('commerce', 'pack_50',  '50 크레딧',  50,  10000, true, 1),
  ('commerce', 'pack_120', '120 크레딧', 120, 20000, true, 2),
  ('commerce', 'pack_200', '200 크레딧', 200, 30000, true, 3)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;
