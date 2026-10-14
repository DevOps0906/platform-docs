# nomad-video(NOMAD AI Factory) 개발 방법

작성일 2026-10-13. 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 nomad-video 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\nomad-video\setup-nomad-video.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/nomad-video/setup-nomad-video.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\nomad-video\        platform에 남는 안내서, 도구, 재료
├── nomad-video_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-nomad-video.sh          설치 스크립트(Git Bash / Linux)
├── setup-nomad-video.ps1         설치 스크립트(Windows PowerShell)
└── nomad-video-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(nomad-video-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\nomad-video\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← nomad-video-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| 7 | 작업(65개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키 | 11~12 |
| - | 인증 단계: Mock → Google → 카카오·네이버 | 13 |
| - | 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 14~18 |
| - | 체크리스트 | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | NOMAD AI Factory. 트렌드 레이더로 소재를 고르고 숏폼(Track A~C), 롱폼(D), Lofi 단일 곡(E), 플레이리스트(F)를 크레딧 과금으로 자동 생산·검사·다채널 배포·제휴 수익화하는 조직 단위 SaaS |
| 통합 원본 | NOMAD Shorts Maker(`D:\WorkSpace\platform\NOMAD Shorts Maker\`), Nomad-BlogStudio(`...\Nomad-BlogStudio\`), Youtube_shots_Maker(`...\Youtube_shots_Maker\`, 작업 트리는 삭제 상태이며 git `5f6d262`에서 읽기 전용으로 참조) |
| 모듈러 앱 id / 스키마 | `video` / `video`(통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 01장 열린 결정 D-1) |
| 개발 근거 | `docs/file/`의 산출물 25개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| 로그인 | MVP 개발은 Mock(Stage A), 공개 베타 전 Google + 이메일(Stage B), G2 후 카카오·네이버(Stage C). 채널 연결 OAuth·네이버 클립 로그인 세션과는 별개. 13절 |
| AI 범위 | 채널 코치 채팅(Dify), 트렌드·채널 성과·과거 대본 RAG, 채널·브랜드 가이드 위키, 대본 그래프 `video.script`, 음성 대화·받아쓰기, 오픈소스 TTS 내레이션 선택 |
| 서비스 구성 | Next.js(`apps/web`), TS 오케스트레이터(BullMQ), Python 미디어 워커(Whisper, demucs, FFmpeg), FastAPI AI 서비스(`apps/api`). 마지막 둘은 서로 호출하지 않는 별개 서비스입니다(11절) |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js), 오케스트레이터 | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI AI 서비스) | `uv --version` | 같음 |
| Python 3.11 + FFmpeg 6, yt-dlp | 미디어 워커(`services/media-worker`, 3.11 고정) | `python --version; ffmpeg -version` | 같음 |
| Redis(Upstash 또는 로컬) | BullMQ | `redis-cli ping`(로컬일 때) | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | Whisper GPU 워커, 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절). 키마다 두는 곳이 다릅니다.
- FastAPI 전용: Anthropic, OpenAI, Google, OpenRouter(상용 LLM), Voyage(임베딩, video는 쓰지 않아도 됨)
- 서버 전용 프로세스(Next.js, 오케스트레이터): ElevenLabs, DeepL, fal, Suno, 채널 OAuth(Google, Meta, TikTok), SerpApi, RapidAPI
- Next.js만: 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`), Toss
- 미디어 워커: Supabase service_role만(LLM·ElevenLabs 키 없음)

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
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\nomad-video`로 복사 |
| 2 | **복사본 안의** `init-project.sh nomad-video --reset-git` 실행 |
| 3 | `nomad-video-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
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

- `nomad-video-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/nomad-video/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/nomad-video/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/nomad-video/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/nomad-video/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/nomad-video/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/nomad-video/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/nomad-video/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/nomad-video/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/nomad-video/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/NOMAD_Shorts_Maker.md`, `Nomad-BlogStudio.md`, `Youtube_shots_Maker.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 |
| `docs/products/nomad-video/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/nomad-video/supabase/monolith/migrations/0002_video_domain.sql` | `supabase/migrations/20261013000002_video_domain.sql` | - | DB |
| `docs/products/nomad-video/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB(플랜 AI 키, AI 라우팅 17행 포함) |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 25개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: 통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 생성과 검사 도구: `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`. 기획서가 바뀌면 다시 실행해 묶음을 새로 만듭니다. 이번 생성 결과는 경로 참조 341개, 묶음 안 누락 0, 절대경로 누락 0입니다.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\nomad-video\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 nomad-video-root에서 온 것입니다.

```
D:\WorkSpace\DEV\nomad-video\
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
│   └── api\                          [베이스] FastAPI(코드 없음, W1 VID-06-045에서 AI 서비스로 스캐폴딩)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\NOMAD_Shorts_Maker.md, Nomad-BlogStudio.md, Youtube_shots_Maker.md   [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(25개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 9개(AUTH_ROADMAP 포함)           [묶음]
│   │   │   └── 디자인\ 5개 + DESIGN.md, COMPONENTS.md     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   └── wiki\WIKI_SCHEMA.md, index.md, log.md, sources\  [묶음] 개발 위키
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 video-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_video_domain.sql   [묶음]
│   └── seed.sql                      [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

미디어 워커(`services/media-worker`), 오케스트레이터(`workers/video-orchestrator`), 업로더(`packages/sns-uploader`)는 베이스에 없으므로 06장 작업(VID-06-009, 011, 015)이 만듭니다. 위치는 `docs/file/03-설계/02_ARCHITECTURE.md` 2절을 따릅니다. 베이스의 `apps/web`, `apps/api`와 기획서의 `apps/nomad-video` 경로가 다르므로 첫 스캐폴딩 task에서 프로젝트 안의 실제 경로를 정하고 `docs/wiki/decisions/`에 기록합니다(제안).

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.x, React 19.2, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전), zod, TanStack Query v5 | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| 워커 | Node 20+ TS(`video-orchestrator`, BullMQ FlowProducer, Upstash Redis) | 같은 곳 |
| 미디어 워커 | Python 3.11 고정, Whisper large-v3, demucs 4, FFmpeg 6, yt-dlp, supabase-py | 같은 곳 |
| AI 서비스 | FastAPI(Python 3.12 제안), LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | `pnpm install / dev / build / lint / typecheck / test`, `uv sync`, `uvicorn app.main:app --reload`, `pytest apps/api`, `pytest services/media-worker`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절). 미디어 워커는 Python 3.11, AI 서비스는 3.12(제안)로 두 서비스의 런타임이 다르므로 가상환경을 따로 만듭니다.

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/database.ts` | 타입 생성(경로 제안) |
| 5 | `node scripts/dev/seed-users.mjs --app video` | 개발용 Mock 로그인 페르소나 시드(13.2절). `scripts/dev/`가 생긴 뒤(VID-06-004)부터. 원격 DB에는 실행하지 않습니다 |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다. pgvector 확장은 Supabase에서 기본 제공되며 `extensions` 스키마에 생성됩니다.
- `seed.sql` 끝에 AI 라우팅 기본값 17행과 체인 검사가 있습니다. 검사는 존재하지 않거나 종류가 다른 제공자가 체인에 있으면 실패합니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(VID-06-001)의 수용 기준입니다.
- RLS 회귀 테스트는 VID-06-002에서 `supabase/tests/`로 옮깁니다. 기획 단계에서 확인한 항목은 `docs/file/03-설계/05_DATA_MODEL.md` 9절과 `공용코어/SECURITY_BASELINE.md` 15절에 있습니다.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 25개(D-1~D-25)와 8.1절 인증 단계 결정 4개(D-26~D-29)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 모놀리스 스키마(`public` 여부) | 착수 전(VID-06-001 전) |
| D-2 | Track F 허용 플랜 | 결제·게이팅(VID-06-005) 전 |
| D-3 | Starter compliance 범위 | 업로드 API(VID-06-021) 전 |
| D-4 | Advanced 30% 할인 | 결제(VID-06-006) 전 |
| D-5 | 네이버 로그인(해소: 결정 22로 Stage C2, D-27) | G2 후 |
| D-6 | 대용량 미디어 저장소 | 미디어 워커(VID-06-011) 전 |
| D-7 | Track A 원본 권리(법률 검토) | 소싱·생산 API(VID-06-017) 전 |
| D-8 | Suno 연동 방식 | Track E(VID-06-019) 전 |
| D-9 | 유료 프로모션 자동 표시 | 업로드 화면(VID-06-032) 전 |
| D-10 | 텐핑·네이버쇼핑 커넥트 | 제휴(VID-06-022) 전 |
| D-11 | 랜딩·링크인바이오 문구 배치 | 공개 페이지(VID-06-023) 전 |
| D-12 | 산출물 보존 기간 | 스케줄러(VID-06-027) 전 |
| D-13 | 파이프라인 STT 일원화 방식 | Whisper 핸들러(VID-06-012) 전 |
| D-14 | OpenAI TTS-1-HD 백업 처리 | AI 단계·내레이션(VID-06-016, 053) 전 |
| D-15 | 오픈소스 TTS 모델과 언어 범위 | 제품 음성 기능(VID-06-053) 전 |
| D-16 | 같은 목소리 규칙의 범위 | VID-06-053 전 |
| D-17 | 3D 히어로 타일 질감 | 3D 히어로(VID-06-054) 전 |
| D-18 | 트렌드 RAG 수집 범위(약관 확인) | RAG 색인(VID-06-047) 전 |
| D-19 | 채팅 화면 레퍼런스 Astryx | 디자인 시스템 1단계(VID-06-041) 전 |
| D-20 | 파이프라인 LLM 단계 경로(`video.step`) | 대본 그래프(VID-06-049) 전 |
| D-21 | DeepL·fal·Suno 국외 이전 고지 | AI 게이트 온보딩(VID-06-046) 전 |
| D-22 | 내레이션 TTS 호출 위치와 ElevenLabs 키 | VID-06-053 전 |
| D-23 | 네이버 클립 업로드 방식(확정: Playwright + 위험 동의) | 클립 업로더(VID-06-057) 전 |
| D-24 | 대행 기능 외부 판매 | Phase 2 |
| D-25 | 고객 승인 링크 수단 | 고객 승인(VID-06-061) 전 |
| D-26 | 카카오 로그인 이메일 정책(권장: 비즈 앱 전환 + 이메일 필수 동의) | G2 판정 전(VID-06-064 전) |
| D-27 | 네이버 로그인 경로(`custom:naver` 또는 서버 브리지) | VID-06-065 스파이크 직후 |
| D-28 | 이메일+비밀번호 가입 유지(권고: 유지) | G1 판정 전(VID-06-063 전) |
| D-29 | 로그인용 Google 클라이언트와 채널용 YouTube 클라이언트 분리, env 이름 | G1 판정 전(VID-06-063 전) |

D-1~D-12는 기획서에서 `#1~#12`로 적혀 있습니다. 같은 번호입니다.

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절, 인증 작업은 8절)

작업은 VID-06-001~065, 모두 65개입니다. 그중 VID-06-043은 사람이 하는 디자인 비주얼 검토입니다. VID-06-004는 인증 Stage A(Mock 로그인)를 맡고, VID-06-063~065는 인증 B·C1·C2 작업입니다(13절). 06장 2절 표는 번호 순이 아니어서 W8 작업 057~062가 010 뒤에 있습니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 040, 041 | 없음 | DB 적용(AI 기본값 포함)·타입, 원본 정리, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 011, 039, 045 | 001 | RLS 테스트, 앱 골격, 미디어 워커 골격, CI, AI 서비스 설치 |
| W1-D | 036 → 042 → 043 → 044(직렬) | 003, 041 | 디자인 시스템 2~4단계(토큰, 기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 008, 012, 013, 014, 022, 025 | W1 | 과금 래퍼, 채널, 미디어 핸들러, 제휴, 웹훅 |
| W3 | 004, 006, 009, 015, 023, 028, 046, 054 | W2, 화면은 044 | 인증 Stage A(Mock 로그인), 결제, YouTube 업로더, 오케스트레이터, 공개 페이지, 셸, AI 게이트, 3D 히어로 |
| W4 | 007, 010, 016, 017, 018, 019, 020, 027, 035, 047, 052 | 006, 015, 046 | 결제 E2E, 생산 API 전부, 스케줄러, 랜딩, RAG 색인, 음성 대화·STT 편입 |
| W5 | 021, 024, 026, 029, 030, 031, 048, 049, 050, 051, 053 | W4 | 업로드 API, 레이더, 분석, 화면, 위키, 대본 그래프, Dify 채팅, 채팅 패널, 제품 음성 기능 |
| W6 | 032, 033, 034, 037, 056 | 021, 024, 049 | 업로드·수익화·레이더 화면, 통합 테스트, 대본 기획 UI |
| W7 | 063(G1 통과 후 먼저), 038, 055 | W6. 063은 G1 | 인증 Stage B(Google + 이메일), 사용자 플로우 E2E, AI 보안 회귀. **MVP 출시(공개 베타) 조건** |
| W8 | 057, 058, 059, 060 → 061, 062, 064·065(G2 통과 후) | W7(057은 009, 059는 blog 브랜드커넥트 어댑터, 064·065는 G2) | 네이버 클립 업로더·동의, 브랜드커넥트 클립, 대행 고객·승인·리포트, 인증 Stage C(카카오, 네이버) |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 결제, 권한, RLS, 데이터 모델, 오케스트레이터 아키텍처, AI 보안 설계 | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 미디어 워커, 그래프, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 3D 히어로, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(VID-06-043) | 사용자 |

06장 4절의 비율(모델 작업 64개 기준)은 Fable 12개(18.8%), Opus 33개(51.6%), Sonnet 16개(25.0%), Haiku 3개(4.7%)입니다(규모 가중 20.9%, 52.7%, 24.0%, 2.3%). 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/VID-06-001-db-apply/
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
    path: docs/file/01-관리/06_AGENT_PLAN.md   # VID-06-001 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/nomad-video/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
VID-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 video_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ seed 의 AI 라우팅 17행과 체인 검사 통과, 플랜 4행에 ai_chat·ai_chat_turns_per_day·voice_chat·ai_script 키 확인
④ supabase gen types 결과를 apps/web/src/types/database.ts 에 저장 ⑤ 06_AGENT_PLAN.md 의 VID-06-001 수용 기준 충족.

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

- **MVP 출시 조건**: W7까지 완료(인증 Stage B VID-06-063 포함), AI 보안 회귀(VID-06-055)와 결제 E2E(VID-06-007) 통과, `06_AGENT_PLAN.md` 7절 완료 정의를 충족해야 합니다.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).
- 원본 정리(VID-06-040)의 git 태그·삭제 명령은 사용자 승인 후에만 실행합니다.

## 11. AI 계층 구축 (nomad-video)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 2·5절, `04_API.md` 2.1·6절

| 구성 | nomad-video 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance). 영상·오디오 바이너리는 처리하지 않음 | VID-06-045 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. 기능별 기본값은 seed의 `ai_routing_settings` 17행(`video.script`·`chat` auto, `video.analyze`·`video.compliance`·위키 오픈소스 우선, `dify.aux`·`video.stt` 오픈소스 강제, 임베딩 oss-embed 고정, 내레이션 elevenlabs → oss-voice) | VID-06-045, 046 |
| 국외 이전 동의 | 온보딩에서 고지와 동의(`set_ai_cross_border_ack`). DeepL·fal·Suno 고지는 같은 화면의 별도 항목(D-21) | VID-06-046 |
| AI 게이트 | Next.js `/api/ai/*`: 인증, 대화 매핑 기록, 크레딧 선차감·정산, EdDSA 토큰 발급, 오케스트레이터용 잡 토큰(`/api/internal/ai-token`) | VID-06-046 |
| RAG | 운영자 컬렉션 `video-trends`·`video-guide`(제품 공통 지식)와 조직 컬렉션 `video-performance`·`video-scripts`·`video-brand`. 임베딩은 모두 oss-embed | VID-06-047 |
| 제품 위키 | 채널·브랜드 가이드 위키(조직별, 사람이 고친 블록은 에이전트가 덮어쓰지 않음, 개인정보 삭제는 `purge_wiki_page`) | VID-06-048 |
| LangGraph | `video.script`: 트렌드 검색 → 기획 → 대본 → 메타데이터 → compliance(마지막 노드). 제휴 링크와 대가성 문구는 그래프가 쓰지 않고 업로드 경로(VID-06-021)가 삽입. 보조 그래프 `video.step`(D-20) | VID-06-049, 056 |
| Dify 채팅 | 공용 Dify에 `video-chat` Chatflow 등록. 입력 `platform_conversation_id`, `context_ref`, HTTP 노드 → `/tools/answer`(내부 키). 설정은 `infra/dify/README.md` | VID-06-050, 051 |
| 음성 | 음성 대화·받아쓰기(STT 오픈소스 우선), 파이프라인 Whisper의 공용 구조 편입(`video.stt`), 오픈소스 TTS 내레이션 선택과 같은 목소리 규칙, 샘플 듣기 | VID-06-052, 053 |
| 보안 회귀 | 조직 격리, 대화 매핑 위조, 강제 오픈소스·국외 동의 우회, 크레딧 우회, 내레이션 대체 금지 | VID-06-055 |

