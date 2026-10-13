-- =====================================================================
-- admin-suite / hms 모놀리스 seed.sql
-- apps 1행('hms', 초대제), 계약형 기본 플랜 1행(온라인 결제 없음, Toss 절 제거), 검사 카탈로그.
-- 검사 정상 범위는 Hospital/src/lib/lab-ranges.ts 를 그대로 옮겼다(임상 검증 필요, 01_PRD 8절).
-- 병원 워크스페이스는 프로비저닝 스크립트(service_role)가 만든다. 환자/진료 데이터는 seed 에 넣지 않는다.
-- =====================================================================
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('hms', 'Admin Suite Hospital', 'hms', 'invite', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('hms', 'contract', 'Contract', 0, 'none', 0, 0, false, '{"max_staff": 50, "phi_log_retention_days": 730, "export_xlsx": true, "ai_assistant": true, "ai_turns_per_day": 300, "ai_voice": true, "ai_docs_max": 1000, "ai_wiki": true}', true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active;

insert into public.lab_test_catalog (code, name, parameters) values
  ('CBC', 'CBC 혈액검사', '[
    {"key":"wbc","label":"WBC (백혈구)","unit":"x10^3/uL","min":4.0,"max":10.0},
    {"key":"rbc","label":"RBC (적혈구)","unit":"x10^6/uL","min":4.2,"max":5.4},
    {"key":"hgb","label":"HGB (헤모글로빈)","unit":"g/dL","min":12.0,"max":16.0},
    {"key":"hct","label":"HCT (헤마토크리트)","unit":"%","min":36.0,"max":48.0},
    {"key":"plt","label":"PLT (혈소판)","unit":"x10^3/uL","min":150,"max":400},
    {"key":"neut","label":"NEUT (호중구)","unit":"%","min":45.0,"max":75.0}]'),
  ('LFT', 'LFT 간기능', '[
    {"key":"alt","label":"ALT","unit":"U/L","min":7,"max":56},
    {"key":"ast","label":"AST","unit":"U/L","min":10,"max":40},
    {"key":"alp","label":"ALP","unit":"U/L","min":44,"max":147},
    {"key":"bilirubin","label":"총 빌리루빈","unit":"mg/dL","min":0.1,"max":1.2},
    {"key":"albumin","label":"알부민","unit":"g/dL","min":3.5,"max":5.0}]'),
  ('UA', '소변검사', '[
    {"key":"glucose","label":"포도당","unit":"mg/dL","min":0,"max":15},
    {"key":"protein","label":"단백질","unit":"mg/dL","min":0,"max":14},
    {"key":"ph","label":"pH","unit":"","min":4.5,"max":8.0}]')
on conflict (code) do update set name = excluded.name, parameters = excluded.parameters;

-- =====================================================================
-- AI·음성 기본값 (2026-10-13, 사용자 결정: hms 는 전용 서버만, 상용 API 없음, 공용 Dify 없음)
--   설계: docs/products/admin-suite/02_ARCHITECTURE.md 5.5절. 제공자 hms-llm, hms-embed, hms-voice 와 '*' 강제 행은 0001_core_lite.sql SECTION 11 이 넣는다.
--   여기서는 기능별 기본값을 같은 제공자로 명시한다(기능 키를 눈에 보이게 하고, 나중에 '*' 행이 바뀌어도 hms 가 공용 제공자로 새지 않게 하는 이중 잠금).
--   - 모든 행 mode = open_source, force_open_source = true. 체인은 hms 전용 제공자 1개이며 어떤 경우에도 공용 서버·상용 API 로 대체하지 않는다.
--   - dify.aux 행은 없다: hms 채팅은 공용 Dify 를 거치지 않는다(Next.js → FastAPI 직접).
--   - 임상 가이드라인과 운영 매뉴얼만 색인한다. 환자 식별정보(PHI)는 색인·질의 모두 금지(01_PRD 6.6절).
--   크레딧 차감은 쓰지 않는다. 한도는 plans.features(ai_*)와 레이트 리밋으로 건다(hms contract 플랜 features 는 위 plans 삽입에 포함).
-- =====================================================================
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'hms', 'admin.assistant', 'llm', 'open_source', '[{"provider":"hms-llm","model":"*"}]', true),
  (null, 'hms', 'wiki.query', 'llm', 'open_source', '[{"provider":"hms-llm","model":"*"}]', true),
  (null, 'hms', 'wiki.ingest', 'llm', 'open_source', '[{"provider":"hms-llm","model":"*"}]', true),
  (null, 'hms', 'wiki.lint', 'llm', 'open_source', '[{"provider":"hms-llm","model":"*"}]', true),
  (null, 'hms', 'admin.knowledge', 'embedding', 'open_source', '[{"provider":"hms-embed","model":"*"}]', true),
  (null, 'hms', 'voice_chat', 'stt', 'open_source', '[{"provider":"hms-voice","model":"*"}]', true),
  (null, 'hms', 'voice_chat', 'tts', 'open_source', '[{"provider":"hms-voice","model":"*"}]', true)
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
    where s.org_id is null and s.app_id = 'hms'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'hms routing defaults: invalid chain providers %', v_bad;
    end if;
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from public.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    where s.app_id = 'hms' and s.org_id is null and (e.item ->> 'provider') not like 'hms-%';
    if v_bad is not null then
      raise exception 'hms routing defaults: non hms-dedicated provider %', v_bad;
    end if;
  end if;
end $$;
