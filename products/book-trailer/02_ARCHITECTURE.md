# 02 아키텍처: NOMAD Book Trailer (book-trailer)

작성일 2026-10-15. AI 계층(FastAPI `apps/api`, LangGraph, RAG, 위키, 공용 Dify), 음성(`packages/core-voice`), 3D 히어로의 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`, `docs/products/_design-guide/HERO_3D.md`이고, 이 문서는 인용하며 book-trailer 고유 경계·잡·그래프·렌더 파이프라인만 정한다.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router + React | 16.2.x / 19.2(lockfile 고정, `latest` 금지) | 저장소 공통(`README.md` 5.2절), 확정 결정 3 |
| UI | Tailwind CSS v4(CSS 우선 설정 `@import "tailwindcss"`, `@theme`, `@custom-variant dark`, 4.x 고정) + shadcn/ui(Tailwind CSS v4 지원 버전), lucide. `tailwind.config.js`와 v3 문법 금지 | 4.x | `docs/products/_design-guide/DESIGN_SYSTEM.md:63-73` |
| 영상 컴포지션 | Remotion(React 컴포지션). 앱 미리보기는 `@remotion/player`, 서버 렌더는 `@remotion/renderer` + `@remotion/bundler` | 4.0.x 정확한 버전 고정(2026-10-15 npm 최신 4.0.529 확인). 라이선스 D-2 | `01_PRD.md` D-2 |
| 3D | three.js + React Three Fiber + drei. 히어로 전용 컴포넌트에서만 import, 동적 import(`ssr: false`) | React 19 호환(구현 시 확인) | 확정 결정 15 |
| 폼/검증/데이터 | React Hook Form + zod, TanStack Query v5 | 구현 시 확인 | 다른 제품과 같음 |
| DB/인증/Storage | Supabase(Postgres 15, RLS, Auth, Storage, Realtime), `@supabase/ssr` | - | `docs/products/_platform-core/CORE_SPEC.md` 1장 |
| 오케스트레이터 | Node 20 + TS 독립 패키지 `workers/trailer-orchestrator`. 큐는 `core.jobs`(`claim_jobs`, SKIP LOCKED)만, BullMQ·Redis 없음 | Node 20 | nomad-docs와 같은 단순 구조(작업 수가 적고 단계가 짧다). 확정 결정 6은 nomad-video 범위(`01_PRD.md` 2장) |
| 렌더러 | Node 20 + Remotion 렌더러 + Chrome Headless Shell + FFmpeg(Remotion 내장) + sharp(표지 팔레트·이미지 정규화). Docker 이미지에 OFL 한국어 서체 8종 포함 | Node 20 | D-2 |
| AI 서비스 | FastAPI(Python) `apps/api`. 공용 ai-service 위에 trailer 확장만. 원고 파싱(텍스트 추출)도 여기서 한다. 영상·오디오·이미지 바이너리는 다루지 않는다(2절 경계 표) | Python 3.12(제안) | 확정 결정 3, 13 |
| AI 오케스트레이션 | LangChain, LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`) | 구현 시 확인 | `docs/products/_platform-core/AI_ARCHITECTURE.md` 4장 |
| 원고 파서 | pdf: pypdf 계열 텍스트 추출, epub: ebooklib, docx: python-docx, md/txt: 그대로. 스캔 PDF OCR은 Phase 2 | 구현 시 확인(라이선스 확인) | flora 파서 선택 교훈(`docs/products/nomad-docs/07_SOURCE_MIGRATION.md` 1.2절) |
| LLM | FastAPI 라우터: 상용 `anthropic`, `openai`, `google` + 오픈소스 `oss-llm`(vLLM). 기능별 체인은 5.1절 | `core.ai_model_prices` 등록 모델 | 확정 결정 17 |
| RAG | pgvector(HNSW, cosine, 1024차원), 임베딩 `oss-embed` 고정 | pgvector 0.8 이상 | `AI_ARCHITECTURE.md` 5장 |
| 채팅 운영 | 공용 자체 호스팅 Dify, 제품 앱 `trailer-chat`(Chatflow) | 설치 버전 문서로 확인 | 확정 결정 14 |
| 음성 | `packages/core-voice`: ElevenLabs TS SDK + 공용 오픈소스 음성 서버 | 구현 시 확인 | 확정 결정 16 |
| 이미지 | fal(Flux 계열), `enable_safety_checker=true`. 코어 제공자 레지스트리 밖이라 라우팅 대상 아님(nomad-video와 같다) | 모델 id는 서버 상수 | `docs/products/nomad-video/02_ARCHITECTURE.md:22` |
| 결제 | Toss Payments(코어) | - | 확정 결정 4 |
| 호스팅 | Vercel(web), Railway(orchestrator 1, renderer 2, `apps/api` 1), 공용 Dify·GPU 서버(운영사) | - | 7절 |

