-- =====================================================================
-- 0008_core_ai.sql
-- AI 계층 공용 테이블(확정 결정 13, 14, 17). 설계: _platform-core/AI_ARCHITECTURE.md, LLM_WIKI.md
--   - 제공자·모델·단가(상용/오픈소스 이원화), 조직별 라우팅 설정, 국외 이전 동의
--   - RAG: 컬렉션, 문서, 청크(pgvector), 조직·앱 필터를 강제하는 검색 RPC
--   - 제품 지식 위키(LLM Wiki): 페이지, 링크, 수정 이력, 개인정보 삭제 경로
--   - 채팅 대화(플랫폼 대화 id ↔ Dify 대화 매핑), 메시지, LangGraph 실행 기록
--   - LangGraph 체크포인트용 ai_runtime 스키마(라이브러리가 테이블을 만든다)
--
-- 원칙(0000~0007과 같음)
--   - 쓰기는 service_role(FastAPI, Next.js 서버)만. 사용자는 SELECT 정책만 받는다.
--   - 사용자에게 연 DEFINER 함수는 core.is_service_caller()로 호출자를 판정하고 역할 비교는 NULL-safe.
--   - 파일 끝에서 이 파일이 만든 함수의 PUBLIC EXECUTE를 회수한다.
--   - 조직 일관성: 하위 테이블은 (id, org_id) 복합 외래키로 상위와 같은 조직만 가리킨다.
--   - 임베딩 차원 1024는 제안값(Voyage 기본). 모델을 바꾸면 컬렉션 단위로 재색인한다.
-- 고문 검토(2026-10-13) 반영: 강제 범위 체인 필터, 체인 검증, 복합 FK, 방문자 키, 청크 직접 조회 차단,
--   국외 이전 동의, 위키 유래·낡음 표시와 개인정보 삭제, HNSW 반복 스캔.
-- 선행: 0000 ~ 0007
-- =====================================================================

create extension if not exists vector with schema extensions;

-- ---------------------------------------------------------------------
-- 1. 제공자, 모델 단가, 라우팅 설정, 조직 AI 설정(국외 이전 동의)
-- ---------------------------------------------------------------------
create table if not exists core.ai_providers (
  id            text primary key,                         -- anthropic, openai, google, openrouter, oss-llm, voyage, oss-embed, elevenlabs, oss-voice (hms는 hms-*)
  name          text not null,
  source        text not null constraint ai_providers_source_check check (source in ('commercial', 'open_source')),
  kinds         text[] not null,                          -- llm, embedding, stt, tts 중 지원 목록
  cross_border  boolean not null default false,           -- 국외 이전 여부(개인정보 처리방침 고지 대상)
  is_active     boolean not null default true,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint ai_providers_kinds_check check (kinds <@ array['llm', 'embedding', 'stt', 'tts']::text[] and cardinality(kinds) > 0),
  constraint ai_providers_oss_domestic_check check (source = 'commercial' or not cross_border)
);

create table if not exists core.ai_model_prices (
  id                uuid primary key default gen_random_uuid(),
  provider_id       text not null references core.ai_providers(id) on delete cascade,
  model             text not null default '*',            -- '*' = 그 제공자의 기본 단가
  kind              text not null constraint ai_model_prices_kind_check check (kind in ('llm', 'embedding', 'stt', 'tts')),
  unit              text not null constraint ai_model_prices_unit_check
                    check (unit in ('1k_input_tokens', '1k_output_tokens', '1k_tokens', 'minute', '1k_characters')),
  credits_per_unit  numeric(12, 4) not null constraint ai_model_prices_credits_check check (credits_per_unit >= 0),
  license           text,                                 -- 오픈소스 모델의 라이선스(상업 이용 가능 여부 확인 결과)
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (provider_id, model, kind, unit)
);

