-- =====================================================================
-- admin-suite / sms 모놀리스 seed.sql
-- apps 1행(id 'sms'), 플랜 2행. 크레딧팩 없음(SECTION 4 제거). 금액은 제안(01_PRD 4절).
-- 학교 워크스페이스는 프로비저닝 스크립트(service_role)가 만든다.
-- =====================================================================
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('sms', 'Admin Suite School', 'sms', 'invite', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('sms', 'default',  'Default',  0,     'none',  0, 0, false, '{"max_students": 100, "max_classes": 5, "export_xlsx": false, "attendance_trend_days": 31, "ai_assistant": true, "ai_turns_per_day": 30, "ai_turns_per_month": 100, "ai_commercial_turns_per_month": 0, "ai_voice": false, "ai_docs_max": 20, "ai_wiki": false}', true,  true, 0),
  ('sms', 'standard', 'Standard', 39000, 'month', 0, 0, false, '{"max_students": 1500, "max_classes": 60, "export_xlsx": true, "attendance_trend_days": 366, "ai_assistant": true, "ai_turns_per_day": 200, "ai_turns_per_month": 1500, "ai_commercial_turns_per_month": 300, "ai_voice": true, "ai_docs_max": 500, "ai_wiki": true}', false, true, 1)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- =====================================================================
-- AI·음성 기본값 (2026-10-13, 확정 결정 13~17). 모듈러 조각 7절과 같은 값
--   설계: docs/products/admin-suite/02_ARCHITECTURE.md 5절, 01_PRD.md 3.6~3.7절. 정본 규칙은 _platform-core/AI_ARCHITECTURE.md 4장, VOICE_ARCHITECTURE.md 3장.
--   모든 값은 제안이며 모듈러 조각(1600/1700)과 이 seed에서만 바꾼다(운영 화면에서 바꾸지 않는다).
--   - admin.assistant : 업무 어시스턴트 그래프(admin.assistant). 기본 체인은 Claude 먼저. 국외 이전 동의가 없는 조직은 resolve_ai_route 가 상용을 걸러 낸다.
--   - wiki.*          : 기관 운영 위키(규정·매뉴얼 정리). 대량 처리라 오픈소스 먼저.
--   - dify.aux        : Dify 보조 LLM 노드. 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--   - admin.knowledge : 사내 규정·매뉴얼 컬렉션 임베딩. 질의와 문서가 같은 모델이어야 하고 동의 여부와 무관해야 하므로 국내 오픈소스 고정.
--   - voice_chat      : 업무 음성 질의. 내부 업무 내용이라 STT, TTS 모두 오픈소스 먼저(ElevenLabs 는 국외 이전 동의 후 대체).
--   크레딧 차감(consume_credits)은 쓰지 않는다. 한도는 plans.features(ai_*)와 레이트 리밋으로 건다.
-- =====================================================================
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'sms', 'admin.assistant', 'llm', 'auto', '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'sms', 'wiki.query', 'llm', 'auto', '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'sms', 'wiki.ingest', 'llm', 'auto', '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'sms', 'wiki.lint', 'llm', 'auto', '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'sms', 'dify.aux', 'llm', 'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'sms', 'admin.knowledge', 'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'sms', 'voice_chat', 'stt', 'auto', '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'sms', 'voice_chat', 'tts', 'auto', '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;

-- AI 문서 원본 버킷: 사용자 정책을 일부러 만들지 않는다(service_role 만 접근).
-- org-files 는 같은 조직 구성원이면 읽을 수 있어, 역할별 공개 범위(audience)가 있는 규정 문서가 새어 나갈 수 있기 때문이다.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ai-docs', 'ai-docs', false, 20971520,
        array['text/plain', 'text/markdown', 'application/pdf',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do nothing;

-- 체인 검사: 제공자 행이 있을 때만 존재·종류·오픈소스 모드를 확인한다.
do $$
declare v_bad text;
begin
  if exists (select 1 from public.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from public.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join public.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'sms'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'sms routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
end $$;
