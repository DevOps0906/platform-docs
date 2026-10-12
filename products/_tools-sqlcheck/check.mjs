// usage: node check.mjs <label> <file1.sql> [file2.sql ...]
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { citext } from '@electric-sql/pglite/contrib/citext';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { uuid_ossp } from '@electric-sql/pglite/contrib/uuid_ossp';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const [label, ...files] = process.argv.slice(2);
const db = new PGlite({ extensions: { pgcrypto, citext, pg_trgm, uuid_ossp } });
let failed = 0;
try {
  await db.exec(readFileSync(join(here, 'prelude.sql'), 'utf8'));
} catch (e) { console.log(`[${label}] PRELUDE ERROR: ${e.message}`); process.exit(2); }
for (const f of files) {
  let sql = readFileSync(f, 'utf8');
  // pg_cron / pg_net / vault extension creation is stubbed
  sql = sql.replace(/create\s+extension\s+if\s+not\s+exists\s+"?(pg_cron|pg_net|supabase_vault|pg_graphql|pg_stat_statements|pgjwt|vector|moddatetime|http|pgsodium)"?[^;]*;/gi, '-- stubbed extension $1;');
  try { await db.exec(sql); console.log(`[${label}] OK   ${f}`); }
  catch (e) { failed++; console.log(`[${label}] FAIL ${f}\n       ${e.message}${e.position ? ' (pos ' + e.position + ': ' + JSON.stringify(sql.slice(Math.max(0,e.position-80), Number(e.position)+40)) + ')' : ''}`); break; }
}
process.exit(failed ? 1 : 0);
