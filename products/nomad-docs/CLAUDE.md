# CLAUDE.md: NOMAD Docs

개발 에이전트 지침. 이 제품의 기획 정본은 같은 폴더의 01~07이고, 이식 원천(flora-publishing, flora v1, SellingDocs, FortuneDocs, admin-suite) 문서보다 우선한다. 모든 사용자 노출 문구는 한국어. 경로 약어(`web/`, `worker/`, `api/`, `tpl/`, `int/`)는 `06_AGENT_PLAN.md` 머리 표와 같다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/`의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더 `01_PRD.md`(기능 ID DC-F-###, 3.2절 효과 엔진, 3.4절 lint, 4장 단가·features) → `02_ARCHITECTURE.md`(모듈 경계, 잡, 라우팅) → `04_API.md`(계약, 오류 코드) → `05_DATA_MODEL.md`(테이블, RLS, 함수) |
| 3 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 1.1절 "불일치와 구현 기준", 금지 패턴(`07_SOURCE_MIGRATION.md` 4절) |
| 4 | DB 작업이면 `docs/products/_supabase-modular/migrations/2300_docs.sql`(정본)과 `supabase/monolith/` |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 3-UI | 화면 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저), `03_SCREENS_UX.md`(4.1절 레퍼런스 표), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` nomad-docs 절, 랜딩이면 `HERO_3D.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 고위험 문서 | `risk_level='high'`(MVP `dev_contract`, Phase 2 `video_service_contract`·`channel_access_mandate`)는 `generation_mode='template'`만. AI가 계약 조항을 생성·수정·요약하지 않는다: 그래프는 `draft_ai_sections`를 건너뛰고, `docs.assist`는 403 `assist_disabled_high_risk`, 채팅은 조항 작성·법률 판단을 거절한다. 첫 생성 전 고지 동의(`DC007`), D-3 법무 검토 전 `doc_types.is_active=false` |
| 숫자는 DB가 계산 | 금액(`line_items.amount_krw` 생성 컬럼), 소계·VAT·합계(뷰 `project_totals`), 기간, 요구사항·산출물 코드(트리거), 문서번호(`docs.next_doc_number`)는 DB가 만든다. 클라이언트 값과 LLM 출력의 숫자를 저장하지 않는다. 불일치는 조용히 고치지 않고 실패·lint 오류 |
| 효과 엔진 결정성 | `computeEffects`는 순수 함수: 시각, 난수, LLM, 네트워크, env 접근 금지. 적용은 service_role `docs.apply_checklist_effects` 1회(해시 비교 `DC010`). `is_user_modified=true` 행과 `source<>'checklist'` 행은 건드리지 않는다 |
| 버전 불변 | `document_versions`는 append-only. 편집도 새 버전. `final` 문서는 수정 불가(`DC003`), 고치려면 `docs.create_revision` |
| 고유식별정보 | 주민등록번호 입력란을 만들지 않는다. 모든 텍스트 입력·CSV·편집 저장에 서버 PII lint(422 `pii_detected`), 업로드 텍스트는 LLM 전송 전 마스킹 |
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 admin 클라이언트는 서버 파일(Route Handler, 워커, ai-service)에서만. `NEXT_PUBLIC_`에 비밀 금지 |
| 크레딧 선차감 | 생성은 `docs.start_generation`(run + `enqueue_job` + `consume_credits` 한 트랜잭션), 동기 AI는 `withCredits`, 렌더·추출·회의록·색인·채팅·음성은 Route Handler가 `docs.reserve_credits`(일일 상한 + 차감 한 트랜잭션)로 차감 후 enqueue. `core.consume_credits`를 Route Handler에서 직접 부르지 않는다. 실패는 `fail_job` 자동 환불 또는 `refund_credits`. 사용자용 RPC 안에서 차감하지 않는다 |
| 생성 취소·실패 | 화면의 취소는 `docs.cancel_generation`만(코어 `cancel_job` 직접 호출 금지). 워커는 재시도가 남은 실패에 `docs.fail_generation`을 부르지 않는다(`02_ARCHITECTURE.md` 4장 실패·재시도 계약). 진행 표시는 `docs.report_generation_progress`(ai-service)만, 화면은 시간 기반 가짜 진행률 금지 |
| 확정 게이트 | 버전 저장 경로(생성·편집)는 `lint_result`에 `ran_at`·`rules`를 넣는다. 정본이 바뀐 문서(`needs_regeneration`, 해시 불일치)는 확정되지 않는다(DC010). 파이프라인 단계는 저장하지 않고 뷰 `docs.project_pipeline`이 계산한다 |
| 코어 재정의 금지 | auth, org, credits, toss, webhooks, oauth, weasyprint render, storage, audit, jobs, compliance, ai-gateway, ai-service, dify, core-voice, llm-wiki는 import·호출만 |
| 수정 금지 | `_platform-core/`, `_design-guide/`, `_supabase-modular/`의 다른 파일, `packages/core-*`, 공용 렌더 서비스(flora-publishing 소유), 공용 ai-service 원본, 이식 원천 폴더. 필요하면 `06_AGENT_PLAN.md` 6절 코어 요청에 적는다 |
| DB 변경 | `2300_docs.sql`만, DC-06-001 담당만. 모놀리스 `0002`는 변환 스크립트(DC-06-002)로만 재생성 |
| 렌더 위치 | PDF·DOCX는 공용 렌더 서비스에서만. Vercel(web) 코드는 `render.pdf`/`render.docx`를 enqueue만 한다. 렌더 입력은 DB의 sanitize된 `body_html`뿐 |
| LLM·음성 키 | LLM 키는 `apps/api`에만. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 web 서버에만. 워커에 LLM 키 금지 |
| AI 경계 | 브라우저는 제품 Route Handler, `/api/ai/*`, `/api/voice/*`만 부른다. Dify·FastAPI·제공자·렌더 직접 호출 금지. Dify 입력은 `platform_conversation_id`, `project_id`만(토큰·org·문서 본문 금지) |
| 강제 오픈소스 | `meeting_minutes`(STT), `docs.minutes`(LLM), `dify.aux`, `docs.knowledge`(임베딩)는 seed대로 오픈소스. 실패해도 상용으로 대체하지 않고 환불. 제공자·모델을 코드에 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다 |
| 서버가 정본 | 플랜·형식·워터마크·문서 단계 판정은 서버(`docs.org_features`, DB 트리거). 클라이언트 잠금은 UX 보조 |
| mock 금지 | 실패를 성공처럼 반환하지 않는다. 실패와 환불을 사용자에게 보여 준다. 인증 Mock은 쿠키 역할 Mock 금지, 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(배포 환경 404, 맨 끝 "인증 단계 규칙" 절) |

## 3. 디렉토리와 소유 경계

`02_ARCHITECTURE.md:34-79`과 `06_AGENT_PLAN.md` 1절·2절 "소유 파일/디렉토리" 열이 정본이다. 자기 작업 경로만 쓴다.

| 위치 | 책임 | 소유 작업 |
|---|---|---|
| `supabase/`, `web/src/types/supabase.ts`, `scripts/nomad-docs/to-monolith.*` | SQL, 타입, 모놀리스 변환 | 001, 002 |
| `supabase/tests/`, `scripts/nomad-docs/rls-runner.*` | RLS·권한 회귀 | 003 |
| `web/` 루트 설정, `web/src/proxy.ts`, `web/src/lib/supabase/`, `web/src/lib/env.ts` | web 골격 | 004 |
| `web/src/lib/auth/`, `web/src/app/api/dev/login/`, `web/src/components/dev-auth/`, `scripts/dev/`, `web/src/app/(auth)/`, `web/src/app/auth/`, `web/src/app/onboarding/{company,terms}/`, `web/src/app/api/terms/`, `web/src/features/{onboarding-terms,login-methods}/` | 인증 단계(맨 끝 "인증 단계 규칙" 절의 소유 경로) | 014, 063, 064, 065 |
| `web/src/lib/server/{http,pricing,features,pii,totals,sanitize,ai,import,trace,catalog,events,kpi}/` | 서버 공용 코드 | 012, 013, 013, 015, 016, 028, 033, 037, 030, 049, 053, 050 |
| `web/src/features/effects-engine/` | 효과 엔진 순수 함수 | 017 |
| `web/src/app/api/<리소스>/` | Route Handler(리소스별 단일 소유) | 06장 2절 표 |
| `worker/src/handlers/` | 생성·패키지·렌더·ZIP·동기화·웹훅·purge 잡 | 027, 029, 052, 053, 051 |
| `api/` 공용 부분 / `app/ai/graphs/docs_*.py` / `app/ai/products/docs/**` / `app/ai/tools/docs/` | ai-service 설치 / 그래프 4종 / 프롬프트·규칙·파서·RAG·위키 / 채팅 도구 | 006 / 022~025 / 021, 022, 024, 031, 032, 035 / 034 |
| `tpl/`(`tpl/tests/` 제외) | 문서 템플릿 9종(+ Phase 2 shorts_agency 7종, DC-06-060), lint 규칙, 조항 골격, sanitize 허용 목록, 체크섬 | 020 |
| `int/` | 연동 어댑터(Phase 2) | 052~055 |
| `web/src/styles/`, `web/src/components/ui/`, `web/src/app/dev/components/` | 디자인 시스템 코드 | 009 |
| `web/src/features/hero3d/`, `web/public/hero/`, `scripts/nomad-docs/hero-record/` | 3D 히어로와 3D 영상(three.js는 여기서만 import) | 045 |
| `web/src/features/pipeline/`, `web/src/app/(app)/pipeline/`, `web/src/app/api/{pipeline,search}/`, `web/src/app/api/{projects,parties}/[id]/activity/` | CRM형 워크스페이스(⌘K, 파이프라인, 거래처 360, 활동) | 061 |
| `web/src/features/progress/` | 생성 단계 진행 애니메이션(`motion`은 여기와 `pipeline/`에서만 import) | 062 |
| 테스트 디렉토리(`web/tests/`, `web/e2e/`, `api/tests/docs/`, `api/eval/docs/`) | 테스트 작업 소유 | 019, 026, 048, 056, 057, 058 |

공용 설정(`web/package.json` 등)은 DC-06-004에 요청한다. 화면 작업은 DC-06-011(디자인 시스템 4단계) 뒤에 시작한다.

## 4. 코어 사용 규칙

| 상황 | 쓰는 것 |
|---|---|
| Route Handler 진입 | `const ctx = await requireSession('docs')` → zod → `core.rate_limit_hit('docs:<route>:<org_id>', ...)` → features → (고위험) 고지 확인 → 차감 → 처리. 실행 계열은 이메일 인증 필수 |
| 기능 게이팅 | `web/src/lib/server/features`(키 없으면 Free 값, `01_PRD.md:285-299`). 단가는 `priceOf`(`01_PRD.md:301-316`) |
| 크레딧 | 멱등 키 생성 `consume:docs:gen:<request_id>`, 패키지 자식 `consume:docs:gen:<run_id>:<doc_type_code>`, 생성 밖 `consume:docs:<작업>:<request_id>`(`docs.reserve_credits`, 다른 작업·금액·조직의 키 재사용 거부), 채팅 `conv:<id>:turn:<n>`, 음성 `voice:<request_id>` |
| 잡 | `core.enqueue_job`, 큐 `docs.generate`·`docs.ai`·`docs.export`·`docs.integration`, 잡 키 `job:docs:<request_id>`. payload에 HTML·금액·비밀 금지(id만) |
| 진행률 | Realtime `core.jobs`, `docs.generation_runs`, `docs.doc_exports`, `docs.documents` |
| 그래프 실행 | 워커가 `/api/internal/ai-token`(워커 키)으로 잡 토큰을 받아 `POST /graphs/docs.generate/runs`. 버전 저장은 ai-service가 `docs.finish_generation`으로 1회, 워커는 `version_id` 존재만 확인 |
| 서명 토큰 | `web/src/lib/server/ai/`만 발급(EdDSA, `iss=docs`, `aud=platform-ai:docs`, 10분) |
| 자격증명 | 연동 토큰·웹훅 비밀은 `core.encrypted_credentials`(vault put/get, `revoke_credential`), OAuth는 `core.oauth_states` create/consume |
| 웹훅 수신 | 원시 본문 서명 검증 → `core.webhook_events`(provider, event_id) 멱등 → 처리 |
| Storage | 경로는 서버가 만든 `<org_id>/docs/<purpose>/<uuid>.<ext>`만. 사용자 파일명은 `original_name`에만. 다운로드는 서명 URL(7일) |
| 감사 | 사용자 RPC는 내부에서 `write_audit`. 서버 경로(효과 적용, 운영자 게시, 동의, 계정 삭제)는 service INSERT 또는 RPC |
| 국외 이전 | 온보딩·설정에서 owner 세션으로 `rpc('set_ai_cross_border_ack')` + 고지문 버전 감사 |
| DB 스키마 | 모듈러는 `supabase.schema('docs')`, 코어는 `SUPABASE_DB_SCHEMA`(`core` / 모놀리스 `public`) |
| SECURITY DEFINER | `set search_path = ''`, 스키마 한정, 사용자 호출용은 `is_service_caller()` + NULL-safe 역할 검사, EXECUTE 명시 정리 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16.2.x(16.2.9 제안), React 19.2, TypeScript strict, Tailwind CSS v4(4.x 고정, `@import "tailwindcss"`, `@theme`, `@custom-variant dark`), shadcn/ui(Tailwind CSS v4 지원 버전), Tiptap 2.x, zod 3.x, Node 20 LTS(워커), FastAPI 0.115 + Python 3.12(제안) + LangChain/LangGraph(api), three.js + React Three Fiber + drei(React 19 호환) |
| 금지 설정 | `tailwind.config.js`, `@tailwind base` 등 v3 문법, `latest` 의존성. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 의존성 | 버전 고정 + lockfile 커밋(Python은 `uv.lock`, 제안) |
| 타입 생성 | 모듈러 `supabase gen types typescript --local --schema core,docs > apps/nomad-docs/src/types/supabase.ts`. 모놀리스는 `--schema public`. `any`로 Supabase 타입 우회 금지 |
| 모놀리스 동기화 | `node scripts/nomad-docs/to-monolith.mjs`(생성), `--check`(CI 비교) |
| 린트 | ESLint flat(typescript-eslint, react-hooks), `ruff`. raw `fetch`는 `web/src/lib/client` 밖에서 금지, three.js import는 `hero3d/` 밖에서 금지, `effects-engine/`에서 `Date`·`Math.random`·`fetch` 금지 |
| 입력 검증 | 모든 경계 zod(TS) / pydantic(Python). 잡 payload와 그래프 출력도 재검증 |
| 디자인 토큰 | `web/src/styles/tokens.css`(`03_SCREENS_UX.md:674` 의미 기반 이름). hex 직접 사용 금지(`bg-[#...]` 린트 차단, 제안), 이모지 아이콘 금지(Lucide). `--color-seal`은 직인·확정 표시·3D 히어로에만. 컴포넌트는 `DESIGN_SYSTEM.md:84-94` 템플릿으로 1개씩 |
| 템플릿 | Jinja2 autoescape, 변수는 서버 스냅샷만. CSS 폰트는 `"Noto Sans CJK KR"` 이름만(파일 경로 금지) |
| 스트리밍 | fetch POST + ReadableStream(SSE 응답). EventSource로 POST 금지 |
| 문구 | 실패 문구는 원인과 다음 행동(환불 여부 포함). 금지 문구는 `01_PRD.md:404-417`, AI 생성 표시는 `01_PRD.md:396` |

## 6. 테스트와 완료 조건

완료 정의 전체는 `06_AGENT_PLAN.md` 7절. 기능 작업은 자기 디렉토리 단위 테스트만 쓰고, 테스트 디렉토리는 테스트 작업이 소유한다.

| 명령 | 기대 |
|---|---|
| `npm run lint && npx tsc --noEmit && npm run test && npm run build`(web, worker) | 통과. Vitest에 효과 엔진 속성 테스트(DC-06-019) 포함 |
| `pytest apps/api -k docs && ruff check apps/api` | 그래프 골든·평가셋, 토큰·조직 격리, 라우팅(DC-06-006, 021~026, 032, 034, 035, 058) |
| `node check.mjs --vector mod <0000~0009> seed.sql 2300_docs.sql`(`docs/products/_tools-sqlcheck`) | OK |
| `node check.mjs --vector mono 0001_core_lite.sql 0002_nomad_docs_domain.sql seed.sql` | OK |
| `node scripts/nomad-docs/to-monolith.mjs --check` | 불일치 0 |
| `node scripts/nomad-docs/rls-runner.mjs --target mod` / `--target mono` | `rls_smoke.sql` 105항목 + 추가 항목 전부 통과(DC-06-003) |
| `npx playwright test e2e/billing` | Toss 테스트 키 5개 시나리오(DC-06-048) |
| `npx playwright test e2e/flows e2e/ai` | 핵심 플로우 5개(DC-06-057, Mock 페르소나 storageState로 로컬, 063 후 스테이징), AI 회귀(DC-06-058) |
| `node scripts/dev/seed-users.mjs --app docs` | 로컬 시드 페르소나 생성(두 번 실행해도 크레딧 1회, 원격 URL이면 exit 1, DC-06-014) |

P0 작업은 대응 테스트 작업이 녹색이어야 완료다(`06_AGENT_PLAN.md` 7절 표). DB나 RLS를 바꾼 PR은 RLS 러너 두 대상이 모두 통과해야 병합한다.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약.

| 분류 | 금지 |
|---|---|
| 돈·권한 | 크레딧 RPC를 사용자에게 열기, 비원자 차감, 사용자용 RPC 안 차감, `FOR ALL` 정책, `'1234'`·localStorage 잠금해제, 클라이언트 플랜 판정, 웹훅 서명 생략, orderId 파싱으로 대상 추출, OAuth state 재사용 |
| 문서 무결성 | LLM이 금액·VAT·번호를 쓰거나 조용히 고치기, 고위험 문서 조항의 AI 생성·수정, 클라이언트 HTML·금액·`req_code` 저장, 확정 문서·버전 행 수정, 효과 엔진의 비결정 요소, 사용자 수정 행 덮어쓰기, 단일 JSON 일괄 생성, 선택 영역 일부만 처리하고 전체 교체 |
| 입력·파일 | 주민등록번호 입력란·저장, 사용자 파일명을 경로로, 서버가 사용자 URL fetch, 렌더러 무제한 외부 fetch, escape 없는 HTML, 한글 `\b` 금지어 매칭 |
| 런타임·배포 | Vercel·Route Handler에서 WeasyPrint 실행, async 안 동기 호출, mock 폴백, `.single()` 0행 500, step `if`의 `secrets`, Windows 폰트 경로, 실키 `.env` 커밋, `latest` 의존성, 빈 `CLAUDE.md` |
| AI·음성 | LLM·음성 키를 브라우저·Vercel·워커에 두기, 브라우저에서 Dify·FastAPI·제공자·렌더 직접 호출, Dify 입력에 토큰·org·본문, 무인증 AI 프록시, 회의 녹음·전사본의 상용 대체 전송, 임의 텍스트 TTS, 사람 소유 위키 블록 덮어쓰기, 전역 n8n 키 |
| 디자인 | 토큰 밖 색(3D 재질 포함), hex 하드코딩, 이모지 아이콘, "Tailwind"만 적은 지시(v3 혼입), 가상 후기·허위 수치·법적 효력 보장 문구 |
| 인증 단계 | 쿠키·localStorage 역할·플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 가짜 세션, 인증 모듈 밖 `AUTH_MODE` 참조, `next` 무검증 리다이렉트(07장 6절, 맨 끝 "인증 단계 규칙" 절) |

변경 기록(장 구조는 `DOC_TEMPLATE.md` 2.9절 7장 그대로 두고 여기에 적는다):

| 날짜 | 변경 |
|---|---|
| 2026-10-13 | Phase 2 `shorts_agency` 패키지(DC-F-046, DC-06-060). 효과 엔진 단가 토큰 `catalog:<key>` 추가(결정성 규칙 동일: 설정에서만 읽는다). content 프로젝트에서 성과 보장 문구는 `L-NO-GUARANTEE` error |
| 2026-10-14 | 교차검증 "반드시 고칠 것" SQL 반영(`06_AGENT_PLAN.md` 1.2.4절 반영 현황), n8n만 사용(Make 제외), CRM형 워크스페이스(DC-F-047, DC-06-061), 생성 진행 애니메이션(DC-F-048, DC-06-062), 3D 영상 히어로(DC-F-049, DC-06-045 확장), RLS 스모크 105항목 |
| 2026-10-14 | 인증 단계(확정 결정 22): DC-06-014를 Stage A로, DC-06-063(B)·064(C1)·065(C2) 추가, 01장 D-18~D-20, 07장 6절. 아래 "인증 단계 규칙" 절 |

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md`, 이 제품 반영은 01장 DC-F-001·8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절, 07장 6절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 Stage A(Mock 로그인). 로컬 `.env.local`은 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 배포 환경(Vercel 미리보기 포함)은 항상 `AUTH_MODE=live` |
| 단계 순서 | A(Mock, DC-06-014) → G1 → B(Google + 이메일, DC-06-063, P0, 공개 베타 필수) → G2 → C1 카카오(DC-06-064, P1)·C2 네이버(DC-06-065, P1) |
| 단계 분기 위치 | `AUTH_MODE`·제공자 목록을 읽는 코드는 `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/app/auth/`, `web/src/app/api/dev/login/`에만. 기능 코드·`proxy.ts`·worker·api·`tpl/`·`int/`는 `requireSession('docs')`·`session_context`만 쓴다 |
| 페르소나 사용법 | `supabase start` → `supabase db reset` → `node scripts/dev/seed-users.mjs --app docs`(제품 훅 포함) → `/login` 개발용 패널. 페르소나 키: owner, admin, member, viewer, outsider, no_app, suspended, ops, pro(05장 10절). 권한 확인은 페르소나를 바꿔 로그인해서 한다 |
| E2E | Playwright `globalSetup`이 페르소나마다(`no_app` 제외) `/api/dev/login`을 호출해 `storageState`를 저장하고 테스트는 그 상태로 시작한다. 온보딩 E2E는 `no_app` 첫 로그인으로 돌린다. Google·카카오·네이버 실로그인은 자동화하지 않고 사람이 수동 점검표로 확인한다 |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 쓰기, `mock-auth`, `nomad_role`, `nomad_plan`, 가짜 사용자 객체·가짜 세션, 원격 Supabase에 개발 계정 만들기, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·출력·로그에 두기, 인증 모듈 밖 `AUTH_MODE` 참조, 페르소나 이메일로 권한 분기, `next` 무검증 리다이렉트, 이메일 일치만으로 계정 자동 합치기(브리지), HubSpot 연동 OAuth를 로그인에 재사용 |
| 단계 전환 | 에이전트가 단계를 스스로 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 기록한 뒤에 B·C 작업을 시작한다. C2 경로(`supabase_custom` 또는 `bridge`)는 스파이크 결과를 `[DECISION]`으로 남긴다 |
| 소유 경로 | 014: `web/src/lib/auth/`, `web/src/app/api/dev/login/`, `web/src/components/dev-auth/`, `scripts/dev/`, `web/src/app/(auth)/login/`(A 구성), `web/src/app/onboarding/company/`. 063: `web/src/app/(auth)/`(014에서 이어 받음), `web/src/app/auth/callback/`, `web/src/app/onboarding/terms/`, `web/src/features/onboarding-terms/`, `web/src/app/api/terms/`, `web/src/lib/auth/onboarding.ts`(이어 받음). 064: `web/src/features/login-methods/`, `web/src/lib/auth/providers/kakao.ts`. 065: `web/src/app/auth/naver/`(브리지만), `web/src/lib/auth/providers/naver.ts`, `scripts/auth/`. 배지 장착(레이아웃)·`db:seed-users` 스크립트·Playwright `globalSetup` 등록은 DC-06-004에, `/app/settings/login-methods` 장착은 DC-06-038에 1줄 요청 |
| 이 제품의 B·C 작업 | B: DC-06-063(W7 맨 앞). C1: DC-06-064, C2: DC-06-065(W8, G2 후). 남은 결정: 01장 8.1절 D-18(카카오 이메일), D-19(네이버 경로), D-20(이메일 가입 유지) |
