-- =====================================================================
-- tenant_theming_smoke.sql : 멀티테넌트 테마 RLS·권한 회귀 테스트 (DB_CONVENTIONS 13.3, SECURITY_BASELINE 15장 형식)
-- 실행: node Multi-tenant_Theming/supabase/tests/run-smoke.mjs --target mod   (모듈러: @C@ = core)
--       node Multi-tenant_Theming/supabase/tests/run-smoke.mjs --target mono  (모놀리스: @C@ = public)
-- 형식: "-- AS <행위자>" 로 역할 전환(service, anon, A, M, B, C), "-- RUN" 다음 한 문장은 준비,
--       "-- TEST <이름> | expect=<rows:N | ok | sqlstate:CODE>" 다음 한 문장이 검사.
-- 행위자: A = 조직 oa(slug acme) owner, 화이트라벨 단계 3 플랜 / M = oa 의 member
--         B = 조직 ob owner, 기본 플랜(단계 0) / C = 엔타이틀먼트 없음 / anon = 비로그인
-- =====================================================================

-- SETUP (관리 세션)
insert into @C@.apps (id, name, schema_name, signup_policy, status) values ('docs', 'NOMAD Docs', 'docs', 'open', 'beta') on conflict (id) do nothing;
insert into @C@.plans (app_id, code, name, price_krw, billing_interval, features, is_default) values ('docs', 'free', 'Free', 0, 'month', '{}', true) on conflict (app_id, code) do nothing;
insert into @C@.plans (app_id, code, name, price_krw, billing_interval, features, is_default) values ('docs', 'wl_test', 'White-label Test', 0, 'month', '{"theming_level": 3}', false) on conflict (app_id, code) do nothing;
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'a@test.local', '{"signup_app": "docs", "full_name": "A"}'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'b@test.local', '{"signup_app": "docs", "full_name": "B"}'),
  ('cccccccc-0000-4000-8000-000000000003', 'c@test.local', '{"full_name": "C"}'),
  ('dddddddd-0000-4000-8000-000000000004', 'm@test.local', '{"signup_app": "docs", "full_name": "M"}');
delete from @C@.app_entitlements where org_id = (select id from @C@.organizations where owner_id = 'cccccccc-0000-4000-8000-000000000003');
update @C@.organizations set slug = 'acme', is_personal = false, name = 'ACME' where owner_id = 'aaaaaaaa-0000-4000-8000-000000000001';
create temp table t_ids as
  select (select id from @C@.organizations where owner_id = 'aaaaaaaa-0000-4000-8000-000000000001') as oa,
         (select id from @C@.organizations where owner_id = 'bbbbbbbb-0000-4000-8000-000000000002') as ob,
         (select id from @C@.organizations where owner_id = 'cccccccc-0000-4000-8000-000000000003') as oc,
         (select slug from @C@.organizations where owner_id = 'bbbbbbbb-0000-4000-8000-000000000002') as ob_slug;
grant select on t_ids to anon, authenticated, service_role;
insert into @C@.org_members (org_id, user_id, role, status, joined_at) select oa, 'dddddddd-0000-4000-8000-000000000004', 'member', 'active', now() from t_ids;
update @C@.app_entitlements set plan_id = (select id from @C@.plans where app_id = 'docs' and code = 'wl_test') where org_id = (select oa from t_ids) and app_id = 'docs';
-- END SETUP

