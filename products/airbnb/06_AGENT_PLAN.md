# 06 에이전트 작업 계획: Stay(가칭)

작업 ID는 `SY-06-###`(SQLSTATE 접두사와 약어 SY, `DB_CONVENTIONS.md` 1장 미사용 접두사, 06장 6절 R-2로 등록 요청). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장(Fable 5.1 / Opus 5.5 / Sonnet 5.5 / Haiku 5.5). 근거 약어는 01장과 같다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 작업마다 소유 디렉토리가 겹치지 않는다. 공유 파일(루트 레이아웃, 공용 타입, 디자인 토큰)은 하나의 작업만 소유하고 다른 작업은 그 작업에 변경을 요청한다 |
| 루트 | 웹 `apps/web/`(Next.js 16 App Router), AI 서비스·잡 워커 `apps/api/`(FastAPI, Python 3.12), DB `supabase/`, 개발 스크립트 `scripts/` |
| DB 정본 | `supabase/migrations/`는 SY-06-001만 쓴다. 스키마 변경이 필요한 작업은 `0003_stay_*.sql`을 SY-06-001 후속 작업으로 요청한다(05장 9절 다음 번호) |
| 서버 계층 | 도메인 서버 코드는 `apps/web/src/server/<도메인>/`. 화면 작업은 서버 함수를 호출만 하고 Supabase를 직접 부르지 않는다 |
| 사용자 세션 | 사용자 요청은 요청 단위 `@supabase/ssr` 클라이언트(SY-06-004 소유 `src/lib/supabase/`)로만 DB를 부른다. service_role 클라이언트는 `src/lib/supabase/admin.ts` 하나이고 잡·크론·운영 스크립트만 import한다 |
| 인증 단계 분기 | `src/lib/auth/`, 로그인 화면, `/auth/callback`에만 둔다(SY-06-003, 039, 040, 041) |
| 완료 조건 | 각 작업의 수용 기준 + P0 작업은 대응 테스트(SY-06-030 RLS, SY-06-037 E2E, SY-06-035 평가셋)가 통과해야 완료 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| SY-06-001 | DB 적용과 타입 생성: 0001 core_lite, 0002 stay_domain, seed를 로컬 Supabase에 적용, 타입 생성 | `supabase/**`(tests 제외), `apps/web/src/types/supabase.ts` | 없음 | P0 | S | Opus | `supabase db reset` 오류 0건. `ai_routing_settings`(app `stay`) 11행. free 플랜 활성. 타입 파일 생성 | 05장 9절, 리뷰 5장 #2, #6 |
| SY-06-002 | 모듈러 조각 역변환: `0002_stay_domain.sql` → `_supabase-modular/migrations/2700_stay.sql`(`stay.` 접두사, `@@modular-only` 머리·AI 라우팅 절), 변환 스크립트 | `supabase/modular/`, `scripts/db/convert-stay.mjs` | 001 | P1 | M | Fable | 조각이 docs 저장소 체커(`check.mjs --vector mod`)를 통과. 조각 → 모놀리스 재변환본이 현재 0002와 본문 동일 | 05장 8절 |
| SY-06-003 | Stage A 인증: 인증 모듈 경계(`src/lib/auth/`), Mock 로그인(`/api/dev/login`, 배포 404), 시드 스크립트(공통 + `seed-users.stay.mjs`), `finishLogin`, 미들웨어 가드 | `apps/web/src/lib/auth/`, `apps/web/src/app/api/dev/`, `apps/web/src/middleware.ts`, `scripts/dev/` | 001, 004 | P0 | M | Fable | `guest` 페르소나 로그인 후 `session_context('stay').entitled=true`. 운영 빌드에서 `/api/dev/login` 404. 쿠키 역할 Mock 0건 | AUTH_ROADMAP 2장, 01장 SY-F-001, 리뷰 5장 #7 |
| SY-06-004 | web 골격: Next.js 16.2 App Router, Tailwind CSS v4, shadcn/ui, 요청 단위 Supabase 클라이언트, 공통 오류 응답 헬퍼, 루트 레이아웃 | `apps/web/package.json`, `apps/web/src/app/layout.tsx`, `apps/web/src/lib/supabase/`, `apps/web/src/lib/http/` | 없음 | P0 | M | Opus | `pnpm build` 경고 0. 서버 코드에 전역 쿠키·전역 헤더 설정 0건(정적 검사). 오류 응답이 `{code, message}`이고 내부 오류 문자열 비노출 | 02장 6절 #5, 리뷰 5장 #5, #10, #12 |
| SY-06-005 | api 골격: FastAPI, 서명 토큰 검증, service_role 클라이언트, 잡 워커(`claim_jobs`) 루프, 헬스체크 | `apps/api/app/main.py`, `apps/api/app/core/`, `apps/api/app/jobs/runner.py` | 없음 | P0 | M | Opus | 잘못된 서명 토큰 401. 잡 1건 enqueue → 처리 → `complete_job`. 워커 2개가 같은 잡을 중복 처리 0건 | `AI_ARCHITECTURE.md` 8장 |
| SY-06-006 | 저장소 위생: `.gitignore`(.next, .env*, *.tsbuildinfo, .DS_Store, .swc), `.env.example`, 비밀 스캔 CI, 락파일 1개(pnpm) | 루트 `.gitignore`, `.env.example`, `.github/workflows/secrets.yml`, `pnpm-lock.yaml` 정책 | 없음 | P0 | S | Sonnet | 비밀 스캔이 테스트 키 커밋을 차단. `git ls-files`에 `.env.local`, `.next/`, `node_modules/` 0건 | 02장 6절 #7, 리뷰 5장 #1, #11 |
| SY-06-007 | 디자인 레퍼런스 분석(`DESIGN_SYSTEM.md` 4장 1단계): 레퍼런스 3개 선정, 원본 화면과 다른 방향 기록 | `docs/design/references.md` | 없음 | P0 | S | Sonnet | 레퍼런스 URL이 모두 `_design-guide/REFERENCES.md` 안에 있다. 원본 Airbnb 모방 요소(빨간 브랜드 색, 로고 형태) 미사용 확인표 | 03장 4.1절, 01장 D14 |
| SY-06-008 | 디자인 토큰과 기본 컴포넌트(2단계): Tailwind CSS v4 `@theme` 토큰, Button·Input·DatePicker·Counter·Dialog·Sheet 배리언트 | `apps/web/src/styles/`, `apps/web/src/components/ui/` | 004, 007 | P0 | M | Sonnet | 03장 3.9절 토큰과 일치. 대비 4.5:1 이상(본문). 컴포넌트 스토리 또는 데모 페이지 | 03장 3.9절 |
| SY-06-009 | 비주얼 검토(3단계, 사람 수행): 토큰·주요 화면 시안 검토와 승인 기록 | `docs/design/review-log.md` | 008 | P0 | S | 사람 | 승인 기록 1건, 수정 요청 반영 확인 | `DESIGN_SYSTEM.md` 4장 3단계 |
| SY-06-010 | 숙소 서버 계층: `create_listing`·RLS UPDATE·`transition_listing`·`delete_listing` 호출, zod 허용 목록, 등록 단계별 저장 함수 | `apps/web/src/server/listings/` | 001, 004 | P0 | M | Fable | 허용 목록 밖 필드(`org_id`, `status`) 전송 시 무시 또는 400. outsider 세션으로 수정 0행. 게시 조건 미충족 SY010을 단계별 안내로 변환 | 05장 7절 #1, #2, 리뷰 5장 #2 |
| SY-06-011 | 등록 마법사 13단계 UI, 단계마다 자동 저장, 체크리스트, 재개. 호스트 셸(헤더 + 좌측 GNB, 03장 8절)도 이 작업이 소유 | `apps/web/src/app/(host)/host/listings/[id]/edit/`, `apps/web/src/app/(host)/host/layout.tsx` | 008, 010, 045 | P0 | L | Sonnet | 13단계를 끝까지 진행해 게시까지 완료. 중간에 닫고 다시 열면 `register_step`에서 재개. 375px 레이아웃 | 01장 SY-F-014, 03장 2.3절 |
| SY-06-012 | 사진 업로드: 서명 업로드 URL Route, 이미지 검사(MIME·10MB), 순서·대표 지정, 변환 잡(640px·2048px) | `apps/web/src/app/api/uploads/`, `apps/web/src/server/photos/`, `apps/api/app/jobs/photos.py` | 001, 004, 005 | P0 | M | Opus | 비로그인 401. 다른 조직 경로 403. 경로에 원본 파일명 0건. 31장째 거부 | 05장 7절 #4, 리뷰 5장 #4 |
| SY-06-013 | 위치 입력과 지도 어댑터: 서버 전용 지오코딩 키 Route, 지도 컴포넌트 인터페이스(Google 구현, D6 대비) | `apps/web/src/lib/maps/`, `apps/web/src/app/api/maps/` | 004 | P0 | M | Opus | 브라우저 번들에 서버 키 0건. 주소 검색 → 핀 조정 → `listing_private` 저장 → 공개 좌표 소수 2자리 | 01장 SY-F-016, 리뷰 5장 #11 |
| SY-06-014 | 검색 화면: 검색 바, 결과 목록 + 지도(경계 검색, 400ms 디바운스), 필터, URL 쿼리 상태 | `apps/web/src/app/(public)/search/`, `apps/web/src/components/search/` | 008, 013 | P0 | L | Sonnet | 날짜가 겹치는 숙소 0건(시드 기준). 지도 이동 후 1초 안 갱신. 새로고침해도 필터 유지 | 01장 SY-F-003, 004, 리뷰 5장 #9 |
| SY-06-015 | 숙소 상세 SSR: 사진 갤러리(`next/image`), 정보, 호스트, 리뷰 목록, 대략 위치 지도, 메타·OG | `apps/web/src/app/(public)/listings/[id]/page.tsx`, `apps/web/src/components/listing/` | 008, 013 | P0 | M | Sonnet | 비공개 숙소 404. 초기 HTML에 제목. LCP 2.5초(4G 측정) | 01장 SY-F-005, 리뷰 5장 #15 |
| SY-06-016 | 예약 흐름: 날짜 선택기(불가 구간), 가격 계산, 예약 요청 서버 함수(`create_reservation`), 확인 화면 | `apps/web/src/server/reservations/`, `apps/web/src/app/(public)/listings/[id]/book/` | 010, 015 | P0 | M | Fable | 동시 요청 100건 중 성공 1건(통합 테스트). 금액 380,000원 예시 일치. SY002~SY006을 사용자 문구로 변환 | 05장 7절 #3, 리뷰 5장 #3 |
| SY-06-017 | 호스트 예약함: 탭, 승인·거절, 호스트 취소(사유), 남은 응답 시간 | `apps/web/src/app/(host)/host/reservations/` | 016 | P0 | M | Opus | 만료 요청 승인 SY007 안내. member의 호스트 취소 버튼 없음 + RPC 42501 | 01장 SY-F-009, 011, 013 |
| SY-06-018 | 내 여행: 다가오는/지난/취소 탭, 확정 후 주소·체크인 안내, 게스트 취소 | `apps/web/src/app/(guest)/trips/` | 016 | P0 | M | Sonnet | requested 카드에 주소 0건, 승인 후 표시. 체크인 당일 취소 버튼 비활성 | 01장 SY-F-010, 012 |
| SY-06-019 | 호스트 달력: 월 보기, 예약·차단 표시, 날짜 차단·해제 | `apps/web/src/app/(host)/host/listings/[id]/calendar/` | 016 | P1 | M | Sonnet | 예약과 겹치는 차단 시 SY003 안내. 차단 즉시 상세 달력 비활성 | 01장 SY-F-018 |
| SY-06-020 | 리뷰: 작성(완료 후 14일), 공개 목록, 호스트 답글 | `apps/web/src/app/(guest)/trips/[id]/review/`, `apps/web/src/components/reviews/`, `apps/web/src/server/reviews/` | 016 | P0 | M | Opus | 미완료 예약 리뷰 버튼 없음 + SY008. 중복 SY009. 답글 1회 | 01장 SY-F-019, 020, 리뷰 5장 #8 |
| SY-06-021 | 찜: 하트 버튼, 내 찜 목록 | `apps/web/src/app/(guest)/wishlist/`, `apps/web/src/components/listing/WishlistButton.tsx` | 015 | P1 | S | Sonnet | 비로그인 클릭 시 로그인 후 원래 화면 복귀. 내 찜 목록이 `my_wishlist`와 일치 | 01장 SY-F-021 |
| SY-06-022 | 정리 크론과 알림 메일 잡: `stay_run_maintenance` 매시간, `stay.notify.email` 핸들러 | `apps/api/app/jobs/maintenance.py`, `apps/api/app/jobs/notify.py`, `supabase/cron/`(001에 요청) | 005, 016 | P1 | M | Opus | 만료·완료 전환 건수 로그. 요청 생성 1분 안 호스트 메일(로컬 메일 캐처). 실패 3회 재시도 | 01장 SY-F-023, 024 |
| SY-06-023 | SEO: `sitemap.ts`(published만), `robots.ts`, OG 이미지 | `apps/web/src/app/sitemap.ts`, `apps/web/src/app/robots.ts` | 015 | P1 | S | Haiku | 비공개·삭제 숙소 sitemap 0건. `/host`, `/trips`, `/api` disallow | 01장 SY-F-025 |
| SY-06-024 | 랜딩·홈 + 3D 히어로(PC·태블릿 풀 3D, 모바일 단순, 정지 이미지 대체) | `apps/web/src/app/(public)/page.tsx`, `apps/web/src/components/hero3d/` | 008, 009 | P0 | L | Sonnet | `HERO_3D.md` 4절 수용 기준. 검색 바가 3D 전에 보이고 키보드 사용 가능. 카피 금지 문구 0건 | 01장 SY-F-026, 035, 03장 4절 |
| SY-06-025 | AI 채팅 경로: Dify 앱 설정, `/api/ai/chat`(세션 확인, 서명 토큰, 선차감, 스트리밍 중계, 직접 경로 폴백) | `apps/web/src/app/api/ai/chat/`, `apps/web/src/server/ai/`, `infra/dify/` | 001, 005 | P0 | M | Fable | 잔액 부족 402(`CR001`). 응답 미전달 턴 전액 환불. 다른 사용자 대화 id 404. Dify 중지 시 10초 안 직접 경로 | 01장 SY-F-027, 034, `AI_ARCHITECTURE.md` 2장 |
| SY-06-026 | 숙소 공개 정보 색인 잡: 게시·수정 시 `listing-<id>` 컬렉션 재색인(정확한 주소 제외) | `apps/api/app/ai/rag/stay_listing.py`, `apps/api/app/jobs/index_listing.py` | 005, 010 | P0 | M | Opus | 게시 후 5분 안 검색 가능. 청크 본문에 `listing_private` 값 0건. 비공개 전환 시 컬렉션 비활성 | 01장 SY-F-027, 6.1절 |
| SY-06-027 | 도우미 채팅 위젯: 상세 오른쪽 시트, 스트리밍, 출처, 크레딧 안내, AI 표시 | `apps/web/src/components/ai/` | 008, 025 | P0 | M | Sonnet | 답변마다 출처 또는 "찾지 못했습니다" 문구. 잔액 부족 시 안내 카드. 키보드로 열고 닫기 | 03장 3.10절 |
| SY-06-028 | 그래프 `stay.listing_assist` + `/api/ai/listing-assist` + 마법사 초안 카드 | `apps/api/app/ai/graphs/stay_listing_assist.py`, `apps/web/src/app/api/ai/listing-assist/`, `apps/web/src/components/ai/ListingDraft*.tsx` | 025, 035, 011 | P0 | M | Fable | 평가셋 30건 금지 문구 0건. 고르기 전 `listings` 변경 0행. 실패 시 환불 | 01장 SY-F-029 |
| SY-06-029 | 그래프 `stay.review_summary` + 하루 1회 잡 + 상세 요약 영역 | `apps/api/app/ai/graphs/stay_review_summary.py`, `apps/api/app/jobs/review_summary.py`, `apps/web/src/components/reviews/ReviewSummary.tsx` | 020, 035 | P1 | M | Opus | 상용 제공자 호출 0건. 리뷰 9건 이하 숙소 요약 없음. 이름·연락처 0건 | 01장 SY-F-030 |
| SY-06-030 | RLS·권한 회귀 테스트: `rls_smoke.mjs` 49항목을 로컬 Supabase SQL 테스트로 옮기고 확장(Storage 정책, 정지 사용자, viewer) | `supabase/tests/` | 001 | P0 | M | Fable | 60항목 이상 통과, CI에서 실행. 실패 시 머지 차단 | 05장 9절, 리뷰 5장 #6, #13 |
| SY-06-031 | 자연어 검색 도우미 `stay.search_parse` + `/api/ai/search-parse` + 필터 미리보기 + 평가셋 | `apps/api/app/ai/llm/stay_search_parse.py`, `apps/web/src/app/api/ai/search-parse/`, `apps/web/src/components/search/NaturalQuery.tsx` | 014, 025 | P1 | M | Opus | 평가셋 정답률 90%. 실패 시 일반 폼으로. 하루 한도 초과 429 | 01장 SY-F-028 |
| SY-06-032 | 호스트 위키: 매뉴얼 업로드, ingest 잡, 검수·발행 화면, 이력 | `apps/web/src/app/(host)/host/wiki/`, `apps/api/app/ai/wiki/stay.py` | 005, 025 | P0 | M | Opus | 게스트가 draft 조회 404. 충돌 409. 사람 소유 블록 덮어쓰기 0건 | 01장 SY-F-031 |
| SY-06-033 | 음성 대화: 마이크 버튼, `/api/voice/stt`·`/api/voice/tts`, 고지 확인 | `apps/web/src/components/voice/`, `apps/web/src/app/api/voice/` | 025, 027 | P0 | M | Opus | 30초 자동 중지. 고지 없이 403. 마이크 거부 시 텍스트 정상. `store_audio=false` 100% | 01장 SY-F-032 |
| SY-06-034 | 온보딩 AI 처리 방식 선택(국외 이전 동의), 설정에서 철회 | `apps/web/src/app/onboarding/`, `apps/web/src/app/(guest)/settings/ai/` | 003 | P0 | S | Sonnet | 미동의 사용자 `ai_usage` 상용 0건. 철회 직후 반영 | 01장 SY-F-033 |
| SY-06-035 | AI compliance 규칙과 평가셋: 금지 문구, 연락처·URL·비밀번호 가리기, 안전·법적 단정 금지, 평가셋 30문항×3기능 | `apps/api/app/ai/compliance/stay.py`, `apps/api/tests/eval/` | 005 | P0 | M | Opus | 평가셋 전체에서 금지 문구 0건. CI에서 실행 | 01장 SY-F-036, 6.1절 |
| SY-06-036 | 크레딧 정산 크론과 미정산 감시 | `apps/api/app/jobs/settle.py` | 005, 025 | P0 | S | Opus | 1시간 넘은 미정산 0행. 같은 멱등 키 차감 1회 | 01장 SY-F-034 |
| SY-06-037 | E2E(Playwright): 검색 → 예약 → 승인 → 완료 → 리뷰, 등록 → 게시, 동시 예약 1건 성공, 비로그인 경계 | `apps/web/e2e/` | 011, 014, 016, 017, 018, 020 | P0 | M | Opus | 시나리오 6개 통과(로컬 + CI). 실패 시 스크린샷 | 리뷰 5장 #13 |
| SY-06-038 | 결제 E2E(Toss 테스트 키): 예약 결제·취소 환불(Phase 2, D2 결정 뒤 범위 확정) | `apps/web/e2e/payments/` | D2, 결제 구현 작업(Phase 2) | P2 | M | Opus | Toss 테스트 결제 승인·취소, 웹훅 멱등 | `DOC_TEMPLATE.md` 2.7절 필수 작업, 01장 D2 |
| SY-06-039 | Stage B: Google OAuth + 이메일 가입·로그인·재설정 화면 + `/auth/callback` + 온보딩 약관 | `apps/web/src/app/(auth)/`, `apps/web/src/app/auth/callback/` | G1(AUTH_ROADMAP 4장), 003 | P0 | M | Fable | AUTH_ROADMAP 5.3절 B-1~B-6. `next`가 외부 URL이면 무시 | 01장 SY-F-001, 8.1절 |
| SY-06-040 | Stage C1: 카카오 로그인 | `apps/web/src/lib/auth/providers/kakao.ts`, 로그인 화면 버튼(039 소유 파일에 요청) | G2, 039 | P1 | S | Opus | AUTH_ROADMAP 7.1.3절 C1-1~C1-5. D15 반영 | 8.1절 |
| SY-06-041 | Stage C2: 네이버 로그인(스파이크 → `custom:naver` 또는 브리지) | `apps/web/src/lib/auth/providers/naver.ts`, `apps/web/src/app/api/auth/naver/`(브리지일 때) | G2, 039 | P1 | M | Fable | AUTH_ROADMAP 7.2.4절 C2-1~C2-6. D16 결정 `log.md` 기록 | 8.1절 |
| SY-06-042 | 성능 점검: 검색 p95, 상세 LCP, 이미지 용량, 번들 크기 | `scripts/perf/` | 014, 015, 024 | P1 | S | Opus | 01장 5절 수치 충족 또는 미달 항목 개선 작업 생성 | 01장 5절 |
| SY-06-043 | 운영 스크립트: 숙소 정지·해제, 리뷰 숨김(service_role CLI, 감사) | `scripts/ops/` | 001 | P1 | S | Haiku | 정지 직후 검색 0건. 감사 행 1건 | 01장 SY-F-022 |
| SY-06-044 | 접근성·반응형 점검: 375/768/1280px, 키보드, 대비 | 점검 보고 `docs/qa/a11y.md`(수정은 해당 화면 작업에 요청) | 011, 014, 015, 016, 018 | P1 | S | Sonnet | 03장 6절 항목 전부 통과 또는 수정 요청 생성 | 03장 6절 |
| SY-06-045 | 정적 데이터 이식: 건물 유형, 침대 유형, 편의시설·공용공간 목록(원본 `lib/staticData.ts`) | `apps/web/src/lib/static-data.ts` | 004 | P0 | S | Haiku | 원본 목록 항목 수와 같고 오타(`amentities`) 없음 | 07장 2절, 리뷰 5장 #14 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | SY-06-001, 004, 005, 006, 007, 045 | 6 | 없음 | 로컬 DB와 타입, 빈 web·api 골격, 저장소 위생, 디자인 레퍼런스, 정적 데이터 |
| W1 | SY-06-003, 010, 012, 013, 030, 035 | 6 | W0 완료 | Mock 로그인, 숙소 서버 계층, 업로드, 지도 어댑터, RLS 회귀 테스트, compliance |
| W1-D | SY-06-008 → 009(사람) | 1 | 004, 007 | 디자인 토큰·컴포넌트, 비주얼 승인 |
| W2 | SY-06-011, 014, 015, 016, 025, 026 | 6 | W1, W1-D 완료 | 등록 마법사, 검색, 상세, 예약, AI 채팅 경로, 숙소 색인 |
| W3 | SY-06-017, 018, 020, 027, 028, 032, 033, 034, 036 | 9(동시 5 권장) | W2 완료 | 호스트 예약함, 내 여행, 리뷰, 도우미 위젯, 소개 작성, 위키, 음성, 온보딩, 정산 |
| W4 | SY-06-002, 019, 021, 022, 023, 024, 029, 031, 043 | 9(동시 5 권장) | W3 완료 | 모듈러 조각, 달력, 찜, 크론·메일, SEO, 랜딩·3D, 리뷰 요약, 자연어 검색, 운영 스크립트 |
| W5 | SY-06-039(맨 앞) → 037, 042, 044 | 4 | W4 완료 + G1 | Google 로그인, E2E, 성능·접근성 점검 → 공개 베타 |
| W6 | SY-06-040, 041 | 2 | G2 | 카카오·네이버 로그인 |
| W7 | SY-06-038 | 1 | Phase 2 결제 착수(D2) | 결제 E2E |

