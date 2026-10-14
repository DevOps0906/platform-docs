# flora-publishing(FLORA Publishing) 개발 방법

작성일 2026-10-13, 2026-10-14 개정(인증 단계 19장, 확정 결정 22; 에이전트·운영 콘솔·디자인 레이어 20장, FLORA 개편 검토용). 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 flora-publishing 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\flora-publishing\setup-flora-publishing.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/flora-publishing/setup-flora-publishing.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\flora-publishing\        platform에 남는 안내서, 도구, 재료
├── flora-publishing_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-flora-publishing.sh          설치 스크립트(Git Bash / Linux)
├── setup-flora-publishing.ps1         설치 스크립트(Windows PowerShell)
└── flora-publishing-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(flora-publishing-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\flora-publishing\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← flora-publishing-root에서 들어온 것(기존 폴더와 합쳐짐)
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
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계: Mock → Google → 카카오·네이버(7·9·10절과 함께 봅니다) | 19 |
| - | 에이전트 실행 계층, 검수, 운영 콘솔, 디자인 레이어(2026-10-14) | 20 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | FLORA Publishing. 원고는 있지만 조판 경험이 없는 1인 작가가 AI와 함께 기획, 집필, 판형 조정을 거쳐 인쇄용 PDF와 ePub을 만드는 전자책 출판 SaaS. 크레딧팩 + 저가 구독(Toss) |
| 통합 원본 | `D:\WorkSpace\platform\Flora-v2\`(베이스), `flora\`(v1 엔진), `flora-publisher\`, `구현해야 할 프로젝트\SellingDocs\`, `WeasyPrint - CSS Paged Media 명세.md` |
| 모듈러 앱 id / 스키마 | `publishing` / `publishing` (통합 DB를 쓸 때) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 01장 D10) |
| 개발 근거 | `docs/file/`의 산출물 25개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | 책별 RAG, 책 설정집 위키, 초안 그래프 `publishing.draft`, 단건 생성 그래프 `publishing.assist`, 글쓰기 도우미 채팅(Dify), 받아쓰기·채팅 음성·원고 낭독(미리듣기). 2026-10-14: 이 기능들을 6개 에이전트로 묶는 실행·검수 계층(`agent_tasks`)과 운영 콘솔. 교육 프로그램은 범위 밖 |
| 소유 서비스 | WeasyPrint 렌더 서비스(`services/render-weasyprint`)는 astro-ai와 공용이며 이 제품이 소유·운영합니다 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 20 LTS(기획 02장 기준), npm | `web`(Next.js), `worker` | `node -v; npm -v` | 같음 |
| Python 3.11(engine) / 3.12 + uv(제안, api) | `engine`, `api`(FastAPI AI 서비스) | `uv --version` | 같음 |
| Docker Desktop | Supabase 로컬, WeasyPrint 렌더 컨테이너(pango, cairo, Noto CJK), Dify, 오픈소스 음성·LLM 서버 | `docker version` | 같음 |
| Supabase CLI | 로컬 DB | `supabase --version` | 같음 |
| epubcheck(제안) | ePub 검증(PB-06-018, 032) | `java -jar epubcheck.jar --version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Anthropic, OpenAI, Google, OpenRouter(상용 LLM, `api/` 전용)
- ElevenLabs(음성, web 서버 전용)
- fal(표지, worker 전용), Toss Payments(결제), Supabase
- 서명 토큰 키쌍(`AI_TOKEN_PRIVATE_KEY`, web 서버 전용)과 Dify 내부 키
- Google OAuth 클라이언트 ID·시크릿(Stage B, Supabase 대시보드·로컬 `config.toml`에만), 카카오·네이버 로그인 키(Stage C). 개발 시작(Stage A)에는 필요 없습니다(19장)

| 인프라 | 문서 |
|---|---|
| Dify(공용 1개) | `D:\WorkSpace\platform\docs\develop\_shared\dify\README.md` |
| 오픈소스 음성 서버 | `...\_shared\voice\README.md` |
| 오픈소스 LLM 서버(vLLM)와 상용 키 | `...\_shared\llm\README.md` |

## 3. 1단계: 베이스 복사와 초기화 (setup 스크립트가 처리)

대상 폴더가 이미 있으면 중단하고, 베이스 원본은 읽기만 합니다.

| 순서 | 동작 |
|---|---|
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\flora-publishing`로 복사 |
| 2 | **복사본 안의** `init-project.sh flora-publishing --reset-git` 실행 |
| 3 | `flora-publishing-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
| 4 | 복사본의 `docs/etc`(베이스 설명서 PDF 13MB) 삭제 |
| 5 | 에이전트 모델 지정(9.2절 표 참고) |
| 6 | 무결성 점검(`_shared/check-invariants.sh`) |

`init-project.sh`는 project-profile의 이름과 target_repo 채우기, 산출물 등록부 생성, git 이력 초기화, 무결성 점검만 합니다. 파일 복사, 커밋, 의존성 설치, 스캐폴딩은 하지 않습니다.

**주의: 반드시 복사본 안의 스크립트를 실행해야 합니다.** 스크립트는 자기 파일이 있는 폴더를 초기화합니다. 베이스 원본에서 실행하면 원본이 초기화되고 `--reset-git`이면 git 이력이 지워집니다.

## 4. 2단계: 묶음 붙여넣기 (setup 스크립트가 처리)

- `flora-publishing-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/flora-publishing/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/flora-publishing/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/flora-publishing/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/flora-publishing/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/flora-publishing/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/flora-publishing/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/flora-publishing/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(DOC-CORE-009 `AUTH_ROADMAP.md`는 2026-10-14 인증 단계, 19장) |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/flora-publishing/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/flora-publishing/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/Flora-v2.md`, `flora.md`, `flora-publisher.md`, `SellingDocs.md` | `docs/reference/reviews/` | 참고 | 원본 리뷰 4건 |
| `docs/products/flora-publishing/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/flora-publishing/supabase/monolith/migrations/0002_publishing_domain.sql` | `supabase/migrations/20261013000002_publishing_domain.sql` | - | DB |
| `docs/products/flora-publishing/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB(플랜, 크레딧팩, AI 라우팅 12행) |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 25개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

**문서 경로 보정**: 복사본 안의 문서 경로는 새 위치로 바꿨고, 복사하지 않은 파일(통합 DB `_supabase-modular`, 다른 제품 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 경로 검사 결과: 참조 443개, 묶음 안 누락 0, 절대경로 누락 0. 기획서가 바뀌면 `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py flora-publishing`을 다시 실행합니다.

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\flora-publishing\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 flora-publishing-root에서 온 것입니다.

```
D:\WorkSpace\DEV\flora-publishing\
├── CLAUDE.md  init-project.sh  INSTALL.md  README.md  요구사항_TASK_전환_Format.md   [베이스]
├── .claude\
│   ├── agents\                       [베이스] claude-main(Opus), claude-reviewer(Sonnet), plan-challenger(→Fable),
│   │                                          nextjs-expert·fastapi-expert·supabase-expert(→Sonnet), review-expert(Sonnet)
│   ├── commands\agent-check.md       [베이스]
│   └── skills\ deliverable-first, nextjs-expert, fastapi-expert, supabase-expert, frontend-design, ui-ux-pro-max  [베이스]
│              llm-wiki\SKILL.md      [묶음] 개발 위키 스킬
├── _shared\                          [베이스] project-profile.md, orchestrator-rules.md, check-invariants.sh, adapters\ ...
├── _templates\                       [베이스] task.md, worker-brief.md ...
├── apps\
│   ├── web\                          [베이스] Next.js(코드 없음) = 기획서의 web/
│   └── api\                          [베이스] FastAPI(코드 없음) = 기획서의 api/ (AI 서비스)
│   (worker\, engine\ 은 기획서의 worker/, engine/. 베이스에 없으므로 PB-06-002, 003이 apps\worker, apps\engine 으로 만듭니다)
├── services\render-weasyprint\       [없음] PB-06-004가 만듭니다(공용 PDF 렌더 서비스)
├── docs\
│   ├── reference\ 00_MERGE_ANALYSIS.md, reviews\(리뷰 4건)   [묶음]
│   ├── file\ _index.md(25개), 01-관리, 02-요구사항, 03-설계(공용코어 9개(AUTH_ROADMAP 포함), 디자인 5개 + DESIGN.md, COMPONENTS.md), 04-구현   [묶음]
│   └── wiki\ WIKI_SCHEMA.md, index.md, log.md, sources\(25개)  [묶음] 개발 위키
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 publishing-chat.yml로 추가)
├── supabase\ migrations\(20261013000001_core_lite.sql, 20261013000002_publishing_domain.sql), seed.sql   [묶음]
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

