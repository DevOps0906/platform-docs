# nomad-commerce 개발 묶음 — NOMAD Commerce

쿠팡·스마트스토어 셀러가 아마존·국내 도매 상품을 가져와 상품DB에 쌓고, AI로 슬롯형 상세페이지(이미지 10장/15장, 카피, 금지어 검사)를 만든 뒤 마켓 규격으로 API 업로드하거나 엑셀(플레이오토 호환)·ZIP으로 내려받는 서비스입니다. 상품 스펙·마켓 규칙 RAG, 셀러 어시스턴트 채팅, 음성이 들어갑니다. 쇼츠 영상 렌더는 nomad-video에 맡깁니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 쿠팡·스마트스토어 국내 셀러 |
| DB 스키마(모듈러 번호) | `commerce`(1400) |
| 개발 작업 수 | 60개(`products/nomad-commerce/06_AGENT_PLAN.md`, 인증 단계 B·C 작업 3개 포함) |
| 로그인 | 인증 단계(확정 결정 22): MVP 개발은 Mock(로컬 시드 계정) → G1 후 Google + 이메일(공개 베타 전) → G2 후 카카오·네이버. 안내서 13장 |
| 기획서 | [`products/nomad-commerce/`](../../products/nomad-commerce/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`nomad-commerce_develop.md`](nomad-commerce_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-nomad-commerce.sh` / `setup-nomad-commerce.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\nomad-commerce\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `nomad-commerce-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/nomad-commerce/setup-nomad-commerce.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/nomad-commerce/setup-nomad-commerce.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
