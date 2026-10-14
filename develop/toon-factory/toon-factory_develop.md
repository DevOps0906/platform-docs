# toon-factory(Toon Factory) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 toon-factory 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\toon-factory\setup-toon-factory.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/toon-factory/setup-toon-factory.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\toon-factory\        platform에 남는 안내서, 도구, 재료
├── toon-factory_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-toon-factory.sh          설치 스크립트(Git Bash / Linux)
├── setup-toon-factory.ps1         설치 스크립트(Windows PowerShell)
└── toon-factory-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(toon-factory-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\toon-factory\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← toon-factory-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(54개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Toon Factory. 이야기를 넣으면 AI가 콘티를 짜고, 카탈로그 캐릭터 모듈(포즈 x 표정)로 컷을 조립해 인스타툰 PNG/ZIP, 세로 웹툰, 9:16 MP4(음성 포함 가능)로 내보내는 AI 웹툰 제작 도구. Free/Pro 구독과 크레딧팩 |
| 통합 원본 | 단독 제품. 기획 문서 3개만 있는 `D:\WorkSpace\platform\Toon-Factory\`와 참고 코드(Shorts Maker의 FFmpeg 모듈, BlogStudio 골격, sellingstudio의 fal 기준 구현) |
| 모듈러 앱 id / 스키마 | `toon` / `toon` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D7) |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 작품 설정 위키(캐릭터 바이블)와 설정 RAG, 콘티 그래프 `toon.storyboard`, 보조 그래프 2개, 창작 어시스턴트 채팅(Dify), 음성 대화, 대사 음성 미리듣기, MP4 음성 입히기 |

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/toon`(Next.js), `services/toon-worker` | `node -v; pnpm -v` | 같음 |
| FFmpeg | 워커의 영상 렌더(Docker 이미지에 포함, 로컬 테스트 때만) | `ffmpeg -version` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI, 그래프) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM)
- Voyage(임베딩, toon은 `oss-embed` 고정이라 선택)
- ElevenLabs(음성)
- fal(배경 이미지 생성, 워커 전용)
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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\toon-factory`로 복사 |
| 2 | **복사본 안의** `init-project.sh toon-factory --reset-git` 실행 |
| 3 | `toon-factory-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `toon-factory-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/toon-factory/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/toon-factory/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/toon-factory/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/toon-factory/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/toon-factory/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/toon-factory/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/toon-factory/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 8개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~008 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/toon-factory/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/toon-factory/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/Toon-Factory.md` 외 3개 | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/toon-factory/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/toon-factory/supabase/monolith/migrations/0002_toon_domain.sql` | `supabase/migrations/20261013000002_toon_domain.sql` | - | DB |
| `docs/products/toon-factory/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\toon-factory\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 toon-factory-root에서 온 것입니다.

