# local-news(로컬뉴스 클라우드, 가칭) 개발 방법

작성일 2026-10-15. 이 문서는 `D:\WorkSpace\platform\docs\products\local-news\` 기획을 멀티에이전트 베이스(`D:\WorkSpace\DEV\MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겨 지역신문 SaaS 개발을 시작하는 방법을 처음부터 끝까지 안내합니다. 근거는 `경로:줄`로 표시하고, 근거가 없는 값은 "제안", 확인하지 못한 값은 "미확인"으로 표시합니다.

## 0. 한눈에 보기

**시작은 setup 스크립트 1개 실행입니다.** 둘 중 하나만 실행하면 됩니다.

| 환경 | 명령 |
|---|---|
| Windows PowerShell | `pwsh -File D:\WorkSpace\platform\docs\develop\local-news\setup-local-news.ps1` |
| Git Bash / Linux | `bash /d/WorkSpace/platform/docs/develop/local-news/setup-local-news.sh` |

먼저 `-DryRun`(PowerShell) 또는 `--dry-run`(Git Bash)으로 실행해 할 일을 확인한 뒤 실제로 실행하시길 권합니다.

```
D:\WorkSpace\platform\docs\develop\local-news\        platform에 남는 안내서, 도구, 재료
├── local-news_develop.md           이 문서(개발 폴더로 옮기지 않음)
├── setup-local-news.sh / .ps1      설치 스크립트
├── modules\                        공통모듈 개발서 8개 + README(20장)
└── local-news-root\                이 폴더 "안의 내용물"이 개발 폴더 루트에 들어갑니다
    ├── docs\  supabase\  infra\  .claude\
                │ setup 스크립트가 복사
                ▼
D:\WorkSpace\DEV\local-news\                            베이스를 복사해 만든 개발 폴더
├── docs\  supabase\  infra\  ← local-news-root에서 들어온 것
└── apps\  _shared\  _templates\  .claude\agents\  init-project.sh ...  ← 베이스에 원래 있던 것
```

| 단계 | 내용 | 절 |
|---|---|---|
| 준비 | 도구 설치, API 키, 공용 인프라 | 2 |
| 1~2 | setup 스크립트 실행(베이스 복사, 초기화, 묶음 붙여넣기, docs/etc 삭제, 에이전트 모델 지정) | 3, 4 |
| 3 | 최종 트리 확인 | 5 |
| 4 | project-profile 작성 | 6 |
| 5 | 로컬 DB 기동과 SQL 적용 | 7 |
| 6 | 착수 전 결정 확정 | 8 |
| 7 | 작업(56개)을 task로 변환 | 9 |
| 8 | 웨이브별 개발 사이클 | 10 |
| - | AI 계층, 개발 위키, 메인 디자인, 이관, 공용 모듈, 검증, 위험 | 11~17 |
| - | 체크리스트 | 18 |
| - | 인증 단계(편집국·독자) | 19 |
| - | 공통모듈 8개 개발 | 20 |
| - | 멀티테넌트(화이트라벨)와 도메인 | 21 |

## 1. 개요

| 항목 | 내용 |
|---|---|
| 제품 | 여러 지역신문사(인터넷 지역신문, 지역 주간·일간)가 구독하는 멀티테넌트 뉴스룸 SaaS. 편집국 콘솔(기사 작성·데스크 승인·홈 편집·광고·뉴스레터·법정 표기)과 신문사마다 자기 제호·도메인으로 열리는 독자 사이트, 플랫폼 운영 콘솔 |
| 앱 id / 스키마 | `news` / 단독 프로젝트는 `public`, 통합 DB는 `news`(번호 2500) |
| 이번 개발 방식 | 단독 Supabase 프로젝트 1개(01장 D-2 권고, README 5장) |
| 개발 근거 | `docs/file/`의 산출물(등록부 `docs/file/_index.md`). 공통모듈 기획서 9개는 `docs/file/03-설계/모듈/` |
| 테넌트 | 신문사 1곳 = `core.organizations` 1행. 화이트라벨은 Multi-tenant Theming(`resolve_tenant`, `tenant_themes`, `tenant_domains`) |
| 사용자 | 편집국(발행인·편집인·데스크·기자·기고자·광고담당), 독자(신문사별 `news.readers`, 조직 멤버 아님), 방문자, 플랫폼 운영자 |
| 폴더 대응 | 기획서의 `src/...`는 베이스의 `apps/web/src/...`, `worker/`는 새 폴더, `apps/api/`는 베이스의 `apps/api/` |

이 문서는 "어떻게 시작하고 진행하는가"를 다룹니다. "무엇을 만드는가"는 묶음 안의 산출물(`docs/file/`)이 정본입니다.

## 2. 사전 준비

| 도구 | 용도 | 확인 |
|---|---|---|
| Git for Windows(Git Bash), git, jq, Python 3 | 베이스 스크립트·무결성 점검 | `bash --version`, `jq --version`, `python --version` |
| Node.js 22 LTS + pnpm | `apps/web`, `worker` | `node -v; pnpm -v` |
| Python 3.12 + uv(제안) | `apps/api`(FastAPI) | `uv --version` |
| Supabase CLI, Docker Desktop | 로컬 DB, Dify, 오픈소스 음성·LLM 서버 | `supabase --version`, `docker version` |