기획서의 경로를 개발 폴더에서는 이렇게 읽습니다. task의 `write_scope`에도 오른쪽 값을 씁니다.

| 기획서 경로 | 개발 폴더 경로 |
|---|---|
| `web/` | `apps/web/` |
| `api/` | `apps/api/` |
| `engine/` | `apps/engine/` |
| `worker/` | `apps/worker/` |
| `services/render-weasyprint/` | `services/render-weasyprint/` |
| `supabase/`, `infra/` | 같음 |

`docs/etc`는 setup 스크립트가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.x, React 19.2, TypeScript strict, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전), Tiptap 2.x(제안) | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인) | 같은 곳 |
| TS 워커 | Node 20 + TS(`apps/worker`) | 같은 곳 |
| 출판 엔진 | FastAPI 0.115 + Python 3.11(pdfplumber, python-docx, nh3, ePub3 빌더) | 같은 곳 |
| AI 서비스 | FastAPI(Python 3.12 제안) + LangChain, LangGraph + `langgraph-checkpoint-postgres` | 같은 곳 |
| 렌더 | WeasyPrint 62 이상(제안) + Noto CJK 컨테이너 | 같은 곳 |
| DB | Supabase(Postgres + pgvector), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 명령 | web·worker: `npm ci / run dev / run build / run lint`, `npx tsc --noEmit`, api·engine: `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `ruff`, DB: `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다. 특히 **Tailwind는 반드시 v4(Tailwind CSS v4)**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절). `tailwind.config.js`를 만들지 않습니다.

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local > apps/web/src/types/supabase.ts` | 타입 생성(`CLAUDE.md` 5절은 `--schema core,publishing`, 단독 프로젝트는 `public`) |

- `core_lite`에는 SECTION 11(AI, pgvector)과 SECTION 12(음성)가 들어 있습니다.
- 기획 단계 검증은 PGlite로 했습니다(`D:\WorkSpace\platform\docs\products\_tools-sqlcheck\check.mjs --vector`, 모놀리스 3/3 OK, AI 라우팅 12행 확인). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 PB-06-001의 수용 기준입니다.
- 개발 시작 단계(Stage A)에서는 `db reset` 뒤 `node scripts/dev/seed-users.mjs --app publishing`으로 개발용 페르소나를 만들고 `/login` 개발용 패널로 로그인합니다(19.2절). 시드 스크립트는 PB-06-006이 만들므로 그 전(W0)에는 SQL·단위 테스트로만 확인합니다.
- RLS 회귀 테스트(57항목 + AI 코어 항목)는 PB-06-029에서 `supabase/tests/`로 옮깁니다.
- 원격 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다.

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 27개(D6은 2026-10-14 확정 결정 22로 닫힘, D20~D22는 8.1절 인증 단계, D23~D27은 8.2절 FLORA 개편)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D1 | FastAPI 범위(LLM 라우터는 ai-service로 변경) | 착수 전 |
| D2 | TTS 엔진 | 닫힘(확정 결정 16) |
| D3 | 판형 프리셋 값 충돌(A5 등) | PB-06-016 전, 실물 출력 테스트로 확정 |
| D4 | 업로드 형식(HWP 제외) | PB-06-015 전 |
| D5 | 판매·유통 | Phase 2 기획 전 |
| D6 | 카카오 로그인 | 닫힘(확정 결정 22: 카카오는 G2 후 C1, PB-06-057) |
| D7 | LLM 전략 | 닫힘(확정 결정 17) |
| D8 | 크레딧 단가·월 크레딧 | PB-06-008 전, 출시 전 원가 재산정 |
| D9 | Free의 업로드·전체 생성 허용 | PB-06-008 전 |
| D10 | 모놀리스 스키마 `public` | 착수 전(이 문서는 단독 `public` 기준) |
| D11 | 표지 이미지 모델 | PB-06-019 전 |
| D12 | 원고 개인정보 분류와 오픈소스 강제 범위(`contains_pii`), 책 스위치 컬럼 승격 | AI 게이트(PB-06-044) 전 |
| D13 | 단건 LLM 호출 경로와 스트리밍 | PB-06-048 전 |
| D14 | AI·음성 크레딧 단가 | PB-06-044 전, 출시 전 재산정 |
| D15 | 낭독·미리듣기 보이스와 ElevenLabs 데이터 보관 | PB-06-053 전 |
| D16 | 동의 증빙 저장 위치(audit_log vs 전용 표) | PB-06-001 마이그레이션 전 |
| D17 | 채팅 화면 레퍼런스 Astryx(존재·라이선스 확인) | 디자인 시스템 1단계(PB-06-039) 전 |
| D18 | 워커의 그래프 호출 인증(잡 토큰) | PB-06-047 전 |
| D19 | 무료 플랜의 AI 범위 | PB-06-044 전 |
| D20 | 카카오 이메일 정책(비즈 앱 `account_email` 권장) | G2 판정 전, PB-06-057 착수 전 |
| D21 | 네이버 경로(`supabase_custom`/`bridge`) | C2 스파이크(PB-06-058 첫 단계) 결과로 |
| D22 | 이메일+비밀번호 가입 유지(권고 유지) | G1 판정 전, PB-06-056 착수 전 |
| D23 | 브랜드 팔레트(기존 유지 권고 vs 제안서 포레스트 그린) | PB-06-041 사람 검토 |
| D24 | 화면 서체(레이어별: 랜딩 기존, 작업·운영 화면 Pretendard 후보) | PB-06-041 |
| D25 | 랜딩 헤드라인(기존 vs 제안서), 대기자 랜딩 교대 실험 | 공개 베타 전(PB-06-063) |
| D26 | 빈 소제목 AI 초안 반영 방식(바로 채우고 "검토 전" 표시 권고) | PB-06-059 착수 전 |
| D27 | 운영자 원고 열람(이용자 허용분만 권고) | PB-06-062 착수 전 |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 PB-06-001~065, 모두 65개입니다(2026-10-14 에이전트·운영 7개 추가, 20장). 그중 PB-06-041은 사람이 하는 디자인 비주얼 검토입니다. PB-06-056~058은 2026-10-14에 추가한 인증 단계 작업이고(19장, `06_AGENT_PLAN.md` 8절), 기존 PB-06-006은 Stage A(Mock 로그인) 범위로 바뀌었습니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 003, 004, 039 | 없음 | DB 적용(AI 기본값 포함), web·엔진·렌더 골격, 디자인 레퍼런스(1단계) |
| W1 | 005, 006, 007, 008, 016, 025, 029, 043 | W0 | CI, 인증 Stage A(Mock 로그인·시드·가드), API 공통, 단가·features, HTML/프리셋, 법무 문구·고지문, RLS 테스트, AI 서비스 설치 |
| W1-D | 040 → 041 → 042(직렬) | 002, 039 | 디자인 시스템 2~4단계. 화면 작업의 진입 조건 |
| W2 | 009, 010, 012, 015, 017, 018, 028, 034, 044, 048, 054, 059 | W1, 054는 042 | 결제, 책 CRUD, 페르소나, 업로드, PDF, ePub, 대기자, 배포, AI 게이트, 단건 생성 그래프, 3D 히어로, 에이전트 실행 계층 |
| W3 | 011, 013, 019, 020, 024, 027, 045 | 010, 012, 044, 048 | 기획 LLM, 섹션 생성, 표지, 책 정보, 랜딩, 운영자, 책별 RAG |
| W4 | 021, 023, 030, 031, 032, 046, 047, 050, 062, 063 | 013, 017, 045, 화면은 042, 062는 027 | 위저드 UI, 대시보드, 결제 E2E, 통합·엔진 테스트, 설정집 위키, 초안 그래프, 채팅 패널, 운영 콘솔 확장, 헤드라인 실험 |
| W5 | 014, 033, 038, 049, 051, 052, 060 | W4 | 전체 생성 워커, 아카이브, 문구 점검, Dify 채팅, 설정집 화면, 음성, 에이전트 작업 공간 |
| W6 | 022, 026, 036, 053 | W5 | 에디터(3단 레이아웃 포함), 웹훅, 탈퇴, 낭독·미리듣기 |
| W7 | 056(G1 통과 후 먼저), 037, 055, 061 | W6, 056은 G1 | Google + 이메일 로그인(Stage B), E2E(Mock 페르소나 storageState, 056 후 스테이징 재실행, 에이전트 작업 불변식), AI 보안 회귀, 에디터 AI 패널(P1). **MVP 출시 조건**(061 제외) |
| W8 | 035, 057·058(G2 통과 후), 064, 065 | MVP 출시, 057·058은 G2 | 공개 책 페이지(Phase 2), 카카오 로그인(C1, P1), 네이버 로그인(C2, P1), 워크플로 빌더·콘텐츠 에이전트(Phase 2) |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 결제, 권한, RLS, 데이터 모델, AI 보안 설계 | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 그래프, 테스트 설계 | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 문서 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 보일러플레이트, 린트·타입 정리, 반복 체크 | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(PB-06-041) | 사용자 |

모델 비율(64개 기준, 2026-10-14): Fable 13, Opus 33, Sonnet 13, Haiku 5(20.3% / 51.6% / 20.3% / 7.8%, 규모 가중 22.0% / 54.3% / 19.7% / 3.9%). 리뷰는 `claude-reviewer`, `plan-challenger`, `review-expert`가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고 작업 1개를 task 1개로 둡니다(베이스 `_templates/task-folder.md`).

```
tasks/PB-06-001-db-apply/
├── task.md      baseline에 산출물 ID, workers_approved, write_scope
├── context.md
└── log.md       [APPROVAL], [DECISION] 기록
```

```yaml
baseline:
  - id: DOC-DES-004
    path: docs/file/03-설계/05_DATA_MODEL.md
  - id: DOC-CORE-003
    path: docs/file/03-설계/공용코어/SECURITY_BASELINE.md
  - id: DOC-MGT-002
    path: docs/file/01-관리/06_AGENT_PLAN.md   # PB-06-001 수용 기준
