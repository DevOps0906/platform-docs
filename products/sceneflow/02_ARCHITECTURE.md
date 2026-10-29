# 02 아키텍처: SceneFlow (sceneflow)

2026-10-13 개정: AI 계층(FastAPI `apps/api`, LangGraph, RAG, 제품 지식 위키, 공용 Dify), 음성(`packages/core-voice`, 공용 오픈소스 음성 서버), 3D 히어로를 추가했다. 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, `docs/design-module/_design-guide/HERO_3D.md`이고 이 문서는 인용하며 video 고유 경계·그래프·라우팅 기본값만 정한다. 기존 Python 미디어 워커(Whisper, demucs, FFmpeg)와 새 FastAPI AI 서비스의 경계는 2절 끝 표.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router + React | 16.2.x / 19.2 (SM 기준, lockfile 고정) | `docs/reviews/NOMAD_Shorts_Maker.md:16` |
| UI | Tailwind CSS v4(CSS 우선 설정 `@import "tailwindcss"`, `@theme`, `@custom-variant dark`, 4.x 고정, `latest` 금지) + shadcn/ui(Tailwind v4 지원 버전, 구현 시 확인), lucide, recharts. `tailwind.config.js`와 v3 문법(`@tailwind base` 등) 금지 | SM 기준 | `docs/reviews/NOMAD_Shorts_Maker.md:16`, `docs/design-module/_design-guide/DESIGN_SYSTEM.md:63-73` |
| 3D | three.js + React Three Fiber + drei. 캔버스는 동적 import(`ssr: false`), 히어로 전용 컴포넌트에서만 import | React 19 호환 버전(구현 시 확인) | 확정 결정 15, `docs/design-module/_design-guide/HERO_3D.md:43-55` |
| 폼/검증/데이터 | React Hook Form + zod, TanStack Query v5 | BS 기준 | `docs/reviews/Nomad-BlogStudio.md:13` |
| DB/인증/Storage | Supabase(Postgres 15, RLS, Auth, Storage, Realtime), `@supabase/ssr` | - | CORE_SPEC 1장 |
| 오케스트레이션 워커 | Node 20 + TS, BullMQ FlowProducer, Upstash Redis(ioredis는 bullmq 내장분만) | - | 확정 결정 6, SM #11 |
| 미디어 워커 | Python 3.11, Whisper large-v3(현행 openai-whisper, 공용 음성 서버와 같은 faster-whisper 계열로의 정렬은 D-13), demucs 4, FFmpeg 6, yt-dlp, supabase-py | 3.11 고정(YSM pyc 3.14 호환 불확실, YSM #18) | 확정 결정 6 |
| AI 서비스 | FastAPI(Python) `apps/api`. 공용 ai-service(`services/ai-service`) 위에 video 확장만 둔다. 미디어 처리는 하지 않는다(2절 경계 표) | Python 3.12(제안, 구현 시 확인. 미디어 워커의 3.11 고정과 별개 서비스) | 확정 결정 3, 13, `docs/products/_platform-core/AI_ARCHITECTURE.md:132-160`, `docs/products/_platform-core/SHARED_MODULES.md:17` |
| AI 오케스트레이션 | LangChain(채팅 모델, text splitter), LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`) | 구현 시 확인 | `docs/products/_platform-core/AI_ARCHITECTURE.md:83`, `:114` |
| LLM | FastAPI 라우터: 상용 `anthropic`(Claude), `openai`(ChatGPT), `google`(Gemini), `openrouter` + 오픈소스 `oss-llm`(vLLM, OpenAI 호환). 기능별 체인은 5절. 기존 "공용 LLM 게이트웨이(OpenRouter + Anthropic 폴백)"는 라우터 체인으로 흡수 | 모델 id는 `core.ai_model_prices` 행으로 | 확정 결정 17 |
| RAG | Supabase pgvector(HNSW, cosine, 1024차원). 임베딩은 이 제품에서 모두 `oss-embed` | pgvector 0.8 이상 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107`, `docs/products/_platform-core/DB_CONVENTIONS.md:315-327` |
| 채팅 운영 | 공용 자체 호스팅 Dify 1개, 제품 앱 `video-chat`(Chatflow) | 설치 버전 문서로 확인 | 확정 결정 14, `docs/products/_platform-core/AI_ARCHITECTURE.md:58-71` |
| 음성 | `packages/core-voice`: ElevenLabs TypeScript 공식 SDK + 공용 오픈소스 음성 서버(faster-whisper + silero-vad + 상업 이용 가능 TTS). 파이프라인 STT는 미디어 워커(2절) | 구현 시 확인 | 확정 결정 16, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:5-20`, `:50-62` |
| 외부 AI | DeepL, fal(Flux), Suno(연동 방식 미확인). 코어 제공자 레지스트리에 없으므로 라우팅 대상이 아니다(01장 D-21). OpenAI TTS-1-HD 백업은 제거(01장 D-14) | - | PRD 14장, SHARED_MODULES 8-9장 |
| 결제 | Toss Payments(코어) | - | 확정 결정 4 |
| 호스팅 | Vercel(웹), Railway(TS 워커, Python CPU 워커, Python GPU 워커, `apps/api`), 공용 Dify·GPU 서버(운영사 자체 호스팅) | - | PRD:663 |

## 2. 모듈 경계

모노레포 기준(제안, SHARED_MODULES 0장 패키지 배치를 따름). 06장 소유 경계의 기준이다.

| 모듈 | 디렉토리 | 책임 | 다른 모듈과의 계약 |
|---|---|---|---|
| web-public | `apps/sceneflow/src/app/(marketing)`, `landing/[slug]`, `lb/[handle]`, `r/[code]`, `legal` | 마케팅, 공개 랜딩, 링크인바이오, 단축 링크 | 공개 RPC `get_public_landing`, `get_public_linkinbio`, 코어 `record_affiliate_click` |
| web-app | `apps/sceneflow/src/app/(dashboard)/dashboard/**` | 대시보드 화면 | `src/server/*` 서버 함수, Realtime(`core.jobs`) |
| api | `apps/sceneflow/src/app/api/**` | Route Handler(얇게) | `requireSession` → `src/server/<domain>` 호출 |
| server domain | `apps/sceneflow/src/server/{billing,channels,sources,productions,longform,music,playlists,publish,affiliate,radar,analytics,clients,brandconnect}` | 게이팅, 크레딧 선차감, 잡 enqueue, 영속화 | 코어 패키지(`core-db`, `core-billing`, `core-jobs`, `core-affiliate`, `core-ai`) |
| orchestrator | `workers/video-orchestrator/src/{flows,steps,radar,analytics,cron,bridge}` | FlowProducer 체인, AI 단계, 업로드, 레이더 수집, 스케줄 | BullMQ 큐 `video.*`(TS), 미디어 단계는 `core.jobs` 자식 잡으로 브리지 |
| media-worker | `services/media-worker/{core,handlers}` | Whisper, demucs, 다운로드, FFmpeg 전 처리 | `core.claim_jobs(queue='video.media.gpu'\|'video.media.cpu')`만 소비 |
| sns-uploader | `packages/sns-uploader/src/{youtube,meta,tiktok,naver-clip}` | 공용 업로더 구현(video 소유, commerce·blog 소비). `naver-clip`은 Playwright 어댑터(공식 API 미확인, D-23) | 인터페이스·`capabilities`·`naver-login.ts` 재사용은 SHARED_MODULES 11장 그대로(재정의하지 않음) |
| agency(대행 운영) | `src/server/clients/**`, `src/app/api/clients/**`, `src/app/(dashboard)/dashboard/clients/**`, 공개 `src/app/review/[token]/**`, 오케스트레이터 `src/agency/{report,review-expire}` | 고객·고객 채널, 승인 링크(토큰 생성·메일·결정), 월간 리포트 PDF | DB RPC `set_client_status`, `open_client_review`·`decide_client_review`(service_role), `client_reports`(service_role) |
| db | `supabase/migrations/1200_video.sql`, `supabase/monolith/**` | 스키마 | 이 폴더 05장 |
| ai-service | `apps/api/` | 공용 ai-service(`app/core`, `app/ai/llm`, `rag`, `wiki`, `tools` 공용 부분)를 그대로 쓰고 video 확장만 둔다: `app/ai/graphs/video_script.py`·`video_step.py`, `app/ai/tools/video/`(채널 코치 답변 모드, 컬렉션 로더), `app/ai/compliance/video.py`, `app/ai/products/video/`(운영자 지식 조직 id, 컬렉션 이름, 프롬프트 로더) | Supabase(service_role), 상용 LLM API, 공용 GPU 서버(`oss-llm`, `oss-embed`), Dify 내부 키 호출 수신 |
| ai-gate | `apps/sceneflow/src/app/api/{ai,internal,onboarding}/**`, `src/app/onboarding/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` | 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, EdDSA 서명 토큰·잡 토큰 발급, 정산 크론, 온보딩 국외 이전 동의 | `packages/ai-gateway` |
| voice | `apps/sceneflow/src/app/api/voice/**`, `src/components/voice/**` | STT, TTS, 음성 세션, 음성 처리 고지, 샘플 듣기 | `packages/core-voice` |
| ai-ui | `apps/sceneflow/src/components/{ai-chat,script-plan,wiki}/**`, `src/app/(dashboard)/dashboard/{chat,wiki}/**` | 채팅 패널, 대본 기획 미리보기, 위키 화면 | `components/ui` |
| hero3d | `apps/sceneflow/src/components/hero3d/**`, `public/hero/**` | 소싱 → 가공 → 배포 영상 타일 파이프라인, 모바일 1줄 흐름, 정지 이미지 | three.js, R3F, drei, 토큰 |
| design-system | `apps/sceneflow/src/styles/tokens.css`, `src/components/ui/**`, `src/app/dev/components/**` | 토큰(Tailwind CSS v4 `@theme`), 기본 컴포넌트, 라이트/다크 미리보기(프로덕션 빌드 제외) | `DESIGN_SYSTEM.md` |

AI 모듈 경계(`docs/products/_platform-core/AI_ARCHITECTURE.md:5-23`을 인용, 재정의하지 않음):

| 경계 | 규칙 |
|---|---|
| 브라우저 ↔ 서버 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지(`docs/products/_platform-core/SECURITY_BASELINE.md:299`) |
| Next.js ↔ FastAPI·음성 서버 | EdDSA 서명 토큰(`iss=video`, `aud=platform-ai:video`, scope는 04장 2.1절). 개인키는 Next.js만 |
| 오케스트레이터 ↔ FastAPI·음성 서버 | 오케스트레이터는 개인키가 없다. Next.js `/api/internal/ai-token`에서 **잡에 묶인 토큰**(running 잡의 org·user, scope `graph:video.script` 또는 `voice`)을 받아 호출한다(astro-ai의 D-18과 같은 문제. 코어 표준화 요청 R-V5) |
| Dify ↔ FastAPI | 입력 변수 `platform_conversation_id` + 내부 키 + 대화 매핑만(토큰을 넘기지 않음) |
| 3D | `src/components/hero3d/`만 three.js를 import한다. 다른 화면은 3D 의존성이 없다 |

### 미디어 워커와 FastAPI AI 서비스의 경계

기존 Python 미디어 워커(`services/media-worker`: Whisper, demucs, FFmpeg, yt-dlp)와 새 FastAPI AI 서비스(`apps/api`)는 **서로 다른 서비스**다. 코드·의존성·배포·비밀이 분리되고 직접 호출하지 않는다. 이어 주는 것은 TS 오케스트레이터와 `core.jobs`다. 확정 결정 6과 YSM 리뷰 #8("FastAPI 폐기, Python은 service_role 워커만", 06장 5절)은 미디어 쪽에서 그대로 유지한다. `apps/api`는 YSM의 FastAPI 라우터·Celery를 이식한 것이 아니라 AI 전용 신규 서비스다(07장 3절 #1).

| 항목 | Python 미디어 워커 | FastAPI AI 서비스 |
|---|---|---|
| 책임 | Whisper STT, demucs 분리, FFmpeg 합성·인코딩, yt-dlp 소싱, pHash, 파일 변환 | LLM 라우터, RAG, 위키, LangGraph, Dify 도구, compliance 규칙, 임베딩 |
| 입력 | `core.claim_jobs`(`video.media.gpu`, `video.media.cpu`)와 Storage 경로 | HTTP: 서명 토큰(Next.js 발급, 잡 토큰 포함) 또는 Dify 내부 키 + 대화 매핑 |
| 비밀 | service_role만. LLM·ElevenLabs·Dify 키와 서명 개인키 없음 | service_role, LLM·임베딩 제공자 키. ElevenLabs 키와 서명 개인키 없음 |
| 다루는 데이터 | 영상·오디오 바이너리 | 텍스트와 임베딩. 영상·오디오 바이너리 처리 금지(FFmpeg·Whisper·demucs 실행 금지) |
| 상대 서비스 호출 | 하지 않는다 | 하지 않는다 |
| 사용량 기록 | STT 호출마다 `core.ai_usage`(kind `stt`, source `open_source`, provider `oss-voice`, feature `video.stt`, `audio_seconds`) 직접 기록(service_role). 크레딧 선차감은 루트 production에 포함 | 라우터가 `ai_usage`, 그래프가 `ai_runs`·`ai_run_steps` 기록. 크레딧 선차감·정산은 Next.js 게이트 |
| 배포 | Railway CPU 2~4 + GPU 호스트 1(7절) | Railway 서비스 1(CPU), 공용 GPU 서버(`oss-llm`, `oss-embed`)를 호출 |

STT 두 경로(01장 VD-F-105, D-13):

| 경로 | 용도 | 구현 | 한도 | 인증 |
|---|---|---|---|---|
| 파이프라인 STT `media.stt` | 원본 영상 음성·롱폼 내레이션 역방향 자막 → 세그먼트 | 미디어 워커의 Whisper(GPU 호스트). 라우팅 기능 `video.stt` = `oss-voice` 고정, 사용량 기록 | 원본 500MB, 롱폼 60분 | DB(`core.claim_jobs`). 서명 토큰 불필요 |
| 대화형 STT | 음성 대화, 대본 받아쓰기(60초 이하) | Next.js `/api/voice/stt` → 공용 음성 서버 `/stt` | 60초·5MB(서버 한도 10분·50MB) | EdDSA 서명 토큰 scope `voice` |

규칙: `src/server`만 service_role 클라이언트를 import한다. 화면 컴포넌트는 서버 함수 또는 RLS 하의 조회만 쓴다. 내부 HTTP 자기 호출(`fetch(APP_URL + '/api/...')`) 금지, 함수 직접 호출만(SM #4, #15).

## 3. 공용 모듈 사용

재정의하지 않는다(SHARED_MODULES 18장).

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 가입(`signup_app='video'`), 세션, `requireSession`, 로그인 단계(`src/lib/auth/`: `getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`. 단계 분기는 여기·로그인 화면·`/auth/callback`·`/api/dev/login`만, 9절) | `proxy.ts`, 레이아웃, 모든 Route Handler | 기본 역할 admin 금지. 기능 코드에서 `AUTH_MODE` 참조 금지(확정 결정 22) |
| org | 1인 1워크스페이스, Advanced 멤버 초대 | `src/server/team` 대신 코어 RPC 직접 | `team_members` 상한은 서버 판정 |
| credits | 생성·업로드·검사 선차감, 실패 환불, 부분 환불 | `src/server/*` | 멱등 키 `consume:video:<request_id>` |
| toss | 구독, 크레딧팩, 빌링키 | `src/server/billing`, orchestrator cron | `confirm_payment_order` PM001 시 별도 호출로 `fail_payment_order`(service_role)를 불러 주문을 failed로 남기고 운영 알림 + Toss 취소를 수행 |
| webhooks | Toss, fal, (Phase 2) Distrokid, Make/n8n | `src/app/api/webhooks/*` | 서명 없으면 거부 |
| oauth | YouTube/Meta/TikTok 채널 연결, 쿠팡 키 저장. 네이버 클립은 OAuth가 아니라 로그인 세션을 `CredentialVault`(provider `naver`)에 저장 | `src/server/channels`, `src/server/affiliate` | state는 `create_oauth_state`만 |
| llm gateway | 사용하지 않는다(2026-10-13). 번역 후처리, 대본, 스토리라인, 블링, GEO 메타, 플리 메타, compliance의 LLM 호출은 라우터(ai-service)로 옮겼다 | - | 라우터 본체가 ai-service로 옮겨졌다(`docs/products/_platform-core/SHARED_MODULES.md:42`). 모델 허용 목록(YSM #6)은 `core.ai_model_prices` 등록 모델과 라우팅 체인으로 대체. 그래프 `video.script`와 `video.step`(D-20)이 호출 경로 |
| ai-gateway | 대화 매핑, 서명 토큰·잡 토큰 발급, 턴 선차감·정산, Dify 중계와 장애 시 직접 경로 | `src/app/api/ai/`, `src/app/api/internal/`, `src/server/ai/` | `docs/products/_platform-core/SHARED_MODULES.md:498` |
| ai-service | 라우터, RAG(트렌드·성과·대본·가이드), 위키, 그래프 `video.script`·`video.step`, 도구 `/tools/answer` | `apps/api` | 제품 확장은 2절 `ai-service` 행 |
| dify | 채팅 앱 `video-chat`(질문 분류, HTTP 노드, 외부 지식) | Next.js `src/app/api/ai/chat` | Dify DB는 조직 데이터 저장소로 관리(로그 30일) |
| core-voice | STT(대화형), TTS(샘플·읽어 주기·내레이션). 내레이션은 `feature='narration'`에서 대체를 끈다 | `src/app/api/voice/`, 오케스트레이터 `steps/tts/`(D-22) | `docs/products/_platform-core/SHARED_MODULES.md:501` |
| llm-wiki | 채널·브랜드 가이드 위키(제품 지식 위키), 운영자 가이드(`video-guide`) | `apps/api`(ingest, lint), `src/components/wiki/`, `dashboard/wiki/` | 조직 위키는 조직 간 공유 없음. 운영자 지식은 외부 지식 API로만 노출 |
| fal client | Track C/D 이미지, 썸네일, 플리 무드 썸네일, 곡 커버 | orchestrator steps | 결과를 `video-media`로 복사 |
| sns uploader | 업로드, 고정 댓글, 쿼터, 통계. `naver_clip`은 고정 댓글·통계 미지원(`capabilities`) | orchestrator `upload.*` | video가 구현 소유 |
| affiliate(브랜드커넥트) | 클립 캠페인 지원 요청(`create_brandconnect_application`, `target_kind='clip'`, `source_app='video'`), blog handoff 수신, 선정 지원서 ↔ 업로드 연결. 제출 어댑터는 blog 소유 | `src/server/brandconnect` | 대가성 문구는 `injectDisclosure(..., { target: 'title_hashtag' })`(naver_clip) |
| automation-core | Phase 2 캔버스 실행 | (Phase 2) | 저장만 `video.workflows` |
| compliance | 업로드 게이트 | orchestrator `compliance.check` | 조직 추가 사전 `video.banned_words` |
| storage | 사용자 업로드(org-files), 서명 URL | 전역 | 대용량은 제품 버킷 `video-media` |
| audit | 채널 변경, WARN 확인, 업로드 취소, 랜딩 공개, 유통 상태 | 제품 RPC 내부, 서버 | |
| jobs | 상태 정본, Python 클레임, 자동 환불 | 전역 | BullMQ 상태를 `core.jobs`에 미러링 |
| affiliate | 계정, 링크, 단축 코드, 대가성 문구 | `src/server/affiliate`, `src/server/publish`, `/r/[code]` | 문구는 `effective_disclosure`, 편집은 `upsert_affiliate_disclosure` |

## 4. 잡과 워커

원칙: 생성 요청 1건 = 루트 `core.jobs` 1행(크레딧 원장 연결) + BullMQ Flow. TS 단계는 BullMQ 자식 잡, Python 단계는 브리지 스텝이 `core.enqueue_job(parent_job_id=루트)`로 만든 자식 잡을 기다린다(폴링 5초 + Realtime). 단계 결과는 `returnvalue`로 다음 단계에 전달한다(placeholder 금지, SM #9). Python은 BullMQ를 흉내 내지 않는다(MA:671, :707).

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `production.run`(루트, Track A/B/C) | `video.orchestrate` | TS | 요청 시 합계(단가표) | 0(자식이 재시도) | 루트 실패 시 잔액 전액 자동 환불, 언어별 실패는 그 언어분 부분 환불 |
| `source.download` | `video.media.cpu` | Python | 소싱 1 | 2 | 최종 실패 |
| `media.stt` | `video.media.gpu` | Python | 루트에 포함 | 2 | 루트 규칙 |
| `media.separate`(demucs) | `video.media.cpu` | Python | 루트에 포함 | 1 | 루트 규칙 |
| `media.silence_cut`, `media.compose`, `media.encode`, `media.kenburns`, `media.watermark_remove` | `video.media.cpu` | Python | 루트에 포함 | 2 | 루트 규칙 |
| `ai.translate`, `ai.image` | `video.ai` | TS | 루트에 포함 | 3(지수 백오프) | 루트 규칙. `ai.translate`의 LLM 후처리는 `video.step`(D-20) 경유 |
| `ai.script` | `video.ai` | TS(그래프 클라이언트) | 루트에 포함(빠른 모드). 정밀 모드는 `run:<ai_run_id>` 별도 선차감 | 1 | 루트 규칙 / 정밀 모드는 즉시 환불. FastAPI `POST /graphs/video.script/runs`를 잡 토큰으로 호출하고 `GET /graphs/runs/{id}`로 대기 |
| `ai.tts` | `video.ai` | TS(`core-voice`) | 루트에 포함 | 3(지수 백오프). 제공자는 작업 시작 때 고정하고 재시도도 같은 제공자(대체 없음) | 루트 규칙. 구간 실패는 그 언어판 실패(VD-F-106) |
| `ai.trend_ingest`, `ai.rag_ingest`, `ai.wiki_ingest`, `ai.wiki_lint` | `video.ai` | TS(요청) → FastAPI | 0 또는 2 / 1(01장 4.1절) | 2 | 해당 없음 / 실제 사용량만 정산 |
| `ai.settle` | `video.ai` | TS(Next.js `/api/internal/ai-settle` 호출) | 0 | 3 | 해당 없음 |
| `longform.storyline` | `video.ai` | TS(그래프 클라이언트) | 5(동기 호출, withCredits). 그래프 `video.script`(Track D) 빠른 모드, 정밀 모드는 8 | 1 | 즉시 환불 |
| `longform.render`(루트) | `video.orchestrate` | TS | 이미지 10장 + TTS + 인코딩 합계 | 0 | 루트 규칙 |
| `longform.highlights` | `video.orchestrate` | TS+Python | 11 | 1 | 최종 실패 |
| `music.generate` | `video.ai` | TS | 15 + 커버 3 + 루프 5 | 2 | 최종 실패 |
| `music.package` | `video.ai` | TS | 0 | 2 | 해당 없음 |
| `playlist.render`(루트) | `video.orchestrate` | TS | 렌더 + 메타 + 썸네일 | 0 | 루트 규칙 |
| `media.loop`, `media.playlist_concat`, `media.highlight_cut` | `video.media.cpu` | Python | 루트에 포함 | 2 | 루트 규칙 |
| `compliance.check` | `video.ai` | TS | 1(LLM 단계가 있을 때). LLM 판정은 `video.step`(kind `compliance_llm`, D-20) 경유 | 1 | LLM 실패 시 환불 + WARN |
| `upload.youtube` / `upload.instagram` / `upload.tiktok` / `upload.threads` | `video.upload` | TS | 1/채널 | 3 | 최종 실패. 쿼터 초과는 실패가 아니라 `run_after` 재예약 |
| `upload.naver_clip` | `video.upload.browser`(동시성 1/계정, 제안) | TS(Playwright, 헤드리스 Chromium) | 1/채널 | 1 | 최종 실패(셀렉터 실패 포함). 계정당 3건/시간·15건/일 초과는 `run_after` 재예약. 동의 철회 시 queued 잡 취소·환불 |
| `brandconnect.apply`(`source_app='video'`) | blog 큐(blog 소유 어댑터) | TS(Playwright) | 0 | blog 규칙 | 해당 없음. video는 지원서 상태만 읽는다 |
| `client_report.build` | `video.orchestrate` | TS(집계) + PDF 렌더(코어 exports) | 0 | 2 | 해당 없음. 실패 시 `client_reports.status=failed` + 운영 알림 |
| `radar.playboard` | `video.radar` | TS | 0(플랫폼 공용 수집) | 3 | 해당 없음 |
| `radar.channel_finder`, `radar.bling` | `video.radar` | TS | 2 / 5 | 1 | 최종 실패 |
| `analytics.sync` | `video.radar` | TS | 0 | 3 | 해당 없음 |

스케줄(워커 크론, service_role. CRON_SECRET 공개 라우트 금지):

| 주기 | 작업 |
|---|---|
| 매 10분 | `core.reap_stale_jobs(600)`, `video.purge_expired_sources()` + Storage 삭제, 예약 업로드 enqueue(`uploads.status='scheduled' and scheduled_at<=now()+5분`) |
| 매 시간 | `core.expire_stale_payment_orders()` |
| 매일 00:10 KST | `core.run_monthly_credit_grants()` |
| 매일 PT 00:00(미확인) | `video.reset_channel_quotas()` |
| 매일 03:00 KST | 플레이보드 수집, `analytics.sync`, 산출물 보존 기간 만료 삭제, 빌링키 갱신 청구 |
| 수집 직후 | `ai.trend_ingest`(운영자 `video-trends` 컬렉션), `analytics.sync` 직후 `ai.rag_ingest`(조직 `video-performance`) |
| 매 5분 | AI 정산(`ai.settle` → `/api/internal/ai-settle`, `settled_at is null` 10분 경과 행) |
| 주 1회 | 채널·브랜드 가이드 위키 lint(`ai.wiki_lint`, 운영사 부담 한도 안) |
| 매 시간 | 만료된 고객 승인 요청 정리(`client_reviews` pending + `expires_at<now()` → expired, 업로드는 `client_review` 유지, 담당자 알림) |
| 매일 06:00 KST | `clients.report_day`가 오늘인 활성 고객의 지난달 `client_report.build` enqueue |

## 5. AI 라우팅

설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md:73-92`(LLM 라우터), `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`(음성)이다. 아래 5.1절은 video 기능별 기본값이며 `docs/products/_supabase-modular/migrations/1200_video.sql` 11절과 `supabase/monolith/seed.sql`의 `ai_routing_settings`(org null, app `video`) 17행과 같다. 이 절의 첫 표(purpose)는 기존 파이프라인 단계의 모델 등급이고, 기능 키와의 대응은 5.1절 "쓰는 곳"에 있다.

| purpose | 모델(fast / quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `translate`(DeepL 후 톤 각색: A 도파민형, B 리뷰어 톤) | 게이트웨이 fast / quality | STT+번역 5/분에 포함 | DeepL 결과 그대로 + 경고 |
| `script`(Track C 대본, 롱폼 10섹션) | quality | 3 / 5 | 게이트웨이 폴백 모델 1회 |
| `analyze`(상품명 파싱, 주제 점수, 하이라이트 선정) | fast | 포함 / 2 | 폴백 1회 |
| `bling` | quality(웹 검색 가능 모델, 미확인) | 5 | 실패 시 환불 |
| `geo_meta`, `playlist_meta` | fast | 포함 / 2 | 폴백 1회 |
| `compliance` | fast | 1 | 실패 시 WARN + 환불 |

모델 이름은 라우터 설정(`core.ai_model_prices` 등록 모델 + 체인)에서만 바꾼다. 요청 본문의 모델 지정은 받지 않고 지정하면 422(YSM #6). 폴백은 라우터 체인의 다음 제공자이며 `core.ai_usage.status='fallback'`로 남는다.

| 매체 | 제공자 | 비고 |
|---|---|---|
| STT(파이프라인) | Whisper large-v3(자체 GPU 워커), 라우팅 기능 `video.stt` = `oss-voice` | 프로세스당 모델 1회 로드, 동시성 1. 공용 음성 서버와 같은 faster-whisper 계열 정렬은 D-13 |
| STT(대화형) | 공용 음성 서버 `/stt`(faster-whisper + silero-vad) 또는 ElevenLabs, 기능 `voice_chat`·`dictation` | 60초 이하. 체인 5.1절 |
| TTS | ElevenLabs Multilingual v2 또는 공용 음성 서버 오픈소스 TTS. 사용자가 생산 요청에서 선택(`voice.provider`), `auto`는 체인 순서 | OpenAI TTS-1-HD 백업은 제거(D-14). Edge-TTS/CLOVA 제외(MA:576). 같은 목소리 규칙은 5.3절 |
| 이미지 | fal Flux Pro/Ultra | `enable_safety_checker=true` |
| 음원 | Suno | 공식 공개 API 여부 미확인. 확인 전에는 사용자가 Suno에서 만든 파일 업로드 경로 병행(01장 8절 D-8) |
| 음원 분리 | demucs | BGM/보이스 분리, 타임아웃 900초 |

### 5.1 기능별 라우팅 기본값

| feature | kind | 모드 | 대체 체인 | 강제 오픈소스 | 쓰는 곳 | 이유 |
|---|---|---|---|---|---|---|
| `video.script` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `trend`·`plan`·`script`·`metadata` 노드 | 대본 품질이 제품 핵심이라 Claude 우선. 채널 토큰·이메일은 보내지 않는다(01장 6.1절) |
| `video.translate` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | `video.step`(kind translate): DeepL 이후 톤 각색 | 톤 품질 우선(purpose `translate` quality) |
| `video.analyze` | llm | auto | oss-llm → anthropic | 아니오 | `video.step`(kind analyze): 상품명 파싱, 주제 점수, 하이라이트 선정 | 단순 분류·추출, 대량(purpose `analyze` fast) |
| `video.bling` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | `video.step`(kind bling) | 웹 검색 가능 모델은 미확인(purpose `bling`). 출처 필수 규칙은 그대로 |
| `video.compliance` | llm | auto | oss-llm → anthropic | 아니오 | `video.step`(kind compliance_llm): 업로드 게이트 LLM 판정 | 규칙 단계가 1차 방어, LLM은 보조(purpose `compliance` fast) |
| `chat` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | `/tools/answer`(채널 코치) | 한국어 품질 |
| `wiki.query` | llm | auto | oss-llm → anthropic | 아니오 | Dify 용어 설명 분기, 대체 경로 | 위키 요약이라 오픈소스로 충분 |
| `wiki.ingest` | llm | auto | oss-llm → anthropic | 아니오 | 가이드 문서 → 위키 | 대량 처리 |
| `wiki.lint` | llm | auto | oss-llm → anthropic | 아니오 | 주 1회 점검 | 같음 |
| `dify.aux` | llm | open_source | oss-llm | 예 | Dify 질문 분류 노드(FastAPI `/v1/chat/completions`) | 조직을 알 수 없어 국외 이전 동의를 확인할 수 없다 |
| `video.knowledge` | embedding | open_source | oss-embed | 아니오(대체 없음) | 운영자 컬렉션 `video-trends`, `video-guide` 색인·검색 질의 | 동의하지 않은 사용자의 질의도 같은 모델로 임베딩해야 하므로 오픈소스 고정. 모델을 바꾸면 재색인 |
| `video.rag` | embedding | open_source | oss-embed | 아니오(대체 없음) | 조직 컬렉션 `video-performance`, `video-scripts`, `video-brand` | 조직이 동의를 바꿔도 컬렉션 임베딩 모델이 흔들리지 않게 고정 |
| `video.stt` | stt | open_source | oss-voice | 예 | 파이프라인 STT(미디어 워커) | 원본은 제3자 저작물·목소리라 국외 제공자로 보내지 않는다. 조직 관리자가 풀 수 없다(`AI001`). 대체 없음 |
| `voice_chat` | stt | auto | oss-voice → elevenlabs | 아니오 | 음성 질문 | 대량·저비용(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:45`) |
| `dictation` | stt | auto | oss-voice → elevenlabs | 아니오 | 대본 받아쓰기 | 같음 |
| `voice_chat` | tts | auto | elevenlabs → oss-voice | 아니오 | 답변·대본 읽어 주기 | 품질 우선 |
| `narration` | tts | auto | elevenlabs → oss-voice | 아니오 | 내레이션, 샘플 듣기 | 사용자가 `voice.provider`로 고를 수 있다. 작업 도중 대체 금지(5.3절) |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 국외 이전 동의 | 동의하지 않은 조직은 `resolve_ai_route`가 상용 제공자를 체인에서 뺀다. `narration`은 oss-voice만 남는다. `dify.aux`는 동의 후에도 `oss-llm` | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:419-476` |
| 임베딩 고정 | 검색 질의 임베딩은 라우팅이 아니라 컬렉션에 기록된 `embedding_provider`·`embedding_model`을 쓴다 | `docs/products/_platform-core/DB_CONVENTIONS.md:315-327` |
| OpenRouter | 플랫폼 제공자로 등록돼 있지만 video 기본 체인에는 넣지 않는다(같은 모델의 중복 경로이고 국외 제공자만 늘어난다) | `docs/products/_supabase-modular/seed.sql:218` |
| 조직 재정의 | 제품 화면에서 `set_ai_routing`을 쓰지 않는다. 사용자가 고르는 것은 국외 이전 동의(온보딩·설정)와 생산 요청의 내레이션 엔진뿐이다 | 01장 VD-F-106, VD-F-108 |
| seed 검사 | 11절 끝의 DO 블록이 체인 제공자의 존재·종류·오픈소스 모드를 검사하고 어긋나면 마이그레이션을 실패시킨다(제공자 행이 아직 없으면 건너뜀) | `1200_video.sql` 11.3절 |

### 5.2 LangGraph 그래프

| 그래프 | 노드 순서 | LLM 기능 | 사람 승인 | compliance | 실행 |
|---|---|---|---|---|---|
| `video.script` | `trend` → `plan` → `script` → `metadata` → `compliance` → (걸린 부분만 `script` 또는 `metadata` 1회 재작성 → `compliance`) | `video.script` | UI에서 시작한 정밀 모드는 `plan` 뒤 interrupt(사용자가 기획안 3안 중 선택·수정하면 같은 thread를 재개, 24시간 안 재개하지 않으면 `canceled` + 선차감 환불). 파이프라인(오케스트레이터)이 시작한 실행은 interrupt 없이 1안으로 진행. 발행·결제·외부 전송은 그래프에 없고 업로드는 기존 compliance 게이트(VD-F-072)와 WARN 확인 RPC를 거친다. Track D 스토리라인은 사용자가 편집 | 있음. 규칙 파일 `packages/video-rules/banned.json`(제안 위치). 마지막 `compliance` 노드가 대본과 제목·설명·태그를 함께 검사하고 대가성 문구 모방 문장을 걸러 낸다(`docs/products/_platform-core/AI_ARCHITECTURE.md:117` 충족, 2026-10-13 교차 검토 반영) | 사용자 UI는 Next.js 게이트 경유, 파이프라인은 오케스트레이터가 잡 토큰으로 요청. 체크포인트 thread = `ai_runs.thread_id` |
| `video.step`(D-20 (a), 제안) | `run` → `compliance` | `video.translate`, `video.analyze`, `video.bling`, `video.compliance` (입력 `kind`로 분기) | 없음 | 있음(출력 규칙, kind `compliance_llm`은 판정 자체가 결과라 면제) | 오케스트레이터 단계에서 동기 호출(실행 id로 대기) |

| 노드 | 입력 | 동작 | 출력 | LLM |
|---|---|---|---|---|
| `trend`(트렌드 검색) | track, 주제 또는 카테고리, 국가·언어 | 운영자 컬렉션 `video-trends` 검색(`match_ai_chunks(운영자 지식 조직, 'video', 임베딩, k=8, 컬렉션)`) + `video.trend_videos` 정형 조회(국가·기간·카테고리 상위, `is_estimated` 포함). 조직 데이터가 아니라 제품 공통 지식. **정밀 모드에서만** 실행 | 근거 청크·행 id 목록 | 없음(임베딩만) |
| `plan`(기획) | 트렌드 근거, 조직 컬렉션 검색(성과·과거 대본·브랜드), 채널 역할·언어, 게시된 가이드 위키 | 각도 3안, 훅, 구조(Track별), 권장 Track, 위험 주제 표시. **정밀 모드에서만** 실행. 근거 id 없는 수치는 쓰지 않는다 | 기획안 JSON | 있음(`video.script`) |
| `script`(대본) | 기획안(빠른 모드는 주제만), Track | Track B/C Mode1: 훅 15초/본문 30초/CTA 5초. Track D: 스토리라인 + 10섹션 대본·이미지 프롬프트. 언어별 | 대본 JSON(pydantic 검증, 워커가 zod로 재검증) | 있음 |
| `compliance`(금지 문구 검사, 마지막 노드) | 대본과 메타 JSON | 규칙 사전 + 조직 `banned_words`(severity fail/warn) + 허위 후기·성과 보장·최상급 단정·출처 없는 수치 검사. 걸린 부분만 해당 노드(`script` 또는 `metadata`)가 1회 재작성, 2회 실패면 run `failed` | 통과 / 걸린 목록 | 없음(규칙) |
| `metadata`(메타데이터) | 대본, 제휴 링크 슬롯 | 제목·설명·태그 KO/JA/EN(GEO). 설명란 첫 줄과 고정 댓글 첫 줄은 비워 두고 `has_affiliate`·`affiliate_link_ids`를 그대로 전달. 검사는 다음 `compliance` 노드가 한다 | 메타 JSON | 있음 |

대가성 문구(확정 결정 12): 그래프는 문구를 생성하지도 지우지도 않는다. 설명란·고정 댓글 첫 줄 삽입은 `src/server/publish`가 `effective_disclosure`로 하고, `uploads_disclosure_check`(DB CHECK)가 최종 보장한다(05장 7절 SM 리뷰 연계).

### 5.3 같은 목소리 규칙 (내레이션)

정본은 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47`이다.

| 항목 | 규칙 |
|---|---|
| 고정 시점 | `production.run`·`longform.render` 시작 때 `resolve_ai_route`(feature `narration`, kind `tts`)와 사용자의 `voice.provider`를 합쳐 쓸 수 있는 제공자 하나와 보이스 id를 정해 `productions.options.voice`(롱폼은 첫 섹션의 `narration_paths`)에 기록한다. 이후 모든 구간은 이 값만 쓴다 |
| 사용자 선택 | `elevenlabs`(미동의·비활성이면 선택지에서 숨김), `oss-voice`, `auto`(체인 순서의 첫 가용). 선택지는 언어별 검증 통과 보이스만(D-15) |
| 대체 금지 | 구간 실패는 같은 제공자로만 재시도(지수 백오프 3회). 계속 실패하면 그 언어판 실패 + 그 언어분 환불. 다른 제공자로 이어 붙이지 않는다 |
| 재생성 | 롱폼 섹션 재생성·재렌더는 기록된 제공자·보이스를 따른다. 쓸 수 없으면 전체 섹션 재내레이션을 사용자에게 제안(전체 단가) |
| 샘플 | 샘플 듣기는 같은 제공자·보이스로만 만들고 대체하지 않는다 |
| 기록 | 구간마다 `core.voice_jobs`(feature `narration`, `provider_id`, `voice_id`, `fallback_from` null)와 `ai_usage`(kind tts, characters) |

기능 키와 기존 purpose의 대응: `translate`→`video.translate`, `script`·`geo_meta`·`playlist_meta`→그래프 `video.script`(`metadata` 노드; 플리 메타는 `video.step` kind `playlist_meta`로 `video.script` 키 사용), `analyze`→`video.analyze`, `bling`→`video.bling`, `compliance`→`video.compliance`.

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 "높음" 26건(SM 12, BS 10, YSM 4) 중 비보안 7건을 여기 두고, 보안·데이터 19건은 05장 7절에 둔다. 합계 26 = 차단 설계 26.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #3 | `src/app/api/billing/checkout/route.ts:18` | checkout과 웹훅의 orderId 형식이 달라 정상 결제가 처리되지 않음 | orderId 파싱을 없애고 코어 `payment_orders` 선저장 → confirm 단일 경로. 웹훅은 상태 동기화만(CORE_SPEC 5.2, 6장) | VID-06-006, 007 |
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #9 | `src/lib/queue/pipeline-track-a.ts:33-100` | 8개 큐 동시 enqueue, placeholder 전달, 즉시 done, fire-and-forget | FlowProducer 부모-자식 체인, `returnvalue` 전달, 상태는 워커 완료 이벤트로만 갱신(전이 트리거가 queued→ready 직행을 22023으로 거부, `1200_video.sql:103-138`). Route Handler는 enqueue만 하고 await 가능한 짧은 작업만 | VID-06-015 |
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #10 | `src/lib/queue/workers/stt.worker.ts:6,18` | TS 워커가 `next/headers` 의존, 기동 스크립트 없음, Python과 같은 큐 소비 | 워커는 `workers/video-orchestrator` 독립 패키지(`npm run worker`), service_role 클라이언트만. Python은 `video.media.*` 큐를 `core.claim_jobs`로만 소비. 페이로드 계약 04장 4절 | VID-06-011, 015 |
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #11 | `src/lib/queue/bullmq.ts:86` 외 | tsc 21개 오류로 빌드 실패, ioredis 중복, 키 대소문자 불일치 | 원본 코드 복사 대신 이식 시 타입 재작성. 언어 키는 `'KO'\|'JA'\|'EN'` 상수 하나. ioredis 루트 의존 제거. CI에서 `tsc --noEmit` 실패 시 머지 불가 | VID-06-039 |
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #12 | `src/app/landing/[slug]/page.tsx:7-46` | Next 16 `params` Promise 미대응, `generateStaticParams`가 cookies 클라이언트 사용, 없는 RPC 호출 | `params`를 await, 공개 페이지는 쿠키 없는 anon 클라이언트로 `video.get_public_landing` 호출, 조회수는 `video.record_landing_view`(service, 존재 확인됨 `1200_video.sql:1434`) | VID-06-023 |
| `docs/reviews/Nomad-BlogStudio.md` 3장 #10 | `src/lib/supabase/middleware.ts:32` | `/landing` 접두사를 보호해 공개 쿠팡 랜딩이 로그인으로 리다이렉트 | 대시보드는 `/dashboard/**` 아래에만 둔다(랜딩 관리 화면은 `/dashboard/monetize/landings`). `proxy.ts` 공개 경로 배열 + 단위 테스트 | VID-06-003, 023 |
| `docs/reviews/Youtube_shots_Maker.md` 3장 #1 | git `0b7f3fa` | 무관한 커밋에서 소스 109개 삭제 | 이식은 `git show 5f6d262:` 읽기로만 한다. 사용자 승인 후 태그 `archive/youtube-shots-maker-v1` 생성, 정리 커밋과 기능 커밋 분리 규칙을 CLAUDE.md에 명시(07장 5절) | VID-06-040 |

## 7. 배포 토폴로지

| 구성 | 배치 | 네트워크 경계 |
|---|---|---|
| 웹(Next.js) | Vercel | 공개. service_role 키는 서버 런타임 env만 |
| video-orchestrator | Railway 서비스 1(Node), 수평 확장 2~4 | 아웃바운드만(Redis, Supabase, 외부 API) |
| media-worker CPU | Railway 서비스 2(Python + FFmpeg + demucs + yt-dlp), 2~4 인스턴스 | 아웃바운드만. 소싱용 프록시 풀 경유 |
| media-worker GPU | GPU 호스트 1대(Whisper) — Railway GPU 가용성 미확인, 대안 GPU 클라우드 | 아웃바운드만 |
| Redis | Upstash | TLS, 워커와 웹(enqueue 전용 얇은 모듈, lazy 연결, SM #19) |
| `apps/api`(FastAPI AI 서비스) | Railway 서비스 1(Python, CPU). 공개 HTTPS이며 서명 토큰 또는 내부 키가 없으면 401(Dify HTTP 노드와 Vercel·워커가 호출하므로 private network만으로는 부족) | Supabase(service_role), 상용 LLM API, 공용 GPU 서버(`oss-llm`, `oss-embed`) |
| Dify(공용) | 운영사 자체 호스팅(`D:\WorkSpace\DEV\platform-dify\`, 제안). 콘솔은 운영자만(2단계 인증) | Next.js → Dify Chat API(앱 키), Dify → FastAPI `/tools/*`, `/v1/chat/completions`, `/dify/retrieval`(내부 키) |
| 공용 GPU 서버 | 운영사 자체 호스팅(`oss-llm` vLLM, `oss-embed`, `oss-voice`). 비공개(서명 토큰·내부 키) | FastAPI(LLM·임베딩), Next.js·오케스트레이터(음성) |
| ElevenLabs | 외부 SaaS(국외) | Next.js 서버(샘플·읽어 주기)와 오케스트레이터(내레이션, D-22). 브라우저 직접 호출 금지 |
| Supabase | 모듈러 통합 프로젝트 | Storage `video-media`는 서명 URL로만 노출 |

렌더 경로: 웹은 enqueue → orchestrator가 단계 실행 → Python이 `video-media`에서 입력을 받고 결과를 다시 올린 뒤 `complete_job(result.storage_path)` → orchestrator가 `outputs` 갱신 → 클라이언트는 `core.jobs` Realtime으로 진행률 확인.

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버·워커 | 비공개 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core` 또는 `public` | 비공개 | 기동 실패 |
| `NEXT_PUBLIC_APP_URL` | 단축 링크, OAuth 리다이렉트 | 공개 | 기동 실패 |
| `UPSTASH_REDIS_URL` | BullMQ | 비공개 | 워커·enqueue 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 토큰 AES-256-GCM | 비공개 | 기동 실패(0키 폴백 금지) |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | 결제 | 클라이언트 키만 공개 | 기동 실패 |
| `GOOGLE_CLIENT_ID/SECRET`, `META_APP_ID/SECRET`, `TIKTOK_CLIENT_KEY/SECRET` | 채널 OAuth(사용자 로그인용 Google 클라이언트와 별개, 9절·01장 D-29) | 비공개 | 해당 플랫폼 연결 비활성 + 경고 |
| `NAVER_CLIP_UPLOAD_ENABLED`, `PLAYWRIGHT_BROWSERS_PATH` | 네이버 클립 업로더 스위치(셀렉터 장애 시 끔), 브라우저 경로 | 비공개(오케스트레이터) | 기본 false. false면 `naver_clip` 업로드 예약 거부 + 대시보드 경고 |
| `CLIENT_REVIEW_BASE_URL`, `CLIENT_REVIEW_TTL_HOURS` | 고객 승인 링크 주소, 기본 유효시간(72) | 비공개(Next.js 서버) | 대행 승인 요청 비활성 |
| `MAIL_FROM_AGENCY` | 승인 요청·리포트 메일 발신 주소(코어 메일 모듈) | 비공개 | 승인 메일 발송 실패 → 링크 복사만 |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OPENROUTER_API_KEY` | 상용 LLM | **FastAPI 전용**(Vercel·오케스트레이터·미디어 워커에 넣지 않음) | 해당 제공자만 비활성(체인에서 다음으로). 전부 없으면 오픈소스만 |
| `OSS_LLM_BASE_URL`, `OSS_EMBED_BASE_URL` | 오픈소스 LLM·임베딩 서버 | FastAPI 전용 | 기동 실패(`video.rag`·`video.knowledge` 임베딩과 미동의 조직 처리에 필수) |
| `VOYAGE_API_KEY` | 상용 임베딩 | FastAPI 전용 | video는 `oss-embed`만 쓰므로 없어도 동작(플랫폼 기본값 호환용) |
| `AI_TOKEN_PRIVATE_KEY`, `AI_TOKEN_KID` | EdDSA(Ed25519) 서명 토큰 발급 | Next.js 서버 전용 | 기동 실패 |
| `AI_TOKEN_JWKS_URL` | 서명 토큰 공개키 | FastAPI, 오픈소스 음성 서버 | 기동 실패 |
| `AI_SERVICE_URL` | FastAPI 주소 | Next.js 서버, 오케스트레이터 | AI 기능 비활성 + 오류 표시, 오케스트레이터 기동 실패 |
| `DIFY_API_URL`, `DIFY_APP_KEY_VIDEO` | Dify Chat API, `video-chat` 앱 키 | Next.js 서버 전용 | 채팅은 FastAPI 직접 경로(`/tools/answer-direct`)로만 동작 + 운영 알림 |
| `DIFY_INTERNAL_API_KEY` | Dify HTTP 노드 → FastAPI 인증(video 전용 값) | FastAPI와 Dify 환경변수(비밀) | FastAPI 기동 실패 |
| `DIFY_USER_HMAC_SECRET` | `dify_user = HMAC(org:sub)` | Next.js 서버 전용 | 기동 실패 |
| `VIDEO_WORKER_INTERNAL_KEY` | 오케스트레이터 → `/api/internal/ai-token` 인증 | Next.js 서버, 오케스트레이터 | 기동 실패 |
| `VIDEO_KNOWLEDGE_ORG_ID` | 운영자 컬렉션(`video-trends`, `video-guide`)을 두는 운영자 조직 id | Next.js 서버, FastAPI, 오케스트레이터 | 트렌드 검색·가이드 비활성 + 기동 경고 |
| `AI_CROSS_BORDER_NOTICE_VERSION` | 국외 이전 고지문 버전 | Next.js 서버 | 기동 실패 |
| `OSS_VOICE_BASE_URL` | 오픈소스 음성 서버 | Next.js 서버, 오케스트레이터 | 기동 실패 |
| `VIDEO_NARRATION_VOICE_ELEVENLABS_KO/JA/EN`, `VIDEO_NARRATION_VOICE_OSS_KO/JA/EN` | 내레이션 기본 보이스 id(D-15, D-16) | Next.js 서버, 오케스트레이터 | 해당 언어·엔진 선택지 숨김 |
| `NEXT_PUBLIC_HERO3D_ENABLED` | 3D 히어로 전체 끄기 스위치(장애 대응) | 공개 | 기본 true. false면 정지 이미지 |
| `DEEPL_API_KEY`, `FAL_KEY`, `SUNO_API_KEY` | 코어 레지스트리 밖 외부 AI(D-21) | 비공개(오케스트레이터) | 해당 단계 잡 실패(환불), 대시보드 경고 |
| `ELEVENLABS_API_KEY` | 상용 STT·TTS | 서버 전용: Next.js(샘플·읽어 주기)와 오케스트레이터(내레이션, D-22). 미디어 워커·FastAPI에는 두지 않음 | ElevenLabs 비활성(체인에서 오픈소스로) |
| `SERPAPI_KEY`, `RAPIDAPI_KEY`, `PROXY_POOL_URL` | 레이더·소싱 | 비공개 | 해당 수집 비활성 |
| `FAL_WEBHOOK_SECRET` | fal 웹훅 | 비공개 | fal 비동기 비활성 |
| `AFFILIATE_IP_SALT_SEED` | 클릭 IP 해시 | 비공개 | 기동 실패 |
| `WORKER_ID`, `MEDIA_QUEUE`(Python) | 워커 식별 | 비공개 | 기동 실패 |

모든 env는 `src/lib/env.ts`(zod)와 Python `settings.py`(pydantic)에서 기동 시 검증한다(SM #20, BS #18). AI 관련 변수는 `docs/products/_platform-core/AI_ARCHITECTURE.md:160`의 목록을 따르며 `NEXT_PUBLIC_HERO3D_ENABLED` 말고는 모두 서버 전용이다. `AI_TOKEN_SECRET`(공유 비밀키)은 쓰지 않는다(EdDSA, `docs/products/_platform-core/SECURITY_BASELINE.md:278`).

## 9. 인증 단계 (2026-10-14 추가, 확정 결정 22)

정본: `docs/products/_platform-core/AUTH_ROADMAP.md`. 세션·조직·엔타이틀먼트 계약(`CORE_SPEC.md` 2장)은 바뀌지 않는다. 세션은 모든 단계에서 실제 Supabase JWT이고, `requireSession('video')`·`proxy.ts`·레이아웃 가드·RLS는 단계와 무관하게 같은 코드다(`AUTH_ROADMAP.md` 0장 불변 조건).

### 9.1 단계표 (이 제품 기준)

| 단계 | 켜지는 로그인 | 진입 게이트 | 이 제품 작업 | 바뀌는 코드 |
|---|---|---|---|---|
| A | 로컬 시드 페르소나 원클릭(`owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops` + 제품 행 `adv_owner`, `adv_member`, 05장 10절). `pending`은 video가 open 앱이라 만들지 않는다 | 없음(W0부터) | VID-06-004 | `src/lib/auth/`, `src/app/(auth)/login`의 개발용 패널, `src/app/api/dev/login`, `scripts/dev/seed-users.mjs` + `scripts/dev/seed-users.video.mjs` |
| B | Google + 이메일(01장 D-28) | G1 | VID-06-063 | 로그인 화면 제공자 버튼·이메일 폼, `src/app/auth/callback`, 온보딩 약관 단계 |
| C1 | 카카오 | G2 | VID-06-064 | 로그인 화면 버튼, `AUTH_PROVIDERS`에 `kakao` |
| C2 | 네이버(`custom:naver` 또는 브리지, 01장 D-27) | G2 | VID-06-065 | 로그인 화면 버튼, (브리지) `src/app/auth/naver/**` |

단계 분기(`AUTH_MODE`, 제공자 목록)를 읽는 곳은 `src/lib/auth/`, `src/app/(auth)/**`, `src/app/auth/**`, `src/app/api/dev/login/**`뿐이다. 기능 코드·워커(오케스트레이터, 미디어 워커)·FastAPI에는 인증 단계 개념이 없다. FastAPI와 음성 서버가 검증하는 EdDSA 서명 토큰(2절)은 사용자 세션에서 Next.js가 발급하므로 Mock 페르소나 세션에서도 같은 경로로 동작한다.

혼동 금지: 채널 연결 OAuth(YouTube·Meta·TikTok, `core.create_oauth_state`/`consume_oauth_state`, 콜백 `/api/channels/callback/[platform]`)와 네이버 클립 업로드용 네이버 로그인 세션(Playwright, `CredentialVault` provider `naver`)은 사용자 로그인과 별개다. 경로·클라이언트·저장소가 다르고 단계 전환의 영향을 받지 않는다. C2의 네이버 "로그인"(사용자 계정)과 네이버 클립 "채널 연결"은 서로 다른 네이버 애플리케이션 등록·동의 항목을 쓴다(제안: 같은 애플리케이션으로 둘 수 있는지는 미확인).

### 9.2 환경변수 (`AUTH_ROADMAP.md` 3.3절 중 이 제품 해당분)

| 이름 | 단계 | 배치 | 없으면 |
|---|---|---|---|
| `AUTH_MODE` | A·B·C | web(Next.js 서버). 오케스트레이터·미디어 워커·`apps/api`에는 두지 않는다 | `live`. 로컬 `.env.example` 기본값은 `mock` |
| `AUTH_PROVIDERS` | B·C | web | 빈 목록이면 live 모드에서 기동 실패. 운영 값: B `google,email`, C1 뒤 `google,email,kakao`, C2 검수 통과 뒤 `naver` 추가(`AUTH_ROADMAP.md` 7.2.4절 C2-6) |
| `DEV_SEED_PASSWORD` | A(로컬 전용) | web 서버, 시드 스크립트. `NEXT_PUBLIC_*` 금지 | Mock 모드 기동 실패 |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`(로그인용) | B | 로컬 `supabase/config.toml`의 `env()`, 원격은 Supabase 대시보드에만. 앱 env에 넣지 않는다 | 로컬 Google 버튼 비활성. 8절 채널 OAuth용 같은 이름 변수와 충돌 주의(01장 D-29) |
| `KAKAO_CLIENT_ID`(REST API 키), `KAKAO_CLIENT_SECRET` | C1 | 위와 같은 방식 | 카카오 버튼 비활성 |
| `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` | C2 | `supabase_custom`이면 등록 스크립트만(앱 env 불필요), `bridge`면 web 서버 전용 | 네이버 버튼 비활성 |
| `NAVER_AUTH_PATH` | C2 | web | `supabase_custom` |
| `AUTH_BRIDGE_SECRET` | C2 브리지만 | web. 32바이트 이상 | 브리지 경로면 기동 실패 |

`src/lib/env.ts`(zod)가 위 조합을 기동 시 검증한다. `AUTH_MODE=mock`인데 `isMockAuthAllowed()`가 거짓(원격 Supabase, `VERCEL_ENV` 또는 `RAILWAY_ENVIRONMENT` 있음)이면 기동 실패하고 조용히 live로 바꾸지 않는다(`AUTH_ROADMAP.md` 2.4절). video의 오케스트레이터는 Railway에서 돌지만 `AUTH_MODE`를 읽지 않으므로 영향이 없다.

### 9.3 외부 콘솔과 배포 토폴로지 메모

| 콘솔 | 단계 | 리디렉션 URI | 메모 |
|---|---|---|---|
| Google Cloud(로그인용 OAuth 클라이언트) | B | `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 앱 도메인이 아니라 Supabase 콜백. 범위는 `openid`, `email`, `profile`만. 채널 연결용 YouTube 클라이언트(리디렉션 `NEXT_PUBLIC_APP_URL/api/channels/callback/youtube`)와 따로 둔다(01장 D-29) |
| 카카오 디벨로퍼스 | C1 | Supabase 콜백(위와 같음, 로컬 `http://localhost:54321/auth/v1/callback`) | 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email`(01장 D-26) |
| 네이버 개발자센터 | C2 | `custom:naver`면 Supabase 콜백, 브리지면 `NEXT_PUBLIC_APP_URL/auth/naver/callback` | 검수 전 "개발중" 상태에서는 등록한 테스트 아이디만 로그인. 네이버 클립 업로드(VD-F-075)는 이 애플리케이션을 쓰지 않는다 |
| Supabase 대시보드 | B·C | Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(Vercel 미리보기 도메인은 명시 등록, 와일드카드 지양) | 제공자 설정과 `AUTH_PROVIDERS` 값을 배포 체크리스트에서 함께 확인(`AUTH_ROADMAP.md` 5.3절 B-6) |

7절 배포 토폴로지에서 바뀌는 구성 요소는 없다. 로그인 콜백은 Vercel 웹(Next.js) 안의 `/auth/callback`이고, Railway 워커와 FastAPI는 로그인 경로에 없다.

### 9.4 로그인 없는 흐름

공개 랜딩(`/landing/[slug]`), 링크인바이오(`/lb/[handle]`), 단축 링크(`/r/[code]`), 결제 복귀(`/billing/success|fail`), 대행 고객의 승인 화면(`/review/[token]`과 결정 API `POST /api/review/[token]`, 토큰 해시 검증, VD-F-123)은 단계와 무관하다. 고객사 담당자는 계정 없이 토큰 링크로만 승인하고(Supabase 세션 없음, service_role 서버 함수가 토큰 해시로 조회), 단계가 바뀌어도 이 흐름은 그대로다. `proxy.ts` 공개 경로 배열(01장 VD-F-002)에 `/login`, `/api/dev/login`(A, 판정이 거짓이면 404), `/auth/callback`(B), 브리지 채택 시 `/auth/naver/**`(C2)를 더할 뿐 이 화면들에 로그인 버튼을 추가하지 않는다.

## 10. 스토리보드 엔진 구조 (2026-10-18 추가, 스토리보드 디벨롭)

정본은 01장 10장(확정 SF-1~SF-4, VD-F-130~142, 단가 10.4절)이다. 이 장은 Track S의 모듈 경계, 잡, 렌더 파이프라인, 성능 예산만 정한다. 렌더 엔진은 FFmpeg 하나다(VD-F-033, `docs/products/sceneflow/01_PRD.md:91`, SF-2). 기존 장의 줄은 바꾸지 않았다. 4절의 `longform.storyline`·`longform.render`·`longform.highlights` 행과 5.2절의 Track D 대본 설명은 Track S로 대체되며, 새 코드는 그 경로에 넣지 않는다(삭제는 01장 D-34). API 계약은 04장 9장, 데이터는 05장 11장, 화면은 03장 8장, 작업은 06장 9장이다.

### 10.1 모듈 경계

서비스 이름은 1~2절 그대로 쓴다. 새 서비스는 없다. 기존 서비스 안에 Track S 디렉토리를 더한다(디렉토리 이름은 제안, 소유 작업은 06장 9장).

| 모듈 | 디렉토리 | 책임 | 다른 모듈과의 계약 |
|---|---|---|---|
| api(Route Handler) | `apps/sceneflow/src/app/api/{storyboards,scenes}/**` | 얇게. `requireSession` → zod → `src/server/storyboards` 호출 | 04장 9장 |
| server domain | `apps/sceneflow/src/server/storyboards/**` | 게이팅(`storyboard`, `storyboard_max_minutes`, `shorts_extract_max`), 렌더 전 검사, 크레딧 선차감, 잡 enqueue, 서버 RPC 호출, 서명 URL | 코어 `consume_credits`·`enqueue_job`, 서버 RPC `video.apply_storyboard_result`·`finish_scene_asset`·`snapshot_storyboard` |
| web-app(편집기) | `apps/sceneflow/src/app/(dashboard)/dashboard/storyboards/**`(화면 `/dashboard/storyboards/...`, 03장 8장), 컴포넌트 `src/components/storyboard/**` | 장면 목록·상세·길이 게이지·출처 경고 수·예상 크레딧 | 읽기는 RLS, 쓰기는 Route Handler만 |
| preview | `src/components/storyboard-preview/**` | 브라우저 타임라인 재생(10.4절). 서버 렌더 없음 | 서명 URL(10분)과 장면 JSON만 받는다 |
| orchestrator | `workers/video-orchestrator/src/flows/storyboard/**`(루트 Flow), 기존 `steps/image`(fal), `steps/tts`(core-voice), `steps/script`(그래프 클라이언트) 재사용 | 루트 잡 `storyboard.render`·`storyboard.shorts`의 FlowProducer 체인, AI 잡(`storyboard.generate`, `scene.image`, `scene.narration`, `storyboard.source_check`) 실행, `outputs` 갱신 | BullMQ 큐 `video.ai`·`video.orchestrate`, 미디어 단계는 `core.jobs` 자식 잡으로 브리지(4절 원칙) |
| media-worker | `services/media-worker/handlers/storyboard/{scene_clip,scene_concat,bgm_mix}`(제안) + 기존 `media.compose`·`media.encode`·`media.stt` 핸들러 | 장면 클립, 연결, 자막 번인, BGM 믹스, 인코딩. FFmpeg만 | `core.claim_jobs(queue='video.media.cpu')`(STT만 `video.media.gpu`) |
| ai-service | `apps/api/app/ai/graphs/video_storyboard.py`, `video_shorts_pick.py`(제안 파일명), 기존 `compliance/video.py` 재사용 | 그래프 `video.storyboard`, `video.shorts_pick`(10.9절). 텍스트만 다룬다 | 잡 토큰 scope `graph:video.storyboard`, `graph:video.shorts_pick` |
| rules | `packages/video-rules/storyboard-layout.json`(제안) | 글자 카드·자막 안전 영역, 글자 크기 비율, 모션 프리셋 수치. TS 미리보기와 Python 워커가 같은 파일을 읽는다 | 원본 소유는 06장 9장 작업 |
| db | `supabase/migrations/1200_video.sql` 새 절 | 05장 11장 테이블·RPC | VID-06-001 소유 규칙 |

경계 규칙(2절 표를 그대로 따르고 Track S에서 더하는 것만):

| 경계 | 규칙 |
|---|---|
| 브라우저 ↔ 서버 | 브라우저는 04장 9장 Route Handler와 RLS 읽기만 쓴다. FastAPI·fal·음성 제공자·media-worker를 직접 부르지 않는다 |
| FastAPI ↔ media-worker | 서로 부르지 않는다(2절 경계 표). 그래프는 장면 JSON만 만들고 이미지·오디오·영상을 다루지 않는다 |
| 키 위치 | fal·ElevenLabs 키는 오케스트레이터에만(8절). media-worker에는 AI 키가 없다. 장면 이미지 생성과 내레이션 TTS는 오케스트레이터가, FFmpeg 단계는 media-worker가 한다 |
| 결과 저장 | 장면 목록은 `apply_storyboard_result`, 소재는 `finish_scene_asset`, 스냅샷은 `snapshot_storyboard`만 쓴다(서버 RPC, service_role). 워커가 테이블에 직접 INSERT하지 않는다 |
| 화면 경로 | 기존 보호 경로 규칙(6절 BS #10 행)에 맞춰 `/dashboard/storyboards`(목록), `/dashboard/storyboards/new`, `/dashboard/storyboards/[id]`(편집기), `/dashboard/storyboards/[id]/render`를 쓴다. API 경로 `/api/storyboards/**`, `/api/scenes/**`는 그대로 |

호출 흐름:

```
브라우저 ─ Route Handler ─ src/server/storyboards ─ consume_credits → enqueue_job
                                                   └ 서버 RPC(snapshot_storyboard 등)
orchestrator(video.ai)       : storyboard.generate → FastAPI video.storyboard → apply_storyboard_result
                               scene.image → fal → finish_scene_asset
                               scene.narration → core-voice → finish_scene_asset
orchestrator(video.orchestrate): storyboard.render(루트) → [ai.tts·storyboard.source_check(video.ai)]
                               → media.scene_clip ×N → media.scene_concat → media.stt → media.compose
                               → media.bgm_mix → media.encode (모두 video.media.cpu, STT만 gpu) → outputs
```

### 10.2 잡과 큐

4절 표와 같은 열이다. 단가는 01장 10.4절.

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `storyboard.generate` | `video.ai` | TS(그래프 클라이언트) → FastAPI `video.storyboard` | 쇼츠 4 / 롱폼 10분당 8(올림) | 1 | 최종 실패 시 전액. 기존 장면은 그대로 둔다 |
| `scene.image` | `video.ai` | TS(fal, 기존 `steps/image`) | 장면당 3. 재사용은 잡 없음, 0 | 3(지수 백오프, 같은 seed) | 최종 실패 시 그 장면분 전액. 이전 `ready` 소재 유지 |
| `scene.narration` | `video.ai` | TS(`core-voice`, 기존 `steps/tts`) | 다시 만들기 1장면 1언어 1. 묶음 생성은 4.1절 내레이션 정액(쇼츠 언어당 ElevenLabs 5 / 오픈소스 2, 롱폼 10분 언어당 5 / 2) | 3(같은 제공자·보이스만, 5.3절) | 구간 하나라도 최종 실패하면 그 요청 전액. 이전 `ready` 내레이션 유지 |
| `storyboard.render`(루트) | `video.orchestrate` | TS(FlowProducer) + Python 자식 | 렌더(쇼츠 언어당 3, 롱폼 10분당 10을 언어판마다, 제안) + 내레이션이 없는 언어의 TTS 정액 + 출처 점검 1 | 0(자식이 재시도) | 10.8절 |
| `storyboard.source_check` | `video.ai` | TS → FastAPI `video.step`(kind `source_check`, 제안) | 루트에 포함(1) | 1 | 실패 시 1 환불 + "출처 점검 안 됨" WARN. 렌더는 계속한다 |
| `storyboard.shorts`(루트) | `video.orchestrate` | TS(그래프 클라이언트 `video.shorts_pick`) + Python 자식 | 선정 단계 2 / 렌더 단계 컷·언어당 3 + 세로 다시 만들기 이미지 3 | 0(자식이 재시도) | 10.8절 |
| `media.scene_clip`(제안) | `video.media.cpu` | Python(FFmpeg) | 루트에 포함 | 2 | 루트 규칙 |
| `media.scene_concat`(제안), `media.bgm_mix`(제안) | `video.media.cpu` | Python(FFmpeg) | 루트에 포함 | 2 | 루트 규칙 |
| `media.compose`, `media.encode`, `media.stt` | 4절 그대로 | Python | 루트에 포함 | 4절 그대로 | 루트 규칙 |

큐는 기존 규칙을 따른다: AI 단계는 `video.ai`에서 잡 토큰(`/api/internal/ai-token`)으로 FastAPI·음성 서버를 부르고, FFmpeg 단계는 media-worker가 `video.media.cpu`에서 소비한다. 명세의 "렌더는 media-worker cpu 큐"는 루트(`video.orchestrate`)가 FFmpeg 단계를 cpu 큐 자식 잡으로 넣는 구조로 읽었다. 루트를 오케스트레이터에 두는 이유는 렌더 중 TTS(ElevenLabs 키)가 필요하고 media-worker에는 그 키가 없기 때문이다.

### 10.3 렌더 파이프라인 (`storyboard.render`)

입력은 스냅샷 하나다(10.5절). 잡 payload의 다른 값으로 장면을 읽지 않는다.

| 단계 | 처리 | 실행 | 실패 처리 |
|---|---|---|---|
| 0 요청 검사·스냅샷 | 서버가 플랜(`storyboard_max_minutes`), 길이 합계 ±10%(`VD017`), 장면 수(`VD018`), clip 권리 근거(`VD019`), 모든 장면 소재 `ready`(`VD001`)를 검사 → 선차감 → `snapshot_storyboard`(status `rendering`, 마스터 컷, 스냅샷 1행) → 루트 enqueue | Next.js 서버 | 검사 실패는 선차감 전 4xx. enqueue 실패는 즉시 환불 |
| 1 내레이션 준비 | 요청 언어 중 장면 내레이션이 다 있는 언어는 그대로 쓴다. 없는 언어는 `ai.tts`로 장면별 구간을 만든다. 제공자·보이스는 그 스토리보드에 처음 기록된 값(5.3절, VD-F-133). 내레이션 문장은 기본 언어 문장을 `ai.translate`로 옮긴다(제안: 번역은 렌더 합계에 포함) | 오케스트레이터 | 그 언어판 실패 + 부분 환불 |
| 2 출처 점검 | `storyboard.source_check`. `source_required=true`인데 출처가 없거나 약한 장면을 WARN 목록으로 남긴다. 렌더를 막지 않는다(D-33 전까지 WARN) | 오케스트레이터 → FastAPI | 1 환불 + "출처 점검 안 됨" WARN |
| 3 장면별 클립 | `media.scene_clip`을 장면마다 만든다(아래 종류 표). 장면 길이는 스냅샷 `duration_ms`. 영상 트랙은 언어 공용이다. 어떤 언어의 내레이션이 장면 길이 - 300ms보다 길면 그 언어판에서만 그 장면 끝 프레임을 늘린다(제안, book-trailer 길이 보정과 같은 300ms, `docs/products/book-trailer/02_ARCHITECTURE.md:125`) | media-worker | 2회 재시도 후 그 장면을 쓰는 모든 언어판 실패 |
| 4 연결 | `media.scene_concat`: 장면 클립을 순서대로 잇는다(컷 전환만, 전환 효과는 Phase 2). 언어별 내레이션 오디오를 장면 시작 시각에 놓는다 | media-worker | 그 언어판 실패 |
| 5 자막 타이밍 | 내레이션 오디오를 `media.stt`(Whisper, `video.stt` = `oss-voice`)로 단어 시각을 얻어 ASS를 만든다. 문장은 STT 결과가 아니라 스냅샷 내레이션 문장을 쓰고 시각만 맞춘다(제안) | media-worker GPU | 실패 시 문장 길이 비례 시각으로 만든다(제안) + 경고 |
| 6 자막 레이어 | `media.compose`. 순서는 VD-F-033 그대로: 원본(= 연결된 장면 영상) → ASS(내레이션 자막) → 강조 자막(`image` 장면의 화면 문구) → 리액션(Track S는 없음) → 배경 템플릿(Track S MVP는 쓰지 않음). `text_card`·`title`의 글자는 3단계 장면 클립 안에 그려지므로 이 단계에서 다시 얹지 않는다. Track S에는 레이어 합성 단가 3을 매기지 않는다(01장 10.4절에 없음) | media-worker | 그 언어판 실패 |
| 7 BGM | `media.bgm_mix`. 곡은 스냅샷의 BGM 1곡(라이선스 근거가 있는 `video.music_library` 곡 또는 없음, 제안). 내레이션 구간에서 덕킹 -12dB, 시작·끝 페이드 2초(제안). `music_cue`는 MVP에서 저장만 하고 곡 전환은 Phase 2(제안) | media-worker | 그 언어판 실패 |
| 8 인코딩 | `media.encode`(preset `longform` 또는 `short`, 30fps). H.264 yuv420p, AAC 48kHz, 통합 음량 -14 LUFS 목표(제안). Starter 워터마크는 워커가 플랜을 읽어 강제(VD-F-034) | media-worker | 그 언어판 실패 |
| 9 컷별 출력 | 언어판마다 `video.outputs` 1행(`storyboard_cut_id`, `kind`는 화면비로 `longform`/`short`, `aspect`). 썸네일은 첫 `title` 장면 또는 첫 장면 프레임(제안) | 오케스트레이터 | - |
| 10 종료 | 하나 이상 ready면 storyboard `rendered`, 전부 실패면 `ready`로 되돌려 편집을 연다. 루트 결과에 `refunded_credits` | 오케스트레이터(service_role) | 10.8절 |

장면 종류별 클립 생성(`media.scene_clip`):

| `kind` | 생성 방법 | 입력 |
|---|---|---|
| `image` | 이미지를 출력 크기의 2배로 키운 뒤 `zoompan`/`crop`으로 모션 프리셋을 적용(제안: 2배 확대로 떨림을 줄인다) | 이미지 소재 경로, `motion_preset`, 길이 |
| `clip` | 앞에서부터 장면 길이만큼 자르고 화면비에 맞춰 크롭·스케일. 원본 소리는 기본 음소거(제안) | 클립 소재 경로, 길이 |
| `text_card` | 단색 배경 + `drawtext`. 글자 크기·안전 영역은 `storyboard-layout.json` | 화면 문구, 길이 |
| `title` | `text_card`와 같고 큰 제목 레이아웃 | 화면 문구(챕터 제목), 길이 |

모션 프리셋 수치(제안, `storyboard-layout.json`에 한 번만 적는다):

| `motion_preset` | FFmpeg 처리 |
|---|---|
| `zoom_in` | 배율 1.00 → 1.12, 중심 고정, 선형 |
| `zoom_out` | 배율 1.12 → 1.00 |
| `pan_left` | 배율 1.10 고정, 오른쪽 끝 → 왼쪽 끝(가로 여유 10%) |
| `pan_right` | `pan_left`의 반대 |
| `static` | 배율 1.00, 움직임 없음 |

서체는 media-worker 이미지에 넣은 OFL 한국어·일본어 서체만 쓴다(제안, 서체 이름은 06장 9장 작업에서 고정). 시스템 서체에 기대지 않는다. 언어판의 `text_card`·`title` 글자는 기본 언어 그대로 나간다(01장 VD-F-136 "언어마다 내레이션·자막만 바꿔 렌더"). 글자 카드 번역은 범위 밖이다(미확인: 01장 10장에 결정 없음).

### 10.4 미리보기 (브라우저 타임라인)

| 항목 | 규칙 |
|---|---|
| 서버 렌더 | 없다. 잡·원장 행을 만들지 않는다. 0크레딧(VD-F-135) |
| 입력 | 장면 JSON(순서, 길이, 문구, 모션)과 `ready` 소재의 서명 URL(10분, 만료 전 다시 받기). 소재가 없는 장면은 회색 칸 + 문구로 보인다 |
| 재생 | `<img>`·`<video>`에 CSS transform으로 모션 프리셋을 근사하고, 내레이션은 `<audio>`를 장면 시작 시각에 맞춰 재생한다. 내레이션이 없으면 길이만큼 무음 |
| 출력과의 관계 | 근사다. 프레임이 FFmpeg 출력과 같다고 보장하지 않는다. 같은 `storyboard-layout.json` 수치를 써서 안전 영역·글자 크기 비율만 맞춘다 |
| 다운로드 | 경로 없음. 화면 녹화는 막지 못하므로 워터마크 규칙은 렌더 산출물에만 건다 |
| 성능 | 미리보기 시작 2초 안 첫 프레임(01장 VD-F-135, 제안). 240장면도 현재 위치 앞뒤 장면 소재만 미리 받는다(제안: 앞 3장면·뒤 5장면) |

### 10.5 스냅샷과 재현성

| 항목 | 규칙 |
|---|---|
| 만드는 곳 | 렌더 요청마다 `video.snapshot_storyboard`가 `video.storyboard_snapshots`에 1행. 쇼츠 컷 렌더도 컷마다 1행 |
| 담는 것(제안) | 스토리보드(id, version, revision, format, aspect, target_seconds, template_code, languages, 고정된 voice), 장면 배열(순서, kind, duration_ms, narration, on_screen_text, motion_preset, music_cue, chapter, sources), 장면별 사용 소재(asset id, storage_path, lang), 컷(kind, aspect, scene_ids, hook_text), BGM(곡 id, 경로, 라이선스 근거), 워터마크 판정, 총 길이. 정확한 키는 04장 9.4절 |
| 렌더 입력 | 워커는 스냅샷의 Storage 경로만 읽는다. 렌더 중 장면을 고칠 수 없다(`VD020`). 렌더가 끝나면 편집이 다시 열리고, 고친 내용은 다음 스냅샷에만 들어간다 |
| 소재 보존 | 스냅샷이 가리키는 `superseded` 소재는 그 스냅샷의 산출물 보존 기간(01장 5장 보존 행)이 끝날 때까지 지우지 않는다(제안) |
| 재현성 | 같은 스냅샷 → 같은 장면 순서·길이·소재·자막 문장. FFmpeg 필터에 난수와 현재 시각을 쓰지 않는다. 바이트 단위 같은 파일은 보장하지 않는다(인코더 스레드 차이). 프레임 해시 비교 테스트는 제안(01장 VD-F-136) |
| 열람 | `GET /api/storyboards/[id]/snapshots/[version]` 읽기 전용(VD-F-139). 이전 스냅샷으로 다시 렌더하는 경로는 MVP에 없다(제안) |
| 멈춘 렌더 | 루트 잡이 `reap_stale_jobs`로 실패 처리되면 10분 크론이 `rendering`인데 루트 잡이 끝난 스토리보드를 `ready`로 되돌린다(제안, 4절 매 10분 행에 더함) |

### 10.6 쇼츠 세로 구도

쇼츠 컷은 마스터 영상을 잘라 내지 않는다. 마스터 컷 스냅샷의 장면으로 9:16 컷을 새로 렌더한다(10.3절과 같은 파이프라인, 크기 1080x1920).

| 장면 종류 | 크롭(D-32 기본 권고 (a)) | 다시 만들기(D-32 (b)) |
|---|---|---|
| `image`(16:9 소재) | 가운데 9:16 영역을 잘라 2배 확대 후 모션 적용. 0크레딧. 원본이 1920x1080이면 세로 영역이 608x1080이라 화질이 떨어지므로 화면에 화질 경고를 띄운다(제안) | 같은 시각 설명으로 1080x1920 이미지를 새로 만든다(이미지 단가 3). 세로 소재는 16:9 소재를 대체하지 않고 따로 보관한다(05장 11장 `scene_assets`에 화면비 구분 칸 필요, 미확인) |
| `clip` | 가운데 크롭 | 해당 없음(크롭만) |
| `text_card`, `title` | 9:16 레이아웃으로 다시 그린다. 0크레딧 | 같음 |

| 항목 | 규칙 |
|---|---|
| 훅 문구 | `video.shorts_pick`이 컷마다 만든다. 첫 2.5초 상단 오버레이로 넣는다(제안). 업로드 제목 초안으로도 쓴다 |
| 자막 위치 | 9:16은 아래 플랫폼 UI를 피해 하단 여백을 화면 높이의 18%로 둔다(제안, `storyboard-layout.json`) |
| 컷 길이 | 60초 이하(01장 VD-F-137, 제안). 연속 장면만(22023) |
| 개수 | 스토리보드당 10편(`VD021`), 플랜 `shorts_extract_max` 이하(403 `VD009`) |
| 마스터 이후 편집 | 쇼츠는 가장 최근 ready 마스터 스냅샷의 장면을 쓴다. 그 뒤에 고친 장면은 쇼츠에 들어가지 않는다는 안내를 화면에 띄운다(제안) |
| 쇼츠 형식 스토리보드 | 형식이 `shorts`면 마스터 컷이 이미 9:16이다. 쇼츠 추출은 `longform`만(22023) |

### 10.7 성능 예산 (제안)

5장 비기능 요구(`docs/products/sceneflow/01_PRD.md:240`, `:244`, `:247`)를 Track S 단계로 나눈 값이다. 모두 제안이며 06장 9장 벤치 작업이 W 단계 끝에 확정한다.

| 항목 | 예산 | 비고 |
|---|---|---|
| 스토리보드 생성(롱폼 10분, 40장면) / 쇼츠 | p95 90초 / 30초 | 그래프 정밀 모드 p95 90초와 같은 수준(01장 5장) |
| 장면 이미지 1장 / 장면 내레이션 1개 | p95 40초 / 20초 | book-trailer 값(`docs/products/book-trailer/01_PRD.md:248`)과 같게 |
| 장면 클립 1개(10초, 1080p) | p95 30초(CPU 1코어) | `media.scene_clip` 타임아웃 300초 |
| 롱폼 10분 1언어 렌더(루트 시작 → 마스터 ready, 큐 대기 제외) | p95 30분. 언어판 1개 추가마다 +15분 | FFmpeg 단계 타임아웃은 롱폼 3,600초(01장 5장) |
| 쇼츠 1컷 1언어 렌더 | p95 5분 | 쇼츠 5편 요청 → 5편 ready p90 30분(01장 10.1절) |
| 큐 대기 | p95 5분 | 01장 5장 워커 큐 지연. 넘으면 media-worker CPU 인스턴스 추가(7절 2~4) |
| 렌더 1건의 동시 장면 클립 잡 | 최대 8 | 렌더 하나가 cpu 큐를 다 차지하지 않게 |
| 조직 동시 렌더 | 01장 5장 동시 생산 상한(Starter 1, Basic 3, Pro 5, Advanced 10)에 포함 | 초과 429 |
| 편집기 첫 표시(240장면) | p95 2초 | 장면 JSON 한 번 + 소재 서명 URL은 보이는 범위만 |
| 중간 산출물(장면 클립, 언어별 중간 파일) | 7일 보존 후 삭제 | 01장 5장 보존 행 |

### 10.8 실패와 부분 환불 (VD-F-035 규칙)

원칙은 VD-F-035(`docs/products/sceneflow/01_PRD.md:93`) 그대로다: 루트 잡 1개 + 단계 자식 잡, 언어판 실패는 그 언어분만 부분 환불, 루트 상태 `partial`. 결과가 전달되지 않은 실패는 전액 환불(01장 4.1절 실패 환불 행).

| 실패 위치 | 처리 | 환불 |
|---|---|---|
| `storyboard.generate` | 장면을 바꾸지 않는다(`apply_storyboard_result`는 성공 때만) | 전액(잡 자동 환불) |
| `scene.image` | 이전 `ready` 소재 유지. 새 소재 행 없음 | 그 장면분 3 |
| `scene.narration` | 구간 하나라도 실패하면 그 요청 실패. 다른 제공자로 대체하지 않는다(5.3절) | 그 요청 전액 |
| 렌더 출처 점검 | WARN "출처 점검 안 됨" + 렌더 계속 | 1 |
| 렌더 언어판(TTS·번역·연결·자막·BGM·인코딩) | 그 언어판 `outputs.status=failed`, 다른 언어는 계속. 루트 `partial` | 그 언어분(그 언어 TTS 정액 + 그 언어 렌더 단가). 멱등 키 `refund:<cut_id>:<lang>`(제안) |
| 렌더 장면 클립(언어 공용) | 그 장면을 쓰는 모든 언어판 실패 → 루트 실패 | 전액(출처 점검 1 포함, 결과가 전달되지 않았으므로) |
| 쇼츠 선정(`video.shorts_pick`) | 컷을 만들지 않는다 | 2 |
| 쇼츠 컷·언어 | 그 컷·언어 실패, 다른 컷 계속. 세로 다시 만들기 이미지가 실패하면 그 컷을 조용히 크롭으로 바꾸지 않고 실패로 둔다 | 그 컷·언어 인코딩 3 + 그 컷의 세로 이미지 단가. 키 `refund:<cut_id>:<lang>`(제안) |
| 루트 잡 reaper 실패 | 10.5절 멈춘 렌더 행 | 코어 자동 환불(잔액 전액) |

### 10.9 그래프 (`video.storyboard`, `video.shorts_pick`)

5.2절 표와 같은 열이다. 입출력 계약은 04장 9.5절.

| 그래프 | 노드 순서 | LLM 기능 | 사람 승인 | compliance | 실행 |
|---|---|---|---|---|---|
| `video.storyboard` | `beats` → `scenes` → `claims` → `validate` → `compliance` → (걸린 장면만 `scenes` 1회 재작성 → `validate` → `compliance`) | `video.script`(제안: 새 기능 키를 만들지 않아 5.1절 seed 17행이 바뀌지 않는다) | 그래프 안에는 없다. 사용자는 결과를 편집기에서 고친다 | 있음(마지막 노드, 6장 금지 문구 + 01장 10.5절) | 오케스트레이터가 잡 토큰(scope `graph:video.storyboard`)으로. 체크포인트 thread = `ai_runs.thread_id` |
| `video.shorts_pick` | `pick` → `hook` → `compliance` | `video.script`(제안) | 없음. 사용자가 제안 컷을 고른다 | 있음(훅 문구) | 오케스트레이터, scope `graph:video.shorts_pick` |

| 노드 | 동작 | LLM |
|---|---|---|
| `beats` | 템플릿 비트 비중(01장 10.3절)으로 목표 길이를 비트별 길이로 나눈다 | 없음(결정적) |
| `scenes` | 대본 문단을 비트에 맞춰 장면으로 나눈다. kind, duration_ms, narration, on_screen_text, visual_prompt, motion_preset, music_cue, chapter, shorts_candidate | 있음 |
| `claims` | 연도·인물·수치·사건 단정 장면에 `source_required=true`. 출처는 대본 그래프의 근거 id(RAG 청크·검색 결과)가 있을 때만 제목·URL을 채우고, 없으면 비운다. URL을 지어내지 않는다 | 있음 |
| `validate` | 장면 수(쇼츠 3~12, 롱폼 분당 3~8, 240 이하), 글자 수, enum 검사. 길이 합계가 ±10% 밖이면 비율로 다시 나눠 100ms 단위로 맞춘다(제안). 숫자는 서버 계산값만 저장한다 | 없음 |
| `compliance` | 기존 규칙 파일 + 01장 10.5절 금지 문구. 2회 걸리면 run `failed` | 없음(규칙) |
| `pick` | `shorts_candidate` 장면에서 연속 묶음(60초 이하, 서로 겹치지 않음)을 최대 요청 수만큼 고른다. 후보가 없으면 전체 장면에서 고른다 | 있음 |
| `hook` | 컷마다 훅 문구 40자 이하(제안) | 있음 |

출처 점검(`storyboard.source_check`)은 별도 그래프를 두지 않고 `video.step`(D-20)의 새 kind `source_check`(제안, 기능 키 `video.analyze`)로 실행한다.

### 10.10 Phase 2 Remotion 경계 (D-30)

MVP에는 Remotion·Chrome·Node 렌더러를 넣지 않는다(SF-2). Phase 2에서 검토할 때 바꿀 수 있는 곳을 미리 한 군데로 좁혀 둔다.

| 항목 | 규칙 |
|---|---|
| 교체 지점 | 3단계 `media.scene_clip` 하나다. 계약은 "스냅샷의 장면 1개 → 정확히 `duration_ms` 길이의 무음 영상 클립"이다. Remotion을 들여도 4~9단계(연결, 자막, BGM, 인코딩, 출력)는 FFmpeg로 남긴다 |
| 대상 | `text_card`·`title`의 모션 그래픽(글자 등장, 숫자 카운트 등)부터. `image` 장면은 FFmpeg 모션으로 충분한지 먼저 본다 |
| 렌더러 공용화 | book-trailer 렌더러(`services/trailer-renderer`, `docs/products/book-trailer/02_ARCHITECTURE.md:41`)를 장면 클립 생성기로 같이 쓰는 안. 큐·스냅샷 형식이 달라 어댑터가 필요하다 |
| 미리보기 | 그때 `text_card`·`title`만 Remotion Player로 바꿀 수 있다. 다른 장면은 10.4절 그대로 |
| 확인할 것 | Remotion 라이선스 조건(book-trailer D-2, `docs/products/book-trailer/01_PRD.md:351`)과 서버 렌더 원가. 01장 D-30 기준 미확인 |
| 지금 하지 않는 것 | `remotion`·`@remotion/*` 패키지 설치, media-worker 이미지에 Chrome 추가, 장면 JSON에 Remotion 전용 필드 추가 |

### 10.11 book-trailer 렌더러와의 차이

| 항목 | SceneFlow Track S(MVP) | book-trailer |
|---|---|---|
| 렌더 엔진 | FFmpeg 6(VD-F-033) | Remotion 4.0.x + Chrome Headless Shell + 내장 FFmpeg(`docs/products/book-trailer/02_ARCHITECTURE.md:11`, `:16`) |
| 렌더 서비스 | 기존 `services/media-worker`(Python 3.11), 큐 `video.media.cpu` | `services/trailer-renderer`(Node 20), 큐 `trailer.render` |
| 오케스트레이션 | BullMQ FlowProducer 루트(`video.orchestrate`) + `core.jobs` 자식 잡 여러 개 | `core.jobs`만, 렌더 1잡이 끝까지 처리(`:101`, `:119-129`) |
| 크레딧 선차감 | Route Handler에서 `consume_credits` → `enqueue_job`(04장 1절) | 서버 RPC `trailer.start_render`가 한 트랜잭션으로 |
| 입력 | `storyboard_snapshots.snapshot` | `renders.snapshot`(`docs/products/book-trailer/04_API.md:156`) |
| 장면 표현 | 장면 클립을 하나씩 만들어 잇는다. 종류 4개 | React 컴포지션 1개 안의 장면 컴포넌트. 종류 7개 |
| 모션 | `zoompan`·`crop` 프리셋 5개 | 프리셋 8개(parallax, type_reveal 등) |
| 글자·자막 | `drawtext` + ASS(libass) 번인. 레이어 순서 고정 | 브라우저 조판, 영상 토큰, 자막 큐 + SRT 부산물 |
| 미리보기 | 브라우저 타임라인 근사. 출력과 프레임이 같지 않다 | Remotion Player, 렌더와 같은 코드(`:39`, `:42`) |
| 길이·규모 | 최대 60분, 240장면 | 짧은 트레일러, 장면 39개 이하 |
| 화면비 | 롱폼 16:9 마스터 + 9:16 쇼츠 컷을 따로 렌더 | 9:16 이미지 기준, 포맷별 크롭·패닝(`:200`) |
| 결정성 | 같은 스냅샷 → 같은 순서·길이·소재(바이트 동일은 아님). 프레임 해시는 제안 | 같은 스냅샷 → 같은 프레임, 프레임 해시 테스트(`:131`) |
| 언어판 | 언어마다 내레이션·자막만 바꿔 같은 장면 영상에 얹는다 | 트레일러 1개 = 언어 1개 |
| 라이선스 | 새 의존성 없음(기존 media-worker 이미지) | Remotion Company License 조건(D-2) |
| 성능 예산 | 롱폼 10분 1언어 p95 30분(제안, 10.7절) | 60초 1080p p95 6분(`docs/products/book-trailer/01_PRD.md:249`) |

## 11. AI 자동편집 엔진과 화면비·해상도 렌더 (2026-10-18 추가, 01장 11장)

정본은 01장 11장(SF-5~SF-8, VD-F-143~159, 명령 허용 목록 11.4절, 단가 11.5절)이고 테이블·RPC는 05장 12장, `1200_video.sql` 13절(`docs/products/_supabase-modular/migrations/1200_video.sql:3038-4195`)이다. 기존 장의 줄은 바꾸지 않았다. 10장 렌더 파이프라인 위에서 달라지는 점만 적는다.

### 11.1 모듈 경계 (10.1절 표에 더함)

| 모듈 | 디렉토리(제안) | 책임 | 계약 |
|---|---|---|---|
| server domain(편집) | `apps/sceneflow/src/server/storyboards/edit/**` | 편집안 생성 요청(선차감 → 그래프), EDL 서버 검사(11.3절), `edit_plans` INSERT(service_role, `base_fingerprint`), 적용 뒤 `regenerate` 명령 선차감·enqueue, 되돌리기·거절 중계 | 04장 10장, RPC `apply_edit_plan`·`undo_edit_plan`·`reject_edit_plan` |
| ai-service(편집 그래프) | `apps/api/app/ai/graphs/video_edit_plan.py`, `apps/api/app/ai/products/video/edl_schema.py` | 그래프 `video.edit_plan`: 지시 + 스토리보드 요약 → 명령 배열 JSON + 사람이 읽는 요약. 자동 다듬기(`mode=auto_polish`)는 규칙 단계 + LLM 1회 | 잡 토큰 scope `graph:video.edit_plan`. 텍스트만 다룬다 |
| media-worker(분석) | `services/media-worker/handlers/storyboard/{silence_detect,retake_detect,upscale}` | 클립 STT(Whisper 단어 시각, `video.stt` = `oss-voice`) + `silencedetect` → 잘라낼 구간 후보, 리테이크 묶음 후보(P1), 1440p 이상 렌더용 이미지 업스케일(D-39) | `video.media.gpu`(STT·업스케일), `video.media.cpu`(silencedetect). 결과는 서버 RPC 없이 잡 result로 돌려주고, 전사는 오케스트레이터가 `clip_transcripts`에 service_role로 쓴다 |
| rules | `packages/video-rules/edit/{fillers.ko.json,safe_zones.json,caption_styles.json,hanja_glossary.json}` | 한국어 군더더기 말 사전(강도별), 플랫폼 세이프존 비율, 자막 스타일 3종 수치, 한자 병기 용어집(운영자 검수 항목만) | TS 편집기·Python 워커·FastAPI가 같은 파일을 읽는다(10.1절 `storyboard-layout.json`과 같은 방식) |
| web-app(AI 편집 패널) | `src/components/storyboard/ai-edit/**` | 지시 입력(텍스트·마이크), 편집안 검토 시트, 편집 기록·되돌리기 | 03장 9장 |

경계 규칙(10.1절에 더함):

| 경계 | 규칙 |
|---|---|
| LLM과 파일 | LLM은 명령 JSON만 만든다(SF-6). 영상·이미지 바이너리를 받지 않고, FFmpeg 인자·셸 문자열을 만들지 않는다. 워커는 스냅샷 JSON만 읽고 LLM 출력을 직접 받지 않는다 |
| 적용 경로 | 장면 변경은 `apply_edit_plan` 하나로만 한다(사용자 세션 RPC, 한 트랜잭션). 서버가 명령을 하나씩 `save_scene`으로 쪼개 부르지 않는다(부분 적용·되돌리기 불일치 방지) |
| 비용 있는 명령 | `regenerate`는 RPC가 실행하지 않고 돌려준다. Route Handler가 01장 11.5절 단가로 선차감 → `scene.image`·`scene.narration` 잡. 승인 화면 합계와 실제 차감이 다르면 차감하지 않고 409(제안) |
| 클립 오디오 | 업로드 클립 STT는 미디어 워커 Whisper만(국외 전송 없음, 01장 6장). 전사 단어는 FastAPI에 보낼 때 장면 id·단어·시각만 보내고 오디오는 보내지 않는다 |

### 11.2 편집안 흐름

```
브라우저(AI 편집 패널) ─ POST /api/storyboards/[id]/edit-plans {text|mode, request_id}
  → src/server/storyboards/edit: 게이팅(ai_edit) → consume(1 또는 자동 다듬기 단가)
  → storyboard_fingerprint(service) → 스토리보드 요약 JSON(장면 id·순서·길이·문구 앞 80자·종류·챕터·쇼츠 후보·렌더 설정)
  → FastAPI POST /graphs/video.edit_plan/runs (Next.js 서명 토큰, 동기 p95 15초, 넘으면 잡 edit.plan으로 전환)
  → 서버 EDL 검사(11.3절) → edit_plans INSERT(status proposed, base_fingerprint, estimate_credits) → 응답
브라우저(검토 시트) ─ 명령 고르기 → POST /api/edit-plans/[id]/apply {command_ids[], request_id}
  → 사용자 세션 rpc('video.apply_edit_plan') → {applied, pending_regenerate}
  → pending_regenerate 가 있으면 consume → enqueue scene.image / scene.narration(문장 범위)
브라우저 ─ POST /api/edit-plans/[id]/undo → rpc('video.undo_edit_plan')
```

자동 다듬기(VD-F-147)는 같은 경로에 `mode=auto_polish`를 준다. 무음·군더더기 말 컷(VD-F-148)은 먼저 분석 잡(`clip.analyze`)이 구간 후보를 만들고, 서버가 그 결과로 `remove_ranges` 명령만 담은 편집안을 직접 만든다(LLM 없음, `source=silence_cut`).

### 11.3 EDL 서버 검사 (그래프 출력 → `edit_plans`)

DB CHECK(`video.valid_edit_commands`, 허용 `op`·키·명령 수 100)는 마지막 방어선이고, 서버가 먼저 아래를 검사한다. 하나라도 걸리면 편집안을 저장하지 않고 `VD023`(그래프 1회 재작성 후에도 실패하면 환불).

| 검사 | 규칙 |
|---|---|
| 스키마 | 01장 11.4절 표의 인자 타입·범위(zod, `packages/video-rules/edit/edl.schema.json` 하나를 TS·Python이 같이 쓴다) |
| 대상 | `scene_id`가 요청 시점 스토리보드 장면인지. 같은 장면에 같은 `op`가 두 번이면 뒤의 것만 남기고 요약에 표시 |
| 형식 | 쇼츠 형식에서 `propose_short`·`set_shorts_candidate` 금지, `set_clip_trim`·`remove_ranges`는 `clip` 장면만 |
| 플랜 | `set_render` 값이 플랜 상한 안(`render_max_resolution`, `render_max_fps`, `render_4k60`), 변형본 수, 쇼츠 컷 한도 |
| 길이 | 적용 후 예상 길이 합계를 계산해 ±10% 밖이면 요약에 경고(차단 아님, 렌더 때 `VD017`) |
| 문구 | `set_text`·`add_scene`의 문구 값은 compliance(01장 6장, 10.5절, 11.7절) 통과. 출처 없는 연도·수치를 새로 넣는 문구는 `source_required=true` 표시 |
| 비용 | `regenerate` 명령마다 01장 11.5절 단가로 `estimate_credits` 합계 |

결정성: 그래프는 온도 0, 출력 스키마 고정, 스토리보드 요약을 정렬된 키로 직렬화한다(같은 입력 = 같은 출력 목표, 제공자 비결정성은 미확인이라 보장 문구를 쓰지 않는다). 입력 해시(`instruction` + `base_fingerprint`)가 같은 `proposed` 편집안이 10분 안에 있으면 새로 만들지 않고 그 편집안을 돌려준다(제안, 크레딧 0).

### 11.4 잡과 큐 (10.2절 표와 같은 열)

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `edit.plan`(동기 응답이 15초를 넘을 때만) | `video.ai` | TS → FastAPI `video.edit_plan` | 지시 1, 자동 다듬기 쇼츠 1 / 롱폼 10분당 2 | 1 | 최종 실패·명령 0개·`VD023` 시 전액 |
| `clip.analyze` | `video.orchestrate`(루트) → `video.media.gpu`(STT) + `video.media.cpu`(silencedetect) | Python | 클립 1분당 STT 3 + 무음 컷 2(올림) | 2 | 최종 실패 시 전액. 전사가 이미 있으면(`clip_transcripts`) STT분 0 |
| `clip.retake`(P1) | `video.ai` | TS → FastAPI `video.step` kind `retake_group` | 클립 10분당 1 | 1 | 실패 시 전액 |
| `scene.narration`(문장 범위) | `video.ai` | 10.2절 그대로 + `sentence_index` | 1 | 3(같은 제공자·보이스) | 그 문장분 |
| `scene.upscale` | `video.media.gpu` | Python(업스케일 모델, 상업 이용 라이선스 확인 전에는 fal 업스케일 API, D-39·미확인) | 1장 1 | 2 | 그 장면분. 실패 장면은 원본 해상도로 렌더하지 않고 렌더 요청을 막는다(조용한 품질 저하 금지) |
| `storyboard.render`(variant 컷) | `video.orchestrate` | 10.2절과 같다. 스냅샷 cut kind `variant` | 그 길이의 렌더 단가 × 해상도·fps 배수 | 0(자식) | 10.8절 |
| `storyboard.meta`(P1, 챕터·제목·설명) | `video.ai` | FastAPI `video.step` kind `chapters_meta` | 1 | 1 | 전액 |
| `storyboard.thumbnail`(P1) | `video.ai` → `video.media.cpu` | 문구 LLM + FFmpeg 합성 | 3안 2 | 1 | 전액 |
| `storyboard.nle_export`(P1) | `video.media.cpu` | Python(FCPXML, Premiere XML, SRT, zip) | 0 | 2 | - |

### 11.5 렌더 파이프라인 변경 (10.3절 단계에 더함)

| 단계 | 변경 |
|---|---|
| 0 요청 검사 | 플랜 상한(`render_max_resolution`, `render_max_fps`, `render_4k60`, VD009). 1440p 이상이면 AI 이미지 장면마다 업스케일 소재 존재 확인, 없으면 `scene.upscale`을 먼저 돌린다(크레딧 합계를 렌더 전에 표시, 03장 9장) |
| 3 장면별 클립 | 출력 크기는 스냅샷 `render.width × render.height`, fps는 `render.fps`(`video.render_dimensions`, 짧은 변 기준). `crop_from`이 있으면 원본 이미지를 컷 화면비로 크롭: 크롭 창 중심 = (`focus.x`, `focus.y`), 창이 이미지 밖으로 나가면 안쪽으로 밀어 넣는다. 그다음 모션 프리셋. `clip` 장면은 `clip.in_ms ~ out_ms`를 자른 뒤 `cut_ranges`를 뺀 구간들을 잇는다(구간 경계에 오디오 10ms 페이드, 제안). 비파괴: 원본 파일은 그대로 |
| 4 연결 | 전환 효과를 쓴다(10.3절 "Phase 2" 대체). 장면 `transition`이 `cut`이 아니면 앞 장면과 `xfade=transition=<name>:duration=<ms>`로 겹친다. 겹친 시간만큼 전체 길이가 줄지 않도록 앞 장면 끝을 `transition_ms`만큼 늘린 클립을 쓴다(제안: 장면 길이 합계 = 출력 길이 유지). 내레이션은 장면 시작 시각 기준 그대로 |
| 5~6 자막 | 스타일은 스냅샷 `style.caption_style`(`packages/video-rules/edit/caption_styles.json`). `word_pop`은 단어 시각으로 말하는 단어만 강조색. `caption_emphasis` 단어는 굵게 + 강조색(3종 공통). `caption_hanja=true`면 용어집에 있는 용어 뒤에 작은 글씨 괄호 한자. 자막 위치는 컷 화면비의 세이프존(11.6절) 안 |
| 7 BGM·음량 | 덕킹을 고정 -12dB 대신 `sidechaincompress`(내레이션을 사이드체인)로 하고 기본 음량은 `style.bgm_level_db`. `loudnorm=true`면 2패스 `loudnorm` -14 LUFS(제안, 10.3절 8단계 목표값과 같음) |
| 8 인코딩 | fps는 스냅샷 값. 2160p는 H.264 High 5.1 또는 HEVC 중 플랫폼 업로드 호환을 확인한 쪽(미확인, VID-06 렌더 벤치 작업에서 결정). 출력 `outputs.width/height/fps` 기록 |
| 9 컷별 출력 | variant 컷은 `outputs.kind`를 형식으로 정한다(롱폼 = `longform`, 쇼츠 = `short`). `aspect`는 컷 화면비 |

### 11.6 세이프존 (제안, `safe_zones.json` 정본)

플랫폼 UI가 덮는 영역의 비율이다. 플랫폼별 공식 수치는 확인하지 못했다(미확인). 편집기 겹쳐 보기와 자막 기본 위치에만 쓰고 업로드를 막지 않는다.

| 화면비 | 위 | 아래 | 오른쪽 | 왼쪽 | 근거 |
|---|---|---|---|---|---|
| 9:16(쇼츠·릴스·틱톡 공통 보수값) | 12% | 22% | 14% | 5% | 제안(미확인). 세 플랫폼 중 가장 넓은 값을 쓴다 |
| 4:5 | 6% | 12% | 6% | 6% | 제안 |
| 1:1 | 5% | 10% | 5% | 5% | 제안 |
| 16:9 | 5% | 10% | 5% | 5% | 제안(플레이어 컨트롤) |

### 11.7 성능 예산 (제안, 10.7절에 더함)

| 항목 | 예산 | 비고 |
|---|---|---|
| 편집안 생성(지시 1회) | p95 15초(넘으면 잡 전환) | 롱폼 240장면 요약 기준 |
| 자동 다듬기 | p95 30초 | |
| 편집안 적용 RPC | p95 500ms(명령 100개, 240장면) | 한 트랜잭션 |
| 되돌리기 RPC | p95 1초 | |
| 클립 분석(10분 클립) | p95 5분 | STT GPU 1 |
| 렌더 해상도 배수 | 1080p30 = 1. 1440p, 2160p, 60fps의 처리 시간 배수는 렌더 벤치로 측정(01장 D-41) | 4K60은 1080p30 대비 픽셀·프레임 약 8배(산술) |
| 장면 클립 1개(10초) | 1080p p95 30초 / 2160p p95 120초(제안) | 타임아웃 2160p 900초 |

### 11.8 실패와 환불 (10.8절에 더함)

| 실패 위치 | 처리 | 환불 |
|---|---|---|
| 편집안 생성 | 그래프 실패, 명령 0개, `VD023`(재작성 1회 후) | 전액 |
| 편집안 적용 | 한 트랜잭션이라 부분 적용 없음. `VD409`면 화면이 "다시 제안받기"를 띄운다 | 편집안 생성 크레딧은 환불하지 않는다(결과가 전달됐으므로, 제안) |
| `regenerate` 잡 | 10.8절 `scene.image`·`scene.narration` 규칙 | 그 장면분 |
| 업스케일 실패 | 렌더 요청 전 단계에서 멈추고 실패 장면 표시 | 그 장면분 1 |
| 변형본 렌더 | 10.8절 렌더 언어판 규칙 | 그 언어분 |

### 11.9 Phase 2 경계

피사체 추적 리프레임, 업로드 클립 장면 감지, 립싱크 더빙, 비트 싱크, 멀티캠(01장 11.3절)은 MVP 코드에 자리(인터페이스·플래그)를 만들지 않는다. 초점은 장면당 한 점(`focus_x/y`)만 둔다. 추적이 들어오면 장면별 초점 시계열을 새 컬럼으로 더한다(그때 05장 개정).