```
D:\WorkSpace\DEV\toon-factory\
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
│   └── api\                          [베이스] FastAPI(코드 없음, W1에서 스캐폴딩)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\Toon-Factory.md, NOMAD_Shorts_Maker.md, Nomad-BlogStudio.md, sellingstudio.md   [묶음]
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
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 app.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_toon_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.x, React 19, TypeScript strict, Tailwind CSS v4, shadcn/ui(v4 지원 버전), Fabric.js v6, Zustand 5 + immer, zod | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 워커 | Node 22 + TS(`services/toon-worker`): fabric/node + sharp 이미지 렌더, FFmpeg 영상 렌더, 큐 `toon.ai`·`toon.render` | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마(모놀리스, D7) | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

앱 폴더: 기획서의 경로는 `apps/toon/`, `apps/api/`, `services/toon-worker/`, `packages/toon-doc/`입니다. 베이스의 빈 `apps/web/`은 W0 앱 골격(TN-06-004)에서 `apps/toon/`으로 이름을 바꾸어 스캐폴딩합니다(제안).

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/toon/src/types/database.ts` | 타입 생성(경로 제안) |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. pgvector 확장은 Supabase에서 기본 제공되며 `extensions` 스키마에 생성됩니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(TN-06-001)의 수용 기준입니다. 모놀리스 SQL(`core_lite` + `toon_domain` + seed)은 PGlite로 OK였고 AI 라우팅 기본값 14행과 free·pro AI 키가 들어 있습니다.
- RLS 회귀 테스트(68항목)는 TN-06-002에서 `supabase/tests/toon/`으로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 4.1절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 17개(D1~D17)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D1 | MP4 렌더를 video 미디어 워커와 공유할지 | MP4 작업(TN-06-020) 전. 기본은 제품 워커에 이식 |
| D2 | 커스텀 캐릭터 시트를 MVP로 당길지 | 착수 전(기본 Phase 2) |
| D3 | 세로 웹툰 기본 규격 | 플랫폼 규격 확인(TN-06-036) 전 |
| D4 | 인스타툰 컷 상한 | TN-06-036 전 |
| D5 | 카탈로그 확보 방식(외주 + 저작권 양도 권고) | 카탈로그 등록(TN-06-012) 전. 라이선스 증빙 없이는 공개 불가 |
| D6 | AI 가시 표기 기본값 | 내보내기 작업(TN-06-019) 전, 법무 확인 |
| D7 | 모놀리스 스키마(`public`) | 착수 전(이 문서는 단독 `public` 기준) |
| D8 | 무료 플랜 상업 이용 | 요금 화면(TN-06-024) 전 |
| D9 | AI 콘티 정액 3크레딧 유지 여부 | 콘티 그래프(TN-06-049) 전, 원가 실측 후 재산정 |
| D10 | 작품 설정 위키·노트의 개인정보 처리 | 위키 운영(TN-06-047) 전 |
| D11 | AI 배경(fal)의 국외 이전 동의 요구(`TN007`) | AI 게이트(TN-06-045) 전, 법무 확인 |
| D12 | 설정 컬렉션 임베딩(`oss-embed` 고정) | RAG 색인(TN-06-046) 전 |
| D13 | 보이스 6종과 ElevenLabs·오픈소스 TTS 조건 | 대사 미리듣기(TN-06-054) 전 |
| D14 | 무료 플랜 AI 채팅 한도 | AI 게이트(TN-06-045) 전 |
| D15 | 채팅 화면 레퍼런스 Astryx 확인 | 디자인 시스템 1단계(TN-06-041) 전 |
| D16 | 영상 음성의 AI 가시 표기 방식 | 영상 음성(TN-06-055) 전, 법무 확인 |
| D17 | 워커의 그래프 호출 인증(잡 토큰) | 콘티 API(TN-06-014) 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 TN-06-001~059, 모두 59개입니다. 그중 TN-06-042는 사람이 하는 디자인 비주얼 검토입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 003, 004, 005, 033, 041, 058 | 없음 | DB 적용·타입, 변환 스크립트, 앱·워커 골격, 문서 스키마, 디자인 레퍼런스(1단계), 생성 규칙 사전 |
| W1 | 002, 006, 007, 010, 012, 028, 037, 044 | W0 | RLS 테스트, 렌더러, 스토어, 레이아웃, 카탈로그 CLI, 법적 페이지, 서버 공통, AI 서비스 설치 |
| W1-D | 034 → 042 → 043(직렬) | 004, 041 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 008, 009, 011, 013, 016, 018, 022, 045 | W1, 화면은 043 | 에디터, 카탈로그·내보내기·결제 API, 콘티 변환, AI 게이트 |
| W3 | 019, 021, 023, 024, 026, 027, 036, 046, 052, 056, 059 | W2, 화면은 043 | 이미지 렌더 워커, 내보내기 화면, 스케줄, 결제 화면, 랜딩, 온보딩, 플랫폼 규격, 설정 RAG, 채팅 시트, 3D 히어로, AI 온보딩 |
| W4 | 020, 025, 029, 031, 047, 049, 050, 053 | W3 | MP4, 결제 E2E, 에디터 테스트, 린트, 설정 위키 운영, 콘티 그래프, 보조 그래프, 음성 대화 |
| W5 | 014, 015, 017, 035, 048, 051, 054, 055 | W4 | AI 콘티·배경·대사 API(그래프 연결), 콘티 화면, 설정 위키 화면, Dify 채팅, 대사 미리듣기, MP4 음성 |
| W6 | 030, 032, 057 | W5 | 핵심 E2E, 내 에셋, AI 보안·라우팅 회귀. **MVP 출시 조건** |
| W7 | 038 → 039, 040 | MVP 출시 | Phase 2·3 |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 결제, 권한, RLS, 데이터 모델, AI 보안 설계(TN-06-001, 002, 005, 022, 023, 038, 044, 045, 057) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 렌더러, 스토어, API, 그래프, RAG·위키, 음성, 테스트 설계(27개) | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 랜딩, 컴포넌트, 3D 히어로, 규칙 사전, 문서(18개) | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크(003, 028, 031, 033) | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(TN-06-042) | 사용자 |

