-- 실행: node products/book-trailer/supabase/monolith/tests/run-smoke.mjs --target mod | mono
--       러너가 @S@/@C@ 를 모듈러는 trailer/core, 모놀리스는 public/public 으로 치환하고, "-- AS <행위자>" 마다
--       역할(service_role 또는 authenticated + request.jwt.claim.sub)을 바꿔 "-- TEST" 다음 한 문장씩 실행한다.
-- =====================================================================
-- rls_smoke.sql : NOMAD Book Trailer RLS/권한 회귀 테스트 (DB_CONVENTIONS 13.3, SECURITY_BASELINE 15장)
-- 적용 순서: 코어 + 도메인 + seed 를 적용한 DB 에서 실행한다.
-- '-- RUN' 머리 다음 한 문장은 기대값 없이 실행한다(준비).
-- 각 검사는 "-- TEST <이름> | expect=<rows:N | ok | sqlstate:CODE>" 머리 + 한 문장. 러너가 순서대로 실행한다.
-- 행위자: A(조직 oA owner, creator 플랜으로 올림), M(oA member), V(oA viewer), B(조직 oB owner, free 플랜, A 의 비멤버),
--         C(엔타이틀먼트 없음), anon, service
-- =====================================================================

-- SETUP (관리 세션)
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'a@test.local', '{"signup_app": "trailer", "full_name": "A"}'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'b@test.local', '{"signup_app": "trailer", "full_name": "B"}'),
  ('cccccccc-0000-4000-8000-000000000003', 'c@test.local', '{"full_name": "C"}'),
  ('dddddddd-0000-4000-8000-000000000004', 'm@test.local', '{"signup_app": "trailer", "full_name": "M"}'),
  ('eeeeeeee-0000-4000-8000-000000000005', 'v@test.local', '{"signup_app": "trailer", "full_name": "V"}');
-- C 는 엔타이틀먼트가 없어야 한다(모놀리스는 apps 1개면 자동 부여하므로 지운다)
delete from @C@.app_entitlements where org_id = (select id from @C@.organizations where owner_id = 'cccccccc-0000-4000-8000-000000000003');
create temp table t_ids as
  select (select id from @C@.organizations where owner_id = 'aaaaaaaa-0000-4000-8000-000000000001') as oa,
         (select id from @C@.organizations where owner_id = 'bbbbbbbb-0000-4000-8000-000000000002') as ob,
         (select id from @C@.organizations where owner_id = 'cccccccc-0000-4000-8000-000000000003') as oc;
grant select on t_ids to authenticated, service_role;
-- M(member), V(viewer) 를 oA 에 추가
insert into @C@.org_members (org_id, user_id, role, status, joined_at)
  select oa, 'dddddddd-0000-4000-8000-000000000004', 'member', 'active', now() from t_ids;
insert into @C@.org_members (org_id, user_id, role, status, joined_at)
  select oa, 'eeeeeeee-0000-4000-8000-000000000005', 'viewer', 'active', now() from t_ids;
-- A 조직을 creator 플랜으로 올린다(가입 크레딧 60 은 free 가입 때 받은 그대로)
update @C@.app_entitlements set plan_id = (select id from @C@.plans where app_id = 'trailer' and code = 'creator')
 where org_id = (select oa from t_ids) and app_id = 'trailer';
-- 책: oA 의 b1(원고 파싱 완료), oB 의 bb1(권리 확인 완료), oC 의 bc1
insert into @S@.books (id, org_id, title, author_name, genre, source, manuscript_path, manuscript_sha256, manuscript_chars)
  select '11111111-0000-4000-8000-000000000001', oa, '북위 37도의 약속', '리치노마드', 'novel', 'upload',
         oa::text || '/trailer/books/11111111-0000-4000-8000-000000000001/manuscript.md', repeat('a', 64), 120000 from t_ids;
insert into @S@.books (id, org_id, title, genre, source, rights_ack_version, rights_ack_at)
  select '11111111-0000-4000-8000-000000000002', ob, 'B의 책', 'essay', 'paste', 'rights-2026-10-v1', now() from t_ids;
insert into @S@.books (id, org_id, title, genre, source)
  select '11111111-0000-4000-8000-000000000003', oc, 'C의 책', 'essay', 'paste' from t_ids;
insert into @S@.trailers (id, org_id, book_id, title, grammar_code, template_code)
  select '22222222-0000-4000-8000-000000000002', ob, '11111111-0000-4000-8000-000000000002', 'B 트레일러', 'essay_quote', 'essay_paper' from t_ids;