-- AS A
-- TEST A 자기 조직 단계 3 | expect=rows:1
select 1 where @C@.theming_level((select oa from t_ids), 'docs') = 3;
-- TEST A 초안 테마 생성 | expect=rows:1
insert into @C@.tenant_themes (org_id, app_id, name, brand_name, tokens, logo_horizontal_path) select oa, 'docs', 'v1', 'ACME', '{"light": {"brand": "#1d4ed8", "radius-control": "8px"}, "dark": {"brand": "oklch(0.7 0.15 250)"}}', oa::text || '/theming/logo-h.svg' from t_ids returning 1;
-- TEST A CSS 주입 토큰 거부 | expect=sqlstate:23514
insert into @C@.tenant_themes (org_id, app_id, name, brand_name, tokens) select oa, 'docs', 'bad', 'X', '{"light": {"brand": "red;}body{display:none"}}' from t_ids;
-- TEST A 허용 목록 밖 토큰(background) 거부 | expect=sqlstate:23514
insert into @C@.tenant_themes (org_id, app_id, name, brand_name, tokens) select oa, 'docs', 'bad', 'X', '{"light": {"background": "#000000"}}' from t_ids;
-- TEST A url() 서체 거부 | expect=sqlstate:23514
insert into @C@.tenant_themes (org_id, app_id, name, brand_name, fonts) select oa, 'docs', 'bad', 'X', '{"heading": "https://evil.example/font.woff2"}' from t_ids;
-- TEST A 다른 조직 경로의 로고 거부 | expect=sqlstate:23514
insert into @C@.tenant_themes (org_id, app_id, name, brand_name, logo_mark_path) select oa, 'docs', 'bad', 'X', ob::text || '/theming/x.svg' from t_ids;
-- TEST A 경로 상위 이동(..) 거부 | expect=sqlstate:23514
insert into @C@.tenant_themes (org_id, app_id, name, brand_name, logo_mark_path) select oa, 'docs', 'bad', 'X', oa::text || '/theming/../x.svg' from t_ids;
-- TEST A status 직접 변경 42501 | expect=sqlstate:42501
update @C@.tenant_themes set status = 'published' where name = 'v1';
-- TEST A 대비 결과 직접 기록 42501 | expect=sqlstate:42501
update @C@.tenant_themes set contrast_report = '{"passed": true}' where name = 'v1';
-- TEST A 대비 검사 전 게시 TM002 | expect=sqlstate:TM002
select @C@.publish_tenant_theme((select id from @C@.tenant_themes where name = 'v1'));

-- AS service
-- RUN
create temp table t_theme as select id from @C@.tenant_themes where name = 'v1';
-- RUN
grant select on t_theme to anon, authenticated, service_role;

-- AS M
-- TEST M(member) 테마 조회 | expect=rows:1
select 1 from @C@.tenant_themes where name = 'v1';
-- TEST M(member) 테마 생성 42501 | expect=sqlstate:42501
insert into @C@.tenant_themes (org_id, app_id, name, brand_name) select oa, 'docs', 'm', 'M' from t_ids;
-- TEST M(member) 테마 수정 0행 | expect=rows:0
update @C@.tenant_themes set brand_name = 'M' where name = 'v1' returning 1;
-- TEST M(member) 게시 42501 | expect=sqlstate:42501
select @C@.publish_tenant_theme((select id from @C@.tenant_themes where name = 'v1'));

-- AS B
-- TEST B 가 A 테마 조회 0행 | expect=rows:0
select 1 from @C@.tenant_themes where org_id = (select oa from t_ids);
-- TEST B 가 A 조직에 테마 생성 42501 | expect=sqlstate:42501
insert into @C@.tenant_themes (org_id, app_id, name, brand_name) select oa, 'docs', 'b', 'B' from t_ids;
-- TEST B 단계 0 인 자기 조직에 테마 생성 42501 | expect=sqlstate:42501
insert into @C@.tenant_themes (org_id, app_id, name, brand_name) select ob, 'docs', 'b', 'B' from t_ids;
-- TEST B 에게 A 조직 단계는 0 | expect=rows:1
select 1 where @C@.theming_level((select oa from t_ids), 'docs') = 0;
-- TEST B 가 A 테마 게시 42501 | expect=sqlstate:42501
select @C@.publish_tenant_theme((select id from t_theme));
-- TEST B 가 A 테마 복제 42501 | expect=sqlstate:42501
select @C@.clone_tenant_theme((select id from t_theme));
-- TEST B 가 A 조직 도메인 요청 42501 | expect=sqlstate:42501
select @C@.request_tenant_domain((select oa from t_ids), 'docs', 'evil.example.com');

-- AS service
-- TEST service 대비 결과 기록 | expect=rows:1
update @C@.tenant_themes set contrast_report = '{"passed": true, "checked_by": "server"}', contrast_checked_at = now() where name = 'v1' returning 1;

-- AS A
-- RUN
update @C@.tenant_themes set tokens = '{"light": {"brand": "#2563eb"}, "dark": {}}' where name = 'v1';
-- TEST A 토큰을 바꾸면 대비 결과가 지워진다 | expect=rows:1
select 1 from @C@.tenant_themes where name = 'v1' and contrast_report is null;

-- AS service
-- RUN
update @C@.tenant_themes set contrast_report = '{"passed": true, "checked_by": "server"}', contrast_checked_at = now() where name = 'v1';

