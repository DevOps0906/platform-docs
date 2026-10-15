# CLAUDE.md: NOMAD Book Trailer

개발 에이전트 지침. 이 제품의 기획 정본은 같은 폴더의 01~08이고, 이식 원천(nomad-video, toon-factory, flora-publishing, nomad-docs) 문서보다 우선한다. 모든 사용자 노출 문구는 한국어. 경로 약어(`web/`, `api/`, `orch/`, `rend/`, `comp/`)는 `06_AGENT_PLAN.md` 머리말과 같다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `D:/WorkSpace/platform/docs/products/_platform-core/`의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더 `01_PRD.md`(기능 ID TR-F-###, 4장 플랜·크레딧 단가, 6장 법·문구) → `02_ARCHITECTURE.md`(모듈 경계, 잡, 라우팅, 같은 목소리, 이미지 스타일) → `04_API.md`(계약, 4절 payload·브리프·장면·스냅샷 스키마, 7절 오류 코드) → `05_DATA_MODEL.md`(테이블, RLS, 함수) |
| 3 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 금지 패턴(`07_SOURCE_MIGRATION.md` 4·6절) |
| 4 | DB 작업이면 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2600_trailer.sql`(정본)과 `supabase/monolith/` |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 3-UI | 화면 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `08_DESIGN_SYSTEM.md`(층 A 앱 토큰, 11장 컴포넌트), `03_SCREENS_UX.md`(4.1절 레퍼런스 표), `DESIGN_PRINCIPLES.md`, 랜딩이면 `HERO_3D.md` |
| 3-영상 | 컴포지션·렌더 작업이면 `08_DESIGN_SYSTEM.md` 4~10장(층 B 영상 토큰, 문법, 모션, 장면 컴포넌트, 변주 규칙)과 `04_API.md` 4.3·4.4절 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 권리 확인 먼저 | 원고 분석·브리프·렌더는 책의 권리 확인(`books.rights_ack_version`·`rights_ack_at`, 고지 버전 `rights-2026-10-v1`)이 없으면 시작하지 않는다(`TR003`). 권리 확인은 감사 로그를 남긴다 |
| 인용은 원고에서만 | 화면·영상에 "인용"으로 표시하는 문장은 원고 문자열 대조를 통과한 것만. 1개 80자, 트레일러 전체 300자 상한(01장 6.3절). 대조 실패 인용은 렌더 전에 사용자가 고치거나 확인해야 한다 |
| 금지 문구 | 근거 없는 판매·순위·수상, 보장, 가상 독자 후기, 의료·투자 효능 단정, 정가 15% 초과 할인 표현(도서정가제), 실존 인물·특정 작가 화풍 프롬프트. 규칙은 `packages/trailer-rules` 하나에서 TS·Python이 같이 읽는다. FAIL은 차단, WARN은 확인 + 감사 |
| AI 표시 | AI 생성 에셋(이미지·내레이션·문구)이 하나라도 있으면 엔드카드 AI 표시가 들어간다. `start_render`가 결정하고 `renders.ai_label` CHECK가 강제한다. 요청 입력으로 끌 수 없다(08장 9.1절) |
| 워터마크 | free 플랜과 480p 미리보기는 항상 워터마크. `start_render`가 플랜으로 결정. 브라우저 미리보기(Remotion Player)는 프록시 저해상도 + 오버레이, 다운로드 경로 없음 |
| 같은 목소리 | 첫 내레이션 성공 시 `trailers.voice`가 고정되고 이후 모든 장면·재생성은 같은 제공자·보이스. 실패는 같은 엔진으로만 3회 재시도 후 실패 + 환불. 다른 엔진으로 대체하지 않는다(02장 5.3절) |
| 이미지 스타일 | 프롬프트는 서버가 조립: 장면 시각 설명 + 키트 팔레트 + 문법 스타일 프리셋 + 금지 접미어 + 트레일러 고정 seed(02장 5.4절, 08장 8장). 사용자 원문 프롬프트를 그대로 제공자에 보내지 않는다 |
| 결정적 값은 서버 | 표지 팔레트(CIELAB k-means, LLM 없음), 글자 노출 시간, 장면 길이 합계 검증(±10%), 크레딧 단가(`web/src/server/pricing.ts`), 렌더 스냅샷은 서버가 만든다. LLM 출력의 숫자를 그대로 저장하지 않는다 |
| 스냅샷 렌더 | 렌더는 `start_render`가 만든 `renders.snapshot`만 입력으로 쓴다. 렌더 중 장면을 고쳐도 그 렌더는 바뀌지 않는다. 렌더러는 스냅샷의 Storage 경로 밖을 fetch하지 않는다 |
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 admin 클라이언트는 서버 파일(`web/src/server/**`, Route Handler, `orch/`, `rend/`)에서만. `NEXT_PUBLIC_`에 비밀 금지 |
| 크레딧 선차감 | 생성·에셋·렌더는 `trailer.start_run` / `trailer.start_render`(service_role, 실행 행 + `enqueue_job` + `consume_credits` 한 트랜잭션). `core.consume_credits`를 Route Handler에서 직접 부르지 않는다. 사용자용 RPC 안에서 차감하지 않는다. 실패는 `fail_job` 자동 환불 → `fail_run` 순서(02장 4절) |
| 실행 상태 | 실행·렌더 상태는 `finish_run`/`fail_run`/`finish_render`만 바꾼다(전이 트리거). 시간 기반 가짜 진행률 금지, 진행률은 렌더러가 보고한 프레임 비율만 |
| 코어 재정의 금지 | auth, org, credits, toss, webhooks, oauth, storage, audit, jobs, compliance, ai-gateway, ai-service, dify, core-voice, llm-wiki, sns-uploader는 import·호출만 |
| 수정 금지 | `D:/WorkSpace/platform/docs/products/_platform-core/`, `D:/WorkSpace/platform/docs/products/_design-guide/`, `_supabase-modular/`의 다른 파일, `packages/core-*`, 공용 ai-service 원본, 이식 원천 폴더. 필요하면 `06_AGENT_PLAN.md` 6절 공용 모듈 요청에 적는다 |
| DB 변경 | `2600_trailer.sql`만, TR-06-001 담당만. 모놀리스 `0001`·`0002`·`seed.sql`은 변환 스크립트로만 재생성 |
| LLM·음성·이미지 키 | LLM 키는 `apps/api`에만. fal·ElevenLabs 키는 오케스트레이터에만. 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 web 서버에만. 렌더러에는 어떤 AI 키도 없다 |
| AI 경계 | 브라우저는 제품 Route Handler, `/api/ai/*`, `/api/voice/*`만 부른다. Dify·FastAPI·제공자·렌더러 직접 호출 금지. Dify 입력은 `platform_conversation_id`만(조직·책은 서버가 대화에서 찾는다. 토큰·org·원고 본문 금지) |
| 원고 취급 | 원고 원문은 Storage에만. DB에는 해시·글자 수, 분석 결과(요약·청크). 분석 뒤 그래프는 요약과 검색 결과만 쓰고 원고 전문을 매번 보내지 않는다 |
| 서버가 정본 | 플랜·포맷·해상도·워터마크·AI 표시·대가성 문구(메타데이터 트리거) 판정은 서버. 클라이언트 잠금은 UX 보조 |
| mock 금지 | 실패를 성공처럼 반환하지 않는다. 실패와 환불을 사용자에게 보여 준다. 인증 Mock은 쿠키 역할 Mock 금지, 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(배포 환경 404, 맨 끝 "인증 단계 규칙" 절) |

## 3. 디렉토리와 소유 경계

`02_ARCHITECTURE.md` 2절과 `06_AGENT_PLAN.md` 2절 "소유 파일/디렉토리" 열이 정본이다. 자기 작업 경로만 쓴다.

| 위치 | 책임 | 소유 작업 |
|---|---|---|
| `supabase/`(tests 제외), `scripts/db/`, `web/src/types/supabase.ts` | SQL, 모놀리스 변환, 타입 | 001 |
| `supabase/tests/`, `scripts/test-rls/` | RLS·권한 회귀 | 002 |
| `web/src/proxy.ts`, `web/src/lib/`(`lib/auth` 제외), `web/next.config.ts`, 루트 레이아웃 | web 골격 | 003 |
| `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/components/auth/`, `web/src/app/api/dev/login/`, `scripts/dev/` | 인증 단계 | 004, 053, 054, 055 |
| `web/src/server/<도메인>/` | 서버 도메인 코드(books, links, trailers, scenes, runs, renders, music, meta, billing, ai, uploads, import, reviews, channels, account, ops, team) | 2절 표의 각 행 |
| `web/src/app/api/<리소스>/` | Route Handler(리소스별 단일 소유) | 2절 표 |
| `orch/` | 오케스트레이터(클레임 루프, 그래프·이미지·TTS·업로드·purge 단계, 크론) | 005, 024, 027, 028, 050, 052, 058 |
| `rend/` | 렌더러(Docker, 팔레트 추출, 렌더 파이프라인, BPM) | 006, 021, 031, 047, 059 |
| `comp/` | Remotion 컴포지션, 장면 컴포넌트, 영상 토큰, 계약 zod 스키마 | 012, 030, 059 |
| `packages/trailer-rules/` | 금지 문구·위험 규칙 사전(TS·Python 공용) | 023 |
| `api/` 공용 / `app/ai/graphs/trailer_*.py` / `app/ai/products/trailer/**` / `app/ai/tools/trailer/` | ai-service 설치 / 그래프 4종 / 스키마·파서·인용·위키 / 코치 도구 | 015 / 022, 023, 025, 039 / 015, 018, 022, 023 / 040 |
| `web/src/styles/`, `web/src/components/ui/`, `web/src/app/dev/components/` | 디자인 시스템 코드 | 008, 009 |
| `web/src/components/hero3d/`, `web/public/hero/`, `web/src/app/(marketing)/` | 랜딩·3D 히어로(three.js는 `hero3d/`에서만 import) | 044 |
| `web/src/components/preview/` | 브라우저 미리보기(Remotion Player는 여기서만 import) | 032 |
| `e2e/`, `tests/`, `api/tests/trailer/` | 테스트 작업 소유 | 014, 017, 046, 047, 048 |

공용 설정(`web/package.json` 등)은 TR-06-003에 요청한다. 화면 작업은 TR-06-011(디자인 시스템 4단계) 뒤에 시작한다.

## 4. 코어 사용 규칙

| 상황 | 쓰는 것 |
|---|---|
| Route Handler 진입 | `const ctx = await requireSession('trailer')` → zod → `core.rate_limit_hit('trailer:<route>:<org_id>', ...)` → 플랜 판정 → (렌더) compliance 사전 검사 → 서버 RPC → 응답. 실행 계열은 이메일 인증 필수 |
| 크레딧 | 단가는 `priceOf`(`web/src/server/pricing.ts`, 01장 4장). 멱등 키 실행 `run:trailer:<request_id>`(`start_run`이 형식 검사), 렌더는 `request_id`(uuid)로 `start_render`가 `consume:trailer:render:<id>`를 만든다, 채팅 `conv:<id>:turn:<n>`, 음성 `voice:<request_id>` |
| 잡 | `core.enqueue_job`, 큐 `trailer.ai`(오케스트레이터), `trailer.render`·`trailer.media`(렌더러), 잡 키는 서버 RPC가 만든다(`job:trailer:render:<id>` 등). payload에 원고·문구·비밀 금지(id만) |
| 진행률 | Realtime `core.jobs`, `trailer.generation_runs`, `trailer.renders` |
| 그래프 실행 | 오케스트레이터가 `/api/internal/ai-token`(워커 키)으로 잡 토큰을 받아 `POST /graphs/trailer.<name>/runs`. 결과 저장은 ai-service가 `trailer.finish_run`으로 1회 |
| 서명 토큰 | `web/src/server/ai/`만 발급(EdDSA, `iss=trailer`, `aud=platform-ai:trailer`, 10분) |
| 자격증명 | YouTube 채널 토큰은 `core.encrypted_credentials`, OAuth는 `core.oauth_states` create/consume(P1) |
| 웹훅 수신 | 원시 본문 서명 검증 → `core.webhook_events`(provider, event_id) 멱등 → 처리 |
| Storage | 경로는 서버가 만든 `<org_id>/trailer/<purpose>/<uuid>.<ext>`만. 사용자 파일명은 표시용만. 다운로드는 서명 URL, 파일명은 RFC 5987 |
| 공개 경로 | `/b/[code]`(`record_link_click`, IP는 일 단위 솔트 sha256), `/review/[token]`(sha256 → `decide_review`), 웹훅뿐. 세션을 만들지 않는다 |
| 감사 | 사용자 RPC는 내부에서 `write_audit`. 권리 확인, WARN 확인, 국외 이전 동의, 계정 삭제는 감사 필수 |
| 국외 이전 | 온보딩·설정에서 owner 세션으로 `rpc('set_ai_cross_border_ack')` + 고지문 버전 감사 |
| DB 스키마 | 모듈러는 `supabase.schema('trailer')`, 코어는 `SUPABASE_DB_SCHEMA`(`core` / 모놀리스 `public`) |
| SECURITY DEFINER | `set search_path = ''`, 스키마 한정, 서버 RPC는 `is_service_caller()` 검사, 컬럼 보호 트리거는 `core.is_privileged_session()`(05장 4절), EXECUTE 명시 정리 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16.2.x, React 19.2, TypeScript strict, Tailwind CSS v4(4.x 고정, `@import "tailwindcss"`, `@theme`, `@custom-variant dark`), shadcn/ui(Tailwind CSS v4 지원 버전), zod 3.x, Node 20 LTS(오케스트레이터·렌더러), Remotion 4.0.x(버전 고정, `remotion`·`@remotion/*` 같은 버전), FastAPI + Python 3.12 + LangChain/LangGraph(api), three.js + React Three Fiber(React 19 호환) |
| 금지 설정 | `tailwind.config.js`, `@tailwind base` 등 v3 문법, `latest` 의존성. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 의존성 | 버전 고정 + lockfile 커밋. Remotion 패키지는 서로 같은 버전이어야 한다(불일치 시 렌더 실패) |
| 타입 생성 | 모듈러 `supabase gen types typescript --local --schema core,trailer > apps/web/src/types/supabase.ts`. 모놀리스는 `--schema public`. `any`로 Supabase 타입 우회 금지 |
| 계약 | 잡 payload·브리프·장면·스냅샷 스키마는 `comp/src/schema`(zod)와 `api/app/ai/products/trailer/schema.py`(pydantic) 두 곳이 정본이고 동치 테스트(TR-06-024)로 묶는다. 다른 곳에서 형식을 다시 정의하지 않는다 |
| 컴포지션 | 같은 props → 같은 프레임(결정성). `Math.random`, `Date`, 네트워크 fetch 금지(린트). 랜덤이 필요하면 스냅샷의 seed로 `random(seed)`. 글자는 안전 영역 안(08장 5.2절), 서체는 이미지에 포함된 OFL 8종 이름만 |
| 린트 | ESLint flat(typescript-eslint, react-hooks), `ruff`. three.js import는 `hero3d/` 밖 금지, `@remotion/player`는 `preview/` 밖 금지, `comp/`에서 `Date`·`Math.random`·`fetch` 금지, hex 직접 사용(`bg-[#...]`) 금지 |
| 입력 검증 | 모든 경계 zod(TS) / pydantic(Python). 그래프 출력도 재검증(장면 수 39 이하, 길이 합계, 인용 길이) |
| 디자인 토큰 | 앱은 `web/src/styles/tokens.css`(08장 3.7절), 영상은 `comp/src/tokens`(08장 5~7장). 두 층을 섞지 않는다: 앱 화면에 책 키트 색을 쓰지 않고, 영상에 앱 팔레트를 쓰지 않는다(08장 0장). 이모지 아이콘 금지(Lucide) |
| 스트리밍 | fetch POST + ReadableStream(SSE 응답). EventSource로 POST 금지 |
| 문구 | 실패 문구는 원인과 다음 행동(환불 여부 포함). 금지 문구는 01장 6장 |

## 6. 테스트와 완료 조건

완료 정의 전체는 `06_AGENT_PLAN.md` 7절. 기능 작업은 자기 디렉토리 단위 테스트만 쓰고, 테스트 디렉토리는 테스트 작업이 소유한다.

| 명령 | 기대 |
|---|---|
| `pnpm -F web lint && pnpm -F web typecheck && pnpm -F web test && pnpm -F web build` | 통과 |
| `pnpm -F trailer-orchestrator test && pnpm -F trailer-renderer test && pnpm -F trailer-compositions test` | 통과(컴포지션 결정성·안전 영역·노출 시간 포함) |
| `pytest apps/api -k trailer && ruff check apps/api` | 그래프 평가셋(장 나누기, 인용 대조, 금지 문구, 코치 재현율), 토큰·조직 격리, 라우팅 |
| `node check.mjs --vector mod <0000~0009> seed.sql 2600_trailer.sql`(`D:/WorkSpace/platform/docs/products/_tools-sqlcheck`) | OK |
| `node check.mjs --vector mono 0001_core_lite.sql 0002_trailer_domain.sql seed.sql` | OK |
| `node scripts/test-rls/run.mjs --target mod` / `--target mono`(TR-06-002 러너. 기획 저장소에서는 `node products/book-trailer/supabase/monolith/tests/run-smoke.mjs --target mod\|mono`) | `rls_smoke.sql` 124/124 |
| 모놀리스 변환 `--check` | 불일치 0 |
| `npx playwright test e2e/billing` | Toss 테스트 키 시나리오(TR-06-014) |
| `npx playwright test e2e/app` | 무료 체험 흐름, viewer 읽기 전용(TR-06-048, Mock 페르소나 storageState) |
| 렌더 회귀 `pnpm -F trailer-renderer bench` | 60초 1080p p95 6분 이하 기록, 프레임 해시 일치(TR-06-047) |

P0 작업은 대응 테스트 작업이 녹색이어야 완료다. DB나 RLS를 바꾼 PR은 스모크 두 대상이 모두 통과해야 병합한다.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4·6절 요약.

| 분류 | 금지 |
|---|---|
| 돈·권한 | 크레딧 RPC를 사용자에게 열기, 비원자 차감, 사용자용 RPC 안 차감, `FOR ALL` 정책, localStorage 잠금해제, 클라이언트 플랜 판정, 웹훅 서명 생략, orderId 파싱, OAuth state 재사용, `x-internal-call` 같은 헤더 신뢰 |
| 영상 무결성 | 브라우저 렌더·다운로드, 요청 입력으로 워터마크·AI 표시 결정, 스냅샷 밖 입력으로 렌더, 다른 목소리 섞기, 원고에 없는 문장을 인용으로 표시, 단계 동시 enqueue·즉시 done |
| 저작권·표시 | 라이선스 근거 없는 음악 공개, OFL 밖 서체, 스톡 변형 재배포, 실존 인물·작가 화풍 프롬프트, 근거 없는 판매·순위·수상 문구, 정가 15% 초과 할인 표현, 대가성 표시 누락, 같은 템플릿 반복 업로드 |
| 입력·파일 | 사용자 파일명을 경로로, 렌더러 무제한 fetch, 원고를 DB 컬럼에 저장, 원고 전문 반복 전송 |
| 런타임·배포 | mock 폴백, `.single()` 0행 500, 시스템 폰트 의존, 실키 `.env` 커밋, `latest` 의존성, Remotion 패키지 버전 불일치, 빈 `CLAUDE.md` |
| AI·음성 | LLM·이미지·음성 키를 브라우저·Vercel·렌더러에 두기, 브라우저에서 Dify·FastAPI·제공자·렌더러 직접 호출, Dify 입력에 토큰·org·원고, 무인증 AI 프록시, 임의 텍스트 TTS, 사람 소유 위키 블록 덮어쓰기 |
| 디자인 | 토큰 밖 색, 앱 토큰과 영상 토큰 혼용, hex 하드코딩, 이모지 아이콘, "Tailwind"만 적은 지시, 가상 후기·허위 수치 |
| 인증 단계 | 쿠키·localStorage 역할·플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 가짜 세션, 인증 모듈 밖 `AUTH_MODE` 참조, `next` 무검증 리다이렉트, 채널 OAuth와 로그인 OAuth 공유 |

변경 기록:

| 날짜 | 변경 |
|---|---|
| 2026-10-15 | 최초 작성(제품 16번째, 스키마 `trailer`, 번호 2600) |

## 인증 단계 규칙 (확정 결정 22)

정본 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`, 이 제품 반영은 01장 TR-F-001·8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절, 07장 6절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 Stage A(Mock 로그인). 로컬 `.env.local`은 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 배포 환경(Vercel 미리보기 포함)은 항상 `AUTH_MODE=live` |
| 단계 순서 | A(Mock, TR-06-004) → G1 → B(Google + 이메일, TR-06-053, P0, 공개 베타 필수) → G2 → C1 카카오(TR-06-054, P1)·C2 네이버(TR-06-055, P1) |
| 단계 분기 위치 | `AUTH_MODE`·제공자 목록을 읽는 코드는 `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/app/auth/`, `web/src/app/api/dev/login/`에만. 기능 코드·`proxy.ts`·`orch/`·`rend/`·`api/`는 `requireSession('trailer')`·`session_context`만 쓴다 |
| 페르소나 사용법 | `supabase start` → `supabase db reset` → `node scripts/dev/seed-users.mjs --app trailer` → `/login` 개발용 패널. 페르소나는 05장 10절. 권한 확인은 페르소나를 바꿔 로그인해서 한다 |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장한다. Google·카카오·네이버 실로그인은 자동화하지 않고 사람이 수동 점검표로 확인한다 |
| 단계 전환 | 에이전트가 단계를 스스로 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 기록한 뒤에 B·C 작업을 시작한다 |
| "mock" 단어 구분 | 2장 "mock 금지"는 LLM·렌더·TTS 장애를 가짜 성공 응답으로 숨기는 것을 금지한다. 이 절의 Mock 로그인은 로컬 시드 계정으로 실제 Supabase JWT를 받는 개발 수단이라 그 금지에 해당하지 않는다 |