```

### 9.4 요청 프롬프트 예시 (W0 첫 작업)

```
D:/WorkSpace/DEV/flora-publishing/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
PB-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 publishing_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다. 완료 조건 = ① supabase db reset 오류 0건 ② pgvector 확장과 ai_*·voice_* 테이블 생성 확인
③ ai_routing_settings(app publishing) 12행과 free·basic 플랜 AI 키 6개 확인 ④ supabase gen types 결과를 apps/web/src/types/supabase.ts 에 저장
⑤ 06_AGENT_PLAN.md 의 PB-06-001 수용 기준 충족.

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

- **MVP 출시 조건**: W7까지 완료(Stage B PB-06-056 포함, P1인 에디터 AI 패널 PB-06-061은 제외), AI 보안 회귀(PB-06-055) 통과, `06_AGENT_PLAN.md` 7절 완료 정의 충족.
- **인증 단계 게이트**: W6이 끝나고 Mock 핵심 플로우 E2E가 녹색이면 사람이 G1을 판정합니다(19.3절). G2는 공개 베타 2주 뒤입니다(19.5절).
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다.
- 화면 작업은 디자인 시스템 4단계(PB-06-042)가 끝난 뒤 시작합니다.

## 11. AI 계층 구축 (flora-publishing)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1·6절

