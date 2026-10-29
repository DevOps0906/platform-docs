"""docs/develop/<제품>/<제품>-root 묶음을 만든다(다시 실행하면 새로 만든다).

usage: python -I build_root.py <제품> [<제품> ...]      (UTF-8 환경: PYTHONUTF8=1 권장)
       python -I build_root.py --check <제품>            만든 묶음의 문서 경로만 검사

하는 일
  1) 기획서 9개, 공용 코어 문서, 디자인 가이드, 통합 분석, 해당 리뷰를 베이스의 산출물 체계(docs/file 단계 폴더)로 복사
  2) 복사본 안의 문서 경로를 새 위치로 바꾸고, 복사하지 않은 파일은 platform 절대경로로 바꾼다(원본은 읽기만 한다)
  3) docs/file/_index.md(산출물 등록부) 완성본 생성
  4) 디자인 시스템 초기 템플릿(DESIGN.md, COMPONENTS.md), 개발 위키 초기 페이지(index·log·sources), Dify 앱 설명서 생성
     (llm-wiki 스킬과 WIKI_SCHEMA.md 는 멀티에이전트 베이스가 제공하므로 묶음에 넣지 않는다)
  5) 단독 배포용 SQL을 Supabase CLI 이름(타임스탬프)으로 복사
"""
import io
import os
import re
import shutil
import sys

PLATFORM = 'D:/WorkSpace/platform'
P = PLATFORM + '/docs/products'
DESIGN = PLATFORM + '/docs/design-module/_design-guide'  # nomad-design-modules 서브모듈(2026-10-30 이전)
DEV = PLATFORM + '/docs/develop'
STAMP = '20261013'

REVIEWS = {
    'astro-ai': ['Astro_AI.md', 'FortuneDocs.md'],
    'flora-publishing': ['Flora-v2.md', 'flora.md', 'flora-publisher.md', 'SellingDocs.md'],
    'sceneflow': ['NOMAD_Shorts_Maker.md', 'Nomad-BlogStudio.md', 'Youtube_shots_Maker.md'],
    'nomad-blog': ['NOMAD_Shorts_Maker.md', 'Youtube_shots_Maker.md', 'nomad-ai-commerce.md', 'nomad-ai-factory.md'],
    'nomad-commerce': ['Nomad-AI-Factory_V.2.md', 'nomad-ai-factory.md', 'nomad-ai-commerce.md', 'sellingstudio.md'],
    'microweb-studio': ['premium-wedding-invitation.md', 'nexus-micro-web-builder.md', 'webcraft-agency-simulator.md', 'WebSite.md'],
    'admin-suite': ['ERP-Wesite.md', 'Hospital.md', 'School_Management_System.md', 'basic-master-module.md'],
    'live-poll': ['Slido_Project.md'],
    'stock-dashboard': ['Stock_Trader_nomad.md'],
    'toon-factory': ['Toon-Factory.md', 'NOMAD_Shorts_Maker.md', 'Nomad-BlogStudio.md', 'sellingstudio.md'],
    'study-note': ['study-note-organizer-codex-01.md'],
    'website-floria': ['WebSite.md'],
    'nomad-docs': ['SellingDocs.md', 'flora.md', 'FortuneDocs.md'],
    'local-news': [],  # 신규 기획(원본·리뷰 없음, 2026-10-15)
    'book-trailer': ['NOMAD_Shorts_Maker.md', 'Toon-Factory.md'],  # 신규 기획, 이식 원천 리뷰(2026-10-15)
    'arch-studio': ['FortuneDocs.md'],  # 신규 기획(설치형), 이식 원천 리뷰(2026-10-16)
}
APP_ID = {
    'astro-ai': 'astro', 'flora-publishing': 'publishing', 'sceneflow': 'video', 'nomad-blog': 'blog',
    'nomad-commerce': 'commerce', 'microweb-studio': 'microweb', 'admin-suite': 'erp, hms, sms', 'live-poll': 'poll',
    'stock-dashboard': 'stock', 'toon-factory': 'toon', 'study-note': 'notes', 'website-floria': 'site',
    'nomad-docs': 'docs', 'local-news': 'news', 'book-trailer': 'trailer', 'arch-studio': 'arch',
}

DESKTOP_UI = {'arch-studio': ('packages/ui/tokens.css', 'packages/ui/src/')}  # (토큰 파일, 컴포넌트 폴더)