## 4. 모델별 비율

사람 작업(SY-06-009) 1개를 빼고 44개 기준.

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 9(002, 003, 010, 016, 025, 028, 030, 039, 041) | 9/44 = 20% | 18/79 = 23% |
| Opus | 19(001, 004, 005, 012, 013, 017, 020, 022, 026, 029, 031, 032, 033, 035, 036, 037, 038, 040, 042) | 19/44 = 43% | 34/79 = 43% |
| Sonnet | 13(006, 007, 008, 011, 014, 015, 018, 019, 021, 024, 027, 034, 044) | 13/44 = 30% | 24/79 = 30% |
| Haiku | 3(023, 043, 045) | 3/44 = 7% | 3/79 = 4% |

## 5. 리뷰 작업 흡수표

| 리뷰 5장 # | 리뷰 작업 | 흡수한 작업 ID |
|---|---|---|
| 1 | `.gitignore` 보강, 인덱스에서 비밀·산출물 제거, 비밀 재발급 | SY-06-006(새 저장소 위생). 원본 저장소 정리는 07장 5절 |
| 2 | 숙소 등록·수정·삭제 소유자 검사, 수정 컬럼 허용 목록 | SY-06-001(RLS·컬럼 GRANT), SY-06-010 |
| 3 | 예약 생성 세션 사용자, 날짜·인원 검증, 겹침 차단 | SY-06-001(배타 제약), SY-06-016 |
| 4 | 업로드 인증·형식·크기·키 정리 | SY-06-012 |
| 5 | `_app.tsx` 전역 쿠키 제거 | SY-06-004(요청 단위 클라이언트, App Router) |
| 6 | RLS 활성화와 정책, 쓰기 RPC 이동 | SY-06-001, SY-06-030 |
| 7 | Refresh 토큰 저장·폐기, OAuth state, 같은 이메일 계정 연결 | SY-06-003, SY-06-039(Supabase Auth로 대체, 07장 3절) |
| 8 | 리뷰를 완료 예약 1건당 1개로 | SY-06-001(유니크 제약), SY-06-020 |
| 9 | 검색 재작성(지도 경계, 겹침 제외, 조인 1회) | SY-06-001(`search_listings`), SY-06-014 |
| 10 | 오류 응답 표준화 | SY-06-004(`src/lib/http/`), 04장 7절 |
| 11 | 서버 전용 Maps 키, `.env.example` | SY-06-013, SY-06-006 |
| 12 | 오래된 의존성 교체 | SY-06-004(새 스택, 07장 3절 폐기 목록) |
| 13 | API 단위·권한 회귀 테스트 | SY-06-030, SY-06-037 |
| 14 | 죽은 코드·오타·빈 저장소 정리 | SY-06-045(정적 데이터만 이식), 07장 3·5절 |
| 15 | `next/image`, favicon, 대시보드 통합 | SY-06-015, SY-06-018, SY-06-024 |

