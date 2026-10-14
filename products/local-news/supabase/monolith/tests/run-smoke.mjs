// run-smoke.mjs — local-news RLS/권한 스모크 러너 (PGlite, Supabase 없이 실행)
//
// 사용: (저장소 루트에서)
//   cd products/_tools-sqlcheck && npm ci && cd ../..
//   node products/local-news/supabase/monolith/tests/run-smoke.mjs --target mono   # 모놀리스: 0001 + 0002 + 0003 + seed.sql
//   node products/local-news/supabase/monolith/tests/run-smoke.mjs --target mod    # 모듈러: core 0000~0009 + seed + Theming 0011 + 2500_news.sql
//   --verbose : 통과한 항목 이름도 출력
//
// 테스트 파일(rls_smoke.sql) 형식은 Multi-tenant_Theming/supabase/tests/run-smoke.mjs 와 같다:
//   -- SETUP ... -- END SETUP           관리 세션(postgres, JWT 없음 = core.is_service_caller() 참)으로 한 번에 실행
//   -- AS <행위자>                      이후 문장의 역할 전환(아래 actors 표)
//   -- RUN                              다음 한 문장을 기대값 없이 실행(실패하면 FAIL 로 센다)
//   -- TEST <이름> | expect=<rows:N | ok | sqlstate:CODE>
//   @C@ = core|public, @N@ = news|public 로 치환한다.
import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..', '..', '..');
const tools = join(root, 'products', '_tools-sqlcheck');
const target = process.argv.includes('--target') ? process.argv[process.argv.indexOf('--target') + 1] : 'mono';
const verbose = process.argv.includes('--verbose');
if (!['mod', 'mono'].includes(target)) { console.error('--target mod | mono'); process.exit(2); }

const req = createRequire(join(tools, 'package.json'));
const load = (spec) => import(pathToFileURL(req.resolve(spec)).href);
const { PGlite } = await load('pglite-vec');
const ext = {};
for (const name of ['pgcrypto', 'citext', 'pg_trgm', 'uuid_ossp']) ext[name] = (await load(`pglite-vec/contrib/${name}`))[name];
ext.vector = (await load('pglite-vec/vector')).vector;
const db = new PGlite({ extensions: ext });

const stubRe = /create\s+extension\s+if\s+not\s+exists\s+"?(pg_cron|pg_net|supabase_vault|pg_graphql|pg_stat_statements|pgjwt|moddatetime|http|pgsodium)"?[^;]*;/gi;
const C = target === 'mod' ? 'core' : 'public';
const N = target === 'mod' ? 'news' : 'public';
const read = (p) => readFileSync(join(root, p), 'utf8');
const mono = 'products/local-news/supabase/monolith';
const files = target === 'mod'
  ? [
      ...readdirSync(join(root, 'products/_supabase-modular/migrations')).filter((f) => /^000\d_/.test(f)).sort()
        .map((f) => [f, read(`products/_supabase-modular/migrations/${f}`)]),
      ['seed.sql', read('products/_supabase-modular/seed.sql')],
      ['0011_core_tenant_theming.sql', read('Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql')],
      ['2500_news.sql', read('products/_supabase-modular/migrations/2500_news.sql')],
    ]
  : [
      ['0001_core_lite.sql', read(`${mono}/migrations/0001_core_lite.sql`)],
      ['0002_tenant_theming.sql', read(`${mono}/migrations/0002_tenant_theming.sql`)],
      ['0003_local_news_domain.sql', read(`${mono}/migrations/0003_local_news_domain.sql`)],
      ['seed.sql', read(`${mono}/seed.sql`)],
    ];

await db.exec(readFileSync(join(tools, 'prelude.sql'), 'utf8'));
for (const [name, sql] of files) {
  try { await db.exec(sql.replace(stubRe, '-- stubbed $1;')); }
  catch (e) { console.log(`APPLY FAIL ${name}: ${e.message}`); process.exit(1); }
}

