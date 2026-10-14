-- =====================================================================
-- rls_smoke.sql : local-news RLS·권한·워크플로 회귀 테스트 (DB_CONVENTIONS 13.3, SECURITY_BASELINE 15장)
-- 실행: node products/local-news/supabase/monolith/tests/run-smoke.mjs --target mono   (@C@ = public, @N@ = public)
--       node products/local-news/supabase/monolith/tests/run-smoke.mjs --target mod    (@C@ = core,   @N@ = news)
-- 형식: "-- AS <행위자>", "-- RUN"(준비 문장), "-- TEST <이름> | expect=<rows:N | ok | sqlstate:CODE>"
-- 행위자(05_DATA_MODEL.md 10절 페르소나):
--   A 신문(김해타임즈, news_pro): P 발행인, E 편집인, D 데스크, R 기자, K 기고자, M 광고담당 / U 독자, W 유료 멤버 독자
--   B 신문(부산주간, news_trial): X 발행인(outsider), V 독자(reader_other), Y1~Y3 한도 시험 사용자
--   C 신문(대구뉴스, news_trial, 매체정보 미완성): N 발행인 / O 플랫폼 운영자 / Z 시험 중 초대 사용자 / anon 비로그인
-- 위험 #1~#10(05장 7절)의 차단을 각 절에서 검사한다.
-- =====================================================================

-- SETUP (관리 세션: JWT 없음 = core.is_service_caller() 참. 신청·수락은 sub 클레임만 바꿔 본인으로 호출)
insert into auth.users (id, email, raw_user_meta_data) values
  ('10000000-0000-4000-8000-000000000001', 'p@a.test',  '{"full_name": "홍발행"}'),
  ('10000000-0000-4000-8000-000000000002', 'e@a.test',  '{"full_name": "김편집"}'),
  ('10000000-0000-4000-8000-000000000003', 'd@a.test',  '{"full_name": "박데스크"}'),
  ('10000000-0000-4000-8000-000000000004', 'r@a.test',  '{"full_name": "최기자"}'),
  ('10000000-0000-4000-8000-000000000005', 'k@a.test',  '{"full_name": "정통신원"}'),
  ('10000000-0000-4000-8000-000000000006', 'm@a.test',  '{"full_name": "한광고"}'),
  ('10000000-0000-4000-8000-000000000007', 'z@a.test',  '{"full_name": "윤신입"}'),
  ('10000000-0000-4000-8000-000000000008', 'x@b.test',  '{"full_name": "부발행"}'),
  ('10000000-0000-4000-8000-000000000009', 'u@r.test',  '{"full_name": "독자U"}'),
  ('10000000-0000-4000-8000-000000000010', 'w@r.test',  '{"full_name": "독자W"}'),
  ('10000000-0000-4000-8000-000000000011', 'v@r.test',  '{"full_name": "독자V"}'),
  ('10000000-0000-4000-8000-000000000012', 'n@c.test',  '{"full_name": "대발행"}'),
  ('10000000-0000-4000-8000-000000000013', 'o@ops.test', '{"full_name": "운영자"}'),
  ('10000000-0000-4000-8000-000000000014', 'y1@b.test', '{"full_name": "Y1"}'),
  ('10000000-0000-4000-8000-000000000015', 'y2@b.test', '{"full_name": "Y2"}'),
  ('10000000-0000-4000-8000-000000000016', 'y3@b.test', '{"full_name": "Y3"}');
update @C@.profiles set platform_role = 'platform_admin' where id = '10000000-0000-4000-8000-000000000013';
-- Supabase 가 storage.objects 에 주는 기본 테이블 권한을 흉내 낸다(정책은 코어·제품 SQL 이 만든다)
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.objects to anon;

create temp table t_ref (k text primary key, v uuid);
create temp table t_art (slug text primary key, id uuid not null);
create temp table t_tok (k text primary key, v text);
grant select on t_ref, t_art, t_tok to anon, authenticated, service_role;
grant insert, update on t_ref, t_art, t_tok to service_role;
create function pg_temp.ref(p text) returns uuid language sql stable as $$ select v from t_ref where k = p $$;
create function pg_temp.art(p text) returns uuid language sql stable as $$ select id from t_art where slug = p $$;
create function pg_temp.tok(p text) returns text language sql stable as $$ select v from t_tok where k = p $$;

-- 개설 신청(본인) → 운영자 승인(서버). A 는 프로, B·C 는 체험
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
select @N@.request_newspaper('gimhae-times', '김해타임즈', 'internet', '경남 아00001', '2020-01-01', '홍발행', 'pub@a.test', '055-000-0001',
  (select id from @C@.organizations where owner_id = '10000000-0000-4000-8000-000000000001' and is_personal)::text || '/news/applications/cert.pdf');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000008', false);
select @N@.request_newspaper('busan-weekly', '부산주간', 'weekly', '부산 다00002', '2019-05-01', '부발행', 'pub@b.test', '051-000-0002',
  (select id from @C@.organizations where owner_id = '10000000-0000-4000-8000-000000000008' and is_personal)::text || '/news/applications/cert.pdf');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000012', false);
select @N@.request_newspaper('daegu-news', '대구뉴스', 'internet', '대구 아00003', '2021-03-01', '대발행', 'pub@c.test', '053-000-0003',
  (select id from @C@.organizations where owner_id = '10000000-0000-4000-8000-000000000012' and is_personal)::text || '/news/applications/cert.pdf');
select set_config('request.jwt.claim.sub', '', false);
select @N@.approve_newspaper((select id from @N@.newspaper_applications where slug = 'gimhae-times'), 'news_pro', '등록증 확인');
select @N@.approve_newspaper((select id from @N@.newspaper_applications where slug = 'busan-weekly'));
select @N@.approve_newspaper((select id from @N@.newspaper_applications where slug = 'daegu-news'));
insert into t_ref select 'oa', org_id from @N@.newspapers where title = '김해타임즈';
insert into t_ref select 'ob', org_id from @N@.newspapers where title = '부산주간';
insert into t_ref select 'oc', org_id from @N@.newspapers where title = '대구뉴스';

