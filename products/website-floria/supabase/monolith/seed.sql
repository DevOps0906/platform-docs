-- =====================================================================
-- seed.sql (모놀리스, website-floria)
-- apps 1행 + 기본 플랜 1행 + AI·음성 라우팅 기본값 8행. 요금과 크레딧이 없는 제품이라 크레딧팩은 없다(01_PRD.md 4장).
-- 모듈러 seed(_supabase-modular/seed.sql)의 ('site', 'default') 행과 같은 값이다. 반복 실행 가능(upsert).
-- 사이트 등록(public.sites)은 seed가 아니라 provision_site(service_role)로 한다: org_id 가 가입 후에만 생기기 때문이다.
--   예) select public.provision_site('<org uuid>', 'floria', 'Floria', 'floria', array['https://floria.example'], 'studio@floria.example');
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('site', 'Website Floria', 'site', 'invite', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('site', 'default', 'Default', 0, 'none', 0, 0, false, '{}', true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 2200_site.sql 11절과 같은 값이다(이유도 그 절 주석).
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
-- 방문자 상담의 비용은 운영자 조직이 낸다(크레딧 없음). 방문자 한도는 라우팅이 아니라 Route Handler 가 강제한다.
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'site', 'site.consult',   'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'site', 'wiki.query',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'site', 'wiki.ingest',    'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'site', 'wiki.lint',      'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'site', 'dify.aux',       'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'site', 'site.knowledge', 'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'site', 'voice_consult',  'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'site', 'voice_consult',  'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
  where s.org_id is null and s.app_id = 'site'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'site routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
