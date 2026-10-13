-- =====================================================================
-- seed.sql (live-poll 모놀리스)
-- apps 1행 + 플랜. 금액과 한도의 정본은 docs/products/live-poll/01_PRD.md 4장이다.
-- 베타 기간에는 free 만 is_active=true. pro/business 는 Phase 2(유료 전환) 때 is_active 를 켠다.
-- 크레딧: 2026-10-13부터 AI·음성 선차감과 정산에만 쓴다(01_PRD.md 4.2절). free 는 가입 크레딧 100(1회, 월 지급 없음),
--         pro 월 1,000, business 월 5,000 (모두 제안). 크레딧팩은 Phase 2 결제와 함께 정한다(01_PRD.md D11).
-- AI·음성 기능별 라우팅 기본값과 체인 검사는 파일 끝에 있다. 모듈러 1800_poll.sql 19절과 같은 값이다.
-- 플랫폼 기본 금칙어는 0002_poll_domain.sql 18절에 있다.
-- 반복 실행 가능(upsert).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status)
values ('poll', 'Live Poll', 'poll', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('poll', 'free',     'Free(베타)', 0,     'none',  0, 100, false,
   '{"max_participants": 100, "max_live_events": 1, "max_events": 50, "polls_per_event": 50, "qna": true, "export_csv": true, "overlay": true, "branding": true, "retention_days": 30, "team_members": 1, "ai_chat": true, "ai_chat_turns_per_day": 100, "voice_chat": true, "qna_assist": true, "qna_assist_runs_per_event": 5, "voice_question": true, "audience_voice_per_event": 20, "audience_voice_per_participant": 5, "event_wiki": true, "materials_max_docs": 10, "materials_max_mb": 20}',
   true, true, 0),
  ('poll', 'pro',      'Pro',        19900, 'month', 1000, 0, false,
   '{"max_participants": 1000, "max_live_events": 3, "max_events": -1, "polls_per_event": -1, "qna": true, "export_csv": true, "overlay": true, "branding": false, "retention_days": 365, "team_members": 1, "ai_chat": true, "ai_chat_turns_per_day": 300, "voice_chat": true, "qna_assist": true, "qna_assist_runs_per_event": 20, "voice_question": true, "audience_voice_per_event": 100, "audience_voice_per_participant": 10, "event_wiki": true, "materials_max_docs": 50, "materials_max_mb": 200}',
   false, false, 1),
  ('poll', 'business', 'Business',   59000, 'month', 5000, 0, false,
   '{"max_participants": 3000, "max_live_events": 10, "max_events": -1, "polls_per_event": -1, "qna": true, "export_csv": true, "overlay": true, "branding": false, "retention_days": 730, "team_members": 5, "ai_chat": true, "ai_chat_turns_per_day": 1000, "voice_chat": true, "qna_assist": true, "qna_assist_runs_per_event": 100, "voice_question": true, "audience_voice_per_event": 500, "audience_voice_per_participant": 20, "event_wiki": true, "materials_max_docs": 200, "materials_max_mb": 1000}',
   false, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 1800_poll.sql 19절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
-- 청중 원문(질문, 음성)을 입력으로 받는 poll.moderate, poll.summary, poll.knowledge, voice_question 은 오픈소스 강제다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'poll', 'chat',            'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'poll', 'poll.moderate',   'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'poll', 'poll.summary',    'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'poll', 'poll.knowledge',  'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', true),
  (null, 'poll', 'wiki.query',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'poll', 'wiki.ingest',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'poll', 'wiki.lint',       'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'poll', 'dify.aux',        'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'poll', 'voice_question',  'stt',       'open_source', '[{"provider":"oss-voice","model":"*"}]', true),
  (null, 'poll', 'voice_chat',      'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'poll', 'voice_chat',      'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'poll', 'qna_read_aloud',  'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
  where s.org_id is null and s.app_id = 'poll'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'poll routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
