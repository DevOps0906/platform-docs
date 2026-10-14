# admin-suite(Admin Suite: ERP, HMS, SMS) 개발 방법

작성일 2026-10-13, 2026-10-14 개정(인증 단계 19장, 확정 결정 22). 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 admin-suite 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로, 확인하지 못한 값은 "구현 시 확인"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\admin-suite\setup-admin-suite.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/admin-suite/setup-admin-suite.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\admin-suite\        platform에 남는 안내서, 도구, 재료
├── admin-suite_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-admin-suite.sh          설치 스크립트(Git Bash / Linux)
├── setup-admin-suite.ps1         설치 스크립트(Windows PowerShell)
└── admin-suite-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\(erp, hms, sms 3세트)  infra\  .claude\
                │
                │ setup 스크립트가 복사(admin-suite-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\admin-suite\                          베이스를 복사해 만든 개발 폴더(모노레포 1개)
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← admin-suite-root에서 들어온 것(기존 폴더와 합쳐짐)
└── apps\  _shared\  _templates\  .claude\agents\  init-project.sh ...  ← 베이스에 원래 있던 것
```

| 단계 | 내용 | 절 |
|---|---|---|
| 준비 | 도구 설치, 공용 인프라, hms 전용 서버 준비 | 2 |
| 1~2 | setup 스크립트 실행(베이스 복사, 초기화, 묶음 붙여넣기, docs/etc 삭제, 에이전트 모델 지정) | 3, 4 |
| 3 | 최종 트리 확인 | 5 |
| 4 | project-profile 작성 | 6 |
| 5 | 로컬 DB 3개(erp, hms, sms)와 SQL 적용 | 7 |
| 6 | 착수 전 결정 확정, 산출물 승인 | 8 |
| 7 | 작업(60개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층(hms 전용 구성 포함), 개발 위키, 디자인 시스템, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계(Mock → Google·이메일 → 카카오·네이버) | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Admin Suite. 공유 코어 `packages/admin-kit` 위에 앱 3개: ERP(재고·판매·인사), HMS(병원 예약·대기열·환자·검사), SMS(학급·출석) |
| 통합 원본 | `D:\WorkSpace\platform\ERP-Wesite\`, `D:\WorkSpace\platform\Hospital\`, `D:\WorkSpace\platform\School_Management_System\` |
| 앱 id / 스키마 | `erp`, `hms`, `sms`. 모듈러 통합 DB를 쓸 때는 erp, sms만 `erp`, `sms` 스키마(hms는 통합 DB 제외, 확정 결정 2) |
| 이번 개발 방식 | 모노레포 1개(개발 폴더 1개)에 앱 3개, **Supabase 프로젝트는 3개**(앱마다 단독, `public` 스키마, 기획서 D-1). hms는 병원마다 프로젝트 1개 |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 사내 규정·매뉴얼 RAG, 기관 운영 위키, LangGraph `admin.assistant`, 채팅 업무 어시스턴트, 업무 음성 질의(erp, sms). hms는 환자 정보 없는 임상 가이드라인·운영 매뉴얼만, **전용 서버만** |
| 3D 히어로 | 적용 안 함(공개 랜딩 없음, 로그인 화면만 가볍게. `HERO_3D.md:92`, 03장 4.5절) |

**hms 특례(사용자 결정 2026-10-13)**: hms는 전용 서버(`hms-llm`, `hms-embed`, `hms-voice`)만 쓰고 상용 API, 공용 GPU·음성 서버, 공용 Dify를 쓰지 않습니다. hms 채팅은 Next.js → FastAPI 직접 경로입니다(11.1절).

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm 9 | 앱 3개와 admin-kit(pnpm workspace + Turborepo, 제안) | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB 3개 | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬 3개(메모리 여유 필요), Dify(erp, sms), 오픈소스 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스·hms 전용 LLM·음성 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- erp, sms: Anthropic, OpenAI, Google, OpenRouter(상용 LLM, FastAPI `api-shared` 전용), ElevenLabs(Next.js 서버 전용, 국외 이전 동의 조직만), Toss(Phase 2), Supabase
- **hms: 상용 키를 넣지 않습니다.** 개발 중에도 마찬가지이며, 넣으면 앱과 `api-hms`가 기동을 거부합니다(02장 5.5절). 필요한 값은 `HMS_LLM_BASE_URL`, `HMS_EMBED_BASE_URL`, `HMS_VOICE_BASE_URL`, `HMS_PHI_KEY_V1`, Supabase뿐입니다.

공용 인프라 설치 문서는 다음과 같습니다.

| 인프라 | 문서 | 사용 앱 |
|---|---|---|
| Dify(공용 1개) | `D:\WorkSpace\platform\docs\develop\_shared\dify\README.md` | erp, sms (hms 제외) |
| 오픈소스 음성 서버 | `...\_shared\voice\README.md` | erp, sms (hms 제외) |
| 오픈소스 LLM 서버(vLLM)와 상용 키 | `...\_shared\llm\README.md` | erp, sms (hms 제외) |
| hms 전용 AI 서버 세트 | 공용 문서에 없음. `infra/hms-ai/`에 제품 문서로 작성(ADM-06-055, 코어 요청 R-9) | hms |

## 3. 1단계: 베이스 복사와 초기화 (setup 스크립트가 처리)

setup 스크립트는 다음 6단계를 순서대로 처리합니다. 대상 폴더가 이미 있으면 중단하고, 베이스 원본은 읽기만 합니다.

| 순서 | 동작 |
|---|---|
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\admin-suite`로 복사 |
| 2 | **복사본 안의** `init-project.sh admin-suite --reset-git` 실행 |
| 3 | `admin-suite-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
| 4 | 복사본의 `docs/etc`(베이스 설명서 PDF 13MB) 삭제 |
| 5 | 에이전트 모델 지정(9.2절 표 참고) |
| 6 | 무결성 점검(`_shared/check-invariants.sh`) |

`init-project.sh`가 하는 일(베이스 `init-project.sh:1-84`)은 4가지입니다.
1. `_shared/project-profile.md`의 이름과 target_repo를 채웁니다.
2. 산출물 등록부 `docs/file/_index.md`를 만듭니다.
3. `--reset-git`이면 템플릿 git 이력을 끊고 `git init`을 합니다.
4. 무결성 점검을 합니다.

파일 복사, 커밋, 의존성 설치, 스캐폴딩은 하지 않습니다.

**주의: 반드시 복사본 안의 스크립트를 실행해야 합니다.** 스크립트는 자기 파일이 있는 폴더를 초기화합니다(`init-project.sh:10`, `ROOT=스크립트 위치`). 베이스 원본 폴더의 스크립트를 실행하면 원본이 초기화되고, `--reset-git`이면 원본의 git 이력이 지워집니다.

## 4. 2단계: 묶음 붙여넣기 (setup 스크립트가 처리)

- `admin-suite-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- `infra/dify/README.md`는 `build_root.py`의 공통 템플릿으로 만들어지며 앱 id가 `erp, hms, sms`로 적혀 있습니다. **Dify 앱은 `erp-assistant`, `sms-assistant` 2개만 만들고 hms는 만들지 않습니다**(04장 6.2절, 코어 요청 R-8). 이 불일치는 ADM-06-048이 `infra/dify/README.md`를 고칠 때 바로잡습니다(`build_root.py` 템플릿 수정 요청은 최종 보고에 있음).
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/admin-suite/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/admin-suite/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/admin-suite/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/admin-suite/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/admin-suite/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/admin-suite/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/admin-suite/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(DOC-CORE-009 `AUTH_ROADMAP.md`는 2026-10-14 인증 단계, 19장) |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/_design-guide/DASHBOARD_PATTERNS.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008 | 앱 화면 구조 패턴(A~O). `03_SCREENS_UX.md` 화면 표의 `패턴` 열과 화면 작업 지시(`DESIGN_SYSTEM.md` 10장)가 이 코드를 쓴다 |
| `docs/products/admin-suite/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/admin-suite/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/ERP-Wesite.md`, `Hospital.md`, `School_Management_System.md`, `basic-master-module.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/admin-suite/supabase/monolith/erp/migrations/0001_core_lite.sql`, `0002_erp_domain.sql` | `supabase/erp/migrations/20261013000001_core_lite.sql`, `20261013000002_erp_domain.sql` | - | DB(erp) |
| `docs/products/admin-suite/supabase/monolith/erp/seed.sql` | `supabase/erp/seed.sql` | - | DB(erp) |
| `docs/products/admin-suite/supabase/monolith/hms/` 같은 3개 | `supabase/hms/migrations/...`, `supabase/hms/seed.sql` | - | DB(hms) |
| `docs/products/admin-suite/supabase/monolith/sms/` 같은 3개 | `supabase/sms/migrations/...`, `supabase/sms/seed.sql` | - | DB(sms) |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | erp, sms 채팅 앱 설정 |

모듈러 조각 `docs/products/_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql`은 통합 DB용 정본이라 개발 폴더로 복사하지 않습니다. 문서에서 가리키는 곳은 `D:/WorkSpace/platform/...` 절대경로로 열 수 있습니다.

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 `PYTHONIOENCODING=utf-8 PYTHONUTF8=1 python -I ...\build_root.py admin-suite`로 묶음을 새로 만듭니다(검사 결과: 경로 참조 387개, 묶음 안 누락 0, 절대경로 누락 0).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\admin-suite\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 admin-suite-root에서 온 것, `[작업]`은 task가 만들 것입니다.

```
D:\WorkSpace\DEV\admin-suite\
├── CLAUDE.md                         [베이스] 오케스트레이터 운영 규칙(덮어쓰지 않음)
├── init-project.sh                   [베이스] 초기화 스크립트(1회 실행 완료)
├── INSTALL.md  README.md  요구사항_TASK_전환_Format.md   [베이스]
├── .claude\
│   ├── agents\                       [베이스] claude-main(Opus), claude-reviewer(Sonnet), plan-challenger(→Fable),
│   │                                          nextjs-expert·fastapi-expert·supabase-expert(→Sonnet), review-expert(Sonnet)
│   ├── commands\agent-check.md       [베이스]
│   └── skills\
│       ├── deliverable-first, nextjs-expert, fastapi-expert, supabase-expert, frontend-design, ui-ux-pro-max   [베이스]
│       └── llm-wiki\SKILL.md         [묶음] 개발 위키 스킬
├── _shared\                          [베이스] project-profile.md(6절에서 채움), orchestrator-rules.md, check-invariants.sh, adapters\ ...
├── _templates\                       [베이스] task.md, task-folder.md, worker-brief.md, ...
├── apps\
│   ├── web\  api\                    [베이스] 빈 자리표시자. web은 쓰지 않으므로 ADM-06-005가 apps\erp, hms, sms로 대체(제안)
│   ├── erp\  hms\  sms\              [작업] Next.js 16 앱 3개
│   └── api\                          [작업] FastAPI AI 서비스(코드 1개, 배포 2곳: api-shared(erp, sms), api-hms)
├── packages\admin-kit\               [작업] 공유 코어(supabase, auth, members, date, realtime, ui, theme, audit, billing, ai)
├── infra\
│   ├── dify\README.md                [묶음] erp-assistant, sms-assistant 설정 설명서(DSL은 작업이 추가)
│   └── hms-ai\                       [작업] hms 전용 AI 서버 세트 정의(ADM-06-055)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\                    [묶음] 00_MERGE_ANALYSIS.md, reviews\ 4개
│   ├── file\                         [묶음] _index.md(24개), 01-관리, 02-요구사항, 03-설계(공용코어 8개, 디자인 5개 + DESIGN.md, COMPONENTS.md), 04-구현
│   └── wiki\                         [묶음] WIKI_SCHEMA.md, index.md, log.md, sources\ 24개
├── supabase\
│   ├── README.md                     [베이스]
│   ├── erp\migrations\ 2개 + seed.sql    [묶음] ERP 프로젝트용
│   ├── hms\migrations\ 2개 + seed.sql    [묶음] HMS 프로젝트용(병원마다 프로젝트 1개)
│   └── sms\migrations\ 2개 + seed.sql    [묶음] SMS 프로젝트용
├── tests\ (rls, e2e, db, ai)         [작업]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 모노레포 | pnpm 9 workspace + Turborepo 2(제안), `packages/admin-kit` + `apps/{erp,hms,sms}` | `02_ARCHITECTURE.md` 1~2절 |
| 웹 | Next.js 16.x, React 19.x, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전, 구현 시 확인), lucide-react | `02_ARCHITECTURE.md` 1절 |
| 3D | 사용 안 함(three.js 계열 import 금지) | 같은 곳 |
| API(AI) | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 워커 | 없음(도메인 쓰기는 동기 RPC, AI 색인은 FastAPI 내부 큐) | `02_ARCHITECTURE.md` 4절 |
| DB | Supabase 프로젝트 3개(erp, hms, sms), `public` 스키마, pgvector | `05_DATA_MODEL.md` 8절 |
| 명령 | `pnpm install / dev / build / lint / typecheck / test:rls / test:e2e / test:ai / db:types --app <erp|hms|sms>`, `uv sync`, `uvicorn app.main:app --reload`, `pytest apps/api`, `supabase --workdir <앱별 프로젝트 폴더> start / db reset`(7절, 구현 시 확인) | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB 3개

개발 폴더는 하나지만 Supabase 프로젝트는 앱마다 따로입니다(erp, hms, sms는 DB를 공유하지 않으며 hms는 통합 DB에도 넣지 않습니다. 확정 결정 2). SQL은 `supabase/erp`, `supabase/hms`, `supabase/sms` 세 폴더에 나뉘어 들어옵니다.

| 순서 | 명령 형식(제안, 정확한 플래그는 구현 시 확인) | 설명 |
|---|---|---|
| 1 | 앱마다 CLI용 프로젝트 폴더를 만듭니다. `supabase/<app>/`의 `migrations/`, `seed.sql`을 CLI가 읽을 수 있는 위치로 연결(복사 또는 링크)하고, `config.toml`의 `project_id`와 포트를 앱마다 다르게 둡니다(예: `admin-suite-erp`, `admin-suite-hms`, `admin-suite-sms`) | 포트 충돌 방지. ADM-06-005가 `scripts/db/`에 래퍼를 둡니다 |
| 2 | `supabase --workdir <앱 프로젝트 폴더> start` | Docker로 앱 1개의 로컬 Supabase 기동. 3개를 동시에 켜면 메모리가 많이 듭니다. 필요한 앱만 켭니다 |
| 3 | `supabase --workdir <앱 프로젝트 폴더> db reset` | `migrations/`를 타임스탬프 순서로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `pnpm db:types --app <erp|hms|sms>` | 앱별 타입 생성(내부에서 `supabase gen types typescript --local` 계열 사용, 출력 경로는 제안: `apps/<app>/src/types/database.ts`) |

- `--workdir`이 가리키는 폴더에서 CLI가 `supabase/config.toml`을 찾는 구조인지, `supabase/<app>/`를 그대로 가리킬 수 있는지는 설치한 CLI 버전의 도움말로 구현 시 확인합니다.
- 각 `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. hms의 SECTION 11은 공용 제공자를 비활성화하고 `hms-*`만 활성으로 둡니다(`0001_core_lite.sql:2020-2034`). 각 `seed.sql` 끝에 AI 라우팅 기본값(erp 8행, sms 8행, hms 7행), 플랜 AI 키, `ai-docs` 버킷, 체인 검사가 있습니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`, 모듈러 13개 파일과 모놀리스 3세트 모두 OK). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 DB 작업(ADM-06-001~003)의 수용 기준입니다. 모듈러 조각(통합 DB) 검증은 platform 저장소의 체커로 하고, 개발 폴더에서는 위 모놀리스 3세트를 적용합니다.
- RLS 회귀 테스트는 ADM-06-034에서 `tests/rls/`로 옮깁니다. 기획 단계에서 확인한 항목(모듈러 92, erp 21, sms 19, hms 52)은 `docs/file/03-설계/05_DATA_MODEL.md` 9절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절). **hms 원격 프로젝트는 병원마다 따로 만들고 환자 데이터는 개발 환경에 넣지 않습니다.**

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 20개와 8.1절 인증 단계 결정 4개(D-21~D-24)를 확정합니다. 기획은 각 항목의 "권고"를 가정으로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 모놀리스 스키마(`public` 권고) | 착수 전(이 문서는 `public` 기준) |
| D-2 | SMS 교사 역할(teacher 추가 권고, SQL 반영됨) | SMS 착수 전(W0) |
| D-3 | ERP sales_manager 재고 권한(출고만 권고) | ERP 재고 화면(ADM-06-015) 전 |
| D-4 | HMS admin의 진료기록 열람(doctor 겸직 시만 권고) | 환자 360 차트(ADM-06-023) 전 |
| D-5 | 검사 승인 이중 확인(다른 사람만 권고) | 검사 화면(ADM-06-026) 전 |
| D-6 | 출시 과금(계약형 권고, Toss는 Phase 2) | 결제 작업(ADM-06-013) 전 |
| D-7 | 의료·미성년자 법령 세부(접속기록 보관, 진료기록 보존, 법정대리인 동의) | 법무 확인. HMS 출시 전, SMS 학생 초대(ADM-06-030) 전 |
| D-8 | School 작업 트리 삭제 의도 확인(HEAD 복원 권고) | SMS 이식(ADM-06-029) 전 |
| D-9 | 브랜드(상표 확인 전 "Admin Suite ERP/Hospital/School") | 로그인 화면(ADM-06-040) 전 |
| D-10 | AI 과금 방식: **확정 A**(플랜 포함 한도, 크레딧 미사용, 2026-10-13 사용자 결정) | 확정됨 |
| D-11 | erp, sms 기본 라우팅(auto + 국외 동의 게이트 권고) | AI 서비스 설치(ADM-06-045) 전 |
| D-12 | hms 전용 AI 서버 배치 단위(병원당 1세트 권고) | hms 전용 서버 정의(ADM-06-055) 전, 법무 확인 |
| D-13 | hms AI 범위(가이드라인·매뉴얼만 권고) | 착수 전, HMS AI 게이트(ADM-06-047) 전 확정 |
| D-14 | hms 질문 입력의 환자 식별정보 처리(차단 권고) | ADM-06-047 전 |
| D-15 | 문서 공개 범위 구조(컬렉션 고정 권고) | RAG 색인(ADM-06-049) 전 |
| D-16 | SMS 학생의 AI 접근(MVP 제외 권고) | AI 게이트·채팅 위젯(ADM-06-046, 052) 전 |
| D-17 | 위키 게시 승인(기관 관리자 검수 권고) | 위키 운영(ADM-06-050) 전 |
| D-18 | 채팅 위젯 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(ADM-06-041) 전 |
| D-19 | hms 음성 모델과 진료 구술(한국어 의료 용어 STT, TTS 라이선스 확인) | hms 음성·서버 작업(ADM-06-054, 055) 전 |
| D-20 | 위키 대상 컬렉션 범위(코어 RLS 개정 R-14 이전에는 구성원 전원 공개 컬렉션만) | 위키 운영(ADM-06-050) 전, R-14 상태 확인 |
| D-21 | hms Google 로그인(이메일·초대 메일만 권고, 병원 정책 확인 전 끔) | 병원별 출시 전(ADM-06-058) |
| D-22 | 카카오 로그인 이메일 정책(erp, sms, 비즈 앱 `account_email` 필수 권고) | C1 착수 전(D-24가 "도입"일 때만) |
| D-23 | 네이버 로그인 경로(`custom:naver` 또는 서버 브리지, 스파이크로 결정) | C2 스파이크 직후(D-24가 "도입"일 때만) |
| D-24 | erp·sms Stage C(카카오·네이버) 도입 여부(미정, P2 선택) | G2 판정 때(19.5절) |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 ADM-06-001~060, 모두 60개입니다. 그중 ADM-06-043은 사람이 하는 디자인 비주얼 검토입니다. ADM-06-058~060은 2026-10-14에 추가한 인증 단계 작업이고(19장, `06_AGENT_PLAN.md` 8절), 기존 ADM-06-007은 Stage A(Mock 로그인) 범위를 더했습니다. 059·060은 계획에 넣어 두고 D-24가 "도입"일 때만 실행합니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 005, 041 | 없음 | DB 조각·모놀리스 적용(AI 기본값 포함), 모노레포 골격, 디자인 레퍼런스(1단계) |
| W1 | 003, 004, 006, 008, 038, 039, 042, 045 | W0 | 모놀리스 검증, 변환기, admin-kit 기초, 디자인 토큰·기본 컴포넌트(2단계), AI 서비스 설치 |
| W1-D | 043 → 044(직렬) | 042 | 사람 비주얼 검토(3단계), 코드를 정답으로 확정(4단계). 앱 화면 작업의 진입 조건 |
| W2 | 007, 009, 010, 021, 034, 037, 049, 055 | 006, 001~003, 042, 045 | 가드, admin-kit UI, Realtime, PHI 계층, RLS·동시성 테스트, RAG 색인, hms 전용 AI 서버 정의 |
| W3 | 011, 012, 020, 028, 033, 040, 046, 047, 050, 051 | 007, 009, 044 | 가입 흐름, 앱 셸 3개, 로그인 화면, AI 게이트(erp·sms, hms), 위키 운영, 그래프 `admin.assistant` |
| W4 | 014, 015, 016, 022, 023, 029, 030, 048, 052, 056 | W3 | 앱 P0 화면, Dify 앱, 채팅 위젯, AI 평가셋 |
| W5 | 017, 018, 024, 025, 026, 031, 013, 053, 054 | W4 | 대시보드, 인사, 캘린더, 대기열, 검사, 출석, 결제, 업무 음성(erp·sms), hms 음성 |
| W6 | 058(G1 통과 후 먼저), 019, 027, 032, 035, 036, 057 | W5. 058은 `[DECISION] G1 통과` 후, 035·057의 B 구성 재실행은 058 완료 후 | Google·이메일·초대 메일 로그인 전환(Stage B), 잔여 화면, E2E, 결제 E2E, AI 보안·격리 회귀. **MVP 출시 조건** |
| W7 | 059, 060(G2 통과 후, D-24 "도입"일 때만) | MVP 출시 후 | 카카오·네이버 로그인(erp·sms만) |

같은 웨이브 안에서도 선행 작업 열이 우선합니다(예: 024 → 025, 030 → 031). 3D 히어로 작업은 없습니다.

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 수 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|---|
| Fable | 14 | 권한, RLS, 데이터 모델, AI 보안 경계(서명 토큰, 게이트, hms 격리), 인증 세션 경로(Stage A·B, 네이버 브리지) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`·`fastapi-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 30 | 기능 구현, 카카오 로그인, API 연동, 그래프, RAG, 위키, 음성, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | 11 | UI, 디자인 토큰·컴포넌트, 채팅 위젯, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 4 | 보일러플레이트, 린트·타입 정리 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 1 | 디자인 비주얼 검토(ADM-06-043) | 사용자 |

모델 작업 59개 기준 비율은 Fable 23.7%, Opus 50.8%, Sonnet 18.6%, Haiku 6.8%(규모 가중 27.4 / 53.8 / 15.1 / 3.8%)입니다. 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/ADM-06-002-hms-db-apply/
├── task.md      baseline에 산출물 ID, workers_approved, write_scope
├── context.md
└── log.md       [APPROVAL], [DECISION] 기록
```

`task.md`의 baseline 예시는 다음과 같습니다.

```yaml
baseline:
  - id: DOC-DES-004
    path: docs/file/03-설계/05_DATA_MODEL.md
  - id: DOC-CORE-003
    path: docs/file/03-설계/공용코어/SECURITY_BASELINE.md
  - id: DOC-MGT-002
    path: docs/file/01-관리/06_AGENT_PLAN.md   # ADM-06-002 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 DB 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/admin-suite/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
ADM-06-002: supabase/hms 의 core_lite(SECTION 11·12 포함)와 hms_domain, seed 를 로컬 Supabase(hms 전용 프로젝트)에 적용한다.
완료 조건 = ① db reset 오류 0건 ② 공용 AI 제공자 is_active=false, hms-llm/hms-embed/hms-voice 만 활성 확인
③ resolve_ai_route 가 모든 기능(admin.assistant, wiki.*, admin.knowledge, voice_chat)에서 hms-* 만 반환
④ patient_private, medical_records, lab_tests 에 authenticated SELECT GRANT 0 확인 ⑤ 06_AGENT_PLAN.md 의 ADM-06-002 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. hms 에는 상용 API 키·공용 서버 주소를 넣지 않는다. 작업 대상 경로: supabase/hms/, scripts/db/

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

## 10. 8단계: 웨이브별 개발 사이클

| 순서 | 내용 | 도구 |
|---|---|---|
| 1 | 웨이브 시작 전에 해당 결정(8절)이 확정됐는지, 산출물이 "승인"인지 확인 | `_index.md` |
| 2 | task 생성, baseline 지정, `workers_approved`·`write_scope` 기록 | `_templates/task.md` |
| 3 | 착수 전 계획 공격(고문) | `plan-challenger`(Fable) |
| 4 | 구현 | 도메인 expert(Sonnet), `gate.sh`·`scope_check.sh` 전후 실행 |
| 5 | 리뷰: 요구사항 → 설계 → 구현 → 테스트 추적성 | `claude-reviewer`, `review-expert` |
| 6 | 개발 위키 갱신(12절) | `llm-wiki` 스킬 |
| 7 | 완료: task status `done`, 웨이브의 모든 task가 끝나면 다음 웨이브 | - |

- **MVP 출시 조건**: W6까지 완료(인증 Stage B ADM-06-058 포함, 19장), AI 보안·격리 회귀(ADM-06-057) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).
- 앱 화면 task는 ADM-06-044(디자인 시스템 4단계)가 끝난 뒤에 시작합니다.

## 11. AI 계층 구축 (admin-suite)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절, `05_DATA_MODEL.md` 2.4·4.5절

| 구성 | admin-suite 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/`(llm 라우터, rag, wiki, graphs, tools, compliance). 코드 1개, 배포 2곳(`api-shared`: erp·sms, `api-hms`: hms 전용) | ADM-06-045 |
| 모델 라우팅 | erp, sms: 상용(Claude → ChatGPT → Gemini)과 오픈소스 병행, 국외 이전 동의가 없으면 오픈소스만. seed의 `ai_routing_settings` erp 8행, sms 8행(위키 작업·음성·임베딩은 오픈소스 우선, Dify 보조 노드는 오픈소스 강제). hms 7행은 전부 `hms-*` 강제 | ADM-06-001~003, 045, 057 |
| 국외 이전 동의 | erp, sms 설정 화면 `/settings/ai`(owner, `set_ai_cross_border_ack`). hms에는 없음 | ADM-06-046 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑, EdDSA 토큰, 하루 질문 한도. **크레딧 선차감은 없음**(플랜 포함 한도, D-10) | ADM-06-046(erp, sms), 047(hms) |
| RAG | 역할별 컬렉션 9개(erp 3, sms 3 `sms-guide-all` 포함, hms 3, 01장 3.7절), 업로드 검증(개인정보·환자 정보 탐지), `ai-docs` 버킷, 평가셋 | ADM-06-049, 056 |
| 운영 위키 | 기관별 위키. "위키 대상" 컬렉션 문서만(D-20, R-14 전) | ADM-06-050 |
| LangGraph | `admin.assistant`: `permission`(DB 역할 → 허용 컬렉션) → `retrieve` → `answer` → `compliance`. 읽기 전용, 도구 없음 | ADM-06-051 |
| Dify 채팅 | erp, sms만: `erp-assistant`, `sms-assistant` Chatflow. 입력 `platform_conversation_id`, HTTP 노드 → `/tools/answer`(앱별 내부 키) | ADM-06-048 |
| 채팅 위젯 | `packages/admin-kit/src/ai/chat/`(마이크 UI 포함) | ADM-06-052 |
| 음성 | erp, sms: STT·TTS 모두 오픈소스 우선, 동의 시 ElevenLabs로 대체. hms: `hms-voice`만 | ADM-06-053, 054 |
| hms 전용 서버 | `infra/hms-ai/` | ADM-06-055 |
| 보안·격리 회귀 | 서명 토큰, 대화 매핑, 역할 경계, 코어 RLS 한계, hms 격리 | ADM-06-057 |

순서는 이렇습니다.
1. erp, sms용 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다. 준비 전에는 라우팅을 상용만 쓰도록 두고 국외 동의가 있는 테스트 조직으로 개발합니다.
2. hms는 공용 인프라를 쓰지 않습니다. `infra/hms-ai/`의 목(stub) 서버로 앱과 FastAPI를 개발하고, 실제 전용 서버 세트는 ADM-06-055 산출물로 병원 환경에 설치합니다.
3. 코어 RLS 한계(R-14)가 해결되기 전까지 `ai_runs`에는 본문을 쓰지 않고 위키는 구성원 전원 공개 컬렉션만 만듭니다(`02_ARCHITECTURE.md` 5.3절 8항).

### 11.1 hms 전용 서버 (사용자 결정 2026-10-13)

| 항목 | 규칙 |
|---|---|
| 서버 | 병원 1곳 = hms 앱 + Supabase + `api-hms` + `hms-llm` + `hms-embed` + `hms-voice`(D-12 권고). 위치는 구현 시 확인 |
| 금지 | 상용 API, 공용 GPU·음성 서버, 공용 Dify, ElevenLabs. 개발 환경도 같음 |
| 경로 | 채팅은 Next.js → FastAPI `/tools/answer-direct`(서명 토큰). 음성은 Next.js `/api/voice/*` → `hms-voice` |
| 기동 검사 | 금지 변수(`DIFY_*`, 상용 키, `OSS_*_BASE_URL`, `VOYAGE_API_KEY`, `ELEVENLABS_API_KEY`)가 하나라도 있으면 앱과 `api-hms` 기동 실패 |
| 대체 | 전용 서버 장애 시 다른 서버로 대체하지 않고 `AI_UNAVAILABLE` |
| 데이터 | 환자 식별정보는 질문·문서로 반입 금지(탐지·차단). FastAPI는 환자 테이블을 읽지 않고 `HMS_PHI_KEY_*`를 받지 않음 |
| 확인 | 의료기기 해당 여부와 광고 문구는 법무 확인(미확인, 01장 6.6절) |

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보(hms는 환자 정보 포함)는 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 24개)는 setup 시 함께 들어옵니다.
- 이 위키는 **개발용**입니다. 제품 안의 기관 운영 위키(DB `core.wiki_pages`)와 다릅니다.

