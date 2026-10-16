"""book-trailer 문서 묶음을 읽기 좋은 PDF로 만든다.

usage: python3 -I build_pdf.py <repo_root> <out_dir>
- 통합본 1개(표지, 문서 목록과 쪽 번호, 책갈피) + 문서별 PDF
- 본문 Noto Sans CJK KR, 제목 Noto Serif CJK KR, 코드 Noto Sans Mono CJK KR
- 열이 8개 이상인 표가 있는 문서는 가로 A4
"""
import html
import io
import os
import re
import sys

import markdown
from playwright.sync_api import sync_playwright
from pypdf import PdfReader

ROOT, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

PARTS = [
    ('1부. 기획서', 'products/book-trailer', [
        ('README.md', '제품 개요'),
        ('01_PRD.md', '요구사항정의서'),
        ('02_ARCHITECTURE.md', '아키텍처설계서'),
        ('03_SCREENS_UX.md', '화면설계서'),
        ('04_API.md', '인터페이스설계서'),
        ('05_DATA_MODEL.md', '데이터설계서'),
        ('06_AGENT_PLAN.md', '작업 계획'),
        ('07_SOURCE_MIGRATION.md', '원본 이식 계획'),
        ('08_DESIGN_SYSTEM.md', '디자인시스템'),
        ('CLAUDE.md', '개발 에이전트 지침'),
    ]),
    ('2부. 가격과 개발 전 검증', 'Price_Plans/book-trailer', [
        ('README.md', '폴더 안내'),
        ('PRICE_PLAN.md', '가격 플랜'),
        ('01_VALIDATION_PLAN.md', '린 검증 계획'),
        ('02_KMONG_LISTING.md', '크몽 상품 원고'),
        ('03_MANUAL_PRODUCTION_SOP.md', '수동 제작 절차'),
        ('04_INTAKE_AND_INTERVIEW.md', '요청서·인터뷰'),
    ]),
    ('3부. 개발서', 'develop/book-trailer', [
        ('README.md', '개발 묶음 안내'),
        ('book-trailer_develop.md', '개발 방법 안내서'),
        ('../../develop_V2/book-trailer/book-trailer_develop_v2.md', '공용모듈 적용판(V2)'),
    ]),
]

