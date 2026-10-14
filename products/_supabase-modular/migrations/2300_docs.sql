-- =====================================================================
-- 2300_docs.sql
-- NOMAD Docs(실무 문서 자동 생성) 도메인. 선행: core 0000~0009, seed.sql
-- 정본 설계: docs/products/nomad-docs/05_DATA_MODEL.md
-- 모놀리스 변환본: docs/products/nomad-docs/supabase/monolith/migrations/0002_nomad_docs_domain.sql
--   (이 파일에서 create schema 블록을 빼고 core. / docs. 를 public. 으로 바꾼 것과 같은 본문)
--
-- 원칙 (SECURITY_BASELINE.md, DB_CONVENTIONS.md)
--   - 정본 데이터(프로필·체크리스트 답·요구사항·산출물·비용 항목·거래처)는 member 이상이 직접 쓴다.
--     단, 상태·번호·금액·결과 컬럼은 컬럼 GRANT(1차) + guard 트리거(2차) + RPC/service_role 로만 바뀐다.
--   - 문서(documents)는 title 만 사용자가 고친다. 버전(document_versions)은 append-only 이며 서버만 쓴다.
--   - 크레딧 선차감 + 실행 기록 + 잡 enqueue 는 service_role 전용 start_generation 한 트랜잭션.
--   - authenticated 에 EXECUTE 를 연 DEFINER 함수는 is_service_caller() + has_org_role 검사를 쓴다.
--   - 자식 테이블은 (parent_id, org_id) 복합 FK 로 상위와 같은 조직만 가리킨다(다른 조직 라벨 금지, 23503).
--   - 숫자(금액·합계·요구사항 번호·문서번호)는 DB 가 계산한다. LLM 은 읽기만 한다(FortuneDocs·SellingDocs 교훈).
--   - 어떤 테이블에도 토큰·API 키·주민등록번호 컬럼이 없다. 자격증명은 core.encrypted_credentials 참조만.
-- SQLSTATE: DC001 상태 전이 위반, DC002 같은 문서(패키지) 생성 진행 중, DC003 확정·불변 데이터 수정,
--           DC004 필수 입력 누락, DC005 compliance FAIL/lint 오류, DC006 플랜 한도, DC007 고위험 고지 미동의,
--           DC008 WARN 미확인 확정, DC009 연동 연결 상태 불가, DC010 버전 충돌
-- =====================================================================

create schema if not exists docs;
grant usage on schema docs to anon, authenticated, service_role;
alter default privileges in schema docs grant all on tables to service_role;
alter default privileges in schema docs grant all on sequences to service_role;
alter default privileges in schema docs grant execute on functions to service_role;
alter default privileges in schema docs revoke execute on functions from public;
-- 주의: 위 줄은 PostgreSQL 전역 기본 PUBLIC EXECUTE 를 없애지 못한다. 파일 끝에서 schema 전체 회수를 한다.

insert into core.apps (id, name, schema_name, signup_policy, status)
values ('docs', 'NOMAD Docs', 'docs', 'open', 'beta')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 0. 공용 트리거 함수: 플랫폼 카탈로그 행의 불변성(게시 뒤), 조직 열 고정
-- ---------------------------------------------------------------------
-- 게시된 doc_type_versions 는 변경·삭제 불가(DC003). 정본 구조가 바뀌면 새 버전 행을 만든다.
create or replace function docs.doc_type_versions_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if old.published_at is not null then
      raise exception 'doc_type_versions: published version is immutable' using errcode = 'DC003';
    end if;
    return old;
  end if;
  if old.published_at is not null then
    -- 게시 뒤 허용되는 변경: retired_at 설정(비활성화)만
    if (new.doc_type_code, new.version, new.structure, new.required_fields, new.lint_rules, new.template_ref, new.checksum, new.published_at)
       is distinct from
       (old.doc_type_code, old.version, old.structure, old.required_fields, old.lint_rules, old.template_ref, old.checksum, old.published_at) then
      raise exception 'doc_type_versions: published version is immutable' using errcode = 'DC003';
    end if;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. 카탈로그(플랫폼 공통, org 없음): doc_types, doc_type_versions, checklist_items, clauses