| 구성 | flora-publishing 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, tools, compliance). LLM 키는 여기에만 | PB-06-043 |
| 모델 라우팅 | 상용(Claude → ChatGPT → Gemini)과 오픈소스(vLLM) 병행. seed의 `ai_routing_settings` 12행(`publishing.draft`·`publishing.assist`·`chat` auto, 위키 작업 오픈소스 우선, `dify.aux` 오픈소스 강제, `publishing.knowledge` oss-embed 고정, 음성 4행) | PB-06-043, 044 |
| 국외 이전 동의 | 온보딩에서 고지와 동의(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음 | PB-06-025, 044 |
| 개인정보 포함 원고 | 책별 오픈소스 전용 스위치(`book_info.ai_open_source_only`). 상용 대체 없음(01장 6.1절, D12) | PB-06-044, 045 |
| AI 게이트 | Next.js `/api/ai/*`, `/api/internal/*`, `/api/onboarding/*`: 대화 매핑, 선차감·정산, EdDSA 토큰, 잡 토큰 | PB-06-044 |
| 단건 생성 | 그래프 `publishing.assist`(compose → generate → compliance)와 compliance 규칙 파일. 기존 제목·기획안·목차·섹션·보조 집필·책 정보·페르소나 합성의 호출 경로 이전 | PB-06-048, 011, 013, 012, 020 |
| RAG | 책별 컬렉션 `book-<book_id>`, 참고 파일·원고 색인, 임베딩 oss-embed 고정, 평가셋 40문항 | PB-06-045 |
| 책 설정집 위키 | 캐릭터·용어·문체 페이지(slug `books/<book_id>/...`), draft → 채택, 사람 소유 블록, lint | PB-06-046, 051 |
| LangGraph | `publishing.draft`: outline → draft → consistency → proofread → compliance. 품질 평가셋 20건 | PB-06-047, 014 |
| Dify 채팅 | 공용 Dify에 `publishing-chat` Chatflow. 입력 `platform_conversation_id`, 모드 book/craft, HTTP 노드 → `/tools/answer` | PB-06-049, 050 |
| 음성 | 받아쓰기(STT 오픈소스 우선), 채팅 음성, 원고 낭독·미리듣기(제공자 대체 금지) | PB-06-052, 053 |
| 보안 회귀 | 서명 토큰, 대화 매핑, 국외 동의 필터, 오픈소스 전용 책, 선차감·정산, 라우팅 스냅샷 | PB-06-055 |

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
- 이것은 개발용 위키이며, 제품 안의 "책 설정집"(제품 지식 위키)과 다릅니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 앱 화면은 Atlassian(주, 워크플로·보드·상태 배지) + Primer(보조, 밀도), 채팅은 Astryx 패턴(확인 후, D17), 랜딩은 HERO_3D | PB-06-039, 고문 검토 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜(청먹, 교정지, 판면, 공정 시안, 맞춤 마젠타, 재단 회색) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`, 기본 컴포넌트, 레이어 3종 `data-surface`(marketing·workspace·ops, 03장 8.2절) | PB-06-040 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | PB-06-041(사람) |
| 4. 정답을 한 곳으로 | 코드를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤 | PB-06-042 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- `design-system/flora-publishing/MASTER.md`는 초안이며 정답이 아닙니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.6)

2026-10-13 사용자 결정으로 히어로가 3D로 바뀌었습니다. 토큰과 "피할 인상"(보라 그라디언트 AI 툴, 크림색 문학 잡지 템플릿)은 그대로입니다.

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 선택한 판형 비율의 원고 낱장이 모여 제본(실, 청먹 표지)되고 책장이 넘어가 실제 렌더한 A5 펼친 면에서 멈춥니다 |
| 모바일(767px 이하) | 책 한 권 회전, 제본은 2D(HTML/SVG)로 첫 화면에 포함, 가벼운 3D는 자동 로드 |
| 대체 | WebGL 미지원·저사양(로드 전 판정)·동작 줄이기 설정이면 정지 렌더 이미지 |

- 성능 예산(제안): PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하
- 3D 재질 색은 토큰만: 맞춤 마젠타는 재단선·맞춤표에만
- 확인: 스크린샷 3종, 고문(Fable) 디자인 검토(PB-06-054, 024)

### 13.3 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` flora-publishing 절(`:39`)에 있습니다.

| 구분 | 출처 | URL | 참고 포인트(가져올 것) | 적용 화면 |
|---|---|---|---|---|
| 랜딩 | Awwwards(Honorable Mention) | https://www.awwwards.com/sites/codapress-publishing | 결과물(책)을 히어로의 주인공으로 두는 방식 | 메인 히어로 |
| 랜딩 | Awwwards(Honorable Mention) | https://www.awwwards.com/sites/blue-bird-publishing-house | 표지 이미지와 서지 정보의 위계 | 시작 템플릿(시드) 갤러리 |
| 앱 | Dribbble | https://dribbble.com/shots/15364448-Scribbler-Writing-App | 본문 폭과 도구 노출을 최소화한 집필 화면 | 원고 편집기 |
| 앱 | Dribbble | https://dribbble.com/shots/23707376-AI-book-app | 생성 단계와 결과 미리보기의 연결 | 위저드, 완성 화면 |
| 앱 | Dribbble | https://dribbble.com/shots/22398012-Lexi-AI-Writer-Assistant-Web-App-Saas-Platform | 좌측 사이드바 + 본문 편집 영역 구조(카드 키트는 가져오지 않음) | 작업 공간 셸 |

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

- 원본 코드는 개발 폴더로 통째로 복사하지 않습니다. task마다 07장 2절의 이식 목록에서 필요한 파일만 옮기고 새 구조에 맞게 고칩니다.
- 원본 경로: `D:\WorkSpace\platform\Flora-v2\`, `flora\`, `flora-publisher\`, `구현해야 할 프로젝트\SellingDocs\`
- 이식 대상: v2 위저드 컴포넌트·페르소나 60종·판형 6종·테마 7종·시드 3종·업로드 파서, v1 ePub3 빌더·`print-presets`·`html-templates`·`build-html`·표지 프롬프트·집필 프롬프트
- 리뷰 "높음" 25건(비보안 13건은 `02_ARCHITECTURE.md` 6절, 보안·데이터 12건은 `05_DATA_MODEL.md` 7절)의 차단 설계는 해당 task의 리뷰 단계에서 확인합니다.
- 폐기 목록(D-01~D-43, 예: 사진집·룩북, Typst, `'1234'` 잠금해제, n8n 프록시, F5-TTS 벤더링)은 옮기지 않습니다. 원본 아카이브는 PB-06-033에서 하며 키 재발급 체크리스트를 포함합니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | 인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터는 `apps/web/src/core/` 같은 한곳에 모읍니다(공용 패키지로 뺄 수 있게). `apps/api/app/core/`, `apps/api/app/ai/`도 같습니다 |
| PDF 렌더 서비스 | `services/render-weasyprint`는 이 제품이 소유하고 astro-ai가 소비합니다. 요청 본문 상한·동시성·장애 연락 계약은 코어 요청 R6 |
| 3D 키트 | 로더, 토큰 기반 재질, 조명, 대체 이미지, 성능 측정은 `packages/ui-3d`로 분리 가능하게 만듭니다(R12) |
| 남은 코어 과제 | `adjust_credits` 미구현(R2), 잡 토큰 발급 표준화(R10), 호출 단위 오픈소스 강제(R8), 그래프 SSE(R9) 등. `docs/file/01-관리/06_AGENT_PLAN.md` 6절을 참고합니다 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의(빌드·타입·린트, pytest, SQL 체커 `--vector`, RLS 스모크, 결제 E2E, 핵심 플로우 E2E, AI·음성, 3D·디자인 시스템)를 따릅니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| 작업 수와 범위 | 65개 작업(인증 단계 3개, 에이전트·운영 7개 포함), 디자인 시스템 사람 검토(PB-06-041)가 병목입니다. W1-D를 일찍 시작합니다 |
| 렌더 컨테이너 | pango, cairo, Noto CJK 누락 시 한글이 깨집니다. 기동 시 `fc-list :lang=ko` 검사(PB-06-004) |
| 원고 개인정보 | 기본은 국외 이전 동의로 통제, 개인정보 포함 책은 오픈소스 전용. 오픈소스 품질이 낮을 수 있습니다(D12) |
| AI·음성 비용 | 크레딧 선차감과 정산, 기능별 라우팅, 오픈소스 우선 기능으로 관리합니다. 초안 그래프 단가(2/4)는 제안값이므로 `core.ai_usage` 원가로 확정합니다(D14) |
| 단건 스트리밍 | 그래프 SSE가 없으면 첫 토큰 목표가 완화됩니다(D13, R9) |
| 낭독 저작권·약관 | 미리듣기 파일의 배포 가능 여부는 ElevenLabs 약관 확인 전까지 청취 확인용으로 한정합니다(D15) |
| 원본 키 유출 | v1·v2의 `.env` 실키는 재발급하고 아카이브에 `.env*`를 남기지 않습니다(07장 5절) |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 인증 단계 건너뛰기 | Mock 단계에서 Google 콘솔을 먼저 붙이거나 기능 코드에 `if (mock)`을 넣지 않습니다. 단계 분기는 인증 모듈 안에서만, 전환은 사람이 G1·G2 판정 후(19장) |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 다시 묶으려면 `build_root.py`를 실행합니다 |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·npm, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 상용만)
- [ ] `supabase start` → `supabase db reset` 성공(7절)
- [ ] 결정 D1~D27 확정(D6은 닫힘), 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.3)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] Stage A: 시드 페르소나로 로컬 로그인 확인(19.2절)
- [ ] W1~W6 진행 후 G1 판정과 `[DECISION] G1 통과` 기록(19.3절)
- [ ] W7: Stage B(PB-06-056) 먼저, 이어서 E2E·AI 보안 회귀, MVP 출시 조건 충족
- [ ] 공개 베타 2주 뒤 G2 판정, C1·C2(19.5~19.7절)

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(확정 결정 22, 2026-10-14). 제품 반영: `docs/file/02-요구사항/01_PRD.md` PB-F-001·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙".

처음에는 Mock 로그인으로 모든 MVP 기능을 완성하고, 기능이 안정되면 Google 로그인을 붙이고, 그것이 안정되면 카카오·네이버를 붙입니다. 세션은 처음부터 실제 Supabase JWT이므로 단계가 바뀌어도 권한·RLS·크레딧 코드는 바뀌지 않습니다.

### 19.1 단계 요약

| 단계 | 언제 | 켜지는 로그인 | 작업 | 끝나는 조건 |
|---|---|---|---|---|
| A Mock | W0부터 W6까지(MVP 기능 개발) | 로컬 시드 페르소나 원클릭 로그인. 상단 배지 `MOCK AUTH · 로컬 전용` | PB-06-006(W1) | G1(19.3절) |
| B Google | G1 통과 후, 공개 베타 전(W7 맨 앞) | Google + 이메일(가입·메일 인증·재설정) | PB-06-056(P0, Fable, M) | G2(19.5절) |
| C1 카카오 | G2 통과 후(W8) | 카카오(Supabase 기본 제공자) | PB-06-057(P1, Opus, S) | `AUTH_ROADMAP.md` 7.1.3절 |
| C2 네이버 | G2 통과 후(W8, C1과 병렬) | 네이버(`custom:naver` 또는 서버 브리지) | PB-06-058(P1, Fable, M) | `AUTH_ROADMAP.md` 7.2.4절 |

### 19.2 Stage A 로컬 실행 순서

| 순서 | 명령·행동 | 설명 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase(`http://127.0.0.1:54321`) |
| 2 | `supabase db reset` | 마이그레이션과 seed 적용(7절) |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<임의의 긴 값>` | 커밋하지 않습니다. `NEXT_PUBLIC_*`에 넣지 않습니다. `NEXT_PUBLIC_SUPABASE_URL`이 로컬이 아니면 web이 기동하지 않습니다 |
| 4 | `node scripts/dev/seed-users.mjs --app publishing` | 페르소나 owner, admin, member, viewer, outsider, no_app, suspended, ops와 제품 훅의 basic(제안)을 만듭니다. 원격 URL이면 즉시 종료, 두 번 실행해도 크레딧 1회. 비밀번호는 출력하지 않습니다 |
| 5 | `npm run dev` 후 `/login` | 개발용 패널에서 페르소나 버튼을 누르면 `/dashboard`(owner·no_app은 `/onboarding` 약관 단계부터) |
| 6 | E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장합니다(PB-06-037) |

페르소나별 기대 결과는 `docs/file/03-설계/05_DATA_MODEL.md` 10절입니다. 권한 분기는 페르소나를 바꿔 로그인해서 확인하고, 기능 코드에서 페르소나 이메일로 분기하지 않습니다.

### 19.3 G1 체크리스트 (사람이 판정)

- [ ] `06_AGENT_PLAN.md` 2절 MVP P0 기능 작업 완료(인증 B·C 작업과 W7의 037·055 공개 베타 마무리 제외)
- [ ] 핵심 플로우 E2E(PB-06-037) Mock 페르소나로 로컬 녹색
- [ ] RLS 스모크(PB-06-029) 전 항목 통과, `outsider` 교차 테넌트 거부
- [ ] 결제 E2E(PB-06-030) Toss 테스트 키로 녹색
- [ ] CI(PB-06-005): 인증 모듈 밖 `AUTH_MODE` 참조 0, `mock-auth`·`nomad_role`·`nomad_plan` 0, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL, 승인된 도메인), 웹 클라이언트 ID, 운영 Supabase 프로젝트
- [ ] 결과를 PB-06-056 task `log.md`에 `[DECISION] G1 통과`로 기록

### 19.4 Stage B 외부 설정 순서 (`AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위 `openid`, `email`, `profile`만 | 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml` `[auth.external.google]`의 `env(GOOGLE_CLIENT_ID)` | 앱 env에는 넣지 않습니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(Vercel 미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |
| 6 | 배포 env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email` | 배포 체크리스트(B-6) |
| 7 | 수동 점검표: 데스크톱·모바일 각 1회, 신규·기존 계정 | 결과를 task `log.md`에(B-5). 실제 Google 로그인은 자동화하지 않습니다 |

### 19.5 G2 체크리스트 (사람이 판정)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안, 감사 `auth.login`과 오류 로그)
- [ ] 가입 기간 신규 가입자 중 `entitled=false`로 남은 사용자 0(`AUTH_ROADMAP.md` 6장의 SQL을 단독 `public` 스키마에 맞춰 실행)
- [ ] 카카오: 디벨로퍼스 앱 생성, 이메일 정책 D20 확정(비즈 앱 전환 권장)
- [ ] 네이버: 애플리케이션 등록, 검수 신청 자료(로그인 버튼부터 가입 완료까지 화면 캡처) 준비
- [ ] 결과를 `[DECISION] G2 통과`로 기록

### 19.6 C1 카카오 설정 (`AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = Supabase 콜백(`https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://localhost:54321/auth/v1/callback`) |
| 4 | 카카오 로그인 활성, 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email` |
| 5 | Supabase → Providers → Kakao 사용(로컬 `[auth.external.kakao]`). 이메일을 받지 못하면 "Allow users without an email"(D20 (b)일 때만) |
| 6 | 배포 env `AUTH_PROVIDERS=google,email,kakao`, 설정 → 로그인 방법 화면 확인(`03_SCREENS_UX.md` 7.4절) |

### 19.7 C2 네이버 스파이크와 검수 (`AUTH_ROADMAP.md` 7.2.2절)

| 단계 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`provider_type: 'oauth2'`, authorize·token·`/v1/nid/me` 엔드포인트). 등록은 `scripts/auth/register-naver-provider.mjs`(제안)로 남깁니다 | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 등록한 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 채워졌는지, 재로그인이 같은 사용자인지 | 둘 다 참이면 `supabase_custom` 채택 |
| 4 | 실패하면 브리지 경로(`04_API.md` 8절 `/auth/naver/start`·`/auth/naver/callback`)를 택하고 코어 요청 R15(`staged/0010_core_auth_identity_links.sql` 적용, 사람이 승인). 결과를 `NAVER_AUTH_PATH`와 `[DECISION]`에 기록 | 기록 |
| 5 | 네이버 검수 신청(로그인 버튼부터 가입 완료까지 화면 캡처). 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다(C2-6) | 검수 통과 |

로컬 Supabase CLI가 커스텀 제공자를 지원하는지는 미확인입니다. 지원하지 않으면 로컬은 Mock·Google·카카오로 개발하고 네이버는 스테이징 프로젝트에서 확인합니다.

### 19.8 단계 전환 요청 프롬프트 예시 (G1 통과 후 Stage B)

베이스 `_templates/dev-request-prompt.md` 형식을 따르며 9.4절 예시를 본떴습니다.

```
D:/WorkSpace/DEV/flora-publishing/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. 특히 docs/file/03-설계/공용코어/AUTH_ROADMAP.md 0·3·5장과 06_AGENT_PLAN.md 8절)