CSS = r'''
@page { size: A4; margin: 18mm 15mm 18mm 15mm; }
@page wide { size: A4 landscape; margin: 14mm 14mm 16mm 14mm; }
@page cover { size: A4; margin: 0; }
:root { --ink:#1A1C21; --sub:#5E6470; --paper:#EEF0F2; --line:#D3D7DD; --hl:#F5D547; --stage:#202227; }
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: 'Noto Sans CJK KR', sans-serif; color: var(--ink); font-size: 9.6pt; line-height: 1.62;
       word-break: keep-all; overflow-wrap: break-word; margin: 0; }
h1, h2, h3, h4 { font-family: 'Noto Serif CJK KR', serif; line-height: 1.35; break-after: avoid; page-break-after: avoid; }
h1 { font-size: 20pt; font-weight: 900; margin: 0 0 4mm; padding-bottom: 3mm; border-bottom: 1.5pt solid var(--ink); }
h2 { font-size: 13.5pt; font-weight: 700; margin: 8mm 0 3mm; }
h2 span.num, h2 { }
h2::after { content: ''; display: block; width: 18mm; height: 2.2pt; background: var(--hl); margin-top: 1.5mm; }
h3 { font-size: 11pt; font-weight: 700; margin: 5mm 0 2mm; color: #2B2E35; }
h4 { font-size: 10pt; margin: 4mm 0 1.5mm; }
p { margin: 0 0 2.4mm; }
ul, ol { margin: 0 0 2.6mm; padding-left: 5mm; }
li { margin: 0.6mm 0; }
blockquote { margin: 3mm 0; padding: 3mm 4mm; background: #F6F7F8; border-left: 2.5pt solid var(--hl); color: #30333A; }
blockquote p:last-child { margin-bottom: 0; }
code { font-family: 'Noto Sans Mono CJK KR', monospace; font-size: 0.86em; background: #EEF0F2; padding: 0.2mm 1mm;
       border-radius: 1mm; overflow-wrap: anywhere; word-break: normal; }
pre { font-family: 'Noto Sans Mono CJK KR', monospace; font-size: 7.6pt; line-height: 1.45; background: #F4F5F7;
      border: 0.6pt solid var(--line); border-radius: 1.5mm; padding: 3mm 3.5mm; white-space: pre-wrap;
      word-break: break-all; margin: 2mm 0 3.5mm; break-inside: auto; }
pre code { background: none; padding: 0; font-size: inherit; }
table { width: 100%; border-collapse: collapse; margin: 2mm 0 4mm; font-size: 8.1pt; line-height: 1.45; }
thead { display: table-header-group; }
th { background: var(--stage); color: #fff; font-weight: 700; text-align: left; padding: 1.6mm 2mm; vertical-align: bottom; }
td { padding: 1.5mm 2mm; border-bottom: 0.5pt solid var(--line); vertical-align: top; overflow-wrap: break-word; }
td.nw, th.nw { white-space: nowrap; }
tr { break-inside: avoid; page-break-inside: avoid; }
tbody tr:nth-child(even) td { background: #F7F8F9; }
td code, th code { font-size: 0.92em; }
section.wide table { font-size: 7.4pt; }
section.wide td, section.wide th { padding: 1.2mm 1.6mm; }
a { color: inherit; text-decoration: none; border-bottom: 0.5pt solid #9AA0AA; }
span.ref { color: inherit; }
hr { border: 0; border-top: 0.6pt solid var(--line); margin: 5mm 0; }
section.doc { break-before: page; page-break-before: always; }
section.first { break-before: auto; page-break-before: auto; }
section.wide { page: wide; }
.doc-label { font-size: 8pt; letter-spacing: 0.08em; color: var(--sub); margin-bottom: 1.5mm; }
.doc-label b { background: var(--hl); color: var(--ink); padding: 0.3mm 1.6mm; margin-right: 2mm; font-weight: 700; }
.doc-path { font-family: 'Noto Sans Mono CJK KR', monospace; font-size: 7.4pt; color: var(--sub); margin: -2mm 0 5mm; }
/* 표지 */
section.cover { page: cover; height: 297mm; background: var(--stage); color: #fff; position: relative; padding: 32mm 22mm; }
.cover .band { position: absolute; left: 0; right: 0; top: 118mm; height: 16mm; background: var(--hl); }
.cover .kicker { font-size: 10pt; letter-spacing: 0.24em; color: #C9CDD4; }
.cover h1.ct { font-family: 'Noto Serif CJK KR', serif; font-size: 36pt; font-weight: 900; border: 0; color: #fff; margin: 8mm 0 4mm; padding: 0; line-height: 1.2; }
.cover .sub { font-size: 13pt; color: #E3E6EA; max-width: 150mm; line-height: 1.6; }
.cover .meta { position: absolute; left: 22mm; bottom: 26mm; font-size: 9pt; color: #C9CDD4; line-height: 1.8; }
/* 목차 */
section.toc { break-before: page; }
.toc h1 { margin-bottom: 6mm; }
.toc .part { font-family: 'Noto Serif CJK KR', serif; font-weight: 700; font-size: 11.5pt; margin: 6mm 0 2mm; padding-bottom: 1mm; border-bottom: 0.8pt solid var(--ink); }
.toc .row { display: flex; align-items: baseline; font-size: 10pt; padding: 1.4mm 0; border-bottom: 0.4pt dotted #B9BEC6; }
.toc .row .t { flex: 1; }
.toc .row .t small { color: var(--sub); margin-left: 2mm; font-size: 8pt; font-family: 'Noto Sans Mono CJK KR', monospace; }
.toc .row .p { width: 14mm; text-align: right; font-variant-numeric: tabular-nums; }
.toc .note { color: var(--sub); font-size: 8.5pt; margin-top: 6mm; line-height: 1.6; }
'''

