# nomad-docs(NOMAD Docs) 개발 방법

작성일 2026-10-13, 2026-10-14 개정(인증 단계 19장, 확정 결정 22). 이 문서는 `D:\WorkSpace\platform\docs\products\`의 통합 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 nomad-docs 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안", 확인하지 못한 값은 "미확인"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\nomad-docs\setup-nomad-docs.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\nomad-docs\        platform에 남는 안내서, 도구, 재료
├── nomad-docs_develop.md        이 문서(개발 폴더로 옮기지 않음)
├── setup-nomad-docs.sh          설치 스크립트(Git Bash / Linux)
├── setup-nomad-docs.ps1         설치 스크립트(Windows PowerShell)
└── nomad-docs-root\             이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │
                │ setup 스크립트가 복사(nomad-docs-root 폴더 자체가 아니라 안의 내용물)
                ▼
D:\WorkSpace\DEV\nomad-docs\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  .claude\skills\llm-wiki\  ← nomad-docs-root에서 들어온 것(기존 폴더와 합쳐짐)
└── apps\  _shared\  _templates\  .claude\agents\  init-project.sh ...  ← 베이스에 원래 있던 것
```

| 단계 | 내용 | 절 |
|---|---|---|
| 준비 | 도구 설치, API 키 준비 | 2 |
| 1~2 | setup 스크립트 실행(베이스 복사, 초기화, 묶음 붙여넣기, docs/etc 삭제, 에이전트 모델 지정) | 3, 4 |
| 3 | 최종 트리 확인 | 5 |
| 4 | project-profile 작성 | 6 |
| 5 | 로컬 DB 기동, SQL 적용, RLS 스모크 | 7 |
| 6 | 착수 전 결정 확정, 산출물 승인 | 8 |
| 7 | 작업(65개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 원본 이식, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계: Mock → Google → 카카오·네이버(7·9·10절과 함께 봅니다) | 19 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | NOMAD Docs. 회사·거래처·프로젝트 정보를 한 번 입력하고 체크리스트에 체크하면 요구사항·화면·비용·계약 조항·검수 항목이 연결되어 실무 문서 묶음(견적서, 과업지시서, 요구사항정의서, WBS, 화면목록, 개발용역계약서, 검수확인서, 회의록 + 요구사항 추적표)을 한 번에 만들고, 버전·추적표·PDF/DOCX 내보내기까지 이어지는 문서 자동화 SaaS. 공개 베타, 가입 개방(`docs/file/01-관리/README.md:3-7`). 브랜드 최종명은 D-1 |
| 통합 원본 | 없음(신규 제품). 대신 이식 원천 6개: flora-publishing(설계 패턴 베이스), flora v1(코드), SellingDocs, FortuneDocs(원칙 1개), platform-docs 문서 표준, admin-suite ERP 스키마(`README.md:40-51`) |
| 모듈러 앱 id / 스키마 | `docs` / `docs` (통합 DB를 쓸 때. 기획의 1차 출시안은 모듈러, `README.md:72`) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(모놀리스, `public` 스키마). 기획서가 "베타를 독립 Supabase 프로젝트로 먼저 띄울 때" 쓰라고 둔 경로입니다(`README.md:74`). 앱 id는 그대로 `docs`, 함수 이름·시그니처는 모듈러와 같고 `SUPABASE_DB_SCHEMA=public`만 다릅니다. 이 경로에서는 admin-suite ERP 교차 스키마 연동(DC-06-055)이 불가능해 Phase 3 API 방식으로 바뀝니다 |
| 개발 근거 | `docs/file/`의 산출물 24개(등록부 `docs/file/_index.md`). 정본은 이 산출물입니다 |
| AI 범위 | RFP·참고 자료 프로젝트별 RAG(`docs.knowledge`), RFP → 체크리스트 답·요구사항 후보 추출(`docs.extract`), 문서 생성 그래프 `docs.generate`(템플릿 섹션은 결정적, 서술 섹션만 LLM), 선택 영역 다시 쓰기 `docs.assist`, 프로젝트 근거 Q&A 채팅(Dify `docs-chat`, 출처 표시), 프로젝트 용어 위키, 회의 녹음 → 회의록 + 요구사항 후보(핵심 음성 기능, STT·LLM 오픈소스 강제), 음성 대화 |
| AI 금지 범위 | 고위험 문서(MVP `dev_contract`)는 템플릿 생성만. AI가 계약 조항을 생성·수정·요약하지 않습니다(`docs/file/04-구현/CLAUDE.md` 2절) |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

이름 주의: `docs`는 앱 id(가입 `signup_app='docs'`, 잡 큐 `docs.*`, 크레딧 멱등 키 `consume:docs:*`)입니다. 개발 폴더의 `docs/`(산출물·위키 폴더)와는 관계가 없습니다.

## 2. 사전 준비

| 도구 | 용도 | 확인(Git Bash) | 확인(PowerShell) |
|---|---|---|---|
| Git for Windows(Git Bash) | 베이스의 `.sh` 스크립트 실행 | `bash --version` | `& "$env:ProgramFiles\Git\bin\bash.exe" --version` |
| git | 저장소 | `git --version` | `git --version` |
| jq | 베이스 게이트·무결성 점검 | `jq --version` | `jq --version` (설치: `winget install jqlang.jq`, 제안) |
| Python 3 | 베이스 self-test, setup의 모델 지정 단계 | `python --version` | `python --version` |
| Node.js 20 LTS, npm | `apps/web`(Next.js), 워커(Node 20 LTS, `02_ARCHITECTURE.md:17`), SQL 체커 | `node -v; npm -v` | 같음 |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI, LangGraph) | `uv --version` | 같음 |
| Supabase CLI | 로컬 DB(`supabase start`, `db reset`) | `supabase --version` | 같음 |
| Docker Desktop | Supabase 로컬, Dify, 오픈소스 LLM·임베딩·음성 서버, 공용 렌더 서비스 | `docker version` | 같음 |
| psql(제안) | RLS 스모크 수동 실행(7.3절) | `psql --version` | 같음 |
| NVIDIA GPU + NVIDIA Container Toolkit(WSL2) | 오픈소스 LLM·임베딩·음성 서버를 직접 띄울 때만 | `nvidia-smi` | 같음 |

**Windows 주의(베이스 `INSTALL.md` §2)**
- `python3`가 Microsoft Store 스텁일 수 있습니다. setup 스크립트는 실제로 실행되는 `python3` 또는 `python`을 골라 씁니다.
- `bash.exe`가 WSL 실행기(`System32`, `WindowsApps`)일 수 있습니다. PowerShell 스크립트는 Git Bash(`Program Files\Git\bin\bash.exe`)만 씁니다.

**API 키**: 서버 환경변수로만 둡니다(`docs/file/03-설계/02_ARCHITECTURE.md` 8절). 브라우저·Vercel·워커에는 LLM 키를 두지 않습니다.
- Anthropic, OpenAI, Google(ai-service `apps/api` 전용)
- ElevenLabs(채팅 음성 STT·TTS, web 서버 전용. 회의 녹음에는 쓰지 않음)
- Toss Payments(크레딧팩, Pro 구독)
- Supabase
- 서명 토큰 키쌍 `AI_TOKEN_PRIVATE_KEY`(Ed25519, web 서버 전용)
- HubSpot(Phase 2. 앱 등록 절차·스코프·서명 방식 미확인, `04_API.md:220-228`)

이 제품에는 OpenRouter·Voyage 키가 없습니다(`02_ARCHITECTURE.md:399`).

공용 인프라 설치 문서는 다음과 같습니다.

| 인프라 | 문서 |
|---|---|
| Dify(공용 1개) | `D:\WorkSpace\platform\docs\develop\_shared\dify\README.md` |
| 오픈소스 음성 서버 | `...\_shared\voice\README.md` |
| 오픈소스 LLM 서버(vLLM)·임베딩과 상용 키 | `...\_shared\llm\README.md` |
| PDF 렌더 서비스(`services/render-weasyprint`) | flora-publishing 소유 공용 서비스. `D:\WorkSpace\platform\docs\develop\flora-publishing\flora-publishing_develop.md` 15절. nomad-docs는 소비자입니다(15절) |

## 3. 1단계: 베이스 복사와 초기화 (setup 스크립트가 처리)

setup 스크립트는 다음 6단계를 순서대로 처리합니다. 대상 폴더가 이미 있으면 중단하고, 베이스 원본은 읽기만 합니다.

| 순서 | 동작 |
|---|---|
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\nomad-docs`로 복사 |
| 2 | **복사본 안의** `init-project.sh nomad-docs --reset-git` 실행 |
| 3 | `nomad-docs-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
| 4 | 복사본의 `docs/etc`(베이스 설명서 PDF 13MB) 삭제 |
| 5 | 에이전트 모델 지정: `plan-challenger`를 `claude-fable-5-1`(고문), `nextjs-expert`·`fastapi-expert`·`supabase-expert`를 `sonnet`(부)으로(9.2절) |
| 6 | 무결성 점검(`_shared/check-invariants.sh`) |

`init-project.sh`가 하는 일(베이스 `init-project.sh:1-84`)은 4가지입니다.
1. `_shared/project-profile.md`의 이름과 target_repo를 채웁니다.
2. 산출물 등록부 `docs/file/_index.md`를 만듭니다.
3. `--reset-git`이면 템플릿 git 이력을 끊고 `git init`을 합니다.
4. 무결성 점검을 합니다.

파일 복사, 커밋, 의존성 설치, 스캐폴딩은 하지 않습니다. setup 스크립트도 커밋, 원격 푸시, 의존성 설치, 원격 DB 변경을 하지 않습니다(`setup-nomad-docs.sh:14`).

**주의: 반드시 복사본 안의 스크립트를 실행해야 합니다.** 스크립트는 자기 파일이 있는 폴더를 초기화합니다(`init-project.sh:10`, `ROOT=스크립트 위치`). 베이스 원본 폴더의 스크립트를 실행하면 원본이 초기화되고, `--reset-git`이면 원본의 git 이력이 지워집니다.

**고문 모델 바꾸기**: 스크립트 5단계는 고문(`plan-challenger`)을 Fable(`claude-fable-5-1`)로 지정합니다. 고문을 Opus로 쓰려면 setup이 끝난 뒤 복사본의 `.claude/agents/plan-challenger.md` frontmatter를 `model: opus`(베이스 원래 값)로 되돌리면 됩니다. 이 문서의 "고문(Fable)"은 그 경우 "고문(Opus)"으로 읽습니다. claude-main·claude-reviewer의 모델 핀은 바꾸지 않습니다(6절).

## 4. 2단계: 묶음 붙여넣기 (setup 스크립트가 처리)

