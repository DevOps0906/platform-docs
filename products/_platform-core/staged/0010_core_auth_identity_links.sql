-- =====================================================================
-- 0010_core_auth_identity_links.sql  (보류 마이그레이션, staged)
-- 정본: docs/products/_platform-core/AUTH_ROADMAP.md 7.2.3절
--
-- 언제 적용하나
--   인증 Stage C2(네이버) 스파이크에서 Supabase 커스텀 제공자(custom:naver)가 실패해
--   "브리지 경로"를 택했을 때만 적용한다. custom:naver 경로면 적용하지 않는다(Supabase auth.identities가 대신한다).
--
-- 적용 방법
--   모듈러: 이 파일을 docs/products/_supabase-modular/migrations/0010_core_auth_identity_links.sql 로 옮긴다.
--   모놀리스: "core." 를 "public." 으로 바꿔 제품 supabase/monolith/migrations/ 의 다음 번호로 추가한다
--            (DB_CONVENTIONS.md 9장 변환 규칙과 같다).
--   검사: docs/products/_tools-sqlcheck 에서 0000~0009 다음에 이 파일을 넣어 OK 확인.
--
-- 설계
--   - 외부 로그인 제공자의 고유 사용자 id -> Supabase auth.users.id 매핑. 이메일로 찾지 않는다(계정 탈취 방지).
--   - 쓰기는 service_role(서버 브리지)만. 사용자는 자기 행만 읽는다(설정 > 로그인 방법 화면).
--   - 제공자 토큰은 저장하지 않는다(로그인에만 쓰고 버린다).
-- 선행: 0000 ~ 0004
-- =====================================================================

create table if not exists core.auth_identity_links (
  provider          text not null
                    constraint auth_identity_links_provider_check check (provider in ('naver')),
  provider_user_id  text not null
                    constraint auth_identity_links_provider_user_id_check check (length(provider_user_id) between 1 and 200),
  user_id           uuid not null references auth.users(id) on delete cascade,
  email_at_link     text,
  created_at        timestamptz not null default now(),
  last_login_at     timestamptz,
  primary key (provider, provider_user_id)
);

-- 한 사용자에 같은 제공자 계정은 1개만 연결한다.
create unique index if not exists auth_identity_links_user_provider_uidx
  on core.auth_identity_links (user_id, provider);

alter table core.auth_identity_links enable row level security;

drop trigger if exists auth_identity_links_guard_write on core.auth_identity_links;
create trigger auth_identity_links_guard_write before insert or update or delete on core.auth_identity_links
  for each row execute function core.guard_privileged_write();

drop policy if exists auth_identity_links_select_self on core.auth_identity_links;
create policy auth_identity_links_select_self on core.auth_identity_links
  for select to authenticated using (user_id = auth.uid());

revoke all on core.auth_identity_links from public, anon, authenticated;
grant select on core.auth_identity_links to authenticated;
grant select, insert, update, delete on core.auth_identity_links to service_role;