[요구사항]
PB-06-056: 인증 Stage B(Google OAuth + 이메일 가입·메일 인증·비밀번호 재설정)로 전환한다.
전제 = log.md 에 [DECISION] G1 통과 기록이 있다(없으면 시작하지 않고 보고).
완료 조건 = ① AUTH_ROADMAP.md 5.3절 B-1~B-6 ② /login 에 Google 버튼 + 이메일 폼, /signup·/reset-password 구현
③ /auth/callback 이 finishLogin(코드 교환 → session_context → bootstrap_app_for_org 1회 → status 분기 → next 화이트리스트)을 거친다
④ 첫 OAuth 로그인은 /onboarding 약관 단계 → AI 처리 방식 순서(03_SCREENS_UX.md 7.3절)
⑤ Mock E2E(PB-06-037)가 계속 녹색이고 배포 빌드에서 /api/dev/login 404
⑥ 06_AGENT_PLAN.md 의 PB-06-056 수용 기준 충족.

[작업의 특성]
권한 경계 작업. 단계 분기는 apps/web/src/lib/auth/, (auth)/, auth/ 안에서만. Google 콘솔·Supabase 대시보드 설정은 사람이 하고(AUTH_ROADMAP.md 5.1절) 에이전트는 체크리스트만 만든다.
작업 대상 경로: apps/web/src/app/(auth)/, apps/web/src/app/auth/callback/, apps/web/src/features/onboarding-terms/, apps/web/src/app/api/terms/, supabase/config.toml, docs/flora-publishing/ops/auth-checklist.md

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

