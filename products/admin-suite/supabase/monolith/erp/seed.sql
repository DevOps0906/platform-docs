-- =====================================================================
-- admin-suite / erp 모놀리스 seed.sql
-- apps 1행(id = 모듈러 스키마 이름 'erp'), 플랜 2행. 크레딧팩 없음(SECTION 4 제거).
-- 금액은 제안이다. 정본은 docs/products/admin-suite/01_PRD.md 4절.
-- 고객사 워크스페이스는 seed 가 아니라 프로비저닝 스크립트(service_role)가 만든다(05_DATA_MODEL 6절).
-- 반복 실행 가능(upsert).
-- =====================================================================
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('erp', 'Admin Suite ERP', 'erp', 'approval', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('erp', 'default',  'Default',  0,     'none',  0, 0, false, '{"max_members": 5, "storage_mb": 500, "export_xlsx": false, "sales_trend_days": 31}', true,  true, 0),
  ('erp', 'standard', 'Standard', 49000, 'month', 0, 0, false, '{"max_members": 50, "storage_mb": 10240, "export_xlsx": true, "sales_trend_days": 366}', false, true, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;
