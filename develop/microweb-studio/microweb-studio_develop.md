# microweb-studio(Microweb Studio) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 microweb-studio 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\microweb-studio\setup-microweb-studio.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/microweb-studio/setup-microweb-studio.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\microweb-studio\        platform에 남는 안내서, 도구, 재료
├── microweb-studio_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-microweb-studio.sh          설치 스크립트(Git Bash / Linux)
├── setup-microweb-studio.ps1         설치 스크립트(Windows PowerShell)
└── microweb-studio-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(microweb-studio-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\microweb-studio\                     베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← microweb-studio-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(53개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Microweb Studio. 하객에게 보내는 모바일 마이크로웹(1차 청첩장, 2단계 돌잔치·부고장)을 템플릿 엔진으로 만들고, 쇼룸(포트폴리오, 가격표, 시뮬레이터, 견적 문의)으로 대행 제작을 파는 서비스. 대행으로 시작해 셀프서비스(크레딧)로 확장, 초대제 베타 |
| 통합 원본 | premium-wedding-invitation(베이스), nexus-micro-web-builder(데이터만), webcraft-agency-simulator(쇼룸), WebSite(포트폴리오 엔트리). 이식 방법은 14절 |
| 모듈러 앱 id / 스키마 | `microweb` / `microweb` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D-1) |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 청첩 문구·구성 제안 그래프(`microweb.invitation_copy`), 문구 코퍼스 RAG와 이벤트 종류별 문구 위키, 제작 상담 AI 채팅(Dify), 음성 대화, 청첩장 인사말 음성, 하객 음성 방명록(STT 자막) |
| 3D | 쇼룸 히어로: 봉투가 열리고 청첩장 카드가 펼쳐져 미니 사이트가 됨(모바일은 봉투 열림만) |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), 워커 | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| ffmpeg(제안) | 워커의 호스트 녹음 mp3 변환(`voice.transcode`, 기획서 D-14) | `ffmpeg -version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM, FastAPI 전용)
- ElevenLabs(음성, Next.js 서버 전용)
- 카카오 JS 키(공유·지도, 도메인 제한), 메일 발송(문의 알림)
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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\microweb-studio`로 복사 |
| 2 | **복사본 안의** `init-project.sh microweb-studio --reset-git` 실행 |
| 3 | `microweb-studio-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `microweb-studio-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/microweb-studio/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/microweb-studio/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/microweb-studio/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/microweb-studio/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/microweb-studio/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/microweb-studio/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/microweb-studio/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 8개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~008 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/microweb-studio/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/microweb-studio/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/premium-wedding-invitation.md`, `nexus-micro-web-builder.md`, `webcraft-agency-simulator.md`, `WebSite.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/microweb-studio/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/microweb-studio/supabase/monolith/migrations/0002_microweb_domain.sql` | `supabase/migrations/20261013000002_microweb_domain.sql` | - | DB |
| `docs/products/microweb-studio/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다(2026-10-13 실행 결과: 경로 참조 340개, 묶음 안 누락 0, 절대경로 누락 0).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\microweb-studio\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 microweb-studio-root에서 온 것입니다.

