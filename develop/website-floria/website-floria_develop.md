# website-floria(Floria 브랜드 사이트) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 website-floria 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\website-floria\setup-website-floria.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/website-floria/setup-website-floria.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\website-floria\        platform에 남는 안내서, 도구, 재료
├── website-floria_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-website-floria.sh          설치 스크립트(Git Bash / Linux)
├── setup-website-floria.ps1         설치 스크립트(Windows PowerShell)
└── website-floria-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\
                │
                │ setup 스크립트가 복사(website-floria-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\website-floria\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← website-floria-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(49개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 인증 단계(Mock → Google), 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~18 |
| - | 체크리스트 | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Floria "Botanic Architecture" 브랜드 사이트. 고급 주거·갤러리·기업 공간의 식물 설치 의뢰를 문의·뉴스레터로 잇고, 초대받은 소수 운영자가 문의를 처리하는 콘솔을 둡니다. 2026-10-13부터 방문자 AI 상담(텍스트·음성)과 3D 온실 구조물 히어로가 들어갑니다. 요금·크레딧·결제는 없습니다 |
| 통합 원본 | `WebSite/Botanic_Architecture`(베이스), `Floria_Neo`(카피 출처). `Floria_NEO_02`, `Lucury Website`, `Biz_Website`는 합치지 않는 연계 사이트(P2) |
| 모듈러 앱 id / 스키마 | `site` / `site`(통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D-8 가정) |
| 개발 근거 | `docs/file/`의 산출물 25개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 방문자 AI 상담(RAG, LangGraph `site.consult`, Dify), 방문자 음성 상담, 브랜드 지식 위키(`/guide`), 운영자 AI 설정. 비용은 운영자 조직 예산(크레딧 없음) |
| 폴더 대응 | 기획서의 `apps/website-floria/`(Next.js)는 베이스의 `apps/web/`에, `apps/api/`(FastAPI)는 베이스의 `apps/api/`에 대응합니다 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, npm | `apps/web`(Next.js 16). 기획서는 `npm ci`를 씁니다 | `node -v; npm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키와 계정**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM, 운영자 조직이 국외 이전에 동의할 때만 쓰임)
- Voyage(플랫폼 기본 임베딩 호환용, 이 제품은 오픈소스 임베딩 고정)
- ElevenLabs(음성, 국외 이전 동의 시)
- Cloudflare Turnstile(문의·구독·상담 시작 CAPTCHA, 제안·미확인), 메일 발송 사업자(D-6)
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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\website-floria`로 복사 |
| 2 | **복사본 안의** `init-project.sh website-floria --reset-git` 실행 |
| 3 | `website-floria-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `website-floria-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/website-floria/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/website-floria/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/website-floria/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/website-floria/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/website-floria/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/website-floria/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/website-floria/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(AUTH_ROADMAP은 DOC-CORE-009, 2026-10-14 인증 단계) |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/website-floria/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/website-floria/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/WebSite.md` | `docs/reference/reviews/WebSite.md` | 참고 | 원본 리뷰 |
| `docs/products/website-floria/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/website-floria/supabase/monolith/migrations/0002_website_floria_domain.sql` | `supabase/migrations/20261013000002_website_floria_domain.sql` | - | DB |
| `docs/products/website-floria/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 25개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 경로 검사 결과(2026-10-13): 경로 참조 360개, 묶음 안 누락 0, 절대경로 누락 0.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\website-floria\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 website-floria-root에서 온 것입니다.

```
D:\WorkSpace\DEV\website-floria\
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
│   ├── web\                          [베이스] Next.js(코드 없음, W0에서 스캐폴딩). 기획서의 apps/website-floria/
│   └── api\                          [베이스] FastAPI(코드 없음, W2에서 AI 서비스 설치). 기획서의 apps/api/
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\WebSite.md        [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(25개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 9개(AUTH_ROADMAP 포함)            [묶음]
│   │   │   └── 디자인\ 5개 + DESIGN.md, COMPONENTS.md     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   └── wiki\WIKI_SCHEMA.md, index.md, log.md, sources\  [묶음] 개발 위키
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 site-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_website_floria_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16, React 19.2, TypeScript 6.0, Tailwind CSS v4(4.x 고정), shadcn/ui(Tailwind CSS v4 지원 버전) | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19.2 호환 버전, 구현 시 확인) | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 워커 | 알림 워커 `worker/notify/`(Railway 소형 프로세스, 제안). LLM 키 없음 | 같은 곳 4절 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마. 크레딧·잡·Storage 절이 없는 `core_lite` | `05_DATA_MODEL.md` 8절 |
| 검증·테스트 | zod, pydantic, Vitest, Playwright, axe, pytest, Lighthouse CI | 같은 곳 |
| 명령 | `npm ci / run dev / run build / run lint`, `npx tsc --noEmit`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 Tailwind CSS v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/db.ts` | 타입 생성(경로 제안) |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있고 크레딧(4)·결제(3)·잡(7)·Storage(8) 절은 없습니다. 그래서 이 제품의 AI는 크레딧·`core.jobs`·Storage를 쓰지 않습니다(`05_DATA_MODEL.md` 8절).
- 도메인 파일에는 `sites.accepts_ai_chat`, `accepts_voice`(기본 꺼짐)와 RPC `update_ai_settings`가 있고, `seed.sql`에는 AI·음성 라우팅 기본값 8행(`app_id='site'`)과 체인 검사가 있습니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`, 2026-10-13 모듈러·모놀리스 모두 OK, 반복 적용 후 라우팅 8행). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 DB 작업(SI-06-003)의 수용 기준입니다.
- RLS 회귀 테스트는 SI-06-004에서 `tests/rls/`로 만듭니다. 기획 단계 스모크 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 21개(8.1절 인증 단계 D-18~D-21 포함)를 확정합니다. 기획은 각 항목의 권고로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | Floria는 실제 사업체인가(사업자 정보) | 착수 전(SEO·푸터·JSON-LD 작업 SI-06-006, 012 전) |
| D-2 | "로컬 소싱 반경" 주장 사용 여부와 단위 | 콘텐츠 작업(SI-06-006) 전 |
| D-3 | 컬렉션 가격 표시와 통화 | 콘텐츠 작업(SI-06-006) 전 |
| D-4 | 온라인 판매(Shop) | Phase 3, 별도 기획 |
| D-5 | 기본 언어 | 콘텐츠 작업(SI-06-006) 전 |
| D-6 | 메일 발송 사업자와 CAPTCHA 사업자 | 구독·알림·문의 API(SI-06-016~018) 전, 처리방침(SI-06-023) 확정 전 |
| D-7 | 실제 사진 확보 방법 | 이미지 파이프라인(SI-06-007) 전 |
| D-8 | 모놀리스 스키마 `public` 확정 | 착수 전(이 문서는 단독 `public` 기준) |
| D-9 | 연계 사이트 보강 시점 | MVP 이후(P2, SI-06-030~032) |
| D-10 | AI 상담을 출시 때 켤 것인가 | 상담 위젯(SI-06-045) 전, 운영 개시 전 |
| D-11 | 상담 지식의 출처와 사례 공개 동의 | 지식 원고(SI-06-039) 전 |
| D-12 | 운영자 조직의 국외 이전 동의와 고지 | AI 게이트(SI-06-037)·콘솔 AI(SI-06-038) 전, 법무 확인 |
| D-13 | AI 일일·월 예산과 방문자 한도 | AI 게이트(SI-06-037) 전(제안값으로 시작해 4주 로그로 조정) |
| D-14 | 음성 상담 공개와 보이스, ElevenLabs 데이터 보관 | 음성 상담(SI-06-046) 전 |
| D-15 | 방문자 대화 보존 기간 | AI 게이트(SI-06-037)·퍼지(SI-06-027) 전 |
| D-16 | 공개 지식 페이지 `/guide` 공개 | 공개 지식 페이지(SI-06-042) 전 |
| D-17 | 채팅 위젯 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(SI-06-033) 전 |
| D-18, D-19 | 카카오 이메일 정책, 네이버 경로 | 해당 없음(이 제품 C단계 제외, 13장) |
| D-20 | 운영자 이메일+비밀번호 로그인 유지(권고: 유지 + Google) | 인증 Stage B(SI-06-049) 전 |
| D-21 | C단계 제외 재검토 조건(권고: 제외 유지) | 공개 베타 운영 뒤 필요할 때 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 SI-06-001~049, 모두 49개입니다. 그중 SI-06-034는 사람이 하는 디자인 비주얼 검토입니다. SI-06-030~032는 연계 사이트(P2)입니다. SI-06-049는 인증 Stage B(Google + 초대 메일, 2026-10-14 추가)이고, 기존 SI-06-019는 인증 Stage A(Mock)로 범위가 바뀌었습니다(13장). 카카오·네이버(C단계) 작업은 이 제품에서 제외라 없습니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 033 | 없음 | 빌드되는 빈 앱, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 006, 007 | W0 | CSP/환경변수, DB 적용·타입(AI 스위치·라우팅 8행), 콘텐츠 데이터, 자산 파이프라인 |
| W1-D | 005 → 034 → 035(직렬) | 001, 033 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 004, 008, 009, 010, 011, 016, 017, 019, 023, 024, 027, 028, 036, 039 | W1, 화면은 035 | RLS 테스트, 섹션, 라우트, 공개 API, 콘솔 가드와 인증 Stage A(Mock 로그인·시드 페르소나), 법적 문구·고지문, 게이트, 퍼지, AI 서비스 설치, 지식 원고 |
| W3 | 012, 013, 014, 015, 018, 020, 021, 022, 029, 037, 040, 047 | W2 해당 선행 | SEO, 접근성, 폼 UI, 알림, 콘솔 화면, 아카이브 계획, AI 게이트, RAG 색인, 3D 히어로 |
| W4 | 026, 038, 041, 043, 045 | W3 해당 선행 | 통합 테스트, 콘솔 AI 설정, 위키 운영, 상담 그래프, 상담 위젯 |
| W5 | 042, 044, 046 | W4 해당 선행 | 공개 지식 페이지, Dify 채팅, 음성 상담 |
| W6 | 049(G1 통과 후 먼저), 025, 048 | W5, 049는 G1 | 인증 Stage B(Google + 초대 메일), e2e 전체, AI 보안 회귀. **MVP 출시(공개 베타) 조건** |
| W7 | 030, 031, 032 | MVP 출시 | 연계 사이트(P2). 인증 C단계는 제외라 작업 없음 |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

모델 비율(06장 4절): Fable 6개(12.5%), Opus 23개(47.9%), Sonnet 18개(37.5%), Haiku 1개(2.1%), 사람 1개(SI-06-034). 규모 가중은 Fable 14.9%, Opus 48.3%, Sonnet 35.6%, Haiku 1.1%입니다.

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 권한·RLS(004), 인증 단계(019 Stage A, 049 Stage B), AI 보안 설계(036 서명 토큰 검증, 037 쿠키 결합·한도·마스킹, 048 AI 회귀) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`·`fastapi-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, RAG, 위키 운영, 음성, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 상담 위젯, 3D 히어로, 지식 원고, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리(SI-06-001) | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(SI-06-034), 지식 원고 자료 제공·검수(D-11), 법무 확인 | 사용자 |

리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/SI-06-003-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # SI-06-003 수용 기준
```

### 9.4 요청 프롬프트 예시 (W1 DB 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/website-floria/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
SI-06-003: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 website_floria_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ sites.accepts_ai_chat·accepts_voice 컬럼과 update_ai_settings 확인, ai_routing_settings(app_id='site') 8행
④ supabase gen types 결과를 apps/web/src/types/db.ts 에 저장 ⑤ 06_AGENT_PLAN.md 의 SI-06-003 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/, apps/web/src/types/, scripts/to-monolith.mjs

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

- **MVP 출시 조건**: W6까지 완료(G1 판정 후 인증 Stage B SI-06-049 포함), AI 보안 회귀(SI-06-048) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다. 법무 확인 체크리스트(01장 6절)와 D-1~D-3, D-6, D-7, D-10~D-12, D-14 확정이 포함됩니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).
- 지식 원고(SI-06-039)는 운영자가 제공하는 사례·식물·FAQ 자료와 고객 동의 증빙이 필요합니다. 자료가 없으면 색인 대상은 비워 두고 구조·린트까지만 진행합니다.

## 11. AI 계층 구축 (website-floria)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 2.1·4.1·5절, `04_API.md` 2.2·6절

| 구성 | website-floria 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance) 설치와 JWKS 검증 | SI-06-036 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 8행(`site.consult` auto, 위키 작업 오픈소스 우선, Dify 보조 노드 오픈소스 강제, 지식 임베딩 oss-embed 고정, 음성 STT 오픈소스 우선·TTS ElevenLabs 우선) | SI-06-003, 036 |
| 국외 이전 동의 | 방문자가 아니라 사이트의 운영자 조직이 콘솔 `/admin/ai`에서 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음 | SI-06-023, 038 |
| AI 게이트(방문자) | Next.js `/api/ai/*`: 서명된 방문자 쿠키(`visitor_key`), Turnstile, 대화 매핑 기록, EdDSA 토큰 발급, 마스킹, 레이트 리밋 5종, 사이트 일일 상한. 크레딧 선차감·정산은 없음 | SI-06-037 |
| RAG | 운영자가 제공한 시공 사례·식물 정보·FAQ 원고(`content/knowledge/`)와 색인(사이트 조직 컬렉션). 평가셋 30문항 | SI-06-039, 040 |
| 제품 위키 | 브랜드 지식 위키(draft → 검수 → `published`), 공개 `/guide`. 개인정보 삭제는 `purge_wiki_page` | SI-06-041, 042 |
| LangGraph | `site.consult`: 질문 정규화 → 검색 → 답변 → 문의 전환 제안 → 금지 규칙 검사. 문의 초안만 만들고 제출은 기존 `site.submit_inquiry` 경로 | SI-06-043 |
| Dify 채팅 | 공용 Dify에 `site-chat` Chatflow 등록. 입력 `platform_conversation_id`, HTTP 노드 → `/tools/answer`(내부 키). 설정은 `infra/dify/README.md` | SI-06-044, 045 |
| 음성 | 방문자 음성 상담(STT 오픈소스 우선, 읽어 주기 TTS ElevenLabs 우선, 30초·3MB, 원본 미저장) | SI-06-046 |
| 보안 회귀 | 쿠키 결합, 서명 토큰, 국외 동의 우회, 강제 오픈소스, 한도, 상담이 `site.*`에 쓰지 않음 | SI-06-048 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 상용 키로 국외 동의가 있는 테스트 조직에서 개발합니다.
3. 준비되면 기본값으로 되돌립니다. 출시 때 사이트 스위치(`accepts_ai_chat`, `accepts_voice`)는 꺼진 채로 시작하고 운영자가 켭니다(D-10).

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보는 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 25개)는 setup 시 함께 들어옵니다.
- 이 위키는 개발용입니다. 제품의 브랜드 지식 위키(`/guide`)와 다릅니다(`LLM_WIKI.md` 앞 표).

