# 07 원본 이식과 폐기: SceneFlow (sceneflow)

AI 관련 원본 자산(2026-10-13 점검): 원본의 AI 사용은 LLM 클라이언트 3종과 Anthropic 직접 호출(`NOMAD Shorts Maker/src/lib/ai/`, YSM `script_adapter.py`, `geo_metadata.py`), DeepL·ElevenLabs·OpenAI TTS 어댑터, Whisper STT, 컴플라이언스 필터, 자유 문자열 모델명(YSM `backend/models/script.py:87`)이다. RAG, 제품 지식 위키, Dify, LangGraph, 음성 대화, 오픈소스 TTS, 3D 히어로는 원본에 없어 모두 신규다(원본 랜딩의 타임라인 히어로는 4.3절 디자인 방향으로 이미 대체됐고 3D가 아니다). 아래 표의 AI 행이 이 자산들의 대응이다. 미디어 워커(Whisper, demucs, FFmpeg)는 FastAPI AI 서비스와 합치지 않는다(02장 2절 경계 표).

경로: SMK=`NOMAD Shorts Maker/`, BSD=`Nomad-BlogStudio/`, YSM=`git show 5f6d262:Youtube_shots_Maker/`(작업 트리에서는 삭제됨, 읽기 전용).

## 1. 원본별 자산 분류

### 1.1 NOMAD Shorts Maker (베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md`, `PRD_add.md`, `PRD_pricing.md` | 기획만 | 참고(이 폴더 01장으로 흡수) | `docs/file/02-요구사항/01_PRD.md` | 확정 결정 8 |
| `src/lib/media/{silence-cut,ken-burns,layer-composite,watermark,thumbnail,ffmpeg}.ts`, `workers/*.py` | 부분 | 이식(로직만, Python 핸들러로) | `services/media-worker/handlers/ffmpeg/` | MA:579-581 |
| `src/lib/platforms/{youtube,instagram,threads,tiktok}.ts`, `src/lib/channels/{oauth-manager,quota-monitor}.ts` | 부분 | 이식 | `packages/sns-uploader/` | SHARED_MODULES 11장 |
| `src/skill/playwright-engine/naver-login.ts` | 부분 | 이식(로그인 세션 처리만, 네이버 클립 어댑터용. 비밀번호 저장 코드가 있으면 폐기하고 세션만 `CredentialVault`에) | `packages/sns-uploader/src/naver-clip/` | VD-F-075, SHARED_MODULES 11장 |
| `src/skill/playwright-engine/brand-connect.ts`, `src/app/api/brand-connect/**` | 부분 | 이관(nomad-blog 소유). video는 가져오지 않는다 | - | 확정 결정 19 |
| `src/lib/platforms/{coupang,suno,distrokid,serpapi,google-trends,youtube-analytics}.ts` | 부분 | 이식(coupang은 공용 affiliate 어댑터가 소유, 참고만) | orchestrator steps/radar | MA:618 |
| `src/lib/radar/{playboard,channel-finder,bling,scorer}.ts` | 부분 | 이식(난수 제거) | `workers/video-orchestrator/src/radar/` | SM #17 |
| `src/lib/ai/{deepl,elevenlabs,openai-tts,whisper}.ts` | 부분 | 이식(deepl, elevenlabs는 `core-voice` 어댑터 규약으로 감싸 이식), openai-tts 폐기(01장 D-14), whisper.ts 폐기(Python 미디어 워커로) | orchestrator `steps/{translate,tts}` | MA:572 |
| `src/lib/compliance/filter.ts` | 부분 | 참고(공용 compliance 모듈이 소유) | - | MA:963 |
| `src/lib/queue/pipeline-track-*.ts`, `workers/*.worker.ts` | 부분 | 참고(단계 목록만), 코드 폐기 | orchestrator flows | SM #9 |
| `src/app/page.tsx`, `src/app/pricing` | 동작 | 참고(구조만, 카피·수치 교체) | `src/app/(marketing)` | 03장 4절 |
| `src/app/landing/[slug]`, `src/app/lb/[username]`, `src/lib/landing/generator.ts`, `src/components/linkinbio/*` | 부분 | 이식(params await, 공개 RPC) | `src/app/{landing,lb}` | SM #12 |
| `src/components/{radar,jobs,longform,publish,channels,sourcing}/*` | 목업~부분 | 이식(실데이터 연결) | 화면 작업 029~034 | SM:179 |
| `src/components/automation/**`, `src/skill/automation-engine/*` | 부분 | Phase 2 참고 | automation-core | MA:639 |
| `src/skill/**`(블로그 생성·게시, 브랜드커넥트, 네이버 로그인), `src/taste/content-automator`, `001_initial.sql` | 부분 | 이관(nomad-blog) | `D:/WorkSpace/platform/docs/products/nomad-blog/` | 확정 결정 1 |
| `supabase/migrations/001_initial_schema.sql` | 부분 | 참고(테이블 개념만), 폐기 | `1200_video.sql` | SM #14 |
| `src/themes/shorts-factory.ts` | 동작 | 참고(트랙 색, 메뉴) | 토큰 036 | MA:673 |