## 13. 디자인 시스템과 로그인 화면

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템(13.2 메인 히어로는 적용하지 않음). 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 주 Primer(정보 밀도), 보조 Atlassian(권한·상태 배지), AI 채팅은 Astryx 패턴(확인 후, D-18) | ADM-06-041, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 4.3절 토큰 플랜(ERP 코발트, HMS 야간 병동, SMS 칠판 인디고) + Tailwind CSS v4 `@theme` → `apps/<app>/src/theme/tokens.css`, `packages/admin-kit/src/ui/` 기본 컴포넌트, 앱별 `/dev/components` | ADM-06-042 |
| 3. 비주얼은 사람이 | 앱 3개의 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | ADM-06-043(사람) |
| 4. 정답을 한 곳으로 | 코드를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | ADM-06-044 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 주의: `build_root.py`가 만든 `DESIGN.md`·`COMPONENTS.md` 초기 템플릿은 토큰 경로를 `apps/web/src/styles/tokens.css`로 적고 있습니다. admin-suite의 정답 경로는 `apps/<app>/src/theme/tokens.css`이므로 ADM-06-041이 1절을 채울 때 바로잡습니다.

### 13.2 메인 히어로: 적용하지 않음

공개 랜딩이 없는 업무용 앱이라 3D 히어로 표준(`HERO_3D.md`)에서 제외됩니다(`HERO_3D.md:92`, `03_SCREENS_UX.md` 4.5절). 로그인 화면은 좌측 정렬 2열(4.3절 안 B)에 앱 주제 그림 1개(인라인 SVG)만 두고, 3D 라이브러리·로드 시퀀스·스크롤 연동을 쓰지 않으며 `prefers-reduced-motion`에서 모션이 없습니다(ADM-06-040). 공개 랜딩이 생기면 그 랜딩에만 표준을 적용합니다.

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` admin-suite 절(`:163`)에 있습니다.

| 구분 | 제목 | 출처 | URL | 참고 포인트(가져올 것) | 적용 화면 |
|---|---|---|---|---|---|
| 앱 | ERP/Admin Dashboard | Dribbble | https://dribbble.com/shots/25055107-ERP-Admin-Dashboard | 시스템 상태, 재무 지표, 사용자 활동을 한 화면에서 보는 운영 요약 | ERP 홈, HMS 관리자 대시보드 |
| 앱 | Table data view for admin dashboard | Dribbble | https://dribbble.com/shots/22988094-Table-data-view-for-admin-dashboard | 행 선택 상태, 페이지네이션, 페이지당 행 수 드롭다운 | admin-kit DataTable |
| 앱 | School Management Dashboard (MindInventory) | Dribbble | https://dribbble.com/shots/21026510-School-Management-Dashboard | 출결·시간표를 한눈에 보는 위젯과 필터 | SMS 홈 |
| 앱 | Student Attendance Management System | Dribbble | https://dribbble.com/shots/20456718-Student-Attendance-Management-System-School-Admin-Dashboard | 출결 추적, 보고서, 결석 알림의 흐름 | SMS 출석 |
| 앱 | School Management Dashboard (CMARIX) | Dribbble | https://dribbble.com/shots/6372267-School-Management-Dashboard | 학생/직원 기록, 출결, 수납을 한 플랫폼에서 다루는 메뉴 구조 | SMS·HMS 내비게이션 구조 |

- 이 제품은 공개 랜딩이 없어(13.2) Dribbble 레퍼런스만 씁니다.
- URL은 이 표와 `REFERENCES.md`에 있는 것만 씁니다. 새 레퍼런스가 필요하면 URL을 직접 열어 확인하고 `REFERENCES.md`에 먼저 추가한 뒤 씁니다.
- 영감용이지 복제용이 아닙니다. 로고·사진·일러스트·아이콘·카피·폰트·색 조합 전체를 가져오지 않고, 레이아웃을 따라 그리지 않습니다. 구조(정보 배치, 위계, 리듬)만 참고하고 토큰은 제품 주제에서 다시 뽑습니다(`03_SCREENS_UX.md` 4.3절).
- Dribbble 링크는 작업 전에 브라우저에서 한 번 엽니다(자동 확인이 막혀 있어 색인으로만 확인됨). 열리지 않으면 `REFERENCES.md`에서 지우고 다른 후보를 씁니다.
- 순서: 레퍼런스(이 절) → 브리프(4.2절) → 토큰 플랜(4.3절) → 13.1 디자인 시스템 → 13.2(히어로 미적용). AI에게 화면을 맡길 때 지시에 이 표의 행(제목과 "참고 포인트")을 적습니다.
- 화면·랜딩 task의 `task.md` baseline에는 아래 3개를 넣습니다. 06장의 레퍼런스 확정 task와 랜딩 task 수용 기준에도 같은 레퍼런스 확인이 들어 있습니다.

```yaml
baseline:
  - id: DOC-DES-002
    path: docs/file/03-설계/03_SCREENS_UX.md   # 4.1절 레퍼런스 표, 4.2 브리프, 4.3 토큰 플랜
  - id: DOC-DSN-005
    path: docs/file/03-설계/디자인/REFERENCES.md   # 이 제품 절, 복제 금지 규칙
  - id: DOC-DSN-001
    path: docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md   # 1단계 레퍼런스 수집, 7단계 체크리스트