-- org_id null = 플랫폼 기본값, app_id null = 모든 앱, feature '*' = 앱의 기본값
create table if not exists core.ai_routing_settings (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid references core.organizations(id) on delete cascade,
  app_id             text references core.apps(id) on delete cascade,
  feature            text not null default '*' constraint ai_routing_settings_feature_check check (feature = lower(btrim(feature)) and feature <> ''),
  kind               text not null constraint ai_routing_settings_kind_check check (kind in ('llm', 'embedding', 'stt', 'tts')),
  mode               text not null default 'auto' constraint ai_routing_settings_mode_check check (mode in ('commercial', 'open_source', 'auto')),
  chain              jsonb not null default '[]'::jsonb,  -- [{"provider":"anthropic","model":"*"}, ...] 대체 순서
  force_open_source  boolean not null default false,      -- 민감 데이터: 상용 API로 보내지 않는다
  updated_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint ai_routing_settings_chain_check check (jsonb_typeof(chain) = 'array'),
  constraint ai_routing_settings_force_check check (not force_open_source or mode = 'open_source')
);
create unique index if not exists ai_routing_settings_scope_uniq
  on core.ai_routing_settings (coalesce(org_id::text, ''), coalesce(app_id, ''), feature, kind);

-- 조직 AI 설정: 국외 이전(상용 제공자) 동의. 동의가 없으면 라우터는 국외 제공자를 쓰지 않는다.
create table if not exists core.ai_org_settings (
  org_id               uuid primary key references core.organizations(id) on delete cascade,
  cross_border_ack_at  timestamptz,
  cross_border_notice  text,                              -- 동의한 고지문 버전
  ack_by               uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. RAG: 컬렉션, 문서, 청크
-- ---------------------------------------------------------------------
create table if not exists core.ai_collections (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  app_id              text not null references core.apps(id),
  kind                text not null constraint ai_collections_kind_check check (kind in ('rag', 'wiki')),
  name                text not null,
  embedding_provider  text not null references core.ai_providers(id),
  embedding_model     text not null,
  embedding_dim       integer not null default 1024 constraint ai_collections_dim_check check (embedding_dim = 1024),
  status              text not null default 'active' constraint ai_collections_status_check check (status in ('active', 'reindexing', 'archived')),
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (org_id, app_id, name),
  unique (id, org_id, app_id)
);

create table if not exists core.ai_documents (
  id             uuid primary key default gen_random_uuid(),
  collection_id  uuid not null,
  org_id         uuid not null references core.organizations(id) on delete cascade,
  app_id         text not null references core.apps(id),
  source_type    text not null constraint ai_documents_source_check check (source_type in ('upload', 'url', 'text', 'product', 'wiki')),
  title          text,
  storage_path   text,
  source_url     text,
  content_hash   text not null,
  mime           text,
  byte_size      bigint,
  status         text not null default 'pending'
                 constraint ai_documents_status_check check (status in ('pending', 'indexing', 'ready', 'failed', 'deleted')),
  contains_pii   boolean not null default false,          -- true면 오픈소스 임베딩·LLM만 허용(라우터가 강제)
  error          text,
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (collection_id, content_hash),
  unique (id, org_id, app_id, collection_id),
  foreign key (collection_id, org_id, app_id) references core.ai_collections(id, org_id, app_id) on delete cascade
);
create index if not exists ai_documents_org_idx on core.ai_documents (org_id, app_id, status);

create table if not exists core.ai_chunks (
  id             bigint generated always as identity primary key,
  document_id    uuid not null,
  collection_id  uuid not null,
  org_id         uuid not null references core.organizations(id) on delete cascade,
  app_id         text not null references core.apps(id),
  chunk_index    integer not null,
  content        text not null,
  token_count    integer,
  embedding      extensions.vector(1024) not null,
  metadata       jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  unique (document_id, chunk_index),
  foreign key (document_id, org_id, app_id, collection_id)
    references core.ai_documents(id, org_id, app_id, collection_id) on delete cascade
);
create index if not exists ai_chunks_scope_idx on core.ai_chunks (org_id, app_id, collection_id);
create index if not exists ai_chunks_embedding_hnsw on core.ai_chunks using hnsw (embedding extensions.vector_cosine_ops);

-- ---------------------------------------------------------------------
-- 3. 제품 지식 위키 (LLM Wiki)
-- ---------------------------------------------------------------------
create table if not exists core.wiki_pages (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  app_id               text not null references core.apps(id),
  collection_id        uuid references core.ai_collections(id) on delete set null,  -- 위키 페이지 임베딩 컬렉션(kind=wiki)
  slug                 text not null constraint wiki_pages_slug_check check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*(/[a-z0-9]+(-[a-z0-9]+)*)*$'),
  title                text not null,
  summary              text,
  body_md              text not null default '',
  page_type            text not null default 'topic' constraint wiki_pages_type_check check (page_type in ('index', 'topic', 'entity', 'concept', 'source', 'log')),
  version              integer not null default 1,
  status               text not null default 'published' constraint wiki_pages_status_check check (status in ('draft', 'published', 'archived')),
  last_editor          text not null default 'agent' constraint wiki_pages_editor_check check (last_editor in ('agent', 'user')),
  last_edited_by       uuid,
  source_document_ids  uuid[] not null default '{}',      -- 근거 원본(낡음 판정, 개인정보 유래 추적)
  derived_from_pii     boolean not null default false,    -- 개인정보 원본에서 유래하면 오픈소스로만 처리
  stale_since          timestamptz,                       -- lint가 원본보다 오래됐다고 판정한 시각
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (org_id, app_id, slug),
  unique (id, org_id)
);

create table if not exists core.wiki_links (
  org_id        uuid not null references core.organizations(id) on delete cascade,
  from_page_id  uuid not null,
  to_page_id    uuid not null,
  created_at    timestamptz not null default now(),
  primary key (from_page_id, to_page_id),
  constraint wiki_links_self_check check (from_page_id <> to_page_id),
  foreign key (from_page_id, org_id) references core.wiki_pages(id, org_id) on delete cascade,
  foreign key (to_page_id, org_id) references core.wiki_pages(id, org_id) on delete cascade
);

create table if not exists core.wiki_revisions (
  id                   bigint generated always as identity primary key,
  page_id              uuid not null,
  org_id               uuid not null references core.organizations(id) on delete cascade,
  version              integer not null,
  body_md              text not null,
  editor_kind          text not null constraint wiki_revisions_editor_check check (editor_kind in ('agent', 'user')),
  edited_by            uuid,
  reason               text,
  source_document_ids  uuid[] not null default '{}',
  created_at           timestamptz not null default now(),
  unique (page_id, version),
  foreign key (page_id, org_id) references core.wiki_pages(id, org_id) on delete cascade
);

-- ---------------------------------------------------------------------
-- 4. 채팅 대화(플랫폼 대화 id ↔ Dify 매핑), 메시지, LangGraph 실행 기록
--    Next.js가 대화를 시작할 때 이 행을 먼저 만들고, 플랫폼 대화 id와 dify_user를 Dify에 넘긴다.
--    FastAPI는 Dify가 보낸 (플랫폼 대화 id, dify_user)가 이 행과 일치할 때만 org를 확정한다.
-- ---------------------------------------------------------------------
create table if not exists core.ai_conversations (
  id                     uuid primary key default gen_random_uuid(),   -- 플랫폼 대화 id(Dify 입력 platform_conversation_id)
  org_id                 uuid not null references core.organizations(id) on delete cascade,
  app_id                 text not null references core.apps(id),
  user_id                uuid,                              -- 로그인 사용자
  visitor_key            text,                              -- 비로그인 방문자: 서버가 만든 쿠키 값의 해시
  dify_user              text not null,                     -- 서버가 만든 불투명 값. 클라이언트 입력 금지
  dify_conversation_id   text,                              -- 첫 응답 후 Next.js가 채운다
  channel                text not null default 'text' constraint ai_conversations_channel_check check (channel in ('text', 'voice')),
  status                 text not null default 'active' constraint ai_conversations_status_check check (status in ('active', 'closed')),
  title                  text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (app_id, dify_conversation_id),
  unique (id, org_id),
  constraint ai_conversations_owner_check check (user_id is not null or visitor_key is not null)
);
create index if not exists ai_conversations_user_idx on core.ai_conversations (org_id, user_id, updated_at desc);

create table if not exists core.ai_messages (
  id                bigint generated always as identity primary key,
  conversation_id   uuid not null,
  org_id            uuid not null references core.organizations(id) on delete cascade,
  role              text not null constraint ai_messages_role_check check (role in ('user', 'assistant', 'tool')),
  content           text not null,
  citations         jsonb not null default '[]'::jsonb,     -- [{"type":"chunk","id":..},{"type":"wiki","slug":..}]
  provider_id       text references core.ai_providers(id),
  model             text,
  input_tokens      integer not null default 0,
  output_tokens     integer not null default 0,
  credits           integer not null default 0,
  credit_ledger_id  bigint references core.credit_ledger(id),
  created_at        timestamptz not null default now(),
  foreign key (conversation_id, org_id) references core.ai_conversations(id, org_id) on delete cascade
);
create index if not exists ai_messages_conv_idx on core.ai_messages (conversation_id, id);

create table if not exists core.ai_runs (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  app_id            text not null references core.apps(id),
  graph             text not null,                          -- 예: astro.reading, blog.post_draft
  status            text not null default 'queued'
                    constraint ai_runs_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  input             jsonb not null default '{}'::jsonb,
  output            jsonb,
  error             text,
  provider_id       text references core.ai_providers(id),
  model             text,
  input_tokens      integer not null default 0,
  output_tokens     integer not null default 0,
  credits           integer not null default 0,
  credit_ledger_id  bigint references core.credit_ledger(id),
  job_id            uuid references core.jobs(id) on delete set null,
  trace_id          text,
  thread_id         text,                                   -- LangGraph 체크포인트 thread
  created_by        uuid,
  created_at        timestamptz not null default now(),
  started_at        timestamptz,
  finished_at       timestamptz,
  updated_at        timestamptz not null default now(),
  unique (id, org_id)
);
create index if not exists ai_runs_org_idx on core.ai_runs (org_id, app_id, created_at desc);

create table if not exists core.ai_run_steps (
  id           bigint generated always as identity primary key,
  run_id       uuid not null,
  org_id       uuid not null references core.organizations(id) on delete cascade,
  node         text not null,
  status       text not null constraint ai_run_steps_status_check check (status in ('running', 'succeeded', 'failed', 'skipped')),
  provider_id  text references core.ai_providers(id),
  model        text,
  tokens       integer not null default 0,
  detail       jsonb not null default '{}'::jsonb,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  foreign key (run_id, org_id) references core.ai_runs(id, org_id) on delete cascade
);

-- ai_usage(0003) 확장: 임베딩·음성 사용량과 제공자 구분, 실행 연결, 정산 상태
--   과금: 턴·실행 시작 때 예상 크레딧을 선차감(멱등 키 = conv:<id>:turn:<n> 등)하고,
--   실제 사용량을 기록한 뒤 차액을 정산한다. settled_at이 비어 있는 행은 정산 잡이 처리한다.
alter table core.ai_usage add column if not exists kind text not null default 'llm';
alter table core.ai_usage add column if not exists source text;
alter table core.ai_usage add column if not exists feature text;
alter table core.ai_usage add column if not exists audio_seconds numeric(10, 2);
alter table core.ai_usage add column if not exists characters integer;
alter table core.ai_usage add column if not exists run_id uuid;
alter table core.ai_usage add column if not exists conversation_id uuid;
alter table core.ai_usage add column if not exists settled_at timestamptz;
do $$ begin
  alter table core.ai_usage add constraint ai_usage_kind_check check (kind in ('llm', 'embedding', 'stt', 'tts', 'image'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table core.ai_usage add constraint ai_usage_source_check check (source is null or source in ('commercial', 'open_source'));
exception when duplicate_object then null; end $$;
create index if not exists ai_usage_unsettled_idx on core.ai_usage (created_at) where settled_at is null;

-- LangGraph 체크포인트: langgraph-checkpoint-postgres가 setup() 때 이 스키마에 표준 테이블을 만든다.
create schema if not exists ai_runtime;
revoke all on schema ai_runtime from public, anon, authenticated;
grant usage, create on schema ai_runtime to service_role;

-- ---------------------------------------------------------------------
-- 5. updated_at, 쓰기 보호, 위키 이력 불변
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['ai_providers', 'ai_model_prices', 'ai_routing_settings', 'ai_org_settings', 'ai_collections',
                           'ai_documents', 'wiki_pages', 'ai_conversations', 'ai_runs'] loop
    execute format('drop trigger if exists %1$s_set_updated_at on core.%1$s', t);
    execute format('create trigger %1$s_set_updated_at before update on core.%1$s for each row execute function core.set_updated_at()', t);
  end loop;
  foreach t in array array['ai_providers', 'ai_model_prices', 'ai_routing_settings', 'ai_org_settings', 'ai_collections',
                           'ai_documents', 'ai_chunks', 'wiki_pages', 'wiki_links', 'wiki_revisions', 'ai_conversations',
                           'ai_messages', 'ai_runs', 'ai_run_steps'] loop
    execute format('drop trigger if exists %1$s_guard_write on core.%1$s', t);
    execute format('create trigger %1$s_guard_write before insert or update or delete on core.%1$s for each row execute function core.guard_privileged_write()', t);
    execute format('alter table core.%s enable row level security', t);
  end loop;
end $$;

-- 위키 이력은 수정·삭제 불가. 예외: 조직 삭제(purge_organization)와 개인정보 삭제(purge_wiki_page)만
-- core.allow_purge를 켜고 service_role 세션에서 지운다.
create or replace function core.wiki_revisions_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and core.is_privileged_session() then
    return old;
  end if;
  raise exception 'wiki_revisions is append-only' using errcode = '42501';
end;
$$;
drop trigger if exists wiki_revisions_immutable on core.wiki_revisions;
create trigger wiki_revisions_immutable before update or delete on core.wiki_revisions
  for each row execute function core.wiki_revisions_immutable();

-- ---------------------------------------------------------------------
-- 6. 함수
-- ---------------------------------------------------------------------

-- 체인 정규화(내부용): 존재·활성·종류가 맞는 제공자만 남기고, 강제 시 오픈소스만, 국외 동의가 없으면 국외 제공자 제외
create or replace function core.ai_filter_chain(p_chain jsonb, p_kind text, p_force boolean, p_cross_border_ok boolean)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(e.item order by e.ord), '[]'::jsonb)
  from jsonb_array_elements(coalesce(p_chain, '[]'::jsonb)) with ordinality as e(item, ord)
  join core.ai_providers p on p.id = e.item ->> 'provider'
  where p.is_active
    and p_kind = any (p.kinds)
    and (not p_force or p.source = 'open_source')
    and (p_cross_border_ok or not p.cross_border);
$$;

-- 벡터 검색(service_role 전용): 조직·앱 필터를 항상 강제한다. 컬렉션을 주면 그 조직 소유인지 확인한다.
-- HNSW + 조직 필터에서 결과가 k보다 적게 나오는 문제를 줄이려고 반복 스캔을 켠다(pgvector 0.8 이상).
create or replace function core.match_ai_chunks(
  p_org_id         uuid,
  p_app_id         text,
  p_embedding      extensions.vector,
  p_k              integer default 8,
  p_collection_id  uuid default null,
  p_min_similarity real default 0
)
returns table (chunk_id bigint, document_id uuid, collection_id uuid, content text, metadata jsonb, similarity real)
language plpgsql
stable
security definer
set search_path = ''
set hnsw.ef_search = 100
set hnsw.iterative_scan = relaxed_order
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'match_ai_chunks: service_role only' using errcode = '42501';
  end if;
  if p_org_id is null or p_app_id is null then
    raise exception 'match_ai_chunks: org and app are required' using errcode = '22023';
  end if;
  if p_k is null or p_k < 1 or p_k > 50 then
    raise exception 'match_ai_chunks: k must be 1..50' using errcode = '22023';
  end if;
  if p_collection_id is not null and not exists (
    select 1 from core.ai_collections c where c.id = p_collection_id and c.org_id = p_org_id and c.app_id = p_app_id
  ) then
    raise exception 'match_ai_chunks: collection not in org/app' using errcode = '42501';
  end if;
  return query
    select ch.id, ch.document_id, ch.collection_id, ch.content, ch.metadata,
           (1 - (ch.embedding operator(extensions.<=>) p_embedding))::real as similarity
    from core.ai_chunks ch
    join core.ai_documents d on d.id = ch.document_id and d.org_id = ch.org_id and d.status = 'ready'
    where ch.org_id = p_org_id
      and ch.app_id = p_app_id
      and (p_collection_id is null or ch.collection_id = p_collection_id)
      and (1 - (ch.embedding operator(extensions.<=>) p_embedding)) >= p_min_similarity
    order by ch.embedding operator(extensions.<=>) p_embedding
    limit p_k;
end;
$$;

-- 유효 라우팅 계산(service_role 전용).
--   1) 가장 구체적인 설정(조직 > 플랫폼, 앱 > 전체, 기능 > '*')의 모드와 체인을 고른다.
--   2) 범위 안의 어떤 행이라도 force_open_source면 오픈소스로 강제하고 체인에서 상용 제공자를 뺀다.
--   3) 조직이 국외 이전에 동의하지 않았으면 국외 제공자를 체인에서 뺀다.
--   4) 걸러진 체인이 비면 플랫폼 기본 체인을 같은 규칙으로 걸러 쓴다. 그래도 비면 빈 체인(라우터는 실패 처리).
create or replace function core.resolve_ai_route(p_org_id uuid, p_app_id text, p_feature text, p_kind text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_feature text := lower(btrim(coalesce(p_feature, '*')));
  v_row     core.ai_routing_settings;
  v_force   boolean;
  v_ack     boolean;
  v_chain   jsonb;
  v_default jsonb;
begin
  if not core.is_privileged_session() then
    raise exception 'resolve_ai_route: service_role only' using errcode = '42501';
  end if;
  select * into v_row
  from core.ai_routing_settings s
  where s.kind = p_kind
    and (s.org_id = p_org_id or s.org_id is null)
    and (s.app_id = p_app_id or s.app_id is null)
    and (s.feature = v_feature or s.feature = '*')
  order by (s.org_id is not null) desc, (s.app_id is not null) desc, (s.feature <> '*') desc
  limit 1;

  select coalesce(bool_or(s.force_open_source), false) into v_force
  from core.ai_routing_settings s
  where s.kind = p_kind
    and (s.org_id = p_org_id or s.org_id is null)
    and (s.app_id = p_app_id or s.app_id is null)
    and (s.feature = v_feature or s.feature = '*');

  select exists (select 1 from core.ai_org_settings o where o.org_id = p_org_id and o.cross_border_ack_at is not null)
    into v_ack;

  v_chain := core.ai_filter_chain(v_row.chain, p_kind, v_force, v_ack);
  if jsonb_array_length(v_chain) = 0 then
    select s.chain into v_default from core.ai_routing_settings s
    where s.org_id is null and s.app_id is null and s.feature = '*' and s.kind = p_kind;
    v_chain := core.ai_filter_chain(v_default, p_kind, v_force, v_ack);
    if jsonb_array_length(v_chain) = 0 then
      select coalesce(jsonb_agg(jsonb_build_object('provider', p.id, 'model', '*') order by p.id), '[]'::jsonb) into v_chain
      from core.ai_providers p
      where p.is_active and p_kind = any (p.kinds) and p.source = 'open_source';
    end if;
  end if;

  return jsonb_build_object(
    'mode', case when v_force then 'open_source' else coalesce(v_row.mode, 'auto') end,
    'chain', v_chain,
    'force_open_source', v_force,
    'cross_border_ack', v_ack,
    'setting_id', v_row.id
  );
end;
$$;

-- 조직 라우팅 변경(owner/admin).
--   - 엔타이틀먼트가 있는 앱만, 기능 키는 소문자·공백 제거로 정규화
--   - 체인 제공자는 존재·활성·종류 일치, open_source 모드는 오픈소스 제공자만
--   - 국외 제공자를 체인에 넣으려면 조직의 국외 이전 동의가 먼저 있어야 한다(AI002)
--   - 플랫폼이 강제한 오픈소스 범위는 풀 수 없다(AI001)
create or replace function core.set_ai_routing(
  p_org_id uuid, p_app_id text, p_feature text, p_kind text, p_mode text,
  p_chain jsonb default '[]'::jsonb, p_force_open_source boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_feature text := lower(btrim(coalesce(p_feature, '*')));
  v_chain jsonb := coalesce(p_chain, '[]'::jsonb);
  v_platform_force boolean;
  v_bad integer;
begin
  if not core.is_service_caller() and not core.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'set_ai_routing: owner/admin only' using errcode = '42501';
  end if;
  if p_org_id is null or p_app_id is null or v_feature = '' then
    raise exception 'set_ai_routing: org, app and feature are required' using errcode = '22023';
  end if;
  if not core.is_service_caller() and not core.has_entitlement(p_org_id, p_app_id) then
    raise exception 'set_ai_routing: no entitlement for app %', p_app_id using errcode = '42501';
  end if;
  if p_mode not in ('commercial', 'open_source', 'auto') or p_kind not in ('llm', 'embedding', 'stt', 'tts') then
    raise exception 'set_ai_routing: invalid mode or kind' using errcode = '22023';
  end if;
  if jsonb_typeof(v_chain) <> 'array' then
    raise exception 'set_ai_routing: chain must be an array' using errcode = '22023';
  end if;
  select count(*) into v_bad
  from jsonb_array_elements(v_chain) e(item)
  left join core.ai_providers p on p.id = e.item ->> 'provider'
  where p.id is null or not p.is_active or not (p_kind = any (p.kinds))
     or ((p_mode = 'open_source' or p_force_open_source) and p.source <> 'open_source');
  if v_bad > 0 then
    raise exception 'set_ai_routing: chain has unknown, inactive, wrong-kind or non-open-source providers' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_chain) e(item)
    join core.ai_providers p on p.id = e.item ->> 'provider'
    where p.cross_border
  ) and not exists (
    select 1 from core.ai_org_settings o where o.org_id = p_org_id and o.cross_border_ack_at is not null
  ) then
    raise exception 'set_ai_routing: cross-border consent required' using errcode = 'AI002';
  end if;
  select coalesce(bool_or(s.force_open_source), false) into v_platform_force
  from core.ai_routing_settings s
  where s.org_id is null and s.kind = p_kind
    and (s.app_id = p_app_id or s.app_id is null)
    and (s.feature = v_feature or s.feature = '*');
  if v_platform_force and (p_mode <> 'open_source' or not coalesce(p_force_open_source, false)) then
    raise exception 'set_ai_routing: platform requires open_source for this scope' using errcode = 'AI001';
  end if;
  insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source, updated_by)
  values (p_org_id, p_app_id, v_feature, p_kind, p_mode, v_chain, coalesce(p_force_open_source, false), auth.uid())
  on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind)
  do update set mode = excluded.mode, chain = excluded.chain,
                force_open_source = excluded.force_open_source, updated_by = excluded.updated_by
  returning id into v_id;
  perform core.write_audit(p_org_id, 'ai.routing.set', 'ai_routing_setting', v_id::text, null,
                           jsonb_build_object('app', p_app_id, 'feature', v_feature, 'kind', p_kind, 'mode', p_mode,
                                              'force_open_source', p_force_open_source));
  return v_id;
