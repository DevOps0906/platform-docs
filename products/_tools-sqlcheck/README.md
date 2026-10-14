# _tools-sqlcheck — SQL 적용 검사 도구 (PGlite)

Supabase 없이 SQL 마이그레이션이 오류 없이 적용되는지 확인하는 도구입니다. PGlite(브라우저·Node용 PostgreSQL)에 `prelude.sql`(Supabase 기본 역할·auth 스키마 흉내)을 먼저 깔고 파일을 순서대로 적용합니다.

```bash
cd products/_tools-sqlcheck
npm ci
# 통합 DB(모듈러): 코어 → seed → 제품 조각
node check.mjs --vector mod ../_supabase-modular/migrations/000*.sql ../_supabase-modular/seed.sql ../_supabase-modular/migrations/2300_docs.sql
# 제품 모놀리스
node check.mjs --vector mono ../nomad-docs/supabase/monolith/migrations/*.sql ../nomad-docs/supabase/monolith/seed.sql
```

`--vector`는 pgvector가 필요한 SQL(0008_core_ai 이후)을 검사할 때 씁니다. 결과는 파일마다 `OK` 또는 오류 위치를 출력합니다. RLS(권한) 판정은 하지 않으며, 그건 각 제품의 RLS 스모크 테스트가 맡습니다.