-- AS A
-- TEST A 게시 | expect=ok
select @C@.publish_tenant_theme((select id from @C@.tenant_themes where name = 'v1'));
-- TEST A 게시본 버전 1 | expect=rows:1
select 1 from @C@.tenant_themes where name = 'v1' and status = 'published' and version = 1 and published_by = 'aaaaaaaa-0000-4000-8000-000000000001';
-- TEST A 게시본 내용 수정 0행 | expect=rows:0
update @C@.tenant_themes set brand_name = 'Changed' where name = 'v1' returning 1;
-- TEST A 게시본 삭제 0행 | expect=rows:0
delete from @C@.tenant_themes where name = 'v1' returning 1;
-- TEST A 게시본 복제 | expect=ok
select @C@.clone_tenant_theme((select id from @C@.tenant_themes where name = 'v1'));
-- TEST A 복제본은 초안이고 대비 결과를 이어받는다 | expect=rows:1
select 1 from @C@.tenant_themes where name = 'v1 (복사본)' and status = 'draft' and contrast_report ->> 'passed' = 'true';
-- TEST A 복제본 게시 | expect=ok
select @C@.publish_tenant_theme((select id from @C@.tenant_themes where name = 'v1 (복사본)'));
-- TEST A 이전 게시본은 보관, 새 게시본 버전 2 | expect=rows:2
select 1 from @C@.tenant_themes where (name = 'v1' and status = 'archived') or (name = 'v1 (복사본)' and status = 'published' and version = 2);
-- TEST A 보관본 재게시 TM001 | expect=sqlstate:TM001
select @C@.publish_tenant_theme((select id from @C@.tenant_themes where name = 'v1'));
-- TEST A 게시 감사 기록 2건 | expect=rows:1
select 1 from @C@.audit_log where org_id = (select oa from t_ids) and action = 'theme.publish' having count(*) = 2;

-- AS service
-- TEST service 가 게시본 내용 수정도 TM003 | expect=sqlstate:TM003
update @C@.tenant_themes set brand_name = 'X' where name = 'v1 (복사본)';

-- AS anon
-- TEST anon 슬러그로 해석, 게시본 버전 2 | expect=rows:1
select 1 where (@C@.resolve_tenant(null, 'acme', 'docs') -> 'theme' ->> 'version')::int = 2;
-- TEST anon 해석 결과에 로고 경로 포함 | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') -> 'theme' -> 'assets' ->> 'logo_horizontal' like '%/theming/logo-h.svg';
-- TEST anon 단계 0 조직은 null(기본 테마) | expect=rows:1
select 1 where @C@.resolve_tenant(null, (select ob_slug from t_ids), 'docs') is null;
-- TEST anon 없는 슬러그 null | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'nope', 'docs') is null;
-- TEST anon 테마 테이블 직접 조회 42501 | expect=sqlstate:42501
select 1 from @C@.tenant_themes;
-- TEST anon theming_level 실행 42501 | expect=sqlstate:42501
select @C@.theming_level((select oa from t_ids), 'docs');
-- TEST anon 내부 함수 실행 42501 | expect=sqlstate:42501
select @C@.theming_level_unchecked((select oa from t_ids), 'docs');

-- AS A
-- TEST A 라벨 추가(단계 2 이상) | expect=ok
insert into @C@.tenant_labels (org_id, app_id, locale, key, value) select oa, 'docs', 'ko', 'nav.customers', '수강생' from t_ids;
-- TEST A 잘못된 라벨 키 거부 | expect=sqlstate:23514
insert into @C@.tenant_labels (org_id, app_id, locale, key, value) select oa, 'docs', 'ko', 'Bad Key!', 'x' from t_ids;
-- TEST A 설정 저장(내비게이션 포함) | expect=ok
insert into @C@.tenant_settings (org_id, app_id, support_email, email_from_name, legal, navigation) select oa, null, 'help@acme.co.kr', 'ACME 고객센터', '{"company_name": "ACME", "business_no": "123-45-67890"}', '[{"key": "customers", "order": 1}, {"key": "billing", "hidden": true}]' from t_ids;
-- TEST A javascript: 고객센터 URL 거부 | expect=sqlstate:23514
update @C@.tenant_settings set support_url = 'javascript:alert(1)' where org_id = (select oa from t_ids);
-- TEST A 발신자 이름에 꺾쇠 거부 | expect=sqlstate:23514
update @C@.tenant_settings set email_from_name = 'ACME <admin@evil>' where org_id = (select oa from t_ids);
-- TEST A 커스텀 도메인 요청 | expect=ok
select @C@.request_tenant_domain((select oa from t_ids), 'docs', ' App.Acme.co.kr. ');
-- TEST A 같은 도메인 재요청 TM005 | expect=sqlstate:TM005
select @C@.request_tenant_domain((select oa from t_ids), 'docs', 'app.acme.co.kr');
-- TEST A 잘못된 호스트 이름 거부 | expect=sqlstate:23514
select @C@.request_tenant_domain((select oa from t_ids), 'docs', 'https://acme.co.kr/x');
-- TEST A 도메인 테이블 직접 INSERT 42501 | expect=sqlstate:42501
insert into @C@.tenant_domains (org_id, app_id, hostname) select oa, 'docs', 'x.acme.co.kr' from t_ids;
-- TEST A 도메인 상태 직접 변경 42501 | expect=sqlstate:42501
select @C@.set_tenant_domain_status((select id from @C@.tenant_domains where hostname = 'app.acme.co.kr'), 'active');

