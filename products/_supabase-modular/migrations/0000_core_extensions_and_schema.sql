-- =====================================================================
-- 0000_core_extensions_and_schema.sql
-- 통합 Supabase 프로젝트(모듈러)의 출발점.
-- 확장 기능, core 스키마, 기본 권한, 공용 트리거/세션 헬퍼를 만든다.
-- PostgreSQL 15 / Supabase 표준 객체만 사용. 반복 실행해도 안전하다.
-- =====================================================================

-- 확장: gen_random_bytes(암호 난수)는 pgcrypto. gen_random_uuid()는 PG13+ 내장.
create extension if not exists pgcrypto with schema extensions;

-- pg_cron은 호스팅 프로젝트에서 대시보드로 켠다. 로컬에서는 선택 사항이라 주석으로 둔다.
-- create extension if not exists pg_cron;

create schema if not exists core;
comment on schema core is '플랫폼 공통: 인증/조직, 플랜/구독/결제, 크레딧 원장, 보안, 잡';

grant usage on schema core to anon, authenticated, service_role;

-- 기본 권한 원칙
--   service_role : 모든 테이블/시퀀스/함수 (RLS는 BYPASSRLS 속성으로 통과)
--   authenticated: 파일별로 SELECT 또는 컬럼 단위 UPDATE만 명시적으로 부여
--   anon         : 가격표(apps/plans/credit_packs) SELECT만
--   함수         : PUBLIC 기본 EXECUTE를 제거하고 필요한 역할에만 부여
alter default privileges in schema core grant all on tables to service_role;
alter default privileges in schema core grant all on sequences to service_role;
alter default privileges in schema core grant execute on functions to service_role;
alter default privileges in schema core revoke execute on functions from public;

-- ---------------------------------------------------------------------
-- 공용 트리거: updated_at 갱신
-- ---------------------------------------------------------------------
create or replace function core.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 세션 헬퍼
--   core.jwt_role()              : PostgREST 요청의 JWT role 클레임 ('anon' | 'authenticated' | 'service_role' | 'none')
--   core.is_privileged_session() : service_role 요청이거나 DB 소유 세션(마이그레이션, pg_cron, SECURITY DEFINER 내부)
--   core.is_service_caller()     : "실제 호출자"가 service_role이거나 JWT 없는 DB 관리 세션(마이그레이션, pg_cron)
-- 쓰기 보호 트리거와 service_role 전용 RPC(EXECUTE가 service_role에만 있는 함수)는 is_privileged_session으로 판정한다.
-- authenticated에 EXECUTE를 연 SECURITY DEFINER 함수 안에서는 반드시 is_service_caller를 쓴다.
--   이유: DEFINER 함수 안에서는 current_user가 함수 소유자(postgres)라서 is_privileged_session()이
--   항상 true가 되고, "서버가 아니면 역할 검사" 분기가 통째로 건너뛰어진다.
-- ---------------------------------------------------------------------
create or replace function core.jwt_role()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
    'none'
  );
$$;

create or replace function core.is_privileged_session()
returns boolean
language sql
stable
set search_path = ''
as $$
  select core.jwt_role() = 'service_role'
      or current_user in ('postgres', 'supabase_admin', 'supabase_auth_admin');
$$;

-- session_user는 SECURITY DEFINER 안에서도 바뀌지 않는다. PostgREST 요청은 session_user가
-- authenticator이고 JWT role이 항상 있으므로, JWT가 없는 관리 세션만 두 번째 조건으로 통과한다.
create or replace function core.is_service_caller()
returns boolean
language sql
stable
set search_path = ''
as $$
  select core.jwt_role() = 'service_role'
      or (core.jwt_role() = 'none' and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin'));
$$;

grant execute on function core.jwt_role() to anon, authenticated;
grant execute on function core.is_privileged_session() to anon, authenticated;
grant execute on function core.is_service_caller() to anon, authenticated;

-- ---------------------------------------------------------------------
-- 쓰기 보호 트리거: service_role 또는 DB 소유 세션이 아니면 어떤 쓰기도 거부한다.
-- 정책이 없는 테이블에 "이중 잠금"으로 붙인다(org_members, subscriptions, wallets 등).
-- ---------------------------------------------------------------------
create or replace function core.guard_privileged_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not core.is_privileged_session() then
    raise exception 'core: % on %.% is allowed only for service_role', tg_op, tg_table_schema, tg_table_name
      using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
