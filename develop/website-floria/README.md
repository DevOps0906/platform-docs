# website-floria 개발 묶음 — Floria (Botanic Architecture)

고급 주거·갤러리·기업 공간의 식물 설치 브랜드 홈페이지와, 들어온 문의·뉴스레터를 처리하는 초대제 운영 콘솔입니다. 방문자 AI 상담(시공 사례·식물 정보·FAQ), 방문자 음성 상담, 브랜드 지식 위키, 3D 온실 구조물 히어로가 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 갤러리·기업 공간·하이엔드 고객(방문자), 스튜디오 운영자 |
| DB 스키마(모듈러 번호) | `site`(2200) |
| 개발 작업 수 | 48개(`products/website-floria/06_AGENT_PLAN.md`) |
| 기획서 | [`products/website-floria/`](../../products/website-floria/) |
| 참고 | 범위가 작아 공용 코어를 먼저 실전 검증하는 제품으로 권장됩니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`website-floria_develop.md`](website-floria_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-website-floria.sh` / `setup-website-floria.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\website-floria\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `website-floria-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/website-floria/setup-website-floria.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/website-floria/setup-website-floria.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
