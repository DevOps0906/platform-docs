# _tools — 리뷰 작성·PDF 변환 도구

| 파일 | 내용 |
|---|---|
| [`REVIEW_TEMPLATE.md`](REVIEW_TEMPLATE.md) | 원본 프로젝트 코드 리뷰 작성 가이드(분석 에이전트용). `reviews/`의 리뷰가 이 형식을 따른다 |
| [`PDF_GUIDE.md`](PDF_GUIDE.md) | 리뷰 md를 PDF로 바꾸는 절차와 변환 전 정리 규칙(PDF 에이전트용) |
| [`md2pdf.py`](md2pdf.py) | md → PDF 변환기(reportlab, 한글 폰트). `python md2pdf.py input.md output.pdf` |
| [`folder_tree.py`](folder_tree.py) | 저장소 폴더 구조를 `FOLDER_TREE.md`로 만든다(요약 트리 + 전체 트리). 저장소 루트에서 `python3 -I _tools/folder_tree.py` |
