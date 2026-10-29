# study-note(Study Note) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 study-note 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\study-note\setup-study-note.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/study-note/setup-study-note.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\study-note\        platform에 남는 안내서, 도구, 재료
├── study-note_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-study-note.sh          설치 스크립트(Git Bash / Linux)
├── setup-study-note.ps1         설치 스크립트(Windows PowerShell)
└── study-note-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(study-note-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\study-note\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  ← study-note-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(55개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키 | 11~12 |
| - | 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 13~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계(Mock → Google → 카카오·네이버) | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Study Note. 수업·회의 원문을 서버가 AI 모델 2개로 정리해 학습 일지로 만들고, 노트·교재를 과목별 개념 위키로 자동 정리하며, 강의 녹음을 자동으로 노트로 바꾸는 학습 노트 서비스. 공개 베타 |
| 통합 원본 | `study-note-organizer-codex-01`(`D:\WorkSpace\platform\study-note-organizer-codex-01\`). 합칠 다른 원본은 없는 정리형 기획 |
| 모듈러 앱 id / 스키마 | `notes` / `notes` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D-8, 사용자 최종 확인 대기) |
| 개발 근거 | `docs/file/`의 산출물 25개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 노트·교재 RAG, 과목별 개념 위키(핵심), LangGraph `notes.organize`(업로드 → 요약 → 개념 연결 → 퀴즈 → 검사), 학습 Q&A 채팅(Dify), 음성 대화, 강의 녹음 → 자동 노트 생성(핵심), 퀴즈 음성 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), 워커 | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI, LangGraph) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절). 브라우저·Vercel에는 LLM 키를 두지 않습니다.
- OpenRouter(일지 정리 워커 전용), Anthropic, OpenAI, Google(FastAPI 상용 LLM)
- ElevenLabs(음성 대화·퀴즈 음성, Next.js 서버 전용. 강의 녹음에는 쓰지 않음)
- Toss Payments(Phase 2 결제)
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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\study-note`로 복사 |
| 2 | **복사본 안의** `init-project.sh study-note --reset-git` 실행 |
| 3 | `study-note-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `study-note-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/study-note/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/study-note/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/study-note/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/study-note/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/study-note/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/study-note/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/study-note/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(DOC-CORE-009 `AUTH_ROADMAP.md`는 2026-10-14 추가, 인증 단계) |
| `docs/design-module/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/design-module/_design-guide/DASHBOARD_PATTERNS.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008 | 앱 화면 구조 패턴(A~O). `03_SCREENS_UX.md` 화면 표의 `패턴` 열과 화면 작업 지시(`DESIGN_SYSTEM.md` 10장)가 이 코드를 쓴다 |
| `docs/products/study-note/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/study-note/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/study-note-organizer-codex-01.md` | `docs/reference/reviews/study-note-organizer-codex-01.md` | 참고 | 원본 리뷰 |
| `docs/products/study-note/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/study-note/supabase/monolith/migrations/0002_study_note_domain.sql` | `supabase/migrations/20261013000002_study_note_domain.sql` | - | DB |
| `docs/products/study-note/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB(AI 라우팅 13행, 플랜 AI 키, `org-files` 버킷 포함) |
| (베이스 제공) | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 규칙·스킬. 묶음에 없고 멀티에이전트 베이스(`MultiAgent-Service-Fullstack-Tree-Framwork`)가 제공한다 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 25개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다. 마지막 검사 결과: 문서 경로 290개, 묶음 안 누락 0, 절대경로 누락 0.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\study-note\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 study-note-root에서 온 것입니다.

```
D:\WorkSpace\DEV\study-note\
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
│   ├── web\                          [베이스] Next.js(코드 없음, W1에서 스캐폴딩). 기획서의 apps/study-note
│   └── api\                          [베이스] FastAPI(코드 없음, W1에서 스캐폴딩)
│                                     (일지 정리 워커 apps/study-note-worker는 apps/worker로 두는 것을 제안)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\study-note-organizer-codex-01.md   [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(25개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 9개(AUTH_ROADMAP 포함)            [묶음]
│   │   │   └── 디자인\ 5개 + DESIGN.md, COMPONENTS.md     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   └── wiki\index.md, log.md, sources\  [묶음] 개발 위키 · WIKI_SCHEMA.md [베이스]
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 notes-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_study_note_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.9, React 19.2.6, TypeScript 6.0.3(strict), Tailwind CSS v4(4.3.0), shadcn/ui(v4 지원 버전), lucide-react | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`) | 같은 곳 |
| 워커 | Node LTS + TS(일지 정리 `notes.organize`, AI 정산 크론). 새 AI 생성은 FastAPI가 맡음 | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안. 원본 기획의 `npm run ...`(`CLAUDE.md` 6절)은 pnpm으로 읽음 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절). 원본 `package.json`의 `latest` 태그는 4.3.0으로 고정합니다.

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/database.ts` | 타입 생성(경로 제안) |
| 5 | `node scripts/dev/seed-users.mjs --app notes` | 개발용 로그인 페르소나 생성(인증 Stage A, 19.2절). 스크립트는 NT-06-006(W2)이 만들므로 W0~W1에서는 건너뜁니다 |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. 코어 축소판에서 SECTION 6-A, 6-B, 8(Storage), 9(affiliate)는 제거돼 있어, 교재 업로드용 `org-files` 버킷은 `seed.sql`이 만듭니다.
- `seed.sql`에는 AI 라우팅 기본값 13행과 체인 검사, Free/Pro 플랜의 AI 키가 들어 있습니다. 확인: `select count(*) from public.ai_routing_settings where app_id = 'notes'` = 13.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(NT-06-002)의 수용 기준입니다.
- RLS 회귀 테스트는 NT-06-003에서 `supabase/tests/`로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 23개(D-1~D-19, 인증 단계 D-20~D-23은 8.1절)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | Pro 가격과 크레딧, 등급 단가 | 베타 2주 실측 후(NT-06-029) |
| D-2 | 키 정책(서버 키만, BYOK 없음) | 착수 전 |
| D-3 | 기본 프리셋 | 작업실 화면(NT-06-017) 전 |
| D-4 | 기본 모델 한쪽만 성공했을 때 통합 허용 | 워커(NT-06-010) 전 |
| D-5 | 복습 플래시카드(Phase 3) 진행 여부 | 베타 지표 확인 후 |
| D-6 | 만 14세 미만 정책, 약관 문구 | 가입 화면·약관 단계(NT-06-053, Stage B) 전, 법무 확인. 법무 페이지(NT-06-021)는 W2 |
| D-7 | 저장소 위치(모노레포 흡수) | 착수 전(NT-06-001) |
| D-8 | 모놀리스 스키마 이름(`public`) | 착수 전(이 문서는 단독 `public` 기준) |
| D-9 | OpenRouter 데이터 사용 정책 | LLM 어댑터(NT-06-009) 전 |
| D-10 | Free 플랜의 AI 기능 범위와 월 크레딧 | AI 게이트(NT-06-036) 전 |
| D-11 | AI 기본 라우팅(오픈소스 우선 vs 상용 우선) | 평가셋(NT-06-049) 결과 후 |
| D-12 | 일지 정리 파이프라인의 AI 계층 통합 시점과 이름 | 워커(NT-06-010) 전(권고: MVP는 현행 유지) |
| D-13 | 강의 녹음 STT 제공자, 고지문, 원본 보관 | 강의 녹음 API(NT-06-045) 전, 법무 확인 |
| D-14 | 교재(저작물) 업로드 정책 | 색인 API(NT-06-037) 전, 법무 확인 |
| D-15 | 퀴즈 형식과 응시 기록 | 그래프(NT-06-039) 전 |
| D-16 | 과목 모델(위키 index 페이지 vs 테이블) | 과목·위키 백엔드(NT-06-038) 전 |
| D-17 | 채팅·노트 화면 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(NT-06-031) 전 |
| D-18 | ElevenLabs 데이터 보관·보이스 | 음성 대화(NT-06-044) 전 |
| D-19 | 위키 자동 갱신 상한과 점검 실행 방식 | 위키 백엔드(NT-06-038) 전 |
| D-20 | 카카오 이메일 정책(권고: 비즈 앱 전환 후 `account_email` 필수) | C1(NT-06-054) 착수 전, G2 직후 |
| D-21 | 네이버 연동 경로(`custom:naver` / 서버 브리지) | C2(NT-06-055) 스파이크 결과 |
| D-22 | 이메일+비밀번호 가입 유지(권고: 유지) | B(NT-06-053) 착수 전, G1 |
| D-23 | 이메일 인증 전 정리 실행 불가의 판정 기준(`email_confirmed_at`) | B(NT-06-053) 착수 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 NT-06-001~055, 모두 55개입니다. 그중 NT-06-033은 사람이 하는 디자인 비주얼 검토입니다. NT-06-053~055는 2026-10-14 인증 단계(19장, 06장 8절) 작업이고, NT-06-006은 Stage A(Mock 로그인) 범위로 바뀌었습니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 022, 031 | 없음 | 저장소 위생, DB 적용·타입(AI 기본값 포함), CI 뼈대, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 003, 004, 005, 007, 035 | W0 | RLS 회귀 CI, 변환 스크립트, 플랫폼 연결, pipeline 로직, AI 서비스 설치 |
| W1-D | 032 → 033 → 034(직렬) | 005, 031 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 006, 008, 009, 013, 015, 016, 020, 021, 036, 049 | W1, 화면은 034 | Stage A 인증(Mock 로그인, 시드), 단위 테스트, LLM 어댑터, 부가 API, 클라이언트 상태, 이식 컴포넌트, 랜딩, 법무, AI 게이트, AI 평가셋 |
| W3 | 010, 012, 014, 017, 018, 019, 037, 038, 041, 050, 052 | W2 | 워커, 실행 API, 비용 보호, 작업실·설정·보관함, RAG 색인, 과목·위키 백엔드, 채팅 패널, 정산 크론, AI 고지문 |
| W4 | 011, 024, 025, 030, 039, 040, 042, 043, 044, 047 | W3 | 통합/E2E 테스트, 스케줄, 디자인 점검, 노트 정리 그래프, Dify 채팅, 위키 화면, 노트·퀴즈 화면, 음성 대화, 3D 히어로 |
| W5 | 045, 046 | W4 | 강의 녹음 API(핵심), 퀴즈 음성 |
| W6 | 051, 053(G1 통과 후 먼저), 048 | W5. 순서: 051 → G1 판정 → 053 → 048 | 강의 녹음 화면, Google OAuth 전환(Stage B), AI 보안 회귀. **공개 베타 출시 조건** |
| W7 | 023, 026, 027, 028, 029, 054·055(G2 통과 후) | W6. 054·055는 G2 | 문서, 결제(Phase 2), 관리자, 운영 리포트, 카카오(C1)·네이버(C2) 로그인 |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | RLS, 데이터 모델, 결제, AI 보안 설계(서명 토큰, 선차감·정산, 회귀) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`·`fastapi-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 음성, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(NT-06-033) | 사용자 |

작업 수 비율(사람 작업 제외 54개): Fable 8(14.8%), Opus 28(51.9%), Sonnet 14(25.9%), Haiku 4(7.4%). 규모 가중 Fable 17.2%, Opus 53.5%, Sonnet 25.3%, Haiku 4.0%(합 99). 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/NT-06-002-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # NT-06-002 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/study-note/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
NT-06-002: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 study_note_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인,
ai_routing_settings 의 notes 행 13건 확인 ③ session_context('notes') 가 entitled=true, 잔액 30
④ supabase gen types 결과를 apps/web/src/types/database.ts 에 저장 ⑤ 06_AGENT_PLAN.md 의 NT-06-002 수용 기준 충족.

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

- **MVP 출시 조건**: W6까지 완료(인증 Stage B NT-06-053 포함, G1 `[DECISION]` 기록), AI 보안 회귀(NT-06-048) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다(3D 히어로 NT-06-047은 P1).
- 화면 작업(016~021, 041~043, 047, 051)은 디자인 시스템 4단계(NT-06-034)가 끝난 뒤 시작합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (study-note)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 4~5절, `04_API.md` 2.1·6절

| 구성 | study-note 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance, 잡 소비자 큐 `notes.ai`) | NT-06-035 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 13행(노트 정리·채팅·위키는 오픈소스 우선, Dify 보조 노드와 강의 STT는 오픈소스 강제, 노트 임베딩은 oss-embed 고정) | NT-06-035, 036 |
| 국외 이전 동의 | 온보딩에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음 | NT-06-036, 052 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산, EdDSA 토큰 발급, 입력 마스킹 | NT-06-036 |
| RAG | 사용자 노트·교재 업로드(서명 업로드 URL)와 과목별 컬렉션 색인. 평가셋은 가상 샘플로 직접 작성 | NT-06-037, 049 |
| 과목별 개념 위키(핵심) | 과목 = 위키 index 페이지 + 컬렉션 규칙(제품 AI 표 없음). 사용자 소유 블록 보호, 낙관적 잠금, 점검 | NT-06-038, 042 |
| LangGraph | `notes.organize`: 불러오기 → 요약 → 개념 연결 → 퀴즈 → 검사(마지막). 퀴즈 조회·세션·채점 API 포함 | NT-06-039, 043 |
| Dify 채팅 | 공용 Dify에 `notes-chat` Chatflow 등록. 입력 `platform_conversation_id`, HTTP 노드 → `/tools/answer`(내부 키). 설정은 `infra/dify/README.md` | NT-06-040, 041 |
| 음성 대화 | STT는 오픈소스 우선, TTS는 ElevenLabs 우선. 녹음 원본 미저장 | NT-06-044 |
| 강의 녹음 → 노트(핵심) | 5분 조각 STT(`lecture_note`, 강제 오픈소스), 제3자 음성 고지, 전사 병합 후 노트 정리. 원본 보관은 동의 시 30일 | NT-06-045, 051 |
| 퀴즈 음성 | 문제 읽어 주기(TTS), 음성 답(STT), 세션 선차감 | NT-06-046 |
| 정산·정리 크론 | `/api/internal/ai-settle` 5분 호출, 만료 녹음·전사 조각 삭제 | NT-06-050 |
| 보안 회귀 | 조직 격리, 대화 매핑 위조, 강제 오픈소스·국외 동의 우회, 퀴즈 정답 노출, 크레딧 우회 | NT-06-048 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 라우팅을 상용만 쓰도록 두고, 국외 동의가 있는 테스트 조직으로 개발합니다. 단 강의 녹음(`lecture_note`)은 상용으로 대체되지 않으므로 오픈소스 음성 서버(또는 모의 서버)가 먼저 필요합니다.
3. 준비되면 기본값으로 되돌립니다.

기존 일지 정리(워커 + OpenRouter, 잡 `notes.organize`)와 새 그래프(LangGraph `notes.organize`, 잡 `notes.ai.organize`)는 이름이 비슷하므로 섞지 않습니다(`02_ARCHITECTURE.md` 4.2절).

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보는 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 25개)는 setup 시 함께 들어옵니다.
- 이것은 개발용 위키입니다. 제품의 과목별 개념 위키(DB `core.wiki_pages`)와 다릅니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 채팅·노트·위키·퀴즈는 Astryx 패턴(존재·라이선스 확인 후, D-17), 보조 Primer(밀도), 랜딩은 HERO_3D | NT-06-031, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(방안지, 먹청, 괘선, 형광노랑, 교정청록, 종이) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`, 기본 컴포넌트와 `/dev/components` | NT-06-032 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | NT-06-033(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | NT-06-034 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.6)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 공간에 흩어진 메모 카드가 정렬되어 한 권의 노트로 모이고 펼쳐지며, 펼친 면에 정리본 예시가 HTML로 겹칩니다. 마지막에 핵심 한 줄에 형광펜이 1회 그어집니다 |
| 모바일(767px 이하) | 가벼운 3D 자동 로드: 메모 카드 5장이 노트 한 권이 되는 짧은 장면. 정리본 예시는 2D 카드 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지(`public/hero/cards-notebook.avif`) |

- 제목, CTA, 정리본 예시는 HTML로 3D 위에 겹칩니다. 히어로는 2026-10-13 사용자 결정(전 제품 3D 히어로)으로 바뀌었습니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 금지: 파스텔 스티커·손글씨 장식, 보라/핑크 그라디언트, 별 파티클, 모든 섹션 페이드인
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(NT-06-047, 020)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` study-note 절(`:246`)에 있습니다.

| 구분 | 제목 | 출처 | URL | 참고 포인트(가져올 것) | 가져오지 않을 것 | 적용 화면 |
|---|---|---|---|---|---|---|
| 랜딩 | Superlist (SOTD) | Awwwards | https://www.awwwards.com/sites/superlist | 실제 제품 화면을 주인공으로 둔 첫 화면 | 할 일 관리 카피와 브랜드 색 | 히어로 |
| 랜딩 | Magpie - Photos & Notes (Honorable Mention) | Awwwards | https://www.awwwards.com/sites/magpie-photos-notes | 노트를 결과물로 보여 주는 기능 소개 | 앱 스타일 색 조합 | 기능 소개 |
| 랜딩 | Learning by Design (Honorable Mention) | Awwwards | https://www.awwwards.com/sites/learning-by-design | 학습 자료를 묶어 탐색하기 쉽게 하는 정보 구조 | 교육 기관 포털 톤 | 보관함 소개 |
| 앱 | Markpad | Dribbble | https://dribbble.com/shots/20665686-Markpad-minimal-MacOS-app-for-writing-notes-in-markdown | 군더더기 없는 텍스트 중심 작성 화면 | macOS 창 크롬 | 작업실 입력부 |
| 앱 | Note taking desktop app | Dribbble | https://dribbble.com/shots/10150150-Note-taking-desktop-app | 사이드바 + 본문 구성 | 다크 모드를 기본값으로 두는 것 | 보관함 |

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

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장의 "가져올 것" 목록에서 필요한 파일만 옮기고 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\study-note-organizer-codex-01\`. 중첩 `.git`, `node_modules`, `dist`는 옮기지 않고 `archive/`로 이동하는 절차는 07장 5절입니다.
- 리뷰 "높음" 3건(API 키 번들 노출, `.gitignore` 부재, 동시 실행)의 차단 설계는 `02_ARCHITECTURE.md` 6절과 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: `VITE_OPENROUTER_API_KEY` 폴백, `README copy.md`, `useLocalStorage`)은 옮기지 않습니다. 원본의 `index.css`는 이미 Tailwind CSS v4 설정이라 그대로 이식하되 hex는 토큰으로 바꿉니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| LLM 키 | 워커(OpenRouter, 일지)와 FastAPI(상용 제공자) 두 곳만. ElevenLabs 키와 서명 개인키는 Next.js 서버만 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 C-9) |
| 남은 코어 과제 | 모듈러 seed AI 키(C-6), ai-service 확장(C-7), core-voice 계약(C-8), 공용 Dify 앱(C-10), 계정 삭제 절차(C-3), 인증: 네이버 브리지 채택 시 `auth_identity_links` 적용(C-11, 조건부), 시드 스크립트 계약 보정(C-12, 19.1절 첫 제품 메모). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 월 30 크레딧에 AI 단가가 큽니다(강의 20분 + 정리 약 15 크레딧). 크레딧 선차감과 정산, 오픈소스 우선 라우팅으로 관리하고 베타 2주 실측으로 단가·플랜을 확정합니다(D-1, D-10) |
| 제3자 음성(강의) | 강의 STT는 오픈소스 강제, 시작 전 고지 필수, 원본 기본 폐기. 법무 확인 전에는 고지문을 초안으로만 둡니다(D-13) |
| 저작물 업로드 | 사용 권한 확인 체크, 개인 학습 한정, 연속 복제 억제. 약관은 법무 확인(D-14) |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, 개인정보 형식 마스킹, 녹음 기본 미저장 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다. 원본 `.env`에 실키가 있었다면 재발급합니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만. 강의 STT는 오픈소스 필수)
- [ ] `supabase start` → `supabase db reset` 성공, 라우팅 13행 확인(7절)
- [ ] 결정 D-1~D-19 확정, 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] Stage A(W2, NT-06-006): 시드 스크립트 실행, `/login` 개발용 패널과 `MOCK AUTH · 로컬 전용` 배지 확인(19.2), 첫 실전 검증 결과 `[DECISION]` 기록
- [ ] W1~W5와 W6의 051 진행, Mock E2E(NT-06-024) 녹색
- [ ] G1 체크리스트(19.3) 판정 후 Google 외부 설정(19.4)과 NT-06-053, 이어서 AI 보안 회귀(NT-06-048) 통과, MVP 출시 조건 충족
- [ ] 공개 베타 2주 후 G2 체크리스트(19.5), 카카오(19.6)·네이버(19.7)

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009, 확정 결정 22). 제품 반영: `docs/file/02-요구사항/01_PRD.md` 2절 머리말·NT-F-001·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙".

외부 콘솔 설정 절차(화면별), 공식 문서 링크, 공용 모듈 `@nomad/core-auth` 구조와 "공용 모듈 완료 후 모든 제품 적용" 절차는 공용 지시서 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`를 따릅니다(2026-10-15). 통합 DB 제품은 Google·카카오·네이버 앱을 1세트만 같이 쓰므로(지시서 1장 AUTH-D1) 이 장의 외부 설정은 그 세트가 이미 있으면 Redirect URLs에 이 제품 도메인을 더하는 것으로 끝납니다.

로그인은 단계로 켭니다. MVP 기능을 만드는 동안은 외부 콘솔 설정 없이 로컬 시드 계정으로 실제 로그인(Mock)하고, 기능이 모두 동작하면 Google을, Google이 안정되면 카카오·네이버를 붙입니다. 세션은 모든 단계에서 실제 Supabase JWT라서 단계를 바꿔도 RLS·크레딧·권한 코드는 바뀌지 않습니다.

### 19.1 단계 요약

| 단계 | 언제 | 켜지는 로그인 | 작업 | 다음 단계 게이트 |
|---|---|---|---|---|
| A | W0부터 MVP 기능 완료(W6의 NT-06-051)까지 | 로컬 Supabase 시드 계정(페르소나) 원클릭 로그인. 실제 제공자 버튼 없음 | NT-06-006(W2) | G1 |
| B | G1 통과 후, 공개 베타 전(W6 맨 앞) | Google + 이메일+비밀번호. 배포 환경에서 Mock 차단 | NT-06-053(P0, Fable, M) | G2 |
| C1 | G2 통과 후(W7) | 카카오 | NT-06-054(P1, Opus, S) | C1 수용 기준 |
| C2 | G2 통과 후, C1과 병렬(W7) | 네이버(`custom:naver` 또는 서버 브리지, 스파이크로 결정) | NT-06-055(P1, Fable, M) | C2 수용 기준 |

**첫 제품 메모**: study-note는 개발 순서상 첫 제품이라(README "공용 코어를 먼저 실전 검증하는 제품") Stage A 시드 스크립트 계약(`AUTH_ROADMAP.md` 2.3·2.4절)이 여기서 처음 실전 검증됩니다. NT-06-006에서 계약과 다르게 동작하는 부분(예: 단독 `public` 스키마에서의 RPC 경로, 로컬 Supabase의 `auth.admin` 동작, 미인증 계정 로그인 가능 여부)이 나오면 코드를 조용히 맞추지 말고 task `log.md`에 `[DECISION]`으로 남기고 `06_AGENT_PLAN.md` 8.6절 C-12로 platform 쪽 `AUTH_ROADMAP.md` 보정을 요청합니다. 시드 스크립트 본체(`scripts/dev/seed-users.mjs`)와 제품 훅(`seed-users.notes.mjs`)을 분리해 다음 제품이 본체를 그대로 가져가게 합니다.

### 19.2 Stage A 로컬 실행 순서

| 순서 | 명령/동작 | 확인 |
|---|---|---|
| 1 | `supabase start` | Docker로 로컬 Supabase 기동(7절) |
| 2 | `supabase db reset` | 마이그레이션·seed 적용. `supabase/config.toml`은 A단계 값(`[auth.external.google]`·`[auth.external.kakao]` `enabled = false`, `[auth.email] enable_confirmations = true`) |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<로컬용 임의 값>` | `NEXT_PUBLIC_SUPABASE_URL`이 `http://127.0.0.1:54321`인지. 원격 URL이면 앱 기동이 실패합니다(정상 동작) |
| 4 | `node scripts/dev/seed-users.mjs --app notes`(`pnpm db:seed-users`) | 출력 표에 페르소나 10개(`owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops`, `unverified`, `low_credit`), `owner` 잔액 30, `low_credit` 잔액 3. 비밀번호는 출력되지 않습니다. 두 번 실행해도 잔액이 늘지 않습니다. 페르소나는 약관 동의 기록을 가진 상태로 만들어집니다(05장 10.2절) |
| 5 | `pnpm dev` → `http://localhost:3000/login` | 상단 `MOCK AUTH · 로컬 전용` 배지, 개발용 패널에서 페르소나 버튼 클릭 → `/app` |
| 6 | E2E: `pnpm exec playwright test` | `globalSetup`이 페르소나별 `storageState`를 저장하고 테스트가 그 상태로 시작합니다(NT-06-024) |

`.env.local`은 커밋하지 않습니다. 배포 환경에는 `DEV_SEED_PASSWORD`를 넣지 않고 `AUTH_MODE=live`입니다.

### 19.3 G1 체크리스트 (사람, Mock → Google)

판정은 대표님이 하고 결과를 NT-06-053 task `log.md`에 `[DECISION] G1 통과`로 남깁니다.

- [ ] `06_AGENT_PLAN.md` 2절 MVP P0 기능 작업 완료(B·C 작업 053~055, 공개 베타 직전 통합 작업 048 제외). 결제(026·027)는 Phase 2라 대상이 아닙니다
- [ ] 핵심 플로우 E2E(NT-06-024)가 Mock 페르소나 `storageState`로 녹색
- [ ] RLS 스모크(NT-06-003) 전 항목 통과, `outsider` 교차 테넌트 거부 확인
- [ ] 단계 분기 코드가 인증 모듈 밖에 0건(NT-06-022 CI)
- [ ] 이용약관·개인정보처리방침 페이지(NT-06-021)가 공개 URL로 열림(Google 동의 화면 등록에 필요)
- [ ] Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 방침·약관 URL, 승인된 도메인), 웹 클라이언트 ID, 운영 Supabase 프로젝트 준비(19.4)

