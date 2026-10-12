-- =====================================================================
-- seed.sql (nomad-video 모놀리스)
-- apps 1행, 플랜 4개(PRD_pricing.md 정본, 확정 결정 8), 크레딧팩 4개 + Advanced 30% 할인팩 4개, video 배치 대가성 문구 기본값.
-- 정본: NOMAD Shorts Maker/PRD_pricing.md:116-155. Track F 는 확정 결정 7 로 추가(모듈러 seed.sql:211-212 와 같게 Pro 이상).
-- features 키 해석은 docs/products/nomad-video/01_PRD.md 4장. 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('video', 'NOMAD AI Factory', 'video', 'open', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('video', 'starter',  'Starter',  0,      'none',  0,    100, false,
   '{"tracks": ["A"], "languages": ["KO"], "max_channels": 1, "watermark": true, "platforms": ["youtube"], "radar": false, "compliance": false, "team_members": 1}',
   true, true, 0),
  ('video', 'basic',    'Basic',    49000,  'month', 1200, 0, false,
   '{"tracks": ["A","B","C"], "languages": ["KO"], "max_channels": 5, "watermark": false, "platforms": ["youtube"], "radar": ["playboard"], "compliance": true, "silence_cut": true, "coupang_landing": true, "team_members": 1}',
   false, true, 1),
  ('video', 'pro',      'Pro',      99000,  'month', 3000, 0, false,
   '{"tracks": ["A","B","C","D","E","F"], "languages": ["KO","JA","EN"], "max_channels": 15, "watermark": false, "platforms": ["youtube","instagram","tiktok","threads"], "radar": ["playboard","channel_finder","bling"], "compliance": true, "silence_cut": true, "layer_composite": true, "coupang_landing": true, "suno": true, "osmu": true, "bling_monthly_limit": 20, "team_members": 1, "priority_render": true}',
   false, true, 2),
  ('video', 'advanced', 'Advanced', 149000, 'month', 5000, 0, false,
   '{"tracks": ["A","B","C","D","E","F"], "languages": ["KO","JA","EN"], "max_channels": 40, "watermark": false, "platforms": ["youtube","instagram","tiktok","threads"], "radar": ["playboard","channel_finder","bling"], "compliance": true, "silence_cut": true, "layer_composite": true, "coupang_landing": true, "suno": true, "osmu": true, "react_flow_full": true, "bling_monthly_limit": -1, "team_members": 5, "api_access": true, "priority_render": true, "credit_discount_pct": 30}',
   false, true, 3)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 크레딧팩: 정가 4종(PRD_pricing.md:149-154). adv_* 4종은 Advanced 30% 할인가. 서버(createOrder)가 Advanced 조직에만 adv_* 를 허용한다.
insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('video', 'pack_500',      '500 크레딧',              500,  15000,  true, 1),
  ('video', 'pack_1000',     '1,000 크레딧',            1000, 28000,  true, 2),
  ('video', 'pack_3000',     '3,000 크레딧',            3000, 75000,  true, 3),
  ('video', 'pack_5000',     '5,000 크레딧',            5000, 110000, true, 4),
  ('video', 'adv_pack_500',  '500 크레딧 (Advanced)',   500,  10500,  true, 11),
  ('video', 'adv_pack_1000', '1,000 크레딧 (Advanced)', 1000, 19600,  true, 12),
  ('video', 'adv_pack_3000', '3,000 크레딧 (Advanced)', 3000, 52500,  true, 13),
  ('video', 'adv_pack_5000', '5,000 크레딧 (Advanced)', 5000, 77000,  true, 14)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 대가성 문구 기본값(org_id null). 모듈러 seed.sql:272-284 의 video 배치 8행과 같은 문구.
insert into public.affiliate_disclosures (org_id, provider, placement, body) values
  (null, 'coupang',                'video_description',    '이 영상은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'coupang',                'video_pinned_comment', '이 영상은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_brandconnect',     'video_description',    '이 영상은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 제작되었습니다.'),
  (null, 'naver_brandconnect',     'video_pinned_comment', '이 영상은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 제작되었습니다.'),
  (null, 'tenping',                'video_description',    '이 영상에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'tenping',                'video_pinned_comment', '이 영상에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'video_description',    '이 영상에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'video_pinned_comment', '이 영상에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.')
on conflict (provider, placement) where org_id is null do update
  set body = excluded.body;
