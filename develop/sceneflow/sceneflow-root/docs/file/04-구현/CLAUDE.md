# CLAUDE.md: SceneFlow (sceneflow)

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 로그인·가입·콜백 작업이면 `AUTH_ROADMAP.md`(이 파일 끝 "인증 단계 규칙" 절) |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장, `DB_CONVENTIONS.md` 14장(pgvector) |
| 2 | 이 폴더 `01_PRD.md`(Track A~F, 단가, 금지 문구) → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` |
| 3 | UI 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` sceneflow 절, 랜딩이면 `HERO_3D.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 `src/server/**`, 워커에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 | 생성·업로드·검사는 선차감 → enqueue(ledger 연결) → 실패 시 자동 환불. 사용자 RPC 안에서 차감하지 않는다 |
| 코어 | 공용 모듈 16개를 재정의하지 않는다. `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*` 수정 금지. 필요하면 06장 6절에 요청 |
| 스키마 | `video` 스키마 변경은 VID-06-001만. 모놀리스 파일은 변환 스크립트로만 생성 |
| 대가성 문구 | 제휴 링크가 있으면 설명란 첫 줄과 고정 댓글 첫 줄에 `effective_disclosure` 문구. 끄는 옵션을 만들지 않는다 |
| 유료 프로모션 | 자동 설정 금지(제안 단계). 체크박스 + 안내만 |
| 네이버 클립 | 공식 API가 없어 Playwright로 게시한다. 채널별 위험 동의(`clip-2026-10-v1`) 없으면 업로드를 만들지 않는다(DB VD015). 계정당 3건/시간·15건/일. 사람처럼 보이게 하는 우회(무작위 지연, 지문 위장)를 넣지 않는다. 사용자의 네이버 비밀번호를 서버가 받지 않는다 |
| 브랜드커넥트 | video는 지원서만 만든다(코어 9인자 RPC, `target_kind='clip'`, `source_app='video'`). Playwright 제출 코드는 blog 소유, video에 복사 금지 |
| 대행 운영 | 고객 승인 토큰 원문은 DB·로그에 남기지 않는다(sha256만). 고객 채널은 승인 전 예약 금지(DB VD016). 고객 A 브랜드 가이드를 고객 B 생산 근거로 쓰지 않는다. 리포트에서 수집하지 않은 지표를 0으로 쓰지 않는다 |
| Track E/F | 메뉴, 테이블, 단가, 채널 역할(lofi/playlist), 색을 섞지 않는다. 공유는 Suno 엔진과 인코딩 워커뿐 |
| 금지 문구 | 01장 6절. 미검증 수치, 가상 후기, 보장 표현 금지 |
| LLM·음성 키 | LLM 키는 FastAPI(`apps/api`)에만. ElevenLabs 키는 서버 전용 프로세스(Next.js 서버, 오케스트레이터)에만, 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만. 브라우저·미디어 워커에 두지 않는다 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js·오케스트레이터 → FastAPI·음성 서버는 EdDSA 서명 토큰(오케스트레이터는 `/api/internal/ai-token`의 잡 토큰), Dify 경로는 대화 매핑(`platform_conversation_id`, `context_ref`, `dify_user`)만. Dify 입력에 토큰·org·채널 토큰·개인정보를 넣지 않는다 |
| 미디어 워커와 FastAPI | 둘은 서로 호출하지 않고 코드·비밀을 공유하지 않는다. FastAPI는 영상·오디오 바이너리를 처리하지 않고(FFmpeg, Whisper, demucs 금지), 미디어 워커는 LLM·ElevenLabs 키를 갖지 않는다(02장 2절 경계 표) |
| AI 입력 | 채널 OAuth 토큰, 이메일, 결제 정보, 원본 영상·오디오는 어떤 AI 제공자에도 보내지 않는다. 성과·대본·브랜드 문서는 국외 이전 동의 조직만 상용 제공자로 간다 |
| AI 크레딧 | 채팅·음성·위키·그래프 정밀 모드는 제공자 호출 전에 선차감하고 끝나면 정산, 결과가 전달되지 않으면 전액 환불(01장 4.1절). 그래프 빠른 모드와 내레이션은 기존 생산 합계에 묶인다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용 제공자를 쓰지 않는다. 파이프라인 STT는 `video.stt` = `oss-voice` 고정 |
| 같은 목소리 | 내레이션·샘플은 작업 시작 때 제공자와 보이스를 하나로 고정하고 중간에 대체하지 않는다. 실패하면 그 언어판 실패 + 환불. 롱폼 섹션 재생성은 기록된 값을 따른다(02장 5.3절) |
| 대가성 문구와 AI | 그래프·채팅이 대가성 문구를 쓰거나 지우거나 바꾸지 않는다. 삽입은 VID-06-021의 `injectDisclosure`만, 최종 보장은 DB CHECK. 근거 id 없는 수치와 가상 후기는 compliance 노드가 차단 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/sceneflow/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 VID-06-044 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고 3D 재질 색도 토큰만. 3D 안에 글자·숫자를 넣지 않는다 |
| git | 정리(삭제·이동) 커밋과 기능 커밋을 분리한다(YSM #1). 원본 폴더 삭제는 사용자 승인 후 |

## 3. 디렉토리와 소유 경계

| 영역 | 경로 | 소유 작업 |
|---|---|---|
| 공통 lib, proxy | `apps/sceneflow/src/{proxy.ts,lib/**}` | VID-06-003 |
| 과금·게이팅 | `src/server/billing/**` | VID-06-005 |
| 도메인 서버 | `src/server/<domain>/**` | 06장 2절 |
| API | `src/app/api/<domain>/**` | 06장 2절 |
| 화면 | `src/app/(dashboard)/dashboard/<area>/**` | 028~034 |
| AI 서비스 | `apps/api/**`(공용 설치·설정 045, `products/video/knowledge.py` 047, `wiki_config.py` 048, `graphs/`·`compliance/video.py` 049, `tools/video/` 050, `tests/video/security/` 055), `packages/video-rules/**` 049 | 045, 047~050, 055 |
| AI 게이트·음성 API | `src/app/api/{ai,internal,onboarding}/**`, `src/app/onboarding/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` 046 / `api/voice/{consent,sessions,stt,tts}` 052 / `api/voice/sample` 053 / `api/wiki` 048 | 046, 048, 052, 053 |
| AI·음성 UI | `src/components/ai-chat/`, `dashboard/chat` 051 / `components/voice/` 052 / `components/voice-engine/` 053 / `components/wiki/`, `dashboard/wiki` 048 / `components/script-plan/` 056 | 048, 051~053, 056 |
| 오케스트레이터 AI 단계 | `workers/video-orchestrator/src/steps/{translate,image,music}` 016 / `steps/{script,ai-step}` 049 / `steps/tts` 053 / `ai-ingest` 047 | 016, 047, 049, 053 |
| 3D·디자인 시스템 | `src/components/hero3d/`, `public/hero/` 054 / `src/styles/tokens.css` 036 / `src/components/ui/`, `src/app/dev/components/` 042 / `docs/file/03-설계/디자인/` 041, 043, 044 | 036, 041~044, 054 |
| Dify·지식·라우팅 스크립트 | `infra/dify/` 050 / `scripts/knowledge/` 047 / `scripts/ai-routing/`, `e2e/ai` 055 | 047, 050, 055 |
| 공개 | `src/app/{landing,lb,r,(marketing),legal}/**` | 022, 023, 035 |
| 오케스트레이터 | `workers/video-orchestrator/**` | 015, 016, 024, 026, 027 |
| 미디어 워커 | `services/media-worker/**` | 011~014 |
| 업로더 | `packages/sns-uploader/**` | 009, 010 |
| 미디어 워커 STT 사용량 | `services/media-worker/handlers/usage/**` | 052 |
| DB | `supabase/**` | 001, 002 |

## 4. 코어 사용 규칙

| 상황 | 쓸 것 |
|---|---|
| Route Handler 진입 | `requireSession('video', { roles })`. 조직은 세션에서만 |
| 기능 판정 | `entitled_plan_code` + `plans.features`(01장 4절 키 표). DB 정책은 `video.org_has_feature` |
| 차감 | `consume_credits(..., p_idempotency_key='consume:video:<request_id>')` → `enqueue_job(p_credit_ledger_id, p_idempotency_key='job:video:<request_id>')` |
| 부분 환불 | `refund_credits(ledger_id, reason, amount, 'refund:<production_id>:<lang>')` |
| Python 단계 | `core.enqueue_job(queue='video.media.cpu'\|'video.media.gpu', parent_job_id=root)` → 결과 대기. Python은 `claim_jobs`만 |
| 채널 토큰 | `beginOAuth/completeOAuth`, `CredentialVault`. 페이로드에는 `credential_id`만 |
| 제휴 | `createShortLink`, `disclosure`, `injectDisclosure`, `/r/[code]`는 `record_affiliate_click` |
| 감사 | 제품 RPC가 이미 기록. 서버 쓰기 중 관리 동작은 `auditAsService` |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인을 다시 확인. 서명 토큰은 `src/server/ai/token.ts`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler·오케스트레이터가 `resolve_ai_route(org, 'video', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')`. DeepL·fal·Suno 고지는 같은 화면의 별도 항목(01장 D-21) |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. 대화형은 `store_audio=false`, 첫 녹음 전 고지 확인. 내레이션은 `feature='narration'`에서 대체를 끈다 |
| 그래프 | 사용자 UI는 `/api/ai/script`(Next.js 게이트), 파이프라인은 오케스트레이터가 `/api/internal/ai-token`으로 잡 토큰을 받아 `POST /graphs/video.script/runs`. FastAPI는 `ai_runs`·`ai_run_steps`·`ai_usage`를 기록하고 video 표는 서버 함수가 쓴다 |
| 위키·지식 | 조직 위키·컬렉션은 그 조직에만. 운영자 컬렉션(`VIDEO_KNOWLEDGE_ORG_ID`)은 외부 지식 API로만 노출. 쓰기는 FastAPI 경유 |
| 결제 | 코어 toss. `confirm_payment_order` PM001이면 별도 호출로 `fail_payment_order(order_id,'amount_mismatch',{...})` 후 운영 알림 + Toss 취소 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16 App Router, React 19, TS strict, Tailwind CSS v4(4.x 고정) + shadcn/ui(Tailwind v4 지원 버전), zod, TanStack Query, BullMQ, three.js + React Three Fiber + drei(React 19 호환 버전), 미디어 워커 Python 3.11, FastAPI AI 서비스 Python 3.12(제안) + LangChain/LangGraph. `latest` 태그 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| 검증 | 모든 입력 zod, env는 `src/lib/env.ts`, Python은 pydantic settings |
| 타입 생성 | `supabase gen types typescript --local --schema core,video > apps/sceneflow/src/types/supabase.ts` |
| 언어 키 | `'KO' \| 'JA' \| 'EN'` 상수 하나 |
| 하위 프로세스 | 인자 배열, `--`, 타임아웃(01장 5절), 실패 시 kill |
| 로깅 | 공용 logger, 토큰·카드·본문 전체 금지 |
| 디자인 토큰 | `src/styles/tokens.css`(03장 4.3절 토큰 플랜, 3.2절 의미 기반 이름). 컴포넌트와 3D 재질에 hex 하드코딩 금지(`bg-[#...]` 린트 차단, 제안), 이모지 아이콘 금지(Lucide) |
| Python AI 서비스 | `apps/api`: ruff, mypy(제안), pydantic 스키마는 04장 4절 payload와 같게. 규칙·프롬프트 파일(`packages/video-rules`)은 복사본을 고치지 않는다(원본 049 소유) |
| 서버 컴포넌트 | 기본. 상호작용만 클라이언트 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -F sceneflow lint && pnpm -F sceneflow typecheck && pnpm -F sceneflow build` | 오류 0 |
| `pytest services/media-worker` | 통과 |
| `node D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs --vector mod <0000~0009> <seed> <1200_video.sql>` | OK(AI 표가 있어 `--vector` 필수) |
| `node D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs --vector mono <0001_core_lite> <0002_video_domain> <seed>` | OK |
| `pytest apps/api` | 토큰·조직 격리·라우팅·그래프·채팅 평가셋(045, 047, 049, 050, 055) |
| `pnpm test:ai` | AI 게이트 선차감·정산·환불, 내레이션 대체 금지(046, 053, 055) |
| `pnpm lhci` | 랜딩 Lighthouse, 3D 히어로 예산(054) |
| `pnpm test:rls`(VID-06-002) | 전 항목 통과 |
| `pnpm test:e2e`(007, 038), `pnpm test:integration`(037) | 통과 |

06장 7절 완료 정의를 모두 만족해야 PR을 머지한다.

## 7. 금지 패턴

07장 4절 요약: 크레딧 RPC 권한 미회수, 비원자 차감, 웹훅 서명 선택 검증·orderId 파싱, `Date.now()` customerKey, OAuth state 신뢰, 토큰 평문·0키 폴백, 세션 없는 anon 클라이언트, `FOR ALL` 정책, `x-internal-call`·자기 HTTP 호출, 쿠키·localStorage 역할 Mock 로그인(허용되는 Mock은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정뿐), `/landing` 보호, 이메일 자동 계정 병합, task 소유권 미검증, 자유 모델명, 예외 원문 노출, 타임아웃 없는 하위 프로세스, yt-dlp 인자 주입, sanitize 없는 HTML, 난수 지표, 미검증 마케팅 수치, 운영자 이메일 하드코딩, 실키 `.env` 커밋, mock 응답으로 장애 숨기기. AI·디자인(2026-10-13): LLM·음성 키를 브라우저·미디어 워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보, LLM이 대가성 문구를 쓰거나 지우기, 근거 없는 수치·가상 후기 생성, 원본 오디오를 국외 STT로 보내기, 내레이션 도중 제공자 대체, 클라이언트 임의 텍스트 TTS(샘플 100자 예외), FastAPI에 미디어 처리 넣기, OpenAI TTS 백업 부활, 3D 재질에 토큰 밖 색·3D 안 숫자, "Tailwind로"만 지시해 v3 설정 생성.

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`. 이 제품 문서의 반영 위치: 01장 9절(범위)·8.1절(D-26~D-29), 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절, 07장 6절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 **Stage A(Mock)**. 단계는 사람이 바꾼다. 에이전트가 스스로 B·C로 넘어가지 않는다 |
| 이 제품의 작업 | A: VID-06-004(W3). B: VID-06-063(G1 후, W7 맨 앞, P0, Fable). C1: VID-06-064(G2 후, W8, P1, Opus). C2: VID-06-065(G2 후, W8, P1, Fable) |
| 세션 | 모든 단계에서 실제 Supabase JWT. `requireSession('video')`·`proxy.ts`·레이아웃 가드·RLS는 단계와 무관하게 같은 코드 |
| 단계 분기 위치 | `AUTH_MODE`·제공자 목록은 `src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/`, `src/app/api/dev/login/`에서만 읽는다. 기능 코드·오케스트레이터·미디어 워커·`apps/api`에 `if (mock)`이나 페르소나 이메일 분기를 넣지 않는다(039 CI가 실패시킴) |
| 페르소나 사용 | 로컬: `supabase start` → `supabase db reset` → `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD` → `node scripts/dev/seed-users.mjs --app video` → `/login` 개발용 패널. 페르소나: `owner`(Starter), `admin`, `member`, `viewer`, `outsider`(교차 테넌트), `no_app`, `suspended`, `ops`, `adv_owner`·`adv_member`(Advanced 팀, 대행·팀·Track D/F 확인). 상세는 05장 10절 |
| E2E | Playwright `globalSetup`이 `/api/dev/login`으로 페르소나별 `storageState`를 저장하고 테스트는 필요한 상태로 시작한다(007, 038). Google·카카오·네이버 실로그인은 자동화하지 않고 사람이 수동 점검표로 확인 |
| 금지 패턴 | 쿠키·localStorage·헤더에 역할·플랜·사용자 id를 적는 Mock(`mock-auth.ts`, `nomad_role`, `nomad_plan`, `dev-user`), 원격 Supabase에 시드 계정 생성, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·로그에 노출, `AUTH_MODE=mock`에서 조용히 live로 전환, 콜백 `next` 무검증, 이메일 일치만으로 계정 자동 병합, `listUsers` 전체 조회로 사용자 찾기 |
| 혼동 금지 | 채널 연결 OAuth(YouTube·Meta·TikTok, `core.oauth_states`, VID-06-008)와 네이버 클립 Playwright 로그인 세션(VID-06-057, `CredentialVault` provider `naver`)은 사용자 로그인이 아니다. 인증 단계와 무관하게 그대로 두고, 로그인 코드와 서로 import하지 않는다. 로그인용 Google 클라이언트와 채널용 YouTube 클라이언트는 분리한다(01장 D-29) |
| 단계 전환 | G1(`AUTH_ROADMAP.md` 4장)·G2(6장)는 사람(대표님)이 판정하고 task `log.md`에 `[DECISION] G1 통과`·`[DECISION] G2 통과`로 남긴다. 네이버 경로(스파이크 결과)도 `[DECISION]`으로 기록하고 `NAVER_AUTH_PATH`에 같은 값을 넣는다 |
| 로그인 없는 흐름 | `/landing/[slug]`, `/lb/[handle]`, `/r/[code]`, `/review/[token]`에는 로그인 버튼을 추가하지 않는다. 대행 고객사 담당자는 계정 없이 토큰 링크로만 승인한다(시드 페르소나 없음) |
| 소유 경로 | 004: `src/lib/auth/`(003 소유 `src/lib/`의 예외), `src/app/(auth)/`, `src/components/auth/`, `src/app/api/dev/login/`, `scripts/dev/`. 063: `(auth)`·`components/auth`(004에서 이어 받음), `src/app/auth/callback/`, `src/app/onboarding/terms/`. 064: `providers/kakao.ts`, `dashboard/settings/login-methods/`. 065: `providers/naver.ts`, `src/app/auth/naver/`(브리지만), `scripts/auth/`. `proxy.ts` 공개 경로·env 스키마는 003, 배지 셸 장착은 028, `config.toml`은 001 파일에 1줄 요청(06장 8.4절) |

## 스토리보드 트랙 규칙 (2026-10-18)

정본: 01장 10장(확정 SF-1~SF-4, VD-F-130~142, 단가 10.4절). 반영 위치: 03·04·05·06장 끝의 2026-10-18 새 장. 트랙은 A, B, S, E, F이고 E·F는 Phase 2다.

| 항목 | 규칙 |
|---|---|
| 렌더 엔진 | FFmpeg만 쓴다(VD-F-033, SF-2). Remotion·CapCut 패키지를 설치하거나 import하지 않는다(Phase 2 검토는 01장 D-30). 미리보기는 브라우저 타임라인만이고 서버 미리보기 렌더를 만들지 않는다(VD-F-135, 0크레딧, 다운로드 경로 없음) |
| 장면 길이 합계 | 목표 길이 ±10%. 판정은 서버가 한다: 그래프 결과 저장(`video.apply_storyboard_result`)과 렌더 요청 때 검사하고 벗어나면 `VD017`. 장면 수는 쇼츠 3~12, 롱폼 분당 3~8, 최대 240(`VD018`). 편집기 게이지는 표시만 하고 클라이언트 값을 믿지 않는다 |
| 낙관적 동시성 | 장면 저장은 `video.save_scene(p_scene_id, p_revision, p_patch)`만. revision이 다르면 `VD409`를 돌려주고 화면은 최신본을 다시 불러온다. revision 없이 덮어쓰는 경로를 만들지 않는다. status `rendering` 중 편집은 `VD020` |
| clip 권리 근거 | `clip` 장면 소재는 `rights_basis`와 근거 메모가 있어야 저장된다(`VD019`). 렌더 직전에도 다시 검사한다. "무료 배포" 원본을 권리 근거로 자동 채우지 않는다 |
| 출처 경고 | 그래프·채팅은 근거 id가 없는 출처 URL을 만들지 않는다. 출처 없는 사실 주장 장면(`source_required=true`)은 WARN이며 D-33 결정 전에는 FAIL로 올리지 않는다. 설명란 "참고 자료"는 대가성 문구 첫 줄 뒤에 넣는다(VD-F-062 순서 유지). AI 생성 소재가 있으면 AI 생성 표시를 기본으로 켠다(01장 10.5절) |
| 서버 쓰기 테이블 | `video.scene_assets`, `video.storyboard_snapshots`는 서버(service_role)만 쓰고 guard 트리거로 막는다. `video.storyboard_templates`는 운영자 seed만. 서버 RPC `video.apply_storyboard_result`, `video.finish_scene_asset`, `video.snapshot_storyboard`를 사용자 세션에서 부르지 않는다. 다른 테이블의 쓰기 주체는 05장 새 장을 따른다 |
| 쇼츠 추출 | 컷은 연속 장면만, 스토리보드당 최대 10편(`VD021`), 플랜 `shorts_extract_max` 이하. 기존 OSMU(`longform_highlights`) 경로에 새 코드를 넣지 않는다 |
| 크레딧 | 단가는 01장 10.4절이 정본(서버 상수). 미리보기·편집 저장·이미지 재사용은 0. 장면 다시 만들기는 그 장면 단가만 선차감하고 실패하면 그 장면분만 환불한다 |
| 기존 Track C·D·E·F | 새 Track C Mode1·Track D 생성 경로를 만들지 않는다(Track S로 안내). `longform_projects/sections/highlights`와 E·F 테이블은 지우지 않는다(삭제는 01장 D-34, 스키마는 VID-06-001). MVP 작업에서 E·F 화면·워커를 새로 만들지 않는다 |
| 소유 작업 | 스토리보드 작업은 06장 2026-10-18 새 장의 작업(VID-06-066부터)이 소유한다. 작업 번호·소유 경로는 그 장을 따르고, 스키마 변경은 VID-06-001에 요청한다 |

## AI 자동편집·화면비 규칙 (2026-10-18)

정본: 01장 11장(SF-5~SF-8, VD-F-143~159, 명령 허용 목록 11.4절, 단가 11.5절, 플랜 키 11.6절). 반영 위치: 02장 11장, 03장 9장, 04장 10장, 05장 12장, 06장 10장, `1200_video.sql` 13절. **주력 기능은 AI 자동편집이다(SF-5).**

| 항목 | 규칙 |
|---|---|
| LLM 출력 | 그래프 `video.edit_plan`은 01장 11.4절 허용 `op`만 담은 명령 JSON을 만든다. LLM 출력으로 FFmpeg 인자·셸 문자열·SQL·파일 경로를 만들지 않는다. 허용 밖 명령은 편집안 전체를 거부한다(`VD023`). 스키마는 `packages/video-rules/edit/edl.schema.json` 하나를 TS·Python이 함께 쓴다 |
| 승인 전 변경 0 | 편집안은 `edit_plans`(proposed)로만 저장한다. 장면 변경은 사용자가 승인한 뒤 `video.apply_edit_plan` 한 번으로만 한다. 명령을 `save_scene`으로 쪼개 적용하거나 서버가 사용자 승인 없이 적용하는 경로를 만들지 않는다(자동 다듬기·무음 컷·리테이크·B-roll도 같다) |
| 낙관적 동시성 | 편집안에 `base_fingerprint`(`storyboard_fingerprint`)를 넣는다. 다르면 `VD409`이고 화면은 "다시 제안받기"를 띄운다. 오래된 편집안을 강제로 적용하는 옵션을 만들지 않는다 |
| 되돌리기 | `undo_edit_plan`만. 가장 최근 적용 편집안부터, 적용 뒤 상태가 그대로일 때만. 되돌려도 크레딧은 환불하지 않는다 |
| 비용 | 편집안 생성(지시 1, 자동 다듬기 쇼츠 1·롱폼 10분당 2)은 Route Handler 선차감. 적용 RPC는 차감하지 않는다. `regenerate` 명령은 RPC가 돌려주고 Route Handler가 명령별 단가로 선차감 → 잡. 승인 화면 예상 합계와 다르게 차감하지 않는다 |
| 클립 분석 | 업로드 클립 STT는 미디어 워커 Whisper(`video.stt` = `oss-voice`)만. 원본 오디오를 FastAPI·상용 STT로 보내지 않는다. 무음·리테이크 컷은 `cut_ranges`만 저장하고 원본 파일을 고치거나 지우지 않는다(비파괴). 컷은 단어 경계에서만 |
| 화면비·해상도 | 화면비는 `storyboard_aspect_allowed`(쇼츠 9:16/1:1/4:5, 롱폼 16:9/9:16/1:1). 해상도·fps 상한은 DB 트리거가 정본(`render_max_resolution`, `render_max_fps`, `render_4k60`). 픽셀 크기는 `video.render_dimensions`만 쓰고 코드에 크기 표를 다시 만들지 않는다. 1440p 이상에서 업스케일이 실패한 장면을 원본 해상도로 조용히 렌더하지 않는다 |
| 크롭 | 컷 화면비 이미지가 없으면 스냅샷 `crop_from`과 장면 초점(`focus_x/y`)으로만 크롭한다. 피사체 추적은 Phase 2라 MVP에 자리를 만들지 않는다 |
| 자막 | 강조어는 내레이션 안 단어만(DB CHECK). 한자 병기는 `hanja_glossary.json` 운영자 검수 항목만. 그래프가 한자를 지어내지 않는다 |
| 발음 사전 | 조직 안에서만 적용. 다른 조직 사전을 읽지 않는다. TTS 직전 텍스트 치환이며 내레이션 원문(`scenes.narration`)은 바꾸지 않는다 |
| 프리셋(P1) | 대행 고객 프리셋은 그 `client_id` 스토리보드에만(VD002). 고객 A 프리셋을 고객 B에 쓰지 않는다 |
| 금지 문구 | 01장 11.7절: "바이럴 보장", "조회수 예측", "편집 시간 N% 절감"(미검증), "AI가 완벽 편집". 쇼츠 점수는 "쇼츠 적합도(참고용)"로만 표시 |
| 소유 작업 | 06장 10장(VID-06-085부터). 스키마 변경은 VID-06-001에 요청 |
