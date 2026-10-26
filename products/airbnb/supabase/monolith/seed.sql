-- =====================================================================
-- seed.sql (airbnb 모놀리스)
-- apps 1행 + 플랜. 금액과 한도의 정본은 docs/products/airbnb/01_PRD.md 4장이다(모두 제안).
-- 베타 기간에는 free 만 is_active=true. host_plus 는 Phase 2(Toss 정기결제) 때 is_active 를 켠다.
-- 크레딧은 AI·음성 선차감과 정산에만 쓴다(01_PRD.md 4.2절). 검색·예약·리뷰·찜은 크레딧을 쓰지 않는다.
--   free: 가입 크레딧 100(1회, 월 지급 없음). host_plus: 월 500(제안). 크레딧팩은 Phase 2 결제와 함께(01_PRD.md D5).
-- AI·음성 기능별 라우팅 기본값과 체인 검사는 파일 끝에 있다.
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('stay', 'Stay', 'stay', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('stay', 'free',      'Free(베타)', 0,     'none',  0,   100, false,
   '{"max_listings": 3, "photos_per_listing": 30, "ai_chat": true, "ai_chat_turns_per_day": 50, "search_assist": true, "search_assist_per_day": 30, "listing_assist": true, "listing_assist_runs_per_day": 10, "review_summary": true, "voice_chat": true, "host_wiki": true, "host_wiki_max_docs": 10, "co_hosts": 0}',
   true, true, 0),
  ('stay', 'host_plus', 'Host Plus',  14900, 'month', 500, 0,   false,
   '{"max_listings": 20, "photos_per_listing": 30, "ai_chat": true, "ai_chat_turns_per_day": 200, "search_assist": true, "search_assist_per_day": 100, "listing_assist": true, "listing_assist_runs_per_day": 50, "review_summary": true, "voice_chat": true, "host_wiki": true, "host_wiki_max_docs": 100, "co_hosts": 3}',
   false, false, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값. 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
-- 게스트가 쓴 리뷰 원문을 입력으로 받는 stay.review_summary 와 Dify 보조(dify.aux)는 오픈소스 강제다(01_PRD 6.1절).
-- 숙소 공개 정보 임베딩(stay.knowledge)은 비용 때문에 오픈소스 기본이지만 강제는 아니다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'stay', 'chat',                 'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'stay', 'stay.search_parse',    'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stay', 'stay.listing_assist',  'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'stay', 'stay.review_summary',  'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'stay', 'stay.knowledge',       'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'stay', 'wiki.query',           'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stay', 'wiki.ingest',          'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stay', 'wiki.lint',            'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stay', 'dify.aux',             'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'stay', 'voice_chat',           'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'stay', 'voice_chat',           'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
  where s.org_id is null and s.app_id = 'stay'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'stay routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