**미디어 워커와 FastAPI의 경계(가장 중요한 규칙)**

| 항목 | 미디어 워커(Python 3.11) | FastAPI AI 서비스(Python 3.12 제안) |
|---|---|---|
| 하는 일 | Whisper, demucs, FFmpeg, yt-dlp | LLM 라우터, RAG, 위키, 그래프 |
| 입력 | `core.claim_jobs` | 서명 토큰 또는 Dify 내부 키 |
| 키 | service_role만 | service_role, LLM 키 |
| 서로 호출 | 안 함(오케스트레이터가 연결) | 안 함 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 라우팅을 상용만 쓰도록 둡니다. 이때는 국외 동의가 있는 테스트 조직으로 개발합니다. 다만 `video.stt`는 오픈소스 강제이므로 파이프라인 STT는 미디어 워커의 Whisper로 개발합니다.
3. 준비되면 기본값으로 되돌립니다.
4. 내레이션은 ElevenLabs로 먼저 개발하고, 오픈소스 TTS는 언어별 품질 검증(D-15)을 통과한 뒤 선택지에 노출합니다.

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보를 위키에 쓰지 않습니다.
- 초기 페이지(`sources/*.md` 25개)는 setup 시 함께 들어옵니다.
- 제품 안의 "채널·브랜드 가이드 위키"(DB, VID-06-048)와 다른 것입니다. 이 위키는 개발용입니다.