```

- 확인: 결과 스크린샷을 이 표의 "참고 포인트"와 나란히 놓고, 가져오지 않기로 한 요소(로고·카피·기본값 스타일)가 섞이지 않았는지 고문 디자인 검토에서 대조합니다.

## 14. 원본 이식

정본: `docs/file/04-구현/07_SOURCE_MIGRATION.md`

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장의 "가져올 것" 목록에서 필요한 파일만 옮기고 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\ERP-Wesite\`, `D:\WorkSpace\platform\Hospital\`, `D:\WorkSpace\platform\School_Management_System\`(School은 nested 저장소 HEAD `3c19d1e`를 `git show`로 읽어 이식, 작업 트리 삭제 의도는 원작성자 확인 D-8)
- 세 원본에는 AI 기능이 없어 AI 이식 자산은 없습니다(전부 신규).
- 리뷰 "높음" 14건의 차단 설계는 `02_ARCHITECTURE.md` 6절과 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: Hospital OVERRIDE 비밀번호, 클라이언트 PageGuard, Tailwind v3식 설정)은 옮기지 않습니다. 원본은 이식 완료 뒤 `archive/`로 옮기고 키를 재발급합니다(07장 5절).

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| admin-kit | `packages/admin-kit/src/{supabase,auth,members,date,realtime,ui,theme,audit,billing,ai}`는 앱 이름(`erp`, `hms`, `sms`)을 하드코딩하지 않습니다. 앱이 설정 객체로 주입합니다 |
| 앱 → 앱 | 앱끼리 import하지 않습니다 |
| hms | `apps/hms`는 Dify 클라이언트와 ElevenLabs 구현을 import하지 않고, hms 코드·키·데이터를 통합 DB나 다른 앱과 섞지 않습니다 |
| AI 서비스 | `apps/api` 1개 코드베이스. 업무·환자 테이블을 읽지 않고 허용 목록 테이블만 씁니다 |
| 공용 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service`, 공용 Dify·GPU 서버는 수정하지 않습니다(필요하면 06장 6절 R-6~R-11 요청) |
| 남은 코어 과제 | R-14(코어 RLS 개정, 높음), R-13(jobs 선택 절), R-12(통합 seed AI 키) 등. `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다(빌드, 타입, 린트, SQL 체커, RLS 스모크, E2E, AI·hms 격리, 디자인 시스템 4단계).

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 3개와 로컬 메모리 | 필요한 앱만 켭니다. erp, sms는 고객사가 적을 때 통합 DB(모듈러, `1600_erp.sql`, `1700_sms.sql`)로 시작하는 선택지가 있습니다(`README.md` 5절). hms는 항상 별도입니다 |
| hms 의료정보 | 환자 데이터를 개발 환경에 넣지 않습니다. AI는 환자 정보를 입력·색인하지 않고 전용 서버만 씁니다. `HMS_PHI_KEY_*`는 앱 서버에만 둡니다 |
| 코어 RLS 한계 | 직원·학생이 PostgREST로 위키·run을 직접 읽을 수 있습니다. 본문 금지, 위키 대상 제한 규칙을 지키고 R-14 해결을 추적합니다 |
| AI 과금 한도 조정 | 크레딧을 쓰지 않고 한도만 둡니다(D-10 A 확정). 운영 중 `ai_usage` 원가를 보고 한도를 조정합니다 |
| 법무 미확인 | 접속기록·진료기록 보존, 법정대리인 동의, 의료기기 해당 여부, 국외 이전 동의 방식은 법무 확인 전 확정하지 않습니다 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 앱 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비(erp, sms): Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만). hms: 전용 서버 또는 목 서버 계획
- [ ] 앱별 로컬 Supabase 기동과 `db reset` 성공(7절): erp, hms, sms
- [ ] 결정 D-1~D-20 확정, 산출물 "승인" 전환(8절). 인증 결정 D-21~D-24는 19장 시점에
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] 앱별 로컬 시드 페르소나 생성과 Mock 로그인 확인(19.2절)
- [ ] W1~W5 진행 → G1 판정(19.3절) → W6(Stage B 058 먼저), AI 보안·격리 회귀 통과, MVP 출시 조건 충족
- [ ] 첫 기관 배포 후 G2 판정과 D-24 결정(19.5절)
- [ ] 코어 요청 R-14 상태 확인

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(확정 결정 22, 2026-10-14). 제품 반영: `docs/file/02-요구사항/01_PRD.md` KIT-F-005·006·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙".

처음에는 Mock 로그인으로 세 앱의 MVP 기능을 완성하고, 기능이 안정되면 Google·이메일·초대 메일 로그인을 붙이고, 그것이 안정되고 고객 기관이 원하면 erp·sms에 카카오·네이버를 붙입니다. 세션은 처음부터 실제 Supabase JWT이므로 단계가 바뀌어도 `createAdminProxy`·`requireRole`·RLS 코드는 바뀌지 않습니다. admin-suite는 권한이 운영자가 만든 기관 조직에 있어 `finishLogin`이 활성 기관 멤버십을 먼저 찾습니다(`02_ARCHITECTURE.md` 9.2절).

### 19.1 단계 요약

| 단계 | 언제 | erp | sms | hms | 작업 | 끝나는 조건 |
|---|---|---|---|---|---|---|
| A Mock | W2부터 W5까지(MVP 기능 개발) | 시드 페르소나 원클릭 로그인. 상단 배지 `MOCK AUTH · 로컬 전용` | 같음 | 같음(로컬 hms 프로젝트만) | ADM-06-007(W2) | G1(19.3절) |
| B | G1 통과 후, 첫 기관 배포 전(W6 맨 앞) | Google + 이메일 가입·메일 인증·재설정 | Google + 초대 메일(비밀번호 설정) | 초대 메일 + 이메일만(D-21) | ADM-06-058(P0, Fable, M) | G2(19.5절) |
| C1 카카오 | G2 통과 + D-24 "도입"(W7) | 카카오 | 카카오 | 제외 | ADM-06-059(P2, Opus, S) | `AUTH_ROADMAP.md` 7.1.3절 |
| C2 네이버 | G2 통과 + D-24 "도입"(W7, C1과 병렬) | 네이버(`custom:naver` 또는 브리지) | 같음 | 제외 | ADM-06-060(P2, Fable, M) | `AUTH_ROADMAP.md` 7.2.4절 |

### 19.2 Stage A 로컬 실행 순서 (앱 하나씩)

| 순서 | 명령·행동 | 설명 |
|---|---|---|
| 1 | `supabase --workdir <앱 프로젝트 폴더> start` | 7절의 앱별 로컬 Supabase. 필요한 앱만 켭니다 |
| 2 | `supabase --workdir <앱 프로젝트 폴더> db reset` | 마이그레이션과 seed 적용(7절) |
| 3 | `apps/<app>/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<임의의 긴 값>` | 커밋하지 않습니다. `NEXT_PUBLIC_*`에 넣지 않습니다. Supabase URL이 로컬이 아니면 앱이 기동하지 않습니다 |
| 4 | `node scripts/dev/seed-users.mjs --app <app>`(`<app>`은 erp, sms, hms 중 하나, 그 앱 프로젝트의 `SUPABASE_URL`로) | 공통 페르소나(owner, admin, member, viewer, outsider, no_app, suspended, ops)와 앱 훅(erp `pending`·`inventory_manager`·`sales_manager`·`join_requested`·`join_rejected`, sms `student`·`invited`, hms `doctor`·`lab_tech`·`invited`)을 만듭니다. owner·outsider는 운영자 프로비저닝 경로(7절 CLI와 같은 순서)로 기관 조직 "개발 기관 A·B"를 만듭니다. 원격 URL이면 즉시 종료, 두 번 실행해도 사용자 수 같음, 비밀번호는 출력하지 않습니다. hms 훅은 환자 데이터를 만들지 않습니다 |
| 5 | `pnpm --filter <app> dev` 후 `/login` | 개발용 패널에서 페르소나 버튼을 누르면 역할 홈(`access.ts`). erp `pending`은 `/pending`, sms·hms `invited`는 `/invite/accept`, `viewer`·`no_app`(sms·hms)은 `/no-access` |
| 6 | E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장합니다(ADM-06-035) |

페르소나별 기대 결과는 `docs/file/03-설계/05_DATA_MODEL.md` 10절입니다. 권한 분기는 페르소나를 바꿔 로그인해서 확인하고, 기능 코드에서 페르소나 이메일로 분기하지 않습니다. erp·sms를 모듈러 통합 DB로 개발하면 `--app erp --app sms`를 한 번에 줄 수 있습니다(`05_DATA_MODEL.md` 10.5절).

### 19.3 G1 체크리스트 (사람이 판정)

- [ ] `06_AGENT_PLAN.md` 2절 MVP P0 기능 작업 완료(W5까지. 인증 B·C 작업과 W6의 035·057 출시 마무리 제외)
- [ ] 역할×경로 E2E(ADM-06-035)가 세 앱 Mock 페르소나로 로컬 녹색
- [ ] RLS 스모크(ADM-06-034) 전 항목 통과, `outsider` 교차 테넌트 거부(세 앱)
- [ ] 결제 E2E는 Phase 2(ADM-06-013·036)라 G1 조건에서 뺍니다(`06_AGENT_PLAN.md` 8.2절)
- [ ] CI: 인증 모듈 밖 `AUTH_MODE`·`AUTH_PROVIDERS` 참조 0, `mock-auth`·쿠키 역할 0(ADM-06-039 린트), `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패(ADM-06-007 빌드 시 env 검사)
- [ ] 외부 준비(erp·sms): Google Cloud 프로젝트, OAuth 동의 화면(앱 이름은 D-9, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL, 승인된 도메인), 웹 클라이언트 ID, 첫 기관 배포용 Supabase 프로젝트. hms: 병원 Supabase 프로젝트의 Email 제공자와 초대 메일 템플릿만
- [ ] 결과를 ADM-06-058 task `log.md`에 `[DECISION] G1 통과`로 기록