C1·C2도 같은 형식으로 요청하되 전제를 `[DECISION] G2 통과`로, 완료 조건을 `AUTH_ROADMAP.md` 7.1.3절(C1-1~C1-5) 또는 7.2.4절(C2-1~C2-6)로 바꿉니다.

### 19.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 우선순위·규모·모델 | 웨이브 |
|---|---|---|---|
| A | PB-06-006(범위 변경: Mock 로그인, 시드, 가드, `finishLogin`) | P0, M, Fable | W1 |
| B | PB-06-056 | P0, M, Fable | W7 맨 앞(G1 후) |
| C1 | PB-06-057 | P1, S, Opus | W8(G2 후) |
| C2 | PB-06-058 | P1, M, Fable | W8(G2 후) |

## 20. 에이전트 실행 계층과 운영 콘솔 (2026-10-14 FLORA 개편, 검토용)

외부 제안서(ChatGPT 작성 "UI/UX 및 AI 에이전트 통합 디자인 제안서")를 기존 기획과 대조해 반영했습니다. 정본은 `docs/file/02-요구사항/01_PRD.md` 3.1절·8.2절, `docs/file/03-설계/02_ARCHITECTURE.md` 10절, `03_SCREENS_UX.md` 8절, `04_API.md` 9절, `05_DATA_MODEL.md` 2.5절, `docs/file/01-관리/06_AGENT_PLAN.md` 9절입니다.

