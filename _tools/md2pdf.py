# -*- coding: utf-8 -*-
"""
Markdown -> PDF converter with Korean font support (Malgun Gothic).
Usage: python md2pdf.py input.md output.pdf
Supports: #/##/### headings, paragraphs, - / * / 1. lists, | tables |, ``` code blocks,
**bold**, `inline code`, horizontal rules (---), > blockquotes.
"""
import sys, re, io
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import registerFontFamily
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                Preformatted, HRFlowable)

FONT_DIR = "C:/Windows/Fonts/"
pdfmetrics.registerFont(TTFont("Malgun", FONT_DIR + "malgun.ttf"))
pdfmetrics.registerFont(TTFont("MalgunB", FONT_DIR + "malgunbd.ttf"))
registerFontFamily("Malgun", normal="Malgun", bold="MalgunB", italic="Malgun", boldItalic="MalgunB")

ACCENT = colors.HexColor("#1F3A5F")
LIGHT = colors.HexColor("#EEF2F7")
CODE_BG = colors.HexColor("#F5F5F5")

S = {
    "title": ParagraphStyle("title", fontName="MalgunB", fontSize=20, leading=26, textColor=ACCENT, spaceAfter=10),
    "h2": ParagraphStyle("h2", fontName="MalgunB", fontSize=14.5, leading=19, textColor=ACCENT, spaceBefore=12, spaceAfter=6),
    "h3": ParagraphStyle("h3", fontName="MalgunB", fontSize=12, leading=16, textColor=colors.HexColor("#2E4A6B"), spaceBefore=8, spaceAfter=4),
    "h4": ParagraphStyle("h4", fontName="MalgunB", fontSize=10.5, leading=14, spaceBefore=6, spaceAfter=3),
    "body": ParagraphStyle("body", fontName="Malgun", fontSize=9.5, leading=14.5, alignment=TA_LEFT, spaceAfter=4),
    "bullet": ParagraphStyle("bullet", fontName="Malgun", fontSize=9.5, leading=14.5, leftIndent=12, bulletIndent=2, spaceAfter=2),
    "bullet2": ParagraphStyle("bullet2", fontName="Malgun", fontSize=9.5, leading=14.5, leftIndent=26, bulletIndent=16, spaceAfter=2),
    "quote": ParagraphStyle("quote", fontName="Malgun", fontSize=9.5, leading=14, leftIndent=10, textColor=colors.HexColor("#444444"),
                            borderPadding=4, backColor=LIGHT, spaceAfter=6),
    "code": ParagraphStyle("code", fontName="Malgun", fontSize=8, leading=11, backColor=CODE_BG, borderPadding=5, leftIndent=4, spaceAfter=6),
    "cell": ParagraphStyle("cell", fontName="Malgun", fontSize=8.5, leading=12),
    "cellh": ParagraphStyle("cellh", fontName="MalgunB", fontSize=8.5, leading=12, textColor=colors.white),
}


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(t):
    t = esc(t)
    # Stash code spans so '*' / '[' inside them are not parsed as bold/italic/links.
    codes = []

    def stash(m):
        codes.append(m.group(1))
        return "\x00%d\x00" % (len(codes) - 1)

    t = re.sub(r"`([^`]+)`", stash, t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"(?<!\*)\*(?!\*)([^*]+?)\*(?!\*)", r"<i>\1</i>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<u>\1</u>", t)
    t = re.sub(r"\x00(\d+)\x00",
               lambda m: '<font face="Malgun" backColor="#F0F0F0">%s</font>' % codes[int(m.group(1))], t)
    return t


