# platform-docs — 통합 플랫폼 기획·개발 문서 저장소

여러 SaaS 프로젝트의 코드 리뷰를 바탕으로 제품을 통합 기획하고, 제품마다 바로 개발을 시작할 수 있는
개발 묶음(설치 스크립트 + 근거 문서 + DB)을 담은 저장소입니다. 코드는 없고 문서와 SQL만 있습니다.
로컬 위치는 `D:\WorkSpace\platform\docs`를 기준으로 합니다(문서 안 경로가 이 위치를 씁니다).

## 1. 폴더 구성

| 폴더 | 내용 | 언제 보나 |
|---|---|---|
| `reviews/` | 원본 프로젝트 25개의 코드 리뷰(결함, 이식할 자산) | 왜 이렇게 기획했는지 근거를 볼 때 |
| `pdf/` | `reviews/`의 PDF 변환본 | 인쇄·공유용 |
| `products/` | 통합 기획서(제품 13개 + 공용 코어 + 디자인 가이드 + 통합 DB) | 무엇을 만들지 볼 때 |
| `develop/` | 제품별 개발 묶음(개발 가이드, setup 스크립트, 개발 폴더에 붙일 문서·DB) | 개발을 시작할 때 |
| `_tools/` | 리뷰 템플릿, md → PDF 변환 도구 | 리뷰를 추가할 때 |

## 2. 제품 목록

| 제품 | 한 줄 | 기획서 | 개발 묶음 |
|---|---|---|---|
| flora-publishing | AI 전자책 출판 | `products/flora-publishing/` | `develop/flora-publishing/` |
| astro-ai (신비로운AI) | 사주·타로 리딩 | `products/astro-ai/` | `develop/astro-ai/` |
| nomad-video (NOMAD AI Factory) | 숏폼 영상 제작·업로드, 쇼츠 대행 | `products/nomad-video/` | `develop/nomad-video/` |
| nomad-blog | 블로그 자동화 | `products/nomad-blog/` | `develop/nomad-blog/` |
| nomad-commerce | 커머스 상세페이지·콘텐츠 | `products/nomad-commerce/` | `develop/nomad-commerce/` |
| microweb-studio | 청첩장·마이크로 웹 | `products/microweb-studio/` | `develop/microweb-studio/` |
| admin-suite | ERP·학교·병원 관리 | `products/admin-suite/` | `develop/admin-suite/` |
| live-poll | 실시간 투표(Slido형) | `products/live-poll/` | `develop/live-poll/` |
| stock-dashboard | 주식 대시보드 | `products/stock-dashboard/` | `develop/stock-dashboard/` |
| toon-factory | 웹툰·캐릭터 생성 | `products/toon-factory/` | `develop/toon-factory/` |
| study-note | 학습 노트 정리 | `products/study-note/` | `develop/study-note/` |
| website-floria | 회사 홈페이지 | `products/website-floria/` | `develop/website-floria/` |
| nomad-docs (NOMAD Docs) | 체크리스트로 계약서·요구사항정의서 등 실무 문서 자동 생성, CRM형 작업 공간 | `products/nomad-docs/` | `develop/nomad-docs/` |

공용: `products/_platform-core/`(인증·조직·크레딧·결제·잡·AI·음성 규격), `products/_design-guide/`
(디자인 시스템, 3D 히어로), `products/_supabase-modular/`(통합 DB: `core` + 제품 스키마).

## 3. 기획 읽는 순서

1. `products/README.md`(전체 인덱스와 진행 상태) → `products/00_MERGE_ANALYSIS.md`(확정 결정 표)
2. 제품 폴더 `README.md` → `01_PRD.md`(기능·요금·열린 결정) → `03_SCREENS_UX.md`(화면) → `06_AGENT_PLAN.md`(작업 계획)
3. 대표님이 결정할 항목은 각 제품 `01_PRD.md` 8절 "열린 결정"에 모여 있습니다.

| 파일(모든 제품 공통) | 내용 |
|---|---|
| `README.md` | 한 줄 정의, 통합 근거, 원본 매핑, 문서 목록 |
| `01_PRD.md` | 페르소나, MVP·Phase 범위, 기능 요구사항과 수용 기준, 요금, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 잡·워커, AI 라우팅, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 사용자 플로우, 디자인 시스템, 메인페이지 |
| `04_API.md` | Route Handler, RPC, 잡 계약, 오류 코드 |
| `05_DATA_MODEL.md` | 테이블, RLS, 함수, 모놀리스·모듈러 차이 |
| `06_AGENT_PLAN.md` | 작업 목록(작업 ID, 소유 경로, 의존성, 권장 모델, 수용 기준), 웨이브 |
| `07_SOURCE_MIGRATION.md` | 원본에서 가져올 것·버릴 것, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 마이그레이션·seed(·RLS 테스트) |

