-- =====================================================================
-- seed.sql
-- 앱 레지스트리(README.md의 모듈러 스키마 전부, hms 제외), 앱별 플랜/크레딧팩, 대가성 문구 기본값.
-- 정본: 각 제품 docs/products/<제품>/01_PRD.md 4장(요금과 크레딧). 플랜/팩/features 값은 각 제품
--   모놀리스 seed(docs/products/<제품>/supabase/monolith/seed.sql)와 같게 맞춘다(3단계 대조, VERIFICATION.md 5장).
--   금액과 크레딧 중 "제안" 표시는 각 01_PRD.md 4장의 근거를 따른다. 확정 시 모놀리스 seed와 이 파일을 함께 갱신한다.
-- 제품 조각(1300 blog, 1600 erp, 1700 sms, 1900 stock, 2100 notes, 2300 docs)도 자기 플랜을 on conflict do nothing 으로 넣는다.
--   이 파일은 on conflict do update 이므로 seed 를 조각 앞에 돌리든 뒤에 돌리든 최종 값은 이 파일 값이다.
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into core.apps (id, name, schema_name, signup_policy, status) values
  ('publishing', 'FLORA Publishing',    'publishing', 'open', 'active'),
  ('astro',      '신비로운AI',            'astro',      'open', 'active'),
  ('video',      'NOMAD AI Factory',     'video',      'open', 'active'),
  ('blog',       'NOMAD Blog',           'blog',       'open', 'active'),
  ('commerce',   'NOMAD Commerce',       'commerce',   'open', 'active'),
  ('microweb',   'Microweb Studio',      'microweb',   'invite', 'beta'),
  ('erp',        'Admin Suite ERP',      'erp',        'approval', 'active'),
  ('sms',        'Admin Suite School',   'sms',        'invite', 'active'),
  ('poll',       'Live Poll',            'poll',       'open', 'beta'),
  ('stock',      'Stock Dashboard',      'stock',      'invite', 'beta'),
  ('toon',       'Toon Factory',         'toon',       'open', 'beta'),
  ('notes',      'Study Note',           'notes',      'open', 'beta'),
  ('site',       'Website Floria',       'site',       'invite', 'beta'),
  ('docs',       'NOMAD Docs',           'docs',       'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- ---------------------------------------------------------------------
-- 전 앱 플랜. 모든 행이 같은 upsert 를 쓴다(모놀리스 seed 의 플랜 행을 그대로 옮김, -1 = 무제한).
-- 앱당 is_default 는 정확히 1행(plans_one_default_per_app_idx).
-- astro starter.signup_credits = 0: 30cr 은 이메일 인증 또는 Google 로그인 확인 뒤 서버가
--   grant_credits(멱등 키 signup:<org_id>:astro)로 지급한다(astro-ai/01_PRD.md 4장, 8장 결정 D-3 (b) 가정).
--   features.welcome_credits = 30 이 그 지급량이다. "가입 즉시 지급"으로 확정되면 30 으로 바꾸고 서버 지급 경로를 끈다.
-- ---------------------------------------------------------------------
insert into core.plans (app_id, code, name, description, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  -- publishing (flora-publishing/01_PRD.md 4장)
  ('publishing', 'free', 'Free', '작은 책 한 권을 체험하는 무료 플랜', 0, 'month', 20, 0, false,
   '{"watermark": true, "exports_per_month": 2, "themes": ["basic"], "max_books": 3, "max_chapters": 3, "max_sections": 6, "max_paragraphs": 3, "personas": 40, "write_all": false, "upload": false, "tone_slider": false, "writing_assist": false, "quality_mode": false, "persona_blend": false, "webhooks": false, "public_page": false}',
   true, true, 0),
  ('publishing', 'basic', 'Basic', '워터마크 없이 책을 계속 만드는 월 구독', 9900, 'month', 200, 0, false,
   '{"watermark": false, "exports_per_month": -1, "themes": ["basic", "pro"], "max_books": -1, "max_chapters": 20, "max_sections": 200, "max_paragraphs": 5, "personas": 60, "write_all": true, "upload": true, "tone_slider": true, "writing_assist": true, "quality_mode": true, "persona_blend": true, "webhooks": true, "public_page": true}',
   false, true, 1),
  -- astro (astro-ai/01_PRD.md 4장, MVP 는 크레딧팩만. 구독은 Phase 2)
  ('astro', 'starter', 'Starter', null, 0, 'none', 0, 0, false,
   '{"readings": ["saju", "tarot", "combined"], "pdf_themes": ["mystical-dark", "oracle-gold"], "max_subjects": 20, "email_delivery": true, "welcome_credits": 30}',
   true, true, 0),
  -- video (NOMAD Shorts Maker/PRD_pricing.md 정본, 확정 결정 8, 이월 불가)
  ('video', 'starter', 'Starter', null, 0, 'none', 0, 100, false,
   '{"tracks": ["A"], "languages": ["KO"], "max_channels": 1, "watermark": true, "platforms": ["youtube"], "radar": false, "compliance": false, "team_members": 1}',
   true, true, 0),
  ('video', 'basic', 'Basic', null, 49000, 'month', 1200, 0, false,
   '{"tracks": ["A","B","C"], "languages": ["KO"], "max_channels": 5, "watermark": false, "platforms": ["youtube"], "radar": ["playboard"], "compliance": true, "silence_cut": true, "coupang_landing": true, "team_members": 1}',
   false, true, 1),
  ('video', 'pro', 'Pro', null, 99000, 'month', 3000, 0, false,
   '{"tracks": ["A","B","C","D","E","F"], "languages": ["KO","JA","EN"], "max_channels": 15, "watermark": false, "platforms": ["youtube","instagram","tiktok","threads","naver_clip"], "brandconnect_clip": true, "radar": ["playboard","channel_finder","bling"], "compliance": true, "silence_cut": true, "layer_composite": true, "coupang_landing": true, "suno": true, "osmu": true, "bling_monthly_limit": 20, "team_members": 1, "priority_render": true}',
   false, true, 2),
  ('video', 'advanced', 'Advanced', null, 149000, 'month', 5000, 0, false,
   '{"tracks": ["A","B","C","D","E","F"], "languages": ["KO","JA","EN"], "max_channels": 40, "watermark": false, "platforms": ["youtube","instagram","tiktok","threads","naver_clip"], "brandconnect_clip": true, "radar": ["playboard","channel_finder","bling"], "compliance": true, "silence_cut": true, "layer_composite": true, "coupang_landing": true, "suno": true, "osmu": true, "react_flow_full": true, "bling_monthly_limit": -1, "team_members": 5, "api_access": true, "agency": true, "priority_render": true, "credit_discount_pct": 30}',
   false, true, 3),
  -- blog (nomad-blog/01_PRD.md 4장)
  ('blog', 'free', 'Free', null, 0, 'month', 20, 0, false,
   '{"posts_per_month": 10, "max_channel_accounts": 2, "channel_types": ["naver","tistory","wordpress"], "ai_modes": ["fast"], "affiliate": true, "affiliate_auto_insert": false, "brandconnect": false, "schedule": false, "automation": false, "team_members": 1}',
   true, true, 0),
  ('blog', 'pro', 'Pro', null, 29000, 'month', 300, 0, false,
   '{"posts_per_month": 50, "max_channel_accounts": 10, "channel_types": ["naver","tistory","wordpress"], "ai_modes": ["fast","quality"], "affiliate": true, "affiliate_auto_insert": true, "brandconnect": true, "schedule": true, "automation": false, "team_members": 1}',
   false, true, 1),
  ('blog', 'business', 'Business', null, 99000, 'month', 1500, 0, false,
   '{"posts_per_month": -1, "max_channel_accounts": -1, "channel_types": ["naver","tistory","wordpress","instagram"], "ai_modes": ["fast","quality"], "affiliate": true, "affiliate_auto_insert": true, "brandconnect": true, "schedule": true, "automation": true, "team_members": 5}',
   false, true, 2),
  -- commerce (nomad-commerce/01_PRD.md 4장, 확정 결정 8: V.2 가격표 + sellingstudio 크레딧 환산)
  ('commerce', 'free', 'Free', null, 0, 'month', 15, 0, false,
   '{"products": 30, "market_slots": 1, "detail_types": ["persuasive"], "slot_sets": [10], "concurrency": 1, "market_api": ["coupang", "smartstore"], "excel_export": false, "zip_export": true, "url_benchmark": false, "voice_input": false, "image_quality": "draft", "api_access": false}',
   true, true, 0),
  ('commerce', 'starter', 'Starter', null, 29000, 'month', 150, 0, false,
   '{"products": 300, "market_slots": 3, "detail_types": ["persuasive", "informative", "emotional"], "slot_sets": [10, 15], "concurrency": 1, "market_api": ["coupang", "smartstore"], "excel_export": true, "zip_export": true, "url_benchmark": true, "voice_input": true, "image_quality": "standard", "api_access": false}',
   false, true, 1),
  ('commerce', 'pro', 'Pro', null, 69000, 'month', 350, 0, false,
   '{"products": 2000, "market_slots": 10, "detail_types": ["persuasive", "informative", "emotional"], "slot_sets": [10, 15], "concurrency": 2, "market_api": ["coupang", "smartstore"], "excel_export": true, "zip_export": true, "url_benchmark": true, "voice_input": true, "image_quality": "pro", "api_access": false}',
   false, true, 2),
  ('commerce', 'enterprise', 'Enterprise', null, 149000, 'month', 550, 0, false,
   '{"products": -1, "market_slots": -1, "detail_types": ["persuasive", "informative", "emotional"], "slot_sets": [10, 15], "concurrency": 5, "market_api": ["coupang", "smartstore"], "excel_export": true, "zip_export": true, "url_benchmark": true, "voice_input": true, "image_quality": "ultra", "api_access": true}',
   false, true, 3),
  -- microweb (microweb-studio/01_PRD.md 4장, 대행 단계에는 구독 과금 없음)
  ('microweb', 'free', 'Free', null, 0, 'none', 0, 0, false,
   '{"guestbook": true, "rsvp": true, "ai_greeting": true, "ai_greeting_per_site_30d": 300, "bgm_upload": true, "max_gallery_photos": 30, "max_hero_photos": 5, "custom_slug": true}',
   true, true, 0),
  -- erp (admin-suite/01_PRD.md 4절, 제안)
  ('erp', 'default', 'Default', null, 0, 'none', 0, 0, false,
   '{"max_members": 5, "storage_mb": 500, "export_xlsx": false, "sales_trend_days": 31}',
   true, true, 0),
  ('erp', 'standard', 'Standard', null, 49000, 'month', 0, 0, false,
   '{"max_members": 50, "storage_mb": 10240, "export_xlsx": true, "sales_trend_days": 366}',
   false, true, 1),
  -- sms (admin-suite/01_PRD.md 4절, 제안)
  ('sms', 'default', 'Default', null, 0, 'none', 0, 0, false,
   '{"max_students": 60, "max_classes": 3, "export_xlsx": false, "attendance_trend_days": 31}',
   true, true, 0),
  ('sms', 'standard', 'Standard', null, 39000, 'month', 0, 0, false,
   '{"max_students": 1500, "max_classes": 60, "export_xlsx": true, "attendance_trend_days": 366}',
   false, true, 1),
  -- poll (live-poll/01_PRD.md 4장, 베타 동안 free 만 활성. 크레딧 미사용)
  ('poll', 'free', 'Free(베타)', null, 0, 'none', 0, 0, false,
   '{"max_participants": 100, "max_live_events": 1, "max_events": 50, "polls_per_event": 50, "qna": true, "export_csv": true, "overlay": true, "branding": true, "retention_days": 30, "team_members": 1}',
   true, true, 0),
  ('poll', 'pro', 'Pro', null, 19900, 'month', 0, 0, false,
   '{"max_participants": 1000, "max_live_events": 3, "max_events": -1, "polls_per_event": -1, "qna": true, "export_csv": true, "overlay": true, "branding": false, "retention_days": 365, "team_members": 1}',
   false, false, 1),
  ('poll', 'business', 'Business', null, 59000, 'month', 0, 0, false,
   '{"max_participants": 3000, "max_live_events": 10, "max_events": -1, "polls_per_event": -1, "qna": true, "export_csv": true, "overlay": true, "branding": false, "retention_days": 730, "team_members": 5}',
   false, false, 2),
  -- stock (stock-dashboard/01_PRD.md 4장, 제안. pro 는 법률 검토 전까지 비활성. 크레딧팩 없음)
  ('stock', 'default', 'Default', null, 0, 'none', 0, 0, false, '{}', true, true, 0),
  ('stock', 'beta', 'Beta', null, 0, 'month', 300, 0, false,
   '{"ai_diagnosis_per_day": 10, "broker_connections_max": 2, "ai_modes": ["quality"], "ai_compare": false, "ideas": false, "leaderboard": false, "paper_orders": false, "history_days": 365}',
   false, true, 1),
  ('stock', 'pro', 'Pro', null, 9900, 'month', 600, 0, false,
   '{"ai_diagnosis_per_day": 20, "broker_connections_max": 3, "ai_modes": ["fast", "quality"], "ai_compare": true, "ideas": true, "leaderboard": true, "paper_orders": true, "history_days": 730}',
   false, false, 2),
  -- toon (toon-factory/01_PRD.md 4절)
  ('toon', 'free', 'Free', null, 0, 'month', 10, 0, false,
   '{"watermark": true, "export": ["png"], "exports_per_month": 20, "max_series": 1, "max_episodes_per_series": 3, "max_cuts_per_episode": 10, "asset_tiers": ["free"], "commercial_use": false, "mp4_max_seconds": 0, "user_asset_storage_mb": 100}',
   true, true, 0),
  ('toon', 'pro', 'Pro', null, 14900, 'month', 300, 0, false,
   '{"watermark": false, "export": ["png", "zip", "webtoon_strip", "mp4"], "exports_per_month": -1, "max_series": 20, "max_episodes_per_series": -1, "max_cuts_per_episode": 60, "asset_tiers": ["free", "premium"], "commercial_use": true, "mp4_max_seconds": 60, "user_asset_storage_mb": 2048}',
   false, true, 1),
  -- notes (study-note/01_PRD.md 4장, Phase 2 플랜은 베타 동안 비활성)
  ('notes', 'free', 'Free', null, 0, 'month', 30, 0, false,
   '{"max_input_chars": 5000, "allowed_tiers": ["lite", "standard"], "history_max_entries": 50, "history_max_bytes": 5000000}',
   true, true, 0),
  ('notes', 'pro', 'Pro', null, 4900, 'month', 300, 0, false,
   '{"max_input_chars": 10000, "allowed_tiers": ["lite", "standard", "premium"], "history_max_entries": 500, "history_max_bytes": 50000000}',
   false, false, 1),
  -- site (website-floria/01_PRD.md 4장, 요금 없음)
  ('site', 'default', 'Default', null, 0, 'none', 0, 0, false, '{}', true, true, 0),
  -- docs (nomad-docs/01_PRD.md 4장, 전부 제안. team 은 Phase 2 전까지 비활성)
  ('docs', 'free', 'Free', null, 0, 'month', 30, 50, false,
   '{"projects_max": 2, "formats": ["pdf"], "watermark": true, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 30, "minutes_max_minutes": 30, "storage_mb": 200}',
   true, true, 0),
  ('docs', 'pro', 'Pro', null, 19900, 'month', 400, 0, false,
   '{"projects_max": 50, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv", "webhook"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 200, "minutes_max_minutes": 120, "storage_mb": 5000}',
   false, true, 1),
  ('docs', 'team', 'Team', null, 59000, 'month', 1500, 0, false,
   '{"projects_max": null, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "phase2", "members_max": 5, "integrations": ["csv", "webhook", "hubspot", "admin_suite_erp", "make", "n8n"], "approvals": true, "share_links": true, "ai_chat_turns_per_day": 500, "minutes_max_minutes": 180, "storage_mb": 20000}',
   false, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, description = excluded.description, price_krw = excluded.price_krw,
      billing_interval = excluded.billing_interval, monthly_credits = excluded.monthly_credits,
      signup_credits = excluded.signup_credits, carry_over = excluded.carry_over, features = excluded.features,
      is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------
-- 크레딧팩(일회 결제, pack 버킷). credits 는 보너스를 포함한 지급 총량이다.
-- 크레딧팩이 없는 앱: erp, sms, poll, stock, site.
-- ---------------------------------------------------------------------
insert into core.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  -- publishing
  ('publishing', 'pack_100', '100 크레딧', 100, 9900,  true, 1),
  ('publishing', 'pack_500', '500 크레딧', 500, 39900, true, 2),
  -- astro (Astro AI 단가표 PRD.md:52-58)
  ('astro', 'pack_100',  '100 크레딧',               100,  4900,  true, 1),
  ('astro', 'pack_300',  '300 + 보너스 30 크레딧',    330,  12900, true, 2),
  ('astro', 'pack_700',  '700 + 보너스 100 크레딧',   800,  27900, true, 3),
  ('astro', 'pack_2000', '2,000 + 보너스 400 크레딧', 2400, 69900, true, 4),
  -- video: 정가 4종 + Advanced 30% 할인 4종(서버가 Advanced 조직에만 adv_* 허용)
  ('video', 'pack_500',      '500 크레딧',              500,  15000,  true, 1),
  ('video', 'pack_1000',     '1,000 크레딧',            1000, 28000,  true, 2),
  ('video', 'pack_3000',     '3,000 크레딧',            3000, 75000,  true, 3),
  ('video', 'pack_5000',     '5,000 크레딧',            5000, 110000, true, 4),
  ('video', 'adv_pack_500',  '500 크레딧 (Advanced)',   500,  10500,  true, 11),
  ('video', 'adv_pack_1000', '1,000 크레딧 (Advanced)', 1000, 19600,  true, 12),
  ('video', 'adv_pack_3000', '3,000 크레딧 (Advanced)', 3000, 52500,  true, 13),
  ('video', 'adv_pack_5000', '5,000 크레딧 (Advanced)', 5000, 77000,  true, 14),
  -- blog
  ('blog', 'pack_100',  '100 크레딧',   100,  4900,  true, 1),
  ('blog', 'pack_500',  '500 크레딧',   500,  19900, true, 2),
  ('blog', 'pack_1500', '1,500 크레딧', 1500, 49000, true, 3),
  -- commerce (sellingstudio/PRD.md:160)
  ('commerce', 'pack_50',  '50 크레딧',  50,  10000, true, 1),
  ('commerce', 'pack_120', '120 크레딧', 120, 20000, true, 2),
  ('commerce', 'pack_200', '200 크레딧', 200, 30000, true, 3),
  -- microweb: 셀프서비스 발행권(Phase 2 전까지 비활성)
  ('microweb', 'pack_30', '30 크레딧 (청첩장 1건)', 30, 30000, false, 1),
  ('microweb', 'pack_60', '60 크레딧 (청첩장 2건)', 60, 57000, false, 2),
  -- toon
  ('toon', 'pack_100', '100 크레딧', 100, 5900,  true, 1),
  ('toon', 'pack_300', '300 크레딧', 300, 15900, true, 2),
  -- notes (Phase 2, 베타 동안 비활성)
  ('notes', 'pack_100', '100 크레딧', 100, 2900, false, 1),
  ('notes', 'pack_300', '300 크레딧', 300, 7900, false, 2),
  -- docs
  ('docs', 'pack_100',  '100 크레딧',   100,  4900,  true, 1),
  ('docs', 'pack_300',  '300 크레딧',   300,  12900, true, 2),
  ('docs', 'pack_1000', '1,000 크레딧', 1000, 39000, true, 3)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 이전 버전 seed 가 넣었던, 정본에 없는 팩은 지우지 않고 판매만 멈춘다(payment_orders 가 참조할 수 있음).
update core.credit_packs set is_active = false
 where (app_id, code) in (('astro', 'pack_1000'))
   and is_active;

-- ---------------------------------------------------------------------
-- affiliate: 플랫폼 기본 대가성 문구(org_id null). org가 owner/admin 권한으로 편집할 수 있지만 끌 수는 없다.
-- 쿠팡은 쿠팡 파트너스 고지 문구 원문을 쓴다. 나머지는 공정위 추천·보증 심사지침 기준 공통 문구(제안).
-- ---------------------------------------------------------------------
insert into core.affiliate_disclosures (org_id, provider, placement, body) values
  (null, 'coupang', 'blog_top',             '이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'coupang', 'video_description',    '이 영상은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'coupang', 'video_pinned_comment', '이 영상은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_brandconnect', 'blog_top',             '이 글은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 작성되었습니다.'),
  (null, 'naver_brandconnect', 'video_description',    '이 영상은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 제작되었습니다.'),
  (null, 'naver_brandconnect', 'video_pinned_comment', '이 영상은 네이버 브랜드커넥트를 통해 브랜드로부터 제품 또는 원고료를 제공받아 제작되었습니다.'),
  (null, 'tenping', 'blog_top',             '이 글에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'tenping', 'video_description',    '이 영상에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'tenping', 'video_pinned_comment', '이 영상에는 텐핑 제휴 링크가 포함되어 있으며, 링크를 통한 참여·구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'blog_top',             '이 글에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'video_description',    '이 영상에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.'),
  (null, 'naver_shopping_connect', 'video_pinned_comment', '이 영상에는 네이버쇼핑 커넥트 제휴 링크가 포함되어 있으며, 구매 시 일정액의 수수료를 제공받습니다.')
on conflict (provider, placement) where org_id is null do update
  set body = excluded.body;

-- ---------------------------------------------------------------------
-- AI 제공자, 모델 단가, 플랫폼 기본 라우팅 (0008, 0009). 모든 단가는 제안값이다.
-- 상용/오픈소스 이원화: LLM(Claude, ChatGPT, Gemini, OpenRouter / vLLM), 임베딩(Voyage / 오픈소스),
-- 음성(ElevenLabs / 공용 GPU 음성 서버). model '*' = 그 제공자의 기본 단가. 구체 모델 단가는 구현 시 추가한다.
-- ---------------------------------------------------------------------
insert into core.ai_providers (id, name, source, kinds, cross_border, notes) values
  ('anthropic',  'Anthropic Claude',          'commercial',  array['llm'],        true,  '국외 이전 고지 대상'),
  ('openai',     'OpenAI ChatGPT',            'commercial',  array['llm'],        true,  '국외 이전 고지 대상'),
  ('google',     'Google Gemini',             'commercial',  array['llm'],        true,  '국외 이전 고지 대상'),
  ('openrouter', 'OpenRouter',                'commercial',  array['llm'],        true,  '대체 경로. 국외 이전 고지 대상'),
  ('oss-llm',    '오픈소스 LLM 서버(vLLM)',     'open_source', array['llm'],        false, '공용 GPU 서버. 상업 이용 가능 라이선스 모델만 등록'),
  ('voyage',     'Voyage AI',                 'commercial',  array['embedding'],  true,  '기본 임베딩. 국외 이전 고지 대상'),
  ('oss-embed',  '오픈소스 임베딩',              'open_source', array['embedding'],  false, '민감 데이터 컬렉션용'),
  ('elevenlabs', 'ElevenLabs',                'commercial',  array['stt', 'tts'], true,  'TypeScript SDK, Next.js 서버에서만 호출. 국외 이전 고지 대상'),
  ('oss-voice',  '오픈소스 음성 서버',           'open_source', array['stt', 'tts'], false, 'faster-whisper + 상업 이용 가능 TTS')
on conflict (id) do update
  set name = excluded.name, source = excluded.source, kinds = excluded.kinds,
      cross_border = excluded.cross_border, notes = excluded.notes;

insert into core.ai_model_prices (provider_id, model, kind, unit, credits_per_unit, license) values
  ('anthropic',  '*', 'llm',       '1k_input_tokens',  1.0000, null),
  ('anthropic',  '*', 'llm',       '1k_output_tokens', 4.0000, null),
  ('openai',     '*', 'llm',       '1k_input_tokens',  1.0000, null),
  ('openai',     '*', 'llm',       '1k_output_tokens', 4.0000, null),
  ('google',     '*', 'llm',       '1k_input_tokens',  1.0000, null),
  ('google',     '*', 'llm',       '1k_output_tokens', 4.0000, null),
  ('openrouter', '*', 'llm',       '1k_input_tokens',  1.0000, null),
  ('openrouter', '*', 'llm',       '1k_output_tokens', 4.0000, null),
  ('oss-llm',    '*', 'llm',       '1k_input_tokens',  0.2000, '모델별 확인'),
  ('oss-llm',    '*', 'llm',       '1k_output_tokens', 0.5000, '모델별 확인'),
  ('voyage',     '*', 'embedding', '1k_tokens',        0.0500, null),
  ('oss-embed',  '*', 'embedding', '1k_tokens',        0.0100, '모델별 확인'),
  ('elevenlabs', '*', 'stt',       'minute',           3.0000, null),
  ('elevenlabs', '*', 'tts',       '1k_characters',    5.0000, null),
  ('oss-voice',  '*', 'stt',       'minute',           0.5000, 'faster-whisper MIT'),
  ('oss-voice',  '*', 'tts',       '1k_characters',    1.0000, '모델별 확인')
on conflict (provider_id, model, kind, unit) do update
  set credits_per_unit = excluded.credits_per_unit, license = excluded.license;

-- 플랫폼 기본 라우팅(org 없음, 앱 없음). 제품은 기능별 기본값을 자기 seed나 운영 화면에서 추가한다.
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, null, '*', 'llm',       'auto',       '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, null, '*', 'embedding', 'commercial', '[{"provider":"voyage","model":"*"},{"provider":"oss-embed","model":"*"}]', false),
  (null, null, '*', 'stt',       'auto',       '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, null, '*', 'tts',       'auto',       '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;
