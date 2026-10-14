# nomad-blog(NOMAD Blog) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 nomad-blog 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\nomad-blog\setup-nomad-blog.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/nomad-blog/setup-nomad-blog.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\nomad-blog\        platform에 남는 안내서, 도구, 재료
├── nomad-blog_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-nomad-blog.sh          설치 스크립트(Git Bash / Linux)
├── setup-nomad-blog.ps1         설치 스크립트(Windows PowerShell)
└── nomad-blog-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(nomad-blog-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\nomad-blog\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← nomad-blog-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(56개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | NOMAD Blog. 키워드 하나로 AI가 블로그 원고를 쓰고, 제휴 상품 카드와 대가성 문구를 자동으로 넣어 네이버 블로그·티스토리·워드프레스에 예약 발행하는 조직 단위 SaaS. 네이버 브랜드커넥트 지원도 완전 자동(Playwright)으로 제출 |
| 통합 원본 | NOMAD Shorts Maker 안의 Content Automator(`D:\WorkSpace\platform\NOMAD Shorts Maker\`), Youtube_shots_Maker Track D(`D:\WorkSpace\platform\Youtube_shots_Maker\`, git 스냅샷 `5f6d262`만 읽음), nomad-ai-commerce·nomad-ai-factory의 블로그 원고 개념 |
| 모듈러 앱 id / 스키마 | `blog` / `blog` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 05장 8절. 모듈러가 1차 출시 기본이고 모놀리스는 준비만 해 둔 것이라 착수 전 확인이 필요합니다. 8절 D-8) |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 조직 자료 RAG, 토픽·키워드 위키, 초안 그래프 `blog.post_draft`(사람 승인 포함), 글쓰기 도우미 채팅(Dify), 음성 받아쓰기와 음성 대화 |
| 변하지 않는 규칙 | 네이버 브랜드커넥트 완전 자동 지원과 위험 동의, 제휴 대가성 문구 자동 삽입(끌 수 없음)은 확정 결정 12 그대로이며 AI 계층이 바꾸지 않습니다 |

**경로 읽는 법.** 기획서의 `apps/nomad-blog/`는 개발 폴더에서는 베이스의 `apps/web/`로 읽습니다(웹), `apps/api/`는 그대로(FastAPI AI 서비스)입니다. 워커 `workers/blog-worker/`와 공용 패키지 `packages/blog-render/`, `packages/blog-rules/`는 개발 폴더 루트에 새로 만듭니다. 실제 배치는 첫 스캐폴딩 task에서 확정합니다(구현 시 확인).

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), `workers/blog-worker` | `node -v; pnpm -v` | 같음 |
| Playwright Chromium | 발행·브랜드커넥트 어댑터 테스트(워커) | `pnpm exec playwright --version` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버, 로컬 WordPress(발행 테스트) | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM, FastAPI 전용. Next.js·워커에는 두지 않습니다)
- ElevenLabs(음성, Next.js 서버 전용)
- Toss Payments(결제)
- Supabase
- 채널 자격증명 암호화 키 `CREDENTIALS_KEY_V<n>`(없으면 기동 실패. 0키 폴백 금지)

쿠팡파트너스 키와 네이버·티스토리·워드프레스 자격증명은 환경변수가 아니라 조직별 `encrypted_credentials`에 저장합니다. 임베딩은 `oss-embed` 고정이라 Voyage 키는 없어도 동작합니다.

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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\nomad-blog`로 복사 |
| 2 | **복사본 안의** `init-project.sh nomad-blog --reset-git` 실행 |
| 3 | `nomad-blog-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `nomad-blog-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/nomad-blog/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/nomad-blog/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/nomad-blog/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/nomad-blog/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/nomad-blog/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/nomad-blog/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/nomad-blog/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 8개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~008 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/nomad-blog/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/nomad-blog/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/NOMAD_Shorts_Maker.md`, `Youtube_shots_Maker.md`, `nomad-ai-commerce.md`, `nomad-ai-factory.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/nomad-blog/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/nomad-blog/supabase/monolith/migrations/0002_blog_domain.sql` | `supabase/migrations/20261013000002_blog_domain.sql` | - | DB |
| `docs/products/nomad-blog/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다. 이번 생성 결과는 경로 참조 383개, 묶음 안 누락 0, 절대경로 누락 0입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다(`python -I build_root.py nomad-blog`).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\nomad-blog\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 nomad-blog-root에서 온 것입니다.

```
D:\WorkSpace\DEV\nomad-blog\
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
│   ├── web\                          [베이스] Next.js(코드 없음, W0~W1에서 스캐폴딩. 기획서의 apps/nomad-blog)
│   └── api\                          [베이스] FastAPI(코드 없음, W1에서 스캐폴딩)
├── workers\blog-worker\              [신규] 발행·브랜드커넥트 워커(BL-06-010에서 생성)
├── packages\blog-render\, blog-rules\   [신규] 렌더·sanitize, 출력 규칙(BL-06-008, 047에서 생성)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\NOMAD_Shorts_Maker.md, Youtube_shots_Maker.md, nomad-ai-commerce.md, nomad-ai-factory.md   [묶음]
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
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 blog-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_blog_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.x, React 19, TypeScript strict, Tailwind CSS v4, shadcn/ui(v4 지원 버전), TipTap, zod, TanStack Query | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 워커 | Node 20+ TS(`blog-worker`, core-jobs `runWorker`) + Playwright Chromium. Redis·BullMQ 없음(`core.jobs`가 큐) | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test`, `pnpm test:rls`, `pnpm test:ai`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/database.ts` | 타입 생성(경로 제안) |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. pgvector 확장은 Supabase에서 기본 제공되며 `extensions` 스키마에 생성됩니다. blog는 코어 [선택] 절을 하나도 지우지 않았습니다(결제, 크레딧, 자격증명, 잡, Storage, affiliate 모두 사용).
- `seed.sql`에는 앱 1행, 플랜 3종(AI 키 6개 포함), 크레딧팩 3종, 대가성 문구 기본값 4행, AI 라우팅 기본값 12행이 들어 있습니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(BL-06-001)의 수용 기준입니다.
- RLS 회귀 테스트는 BL-06-028에서 `supabase/tests/`로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 20개(D-1~D-20)를 확정합니다. D-1~D-12는 기존 8절의 #1~#12와 같은 번호입니다. 기획은 각 항목의 "권고와 이 기획의 가정"으로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 네이버 블로그에 쿠팡 링크(경고 후 허용 / 차단) | 발행 오케스트레이션(BL-06-014) 전 |
| D-2 | 네이버 채널 링크 형식(단축 링크 / 직접 링크) | 제휴 API(BL-06-016) 전 |
| D-3 | 텐핑·네이버쇼핑 커넥트(공개 API 확인) | 제휴 API(BL-06-016) 전 |
| D-4 | 브랜드커넥트 무인 자동 지원 규칙 | Phase 2 |
| D-5 | AI 활용 표기(기본 ON, 해제 가능 여부), 법률 검토 | 렌더러(BL-06-008) 전 |
| D-6 | 네이버·티스토리 자격증명 방식(비밀번호 암호화 / 쿠키 가져오기) | 채널 연결(BL-06-009) 전 |
| D-7 | 티스토리 공식 API 여부 | 티스토리 어댑터(BL-06-012) 전 |
| D-8 | 배포 DB와 모놀리스 스키마 | 착수 전(이 문서는 단독 `public` 기준) |
| D-9 | seed의 blog 플랜 | 닫힘(2026-10-13 반영 완료) |
| D-10 | 인스타그램 포함 시점 | Phase 2 |
| D-11 | 환불 정책, 법률 검토 | 결제(BL-06-025) 전 |
| D-12 | 네이버 소셜 로그인 | 인증(BL-06-004) 전(MVP 미도입 가정) |
| D-13 | 비공개 브랜드 자료와 상용 AI | 자료 RAG(BL-06-048) 전 |
| D-14 | 캠페인 요강·브랜드 소재의 AI 색인 허용 범위 | 자료 RAG(BL-06-048) 전 |
| D-15 | 워커의 그래프 호출 인증(잡 토큰) | AI 게이트(BL-06-046) 전 |
| D-16 | 받아쓰기·읽어 주기 제공자와 ElevenLabs 데이터 보관 | 음성(BL-06-053) 전 |
| D-17 | 채팅 화면 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(BL-06-041) 전 |
| D-18 | 운영자 규정 해설집 컬렉션 | Phase 2(MVP는 규칙 사전만) |
| D-19 | 공정 사용 한도와 월 크레딧 재산정 | AI 게이트(BL-06-046) 전, 출시 전 재확인 |
| D-20 | 반복 시리즈 무인 AI 초안의 사람 승인 | Phase 2(시리즈 작업 전) |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 BL-06-001~056, 모두 56개입니다. 그중 BL-06-043은 사람이 하는 디자인 비주얼 검토입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 003, 033, 035, 041 | 없음 | DB 적용·타입(AI 기본값 포함), 앱 골격, 아카이브·키 점검, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 004, 007, 008, 010, 020, 032, 045, 047 | W0 | 모듈러→모놀리스 변환 스크립트, 인증, 에디터 확장, 렌더러, 워커 런타임, `/r`, CI, AI 서비스 설치, 공용 출력 규칙 |
| W1-D | 042 → 043 → 044(직렬) | 003, 041 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 006, 009, 011, 012, 013, 025, 028, 031, 046, 048 | W1 | 게이팅, 단건 AI 라우트(FastAPI 경유), 채널 연결, 어댑터 3종, 결제, RLS·렌더 테스트, AI 게이트, RAG 색인 |
| W3 | 014, 016, 019, 023, 029, 034, 049, 050, 051, 055 | W2, 화면은 044 | 발행 오케스트레이션(승인 확인), 제휴, 컴플라이언스, 채널 화면, 결제 E2E, 위키, 초안 그래프, Dify 채팅, 3D 히어로 |
| W4 | 015, 017, 021, 022, 026, 027, 030, 038, 052 | W3 | 생성 잡(그래프 연결), 브랜드커넥트 API, 앱 화면, 랜딩, 설정, 발행 통합 테스트, 내보내기, 채팅 패널·자료 화면 |
| W5 | 018, 024, 036, 037, 053 | W4 | 브랜드커넥트 워커와 화면, 문구 점검, 생성 E2E, 음성 대화 |
| W6 | 054 → 056(직렬) | W5 | 음성 받아쓰기, AI·음성 보안 회귀. **MVP 완료 조건** |
| W7 | 039, 040 | MVP 출시 | Phase 2(n8n/Make 브릿지, 인스타그램 카드 포스팅) |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 결제, 권한, RLS, 자격증명, 데이터 모델, AI 보안 설계 | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 어댑터, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(BL-06-043) | 사용자 |

리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다. 모델 비율은 모델 작업 55개 기준 Fable 11, Opus 28, Sonnet 13, Haiku 3입니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/BL-06-001-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # BL-06-001 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/nomad-blog/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
BL-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 blog_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ ai_routing_settings 의 app_id='blog' 행 12개와 plans.features 의 AI 키 6개 확인
④ supabase gen types 결과를 apps/web/src/types/database.ts 에 저장 ⑤ 06_AGENT_PLAN.md 의 BL-06-001 수용 기준 충족.

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

- **MVP 출시 조건**: W6까지 완료, AI 보안 회귀(BL-06-056) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다. 발행 통합 테스트(BL-06-030)와 생성 E2E(BL-06-037)에서 대가성 문구 포함률 100%여야 합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).
- 같은 디렉토리를 두 task가 쓰지 않도록 `write_scope`를 06장 2절의 "소유 파일/디렉토리"로 지정합니다. `src/app/api/ai/`와 `src/server/ai/`는 분할 소유입니다(06장 1절).

## 11. AI 계층 구축 (nomad-blog)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절

| 구성 | nomad-blog 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance). LLM 키는 여기에만 둡니다 | BL-06-045 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 12행(`blog.post_draft`·`blog.assist`·`chat` auto, `blog.compliance` 3개 후보, 위키 작업 오픈소스 우선, Dify 보조 노드 오픈소스 강제, 자료 임베딩 oss-embed 고정, 받아쓰기 오픈소스 우선) | BL-06-045, 046 |
| 국외 이전 동의 | 온보딩 `/onboarding/ai`에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음. 처리방침·랜딩의 고지 문구는 법적 문구 작업과 함께 | BL-06-046, 026 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산, EdDSA 토큰 발급, 잡 토큰, 발행 전 승인·반려 | BL-06-046 |
| RAG | 조직 자료 컬렉션 `blog-materials`(브랜드·상품·캠페인 자료, oss-embed). 업로드 한도는 `features.rag_documents` | BL-06-048, 052 |
| 제품 위키 | 토픽·키워드 위키(조직 내부, Pro 이상). 사람 소유 블록 보호, 주 1회 lint, 개인정보 포함 자료 제외 | BL-06-049 |
| LangGraph | `blog.post_draft`: 키워드 리서치 → 자료 검색 → 초안 → 제휴 링크·대가성 점검 → SEO 점검 → 규정 검사 → 사람 승인(interrupt). 대가성 문구는 AI가 쓰지도 지우지도 않음. 공용 금지 표현 규칙 파일 | BL-06-050, 047 |
| 사람 승인 | 그래프 `approve`에서 멈추고 `ai-approve`로 재개. 발행·예약 라우트가 승인을 확인(`AI_APPROVAL_REQUIRED`). 승인 화면 `/posts/[id]/review` | BL-06-046, 014, 022 |
| 생성 잡 연결 | 워커 `blog.generate`가 잡 토큰으로 그래프를 실행하고 결과를 저장 | BL-06-015 |
| Dify 채팅 | 공용 Dify에 `blog-chat` Chatflow 등록. 입력 `platform_conversation_id`, HTTP 노드 → `/tools/answer`(내부 키). 조직 데이터라 외부 지식 API는 쓰지 않음. 설정은 `infra/dify/README.md` | BL-06-051, 052 |
| 음성 | 음성 대화(STT는 오픈소스 우선, TTS는 ElevenLabs 우선), 에디터 음성 받아쓰기(오픈소스 우선). 녹음 원본은 저장하지 않음 | BL-06-053, 054 |
| 보안 회귀 | 조직 격리, 대화 매핑 위조, 강제 오픈소스·국외 동의 우회, 크레딧 우회, 승인 전 발행, 채널 비밀의 AI 입력 유입 | BL-06-056, 028 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다. 코어 요청(AI-R3 잡 토큰, AI-R4 단건 호출·위키 저장, AI-R7 그래프 재개)은 `06_AGENT_PLAN.md` 6.1절을 확인합니다.
2. 오픈소스 서버가 준비되기 전에는 라우팅을 상용만 쓰도록 둡니다. 이때는 국외 동의가 있는 테스트 조직으로 개발합니다.
3. 준비되면 기본값으로 되돌립니다.

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보(채널 비밀번호, 세션 쿠키 포함)는 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 24개)는 setup 시 함께 들어옵니다.
- 이 위키는 개발용입니다. 제품 기능인 "토픽·키워드 위키"(BL-06-049, DB 저장)와 구분합니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 앱 화면은 Primer(발행 관리의 정보 밀도), 보조 Atlassian(캘린더·상태 배지), 채팅은 Astryx 패턴(확인 후, D-17), 랜딩은 HERO_3D | BL-06-041, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(원고지, 먹, 교정 적색, 잉크 청, 괘선, 문구 노랑) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`, 기본 컴포넌트, `/dev/components` | BL-06-042 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다(문구 노랑 위 글자 대비 포함) | BL-06-043(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | BL-06-044 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다. CI가 `tailwind.config.*`와 `@tailwind base`를 막습니다(BL-06-032).
- 화면 작업(021~024, 026, 027, 049, 052, 055)은 BL-06-044가 끝난 뒤에 시작합니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.6)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 괘선이 그어진 원고 시트가 평평하게 놓이고, 키워드를 넣으면 3등분으로 접혀 채널 카드 3장(네이버·티스토리·워드프레스)으로 나뉘어 발행됩니다. 카드마다 대가성 문구 띠가 먼저 붙어 있습니다 |
| 모바일(767px 이하) | 가벼운 3D 자동 로드: 시트 1장이 한 번 접히는 연출만, 채널 카드는 HTML 칩 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 카드 3장이 놓인 정지 렌더 이미지 |

- 제목, 입력, 채널 이름 칩은 HTML로 3D 위에 겹칩니다. 3D 안에는 글자를 그리지 않습니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 금지: 보라/핑크 그라디언트, 종이비행기·종이 조각 파티클, 별 파티클, 노트북 목업 3D, video와 구분 안 되는 다크 장면
- 히어로를 3D로 바꾼 것은 사용자 결정(2026-10-13, 확정 결정 15)입니다. 토큰·서체·카피 원칙은 그대로입니다.
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(BL-06-055, 026)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` nomad-blog 절(`:101`)에 있습니다.

| 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|
| Awwwards | https://www.awwwards.com/sites/catalyze-ai-saas-website | AI SaaS 랜딩의 기능 설명 순서와 제품 화면 노출 방식(장식 그라디언트·아이브로 라벨은 가져오지 않음) | 랜딩 |
| Dribbble | https://dribbble.com/shots/20827495-AI-Writing-tool-Website | 첫 화면에서 "검색에 맞춘 원고를 만든다"는 가치를 설명하는 카피 구조(영어 카피·일러스트 제외) | 랜딩 히어로 카피 |
| Dribbble | https://dribbble.com/shots/22408990-Lexi-AI-Writer-Assistant-Web-App-Saas-Platform-Chat-AI | 편집기 옆 대화형 수정 패널 | 에디터 |
| Dribbble | https://dribbble.com/shots/9895896-WP-Scheduled-Posts-Missed-Schedule-Best-Editorial-Calendar | 편집 캘린더 + 예약 위젯 | 캘린더 |
| Dribbble | https://dribbble.com/shots/14671941-Farmhouse-Affiliate-Marketing-Dashboard | 상품별 클릭·수익 추이 | 제휴 통계 |

- URL은 이 표와 `REFERENCES.md`에 있는 것만 씁니다. 새 레퍼런스가 필요하면 URL을 직접 열어 확인하고 `REFERENCES.md`에 먼저 추가한 뒤 씁니다.
- 영감용이지 복제용이 아닙니다. 로고·사진·일러스트·아이콘·카피·폰트·색 조합 전체를 가져오지 않고, 레이아웃을 따라 그리지 않습니다. 구조(정보 배치, 위계, 리듬)만 참고하고 토큰은 제품 주제에서 다시 뽑습니다(`03_SCREENS_UX.md` 4.3절).
- Dribbble 링크는 작업 전에 브라우저에서 한 번 엽니다(자동 확인이 막혀 있어 색인으로만 확인됨). 열리지 않으면 `REFERENCES.md`에서 지우고 다른 후보를 씁니다.
- 순서: 레퍼런스(이 절) → 브리프(4.2절) → 토큰 플랜(4.3절) → 13.1 디자인 시스템 → 13.2 메인 히어로. AI에게 화면을 맡길 때 지시에 이 표의 행(제목과 "참고 포인트")을 적습니다.
- 확인: 결과 스크린샷을 이 표의 "참고 포인트"와 나란히 놓고, 가져오지 않기로 한 요소(로고·카피·기본값 스타일)가 섞이지 않았는지 고문 디자인 검토에서 대조합니다.

## 14. 원본 이식

정본: `docs/file/04-구현/07_SOURCE_MIGRATION.md`

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장의 "이식 자산" 목록에서 필요한 파일만 옮기고 07장 2절의 수정 목록을 적용해 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\NOMAD Shorts Maker\`(CA: `src/skill/**`, `src/components/posts/*`), `D:\WorkSpace\platform\Youtube_shots_Maker\`(YSM은 작업 트리가 아니라 `git show 5f6d262:Youtube_shots_Maker/<경로>`로만 읽습니다).
- 리뷰 "높음" 16건(NOMAD_Shorts_Maker 12, Youtube_shots_Maker 4)의 차단 설계는 `02_ARCHITECTURE.md` 6절과 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: `x-internal-call`, Mock 브랜드커넥트 추천, 가상 후기 프롬프트, 봇 감지 우회, 프록시 순환)과 3.3절의 AI 계층 추가 폐기(웹·워커의 LLM 직접 호출, 승인 없는 즉시 발행)는 옮기지 않습니다.
- 원본 폴더는 고치지 않습니다. 아카이브 태그와 키 재발급은 사용자 승인 후 진행합니다(BL-06-033, 035, 07장 5절).

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 워커 | `workers/blog-worker`는 Next를 import하지 않는 독립 패키지입니다. 큐 `blog.ai`, `blog.publish`, `blog.browser`는 이 워커만, `blog.aisvc`는 FastAPI만 소비합니다 |
| 렌더·규칙 | `packages/blog-render`(렌더·sanitize·대가성 문구)는 웹과 워커가 공유, `packages/blog-rules`(금지 표현)는 TS와 Python이 같은 파일을 읽습니다 |
| affiliate | 링크, 클릭, 대가성 문구, 브랜드커넥트 DB는 코어 소유입니다. blog는 매핑과 FK만 두고 브랜드커넥트 Playwright 흐름은 blog가 소유합니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 AI-R1) |
| 남은 코어 과제 | `adjust_credits` 미구현(크레딧팩 환불), AI-R2(모듈러 seed 플랜 AI 키), AI-R3(잡 토큰 패턴), AI-R4(단건 호출·위키 저장), AI-R7(그래프 재개). `docs/file/01-관리/06_AGENT_PLAN.md` 6절을 참고합니다 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- 기획 단계 SQL 검증 명령(개발 폴더에서는 같은 파일이 `supabase/`에 있습니다):
  - `node check.mjs --vector mod`(0000~0009 + 모듈러 seed + `1300_blog.sql`)
  - `node check.mjs --vector mono`(`0001_core_lite` + `0002_blog_domain` + `seed.sql`)
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다(빌드·타입·린트, RLS 스모크, 결제 E2E, 발행 통합, 대가성 문구 포함률 100%, AI 회귀, 3D·디자인 시스템).

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| 네이버·티스토리 자동 게시와 브랜드커넥트 자동 지원의 약관 위험 | 공식 API가 아니라 Playwright로 사용자 계정을 조작합니다. 위험 고지와 동의(owner/admin, 고지문 버전) 없이 자동 작업을 실행하지 않고, CAPTCHA 우회·봇 감지 우회·프록시 순환을 쓰지 않습니다. 약관은 미확인입니다(01장 6.4절) |
| 대가성 문구 누락 | 렌더러가 제휴 매핑·도메인 스캔·브랜드커넥트 연결로 필수 여부를 계산하고 DB 불변식(23514)이 막습니다. AI는 문구를 쓰거나 지우거나 숨기지 않습니다. 포함률 100%가 아니면 장애로 봅니다 |
| 승인 없는 AI 발행 | 발행·예약 라우트의 승인 확인과 BL-06-056 회귀 테스트. 승인 확인은 DB 불변식이 아니라 서버 규칙이므로 우회 경로(내부 호출 헤더 등)를 만들지 않습니다 |
| 채널 비밀의 AI 유입 | 그래프·채팅 입력 스키마에 비밀 필드를 두지 않고, 로그·프롬프트·위키에 쓰지 않습니다 |
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 크레딧 선차감과 정산, 기능별 라우팅, 오픈소스 우선 기능으로 관리합니다. 그래프 정액(5/8)이 월 크레딧을 더 쓰므로 운영 중 `core.ai_usage`로 원가를 확인해 단가와 D-19를 재확인합니다 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, 체험 메모·채팅 마스킹, 녹음 기본 미저장, 비공개 자료 안내(D-13) |
| Playwright 워커 운영 | 계정당 브라우저 1개 잠금, 발행 간격 10분·일일 상한, 셀렉터 변경 시 운영 알림(사이트 변경 감지) |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 원본 `.env` 키는 재사용하지 않고 재발급합니다(BL-06-035). 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, Playwright, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D-1~D-20 확정(Phase 2 항목은 보류 가능), 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] W1~W6 진행, AI 보안 회귀 통과, 대가성 문구 포함률 100%, MVP 출시 조건 충족

## 부록 A. 스크립트 없이 손으로 할 때

`nomad-blog-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\nomad-blog\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/nomad-blog"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-blog" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-blog" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/nomad-blog"` | `Set-Location "D:\WorkSpace\DEV\nomad-blog"` | `cd /d "D:\WorkSpace\DEV\nomad-blog"` |
| 3 초기화 | `bash init-project.sh nomad-blog --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh nomad-blog --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh nomad-blog --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/nomad-blog/nomad-blog-root/." "D:/WorkSpace/DEV/nomad-blog/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\nomad-blog\nomad-blog-root\*" "D:\WorkSpace\DEV\nomad-blog" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\nomad-blog\nomad-blog-root" "D:\WorkSpace\DEV\nomad-blog" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버, 로컬 WordPress).