## 13. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009, 확정 결정 22). 제품 반영: `docs/file/02-요구사항/01_PRD.md` SI-F-020·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절.

이 제품에서 로그인하는 사람은 초대받은 운영자뿐입니다(`inviteUserByEmail` + `provision_site`, SI-F-020). 방문자(문의·뉴스레터·AI 상담·`/guide`)는 단계와 무관하게 로그인하지 않습니다.

### 13.1 단계 요약

| 단계 | 운영자 로그인 | 시작 조건 | 작업 |
|---|---|---|---|
| A Mock | `/admin/login` 개발용 패널. 로컬 Supabase 시드 계정으로 실제 JWT 로그인. 모든 화면 상단 `MOCK AUTH · 로컬 전용` 배지 | 개발 시작(W2의 SI-06-019) | SI-06-019 |
| B Google | "Google로 계속하기" + 초대 메일 수락(비밀번호 설정)·이메일 로그인. 배포 환경에서 Mock 차단 | G1(사람 판정) | SI-06-049(P0, W6 맨 앞) |
| C1 카카오, C2 네이버 | 제외(운영자 전용 콘솔, 초대 메일+Google로 충분) | - | 없음 |

### 13.2 Stage A 로컬 실행 순서

| 순서 | 명령·동작 | 확인 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase 기동(7장) |
| 2 | `supabase db reset` | 마이그레이션·seed 적용. `apps` 행 `site`는 `signup_policy='invite'` |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<로컬 전용 값>`, `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321` | `DEV_SEED_PASSWORD`는 `NEXT_PUBLIC_*`에 넣지 않습니다 |
| 4 | `node scripts/dev/seed-users.mjs --app site` | 공통 페르소나 + 제품 훅(`seed-users.site.mjs`): 엔타이틀먼트 부트스트랩(service_role), `owner`·`outsider`는 `provision_site`, `site_pending`은 사이트 없음. 출력 표에 비밀번호 없음. 원격 URL이면 즉시 종료 |
| 5 | `npm run dev` → `http://localhost:3000/admin/login` 개발용 패널 | `owner` → 문의 목록, `site_pending` → "등록된 사이트가 없습니다", `no_app` → `/admin/no-access`, `viewer` → 문의 접근 거부 |
| 6 | `npx playwright test` | `globalSetup`이 페르소나별 `storageState`를 저장(SI-06-025) |

