# CLAUDE.md: NOMAD AI Factory (nomad-video)

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장, `DB_CONVENTIONS.md` 14장(pgvector) |
| 2 | 이 폴더 `01_PRD.md`(Track A~F, 단가, 금지 문구) → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` |
| 3 | UI 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` nomad-video 절, 랜딩이면 `HERO_3D.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 `src/server/**`, 워커에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 | 생성·업로드·검사는 선차감 → enqueue(ledger 연결) → 실패 시 자동 환불. 사용자 RPC 안에서 차감하지 않는다 |
| 코어 | 공용 모듈 16개를 재정의하지 않는다. `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*` 수정 금지. 필요하면 06장 6절에 요청 |
| 스키마 | `video` 스키마 변경은 VID-06-001만. 모놀리스 파일은 변환 스크립트로만 생성 |
| 대가성 문구 | 제휴 링크가 있으면 설명란 첫 줄과 고정 댓글 첫 줄에 `effective_disclosure` 문구. 끄는 옵션을 만들지 않는다 |
| 유료 프로모션 | 자동 설정 금지(제안 단계). 체크박스 + 안내만 |
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
| 디자인 시스템 | 정답은 코드 하나: `apps/nomad-video/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 VID-06-044 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고 3D 재질 색도 토큰만. 3D 안에 글자·숫자를 넣지 않는다 |
| git | 정리(삭제·이동) 커밋과 기능 커밋을 분리한다(YSM #1). 원본 폴더 삭제는 사용자 승인 후 |

## 3. 디렉토리와 소유 경계

| 영역 | 경로 | 소유 작업 |
|---|---|---|
| 공통 lib, proxy | `apps/nomad-video/src/{proxy.ts,lib/**}` | VID-06-003 |
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
| Python 단계 | `core.enqueue_job(queue='video.media.cpu'|'video.media.gpu', parent_job_id=root)` → 결과 대기. Python은 `claim_jobs`만 |
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
| 타입 생성 | `supabase gen types typescript --local --schema core,video > apps/nomad-video/src/types/supabase.ts` |
| 언어 키 | `'KO' | 'JA' | 'EN'` 상수 하나 |
| 하위 프로세스 | 인자 배열, `--`, 타임아웃(01장 5절), 실패 시 kill |
| 로깅 | 공용 logger, 토큰·카드·본문 전체 금지 |
| 디자인 토큰 | `src/styles/tokens.css`(03장 4.3절 토큰 플랜, 3.2절 의미 기반 이름). 컴포넌트와 3D 재질에 hex 하드코딩 금지(`bg-[#...]` 린트 차단, 제안), 이모지 아이콘 금지(Lucide) |
| Python AI 서비스 | `apps/api`: ruff, mypy(제안), pydantic 스키마는 04장 4절 payload와 같게. 규칙·프롬프트 파일(`packages/video-rules`)은 복사본을 고치지 않는다(원본 049 소유) |
| 서버 컴포넌트 | 기본. 상호작용만 클라이언트 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -F nomad-video lint && pnpm -F nomad-video typecheck && pnpm -F nomad-video build` | 오류 0 |
| `pytest services/media-worker` | 통과 |
| `node docs/products/_tools-sqlcheck/check.mjs --vector mod <0000~0009> <seed> <1200_video.sql>` | OK(AI 표가 있어 `--vector` 필수) |
| `node docs/products/_tools-sqlcheck/check.mjs --vector mono <0001_core_lite> <0002_video_domain> <seed>` | OK |
| `pytest apps/api` | 토큰·조직 격리·라우팅·그래프·채팅 평가셋(045, 047, 049, 050, 055) |
| `pnpm test:ai` | AI 게이트 선차감·정산·환불, 내레이션 대체 금지(046, 053, 055) |
| `pnpm lhci` | 랜딩 Lighthouse, 3D 히어로 예산(054) |
| `pnpm test:rls`(VID-06-002) | 전 항목 통과 |
| `pnpm test:e2e`(007, 038), `pnpm test:integration`(037) | 통과 |

06장 7절 완료 정의를 모두 만족해야 PR을 머지한다.

## 7. 금지 패턴

07장 4절 요약: 크레딧 RPC 권한 미회수, 비원자 차감, 웹훅 서명 선택 검증·orderId 파싱, `Date.now()` customerKey, OAuth state 신뢰, 토큰 평문·0키 폴백, 세션 없는 anon 클라이언트, `FOR ALL` 정책, `x-internal-call`·자기 HTTP 호출, Mock 로그인, `/landing` 보호, 이메일 자동 계정 병합, task 소유권 미검증, 자유 모델명, 예외 원문 노출, 타임아웃 없는 하위 프로세스, yt-dlp 인자 주입, sanitize 없는 HTML, 난수 지표, 미검증 마케팅 수치, 운영자 이메일 하드코딩, 실키 `.env` 커밋, mock 응답으로 장애 숨기기. AI·디자인(2026-10-13): LLM·음성 키를 브라우저·미디어 워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보, LLM이 대가성 문구를 쓰거나 지우기, 근거 없는 수치·가상 후기 생성, 원본 오디오를 국외 STT로 보내기, 내레이션 도중 제공자 대체, 클라이언트 임의 텍스트 TTS(샘플 100자 예외), FastAPI에 미디어 처리 넣기, OpenAI TTS 백업 부활, 3D 재질에 토큰 밖 색·3D 안 숫자, "Tailwind로"만 지시해 v3 설정 생성.
