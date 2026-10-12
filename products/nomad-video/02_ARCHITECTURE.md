# 02 아키텍처: NOMAD AI Factory (nomad-video)

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router + React | 16.2.x / 19.2 (SM 기준, lockfile 고정) | `docs/reviews/NOMAD_Shorts_Maker.md:16` |
| UI | Tailwind v4 + shadcn/ui, lucide, recharts | SM 기준 | 같음 |
| 폼/검증/데이터 | React Hook Form + zod, TanStack Query v5 | BS 기준 | `docs/reviews/Nomad-BlogStudio.md:13` |
| DB/인증/Storage | Supabase(Postgres 15, RLS, Auth, Storage, Realtime), `@supabase/ssr` | - | CORE_SPEC 1장 |
| 오케스트레이션 워커 | Node 20 + TS, BullMQ FlowProducer, Upstash Redis(ioredis는 bullmq 내장분만) | - | 확정 결정 6, SM #11 |
| 미디어 워커 | Python 3.11, openai-whisper large-v3, demucs 4, FFmpeg 6, yt-dlp, supabase-py | 3.11 고정(YSM pyc 3.14 호환 불확실, YSM #18) | 확정 결정 6 |
| AI | 공용 LLM 게이트웨이(OpenRouter + Anthropic 폴백), DeepL, ElevenLabs, OpenAI TTS-1-HD, fal(Flux), Suno(연동 방식 미확인) | - | PRD 14장, SHARED_MODULES 8-9장 |
| 결제 | Toss Payments(코어) | - | 확정 결정 4 |
| 호스팅 | Vercel(웹), Railway(TS 워커, Python CPU 워커, Python GPU 워커) | - | PRD:663 |

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

규칙: `src/server`만 service_role 클라이언트를 import한다. 화면 컴포넌트는 서버 함수 또는 RLS 하의 조회만 쓴다. 내부 HTTP 자기 호출(`fetch(APP_URL + '/api/...')`) 금지, 함수 직접 호출만(SM #4, #15).

## 3. 공용 모듈 사용

재정의하지 않는다(SHARED_MODULES 18장).

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 가입(`signup_app='video'`), 세션, `requireSession` | `proxy.ts`, 레이아웃, 모든 Route Handler | 기본 역할 admin 금지 |
| org | 1인 1워크스페이스, Advanced 멤버 초대 | `src/server/team` 대신 코어 RPC 직접 | `team_members` 상한은 서버 판정 |
| credits | 생성·업로드·검사 선차감, 실패 환불, 부분 환불 | `src/server/*` | 멱등 키 `consume:video:<request_id>` |
| toss | 구독, 크레딧팩, 빌링키 | `src/server/billing`, orchestrator cron | `confirm_payment_order` PM001 시 주문이 failed로 남지 않는 코어 결함에 의존하지 않고 운영 알림 + 취소를 직접 수행 |
| webhooks | Toss, fal, (Phase 2) Distrokid, Make/n8n | `src/app/api/webhooks/*` | 서명 없으면 거부 |
| oauth | YouTube/Meta/TikTok 채널 연결, 쿠팡 키 저장 | `src/server/channels`, `src/server/affiliate` | state는 `create_oauth_state`만 |
| llm gateway | 번역 후처리, 대본, 스토리라인, 블링, GEO 메타, 플리 메타, compliance | orchestrator steps, `src/server/radar` | 모델 허용 목록(YSM #6) |
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
| `ai.translate`, `ai.script`, `ai.tts`, `ai.image` | `video.ai` | TS | 루트에 포함 | 3(지수 백오프) | 루트 규칙 |
| `longform.storyline` | `video.ai` | TS | 5(동기 호출, withCredits) | 1 | 즉시 환불 |
| `longform.render`(루트) | `video.orchestrate` | TS | 이미지 10장 + TTS + 인코딩 합계 | 0 | 루트 규칙 |
| `longform.highlights` | `video.orchestrate` | TS+Python | 11 | 1 | 최종 실패 |
| `music.generate` | `video.ai` | TS | 15 + 커버 3 + 루프 5 | 2 | 최종 실패 |
| `music.package` | `video.ai` | TS | 0 | 2 | 해당 없음 |
| `playlist.render`(루트) | `video.orchestrate` | TS | 렌더 + 메타 + 썸네일 | 0 | 루트 규칙 |
| `media.loop`, `media.playlist_concat`, `media.highlight_cut` | `video.media.cpu` | Python | 루트에 포함 | 2 | 루트 규칙 |
| `compliance.check` | `video.ai` | TS | 1(LLM 단계가 있을 때) | 1 | LLM 실패 시 환불 + WARN |
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

## 5. AI 라우팅

| purpose | 모델(fast / quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `translate`(DeepL 후 톤 각색: A 도파민형, B 리뷰어 톤) | 게이트웨이 fast / quality | STT+번역 5/분에 포함 | DeepL 결과 그대로 + 경고 |
| `script`(Track C 대본, 롱폼 10섹션) | quality | 3 / 5 | 게이트웨이 폴백 모델 1회 |
| `analyze`(상품명 파싱, 주제 점수, 하이라이트 선정) | fast | 포함 / 2 | 폴백 1회 |
| `bling` | quality(웹 검색 가능 모델, 미확인) | 5 | 실패 시 환불 |
| `geo_meta`, `playlist_meta` | fast | 포함 / 2 | 폴백 1회 |
| `compliance` | fast | 1 | 실패 시 WARN + 환불 |

모델 이름은 게이트웨이 설정에서만 바꾼다. 요청 본문의 모델 지정은 허용 목록 밖이면 422(YSM #6).

| 매체 | 제공자 | 비고 |
|---|---|---|
| STT | Whisper large-v3(자체 GPU 워커) | 프로세스당 모델 1회 로드, 동시성 1 |
| TTS | ElevenLabs Multilingual v2 기본, OpenAI TTS-1-HD 백업 | Edge-TTS/CLOVA 제외(MA:576) |
| 이미지 | fal Flux Pro/Ultra | `enable_safety_checker=true` |
| 음원 | Suno | 공식 공개 API 여부 미확인. 확인 전에는 사용자가 Suno에서 만든 파일 업로드 경로 병행(01장 8절 #8) |
| 음원 분리 | demucs | BGM/보이스 분리, 타임아웃 900초 |

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
| `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY` | LLM 게이트웨이 | 비공개 | 기동 실패 |
| `DEEPL_API_KEY`, `ELEVENLABS_API_KEY`, `OPENAI_API_KEY`, `FAL_KEY`, `SUNO_API_KEY` | AI | 비공개 | 해당 단계 잡 실패(환불), 대시보드 경고 |
| `SERPAPI_KEY`, `RAPIDAPI_KEY`, `PROXY_POOL_URL` | 레이더·소싱 | 비공개 | 해당 수집 비활성 |
| `FAL_WEBHOOK_SECRET` | fal 웹훅 | 비공개 | fal 비동기 비활성 |
| `AFFILIATE_IP_SALT_SEED` | 클릭 IP 해시 | 비공개 | 기동 실패 |
| `WORKER_ID`, `MEDIA_QUEUE`(Python) | 워커 식별 | 비공개 | 기동 실패 |

모든 env는 `src/lib/env.ts`(zod)와 Python `settings.py`(pydantic)에서 기동 시 검증한다(SM #20, BS #18).
