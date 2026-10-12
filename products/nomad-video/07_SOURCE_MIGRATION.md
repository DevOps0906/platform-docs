# 07 원본 이식과 폐기: NOMAD AI Factory (nomad-video)

경로: SMK=`NOMAD Shorts Maker/`, BSD=`Nomad-BlogStudio/`, YSM=`git show 5f6d262:Youtube_shots_Maker/`(작업 트리에서는 삭제됨, 읽기 전용).

## 1. 원본별 자산 분류

### 1.1 NOMAD Shorts Maker (베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md`, `PRD_add.md`, `PRD_pricing.md` | 기획만 | 참고(이 폴더 01장으로 흡수) | `docs/products/nomad-video/01_PRD.md` | 확정 결정 8 |
| `src/lib/media/{silence-cut,ken-burns,layer-composite,watermark,thumbnail,ffmpeg}.ts`, `workers/*.py` | 부분 | 이식(로직만, Python 핸들러로) | `services/media-worker/handlers/ffmpeg/` | MA:579-581 |
| `src/lib/platforms/{youtube,instagram,threads,tiktok}.ts`, `src/lib/channels/{oauth-manager,quota-monitor}.ts` | 부분 | 이식 | `packages/sns-uploader/` | SHARED_MODULES 11장 |
| `src/lib/platforms/{coupang,suno,distrokid,serpapi,google-trends,youtube-analytics}.ts` | 부분 | 이식(coupang은 공용 affiliate 어댑터가 소유, 참고만) | orchestrator steps/radar | MA:618 |
| `src/lib/radar/{playboard,channel-finder,bling,scorer}.ts` | 부분 | 이식(난수 제거) | `workers/video-orchestrator/src/radar/` | SM #17 |
| `src/lib/ai/{deepl,elevenlabs,openai-tts,whisper}.ts` | 부분 | 이식(deepl, elevenlabs, openai-tts), whisper.ts 폐기(Python) | orchestrator steps | MA:572 |
| `src/lib/compliance/filter.ts` | 부분 | 참고(공용 compliance 모듈이 소유) | - | MA:963 |
| `src/lib/queue/pipeline-track-*.ts`, `workers/*.worker.ts` | 부분 | 참고(단계 목록만), 코드 폐기 | orchestrator flows | SM #9 |
| `src/app/page.tsx`, `src/app/pricing` | 동작 | 참고(구조만, 카피·수치 교체) | `src/app/(marketing)` | 03장 4절 |
| `src/app/landing/[slug]`, `src/app/lb/[username]`, `src/lib/landing/generator.ts`, `src/components/linkinbio/*` | 부분 | 이식(params await, 공개 RPC) | `src/app/{landing,lb}` | SM #12 |
| `src/components/{radar,jobs,longform,publish,channels,sourcing}/*` | 목업~부분 | 이식(실데이터 연결) | 화면 작업 029~034 | SM:179 |
| `src/components/automation/**`, `src/skill/automation-engine/*` | 부분 | Phase 2 참고 | automation-core | MA:639 |
| `src/skill/**`(블로그 생성·게시, 브랜드커넥트, 네이버 로그인), `src/taste/content-automator`, `001_initial.sql` | 부분 | 이관(nomad-blog) | `docs/products/nomad-blog/` | 확정 결정 1 |
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
| `backend/services/stt.py` | 부분 | 이식(전역 Lock 제거) | `handlers/stt.py` | YSM #10 |
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
| stt | 프로세스 시작 시 모델 1회 로드, 동기 처리(이벤트 루프 재생성 제거), GPU OOM 시 CPU 폴백 유지 |
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
| 10 | Mock 로그인(`lib/mock-auth.ts`) | 프로덕션 노출 | MA:669 |
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
| Mock 로그인 상시 노출 | SM `src/lib/mock-auth.ts` | 인증 우회 | 없음 |
| `/landing` 보호 | BS `middleware.ts:32` | 수익 경로 차단 | 공개 경로 배열 |
| 네이버 이메일 자동 병합, `listUsers()` 1페이지 | YSM `app/api/auth/naver/callback/route.ts:54-86` | 계정 탈취 | MVP 제외, 명시적 연결 |
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