```
D:\WorkSpace\DEV\microweb-studio\
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
│   ├── web\                          [베이스] Next.js(코드 없음, W0~W1에서 스캐폴딩. 실제 앱 경로는 기획서의 apps/microweb-studio를 apps/web으로 읽는다)
│   └── api\                          [베이스] FastAPI(코드 없음, MW-06-039에서 설치)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\premium-wedding-invitation.md, nexus-micro-web-builder.md, webcraft-agency-simulator.md, WebSite.md   [묶음]
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
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 microweb-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_microweb_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16 App Router, React 19, TypeScript strict, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전, 스튜디오 화면), zod, 모션 framer-motion | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인). 쇼룸 히어로만 | 같은 곳 |
| API | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 워커 | Node 22 + TS(`microweb.media` 큐: 이미지 처리, 게시, 음성 변환, 만료·정리), sharp, ffmpeg | 같은 곳 |
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

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. pgvector 확장은 Supabase에서 기본 제공되며 `extensions` 스키마에 생성됩니다.
- 도메인 파일 `microweb_domain.sql`의 끝(20절)에 방명록 음성 연결 컬럼(`voice_job_id`, `has_voice`), `attach_guestbook_voice` 함수, `site_assets.kind` `voice`가 있고, AI 라우팅 기본값 12행과 free 플랜 AI 키는 `seed.sql` 끝에 있습니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`, mod/mono 모두 OK). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(MW-06-002)의 수용 기준입니다.
- 초대제 베타라 Supabase Auth의 공개 가입을 끄고 운영자가 초대 메일을 보냅니다(MW-06-026). 허용 목록(`studio_access`)이 2차 게이트입니다.
- RLS 회귀 테스트는 MW-06-030에서 `supabase/tests/`로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 18개를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 모놀리스 스키마(public) | 착수 전(이 문서는 단독 `public` 기준) |
| D-2 | 대행 결제 수단 | 주문 장부 작업(MW-06-019) 전 |
| D-3 | 셀프 크레딧 단가 | Phase 2(W7) 전, 베타 인터뷰 후 |
| D-4 | RSVP MVP 포함 | 하객 쓰기(MW-06-009) 전 |
| D-5 | 만료 기본값 | 사이트 라우트(MW-06-015)·게시(MW-06-013) 전 |
| D-6 | 지도 표시 | 블록 렌더러(MW-06-005) 전 |
| D-7 | WebSite 포트폴리오 게시 | 카탈로그(MW-06-024) 전 |
| D-8 | studio org 지정 | 인증(MW-06-003) 전 |
| D-9 | 대행 모드 AI 비용 부담 | AI 게이트(MW-06-040) 전 |
| D-10 | AI 크레딧 단위 가치 | AI 게이트(MW-06-040) 전 |
| D-11 | 하객 음성 공개 재생 | 하객 음성(MW-06-051) 전 |
| D-12 | 하객 음성 고지문·미성년·보관 기간 | 법적 고지(MW-06-029) 전, 법무 확인 |
| D-13 | 인사말 보이스와 ElevenLabs 조건 | 인사말 음성(MW-06-050) 전 |
| D-14 | 호스트 녹음 mp3 변환 | 이미지 워커(MW-06-011)·인사말 음성(MW-06-050) 전 |
| D-15 | 문구 코퍼스 출처 | 코퍼스 원고(MW-06-041) 전 |
| D-16 | 채팅 화면 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(MW-06-036) 전 |
| D-17 | 쇼룸 비로그인 AI 상담 시기 | Phase 2 |
| D-18 | AI 생성물 표시 의무 범위 | 법적 고지(MW-06-029)·문구 제안 패널(MW-06-047) 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 MW-06-001~053, 모두 53개입니다. 그중 MW-06-037은 사람이 하는 디자인 비주얼 검토입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 036 | 없음 | 앱 골격, DB 적용·타입(AI·음성 20절 포함), 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 003, 004, 022, 033, 034, 039 | W0 | 인증 가드, 블록 스키마, 쇼룸 데이터, 노출 시크릿 사고 대응, 원본 아카이브, AI 서비스 설치 |
| W1-D | 020 → 037 → 038(직렬) | 001, 036 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 006, 008, 009, 010, 011, 015, 025, 026, 029, 040, 041, 052 | W1, 025·052는 038 | 렌더러, 테마, 공유, 하객 쓰기, 업로드, 이미지 워커, 사이트 라우트, 문의, 초대, 문구·고지문, AI 게이트, 문구 코퍼스, 3D 히어로 |
| W3 | 007, 012, 013, 014, 016, 017, 018, 019, 021, 023, 024, 030, 042, 044, 048 | W2, 화면은 038 | 하객 페이지, 게시 파이프라인, 편집기, 축하말 그래프, 시안 확인, 관리 화면, 쇼룸 페이지, RLS 테스트, RAG 색인, 문구 제안 그래프, 채팅 시트 |
| W4 | 043, 045, 046, 049, 050, 051 | W3 | 위키 운영, Dify 채팅, 문구 제안 라우트, 음성 대화, 인사말 음성, 하객 음성 방명록 |
| W5 | 047, 053 | W4 | 문구 제안 패널, AI·음성 보안 회귀 |
| W6 | 032, 035 | W5 | E2E와 체크리스트, 문서. **MVP 출시 조건** |
| W7 | 027, 028, 031 | MVP 출시 + 셀프 단가 확정 | Phase 2: 크레딧팩 결제, 돌잔치·부고장, 결제 E2E |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 권한, RLS, 데이터 모델, 크레딧 경로, AI 보안 설계, 익명 하객 음성 | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 워커, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 코퍼스 원고, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(MW-06-037) | 사용자 |