## 2. 모듈 경계

모노레포(제안, `docs/products/_platform-core/SHARED_MODULES.md` 0장 패키지 배치). 06장 소유 경계의 기준이다.

| 모듈 | 디렉토리 | 책임 | 계약 |
|---|---|---|---|
| web-public | `apps/web/src/app/(marketing)/**`, `src/app/b/[code]/**`, `src/app/review/[token]/**`(P1), `src/app/legal/**` | 랜딩, 구매 링크 리다이렉트, 외부 승인 화면 | service RPC `record_link_click`, `decide_review` |
| web-app | `apps/web/src/app/(app)/**` | 홈, 책, 트레일러 편집, 렌더, 설정 | `src/server/*`, Realtime(`core.jobs`, `trailer.generation_runs`, `trailer.renders`) |
| api | `apps/web/src/app/api/**` | Route Handler(얇게) | `requireSession('trailer')` → `src/server/<domain>` |
| server domain | `apps/web/src/server/{billing,books,uploads,brand-kits,trailers,scenes,runs,renders,links,meta,music,reviews,ops,account}` | 게이팅, 크레딧 계산(`pricing.ts`), service RPC 호출, 서명 URL | 코어 패키지(`core-db`, `core-billing`, `core-jobs`, `core-ai`) |
| auth | `apps/web/src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/`, `src/app/api/dev/login/` | 로그인 단계 분기(A/B/C)는 여기서만 | `AUTH_ROADMAP.md` 3.1절 |
| preview | `apps/web/src/components/preview/**` | Remotion Player 미리보기(프록시 에셋, 워터마크 오버레이, 다운로드 없음) | `packages/trailer-compositions` |
| orchestrator | `workers/trailer-orchestrator/src/{index,core,steps,cron}` | 잡 클레임(`trailer.ai`), 그래프 호출(잡 토큰), 이미지(fal)·TTS(core-voice) 생성, 결과 업로드, `finish_run`/`fail_run` | `core.claim_jobs`, `trailer.*` service RPC |
| renderer | `services/trailer-renderer/src/{index,handlers/{render,kit,asset},fonts}` | 잡 클레임(`trailer.render`, `trailer.media`), 스냅샷 → 컴포지션 props → 렌더 → 포스터·SRT → `exports` 업로드 → `finish_render`. 표지 팔레트 추출, 사용자 이미지 정규화 | `core.claim_jobs`, `trailer.finish_render`/`fail_render` |
| compositions | `packages/trailer-compositions/src/{compositions,scenes,tokens,motion,captions}` | 템플릿 6종 컴포지션, 장면 종류별 컴포넌트, 영상 토큰(08_DESIGN_SYSTEM.md 5~9장), 모션 프리셋, 자막 배치 | 입력 = 렌더 스냅샷(04장 4.4절). 앱 미리보기와 서버 렌더가 같은 코드 |
| rules | `packages/trailer-rules/{banned.json,claims.json,price_law.json,spoiler.json}` | compliance 규칙(TS·Python 공용 JSON) | 원본 소유 TR-06-023 |
| ai-service | `apps/api/` | 공용 ai-service + trailer 확장: `app/ai/graphs/trailer_{digest,brief,storyboard,meta}.py`, `app/ai/compliance/trailer.py`, `app/ai/products/trailer/{parsers,quotes,knowledge,wiki_config}.py`, `app/ai/tools/trailer/` | Supabase(service_role), LLM, 공용 GPU 서버 |
| ai-gate | `apps/web/src/app/api/{ai,internal,onboarding}/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` | 대화 생성, 채팅 중계, 턴 선차감·정산, 서명 토큰·잡 토큰, 국외 이전 동의 | `packages/ai-gateway` |
| voice | `apps/web/src/app/api/voice/**`, `src/components/voice/**` | STT, TTS 읽어 주기, 내레이션 샘플 | `packages/core-voice` |
| ai-ui | `apps/web/src/components/{ai-chat,wiki}/**` | 코치 채팅, 책 설정 위키 | `components/ui` |
| hero3d | `apps/web/src/components/hero3d/**`, `public/hero/**` | 랜딩 3D 장면, 3D 영상 단계, 정지 이미지 | three.js, 토큰 |
| design-system | `apps/web/src/styles/tokens.css`, `src/components/ui/**`, `src/app/dev/components/**` | 앱 토큰(Tailwind CSS v4 `@theme`), 기본 컴포넌트, 미리보기(프로덕션 빌드 제외) | 08_DESIGN_SYSTEM.md |
| db | `supabase/**` | 마이그레이션, seed, RLS 스모크 | 05장 |

AI 모듈 경계(`AI_ARCHITECTURE.md` 1~3장 인용, 재정의하지 않음):

