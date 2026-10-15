-- =====================================================================
-- seed.sql (모놀리스 book-trailer)
-- 앱 레지스트리 1행(가입 트리거는 apps 가 1개면 자동 부트스트랩), 플랜 free/creator/publisher, 크레딧팩, 기능별 AI 라우팅 기본값.
-- 금액·크레딧·features 는 전부 제안값이며 정본은 01_PRD.md 4장이다. 반복 실행 가능.
-- 장르 문법·템플릿·runtime_config 카탈로그는 0002_trailer_domain.sql 11절에 있다(설정 데이터라 마이그레이션과 함께 간다).
-- 아래 플랜·크레딧팩·라우팅 블록은 모듈러 2600_trailer.sql 의 @monolith-seed 블록을 public 으로 변환한 것이다.
-- =====================================================================

insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('trailer', 'NOMAD Book Trailer', 'public', 'open', 'beta')
on conflict (id) do update
  set name = excluded.name, schema_name = excluded.schema_name, signup_policy = excluded.signup_policy, status = excluded.status;

-- @monolith-seed-begin (모놀리스 변환 시 이 표시부터 @monolith-seed-end 까지는 seed.sql 이 소유한다)
-- =====================================================================
-- 12. 플랜·크레딧팩(01_PRD 4장, 전부 제안). 모듈러 seed.sql 에 trailer 행이 들어오기 전(코어 요청 R-T1)에도 가입이 되도록
--     do nothing 으로 넣는다. seed.sql 이 나중에 같은 키로 upsert 하면 그 값이 최종이다. 가격은 VAT 포함(B2C SaaS).
-- =====================================================================
insert into public.plans (app_id, code, name, description, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('trailer', 'free', 'Free', '30초 세로 트레일러 1편 체험', 0, 'month', 0, 60, false,
   '{"max_books": 1, "max_trailers_per_book": 1, "formats": ["vertical_9_16"], "max_resolution": "720p", "max_duration_s": 30, "watermark": true, "brand_kits_max": 1, "members_max": 1, "approval_links": false, "priority_render": false, "premium_templates": false, "music_upload": false, "sns_upload": false, "flora_import": false, "ai_chat": true, "ai_chat_turns_per_day": 20, "voice_chat": true, "storage_mb": 300}',
   true, true, 0),
  ('trailer', 'creator', 'Creator', '작가·1인 출판사', 29000, 'month', 800, 0, false,
   '{"max_books": 10, "max_trailers_per_book": 5, "formats": ["vertical_9_16", "landscape_16_9", "square_1_1", "portrait_4_5", "cover_loop"], "max_resolution": "1080p", "max_duration_s": 90, "watermark": false, "brand_kits_max": 5, "members_max": 1, "approval_links": false, "priority_render": false, "premium_templates": true, "music_upload": true, "sns_upload": true, "flora_import": true, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "storage_mb": 5000}',
   false, true, 1),
  ('trailer', 'publisher', 'Publisher', '출판사·에이전시 팀', 99000, 'month', 3000, 0, false,
   '{"max_books": 100, "max_trailers_per_book": 20, "formats": ["vertical_9_16", "landscape_16_9", "square_1_1", "portrait_4_5", "cover_loop"], "max_resolution": "1080p", "max_duration_s": 90, "watermark": false, "brand_kits_max": 30, "members_max": 5, "approval_links": true, "priority_render": true, "premium_templates": true, "music_upload": true, "sns_upload": true, "flora_import": true, "ai_chat": true, "ai_chat_turns_per_day": 500, "voice_chat": true, "storage_mb": 30000}',
   false, true, 2)
on conflict (app_id, code) do nothing;

-- 기존 features 가 비어 있는(다른 경로로 먼저 만들어진) 행만 채운다. 값이 있으면 건드리지 않는다(반복 실행 가능).
update public.plans p
   set features = v.f::jsonb
  from (values
    ('free',      '{"max_books": 1, "max_trailers_per_book": 1, "formats": ["vertical_9_16"], "max_resolution": "720p", "max_duration_s": 30, "watermark": true, "brand_kits_max": 1, "members_max": 1, "approval_links": false, "priority_render": false, "premium_templates": false, "music_upload": false, "sns_upload": false, "flora_import": false, "ai_chat": true, "ai_chat_turns_per_day": 20, "voice_chat": true, "storage_mb": 300}'),
    ('creator',   '{"max_books": 10, "max_trailers_per_book": 5, "formats": ["vertical_9_16", "landscape_16_9", "square_1_1", "portrait_4_5", "cover_loop"], "max_resolution": "1080p", "max_duration_s": 90, "watermark": false, "brand_kits_max": 5, "members_max": 1, "approval_links": false, "priority_render": false, "premium_templates": true, "music_upload": true, "sns_upload": true, "flora_import": true, "ai_chat": true, "ai_chat_turns_per_day": 200, "voice_chat": true, "storage_mb": 5000}'),
    ('publisher', '{"max_books": 100, "max_trailers_per_book": 20, "formats": ["vertical_9_16", "landscape_16_9", "square_1_1", "portrait_4_5", "cover_loop"], "max_resolution": "1080p", "max_duration_s": 90, "watermark": false, "brand_kits_max": 30, "members_max": 5, "approval_links": true, "priority_render": true, "premium_templates": true, "music_upload": true, "sns_upload": true, "flora_import": true, "ai_chat": true, "ai_chat_turns_per_day": 500, "voice_chat": true, "storage_mb": 30000}')
  ) as v(code, f)
 where p.app_id = 'trailer' and p.code = v.code and p.features = '{}'::jsonb;

insert into public.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
  ('trailer', 'pack_300',  '300 크레딧',   300,  11900, true, 1),
  ('trailer', 'pack_1000', '1,000 크레딧', 1000, 35000, true, 2),
  ('trailer', 'pack_3000', '3,000 크레딧', 3000, 95000, true, 3)
on conflict (app_id, code) do nothing;

-- =====================================================================
-- 13. AI·음성 기능별 라우팅 기본값 (org_id null, app_id 'trailer'). 정본 02_ARCHITECTURE.md 5.1절. 모든 값은 제안.
--     - trailer.digest     : 원고 전체를 장 단위로 요약(대량). 미출간 원고라 오픈소스 먼저, 동의 조직만 상용 대체.
--     - trailer.brief      : 훅·로그라인 카피 품질이 제품 핵심이라 Claude 먼저. 입력은 분석 결과(원고 전문 아님).
--     - trailer.storyboard : 장르 문법에 맞춘 장면 구성. 같은 이유로 Claude 먼저.
--     - trailer.prompt_en  : 장면 설명 → 영어 이미지 프롬프트(번역·정리). 오픈소스 먼저.
--     - trailer.meta       : 플랫폼별 제목·설명·해시태그. Claude 먼저.
--     - trailer.compliance : 금지 문구·스포일러 보조 판정. 규칙이 1차 방어라 오픈소스 먼저.
--     - chat               : 트레일러 코치(책 근거 Q&A). 한국어 품질 때문에 Claude 먼저.
--     - wiki.*             : 책 설정 위키(인물·장소·용어). 대량이라 오픈소스 먼저.
--     - dify.aux           : 조직을 알 수 없어 동의 확인 불가 → 오픈소스 강제.
--     - trailer.knowledge  : 책 원고 컬렉션 임베딩. 컬렉션마다 모델 고정 + 미출간 원고 → 국내 오픈소스 고정.
--     - voice_chat / dictation(stt), voice_chat(tts), narration(tts): VOICE_ARCHITECTURE 기본. narration 은 작업 도중 대체 금지
--       (금지는 체인이 아니라 packages/core-voice 어댑터가 feature=narration 에서 강제).
-- =====================================================================
insert into public.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'trailer', 'trailer.digest',     'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'trailer', 'trailer.brief',      'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'trailer', 'trailer.storyboard', 'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'trailer', 'trailer.prompt_en',  'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'trailer', 'trailer.meta',       'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'trailer', 'trailer.compliance', 'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'trailer', 'chat',               'llm',       'auto',        '[{"provider":"anthropic","model":"*"},{"provider":"openai","model":"*"},{"provider":"google","model":"*"},{"provider":"oss-llm","model":"*"}]', false),
  (null, 'trailer', 'wiki.ingest',        'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'trailer', 'wiki.query',         'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'trailer', 'wiki.lint',          'llm',       'auto',        '[{"provider":"oss-llm","model":"*"},{"provider":"anthropic","model":"*"}]', false),
  (null, 'trailer', 'dify.aux',           'llm',       'open_source', '[{"provider":"oss-llm","model":"*"}]', true),
  (null, 'trailer', 'trailer.knowledge',  'embedding', 'open_source', '[{"provider":"oss-embed","model":"*"}]', false),
  (null, 'trailer', 'voice_chat',         'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'trailer', 'dictation',          'stt',       'auto',        '[{"provider":"oss-voice","model":"*"},{"provider":"elevenlabs","model":"*"}]', false),
  (null, 'trailer', 'voice_chat',         'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false),
  (null, 'trailer', 'narration',          'tts',       'auto',        '[{"provider":"elevenlabs","model":"*"},{"provider":"oss-voice","model":"*"}]', false)
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
    where s.org_id is null and s.app_id = 'trailer'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'trailer routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
  if (select count(*) from public.ai_routing_settings s where s.org_id is null and s.app_id = 'trailer') <> 16 then
    raise exception 'trailer routing defaults: expected 16 rows';
  end if;
end $$;

-- @monolith-seed-end
