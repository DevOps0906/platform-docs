# airbnb(Stay, 가칭) 개발 방법

작성일 2026-10-20. 이 문서는 `D:\WorkSpace\platform\docs\products\airbnb\`의 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 airbnb 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안"으로 표시합니다.

**다른 제품과 다른 점(2026-10-20 현재)**: 이 묶음은 "핵심만"으로 만들었습니다. setup 스크립트(`setup-airbnb.sh` / `.ps1`)와 개발 폴더에 붙일 `airbnb-root/` 묶음이 아직 없습니다. 3~5장은 스크립트가 만들어진 뒤 하게 될 일을 적었고, 지금 바로 시작하려면 부록 A의 손 작업을 따릅니다. 만드는 방법은 0장 끝과 `README.md`에 있습니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다(스크립트를 만든 뒤).** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\airbnb\setup-airbnb.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/airbnb/setup-airbnb.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\airbnb\         platform에 남는 안내서, 도구, 재료
├── README.md
├── airbnb_develop.md           이 문서(개발 폴더로 옮기지 않음)
├── setup-airbnb.sh             (아직 없음) 설치 스크립트(Git Bash / Linux)
├── setup-airbnb.ps1            (아직 없음) 설치 스크립트(Windows PowerShell)
└── airbnb-root\                (아직 없음) build_root.py가 만든다. "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(airbnb-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\airbnb\                              베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  ← airbnb-root에서 들어온 것(기존 폴더와 합쳐짐)
└── apps\  _shared\  _templates\  .claude\agents\  init-project.sh ...  ← 베이스에 원래 있던 것
```

