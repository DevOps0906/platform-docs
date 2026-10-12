-- =====================================================================
-- admin-suite / sms 모놀리스 seed.sql
-- apps 1행(id 'sms'), 플랜 2행. 크레딧팩 없음(SECTION 4 제거). 금액은 제안(01_PRD 4절).
-- 학교 워크스페이스는 프로비저닝 스크립트(service_role)가 만든다.
-- =====================================================================
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('sms', 'Admin Suite School', 'sms', 'invite', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('sms', 'default',  'Default',  0,     'none',  0, 0, false, '{"max_students": 60, "max_classes": 3, "export_xlsx": false, "attendance_trend_days": 31}', true,  true, 0),
  ('sms', 'standard', 'Standard', 39000, 'month', 0, 0, false, '{"max_students": 1500, "max_classes": 60, "export_xlsx": true, "attendance_trend_days": 366}', false, true, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;
