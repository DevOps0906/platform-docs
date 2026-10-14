# flora-publishing 개발 묶음 — FLORA Publishing

원고는 있지만 편집·조판 경험이 없는 1인 작가가 AI와 함께 기획 → 집필 → 판형 조정을 거쳐 인쇄용 PDF와 ePub을 완성하는 전자책 출판 서비스입니다. 여러 제품이 같이 쓰는 PDF 렌더 서비스(WeasyPrint)의 소유 제품입니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 1인 작가·에세이스트, 크리에이터, 소규모 독립 출판사 |
| DB 스키마(모듈러 번호) | `publishing`(1000) |
| 개발 작업 수 | 65개(`products/flora-publishing/06_AGENT_PLAN.md`, 인증 단계 작업 3개, 에이전트·운영 작업 7개 포함) |
| 에이전트·운영 (2026-10-14, 검토용) | 기존 기능을 6개 에이전트로 묶는 실행·검수 계층(`agent_tasks`), 운영 콘솔, 디자인 레이어 3종. [`flora-publishing_develop.md`](flora-publishing_develop.md) 20장 |
| 인증 단계 | 개발은 Mock 로그인(Stage A, 로컬 시드 계정)으로 시작 → G1 후 Google + 이메일(B) → G2 후 카카오·네이버(C). [`flora-publishing_develop.md`](flora-publishing_develop.md) 19장 |
| 기획서 | [`products/flora-publishing/`](../../products/flora-publishing/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`flora-publishing_develop.md`](flora-publishing_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-flora-publishing.sh` / `setup-flora-publishing.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\flora-publishing\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `flora-publishing-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/flora-publishing/setup-flora-publishing.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/flora-publishing/setup-flora-publishing.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
