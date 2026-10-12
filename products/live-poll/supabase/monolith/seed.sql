-- =====================================================================
-- seed.sql (live-poll 모놀리스)
-- apps 1행 + 플랜. 금액과 한도의 정본은 docs/products/live-poll/01_PRD.md 4장이다.
-- 베타 기간에는 free 만 is_active=true. pro/business 는 Phase 2(유료 전환) 때 is_active 를 켠다.
-- 크레딧을 쓰지 않으므로 monthly_credits/signup_credits 는 0, 크레딧팩 없음.
-- 플랫폼 기본 금칙어는 0002_poll_domain.sql 18절에 있다.
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('poll', 'Live Poll', 'poll', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('poll', 'free',     'Free(베타)', 0,     'none',  0, 0, false,
   '{"max_participants": 100, "max_live_events": 1, "max_events": 50, "polls_per_event": 50, "qna": true, "export_csv": true, "overlay": true, "branding": true, "retention_days": 30, "team_members": 1}',
   true, true, 0),
  ('poll', 'pro',      'Pro',        19900, 'month', 0, 0, false,
   '{"max_participants": 1000, "max_live_events": 3, "max_events": -1, "polls_per_event": -1, "qna": true, "export_csv": true, "overlay": true, "branding": false, "retention_days": 365, "team_members": 1}',
   false, false, 1),
  ('poll', 'business', 'Business',   59000, 'month', 0, 0, false,
   '{"max_participants": 3000, "max_live_events": 10, "max_events": -1, "polls_per_event": -1, "qna": true, "export_csv": true, "overlay": true, "branding": false, "retention_days": 730, "team_members": 5}',
   false, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;
