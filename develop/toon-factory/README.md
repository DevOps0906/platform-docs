# toon-factory 개발 묶음 — Toon Factory

이야기를 넣으면 AI가 회차 콘티(컷 구성·대사)를 짜고, 미리 만든 캐릭터 모듈(포즈·표정)로 컷을 조립하며 배경은 AI로 생성해 인스타툰 PNG·ZIP, 세로 스크롤 웹툰, 9:16 MP4로 내보내는 AI 웹툰 제작 도구입니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 인스타툰·웹툰 지망 작가, SNS 마케터, 지식 크리에이터 |
| DB 스키마(모듈러 번호) | `toon`(2000) |
| 개발 작업 수 | 69개(`products/toon-factory/06_AGENT_PLAN.md`, 인증 단계 B·C1·C2 3개 포함) |
| 로그인 | 인증 단계: 개발 1단계는 Mock(로컬 시드 계정) → G1 후 Google·이메일(공개 베타 전) → G2 후 카카오·네이버. 순서와 실행 방법은 `toon-factory_develop.md` 13장 |
| 기획서 | [`products/toon-factory/`](../../products/toon-factory/) |
| 참고 | 경쟁 서비스 비교는 `products/toon-factory/08_BENCHMARK.md`에 따로 있습니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`toon-factory_develop.md`](toon-factory_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-toon-factory.sh` / `setup-toon-factory.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\toon-factory\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `toon-factory-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/toon-factory/setup-toon-factory.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/toon-factory/setup-toon-factory.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