| 경계 | 규칙 |
|---|---|
| 브라우저 ↔ 서버 | 브라우저는 `/api/ai/*`, `/api/voice/*`만. Dify·FastAPI·제공자 직접 호출 금지 |
| Next.js ↔ FastAPI·음성 서버 | EdDSA 서명 토큰(`iss=trailer`, `aud=platform-ai:trailer`, scope는 04장 2.1절). 개인키는 Next.js만 |
| 오케스트레이터 ↔ FastAPI·음성 서버 | 오케스트레이터는 개인키가 없다. `/api/internal/ai-token`에서 running 잡에 묶인 토큰(scope `graph:trailer.*`, `voice`, `parse`)을 받는다(`AI_ARCHITECTURE.md` 1장 잡 토큰 규칙. `parse` scope는 2026-10-16 R-T4로 추가) |
| Dify ↔ FastAPI | `platform_conversation_id` + 내부 키 + 대화 매핑만 |
| 3D | `src/components/hero3d/`만 three.js를 import |

### 렌더러와 FastAPI AI 서비스의 경계

| 항목 | 렌더러(`services/trailer-renderer`) | FastAPI AI 서비스(`apps/api`) |
|---|---|---|
| 책임 | 영상 렌더, 포스터, SRT, 표지 팔레트 추출, 이미지 정규화 | 원고 파싱, LLM 그래프, RAG, 위키, 인용 원고 대조, compliance 규칙 |
| 입력 | `core.claim_jobs('trailer.render' \| 'trailer.media')`와 Storage 경로 | 서명 토큰(잡 토큰 포함) 또는 Dify 내부 키 |
| 비밀 | service_role만. LLM·ElevenLabs·fal 키, 서명 개인키 없음 | service_role, LLM·임베딩 키. ElevenLabs·fal 키와 서명 개인키 없음 |
| 다루는 데이터 | 이미지·오디오·영상 바이너리 | 텍스트·임베딩(원고 파일은 텍스트 추출만) |
| 상대 호출 | 하지 않는다 | 하지 않는다 |

이미지(fal)와 TTS(ElevenLabs·오픈소스)는 오케스트레이터가 호출한다. 오케스트레이터는 fal 키와 ElevenLabs 키를 가진 서버 전용 프로세스다(nomad-video 오케스트레이터와 같은 배치, `docs/products/nomad-video/CLAUDE.md` 2장 LLM·음성 키 행). LLM 키는 FastAPI에만 둔다.

## 3. 공용 모듈 사용

재정의하지 않는다(`SHARED_MODULES.md` 19장).

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 가입(`signup_app='trailer'`), 세션, `requireSession`, 로그인 단계 | `proxy.ts`, 레이아웃, Route Handler | 단계 분기는 `src/lib/auth/`만(9절) |
| org | 1인 1워크스페이스, publisher 팀 5인 | 코어 RPC | `members_max`는 서버 판정 |
| credits | 선차감(`start_run`·`start_render` 안), 실패 환불(`fail_job`) | DB 함수, `src/server/runs`, `src/server/renders` | 단가는 `pricing.ts` |
| toss | 구독, 크레딧팩 | `src/server/billing` | `confirm_payment_order` PM001 시 `fail_payment_order` + 운영 알림 + Toss 취소 |
| webhooks | Toss, fal(비동기 결과, 선택) | `src/app/api/webhooks/*` | 서명 없으면 거부 |
| oauth | YouTube 채널 연결(P1) | `src/server/channels` | 로그인 Google 클라이언트와 분리(D-17) |
| storage | 원고·표지·음악(org-files), 렌더(exports), 제품 버킷 3개 | 전역 | 서명 URL 10분(제안) |
| audit | 권리 확인, 승인 링크, compliance WARN 확인, FLORA 가져오기 | 제품 RPC, 서버 | |
| jobs | 상태 정본, 클레임, 자동 환불, Realtime | 전역 | 큐 `trailer.ai`, `trailer.render`, `trailer.media` |
| compliance | 공용 금지어 사전 + 제품 규칙(`packages/trailer-rules`) | 그래프 마지막 노드, 렌더 직전 서버 | |
| sns uploader | YouTube 업로드(P1, 소비자) | 오케스트레이터 `steps/upload` | 구현 소유는 nomad-video(`SHARED_MODULES.md` 11장) |
| ai-gateway | 대화 매핑, 서명·잡 토큰, 턴 선차감·정산 | `src/app/api/ai/`, `src/server/ai/` | |
| ai-service | 라우터, RAG, 위키, 그래프 4종, `/tools/answer` | `apps/api` | |
| dify | 채팅 앱 `trailer-chat` | `src/app/api/ai/chat` | Dify 로그 30일 |
| core-voice | STT, TTS(읽어 주기·샘플·내레이션). 내레이션은 `feature='narration'`에서 대체 끔 | `src/app/api/voice/`, 오케스트레이터 `steps/tts` | |
| llm-wiki | 책 설정 위키 | `apps/api`(ingest, lint), `src/components/wiki/` | 조직 간 공유 없음 |
| affiliate | 쓰지 않는다 | - | 05장 6절. 범용화는 R-T3 |
| render-weasyprint | 쓰지 않는다 | - | PDF 산출물이 없다 |