페르소나 전체 표는 `docs/file/03-설계/05_DATA_MODEL.md` 10절입니다.

### 13.3 G1 체크리스트 (사람이 판정)

- [ ] W0~W5 P0 작업 완료(049·025·048 제외)
- [ ] 핵심 플로우 E2E 녹색(Mock 페르소나): 문의 접수, 구독 확인, 상담 → 문의 전환, 콘솔 문의 처리
- [ ] RLS 스모크(SI-06-004) 전 항목 통과, `outsider` 교차 테넌트 거부
- [ ] 결제 E2E: 해당 없음(결제 없음)
- [ ] 단계 분기 코드가 인증 모듈 밖에 0건(SI-06-024 CI 검사)
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침 `/privacy`·이용약관 URL(이 제품은 이용약관 없음, 01장 6절), 승인된 도메인), 웹 클라이언트 ID, 운영 Supabase 프로젝트
- [ ] task `log.md`에 `[DECISION] G1 통과` 기록

### 13.4 Stage B 외부 설정 순서 (`AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위는 `openid`, `email`, `profile`만 | 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml` `[auth.external.google]`에 `env(GOOGLE_CLIENT_ID)` | 앱 env에는 넣지 않습니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | 운영 env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email` | 배포 체크리스트(`docs-ops/AUTH_DEPLOY_CHECKLIST.md`, SI-06-049)와 대조 |
| 6 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |

