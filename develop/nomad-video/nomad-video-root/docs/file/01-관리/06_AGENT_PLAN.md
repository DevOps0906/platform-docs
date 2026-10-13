# 06 에이전트 작업 계획: NOMAD AI Factory (nomad-video)

작업 ID는 `VID-06-###`(DB_CONVENTIONS 1장 SQLSTATE 접두사 `VD`의 작업 약어). 모델 기준은 `docs/file/03-설계/공용코어/DOC_TEMPLATE.md` 1장: Fable(결제, 권한, RLS, 데이터 모델), Opus(기능 구현, API 연동, 테스트 설계), Sonnet(UI, 메인페이지, 컴포넌트, 문서), Haiku(보일러플레이트, 린트/타입, 문구, 반복 체크).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 4장) 작업 16개(VID-06-041~056)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 012(사용량 기록), 016(대본·TTS 이관), 036(디자인 시스템 2단계 토큰), 004·023·028·035·038(선행 추가), 001·003·005·021·039(수용 기준 보강)이다. 작업 수 56개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. 기존 40개가 이미 한도를 넘었고(Track A~F 전부 MVP, 확정 결정 7) AI·음성·3D·디자인 시스템이 MVP에 들어와 작업 하나를 더 합칠 수 없어 분리했다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 아래 표의 디렉토리만 만든다·고친다. 다른 작업의 디렉토리를 고쳐야 하면 그 작업 소유자에게 요청 작업을 남긴다 |
| 공용 파일 | `apps/nomad-video/src/lib/**`(env, core 래퍼)은 VID-06-003, `src/server/billing/**`(게이팅·단가)는 VID-06-005만 수정. 다른 작업은 import만 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, 공용 패키지(`packages/core-*`) 수정 금지. 필요하면 6절 코어 요청 |
| DB | 스키마 변경은 VID-06-001(Fable)만. 모놀리스는 변환 스크립트로만 생성 |
| 테스트 | 모든 P0 작업은 3절 웨이브 표의 테스트 작업(002, 007, 037, 038, 055) 중 하나에 대응한다 |
| AI 서비스 경계 | `apps/api/`는 VID-06-045가 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. video 확장은 작업별로 나눈다: 047 `app/ai/products/video/knowledge.py`, 048 `app/ai/products/video/wiki_config.py`, 049 `app/ai/graphs/`·`app/ai/compliance/video.py`, 050 `app/ai/tools/video/`. FastAPI는 영상·오디오 바이너리를 처리하지 않고 미디어 워커는 LLM 키를 갖지 않는다(02장 2절 경계 표) |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(R-V5~R-V10) |
| 사람 작업 | VID-06-043(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(004, 023, 028~035, 048, 051, 054, 056)은 VID-06-044(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:48`) |
| 대가성 문구 | 문구 삽입은 VID-06-021만 한다. AI 작업(049, 050)은 문구를 쓰거나 지우지 않고 규칙 파일로 모방 문장을 제거만 한다(확정 결정 12) |

| 영역 | 경로(제안 모노레포) |
|---|---|
| DB | `supabase/migrations/1200_video.sql`, `supabase/monolith/**`, `scripts/mono-convert.mjs` |
| 웹 공통 | `apps/nomad-video/src/{proxy.ts,lib/**}`, `package.json` |
| 서버 도메인 | `apps/nomad-video/src/server/<domain>/**` |
| API | `apps/nomad-video/src/app/api/<domain>/**` |
| 화면 | `apps/nomad-video/src/app/(dashboard)/dashboard/<area>/**`, `src/components/<area>/**` |
| 워커 | `workers/video-orchestrator/src/<area>/**`, `services/media-worker/**`, `packages/sns-uploader/**` |
| 테스트 | `supabase/tests/**`, `tests/{e2e,integration}/<area>/**` |
| AI 서비스 | `apps/api/**`(Python), `packages/video-rules/**` |
| AI 게이트·음성 | `apps/nomad-video/src/app/api/{ai,internal,onboarding,voice,wiki}/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` |
| AI·음성 UI | `src/components/{ai-chat,voice,voice-engine,script-plan,wiki,hero3d,ui}/**`, `src/app/(dashboard)/dashboard/{chat,wiki}/**`, `src/app/dev/components/**` |
| Dify·지식 | `infra/dify/**`, `scripts/{knowledge,ai-routing}/**` |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| VID-06-001 | 1200 조각 적용, 모놀리스 변환 스크립트, 타입 생성(`--schema core,video`) | `supabase/migrations/1200_video.sql`, `supabase/monolith/**`, `scripts/mono-convert.mjs`, `apps/nomad-video/src/types/supabase.ts` | 없음 | P0 | M | Fable(데이터 모델) | `supabase db reset` 성공, 체커 OK(모듈러·모놀리스), 타입 파일에 22개 테이블, 11절 AI 라우팅 17행과 체인 검사 DO 블록 통과 | 05장, SM 작업 6, BS 작업 1·11·14 |
| VID-06-002 | RLS/권한 회귀 테스트(PGlite + 로컬 Supabase) | `supabase/tests/**` | 001 | P0 | M | Fable(RLS) | 05장 9절 65항목 + SECURITY_BASELINE 15장이 CI에서 통과, 실패 시 머지 불가 | SM 작업 1·15, BS 작업 1, YSM 작업 6 |
| VID-06-003 | 앱 골격: `proxy.ts` 공개 경로 배열, `lib/env.ts`(zod), 코어 클라이언트 3계층 연결, `requireSession`, enqueue 전용 lazy Redis 모듈, 응답 봉투 | `apps/nomad-video/src/proxy.ts`, `src/lib/**`, `package.json` | 001 | P0 | M | Opus(골격·연동) | 비로그인 `/dashboard` 302, `/landing/x` 200, env 누락 시 기동 실패, `x-internal-call` 문자열 0건, 02장 8절 AI 변수(`AI_TOKEN_PRIVATE_KEY` 등)는 Next.js 서버 범위만 검증하고 `NEXT_PUBLIC_`에 비밀 0 | SM 작업 3·4·8·10·12, BS 작업 5·7·13, YSM 작업 9 |
| VID-06-004 | 로그인·가입·온보딩 화면(`signup_app='video'`, 프로필 없으면 로그아웃) | `src/app/(auth)/**`, `src/components/auth/**` | 003, 044 | P0 | S | Sonnet(UI) | 가입 직후 Starter 100크레딧 표시, Mock 로그인 없음, 네이버 로그인 없음 | SM 작업 4, BS 작업 4, YSM 작업 5 |
| VID-06-005 | 플랜 게이팅·단가표(`priceOf`)·크레딧 래퍼(consume→enqueue→환불, 부분 환불) | `src/server/billing/**` | 003 | P0 | M | Fable(과금·권한) | 01장 4절 단가와 일치하는 단위 테스트, Starter Track B 403 VD009, 동시 50요청 음수 0, AI 단가(01장 4.1절)와 `src/server/ai-pricing.ts`(046) 값이 같은지 비교하는 테스트 | BS 작업 2, 01장 VD-F-003/091 |
| VID-06-006 | 결제: 주문 선저장, confirm, 빌링키, 해지, Advanced 할인 팩 판정, PM001 운영 알림·취소 | `src/app/api/billing/**`, `src/server/payments/**`, `src/app/billing/**` | 005 | P0 | L | Fable(결제) | 금액 위조 PM001 + `fail_payment_order` 호출 + 취소 호출, 같은 결제 2회 멱등, 비Advanced의 adv 팩 403 | SM 작업 2, BS 작업 3, 01장 VD-F-090 |
| VID-06-007 | 결제 E2E(Toss 테스트 키): 구독, 크레딧팩, 실패 복귀 | `tests/e2e/billing/**` | 006 | P0 | M | Opus(테스트 설계) | 3시나리오 통과, 원장·엔타이틀먼트 기대값 일치 | SM 작업 2, DOC_TEMPLATE 필수 |
| VID-06-008 | 채널 OAuth 연결·콜백·역할 변경·해제(코어 oauth, 자격증명 vault), 다채널 위험 동의 | `src/app/api/channels/**`, `src/server/channels/**` | 003, 001 | P0 | M | Fable(OAuth·권한) | state 재사용 OA001, Starter 2번째 채널 VD003, 오류 원문을 쿼리스트링에 싣지 않음, 토큰 평문 0 | SM 작업 4, BS 작업 8, YSM 작업 4·10·13 |
| VID-06-009 | sns-uploader YouTube: resumable 스트리밍, 고정 댓글, 쿼터, 대체 채널 선택, 재예약 | `packages/sns-uploader/src/{youtube,registry.ts,types.ts}` | 008 | P0 | L | Opus(API 연동) | 1GB 파일 업로드 시 RSS 512MB 이하, 쿼터 초과 시 대체 채널 또는 `run_after` 재예약 | SM 작업 12 |
| VID-06-010 | sns-uploader Meta(IG Reels, Threads)·TikTok 어댑터 | `packages/sns-uploader/src/{meta,tiktok}/**` | 009 | P1 | M | Opus(API 연동) | 샌드박스 계정 업로드 성공, 토큰 만료 시 credentials error + 재연결 요청 | 01장 VD-F-071 |
| VID-06-011 | Python 미디어 워커 골격: claim/heartbeat/complete/fail 루프, 취소 신호, 하위 프로세스 타임아웃·kill, settings 검증, pytest | `services/media-worker/{core,tests}/**` | 001 | P0 | M | Opus(워커) | 타임아웃 초과 프로세스 kill 후 fail_job, 하트비트 60초, pytest 통과 | SM 작업 7, BS 작업 9, YSM 작업 8·11·12·15 |
| VID-06-012 | Whisper STT(모델 1회 로드, 동시성 1), demucs 핸들러. 호출마다 사용량 기록(052의 `handlers/usage/`) | `services/media-worker/handlers/{stt,separate}.py` | 011 | P0 | M | Opus(기능) | 60초 중국어 클립 세그먼트 반환, 전역 asyncio Lock 없음, 호출 1건당 `core.ai_usage` stt 행 1개(provider `oss-voice`, feature `video.stt`, `audio_seconds`), 공용 음성 서버와 같은 세그먼트 형식(01장 D-13) | YSM 작업 11·12 |
| VID-06-013 | FFmpeg 핸들러: 워터마크 제거·삽입, 무음컷(-30dB/0.5초), ASS+강조 자막 합성, 인코딩, 켄번스, 루프, 플리 연결, 하이라이트 컷 | `services/media-worker/handlers/ffmpeg/**` | 011 | P0 | L | Opus(기능) | 04장 4절 계약대로 결과 경로 반환, 레이어 순서 테스트, 3시간 플리 90분 이내 | YSM 작업 12, 01장 VD-F-030~050 |
| VID-06-014 | 다운로더(YSM 이식): 도메인 허용 목록, `--`, 프록시 풀, pHash, 24시간 원본 삭제 | `services/media-worker/handlers/{download,purge}.py` | 011 | P0 | M | Opus(기능) | 허용 목록 밖 URL 거부, purge 후 객체 없음 | BS 작업 12, YSM 작업 12 |
| VID-06-015 | TS 오케스트레이터: FlowProducer 트랙별 플로우, Python 브리지(자식 core.jobs), 상태 미러링, 언어별 부분 환불 | `workers/video-orchestrator/src/{flows,bridge,index.ts}` | 005, 011 | P0 | L | Fable(아키텍처·과금) | placeholder 0건, 단계 결과 returnvalue 전달, JA 실패 시 JA분만 환불 | SM 작업 3·7·12, BS 작업 9 |
| VID-06-016 | AI 단계: 번역(톤), fal 이미지, Suno. 대본·LLM 호출 경로는 049, TTS는 053으로 이관(2026-10-13) | `workers/video-orchestrator/src/steps/{translate,image,music}/**` | 015 | P0 | M | Opus(API 연동) | 라우팅 체인 밖 모델 요청 거부, 제공자 오류 시 폴백 1회 후 실패(mock 반환 0), OpenAI TTS 코드 0(01장 D-14) | SM 작업 10, BS 작업 11, YSM 작업 7 |
| VID-06-017 | 소싱·숏폼 생산 API(견적, 생성, 조회, 취소, 동시 생산 상한) | `src/app/api/{sources,productions}/**`, `src/server/{sources,productions}/**` | 005, 015 | P0 | M | Opus(기능) | 같은 request_id 재요청 시 차감 1회, 세션 org와 다른 행 404 | YSM 작업 6, 01장 VD-F-020~035 |
| VID-06-018 | 롱폼 API: 점수 게이트, 스토리라인, 10섹션, 렌더, OSMU | `src/app/api/longform/**`, `src/server/longform/**` | 005, 015 | P0 | M | Opus(기능) | 점수 59 → VD010 + 대안 3, 하이라이트 3개 각 60초 이하, 목업 응답 0 | BS 작업 10, 01장 VD-F-040~041 |
| VID-06-019 | Track E API: 곡 생성, 루프 영상, 유통 패키지, 상태 기록 | `src/app/api/music/**`, `src/server/music/**` | 005, 015 | P0 | M | Opus(기능) | 곡 1개 = music_tracks 1 + outputs(music_loop) 1, none→live 22023 | 01장 VD-F-050~051 |
| VID-06-020 | Track F API: 플리, 항목 정렬, 라이브러리 등록, 트랙리스트·타임스탬프·고정 댓글 생성, 렌더 | `src/app/api/{playlists,library}/**`, `src/server/playlists/**` | 005, 015 | P0 | M | Opus(기능) | 합계 시간 ±5% 밖 409, 만료 라이선스 곡 VD006, 타임스탬프가 실제 연결 결과와 일치 | 01장 2절 E/F 구분표 |
| VID-06-021 | 업로드 API: 문구 삽입, compliance 게이트(규칙+LLM), WARN 확인, 예약, 취소 | `src/app/api/uploads/**`, `src/server/publish/**` | 009, 022 | P0 | L | Opus(기능) | 제휴 링크 있는 업로드의 설명란·고정 댓글 첫 줄 = 문구, FAIL 업로드 예약 불가, LLM 오류 시 WARN, 그래프 생성물에 문구가 없는 것이 정상이며 첫 줄 삽입은 이 작업만 수행(VD-F-103), LLM 판정은 `video.step`(049) 경유 | 01장 VD-F-062/072 |
| VID-06-022 | 제휴 통합: 계정 연결(쿠팡 API, 텐핑·네이버쇼핑 커넥트 수동), 단축 링크, `/r/[code]`, 문구 편집 | `src/app/api/affiliate/**`, `src/app/r/**`, `src/server/affiliate/**` | 003 | P0 | M | Opus(API 연동) | `/r/` 302 + 클릭 1행(IP 해시만), 레이트 리밋 60/분, 문구 10자 미만 거부 | 확정 결정 12 |
| VID-06-023 | 공개 페이지 `/landing/[slug]`(ISR, params await), `/lb/[handle]`, 조회수 집계 | `src/app/{landing,lb}/**`, `src/components/public/**` | 001, 022, 044 | P0 | M | Sonnet(UI) | 비로그인 200, 대가성 문구 렌더, 비공개 404 | SM 작업 5, BS 작업 5 |
| VID-06-024 | 레이더 수집·API: 플레이보드(난수 0), 채널파인더, 블링(출처 필수, 월 한도) | `workers/video-orchestrator/src/radar/**`, `src/app/api/radar/**`, `src/server/radar/**` | 015 | P1 | M | Opus(API 연동) | growth_rate 미산출 시 null + 추정 배지, Pro 21번째 블링 VD012 | SM 작업 9, BS 작업 10 |
| VID-06-025 | 웹훅 수신: Toss(코어 위임), fal, (Phase 2) Distrokid·Make 서명 필수 골격 | `src/app/api/webhooks/**` | 003 | P0 | S | Opus(연동) | 서명 없는 요청 401, 중복 200 | SM 작업 11, BS 작업 6 |
| VID-06-026 | 성과 수집(YouTube Analytics 스냅샷) | `workers/video-orchestrator/src/analytics/**` | 009 | P1 | S | Opus(연동) | 일 1회 스냅샷, 실패 시 이전 값 유지 | 01장 VD-F-080 |
| VID-06-027 | 스케줄러: reap, purge, 예약 업로드 enqueue, 쿼터 리셋, 월 지급, 빌링 청구, 보존 기간 삭제 | `workers/video-orchestrator/src/cron/**` | 015 | P0 | S | Opus(워커) | CRON_SECRET 공개 라우트 0, 각 작업 멱등 | SM 작업 3 |
| VID-06-028 | 대시보드 홈 + 잡 진행률 Realtime(서버 컴포넌트, 더미 0) | `src/app/(dashboard)/dashboard/page.tsx`, `src/app/(dashboard)/layout.tsx`, `src/components/{shell,jobs}/**` | 003, 044 | P0 | M | Sonnet(UI) | 더미 배열 0, Realtime 끊김 시 폴링 | SM 작업 9 |
| VID-06-029 | 소싱·숏폼 화면 | `src/app/(dashboard)/dashboard/{sources,shorts}/**`, `src/components/shorts/**` | 017, 028 | P0 | M | Sonnet(UI) | 예상 크레딧 표시, 402 안내 문구 | 03장 |
| VID-06-030 | 롱폼 스토리보드 화면 | `src/app/(dashboard)/dashboard/longform/**`, `src/components/longform/**` | 018, 028 | P0 | M | Sonnet(UI) | 잠금 상태 편집 비활성 | 03장 |
| VID-06-031 | 곡·플리·라이브러리 화면 | `src/app/(dashboard)/dashboard/{music,playlists,library}/**`, `src/components/music/**` | 019, 020, 028 | P0 | M | Sonnet(UI) | E/F 메뉴·색 분리, 키보드 정렬 대체 | 확정 결정 E/F 구분 |
| VID-06-032 | 채널·업로드 화면(설정·배포 대형 페이지를 섹션 컴포넌트로 분할) | `src/app/(dashboard)/dashboard/{channels,publish}/**`, `src/components/publish/**` | 008, 021, 028 | P0 | M | Sonnet(UI) | 문구 첫 줄 잠금 표시, WARN 확인 흐름, 파일당 400줄 이하(제안) | YSM 작업 14 |
| VID-06-033 | 수익화 화면(제휴 계정·링크·통계, 랜딩, 링크인바이오, 문구 편집) | `src/app/(dashboard)/dashboard/monetize/**`, `src/components/monetize/**` | 022, 023, 028 | P0 | M | Sonnet(UI) | 문구 끄기 UI 0, 공개 버튼이 VD001/VD009 안내 | 확정 결정 12 |
| VID-06-034 | 레이더·분석·크레딧·결제 화면 | `src/app/(dashboard)/dashboard/{radar,analytics,credits,billing,settings}/**`, `src/components/{radar,analytics,billing}/**` | 006, 024, 028 | P0 | M | Sonnet(UI) | 추정 배지, 블링 출처 목록, 원장 표 | 03장 |
| VID-06-035 | 마케팅 랜딩·요금·약관 페이지(frontend-design 절차, MASTER.md) | `src/app/(marketing)/**`, `src/app/legal/**`, `design-system/nomad-video/**` | 036, 044, 054 | P0 | M | Sonnet(메인페이지) | 03장 4절 체크(4.5절 3D 히어로는 054의 `Hero3D`를 장착), 금지 문구 0, DESIGN_PRINCIPLES 7단계 체크리스트 통과 | 03장 4절 |
| VID-06-036 | 디자인 시스템 2단계 토큰: 토큰 파일(라이트 랜딩·다크 대시보드, 트랙 범례), i18n 문구 키 | `src/styles/tokens.css`, `src/i18n/**` | 003, 041 | P0 | S | Haiku(보일러플레이트) | 하드코딩 hex 0(lint 규칙), 03장 3.2절 의미 기반 토큰 이름, `tailwind.config.js` 0 | BS 작업 15 |
| VID-06-037 | 파이프라인 통합 테스트(가짜 제공자, Python 워커 로컬, 부분 환불) | `tests/integration/pipeline/**` | 015, 013, 016 | P0 | M | Opus(테스트 설계) | Track A~F 각 1시나리오 통과, drift 0 | SM 작업 15, YSM 작업 15 |
| VID-06-038 | 사용자 플로우 E2E(webapp-testing): 가입→첫 생성, 업로드 WARN, Track B 랜딩, Track F | `tests/e2e/flows/**` | 029~034, 051, 053 | P0 | M | Opus(테스트 설계) | 03장 2절 6개 플로우 + AI 3개 플로우(2.7 채팅, 2.8 음성, 2.9 엔진 선택) 통과, 뷰포트 4종 스크린샷 | 03장 2절 |
| VID-06-039 | CI(tsc, eslint, build, pytest, SQL 체커, RLS 스모크), 린트·타입 정리, 로거, sanitize | `.github/workflows/nomad-video.yml`, `apps/nomad-video/eslint.config.mjs` | 001 | P0 | S | Haiku(린트·설정) | CI 녹색, `console.log` 0, `dangerouslySetInnerHTML` 0, `pytest apps/api`·`ruff` 포함, 비밀 검사에 AI 키 패턴 추가 | SM 작업 5·14·15, BS 작업 14 |
| VID-06-040 | 원본 정리 체크리스트: YSM 태그(사용자 승인 후), `.gitignore`(pyc, .venv, tsbuildinfo), 잔여물 삭제, 노출 키 재발급 목록 | `archive/README-nomad-video.md`, 루트 `.gitignore`의 해당 줄 | 없음 | P1 | S | Haiku(반복 체크) | 07장 5절 표 전 항목 완료 표시 | SM 작업 13, YSM 작업 1·2·3 |
| VID-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Primer + 보조 Atlassian, 채팅은 Astryx 패턴 확인 D-19, 랜딩은 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet(문서) | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안(Primer + shadcn/ui) 기록(01장 D-19). 고문(Fable) 검토 기록 | DESIGN_SYSTEM 4장 1단계, 9절 |
| VID-06-042 | 디자인 시스템 2단계(컴포넌트): 036 토큰 위에서 기본 컴포넌트·배리언트(03장 3.2절 표)와 `/dev/components` 미리보기. 컴포넌트 1개 단위로 지시 | `apps/nomad-video/src/components/ui/**`, `src/app/dev/components/**`, `docs/file/03-설계/디자인/COMPONENTS.md`(초안) | 036 | P0 | M | Sonnet(컴포넌트) | 03장 3.2절 기본 컴포넌트 전부가 라이트/다크로 `/dev/components`에 보인다. 컴포넌트마다 `DESIGN_SYSTEM.md` 8장 지시 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증) 기록. hex 직접 사용 0, `tailwind.config.js` 0, 프로덕션 빌드에 `/dev/components` 미포함 | DESIGN_SYSTEM 4장 2단계 |
| VID-06-043 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | 042 | P0 | M | 사람(보조 Sonnet) | 03장 3.2절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| VID-06-044 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | 043 | P0 | S | Opus(검토·정리) | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| VID-06-045 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, video 설정(app, `VIDEO_KNOWLEDGE_ORG_ID`, 컬렉션 이름), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/video/`, `app/ai/compliance/video.py`, `app/ai/products/video/knowledge.py`, `wiki_config.py` 제외), `apps/api/tests/platform/` | 001 | P0 | M | Fable(AI 보안 경계) | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 대상 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 필수 변수 누락 시 기동 실패, `apps/api`에서 ffmpeg·whisper·demucs import 0(02장 2절 경계) | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| VID-06-046 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰·잡 토큰 발급(`/api/internal/ai-token`), 정산 크론 엔드포인트, 정밀 모드 대본 시작·재개, AI 단가, 온보딩 국외 이전 동의 | `apps/nomad-video/src/app/api/{ai,internal,onboarding}/**`, `src/app/onboarding/**`, `src/server/ai/**`, `src/server/ai-pricing.ts` | 003, 005, 045 | P0 | L | Fable(과금·AI 보안) | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 잡 토큰은 running 잡에만(그 외 409), 동의 시 `ai_org_settings` 고지문 버전 일치, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 정밀 모드 24시간 미재개 실행 환불 | VD-F-100, 103, 108, 109 |
| VID-06-047 | RAG 색인: 운영자 컬렉션(`video-trends`, `video-guide`)과 조직 컬렉션(`video-performance`, `video-scripts`, `video-brand`), 자동 색인 잡, Dify 외부 지식 설정, 검색 평가셋 40문항 | `apps/api/app/ai/products/video/knowledge.py`, `workers/video-orchestrator/src/ai-ingest/**`, `scripts/knowledge/`, `apps/api/tests/video/retrieval/` | 015, 045, 046 | P0 | L | Opus(RAG·연동) | 재현율@8 0.8 이상(제안), 다른 조직 컬렉션 요청 42501, 외부 지식 응답에 사용자 조직 데이터 0, 컬렉션당 임베딩 모델 1종(`oss-embed`), `is_estimated` 표시 보존, 난수·더미 지표 색인 0, 조직 월 청크 상한(`AI_INDEX_LIMIT`) 동작, D-18 범위(요약 지표 + 출처) 준수 | VD-F-101 |
| VID-06-048 | 채널·브랜드 가이드 위키: 문서 업로드 → ingest(draft) → 게시·편집·이력·lint 화면과 API, 주 1회 lint 잡 | `apps/api/app/ai/products/video/wiki_config.py`, `apps/nomad-video/src/app/(dashboard)/dashboard/wiki/**`, `src/components/wiki/**`, `src/app/api/wiki/**` | 044, 047 | P0 | M | Opus(기능·연동) | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 표시가 붙은 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, lint 결과 화면 표시, 모든 쓰기 감사 1행, 다른 조직 페이지 접근 0 | VD-F-102, LLM_WIKI 3장 |
| VID-06-049 | LangGraph `video.script`(trend → plan → script → metadata → compliance)와 `video.step`(D-20), 체크포인트, 실행 기록, 규칙 파일, 오케스트레이터의 그래프 클라이언트 | `apps/api/app/ai/graphs/video_script.py`·`video_step.py`, `apps/api/app/ai/compliance/video.py`, `packages/video-rules/**`, `workers/video-orchestrator/src/steps/{script,ai-step}/**`, `apps/api/tests/video/graph/` | 016, 045, 047 | P0 | L | Opus(그래프) | 실행 1회 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 출처 없는 수치 0, 대가성 문구 모방 문장 제거와 첫 줄 비움, 걸린 부분 1회 재작성·2회 실패 시 run failed + 환불, 금지 문구 평가셋 30문항 위반 0(상용·오픈소스 경로 모두), UI 시작 정밀 모드의 interrupt 재개가 같은 thread, `video.step`의 허용 밖 kind 422 | VD-F-103, 111 |
| VID-06-050 | Dify `video-chat`(질문 분류, HTTP 노드, 외부 지식)과 `/tools/answer` video 확장(채널 코치 모드, 마스킹, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/video/`, `apps/api/tests/video/chat/` | 046, 047 | P0 | M | Opus(연동) | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `context_ref` 403, 답변 출처 1개 이상 또는 `no_source`, 평가셋 금지 문구 0·근거 없는 수치 0, DSL에 키 0 | VD-F-100, 111, 04장 6.2절 |
| VID-06-051 | 채팅 패널과 대화 목록(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 컨텍스트 칩) | `apps/nomad-video/src/components/ai-chat/**`, `src/app/(dashboard)/dashboard/chat/**` | 044, 046, 052 | P0 | M | Sonnet(UI) | 03장 3.1절 구성, 375px 전체 화면 시트, `aria-live`, 402 충전 모달, 대체·근거 없음·환불 상태 표시. 대시보드 레이아웃 장착은 028 파일에 1줄 요청 | VD-F-100, 03장 5절 |
| VID-06-052 | 음성 대화: `/api/voice/*`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기. Whisper STT 편입: 라우팅 `video.stt` 고정, 워커 사용량 기록 모듈 | `apps/nomad-video/src/app/api/voice/{consent,sessions,stt,tts}/**`, `src/components/voice/**`, `services/media-worker/handlers/usage/**` | 011, 012, 046 | P0 | M | Opus(기능·연동) | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 텍스트만, 파이프라인 STT 호출 100%가 `ai_usage` stt 행(provider `oss-voice`, feature `video.stt`)을 남기고 원본 오디오가 국외 제공자로 가는 경로 0 | VD-F-104, 105 |
| VID-06-053 | 제품 음성 기능: 오픈소스 TTS 내레이션 선택(`voice.provider`), 같은 목소리 규칙, 샘플 듣기, 받아쓰기, 엔진 선택 UI | `workers/video-orchestrator/src/steps/tts/**`, `apps/nomad-video/src/app/api/voice/sample/**`, `src/components/voice-engine/**` | 016, 046, 052 | P0 | L | Opus(기능·연동) | 한 언어판 `voice_jobs`의 provider·voice_id 동일·`fallback_from` null, 3구간 중 2구간째 강제 실패 시 산출물 0 + 그 언어분 환불 1행, 샘플 제공자 = 본 작업 제공자, 미동의 조직의 ElevenLabs 선택지 없음, 재생성 섹션 보이스 불일치 422 `VD013`, 롱폼 섹션 재생성이 첫 섹션 기준을 따름, 받아쓰기 60초·원본 미저장 | VD-F-106, 107 |
| VID-06-054 | 3D 히어로: 영상 타일 파이프라인(PC·태블릿), 한 줄 흐름(모바일), 정지 이미지 대체, 성능 예산 | `apps/nomad-video/src/components/hero3d/`, `apps/nomad-video/public/hero/` | 044 | P0 | L | Sonnet(UI·3D) | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 3D 안 글자·숫자 0, 보라 글로우·네온 그리드 0 | VD-F-110, 03장 4.5절 |
| VID-06-055 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 강제 오픈소스, 선차감·정산·환불, 라우팅 seed 스냅샷, 내레이션 대체 금지, 파이프라인 STT 국외 호출 0) | `apps/api/tests/video/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | 046, 049, 050, 052, 053 | P0 | M | Fable(AI 보안) | `resolve_ai_route` 스냅샷(17행 x 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, 내레이션 구간 강제 실패 시 대체 호출 0, 원장 drift 0, `uploads_disclosure_check` 우회 시도 실패, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |
| VID-06-056 | 대본 기획 미리보기 UI: 기획안 3안 비교 표, 근거 칩, 추정 배지, 선택·수정, `script_run_id`를 생산 요청으로 전달 | `apps/nomad-video/src/components/script-plan/**` | 029, 030, 049 | P0 | M | Sonnet(UI) | 03장 3.1절 구성, 근거 없는 수치 표시 0, 402·`VD009`·`VD010` 안내, 24시간 만료 안내. 숏폼 생성·롱폼 화면 장착은 029·030 파일에 1줄 요청 | VD-F-103, 03장 2.10절 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 040, 041 | 3 | 없음 | DB 적용(AI 기본값 포함), 타입, 원본 정리, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 011, 039, 045 | 5 | 001 | RLS 테스트, 앱 골격, 미디어 워커 골격, CI, AI 서비스 설치 |
| W1-D | 036 → 042 → 043 → 044(직렬) | 1 | 003, 041 | 디자인 시스템 2~4단계(토큰, 기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 008, 012, 013, 014, 022, 025 | 7 | W1 | 과금 래퍼, 채널, 미디어 핸들러, 제휴, 웹훅 |
| W3 | 004, 006, 009, 015, 023, 028, 046, 054 | 8 | W2, 화면은 044 | 인증 화면, 결제, YouTube 업로더, 오케스트레이터, 공개 페이지, 셸, AI 게이트, 3D 히어로 |
| W4 | 007, 010, 016, 017, 018, 019, 020, 027, 035, 047, 052 | 11 | 006, 015, 046 | 결제 E2E, 생산 API 전부, 스케줄러, 랜딩, RAG 색인, 음성 대화·STT 편입 |
| W5 | 021, 024, 026, 029, 030, 031, 048, 049, 050, 051, 053 | 11 | W4 | 업로드 API, 레이더, 분석, 화면, 위키, 대본 그래프, Dify 채팅, 채팅 패널, 제품 음성 기능 |
| W6 | 032, 033, 034, 037, 056 | 5 | 021, 024, 049 | 업로드·수익화·레이더 화면, 통합 테스트, 대본 기획 UI |
| W7 | 038, 055 | 2 | W6 | 사용자 플로우 E2E, AI 보안 회귀. MVP 출시 조건 |

034(레이더·분석·크레딧·결제 화면)는 선행 024와 같은 웨이브에 있던 것을 W6으로 옮겼다(2026-10-13 정리).

P0 작업과 테스트 작업 대응: DB·권한(001, 003, 005, 008) → 002 / 결제(006) → 007 / 워커·생산·업로드(009, 011~021, 025, 027) → 037 / 화면·공개 페이지(004, 023, 028~036, 042, 054, 056) → 038 / AI·음성(045~053) → 055 / 디자인 시스템(041~044)은 043(사람 검토) / 039는 전체 게이트.

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 9 | 16.4% | 21/111 = 18.9% |
| Opus | 28 | 50.9% | 58/111 = 52.3% |
| Sonnet | 15 | 27.3% | 29/111 = 26.1% |
| Haiku | 3 | 5.5% | 3/111 = 2.7% |

비율은 모델 작업 55개 기준이다. 사람 작업 1개(VID-06-043, M)는 비율에서 뺐다. 2026-10-13 이전(40개)은 Fable 15.0%, Opus 52.5%, Sonnet 25.0%, Haiku 7.5%였다.

Fable은 데이터 모델, RLS, 결제, 크레딧 차감 경로, OAuth에 더해 AI 보안 경계(서명 토큰 검증 045, AI 게이트의 선차감·정산·동의 046, AI 회귀 055)를 맡는다. 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 패널·대본 기획 UI·3D 히어로·디자인 시스템 컴포넌트는 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

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
| YSM 5 | 네이버 로그인 naver_id 매핑 | 004(MVP 제외 확인) + 6절 코어 요청 |
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

AI·음성·3D·디자인 시스템 작업(041~056)은 리뷰 작업이 아니라 확정 결정 13~17에서 온 신규 작업이라 위 표에 행이 없다. 리뷰 작업 수 = 흡수표 행 수 규칙(`DOC_TEMPLATE.md` 3절)은 그대로 유지된다(40행 → 변경 없음).

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 |
|---|---|---|
| 모듈러 `seed.sql`에 video `adv_pack_*` 4행 추가 | `_supabase-modular/seed.sql` | Advanced 30% 할인(PRD_pricing.md:149-154). 모놀리스 seed에는 반영함. 해결(2026-10-13 코어 반영 완료): 모듈러 seed에도 추가됨 |
| `affiliate_disclosures.placement`에 `landing`(랜딩·링크인바이오) 추가 검토 | 0006 | 현재 `video_description` 문구 재사용 |
| `storage` 대용량 미디어 버킷을 코어 표준으로 정의할지 결정 | 0005 | 제품 조각이 `video-media`(5GB, 서버 쓰기만)를 만든다 |
| `confirm_payment_order` 금액 불일치 시 failed 기록(롤백되지 않게) | 0003 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 이를 별도 호출하고 운영 알림·취소 |
| `adjust_credits`(환불 시 팩 크레딧 음수 조정) | 0003 | CORE_SPEC 5.4 제안과 같음 |
| 네이버 로그인(Phase 2): 로그인 상태에서만 identity 연결, 이메일 자동 병합 금지 | core auth | YSM #3 |
| features 키 `max_concurrent_productions` 추가 | seed | 현재 서버 상수(01장 5절) |
| automation-core 캔버스 실행 엔진(Phase 2) | packages/automation-core | `video.workflows` 저장만 MVP |

AI·음성 요청(2026-10-13, 01장 D-13~D-22와 연결):

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 |
|---|---|---|---|---|
| R-V1 | `_supabase-modular/seed.sql` | video 플랜 4행 `features`에 `ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `ai_script` 추가 | seed가 1200보다 나중에 실행되면 11.2절 병합 UPDATE가 덮어써진다 | 서버가 누락 키를 기본값으로 읽는다(01장 4장 키 표) |
| R-V2 | `_supabase-modular/seed.sql` 제공자 | `openai` 제공자 kinds에 `tts` 추가(01장 D-14 (b)) | 기존 OpenAI TTS-1-HD 백업을 체인에 유지하려면 필요 | D-14 (a): OpenAI TTS 백업 제거, 체인 `elevenlabs → oss-voice` |
| R-V3 | ai_providers | DeepL, fal, Suno를 제공자 레지스트리에 편입(국외 이전 필터 적용, 01장 D-21) | 코어 라우팅 밖 외부 서비스의 국외 동의 연동 | 온보딩 화면의 별도 고지 항목과 기능 비활성 |
| R-V4 | ai-service | 서명 토큰 기반 단일 LLM 호출 엔드포인트(feature 키로 라우팅) 추가(01장 D-20 (b)) | 파이프라인 TS 단계의 LLM 호출 경로 | 1노드 그래프 `video.step`(049) |
| R-V5 | AI_ARCHITECTURE, ai-gateway | TS 워커가 그래프·음성 서버를 호출할 때 쓰는 잡 토큰 발급 규칙(Next.js `/api/internal/ai-token`, 워커 키 + running 잡 확인, org·sub는 잡 행에서) 표준화. `D:/WorkSpace/platform/docs/products/astro-ai/06_AGENT_PLAN.md` 6절 R-8과 같은 요청 | 개인키는 Next.js에만 둔다는 규칙과 워커 기반 생성이 함께 필요 | video 제품 엔드포인트로 구현(04장 2.1절) |
| R-V6 | core-voice, VOICE_ARCHITECTURE | (a) TS 서버 워커(오케스트레이터)에서 ElevenLabs SDK 호출 허용 확인(01장 D-22) (b) 기능별 대체 금지 옵션(`feature='narration'`)과 "시작 제공자 고정" 동작을 `VoiceAdapter` 계약에 명시(astro R-11과 같음) | 롱폼 내레이션이 요청-응답 시간 안에 끝나지 않는다. 대체 금지를 코드 계약으로 강제 | 내레이션 단계가 체인 첫 가용 제공자 하나만 넘겨 호출 |
| R-V7 | 공용 Dify | `video-chat` 앱 생성, 내부 키 환경 변수, 외부 지식 `video-guide`·`video-trends` 등록, 로그 보존 30일 | 공용 인프라는 코어 소유 | 없음(필수). 장애 시 `/tools/answer-direct` |
| R-V8 | `_design-guide` 3D 키트 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/file/03-설계/디자인/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| R-V9 | ai-service | (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | Dify 보조 노드 라우팅(`dify.aux`, `wiki.query`)과 위키 편집 | (a) Dify에 기능별 모델 이름을 따로 등록 (b) video 확장(`app/ai/products/video/wiki_config.py`)에 임시 구현 |
| R-V10 | 공용 음성 서버 | KO/JA/EN TTS 평가 문장 세트와 품질 판정 결과 공유, STT 요청 한도(10분·50MB) 상향 가능 여부(01장 D-13, D-15) | 오픈소스 내레이션의 언어 범위 결정, 파이프라인 STT 일원화 재검토 | 오픈소스 선택지는 검증 통과 언어만 노출, 파이프라인 STT는 미디어 워커 유지 |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `pnpm -F nomad-video build`, `tsc --noEmit`, `eslint` 오류 0 |
| Python | `pytest services/media-worker` 통과 |
| SQL | `node check.mjs mod ... 0000~0007 seed 1200_video.sql` OK, `node check.mjs mono ...` OK |
| RLS 스모크 | VID-06-002 전 항목 통과(현재 기획 단계 65/65) |
| 결제 E2E | VID-06-007 통과 |
| 파이프라인 | VID-06-037 Track A~F 통과, 원장 drift 0 |
| 사용자 플로우 | VID-06-038 통과(AI 플로우 3개 포함), DESIGN_PRINCIPLES 7단계 체크리스트 |
| AI·음성 | `pytest apps/api` 통과, VID-06-055 녹색, 금지 문구 평가셋 30문항(대본 그래프)·채팅 평가셋 30문항 위반 0, RAG 평가셋 40문항 재현율 기준 충족, 같은 목소리 강제 실패 테스트 통과, 파이프라인 STT 국외 제공자 호출 0 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준(VID-06-054), 디자인 시스템 4단계(VID-06-044) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | 2절 56개 완료(사람 작업 043 포함, P1·P2 작업은 기존 규칙대로 출시 후 가능), 리뷰 "높음" 26건 차단 설계 구현 확인 |
