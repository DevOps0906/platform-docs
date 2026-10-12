# 06 에이전트 작업 계획: NOMAD AI Factory (nomad-video)

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 아래 표의 디렉토리만 만든다·고친다. 다른 작업의 디렉토리를 고쳐야 하면 그 작업 소유자에게 요청 작업을 남긴다 |
| 공용 파일 | `apps/nomad-video/src/lib/**`(env, core 래퍼)은 VID-06-003, `src/server/billing/**`(게이팅·단가)는 VID-06-005만 수정. 다른 작업은 import만 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, 공용 패키지(`packages/core-*`) 수정 금지. 필요하면 6절 코어 요청 |
| DB | 스키마 변경은 VID-06-001(Fable)만. 모놀리스는 변환 스크립트로만 생성 |
| 테스트 | 모든 P0 작업은 3절 웨이브 표의 테스트 작업(002, 007, 037, 038) 중 하나에 대응한다 |

| 영역 | 경로(제안 모노레포) |
|---|---|
| DB | `supabase/migrations/1200_video.sql`, `supabase/monolith/**`, `scripts/mono-convert.mjs` |
| 웹 공통 | `apps/nomad-video/src/{proxy.ts,lib/**}`, `package.json` |
| 서버 도메인 | `apps/nomad-video/src/server/<domain>/**` |
| API | `apps/nomad-video/src/app/api/<domain>/**` |
| 화면 | `apps/nomad-video/src/app/(dashboard)/dashboard/<area>/**`, `src/components/<area>/**` |
| 워커 | `workers/video-orchestrator/src/<area>/**`, `services/media-worker/**`, `packages/sns-uploader/**` |
| 테스트 | `supabase/tests/**`, `tests/{e2e,integration}/<area>/**` |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| VID-06-001 | 1200 조각 적용, 모놀리스 변환 스크립트, 타입 생성(`--schema core,video`) | `supabase/migrations/1200_video.sql`, `supabase/monolith/**`, `scripts/mono-convert.mjs`, `apps/nomad-video/src/types/supabase.ts` | 없음 | P0 | M | Fable(데이터 모델) | `supabase db reset` 성공, 체커 OK(모듈러·모놀리스), 타입 파일에 22개 테이블 | 05장, SM 작업 6, BS 작업 1·11·14 |
| VID-06-002 | RLS/권한 회귀 테스트(PGlite + 로컬 Supabase) | `supabase/tests/**` | 001 | P0 | M | Fable(RLS) | 05장 9절 65항목 + SECURITY_BASELINE 15장이 CI에서 통과, 실패 시 머지 불가 | SM 작업 1·15, BS 작업 1, YSM 작업 6 |
| VID-06-003 | 앱 골격: `proxy.ts` 공개 경로 배열, `lib/env.ts`(zod), 코어 클라이언트 3계층 연결, `requireSession`, enqueue 전용 lazy Redis 모듈, 응답 봉투 | `apps/nomad-video/src/proxy.ts`, `src/lib/**`, `package.json` | 001 | P0 | M | Opus(골격·연동) | 비로그인 `/dashboard` 302, `/landing/x` 200, env 누락 시 기동 실패, `x-internal-call` 문자열 0건 | SM 작업 3·4·8·10·12, BS 작업 5·7·13, YSM 작업 9 |
| VID-06-004 | 로그인·가입·온보딩 화면(`signup_app='video'`, 프로필 없으면 로그아웃) | `src/app/(auth)/**`, `src/components/auth/**` | 003 | P0 | S | Sonnet(UI) | 가입 직후 Starter 100크레딧 표시, Mock 로그인 없음, 네이버 로그인 없음 | SM 작업 4, BS 작업 4, YSM 작업 5 |
| VID-06-005 | 플랜 게이팅·단가표(`priceOf`)·크레딧 래퍼(consume→enqueue→환불, 부분 환불) | `src/server/billing/**` | 003 | P0 | M | Fable(과금·권한) | 01장 4절 단가와 일치하는 단위 테스트, Starter Track B 403 VD009, 동시 50요청 음수 0 | BS 작업 2, 01장 VD-F-003/091 |
| VID-06-006 | 결제: 주문 선저장, confirm, 빌링키, 해지, Advanced 할인 팩 판정, PM001 운영 알림·취소 | `src/app/api/billing/**`, `src/server/payments/**`, `src/app/billing/**` | 005 | P0 | L | Fable(결제) | 금액 위조 PM001 + 취소 호출, 같은 결제 2회 멱등, 비Advanced의 adv 팩 403 | SM 작업 2, BS 작업 3, 01장 VD-F-090 |
| VID-06-007 | 결제 E2E(Toss 테스트 키): 구독, 크레딧팩, 실패 복귀 | `tests/e2e/billing/**` | 006 | P0 | M | Opus(테스트 설계) | 3시나리오 통과, 원장·엔타이틀먼트 기대값 일치 | SM 작업 2, DOC_TEMPLATE 필수 |
| VID-06-008 | 채널 OAuth 연결·콜백·역할 변경·해제(코어 oauth, 자격증명 vault), 다채널 위험 동의 | `src/app/api/channels/**`, `src/server/channels/**` | 003, 001 | P0 | M | Fable(OAuth·권한) | state 재사용 OA001, Starter 2번째 채널 VD003, 오류 원문을 쿼리스트링에 싣지 않음, 토큰 평문 0 | SM 작업 4, BS 작업 8, YSM 작업 4·10·13 |
| VID-06-009 | sns-uploader YouTube: resumable 스트리밍, 고정 댓글, 쿼터, 대체 채널 선택, 재예약 | `packages/sns-uploader/src/{youtube,registry.ts,types.ts}` | 008 | P0 | L | Opus(API 연동) | 1GB 파일 업로드 시 RSS 512MB 이하, 쿼터 초과 시 대체 채널 또는 `run_after` 재예약 | SM 작업 12 |
| VID-06-010 | sns-uploader Meta(IG Reels, Threads)·TikTok 어댑터 | `packages/sns-uploader/src/{meta,tiktok}/**` | 009 | P1 | M | Opus(API 연동) | 샌드박스 계정 업로드 성공, 토큰 만료 시 credentials error + 재연결 요청 | 01장 VD-F-071 |
| VID-06-011 | Python 미디어 워커 골격: claim/heartbeat/complete/fail 루프, 취소 신호, 하위 프로세스 타임아웃·kill, settings 검증, pytest | `services/media-worker/{core,tests}/**` | 001 | P0 | M | Opus(워커) | 타임아웃 초과 프로세스 kill 후 fail_job, 하트비트 60초, pytest 통과 | SM 작업 7, BS 작업 9, YSM 작업 8·11·12·15 |
| VID-06-012 | Whisper STT(모델 1회 로드, 동시성 1), demucs 핸들러 | `services/media-worker/handlers/{stt,separate}.py` | 011 | P0 | M | Opus(기능) | 60초 중국어 클립 세그먼트 반환, 전역 asyncio Lock 없음 | YSM 작업 11·12 |
| VID-06-013 | FFmpeg 핸들러: 워터마크 제거·삽입, 무음컷(-30dB/0.5초), ASS+강조 자막 합성, 인코딩, 켄번스, 루프, 플리 연결, 하이라이트 컷 | `services/media-worker/handlers/ffmpeg/**` | 011 | P0 | L | Opus(기능) | 04장 4절 계약대로 결과 경로 반환, 레이어 순서 테스트, 3시간 플리 90분 이내 | YSM 작업 12, 01장 VD-F-030~050 |
| VID-06-014 | 다운로더(YSM 이식): 도메인 허용 목록, `--`, 프록시 풀, pHash, 24시간 원본 삭제 | `services/media-worker/handlers/{download,purge}.py` | 011 | P0 | M | Opus(기능) | 허용 목록 밖 URL 거부, purge 후 객체 없음 | BS 작업 12, YSM 작업 12 |
| VID-06-015 | TS 오케스트레이터: FlowProducer 트랙별 플로우, Python 브리지(자식 core.jobs), 상태 미러링, 언어별 부분 환불 | `workers/video-orchestrator/src/{flows,bridge,index.ts}` | 005, 011 | P0 | L | Fable(아키텍처·과금) | placeholder 0건, 단계 결과 returnvalue 전달, JA 실패 시 JA분만 환불 | SM 작업 3·7·12, BS 작업 9 |
| VID-06-016 | AI 단계: 번역(톤), 대본, TTS(ElevenLabs/OpenAI), fal 이미지, Suno, 모델 허용 목록 | `workers/video-orchestrator/src/steps/**` | 015 | P0 | M | Opus(API 연동) | 허용 목록 밖 모델 거부, 제공자 오류 시 폴백 1회 후 실패(mock 반환 0) | SM 작업 10, BS 작업 11, YSM 작업 7 |
| VID-06-017 | 소싱·숏폼 생산 API(견적, 생성, 조회, 취소, 동시 생산 상한) | `src/app/api/{sources,productions}/**`, `src/server/{sources,productions}/**` | 005, 015 | P0 | M | Opus(기능) | 같은 request_id 재요청 시 차감 1회, 세션 org와 다른 행 404 | YSM 작업 6, 01장 VD-F-020~035 |
| VID-06-018 | 롱폼 API: 점수 게이트, 스토리라인, 10섹션, 렌더, OSMU | `src/app/api/longform/**`, `src/server/longform/**` | 005, 015 | P0 | M | Opus(기능) | 점수 59 → VD010 + 대안 3, 하이라이트 3개 각 60초 이하, 목업 응답 0 | BS 작업 10, 01장 VD-F-040~041 |
| VID-06-019 | Track E API: 곡 생성, 루프 영상, 유통 패키지, 상태 기록 | `src/app/api/music/**`, `src/server/music/**` | 005, 015 | P0 | M | Opus(기능) | 곡 1개 = music_tracks 1 + outputs(music_loop) 1, none→live 22023 | 01장 VD-F-050~051 |
| VID-06-020 | Track F API: 플리, 항목 정렬, 라이브러리 등록, 트랙리스트·타임스탬프·고정 댓글 생성, 렌더 | `src/app/api/{playlists,library}/**`, `src/server/playlists/**` | 005, 015 | P0 | M | Opus(기능) | 합계 시간 ±5% 밖 409, 만료 라이선스 곡 VD006, 타임스탬프가 실제 연결 결과와 일치 | 01장 2절 E/F 구분표 |
| VID-06-021 | 업로드 API: 문구 삽입, compliance 게이트(규칙+LLM), WARN 확인, 예약, 취소 | `src/app/api/uploads/**`, `src/server/publish/**` | 009, 022 | P0 | L | Opus(기능) | 제휴 링크 있는 업로드의 설명란·고정 댓글 첫 줄 = 문구, FAIL 업로드 예약 불가, LLM 오류 시 WARN | 01장 VD-F-062/072 |
| VID-06-022 | 제휴 통합: 계정 연결(쿠팡 API, 텐핑·네이버쇼핑 커넥트 수동), 단축 링크, `/r/[code]`, 문구 편집 | `src/app/api/affiliate/**`, `src/app/r/**`, `src/server/affiliate/**` | 003 | P0 | M | Opus(API 연동) | `/r/` 302 + 클릭 1행(IP 해시만), 레이트 리밋 60/분, 문구 10자 미만 거부 | 확정 결정 12 |
| VID-06-023 | 공개 페이지 `/landing/[slug]`(ISR, params await), `/lb/[handle]`, 조회수 집계 | `src/app/{landing,lb}/**`, `src/components/public/**` | 001, 022 | P0 | M | Sonnet(UI) | 비로그인 200, 대가성 문구 렌더, 비공개 404 | SM 작업 5, BS 작업 5 |
| VID-06-024 | 레이더 수집·API: 플레이보드(난수 0), 채널파인더, 블링(출처 필수, 월 한도) | `workers/video-orchestrator/src/radar/**`, `src/app/api/radar/**`, `src/server/radar/**` | 015 | P1 | M | Opus(API 연동) | growth_rate 미산출 시 null + 추정 배지, Pro 21번째 블링 VD012 | SM 작업 9, BS 작업 10 |
| VID-06-025 | 웹훅 수신: Toss(코어 위임), fal, (Phase 2) Distrokid·Make 서명 필수 골격 | `src/app/api/webhooks/**` | 003 | P0 | S | Opus(연동) | 서명 없는 요청 401, 중복 200 | SM 작업 11, BS 작업 6 |
| VID-06-026 | 성과 수집(YouTube Analytics 스냅샷) | `workers/video-orchestrator/src/analytics/**` | 009 | P1 | S | Opus(연동) | 일 1회 스냅샷, 실패 시 이전 값 유지 | 01장 VD-F-080 |
| VID-06-027 | 스케줄러: reap, purge, 예약 업로드 enqueue, 쿼터 리셋, 월 지급, 빌링 청구, 보존 기간 삭제 | `workers/video-orchestrator/src/cron/**` | 015 | P0 | S | Opus(워커) | CRON_SECRET 공개 라우트 0, 각 작업 멱등 | SM 작업 3 |
| VID-06-028 | 대시보드 홈 + 잡 진행률 Realtime(서버 컴포넌트, 더미 0) | `src/app/(dashboard)/dashboard/page.tsx`, `src/app/(dashboard)/layout.tsx`, `src/components/{shell,jobs}/**` | 003 | P0 | M | Sonnet(UI) | 더미 배열 0, Realtime 끊김 시 폴링 | SM 작업 9 |
| VID-06-029 | 소싱·숏폼 화면 | `src/app/(dashboard)/dashboard/{sources,shorts}/**`, `src/components/shorts/**` | 017, 028 | P0 | M | Sonnet(UI) | 예상 크레딧 표시, 402 안내 문구 | 03장 |
| VID-06-030 | 롱폼 스토리보드 화면 | `src/app/(dashboard)/dashboard/longform/**`, `src/components/longform/**` | 018, 028 | P0 | M | Sonnet(UI) | 잠금 상태 편집 비활성 | 03장 |
| VID-06-031 | 곡·플리·라이브러리 화면 | `src/app/(dashboard)/dashboard/{music,playlists,library}/**`, `src/components/music/**` | 019, 020, 028 | P0 | M | Sonnet(UI) | E/F 메뉴·색 분리, 키보드 정렬 대체 | 확정 결정 E/F 구분 |
| VID-06-032 | 채널·업로드 화면(설정·배포 대형 페이지를 섹션 컴포넌트로 분할) | `src/app/(dashboard)/dashboard/{channels,publish}/**`, `src/components/publish/**` | 008, 021, 028 | P0 | M | Sonnet(UI) | 문구 첫 줄 잠금 표시, WARN 확인 흐름, 파일당 400줄 이하(제안) | YSM 작업 14 |
| VID-06-033 | 수익화 화면(제휴 계정·링크·통계, 랜딩, 링크인바이오, 문구 편집) | `src/app/(dashboard)/dashboard/monetize/**`, `src/components/monetize/**` | 022, 023, 028 | P0 | M | Sonnet(UI) | 문구 끄기 UI 0, 공개 버튼이 VD001/VD009 안내 | 확정 결정 12 |
| VID-06-034 | 레이더·분석·크레딧·결제 화면 | `src/app/(dashboard)/dashboard/{radar,analytics,credits,billing,settings}/**`, `src/components/{radar,analytics,billing}/**` | 006, 024, 028 | P0 | M | Sonnet(UI) | 추정 배지, 블링 출처 목록, 원장 표 | 03장 |
| VID-06-035 | 마케팅 랜딩·요금·약관 페이지(frontend-design 절차, MASTER.md) | `src/app/(marketing)/**`, `src/app/legal/**`, `design-system/nomad-video/**` | 036 | P0 | M | Sonnet(메인페이지) | 03장 4절 체크, 금지 문구 0, DESIGN_PRINCIPLES 7단계 체크리스트 통과 | 03장 4절 |
| VID-06-036 | 디자인 토큰 파일(라이트 랜딩·다크 대시보드, 트랙 범례), i18n 문구 키 | `src/styles/tokens.css`, `src/i18n/**` | 003 | P0 | S | Haiku(보일러플레이트) | 하드코딩 hex 0(lint 규칙) | BS 작업 15 |
| VID-06-037 | 파이프라인 통합 테스트(가짜 제공자, Python 워커 로컬, 부분 환불) | `tests/integration/pipeline/**` | 015, 013, 016 | P0 | M | Opus(테스트 설계) | Track A~F 각 1시나리오 통과, drift 0 | SM 작업 15, YSM 작업 15 |
| VID-06-038 | 사용자 플로우 E2E(webapp-testing): 가입→첫 생성, 업로드 WARN, Track B 랜딩, Track F | `tests/e2e/flows/**` | 029~034 | P0 | M | Opus(테스트 설계) | 03장 2절 6개 플로우 통과, 뷰포트 4종 스크린샷 | 03장 2절 |
| VID-06-039 | CI(tsc, eslint, build, pytest, SQL 체커, RLS 스모크), 린트·타입 정리, 로거, sanitize | `.github/workflows/nomad-video.yml`, `apps/nomad-video/eslint.config.mjs` | 001 | P0 | S | Haiku(린트·설정) | CI 녹색, `console.log` 0, `dangerouslySetInnerHTML` 0 | SM 작업 5·14·15, BS 작업 14 |
| VID-06-040 | 원본 정리 체크리스트: YSM 태그(사용자 승인 후), `.gitignore`(pyc, .venv, tsbuildinfo), 잔여물 삭제, 노출 키 재발급 목록 | `archive/README-nomad-video.md`, 루트 `.gitignore`의 해당 줄 | 없음 | P1 | S | Haiku(반복 체크) | 07장 5절 표 전 항목 완료 표시 | SM 작업 13, YSM 작업 1·2·3 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 040 | 2 | 없음 | DB 적용, 타입, 원본 정리 |
| W1 | 002, 003, 011, 039 | 4 | 001 | RLS 테스트, 앱 골격, 미디어 워커 골격, CI |
| W2 | 004, 005, 008, 012, 013, 014, 022, 025, 028, 036 | 10 | W1 | 인증 화면, 과금 래퍼, 채널, 미디어 핸들러, 제휴, 웹훅, 셸, 토큰 |
| W3 | 006, 009, 015, 023 | 4 | 005, 008, 011, 022 | 결제, YouTube 업로더, 오케스트레이터, 공개 페이지 |
| W4 | 007, 010, 016, 017, 018, 019, 020, 027, 035 | 9 | 006, 015 | 결제 E2E, 생산 API 전부, 스케줄러, 랜딩 |
| W5 | 021, 024, 026, 029, 030, 031, 034 | 7 | W4 | 업로드 API, 레이더, 분석, 화면 |
| W6 | 032, 033, 037 | 3 | 021 | 업로드·수익화 화면, 통합 테스트 |
| W7 | 038 | 1 | W6 | 사용자 플로우 E2E |