## 4. 잡과 워커

원칙: 사용자 요청 1건 = `generation_runs` 또는 `renders` 1행 + `core.jobs` 1행(크레딧 원장 연결). 서버 RPC가 검사·선차감·enqueue를 한 트랜잭션으로 한다(`2600_trailer.sql` 7-2·7-5절). 워커는 결과를 Storage에 올린 뒤 `finish_run`/`finish_render`로 결과 저장 + 종료 + 환불 표시 해제를 한 트랜잭션으로 한다. 실패는 `core.fail_job`(재시도 또는 최종 실패 시 자동 환불) 다음 `trailer.fail_run`/`fail_render`.

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `book.parse` | `trailer.ai` | TS → FastAPI `/products/trailer/parse` | 0 | 2 | 해당 없음. 실패 시 책에 오류 표시 |
| `trailer.digest` | `trailer.ai` | TS → 그래프 `trailer.digest` | 20 + 10만 자당 8 | 2(같은 실행 id로 그래프 재개) | 최종 실패 시 전액 |
| `trailer.brief` | `trailer.ai` | TS → 그래프 `trailer.brief` | 8 | 2 | 최종 실패 시 전액 |
| `trailer.storyboard` | `trailer.ai` | TS → 그래프 `trailer.storyboard` | 6 | 2 | 최종 실패 시 전액 |
| `trailer.scene_image` | `trailer.ai` | TS(fal) | 3 | 3(지수 백오프, 같은 seed) | 최종 실패 시 전액 |
| `trailer.narration` | `trailer.ai` | TS(core-voice) | EL 2 / 오픈소스 1 | 3(같은 제공자·보이스만) | 최종 실패 시 전액. 다른 목소리 결과는 저장 거부(5.3절) |
| `trailer.meta` | `trailer.ai` | TS → 그래프 `trailer.meta` | 2 | 2 | 최종 실패 시 전액 |
| `render.trailer` | `trailer.render` | Node 렌더러 | 4/6/8 + 1080p 2, 표지 루프 2, 480p 1 | 2(같은 스냅샷) | 최종 실패 시 전액 |
| `kit.extract` | `trailer.media` | Node 렌더러(sharp) | 0 | 1 | 해당 없음 |
| `asset.normalize` | `trailer.media` | Node 렌더러(sharp: 리사이즈, EXIF 제거, webp) | 0 | 1 | 해당 없음 |
| `ai.settle` | `trailer.ai` | TS → Next.js `/api/internal/ai-settle` | 0 | 3 | 해당 없음 |
| `upload.youtube`(P1) | `trailer.upload` | TS(sns-uploader) | 1/건 | 3 | 최종 실패. 쿼터 초과는 `run_after` 재예약 |
| `purge.book` | `trailer.ai` | TS | 0 | 3 | 해당 없음 |

렌더 파이프라인(`render.trailer`):

| 단계 | 처리 | 실패 처리 |
|---|---|---|
| 1 클레임 | `claim_jobs('trailer.render', worker_id, 1)`. 인스턴스당 동시 2(제안) | - |
| 2 스냅샷 읽기 | `renders.snapshot`(service_role). 에셋 서명 URL 대신 Storage에서 임시 폴더로 내려받는다(렌더 중 URL 만료 방지) | 에셋 없음 → 최종 실패(재시도 없음) |
| 3 길이 보정 | 내레이션 오디오 길이 + 300ms가 장면 길이보다 길면 그 장면을 늘린다. 총 길이가 플랜 한도 110%를 넘으면 실패(서버가 렌더 전에 경고하므로 드물다) | 최종 실패 + 환불 |
| 4 props | 스냅샷 → 컴포지션 props(포맷, 해상도, 팔레트, 서체, 장면 배열, 자막 큐, 워터마크·AI 표시 플래그). 플래그는 스냅샷 값만 쓰고 잡 payload를 보지 않는다 | - |
| 5 렌더 | `selectComposition` → `renderMedia`(H.264, AAC, yuv420p, CRF 18 제안, 30fps). 서체는 이미지에 포함된 OFL 파일만, 로딩 완료 전 프레임 금지(`delayRender`) | 타임아웃: 길이 x 10(최소 5분, 제안). 초과 시 재시도 |
| 6 부산물 | 포스터(제목 장면 중간 프레임 PNG), SRT(자막 큐), 메타데이터 txt | - |
| 7 업로드·종료 | `exports/<org>/trailer/renders/<render_id>/` → `finish_render` | 업로드 실패 재시도 |