**API 키와 계정**(서버 환경변수로만, `docs/file/03-설계/02_ARCHITECTURE.md` 8절): Supabase, 상용 LLM(Anthropic·OpenAI·Google, 신문사가 국외 이전에 동의할 때만), ElevenLabs(오디오 기사, 동의 시), 메일 발송 사업자(Resend 또는 Amazon SES, 결정 MD-1), Web Push VAPID 키, Cloudflare Turnstile(제보·정정 청구 폼, 제안), Vercel(와일드카드 서브도메인·커스텀 도메인 API). 독자 결제 Toss 키는 플랫폼이 아니라 **각 신문사가 자기 가맹 키**를 콘솔에 등록합니다(01장 D-4).

공용 인프라 설치 문서:

| 인프라 | 문서 |
|---|---|
| Dify(공용 1개) | `D:/WorkSpace/platform/docs/develop/_shared/dify/README.md` |
| 오픈소스 음성 서버 | `D:/WorkSpace/platform/docs/develop/_shared/voice/README.md` |
| 오픈소스 LLM 서버와 상용 키 | `D:/WorkSpace/platform/docs/develop/_shared/llm/README.md` |
| 소셜 로그인 지시서 | `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md` |

## 3. 1단계: 베이스 복사와 초기화 (setup 스크립트가 처리)

| 순서 | 동작 |
|---|---|
| 1 | 베이스 원본을 `D:\WorkSpace\DEV\local-news`로 복사 |
| 2 | **복사본 안의** `init-project.sh local-news --reset-git` 실행 |
| 3 | `local-news-root` 안의 내용물(`docs`, `supabase`, `infra`, `.claude`)을 복사본 루트에 붙여넣기 |
| 4 | 복사본의 `docs/etc` 삭제 |
| 5 | 에이전트 모델 지정(9.2절) |
| 6 | 무결성 점검(`_shared/check-invariants.sh`) |

**주의: 반드시 복사본 안의 스크립트를 실행합니다.** 베이스 원본 폴더의 `init-project.sh`를 실행하면 원본이 초기화됩니다.

## 4. 2단계: 묶음 붙여넣기 (setup 스크립트가 처리)

- `local-news-root` 폴더 자체가 아니라 그 안의 내용물이 개발 폴더 루트에 들어갑니다. 덮어쓰는 파일은 `docs/file/_index.md` 하나입니다.
- 공통모듈 개발서(`develop/local-news/modules/`)는 묶음에 들어가지 않습니다. 20장의 절대경로로 엽니다.
- 손으로 하는 방법은 부록 A.

## 5. 3단계: 이관 경로와 최종 트리

### 5.1 이관 경로 (원본 기준 `D:\WorkSpace\platform\`)

| 원본 | 개발 폴더 안 경로 | ID | 산출물명 |
|---|---|---|---|
| `docs/products/local-news/README.md`, `06_AGENT_PLAN.md` | `docs/file/01-관리/` | DOC-MGT-001, 002 | 제품 개요, 작업 계획 |
| `docs/products/local-news/01_PRD.md` | `docs/file/02-요구사항/01_PRD.md` | DOC-REQ-001 | 요구사항정의서 |
| `docs/products/local-news/02~05_*.md` | `docs/file/03-설계/` | DOC-DES-001~004 | 아키텍처·화면·인터페이스·데이터 설계서 |
| `docs/products/local-news/modules/` 9개(M1~M8, README) | `docs/file/03-설계/모듈/` | DOC-MOD-001~009 | 공통모듈 기획서 |
| `docs/products/_platform-core/` 9개 | `docs/file/03-설계/공용코어/` | DOC-CORE-001~009 | 공용 코어 명세(AUTH_ROADMAP = DOC-CORE-009) |
| `docs/products/_design-guide/` 5개 + DASHBOARD_PATTERNS | `docs/file/03-설계/디자인/` | DOC-DSN-001~005, 008 | 디자인 기준 |
| (생성) DESIGN.md, COMPONENTS.md | `docs/file/03-설계/디자인/` | DOC-DSN-006~007 | 03장 3.9절 초기값에서 생성 |
| `docs/products/local-news/CLAUDE.md`, `07_SOURCE_MIGRATION.md` | `docs/file/04-구현/` | DOC-IMP-001, 002 | 개발지침, 이관 계획 |
| `docs/products/local-news/research/` 2개 | `docs/reference/research/` | 참고 | 언론사 디자인 벤치마크, 시장·법규 조사 |
| `docs/products/local-news/supabase/monolith/` | `supabase/migrations/20261013000001~3_*.sql`, `supabase/seed.sql`, `supabase/tests/rls_smoke.sql` | - | DB(core_lite, tenant_theming, local_news_domain) |