모델 비율은 Fable 11개(21.2%), Opus 22개(42.3%), Sonnet 16개(30.8%), Haiku 3개(5.8%)입니다(사람 작업 제외 52개 기준). 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/MW-06-002-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # MW-06-002 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 DB 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/microweb-studio/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
MW-06-002: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 microweb_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ ai_routing_settings(app_id='microweb') 12행, guestbook_entries.has_voice 컬럼, attach_guestbook_voice 함수 확인
④ supabase gen types 결과를 apps/web/src/types/database.ts 에 저장 ⑤ 06_AGENT_PLAN.md 의 MW-06-002 수용 기준 충족.

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

- **MVP 출시 조건**: W6까지 완료, AI·음성 보안 회귀(MW-06-053) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).
- 노출 시크릿 사고 대응(MW-06-033)은 코드가 아닌 운영 작업입니다. 키 폐기·재발급 결과는 값을 적지 않고 런북에만 기록합니다.

## 11. AI 계층 구축 (microweb-studio)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절

| 구성 | microweb-studio 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance) | MW-06-039 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 12행(`microweb_copy` auto, `microweb_greeting` 오픈소스 먼저, 위키 작업 오픈소스 우선, Dify 보조 노드와 하객 음성 STT 오픈소스 강제, 코퍼스 임베딩 oss-embed 고정) | MW-06-039, 040 |
| 국외 이전 동의 | 스튜디오 온보딩에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음. 하객 음성은 동의와 무관하게 항상 오픈소스 | MW-06-029, 040 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산(대행 모드는 0 크레딧 분기, D-9), EdDSA 토큰 발급 | MW-06-040 |
| RAG | 운영자가 쓴 문구 코퍼스(이벤트 종류별 인사말·안내·계좌·방명록 문구)와 템플릿 설명의 색인. 고객 실제 문구와 개인정보는 색인하지 않음(D-15) | MW-06-041, 042 |
| 제품 위키 | 이벤트 종류별 문구 위키(`wedding/*`, `dol/*`, `obituary/*`, `concepts/*`), draft 검수 후 published | MW-06-043 |
| LangGraph | `microweb.invitation_copy`(입력 정리 → 예시 검색 → 초안 3안 → 구성 제안 → 금지 문구 검사), `microweb.guest_greeting`(하객 축하말). 결과는 운영자가 "적용"해야 반영 | MW-06-044, 016, 046, 047 |
| Dify 채팅 | 공용 Dify에 `microweb-chat` Chatflow 등록(제작 상담). 입력 `platform_conversation_id`, HTTP 노드 → `/tools/answer`(내부 키). 설정은 `infra/dify/README.md` | MW-06-045, 048 |
| 음성 | 스튜디오 음성 대화(STT 오픈소스 우선, TTS ElevenLabs 우선), 청첩장 인사말 음성(TTS 또는 호스트 녹음 → mp3), 하객 음성 방명록(녹음 전 고지, 오픈소스 STT 자막, 서명된 방문자 쿠키와 엄격 레이트 리밋) | MW-06-049, 050, 051 |
| 보안 회귀 | 조직 격리, 대화 매핑 위조, 강제 오픈소스·국외 동의 우회, 하객 음성 남용, 크레딧 우회 | MW-06-053 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 라우팅을 상용만 쓰도록 둡니다. 이때는 국외 동의가 있는 테스트 조직으로 개발합니다. 단 하객 음성 STT는 상용으로 바꾸지 않으므로 오픈소스 음성 서버(또는 테스트 스텁)가 필요합니다.
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
- 이 개발용 위키는 제품 안의 "문구 위키"(MW-06-043)와 다릅니다. 제품 위키는 DB(`core.wiki_pages`)에 있고 스튜디오 사용자가 읽는 기능입니다.