B단계 수동 점검(B-5): 데스크톱·모바일 각 1회, 초대받은 이메일의 Google 계정(→ 콘솔)과 초대받지 않은 Google 계정(→ `/admin/no-access`). 결과를 task `log.md`에 남깁니다. 실제 Google 로그인은 자동화하지 않습니다.

### 13.5 G2와 C단계 (이 제품은 제외)

G2 체크리스트(`AUTH_ROADMAP.md` 6장), C1 카카오 설정(7.1.1절), C2 네이버 스파이크(7.2.2절)와 검수는 이 제품에 적용하지 않습니다. `AUTH_ROADMAP.md` 8장 매트릭스에서 website-floria의 C1·C2가 "제외"이기 때문입니다. 공개 베타 뒤에도 운영 env `AUTH_PROVIDERS`에 `kakao`, `naver`를 넣지 않습니다. 다시 넣으려면 플랫폼 결정(01장 D-21)으로 매트릭스를 먼저 바꾸고, 그때 7.1.1·7.2.2절 절차와 새 작업을 06장에 추가합니다.

### 13.6 단계 전환 요청 프롬프트 예시 (G1 통과 후 Stage B, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/website-floria/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
SI-06-049: 인증 Stage B(Google OAuth + 초대 메일 화면)로 전환한다. 근거 = docs/file/03-설계/공용코어/AUTH_ROADMAP.md 3.2·5장,
docs/file/01-관리/06_AGENT_PLAN.md 8절. 진입 조건 = tasks/ 의 log.md 에 [DECISION] G1 통과 기록이 있다(없으면 시작하지 않고 보고).
완료 조건 = ① /admin/login 에 "Google로 계속하기"와 이메일 폼, 개발용 패널은 isMockAuthAllowed() 거짓이면 렌더 0
② /auth/callback 이 finishLogin(코드 교환 → session_context → invite 앱이라 bootstrap 호출 없음 → no-access 분기 → next 화이트리스트)
③ 초대 메일 수락(비밀번호 설정)·재설정 화면, /admin/no-access ④ AUTH_ROADMAP 5.3 B-1~B-6 충족(B-5 수동 점검표는 사람에게 요청)
⑤ Mock E2E(SI-06-025 콘솔 흐름) 계속 녹색 ⑥ 카카오·네이버 버튼과 코드는 만들지 않는다(이 제품 C단계 제외).

