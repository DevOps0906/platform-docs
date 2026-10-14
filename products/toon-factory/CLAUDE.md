# CLAUDE.md: Toon Factory

개발 에이전트 지침. 원본 `Toon-Factory/Claude.md`를 대체한다. 주석, 문서, UI 문구는 한국어로 쓰고 식별자는 영어로 쓴다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 로그인·가입·콜백 작업이면 `AUTH_ROADMAP.md`(이 파일 끝 "인증 단계 규칙" 절) |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 2 | 이 폴더 `01_PRD.md` → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` 4절 |
| 3 | UI 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` toon-factory 절, 랜딩이면 `HERO_3D.md`. 디자인 정답은 코드(`tokens.css`, `components/ui/`)이고 문서는 `docs/file/03-설계/디자인/DESIGN.md`·`COMPONENTS.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 비밀 | `SUPABASE_SERVICE_ROLE_KEY`, `FAL_KEY`, `TOSS_SECRET_KEY`, 빌링키 암호화 키는 서버·워커에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 | 유료 작업은 `consume_credits` 선차감 → 제품 행 → `enqueue_job`. 실패 환불은 `fail_job`/`refund_credits`. 브라우저에서 크레딧 RPC 호출 금지 |
| 결과물 | 최종 PNG/ZIP/스트립/MP4는 워커만 만든다. 브라우저 다운로드용 렌더 코드 금지. 워터마크는 `exports.watermark`만 믿는다 |
| 에셋 | 원본·편집용 경로를 클라이언트로 보내지 않는다. 서명 URL은 `toon.org_asset_access` 통과분만 |
| AI 표시 | 메타데이터 표시는 끌 수 없다. 가시 표기 해제는 사용자 확인 + 감사 로그 |
| 코어 | 플랜·구독·크레딧·결제·잡 테이블을 제품 스키마에 만들지 않는다. `core.*` ALTER 금지. `_platform-core`, `_supabase-modular`의 다른 파일 수정 금지(6장 6절 요청으로) |
| DB 변경 | SQL은 Fable 작업(TN-06-001, 002, 038, 060)만. 모놀리스 파일은 변환 스크립트로만 재생성 |
| LLM·음성 키 | LLM 키는 FastAPI(`apps/api`)에만. Vercel과 `toon-worker`에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만. `FAL_KEY`는 워커만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·개인정보를 넣지 않는다 |
| AI 입력 | 시놉시스, 설정 요약, 컷 단위 장면·대사만 보낸다. 이메일·이름·결제 정보는 어떤 AI 제공자에도 보내지 않는다. 사용자 메시지는 마스킹 후 |
| AI 결과 반영 | AI는 컷 문서와 위키를 직접 고치지 않는다. 초안만 돌려주고 사용자 동작("콘티 적용", "말풍선에 넣기")이 `editorStore` 커맨드로 반영한다 |
| AI 크레딧 | 채팅·음성·위키 갱신은 제공자 호출 전에 선차감하고 끝나면 정산, 결과가 전달되지 않으면 전액 환불(01장 4.6절). 콘티·대사·배경은 정액 선차감. 그 밖의 파일에서 차감하지 않는다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용 제공자를 쓰지 않고, AI 배경(fal)은 `TN007`로 막는다 |
| 영상 음성 | `feature='video_voice'`는 작업 도중 다른 제공자로 대체하지 않는다. 실패하면 클립을 남기지 않고 환불 |
| 협찬 표시 | 협찬 회차의 대가성 문구·가상인물 표시는 `exports.disclosure_text`·`virtual_character_label`만 믿는다(DB 트리거가 채움). 요청 값으로 바꾸거나 끄는 경로를 만들지 않는다. 승인(`approved`)은 `decide_sponsorship`으로만 |
| 프리셋 | 플랫폼 규격 수치는 `packages/toon-doc/presets/`에만 둔다. 화면·워커에 크기 상수를 복제하지 않는다 |
| 음성 | 녹음 원본 저장 금지(`store_audio=false`). 첫 마이크 사용 전 음성 처리 고지(감사 `voice.notice_ack`). TTS 텍스트는 저장된 문서·DB 메시지에서만. 보이스는 사전 정의 6종만(복제·모방 금지) |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/toon/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 TN-06-043 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고, 3D 재질 색도 토큰만. 캐릭터·말풍선·효과 글자를 3D에 넣지 않는다 |

## 3. 디렉토리와 소유 경계

`apps/toon/`(앱), `packages/toon-doc/`(문서 스키마·렌더·레이아웃·콘티 변환·프리셋·템플릿), `services/toon-worker/`(잡 핸들러, 미디어, 스케줄), `tools/`(카탈로그 등록, 모놀리스 변환, 문구 검사), `supabase/`. Fabric 코드는 `apps/toon/src/components/canvas/`와 `packages/toon-doc/src/render/`에만 둔다. 상태 원천은 `editorStore` 문서이고 Fabric은 뷰다. 작업별 소유 디렉토리는 06장 2절 표가 정본이다. AI·음성(2026-10-13): `apps/api/`(FastAPI, 공용 ai-service 설치 TN-06-044, 확장 046·047·049·050·051), `infra/dify/`(051), `apps/toon/src/app/api/ai/`(045, `knowledge/` 046, `wiki/` 047), `api/voice/`(053·054·055), `src/lib/server/ai/`(045), `lib/server/voices.ts`(053), `components/ai-chat/`(052), `components/voice/`(053·054), `components/wiki/`(048), `components/hero3d/`(056), `packages/toon-doc/rules/`(058), `services/toon-worker/src/media-audio/`(055), `docs/file/03-설계/디자인/`(041·042·043).

## 4. 코어 사용 규칙

| 용도 | 사용법 |
|---|---|
| 세션 | Route Handler 첫 줄 `const ctx = await requireSession('toon')`. 역할은 `ctx.org.role`, 기능은 `toon.plan_features(org)` |
| 가입 | `signUp({ options: { data: { signup_app: 'toon' } } })`. SSO 사용자는 `bootstrap_app_for_org('toon')` |
| 크레딧 | `credits.consume({ orgId, amount: priceOf('toon', action), appId: 'toon', reason, ref: { type: 'job', id: requestId }, idempotencyKey: 'consume:toon:' + requestId })` |
| 잡 | `jobs.enqueue({ queue: 'toon.ai' 또는 'toon.render', jobType, payload, creditLedgerId, idempotencyKey: 'job:toon:' + requestId })` |
| 콘텐츠 쓰기 | 서버에서도 사용자 세션 클라이언트로(RLS, 한도 트리거 적용). service_role 콘텐츠 쓰기는 운영 도구만 |
| 감사 | 다운로드, AI 가시 표기 해제, 카탈로그 검증·공개, 에셋 보관 |
| 레이트 리밋 | `rate_limit_hit('toon:<route>:<org_id>', ...)`, 값은 01장 5절 |
| Realtime | `core.jobs` 구독. 별도 채널 금지 |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인과 `series_id`의 조직을 다시 확인. 서명 토큰은 `src/lib/server/ai/token.ts`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'toon', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')`(고지문 버전 기록). AI 배경 요청은 `ai_org_settings`를 읽어 확인 |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. `store_audio=false`. 영상 음성은 `video-lines`에서 대사별 mp3를 만들고 워커는 합성만 |
| 그래프 | 워커는 `/api/internal/ai-token`으로 잡 토큰을 받아 `POST /graphs/{name}/runs`. FastAPI는 `ai_runs`·`ai_run_steps`·`ai_usage`를 기록하고 toon 표는 워커가 쓴다 |
| 위키·설정 | 작품별 컬렉션(`settings-<series_id>`, `wiki-<series_id>`). 쓰기는 FastAPI 경유(`expected_version`), 사람 소유 블록(`<!-- owner:user -->`)은 ingest가 수정하지 않는다 |

