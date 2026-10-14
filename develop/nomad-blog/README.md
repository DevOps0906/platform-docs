# nomad-blog 개발 묶음 — NOMAD Blog

키워드 하나로 AI가 블로그 원고를 쓰고 제휴 상품 카드와 대가성(광고) 문구를 자동으로 넣은 뒤, 네이버 블로그·티스토리·워드프레스에 예약 발행하는 조직 단위 서비스입니다. 네이버 브랜드커넥트 지원도 자동으로 제출합니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 제휴 수익 블로거, 블로그 여러 개를 운영하는 제휴 마케터, 소상공인 |
| DB 스키마(모듈러 번호) | `blog`(1300) |
| 개발 작업 수 | 56개(`products/nomad-blog/06_AGENT_PLAN.md`) |
| 기획서 | [`products/nomad-blog/`](../../products/nomad-blog/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`nomad-blog_develop.md`](nomad-blog_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-nomad-blog.sh` / `setup-nomad-blog.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\nomad-blog\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `nomad-blog-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/nomad-blog/setup-nomad-blog.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/nomad-blog/setup-nomad-blog.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