-- AS B
-- TEST B 가 A 도메인 조회 0행 | expect=rows:0
select 1 from @C@.tenant_domains where hostname = 'app.acme.co.kr';
-- TEST B 단계 0 에서 커스텀 도메인 요청 42501 | expect=sqlstate:42501
select @C@.request_tenant_domain((select ob from t_ids), 'docs', 'b.example.com');
-- TEST B 가 A 라벨 조회 0행 | expect=rows:0
select 1 from @C@.tenant_labels where org_id = (select oa from t_ids);
-- TEST B 가 A 설정 수정 0행 | expect=rows:0
update @C@.tenant_settings set support_email = 'x@evil.com' where org_id = (select oa from t_ids) returning 1;

-- AS anon
-- TEST anon 활성화 전 도메인은 해석되지 않음 | expect=rows:1
select 1 where @C@.resolve_tenant('app.acme.co.kr', null, null) is null;

-- AS service
-- TEST service 도메인 확인 중 | expect=ok
select @C@.set_tenant_domain_status((select id from @C@.tenant_domains where hostname = 'app.acme.co.kr'), 'verifying', '{"records": [{"type": "CNAME", "name": "app", "value": "cname.vercel-dns.com"}]}');
-- TEST service 도메인 활성화 | expect=ok
select @C@.set_tenant_domain_status((select id from @C@.tenant_domains where hostname = 'app.acme.co.kr'), 'active');
-- TEST service 첫 활성 도메인은 대표 도메인 | expect=rows:1
select 1 from @C@.tenant_domains where hostname = 'app.acme.co.kr' and is_primary and verified_at is not null;
-- TEST service 잘못된 전이(active→verifying) 22023 | expect=sqlstate:22023
select @C@.set_tenant_domain_status((select id from @C@.tenant_domains where hostname = 'app.acme.co.kr'), 'verifying');

-- AS anon
-- TEST anon 도메인으로 해석(대소문자·포트 무시) | expect=rows:1
select 1 where @C@.resolve_tenant('APP.ACME.CO.KR:443', null, null) ->> 'org_id' = (select oa::text from t_ids);
-- TEST anon 슬러그 해석에 대표 도메인 포함(301 이동용) | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') ->> 'primary_domain' = 'app.acme.co.kr';
-- TEST anon 단계 3 에서 내비게이션 노출 | expect=rows:1
select 1 where jsonb_array_length(@C@.resolve_tenant('app.acme.co.kr', null, null) -> 'settings' -> 'navigation') = 2;
-- TEST anon 공개 라벨 | expect=rows:1
select 1 where @C@.tenant_public_labels((select oa from t_ids), 'docs', 'ko') ->> 'nav.customers' = '수강생';

-- AS service
-- TEST service 슬롯 확장 등록 | expect=ok
insert into @C@.tenant_extensions (org_id, app_id, slot_key, extension_key, config) select oa, 'docs', 'dashboard.home', 'acme-home', '{"widgets": ["kpi"]}' from t_ids;
-- TEST service 훅 확장 등록(단계 4 전용) | expect=ok
insert into @C@.tenant_extensions (org_id, app_id, slot_key, extension_key, kind) select oa, 'docs', 'order.after_create', 'acme-erp-sync', 'hook' from t_ids;
-- TEST service 단계 덮어쓰기 범위 밖(7) 거부 | expect=sqlstate:23514
insert into @C@.tenant_feature_overrides (org_id, app_id, feature_key, value) select oa, 'docs', 'theming_level', '7' from t_ids;
-- TEST service 배포 기록(모델 B) | expect=ok
insert into @C@.tenant_deployments (org_id, app_id, deploy_model, supabase_project_ref) select oa, 'docs', 'B', 'abcd1234' from t_ids;

