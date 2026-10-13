-- 실행: 아래 @S@/@C@ 를 모듈러는 docs/core, 모놀리스는 public/public 으로 치환하고, "-- AS <행위자>" 마다
--       역할(service_role 또는 authenticated + request.jwt.claim.sub)을 바꿔 "-- TEST" 다음 한 문장씩 실행한다.
--       결과(2026-10-13, PGlite): 모듈러 59/59, 모놀리스 59/59 통과.
-- =====================================================================
-- rls_smoke.sql : NOMAD Docs RLS/권한 회귀 테스트 (DB_CONVENTIONS 13.3, SECURITY_BASELINE 15장)
-- 적용 순서: 코어 + 도메인 + seed 를 적용한 DB 에서 실행한다.
-- 모듈러: @S@ = docs, @C@ = core / 모놀리스: @S@ = public, @C@ = public (러너가 치환한다)
-- '-- RUN' 머리 다음 한 문장은 기대값 없이 실행한다(준비).
-- 각 검사는 "-- TEST <이름> | expect=<rows:N | ok | sqlstate:CODE>" 머리 + 한 문장. 러너가 순서대로 실행한다.
-- 사용자 A(조직 oA, 엔타이틀먼트 있음), B(조직 oB, 엔타이틀먼트 있음, A 의 비멤버), C(엔타이틀먼트 없음)
-- =====================================================================

-- SETUP (관리 세션)
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'a@test.local', '{"signup_app": "docs", "full_name": "A"}'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'b@test.local', '{"signup_app": "docs", "full_name": "B"}'),
  ('cccccccc-0000-4000-8000-000000000003', 'c@test.local', '{"full_name": "C"}');
-- C 는 엔타이틀먼트가 없어야 한다(모놀리스는 apps 1개면 자동 부여하므로 지운다)
delete from @C@.app_entitlements where org_id = (select id from @C@.organizations where owner_id = 'cccccccc-0000-4000-8000-000000000003');
create temp table t_ids as
  select (select id from @C@.organizations where owner_id = 'aaaaaaaa-0000-4000-8000-000000000001') as oa,
         (select id from @C@.organizations where owner_id = 'bbbbbbbb-0000-4000-8000-000000000002') as ob,
         (select id from @C@.organizations where owner_id = 'cccccccc-0000-4000-8000-000000000003') as oc;
grant select on t_ids to authenticated, service_role;
insert into @S@.parties (id, org_id, kind, name) select '11111111-0000-4000-8000-000000000001', oa, 'self', 'A사' from t_ids;
insert into @S@.parties (id, org_id, kind, name) select '11111111-0000-4000-8000-000000000002', oa, 'client', '고객사' from t_ids;
insert into @S@.projects (id, org_id, client_party_id, name) select '22222222-0000-4000-8000-000000000001', oa, '11111111-0000-4000-8000-000000000002', 'A 프로젝트' from t_ids;
insert into @S@.requirements (org_id, project_id, kind, title) select oa, '22222222-0000-4000-8000-000000000001', 'functional', '로그인' from t_ids;
insert into @S@.line_items (org_id, project_id, name, quantity, unit_price_krw) select oa, '22222222-0000-4000-8000-000000000001', '개발', 10, 400000 from t_ids;
insert into @S@.projects (id, org_id, name) select '22222222-0000-4000-8000-000000000003', oc, 'C 프로젝트' from t_ids;
-- END SETUP