결정성: 같은 스냅샷은 같은 프레임을 만든다(난수는 seed에서만, 현재 시각을 쓰지 않는다). 렌더러 테스트가 프레임 해시를 비교한다(TR-06-047).

스케줄(오케스트레이터 크론, service_role. 공개 크론 라우트 없음):

| 주기 | 작업 |
|---|---|
| 매 10분 | `core.reap_stale_jobs(600)`, 활성 조직의 `trailer.reconcile_runs` |
| 매 5분 | AI 정산(`ai.settle`, `settled_at is null` 10분 경과 행) |
| 매 시간 | `core.expire_stale_payment_orders()`, 만료된 승인 링크 expired 처리(P1) |
| 매일 00:10 KST | `core.run_monthly_credit_grants()` |
| 매일 03:00 KST | 보존 만료 렌더 파일 삭제(`renders_expiry_idx`), 만료 7일 전 알림, 삭제 30일 지난 책 `purge.book` |
| 주 1회 | 책 설정 위키 lint(운영사 부담 한도 안) |

## 5. AI 라우팅

설계 정본은 `AI_ARCHITECTURE.md` 4장(LLM 라우터), `VOICE_ARCHITECTURE.md` 3장(음성)이다. 5.1절 표는 `2600_trailer.sql` 13절과 `supabase/monolith/seed.sql`의 `ai_routing_settings`(org null, app `trailer`) 16행과 같다(DO 블록이 16행과 체인을 검사).

### 5.1 기능별 라우팅 기본값

| feature | kind | 모드 | 대체 체인 | 강제 오픈소스 | 쓰는 곳 | 이유 |
|---|---|---|---|---|---|---|
| `trailer.digest` | llm | auto | oss-llm → anthropic | 아니오 | 그래프 `trailer.digest` | 원고 전체 장 단위 처리(대량). 미출간 원고라 오픈소스 먼저 |
| `trailer.brief` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `trailer.brief` | 훅·로그라인 카피 품질이 제품 핵심. 입력은 분석 결과(원고 전문 아님) |
| `trailer.storyboard` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `trailer.storyboard` | 장르 문법에 맞춘 장면 구성 |
| `trailer.prompt_en` | llm | auto | oss-llm → anthropic | 아니오 | 스토리보드 `visual_prompt` 노드, 장면 재생성 | 번역·정리 |
| `trailer.meta` | llm | auto | anthropic → openai → oss-llm | 아니오 | 그래프 `trailer.meta` | 플랫폼별 카피 |
| `trailer.compliance` | llm | auto | oss-llm → anthropic | 아니오 | 각 그래프 `compliance` 노드의 LLM 보조 판정 | 규칙이 1차 방어 |
| `chat` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | `/tools/answer`(코치) | 한국어 품질 |
| `wiki.ingest`, `wiki.query`, `wiki.lint` | llm | auto | oss-llm → anthropic | 아니오 | 책 설정 위키 | 대량 |
| `dify.aux` | llm | open_source | oss-llm | 예 | Dify 질문 분류 노드 | 조직을 알 수 없어 동의 확인 불가 |
| `trailer.knowledge` | embedding | open_source | oss-embed | 아니오(대체 없음) | 책 원고 컬렉션 `trailer-book-<book_id>` | 컬렉션 모델 고정 + 미출간 원고 |
| `voice_chat` | stt | auto | oss-voice → elevenlabs | 아니오 | 음성 질문 | `VOICE_ARCHITECTURE.md` 기본 |
| `dictation` | stt | auto | oss-voice → elevenlabs | 아니오 | 내레이션 문구 받아쓰기 | 같음 |
| `voice_chat` | tts | auto | elevenlabs → oss-voice | 아니오 | 답변 읽어 주기 | 품질 |
| `narration` | tts | auto | elevenlabs → oss-voice | 아니오 | 내레이션, 샘플 | 사용자가 `voice_pref`로 고른다. 작업 도중 대체 금지(5.3절) |

| 규칙 | 내용 |
|---|---|
| 국외 이전 동의 | 미동의 조직은 `resolve_ai_route`가 상용 제공자를 뺀다. 분석은 oss-llm, 내레이션은 oss-voice만 남는다 |
| 원고 전문 | 상용 제공자로 원고 전문을 보내는 경로는 `trailer.digest`의 대체(oss 장애 + 동의 조직)뿐이다. 브리프·스토리보드·메타·채팅은 분석 결과와 RAG 발췌만 보낸다 |
| 조직 재정의 | 제품 화면에서 `set_ai_routing`을 쓰지 않는다. 사용자가 고르는 것은 국외 이전 동의와 내레이션 엔진뿐이다 |
| 모델 지정 | 요청 본문의 모델 지정은 받지 않는다(422) |