PRODUCT_DOCS = [  # (원본 파일, 단계 폴더, ID, 산출물명)
    ('README.md', '01-관리', 'DOC-MGT-001', '제품 개요'),
    ('06_AGENT_PLAN.md', '01-관리', 'DOC-MGT-002', '작업 계획(WBS)'),
    ('01_PRD.md', '02-요구사항', 'DOC-REQ-001', '요구사항정의서'),
    ('02_ARCHITECTURE.md', '03-설계', 'DOC-DES-001', '아키텍처설계서'),
    ('03_SCREENS_UX.md', '03-설계', 'DOC-DES-002', '화면설계서'),
    ('04_API.md', '03-설계', 'DOC-DES-003', '인터페이스설계서'),
    ('05_DATA_MODEL.md', '03-설계', 'DOC-DES-004', '데이터설계서'),
    ('CLAUDE.md', '04-구현', 'DOC-IMP-001', '개발지침'),
    ('07_SOURCE_MIGRATION.md', '04-구현', 'DOC-IMP-002', '원본 이식 계획'),
]
# 제품 폴더에 있을 때만 옮기는 기획서(2026-10-15 book-trailer부터). 기존 ID를 바꾸지 않도록 새 번호를 쓴다.
OPTIONAL_PRODUCT_DOCS = [
    ('08_DESIGN_SYSTEM.md', '03-설계', 'DOC-DES-005', '디자인시스템설계서'),
]
CORE_DOCS = ['CORE_SPEC.md', 'SHARED_MODULES.md', 'SECURITY_BASELINE.md', 'DB_CONVENTIONS.md', 'DOC_TEMPLATE.md',
             'AI_ARCHITECTURE.md', 'LLM_WIKI.md', 'VOICE_ARCHITECTURE.md',
             'AUTH_ROADMAP.md']  # DOC-CORE-009: 인증 단계(2026-10-14, 확정 결정 22). 순서를 바꾸면 기존 DOC-CORE ID가 바뀐다
DESIGN_DOCS = ['DESIGN_PRINCIPLES.md', 'DESIGN_SYSTEM.md', 'HERO_3D.md', 'SKILLS.md', 'REFERENCES.md']
# 나중에 추가한 디자인 기준 문서. DOC-DSN-006/007은 DESIGN.md/COMPONENTS.md가 쓰므로 008부터 고정 ID를 준다(기존 ID를 바꾸지 않는다).
EXTRA_DESIGN_DOCS = [('DASHBOARD_PATTERNS.md', 'DOC-DSN-008'), ('LANDING_PERSUASION.md', 'DOC-DSN-009')]  # 009: 설득형 랜딩(2026-10-17)


def read(p):
    return io.open(p, encoding='utf-8').read()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def plan(prod):
    """(원본 절대경로, 묶음 안 상대경로, ID, 산출물명, 단계) 목록과 경로 매핑."""
    items = []
    for f, stage, did, name in PRODUCT_DOCS:
        items.append((f'{P}/{prod}/{f}', f'docs/file/{stage}/{f}', did, name, stage))
    for f, stage, did, name in OPTIONAL_PRODUCT_DOCS:
        if os.path.isfile(f'{P}/{prod}/{f}'):
            items.append((f'{P}/{prod}/{f}', f'docs/file/{stage}/{f}', did, name, stage))
    for i, f in enumerate(CORE_DOCS, 1):
        items.append((f'{P}/_platform-core/{f}', f'docs/file/03-설계/공용코어/{f}', f'DOC-CORE-{i:03d}', f'공용 코어: {f[:-3]}', '03-설계'))
    for i, f in enumerate(DESIGN_DOCS, 1):
        items.append((f'{DESIGN}/{f}', f'docs/file/03-설계/디자인/{f}', f'DOC-DSN-{i:03d}', f'디자인 기준: {f[:-3]}', '03-설계'))
    for f, did in EXTRA_DESIGN_DOCS:
        items.append((f'{DESIGN}/{f}', f'docs/file/03-설계/디자인/{f}', did, f'디자인 기준: {f[:-3]}', '03-설계'))
    # 제품 공통모듈 기획서(선택, 2026-10-15 local-news부터): products/<제품>/modules/*.md → docs/file/03-설계/모듈/
    mod_dir = f'{P}/{prod}/modules'
    if os.path.isdir(mod_dir):
        for i, f in enumerate(sorted(x for x in os.listdir(mod_dir) if x.endswith('.md')), 1):
            items.append((f'{mod_dir}/{f}', f'docs/file/03-설계/모듈/{f}', f'DOC-MOD-{i:03d}', f'공통모듈 기획: {f[:-3]}', '03-설계'))
    refs =[(f'{P}/00_MERGE_ANALYSIS.md', 'docs/reference/00_MERGE_ANALYSIS.md')]
    # 제품 조사 자료(선택): products/<제품>/research/*.md → docs/reference/research/
    res_dir = f'{P}/{prod}/research'
    if os.path.isdir(res_dir):
        for f in sorted(x for x in os.listdir(res_dir) if x.endswith('.md')):
            refs.append((f'{res_dir}/{f}', f'docs/reference/research/{f}'))
    for r in REVIEWS[prod]:
        refs.append((f'{PLATFORM}/docs/reviews/{r}', f'docs/reference/reviews/{r}'))
    mapping = {}
    for src, dst, *_ in items:
        mapping[src[len(PLATFORM) + 1:]] = dst
    for src, dst in refs:
        mapping[src[len(PLATFORM) + 1:]] = dst
    mapping[f'docs/products/{prod}/'] = 'docs/file/'
    return items, refs, mapping


