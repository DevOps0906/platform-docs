# -*- coding: utf-8 -*-
"""제품 기획서(products/<제품>/*.md)를 제품별 통합본 PDF 1개로 만든다.

usage: python -X utf8 product_pdf.py <저장소 루트> <출력 폴더> <제품> [<제품> ...]
       python -X utf8 product_pdf.py <저장소 루트> <출력 폴더> --all      (book-trailer 제외: 전용 도구 book_trailer_pdf.py)
       python -X utf8 product_pdf.py <저장소 루트> <PDF 레포 루트> --common   공용 문서 2종(통합 결정 분석, 공용 코어 규격) -> <레포 루트>/common-docs/
출력: <출력 폴더>/<제품>/<제품>_기획서_통합본.pdf  (표지, 문서 목록과 쪽 번호, 장·절 책갈피)
변환기: md2pdf.py의 convert() (reportlab, 맑은 고딕). 정본은 md이며 PDF는 사본이다.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import md2pdf as M
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, PageBreak, Flowable, Table, TableStyle

ORDER = ['README.md', '01_PRD.md', '02_ARCHITECTURE.md', '03_SCREENS_UX.md', '04_API.md', '05_DATA_MODEL.md',
         '06_AGENT_PLAN.md', '07_SOURCE_MIGRATION.md']
LABEL = {'README.md': '제품 개요', '01_PRD.md': '요구사항정의서', '02_ARCHITECTURE.md': '아키텍처설계서',
         '03_SCREENS_UX.md': '화면설계서', '04_API.md': '인터페이스설계서', '05_DATA_MODEL.md': '데이터설계서',
         '06_AGENT_PLAN.md': '작업 계획', '07_SOURCE_MIGRATION.md': '원본 이식 계획', 'CLAUDE.md': '개발 에이전트 지침'}


class Mark(Flowable):
    """문서 시작 표식: 시작 쪽 기록 + 책갈피."""
    def __init__(self, key, title, starts):
        super().__init__(); self.key, self.title, self.starts = key, title, starts
        self.width = self.height = 0
    def draw(self):
        c = self.canv
        self.starts[self.key] = c.getPageNumber()
        c.bookmarkPage(self.key); c.addOutlineEntry(self.title, self.key, level=0, closed=True)
        self.starts['_last'] = 0


def docs_of(root, prod):
    d = os.path.join(root, 'products', prod)
    names = [f for f in os.listdir(d) if f.endswith('.md')]
    mid = sorted(f for f in names if f not in ORDER and f != 'CLAUDE.md')
    return [f for f in ORDER if f in names] + mid + (['CLAUDE.md'] if 'CLAUDE.md' in names else [])


def title_of(path, fallback):
    for l in io.open(path, encoding='utf-8'):
        if l.startswith('# '):
            return l[2:].strip()[:120]
    return fallback


def build(root, prod, out_pdf, items=None, subtitle='기획서 통합본', note=None, foot='기획서'):
    """items: [(md 절대경로, 표시 이름, 설명)]. 없으면 products/<제품>/ 문서 목록."""
    if items is None:
        items = [(os.path.join(root, 'products', prod, f), f, LABEL.get(f, f[:-3])) for f in docs_of(root, prod)]
    if note is None:
        note = '정본은 platform-docs 저장소의 products/%s/ 의 Markdown 문서이며, 이 PDF는 인쇄·공유용 사본입니다.' % prod
    starts = {}
    for final in (False, True):
        starts.pop('_last', None)
        story = []
        cover = [Spacer(1, 70 * mm),
                 Paragraph(prod, ParagraphStyle('ct', fontName='MalgunB', fontSize=30, leading=38, textColor=M.ACCENT)),
                 Spacer(1, 4 * mm), Paragraph(subtitle, ParagraphStyle('cs', fontName='Malgun', fontSize=14, leading=20)),
                 Spacer(1, 8 * mm),
                 Paragraph(note, M.S['body']), PageBreak()]
        # 목차 칸은 Paragraph로 감싸서, 내용이 칸 폭을 넘으면 같은 칸 안에서 다음 줄로 내려가게 한다(쪽 번호 칸과 겹침 방지)
        cell = ParagraphStyle('tc', fontName='Malgun', fontSize=9.5, leading=13)
        head = ParagraphStyle('th', parent=cell, fontName='MalgunB')
        pg = ParagraphStyle('tp', parent=cell, alignment=2)
        rows = [[Paragraph('문서', head), Paragraph('내용', head), Paragraph('쪽', ParagraphStyle('thp', parent=head, alignment=2))]]
        for _, key, label in items:
            rows.append([Paragraph(M.esc(key), cell), Paragraph(M.esc(label), cell), Paragraph(str(starts.get(key, '')) if final else '', pg)])
        toc = Table(rows, colWidths=[62 * mm, 90 * mm, 22 * mm], repeatRows=1)
        toc.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), M.LIGHT), ('LINEBELOW', (0, 0), (-1, -1), 0.3, colors.HexColor('#CCCCCC')),
                                 ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                                 ('LEFTPADDING', (0, 0), (-1, -1), 4), ('RIGHTPADDING', (0, 0), (-1, -1), 6)]))
        story += cover + [Paragraph('문서 목록', M.S['h2']), toc, PageBreak()]
        for k, (path, key, label) in enumerate(items):
            md = io.open(path, encoding='utf-8').read()
            story.append(Mark(key, '%s  %s' % (key[:-3] if key.endswith('.md') else key, label), starts))
            story += M.convert(md)
            if k < len(items) - 1:
                story.append(PageBreak())

        def footer(canvas, doc):
            canvas.saveState(); canvas.setFont('Malgun', 8); canvas.setFillColor(colors.HexColor('#888888'))
            canvas.drawRightString(A4[0] - 18 * mm, 12 * mm, str(doc.page)); canvas.drawString(18 * mm, 12 * mm, prod + ' ' + foot)
            canvas.restoreState()

        class Doc(BaseDocTemplate):
            def afterFlowable(self, fl):
                if isinstance(fl, Paragraph) and fl.style.name in ('title', 'h2') and final and '_last' in starts:
                    lvl = min(1 if fl.style.name == 'title' else 2, starts['_last'] + 1)
                    key = 'h%d_%d' % (self.page, id(fl))
                    self.canv.bookmarkPage(key)
                    self.canv.addOutlineEntry(fl.getPlainText()[:80], key, level=lvl, closed=True)
                    starts['_last'] = lvl
        doc = Doc(out_pdf, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=18 * mm, bottomMargin=20 * mm,
                  title=prod + ' ' + subtitle)
        doc.addPageTemplates([PageTemplate(id='p', frames=[Frame(18 * mm, 20 * mm, A4[0] - 36 * mm, A4[1] - 38 * mm, id='f')],
                                           onPage=footer)])
        doc.build(story)
    return len(items), doc.page


CORE = ['README.md', 'CORE_SPEC.md', 'SHARED_MODULES.md', 'SECURITY_BASELINE.md', 'DB_CONVENTIONS.md', 'DOC_TEMPLATE.md',
        'AI_ARCHITECTURE.md', 'VOICE_ARCHITECTURE.md', 'LLM_WIKI.md', 'AUTH_ROADMAP.md', 'COMMON_MODULES_ROADMAP.md']
MODULES = ['README.md', 'compliance.md', 'media.md', 'editorial.md', 'community.md', 'search.md', 'membership.md', 'ads.md']


def build_common(root, out):
    d = os.path.join(out, 'common-docs'); os.makedirs(d, exist_ok=True)
    P = os.path.join(root, 'products')
    note = '정본은 platform-docs 저장소 products/ 의 Markdown 문서이며, 이 PDF는 인쇄·공유용 사본입니다.'
    m = os.path.join(P, '00_MERGE_ANALYSIS.md')
    r = build(root, 'NOMAD 통합 결정 분석', os.path.join(d, '00_통합결정분석.pdf'),
              [(m, '00_MERGE_ANALYSIS.md', title_of(m, '통합 분석'))], '통합 결정 분석(확정 결정 22개 포함)', note, '')
    print('%-20s 문서 %d개, %d쪽' % ('통합결정분석', *r))
    items = []
    for f in CORE:
        pth = os.path.join(P, '_platform-core', f)
        items.append((pth, f if f != 'README.md' else 'core/README.md', title_of(pth, f[:-3])))
    for f in MODULES:
        pth = os.path.join(P, '_platform-core', 'common-modules', f)
        items.append((pth, 'common-modules/' + f, title_of(pth, f[:-3])))
    r = build(root, 'NOMAD 공용 코어 규격', os.path.join(d, '01_공용코어규격_통합본.pdf'), items, '공용 코어 규격·공용모듈 통합본', note, '')
    print('%-20s 문서 %d개, %d쪽' % ('공용코어규격', *r))


def main():
    root, out, *prods = sys.argv[1:]
    if prods == ['--common']:
        build_common(root, out)
        return
    if prods == ['--all']:
        prods = sorted(p for p in os.listdir(os.path.join(root, 'products'))
                       if not p.startswith('_') and p != 'book-trailer' and os.path.isfile(os.path.join(root, 'products', p, '01_PRD.md')))
    for p in prods:
        d = os.path.join(out, p); os.makedirs(d, exist_ok=True)
        try:
            n, pages = build(root, p, os.path.join(d, '%s_기획서_통합본.pdf' % p))
            print('%-20s 문서 %d개, %d쪽' % (p, n, pages))
        except Exception as e:
            print('%-20s 실패: %s: %s' % (p, type(e).__name__, e)); raise


if __name__ == '__main__':
    main()