모델 비율(58개): Fable 9(15.5%), Opus 27(46.6%), Sonnet 18(31.0%), Haiku 4(6.9%). 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/TN-06-001-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # TN-06-001 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/toon-factory/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
TN-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 toon_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ ai_routing_settings 의 app toon 행 14개 확인 ④ supabase gen types 결과를 apps/toon/src/types/database.ts 에 저장
⑤ 06_AGENT_PLAN.md 의 TN-06-001 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/, apps/toon/src/types/

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

- **MVP 출시 조건**: W6까지 완료, AI 보안 회귀(TN-06-057) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (toon-factory)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절

| 구성 | toon-factory 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance)에 toon 확장(`products/toon/`) | TN-06-044 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 14행(`toon.storyboard`·`toon.dialogue`·`chat` auto, 일관성·프롬프트·위키 작업 오픈소스 우선, Dify 보조 노드 오픈소스 강제, 설정 임베딩 oss-embed 고정, 음성 4행) | TN-06-044, 045 |
| 국외 이전 동의 | 온보딩 `/onboarding/ai`에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자와 AI 배경(fal, `TN007`)을 쓰지 않음 | TN-06-045, 059 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산, EdDSA 토큰·잡 토큰 발급 | TN-06-045 |
| 작품 설정 RAG | 사용자의 설정 노트를 작품별 컬렉션에 색인(`oss-embed`). 작품 간 격리, 고아 컬렉션 정리 | TN-06-046 |
| 작품 설정 위키 | 캐릭터 바이블(entity), 세계관(concept), 줄거리(topic). 사람 소유 블록 보호, 낙관적 잠금. 화면은 TN-06-048 | TN-06-047, 048 |
| LangGraph | `toon.storyboard`: 줄거리 → 컷 분할 → 캐릭터 일관성 검사(위키 대조) → 이미지 프롬프트 → compliance. 보조 그래프 `toon.dialogue`, `toon.image_prompt`. 규칙 사전은 TN-06-058 | TN-06-049, 050, 058 |
| 콘티·배경·대사 API | 워커가 잡 토큰으로 그래프를 호출(LLM 키는 FastAPI에만) | TN-06-014, 015, 035 |
| Dify 채팅 | 공용 Dify에 `toon-chat` Chatflow 등록. 입력 `platform_conversation_id`, `series_id`, `mode`. 설정은 `infra/dify/README.md` | TN-06-051, 052 |
| 음성 | 음성 대화(STT 오픈소스 우선, TTS ElevenLabs 우선), 대사 음성 미리듣기(보이스 6종), MP4 음성 입히기(작업 중 제공자 대체 금지) | TN-06-053, 054, 055 |
| 보안 회귀 | 조직·작품 격리, 대화 매핑 위조, 강제 오픈소스·국외 동의 우회, 크레딧 우회, 영상 음성 대체 금지 | TN-06-057 |

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
- 초기 페이지(`sources/*.md` 24개)는 setup 시 함께 들어옵니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

