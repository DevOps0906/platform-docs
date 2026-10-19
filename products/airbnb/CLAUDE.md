# CLAUDE.md: Stay(가칭)

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `AI_ARCHITECTURE.md`, `AUTH_ROADMAP.md`(인증 작업이면 맨 끝 "인증 단계 규칙") |
| 2 | 이 폴더 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | `supabase/monolith/migrations/0002_stay_domain.sql`(DB 정본, SY-06-002 이후에는 `_supabase-modular/migrations/2700_stay.sql`) |
| 4 | UI 작업이면 `docs/products/_design-guide/`(`DESIGN_PRINCIPLES.md`, `DESIGN_SYSTEM.md`, `HERO_3D.md`, `REFERENCES.md`) |
| 5 | AI·음성 작업이면 `_platform-core/LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`는 서버 전용. 클라이언트는 `apps/web/src/lib/supabase/admin.ts` 하나이고 잡·크론·운영 스크립트(`apps/api`, `scripts/ops`)만 import한다. 사용자 요청 경로(페이지, 서버 함수, Route Handler)는 요청 단위 사용자 세션 클라이언트만 쓴다 |
| 사용자 id | 요청 body·쿼리의 사용자 id를 소유자·게스트로 쓰지 않는다. 게스트는 `auth.uid()`, 호스트 조직은 세션의 조직 멤버십으로만 정한다(리뷰 #2, #3) |
| 전역 상태 | 서버 코드에서 전역 쿠키·전역 헤더·모듈 수준 사용자 변수를 두지 않는다(리뷰 #5) |
| 정확한 주소 | 상세주소·정확 좌표·체크인 안내는 `listing_private`에서만 읽는다. 공개 화면·AI 근거·로그에 넣지 않는다 |
| 크레딧 | AI·음성 경로(`/api/ai/*`, `/api/voice/*`, `/api/host/wiki/*`)에서만 `consume_credits` 선차감 후 정산. 검색·예약·리뷰·찜·알림 경로는 크레딧을 쓰지 않는다 |
| AI 경계 | 브라우저는 Dify·FastAPI·LLM 제공자를 직접 부르지 않는다. Next.js → FastAPI는 서명 토큰. 리뷰 원문을 상용 제공자로 보내지 않는다(`stay.review_summary` 오픈소스 강제) |
| AI는 제안만 | 소개 작성 도우미 결과는 호스트가 고를 때만 저장한다 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*`를 수정하지 않는다. 필요하면 06장 6절에 요청 |
| DB 변경 | `supabase/migrations/`는 SY-06-001 소유. 스키마 변경은 SY-06-001 후속 마이그레이션(`0003_stay_*.sql`)으로만 |
| 상표 | "Airbnb", "에어비앤비"를 제품명·카피에 쓰지 않는다. 원본의 빨간 브랜드 색, 로고, 이미지, 화면 배치를 복사하지 않는다(07장 3절 #18, #19) |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정, `@theme`). `tailwind.config.js`·v3 문법 금지 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산 준수 |

## 3. 디렉토리와 소유 경계

`apps/web/src/` 아래: `app/(public)` 홈·검색·상세·예약, `app/(guest)` 내 여행·찜·설정, `app/(host)/host` 숙소 등록·달력·예약함·위키, `app/(auth)` 로그인, `app/auth/callback`, `app/onboarding`, `app/api/ai`·`app/api/voice`·`app/api/uploads`·`app/api/maps`·`app/api/dev`, `server/<도메인>`(listings, photos, reservations, reviews, ai), `lib/supabase`(004 소유), `lib/auth`(003·039), `lib/maps`(013), `lib/http`(004), `components/ui`(008), `components/hero3d`(024), `components/ai`(027·028), `components/voice`(033), `styles/tokens.css`(008). `apps/api/app/`: `core`·`jobs/runner.py`(005), `jobs/*`(012, 022, 026, 029, 036), `ai/graphs`(028, 029), `ai/compliance`(035), `ai/wiki`(032). DB `supabase/`(001, tests는 030). 작업별 소유는 06장 2절 표가 정본이며 남의 디렉토리는 읽기만 한다.

## 4. 코어 사용 규칙

| 항목 | 규칙 |
|---|---|
| 세션 | 로그인 필요 라우트 진입부 `requireSession('stay')`. 호스트 화면은 `session_context`의 조직 역할로 메뉴를 나눈다. 정지 계정은 RPC가 42501 |
| 가입 | `signUp({ options: { data: { signup_app: 'stay' } } })`. 모놀리스는 앱 행 1개라 자동 부트스트랩 |
| 플랜 | 기능 게이팅은 서버에서 `entitled_plan_code` + `plans.features`(01장 4절). DB 한도는 RPC(`max_listings`)와 RLS(사진 30장) |
| 크레딧 | `consume_credits`는 `src/server/ai/credits.ts`에서만(멱등 키 `conv:<id>:turn:<n>`, `run:<id>`, `voice:<id>`). 실패·미전달은 `refund_credits`. 정산은 SY-06-036 크론 |
| 잡 | `enqueue_job`: `stay.photo.process`(012), `stay.ai.index_listing`(026), `stay.wiki.ingest`(032), `stay.ai.review_summary`(029), `stay.notify.email`(022). 소비는 `apps/api` 워커 |
| 감사 | 숙소·예약 RPC가 내부에서 `write_audit`. 게스트 행동은 게스트 개인 조직에 기록. 음성 고지 확인은 `voice.notice_ack` |
| 레이트 리밋 | DB: RPC 내부 `stay_rate_limit`(키 `stay:<동작>:<id>`). Route Handler: 검색·상세 IP HMAC 120/분, 업로드 60/시간(01장 5절) |
| 오류 | RPC SQLSTATE(SY001~SY012, SY429, 42501, CR001)를 `src/lib/http/` 매핑으로 `{code, message}` 응답(04장 7절) |

## 5. 코드 규칙

| 항목 | 내용 |
|---|---|
| 스택 | Next.js 16.2.x(App Router), React 19, TypeScript 5, Tailwind CSS v4, shadcn/ui, zod, `@supabase/ssr`. `apps/api`는 FastAPI + Python 3.12, LangChain/LangGraph |
| 패키지 | pnpm(락파일 하나). Python은 uv |
| 타입 생성 | `supabase gen types typescript --local --schema public > apps/web/src/types/supabase.ts` |
| 디자인 토큰 | `apps/web/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`가 정답. hex를 화면 코드에 직접 쓰지 않는다 |
| 이미지 | `next/image`. 숙소 사진은 Storage 변환본(640px, 2048px) |
| 입력 검증 | Route Handler·서버 함수 입력은 zod 허용 목록. 모르는 필드는 버린다 |
| 렌더 | 공개 상세·검색은 서버 컴포넌트. 클라이언트 전역 상태 라이브러리를 들이지 않는다(필터는 URL 쿼리) |

## 6. 테스트와 완료 조건

06장 7절이 정본이다.

| 명령 | 기준 |
|---|---|
| `pnpm -C apps/web build`, `pnpm -C apps/web exec tsc --noEmit`, `pnpm -C apps/web lint` | 오류 0 |
| `supabase db reset` + `supabase/tests`(SY-06-030) | RLS 회귀 60항목 이상 통과 |
| `pnpm -C apps/web exec playwright test`(SY-06-037) | 시나리오 6개 통과 |
| `uv run pytest`, `uv run ruff check`, `uv run mypy`(apps/api) | 통과, 평가셋 금지 문구 0건(SY-06-035) |

P0 작업은 대응 테스트가 통과해야 완료다. 구현이 기획과 달라지면 코드를 조용히 맞추지 말고 문서를 고치는 task를 따로 만든다.

## 7. 금지 패턴

07장 4절 요약: body의 사용자 id 신뢰, `...req.body` 그대로 update, 쓰기 경로의 인증 누락, 전역 axios/쿠키 헤더, 무인증·public-read 업로드와 원본 파일명 키, RLS 끄기, service_role을 사용자 요청에 사용, 예외 객체 응답, 서버에서 `NEXT_PUBLIC_` 키 사용, state 없는 OAuth, `Set-Cookie` 중복 설정, 조회 후 삽입식 중복 방지, 코드만으로 하는 날짜 겹침 검사, 비밀 커밋, 정확한 주소 공개, 타사 상표 복제.

## 인증 단계 규칙

| 항목 | 내용 |
|---|---|
| 지금 단계 | A(Mock). B는 G1 뒤 SY-06-039, C1·C2는 G2 뒤 SY-06-040·041 |
| 분기 위치 | 단계 분기는 `src/lib/auth/`, 로그인 화면, `/auth/callback`에만. 다른 코드는 `requireSession('stay')`만 안다 |
| 페르소나 | 05장 10절: 공통(`owner`, `admin`, `member`, `viewer`, `outsider`, `no_app`, `suspended`, `ops`) + 제품(`host`, `guest`). 시드는 `scripts/dev/seed-users.mjs --app stay` 후 `seed-users.stay.mjs` |
| 금지 | 쿠키 역할 Mock, `mock-auth.ts`, 콜백 `next` 무검증, 원본 자체 JWT·refresh 코드 재사용(07장 6절) |
| 비로그인 | 검색·상세·리뷰 목록·불가 달력은 단계와 무관한 공개 RPC. 예약·찜·도우미는 로그인 후 원래 화면으로 복귀 |

## 호스트 셸 규칙

호스트 화면(`/host/*`)은 헤더 + 좌측 GNB 셸 안에 둔다. 구성과 결정 대기 항목은 03장 8절이 정본이다. 셸 레이아웃 `apps/web/src/app/(host)/host/layout.tsx`는 SY-06-011만 소유하고(06장 2절), 게스트 화면과 공개 화면은 셸 밖이다.