# docs/Tauri, docs/develop_V2 등 묶음에 복사하지 않는 공용 가이드는 platform 절대경로로 바꾼다(2026-10-16 arch-studio부터)
REF_RE = re.compile(r'(?<![\w/.-])((?:docs/(?:products|reviews|Tauri|Capacitor|develop_V2|develop|Price_Plans|Multi-tenant_Theming|design-module)/|_platform-core/|_design-guide/)[^\s`\'"|)\]:,;<>]*)')


def rewrite(text, mapping):
    def fix(m):
        path = m.group(1)
        full = path
        if path.startswith('_platform-core/') or path.startswith('_design-guide/'):
            full = ('docs/design-module/' if path.startswith('_design-guide/') else 'docs/products/') + path
        if full in mapping:
            return mapping[full]
        for k, v in mapping.items():
            if k.endswith('/') and full.startswith(k) and full[len(k):] in ('',):
                return v
        if full.rstrip('/') + '/' in mapping and full.endswith('/'):
            return mapping[full]
        return PLATFORM + '/' + full
    return REF_RE.sub(fix, text)


def sql_sets(prod):
    base = f'{P}/{prod}/supabase/monolith'
    if prod == 'admin-suite':
        return [(f'{base}/{a}', f'supabase/{a}') for a in ('erp', 'hms', 'sms')]
    return [(base, 'supabase')]


def design_seed(sources, name, prod):
    """기획서의 "### 또는 #### <번호> <name> 초기값" 절 본문(같은 수준 이상 다음 제목 전까지)을 DESIGN.md/COMPONENTS.md 초기본으로 만든다.

    sources: [(묶음 안 경로, 본문)] 순서대로 찾는다(03_SCREENS_UX.md 먼저, 있으면 08_DESIGN_SYSTEM.md).
    """
    for path, text in sources:
        m = re.search(r'^(#{3,4}) [0-9.]+ ' + re.escape(name) + r' 초기값[^\n]*\n', text, re.M)
        if not m:
            continue
        level = len(m.group(1))
        rest = text[m.end():] + '\n' + '#' * level + ' '
        body = re.match(r'(.*?)(?=^#{1,%d} )' % level, rest, re.S | re.M).group(1)
        kind = '디자인 토큰' if name == 'DESIGN.md' else '컴포넌트·배리언트 명세'
        origin = '화면설계서 3장' if path.endswith('03_SCREENS_UX.md') else f'기획서 `{path}`'
        return (f'# {name} — {prod} {kind} (초기값: {origin}에서 복사)\n\n'
                '> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.\n'
                f'> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `{path}` 같은 이름의 "초기값" 절.\n\n'
                + body.strip() + '\n')
    return None


def headings(text):
    return [l for l in text.splitlines() if l.startswith('## ')]