- 복사하지 않은 파일(통합 DB 조각 `2500_news.sql`, `Multi-tenant_Theming/`, 스모크 러너 `run-smoke.mjs`, 변환 스크립트)은 `D:/WorkSpace/platform/...` 절대경로로 엽니다.
- 경로 검사: `build_root.py --check local-news`(결과는 17장 아래 표).

### 5.2 최종 트리 (setup 실행 후 `D:\WorkSpace\DEV\local-news\`)

```
D:\WorkSpace\DEV\local-news\
├── CLAUDE.md  init-project.sh  _shared\  _templates\  .claude\agents\      [베이스]
├── .claude\skills\llm-wiki\SKILL.md                                         [베이스]
├── apps\web\   apps\api\                                                    [베이스] 코드 없음(W0 스캐폴딩)
├── docs\
│   ├── file\_index.md, 01-관리\, 02-요구사항\, 03-설계\(공용코어\, 디자인\, 모듈\), 04-구현\   [묶음]
│   ├── reference\00_MERGE_ANALYSIS.md, research\                           [묶음]
│   └── wiki\                                                                [묶음] 개발 위키
├── infra\dify\README.md                                                     [묶음]
└── supabase\migrations\(3개), seed.sql, tests\rls_smoke.sql                 [묶음]
```

## 6. 4단계: project-profile 작성

| 항목 | 값 | 근거 |
|---|---|---|
| 웹 | Next.js 16.2.x(App Router), React 19.2, TypeScript, Tailwind CSS v4(4.x 고정), shadcn/ui | `docs/file/03-설계/02_ARCHITECTURE.md` 1절 |
| 워커 | TS 워커(Railway, 제안), 큐 6개 | 02장 4절 |
| API | FastAPI(Python 3.12 제안), LangChain·LangGraph | 02장 5절 |
| DB | Supabase(Postgres 15 + pgvector), 단독 프로젝트, `public` 스키마 | 05장 8절 |
| 렌더 | 독자 사이트 ISR + 캐시 태그, 와일드카드 서브도메인 + 커스텀 도메인(Vercel) | 02장 7·10절 |
| 검증·테스트 | zod, pydantic, Vitest, Playwright, axe, pytest, Lighthouse CI | 06장 7절 |
| 명령 | `pnpm install / dev / build / lint / typecheck / test:e2e / test:perf`, `pnpm db:types`, `uv sync`, `pytest apps/api`, `supabase start`, `supabase db reset` | 제안 |
| 모델 핀 | claude-main `claude-opus-5-5`, claude-reviewer `claude-sonnet-5-5`(변경하지 않음) | 베이스 `_shared/backends.json` |

## 7. 5단계: 로컬 DB

| 순서 | 명령 | 설명 |
|---|---|---|
| 1 | `supabase init`(config가 없을 때만) | 외부 로그인 제공자는 모두 끔(Stage A) |
| 2 | `supabase start` | 로컬 Supabase |
| 3 | `supabase db reset` | core_lite → tenant_theming → local_news_domain → seed 순서 |
| 4 | `pnpm db:types` | 타입 생성 |
| 5 | `node scripts/dev/seed-users.mjs --app news` | 시드 페르소나(19.2절) |

- 기획 단계 검증(PGlite): 모듈러·모놀리스 적용 OK, RLS 스모크 314/314(두 대상). 명령은 `docs/file/03-설계/05_DATA_MODEL.md` 9절. 실제 Supabase에서 한 번 더 확인하는 것이 NW-06-001·003의 수용 기준입니다.
- 모놀리스 `0003`은 통합 조각 `2500_news.sql`의 변환본입니다. SQL을 고칠 때는 조각을 고치고 변환 스크립트 `D:/WorkSpace/platform/docs/products/local-news/supabase/tools/to_monolith.py`로 다시 만듭니다(NW-06-001이 앱 저장소 `scripts/db/`로 옮김).
- 스모크 러너: `D:/WorkSpace/platform/docs/products/local-news/supabase/monolith/tests/run-smoke.mjs`(`--target mono|mod`).
- 원격 `supabase db push`는 사람이 확인 후 실행합니다.

## 8. 6단계: 착수 전 결정 확정

`docs/file/02-요구사항/01_PRD.md` 8절의 결정 D-1~D-18을 확정합니다. 기획은 각 항목의 "권고"를 가정으로 작성돼 있습니다.

| ID | 결정 | 확정 시점 |
|---|---|---|
| D-1 | 제품 브랜드명 | 마케팅 랜딩(NW-06-040) 전 |
| D-2 | 1차 DB(단독 프로젝트 권고) | 착수 전(이 문서는 단독 기준) |
| D-3 | 독자 로그인 도메인(서브도메인 와일드카드 + 커스텀 도메인 개별 등록 권고) | NW-06-039 전 |
| D-4 | 독자 결제(신문사 자기 Toss 가맹 권고) | NW-06-024 전 |
| D-5 | 가격과 독자 결제 수수료 | 공개 베타 전(`D:/WorkSpace/platform/docs/Price_Plans/local-news/PRICE_PLAN.md`) |
| D-6 | 댓글 기본값(기본 끔 권고) | NW-06-031 전 |
| D-7 | 검색 엔진(Postgres 권고) | NW-06-035 전 |
| D-8 | 날씨·미세먼지·공고 외부 API | NW-06-036 전 |
| D-9 | AI 보도자료 초안 표시와 자체기사 비율 규칙 | NW-06-043 전 |
| D-10 | 기존 CMS 이관 범위·가격 | NW-06-018 전 |
| D-11 | 3D 히어로(독자 사이트 미적용 권고) | NW-06-040 전 |
| D-12 | 지역신문발전기금 연계 영업 | 영업 시작 전 |
| D-13~D-18 | 인증 결정(카카오 이메일, 네이버 경로, 독자 이메일 방식, 공통 계정 처리자, 편집국 카카오·네이버, 독자 개인 조직) | 19장 시점 |

