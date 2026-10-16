# pdf — 코드 리뷰 PDF 변환본

[`reviews/`](../reviews/)의 리뷰 25개를 같은 파일 이름의 PDF로 변환한 것입니다(인쇄·공유용). 내용의 정본은 `reviews/`의 md 파일입니다.

변환 방법: [`_tools/PDF_GUIDE.md`](../_tools/PDF_GUIDE.md) (`python _tools/md2pdf.py <입력.md> <출력.pdf>`, 맑은 고딕 내장)

## book-trailer 기획·개발 문서 (2026-10-16)

[`book-trailer/`](book-trailer/)에 북트레일러 제품 문서 19개의 PDF가 있습니다. 정본은 각 폴더의 md 파일입니다.

| 파일 | 내용 |
|---|---|
| `book-trailer/book-trailer_통합본.pdf` | 표지, 쪽 번호가 있는 문서 목록, 책갈피(장·절)를 넣은 통합본 143쪽 |
| `book-trailer/1_기획서/` | `products/book-trailer/` 10개(README, 01~08, CLAUDE) |
| `book-trailer/2_가격과_검증/` | `Price_Plans/book-trailer/` 6개(README, PRICE_PLAN, 01~04) |
| `book-trailer/3_개발서/` | `develop/book-trailer/` 2개, `develop_V2/book-trailer/` 1개 |

변환 방법: `python3 -I _tools/book_trailer_pdf.py <저장소 루트> pdf/book-trailer` (Markdown → HTML → Chromium 인쇄, Playwright. 본문 Noto Sans CJK KR, 제목 Noto Serif CJK KR, 코드 Noto Sans Mono CJK KR. 열이 8개 이상인 표가 있는 문서는 가로 A4). md를 고친 뒤 다시 실행하면 통합본 목차 쪽 번호도 새로 계산합니다.