### 19.4 Stage B 외부 설정 순서 (`AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위 `openid`, `email`, `profile`만 | erp·sms만. 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬은 그 앱 프로젝트의 API 포트 `/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다. 고객사별 모놀리스로 가면 프로젝트마다 URI가 늘어납니다(`02_ARCHITECTURE.md` 9.4절) |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용(erp·sms 프로젝트). 로컬은 `config.toml` `[auth.external.google]`의 `env(GOOGLE_CLIENT_ID)` | 앱 env에는 넣지 않습니다. hms 병원 프로젝트는 Email만 켭니다(D-21) |
| 4 | Authentication → URL Configuration: Site URL = 앱 운영 도메인, Redirect URLs = `https://<앱 도메인>/auth/callback`(Vercel 미리보기 도메인은 명시 등록) | 프로젝트마다. 와일드카드 지양 |
| 5 | 초대 메일 템플릿(sms·hms)과 확인 메일 템플릿(erp)의 링크가 `/auth/callback`을 거치는지 확인 | 초대 메일의 비밀번호 설정 후 `/invite/accept` |
| 6 | 동의 화면을 "프로덕션"으로 게시 | 첫 기관 배포 전 |
| 7 | 배포 env: `AUTH_MODE=live`, `AUTH_PROVIDERS` erp·sms `google,email`, hms `email` | 배포 체크리스트(B-6). hms는 `email` 외 값이면 기동 실패 |
| 8 | 수동 점검표: erp·sms Google 데스크톱·모바일 각 1회(신규·기존 계정), 세 앱 초대 메일 수락 1회 | 결과를 task `log.md`에(B-5). 실제 Google 로그인은 자동화하지 않습니다 |