## 13. 메인 디자인과 디자인 시스템

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 스튜디오(제작 주문 관리)는 Atlassian 주·Primer 보조, 채팅은 Astryx 패턴(확인 후, D-16), 공개 청첩장·쇼룸은 DESIGN_PRINCIPLES + HERO_3D(B2B 레퍼런스 사용 안 함) | MW-06-036, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(백자, 먹, 한지 괘, 청자, 인주) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`, 기본 컴포넌트, `/dev/components` | MW-06-020 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | MW-06-037(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | MW-06-038 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 청첩장 템플릿 테마(`src/engine/themes/<theme>.css`)는 스튜디오 토큰과 별개이고, 하객 페이지는 스튜디오 토큰을 쓰지 않습니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.6)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 봉투 덮개가 열리고 카드가 올라와 한지 괘를 따라 펼쳐진 뒤, 그 자리에 실제 엔진으로 렌더한 375px 샘플 청첩장(HTML)이 겹칩니다. [다시 보기], [움직임 멈춤] 제공 |
| 모바일(767px 이하) | 제목·CTA·샘플 프레임을 HTML로 즉시 표시하고, 봉투 열림만 가벼운 3D로 자동 로드. 카드 펼침은 2D |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 제목과 CTA는 HTML로 3D 위에 겹칩니다. 3D 안에는 글자를 넣지 않습니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하. 하객 페이지(`/i/*`)와 스튜디오 번들에는 three.js를 넣지 않습니다.
- 금지: 떨어지는 꽃잎·하트 파티클, 보라/핑크 조명, 글로우, 3D 필기체. 인주는 CTA 1개와 도장 1개에만 씁니다.
- 이 히어로는 사용자 결정(2026-10-13)으로 기존 "휴대폰 iframe" 안을 대체했고 변경 기록은 `03_SCREENS_UX.md` 4.4절에 있습니다.
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(MW-06-052, 021)

## 14. 원본 이식

정본: `docs/file/04-구현/07_SOURCE_MIGRATION.md`

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장의 "가져올 것" 목록에서 필요한 파일만 옮기고 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\premium-wedding-invitation\`, `nexus-micro-web-builder\`, `webcraft-agency-simulator\`(아카이브 대상, MW-06-034), `WebSite\`(링크·스크린샷만).
- 리뷰 "높음" 10건의 차단 설계는 `02_ARCHITECTURE.md` 6절과 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: 범용 Vertex 프록시, 방문마다 이미지 생성, AI 생성 지도, 미검증 수치 히어로, Tailwind CDN)은 옮기지 않습니다.
- webcraft `backend/.env.local`에 노출된 시크릿은 값 자체를 어떤 문서에도 옮기지 않고 폐기·재발급합니다(MW-06-033, 07장 5절).

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 R-12) |
| 남은 코어 과제 | `credits: 0` 호출 허용(R-4), 하객 음성의 익명 세션과 호스트 읽기 경로(R-9), 모듈러 seed AI 키(R-8), 위키 편집 엔드포인트(R-10), Dify 앱(R-11), AI 단가 환산(R-13), `adjust_credits`(R-6). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다. 하객 페이지 JS 150KB 이하, 추적 node_modules 0, gitleaks 0도 포함입니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 셀프서비스는 크레딧 선차감과 정산, 대행은 공정 사용 상한, 하객 기능은 사이트당 상한과 IP 레이트 리밋으로 관리합니다. 운영 중 `core.ai_usage`로 원가를 확인해 단가(제안값, D-10)를 확정합니다 |
| 하객 음성(제3자 녹음) | 고지 없는 보관을 DB가 거부합니다. 고지문·미성년 처리는 법무 확인(D-12) 전에는 하객 음성 옵션을 기본 꺼짐으로 둡니다 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, 실명·전화·계좌 미전송, 하객 음성은 항상 오픈소스, 녹음 기본 미저장(스튜디오 질문) |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, ffmpeg, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만. 하객 음성은 오픈소스 필수)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D-1~D-18 확정, 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절), 노출 시크릿 사고 대응(MW-06-033) 확인
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] W1~W6 진행, AI·음성 보안 회귀 통과, MVP 출시 조건 충족

## 부록 A. 스크립트 없이 손으로 할 때

`microweb-studio-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\microweb-studio\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/microweb-studio"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\microweb-studio" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\microweb-studio" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/microweb-studio"` | `Set-Location "D:\WorkSpace\DEV\microweb-studio"` | `cd /d "D:\WorkSpace\DEV\microweb-studio"` |
| 3 초기화 | `bash init-project.sh microweb-studio --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh microweb-studio --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh microweb-studio --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/microweb-studio/microweb-studio-root/." "D:/WorkSpace/DEV/microweb-studio/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\microweb-studio\microweb-studio-root\*" "D:\WorkSpace\DEV\microweb-studio" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\microweb-studio\microweb-studio-root" "D:\WorkSpace\DEV\microweb-studio" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
