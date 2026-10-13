# 02 아키텍처: NOMAD AI Factory (nomad-video)

2026-10-13 개정: AI 계층(FastAPI `apps/api`, LangGraph, RAG, 제품 지식 위키, 공용 Dify), 음성(`packages/core-voice`, 공용 오픈소스 음성 서버), 3D 히어로를 추가했다. 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, `docs/products/_design-guide/HERO_3D.md`이고 이 문서는 인용하며 video 고유 경계·그래프·라우팅 기본값만 정한다. 기존 Python 미디어 워커(Whisper, demucs, FFmpeg)와 새 FastAPI AI 서비스의 경계는 2절 끝 표.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router + React | 16.2.x / 19.2 (SM 기준, lockfile 고정) | `docs/reviews/NOMAD_Shorts_Maker.md:16` |
| UI | Tailwind CSS v4(CSS 우선 설정 `@import "tailwindcss"`, `@theme`, `@custom-variant dark`, 4.x 고정, `latest` 금지) + shadcn/ui(Tailwind v4 지원 버전, 구현 시 확인), lucide, recharts. `tailwind.config.js`와 v3 문법(`@tailwind base` 등) 금지 | SM 기준 | `docs/reviews/NOMAD_Shorts_Maker.md:16`, `docs/products/_design-guide/DESIGN_SYSTEM.md:63-73` |
| 3D | three.js + React Three Fiber + drei. 캔버스는 동적 import(`ssr: false`), 히어로 전용 컴포넌트에서만 import | React 19 호환 버전(구현 시 확인) | 확정 결정 15, `docs/products/_design-guide/HERO_3D.md:43-55` |
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
| web-public | `apps/nomad-video/src/app/(marketing)`, `landing/[slug]`, `lb/[handle]`, `r/[code]`, `legal` | 마케팅, 공개 랜딩, 링크인바이오, 단축 링크 | 공개 RPC `get_public_landing`, `get_public_linkinbio`, 코어 `record_affiliate_click` |
| web-app | `apps/nomad-video/src/app/(dashboard)/dashboard/**` | 대시보드 화면 | `src/server/*` 서버 함수, Realtime(`core.jobs`) |
| api | `apps/nomad-video/src/app/api/**` | Route Handler(얇게) | `requireSession` → `src/server/<domain>` 호출 |
| server domain | `apps/nomad-video/src/server/{billing,channels,sources,productions,longform,music,playlists,publish,affiliate,radar,analytics}` | 게이팅, 크레딧 선차감, 잡 enqueue, 영속화 | 코어 패키지(`core-db`, `core-billing`, `core-jobs`, `core-affiliate`, `core-ai`) |
| orchestrator | `workers/video-orchestrator/src/{flows,steps,radar,analytics,cron,bridge}` | FlowProducer 체인, AI 단계, 업로드, 레이더 수집, 스케줄 | BullMQ 큐 `video.*`(TS), 미디어 단계는 `core.jobs` 자식 잡으로 브리지 |
| media-worker | `services/media-worker/{core,handlers}` | Whisper, demucs, 다운로드, FFmpeg 전 처리 | `core.claim_jobs(queue='video.media.gpu'|'video.media.cpu')`만 소비 |
| sns-uploader | `packages/sns-uploader/src/{youtube,meta,tiktok}` | 공용 업로더 구현(video 소유, commerce·blog 소비) | 인터페이스는 SHARED_MODULES 11장 그대로 |
| db | `supabase/migrations/1200_video.sql`, `supabase/monolith/**` | 스키마 | 이 폴더 05장 |
| ai-service | `apps/api/`: 공용 ai-service(`app/core`, `app/ai/llm`, `rag`, `wiki`, `tools` 공용 부분)를 그대로 쓰고 video 확장만 둔다: `app/ai/graphs/video_script.py`·`video_step.py`, `app/ai/tools/video/`(채널 코치 답변 모드, 컬렉션 로더), `app/ai/compliance/video.py`, `app/ai/products/video/`(운영자 지식 조직 id, 컬렉션 이름, 프롬프트 로더) | Supabase(service_role), 상용 LLM API, 공용 GPU 서버(`oss-llm`, `oss-embed`), Dify 내부 키 호출 수신 |
| ai-gate | `apps/nomad-video/src/app/api/{ai,internal,onboarding}/**`, `src/app/onboarding/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` | 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, EdDSA 서명 토큰·잡 토큰 발급, 정산 크론, 온보딩 국외 이전 동의 | `packages/ai-gateway` |
| voice | `apps/nomad-video/src/app/api/voice/**`, `src/components/voice/**` | STT, TTS, 음성 세션, 음성 처리 고지, 샘플 듣기 | `packages/core-voice` |
| ai-ui | `apps/nomad-video/src/components/{ai-chat,script-plan,wiki}/**`, `src/app/(dashboard)/dashboard/{chat,wiki}/**` | 채팅 패널, 대본 기획 미리보기, 위키 화면 | `components/ui` |
| hero3d | `apps/nomad-video/src/components/hero3d/**`, `public/hero/**` | 소싱 → 가공 → 배포 영상 타일 파이프라인, 모바일 1줄 흐름, 정지 이미지 | three.js, R3F, drei, 토큰 |
| design-system | `apps/nomad-video/src/styles/tokens.css`, `src/components/ui/**`, `src/app/dev/components/**` | 토큰(Tailwind CSS v4 `@theme`), 기본 컴포넌트, 라이트/다크 미리보기(프로덕션 빌드 제외) | `DESIGN_SYSTEM.md` |

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
| auth | 가입(`signup_app='video'`), 세션, `requireSession` | `proxy.ts`, 레이아웃, 모든 Route Handler | 기본 역할 admin 금지 |
| org | 1인 1워크스페이스, Advanced 멤버 초대 | `src/server/team` 대신 코어 RPC 직접 | `team_members` 상한은 서버 판정 |
| credits | 생성·업로드·검사 선차감, 실패 환불, 부분 환불 | `src/server/*` | 멱등 키 `consume:video:<request_id>` |
| toss | 구독, 크레딧팩, 빌링키 | `src/server/billing`, orchestrator cron | `confirm_payment_order` PM001 시 별도 호출로 `fail_payment_order`(service_role)를 불러 주문을 failed로 남기고 운영 알림 + Toss 취소를 수행 |
| webhooks | Toss, fal, (Phase 2) Distrokid, Make/n8n | `src/app/api/webhooks/*` | 서명 없으면 거부 |
| oauth | YouTube/Meta/TikTok 채널 연결, 쿠팡 키 저장 | `src/server/channels`, `src/server/affiliate` | state는 `create_oauth_state`만 |
| llm gateway | 사용하지 않는다(2026-10-13). 번역 후처리, 대본, 스토리라인, 블링, GEO 메타, 플리 메타, compliance의 LLM 호출은 라우터(ai-service)로 옮겼다 | - | 라우터 본체가 ai-service로 옮겨졌다(`docs/products/_platform-core/SHARED_MODULES.md:42`). 모델 허용 목록(YSM #6)은 `core.ai_model_prices` 등록 모델과 라우팅 체인으로 대체. 그래프 `video.script`와 `video.step`(D-20)이 호출 경로 |
| ai-gateway | 대화 매핑, 서명 토큰·잡 토큰 발급, 턴 선차감·정산, Dify 중계와 장애 시 직접 경로 | `src/app/api/ai/`, `src/app/api/internal/`, `src/server/ai/` | `docs/products/_platform-core/SHARED_MODULES.md:498` |
| ai-service | 라우터, RAG(트렌드·성과·대본·가이드), 위키, 그래프 `video.script`·`video.step`, 도구 `/tools/answer` | `apps/api` | 제품 확장은 2절 `ai-service` 행 |
| dify | 채팅 앱 `video-chat`(질문 분류, HTTP 노드, 외부 지식) | Next.js `src/app/api/ai/chat` | Dify DB는 조직 데이터 저장소로 관리(로그 30일) |
| core-voice | STT(대화형), TTS(샘플·읽어 주기·내레이션). 내레이션은 `feature='narration'`에서 대체를 끈다 | `src/app/api/voice/`, 오케스트레이터 `steps/tts/`(D-22) | `docs/products/_platform-core/SHARED_MODULES.md:501` |
| llm-wiki | 채널·브랜드 가이드 위키(제품 지식 위키), 운영자 가이드(`video-guide`) | `apps/api`(ingest, lint), `src/components/wiki/`, `dashboard/wiki/` | 조직 위키는 조직 간 공유 없음. 운영자 지식은 외부 지식 API로만 노출 |
| fal client | Track C/D 이미지, 썸네일, 플리 무드 썸네일, 곡 커버 | orchestrator steps | 결과를 `video-media`로 복사 |
| sns uploader | 업로드, 고정 댓글, 쿼터, 통계 | orchestrator `upload.*` | video가 구현 소유 |
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
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #11 | `src/lib/queue/bullmq.ts:86` 외 | tsc 21개 오류로 빌드 실패, ioredis 중복, 키 대소문자 불일치 | 원본 코드 복사 대신 이식 시 타입 재작성. 언어 키는 `'KO'|'JA'|'EN'` 상수 하나. ioredis 루트 의존 제거. CI에서 `tsc --noEmit` 실패 시 머지 불가 | VID-06-039 |
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
| `GOOGLE_CLIENT_ID/SECRET`, `META_APP_ID/SECRET`, `TIKTOK_CLIENT_KEY/SECRET` | 채널 OAuth | 비공개 | 해당 플랫폼 연결 비활성 + 경고 |
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
