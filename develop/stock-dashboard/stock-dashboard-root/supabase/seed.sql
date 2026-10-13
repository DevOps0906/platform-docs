-- =====================================================================
-- seed.sql (stock-dashboard 모놀리스)
-- apps 1행, 플랜 3개(default, beta, pro), 종목 마스터 샘플. 반복 실행 가능(upsert).
-- 금액/크레딧 정본: docs/products/stock-dashboard/01_PRD.md 4장. 수치는 모두 "제안"이다.
-- 크레딧팩은 두지 않는다(AI 진단을 건별 판매하지 않음, 01_PRD 4장과 6장).
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('stock', 'Stock Dashboard', 'stock', 'invite', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- default: 가입 트리거가 부여. 기능 없음. 실제 접근은 beta_access(초대 수락)가 있어야 열린다.
-- beta  : 초대 수락 시 서버가 전환(04_API 3장). 무료, 월 300 크레딧(AI 진단 10cr x 30회).
-- pro   : 법률 검토와 유사투자자문업 판단 전까지 is_active = false. 결제 화면에 노출되지 않는다.
insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('stock', 'default', 'Default', 0, 'none', 0, 0, false, '{}', true, true, 0),
  ('stock', 'beta', 'Beta', 0, 'month', 300, 0, false,
   '{"ai_diagnosis_per_day": 10, "broker_connections_max": 2, "ai_modes": ["quality"], "ai_compare": false, "ideas": false, "leaderboard": false, "paper_orders": false, "history_days": 365, "ai_chat": true, "ai_chat_turns_per_day": 100, "ai_research_per_day": 20, "voice_chat": true, "briefing": true}',
   false, true, 1),
  ('stock', 'pro', 'Pro', 9900, 'month', 600, 0, false,
   '{"ai_diagnosis_per_day": 20, "broker_connections_max": 3, "ai_modes": ["fast", "quality"], "ai_compare": true, "ideas": true, "leaderboard": true, "paper_orders": true, "history_days": 730, "ai_chat": true, "ai_chat_turns_per_day": 200, "ai_research_per_day": 40, "voice_chat": true, "briefing": true}',
   false, false, 2)
on conflict (app_id, code) do update
  set name = excluded.name, price_krw = excluded.price_krw, billing_interval = excluded.billing_interval,
      monthly_credits = excluded.monthly_credits, signup_credits = excluded.signup_credits, carry_over = excluded.carry_over,
      features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active, sort_order = excluded.sort_order;

-- 종목 마스터 샘플(MockBroker 와 화면 개발용). 실데이터는 동기화 워커가 채운다. 시세 값은 넣지 않는다.
-- IDXKSP 는 코스피 지수의 내부 의사 코드(성과 평가 기준 지수, 01_PRD ST-F-013).
insert into public.instruments (symbol, name, market, sector) values
  ('005930', '삼성전자', 'KOSPI', '전기전자'),
  ('000660', 'SK하이닉스', 'KOSPI', '전기전자'),
  ('035420', 'NAVER', 'KOSPI', '서비스업'),
  ('005380', '현대차', 'KOSPI', '운수장비'),
  ('068270', '셀트리온', 'KOSPI', '의약품'),
  ('IDXKSP', '코스피 지수', 'INDEX', null)
on conflict (symbol) do update set name = excluded.name, market = excluded.market, sector = excluded.sector;

-- ---------------------------------------------------------------------
-- AI·음성 기능별 라우팅 기본값 (2026-10-13). 모듈러 1900_stock.sql 14.2절과 같은 값이다.
-- 제공자·단가·플랫폼 기본 라우팅 행은 0001_core_lite.sql SECTION 11 이 넣는다. 모든 값은 제안이다.
--   체인 제공자는 core.ai_providers 행이어야 하고 kind 가 맞아야 한다(아래 체인 검사). 정본 표는 02_ARCHITECTURE.md 5.1절.
--   - stock.research / chat : 공개 자료(공시·위키) 요약과 채팅. 품질 우선 Claude 먼저. 국외 이전 동의가 없는 조직은 resolve_ai_route 가 상용을 걸러 낸다.
--   - stock.diagnosis       : 포트폴리오 진단 설명(입력은 종목코드·비중%·손익률%·업종·재무지표만, 금액 원값·계좌번호·이름 없음). 오픈소스 강제 여부는 01_PRD 열린 결정 D-13.
--   - stock.advice_check    : 투자 권유 금지 검사의 LLM 판정 단계. 규칙 사전 단계는 LLM 이 아니다. 판정할 수 없으면 출력하지 않는다(fail-closed).
--   - wiki.*                : 운영자 조직의 용어 위키(개인정보 없음). 대량 처리라 오픈소스 먼저.
--   - dify.aux              : Dify 분류 노드. 조직을 알 수 없어 동의를 확인할 수 없으므로 오픈소스 강제.
--   - stock.knowledge       : 공시·위키 컬렉션 임베딩. 동의 없는 사용자의 질의도 같은 모델로 임베딩해야 하므로 오픈소스 임베딩으로 고정(모델을 바꾸면 재색인).
--   - voice_chat            : 음성 질의 STT 는 오픈소스 먼저, 답변 읽어 주기 TTS 는 ElevenLabs 먼저.
--   - briefing              : 브리핑 낭독 TTS. 한 브리핑은 한 제공자로만 만든다(작업 도중 대체 금지는 음성 어댑터가 강제한다).
-- ---------------------------------------------------------------------
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'stock', 'stock.research',     'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'stock', 'chat',               'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'stock', 'stock.diagnosis',    'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'stock', 'stock.advice_check', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stock', 'wiki.query',         'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stock', 'wiki.ingest',        'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stock', 'wiki.lint',          'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'stock', 'dify.aux',           'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'stock', 'stock.knowledge',    'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'stock', 'voice_chat',         'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'stock', 'voice_chat',         'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'stock', 'briefing',           'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
  where s.org_id is null and s.app_id = 'stock'
    and (p.id is null or not (s.kind = any (p.kinds))
         or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
  if v_bad is not null then
    raise exception 'stock routing defaults: invalid chain providers %', v_bad;
  end if;
end $$;
