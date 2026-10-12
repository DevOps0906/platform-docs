-- =====================================================================
-- seed.sql (stock-dashboard 모놀리스)
-- apps 1행, 플랜 3개(default, beta, pro), 종목 마스터 샘플. 반복 실행 가능(upsert).
-- 금액/크레딧 정본: docs/products/stock-dashboard/01_PRD.md 4장. 수치는 모두 "제안"이다.
-- 크레딧팩은 두지 않는다(AI 진단을 건별 판매하지 않음, 01_PRD 4장과 6장).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('stock', 'Stock Dashboard', 'stock', 'invite', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- default: 가입 트리거가 부여. 기능 없음. 실제 접근은 beta_access(초대 수락)가 있어야 열린다.
-- beta  : 초대 수락 시 서버가 전환(04_API 3장). 무료, 월 300 크레딧(AI 진단 10cr x 30회).
-- pro   : 법률 검토와 유사투자자문업 판단 전까지 is_active = false. 결제 화면에 노출되지 않는다.
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('stock', 'default', 'Default', 0, 'none', 0, 0, false, '{}', true, true, 0),
  ('stock', 'beta', 'Beta', 0, 'month', 300, 0, false,
   '{"ai_diagnosis_per_day": 10, "broker_connections_max": 2, "ai_modes": ["quality"], "ai_compare": false, "ideas": false, "leaderboard": false, "paper_orders": false, "history_days": 365}',
   false, true, 1),
  ('stock', 'pro', 'Pro', 9900, 'month', 600, 0, false,
   '{"ai_diagnosis_per_day": 20, "broker_connections_max": 3, "ai_modes": ["fast", "quality"], "ai_compare": true, "ideas": true, "leaderboard": true, "paper_orders": true, "history_days": 730}',
   false, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 종목 마스터 샘플(MockBroker 와 화면 개발용). 실데이터는 동기화 워커가 채운다. 시세 값은 넣지 않는다.
-- IDXKSP 는 코스피 지수의 내부 의사 코드(성과 평가 기준 지수, 01_PRD ST-F-013).
insert into public.instruments (symbol, name, market, sector) values
  ('005930', '삼성전자', 'KOSPI', '전기전자'),
  ('000660', 'SK하이닉스', 'KOSPI', '전기전자'),
  ('035420', 'NAVER', 'KOSPI', '서비스업'),
  ('005380', '현대차', 'KOSPI', '운수장비'),
  ('068270', '셀트리온', 'KOSPI', '의약품'),
  ('IDXKSP', '코스피 지수', 'INDEX', null)
on conflict (symbol) do update set name = excluded.name, market = excluded.market, sector = excluded.sector;
