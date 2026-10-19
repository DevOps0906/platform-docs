// RLS·RPC 스모크(PGlite). docs/products/airbnb/05_DATA_MODEL.md 9장
// 실행: cd docs/products/_tools-sqlcheck && npm install && node ../airbnb/supabase/monolith/tests/rls_smoke.mjs . ../airbnb/supabase/monolith
// pglite-vec(0.3.x)의 btree_gist·vector 확장을 쓴다. 0001 → 0002 → seed 를 두 번 적용(반복 실행 검사)한 뒤 49개 항목을 검사한다.
// usage: node run.mjs <sqlcheck_dir> <monolith_dir>
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const [chk, mono] = process.argv.slice(2);
const nm = (p) => pathToFileURL(join(chk, 'node_modules', 'pglite-vec', 'dist', p)).href;
const { PGlite } = await import(nm('index.js'));
const ext = {};
for (const n of ['pgcrypto', 'citext', 'pg_trgm', 'uuid_ossp', 'btree_gist']) ext[n] = (await import(nm(`contrib/${n}.js`)))[n];
ext.vector = (await import(nm('vector/index.js'))).vector;
const db = new PGlite({ extensions: ext });
const stub = /create\s+extension\s+if\s+not\s+exists\s+"?(pg_cron|pg_net|supabase_vault|pg_graphql|pg_stat_statements|pgjwt|moddatetime|http|pgsodium)"?[^;]*;/gi;
const run = async (label, sql) => {
  try { await db.exec(sql.replace(stub, '-- stub;')); console.log('OK  ', label); }
  catch (e) { console.log('FAIL', label, e.message); process.exit(1); }
};
await run('prelude', readFileSync(join(chk, 'prelude.sql'), 'utf8'));
for (const f of ['migrations/0001_core_lite.sql', 'migrations/0002_stay_domain.sql', 'seed.sql', 'migrations/0002_stay_domain.sql', 'seed.sql'])
  await run(f, readFileSync(join(mono, f), 'utf8'));

let pass = 0, fail = 0;
const as = async (who, sql) => {
  await db.exec('reset role');
  const set = (sub, role) => db.exec(`select set_config('request.jwt.claim.sub','${sub}',false), set_config('request.jwt.claim.role','${role}',false);`);
  if (who === 'anon') { await set('', 'anon'); await db.exec('set role anon'); }
  else if (who === 'service') { await set('', 'service_role'); await db.exec('set role service_role'); }
  else if (who) { await set(who, 'authenticated'); await db.exec('set role authenticated'); }
  else { await set('', ''); }
  return db.query(sql);
};
const expectOk = async (name, who, sql, check = () => true) => {
  try {
    const r = await as(who, sql);
    if (check(r.rows)) { pass++; console.log('PASS', name); }
    else { fail++; console.log('FAIL', name, JSON.stringify(r.rows).slice(0, 300)); }
    return r.rows;
  } catch (e) { fail++; console.log('FAIL', name, e.message); return []; }
};
const expectErr = async (name, who, sql, code) => {
  try { await as(who, sql); fail++; console.log('FAIL', name, '(no error)'); }
  catch (e) {
    const ok = !code || e.code === code;
    ok ? pass++ : fail++;
    console.log(ok ? 'PASS' : 'FAIL', name, e.code, e.message.slice(0, 90));
  }
};
const H = '00000000-0000-0000-0000-0000000000a1', G = '00000000-0000-0000-0000-0000000000b2', O = '00000000-0000-0000-0000-0000000000c3';
await as(null, `insert into auth.users (id, email, raw_user_meta_data) values
  ('${H}','host@dev.test','{"display_name":"호스트"}'), ('${G}','guest@dev.test','{"display_name":"게스트"}'), ('${O}','outsider@dev.test','{}')`);
await expectOk('가입 -> stay 엔타이틀먼트', null,
  `select public.has_entitlement(o.id,'stay') e from public.organizations o where o.owner_id='${H}'`, r => r[0]?.e === true);