## 4. 개발하는 방법 (모든 제품 공통)

개발은 이 저장소에서 하지 않습니다. 멀티에이전트 베이스 레포를 복사해 제품별 개발 폴더를 만들고,
이 저장소의 개발 묶음을 그 위에 붙인 뒤 그 폴더에서 Claude Code로 개발합니다.

```
D:\WorkSpace\platform\docs\develop\<제품>\          ← 이 저장소(안내서, 스크립트, 묶음)
        │  setup 스크립트: 베이스 복사 → 초기화 → 묶음 붙여넣기 → 에이전트 모델 지정 → 무결성 점검
        ▼
D:\WorkSpace\DEV\<제품>\                             ← 개발 폴더(여기서 claude 실행)
  ├── docs\file\    근거 산출물(기획서 01~07, 공용 코어, 디자인)  ← 개발의 정답
  ├── docs\wiki\    개발 위키
  ├── supabase\     로컬 DB 마이그레이션·seed·RLS 테스트
  ├── apps\web\  apps\api\                          ← 여기에 코드를 만든다
  ├── .claude\agents\  _shared\  _templates\        ← 베이스(오케스트레이터 규칙, 승인 게이트)
  └── tasks\        작업 1개 = task 폴더 1개
```

| 단계 | 할 일 | 상세 |
|---|---|---|
| 0 준비 | Git, jq, Python, Node 20, Docker, Supabase CLI, Claude Code. 베이스 레포 `MultiAgent-Service-Fullstack-Tree-Framwork`를 `D:\WorkSpace\DEV\`에 받기 | 개발 가이드 2장 |
| 1 설치 | setup 스크립트를 드라이런으로 확인 후 실행 | 개발 가이드 3~5장 |
| 2 프로필 | `_shared/project-profile.md`에 스택 버전·명령 채우기 | 개발 가이드 6장 |
| 3 로컬 DB | `supabase start` → `supabase db reset` → 타입 생성 → 확인 쿼리 | 개발 가이드 7장 |
| 4 결정 | 착수 전 결정 확정, 산출물 상태를 "승인"으로 | 개발 가이드 8장 |
| 5 작업 | `06_AGENT_PLAN.md`의 작업을 웨이브(W0부터) 순서로 task로 만들어 요청 프롬프트로 지시 | 개발 가이드 9장 |
| 6 반복 | 계획 공격 → 구현 → 리뷰 → 위키 갱신 → 완료, 웨이브가 끝나면 다음 웨이브 | 개발 가이드 10장 |

개발 가이드: `develop/<제품>/<제품>_develop.md`

## 5. 예시: NOMAD Docs로 첫 작업까지

### 5.1 설치

PowerShell:
```powershell
pwsh -File D:\WorkSpace\platform\docs\develop\nomad-docs\setup-nomad-docs.ps1 -DryRun   # 할 일만 출력
pwsh -File D:\WorkSpace\platform\docs\develop\nomad-docs\setup-nomad-docs.ps1          # 실제 실행
```
Git Bash:
```bash
bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh --dry-run
bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh
```
마지막에 `결과: PASS=17 FAIL=0`과 `== ALL PASS ==`가 나오면 `D:\WorkSpace\DEV\nomad-docs\`가 준비된 것입니다.
대상 폴더가 이미 있으면 스크립트는 덮어쓰지 않고 멈춥니다.

### 5.2 프로필과 에이전트 확인

1. `D:\WorkSpace\DEV\nomad-docs\_shared\project-profile.md`에 스택을 적습니다(Next.js 16.2.x, React 19.2,
   Tailwind CSS v4, shadcn/ui, FastAPI 0.115 + Python 3.12, Supabase 등. 값은 개발 가이드 6장 표).
2. 개발 폴더에서 `claude`를 실행하고 `/agent-check`로 에이전트를 확인합니다.
   주 Opus(claude-main), 리뷰 Sonnet(claude-reviewer), 계획 공격 Fable(plan-challenger), 구현 Sonnet(도메인 expert).

### 5.3 로컬 DB

```bash
cd /d/WorkSpace/DEV/nomad-docs
supabase start
supabase db reset
mkdir -p apps/web/src/types
supabase gen types typescript --local --schema public > apps/web/src/types/supabase.ts
```

| 확인(Studio SQL 편집기) | 기대값 |
|---|---|
| `select count(*) from public.ai_routing_settings where org_id is null and app_id = 'docs'` | 13 |
| `select count(*) from public.doc_types where phase = 'mvp' and is_active` | 8(계약서 `dev_contract`는 법무 검토 전 비활성) |
| `select code, signup_credits, monthly_credits, is_active from public.plans where app_id = 'docs'` | free 50/30, pro 0/400, team 0/1500 비활성 |

RLS 권한 테스트 105개는 `supabase/tests/rls_smoke.sql`에 있습니다(실행법: 개발 가이드 7.3절).

### 5.4 착수 전 결정 (`docs/file/02-요구사항/01_PRD.md` 8절)

W0는 결정 없이 시작할 수 있습니다. 계약서 공개(D-3 법무 검토), 요금(D-4 베타 원가 측정 후)은 해당 웨이브 전에 정합니다.

### 5.5 첫 task 만들기와 지시 (W0의 DC-06-001)

```
tasks/DC-06-001-db-apply/
├── task.md      baseline(근거 산출물 ID), workers_approved, write_scope: supabase/**, apps/web/src/types/**
├── context.md
└── log.md       [APPROVAL], [DECISION] 기록
```

Claude Code에 보내는 요청(베이스 `_templates/dev-request-prompt.md` 형식):
```
D:/WorkSpace/DEV/nomad-docs/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.

[요구사항]
DC-06-001: supabase/migrations 의 core_lite 와 nomad_docs_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다(단독 프로젝트, public 스키마). 완료 조건 = ① supabase db reset 오류 0건
② ai_routing_settings 의 app_id='docs' 행 13건 ③ doc_types mvp 활성 8종(dev_contract 비활성)
④ supabase/tests/rls_smoke.sql 105항목 통과 ⑤ 타입을 apps/web/src/types/supabase.ts 에 저장
⑥ 06_AGENT_PLAN.md 의 DC-06-001 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/(tests/ 제외), apps/web/src/types/

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남긴다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

### 5.6 이후 순서

| 웨이브 | 작업(예) | 끝나면 생기는 것 |
|---|---|---|
| W0 | 001 DB, 004 web 골격, 005 워커 골격, 008 디자인 레퍼런스 | 로컬 DB, 빈 앱 골격 |
| W1 / W1-D | 002~020, 046 / 디자인 시스템 009 → 010(사람 검토) → 011 | 모놀리스 변환, RLS 러너, AI 서비스, 효과 엔진, 디자인 토큰 |
| W2~W4 | 인증·정본 API·결제 → 생성 그래프·문서 API·화면 1 → 패키지·내보내기·CRM 화면(061)·생성 애니메이션(062) | 체크리스트 → 문서 생성 → PDF |
| W5~W7 | 편집기·채팅 → 위키·KPI → 통합·E2E·AI 보안 회귀 | 공개 베타(MVP) |
| W8 | 연동(n8n, HubSpot, ERP), 숏폼 대행 패키지 | Phase 2 |

작업마다 `06_AGENT_PLAN.md` 2절의 "수용 기준"이 완료 조건이고, P0 작업은 대응 테스트 작업이 통과해야 완료입니다.
구현이 기획과 달라지면 코드를 조용히 맞추지 말고 산출물을 고치는 task를 따로 만듭니다.

## 6. 규칙

- 공용 폴더(`_platform-core/`, `_design-guide/`, `_supabase-modular/`)는 제품 작업에서 고치지 않고 각 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적습니다.
- DB 정본은 모듈러 조각(`_supabase-modular/migrations/<번호>_<스키마>.sql`)이고, 제품 모놀리스는 변환본입니다.
- 원격 DB 적용(`supabase db push`)은 사람이 확인 후 실행합니다.
- 기술 스택은 Tailwind CSS v4 고정(v3 문법·`tailwind.config.js` 금지).
- 이 저장소 변경은 브랜치 → PR → main 병합으로 합니다.

## 7. 현재 상태 (2026-10-14)

| 항목 | 상태 |
|---|---|
| 기획 | 13개 제품 완료. 검증 기록: `products/_supabase-modular/VERIFICATION.md`, `products/_STRUCTURE_CHECK.md` |
| 개발 묶음 | 13개 제품 완료(`develop/`) |
| 남은 결정 | 각 제품 `01_PRD.md` 8절. 공용 과제는 `products/README.md` "남은 코어 과제" |