-- 매체정보: A, B 완성. C 는 미완성(위험 #5)
select @N@.set_newspaper_profile(pg_temp.ref('oa'), '{"legal_name": "(주)김해타임즈", "editor_name": "김편집", "youth_officer_name": "이청소", "publish_address": "경남 김해시 가야로 1", "phone": "055-000-0001", "first_published_on": "2020-02-01", "comments_enabled": true, "banned_words": ["바보"]}');
select @N@.set_newspaper_profile(pg_temp.ref('ob'), '{"legal_name": "부산주간", "editor_name": "부편집", "youth_officer_name": "부청소", "publish_address": "부산시 중구 중앙대로 1", "phone": "051-000-0002", "first_published_on": "2019-06-01"}');

-- A 편집국 초대(서버) → 본인 수락
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000002', 'editor', '김편집');
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000003', 'desk', '박데스크');
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000004', 'reporter', '최기자');
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000005', 'contributor', '정통신원');
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000006', 'ad_manager', '한광고');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
select @N@.accept_staff_invite(pg_temp.ref('oa'));
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', false);
select @N@.accept_staff_invite(pg_temp.ref('oa'));
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', false);
select @N@.accept_staff_invite(pg_temp.ref('oa'));
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', false);
select @N@.accept_staff_invite(pg_temp.ref('oa'));
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000006', false);
select @N@.accept_staff_invite(pg_temp.ref('oa'));

-- 독자 가입(본인): U, W 는 A, V 는 B
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000009', false);
select @N@.ensure_reader(pg_temp.ref('oa'), '독자유', 'v1', 'v1', true, false);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000010', false);
select @N@.ensure_reader(pg_temp.ref('oa'), '독자더블', 'v1', 'v1', true, true);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000011', false);
select @N@.ensure_reader(pg_temp.ref('ob'), '부산독자', 'v1', 'v1', true, false);
select set_config('request.jwt.claim.sub', '', false);
insert into t_ref select 'reader_u', id from @N@.readers where user_id = '10000000-0000-4000-8000-000000000009';
insert into t_ref select 'reader_w', id from @N@.readers where user_id = '10000000-0000-4000-8000-000000000010';

-- 분류·계약·미디어·광고·뉴스레터·멤버십 기본 행(서버)
insert into t_ref values ('sec_a', @N@.upsert_taxonomy(pg_temp.ref('oa'), 'section', null, '{"slug": "local", "name": "지역"}'));
insert into t_ref values ('sec_b', @N@.upsert_taxonomy(pg_temp.ref('ob'), 'section', null, '{"slug": "local", "name": "지역"}'));
insert into t_ref values ('tag_a', @N@.upsert_taxonomy(pg_temp.ref('oa'), 'tag', null, '{"slug": "가야", "name": "가야"}'));
insert into t_ref values ('reg_a', @N@.upsert_taxonomy(pg_temp.ref('oa'), 'region', null, '{"slug": "gimhae", "name": "김해시"}'));
insert into t_ref select 'wire_ok', id from @N@.upsert_wire_contract(pg_temp.ref('oa'), null, '{"provider": "yonhap", "name": "연합 전재", "starts_on": "2020-01-01", "attribution_text": "연합뉴스"}');
insert into t_ref select 'wire_old', id from @N@.upsert_wire_contract(pg_temp.ref('oa'), null, '{"provider": "newsis", "name": "뉴시스 만료", "starts_on": "2020-01-01", "ends_on": "2021-01-01", "attribution_text": "뉴시스"}');
insert into t_ref select 'media_a', id from @N@.save_media_asset(pg_temp.ref('oa'), null,
  jsonb_build_object('storage_path', pg_temp.ref('oa')::text || '/news/media/p.jpg', 'mime', 'image/jpeg', 'alt_text', '가야 축제 개막식', 'credit', '김해타임즈'));
insert into t_ref select 'slot_a', id from @N@.upsert_ad_slot(pg_temp.ref('oa'), null, '{"code": "home_top", "name": "홈 상단", "placement": "home", "width": 728, "height": 90}');
insert into t_ref select 'adv_local', id from @N@.upsert_advertiser(pg_temp.ref('oa'), null, '{"name": "가야식당", "kind": "local_business"}');
insert into t_ref select 'adv_gov', id from @N@.upsert_advertiser(pg_temp.ref('oa'), null, '{"name": "김해시청", "kind": "institution", "is_government": true}');
insert into t_ref select 'list_morning', id from @N@.upsert_newsletter_list(pg_temp.ref('oa'), null, '{"slug": "morning", "name": "아침 브리핑", "kind": "morning_brief"}');
insert into t_ref select 'list_promo', id from @N@.upsert_newsletter_list(pg_temp.ref('oa'), null, '{"slug": "promo", "name": "지역 할인 소식", "contains_ads": true}');
insert into t_ref select 'tier_a', id from @N@.upsert_membership_tier(pg_temp.ref('oa'), null, '{"code": "basic", "name": "후원회원", "price_krw": 10000}');
insert into storage.objects (bucket_id, name) values
  ('org-files', (select v from t_ref where k = 'oa')::text || '/news/tips/a.jpg'),
  ('org-files', (select v from t_ref where k = 'oa')::text || '/news/media/raw.jpg');
-- END SETUP

-- =====================================================================
-- 1. 개설·프로비저닝 (NW-F-001)
-- =====================================================================
-- AS service
-- TEST 신문사 3곳과 조직(is_personal=false) | expect=rows:3
select 1 from @N@.newspapers n join @C@.organizations o on o.id = n.org_id where not o.is_personal;
-- TEST A 발행인 = 조직 owner = staff publisher | expect=rows:1
select 1 from @N@.staff s join @C@.org_members m on m.org_id = s.org_id and m.user_id = s.user_id
 where s.org_id = pg_temp.ref('oa') and s.role = 'publisher' and m.role = 'owner' and s.status = 'active';
-- TEST B 체험 엔타이틀먼트 30일 만료·trial | expect=rows:1
select 1 from @C@.app_entitlements where org_id = pg_temp.ref('ob') and app_id = 'news' and source = 'trial'
   and expires_at between now() + interval '29 days' and now() + interval '31 days';
-- TEST B 체험 구독 trialing | expect=rows:1
select 1 from @C@.subscriptions where org_id = pg_temp.ref('ob') and app_id = 'news' and status = 'trialing';
-- TEST A 프로 월 크레딧 4000 지급 | expect=rows:1
select 1 from @C@.credit_ledger where org_id = pg_temp.ref('oa') and entry_type = 'grant' and amount = 4000;
-- TEST 기본 배포 설정·페이월 행 생성 | expect=rows:3
select 1 from @N@.syndication_settings s join @N@.paywall_rules p on p.org_id = s.org_id;
-- TEST 독자 가입은 조직 멤버를 만들지 않는다 | expect=rows:0
select 1 from @C@.org_members where user_id in ('10000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000010') and org_id = pg_temp.ref('oa');

-- AS U
-- TEST U 기존 슬러그로 신청 NW001 | expect=sqlstate:NW001
select @N@.request_newspaper('gimhae-times', '김해새신문', 'internet', '경남 아00009', '2024-01-01', '독자유', 'u@r.test', '010-0000-0009',
  (select id from @C@.organizations where owner_id = auth.uid() and is_personal)::text || '/news/applications/c.pdf');
-- TEST U 예약어 슬러그 NW001 | expect=sqlstate:NW001
select @N@.request_newspaper('newsroom', '뉴스룸', 'internet', '경남 아00009', '2024-01-01', '독자유', 'u@r.test', '010-0000-0009',
  (select id from @C@.organizations where owner_id = auth.uid() and is_personal)::text || '/news/applications/c.pdf');
-- TEST U 남의 개인 조직 경로로 등록증 23514 | expect=sqlstate:23514
select @N@.request_newspaper('u-paper', '유신문', 'internet', '경남 아00009', '2024-01-01', '독자유', 'u@r.test', '010-0000-0009',
  '00000000-0000-4000-8000-000000000000/news/applications/c.pdf');
-- TEST U 정상 신청 | expect=ok
select @N@.request_newspaper('u-paper', '유신문', 'internet', '경남 아00009', '2024-01-01', '독자유', 'u@r.test', '010-0000-0009',
  (select id from @C@.organizations where owner_id = auth.uid() and is_personal)::text || '/news/applications/c.pdf');
-- TEST U 진행 중 신청이 있으면 NW001 | expect=sqlstate:NW001
select @N@.request_newspaper('u-paper2', '유신문2', 'internet', '경남 아00009', '2024-01-01', '독자유', 'u@r.test', '010-0000-0009',
  (select id from @C@.organizations where owner_id = auth.uid() and is_personal)::text || '/news/applications/c.pdf');
-- TEST U 자기 신청만 보인다 | expect=rows:1
select 1 from @N@.newspaper_applications;
-- TEST U 승인 RPC 42501 | expect=sqlstate:42501
select @N@.approve_newspaper((select id from @N@.newspaper_applications where slug = 'u-paper'));
-- TEST U 신청 철회 | expect=ok
select @N@.withdraw_newspaper_request((select id from @N@.newspaper_applications where slug = 'u-paper'));
-- TEST U 신청 테이블 직접 UPDATE 42501 | expect=sqlstate:42501
update @N@.newspaper_applications set status = 'approved';

-- AS O
-- TEST 운영자 개설 신청 전체 조회 | expect=rows:4
select 1 from @N@.newspaper_applications;
-- TEST 운영자도 편집국 기사는 0행(편집국 아님) | expect=rows:0
select 1 from @N@.articles;

-- AS P
-- TEST P 는 U 신청을 못 본다 | expect=rows:0
select 1 from @N@.newspaper_applications where slug = 'u-paper';
-- TEST 코어 함수 권한 보존: 발행인 session_context(신문 조직) = news_pro | expect=rows:1
select 1 where @C@.session_context('news', pg_temp.ref('oa')) ->> 'plan_code' = 'news_pro';
-- AS U
-- TEST 독자 session_context: 신문 엔타이틀먼트 없음(독자는 엔타이틀먼트가 필요 없다) | expect=rows:1
select 1 where (@C@.session_context('news') ->> 'entitled')::boolean = false;

-- =====================================================================
-- 2. 편집국 구성원과 역할 (NW-F-004)
-- =====================================================================
-- AS D
-- TEST 데스크는 초대 불가 42501 | expect=sqlstate:42501
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000007', 'reporter', '윤신입');
-- AS E
-- TEST 편집인은 편집인을 초대할 수 없다 42501 | expect=sqlstate:42501
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000007', 'editor', '윤신입');
-- TEST 편집인이 기자 초대 | expect=ok
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000007', 'reporter', '윤신입');
-- TEST 이미 초대된 사람 재초대 NW004 | expect=sqlstate:NW004
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000007', 'reporter', '윤신입');
-- AS Z
-- TEST 수락 전 Z 는 A 기사 0행(staff invited) | expect=rows:0
select 1 from @N@.newspapers where org_id = pg_temp.ref('oa');
-- TEST Z 초대 수락 | expect=ok
select @N@.accept_staff_invite(pg_temp.ref('oa'));
-- TEST 수락 후 Z 는 A 매체정보를 본다 | expect=rows:1
select 1 from @N@.newspapers where org_id = pg_temp.ref('oa');
-- TEST Z 자기 역할 변경 42501 | expect=sqlstate:42501
select @N@.set_staff_role(pg_temp.ref('oa'), auth.uid(), 'editor');
-- AS E
-- TEST 편집인이 발행인 역할 변경 42501 | expect=sqlstate:42501
select @N@.set_staff_role(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000001', 'desk');
-- AS P
-- TEST 발행인이 Z 를 편집인으로(코어 admin 동기화) | expect=ok
select @N@.set_staff_role(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000007', 'editor');
-- TEST Z 코어 역할 admin | expect=rows:1
select 1 from @C@.org_members where org_id = pg_temp.ref('oa') and user_id = '10000000-0000-4000-8000-000000000007' and role = 'admin';
-- TEST 발행인이 Z 제거 | expect=ok
select @N@.remove_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000007');
-- TEST 발행인 제거 불가 42501 | expect=sqlstate:42501
select @N@.remove_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000001');
-- AS Z
-- TEST 제거된 Z 는 A 데이터 0행 | expect=rows:0
select 1 from @N@.newspapers where org_id = pg_temp.ref('oa');
-- TEST staff 직접 INSERT 42501 | expect=sqlstate:42501
insert into @N@.staff (org_id, user_id, role, status, byline_name) values (pg_temp.ref('oa'), auth.uid(), 'publisher', 'active', 'x');
-- AS X
-- TEST B 발행인이 A 에 초대 42501 | expect=sqlstate:42501
select @N@.invite_staff(pg_temp.ref('oa'), '10000000-0000-4000-8000-000000000014', 'reporter', 'Y1');
-- TEST B 발행인은 A 편집국 0행 | expect=rows:0
select 1 from @N@.staff where org_id = pg_temp.ref('oa');
-- TEST B 기자 초대 1 | expect=ok
select @N@.invite_staff(pg_temp.ref('ob'), '10000000-0000-4000-8000-000000000014', 'reporter', 'Y1');
-- TEST B 기자 초대 2 | expect=ok
select @N@.invite_staff(pg_temp.ref('ob'), '10000000-0000-4000-8000-000000000015', 'reporter', 'Y2');
-- TEST 체험 플랜 기자 3명 한도 NW014 | expect=sqlstate:NW014
select @N@.invite_staff(pg_temp.ref('ob'), '10000000-0000-4000-8000-000000000016', 'reporter', 'Y3');

-- =====================================================================
-- 3. 기사 작성과 유형 규칙 (NW-F-010, 011, 032, 050)
-- =====================================================================
-- AS R
-- TEST 기자 초안 작성(섹션·태그·지역·사진) | expect=ok
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'a-pub', 'title', '김해 가야 축제 개막', 'summary', '가야 축제가 열렸다',
  'body', '[{"type": "p", "text": "김해시 가야 축제가 개막했다."}]'::jsonb, 'body_text', '김해시 가야 축제가 개막했다',
  'section_id', pg_temp.ref('sec_a'), 'tag_ids', jsonb_build_array(pg_temp.ref('tag_a')), 'region_ids', jsonb_build_array(pg_temp.ref('reg_a')),
  'hero_media_id', pg_temp.ref('media_a'), 'media_ids', jsonb_build_array(pg_temp.ref('media_a'))));
-- TEST 다른 신문 섹션 참조 23503 (위험 #1) | expect=sqlstate:23503
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'x-cross', 'title', '교차', 'section_id', pg_temp.ref('sec_b')));
-- TEST 기사형 광고 라벨 없음 23514 (위험 #4) | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "ad-nolabel", "title": "맛집 소개", "type": "sponsored"}');
-- TEST 허용 밖 라벨 23514 | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "ad-badlabel", "title": "맛집 소개", "type": "sponsored", "sponsor_label": "홍보"}');
-- TEST 일반 기사에 광고 라벨 23514 | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "ad-mixed", "title": "일반", "sponsor_label": "광고"}');
-- TEST 기사형 광고(라벨 기사형 광고) | expect=ok
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "sp-1", "title": "가야식당 신메뉴", "type": "sponsored", "sponsor_label": "기사형 광고"}');
-- TEST AI 보조인데 고지 없음 23514 | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "ai-nodisc", "title": "요약", "ai_assisted": true}');
-- TEST 기자가 origin 지정 42501 | expect=sqlstate:42501
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "ai-fake", "title": "x", "type": "press_release", "origin": "ai_press_release", "ai_assisted": true, "ai_disclosure": "AI 초안을 바탕으로 작성"}');
-- TEST 허용 밖 필드(status) NW015 | expect=sqlstate:NW015
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "st", "title": "x", "status": "published"}');
-- TEST 여론조사 표시 없음 23514 | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "poll-bad", "title": "지지율", "is_poll": true}');
-- TEST 기사 직접 INSERT 42501 | expect=sqlstate:42501
insert into @N@.articles (org_id, slug, title, byline) values (pg_temp.ref('oa'), 'raw', 'raw', 'x');
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'a-embargo', 'title', '엠바고 기사', 'embargo_until', now() + interval '1 day'));
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "a-sched", "title": "예약 기사"}');
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "a-svc", "title": "서버 게시 시험"}');
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'w-old', 'title', '만료 계약 전재', 'type', 'wire', 'wire_contract_id', pg_temp.ref('wire_old')));
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'w-ok', 'title', '유효 계약 전재', 'type', 'wire', 'wire_contract_id', pg_temp.ref('wire_ok')));
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "poll-1", "title": "시장 지지율 조사", "is_poll": true, "poll_disclosure": "조사기관 가야리서치, 표본 1000명, 오차 ±3.1%p"}');
-- RUN
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "prem-1", "title": "프리미엄 심층", "is_premium": true, "body": [{"type": "p", "text": "유료 본문"}]}');
-- AS K
-- TEST 기고자 초안(유형은 contribution 으로 고정) | expect=ok
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "k-draft", "title": "기고문", "type": "original"}');
-- TEST 기고자 기사 유형 contribution | expect=rows:1
select 1 from @N@.articles where slug = 'k-draft' and type = 'contribution';
-- TEST 기고자는 남의 기사 0행 | expect=rows:0
select 1 from @N@.articles where slug = 'a-pub';
-- AS service
-- TEST AI 초안을 자체기사(original)로 23514 (위험 #9) | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'ai-orig', 'title', '시청 보도자료', 'type', 'original', 'origin', 'ai_press_release',
  'ai_assisted', true, 'ai_disclosure', 'AI가 보도자료를 바탕으로 초안을 작성했습니다', 'author_id', '10000000-0000-4000-8000-000000000004'));