주 레퍼런스는 Atlassian(회차·컷 관리, 상태 배지, 권한, 드래그 앤 드롭), 보조는 Primer(밀도)입니다. 채팅·음성·위키 화면은 Astryx 패턴(미확인, D15)입니다.

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 앱 화면 Atlassian + Primer, 채팅은 Astryx 확인(D15), 랜딩은 HERO_3D | TN-06-041, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(원고지 흰, 거터 회색, 펜선 남색, 논포토 블루, 효과선 노랑, 에디터 크롬) + Tailwind CSS v4 `@theme` → `apps/toon/src/styles/tokens.css`, 기본 컴포넌트, `/dev/components` | TN-06-034 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | TN-06-042(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | TN-06-043 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 이전 계획의 `design-system/toon-factory/MASTER.md`는 만들지 않습니다(정답이 두 곳이 되지 않게).

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.5)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 공간에 흩어진 웹툰 컷 패널이 스크롤에 따라 가운데 세로 스크롤 만화 스트립으로 정렬됩니다 |
| 모바일(767px 이하) | 가벼운 3D 자동 로드: 컷 3장이 세로로 정렬됩니다 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 제목, CTA, 샘플 스트립은 HTML로 3D 위에 겹칩니다. 3D 컷은 빈 컷(외곽선과 콘티 선)이고 캐릭터·말풍선·효과 글자는 넣지 않습니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 금지: 보라/핑크 그라디언트, 만화 효과음 글자·말풍선을 UI 장식으로 쓰기, 토큰 밖 3D 색
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(TN-06-056, 026)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` toon-factory 절(`:225`)에 있습니다.

| 출처 | URL | 참고 포인트(가져올 것) | 적용 화면 |
|---|---|---|---|
| Awwwards (Nominee) | https://www.awwwards.com/sites/soul-reaper-html5-scroll-book | 스크롤로 진행되는 코믹. 세로 스크롤 문법을 랜딩 연출 하나로 쓰는 방식 | 히어로(샘플 웹툰 스크롤) |
| Awwwards (Nominee) | https://www.awwwards.com/sites/manga-san | 만화 페이지를 경험 공간으로 보여 주는 구성 | 샘플 작품 구간 |
| Dribbble | https://dribbble.com/shots/15313910-StoryBoard-Dashboard-App-Design | 장면 프레임을 나열해 관리하는 스토리보드 | 콘티 화면, 회차 목록 |
| Dribbble | https://dribbble.com/shots/9071622-Webtoon-Factory | 사용자가 직접 코믹을 만드는 제작 흐름 | 에디터 흐름(이름이 비슷하므로 명칭·그래픽 차용 금지) |
| Dribbble | https://dribbble.com/shots/24546086-Ai-Storybook-app | 캐릭터를 만들고 이야기에 배치하는 흐름 | Phase 2 캐릭터 시트 |

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

- 원본은 기획 문서 3개뿐이라 이식은 주로 개념과 참고 코드입니다. 원본 폴더 `D:\WorkSpace\platform\Toon-Factory\`는 옮기거나 지우지 않습니다(아카이브는 사용자 승인 뒤 별도 작업).
- 참고 코드는 통째로 복사하지 않고 task마다 필요한 파일만 옮깁니다: `NOMAD Shorts Maker/src/lib/media/`의 `ken-burns.ts`, `layer-composite.ts`(FFmpeg 인자 구성)는 TN-06-020에서 `services/toon-worker/src/media/`로, `Nomad-BlogStudio`는 Next 16 골격 참고(TN-06-004)만.
- 리뷰 "높음" 6건의 차단 설계는 `02_ARCHITECTURE.md` 6절(#5, #6)과 `05_DATA_MODEL.md` 7절(#1~#4)에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(FFmpeg.wasm 브라우저 렌더, LoRA, 자동 누끼, 브라우저·Vercel의 LLM·음성 키 직접 사용, `enable_safety_checker: false`)은 옮기지 않습니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/toon/src/lib/server/`(세션, 기능 게이팅, 단가, AI 게이트 `ai/`), `packages/toon-doc/`(문서 스키마·렌더·규칙), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 영상 렌더 | MP4 렌더는 제품 워커에 이식합니다. video의 미디어 워커와 공유할지는 D1입니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 9) |
| 남은 코어 과제 | `adjust_credits` 미구현(요청 3), 잡 토큰 패턴 표준화(요청 8), ai-service 사용자 조직 위키 저장 API(요청 10), core-voice 대체 금지 일반화(요청 11) 등. `docs/file/01-관리/06_AGENT_PLAN.md` 6절 코어 요청을 참고합니다 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 크레딧 선차감과 정산, 기능별 라우팅, 오픈소스 우선 기능으로 관리합니다. 운영 중 `core.ai_usage`로 원가를 확인해 단가(제안값)를 확정합니다 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, AI 배경(fal)은 동의 없이 차단(`TN007`, D11), 이메일·이름·결제 정보 미전송, 녹음 기본 미저장 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| AI 콘티 원가 | 정액 3크레딧은 오픈소스 경로 기준입니다. 상용 경로 원가를 `core.ai_usage`로 실측해 D9를 재검토합니다 |
| 영상 음성 시간 제한 | Vercel 함수 시간 제한 때문에 `video-lines`는 요청당 대사 10개로 분할합니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D1~D17 확정, 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] W1~W6 진행, AI 보안 회귀(TN-06-057) 통과, MVP 출시 조건 충족

## 부록 A. 스크립트 없이 손으로 할 때

`toon-factory-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\toon-factory\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/toon-factory"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\toon-factory" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\toon-factory" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/toon-factory"` | `Set-Location "D:\WorkSpace\DEV\toon-factory"` | `cd /d "D:\WorkSpace\DEV\toon-factory"` |
| 3 초기화 | `bash init-project.sh toon-factory --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh toon-factory --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh toon-factory --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/toon-factory/toon-factory-root/." "D:/WorkSpace/DEV/toon-factory/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\toon-factory\toon-factory-root\*" "D:\WorkSpace\DEV\toon-factory" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\toon-factory\toon-factory-root" "D:\WorkSpace\DEV\toon-factory" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