[작업의 특성]
권한 경계(Fable). 원격 Supabase 대시보드·Google Cloud 설정은 사람이 한다(13.4). 작업 대상 경로: 06_AGENT_PLAN.md 8절 SI-06-049 소유 경로.
supabase/config.toml 과 docs-ops/ONBOARDING.md 는 변경 요청만 한다.

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert, supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

### 13.7 이 제품의 인증 작업 ID

| 단계 | 작업 | 웨이브 | 우선순위 | 모델 |
|---|---|---|---|---|
| A | SI-06-019(콘솔 인증 Stage A: 인증 모듈 경계, Mock 로그인, 시드 스크립트 + 제품 훅, 가드, `finishLogin`) | W2 | P0 | Fable |
| B | SI-06-049(Google OAuth + 초대 메일 화면, `/auth/callback`, `/admin/no-access`) | W6 맨 앞(G1 후) | P0 | Fable |
| C1, C2 | 없음(제외) | - | - | - |

## 14. 메인 디자인과 디자인 시스템

디자인 작업 순서: 14.3 시각 레퍼런스(Awwwards·Dribbble) → 14.1 디자인 시스템 → 14.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 14.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 공개 사이트는 DESIGN_PRINCIPLES + HERO_3D(B2B 레퍼런스 미적용), 운영 콘솔은 Primer, 상담 위젯 구조는 Astryx 패턴(확인 후, D-17) | SI-06-033, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(온실 그늘, 이끼 석재, 석회, 잿빛 잎, 난초 자주) + Tailwind CSS v4 `@theme` → `src/styles/tokens.css`, 기본 컴포넌트, `/dev/components` | SI-06-005 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다(라이트 토큰 초안 확정 포함) | SI-06-034(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | SI-06-035 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 화면 작업(008~011, 014, 015, 020~022, 038, 041, 042, 045, 047)은 SI-06-035가 끝난 뒤 시작합니다.

### 14.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.8)

히어로는 사용자 결정(2026-10-13)으로 사진 중심에서 3D 온실 구조물로 바뀌었습니다.

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 석회 바닥판 위에 온실 리브가 올라서고 유리 패널이 서고, 줄기가 리브를 타고 자라 난초 3송이가 열린 뒤 정지합니다(약 3초, 로드 때 1회). 이후 시점 이동에만 다시 그립니다 |
| 모바일(767px 이하) | 제목·CTA·정지 이미지 자리를 HTML로 즉시 표시하고, 리브 3개·줄기 1묶음·난초 1송이의 단순판을 첫 화면 뒤 자동 로드 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기·데이터 절약이면 정지 렌더 이미지(`public/hero/greenhouse.avif`, 150KB 이하) |

- 제목, CTA는 HTML로 3D 위에 겹칩니다. 캔버스는 `aria-hidden`입니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하. 3D는 첫 화면 2MB 예산 밖(첫 화면 뒤 로드), 정지 이미지는 안.
- 금지: 보라/핑크 그라디언트, 별 파티클, 금색 재질, 잎 일러스트 패턴. 3D 재질 색은 토큰만 씁니다.
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(SI-06-047, 008).

### 14.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` website-floria 절(`:267`)에 있습니다.

| 출처 | 제목 | URL | 참고 포인트(가져올 것) | 가져오지 않을 것 | 적용 화면 |
|---|---|---|---|---|---|
| Awwwards | Botanic Expo (SOTD) | https://www.awwwards.com/sites/botanic-expo | 식물을 전시 공간처럼 보여 주는 쇼케이스 구성 | 2074년 SF 세계관과 3D 자산 | Hero 연출 |
| Awwwards | plantica (Honorable Mention) | https://www.awwwards.com/sites/plantica-1 | 작업물 중심 포트폴리오 목록 구성 | 일본어 타이포와 스튜디오 사진 | Archive |
| Awwwards | Humbert & Poyet (SOTD) | https://www.awwwards.com/sites/humbert-poyet | 깨끗하고 미니멀한 프로젝트 제시 | 사진, 로고 | Collections |
| Awwwards | Kononenko Architectural Bureau (SOTD) | https://www.awwwards.com/sites/kononenko-architectural-bureau | 굵은 타이포와 정돈된 구조로 프로젝트를 보이는 방식 | 몰입형 인터랙션을 여러 개 겹치는 것 | Hero 타이포 처리 |

- 이 제품은 Dribbble 샷을 고르지 않았습니다. 운영 화면은 14.1의 디자인 시스템 레퍼런스를 따릅니다.
- URL은 이 표와 `REFERENCES.md`에 있는 것만 씁니다. 새 레퍼런스가 필요하면 URL을 직접 열어 확인하고 `REFERENCES.md`에 먼저 추가한 뒤 씁니다.
- 영감용이지 복제용이 아닙니다. 로고·사진·일러스트·아이콘·카피·폰트·색 조합 전체를 가져오지 않고, 레이아웃을 따라 그리지 않습니다. 구조(정보 배치, 위계, 리듬)만 참고하고 토큰은 제품 주제에서 다시 뽑습니다(`03_SCREENS_UX.md` 4.3절).
- Dribbble 링크는 작업 전에 브라우저에서 한 번 엽니다(자동 확인이 막혀 있어 색인으로만 확인됨). 열리지 않으면 `REFERENCES.md`에서 지우고 다른 후보를 씁니다.
- 순서: 레퍼런스(이 절) → 브리프(4.2절) → 토큰 플랜(4.3절) → 14.1 디자인 시스템 → 14.2 메인 히어로. AI에게 화면을 맡길 때 지시에 이 표의 행(제목과 "참고 포인트")을 적습니다.
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

## 15. 원본 이식

정본: `docs/file/04-구현/07_SOURCE_MIGRATION.md`

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장의 "가져올 것" 목록에서 필요한 파일만 옮기고 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\WebSite\Botanic_Architecture\`(베이스), `Floria_Neo`(카피만). 나머지 3개 사이트는 이식하지 않습니다.
- 원본에는 AI 기능이 없어 AI 계층은 모두 새로 만듭니다. 상담 지식 원고도 원본에 없으므로 운영자가 제공해야 합니다(D-11).
- 리뷰 "높음" 8건의 차단 설계는 `02_ARCHITECTURE.md` 6절에 있습니다(영상 236MB, 프레임 150장 로더, 누락 이미지 10개, 인라인 grid, Biz_Website 소스 없음, Play CDN, 미정의 라우트 7개, 중첩 git+LFS). 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(가상 후기 5건, 50마일/80km 주장, 555 전화번호, `blur` 조명 원, 인라인 style, Play CDN)은 옮기지 않습니다.
- 아카이브·저장소 경계 정리는 사용자 승인 후 SI-06-029가 계획서를 만듭니다. git 쓰기는 에이전트가 하지 않습니다.

## 16. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/lib/`(인증 가드, Supabase 클라이언트), `apps/web/src/server/ai/`(AI 게이트), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 방문자 AI 규약 | 쿠키 발급·`visitor_key`·토큰 `sub=visitor:<key>`·크레딧 없는 모드는 `src/server/ai/`에 두고 공용 `packages/ai-gateway` 반영을 요청합니다(코어 요청 6) |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 7) |
| 남은 코어 과제 | 서비스 전용 함수의 PUBLIC EXECUTE 회수(요청 1~2), 메일 모듈 필요 여부(요청 4), core-voice 방문자 옵션(요청 8), ai-service 훅(요청 9), Dify 앱·로그 보존(요청 10), 방문자 대화 퍼지 함수(요청 12). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