## 13. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009), 제품 적용은 `docs/file/02-요구사항/01_PRD.md` 9절·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, 개발 규칙은 `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙" 절입니다.

### 13.1 단계 요약

| 단계 | 로그인 | 언제 | 끝나는 조건 | 작업 |
|---|---|---|---|---|
| A | 로컬 Supabase 시드 계정 Mock 로그인(`/login` 개발용 패널, 모든 화면 상단 `MOCK AUTH · 로컬 전용` 배지) | W3(VID-06-004)부터 MVP 기능이 모두 동작할 때까지 | G1(13.3) | VID-06-004 |
| B | Google + 이메일(가입·메일 인증·비밀번호 재설정) | G1 통과 후, 공개 베타 전(W7 맨 앞) | G2(13.5) | VID-06-063(P0, Fable, M) |
| C1 | 카카오(Supabase 기본 제공자) | G2 통과 후(W8) | `AUTH_ROADMAP.md` 7.1.3절 | VID-06-064(P1, Opus, S) |
| C2 | 네이버(스파이크 → `custom:naver` 또는 서버 브리지) | G2 통과 후(W8, 064와 병렬) | `AUTH_ROADMAP.md` 7.2.4절 | VID-06-065(P1, Fable, M) |

- 세션은 모든 단계에서 실제 Supabase JWT입니다. `requireSession('video')`, `proxy.ts`, RLS, AI 서명 토큰 발급은 단계가 바뀌어도 같은 코드입니다.
- 단계 분기(`AUTH_MODE`, 제공자 목록)는 `src/lib/auth/`, 로그인 화면, 콜백, `/api/dev/login`에만 둡니다. 기능 코드·오케스트레이터·미디어 워커·`apps/api`의 `if (mock)`은 CI가 막습니다(VID-06-039).
- **혼동 금지**: 채널 연결 OAuth(YouTube·Meta·TikTok, `core.oauth_states`, VID-06-008)와 네이버 클립 업로드용 Playwright 로그인 세션(VID-06-057)은 사용자 로그인이 아닙니다. 단계와 무관하게 그대로이고 로그인 코드와 서로 import하지 않습니다. 로그인용 Google OAuth 클라이언트와 채널용 YouTube 클라이언트는 분리합니다(01장 D-29).
- 공개 랜딩·링크인바이오·단축 링크 방문자와 대행 고객 승인 화면(`/review/[token]`)은 로그인이 없고 단계와 무관합니다.
- VID-06-004는 디자인 시스템 4단계(VID-06-044) 뒤인 W3에 있어 Mock 로그인이 W3부터 생깁니다. W1~W2의 API 작업은 SQL·단위 테스트로 검증합니다. 더 일찍 필요하면 004의 비화면 부분(`src/lib/auth/`, `/api/dev/login`, 시드 스크립트)을 먼저 하는 분할을 결정합니다(06장 8.4절, 사용자 결정 필요).

