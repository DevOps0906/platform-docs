-- =====================================================================
-- seed.sql (모놀리스, schema public) - microweb-studio
-- 선행: migrations/0001_core_lite.sql, migrations/0002_microweb_domain.sql
-- 앱 1행, 기본 플랜 1행, 셀프서비스 발행 크레딧팩(Phase 2 전까지 비활성), 포트폴리오 초안.
-- 금액과 크레딧은 01_PRD.md 4장의 "제안" 값이다. 확정되면 이 파일과 _supabase-modular/seed.sql 을 함께 갱신한다.
-- 템플릿 카탈로그 12행은 0002_microweb_domain.sql 19절에 있다(모듈러 조각과 같은 본문).
-- 반복 실행 가능(upsert).
-- =====================================================================

-- 초대제 베타(확정: 브리프 "invite-only beta"). core 부트스트랩은 'invite' 를 강제하지 않으므로
-- 실제 차단은 Supabase Auth 공개 가입 끄기 + public.studio_access 허용 목록이 한다(05_DATA_MODEL.md 3장).
insert into public.apps (id, name, schema_name, signup_policy, status)
values ('microweb', 'Microweb Studio', 'public', 'invite', 'beta')
on conflict (id) do update
  set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

-- 기본 플랜. 대행 단계에는 구독 과금이 없다(대행비는 production_orders, 셀프 발행은 크레딧팩).
-- features 키의 의미는 01_PRD.md 4장 표(AI·음성 키 8개는 2026-10-13 추가). 서버만 읽는다.
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over,
                          features, is_default, is_active, sort_order)
values ('microweb', 'free', 'Free', 0, 'none', 0, 0, false,
        '{"guestbook": true, "rsvp": true, "ai_greeting": true, "ai_greeting_per_site_30d": 300, "bgm_upload": true, "max_gallery_photos": 30, "max_hero_photos": 5, "custom_slug": true, "ai_copy": true, "ai_copy_runs_per_site_30d": 20, "ai_chat": true, "ai_chat_turns_per_day": 100, "voice_chat": true, "voice_greeting": true, "guestbook_voice": true, "guestbook_voice_per_site_30d": 100}',
        true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 셀프서비스 발행권(Phase 2). 1 크레딧 = 1,000원 기준(제안). 청첩장 발행 30, 돌잔치 20, 부고장 10 크레딧.
insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order)
values
  ('microweb', 'pack_30', '30 크레딧 (청첩장 1건)', 30, 30000, false, 1),
  ('microweb', 'pack_60', '60 크레딧 (청첩장 2건)', 60, 57000, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, credits = excluded.credits, price_krw = excluded.price_krw,
      is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 포트폴리오 초안: WebSite 저장소의 실제 사이트. 고객 게시 동의(client_permission_at)와 스크린샷(image_path)이
-- 들어오기 전에는 draft 로 두며, 체크 제약이 published 전환을 막는다(가짜 포트폴리오 금지, 01_PRD.md 6장).
insert into public.portfolio_items (slug, title, category, tier, industry, summary, status, sort_order)
values
  ('floria-botanic', 'Floria Botanic Architecture', 'website', 'basic', '플로럴 스튜디오', '원페이지 브랜드 사이트', 'draft', 1),
  ('floria-neo', 'Floria Neo', 'website', 'basic', '플로럴 스튜디오', '원페이지 브랜드 사이트', 'draft', 2),
  ('floria-neo-02', 'Floria NEO 02', 'website', 'pro', '플로럴 스튜디오', '다중 서브페이지 사이트', 'draft', 3),
  ('hanul-construction', '한울건설 브랜드 사이트', 'website', 'basic', '건설', '배경 영상과 스크롤 연출의 원페이지 사이트', 'draft', 4)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 1500_microweb.sql 20절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
--   microweb_guestbook_voice 는 하객 음성이라 오픈소스 강제(조직이 해제할 수 없다).
--   기능 키에 점(.) 대신 밑줄을 쓴 이유: 모듈러 → 모놀리스 변환기가 'microweb.' 접두사를 'public.' 으로 바꾸기 때문이다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'microweb', 'microweb_copy',            'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'microweb', 'microweb_greeting',        'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'microweb', 'chat',                     'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'microweb', 'wiki.query',               'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'microweb', 'wiki.ingest',              'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'microweb', 'wiki.lint',                'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'microweb', 'dify.aux',                 'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'microweb', 'microweb_knowledge',       'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'microweb', 'voice_chat',               'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'microweb', 'voice_chat',               'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'microweb', 'microweb_voice_greeting',  'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'microweb', 'microweb_guestbook_voice', 'stt',       'open_source', '[{"provider":"oss-voice","model":"*"}]', true)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 체인 검사: 존재하지 않거나 종류가 다른 제공자, 오픈소스 모드의 상용 제공자가 있으면 실패한다.
do $$
declare v_bad text;
begin
  select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
  from public.ai_routing_settings s
  cross join lateral jsonb_array_elements(s.chain) as e(item)
  left join public.ai_providers p on p.id = e.item ->> 'provider'
  where s.org_id is null and s.app_id = 'microweb'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'microweb routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
