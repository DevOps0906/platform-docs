# book-trailer 개발 묶음 — NOMAD Book Trailer

원고(PDF·EPUB·DOCX·MD·TXT)나 FLORA 책을 넣으면 AI가 원고를 읽고 훅 브리프 3안을 만들고, 장르 트레일러 문법(6종)으로 스토리보드를 짠 뒤 장면 이미지·내레이션(같은 목소리)·자막·음악을 붙여 쇼츠(9:16)·유튜브(16:9)·인스타(1:1, 4:5)·표지 루프 영상을 한 번에 렌더하고, 구매 링크 클릭까지 측정하는 북트레일러 자동화 서비스입니다. 렌더는 Remotion(React 컴포지션)이라 앱과 영상이 같은 디자인 토큰 체계를 씁니다. 책 근거 코치 채팅, 책 설정 위키, 음성 대화, 동적 3D + 3D 영상 메인 화면이 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 1인 출판사·작가, 중소 출판사 마케터, 웹소설·전자책 작가 |
| DB 스키마(모듈러 번호) | `trailer`(2600) |
| 개발 작업 수 | 60개(`products/book-trailer/06_AGENT_PLAN.md`, 인증 단계 작업 포함) |
| 인증 단계 | Mock 로그인(Stage A)으로 시작 → G1 후 Google + 이메일(B) → G2 후 카카오·네이버(C). [`book-trailer_develop.md`](book-trailer_develop.md) 19장 |
| 기획서 | [`products/book-trailer/`](../../products/book-trailer/) (디자인 시스템은 `08_DESIGN_SYSTEM.md`) |
| 가격 | [`Price_Plans/book-trailer/PRICE_PLAN.md`](../../Price_Plans/book-trailer/PRICE_PLAN.md) |
| 참고 | 개발 전에 대행 판매로 수요·품질을 먼저 검증하는 순서를 권합니다(개발서 1.1절). Remotion은 직원 4명부터 유료 라이선스(D-2) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`book-trailer_develop.md`](book-trailer_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-book-trailer.sh` / `setup-book-trailer.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\book-trailer\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `book-trailer-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물 27개, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py book-trailer`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/book-trailer/setup-book-trailer.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/book-trailer/setup-book-trailer.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
