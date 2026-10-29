# -*- coding: utf-8 -*-
"""PDF 안에서 글자가 서로 겹치는 쪽을 찾는다(문서 목록 칸 침범 등).

usage: python -X utf8 pdf_overlap_check.py <PDF 또는 폴더>   (PyMuPDF 필요)  겹침 0건이면 "겹침 있는 PDF: 0"
"""
import sys, os, pymupdf
def page_overlaps(page):
    ws = page.get_text("words")  # x0,y0,x1,y1,word,block,line,wordno
    ws.sort(key=lambda w: w[1])
    bad = []
    for i, a in enumerate(ws):
        for b in ws[i+1:]:
            if b[1] >= a[3]: break          # y가 더 아래면 이후는 모두 겹치지 않음
            if (a[5], a[6]) == (b[5], b[6]): continue   # 같은 줄 안의 단어 쌍은 제외
            ix = min(a[2], b[2]) - max(a[0], b[0]); iy = min(a[3], b[3]) - max(a[1], b[1])
            if ix > 1 and iy > 1:
                small = min((a[2]-a[0])*(a[3]-a[1]), (b[2]-b[0])*(b[3]-b[1]))
                if small > 0 and ix*iy/small > 0.3: bad.append((a[4], b[4]))
    return bad
root = sys.argv[1]; tot = 0
for dp, _, fs in os.walk(root):
    if '.git' in dp: continue
    for f in sorted(fs):
        if not f.endswith('.pdf'): continue
        p = os.path.join(dp, f); d = pymupdf.open(p); pages = []
        for n, pg in enumerate(d, 1):
            o = page_overlaps(pg)
            if o: pages.append((n, len(o), o[0]))
        rel = os.path.relpath(p, root)
        if pages:
            tot += 1; print('겹침', rel, '|', len(pages), '쪽', '| 예:', pages[:3])
        d.close()
print('검사 끝, 겹침 있는 PDF:', tot)