## 9. 7단계: 작업을 task로 변환

### 9.1 작업과 웨이브 (정본: `docs/file/01-관리/06_AGENT_PLAN.md` 2~3절)

작업은 NW-06-001~056, 모두 56개입니다. 그중 NW-06-009는 사람이 하는 디자인 비주얼 검토입니다.

| 웨이브 | 작업 ID | 진입 조건 | 산출물 |
|---|---|---|---|
| W0 | 001, 002, 007 | 없음 | DB 적용, 골격, 디자인 레퍼런스 |
| W1 | 003, 004, 005, 006, 008, 041 | W0 | RLS CI, 인증 Stage A, 테넌시 연결, 금지 검사, 토큰·컴포넌트, AI 서비스 |
| W1-D | 009 → 010 | 008 | 사람 비주얼 검토, 코드 정답 확정. 화면 작업의 진입 조건 |
| W2 | 011, 017, 042 | W1 | M1 서버, 개설 신청·승인, AI 게이트 |
| W3 | 012, 014, 015, 020, 022, 037 | 011, 010 | 에디터·데스크, 미디어, 분류·구성원, 독자 홈 템플릿, 법정 표기, 게시 파이프라인 |
| W4 | 013, 021, 025, 034, 039, 043, 044 | W3 | 홈 편집, 독자 사이트, 광고, 준수 데스크, 브랜딩·도메인, AI 기사 보조·어시스턴트 |
| W5 | 016, 018, 023, 030, 033, 035, 036, 040, 045 | W4 | 라이브, 이관, 독자 가입, 제보, 배포·SEO, 검색·분석, 지역 생활, 랜딩, 음성 |
| W6 | 019, 024, 026, 027, 028, 031, 032, 038 | W5 | 내보내기, 독자 결제, 업소·공고, 외부 광고망, 뉴스레터, 댓글, 경조사, 운영 콘솔 |
| W7 | 052·053(G1 후 먼저), 029, 046, 047, 048, 049, 050, 051 | W6 + G1 | 로그인 전환, 웹 푸시, AI 회귀, E2E, 결제 E2E, 성능·시각 회귀, 문구. **공개 베타 조건** |
| W8 | 056, 054·055(G2 후) | 공개 베타 후 | 운영 문서, 카카오·네이버 |

### 9.2 모델과 에이전트 매핑 (주 Opus, 부 Sonnet, 고문 Fable)

모델 비율(06장 4절, 모델 작업 55개): Fable 13(23.6%), Opus 23(41.8%), Sonnet 15(27.3%), Haiku 4(7.3%). 규모 가중은 Fable 23.3%, Opus 46.6%, Sonnet 26.7%, Haiku 3.4%입니다. 토큰을 아끼려면 task마다 06장 해당 행과 관련 절만 baseline으로 주고, 화면·반복 작업은 Sonnet·Haiku에 맡깁니다.

| 06장 권장 모델 | 작업 성격 | 베이스에서 맡는 쪽 |
|---|---|---|
| Fable | DB·RLS(001, 003), 인증(004, 052, 053, 055), 테넌트 해석(005), 개설 승인(017), 독자 결제(024, 048), AI 보안(041, 042, 046) | 오케스트레이터가 설계, `plan-challenger`(Fable)가 착수 전 검토, 구현은 `supabase-expert`·`fastapi-expert`·`nextjs-expert`(Sonnet) |
| Opus | 모듈 서버·API, AI 그래프·RAG, 워커, 테스트 설계 | `claude-main`(Opus) 설계 → expert(Sonnet) 구현 |
| Sonnet | 독자 사이트·편집국 화면, 디자인 시스템, 랜딩 | `nextjs-expert`(Sonnet) |
| Haiku | 골격, 린트, 문구, 운영 문서 | 오케스트레이터 직접 처리 |
| 사람 | 디자인 비주얼 검토(009), 법무 확인, G1·G2 판정 | 사용자 |

### 9.3 task 폴더 만들기

웨이브 단위로 task 폴더를 만들고 작업 1개를 task 1개로 둡니다(베이스 `_templates/task-folder.md`). baseline 예:

```yaml
baseline:
  - id: DOC-DES-004
    path: docs/file/03-설계/05_DATA_MODEL.md
  - id: DOC-MGT-002
    path: docs/file/01-관리/06_AGENT_PLAN.md   # 해당 작업 행
  - id: DOC-MOD-001
    path: docs/file/03-설계/모듈/M1_newsroom-cms.md
```

