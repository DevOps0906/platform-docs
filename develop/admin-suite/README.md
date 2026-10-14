# admin-suite 개발 묶음 — Admin Suite

기관 내부 관리 시스템 3종 묶음입니다. ERP(재고·판매·인사), HMS 병원(예약·대기열·환자·검사), SMS 학교(학급·출석)를 공유 보안 코어 `packages/admin-kit` 위의 앱 3개로 만듭니다. 사내 규정·매뉴얼을 근거로 답하는 AI 업무 어시스턴트(채팅·음성)와 기관 운영 위키가 들어갑니다. 병원(HMS)은 의료정보 보호를 위해 전용 서버만 쓰고 상용 API·공용 서버를 쓰지 않습니다. 공개 랜딩이 없어 3D 히어로는 없습니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 중소기업·병원·학교 직원(역할별) |
| DB 스키마(모듈러 번호) | `erp`·`sms`(1600·1700), hms는 모놀리스 전용 |
| 개발 작업 수 | 57개(`products/admin-suite/06_AGENT_PLAN.md`) |
| 기획서 | [`products/admin-suite/`](../../products/admin-suite/) |
| 참고 | 앱 3개라 묶음 안 `supabase/`가 erp·hms·sms 세 세트입니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`admin-suite_develop.md`](admin-suite_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-admin-suite.sh` / `setup-admin-suite.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\admin-suite\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `admin-suite-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/admin-suite/setup-admin-suite.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/admin-suite/setup-admin-suite.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
