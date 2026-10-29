# 06 에이전트 작업 계획: SceneFlow (sceneflow)

작업 ID는 `VID-06-###`(DB_CONVENTIONS 1장 SQLSTATE 접두사 `VD`의 작업 약어). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장: Fable(결제, 권한, RLS, 데이터 모델), Opus(기능 구현, API 연동, 테스트 설계), Sonnet(UI, 메인페이지, 컴포넌트, 문서), Haiku(보일러플레이트, 린트/타입, 문구, 반복 체크).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/design-module/_design-guide/DESIGN_SYSTEM.md` 4장) 작업 16개(VID-06-041~056)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 012(사용량 기록), 016(대본·TTS 이관), 036(디자인 시스템 2단계 토큰), 004·023·028·035·038(선행 추가), 001·003·005·021·039(수용 기준 보강)이다. 작업 수 56개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. 기존 40개가 이미 한도를 넘었고(Track A~F 전부 MVP, 확정 결정 7) AI·음성·3D·디자인 시스템이 MVP에 들어와 작업 하나를 더 합칠 수 없어 분리했다. 이후 2026-10-13 2차 개정으로 클립·브랜드커넥트·대행 6개(057~062)가, 2026-10-14 인증 단계(확정 결정 22)로 3개(063~065, 8절)가 더해져 65개(모델 작업 64, 사람 1)가 되었고, 004는 Stage A 범위로 바뀌었다. 2026-10-18 스토리보드 디벨롭(01장 10장)으로 9장 19개(066~084)가 더해져 전체 ID 84개(모델 83, 사람 1)이고, 그중 MVP 계획 79개(모델 78, 사람 1; P0 66, P1 13), Phase 2로 옮긴 3개(019, 020, 031), 9장이 대체해 실행하지 않는 2개(018, 030)다(9.5절). 같은 날 AI 자동편집·화면비(01장 11장, 주력 기능 SF-5)로 10장 30개(085~114)가 더해져 전체 ID 114개(모델 113, 사람 1), MVP 계획 108개(P0 88, P1 20), 실행하지 않는 것은 018·030·082(10장 흡수) 3개다(10.5절).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 아래 표의 디렉토리만 만든다·고친다. 다른 작업의 디렉토리를 고쳐야 하면 그 작업 소유자에게 요청 작업을 남긴다 |
| 공용 파일 | `apps/sceneflow/src/lib/**`(env, core 래퍼)은 VID-06-003, `src/server/billing/**`(게이팅·단가)는 VID-06-005만 수정(2026-10-18: `billing/storyboard.ts`만 069, 9장, `billing/ai-edit.ts`만 087, 10장). 다른 작업은 import만. 예외: `src/lib/auth/**`(인증 모듈 경계)는 004(Stage A) → 063(B) → 064·065(C) 순서로 이어 받는다(8절, 동시 쓰기 없음) |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, 공용 패키지(`packages/core-*`) 수정 금지. 필요하면 6절 코어 요청 |
| DB | 스키마 변경은 VID-06-001(Fable)만. 모놀리스는 변환 스크립트로만 생성(2026-10-18: 스토리보드 절은 001 담당이 001 뒤 066으로 이어 수행, 9장. AI 자동편집 13절은 066 뒤 085, 10장) |
| 테스트 | 모든 P0 작업은 3절 웨이브 표의 테스트 작업(002, 007, 037, 038, 055) 중 하나에 대응한다(2026-10-18: 9장 작업은 068, 083, 084, 9.2절. 10장 작업은 086, 105, 106, 10.2절) |
| AI 서비스 경계 | `apps/api/`는 VID-06-045가 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. video 확장은 작업별로 나눈다: 047 `app/ai/products/video/knowledge.py`, 048 `app/ai/products/video/wiki_config.py`, 049 `app/ai/graphs/`·`app/ai/compliance/video.py`, 050 `app/ai/tools/video/`. FastAPI는 영상·오디오 바이너리를 처리하지 않고 미디어 워커는 LLM 키를 갖지 않는다(02장 2절 경계 표). 2026-10-18: `app/ai/graphs/video_storyboard.py`·`video_shorts_pick.py`는 071(9장), `video_edit_plan.py`·`products/video/edl_schema.py`는 089(10장) |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(R-V5~R-V10) |
| 사람 작업 | VID-06-043(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(004, 023, 028~035, 048, 051, 054, 056, 2026-10-18: 9장 078~081, 10장 099~103·110 포함)은 VID-06-044(4단계) 뒤에 시작한다(`docs/design-module/_design-guide/DESIGN_SYSTEM.md:48`) |
| 대가성 문구 | 문구 삽입은 VID-06-021만 한다. AI 작업(049, 050)은 문구를 쓰거나 지우지 않고 규칙 파일로 모방 문장을 제거만 한다(확정 결정 12) |

| 영역 | 경로(제안 모노레포) |
|---|---|
| DB | `supabase/migrations/1200_video.sql`, `supabase/monolith/**`, `scripts/mono-convert.mjs` |
| 웹 공통 | `apps/sceneflow/src/{proxy.ts,lib/**}`, `package.json` |
| 서버 도메인 | `apps/sceneflow/src/server/<domain>/**` |
| API | `apps/sceneflow/src/app/api/<domain>/**` |
| 화면 | `apps/sceneflow/src/app/(dashboard)/dashboard/<area>/**`, `src/components/<area>/**` |
| 워커 | `workers/video-orchestrator/src/<area>/**`, `services/media-worker/**`, `packages/sns-uploader/**` |
| 테스트 | `supabase/tests/**`, `tests/{e2e,integration}/<area>/**` |
| AI 서비스 | `apps/api/**`(Python), `packages/video-rules/**` |
| AI 게이트·음성 | `apps/sceneflow/src/app/api/{ai,internal,onboarding,voice,wiki}/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` |
| AI·음성 UI | `src/components/{ai-chat,voice,voice-engine,script-plan,wiki,hero3d,ui}/**`, `src/app/(dashboard)/dashboard/{chat,wiki}/**`, `src/app/dev/components/**` |
| Dify·지식 | `infra/dify/**`, `scripts/{knowledge,ai-routing}/**` |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| VID-06-001 | 1200 조각 적용, 모놀리스 변환 스크립트, 타입 생성(`--schema core,video`) | `supabase/migrations/1200_video.sql`, `supabase/monolith/**`, `scripts/mono-convert.mjs`, `apps/sceneflow/src/types/supabase.ts` | 없음 | P0 | M | Fable(데이터 모델) | `supabase db reset` 성공, 체커 OK(모듈러·모놀리스), 타입 파일에 26개 테이블(2026-10-13 대행 4개 포함), 11절 AI 라우팅 17행과 체인 검사 DO 블록 통과(2026-10-18: 스토리보드 테이블 6개는 001 뒤 9장 066이 이어 추가) | 05장, SM 작업 6, BS 작업 1·11·14 |
| VID-06-002 | RLS/권한 회귀 테스트(PGlite + 로컬 Supabase) | `supabase/tests/**` | 001 | P0 | M | Fable(RLS) | 05장 9절 65항목 + 2026-10-13 클립·대행 33항목 + SECURITY_BASELINE 15장이 CI에서 통과, 실패 시 머지 불가(2026-10-18: 스토리보드 항목은 9장 068) | SM 작업 1·15, BS 작업 1, YSM 작업 6 |
| VID-06-003 | 앱 골격: `proxy.ts` 공개 경로 배열, `lib/env.ts`(zod), 코어 클라이언트 3계층 연결, `requireSession`, enqueue 전용 lazy Redis 모듈, 응답 봉투 | `apps/sceneflow/src/proxy.ts`, `src/lib/**`, `package.json` | 001 | P0 | M | Opus(골격·연동) | 비로그인 `/dashboard` 302, `/landing/x` 200, env 누락 시 기동 실패, `x-internal-call` 문자열 0건, 02장 8절 AI 변수(`AI_TOKEN_PRIVATE_KEY` 등)는 Next.js 서버 범위만 검증하고 `NEXT_PUBLIC_`에 비밀 0 | SM 작업 3·4·8·10·12, BS 작업 5·7·13, YSM 작업 9 |
| VID-06-004 | 인증 Stage A(2026-10-14 범위 변경, 확정 결정 22): 인증 모듈 경계(`src/lib/auth/`: `getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`), Mock 로그인(`POST /api/dev/login`, `/login` 개발용 패널, 모든 화면 상단 배지 `MOCK AUTH · 로컬 전용`), `scripts/dev/seed-users.mjs` + 제품 훅 `seed-users.video.mjs`(05장 10절 페르소나, Advanced 팀 `adv_owner`·`adv_member` 포함), 가드(env zod 기동 실패, 배포 빌드에서 `/api/dev/login` 404, 패널 미렌더), `finishLogin`(`session_context` → 필요 시 `bootstrap_app_for_org` → 상태 분기 → `next` 화이트리스트, 프로필 없으면 로그아웃). 이메일 가입·메일 인증·비밀번호 재설정 화면은 Stage B(063)로 옮겼다 | `src/app/(auth)/**`, `src/components/auth/**`, `src/lib/auth/**`(003 소유 `src/lib/`의 예외), `src/app/api/dev/login/**`, `scripts/dev/**`. 배지의 대시보드 셸 장착은 028 파일에, `.env.example`·env 스키마 항목·`package.json` 스크립트 `db:seed-users`·`proxy.ts` 공개 경로 `/login`·`/api/dev/login`은 003 파일에 1줄 요청 | 003, 044 | P0 | M | Opus(인증 모듈·Mock 가드) | `owner` 페르소나 로그인 → `session_context('video')` `entitled=true`, `plan_code=starter`, `credit_balance=100`(시드 2회 실행 뒤에도 가입 원장 1행), `adv_owner` → `plan_code=advanced`·`features.agency=true`, `adv_member` → 같은 조직 role `member`, `outsider`로 owner 조직 제품 테이블 0행·쓰기 42501, `no_app`(모듈러) 첫 진입 부트스트랩 1회 후 `entitled=true`, `suspended` 403, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404·개발용 패널 미렌더, 원격 Supabase URL이면 시드 스크립트 exit 1, 쿠키·localStorage 역할/플랜 0, 네이버 로그인 없음(C2 전) | SM 작업 4, BS 작업 4, YSM 작업 5, `AUTH_ROADMAP.md` 2장·9장 |
| VID-06-005 | 플랜 게이팅·단가표(`priceOf`)·크레딧 래퍼(consume→enqueue→환불, 부분 환불) | `src/server/billing/**` | 003 | P0 | M | Fable(과금·권한) | 01장 4절 단가와 일치하는 단위 테스트, Starter Track B 403 VD009, 동시 50요청 음수 0, AI 단가(01장 4.1절)와 `src/server/ai-pricing.ts`(046) 값이 같은지 비교하는 테스트(2026-10-18: Track S 단가·플랜 키는 9장 069) | BS 작업 2, 01장 VD-F-003/091 |
| VID-06-006 | 결제: 주문 선저장, confirm, 빌링키, 해지, Advanced 할인 팩 판정, PM001 운영 알림·취소 | `src/app/api/billing/**`, `src/server/payments/**`, `src/app/billing/**` | 005 | P0 | L | Fable(결제) | 금액 위조 PM001 + `fail_payment_order` 호출 + 취소 호출, 같은 결제 2회 멱등, 비Advanced의 adv 팩 403 | SM 작업 2, BS 작업 3, 01장 VD-F-090 |
| VID-06-007 | 결제 E2E(Toss 테스트 키): 구독, 크레딧팩, 실패 복귀 | `tests/e2e/billing/**` | 006 | P0 | M | Opus(테스트 설계) | 3시나리오 통과, 원장·엔타이틀먼트 기대값 일치. Mock `owner` 페르소나 storageState로 실행 | SM 작업 2, DOC_TEMPLATE 필수 |
| VID-06-008 | 채널 OAuth 연결·콜백·역할 변경·해제(코어 oauth, 자격증명 vault), 다채널 위험 동의 | `src/app/api/channels/**`, `src/server/channels/**` | 003, 001 | P0 | M | Fable(OAuth·권한) | state 재사용 OA001, Starter 2번째 채널 VD003, 오류 원문을 쿼리스트링에 싣지 않음, 토큰 평문 0 | SM 작업 4, BS 작업 8, YSM 작업 4·10·13 |
| VID-06-009 | sns-uploader YouTube: resumable 스트리밍, 고정 댓글, 쿼터, 대체 채널 선택, 재예약 | `packages/sns-uploader/src/{youtube,registry.ts,types.ts}` | 008 | P0 | L | Opus(API 연동) | 1GB 파일 업로드 시 RSS 512MB 이하, 쿼터 초과 시 대체 채널 또는 `run_after` 재예약 | SM 작업 12 |
| VID-06-010 | sns-uploader Meta(IG Reels, Threads)·TikTok 어댑터 | `packages/sns-uploader/src/{meta,tiktok}/**` | 009 | P1 | M | Opus(API 연동) | 샌드박스 계정 업로드 성공, 토큰 만료 시 credentials error + 재연결 요청 | 01장 VD-F-071 |
| VID-06-057 | sns-uploader 네이버 클립 어댑터(Playwright): 서버 브라우저 로그인 세션 저장(`naver-login.ts` 재사용, SHARED_MODULES 11장), 업로드 폼 자동화, `capabilities`(고정 댓글·통계 없음), 계정당 3건/시간·15건/일, 실행 직전 동의 버전 재확인, 셀렉터 실패 시 환불·운영 알림, `NAVER_CLIP_UPLOAD_ENABLED` 스위치, 수동 업로드용 패키지(영상·제목·설명·해시태그·문구) 다운로드 | `packages/sns-uploader/src/naver-clip/**`, `apps/sceneflow/src/app/api/channels/connect/naver-clip/**` | 009 | P1 | L | Opus(브라우저 자동화) | 테스트 계정으로 업로드 성공, 동의 없는 채널 VD015, 버전 바뀐 뒤 대기 잡 실패·환불, 상한 초과 시 `run_after` 재예약, 셀렉터 실패 모의 테스트에서 환불 원장 1행, 비밀번호를 서버가 받지 않음(로그인은 사용자가 브라우저 창에서) | VD-F-075, 확정 결정 18 |
| VID-06-058 | 클립 위험 동의 화면·API(고지문 `clip-2026-10-v1`, 체크 3개 + 입력, 철회 시 대기 업로드 취소·환불) | `src/app/api/channels/[id]/clip-consent/**`, `src/app/(dashboard)/dashboard/channels/[id]/clip-consent/**` | 008, 044 | P1 | S | Sonnet(UI) | 01장 6.5절 문구 그대로, 끝까지 읽기 전 체크 비활성, member 접근 403, 철회 후 queued 잡 0 | VD-F-075 |
| VID-06-059 | 브랜드커넥트 클립 캠페인(video 쪽): 캠페인 목록(blog 스캔 결과 중 클립형), blog handoff 수신(`/api/brandconnect/handoff/accept`), 지원 요청(코어 9인자 RPC, `target_kind='clip'`, `source_app='video'`), 선정 지원서 ↔ 업로드 연결, `injectDisclosure(target 'title_hashtag')` | `src/server/brandconnect/**`, `src/app/api/brandconnect/**`, `dashboard/monetize/brandconnect/**` | 021, 022, blog 어댑터(BL 작업) | P1 | M | Opus(연동) | 위험 동의 없는 계정 지원 42501 → 403, 지원서 연결 업로드의 문구 누락 23514, 다른 조직 handoff 토큰 404, video는 Playwright 코드를 갖지 않음 | VD-F-063, 확정 결정 19 |
| VID-06-060 | 대행 고객·고객 채널 API와 화면(목록·상세 탭, 상태 RPC, 생산 요청 `client_id`, 그래프 입력의 고객 범위) | `src/server/clients/**`, `src/app/api/clients/**`, `dashboard/clients/**` | 001, 016, 044, 049 | P1 | M | Sonnet(UI) + Opus(그래프 범위) | 비 Advanced 403, 고객 B 생산 근거에 고객 A 문서 0, 고객 8곳·채널 20개 목록 p95 1초 | VD-F-120~122, 125 |
| VID-06-061 | 고객 승인: 토큰 생성·해시·메일, 공개 `/review/[token]`(레이트 리밋, 서명 URL 10분), 결정 처리, 만료 정리 크론, 감사 | `src/app/api/uploads/[id]/client-review/**`, `src/app/review/**`, `src/app/api/review/**`, `workers/video-orchestrator/src/agency/review-expire.ts`. `proxy.ts` 공개 경로 `/review/**`·`/api/review/**`(로그인 없음, 01장 VD-F-002)는 003 파일에 1줄 요청 | 021, 060 | P1 | M | Fable(보안) | 토큰 원문이 DB·로그에 0, 승인 전 예약 VD016, 두 번 결정 409, 만료 링크 결정 불가, IP 해시 30회/10분 초과 429 | VD-F-123, 126 |
| VID-06-062 | 월간 고객 리포트: 집계(조회·시청·준수율·구독 순증·완주율·제휴 클릭, 미제공 지표 null), PDF 렌더(core exports), 발송 처리, 매일 06:00 크론 | `workers/video-orchestrator/src/agency/report.ts`, `src/app/api/clients/[id]/reports/**` | 026, 060 | P1 | M | Opus(집계) | 스냅샷 집계와 수치 일치(단위 테스트), 미제공 지표가 0으로 표시되지 않음, 같은 달 재생성 시 1행 유지 | VD-F-124, `08_AGENCY_OPERATIONS.md` 5장 |
| VID-06-011 | Python 미디어 워커 골격: claim/heartbeat/complete/fail 루프, 취소 신호, 하위 프로세스 타임아웃·kill, settings 검증, pytest | `services/media-worker/{core,tests}/**` | 001 | P0 | M | Opus(워커) | 타임아웃 초과 프로세스 kill 후 fail_job, 하트비트 60초, pytest 통과 | SM 작업 7, BS 작업 9, YSM 작업 8·11·12·15 |
| VID-06-012 | Whisper STT(모델 1회 로드, 동시성 1), demucs 핸들러. 호출마다 사용량 기록(052의 `handlers/usage/`) | `services/media-worker/handlers/{stt,separate}.py` | 011 | P0 | M | Opus(기능) | 60초 중국어 클립 세그먼트 반환, 전역 asyncio Lock 없음, 호출 1건당 `core.ai_usage` stt 행 1개(provider `oss-voice`, feature `video.stt`, `audio_seconds`), 공용 음성 서버와 같은 세그먼트 형식(01장 D-13) | YSM 작업 11·12 |
| VID-06-013 | FFmpeg 핸들러: 워터마크 제거·삽입, 무음컷(-30dB/0.5초), ASS+강조 자막 합성, 인코딩, 켄번스, 루프, 플리 연결, 하이라이트 컷 (2026-10-18: 루프·플리 연결은 Phase 2(SF-3), 하이라이트 컷은 9장 073 쇼츠 컷으로 대체, 켄번스·자막은 073이 재사용) | `services/media-worker/handlers/ffmpeg/**` | 011 | P0 | L | Opus(기능) | 04장 4절 계약대로 결과 경로 반환, 레이어 순서 테스트, 3시간 플리 90분 이내 | YSM 작업 12, 01장 VD-F-030~050 |
| VID-06-014 | 다운로더(YSM 이식): 도메인 허용 목록, `--`, 프록시 풀, pHash, 24시간 원본 삭제 | `services/media-worker/handlers/{download,purge}.py` | 011 | P0 | M | Opus(기능) | 허용 목록 밖 URL 거부, purge 후 객체 없음 | BS 작업 12, YSM 작업 12 |
| VID-06-015 | TS 오케스트레이터: FlowProducer 트랙별 플로우, Python 브리지(자식 core.jobs), 상태 미러링, 언어별 부분 환불 | `workers/video-orchestrator/src/{flows,bridge,index.ts}` | 005, 011 | P0 | L | Fable(아키텍처·과금) | placeholder 0건, 단계 결과 returnvalue 전달, JA 실패 시 JA분만 환불 | SM 작업 3·7·12, BS 작업 9 |
| VID-06-016 | AI 단계: 번역(톤), fal 이미지, Suno. 대본·LLM 호출 경로는 049, TTS는 053으로 이관(2026-10-13) (2026-10-18: Suno는 Phase 2(SF-3), fal 이미지 단계는 9장 072가 재사용) | `workers/video-orchestrator/src/steps/{translate,image,music}/**` | 015 | P0 | M | Opus(API 연동) | 라우팅 체인 밖 모델 요청 거부, 제공자 오류 시 폴백 1회 후 실패(mock 반환 0), OpenAI TTS 코드 0(01장 D-14) | SM 작업 10, BS 작업 11, YSM 작업 7 |
| VID-06-017 | 소싱·숏폼 생산 API(견적, 생성, 조회, 취소, 동시 생산 상한) (2026-10-18: Track C Mode1 제외 → 9장 Track S, Mode2는 Track A 옵션, SF-1) | `src/app/api/{sources,productions}/**`, `src/server/{sources,productions}/**` | 005, 015 | P0 | M | Opus(기능) | 같은 request_id 재요청 시 차감 1회, 세션 org와 다른 행 404 | YSM 작업 6, 01장 VD-F-020~035 |
| VID-06-018 | 롱폼 API: 점수 게이트, 스토리라인, 10섹션, 렌더, OSMU (2026-10-18: 9장 VID-06-074·075로 대체, 실행 안 함) | `src/app/api/longform/**`, `src/server/longform/**` | 005, 015 | P0 | M | Opus(기능) | 점수 59 → VD010 + 대안 3, 하이라이트 3개 각 60초 이하, 목업 응답 0 | BS 작업 10, 01장 VD-F-040~041 |
| VID-06-019 | Track E API: 곡 생성, 루프 영상, 유통 패키지, 상태 기록 (2026-10-18: Phase 2, SF-3) | `src/app/api/music/**`, `src/server/music/**` | 005, 015 | P0 | M | Opus(기능) | 곡 1개 = music_tracks 1 + outputs(music_loop) 1, none→live 22023 | 01장 VD-F-050~051 |
| VID-06-020 | Track F API: 플리, 항목 정렬, 라이브러리 등록, 트랙리스트·타임스탬프·고정 댓글 생성, 렌더 (2026-10-18: Phase 2, SF-3) | `src/app/api/{playlists,library}/**`, `src/server/playlists/**` | 005, 015 | P0 | M | Opus(기능) | 합계 시간 ±5% 밖 409, 만료 라이선스 곡 VD006, 타임스탬프가 실제 연결 결과와 일치 | 01장 2절 E/F 구분표 |
| VID-06-021 | 업로드 API: 문구 삽입, compliance 게이트(규칙+LLM), WARN 확인, 예약, 취소 | `src/app/api/uploads/**`, `src/server/publish/**` | 009, 022 | P0 | L | Opus(기능) | 제휴 링크 있는 업로드의 설명란·고정 댓글 첫 줄 = 문구, FAIL 업로드 예약 불가, LLM 오류 시 WARN, 그래프 생성물에 문구가 없는 것이 정상이며 첫 줄 삽입은 이 작업만 수행(VD-F-103), LLM 판정은 `video.step`(049) 경유 | 01장 VD-F-062/072 |
| VID-06-022 | 제휴 통합: 계정 연결(쿠팡 API, 텐핑·네이버쇼핑 커넥트 수동), 단축 링크, `/r/[code]`, 문구 편집 | `src/app/api/affiliate/**`, `src/app/r/**`, `src/server/affiliate/**` | 003 | P0 | M | Opus(API 연동) | `/r/` 302 + 클릭 1행(IP 해시만), 레이트 리밋 60/분, 문구 10자 미만 거부 | 확정 결정 12 |
| VID-06-023 | 공개 페이지 `/landing/[slug]`(ISR, params await), `/lb/[handle]`, 조회수 집계 | `src/app/{landing,lb}/**`, `src/components/public/**` | 001, 022, 044 | P0 | M | Sonnet(UI) | 비로그인 200, 대가성 문구 렌더, 비공개 404 | SM 작업 5, BS 작업 5 |
| VID-06-024 | 레이더 수집·API: 플레이보드(난수 0), 채널파인더, 블링(출처 필수, 월 한도) | `workers/video-orchestrator/src/radar/**`, `src/app/api/radar/**`, `src/server/radar/**` | 015 | P1 | M | Opus(API 연동) | growth_rate 미산출 시 null + 추정 배지, Pro 21번째 블링 VD012 | SM 작업 9, BS 작업 10 |
| VID-06-025 | 웹훅 수신: Toss(코어 위임), fal, (Phase 2) Distrokid·Make 서명 필수 골격 | `src/app/api/webhooks/**` | 003 | P0 | S | Opus(연동) | 서명 없는 요청 401, 중복 200 | SM 작업 11, BS 작업 6 |
| VID-06-026 | 성과 수집(YouTube Analytics 스냅샷) | `workers/video-orchestrator/src/analytics/**` | 009 | P1 | S | Opus(연동) | 일 1회 스냅샷, 실패 시 이전 값 유지 | 01장 VD-F-080 |
| VID-06-027 | 스케줄러: reap, purge, 예약 업로드 enqueue, 쿼터 리셋, 월 지급, 빌링 청구, 보존 기간 삭제 | `workers/video-orchestrator/src/cron/**` | 015 | P0 | S | Opus(워커) | CRON_SECRET 공개 라우트 0, 각 작업 멱등 | SM 작업 3 |
| VID-06-028 | 대시보드 홈 + 잡 진행률 Realtime(서버 컴포넌트, 더미 0) | `src/app/(dashboard)/dashboard/page.tsx`, `src/app/(dashboard)/layout.tsx`, `src/components/{shell,jobs}/**` | 003, 044 | P0 | M | Sonnet(UI) | 더미 배열 0, Realtime 끊김 시 폴링 | SM 작업 9 |
| VID-06-029 | 소싱·숏폼 화면 (2026-10-18: Track C 선택지 제외, 스토리보드 링크는 9장 078이 1줄 요청) | `src/app/(dashboard)/dashboard/{sources,shorts}/**`, `src/components/shorts/**` | 017, 028 | P0 | M | Sonnet(UI) | 예상 크레딧 표시, 402 안내 문구 | 03장 |
| VID-06-030 | 롱폼 스토리보드 화면 (2026-10-18: 9장 VID-06-078~081로 대체, 실행 안 함) | `src/app/(dashboard)/dashboard/longform/**`, `src/components/longform/**` | 018, 028 | P0 | M | Sonnet(UI) | 잠금 상태 편집 비활성 | 03장 |
| VID-06-031 | 곡·플리·라이브러리 화면 (2026-10-18: Phase 2, SF-3) | `src/app/(dashboard)/dashboard/{music,playlists,library}/**`, `src/components/music/**` | 019, 020, 028 | P0 | M | Sonnet(UI) | E/F 메뉴·색 분리, 키보드 정렬 대체 | 확정 결정 E/F 구분 |
| VID-06-032 | 채널·업로드 화면(설정·배포 대형 페이지를 섹션 컴포넌트로 분할) | `src/app/(dashboard)/dashboard/{channels,publish}/**`, `src/components/publish/**` | 008, 021, 028 | P0 | M | Sonnet(UI) | 문구 첫 줄 잠금 표시, WARN 확인 흐름, 파일당 400줄 이하(제안) | YSM 작업 14 |
| VID-06-033 | 수익화 화면(제휴 계정·링크·통계, 랜딩, 링크인바이오, 문구 편집) | `src/app/(dashboard)/dashboard/monetize/**`, `src/components/monetize/**` | 022, 023, 028 | P0 | M | Sonnet(UI) | 문구 끄기 UI 0, 공개 버튼이 VD001/VD009 안내 | 확정 결정 12 |
| VID-06-034 | 레이더·분석·크레딧·결제 화면 | `src/app/(dashboard)/dashboard/{radar,analytics,credits,billing,settings}/**`, `src/components/{radar,analytics,billing}/**` | 006, 024, 028 | P0 | M | Sonnet(UI) | 추정 배지, 블링 출처 목록, 원장 표 | 03장 |
| VID-06-035 | 마케팅 랜딩·요금·약관 페이지(frontend-design 절차, MASTER.md) (2026-10-18: Track E·F 소개 제외, Track S 소개, 9.4절 제안) | `src/app/(marketing)/**`, `src/app/legal/**`, `design-system/sceneflow/**` | 036, 044, 054 | P0 | M | Sonnet(메인페이지) | 03장 4절 체크(4.5절 3D 히어로는 054의 `Hero3D`를 장착), 금지 문구 0, DESIGN_PRINCIPLES 7단계 체크리스트 통과 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/design-module/_design-guide/REFERENCES.md:16-23`). | 03장 4절 |
| VID-06-036 | 디자인 시스템 2단계 토큰: 토큰 파일(라이트 랜딩·다크 대시보드, 트랙 범례), i18n 문구 키 | `src/styles/tokens.css`, `src/i18n/**` | 003, 041 | P0 | S | Haiku(보일러플레이트) | 하드코딩 hex 0(lint 규칙), 03장 3.2절 의미 기반 토큰 이름, `tailwind.config.js` 0 | BS 작업 15 |
| VID-06-037 | 파이프라인 통합 테스트(가짜 제공자, Python 워커 로컬, 부분 환불) (2026-10-18: Track A·B만, Track S는 9장 083, E·F는 Phase 2) | `tests/integration/pipeline/**` | 015, 013, 016 | P0 | M | Opus(테스트 설계) | Track A~F 각 1시나리오 통과, drift 0 | SM 작업 15, YSM 작업 15 |
| VID-06-038 | 사용자 플로우 E2E(webapp-testing): 가입→첫 생성, 업로드 WARN, Track B 랜딩, Track F (2026-10-18: Track F 플로우는 Phase 2, 스토리보드 플로우는 9장 084) | `tests/e2e/flows/**` | 029~034, 051, 053 | P0 | M | Opus(테스트 설계) | 03장 2절 6개 플로우 + AI 3개 플로우(2.7 채팅, 2.8 음성, 2.9 엔진 선택) 통과, 뷰포트 4종 스크린샷. Mock 페르소나 storageState로 실행(`globalSetup`이 `/api/dev/login`으로 `owner`, `adv_owner`, `viewer`, `outsider` 상태 저장), 063 완료 후 재실행(B-5) | 03장 2절 |
| VID-06-039 | CI(tsc, eslint, build, pytest, SQL 체커, RLS 스모크), 린트·타입 정리, 로거, sanitize | `.github/workflows/sceneflow.yml`, `apps/sceneflow/eslint.config.mjs` | 001 | P0 | S | Haiku(린트·설정) | CI 녹색, `console.log` 0, `dangerouslySetInnerHTML` 0, `pytest apps/api`·`ruff` 포함, 비밀 검사에 AI 키 패턴 추가. 인증 금지 문자열 검사(`AUTH_ROADMAP.md` 9장): 쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈(`src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/`, `src/app/api/dev/login/`) 밖의 `AUTH_MODE` 참조가 있으면 실패. `AUTH_MODE=mock VERCEL_ENV=production` 빌드가 실패하는지 확인하는 잡 | SM 작업 5·14·15, BS 작업 14 |
| VID-06-040 | 원본 정리 체크리스트: YSM 태그(사용자 승인 후), `.gitignore`(pyc, .venv, tsbuildinfo), 잔여물 삭제, 노출 키 재발급 목록 | `archive/README-sceneflow.md`, 루트 `.gitignore`의 해당 줄 | 없음 | P1 | S | Haiku(반복 체크) | 07장 5절 표 전 항목 완료 표시 | SM 작업 13, YSM 작업 1·2·3 |
| VID-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Primer + 보조 Atlassian, 채팅은 Astryx 패턴 확인 D-19, 랜딩은 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet(문서) | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안(Primer + shadcn/ui) 기록(01장 D-19). 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/design-module/_design-guide/REFERENCES.md:80` sceneflow 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/design-module/_design-guide/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| VID-06-042 | 디자인 시스템 2단계(컴포넌트): 036 토큰 위에서 기본 컴포넌트·배리언트(03장 3.2절 표)와 `/dev/components` 미리보기. 컴포넌트 1개 단위로 지시 | `apps/sceneflow/src/components/ui/**`, `src/app/dev/components/**`, `docs/file/03-설계/디자인/COMPONENTS.md`(초안) | 036 | P0 | M | Sonnet(컴포넌트) | 03장 3.2절 기본 컴포넌트 전부가 라이트/다크로 `/dev/components`에 보인다. 컴포넌트마다 `DESIGN_SYSTEM.md` 8장 지시 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증) 기록. hex 직접 사용 0, `tailwind.config.js` 0, 프로덕션 빌드에 `/dev/components` 미포함 | DESIGN_SYSTEM 4장 2단계 |
| VID-06-043 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | 042 | P0 | M | 사람(보조 Sonnet) | 03장 3.2절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| VID-06-044 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | 043 | P0 | S | Opus(검토·정리) | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| VID-06-045 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, video 설정(app, `VIDEO_KNOWLEDGE_ORG_ID`, 컬렉션 이름), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/video/`, `app/ai/compliance/video.py`, `app/ai/products/video/knowledge.py`, `wiki_config.py` 제외), `apps/api/tests/platform/` | 001 | P0 | M | Fable(AI 보안 경계) | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 대상 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 필수 변수 누락 시 기동 실패, `apps/api`에서 ffmpeg·whisper·demucs import 0(02장 2절 경계) | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| VID-06-046 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰·잡 토큰 발급(`/api/internal/ai-token`), 정산 크론 엔드포인트, 정밀 모드 대본 시작·재개, AI 단가, 온보딩 국외 이전 동의 | `apps/sceneflow/src/app/api/{ai,internal,onboarding}/**`, `src/app/onboarding/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` | 003, 005, 045 | P0 | L | Fable(과금·AI 보안) | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 잡 토큰은 running 잡에만(그 외 409), 동의 시 `ai_org_settings` 고지문 버전 일치, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 정밀 모드 24시간 미재개 실행 환불 | VD-F-100, 103, 108, 109 |
| VID-06-047 | RAG 색인: 운영자 컬렉션(`video-trends`, `video-guide`)과 조직 컬렉션(`video-performance`, `video-scripts`, `video-brand`), 자동 색인 잡, Dify 외부 지식 설정, 검색 평가셋 40문항 | `apps/api/app/ai/products/video/knowledge.py`, `workers/video-orchestrator/src/ai-ingest/**`, `scripts/knowledge/`, `apps/api/tests/video/retrieval/` | 015, 045, 046 | P0 | L | Opus(RAG·연동) | 재현율@8 0.8 이상(제안), 다른 조직 컬렉션 요청 42501, 외부 지식 응답에 사용자 조직 데이터 0, 컬렉션당 임베딩 모델 1종(`oss-embed`), `is_estimated` 표시 보존, 난수·더미 지표 색인 0, 조직 월 청크 상한(`AI_INDEX_LIMIT`) 동작, D-18 범위(요약 지표 + 출처) 준수 | VD-F-101 |
| VID-06-048 | 채널·브랜드 가이드 위키: 문서 업로드 → ingest(draft) → 게시·편집·이력·lint 화면과 API, 주 1회 lint 잡 | `apps/api/app/ai/products/video/wiki_config.py`, `apps/sceneflow/src/app/(dashboard)/dashboard/wiki/**`, `src/components/wiki/**`, `src/app/api/wiki/**` | 044, 047 | P0 | M | Opus(기능·연동) | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 표시가 붙은 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, lint 결과 화면 표시, 모든 쓰기 감사 1행, 다른 조직 페이지 접근 0 | VD-F-102, LLM_WIKI 3장 |
| VID-06-049 | LangGraph `video.script`(trend → plan → script → metadata → compliance)와 `video.step`(D-20), 체크포인트, 실행 기록, 규칙 파일, 오케스트레이터의 그래프 클라이언트 (2026-10-18: Track D 10섹션 대신 Track S 대본, 스토리보드 그래프는 9장 071) | `apps/api/app/ai/graphs/video_script.py`·`video_step.py`, `apps/api/app/ai/compliance/video.py`, `packages/video-rules/**`, `workers/video-orchestrator/src/steps/{script,ai-step}/**`, `apps/api/tests/video/graph/` | 016, 045, 047 | P0 | L | Opus(그래프) | 실행 1회 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 출처 없는 수치 0, 대가성 문구 모방 문장 제거와 첫 줄 비움, 걸린 부분 1회 재작성·2회 실패 시 run failed + 환불, 금지 문구 평가셋 30문항 위반 0(상용·오픈소스 경로 모두), UI 시작 정밀 모드의 interrupt 재개가 같은 thread, `video.step`의 허용 밖 kind 422 | VD-F-103, 111 |
| VID-06-050 | Dify `video-chat`(질문 분류, HTTP 노드, 외부 지식)과 `/tools/answer` video 확장(채널 코치 모드, 마스킹, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/video/`, `apps/api/tests/video/chat/` | 046, 047 | P0 | M | Opus(연동) | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `context_ref` 403, 답변 출처 1개 이상 또는 `no_source`, 평가셋 금지 문구 0·근거 없는 수치 0, DSL에 키 0 | VD-F-100, 111, 04장 6.2절 |
| VID-06-051 | 채팅 패널과 대화 목록(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 컨텍스트 칩) | `apps/sceneflow/src/components/ai-chat/**`, `src/app/(dashboard)/dashboard/chat/**` | 044, 046, 052 | P0 | M | Sonnet(UI) | 03장 3.1절 구성, 375px 전체 화면 시트, `aria-live`, 402 충전 모달, 대체·근거 없음·환불 상태 표시. 대시보드 레이아웃 장착은 028 파일에 1줄 요청 | VD-F-100, 03장 5절 |
| VID-06-052 | 음성 대화: `/api/voice/*`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기. Whisper STT 편입: 라우팅 `video.stt` 고정, 워커 사용량 기록 모듈 | `apps/sceneflow/src/app/api/voice/{consent,sessions,stt,tts}/**`, `src/components/voice/**`, `services/media-worker/handlers/usage/**` | 011, 012, 046 | P0 | M | Opus(기능·연동) | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 텍스트만, 파이프라인 STT 호출 100%가 `ai_usage` stt 행(provider `oss-voice`, feature `video.stt`)을 남기고 원본 오디오가 국외 제공자로 가는 경로 0 | VD-F-104, 105 |
| VID-06-053 | 제품 음성 기능: 오픈소스 TTS 내레이션 선택(`voice.provider`), 같은 목소리 규칙, 샘플 듣기, 받아쓰기, 엔진 선택 UI (2026-10-18: 섹션 재생성 기준은 9장 072 장면 내레이션 다시 만들기로 바뀜) | `workers/video-orchestrator/src/steps/tts/**`, `apps/sceneflow/src/app/api/voice/sample/**`, `src/components/voice-engine/**` | 016, 046, 052 | P0 | L | Opus(기능·연동) | 한 언어판 `voice_jobs`의 provider·voice_id 동일·`fallback_from` null, 3구간 중 2구간째 강제 실패 시 산출물 0 + 그 언어분 환불 1행, 샘플 제공자 = 본 작업 제공자, 미동의 조직의 ElevenLabs 선택지 없음, 재생성 섹션 보이스 불일치 422 `VD013`, 롱폼 섹션 재생성이 첫 섹션 기준을 따름, 받아쓰기 60초·원본 미저장 | VD-F-106, 107 |
| VID-06-054 | 3D 히어로: 영상 타일 파이프라인(PC·태블릿), 한 줄 흐름(모바일), 정지 이미지 대체, 성능 예산 | `apps/sceneflow/src/components/hero3d/`, `apps/sceneflow/public/hero/` | 044 | P0 | L | Sonnet(UI·3D) | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 3D 안 글자·숫자 0, 보라 글로우·네온 그리드 0 | VD-F-110, 03장 4.5절 |
| VID-06-055 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 강제 오픈소스, 선차감·정산·환불, 라우팅 seed 스냅샷, 내레이션 대체 금지, 파이프라인 STT 국외 호출 0) | `apps/api/tests/video/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | 046, 049, 050, 052, 053 | P0 | M | Fable(AI 보안) | `resolve_ai_route` 스냅샷(17행 x 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, 내레이션 구간 강제 실패 시 대체 호출 0, 원장 drift 0, `uploads_disclosure_check` 우회 시도 실패, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |
| VID-06-056 | 대본 기획 미리보기 UI: 기획안 3안 비교 표, 근거 칩, 추정 배지, 선택·수정, `script_run_id`를 생산 요청으로 전달 (2026-10-18: 030 대신 9장 078 새로 만들기에 장착) | `apps/sceneflow/src/components/script-plan/**` | 029, 030, 049 | P0 | M | Sonnet(UI) | 03장 3.1절 구성, 근거 없는 수치 표시 0, 402·`VD009`·`VD010` 안내, 24시간 만료 안내. 숏폼 생성·롱폼 화면 장착은 029·030 파일에 1줄 요청 | VD-F-103, 03장 2.10절 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 040, 041 | 3 | 없음 | DB 적용(AI 기본값 포함), 타입, 원본 정리, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 011, 039, 045 | 5 | 001 | RLS 테스트, 앱 골격, 미디어 워커 골격, CI, AI 서비스 설치 |
| W1-D | 036 → 042 → 043 → 044(직렬) | 1 | 003, 041 | 디자인 시스템 2~4단계(토큰, 기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 008, 012, 013, 014, 022, 025 | 7 | W1 | 과금 래퍼, 채널, 미디어 핸들러, 제휴, 웹훅 |
| W3 | 004, 006, 009, 015, 023, 028, 046, 054 | 8 | W2, 화면은 044 | 인증 화면, 결제, YouTube 업로더, 오케스트레이터, 공개 페이지, 셸, AI 게이트, 3D 히어로 |
| W4 | 007, 010, 016, 017, 018, 019, 020, 027, 035, 047, 052 | 11 | 006, 015, 046 | 결제 E2E, 생산 API 전부, 스케줄러, 랜딩, RAG 색인, 음성 대화·STT 편입(2026-10-18: 018은 9장으로 대체, 019·020은 Phase 2. 병렬 수는 이전 값) |
| W5 | 021, 024, 026, 029, 030, 031, 048, 049, 050, 051, 053 | 11 | W4 | 업로드 API, 레이더, 분석, 화면, 위키, 대본 그래프, Dify 채팅, 채팅 패널, 제품 음성 기능(2026-10-18: 030은 9장으로 대체, 031은 Phase 2. 병렬 수는 이전 값) |
| W6 | 032, 033, 034, 037, 056 | 5 | 021, 024, 049 | 업로드·수익화·레이더 화면, 통합 테스트, 대본 기획 UI |
| W7 | 063(G1 통과 후 먼저), 038, 055 | 1 + 2 | W6. 063은 G1 통과(`[DECISION] G1 통과`) 후 시작하고 038·055의 공개 베타 마무리 재실행은 063 완료를 기다린다. G1 근거인 Mock 핵심 플로우는 038이 W6 종료 직후 로컬에서 먼저 녹색으로 만든다(8.2절) | 인증 Stage B(Google + 이메일), 사용자 플로우 E2E, AI 보안 회귀. MVP 출시(공개 베타) 조건(2026-10-18: 9.2절 S8과 10.2절 E7 완료 뒤 시작) |
| W8(2026-10-13 추가) | 057, 058, 059, 060 → 061, 062, 064·065(G2 통과 후) | 4 → 2, 인증 2 | W7(057은 009, 059는 blog 브랜드커넥트 어댑터, 064·065는 G2 통과 `[DECISION] G2 통과`, 둘은 병렬 가능) | 네이버 클립 업로더·동의, 브랜드커넥트 클립, 대행 고객·승인·리포트, 인증 Stage C(카카오 C1, 네이버 C2). 002에 클립·대행 33항목 편입 |

034(레이더·분석·크레딧·결제 화면)는 선행 024와 같은 웨이브에 있던 것을 W6으로 옮겼다(2026-10-13 정리).

P0 작업과 테스트 작업 대응: DB·권한(001, 003, 005, 008) → 002 / 결제(006) → 007 / 워커·생산·업로드(009, 011~021, 025, 027) → 037 / 화면·공개 페이지(023, 028~036, 042, 054, 056) → 038 / 인증 Stage A(004) → 038(Mock storageState)·002(`outsider`)·039(금지 문자열·배포 빌드 검사) / 인증 Stage B(063) → 콜백 단위 테스트(B-2, B-3)·배포 빌드 검사(B-4)·038 재실행(B-5)·Google 실로그인 수동 점검표 / AI·음성(045~053) → 055 / 디자인 시스템(041~044)은 043(사람 검토) / 039는 전체 게이트. (2026-10-18: 9장 작업 대응은 9.2절, 10장은 10.2절)

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 19 | 17.8% | 39/217 = 18.0% |
| Opus | 57 | 53.3% | 123/217 = 56.7% |
| Sonnet | 26 | 24.3% | 50/217 = 23.0% |
| Haiku | 5 | 4.7% | 5/217 = 2.3% |

2026-10-18 10장 추가 뒤 비율은 MVP 계획의 모델 작업 107개 기준이다(10.5절: 78개 + 10장 30개 − 흡수 082). 그 직전 78개 기준 값은 Fable 16(20.5%), Opus 39(50.0%), Sonnet 19(24.4%), Haiku 4(5.1%), 규모 가중 33·85·37·4 / 159였다. 78개 기준의 셈법(9.5절: 64개 + 9장 19개 − 대체 018·030 − Phase 2 019·020·031). 그 직전 64개 기준 값은 Fable 12(18.8%), Opus 33(51.6%), Sonnet 16(25.0%), Haiku 3(4.7%), 규모 가중 27·68·31·3 / 129였다. 64개 기준의 셈법(2026-10-14: 2절 모델 작업 61개(2절 62행 중 사람 작업 043 제외) + 8절 인증 3개, 060의 "Sonnet(UI) + Opus"는 앞의 Sonnet으로 셈, 004는 Sonnet S → Opus M). 사람 작업 1개(VID-06-043, M)는 비율에서 뺐다. 2026-10-14 직전 표는 W8 작업 6개(057~062)가 빠진 55개 기준(Fable 16.4%, Opus 50.9%, Sonnet 27.3%, Haiku 5.5%)이었고, 61개로 다시 세면 Fable 10(16.4%), Opus 31(50.8%), Sonnet 17(27.9%), Haiku 3(4.9%), 규모 가중 23·65·32·3 / 123이었다(8.5절). 2026-10-13 이전(40개)은 Fable 15.0%, Opus 52.5%, Sonnet 25.0%, Haiku 7.5%였다.

Fable은 데이터 모델, RLS, 결제, 크레딧 차감 경로, OAuth에 더해 AI 보안 경계(서명 토큰 검증 045, AI 게이트의 선차감·정산·동의 046, AI 회귀 055)와 인증 단계의 세션 발급 경계(Stage B 063, Stage C2 네이버 065)를 맡는다. Stage A(004)와 C1 카카오(064)는 Opus다. 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 패널·대본 기획 UI·3D 히어로·디자인 시스템 컴포넌트는 Sonnet이다(`docs/products/_platform-core/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

| 리뷰 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| SM 1 | 크레딧 RPC 봉쇄 | 코어 0003 + 002 |
| SM 2 | 결제 경로 단일화 | 006, 007 |
| SM 3 | 서비스 클라이언트, `x-internal-call` 제거 | 003, 015, 027 |
| SM 4 | 인증 가드, Mock 로그인, OAuth state, 키 폴백 | 003, 004, 008 |
| SM 5 | 빌드 복구, params Promise, landing views RPC | 039, 023 |
| SM 6 | 제품 경계, 스키마 org 통일, 플랜 단일 소스 | 001(+ 확정 결정 1, 8) |
| SM 7 | FlowProducer 파이프라인, 워커 분리, Python 큐 분리 | 015, 011 |
| SM 8 | zod 검증, `getCurrentOrg` | 003 |
| SM 9 | 대시보드 실데이터, 플레이보드 난수 제거 | 028, 024 |
| SM 10 | AI 클라이언트 단일화, env 검증 | 003, 016 |
| SM 11 | reactflow-executor 수정, DistroKid/자동화 콜백 서명 | 025(서명 골격), 캔버스 실행은 Phase 2(automation-core) |
| SM 12 | YouTube 스트리밍 업로드, Redis lazy | 009, 003 |
| SM 13 | 루트 문서 정리 | 040(이 기획 폴더가 정본 문서를 대체) |
| SM 14 | 로깅, sanitize | 039 |
| SM 15 | 통합 테스트·CI | 002, 039 |
| BS 1 | RLS 재작성 | 001, 002 |
| BS 2 | 크레딧 RPC 재설계 | 코어 0003 + 005 |
| BS 3 | 결제 재설계 | 006 |
| BS 4 | 가입 트리거 | 코어 0001 + 004 |
| BS 5 | 미들웨어 `/landing` 예외 | 003, 023 |
| BS 6 | Make 웹훅 HMAC | 025 |
| BS 7 | org-context 헬퍼 + zod | 003 |
| BS 8 | YouTube OAuth state, 토큰 암호화 | 008 |
| BS 9 | 워커 런타임 분리 | 015, 011 |
| BS 10 | 목업 제거 | 024, 018 |
| BS 11 | 스키마 정합성, fal 오류 throw | 001, 016 |
| BS 12 | yt-dlp `--`, URL 화이트리스트 | 014 |
| BS 13 | env 정리 | 003 |
| BS 14 | 타입 생성, any 제거, sections 부분 갱신 | 001, 039 |
| BS 15 | 색상 토큰화 | 036 |
| YSM 1 | 삭제 경위 확인, 아카이브 태그 | 040 |
| YSM 2 | `.gitignore`, 잔여물 삭제 | 040 |
| YSM 3 | 키 점검·교체 | 040 |
| YSM 4 | OAuth state 재구현 | 코어 0004 + 008 |
| YSM 5 | 네이버 로그인 naver_id 매핑 | 004(Stage A에서 네이버 로그인 없음 확인) → 065(Stage C2, G2 후, 이메일 자동 병합 금지) + 6절·8.3절 코어 요청 |
| YSM 6 | 태스크 소유권 검증 | 002, 017 |
| YSM 7 | 모델 허용 목록, LLM 단일화 | 016 |
| YSM 8 | 인증 의존성 블로킹 제거 | 011(FastAPI 폐기, Python은 service_role 워커만) |
| YSM 9 | role/plan 이중 권한 통합 | 003(`session_context` 단일 출처) |
| YSM 10 | CORS, 오류 원문 노출 | 008, 003 |
| YSM 11 | 하위 프로세스 타임아웃, STT Lock | 011, 012 |
| YSM 12 | 모듈 이식 설계 | 011, 012, 013, 014 |
| YSM 13 | account_manager 분할 | 008(코어 vault 사용, 암호화 방식만 참고) |
| YSM 14 | 대형 페이지 분할 | 032 |
| YSM 15 | pytest 기본 세트 | 011, 037 |

AI·음성·3D·디자인 시스템 작업(041~056)은 리뷰 작업이 아니라 확정 결정 13~17에서 온 신규 작업이라 위 표에 행이 없다. 2026-10-18 스토리보드 작업(066~084)도 같다(9장). 리뷰 작업 수 = 흡수표 행 수 규칙(`DOC_TEMPLATE.md` 3절)은 그대로 유지된다(40행 → 변경 없음).

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 |
|---|---|---|
| 모듈러 `seed.sql`에 video `adv_pack_*` 4행 추가 | `_supabase-modular/seed.sql` | Advanced 30% 할인(PRD_pricing.md:149-154, 2026-10-14 20%로 변경, 01장 4절). 모놀리스 seed에는 반영함. 해결(2026-10-13 코어 반영 완료): 모듈러 seed에도 추가됨 |
| `affiliate_disclosures.placement`에 `landing`(랜딩·링크인바이오) 추가 검토 | 0006 | 현재 `video_description` 문구 재사용 |
| `storage` 대용량 미디어 버킷을 코어 표준으로 정의할지 결정 | 0005 | 제품 조각이 `video-media`(5GB, 서버 쓰기만)를 만든다 |
| `confirm_payment_order` 금액 불일치 시 failed 기록(롤백되지 않게) | 0003 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 이를 별도 호출하고 운영 알림·취소 |
| `adjust_credits`(환불 시 팩 크레딧 음수 조정) | 0003 | CORE_SPEC 5.4 제안과 같음 |
| 네이버 로그인(결정 22로 Stage C2, VID-06-065): 로그인 상태에서만 identity 연결, 이메일 자동 병합 금지. 브리지 경로 채택 시 코어 `staged/0010_core_auth_identity_links.sql` 적용(8.3절 R-V11) | core auth | YSM #3, `AUTH_ROADMAP.md` 7.2.3절 |
| features 키 `max_concurrent_productions` 추가 | seed | 현재 서버 상수(01장 5절) |
| automation-core 캔버스 실행 엔진(Phase 2) | packages/automation-core | `video.workflows` 저장만 MVP |
| 브랜드커넥트 범용화(`target_url`, `target_kind`, `source_app`, 9인자 RPC, `brandconnect.apply` payload `source_app`) | 0006, CORE_SPEC 13장 | 해결(2026-10-13 코어 반영): video 클립 캠페인 지원(VD-F-063) |
| `injectDisclosure` 대상 `title_hashtag`(제목 앞 + 첫 해시태그) | SHARED_MODULES 17장 | 해결(2026-10-13 코어 반영): 네이버 클립은 고정 댓글이 없다 |
| sns-uploader `naver_clip`(Platform 타입, `capabilities`, 잡 `upload.naver_clip`, `naver-login.ts` 재사용) | SHARED_MODULES 11장 | 해결(2026-10-13 코어 반영). 구현은 video(VID-06-057) |
| 공용 메일 발송(승인 요청·리포트) 템플릿 등록 | core 메일 모듈 | 고객 승인 링크(VD-F-123). 그때까지 링크 복사 경로 |

AI·음성 요청(2026-10-13, 01장 D-13~D-22와 연결):

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 |
|---|---|---|---|---|
| R-V1 | `_supabase-modular/seed.sql` | video 플랜 4행 `features`에 `ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `ai_script` 추가 | seed가 1200보다 나중에 실행되면 11.2절 병합 UPDATE가 덮어써진다 | 서버가 누락 키를 기본값으로 읽는다(01장 4장 키 표) |
| R-V2 | `_supabase-modular/seed.sql` 제공자 | `openai` 제공자 kinds에 `tts` 추가(01장 D-14 (b)) | 기존 OpenAI TTS-1-HD 백업을 체인에 유지하려면 필요 | D-14 (a): OpenAI TTS 백업 제거, 체인 `elevenlabs → oss-voice` |
| R-V3 | ai_providers | DeepL, fal, Suno를 제공자 레지스트리에 편입(국외 이전 필터 적용, 01장 D-21) | 코어 라우팅 밖 외부 서비스의 국외 동의 연동 | 온보딩 화면의 별도 고지 항목과 기능 비활성 |
| R-V4 | ai-service | 서명 토큰 기반 단일 LLM 호출 엔드포인트(feature 키로 라우팅) 추가(01장 D-20 (b)) | 파이프라인 TS 단계의 LLM 호출 경로 | 1노드 그래프 `video.step`(049) |
| R-V5 | AI_ARCHITECTURE, ai-gateway | TS 워커가 그래프·음성 서버를 호출할 때 쓰는 잡 토큰 발급 규칙(Next.js `/api/internal/ai-token`, 워커 키 + running 잡 확인, org·sub는 잡 행에서) 표준화. `docs/products/astro-ai/06_AGENT_PLAN.md` 6절 R-8과 같은 요청 | 개인키는 Next.js에만 둔다는 규칙과 워커 기반 생성이 함께 필요 | video 제품 엔드포인트로 구현(04장 2.1절) |
| R-V6 | core-voice, VOICE_ARCHITECTURE | (a) TS 서버 워커(오케스트레이터)에서 ElevenLabs SDK 호출 허용 확인(01장 D-22) (b) 기능별 대체 금지 옵션(`feature='narration'`)과 "시작 제공자 고정" 동작을 `VoiceAdapter` 계약에 명시(astro R-11과 같음) | 롱폼 내레이션이 요청-응답 시간 안에 끝나지 않는다. 대체 금지를 코드 계약으로 강제 | 내레이션 단계가 체인 첫 가용 제공자 하나만 넘겨 호출 |
| R-V7 | 공용 Dify | `video-chat` 앱 생성, 내부 키 환경 변수, 외부 지식 `video-guide`·`video-trends` 등록, 로그 보존 30일 | 공용 인프라는 코어 소유 | 없음(필수). 장애 시 `/tools/answer-direct` |
| R-V8 | `_design-guide` 3D 키트 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/design-module/_design-guide/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| R-V9 | ai-service | (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | Dify 보조 노드 라우팅(`dify.aux`, `wiki.query`)과 위키 편집 | (a) Dify에 기능별 모델 이름을 따로 등록 (b) video 확장(`app/ai/products/video/wiki_config.py`)에 임시 구현 |
| R-V10 | 공용 음성 서버 | KO/JA/EN TTS 평가 문장 세트와 품질 판정 결과 공유, STT 요청 한도(10분·50MB) 상향 가능 여부(01장 D-13, D-15) | 오픈소스 내레이션의 언어 범위 결정, 파이프라인 STT 일원화 재검토 | 오픈소스 선택지는 검증 통과 언어만 노출, 파이프라인 STT는 미디어 워커 유지 |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `pnpm -F sceneflow build`, `tsc --noEmit`, `eslint` 오류 0 |
| Python | `pytest services/media-worker` 통과 |
| SQL | `node check.mjs mod ... 0000~0007 seed 1200_video.sql` OK, `node check.mjs mono ...` OK |
| RLS 스모크 | VID-06-002 전 항목 통과(현재 기획 단계 65/65) |
| 결제 E2E | VID-06-007 통과 |
| 파이프라인 | VID-06-037 Track A~F 통과, 원장 drift 0(2026-10-18: 037은 Track A·B, Track S는 083, E·F는 Phase 2) |
| 사용자 플로우 | VID-06-038 통과(AI 플로우 3개 포함, Mock 페르소나 storageState), DESIGN_PRINCIPLES 7단계 체크리스트. 공개 베타 전 인증 Stage B: VID-06-063 수용 기준 B-1~B-6 통과(B-5 Google 실로그인 수동 점검표를 task `log.md`에 기록) |
| AI·음성 | `pytest apps/api` 통과, VID-06-055 녹색, 금지 문구 평가셋 30문항(대본 그래프)·채팅 평가셋 30문항 위반 0, RAG 평가셋 40문항 재현율 기준 충족, 같은 목소리 강제 실패 테스트 통과, 파이프라인 STT 국외 제공자 호출 0 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준(VID-06-054), 디자인 시스템 4단계(VID-06-044) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | 2절 62개 + 8절 인증 3개 + 9장 19개 = 84개 중 MVP 계획 79개의 P0 66개 전부 완료(2026-10-18: Phase 2 019·020·031과 대체된 018·030 제외, 9.5절. 10장 추가 뒤에는 114개 중 MVP 계획 108개의 P0 88개, 흡수된 082 제외, 10.5절. 사람 작업 043 포함, P1·P2 작업은 기존 규칙대로 출시 후 가능, 인증 C1·C2 064·065는 G2 후), 리뷰 "높음" 26건 차단 설계 구현 확인 |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 9장(작업 계획 반영 규칙)과 8장 sceneflow 행(open, 크리에이터, A 추가 페르소나 "Advanced 팀 멤버", B Google + 이메일, C1 P1, C2 P1)이다. Stage A는 기존 VID-06-004가 맡는다(2절 행에서 범위 변경). 아래 3개가 새 작업이다. ID는 2절 최대 번호 VID-06-062 다음부터다(2절 표는 번호 순이 아니라 W8 작업 057~062가 010 뒤에 있다).

여기서 말하는 로그인은 사용자 계정 로그인이다. 채널 연결 OAuth(VID-06-008, `core.oauth_states`)와 네이버 클립 업로드용 브라우저 로그인 세션(VID-06-057, Playwright)은 이 작업들의 범위가 아니며 서로 코드를 import하지 않는다(07장 6절).

### 8.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| VID-06-063 | 인증 Stage B: Google OAuth 전환 + 이메일 가입·메일 인증·비밀번호 재설정 화면, `/auth/callback`(`finishLogin` 3.2절 전체), OAuth 첫 로그인 약관 동의(온보딩 첫 단계, 03장 7.3절), 배포 env(`AUTH_MODE=live`, `AUTH_PROVIDERS=google,email`)와 배포 체크리스트(Google 콘솔·Supabase Providers·Redirect URLs), 로그인용 Google 클라이언트와 채널용 YouTube 클라이언트 분리(01장 D-29) | `src/app/(auth)/**`(004에서 이어 받음: login B 구성, signup, reset-password, verify), `src/components/auth/**`(004에서 이어 받음: Google 버튼, 이메일 폼), `src/app/auth/callback/**`, `src/lib/auth/**`(제공자 목록, `finishLogin` 완성), `src/app/onboarding/terms/**`, `src/app/api/onboarding/terms/**`(046 소유 `onboarding` 중 `terms/` 하위만), `docs/sceneflow/ops/auth-checklist.md`(제안). `supabase/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`는 001 소유 파일에 요청, `/onboarding/terms` → `/onboarding/ai` 순서 연결은 046 파일에, `proxy.ts` 공개 경로 `/auth/callback`은 003 파일에 1줄 요청 | 004, 008, 046, 038(Mock 녹색), 진입 조건 G1(`[DECISION] G1 통과`) | P0 | M | Fable(세션 발급·권한 경계) | `AUTH_ROADMAP.md` 5.3절 그대로: B-1 새 Google 계정 첫 로그인 → `session_context('video')`가 `entitled=true`, `plan_code=starter`, 가입 크레딧 100이 1회만 지급(재로그인 3회 뒤에도 원장 행 수 같음). B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → `/dashboard`. B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 서버 오류 로그에 토큰·코드 없음. B-4 배포 빌드(`VERCEL_ENV=production`)에서 `/api/dev/login` 404, 로그인 화면에 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(038) 계속 녹색, Google 실로그인은 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인하고 task `log.md`에 기록. B-6 운영 대시보드 Google 설정, Redirect URLs, `AUTH_PROVIDERS` 값이 배포 체크리스트와 일치. video 추가: 같은 이메일의 이메일 가입자가 Google로 로그인하면 같은 `user_id`이고 가입 원장 추가 0, OAuth 첫 로그인은 약관 동의 → `/onboarding/ai` → `/dashboard`, 이메일 가입자는 약관 단계 생략, 채널 연결 OAuth(008) 회귀 테스트 녹색(로그인 클라이언트 변경이 채널 연결에 영향 없음) | `AUTH_ROADMAP.md` 5장, 9장, 01장 VD-F-001·D-28·D-29 |
| VID-06-064 | 인증 Stage C1: 카카오 로그인(Supabase 기본 제공자 `kakao`), 카카오 버튼, 설정 → 로그인 방법(연결·해제, 03장 7.4절) | `src/lib/auth/providers/kakao.ts`(제안), `src/components/auth/`의 카카오 버튼(063 완료 후 이어 받음), `src/app/(dashboard)/dashboard/settings/login-methods/**`(034 소유 `settings/` 중 `login-methods/` 하위만. 설정 메뉴 링크 1줄은 034 파일에 요청). `supabase/config.toml`의 `[auth.external.kakao]`와 `[auth] enable_manual_linking`은 001 소유 파일에 요청 | 063, 진입 조건 G2(`[DECISION] G2 통과`), 01장 D-26 확정 | P1 | S | Opus | `AUTH_ROADMAP.md` 7.1.3절 그대로: C1-1 새 카카오 계정 첫 로그인 → B-1과 같은 결과(엔타이틀먼트·크레딧 1회). C1-2 비즈 앱(a)이면 Google로 가입한 같은 이메일 사용자가 카카오로 로그인 → 같은 `user_id`(Supabase 자동 연결은 제공자가 이메일 인증을 확인한 경우에만, 미확인이면 수동 연결 7.3절). C1-3 (b)면 이메일 없는 사용자가 결제(VD-F-090) 전 연락 이메일 입력 화면을 본다. C1-4 표시 이름은 카카오 닉네임, 없으면 `user` 규칙. C1-5 카카오 버튼은 카카오 디자인 가이드의 색·문구(미확인: 최신판 확인 후 반영). 로그인 방법 화면: 마지막 수단 해제 불가, 감사 `auth.identity_link`·`auth.identity_unlink` | `AUTH_ROADMAP.md` 7.1절, 7.3절, 8장 |
| VID-06-065 | 인증 Stage C2: 네이버 로그인(스파이크 0.5일 → `custom:naver` 또는 서버 브리지), 네이버 버튼, 로그인 방법 화면의 네이버 행, 네이버 검수 자료 | `src/lib/auth/providers/naver.ts`(제안), `scripts/auth/register-naver-provider.mjs`(제안), 브리지 경로일 때만 `src/app/auth/naver/**`(start, callback), `docs/sceneflow/ops/naver-review/`(검수 캡처, 제안). 로그인 방법 화면의 네이버 행은 064 파일에 요청 | 063(064와 병렬 가능, 로그인 방법 화면 행은 064 완료 후), 진입 조건 G2, 브리지면 8.3절 R-V11 적용 후 | P1 | M | Fable(브리지는 세션 발급 경로) | `AUTH_ROADMAP.md` 7.2.4절 그대로: C2-1 스파이크 결과가 `[DECISION]`으로 기록되고 `NAVER_AUTH_PATH`가 그 값이다(01장 D-27). C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 결과. C2-3 같은 네이버 계정 재로그인 5회 → 같은 `user_id`, 사용자 수 증가 0. C2-4 (브리지) state 변조·재사용·쿠키 없음 → 거부, 세션 미생성. 다른 브라우저에서 받은 콜백 URL 재생 → 거부. C2-5 (브리지) 같은 이메일의 Google 가입자가 네이버로 처음 로그인 → `email_in_use` 안내, 새 사용자 0. C2-6 네이버 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않는다. video 추가: 네이버 클립 채널 연결(057)의 `CredentialVault`(provider `naver`) 행과 로그인 identity가 섞이지 않는다(같은 네이버 계정으로 로그인과 클립 연결을 모두 해도 `channels`·`encrypted_credentials` 행 수 변화 없음), `naver-login.ts`를 import하지 않음 | `AUTH_ROADMAP.md` 7.2절, 8장, 01장 D-5 해소 |

### 8.2 게이트와 웨이브

| 게이트·웨이브 | 작업 | 진입 조건 | 판정 |
|---|---|---|---|
| Stage A | VID-06-004(W3, 2절 범위 변경) | 003, 044. 004보다 앞 웨이브(W0~W2, W1-D)의 작업은 시드 스크립트 없이 SQL·단위 테스트(002의 PGlite·로컬 Supabase 스모크)로 검증한다. W4 이후 화면·API 작업은 Mock 페르소나로 로그인해 개발한다 | - |
| G1 | - | `AUTH_ROADMAP.md` 4장. video 기준: (1) 2절 MVP P0 기능 작업 완료(인증 B·C 작업과 공개 베타 직전 통합 작업 038·055 제외), (2) 핵심 플로우 E2E(038)가 Mock 페르소나 storageState로 로컬 녹색, (3) RLS 스모크(002) 전 항목 + `outsider` 교차 테넌트 거부, (4) 결제 E2E(007, Toss 테스트 키) 녹색, (5) 단계 분기 코드가 인증 모듈 밖 0건(039 CI), (6) Google Cloud 프로젝트·OAuth 동의 화면(앱 이름, 지원 이메일, 로고, 개인정보처리방침·이용약관 URL, 승인된 도메인)·로그인용 웹 클라이언트 ID·운영 Supabase 프로젝트 준비(`AUTH_ROADMAP.md` 5.1절) | 사람(대표님)이 task `log.md`에 `[DECISION] G1 통과`. 2026-10-18: (1)에 9장 P0 18개, (2)에 084, 파이프라인 083 녹색을 더한다(9.2절). 10장: (1)에 P0 22개, (2)에 106, 파이프라인 105 녹색(10.2절) |
| Stage B | VID-06-063 | W7의 맨 앞(마지막 기능 웨이브 W6 다음, 공개 베타 직전 통합·E2E 웨이브). 038·055의 공개 베타 마무리 재실행은 063 완료를 기다린다 | - |
| G2 | - | `AUTH_ROADMAP.md` 6장: Google 실로그인 공개 베타 운영 2주(제안), 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안), open 앱 신규 가입자 중 `entitled=false` 0, 카카오 디벨로퍼스 앱·비즈 앱 전환(01장 D-26), 네이버 애플리케이션 등록·검수 자료 준비·C2 스파이크 결과 기록 | 사람이 `[DECISION] G2 통과` |
| Stage C | VID-06-064, VID-06-065 | W8(MVP 출시 후 웨이브), G2 통과 후. 064·065 병렬 가능. 네이버 검수 기간 때문에 065의 신청 자료 준비는 G2 직후 시작 | - |

### 8.3 코어 요청 (6절 표에 이어서)

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 |
|---|---|---|---|---|
| R-V11 | `_platform-core` | C2 스파이크가 실패해 브리지 경로를 택하면 `docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`(`core.auth_identity_links`) 적용. 코어는 한 번만 적용하고 모든 제품이 쓴다 | 브리지 로그인은 네이버 고유 id로 사용자를 찾는다. `core.oauth_states`는 로그인 전 사용자·조직이 없어 브리지 state에 쓸 수 없다(`AUTH_ROADMAP.md` 7.2.3절) | `custom:naver` 스파이크가 통과하면 요청하지 않는다 |

### 8.4 기존 문서와 달라진 점

| 항목 | 이전 | 지금 | 반영 |
|---|---|---|---|
| VID-06-004 범위·모델 | 로그인·가입·온보딩 화면, Sonnet(UI) S, 수용 기준 "Mock 로그인 없음" | Stage A(인증 모듈 경계, Mock 로그인, 시드, 가드, `finishLogin`), Opus M. "Mock 로그인 없음"은 "쿠키 역할 Mock 금지, 로컬 시드 계정만"으로 바뀜. 이메일 가입·재설정 화면은 063 | 2절 004 행, 01장 VD-F-002 |
| 004의 Stage A 시점 | W3(디자인 시스템 044 뒤) | 그대로 W3. 004가 디자인 시스템 4단계(사람 검토 043 포함) 뒤라서 Mock 로그인이 W3까지 늦다. W1~W2 API 작업은 SQL·단위 테스트로 검증하고, 일찍 Mock이 필요하면 004의 비화면 부분(`src/lib/auth/`, `/api/dev/login`, 시드 스크립트)을 044 전에 먼저 끝내고 패널만 044 뒤에 붙이는 분할을 제안한다(사용자 결정 필요) | 이 표 |
| `src/lib/` 소유 | 003 단독 | `src/lib/auth/**`는 004 → 063 → 064·065 순서(직렬, 064·065가 병렬이면 `providers/kakao.ts`·`providers/naver.ts`로 파일을 나눈다) | 1절 공용 파일 행 |
| `src/app/onboarding/` 소유 | 046 단독 | `terms/` 하위만 063 | 8.1절 063 행 |
| `src/app/(auth)/`·`src/components/auth/` 소유 | 004 단독 | 004(A 구성) → 063(B, 이어 받음) → 064(카카오 버튼, 063 완료 후). 065는 064 파일에 요청(직렬이라 동시 쓰기 없음) | 2절 004 행, 8.1절 |
| `dashboard/settings/` 소유 | 034 단독 | `login-methods/` 하위만 064 | 8.1절 064 행 |
| `proxy.ts` 공개 경로 | VD-F-002 목록(고객 승인 `/review/**` 누락) | `/login`·`/api/dev/login`(004), `/auth/callback`(063), `/review/**`·`/api/review/**`(061)을 각 작업이 003 파일에 1줄 요청 | 01장 VD-F-002, 2절 004·061 행, 8.1절 063 행 |
| 01장 D-5 네이버 로그인 | 열린 결정, MVP 제외 → Phase 2 | 결정 22로 C2 확정(065). 카카오 이메일 D-26, 네이버 경로 D-27, 이메일 가입 유지 D-28, 로그인/채널 Google 클라이언트 분리 D-29를 01장 8.1절에 새로 둠 | 01장 8절 D-5 행, 8.1절 |
| 038 수용 기준 | E2E 로그인 방식 미정 | Mock 페르소나 storageState(`owner`, `adv_owner`, `viewer`, `outsider`), 063 후 재실행 | 2절 038 행 |
| 039 수용 기준 | "Mock 로그인" 금지 검사는 없었다(07장·CLAUDE.md 금지 패턴에만 있음) | `AUTH_ROADMAP.md` 9장 CI 금지 문자열 + 배포 빌드 검사 | 2절 039 행, CLAUDE.md 인증 단계 절 |
| 작업 수 | 2절 62개(4절 비율은 55개 기준으로 W8 6개 미반영, 7절 "56개"도 W8 미반영) | 65개(모델 작업 64, 사람 1). 4절 비율과 7절 작업 수를 함께 고쳤다 | 1행 머리말, 4절, 7절 |

### 8.5 모델 비율 변화

| 모델 | 이전(2절 61개 모델 작업 다시 셈) | 지금(64개) | 규모 가중 이전 → 지금 |
|---|---|---|---|
| Fable | 10(16.4%) | 12(18.8%) | 23/123(18.7%) → 27/129(20.9%) |
| Opus | 31(50.8%) | 33(51.6%) | 65/123(52.8%) → 68/129(52.7%) |
| Sonnet | 17(27.9%) | 16(25.0%) | 32/123(26.0%) → 31/129(24.0%) |
| Haiku | 3(4.9%) | 3(4.7%) | 3/123(2.4%) → 3/129(2.3%) |

변화 요인: 신규 063(Fable M), 064(Opus S), 065(Fable M), 기존 004 Sonnet S → Opus M.

## 9. 스토리보드 트랙 작업 (2026-10-18 추가, 스토리보드 디벨롭)

정본은 01장 10장(확정 SF-1~SF-4, 10.2절 VD-F-130~142, 10.4절 단가, 10.7절 D-30~D-34)이다. 화면은 03장 8장, API·잡은 04장 9장, 테이블·RPC·오류 코드는 05장 11장(모두 2026-10-18 새 장)을 따른다. 새 작업은 19개(VID-06-066~084)이고 ID는 8절 최대 번호 065 다음부터다. 기존 작업 행은 지우지 않고 범위가 바뀐 행에만 같은 줄로 "(2026-10-18: ...)"를 달았다(9.4절). 모델 배분은 머리말 원칙을 따른다: Fable(데이터 모델, RLS, 과금·권한), Opus(기능 구현, API 연동, 그래프, 테스트 설계), Sonnet(UI, 문서), Haiku(문구, 반복 작업).

| 경로 기준 | 내용 |
|---|---|
| 화면 | `src/app/(dashboard)/dashboard/storyboards/**`(03장 8.1절: `/dashboard/storyboards`, `/dashboard/storyboards/new`, `/dashboard/storyboards/[id]`, `/dashboard/storyboards/[id]/render`). 명세의 `/app/storyboards/**`는 1절 경로 규칙에 맞춰 `/dashboard/storyboards/**`로 둔다 |
| 컴포넌트 | `src/components/storyboard/<영역>/**` |
| API | `src/app/api/storyboards/**`, `src/app/api/scenes/**` |
| 서버 도메인 | `src/server/storyboards/<영역>/**` |
| 워커 | `workers/video-orchestrator/src/storyboard/<영역>/**`, `services/media-worker/handlers/ffmpeg/storyboard/**` |
| AI 서비스 | `apps/api/app/ai/graphs/video_storyboard.py`, `video_shorts_pick.py` |
| 스키마 | 1절 규칙 그대로 VID-06-001 소유 파일에 들어간다. 001 담당(Fable)이 001 완료 뒤 066으로 이어서 수행한다(CLAUDE.md 스토리보드 규칙 "스키마 변경은 VID-06-001에 요청") |

렌더는 FFmpeg 하나다(VD-F-033, SF-2). 이 장의 어떤 작업도 Remotion·CapCut 패키지를 설치하거나 import하지 않는다.

### 9.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| VID-06-066 | 스토리보드 스키마(05장 11장): 새 테이블 6개(`storyboard_templates`, `storyboards`, `scenes`, `scene_assets`, `storyboard_cuts`, `storyboard_snapshots`), `outputs.storyboard_cut_id` FK("정확히 하나" CHECK 포함), 사용자 RPC 5개(`save_scene`, `reorder_scenes`, `add_scene`, `delete_scene`, `set_shorts_candidate`)와 서버 RPC 3개(`apply_storyboard_result`, `finish_scene_asset`, `snapshot_storyboard`), 오류 코드 `VD017`~`VD021`·`VD409`, RLS(멤버 + 엔타이틀먼트)와 서버 쓰기 테이블 guard 트리거, 플랜 키 3개(`storyboard`, `storyboard_max_minutes`, `shorts_extract_max`) 병합 UPDATE, 템플릿 seed 5종(01장 10.3절 비트), `productions.track` C 신규 생성 금지 표시(제안)와 `longform_*` 3개 테이블 "Track S로 대체, 삭제는 D-34" 주석, 모놀리스 재생성, 타입 재생성 | 001과 같은 파일: `supabase/migrations/1200_video.sql`(끝 "스토리보드" 새 절), `supabase/monolith/**`(변환 스크립트로만), `apps/sceneflow/src/types/supabase.ts`. 001 완료 뒤 직렬로 이어 받는다(동시 쓰기 없음) | 001 | P0 | M | Fable(데이터 모델·RLS) | `supabase db reset` 성공, 체커 OK(`--vector` 모듈러·모놀리스), 타입 파일에 새 테이블 6개. `save_scene` revision 불일치 `VD409`, status `rendering` 중 사용자 RPC `VD020`, 241번째 장면 `VD018`, 권리 근거 없는 clip 소재 `VD019`, 11번째 short 컷 `VD021`, `apply_storyboard_result` 합계 ±10% 밖 `VD017`, `scene_ids`가 연속이 아닌 컷 22023, 사용자 세션의 `scene_assets`·`storyboard_snapshots`·`storyboard_templates` 쓰기 42501, 스냅샷 UPDATE·DELETE 42501, 다른 조직 `storage_path` 23514, 템플릿 비트 비중 합계 100 검사 DO 블록 통과, 서버 RPC는 `is_service_caller()` 검사 | VD-F-130~139, 141, 05장 11장 |
| VID-06-067 | 기존 Track D 데이터 이전 경로(개발 착수 전 정리): `longform_projects/sections/highlights` → `storyboards/scenes/storyboard_cuts` 이전 스크립트(섹션 1개 → `image` 장면 1개, 하이라이트 1개 → `short` 컷 1개), dry-run 모드, 새 Track D·Track C Mode1 생성 경로 0 확인 목록 | `scripts/migrate/longform-to-storyboard.sql`(제안), `scripts/migrate/README.md`(제안). 대응표 자체는 05장 11장(05장 작업 문서) | 066 | P0 | S | Fable(데이터 모델) | 로컬 시드 롱폼 1건 dry-run에서 섹션 수 = 장면 수, 하이라이트 수 = short 컷 수, 장면 길이 합계 = 섹션 길이 합계. 운영 데이터가 없으면 "이전 대상 0"을 task `log.md`에 기록. 이 작업은 기존 테이블을 지우지 않는다(D-34 결정 전) | VD-F-142, D-34 |
| VID-06-068 | 스토리보드 RLS·권한 회귀 테스트 | `supabase/tests/storyboard/**`(002 소유 `supabase/tests/` 중 이 하위 폴더만) | 066, 002 | P0 | M | Fable(RLS) | `outsider`로 다른 조직 스토리보드·장면·소재·컷·스냅샷 0행, 쓰기 42501. `viewer` 쓰기 42501. `owner`(Starter, `storyboard=false`) 생성 42501. Basic 조직 20분 롱폼 INSERT 42501. 서버 쓰기 테이블 guard 우회 시도 실패. 대행 조직 `client_id`가 다른 조직 고객이면 거부. CI에서 002와 함께 실행, 실패 시 머지 불가 | VD-F-130, 132, 134, 139, SECURITY_BASELINE |
| VID-06-069 | Track S 단가·플랜 판정: 01장 10.4절 단가를 `priceOf`에 등록, `storyboard`·`storyboard_max_minutes`·`shorts_extract_max` 판정, 장면 다시 만들기 부분 환불 키(`refund:storyboard:<id>:scene:<scene_id>:<part>`, 제안) | `src/server/billing/storyboard.ts`(005 소유 `billing/` 중 이 파일만. `priceOf` 등록 1줄은 005 파일에 요청) | 005, 066 | P0 | S | Fable(과금·권한) | 01장 10.4절 표와 같은 단위 테스트(롱폼은 10분 단위 올림), 예시 계산 119 / 136 재현, 미리보기·편집 저장·이미지 재사용 0, Starter 403 `VD009`, Basic 20분 403 `VD009`, Basic 4번째 쇼츠 컷 403 `VD009`, 동시 50요청 음수 잔액 0 | VD-F-130, 133, 137, 01장 10.4절 |
| VID-06-070 | 템플릿 5종 비트 지침과 평가 샘플: 템플릿별 비트 설명·장면 분배 규칙·금지 표현, 쇼츠·롱폼 평가 주제 샘플 | `packages/video-rules/storyboard/**`(049 소유 `video-rules/` 중 이 하위 폴더만) | 066 | P0 | S | Sonnet(문서) | 5종 코드가 01장 10.3절과 같다, 비트 이름·비중이 seed와 같다(스크립트 비교), 템플릿마다 쇼츠 1·롱폼 1 평가 샘플(071 평가셋에 들어감), `product_review`에 Track B 연계 없음, 금지 문구 0(01장 6장, 10.5절) | VD-F-141 |
| VID-06-071 | FastAPI 그래프 `video.storyboard`(대본 + 템플릿 비트 + 목표 길이 → 장면 목록 JSON, 사실 주장 표시 `source_required`, compliance 마지막 노드, 범위 밖 1회 재작성)와 `video.shorts_pick`(쇼츠 후보 장면 → 연속 장면 묶음 + 훅 문구), 출력 스키마(pydantic), 평가셋 | `apps/api/app/ai/graphs/video_storyboard.py`, `apps/api/app/ai/graphs/video_shorts_pick.py`(049 소유 `graphs/` 중 두 파일만), `apps/api/app/ai/products/video/storyboard_schema.py`(제안), `apps/api/tests/video/storyboard/` | 049, 045, 070 | P0 | L | Opus(그래프) | 장면 길이 합계 = 목표 ±10%(벗어나면 1회 재작성, 그래도 벗어나면 run failed), 장면 수 범위(쇼츠 3~12, 롱폼 분당 3~8, 최대 240), `scene_kind` 4종·`motion_preset` 5종 밖 값 0, 글자 수 제한(문구 160, 내레이션 600, 시각 설명 600), 근거 id 없는 출처 URL 0, 숫자 `text_card`는 `source_required=true`, 금지 문구 평가셋(대본 그래프 30문항 + 역사 단정 문항, 제안 20) 위반 0(상용·오픈소스 경로), 실행 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`, `shorts_pick` 결과의 `scene_ids`가 연속이고 컷 10개 이하 | VD-F-131, 137, 138, 141 |
| VID-06-072 | 오케스트레이터 Track S 생성·소재 단계: 잡 `storyboard.generate`(잡 토큰 → 그래프 → `apply_storyboard_result`), `scene.image`(016 fal 단계 재사용, 서버 조립 프롬프트), `scene.narration`(053 TTS 단계 재사용, 같은 목소리 규칙), `finish_scene_asset`, 이전 소재 superseded, 장면 단위 실패 환불 | `workers/video-orchestrator/src/storyboard/{generate,assets}/**` | 015, 016, 053, 066, 069, 071 | P0 | L | Opus(워커·연동) | 같은 잡 재시도 시 결과 반영 1회(멱등), 이미지 1장 실패 시 그 장면 3크레딧만 환불 1행, 다시 만들기 뒤 같은 장면·종류·언어의 ready 소재 1행, 재사용 이미지는 원장 행 0 + `reused_from_asset_id`, AI 소재 `ai_generated=true`, 내레이션 제공자·보이스가 기록값과 다르면 422 `VD013`이고 대체 호출 0, 미디어 워커에 LLM 키 0 | VD-F-131, 133, 134 |
| VID-06-073 | FFmpeg 스토리보드 렌더·쇼츠 컷 핸들러: 스냅샷 JSON 입력, 장면 종류 4종 렌더(이미지 + 모션 프리셋 5종, clip 트림, `text_card`·`title` 글자 카드), 내레이션·음악·자막 믹스(자막 레이어 VD-F-033), 언어판, 9:16 크롭 컷, Starter 워터마크 규칙 유지 | `services/media-worker/handlers/ffmpeg/storyboard/**`(013 소유 `ffmpeg/` 중 이 하위 폴더만, 013의 켄번스·자막 함수 재사용) | 013, 066 | P0 | L | Opus(기능) | 04장 9장 payload 계약대로 결과 경로 반환, 스냅샷 밖 Storage 경로 읽기 0, 같은 스냅샷 두 번 렌더 시 장면 순서·길이 동일(프레임 해시 비교는 제안), 10분 1언어 렌더가 5장 p90(2시간) 예산 안, 9:16 크롭이 글자 카드를 자르지 않음(글자 카드는 9:16으로 다시 그림), 하위 프로세스 타임아웃·kill(011 규칙), Remotion·CapCut 의존 0 | VD-F-136, 137 |
| VID-06-074 | 스토리보드 API(생성·편집): `POST /api/storyboards`, `GET /api/storyboards/[id]`, `POST .../generate`, `PATCH /api/scenes/[id]`, `POST .../reorder`, `POST /api/scenes/[id]/regenerate`, 장면 추가·삭제·쇼츠 후보 Route Handler와 서버 도메인 | `src/app/api/storyboards/{route.ts,[id]/route.ts,[id]/generate/**,[id]/reorder/**,[id]/scenes/**}`, `src/app/api/scenes/**`, `src/server/storyboards/{core,scenes}/**` | 005, 015, 066, 069 | P0 | L | Opus(기능) | 04장 9장 계약, 같은 `request_id` 재요청 차감 1회, 주제 점수 59 → 409 `VD010` + 대안 3개, revision 불일치 409 `VD409` + 최신본, 렌더 중 PATCH 409 `VD020`, 세션 org와 다른 id 404, 다시 만들기 요청은 그 장면 단가만 선차감, 목업 응답 0, 대행 조직 `client_id` 규칙(VD-F-122) | VD-F-130~134 |
| VID-06-075 | 렌더·쇼츠 추출·스냅샷 API와 렌더 흐름: `POST .../render`(서버 검사: 합계 ±10%, 소재 ready, clip 근거 → `snapshot_storyboard` → 잡 `storyboard.render`, media-worker cpu 큐), `POST .../shorts`(그래프 `video.shorts_pick` → 잡 `storyboard.shorts`), `GET .../snapshots/[version]`, 결과 `outputs.storyboard_cut_id` 연결, 언어별 부분 환불 | `src/app/api/storyboards/[id]/{render,shorts,snapshots}/**`, `src/server/storyboards/render/**`, `workers/video-orchestrator/src/storyboard/{render,shorts}/**` | 072, 073, 074 | P0 | L | Opus(기능·워커) | 렌더마다 스냅샷 1행, 범위 밖 `VD017`, 소재 없는 장면 목록과 함께 409, 11번째 컷 `VD021`, 플랜 한도 `VD009`, 컷마다 `outputs` 1행, JA 언어판 실패 시 JA분만 환불, 세로 구도 기본값이 설정 값(D-32 결정 전 제안값 크롭), 스냅샷 응답은 읽기 전용 | VD-F-136, 137, 139 |
| VID-06-076 | 출처 칸·사실 확인 경고: 출처 점검 잡 `storyboard.source_check`(049 `video.step`에 kind `source_check` 추가 1줄 요청, 1크레딧), WARN 목록 저장, 업로드 설명란 "참고 자료" 블록 생성기(대가성 문구 첫 줄 뒤, 설명란 끝) | `src/server/storyboards/sources/**`, `workers/video-orchestrator/src/storyboard/source-check/**`. 업로드 설명란 조립에서 이 생성기를 부르는 1줄은 021 파일에 요청(문구 삽입은 021만, 1절) | 049, 066, 074 | P0 | M | Opus(기능·연동) | 출처 없는 사실 주장 장면이 있는 업로드의 compliance verdict WARN(FAIL 아님, D-33), `has_affiliate=true` 업로드 첫 줄은 대가성 문구 그대로(DB CHECK), 출처 0개면 "참고 자료" 블록 없음, URL은 http(s)만, 설명란 5,000자를 넘으면 뒤쪽 출처를 줄이고 "외 N건"(제안), 그래프가 만든 출처 URL 중 근거 id 없는 것 0, 점검 실패 시 환불 1행 | VD-F-138, 01장 10.5절 |
| VID-06-077 | 스토리보드 화면 문구 키와 오류 문구(03장 8.6절), 템플릿 이름·비트 이름, 장면 종류·모션 이름 한국어 라벨 | `src/i18n/storyboard/**`(036 소유 `src/i18n/` 중 이 하위 폴더만) | 036 | P0 | S | Haiku(문구) | 03장 8.6절 문구와 글자 하나까지 같음(스크립트 비교), `VD017`~`VD021`·`VD409` 문구 키 전부, 금지 문구 0(01장 6장·10.5절 마케팅 금지 포함 "사실 확인 완료" 0), 하드코딩 한국어 문자열 0(린트, 제안) | 03장 8.6절 |
| VID-06-078 | 스토리보드 목록·새로 만들기 5단계 화면(형식 → 길이 → 템플릿 → 주제 → 대본 확인), 대본 기획 미리보기(056) 장착 | `src/app/(dashboard)/dashboard/storyboards/{page.tsx,new/**}`, `src/components/storyboard/{list,wizard}/**`. 대시보드 메뉴 "롱폼 → 스토리보드" 1줄은 028 파일에, 숏폼 생성의 Track C 자리 링크 1줄은 029 파일에 요청 | 028, 044, 056, 074 | P0 | M | Sonnet(UI) | 03장 8.1·8.2절 구성, 단계 중간 저장, 플랜 상한 길이 잠금 칸(글자 표시), `VD010` 대안 3개, 402 충전 모달, Starter 안내 화면, 예상 크레딧 표시, 375px 목록 카드형 | VD-F-130, 141, 03장 8장 |
| VID-06-079 | 편집기 3단: 장면 목록(챕터 묶음, 끌어 옮기기, 키보드 옮기기, 쇼츠 후보·출처·AI 배지), 장면 상세(자동 저장, 소재 고르기·업로드·재사용, 권리 근거, 출처 칸), 상단 길이 게이지·장면 수·출처 경고 수·예상 크레딧, 하단 바 | `src/app/(dashboard)/dashboard/storyboards/[id]/page.tsx`, `src/components/storyboard/editor/**` | 044, 074, 077 | P0 | L | Sonnet(UI) | 03장 8.3~8.8절 구성, 키보드만으로 장면 순서 변경 + `aria-live` 알림, 게이지 `role="meter"`와 글자 상태, `VD409` 최신본 + 내 입력 보존, `VD020` 입력 비활성, viewer 읽기 전용, 767px 이하 읽기 전용, 1,000ms 안 저장 상태 표시(제안), 240장면에서 스크롤 끊김 없음(가상 목록, 제안) | VD-F-132~134, 138, 03장 8장 |
| VID-06-080 | 브라우저 미리보기 타임라인: 장면 이미지·클립·글자 카드 순서 재생, 모션 프리셋 근사, 내레이션·음악 오디오 맞춤, 자막 언어 전환, 장면 클릭 이동 | `src/components/storyboard/preview/**` | 044, 074 | P0 | M | Sonnet(UI) | 미리보기가 잡·원장 행 0(네트워크 기록 확인), 다운로드 버튼·경로 0, 시작 2초 안 첫 프레임(제안), 소재 없는 장면 자리표시, reduced-motion이면 모션 정지, 렌더러 패키지 import 0 | VD-F-135 |
| VID-06-081 | 렌더·쇼츠 추출·언어판 화면과 스냅샷 열람: 마스터 컷 언어별 렌더 행, 쇼츠 후보 고르기·컷 카드(훅 문구, 세로 구도 선택), 언어판 행, 스냅샷 목록과 읽기 전용 편집기, 업로드 준비 연결 | `src/app/(dashboard)/dashboard/storyboards/[id]/render/**`, `src/components/storyboard/{render,shorts,snapshot}/**` | 075, 079 | P0 | M | Sonnet(UI) | 03장 8.9절 구성, 진행률 없는 무한 스피너 0(패턴 N), 실패 행 원인 한 줄 + 환불 표시, `VD021`·`VD009` 안내, 남은 컷 수 표시, 스냅샷 열람 중 편집 0, 업로드 준비가 기존 `/dashboard/publish/[uploadId]`로 이동, AI 생성 표시 기본 체크 전달(01장 10.5절) | VD-F-136, 137, 139 |
| VID-06-082 | (10장 VID-06-090·099로 흡수, 실행 안 함) 음성 지시 편집(P1): 받아쓰기(052 경로) → 텍스트 확인 → 편집 패치 변환(049 `video.step` kind `scene_command` 1줄 요청, 1크레딧 제안) → 변경 미리보기 → 적용(`save_scene`) | `src/components/storyboard/voice-command/**`, `src/app/api/storyboards/[id]/command/**`(제안 경로, 04장 9장에 없으면 04장에 추가 요청) | 052, 074, 079 | P1 | M | Opus(기능·연동) | 사용자 확인 전 장면 변경 0, 음성 고지 미확인 403, `store_audio=false` 100%, 해석 실패 시 변경 0 + "알아듣지 못했습니다", 적용 시 revision 검사(`VD409`), 마이크 없이도 편집기 정상 | VD-F-140 |
| VID-06-083 | Track S 파이프라인 통합 테스트(가짜 제공자, 로컬 Python 워커): 주제 → 대본 → 스토리보드 → 장면 소재 → 렌더 → 쇼츠 3편 → JA 언어판, 부분 환불 | `tests/integration/storyboard/**` | 072, 073, 075, 076 | P0 | M | Opus(테스트 설계) | 끝까지 통과, 이미지 1장 실패 주입 시 그 장면분만 환불, JA 실패 주입 시 JA분만 환불, 렌더 중 편집 `VD020`, 같은 스냅샷 다시 렌더 결과의 장면 순서·길이 동일, 원장 drift 0, 미리보기 경로 잡 0 | VD-F-131~139 |
| VID-06-084 | 스토리보드 사용자 플로우 E2E(03장 8.2절 16단계, 현우 흐름) | `tests/e2e/storyboard/**` | 078, 079, 080, 081 | P0 | M | Opus(테스트 설계) | Mock 페르소나 storageState: `adv_owner`(롱폼 10분 + 쇼츠 3편 + 업로드 준비까지), `owner`(Starter 안내 화면), `viewer`(읽기 전용), `outsider`(404). 키보드만으로 장면 옮기기, 두 탭 동시 편집 `VD409`, 뷰포트 4종(375/768/1024/1440) 스크린샷, 063 완료 뒤 재실행 | 03장 8장, VD-F-130~139 |

### 9.2 웨이브와 게이트

Track S 작업은 3절 웨이브와 나란히 가는 S 웨이브로 묶는다. 앞쪽(S1~S5)은 기존 웨이브 시기에 끼워 넣고, 뒤쪽(S6~S8)은 W6과 W7 사이에 새로 들어간다. W7(G1, 공개 베타)은 S8 완료를 기다린다.

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 같은 시기 | 산출물 |
|---|---|---|---|---|---|
| S1 | 066 | 1 | 001 완료 | W1 | 스토리보드 스키마, 타입 |
| S2 | 067, 068, 070, 077 | 4 | 066(+ 068은 002, 077은 036) | W2 | 이전 스크립트, RLS 테스트, 템플릿 지침, 문구 키 |
| S3 | 069, 073 | 2 | 005(069), 013(073), 066 | W3 | 단가·플랜 판정, FFmpeg 렌더 핸들러 |
| S4 | 074 | 1 | 015, 069 | W4 | 생성·편집 API |
| S5 | 078, 079, 080 → 071, 076 | 3 → 2 | 화면 3개는 074·044·028(078은 056 장착 요청만 W6 뒤), 071·076은 049(W5) | W5~W6 | 목록·새로 만들기·편집기·미리보기, 그래프, 출처 점검 |
| S6 | 072 | 1 | 071, 053(W5), 016 | W6 뒤 새 웨이브 | 생성·소재 단계(실제 그래프 경로) |
| S7 | 075 → 081 | 1 → 1 | 072, 073, 074 / 081은 075·079 | 새 웨이브 | 렌더·쇼츠·스냅샷 API와 화면 |
| S8 | 083, 084 | 2 | S7 | 새 웨이브, W7 직전 | 통합 테스트, E2E |
| W8 | 082 | 1 | G1 뒤, 052·079 | W8 | 음성 지시 편집(P1)(10장 090·099로 흡수되어 MVP P0 E5·E6에서 실행) |

| 게이트 | 조건 | 판정 |
|---|---|---|
| S-스키마 | 066 수용 기준과 068 녹색 전에는 스토리보드 API(074)를 머지하지 않는다. 066 전 화면·API 작업은 타입이 없어 시작하지 않는다 | CI(039, 068) |
| S-그래프 평가 | 071 평가셋(장면 수·길이 합계·금지 문구·출처 URL) 통과 전에는 072가 실제 제공자 경로를 켜지 않는다. 그 전 078~080은 074의 가짜 그래프 결과(고정 JSON 픽스처)로 개발한다 | `pytest apps/api -k storyboard` |
| S-렌더 계약 | 073의 스냅샷 입력과 075가 만드는 스냅샷이 04장 9장 payload와 같다는 계약 테스트(zod·pydantic 동치) 통과 전에는 075 머지 금지 | 075 단위 테스트 |
| 결정 게이트 | D-32(세로 구도 기본값)는 075·081 착수 전에 정한다. 정하지 않으면 제안값(크롭)을 설정 기본값으로 두고 두 방식을 모두 구현한다. D-33은 076을 WARN으로 고정한다. D-34 전에는 067이 기존 테이블을 지우지 않는다. D-30·D-31은 Phase 2 | 사람이 task `log.md`에 `[DECISION]` |
| G1(8.2절에 더함) | video 기준 (1)에 9장 P0 작업 18개 완료, (2)에 084 녹색, 파이프라인 기준에 083 녹색을 더한다 | 사람(대표님) `[DECISION] G1 통과` |

P0 작업과 테스트 작업 대응(3절 규칙에 더함): 스키마·단가(066, 067, 069) → 068 / 그래프·워커·API(070~076) → 083 / 화면(078~081), 문구(077) → 084 / 음성 지시(082, P1) → 055의 음성 항목에 1줄 요청.

### 9.3 코어·공용 요청 (6절, 8.3절 표에 이어서)

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 | 시점 |
|---|---|---|---|---|---|
| R-V12 | `_supabase-modular/seed.sql` | video 플랜 4행 `features`에 `storyboard`, `storyboard_max_minutes`, `shorts_extract_max` 추가(값은 01장 10.4절, 제안) | R-V1과 같다: seed가 1200보다 나중에 실행되면 066의 병합 UPDATE가 덮어써진다 | 서버(069)가 누락 키를 기본값(Starter 값)으로 읽는다 | MVP |
| R-V13 | `_platform-core`, 공용 패키지(제안 `packages/storyboard-core`) | 공용 스토리보드 모듈: 장면 스키마(zod·pydantic 동치), 길이 합계 ±10%·장면 수 검증, 낙관적 동시성 `save_scene`·`reorder_scenes` 패턴과 409 응답 형식, 렌더 스냅샷 형식, 장면 목록 키보드 정렬·미리보기 타임라인 UI. **book-trailer, toon-factory와 함께** 요청한다 | 세 제품이 같은 구조를 따로 만든다: book-trailer 장면·`save_scene`·`TR409`(`docs/products/book-trailer/03_SCREENS_UX.md:74`), toon-factory 콘티 그래프 `toon.storyboard`(`docs/products/toon-factory/01_PRD.md:136`), sceneflow Track S(01장 10장) | MVP는 video 안(`src/server/storyboards/`, `src/components/storyboard/`, `storyboard_schema.py`)에 공용으로 옮기기 쉬운 같은 인터페이스로 둔다. 제품 이름·스키마 이름을 모듈 안에 하드코딩하지 않는다 | Phase 2 |
| R-V14 | `_platform-core` 렌더 서비스 | 렌더러 공용화 검토(D-30): book-trailer R-T8(`docs/products/book-trailer/06_AGENT_PLAN.md:154`, Remotion 렌더러 공용 서비스 승격)과 한 번에 검토. 장면 모션 그래픽용 Remotion 도입 여부, 라이선스 조건(미확인), 서버 렌더 원가 | 같은 장면 스냅샷을 두 렌더러가 따로 읽으면 결과가 갈린다 | MVP는 FFmpeg 핸들러(073)만. 스냅샷 형식은 R-V13 후보 형식을 따른다 | Phase 2 |
| R-V15 | ai_providers, 공용 GPU 서버 | 오픈소스 이미지 모델 경로를 제공자 레지스트리에 편입 검토(D-31, 상업 이용 라이선스 확인 뒤) | 이미지가 롱폼 단가의 약 3분의 2(01장 10.4절 예시) | fal 단가 3 유지 + 이미지 재사용 0크레딧을 기본으로 보인다 | Phase 2(가격 검증 결과에 따라) |

### 9.4 기존 작업에서 범위가 바뀐 것

2절·3절·7절의 해당 줄에 같은 줄 수정으로 "(2026-10-18: ...)"를 달았다. 줄 수는 그대로다.

| 작업 ID | 이전 범위 | 바뀐 범위 | 대체·이동 |
|---|---|---|---|
| VID-06-018 | 롱폼 API(점수 게이트, 스토리라인, 10섹션, 렌더, OSMU) | 실행하지 않는다 | 9장 VID-06-074(생성·편집), 075(렌더·쇼츠). 점수 게이트는 074 |
| VID-06-030 | 롱폼 스토리보드 화면 | 실행하지 않는다 | 9장 VID-06-078~081 |
| VID-06-019 | Track E API | Phase 2(SF-3) | - |
| VID-06-020 | Track F API(플리, 라이브러리 등록) | Phase 2(SF-3). `music_library`도 Track F 라이선스 곡이라 함께 옮긴다 | - |
| VID-06-031 | 곡·플리·라이브러리 화면 | Phase 2(SF-3) | - |
| VID-06-013 | FFmpeg: 워터마크·무음컷·자막·인코딩·켄번스·루프·플리 연결·하이라이트 컷 | 루프·플리 연결은 Phase 2. 하이라이트 컷은 073 쇼츠 컷으로 대체. 켄번스·자막·인코딩은 그대로이고 073이 재사용 | 073 |
| VID-06-016 | 번역, fal 이미지, Suno | Suno 단계는 Phase 2. fal 이미지 단계는 072 장면 이미지가 재사용 | 072 |
| VID-06-017 | 소싱·숏폼 생산 API(Track A/B/C) | Track C Mode1 제외(Track S로 안내), Mode2는 Track A의 "원본 재편집" 옵션(SF-1) | 074 |
| VID-06-029 | 소싱·숏폼 화면(Track 선택 A/B/C) | Track C 선택지를 빼고 스토리보드 새로 만들기 링크(078이 029 파일에 1줄 요청) | 078 |
| VID-06-037 | 파이프라인 통합 테스트 Track A~F | Track A·B만. Track S는 083, E·F 시나리오는 Phase 2 | 083 |
| VID-06-038 | 사용자 플로우 E2E(가입→첫 생성, 업로드 WARN, Track B 랜딩, Track F) | Track F 플로우는 Phase 2. 스토리보드 플로우는 084 | 084 |
| VID-06-049 | `video.script`의 Track D 스토리라인·10섹션 | Track D 대신 Track S 대본(쇼츠·롱폼)을 만든다. 스토리보드 그래프는 071 | 071 |
| VID-06-053 | 롱폼 섹션 재생성이 첫 섹션 기준을 따름 | 장면 내레이션 다시 만들기(072)가 스토리보드에 처음 기록된 제공자·보이스를 따름 | 072 |
| VID-06-056 | 숏폼 생성·롱폼 화면(029·030)에 장착 | 029와 스토리보드 새로 만들기 5단계(078)에 장착 | 078 |
| VID-06-035 | 랜딩: 6개 트랙 소개, 히어로 레인 F(플리) | Track E·F 소개를 빼고 Track S(스토리보드 하나로 롱폼 + 쇼츠)를 보여 준다(제안, 03장 8.11절) | - |
| VID-06-001, 002, 005 | 기존 테이블 26개, RLS 항목, 단가표 | 스토리보드 절·테스트·단가는 각각 066, 068, 069가 이어서 맡는다 | 066, 068, 069 |

### 9.5 작업 수와 모델 비율

| 구분 | 작업 수 | 내용 |
|---|---|---|
| 전체 ID | 84개 | 2절 62 + 8절 3 + 9장 19. 모델 작업 83, 사람 1(043) |
| MVP 계획 | 79개(모델 78, 사람 1) | P0 66, P1 13. P1 중 W8 작업(057~062, 064, 065, 082)은 MVP 출시 뒤 웨이브 |
| Phase 2로 옮김 | 3개 | 019, 020, 031 |
| 대체되어 실행하지 않음 | 2개 | 018, 030(9장 작업이 대체) |

모델 비율(MVP 계획의 모델 작업 78개 기준, 4절 표를 같은 줄 수정으로 갱신함):

| 모델 | 이전(64개) | 지금(78개) | 규모 가중(S=1, M=2, L=3) 이전 → 지금 |
|---|---|---|---|
| Fable | 12(18.8%) | 16(20.5%) | 27/129(20.9%) → 33/159(20.8%) |
| Opus | 33(51.6%) | 39(50.0%) | 68/129(52.7%) → 85/159(53.5%) |
| Sonnet | 16(25.0%) | 19(24.4%) | 31/129(24.0%) → 37/159(23.3%) |
| Haiku | 3(4.7%) | 4(5.1%) | 3/129(2.3%) → 4/159(2.5%) |

변화 요인: 신규 Fable 4(066 M, 067 S, 068 M, 069 S), Opus 9(071~075 L, 076·082·083·084 M), Sonnet 5(070 S, 078 M, 079 L, 080 M, 081 M), Haiku 1(077 S). 빠진 것: Opus 3(018, 019, 020, 모두 M), Sonnet 2(030, 031, 모두 M). Phase 2 작업 3개를 다시 MVP로 올리면 Opus 41, Sonnet 20, 합계 81개가 된다.

### 9.6 확인 필요(열린 항목)

| 항목 | 내용 |
|---|---|
| 음악 큐의 음원 출처 | 장면 `music_cue`는 큐 이름만 저장한다. Track S BGM을 어디서 가져올지(운영자 제공 BGM 묶음, 조직 라이선스 곡, 음악 없음)는 01장 10장에 없다. `music_library`는 Track F용이고 Phase 2로 옮겼다. 제안: 새 결정 D-35로 올리고, 결정 전 073은 "음악 없음"과 운영자 BGM 묶음 경로만 구현한다 |
| 쇼츠 후보 없이 고르기 | 쇼츠 후보 표시 장면이 없을 때 전체 장면에서 고르는 경로(03장 8.6절)는 01장에 없다(제안) |
| 장면 하나의 길이 범위 | 장면별 최소·최대 길이는 정하지 않았다(03장 8.4절 제안 1~60초) |
| 음성 지시 경로 | `POST /api/storyboards/[id]/command`는 04장 9장 목록에 없는 제안 경로다(082)(10장: 04장 10.1절 `POST .../edit-plans {mode: 'voice'}`로 대체, 090) |

## 10. AI 자동편집·화면비 작업 (2026-10-18 추가, 01장 11장)

정본은 01장 11장(확정 SF-5~SF-8, 11.2절 VD-F-143~159, 11.4절 편집 명령 허용 목록, 11.5절 단가, 11.6절 플랜 키, 11.9절 D-38~D-44)이다. 구조는 02장 11장, 화면은 03장 9장, API·잡·오류 코드는 04장 10장, 테이블·RPC는 05장 12장과 `docs/products/_supabase-modular/migrations/1200_video.sql` 13절(`:3038-4195`)을 따른다. **SceneFlow의 주력 기능은 AI 자동편집이다(SF-5, `01_PRD.md:573`).** 그래서 이 장의 P0 작업은 공개 베타(W7, G1) 전에 끝나야 한다. 새 작업은 30개(VID-06-085~114)이고 ID는 9장 최대 번호 084 다음부터다. 기존 작업 행은 지우지 않았고, 범위가 바뀐 행에만 같은 줄로 "(10장 ...)"를 달았다(10.4절). 모델 배분은 머리말 원칙을 따른다: Fable(데이터 모델, RLS, 과금·권한), Opus(기능 구현, API 연동, 그래프, 워커, 테스트 설계), Sonnet(UI, 문서), Haiku(문구).

| 경로 기준 | 내용 |
|---|---|
| 화면 | `src/components/storyboard/{ai-edit,render-settings,variants,focus,silence-review,captions}/**`(03장 9.8절 컴포넌트). 편집기 페이지(`dashboard/storyboards/[id]/page.tsx`)와 렌더 페이지는 079·081 소유라 장착은 1줄 요청. 설정 화면은 `dashboard/settings/{pronunciation,edit-presets}/**`(034 소유 `settings/` 중 이 하위만, 064 `login-methods/`와 같은 예외) |
| API | `src/app/api/storyboards/[id]/{edit-plans,settings,variants,meta,thumbnails,nle-export}/**`, `src/app/api/edit-plans/**`, `src/app/api/scenes/[id]/{analyze-clip,retakes}/**`, `src/app/api/{pronunciation-lexicon,edit-presets}/**`(04장 10.1절) |
| 서버 도메인 | `src/server/storyboards/{edit,render-settings,clip-analysis,lexicon,meta}/**`(02장 11.1절 `src/server/storyboards/edit/**`) |
| 과금 | `src/server/billing/ai-edit.ts`(005 소유 `billing/` 중 이 파일만, 069 `storyboard.ts`와 같은 예외) |
| 워커 | `workers/video-orchestrator/src/storyboard/{edit,clip,upscale,sentence,meta}/**`, `services/media-worker/handlers/storyboard/{silence_detect,retake_detect,upscale}/**`(02장 11.1절). FFmpeg 렌더 확장은 073 소유 `handlers/ffmpeg/storyboard/**`를 073 완료 뒤 이어 받는다(동시 쓰기 없음) |
| AI 서비스 | `apps/api/app/ai/graphs/video_edit_plan.py`, `apps/api/app/ai/products/video/edl_schema.py`(02장 11.1절, 049 소유 `graphs/` 중 이 파일만), `apps/api/tests/video/edit/` |
| 규칙 | `packages/video-rules/edit/**`(049 소유 `video-rules/` 중 이 하위만): `edl.schema.json`(TS·Python 공용 정본, CLAUDE.md AI 자동편집 규칙), `fillers.ko.json`, `safe_zones.json`, `caption_styles.json`, `hanja_glossary.json`(02장 11.1절) |
| 스키마 | 1절 규칙 그대로 VID-06-001 소유 파일에 들어간다. 001·066 담당(Fable)이 066 완료 뒤 085로 이어서 수행한다 |

이 장의 어떤 작업도 LLM 출력으로 FFmpeg 인자·셸 문자열·SQL·파일 경로를 만들지 않는다(SF-6, 02장 11.1절 경계 규칙). 장면 변경은 `video.apply_edit_plan` 한 번으로만 한다.

### 10.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| VID-06-085 | AI 자동편집·화면비 스키마(05장 12장, `1200_video.sql` 13절) 적용: 기획 저장소의 13절 SQL(체커·행동 검사 62항목 통과, 05장 12.8절)을 개발 저장소 `1200_video.sql` 끝에 옮기고, 모놀리스 재생성(변환 스크립트), 타입 재생성. 새 테이블 4개(`edit_plans`, `edit_presets`, `pronunciation_lexicon`, `clip_transcripts`), storyboards 컬럼 8개(`resolution`, `fps`, `shorts_aspect`, `caption_style`, `caption_hanja`, `bgm_level_db`, `loudnorm`, `edit_preset_id`), scenes 컬럼(`focus_x/y`, `transition(_ms)`, `clip_in/out_ms`, `cut_ranges`, `caption_emphasis`), cut kind `variant`, `outputs.width/height/fps`, RPC `apply_edit_plan`·`undo_edit_plan`·`reject_edit_plan`·`storyboard_fingerprint`, `snapshot_storyboard` 다시 정의, 오류 코드 `VD022`·`VD023`, 플랜 키 7개 병합 UPDATE(`:4179-4195`) | 001·066과 같은 파일: `supabase/migrations/1200_video.sql`(끝 13절), `supabase/monolith/**`(변환 스크립트로만), `apps/sceneflow/src/types/supabase.ts`. 066 완료 뒤 직렬로 이어 받는다 | 066 | P0 | M | Fable(데이터 모델·RLS) | `supabase db reset` 성공(1200 2회 연속 적용 포함), 체커 OK(`--vector` 모듈러·모놀리스), 타입 파일에 새 테이블 4개와 새 컬럼. 05장 12.8절 13절 행동 검사 62항목이 개발 저장소에서도 같은 결과: 롱폼 4:5 23514, Basic 2160p `VD009`, 렌더 중 설정 변경 `VD020`, rendered 뒤 설정 변경 시 status `ready`, 같은 화면비 변형본 22023, 4번째 변형본 `VD022`, 허용 밖 op 23514(CHECK)·다른 스토리보드 장면 `VD023`, 지문 불일치 `VD409`, 다시 적용 `VD005`, 뒤 편집이 있으면 되돌리기 `VD409`, 사용자 세션의 `edit_plans` INSERT·`clip_transcripts` 쓰기 42501, 발음 사전 중복 23505·2,001번째 54000. 라우팅 키 `video.edit_plan` 행 추가 여부는 10.6절 결정을 따른다 | VD-F-143~151, 155, 05장 12장 |
| VID-06-086 | AI 자동편집 RLS·동작 회귀 테스트 | `supabase/tests/ai-edit/**`(002 소유 `supabase/tests/` 중 이 하위 폴더만) | 085, 068 | P0 | M | Fable(RLS) | 05장 12.8절 13절 검사 62항목을 CI 테스트로 옮긴다. 추가: `outsider`로 다른 조직 편집안·프리셋·사전·전사 0행·쓰기 42501, `viewer`의 `apply_edit_plan`·`undo_edit_plan`·사전 쓰기 42501, `owner`(Starter, `ai_edit=false`) 적용 `VD009`, `storyboard_fingerprint` 사용자 EXECUTE 42501, 대행 조직 고객 A 프리셋을 고객 B 스토리보드에 연결 `VD002`, 변형본 스냅샷 `crop_from`·픽셀 크기가 `render_dimensions`와 같음. CI에서 002·068과 함께 실행, 실패 시 머지 불가 | VD-F-144, 146, 150, 151, 155, SECURITY_BASELINE |
| VID-06-087 | AI 편집 단가·렌더 배수·플랜 게이팅: 01장 11.5절 단가(편집 지시 1, 자동 다듬기 쇼츠 1 / 롱폼 10분당 2, 클립 분석 1분당 STT 3 + 무음 컷 2, 문장 1, 업스케일 1장 1, 변형본 = 그 길이 렌더 단가, P1 단가)를 `priceOf`에 등록, 해상도·fps 배수(1080p30 = 1, 1440p 1.5, 2160p 2, 60fps 1.5, 곱 후 올림, D-41 전까지 제안값 상수), 플랜 키 판정(`ai_edit`, `render_max_resolution`, `render_max_fps`, `render_4k60`, `aspect_variants_max`, `nle_export`, `edit_presets_max`), 누락 키 기본값(Starter 값), 명령별 부분 환불 키(`refund:edit:<plan_id>:<command_id>`, 제안) | `src/server/billing/ai-edit.ts`. `priceOf` 등록 1줄은 005 파일에, 렌더 단가에 배수를 곱하는 1줄은 069 파일(`billing/storyboard.ts`)에 요청 | 005, 069, 085 | P0 | M | Fable(과금·권한) | 01장 11.5절 표와 같은 단위 테스트, 예시 재현(현우 세트 136 + 22 = 158, 2160p 세트는 렌더 10 → 20 + 업스케일 30), 적용·일부 적용·되돌리기·거절·프리셋 저장 0, 1440p 10분 렌더 15, 2160p60 10분 렌더 30(2 × 1.5), Starter 편집안 생성 403 `VD009`, Basic 1440p 403 `VD009`, Pro 4K60 403 `VD009`, 서버 키 값이 `1200_video.sql:4179-4195`와 같다(스크립트 비교), 동시 50요청 음수 잔액 0. 배수 상수 옆에 "D-41 확정 전 제안값" 주석 | VD-F-143, 144, 146~150, 01장 11.5·11.6절 |
| VID-06-088 | 편집 규칙 파일과 평가 자료: 한국어 군더더기 말 사전(강도 3단계, 운영자 seed, D-42 기본 보수), 세이프존 비율(02장 11.6절 제안값), 자막 스타일 3종 수치, 한자 병기 용어집 형식과 첫 항목(운영자 검수 항목만), 한국어 편집 지시 평가 문장(제안 60개: 길이·순서·전환·문구·강조·렌더 설정·쇼츠·해석 불가 지시 포함, 지시마다 기대 명령) | `packages/video-rules/edit/{fillers.ko.json,safe_zones.json,caption_styles.json,hanja_glossary.json}`, `packages/video-rules/edit/eval/**`(`edl.schema.json`은 089) | 085 | P0 | S | Sonnet(문서) | JSON 스키마 검사 통과, 용어집 항목마다 검수자·근거 칸, 근거 없는 한자 0, 세이프존 값이 02장 11.6절과 같다(스크립트 비교), 평가 문장 중 허용 목록 밖 요청(예: "배경을 실사로 바꿔")과 해석 불가 문장이 각 5개 이상(제안), 금지 문구 0(01장 11.7절) | VD-F-145, 146, 148, 149, D-42 |
| VID-06-089 | FastAPI 그래프 `video.edit_plan`: 지시(`mode=command\|voice`) + 스토리보드 요약 → 01장 11.4절 허용 명령 JSON(최대 100개) + 사람이 읽는 요약 + compliance, 온도 0, 출력 pydantic 스키마(`edl.schema.json`에서 생성), 스토리보드 요약 정렬 직렬화, 허용 밖 출력 1회 재작성. 자동 다듬기(`mode=auto_polish`): 규칙 단계(내레이션 끝 + 300ms 길이, 같은 모션 3연속 금지, 챕터 경계 `fade` 500ms, 덕킹·loudnorm 켜기, 프리셋 값 우선) + LLM 1회(강조어, 쇼츠 후보). 평가셋 실행기 | `apps/api/app/ai/graphs/video_edit_plan.py`, `apps/api/app/ai/products/video/edl_schema.py`, `packages/video-rules/edit/edl.schema.json`, `apps/api/tests/video/edit/` | 045, 049, 071, 088 | P0 | L | Opus(그래프) | 088 평가 문장에서 기대 명령 일치율 측정값을 task `log.md`에 기록(목표는 01장 11.8절 해석 실패율 5% 이하, 제안), 허용 밖 op·키 0(재작성 후), 요청에 없던 장면 id 0, 같은 입력 3회 실행 결과 비교 기록(제공자 비결정성은 미확인이라 "같은 결과 보장" 문구를 쓰지 않는다, 02장 11.3절), 자동 다듬기 적용 후 길이 합계 ±10% 밖이면 길이 명령 제외 + 경고, `set_text` 값 금지 문구 0(평가셋 + 01장 11.7절), 실행 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 잡 토큰 scope `graph:video.edit_plan` 밖 토큰 401, 영상·오디오 바이너리 import 0 | VD-F-146, 147, 01장 11.4절 |
| VID-06-090 | 편집안 생성 API와 EDL 서버 검사: `POST /api/storyboards/[id]/edit-plans`(`mode` command·voice·auto_polish, P1 broll은 111), `GET .../edit-plans`, 선차감 → `storyboard_fingerprint` → 그래프(동기 p95 15초, 넘으면 잡 `edit.plan`) → 서버 검사(02장 11.3절 7항목) → `edit_plans` INSERT(service_role, `proposed`, `estimate_credits`), 같은 입력 10분 안 재요청은 기존 편집안(0크레딧, 제안), 명령 0개·`VD023` 환불. 음성 지시는 받아쓰기 텍스트를 `mode=voice`로 받는다(기존 082 흡수) | `src/app/api/storyboards/[id]/edit-plans/{route.ts}`, `src/server/storyboards/edit/{create,validate,summary}/**`, `workers/video-orchestrator/src/storyboard/edit/**`(잡 `edit.plan`) | 074, 085, 087, 089(평가 통과 전에는 고정 JSON 픽스처) | P0 | L | Opus(기능·연동) | 04장 10.1절 계약, 같은 `request_id` 재요청 차감 1회, 서버 검사가 DB CHECK보다 먼저 걸린다(같은 장면 같은 op 두 번이면 뒤의 것 + 경고, 쇼츠 형식 `propose_short` `VD023`, 플랜 밖 `set_render` `VD023`), 해석 실패 시 `commands: []` + 환불 1행, 15초 넘는 요청이 잡으로 전환, 레이트 리밋 429, 음성 원본을 받는 입력 칸 0, 대행 조직 고객 범위(VD-F-122) 밖 문서 0, 목업 응답 0 | VD-F-140, 146, 147, 02장 11.2·11.3절 |
| VID-06-091 | 편집안 적용·거절·되돌리기 API와 `regenerate` 실행: `POST /api/edit-plans/[id]/{apply,reject,undo}`, 사용자 세션 `rpc('video.apply_edit_plan', {p_plan_id, p_command_ids})` → `pending_regenerate` 명령마다 consume(`consume:video:<request_id>:<command_id>`) → `scene.image`·`scene.narration`(문장 범위) enqueue, 승인 화면 합계와 다르면 차감하지 않고 409(제안) | `src/app/api/edit-plans/**`, `src/server/storyboards/edit/{apply,undo}/**` | 072, 085, 087, 090 | P0 | M | Opus(기능) | 승인 전 장면 변경 0, 일부 명령만 고르면 그 명령만 적용, 한 트랜잭션(중간 실패 시 장면 변경 0), `VD409` 응답에 "다시 제안받기" detail, regenerate 잔액 부족 402여도 비용 없는 명령 적용은 유지되고 regenerate만 대기 표시, regenerate 잡 실패 시 그 명령분만 환불 1행, 되돌리기 0크레딧·다시 만들기 환불 없음, 되돌리기 후 장면 필드가 적용 전과 같다, 서버가 명령을 `save_scene`으로 쪼개 부르는 코드 0 | VD-F-146, 151, 02장 11.2절 |
| VID-06-092 | 렌더 설정·변형본 API와 렌더 요청 변경: `PATCH /api/storyboards/[id]/settings`(화면비·해상도·fps·쇼츠 화면비·자막 스타일·BGM 음량·프리셋, 응답에 배수와 픽셀 크기), `POST /api/storyboards/[id]/variants`(variant 컷 INSERT(service) → `snapshot_storyboard(p_cut_id)` → 루트 잡), 렌더 요청에 배수·업스케일 선행 단계·`estimate` 분해 추가, 쇼츠 `image_mode`, 새로 만들기 입력의 `aspect`·`resolution`·`fps` | `src/app/api/storyboards/[id]/{settings,variants}/**`, `src/server/storyboards/render-settings/**`. 렌더·쇼츠 요청 변경은 075 소유 `api/storyboards/[id]/{render,shorts}`·`server/storyboards/render/**`에, 새로 만들기 입력은 074 소유 `api/storyboards/route.ts`에 각 1줄 요청(075·074 완료 뒤) | 074, 075, 085, 087 | P0 | M | Opus(기능) | 04장 10.1절 계약과 "바뀌는 동작" 표, 형식에 없는 화면비 422 23514, 플랜 상한 403 `VD009`, 렌더 중 409 `VD020`, 마스터와 같은 화면비 22023, 4번째 변형본 `VD022`, 1440p 이상 렌더 요청 시 업스케일 소재 없는 AI 이미지 장면 수만큼 `scene.upscale`이 루트 앞에 들어가고 `estimate.upscale`에 합산, 픽셀 크기를 코드 표가 아니라 `video.render_dimensions`에서 읽음 | VD-F-143, 144, 04장 10.1절 |
| VID-06-093 | FFmpeg 렌더 프로필: 스냅샷 `render.width×height·fps`로 출력, 장면 초점(`focus`) 기준 크롭(`crop_from`, 창이 이미지 밖이면 안쪽으로), 전환 `xfade`(01장 11.4절 8종, 200~1,500ms, 길이 합계 유지), `clip` 트림 + `cut_ranges` 제외 이어 붙이기(경계 오디오 페이드 10ms, 제안), variant 컷 렌더, 출력 `width/height/fps` 결과 보고 | `services/media-worker/handlers/ffmpeg/storyboard/**`(073 완료 뒤 이어 받음) | 073, 085 | P0 | L | Opus(기능) | 04장 10.3절 `media.scene_clip` 계약, 화면비 4종 × 해상도 4종 픽셀 크기가 `render_dimensions`와 같다(ffprobe), 같은 스냅샷 두 번 렌더 시 장면 순서·길이 동일, 전환이 있어도 출력 길이 = 장면 길이 합계(±1프레임), `cut_ranges` 경계가 지정 ms와 1프레임 안에서 일치, 원본 클립 파일 수정·삭제 0(해시 비교), 2160p 장면 클립 타임아웃 900초(02장 11.7절), LLM 키·LLM 출력 입력 0 | VD-F-143~145, 148, 02장 11.5절 |
| VID-06-094 | FFmpeg 오디오·자막: 2패스 `loudnorm`(-14 LUFS, 제안), BGM 덕킹 `sidechaincompress`(내레이션 사이드체인, 기본 `bgm_level_db`), 자막 스타일 3종(`caption_styles.json`), `word_pop` 단어 시각 강조, 강조어 굵게 + 강조색, 한자 병기(`caption_hanja=true`이고 `hanja_glossary.json` 항목만), 자막 위치는 컷 화면비 세이프존 안 | `services/media-worker/handlers/ffmpeg/storyboard/{audio,captions}/**`(093과 같은 폴더의 하위, 093과 파일 분리) | 088, 093 | P0 | M | Opus(기능) | `loudnorm=true` 출력의 통합 음량이 목표 ±1 LU(측정값 기록), 내레이션 구간 BGM이 비구간보다 낮다(측정), 강조어가 내레이션에 없으면 렌더 전에 22023(DB CHECK와 같은 규칙), 용어집 밖 한자 0, 9:16·4:5·1:1·16:9 각 샘플에서 자막 박스가 세이프존 안(좌표 테스트), 자막 레이어 순서는 VD-F-033 그대로 | VD-F-147, 149, 02장 11.5절 |
| VID-06-095 | 4K 업스케일 단계(D-39 (a)): 잡 `scene.upscale`(`video.media.gpu`), 1440p 이상 렌더의 AI 이미지 장면마다 1장 1크레딧, 새 소재(`meta.upscaled_from`), 실패 장면은 원본 해상도로 렌더하지 않고 렌더 요청을 멈춤. 업스케일 모델·경로(오픈소스 자체 운영 / fal 업스케일 API)는 상업 이용 라이선스와 원가 확인 뒤 정한다(미확인) | `services/media-worker/handlers/storyboard/upscale/**`, `workers/video-orchestrator/src/storyboard/upscale/**` | 011, 085, 087, 092 | P0 | M | Opus(기능·연동) | 04장 10.3절 `scene.upscale` 계약, 출력 크기 = `target`, 같은 소재 두 번 요청 시 업스케일 1회(멱등), 실패 주입 시 그 장면 1크레딧만 환불 1행 + 렌더 잡 미생성, 업스케일 실패 장면이 원본 해상도로 렌더된 출력 0, 사용 모델·라이선스 근거·1장 처리 시간이 task `log.md`에 기록(가격 문서 12장 원가 입력), D-39가 (b)로 정해지면 이 작업은 실행하지 않는다 | VD-F-143, D-39 |
| VID-06-096 | 렌더 원가 벤치(D-41): 같은 스냅샷(롱폼 10분 40장면, 쇼츠 60초)을 1080p30, 1440p30, 2160p30, 1080p60, 2160p60으로 렌더해 처리 시간, CPU 시간, 최대 메모리, 출력 크기를 잰다. 2160p 코덱(H.264 High 5.1 / HEVC) 업로드 호환 확인(02장 11.5절 8단계 미확인 항목) | `services/media-worker/bench/**`, `docs/sceneflow/bench/render-cost.md`(제안) | 093, 094 | P0 | S | Opus(측정) | 측정 표에 조건(서버 사양, FFmpeg 버전, 3회 평균)과 1080p30 대비 배수, 그 배수로 다시 계산한 01장 11.5절 배수 제안과 가격 문서 12장 원가를 함께 적는다. 측정 전 수치를 확정값으로 쓰지 않는다. 결과는 사람이 D-41 `[DECISION]`으로 판정 | D-41, 01장 11.5절 |
| VID-06-097 | 클립 무음·군더더기 말 분석: `POST /api/scenes/[id]/analyze-clip`, 잡 `clip.analyze`(루트 `video.orchestrate` → `video.media.gpu` Whisper 단어 시각(`video.stt` = `oss-voice`, 012 핸들러 재사용) + `video.media.cpu` `silencedetect`), 군더더기 말 사전(088) + 조직 추가 단어, 강도·최소 무음·앞뒤 여유, 단어 경계 컷, 전사 `clip_transcripts` INSERT(service_role), 결과로 `remove_ranges`만 담은 편집안(`source=silence_cut`, LLM 없음) | `src/app/api/scenes/[id]/analyze-clip/**`(074 소유 `api/scenes/` 중 이 하위만), `src/server/storyboards/clip-analysis/**`, `workers/video-orchestrator/src/storyboard/clip/**`, `services/media-worker/handlers/storyboard/silence_detect/**` | 012, 085, 087, 088, 090 | P0 | L | Opus(워커·연동) | 04장 10.1·10.3절 계약, 컷 경계가 단어 타임스탬프 경계와 일치(테스트 샘플), 어절 중간 컷 0, 원본 파일 수정·삭제 0, 전사가 있으면 STT분 0크레딧, 클립 1분당 5크레딧(올림), 실패 시 전액 환불, 원본 오디오가 FastAPI·상용 STT로 가는 경로 0(`ai_usage` stt 행 provider `oss-voice` 100%), clip 장면이 아니면 22023, 승인 전 `cut_ranges` 변경 0 | VD-F-148, D-42, 01장 11.7절 |
| VID-06-098 | 문장 단위 내레이션 다시 만들기와 발음 사전: `regenerate` `part=sentence`(장면 내레이션 문장 분할 규칙, 같은 목소리 규칙 VD-F-106, 문장 범위만 교체 후 이어 붙임), 발음 사전 API(`/api/pronunciation-lexicon` CRUD·일괄 붙여넣기 200개)와 TTS 직전 텍스트 치환 모듈(조직 사전만, `scenes.narration` 원문 불변) | `workers/video-orchestrator/src/storyboard/sentence/**`, `workers/video-orchestrator/src/storyboard/lexicon/**`, `src/app/api/pronunciation-lexicon/**`, `src/server/storyboards/lexicon/**`. `scene.narration` 단계에서 치환 모듈을 부르는 1줄은 053 파일(`steps/tts`)에, `part: 'sentence'` 입력 1줄은 074 파일(`api/scenes/[id]/regenerate`)에 요청 | 053, 072, 074, 085 | P0 | L | Opus(기능·연동) | 문장 다시 만들기 1크레딧, 실패 시 그 문장분 환불 1행, 다시 만든 문장 앞뒤 이음매 무음 100ms 이하(측정값 기록, 제안 기준), 제공자·보이스가 기록값과 다르면 422 `VD013`·대체 호출 0, 문장 번호 범위 밖 22023, 사전 치환 후에도 `scenes.narration` 변화 0, 다른 조직 사전 항목 적용 0, 중복 표기 409 23505, 2,001번째 422 54000 | VD-F-150, 01장 11.7절 |
| VID-06-099 | AI 편집 패널·편집안 검토 시트·편집 기록: AiEditPanel(지시 1,000자, 마이크 받아쓰기 → 텍스트 확인 → `mode=voice`, [자동 다듬기], 편집안 목록), EditPlanReviewSheet(명령 체크박스, 장면별 묶음, BeforeAfterDiff, 예상 크레딧 합계, [적용] [거절]), EditHistorySheet(맨 위 적용 편집안만 [되돌리기]). 기존 082의 음성 지시 UI를 흡수(VoiceCommandSheet 대신 VoiceButton, 03장 9.9절) | `src/components/storyboard/ai-edit/**`. 편집기 오른쪽 칸·상단 버튼 장착 1줄은 079 파일에 요청 | 044, 052, 079, 090, 091, 104 | P0 | L | Sonnet(UI) | 03장 9.1~9.5절 구성, 승인 전 미리보기만(장면 변경 0), 비용 있는 명령에 크레딧 배지와 합계, `VD409` → "다시 제안받기", `VD023` 안내, 402 충전 모달, 명령 0개 "지시를 이해하지 못했습니다", viewer 버튼 0, 음성 고지 미확인 시 마이크 비활성·텍스트 입력 정상, 키보드만으로 명령 선택·적용, `aria-live` 결과 알림, 금지 문구 "AI가 완벽 편집" 0 | VD-F-140, 146, 147, 151, 03장 9장 |
| VID-06-100 | 렌더 설정 패널·변형본 대화상자·초점·세이프존: RenderSettingsPanel(AspectPicker, 해상도·fps, 플랜 밖 값 잠금 표시, CreditMultiplierPreview), AspectVariantDialog(마스터와 다른 화면비만, 크롭 0 / 다시 만들기 장면당 3, 남은 변형본 수), FocusPointPicker, SafeZoneOverlay(YouTube 쇼츠·릴스·틱톡) | `src/components/storyboard/{render-settings,variants,focus}/**`. 새로 만들기 1단계 장착은 078 파일에, 렌더 화면 장착은 081 파일에 1줄 요청 | 044, 078, 079, 081, 088, 092 | P0 | M | Sonnet(UI) | 03장 9.1절 렌더 설정·변형본·초점 행 구성, 형식이 허용하지 않는 화면비 선택지 0, 잠긴 값에 플랜 이름 글자 표시(색만으로 구분하지 않음), 배수 미리보기 값이 서버 응답(`render_multiplier`)과 같다, 초점 키보드 이동(방향키 0.05 단위, 제안), 세이프존 값이 `safe_zones.json`과 같다, 세이프존 밖 화면 문구 경고(차단 아님) | VD-F-143~145 |
| VID-06-101 | 무음·군더더기 말 컷 검토 시트: SilenceCutReview(강도·최소 무음·앞뒤 여유 설정, 분석 진행, 구간 목록(사유, 시작~끝, [듣기], 개별 해제), 잘라낼 합계) → 검토 시트(099)로 넘김 | `src/components/storyboard/silence-review/**` | 097, 099 | P0 | M | Sonnet(UI) | 03장 9.1절 무음 컷 행, 구간마다 듣기·해제, 해제한 구간은 편집안 명령에서 빠짐, 진행률 없는 무한 스피너 0, clip 장면이 아니면 진입 버튼 0, 분석 실패 시 원인 한 줄 + 환불 표시 | VD-F-148 |
| VID-06-102 | 자막 스타일·강조어 편집기: CaptionStyleEditor(3종, 한자 병기 토글), EmphasisChips(장면당 10개, 내레이션 안 단어만) | `src/components/storyboard/captions/**`. 장면 상세 칸 장착 1줄은 079 파일에 요청 | 044, 079, 088, 094 | P0 | M | Sonnet(UI) | 03장 9.1절 자막 행, 내레이션에 없는 단어 칩 추가 불가(서버 23514도 처리), 11번째 칩 비활성, 스타일 미리보기가 `caption_styles.json` 수치와 같다, 한자 병기 켜기 전 "운영자 용어집 항목만" 안내 | VD-F-149 |
| VID-06-103 | 발음 사전 설정 화면: PronunciationTable(언어, 표기 → 읽기, 메모, 검색, 추가·수정·삭제, "n / 2,000") | `src/app/(dashboard)/dashboard/settings/pronunciation/**`(034 소유 `settings/` 중 이 하위만, 설정 메뉴 링크 1줄은 034 파일에 요청) | 034, 044, 098 | P0 | S | Sonnet(UI) | 03장 9.1절 발음 사전 행, viewer 읽기 전용, 중복 표기 안내(23505), 한도 안내(54000), 일괄 붙여넣기 200개 이하 | VD-F-150 |
| VID-06-104 | AI 편집 문구 키와 오류 문구(03장 9.5절), 명령 표시 문장(03장 9.4절), `VD022`·`VD023` 문구 키 | `src/i18n/ai-edit/**`(036 소유 `src/i18n/` 중 이 하위만) | 036, 077 | P0 | S | Haiku(문구) | 03장 9.4·9.5절 문구와 글자 하나까지 같음(스크립트 비교), 01장 11.4절 op 17종 표시 문장 전부, 금지 문구 0(01장 11.7절: "바이럴 보장", "조회수 예측", "편집 시간 N% 절감", "AI가 완벽 편집"), 하드코딩 한국어 문자열 0(린트, 제안) | 03장 9.4·9.5절 |
| VID-06-105 | AI 자동편집 통합 테스트(가짜 제공자, 로컬 Python 워커): 지시 → 편집안 → 일부 승인 → 적용 → regenerate 차감·잡 → 되돌리기, 자동 다듬기, 클립 분석 → 무음 컷 편집안 → 적용 → 렌더, 9:16 변형본, 2160p 렌더(업스케일 포함), 문장 다시 만들기 + 발음 사전 | `tests/integration/ai-edit/**` | 090~095, 097, 098 | P0 | M | Opus(테스트 설계) | 끝까지 통과, 원장 drift 0, 승인 전 장면 변경 0, 편집안 생성 후 장면을 바꾸면 적용 `VD409`, regenerate 1개 실패 주입 시 그 명령분만 환불, 업스케일 실패 주입 시 렌더 잡 0, 변형본 출력 `width/height/fps`가 설정과 같다, 원본 클립 해시 불변 | VD-F-143~151 |
| VID-06-106 | AI 자동편집 사용자 플로우 E2E(03장 9.2절, 현우 흐름) | `tests/e2e/ai-edit/**` | 099~104 | P0 | M | Opus(테스트 설계) | Mock 페르소나 storageState: `adv_owner`(지시 → 검토 → 일부 적용 → 되돌리기 → 9:16 변형본 → 렌더), Basic 조직 페르소나(2160p 잠금 표시·변형본 1개, 05장 10절 페르소나에 없어 004 시드 훅에 추가 요청), `owner`(Starter, AI 편집 잠금 안내), `viewer`(읽기 전용), `outsider`(404). 두 탭에서 편집 후 오래된 편집안 적용 `VD409`, 키보드만으로 명령 선택·적용, 뷰포트 4종(375/768/1024/1440) 스크린샷, 063 완료 뒤 재실행 | 03장 9장, VD-F-143~151 |
| VID-06-107 | 쇼츠 적합도 점수(P1): `video.shorts_pick` 결과에 컷마다 0~100과 근거 태그, ShortsScoreTags | `apps/api/app/ai/graphs/video_shorts_pick.py`(071 완료 뒤 이어 받음), `src/components/storyboard/shorts-score/**`(081 쇼츠 탭 장착 1줄 요청) | 071, 081 | P1 | S | Opus(그래프) | 점수마다 근거 태그 1개 이상, 화면 이름 "쇼츠 적합도(참고용)", 금지 문구 "바이럴 보장"·"조회수 예측" 0, 크레딧 추가 0(선정 2에 포함) | VD-F-152 |
| VID-06-108 | 리테이크 감지와 테이크 선택(P1): `POST /api/scenes/[id]/retakes`, 잡 `clip.retake`(`video.step` kind `retake_group` 1줄 요청), RetakePicker → `source=retake` 편집안 | `src/app/api/scenes/[id]/retakes/**`, `workers/video-orchestrator/src/storyboard/clip/retake/**`, `services/media-worker/handlers/storyboard/retake_detect/**`, `src/components/storyboard/retake/**` | 097, 099 | P1 | M | Opus(기능·연동) | 전사 없으면 409 22023, 기본 선택 마지막 테이크(제안), 고른 테이크 외 구간만 편집안에, 클립 10분당 1크레딧, LLM에 오디오 0(전사 단어·시각만) | VD-F-153 |
| VID-06-109 | 자동 챕터·제목·설명(P1): `POST /api/storyboards/[id]/meta`, 잡 `storyboard.meta`(`video.step` kind `chapters_meta`), YouTube 챕터 조건 미달이면 `chapters: null`, 설명란 순서(대가성 문구 첫 줄 → 설명 → 챕터 → 참고 자료) | `src/app/api/storyboards/[id]/meta/**`, `src/server/storyboards/meta/**`, `workers/video-orchestrator/src/storyboard/meta/**`. 업로드 설명란 조립 1줄은 021 파일에 요청(문구 삽입은 021만, 1절) | 021, 075, 076 | P1 | M | Opus(기능) | 타임스탬프 = 스냅샷 장면 시작 시각, 첫 타임스탬프 0:00·3개 이상·각 10초 이상, `has_affiliate=true` 첫 줄은 대가성 문구 그대로, 금지 문구 0, 1크레딧 | VD-F-154 |
| VID-06-110 | 편집 프리셋(P1): `/api/edit-presets` CRUD, EditPresetForm, 설정 화면, 새 스토리보드·자동 다듬기의 기본 프리셋 적용(089·092에 1줄 요청) | `src/app/api/edit-presets/**`, `src/server/edit-presets/**`, `src/app/(dashboard)/dashboard/settings/edit-presets/**`(034 소유 `settings/` 중 이 하위만), `src/components/storyboard/presets/**` | 089, 092, 103 | P1 | M | Sonnet(UI) | 03장 9.1절 프리셋 행, 개수 초과 403 `VD009`, 모르는 키 422 23514, 다른 고객 프리셋 `VD002`, 저장 0크레딧, 고객 A 프리셋이 고객 B 스토리보드 선택지에 0 | VD-F-155, 08장 규칙 |
| VID-06-111 | 자동 B-roll 제안(P1): `mode=broll`(빈도 낮음·보통·많음), 명령은 `add_scene` + `set_text`만, 사실 주장 카드 `source_required=true`, AI 이미지는 승인 후 regenerate | `apps/api/app/ai/graphs/video_edit_plan.py`의 broll 노드(089 완료 뒤 이어 받음), `src/components/storyboard/broll/**`(099 패널 장착 1줄 요청) | 089, 090, 099 | P1 | M | Opus(그래프) | 편집안 명령 종류가 두 가지뿐, 장면 수 한도(`VD018`)·길이 합계를 넘는 명령 제외 + 안내, 제안 2크레딧 + 승인한 AI 이미지 장면 3 | VD-F-156 |
| VID-06-112 | 자동 썸네일 3안(P1): `POST /api/storyboards/[id]/thumbnails`, 잡 `storyboard.thumbnail`(문구 `video.step` kind `thumbnail_copy` + FFmpeg 합성), ThumbnailOptions(업로드 화면 썸네일 칸) | `src/app/api/storyboards/[id]/thumbnails/**`, `workers/video-orchestrator/src/storyboard/thumbnail/**`, `services/media-worker/handlers/storyboard/thumbnail/**`, `src/components/storyboard/thumbnail/**`(032 업로드 화면 장착 1줄 요청) | 032, 075 | P1 | M | Opus(기능) | 3안 1280x720, 문구 30자 이하, 금지 문구가 든 안 0(재생성 1회 후 422), AI 이미지 썸네일은 AI 생성 표시 규칙(01장 10.5절), 2크레딧(+ AI 이미지 3) | VD-F-157 |
| VID-06-113 | NLE 내보내기(P1): `POST /api/storyboards/[id]/nle-export`, 잡 `storyboard.nle_export`(FCPXML, Premiere XML, SRT, 소재 zip), 서명 URL 24시간 | `src/app/api/storyboards/[id]/nle-export/**`, `services/media-worker/handlers/storyboard/nle_export/**` | 075, 085, 087 | P1 | M | Opus(기능) | XML의 장면 순서·길이·전환이 렌더 스냅샷과 같다(스크립트 비교), DaVinci·Final Cut·Premiere 가져오기 수동 점검표 기록(자동화 불가 항목), `nle_export=false` 403 `VD009`, 0크레딧 | VD-F-158 |
| VID-06-114 | 연도·인물 표기 일관성 점검(P1): 076 출처 점검 잡에 같은 인물·사건 연도·이름 표기 불일치 WARN 추가 | `workers/video-orchestrator/src/storyboard/source-check/**`(076 완료 뒤 이어 받음), `packages/video-rules/edit/eval/consistency/**`(평가 샘플) | 076 | P1 | S | Opus(기능) | 불일치 샘플에서 WARN 1건 이상, FAIL로 올리지 않음(D-33), 추가 크레딧 0(출처 점검 1 안), "사실 확인 완료" 같은 보증 문구 0 | VD-F-159 |

### 10.2 웨이브와 게이트

AI 자동편집 작업은 3절 웨이브, 9.2절 S 웨이브와 나란히 가는 E 웨이브로 묶는다. 주력 기능(SF-5)이라 P0 작업(085~106)은 모두 W7(G1, 공개 베타) 전에 끝낸다. W7은 9.2절 S8과 이 절 E7 완료를 함께 기다린다.

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 같은 시기 | 산출물 |
|---|---|---|---|---|---|
| E1 | 085 | 1 | 066 완료 | W2(S2) | AI 편집·화면비 스키마, 타입 |
| E2 | 086, 087, 088, 104 | 4 | 085(+ 086은 068, 087은 069, 104는 077) | W3(S3) | RLS 테스트, 단가·배수·게이팅, 규칙 파일·평가 문장, 문구 키 |
| E3 | 093 → 094 | 1 → 1 | 073 완료(093이 이어 받음), 085 / 094는 088·093 | W4~W5 | 렌더 프로필, 오디오·자막 |
| E4 | 089, 096, 097 | 3 | 089는 049(W5)·071·088, 096은 093·094, 097은 012·088·090(편집안 저장 경로만, 090 전에는 서버 함수 스텁) | W5~W6 | 편집 그래프, 렌더 원가 벤치(01장 D-41의 "W5 렌더 벤치"), 클립 분석 |
| E5 | 090 → 091, 092, 095, 098 | 1 → 4 | 090은 074·087(그래프 평가 전에는 픽스처), 091은 072(S6), 092는 075(S7 전반), 095는 092, 098은 053·072 | W6 뒤 새 웨이브(S6~S7) | 편집안 생성·적용·되돌리기 API, 렌더 설정·변형본 API, 업스케일, 문장 다시 만들기·발음 사전 |
| E6 | 099, 100, 102, 103 → 101 | 4 → 1 | 화면은 044·079(S5), 100은 081(S7), 101은 097·099 | S7과 같은 시기 | AI 편집 패널·검토 시트·기록, 렌더 설정·변형본·초점, 자막 편집, 발음 사전 화면, 무음 컷 검토 |
| E7 | 105, 106 | 2 | E6, S7 | S8과 같은 시기, W7 직전 | 통합 테스트, E2E |
| W8 | 107~114 | 8(선행 따라 순서) | G1 뒤, 각 행 선행 | W8 | P1 8개 |

| 게이트 | 조건 | 판정 |
|---|---|---|
| E-스키마 | 085 수용 기준과 086 녹색 전에는 편집안 API(090·091)와 렌더 설정 API(092)를 머지하지 않는다 | CI(039, 086) |
| E-EDL 계약 | 명령 허용 목록 정본은 01장 11.4절 하나다. `edl.schema.json`(089) ↔ zod(090) ↔ pydantic(089) ↔ DB `video.valid_edit_commands`(`1200_video.sql:3254`)가 같은 op·키·범위를 받는지 계약 테스트(op 17종 × 허용·거부 샘플) 통과 전에는 090·091 머지 금지 | 089·090 단위 테스트 |
| E-그래프 평가 | 089 평가 결과(일치율, 허용 밖 0, 금지 문구 0)를 기록하기 전에는 090이 실제 제공자 경로를 켜지 않는다. 그 전 099는 090의 고정 JSON 픽스처로 개발한다 | `pytest apps/api -k edit` |
| E-렌더 계약 | 093·094의 스냅샷 입력과 092·075가 만드는 스냅샷이 04장 10.3절 키(`render`, `style`, `focus`, `transition`, `clip`, `caption_emphasis`, `crop_from`)와 같다는 계약 테스트 통과 전에는 092 머지 금지 | 092 단위 테스트 |
| 결정 게이트 | D-41: 096 측정 결과로 사람이 판정한다. 판정 전 087은 01장 11.5절 제안 배수를 상수로 두고, 판매 페이지(035)에 1440p·2160p·60fps 단가를 확정값으로 쓰지 않는다. D-39: (a)면 095 실행, (b)면 095 실행 안 함. D-42: 088 기본 보수. D-40: 090은 버튼 방식(b)만 구현(첫 1회 무료는 가격 결정 뒤 087에 1줄). D-38: 10.6절. D-43: 9:16 롱폼 업로드는 결정 전 (a) 제안값으로 021에 1줄 요청. D-44: Phase 2 | 사람이 task `log.md`에 `[DECISION]` |
| G1(8.2절에 더함) | video 기준 (1)에 10장 P0 작업 22개 완료, (2)에 106 녹색, 파이프라인 기준에 105 녹색을 더한다 | 사람(대표님) `[DECISION] G1 통과` |

P0 작업과 테스트 작업 대응(3절, 9.2절 규칙에 더함): 스키마·단가(085, 087) → 086 / 그래프·API·워커(088~095, 097, 098) → 105 / 화면(099~103), 문구(104) → 106 / 벤치(096)는 테스트가 아니라 D-41 판정 자료 / AI 경계(그래프 토큰 scope `graph:video.edit_plan`, 클립 오디오 국외 전송 0, 음성 지시 원본 미저장)는 055에 항목 1줄 요청.

### 10.3 코어·공용 요청 (6절, 8.3절, 9.3절 표에 이어서)

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 | 시점 |
|---|---|---|---|---|---|
| R-V16 | `_supabase-modular/seed.sql` | video 플랜 4행 `features`에 `render_max_resolution`, `render_max_fps`, `render_4k60`, `aspect_variants_max`, `ai_edit`, `nle_export`, `edit_presets_max` 추가(값은 01장 11.6절, 제안). 모놀리스 seed에는 반영됨(05장 12.8절) | R-V1·R-V12와 같다: seed가 1200보다 나중에 실행되면 085의 병합 UPDATE가 덮어써진다 | 서버(087)가 누락 키를 기본값(Starter 값)으로 읽는다 | MVP |
| R-V17 | ai_providers | (a) 업스케일 경로(D-39)를 외부 API로 정하면 그 제공자를 레지스트리에 편입(국외 이전 필터, R-V3과 같은 방식) (b) D-38 (b) 채택 시 고품질 이미지 제공자(GPT Image 2 등) 편입 | 국외 이전 동의 필터를 코어 라우팅 밖 제공자에도 걸어야 한다 | (a) 오픈소스 업스케일 모델(라이선스 확인 뒤) (b) 고품질 선택지를 노출하지 않는다 | D-38·D-39 판정 뒤 |
| R-V18 | `_platform-core`, 공용 패키지 | R-V13 공용 스토리보드 모듈에 편집 명령 목록(EDL) 스키마·승인 흐름·되돌리기 패턴 포함 검토. book-trailer·toon-factory와 함께 | 세 제품이 장면 편집 명령을 따로 정의하면 갈린다 | MVP는 `packages/video-rules/edit/edl.schema.json`(제품 이름 하드코딩 없이) | Phase 2 |

### 10.4 기존 작업에서 범위가 바뀐 것

같은 줄 수정으로 "(10장 ...)"를 단 줄은 1절 12·14·15·16·19행, 3절 115·120행, 4절 표(126~129행)와 131행, 7절 232행, 8.2절 253행, 9.1절 082 행(327행), 9.2절 W8 행(345행), 9.6절 음성 지시 경로 행(416행), 머리말 5행이다. 줄 수는 그대로다.

| 작업 ID | 이전 범위 | 바뀐 범위 | 대체·이동 |
|---|---|---|---|
| VID-06-082 | 음성 지시 편집(P1, W8): 받아쓰기 → `video.step` kind `scene_command` 패치 → `save_scene` 적용, 별도 `POST .../command` 경로 | 실행하지 않는다(흡수). 음성 입력은 AI 편집 지시의 입력 방식 하나가 되어 MVP P0로 올라간다(01장 VD-F-140 "MVP로 올림", 04장 10.1절 `/command` 대체). 적용은 `save_scene`이 아니라 `apply_edit_plan` | 090(`mode=voice` 서버 경로), 099(마이크 버튼 UI) |
| VID-06-073 | FFmpeg 스토리보드 렌더: 16:9·9:16, 전환 없음(10.3절 "Phase 2"), 고정 -12dB 덕킹 | 화면비 4종·해상도·fps, 초점 크롭, xfade 전환, `clip` 컷 구간, sidechain 덕킹·loudnorm, 자막 스타일·강조·한자 병기. 073 완료 뒤 같은 폴더를 093·094가 이어 받는다 | 093, 094 |
| VID-06-074 | 스토리보드 API(화면비는 형식이 정함, 장면 다시 만들기 image·narration) | 새로 만들기 입력에 `aspect`·`resolution`·`fps` 등(092가 1줄 요청), `regenerate` `part=sentence`(098이 1줄 요청), `api/scenes/[id]/analyze-clip`·`retakes` 하위는 097·108 소유 | 092, 097, 098, 108 |
| VID-06-075 | 렌더·쇼츠 API(단가 = 길이 렌더 단가) | 렌더 단가 × 해상도·fps 배수, 업스케일 선행 단계, `estimate` 분해, 쇼츠 `image_mode`(092가 1줄 요청). 변형본은 새 경로 `variants`(092) | 092 |
| VID-06-069 | Track S 단가 | 렌더 단가에 배수를 곱하는 1줄(087이 요청). AI 편집 단가는 `billing/ai-edit.ts`(087) | 087 |
| VID-06-053 | 장면 내레이션 TTS | TTS 직전 발음 사전 치환 1줄(098이 요청) | 098 |
| VID-06-071, 076 | `video.shorts_pick`, 출처 점검 | P1에서 쇼츠 적합도 점수(107), 일관성 점검(114)이 완료 뒤 이어 받는다 | 107, 114 |
| VID-06-034 | 설정 화면 `settings/` 단독 | `pronunciation/`(103), `edit-presets/`(110) 하위만 예외 | 103, 110 |
| VID-06-001, 002, 005, 049 | 스키마, RLS 테스트, 단가표, `graphs/`·`video-rules/` | 13절은 085, 테스트는 086(`tests/ai-edit/`), 단가는 087(`billing/ai-edit.ts`), 그래프 파일 `video_edit_plan.py`는 089, `video-rules/edit/`는 088·089 | 085~089 |

### 10.5 작업 수와 모델 비율

| 구분 | 작업 수 | 내용 |
|---|---|---|
| 전체 ID | 114개 | 2절 62 + 8절 3 + 9장 19 + 10장 30. 모델 작업 113, 사람 1(043) |
| MVP 계획 | 108개(모델 107, 사람 1) | P0 88(9.5절 66 + 10장 22), P1 20(9.5절 13 − 흡수 082 + 10장 8). P1 중 W8 작업(057~062, 064, 065, 107~114)은 MVP 출시 뒤 웨이브 |
| Phase 2로 옮김 | 3개 | 019, 020, 031(변화 없음) |
| 대체·흡수되어 실행하지 않음 | 3개 | 018, 030(9장 작업이 대체), 082(10장 090·099로 흡수) |

10장 30개 내역: Fable 3(085 M, 086 M, 087 M), Opus 19(089·090·093·097·098 L, 091·092·094·095·105·106 M, 096 S / P1 108·109·111·112·113 M, 107·114 S), Sonnet 7(099 L, 100·101·102 M, 088·103 S / P1 110 M), Haiku 1(104 S). 빠진 것: Opus 1(082, M).

모델 비율(MVP 계획의 모델 작업 107개 기준, 4절 표를 같은 줄 수정으로 갱신함):

| 모델 | 이전(78개, 9.5절) | 지금(107개) | 규모 가중(S=1, M=2, L=3) 이전 → 지금 |
|---|---|---|---|
| Fable | 16(20.5%) | 19(17.8%) | 33/159(20.8%) → 39/217(18.0%) |
| Opus | 39(50.0%) | 57(53.3%) | 85/159(53.5%) → 123/217(56.7%) |
| Sonnet | 19(24.4%) | 26(24.3%) | 37/159(23.3%) → 50/217(23.0%) |
| Haiku | 4(5.1%) | 5(4.7%) | 4/159(2.5%) → 5/217(2.3%) |

변화 요인: 그래프·워커·API·테스트가 많아 Opus 몫이 늘었다(규모 가중 56.7%). Fable 비율은 줄었지만 과금(087)·스키마(085)·RLS(086) 경계는 그대로 Fable이 맡는다. 작업 수 114개는 `DOC_TEMPLATE.md`의 15~40개 권장을 크게 넘는다. 9장까지와 같은 이유(트랙·AI 계층이 모두 MVP)에 주력 기능 SF-5가 더해졌고, 화면·워커·그래프의 소유 경로가 달라 합치면 동시 쓰기가 생겨 나눴다. 저장소 전체 작업 합계는 981 + 30 = 1,011개다(루트 README 반영은 별도).

### 10.6 확인 필요(열린 항목)

| 항목 | 내용 |
|---|---|
| 라우팅 기능 키 | `video.edit_plan`(llm) 행이 1200 11절 라우팅 seed(`1200_video.sql:1882-1898`)와 02장 5.1절에 없다. 9장 그래프(`video.storyboard`, `video.shorts_pick`)도 같은 상태다(미확인: 049 체인을 그대로 쓰는지). 제안: 085가 `video.edit_plan` 행을 더하고 055 라우팅 스냅샷(17행)을 갱신한다. 기본 체인은 가격 문서 12장 SF-P-7(저가 모델 우선, 제안)을 따른다 |
| D-38 고품질 이미지 경로 | 이 장에 작업이 없다. (b)로 정하면 072 이미지 단계·087 단가·099 비용 배지에 걸친 새 작업이 필요하다(제안: 그때 VID-06-115부터, Phase 2 또는 P1). 가격은 가격 문서 12장 SF-P-9 |
| 업스케일 모델 | 오픈소스 자체 운영과 fal 업스케일 API 중 무엇을 쓸지, 상업 이용 라이선스와 1장 원가가 미확인이다(095, 02장 11.4절) |
| 2160p 코덱 | H.264 High 5.1과 HEVC 중 플랫폼 업로드 호환 확인은 096 벤치에서 한다(02장 11.5절 8단계 미확인) |
| Basic 페르소나 | 05장 10절 시드 페르소나에 Basic 조직이 없다. 106의 Basic 잠금 시나리오용 페르소나(제안 `basic_owner`)를 004 시드 훅에 1줄 요청한다 |
| 편집 지시 평가 기준 | 089 일치율의 통과 기준은 정하지 않았다. 01장 11.8절 KPI(해석 실패율 5% 이하, 제안)를 첫 기준으로 쓰고 첫 측정 뒤 사람이 정한다 |
