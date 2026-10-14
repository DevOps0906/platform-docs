# CLAUDE.md: Floria (website-floria)

## 1. 먼저 읽을 문서

1. `docs/products/_platform-core/`의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`(16장 AI·음성), `DB_CONVENTIONS.md`(14장 pgvector), `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`
   - AI·음성 작업이면 `AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`도 읽는다.
2. 이 폴더의 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md`. 작업 전에 `06_AGENT_PLAN.md`에서 자기 작업 ID와 소유 디렉터리를 확인한다.
3. UI 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` website-floria 절, 히어로면 `HERO_3D.md`.

## 2. 절대 규칙

- `SUPABASE_SERVICE_ROLE_KEY`는 서버 전용이다. `NEXT_PUBLIC_` 접두사 금지, 관리자 클라이언트는 서버 파일에서만 import한다.
- 방문자 쓰기는 `src/app/api/` → service_role → `site.*` RPC 한 줄기뿐이다. 브라우저에서 쓰기 RPC를 직접 부르지 않는다.
- 이 제품에는 크레딧·결제가 없다. 만들지 않는다. AI·음성도 크레딧 선차감·정산·환불을 만들지 않는다(운영자 조직 예산, 사용량은 `core.ai_usage`에 기록만).
- LLM 키는 FastAPI(`apps/api`)에만. Vercel과 워커에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만.
- 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·개인정보를 넣지 않는다.
- 방문자 대화는 서명 쿠키 해시 `visitor_key`에 묶고 매 턴 일치를 확인한다. 상담은 `site.*`에 쓰지 않는다. 문의 전환은 문의 초안만 만들고 방문자가 기존 폼으로 직접 제출한다.
- 방문자 입력은 서버가 마스킹한 뒤에만 저장·전송한다. 상담 응답은 그래프 `compliance` 노드를 거친다: 후기·평점·미검증 수치(`claims.verified`)·가짜 연락처·가격/납기 약속 금지, 연락처는 `business.ts` 값만, 출처 없는 주장 금지.
- 라우팅은 02장 5.1절과 seed가 정본이다. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 운영자 조직이 국외 이전에 동의하지 않았으면 상용 제공자를 쓰지 않는다. 임베딩은 오픈소스 고정.
- 음성: `store_audio=false`, 첫 마이크 사용 전 고지 확인, 읽어 주기 입력은 DB의 assistant 메시지만.
- Tailwind는 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다.
- 디자인 시스템의 정답은 코드 하나: `src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 SI-06-035 뒤에 시작한다. 공개 사이트에 B2B 레퍼런스를 적용하지 않는다.
- 3D: three.js는 `src/components/hero3d/`에서만 import한다. `HERO_3D.md` 성능 예산과 대체 화면을 지키고, 3D 재질 색도 토큰만 쓴다(금색·잎 패턴·별 파티클 금지).
- 코어 재정의 금지. `_platform-core/`, `_supabase-modular/`의 다른 파일을 수정하지 않는다. `core.*`를 ALTER하지 않는다.
- 증빙 없는 후기, 수치, 연락처, 평점을 화면과 JSON-LD에 넣지 않는다(01장 6절).
- 확인/해지 링크는 GET으로 상태를 바꾸지 않는다.

## 3. 디렉토리와 소유 경계

02장 2절의 모듈 표와 06장 2절의 소유 파일 열이 정본이다. 요약: `src/content/`(SI-06-006), `src/styles/`·`src/components/ui/`(005), `src/components/sections/*`(008~010), `src/lib/routes.ts`·layout(011), `src/app/api/inquiries`·`src/lib/forms`(016), `src/app/api/newsletter`·`src/lib/newsletter`·`src/lib/mail`(017), `src/lib/auth`·콘솔 가드(019), `worker/notify`(018, `lint-tick.ts`만 041), `scripts/`·CI(024), `tests/*`(004, 025, 026). 남의 디렉터리를 고치지 말고 요청한다.

