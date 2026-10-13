// usage: node check.mjs [--vector] <label> <file1.sql> [file2.sql ...]
//   --vector : pgvector가 필요한 SQL(0008_core_ai 이후, AI 테이블)을 검사할 때 사용.
//              PGlite 0.5.x에는 pgvector가 없어서 0.3.15(별칭 pglite-vec)를 쓴다.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
let args = process.argv.slice(2);
const useVector = args[0] === '--vector';
if (useVector) args = args.slice(1);
const [label, ...files] = args;
const pkg = useVector ? 'pglite-vec' : '@electric-sql/pglite';
const { PGlite } = await import(pkg);
const { pgcrypto } = await import(`${pkg}/contrib/pgcrypto`);
const { citext } = await import(`${pkg}/contrib/citext`);
const { pg_trgm } = await import(`${pkg}/contrib/pg_trgm`);
const { uuid_ossp } = await import(`${pkg}/contrib/uuid_ossp`);
const extensions = { pgcrypto, citext, pg_trgm, uuid_ossp };
if (useVector) extensions.vector = (await import('pglite-vec/vector')).vector;
const db = new PGlite({ extensions });
let failed = 0;
try {
  await db.exec(readFileSync(join(here, 'prelude.sql'), 'utf8'));
} catch (e) { console.log(`[${label}] PRELUDE ERROR: ${e.message}`); process.exit(2); }
// pg_cron / pg_net / vault 등은 스텁 처리한다. vector는 --vector일 때만 실제로 만든다.
const stubbed = ['pg_cron', 'pg_net', 'supabase_vault', 'pg_graphql', 'pg_stat_statements', 'pgjwt', 'moddatetime', 'http', 'pgsodium'];
if (!useVector) stubbed.push('vector');
const stubRe = new RegExp(`create\\s+extension\\s+if\\s+not\\s+exists\\s+"?(${stubbed.join('|')})"?[^;]*;`, 'gi');
for (const f of files) {
  let sql = readFileSync(f, 'utf8');
  sql = sql.replace(stubRe, '-- stubbed extension $1;');
  try { await db.exec(sql); console.log(`[${label}] OK   ${f}`); }
  catch (e) { failed++; console.log(`[${label}] FAIL ${f}\n       ${e.message}${e.position ? ' (pos ' + e.position + ': ' + JSON.stringify(sql.slice(Math.max(0,e.position-80), Number(e.position)+40)) + ')' : ''}`); break; }
}
process.exit(failed ? 1 : 0);