### 9.4 요청 프롬프트 예시 (W2 M1 서버, 베이스 `_templates/dev-request-prompt.md` 형식)

```
D:/WorkSpace/DEV/local-news/docs/file 의 산출물 중 baseline 으로 지정한 파일만 읽고 분석한다.
(06_AGENT_PLAN.md 의 NW-06-011 행, 04_API.md 2.2·3절, 05_DATA_MODEL.md 2·3·4절, 모듈/M1_newsroom-cms.md)

[요구사항]
NW-06-011: M1 서버(기사 저장·제출·검토·예약·게시·게시 취소·정정 RPC 래퍼, 수정 이력, 미리보기 토큰)를 만든다.
완료 조건 = 06_AGENT_PLAN.md NW-06-011 수용 기준 전부, 단위 테스트, RLS 스모크 녹색 유지.

[작업의 특성]
작업 대상 경로: apps/web/src/modules/newsroom-cms/server/, apps/web/src/app/api/newsroom/articles/
SQL 변경이 필요하면 고치지 말고 log.md 에 NW-06-001 요청으로 남긴다.

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남기고 종료 시 [DECISION-SUMMARY] 로 정리한다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 nextjs-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 review-expert 가 진행한다.
```

## 10. 8단계: 웨이브별 개발 사이클

| 순서 | 내용 | 도구 |
|---|---|---|
| 1 | 웨이브 시작 전 해당 결정(8절) 확정, 산출물 "승인" 확인 | `_index.md` |
| 2 | task 생성, baseline·`workers_approved`·`write_scope` 기록 | `_templates/task.md` |
| 3 | 착수 전 계획 검토(Fable 작업만 고문 검토, 토큰 절약) | `plan-challenger` |
| 4 | 구현, `gate.sh`·`scope_check.sh` 전후 실행 | 도메인 expert |
| 5 | 리뷰: 요구사항 → 설계 → 구현 → 테스트 추적성 | `claude-reviewer`, `review-expert` |
| 6 | 개발 위키 갱신 | `llm-wiki` 스킬 |
| 7 | 완료: 웨이브의 모든 task가 끝나면 다음 웨이브 | - |

- **공개 베타 조건**: W7까지 완료(G1 판정 후 Stage B 052·053 포함), AI 보안 회귀(046) 통과, 성능 예산(049) 통과, `06_AGENT_PLAN.md` 7절 완료 정의.
- 구현이 산출물과 달라지면 코드를 조용히 맞추지 말고 산출물 갱신 task를 따로 만듭니다.

## 11. AI 계층 구축 (local-news)