P0 작업과 테스트 작업 대응: DB·권한(001, 003, 005, 008) → 002 / 결제(006) → 007 / 워커·생산·업로드(009, 011~021, 025, 027) → 037 / 화면·공개 페이지(004, 023, 028~036) → 038 / 039는 전체 게이트.

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 6 | 15.0% | 14/78 = 17.9% |
| Opus | 21 | 52.5% | 42/78 = 53.8% |
| Sonnet | 10 | 25.0% | 19/78 = 24.4% |
| Haiku | 3 | 7.5% | 3/78 = 3.8% |

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

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 |
|---|---|---|
| 모듈러 `seed.sql`에 video `adv_pack_*` 4행 추가 | `_supabase-modular/seed.sql` | Advanced 30% 할인(PRD_pricing.md:149-154). 모놀리스 seed에는 반영함 |
| `affiliate_disclosures.placement`에 `landing`(랜딩·링크인바이오) 추가 검토 | 0006 | 현재 `video_description` 문구 재사용 |
| `storage` 대용량 미디어 버킷을 코어 표준으로 정의할지 결정 | 0005 | 제품 조각이 `video-media`(5GB, 서버 쓰기만)를 만든다 |
| `confirm_payment_order` 금액 불일치 시 failed 기록(롤백되지 않게) | 0003 | 알려진 결함. 제품은 의존하지 않고 운영 알림·취소로 대응 |
| `adjust_credits`(환불 시 팩 크레딧 음수 조정) | 0003 | CORE_SPEC 5.4 제안과 같음 |
| 네이버 로그인(Phase 2): 로그인 상태에서만 identity 연결, 이메일 자동 병합 금지 | core auth | YSM #3 |
| features 키 `max_concurrent_productions` 추가 | seed | 현재 서버 상수(01장 5절) |
| automation-core 캔버스 실행 엔진(Phase 2) | packages/automation-core | `video.workflows` 저장만 MVP |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `pnpm -F nomad-video build`, `tsc --noEmit`, `eslint` 오류 0 |
| Python | `pytest services/media-worker` 통과 |
| SQL | `node check.mjs mod ... 0000~0007 seed 1200_video.sql` OK, `node check.mjs mono ...` OK |
| RLS 스모크 | VID-06-002 전 항목 통과(현재 기획 단계 65/65) |
| 결제 E2E | VID-06-007 통과 |
| 파이프라인 | VID-06-037 Track A~F 통과, 원장 drift 0 |
| 사용자 플로우 | VID-06-038 통과, DESIGN_PRINCIPLES 7단계 체크리스트 |
| 작업 | 2절 40개 완료, 리뷰 "높음" 26건 차단 설계 구현 확인 |
