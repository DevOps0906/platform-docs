# microweb-studio 개발 묶음 — Microweb Studio

하객에게 보내는 모바일 마이크로웹(1차 청첩장, 2단계 돌잔치·부고장)을 템플릿 엔진으로 만들고, 같은 사이트의 쇼룸(포트폴리오, 가격표, 업종×등급 시뮬레이터, 견적 문의)으로 대행 제작을 판매합니다. AI 문구·구성 제안, 제작 상담 채팅, 청첩장 인사말 음성, 하객 음성 방명록이 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 대행 제작 스튜디오 운영자(초대제 베타)와 하객 |
| DB 스키마(모듈러 번호) | `microweb`(1500) |
| 개발 작업 수 | 53개(`products/microweb-studio/06_AGENT_PLAN.md`) |
| 기획서 | [`products/microweb-studio/`](../../products/microweb-studio/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`microweb-studio_develop.md`](microweb-studio_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-microweb-studio.sh` / `setup-microweb-studio.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\microweb-studio\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `microweb-studio-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/microweb-studio/setup-microweb-studio.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/microweb-studio/setup-microweb-studio.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