정본: `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, 제품 `02_ARCHITECTURE.md` 5절, `04_API.md` 2.4·6절.

| 구성 | 내용 | 작업 |
|---|---|---|
| FastAPI AI 서비스 | `apps/api/app/ai/products/news/` 설정, 서명 토큰 검증, 라우팅 seed 14행 | NW-06-041 |
| AI 게이트 | 편집국 호스트만 `/api/ai/*`, `/api/voice/*`. 크레딧 선차감·정산·환불, 입력 마스킹. 독자 호스트에는 AI 경로 없음(독자 Q&A는 P2) | NW-06-042 |
| 기사 보조 | 그래프 `news.press_to_draft`(보도자료 → 초안, 사람 승인 필수, AI 표시), `news.assist`(제목·요약·교정·alt) | NW-06-043 |
| 어시스턴트 | 과거 기사·사내 규정 RAG, Dify 앱(`infra/dify/`), 채팅 위젯 | NW-06-044 |
| 음성 | 인터뷰 받아쓰기(STT, 원본 미저장, 오픈소스 강제), 오디오 기사(TTS, AI 음성 표시) | NW-06-045 |
| 회귀 | AI 표시 누락 0, 사람 승인 우회 0, 교차 신문사 근거 0 | NW-06-046 |

## 12. 개발 위키 운영

| 시점 | 할 일 |
|---|---|
| task 완료 | `docs/wiki/modules/`, `decisions/`, `log.md` 갱신 |
| 산출물 변경 | `docs/wiki/sources/<ID>.md` 갱신 |
| 웨이브 종료 | lint: 낡은 페이지, 깨진 링크, 출처 없는 주장 |

위키는 산출물을 대체하지 않습니다. 키·토큰과 독자 개인정보는 위키에 쓰지 않습니다.

## 13. 메인 디자인과 디자인 시스템

### 13.1 디자인 시스템 (정본: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`)

| 단계 | 작업 | 담당 |
|---|---|---|
| 1 레퍼런스 확정 | 언론사 벤치마크(`docs/reference/research/DESIGN_BENCHMARK.md`) + `REFERENCES.md` | NW-06-007 |
| 2 토큰·컴포넌트 | Tailwind CSS v4 3계층 토큰(테넌트 허용 목록), 서체 프리셋(Pretendard, Noto Serif KR, 본명조, 나눔명조), 본문 17px 기본 | NW-06-008 |
| 3 비주얼은 사람이 | 템플릿 3종 × 라이트·다크 × 시험 테넌트 3개 | NW-06-009(사람) |
| 4 정답 확정 | 코드 기준으로 DESIGN.md·COMPONENTS.md 재작성 | NW-06-010 |

### 13.2 독자 메인페이지 (정본: `docs/file/03-설계/03_SCREENS_UX.md` 4절)

국내 중앙지·지역지와 해외 언론사(직접 확인한 곳과 차단돼 미확인인 곳을 03장 4.1절에 구분)를 벤치마킹한 템플릿 3종을 씁니다.

| 템플릿 | 대상 | 특징 |
|---|---|---|
| A 전통 신문형 | 지역 일간·주간 | 헤드 + 서브 + 많이 본 뉴스, 부고·인사 탭, 섹션 블록 + 300x250 레일 |
| B 모던 매거진형 | 기획·인물 중심 | 리드 패키지 대형 이미지, 섹션 카드, 오피니언 레일, 뉴스레터·후원 CTA |
| C 모바일 피드형 | 인터넷 지역신문 | 시군 칩 탭, 피드 카드, 하단 탭 바 |

공통 규칙: 광고 슬롯 크기 예약(CLS 0.1 이하), 팝업·전면광고 없음, 법정 푸터 필수, 독자 사이트 3D 히어로 없음(D-11).

## 14. 이관 (기존 CMS → 로컬뉴스 클라우드)

정본: `docs/file/04-구현/07_SOURCE_MIGRATION.md`. 원본 코드는 없고, 고객 신문사의 기존 사이트 기사·사진·지면 PDF를 가져옵니다(NW-06-018). 가져온 기사는 기본 `original`, "보도자료·제공" 표기가 있으면 `press_release` 후보로 편집국이 확인합니다. 원 URL은 301로 넘깁니다.

## 15. 공용 모듈 경계

| 항목 | 규칙 |
|---|---|
| 코어 | 인증·조직·크레딧·Toss·잡·Storage·감사·AI 게이트는 코어 import만 |
| 공통모듈 | `apps/web/src/modules/<모듈>/`. 다른 모듈은 `server/index.ts` 공개 함수만 import(20장) |
| 테넌트 | `src/lib/tenancy/`(core-tenancy 어댑터)만. Theming SQL은 모놀리스 `0002` 변환본 |
| 코어 요청 | 06장 6절 R-1~R-10(인증 매트릭스, 매직 링크 예외, 독자 제공자 변수, Theming 승격, 독자 결제, 통합 seed, 레퍼런스, notify 추출, 광고 스키마, 네이버 브리지) |

## 16. 검증과 완료 정의

- task 완료 = `06_AGENT_PLAN.md` 수용 기준 + 리뷰 추적성 + `gate.sh`·`scope_check.sh` 통과
- 커밋 전 `bash _shared/check-invariants.sh` PASS
- 공개 베타 완료는 06장 7절: 빌드·타입·린트, SQL 체커, RLS 314, E2E, 결제 E2E, AI 회귀, 성능 예산, 법정 표기 점검, 디자인 시스템 4단계, 인증 G1.

## 17. 위험과 주의

| 위험 | 대응 |
|---|---|
| 법정 표기 누락 | 필요적 게재사항 미완성이면 공개 차단(DB 판정). 법무 확인 전 조문 번호·과태료는 미확인으로 둡니다(01장 6절) |
| 자체기사 비율·포털 감점 | 보도자료·AI 초안은 자체기사가 아님. 주간 대시보드 경고 |
| 속보 트래픽 급증 | ISR + 캐시 태그, 공개 콘텐츠는 anon 키(캐시 공유), 조회수는 묶음 증분 |
| 광고로 인한 CLS | 슬롯 크기 예약, 하우스 광고, Lighthouse CI(049) |
| 독자 개인정보 | 신문사 = 처리자, 플랫폼 = 수탁자. 제보 원문 DESK 전용, 독자 행은 신문사별 |
| 커스텀 도메인 로그인 | 활성화 때 Redirect URL 개별 등록(D-3). 허용 목록 상한 미확인 |
| 이관 저작권 | 통신사 전재 기사는 이관하지 않음 |
| 비밀키 | 신문사 Toss 키는 암호화 저장만. `.env*` 커밋 금지 |
| 토큰 비용 | task baseline을 작업 행·관련 절로 좁히고, 고문 검토는 Fable 작업에만 |

경로 검사 결과(`build_root.py --check local-news`, 2026-10-15): 산출물 35개, SQL 5개, 경로 참조 477개, 묶음 안 누락 0, 절대경로 누락 0.

## 18. 체크리스트

- [ ] 2절 도구 설치, setup 스크립트 dry-run → 실행, 무결성 점검 PASS
- [ ] `_shared/project-profile.md` 작성(6절), `/agent-check`
- [ ] 공용 인프라(Dify, 오픈소스 음성·LLM 서버, 메일 발송 사업자)
- [ ] `supabase start` → `db reset` → 시드 페르소나(7절)
- [ ] 결정 D-1~D-12 확정(8절)
- [ ] 디자인 시스템 1~4단계(13.1), 사람 비주얼 검토 포함
- [ ] W0~W6 진행 → G1 판정(19.3) → W7(Stage B 먼저) → 공개 베타
- [ ] 첫 신문사 파일럿: 개설 승인 → 매체정보 → 브랜딩 → 이관 → 도메인 연결(21장)
- [ ] G2 판정 → W8 카카오·네이버

## 19. 인증 단계: Mock → Google → 카카오·네이버

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009). 제품 반영: `docs/file/02-요구사항/01_PRD.md` 2·3·8.1절, `docs/file/03-설계/02_ARCHITECTURE.md` 9절, `03_SCREENS_UX.md` 7절, `04_API.md` 8절, `05_DATA_MODEL.md` 10절, `docs/file/01-관리/06_AGENT_PLAN.md` 8절, `docs/file/04-구현/CLAUDE.md` "인증 단계 규칙". 외부 콘솔 화면별 절차와 공식 링크는 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`입니다.

이 제품은 로그인 대상이 둘입니다. 이 제품은 단독 Supabase 프로젝트라 Google·카카오·네이버 앱을 이 제품용으로 따로 만들고, 동의 화면 이름은 플랫폼 브랜드(신문사마다 바꿀 수 없음, 01장 D-16)입니다.

### 19.1 단계 요약

| 단계 | 편집국(`newsroom.<플랫폼>`) | 독자(신문사 도메인) | 작업 |
|---|---|---|---|
| A Mock | 시드 페르소나(owner=발행인 등) | 시드 독자 페르소나(reader 등) | NW-06-004, 023 |
| B | Google + 이메일·초대 메일 | 이메일(D-15) + Google | NW-06-052, 053(W7 맨 앞, G1 후) |
| C1 카카오 | P2 선택(D-17) | P1 | NW-06-054(W8, G2 후) |
| C2 네이버 | P2 선택(D-17) | P1 | NW-06-055(W8, G2 후) |

### 19.2 Stage A 로컬 실행 순서

| 순서 | 명령·행동 | 설명 |
|---|---|---|
| 1 | `supabase start` → `supabase db reset` | 7절 |
| 2 | `apps/web/.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<긴 임의 값>` | 커밋 금지, `NEXT_PUBLIC_*` 금지 |
| 3 | `node scripts/dev/seed-users.mjs --app news` | 편집국 페르소나 11개 + 독자 페르소나 3개, 신문사 `dev-times`·`other-daily`(05장 10절). 두 번 실행해도 같음 |
| 4 | 편집국: `http://newsroom.localhost:3000/login` 개발용 패널 | owner로 들어가면 대시보드 |
| 5 | 독자: `http://dev-times.localhost:3000/` 또는 `?tenant=dev-times`(02장 10절) | reader로 로그인하면 계정 화면 |
| 6 | E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login` storageState 저장(NW-06-047) |

### 19.3 G1 체크리스트 (사람이 판정)

- [ ] 06장 2절 P0 기능 작업 완료(W6까지)
- [ ] NW-06-047 Mock E2E 로컬 녹색
- [ ] RLS 314/314, `outsider`·`reader_other` 격리
- [ ] 단계 분기 코드가 인증 모듈 밖 0건(NW-06-006)
- [ ] Google Cloud 로그인 프로젝트·동의 화면(플랫폼 브랜드), 운영 Supabase 프로젝트
- [ ] `[DECISION] G1 통과` 기록

### 19.4 Stage B 외부 설정

`D:/WorkSpace/platform/docs/develop/_shared/auth/README.md` 5장 순서를 따르고, 이 제품만의 추가 사항은 다음과 같습니다.

| 항목 | 내용 |
|---|---|
| Redirect URLs | `https://newsroom.<플랫폼>/auth/callback`, `https://*.<플랫폼>/auth/callback`(플랫폼 소유 서브도메인만 와일드카드), 커스텀 도메인은 활성화 때 도메인 워커가 관리 API로 개별 등록(D-3 (a)) |
| 배포 env | 편집국 `AUTH_PROVIDERS=google,email`, 독자 `AUTH_PROVIDERS_READER=google,email`(코어 요청 R-3) |
| 메일 템플릿 | 매직 링크·확인 메일은 `{{ .RedirectTo }}` 기준으로 신문사 도메인에 돌아오게 |

### 19.5 G2와 C단계

- G2: 공개 베타 2주(제안), 콜백 오류율 1% 미만(제안), 독자 `readers` 행 누락 0, 카카오 비즈 앱 전환(D-13), 네이버 애플리케이션 등록·검수 자료.
- C1 카카오·C2 네이버는 독자부터 켭니다. 네이버는 `custom:naver`(Supabase 커스텀 제공자) 스파이크를 먼저 합니다(D-14).

### 19.6 이 제품의 인증 작업 ID

| 단계 | 작업 | 웨이브 | 우선순위 | 모델 |
|---|---|---|---|---|
| A | NW-06-004(편집국·공통 모듈), NW-06-023(독자 로그인 A 구성) | W1, W5 | P0 | Fable, Opus |
| B | NW-06-052(편집국), NW-06-053(독자) | W7 맨 앞(G1 후) | P0 | Fable |
| C1 | NW-06-054 | W8(G2 후) | P1 | Opus |
| C2 | NW-06-055 | W8(G2 후) | P1 | Fable |

## 20. 공통모듈 8개 개발

기획서는 `docs/file/03-설계/모듈/`(DOC-MOD-001~009), 개발서는 platform 저장소의 `D:/WorkSpace/platform/docs/develop/local-news/modules/README.md`와 모듈별 파일입니다.

| 모듈 | 기획서 | 개발서 | 작업 |
|---|---|---|---|
| M1 newsroom-cms | `docs/file/03-설계/모듈/M1_newsroom-cms.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M1_newsroom-cms.md` | 011~016, 018, 019, 037 |
| M2 reader-membership | `docs/file/03-설계/모듈/M2_reader-membership.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M2_reader-membership.md` | 023, 024 |
| M3 ad-manager | `docs/file/03-설계/모듈/M3_ad-manager.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M3_ad-manager.md` | 025~027 |
| M4 notify-newsletter | `docs/file/03-설계/모듈/M4_notify-newsletter.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M4_notify-newsletter.md` | 028, 029 |
| M5 community | `docs/file/03-설계/모듈/M5_community.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M5_community.md` | 030~032 |
| M6 distribution-seo | `docs/file/03-설계/모듈/M6_distribution-seo.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M6_distribution-seo.md` | 033 |
| M7 compliance-desk | `docs/file/03-설계/모듈/M7_compliance-desk.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M7_compliance-desk.md` | 022, 034 |
| M8 search-analytics | `docs/file/03-설계/모듈/M8_search-analytics.md` | `D:/WorkSpace/platform/docs/develop/local-news/modules/M8_search-analytics.md` | 035 |

공용모듈 전환: M1~M8의 제품 무관 부분은 공용모듈 7개로 정의됐습니다(`D:/WorkSpace/platform/docs/develop/_shared/modules/README.md`, 06장 R-11). 1차는 `news` 스키마로 만들고 공용 v1.0 출시 후 전환합니다.

규칙: 모듈은 자기 표만 쓰고, 다른 모듈은 공개 함수나 잡으로만 부릅니다. 두 번째 제품이 같은 모듈을 쓰게 되면 `D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 3장 공용 스키마로 꺼냅니다(예: M4 → `notify` 0100).

## 21. 멀티테넌트(화이트라벨)와 도메인

정본: 제품 `docs/file/03-설계/02_ARCHITECTURE.md` 10절, 공용 설계 `D:/WorkSpace/platform/docs/Multi-tenant_Theming/README.md`.

| 순서 | 할 일 | 작업 |
|---|---|---|
| 1 | `proxy.ts`가 Host로 독자·편집국·운영·마케팅을 나누고 `resolve_tenant` 결과를 헤더로 넘김(클라이언트 헤더 무시) | NW-06-005 |
| 2 | 루트 레이아웃이 테마 CSS를 서버에서 주입(깜빡임 0) | NW-06-005 |
| 3 | 브랜딩 설정: 로고 → 색 추출 → 대비 검사 → 게시 | NW-06-039 |
| 4 | 서브도메인 `<slug>.<플랫폼>` 자동, 커스텀 도메인은 Standard 이상(`news_custom_domains`) | NW-06-039 |
| 5 | 도메인 활성화 때 독자 로그인 Redirect URL 등록 잡 | NW-06-039, 053 |
| 6 | 해석 실패·비활성 도메인은 오류 화면(플랫폼 브랜드로 기사 노출 0) | NW-06-005 |

플랜별 화이트라벨 단계: Starter L1(브랜딩), Standard·Pro L2(커스텀 도메인), Enterprise L3(전용 슬롯, 전용 DB는 판매 모델 B).

## 부록 A. 스크립트 없이 손으로 할 때

| 동작 | Git Bash / Linux |
|---|---|
| 1 복사 | `cp -r "D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork" "D:/WorkSpace/DEV/local-news"` |
| 2 이동 | `cd "D:/WorkSpace/DEV/local-news"` |
| 3 초기화 | `bash init-project.sh local-news --reset-git` |
| 4 붙여넣기 | `cp -r "D:/WorkSpace/platform/docs/develop/local-news/local-news-root/." "D:/WorkSpace/DEV/local-news/"` |
| 5 docs/etc 삭제 | `rm -rf docs/etc` |
| 6 모델 지정 | `.claude/agents/plan-challenger.md`의 `model: opus`를 `model: claude-fable-5-1`로, `nextjs-expert.md`·`fastapi-expert.md`·`supabase-expert.md`에 `model: sonnet` 추가 |
| 7 점검 | `bash _shared/check-invariants.sh` |

PowerShell과 cmd 명령은 다른 제품 안내서 부록 A와 같고 폴더 이름만 `local-news`로 바꿉니다(`D:/WorkSpace/platform/docs/develop/website-floria/website-floria_develop.md` 부록 A).