end;
$$;

-- 국외 이전 동의 기록·철회(owner/admin). 철회하면 라우터는 국외 제공자를 즉시 빼고 쓴다.
create or replace function core.set_ai_cross_border_ack(p_org_id uuid, p_ack boolean, p_notice_version text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_service_caller() and not core.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'set_ai_cross_border_ack: owner/admin only' using errcode = '42501';
  end if;
  if p_ack and coalesce(btrim(p_notice_version), '') = '' then
    raise exception 'set_ai_cross_border_ack: notice version required' using errcode = '22023';
  end if;
  insert into core.ai_org_settings (org_id, cross_border_ack_at, cross_border_notice, ack_by)
  values (p_org_id, case when p_ack then now() end, case when p_ack then p_notice_version end, auth.uid())
  on conflict (org_id) do update
    set cross_border_ack_at = excluded.cross_border_ack_at,
        cross_border_notice = excluded.cross_border_notice,
        ack_by = excluded.ack_by;
  perform core.write_audit(p_org_id, case when p_ack then 'ai.cross_border.ack' else 'ai.cross_border.revoke' end,
                           'organization', p_org_id::text, null, jsonb_build_object('notice', p_notice_version));
end;
$$;

-- 위키 페이지 개인정보 삭제(service_role 전용): 페이지·링크·이력을 실제로 지운다. 평소 삭제는 status='archived'.
create or replace function core.purge_wiki_page(p_page_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  if not core.is_privileged_session() then
    raise exception 'purge_wiki_page: service_role only' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'purge_wiki_page: reason required' using errcode = '22023';
  end if;
  select org_id into v_org from core.wiki_pages where id = p_page_id;
  if v_org is null then
    return;
  end if;
  perform set_config('core.allow_purge', 'on', true);
  delete from core.wiki_pages where id = p_page_id;
  perform set_config('core.allow_purge', 'off', true);
  perform core.write_audit(v_org, 'ai.wiki.purge', 'wiki_page', p_page_id::text, null, jsonb_build_object('reason', p_reason));
end;
$$;

-- ---------------------------------------------------------------------
-- 7. 권한과 RLS 정책 (SELECT만)
--    ai_chunks는 사용자에게 열지 않는다(임베딩·원문 대량 조회 차단). 검색은 FastAPI가 RPC로만.
-- ---------------------------------------------------------------------
grant select on core.ai_providers, core.ai_model_prices to authenticated;
grant select on core.ai_routing_settings, core.ai_org_settings, core.ai_collections, core.ai_documents,
                core.wiki_pages, core.wiki_links, core.wiki_revisions,
                core.ai_conversations, core.ai_messages, core.ai_runs, core.ai_run_steps to authenticated;
revoke all on core.ai_chunks from anon, authenticated;

drop policy if exists ai_providers_select on core.ai_providers;
create policy ai_providers_select on core.ai_providers for select to authenticated using (is_active);
drop policy if exists ai_model_prices_select on core.ai_model_prices;
create policy ai_model_prices_select on core.ai_model_prices for select to authenticated using (is_active);
drop policy if exists ai_routing_settings_select on core.ai_routing_settings;
create policy ai_routing_settings_select on core.ai_routing_settings for select to authenticated
  using (org_id is null or core.is_org_member(org_id));
drop policy if exists ai_org_settings_select on core.ai_org_settings;
create policy ai_org_settings_select on core.ai_org_settings for select to authenticated
  using (core.is_org_member(org_id));

do $$
declare t text;
begin
  foreach t in array array['ai_collections', 'ai_documents', 'wiki_pages', 'wiki_links', 'wiki_revisions',
                           'ai_runs', 'ai_run_steps'] loop
    execute format('drop policy if exists %1$s_select on core.%1$s', t);
    execute format('create policy %1$s_select on core.%1$s for select to authenticated using (core.is_org_member(org_id))', t);
  end loop;
end $$;
drop policy if exists ai_chunks_select on core.ai_chunks;

-- 대화는 본인 것만 본다(같은 조직의 다른 멤버 대화, 방문자 대화는 보이지 않는다)
drop policy if exists ai_conversations_select on core.ai_conversations;
create policy ai_conversations_select on core.ai_conversations for select to authenticated
  using (user_id = auth.uid() and core.is_org_member(org_id));
drop policy if exists ai_messages_select on core.ai_messages;
create policy ai_messages_select on core.ai_messages for select to authenticated
  using (exists (select 1 from core.ai_conversations c
                 where c.id = conversation_id and c.user_id = auth.uid() and core.is_org_member(c.org_id)));

-- 함수 실행 권한: PUBLIC 회수 후 필요한 역할만
revoke execute on function core.ai_filter_chain(jsonb, text, boolean, boolean) from public, anon, authenticated;
revoke execute on function core.match_ai_chunks(uuid, text, extensions.vector, integer, uuid, real) from public, anon, authenticated;
revoke execute on function core.resolve_ai_route(uuid, text, text, text) from public, anon, authenticated;
revoke execute on function core.set_ai_routing(uuid, text, text, text, text, jsonb, boolean) from public, anon;
revoke execute on function core.set_ai_cross_border_ack(uuid, boolean, text) from public, anon;
revoke execute on function core.purge_wiki_page(uuid, text) from public, anon, authenticated;
revoke execute on function core.wiki_revisions_immutable() from public, anon, authenticated;
grant execute on function core.ai_filter_chain(jsonb, text, boolean, boolean) to service_role;
grant execute on function core.match_ai_chunks(uuid, text, extensions.vector, integer, uuid, real) to service_role;
grant execute on function core.resolve_ai_route(uuid, text, text, text) to service_role;
grant execute on function core.set_ai_routing(uuid, text, text, text, text, jsonb, boolean) to authenticated, service_role;
grant execute on function core.set_ai_cross_border_ack(uuid, boolean, text) to authenticated, service_role;
grant execute on function core.purge_wiki_page(uuid, text) to service_role;
