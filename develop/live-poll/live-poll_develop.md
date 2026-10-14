# live-poll(Live Poll) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 live-poll 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\live-poll\setup-live-poll.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/live-poll/setup-live-poll.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\live-poll\        platform에 남는 안내서, 도구, 재료
├── live-poll_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-live-poll.sh          설치 스크립트(Git Bash / Linux)
├── setup-live-poll.ps1         설치 스크립트(Windows PowerShell)
└── live-poll-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(live-poll-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\live-poll\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← live-poll-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(48개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Live Poll. 청중이 로그인 없이 코드로 들어와 투표·질문하고 결과가 발표 화면과 OBS 오버레이에 실시간 반영되는 서비스. 베타는 무료, 유료 플랜은 Phase 2 |
| 통합 원본 | 없음(기획 문서 2개뿐인 `D:\WorkSpace\platform\구현해야 할 프로젝트\Slido_Project\`, 코드 없음). 단독 제품 |
| 모듈러 앱 id / 스키마 | `poll` / `poll` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D6) |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 진행자 AI 어시스턴트(Dify), 행사 자료 RAG, 행사 위키, Q&A AI 정리 그래프 `poll.qna_assist`, 음성(진행자 음성 대화, 청중 음성 질문, 요약 읽어 주기). 청중 원문은 항상 오픈소스 모델 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), 브로드캐스터 워커 | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |
| k6 | 부하 테스트(LP-06-027) | `k6 version` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM, FastAPI 전용)
- ElevenLabs(음성, Next.js 서버 전용)
- Supabase(URL, anon, service_role, JWT secret)
- `POLL_IP_HMAC_SECRET`, `DIFY_*`, `AI_TOKEN_PRIVATE_KEY`(Ed25519)
- Toss Payments(Phase 2부터)

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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\live-poll`로 복사 |
| 2 | **복사본 안의** `init-project.sh live-poll --reset-git` 실행 |
| 3 | `live-poll-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `live-poll-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/live-poll/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/live-poll/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/live-poll/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/live-poll/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/live-poll/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/live-poll/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/live-poll/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 8개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~008 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/live-poll/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/live-poll/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/Slido_Project.md` | `docs/reference/reviews/Slido_Project.md` | 참고 | 원본 리뷰 |
| `docs/products/live-poll/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/live-poll/supabase/monolith/migrations/0002_poll_domain.sql` | `supabase/migrations/20261013000002_poll_domain.sql` | - | DB |
| `docs/products/live-poll/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 어시스턴트 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다. 이번 점검 결과: 경로 참조 338개, 묶음 안 누락 0, 절대경로 누락 0.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\live-poll\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 live-poll-root에서 온 것입니다.

```
D:\WorkSpace\DEV\live-poll\
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
│   └── adapters\  gate.sh  scope_check.sh  call_worker.sh  _run.py   [베이스]
├── _templates\                       [베이스] task.md, task-folder.md, worker-brief.md, worker-result.md, log.md, context.md, dev-request-prompt.md
├── apps\
│   ├── web\                          [베이스] Next.js(코드 없음, W0에서 스캐폴딩). 기획서의 apps/live-poll/ 경로는 여기에 대응(제안)
│   └── api\                          [베이스] FastAPI(코드 없음, LP-06-036에서 설치)
├── services\poll-broadcaster\        [신규] 브로드캐스터 워커(LP-06-010에서 생성, 베이스에는 없음)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\Slido_Project.md  [묶음]
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
├── infra\dify\README.md              [묶음] 어시스턴트 앱 설정 설명서(DSL은 poll-assistant.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_poll_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.9, React 19, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전), Recharts 3(콘솔만) | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인). 랜딩 히어로에서만 | 같은 곳 |
| 실시간 | Supabase Realtime Broadcast(private 채널), 브로드캐스터 워커 Node 22(`services/poll-broadcaster`) | 같은 곳 5-1절 |
| API(AI) | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test / test:e2e / test:rls / test:ai`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/database.ts` | 타입 생성(경로 제안) |

- `core_lite`에는 SECTION 4(크레딧), 7(잡), 8(Storage)이 복원돼 있고 SECTION 11(AI, pgvector)과 12(음성)가 들어 있습니다. 처음 만든 live-poll 코어 라이트는 크레딧을 지웠으나 AI 선차감 때문에 복원했습니다(`05_DATA_MODEL.md` 8장).
- 도메인 `poll_domain`은 `poll` 스키마 이름이 `public`으로 바뀐 변환본입니다. Realtime `realtime.messages` 정책(17절)은 실제 Supabase에서만 적용됩니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(LP-06-002)의 수용 기준입니다.
- RLS 회귀 테스트는 LP-06-026에서 `supabase/tests/`로 옮깁니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 18개를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D1 | 제품명(Slido 상표 사용 금지) | 랜딩(LP-06-022) 착수 전 |
| D2 | 청중 신원: 참가자 토큰 vs Supabase 익명 로그인 | 착수 전(권고: 참가자 토큰) |
| D3 | Q&A 범위 | 착수 전(권고: 베타 포함) |
| D4 | 유료 가격 | Phase 2, 베타 8주 뒤 |
| D5 | 대규모 행사 지연 목표 | 부하 테스트(LP-06-027) 뒤 |
| D6 | 모놀리스 스키마 | 착수 전(이 문서는 단독 `public` 기준) |
| D7 | 청중 쿠키 유효기간 | 청중 API(LP-06-005) 전 |
| D8 | 베타 AI 크레딧 보충 | AI 게이트(LP-06-037) 전 |
| D9 | 청중 원문 처리 제공자(오픈소스 강제 여부) | AI 서비스 설치(LP-06-036) 전 |
| D10 | 청중용 AI 채팅 | Phase 2 재검토 |
| D11 | 크레딧팩 가격과 시점 | Phase 2 |
| D12 | 청중 음성 질문 남용 대응(Turnstile 여부) | 청중 음성 질문(LP-06-045) 전 |
| D13 | 행사 위키 공개 범위 | 위키(LP-06-039) 전 |
| D14 | Q&A AI 정리 자동 실행 | 그래프(LP-06-040) 전 |
| D15 | Q&A 아카이브 저장 시점 | 자료·아카이브(LP-06-038) 전 |
| D16 | 오픈소스 STT·TTS 모델, ElevenLabs 데이터 보관 | 진행자 음성(LP-06-044) 전 |
| D17 | 디자인 레퍼런스(Atlassian·Primer 사용 범위, Astryx 존재·라이선스 확인) | 디자인 시스템 1단계(LP-06-033) 전 |
| D18 | 랜딩 3D 장면 데이터(시연 값) | 3D 히어로(LP-06-047) 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 LP-06-001~048, 모두 48개입니다. 그중 LP-06-034는 사람이 하는 디자인 비주얼 검토입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 033 | 없음 | 앱 골격, DB 적용·타입, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 003, 004, 010, 011, 023, 026, 036 | W0 | 진행자 인증, 도메인 라이브러리, 브로드캐스터, Realtime 권한, 토큰·기본 컴포넌트(2단계), RLS 회귀, AI 서비스 설치 |
| W1-D | 034 → 035(직렬) | 023 | 디자인 시스템 3~4단계(사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 013, 015, 018, 021, 024, 037, 047 | W1, W1-D | 청중 API, 실시간 훅, 공용 컴포넌트, 오버레이 API, 설정, 문구, AI 게이트, 3D 히어로 |
| W3 | 006, 007, 012, 014, 016, 017, 022, 038, 040 | W2 | API 테스트, 편집 화면, 남용 테스트, 훅 테스트, 발표/오버레이, 랜딩, 자료 RAG, Q&A 정리 그래프 |
| W4 | 008, 009, 027, 031, 039, 041 | W3 | 콘솔, 청중 화면, 부하 테스트, 배포, 행사 위키, Dify 어시스턴트 |
| W5 | 019, 020, 025, 030, 032, 042, 044, 045 | W4 | Q&A 패널, 결과/CSV, E2E, 접근성, 가이드, 어시스턴트 패널, 진행자 음성 대화, 청중 음성 질문 |
| W6 | 043, 046, 048 | W5 | Q&A AI 정리 패널, 요약 읽어 주기, AI 보안 회귀. **MVP 출시 조건**(베타 공개) |
| W7 | 029, 028 | 베타 8주 뒤 가격 결정(D4, D11) | Phase 2 유료 플랜(순차) |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 결제, 권한, RLS, 데이터 모델, 부하 진단, AI 보안 설계(036, 037, 048) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(LP-06-034) | 사용자 |

모델 비율(06장 4절): Fable 8, Opus 21, Sonnet 14, Haiku 4(모델 작업 47개, 사람 1개 제외). 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/LP-06-002-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # LP-06-002 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 DB 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/live-poll/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
LP-06-002: supabase/migrations 의 core_lite(SECTION 4·7·8·11·12 포함)와 poll_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ ai_routing_settings(org null, app poll) 12행 ④ supabase gen types 결과를 apps/web/src/types/database.ts 에 저장
⑤ 06_AGENT_PLAN.md 의 LP-06-002 수용 기준 충족.

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

- **MVP 출시 조건**: W6까지 완료, AI 보안 회귀(LP-06-048) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
- **투표 경로 격리**: AI·음성 작업은 청중 투표 API와 브로드캐스터를 수정하지 않습니다(`06_AGENT_PLAN.md` 1절). 이를 `write_scope`에 반영하세요.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (live-poll)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절

| 구성 | live-poll 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance). 투표·실시간 경로에는 들어오지 않음 | LP-06-036 |
| 모델 라우팅 | 기능별 기본값은 seed의 `ai_routing_settings` 12행. 진행자 `chat`은 auto(Claude → ChatGPT → Gemini → 오픈소스), 위키는 오픈소스 우선, **청중 원문 단계(`poll.moderate`, `poll.summary`, `poll.knowledge`, `voice_question`)와 `dify.aux`는 오픈소스 강제** | LP-06-036, 037 |
| 국외 이전 동의 | 온보딩에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음 | LP-06-037 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산, EdDSA 토큰 발급, 정산 크론 | LP-06-037 |
| 행사 자료 RAG | 행사별 컬렉션 `event-<id>`, 조직 Q&A 아카이브 `qna-archive`(`contains_pii`), 평가셋 30문항 | LP-06-038 |
| 행사 위키 | 자료·아카이브 → 위키 draft, 진행자 검수·게시, Q&A 파생은 `derived_from_pii` | LP-06-039 |
| LangGraph | `poll.qna_assist`: load → moderate → cluster → summarize → compliance → output. AI는 제안만, 적용은 진행자(`moderate_question`) | LP-06-040, 043 |
| Dify 어시스턴트 | 공용 Dify에 `poll-assistant` Chatflow 등록. 입력 `platform_conversation_id`, HTTP 노드 → `/tools/answer`(내부 키). 설정은 `infra/dify/README.md` | LP-06-041, 042 |
| 음성 | 진행자 음성 대화(STT 오픈소스 우선, TTS ElevenLabs 우선), 청중 음성 질문(오픈소스 전용, 5중 한도, 4건 묶음 선차감), Q&A 요약 읽어 주기 | LP-06-044, 045, 046 |
| 보안 회귀 | 조직 격리, 대화 매핑 위조, 청중 원문 오픈소스 강제, 국외 동의 우회, 크레딧 우회, 음성 남용, AI 정지 시 투표 정상 | LP-06-048 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 진행자 `chat`만 상용(국외 동의 테스트 조직)으로 개발하고, 청중 원문 단계(Q&A 정리, 청중 음성)는 목 제공자로 개발합니다. 청중 원문을 상용으로 시험하지 않습니다.
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
- 제품의 "행사 위키"(DB의 `core.wiki_pages`, LP-06-039)와는 다른 것입니다. 이 절은 개발용 위키입니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 진행자 콘솔은 Atlassian(주)·Primer(보조), AI 패널은 Astryx 패턴(확인 후, D17), 랜딩은 HERO_3D | LP-06-033, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(객석 남색, 스크린 백색, 막대 청록, 응답 주황, 좌석 회색) + Tailwind CSS v4 `@theme` → `tokens.css`, 기본 컴포넌트, `/dev/components` | LP-06-023 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | LP-06-034(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | LP-06-035 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 화면 작업은 4단계(LP-06-035) 뒤에 시작합니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.5)

2026-10-13 사용자 결정(확정 결정 15)으로 CSS 막대 데모에서 3D 무대 장면으로 바뀌었습니다.

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 무대 위에서 투표 시연이 들어올 때마다 막대와 구가 솟고 순위가 교대합니다 |
| 모바일(767px 이하) | 가벼운 3D 자동 로드: 막대 3개 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 제목, 6자리 코드, 막대 라벨·숫자는 HTML로 3D 위에 겹칩니다. 값은 시연용이며 "시연 화면입니다"를 표시합니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 금지: 이모지 반응 남발, 네온색, 보라/핑크 그라디언트, 큰 숫자 + 작은 라벨 히어로
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(LP-06-047, 022)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` live-poll 절(`:183`)에 있습니다.

| 구분 | 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|---|
| 랜딩 | Awwwards (SWSH, Nominee) | https://www.awwwards.com/sites/swsh | 라이브 행사 중 참여와 행사 후 결과를 나눠 설명하는 구조 | 랜딩 |
| 앱 | Dribbble (Fast Poll - Poll Results) | https://dribbble.com/shots/5451736-Fast-Poll-Poll-Results | 자동 갱신 결과, 숫자 애니메이션, 득표순 재정렬 | 발표 화면, 오버레이, 랜딩 히어로 데모 |
| 앱 | Dribbble (Online poll result dashboard) | https://dribbble.com/shots/6227327-Online-poll-result-dashboard | 진행자가 보는 결과 대시보드 배치 | 진행자 콘솔 |
| 앱 | Dribbble (Mobile design concept for a polling app) | https://dribbble.com/shots/24164744-Mobile-design-concept-for-a-polling-app | 모바일 선택지 크기와 제출 흐름 | 청중 화면 |

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

- 원본(`D:\WorkSpace\platform\구현해야 할 프로젝트\Slido_Project\`)에는 코드가 없고 문서 2개뿐입니다. 이식은 요구사항·원칙을 새 기획서로 옮기는 것이며 복사할 코드가 없습니다. AI 계층은 원본에 없는 신규 기능입니다.
- 리뷰 "높음" 4건의 차단 설계는 `02_ARCHITECTURE.md` 6절과 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(Socket.io/FastAPI WebSocket, Redis 집계, 방 페이지 GEO)과 복사 금지 결함(전체 재조회, 채널 중복, 공개 채널 신뢰 등)은 옮기지 않습니다. 참고 자산(Hospital 실시간 훅)은 구조만 참고합니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| 브로드캐스터 | `services/poll-broadcaster/`는 Railway에 올리는 별도 프로세스입니다. 투표 경로의 일부이므로 AI 코드를 import하지 않습니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 R-5) |
| 남은 코어 과제 | 모듈러 seed 반영(R-3), `rate_limit_peek`(R-2), ai-service 모델 키 해석·위키 편집(R-6), core-voice 방문자 컨텍스트(R-7), Dify 앱 생성(R-8). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`). Realtime 부하가 다른 제품에 영향을 주면 모놀리스로 분리합니다 |
| Realtime 한도 | 플랜별 동시 접속·초당 메시지 한도는 미확인입니다. LP-06-027 부하 테스트로 확정하고 인원별 간격은 1810 마이그레이션으로 반영합니다. 청중 JWT 방식(사용자 정의 JWT 수용 여부)은 LP-06-011에서 확인합니다 |
| 청중 음성 남용 | 익명 입력으로 진행자 지갑이 소진될 수 있습니다. 5중 한도 + 묶음 선차감 + 오픈소스 전용을 지키고 LP-06-048 시나리오를 통과해야 합니다. 남용이 보이면 D12(Turnstile)를 앞당깁니다 |
| AI·음성 비용 | 크레딧 선차감과 정산, 기능별 라우팅, 오픈소스 우선·강제 기능으로 관리합니다. 운영 중 `core.ai_usage`로 원가를 확인해 단가(제안값)와 free 가입 크레딧 100(D8)을 확정합니다 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, 청중 원문(질문·닉네임·음성)은 동의와 무관하게 상용 전송 금지(D9), 녹음 기본 미저장, IP 원문 미저장 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만, LLM 키는 FastAPI에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, Supabase CLI, Docker, k6)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 진행자 chat만 상용)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D1~D18 확정, 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] W1~W6 진행, AI 보안 회귀 통과, MVP 출시 조건 충족

## 부록 A. 스크립트 없이 손으로 할 때

`live-poll-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\live-poll\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/live-poll"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\live-poll" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\live-poll" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/live-poll"` | `Set-Location "D:\WorkSpace\DEV\live-poll"` | `cd /d "D:\WorkSpace\DEV\live-poll"` |
| 3 초기화 | `bash init-project.sh live-poll --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh live-poll --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh live-poll --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/live-poll/live-poll-root/." "D:/WorkSpace/DEV/live-poll/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\live-poll\live-poll-root\*" "D:\WorkSpace\DEV\live-poll" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\live-poll\live-poll-root" "D:\WorkSpace\DEV\live-poll" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