AI·3D(2026-10-13): `apps/api/`(036 공용 설치, 040 `products/site/knowledge.py`, 041 `products/site/wiki_config.py`, 043 `graphs/site_consult.py`·`compliance/site.py`, 044 `tools/site/`), `src/app/api/ai/`·`src/server/ai/`(037), `src/app/api/voice/`·`src/components/voice/`(046), `src/components/ai-consult/`(045), `src/app/(console)/admin/ai/`·`src/app/api/admin/ai/`(038), `admin/knowledge/`·`admin/wiki/`·`src/app/api/admin/{knowledge,wiki}/`·`src/app/api/internal/`(041), `src/app/(site)/guide/`(042), `content/knowledge/`(039), `scripts/knowledge/`(040), `infra/dify/`(044), `src/components/hero3d/`·`public/hero/`(047), `docs/file/03-설계/디자인/`(DESIGN.md 1절 033, 2절 이후와 COMPONENTS.md 035, review/ 034), `tests/ai/`·`scripts/ai-routing/`·`apps/api/tests/site/security/`(048).

## 4. 코어 사용 규칙

- 콘솔 라우트 진입부는 `requireSession('site')`. 프로필이 없으면 로그아웃, 기본 역할을 admin으로 두지 않는다.
- 레이트 리밋은 `core.rate_limit_hit`(Route Handler에서 IP 해시 키 `site:inq:ip:<hash>`).
- 감사는 RPC 안에서 `core.write_audit`. 개인정보 전문을 기록하지 않는다.
- 크레딧, 잡, 자격증명 vault, Storage는 쓰지 않는다(모놀리스 `core_lite`에 해당 절이 없다).
- AI 게이트: 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC) 턴마다 쿠키와 `visitor_key`를 대조한다. 서명 토큰은 `src/server/ai/token.ts`만 발급한다.
- AI 라우팅: FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'site', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다.
- 국외 이전 동의: 콘솔에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')`. 스위치는 `rpc('update_ai_settings')`.
- 위키·지식은 사이트 조직에만 둔다. 공개 `/guide`는 `published`만 서버에서 읽는다. 쓰기는 FastAPI 경유.
- 스키마는 환경변수(`SUPABASE_DB_SCHEMA`, `SITE_DB_SCHEMA`)로 전환한다. 모듈러는 `core`/`site`, 모놀리스는 둘 다 `public`.

## 5. 코드 규칙

- 스택: Next.js 16, React 19.2, TypeScript 6.0, Tailwind CSS v4 `@theme`(4.x 고정), shadcn/ui(Tailwind CSS v4 지원 버전), three.js + React Three Fiber + drei(React 19.2 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph(02장 1절). `latest` 태그 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안).
- Python: `apps/api` ruff, mypy(제안), pydantic 스키마는 zod와 같게. 규칙 파일(`content/knowledge/rules/`)은 복사본을 고치지 않는다(원본 039 소유).
- 색, 서체, 간격은 `src/styles/tokens.css`의 CSS 변수(`@theme`)로만. 컴포넌트와 3D 재질에 hex 금지(03장 4.3, 린트로 `bg-[#...]` 차단: 제안), 이모지 아이콘 금지(Lucide).
- 인라인 `style`로 grid/width 지정 금지. 내부 링크는 `src/lib/routes.ts` 키로만.
- 입력은 zod로 검증한다. Supabase 타입을 `any`로 우회하지 않는다.
- 타입 생성: 모듈러 `supabase gen types typescript --local --schema core,site > src/types/db.ts`, 모놀리스는 기본 스키마.
- 사용자 노출 문구는 한국어. 오류는 무엇을 고칠지 쓰고 사과하지 않는다.

## 6. 테스트와 완료 조건