## 5. 코드 규칙

| 항목 | 내용 |
|---|---|
| 스택 | Next.js 16, TypeScript strict(`any` 금지), Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전), Fabric 6, Zustand 5 + immer, zod, three.js + React Three Fiber + drei(React 19 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph. 버전 고정, `latest` 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| Python | `apps/api`: ruff, mypy(제안). pydantic 스키마는 `packages/toon-doc` zod 스키마와 같게. 규칙 JSON(`packages/toon-doc/rules/`)의 복사본을 고치지 않는다 |
| 입력 | Route Handler 입력은 zod. 문서는 `packages/toon-doc` 스키마로 검증 |
| 성능 | 캔버스 갱신은 rAF로 묶고, 저장은 1.5초 디바운스(최대 10초) |
| 타입 생성 | `supabase gen types typescript --local --schema core,toon > packages/toon-doc/src/db-types.ts` |
| 디자인 | 색·서체·간격은 `apps/toon/src/styles/tokens.css`의 `@theme` 토큰으로만. 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안). 아이콘은 Lucide. 이모지 금지 |
| 문구 | 01장 6.5절 금지 문구 사용 금지. 오류 문구는 무엇이 잘못됐고 어떻게 고치는지 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -r build && pnpm -r typecheck && pnpm -r lint` | 0 오류 |
| `node docs/products/_tools-sqlcheck/check.mjs ...` | 모듈러·모놀리스 OK |
| `pnpm test:rls` | TN-06-002 전 항목 통과 |
| `pnpm test` | 에디터 커버리지 80%, 골든 이미지 차이 0.5% 이하 |
| `pnpm test:e2e` | 핵심 플로우와 결제 E2E(Toss 테스트 키) 통과 |
| 금지 문구 검사 | `tools/copy-lint` 통과 |
| `pytest apps/api` | 토큰·조직 격리·라우팅·그래프·위키·채팅 평가셋(044, 046, 047, 049, 050, 051, 057) |
| `pnpm test:ai` | AI 게이트 선차감·정산·환불, 영상 음성 대체 금지(045, 053, 054, 055, 057) |
| `pnpm lhci` | 랜딩 Lighthouse(3D 히어로 예산) |

## 7. 금지 패턴

07장 4절 요약: 클라이언트 결과물 렌더, 공개 버킷 프리미엄 에셋, Fabric `toObject` 저장, 스톡 변형 카탈로그, fal 안전 필터 끄기, 키 없을 때 placeholder, 크레딧 RPC 직접 호출, 웹훅 서명 생략, `customerKey = Date.now()`, 셀프 플랜 변경 정책, localStorage 잠금 해제, 프로필 없으면 admin, 정책 안 `org_members` 직접 조회, org_id 없는 FK, 사용자 파일명 경로, `.env` 커밋. AI·음성·3D·디자인(07장 4절 추가분): LLM·음성 키 배치 위반, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰, 국외 이전 동의 없는 상용 AI·fal 호출, AI의 문서·위키 직접 수정, 작품 간 설정 컬렉션 혼합, 임의 텍스트 TTS, 영상 음성 도중 제공자 대체, 보이스 복제, AI 표시 회피, 3D 재질 토큰 밖 색, `tailwind.config.js`와 버전 없는 "Tailwind".

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`, 이 제품 적용은 01장 8.1절, 02장 10절, 03장 7절, 04장 8절, 05장 10절, 06장 8절이다.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 Stage A(Mock). 로컬 `.env.local`은 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 배포 환경은 항상 `AUTH_MODE=live` |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH`를 읽는 코드는 `apps/toon/src/lib/auth/`, 로그인 화면(`src/app/(auth)/login/`), `/auth/callback`, `/api/dev/login`, (C2 브리지) `/auth/naver/*`에만 둔다. 기능 코드·워커·`apps/api`에 `if (mock)` 금지 |
| 세션 | 모든 단계에서 실제 Supabase JWT. `requireSession('toon')`, `session_context`, RLS는 단계와 무관하게 같다. 로그인 직후 처리는 `finishLogin('toon', next)` 하나(Mock 포함) |
| 페르소나 | `supabase db reset` → `pnpm db:seed-users`(= `node scripts/dev/seed-users.mjs --app toon`, 제품 훅 `seed-users.toon.mjs`). 키: `owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops`, `pro_owner`, `low_credit`(05장 10절). 권한 분기는 `session_context`로만, 페르소나 이메일로 분기 금지 |
| E2E | Playwright `globalSetup`이 `/api/dev/login`으로 페르소나별 `storageState`를 저장하고 각 테스트는 그 상태로 시작한다. 실제 Google·카카오·네이버 로그인은 자동화하지 않는다(사람 수동 점검표) |
| 금지 패턴 | 쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈 밖 `AUTH_MODE` 참조(CI 실패, TN-06-031), 원격 Supabase에 시드 계정 생성, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·브라우저 번들에 넣기, 콜백 `next` 무검증, 제공자 토큰 저장, 이메일 일치만으로 계정 합치기(07장 6절) |
| 단계 전환 | 에이전트가 스스로 단계를 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과` / `[DECISION] G2 통과`로 기록한 뒤에만 B·C 작업을 시작한다. 네이버 경로도 스파이크 뒤 `[DECISION]`으로 기록 |
| 소유 경로 | 004: `src/lib/auth/`, `src/app/api/dev/login/`, `scripts/dev/`, `src/proxy.ts`. 027: `(auth)/login/`. 067: `(auth)/signup/`·`reset/`·`auth/callback/`, `(auth)/login/providers/`(027에서), `src/lib/auth/oauth/`와 콜백 연결부(004에서 이어 받음), `onboarding/terms/`. 068: `oauth/kakao.ts`, `app/settings/login-methods/`. 069: `oauth/naver.ts`, `(auth)/auth/naver/`(브리지만), `scripts/auth/`. 다른 작업 파일은 1줄 요청(06장 8.1·8.4절) |
| 이 제품의 작업 | A: TN-06-004(모듈 경계, Mock, 시드, 가드, `finishLogin`), TN-06-027(개발용 패널). B: TN-06-067(P0, W6 맨 앞, G1 후). C1: TN-06-068(P1, W7, G2 후). C2: TN-06-069(P1, W7, G2 후) |
