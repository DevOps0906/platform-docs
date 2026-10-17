# nomad-commerce(NOMAD Commerce) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 nomad-commerce 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\nomad-commerce\setup-nomad-commerce.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/nomad-commerce/setup-nomad-commerce.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\nomad-commerce\        platform에 남는 안내서, 도구, 재료
├── nomad-commerce_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-nomad-commerce.sh          설치 스크립트(Git Bash / Linux)
├── setup-nomad-commerce.ps1         설치 스크립트(Windows PowerShell)
└── nomad-commerce-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(nomad-commerce-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\nomad-commerce\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  ← nomad-commerce-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(60개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계(Mock → Google → 카카오·네이버) | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | NOMAD Commerce. 소싱(아마존·엑셀) → AI 상세페이지(슬롯형 이미지·카피·금지어 검사) → 마켓 규격 변환 → 쿠팡·스마트스토어 업로드 또는 엑셀/ZIP 내보내기를 하는 셀러 도구, 구독 + 크레딧팩 |
| 통합 원본 | Nomad-AI-Factory_V.2(기획 정본), nomad-ai-factory(v1), nomad-ai-commerce, sellingstudio(코드 베이스). 경로는 `D:\WorkSpace\platform\` 아래 각 폴더 |
| 모듈러 앱 id / 스키마 | `commerce` / `commerce` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D-7) |
| 개발 근거 | `docs/file/`의 산출물 25개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 상세페이지 생성 그래프, 보조 AI 그래프, 마켓 규칙·상품 스펙 RAG, 마켓 규칙 위키, 셀러 어시스턴트 채팅(Dify), 음성(상품 설명 입력, 쇼츠 내레이션, 음성 대화) |
| 경계 | 쇼츠 영상 렌더 엔진은 sceneflow 소유(Phase 2에 워커 API 호출). 이 폴더에서 구현하지 않습니다 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), `services/commerce-worker`(TS 워커) | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM)
- Voyage(임베딩, commerce는 오픈소스 임베딩 고정이라 없어도 동작)
- ElevenLabs(음성)
- fal(이미지), 아마존 상품 데이터 공급자(D-4), 쿠팡 Wing·네이버 커머스 API(셀러 본인 키, 앱 설정 화면에서 입력)
- Toss Payments(결제)
- Supabase

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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\nomad-commerce`로 복사 |
| 2 | **복사본 안의** `init-project.sh nomad-commerce --reset-git` 실행 |
| 3 | `nomad-commerce-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
| 4 | 복사본의 `docs/etc`(베이스 설명서 PDF 13MB) 삭제 |
| 5 | 에이전트 모델 지정(11절 표 참고) |
| 6 | 무결성 점검(`_shared/check-invariants.sh`) |

`init-project.sh`가 하는 일(베이스 `init-project.sh:1-84`)은 4가지입니다.
1. `_shared/project-profile.md`의 이름과 target_repo를 채웁니다.
2. 산출물 등록부 `docs/file/_index.md`를 만듭니다.
3. `--reset-git`이면 템플릿 git 이력을 끊고 `git init`을 합니다.
4. 무결성 점검을 합니다.

파일 복사, 커밋, 의존성 설치, 스캐폴딩은 하지 않습니다.

**주의: 반드시 복사본 안의 스크립트를 실행해야 합니다.** 스크립트는 자기 파일이 있는 폴더를 초기화합니다(`init-project.sh:10`, `ROOT=스크립트 위치`). 베이스 원본 폴더의 스크립트를 실행하면 원본이 초기화되고, `--reset-git`이면 원본의 git 이력이 지워집니다.

## 4. 2단계: 묶음 붙여넣기 (setup 스크립트가 처리)

- `nomad-commerce-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/nomad-commerce/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/nomad-commerce/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/nomad-commerce/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/nomad-commerce/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/nomad-commerce/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/nomad-commerce/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/nomad-commerce/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(DOC-CORE-009 `AUTH_ROADMAP.md`는 2026-10-14 추가, 인증 단계) |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/_design-guide/DASHBOARD_PATTERNS.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008 | 앱 화면 구조 패턴(A~O). `03_SCREENS_UX.md` 화면 표의 `패턴` 열과 화면 작업 지시(`DESIGN_SYSTEM.md` 10장)가 이 코드를 쓴다 |
| `docs/products/nomad-commerce/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/Nomad-AI-Factory_V.2.md`, `nomad-ai-factory.md`, `nomad-ai-commerce.md`, `sellingstudio.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/nomad-commerce/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/nomad-commerce/supabase/monolith/migrations/0002_commerce_domain.sql` | `supabase/migrations/20261013000002_commerce_domain.sql` | - | DB |
| `docs/products/nomad-commerce/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| (베이스 제공) | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 규칙·스킬. 묶음에 없고 멀티에이전트 베이스(`MultiAgent-Service-Fullstack-Tree-Framwork`)가 제공한다 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 25개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\nomad-commerce\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 nomad-commerce-root에서 온 것입니다.

```
D:\WorkSpace\DEV\nomad-commerce\
├── CLAUDE.md                         [베이스] 오케스트레이터 운영 규칙(덮어쓰지 않음)
├── init-project.sh                   [베이스] 초기화 스크립트(1회 실행 완료)
├── INSTALL.md  README.md  요구사항_TASK_전환_Format.md   [베이스]
├── .claude\
│   ├── agents\                       [베이스] claude-main(Opus), claude-reviewer(Sonnet), plan-challenger(→Fable),
│   │                                          nextjs-expert·fastapi-expert·supabase-expert(→Sonnet), review-expert(Sonnet)
│   ├── commands\agent-check.md       [베이스]
│   └── skills\
│       ├── deliverable-first, nextjs-expert, fastapi-expert, supabase-expert, frontend-design, ui-ux-pro-max   [베이스]
│       └── llm-wiki\SKILL.md         [베이스] 개발 위키 스킬
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
│   └── api\                          [베이스] FastAPI(코드 없음, W1에서 스캐폴딩)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\Astro_AI.md, FortuneDocs.md   [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(25개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 9개                              [묶음]
│   │   │   └── 디자인\ 5개 + DESIGN.md, COMPONENTS.md     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   └── wiki\index.md, log.md, sources\  [묶음] 개발 위키 · WIKI_SCHEMA.md [베이스]
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 app.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_commerce_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.x(LTS), React 19, Tailwind CSS v4, shadcn/ui(v4 지원 버전) | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 워커 | Node 22 + TS(`services/commerce-worker`) | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/database.ts` | 타입 생성(경로 제안) |
| 5 | `node scripts/dev/seed-users.mjs --app commerce` | 개발용 로그인 페르소나 시드(Stage A). 스크립트는 CM-06-007이 만들므로 그 전에는 건너뜁니다(19.2절) |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. pgvector 확장은 Supabase에서 기본 제공되며 `extensions` 스키마에 생성됩니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(CM-06-001)의 수용 기준입니다.
- RLS 회귀 테스트는 CM-06-003에서 `supabase/tests/`로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 17개(D-1~D-17)와 8.1절의 인증 단계 결정 3개(D-18~D-20)를 확정합니다. 기획은 각 항목의 "권고"를 가정으로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 엔터프라이즈 크레딧(550 유지 / 1,100 / MVP 미판매) | 결제 작업(CM-06-025) 전 |
| D-2 | 이월(없음 / 코어에 이월 비율 요청) | 결제 작업 전 |
| D-3 | Free 체험량(월 15 / 가입 크레딧 30 추가) | 착수 전(결제·크레딧 작업 전) |
| D-4 | 아마존 데이터 공급자(Rainforest, Keepa 등, 단가·약관 비교) | 소싱 작업(CM-06-018) 전 |
| D-5 | 네이버 커머스 API 형태(셀러 직접 발급 / 솔루션사 등록) | 스마트스토어 어댑터(CM-06-022) 전, 출시 2주 전 최종 |
| D-6 | 코드 베이스(sellingstudio 확장 / 모노레포 이식) | 착수 전 |
| D-7 | 모놀리스 스키마(`public`) | 착수 전(이 문서는 단독 `public` 기준) |
| D-8 | 연간 플랜·Add-on | Phase 2 |
| D-9 | 마켓 규칙 위키 공개 범위와 원고 출처 | 규칙 원고(CM-06-047) 전 |
| D-10 | AI 채팅 무료 제공 | AI 게이트(CM-06-046) 전 |
| D-11 | 상품 스펙 RAG 색인 대상과 상한 | RAG 색인(CM-06-048) 전 |
| D-12 | 쇼츠 내레이션 MVP 범위, 보이스, ElevenLabs 데이터 보관 | 내레이션(CM-06-055) 전 |
| D-13 | 채팅 화면 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(CM-06-041) 전 |
| D-14 | 워커의 그래프 호출 방식과 인증 | 생성 그래프(CM-06-051) 전 |
| D-15 | 이미지 생성(fal)과 국외 이전 동의 | AI 게이트(CM-06-046)와 법적 문서(CM-06-033) 전, 법무 확인 |
| D-16 | Vision의 오픈소스 경로(멀티모달 서빙 여부) | 보조 AI 라우트(CM-06-011) 전 |
| D-17 | AI 생성물 표시의 마켓 정책 | 출시 2주 전 |
| D-18 | 카카오 이메일 정책(비즈 앱 `account_email` 필수 권장) | C1(CM-06-059) 전, G2 직후 |
| D-19 | 네이버 로그인 경로(`custom:naver` / 서버 브리지) | C2(CM-06-060) 스파이크 결과 |
| D-20 | 이메일+비밀번호 가입 유지 | G1 판정 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 CM-06-001~060, 모두 60개입니다. 그중 CM-06-043은 사람이 하는 디자인 비주얼 검토입니다. CM-06-058~060은 2026-10-14에 더한 인증 단계 B·C1·C2 작업이고(`06_AGENT_PLAN.md` 8절), CM-06-007은 Stage A(Mock 로그인) 범위로 바뀌었습니다(19장).

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 004, 006, 008, 017, 041 | 없음 | DB 적용·타입(AI 기본값 포함), 앱 골격, 도메인 상수, 안전 fetch, 금지어 매처·규칙 파일, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 005, 007, 015, 016, 021, 022, 045 | W0 | 모놀리스 스크립트, RLS 테스트, env, 인증 Stage A(Mock 로그인·시드), 렌더 템플릿, 변환, 마켓 어댑터 2개, AI 서비스 설치 |
| W1-D | 042 → 043 → 044(직렬) | 004, 041 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 009, 010, 012, 025, 027, 032, 033, 046, 047 | W1, 화면은 044 | 계정, 생성 API, 워커 런타임, 결제, 셸, 랜딩, 법적 문서, AI 게이트, 마켓 규칙 원고 |
| W3 | 014, 018, 019, 023, 024, 034, 036, 048, 056 | W2 | 이미지, 소싱, 업로드, 내보내기, 문구, CI, RAG 색인, 3D 히어로 |
| W4 | 020, 026, 028, 029, 030, 031, 049, 051, 052, 053 | W3 | 소싱 API, 결제 E2E, 화면 4종, 위키 운영, 생성·보조 그래프, Dify 채팅, 채팅 패널 |
| W5 | 011, 013, 050, 054 | W4 | 보조 AI 라우트, 상세페이지 파이프라인(그래프 연결), 공개 위키, 음성 대화·상품 음성 입력 |
| W6 | 035, 055, 057 | W5 | 플로우 E2E, 쇼츠 내레이션, AI 보안 회귀. **MVP 출시 조건** |
| W7 | 058(G1 통과 후 먼저), 037 | W6, 058은 사람의 G1 판정. 037과 035·057의 B 구성 재실행은 058 완료를 기다립니다 | Google 로그인 전환(Stage B), 원본 아카이브 → 공개 베타 |
| W8 | 038, 039, 040, 059·060(G2 통과 후) | 베타 출시, 059·060은 사람의 G2 판정 | Phase 2(쇼츠 영상 연동, 자동화, 모바일), 카카오(C1)·네이버(C2) 로그인 |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 결제, 권한, RLS, 데이터 모델, AI 보안 설계 | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(CM-06-043) | 사용자 |

리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/CM-06-001-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # CM-06-001 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/nomad-commerce/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
CM-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 commerce_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ ai_routing_settings(app commerce) 14행과 플랜 AI 키 확인 ④ supabase gen types 결과를 apps/web/src/types/database.ts 에 저장
⑤ 06_AGENT_PLAN.md 의 CM-06-001 수용 기준 충족.

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

- **MVP 출시 조건**: W6까지 완료, AI 보안 회귀(CM-06-057) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
- **공개 베타 조건**: 사람이 G1을 판정한 뒤 W7의 CM-06-058(Google 로그인, Stage B)을 끝내야 합니다. 그 전까지 배포 환경에는 로그인 수단이 없으므로 외부 사용자를 받지 않습니다(19장).
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (nomad-commerce)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·4.1·6절

| 구성 | nomad-commerce 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance) | CM-06-045 |
| 모델 라우팅 | 상용(Claude, ChatGPT, Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 14행(`commerce.detail_page`·`commerce.assist` 등 auto, 위키 작업 오픈소스 우선, Dify 보조 노드 오픈소스 강제, 임베딩 oss-embed 고정) | CM-06-045, 046 |
| 국외 이전 동의 | 온보딩·설정에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음. 이미지 생성(fal)은 체인 밖(D-15) | CM-06-046 |
| AI 게이트 | Next.js `/api/ai/*`, `/api/voice/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산, EdDSA 토큰 발급, 잡 토큰(`/api/internal/ai-token`) | CM-06-046 |
| RAG | 마켓 규칙 원고(CM-06-047)와 색인(운영자 조직), 셀러 상품 스펙 색인(셀러 조직), 평가셋 | CM-06-047, 048 |
| 마켓 규칙 위키 | 쿠팡·스마트스토어 규칙 위키(draft 검수 후 published, 기준일·출처), 공개 화면 | CM-06-049, 050 |
| LangGraph | `commerce.detail_page`(정보 추출 → 규칙 검색 → 카피 → 금지어 → 마켓 형식 변환 → compliance), `commerce.assist`. 워커는 1~3단계에서 잡 토큰으로 호출, 이미지·합성·마켓 이미지 변환·업로드는 TS 워커 | CM-06-051, 013, 011 |
| Dify 채팅 | 공용 Dify에 `commerce-chat` Chatflow 등록(셀러 어시스턴트: 모드 rules, product). 설정은 `infra/dify/README.md` | CM-06-052, 053 |
| 음성 | 상품 설명 음성 입력, 음성 대화(STT 오픈소스 우선, TTS ElevenLabs 우선), 쇼츠 내레이션(작업 중 제공자 대체 금지). 영상 렌더는 sceneflow(Phase 2) | CM-06-054, 055 |
| 보안 회귀 | 조직 격리, 대화 매핑·바인딩 위조, 강제 오픈소스·국외 동의 우회, 크레딧 우회, LLM 키 위치 | CM-06-057 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 라우팅을 상용만 쓰도록 둡니다. 이때는 국외 동의가 있는 테스트 조직으로 개발합니다.
3. 준비되면 기본값으로 되돌립니다.

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보는 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 25개)는 setup 시 함께 들어옵니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 앱 화면은 Primer(정보 밀도), 상태 배지는 Atlassian 보조, 채팅은 Astryx 패턴(확인 후, D-13), 랜딩은 HERO_3D | CM-06-041, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(검수지, 먹선, 분할선, 송장 블루, 승인 그린, 반려 레드) + Tailwind CSS v4 `@theme` → `apps/nomad-commerce/styles/tokens.css`, 기본 컴포넌트와 `/dev/components` | CM-06-042 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | CM-06-043(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | CM-06-044 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.5)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 상품 상자가 열리고, 상세페이지 패널로 펼쳐지고, 쿠팡·스마트스토어 진열대에 놓입니다 |
| 모바일(767px 이하) | 가벼운 3D 자동 로드: 상자 열림만 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 헤드라인, 아마존 URL 입력, CTA는 HTML로 3D 위에 겹칩니다. 이 히어로는 2026-10-13 사용자 결정으로 기존 스크롤 분할 연출을 대체했습니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 금지: 보라/핑크 그라디언트, 별 파티클, 흔한 지구본·네온 그리드, 다크 + 민트, 마켓 로고
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(CM-06-056, 032)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` nomad-commerce 절(`:122`)에 있습니다.

| 구분 | 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|---|
| 랜딩 | Awwwards (SOTD) | https://www.awwwards.com/sites/shopify-editions-summer-24 | 기능을 실제 제품 데모로 하나씩 보여 주는 구성. 섹션 수는 줄인다 | 랜딩 기능 소개 |
| 랜딩 | Awwwards (SOTD) | https://www.awwwards.com/sites/the-renaissance-edition | 긴 세로 스크롤을 한 장의 편집물처럼 이어 보이게 하는 리듬(상세페이지 롱이미지와 닮음) | 랜딩 히어로-흐름 섹션 |
| 앱 | Dribbble | https://dribbble.com/shots/24616305-Seller-Dashboard-Table | 상품명·SKU·이미지·상태·재고를 한 표에 두는 셀러 목록 | 상품DB, 업로드 이력 |
| 앱 | Dribbble | https://dribbble.com/shots/25971204-Multi-Channel-Performance-Dashboard-D2C-Analytics-UI | 마켓별 채널 카드(목표 대비 결과) | 대시보드 마켓별 업로드 성과 |
| 앱 | Dribbble | https://dribbble.com/shots/5590916-E-Commerce-Seller-Dashboard | 아코디언 사이드바와 중요 알림을 가운데 두는 배치(다크 모드는 가져오지 않음) | 앱 셸, 알림 |

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

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장의 "이식" 목록에서 필요한 파일만 옮기고 2절의 수정점을 반영해 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\sellingstudio\`(코드 베이스), `nomad-ai-factory\`, `nomad-ai-commerce\`, `Nomad-AI-Factory_V.2\`(기획 정본). 아카이브 절차는 07장 5절(CM-06-037)입니다.
- 리뷰 "높음" 22건의 차단 설계는 `02_ARCHITECTURE.md` 6절(5건)과 `05_DATA_MODEL.md` 7절(17건)에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: 분리 크레딧 차감, 클라이언트 `selling_pages` insert, 단일 env 마켓 키, fal whisper STT, OpenRouter 직접 호출)은 옮기지 않습니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 워커 | 상세페이지·업로드·내보내기 워커는 `services/commerce-worker`로 두고, 앱과는 `packages/commerce-*`만 공유합니다 |
| 영상 렌더 | 쇼츠 영상 렌더는 sceneflow 소유입니다(Phase 2에 워커 API 호출만). 이 저장소에 렌더 코드를 만들지 않습니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 R-6) |
| 남은 코어 과제 | `adjust_credits` 미구현, 잡 토큰 패턴 표준화(R-3), 조직별 동시성 claim 등. `docs/file/01-관리/06_AGENT_PLAN.md` 6절과 6.1절을 참고합니다 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 크레딧 선차감과 정산, 기능별 라우팅, 오픈소스 우선 기능으로 관리합니다. 운영 중 `core.ai_usage`로 원가를 확인해 단가(제안값)를 확정합니다 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, 셀러 연락처·마켓 키·사업자번호 AI 요청 제외, 녹음 기본 미저장. 이미지 생성(fal)은 체인 밖이라 D-15로 별도 확정 |
| 마켓 정책 변경 | 마켓 규칙 위키는 기준일을 표시하고 6개월 넘으면 경고합니다. 승인·반려를 보장하는 문구는 만들지 않습니다 |
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
- [ ] 결정 D-1~D-17 확정(인증 D-18~D-20은 각 단계 전), 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] Stage A: CM-06-007 완료 후 `seed-users.mjs --app commerce`, `/login` 개발용 패널 확인(19.2)
- [ ] W1~W6 진행(W6까지가 MVP), AI 보안 회귀 통과, MVP 출시 조건 충족
- [ ] G1 판정(사람, 19.3) → Google 외부 설정(19.4) → CM-06-058 완료 → 공개 베타
- [ ] G2 판정(사람, 19.5) → 카카오(19.6)·네이버 스파이크와 검수(19.7)

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009, 확정 결정 22). 제품 적용값은 `docs/file/02-요구사항/01_PRD.md` CM-F-001·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙" 절, `docs/file/04-구현/07_SOURCE_MIGRATION.md` 6절입니다.

외부 콘솔 설정 절차(화면별), 공식 문서 링크, 공용 모듈 `@nomad/core-auth` 구조와 "공용 모듈 완료 후 모든 제품 적용" 절차는 공용 지시서 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`를 따릅니다(2026-10-15). 통합 DB 제품은 Google·카카오·네이버 앱을 1세트만 같이 쓰므로(지시서 1장 AUTH-D1) 이 장의 외부 설정은 그 세트가 이미 있으면 Redirect URLs에 이 제품 도메인을 더하는 것으로 끝납니다.

처음 개발은 Mock 로그인으로 진행하고, MVP 기능이 모두 잘 동작하면 Google 로그인을 붙이고, 그것이 안정되면 카카오·네이버 로그인을 붙입니다. 세 단계 모두 세션은 실제 Supabase JWT라서 로그인 뒤 코드(권한, RLS, 크레딧)는 바뀌지 않습니다. 기존 기획의 MVP 카카오 로그인은 이 결정으로 C1 단계로 옮겼습니다. A·B 단계의 로그인 화면에는 카카오 버튼이 없습니다. 원본(nomad-ai-commerce)의 `mock-login`·`nomad_role`·`nomad_plan` 쿠키 권한은 복사 금지이고, 허용되는 Mock은 아래 시드 계정 로그인뿐입니다.

### 19.1 단계 요약

| 단계 | 언제 | 켜지는 로그인 | 다음 단계 게이트(사람 판정) | 작업 |
|---|---|---|---|---|
| A Mock | W0부터 W6까지(MVP 기능 개발) | 로컬 시드 페르소나 원클릭 로그인. 실제 제공자 버튼 없음. 화면 상단 `MOCK AUTH · 로컬 전용` 배지 | G1(19.3절) | CM-06-007(W1) |
| B Google | G1 통과 후, 공개 베타 전 | Google + 이메일(가입·인증 메일·비밀번호 재설정). 배포 환경에서 Mock 차단 | G2(19.5절) | CM-06-058(P0, Fable, W7 맨 앞) |
| C1 카카오 | G2 통과 후 | 카카오(Supabase 기본 제공자) | 7.1.3절 수용 기준 | CM-06-059(P1, Opus, W8) |
| C2 네이버 | G2 통과 후(C1과 병렬) | 네이버(`custom:naver` 또는 서버 브리지, 스파이크로 결정) | 7.2.4절 수용 기준 | CM-06-060(P1, Fable, W8) |

### 19.2 Stage A 로컬 실행 순서

CM-06-007(W1)이 끝나야 시드 스크립트와 개발용 로그인이 생깁니다. 그 전 W0 작업은 SQL·단위 테스트로만 검증합니다.

| 순서 | 명령 / 동작 | 확인 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase(`http://127.0.0.1:54321`) 기동 |
| 2 | `supabase db reset` | 마이그레이션·seed 적용(7절) |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<로컬 전용 임의 값>`, `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321` | `DEV_SEED_PASSWORD`는 `NEXT_PUBLIC_`을 붙이지 않습니다. 원격 Supabase URL이면 Mock 모드 기동이 실패합니다 |
| 4 | `node scripts/dev/seed-users.mjs --app commerce` | 페르소나 표 출력(이메일, 조직 id, 플랜, 잔액. 비밀번호 없음). 두 번 실행해도 크레딧 1회 |
| 5 | `pnpm dev` → `/login` | "개발용 로그인" 패널에서 `owner` 선택 → `/dashboard`, 플랜 `free`, 잔액 15 |
| 6 | E2E | Playwright `globalSetup`이 페르소나별로 `/api/dev/login`을 호출해 `storageState`를 저장합니다(CM-06-035) |

페르소나: `owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops` + 제품 행 `pro`, `ai_consent`(제안). 기대 결과는 `05_DATA_MODEL.md` 10절입니다. commerce는 open 앱이라 `pending` 페르소나를 만들지 않습니다.

### 19.3 G1 체크리스트(A → B, 사람이 판정)

- [ ] `06_AGENT_PLAN.md` 2절 MVP P0 기능 작업 완료(인증 B·C 작업 제외)
- [ ] 핵심 플로우 E2E(CM-06-035) 녹색, Mock 페르소나 `storageState`로 실행
- [ ] RLS 스모크(CM-06-003) 전 항목 통과, `outsider` 교차 테넌트 거부 확인
- [ ] 결제 E2E(CM-06-026, Toss 테스트 키) 녹색
- [ ] CI(CM-06-036): 인증 모듈 밖 단계 분기 0건, `nomad_role`·`nomad_plan`·`mock-auth` 0건, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패 확인
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL, 승인된 도메인), 웹 클라이언트 ID, 운영 Supabase 프로젝트
- [ ] 01장 D-20(이메일 가입 유지) 확정
- [ ] 결과를 CM-06-058 task `log.md`에 `[DECISION] G1 통과`로 기록

### 19.4 Stage B 외부 설정 순서(사람, `AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위 `openid`, `email`, `profile`만 | "테스트" 게시 상태에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml`의 `[auth.external.google]`에 `env(GOOGLE_CLIENT_ID)`, `env(GOOGLE_CLIENT_SECRET)` | 키는 앱·워커·ai-service env에 넣지 않습니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | 배포 env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email` | `DEV_SEED_PASSWORD`는 배포 환경에 두지 않습니다 |
| 6 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |
| 7 | 수동 점검표: Google 실로그인 데스크톱·모바일 각 1회, 신규·기존 계정 → task `log.md` | B-5. 실제 Google 로그인은 자동화하지 않습니다 |

### 19.5 G2 체크리스트(B → C, 사람이 판정)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안, 감사 `auth.login`과 오류 로그)
- [ ] 가입 기간 신규 가입자 중 commerce `entitled=false`로 남은 사용자 0(`AUTH_ROADMAP.md` 6장의 SQL)
- [ ] 카카오 디벨로퍼스 앱 생성, 이메일 정책 결정(D-18, 비즈 앱 전환 권장)
- [ ] 네이버 애플리케이션 등록, 검수 자료(로그인 버튼부터 가입 완료까지 캡처) 준비
- [ ] CM-06-059·060 task `log.md`에 `[DECISION] G2 통과`

### 19.6 C1 카카오 설정(`AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = Supabase 콜백(`https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://localhost:54321/auth/v1/callback`) |
| 4 | 카카오 로그인 활성(State ON), 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email` |
| 5 | Supabase → Providers → Kakao 사용(이메일을 받지 못하면 "Allow users without an email"). 로컬 `[auth.external.kakao]`에 `env(KAKAO_CLIENT_ID)`, `env(KAKAO_CLIENT_SECRET)`(CM-06-001 파일에 1줄 요청) |
| 6 | 배포 `AUTH_PROVIDERS=google,email,kakao`. 수용 기준 C1-1~C1-5(`06_AGENT_PLAN.md` CM-06-059) |

### 19.7 C2 네이버 스파이크와 검수(`AUTH_ROADMAP.md` 7.2.2절)

| 단계 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`provider_type: 'oauth2'`, authorize `https://nid.naver.com/oauth2.0/authorize`, token `https://nid.naver.com/oauth2.0/token`, 사용자 정보 `https://openapi.naver.com/v1/nid/me`). 스크립트 `scripts/auth/register-naver-provider.mjs` | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 등록된 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 채워지는지, 재로그인이 같은 사용자인지 | 둘 다 참이면 `supabase_custom` |
| 4 | 실패하면 서버 브리지(`/auth/naver/start`·`/auth/naver/callback`) + 코어 요청 R-9(`staged/0010_core_auth_identity_links.sql` 적용) | `[DECISION]`과 `NAVER_AUTH_PATH` 기록(01장 D-19) |
| 5 | 네이버 검수 신청(로그인 버튼부터 가입 완료까지 캡처). 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다 | C2-6 |

중첩 응답(`response.id`, `response.email`)을 Supabase 커스텀 OAuth2가 읽는지는 문서에 없어 미확인이고, 그래서 스파이크가 첫 단계입니다. 로컬 CLI의 커스텀 제공자 지원도 미확인이라 네이버는 스테이징 프로젝트에서 확인합니다.

### 19.8 단계 전환 요청 프롬프트 예시 (베이스 `_templates/dev-request-prompt.md` 형식)

G1 판정을 사람이 기록한 뒤 B단계 작업을 시작할 때의 예시입니다. C1·C2도 같은 형식으로 작업 ID와 수용 기준 절만 바꿉니다.

```
D:/WorkSpace/DEV/nomad-commerce/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
CM-06-058: 인증 Stage B(Google OAuth + 이메일 가입·재설정, /auth/callback finishLogin, 온보딩 약관 단계)를 구현한다.
진입 조건 = tasks/CM-06-058-*/log.md 에 사람이 남긴 [DECISION] G1 통과가 있어야 한다(없으면 중단하고 보고).
완료 조건 = ① docs/file/03-설계/공용코어/AUTH_ROADMAP.md 5.3절 B-1~B-6 충족
② Mock 페르소나 E2E(tests/e2e/flows) 계속 녹색 ③ AUTH_MODE=mock VERCEL_ENV=production 빌드 실패, live 빌드에서 /api/dev/login 404
④ 첫 Google 로그인 사용자가 약관 동의 전 /dashboard 에 들어가지 않음 ⑤ 06_AGENT_PLAN.md 의 CM-06-058 수용 기준 충족.
Google 실로그인 수동 점검표(B-5)는 사람이 수행하도록 체크리스트만 만든다.

[작업의 특성]
인증 경계 작업. 단계 분기는 apps/web/src/lib/auth/, 로그인 화면, 콜백 라우트에만 둔다. 기능 코드 수정 금지. 카카오 버튼은 만들지 않는다(C1).
작업 대상 경로: 06_AGENT_PLAN.md 8절 CM-06-058 소유 경로. lib/auth/ 의 약관 단계 연결과 supabase/config.toml 은 소유 작업(007, 001)에 1줄 요청.
원격 Supabase 대시보드 설정과 Google Cloud 콘솔 작업은 하지 않는다(사람).

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert, supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

`task.md` baseline에는 `DOC-CORE-009`(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md`), `DOC-MGT-002`(06_AGENT_PLAN.md, CM-06-058 수용 기준), `DOC-DES-002`(03_SCREENS_UX.md 7절), `DOC-DES-003`(04_API.md 8절)을 넣습니다.

### 19.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 우선순위 | 모델 | 웨이브 |
|---|---|---|---|---|
| A | CM-06-007(범위를 Stage A로 바꿈) | P0 | Fable | W1 |
| B | CM-06-058 | P0(공개 베타 필수) | Fable | W7 맨 앞(G1 후. 037과 035·057의 B 구성 재실행이 058을 기다림) |
| C1 | CM-06-059(기존 MVP 카카오를 옮김) | P1 | Opus | W8(G2 후) |
| C2 | CM-06-060 | P1 | Fable | W8(G2 후) |

## 부록 A. 스크립트 없이 손으로 할 때

`nomad-commerce-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\nomad-commerce\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/nomad-commerce"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-commerce" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-commerce" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/nomad-commerce"` | `Set-Location "D:\WorkSpace\DEV\nomad-commerce"` | `cd /d "D:\WorkSpace\DEV\nomad-commerce"` |
| 3 초기화 | `bash init-project.sh nomad-commerce --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh nomad-commerce --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh nomad-commerce --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/nomad-commerce/nomad-commerce-root/." "D:/WorkSpace/DEV/nomad-commerce/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\nomad-commerce\nomad-commerce-root\*" "D:\WorkSpace\DEV\nomad-commerce" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\nomad-commerce\nomad-commerce-root" "D:\WorkSpace\DEV\nomad-commerce" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
