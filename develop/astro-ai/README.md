# astro-ai 개발 묶음 — 신비로운AI

만세력 엔진이 계산한 사주 원국과 사용자가 뽑은 타로 3장을 AI가 해설해, 본인·가족·지인의 리포트를 A4 책자형 PDF로 만들고 이메일과 대시보드로 전달하는 크레딧팩 결제형 서비스입니다. AI 채팅(내 사주 질문, 용어 설명), 음성 대화, 리딩 낭독, 사주 용어 위키, 3D 히어로가 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 자기 이해·가족 선물용 리포트를 원하는 20~40대 |
| DB 스키마(모듈러 번호) | `astro`(1100) |
| 개발 작업 수 | 54개(`products/astro-ai/06_AGENT_PLAN.md`) |
| 기획서 | [`products/astro-ai/`](../../products/astro-ai/) |
| 참고 | 개발 가이드 형식의 기준 예시(astro-ai 기준)입니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`astro-ai_develop.md`](astro-ai_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-astro-ai.sh` / `setup-astro-ai.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\astro-ai\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `astro-ai-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/astro-ai/setup-astro-ai.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/astro-ai/setup-astro-ai.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