const L = (await expectOk('호스트 create_listing', H, `select id, org_id from public.create_listing()`, r => r.length === 1))[0];
await expectOk('호스트 숙소 정보 수정(컬럼 GRANT)', H,
  `update public.listings set title='바다 앞 조용한 독채', description='창밖으로 바다가 보이는 조용한 독채입니다. 가족 여행에 좋아요.',
   price_per_night=120000, cleaning_fee=20000, max_guests=4, city='강릉시', min_nights=1, max_nights=14 where id='${L.id}' returning id`, r => r.length === 1);
await expectErr('호스트 status 직접 변경 거부', H, `update public.listings set status='published' where id='${L.id}'`, '42501');
await expectErr('게시 조건 미충족 SY010', H, `select public.transition_listing('${L.id}','published')`, 'SY010');
await expectOk('비공개 주소 입력 -> 공개 좌표 반올림', H,
  `update public.listing_private set street_address='강원 강릉시 해안로 1', detail_address='101호', lat=37.771234, lng=128.947654 where listing_id='${L.id}' returning listing_id`, r => r.length === 1);
await expectOk('공개 좌표 37.77', H, `select public_lat from public.listings where id='${L.id}'`, r => String(r[0]?.public_lat) === '37.77');
await expectOk('사진 5장 추가', H,
  `insert into public.listing_photos (org_id, listing_id, storage_path, position)
   select '${L.org_id}','${L.id}', '${L.org_id}/listings/${L.id}/p'||g||'.webp', g from generate_series(1,5) g returning id`, r => r.length === 5);
await expectErr('다른 경로 사진 거부', H,
  `insert into public.listing_photos (org_id, listing_id, storage_path) values ('${L.org_id}','${L.id}','other/x.webp')`, '23514');
await expectOk('게시 published', H, `select (public.transition_listing('${L.id}','published')).status`, r => r[0].status === 'published');
await expectErr('anon 테이블 직접 읽기 거부', 'anon', `select * from public.listings`, '42501');
await expectOk('anon 검색 1건', 'anon', `select public.search_listings(p_city => '강릉시', p_guests => 2) j`, r => r.length === 1);
await expectOk('anon 지도 경계 검색 1건', 'anon', `select public.search_listings(37.5, 128.5, 38.0, 129.2) j`, r => r.length === 1);
await expectOk('anon 상세에 정확한 주소 없음', 'anon', `select public.get_listing_public('${L.id}') j`,
  r => !JSON.stringify(r[0].j).includes('해안로') && r[0].j.photos.length === 5);
await expectOk('outsider 숙소 테이블 0행', O, `select * from public.listings`, r => r.length === 0);
await expectOk('outsider 숙소 수정 0행', O, `update public.listings set title='해킹' where id='${L.id}' returning id`, r => r.length === 0);
const d = (n) => `(public.stay_today() + ${n})`;
const R1 = (await expectOk('게스트 예약 요청', G,
  `select id, status, total_price from public.create_reservation('${L.id}', ${d(10)}, ${d(13)}, 2, 0, 0, '잘 부탁드립니다')`,
  r => r[0]?.status === 'requested' && r[0]?.total_price === 380000))[0];
await expectErr('겹치는 예약 SY003', O, `select public.create_reservation('${L.id}', ${d(12)}, ${d(14)}, 1)`, 'SY003');
await expectErr('호스트 자기 숙소 예약 SY006', H, `select public.create_reservation('${L.id}', ${d(20)}, ${d(21)}, 1)`, 'SY006');
await expectErr('인원 초과 SY004', O, `select public.create_reservation('${L.id}', ${d(20)}, ${d(21)}, 5)`, 'SY004');
await expectErr('과거 날짜 SY002', O, `select public.create_reservation('${L.id}', ${d(-2)}, ${d(1)}, 1)`, 'SY002');
await expectErr('anon 예약 RPC 거부', 'anon', `select public.create_reservation('${L.id}', ${d(20)}, ${d(21)}, 1)`, '42501');
await expectErr('게스트 예약 직접 INSERT 거부', G,
  `insert into public.reservations (org_id, listing_id, guest_user_id, check_in, check_out, nightly_price, total_price)
   values ('${L.org_id}','${L.id}','${G}', ${d(30)}, ${d(31)}, 1, 1)`, '42501');