## 6. 공용 모듈 요청

| ID | 요청 | 대상 | 이유 | 우선순위 |
|---|---|---|---|---|
| R-1 | `AUTH_ROADMAP.md` 8장 매트릭스에 airbnb(`stay`) 행 추가(01장 8.1절 문안) | `_platform-core/AUTH_ROADMAP.md` | 신규 제품 등록 | P0 |
| R-2 | `DB_CONVENTIONS.md`에 스키마 `stay` 번호 2700, SQLSTATE 접두사 `SY` 등록. core 0000에 `btree_gist` 확장 추가 | `_platform-core/DB_CONVENTIONS.md`, `_supabase-modular/migrations/0000_*` | 번호 충돌 방지, 모듈러 배타 제약 | P0 |
| R-3 | 지리 검색 공용 헬퍼(PostGIS 또는 경계 검색 함수) 검토 | `_platform-core/SHARED_MODULES.md` | 숙소 1만 개 이후 성능(05장 5절). 다른 지도 제품(local-news 등)과 공유 가능 | P2 |
| R-4 | 공용모듈 `community`(신고·차단)와 `search` 채택 검토 | `develop_V2/` | Phase 2 신고 접수·메시지 차단, 숙소 텍스트 검색 | P2 |
| R-5 | 네이버 브리지 선택 시 코어 SECTION 6-A(oauth_states)와 staged 0010 적용 | `_platform-core/staged/` | 01장 D16 | P1(C2 착수 시) |