| 단계 | 내용 | 절 |
|---|---|---|
| 0 | (지금만) 묶음과 스크립트 만들기, 또는 부록 A 손 작업 | 0장 끝, 부록 A |
| 준비 | 도구 설치, API 키 준비 | 2 |
| 1~2 | setup 스크립트 실행(베이스 복사, 초기화, 묶음 붙여넣기, docs/etc 삭제, 에이전트 모델 지정) | 3, 4 |
| 3 | 최종 트리 확인 | 5 |
| 4 | project-profile 작성 | 6 |
| 5 | 로컬 DB 기동과 SQL 적용 | 7 |
| 6 | 착수 전 결정 확정, 산출물 승인 | 8 |
| 7 | 작업(45개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계: Mock → Google → 카카오·네이버 | 19 |

**묶음과 스크립트 만들기(docs 저장소에서 1회)**

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | `develop/_shared/tools/build_root.py`의 `REVIEWS`에 `'airbnb': ['Airbnb_CloneCoding.md']`, `APP_ID`에 `'airbnb': 'stay'` 추가 | 모르는 제품이면 `SystemExit`로 멈추던 것이 통과 |
| 2 | `python -I develop/_shared/tools/build_root.py airbnb` | `develop/airbnb/airbnb-root/docs/file/_index.md` 생성 |
| 3 | `python -I develop/_shared/tools/build_root.py airbnb --check` | 경로 참조 누락 0 |
| 4 | `develop/live-poll/setup-live-poll.sh`, `.ps1`을 `develop/airbnb/setup-airbnb.*`로 복사하고 `live-poll`을 `airbnb`로 바꾼다(`$Pkg = airbnb-root`, 대상 `D:\WorkSpace\DEV\airbnb`) | `--dry-run` 출력에 6단계가 보인다 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | Stay(가칭, 최종명은 01장 D1). 게스트가 숙소를 검색·예약 요청하고 호스트가 숙소를 올려 승인하는 숙소 공유 서비스. 베타는 결제 없는 예약 요청·확정, 결제와 호스트 유료 플랜은 Phase 2(D2) |
| 원본 | `D:\WorkSpace\CloneCoding\Airbnb_CloneCoding`(Next.js 14 Pages Router, 완성도 약 60%, `docs/reviews/Airbnb_CloneCoding.md:18`). 서버 코드는 이식하지 않고 다시 쓴다(14절) |
| 모듈러 앱 id / 스키마 | `stay` / `stay`(번호 2700, 등록 요청 06장 R-2) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(`public` 스키마, 기획서 D12) |
| 개발 근거 | `docs/file/`의 산출물(등록부 `docs/file/_index.md`, build_root가 생성). 정본은 이 산출물입니다 |
| 인증 | 게스트·호스트가 같은 계정. 단계: A Mock(개발) → B Google + 이메일(공개 베타 전) → C 카카오·네이버(G2 후). 비로그인 검색·상세·리뷰 목록은 공개 RPC로 단계와 무관(19절) |
| AI 범위 | 숙소 AI 도우미(Dify, 숙소 공개 정보·호스트 위키 근거), 자연어 검색 `stay.search_parse`, 소개 작성 그래프 `stay.listing_assist`, 리뷰 요약 그래프 `stay.review_summary`(오픈소스 강제), 호스트 위키, 음성 대화 |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | 같음 |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, build_root.py, setup의 모델 지정 단계 | `python --version` | 같음 |
| Node.js 22 LTS, pnpm | `apps/web`(Next.js) | `node -v; pnpm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI AI 서비스·잡 워커) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 음성·LLM 서버, 로컬 메일 캐처 | `docker version` | 같음 |
| Playwright | E2E(SY-06-037) | `pnpm exec playwright --version` | 같음 |
| NVIDIA GPU + Container Toolkit(WSL2) | 오픈소스 음성·LLM 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. 실제로 실행되는 `python`을 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절).
- Supabase(URL, anon, service_role)
- Google Maps Platform: 브라우저용(HTTP 리퍼러 제한) 키와 **서버 지오코딩용 키를 분리**(원본은 공개 키 하나로 서버 호출, 리뷰 #16)
- Anthropic, OpenAI, Google(상용 LLM, FastAPI 전용), ElevenLabs(음성, Next.js 서버 전용)
- `DIFY_*`, `AI_TOKEN_PRIVATE_KEY`(Ed25519, Next.js만), IP HMAC 비밀(레이트 리밋 키)
- 이메일 발송 서비스 키(SY-06-022, 서비스는 구현 시 선택)
- Toss Payments(Phase 2부터)

**원본 저장소 주의**: 원본 폴더의 git 인덱스에 `.env.local`(AWS 키, JWT 비밀)이 올라가 있습니다(리뷰 #7). 원본 키는 재발급하고, 새 개발 폴더로 복사하지 않습니다(07장 5절).

공용 인프라 설치 문서는 다음과 같습니다.

| 인프라 | 문서 |
|---|---|
| Dify(공용 1개) | `D:\WorkSpace\platform\docs\develop\_shared\dify\README.md` |
| 오픈소스 음성 서버 | `...\_shared\voice\README.md` |
| 오픈소스 LLM 서버(vLLM)와 상용 키 | `...\_shared\llm\README.md` |
| 소셜 로그인 | `...\_shared\auth\README.md` |

## 3. 1단계: 베이스 복사와 초기화 (setup 스크립트가 처리할 일)

setup 스크립트(0장 끝에서 live-poll 것을 복사해 만듦)는 다음 6단계를 순서대로 처리합니다. 대상 폴더가 이미 있으면 중단하고, 베이스 원본은 읽기만 합니다.

| 순서 | 동작 |
|---|---|
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\airbnb`로 복사 |
| 2 | **복사본 안의** `init-project.sh airbnb --reset-git` 실행 |
| 3 | `airbnb-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
| 4 | 복사본의 `docs/etc`(베이스 설명서 PDF) 삭제 |
| 5 | 에이전트 모델 지정(9.2절) |
| 6 | 무결성 점검(`_shared/check-invariants.sh`) |

`init-project.sh`는 `_shared/project-profile.md`의 이름과 target_repo를 채우고, 산출물 등록부 `docs/file/_index.md`를 만들고, `--reset-git`이면 템플릿 git 이력을 끊고 `git init`을 한 뒤 무결성 점검을 합니다. 파일 복사, 커밋, 의존성 설치, 스캐폴딩은 하지 않습니다.

**주의: 반드시 복사본 안의 스크립트를 실행해야 합니다.** 스크립트는 자기 파일이 있는 폴더를 초기화합니다. 베이스 원본에서 실행하면 원본이 초기화되고 git 이력이 지워집니다.

## 4. 2단계: 묶음 붙여넣기 (setup 스크립트가 처리할 일)

- `airbnb-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 묶음이 아직 없을 때 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`, build_root.py 매핑)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/airbnb/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/airbnb/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/airbnb/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/airbnb/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/airbnb/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/airbnb/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/airbnb/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세 |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/_design-guide/DASHBOARD_PATTERNS.md`, `LANDING_PERSUASION.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008~009 | 앱 화면 구조 패턴, 설득형 랜딩 |
| `docs/products/airbnb/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/airbnb/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/Airbnb_CloneCoding.md` | `docs/reference/reviews/Airbnb_CloneCoding.md` | 참고 | 원본 리뷰 |
| `docs/products/airbnb/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB |
| `docs/products/airbnb/supabase/monolith/migrations/0002_stay_domain.sql` | `supabase/migrations/20261013000002_stay_domain.sql` | - | DB |
| `docs/products/airbnb/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB |
| `docs/products/airbnb/supabase/monolith/tests/rls_smoke.mjs` | `supabase/tests/rls_smoke.mjs` | - | 기획 단계 PGlite 스모크(49항목). SY-06-030이 SQL 테스트로 옮긴다 |
| (베이스 제공) | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 규칙·스킬 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 숙소 도우미 앱 설정 |

**문서 경로 보정**: build_root.py가 복사본 안의 경로를 새 위치로 바꾸고, 복사하지 않은 파일(통합 DB, 다른 제품 문서)은 `D:/WorkSpace/platform/...` 절대경로로 바꿉니다. 줄 번호는 그대로입니다. 원본 기획서는 고치지 않습니다. `tests/*.sql`만 복사하는 build_root.py라면 `rls_smoke.mjs`는 손으로 복사합니다(미확인: build_root.py가 `.mjs`를 복사하는지).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\airbnb\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 airbnb-root에서 온 것, `[신규]`는 작업이 만드는 것입니다.

```
D:\WorkSpace\DEV\airbnb\
├── CLAUDE.md                         [베이스] 오케스트레이터 운영 규칙(덮어쓰지 않음)
├── init-project.sh  INSTALL.md  README.md  요구사항_TASK_전환_Format.md   [베이스]
├── .claude\
│   ├── agents\                       [베이스] claude-main(Opus), claude-reviewer(Sonnet), plan-challenger(→Fable),
│   │                                          nextjs-expert·fastapi-expert·supabase-expert(→Sonnet), review-expert(Sonnet)
│   ├── commands\agent-check.md       [베이스]
│   └── skills\                       [베이스] deliverable-first, nextjs-expert, fastapi-expert, supabase-expert, frontend-design, llm-wiki 등
├── _shared\                          [베이스] project-profile.md(6절), orchestrator-rules.md, check-invariants.sh, gate.sh, scope_check.sh ...
├── _templates\                       [베이스] task.md, task-folder.md, log.md, context.md, dev-request-prompt.md ...
├── apps\
│   ├── web\                          [베이스] Next.js(코드 없음, SY-06-004에서 스캐폴딩)
│   └── api\                          [베이스] FastAPI(코드 없음, SY-06-005에서 설치)
├── scripts\dev\  scripts\ops\  scripts\perf\   [신규] 시드(SY-06-003), 운영(043), 성능(042)
├── docs\
│   ├── reference\00_MERGE_ANALYSIS.md, reviews\Airbnb_CloneCoding.md   [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md, 공용코어\ 9개, 디자인\     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   ├── design\                       [신규] 레퍼런스(SY-06-007), 비주얼 검토 기록(009)
│   └── wiki\index.md, log.md, sources\  [묶음] · WIKI_SCHEMA.md [베이스]
├── infra\dify\README.md              [묶음]
├── supabase\
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_stay_domain.sql   [묶음]
│   ├── seed.sql                      [묶음]
│   └── tests\                        [묶음 + 신규] rls_smoke.mjs → SY-06-030 SQL 테스트
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트(또는 부록 A 5단계)가 지웁니다.

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.x(App Router), React 19, Tailwind CSS v4(4.x 고정), shadcn/ui(v4 지원 버전), `@supabase/ssr`(요청 단위 클라이언트), zod | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인). 랜딩 히어로에서만 | 같은 곳 |
| 지도 | Google Maps JavaScript API(어댑터 뒤, D6), 서버 지오코딩은 별도 키 | `01_PRD.md` D6, SY-06-013 |
| API(AI)·워커 | FastAPI(Python 3.12, 제안), LangChain, LangGraph. AI 서비스와 잡 워커에만 쓰고 예약·검색 경로에는 넣지 않음 | 02장 2절 |
| DB | Supabase(Postgres + pgvector + btree_gist), 단독 프로젝트, `public` 스키마 | `05_DATA_MODEL.md` |
| 테스트 | Vitest(단위), Playwright(E2E), Supabase SQL 테스트(RLS), pytest(AI 평가셋) | 06장 7절 |
| 명령 | `pnpm install / dev / build / lint / typecheck / test / test:e2e / test:rls / test:ai`, `uv sync`, `uvicorn app.main:app --reload`, `pytest`, `supabase start`, `supabase db reset`, `supabase gen types typescript --local` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 대상), plan-challenger `claude-fable-5-1` | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile(pnpm 하나)로 고정합니다. 원본처럼 `package-lock.json`과 `yarn.lock`을 함께 두지 않습니다(리뷰 #24). 스타일은 반드시 **Tailwind CSS v4**이고 styled-components·Redux는 쓰지 않습니다(07장 3절).

## 7. 5단계: 로컬 DB

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만. 기존 `migrations`, `seed.sql`은 그대로 둡니다 |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `mkdir -p apps/web/src/types && supabase gen types typescript --local --schema public > apps/web/src/types/supabase.ts` | 타입 생성(SY-06-001 소유 경로) |

| 확인(Studio SQL 편집기) | 기대값 |
|---|---|
| `select count(*) from public.ai_routing_settings where org_id is null and app_id = 'stay'` | 11 |
| `select code, signup_credits, monthly_credits, is_active from public.plans where app_id = 'stay'` | free 100 / 0 / true, host_plus 0 / 500 / false |
| `select count(*) from public.listings` | 0(시드 훅 실행 전) |
| `select extname from pg_extension where extname in ('btree_gist', 'vector')` | 2행 |

- `core_lite`는 `MONOLITH_CORE_LITE.sql` 사본에서 SECTION 6-A, 6-B, 9만 지웠습니다. SECTION 3(Toss, Phase 2), 4(크레딧), 6-C(레이트 리밋), 7(잡), 8(Storage, 숙소 사진은 `public-assets` 버킷), 11(AI), 12(음성)가 들어 있습니다.
- `stay_domain`은 아직 모듈러 조각이 없어 이 파일이 정본입니다. SY-06-002가 `2700_stay.sql`로 역변환한 뒤부터는 조각이 정본입니다(`05_DATA_MODEL.md` 8장).
- 기획 단계 검증은 PGlite로 했습니다: 0001 → 0002 → seed 2회 반복 적용 OK, 스모크 49/49 통과(`05_DATA_MODEL.md` 9장, `supabase/tests/rls_smoke.mjs`). 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 작업(SY-06-001)의 수용 기준입니다.
- 스모크 재실행: docs 저장소의 `products/_tools-sqlcheck`에서 `npm install` 후 `node ../airbnb/supabase/monolith/tests/rls_smoke.mjs . ../airbnb/supabase/monolith`.
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다.

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 14개와 8.1절 인증 단계 결정 3개(D15~D17)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 권고와 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D1 | 제품명("Airbnb", "에어비앤비" 상표 사용 금지) | 랜딩(SY-06-024) 착수 전 |
| D2 | 결제 시점과 방식(권고: MVP 결제 없음, Phase 2 Toss) | Phase 2 착수 전(SY-06-038) |
| D3 | 수익 모델(서비스 수수료 / 호스트 구독 / 둘 다) | Phase 2 결제와 함께 |
| D4 | 취소·환불 규정, 호스트 취소 패널티 | Phase 2 결제와 함께 |
| D5 | 베타 AI 크레딧 보충 | AI 채팅 경로(SY-06-025) 전 |
| D6 | 지도 제공자(Google 유지 / 카카오 / 네이버) | 지도 어댑터(SY-06-013) 전. 결정 전에는 어댑터 뒤 Google 구현 |
| D7 | 숙박업 신고번호 입력(권고: 선택 입력 + 확인 체크) | 공개 베타(W5) 전. 컬럼은 `0003_stay_*.sql` |
| D8 | 즉시 예약 기본값(권고: 꺼짐) | 예약 흐름(SY-06-016) 전 |
| D9 | 확정 게스트의 체크인 안내 AI 질의(권고: MVP 제외) | 숙소 색인(SY-06-026) 전 |
| D10 | 리뷰 요약 제공자(권고: 오픈소스 강제) | 리뷰 요약(SY-06-029) 전 |
| D11 | 호스트-게스트 메시지(권고: Phase 2) | 착수 전 |
| D12 | DB 구조(권고: 모놀리스 `public`) | 착수 전(SY-06-001). 이 문서는 단독 `public` 기준 |
| D13 | 게스트 AI 비용 부담(권고: 게스트 본인 지갑) | AI 채팅 경로(SY-06-025) 전 |
| D14 | 디자인 레퍼런스 사용 범위(원본 Airbnb 모방 화면 금지) | 디자인 레퍼런스(SY-06-007) 전 |
| D15 | 카카오 이메일 정책(권장: 비즈 앱 + `account_email` 필수) | G2 판정 전(SY-06-040 착수 전) |
| D16 | 네이버 경로(`supabase_custom` 또는 브리지) | SY-06-041 첫 단계 스파이크 결과 |
| D17 | 이메일+비밀번호 가입 유지(권고: 유지) | G1 판정 전(SY-06-039 착수 전) |

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 SY-06-001~045, 모두 45개입니다. 그중 SY-06-009는 사람이 하는 디자인 비주얼 검토이고, SY-06-038(결제 E2E)은 Phase 2입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 004, 005, 006, 007, 045 | 없음 | 로컬 DB와 타입, 빈 web·api 골격, 저장소 위생, 디자인 레퍼런스, 정적 데이터 |
| W1 | 003, 010, 012, 013, 030, 035 | W0 | Mock 로그인, 숙소 서버 계층, 사진 업로드, 지도 어댑터, RLS 회귀 테스트, AI compliance |
| W1-D | 008 → 009(사람) | 004, 007 | 디자인 토큰·컴포넌트, 비주얼 승인. 화면 작업의 진입 조건 |
| W2 | 011, 014, 015, 016, 025, 026 | W1, W1-D | 등록 마법사, 검색, 상세, 예약, AI 채팅 경로, 숙소 색인 |
| W3 | 017, 018, 020, 027, 028, 032, 033, 034, 036 | W2 | 호스트 예약함, 내 여행, 리뷰, 도우미 위젯, 소개 작성, 위키, 음성, 온보딩, 정산 |
| W4 | 002, 019, 021, 022, 023, 024, 029, 031, 043 | W3 | 모듈러 조각, 달력, 찜, 크론·메일, SEO, 랜딩·3D, 리뷰 요약, 자연어 검색, 운영 스크립트 |
| W5 | 039(맨 앞) → 037, 042, 044 | W4 + G1 | Google 로그인, E2E, 성능·접근성 점검 → **공개 베타** |
| W6 | 040, 041 | G2 | 카카오·네이버 로그인 |
| W7 | 038 | Phase 2 결제 착수(D2) | 결제 E2E |

W3·W4는 작업이 9개라 동시 5개 정도로 나눠 진행합니다(06장 3절).

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | 권한 경계, RLS, 예약 무결성, AI 경로, 인증 B·C2(002, 003, 010, 016, 025, 028, 030, 039, 041) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`·`nextjs-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 기능 구현, API 연동, 잡, 그래프, 테스트 설계 | `claude-main`(Opus)이 설계 → `nextjs-expert`·`fastapi-expert`(Sonnet)가 구현 |
| Sonnet | UI, 메인페이지, 컴포넌트, 문서·설정 | `nextjs-expert`(Sonnet), 문서는 오케스트레이터 |
| Haiku | 정적 데이터, SEO 파일, 운영 스크립트(023, 043, 045) | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토(SY-06-009) | 사용자 |

모델 비율(06장 4절, 사람 작업 제외 44개): Fable 9(20%), Opus 19(43%), Sonnet 13(30%), Haiku 3(7%). 규모 가중 23/43/30/4%. 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(Fable), `review-expert`(Sonnet)가 병렬로 맡습니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/SY-06-001-db-apply/
├── task.md      baseline에 산출물 ID, workers_approved, write_scope
├── context.md
└── log.md       [APPROVAL], [DECISION] 기록
```

`task.md`의 baseline과 범위 예시는 다음과 같습니다.

```yaml
baseline:
  - id: DOC-DES-004
    path: docs/file/03-설계/05_DATA_MODEL.md        # 테이블, RLS, 9장 검증
  - id: DOC-CORE-004
    path: docs/file/03-설계/공용코어/DB_CONVENTIONS.md
  - id: DOC-MGT-002
    path: docs/file/01-관리/06_AGENT_PLAN.md        # SY-06-001 수용 기준
workers_approved: [claude-main, supabase-expert, claude-reviewer, plan-challenger, review-expert]
write_scope:
  - supabase/**
  - "!supabase/tests/**"
  - apps/web/src/types/supabase.ts
```

### 9.4 요청 프롬프트 예시 (W0 DB 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/airbnb/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
SY-06-001: supabase/migrations 의 core_lite(SECTION 3·4·6-C·7·8·11·12 포함)와 stay_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다(단독 프로젝트, public 스키마). 완료 조건 = ① supabase db reset 오류 0건
② btree_gist·vector 확장과 listings·reservations 등 도메인 테이블 7개 생성 확인
③ ai_routing_settings(org null, app stay) 11행 ④ plans: free 활성(가입 크레딧 100), host_plus 비활성
⑤ supabase gen types 결과를 apps/web/src/types/supabase.ts 에 저장 ⑥ 06_AGENT_PLAN.md 의 SY-06-001 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/(tests/ 제외), apps/web/src/types/supabase.ts

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

- **공개 베타 조건**: W5까지 완료, Stage B Google 로그인(SY-06-039) B-1~B-6 충족, E2E(SY-06-037) 6개 시나리오 통과, `06_AGENT_PLAN.md` 7절 완료 정의 충족.
- **사용자 세션 규칙**: 사용자 요청은 요청 단위 `@supabase/ssr` 클라이언트로만 DB를 부릅니다. service_role(`src/lib/supabase/admin.ts`)은 잡·크론·운영 스크립트만 import합니다(06장 1절). 원본의 `axios.defaults` 전역 쿠키(리뷰 #5) 같은 서버 전역 상태를 만들지 않습니다.
- **예약 경로 격리**: AI·음성 작업은 예약·검색 서버 함수(`src/server/reservations/`, `listings/`)를 수정하지 않습니다. `write_scope`에 반영하세요.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (airbnb)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2·6절

| 구성 | airbnb 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/`(llm 라우터, rag, wiki, graphs, compliance)와 잡 워커 `apps/api/app/jobs/`. 예약·검색 경로에는 들어오지 않음 | SY-06-005 |
| 모델 라우팅 | seed `ai_routing_settings` 11행. `chat`은 auto(Claude → ChatGPT → Gemini → 오픈소스), `stay.search_parse`·위키는 오픈소스 우선, `stay.listing_assist`는 상용 우선, **`stay.review_summary`와 `dify.aux`는 오픈소스 강제**, `stay.knowledge` 임베딩은 오픈소스 기본 | SY-06-001, 025 |
| 국외 이전 동의 | 온보딩 "AI 처리 방식"(`set_ai_cross_border_ack`). 동의 전에는 국외 제공자를 쓰지 않음 | SY-06-034 |
| AI 채팅 경로 | Next.js `/api/ai/chat`: 세션, 대화 매핑, 크레딧 선차감·정산(게스트 본인 지갑, D13), EdDSA 서명 토큰, Dify 장애 시 `/tools/answer-direct` | SY-06-025, 036 |
| 숙소 색인 | 게시·수정 시 `listing-<listing_id>` 컬렉션 재색인. **`listing_private`(정확한 주소·체크인 안내)는 넣지 않음** | SY-06-026 |
| 도우미 위젯 | 숙소 상세 오른쪽 시트, 스트리밍, 출처, "AI가 생성한 답변" 표시 | SY-06-027 |
| LangGraph | `stay.listing_assist`: load → draft → compliance(고른 안만 저장). `stay.review_summary`: load → summarize → compliance(하루 1회 잡) | SY-06-028, 029 |
| 자연어 검색 | `stay.search_parse`: 문장 → 검색 필터 JSON → 사용자 확인 후 검색 | SY-06-031 |
| 호스트 위키 | 하우스 매뉴얼 → 위키 draft → 호스트 검수·발행. 현관 비밀번호·연락처 가리기 | SY-06-032 |
| 음성 | 도우미 음성 대화(30초, 원본 미저장, 첫 사용 고지) | SY-06-033 |
| compliance·평가셋 | 금지 문구(안전·합법 단정, 최저가, 차별), 연락처·URL·비밀번호 가리기, 평가셋 30문항×3기능 | SY-06-035 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 음성·LLM 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 오픈소스 서버가 준비되기 전에는 `chat`·`listing_assist`만 상용(국외 동의 테스트 계정)으로 개발하고, 리뷰 요약은 목 제공자로 개발합니다. 게스트 리뷰 원문을 상용으로 시험하지 않습니다.
3. 준비되면 기본값으로 되돌립니다.

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보(호스트 주소 포함)는 위키에 쓰지 않습니다.
- 제품의 "호스트 위키"(DB의 `wiki_pages`, SY-06-032)와는 다른 것입니다. 이 절은 개발용 위키입니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.3 시각 레퍼런스 → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | `_design-guide/REFERENCES.md` 안의 레퍼런스만, 원본(Airbnb 모방) 요소 미사용 확인표(D14) | SY-06-007 |
| 2. 가진 것 위에서 시작 | 03장 토큰 플랜 + Tailwind CSS v4 `@theme` → 토큰 파일, 기본 컴포넌트(Button, Input, DatePicker, Counter, Dialog, Sheet) | SY-06-008 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다 | SY-06-009(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드에 맞춤 | SY-06-008 마무리 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다. "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 화면 작업(W2 이후)은 SY-06-009 승인 뒤에 시작합니다.
- 원본의 빨간 브랜드 색(`styles/palette.ts`), 로고 형태, 카드 배치를 옮기지 않습니다.

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.5)

| 기기 | 구성 |
|---|---|
| PC(1280px 이상), 태블릿(768~1279px) | 풀 3D: 접힌 종이 지도가 펼쳐지며 집 모형 핀이 솟는 장면 |
| 모바일(767px 이하) | 가벼운 3D: 핀 3개 단순 장면 |
| 대체 | WebGL 미지원·저사양·`prefers-reduced-motion`이면 정지 이미지 |

- 검색 바(위치·날짜·인원)는 HTML로 3D 위에 겹치고 3D보다 먼저 보입니다. 장면 속 숙소·가격은 시연용이며 "시연 화면입니다"를 표시합니다.
- 성능 예산: PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초 이하(`HERO_3D.md:32-41`).
- 카피는 01장 6절 금지 문구(가짜 숙소 수, 최저가 보장, 타사 상표)를 통과해야 합니다.
- 확인: 스크린샷 3종(PC·태블릿·모바일), 고문(Fable) 디자인 검토(SY-06-024).

### 13.3 시각 레퍼런스 (정본: `docs/file/03-설계/디자인/REFERENCES.md`, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

| 화면 | 주 레퍼런스 | 가져오는 방식 |
|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작 | 기억에 남는 요소 하나만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면(검색, 상세, 호스트 화면) | Dribbble 샷 | 정보 배치와 밀도를 가져옵니다 |

- 이 제품이 고른 레퍼런스 표는 `03_SCREENS_UX.md` 4.1절에 있습니다. URL은 그 표와 `REFERENCES.md`에 있는 것만 씁니다. 새 레퍼런스가 필요하면 URL을 직접 열어 확인하고 `REFERENCES.md`에 먼저 추가합니다.
- 영감용이지 복제용이 아닙니다. 특히 숙소 공유 서비스는 기존 상용 서비스의 화면과 닮기 쉬우므로 구조(정보 배치, 위계)만 참고합니다.
- 화면·랜딩 task의 baseline:

```yaml
baseline:
  - id: DOC-DES-002
    path: docs/file/03-설계/03_SCREENS_UX.md   # 4.1절 레퍼런스 표, 4.2 브리프, 4.3 토큰 플랜
  - id: DOC-DSN-005
    path: docs/file/03-설계/디자인/REFERENCES.md
  - id: DOC-DSN-001
    path: docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md
```

## 14. 원본 이식

정본: `docs/file/04-구현/07_SOURCE_MIGRATION.md`

- 원본(`D:\WorkSpace\CloneCoding\Airbnb_CloneCoding`)은 동작하는 코드지만 **서버 코드는 복사하지 않습니다.** 쓰기 API 무인증(리뷰 #1~#4), 전역 쿠키(#5), RLS 비활성(#6)이 구조 문제라서 공용 코어 위에서 다시 씁니다.
- 가져오는 것은 둘뿐입니다. ① 정적 데이터(건물 유형, 침대 유형, 편의시설·공용공간 목록, 원본 `lib/staticData.ts`)를 `apps/web/src/lib/static-data.ts`로(SY-06-045, `amentities` 오타 수정) ② 등록 13단계의 순서와 필드 구성(SY-06-011이 화면을 새로 만든다).
- 원본 자체 JWT·refresh·OAuth 콜백, S3 업로드, Redux slice, styled-components, `lib/data` JSON 저장소, 원본 이미지(`public/static/image/*.jpg`)는 옮기지 않습니다(07장 3·4절).
- 카카오·네이버 응답 구조(네이버 `response` 중첩, state 필수)는 C1·C2 작업의 참고 지식으로만 씁니다(07장 2절).
- 리뷰 "높음" 7건의 차단 설계는 `02_ARCHITECTURE.md` 6절(#5, #7)과 `05_DATA_MODEL.md` 7절(#1~#4, #6)에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | `apps/web/src/core/`(조직, 크레딧, AI 게이트, 음성 어댑터), `apps/api/app/core/`, `apps/api/app/ai/`. 인증 단계 모듈은 `apps/web/src/lib/auth/`에 두고 그 밖에서 `AUTH_MODE`를 읽지 않습니다 |
| Supabase 클라이언트 | 요청 단위 `src/lib/supabase/`(SY-06-004 소유)만. service_role은 `src/lib/supabase/admin.ts` 하나 |
| 지도 | `src/lib/maps/` 어댑터 인터페이스(D6 대비). 화면은 어댑터만 import |
| 3D 키트 | 3D 공통 요소(로더, 재질, 대체 이미지, 성능 측정)는 공용 패키지로 분리 가능하게 만듭니다 |
| 남은 코어 과제 | AUTH_ROADMAP 8장 행 추가(R-1), `stay`/2700·`SY` 등록과 core `btree_gist`(R-2), 지리 검색 헬퍼(R-3), 공용모듈 community·search 검토(R-4), 네이버 브리지 시 6-A·staged 0010(R-5). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- P0 작업은 대응 테스트(SY-06-030 RLS, SY-06-037 E2E, SY-06-035 평가셋)가 통과해야 완료입니다.
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다. 비밀 스캔 CI(SY-06-006)도 통과해야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| 이중 예약 | 애플리케이션 락이 아니라 DB 배타 제약(`reservations_no_overlap`)이 판정합니다. SY-06-016 동시 요청 100건 중 성공 1건 테스트를 지웁니다·우회하지 않습니다 |
| 호스트 주소 노출 | 정확한 주소·좌표·체크인 안내는 `listing_private`에만 둡니다. 공개 RPC·AI 색인·로그에 넣지 않습니다. 새 응답 필드를 추가할 때 RLS 스모크에 "상세주소 문자열 0건" 검사를 함께 넣습니다 |
| 숙박업 규제 | 신고 없는 내국인 도시민박은 불법일 수 있습니다(01장 6절, 미확인). 플랫폼이 합법 여부를 검증했다고 표시하지 않고, D7 결정을 공개 베타 전에 확정합니다 |
| 결제 없는 예약 | 베타 예약은 금전 이동이 없습니다. "결제 기능 준비 중" 고지를 빼지 않고, 호스트와 게스트가 외부 송금으로 거래하도록 유도하는 문구를 만들지 않습니다 |
| 지도 비용·약관 | Google Maps 무료 한도와 저장 제한은 미확인입니다. 서버 키 분리, 지오코딩 결과는 호스트가 확정한 좌표만 저장, 타일 캐시 금지 |
| Supabase 프로젝트 비용 | 제품마다 프로젝트 1개입니다. 계정 공유가 필요해지면 모듈러(SY-06-002 조각)로 전환합니다 |
| AI·음성 비용 | 크레딧 선차감과 정산, 리뷰 요약·색인은 플랫폼 예산이므로 숙소당 하루 1회 제한을 지킵니다. 원가는 `ai_usage`로 확인해 단가(제안값)와 가입 크레딧 100(D5)을 확정합니다 |
| 비밀키 | `.env*`는 커밋하지 않습니다(SY-06-006). 원본 저장소의 키는 재발급합니다. 서명 개인키는 Next.js 서버에만, LLM 키는 FastAPI에만 둡니다 |
| Mock 로그인 노출 | `AUTH_MODE=mock`이 배포에 들어가면 개발 계정 로그인이 열립니다. `/api/dev/login` 배포 404, 루프백 판정, CI 빌드 검사(SY-06-003)로 막고 단계 전환은 사람이 G1·G2를 판정한 뒤에만 합니다 |
| 원본 디자인 모방 | 상표·트레이드 드레스 위험. D14와 13.3절 대조 검토 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 바뀐 기획서를 platform에서 다시 묶으려면 `build_root.py airbnb`를 실행합니다 |

## 18. 체크리스트

- [ ] (지금만) build_root.py에 airbnb 등록, 묶음 생성, setup 스크립트 복사 — 또는 부록 A 손 작업
- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node·pnpm, uv, Supabase CLI, Docker, Playwright)
- [ ] 원본 저장소 키 재발급(07장 5절)
- [ ] setup 스크립트 dry-run → 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 음성·LLM 서버(또는 임시로 chat·listing_assist만 상용)
- [ ] `supabase start` → `supabase db reset` 성공, 7절 확인 쿼리 4개(라우팅 11행 등)
- [ ] 결정 D1~D17 확정(해당 시점 전), 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] Stage A: `seed-users.mjs --app stay` 실행, `/login` 개발용 패널로 `host`·`guest` 로그인 확인(19.2)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] W1~W4 진행 → G1 판정(19.3) → W5(SY-06-039 먼저) → E2E·성능·접근성 → 공개 베타
- [ ] 공개 베타 2주 뒤 G2 판정(19.5) → SY-06-040·041(19.6, 19.7)

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009), 제품 적용은 `01_PRD.md` SY-F-001·8.1절, `02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `06_AGENT_PLAN.md` 8절, `CLAUDE.md` "인증 단계 규칙" 절. 외부 콘솔 설정 절차와 공용 모듈 `@nomad/core-auth`는 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`를 따릅니다.

이 제품은 AUTH_ROADMAP 8장 매트릭스에 아직 행이 없습니다. 06장 6절 R-1로 행 추가를 요청합니다(01장 8.1절 문안).

### 19.1 단계 요약

| 단계 | 로그인 | 언제 | 끝나는 조건 | 작업 |
|---|---|---|---|---|
| A | 로컬 Supabase 시드 계정 Mock 로그인(`/login` 개발용 패널, 상단 `MOCK AUTH · 로컬 전용` 배지) | W1(SY-06-003)부터 MVP 기능이 모두 동작할 때까지 | G1(19.3) | SY-06-003 |
| B | Google + 이메일(가입·비밀번호 재설정) | G1 통과 후, 공개 베타 전(W5 맨 앞) | G2(19.5) | SY-06-039(P0, Fable, M) |
| C1 | 카카오(Supabase 기본 제공자) | G2 통과 후(W6) | `AUTH_ROADMAP.md` 7.1.3절 | SY-06-040(P1, Opus, S) |
| C2 | 네이버(스파이크 → `custom:naver` 또는 서버 브리지) | G2 통과 후(W6, 040과 병렬) | `AUTH_ROADMAP.md` 7.2.4절 | SY-06-041(P1, Fable, M) |

- 세션은 모든 단계에서 실제 Supabase JWT입니다. 원본의 자체 JWT(Access 15분 + Refresh 7일 쿠키)와 `refresh_tokens` 테이블은 쓰지 않습니다(07장 6절).
- 단계 분기(`AUTH_MODE`, 제공자 목록)는 `src/lib/auth/`, 로그인 화면, 콜백, `/api/dev/login`에만 둡니다.
- **airbnb 특이점: 비로그인 방문자도 검색·상세·리뷰 목록·예약 불가 달력을 봅니다.** 공개 RPC 4개로 동작하며 단계와 무관합니다. 예약·찜·도우미 버튼을 누르면 로그인 화면으로 보낸 뒤 원래 위치로 돌아옵니다(`next`는 내부 경로만 허용).
- 게스트와 호스트는 같은 계정입니다. 숙소를 만들면 호스트 화면이 열립니다(역할 컬럼 없음).

### 19.2 Stage A 로컬 실행 순서

| 순서 | 명령·동작 | 설명 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase 기동(7절) |
| 2 | `supabase db reset` | 마이그레이션과 `seed.sql` 적용. `supabase/config.toml`의 Google·카카오 제공자는 `enabled = false` 그대로 |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<로컬 전용 임의 값>` | 서버 변수. `NEXT_PUBLIC_SUPABASE_URL`은 `http://127.0.0.1:54321`(루프백이 아니면 Mock이 꺼지고 기동 실패) |
| 4 | `node scripts/dev/seed-users.mjs --app stay` | 공통 페르소나 + 제품 훅(`seed-users.stay.mjs`: `host` 숙소 A 게시·B draft·날짜 차단, `guest` 확정 1건·요청 1건). 원격 호스트면 즉시 종료. 두 번 실행해도 크레딧이 두 번 지급되지 않습니다 |
| 5 | `pnpm dev` → `http://localhost:3000/login` | 개발용 패널에서 페르소나 버튼으로 로그인 |
| 6 | 비로그인 확인: 시크릿 창에서 `/search` → 숙소 A 1건, 상세에 상세주소 없음 | 공개 RPC(단계와 무관) |
| 7 | E2E: `pnpm test:e2e` | `globalSetup`이 페르소나마다 `/api/dev/login`을 불러 `storageState`를 저장 |

| 페르소나 | 기대 상태 | 주로 쓰는 곳 |
|---|---|---|
| `host` | 개인 조직 owner, free, 가입 크레딧 100, 숙소 A published(사진 5장, 날짜 차단 1건)·B draft | 호스트 예약함, 등록 마법사, 달력, 승인·취소 |
| `guest` | 개인 조직 owner, 숙소 A 확정 예약 1건(주소 보임)·요청 1건(주소 없음) | 내 여행, 예약, 리뷰(테스트가 날짜를 옮겨 completed) |
| `owner` | 개인 조직 owner, free, 가입 크레딧 100 | 빈 계정에서 시작하는 개발 |
| `outsider` | 다른 개인 조직 owner | 교차 테넌트 거부(host 숙소·예약 0행) |
| `viewer` | owner 조직 viewer | 숙소 수정 0행, `create_listing` 42501 |
| `admin`·`member`, `no_app`, `suspended`, `ops` | 코어 공통. `suspended`는 모든 게스트·호스트 RPC 42501 | 역할 분기, 403 |
| `pending` | 만들지 않음 | open 앱이라 승인 대기 없음 |

### 19.3 게이트 G1 체크리스트 (사람이 판정)

- [ ] `06_AGENT_PLAN.md` 2절 MVP P0 기능 작업 완료(039~041, 037·042·044 제외)
- [ ] 핵심 플로우(검색 → 예약 → 승인 → 리뷰)가 Mock 페르소나로 동작
- [ ] RLS 회귀(SY-06-030) 전 항목 통과, `outsider` 교차 테넌트 거부, 상세주소 비노출 확인
- [ ] 결제 E2E는 해당 없음(결제는 Phase 2, SY-06-038)
- [ ] 인증 모듈 밖 단계 분기 0건(SY-06-003 CI 검사)
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름은 D1 확정 이름, 개인정보처리방침·이용약관 URL), 웹 클라이언트 ID, 운영 Supabase 프로젝트
- [ ] 01장 D17(이메일 가입 유지) 확정
- [ ] 판정 결과를 task `log.md`에 `[DECISION] G1 통과`로 기록

### 19.4 Stage B 외부 설정 순서 (사람, `AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: External, 범위 `openid`, `email`, `profile`만 | 원본이 받던 생일 등 추가 범위는 받지 않음(01장 6절) |
| 2 | OAuth 클라이언트 ID(웹). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 원본의 `/api/auth/google/callback`이 아니라 Supabase 콜백 |
| 3 | Supabase → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `config.toml` `[auth.external.google]`에 `env(GOOGLE_CLIENT_ID)` | 키는 앱 env에 넣지 않음 |
| 4 | URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback` | 와일드카드 지양 |
| 5 | Vercel 운영 env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email`. `DEV_SEED_PASSWORD`는 넣지 않음 | B-4, B-6 |
| 6 | 동의 화면 "프로덕션" 게시 | 공개 베타 전 |
| 7 | Google 실로그인 수동 점검(데스크톱·모바일, 신규·기존 계정): 신규 계정 `entitled=true`·free·가입 크레딧 100, 재로그인 뒤에도 원장 1행. 비로그인 검색·상세가 전환 전과 같은지 확인 | 결과를 task `log.md`에(B-5) |

### 19.5 게이트 G2 체크리스트 (사람이 판정)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안)
- [ ] 신규 가입자 중 `entitled=false`로 남은 사용자 0(app `stay`)
- [ ] 카카오 디벨로퍼스 앱 생성, 01장 D15 확정
- [ ] 네이버 애플리케이션 등록, 검수 신청 자료 준비
- [ ] 판정 결과를 task `log.md`에 `[DECISION] G2 통과`로 기록

### 19.6 C1 카카오 설정 (사람, `AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id`, Client Secret 활성 |
| 2 | Redirect URI = Supabase 콜백(운영·로컬). 원본의 `KAKAO_REDIRECT_URI=/api/auth/kakao/callback`은 쓰지 않음 |
| 3 | 동의항목 `profile_nickname`, `profile_image`, (비즈 앱이면) `account_email` |
| 4 | Supabase → Providers → Kakao 사용. 이메일 없는 설정이면 예약 알림(SY-F-024)용 연락 이메일 입력을 구현 범위에 넣음 |
| 5 | SY-06-040 완료 후 운영 `AUTH_PROVIDERS`에 `kakao` 추가. C1-1: 새 카카오 계정 첫 로그인 뒤 B-1과 같은 결과 |

### 19.7 C2 네이버 스파이크와 검수 (`AUTH_ROADMAP.md` 7.2.2절)

| 순서 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 `custom:naver` 등록(네이버 authorize·token·`/v1/nid/me`) | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공 |
| 3 | `auth.users.email`이 채워지는지, 재로그인이 같은 사용자로 매칭되는지(네이버 응답은 `response` 아래 중첩, 원본 `naver/callback.ts:33` 참고) | 둘 다 참이면 `supabase_custom` |
| 4 | 실패하면 서버 브리지. 코어 SECTION 6-A 복원과 staged 0010 적용 요청(06장 R-5). 결과를 `[DECISION]`과 `NAVER_AUTH_PATH`에 기록(D16) | 기록 |
| 5 | 네이버 검수 신청. 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않음 | 검수 통과 |

로컬 Supabase CLI의 커스텀 제공자 지원은 미확인입니다. 지원하지 않으면 네이버는 스테이징 프로젝트에서 확인합니다.

### 19.8 단계 전환 요청 프롬프트 예시

```
D:/WorkSpace/DEV/airbnb/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
SY-06-039: 인증 Stage B(Google OAuth + 이메일 가입·로그인·비밀번호 재설정)를 구현한다.
근거 = docs/file/03-설계/공용코어/AUTH_ROADMAP.md 3.2절·5장, 02_ARCHITECTURE.md 9절, 03_SCREENS_UX.md 7절,
04_API.md 8절, 01_PRD.md SY-F-001·8.1절, 06_AGENT_PLAN.md 8절.
완료 조건 = ① AUTH_ROADMAP.md 5.3절 B-1~B-6 ② 새 Google 계정 첫 로그인 뒤 entitled=true, free, 가입 크레딧 100 1회
③ OAuth 첫 로그인은 /onboarding(약관 → AI 처리 방식) ④ Mock E2E 계속 녹색
⑤ 비로그인 검색·상세 E2E가 전환 전후 같은 결과 ⑥ /auth/callback 의 next 가 외부 URL 이면 무시
⑦ Google 실로그인 수동 점검표는 사람이 채우도록 log.md 에 빈 표로 남긴다.

[작업의 특성]
인증 경로 작업. 진입 조건 = log.md 의 [DECISION] G1 통과. 원격 Supabase 대시보드·Google 콘솔 설정은 하지 않고 사람 작업 목록으로 남긴다.
Mock 로그인 코드는 지우지 않는다(로컬·E2E용). 기능 코드에 AUTH_MODE 분기를 추가하지 않는다.
공개 검색·상세(app/(public)), 예약 서버 함수(src/server/reservations)는 수정하지 않는다.
작업 대상 경로: apps/web/src/app/(auth)/, apps/web/src/app/auth/callback/, supabase/config.toml 의 [auth.external.google] 절
apps/web/src/lib/auth/(003 소유), /onboarding(034 소유)은 1줄 요청으로 처리한다.

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert, supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

### 19.9 이 제품의 인증 작업 ID

| 단계 | 작업 | 우선순위 | 웨이브 | 모델 |
|---|---|---|---|---|
| A | SY-06-003(인증 모듈 경계, Mock 로그인, 시드 스크립트 + `host`·`guest` 훅, 가드, `finishLogin`) | P0 | W1 | Fable |
| B | SY-06-039(Google + 이메일, 콜백, 약관 온보딩) | P0 | W5 맨 앞(G1 후) | Fable |
| C1 | SY-06-040(카카오) | P1 | W6(G2 후) | Opus |
| C2 | SY-06-041(네이버 스파이크 → `custom:naver` 또는 브리지) | P1 | W6(G2 후) | Fable |
| 관련 | SY-06-030(RLS 회귀, `outsider`), SY-06-034(온보딩 AI 처리 방식), SY-06-037(Mock storageState E2E, G1 근거) | P0 | W1, W3, W5 | - |

## 부록 A. 스크립트 없이 손으로 할 때

setup 스크립트와 `airbnb-root/`가 아직 없으므로 지금은 이 절차로 시작합니다. 묶음이 생기면 4단계를 "airbnb-root 안의 내용물 붙여넣기" 한 줄로 바꿉니다.

| 동작 | Git Bash / Linux | Windows PowerShell |
|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/airbnb"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\airbnb" -Recurse` |
| 2 이동 | `cd "D:/WorkSpace/DEV/airbnb"` | `Set-Location "D:\WorkSpace\DEV\airbnb"` |
| 3 초기화 | `bash init-project.sh airbnb --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh airbnb --reset-git` |
| 4 산출물 복사 | 아래 표 | 아래 표 |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md` frontmatter에 `model: sonnet` 추가 | 같음(편집기 사용) |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` |

**4단계 산출물 복사(build_root.py 매핑을 손으로)**. `P=D:/WorkSpace/platform/docs`, `D=D:/WorkSpace/DEV/airbnb`라고 두면:

```bash
P=/d/WorkSpace/platform/docs; D=/d/WorkSpace/DEV/airbnb; A=$P/products/airbnb
mkdir -p "$D/docs/file/01-관리" "$D/docs/file/02-요구사항" "$D/docs/file/03-설계/공용코어" "$D/docs/file/03-설계/디자인" \
         "$D/docs/file/04-구현" "$D/docs/reference/reviews" "$D/supabase/migrations" "$D/supabase/tests"
cp "$A/README.md" "$A/06_AGENT_PLAN.md"                                   "$D/docs/file/01-관리/"
cp "$A/01_PRD.md"                                                         "$D/docs/file/02-요구사항/"
cp "$A/02_ARCHITECTURE.md" "$A/03_SCREENS_UX.md" "$A/04_API.md" "$A/05_DATA_MODEL.md"  "$D/docs/file/03-설계/"
cp "$A/CLAUDE.md" "$A/07_SOURCE_MIGRATION.md"                             "$D/docs/file/04-구현/"
for f in CORE_SPEC SHARED_MODULES SECURITY_BASELINE DB_CONVENTIONS DOC_TEMPLATE AI_ARCHITECTURE LLM_WIKI VOICE_ARCHITECTURE AUTH_ROADMAP; do
  cp "$P/products/_platform-core/$f.md" "$D/docs/file/03-설계/공용코어/"; done
for f in DESIGN_PRINCIPLES DESIGN_SYSTEM HERO_3D SKILLS REFERENCES DASHBOARD_PATTERNS LANDING_PERSUASION; do
  cp "$P/products/_design-guide/$f.md" "$D/docs/file/03-설계/디자인/"; done
cp "$P/products/00_MERGE_ANALYSIS.md"      "$D/docs/reference/"
cp "$P/reviews/Airbnb_CloneCoding.md"      "$D/docs/reference/reviews/"
cp "$A/supabase/monolith/migrations/0001_core_lite.sql"   "$D/supabase/migrations/20261013000001_core_lite.sql"
cp "$A/supabase/monolith/migrations/0002_stay_domain.sql" "$D/supabase/migrations/20261013000002_stay_domain.sql"
cp "$A/supabase/monolith/seed.sql"                        "$D/supabase/seed.sql"
cp "$A/supabase/monolith/tests/rls_smoke.mjs"             "$D/supabase/tests/"
```

| 손 작업의 한계 | 대응 |
|---|---|
| 문서 안 경로가 `docs/products/...` 그대로다(build_root.py의 경로 보정 없음) | 개발 에이전트에게 "문서 경로 `docs/products/airbnb/<파일>`은 `docs/file/` 아래 같은 파일"이라고 알려 주거나, 묶음을 만든 뒤 다시 붙인다 |
| `docs/file/_index.md` 등록부가 init의 빈 템플릿이다 | 첫 task(SY-06-001) 전에 `deliverable-first` 스킬로 등록부를 채우게 하거나 5.1절 표의 ID로 직접 채운다 |
| `docs/wiki/sources/*.md`, `infra/dify/README.md`가 없다 | 위키는 첫 웨이브 종료 때 ingest로 만들고, Dify 설명서는 SY-06-025가 만든다 |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버).