--    쓰기는 service_role(운영자 카탈로그 관리 DC-F-040)만. 엔타이틀먼트가 있는 사용자는 읽기.
-- ---------------------------------------------------------------------
create table if not exists docs.doc_types (
  code             text primary key constraint doc_types_code_check check (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name             text not null,
  category         text not null constraint doc_types_category_check
                   check (category in ('sales', 'dev', 'contract', 'ops', 'business', 'hr', 'legal')),
  risk_level       text not null default 'low' constraint doc_types_risk_check check (risk_level in ('low', 'high')),
  generation_mode  text not null constraint doc_types_mode_check check (generation_mode in ('template', 'hybrid', 'ai')),
  phase            text not null default 'mvp' constraint doc_types_phase_check check (phase in ('mvp', 'phase2', 'phase3')),
  credits          integer not null constraint doc_types_credits_check check (credits between 0 and 100),
  in_package       text[] not null default '{}',                 -- 포함되는 패키지 code 목록(예: outsourcing_basic)
  package_order    integer,                                     -- 패키지 생성 순서(의존)
  number_prefix    text not null default 'DOC' constraint doc_types_prefix_check check (number_prefix ~ '^[A-Z]{2,5}$'),  -- 문서번호 {TYPE}(01_PRD 3.6)
  notice_version   text,                                        -- 고위험 유형의 현재 고지문 버전(risk_acknowledgements 와 대조)
  is_active        boolean not null default true,
  sort_order       integer not null default 100,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- 고위험 유형은 MVP 에서 template 만 허용한다(AI 가 조항을 쓰지 않는다)
  constraint doc_types_high_risk_template_check check (risk_level = 'low' or generation_mode = 'template'),
  constraint doc_types_high_risk_notice_check check (risk_level = 'low' or notice_version is not null)
);
drop trigger if exists doc_types_set_updated_at on docs.doc_types;
create trigger doc_types_set_updated_at before update on docs.doc_types
  for each row execute function core.set_updated_at();
drop trigger if exists doc_types_guard_write on docs.doc_types;
create trigger doc_types_guard_write before insert or update or delete on docs.doc_types
  for each row execute function core.guard_privileged_write();
alter table docs.doc_types enable row level security;
revoke all on docs.doc_types from public, anon, authenticated;
grant select on docs.doc_types to authenticated;
drop policy if exists doc_types_select on docs.doc_types;
create policy doc_types_select on docs.doc_types for select to authenticated
  using (exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs')));

create table if not exists docs.doc_type_versions (
  id               uuid primary key default gen_random_uuid(),
  doc_type_code    text not null references docs.doc_types(code) on delete cascade,
  version          integer not null constraint doc_type_versions_version_check check (version >= 1),
  structure        jsonb not null default '[]'::jsonb,           -- [{key,title,kind: fixed|variable|ai|table, ...}]
  required_fields  text[] not null default '{}',
  lint_rules       jsonb not null default '[]'::jsonb,
  template_ref     text,                                        -- 저장소 템플릿 경로(templates/<code>/v<n>.html.j2)
  checksum         text,                                        -- 템플릿 파일 sha256
  published_at     timestamptz,                                 -- null = 초안(운영자 편집 가능)
  retired_at       timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (doc_type_code, version),
  constraint doc_type_versions_structure_check check (jsonb_typeof(structure) = 'array'),
  constraint doc_type_versions_lint_check check (jsonb_typeof(lint_rules) = 'array')
);
create index if not exists doc_type_versions_published_idx on docs.doc_type_versions (doc_type_code, version desc)
  where published_at is not null and retired_at is null;
drop trigger if exists doc_type_versions_set_updated_at on docs.doc_type_versions;
create trigger doc_type_versions_set_updated_at before update on docs.doc_type_versions
  for each row execute function core.set_updated_at();
drop trigger if exists doc_type_versions_guard_write on docs.doc_type_versions;
create trigger doc_type_versions_guard_write before insert or update or delete on docs.doc_type_versions
  for each row execute function core.guard_privileged_write();
drop trigger if exists doc_type_versions_immutable on docs.doc_type_versions;
create trigger doc_type_versions_immutable before update or delete on docs.doc_type_versions
  for each row execute function docs.doc_type_versions_immutable();
alter table docs.doc_type_versions enable row level security;
revoke all on docs.doc_type_versions from public, anon, authenticated;
grant select on docs.doc_type_versions to authenticated;
drop policy if exists doc_type_versions_select on docs.doc_type_versions;
create policy doc_type_versions_select on docs.doc_type_versions for select to authenticated
  using (published_at is not null
         and exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs')));

create table if not exists docs.checklist_items (
  key          text primary key constraint checklist_items_key_check check (key ~ '^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$'),
  group_key    text not null constraint checklist_items_group_check
               check (group_key in ('profile', 'project_type', 'feature', 'nfr', 'delivery', 'contract_terms')),
  label        text not null,
  help         text,
  input_type   text not null constraint checklist_items_input_check
               check (input_type in ('boolean', 'single', 'multi', 'number', 'text', 'date', 'money')),
  options      jsonb not null default '[]'::jsonb,
  effects      jsonb not null default '[]'::jsonb,              -- 결정적 효과 엔진 입력: [{when, create: requirement|artifact|line_item|clause, ...}]
  applies_to   text[] not null default '{}',                    -- 비면 전체 project_type
  is_required  boolean not null default false,
  version      integer not null default 1,
  is_active    boolean not null default true,
  sort_order   integer not null default 100,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint checklist_items_options_check check (jsonb_typeof(options) = 'array'),
  constraint checklist_items_effects_check check (jsonb_typeof(effects) = 'array')
);
drop trigger if exists checklist_items_set_updated_at on docs.checklist_items;
create trigger checklist_items_set_updated_at before update on docs.checklist_items
  for each row execute function core.set_updated_at();
drop trigger if exists checklist_items_guard_write on docs.checklist_items;
create trigger checklist_items_guard_write before insert or update or delete on docs.checklist_items
  for each row execute function core.guard_privileged_write();
alter table docs.checklist_items enable row level security;
revoke all on docs.checklist_items from public, anon, authenticated;
grant select on docs.checklist_items to authenticated;
drop policy if exists checklist_items_select on docs.checklist_items;
create policy checklist_items_select on docs.checklist_items for select to authenticated
  using (exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs')));

-- 체크리스트 항목 버전 관리(교차검증 #6, 2026-10-14). 효과·선택지·입력 형식·적용 유형·필수 여부가 바뀌면
-- version 이 오르고 그 내용이 checklist_item_versions 에 불변으로 남는다. version 은 운영자도 직접 정하지 않는다.
-- checklist_answers_hash 가 답한 항목의 version 을 포함하므로, 미리보기와 적용 사이에 카탈로그가 바뀌면 DC010 이다.
create table if not exists docs.checklist_item_versions (
  key          text not null,
  version      integer not null constraint checklist_item_versions_version_check check (version >= 1),
  label        text not null,
  input_type   text not null,
  options      jsonb not null,
  effects      jsonb not null,
  applies_to   text[] not null,
  is_required  boolean not null,
  captured_at  timestamptz not null default now(),
  primary key (key, version)
);

create or replace function docs.checklist_item_bump_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.version := 1;
  elsif (new.effects, new.options, new.input_type, new.applies_to, new.is_required)
        is distinct from (old.effects, old.options, old.input_type, old.applies_to, old.is_required) then
    new.version := old.version + 1;
  else
    new.version := old.version;
  end if;
  return new;
end;
$$;
drop trigger if exists checklist_items_bump_version on docs.checklist_items;
create trigger checklist_items_bump_version before insert or update on docs.checklist_items
  for each row execute function docs.checklist_item_bump_version();

create or replace function docs.checklist_item_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into docs.checklist_item_versions (key, version, label, input_type, options, effects, applies_to, is_required)
  values (new.key, new.version, new.label, new.input_type, new.options, new.effects, new.applies_to, new.is_required)
  on conflict (key, version) do nothing;
  return null;
end;
$$;
revoke execute on function docs.checklist_item_snapshot() from public, anon, authenticated;
drop trigger if exists checklist_items_snapshot on docs.checklist_items;
create trigger checklist_items_snapshot after insert or update on docs.checklist_items
  for each row execute function docs.checklist_item_snapshot();

create or replace function docs.checklist_item_versions_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'checklist_item_versions is append-only (%)', tg_op using errcode = 'DC003';
end;
$$;
drop trigger if exists checklist_item_versions_immutable on docs.checklist_item_versions;
create trigger checklist_item_versions_immutable before update or delete on docs.checklist_item_versions
  for each row execute function docs.checklist_item_versions_immutable();
alter table docs.checklist_item_versions enable row level security;
revoke all on docs.checklist_item_versions from public, anon, authenticated;
grant select on docs.checklist_item_versions to authenticated;
drop policy if exists checklist_item_versions_select on docs.checklist_item_versions;
create policy checklist_item_versions_select on docs.checklist_item_versions for select to authenticated
  using (exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs')));

-- 조항 라이브러리. org_id null = 플랫폼 표준(MVP), 값 있음 = 조직 맞춤(Phase 2, 쓰기 경로는 Phase 2 RPC 로 추가)
create table if not exists docs.clauses (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid references core.organizations(id) on delete cascade,
  code           text not null constraint clauses_code_check check (code ~ '^[a-z][a-z0-9_.]{1,60}$'),
  doc_type_code  text not null references docs.doc_types(code) on delete cascade,
  title          text not null,
  body_template  text not null,                                 -- {{var}} 치환. AI 가 수정하지 않는다
  variables      text[] not null default '{}',
  is_required    boolean not null default false,
  source_note    text,                                          -- 출처(표준계약서 원문 조항 번호 등, D-8)
  version        integer not null default 1,
  status         text not null default 'draft' constraint clauses_status_check check (status in ('draft', 'published', 'retired')),
  sort_order     integer not null default 100,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index if not exists clauses_platform_code_uniq on docs.clauses (doc_type_code, code, version) where org_id is null;
create unique index if not exists clauses_org_code_uniq on docs.clauses (org_id, doc_type_code, code, version) where org_id is not null;
drop trigger if exists clauses_set_updated_at on docs.clauses;
create trigger clauses_set_updated_at before update on docs.clauses
  for each row execute function core.set_updated_at();
drop trigger if exists clauses_guard_write on docs.clauses;
create trigger clauses_guard_write before insert or update or delete on docs.clauses
  for each row execute function core.guard_privileged_write();
alter table docs.clauses enable row level security;
revoke all on docs.clauses from public, anon, authenticated;
grant select on docs.clauses to authenticated;
drop policy if exists clauses_select on docs.clauses;
create policy clauses_select on docs.clauses for select to authenticated
  using (status = 'published'
         and ((org_id is null and exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs')))
              or (org_id is not null and core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'))));

-- ---------------------------------------------------------------------
-- 2. runtime_config: 운영 상한(동시 생성, 일일 크레딧 상한). 사용자는 접근 불가(정책 없음 = 전부 거부).
-- ---------------------------------------------------------------------
create table if not exists docs.runtime_config (
  key        text primary key,
  value_int  integer not null,
  note       text,
  updated_at timestamptz not null default now()
);
drop trigger if exists runtime_config_set_updated_at on docs.runtime_config;
create trigger runtime_config_set_updated_at before update on docs.runtime_config
  for each row execute function core.set_updated_at();
drop trigger if exists runtime_config_guard_write on docs.runtime_config;
create trigger runtime_config_guard_write before insert or update or delete on docs.runtime_config
  for each row execute function core.guard_privileged_write();
alter table docs.runtime_config enable row level security;
revoke all on docs.runtime_config from public, anon, authenticated;

-- 일일 플랫폼 크레딧 사용량(KST 날짜). 생성·추출·회의록·채팅·색인·내보내기 등 docs 의 모든 차감이
-- start_generation 또는 reserve_credits 를 거치며 같은 트랜잭션에서 더한다(교차검증 #11). 환불은 빼지 않는다(보수적 상한).
create table if not exists docs.daily_credit_usage (
  day      date primary key,
  credits  bigint not null default 0 constraint daily_credit_usage_credits_check check (credits >= 0)
);
alter table docs.daily_credit_usage enable row level security;
revoke all on docs.daily_credit_usage from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. workspace_settings: 조직당 1행. owner/admin 이 컬럼 GRANT 범위 안에서 쓴다.
--    자사 정보는 parties.kind='self' 행이다(여기엔 서식·기본값만).
-- ---------------------------------------------------------------------
create table if not exists docs.workspace_settings (
  org_id               uuid primary key references core.organizations(id) on delete cascade,
  doc_number_format    text not null default '{TYPE}-{YYYY}-{SEQ:4}'
                       constraint workspace_settings_number_format_check check (doc_number_format like '%{SEQ%' and char_length(doc_number_format) <= 60
                              -- 유형 토큰과 연도 토큰이 모두 있어야 유형 간·연도 간 번호가 겹치지 않는다(교차검증 #10)
                              and (doc_number_format like '%{TYPE}%' or doc_number_format like '%{PREFIX}%')
                              and (doc_number_format like '%{YYYY}%' or doc_number_format like '%{YY}%')),
  default_day_rate_krw bigint not null default 0 constraint workspace_settings_day_rate_check check (default_day_rate_krw >= 0),
  vat_rate_bp          integer not null default 1000 constraint workspace_settings_vat_check check (vat_rate_bp between 0 and 10000),
  seal_image_path      text constraint workspace_settings_seal_path_check check (seal_image_path is null or seal_image_path ~ '^[0-9a-f-]{36}/docs/seal/[0-9a-f-]{36}\.(png|webp)$'),
  defaults             jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
drop trigger if exists workspace_settings_set_updated_at on docs.workspace_settings;
create trigger workspace_settings_set_updated_at before update on docs.workspace_settings
  for each row execute function core.set_updated_at();
alter table docs.workspace_settings enable row level security;
revoke all on docs.workspace_settings from public, anon, authenticated;
grant select on docs.workspace_settings to authenticated;
grant insert (org_id, doc_number_format, default_day_rate_krw, vat_rate_bp, seal_image_path, defaults) on docs.workspace_settings to authenticated;
grant update (doc_number_format, default_day_rate_krw, vat_rate_bp, seal_image_path, defaults) on docs.workspace_settings to authenticated;
drop policy if exists workspace_settings_select on docs.workspace_settings;
create policy workspace_settings_select on docs.workspace_settings for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists workspace_settings_insert on docs.workspace_settings;
create policy workspace_settings_insert on docs.workspace_settings for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists workspace_settings_update on docs.workspace_settings;
create policy workspace_settings_update on docs.workspace_settings for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin']));

-- ---------------------------------------------------------------------
-- 4. parties: 당사자(자사·거래처·협력사·프리랜서). member 이상 쓰기. 주민등록번호 컬럼은 없다.
--    biz_reg_no 는 사업자등록번호(10자리)만 허용한다(13자리 고유식별정보 입력 차단).
-- ---------------------------------------------------------------------
create table if not exists docs.parties (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  kind            text not null constraint parties_kind_check check (kind in ('self', 'client', 'vendor', 'freelancer')),
  name            text not null constraint parties_name_check check (char_length(name) between 1 and 120),
  biz_reg_no      text constraint parties_biz_reg_no_check check (biz_reg_no is null or biz_reg_no ~ '^[0-9]{3}-?[0-9]{2}-?[0-9]{5}$'),
  representative  text,
  address         text,
  contact_name    text,
  contact_email   text constraint parties_contact_email_check check (contact_email is null or contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  contact_phone   text,
  notes           text,
  created_by      uuid default auth.uid(),
  deleted_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, org_id)
);
create index if not exists parties_org_kind_idx on docs.parties (org_id, kind, name) where deleted_at is null;
create unique index if not exists parties_one_self_uniq on docs.parties (org_id) where kind = 'self' and deleted_at is null;
drop trigger if exists parties_set_updated_at on docs.parties;
create trigger parties_set_updated_at before update on docs.parties
  for each row execute function core.set_updated_at();

-- 공용 2차 잠금: 사용자 세션은 org_id 와 created_by 를 바꾸지 못한다(여러 정본 테이블에 공유)
create or replace function docs.guard_org_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if core.is_privileged_session() then
    return new;
  end if;
  if new.org_id <> old.org_id or new.created_by is distinct from old.created_by then
    raise exception '%: org_id/created_by are immutable', tg_table_name using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists parties_guard_org on docs.parties;
create trigger parties_guard_org before update on docs.parties
  for each row execute function docs.guard_org_columns();

alter table docs.parties enable row level security;
revoke all on docs.parties from public, anon, authenticated;
grant select on docs.parties to authenticated;
grant insert (org_id, kind, name, biz_reg_no, representative, address, contact_name, contact_email, contact_phone, notes) on docs.parties to authenticated;
grant update (kind, name, biz_reg_no, representative, address, contact_name, contact_email, contact_phone, notes, deleted_at) on docs.parties to authenticated;
grant delete on docs.parties to authenticated;
drop policy if exists parties_select on docs.parties;
create policy parties_select on docs.parties for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists parties_insert on docs.parties;
create policy parties_insert on docs.parties for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists parties_update on docs.parties;
create policy parties_update on docs.parties for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists parties_delete on docs.parties;
create policy parties_delete on docs.parties for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- ---------------------------------------------------------------------
-- 5. projects: 프로젝트. member 이상 쓰기(status 제외: set_project_status RPC, DC001).
--    client_party_id 는 같은 조직의 parties 만(복합 FK).
-- ---------------------------------------------------------------------
create table if not exists docs.projects (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  client_party_id    uuid,
  name               text not null constraint projects_name_check check (char_length(name) between 1 and 160),
  code               text constraint projects_code_check check (code is null or code ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,29}$'),
  project_type       text not null default 'web' constraint projects_type_check check (project_type in ('web', 'app', 'ai', 'mixed', 'other', 'content')),  -- content: 숏폼 제작·채널 운영 대행(shorts_agency, Phase 2)
  status             text not null default 'draft' constraint projects_status_check check (status in ('draft', 'active', 'delivered', 'archived')),
  profile            jsonb not null default '{}'::jsonb,
  checklist_version  integer not null default 1,
  start_date         date,
  end_date           date,
  currency           text not null default 'KRW' constraint projects_currency_check check (currency = 'KRW'),
  created_by         uuid default auth.uid(),
  deleted_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (id, org_id),
  constraint projects_client_fk foreign key (client_party_id, org_id) references docs.parties (id, org_id) on delete set null (client_party_id),
  constraint projects_dates_check check (start_date is null or end_date is null or end_date >= start_date)
);
create unique index if not exists projects_org_code_uniq on docs.projects (org_id, code) where code is not null and deleted_at is null;
create index if not exists projects_org_status_idx on docs.projects (org_id, status, updated_at desc) where deleted_at is null;
drop trigger if exists projects_set_updated_at on docs.projects;
create trigger projects_set_updated_at before update on docs.projects
  for each row execute function core.set_updated_at();
drop trigger if exists projects_guard_org on docs.projects;
create trigger projects_guard_org before update on docs.projects
  for each row execute function docs.guard_org_columns();

-- 상태 전이(service_role 에도 적용): draft -> active | archived, active -> delivered | archived, delivered -> active | archived, archived -> active
create or replace function docs.check_project_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status = 'draft' and new.status in ('active', 'archived'))
         or (old.status = 'active' and new.status in ('delivered', 'archived'))
         or (old.status = 'delivered' and new.status in ('active', 'archived'))
         or (old.status = 'archived' and new.status = 'active')) then
      raise exception 'projects: invalid transition % -> %', old.status, new.status using errcode = 'DC001';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists projects_status_transition on docs.projects;
create trigger projects_status_transition before update of status on docs.projects
  for each row execute function docs.check_project_transition();

alter table docs.projects enable row level security;
revoke all on docs.projects from public, anon, authenticated;
grant select on docs.projects to authenticated;
grant insert (org_id, client_party_id, name, code, project_type, profile, start_date, end_date) on docs.projects to authenticated;
grant update (client_party_id, name, code, project_type, profile, start_date, end_date, deleted_at) on docs.projects to authenticated;
-- deleted_at(소프트 삭제·복구)은 owner/admin 만(교차검증 #9). 컬럼 GRANT 는 member 도 갖지만 트리거가 역할을 다시 본다.
grant delete on docs.projects to authenticated;
drop policy if exists projects_select on docs.projects;
create policy projects_select on docs.projects for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists projects_insert on docs.projects;
create policy projects_insert on docs.projects for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists projects_update on docs.projects;
create policy projects_update on docs.projects for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists projects_delete on docs.projects;
create policy projects_delete on docs.projects for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));

-- 플랜 한도(projects_max): INSERT 시 서버 트리거로 강제(DC006). 삭제·보관된 프로젝트는 세지 않는다.
create or replace function docs.org_features(p_org_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.features
    from core.app_entitlements e
    join core.plans p on p.id = e.plan_id
    where e.org_id = p_org_id and e.app_id = 'docs' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
  ), '{}'::jsonb);
$$;
revoke execute on function docs.org_features(uuid) from public, anon, authenticated;
grant execute on function docs.org_features(uuid) to service_role;

create or replace function docs.enforce_project_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_max integer; v_n integer;
begin
  if tg_op = 'UPDATE' then
    if new.deleted_at is distinct from old.deleted_at and not core.is_service_caller()
       and not core.has_org_role(new.org_id, array['owner', 'admin']) then
      raise exception 'projects: only owner/admin may delete or restore' using errcode = '42501';
    end if;
    -- 한도 검사는 "세지 않던 행이 다시 세어지는" 변경(복구, 보관 해제)에만 한다. 보관 해제는 set_project_status 경유.
    if not ((old.deleted_at is not null and new.deleted_at is null and new.status <> 'archived')
         or (old.status = 'archived' and new.status <> 'archived' and new.deleted_at is null)) then
      return new;
    end if;
  end if;
  -- 무제한 플랜은 features.projects_max 가 null(JSON null)이다. 키가 없으면 Free 값 2.
  if (docs.org_features(new.org_id) -> 'projects_max') = 'null'::jsonb then
    return new;
  end if;
  v_max := coalesce((docs.org_features(new.org_id) ->> 'projects_max')::integer, 2);
  select count(*) into v_n from docs.projects p
  where p.org_id = new.org_id and p.deleted_at is null and p.status <> 'archived' and p.id <> new.id;
  if v_n >= v_max then
    raise exception 'projects: plan limit reached (% of %)', v_n, v_max using errcode = 'DC006';
  end if;
  return new;
end;
$$;
drop trigger if exists projects_enforce_limit on docs.projects;
create trigger projects_enforce_limit before insert or update of deleted_at, status on docs.projects
  for each row execute function docs.enforce_project_limit();

-- ---------------------------------------------------------------------
-- 6. checklist_answers: PK(project_id, item_key). member 는 source='user' 행만 직접 쓴다.
--    extract/integration 후보(is_confirmed=false)는 서버가 넣고 confirm_checklist_suggestions RPC 로 확정한다.
-- ---------------------------------------------------------------------
create table if not exists docs.checklist_answers (
  project_id    uuid not null,
  org_id        uuid not null references core.organizations(id) on delete cascade,
  item_key      text not null references docs.checklist_items(key) on update cascade,
  value         jsonb not null default 'null'::jsonb,
  source        text not null default 'user' constraint checklist_answers_source_check check (source in ('user', 'extract', 'integration')),
  is_confirmed  boolean not null default true,
  answered_by   uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (project_id, item_key),
  constraint checklist_answers_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade
);
create index if not exists checklist_answers_org_idx on docs.checklist_answers (org_id);
create index if not exists checklist_answers_pending_idx on docs.checklist_answers (project_id) where not is_confirmed;
drop trigger if exists checklist_answers_set_updated_at on docs.checklist_answers;
create trigger checklist_answers_set_updated_at before update on docs.checklist_answers
  for each row execute function core.set_updated_at();

create or replace function docs.guard_checklist_answer_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if core.is_privileged_session() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.source <> 'user' or not new.is_confirmed then
      raise exception 'checklist_answers: only confirmed user answers may be inserted directly' using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' then
    if new.org_id <> old.org_id or new.project_id <> old.project_id
       or new.source <> 'user' or not new.is_confirmed then
      raise exception 'checklist_answers: source/is_confirmed are server-managed' using errcode = '42501';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
drop trigger if exists checklist_answers_guard_write on docs.checklist_answers;
create trigger checklist_answers_guard_write before insert or update or delete on docs.checklist_answers
  for each row execute function docs.guard_checklist_answer_write();

-- 답 값 형식 검사(교차검증 #13, 2026-10-14). 서버 zod 와 같은 규칙을 DB 에서도 강제한다. null = 미응답.
create or replace function docs.validate_checklist_answer()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_item docs.checklist_items; v_ok boolean;
begin
  if new.value = 'null'::jsonb then
    return new;
  end if;
  select * into v_item from docs.checklist_items i where i.key = new.item_key;
  v_ok := case v_item.input_type
    when 'boolean' then jsonb_typeof(new.value) = 'boolean'
    when 'number'  then jsonb_typeof(new.value) = 'number'
    when 'money'   then jsonb_typeof(new.value) = 'number' and (new.value #>> '{}')::numeric >= 0
    when 'text'    then jsonb_typeof(new.value) = 'string' and char_length(new.value #>> '{}') <= 2000
    when 'date'    then jsonb_typeof(new.value) = 'string' and (new.value #>> '{}') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    when 'single'  then jsonb_typeof(new.value) = 'string'
                        and (jsonb_array_length(v_item.options) = 0 or v_item.options @> jsonb_build_array(new.value))
    when 'multi'   then jsonb_typeof(new.value) = 'array'
                        and not exists (select 1 from jsonb_array_elements(new.value) x where jsonb_typeof(x) <> 'string')
                        and (jsonb_array_length(v_item.options) = 0 or v_item.options @> new.value)
    else false end;
  if not coalesce(v_ok, false) then
    raise exception 'checklist_answers: value does not match % item %', v_item.input_type, new.item_key using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists checklist_answers_validate on docs.checklist_answers;
create trigger checklist_answers_validate before insert or update of value on docs.checklist_answers
  for each row execute function docs.validate_checklist_answer();

alter table docs.checklist_answers enable row level security;
revoke all on docs.checklist_answers from public, anon, authenticated;
grant select on docs.checklist_answers to authenticated;
grant insert (project_id, org_id, item_key, value) on docs.checklist_answers to authenticated;
grant update (value, source, is_confirmed, answered_by) on docs.checklist_answers to authenticated;
grant delete on docs.checklist_answers to authenticated;
drop policy if exists checklist_answers_select on docs.checklist_answers;
create policy checklist_answers_select on docs.checklist_answers for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists checklist_answers_insert on docs.checklist_answers;
create policy checklist_answers_insert on docs.checklist_answers for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists checklist_answers_update on docs.checklist_answers;
create policy checklist_answers_update on docs.checklist_answers for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists checklist_answers_delete on docs.checklist_answers;
create policy checklist_answers_delete on docs.checklist_answers for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 7. 프로젝트 내 코드 자동 부여(FR-001 / NFR-001 / CON-001 / SCR-001 ...). 트리거가 프로젝트·접두사별 카운터를 올린다.
--    지운 번호는 다시 쓰지 않는다(교차검증 #8, 2026-10-14. 이전에는 현재 최대값 + 1 이라 마지막 번호가 재사용됐다).
--    사용자가 준 값은 무시한다(코드는 서버 계산).
-- ---------------------------------------------------------------------
create table if not exists docs.project_code_counters (
  project_id  uuid not null references docs.projects(id) on delete cascade,
  prefix      text not null constraint project_code_counters_prefix_check check (prefix ~ '^[A-Z]{2,4}$'),
  last_no     integer not null constraint project_code_counters_no_check check (last_no >= 1),
  primary key (project_id, prefix)
);
alter table docs.project_code_counters enable row level security;
revoke all on docs.project_code_counters from public, anon, authenticated;

-- requirements/artifacts 의 INVOKER 트리거가 사용자 세션에서 호출하므로 authenticated 에 EXECUTE 가 필요하다.
-- DEFINER 로 두어 RLS 와 무관하게 프로젝트 전체 번호를 보고, 비멤버의 직접 호출은 42501 로 막는다.
create or replace function docs.next_project_code(p_project_id uuid, p_table text, p_prefix text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_n integer;
begin
  if not core.is_service_caller()
     and not core.has_org_role((select p.org_id from docs.projects p where p.id = p_project_id), array['owner', 'admin', 'member']) then
    raise exception 'next_project_code: not a member' using errcode = '42501';
  end if;
  -- 사용자 세션은 트리거 안에서만 부를 수 있다(직접 호출로 카운터를 소모하지 못하게, 2026-10-14 검토)
  if not core.is_service_caller() and pg_trigger_depth() = 0 then
    raise exception 'next_project_code: trigger use only' using errcode = '42501';
  end if;
  if p_table not in ('requirements', 'artifacts') or p_prefix !~ '^[A-Z]{2,4}$' then
    raise exception 'next_project_code: invalid arguments' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('docs:code:' || p_project_id::text || ':' || p_prefix));
  -- 카운터가 없을 때(첫 번호, 또는 카운터 도입 전 행이 있는 프로젝트)는 현재 최대값 + 1 에서 시작한다.
  if p_table = 'requirements' then
    select coalesce(max(substring(r.req_code from '[0-9]+$')::integer), 0) + 1 into v_n
    from docs.requirements r where r.project_id = p_project_id and r.req_code like p_prefix || '-%';
  else
    select coalesce(max(substring(a.code from '[0-9]+$')::integer), 0) + 1 into v_n
    from docs.artifacts a where a.project_id = p_project_id and a.code like p_prefix || '-%';
  end if;
  insert into docs.project_code_counters (project_id, prefix, last_no) values (p_project_id, p_prefix, v_n)
  on conflict (project_id, prefix) do update
    set last_no = greatest(docs.project_code_counters.last_no + 1, excluded.last_no)
  returning last_no into v_n;
  return p_prefix || '-' || lpad(v_n::text, 3, '0');
end;
$$;

-- ---------------------------------------------------------------------
-- 8. requirements: 요구사항. member 이상 쓰기(req_code 제외). 상태는 CHECK 만(단순 분류, 전이 강제 없음).
-- ---------------------------------------------------------------------
create table if not exists docs.requirements (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  project_id           uuid not null,
  req_code             text not null,
  kind                 text not null default 'functional' constraint requirements_kind_check check (kind in ('functional', 'nonfunctional', 'constraint')),
  title                text not null constraint requirements_title_check check (char_length(title) between 1 and 200),
  description          text,
  priority             text not null default 'should' constraint requirements_priority_check check (priority in ('must', 'should', 'could', 'wont')),
  acceptance_criteria  text,
  source               text not null default 'manual' constraint requirements_source_check check (source in ('checklist', 'extract', 'manual', 'integration', 'minutes')),
  source_key           text,
  is_user_modified     boolean not null default false,
  status               text not null default 'proposed' constraint requirements_status_check check (status in ('proposed', 'accepted', 'rejected', 'changed')),
  sort_order           integer not null default 100,
  created_by           uuid default auth.uid(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (id, org_id),
  unique (project_id, req_code),
  constraint requirements_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade
);
create index if not exists requirements_project_idx on docs.requirements (project_id, kind, sort_order);
create index if not exists requirements_source_idx on docs.requirements (project_id, source, source_key) where source_key is not null;
drop trigger if exists requirements_set_updated_at on docs.requirements;
create trigger requirements_set_updated_at before update on docs.requirements
  for each row execute function core.set_updated_at();

create or replace function docs.requirements_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.req_code := docs.next_project_code(new.project_id, 'requirements',
                      case new.kind when 'functional' then 'FR' when 'nonfunctional' then 'NFR' else 'CON' end);
    if not core.is_privileged_session() then
      new.source := 'manual';
      new.source_key := null;
    end if;
    return new;
  end if;
  if new.req_code <> old.req_code or new.project_id <> old.project_id or new.kind <> old.kind then
    raise exception 'requirements: req_code/project_id/kind are immutable' using errcode = 'DC003';
  end if;
  if not core.is_privileged_session() then
    if new.org_id <> old.org_id or new.created_by is distinct from old.created_by
       or new.source <> old.source or new.source_key is distinct from old.source_key then
      raise exception 'requirements: org/source columns are server-managed' using errcode = '42501';
    end if;
    -- status 도 포함한다: 사용자가 직접 rejected 로 둔 엔진 행을 재적용이 accepted 로 되돌리지 않게(2026-10-14 검토)
    if (new.title, new.description, new.priority, new.acceptance_criteria, new.status) is distinct from
       (old.title, old.description, old.priority, old.acceptance_criteria, old.status) then
      new.is_user_modified := true;   -- 효과 엔진 재적용 시 사용자 수정분 보존(DC-F-006)
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists requirements_before_write on docs.requirements;
create trigger requirements_before_write before insert or update on docs.requirements
  for each row execute function docs.requirements_before_write();

alter table docs.requirements enable row level security;
revoke all on docs.requirements from public, anon, authenticated;
grant select on docs.requirements to authenticated;
grant insert (org_id, project_id, kind, title, description, priority, acceptance_criteria, status, sort_order) on docs.requirements to authenticated;
grant update (title, description, priority, acceptance_criteria, status, sort_order) on docs.requirements to authenticated;
grant delete on docs.requirements to authenticated;
drop policy if exists requirements_select on docs.requirements;
create policy requirements_select on docs.requirements for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists requirements_insert on docs.requirements;
create policy requirements_insert on docs.requirements for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists requirements_update on docs.requirements;
create policy requirements_update on docs.requirements for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists requirements_delete on docs.requirements;
create policy requirements_delete on docs.requirements for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 9. artifacts: 산출물 항목(화면, 마일스톤, 산출물, 테스트케이스·API·테이블은 Phase 2). code 는 트리거 부여.
-- ---------------------------------------------------------------------
create table if not exists docs.artifacts (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  project_id        uuid not null,
  kind              text not null constraint artifacts_kind_check check (kind in ('screen', 'milestone', 'deliverable', 'test_case', 'api', 'table')),
  code              text not null,
  name              text not null constraint artifacts_name_check check (char_length(name) between 1 and 200),
  attributes        jsonb not null default '{}'::jsonb,
  source            text not null default 'manual' constraint artifacts_source_check check (source in ('checklist', 'extract', 'manual', 'integration', 'minutes')),
  source_key        text,
  is_user_modified  boolean not null default false,
  sort_order        integer not null default 100,
  created_by        uuid default auth.uid(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  unique (project_id, code),
  constraint artifacts_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade
);
create index if not exists artifacts_project_idx on docs.artifacts (project_id, kind, sort_order);
drop trigger if exists artifacts_set_updated_at on docs.artifacts;
create trigger artifacts_set_updated_at before update on docs.artifacts
  for each row execute function core.set_updated_at();

create or replace function docs.artifacts_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.code := docs.next_project_code(new.project_id, 'artifacts',
                  case new.kind when 'screen' then 'SCR' when 'milestone' then 'MS' when 'deliverable' then 'DLV'
                                when 'test_case' then 'TC' when 'api' then 'API' else 'TBL' end);
    if not core.is_privileged_session() then
      new.source := 'manual';
      new.source_key := null;
    end if;
    return new;
  end if;
  if new.code <> old.code or new.project_id <> old.project_id or new.kind <> old.kind then
    raise exception 'artifacts: code/project_id/kind are immutable' using errcode = 'DC003';
  end if;
  if not core.is_privileged_session() then
    if new.org_id <> old.org_id or new.created_by is distinct from old.created_by
       or new.source <> old.source or new.source_key is distinct from old.source_key then
      raise exception 'artifacts: org/source columns are server-managed' using errcode = '42501';
    end if;
    if (new.name, new.attributes) is distinct from (old.name, old.attributes) then
      new.is_user_modified := true;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists artifacts_before_write on docs.artifacts;
create trigger artifacts_before_write before insert or update on docs.artifacts
  for each row execute function docs.artifacts_before_write();

alter table docs.artifacts enable row level security;
revoke all on docs.artifacts from public, anon, authenticated;
grant select on docs.artifacts to authenticated;
grant insert (org_id, project_id, kind, name, attributes, sort_order) on docs.artifacts to authenticated;
grant update (name, attributes, sort_order) on docs.artifacts to authenticated;
grant delete on docs.artifacts to authenticated;
drop policy if exists artifacts_select on docs.artifacts;
create policy artifacts_select on docs.artifacts for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists artifacts_insert on docs.artifacts;
create policy artifacts_insert on docs.artifacts for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists artifacts_update on docs.artifacts;
create policy artifacts_update on docs.artifacts for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists artifacts_delete on docs.artifacts;
create policy artifacts_delete on docs.artifacts for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 10. line_items: 비용 항목. amount_krw 는 생성 컬럼(수량 x 단가, 원 단위 반올림). 합계·VAT 는 뷰가 계산한다.
-- ---------------------------------------------------------------------
create table if not exists docs.line_items (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  project_id        uuid not null,
  category          text not null default 'dev' constraint line_items_category_check check (category in ('dev', 'design', 'pm', 'qa', 'infra', 'license', 'etc', 'production', 'channel_ops', 'media')),
  name              text not null constraint line_items_name_check check (char_length(name) between 1 and 200),
  unit              text not null default 'man_day' constraint line_items_unit_check check (unit in ('man_day', 'man_month', 'ea', 'lump', 'per_video', 'per_month', 'per_channel')),
  quantity          numeric(10, 2) not null default 1 constraint line_items_quantity_check check (quantity >= 0),
  unit_price_krw    bigint not null default 0 constraint line_items_unit_price_check check (unit_price_krw >= 0),
  amount_krw        bigint generated always as (round(quantity * unit_price_krw)::bigint) stored,
  source            text not null default 'manual' constraint line_items_source_check check (source in ('checklist', 'extract', 'manual', 'integration', 'minutes')),
  source_key        text,
  is_user_modified  boolean not null default false,
  sort_order        integer not null default 100,
  created_by        uuid default auth.uid(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  constraint line_items_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade
);
create index if not exists line_items_project_idx on docs.line_items (project_id, sort_order);
drop trigger if exists line_items_set_updated_at on docs.line_items;
create trigger line_items_set_updated_at before update on docs.line_items
  for each row execute function core.set_updated_at();

create or replace function docs.line_items_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not core.is_privileged_session() then
      new.source := 'manual';
      new.source_key := null;
    end if;
    return new;
  end if;
  if not core.is_privileged_session() then
    if new.org_id <> old.org_id or new.project_id <> old.project_id or new.created_by is distinct from old.created_by
       or new.source <> old.source or new.source_key is distinct from old.source_key then
      raise exception 'line_items: org/source columns are server-managed' using errcode = '42501';
    end if;
    if (new.name, new.category, new.unit, new.quantity, new.unit_price_krw) is distinct from
       (old.name, old.category, old.unit, old.quantity, old.unit_price_krw) then
      new.is_user_modified := true;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists line_items_before_write on docs.line_items;
create trigger line_items_before_write before insert or update on docs.line_items
  for each row execute function docs.line_items_before_write();

alter table docs.line_items enable row level security;
revoke all on docs.line_items from public, anon, authenticated;
grant select on docs.line_items to authenticated;
grant insert (org_id, project_id, category, name, unit, quantity, unit_price_krw, sort_order) on docs.line_items to authenticated;
grant update (category, name, unit, quantity, unit_price_krw, sort_order) on docs.line_items to authenticated;
grant delete on docs.line_items to authenticated;
drop policy if exists line_items_select on docs.line_items;
create policy line_items_select on docs.line_items for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists line_items_insert on docs.line_items;
create policy line_items_insert on docs.line_items for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists line_items_update on docs.line_items;
create policy line_items_update on docs.line_items for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists line_items_delete on docs.line_items;
create policy line_items_delete on docs.line_items for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'));

-- 프로젝트 합계 뷰(security_invoker: 호출자의 RLS 로 line_items 를 읽는다). 공급가·VAT·합계는 서버 계산(원칙 4).
create or replace view docs.project_totals with (security_invoker = true) as
  select p.id as project_id, p.org_id,
         coalesce(sum(li.amount_krw), 0)::bigint as subtotal_krw,
         coalesce(s.vat_rate_bp, 1000) as vat_rate_bp,
         (round(coalesce(sum(li.amount_krw), 0) * coalesce(s.vat_rate_bp, 1000) / 10000.0))::bigint as vat_krw,
         (coalesce(sum(li.amount_krw), 0) + round(coalesce(sum(li.amount_krw), 0) * coalesce(s.vat_rate_bp, 1000) / 10000.0))::bigint as total_krw,
         count(li.id)::integer as line_item_count
  from docs.projects p
  left join docs.workspace_settings s on s.org_id = p.org_id
  left join docs.line_items li on li.project_id = p.id
  group by p.id, p.org_id, s.vat_rate_bp;
revoke all on docs.project_totals from public, anon, authenticated;
grant select on docs.project_totals to authenticated;

-- ---------------------------------------------------------------------
-- 11. uploads: RFP·녹음·참고 자료. Route Handler(service_role)가 MIME·크기·매직바이트 검사 뒤 넣는다. 사용자는 읽기만.
--     storage_path 는 서버가 만든다: <org_id>/docs/<purpose>/<uuid>.<ext> (사용자 파일명은 경로에 쓰지 않는다).
-- ---------------------------------------------------------------------
create table if not exists docs.uploads (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references core.organizations(id) on delete cascade,
  project_id       uuid,
  purpose          text not null constraint uploads_purpose_check check (purpose in ('rfp', 'minutes_audio', 'minutes_text', 'reference', 'template_docx')),
  original_name    text,                                     -- 표시용. 경로에는 쓰지 않는다
  storage_path     text not null constraint uploads_storage_path_check check (storage_path ~ '^[0-9a-f-]{36}/docs/(rfp|minutes_audio|minutes_text|reference|template_docx)/[0-9a-f-]{36}\.[a-z0-9]{1,8}$'),
  mime             text not null,
  bytes            bigint not null constraint uploads_bytes_check check (bytes between 1 and 20971520),   -- 20MB(flora 업로드 파서 교훈)
  sha256           text not null constraint uploads_sha256_check check (sha256 ~ '^[0-9a-f]{64}$'),
  parse_status     text not null default 'pending' constraint uploads_parse_status_check check (parse_status in ('pending', 'parsing', 'parsed', 'failed', 'deleted')),
  ai_document_id   uuid references core.ai_documents(id) on delete set null,
  error            text,
  expires_at       timestamptz,                              -- 녹음 원본 기본 24시간(D-11 제안)
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint uploads_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade,
  constraint uploads_storage_org_check check (split_part(storage_path, '/', 1) = org_id::text)
);
create index if not exists uploads_project_idx on docs.uploads (project_id, purpose, created_at desc);
create index if not exists uploads_expires_idx on docs.uploads (expires_at) where expires_at is not null and parse_status <> 'deleted';
drop trigger if exists uploads_set_updated_at on docs.uploads;
create trigger uploads_set_updated_at before update on docs.uploads
  for each row execute function core.set_updated_at();
drop trigger if exists uploads_guard_write on docs.uploads;
create trigger uploads_guard_write before insert or update or delete on docs.uploads
  for each row execute function core.guard_privileged_write();
alter table docs.uploads enable row level security;
revoke all on docs.uploads from public, anon, authenticated;
grant select on docs.uploads to authenticated;
drop policy if exists uploads_select on docs.uploads;
create policy uploads_select on docs.uploads for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 12. documents: 문서. 사용자는 title 만 고친다(컬럼 GRANT). 생성은 start_generation, 확정·보관·개정은 RPC.
--     프로젝트 FK 는 no action: 문서가 있는 프로젝트는 영구 삭제되지 않는다(soft delete 만). 조직 purge 에서는
--     같은 문장 안에서 둘 다 지워지므로 통과한다.
-- ---------------------------------------------------------------------
create table if not exists docs.documents (
  id                      uuid primary key default gen_random_uuid(),
  org_id                  uuid not null references core.organizations(id) on delete cascade,
  project_id              uuid not null,
  doc_type_code           text not null references docs.doc_types(code),
  title                   text not null constraint documents_title_check check (char_length(title) between 1 and 200),
  status                  text not null default 'draft' constraint documents_status_check
                          check (status in ('draft', 'generating', 'review', 'final', 'archived')),
  current_version         integer not null default 0 constraint documents_current_version_check check (current_version >= 0),
  doc_number              text,
  finalized_at            timestamptz,
  finalized_by            uuid,
  archived_at             timestamptz,
  supersedes_document_id  uuid,
  needs_regeneration      boolean not null default false,
  created_by              uuid,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique (id, org_id),
  constraint documents_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id),
  constraint documents_supersedes_fk foreign key (supersedes_document_id, org_id) references docs.documents (id, org_id),
  constraint documents_final_number_check check (status <> 'final' or (doc_number is not null and finalized_at is not null and current_version >= 1))
);
create index if not exists documents_project_idx on docs.documents (project_id, doc_type_code, created_at desc);
create index if not exists documents_org_status_idx on docs.documents (org_id, status, updated_at desc);
create unique index if not exists documents_org_number_uniq on docs.documents (org_id, doc_number) where doc_number is not null;
-- 원본 1건당 진행 중(보관 아님) 개정본은 1건
create unique index if not exists documents_one_open_revision_uniq on docs.documents (supersedes_document_id)
  where supersedes_document_id is not null and status <> 'archived';
drop trigger if exists documents_set_updated_at on docs.documents;
create trigger documents_set_updated_at before update on docs.documents
  for each row execute function core.set_updated_at();

-- 상태 전이 + 확정 불변(service_role 에도 적용)
--   draft -> generating | final | archived (final 은 버전이 있는 개정본 draft 의 확정, finalize_document 만)
--   generating -> review | draft (생성 실패: 버전이 있으면 review, 없으면 draft)
--   review -> generating | final | archived
--   final -> archived (그 밖의 변경은 DC003. 고치려면 create_revision)
--   archived -> 없음
create or replace function docs.documents_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    -- 2차 잠금: 사용자 세션은 title 외 어떤 컬럼도 바꾸지 못한다
    if (new.org_id, new.project_id, new.doc_type_code, new.status, new.current_version, new.doc_number,
        new.finalized_at, new.finalized_by, new.archived_at, new.supersedes_document_id, new.needs_regeneration, new.created_by)
       is distinct from
       (old.org_id, old.project_id, old.doc_type_code, old.status, old.current_version, old.doc_number,
        old.finalized_at, old.finalized_by, old.archived_at, old.supersedes_document_id, old.needs_regeneration, old.created_by) then
      raise exception 'documents: only title is user-editable' using errcode = '42501';
    end if;
  end if;
  if old.status in ('final', 'archived') then
    if (new.org_id, new.project_id, new.doc_type_code, new.title, new.current_version, new.doc_number,
        new.finalized_at, new.finalized_by, new.supersedes_document_id)
       is distinct from
       (old.org_id, old.project_id, old.doc_type_code, old.title, old.current_version, old.doc_number,
        old.finalized_at, old.finalized_by, old.supersedes_document_id) then
      raise exception 'documents: % document is immutable', old.status using errcode = 'DC003';
    end if;
  end if;
  if new.status is distinct from old.status then
    if not ((old.status = 'draft' and new.status in ('generating', 'final', 'archived'))
         or (old.status = 'generating' and new.status in ('review', 'draft'))
         or (old.status = 'review' and new.status in ('generating', 'final', 'archived'))
         or (old.status = 'final' and new.status = 'archived')) then
      raise exception 'documents: invalid transition % -> %', old.status, new.status using errcode = 'DC001';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists documents_before_update on docs.documents;
create trigger documents_before_update before update on docs.documents
  for each row execute function docs.documents_before_update();
drop trigger if exists documents_guard_insert on docs.documents;
create trigger documents_guard_insert before insert or delete on docs.documents
  for each row execute function core.guard_privileged_write();

alter table docs.documents enable row level security;
revoke all on docs.documents from public, anon, authenticated;
grant select on docs.documents to authenticated;
grant update (title) on docs.documents to authenticated;
drop policy if exists documents_select on docs.documents;
create policy documents_select on docs.documents for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));
drop policy if exists documents_update on docs.documents;
create policy documents_update on docs.documents for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']));

-- 정본(답·요구사항·산출물·비용)이 바뀌면 같은 프로젝트의 draft/review 문서에 "재생성 필요" 표시(원칙 1).
-- 사용자 세션에서도 documents 를 갱신해야 하므로 DEFINER(guard 통과). 트리거 전용, EXECUTE 는 회수한다.
create or replace function docs.mark_documents_stale()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_project uuid;
begin
  v_project := case when tg_op = 'DELETE' then old.project_id else new.project_id end;
  update docs.documents d set needs_regeneration = true
  -- generating 포함: 생성 중에 바뀐 정본도 놓치지 않는다. 표시는 start_generation 이 지우고 finish 는 건드리지 않는다.
  where d.project_id = v_project and d.status in ('draft', 'review', 'generating') and not d.needs_regeneration;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
drop trigger if exists checklist_answers_mark_stale on docs.checklist_answers;
create trigger checklist_answers_mark_stale after insert or update or delete on docs.checklist_answers
  for each row execute function docs.mark_documents_stale();
drop trigger if exists requirements_mark_stale on docs.requirements;
create trigger requirements_mark_stale after insert or update or delete on docs.requirements
  for each row execute function docs.mark_documents_stale();
drop trigger if exists artifacts_mark_stale on docs.artifacts;
create trigger artifacts_mark_stale after insert or update or delete on docs.artifacts
  for each row execute function docs.mark_documents_stale();
drop trigger if exists line_items_mark_stale on docs.line_items;
create trigger line_items_mark_stale after insert or update or delete on docs.line_items
  for each row execute function docs.mark_documents_stale();

-- ---------------------------------------------------------------------
-- 13. document_versions: append-only. 생성(finish_generation)·편집 저장(Route Handler 가 sanitize 후 service INSERT)·
--     개정 복사(create_revision)만 새 행을 만든다. UPDATE 는 언제나 DC003, DELETE 는 조직 purge 안에서만.
-- ---------------------------------------------------------------------
create table if not exists docs.document_versions (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references core.organizations(id) on delete cascade,
  document_id         uuid not null,
  version             integer not null constraint document_versions_version_check check (version >= 1),
  doc_type_version    integer not null,
  content             jsonb not null default '[]'::jsonb,
  body_html           text constraint document_versions_body_size_check check (body_html is null or octet_length(body_html) <= 2097152),
  variables_snapshot  jsonb not null default '{}'::jsonb,
  inputs_hash         text,
  -- lint 를 실제로 돌린 버전만 ran_at(ISO 시각)·rules(적용 규칙 ID 배열)를 가진다. 기본값(키 없음) = lint 미실행.
  -- finalize_document 는 ran_at 이 없으면 DC005 로 막는다(교차검증 #2). 편집 저장 경로도 저장 전 lint 를 돌려 함께 넣는다.
  lint_result         jsonb not null default '{"errors": [], "warnings": []}'::jsonb,
  compliance_verdict  text not null default 'skipped' constraint document_versions_verdict_check
                      check (compliance_verdict in ('pass', 'warn', 'fail', 'skipped')),
  created_kind        text not null constraint document_versions_kind_check check (created_kind in ('generated', 'edited', 'imported')),
  generation_run_id   uuid,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  unique (id, org_id),
  unique (document_id, version),
  constraint document_versions_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade,
  constraint document_versions_content_check check (jsonb_typeof(content) = 'array')
);
create index if not exists document_versions_org_idx on docs.document_versions (org_id);

create or replace function docs.document_versions_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('core.allow_purge', true) = 'on' and core.is_privileged_session() then
    return old;
  end if;
  raise exception 'document_versions is append-only (%)', tg_op using errcode = 'DC003';
end;
$$;
drop trigger if exists document_versions_immutable on docs.document_versions;
create trigger document_versions_immutable before update or delete on docs.document_versions
  for each row execute function docs.document_versions_immutable();

-- INSERT 는 service 만 + 문서가 final/archived 이면 거부 + 번호는 current_version + 1 이어야 한다
create or replace function docs.document_versions_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_doc docs.documents;
begin
  if not core.is_privileged_session() then
    raise exception 'document_versions: INSERT is allowed only for service_role' using errcode = '42501';
  end if;
  select * into v_doc from docs.documents d where d.id = new.document_id and d.org_id = new.org_id;
  if found then
    if v_doc.status in ('final', 'archived') then
      raise exception 'document_versions: document is %', v_doc.status using errcode = 'DC003';
    end if;
    if v_doc.status = 'generating' and new.created_kind <> 'generated' then
      raise exception 'document_versions: document is generating' using errcode = 'DC002';
    end if;
    if new.version <> v_doc.current_version + 1 then
      raise exception 'document_versions: expected version %, got %', v_doc.current_version + 1, new.version using errcode = 'DC010';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists document_versions_before_insert on docs.document_versions;
create trigger document_versions_before_insert before insert on docs.document_versions
  for each row execute function docs.document_versions_before_insert();

-- 버전이 저장되면 문서의 current_version 을 그 번호로 맞춘다(편집 저장 경로가 INSERT 1번으로 끝나게).
-- 생성 중(generating)인 문서에 편집 버전을 넣으면 DC002(생성 결과와 충돌).
create or replace function docs.document_versions_after_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update docs.documents d set current_version = new.version where d.id = new.document_id;
  return new;
end;
$$;
drop trigger if exists document_versions_after_insert on docs.document_versions;
create trigger document_versions_after_insert after insert on docs.document_versions
  for each row execute function docs.document_versions_after_insert();

alter table docs.document_versions enable row level security;
revoke all on docs.document_versions from public, anon, authenticated;
grant select on docs.document_versions to authenticated;
drop policy if exists document_versions_select on docs.document_versions;
create policy document_versions_select on docs.document_versions for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 14. trace_links: 요구사항 -> 화면·문서 절·조항·비용·검수 항목. service 만 쓴다(효과 엔진, 생성 그래프).
-- ---------------------------------------------------------------------
create table if not exists docs.trace_links (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  requirement_id  uuid not null,
  to_kind         text not null constraint trace_links_to_kind_check
                  check (to_kind in ('artifact', 'document_section', 'clause', 'line_item', 'acceptance_item')),
  to_ref          text not null,                     -- artifact/line_item id, 섹션 key, 조항 code, 검수 항목 key
  document_id     uuid,
  created_at      timestamptz not null default now(),
  constraint trace_links_requirement_fk foreign key (requirement_id, org_id) references docs.requirements (id, org_id) on delete cascade,
  constraint trace_links_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade
);
create unique index if not exists trace_links_uniq on docs.trace_links
  (requirement_id, to_kind, to_ref, (coalesce(document_id, '00000000-0000-0000-0000-000000000000'::uuid)));
create index if not exists trace_links_document_idx on docs.trace_links (document_id) where document_id is not null;
create index if not exists trace_links_org_idx on docs.trace_links (org_id);
drop trigger if exists trace_links_guard_write on docs.trace_links;
create trigger trace_links_guard_write before insert or update or delete on docs.trace_links
  for each row execute function core.guard_privileged_write();
alter table docs.trace_links enable row level security;
revoke all on docs.trace_links from public, anon, authenticated;
grant select on docs.trace_links to authenticated;
drop policy if exists trace_links_select on docs.trace_links;
create policy trace_links_select on docs.trace_links for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 15. generation_runs: 생성 실행. 문서당(패키지는 프로젝트·패키지당) 활성 1개(DC002, 부분 유니크).
-- ---------------------------------------------------------------------
create table if not exists docs.generation_runs (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  project_id        uuid not null,
  document_id       uuid,
  doc_type_code     text references docs.doc_types(code),
  package_code      text constraint generation_runs_package_check check (package_code is null or package_code ~ '^[a-z][a-z0-9_]{1,40}$'),
  parent_run_id     uuid references docs.generation_runs(id) on delete set null,
  job_id            uuid references core.jobs(id) on delete set null,
  ai_run_id         uuid references core.ai_runs(id) on delete set null,
  status            text not null default 'queued' constraint generation_runs_status_check
                    check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  credits_reserved  integer not null default 0 constraint generation_runs_reserved_check check (credits_reserved >= 0),
  credits_settled   integer constraint generation_runs_settled_check check (credits_settled is null or credits_settled between 0 and credits_reserved),
  credit_ledger_id  bigint references core.credit_ledger(id),
  idempotency_key   text not null unique constraint generation_runs_idem_check check (idempotency_key ~ '^gen:docs:'),
  error             text,
  -- 단계별 진행 애니메이션용(DC-F-048, 2026-10-14). ai-service 가 report_generation_progress 로만 갱신한다.
  -- {stage, section_key, step, total, at}. stage: queued|collecting|drafting|assembling|linting|rendering|done
  progress          jsonb not null default '{}'::jsonb constraint generation_runs_progress_check check (jsonb_typeof(progress) = 'object'),
  created_by        uuid,
  queued_at         timestamptz not null default now(),
  started_at        timestamptz,
  finished_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, org_id),
  constraint generation_runs_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade,
  constraint generation_runs_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade,
  constraint generation_runs_target_check check ((document_id is not null and doc_type_code is not null) or (document_id is null and package_code is not null))
);
create unique index if not exists generation_runs_one_active_per_document_uniq on docs.generation_runs (document_id)
  where document_id is not null and status in ('queued', 'running');
create unique index if not exists generation_runs_one_active_package_uniq on docs.generation_runs (project_id, package_code)
  where document_id is null and status in ('queued', 'running');
create index if not exists generation_runs_org_active_idx on docs.generation_runs (org_id) where status in ('queued', 'running');
create index if not exists generation_runs_created_idx on docs.generation_runs (created_at);
create index if not exists generation_runs_document_idx on docs.generation_runs (document_id, created_at desc);
create index if not exists generation_runs_job_idx on docs.generation_runs (job_id) where job_id is not null;
drop trigger if exists generation_runs_set_updated_at on docs.generation_runs;
create trigger generation_runs_set_updated_at before update on docs.generation_runs
  for each row execute function core.set_updated_at();
drop trigger if exists generation_runs_guard_write on docs.generation_runs;
create trigger generation_runs_guard_write before insert or update or delete on docs.generation_runs
  for each row execute function core.guard_privileged_write();

create or replace function docs.check_generation_run_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status = 'queued' and new.status in ('running', 'failed', 'canceled'))
         or (old.status = 'running' and new.status in ('succeeded', 'failed', 'canceled'))) then
      raise exception 'generation_runs: invalid transition % -> %', old.status, new.status using errcode = 'DC001';
    end if;
  elsif old.status in ('succeeded', 'failed', 'canceled')
        and (new.credits_reserved, new.document_id, new.project_id) is distinct from (old.credits_reserved, old.document_id, old.project_id) then
    raise exception 'generation_runs: terminal run is immutable' using errcode = 'DC003';
  end if;
  return new;
end;
$$;
drop trigger if exists generation_runs_status_transition on docs.generation_runs;
create trigger generation_runs_status_transition before update on docs.generation_runs
  for each row execute function docs.check_generation_run_transition();

alter table docs.generation_runs enable row level security;
revoke all on docs.generation_runs from public, anon, authenticated;
grant select on docs.generation_runs to authenticated;
drop policy if exists generation_runs_select on docs.generation_runs;
create policy generation_runs_select on docs.generation_runs for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 16. doc_exports: PDF·DOCX·ZIP(HWPX 는 Phase 3). 렌더 결과는 exports 버킷, 서명 URL 로만 내려준다.
-- ---------------------------------------------------------------------
create table if not exists docs.doc_exports (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  project_id           uuid not null,
  document_version_id  uuid,
  format               text not null constraint doc_exports_format_check check (format in ('pdf', 'docx', 'zip', 'hwpx')),
  status               text not null default 'queued' constraint doc_exports_status_check
                       check (status in ('queued', 'rendering', 'ready', 'failed', 'expired')),
  storage_path         text constraint doc_exports_storage_path_check check (storage_path is null or storage_path ~ '^[0-9a-f-]{36}/docs/exports/[0-9a-f-]{36}\.(pdf|docx|zip|hwpx)$'),
  bytes                bigint constraint doc_exports_bytes_check check (bytes is null or bytes between 1 and 209715200),
  pages                integer,
  sha256               text,
  job_id               uuid references core.jobs(id) on delete set null,
  credit_ledger_id     bigint references core.credit_ledger(id),
  watermark            boolean not null default true,
  expires_at           timestamptz,
  error                text,
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint doc_exports_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade,
  constraint doc_exports_version_fk foreign key (document_version_id, org_id) references docs.document_versions (id, org_id) on delete cascade,
  constraint doc_exports_target_check check ((format = 'zip') = (document_version_id is null)),
  constraint doc_exports_storage_org_check check (storage_path is null or split_part(storage_path, '/', 1) = org_id::text),
  constraint doc_exports_ready_check check (status <> 'ready' or storage_path is not null)
);
create index if not exists doc_exports_version_idx on docs.doc_exports (document_version_id, format, status);
create index if not exists doc_exports_project_idx on docs.doc_exports (project_id, created_at desc);
create index if not exists doc_exports_expires_idx on docs.doc_exports (expires_at) where status = 'ready';
drop trigger if exists doc_exports_set_updated_at on docs.doc_exports;
create trigger doc_exports_set_updated_at before update on docs.doc_exports
  for each row execute function core.set_updated_at();
drop trigger if exists doc_exports_guard_write on docs.doc_exports;
create trigger doc_exports_guard_write before insert or update or delete on docs.doc_exports
  for each row execute function core.guard_privileged_write();

create or replace function docs.check_doc_export_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status = 'queued' and new.status in ('rendering', 'failed'))
         or (old.status = 'rendering' and new.status in ('ready', 'failed'))
         or (old.status = 'ready' and new.status = 'expired')) then
      raise exception 'doc_exports: invalid transition % -> %', old.status, new.status using errcode = 'DC001';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists doc_exports_status_transition on docs.doc_exports;
create trigger doc_exports_status_transition before update of status on docs.doc_exports
  for each row execute function docs.check_doc_export_transition();

alter table docs.doc_exports enable row level security;
revoke all on docs.doc_exports from public, anon, authenticated;
grant select on docs.doc_exports to authenticated;
drop policy if exists doc_exports_select on docs.doc_exports;
create policy doc_exports_select on docs.doc_exports for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 17. doc_counters: 문서번호 일련번호(조직·유형·연도(KST)). next_doc_number 만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists docs.doc_counters (
  org_id         uuid not null references core.organizations(id) on delete cascade,
  doc_type_code  text not null references docs.doc_types(code),
  year           integer not null constraint doc_counters_year_check check (year between 2000 and 2999),
  last_no        integer not null default 0 constraint doc_counters_last_no_check check (last_no >= 0),
  updated_at     timestamptz not null default now(),
  primary key (org_id, doc_type_code, year)
);
drop trigger if exists doc_counters_set_updated_at on docs.doc_counters;
create trigger doc_counters_set_updated_at before update on docs.doc_counters
  for each row execute function core.set_updated_at();
drop trigger if exists doc_counters_guard_write on docs.doc_counters;
create trigger doc_counters_guard_write before insert or update or delete on docs.doc_counters
  for each row execute function core.guard_privileged_write();
alter table docs.doc_counters enable row level security;
revoke all on docs.doc_counters from public, anon, authenticated;
grant select on docs.doc_counters to authenticated;
drop policy if exists doc_counters_select on docs.doc_counters;
create policy doc_counters_select on docs.doc_counters for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 18. risk_acknowledgements: 고위험 문서 고지 동의(조직·유형·고지문 버전당 1회). ack_risk_notice RPC 만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists docs.risk_acknowledgements (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  doc_type_code   text not null references docs.doc_types(code),
  notice_version  text not null,
  acked_by        uuid,
  acked_at        timestamptz not null default now(),
  unique (org_id, doc_type_code, notice_version)
);
drop trigger if exists risk_acknowledgements_guard_write on docs.risk_acknowledgements;
create trigger risk_acknowledgements_guard_write before insert or update or delete on docs.risk_acknowledgements
  for each row execute function core.guard_privileged_write();
alter table docs.risk_acknowledgements enable row level security;
revoke all on docs.risk_acknowledgements from public, anon, authenticated;
grant select on docs.risk_acknowledgements to authenticated;
drop policy if exists risk_acknowledgements_select on docs.risk_acknowledgements;
create policy risk_acknowledgements_select on docs.risk_acknowledgements for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 19. approval_steps (Phase 2): 검토·승인 단계. decide_approval RPC 로만 결정한다.
-- ---------------------------------------------------------------------
create table if not exists docs.approval_steps (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references core.organizations(id) on delete cascade,
  document_id       uuid not null,
  version           integer not null,
  step_no           integer not null constraint approval_steps_step_check check (step_no between 1 and 10),
  approver_user_id  uuid not null,
  status            text not null default 'pending' constraint approval_steps_status_check check (status in ('pending', 'approved', 'rejected')),
  comment           text constraint approval_steps_comment_check check (comment is null or char_length(comment) <= 2000),
  decided_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (document_id, version, step_no),
  constraint approval_steps_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade
);
create index if not exists approval_steps_approver_idx on docs.approval_steps (approver_user_id) where status = 'pending';
drop trigger if exists approval_steps_set_updated_at on docs.approval_steps;
create trigger approval_steps_set_updated_at before update on docs.approval_steps
  for each row execute function core.set_updated_at();
drop trigger if exists approval_steps_guard_write on docs.approval_steps;
create trigger approval_steps_guard_write before insert or update or delete on docs.approval_steps
  for each row execute function core.guard_privileged_write();
alter table docs.approval_steps enable row level security;
revoke all on docs.approval_steps from public, anon, authenticated;
grant select on docs.approval_steps to authenticated;
drop policy if exists approval_steps_select on docs.approval_steps;
create policy approval_steps_select on docs.approval_steps for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 20. signature_requests (Phase 3): 외부 전자서명 요청. 제공자 미확인(D-7). service 만 쓴다.
-- ---------------------------------------------------------------------
create table if not exists docs.signature_requests (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  document_version_id  uuid not null,
  provider             text not null,
  external_id          text,
  status               text not null default 'draft' constraint signature_requests_status_check
                       check (status in ('draft', 'sent', 'signed', 'declined', 'expired', 'canceled')),
  signed_pdf_path      text constraint signature_requests_path_check check (signed_pdf_path is null or split_part(signed_pdf_path, '/', 1) = org_id::text),
  sha256               text,
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint signature_requests_version_fk foreign key (document_version_id, org_id) references docs.document_versions (id, org_id) on delete cascade
);
create unique index if not exists signature_requests_external_uniq on docs.signature_requests (provider, external_id) where external_id is not null;
drop trigger if exists signature_requests_set_updated_at on docs.signature_requests;
create trigger signature_requests_set_updated_at before update on docs.signature_requests
  for each row execute function core.set_updated_at();
drop trigger if exists signature_requests_guard_write on docs.signature_requests;
create trigger signature_requests_guard_write before insert or update or delete on docs.signature_requests
  for each row execute function core.guard_privileged_write();
alter table docs.signature_requests enable row level security;
revoke all on docs.signature_requests from public, anon, authenticated;
grant select on docs.signature_requests to authenticated;
drop policy if exists signature_requests_select on docs.signature_requests;
create policy signature_requests_select on docs.signature_requests for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 21. 연동: integration_connections, field_mappings, external_refs, sync_runs
--     자격증명은 core.encrypted_credentials 참조만(평문 컬럼 없음). 연결 생성·상태 변경은 service(OAuth 콜백, 어댑터),
--     사용자의 해지는 revoke_integration RPC. 내부 ERP(erp.*) 읽기는 service_role 함수만(사용자 교차 스키마 GRANT 없음).
-- ---------------------------------------------------------------------
create table if not exists docs.integration_connections (
  id                   uuid primary key default gen_random_uuid(),
  org_id               uuid not null references core.organizations(id) on delete cascade,
  provider             text not null constraint integration_connections_provider_check
                       check (provider in ('csv', 'hubspot', 'salesforce', 'admin_suite_erp', 'ecount', 'douzone', 'n8n')),  -- 자동화는 n8n 만(2026-10-14, Make 제외)
  kind                 text not null constraint integration_connections_kind_check check (kind in ('crm', 'erp', 'automation', 'file')),
  status               text not null default 'pending' constraint integration_connections_status_check
                       check (status in ('pending', 'active', 'error', 'revoked')),
  credential_id        uuid references core.encrypted_credentials(id) on delete set null,
  external_account_id  text not null default '',
  sync_direction       text not null default 'pull' constraint integration_connections_direction_check check (sync_direction in ('pull', 'push', 'both')),
  settings             jsonb not null default '{}'::jsonb,       -- 비밀값 금지(커서, 파이프라인 id 등)
  inbound_token_hash   text,                                     -- Make/n8n 수신 토큰의 sha256(원문은 1회 표시 후 버림)
  last_synced_at       timestamptz,
  last_error           text,
  revoked_at           timestamptz,
  created_by           uuid,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (id, org_id),
  constraint integration_connections_token_hash_check check (inbound_token_hash is null or inbound_token_hash ~ '^[0-9a-f]{64}$')
);
create unique index if not exists integration_connections_live_uniq on docs.integration_connections (org_id, provider, external_account_id)
  where status <> 'revoked';
create unique index if not exists integration_connections_inbound_uniq on docs.integration_connections (inbound_token_hash)
  where inbound_token_hash is not null;
drop trigger if exists integration_connections_set_updated_at on docs.integration_connections;
create trigger integration_connections_set_updated_at before update on docs.integration_connections
  for each row execute function core.set_updated_at();
drop trigger if exists integration_connections_guard_write on docs.integration_connections;
create trigger integration_connections_guard_write before insert or update or delete on docs.integration_connections
  for each row execute function core.guard_privileged_write();

-- 상태 전이: pending -> active | error | revoked, active -> error | revoked, error -> active | revoked, revoked -> 없음
create or replace function docs.check_connection_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status = 'pending' and new.status in ('active', 'error', 'revoked'))
         or (old.status = 'active' and new.status in ('error', 'revoked'))
         or (old.status = 'error' and new.status in ('active', 'revoked'))) then
      raise exception 'integration_connections: invalid transition % -> %', old.status, new.status using errcode = 'DC009';
    end if;
  end if;
  if new.org_id <> old.org_id or new.provider <> old.provider then
    raise exception 'integration_connections: org_id/provider are immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists integration_connections_status_transition on docs.integration_connections;
create trigger integration_connections_status_transition before update on docs.integration_connections
  for each row execute function docs.check_connection_transition();

alter table docs.integration_connections enable row level security;
revoke all on docs.integration_connections from public, anon, authenticated;
-- inbound_token_hash 는 사용자에게 보이지 않게 컬럼 GRANT 로 제외한다
grant select (id, org_id, provider, kind, status, credential_id, external_account_id, sync_direction, settings,
              last_synced_at, last_error, revoked_at, created_by, created_at, updated_at) on docs.integration_connections to authenticated;
drop policy if exists integration_connections_select on docs.integration_connections;
create policy integration_connections_select on docs.integration_connections for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));

-- 필드 매핑: owner/admin 이 쓴다(순수 설정). internal_path 는 허용 목록 정규식으로 제한한다.
create table if not exists docs.field_mappings (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  connection_id   uuid not null,
  entity          text not null constraint field_mappings_entity_check check (entity in ('party', 'project', 'line_item', 'document')),
  external_field  text not null constraint field_mappings_external_check check (char_length(external_field) between 1 and 200),
  internal_path   text not null constraint field_mappings_internal_check
                  check (internal_path ~ '^(party|project|line_item|document)\.[a-z_]+(\.[a-z0-9_]+)?$'),
  transform       text not null default 'none' constraint field_mappings_transform_check check (transform in ('none', 'date', 'money', 'enum_map')),
  enum_map        jsonb,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (connection_id, entity, internal_path),
  constraint field_mappings_connection_fk foreign key (connection_id, org_id) references docs.integration_connections (id, org_id) on delete cascade,
  constraint field_mappings_enum_check check ((transform = 'enum_map') = (enum_map is not null and jsonb_typeof(enum_map) = 'object')),
  -- 문서·버전·문서번호는 NOMAD Docs 가 정본: 외부 값이 쓰는 매핑을 만들 수 없다(document 는 push 전용 표시 필드만)
  constraint field_mappings_document_owner_check check (entity <> 'document' or internal_path in ('document.title', 'document.doc_number', 'document.pdf_url', 'document.status'))
);
drop trigger if exists field_mappings_set_updated_at on docs.field_mappings;
create trigger field_mappings_set_updated_at before update on docs.field_mappings
  for each row execute function core.set_updated_at();
alter table docs.field_mappings enable row level security;
revoke all on docs.field_mappings from public, anon, authenticated;
grant select on docs.field_mappings to authenticated;
grant insert (org_id, connection_id, entity, external_field, internal_path, transform, enum_map, is_active) on docs.field_mappings to authenticated;
grant update (external_field, transform, enum_map, is_active) on docs.field_mappings to authenticated;
grant delete on docs.field_mappings to authenticated;
drop policy if exists field_mappings_select on docs.field_mappings;
create policy field_mappings_select on docs.field_mappings for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists field_mappings_insert on docs.field_mappings;
create policy field_mappings_insert on docs.field_mappings for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));
drop policy if exists field_mappings_update on docs.field_mappings;
create policy field_mappings_update on docs.field_mappings for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'))
  with check (core.has_org_role(org_id, array['owner', 'admin']));
drop policy if exists field_mappings_delete on docs.field_mappings;
create policy field_mappings_delete on docs.field_mappings for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));
-- 2차 잠금: 사용자 세션은 org/연결/엔티티/내부 경로를 바꾸지 못한다(바꾸려면 삭제 후 새로 만든다)
create or replace function docs.guard_field_mapping_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not core.is_privileged_session()
     and (new.org_id <> old.org_id or new.connection_id <> old.connection_id or new.entity <> old.entity or new.internal_path <> old.internal_path) then
    raise exception 'field_mappings: org/connection/entity/internal_path are immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists field_mappings_guard_columns on docs.field_mappings;
create trigger field_mappings_guard_columns before update on docs.field_mappings
  for each row execute function docs.guard_field_mapping_columns();

-- external_refs: 내부 엔티티 <-> 외부 엔티티 1:1. 유니크 2개:
--   (connection_id, entity, internal_id)  : 내부 행 1개는 한 연결에서 외부 행 1개만
--   (connection_id, entity, external_id)  : 외부 행 1개는 내부 행 1개만(중복 pull 로 거래처가 둘이 되지 않게)
create table if not exists docs.external_refs (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references core.organizations(id) on delete cascade,
  connection_id   uuid not null,
  entity          text not null constraint external_refs_entity_check check (entity in ('party', 'project', 'line_item', 'document')),
  internal_id     uuid not null,
  external_type   text not null,
  external_id     text not null constraint external_refs_external_id_check check (char_length(external_id) between 1 and 200),
  etag            text,
  last_synced_at  timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (connection_id, entity, internal_id),
  unique (connection_id, entity, external_id),
  constraint external_refs_connection_fk foreign key (connection_id, org_id) references docs.integration_connections (id, org_id) on delete cascade
);
create index if not exists external_refs_internal_idx on docs.external_refs (entity, internal_id);
create index if not exists external_refs_org_idx on docs.external_refs (org_id);
drop trigger if exists external_refs_set_updated_at on docs.external_refs;
create trigger external_refs_set_updated_at before update on docs.external_refs
  for each row execute function core.set_updated_at();
drop trigger if exists external_refs_guard_write on docs.external_refs;
create trigger external_refs_guard_write before insert or update or delete on docs.external_refs
  for each row execute function core.guard_privileged_write();
alter table docs.external_refs enable row level security;
revoke all on docs.external_refs from public, anon, authenticated;
grant select on docs.external_refs to authenticated;
drop policy if exists external_refs_select on docs.external_refs;
create policy external_refs_select on docs.external_refs for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs'));

create table if not exists docs.sync_runs (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  connection_id  uuid not null,
  entity         text not null constraint sync_runs_entity_check check (entity in ('party', 'project', 'line_item', 'document')),
  direction      text not null constraint sync_runs_direction_check check (direction in ('pull', 'push')),
  status         text not null default 'queued' constraint sync_runs_status_check check (status in ('queued', 'running', 'succeeded', 'failed', 'canceled')),
  job_id         uuid references core.jobs(id) on delete set null,
  stats          jsonb not null default '{}'::jsonb,           -- {created, updated, skipped, conflicts}
  started_at     timestamptz,
  finished_at    timestamptz,
  error          text,
  created_by     uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint sync_runs_connection_fk foreign key (connection_id, org_id) references docs.integration_connections (id, org_id) on delete cascade
);
create unique index if not exists sync_runs_one_active_uniq on docs.sync_runs (connection_id, entity, direction) where status in ('queued', 'running');
create index if not exists sync_runs_connection_idx on docs.sync_runs (connection_id, created_at desc);
drop trigger if exists sync_runs_set_updated_at on docs.sync_runs;
create trigger sync_runs_set_updated_at before update on docs.sync_runs
  for each row execute function core.set_updated_at();
drop trigger if exists sync_runs_guard_write on docs.sync_runs;
create trigger sync_runs_guard_write before insert or update or delete on docs.sync_runs
  for each row execute function core.guard_privileged_write();
alter table docs.sync_runs enable row level security;
revoke all on docs.sync_runs from public, anon, authenticated;
grant select on docs.sync_runs to authenticated;
drop policy if exists sync_runs_select on docs.sync_runs;
create policy sync_runs_select on docs.sync_runs for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));

-- ---------------------------------------------------------------------
-- 22. 발신 웹훅(Phase 2): webhook_endpoints, webhook_deliveries. URL 검증(https, 사설 IP 차단)은 서버가 등록 시와
--     발송 직전 DNS 해석 후 두 번 한다(SSRF). 서명 비밀은 core.encrypted_credentials 에만 둔다.
-- ---------------------------------------------------------------------
create table if not exists docs.webhook_endpoints (
  id                    uuid primary key default gen_random_uuid(),
  org_id                uuid not null references core.organizations(id) on delete cascade,
  url                   text not null constraint webhook_endpoints_url_check
                        check (url ~ '^https://[A-Za-z0-9.-]+(:[0-9]{2,5})?(/[^\s]*)?$' and char_length(url) <= 2000
                               and url !~* '^https://(localhost|127\.|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2[0-9]|3[01])\.|0\.|\[)'),
  events                text[] not null constraint webhook_endpoints_events_check
                        check (cardinality(events) > 0 and events <@ array['project.created', 'document.generated', 'document.finalized', 'document.exported', 'package.completed']::text[]),
  secret_credential_id  uuid references core.encrypted_credentials(id) on delete set null,
  status                text not null default 'active' constraint webhook_endpoints_status_check check (status in ('active', 'disabled', 'failing')),
  failure_count         integer not null default 0 constraint webhook_endpoints_failures_check check (failure_count >= 0),
  created_by            uuid,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (id, org_id)
);
drop trigger if exists webhook_endpoints_set_updated_at on docs.webhook_endpoints;
create trigger webhook_endpoints_set_updated_at before update on docs.webhook_endpoints
  for each row execute function core.set_updated_at();
drop trigger if exists webhook_endpoints_guard_write on docs.webhook_endpoints;
create trigger webhook_endpoints_guard_write before insert or update or delete on docs.webhook_endpoints
  for each row execute function core.guard_privileged_write();
alter table docs.webhook_endpoints enable row level security;
revoke all on docs.webhook_endpoints from public, anon, authenticated;
grant select on docs.webhook_endpoints to authenticated;
drop policy if exists webhook_endpoints_select on docs.webhook_endpoints;
create policy webhook_endpoints_select on docs.webhook_endpoints for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));