### 19.4 Stage B 외부 설정 순서 (사람, `AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위는 `openid`, `email`, `profile`만 | 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml` `[auth.external.google] enabled = true`, `client_id = "env(GOOGLE_CLIENT_ID)"`, `secret = "env(GOOGLE_CLIENT_SECRET)"` | 키는 앱 env에 넣지 않습니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | Vercel env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email` | `DEV_SEED_PASSWORD` 없음 |
| 6 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |

B 작업(NT-06-053) 수용 기준은 `AUTH_ROADMAP.md` 5.3절 B-1~B-6입니다. Google 실로그인은 자동화하지 않고 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인해 task `log.md`에 남깁니다. Google 로그인 사용자의 `email_confirmed_at`이 채워지는지 확인해 `[DECISION]`으로 기록합니다(01장 D-23, 이 제품은 이메일 인증 전 정리 실행을 막습니다).

### 19.5 G2 체크리스트 (사람, Google → 카카오·네이버)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안, 감사 `auth.login`과 오류 로그)
- [ ] 신규 가입자 중 `entitled=false`로 남은 사용자 0(`AUTH_ROADMAP.md` 6장 SQL을 가입 기간으로 제한해 실행, 단독 모놀리스는 `core.` 대신 `public.`)
- [ ] 카카오 디벨로퍼스 앱 생성, 이메일 정책 결정(01장 D-20, 권고 비즈 앱 전환)
- [ ] 네이버 애플리케이션 등록, 검수 신청 자료(로그인 버튼부터 가입 완료까지 화면 캡처) 준비, C2 스파이크 결과 기록(01장 D-21)

