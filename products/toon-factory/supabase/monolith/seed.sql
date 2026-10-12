-- =====================================================================
-- seed.sql (toon-factory 모놀리스)
-- apps 1행, 플랜 2개(free 기본, pro), 크레딧팩 2개, 카탈로그 샘플 팩 1개(draft).
-- 금액·크레딧·features 정본: docs/products/toon-factory/01_PRD.md 4절.
--   free/pro 의 가격과 월 크레딧은 모듈러 seed(_supabase-modular/seed.sql:43, :108-111)와 같다.
--   features 키는 01_PRD 4절에서 확장했다(모듈러 seed 갱신은 06_AGENT_PLAN.md 6절 요청 항목).
--   크레딧팩은 제안(01_PRD 4절).
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('toon', 'Toon Factory', 'public', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('toon', 'free', 'Free', 0, 'month', 10, 0, false,
   '{"watermark": true, "export": ["png"], "exports_per_month": 20, "max_series": 1, "max_episodes_per_series": 3, "max_cuts_per_episode": 10, "asset_tiers": ["free"], "commercial_use": false, "mp4_max_seconds": 0, "user_asset_storage_mb": 100}',
   true, true, 0),
  ('toon', 'pro', 'Pro', 14900, 'month', 300, 0, false,
   '{"watermark": false, "export": ["png", "zip", "webtoon_strip", "mp4"], "exports_per_month": -1, "max_series": 20, "max_episodes_per_series": -1, "max_cuts_per_episode": 60, "asset_tiers": ["free", "premium"], "commercial_use": true, "mp4_max_seconds": 60, "user_asset_storage_mb": 2048}',
   false, true, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('toon', 'pack_100', '100 크레딧', 100, 5900,  true, 1),
  ('toon', 'pack_300', '300 크레딧', 300, 15900, true, 2)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 카탈로그 샘플 팩(draft). 라이선스 검증(license_verified_at/by) 전에는 published 로 바꿀 수 없다(CHECK).
-- 실제 에셋 행은 운영자 일괄 등록 도구(TN-06-008)가 Storage 업로드와 함께 넣는다.
insert into public.asset_packs (code, name, description, style_preset, tier, license_source, license_ref, commercial_use_allowed, status, sort_order)
values ('starter_daily', '일상 스타터 팩', 'MVP 캐릭터 2종 x 포즈 15 x 표정 6, 배경 20, 말풍선 10, 효과 글자 10 (01_PRD 3절 TN-F-010)',
        'flat_line', 'free', 'commissioned', 'CONTRACT-PENDING', true, 'draft', 0)
on conflict (code) do nothing;