def build(prod):
    out = f'{DEV}/{prod}/{prod}-root'
    if os.path.isdir(out):
        shutil.rmtree(out)
    items, refs, mapping = plan(prod)
    index_rows = []
    for src, dst, did, name, stage in items:
        write(f'{out}/{dst}', rewrite(read(src), mapping))
        index_rows.append((did, name, stage, dst))
    for src, dst in refs:
        write(f'{out}/{dst}', rewrite(read(src), mapping))

    # 디자인 시스템 초기 템플릿(DESIGN_SYSTEM.md 9절)
    # 03_SCREENS_UX.md 에 "#### ... DESIGN.md 초기값" / "#### ... COMPONENTS.md 초기값" 절이 있으면 그 내용으로 채운다(선택).
    seeds = [('docs/file/03-설계/03_SCREENS_UX.md', read(f'{P}/{prod}/03_SCREENS_UX.md'))]
    if os.path.isfile(f'{P}/{prod}/08_DESIGN_SYSTEM.md'):
        seeds.append(('docs/file/03-설계/08_DESIGN_SYSTEM.md', read(f'{P}/{prod}/08_DESIGN_SYSTEM.md')))
    write(f'{out}/docs/file/03-설계/디자인/DESIGN.md',
          design_seed(seeds, 'DESIGN.md', prod) or DESIGN_TMPL.format(prod=prod))
    write(f'{out}/docs/file/03-설계/디자인/COMPONENTS.md',
          design_seed(seeds, 'COMPONENTS.md', prod) or COMPONENTS_TMPL.format(prod=prod))
    if prod in DESKTOP_UI:  # 데스크톱 제품은 디자인 토큰·컴포넌트 정답 소스가 공유 패키지에 있다
        for f in ('DESIGN.md', 'COMPONENTS.md'):
            q = f'{out}/docs/file/03-설계/디자인/{f}'
            write(q, read(q).replace('apps/web/src/styles/tokens.css', DESKTOP_UI[prod][0])
                  .replace('apps/web/src/components/ui/', DESKTOP_UI[prod][1]))
    index_rows.append(('DOC-DSN-006', '디자인 토큰 정의(DESIGN.md)', '03-설계', 'docs/file/03-설계/디자인/DESIGN.md'))
    index_rows.append(('DOC-DSN-007', '컴포넌트·배리언트 명세(COMPONENTS.md)', '03-설계', 'docs/file/03-설계/디자인/COMPONENTS.md'))

    # SQL
    sql_rows = []
    for src_dir, dst_dir in sql_sets(prod):
        migs = sorted(f for f in os.listdir(f'{src_dir}/migrations') if f.endswith('.sql'))
        for i, f in enumerate(migs, 1):
            stem = re.sub(r'^\d+_', '', f)
            dst = f'{dst_dir}/migrations/{STAMP}{i:06d}_{stem}'
            write(f'{out}/{dst}', read(f'{src_dir}/migrations/{f}'))
            sql_rows.append((f'{src_dir}/migrations/{f}'[len(PLATFORM) + 1:], dst))
        write(f'{out}/{dst_dir}/seed.sql', read(f'{src_dir}/seed.sql'))
        sql_rows.append((f'{src_dir}/seed.sql'[len(PLATFORM) + 1:], f'{dst_dir}/seed.sql'))
        # 선택: tests/rls_smoke.sql 등(DOC_TEMPLATE.md 2.10절 '제안'). 있는 제품만 복사한다.
        if os.path.isdir(f'{src_dir}/tests'):
            for f in sorted(x for x in os.listdir(f'{src_dir}/tests') if x.endswith('.sql')):
                write(f'{out}/{dst_dir}/tests/{f}', read(f'{src_dir}/tests/{f}'))
                sql_rows.append((f'{src_dir}/tests/{f}'[len(PLATFORM) + 1:], f'{dst_dir}/tests/{f}'))

    # 산출물 등록부
    rows = '\n'.join(f'| {d} | {n} | {s.replace("-", " ", 1)} | platform 기획(2026-10-13) | 원문 확인 | 초안 | 1.0 | {p} | - |'
                     for d, n, s, p in index_rows)
    write(f'{out}/docs/file/_index.md', INDEX_TMPL.format(prod=prod, rows=rows))

    # 개발 위키 초기 페이지
    src_pages = []
    for d, n, s, p in index_rows:
        body = read(f'{out}/{p}')
        hs = '\n'.join(f'- {h[3:]}' for h in headings(body)) or '- (장 제목 없음)'
        slug = d.lower()
        write(f'{out}/docs/wiki/sources/{slug}.md', SOURCE_PAGE.format(did=d, name=n, path=p, heads=hs))
        src_pages.append(f'- [[sources/{slug}]] {d} {n}')
    write(f'{out}/docs/wiki/index.md', WIKI_INDEX.format(prod=prod, pages='\n'.join(src_pages)))
    write(f'{out}/docs/wiki/log.md', WIKI_LOG.format(prod=prod))

    # Dify 앱 설명서
    write(f'{out}/infra/dify/README.md', DIFY_TMPL.format(prod=prod, app=APP_ID[prod]))
    return out, index_rows, sql_rows