-- AS service
-- TEST service start_generation(quote) | expect=ok
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 같은 멱등 키 재호출은 같은 실행 | expect=rows:1
select 1 from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001' having count(*) = 1;
-- TEST service 같은 문서 생성 중 재시작 DC002 | expect=sqlstate:DC002
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', (select document_id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001'), 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0002', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 크레딧 선차감 원장 행 | expect=rows:1
select 1 from @C@.credit_ledger where idempotency_key = 'consume:docs:aaaaaaaa-run-0001';
-- RUN
create temp table t_doc as select document_id as id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001';
-- RUN
grant select on t_doc to authenticated, service_role;
-- TEST service finish_generation 버전 1 저장 | expect=ok
select @S@.finish_generation((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001'), '[{"key":"header"}]'::jsonb, '<p>견적</p>', '{"client_party":"고객사","self_party":"A사","line_items":"1","quote":{"valid_until":"2026-11-30"}}'::jsonb, 'h1', '{"errors":[],"warnings":[]}'::jsonb, 'pass');
-- TEST service 계약서는 고지 동의 없이 생성 불가 DC007 | expect=sqlstate:DC007
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'dev_contract', null, null, null, 'gen:docs:aaaaaaaa-run-0003', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 비멤버(B)를 행위자로 A 조직 생성 42501 | expect=sqlstate:42501
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'wbs', null, null, null, 'gen:docs:aaaaaaaa-run-0004', 'bbbbbbbb-0000-4000-8000-000000000002');

-- AS A
-- TEST A 자기 문서 조회 | expect=rows:1
select 1 from @S@.documents where org_id = (select oa from t_ids);
-- TEST A 문서 status 직접 변경 42501 | expect=sqlstate:42501
update @S@.documents set status = 'final' where org_id = (select oa from t_ids);
-- TEST A 문서 title 변경(양성 대조) | expect=rows:1
update @S@.documents set title = '견적서(수정)' where org_id = (select oa from t_ids) returning 1;
-- TEST A 버전 직접 INSERT 42501 | expect=sqlstate:42501
insert into @S@.document_versions (org_id, document_id, version, doc_type_version, created_kind) select org_id, id, 2, 1, 'edited' from @S@.documents where org_id = (select oa from t_ids);
-- TEST A 요구사항 req_code 자동 부여 FR-001 | expect=rows:1
select 1 from @S@.requirements where org_id = (select oa from t_ids) and req_code = 'FR-001';
-- TEST A 요구사항 수정 시 is_user_modified=true | expect=rows:1
update @S@.requirements set title = '로그인(이메일)' where org_id = (select oa from t_ids) returning case when is_user_modified then 1 end;
-- TEST A 프로젝트 합계 뷰(4,000,000 + VAT 400,000) | expect=rows:1
select 1 from @S@.project_totals where project_id = '22222222-0000-4000-8000-000000000001' and subtotal_krw = 4000000 and vat_krw = 400000 and total_krw = 4400000;
-- TEST A 확정 버전 불일치 DC010 | expect=sqlstate:DC010
select @S@.finalize_document((select id from @S@.documents where org_id = (select oa from t_ids)), 9, false);
-- TEST A 문서 확정 | expect=ok
select @S@.finalize_document((select id from @S@.documents where org_id = (select oa from t_ids)), 1, false);
-- TEST A 문서번호 QT-연도-0001 형식 | expect=rows:1
select 1 from @S@.documents where org_id = (select oa from t_ids) and status = 'final' and doc_number ~ '^QT-[0-9]{4}-0001$';
-- TEST A 확정 문서 재확정 DC003 | expect=sqlstate:DC003
select @S@.finalize_document((select id from @S@.documents where org_id = (select oa from t_ids)), 1, false);
-- TEST A 확정 문서 title 변경 DC003 | expect=sqlstate:DC003
update @S@.documents set title = 'x' where org_id = (select oa from t_ids);
-- TEST A 서비스 전용 RPC start_generation 호출 42501 | expect=sqlstate:42501
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'wbs', null, null, null, 'gen:docs:aaaaaaaa-run-0005', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST A 서비스 전용 RPC finish_generation 호출 42501 | expect=sqlstate:42501
select @S@.finish_generation(gen_random_uuid(), '[]'::jsonb, null, null, null, null, 'pass');
-- TEST A 프로젝트 status 직접 변경 42501 | expect=sqlstate:42501
update @S@.projects set status = 'active' where id = '22222222-0000-4000-8000-000000000001';
-- TEST A 프로젝트 상태 RPC(draft -> active) | expect=ok
select @S@.set_project_status('22222222-0000-4000-8000-000000000001', 'active');
-- TEST A 프로젝트 잘못된 전이(active -> draft) DC001 | expect=sqlstate:DC001
select @S@.set_project_status('22222222-0000-4000-8000-000000000001', 'draft');
-- TEST A 연동 연결 직접 INSERT 42501 | expect=sqlstate:42501
insert into @S@.integration_connections (org_id, provider, kind) select oa, 'csv', 'file' from t_ids;
-- TEST A 크레딧 원장 직접 INSERT 42501 | expect=sqlstate:42501
insert into @C@.credit_ledger default values;

-- AS B
-- TEST B 가 A 의 projects 조회 0행 | expect=rows:0
select 1 from @S@.projects where org_id = (select oa from t_ids);
-- TEST B 가 A 의 parties 조회 0행 | expect=rows:0
select 1 from @S@.parties where org_id = (select oa from t_ids);
-- TEST B 가 A 의 requirements 조회 0행 | expect=rows:0
select 1 from @S@.requirements where org_id = (select oa from t_ids);
-- TEST B 가 A 의 line_items 조회 0행 | expect=rows:0
select 1 from @S@.line_items where org_id = (select oa from t_ids);
-- TEST B 가 A 의 documents 조회 0행 | expect=rows:0
select 1 from @S@.documents where org_id = (select oa from t_ids);
-- TEST B 가 A 의 document_versions 조회 0행 | expect=rows:0
select 1 from @S@.document_versions where org_id = (select oa from t_ids);
-- TEST B 가 A 의 generation_runs 조회 0행 | expect=rows:0
select 1 from @S@.generation_runs where org_id = (select oa from t_ids);
-- TEST B 가 A 의 project_totals 조회 0행 | expect=rows:0
select 1 from @S@.project_totals where org_id = (select oa from t_ids);
-- TEST B 가 org_id=A 로 projects INSERT 42501 | expect=sqlstate:42501
insert into @S@.projects (org_id, name) select oa, '침투' from t_ids;
-- TEST B 가 org_id=A 로 parties INSERT 42501 | expect=sqlstate:42501
insert into @S@.parties (org_id, kind, name) select oa, 'client', '침투' from t_ids;
-- TEST B 자기 조직 프로젝트 생성(양성 대조) | expect=rows:1
insert into @S@.projects (org_id, name) select ob, 'B 프로젝트' from t_ids returning 1;
-- TEST B 자기 프로젝트의 org_id 를 A 로 변경 42501 | expect=sqlstate:42501
update @S@.projects set org_id = (select oa from t_ids) where org_id = (select ob from t_ids);
-- TEST B 자기 조직 요구사항을 A 프로젝트에 연결 시도 차단(번호 부여 전 멤버 검사, 그 뒤 복합 FK) | expect=sqlstate:42501
insert into @S@.requirements (org_id, project_id, kind, title) select ob, '22222222-0000-4000-8000-000000000001', 'functional', '침투' from t_ids;
-- TEST B 가 A 문서 title 변경 0행 | expect=rows:0
update @S@.documents set title = '침투' where org_id = (select oa from t_ids) returning 1;
-- TEST B 가 A 문서 확정 시도 42501 | expect=sqlstate:42501
select @S@.finalize_document((select id from t_doc), 1, false);
-- TEST B document_versions INSERT 42501 | expect=sqlstate:42501
insert into @S@.document_versions (org_id, document_id, version, doc_type_version, created_kind) values ((select ob from t_ids), gen_random_uuid(), 1, 1, 'edited');
-- TEST B generation_runs INSERT 42501 | expect=sqlstate:42501
insert into @S@.generation_runs (org_id, project_id, idempotency_key) select ob, gen_random_uuid(), 'gen:docs:bbbbbbbb-run-0001' from t_ids;
-- TEST B doc_exports INSERT 42501 | expect=sqlstate:42501
insert into @S@.doc_exports (org_id, project_id, format) select ob, gen_random_uuid(), 'pdf' from t_ids;
-- TEST B external_refs INSERT 42501 | expect=sqlstate:42501
insert into @S@.external_refs (org_id, connection_id, entity, internal_id, external_type, external_id) values ((select ob from t_ids), gen_random_uuid(), 'party', gen_random_uuid(), 'company', '1');
-- TEST B risk_acknowledgements INSERT 42501 | expect=sqlstate:42501
insert into @S@.risk_acknowledgements (org_id, doc_type_code, notice_version) values ((select ob from t_ids), 'dev_contract', 'notice-contract-2026-10-13');
-- TEST B 카탈로그 doc_types 쓰기 42501 | expect=sqlstate:42501
update @S@.doc_types set credits = 0 where code = 'quote';
-- TEST B 카탈로그 doc_types 읽기(양성 대조, 엔타이틀먼트 있음) | expect=rows:9
select 1 from @S@.doc_types where phase = 'mvp' and is_active;
-- TEST B 자기 지갑 조작 42501 | expect=sqlstate:42501
update @C@.wallets set org_id = org_id where org_id = (select ob from t_ids);
-- TEST B 서비스 전용 next_doc_number 호출 42501 | expect=sqlstate:42501
select @S@.next_doc_number((select ob from t_ids), 'quote');

-- AS C
-- TEST C(엔타이틀먼트 없음) 자기 프로젝트 조회 0행 | expect=rows:0
select 1 from @S@.projects where org_id = (select oc from t_ids);
-- TEST C 카탈로그 조회 0행 | expect=rows:0
select 1 from @S@.doc_types;
-- TEST C 자기 조직 프로젝트 INSERT 42501 | expect=sqlstate:42501
insert into @S@.projects (org_id, name) select oc, 'x' from t_ids;

-- AS service
-- TEST service 버전 UPDATE 불가 DC003 | expect=sqlstate:DC003
update @S@.document_versions set body_html = 'x' where org_id = (select oa from t_ids);
-- TEST service 버전 DELETE 불가 DC003 | expect=sqlstate:DC003
delete from @S@.document_versions where org_id = (select oa from t_ids);
-- TEST service 확정 문서에 새 버전 INSERT 불가 DC003 | expect=sqlstate:DC003
insert into @S@.document_versions (org_id, document_id, version, doc_type_version, created_kind) select org_id, id, 2, 1, 'edited' from @S@.documents where org_id = (select oa from t_ids);
-- TEST service 게시된 유형 버전 수정 불가 DC003 | expect=sqlstate:DC003
update @S@.doc_type_versions set structure = '[]'::jsonb where doc_type_code = 'quote' and version = 1;
-- TEST service 확정 -> 보관 전이 허용 | expect=ok
select @S@.archive_document((select id from @S@.documents where org_id = (select oa from t_ids)));
-- TEST service 보관 -> 확정 전이 불가 DC001 | expect=sqlstate:DC001
update @S@.documents set status = 'final' where org_id = (select oa from t_ids);