-- END SETUP

-- AS A
-- TEST A 자기 책 조회 | expect=rows:1
select 1 from @S@.books where org_id = (select oa from t_ids);
-- TEST A 다른 조직 책은 안 보임 | expect=rows:0
select 1 from @S@.books where org_id = (select ob from t_ids);
-- TEST A 두 번째 책 추가(creator 한도 10) | expect=ok
insert into @S@.books (id, org_id, title, genre, source) select '11111111-0000-4000-8000-000000000004', oa, '두 번째 책', 'self_help', 'paste' from t_ids;
-- TEST A 원고 해시 직접 변경 42501(컬럼 GRANT 없음) | expect=sqlstate:42501
update @S@.books set manuscript_sha256 = repeat('b', 64) where id = '11111111-0000-4000-8000-000000000001';
-- TEST A 권리 확인 컬럼 직접 변경 42501 | expect=sqlstate:42501
update @S@.books set rights_ack_version = 'rights-2026-10-v1' where id = '11111111-0000-4000-8000-000000000001';
-- TEST A FLORA 출처 책 직접 생성 42501(정책) | expect=sqlstate:42501
insert into @S@.books (org_id, title, source, flora_book_id) select oa, 'x', 'flora', gen_random_uuid() from t_ids;
-- TEST A 다른 조직 폴더를 표지 경로로 23514 | expect=sqlstate:23514
update @S@.books set cover_path = (select ob from t_ids)::text || '/trailer/books/11111111-0000-4000-8000-000000000001/cover.png' where id = '11111111-0000-4000-8000-000000000001';
-- TEST A 권리 확인 잘못된 버전 22023 | expect=sqlstate:22023
select @S@.acknowledge_rights('11111111-0000-4000-8000-000000000001', 'v1');
-- TEST A 권리 확인 | expect=ok
select @S@.acknowledge_rights('11111111-0000-4000-8000-000000000001', 'rights-2026-10-v1');
-- TEST A 권리 확인 기록 남음(DEFINER 쓰기가 트리거에 되돌려지지 않음) | expect=rows:1
select 1 from @S@.books where id = '11111111-0000-4000-8000-000000000001' and rights_ack_at is not null and rights_ack_by = 'aaaaaaaa-0000-4000-8000-000000000001';
-- TEST A 원고 경로를 바꾸면 분석 상태 초기화(양성 대조: 책 2) | expect=rows:1
update @S@.books set manuscript_path = (select oa from t_ids)::text || '/trailer/books/11111111-0000-4000-8000-000000000004/manuscript.pdf' where id = '11111111-0000-4000-8000-000000000004' returning case when digest_status = 'none' and manuscript_sha256 is null then 1 end;
-- TEST A 트레일러 생성 | expect=ok
insert into @S@.trailers (id, org_id, book_id, title, grammar_code, template_code, formats, duration_s) select '22222222-0000-4000-8000-000000000001', oa, '11111111-0000-4000-8000-000000000001', '북위 37도 티저', 'novel_cinematic', 'cinematic_basic', array['vertical_9_16'], 30 from t_ids;
-- TEST A 엔드카드 자동 생성 | expect=rows:1
select 1 from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'end_card';
-- TEST A 엔드카드 직접 생성 42501(정책) | expect=sqlstate:42501
insert into @S@.scenes (org_id, trailer_id, position, kind) select oa, '22222222-0000-4000-8000-000000000001', 5, 'end_card' from t_ids;
-- TEST A 엔드카드 삭제는 정책에 걸려 0행 | expect=rows:0
delete from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'end_card' returning 1;
-- TEST A 장면 kind 변경 42501(컬럼 GRANT 없음) | expect=sqlstate:42501
update @S@.scenes set kind = 'title_card' where trailer_id = '22222222-0000-4000-8000-000000000001';
-- TEST A 이미지 장면 추가 | expect=ok
insert into @S@.scenes (id, org_id, trailer_id, position, kind, duration_ms, text) select '33333333-0000-4000-8000-000000000001', oa, '22222222-0000-4000-8000-000000000001', 1, 'image_scene', 4000, '밤의 도시' from t_ids;
-- TEST A 장면 저장 revision 충돌 TR409 | expect=sqlstate:TR409
select @S@.save_scene('33333333-0000-4000-8000-000000000001', '{"text":"x"}'::jsonb, 9);
-- TEST A 장면 저장 알 수 없는 키 22023 | expect=sqlstate:22023
select @S@.save_scene('33333333-0000-4000-8000-000000000001', '{"kind":"end_card"}'::jsonb, 1);
-- TEST A 장면 저장(revision 2) | expect=rows:1
select 1 where @S@.save_scene('33333333-0000-4000-8000-000000000001', '{"text":"잠들지 않는 도시","duration_ms":5000}'::jsonb, 1) = 2;
-- TEST A 엔드카드가 마지막이 아닌 순서 TR007 | expect=sqlstate:TR007
select @S@.reorder_scenes('22222222-0000-4000-8000-000000000001', array[(select id from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'end_card'), '33333333-0000-4000-8000-000000000001'::uuid]);
-- TEST A 순서 변경(엔드카드 마지막) | expect=ok
select @S@.reorder_scenes('22222222-0000-4000-8000-000000000001', array['33333333-0000-4000-8000-000000000001'::uuid, (select id from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'end_card')]);
-- TEST A 수동 브리프 저장(버전 1) | expect=rows:1
insert into @S@.briefs (org_id, trailer_id, source, content) select oa, '22222222-0000-4000-8000-000000000001', 'manual', '{"logline":"약속의 밤"}'::jsonb from t_ids returning case when version = 1 then 1 end;
-- TEST A AI 출처로 넣어도 manual 로 저장(버전 2, AI 표시 위조 불가) | expect=rows:1
insert into @S@.briefs (org_id, trailer_id, source, content) select oa, '22222222-0000-4000-8000-000000000001', 'ai', '{}'::jsonb from t_ids returning case when source = 'manual' and ai_run_id is null and version = 2 then 1 end;
-- TEST A 브리프 수정 42501(불변) | expect=sqlstate:42501
update @S@.briefs set content = '{}'::jsonb where trailer_id = '22222222-0000-4000-8000-000000000001';
-- TEST A 실행 기록 직접 INSERT 42501 | expect=sqlstate:42501
insert into @S@.generation_runs (org_id, kind, book_id, idempotency_key) select oa, 'digest', '11111111-0000-4000-8000-000000000001', 'run:trailer:direct-0001' from t_ids;
-- TEST A 서비스 전용 start_run 호출 42501 | expect=sqlstate:42501
select @S@.start_run((select oa from t_ids), 'digest', '11111111-0000-4000-8000-000000000001', null, null, 0, 'run:trailer:aaaaaaaa-0000', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST A 서비스 전용 start_render 호출 42501 | expect=sqlstate:42501
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '720p', 0, gen_random_uuid(), 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST A 고정 목소리 직접 변경 42501 | expect=sqlstate:42501
update @S@.trailers set voice = '{"provider":"x"}'::jsonb where id = '22222222-0000-4000-8000-000000000001';
-- TEST A 렌더 없이 승인 TR004 | expect=sqlstate:TR004
update @S@.trailers set status = 'approved' where id = '22222222-0000-4000-8000-000000000001';
-- TEST A 구매 링크(제휴) 추가 | expect=ok
insert into @S@.purchase_links (id, org_id, book_id, store, url, is_affiliate) select '44444444-0000-4000-8000-000000000001', oa, '11111111-0000-4000-8000-000000000001', 'aladin', 'https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=1', true from t_ids;
-- TEST A http 링크 거부 23514 | expect=sqlstate:23514
insert into @S@.purchase_links (org_id, book_id, store, url) select oa, '11111111-0000-4000-8000-000000000001', 'other', 'http://example.com' from t_ids;
-- TEST A 클릭 수 직접 변경 42501 | expect=sqlstate:42501
update @S@.purchase_links set click_count = 999 where id = '44444444-0000-4000-8000-000000000001';
-- TEST A 제휴 링크가 있는 메타데이터는 대가성 문구가 첫 줄 | expect=rows:1
insert into @S@.metadata_packs (org_id, trailer_id, platform, title, description, link_ids) select oa, '22222222-0000-4000-8000-000000000001', 'youtube_shorts', '북위 37도의 약속', '책 소개', array['44444444-0000-4000-8000-000000000001'::uuid] from t_ids returning case when has_affiliate and description like '이 설명에는 제휴 링크가%' then 1 end;
-- TEST A 대가성 문구를 지우려 해도 다시 들어감 | expect=rows:1
update @S@.metadata_packs set description = '문구 없이' where trailer_id = '22222222-0000-4000-8000-000000000001' and platform = 'youtube_shorts' returning case when left(description, char_length(disclosure)) = disclosure then 1 end;
-- TEST A has_affiliate 직접 끄기 42501 | expect=sqlstate:42501
update @S@.metadata_packs set has_affiliate = false where trailer_id = '22222222-0000-4000-8000-000000000001';
-- TEST A 해시태그 공백 포함 23514 | expect=sqlstate:23514
insert into @S@.metadata_packs (org_id, trailer_id, platform, title, hashtags) select oa, '22222222-0000-4000-8000-000000000001', 'tiktok', 't', array['#북 트레일러'] from t_ids;
-- TEST A 운영 상수 조회 42501 | expect=sqlstate:42501
select 1 from @S@.runtime_config;
-- TEST A 음악 원본 경로 조회 42501(컬럼 GRANT 없음) | expect=sqlstate:42501
select storage_path from @S@.music_tracks;
-- TEST A 공개 문법 카탈로그 조회 6종 | expect=rows:6
select 1 from @S@.grammars;
-- TEST A 잘못된 팔레트 23514 | expect=sqlstate:23514
insert into @S@.brand_kits (org_id, name, palette) select oa, 'x', '[{"role":"text","hex":"#000"}]'::jsonb from t_ids;
-- TEST A 브랜드 키트 생성 | expect=ok
insert into @S@.brand_kits (id, org_id, book_id, name, palette, font_display) select '55555555-0000-4000-8000-000000000001', oa, '11111111-0000-4000-8000-000000000001', '표지 키트', '[{"role":"background","hex":"#0E1A2B"},{"role":"text","hex":"#F4EFE6"},{"role":"accent","hex":"#C8553D"}]'::jsonb, 'gowun_batang' from t_ids;

-- AS M
-- TEST M(member) 책 조회 | expect=rows:2
select 1 from @S@.books where org_id = (select oa from t_ids);
-- TEST M 장면 추가 | expect=ok
insert into @S@.scenes (org_id, trailer_id, position, kind, text) select oa, '22222222-0000-4000-8000-000000000001', 7, 'hook_text', '그날 밤, 약속은 깨졌다' from t_ids;
-- TEST M 책 삭제는 owner/admin 만(0행) | expect=rows:0
delete from @S@.books where id = '11111111-0000-4000-8000-000000000004' returning 1;

-- AS V
-- TEST V(viewer) 책 조회 | expect=rows:2
select 1 from @S@.books where org_id = (select oa from t_ids);
-- TEST V 책 제목 수정 0행 | expect=rows:0
update @S@.books set title = 'v' where id = '11111111-0000-4000-8000-000000000001' returning 1;
-- TEST V 트레일러 생성 42501 | expect=sqlstate:42501
insert into @S@.trailers (org_id, book_id, title, grammar_code, template_code) select oa, '11111111-0000-4000-8000-000000000001', 'v', 'novel_cinematic', 'cinematic_basic' from t_ids;
-- TEST V 권리 확인 42501 | expect=sqlstate:42501
select @S@.acknowledge_rights('11111111-0000-4000-8000-000000000004', 'rights-2026-10-v1');

-- AS B
-- TEST B 다른 조직 트레일러 수정 0행 | expect=rows:0
update @S@.trailers set title = 'hack' where id = '22222222-0000-4000-8000-000000000001' returning 1;
-- TEST B 다른 조직 장면 저장 P0002(보이지 않음) | expect=sqlstate:P0002
select @S@.save_scene('33333333-0000-4000-8000-000000000001', '{"text":"x"}'::jsonb, 2);
-- TEST B 다른 조직 책으로 자기 조직 트레일러 23503(복합 FK) | expect=sqlstate:23503
insert into @S@.trailers (org_id, book_id, title, grammar_code, template_code) select ob, '11111111-0000-4000-8000-000000000001', 'x', 'novel_cinematic', 'cinematic_basic' from t_ids;
-- TEST B free 플랜 두 번째 책 TR005 | expect=sqlstate:TR005
insert into @S@.books (org_id, title, source) select ob, 'B 두 번째', 'paste' from t_ids;
-- TEST B 다른 조직 메타데이터 조회 0행 | expect=rows:0
select 1 from @S@.metadata_packs;

-- AS C
-- TEST C(엔타이틀먼트 없음) 카탈로그 0행 | expect=rows:0
select 1 from @S@.grammars;
-- TEST C 책 생성 42501 | expect=sqlstate:42501
insert into @S@.books (org_id, title, source) select oc, 'c', 'paste' from t_ids;

-- AS anon
-- TEST anon 책 조회 42501 | expect=sqlstate:42501
select 1 from @S@.books;
-- TEST anon 카탈로그 조회 42501 | expect=sqlstate:42501
select 1 from @S@.grammars;

-- AS service
-- TEST service 권리 확인 없는 책 분석 TR003 | expect=sqlstate:TR003
select @S@.start_run((select oa from t_ids), 'digest', '11111111-0000-4000-8000-000000000004', null, null, 20, 'run:trailer:aaaaaaaa-dig-0000', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 분석 전 브리프 TR004 | expect=sqlstate:TR004
select @S@.start_run((select oa from t_ids), 'brief', null, '22222222-0000-4000-8000-000000000001', null, 8, 'run:trailer:aaaaaaaa-brf-0000', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 원고 분석 시작 | expect=ok
select @S@.start_run((select oa from t_ids), 'digest', '11111111-0000-4000-8000-000000000001', null, null, 20, 'run:trailer:aaaaaaaa-dig-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 같은 멱등 키는 같은 실행 | expect=rows:1
select 1 from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-dig-0001' having count(*) = 1;
-- TEST service 크레딧 선차감 원장 행 | expect=rows:1
select 1 from @C@.credit_ledger where idempotency_key = 'consume:trailer:run:aaaaaaaa-dig-0001';
-- TEST service 책 분석 상태 queued | expect=rows:1
select 1 from @S@.books where id = '11111111-0000-4000-8000-000000000001' and digest_status = 'queued';
-- TEST service 같은 대상 분석 중 재시작 TR002 | expect=sqlstate:TR002
select @S@.start_run((select oa from t_ids), 'digest', '11111111-0000-4000-8000-000000000001', null, null, 20, 'run:trailer:aaaaaaaa-dig-0002', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 다른 조직이 같은 멱등 키 42501 | expect=sqlstate:42501
select @S@.start_run((select ob from t_ids), 'digest', '11111111-0000-4000-8000-000000000002', null, null, 0, 'run:trailer:aaaaaaaa-dig-0001', 'bbbbbbbb-0000-4000-8000-000000000002');
-- TEST service 비멤버 행위자 42501 | expect=sqlstate:42501
select @S@.start_run((select oa from t_ids), 'meta', null, '22222222-0000-4000-8000-000000000001', null, 2, 'run:trailer:aaaaaaaa-met-0009', 'bbbbbbbb-0000-4000-8000-000000000002');
-- TEST service 원고 분석 종료 | expect=ok
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-dig-0001'), '{"chapters":[{"n":1,"title":"1장","summary":"약속"}],"characters":[{"name":"서연"}]}'::jsonb);
-- TEST service 결과를 넘긴 잡은 환불 표시 해제 | expect=rows:1
select 1 from @C@.jobs where id = (select job_id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-dig-0001') and not refund_on_failure;
-- TEST service 분석 상태 ready | expect=rows:1
select 1 from @S@.books b join @S@.book_digests d on d.book_id = b.id where b.id = '11111111-0000-4000-8000-000000000001' and b.digest_status = 'ready';
-- TEST service 같은 원고 재분석 22023 | expect=sqlstate:22023
select @S@.start_run((select oa from t_ids), 'digest', '11111111-0000-4000-8000-000000000001', null, null, 20, 'run:trailer:aaaaaaaa-dig-0003', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 종료된 실행 재종료 TR001 | expect=sqlstate:TR001
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-dig-0001'), '{"chapters":[{"n":1}]}'::jsonb);
-- RUN
select @S@.start_run((select oa from t_ids), 'brief', null, '22222222-0000-4000-8000-000000000001', null, 8, 'run:trailer:aaaaaaaa-brf-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 브리프 형식 오류 22023 | expect=sqlstate:22023
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-brf-0001'), '{"brief":{}}'::jsonb);
-- TEST service 브리프 종료(3안, 첫 안이 현재 브리프) | expect=ok
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-brf-0001'), '{"briefs":[{"angle":"question","logline":"약속을 지키려는 마지막 밤","hooks":[{"text":"그날 밤 37도선에서"}]},{"angle":"character","logline":"서연의 선택"},{"angle":"atmosphere","logline":"잠들지 않는 도시"}]}'::jsonb);
-- TEST service 브리프 3안 저장 | expect=rows:1
select 1 from @S@.briefs where trailer_id = '22222222-0000-4000-8000-000000000001' and source = 'ai' having count(*) = 3;
-- TEST service 현재 브리프는 AI 버전 3 | expect=rows:1
select 1 from @S@.trailers t join @S@.briefs b on b.id = t.current_brief_id where t.id = '22222222-0000-4000-8000-000000000001' and b.version = 3 and b.source = 'ai';
-- RUN
select @S@.start_run((select oa from t_ids), 'storyboard', null, '22222222-0000-4000-8000-000000000001', null, 6, 'run:trailer:aaaaaaaa-stb-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 스토리보드에 엔드카드 포함 TR007 | expect=sqlstate:TR007
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-stb-0001'), '{"scenes":[{"kind":"end_card"}]}'::jsonb);
-- TEST service 스토리보드 종료(장면 3 + 엔드카드) | expect=ok
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-stb-0001'), '{"scenes":[{"kind":"title_card","duration_ms":3000,"text":"북위 37도의 약속"},{"kind":"quote_card","duration_ms":4000,"text":"그날 밤, 우리는 약속했다","quote_ref":{"chapter":1,"start":0,"end":12},"quote_verified":true},{"kind":"image_scene","duration_ms":5000,"narration":"도시는 잠들지 않았다","visual":{"prompt":"night city","motion":"ken_burns_in"}}]}'::jsonb);
-- TEST service 엔드카드는 마지막(position 3) | expect=rows:1
select 1 from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'end_card' and position = 3;
-- TEST service 스토리보드 버전 1 | expect=rows:1
select 1 from @S@.trailers where id = '22222222-0000-4000-8000-000000000001' and storyboard_version = 1;
-- RUN
create temp table t_img as select id from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'image_scene';
-- RUN
grant select on t_img to authenticated, service_role;
-- TEST service 에셋 없이 렌더 TR004 | expect=sqlstate:TR004
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '1080p', 6, '66666666-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 엔드카드에는 이미지 생성 불가 22023 | expect=sqlstate:22023
select @S@.start_run((select oa from t_ids), 'scene_image', null, '22222222-0000-4000-8000-000000000001', (select id from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'end_card'), 3, 'run:trailer:aaaaaaaa-img-0000', 'aaaaaaaa-0000-4000-8000-000000000001');
-- RUN
select @S@.start_run((select oa from t_ids), 'scene_image', null, '22222222-0000-4000-8000-000000000001', (select id from t_img), 3, 'run:trailer:aaaaaaaa-img-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 다른 조직 폴더 에셋 경로 23514 | expect=sqlstate:23514
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-img-0001'), jsonb_build_object('storage_path', (select ob from t_ids)::text || '/trailer/assets/' || (select id from t_img)::text || '/99999999-0000-4000-8000-000000000001.png', 'provider', 'fal', 'model', 'flux-pro'));
-- TEST service 이미지 에셋 저장 | expect=ok
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-img-0001'), jsonb_build_object('storage_path', (select oa from t_ids)::text || '/trailer/assets/' || (select id from t_img)::text || '/99999999-0000-4000-8000-000000000001.png', 'provider', 'fal', 'model', 'flux-pro', 'seed', 42, 'width', 1080, 'height', 1920));
-- TEST service 이미지 에셋은 AI 생성 표시 | expect=rows:1
select 1 from @S@.scene_assets where scene_id = (select id from t_img) and status = 'ready' and ai_generated and slot = 'visual';
-- RUN
select @S@.start_run((select oa from t_ids), 'narration', null, '22222222-0000-4000-8000-000000000001', (select id from t_img), 5, 'run:trailer:aaaaaaaa-nar-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 내레이션 저장(목소리 고정) | expect=ok
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-nar-0001'), jsonb_build_object('storage_path', (select oa from t_ids)::text || '/trailer/assets/' || (select id from t_img)::text || '/99999999-0000-4000-8000-000000000002.mp3', 'provider', 'elevenlabs', 'model', 'multilingual_v2', 'voice_id', 'v1', 'duration_ms', 2400, 'chars', 11));
-- TEST service 트레일러 목소리 고정됨 | expect=rows:1
select 1 from @S@.trailers where id = '22222222-0000-4000-8000-000000000001' and voice ->> 'provider' = 'elevenlabs' and voice ->> 'voice_id' = 'v1';
-- RUN
select @S@.start_run((select oa from t_ids), 'narration', null, '22222222-0000-4000-8000-000000000001', (select id from t_img), 5, 'run:trailer:aaaaaaaa-nar-0002', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 다른 목소리 내레이션 거부 22023(같은 목소리 규칙) | expect=sqlstate:22023
select @S@.finish_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-nar-0002'), jsonb_build_object('storage_path', (select oa from t_ids)::text || '/trailer/assets/' || (select id from t_img)::text || '/99999999-0000-4000-8000-000000000003.mp3', 'provider', 'oss-voice', 'model', 'x', 'voice_id', 'v9'));
-- TEST service 실패 기록 | expect=ok
select @S@.fail_run((select id from @S@.generation_runs where idempotency_key = 'run:trailer:aaaaaaaa-nar-0002'), 'voice mismatch');
-- TEST service 내레이션 문장 없는 장면 TR004 | expect=sqlstate:TR004
select @S@.start_run((select oa from t_ids), 'narration', null, '22222222-0000-4000-8000-000000000001', (select id from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'title_card'), 5, 'run:trailer:aaaaaaaa-nar-0003', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 크레딧 부족 CR001 | expect=sqlstate:CR001
select @S@.start_run((select oa from t_ids), 'meta', null, '22222222-0000-4000-8000-000000000001', null, 99999, 'run:trailer:aaaaaaaa-met-0001', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 선택하지 않은 포맷 렌더 22023 | expect=sqlstate:22023
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'landscape_16_9', '1080p', 6, '66666666-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service free 플랜 1080p TR005 | expect=sqlstate:TR005
select @S@.start_render((select ob from t_ids), '22222222-0000-4000-8000-000000000002', 'vertical_9_16', '1080p', 6, '66666666-0000-4000-8000-000000000003', 'bbbbbbbb-0000-4000-8000-000000000002');
-- TEST service 렌더 시작(creator, 1080p) | expect=ok
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '1080p', 6, '66666666-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 워터마크 없음·AI 표시 켬·스냅샷 장면 4개 | expect=rows:1
select 1 from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004' and not watermark and ai_label and plan_code = 'creator' and jsonb_array_length(snapshot -> 'scenes') = 4;
-- TEST service 같은 요청 재호출은 같은 렌더 | expect=rows:1
select 1 from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004' having count(*) = 1;
-- TEST service 다른 폴더 출력 경로 22023 | expect=sqlstate:22023
select @S@.finish_render((select id from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004'), (select oa from t_ids)::text || '/trailer/renders/other/trailer.mp4', null, null, 1000, 16000);
-- TEST service 렌더 종료 | expect=ok
select @S@.finish_render((select id from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004'), (select oa from t_ids)::text || '/trailer/renders/' || (select id from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004')::text || '/trailer.mp4', null, null, 1000, 16000);
-- TEST service 보존 기간 90일(유료) | expect=rows:1
select 1 from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004' and status = 'succeeded' and expires_at > now() + interval '89 days';
-- TEST service 구매 링크 클릭은 URL 반환 | expect=rows:1
select 1 where @S@.record_link_click((select short_code from @S@.purchase_links where id = '44444444-0000-4000-8000-000000000001'), 'https://youtube.com', repeat('c', 64), 'UA', 'render:vertical') like 'https://www.aladin.co.kr/%';
-- TEST service 클릭 수 집계 1 | expect=rows:1
select 1 from @S@.purchase_links where id = '44444444-0000-4000-8000-000000000001' and click_count = 1;
-- TEST service 없는 코드 클릭은 null | expect=rows:1
select 1 where @S@.record_link_click('zzzzzzzzzz') is null;
-- TEST service creator 플랜 승인 링크 TR005 | expect=sqlstate:TR005
select @S@.open_review((select oa from t_ids), '22222222-0000-4000-8000-000000000001', array[(select id from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004')], repeat('d', 64), '편집자', 'aaaaaaaa-0000-4000-8000-000000000001');
-- RUN
update @C@.app_entitlements set plan_id = (select id from @C@.plans where app_id = 'trailer' and code = 'publisher') where org_id = (select oa from t_ids) and app_id = 'trailer';
-- TEST service publisher 플랜 승인 링크 | expect=ok
select @S@.open_review((select oa from t_ids), '22222222-0000-4000-8000-000000000001', array[(select id from @S@.renders where request_id = '66666666-0000-4000-8000-000000000004')], repeat('d', 64), '편집자', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 잘못된 토큰 결정 TR009 | expect=sqlstate:TR009
select @S@.decide_review(repeat('e', 64), 'approved');
-- TEST service 승인 결정 | expect=ok
select @S@.decide_review(repeat('d', 64), 'approved', '좋습니다');
-- TEST service 승인되면 트레일러 approved | expect=rows:1
select 1 from @S@.trailers where id = '22222222-0000-4000-8000-000000000001' and status = 'approved';
-- TEST service 결정된 링크 재사용 TR009 | expect=sqlstate:TR009
select @S@.decide_review(repeat('d', 64), 'changes_requested');
-- TEST service FLORA 없는 배포에서 가져오기 TR010 | expect=sqlstate:TR010
select @S@.import_flora_book((select oa from t_ids), gen_random_uuid(), 'aaaaaaaa-0000-4000-8000-000000000001');

-- AS A
-- TEST A 승인 토큰 해시 조회 42501(컬럼 GRANT 없음) | expect=sqlstate:42501
select token_sha256 from @S@.reviews;
-- TEST A 승인 링크 상태 조회 | expect=rows:1
select 1 from @S@.reviews where status = 'approved';
-- TEST A 렌더 직접 INSERT 42501 | expect=sqlstate:42501
insert into @S@.renders (org_id, trailer_id, format, resolution, plan_code, watermark, ai_label, snapshot, request_id) select oa, '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '1080p', 'publisher', false, false, '{}'::jsonb, gen_random_uuid() from t_ids;
-- TEST A 렌더 워터마크 끄기 42501 | expect=sqlstate:42501
update @S@.renders set watermark = false;
-- TEST A 인용 문장 수정 시 검증 해제 | expect=rows:1
update @S@.scenes set text = '내가 고친 문장' where trailer_id = '22222222-0000-4000-8000-000000000001' and kind = 'quote_card' returning case when not quote_verified then 1 end;
-- TEST A 클릭 기록 조회 | expect=rows:1
select 1 from @S@.link_clicks where org_id = (select oa from t_ids);

-- AS service
-- RUN
select @C@.grant_credits((select oa from t_ids), 100, 'trailer', 'test topup', 'pack');
-- TEST service 검증되지 않은 인용 렌더 TR006 | expect=sqlstate:TR006
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '1080p', 6, '66666666-0000-4000-8000-000000000005', 'aaaaaaaa-0000-4000-8000-000000000001');
-- TEST service 사용자가 직접 쓴 문장임을 확인하면 렌더 가능 | expect=ok
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '1080p', 6, '66666666-0000-4000-8000-000000000006', 'aaaaaaaa-0000-4000-8000-000000000001', true);
-- TEST service 동시 렌더 한도 TR005(진행 중 1 + 새 2번째는 허용, 3번째 거부) | expect=ok
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '720p', 4, '66666666-0000-4000-8000-000000000007', 'aaaaaaaa-0000-4000-8000-000000000001', true);
-- TEST service 동시 렌더 3번째 TR005 | expect=sqlstate:TR005
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '720p', 4, '66666666-0000-4000-8000-000000000008', 'aaaaaaaa-0000-4000-8000-000000000001', true);
-- TEST service 잡 취소 뒤 정리하면 렌더 canceled | expect=ok
select @C@.cancel_job((select job_id from @S@.renders where request_id = '66666666-0000-4000-8000-000000000007'));
-- TEST service 정리 후 다시 렌더 가능 | expect=ok
select @S@.start_render((select oa from t_ids), '22222222-0000-4000-8000-000000000001', 'vertical_9_16', '720p', 4, '66666666-0000-4000-8000-000000000009', 'aaaaaaaa-0000-4000-8000-000000000001', true);
-- TEST service 취소된 렌더는 canceled | expect=rows:1
select 1 from @S@.renders where request_id = '66666666-0000-4000-8000-000000000007' and status = 'canceled';

-- AS A
-- TEST A 트레일러 삭제(엔드카드도 함께 지워짐) | expect=ok
delete from @S@.trailers where id = '22222222-0000-4000-8000-000000000001';
-- TEST A 삭제 후 장면 0행 | expect=rows:0
select 1 from @S@.scenes where trailer_id = '22222222-0000-4000-8000-000000000001';
