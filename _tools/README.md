# _tools — 리뷰 작성·PDF 변환 도구

| 파일 | 내용 |
|---|---|
| [`REVIEW_TEMPLATE.md`](REVIEW_TEMPLATE.md) | 원본 프로젝트 코드 리뷰 작성 가이드(분석 에이전트용). `reviews/`의 리뷰가 이 형식을 따른다 |
| [`PDF_GUIDE.md`](PDF_GUIDE.md) | 리뷰 md를 PDF로 바꾸는 절차와 변환 전 정리 규칙(PDF 에이전트용) |
| [`md2pdf.py`](md2pdf.py) | md → PDF 변환기(reportlab, 한글 폰트). `python md2pdf.py input.md output.pdf`. 결과 PDF는 별도 레포 [PDF_Collections](https://github.com/DevOps0906/PDF_Collections)에 보관 |
| [`product_pdf.py`](product_pdf.py) | 제품 기획서(`products/<제품>/*.md`)를 제품별 통합본 PDF 1개로 변환(표지, 문서 목록과 쪽 번호, 장·절 책갈피). `python -X utf8 product_pdf.py <루트> <출력> --all`(제품), `--common`(통합 결정 분석·공용 코어 규격 2종). 결과는 [PDF_Collections](https://github.com/DevOps0906/PDF_Collections)`/product-docs/` |
| [`folder_tree.py`](folder_tree.py) | 저장소 폴더 구조를 `FOLDER_TREE.md`로 만든다(요약 트리 + 전체 트리). 저장소 루트에서 `python3 -I _tools/folder_tree.py` |
