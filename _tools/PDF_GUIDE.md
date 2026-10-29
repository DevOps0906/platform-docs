# PDF 생성 가이드 (PDF 에이전트용)

입력: `D:\WorkSpace\platform\docs\reviews\*.md`
출력: 별도 레포 PDF_Collections(로컬 `D:WorkSpaceDEVPDF_Collectionsde-reviews<제품><동일 파일명>.pdf`). 제품 폴더는 reviews/README.md 표의 "반영된 통합 제품" 첫 번째 기준
도구: `python D:\WorkSpace\platform\docs\_tools\md2pdf.py <input.md> <output.pdf>` (reportlab, 맑은 고딕 내장, 설치 완료)

## 절차 (파일마다)
1. md 파일을 읽어 구조를 확인한다. 아래 "PDF 변환 전 정리" 규칙에 맞게 md 를 **수정** 한다 (내용은 바꾸지 않고 형식만).
2. md2pdf.py 로 변환한다.
3. 변환 결과를 검증한다: `python -c "from pypdf import PdfReader; r=PdfReader('out.pdf'); print(len(r.pages)); print(r.pages[0].extract_text()[:400])"` (pypdf 가 없으면 `pip install pypdf`). 페이지 수가 2 이상이고 첫 페이지에 한국어 제목이 보여야 한다. 깨진 글자(■, ???)가 있으면 원인을 찾아 고친다.
4. 변환 오류(예외)가 나면 md2pdf.py 가 처리 못하는 마크다운 문법이 원인이다. md 쪽을 고치거나, 필요하면 md2pdf.py 를 **하위 호환을 유지하며** 개선한다. 개선했다면 이미 변환한 파일을 다시 변환한다.

## PDF 변환 전 정리 규칙
- (2026-10-12 수정) md2pdf.py 가 이제 코드 스팬(`...`) 안의 `*` 를 그대로 처리한다. `src/*`, `*.ts` 같은 와일드카드는 바꾸지 말고 그대로 둔다.
- 파일 수정은 Edit 도구로 한다. sed 로 여러 줄을 한꺼번에 바꾸지 않는다.
- 표 안의 셀에 줄바꿈(`<br>`)이나 파이프 문자 `|` 가 포함되면 안 된다. 셀 내부의 `|` 는 `/` 로 바꾼다.
- HTML 태그(`<br>`, `<b>`, `<sub>` 등)는 모두 제거하거나 Markdown 으로 바꾼다.
- 이모지와 특수 기호(✅ ❌ ⚠️ → 등)는 텍스트로 바꾼다 (예: `->`, `O`, `X`, `[주의]`).
- 표 머리글 아래 구분선 `|---|---|` 은 반드시 있어야 한다.
- 코드 블록은 ``` 로 감싼다. 들여쓰기만으로 된 코드 블록은 ``` 로 바꾼다.
- 중첩 리스트는 2칸 들여쓰기만 지원한다. 3단계 이상은 2단계로 평탄화한다.
- 제목은 `#` 1개(문서 제목) 1번만, 그 아래는 `##`, `###` 만 쓴다.

## 완료 보고 형식
파일별로 `파일명 | 페이지수 | 상태(OK/수정후OK/실패)` 표를 작성하고, md2pdf.py 를 수정했다면 무엇을 바꿨는지 2줄로 적는다.

## 제품 기획서 통합본 (2026-10-30 추가)

- 도구: `python -X utf8 _tools/product_pdf.py <저장소 루트> <PDF_Collections>/product-docs --all` (book-trailer는 `book_trailer_pdf.py`가 별도 담당)
- 변환기는 `md2pdf.py`의 `convert()`를 쓴다. reportlab·pypdf가 설치된 Python으로 실행한다(시스템 `py`에는 없을 수 있음).
- `md2pdf.py` 표 폭 계산을 개선했다: 열 폭은 평균 길이와 가장 긴 단어 기준이고, 열이 8개 이상이면 글자를 줄이며 최소 폭을 보장한다(좁은 열 때문에 행이 한 쪽을 넘던 LayoutError 해결).
- 알려진 한계: 코드 스팬 안의 `|`는 표 열 구분으로 읽혀 행이 쪼개진다.