create table if not exists docs.webhook_deliveries (
  id               bigint generated always as identity primary key,
  org_id           uuid not null references core.organizations(id) on delete cascade,
  endpoint_id      uuid not null,
  event_type       text not null,
  event_id         uuid not null,
  payload_hash     text not null constraint webhook_deliveries_hash_check check (payload_hash ~ '^[0-9a-f]{64}$'),
  status           text not null default 'pending' constraint webhook_deliveries_status_check check (status in ('pending', 'delivered', 'failed')),
  attempts         integer not null default 0 constraint webhook_deliveries_attempts_check check (attempts between 0 and 10),
  response_status  integer,
  next_attempt_at  timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (endpoint_id, event_id),
  constraint webhook_deliveries_endpoint_fk foreign key (endpoint_id, org_id) references docs.webhook_endpoints (id, org_id) on delete cascade
);
create index if not exists webhook_deliveries_due_idx on docs.webhook_deliveries (next_attempt_at) where status = 'pending';
drop trigger if exists webhook_deliveries_set_updated_at on docs.webhook_deliveries;
create trigger webhook_deliveries_set_updated_at before update on docs.webhook_deliveries
  for each row execute function core.set_updated_at();
drop trigger if exists webhook_deliveries_guard_write on docs.webhook_deliveries;
create trigger webhook_deliveries_guard_write before insert or update or delete on docs.webhook_deliveries
  for each row execute function core.guard_privileged_write();