### 13.2 Stage A 로컬 실행 순서

| 순서 | 명령·동작 | 설명 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase 기동(7절) |
| 2 | `supabase db reset` | 마이그레이션과 `seed.sql` 적용. `supabase/config.toml`의 Google·카카오 제공자는 `enabled = false` 그대로 |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<로컬 전용 임의 값>` | 서버 변수입니다. `NEXT_PUBLIC_`를 붙이지 않습니다. `NEXT_PUBLIC_SUPABASE_URL`은 `http://127.0.0.1:54321`(루프백이 아니면 Mock이 기동 실패) |
| 4 | `node scripts/dev/seed-users.mjs --app video` | 공통 페르소나 + 제품 훅(`seed-users.video.mjs`, Advanced 팀). 원격 호스트면 즉시 종료합니다. 두 번 실행해도 크레딧이 두 번 지급되지 않습니다 |
| 5 | `pnpm dev` → `http://localhost:3000/login` | 개발용 패널에서 페르소나 버튼으로 로그인 |
| 6 | E2E: `pnpm test:e2e` | `globalSetup`이 페르소나마다 `/api/dev/login`을 불러 `storageState`를 저장합니다(VID-06-007, 038) |

| 페르소나 | 기대 상태 | 주로 쓰는 곳 |
|---|---|---|
| `owner` | 개인 조직 owner, Starter, 잔액 100 | 기본 개발, Track A, 결제 E2E |
| `adv_owner` | Advanced 조직 owner(`features.agency`, 팀 5인, 채널 40) | 대행 고객·승인·리포트(060~062), Track D/F, 팀 초대 |
| `adv_member` | `adv_owner` 조직의 member | 팀 멤버 화면, member 권한 거부(클립 동의 403, 고객 생성 42501) |
| `admin`·`member`·`viewer` | `owner` 조직의 해당 역할(Starter) | 역할 분기, viewer 읽기 전용 |
| `outsider` | 다른 개인 조직 owner | 교차 테넌트 거부 |
| `no_app`, `suspended`, `ops` | 코어 공통(`AUTH_ROADMAP.md` 2.2절). 이 개발은 단독 `public` 스키마라 `no_app`도 가입 트리거가 자동 부트스트랩합니다 | 첫 진입, 403, 운영자 컬렉션 관리 |