-- TEST 보도자료 AI 초안(서버) | expect=ok
select @N@.save_article(pg_temp.ref('oa'), null, jsonb_build_object('slug', 'ai-1', 'title', '시청 보도자료 기사', 'type', 'press_release', 'origin', 'ai_press_release',
  'ai_assisted', true, 'ai_disclosure', 'AI가 보도자료를 바탕으로 초안을 작성했습니다', 'author_id', '10000000-0000-4000-8000-000000000004'));
-- RUN
insert into t_art select slug, id from @N@.articles on conflict (slug) do nothing;

-- =====================================================================
-- 4. 워크플로: 기고자 직접 게시 차단, 데스크 승인, 사람 승인 (위험 #3, #9)
-- =====================================================================
-- AS K
-- TEST 기고자가 남의 기사 수정 42501 | expect=sqlstate:42501
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"title": "변조"}');
-- TEST 기고자 자기 초안 제출 | expect=ok
select @N@.submit_article(pg_temp.art('k-draft'));
-- TEST 기고자 승인 42501 (위험 #3) | expect=sqlstate:42501
select @N@.review_article(pg_temp.art('k-draft'), 'approve');
-- TEST 기고자 게시 42501 (위험 #3) | expect=sqlstate:42501
select @N@.publish_article(pg_temp.art('k-draft'));
-- TEST 기고자 예약 42501 | expect=sqlstate:42501
select @N@.schedule_article(pg_temp.art('k-draft'), now() + interval '1 hour');
-- TEST 기고자 기사 상태 직접 UPDATE 42501 | expect=sqlstate:42501
update @N@.articles set status = 'published' where slug = 'k-draft';
-- AS R
-- TEST 기자 제출 | expect=ok
select @N@.submit_article(pg_temp.art('a-pub'));
-- TEST 기자 승인 42501 | expect=sqlstate:42501
select @N@.review_article(pg_temp.art('a-pub'), 'approve');
-- TEST 제출된 기사 다시 제출 NW004 | expect=sqlstate:NW004
select @N@.submit_article(pg_temp.art('a-pub'));
-- RUN
select @N@.submit_article(pg_temp.art('a-embargo'));
-- RUN
select @N@.submit_article(pg_temp.art('a-sched'));
-- RUN
select @N@.submit_article(pg_temp.art('a-svc'));
-- RUN
select @N@.submit_article(pg_temp.art('w-old'));
-- RUN
select @N@.submit_article(pg_temp.art('w-ok'));
-- RUN
select @N@.submit_article(pg_temp.art('poll-1'));
-- RUN
select @N@.submit_article(pg_temp.art('prem-1'));
-- RUN
select @N@.submit_article(pg_temp.art('sp-1'));
-- AS service
-- RUN
select @N@.submit_article(pg_temp.art('ai-1'));
-- TEST 서버(AI)가 승인 NW006 (위험 #9) | expect=sqlstate:NW006
select @N@.review_article(pg_temp.art('ai-1'), 'approve');
-- AS D
-- TEST 데스크 반려 사유 없음 NW015 | expect=sqlstate:NW015
select @N@.review_article(pg_temp.art('k-draft'), 'reject');
-- TEST 데스크 반려 | expect=ok
select @N@.review_article(pg_temp.art('k-draft'), 'reject', '사실 확인 자료를 붙여 주세요');
-- TEST 데스크 승인 | expect=ok
select @N@.review_article(pg_temp.art('a-pub'), 'approve');
-- TEST 승인자 기록(사람) | expect=rows:1
select 1 from @N@.articles where slug = 'a-pub' and status = 'approved' and approved_by = auth.uid();
-- TEST 승인된 기사 재승인 NW004 | expect=sqlstate:NW004
select @N@.review_article(pg_temp.art('a-pub'), 'approve');
-- TEST AI 초안 반려(사람 검수) | expect=ok
select @N@.review_article(pg_temp.art('ai-1'), 'reject', '수치 출처 확인');
-- RUN
select @N@.review_article(pg_temp.art('a-embargo'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('a-sched'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('a-svc'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('w-old'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('w-ok'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('poll-1'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('prem-1'), 'approve');
-- RUN
select @N@.review_article(pg_temp.art('sp-1'), 'approve');
-- AS R
-- TEST 기자는 승인된 기사 수정 불가 NW004 | expect=sqlstate:NW004
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"title": "몰래 수정"}');
-- TEST AI 초안 유형을 자체기사로 변경 23514 (위험 #9) | expect=sqlstate:23514
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('ai-1'), '{"type": "original"}');
-- TEST AI 초안 origin 변경 22023 | expect=sqlstate:22023
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('ai-1'), '{"origin": "human"}');
-- TEST 반려된 AI 초안 사람 수정 | expect=ok
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('ai-1'), '{"title": "시청, 가야 축제 예산 증액", "source_note": "김해시청 보도자료"}');
-- RUN
select @N@.submit_article(pg_temp.art('ai-1'));
-- AS D
-- RUN
select @N@.review_article(pg_temp.art('ai-1'), 'approve', '수치 확인 완료');

-- =====================================================================
-- 5. 게시 요건: 매체정보, 전재 계약, 선거, 서버 게시 제한 (위험 #5, #3)
-- =====================================================================
-- AS D
-- TEST 데스크 게시 | expect=ok
select @N@.publish_article(pg_temp.art('a-pub'));
-- TEST 게시 시각·최초 게시 시각 | expect=rows:1
select 1 from @N@.articles where slug = 'a-pub' and status = 'published' and published_at <= now() and first_published_at = published_at;
-- TEST 사진이 공개 표시됨(published_at) | expect=rows:1
select 1 from @N@.media_assets where id = pg_temp.ref('media_a') and published_at is not null;
-- TEST 만료된 전재 계약 NW005 | expect=sqlstate:NW005
select @N@.publish_article(pg_temp.art('w-old'));
-- TEST 유효 전재 계약 게시 | expect=ok
select @N@.publish_article(pg_temp.art('w-ok'));
-- TEST AI 보도자료 기사 게시(사람 승인 후) | expect=ok
select @N@.publish_article(pg_temp.art('ai-1'));
-- TEST 엠바고 기사 게시 | expect=ok
select @N@.publish_article(pg_temp.art('a-embargo'));
-- TEST 프리미엄 기사 게시 | expect=ok
select @N@.publish_article(pg_temp.art('prem-1'));
-- TEST 기사형 광고 게시 | expect=ok
select @N@.publish_article(pg_temp.art('sp-1'));
-- TEST 예약 시각이 과거 NW015 | expect=sqlstate:NW015
select @N@.schedule_article(pg_temp.art('a-sched'), now() - interval '1 hour');
-- TEST 예약 | expect=ok
select @N@.schedule_article(pg_temp.art('a-sched'), now() + interval '1 hour');
-- TEST 게시 후 수정 사유 없음 NW015 | expect=sqlstate:NW015
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"title": "김해 가야 축제 개막(수정)"}');
-- TEST 게시 후 수정(공개 수정 사유) | expect=ok
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"title": "김해 가야 축제 개막(수정)", "change_note": "행사 일정 오기 수정"}');
-- TEST 수정 표시 기록 | expect=rows:1
select 1 from @N@.articles where slug = 'a-pub' and revision_count = 1 and revision_note = '행사 일정 오기 수정' and revised_at is not null;
-- AS P
-- RUN
select @N@.upsert_election_period(pg_temp.ref('oa'), null, jsonb_build_object('name', '보궐선거', 'election_day', (now() + interval '2 days')::date,
  'poll_blackout_from', now() - interval '1 day', 'poll_blackout_until', now() + interval '2 days'));
-- AS D
-- TEST 여론조사 공표 금지 기간 게시 NW007 | expect=sqlstate:NW007
select @N@.publish_article(pg_temp.art('poll-1'));
-- AS service
-- TEST 서버는 승인 기사를 바로 게시할 수 없다 42501 | expect=sqlstate:42501
select @N@.publish_article(pg_temp.art('a-svc'));
-- TEST 예약 실행(아직 시각 전) 0건 | expect=rows:1
select 1 where (@N@.run_scheduled_publishing() ->> 'published')::int = 0;
-- RUN
update @N@.articles set scheduled_for = now() - interval '1 minute' where slug = 'a-sched';
-- TEST 예약 실행 1건 게시 | expect=rows:1
select 1 where (@N@.run_scheduled_publishing() ->> 'published')::int = 1;
-- TEST 예약 기사 published_at = 예약 시각 | expect=rows:1
select 1 from @N@.articles where slug = 'a-sched' and status = 'published' and published_at = scheduled_for;
-- TEST 서버도 상태 전이 위반 22023 | expect=sqlstate:22023
update @N@.articles set status = 'draft' where slug = 'a-pub';
-- TEST 최초 게시 시각 변경 22023 | expect=sqlstate:22023
update @N@.articles set first_published_at = now() - interval '30 days' where slug = 'a-pub';

-- C: 매체정보 미완성 신문은 게시도 공개도 안 된다(위험 #5)
-- AS N
-- RUN
select @N@.save_article(pg_temp.ref('oc'), null, '{"slug": "c-1", "title": "대구 소식"}');
-- AS service
-- RUN
insert into t_art select slug, id from @N@.articles on conflict (slug) do nothing;
-- AS N
-- RUN
select @N@.submit_article(pg_temp.art('c-1'));
-- RUN
select @N@.review_article(pg_temp.art('c-1'), 'approve');
-- TEST 매체정보 미완성 게시 NW003 (위험 #5) | expect=sqlstate:NW003
select @N@.publish_article(pg_temp.art('c-1'));
-- TEST C 매체정보 미완성 | expect=rows:1
select 1 where not @N@.is_profile_complete(pg_temp.ref('oc'));
-- TEST C 지면 PDF(체험 플랜) NW014 | expect=sqlstate:NW014
select @N@.save_print_edition(pg_temp.ref('oc'), null, jsonb_build_object('edition_date', '2026-10-15', 'pdf_path', pg_temp.ref('oc')::text || '/news/print/1.pdf'));
-- RUN
select @N@.set_newspaper_profile(pg_temp.ref('oc'), '{"legal_name": "대구뉴스", "editor_name": "대편집", "youth_officer_name": "대청소", "publish_address": "대구시 중구 동성로 1", "phone": "053-000-0003", "first_published_on": "2021-04-01"}');
-- TEST 완성 후 게시 | expect=ok
select @N@.publish_article(pg_temp.art('c-1'));
-- AS anon
-- TEST C 기사 공개 | expect=rows:1
select id, title from @N@.articles where slug = 'c-1';
-- TEST C 법정 푸터 공개 | expect=rows:1
select title, youth_officer_name, registration_no from @N@.newspapers where org_id = pg_temp.ref('oc');
-- AS N
-- RUN
select @N@.set_newspaper_profile(pg_temp.ref('oc'), '{"youth_officer_name": null}');
-- AS anon
-- TEST 청소년보호책임자 삭제 → C 기사 비공개 (위험 #5) | expect=rows:0
select id, title from @N@.articles where slug = 'c-1';
-- TEST 청소년보호책임자 삭제 → 법정 푸터 0행 | expect=rows:0
select title from @N@.newspapers where org_id = pg_temp.ref('oc');
-- TEST C read_article null | expect=rows:1
select 1 where @N@.read_article(pg_temp.ref('oc'), 'c-1') is null;
-- AS U
-- TEST 비공개 신문사 독자 가입 NW002 | expect=sqlstate:NW002
select @N@.ensure_reader(pg_temp.ref('oc'), '대구독자', 'v1', 'v1', true, false);

-- =====================================================================
-- 6. 방문자(anon) 공개 범위 (위험 #2)
-- =====================================================================
-- AS anon
-- TEST 공개 기사 공개 컬럼 | expect=rows:1
select id, title, byline, sponsor_label, ai_disclosure, revision_note from @N@.articles where slug = 'a-pub';
-- TEST 본문 컬럼 직접 조회 42501 | expect=sqlstate:42501
select body from @N@.articles where slug = 'a-pub';
-- TEST select * 42501 | expect=sqlstate:42501
select * from @N@.articles;
-- TEST 초안·제출·승인 기사 0행 | expect=rows:0
select id from @N@.articles where slug in ('k-draft', 'a-svc', 'poll-1', 'w-old');
-- TEST 엠바고 기사 0행 | expect=rows:0
select id from @N@.articles where slug = 'a-embargo';
-- TEST A 공개 기사 수(a-pub, w-ok, ai-1, prem-1, sp-1, a-sched) | expect=rows:6
select id from @N@.articles where org_id = pg_temp.ref('oa');
-- TEST read_article 본문 포함 | expect=rows:1
select 1 where (@N@.read_article(pg_temp.ref('oa'), 'a-pub') -> 'body') <> 'null'::jsonb;
-- TEST read_article 공개 수정 이력 1건 | expect=rows:1
select 1 where jsonb_array_length(@N@.read_article(pg_temp.ref('oa'), 'a-pub') -> 'corrections') = 1;
-- TEST read_article 엠바고 null | expect=rows:1
select 1 where @N@.read_article(pg_temp.ref('oa'), 'a-embargo') is null;
-- TEST 기사형 광고 라벨이 공개 응답에 있다 | expect=rows:1
select 1 where @N@.read_article(pg_temp.ref('oa'), 'sp-1') ->> 'sponsor_label' = '기사형 광고';
-- TEST AI 고지 문구 공개 | expect=rows:1
select 1 where @N@.read_article(pg_temp.ref('oa'), 'ai-1') ->> 'ai_disclosure' like 'AI가%';
-- TEST 전재 출처 공개 | expect=rows:1
select 1 where @N@.read_article(pg_temp.ref('oa'), 'w-ok') ->> 'wire_attribution' = '연합뉴스';
-- TEST 공개 기사 태그 | expect=rows:1
select tag_id from @N@.article_tags where article_id = pg_temp.art('a-pub');
-- TEST 사진 공개 컬럼 | expect=rows:1
select id, alt_text, credit from @N@.media_assets where org_id = pg_temp.ref('oa');
-- TEST 법정 푸터 컬럼(A) | expect=rows:1
select title, registration_no, publisher_name, editor_name, youth_officer_name, publish_address, phone from @N@.newspapers where org_id = pg_temp.ref('oa');
-- TEST 금칙어 목록 42501 | expect=sqlstate:42501
select banned_words from @N@.newspapers;
-- TEST 기자 공개 프로필(활성 6명) | expect=rows:6
select byline_name from @N@.staff where org_id = pg_temp.ref('oa');
-- TEST staff user_id 42501 | expect=sqlstate:42501
select user_id from @N@.staff;
-- TEST 독자 테이블 42501 | expect=sqlstate:42501
select 1 from @N@.readers;
-- TEST 댓글 테이블 42501 | expect=sqlstate:42501
select 1 from @N@.comments;
-- TEST 제보 테이블 42501 | expect=sqlstate:42501
select 1 from @N@.tips;
-- TEST 정정 청구 42501 | expect=sqlstate:42501
select 1 from @N@.correction_requests;
-- TEST 구독 테이블 42501 | expect=sqlstate:42501
select 1 from @N@.newsletter_subscriptions;
-- TEST 섹션 공개 | expect=rows:1
select slug from @N@.sections where org_id = pg_temp.ref('oa');
-- TEST save_article 실행 42501 | expect=sqlstate:42501
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "anon", "title": "x"}');
-- TEST post_comment 실행 42501 | expect=sqlstate:42501
select @N@.post_comment(pg_temp.art('a-pub'), '익명 댓글');
-- TEST 내부 헬퍼 assert_staff 실행 42501 | expect=sqlstate:42501
select @N@.assert_staff(pg_temp.ref('oa'), array['publisher'], 'x');
-- TEST has_entitlement 실행 42501(코어 규칙) | expect=sqlstate:42501
select @C@.has_entitlement(pg_temp.ref('oa'), 'news');
-- TEST 공개 판정 함수 | expect=rows:1
select 1 where @N@.is_public_newspaper(pg_temp.ref('oa')) and @N@.is_profile_complete(pg_temp.ref('oa'));

-- AS U
-- TEST 로그인 독자도 기사 테이블 직접 0행(공개 콘텐츠는 anon 키) | expect=rows:0
select 1 from @N@.articles;
-- TEST 독자 read_article 예약·엠바고 null | expect=rows:1
select 1 where @N@.read_article(pg_temp.ref('oa'), 'a-embargo') is null;
-- TEST 독자는 조직 멤버가 아니다 | expect=rows:1
select 1 where not @C@.is_org_member(pg_temp.ref('oa'));
-- TEST 독자 매체정보 수정 42501 | expect=sqlstate:42501
select @N@.set_newspaper_profile(pg_temp.ref('oa'), '{"phone": "010-1111-2222"}');

-- =====================================================================
-- 7. 교차 신문사 격리 (위험 #1)
-- =====================================================================
-- AS X
-- TEST B 발행인이 A 기사 0행 | expect=rows:0
select 1 from @N@.articles where org_id = pg_temp.ref('oa');
-- TEST B 발행인이 A 기사 게시 42501 | expect=sqlstate:42501
select @N@.publish_article(pg_temp.art('a-svc'));
-- TEST B 발행인이 A 기사 저장 42501 | expect=sqlstate:42501
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"title": "탈취"}');
-- TEST B 발행인이 A 매체정보 수정 42501 | expect=sqlstate:42501
select @N@.set_newspaper_profile(pg_temp.ref('oa'), '{"phone": "051-999-9999"}');
-- TEST B 발행인이 A 이력 0행 | expect=rows:0
select 1 from @N@.article_revisions where org_id = pg_temp.ref('oa');
-- TEST B 발행인이 A 매체정보 행 0 | expect=rows:0
select 1 from @N@.newspapers where org_id = pg_temp.ref('oa');
-- TEST B 기사에 A 섹션 23503 | expect=sqlstate:23503
select @N@.save_article(pg_temp.ref('ob'), null, jsonb_build_object('slug', 'b-cross', 'title', '교차', 'section_id', pg_temp.ref('sec_a')));
-- TEST B 기사에 A 사진 23503 | expect=sqlstate:23503
select @N@.save_article(pg_temp.ref('ob'), null, jsonb_build_object('slug', 'b-cross2', 'title', '교차', 'media_ids', jsonb_build_array(pg_temp.ref('media_a'))));
-- TEST B 발행인이 A 주간 지표 42501 | expect=sqlstate:42501
select @N@.compliance_weekly_stats(pg_temp.ref('oa'), date_trunc('week', now() at time zone 'Asia/Seoul')::date);
-- TEST B 보도자료 기사 작성 | expect=ok
select @N@.save_article(pg_temp.ref('ob'), null, '{"slug": "b-press", "title": "부산시 보도자료", "type": "press_release", "source_note": "부산시"}');
-- AS service
-- RUN
insert into t_art select slug, id from @N@.articles on conflict (slug) do nothing;
-- AS X
-- RUN
select @N@.submit_article(pg_temp.art('b-press'));
-- RUN
select @N@.review_article(pg_temp.art('b-press'), 'approve');
-- TEST B 게시 | expect=ok
select @N@.publish_article(pg_temp.art('b-press'));
-- TEST B 주간 지표: 자체기사 0%, 보도자료 과다 경고 | expect=rows:1
select 1 where (@N@.compliance_weekly_stats(pg_temp.ref('ob'), date_trunc('week', now() at time zone 'Asia/Seoul')::date) -> 'flags')
               @> '["original_ratio_below_30", "press_release_ratio_high"]'::jsonb;

-- =====================================================================
-- 8. 독자 데이터 (위험 #7)
-- =====================================================================
-- AS U
-- TEST 독자는 자기 행 1개만 | expect=rows:1
select 1 from @N@.readers;
-- TEST 독자 행 직접 UPDATE 42501 | expect=sqlstate:42501
update @N@.readers set status = 'active';
-- TEST 닉네임 중복 23505 | expect=sqlstate:23505
select @N@.ensure_reader(pg_temp.ref('oa'), '독자더블', 'v1', 'v1', true, false);
-- TEST 14세 미만 NW015 | expect=sqlstate:NW015
select @N@.ensure_reader(pg_temp.ref('ob'), '부산유', 'v1', 'v1', false, false);
-- AS V
-- TEST B 독자는 A 독자 0행 | expect=rows:0
select 1 from @N@.readers where org_id = pg_temp.ref('oa');
-- AS P
-- TEST A 발행인은 A 독자 2명 | expect=rows:2
select 1 from @N@.readers where org_id = pg_temp.ref('oa');
-- TEST A 발행인은 B 독자 0행 | expect=rows:0
select 1 from @N@.readers where org_id = pg_temp.ref('ob');
-- AS D
-- TEST 데스크는 독자 개인정보 0행 | expect=rows:0
select 1 from @N@.readers;
-- AS M
-- TEST 광고담당 독자 0행 | expect=rows:0
select 1 from @N@.readers;
-- AS X
-- TEST B 발행인은 A 독자 0행, B 독자 1 | expect=rows:1
select 1 from @N@.readers;

-- =====================================================================
-- 9. 댓글·신고·임시조치 (위험 #8)
-- =====================================================================
-- AS U
-- TEST 독자 댓글 | expect=ok
select @N@.post_comment(pg_temp.art('a-pub'), '축제 소식 고맙습니다');
-- TEST 금칙어 NW010 | expect=sqlstate:NW010
select @N@.post_comment(pg_temp.art('a-pub'), '이런 바보 같은 기사');
-- TEST 비공개 기사 댓글 P0002 | expect=sqlstate:P0002
select @N@.post_comment(pg_temp.art('a-svc'), '미리 보기');
-- AS V
-- TEST A 미가입 독자 댓글 NW008 | expect=sqlstate:NW008
select @N@.post_comment(pg_temp.art('a-pub'), '부산에서 왔어요');
-- AS anon
-- TEST 공개 댓글 목록(닉네임만) | expect=rows:1
select nickname, body from @N@.list_comments(pg_temp.art('a-pub')) where nickname = '독자유';
-- AS W
-- TEST 다른 독자 댓글 행 0 | expect=rows:0
select 1 from @N@.comments;
-- AS D
-- TEST 데스크 모더레이션 조회 1 | expect=rows:1
select 1 from @N@.comments;
-- AS R
-- TEST 기자는 댓글 원장 0행 | expect=rows:0
select 1 from @N@.comments;
-- AS X
-- TEST B 발행인 A 댓글 0행 | expect=rows:0
select 1 from @N@.comments;
-- AS service
-- RUN
insert into t_ref select 'cmt_u', id from @N@.comments where body = '축제 소식 고맙습니다';
-- AS W
-- TEST 권리침해 신고 → 임시조치 | expect=ok
select @N@.report_comment(pg_temp.ref('cmt_u'), 'defamation', '사실과 다른 내용', true);
-- TEST 같은 댓글 재신고 23505 | expect=sqlstate:23505
select @N@.report_comment(pg_temp.ref('cmt_u'), 'spam');
-- AS anon
-- TEST 임시조치 댓글은 공개 목록에서 빠진다 | expect=rows:0
select 1 from @N@.list_comments(pg_temp.art('a-pub'));
-- AS U
-- TEST 자기 댓글 신고 NW015 | expect=sqlstate:NW015
select @N@.report_comment(pg_temp.ref('cmt_u'), 'spam');
-- TEST 독자 댓글 직접 UPDATE 42501 | expect=sqlstate:42501
update @N@.comments set status = 'visible';
-- AS R
-- TEST 기자 모더레이션 42501 | expect=sqlstate:42501
select @N@.moderate_comment(pg_temp.ref('cmt_u'), 'show');
-- AS D
-- TEST 데스크 임시조치 해제 | expect=ok
select @N@.moderate_comment(pg_temp.ref('cmt_u'), 'show', '권리침해 소명 없음');
-- TEST 신고는 기각 처리 | expect=rows:1
select 1 from @N@.comment_reports where comment_id = pg_temp.ref('cmt_u') and status = 'dismissed';
-- AS anon
-- TEST 해제 후 공개 목록 1 | expect=rows:1
select 1 from @N@.list_comments(pg_temp.art('a-pub'));
-- AS P
-- RUN
select @N@.set_reader_status(pg_temp.ref('reader_u'), 'blocked', '반복 비방');
-- AS U
-- TEST 차단 독자 댓글 NW008 | expect=sqlstate:NW008
select @N@.post_comment(pg_temp.art('a-pub'), '다시 씁니다');
-- AS P
-- RUN
select @N@.set_reader_status(pg_temp.ref('reader_u'), 'active');
-- AS D
-- RUN
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"comments_enabled": false, "change_note": "댓글 닫기"}');
-- AS U
-- TEST 기사 댓글 꺼짐 NW009 | expect=sqlstate:NW009
select @N@.post_comment(pg_temp.art('a-pub'), '닫힌 기사');
-- AS D
-- RUN
select @N@.save_article(pg_temp.ref('oa'), pg_temp.art('a-pub'), '{"comments_enabled": true, "change_note": "댓글 다시 열기"}');
-- AS P
-- RUN
select @N@.upsert_election_period(pg_temp.ref('oa'), (select id from @N@.election_periods where org_id = pg_temp.ref('oa') limit 1), '{"comment_policy": "disabled"}');
-- AS U
-- TEST 선거 기간 댓글 정책 NW009 | expect=sqlstate:NW009
select @N@.post_comment(pg_temp.art('a-pub'), '선거 댓글');
-- AS P
-- RUN
select @N@.upsert_election_period(pg_temp.ref('oa'), (select id from @N@.election_periods where org_id = pg_temp.ref('oa') limit 1), '{"comment_policy": "normal"}');

-- =====================================================================
-- 10. 정정·반론 청구 SLA (위험 #6)
-- =====================================================================
-- AS service
-- TEST 웹 폼 청구 접수 | expect=ok
select @N@.submit_correction_request(pg_temp.ref('oa'), jsonb_build_object('article_id', pg_temp.art('a-pub'), 'kind', 'correction',
  'requester_name', '가야상인회', 'requester_email', 'shop@g.test', 'claim_text', '참가 상인 수가 잘못 보도되었습니다'));
-- RUN
insert into t_ref select 'req1', id from @N@.correction_requests where requester_name = '가야상인회';
-- TEST 통지 기한 = 접수 + 3일 | expect=rows:1
select 1 from @N@.correction_requests where id = pg_temp.ref('req1') and notify_due_at = received_at + interval '3 days';
-- TEST 서버도 통지 기한 변경 22023 | expect=sqlstate:22023
update @N@.correction_requests set notify_due_at = notify_due_at + interval '10 days' where id = pg_temp.ref('req1');
-- TEST 서버도 접수 시각 변경 22023 | expect=sqlstate:22023
update @N@.correction_requests set received_at = now() where id = pg_temp.ref('req1');
-- TEST 접수 시각 미래 NW015 | expect=sqlstate:NW015
select @N@.submit_correction_request(pg_temp.ref('oa'), jsonb_build_object('article_url', 'https://gimhae.example/1', 'kind', 'rebuttal',
  'requester_name', '갑', 'requester_phone', '010-0000-0001', 'claim_text', '반론 보도를 청구합니다', 'received_at', now() + interval '1 day'));
-- TEST 5일 전 우편 접수(기한 초과 사례) | expect=ok
select @N@.submit_correction_request(pg_temp.ref('oa'), jsonb_build_object('article_url', 'https://gimhae.example/2', 'kind', 'rebuttal',
  'requester_name', '을', 'requester_phone', '010-0000-0002', 'claim_text', '반론 보도를 청구합니다', 'channel', 'mail', 'received_at', now() - interval '5 days'));
-- AS U
-- TEST 독자 직접 청구 RPC 42501(서버 경유) | expect=sqlstate:42501
select @N@.submit_correction_request(pg_temp.ref('oa'), '{"kind": "correction", "article_url": "x", "requester_name": "유", "requester_email": "u@r.test", "claim_text": "정정을 요청합니다"}');
-- AS D
-- TEST 데스크 청구 조회 2 | expect=rows:2
select 1 from @N@.correction_requests;
-- TEST 데스크는 수용 결정 불가 42501 | expect=sqlstate:42501
select @N@.respond_correction_request(pg_temp.ref('req1'), 'accept');
-- AS E
-- TEST 기한 초과 1건 표시 | expect=rows:1
select 1 from @N@.correction_sla where notify_overdue;
-- TEST 거부 사유 없음 NW015 | expect=sqlstate:NW015
select @N@.respond_correction_request(pg_temp.ref('req1'), 'reject');
-- TEST 편집인 수용 | expect=ok
select @N@.respond_correction_request(pg_temp.ref('req1'), 'accept', '수치 확인, 정정 보도');
-- TEST 게재 기한 = 결정 + 7일, 통지 시각 기록 | expect=rows:1
select 1 from @N@.correction_requests where id = pg_temp.ref('req1') and status = 'accepted'
   and publish_due_at = decided_at + interval '7 days' and notified_at is not null;
-- TEST 결정 후 재결정 NW004 | expect=sqlstate:NW004
select @N@.respond_correction_request(pg_temp.ref('req1'), 'reject', '번복');
-- AS service
-- TEST 게재 기한 변경 22023 | expect=sqlstate:22023
update @N@.correction_requests set publish_due_at = publish_due_at + interval '30 days' where id = pg_temp.ref('req1');
-- AS D
-- TEST 청구 종류와 다른 정정 기록 NW015 | expect=sqlstate:NW015
select @N@.record_article_correction(pg_temp.art('a-pub'), 'rebuttal', '반론문 게재', pg_temp.ref('req1'));
-- TEST 청구 연결 정정 보도 기록 | expect=ok
select @N@.record_article_correction(pg_temp.art('a-pub'), 'correction', '참가 상인 수를 120곳에서 210곳으로 바로잡습니다', pg_temp.ref('req1'));
-- TEST 청구 게재 완료 | expect=rows:1
select 1 from @N@.correction_requests where id = pg_temp.ref('req1') and status = 'published' and published_revision_id is not null;
-- TEST 데스크 이력 직접 수정 42501 | expect=sqlstate:42501
update @N@.article_revisions set note = '변경' where article_id = pg_temp.art('a-pub');
-- AS service
-- TEST 서버도 이력 수정 불가 22023 | expect=sqlstate:22023
update @N@.article_revisions set note = '변경' where article_id = pg_temp.art('a-pub');
-- AS anon
-- TEST 공개 정정 이력 2건(수정 1 + 정정 1, 댓글 설정 변경은 이력 아님) | expect=rows:1
select 1 where jsonb_array_length(@N@.read_article(pg_temp.ref('oa'), 'a-pub') -> 'corrections') = 2;
-- AS X
-- TEST B 발행인 A 청구 0행 | expect=rows:0
select 1 from @N@.correction_requests where org_id = pg_temp.ref('oa');

-- =====================================================================
-- 11. 조회수·많이 본 뉴스·검색 (위험 #10)
-- =====================================================================
-- AS anon
-- TEST anon 조회수 증분 42501 | expect=sqlstate:42501
select @N@.increment_article_views(pg_temp.art('a-pub'), 1);
-- TEST anon 집계 테이블 42501 | expect=sqlstate:42501
select 1 from @N@.article_view_hourly;
-- AS U
-- TEST 독자 조회수 증분 42501 | expect=sqlstate:42501
select @N@.increment_article_views(pg_temp.art('a-pub'), 100);
-- AS R
-- TEST 기자 조회수 증분 42501 | expect=sqlstate:42501
select @N@.increment_article_views(pg_temp.art('a-pub'), 100);
-- AS service
-- TEST 서버 증분 | expect=rows:1
select 1 where @N@.increment_article_views(pg_temp.art('a-pub'), 5);
-- TEST 비공개 기사 증분 false | expect=rows:1
select 1 where not @N@.increment_article_views(pg_temp.art('k-draft'), 5);
-- TEST 엠바고 기사 증분 false | expect=rows:1
select 1 where not @N@.increment_article_views(pg_temp.art('a-embargo'), 5);
-- TEST 1회 상한 초과 NW015 | expect=sqlstate:NW015
select @N@.increment_article_views(pg_temp.art('a-pub'), 5000);
-- TEST 3일 전 소급 NW015 | expect=sqlstate:NW015
select @N@.increment_article_views(pg_temp.art('a-pub'), 1, now() - interval '3 days');
-- TEST 시간 버킷 1행에 5회 | expect=rows:1
select 1 from @N@.article_view_hourly where article_id = pg_temp.art('a-pub') and views = 5;
-- AS anon
-- TEST 많이 본 뉴스 24h | expect=rows:1
select 1 from @N@.most_read(pg_temp.ref('oa'), '24h') where slug = 'a-pub' and views = 5;
-- TEST 많이 본 뉴스 1h | expect=rows:1
select 1 from @N@.most_read(pg_temp.ref('oa'), '1h');
-- TEST 잘못된 창은 빈 결과 | expect=rows:0
select 1 from @N@.most_read(pg_temp.ref('oa'), '7d');
-- TEST 검색(제목 부분 일치) | expect=rows:1
select 1 from @N@.search_articles(pg_temp.ref('oa'), '축제 개막');
-- TEST 검색은 초안을 돌려주지 않는다 | expect=rows:0
select 1 from @N@.search_articles(pg_temp.ref('oa'), '기고문');
-- TEST 검색은 엠바고 기사를 돌려주지 않는다 | expect=rows:0
select 1 from @N@.search_articles(pg_temp.ref('oa'), '엠바고');
-- TEST 빈 검색어 NW015 | expect=sqlstate:NW015
select 1 from @N@.search_articles(pg_temp.ref('oa'), '  ');
-- AS D
-- TEST 데스크 조회 집계 1 | expect=rows:1
select 1 from @N@.article_view_hourly;
-- AS U
-- TEST 독자 조회 집계 0 | expect=rows:0
select 1 from @N@.article_view_hourly;

-- =====================================================================
-- 12. 광고 (위험 #4)
-- =====================================================================
-- AS M
-- TEST 광고담당 캠페인 | expect=ok
select @N@.save_ad_campaign(pg_temp.ref('oa'), null, jsonb_build_object('advertiser_id', pg_temp.ref('adv_local'), 'name', '가을 메뉴',
  'price_krw', 300000, 'starts_at', now() - interval '1 day', 'ends_at', now() + interval '10 days', 'status', 'active'));
-- TEST 정부 광고주 직판 NW013 | expect=sqlstate:NW013
select @N@.save_ad_campaign(pg_temp.ref('oa'), null, jsonb_build_object('advertiser_id', pg_temp.ref('adv_gov'), 'name', '시정 홍보',
  'price_krw', 500000, 'starts_at', now(), 'ends_at', now() + interval '10 days'));
-- AS service
-- RUN
insert into t_ref select 'camp', id from @N@.ad_campaigns where name = '가을 메뉴';
-- AS M
-- TEST 허용 밖 광고 라벨 23514 | expect=sqlstate:23514
select @N@.save_ad_creative(pg_temp.ref('oa'), null, jsonb_build_object('campaign_id', pg_temp.ref('camp'), 'slot_id', pg_temp.ref('slot_a'), 'kind', 'text',
  'headline', '가을 메뉴 출시', 'click_url', 'https://gaya.example', 'label', '홍보'));
-- TEST 이미지 소재 대체텍스트 없음 23514 | expect=sqlstate:23514
select @N@.save_ad_creative(pg_temp.ref('oa'), null, jsonb_build_object('campaign_id', pg_temp.ref('camp'), 'slot_id', pg_temp.ref('slot_a'), 'kind', 'image',
  'media_path', pg_temp.ref('oa')::text || '/news/ads/a.jpg', 'click_url', 'https://gaya.example'));
-- TEST 소재 등록 | expect=ok
select @N@.save_ad_creative(pg_temp.ref('oa'), null, jsonb_build_object('campaign_id', pg_temp.ref('camp'), 'slot_id', pg_temp.ref('slot_a'), 'kind', 'image',
  'media_path', pg_temp.ref('oa')::text || '/news/ads/a.jpg', 'alt_text', '가야식당 가을 메뉴', 'click_url', 'https://gaya.example'));
-- AS service
-- RUN
insert into t_ref select 'cre', id from @N@.ad_creatives where alt_text = '가야식당 가을 메뉴';
-- AS M
-- TEST 광고담당 소재 승인 42501 | expect=sqlstate:42501
select @N@.review_ad_creative(pg_temp.ref('cre'), 'approve');
-- TEST 광고담당 기사 작성 42501 | expect=sqlstate:42501
select @N@.save_article(pg_temp.ref('oa'), null, '{"slug": "m-1", "title": "광고담당 기사"}');
-- TEST 광고담당은 기사형 광고만 본다 | expect=rows:1
select 1 from @N@.articles;
-- TEST 광고담당 제보 0행 | expect=rows:0
select 1 from @N@.tips;
-- AS anon
-- TEST 승인 전 광고 노출 0 | expect=rows:0
select 1 from @N@.serve_ads(pg_temp.ref('oa'), 'home');
-- TEST 광고 소재 직접 조회 42501 | expect=sqlstate:42501
select 1 from @N@.ad_creatives;
-- TEST 슬롯 크기 공개(공간 예약) | expect=rows:1
select width, height from @N@.ad_slots where org_id = pg_temp.ref('oa');
-- AS E
-- TEST 편집인 소재 승인 | expect=ok
select @N@.review_ad_creative(pg_temp.ref('cre'), 'approve');
-- AS anon
-- TEST 광고 노출은 라벨과 함께 | expect=rows:1
select 1 from @N@.serve_ads(pg_temp.ref('oa'), 'home') where label = '광고';
-- AS M
-- RUN
select @N@.save_ad_creative(pg_temp.ref('oa'), pg_temp.ref('cre'), '{"click_url": "https://gaya.example/new"}');
-- AS anon
-- TEST 소재 수정 후 재검토 전 노출 0 | expect=rows:0
select 1 from @N@.serve_ads(pg_temp.ref('oa'), 'home');
-- AS R
-- TEST 기자 광고주 0행 | expect=rows:0
select 1 from @N@.advertisers;
-- AS service
-- TEST 광고 집계(서버) | expect=ok
select @N@.record_ad_stats(pg_temp.ref('cre'), (now() at time zone 'Asia/Seoul')::date, 100, 3);
-- AS M
-- TEST 광고담당 집계 조회 | expect=rows:1
select 1 from @N@.ad_daily_stats where impressions = 100;
-- TEST 광고담당 집계 직접 수정 42501 | expect=sqlstate:42501
update @N@.ad_daily_stats set impressions = 999999;

-- =====================================================================
-- 13. 뉴스레터 이중 동의·해지 토큰·2년 재확인
-- =====================================================================
-- AS service
-- RUN
insert into t_tok select 'nl', @N@.subscribe_newsletter(pg_temp.ref('oa'), 'morning', 'Sub@X.test', 'v1')::text;
-- TEST 토큰 원문은 저장하지 않는다 | expect=rows:0
select 1 from @N@.newsletter_subscriptions where confirm_token_hash = (pg_temp.tok('nl')::jsonb ->> 'confirm_token');
-- TEST 해시는 저장한다 | expect=rows:1
select 1 from @N@.newsletter_subscriptions where confirm_token_hash = @N@.token_hash(pg_temp.tok('nl')::jsonb ->> 'confirm_token') and email = 'sub@x.test';
-- TEST 광고 포함 목록은 광고 수신 동의 필수 NW015 | expect=sqlstate:NW015
select @N@.subscribe_newsletter(pg_temp.ref('oa'), 'promo', 'sub2@x.test', 'v1', false);
-- TEST 동의 문구 버전 불일치 NW015 | expect=sqlstate:NW015
select @N@.subscribe_newsletter(pg_temp.ref('oa'), 'morning', 'sub3@x.test', 'v0');
-- AS anon
-- TEST anon 구독 신청 RPC 42501(서버 경유) | expect=sqlstate:42501
select @N@.subscribe_newsletter(pg_temp.ref('oa'), 'morning', 'anon@x.test', 'v1');
-- TEST 잘못된 토큰 NW012 | expect=sqlstate:NW012
select @N@.confirm_newsletter(repeat('0', 64));
-- TEST 이중 동의 확인 | expect=rows:1
select 1 where @N@.confirm_newsletter(pg_temp.tok('nl')::jsonb ->> 'confirm_token') ->> 'status' = 'confirmed';
-- TEST 같은 확인 토큰 재사용 NW012 | expect=sqlstate:NW012
select @N@.confirm_newsletter(pg_temp.tok('nl')::jsonb ->> 'confirm_token');
-- AS service
-- TEST 재확인 기한 = 확인 + 2년 | expect=rows:1
select 1 from @N@.newsletter_subscriptions where email = 'sub@x.test' and reconfirm_due_at = confirmed_at + interval '2 years';
-- TEST 재확인 기한 직접 변경 22023 | expect=sqlstate:22023
update @N@.newsletter_subscriptions set reconfirm_due_at = now() + interval '10 years' where email = 'sub@x.test';
-- RUN
insert into t_tok select 'rc', @N@.issue_newsletter_reconfirm(id) from @N@.newsletter_subscriptions where email = 'sub@x.test';
-- AS anon
-- TEST 2년 재확인 | expect=ok
select @N@.confirm_newsletter(pg_temp.tok('rc'));
-- AS service
-- TEST 재확인 후 기한 = 재확인 + 2년 | expect=rows:1
select 1 from @N@.newsletter_subscriptions where email = 'sub@x.test' and reconfirmed_at is not null and reconfirm_due_at = reconfirmed_at + interval '2 years';
-- AS P
-- TEST 발행인 구독자 조회 | expect=rows:1
select email, status from @N@.newsletter_subscriptions;
-- TEST 토큰 해시 컬럼 42501 | expect=sqlstate:42501
select confirm_token_hash from @N@.newsletter_subscriptions;
-- AS D
-- TEST 데스크 구독자 0행 | expect=rows:0
select 1 from @N@.newsletter_subscriptions;
-- TEST 광고 포함 회차 제목 (광고) 없음 23514 | expect=sqlstate:23514
select @N@.save_newsletter_issue(pg_temp.ref('oa'), null, jsonb_build_object('list_id', pg_temp.ref('list_morning'), 'subject', '아침 브리핑', 'contains_ad', true));
-- TEST 발송 상태 직접 지정 42501 | expect=sqlstate:42501
select @N@.save_newsletter_issue(pg_temp.ref('oa'), null, jsonb_build_object('list_id', pg_temp.ref('list_morning'), 'subject', '아침', 'status', 'sent'));
-- TEST 회차 저장 | expect=ok
select @N@.save_newsletter_issue(pg_temp.ref('oa'), null, jsonb_build_object('list_id', pg_temp.ref('list_morning'), 'subject', '(광고) 아침 브리핑', 'contains_ad', true));
-- AS anon
-- TEST 해지 | expect=rows:1
select 1 where (@N@.unsubscribe_newsletter(pg_temp.tok('nl')::jsonb ->> 'unsubscribe_token') ->> 'changed')::boolean;
-- TEST 해지 멱등 | expect=rows:1
select 1 where not (@N@.unsubscribe_newsletter(pg_temp.tok('nl')::jsonb ->> 'unsubscribe_token') ->> 'changed')::boolean;
-- AS service
-- TEST 재구독은 새 토큰 발급 | expect=rows:1
select 1 where (@N@.subscribe_newsletter(pg_temp.ref('oa'), 'morning', 'sub@x.test', 'v1') ->> 'send_confirmation')::boolean;

-- =====================================================================
-- 14. 제보(제보자 보호)와 첨부 Storage 제한
-- =====================================================================
-- AS service
-- TEST 제보 접수(서버) | expect=ok
select @N@.submit_tip(pg_temp.ref('oa'), jsonb_build_object('title', '하천 오염', 'body', '가야천에 폐수가 흘러듭니다. 사진 첨부.', 'contact_phone', '010-1234-5678',
  'attachment_paths', jsonb_build_array(pg_temp.ref('oa')::text || '/news/tips/a.jpg'), 'consent_version', 'v1'));
-- TEST 다른 신문 경로 첨부 23514 | expect=sqlstate:23514
select @N@.submit_tip(pg_temp.ref('oa'), jsonb_build_object('title', '경로', 'body', '다른 신문 폴더 경로 시험입니다', 'consent_version', 'v1',
  'attachment_paths', jsonb_build_array(pg_temp.ref('ob')::text || '/news/tips/x.jpg')));
-- TEST 상위 경로(..) 첨부 23514 | expect=sqlstate:23514
select @N@.submit_tip(pg_temp.ref('oa'), jsonb_build_object('title', '경로', 'body', '상위 경로 이동 시험입니다', 'consent_version', 'v1',
  'attachment_paths', jsonb_build_array(pg_temp.ref('oa')::text || '/news/tips/../media/p.jpg')));
-- AS U
-- TEST 독자 직접 제보 RPC 42501(서버 경유) | expect=sqlstate:42501
select @N@.submit_tip(pg_temp.ref('oa'), '{"title": "x", "body": "직접 제보 시험입니다", "consent_version": "v1"}');
-- AS D
-- TEST 데스크 제보 조회 | expect=rows:1
select 1 from @N@.tips;
-- TEST 데스크 제보 첨부 파일 조회 | expect=rows:1
select 1 from storage.objects where name like '%/news/tips/%';
-- RUN
select @N@.set_tip_status((select id from @N@.tips limit 1), 'assigned', '10000000-0000-4000-8000-000000000004');
-- AS R
-- TEST 배정된 기자 제보 조회 | expect=rows:1
select 1 from @N@.tips;
-- AS K
-- TEST 기고자 제보 0행 | expect=rows:0
select 1 from @N@.tips;
-- TEST 기고자 제보 첨부 파일 0행(제한 정책) | expect=rows:0
select 1 from storage.objects where name like '%/news/tips/%';
-- TEST 기고자 일반 조직 파일은 보인다(대조) | expect=rows:1
select 1 from storage.objects where name like '%/news/media/raw.jpg';
-- TEST 사용자 세션 제보 폴더 업로드 42501 | expect=sqlstate:42501
insert into storage.objects (bucket_id, name) values ('org-files', pg_temp.ref('oa')::text || '/news/tips/b.jpg');
-- AS X
-- TEST B 발행인 A 제보 0행 | expect=rows:0
select 1 from @N@.tips;

-- =====================================================================
-- 15. 멤버십·프리미엄·후원 (결제 기록은 서버만)
-- =====================================================================
-- AS U
-- TEST 독자 멤버십 기록 42501 | expect=sqlstate:42501
select @N@.record_membership(pg_temp.ref('oa'), pg_temp.ref('reader_u'), pg_temp.ref('tier_a'), 'active');
-- AS service
-- TEST 서버 멤버십 활성 | expect=ok
select @N@.record_membership(pg_temp.ref('oa'), pg_temp.ref('reader_w'), pg_temp.ref('tier_a'), 'active', now(), now() + interval '1 month', 'toss-sub-1', 'evt-1');
-- TEST 같은 이벤트 재처리 멱등 | expect=rows:1
select 1 where (@N@.record_membership(pg_temp.ref('oa'), pg_temp.ref('reader_w'), pg_temp.ref('tier_a'), 'active', null, null, null, 'evt-1')).id
             = (select id from @N@.memberships where reader_id = pg_temp.ref('reader_w'));
-- TEST 활성 → pending 역행 22023 | expect=sqlstate:22023
select @N@.record_membership(pg_temp.ref('oa'), pg_temp.ref('reader_w'), pg_temp.ref('tier_a'), 'pending');
-- TEST 후원 기록(결제 완료) | expect=ok
select @N@.record_donation(pg_temp.ref('oa'), 'don_000001', 'paid', 50000, '{"payment_key": "pk_1", "donor_display_name": "가야주민"}');
-- TEST 후원 금액 불일치 NW015 | expect=sqlstate:NW015
select @N@.record_donation(pg_temp.ref('oa'), 'don_000001', 'paid', 5000);
-- AS W
-- TEST 멤버 자기 멤버십 1 | expect=rows:1
select 1 from @N@.memberships;
-- TEST 멤버 프리미엄 본문 열림 | expect=rows:1
select 1 where (@N@.read_article(pg_temp.ref('oa'), 'prem-1') ->> 'locked')::boolean = false
           and @N@.read_article(pg_temp.ref('oa'), 'prem-1') -> 'body' <> 'null'::jsonb;
-- TEST 멤버십 직접 수정 42501 | expect=sqlstate:42501
update @N@.memberships set status = 'expired';
-- AS U
-- TEST 비멤버 프리미엄 잠김 | expect=rows:1
select 1 where (@N@.read_article(pg_temp.ref('oa'), 'prem-1') ->> 'locked')::boolean and @N@.read_article(pg_temp.ref('oa'), 'prem-1') -> 'body' = 'null'::jsonb;
-- TEST 다른 독자 멤버십 0 | expect=rows:0
select 1 from @N@.memberships;
-- AS anon
-- TEST 방문자 프리미엄 잠김 | expect=rows:1
select 1 where (@N@.read_article(pg_temp.ref('oa'), 'prem-1') ->> 'locked')::boolean;
-- AS P
-- TEST 발행인 후원 조회 | expect=rows:1
select 1 from @N@.donations;
-- AS X
-- TEST B 발행인 A 후원 0 | expect=rows:0
select 1 from @N@.donations;
-- AS W
-- TEST 멤버십 남은 독자 탈퇴 NW004 | expect=sqlstate:NW004
select @N@.withdraw_reader(pg_temp.ref('oa'));

-- =====================================================================
-- 16. 홈 편집·경조사·행사·공고
-- =====================================================================
-- AS D
-- RUN
select @N@.save_home_layout(pg_temp.ref('oa'), null, '{"name": "10월 홈", "template": "traditional", "blocks": [{"block": "headline", "enabled": true}]}');
-- TEST 홈 게시 | expect=ok
select @N@.publish_home_layout((select id from @N@.home_layouts where name = '10월 홈'));
-- TEST 게시본 블록 수정 22023 | expect=sqlstate:22023
select @N@.save_home_layout(pg_temp.ref('oa'), (select id from @N@.home_layouts where name = '10월 홈'), '{"blocks": []}');
-- AS K
-- TEST 기고자 홈 편집 42501 | expect=sqlstate:42501
select @N@.save_home_layout(pg_temp.ref('oa'), null, '{"name": "x", "template": "feed"}');
-- AS anon
-- TEST 게시된 홈 공개 | expect=rows:1
select template, version from @N@.home_layouts where org_id = pg_temp.ref('oa') and version = 1;
-- AS U
-- TEST 독자 부고 신청 | expect=ok
select @N@.submit_life_event(pg_temp.ref('oa'), '{"kind": "obituary", "title": "가야동 김모씨 별세", "body": "발인 10월 17일", "applicant_name": "김상주", "consent_version": "v1"}');
-- AS V
-- TEST 미가입 독자 신청 NW008 | expect=sqlstate:NW008
select @N@.submit_life_event(pg_temp.ref('oa'), '{"kind": "wedding", "title": "화촉", "body": "결혼합니다", "applicant_name": "부산", "consent_version": "v1"}');
-- AS anon
-- TEST 검토 전 경조사 비공개 | expect=rows:0
select 1 from @N@.life_events;
-- AS D
-- TEST 데스크 경조사 승인 | expect=ok
select @N@.review_life_event((select id from @N@.life_events limit 1), 'approve');
-- AS anon
-- TEST 승인 경조사 공개 | expect=rows:1
select title from @N@.life_events;
-- AS R
-- TEST 기자 행사 게시 | expect=ok
select @N@.save_event(pg_temp.ref('oa'), null, jsonb_build_object('title', '가야 문화축제', 'starts_at', now() + interval '3 days', 'status', 'published'));
-- AS M
-- TEST 광고담당 지자체 공고 게시 | expect=ok
select @N@.save_public_notice(pg_temp.ref('oa'), null, '{"issuer_name": "김해시", "title": "도시계획 열람 공고", "body": "열람 기간 14일", "status": "published"}');
-- AS anon
-- TEST 행사·공고 공개 | expect=rows:2
select title from @N@.events union all select title from @N@.public_notices;

-- =====================================================================
-- 17. 주간 자체기사 지표 (NW-F-041, 위험 #9)
-- =====================================================================
-- AS R
-- TEST 기자 주간 지표 42501 | expect=sqlstate:42501
select @N@.compliance_weekly_stats(pg_temp.ref('oa'), date_trunc('week', now() at time zone 'Asia/Seoul')::date);
-- AS D
-- TEST 월요일이 아닌 시작일 NW015 | expect=sqlstate:NW015
select @N@.compliance_weekly_stats(pg_temp.ref('oa'), date_trunc('week', now() at time zone 'Asia/Seoul')::date + 1);
-- TEST A 이번 주: 분모 6(광고 제외), 자체 4, AI 보도자료 1(자체 아님), 광고 1 | expect=rows:1
select 1 from (select @N@.compliance_weekly_stats(pg_temp.ref('oa'), date_trunc('week', now() at time zone 'Asia/Seoul')::date) s) x
 where (s ->> 'total_published')::int = 6 and (s ->> 'original_count')::int = 4 and (s ->> 'ai_press_release_count')::int = 1
   and (s ->> 'press_release_count')::int = 1 and (s ->> 'wire_count')::int = 1 and (s ->> 'sponsored_count')::int = 1
   and jsonb_array_length(s -> 'flags') = 0;
-- TEST 지난주 신규 게재 0 경고 | expect=rows:1
select 1 where @N@.compliance_weekly_stats(pg_temp.ref('oa'), date_trunc('week', now() at time zone 'Asia/Seoul')::date - 7) -> 'flags' @> '["no_new_articles"]'::jsonb;
-- AS O
-- TEST 운영자 지표 조회 | expect=ok
select @N@.compliance_weekly_stats(pg_temp.ref('oa'), date_trunc('week', now() at time zone 'Asia/Seoul')::date);

-- =====================================================================
-- 18. 엔타이틀먼트 정지 시 편집국·공개 모두 차단
-- =====================================================================
-- AS service
-- RUN
update @C@.app_entitlements set status = 'suspended' where org_id = pg_temp.ref('ob') and app_id = 'news';
-- AS X
-- TEST 정지된 신문 편집국 조회 0 | expect=rows:0
select 1 from @N@.articles;
-- TEST 정지된 신문 저장 42501 | expect=sqlstate:42501
select @N@.save_article(pg_temp.ref('ob'), null, '{"slug": "b-2", "title": "정지 중"}');
-- AS anon
-- TEST 정지된 신문 기사 비공개 | expect=rows:0
select 1 from @N@.articles where org_id = pg_temp.ref('ob');
-- TEST 정지된 신문 테마 해석 null(Theming) | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'busan-weekly', 'news') is null;
-- TEST 활성 신문 테마 해석(서브도메인 슬러그) | expect=rows:1
select 1 where @C@.resolve_tenant(null, 'gimhae-times', 'news') ->> 'org_id' = pg_temp.ref('oa')::text;