### 20.1 무엇이 바뀌었나

| 항목 | 내용 |
|---|---|
| 에이전트 | 기획·자료·집필·편집·출판(콘텐츠는 Phase 2). 새 실행 엔진이 아니라 기존 Route Handler·잡·그래프를 레지스트리로 묶은 것 |
| 기록 | 유료 작업형 요청 1건 = `agent_tasks` 1행(`request_id` 멱등). 잡·실행·그래프 id를 잇고, 크레딧 원장은 `ref_type='agent_task'`, `ref_id=<작업 id>`로 묶는다 |
| 검수 | 사용자가 쓴 본문은 승인 전 불변. 잡으로 끝난 원고 작업(챕터 초안, 전체 순차 생성, 전체 다듬기)은 검수 대기함과 에디터 AI 패널 "제안" 탭에서 비교·승인·거부(RPC `decide_agent_task`). 선택 영역 동작은 그 자리 Diff 카드가 검수 |
| 재시도 | 실패·부분·취소만, 작업당 한 번, 재시도 범위(실패분, 취소면 남은 것까지)만 차감. 원래 작업의 결과 없는 차감이 모두 환불돼 있어야 한다(DB 트리거·부분 유니크 + 원장 `ref_id` 확인) |
| 운영 콘솔 | 운영 홈, 사용자·권한, 출판 프로젝트, 에이전트·AI 운영, 작업 큐·실행 추적 6단계, 결제·크레딧·원가, 설정 열람, 감사. 원고 본문은 기본 차단 |
| 디자인 | 레이어 3종(`data-surface`: marketing, workspace, ops). 색·서체·헤드라인은 D23~D25 결정 전까지 기존 토큰 |
| 범위 밖 | 교육 프로그램(별도 사업) |