결과는 NT-06-054·055 task `log.md`에 `[DECISION] G2 통과`.

### 19.6 C1 카카오 설정 (사람, `AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = `https://<project-ref>.supabase.co/auth/v1/callback`(로컬 `http://localhost:54321/auth/v1/callback`) |
| 4 | 카카오 로그인 활성(State ON), 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email` |
| 5 | Supabase → Providers → Kakao 사용. 이메일을 받지 못하면 "Allow users without an email"(D-20 (b)일 때만). 로컬은 `[auth.external.kakao]` |
| 6 | Vercel env `AUTH_PROVIDERS=google,email,kakao` |

수용 기준은 `AUTH_ROADMAP.md` 7.1.3절 C1-1~C1-5입니다. 설정 → 로그인 방법 화면(계정 연결)도 이 작업(NT-06-054)이 만듭니다.

### 19.7 C2 네이버 스파이크와 검수 (`AUTH_ROADMAP.md` 7.2.2절)

| 단계 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`provider_type: 'oauth2'`, authorize·token·사용자 정보 엔드포인트). 스크립트 `scripts/auth/register-naver-provider.mjs`로 남김 | 등록 성공 |
| 2 | 네이버 "개발중" 상태 + 등록한 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 채워졌는지, 같은 계정 재로그인이 같은 사용자인지 | 둘 다 참이면 `supabase_custom` 채택 |
| 4 | 실패하면 서버 브리지 경로 채택 → 코어 `staged/0010_core_auth_identity_links.sql`을 `public`으로 변환해 `supabase/migrations/` 다음 번호로 적용 요청(06장 C-11). 결과를 `NAVER_AUTH_PATH`와 `[DECISION]`에 기록 | 기록 |

로컬 CLI가 커스텀 제공자를 지원하는지는 미확인입니다. 지원하지 않으면 로컬 개발은 Mock·Google·카카오로 하고 네이버는 스테이징 프로젝트에서 확인합니다. 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다(C2-6). 수용 기준은 7.2.4절 C2-1~C2-6입니다.

### 19.8 단계 전환 요청 프롬프트 예시 (G1 통과 후 B 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/study-note/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
NT-06-053(인증 Stage B): G1 판정 [DECISION] G1 통과 가 tasks/NT-06-053-auth-stage-b/log.md 에 있는지 먼저 확인하고,
없으면 중단한다. 로그인 화면에 Google 버튼과 이메일 폼, /auth/callback(finishLogin), 이메일 가입·인증·비밀번호 재설정,
/onboarding/terms(약관·만 14세 확인) 를 만든다. 완료 조건 = ① docs/file/03-설계/공용코어/AUTH_ROADMAP.md 5.3절 B-1~B-6
② next=//evil.com 등 3종이 /app 으로 ③ AUTH_MODE=mock VERCEL_ENV=production 빌드 실패, /api/dev/login 404
④ Mock 페르소나 E2E(NT-06-024) 계속 녹색 ⑤ Google 실로그인 수동 점검표 결과와 email_confirmed_at 확인 결과를 log.md 에 기록
⑥ 06_AGENT_PLAN.md 8.1절 NT-06-053 수용 기준 충족.

[작업의 특성]
인증 모듈과 로그인 화면·콜백·온보딩 약관 단계만. 기능 코드에 단계 분기 금지. Google 클라이언트 시크릿은 앱 env 에 넣지 않는다.
작업 대상 경로: apps/web/src/lib/auth/providers/, apps/web/src/components/auth/providers/, apps/web/src/app/auth/callback/,
apps/web/src/app/(auth)/{signup,verify,reset-password}/, apps/web/src/app/(auth)/login/page.tsx(NT-06-006에서 이어 받음),
apps/web/src/app/onboarding/terms/, apps/web/src/app/api/onboarding/terms/, apps/web/tests/e2e/auth/,
supabase/config.toml 의 [auth.external.google] 블록. (proxy.ts 의 /auth/callback 공개 경로와 약관 이동은 NT-06-005 파일에 1줄 요청)

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert, supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

C1·C2도 같은 형식으로, 첫 줄 확인 대상을 `[DECISION] G2 통과`로, 완료 조건을 7.1.3절·7.2.4절로 바꿔 씁니다. B 작업의 baseline에는 `DOC-CORE-009`(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md`)를 넣습니다.