alter table docs.webhook_deliveries enable row level security;
revoke all on docs.webhook_deliveries from public, anon, authenticated;
grant select on docs.webhook_deliveries to authenticated;
drop policy if exists webhook_deliveries_select on docs.webhook_deliveries;
create policy webhook_deliveries_select on docs.webhook_deliveries for select to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs'));

-- 진행률 UI: 생성 실행·내보내기·문서 상태를 RLS 하에서 구독한다
do $$
declare t text;
begin
  foreach t in array array['generation_runs', 'doc_exports', 'documents'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'docs' and tablename = t) then
      execute format('alter publication supabase_realtime add table docs.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 22a. 로그인 후 CRM형 워크스페이스용 읽기 뷰(DC-F-047, 2026-10-14). 새 정본 테이블을 만들지 않고 기존 행에서 계산한다.
--      security_invoker 라 각 원본 테이블의 RLS 가 그대로 적용된다(다른 조직 행은 보이지 않는다).
-- ---------------------------------------------------------------------
-- 프로젝트 파이프라인 단계(보드 열). 우선순위: closed > accepted > contracted > quoted > drafting > lead
create or replace view docs.project_pipeline with (security_invoker = true) as
  select p.id as project_id, p.org_id, p.name, p.client_party_id, p.project_type, p.status, p.updated_at,
         case
           when p.status in ('delivered', 'archived') then 'closed'
           when bool_or(d.status = 'final' and d.doc_type_code = 'acceptance') then 'accepted'
           when bool_or(d.status = 'final' and t.category = 'contract') then 'contracted'
           when bool_or(d.status = 'final' and d.doc_type_code = 'quote') then 'quoted'
           when count(d.id) > 0 then 'drafting'
           else 'lead'
         end as stage,
         count(d.id) filter (where d.status in ('draft', 'review', 'generating'))::integer as open_documents,
         count(d.id) filter (where d.needs_regeneration)::integer as stale_documents
  from docs.projects p
  left join docs.documents d on d.project_id = p.id and d.status <> 'archived'
  left join docs.doc_types t on t.code = d.doc_type_code
  where p.deleted_at is null
  group by p.id, p.org_id, p.name, p.client_party_id, p.project_type, p.status, p.updated_at;
revoke all on docs.project_pipeline from public, anon, authenticated;
grant select on docs.project_pipeline to authenticated;

-- 프로젝트 활동 타임라인(최근 순). 원본: 생성 실행, 문서 버전 저장, 확정, 자료 업로드
create or replace view docs.project_activity with (security_invoker = true) as
  select g.org_id, g.project_id, coalesce(g.finished_at, g.queued_at) as at, 'generation'::text as kind, g.id as ref_id,
         g.status as detail, g.document_id
  from docs.generation_runs g where g.parent_run_id is null
  union all
  select v.org_id, d.project_id, v.created_at, 'version', v.id, v.created_kind || ':' || v.version::text, v.document_id
  from docs.document_versions v join docs.documents d on d.id = v.document_id
  union all
  select d.org_id, d.project_id, d.finalized_at, 'finalized', d.id, d.doc_number, d.id
  from docs.documents d where d.finalized_at is not null
  union all
  select u.org_id, u.project_id, u.created_at, 'upload', u.id, u.purpose, null::uuid
  from docs.uploads u where u.project_id is not null;
revoke all on docs.project_activity from public, anon, authenticated;
grant select on docs.project_activity to authenticated;

-- =====================================================================
-- 23. 함수 (RPC)
--   service_role 전용: next_doc_number, checklist_answers_hash, apply_checklist_effects, start_generation,
--                      finish_generation, fail_generation, upsert_external_ref (내부 판정 is_privileged_session)
--   사용자(authenticated) : finalize_document, archive_document, create_revision, set_project_status,
--                      confirm_checklist_suggestions, ack_risk_notice, revoke_integration, decide_approval(Phase 2)
--                      (내부 판정 is_service_caller + has_org_role, NULL-safe)
-- =====================================================================

-- 23.1 next_doc_number: 조직·유형·연도(KST) 일련번호를 행 잠금으로 올리고 서식을 적용한다.
--      서식 토큰: {PREFIX} 또는 {TYPE}(doc_types.number_prefix), {YYYY}, {YY}, {SEQ:n}(n자리 0 채움, 기본 4)
create or replace function docs.next_doc_number(p_org_id uuid, p_doc_type_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year   integer := extract(year from (now() at time zone 'Asia/Seoul'))::integer;
  v_no     integer;
  v_fmt    text;
  v_prefix text;
  v_width  integer;
  v_out    text;
begin
  if not core.is_privileged_session() then
    raise exception 'next_doc_number: service_role only' using errcode = '42501';
  end if;
  select t.number_prefix into v_prefix from docs.doc_types t where t.code = p_doc_type_code;
  if v_prefix is null then
    raise exception 'next_doc_number: unknown doc type %', p_doc_type_code using errcode = '22023';
  end if;
  insert into docs.doc_counters (org_id, doc_type_code, year, last_no) values (p_org_id, p_doc_type_code, v_year, 1)
  on conflict (org_id, doc_type_code, year) do update set last_no = docs.doc_counters.last_no + 1
  returning last_no into v_no;

  select s.doc_number_format into v_fmt from docs.workspace_settings s where s.org_id = p_org_id;
  v_fmt := coalesce(v_fmt, '{PREFIX}-{YYYY}-{SEQ:4}');
  v_width := coalesce(nullif(substring(v_fmt from '\{SEQ:([0-9])\}'), '')::integer, 4);
  v_out := replace(replace(replace(replace(v_fmt, '{PREFIX}', v_prefix), '{TYPE}', v_prefix), '{YYYY}', v_year::text), '{YY}', right(v_year::text, 2));
  v_out := regexp_replace(v_out, '\{SEQ(:[0-9])?\}', lpad(v_no::text, greatest(v_width, char_length(v_no::text)), '0'));
  return v_out;
end;
$$;

-- 23.2 checklist_answers_hash: 효과 엔진 미리보기와 적용 사이에 입력이 바뀌었는지 판정(DC010).
--      입력 = 고정 체크리스트 버전 + 기본 일단가 + 단가 카탈로그(defaults) + 확정 답 전부(키 순, 항목 version 포함)
--      항목 version 을 넣어 카탈로그 효과가 바뀐 경우도 DC010 으로 잡는다(교차검증 #6).
create or replace function docs.checklist_answers_hash(p_project_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select md5(
    coalesce((select p.checklist_version::text from docs.projects p where p.id = p_project_id), '') || '|' ||
    coalesce((select s.default_day_rate_krw::text || '|' || md5(s.defaults::text)
              from docs.projects p join docs.workspace_settings s on s.org_id = p.org_id
              where p.id = p_project_id), '0') || '|' ||
    coalesce((select string_agg(a.item_key || '@' || coalesce(i.version, 0)::text || '=' || a.value::text, '|' order by a.item_key)
              from docs.checklist_answers a left join docs.checklist_items i on i.key = a.item_key
              where a.project_id = p_project_id and a.is_confirmed), '')
  );
$$;

-- 23.3 apply_checklist_effects (service_role): Route Handler 가 TS computeEffects 로 계산한 목표 집합을 한 트랜잭션으로 반영.
--      p_plan = {"requirements":[{source_key,kind,title,description,priority,acceptance_criteria,sort_order}],
--                "artifacts":[{source_key,kind,name,attributes,sort_order}],
--                "line_items":[{source_key,category,name,unit,quantity,unit_price_krw,sort_order}],
--                "links":[{requirement_key, artifact_key}]}
--      규칙(01_PRD 3.2절): 목표에만 있음 INSERT / 둘 다 + 사용자 미수정 UPDATE / 둘 다 + 사용자 수정 유지 /
--      현재에만 + 미수정 DELETE(문서가 추적 중인 요구사항은 status='rejected') / 현재에만 + 수정 유지.
--      사용자(authenticated)에게 열지 않는 이유: p_plan 은 서버 계산 결과여야 하며 source='checklist' 행을 만들 수 있기 때문.
create or replace function docs.apply_checklist_effects(p_project_id uuid, p_plan jsonb, p_expected_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project docs.projects;
  v_added   integer := 0;
  v_updated integer := 0;
  v_removed integer := 0;
  v_kept    integer := 0;
  v_n       integer;
  e         record;
begin
  if not core.is_privileged_session() then
    raise exception 'apply_checklist_effects: service_role only' using errcode = '42501';
  end if;
  if p_plan is null or jsonb_typeof(p_plan) <> 'object' then
    raise exception 'apply_checklist_effects: plan must be an object' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('docs:effects:' || p_project_id::text));
  select * into v_project from docs.projects p where p.id = p_project_id and p.deleted_at is null for update;
  if not found then
    raise exception 'apply_checklist_effects: project not found' using errcode = 'P0002';
  end if;
  if v_project.status = 'archived' then
    raise exception 'apply_checklist_effects: project is archived' using errcode = 'DC001';
  end if;
  if docs.checklist_answers_hash(p_project_id) is distinct from p_expected_hash then
    raise exception 'apply_checklist_effects: answers changed since preview' using errcode = 'DC010';
  end if;

  -- 요구사항: 목표 순서대로(같은 입력이면 같은 번호)
  for e in select x.value as v from jsonb_array_elements(coalesce(p_plan -> 'requirements', '[]'::jsonb)) with ordinality as x(value, n) order by x.n loop
    update docs.requirements r
       set title = e.v ->> 'title', description = e.v ->> 'description',
           priority = coalesce(e.v ->> 'priority', 'should'), acceptance_criteria = e.v ->> 'acceptance_criteria',
           sort_order = coalesce((e.v ->> 'sort_order')::integer, r.sort_order)
     where r.project_id = p_project_id and r.source = 'checklist' and r.source_key = e.v ->> 'source_key' and not r.is_user_modified
       and (r.title, r.description, r.priority, r.acceptance_criteria) is distinct from
           (e.v ->> 'title', e.v ->> 'description', coalesce(e.v ->> 'priority', 'should'), e.v ->> 'acceptance_criteria');
    get diagnostics v_n = row_count;
    v_updated := v_updated + v_n;
    -- 체크 해제로 rejected 가 된 엔진 행이 목표에 다시 들어오면 accepted 로 되돌린다(교차검증 #7).
    update docs.requirements r set status = 'accepted'
     where r.project_id = p_project_id and r.source = 'checklist' and r.source_key = e.v ->> 'source_key'
       and not r.is_user_modified and r.status = 'rejected';
    get diagnostics v_n = row_count;
    v_updated := v_updated + v_n;
    if not exists (select 1 from docs.requirements r where r.project_id = p_project_id and r.source = 'checklist' and r.source_key = e.v ->> 'source_key') then
      insert into docs.requirements (org_id, project_id, kind, title, description, priority, acceptance_criteria, source, source_key, status, sort_order)
      values (v_project.org_id, p_project_id, e.v ->> 'kind', e.v ->> 'title', e.v ->> 'description', coalesce(e.v ->> 'priority', 'should'),
              e.v ->> 'acceptance_criteria', 'checklist', e.v ->> 'source_key', 'accepted', coalesce((e.v ->> 'sort_order')::integer, 100));
      v_added := v_added + 1;
    end if;
  end loop;

  for e in select x.value as v from jsonb_array_elements(coalesce(p_plan -> 'artifacts', '[]'::jsonb)) with ordinality as x(value, n) order by x.n loop
    update docs.artifacts a
       set name = e.v ->> 'name', attributes = coalesce(e.v -> 'attributes', '{}'::jsonb),
           sort_order = coalesce((e.v ->> 'sort_order')::integer, a.sort_order)
     where a.project_id = p_project_id and a.source = 'checklist' and a.source_key = e.v ->> 'source_key' and not a.is_user_modified
       and (a.name, a.attributes) is distinct from (e.v ->> 'name', coalesce(e.v -> 'attributes', '{}'::jsonb));
    get diagnostics v_n = row_count;
    v_updated := v_updated + v_n;
    if not exists (select 1 from docs.artifacts a where a.project_id = p_project_id and a.source = 'checklist' and a.source_key = e.v ->> 'source_key') then
      insert into docs.artifacts (org_id, project_id, kind, name, attributes, source, source_key, sort_order)
      values (v_project.org_id, p_project_id, e.v ->> 'kind', e.v ->> 'name', coalesce(e.v -> 'attributes', '{}'::jsonb),
              'checklist', e.v ->> 'source_key', coalesce((e.v ->> 'sort_order')::integer, 100));
      v_added := v_added + 1;
    end if;
  end loop;

  for e in select x.value as v from jsonb_array_elements(coalesce(p_plan -> 'line_items', '[]'::jsonb)) with ordinality as x(value, n) order by x.n loop
    update docs.line_items l
       set category = e.v ->> 'category', name = e.v ->> 'name', unit = e.v ->> 'unit',
           quantity = (e.v ->> 'quantity')::numeric, unit_price_krw = (e.v ->> 'unit_price_krw')::bigint,
           sort_order = coalesce((e.v ->> 'sort_order')::integer, l.sort_order)
     where l.project_id = p_project_id and l.source = 'checklist' and l.source_key = e.v ->> 'source_key' and not l.is_user_modified
       and (l.category, l.name, l.unit, l.quantity, l.unit_price_krw) is distinct from
           (e.v ->> 'category', e.v ->> 'name', e.v ->> 'unit', (e.v ->> 'quantity')::numeric, (e.v ->> 'unit_price_krw')::bigint);
    get diagnostics v_n = row_count;
    v_updated := v_updated + v_n;
    if not exists (select 1 from docs.line_items l where l.project_id = p_project_id and l.source = 'checklist' and l.source_key = e.v ->> 'source_key') then
      insert into docs.line_items (org_id, project_id, category, name, unit, quantity, unit_price_krw, source, source_key, sort_order)
      values (v_project.org_id, p_project_id, e.v ->> 'category', e.v ->> 'name', e.v ->> 'unit', (e.v ->> 'quantity')::numeric,
              (e.v ->> 'unit_price_krw')::bigint, 'checklist', e.v ->> 'source_key', coalesce((e.v ->> 'sort_order')::integer, 100));
      v_added := v_added + 1;
    end if;
  end loop;

  -- 목표에 없는 엔진 행: 사용자 수정분은 유지, 나머지는 제거(추적 중인 요구사항은 rejected)
  select count(*) into v_n from (
    select 1 from docs.requirements r where r.project_id = p_project_id and r.source = 'checklist' and r.is_user_modified
       and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'requirements', '[]'::jsonb)) x where x.value ->> 'source_key' = r.source_key)
    union all
    select 1 from docs.artifacts a where a.project_id = p_project_id and a.source = 'checklist' and a.is_user_modified
       and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'artifacts', '[]'::jsonb)) x where x.value ->> 'source_key' = a.source_key)
    union all
    select 1 from docs.line_items l where l.project_id = p_project_id and l.source = 'checklist' and l.is_user_modified
       and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'line_items', '[]'::jsonb)) x where x.value ->> 'source_key' = l.source_key)
  ) k;
  v_kept := v_n;

  update docs.requirements r set status = 'rejected'
   where r.project_id = p_project_id and r.source = 'checklist' and not r.is_user_modified and r.status <> 'rejected'
     and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'requirements', '[]'::jsonb)) x where x.value ->> 'source_key' = r.source_key)
     and exists (select 1 from docs.trace_links t where t.requirement_id = r.id and t.document_id is not null);
  get diagnostics v_n = row_count;
  v_removed := v_removed + v_n;
  delete from docs.requirements r
   where r.project_id = p_project_id and r.source = 'checklist' and not r.is_user_modified
     and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'requirements', '[]'::jsonb)) x where x.value ->> 'source_key' = r.source_key)
     and not exists (select 1 from docs.trace_links t where t.requirement_id = r.id and t.document_id is not null);
  get diagnostics v_n = row_count;
  v_removed := v_removed + v_n;
  delete from docs.artifacts a
   where a.project_id = p_project_id and a.source = 'checklist' and not a.is_user_modified
     and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'artifacts', '[]'::jsonb)) x where x.value ->> 'source_key' = a.source_key);
  get diagnostics v_n = row_count;
  v_removed := v_removed + v_n;
  delete from docs.line_items l
   where l.project_id = p_project_id and l.source = 'checklist' and not l.is_user_modified
     and not exists (select 1 from jsonb_array_elements(coalesce(p_plan -> 'line_items', '[]'::jsonb)) x where x.value ->> 'source_key' = l.source_key);
  get diagnostics v_n = row_count;
  v_removed := v_removed + v_n;

  -- 요구사항 -> 화면 추적(효과 links). 문서 없는 엔진 링크는 대상이 지워지면 다시 계산되므로 추가만 한다.
  insert into docs.trace_links (org_id, requirement_id, to_kind, to_ref)
  select v_project.org_id, r.id, 'artifact', a.id::text
  from jsonb_array_elements(coalesce(p_plan -> 'links', '[]'::jsonb)) x
  join docs.requirements r on r.project_id = p_project_id and r.source = 'checklist' and r.source_key = x.value ->> 'requirement_key'
  join docs.artifacts a on a.project_id = p_project_id and a.source = 'checklist' and a.source_key = x.value ->> 'artifact_key'
  on conflict do nothing;
  delete from docs.trace_links t
   where t.org_id = v_project.org_id and t.to_kind = 'artifact' and t.document_id is null
     and t.requirement_id in (select r.id from docs.requirements r where r.project_id = p_project_id)
     and not exists (select 1 from docs.artifacts a where a.id::text = t.to_ref);

  perform core.write_audit(v_project.org_id, 'docs_project.apply_effects', 'docs_project', p_project_id::text, null,
                           jsonb_build_object('added', v_added, 'updated', v_updated, 'removed', v_removed, 'kept', v_kept));
  return jsonb_build_object('added', v_added, 'updated', v_updated, 'removed', v_removed, 'kept', v_kept);