def make_table(rows):
    rows = [r for r in rows if not re.match(r"^\s*\|?\s*:?-{2,}", r)]
    data = []
    for r in rows:
        cells = [c.strip() for c in r.strip().strip("|").split("|")]
        data.append(cells)
    if not data:
        return None
    ncol = max(len(r) for r in data)
    data = [r + [""] * (ncol - len(r)) for r in data]
    small = ncol >= 8   # 열이 많으면 글자를 줄여 좁은 열에서도 행이 한 쪽을 넘지 않게 한다
    hs, cs = (S["cellh"], S["cell"]) if not small else (
        ParagraphStyle("cellh_s", parent=S["cellh"], fontSize=6.8, leading=9), ParagraphStyle("cell_s", parent=S["cell"], fontSize=6.8, leading=9))
    pdata = [[Paragraph(inline(c), hs if i == 0 else cs) for c in r] for i, r in enumerate(data)]
    avail = A4[0] - 36 * mm
    # 열 폭 = 평균 길이(상한 40) 기준, 단 가장 긴 단어가 들어갈 최소 폭은 보장
    def colw(j):
        col = [data[i][j] for i in range(len(data))]
        avg = sum(len(c) for c in col) / len(col)
        word = max((len(w) for c in col for w in c.split()), default=1)
        return max(min(avg, 40), min(word * 1.15, 30), 4)
    lens = [colw(j) for j in range(ncol)]
    tot = sum(lens)
    widths = [avail * l / tot for l in lens]
    minw = 24 if small else 30   # 패딩(8pt)보다 충분히 넓게: 열이 매우 많은 표에서 음수 폭 방지
    if min(widths) < minw:
        extra = sum(max(0, minw - w) for w in widths)
        big = sum(w for w in widths if w >= minw)
        widths = [minw if w < minw else w - extra * w / big for w in widths]
    t = Table(pdata, colWidths=widths, repeatRows=1)
    style = [("BACKGROUND", (0, 0), (-1, 0), ACCENT),
             ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#BBBBBB")),
             ("VALIGN", (0, 0), (-1, -1), "TOP"),
             ("LEFTPADDING", (0, 0), (-1, -1), 2 if small else 4), ("RIGHTPADDING", (0, 0), (-1, -1), 2 if small else 4),
             ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    for i in range(1, len(pdata)):
        if i % 2 == 0:
            style.append(("BACKGROUND", (0, i), (-1, i), LIGHT))
    t.setStyle(TableStyle(style))
    return t


LIST_RE = re.compile(r"^(\s*)([-*+]|\d+[.)])\s+(.*)")


def convert(md_text):
    story = []
    lines = md_text.splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.strip().startswith("```"):
            buf = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i]); i += 1
            i += 1
            story.append(Preformatted("\n".join(buf), S["code"]))
            continue
        if ln.strip().startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i]); i += 1
            t = make_table(rows)
            if t:
                story.append(t); story.append(Spacer(1, 6))
            continue
        if re.match(r"^\s*(---|\*\*\*|___)\s*$", ln):
            story.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#CCCCCC"), spaceBefore=6, spaceAfter=6))
            i += 1; continue
        m = re.match(r"^(#{1,6})\s+(.*)", ln)
        if m:
            lvl = len(m.group(1)); txt = inline(m.group(2).strip())
            if lvl == 1:
                story.append(Paragraph(txt, S["title"]))
                story.append(HRFlowable(width="100%", thickness=1.2, color=ACCENT, spaceAfter=8))
            elif lvl == 2:
                story.append(Paragraph(txt, S["h2"]))
            elif lvl == 3:
                story.append(Paragraph(txt, S["h3"]))
            else:
                story.append(Paragraph(txt, S["h4"]))
            i += 1; continue
        m = LIST_RE.match(ln)
        if m:
            indent = len(m.group(1).replace("\t", "    "))
            marker = m.group(2)
            bullet = marker if marker[0].isdigit() else "\u2022"
            txt = m.group(3)
            j = i + 1
            while (j < len(lines) and lines[j].strip() and not LIST_RE.match(lines[j])
                   and not lines[j].startswith("#") and not lines[j].strip().startswith("|")
                   and not lines[j].strip().startswith("```")):
                txt += " " + lines[j].strip(); j += 1
            style = S["bullet2"] if indent >= 2 else S["bullet"]
            story.append(Paragraph(inline(txt), style, bulletText=bullet))
            i = j; continue
        if ln.strip().startswith(">"):
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(lines[i].strip()[1:].strip()); i += 1
            story.append(Paragraph(inline(" ".join(buf)), S["quote"]))
            continue
        if not ln.strip():
            i += 1; continue
        buf = [ln.strip()]
        j = i + 1
        while j < len(lines) and lines[j].strip() and not re.match(r"^(#{1,6}\s|\s*([-*+]|\d+[.)])\s|\||```|>)", lines[j]):
            buf.append(lines[j].strip()); j += 1
        story.append(Paragraph(inline(" ".join(buf)), S["body"]))
        i = j
    return story


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Malgun", 8)
    canvas.setFillColor(colors.HexColor("#888888"))
    canvas.drawRightString(A4[0] - 18 * mm, 12 * mm, str(doc.page))
    canvas.drawString(18 * mm, 12 * mm, doc.title or "")
    canvas.restoreState()


def main():
    src, dst = sys.argv[1], sys.argv[2]
    md = io.open(src, encoding="utf-8").read()
    title = ""
    for l in md.splitlines():
        if l.startswith("# "):
            title = l[2:].strip(); break
    doc = SimpleDocTemplate(dst, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=18 * mm, bottomMargin=20 * mm, title=title)
    doc.build(convert(md), onFirstPage=footer, onLaterPages=footer)
    print("written", dst)


if __name__ == "__main__":
    main()