- `npm run lint && npx tsc --noEmit && npm run build`
- SQL 체커: `docs/products/_tools-sqlcheck`에서 `node check.mjs mono ...`, `node check.mjs mod ...`(06장 7절)
- RLS 스모크(SI-06-004), API 통합(026), e2e(025), CI 게이트(024)가 통과해야 완료. 결제 E2E는 해당 없음.
- AI: `pytest apps/api`(036, 040, 043, 044, 048), `tests/ai/`(048), 검색 평가셋 재현율@6 0.8, 금지 규칙 평가셋 위반 0. SQL 체커는 AI 표가 있어 `--vector`가 필수(`node check.mjs --vector mono ...`, `--vector mod ...`).
- 3D·디자인: `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(SI-06-035) 완료.

## 7. 금지 패턴

07장 4절 요약: 가상 후기·미검증 수치·가짜 연락처, 외부 CDN/임시 이미지 URL, `href="#"`과 미정의 라우트, 인라인 grid, 영상 autoplay+preload auto와 전량 프리로드 로더, 중첩 `.git`/LFS, 프로필 없으면 admin, 오류를 성공으로 위장, CORS `*`, 서명 없는 토큰. AI·디자인(2026-10-13): LLM·음성 키를 브라우저·Vercel·워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보, 대화 id만으로 이어 쓰기, 한도 없는 익명 AI 호출, AI 응답의 후기·평점·미검증 수치·가짜 연락처·가격 약속, 임의 텍스트 TTS, 토큰 밖 3D 색·금색·별 파티클, "Tailwind"만 적은 지시(v3 혼입).

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md`. 로그인하는 사람은 초대받은 운영자뿐이고, 방문자(문의·뉴스레터·AI 상담·`/guide`)는 단계와 무관하게 로그인하지 않는다. 그 화면에 로그인 버튼을 추가하지 않는다.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 **Stage A(Mock)**. `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. Stage B(Google + 초대 메일)는 G1 통과 후. C1 카카오·C2 네이버는 이 제품에서 제외(운영자 전용 콘솔) |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`를 읽는 코드는 `src/lib/auth/`, `/admin/login` 화면, `src/app/auth/callback/`, `src/app/api/dev/login/`에만 둔다. 콘솔 화면·공개 사이트·AI 게이트·워커에 `if (mock)` 금지. 권한은 `session_context('site')`로만 |
| 페르소나 사용법 | `supabase start` → `supabase db reset` → `node scripts/dev/seed-users.mjs --app site`(제품 훅 `seed-users.site.mjs`가 엔타이틀먼트 부트스트랩과 `provision_site`) → `/admin/login` 개발용 패널. 페르소나: `owner`(사이트 등록 완료), `site_pending`(사이트 미등록), `admin`, `member`, `viewer`, `outsider`, `no_app`(초대 안 받음 → `/admin/no-access`), `suspended`, `ops`(05장 10절) |
| E2E | Playwright `globalSetup`이 `/api/dev/login`으로 페르소나별 `storageState`를 저장하고 콘솔 테스트는 그 상태로 시작한다(SI-06-025). 실제 Google 로그인은 자동화하지 않는다 |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 쓰기, `mock-auth`, `nomad_role`, `nomad_plan`, `dev-user` 우회, 원격 DB에 시드 계정 생성, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`나 번들에 넣기, 콜백 `next` 무검증, invite 앱 콜백에서 `bootstrap_app_for_org` 호출, 가입 폼·가입 링크 추가 |
| 단계 전환 | 사람(대표님)이 G1(`AUTH_ROADMAP.md` 4장)을 판정하고 task `log.md`에 `[DECISION] G1 통과`를 남긴 뒤에만 B 작업을 시작한다. 에이전트가 스스로 단계를 올리지 않는다. G2·C단계는 이 제품에 없다 |
| 작업 ID | Stage A: SI-06-019(기존 작업 범위 변경). Stage B: SI-06-049(P0, W6 맨 앞). C: 없음(제외) |