### 5.2 LangGraph 그래프

| 그래프 | 노드 순서 | LLM 기능 | 사람 승인 | compliance |
|---|---|---|---|---|
| `trailer.digest` | `load`(Storage 정규화 md) → `split_chapters`(결정적: 제목 패턴·분량) → `summarize_chapter`(장마다 병렬 4) → `extract_entities`(인물·장소·용어·주제) → `index`(RAG 청크, 임베딩) → `wiki_seed`(위키 초안) → `output` | `trailer.digest`, `wiki.ingest` | 없음 | 해당 없음(사용자에게 보이는 카피가 아니다) |
| `trailer.brief` | `load_digest` → `spoiler_window`(결정적: 스포일러 수준별 인용 가능 구간 계산, 결말 15% 제외 등) → `angles`(3각도) → `hooks`(로그라인·훅) → `quotes`(RAG로 후보 문단 → 문장 선택) → `verify_quotes`(결정적: 원고와 글자 단위 대조, 위치 기록) → `compliance` → (걸린 부분만 `hooks` 1회 재작성 → `compliance`) | `trailer.brief` | 사용자가 3안 중 고른다(그래프 밖 UI, interrupt 없음) | 있음 |
| `trailer.storyboard` | `load`(현재 브리프, 문법 비트, 위키, 목표 길이) → `beats_to_scenes`(비트 비중으로 장면 수·길이 배분, 결정적) → `write_scenes`(문구·내레이션·장면 종류) → `visual_prompt`(영어 이미지 프롬프트 + 모션 프리셋, `trailer.prompt_en`) → `fit_duration`(결정적: 합계 ±10% 보정, 글자 수 대비 최소 노출 시간) → `verify_quotes` → `compliance` → `output` | `trailer.storyboard`, `trailer.prompt_en` | 없음(편집기에서 사람이 고친다) | 있음 |
| `trailer.meta` | `load`(브리프, 장면, 구매 링크) → `per_platform`(제목·설명·해시태그) → `links`(단축 링크 + 태그 삽입, 결정적) → `compliance` → `output` | `trailer.meta` | 없음 | 있음. 대가성 문구는 그래프가 쓰지도 지우지도 않는다(DB 트리거만) |

compliance 노드(마지막, `AI_ARCHITECTURE.md` 6장 "compliance 뒤에는 비생성 노드만"): `packages/trailer-rules` 규칙 사전 + 근거 없는 실적·순위·수상, 보장, 가상 후기, 의료·투자 단정, 도서정가제 할인 표현, 실존 인물 이름(이미지 프롬프트), 스포일러 구간 인용 검사. 걸린 부분만 그 노드가 1회 재작성, 2회 실패면 run failed(환불). WARN은 결과에 표시하고 렌더 전에 사용자 확인을 받는다.

### 5.3 같은 목소리 규칙 (내레이션)

정본은 `VOICE_ARCHITECTURE.md` 3장 같은 목소리 규칙이다.

| 항목 | 규칙 |
|---|---|
| 고정 시점 | 트레일러의 첫 내레이션 실행이 `resolve_ai_route(narration, tts)`와 `voice_pref`를 합쳐 제공자·보이스 하나를 정하고, 성공하면 `finish_run`이 `trailers.voice`에 기록한다. 이후 장면은 이 값만 쓴다 |
| 대체 금지 | 실패는 같은 제공자로만 재시도(지수 백오프 3회). 다른 목소리 결과는 DB가 거부(22023) |
| 바꾸기 | 사용자가 목소리를 바꾸려면 "전체 다시 녹음"(모든 장면 내레이션 재생성, 장면 수 x 단가)만. 서버가 `voice`를 비우고 모든 audio 에셋을 superseded로 바꾼 뒤 시작(service) |
| 샘플 | 같은 제공자·보이스로만 |

### 5.4 이미지 스타일 고정

| 항목 | 규칙 |
|---|---|
| 프롬프트 조립 | 장면 `visual.prompt`(영어) + 문법 스타일 프리셋(08_DESIGN_SYSTEM.md 6장) + 팔레트 설명(브랜드 키트 hex → 색 이름) + 금지 접미어(no text, no watermark, no real person likeness) |
| seed | 트레일러마다 하나(트레일러 id에서 결정적으로 만든 정수). 장면 재생성은 seed + 재생성 횟수 |
| 인물 | 기본은 실루엣·뒷모습·손·소품. 위키의 인물 묘사(머리색·옷)를 프롬프트에 넣어 장면 간 일관성을 맞춘다. 얼굴 일관성(캐릭터 시트)은 Phase 2(TR-F-131) |
| 비율 | 포맷별로 따로 생성하지 않는다. 9:16 기준 1080x1920으로 만들고 컴포지션이 포맷별 크롭·패닝(`visual.focus`)으로 맞춘다(크레딧 절약) |
| 안전 | fal 안전 검사 켬. 실존 인물 이름·브랜드 로고 요청은 compliance가 먼저 막는다 |