HEADER = ('<div style="font-family:\'Noto Sans CJK KR\';font-size:7pt;color:#8A9099;width:100%;padding:0 15mm;'
          'display:flex;justify-content:space-between;"><span>NOMAD Book Trailer · 기획·개발 문서</span>'
          '<span>{title}</span></div>')
FOOTER = ('<div style="font-family:\'Noto Sans CJK KR\';font-size:7.5pt;color:#8A9099;width:100%;text-align:center;">'
          '<span class="pageNumber"></span> / <span class="totalPages"></span></div>')


def max_cols(md_text):
    best, in_code = 0, False
    for line in md_text.split('\n'):
        if line.startswith('```'):
            in_code = not in_code
            continue
        if not in_code and line.startswith('|'):
            best = max(best, len(re.split(r'(?<!\\)\|', line)) - 2)
    return best


def md_to_html(md_text, prefix):
    md = markdown.Markdown(extensions=['tables', 'fenced_code', 'sane_lists', 'toc'],
                           extension_configs={'toc': {'slugify': lambda v, s: prefix + '-' + re.sub(r'[^\w가-힣-]+', '-', v).strip('-')}})
    out = md.convert(md_text)
    # 상대 링크는 묶음 안에서 열리지 않으므로 글자만 남긴다. 외부 링크(http)는 유지.
    out = re.sub(r'<a href="(?!https?:)[^"]*">(.*?)</a>', r'<span class="ref">\1</span>', out, flags=re.S)
    # 짧은 칸(ID, 모델, 우선순위 등)은 줄바꿈하지 않는다.
    def nw(m):
        tag, attrs, inner = m.group(1), m.group(2) or '', m.group(3)
        txt = html.unescape(re.sub('<[^>]+>', '', inner)).strip()
        if 0 < len(txt) <= 12 and txt.count(' ') <= 1:
            return f'<{tag}{attrs} class="nw">{inner}</{tag}>'
        return m.group(0)
    out = re.sub(r'<(td|th)(\s[^>]*)?>(.*?)</\1>', nw, out, flags=re.S)
    return out


def doc_section(path, label, part_no, idx):
    text = io.open(path, encoding='utf-8').read()
    wide = max_cols(text) >= 8
    body = md_to_html(text, f'd{part_no}-{idx}')
    m = re.search(r'<h1[^>]*>(.*?)</h1>', body, re.S)
    title = re.sub('<[^>]+>', '', m.group(1)) if m else label
    rel = os.path.relpath(path, ROOT)
    head = f'<div class="doc-label"><b>{part_no}-{idx}</b>{html.escape(label)}</div>'
    body = body.replace(m.group(0), head + m.group(0) + f'<div class="doc-path">{html.escape(rel)}</div>', 1) if m else head + body
    cls = 'doc wide' if wide else 'doc'
    return f'<section class="{cls}">{body}</section>', html.unescape(title), wide


def page_html(sections_html, title):
    return (f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>{html.escape(title)}</title>'
            f'<style>{CSS}</style></head><body>{sections_html}</body></html>')


def render(pw_page, html_text, out_path, header_title):
    pw_page.set_content(html_text, wait_until='load')
    pw_page.evaluate('document.fonts.ready')
    pw_page.pdf(path=out_path, prefer_css_page_size=True, print_background=True, display_header_footer=True,
                header_template=HEADER.format(title=html.escape(header_title)), footer_template=FOOTER,
                margin={'top': '18mm', 'bottom': '18mm', 'left': '15mm', 'right': '15mm'}, outline=True, tagged=True)