### 1.2 Nomad-BlogStudio

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `src/lib/supabase/middleware.ts` 가드 패턴 | 동작 | 참고(`/landing` 예외 수정) | `src/proxy.ts` | BS #10 |
| `src/app/(dashboard)/*` 서버 컴포넌트 조회 | 부분 | 참고 | 화면 작업 | BS:36 |
| `src/app/api/longform/*` 골격 | 목업 | 참고(섹션 정규화) | `src/server/longform` | BS #16, #20 |
| `src/lib/ai/fal-image.ts` | 부분 | 폐기(공용 fal client) | - | SHARED_MODULES 9장 |
| 저장소 나머지 | - | 폐기 | - | MA:663 |

### 1.3 Youtube_shots_Maker

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `backend/services/downloader.py`(798줄) | 부분 | 이식 | `services/media-worker/handlers/download.py` | YSM:122 |
| `backend/services/audio_separator.py` | 부분 | 이식(타임아웃 추가) | `handlers/separate.py` | YSM #14 |
| `backend/services/proxy_manager.py` | 부분 | 이식(소싱 전용) | `media-worker/core/proxy.py` | MA:566 |
| `backend/services/stt.py` | 부분 | 이식(전역 Lock 제거, 라우팅 `video.stt` 편입과 사용량 기록 추가, faster-whisper 정렬은 01장 D-13) | `handlers/stt.py` | YSM #10 |
| `backend/services/geo_metadata.py` | 부분 | 참고(프롬프트) | orchestrator steps | MA:610 |
| `backend/services/account_manager.py`의 AES-GCM | 동작 | 참고(방식만, 저장은 코어 vault) | - | YSM:165 |
| `backend/services/video_editor.py`, `tts.py`, `script_adapter.py` | 부분 | 참고(Edge-TTS/CLOVA 제외) | - | MA:576 |
| `backend/services/naver_shopping.py` | 부분(Mock 폴백) | 참고(공개 API 미확인이라 코드 미이식) | 공용 affiliate | 확정 결정 12 |
| `backend/services/{naver_blog,blog_writer}.py`, `tasks/blog_pipeline.py` | 부분 | 이관(nomad-blog) | - | 확정 결정 1 |
| 그 외(FastAPI, Celery, Next 14, Docker, 마이그레이션) | 부분 | 폐기 | - | MA:660 |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| downloader | URL 도메인 허용 목록, yt-dlp 인자 앞 `--`, 300초 타임아웃·kill, `except: pass` 제거(YSM #16), 결과를 `video-media`에 업로드, pHash 계산 |
| audio_separator | 900초 타임아웃, 출력 경로는 서버 생성 uuid |
| stt | 호출마다 `core.ai_usage` stt 행 기록(VID-06-052 `handlers/usage/`), 공용 음성 서버와 같은 세그먼트 형식, 프로세스 시작 시 모델 1회 로드, 동기 처리(이벤트 루프 재생성 제거), GPU OOM 시 CPU 폴백 유지 |
| ffmpeg 계열(SMK workers) | 입력 계약 `input_path` 단일화(SM #10의 `videoPath`/`audioUrl` 불일치 해소), `execFile` 인자 배열, 레이어 순서 상수 |
| sns 업로더 | `readFileSync` → 스트림 resumable(SM #18), 반환 타입 정리(`uploadVideo().videoId`), 토큰은 vault에서 복호화, 쿼터 사용량 갱신 |
| oauth-manager | state는 코어 `create/consume_oauth_state`, 콜백에서 쿠키 세션에 의존하지 않음 |
| radar | 난수 성장률 제거, 수익 추정 출처 저장 |
| landing/lb | `params` await, 공개 RPC 사용, 대가성 문구 표시, 조회수 service RPC |
| coupang | 공용 affiliate 어댑터로 대체(직접 이식하지 않음), 키는 vault |
| 화면 컴포넌트 | 하드코딩 hex 242회(BS #24) → 토큰, `any` 제거, 서버 컴포넌트 우선 |

## 3. 폐기 목록과 사유

분석의 "폐기"(C-3 표 13행 MA:658-675, 매트릭스 내 폐기·제외 MA:576, :580, :598, :643)를 빠짐없이 옮긴다.

| # | 대상 | 사유 | 근거 |
|---|---|---|---|
| 1 | YSM FastAPI 라우터 9개, Celery 태스크·beat, Next 14 프론트, `start.ps1`, Dockerfile 2종, `docker-compose.yml`, `railway.toml` | 2세대로 대체, 코드 공유 흔적 없음. 서비스 함수만 이식 | MA:660 |
| 2 | YSM 작업 트리 잔해(pyc, .venv, node_modules, .next, 평문 키 `.env`) | 실행 불가, 키 유출 위험. 태그 보존 후 삭제 | MA:661 |
| 3 | YSM role/plan 이중 권한, 실패 시 기본 `admin` 표시 | 권한 오인 | MA:662 |
| 4 | BS 저장소 자체 | v0.3.0 하위 집합, lib 21개 중 17개 죽은 코드 | MA:663 |
| 5 | BS 002 마이그레이션 중복 RLS/인덱스, `increment`(x+1) | 의미 오류, 중복 | MA:664 |
| 6 | SM `001_initial.sql`(user 기반 9테이블), `002_billing.sql` | org 기준 통일, 번호 충돌 | MA:665 |
| 7 | SM 플랜 정의 3벌(`lib/plans.ts`, 테마 plans, 웹훅 `PLAN_CREDITS`) | `core.plans` + PRD_pricing 하나로 | MA:666 |
| 8 | SM 결제 두 번째 경로(웹훅 orderId 파싱) | 정상 결제는 실패, 위조만 통과 | MA:667 |
| 9 | `x-internal-call` 우회, `fetch(APP_URL+'/api/…')` 자기 호출 | 인증 우회 | MA:668 |
| 10 | Mock 로그인(`lib/mock-auth.ts`) | 프로덕션 노출. 허용되는 Mock은 `AUTH_ROADMAP.md` 2장 | MA:669 |
| 11 | LLM 클라이언트 3종, YSM Anthropic 직접 호출 | 공용 게이트웨이 하나 | MA:670 |
| 12 | Python 워커가 BullMQ 프로토콜을 흉내 내는 방식 | 큐 경쟁·충돌. Python은 `core.jobs`만 | MA:671 |
| 13 | 플레이보드 난수 성장률, 대시보드 더미 배열 | 가짜 지표 저장 | MA:672 |
| 14 | 루트 문서 분기본(`_add`, `_pricing`, `_complete`), `taste-skill*.ts` 3종, `files.zip`, content-automator 테마 | 중복. 이 기획 폴더가 정본 | MA:673 |
| 15 | Remotion, CapCut 익스포트 | 의존성 없음, FFmpeg 하나로 충분 | MA:674, :580 |
| 16 | ioredis 루트 직접 의존 | bullmq 내장분과 중복 | MA:675 |
| 17 | Supabase Edge Functions 3종(automation-callback, process-schedule, session-check) | Next 라우트·워커와 기능 중복 | MA:643 |
| 18 | Edge-TTS, CLOVA TTS | ElevenLabs + OpenAI 백업으로 통일 | MA:576 |
| 19 | YouTube Live 24시간(분석: 폐기) | 확정 결정 7로 "폐기"가 아니라 Phase 2로 변경. 기록만 남김 | MA:598, 확정 결정 7 |
| 20 | BS `lib/ai/fal-image.ts` placeholder URL 반환 | 오류를 숨겨 과금(BS #17). 공용 fal client | BS:71 |
| 21 | SM Content Automator 블로그 기능, YSM Track D 블로그 | 폐기가 아니라 nomad-blog로 이관(결정 1) | MA:628-633 |

AI 계층 도입(2026-10-13)으로 생긴 추가 폐기. 분석 C-3 목록 밖이라 번호 앞에 N-을 붙인다(위 21개와 합산하지 않는다).

| # | 대상 | 사유 | 근거 |
|---|---|---|---|
| N-22 | OpenAI TTS-1-HD 백업 호출(SM `src/lib/ai/openai-tts.ts`, PRD 14장 TTS 백업) | 코어 제공자 레지스트리에서 `openai`는 `llm`만이다. 체인 `elevenlabs → oss-voice`로 대체(01장 D-14, 코어 요청 R-V2) | `D:/WorkSpace/platform/docs/products/_supabase-modular/seed.sql:216` |
| N-23 | orchestrator의 TS LLM 직접 호출 경로(번역·대본·블링·메타·compliance 단계가 LLM 클라이언트를 직접 부르던 코드) | 라우터가 FastAPI로 옮겨졌다. 단계는 그래프 `video.script`·`video.step` 호출로 바뀐다(02장 5.2절). 폐기 #11(LLM 클라이언트 3종)과 같은 뿌리 | `docs/file/03-설계/공용코어/SHARED_MODULES.md:42` |
| N-24 | 원본 랜딩 연출 "플레이헤드 1회 스윕"(4.3절 초기안) | 3D 히어로가 대체(사용자 결정 2026-10-13, 03장 4.5절). 하단 구성은 유지 | 확정 결정 15 |
| N-25 | YSM의 FastAPI 라우터를 AI 서비스로 재사용하는 안 | `apps/api`는 AI 전용 신규 서비스다. 미디어·소싱·OAuth 라우터를 섞으면 LLM 키와 미디어 바이너리 경계가 무너진다(폐기 #1, YSM #8과 같은 결론) | 02장 2절 경계 표 |

## 4. 복사 금지 결함

SECURITY_BASELINE 14장 중 해당 항목 + 제품 고유 결함.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 RPC EXECUTE 미회수 | SM `001_initial_schema.sql:455-499`, BS `002_rpc_functions.sql:6-50` | 브라우저에서 충전 | 코어 service 전용 RPC, 제품 함수 끝에 PUBLIC EXECUTE 회수 |
| 비원자 차감, refund에 Promise 대입 | BS `src/lib/billing/credits.ts:22-73` | 음수 잔액, 원장 불일치 | `consume_credits`/`refund_credits` |
| 웹훅 서명 선택적, orderId 파싱 | SM `webhooks/toss/route.ts:19-51`, BS `billing/confirm/route.ts:32-34` | 위조 결제 | 코어 webhooks + confirm |
| `customerKey = user-${Date.now()}` | SM `src/app/pricing/page.tsx:39` | 빌링키 불가 | `org_<org_id>` |
| OAuth state base64 JSON 신뢰 | SM `channels/oauth/route.ts:16-18`, BS `auth/youtube/callback/route.ts:20`, YSM `backend/routers/oauth.py:76-92` | 타인 계정에 채널 연결 | 코어 oauth_states |
| 토큰 평문(`access_token_enc`), 0키 폴백 | BS #11, SM `src/lib/crypto.ts:4` | DB 유출 시 전 계정 탈취 | vault, 키 없으면 기동 실패 |
| 세션 없는 백그라운드 작업이 anon 클라이언트 사용 | SM `src/lib/supabase/server.ts` | 조용한 실패 | admin 클라이언트 + guard 트리거 |
| `org_members FOR ALL`, 멤버 UPDATE로 잔액·플랜 수정 | BS `001_initial_schema.sql:226-287` | 테넌트 붕괴, 셀프 업그레이드 | 코어 정책, 제품 테이블에 잔액·플랜 없음 |
| `x-internal-call` 헤더 우회 | SM `posts/[id]/publish/route.ts:23-30` | 인증 우회 | 함수 직접 호출 |
| Mock 로그인 상시 노출 | SM `src/lib/mock-auth.ts` | 인증 우회 | 이 파일은 옮기지 않는다. 허용되는 Mock은 `AUTH_ROADMAP.md` 2장(로컬 시드 계정으로 실제 JWT, 원격·배포 차단)뿐(확정 결정 22) |
| `/landing` 보호 | BS `middleware.ts:32` | 수익 경로 차단 | 공개 경로 배열 |
| 네이버 이메일 자동 병합, `listUsers()` 1페이지 | YSM `app/api/auth/naver/callback/route.ts:54-86` | 계정 탈취 | MVP 제외, C2(G2 후, VID-06-065)에서 네이버 고유 id 기준·로그인 상태 명시적 연결(`AUTH_ROADMAP.md` 7.2.3절) |
| task_id 소유권 미검증 | YSM `backend/routers/studio.py:306-340` | IDOR | `core.jobs` RLS + org 대조 |
| 자유 문자열 모델명 | YSM `backend/models/script.py:87` | 비용 남용 | 허용 목록 |
| 예외 원문을 쿼리스트링으로 노출 | YSM `backend/routers/oauth.py:296-299` | 내부 정보 누출 | 오류 코드만 |
| 하위 프로세스 타임아웃 없음 | YSM `audio_separator.py:153-171`, `video_editor.py:256-305` | 워커 정지 | 타임아웃 + kill |
| yt-dlp 인자 주입 | BS `src/lib/media/ytdlp.ts:29-31` | 옵션 주입 | `--` + 허용 목록 |
| AI 결과 `dangerouslySetInnerHTML` 무 sanitize | SM `MultiChannelEditor.tsx:316` | XSS | 텍스트 렌더 또는 sanitize |
| 성장률 난수 저장 | SM `src/lib/radar/playboard.ts:75-76` | 허위 지표 | null + 추정 배지 |
| 랜딩 미검증 수치 "128,470+" | SM `src/app/page.tsx:164` | 허위 표시 | 검증 수치만 |
| 운영자 이메일 하드코딩 admin 부여 | YSM `backend/migrations/003_user_roles.sql:58` | 개인정보, 환경 분리 불가 | `approve_profile`/platform_admin 수동 부여 |
| 실키 `.env` 잔존 | YSM `backend/.env`, BS `.env` | 키 유출 | 재발급 후 삭제 |
| LLM·음성 키를 브라우저, Vercel 클라이언트 번들, 미디어 워커에 두기 | SM `.env.local`의 LLM 키 다수(원본은 Next.js 서버에 직접 둠) | 키 유출, 비용 남용, 미디어 워커 침해 시 확산 | LLM 키는 FastAPI 전용, ElevenLabs 키는 서버 전용 프로세스(Next.js, 오케스트레이터), 서명 개인키는 Next.js만(02장 8절) |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·채널 토큰·개인정보 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `context_ref`, `dify_user`) |
| 내레이션·샘플 도중 다른 제공자로 대체 | `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:47` | 한 영상 안에서 목소리가 바뀜 | 작업 시작 때 고정, 대체 금지, 실패 + 환불(02장 5.3절) |
| 원본 영상·오디오를 국외 STT로 전송 | 신규 위험(제3자 저작물·음성) | 권리·개인정보, 국외 이전 | `video.stt`는 `oss-voice` 고정(01장 6.1절) |
| LLM이 대가성 문구를 쓰거나 지우거나 우회 표현으로 대체 | 확정 결정 12 | 표시·광고법 위반 | 문구는 서버가 삽입(`effective_disclosure`), 그래프는 자리만 비움, DB CHECK |
| 근거 없는 조회수·수익 수치와 가상 후기를 LLM이 생성 | `NOMAD Shorts Maker/src/app/page.tsx:164`(미검증 수치 전례), 01장 6절 | 허위 표시 | 근거 id가 있는 수치만 인용, compliance 노드 규칙 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용, 과금 우회 | DB의 메시지·대본만 낭독. 샘플만 100자 이하 + 선차감 + 레이트 리밋 |
| 타인(원본 배우·크리에이터) 목소리 복제 | `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:80` | 음성·초상 권리 침해 | 미제공, Phase 2도 본인 한정 |
| 미디어 처리(FFmpeg·Whisper)를 FastAPI AI 서비스에 넣기 | 02장 2절 | LLM 키와 미디어 바이너리 경계 붕괴 | 미디어 워커(`core.claim_jobs`)에만 |
| 3D 재질에 토큰 밖 색, 3D 안 숫자·글자, 보라 글로우·네온 그리드 | `docs/file/03-설계/디자인/HERO_3D.md:52-53`, REFERENCES sceneflow 피할 인상 | 피할 인상, 검증 불가 수치 | 03장 4.5절 토큰 표 |
| "Tailwind로"만 지시해 v3 설정 생성 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:23` | v3 설정 혼입 | 지시와 문서에 Tailwind CSS v4 명시, `tailwind.config.js` 금지 |

## 5. 아카이브 절차

git 쓰기 명령은 사용자 승인 후 개발 단계에서 수행한다(이 기획 작업은 읽기만 했다).

| 순서 | 작업 | 담당 |
|---|---|---|
| 1 | `git tag archive/youtube-shots-maker-v1 5f6d262` (0b7f3fa 삭제가 의도였는지 사용자 확인 후) | VID-06-040, 사용자 승인 |
| 2 | Youtube_shots_Maker 작업 트리 잔해(pyc, .venv, node_modules, .next, tsbuildinfo) 삭제, 루트 `.gitignore`에 `__pycache__/`, `*.pyc`, `.venv/`, `*.tsbuildinfo` 추가 | VID-06-040 |
| 3 | 노출 키 목록 작성 → 재발급(YSM `backend/.env`, `.env.local`, BS `.env`, SM `.env.local`): Supabase service, OpenRouter, Anthropic, OpenAI, 암호화 키 | VID-06-040, 사용자 |
| 4 | Nomad-BlogStudio, NOMAD Shorts Maker를 `archive/` 이동 또는 태그 `archive/nomad-blogstudio-v0.3`, `archive/nomad-shorts-maker-v0.4` | VID-06-040 |
| 5 | SM `files.zip`, `taste-skill-shorts-factory*.ts` 3종, `_add`/`_pricing`/`_complete` 문서는 아카이브에만 남김 | VID-06-040 |
| 6 | 정리 커밋과 기능 커밋 분리 규칙을 CLAUDE.md에 둔다(YSM #1 재발 방지) | 이 폴더 CLAUDE.md 2장 |
| 7 | AI 인프라 연결: 공용 Dify에 `video-chat` 앱 등록과 내부 키 발급, 운영자 지식 조직 생성(`VIDEO_KNOWLEDGE_ORG_ID`), 공용 음성 서버 보이스 목록 확정 | VID-06-050, 사용자(R-V7, R-V10) |

## 6. 인증 단계 관련 복사 금지 (2026-10-14 추가, 확정 결정 22)

4절 표에 없는 인증 패턴을 여기 둔다. 허용되는 Mock은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2장(로컬 시드 계정으로 실제 JWT, `isMockAuthAllowed()` 가드, 배포 환경 404)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키·localStorage에 역할·플랜을 적는 Mock(`mock-auth.ts`, `nomad_role`, `nomad_plan`, `mock-login`, `dev-user`) | 이 제품 원본: SM `src/lib/mock-auth.ts:15-19`(localStorage Mock 로그인, 항상 렌더, `docs/reference/reviews/NOMAD_Shorts_Maker.md:83`, 4절 표의 "Mock 로그인 상시 노출" 행). 쿠키 이름 `nomad_role`·`nomad_plan`은 같은 계열 원본의 전례: `D:/WorkSpace/platform/docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96`, `D:/WorkSpace/platform/docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88` | 권한 위조, 프로덕션 노출 | `AUTH_ROADMAP.md` 2장 시드 페르소나 + `session_context` |
| 로그인 콜백의 `next`·`redirect` 무검증 리다이렉트 | 이 제품 원본의 사용자 로그인 콜백은 리뷰에 없다(미확인). YSM 네이버 콜백(`[5f6d262] app/api/auth/naver/callback/route.ts`)은 4절에서 이미 폐기 | 오픈 리다이렉트 | `next`는 `/`로 시작하고 `//`·`@`·`\` 없을 때만, origin은 `NEXT_PUBLIC_APP_URL` 고정(`AUTH_ROADMAP.md` 3.2절 5번) |
| 기능 코드의 `if (mock)`, 페르소나 이메일로 권한 분기 | 신규 위험 | 배포 경로와 개발 경로가 갈라져 테스트가 의미를 잃음 | 단계 분기는 `src/lib/auth/`·로그인 화면·콜백·`/api/dev/login`만(CI 검사, 06장 VID-06-039) |
| 채널 연결 OAuth 코드(`oauth-manager`, `core.oauth_states`)를 사용자 로그인 콜백에 재사용 | SM `src/lib/channels/oauth-manager.ts`(2절 이식 대상) | 채널 state는 로그인한 사용자·조직이 전제라 로그인 전에 쓸 수 없고, 두 흐름의 토큰 저장 규칙이 다르다 | 사용자 로그인은 Supabase Auth(`signInWithOAuth`) + `/auth/callback`, 채널은 기존 코어 oauth 모듈. 서로 import하지 않는다 |
| 네이버 클립 Playwright 로그인(`naver-login.ts`)을 사용자 네이버 로그인(C2)에 재사용 | SM `src/skill/playwright-engine/naver-login.ts`(1.1절 이식 대상, 클립 어댑터 전용) | 브라우저 세션 자동화는 계정 로그인 수단이 아니다. 네이버 정책 위험이 사용자 로그인으로 번진다 | C2는 `custom:naver` 또는 서버 브리지(`AUTH_ROADMAP.md` 7.2절) |