end;
$$;

-- 23.4 start_generation (service_role): 실행 기록 + 크레딧 선차감 + 잡 enqueue 를 한 트랜잭션으로.
--      어느 단계에서 실패해도 전부 롤백되므로 "과금만 되고 잡이 없는" 상태가 생기지 않는다(SellingDocs #2).
--      문서 실행: p_doc_type_code 필수. p_document_id 가 null 이면 문서를 새로 만든다(draft -> generating).
--      패키지 부모 실행: p_package_code 필수, p_document_id·p_doc_type_code null, p_credits 0(자식 단위 차감).
--      패키지 자식 실행: p_parent_job_id = 부모 잡. 조직 동시 생성 수는 부모 1건으로 센다.
--      멱등 키 gen:docs:<request_id> -> consume:docs:<request_id>, job:docs:<request_id>
create or replace function docs.start_generation(
  p_org_id          uuid,
  p_project_id      uuid,
  p_document_id     uuid,
  p_doc_type_code   text,
  p_package_code    text,
  p_parent_job_id   uuid,
  p_credits         integer,
  p_idempotency_key text,
  p_actor           uuid
)
returns docs.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run       docs.generation_runs;
  v_project   docs.projects;
  v_doc       docs.documents;
  v_type      docs.doc_types;
  v_parent    docs.generation_runs;
  v_features  jsonb;
  v_phase     text;
  v_rid       text;
  v_credits   integer;
  v_max       integer;
  v_active    integer;
  v_ledger    bigint;
  v_job       core.jobs;
  v_run_id    uuid := gen_random_uuid();
begin
  if not core.is_privileged_session() then
    raise exception 'start_generation: service_role only' using errcode = '42501';
  end if;
  -- 패키지 자식은 gen:docs:<run_id>:<doc_type_code> 이므로 ':' 와 '_' 를 허용한다(교차검증 #12).
  if p_idempotency_key is null or p_idempotency_key !~ '^gen:docs:[A-Za-z0-9][A-Za-z0-9_:-]{7,119}$' then
    raise exception 'start_generation: idempotency key must be gen:docs:<request_id>' using errcode = '22023';
  end if;
  if (p_package_code is null) = (p_doc_type_code is null) then
    raise exception 'start_generation: exactly one of doc_type_code, package_code' using errcode = '22023';
  end if;
  if p_package_code is not null and p_document_id is not null then
    raise exception 'start_generation: package run has no document' using errcode = '22023';
  end if;
  v_rid := substring(p_idempotency_key from 10);

  perform pg_advisory_xact_lock(hashtext('docs:gen:' || p_idempotency_key));
  select * into v_run from docs.generation_runs r where r.idempotency_key = p_idempotency_key;
  if found then
    if v_run.org_id <> p_org_id then
      raise exception 'start_generation: idempotency key belongs to another organization' using errcode = '42501';
    end if;
    return v_run;
  end if;

  if not exists (select 1 from core.org_members m
                 where m.org_id = p_org_id and m.user_id = p_actor and m.status = 'active'
                   and coalesce(m.role, '') in ('owner', 'admin', 'member')) then
    raise exception 'start_generation: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(p_org_id, 'docs') then
    raise exception 'start_generation: no entitlement' using errcode = '42501';
  end if;

  select * into v_project from docs.projects p
  where p.id = p_project_id and p.org_id = p_org_id and p.deleted_at is null for update;
  if not found then
    raise exception 'start_generation: project not found' using errcode = 'P0002';
  end if;
  if v_project.status = 'archived' then
    raise exception 'start_generation: project is archived' using errcode = 'DC001';
  end if;

  -- core.cancel_job 이나 잡 정리기로 잡만 끝난 실행을 먼저 정리한다(그렇지 않으면 DC002·DC006 으로 영구 차단, 교차검증 #3)
  perform docs.reconcile_generation_runs(p_org_id);

  v_features := docs.org_features(p_org_id);
  v_phase := coalesce(v_features ->> 'doc_phase', 'mvp');

  if p_parent_job_id is not null then
    select * into v_parent from docs.generation_runs r
    where r.job_id = p_parent_job_id and r.org_id = p_org_id and r.project_id = p_project_id and r.document_id is null;
    if not found then
      raise exception 'start_generation: parent package run not found' using errcode = 'P0002';
    end if;
  end if;

  if p_doc_type_code is not null then
    select * into v_type from docs.doc_types t where t.code = p_doc_type_code and t.is_active;
    if not found then
      raise exception 'start_generation: doc type % is not available', p_doc_type_code using errcode = '22023';
    end if;
    if not (v_type.phase = 'mvp' or (v_type.phase = 'phase2' and v_phase in ('phase2', 'phase3')) or (v_type.phase = 'phase3' and v_phase = 'phase3')) then
      raise exception 'start_generation: doc type % requires plan phase %', p_doc_type_code, v_type.phase using errcode = 'DC006';
    end if;
    if v_type.risk_level = 'high' and not exists (
         select 1 from docs.risk_acknowledgements k
         where k.org_id = p_org_id and k.doc_type_code = v_type.code and k.notice_version = v_type.notice_version) then
      raise exception 'start_generation: risk notice % not acknowledged', v_type.notice_version using errcode = 'DC007';
    end if;
    v_credits := coalesce(p_credits, v_type.credits);

    if p_document_id is null then
      insert into docs.documents (org_id, project_id, doc_type_code, title, created_by)
      values (p_org_id, p_project_id, p_doc_type_code, v_type.name, p_actor)
      returning * into v_doc;
    else
      select * into v_doc from docs.documents d
      where d.id = p_document_id and d.org_id = p_org_id and d.project_id = p_project_id for update;
      if not found then
        raise exception 'start_generation: document not found' using errcode = 'P0002';
      end if;
      if v_doc.doc_type_code <> p_doc_type_code then
        raise exception 'start_generation: doc type mismatch' using errcode = '22023';
      end if;
      if v_doc.status = 'generating' then
        raise exception 'start_generation: generation already running for this document' using errcode = 'DC002';
      end if;
      if v_doc.status in ('final', 'archived') then
        raise exception 'start_generation: document is %', v_doc.status using errcode = 'DC003';
      end if;
    end if;
    if exists (select 1 from docs.generation_runs r where r.document_id = v_doc.id and r.status in ('queued', 'running')) then
      raise exception 'start_generation: generation already running for this document' using errcode = 'DC002';
    end if;
  else
    v_credits := coalesce(p_credits, 0);
    if exists (select 1 from docs.generation_runs r
               where r.project_id = p_project_id and r.package_code = p_package_code and r.document_id is null
                 and r.status in ('queued', 'running')) then
      raise exception 'start_generation: package already running' using errcode = 'DC002';
    end if;
  end if;
  if v_credits < 0 then
    raise exception 'start_generation: credits must be >= 0' using errcode = '22023';
  end if;

  -- 조직 동시 생성(패키지 1건 = 1건, 자식은 세지 않음)과 일일 플랫폼 상한(KST 자정 기준)
  if p_parent_job_id is null then
    select c.value_int into v_max from docs.runtime_config c where c.key = 'max_active_generations_per_org';
    select count(*) into v_active from docs.generation_runs r
    where r.org_id = p_org_id and r.parent_run_id is null and r.status in ('queued', 'running');
    if v_active >= coalesce(v_max, 3) then
      raise exception 'start_generation: too many active generations for this organization' using errcode = 'DC006';
    end if;
  end if;
  perform docs.charge_daily_cap(v_credits);

  -- 선차감(원자, 멱등). 부족하면 CR001 로 전체 롤백(문서 생성 포함)
  if v_credits > 0 then
    select c.ledger_id into v_ledger
    from core.consume_credits(p_org_id, v_credits, 'docs', 'docs.generate', 'docs_generation_run', v_run_id::text,
                              'consume:docs:gen:' || v_rid,   -- 생성 전용 네임스페이스(reserve_credits 는 gen: 을 쓰지 못한다)
                              jsonb_build_object('project_id', p_project_id, 'document_id', v_doc.id, 'doc_type_code', p_doc_type_code,
                                                 'package_code', p_package_code), p_actor) c;
  end if;

  insert into docs.generation_runs (id, org_id, project_id, document_id, doc_type_code, package_code, parent_run_id,
                                    credits_reserved, credit_ledger_id, idempotency_key, created_by)
  values (v_run_id, p_org_id, p_project_id, v_doc.id, p_doc_type_code,
          coalesce(p_package_code, v_parent.package_code), v_parent.id, v_credits, v_ledger, p_idempotency_key, p_actor)
  returning * into v_run;

  select * into v_job from core.enqueue_job(
    p_org_id, 'docs', 'docs.generate', case when p_package_code is not null then 'docs.package' else 'docs.generate' end,
    jsonb_build_object('run_id', v_run_id, 'project_id', p_project_id, 'document_id', v_doc.id,
                       'doc_type_code', p_doc_type_code, 'package_code', p_package_code),
    100, now(), 3, v_ledger, 'job:docs:' || v_rid, p_parent_job_id, p_actor, true);

  update docs.generation_runs set job_id = v_job.id where id = v_run_id returning * into v_run;
  if v_doc.id is not null then
    update docs.documents set status = 'generating', needs_regeneration = false where id = v_doc.id;
  end if;
  return v_run;
end;
$$;

-- 23.5 finish_generation (service_role): 버전 저장 + 문서 review + 실행 succeeded 를 한 트랜잭션으로.
--      패키지 부모 실행(document 없음)은 실행 상태만 succeeded 로 닫고 null 을 돌려준다.
create or replace function docs.finish_generation(
  p_run_id      uuid,
  p_content     jsonb,
  p_body_html   text,
  p_variables   jsonb,
  p_inputs_hash text,
  p_lint        jsonb,
  p_verdict     text,
  p_ai_run_id   uuid default null
)
returns docs.document_versions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run  docs.generation_runs;
  v_doc  docs.documents;
  v_ver  docs.document_versions;
  v_dtv  integer;
begin
  if not core.is_privileged_session() then
    raise exception 'finish_generation: service_role only' using errcode = '42501';
  end if;
  select * into v_run from docs.generation_runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'finish_generation: run not found' using errcode = 'P0002';
  end if;
  if v_run.status not in ('queued', 'running') then
    raise exception 'finish_generation: run is already %', v_run.status using errcode = 'DC001';
  end if;
  if v_run.status = 'queued' then
    update docs.generation_runs set status = 'running', started_at = now() where id = p_run_id;
  end if;

  -- 결과를 넘긴 실행은 잡이 나중에 실패로 끝나도 환불하지 않는다(교차검증 #4). 같은 트랜잭션에서 잡의 환불 표시를 끈다.
  -- core 함수는 고치지 않고 이 실행이 소유한 잡 행의 refund_on_failure 만 바꾼다(core.fail_job 이 이 값을 본다).
  if v_run.job_id is not null then
    update core.jobs set refund_on_failure = false where id = v_run.job_id and refund_on_failure;
  end if;

  if v_run.document_id is null then
    update docs.generation_runs set status = 'succeeded', finished_at = now(), credits_settled = credits_reserved,
           ai_run_id = coalesce(p_ai_run_id, ai_run_id), progress = jsonb_build_object('stage', 'done', 'at', now())
    where id = p_run_id;
    return null;
  end if;

  if p_verdict is null or p_verdict not in ('pass', 'warn', 'fail', 'skipped') then
    raise exception 'finish_generation: invalid verdict %', p_verdict using errcode = '22023';
  end if;
  if p_content is null or jsonb_typeof(p_content) <> 'array' then
    raise exception 'finish_generation: content must be a section array' using errcode = '22023';
  end if;
  if p_body_html is not null and octet_length(p_body_html) > 2097152 then
    raise exception 'finish_generation: body_html exceeds 2MB' using errcode = '22023';
  end if;

  select * into v_doc from docs.documents d where d.id = v_run.document_id for update;
  if v_doc.status <> 'generating' then
    raise exception 'finish_generation: document is %', v_doc.status using errcode = 'DC001';
  end if;
  select max(v.version) into v_dtv from docs.doc_type_versions v
  where v.doc_type_code = v_doc.doc_type_code and v.published_at is not null;

  insert into docs.document_versions (org_id, document_id, version, doc_type_version, content, body_html, variables_snapshot,
                                      inputs_hash, lint_result, compliance_verdict, created_kind, generation_run_id, created_by)
  values (v_doc.org_id, v_doc.id, v_doc.current_version + 1, coalesce(v_dtv, 1), p_content, p_body_html,
          coalesce(p_variables, '{}'::jsonb), p_inputs_hash, coalesce(p_lint, '{"errors": [], "warnings": []}'::jsonb),
          p_verdict, 'generated', p_run_id, v_run.created_by)
  returning * into v_ver;

  update docs.documents set status = 'review' where id = v_doc.id;   -- needs_regeneration 은 start 에서 지웠다(생성 중 변경 보존)
  update docs.generation_runs set status = 'succeeded', finished_at = now(), credits_settled = credits_reserved,
         ai_run_id = coalesce(p_ai_run_id, ai_run_id), progress = jsonb_build_object('stage', 'done', 'at', now())
  where id = p_run_id;
  return v_ver;
end;
$$;

-- 23.6 fail_generation (service_role): 실행 failed + 문서를 이전 상태로. 크레딧 환불은 core.fail_job 이 같은 원장 행으로
--      한다(멱등 키 refund:job:<job_id>). 여기서 환불하지 않아 이중 환불이 생기지 않는다.
--      호출 순서(교차검증 #5): 워커는 재시도가 남은 실패에서는 이 함수를 부르지 않고 core.fail_job(retryable)만 부른다.
--      마지막 시도 실패(또는 재시도 불가 오류)에서만 이 함수 → core.fail_job(retryable=false) 순서로 부른다.
--      재시도 잡이 시작될 때 실행이 이미 succeeded 면 워커는 그래프를 다시 돌리지 않고 core.complete_job 으로 끝낸다.
create or replace function docs.fail_generation(p_run_id uuid, p_error text)
returns docs.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare v_run docs.generation_runs;
begin
  if not core.is_privileged_session() then
    raise exception 'fail_generation: service_role only' using errcode = '42501';
  end if;
  select * into v_run from docs.generation_runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'fail_generation: run not found' using errcode = 'P0002';
  end if;
  if v_run.status not in ('queued', 'running') then
    raise exception 'fail_generation: run is already %', v_run.status using errcode = 'DC001';
  end if;
  update docs.generation_runs
     set status = 'failed', finished_at = now(), credits_settled = 0, error = left(p_error, 1000)
   where id = p_run_id returning * into v_run;
  if v_run.document_id is not null then
    update docs.documents
       set status = case when current_version > 0 then 'review' else 'draft' end
     where id = v_run.document_id and status = 'generating';
  end if;
  return v_run;
end;
$$;

-- 23.6a reconcile_generation_runs (service_role, 내부 호출): 잡은 끝났는데 실행이 queued/running 으로 남은 행을 정리한다.
--       잡 canceled -> 실행 canceled, 잡 failed -> 실행 failed. 문서는 generating 에서 이전 상태로 돌린다.
--       start_generation·cancel_generation 이 먼저 부르고, 정리 스케줄(DC-06-051 sweeper)도 부른다.
create or replace function docs.reconcile_generation_runs(p_org_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_n integer := 0; r record;
begin
  if not core.is_privileged_session() and not core.is_service_caller()
     and not (p_org_id is not null and core.has_org_role(p_org_id, array['owner', 'admin', 'member'])) then
    raise exception 'reconcile_generation_runs: not allowed' using errcode = '42501';
  end if;
  for r in
    select g.id, g.document_id, j.status as job_status
    from docs.generation_runs g join core.jobs j on j.id = g.job_id
    where g.status in ('queued', 'running') and j.status in ('canceled', 'failed')
      and (p_org_id is null or g.org_id = p_org_id)
    for update of g
  loop
    update docs.generation_runs
       set status = case when r.job_status = 'canceled' then 'canceled' else 'failed' end,
           finished_at = now(), credits_settled = 0,
           error = coalesce(error, 'job ' || r.job_status), progress = jsonb_build_object('stage', r.job_status, 'at', now())
     where id = r.id;
    if r.document_id is not null then
      update docs.documents set status = case when current_version > 0 then 'review' else 'draft' end
       where id = r.document_id and status = 'generating';
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- 23.6b cancel_generation (authenticated owner/admin 또는 실행을 시작한 member): 대기 중 생성 취소(교차검증 #3).
--       잡 취소(환불 포함, core.cancel_job) + 실행 canceled + 문서 복구를 한 트랜잭션으로. 화면은 이 RPC 만 쓴다.
--       running 실행은 취소하지 않는다(DC001): 그래프가 이미 비용을 쓰고 있어 결과를 받거나 실패 환불로 끝낸다.
create or replace function docs.cancel_generation(p_run_id uuid)
returns docs.generation_runs
language plpgsql
security definer
set search_path = ''
as $$
declare v_run docs.generation_runs; v_job core.jobs;
begin
  select * into v_run from docs.generation_runs r where r.id = p_run_id for update;
  if not found then
    raise exception 'cancel_generation: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_run.org_id, array['owner', 'admin'])
     and not (core.has_org_role(v_run.org_id, array['member']) and v_run.created_by is not distinct from auth.uid()) then
    raise exception 'cancel_generation: owner/admin or the requester only' using errcode = '42501';
  end if;
  perform docs.reconcile_generation_runs(v_run.org_id);
  select * into v_run from docs.generation_runs r where r.id = p_run_id;
  if v_run.status <> 'queued' then
    raise exception 'cancel_generation: run is % (only queued runs can be canceled)', v_run.status using errcode = 'DC001';
  end if;
  if v_run.job_id is not null then
    select * into v_job from core.jobs j where j.id = v_run.job_id;
    if v_job.status = 'queued' then
      perform core.cancel_job(v_run.job_id);
    elsif v_job.status = 'running' then
      raise exception 'cancel_generation: job already started' using errcode = 'DC001';
    end if;
  end if;
  -- 패키지 부모면 대기 중인 자식 실행도 함께 취소한다
  perform core.cancel_job(c.job_id)
    from docs.generation_runs c join core.jobs j on j.id = c.job_id
   where c.parent_run_id = v_run.id and c.status = 'queued' and j.status = 'queued';
  -- 자식은 잡이 실제로 취소된 것만 닫는다(잡이 이미 running 이면 그 자식은 끝까지 진행)
  update docs.generation_runs g set status = 'canceled', finished_at = now(), credits_settled = 0,
         progress = jsonb_build_object('stage', 'canceled', 'at', now())
   where g.id = v_run.id
      or (g.parent_run_id = v_run.id and g.status = 'queued'
          and (g.job_id is null or exists (select 1 from core.jobs j where j.id = g.job_id and j.status = 'canceled')));
  update docs.documents d set status = case when d.current_version > 0 then 'review' else 'draft' end
   where d.status = 'generating'
     and d.id in (select g.document_id from docs.generation_runs g
                  where (g.id = v_run.id or g.parent_run_id = v_run.id) and g.status = 'canceled' and g.document_id is not null);
  select * into v_run from docs.generation_runs r where r.id = p_run_id;
  perform core.write_audit(v_run.org_id, 'docs_generation.cancel', 'docs_generation_run', p_run_id::text);
  return v_run;
end;
$$;

-- 23.6c report_generation_progress (service_role): 단계별 진행 표시(DC-F-048). 종료된 실행은 무시한다(조용히 0행).
create or replace function docs.report_generation_progress(p_run_id uuid, p_stage text, p_section_key text, p_step integer, p_total integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'report_generation_progress: service_role only' using errcode = '42501';
  end if;
  if p_stage not in ('queued', 'collecting', 'drafting', 'assembling', 'linting', 'rendering')
     or p_step < 0 or p_total < 0 or p_step > p_total or (p_section_key is not null and p_section_key !~ '^[a-z][a-z0-9_]{0,40}$') then
    raise exception 'report_generation_progress: invalid progress' using errcode = '22023';
  end if;
  update docs.generation_runs
     set progress = jsonb_build_object('stage', p_stage, 'section_key', p_section_key, 'step', p_step, 'total', p_total, 'at', now()),
         status = case when status = 'queued' then 'running' else status end,
         started_at = coalesce(started_at, now())
   where id = p_run_id and status in ('queued', 'running');
end;
$$;

-- 23.6d charge_daily_cap (내부): 일일 플랫폼 상한 확인 + 사용량 가산(같은 트랜잭션). 초과면 DC006.
create or replace function docs.charge_daily_cap(p_credits integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_cap integer; v_day date := (now() at time zone 'Asia/Seoul')::date; v_used bigint;
begin
  if not core.is_privileged_session() then
    raise exception 'charge_daily_cap: service_role only' using errcode = '42501';
  end if;
  if coalesce(p_credits, 0) <= 0 then
    return;
  end if;
  select c.value_int into v_cap from docs.runtime_config c where c.key = 'daily_credit_cap';
  insert into docs.daily_credit_usage (day, credits) values (v_day, 0) on conflict (day) do nothing;
  select u.credits into v_used from docs.daily_credit_usage u where u.day = v_day for update;
  if v_cap is not null and v_used + p_credits > v_cap then
    raise exception 'daily platform budget exhausted' using errcode = 'DC006';
  end if;
  update docs.daily_credit_usage set credits = credits + p_credits where day = v_day;
end;
$$;

-- 23.6e reserve_credits (service_role): 생성 밖의 모든 docs 차감(추출, 회의록, 다시 쓰기, 채팅 턴, 음성, 색인, 내보내기)의
--       단일 입구. 일일 상한 + core.consume_credits 를 한 트랜잭션으로 한다(교차검증 #11). 멱등 키가 이미 쓰였으면
--       상한을 다시 세지 않고 기존 원장 행을 돌려준다. Route Handler 는 core.consume_credits 를 직접 부르지 않는다.
create or replace function docs.reserve_credits(
  p_org_id uuid, p_actor uuid, p_credits integer, p_reason text, p_ref_type text, p_ref_id text,
  p_idempotency_key text, p_metadata jsonb default '{}'::jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_ledger bigint; v_row core.credit_ledger;
begin
  if not core.is_privileged_session() then
    raise exception 'reserve_credits: service_role only' using errcode = '42501';
  end if;
  if p_credits is null or p_credits <= 0 or p_reason !~ '^(docs\.[a-z_.]+|chat|voice\.[a-z_]+|render\.[a-z]+|rag\.index)$' then
    raise exception 'reserve_credits: invalid arguments' using errcode = '22023';
  end if;
  -- 키 형식: consume:docs:<작업>:<request_id>(작업 = extract, minutes, assist, render, index, export ...), conv:<id>:turn:<n>, voice:<id>.
  -- consume:docs:gen: 은 start_generation 전용이다. 같은 키를 다른 작업·금액·조직이 쓰면 거부한다(2026-10-14 검토: 키 재사용 과금 우회).
  if p_idempotency_key is null
     or p_idempotency_key !~ '^(consume:docs:[a-z_]{2,20}:|conv:|voice:)[A-Za-z0-9][A-Za-z0-9_:-]{7,119}$'
     or p_idempotency_key like 'consume:docs:gen:%' then
    raise exception 'reserve_credits: invalid idempotency key' using errcode = '22023';
  end if;
  select * into v_row from core.credit_ledger l where l.idempotency_key = p_idempotency_key;
  if found then
    if v_row.org_id <> p_org_id then
      raise exception 'reserve_credits: idempotency key belongs to another organization' using errcode = '42501';
    end if;
    if v_row.entry_type <> 'consume' or v_row.amount <> -p_credits or v_row.reason is distinct from p_reason then
      raise exception 'reserve_credits: idempotency key reused for a different charge' using errcode = '22023';
    end if;
    return v_row.id;
  end if;
  perform docs.charge_daily_cap(p_credits);
  select c.ledger_id into v_ledger
  from core.consume_credits(p_org_id, p_credits, 'docs', p_reason, p_ref_type, p_ref_id, p_idempotency_key,
                            coalesce(p_metadata, '{}'::jsonb), p_actor) c;
  return v_ledger;
end;
$$;

-- 23.7 upsert_external_ref (service_role): 외부 매핑 1:1. 연결이 active 가 아니면 DC009.
--      내부 행이 연결과 같은 조직인지 확인한다(다른 조직 엔티티를 외부와 묶지 못함).
create or replace function docs.upsert_external_ref(
  p_connection_id uuid,
  p_entity        text,
  p_internal_id   uuid,
  p_external_type text,
  p_external_id   text,
  p_etag          text default null
)
returns docs.external_refs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conn docs.integration_connections;
  v_ok   boolean;
  v_row  docs.external_refs;
begin
  if not core.is_privileged_session() then
    raise exception 'upsert_external_ref: service_role only' using errcode = '42501';
  end if;
  select * into v_conn from docs.integration_connections c where c.id = p_connection_id for share;
  if not found then
    raise exception 'upsert_external_ref: connection not found' using errcode = 'P0002';
  end if;
  if v_conn.status <> 'active' then
    raise exception 'upsert_external_ref: connection is %', v_conn.status using errcode = 'DC009';
  end if;
  v_ok := case p_entity
    when 'party'     then exists (select 1 from docs.parties x where x.id = p_internal_id and x.org_id = v_conn.org_id)
    when 'project'   then exists (select 1 from docs.projects x where x.id = p_internal_id and x.org_id = v_conn.org_id)
    when 'line_item' then exists (select 1 from docs.line_items x where x.id = p_internal_id and x.org_id = v_conn.org_id)
    when 'document'  then exists (select 1 from docs.documents x where x.id = p_internal_id and x.org_id = v_conn.org_id)
    else null end;
  if v_ok is null then
    raise exception 'upsert_external_ref: invalid entity %', p_entity using errcode = '22023';
  end if;
  if not v_ok then
    raise exception 'upsert_external_ref: internal % % not in connection organization', p_entity, p_internal_id using errcode = '42501';
  end if;
  insert into docs.external_refs (org_id, connection_id, entity, internal_id, external_type, external_id, etag, last_synced_at)
  values (v_conn.org_id, p_connection_id, p_entity, p_internal_id, p_external_type, p_external_id, p_etag, now())
  on conflict (connection_id, entity, internal_id) do update
    set external_type = excluded.external_type, external_id = excluded.external_id, etag = excluded.etag, last_synced_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

-- 23.8 finalize_document (authenticated owner/admin): 확정 게이트 후 문서번호 부여.
--      검사 순서: 상태(DC001) -> 버전 일치·정본 최신성(DC010) -> 필수 입력(DC004) -> lint 미실행·lint 오류·compliance FAIL(DC005)
--               -> WARN 확인(DC008) -> 고위험 고지(DC007). 확정 문서·보관 문서는 DC003.
--      정본 최신성(교차검증 #2): needs_regeneration=true(단가·체크리스트 변경 뒤)이거나, 생성 버전의 inputs_hash 가
--      현재 checklist_answers_hash 와 다르면 확정하지 않는다. 사용자가 고친 편집 버전(created_kind='edited')은 해시를 보지 않는다.
create or replace function docs.finalize_document(p_document_id uuid, p_expected_version integer, p_ack_warn boolean default false)
returns docs.documents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doc     docs.documents;
  v_type    docs.doc_types;
  v_ver     docs.document_versions;
  v_missing jsonb;
  v_number  text;
begin
  select * into v_doc from docs.documents d where d.id = p_document_id for update;
  if not found then
    raise exception 'finalize_document: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_doc.org_id, array['owner', 'admin']) then
    raise exception 'finalize_document: owner/admin only' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_doc.org_id, 'docs') then
    raise exception 'finalize_document: no entitlement' using errcode = '42501';
  end if;
  if v_doc.status in ('final', 'archived') then
    raise exception 'finalize_document: document is already %', v_doc.status using errcode = 'DC003';
  end if;
  if v_doc.status not in ('draft', 'review') or v_doc.current_version < 1 then
    raise exception 'finalize_document: invalid state % (version %)', v_doc.status, v_doc.current_version using errcode = 'DC001';
  end if;
  if p_expected_version is distinct from v_doc.current_version then
    raise exception 'finalize_document: version conflict (current %, expected %)', v_doc.current_version, p_expected_version using errcode = 'DC010';
  end if;

  select * into v_ver from docs.document_versions v where v.document_id = v_doc.id and v.version = v_doc.current_version;
  select * into v_type from docs.doc_types t where t.code = v_doc.doc_type_code;
  if v_doc.needs_regeneration then
    raise exception 'finalize_document: source data changed, regenerate first' using errcode = 'DC010';
  end if;
  if v_ver.created_kind = 'generated' and v_ver.inputs_hash is not null
     and v_ver.inputs_hash is distinct from docs.checklist_answers_hash(v_doc.project_id) then
    raise exception 'finalize_document: checklist changed since generation' using errcode = 'DC010';
  end if;

  -- 필수 입력: 그 버전이 쓴 유형 버전의 required_fields 가 variables_snapshot 에 비어 있지 않게 있어야 한다
  select coalesce(jsonb_agg(f), '[]'::jsonb) into v_missing
  from docs.doc_type_versions tv, unnest(tv.required_fields) f
  where tv.doc_type_code = v_doc.doc_type_code and tv.version = v_ver.doc_type_version
    and coalesce(nullif(v_ver.variables_snapshot ->> f, ''), nullif(v_ver.variables_snapshot #>> string_to_array(f, '.'), '')) is null;
  if jsonb_array_length(v_missing) > 0 then
    raise exception 'finalize_document: required inputs missing %', v_missing using errcode = 'DC004';
  end if;
  if not (v_ver.lint_result ? 'ran_at') then
    raise exception 'finalize_document: lint has not run on version %', v_ver.version using errcode = 'DC005';
  end if;
  if v_ver.compliance_verdict = 'fail' or jsonb_array_length(coalesce(v_ver.lint_result -> 'errors', '[]'::jsonb)) > 0 then
    raise exception 'finalize_document: compliance fail or lint errors' using errcode = 'DC005';
  end if;
  if (v_ver.compliance_verdict = 'warn' or jsonb_array_length(coalesce(v_ver.lint_result -> 'warnings', '[]'::jsonb)) > 0)
     and not coalesce(p_ack_warn, false) then
    raise exception 'finalize_document: warnings must be acknowledged' using errcode = 'DC008';
  end if;
  if v_type.risk_level = 'high' and not exists (
       select 1 from docs.risk_acknowledgements k
       where k.org_id = v_doc.org_id and k.doc_type_code = v_type.code and k.notice_version = v_type.notice_version) then
    raise exception 'finalize_document: risk notice % not acknowledged', v_type.notice_version using errcode = 'DC007';
  end if;

  v_number := docs.next_doc_number(v_doc.org_id, v_doc.doc_type_code);
  update docs.documents
     set status = 'final', doc_number = v_number, finalized_at = now(), finalized_by = auth.uid(), needs_regeneration = false
   where id = p_document_id returning * into v_doc;
  perform core.write_audit(v_doc.org_id, 'docs_document.finalize', 'docs_document', p_document_id::text, null,
                           jsonb_build_object('doc_number', v_number, 'version', v_doc.current_version,
                                              'compliance', v_ver.compliance_verdict, 'ack_warn', coalesce(p_ack_warn, false)));
  return v_doc;
end;
$$;

-- 23.9 archive_document (authenticated owner/admin)
create or replace function docs.archive_document(p_document_id uuid)
returns docs.documents
language plpgsql
security definer
set search_path = ''
as $$
declare v_doc docs.documents;
begin
  select * into v_doc from docs.documents d where d.id = p_document_id for update;
  if not found then
    raise exception 'archive_document: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_doc.org_id, array['owner', 'admin']) then
    raise exception 'archive_document: owner/admin only' using errcode = '42501';
  end if;
  if v_doc.status not in ('draft', 'review', 'final') then
    raise exception 'archive_document: cannot archive % document', v_doc.status using errcode = 'DC001';
  end if;
  update docs.documents set status = 'archived', archived_at = now() where id = p_document_id returning * into v_doc;
  perform core.write_audit(v_doc.org_id, 'docs_document.archive', 'docs_document', p_document_id::text);
  return v_doc;
end;
$$;

-- 23.10 create_revision (authenticated owner/admin): 확정 문서의 개정본(새 draft 문서, 버전 1 = 원본 최신 버전 복사)
create or replace function docs.create_revision(p_document_id uuid)
returns docs.documents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_src  docs.documents;
  v_ver  docs.document_versions;
  v_new  docs.documents;
begin
  select * into v_src from docs.documents d where d.id = p_document_id for update;
  if not found then
    raise exception 'create_revision: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_src.org_id, array['owner', 'admin']) then
    raise exception 'create_revision: owner/admin only' using errcode = '42501';
  end if;
  if v_src.status <> 'final' then
    raise exception 'create_revision: only final documents can be revised (status %)', v_src.status using errcode = 'DC001';
  end if;
  if exists (select 1 from docs.documents d where d.supersedes_document_id = p_document_id and d.status <> 'archived') then
    raise exception 'create_revision: an open revision already exists' using errcode = 'DC002';
  end if;
  select * into v_ver from docs.document_versions v where v.document_id = v_src.id and v.version = v_src.current_version;

  insert into docs.documents (org_id, project_id, doc_type_code, title, supersedes_document_id, created_by)
  values (v_src.org_id, v_src.project_id, v_src.doc_type_code, left(v_src.title || ' (개정)', 200), v_src.id, auth.uid())
  returning * into v_new;
  insert into docs.document_versions (org_id, document_id, version, doc_type_version, content, body_html, variables_snapshot,
                                      inputs_hash, lint_result, compliance_verdict, created_kind, created_by)
  values (v_new.org_id, v_new.id, 1, v_ver.doc_type_version, v_ver.content, v_ver.body_html, v_ver.variables_snapshot,
          v_ver.inputs_hash, v_ver.lint_result, v_ver.compliance_verdict, 'imported', auth.uid());
  select * into v_new from docs.documents d where d.id = v_new.id;
  perform core.write_audit(v_src.org_id, 'docs_document.revise', 'docs_document', v_new.id::text, null,
                           jsonb_build_object('supersedes', v_src.id, 'doc_number', v_src.doc_number));
  return v_new;
end;
$$;

-- 23.11 set_project_status (authenticated owner/admin). 전이 규칙은 projects_status_transition 트리거(DC001).
create or replace function docs.set_project_status(p_project_id uuid, p_to text)
returns docs.projects
language plpgsql
security definer
set search_path = ''
as $$
declare v_row docs.projects; v_from text;
begin
  select * into v_row from docs.projects p where p.id = p_project_id and p.deleted_at is null for update;
  if not found then
    raise exception 'set_project_status: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'set_project_status: owner/admin only' using errcode = '42501';
  end if;
  if p_to is null or p_to not in ('draft', 'active', 'delivered', 'archived') then
    raise exception 'set_project_status: invalid status %', p_to using errcode = '22023';
  end if;
  if p_to = v_row.status then
    return v_row;
  end if;
  v_from := v_row.status;
  -- 보관에서 복원할 때의 활성 프로젝트 한도는 projects_enforce_limit 트리거가 본다(무제한 플랜 null 처리 포함, 2026-10-14)
  update docs.projects set status = p_to where id = p_project_id returning * into v_row;
  perform core.write_audit(v_row.org_id, 'docs_project.status', 'docs_project', p_project_id::text,
                           jsonb_build_object('status', v_from), jsonb_build_object('status', p_to));
  return v_row;
end;
$$;

-- 23.12 confirm_checklist_suggestions (authenticated member 이상): extract/integration 후보를 확정(source 유지)
create or replace function docs.confirm_checklist_suggestions(p_project_id uuid, p_item_keys text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid; v_n integer;
begin
  select p.org_id into v_org from docs.projects p where p.id = p_project_id and p.deleted_at is null;
  if v_org is null then
    raise exception 'confirm_checklist_suggestions: project not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_org, array['owner', 'admin', 'member']) then
    raise exception 'confirm_checklist_suggestions: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_org, 'docs') then
    raise exception 'confirm_checklist_suggestions: no entitlement' using errcode = '42501';
  end if;
  if p_item_keys is null or cardinality(p_item_keys) > 200 then
    raise exception 'confirm_checklist_suggestions: 1..200 keys' using errcode = '22023';
  end if;
  update docs.checklist_answers a set is_confirmed = true, answered_by = auth.uid()
   where a.project_id = p_project_id and a.item_key = any (p_item_keys) and not a.is_confirmed;
  get diagnostics v_n = row_count;
  if v_n > 0 then
    perform core.write_audit(v_org, 'docs_project.confirm_suggestions', 'docs_project', p_project_id::text, null,
                             jsonb_build_object('count', v_n));
  end if;
  return v_n;
end;
$$;

-- 23.13 ack_risk_notice (authenticated owner/admin): 고위험 유형의 현재 고지문 버전에만 동의할 수 있다. 멱등.
create or replace function docs.ack_risk_notice(p_doc_type_code text, p_notice_version text, p_org_id uuid default null)
returns docs.risk_acknowledgements
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org  uuid := coalesce(p_org_id, core.personal_org_id());
  v_type docs.doc_types;
  v_row  docs.risk_acknowledgements;
begin
  if v_org is null then
    raise exception 'ack_risk_notice: no organization' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_org, array['owner', 'admin']) then
    raise exception 'ack_risk_notice: owner/admin only' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_org, 'docs') then
    raise exception 'ack_risk_notice: no entitlement' using errcode = '42501';
  end if;
  select * into v_type from docs.doc_types t where t.code = p_doc_type_code;
  if not found or v_type.risk_level <> 'high' then
    raise exception 'ack_risk_notice: % is not a high-risk doc type', p_doc_type_code using errcode = '22023';
  end if;
  if p_notice_version is distinct from v_type.notice_version then
    raise exception 'ack_risk_notice: notice version mismatch (current %)', v_type.notice_version using errcode = '22023';
  end if;
  insert into docs.risk_acknowledgements (org_id, doc_type_code, notice_version, acked_by)
  values (v_org, p_doc_type_code, p_notice_version, auth.uid())
  on conflict (org_id, doc_type_code, notice_version) do nothing;
  select * into v_row from docs.risk_acknowledgements k
  where k.org_id = v_org and k.doc_type_code = p_doc_type_code and k.notice_version = p_notice_version;
  perform core.write_audit(v_org, 'docs.risk_ack', 'docs_doc_type', p_doc_type_code, null,
                           jsonb_build_object('notice_version', p_notice_version));
  return v_row;
end;
$$;

-- 23.14 revoke_integration (authenticated owner/admin): 해지 + 자격증명 revoke + 대기 동기화 잡 취소
create or replace function docs.revoke_integration(p_connection_id uuid)
returns docs.integration_connections
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conn docs.integration_connections;
  v_job  uuid;
begin
  select * into v_conn from docs.integration_connections c where c.id = p_connection_id for update;
  if not found then
    raise exception 'revoke_integration: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and not core.has_org_role(v_conn.org_id, array['owner', 'admin']) then
    raise exception 'revoke_integration: owner/admin only' using errcode = '42501';
  end if;
  if v_conn.status = 'revoked' then
    raise exception 'revoke_integration: already revoked' using errcode = 'DC009';
  end if;
  update docs.integration_connections
     set status = 'revoked', revoked_at = now(), inbound_token_hash = null
   where id = p_connection_id returning * into v_conn;
  if v_conn.credential_id is not null then
    perform core.revoke_credential(v_conn.credential_id);
  end if;
  for v_job in select r.job_id from docs.sync_runs r
               join core.jobs j on j.id = r.job_id
               where r.connection_id = p_connection_id and r.status = 'queued' and j.status = 'queued' loop
    perform core.cancel_job(v_job);
  end loop;
  update docs.sync_runs set status = 'canceled', finished_at = now()
   where connection_id = p_connection_id and status = 'queued';
  perform core.write_audit(v_conn.org_id, 'docs_integration.revoke', 'docs_integration', p_connection_id::text, null,
                           jsonb_build_object('provider', v_conn.provider));
  return v_conn;
end;
$$;

-- 23.15 decide_approval (Phase 2, authenticated): 지정된 승인자 본인만 pending 단계를 결정한다.
--       시그니처는 Phase 2 설계에서 바뀔 수 있다(04_API 3장). MVP 에서는 approval_steps 행이 없어 호출해도 P0002.
create or replace function docs.decide_approval(p_step_id uuid, p_decision text, p_comment text default null)
returns docs.approval_steps
language plpgsql
security definer
set search_path = ''
as $$
declare v_step docs.approval_steps;
begin
  select * into v_step from docs.approval_steps s where s.id = p_step_id for update;
  if not found then
    raise exception 'decide_approval: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller()
     and (v_step.approver_user_id is distinct from auth.uid()
          or not core.has_org_role(v_step.org_id, array['owner', 'admin', 'member'])) then
    raise exception 'decide_approval: not the approver' using errcode = '42501';
  end if;
  if p_decision is null or p_decision not in ('approved', 'rejected') then
    raise exception 'decide_approval: invalid decision' using errcode = '22023';
  end if;
  if v_step.status <> 'pending' then
    raise exception 'decide_approval: step already %', v_step.status using errcode = 'DC001';
  end if;
  update docs.approval_steps set status = p_decision, comment = left(p_comment, 2000), decided_at = now()
   where id = p_step_id returning * into v_step;
  perform core.write_audit(v_step.org_id, 'docs_approval.' || p_decision, 'docs_approval_step', p_step_id::text);
  return v_step;
end;
$$;

-- ---------------------------------------------------------------------
-- 24. 함수 권한: PUBLIC 회수, service_role 전용과 authenticated 허용 목록 분리.
--     파일 끝에서 schema 전체를 한 번 더 회수한다(새 함수가 추가돼도 PUBLIC 에 열리지 않게).
-- ---------------------------------------------------------------------
revoke execute on all functions in schema docs from public, anon, authenticated;
grant execute on all functions in schema docs to service_role;
-- 사용자 RPC (내부에서 is_service_caller + has_org_role)
grant execute on function docs.finalize_document(uuid, integer, boolean) to authenticated;
grant execute on function docs.archive_document(uuid) to authenticated;
grant execute on function docs.create_revision(uuid) to authenticated;
grant execute on function docs.set_project_status(uuid, text) to authenticated;
grant execute on function docs.confirm_checklist_suggestions(uuid, text[]) to authenticated;
grant execute on function docs.ack_risk_notice(text, text, uuid) to authenticated;
grant execute on function docs.revoke_integration(uuid) to authenticated;
grant execute on function docs.decide_approval(uuid, text, text) to authenticated;
grant execute on function docs.next_project_code(uuid, text, text) to authenticated;   -- 트리거 경유(내부 멤버 검사)
grant execute on function docs.cancel_generation(uuid) to authenticated;               -- 2026-10-14 추가(교차검증 #3)
-- 트리거 함수(사용자 세션의 INSERT/UPDATE 가 호출하는 비-DEFINER 트리거 함수는 EXECUTE 가 필요 없다. 트리거 발화는 권한 검사를 하지 않는다)

-- ---------------------------------------------------------------------
-- 25. 제품 seed (카탈로그 설정 데이터). 모두 upsert 이므로 반복 실행 가능.
--     위치 결정: 카탈로그(doc_types, doc_type_versions 1행씩, 대표 checklist_items, 표준 조항 골격)와 runtime_config 는
--     이 조각과 모놀리스 0002 말미에 둔다(DB 구조와 함께 배포되는 설정 데이터. study-note 의 model_catalog 와 같은 방식).
--     플랜·크레딧팩·apps 는 모놀리스 seed.sql 과 모듈러 seed.sql(코어 요청 C-3) 소유이며, 이 조각은 C-3 반영 전까지
--     on conflict do nothing 으로만 넣는다. 크레딧·수량·조항 본문은 제안값이다(01_PRD 3장, 4장).
-- ---------------------------------------------------------------------
insert into docs.doc_types (code, name, category, risk_level, generation_mode, phase, credits, in_package, package_order, number_prefix, notice_version, is_active, sort_order) values
  ('quote',          '견적서',                       'sales',    'low',  'template', 'mvp',    2,  '{outsourcing_basic,shorts_agency}', 2, 'QT',  null, true,  10),
  ('sow',            '과업지시서(SOW)',               'sales',    'low',  'hybrid',   'mvp',    6,  '{outsourcing_basic,shorts_agency}', 3, 'SOW', null, true,  20),
  ('req_spec',       '요구사항정의서',                 'dev',      'low',  'hybrid',   'mvp',    6,  '{outsourcing_basic}', 1, 'REQ', null, true,  30),
  ('wbs',            'WBS·일정표',                    'dev',      'low',  'template', 'mvp',    2,  '{outsourcing_basic}', 1, 'WBS', null, true,  40),
  ('screen_list',    '화면목록·메뉴구조도',            'dev',      'low',  'hybrid',   'mvp',    6,  '{outsourcing_basic}', 1, 'SL',  null, true,  50),
  ('dev_contract',   '소프트웨어 개발 용역계약서',      'contract', 'high', 'template', 'mvp',    2,  '{outsourcing_basic}', 4, 'CT',  'notice-contract-2026-10-13', false, 60),  -- D-3 법무 검토 전 비활성(교차검증 #1)
  ('acceptance',     '검수확인서',                    'dev',      'low',  'template', 'mvp',    2,  '{outsourcing_basic,shorts_agency}', 5, 'AC',  null, true,  70),
  ('minutes',        '회의록',                        'ops',      'low',  'ai',       'mvp',    0,  '{}',                  null, 'MN', null, true, 80),
  ('trace_matrix',   '요구사항 추적표',                'dev',      'low',  'template', 'mvp',    2,  '{outsourcing_basic}', 6, 'TM',  null, true,  90),
  ('nda',            '비밀유지계약서',                 'contract', 'high', 'template', 'phase2', 2,  '{}', null, 'NDA', 'notice-contract-2026-10-13', false, 110),
  ('maint_contract', '유지보수계약서',                 'contract', 'high', 'template', 'phase2', 2,  '{}', null, 'MC',  'notice-contract-2026-10-13', false, 120),
  ('proposal',       '제안서',                        'sales',    'low',  'ai',       'phase2', 12, '{}', null, 'PR',  null, false, 130),
  ('change_request', '변경요청서',                    'dev',      'low',  'hybrid',   'phase2', 6,  '{}', null, 'CR',  null, false, 140),
  ('test_cases',     '테스트케이스',                  'dev',      'low',  'hybrid',   'phase2', 6,  '{}', null, 'TC',  null, false, 150),
  ('api_spec',       'API 명세서',                    'dev',      'low',  'hybrid',   'phase2', 6,  '{}', null, 'API', null, false, 160),
  ('db_design',      'DB 설계서',                     'dev',      'low',  'hybrid',   'phase2', 6,  '{}', null, 'DB',  null, false, 170),
  ('invoice',        '청구서·거래명세서',              'sales',    'low',  'template', 'phase2', 2,  '{}', null, 'IV',  null, false, 180),
  ('biz_plan',       '사업계획서·정부지원사업 신청서',  'business', 'low',  'ai',       'phase2', 12, '{}', null, 'BP',  null, false, 190),
  ('employment',     '근로계약서',                    'hr',       'high', 'template', 'phase3', 2,  '{}', null, 'EM',  'notice-contract-2026-10-13', false, 210),
  ('privacy_policy', '개인정보처리방침',               'legal',    'high', 'template', 'phase3', 2,  '{}', null, 'PP',  'notice-contract-2026-10-13', false, 220),
  ('terms',          '이용약관',                      'legal',    'high', 'template', 'phase3', 2,  '{}', null, 'TS',  'notice-contract-2026-10-13', false, 230),
  -- shorts_agency(숏폼 제작·채널 운영 대행, DC-F-046, Phase 2). quote·sow·acceptance 는 위 행에서 in_package 로 공유한다.
  -- package_order 는 유형마다 1개라 두 패키지가 같은 순서 체계(1 기획 → 2 견적 → 3 과업 → 4 계약 → 5 검수)를 쓴다.
  ('content_brief',           '콘텐츠 브리프·기획안',           'sales',    'low',  'hybrid',   'phase2', 6,  '{shorts_agency}', 1,    'CB',  null, false, 310),
  ('video_service_contract',  '영상 제작·채널 운영 대행 계약서', 'contract', 'high', 'template', 'phase2', 2,  '{shorts_agency}', 4,    'VC',  'notice-contract-2026-10-13', false, 320),
  ('channel_access_mandate',  '채널 계정 접근·운영 위임 동의서', 'contract', 'high', 'template', 'phase2', 2,  '{shorts_agency}', 4,    'CAM', 'notice-channel-mandate-2026-10-13', false, 330),
  ('brand_guide_ack',         '브랜드 가이드 확인서',           'ops',      'low',  'template', 'phase2', 2,  '{}', null, 'BG',  null, false, 340),
  ('ad_disclosure_checklist', '광고 표시 준수 체크리스트',       'ops',      'low',  'template', 'phase2', 2,  '{}', null, 'ADC', null, false, 350),
  ('monthly_report',          '월간 성과 리포트',               'ops',      'low',  'hybrid',   'phase2', 6,  '{}', null, 'MR',  null, false, 360),
  ('service_intro',           '서비스 소개서',                  'sales',    'low',  'ai',       'phase2', 12, '{}', null, 'SI',  null, false, 370)
on conflict (code) do update
  set name = excluded.name, category = excluded.category, risk_level = excluded.risk_level, generation_mode = excluded.generation_mode,
      phase = excluded.phase, credits = excluded.credits, in_package = excluded.in_package, package_order = excluded.package_order,
      number_prefix = excluded.number_prefix, notice_version = excluded.notice_version,
      sort_order = excluded.sort_order;
-- is_active 는 처음 넣을 때만 정한다. 운영자가 켜고 끈 값을 마이그레이션 재실행이 덮지 않는다(교차검증 #1).
-- 회의록 크레딧 0: 가변 단가(STT 분당 1 + 그래프 5)라 Route Handler 가 계산해 차감한다(start_generation 을 쓰지 않음).

-- MVP 유형별 게시 버전 1. 섹션 구조와 필수 입력은 01_PRD 3.1절. 게시 후 불변(DC003)이므로 on conflict do nothing.
insert into docs.doc_type_versions (doc_type_code, version, structure, required_fields, lint_rules, template_ref, published_at) values
  ('quote', 1,
   '[{"key":"header","title":"견적 개요","kind":"fixed"},{"key":"items","title":"견적 내역","kind":"table"},{"key":"totals","title":"합계","kind":"table"},{"key":"terms","title":"유효기간·조건","kind":"variable"}]',
   '{client_party,self_party,line_items,quote.valid_until}', '["L-AMOUNT-MATCH","L-PARTY","L-RRN","L-BANNED"]', 'templates/quote/v1.html.j2', now()),
  ('sow', 1,
   '[{"key":"overview","title":"개요","kind":"ai"},{"key":"scope","title":"과업 범위","kind":"variable"},{"key":"requirements","title":"요구사항 요약","kind":"table"},{"key":"schedule","title":"일정","kind":"table"},{"key":"deliverables","title":"산출물","kind":"table"},{"key":"amount","title":"금액","kind":"table"}]',
   '{client_party,project.start_date,project.end_date,requirements}', '["L-AMOUNT-MATCH","L-PERIOD","L-PARTY","L-REQ-REF","L-RRN","L-AI-CLAIM","L-BANNED"]', 'templates/sow/v1.html.j2', now()),
  ('req_spec', 1,
   '[{"key":"intro","title":"개요","kind":"ai"},{"key":"functional","title":"기능 요구사항","kind":"table"},{"key":"nonfunctional","title":"비기능 요구사항","kind":"table"},{"key":"constraints","title":"제약 사항","kind":"table"},{"key":"glossary","title":"용어 정의","kind":"variable"}]',
   '{profile.service_summary,requirements}', '["L-REQ-REF","L-UNTRACED","L-RRN","L-AI-CLAIM","L-BANNED"]', 'templates/req_spec/v1.html.j2', now()),
  ('wbs', 1,
   '[{"key":"phases","title":"단계별 작업","kind":"table"},{"key":"schedule","title":"일정","kind":"table"},{"key":"deliverables","title":"산출물 연결","kind":"table"}]',
   '{project.start_date,project.end_date,milestones}', '["L-PERIOD","L-RRN","L-BANNED"]', 'templates/wbs/v1.html.j2', now()),
  ('screen_list', 1,
   '[{"key":"menu","title":"메뉴 트리","kind":"table"},{"key":"screens","title":"화면 목록","kind":"table"},{"key":"descriptions","title":"화면 설명","kind":"ai"}]',
   '{screens}', '["L-REQ-REF","L-UNTRACED","L-RRN","L-AI-CLAIM","L-BANNED"]', 'templates/screen_list/v1.html.j2', now()),
  ('dev_contract', 1,
   '[{"key":"preamble","title":"전문","kind":"fixed"},{"key":"clauses","title":"조항","kind":"variable"},{"key":"payment","title":"대금 지급","kind":"table"},{"key":"signature","title":"서명","kind":"fixed"},{"key":"attachments","title":"별첨","kind":"variable"}]',
   '{client_party,self_party,total_krw,contract_terms.payment_schedule,project.start_date,project.end_date,contract_terms.warranty_months,contract_terms.ip_ownership}',
   '["L-AMOUNT-MATCH","L-PAY-100","L-PERIOD","L-PARTY","L-REQUIRED-CLAUSE","L-RRN","L-BANNED"]', 'templates/dev_contract/v1.html.j2', now()),
  ('acceptance', 1,
   '[{"key":"target","title":"검수 대상","kind":"variable"},{"key":"items","title":"검수 항목","kind":"table"},{"key":"signature","title":"서명","kind":"fixed"}]',
   '{requirements,acceptance.date,contract_terms.acceptance_days}', '["L-PARTY","L-REQ-REF","L-RRN","L-BANNED"]', 'templates/acceptance/v1.html.j2', now()),
  ('minutes', 1,
   '[{"key":"summary","title":"개요","kind":"ai"},{"key":"discussion","title":"논의","kind":"ai"},{"key":"decisions","title":"결정 사항","kind":"table"},{"key":"actions","title":"할 일","kind":"table"},{"key":"req_candidates","title":"요구사항 후보","kind":"table"}]',
   '{minutes.attendees,minutes.date}', '["L-RRN","L-AI-CLAIM","L-BANNED"]', 'templates/minutes/v1.html.j2', now()),
  ('trace_matrix', 1,
   '[{"key":"matrix","title":"추적표","kind":"table"},{"key":"gaps","title":"빈칸 요약","kind":"variable"}]',
   '{requirements}', '["L-REQ-REF","L-UNTRACED","L-RRN"]', 'templates/trace_matrix/v1.html.j2', now())
on conflict (doc_type_code, version) do nothing;

-- shorts_agency 유형 초안 버전(published_at null = 운영자 편집 가능, 사용자에게 보이지 않음). DC-F-046 착수 때 게시한다(01_PRD 3.1.1절).
insert into docs.doc_type_versions (doc_type_code, version, structure, required_fields, lint_rules, template_ref, published_at) values
  ('content_brief', 1,
   '[{"key":"goal","title":"목표와 타깃","kind":"ai"},{"key":"channels","title":"채널·규격","kind":"table"},{"key":"cadence","title":"편수·일정","kind":"table"},{"key":"hooks","title":"훅·스크립트 초안","kind":"ai"},{"key":"references","title":"참고 영상","kind":"variable"},{"key":"disclosure","title":"광고 표시 방식","kind":"variable"}]',
   '{client_party,content.channels,content.monthly_videos,profile.service_summary}', '["L-REQ-REF","L-RRN","L-AI-CLAIM","L-NO-GUARANTEE","L-BANNED"]', 'templates/content_brief/v1.html.j2', null),
  ('video_service_contract', 1,
   '[{"key":"preamble","title":"전문","kind":"fixed"},{"key":"clauses","title":"조항","kind":"variable"},{"key":"specs","title":"납품 사양","kind":"table"},{"key":"payment","title":"대금 지급","kind":"table"},{"key":"signature","title":"서명","kind":"fixed"},{"key":"attachments","title":"별첨","kind":"variable"}]',
   '{client_party,self_party,total_krw,contract_terms.payment_schedule,project.start_date,project.end_date,contract_terms.ip_ownership,contract_terms.revision_rounds,contract_terms.secondary_use_months,contract_terms.acceptance_days}',
   '["L-AMOUNT-MATCH","L-PAY-100","L-PERIOD","L-PARTY","L-REQUIRED-CLAUSE","L-NO-GUARANTEE","L-RRN","L-BANNED"]', 'templates/video_service_contract/v1.html.j2', null),
  ('channel_access_mandate', 1,
   '[{"key":"preamble","title":"전문","kind":"fixed"},{"key":"channels","title":"위임 채널","kind":"table"},{"key":"clauses","title":"위임 범위·책임","kind":"variable"},{"key":"risk","title":"자동화 위험 고지","kind":"fixed"},{"key":"signature","title":"서명","kind":"fixed"}]',
   '{client_party,self_party,content.channels,project.start_date,project.end_date}', '["L-PARTY","L-PERIOD","L-REQUIRED-CLAUSE","L-RRN","L-BANNED"]', 'templates/channel_access_mandate/v1.html.j2', null),
  ('brand_guide_ack', 1,
   '[{"key":"brand","title":"브랜드 기본 정보","kind":"variable"},{"key":"dos","title":"써야 할 표현·톤","kind":"table"},{"key":"donts","title":"금지 표현·경쟁사","kind":"table"},{"key":"assets","title":"제공 소재·사용 범위","kind":"table"},{"key":"signature","title":"확인","kind":"fixed"}]',
   '{client_party,self_party}', '["L-PARTY","L-RRN","L-BANNED"]', 'templates/brand_guide_ack/v1.html.j2', null),
  ('ad_disclosure_checklist', 1,
   '[{"key":"campaign","title":"캠페인·대가 관계","kind":"variable"},{"key":"placement","title":"채널별 표시 위치","kind":"table"},{"key":"wording","title":"표시 문구","kind":"table"},{"key":"virtual_human","title":"AI 가상인물 표시","kind":"variable"},{"key":"check","title":"게시 전 확인","kind":"table"}]',
   '{content.channels,feat.content_affiliate}', '["L-AD-DISCLOSURE","L-RRN","L-BANNED"]', 'templates/ad_disclosure_checklist/v1.html.j2', null),
  ('monthly_report', 1,
   '[{"key":"summary","title":"핵심 지표 요약","kind":"table"},{"key":"top_bottom","title":"상위·하위 영상","kind":"table"},{"key":"insights","title":"분석","kind":"ai"},{"key":"next_plan","title":"다음 달 계획","kind":"ai"},{"key":"requests","title":"고객 요청 처리","kind":"table"}]',
   '{client_party,report.period,report.kpis}', '["L-PARTY","L-RRN","L-AI-CLAIM","L-NO-GUARANTEE","L-BANNED"]', 'templates/monthly_report/v1.html.j2', null),
  ('service_intro', 1,
   '[{"key":"intro","title":"회사·서비스 소개","kind":"ai"},{"key":"packages","title":"서비스 패키지","kind":"table"},{"key":"process","title":"진행 절차","kind":"table"},{"key":"portfolio","title":"포트폴리오","kind":"variable"},{"key":"contact","title":"문의","kind":"fixed"}]',
   '{self_party,profile.service_summary}', '["L-RRN","L-AI-CLAIM","L-NO-GUARANTEE","L-BANNED"]', 'templates/service_intro/v1.html.j2', null)
on conflict (doc_type_code, version) do nothing;

-- 대표 체크리스트 항목(01_PRD 3.3절 예시 중 일부). 나머지 항목과 효과 수량은 운영자 화면(DC-F-040)에서 게시한다.
insert into docs.checklist_items (key, group_key, label, input_type, options, effects, is_required, sort_order, applies_to) values
  ('profile.service_summary', 'profile', '서비스 한 줄 소개', 'text', '[]', '[]', true, 10, '{}'),
  ('profile.platforms', 'profile', '플랫폼', 'multi', '["web","android","ios","desktop","admin_web"]', '[]', true, 20, '{web,app,ai,mixed,other}'),
  ('project_type.build_kind', 'project_type', '구축 유형', 'single', '["new","renewal","maintenance"]', '[]', true, 30, '{web,app,ai,mixed,other}'),
  ('feat.login', 'feature', '회원가입·로그인', 'boolean', '[]',
   '[{"id":"fr_signup","target":"requirements","kind":"functional","title":"회원가입","priority":"must"},{"id":"fr_login","target":"requirements","kind":"functional","title":"로그인","priority":"must"},{"id":"fr_reset","target":"requirements","kind":"functional","title":"비밀번호 재설정","priority":"should"},{"id":"scr_login","target":"artifacts","kind":"screen","name":"로그인","links":["fr_login"]},{"id":"li_login","target":"line_items","category":"dev","name":"회원·인증 개발","unit":"man_day","quantity":3,"unit_price":"default_day_rate"}]',
   false, 100, '{web,app,ai,mixed,other}'),
  ('feat.payment', 'feature', '결제', 'boolean', '[]',
   '[{"id":"fr_pg","target":"requirements","kind":"functional","title":"카드·간편결제 결제","priority":"must"},{"id":"fr_refund","target":"requirements","kind":"functional","title":"결제 취소·환불","priority":"should"},{"id":"nfr_pg_sec","target":"requirements","kind":"nonfunctional","title":"카드정보 미저장","priority":"must"},{"id":"scr_checkout","target":"artifacts","kind":"screen","name":"결제","links":["fr_pg"]},{"id":"li_pg","target":"line_items","category":"dev","name":"PG 결제 연동","unit":"man_day","quantity":5,"unit_price":"default_day_rate"},{"id":"cl_pg","target":"clauses","code":"dev.pg_responsibility"}]',
   false, 110, '{web,app,ai,mixed,other}'),
  ('nfr.security_level', 'nfr', '보안 수준', 'single', '["basic","standard","high"]', '[]', true, 200, '{web,app,ai,mixed,other}'),
  ('delivery.source_code', 'delivery', '소스코드 인도', 'boolean', '[]',
   '[{"id":"dlv_src","target":"artifacts","kind":"deliverable","name":"소스코드"},{"id":"cl_src","target":"clauses","code":"dev.source_delivery"}]', true, 300, '{web,app,ai,mixed,other}'),
  ('contract_terms.payment_schedule', 'contract_terms', '대금 지급 방식', 'single', '["advance_balance_50_50","advance_mid_balance_30_40_30","monthly"]',
   '[{"id":"cl_pay","target":"clauses","code":"dev.payment"}]', true, 400, '{}'),
  ('contract_terms.warranty_months', 'contract_terms', '하자보수 기간(개월)', 'number', '[]', '[{"id":"cl_warranty","target":"clauses","code":"dev.warranty"}]', true, 410, '{web,app,ai,mixed,other}'),
  ('contract_terms.ip_ownership', 'contract_terms', '지식재산권 귀속', 'single', '["client","developer","shared"]', '[{"id":"cl_ip","target":"clauses","code":"dev.ip"}]', true, 420, '{}'),
  ('contract_terms.acceptance_days', 'contract_terms', '검수 기간(일)', 'number', '[]', '[{"id":"cl_accept","target":"clauses","code":"dev.acceptance"}]', true, 430, '{}'),
  -- shorts_agency 체크리스트(applies_to = content). dev 전용 항목은 위에서 applies_to 로 content 를 뺐다.
  -- 단가 "catalog:<key>"는 조직 단가 카탈로그(workspace_settings.defaults, DC-F-028)에서 읽고 없으면 0 + lint warn(01_PRD 3.3.1절, D-14).
  ('content.channels', 'profile', '운영 채널', 'multi', '["youtube_shorts","instagram_reels","tiktok","naver_clip","threads"]',
   '[{"id":"nfr_spec","target":"requirements","kind":"nonfunctional","title":"{{answer.label}} 업로드 규격(9:16, 길이, 자막 안전영역) 준수","priority":"must"}]', true, 1000, '{content}'),
  ('content.monthly_videos', 'profile', '월 제작 편수', 'number', '[]',
   '[{"id":"fr_cadence","target":"requirements","kind":"functional","title":"월 {{answer}}편 숏폼 제작·납품","priority":"must"},{"id":"dlv_video","target":"artifacts","kind":"deliverable","name":"숏폼 영상(9:16) 월 {{answer}}편","links":["fr_cadence"]},{"id":"ms_month","target":"artifacts","kind":"milestone","name":"월간 납품·검수"},{"id":"li_video","target":"line_items","category":"production","name":"숏폼 영상 제작(기획·편집·자막)","unit":"per_video","quantity":{"from":"content.monthly_videos","factor":1,"min":1,"max":300},"unit_price":"catalog:short_video"}]', true, 1010, '{content}'),
  ('content.channel_count', 'profile', '운영 채널 수(계정 기준)', 'number', '[]', '[]', false, 1020, '{content}'),
  ('feat.content_shooting', 'feature', '촬영 포함', 'boolean', '[]',
   '[{"id":"con_shoot","target":"requirements","kind":"constraint","title":"촬영 일정·장소는 발주자와 사전 합의","priority":"must"},{"id":"li_shoot","target":"line_items","category":"production","name":"촬영(장비·장소·인력)","unit":"ea","quantity":1,"unit_price":"catalog:shooting_day"},{"id":"cl_shoot","target":"clauses","code":"vsc.shooting"}]', false, 1100, '{content}'),
  ('feat.content_talent', 'feature', '출연자 섭외', 'boolean', '[]',
   '[{"id":"con_talent","target":"requirements","kind":"constraint","title":"출연자 초상권·출연 동의서 확보","priority":"must"},{"id":"li_talent","target":"line_items","category":"media","name":"출연료","unit":"ea","quantity":1,"unit_price":"catalog:talent_fee"},{"id":"cl_publicity","target":"clauses","code":"vsc.publicity_rights"}]', false, 1110, '{content}'),
  ('feat.content_music_license', 'feature', '음원·폰트·스톡 소재', 'single', '["free_library","licensed_paid","client_provided"]',
   '[{"id":"li_music","target":"line_items","category":"license","name":"유료 음원·스톡 라이선스","unit":"per_month","quantity":1,"unit_price":"catalog:music_license","when":{"eq":"licensed_paid"}},{"id":"cl_license","target":"clauses","code":"vsc.license"}]', true, 1120, '{content}'),
  ('feat.content_multilingual', 'feature', '다국어 자막·더빙', 'multi', '["en","ja","zh","vi"]',
   '[{"id":"li_lang","target":"line_items","category":"production","name":"{{answer.label}} 자막·더빙","unit":"per_video","quantity":{"from":"content.monthly_videos","factor":1,"min":1,"max":300},"unit_price":"catalog:localize_video"}]', false, 1130, '{content}'),
  ('feat.content_affiliate', 'feature', '광고·제휴(대가 관계) 포함', 'multi', '["brandconnect","shopping_connect","coupang","direct_sponsor"]',
   '[{"id":"nfr_disclosure","target":"requirements","kind":"nonfunctional","title":"경제적 이해관계 표시(제목·영상 내·첫 해시태그, 추천보증 심사지침)","priority":"must"},{"id":"cl_ad","target":"clauses","code":"vsc.ad_disclosure"}]', false, 1140, '{content}'),
  ('delivery.upload_service', 'delivery', '채널 업로드·운영 대행', 'boolean', '[]',
   '[{"id":"fr_upload","target":"requirements","kind":"functional","title":"합의된 일정에 채널 업로드와 제목·해시태그·고정 댓글 관리","priority":"must"},{"id":"li_ops","target":"line_items","category":"channel_ops","name":"채널 업로드·운영(월)","unit":"per_channel","quantity":{"from":"content.channel_count","factor":1,"min":1,"max":40},"unit_price":"catalog:channel_ops_month"},{"id":"cl_ops","target":"clauses","code":"vsc.channel_ops"}]', false, 1200, '{content}'),
  ('delivery.naver_clip_upload', 'delivery', '네이버 클립 자동 업로드 포함', 'boolean', '[]',
   '[{"id":"con_clip","target":"requirements","kind":"constraint","title":"네이버 클립 자동 업로드(공식 API 미확인, 브라우저 자동화)의 약관·계정 제한 위험을 발주자가 고지받고 위임 동의서에 동의","priority":"must"},{"id":"cl_auto","target":"clauses","code":"vsc.automation_risk"}]', false, 1210, '{content}'),
  ('delivery.monthly_report', 'delivery', '월간 성과 리포트', 'boolean', '[]',
   '[{"id":"dlv_report","target":"artifacts","kind":"deliverable","name":"월간 성과 리포트"},{"id":"li_report","target":"line_items","category":"channel_ops","name":"월간 성과 리포트","unit":"per_month","quantity":1,"unit_price":"catalog:monthly_report"}]', false, 1220, '{content}'),
  ('contract_terms.revision_rounds', 'contract_terms', '편당 무상 수정 횟수', 'number', '[]', '[{"id":"cl_rev","target":"clauses","code":"vsc.revision"}]', true, 1400, '{content}'),
  ('contract_terms.secondary_use_months', 'contract_terms', '2차 사용(광고 집행·타 채널) 허용 기간(개월)', 'number', '[]', '[{"id":"cl_2nd","target":"clauses","code":"vsc.secondary_use"}]', true, 1410, '{content}'),
  ('contract_terms.retainer_months', 'contract_terms', '월 리테이너 최소 기간(개월)', 'number', '[]', '[{"id":"cl_term","target":"clauses","code":"vsc.term"}]', false, 1420, '{content}')
on conflict (key) do update
  set group_key = excluded.group_key, label = excluded.label, input_type = excluded.input_type, options = excluded.options,
      effects = excluded.effects, is_required = excluded.is_required, sort_order = excluded.sort_order, applies_to = excluded.applies_to;

-- 표준 조항 골격(org_id null). 본문 원문 출처와 이용 조건은 미확인(D-8)이라 status='draft'(사용자에게 보이지 않음).
-- 법무 검토(D-3) 후 운영자가 본문을 채워 published 로 바꾼다. 그 전에는 dev_contract 확정 시 L-REQUIRED-CLAUSE 가 막는다.
insert into docs.clauses (org_id, code, doc_type_code, title, body_template, variables, is_required, source_note, version, status, sort_order) values
  (null, 'dev.purpose',            'dev_contract', '계약의 목적',     '{{self_name}}(이하 "수급인")은 {{client_name}}(이하 "도급인")의 {{project_name}} 개발 용역을 수행한다.', '{self_name,client_name,project_name}', true,  '미확인(D-8)', 1, 'draft', 10),
  (null, 'dev.payment',            'dev_contract', '대금과 지급',     '계약 금액은 금 {{total_krw_korean}}원(부가세 포함)이며 {{payment_schedule_text}}에 따라 지급한다.', '{total_krw_korean,payment_schedule_text}', true, '미확인(D-8)', 1, 'draft', 20),
  (null, 'dev.acceptance',         'dev_contract', '검수',           '도급인은 납품일로부터 {{acceptance_days}}일 이내에 검수 결과를 통지한다.', '{acceptance_days}', true, '미확인(D-8)', 1, 'draft', 30),
  (null, 'dev.warranty',           'dev_contract', '하자보수',       '수급인은 검수 완료일로부터 {{warranty_months}}개월간 하자를 보수한다.', '{warranty_months}', true, '미확인(D-8)', 1, 'draft', 40),
  (null, 'dev.ip',                 'dev_contract', '지식재산권',     '{{ip_ownership_text}}', '{ip_ownership_text}', true, '미확인(D-8)', 1, 'draft', 50),
  (null, 'dev.confidentiality',    'dev_contract', '비밀유지',       '당사자는 계약 이행 중 알게 된 상대방의 비밀을 제3자에게 누설하지 않는다.', '{}', true, '미확인(D-8)', 1, 'draft', 60),
  (null, 'dev.source_delivery',    'dev_contract', '소스코드 인도',  '수급인은 검수 완료 시 소스코드와 빌드 방법을 인도한다.', '{}', false, '미확인(D-8)', 1, 'draft', 70),
  (null, 'dev.pg_responsibility',  'dev_contract', '결제대행 책임',  'PG 계약과 수수료는 {{pg_contract_party_text}}가 부담한다.', '{pg_contract_party_text}', false, '미확인(D-8)', 1, 'draft', 80),
  (null, 'dev.delay_penalty',      'dev_contract', '지체상금',       '수급인의 책임으로 납기를 지체하면 지체 1일당 계약 금액의 {{delay_rate_text}}를 지체상금으로 한다.', '{delay_rate_text}', false, '미확인(D-8)', 1, 'draft', 90),
  -- shorts_agency 계약서·위임 동의서 골격. 영상 제작 전용 공공 표준계약서는 찾지 못했다(D-15, 01_PRD 6.4절).
  (null, 'vsc.purpose', 'video_service_contract', '계약의 목적', '{{self_name}}(이하 "수급인")은 {{client_name}}(이하 "도급인")을 위해 {{project_name}}의 숏폼 영상 제작{{channel_ops_text}} 용역을 수행한다.', '{self_name,client_name,project_name,channel_ops_text}', true, '미확인(D-8, D-15)', 1, 'draft', 10),
  (null, 'vsc.deliverables', 'video_service_contract', '납품 사양', '수급인은 별첨 납품 사양(월 {{monthly_videos}}편, 화면비 9:16, 길이, 해상도, 파일 형식, 자막)에 맞춰 납품한다.', '{monthly_videos}', true, '미확인(D-8, D-15)', 1, 'draft', 20),
  (null, 'vsc.acceptance', 'video_service_contract', '검수', '도급인은 납품일로부터 {{acceptance_days}}일 이내에 검수 결과를 통지하며, 기간 안에 통지가 없으면 검수를 마친 것으로 본다.', '{acceptance_days}', true, '미확인(D-8, D-15)', 1, 'draft', 30),
  (null, 'vsc.revision', 'video_service_contract', '수정', '편당 무상 수정은 {{revision_rounds}}회로 하고, 이를 넘는 수정과 기획 변경은 변경요청서로 합의한 추가 비용으로 진행한다.', '{revision_rounds}', true, '미확인(D-8, D-15)', 1, 'draft', 40),
  (null, 'vsc.payment', 'video_service_contract', '대금과 지급', '계약 금액은 금 {{total_krw_korean}}원(부가세 포함)이며 {{payment_schedule_text}}에 따라 지급한다.', '{total_krw_korean,payment_schedule_text}', true, '미확인(D-8, D-15)', 1, 'draft', 50),
  (null, 'vsc.ip', 'video_service_contract', '저작권 귀속', '{{ip_ownership_text}} 단, 수급인이 기존에 보유한 템플릿·편집 노하우·범용 소재의 권리는 수급인에게 남는다.', '{ip_ownership_text}', true, '미확인(D-8, D-15)', 1, 'draft', 60),
  (null, 'vsc.secondary_use', 'video_service_contract', '2차 사용', '도급인은 납품 영상을 계약 채널 밖의 광고 집행·타 채널 게시에 납품일로부터 {{secondary_use_months}}개월 동안 쓸 수 있으며, 그 뒤의 사용은 별도로 합의한다.', '{secondary_use_months}', true, '미확인(D-8, D-15)', 1, 'draft', 70),
  (null, 'vsc.license', 'video_service_contract', '음원·폰트·스톡 소재', '영상에 쓰인 음원·폰트·스톡 소재의 출처는 {{license_source_text}}이며, 라이선스 범위를 넘겨 사용해 생긴 분쟁은 넘겨 사용한 당사자가 책임진다.', '{license_source_text}', true, '미확인(D-8, D-15)', 1, 'draft', 80),
  (null, 'vsc.publicity_rights', 'video_service_contract', '초상권·출연 동의', '출연자의 초상·음성 사용 범위와 기간은 출연 동의서에 따르며, 수급인은 촬영 전에 서면 동의를 받는다.', '{}', false, '미확인(D-8, D-15)', 1, 'draft', 90),
  (null, 'vsc.ad_disclosure', 'video_service_contract', '광고 표시', '대가를 받은 홍보 영상에는 추천·보증 등에 관한 표시·광고 심사지침에 따라 경제적 이해관계를 제목·영상 안·첫 해시태그 등 소비자가 쉽게 알 수 있는 위치에 표시한다. 표시 문구는 도급인이 최종 확인한다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 100),
  (null, 'vsc.no_guarantee', 'video_service_contract', '성과 비보장', '수급인은 조회수·구독자 수·매출 등 특정 성과를 보장하지 않으며, 플랫폼 알고리즘·정책 변경에 따른 성과 변동은 계약 위반이 아니다. 수급인은 조회수·구독자 구매 등 플랫폼 정책 위반 수단을 쓰지 않는다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 110),
  (null, 'vsc.channel_ops', 'video_service_contract', '채널 운영 대행', '채널 업로드·운영 범위와 계정 접근 방법은 별첨 채널 계정 접근·운영 위임 동의서에 따른다.', '{}', false, '미확인(D-8, D-15)', 1, 'draft', 120),
  (null, 'vsc.automation_risk', 'video_service_contract', '자동 업로드 위험', '공식 업로드 API가 확인되지 않은 채널(예: 네이버 클립)의 자동 업로드는 플랫폼 약관상 제한될 수 있으며, 도급인은 이 위험을 고지받고 동의하였다. 계정 제재가 생기면 수급인은 즉시 자동 업로드를 멈춘다.', '{}', false, '미확인(D-8, D-15)', 1, 'draft', 130),
  (null, 'vsc.shooting', 'video_service_contract', '촬영', '촬영 일정·장소·소품은 도급인과 사전에 합의하며, 도급인 사유로 촬영이 취소되면 이미 발생한 실비를 도급인이 부담한다.', '{}', false, '미확인(D-8, D-15)', 1, 'draft', 140),
  (null, 'vsc.term', 'video_service_contract', '계약 기간', '계약 기간은 {{project_start}}부터 {{project_end}}까지로 하며, 월 리테이너는 최소 {{retainer_months}}개월 유지한 뒤 한쪽이 30일 전에 서면으로 통지하면 끝난다.', '{project_start,project_end,retainer_months}', false, '미확인(D-8, D-15)', 1, 'draft', 150),
  (null, 'vsc.confidentiality', 'video_service_contract', '비밀유지', '당사자는 계약 이행 중 알게 된 상대방의 비밀(계정 정보, 미공개 제품·캠페인 정보 포함)을 제3자에게 누설하지 않는다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 160),
  (null, 'vsc.termination', 'video_service_contract', '해지', '한쪽이 계약을 위반하고 14일 안에 시정하지 않으면 상대방은 서면 통지로 해지할 수 있으며, 해지 시점까지 납품·검수된 분량의 대금은 정산한다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 170),
  (null, 'vsc.liability', 'video_service_contract', '손해배상', '고의 또는 중과실이 없는 한 손해배상 총액은 직전 {{liability_cap_months}}개월 동안 지급된 대금을 한도로 한다.', '{liability_cap_months}', true, '미확인(D-8, D-15)', 1, 'draft', 180),
  (null, 'cam.scope', 'channel_access_mandate', '위임 범위', '{{client_name}}은 별표 채널에 대해 {{self_name}}에게 영상 업로드, 제목·설명·해시태그 편집, 댓글 관리 권한을 {{project_start}}부터 {{project_end}}까지 위임한다. 채널 삭제와 수익 정산 계좌 변경 권한은 위임하지 않는다.', '{client_name,self_name,project_start,project_end}', true, '미확인(D-8, D-15)', 1, 'draft', 10),
  (null, 'cam.credentials', 'channel_access_mandate', '계정 접근 방법', '접근은 플랫폼이 제공하는 관리자·편집자 초대 기능을 먼저 쓴다. 비밀번호를 넘겨받아야 하면 수급인은 암호화 저장소에만 보관하고 계약이 끝나면 즉시 삭제하며, 도급인은 종료 뒤 비밀번호를 바꾼다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 20),
  (null, 'cam.automation_risk', 'channel_access_mandate', '자동화 위험 고지', '공식 업로드 API가 확인되지 않은 채널(예: 네이버 클립)에 브라우저 자동화로 업로드하면 플랫폼 약관 위반으로 업로드 제한·계정 정지·수익 정산 보류가 생길 수 있다. 도급인은 이를 이해하고 자동 업로드에 동의한다.', '{}', false, '미확인(D-8, D-15)', 1, 'draft', 30),
  (null, 'cam.revocation', 'channel_access_mandate', '위임 철회', '도급인은 언제든 서면(이메일 포함)으로 위임을 철회할 수 있고, 수급인은 통지를 받는 즉시 예약 업로드를 취소하고 접근 권한을 반납한다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 40),
  (null, 'cam.liability', 'channel_access_mandate', '책임', '수급인은 위임 범위를 넘는 계정 사용으로 생긴 손해를 배상한다. 위임 범위 안의 사용에 대해 플랫폼이 정책 변경으로 내린 제재는 수급인의 책임이 아니다.', '{}', true, '미확인(D-8, D-15)', 1, 'draft', 50)
on conflict (doc_type_code, code, version) where org_id is null do nothing;

insert into docs.runtime_config (key, value_int, note) values
  ('max_active_generations_per_org', 3,     '제안: 조직당 동시 생성(패키지 1건 = 1건). 01_PRD 5장'),
  ('daily_credit_cap',               20000, '제안: 플랫폼 일일 생성 크레딧 상한(KST 자정). 01_PRD 5장')
on conflict (key) do nothing;

-- @monolith-seed-begin (모놀리스 변환 시 이 표시부터 @monolith-seed-end 까지는 seed.sql 이 소유한다)
-- 플랜(01_PRD 4장, 기준서 10장, 전부 제안). 모듈러 seed.sql 에 docs 행이 들어오기 전(코어 요청 C-3)에도 가입이 되도록
-- do nothing 으로 넣는다. seed.sql 이 나중에 같은 키로 upsert 하면 그 값이 최종이다.
insert into core.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('docs', 'free', 'Free', 0, 'month', 30, 50, false,
   '{"projects_max": 2, "formats": ["pdf"], "watermark": true, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 30, "minutes_max_minutes": 30, "storage_mb": 200}',
   true, true, 0),
  ('docs', 'pro', 'Pro', 19900, 'month', 400, 0, false,
   '{"projects_max": 50, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv", "webhook"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 200, "minutes_max_minutes": 120, "storage_mb": 5000}',
   false, true, 1),
  ('docs', 'team', 'Team', 59000, 'month', 1500, 0, false,
   '{"projects_max": 300, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "phase2", "members_max": 5, "integrations": ["csv", "webhook", "hubspot", "admin_suite_erp", "n8n"], "approvals": true, "share_links": true, "ai_chat_turns_per_day": 500, "minutes_max_minutes": 180, "storage_mb": 20000}',
   false, false, 2)
on conflict (app_id, code) do nothing;

-- 기존 features 가 비어 있는(다른 경로로 먼저 만들어진) 행만 채운다. 값이 있으면 건드리지 않는다(반복 실행 가능).
update core.plans p
   set features = v.f::jsonb
  from (values
    ('free', '{"projects_max": 2, "formats": ["pdf"], "watermark": true, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 30, "minutes_max_minutes": 30, "storage_mb": 200}'),
    ('pro',  '{"projects_max": 50, "formats": ["pdf", "docx", "zip"], "watermark": false, "doc_phase": "mvp", "members_max": 1, "integrations": ["csv", "webhook"], "approvals": false, "share_links": false, "ai_chat_turns_per_day": 200, "minutes_max_minutes": 120, "storage_mb": 5000}')
  ) as v(code, f)
 where p.app_id = 'docs' and p.code = v.code and p.features = '{}'::jsonb;

insert into core.credit_packs (app_id, code, name, credits, price_krw, is_active, sort_order) values
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
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
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
  if exists (select 1 from core.ai_providers) then
    select string_agg(s.feature || '/' || s.kind || ':' || coalesce(e.item ->> 'provider', '?'), ', ') into v_bad
    from core.ai_routing_settings s
    cross join lateral jsonb_array_elements(s.chain) as e(item)
    left join core.ai_providers p on p.id = e.item ->> 'provider'
    where s.org_id is null and s.app_id = 'docs'
      and (p.id is null or not (s.kind = any (p.kinds))
           or ((s.mode = 'open_source' or s.force_open_source) and p.source <> 'open_source'));
    if v_bad is not null then
      raise exception 'docs routing defaults: invalid chain providers %', v_bad;
    end if;
  end if;
  if (select count(*) from core.ai_routing_settings s where s.org_id is null and s.app_id = 'docs') <> 13 then
    raise exception 'docs routing defaults: expected 13 rows';
  end if;
end $$;

-- @monolith-seed-end

-- 마지막: 이 조각이 만든 모든 함수의 PUBLIC EXECUTE 회수(SECURITY_BASELINE 3절). 위 허용 목록 GRANT 는 유지된다.
revoke execute on all functions in schema docs from public;
