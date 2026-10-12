-- =====================================================================
-- seed.sql (astro-ai 모놀리스)
-- 정본: Astro AI 단가표(확정 결정 8) = Astro AI/기획안/공통/PRD.md:29-58. 요금 해석은 docs/products/astro-ai/01_PRD.md 4장.
-- MVP 결제 수단은 크레딧팩 일회 결제만(확정 결정 7). 구독 플랜(Basic/Pro/Master)은 Phase 2 이므로 넣지 않는다.
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('astro', '신비로운AI', 'public', 'open', 'active')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- 기본 플랜 Starter (무료, 가입 1회 30cr = PRD.md:31)
-- signup_credits 를 0 으로 두는 이유(제안, 01_PRD.md 4.4절): 가입 트리거는 auth.users INSERT 시점(이메일 인증 전)에
-- 지급하므로, 무료 크레딧 반복 수령(docs/reviews/FortuneDocs.md:51)을 막기 위해 30cr 은 서버가
-- 이메일 인증 완료 또는 Google 로그인 확인 뒤 grant_credits(멱등 키 signup:<org_id>:astro)로 지급한다.
-- 사용자가 "가입 즉시 지급"을 고르면 이 값을 30 으로 바꾸고 서버 지급 경로를 끈다(01_PRD.md 8장 결정 D-3).
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('astro', 'starter', 'Starter', 0, 'none', 0, 0, false,
   '{"readings": ["saju", "tarot", "combined"], "pdf_themes": ["mystical-dark", "oracle-gold"], "max_subjects": 20, "email_delivery": true, "welcome_credits": 30}',
   true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 크레딧팩 4종 (PRD.md:52-58). credits 는 보너스를 포함한 지급 총량이다(core.credit_packs 에 보너스 컬럼이 없음).
insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('astro', 'pack_100',  '100 크레딧',              100,  4900,  true, 1),
  ('astro', 'pack_300',  '300 + 보너스 30 크레딧',   330,  12900, true, 2),
  ('astro', 'pack_700',  '700 + 보너스 100 크레딧',  800,  27900, true, 3),
  ('astro', 'pack_2000', '2,000 + 보너스 400 크레딧', 2400, 69900, true, 4)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 테마 2종은 0002_astro_domain.sql 11절에서 넣는다(FK 참조 데이터).