### 19.5 G2 체크리스트 (사람이 판정)

- [ ] 첫 기관 배포 후 Google·이메일 실로그인 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안, 감사 `auth.login`과 오류 로그)
- [ ] erp OAuth·이메일 신규 사용자 중 pending 프로필 없이 남은 사용자(`/pending` 미도달) 0, 기존 활성 구성원 pending 강등 0, sms·hms 초대 수락 실패(링크 만료 제외) 0(제안, open 앱용 `entitled=false` 조건 대신, `06_AGENT_PLAN.md` 8.2절)
- [ ] D-24 결정: 고객 기관 요청이 있으면 "도입", 없으면 "도입하지 않음"(059·060 취소)
- [ ] "도입"이면 카카오 디벨로퍼스 앱 생성과 이메일 정책 D-22(비즈 앱 전환 권장), 네이버 애플리케이션 등록과 검수 자료 준비
- [ ] 결과를 `[DECISION] G2 통과`, `[DECISION] D-24 ...`로 기록

### 19.6 C1 카카오 설정 (erp·sms, `AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = erp·sms Supabase 프로젝트 콜백(`https://<project-ref>.supabase.co/auth/v1/callback`). hms 병원 프로젝트는 등록하지 않습니다 |
| 4 | 카카오 로그인 활성, 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email`(D-22 (a) 권장: 초대·가입 승인이 이메일 기준) |
| 5 | Supabase → Providers → Kakao 사용(로컬 `[auth.external.kakao]`) |
| 6 | 배포 env `AUTH_PROVIDERS=google,email,kakao`(erp·sms), 설정 → 로그인 방법 화면 확인(`03_SCREENS_UX.md` 7.4절) |

### 19.7 C2 네이버 스파이크와 검수 (erp·sms, `AUTH_ROADMAP.md` 7.2.2절)

| 단계 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`provider_type: 'oauth2'`, authorize·token·`/v1/nid/me` 엔드포인트). 등록은 `scripts/auth/register-naver-provider.mjs`(제안)로 남깁니다 | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 등록한 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 채워졌는지, 재로그인이 같은 사용자인지 | 둘 다 참이면 `supabase_custom` 채택 |
| 4 | 실패하면 브리지 경로(`04_API.md` 8.3절 `/auth/naver/start`·`/auth/naver/callback`)를 택하고 코어 요청 R-15(`staged/0010_core_auth_identity_links.sql` 적용, 사람이 승인). 결과를 `NAVER_AUTH_PATH`와 `[DECISION]`(D-23)에 기록 | 기록 |
| 5 | 네이버 검수 신청(로그인 버튼부터 가입 완료까지 화면 캡처). 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다(C2-6) | 검수 통과 |

로컬 Supabase CLI가 커스텀 제공자를 지원하는지는 미확인입니다. 지원하지 않으면 로컬은 Mock·Google·카카오로 개발하고 네이버는 스테이징 프로젝트에서 확인합니다.

### 19.8 단계 전환 요청 프롬프트 예시 (G1 통과 후 Stage B)

베이스 `_templates/dev-request-prompt.md` 형식을 따르며 9.4절 예시를 본떴습니다.

```
D:/WorkSpace/DEV/admin-suite/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. 특히 docs/file/03-설계/공용코어/AUTH_ROADMAP.md 0·3·5장과 06_AGENT_PLAN.md 8절)

