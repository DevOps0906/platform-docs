# stock-dashboard 개발 묶음 — Stock Dashboard

본인이 직접 연결한 증권사 계좌(1차는 모의투자)의 잔고·보유 종목·체결 내역을 한 화면에서 보고, AI가 포트폴리오 분산과 위험 요인을 진단하는 초대제 개인 투자 대시보드입니다. 종목 추천이나 매수가·목표가·손절가는 제시하지 않습니다. 공시 요약, 용어 채팅·위키, 음성 브리핑이 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 개인 투자자(초대제) |
| DB 스키마(모듈러 번호) | `stock`(1900), 1차는 모놀리스 권장 |
| 개발 작업 수 | 54개(`products/stock-dashboard/06_AGENT_PLAN.md`, 인증 단계 B·C 3개 포함) |
| 기획서 | [`products/stock-dashboard/`](../../products/stock-dashboard/) |
| 참고 | 유사투자자문업 해석과 공시 데이터 이용 조건은 열린 결정입니다. |
| 인증 단계 | 개발은 Mock 로그인(로컬 시드 페르소나)으로 시작하고, G1 뒤 "초대 링크 수락 + Google"(ST-06-052), G2 뒤 카카오·네이버(P2 선택). 초대 토큰 흐름은 그대로. 안내서 19장 |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`stock-dashboard_develop.md`](stock-dashboard_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-stock-dashboard.sh` / `setup-stock-dashboard.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\stock-dashboard\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `stock-dashboard-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/stock-dashboard/setup-stock-dashboard.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/stock-dashboard/setup-stock-dashboard.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
