-- =====================================================================
-- seed.sql (모놀리스, website-floria)
-- apps 1행 + 기본 플랜 1행. 요금과 크레딧이 없는 제품이라 크레딧팩은 없다(01_PRD.md 4장).
-- 모듈러 seed(_supabase-modular/seed.sql)의 ('site', 'default') 행과 같은 값이다. 반복 실행 가능(upsert).
-- 사이트 등록(public.sites)은 seed가 아니라 provision_site(service_role)로 한다: org_id 가 가입 후에만 생기기 때문이다.
--   예) select public.provision_site('<org uuid>', 'floria', 'Floria', 'floria', array['https://floria.example'], 'studio@floria.example');
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('site', 'Website Floria', 'site', 'invite', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('site', 'default', 'Default', 0, 'none', 0, 0, false, '{}', true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;
