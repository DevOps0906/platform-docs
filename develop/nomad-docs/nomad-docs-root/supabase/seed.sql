-- =====================================================================
-- seed.sql (모놀리스 nomad-docs)
-- 앱 레지스트리 1행(가입 트리거는 apps 가 1개면 자동 부트스트랩), 플랜 free/pro/team, 크레딧팩, 기능별 AI 라우팅 기본값.
-- 금액·크레딧·features 는 전부 제안값이며 정본은 01_PRD.md 4장이다. 반복 실행 가능.
-- 문서 유형·체크리스트·표준 조항·runtime_config 카탈로그는 0002_nomad_docs_domain.sql 말미에 있다
-- (설정 데이터이므로 마이그레이션과 함께 간다. 모듈러 2300_docs.sql 25절과 같은 값).
-- 아래 플랜·크레딧팩·라우팅 블록은 모듈러 2300_docs.sql 의 @monolith-seed 블록을 public 으로 변환한 것이다.
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('docs', 'NOMAD Docs', 'public', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- @monolith-seed-begin (모놀리스 변환 시 이 표시부터 @monolith-seed-end 까지는 seed.sql 이 소유한다)
-- 플랜(01_PRD 4장, 기준서 10장, 전부 제안). 모듈러 seed.sql 에 docs 행이 들어오기 전(코어 요청 C-3)에도 가입이 되도록
-- do nothing 으로 넣는다. seed.sql 이 나중에 같은 키로 upsert 하면 그 값이 최종이다.
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('docs', 'free', 'Free', 0, 'month', 30, 50, false,
   '{"projects_max": 2, "formats": ["pdf"], "watermark": true, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 30, "minutes_max_minutes": 30, "storage_mb": 200}',
   true, true, 0),
  ('docs', 'pro', 'Pro', 19900, 'month', 400, 0, false,
   '{"projects_max": 50, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv", "webhook"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 200, "minutes_max_minutes": 120, "storage_mb": 5000}',
   false, true, 1),
  ('docs', 'team', 'Team', 59000, 'month', 1500, 0, false,
   '{"projects_max": null, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "phase2", "members_max": 5, "integrations": ["csv", "webhook", "hubspot", "admin_suite_erp", "make", "n8n"], "approvals": true, "share_links": true, "ai_chat_turns_per_day": 500, "minutes_max_minutes": 180, "storage_mb": 20000}',
   false, false, 2)
on conflict (app_id, code) do nothing;

-- 기존 features 가 비어 있는(다른 경로로 먼저 만들어진) 행만 채운다. 값이 있으면 건드리지 않는다(반복 실행 가능).
update public.plans p
   set features = v.f::jsonb
  from (values
    ('free', '{"projects_max": 2, "formats": ["pdf"], "watermark": true, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 30, "minutes_max_minutes": 30, "storage_mb": 200}'),
    ('pro',  '{"projects_max": 50, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv", "webhook"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 200, "minutes_max_minutes": 120, "storage_mb": 5000}')
  ) as v(code, f)
 where p.app_id = 'docs' and p.code = v.code and p.features = '{}'::jsonb;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('docs', 'pack_100',  '100 크레딧',   100,  4900,  true, 1),
  ('docs', 'pack_300',  '300 크레딧',   300,  12900, true, 2),
  ('docs', 'pack_1000', '1,000 크레딧', 1000, 39000, true, 3)
on conflict (app_id, code) do nothing;

-- ---------------------------------------------------------------------
-- 26. AI·음성 기능별 라우팅 기본값 (org_id null, app_id 'docs'). 정본 02_ARCHITECTURE.md 5장. 모든 값은 제안.
--     - docs.extract : 고객 RFP 기밀성 때문에 오픈소스 먼저.
--     - docs.minutes : 회의 전사본에 제3자 발언이 담기므로 오픈소스 강제(조정 2026-10-13, 기준서 9장의 auto 체인에서 변경).
--     - dify.aux     : 조직을 알 수 없어 국외 이전 동의를 확인할 수 없으므로 오픈소스 강제.
--     - docs.knowledge(embedding): 컬렉션 임베딩 모델 고정, 국내 오픈소스.
--     - meeting_minutes(stt): 제3자 음성, 오픈소스 강제.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'docs', 'docs.generate',   'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'docs', 'docs.assist',     'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'docs', 'docs.extract',    'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"google","model":"*"}]', false),
  (null, 'docs', 'docs.minutes',    'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'docs', 'chat',            'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"}]', false),
  (null, 'docs', 'wiki.ingest',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'docs', 'wiki.query',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'docs', 'wiki.lint',       'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'docs', 'dify.aux',        'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'docs', 'docs.knowledge',  'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'docs', 'meeting_minutes', 'stt',       'open_source', '[{"provider":"oss-voice","model":"*"}]', true),
  (null, 'docs', 'voice_chat',      'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'docs', 'voice_chat',      'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- 체인 검사: 제공자 행이 있을 때만(seed 전에 적용되는 배포 순서에서도 실패하지 않게) 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from public.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from public.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join public.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'docs'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'docs routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
  if (select count(*) from public.ai_routing_settings s where s.org_id is null and s.app_id = 'docs') <> 13 then
    raise exception 'docs routing defaults: expected 13 rows';
  end if;
end $$;