## 7. 완료 정의

| 항목 | 기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -C apps/web build`, `tsc --noEmit`, `eslint` 오류 0. `apps/api`는 `ruff`, `mypy`, `pytest` 통과 |
| DB | `supabase db reset` 오류 0, SY-06-030 RLS 회귀 60항목 이상 통과 |
| E2E | SY-06-037 시나리오 6개 통과 |
| AI | SY-06-035 평가셋 금지 문구 0건, 미정산 0행 |
| 성능 | 01장 5절 검색·상세·3D 수치(SY-06-042 보고) |
| 인증 | G1 통과 후 B 완료(B-1~B-6), G2 후 C1·C2 |
| 작업 | 이 장 2절 P0 작업 전부 완료. P1은 공개 베타 후 4주 안 |
| 결제 E2E | Phase 2(D2) 착수 시 SY-06-038 |

## 8. 인증 단계 작업

### 8.1 단계와 작업

| 단계 | 작업 | 웨이브 | 비고 |
|---|---|---|---|
| A | SY-06-003 | W1 | 앞 웨이브(W0) 작업은 시드 없이 SQL·단위 테스트로 검증 |
| B | SY-06-039 | W5 맨 앞 | 공개 베타 직전. E2E(037)가 039 완료를 기다린다 |
| C1 | SY-06-040 | W6 | G2 후 |
| C2 | SY-06-041 | W6 | G2 후, 스파이크 먼저 |

### 8.2 게이트

| 게이트 | 조건 |
|---|---|
| G1 | Mock 계정으로 E2E 핵심 시나리오(검색 → 예약 → 승인 → 리뷰) 통과, RLS 회귀 통과(AUTH_ROADMAP 4장) |
| G2 | Google 로그인이 베타에서 2주 이상 오류율 1% 미만(AUTH_ROADMAP 6장) |

### 8.3 페르소나 사용

05장 10절 페르소나(`host`, `guest` + 공통)를 E2E와 수동 점검에 쓴다. 테스트가 날짜를 옮겨 completed 상태를 만들 때는 service_role 테스트 헬퍼만 쓴다.

### 8.4 금지

쿠키 역할 Mock, 클라이언트에서 정한 사용자 id, 콜백 `next` 무검증, 원본 자체 JWT 코드 재사용(07장 6절).

## 추가 작업 후보 (미배정 · 위 집계에 포함하지 않음)

| ID | 작업 | 근거 |
|---|---|---|
| SY-06-046 | 날씨 어댑터 `/api/weather` + 서버 캐시 + 출처 표기 | SY-F-038, 04장 6.5절 |
| SY-06-047 | 환율 캐시 크론 `fx_rates` + 표기 컴포넌트(제공자 결정 D19 후) | SY-F-039, 04장 6.6절 |
| SY-06-048 | 카카오맵·네이버 지도 `MapProvider` 구현 | D6, 04장 6.3절 |