## 17. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다: 빌드·타입·린트, SQL 체커와 RLS 스모크, CI 게이트(예산·자산·리포), e2e, AI 평가셋·회귀, 3D·디자인 시스템 4단계, 법무 체크리스트.

## 18. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용(익명 호출) | 스위치 기본 꺼짐, Turnstile, 레이트 리밋 5종, 사이트 일일 상한, 입력·턴·토큰 상한. 크레딧이 없어 운영자 예산이므로 `core.ai_usage`로 원가를 주기적으로 확인합니다 |
| 허위 표시 | AI 응답에도 가상 후기·평점·미검증 수치·가짜 연락처·가격 약속 금지. 그래프 `compliance` 노드와 규칙 파일, 평가셋으로 막습니다 |
| 국외 이전과 개인정보 | 운영자 동의 전 국외 제공자 사용 금지, 방문자 입력 마스킹, 대화 30일 삭제, 녹음 미저장. 방문자 본인 동의가 아닌 구조의 충분성은 법무 확인(D-12) |
| 지식 자료 부재 | 사례·식물·FAQ 원고가 없으면 상담이 대부분 "근거 없음"으로 답합니다. 자료 없이 켜지 않습니다(D-10, D-11) |
| 3D 성능 | 모바일 예산(300KB)을 넘기기 쉽습니다. 넘으면 유리·가지를 먼저 빼고, 그래도 넘으면 정지 이미지로 대체합니다 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 19. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D-1~D-21 확정, 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(14.3)
- [ ] 디자인 시스템 1~4단계 완료(14.1). 사람 비주얼 검토 포함
- [ ] 운영자 제공 지식 자료와 고객 동의 증빙 확보(D-11)
- [ ] Stage A: `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`, `node scripts/dev/seed-users.mjs --app site` 후 `/admin/login` 개발용 패널 확인(13장)
- [ ] W5 완료 후 G1 판정과 `[DECISION] G1 통과` 기록, Google 외부 설정(13.4) 후 SI-06-049
- [ ] W1~W6 진행, AI 보안 회귀 통과, MVP 출시 조건 충족

## 부록 A. 스크립트 없이 손으로 할 때

`website-floria-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\website-floria\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/website-floria"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\website-floria" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\website-floria" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/website-floria"` | `Set-Location "D:\WorkSpace\DEV\website-floria"` | `cd /d "D:\WorkSpace\DEV\website-floria"` |
| 3 초기화 | `bash init-project.sh website-floria --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh website-floria --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh website-floria --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/website-floria/website-floria-root/." "D:/WorkSpace/DEV/website-floria/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\website-floria\website-floria-root\*" "D:\WorkSpace\DEV\website-floria" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\website-floria\website-floria-root" "D:\WorkSpace\DEV\website-floria" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
