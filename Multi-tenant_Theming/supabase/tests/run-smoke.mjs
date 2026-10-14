// run-smoke.mjs — Multi-tenant Theming RLS/권한 스모크 러너 (PGlite, Supabase 없이 실행)
//
// 사용: (저장소 루트에서)
//   cd products/_tools-sqlcheck && npm ci && cd ../..
//   node Multi-tenant_Theming/supabase/tests/run-smoke.mjs --target mod    # 통합 DB: core 0000~0009 + seed + 0011
//   node Multi-tenant_Theming/supabase/tests/run-smoke.mjs --target mono   # 모놀리스: MONOLITH_CORE_LITE + 0011(core.→public.)
//
// 테스트 파일 형식은 제품 rls_smoke.sql 과 같다:
//   -- SETUP ... -- END SETUP           관리 세션으로 한 번에 실행
//   -- AS <service|anon|A|M|B|C>        이후 문장의 역할 전환
//   -- RUN                              다음 문장을 기대값 없이 실행
//   -- TEST <이름> | expect=<rows:N | ok | sqlstate:CODE>
import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..');
const tools = join(root, 'products', '_tools-sqlcheck');
const target = process.argv.includes('--target') ? process.argv[process.argv.indexOf('--target') + 1] : 'mod';
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
const theming = readFileSync(join(here, '..', '0011_core_tenant_theming.sql'), 'utf8');
const files = target === 'mod'
  ? [
      ...readdirSync(join(root, 'products/_supabase-modular/migrations')).filter((f) => /^000\d_/.test(f)).sort()
        .map((f) => ['core ' + f, readFileSync(join(root, 'products/_supabase-modular/migrations', f), 'utf8')]),
      ['seed.sql', readFileSync(join(root, 'products/_supabase-modular/seed.sql'), 'utf8')],
      ['0011_core_tenant_theming.sql', theming],
    ]
  : [
      ['MONOLITH_CORE_LITE.sql', readFileSync(join(root, 'products/_platform-core/MONOLITH_CORE_LITE.sql'), 'utf8')],
      ['0011 (core.→public.)', theming.replace(/core\./g, 'public.')],
    ];

await db.exec(readFileSync(join(tools, 'prelude.sql'), 'utf8'));
for (const [name, sql] of files) {
  try { await db.exec(sql.replace(stubRe, '-- stubbed $1;')); }
  catch (e) { console.log(`APPLY FAIL ${name}: ${e.message}`); process.exit(1); }
}

const actors = {
  service: ['service_role', ''],
  anon: ['anon', ''],
  A: ['authenticated', 'aaaaaaaa-0000-4000-8000-000000000001'],
  B: ['authenticated', 'bbbbbbbb-0000-4000-8000-000000000002'],
  C: ['authenticated', 'cccccccc-0000-4000-8000-000000000003'],
  M: ['authenticated', 'dddddddd-0000-4000-8000-000000000004'],
};
async function become(actor) {
  const [role, sub] = actors[actor] ?? (() => { throw new Error(`unknown actor ${actor}`); })();
  await db.exec(`reset role;
    select set_config('request.jwt.claim.role', '${role}', false);
    select set_config('request.jwt.claim.sub', '${sub}', false);
    set role ${role};`);
}

const text = readFileSync(join(here, 'tenant_theming_smoke.sql'), 'utf8').replaceAll('@C@', C);
const setup = text.slice(text.indexOf('-- SETUP'), text.indexOf('-- END SETUP'));
await db.exec('reset role;' + setup);

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
for (let i = 0; i < lines.length; ) {
  const line = lines[i++];
  let m;
  if ((m = line.match(/^-- AS (\S+)/))) { await become(m[1]); continue; }
  if (line.startsWith('-- RUN')) {
    const [sql, next] = takeStatement(i); i = next;
    try { await db.query(sql); } catch (e) { console.log(`RUN FAIL: ${sql}\n   ${e.message}`); fail++; }
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
    if (ok) pass++;
    else { fail++; console.log(`FAIL ${name}\n   expect=${expect} got=${got.code ? `sqlstate:${got.code} ${got.msg}` : `rows:${got.rows}`}`); }
  }
}
console.log(`[${target}] 결과: PASS=${pass} FAIL=${fail}`);
process.exit(fail ? 1 : 0);
