#!/usr/bin/env python3
"""2500_news.sql (modular) -> 0003_local_news_domain.sql (monolith), DB_CONVENTIONS 12장 규칙.
(a) create schema 블록·core.apps 등록 제거 (b) core. -> public. (c) news. -> public.
(d) 테이블 권한은 조각 안의 revoke all ... from public, anon, authenticated 가 이미 처리
(e) @@MODULAR_ONLY 구간 제거(플랜·AI 라우팅은 모놀리스 seed.sql, 함수 목록 누락 검사는 public 에 코어 함수가 있어 제외)
(f) 함수 권한 루프의 nspname 'news' -> 'public'(이름 목록으로만 회수하므로 코어 함수는 건드리지 않는다)
"""
import re, sys

src_path, dst_path = sys.argv[1], sys.argv[2]
s = open(src_path, encoding='utf8').read()

# (e) modular-only blocks
s, n = re.subn(r'[ \t]*-- @@MODULAR_ONLY_BEGIN.*?-- @@MODULAR_ONLY_END[^\n]*\n', '', s, flags=re.S)
assert n == 2, n

# (a) schema bootstrap block
block = re.search(r'create schema if not exists news;.*?alter default privileges in schema news revoke execute on functions from public;\n', s, re.S)
assert block
s = s.replace(block.group(0), '-- (모놀리스) 스키마 생성·기본 권한 블록 제거: 객체는 public 에 만든다. 기본 권한 회수는 0001_core_lite.sql SECTION 0·10.\n')
app = re.search(r"insert into core\.apps \(id, name, schema_name, signup_policy, status\) values \('news'[^\n]*\n[^\n]*\n", s)
assert app
s = s.replace(app.group(0), "-- (모놀리스) apps 행은 seed.sql 이 넣는다(schema_name = 'public').\n")

# (f) privilege loop namespace
assert s.count("n.nspname = 'news'") == 1
s = s.replace("n.nspname = 'news'", "n.nspname = 'public'")

# (b)(c) schema prefixes
s = re.sub(r'\bcore\.', 'public.', s)
s = re.sub(r'\bnews\.', 'public.', s)

header = """-- =====================================================================
-- local-news 모놀리스 0003_local_news_domain.sql
-- 원본: docs/products/_supabase-modular/migrations/2500_news.sql 의 변환본(직접 수정 금지. 원본을 고친 뒤 다시 변환한다).
-- 변환: DB_CONVENTIONS.md 12장 + products/local-news/05_DATA_MODEL.md 8장
--   python3 -I docs/products/local-news/supabase/tools/to_monolith.py docs/products/_supabase-modular/migrations/2500_news.sql docs/products/local-news/supabase/monolith/migrations/0003_local_news_domain.sql
--   (a) create schema·기본 권한·core.apps 등록 제거 (b) core. -> public. (c) news. -> public.
--   (d) 플랜·AI 라우팅 기본값은 seed.sql (e) 함수 권한은 이름 목록으로만 회수(코어 함수 권한 보존)
-- 선행: 0001_core_lite.sql(SECTION 6-A, 9 제거본), 0002_tenant_theming.sql
-- =====================================================================

"""
open(dst_path, 'w', encoding='utf8').write(header + s)
print('ok', dst_path)