PATH_RE = re.compile(r'(?<![\w/.-])(docs/(?:file|reference|wiki)/[^\s`\'"|)\]:,;<>]+\.md)')
# 베이스(멀티에이전트 베이스 저장소)가 개발 폴더에 제공하는 파일 — 묶음에 없어도 누락으로 보지 않는다
BASE_PROVIDED = {'docs/wiki/WIKI_SCHEMA.md'}
ABS_RE = re.compile(r'(D:/WorkSpace/platform/[^\s`\'"|)\]:,;<>]+)')


def check(prod):
    out = f'{DEV}/{prod}/{prod}-root'
    missing, absmiss, n = [], [], 0
    for dp, _, fs in os.walk(out):
        for f in fs:
            if not f.endswith('.md'):
                continue
            t = read(os.path.join(dp, f))
            for m in PATH_RE.finditer(t):
                n += 1
                if m.group(1) not in BASE_PROVIDED and not os.path.exists(f'{out}/{m.group(1)}'):
                    missing.append((os.path.relpath(os.path.join(dp, f), out), m.group(1)))
            for m in ABS_RE.finditer(t):
                n += 1
                q = m.group(1).rstrip('.')
                if '<' in q or '*' in q or '~' in q:
                    continue
                if not os.path.exists(q):
                    absmiss.append((os.path.relpath(os.path.join(dp, f), out), q))
    return n, missing, absmiss


INDEX_TMPL = '''# 산출물 등록부 (docs/file/_index.md) — {prod}

> 개발·리뷰의 근거 산출물 목록. 규칙: `_shared/orchestrator-rules.md` §4. 표준 매핑: `.claude/skills/deliverable-first/references/standards-map.md`
> 출처: `D:/WorkSpace/platform/docs/products/`의 통합 기획(2026-10-13)을 `docs/develop/_shared/tools/build_root.py`로 옮겼다. 상태가 "초안"인 산출물은 착수 전 결정을 확정한 뒤 "승인"으로 바꾼다.

## 적용 표준

| 표준 | 버전 | 원문 확보 | 비고 |
|---|---|---|---|
| platform 통합 기획 규칙(DOC_TEMPLATE) | 2026-10-13 | 확보 | `docs/file/03-설계/공용코어/DOC_TEMPLATE.md` |

## 산출물

| ID | 산출물명 | 단계 | 표준 출처 | 출처 상태 | 상태 | 버전 | 경로 | 상위 ID |
|---|---|---|---|---|---|---|---|---|
{rows}

<!-- 상태: 초안 | 검토 | 승인 | 폐기.  출처 상태: 원문 확인 | 공개 요약 | 미확인 -->

## 변경 이력

| 날짜 | ID | 변경 | 사유 | 작업 |
|---|---|---|---|---|
| 2026-10-13 | 전체 | 최초 등록 | platform 통합 기획 이관 | setup 스크립트 |
'''

DESIGN_TMPL = '''# DESIGN.md — {prod} 디자인 토큰 (초기 템플릿)

> 정답 소스는 코드다: `apps/web/src/styles/tokens.css`(Tailwind CSS v4 `@theme`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 피그마 노드 ID나 외부 파일 링크를 적지 않는다.

## 1. 레퍼런스와 방향
| 항목 | 값 |
|---|---|
| 주 레퍼런스 | (DESIGN_SYSTEM.md 5장에서 선택) |
| 가져올 패턴 | |
| 가져오지 않을 것 | |

## 2. 색 토큰 (라이트 / 다크)
| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `--color-surface` | | | |
| `--color-text` | | | |
| `--color-text-muted` | | | |
| `--color-accent` | | | |
| `--color-border` | | | |

출발점: 화면설계서(`docs/file/03-설계/03_SCREENS_UX.md`) 4절 토큰 플랜.

## 3. 서체, 간격, radius, 그림자, 모션
| 토큰 | 값 | 용도 |
|---|---|---|
| `--font-display` | | |
| `--font-body` | | |
| `--radius-control` | | |
| `--spacing-*` | | |

## 4. 밀도와 다크 모드
- 밀도: 컴팩트 / 기본
- 다크 모드 전환 방식: `.dark` 또는 `data-theme` 중 하나
'''