### 20.2 로컬 확인 순서 (Stage A Mock 로그인 상태에서)

| 순서 | 할 일 | 기대 |
|---|---|---|
| 1 | `supabase db reset` 후 `\d agent_tasks`(모놀리스 `public`) | 표, 트리거 3개(`set_updated_at`, `before_insert`, `transition`) + guard |
| 2 | `owner` 페르소나로 챕터 초안 실행 | `/dashboard/agents?tab=history`에 행 1개, 끝나면 "검수 대기" |
| 3 | 같은 요청을 같은 `request_id`로 다시 보냄 | 새 행 0, 차감 0 |
| 4 | 일부 승인 | 승인한 소제목만 revision+1, 작업 "일부 승인", 감사 `agent_task.decide` |
| 5 | `viewer`로 결정 시도 | 403 |
| 6 | `ops` 페르소나로 `/admin/jobs/<작업 id>` | 6단계 추적, 본문·프롬프트 없음 |

### 20.3 이 제품의 에이전트·운영 작업 ID

| ID | 작업 | 웨이브 | 모델 |
|---|---|---|---|
| PB-06-059 | 에이전트 실행 계층(레지스트리, 기록기, API, 동기화 크론) | W2 | Opus |
| PB-06-060 | 에이전트 작업 공간 화면 | W5 | Sonnet |
| PB-06-061 | 에디터 AI 패널(3단 레이아웃은 022, W6) | W7 | Opus |
| PB-06-062 | 운영 콘솔 확장(추적, 원가, 재실행) | W4 | Fable |
| PB-06-063 | 랜딩 헤드라인 실험(D25) | W4 | Haiku |
| PB-06-064, 065 | 워크플로 빌더, 콘텐츠 에이전트(Phase 2) | W8 | Sonnet, Opus |

## 부록 A. 스크립트 없이 손으로 할 때

`flora-publishing-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\flora-publishing\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/flora-publishing"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\flora-publishing" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\flora-publishing" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/flora-publishing"` | `Set-Location "D:\WorkSpace\DEV\flora-publishing"` | `cd /d "D:\WorkSpace\DEV\flora-publishing"` |
| 3 초기화 | `bash init-project.sh flora-publishing --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh flora-publishing --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh flora-publishing --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/flora-publishing/flora-publishing-root/." "D:/WorkSpace/DEV/flora-publishing/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\flora-publishing\flora-publishing-root\*" "D:\WorkSpace\DEV\flora-publishing" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\flora-publishing\flora-publishing-root" "D:\WorkSpace\DEV\flora-publishing" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Docker는 별도로 필요합니다(Supabase 로컬, 렌더 컨테이너, Dify, 오픈소스 서버).