`adv_owner`의 Advanced 플랜은 결제 경로가 아니라 시드 스크립트가 service_role로 엔타이틀먼트를 바꿔 만든 개발용 상태입니다(05장 10절). 결제 흐름 검증은 `owner`로 VID-06-007에서 합니다.

### 13.3 게이트 G1 체크리스트 (사람이 판정)

- [ ] `06_AGENT_PLAN.md` 2절 P0 기능 작업 완료(063~065와 공개 베타 직전 통합 작업 038·055 제외)
- [ ] 사용자 플로우 E2E(VID-06-038) 로컬 녹색, Mock 페르소나 storageState
- [ ] RLS 회귀(VID-06-002) 전 항목 통과, `outsider` 교차 테넌트 거부 확인
- [ ] 결제 E2E(VID-06-007) 녹색(Toss 테스트 키)
- [ ] 인증 모듈 밖 단계 분기 0건(VID-06-039 CI)
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL, 승인된 도메인), **로그인용** 웹 클라이언트 ID(채널용 YouTube 클라이언트와 별도), 운영 Supabase 프로젝트
- [ ] 01장 D-28(이메일 가입 유지), D-29(로그인·채널 Google 클라이언트 분리와 env 이름) 확정
- [ ] 판정 결과를 task `log.md`에 `[DECISION] G1 통과`로 기록