COMPONENTS_TMPL = '''# COMPONENTS.md — {prod} 컴포넌트·배리언트 명세 (초기 템플릿)

> 정답 소스는 코드 컴포넌트(`apps/web/src/components/ui/`, shadcn/ui + Tailwind CSS v4 토큰). 작업 지시는 `DESIGN_SYSTEM.md` 8장 템플릿으로 컴포넌트 1개씩 맡긴다.

| 컴포넌트 | 크기 배리언트 | 종류 배리언트 | 상태 | 토큰 | 미리보기 확인(라이트/다크) |
|---|---|---|---|---|---|
| Button | sm/md/lg | primary/secondary/ghost/danger | 기본·호버·포커스·비활성·로딩 | | |
| Input | | | 기본·포커스·오류·비활성 | | |
| Select | | | | | |
| Dialog | | | | | |
| Table | 컴팩트/기본 | | 빈 상태·로딩·오류 | | |
| Badge | | 상태별 | | | |
| ChatThread(AI 채팅) | | | 스트리밍·출처·오류 | | |
| VoiceButton(음성) | | | 녹음 중·권한 거부 | | |
'''

SOURCE_PAGE = '''# {did} {name}

산출물 요약 페이지(초기 페이지, 기계 생성). 정본은 산출물이다: `{path}`

## 장 구성
{heads}

## 출처
- `{path}`

## 관련
- [[index]]
'''

WIKI_INDEX = '''# {prod} 개발 위키 목차

규칙: `docs/wiki/WIKI_SCHEMA.md`, 스킬: `.claude/skills/llm-wiki/SKILL.md`. 정본은 `docs/file/`의 산출물이며, 이 위키는 요약이다.

## 산출물 요약 (sources)
{pages}

## 모듈 (modules)
- (개발이 시작되면 task 완료 시 추가)

## 결정 (decisions)
- (task의 [DECISION]을 옮겨 적는다)

## 용어 (concepts)
- (도메인 용어)
'''

WIKI_LOG = '''# {prod} 개발 위키 변경 기록 (append-only)

| 날짜 | task | 페이지 | 변경 |
|---|---|---|---|
| 2026-10-13 | setup | index, sources/* | 산출물 요약 초기 페이지 생성(build_root.py) |
'''

DIFY_TMPL = '''# {prod} Dify 채팅 앱 설정 설명서

공용 Dify 설치·운영은 `D:/WorkSpace/platform/docs/develop/_shared/dify/README.md`, 설계는 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md` 2~3장을 따릅니다. 이 폴더에는 이 제품 앱의 설정 설명과, Dify에서 앱을 만든 뒤 내보낸 DSL 파일(`app.yml`)을 둡니다.

| 항목 | 값 |
|---|---|
| 앱 종류 | Chatflow (제품당 1개) |
| 앱 id(platform) | `{app}` |
| 입력 변수 | `platform_conversation_id`(텍스트, 필수). Dify `user`는 Next.js가 만든 `dify_user` |
| 답변 생성 | HTTP 요청 노드 → `POST {{FASTAPI}}/tools/answer`, 헤더 `Authorization: Bearer {{DIFY_INTERNAL_API_KEY}}`, 본문에 `platform_conversation_id`, `sys.user`, 사용자 질문 |
| 보조 LLM 노드 | 모델 공급자 = 이 제품 FastAPI 라우터(OpenAI 호환). 조직 데이터 금지 |
| 외부 지식 API | 제품 공통 지식만(조직 데이터 금지) |
| 금지 | Dify 내장 지식베이스, 서명 토큰이나 개인정보를 입력 변수로 넘기는 것 |
| 내보내기 | 앱을 바꿀 때마다 DSL을 내보내 `infra/dify/app.yml`로 커밋합니다(키 값 제외) |

기능별 그래프와 라우팅 기본값은 `docs/file/03-설계/02_ARCHITECTURE.md`를 따릅니다.
'''


if __name__ == '__main__':
    args = sys.argv[1:]
    only_check = args[:1] == ['--check']
    if only_check:
        args = args[1:]
    for prod in args:
        if prod not in REVIEWS:
            raise SystemExit(f'알 수 없는 제품: {prod}')
        if not only_check:
            out, rows, sqls = build(prod)
            print(f'{prod}: 산출물 {len(rows)}개, SQL {len(sqls)}개 -> {out}')
        n, missing, absmiss = check(prod)
        print(f'{prod}: 경로 참조 {n}개, 묶음 안 누락 {len(missing)}, 절대경로 누락 {len(absmiss)}')
        for x in (missing + absmiss)[:15]:
            print('   ', x)