await expectOk('requested 게스트는 주소 못 봄', G, `select * from public.listing_private`, r => r.length === 0);
await expectErr('게스트가 승인 시도 42501', G, `select public.respond_reservation('${R1.id}', true)`, '42501');
await expectOk('호스트 승인', H, `select (public.respond_reservation('${R1.id}', true)).status`, r => r[0].status === 'confirmed');
await expectOk('confirmed 게스트는 주소 봄', G, `select street_address from public.listing_private`, r => r.length === 1);
await expectOk('outsider 예약 0행', O, `select * from public.reservations`, r => r.length === 0);
await expectOk('달력 불가 구간(anon)', 'anon', `select * from public.listing_unavailable_ranges('${L.id}', public.stay_today(), public.stay_today()+60)`, r => r.length === 1);
await expectErr('날짜 차단이 예약과 겹치면 SY003', H, `select public.block_dates('${L.id}', ${d(11)}, ${d(12)})`, 'SY003');
await expectOk('날짜 차단', H, `select id from public.block_dates('${L.id}', ${d(40)}, ${d(42)}, '수리')`, r => r.length === 1);
await expectErr('차단 날짜 예약 SY003', O, `select public.create_reservation('${L.id}', ${d(41)}, ${d(43)}, 1)`, 'SY003');
await expectErr('완료 전 리뷰 SY008', G, `select public.create_review('${R1.id}', 5, '정말 좋았어요 다음에 또 올게요')`, 'SY008');
await as(null, `update public.reservations set check_in = public.stay_today()-3, check_out = public.stay_today()-1 where id='${R1.id}'`);
await expectErr('authenticated 정리 함수 거부', G, `select public.stay_run_maintenance()`, '42501');
await expectOk('service 정리 -> completed', 'service', `select public.stay_run_maintenance() j`, r => r[0].j.completed === 1);
await expectErr('outsider 남의 예약 리뷰 SY001', O, `select public.create_review('${R1.id}', 1, '가 보지도 않은 숙소 리뷰')`, 'SY001');
await expectOk('리뷰 작성', G, `select (public.create_review('${R1.id}', 4, '바다가 보여서 정말 좋았어요')).rating`, r => r[0].rating === 4);
await expectErr('중복 리뷰 SY009', G, `select public.create_review('${R1.id}', 5, '한 번 더 쓰는 리뷰입니다')`, 'SY009');
await expectOk('평균 별점 트리거', H, `select rating_avg, review_count from public.listings where id='${L.id}'`,
  r => String(r[0].rating_avg) === '4.0' && r[0].review_count === 1);
await expectOk('공개 리뷰 이름 가림', 'anon', `select public.listing_reviews_public('${L.id}') j`, r => /^.\*\*$/.test(r[0].j.reviewer_name));
await expectOk('찜 켜기', G, `select public.toggle_wishlist('${L.id}') v`, r => r[0].v === true);
await expectOk('내 찜 1건', G, `select public.my_wishlist() j`, r => r.length === 1);
await expectOk('outsider 찜 0행', O, `select * from public.wishlists`, r => r.length === 0);
await expectOk('내 여행에 주소 포함(completed)', G, `select public.my_trips() j`, r => r[0].j.private?.street_address === '강원 강릉시 해안로 1');
await expectOk('호스트 예약함 게스트 이름', H, `select public.host_reservations('${L.org_id}') j`, r => typeof r[0].j.guest_display_name === 'string' && r[0].j.guest_display_name.length > 0);
await expectErr('outsider 호스트 예약함 거부', O, `select public.host_reservations('${L.org_id}')`, '42501');
await expectOk('라우팅 기본값 11행', null, `select count(*)::int c from public.ai_routing_settings where org_id is null and app_id='stay'`, r => r[0].c === 11);
await expectOk('숙소 삭제(소프트)', H, `select public.delete_listing('${L.id}')`, () => true);
await expectOk('삭제 숙소 검색 0건', 'anon', `select public.search_listings(p_city => '강릉시') j`, r => r.length === 0);
console.log(`\nRESULT pass=${pass} fail=${fail}`);
process.exit(fail ? 1 : 0);
