# live-poll 개발 묶음 — Live Poll

진행자가 행사(방)를 만들면 청중이 로그인 없이 6자리 코드나 QR로 들어와 투표·질문하고, 결과가 발표 화면과 OBS 방송 오버레이에 실시간으로 반영되는 서비스입니다(Slido형). 진행자 AI 어시스턴트, Q&A AI 정리(분류·군집·요약), 행사 위키, 음성 질문, 3D 히어로가 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 강연자, 행사 진행자, 방송인과 청중 |
| DB 스키마(모듈러 번호) | `poll`(1800) |
| 개발 작업 수 | 48개(`products/live-poll/06_AGENT_PLAN.md`) |
| 기획서 | [`products/live-poll/`](../../products/live-poll/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`live-poll_develop.md`](live-poll_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-live-poll.sh` / `setup-live-poll.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\live-poll\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `live-poll-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/live-poll/setup-live-poll.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/live-poll/setup-live-poll.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