-- AS anon
-- TEST anon 단계 3: 슬롯만 노출, 훅은 숨김 | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') -> 'extensions' = '{"dashboard.home": "acme-home"}'::jsonb;

-- AS A
-- TEST A 확장 키 조회 | expect=rows:2
select slot_key from @C@.tenant_extensions where org_id = (select oa from t_ids);
-- TEST A 확장 config 조회 42501 | expect=sqlstate:42501
select config from @C@.tenant_extensions;
-- TEST A 확장 직접 등록 42501 | expect=sqlstate:42501
insert into @C@.tenant_extensions (org_id, app_id, slot_key, extension_key) select oa, 'docs', 'x.y', 'z' from t_ids;
-- TEST A 배포 기록 조회 | expect=rows:1
select 1 from @C@.tenant_deployments where org_id = (select oa from t_ids);
-- TEST A 배포 기록 수정 42501 | expect=sqlstate:42501
update @C@.tenant_deployments set deploy_model = 'C';
-- TEST A 단계 덮어쓰기 직접 INSERT 42501 | expect=sqlstate:42501
insert into @C@.tenant_feature_overrides (org_id, app_id, feature_key, value) select oa, 'docs', 'theming_level', '4' from t_ids;

-- AS M
-- TEST M(member) 확장 조회 0행 | expect=rows:0
select 1 from @C@.tenant_extensions;
-- TEST M(member) 배포 기록 조회 0행 | expect=rows:0
select 1 from @C@.tenant_deployments;

-- AS B
-- TEST B 가 A 배포 기록 조회 0행 | expect=rows:0
select 1 from @C@.tenant_deployments;
-- TEST B 가 A 기능 값 조회 42501 | expect=sqlstate:42501
select @C@.effective_features((select oa from t_ids), 'docs');

-- AS service
-- TEST service 조직 단계를 1로 낮춤 | expect=ok
insert into @C@.tenant_feature_overrides (org_id, app_id, feature_key, value, reason) select oa, 'docs', 'theming_level', '1', '다운그레이드 테스트' from t_ids;

-- AS anon
-- TEST anon 단계 1: 내비게이션 비노출 | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') -> 'settings' -> 'navigation' = '[]'::jsonb;
-- TEST anon 단계 1: 라벨 비노출 | expect=rows:1
select 1 where @C@.tenant_public_labels((select oa from t_ids), 'docs', 'ko') = '{}'::jsonb;
-- TEST anon 단계 1: 확장 비노출 | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') -> 'extensions' = '{}'::jsonb;
-- TEST anon 단계 1: 대표 도메인 비노출 | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') ->> 'primary_domain' is null;
-- TEST anon 단계 1: 테마는 그대로 | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'acme', 'docs') -> 'theme' ->> 'brand_name' = 'ACME';

-- AS A
-- TEST A 단계 1 에서 라벨 추가 42501 | expect=sqlstate:42501
insert into @C@.tenant_labels (org_id, app_id, locale, key, value) select oa, 'docs', 'ko', 'nav.orders', '수강 신청' from t_ids;
-- TEST A 단계 1 에서 커스텀 도메인 요청 42501 | expect=sqlstate:42501
select @C@.request_tenant_domain((select oa from t_ids), 'docs', 'www.acme.co.kr');
-- TEST A 기능 값에 덮어쓰기 반영 | expect=rows:1
select 1 where (@C@.effective_features((select oa from t_ids), 'docs') ->> 'theming_level')::int = 1;

-- AS C
-- TEST C(엔타이틀먼트 없음) 단계 0 | expect=rows:1
select 1 where @C@.theming_level((select oc from t_ids), null) = 0;
-- TEST C 테마 생성 42501 | expect=sqlstate:42501
insert into @C@.tenant_themes (org_id, name, brand_name) select oc, 'c', 'C' from t_ids;

-- AS service
-- RUN
update @C@.app_entitlements set status = 'suspended' where org_id = (select oa from t_ids) and app_id = 'docs';

-- AS anon
-- TEST anon 엔타이틀먼트 정지 시 기본 테마(null) | expect=rows:1
select 1 where @C@.resolve_tenant('app.acme.co.kr', null, null) is null;
