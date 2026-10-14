# microweb-studio(Microweb Studio) 개발 방법

작성일 2026-10-13, 2026-10-14 개정(인증 단계 19장, 확정 결정 22). 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 microweb-studio 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

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
| 7 | 작업(56개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계: Mock → Google·초대 메일 → 카카오·네이버(초대받은 운영자만 로그인. 7·9·10절과 함께 봅니다) | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Microweb Studio. 하객에게 보내는 모바일 마이크로웹(1차 청첩장, 2단계 돌잔치·부고장)을 템플릿 엔진으로 만들고, 쇼룸(포트폴리오, 가격표, 시뮬레이터, 견적 문의)으로 대행 제작을 파는 서비스. 대행으로 시작해 셀프서비스(크레딧)로 확장, 초대제 베타 |
| 통합 원본 | premium-wedding-invitation(베이스), nexus-micro-web-builder(데이터만), webcraft-agency-simulator(쇼룸), WebSite(포트폴리오 엔트리). 이식 방법은 14절 |
| 모듈러 앱 id / 스키마 | `microweb` / `microweb` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D-1) |
| 개발 근거 | `docs/file/`의 산출물 25개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| 인증 | 초대제(`signup_policy='invite'`). 초대받은 운영자만 로그인. 단계: A Mock(개발) → B Google + 초대 메일(공개 베타 전) → C 카카오·네이버(G2 후, P2 선택). 하객(`/i/*`)·고객 시안(`/p/*`)·쇼룸 방문자는 로그인 없음, 단계와 무관(19절) |
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
- Google OAuth 클라이언트 ID·시크릿(Stage B, Supabase 대시보드·로컬 `config.toml`에만), 카카오·네이버 로그인 키(Stage C, 선택). 19장
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
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(DOC-CORE-009 `AUTH_ROADMAP.md`는 2026-10-14 인증 단계, 19장) |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/_design-guide/DASHBOARD_PATTERNS.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008 | 앱 화면 구조 패턴(A~O). `03_SCREENS_UX.md` 화면 표의 `패턴` 열과 화면 작업 지시(`DESIGN_SYSTEM.md` 10장)가 이 코드를 쓴다 |
| `docs/products/microweb-studio/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/microweb-studio/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/premium-wedding-invitation.md`, `nexus-micro-web-builder.md`, `webcraft-agency-simulator.md`, `WebSite.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/microweb-studio/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/microweb-studio/supabase/monolith/migrations/0002_microweb_domain.sql` | `supabase/migrations/20261013000002_microweb_domain.sql` | - | DB |
| `docs/products/microweb-studio/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 25개 |
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
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(25개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 9개(AUTH_ROADMAP 포함)            [묶음]
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
- 개발 시작 단계(Stage A)에서는 `db reset` 뒤 `node scripts/dev/seed-users.mjs --app microweb`으로 개발용 페르소나를 만들고 `/login` 개발용 패널로 로그인합니다(19.2절).
- RLS 회귀 테스트는 MW-06-030에서 `supabase/tests/`로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 21개(D-19~D-21은 8.1절 인증 단계)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

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
| D-19 | C단계(카카오·네이버) 도입 여부 | G2 판정 후 |
| D-20 | 카카오 이메일 정책 | C1(MW-06-055) 착수 전 |
| D-21 | 네이버 경로(`supabase_custom`/`bridge`) | C2 스파이크(MW-06-056 첫 단계) 결과로 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 MW-06-001~056, 모두 56개입니다. 그중 MW-06-037은 사람이 하는 디자인 비주얼 검토입니다. MW-06-054~056은 2026-10-14에 추가한 인증 단계 작업이고(19장), 기존 MW-06-003은 Stage A(Mock 로그인) 범위로 바뀌었습니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 036 | 없음 | 앱 골격, DB 적용·타입(AI·음성 20절 포함), 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 003, 004, 022, 033, 034, 039 | W0 | 인증 가드와 Mock 로그인(Stage A), 블록 스키마, 쇼룸 데이터, 노출 시크릿 사고 대응, 원본 아카이브, AI 서비스 설치 |
| W1-D | 020 → 037 → 038(직렬) | 001, 036 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 006, 008, 009, 010, 011, 015, 025, 026, 029, 040, 041, 052 | W1, 025·052는 038 | 렌더러, 테마, 공유, 하객 쓰기, 업로드, 이미지 워커, 사이트 라우트, 문의, 초대, 문구·고지문, AI 게이트, 문구 코퍼스, 3D 히어로 |
| W3 | 007, 012, 013, 014, 016, 017, 018, 019, 021, 023, 024, 030, 042, 044, 048 | W2, 화면은 038 | 하객 페이지, 게시 파이프라인, 편집기, 축하말 그래프, 시안 확인, 관리 화면, 쇼룸 페이지, RLS 테스트, RAG 색인, 문구 제안 그래프, 채팅 시트 |
| W4 | 043, 045, 046, 049, 050, 051 | W3 | 위키 운영, Dify 채팅, 문구 제안 라우트, 음성 대화, 인사말 음성, 하객 음성 방명록 |
| W5 | 047, 053 | W4 | 문구 제안 패널, AI·음성 보안 회귀 |
| W6 | 054(G1 통과 후 먼저), 032, 035 | W5, 054는 G1 | Google + 초대 메일 로그인(Stage B), E2E(Mock 페르소나 storageState)와 체크리스트, 문서. **MVP 출시 조건** |
| W7 | 027, 028, 031, 055·056(G2 통과 후, P2 선택) | MVP 출시 + 셀프 단가 확정, 055·056은 G2 | Phase 2: 크레딧팩 결제, 돌잔치·부고장, 결제 E2E, 카카오·네이버 로그인(선택) |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 권한, RLS, 데이터 모델, 크레딧 경로, AI 보안 설계, 익명 하객 음성, 인증 A·B·C2(003, 054, 056) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 워커, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 코퍼스 원고, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(MW-06-037) | 사용자 |

모델 비율은 Fable 13개(23.6%), Opus 23개(41.8%), Sonnet 16개(29.1%), Haiku 3개(5.5%)입니다(사람 작업 제외 55개 기준, 규모 가중 23.8/41.9/30.5/3.8%). 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

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

- **MVP 출시 조건**: W6까지 완료(Stage B MW-06-054 포함), AI·음성 보안 회귀(MW-06-053) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
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
- 초기 페이지(`sources/*.md` 25개)는 setup 시 함께 들어옵니다.
- 이 개발용 위키는 제품 안의 "문구 위키"(MW-06-043)와 다릅니다. 제품 위키는 DB(`core.wiki_pages`)에 있고 스튜디오 사용자가 읽는 기능입니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

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

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` microweb-studio 절(`:142`)에 있습니다.

| 구분 | 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|---|
| 랜딩 | Awwwards (Nominee) | https://www.awwwards.com/sites/wedding-invitation | 하객에게 환영을 전하는 목적에 맞춘 페이지 흐름 | `wedding_classic` 섹션 순서 |
| 랜딩 | Awwwards (Honorable Mention) | https://www.awwwards.com/sites/amelia-steve-wedding | 색과 타이포만으로 만든 단일 페이지 | 미니멀 테마, 쇼룸의 절제 |
| 랜딩 | Awwwards (Honorable Mention) | https://www.awwwards.com/sites/dora-ai | 생성 결과물을 직접 시연하는 방식 | 쇼룸 히어로(실제 렌더 시연), Phase 2 셀프 랜딩 |
| 앱 | Dribbble | https://dribbble.com/shots/15693896-Wedding-Invitation-Mobile-Website-UI-Design | 일시·장소·지도·계좌·방명록 정보 블록 배치 | 하객 페이지 블록 |
| 앱 | Dribbble | https://dribbble.com/shots/23677358-Wedding-Invitation-Website-Landing-Page | 데스크톱에서 열린 청첩장 구성 | 하객 페이지 데스크톱 뷰, 쇼룸 썸네일 |

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
- 원본 경로: `D:\WorkSpace\platform\premium-wedding-invitation\`, `nexus-micro-web-builder\`, `webcraft-agency-simulator\`(아카이브 대상, MW-06-034), `WebSite\`(링크·스크린샷만).
- 리뷰 "높음" 10건의 차단 설계는 `02_ARCHITECTURE.md` 6절과 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: 범용 Vertex 프록시, 방문마다 이미지 생성, AI 생성 지도, 미검증 수치 히어로, Tailwind CDN)은 옮기지 않습니다. webcraft의 역할 직접 선택 로그인과 다른 원본의 쿠키 역할 Mock도 옮기지 않고, 개발용 로그인은 19절의 로컬 시드 계정 방식만 씁니다(07장 6절).
- webcraft `backend/.env.local`에 노출된 시크릿은 값 자체를 어떤 문서에도 옮기지 않고 폐기·재발급합니다(MW-06-033, 07장 5절).

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다. 인증 단계 모듈은 `apps/web/src/lib/auth/`(기획서 `src/lib/auth/`)에 두고 그 밖에서 `AUTH_MODE`를 읽지 않습니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 R-12) |
| 남은 코어 과제 | `credits: 0` 호출 허용(R-4), 하객 음성의 익명 세션과 호스트 읽기 경로(R-9), 모듈러 seed AI 키(R-8), 위키 편집 엔드포인트(R-10), Dify 앱(R-11), AI 단가 환산(R-13), `adjust_credits`(R-6), 네이버 브리지 경로를 택할 때만 `auth_identity_links` 적용(R-14, 06장 8.3절). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

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
| Mock 로그인 노출 | `AUTH_MODE=mock`이 배포에 들어가면 개발 계정 로그인이 열립니다. `isMockAuthAllowed()` 3조건, 기동 실패, `/api/dev/login` 404, CI 빌드 검사(19.1, MW-06-003·034)로 막고 단계 전환은 사람이 G1·G2를 판정한 뒤에만 합니다 |
| 하객 화면에 로그인 유입 | 단계 전환 때 하객(`/i/*`)·시안(`/p/*`)·쇼룸에 로그인 버튼이나 세션 검사가 섞이면 무로그인 열람이 깨집니다. B·C task의 `write_scope`에서 `src/app/i`, `src/app/p`, `src/app/(showroom)`, `src/app/api/public`, `src/engine`을 빼고, MW-06-032 F2·F3·F8(하객·문의·하객 음성) 재실행으로 확인합니다 |
| 초대 이메일 불일치 | 초대받은 이메일과 다른 Google 계정으로 로그인하면 엔타이틀먼트 없는 새 사용자가 생깁니다. `/no-access` 안내로 막고 권한을 자동으로 합치지 않습니다(19.1) |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, ffmpeg, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만. 하객 음성은 오픈소스 필수)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D-1~D-18 확정(D-19~D-21은 G2 뒤), 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절), 노출 시크릿 사고 대응(MW-06-033) 확인
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] Stage A: `seed-users.mjs --app microweb` 실행, `/login` 개발용 패널로 `owner`·`studio_denied`·`no_app` 동작 확인(19.2)
- [ ] W1~W5 진행, G1 판정과 `[DECISION]` 기록(19.3), Google·Supabase 외부 설정(19.4)
- [ ] W6(MW-06-054 Stage B 먼저) 진행, AI·음성 보안 회귀 통과, MVP 출시 조건 충족
- [ ] (선택) G2 판정 후 카카오·네이버(19.5~19.7)

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009, 확정 결정 22). 제품 반영: `docs/file/02-요구사항/01_PRD.md` MW-F-024·8.1~8.2절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙".

외부 콘솔 설정 절차(화면별), 공식 문서 링크, 공용 모듈 `@nomad/core-auth` 구조와 "공용 모듈 완료 후 모든 제품 적용" 절차는 공용 지시서 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`를 따릅니다(2026-10-15). 통합 DB 제품은 Google·카카오·네이버 앱을 1세트만 같이 쓰므로(지시서 1장 AUTH-D1) 이 장의 외부 설정은 그 세트가 이미 있으면 Redirect URLs에 이 제품 도메인을 더하는 것으로 끝납니다.

microweb-studio는 초대제(`signup_policy='invite'`)라 로그인하는 사람은 초대받은 운영자뿐입니다. 하객(`/i/*`), 고객 시안(`/p/*`), 쇼룸 방문자는 어느 단계에서도 로그인하지 않습니다.

### 19.1 단계 요약

| 단계 | 언제 | 켜지는 로그인 | 이 제품 작업 | 우선순위 |
|---|---|---|---|---|
| A Mock | 개발 시작(W0~W5) | 로컬 Supabase 시드 페르소나 원클릭(`/login` 개발용 패널). 실제 JWT | MW-06-003(W1) | P0 |
| B Google + 초대 메일 | G1 통과 후, 공개 베타 전 | Google 버튼 + 초대 메일 링크(`/auth/invite`, 비밀번호 설정은 건너뛰기 가능) + 이메일·비밀번호 로그인(공개 가입 없음). 초대받은 이메일과 같은 Google 계정이어야 하고, 다르면 `/no-access` 안내 | MW-06-054(W6 맨 앞) | P0 |
| C1 카카오 | G2 통과 후 | Supabase 기본 제공자 `kakao` | MW-06-055(W7) | P2 선택 |
| C2 네이버 | G2 통과 후(C1과 병렬 가능) | `custom:naver` 또는 서버 브리지(스파이크로 결정) | MW-06-056(W7) | P2 선택 |

단계가 바뀌어도 세션(실제 Supabase JWT), 권한 판정(`session_context` → `studio_access`), RLS는 그대로입니다. 단계 분기 코드는 `apps/web/src/lib/auth/`, 로그인 화면, `/auth/callback`, `/auth/invite`, `/api/dev/login`에만 둡니다. 하객·시안·쇼룸 화면에는 어느 단계에서도 로그인 버튼을 넣지 않습니다(Mock 배지는 표시만).

- 제품 페르소나: `studio_access` 허용은 `owner`(기준 운영자), 미허용은 `studio_denied`(엔타이틀먼트만 있어 `/pending`). 초대받지 않은 이메일은 `no_app`(→ `/no-access`)으로 A단계에서 미리 확인합니다.

### 19.2 Stage A 로컬 실행 순서

| 순서 | 명령 / 동작 | 확인 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase 기동(7절) |
| 2 | `supabase db reset` | 마이그레이션·seed 적용 |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<로컬 전용 임의 값>` | `NEXT_PUBLIC_SUPABASE_URL`이 `http://127.0.0.1:54321`인지 확인. 원격 URL이면 Mock 기동이 실패해야 정상 |
| 4 | `node scripts/dev/seed-users.mjs --app microweb` | 공통 페르소나 + 제품 훅(`seed-users.microweb.mjs`)이 `owner`·`outsider`에 엔타이틀먼트와 `studio_access`를, `studio_denied`에 엔타이틀먼트만 부여. 출력 표에 페르소나·조직 id(비밀번호는 출력하지 않음) |
| 5 | 출력된 `owner` 조직 id를 `.env.local`의 `MICROWEB_STUDIO_ORG_ID`에 | 쇼룸 문의(`create_lead`)가 그 조직으로 들어감 |
| 6 | `pnpm dev` → `/login` | 상단 `MOCK AUTH · 로컬 전용` 배지, 개발용 패널. `owner` → `/studio`, `studio_denied` → `/pending`, `no_app` → `/no-access` |
| 7 | E2E: `npx playwright test e2e/flows` | `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장(MW-06-032) |

invite 앱이라 가입 트리거가 엔타이틀먼트를 만들지 않습니다. 시드 훅은 운영자 초대(MW-06-026)와 같은 service_role 경로(`bootstrap_app_for_org` + `studio_access` INSERT)로 권한을 만듭니다(`docs/file/03-설계/05_DATA_MODEL.md` 10절).

### 19.3 G1 체크리스트(사람이 판정)

- [ ] W0~W5 P0 작업 완료(인증 B·C 작업과 W6 통합 작업 제외)
- [ ] F1~F3 E2E가 Mock 페르소나 `storageState`로 녹색(MW-06-032 Mock 스위트)
- [ ] RLS 스모크 87/87(MW-06-030), `outsider` 교차 조직 거부와 `studio_denied` 0행 확인
- [ ] 단계 분기 코드가 인증 모듈 밖에 0건(CI grep, MW-06-034 금지 문자열 검사)
- [ ] `AUTH_MODE=mock VERCEL_ENV=production npm run build` 실패 확인
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL, 승인된 도메인), 웹 클라이언트 ID, 운영 Supabase 프로젝트
- [ ] 결과를 task `log.md`에 `[DECISION] G1 통과`로 기록(결제 E2E는 Phase 2라 G1 조건 아님)

### 19.4 Stage B 외부 설정 순서(사람, `AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: External, 범위는 `openid`, `email`, `profile`만 | 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml` `[auth.external.google]`에 `env(GOOGLE_CLIENT_ID)`, `env(GOOGLE_CLIENT_SECRET)` | 앱 env에는 넣지 않습니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`, `https://<도메인>/auth/invite`(미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | Supabase 공개 가입은 계속 끈 상태로 둡니다(초대제). Email Templates의 초대 메일 링크를 `{{ .SiteURL }}/auth/invite?token_hash={{ .TokenHash }}&type=invite`로 바꾸고, 테스트 초대 1건으로 `/auth/invite` → 비밀번호 설정 → 약관 → `/studio`가 이어지는지 확인(제안, 04장 8절) | 초대·허용 목록 부여는 MW-06-026 관리자 라우트 |
| 6 | Vercel env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email` | `DEV_SEED_PASSWORD`는 배포 env에 넣지 않습니다 |
| 7 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |
| 8 | 수동 점검표: 데스크톱·모바일 각 1회, 초대받은 이메일의 Google 계정(→ `/studio`)과 초대받지 않은 계정(→ `/no-access`). 결과를 task `log.md`에 | B-5. 실제 Google 로그인은 자동화하지 않습니다 |

### 19.5 G2 체크리스트(사람이 판정)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안, 감사 `auth.login`과 오류 로그)
- [ ] 초대받은 사용자 중 `entitled=false`로 남은 사용자 0(invite 앱 기준으로 읽음)
- [ ] 카카오·네이버를 실제로 켤지 결정(01_PRD D-19, P2 선택). 켜지 않으면 C 작업은 보류
- [ ] 켜는 경우: 카카오 디벨로퍼스 앱과 비즈 앱 전환(D-20 권고 (a)), 네이버 애플리케이션 등록과 검수 자료 준비
- [ ] 결과를 `[DECISION] G2 통과`로 기록

### 19.6 C1 카카오 설정(`AUTH_ROADMAP.md` 7.1.1절, 선택)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = Supabase 콜백(`https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://localhost:54321/auth/v1/callback`) |
| 4 | 카카오 로그인 활성, 동의항목 `profile_nickname`, `profile_image`, (비즈 앱) `account_email`. 초대제라 이메일이 있어야 초대 사용자와 같은 계정이 됩니다(D-20) |
| 5 | Supabase → Providers → Kakao 사용, 운영 `AUTH_PROVIDERS`에 `kakao` 추가 |

공유·지도용 카카오 JS 키(`NEXT_PUBLIC_KAKAO_JS_KEY`)와 같은 카카오 앱을 쓸지는 미확인입니다(구현 시 확인).

### 19.7 C2 네이버 스파이크와 검수(`AUTH_ROADMAP.md` 7.2.2절, 선택)

| 단계 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`provider_type: 'oauth2'`, authorize·token·사용자 정보 엔드포인트). 스크립트 `scripts/auth/register-naver-provider.mjs`로 남김 | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 등록된 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 네이버 이메일로 채워지는지, 재로그인이 같은 사용자인지 | 둘 다 참이면 `supabase_custom` |
| 4 | 실패하면 브리지 경로(`/auth/naver/start`·`/auth/naver/callback`, 코어 `staged/0010_core_auth_identity_links.sql` 적용 요청 R-14) | `NAVER_AUTH_PATH`와 `[DECISION]` 기록(D-21) |
| 5 | 검수 신청: 로그인 버튼부터 가입 완료까지 화면 캡처. 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않음 | C2-6 |

### 19.8 단계 전환 요청 프롬프트 예시 (Stage B, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/microweb-studio/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
MW-06-054: Stage B(Google OAuth + 초대 메일)로 전환한다. 진입 조건 = tasks 의 log.md 에 [DECISION] G1 통과 기록 확인.
완료 조건 = ① /login 에 "Google로 계속하기" 버튼, 이메일·비밀번호 로그인(공개 가입 폼 없음)과 비밀번호 재설정, 초대 메일 안내. 개발용 패널은 Mock 판정 거짓이면 렌더 안 함.
/auth/invite 는 verifyOtp(type invite) → 비밀번호 설정(건너뛰기 가능) → finishLogin, 만료·재사용은 /login?error=invite_expired
② /auth/callback 이 finishLogin 전체(코드 교환 → session_context('microweb') → invite 앱이라 bootstrap_app_for_org 호출 없음
→ entitled=false 면 /no-access "초대받은 이메일로 로그인하세요" → studio_access 없으면 /pending → next 화이트리스트, 기본 /studio)
③ 첫 로그인 뒤 스튜디오 온보딩 첫 단계에서 약관 동의 ④ docs/file/03-설계/공용코어/AUTH_ROADMAP.md 5.3절 B-1~B-6 충족
(B-5 수동 점검표는 사람 확인 항목으로 log.md 에 남김) ⑤ e2e/flows Mock 스위트 재실행 녹색, 하객(F2)·문의(F3)·하객 음성(F8) 흐름이 전환 전후 같은 결과.

[작업의 특성]
인증 모듈과 로그인·콜백·초대 수락·온보딩 약관 단계만. 기능 코드에 AUTH_MODE 분기 추가 금지.
하객(app/i, api/public)·시안(app/p)·쇼룸(app/(showroom))·engine 은 수정하지 않는다(로그인 없는 흐름, 단계와 무관).
작업 대상 경로: apps/web/src/app/auth/callback/, apps/web/src/app/auth/invite/, apps/web/src/app/login/providers/, apps/web/src/app/login/reset-password/, apps/web/src/app/studio/onboarding/terms/, supabase/config.toml 의 [auth.external.google] 절, docs/deploy/auth-checklist.md
apps/web/src/lib/auth/·scripts/dev/(003 소유), /studio/onboarding 단계 연결(040 소유)은 1줄 요청으로 처리한다.
Google Cloud 콘솔·Supabase 대시보드 설정은 사람이 한다(19.4절). 원격 db push 금지.

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert, supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

Stage A 작업(MW-06-003)은 W1의 다른 작업과 같은 형식으로 요청하고, 완료 조건에 `06_AGENT_PLAN.md` MW-06-003 수용 기준(`owner` → `entitled=true`, `outsider` 타 조직 0행, `studio_denied` → `/pending`, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, live 빌드 `/api/dev/login` 404)을 그대로 적습니다.

### 19.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 웨이브 | 게이트 |
|---|---|---|---|
| A | MW-06-003(범위 변경) | W1 | 없음 |
| B | MW-06-054 | W6 맨 앞 | G1 |
| C1 | MW-06-055(P2 선택) | W7 | G2 |
| C2 | MW-06-056(P2 선택) | W7 | G2 |

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
