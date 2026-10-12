-- =====================================================================
-- seed.sql (모놀리스 study-note)
-- 앱 레지스트리 1행(가입 트리거가 apps 가 1개면 자동 부트스트랩), 기본 플랜, Phase 2 플랜/크레딧팩(비활성).
-- model_catalog 와 runtime_config 는 0002_study_note_domain.sql 말미에 있다(설정 데이터이므로 마이그레이션과 함께 간다).
-- 금액과 크레딧은 제안값이다. 정본은 01_PRD.md 4장. 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('notes', 'Study Note', 'public', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- 기본(무료) 플랜: 월 30 크레딧, 이월 없음, 가입 크레딧 없음 (모듈러 seed.sql 의 notes 행과 동일)
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('notes', 'free', 'Free', 0, 'month', 30, 0, false,
   '{"max_input_chars": 5000, "allowed_tiers": ["lite", "standard"], "history_max_entries": 50, "history_max_bytes": 5000000}', true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- Phase 2: 베타 동안 비활성
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('notes', 'pro', 'Pro', 4900, 'month', 300, 0, false,
   '{"max_input_chars": 10000, "allowed_tiers": ["lite", "standard", "premium"], "history_max_entries": 500, "history_max_bytes": 50000000}', false, false, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, monthly_credits = excluded.monthly_credits,
      features = excluded.features, is_active = excluded.is_active, sort_order = excluded.sort_order;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('notes', 'pack_100', '100 크레딧', 100, 2900, false, 1),
  ('notes', 'pack_300', '300 크레딧', 300, 7900, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;