[요구사항]
ADM-06-058: 인증 Stage B로 전환한다. erp = Google + 이메일 가입·메일 인증·비밀번호 재설정, sms = Google + 초대 메일, hms = 초대 메일 + 이메일만.
전제 = log.md 에 [DECISION] G1 통과 기록이 있다(없으면 시작하지 않고 보고).
완료 조건 = ① 06_AGENT_PLAN.md 8.1절 058 수용 기준(AUTH_ROADMAP.md 5.3절 B-1~B-6의 앱별 해석)
② /auth/callback 이 finishLogin(코드 교환 → 활성 기관 멤버십 → erp만 bootstrap_app_for_org 1회 → status 분기 → next 화이트리스트)을 거친다
③ 첫 OAuth 로그인 약관 단계: erp /pending 첫 단계, sms·hms /invite/accept(03_SCREENS_UX.md 7.3절)
④ hms 로그인 화면에 Google 버튼 0, AUTH_PROVIDERS 가 email 이 아니면 기동 실패
⑤ Mock E2E(ADM-06-035)가 계속 녹색이고 세 앱 배포 빌드에서 /api/dev/login 404.

[작업의 특성]
권한 경계 작업. 단계 분기는 packages/admin-kit/src/auth/ 와 앱의 (auth)/, auth/callback/, api/dev/login/ 안에서만. Google 콘솔·Supabase 대시보드 설정은 사람이 하고(AUTH_ROADMAP.md 5.1절) 에이전트는 체크리스트만 만든다.
작업 대상 경로: packages/admin-kit/src/auth/{callback,providers,terms}/, apps/{erp,sms,hms}/src/app/auth/callback/, apps/{erp,sms,hms}/src/app/(auth)/, supabase/<app>/config.toml(erp·sms Google 절), docs/admin-suite/ops/auth-checklist.md

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