### 13.4 Stage B 외부 설정 순서 (사람, `AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위는 `openid`, `email`, `profile`만 | 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다. YouTube 범위는 로그인 클라이언트에 넣지 않습니다 |
| 2 | 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션, 로그인용). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다. 채널 연결용 클라이언트의 리디렉션(`/api/channels/callback/youtube`)과 섞지 않습니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml` `[auth.external.google]`에 `env(GOOGLE_CLIENT_ID)` | 로그인 키는 앱 env에 넣지 않습니다. 채널용 `GOOGLE_CLIENT_ID`(앱 env)와 이름이 겹치므로 D-29 결정대로 셸을 분리하거나 채널용 이름을 바꿉니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | Vercel 운영 env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email`. `DEV_SEED_PASSWORD`는 넣지 않습니다 | B-4, B-6 |
| 6 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |
| 7 | Google 실로그인 수동 점검(데스크톱·모바일 각 1회, 신규·기존 계정): 신규 계정 Starter 잔액 100, 재로그인 뒤에도 가입 원장 1행, 채널 연결(YouTube) 정상 | 결과를 task `log.md`에(B-5) |

### 13.5 게이트 G2 체크리스트 (사람이 판정)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안)
- [ ] 신규 가입자 중 `entitled=false`로 남은 사용자 0(`AUTH_ROADMAP.md` 6장 3번 쿼리, 단독 `public` 스키마면 `core.`를 `public.`으로)
- [ ] 카카오 디벨로퍼스 앱 생성, 01장 D-26 확정(권장: 비즈 앱 전환 + `account_email` 필수)
- [ ] 네이버 애플리케이션 등록(로그인용. 네이버 클립 업로드와 무관), 검수 신청 자료(로그인 버튼부터 가입 완료까지 화면 캡처) 준비
- [ ] 판정 결과를 task `log.md`에 `[DECISION] G2 통과`로 기록

### 13.6 C1 카카오 설정 (사람, `AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = Supabase 콜백(`https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://localhost:54321/auth/v1/callback`) |
| 4 | 카카오 로그인 활성, 동의항목 `profile_nickname`, `profile_image`, (비즈 앱이면) `account_email` |
| 5 | Supabase → Providers → Kakao 사용. 이메일을 받지 못하는 설정이면 "Allow users without an email"을 켜고 C1-3(결제 전 연락 이메일 입력)을 구현 범위에 넣습니다 |
| 6 | VID-06-064 완료 후 운영 `AUTH_PROVIDERS`에 `kakao` 추가. 수용 기준 C1-1: 새 카카오 계정 첫 로그인 뒤 Starter 잔액 100, 재로그인 뒤에도 가입 원장 1행 |

### 13.7 C2 네이버 스파이크와 검수 (`AUTH_ROADMAP.md` 7.2.2절)

| 순서 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`scripts/auth/register-naver-provider.mjs`, OAuth2, 네이버 authorize·token·`/v1/nid/me`) | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 등록된 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 채워졌는지, 재로그인이 같은 사용자로 매칭되는지 | 둘 다 참이면 `supabase_custom` |
| 4 | 실패하면 서버 브리지 경로. 코어 `staged/0010_core_auth_identity_links.sql` 적용을 요청(06장 8.3절 R-V11). 결과를 `[DECISION]`과 `NAVER_AUTH_PATH`에 기록(01장 D-27) | 기록 |
| 5 | 네이버 검수 신청(로그인 버튼부터 가입 완료까지 화면 캡처). 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다(C2-6) | 검수 통과 |

로컬 Supabase CLI가 커스텀 제공자를 지원하는지는 미확인입니다. 지원하지 않으면 로컬 개발은 Mock·Google·카카오로 하고 네이버는 스테이징 프로젝트에서 확인합니다. 네이버 클립 Playwright 코드(`naver-login.ts`)는 이 작업에 쓰지 않습니다.

### 13.8 단계 전환 요청 프롬프트 예시 (베이스 `_templates/dev-request-prompt.md` 형식)

G1 통과를 `log.md`에 기록한 뒤 Stage B 작업을 요청하는 예시입니다(9.4절 형식). C1·C2도 작업 ID, 수용 기준 절(7.1.3절, 7.2.4절), 게이트(G2)만 바꿔 같은 형식으로 씁니다.

