-- 실행: 아래 @S@/@C@ 를 모듈러는 docs/core, 모놀리스는 public/public 으로 치환하고, "-- AS <행위자>" 마다
--       역할(service_role 또는 authenticated + request.jwt.claim.sub)을 바꿔 "-- TEST" 다음 한 문장씩 실행한다.
--       결과(2026-10-14, PGlite): 모듈러 105/105, 모놀리스 105/105 통과(2026-10-13 59항목 + 교차검증 회귀·신규 기능·독립 검토 회귀 46항목).
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
select 1 from @C@.credit_ledger where idempotency_key = 'consume:docs:gen:aaaaaaaa-run-0001';
-- RUN
create temp table t_doc as select document_id as id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001';
-- RUN
grant select on t_doc to authenticated, service_role;
-- TEST service finish_generation 버전 1 저장 | expect=ok
select @S@.finish_generation((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001'), '[{"key":"header"}]'::jsonb, '<p>견적</p>', '{"client_party":"고객사","self_party":"A사","line_items":"1","quote":{"valid_until":"2026-11-30"}}'::jsonb, null, '{"errors":[],"warnings":[],"ran_at":"2026-10-14T00:00:00Z","rules":["L-AMOUNT-MATCH"]}'::jsonb, 'pass');
-- TEST service 결과를 넘긴 실행의 잡은 환불 표시가 꺼짐(교차검증 #4) | expect=rows:1
select 1 from @C@.jobs where id = (select job_id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0001') and not refund_on_failure;
-- TEST service seed 에서 계약서 유형은 비활성(D-3 전, 교차검증 #1) | expect=rows:1
select 1 from @S@.doc_types where code = 'dev_contract' and not is_active;
-- TEST service 비활성 계약서 생성 거부 22023 | expect=sqlstate:22023
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'dev_contract', null, null, null, 'gen:docs:aaaaaaaa-run-00c1', 'aaaaaaaa-0000-4000-8000-000000000001');
-- RUN
update @S@.doc_types set is_active = true where code = 'dev_contract';
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
-- TEST A 원가·요구사항이 바뀐 낡은 문서 확정 DC010(교차검증 #2) | expect=sqlstate:DC010
select @S@.finalize_document((select id from t_doc), 1, false);

-- AS service
-- RUN
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', (select id from t_doc), 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0005', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 재생성 결과 저장(버전 2) | expect=ok
select @S@.finish_generation((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0005'), '[{"key":"header"}]'::jsonb, '<p>견적2</p>', '{"client_party":"고객사","self_party":"A사","line_items":"1","quote":{"valid_until":"2026-11-30"}}'::jsonb, null, '{"errors":[],"warnings":[],"ran_at":"2026-10-14T00:00:00Z","rules":["L-AMOUNT-MATCH"]}'::jsonb, 'pass');
-- RUN
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0009', 'aaaaaaaa-0000-4000-8000-000000000001');
-- RUN
create temp table t_doc2 as select document_id as id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0009';
-- RUN
grant select on t_doc2 to authenticated, service_role;
-- TEST service lint 미실행 결과 저장(ran_at 없음) | expect=ok
select @S@.finish_generation((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0009'), '[{"key":"header"}]'::jsonb, '<p>견적3</p>', '{"client_party":"고객사","self_party":"A사","line_items":"1","quote":{"valid_until":"2026-11-30"}}'::jsonb, null, '{"errors":[],"warnings":[]}'::jsonb, 'pass');

-- AS A
-- TEST A lint 를 돌리지 않은 버전 확정 DC005(교차검증 #2) | expect=sqlstate:DC005
select @S@.finalize_document((select id from t_doc2), 1, false);
-- TEST A 확정 버전 불일치 DC010 | expect=sqlstate:DC010
select @S@.finalize_document((select id from t_doc), 9, false);
-- TEST A 문서 확정 | expect=ok
select @S@.finalize_document((select id from t_doc), 2, false);
-- TEST A 문서번호 QT-연도-0001 형식 | expect=rows:1
select 1 from @S@.documents where id = (select id from t_doc) and status = 'final' and doc_number ~ '^QT-[0-9]{4}-0001$';
-- TEST A 확정 문서 재확정 DC003 | expect=sqlstate:DC003
select @S@.finalize_document((select id from t_doc), 2, false);
-- TEST A 확정 문서 title 변경 DC003 | expect=sqlstate:DC003
update @S@.documents set title = 'x' where id = (select id from t_doc);
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
insert into @S@.document_versions (org_id, document_id, version, doc_type_version, created_kind) select org_id, id, 3, 1, 'edited' from @S@.documents where id = (select id from t_doc);
-- TEST service 게시된 유형 버전 수정 불가 DC003 | expect=sqlstate:DC003
update @S@.doc_type_versions set structure = '[]'::jsonb where doc_type_code = 'quote' and version = 1;
-- TEST service 확정 -> 보관 전이 허용 | expect=ok
select @S@.archive_document((select id from t_doc));
-- TEST service 보관 -> 확정 전이 불가 DC001 | expect=sqlstate:DC001
update @S@.documents set status = 'final' where id = (select id from t_doc);

-- ---------------------------------------------------------------------
-- 2026-10-14 추가: 교차검증 "반드시 고칠 것" 회귀(06_AGENT_PLAN.md 1.2.4)
-- ---------------------------------------------------------------------
-- AS service
-- RUN
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0006', 'aaaaaaaa-0000-4000-8000-000000000001');
-- RUN
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0007', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 패키지 자식 형식 멱등 키(<run_id>:<doc_type_code>) 허용(교차검증 #12) | expect=ok
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'wbs', null, null, null, 'gen:docs:aaaaaaaa-run-0010:wbs_child', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 조직 동시 생성 3건 초과 DC006 | expect=sqlstate:DC006
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', null, 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0011', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 진행 단계 보고(DC-F-054) | expect=ok
select @S@.report_generation_progress((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0010:wbs_child'), 'drafting', 'phases', 1, 3);
-- TEST service 진행 단계가 실행 행에 남음(Realtime 대상) | expect=rows:1
select 1 from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0010:wbs_child' and progress ->> 'stage' = 'drafting' and status = 'running';
-- TEST service 잘못된 진행 단계 22023 | expect=sqlstate:22023
select @S@.report_generation_progress((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0010:wbs_child'), 'teleport', null, 0, 1);

-- AS A
-- TEST A 진행 보고 RPC 호출 42501 | expect=sqlstate:42501
select @S@.report_generation_progress((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0006'), 'drafting', null, 0, 1);
-- TEST A 대기 중 생성 취소(교차검증 #3) | expect=ok
select @S@.cancel_generation((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0006'));
-- TEST A 취소 후 실행 canceled·문서 draft | expect=rows:1
select 1 from @S@.generation_runs g join @S@.documents d on d.id = g.document_id where g.idempotency_key = 'gen:docs:aaaaaaaa-run-0006' and g.status = 'canceled' and d.status = 'draft';
-- TEST A 취소 환불 원장 행 | expect=rows:1
select 1 from @C@.credit_ledger where entry_type = 'refund' and refund_of = (select credit_ledger_id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0006');
-- TEST A 실행 중 생성은 취소 불가 DC001 | expect=sqlstate:DC001
select @S@.cancel_generation((select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0010:wbs_child'));
-- RUN
select @C@.cancel_job((select job_id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0007'));
-- TEST A 없는 실행 취소 P0002 | expect=sqlstate:P0002
select @S@.cancel_generation(gen_random_uuid());

-- AS service
-- TEST service 코어 잡만 취소된 실행도 다음 생성 전에 정리되어 같은 문서 재생성 가능(교차검증 #3) | expect=ok
select @S@.start_generation((select oa from t_ids), '22222222-0000-4000-8000-000000000001', (select document_id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0007'), 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0008', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 정리된 실행은 canceled | expect=rows:1
select 1 from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0007' and status = 'canceled';
-- RUN
create temp table t_run8 as select id from @S@.generation_runs where idempotency_key = 'gen:docs:aaaaaaaa-run-0008';
-- RUN
grant select on t_run8 to authenticated, service_role;

-- AS B
-- TEST B 가 A 조직 대기 실행 취소 42501 | expect=sqlstate:42501
select @S@.cancel_generation((select id from t_run8));

-- AS service
-- RUN
update @S@.runtime_config set value_int = 1 where key = 'daily_credit_cap';
-- TEST service 일일 상한은 생성 밖 차감(reserve_credits)에도 적용 DC006(교차검증 #11) | expect=sqlstate:DC006
select @S@.reserve_credits((select oa from t_ids), 'aaaaaaaa-0000-4000-8000-000000000001', 3, 'docs.extract', 'docs_upload', 'u1', 'consume:docs:extract:aaaaaaaa-req-0001', '{}'::jsonb);
-- RUN
update @S@.runtime_config set value_int = 20000 where key = 'daily_credit_cap';
-- TEST service reserve_credits 차감(양성 대조) | expect=ok
select @S@.reserve_credits((select oa from t_ids), 'aaaaaaaa-0000-4000-8000-000000000001', 3, 'docs.extract', 'docs_upload', 'u1', 'consume:docs:extract:aaaaaaaa-req-0001', '{}'::jsonb);
-- TEST service 같은 멱등 키 재호출은 같은 원장 행·사용량 1회 | expect=rows:1
select 1 from @C@.credit_ledger where idempotency_key = 'consume:docs:extract:aaaaaaaa-req-0001' having count(*) = 1;
-- TEST service 같은 키를 다른 금액으로 재사용 거부 22023(키 재사용 과금 우회 차단) | expect=sqlstate:22023
select @S@.reserve_credits((select oa from t_ids), 'aaaaaaaa-0000-4000-8000-000000000001', 10, 'docs.extract', 'docs_upload', 'u1', 'consume:docs:extract:aaaaaaaa-req-0001', '{}'::jsonb);
-- TEST service 생성 전용 네임스페이스(gen:) 사용 거부 22023 | expect=sqlstate:22023
select @S@.reserve_credits((select oa from t_ids), 'aaaaaaaa-0000-4000-8000-000000000001', 2, 'docs.export', 'docs_export', 'e1', 'consume:docs:gen:aaaaaaaa-run-0001', '{}'::jsonb);
-- TEST service 다른 조직의 키 재사용 42501 | expect=sqlstate:42501
select @S@.reserve_credits((select ob from t_ids), 'bbbbbbbb-0000-4000-8000-000000000002', 3, 'docs.extract', 'docs_upload', 'u1', 'consume:docs:extract:aaaaaaaa-req-0001', '{}'::jsonb);
-- TEST service 다른 조직의 생성 멱등 키 재사용 42501 | expect=sqlstate:42501
select @S@.start_generation((select ob from t_ids), gen_random_uuid(), null, 'quote', null, null, null, 'gen:docs:aaaaaaaa-run-0001', 'bbbbbbbb-0000-4000-8000-000000000002');
-- RUN
create temp table t_hash as select @S@.checklist_answers_hash('22222222-0000-4000-8000-000000000001') as h;
-- RUN
grant select on t_hash to authenticated, service_role;
-- RUN
update @S@.checklist_items set effects = effects || '[{"id":"fr_social","target":"requirements","kind":"functional","title":"소셜 로그인","priority":"could"}]'::jsonb where key = 'feat.login';
-- TEST service 효과가 바뀌면 항목 version 증가·이력 2행(교차검증 #6) | expect=rows:1
select 1 from @S@.checklist_items i where i.key = 'feat.login' and i.version = 2 and (select count(*) from @S@.checklist_item_versions v where v.key = 'feat.login') = 2;
-- TEST service 항목 이력 수정 불가 DC003 | expect=sqlstate:DC003
update @S@.checklist_item_versions set label = 'x' where key = 'feat.login';
-- TEST service 라벨만 바뀌면 version 유지 | expect=rows:1
update @S@.checklist_items set label = '회원가입·로그인(계정)' where key = 'feat.login' returning case when version = 2 then 1 end;

-- AS A
-- TEST A 체크리스트 답 형식 오류(boolean 항목에 문자열) 22023(교차검증 #13) | expect=sqlstate:22023
insert into @S@.checklist_answers (project_id, org_id, item_key, value) select '22222222-0000-4000-8000-000000000001', oa, 'feat.login', '"ultra"'::jsonb from t_ids;
-- TEST A 선택지에 없는 값 22023 | expect=sqlstate:22023
insert into @S@.checklist_answers (project_id, org_id, item_key, value) select '22222222-0000-4000-8000-000000000001', oa, 'nfr.security_level', '"ultra"'::jsonb from t_ids;
-- TEST A 올바른 답 입력(양성 대조) | expect=ok
insert into @S@.checklist_answers (project_id, org_id, item_key, value) select '22222222-0000-4000-8000-000000000001', oa, 'feat.login', 'true'::jsonb from t_ids;

-- AS service
-- TEST service 답이 바뀌면 효과 해시가 바뀜 | expect=rows:1
select 1 where @S@.checklist_answers_hash('22222222-0000-4000-8000-000000000001') <> (select h from t_hash);

-- AS A
-- RUN
insert into @S@.requirements (org_id, project_id, kind, title) select oa, '22222222-0000-4000-8000-000000000001', 'functional', '가입' from t_ids;
-- RUN
delete from @S@.requirements where project_id = '22222222-0000-4000-8000-000000000001' and req_code = 'FR-002';
-- RUN
insert into @S@.requirements (org_id, project_id, kind, title) select oa, '22222222-0000-4000-8000-000000000001', 'functional', '탈퇴' from t_ids;
-- TEST A 지운 마지막 코드는 재사용하지 않음(FR-003, 교차검증 #8) | expect=rows:1
select 1 from @S@.requirements where project_id = '22222222-0000-4000-8000-000000000001' and title = '탈퇴' and req_code = 'FR-003';
-- TEST A 유형·연도 토큰 없는 문서번호 서식 거부 23514(교차검증 #10) | expect=sqlstate:23514
insert into @S@.workspace_settings (org_id, doc_number_format) select oa, '{YYYY}-{SEQ:4}' from t_ids;
-- RUN
insert into @S@.projects (org_id, name) select oa, 'A 두 번째' from t_ids;
-- TEST A Free 한도(2개) 초과 생성 DC006 | expect=sqlstate:DC006
insert into @S@.projects (org_id, name) select oa, 'A 세 번째' from t_ids;
-- RUN
update @S@.projects set deleted_at = now() where name = 'A 두 번째';
-- RUN
insert into @S@.projects (org_id, name) select oa, 'A 세 번째' from t_ids;
-- TEST A 삭제했던 프로젝트 복구로 한도 우회 DC006(교차검증 #9) | expect=sqlstate:DC006
update @S@.projects set deleted_at = null where name = 'A 두 번째';

-- AS A
-- TEST A CRM 파이프라인 뷰에 자기 프로젝트 1행(DC-F-047) | expect=rows:1
select 1 from @S@.project_pipeline where project_id = '22222222-0000-4000-8000-000000000001' and stage in ('lead', 'drafting', 'quoted');
-- TEST A 활동 타임라인에 자기 프로젝트 기록 | expect=rows:1
select 1 from @S@.project_activity where project_id = '22222222-0000-4000-8000-000000000001' having count(*) >= 3;

-- AS B
-- TEST B 파이프라인·활동 뷰에서 A 조직 0행 | expect=rows:0
select 1 from @S@.project_pipeline where org_id = (select oa from t_ids) union all select 1 from @S@.project_activity where org_id = (select oa from t_ids);

-- AS A
-- TEST A 요구사항 상태를 직접 바꾸면 사용자 수정으로 표시(재적용이 되돌리지 않음) | expect=rows:1
update @S@.requirements set status = 'rejected' where project_id = '22222222-0000-4000-8000-000000000001' and title = '탈퇴' returning case when is_user_modified then 1 end;
-- TEST A 코드 함수 직접 호출 42501(카운터 소모 방지) | expect=sqlstate:42501
select @S@.next_project_code('22222222-0000-4000-8000-000000000001', 'requirements', 'FR');
-- RUN
update @S@.line_items set unit_price_krw = 450000 where project_id = '22222222-0000-4000-8000-000000000001' and name = '개발';

-- AS service
-- TEST service 생성 중 정본이 바뀌면 완료 뒤에도 재생성 필요 유지 | expect=ok
select @S@.finish_generation((select id from t_run8), '[{"key":"header"}]'::jsonb, '<p>견적4</p>', '{"client_party":"고객사","self_party":"A사","line_items":"1","quote":{"valid_until":"2026-11-30"}}'::jsonb, null, '{"errors":[],"warnings":[],"ran_at":"2026-10-14T00:00:00Z","rules":["L-AMOUNT-MATCH"]}'::jsonb, 'pass');
-- TEST service 생성 중 변경된 문서는 needs_regeneration=true | expect=rows:1
select 1 from @S@.documents d join @S@.generation_runs g on g.document_id = d.id where g.id = (select id from t_run8) and d.needs_regeneration and d.status = 'review';