C1·C2도 같은 형식으로 요청하되 전제를 `[DECISION] G2 통과`와 D-24 "도입"으로, 완료 조건을 `AUTH_ROADMAP.md` 7.1.3절(C1-1~C1-5) 또는 7.2.4절(C2-1~C2-6)로, 대상 앱을 erp·sms로 바꿉니다.

### 19.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 우선순위·규모·모델 | 웨이브 |
|---|---|---|---|
| A | ADM-06-007(범위 추가: 인증 단계 모듈, Mock 로그인, 시드와 앱 훅 3개, `finishLogin` 기관 조직 분기) | P0, M, Fable | W2 |
| A(화면) | ADM-06-014·022·029(로그인 화면 A 구성, 개발용 패널 장착) | P0, M, Opus | W4 |
| B | ADM-06-058 | P0, M, Fable | W6 맨 앞(G1 후) |
| C1 | ADM-06-059(erp·sms, D-24 "도입"일 때만) | P2, S, Opus | W7(G2 후) |
| C2 | ADM-06-060(erp·sms, D-24 "도입"일 때만) | P2, M, Fable | W7(G2 후) |

## 부록 A. 스크립트 없이 손으로 할 때

`admin-suite-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\admin-suite\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/admin-suite"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\admin-suite" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\admin-suite" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/admin-suite"` | `Set-Location "D:\WorkSpace\DEV\admin-suite"` | `cd /d "D:\WorkSpace\DEV\admin-suite"` |
| 3 초기화 | `bash init-project.sh admin-suite --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh admin-suite --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh admin-suite --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/admin-suite/admin-suite-root/." "D:/WorkSpace/DEV/admin-suite/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\admin-suite\admin-suite-root\*" "D:\WorkSpace\DEV\admin-suite" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\admin-suite\admin-suite-root" "D:\WorkSpace\DEV\admin-suite" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬 3개, Dify, 오픈소스 서버).