## 6. 리뷰 "높음" 결함의 차단 설계

이식 원천 "높음" 18건 중 비보안 8건. 보안·데이터 10건은 05장 7절. 합계 18 = 차단 설계 18.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #3 | `docs/reviews/NOMAD_Shorts_Maker.md:80` | checkout과 웹훅의 orderId 형식 불일치 | orderId 파싱 없이 코어 `payment_orders` 선저장 → confirm 단일 경로 | TR-06-013, 014 |
| 같은 리뷰 #8 | `:85` | 세션 없는 컨텍스트(웹훅·워커)에서 쿠키 anon 클라이언트 사용 → 쓰기 0 | 워커·웹훅은 service_role 클라이언트만(`src/server/**`, 워커 패키지). 쿠키 클라이언트는 화면·Route Handler만. 서버 RPC는 service 전용이라 anon 클라이언트로 부르면 42501이 나서 조용히 실패하지 않는다 | TR-06-003, 005, 006 |
| 같은 리뷰 #9 | `:86` | 단계 의존 없이 동시 enqueue, placeholder, 즉시 done | 단계는 사용자 행동(분석 → 브리프 → 스토리보드 → 에셋 → 렌더)마다 별도 실행이고 선행 조건을 DB가 검사(`TR004`). 실행 상태는 워커의 `finish_run`/`fail_run`으로만 바뀌고 전이 트리거가 queued → succeeded 직행을 거부(`TR001`) | 05장 3절, TR-06-024 |
| 같은 리뷰 #10 | `:87` | TS 워커가 `next/headers`에 의존, Python과 같은 큐를 다른 계약으로 소비 | 오케스트레이터·렌더러는 독립 패키지(`npm run start`), Next.js 의존 없음. 큐마다 소비자 하나(`trailer.ai` 오케스트레이터, `trailer.render`·`trailer.media` 렌더러). 페이로드 계약 04장 4절, zod·pydantic 양쪽 검증 | TR-06-005, 006 |
| 같은 리뷰 #11 | `:88` | `tsc` 오류로 빌드 실패, 의존성 중복 | CI에서 `tsc --noEmit`·lint·build 실패 시 머지 불가. 원본 코드를 복사하지 않고 새로 작성 | TR-06-049 |
| 같은 리뷰 #12 | `:89` | Next 16 `params` Promise 미대응, 없는 RPC 호출 | `params`는 await, 공개 페이지(`/b/[code]`)는 쿠키 없는 서버 처리 + 존재하는 service RPC(`record_link_click`, 스모크로 확인) | TR-06-020 |
| `docs/reviews/Toon-Factory.md` 3장 #5 | `docs/reviews/Toon-Factory.md:49` | LoRA 화풍 통일은 학습·GPU·검수 기준 없이 일정 위험 | 화풍 학습을 하지 않는다. 스타일 고정은 프롬프트 프리셋 + 팔레트 + 고정 seed(5.4절)와 템플릿(모션·타이포·색 보정)으로 하고, 일관성 검수 기준표(08_DESIGN_SYSTEM.md 8.3절)로 사람이 판정. 캐릭터 얼굴 일관성은 Phase 2 | 5.4절, TR-06-027 |
| 같은 리뷰 #6 | `:50` | 구매 에셋을 AI로 변형해 재배포하는 라이선스 위험 | 스톡 에셋을 변형·재배포하지 않는다. 음악은 상업 이용 라이선스 검증 곡만 공개(DB CHECK), 서체는 OFL만, 템플릿 그래픽은 자체 제작 코드(Remotion 컴포넌트). 운영자 카탈로그 화면에 라이선스 근거 입력 필수 | 05장 2.3절, TR-06-029, 045 |

## 7. 배포 토폴로지

| 구성 | 위치 | 네트워크 경계 |
|---|---|---|
| web(Next.js) | Vercel | 공개. Supabase(anon/세션), 서버 함수만 service_role |
| orchestrator | Railway 1(CPU 1~2 vCPU) | 외부: fal, ElevenLabs, 공용 음성 서버, FastAPI, Supabase(service_role), Next.js `/api/internal/*`(내부 키) |
| renderer | Railway 2(각 4 vCPU·8GB, 제안) Docker: Node 20 + Chrome Headless Shell + 서체 | 외부: Supabase(service_role, Storage)만 |
| apps/api | Railway 1(CPU) | 공용 GPU 서버(`oss-llm`, `oss-embed`), 상용 LLM, Supabase(service_role), Dify에서 내부 키 호출 수신 |
| Dify, GPU 음성·LLM 서버 | 운영사 자체 호스팅(공용) | `docs/develop/_shared/{dify,voice,llm}/` |
| Supabase | 모듈러 프로젝트 1개(출시) | 모놀리스는 고객 전용 설치형(05장 8절) |

