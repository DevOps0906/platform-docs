# nomad-video 개발 묶음 — NOMAD AI Factory

트렌드 레이더로 소재를 고르고 숏폼(Track A~C), 롱폼(Track D), Lofi 단일 곡(Track E), 플레이리스트(Track F)를 크레딧 과금으로 자동 생산·검사한 뒤 YouTube(최대 40채널)·인스타그램·틱톡·스레드·네이버 클립에 배포하고 제휴 수익화까지 하는 조직 단위 서비스입니다. AI 채널 코치 채팅과 쇼츠 대행 에이전시 운영 기능(고객사, 검수, 월간 리포트)이 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 숏폼 크리에이터, 커머스 운영자, 소규모 에이전시 |
| DB 스키마(모듈러 번호) | `video`(1200) |
| 개발 작업 수 | 65개(`products/nomad-video/06_AGENT_PLAN.md`, 인증 단계 작업 3개 포함) |
| 로그인 | MVP 개발은 Mock(Stage A), 공개 베타 전 Google + 이메일(B), G2 후 카카오·네이버(C). 채널 연결 OAuth·네이버 클립 로그인과는 별개. [`nomad-video_develop.md`](nomad-video_develop.md) 19절 |
| 기획서 | [`products/nomad-video/`](../../products/nomad-video/) |
| 참고 | 쇼츠 대행 운영 설계는 `products/nomad-video/08_AGENCY_OPERATIONS.md`에 따로 있습니다. |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`nomad-video_develop.md`](nomad-video_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |
| `setup-nomad-video.sh` / `setup-nomad-video.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\nomad-video\`를 만들고 아래 묶음을 붙이는 설치 스크립트(Git Bash / PowerShell). 먼저 `--dry-run` / `-DryRun`으로 확인한다 |
| `nomad-video-root/` | 개발 폴더 루트에 붙는 내용(`docs/file` 근거 산출물, `docs/wiki`, `supabase`, `infra`, `.claude/skills/llm-wiki`). 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/nomad-video/setup-nomad-video.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/nomad-video/setup-nomad-video.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 4~5절을 참고한다.