### 19.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 우선순위 | 모델 | 웨이브 |
|---|---|---|---|---|
| A | NT-06-006(범위 변경: 인증 모듈, Mock 로그인, 시드, 가드, `finishLogin`) | P0 | Opus | W2 |
| B | NT-06-053 | P0 | Fable | W6 맨 앞(G1 후) |
| C1 | NT-06-054 | P1 | Opus | W7(G2 후) |
| C2 | NT-06-055 | P1 | Fable | W7(G2 후) |
| 관련 | NT-06-003(RLS, `outsider`), NT-06-024(Mock storageState E2E), NT-06-022(CI 금지 문자열·배포 빌드 검사) | P0, 022는 P1 | W1, W4, W0 | - |

## 부록 A. 스크립트 없이 손으로 할 때

`study-note-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\study-note\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/study-note"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\study-note" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\study-note" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/study-note"` | `Set-Location "D:\WorkSpace\DEV\study-note"` | `cd /d "D:\WorkSpace\DEV\study-note"` |
| 3 초기화 | `bash init-project.sh study-note --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh study-note --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh study-note --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/study-note/study-note-root/." "D:/WorkSpace/DEV/study-note/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\study-note\study-note-root\*" "D:\WorkSpace\DEV\study-note" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\study-note\study-note-root" "D:\WorkSpace\DEV\study-note" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
