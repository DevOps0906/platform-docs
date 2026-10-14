# study-note 개발 묶음 — Study Note

수업이나 회의 원문을 붙여넣으면 AI 모델 2개가 따로 정리하고 통합 모델이 하나의 "학습 일지"(학습 목표 / 학습 내용)로 합쳐 TXT와 보관함에 남기는 서비스입니다. 과목별 개념 위키, 퀴즈, 내 노트 근거 Q&A 채팅, 강의 녹음 → 자동 노트 기능이 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | IT 교육·부트캠프 수강생, 강사, 회의를 정리하는 직장인 |
| DB 스키마(모듈러 번호) | `notes`(2100) |
| 개발 작업 수 | 52개(`products/study-note/06_AGENT_PLAN.md`) |
| 기획서 | [`products/study-note/`](../../products/study-note/) |
| 참고 | 범위가 작아 공용 코어를 먼저 실전 검증하는 제품으로 권장됩니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`study-note_develop.md`](study-note_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-study-note.sh` / `setup-study-note.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\study-note\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `study-note-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/study-note/setup-study-note.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/study-note/setup-study-note.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