```
D:/WorkSpace/DEV/nomad-video/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
VID-06-063: 인증 Stage B(Google OAuth + 이메일 가입·메일 인증·비밀번호 재설정)를 구현한다.
근거 = docs/file/03-설계/공용코어/AUTH_ROADMAP.md 3.2절·5장, 02_ARCHITECTURE.md 9절, 03_SCREENS_UX.md 7절,
04_API.md 8절, 01_PRD.md VD-F-001·9절·8.1절(D-28, D-29), 06_AGENT_PLAN.md 8절.
완료 조건 = ① AUTH_ROADMAP.md 5.3절 B-1~B-6 ② 새 Google 계정 첫 로그인 뒤 Starter 100크레딧 1회(재로그인 3회 뒤 가입 원장 1행)
③ OAuth 첫 로그인은 약관 동의 → /onboarding/ai → /dashboard ④ Mock E2E(VID-06-038) 계속 녹색
⑤ 채널 연결 OAuth(VID-06-008) 회귀 테스트 녹색 ⑥ Google 실로그인 수동 점검표는 사람이 채우도록 log.md 에 빈 표로 남긴다.

[작업의 특성]
인증 경로 작업. 진입 조건 = log.md 의 [DECISION] G1 통과. 원격 Supabase 대시보드·Google 콘솔 설정은 하지 않고 사람 작업 목록으로 남긴다.
Mock 로그인 코드는 지우지 않는다(로컬·E2E용). 기능 코드에 AUTH_MODE 분기를 추가하지 않는다.
채널 연결 OAuth(src/server/channels, /api/channels/**)와 네이버 클립 업로더(packages/sns-uploader/src/naver-clip)는 건드리지 않는다.
작업 대상 경로: apps/web/src/lib/auth/, apps/web/src/app/(auth)/, apps/web/src/app/auth/callback/, apps/web/src/app/onboarding/terms/, apps/web/src/app/api/onboarding/terms/

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert, supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

### 13.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 우선순위 | 웨이브 | 모델 |
|---|---|---|---|---|
| A | VID-06-004(인증 모듈 경계, Mock 로그인, 시드 스크립트 + Advanced 팀 훅, 가드, `finishLogin`) | P0 | W3 | Opus |
| B | VID-06-063(Google + 이메일, 콜백, 약관 온보딩, 로그인·채널 Google 클라이언트 분리) | P0 | W7 맨 앞(G1 후) | Fable |
| C1 | VID-06-064(카카오, 설정 → 로그인 방법) | P1 | W8(G2 후) | Opus |
| C2 | VID-06-065(네이버 스파이크 → `custom:naver` 또는 브리지) | P1 | W8(G2 후) | Fable |
| 관련 | VID-06-002(RLS, `outsider`), VID-06-007·038(Mock storageState E2E), VID-06-039(CI 금지 문자열·배포 빌드 검사) | P0 | W1, W4, W7, W1 | - |

## 14. 메인 디자인과 디자인 시스템

디자인 작업 순서: 14.3 시각 레퍼런스(Awwwards·Dribbble) → 14.1 디자인 시스템 → 14.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 14.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 앱 화면(잡·채널 대시보드)은 Primer, 보조 Atlassian(상태 배지·권한), 채팅은 Astryx 패턴(확인 후, D-19), 랜딩은 HERO_3D | VID-06-041, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(스크린 화이트, 편집실 슬레이트, 번인 자막 옐로, 타임코드 블루, 레코딩 레드, 타임라인 그레이, 트랙 범례 A~F) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`, 기본 컴포넌트 | VID-06-036(토큰), 042(컴포넌트) |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | VID-06-043(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | VID-06-044 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 랜딩은 밝은 편집실, 대시보드는 다크 베이스를 유지하고 트랙 색(A~F)은 항상 문자 라벨과 함께 씁니다.

### 14.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.5)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 원본 클립 타일이 소싱 레인에서 들어와 가공 게이트에서 9:16으로 바뀌고 번인 자막 띠가 붙은 뒤 KO·JA·EN 3장으로 갈라져 다채널 슬롯에 안착합니다 |
| 모바일(767px 이하) | 가벼운 3D 자동 로드: 타일 5개의 한 줄 흐름, 갈라짐 없음 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 제목, CTA, 단계 레이블, 언어 배지는 HTML로 3D 위에 겹칩니다. 3D 안에는 글자와 숫자를 넣지 않습니다.
- 이 히어로는 사용자 결정(2026-10-13)으로 기존 "플레이헤드 1회 스윕" 연출을 대체한 것입니다.
- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 금지: 보라 글로우, 큰 숫자 + 그라디언트, 해커 터미널 모노스페이스 라벨, 네온 그리드, 생성 건수·수익 같은 미검증 수치
- 확인: 레퍼런스 대비 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(VID-06-054, 035)

### 14.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` nomad-video 절(`:80`)에 있습니다.

| 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|
| Awwwards, Physical Matter by Runway (Honorable Mention) | https://www.awwwards.com/sites/physical-matter-by-runway | 히어로를 생성 결과 영상 하나로 연다 | 메인 히어로 |
| Awwwards, Join Radio (SOTD) | https://www.awwwards.com/sites/join-radio | 시간대에 따라 배경과 그래픽이 바뀌는 방식 | Track F 플리 소개, 링크인바이오 |
| Dribbble, Video Editing Dashboard | https://dribbble.com/shots/25186663-Video-Editing-Dashboard | 프로젝트 목록 + 타임라인 + 미리보기 왕복 | 롱폼 스토리보드, 숏폼 상세 |
| Dribbble, YouTube channel Dashboard Sample | https://dribbble.com/shots/25345883-YouTube-channel-Dashboard-Sample | 채널 지표 + 제휴 파트너 목록 한 화면 | 분석, 수익화 |
| Dribbble, Lofi Music Player | https://dribbble.com/shots/11703209-Lofi-Music-Player | 단일 곡 재생 화면 | Track E 곡 상세 |

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
- 원본 경로: `D:\WorkSpace\platform\NOMAD Shorts Maker\`, `D:\WorkSpace\platform\Nomad-BlogStudio\`, Youtube_shots_Maker는 `git show 5f6d262:Youtube_shots_Maker/...`로 읽기만 합니다.
- 리뷰 "높음" 26건의 차단 설계는 `02_ARCHITECTURE.md` 6절(7건)과 `05_DATA_MODEL.md` 7절(19건)에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.
- 07장의 "폐기" 항목(예: Mock 로그인, `x-internal-call`, OpenAI TTS 백업, 플레이보드 난수)은 옮기지 않습니다.
- Youtube_shots_Maker 정리의 git 태그·삭제는 사용자 승인 후에만 합니다(VID-06-040).

## 16. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 한곳에 모읍니다 |
| sns-uploader | 이 제품이 구현을 소유하고 nomad-commerce·nomad-blog가 소비합니다. `packages/sns-uploader`로 분리 가능하게 만듭니다 |
| 3D 키트 | 3D 공통 요소(로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정)는 `packages/ui-3d`로 분리 가능하게 만듭니다(코어 요청 R-V8) |
| 남은 코어 과제 | 06장 6절 R-V1~R-V10(플랜 AI 키 seed, OpenAI TTS kinds, 외부 서비스 레지스트리, 잡 토큰 표준화, ElevenLabs 서버 워커 호출 허용, Dify 앱, 음성 서버 품질) 등. `docs/file/01-관리/06_AGENT_PLAN.md` 6절을 참고합니다 |

## 17. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다(빌드·타입·린트, `pytest services/media-worker`, `pytest apps/api`, SQL 체커 OK, RLS 스모크, 결제 E2E, 파이프라인 통합 테스트, AI 보안 회귀, 3D·디자인 시스템 기준).

## 18. 위험과 주의

| 위험 | 대응 |
|---|---|
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 제품이 3~4개를 넘으면 통합 DB(모듈러) 전환을 검토합니다. 통합 DB SQL은 이미 있습니다(`D:\WorkSpace\platform\docs\products\_supabase-modular\`) |
| AI·음성 비용 | 크레딧 선차감과 정산, 기능별 라우팅, 오픈소스 우선 기능으로 관리합니다. 운영 중 `core.ai_usage`로 원가를 확인해 단가(제안값)를 확정합니다 |
| 원본 영상·오디오 | 제3자 저작물·목소리입니다. 파이프라인 STT는 오픈소스 강제(`video.stt`)이고 국외 제공자로 보내지 않습니다. 원본은 24시간 뒤 삭제합니다 |
| Mock 로그인 노출 | `AUTH_MODE=mock`은 로컬 `.env.local`에만 둡니다. 배포 환경 변수에 넣으면 기동이 실패하도록 가드가 있지만, 운영 env는 사람이 `AUTH_MODE=live`로 확인합니다(13.4절) |
| 대가성 문구 | 제휴 링크가 있는 업로드의 설명란·고정 댓글 첫 줄 문구는 그래프·채팅이 쓰거나 지우지 않고 서버가 삽입하며 DB CHECK가 보장합니다. 끄는 옵션을 만들지 않습니다 |
| 같은 목소리 | 내레이션은 작업 중 제공자를 바꾸지 않습니다. 실패하면 그 언어판만 실패 + 환불입니다 |
| 플랫폼 약관 | YouTube 다채널·도우인 수집·Suno 상업 이용·AI 음성 표시 정책은 미확인 항목이 많습니다. 구현 시 약관으로 확인하고 01장 6절에 반영합니다 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만, LLM 키는 FastAPI에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다. 원본의 노출된 키는 재발급합니다(VID-06-040) |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 19. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python 3.11/3.12, Node·pnpm, uv, FFmpeg, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D-1~D-29 확정(D-26~D-29는 각 확정 시점에), 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(14.3)
- [ ] 디자인 시스템 1~4단계 완료(14.1). 사람 비주얼 검토 포함
- [ ] Stage A 로컬 실행(13.2): 시드 스크립트, 개발용 패널 로그인
- [ ] W1~W6 진행, G1 판정(13.3), W7 인증 Stage B(13.4), 결제 E2E와 AI 보안 회귀 통과, MVP 출시 조건 충족
- [ ] 공개 베타 2주 뒤 G2 판정(13.5), 카카오·네이버(13.6~13.7)

## 부록 A. 스크립트 없이 손으로 할 때

`nomad-video-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\nomad-video\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/nomad-video"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-video" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-video" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/nomad-video"` | `Set-Location "D:\WorkSpace\DEV\nomad-video"` | `cd /d "D:\WorkSpace\DEV\nomad-video"` |
| 3 초기화 | `bash init-project.sh nomad-video --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh nomad-video --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh nomad-video --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/nomad-video/nomad-video-root/." "D:/WorkSpace/DEV/nomad-video/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\nomad-video\nomad-video-root\*" "D:\WorkSpace\DEV\nomad-video" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\nomad-video\nomad-video-root" "D:\WorkSpace\DEV\nomad-video" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