렌더러 확장: 큐 대기 p95가 5분을 넘으면 인스턴스 추가(제안). Remotion Lambda(AWS)는 쓰지 않는다(Railway 단일 클라우드 유지, 비용 예측). 렌더 결과는 Storage `exports`로만 나가고 렌더러는 공개 포트가 없다.

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 브라우저 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버·워커 | 서버 전용 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `trailer`(모듈러) / `public`(모놀리스) | 서버 | 기동 실패 |
| `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET`, `NEXT_PUBLIC_TOSS_CLIENT_KEY` | 결제 | 클라이언트 키만 공개 | 기동 실패 |
| `AI_TOKEN_PRIVATE_KEY` | EdDSA 서명 토큰(Next.js만) | 서버 전용 | 기동 실패 |
| `AI_TOKEN_JWKS_URL` | FastAPI·음성 서버 검증 | 서버 | 기동 실패 |
| `INTERNAL_API_KEY` | 오케스트레이터 → `/api/internal/*` | 서버 전용 | 기동 실패 |
| `FASTAPI_URL`, `DIFY_API_URL`, `DIFY_APP_KEY_TRAILER`, `DIFY_INTERNAL_API_KEY` | AI 서비스·Dify | 서버 | 기동 실패 |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OSS_LLM_URL`, `OSS_EMBED_URL` | LLM(FastAPI만) | 서버 전용 | 해당 제공자 체인에서 제외 + 경고 |
| `ELEVENLABS_API_KEY` | TTS·STT(Next.js 서버, 오케스트레이터) | 서버 전용 | 체인에서 제외 |
| `OSS_VOICE_URL` | 공용 음성 서버 | 서버 | 기동 실패(대체 경로가 없다) |
| `FAL_KEY` | 이미지(오케스트레이터만) | 서버 전용 | 기동 실패 |
| `WORKER_ID`, `RENDER_CONCURRENCY`(기본 2), `RENDER_TIMEOUT_FACTOR`(기본 10) | 렌더러 | 서버 | 기본값 |
| `IP_HASH_SALT_SEED` | 클릭 IP 일 단위 솔트 생성 | 서버 전용 | 기동 실패 |
| `NEXT_PUBLIC_HERO3D_ENABLED`, `NEXT_PUBLIC_HERO_VIDEO_ENABLED` | 3D·3D 영상 킬 스위치 | 공개 | 꺼짐 = 정지 이미지 |
| `CREDENTIAL_ENCRYPTION_KEY` | YouTube 토큰(P1, 코어 vault) | 서버 전용 | 기동 실패 |

인증 단계 변수는 9.2절.

## 9. 인증 단계 (확정 결정 22)

### 9.1 단계표 (이 제품 기준)

| 단계 | 로그인 수단 | 켜는 조건 | 작업 |
|---|---|---|---|
| A | 로컬 시드 계정 개발용 패널(`/login`), `/api/dev/login` | 로컬 Supabase + `AUTH_MODE=mock` | TR-06-004 |
| B | Google OAuth + 이메일(가입·재설정) | G1(사람 판정) | TR-06-053 |
| C1 | 카카오 | G2 | TR-06-054(P1) |
| C2 | 네이버(OIDC 또는 서버 브리지, D-15) | G2 | TR-06-055(P1) |

### 9.2 환경변수 (`AUTH_ROADMAP.md` 3.3절 중 이 제품 해당분)

| 변수 | 단계 | 비고 |
|---|---|---|
| `AUTH_MODE` | A~C | `mock` / `live`. 기능 코드에서 읽지 않는다 |
| `DEV_SEED_PASSWORD` | A | 로컬 전용. `NEXT_PUBLIC_*`·로그 금지 |
| `AUTH_PROVIDERS` | B~C | `google,email` → `google,email,kakao,naver` |
| `NAVER_AUTH_PATH`, `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` | C2 | 브리지일 때만 서버 전용 |

### 9.3 외부 콘솔과 배포 메모

로그인용 Google 클라이언트와 YouTube 채널 연결용 클라이언트를 분리한다(D-17). 콜백 `/auth/callback`의 `next`는 허용 목록 경로만.

### 9.4 로그인 없는 흐름

`/b/[code]`, `/review/[token]`(P1), 랜딩·법적 고지. 로그인 버튼을 넣지 않는다.