def main():
    docs = []  # (part title, part_no, idx, label, path, section html, title, wide)
    for pno, (ptitle, base, files) in enumerate(PARTS, 1):
        for i, (f, label) in enumerate(files, 1):
            path = os.path.normpath(os.path.join(ROOT, base, f))
            sec, title, wide = doc_section(path, label, pno, i)
            docs.append((ptitle, pno, i, label, path, sec, title, wide))

    cover = ('<section class="cover"><div class="band"></div><div class="kicker">NOMAD AI FACTORY · 디지털노마드연구소</div>'
             '<h1 class="ct">NOMAD Book Trailer</h1><div class="sub">원고를 넣으면 훅 브리프, 장르 문법 스토리보드, 규격별 트레일러 렌더, '
             '구매 링크 측정까지. 북트레일러 자동화 플랫폼의 기획서·디자인시스템·가격·검증·개발서 통합본</div>'
             '<div class="meta">문서 {n}개 · 기준 저장소 DevOps0906/platform-docs (main)<br>작성 2026-10-15 ~ 2026-10-16 · 상태: 기획 완료, 개발 전 검증 단계</div></section>').format(n=len(docs))

    def toc(pages):
        rows, cur = [], None
        for (pt, pno, i, label, path, sec, title, wide) in docs:
            if pt != cur:
                rows.append(f'<div class="part">{html.escape(pt)}</div>')
                cur = pt
            p = pages.get((pno, i), '')
            rel = os.path.relpath(path, ROOT)
            rows.append(f'<div class="row"><span class="t">{pno}-{i}. {html.escape(label)}<small>{html.escape(rel)}</small></span><span class="p">{p}</span></div>')
        return ('<section class="toc"><h1>문서 목록</h1>' + ''.join(rows) +
                '<div class="note">읽는 순서 제안: 1-1 제품 개요 → 1-2 요구사항 → 2-3 린 검증 계획 → 2-4 크몽 상품 원고 → 2-5 수동 제작 절차. '
                '개발을 시작할 때는 3-2 개발 방법 안내서와 1-7 작업 계획을 함께 봅니다. PDF 책갈피에서 장·절로 바로 이동할 수 있습니다. '
                '문서 안의 파일 경로는 저장소 기준이며, 정본은 저장소의 Markdown입니다.</div></section>')

    combined_path = os.path.join(OUT, 'book-trailer_통합본.pdf')
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        body = ''.join(d[5] for d in docs)
        # 1차: 쪽 번호 찾기
        render(page, page_html(cover + toc({}) + body, 'NOMAD Book Trailer 통합본'), combined_path, '통합본')
        reader = PdfReader(combined_path)
        texts = [(pg.extract_text() or '') for pg in reader.pages]
        pages, start = {}, 2
        for (pt, pno, i, label, path, sec, title, wide) in docs:
            key = f'{pno}-{i}'
            for k in range(start, len(texts)):
                head = texts[k][:400].replace('\n', ' ')
                if key in head and label in head:
                    pages[(pno, i)] = k + 1
                    start = k + 1
                    break
        # 2차: 쪽 번호를 넣은 목차로 다시
        render(page, page_html(cover + toc(pages) + body, 'NOMAD Book Trailer 통합본'), combined_path, '통합본')
        n_combined = len(PdfReader(combined_path).pages)
        print('통합본', n_combined, '쪽, 목차 찾은 문서', len(pages), '/', len(docs))
        # 문서별 PDF
        results = []
        for (pt, pno, i, label, path, sec, title, wide) in docs:
            name = os.path.splitext(os.path.basename(path))[0]
            folder = {1: '1_기획서', 2: '2_가격과_검증', 3: '3_개발서'}[pno]
            os.makedirs(os.path.join(OUT, folder), exist_ok=True)
            out = os.path.join(OUT, folder, f'{pno}-{i:02d}_{name}.pdf')
            render(page, page_html(sec.replace('class="doc', 'class="first doc', 1), title), out, label)
            results.append((out, len(PdfReader(out).pages), wide))
        browser.close()
    for out, n, wide in results:
        print(f'{os.path.relpath(out, OUT)}\t{n}쪽' + ('\t가로' if wide else ''))


if __name__ == '__main__':
    main()