- `nomad-docs-root` 폴더 자체가 아니라 **그 안의 내용물**이 개발 폴더 루트에 들어갑니다. `docs`와 `supabase`는 베이스의 같은 폴더와 합쳐집니다.
- 덮어쓰는 파일은 `docs/file/_index.md` 하나뿐입니다. init이 만든 빈 등록부를 완성본으로 교체합니다.
- 손으로 하는 방법은 부록 A에 있습니다.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/nomad-docs/README.md` | `docs/file/01-관리/README.md` | DOC-MGT-001 | 제품 개요 |
| `docs/products/nomad-docs/06_AGENT_PLAN.md` | `docs/file/01-관리/06_AGENT_PLAN.md` | DOC-MGT-002 | 작업 계획(WBS) |
| `docs/products/nomad-docs/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/nomad-docs/02_ARCHITECTURE.md` | `docs/file/03-설계/02_ARCHITECTURE.md` | DOC-DES-001 | 아키텍처설계서 |
| `docs/products/nomad-docs/03_SCREENS_UX.md` | `docs/file/03-설계/03_SCREENS_UX.md` | DOC-DES-002 | 화면설계서 |
| `docs/products/nomad-docs/04_API.md` | `docs/file/03-설계/04_API.md` | DOC-DES-003 | 인터페이스설계서 |
| `docs/products/nomad-docs/05_DATA_MODEL.md` | `docs/file/03-설계/05_DATA_MODEL.md` | DOC-DES-004 | 데이터설계서 |
| `docs/products/_platform-core/` 9개(CORE_SPEC, SHARED_MODULES, SECURITY_BASELINE, DB_CONVENTIONS, DOC_TEMPLATE, AI_ARCHITECTURE, LLM_WIKI, VOICE_ARCHITECTURE, AUTH_ROADMAP) | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(DOC-CORE-009 `AUTH_ROADMAP.md`는 2026-10-14 인증 단계, 19장) |
| `docs/products/_design-guide/` 5개(DESIGN_PRINCIPLES, DESIGN_SYSTEM, HERO_3D, SKILLS, REFERENCES) | `docs/file/03-설계/디자인/` | DOC-DSN-001~005 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md 초기 템플릿 | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 디자인 토큰, 컴포넌트 명세 |
| `docs/products/_design-guide/DASHBOARD_PATTERNS.md` | `docs/file/03-설계/디자인/` | DOC-DSN-008 | 앱 화면 구조 패턴(A~O). `03_SCREENS_UX.md` 화면 표의 `패턴` 열과 화면 작업 지시(`DESIGN_SYSTEM.md` 10장)가 이 코드를 쓴다 |
| `docs/products/nomad-docs/CLAUDE.md` | `docs/file/04-구현/CLAUDE.md` | DOC-IMP-001 | 개발지침 |
| `docs/products/nomad-docs/07_SOURCE_MIGRATION.md` | `docs/file/04-구현/07_SOURCE_MIGRATION.md` | DOC-IMP-002 | 원본 이식 계획 |
| `docs/products/00_MERGE_ANALYSIS.md` | `docs/reference/00_MERGE_ANALYSIS.md` | 참고 | 통합 분석, 확정 결정 |
| `docs/reviews/SellingDocs.md`, `flora.md`, `FortuneDocs.md` | `docs/reference/reviews/` | 참고 | 이식 원천 리뷰 3건 |
| `docs/products/nomad-docs/supabase/monolith/migrations/0001_core_lite.sql` | `supabase/migrations/20261013000001_core_lite.sql` | - | DB(코어 축소판, SECTION 9 affiliate만 제거) |
| `docs/products/nomad-docs/supabase/monolith/migrations/0002_nomad_docs_domain.sql` | `supabase/migrations/20261013000002_nomad_docs_domain.sql` | - | DB(도메인, 테이블 28·뷰 1·함수 34, 카탈로그 seed 포함) |
| `docs/products/nomad-docs/supabase/monolith/seed.sql` | `supabase/seed.sql` | - | DB(apps 1행, 플랜 free/pro/team, 크레딧팩 3종, AI 라우팅 13행) |
| `docs/products/nomad-docs/supabase/monolith/tests/rls_smoke.sql` | `supabase/tests/rls_smoke.sql` | - | RLS·권한 회귀 105항목 |
| `docs/develop/_shared/llm-wiki/` | `docs/wiki/WIKI_SCHEMA.md`, `.claude/skills/llm-wiki/SKILL.md` | - | 개발 위키 |
| (생성) 개발 위키 초기 페이지 | `docs/wiki/index.md`, `log.md`, `sources/*.md` | - | 산출물 요약 24개 |
| (생성) Dify 앱 설명서 | `infra/dify/README.md` | - | 채팅 앱 설정 |

SQL 4개는 기획 폴더의 파일과 바이트 단위로 같습니다(2026-10-13 확인). 모듈러 정본 `docs/products/_supabase-modular/migrations/2300_docs.sql`은 묶음에 넣지 않았습니다(7.4절).

**문서 경로 보정**
- 복사본 안의 문서 경로는 새 위치로 바꿨습니다. 원본 기획서는 수정하지 않았습니다.
- 복사하지 않은 파일(예: `_supabase-modular/migrations/2300_docs.sql`, `MONOLITH_CORE_LITE.sql`, flora-publishing 문서)을 가리키는 참조는 `D:/WorkSpace/platform/...` 절대경로로 바꿔 계속 열 수 있게 했습니다. 줄 번호는 그대로입니다.
- 마지막 검사 결과(2026-10-13, `build_root.py`의 검사 규칙과 같은 정규식): 문서 경로 544개, 묶음 안 누락 0, 절대경로 누락 0.
- 생성 도구 `D:\WorkSpace\platform\docs\develop\_shared\tools\build_root.py`의 제품 등록 표(`REVIEWS`, `APP_ID`)에는 아직 `nomad-docs`가 없습니다(2026-10-13 확인). 기획서가 바뀌어 묶음을 다시 만들려면 등록 행(`'nomad-docs': ['SellingDocs.md', 'flora.md', 'FortuneDocs.md']`, 앱 id `'docs'`)을 먼저 추가해야 합니다(제안).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\nomad-docs\`)

`[베이스]`는 베이스에서 온 것, `[묶음]`은 nomad-docs-root에서 온 것입니다.

```
D:\WorkSpace\DEV\nomad-docs\
├── CLAUDE.md                         [베이스] 오케스트레이터 운영 규칙(덮어쓰지 않음)
├── init-project.sh                   [베이스] 초기화 스크립트(1회 실행 완료)
├── INSTALL.md  README.md  요구사항_TASK_전환_Format.md   [베이스]
├── .claude\
│   ├── agents\                       [베이스] claude-main(Opus), claude-reviewer(Sonnet), plan-challenger(→Fable, Opus로 교체 가능),
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
│   ├── web\                          [베이스] Next.js(코드 없음, W0~W1에서 스캐폴딩)
│   └── api\                          [베이스] FastAPI(코드 없음, W0~W1에서 스캐폴딩)
│                                     (워커 apps/nomad-docs-worker는 apps/worker로, tpl·int는 packages/ 아래에 두는 것을 제안. 아래 표)
├── docs\
│   ├── ai\md2pdf\                    [베이스] 문서 PDF 변환 도구
│   ├── reference\
│   │   ├── reference-site.md  Agents-CLAUDE.md   [베이스]
│   │   ├── 00_MERGE_ANALYSIS.md      [묶음]
│   │   └── reviews\SellingDocs.md, flora.md, FortuneDocs.md   [묶음]
│   ├── file\
│   │   ├── _index.md                 [묶음] 산출물 등록부 완성본(24개)
│   │   ├── README.md  _sources\      [베이스]
│   │   ├── 01-관리\README.md, 06_AGENT_PLAN.md          [묶음]
│   │   ├── 02-요구사항\01_PRD.md                         [묶음]
│   │   ├── 03-설계\02~05 *.md                            [묶음]
│   │   │   ├── 공용코어\ 9개(AUTH_ROADMAP 포함)            [묶음]
│   │   │   └── 디자인\ 5개 + DESIGN.md, COMPONENTS.md     [묶음]
│   │   └── 04-구현\CLAUDE.md, 07_SOURCE_MIGRATION.md     [묶음]
│   └── wiki\WIKI_SCHEMA.md, index.md, log.md, sources\  [묶음] 개발 위키(sources 24개)
├── infra\dify\README.md              [묶음] 채팅 앱 설정 설명서(DSL은 DC-06-034가 docs-chat.yml로 추가)
├── supabase\
│   ├── README.md                     [베이스]
│   ├── migrations\20261013000001_core_lite.sql, 20261013000002_nomad_docs_domain.sql   [묶음]
│   ├── seed.sql                      [묶음]
│   └── tests\rls_smoke.sql           [묶음] RLS·권한 회귀 105항목(러너는 DC-06-003)
└── tasks\  _local\                   [베이스] 작업 데이터(git 추적 안 함)
```

`docs/etc`는 setup 스크립트가 지웁니다. `infra/dify/README.md`는 DSL 파일 이름을 `app.yml`로 적고 있지만 작업 계획의 소유 파일은 `infra/dify/docs-chat.yml`(DC-06-034)이므로 `docs-chat.yml`로 둡니다.

기획서의 경로를 개발 폴더에서는 이렇게 읽습니다. task의 `write_scope`에도 오른쪽 값을 씁니다(약어 정의 `06_AGENT_PLAN.md:5-13`).

| 기획서 경로 | 개발 폴더 경로 |
|---|---|
| `web/` = `apps/nomad-docs/` | `apps/web/` |
| `worker/` = `apps/nomad-docs-worker/` | `apps/worker/`(제안) |
| `api/` = `apps/api/` | `apps/api/` |
| `tpl/` = `packages/docs-templates/` | `packages/docs-templates/` |
| `int/` = `packages/docs-integrations/` | `packages/docs-integrations/` |
| `supabase/monolith/migrations/0001`, `0002` | `supabase/migrations/20261013000001_*`, `20261013000002_*` |
| `supabase/monolith/seed.sql`, `tests/` | `supabase/seed.sql`, `supabase/tests/` |
| `scripts/nomad-docs/`, `infra/` | 같음 |

## 6. 4단계: project-profile 작성

`_shared/project-profile.md`에 다음 값을 채웁니다. 이름과 target_repo는 init이 채웁니다.

| 항목 | 값 | 근거 |
|---|---|---|
| 적용 표준 | platform 통합 기획 규칙(DOC_TEMPLATE) | `docs/file/_index.md` |
| 웹 | Next.js 16.2.x(16.2.9 제안), React 19.2, TypeScript strict, Tailwind CSS v4(4.x 고정), shadcn/ui(Tailwind CSS v4 지원 버전, 구현 시 확인), Tiptap 2.x(제안), zod 3.x, lucide-react, `@supabase/ssr` | `docs/file/03-설계/02_ARCHITECTURE.md` 1절, `docs/file/04-구현/CLAUDE.md` 5절 |
| 3D | three.js + React Three Fiber + drei(React 19 호환 버전, 구현 시 확인). three.js import는 `hero3d/` 안에서만 | 같은 곳 |
| TS 워커 | Node 20 LTS + TS(`apps/worker`, 큐 `docs.generate`·`docs.export`·`docs.integration`) | `02_ARCHITECTURE.md` 1절, 4절 |
| AI 서비스 | FastAPI 0.115 + Python 3.12(제안), LangChain, LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`), Jinja2(autoescape), nh3 | `02_ARCHITECTURE.md` 1절 |
| 렌더 | 공용 렌더 서비스(WeasyPrint 62 이상 제안, flora-publishing 소유). 이 저장소에 렌더 컨테이너를 만들지 않습니다 | `02_ARCHITECTURE.md` 1절, 6절 |
| DB | Supabase(PostgreSQL 15 + pgvector), 단독 프로젝트, `public` 스키마, `SUPABASE_DB_SCHEMA=public` | `05_DATA_MODEL.md` 8절, `README.md:74` |
| 명령 | web·worker: `npm ci / run dev / run build / run lint / run test`, `npx tsc --noEmit`, api: `uv sync`, `uvicorn app.main:app --reload`, `pytest apps/api -k docs`, `ruff check apps/api`, DB: `supabase start`, `supabase db reset`, `supabase gen types typescript --local --schema public > apps/web/src/types/supabase.ts` | `CLAUDE.md` 5~6절(npm 기준). uv·경로는 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음, 무결성 점검 INV13 대상) | 베이스 `_shared/backends.json` |

버전은 `latest`로 두지 않고 lockfile로 고정합니다(Python은 `uv.lock`, 제안). 특히 **Tailwind는 반드시 v4(Tailwind CSS v4)**입니다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 6절). `tailwind.config.js`와 `@tailwind base` 같은 v3 문법을 쓰지 않으며, 지시에도 "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.

## 7. 5단계: 로컬 DB

### 7.1 기동과 적용

| 순서 | 명령(Git Bash / PowerShell 공통) | 설명 |
|---|---|---|
| 1 | `supabase init` | `supabase/config.toml`이 없을 때만 만듭니다. 기존 `migrations`, `seed.sql`, `tests`는 그대로 둡니다. 모놀리스는 `[api].schemas`에 따로 추가할 스키마가 없습니다(`docs`를 추가하는 것은 모듈러 기준, `06_AGENT_PLAN.md:63`) |
| 2 | `supabase start` | Docker로 로컬 Supabase 기동 |
| 3 | `supabase db reset` | `migrations/`를 이름순(타임스탬프)으로 적용하고 `seed.sql`을 넣습니다 |
| 4 | `supabase gen types typescript --local --schema public > apps/web/src/types/supabase.ts` | 타입 생성(`CLAUDE.md` 5절 "모놀리스는 `--schema public`"). `apps/web/src/types/`가 없으면 먼저 만듭니다 |

- `core_lite`는 코어 축소판에서 SECTION 9(affiliate)만 뺐습니다. Toss, 크레딧, OAuth state, 자격증명, 레이트 리밋, 잡, Storage(`org-files`, `exports`), SECTION 11(AI, pgvector), SECTION 12(음성, `voice-audio` 버킷)를 모두 유지합니다(`20261013000001_core_lite.sql:2414-2421`).
- `0002` 말미에 카탈로그 seed(문서 유형 `doc_types`, 유형 버전, 대표 체크리스트 항목, `dev_contract` 조항 골격 9개 `status='draft'`, `runtime_config`)가 있습니다. 플랜·크레딧팩·라우팅은 `seed.sql`이 소유합니다(`05_DATA_MODEL.md` 8절).
- `seed.sql`은 라우팅 행이 13개가 아니면 스스로 예외를 냅니다.

**적용 후 확인 쿼리**(Studio SQL 편집기 또는 psql)

| 확인 | 쿼리 | 기대값 |
|---|---|---|
| 라우팅 기본값 | `select count(*) from public.ai_routing_settings where org_id is null and app_id = 'docs'` | 13 |
| 강제 오픈소스 | `select feature, kind from public.ai_routing_settings where app_id = 'docs' and force_open_source` | `docs.minutes`/llm, `dify.aux`/llm, `meeting_minutes`/stt 3행 |
| MVP 문서 유형 | `select count(*) from public.doc_types where phase = 'mvp' and is_active` | 8(`dev_contract`는 D-3 법무 검토 전 비활성, 8절) |
| 플랜 | `select code, signup_credits, monthly_credits, is_active from public.plans where app_id = 'docs'` | free 50/30 활성, pro 0/400 활성, team 0/1500 비활성 |
| pgvector | `select extname from pg_extension where extname = 'vector'` | 1행 |

### 7.2 SQL 체커(PGlite)로 다시 확인

기획 단계 검증 결과(2026-10-13, PGlite, `docs/file/03-설계/05_DATA_MODEL.md:5`): 모듈러 core 0000~0009 + seed + 2300 적용 정순·역순 OK, 모놀리스 0001 + 0002 + seed OK, RLS 스모크 59/59(모듈러)·59/59(모놀리스), 권한 감사 이상 0건(PUBLIC EXECUTE 남은 제품 함수 0, `search_path` 없는 DEFINER 0, RLS 꺼진 테이블 0).

재검증(2026-10-14, 교차검증 반영 후): 모듈러 전 제품 체인 정순·역순·재실행 OK, 모놀리스 0001 + 0002 + seed OK, RLS 스모크 105/105(모듈러·모놀리스), 권한 감사 0건(`docs/file/03-설계/05_DATA_MODEL.md` 머리).

개발 폴더의 SQL을 고친 뒤에는 같은 체커로 다시 확인합니다. 체커는 platform 쪽에 있고 처음 한 번 `npm install`이 필요합니다(`node_modules`는 platform 저장소에 포함돼 있지 않을 수 있음, 미확인).

```
cd D:/WorkSpace/platform/docs/products/_tools-sqlcheck
npm install
node check.mjs --vector mono \
  D:/WorkSpace/DEV/nomad-docs/supabase/migrations/20261013000001_core_lite.sql \
  D:/WorkSpace/DEV/nomad-docs/supabase/migrations/20261013000002_nomad_docs_domain.sql \
  D:/WorkSpace/DEV/nomad-docs/supabase/seed.sql
```

- 사용법은 `node check.mjs [--vector] <label> <file...>`입니다(`check.mjs:1-3`). 첫 인자 `mono`는 출력 라벨일 뿐입니다. AI 테이블(pgvector)이 있으므로 `--vector`가 필수입니다.
- 파일마다 `[mono] OK <파일>`이 나오면 통과, `FAIL`이면 첫 실패에서 멈추고 종료 코드 1입니다.
- 체커는 적용 가능 여부만 봅니다. RLS 판정은 7.3절 스모크가 맡습니다.
- 실제 Supabase(`db reset`)에서 한 번 더 확인하는 것이 첫 DB 작업(DC-06-001)의 수용 기준입니다.

### 7.3 RLS 스모크(`supabase/tests/rls_smoke.sql`)

105개 검사가 한 파일에 있습니다(2026-10-13 기본 59 + 2026-10-14 교차검증 회귀·신규 기능·독립 검토 회귀 46). 파일은 스키마 자리표시자를 씁니다.

| 자리표시자 | 뜻 | 모놀리스(이번 개발) | 모듈러 |
|---|---|---|---|
| `@S@` | 제품 스키마 | `public` | `docs` |
| `@C@` | 코어 스키마 | `public` | `core` |

| 머리 표시 | 의미 |
|---|---|
| `-- SETUP` ~ `-- END SETUP` | 관리 세션에서 사용자 A·B·C, 거래처, 프로젝트 등을 만듭니다 |
| `-- AS service` / `-- AS A` / `-- AS B` / `-- AS C` | 이후 문장의 역할. service는 `service_role`, A·B·C는 `authenticated` + `request.jwt.claim.sub`(A `aaaaaaaa-0000-4000-8000-000000000001`, B `bbbbbbbb-...-000000000002`, C `cccccccc-...-000000000003`) |
| `-- RUN` | 다음 한 문장을 기대값 없이 실행(준비) |
| `-- TEST <이름> \| expect=...` | 다음 한 문장의 기대값: `rows:N`(행 수), `ok`(오류 없음), `sqlstate:CODE`(그 오류 코드) |

사용자 A·B는 엔타이틀먼트가 있고 서로 비멤버이며, C는 엔타이틀먼트가 없습니다(모놀리스는 apps가 1개면 자동 부여하므로 SETUP이 지웁니다).

자동 러너(`scripts/nomad-docs/rls-runner.*`, `--target mono`)는 DC-06-003이 만듭니다. 그 전에 수동으로 확인하려면:

1. 치환본을 만듭니다(작업 데이터 폴더, git 추적 안 함).
   `sed -e 's/@S@/public/g' -e 's/@C@/public/g' supabase/tests/rls_smoke.sql > tasks/_local/rls_smoke.mono.sql`
2. `supabase db reset`으로 깨끗한 DB를 만듭니다. SETUP이 고정 id를 넣으므로 다시 돌릴 때마다 reset합니다.
3. psql로 접속합니다(로컬 기본 주소 `postgresql://postgres:postgres@127.0.0.1:54322/postgres`, `supabase status`로 확인).
4. SETUP 블록을 그대로 실행합니다.
5. `-- AS` 표시마다 역할을 바꿉니다. service: `set role service_role;` / A·B·C: `reset role; select set_config('request.jwt.claim.sub', '<사용자 id>', false); select set_config('request.jwt.claims', '{"sub":"<사용자 id>","role":"authenticated"}', false); set role authenticated;`
6. `-- TEST` 다음 문장을 하나씩 실행하고 기대값과 비교합니다.

- 파일 전체를 psql에 한 번에 넣으면 역할 전환과 기대 오류 판정이 되지 않습니다. 반드시 문장 단위로 판정합니다.
- 이 파일은 pgTAP 형식이 아닙니다. `supabase test db`(pgTAP 실행)로 돌리지 않습니다(제안: 혼동을 피하려면 러너가 생긴 뒤 위치를 `supabase/tests/` 아래 하위 폴더로 옮기는 것은 DC-06-003에서 판단).
- DC-06-003의 수용 기준은 모놀리스·모듈러 두 대상 모두 105/105과 추가 AI 항목(타인 `ai_conversations` 0행, `ai_chunks` SELECT 42501, `resolve_ai_route` authenticated 42501)입니다. 이번 개발은 단독(모놀리스)이므로 모듈러 대상은 platform의 `2300_docs.sql`로 돌립니다(7.4절).

### 7.4 DB 변경 규칙(단독 개발에서)

- 기획의 정본은 모듈러 `2300_docs.sql`이고 모놀리스 `0002`는 변환 스크립트(DC-06-002)로만 다시 만듭니다(`CLAUDE.md` 2절 "DB 변경"). 단독 개발에서도 이 규칙을 지킵니다.
- 앱 저장소 사본은 `supabase/modular/2300_docs.sql`에 두는 것을 제안합니다. `supabase/migrations/`에 두면 `db reset`이 모듈러 파일까지 적용해 실패합니다.
- 변환: `node scripts/nomad-docs/to-monolith.mjs`(생성), `--check`(CI에서 불일치 시 실패). 출력이 `supabase/migrations/20261013000002_nomad_docs_domain.sql`과 diff 0이어야 합니다(DC-06-002 수용 기준의 파일명을 개발 폴더 이름으로 읽음).
- 원격 DB에 처음 `db push`한 뒤에는 이미 적용한 마이그레이션 파일을 고치지 않고 새 타임스탬프 파일을 추가합니다(제안).
- 원격 DB에 적용하는 `supabase db push`는 에이전트가 실행하지 않고 사람이 확인 후 실행합니다(베이스 project-profile 5절).

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 20개(D-13~D-17은 Phase 2·3D 영상, D-18~D-20은 8.1절 인증 단계)를 확정합니다. 기획은 각 항목의 "권고"로 작성돼 있습니다. 가정과 다르게 정하면 해당 산출물을 고치는 task를 따로 만듭니다.

| ID | 결정 | 권고 | 확정 시점 |
|---|---|---|---|
| D-1 | 브랜드명 | (a) NOMAD Docs로 베타. 폴더·app id `docs`는 유지 | 랜딩(DC-06-044)·법무 문구(DC-06-046) 전 |
| D-2 | MVP 문서 범위 | (a) 8종(계약서 포함)으로 설계·구현, 공개는 D-3으로 계약서만 늦출 수 있게 | 착수 전(템플릿 DC-06-020 전) |
| D-3 | 계약서 출시 게이트 | (a) 법무 검토 완료 전 `dev_contract` 비활성. 변호사법 관련 위험 미확인 | 착수 전 원칙 확정, 활성은 법무 검토 완료 후(공개 베타 W7과 별도 조건) |
| D-4 | 요금 확정 | (b) 베타 2주 원가 측정 후. 지금 값은 상대 비율만 의미 | 베타 2주 후. 단가표(DC-06-013)는 제안값으로 진행 |
| D-5 | HWPX 시점 | (a) Phase 3 | 확인만(업로드 DC-06-031은 hwpx 제외, `06_AGENT_PLAN.md` 1.1절 I-16) |
| D-6 | 첫 CRM | (a) HubSpot. 약관·한도 미확인 | W8(DC-06-054) 전, 국내 고객 인터뷰 후 |
| D-7 | 전자서명 제공자 | API·요금·법적 효력 확인(미확인) | Phase 3 착수 전 |
| D-8 | 표준계약서 원문 출처와 이용 조건 | 확인 전까지 (b) 자체 작성 조항만, `clauses.source_note` 필수 | 템플릿·조항 골격(DC-06-020) 전, 게시는 운영자 카탈로그(DC-06-049) |
| D-9 | AI 생성 표시 방식 | (c) 메타데이터 + 꼬리말(확정 시 끌 수 있음) | 템플릿(DC-06-020)·내보내기(DC-06-029) 전 |
| D-10 | 업로드 자료 보존 | (a) 원본 90일 + 텍스트는 프로젝트 삭제 시까지(제안) | 업로드(DC-06-031)·정리 스케줄(DC-06-051) 전 |
| D-11 | 회의 녹음 원본 보존, 전사본 처리 경로 | (a) 24시간 후 삭제 + 전사본 그래프 오픈소스 강제(seed가 이미 이 값) | 회의록(DC-06-024) 전 |
| D-12 | 정부지원 신청서(`biz_plan`)를 Phase 2 맨 앞으로 | 페르소나 인터뷰 후. 앞당기면 D-5와 묶어 판단 | Phase 2 계획 시 |
| D-13 | shorts_agency 공개 시점 | (a) Phase 2(team 플랜). 직접 대행 운영 조직에만 수동 부여 | W8(DC-06-060) 전 |
| D-14 | content 단가 토큰 `catalog:<key>` 저장 위치 | (a) `workspace_settings.defaults` | DC-06-060 전 |
| D-15 | 영상 제작 계약서·위임 동의서 조항 원문 출처 | 확인 전까지 (b) 자체 작성 + 법무 검토 | DC-06-060 게시 전 |
| D-16 | 월간 리포트 KPI 입력 | (a) 사용자 입력·CSV로 시작 | DC-06-060 전 |
| D-17 | 3D 영상 히어로 제작 방식 | (a) 3D 장면 직접 렌더 녹화 | DC-06-045 전 |
| D-18 | 카카오 이메일 정책(비즈 앱 `account_email` 권장) | (a) 비즈 앱 전환 후 필수 동의 | G2 판정 전, DC-06-064 착수 전 |
| D-19 | 네이버 경로(`supabase_custom`/`bridge`) | 스파이크로 결정 | C2 스파이크(DC-06-065 첫 단계) 결과로 |
| D-20 | 이메일+비밀번호 가입 유지 | (a) 유지 | G1 판정 전, DC-06-063 착수 전 |

**D-3 계약서 게이트를 지키는 방법**
- 규칙: 법무 검토 전에는 `doc_types.is_active=false`로 배포합니다(`01_PRD.md:390`, `06_AGENT_PLAN.md:32`, `:220`). 패키지는 7종으로 축소 표시합니다.
- 현재 seed(2026-10-14 반영): `dev_contract`는 `is_active=false`로 들어가고, `on conflict do update`가 `is_active`를 덮지 않습니다(운영자가 켠 값 보존). 패키지는 계약서 없이 7종으로 보입니다.
- RLS 스모크는 비활성 상태를 먼저 확인("seed에서 계약서 유형은 비활성", "비활성 계약서 생성 거부 22023")한 뒤 테스트 안에서만 켜고 고지 동의 경로(DC007)를 검사합니다. 로컬·스테이징·운영 모두 같은 seed를 씁니다(분기 없음).
- D-3 법무 검토가 끝나면 운영자 화면(DC-F-040) 또는 service_role로 `update doc_types set is_active = true where code = 'dev_contract'`를 실행하고 감사 기록을 남깁니다(사람이 확인 후 실행).
- 활성 여부와 관계없이 지켜야 할 것: `dev_contract`는 template만, LLM `ai_usage` 0행, `docs.assist` 403 `assist_disabled_high_risk`, 첫 생성 전 고지 동의(DC007), 조항은 `status='draft'`라 확정 시 `L-REQUIRED-CLAUSE`가 막습니다(`05_DATA_MODEL.md` 9절 seed 표).

**산출물 승인 절차**
1. 결정 결과를 해당 산출물에 반영하는 task를 만듭니다.
2. 반영이 끝나면 `docs/file/_index.md`의 상태를 "초안"에서 "승인"으로 바꾸고, 변경 이력에 날짜·ID·사유·task를 적습니다.
3. 개발 task는 "승인" 상태의 산출물만 baseline으로 씁니다(베이스 `orchestrator-rules.md` §4).

문서 간 불일치 18건(I-1~I-18)은 2026-10-13에 기획서 본문을 고쳐 정리했습니다(`06_AGENT_PLAN.md` 1.1절). 구현 에이전트는 이 표를 다시 판단하지 않고 01~05 본문을 따릅니다. 이번 정리 이후 남은 차이는 위 D-3 seed 항목과 13.2절 3D 히어로 경로뿐입니다.

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 DC-06-001~065, 모두 65개입니다. DC-06-010은 판정을 사람이 하는 디자인 비주얼 검토(준비는 Sonnet)이고, DC-06-052~055·060(P2)은 Phase 2입니다. 2026-10-14에 DC-06-061(CRM형 워크스페이스)·062(생성 진행 애니메이션)를 W4에 추가했습니다. DC-06-063~065는 같은 날 추가한 인증 단계 작업이고(19장, `06_AGENT_PLAN.md` 8절), 기존 DC-06-014는 Stage A(Mock 로그인) 범위로 바뀌었습니다.

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 005, 008 | 4 | 없음 | DB 조각 적용, 타입, web·워커 골격, 디자인 레퍼런스(1단계) |
| W1 | 002, 003, 006, 007, 012, 013, 017, 020, 046 | 9 | W0 완료 | 모놀리스 변환, RLS 러너, ai-service, CI, API 공통, 단가·features, 효과 엔진, 템플릿 9종, 법무 문구 |
| W1-D | 009 → 010 → 011(직렬) | 1 | 004, 008 완료 | 디자인 시스템 2~4단계. 010은 사람이 수행. 011 완료가 모든 화면 작업(038~045)의 진입 조건 |
| W2 | 014, 015, 016, 019, 021, 031, 033, 047 | 8 | W1 완료 | 인증 Stage A(Mock 로그인·시드·가드), 워크스페이스·거래처, 정본 API, 효과 엔진 속성 테스트, compliance·lint, 업로드, AI 게이트, 결제 |
| W3 | 018, 022, 028, 032, 036, 037, 038, 045, 049, 059 | 10 | W2 완료, 038·045는 011 완료 | 효과 적용, 생성 그래프, 문서 API, RAG, 음성, CSV, 화면 1, 3D 히어로(+ 3D 영상), 운영자 카탈로그, 배포 |
| W4 | 023, 024, 025, 027, 029, 030, 035, 039, 044, 048, 061, 062 | 12 | W3 완료. 029의 DOCX는 C-1 반영 전 비활성으로 진행 | 추출·회의록·다시 쓰기 그래프, 생성 요청·패키지, 내보내기, 추적표, 위키, 화면 2, 랜딩, 결제 E2E, CRM 워크스페이스, 생성 진행 애니메이션 |
| W5 | 026, 034, 040, 041, 042, 051 | 6 | W4 완료 | 골든·평가, Dify 채팅, 편집기, 화면 3·4, 계정 삭제·정리 |
| W6 | 043, 050 | 2 | W5 완료 | 화면 5(채팅·위키), KPI |
| W7 | 063(G1 통과 후 먼저), 056, 057, 058 | 4 | W6 완료, 063은 G1 | Google + 이메일 로그인(Stage B), 통합·E2E(Mock 페르소나 storageState, 063 후 스테이징 재실행)·AI 회귀. 녹색이면 공개 베타(MVP). `dev_contract` 활성은 D-3 법무 검토 완료가 별도 조건 |
| W8 | 052 → 053, 054, 055, 060 / 064·065(G2 통과 후) | 1 → 4, 064·065 병렬 2 | MVP 출시 후, team 플랜(C-5) 준비. 064·065는 G2 | 연동 프레임워크, 발신 웹훅·n8n(Make는 쓰지 않음), HubSpot, admin-suite ERP, shorts_agency(Phase 2), 카카오 로그인(C1, P1), 네이버 로그인(C2, P1) |

단독(모놀리스) 개발에서 읽는 방법:
- DC-06-001의 "모듈러 조각 `2300` 적용, `--schema core,docs` 타입"은 단독 DB에서는 `0001`+`0002`+seed 적용과 `--schema public` 타입으로 읽습니다. 모듈러 체커 확인(`check.mjs --vector mod ...`)은 platform의 `_supabase-modular`로 그대로 수행합니다.
- DC-06-055(admin-suite ERP)는 모놀리스에서 불가능합니다(`README.md:74`). W8 착수 시 모듈러 전환 또는 Phase 3 API 방식(C-2)을 다시 결정합니다.

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | DB·RLS(001, 003), 결제·크레딧 차감 경로(013, 027, 033, 047), 권한 경계(006, 014 인증 Stage A, 049, 055, 063 인증 Stage B, 065 네이버 로그인), 체크리스트 효과 원자 적용(018), 고위험 문서 규칙이 걸린 생성 그래프(022), AI 보안 회귀(058), 개인정보 삭제(051) | 오케스트레이터(Opus)가 설계하고 `plan-challenger`(고문, Fable)가 착수 전 계획을 검토. 구현은 `supabase-expert`·`fastapi-expert`·`nextjs-expert`(Sonnet), 리뷰는 `review-expert` |
| Opus | 그래프(extract·minutes·assist), RAG, 위키, Dify, 음성, 편집기, API, 템플릿, 효과 엔진, 테스트 설계, 카카오 로그인(064) | `claude-main`(Opus)이 설계 → `fastapi-expert`·`nextjs-expert`(Sonnet)가 구현 |
| Sonnet | 화면, 랜딩, 3D 히어로·3D 영상, 디자인 시스템 구현, CRM 워크스페이스(061), 생성 진행 애니메이션(062), CI, 배포 설정 | `nextjs-expert`(Sonnet), CI·배포 문서는 오케스트레이터 |
| Haiku | 법무 문구·점검표(046), KPI 쿼리(050) | 오케스트레이터가 직접 처리(베이스에 Haiku 워커 없음) |
| 사람 | 디자인 비주얼 검토 판정(DC-06-010, 준비는 Sonnet) | 사용자 |

작업 수 비율(65개, `06_AGENT_PLAN.md` 4절, 2026-10-14 인증 단계 반영): Fable 16(24.6%), Opus 33(50.8%), Sonnet 14(21.5%), Haiku 2(3.1%). 규모 가중(S=1, M=2, L=3, 합계 142) 기준은 Fable 25.4%, Opus 52.1%, Sonnet 20.4%, Haiku 2.1%입니다. 리뷰는 `claude-reviewer`(Sonnet), `plan-challenger`(고문), `review-expert`(Sonnet)가 병렬로 맡습니다. 모델 지정은 setup 스크립트 5단계가 복사본에만 적용합니다. 고문을 Opus로 바꾼 경우(3절) "Fable" 행의 계획 검토는 Opus 고문이 맡고, 나머지 매핑은 같습니다.

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고, 작업 1개를 task 1개로 둡니다. 형식은 베이스 `_templates/task-folder.md`를 따릅니다.

```
tasks/DC-06-001-db-apply/
├── task.md      baseline에 산출물 ID, workers_approved, write_scope
├── context.md
└── log.md       [APPROVAL], [DECISION] 기록
```

`task.md`의 baseline 예시는 다음과 같습니다.

```yaml
baseline:
  - id: DOC-DES-004
    path: docs/file/03-설계/05_DATA_MODEL.md
  - id: DOC-CORE-004
    path: docs/file/03-설계/공용코어/DB_CONVENTIONS.md
  - id: DOC-CORE-003
    path: docs/file/03-설계/공용코어/SECURITY_BASELINE.md
  - id: DOC-MGT-002
    path: docs/file/01-관리/06_AGENT_PLAN.md   # DC-06-001 수용 기준, 1.1절 I-12
```

`write_scope`는 06장 2절 "소유 파일/디렉토리" 열을 5.2절 경로 표로 바꿔 적습니다. 한 경로는 한 작업만 씁니다. 공용 설정(`apps/web/package.json`, `next.config.ts`, 루트 레이아웃)은 DC-06-004만, SQL은 DC-06-001만 수정합니다(`06_AGENT_PLAN.md:21-24`).

### 9.4 요청 프롬프트 예시 (W0 첫 작업, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/nomad-docs/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. docs/file/_index.md 가 없으면 deliverable-first 스킬 절차로 산출물부터 추출한다.)

[요구사항]
DC-06-001: supabase/migrations 의 core_lite(SECTION 11·12 포함)와 nomad_docs_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다(단독 프로젝트, public 스키마). 완료 조건 = ① supabase db reset 오류 0건
② pgvector 확장과 ai_*·voice_* 테이블 생성 확인, ai_routing_settings 의 app_id='docs' 행 13건,
force_open_source 3건(docs.minutes, dify.aux, meeting_minutes) 확인 ③ doc_types 의 mvp 활성 8종 확인,
dev_contract 가 seed 에서 비활성(is_active=false)이고 재실행해도 유지되는지 확인. supabase/tests/rls_smoke.sql 105항목 통과
④ 1.1절 I-12(직인 png|webp) 반영 확인 ⑤ supabase gen types typescript --local --schema public 결과를
apps/web/src/types/supabase.ts 에 저장 ⑥ PGlite 체커(check.mjs --vector mono 0001 0002 seed) OK
⑦ 06_AGENT_PLAN.md 의 DC-06-001 수용 기준을 단독(모놀리스) 기준으로 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/(tests/ 제외), apps/web/src/types/

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
| 3 | 착수 전 계획 공격(고문) | `plan-challenger`(Fable, 또는 Opus로 교체) |
| 4 | 구현 | 도메인 expert(Sonnet), `gate.sh`·`scope_check.sh` 전후 실행 |
| 5 | 리뷰: 요구사항 → 설계 → 구현 → 테스트 추적성 | `claude-reviewer`, `review-expert` |
| 6 | 개발 위키 갱신(12절) | `llm-wiki` 스킬 |
| 7 | 완료: task status `done`, 웨이브의 모든 task가 끝나면 다음 웨이브 | - |

- **MVP(공개 베타) 출시 조건**: W7(063 Stage B, 056, 057, 058)까지 녹색, `06_AGENT_PLAN.md` 7절 완료 정의 충족. P0·P1 작업 전부 완료(P2 = 052~055, 060 제외, G2 이후 작업인 064·065 제외). 3D 히어로(045), KPI(050), 계정 삭제·정리(051)는 P1입니다.
- **`dev_contract` 활성 조건**: 위와 별도로 D-3 법무 검토 완료(8절).
- 화면 작업(038~045)은 디자인 시스템 4단계(DC-06-011)가 끝난 뒤 시작합니다.
- 각 P0 작업은 대응 테스트 작업이 녹색이어야 완료입니다(`06_AGENT_PLAN.md` 7절 표. 예: 017 → 019, 020~025·029 → 026·058, 047 → 048).
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다(베이스 `orchestrator-rules.md` §4.5).

## 11. AI 계층 구축 (nomad-docs)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, 제품 설계 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.1절

| 구성 | nomad-docs 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api`(공용 ai-service + docs 확장: `app/ai/graphs/docs_*.py`, `app/ai/products/docs/`, `app/ai/tools/docs/`, `app/ai/compliance/docs.py`). JWKS 검증 `aud=platform-ai:docs`, 비동기 HTTP만, 기동 시 `DOCS_TEMPLATES_DIR` 체크섬 검사 | DC-06-006 |
| 모델 라우팅 | seed `ai_routing_settings` 13행. `docs.generate`·`docs.assist`는 상용 우선, `docs.extract`·`chat`·위키는 오픈소스 우선, `docs.minutes`(llm)·`dify.aux`·`meeting_minutes`(stt)는 오픈소스 강제, `docs.knowledge` 임베딩은 `oss-embed` 고정, `voice_chat`은 STT 오픈소스 우선·TTS ElevenLabs 우선(`02_ARCHITECTURE.md` 5.1절). 제공자·모델을 코드에 하드코딩하지 않고 `resolve_ai_route` 결과만 씁니다 | DC-06-006, 058 |
| 국외 이전 동의 | 온보딩 `/onboarding/ai`에서 고지와 동의(`set_ai_cross_border_ack`). 미동의 조직은 모든 llm 기능이 `oss-llm`만 씁니다 | DC-06-033 |
| AI 게이트 | Next.js `/api/ai/*`: 대화 생성(`dify_user` HMAC), 채팅 중계, 턴 선차감·정산, EdDSA 서명 토큰(`iss=docs`, 10분), 워커용 잡 토큰 `/api/internal/ai-token`, 정산 `/api/internal/ai-settle` | DC-06-033 |
| 업로드와 RAG | 서명 업로드 URL, 매직바이트 검사, 파서(txt, md, docx, pdf. hwpx 제외), LLM 전송 전 주민등록번호 마스킹, 프로젝트별 컬렉션 `docs.knowledge` 색인(`rag.index`, 1MB당 1크레딧) | DC-06-031, 032 |
| 문서 생성 그래프 | LangGraph `docs.generate`: load_context → plan_sections → fill_template → draft_ai_sections → consistency_check → lint → compliance → output. template 유형은 LLM 0회, `dev_contract`는 `draft_ai_sections`를 건너뜀. 숫자는 서버 값만, 불일치는 조용히 고치지 않고 lint 오류 | DC-06-020, 021, 022, 026 |
| RFP 추출 | LangGraph `docs.extract`: parse → index → extract_checklist → extract_requirements → dedupe → compliance → output(제안 행만, 확인 전 정본 0행) | DC-06-023 |
| 선택 영역 다시 쓰기 | LangGraph `docs.assist`(다시 쓰기·요약·표 변환). 4,000자 초과 422(잘라서 처리 금지), Diff 제안만, 고위험 문서 403 | DC-06-025, 040 |
| Dify 채팅 | 공용 Dify에 `docs-chat` Chatflow. 입력 `platform_conversation_id`, `project_id`만. HTTP 노드 → `/tools/answer`(내부 키), 장애 시 `/tools/answer-direct`. 법률 판단 질문은 거절. 설정은 `infra/dify/README.md`, DSL은 `infra/dify/docs-chat.yml` | DC-06-034, 043 |
| 프로젝트 용어 위키 | `wiki.ingest`(색인·회의록 직후), party → entity, term·acronym → concept, decision → topic. 사용자 소유 블록 보호, `expected_version` 충돌 409 | DC-06-035, 043 |
| 회의 녹음 → 회의록(핵심) | 녹음 전 매번 제3자 고지(미확인 업로드 422 `recording_notice_required`), STT 10분 분할(`meeting_minutes`, 오픈소스 강제), LangGraph `docs.minutes`(오픈소스 강제) → 회의록 + 결정 사항·할 일 + 요구사항 후보. 원본 24시간 삭제, 텍스트 붙여넣기만으로도 생성 가능, 실패 시 전액 환불. 길이 상한은 플랜 `minutes_max_minutes`(30/120/180분), 파일 200MB | DC-06-024, 042 |
| 음성 대화 | `/api/voice/consent`, `stt`, `tts`(DB의 assistant 메시지만). 60초 자동 중지, `store_audio=false`, 마이크 거부 시 텍스트 채팅 정상 | DC-06-036 |
| 정산·정리 | 정산 5분, 하트비트 회수 5분, 녹음 원본 삭제 1시간 주기, 내보내기 만료 1일(워커 스케줄, 공개 크론 라우트 없음) | DC-06-033, 051 |
| 보안 회귀 | 서명 토큰 위조·만료·재사용, 대화 매핑, 국외 동의 필터, 강제 오픈소스 3종, 고위험 문서 LLM 0, 선차감·정산·환불, 라우팅 seed 스냅샷 | DC-06-058 |

순서는 이렇습니다.
1. 공용 인프라(Dify, 오픈소스 LLM·임베딩·음성 서버)는 `_shared` 문서대로 먼저 띄웁니다.
2. 이 제품은 오픈소스 서버가 없으면 일부가 아예 기동하지 않습니다. ai-service는 `OSS_LLM_BASE_URL`, `OSS_EMBED_BASE_URL`이 없으면 기동 실패이고, web·ai-service는 `OSS_VOICE_BASE_URL`이 없으면 기동 실패입니다(`02_ARCHITECTURE.md` 8절). GPU 서버가 준비되기 전에는 OpenAI 호환 모의 서버를 주소로 두는 것을 제안합니다.
3. 상용 우선 기능(`docs.generate`, `docs.assist`)은 국외 동의가 있는 테스트 조직으로 개발합니다. 회의록(`meeting_minutes`, `docs.minutes`), `dify.aux`, `docs.knowledge`는 상용으로 대체되지 않으므로 오픈소스 서버(또는 모의 서버)가 먼저 필요합니다.
4. 준비되면 seed 기본값 그대로 운영합니다.

이름 주의: `docs.generate`는 잡 타입, 큐 이름, LangGraph 그래프, 라우팅 feature에 모두 쓰입니다(`02_ARCHITECTURE.md` 4절, 5절). 패키지 부모 잡 `docs.package`도 `docs.generate` 큐를 씁니다. `docs.extract`·`docs.minutes` 잡은 `docs.ai` 큐입니다. 큐와 그래프를 섞지 않도록 task에 둘 중 무엇인지 적습니다.

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | 관련 `docs/wiki/modules/`, `decisions/` 페이지와 `log.md` 갱신(`llm-wiki` 스킬의 ingest) |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 점검 |

- 위키는 산출물을 대체하지 않습니다. 충돌하면 `docs/file/`이 정본입니다.
- 키·토큰 값과 개인정보는 위키에 쓰지 않습니다. 고객 RFP·회의록 같은 샘플 자료도 위키에 붙이지 않습니다.
- 초기 페이지(`sources/*.md` 24개)는 setup 시 함께 들어옵니다.
- 이것은 개발용 위키입니다. 제품의 프로젝트 용어 위키(DB `wiki_pages`, DC-06-035)와 다릅니다.
- D-3 seed 처리처럼 기획과 다르게 정한 사항은 `decisions/` 페이지에 남깁니다.

## 13. 메인 디자인과 디자인 시스템

디자인 작업 순서: 13.5 시각 레퍼런스(Awwwards·Dribbble) → 13.1 디자인 시스템 → 13.2 메인 히어로. 공통 절차 7단계는 `docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md`입니다.

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`, 제품 선택은 `03_SCREENS_UX.md` 3.25절)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1. 레퍼런스 확정 | 앱 화면은 Atlassian(단계형 폼, 칸반과 키보드 대안, 상태 lozenge, 모달), 보조 Primer(고밀도 표, tabular 숫자, 비용·추적표·버전 이력), AI 채팅·음성·위키 화면은 Astryx 패턴(존재·라이선스 확인, 미확인 시 대체안 기록), 랜딩은 `HERO_3D.md`. 라이브러리(`@atlaskit/*`, `@primer/react`)는 설치하지 않습니다 | DC-06-008, 고문 검토 1건 |
| 2. 가진 것 위에서 시작 | 03장 4.3절 토큰 플랜(서류철 `--color-canvas`, 용지 `--color-surface`, 먹회 `--color-text`, 괘선 `--color-rule`, 결재청 `--color-accent`, 인주 `--color-seal`) + Tailwind CSS v4 `@theme` → `apps/web/src/styles/tokens.css`(기획 표기 `apps/nomad-docs/src/styles/tokens.css`, I-13), 기본 컴포넌트와 `/dev/components` | DC-06-009 |
| 3. 비주얼은 사람이 | 라이트/다크, 상태 6종, 크기 배리언트를 스크린샷으로 보고 사람이 수치를 고칩니다. `--color-seal` 사용처가 직인·확정 표시·3D 히어로뿐인지 확인 | DC-06-010(사람) |
| 4. 정답을 한 곳으로 | 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 `DESIGN.md`, `COMPONENTS.md`를 코드 기준으로 맞춤(스크립트 비교 100% 일치) | DC-06-011 |

- AI에게는 컴포넌트 1개 단위로 맡깁니다(`DESIGN_SYSTEM.md` 8장 템플릿). "알아서 만들어 줘"는 쓰지 않습니다.
- 지시에는 버전을 항상 적습니다. "Tailwind"가 아니라 "Tailwind CSS v4"라고 씁니다.
- 기본 컴포넌트 다음에 제품 고유 컴포넌트(ChecklistStep, EffectsPreviewPanel, RequirementBoard, LineItemTable, DocEditor, DiffCard, LintPanel, FinalizeDialog, TraceMatrix, MeetingRecorder, RiskNoticeDialog, ChatPanel 등)를 만듭니다(`03_SCREENS_UX.md` 3.25절).
- 금액 열은 tabular 숫자·오른쪽 정렬, 상태는 아이콘 + 텍스트(색만으로 구분 금지), 이모지 아이콘 금지(Lucide), hex 하드코딩 금지.
- `docs/file/03-설계/디자인/DESIGN.md`, `COMPONENTS.md`는 빈 템플릿이 아니라 `03_SCREENS_UX.md` 3.25.1·3.25.2절 초기값(색 토큰 라이트/다크, 서체, radius, 행 높이, 모션 토큰, 컴포넌트 배리언트 표)으로 채워져 들어옵니다. DC-06-009는 이 값으로 `tokens.css`를 만들고, DC-06-011이 코드 기준으로 다시 맞춥니다(다르면 코드가 이깁니다).

### 13.2 메인 히어로 (정본: `HERO_3D.md`, `03_SCREENS_UX.md` 4.6절)

소재: 체크리스트 판의 체크가 하나씩 접혀 서류 낱장이 되고, 낱장이 패키지 의존 순서대로 묶음으로 쌓인 뒤 맨 위 견적서에 인주 직인이 한 번 찍힙니다. 의미는 "입력 한 번(체크)이 여러 문서가 되고, 마지막에 사람이 확정한다"입니다.

| 기기 | 구성 |
|---|---|
| PC(1280px 이상) | 풀 3D: 체크 8개 → 낱장 8장(7종 + 추적표) → 묶음 → 직인. 제목·CTA·샘플 PDF 링크는 HTML 오버레이 |
| 태블릿(768~1279px) | PC와 같은 장면, DPR 상한 1.5, 터치 드래그 시점 이동. iOS 기울기는 버튼 탭으로 권한 요청 |
| 모바일(767px 이하) | HTML 즉시 표시 + 가벼운 3D 자동 로드(로딩 전 저사양 판정): 체크 3 → 낱장 3, 직인은 2D SVG |
| 대체 | WebGL 미지원·저사양·reduced-motion·데이터 절약·`NEXT_PUBLIC_HERO3D_ENABLED=false`·30fps 미만 지속이면 정지 렌더 이미지(`public/hero/checklist-to-docs.avif`, WebP 대체) + HTML 견적서 첫 쪽 |

- 직인이 끝나면 렌더를 멈춥니다(`frameloop="demand"`). 직인 안에는 글자를 넣지 않습니다(실존 회사 직인처럼 보이지 않게). 견적서 예시에는 "예시 문서"를 표시합니다.
- 형상은 코드 생성 도형만(외부 glTF·텍스처·3D 글자 없음), 색은 토큰만(서류철, 용지, 괘선, 결재청, 인주).
- 성능 예산: PC·태블릿 1MB/60fps, 모바일 300KB/30fps, LCP 2.5초, 첫 화면 전 3D 초기화 0ms.
- 금지: 저울·법봉, 보라/핑크 그라디언트, 별 파티클, 네온 그리드, 지구본, 가상 후기·허위 수치.
- 위치: 작업 계획의 소유 경로 `apps/web/src/features/hero3d/`, `apps/web/public/hero/`(DC-06-045, `06_AGENT_PLAN.md:107`)를 따릅니다. 03장 4.6절은 `src/components/hero3d/`로 적고 있어 서로 다릅니다(확인 2026-10-13). 소유 경계 정본은 06장이므로 `features/hero3d/`로 두고, 03장 표기 수정은 산출물 갱신 task로 처리합니다(제안).
- 확인: PC·태블릿·모바일 스크린샷 3종, Lighthouse, 프레임 측정, 고문 디자인 검토(`HERO_3D.md:70-75`).
- 레퍼런스 URL은 `REFERENCES.md`에 있는 것만 씁니다(nomad-docs 절 `REFERENCES.md:309`, 13.5절). `HERO_3D.md`에 이 제품의 소재 행(5장)과 영상 단계(6장)가 들어가 C-4는 반영됐습니다.
- **3D 영상 레이어(DC-F-049, `03_SCREENS_UX.md` 4.6.1절)**: 메인은 "동적 3D + 3D 영상" 두 겹입니다. 실시간 3D를 못 돌리는 기기(모바일·저사양·WebGL 실패·30fps 미만)는 같은 장면을 미리 렌더한 8~12초 무음 루프 영상(`public/hero/hero-loop.mp4`·`.webm`·`hero-loop-m.mp4`, 포스터 avif)을 보고, reduced-motion·데이터 절약·영상 실패면 정지 이미지를 봅니다. 영상은 `scripts/nomad-docs/hero-record/`로 R3F 장면을 오프라인 렌더해 ffmpeg로 만듭니다(D-17). 예산: 영상 2MB(모바일 1MB), 포스터가 LCP, 첫 화면 JS에 3D·영상 코드 0. 킬 스위치 `NEXT_PUBLIC_HERO_VIDEO_ENABLED`.

### 13.3 로그인 후 화면: CRM형 워크스페이스 (정본: `03_SCREENS_UX.md` 3.26절, DC-06-061)

| 화면 | 벤치마킹 패턴 | 데이터 |
|---|---|---|
| 앱 셸 | 왼쪽 내비(홈·파이프라인·거래처·프로젝트·문서·연동·설정) + 상단 ⌘K 명령 막대(Linear) | - |
| 파이프라인 `/app/pipeline` | 단계 열 보드 + 열 합계 + 14일 정체 표시(Pipedrive), 보드/표 전환(Attio) | 뷰 `project_pipeline`(단계는 문서 상태에서 계산, 저장 안 함) |
| 거래처 360 `/app/parties/[id]` | 왼쪽 속성·가운데 활동·오른쪽 연결 카드(HubSpot) | 뷰 `project_activity`, `project_totals` |
| 커맨드 팔레트 | 검색 + 명령 + 최근, `g p`/`g c` 이동(Linear) | `GET /api/search` |

- 카드를 끌어 놓아 단계를 바꾸지 않습니다. 단계는 문서가 정합니다(견적서 확정 → quoted, 계약서 확정 → contracted, 검수확인서 확정 → accepted).
- 요청 프롬프트 예시(9.4절 형식): "작업 DC-06-061. 근거 `03_SCREENS_UX.md` 3.26절, `04_API.md` 2장 `/api/pipeline`·`/api/search`·activity. 작업 대상 경로: `apps/web/src/features/pipeline/`, `apps/web/src/app/(app)/pipeline/`, `apps/web/src/app/api/{pipeline,search}/`, `apps/web/src/app/api/{projects,parties}/[id]/activity/`. 스택: Next.js 16.2.x, React 19.2, Tailwind CSS v4, shadcn/ui, motion(구 framer-motion, React 19 지원 버전). 완료 기준은 06장 DC-06-061 행."

### 13.4 문서 생성 단계별 애니메이션 (정본: `03_SCREENS_UX.md` 3.27절, DC-06-062)

| 단계 | 서버 근거 | 화면 |
|---|---|---|
| queued → collecting → drafting(섹션별) → assembling → linting → done | `generation_runs.progress`(ai-service가 `docs.report_generation_progress`로 기록, Realtime) | 단계 레일 + 용지에 섹션 줄이 차례로 그려짐, 패키지는 문서별 레인 |

- 시간 기반 가짜 진행률을 쓰지 않습니다. 서버가 단계를 보내지 않으면 화면도 움직이지 않습니다.
- 대기 중에만 [취소](`docs.cancel_generation`). reduced-motion이면 단계 목록만 바뀝니다.
- 그래프 쪽 진행 보고는 DC-06-022(생성 그래프)의 수용 기준에 들어 있습니다. 화면(062)은 022·027 뒤에 시작합니다.

### 13.5 시각 레퍼런스: Awwwards · Dribbble (정본: `docs/file/03-설계/디자인/REFERENCES.md`, `DESIGN_PRINCIPLES.md` 1단계, 제품 선택은 `03_SCREENS_UX.md` 4.1절)

화면 종류에 따라 레퍼런스 출처를 나눕니다(`DESIGN_PRINCIPLES.md` 1단계, "대시보드와 마케팅 페이지의 구분" 절).

| 화면 | 주 레퍼런스 | 목록 | 가져오는 방식 |
|---|---|---|---|
| 메인페이지·랜딩 | Awwwards 수상작(SOTD → Honorable Mention → Nominee 순) | https://www.awwwards.com/websites/ | 기억에 남는 요소 하나(히어로 처리, 서체, 인터랙션 중 하나)만 가져오고 나머지는 조용히 둡니다 |
| 앱 화면·대시보드 | Dribbble 샷 | https://dribbble.com/ | 정보 배치와 밀도를 가져옵니다. 상태색과 데이터가 주인공입니다 |

이 제품이 고른 레퍼런스입니다(`03_SCREENS_UX.md` 4.1절 표 그대로). 후보 전체와 브리프 보조 표(기존 토큰, 피할 인상, UUPM 쿼리)는 `REFERENCES.md` nomad-docs 절(`:309`)에 있습니다.

| 구분 | 제목 | 출처 | URL | 참고 포인트(가져올 것) | 가져오지 않을 것 | 적용 화면 | REFERENCES.md 위치 |
|---|---|---|---|---|---|---|---|
| 랜딩 | Superlist (SOTD) | Awwwards | https://www.awwwards.com/sites/superlist | 생산성 도구의 실제 제품 화면을 첫 화면 주인공으로 두는 구성. 여기서는 체크리스트 화면 한 장 | 할 일 관리 카피, 브랜드 색 | 히어로 오버레이 옆 체크리스트 실제 화면 | study-note 절 `:258` |
| 랜딩 | Codapress Publishing (Honorable Mention) | Awwwards | https://www.awwwards.com/sites/codapress-publishing | 결과물을 히어로의 주인공으로 두는 방식. 여기서는 책 대신 문서 묶음(8장 서류) | 원형 캐러셀과 GSAP 스크롤 연출 반복 | 히어로 마지막 프레임, "만들어지는 문서" 섹션 | flora-publishing 절 `:51` |
| 앱 | Lexi - AI Writer Assistant Web App Saas Platform | Dribbble | https://dribbble.com/shots/22398012-Lexi-AI-Writer-Assistant-Web-App-Saas-Platform | 좌측 사이드바 + 본문 편집 영역의 작업 공간 구조 | 모든 패널을 같은 둥근 카드로 나누는 SaaS 카드 키트 | 프로젝트 셸, 문서 편집기 | flora-publishing 절 `:55` |
| 앱 | Scribbler - Writing App | Dribbble | https://dribbble.com/shots/15364448-Scribbler-Writing-App | 본문 폭과 도구 노출을 최소화한 편집 화면 | 종이 질감 배경, 크림 배경 | 문서 편집기 본문 영역 | flora-publishing 절 `:53` |
| 앱 | Table data view for admin dashboard | Dribbble | https://dribbble.com/shots/22988094-Table-data-view-for-admin-dashboard | 행 선택 상태, 페이지네이션, 페이지당 행 수 | 행 호버 전환 효과 | 비용 항목, 요구사항 표, 버전 이력, 내보내기 기록 | admin-suite 절 `:176` |

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

- 이 제품은 전용 원본 저장소가 없습니다. 이식 원천은 다른 제품 소유이거나 공용 문서이므로 **읽기 전용**으로 두고, 옮기거나 지우지 않습니다. 아카이브(`archive/`) 대상도 없습니다(07장 5절).
- 대부분은 "참고"(패턴만 보고 새로 작성)입니다. 실제로 코드·데이터를 옮기는 것은 두 가지뿐입니다.

| 원천 | 옮기는 것 | 대상 | 작업 |
|---|---|---|---|
| flora v1 `api/routers/export.py`의 `content_disposition`(RFC 5987 한글 파일명) | Python → TS로 옮김. 파일명은 `<문서번호>_<유형명>.<ext>`(제안) | `apps/web/src/app/api/exports/` | DC-06-029 |
| flora-publishing 설계의 sanitize 허용 목록 | `table`, `colgroup`, `col`, `th/td[colspan,rowspan]`, `section[data-key]` 추가(제안). TS·Python이 같은 JSON을 읽고 해시 일치 테스트 | `packages/docs-templates/sanitize-allowlist.json` | DC-06-020, 028 |

| 원천 | 참고만 하는 것 |
|---|---|
| flora-publishing(설계) | LangGraph 초안 그래프 패턴 → `docs.generate`, 단건 보조 그래프 → `docs.assist`, Tiptap + 선택영역 툴바 + Diff 카드(섹션 단위 노드로 변경), 업로드 파서 계약, 크레딧 선차감·환불 흐름 |
| flora v1 | WeasyPrint 경로 교훈(렌더는 공용 서비스, CSS는 `"Noto Sans CJK KR"` 이름만), HTML 조립 구조(Jinja autoescape로 새로 작성), 파서 라이브러리 선택 |
| SellingDocs(기획) | "구조화 JSON → HTML 템플릿 → PDF"를 "문서 1개 = 잡 1개, 문서 안 = 섹션 JSON"으로, 크레딧 원자 차감 교훈, Route Handler 순서(인증 → zod → 레이트 리밋 → 엔타이틀먼트 → 크레딧 → 처리) |
| FortuneDocs(기획) | "결정적 값은 서버 계산, LLM은 해석만" 원칙 하나 → 금액 생성 컬럼, `project_totals`, `req_code` 트리거 |
| platform-docs 문서 표준 | `req_spec`·`sow` 장 구조와 표 컬럼, 등록부 모델 → `trace_links`, 품질 점검표 → lint 규칙. 내부 표기(모델 배정, `경로:줄`, 작업 ID)는 고객 문서에서 제거(DS-23) |
| admin-suite ERP | Phase 2 연동 대상 스키마(읽기만). 모놀리스에서는 사용 불가 |

- 원천 위치(참고용): flora v1 `D:\WorkSpace\platform\flora\`, SellingDocs `D:\WorkSpace\platform\구현해야 할 프로젝트\SellingDocs\`(flora-publishing 개발 방법 14절과 같은 경로), flora-publishing 기획 `D:\WorkSpace\platform\docs\products\flora-publishing\`.
- 원천의 `.env*`, `node_modules`, venv, 잡파일, `f5-tts/`는 새 저장소로 복사하지 않습니다. 실수로 원천 `.env` 값을 복사·커밋했다면 해당 키를 즉시 재발급합니다(07장 5절 4번).
- 리뷰 "높음" 14건(SellingDocs 4, flora 10)의 차단 설계는 비보안 7건 `02_ARCHITECTURE.md` 6절, 보안·데이터 7건 `05_DATA_MODEL.md` 7절에 있습니다. 해당 task의 리뷰 단계에서 차단 여부를 확인합니다. FortuneDocs·Flora-v2의 높음은 제외 대상입니다(`README.md` 2.1절).
- 폐기 목록 DS-01~DS-27(예: Word 호환 .doc 내보내기, Typst, ePub, 페르소나 60종, F5-TTS, n8n 전역 키, 단일 JSON 일괄 생성, Vercel 안 WeasyPrint, QuickChart, Stripe, `'1234'` 잠금해제, mock 폴백, 실키 `.env`)는 옮기지 않습니다(07장 3절). 복사 금지 결함은 07장 4절입니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| core 코드 위치 | 인증, 조직, 결제, 크레딧, AI 게이트, 음성 어댑터는 `apps/web/src/lib/server/` 아래 영역별 단일 소유(http 012, pricing·features 013, pii 015, totals 016, sanitize 028, ai 033 등, `06_AGENT_PLAN.md:23`)로 모읍니다. 다음 제품에서 재사용하거나 공용 패키지로 뺄 수 있게 합니다. `apps/api/app/ai/`의 공용 부분은 DC-06-006만 씁니다 |
| 코어 재정의 금지 | auth, org, credits, toss, webhooks, oauth, weasyprint render, storage, audit, jobs, compliance, ai-gateway, ai-service, dify, core-voice, llm-wiki는 import·호출만(`CLAUDE.md` 2절) |
| LLM·음성 키 | LLM 키는 `apps/api`에만. ElevenLabs 키와 서명 개인키(`AI_TOKEN_PRIVATE_KEY`)는 web 서버에만. 워커에는 LLM 키가 없습니다(기동 검사) |
| PDF 렌더 서비스 | 공용 `services/render-weasyprint`는 flora-publishing 소유입니다. nomad-docs는 워커가 `render.pdf`/`render.docx`를 enqueue하고 private network로 호출(`RENDER_SERVICE_URL`, `X-Render-Token`)만 합니다. web(Vercel) 코드에 렌더 호출 0. 단독 개발에서 렌더 서비스가 아직 없으면 DC-06-029의 PDF 경로가 막힙니다. flora-publishing 개발 폴더의 렌더 서비스를 로컬 Docker로 띄워 쓰는 것을 제안합니다(17절) |
| DOCX(C-1) | 렌더 서비스에 `POST /render/docx`, `app_id='docs'`, A4 공문서 프리셋(머리말·꼬리말, "n / N", 간인), DOCX 경로 폰트 검사가 반영되기 전에는 DOCX 요청을 403 `format_unavailable`로 둡니다. PDF는 기존 `/render/pdf`로 진행 |
| 3D 키트 | 로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 측정은 `packages/ui-3d`로 분리 가능하게 만듭니다(C-9). 그 전에는 같은 인터페이스로 `hero3d/` 안에 둡니다 |
| 남은 코어 과제 | C-1 DOCX·A4 프리셋(029), C-3 모듈러 seed의 docs 행(001은 조각 보충으로 진행), C-5 팀 조직(W8), C-6 웹훅 재시도 표준(053), C-7 교차 스키마 읽기(055), C-8 `adjust_credits`(047 환불, 반영 전 수동 기록), C-9 3D 키트(045), C-10 공용 Dify `docs-chat`·대화 삭제 절차(034, 051), C-11 ai-service `dify.aux` 모델 해석·위키 사용자 편집 저장(034, 035), C-2 조직 API 키(Phase 3). `docs/file/01-관리/06_AGENT_PLAN.md` 6절 참고 |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md`의 수용 기준 충족 + 대응 테스트 작업 녹색 + 리뷰 추적성 표에 끊긴 곳 없음 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전에 `bash _shared/check-invariants.sh`가 PASS여야 합니다.
- MVP 완료는 `06_AGENT_PLAN.md` 7절 완료 정의를 따릅니다. 단독 개발에서 확인할 명령은 다음과 같습니다.

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트·단위 | `npm run lint && npx tsc --noEmit && npm run test && npm run build`(web, worker). Vitest에 효과 엔진 속성 테스트(DC-06-019) 포함 |
| Python | `pytest apps/api -k docs`, `ruff check apps/api` |
| SQL(모놀리스) | `check.mjs --vector mono 0001 0002 seed` OK(7.2절), `node scripts/nomad-docs/to-monolith.mjs --check` 불일치 0 |
| SQL(모듈러) | platform `_tools-sqlcheck`에서 `node check.mjs --vector mod <0000~0009> seed.sql 2300_docs.sql` OK |
| 타입 | `supabase gen types typescript --local --schema public` 결과가 커밋본과 같음(CI 비교) |
| RLS 스모크 | `node scripts/nomad-docs/rls-runner.mjs --target mono`(필수), `--target mod`(모듈러 정본 확인) 105항목 + 추가 항목 전부 통과 |
| 결제 E2E | `npx playwright test e2e/billing` 5개 시나리오(Toss 테스트 키) |
| 핵심 플로우·AI | `npx playwright test e2e/flows e2e/ai`, `pytest apps/api/tests/docs/security`. 평가셋(hybrid 20, 검색 30, 채팅 30, 추출 10)을 상용·오픈소스 두 경로로 통과. `meeting_minutes`·`docs.minutes` 상용 호출 0 |
| 고위험 문서 | `dev_contract` 생성의 LLM `ai_usage` 0, D-3 법무 검토 완료 전 배포 대상에서 `doc_types.is_active=false` |
| 3D·디자인 시스템 | `HERO_3D.md:70-75` 수용 기준, DC-06-011 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 인증 단계 | Stage A: CI 인증 검사(DC-06-007)와 DC-06-014 수용 기준. Stage B: `AUTH_ROADMAP.md` 5.3절 B-1~B-6(DC-06-063, Google 실로그인은 수동 점검표). 19장 |

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| 계약서와 변호사법 | 문서 자동 작성이 변호사법상 비변호사의 법률사무 취급 금지 규정과 충돌하는지 미확인입니다(`01_PRD.md:390`). D-3 법무 검토 전에는 `dev_contract`를 배포 대상에서 비활성으로 두고, 템플릿만·AI 조항 생성 없음·개별 사안 판단 없음·채팅의 법률 판단 거절을 유지합니다. 표준계약서 원문 출처·이용 조건도 미확인(D-8)이라 조항은 운영자 작성분만, `source_note` 필수입니다 |
| seed의 계약서 활성 상태 | 2026-10-14에 seed를 비활성으로 고쳤습니다(8절). 운영에서 켤 때는 D-3 법무 검토 기록이 먼저입니다 |
| DOCX 의존성 | DOCX와 A4 공문서 프리셋은 공용 렌더 서비스 확장(C-1, flora-publishing 소유)에 달려 있습니다. 반영 전에는 DOCX 403 `format_unavailable`, Pro 요금 표의 DOCX 제공 문구는 반영 시점에 맞춰 확인합니다 |
| 렌더 서비스 부재 | 단독 개발 시점에 공용 렌더 서비스가 없을 수 있습니다. PDF 내보내기(029), 한글 골든(026), 패키지 ZIP이 막히므로 flora-publishing 렌더 서비스를 로컬로 띄우거나 W4 전에 운영 상태를 확인합니다 |
| HubSpot API | 엔드포인트, 스코프, 서명 헤더·알고리즘, 이벤트 id 필드, 레이트 한도, 앱 등록 절차가 모두 미확인입니다(`04_API.md:193-228`). DC-06-054는 공식 문서 확인 기록을 수용 기준으로 둡니다(Phase 2) |
| 제3자 음성(회의) | 회의 녹음 STT·전사본 그래프는 오픈소스 강제, 녹음 전 매번 고지, 원본 24시간 삭제. 오픈소스 서버 장애 시 상용 대체 없이 실패·환불합니다(D-11) |
| 고객 RFP 기밀성 | 추출은 오픈소스 우선, 임베딩은 `oss-embed` 고정, 업로드 텍스트는 LLM 전송 전 주민등록번호 마스킹, 원본 90일(D-10 제안), 인젝션 방어 문구 고정 |
| 숫자 무결성 | 금액·VAT·문서번호·요구사항 코드는 DB가 만듭니다. LLM·클라이언트 숫자를 저장하거나 조용히 고치는 코드 경로는 수용 기준 미달입니다 |
| AI·음성 비용 | 크레딧 선차감·정산·환불, 오픈소스 우선 라우팅으로 관리합니다. 요금·단가는 전부 제안값이라 베타 2주 원가 측정으로 확정합니다(D-4) |
| 작업 수와 범위 | 65개(인증 단계 3개 포함)로 권장 15~40개를 넘습니다(`06_AGENT_PLAN.md:15`). 사람 비주얼 검토(DC-06-010)가 화면 작업 전체의 병목이므로 W1-D를 일찍 시작합니다. 첫 검증만 빠르게 하려면 `06_AGENT_PLAN.md` 1.2.3절 축소 릴리스(v0, 작업 20개 안팎)를 먼저 고려합니다 |
| 국외 이전과 개인정보 | 동의 전 국외 제공자 사용 금지, 주민등록번호 입력란 없음과 서버 PII lint, 녹음 기본 미저장 |
| 비밀키 | `.env*`는 커밋하지 않습니다. 서명 개인키는 Next.js 서버에만 둡니다. 키 값을 로그·문서·위키에 쓰지 않습니다 |
| 기획 변경 | 산출물 갱신 task로 처리합니다. 묶음을 다시 만들려면 `build_root.py`에 nomad-docs 등록을 먼저 추가합니다(5.1절) |
| AI에게 범위 없이 맡기기 | `DESIGN_SYSTEM.md` 7장 금지 사항. 맡기는 크기는 검증할 수 있는 크기까지입니다 |

## 18. 체크리스트

- [ ] 2절 도구 설치 확인(Git Bash, jq, Python, Node 20·npm, uv, Supabase CLI, Docker)
- [ ] setup 스크립트 dry-run으로 할 일 확인
- [ ] setup 스크립트 실행, 무결성 점검 PASS
- [ ] (선택) 고문 모델을 Opus로 쓸 경우 `plan-challenger.md`를 `model: opus`로 변경(3절)
- [ ] `_shared/project-profile.md` 작성(6절), `claude` 실행 후 `/agent-check`
- [ ] 공용 인프라 준비: Dify, 오픈소스 LLM·임베딩·음성 서버(또는 모의 서버), 공용 렌더 서비스 확인
- [ ] `supabase start` → `supabase db reset` 성공, 라우팅 13행·강제 오픈소스 3행·MVP 활성 유형 8종(계약서 비활성) 확인(7.1절)
- [ ] PGlite 체커 `--vector mono` OK(7.2절), RLS 스모크 105항목 수동 또는 러너로 확인(7.3절)
- [ ] 결정 D-1~D-20 확정, 특히 D-3 계약서 게이트와 seed 처리안 기록, 산출물 "승인" 전환(8절)
- [ ] W0 task 생성과 진행(9절)
- [ ] 시각 레퍼런스(Awwwards·Dribbble) 링크를 열어 확인하고 브리프·토큰 플랜과 대조(13.5)
- [ ] 디자인 시스템 1~4단계 완료(13.1). 사람 비주얼 검토 포함
- [ ] Stage A: 시드 페르소나로 로컬 로그인 확인(19.2절)
- [ ] W1~W6 진행 후 G1 판정과 `[DECISION] G1 통과` 기록(19.3절)
- [ ] W7: Stage B(DC-06-063) 먼저, 이어서 통합·E2E·AI 보안 회귀(058), 공개 베타 출시 조건 충족
- [ ] 공개 베타 2주 뒤 G2 판정, C1·C2(19.5~19.7절)
- [ ] `dev_contract` 활성은 법무 검토 완료 후에만

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(확정 결정 22, 2026-10-14. 이 묶음에 아직 없으면 `build_root.py`로 묶음을 다시 만든 뒤 들어옵니다. 원본은 `D:\WorkSpace\platform\docs\products\_platform-core\AUTH_ROADMAP.md`). 제품 반영: `docs/file/02-요구사항/01_PRD.md` DC-F-001·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `07_SOURCE_MIGRATION.md` 6절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙".

처음에는 Mock 로그인으로 모든 MVP 기능을 완성하고, 기능이 안정되면 Google 로그인(+ 이메일)을 붙이고, 그것이 안정되면 카카오·네이버를 붙입니다. 세션은 처음부터 실제 Supabase JWT이므로 단계가 바뀌어도 권한·RLS·크레딧·효과 엔진 코드는 바뀌지 않습니다. 이 제품은 가입 개방(open)이고 로그인하는 사람은 프리랜서·에이전시입니다. 경로의 `apps/web/`은 기획서의 `web/`(`apps/nomad-docs/`)입니다(5.2절).

### 19.1 단계 요약

| 단계 | 언제 | 켜지는 로그인 | 작업 | 끝나는 조건 |
|---|---|---|---|---|
| A Mock | W0부터 W6까지(MVP 기능 개발) | 로컬 시드 페르소나 원클릭 로그인. 상단 배지 `MOCK AUTH · 로컬 전용` | DC-06-014(W2) | G1(19.3절) |
| B Google | G1 통과 후, 공개 베타 전(W7 맨 앞) | Google + 이메일(가입·메일 인증·재설정), 첫 OAuth 로그인 뒤 `/onboarding/terms` | DC-06-063(P0, Fable, M) | G2(19.5절) |
| C1 카카오 | G2 통과 후(W8) | 카카오(Supabase 기본 제공자) | DC-06-064(P1, Opus, S) | `AUTH_ROADMAP.md` 7.1.3절 |
| C2 네이버 | G2 통과 후(W8, C1과 병렬) | 네이버(`custom:naver` 또는 서버 브리지) | DC-06-065(P1, Fable, M) | `AUTH_ROADMAP.md` 7.2.4절 |

### 19.2 Stage A 로컬 실행 순서

| 순서 | 명령·행동 | 설명 |
|---|---|---|
| 1 | `supabase start` | 로컬 Supabase(`http://127.0.0.1:54321`) |
| 2 | `supabase db reset` | 마이그레이션과 seed 적용(7.1절) |
| 3 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<임의의 긴 값>` | 커밋하지 않습니다. `NEXT_PUBLIC_*`에 넣지 않습니다. `NEXT_PUBLIC_SUPABASE_URL`이 로컬이 아니면 web이 기동하지 않습니다 |
| 4 | `node scripts/dev/seed-users.mjs --app docs` | 페르소나 owner, admin, member, viewer, outsider, no_app, suspended, ops와 제품 훅의 pro(제안)를 만듭니다. 원격 URL이면 즉시 종료, 두 번 실행해도 크레딧 1회. 비밀번호는 출력하지 않습니다. 단독(모놀리스) DB라 `no_app`도 가입 트리거가 바로 엔타이틀먼트를 줍니다(`05_DATA_MODEL.md` 10.3절) |
| 5 | `npm run dev` 후 `/login` | 개발용 패널에서 페르소나 버튼을 누릅니다. 첫 로그인은 `/onboarding/ai`(owner) → `/onboarding/company`(자사 정보가 빈 조직의 owner/admin) → `/app` 순서이고, 다음 로그인부터 `/app`입니다(`02_ARCHITECTURE.md` 9.6절) |
| 6 | E2E | Playwright `globalSetup`이 페르소나마다(`no_app` 제외) `/api/dev/login`을 호출해 `storageState`를 저장합니다. 온보딩 플로우는 `no_app` 첫 로그인으로 돌립니다(DC-06-057) |

페르소나별 기대 결과는 `docs/file/03-설계/05_DATA_MODEL.md` 10절입니다(예: `owner` 잔액 80 = 가입 50 + 월 30, `outsider`로 owner 조직 프로젝트·문서 0행). 권한 분기는 페르소나를 바꿔 로그인해서 확인하고, 기능 코드에서 페르소나 이메일로 분기하지 않습니다. 7.3절 RLS 스모크는 SQL 안 `-- AS` 역할 전환을 쓰므로 페르소나와 별개로 그대로 돌립니다.

### 19.3 G1 체크리스트 (사람이 판정)

- [ ] `06_AGENT_PLAN.md` 2절 MVP P0 기능 작업 완료(인증 B·C 작업과 W7의 056·057·058 공개 베타 마무리 제외)
- [ ] 핵심 플로우 E2E(DC-06-057) Mock 페르소나로 로컬 녹색
- [ ] RLS 스모크(DC-06-003) 전 항목 통과, `outsider` 교차 테넌트 거부
- [ ] 결제 E2E(DC-06-048) Toss 테스트 키로 녹색
- [ ] CI(DC-06-007): 인증 모듈 밖 `AUTH_MODE` 참조 0, `mock-auth`·`nomad_role`·`nomad_plan` 0, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패
- [ ] 외부 준비: Google Cloud 프로젝트, OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL `/legal/privacy`·`/legal/terms`, 승인된 도메인), 웹 클라이언트 ID, 운영 Supabase 프로젝트
- [ ] 결과를 DC-06-063 task `log.md`에 `[DECISION] G1 통과`로 기록

### 19.4 Stage B 외부 설정 순서 (`AUTH_ROADMAP.md` 5.1절)

| 순서 | 할 일 | 비고 |
|---|---|---|
| 1 | Google Cloud 콘솔 → OAuth 동의 화면: 사용자 유형 External, 범위 `openid`, `email`, `profile`만 | 게시 상태 "테스트"에서는 등록한 테스트 사용자만 로그인됩니다 |
| 2 | 사용자 인증 정보 → OAuth 클라이언트 ID(웹 애플리케이션). 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백입니다 |
| 3 | Supabase 대시보드 → Authentication → Providers → Google 사용, 클라이언트 ID·시크릿 입력. 로컬은 `supabase/config.toml` `[auth.external.google]`의 `env(GOOGLE_CLIENT_ID)` | 앱 env에는 넣지 않습니다 |
| 4 | Authentication → URL Configuration: Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(Vercel 미리보기 도메인은 명시 등록) | 와일드카드 지양 |
| 5 | 동의 화면을 "프로덕션"으로 게시 | 공개 베타 전 |
| 6 | 배포 env: `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email`, `DOCS_TERMS_VERSION`(제안) | 배포 체크리스트(B-6), `docs/nomad-docs/ops/auth-checklist.md` |
| 7 | 수동 점검표: 데스크톱·모바일 각 1회, 신규·기존 계정 | 결과를 task `log.md`에(B-5). 실제 Google 로그인은 자동화하지 않습니다 |

### 19.5 G2 체크리스트 (사람이 판정)

- [ ] Google 실로그인으로 공개 베타 운영 2주(제안)
- [ ] 인증 관련 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안, 감사 `auth.login`과 오류 로그)
- [ ] 가입 기간 신규 가입자 중 `entitled=false`로 남은 사용자 0(`AUTH_ROADMAP.md` 6장의 SQL을 단독 `public` 스키마에 맞춰 `app_id = 'docs'`로 실행)
- [ ] 카카오: 디벨로퍼스 앱 생성, 이메일 정책 D-18 확정(비즈 앱 전환 권장)
- [ ] 네이버: 애플리케이션 등록, 검수 신청 자료(로그인 버튼부터 가입 완료까지 화면 캡처) 준비
- [ ] 결과를 `[DECISION] G2 통과`로 기록

### 19.6 C1 카카오 설정 (`AUTH_ROADMAP.md` 7.1.1절)

| 순서 | 할 일 |
|---|---|
| 1 | 카카오 디벨로퍼스 앱 생성 → REST API 키 = `client_id` |
| 2 | 카카오 로그인 Client Secret 활성 → `client_secret` |
| 3 | Redirect URI = Supabase 콜백(`https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://localhost:54321/auth/v1/callback`) |
| 4 | 카카오 로그인 활성, 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email` |
| 5 | Supabase → Providers → Kakao 사용(로컬 `[auth.external.kakao]`). 이메일을 받지 못하면 "Allow users without an email"(D-18 (b)일 때만) |
| 6 | 배포 env `AUTH_PROVIDERS=google,email,kakao`, 설정 → 로그인 방법 화면(`/app/settings/login-methods`) 확인(`03_SCREENS_UX.md` 7.4절) |

### 19.7 C2 네이버 스파이크와 검수 (`AUTH_ROADMAP.md` 7.2.2절)

| 단계 | 할 일 | 통과 기준 |
|---|---|---|
| 1 | 운영과 분리한 Supabase 프로젝트에 관리자 API로 `custom:naver` 등록(`provider_type: 'oauth2'`, authorize·token·`/v1/nid/me` 엔드포인트). 등록은 `scripts/auth/register-naver-provider.mjs`(제안)로 남깁니다 | 등록 성공 |
| 2 | 네이버 "개발 중" 상태 + 등록한 테스트 아이디로 `signInWithOAuth({ provider: 'custom:naver' })` | 로그인 성공, `identities[].provider = 'custom:naver'` |
| 3 | `auth.users.email`이 채워졌는지, 재로그인이 같은 사용자인지 | 둘 다 참이면 `supabase_custom` 채택 |
| 4 | 실패하면 브리지 경로(`04_API.md` 8절 `/auth/naver/start`·`/auth/naver/callback`)를 택하고 코어 요청 C-13(`staged/0010_core_auth_identity_links.sql` 적용, 사람이 승인). 결과를 `NAVER_AUTH_PATH`와 `[DECISION]`에 기록 | 기록 |
| 5 | 네이버 검수 신청(로그인 버튼부터 가입 완료까지 화면 캡처). 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다(C2-6) | 검수 통과 |

로컬 Supabase CLI가 커스텀 제공자를 지원하는지는 미확인입니다. 지원하지 않으면 로컬은 Mock·Google·카카오로 개발하고 네이버는 스테이징 프로젝트에서 확인합니다.

### 19.8 단계 전환 요청 프롬프트 예시 (G1 통과 후 Stage B)

베이스 `_templates/dev-request-prompt.md` 형식을 따르며 9.4절 예시를 본떴습니다.

```
D:/WorkSpace/DEV/nomad-docs/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.
(이미 읽은 파일은 skip. 특히 docs/file/03-설계/공용코어/AUTH_ROADMAP.md 0·3·5장과 06_AGENT_PLAN.md 8절, 02_ARCHITECTURE.md 9절)

[요구사항]
DC-06-063: 인증 Stage B(Google OAuth + 이메일 가입·메일 인증·비밀번호 재설정)로 전환한다.
전제 = log.md 에 [DECISION] G1 통과 기록이 있다(없으면 시작하지 않고 보고).
완료 조건 = ① AUTH_ROADMAP.md 5.3절 B-1~B-6 ② /login 에 Google 버튼 + 이메일 폼, /signup·/reset-password 구현
③ /auth/callback 이 finishLogin(코드 교환 → session_context('docs') → bootstrap_app_for_org 1회 → status 분기
→ 워크스페이스 보장 → next 화이트리스트)을 거친다
④ 첫 OAuth 로그인은 /onboarding/terms → /onboarding/ai → /onboarding/company 순서(02_ARCHITECTURE.md 9.6절, 03_SCREENS_UX.md 7.3절)
⑤ 메일 인증 전 생성 요청 403 email_not_verified
⑥ Mock E2E(DC-06-057)가 계속 녹색이고 배포 빌드에서 /api/dev/login 404
⑦ 06_AGENT_PLAN.md 의 DC-06-063 수용 기준 충족.

[작업의 특성]
권한 경계 작업. 단계 분기는 apps/web/src/lib/auth/, (auth)/, auth/ 안에서만. Google 콘솔·Supabase 대시보드 설정은 사람이 하고(AUTH_ROADMAP.md 5.1절) 에이전트는 체크리스트만 만든다.
작업 대상 경로: apps/web/src/app/(auth)/, apps/web/src/app/auth/callback/, apps/web/src/app/onboarding/terms/, apps/web/src/features/onboarding-terms/,
apps/web/src/app/api/terms/, apps/web/src/lib/auth/onboarding.ts, supabase/config.toml([auth.external.google]·additional_redirect_urls만), docs/nomad-docs/ops/auth-checklist.md

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
| A | DC-06-014(범위 변경: Mock 로그인, 시드, 가드, `finishLogin`, 온보딩 경로, 회사 정보 온보딩) | P0, M, Fable | W2 |
| B | DC-06-063 | P0, M, Fable | W7 맨 앞(G1 후) |
| C1 | DC-06-064 | P1, S, Opus | W8(G2 후) |
| C2 | DC-06-065 | P1, M, Fable | W8(G2 후) |

## 부록 A. 스크립트 없이 손으로 할 때

`nomad-docs-root` 폴더 자체가 아니라 **그 안의 `docs`, `supabase`, `infra`, `.claude` 폴더**를 `D:\WorkSpace\DEV\nomad-docs\`에 붙여넣습니다.

| 동작 | Git Bash / Linux | Windows PowerShell | Windows cmd |
|---|---|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/nomad-docs"` | `Copy-Item "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-docs" -Recurse` | `robocopy "D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork" "D:\WorkSpace\DEV\nomad-docs" /E` |
| 2 이동 | `cd "D:/WorkSpace/DEV/nomad-docs"` | `Set-Location "D:\WorkSpace\DEV\nomad-docs"` | `cd /d "D:\WorkSpace\DEV\nomad-docs"` |
| 3 초기화 | `bash init-project.sh nomad-docs --reset-git` | `& "$env:ProgramFiles\Git\bin\bash.exe" init-project.sh nomad-docs --reset-git` | `"%ProgramFiles%\Git\bin\bash.exe" init-project.sh nomad-docs --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/nomad-docs/nomad-docs-root/." "D:/WorkSpace/DEV/nomad-docs/"` | `Copy-Item "D:\WorkSpace\platform\docs\develop\nomad-docs\nomad-docs-root\*" "D:\WorkSpace\DEV\nomad-docs" -Recurse -Force` 후 `.claude` 폴더도 같은 방법으로 복사 | `robocopy "D:\WorkSpace\platform\docs\develop\nomad-docs\nomad-docs-root" "D:\WorkSpace\DEV\nomad-docs" /E` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` | `Remove-Item docs\etc -Recurse -Force` | `rmdir /s /q docs\etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로 바꾸고(고문을 Opus로 쓸 경우 그대로 둠), `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`의 frontmatter에 `model: sonnet` 한 줄을 추가 | 같음(편집기 사용) | 같음 |
| 7 점검 | `bash _shared/check-invariants.sh` | `& "$env:ProgramFiles\Git\bin\bash.exe" _shared/check-invariants.sh` | `"%ProgramFiles%\Git\bin\bash.exe" _shared/check-invariants.sh` |

- 3단계의 `init-project.sh`는 bash 스크립트라 Windows에서도 Git Bash의 `bash.exe`로 실행합니다. `System32`나 `WindowsApps`의 `bash.exe`(WSL)는 쓰지 않습니다.
- Linux(Git Bash) 명령을 함께 싣는 이유는 베이스 도구(`init-project.sh`, `gate.sh`, `scope_check.sh`, `check-invariants.sh`)가 모두 bash 스크립트이기 때문입니다.
- Docker는 이와 별개로 필요합니다(Supabase 로컬, Dify, 오픈소스 서버, 렌더 서비스).