// 행위자: 05_DATA_MODEL.md 10절 페르소나와 같은 역할
const uid = (n) => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const actors = {
  service: ['service_role', ''], anon: ['anon', ''],
  P: ['authenticated', uid(1)],   // A 신문 발행인(owner, publisher)
  E: ['authenticated', uid(2)],   // A 편집인(admin, editor)
  D: ['authenticated', uid(3)],   // A 데스크(member, desk)
  R: ['authenticated', uid(4)],   // A 기자(member, reporter)
  K: ['authenticated', uid(5)],   // A 기고자(member, contributor)
  M: ['authenticated', uid(6)],   // A 광고담당(member, ad_manager)
  Z: ['authenticated', uid(7)],   // 시험 중 초대되는 사용자
  X: ['authenticated', uid(8)],   // B 신문 발행인(outsider)
  U: ['authenticated', uid(9)],   // A 독자(reader)
  W: ['authenticated', uid(10)],  // A 유료 멤버 독자(reader_member)
  V: ['authenticated', uid(11)],  // B 독자(reader_other)
  N: ['authenticated', uid(12)],  // C 신문 발행인(매체정보 미완성 신문)
  O: ['authenticated', uid(13)],  // 플랫폼 운영자(ops)
  Y1: ['authenticated', uid(14)], Y2: ['authenticated', uid(15)], Y3: ['authenticated', uid(16)], // B 한도 시험용
};
async function become(actor) {
  const a = actors[actor];
  if (!a) throw new Error(`unknown actor ${actor}`);
  await db.exec(`reset role;
    select set_config('request.jwt.claim.role', '${a[0]}', false);
    select set_config('request.jwt.claim.sub', '${a[1]}', false);
    set role ${a[0]};`);
}

const text = read(`${mono}/tests/rls_smoke.sql`).replaceAll('@C@', C).replaceAll('@N@', N);
const setup = text.slice(text.indexOf('-- SETUP'), text.indexOf('-- END SETUP'));
try { await db.exec('reset role;' + setup); }
catch (e) { console.log(`SETUP FAIL: ${e.message}`); process.exit(1); }

const lines = text.slice(text.indexOf('-- END SETUP')).split('\n');
let pass = 0, fail = 0;
const takeStatement = (i) => {
  const buf = [];
  while (i < lines.length) {
    const l = lines[i++];
    if (!l.trim() || (l.startsWith('--') && buf.length === 0)) continue;
    buf.push(l);
    if (l.trimEnd().endsWith(';')) break;
  }
  return [buf.join('\n'), i];
};
let current = 'none';
for (let i = 0; i < lines.length; ) {
  const line = lines[i++];
  let m;
  if ((m = line.match(/^-- AS (\S+)/))) { current = m[1]; await become(m[1]); continue; }
  if (line.startsWith('-- RUN')) {
    const [sql, next] = takeStatement(i); i = next;
    try { await db.query(sql); } catch (e) { console.log(`RUN FAIL (${current}): ${sql}\n   ${e.code ?? ''} ${e.message}`); fail++; }
    continue;
  }
  if ((m = line.match(/^-- TEST (.+?) \| expect=(\S+)/))) {
    const [name, expect] = [m[1], m[2]];
    const [sql, next] = takeStatement(i); i = next;
    let got;
    try { const r = await db.query(sql); got = { rows: r.rows.length }; }
    catch (e) { got = { code: e.code, msg: e.message }; }
    let ok;
    if (expect === 'ok') ok = !got.code;
    else if (expect.startsWith('rows:')) ok = !got.code && got.rows === Number(expect.slice(5));
    else if (expect.startsWith('sqlstate:')) ok = got.code === expect.slice(9);
    if (ok) { pass++; if (verbose) console.log(`ok   ${name}`); }
    else { fail++; console.log(`FAIL ${name} (${current})\n   expect=${expect} got=${got.code ? `sqlstate:${got.code} ${got.msg}` : `rows:${got.rows}`}`); }
  }
}
console.log(`[${target}] 결과: PASS=${pass} FAIL=${fail}`);
process.exit(fail ? 1 : 0);
