# nomad-docs 개발 묶음 — NOMAD Docs

회사·거래처·프로젝트 정보를 한 번 입력하고 체크리스트에 체크하면 견적서·과업지시서·요구사항정의서·WBS·화면목록·개발용역계약서·검수확인서·회의록을 한 번에 만드는 문서 자동화 서비스입니다. 체크 하나가 요구사항·화면·비용·계약 조항·검수 항목까지 연결되어 문서끼리 금액과 번호가 맞습니다. 버전 관리, 요구사항 추적표, PDF/DOCX 내보내기, CRM형 작업 화면(파이프라인 보드), 생성 단계 애니메이션, 동적 3D + 3D 영상 메인 화면, n8n·HubSpot·ERP 연동(Phase 2)이 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 외주 개발 프리랜서, 소형 개발 에이전시 |
| DB 스키마(모듈러 번호) | `docs`(2300) |
| 개발 작업 수 | 65개(`products/nomad-docs/06_AGENT_PLAN.md`, 인증 단계 작업 3개 포함) |
| 인증 단계 | 개발은 Mock 로그인(Stage A, 로컬 시드 계정)으로 시작 → G1 후 Google + 이메일(B) → G2 후 카카오·네이버(C). [`nomad-docs_develop.md`](nomad-docs_develop.md) 19장 |
| 기획서 | [`products/nomad-docs/`](../../products/nomad-docs/) |
| 참고 | 계약서는 법무 검토(D-3) 전까지 비활성입니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`nomad-docs_develop.md`](nomad-docs_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-nomad-docs.sh` / `setup-nomad-docs.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\nomad-docs\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `nomad-docs-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
