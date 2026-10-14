# stock-dashboard(Stock Dashboard) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 stock-dashboard 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다. 이 제품은 돈과 금융 규제가 걸린 초대제 베타이므로 애매한 항목은 멈추고 사용자에게 묻습니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\stock-dashboard\setup-stock-dashboard.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/stock-dashboard/setup-stock-dashboard.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\stock-dashboard\        platform에 남는 안내서, 도구, 재료
├── stock-dashboard_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-stock-dashboard.sh          설치 스크립트(Git Bash / Linux)
├── setup-stock-dashboard.ps1         설치 스크립트(Windows PowerShell)
└── stock-dashboard-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(stock-dashboard-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\stock-dashboard\                          베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← stock-dashboard-root에서 들어온 것(기존 폴더와 합쳐짐)
└── apps\  _shared\  _templates\  .claude\agents\  init-project.sh ...  ← 베이스에 원래 있던 것
```

| 단계 | 내용 | 절 |
|---|---|---|
| 준비 | 도구 설치, API 키 준비 | 2 |
| 1~2 | setup 스크립트 실행(베이스 복사, 초기화, 묶음 붙여넣기, docs/etc 삭제, 에이전트 모델 지정) | 3, 4 |
| 3 | 최종 트리 확인 | 5 |
| 4 | project-profile 작성 | 6 |
| 5 | 로컬 DB 기동과 SQL 적용 | 7 |
| 6 | 착수 전 결정 확정, 산출물 승인 | 8 |
| 7 | 작업(51개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 디자인 시스템과 3D 히어로, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Stock Dashboard. 본인이 연결한 증권사 계좌(1차는 모의투자)의 잔고·보유·체결을 한 화면에서 조회하고, 공시 요약과 용어 설명 AI를 제공하는 초대제 개인 투자 대시보드. 종목 추천과 매수가·목표가·손절가는 제공하지 않음 |
| 통합 원본 | `D:\WorkSpace\platform\구현해야 할 프로젝트\Stock_Trader_nomad`(문서 2개뿐, 코드 없음) |
| 모듈러 앱 id / 스키마 | `stock` / `stock` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D-1). 금융 데이터 격리가 이유입니다(`docs/file/01-관리/README.md` 5절) |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 공시 RAG, 리서치 요약·진단 그래프, 주식 용어 위키, 공시·용어 채팅(Dify), 음성 질의와 브리핑 낭독. 모든 출력은 투자 권유 금지 검사를 통과해야 합니다 |
| 게이트 | 초대제 베타 게이트(`beta_access`)를 유지합니다. 유사투자자문업 법률 의견(D-3)이 오기 전에는 무료이며 AI 범위를 사실 요약에서 넓히지 않습니다 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), 워커 2개 | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM, FastAPI 전용)
- ElevenLabs(음성, Next.js 서버 전용)
- DART 오픈API(공시, 재무지표)
- 증권사 모의투자 키(spike ST-06-004 뒤에 선정. 실키는 커밋하지 않음)
- Supabase, Toss Payments(Phase 2)

공용 인프라 설치 문서는 다음과 같습니다.

| 인프라 | 문서 |
|---|---|
| Dify(공용 1개) | `D:\WorkSpace\platform\docs\develop\_shared\dify\README.md` |
| 오픈소스 음성 서버 | `...\_shared\voice\README.md` |
| 오픈소스 LLM 서버(vLLM)와 상용 키 | `...\_shared\llm\README.md` |

## 3. 1단계: 베이스 복사와 초기화 (setup 스크립트가 처리)

setup 스크립트는 다음 6단계를 순서대로 처리합니다. 대상 폴더가 이미 있으면 중단하고, 베이스 원본은 읽기만 합니다.

| 순서 | 동작 |
|---|---|
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\stock-dashboard`로 복사 |
| 2 | **복사본 안의** `init-project.sh stock-dashboard --reset-git` 실행 |
| 3 | `stock-dashboard-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `stock-dashboard-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/stock-dashboard/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/stock-dashboard/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/stock-dashboard/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/stock-dashboard/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/stock-dashboard/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/stock-dashboard/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/stock-dashboard/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 8개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~008 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/_design-guide/DASHBOARD_PATTERNS.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008 | 앱 화면 구조 패턴(A~O). `03_SCREENS_UX.md` 화면 표의 `패턴` 열과 화면 작업 지시(`DESIGN_SYSTEM.md` 10장)가 이 코드를 쓴다 |
| `docs/products/stock-dashboard/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/stock-dashboard/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/Stock_Trader_nomad.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/stock-dashboard/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `.../0002_stock_domain.sql` | `supabase/migrations/20261013000002_stock_domain.sql` | - | DB |
| `.../0003_stock_orders_paper.sql` | `supabase/migrations/20261013000003_stock_orders_paper.sql` | - | DB(Phase 3 주문 안전장치. MVP에서는 `ORDERS_ENABLED=false`) |
| `docs/products/stock-dashboard/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB(AI 라우팅 기본값 12행 포함) |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다(2026-10-13 검사: 경로 참조 455개, 묶음 안 누락 0, 절대경로 누락 0).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\stock-dashboard\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 stock-dashboard-root에서 온 것입니다.

```
D:\WorkSpace\DEV\stock-dashboard\
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
├── _shared\
│   ├── project-profile.md            [베이스] 6절에서 채움
│   ├── orchestrator-rules.md  routing.md  approval-policy.md  system-invariants.md  design-basis.md  learnings.md   [베이스]
│   ├── check-invariants.sh           [베이스] 무결성 점검(INV 목록). 커밋 전 PASS 필요
│   ├── reentry-check.sh              [베이스] 세션 재진입 시 task 상태 점검
│   └── adapters\
│       ├── gate.sh                   [베이스] 워커 호출 전 승인 게이트(workers_approved, [APPROVAL])
│       ├── scope_check.sh            [베이스] 외부 쓰기 범위 검사(write_scope 대조)
│       ├── call_worker.sh            [베이스] 워커 호출 래퍼
│       └── _run.py                   [베이스] 스크립트 실행 보조
├── _templates\                       [베이스] task.md, task-folder.md, worker-brief.md, worker-result.md, log.md, context.md, dev-request-prompt.md
├── apps\
│   ├── web\                          [베이스] Next.js(코드 없음, W1에서 스캐폴딩)
│   └── api\                          [베이스] FastAPI(코드 없음, ST-06-038에서 스캐폴딩)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\Stock_Trader_nomad.md          [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(24개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 8개                              [묶음]
│   │   │   └── 디자인\ 5개 + DESIGN.md, COMPONENTS.md     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   └── wiki\WIKI_SCHEMA.md, index.md, log.md, sources\  [묶음] 개발 위키
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 stock-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, ..02_stock_domain.sql, ..03_stock_orders_paper.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다. 워커용 `workers/quote-relay`, `workers/stock-jobs`, `content/knowledge`, `packages/*`는 해당 task에서 만듭니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.9, React 19, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전), Recharts 3, zustand 5.x, TanStack Query 5.x, zod 3.x | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`) | 같은 곳 |
| 워커 | Node 22 + TS: `quote-relay`(시세 중계), `stock-jobs`(core.jobs 소비) | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test`, `pnpm test:rls`, `pnpm test:e2e`, `pnpm test:ai`, `pnpm check:bundle-secrets`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | `docs/file/04-구현/CLAUDE.md` 6절, 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 Tailwind CSS v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/supabase.ts` | 타입 생성(경로 제안) |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. pgvector 확장은 Supabase에서 기본 제공되며 `extensions` 스키마에 생성됩니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(ST-06-001)의 수용 기준입니다.
- `0003_stock_orders_paper.sql`은 Phase 3 주문 안전장치입니다. 함께 적용하지만 `ORDERS_ENABLED=false`이고 DB가 `env='paper'` 외 주문 행을 거부합니다.
- RLS 회귀 테스트는 ST-06-003에서 `supabase/tests/`로 옮깁니다. 기획 단계 결과는 `docs/file/03-설계/05_DATA_MODEL.md` 4.1절과 9절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 18개를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 모놀리스 스키마(`public`) | 착수 전(이 문서는 단독 `public` 기준) |
| D-2 | 첫 증권사 | spike ST-06-004 결과 뒤(어댑터 ST-06-014 전) |
| D-3 | 유료화, 유사투자자문업 법률 의견 | 의견서 수령 전까지 무료·초대제 유지. Phase 2 결제(ST-06-031) 전 필수 |
| D-4 | Phase 3 주문 | MVP KPI 확인 후(W9 전) |
| D-5 | 상승/하락 색 | 미결 유지. 디자인 시스템 3단계(ST-06-036) 전 권장. 그 전에는 `--color-up`/`--color-down` 토큰만 참조 |
| D-6 | 브랜드명 | 공개 전(상표 확인 뒤) |
| D-7 | 베타 규모와 초대 발급자 | 초대 발급(ST-06-009) 전 |
| D-8 | 코어 invite 정책 강제 | 닫힘(코어 반영 완료, 제품 게이트 유지) |
| D-9 | NXT 시간대 반영 | Phase 2 |
| D-10 | 공시·뉴스 데이터 이용 허락 | 공시 RAG 실수집(ST-06-041 실제 수집) 전. 그 전에는 합성 문서만 |
| D-11 | AI 요약의 범위(사실 요약만) | AI 그래프(ST-06-045) 전 |
| D-12 | 투자 권유 금지 검사 구성 | ST-06-040 전 |
| D-13 | 진단 입력의 LLM 경로(동의 기반 / 오픈소스 강제) | AI 서비스 설치(ST-06-038)와 진단(ST-06-021) 전 |
| D-14 | 음성 제공자 조건(ElevenLabs 보관, 보이스) | 음성(ST-06-048) 전 |
| D-15 | 브리핑 제공 방식(요청 시 생성만) | 브리핑(ST-06-049) 전 |
| D-16 | 위키 공개 범위(로그인 사용자만) | 위키 화면(ST-06-044) 전 |
| D-17 | 채팅 화면 레퍼런스 Astryx 확인 | 디자인 시스템 1단계(ST-06-035) 전 |
| D-18 | 랜딩 3D 지형 데이터(샘플 고정) | 3D 히어로(ST-06-050) 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 ST-06-001~051, 모두 51개입니다. 그중 ST-06-036은 사람이 하는 디자인 비주얼 검토입니다. 모델 작업 50개의 비율은 Fable 24.0%, Opus 38.0%, Sonnet 32.0%, Haiku 6.0%입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 004, 005, 035 | 없음 | DB·타입(AI 기본값 포함), 증권사 선정, 법률 질의서·고지 초안, 디자인 레퍼런스(1단계) |
| W1 | 002, 003, 006, 008, 026, 038 | W0 | 변환 스크립트, RLS 테스트, 앱 골격, 어댑터 계약, 금칙어 사전, AI 서비스 설치 |
| W2 | 007, 011, 027, 040, 041, 042 | 006(011은 035도) | 보안 유틸, 디자인 시스템 2단계, 환경 정리, 투자 권유 금지 검사, 공시 RAG, 해설집 원고 |
| W2-D | 036 → 037(직렬) | 011 | 디자인 시스템 3~4단계(사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W3 | 009, 010, 012, 013, 015, 039, 045, 050 | W2, 화면은 037 | 초대, 동의 화면, 연결, 동기화, 시세 워커, AI 게이트, AI 그래프, 3D 히어로 |
| W4 | 014, 016, 019, 020, 021, 024, 028, 043, 046, 047 | W3 | 실어댑터, 시세 스토어, 배치, 일지, 진단 라우트, 운영자, 계정, 위키 운영, Dify 채팅, 채팅 패널 |
| W5 | 017, 022, 023, 044, 048 | W4 | 대시보드, 진단 화면, 랜딩, 위키 화면, 음성 질의 |
| W6 | 018, 049 | 017·048 | 종목 상세 모달, 리서치 요약·브리핑·낭독 |
| W7 | 025, 051 | W6 | E2E, AI 보안 회귀. **MVP 완료** |
| W8(P2) | 029, 030, 031 | MVP + 법률 의견 | 아이디어/리더보드, 3사 비교, 결제 |
| W9(P3) | 032 | 사용자 결정(D-4) | 주문 모듈 |
| W10(P3) | 033, 034 | 032 | 주문 UI, 안전장치 테스트 |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 키 보관, RLS, 시세 워커, 결제, 주문, AI 서명 토큰·동의 경계, 투자 권유 금지 검사, AI 보안 회귀 | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`·`fastapi-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 랜딩, 컴포넌트, 해설집 원고, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 변환 스크립트, 사전 파일, 환경 정리 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(ST-06-036), 법률 의견·약관 확인(D-3, D-10) | 사용자 |

리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/ST-06-001-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # ST-06-001 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/stock-dashboard/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
ST-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함), stock_domain, stock_orders_paper, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·wiki_*·voice_* 테이블 생성 확인
③ ai_routing_settings(org null, app stock) 12행, ai_reports_advice_check_passed_check 제약 존재 확인
④ supabase gen types 결과를 apps/web/src/types/supabase.ts 에 저장 ⑤ 06_AGENT_PLAN.md 의 ST-06-001 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/, apps/web/src/types/

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

- **MVP 완료 조건**: W7까지 완료, AI 보안 회귀(ST-06-051) 통과, `06_AGENT_PLAN.md` 7절 완료 정의 충족.
- **금융 보호선**: 어떤 task도 보유 수량·금액을 AI에 보내거나, 투자 권유 금지 검사 없이 AI 텍스트를 노출하면 리뷰에서 반려합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (stock-dashboard)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절

| 구성 | stock-dashboard 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance) | ST-06-038 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. seed `ai_routing_settings` 12행: `stock.research`·`chat`·`stock.diagnosis` auto, `stock.advice_check`·위키 작업 오픈소스 우선, `dify.aux` 오픈소스 강제, `stock.knowledge` oss-embed 고정, 음성 STT 오픈소스 우선·TTS ElevenLabs 우선, `briefing` 대체 금지 | ST-06-038, 039 |
| 국외 이전 동의 | 온보딩에서 선택 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음 | ST-06-039 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑, 정액·턴 선차감과 정산, EdDSA 토큰, 그래프 실행 요청 | ST-06-039 |
| 투자 권유 금지 검사 | 규칙 사전(`src/content/banned.json`) + LLM 판정, 판정 불가면 출력 없음, DB `advice_check` CHECK | ST-06-026, 040 |
| RAG | DART 공시(약관 확인 뒤에만 실수집, D-10), 합성 문서로 개발·테스트. 뉴스 본문은 저장하지 않음 | ST-06-041, 005 |
| 제품 위키 | 주식 용어·공시 해설 위키, 원고 `content/knowledge/`, 로그인 베타 사용자만 열람 | ST-06-042, 043, 044 |
| LangGraph | `stock.research_summary`(retrieve → summarize → advice_check → compliance), `stock.diagnosis`(explain → advice_check → compliance) | ST-06-045 |
| Dify 채팅 | 공용 Dify에 `stock-chat` Chatflow. Dify는 분류와 고정 거절 문구만, 답변은 `/tools/answer`. 설정은 `infra/dify/README.md` | ST-06-046, 047 |
| 음성 | 음성 질의(STT 오픈소스 우선), 답변 읽어 주기, 브리핑 낭독(검사 통과 대본만, 제공자 대체 금지) | ST-06-048, 049 |
| 보안 회귀 | 조직 격리, 대화 매핑 위조, 국외 동의 우회, 크레딧 우회, 투자 권유 우회, 보유 내역 비유출 | ST-06-051 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 라우팅을 상용만 쓰도록 두고, 국외 동의가 있는 테스트 조직으로 개발합니다. 다만 `stock.advice_check`는 판정 경로가 없으면 출력하지 않으므로 상용 경로 하나는 열려 있어야 합니다.
3. 준비되면 기본값으로 되돌립니다.

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보, 계좌번호를 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 24개)는 setup 시 함께 들어옵니다.

## 13. 디자인 시스템과 3D 히어로

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 주 레퍼런스 Primer(데이터 밀도), 상태 배지 Atlassian, 채팅 Astryx 패턴(확인 후, D-17), 랜딩 HERO_3D | ST-06-035, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(야간장 남색, 체결판 남회, 한지 백, 장외 회색, 동시호가 황) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`, 기본 컴포넌트, `/dev/components` | ST-06-011 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | ST-06-036(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | ST-06-037 |

- 상승/하락 색은 미결(D-5)입니다. 컴포넌트는 `--color-up`/`--color-down` 의미 토큰만 참조하고, 결정 뒤 값만 바꿉니다. 색만으로 뜻을 전하지 않습니다(부호 병기).
- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). 지시에는 버전을 적고 "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.5) — 2026-10-13 사용자 결정으로 3D 적용

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 시세 흐름을 지형으로 보여 주는 3D 차트(가로 장 시간, 깊이 업종, 높이 거래 활동의 상대 크기). 현재 시각 선은 시계만 사용 |
| 모바일(767px 이하) | 2D 지형 단면(SVG)을 즉시 표시. 저사양 판정을 통과하고 300KB 이하이면 가벼운 지형으로 교체 로드 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 제목, CTA, 장 시간 바는 HTML로 3D 위에 겹칩니다. 데이터는 고정 시드 샘플이며 "샘플 데이터, 실제 시세 아님" 배지를 고정합니다(D-18).
- 수익 약속 표현 금지: 수익률·`%`·상승/하락 색·우상향 곡선을 쓰지 않습니다. 단위 테스트로 앞/뒤 1/3 평균 높이 비 0.8~1.25를 확인합니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 피할 인상: 거의 검은 배경 + 애시드 그린, 크립토 네온, 수익 인증 광고
- 확인: 레퍼런스 대비 스크린샷 3종, 고문(Fable) 디자인 검토(ST-06-050, 023)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` stock-dashboard 절(`:205`)에 있습니다.

| 구분 | 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|---|
| 랜딩 | Awwwards (Montfort, SOTD) | https://www.awwwards.com/sites/montfort | 투자 회사의 절제된 신뢰 톤. 큰 약속 대신 조용한 문장 | `/` |
| 랜딩 | Awwwards (Runway Financial, SOTD) | https://www.awwwards.com/sites/runway-financial | 실제 제품 화면으로 제품을 설명하는 방식 | `/` 히어로 |
| 앱 | Dribbble (GNII AI Powered Dashboard) | https://dribbble.com/shots/20626721-GNII-AI-Powered-Dashboard-Stock-Crypto-Trading-Web3-SaaS-App | 여러 자산을 한 화면에 모은 배치, 다크/라이트 둘 다 | `/dashboard` |
| 앱 | Dribbble (Stock Market Dashboard, PIXEL) | https://dribbble.com/shots/8173750-Stock-Market-Dashboard | 블루·그레이 중심으로 상태색을 돋보이게 | 보유 그리드 |
| 앱 | Dribbble (Stock Market Dashboard, Seb Hooper) | https://dribbble.com/shots/6095497-Stock-Market-Dashboard | 차트 + 종목 목록 배치 | 종목 상세 모달 |

- URL은 이 표와 `REFERENCES.md`에 있는 것만 씁니다. 새 레퍼런스가 필요하면 URL을 직접 열어 확인하고 `REFERENCES.md`에 먼저 추가한 뒤 씁니다.
- 영감용이지 복제용이 아닙니다. 로고·사진·일러스트·아이콘·카피·폰트·색 조합 전체를 가져오지 않고, 레이아웃을 따라 그리지 않습니다. 구조(정보 배치, 위계, 리듬)만 참고하고 토큰은 제품 주제에서 다시 뽑습니다(`03_SCREENS_UX.md` 4.3절).
- Dribbble 링크는 작업 전에 브라우저에서 한 번 엽니다(자동 확인이 막혀 있어 색인으로만 확인됨). 열리지 않으면 `REFERENCES.md`에서 지우고 다른 후보를 씁니다.
- 순서: 레퍼런스(이 절) → 브리프(4.2절) → 토큰 플랜(4.3절) → 13.1 디자인 시스템 → 13.2 메인 히어로. AI에게 화면을 맡길 때 지시에 이 표의 행(제목과 "참고 포인트")을 적습니다.
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

- 원본은 문서 2개뿐이고 코드가 없습니다. "이식"은 요구사항과 화면 지침의 이식이며, 코드 자산(sellingstudio의 Supabase 클라이언트, 키 암호화 등)은 코어 경유로 씁니다.
- 원본 경로: `D:\WorkSpace\platform\구현해야 할 프로젝트\Stock_Trader_nomad`
- 리뷰 "높음" 6건의 차단 설계는 `02_ARCHITECTURE.md` 6절(#5, #6)과 `05_DATA_MODEL.md` 7절(#1~#4)에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(스크래핑, 공개 GEO·JSON-LD, 모델명 하드코딩, Context로 시세 관리)과 매수가·목표가·손절가 카드는 옮기지 않습니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 R-9) |
| 남은 코어 과제 | `adjust_credits` 미구현(R-4), 플랜 변경 RPC(R-2), ai-service 모델→기능 해석·위키 편집 저장(R-7), 3사 비교용 제공자 지정(R-8), 공용 Dify 앱(R-10), 브리핑 대체 금지 옵션(R-11). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |
| 금지 | `_platform-core`, `_supabase-modular`의 다른 파일을 제품 task에서 수정하지 않습니다 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다(빌드, 타입, 린트, SQL 체커 2종, RLS 스모크, E2E, 번들 비밀 검사, AI 회귀, 3D·디자인 시스템).
- 법률: ST-06-005 의견 반영 전에는 공개 랜딩 확장과 유료 플랜을 열지 않습니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| 유사투자자문업·투자자문업 해석 | 법률 의견 전까지 무료·초대제·사실 요약만. 투자 권유 금지 검사 필수, 가격 제시 DB CHECK |
| 공시·뉴스 데이터 이용 | 약관 확인 기록(`docs/legal/data-sources.md`) 전에는 실수집 금지, 개발은 합성 문서. 뉴스 본문 저장 금지 |
| 증권사 키·계좌번호 | `encrypted_credentials`만, 마스킹·HMAC, 로그 마스킹, 번들 검사 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 금지, 보유 수량·금액 미전송, 녹음 기본 미저장 |
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 정액·선차감·정산, 기능별 라우팅, 오픈소스 우선 기능으로 관리. 운영 중 `core.ai_usage`로 원가를 확인해 단가(제안값)를 확정 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D-1~D-18 확정 또는 보류 사유 기록, 산출물 "승인" 전환(8절). D-3(법률 의견)·D-10(데이터 이용)은 미결이면 해당 범위 잠금
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] W1~W7 진행, AI 보안 회귀 통과, MVP 완료 조건 충족

## 부록 A. 스크립트 없이 손으로 할 때

`stock-dashboard-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\stock-dashboard\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/stock-dashboard"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\stock-dashboard" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\stock-dashboard" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/stock-dashboard"` | `Set-Location "D:\WorkSpace\DEV\stock-dashboard"` | `cd /d "D:\WorkSpace\DEV\stock-dashboard"` |
| 3 초기화 | `bash init-project.sh stock-dashboard --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh stock-dashboard --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh stock-dashboard --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/stock-dashboard/stock-dashboard-root/." "D:/WorkSpace/DEV/stock-dashboard/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\stock-dashboard\stock-dashboard-root\*" "D:\WorkSpace\DEV\stock-dashboard" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\stock-dashboard\stock-dashboard-root" "D:\WorkSpace\DEV\stock-dashboard" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
