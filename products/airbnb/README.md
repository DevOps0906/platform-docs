# Stay, 가칭 (airbnb)

## 1. 한 줄 정의

여행자(게스트)가 지도와 날짜·인원으로 숙소를 찾아 예약을 요청하고, 개인 호스트가 13단계 마법사로 숙소를 올려 예약을 승인·관리하는 숙소 공유 웹 서비스다. Airbnb 클론코딩 원본(`docs/reviews/Airbnb_CloneCoding.md:7`)의 검색 → 상세 → 예약, 등록 13단계, 리뷰, 찜 흐름을 유지하고, 원본에 없던 권한 경계(RLS + RPC), 이중 예약 차단, 정확한 주소 비공개, 호스트 승인 흐름을 새로 설계했다. 공용 코어(로그인·조직, 크레딧, 잡, AI 계층, 음성)를 쓰고, 숙소 AI 도우미(숙소 공개 정보 근거 질의응답), 자연어 검색, 호스트 숙소 소개 작성 도우미, 리뷰 요약, 호스트 위키, 음성 대화, 3D 히어로를 MVP에 넣는다(`docs/products/_platform-core/DOC_TEMPLATE.md` 2.2절 AI·음성 필수 내용).

| 대상 | 상황 |
|---|---|
| 게스트(여행자) | 휴대폰·노트북으로 여행지와 날짜를 넣고 숙소를 비교한다. 로그인 없이 검색·상세를 보고, 예약·찜·리뷰·AI 도우미는 로그인 후 쓴다 |
| 호스트(개인 숙소 운영자) | 집 한 채나 방 하나를 빌려준다. 숙소를 올리고 사진·요금·달력을 관리하며 예약 요청을 승인한다 |
| 운영자 | 신고된 숙소를 정지하고 정리 작업을 돌린다(MVP는 service_role 스크립트, 운영 화면은 Phase 2) |

제품명 "Airbnb"는 상용 서비스 상표라서 쓰지 않는다. 작업명은 seed의 앱 이름 "Stay"(`supabase/monolith/seed.sql:11-14`)이고 최종 브랜드명은 01장 8절 D1이다. 원본의 디자인(로고, 빨간 브랜드 색 `styles/palette.ts`, 화면 배치)을 그대로 옮기지 않는다(01장 6절 금지 문구, D14).

## 2. 통합 근거

단독 제품이다. 플랫폼의 기존 16개 제품과 합칠 원본이 없고(`docs/products/README.md` 제품 목록에 숙박 도메인 없음), 이 문서 묶음이 처음 등록한다.

| 근거 | 내용 |
|---|---|
| 베이스 | 원본은 동작하는 Next.js 14 Pages Router 코드다(완성도 약 60%, `docs/reviews/Airbnb_CloneCoding.md:18`). 화면 흐름과 정적 데이터는 가져오되 서버 코드는 공용 코어 위에서 다시 쓴다(07장) |
| 리뷰 높음 7건 | 쓰기 API 무인증 4건, SSR 쿠키 공유, RLS 비활성, 비밀 유출 위험(`docs/reviews/Airbnb_CloneCoding.md:55-61`). 구조 문제라서 원본 수정보다 재작성이 싸다(리뷰 4장) |
| 공용 코어 | Supabase Auth + 조직 + 엔타이틀먼트(`docs/products/_platform-core/CORE_SPEC.md`), 크레딧 선차감(`AI_ARCHITECTURE.md` 7장), 잡, Storage `public-assets` 버킷을 그대로 쓴다. 원본의 자체 JWT·refresh·OAuth 콜백(약 600줄)은 버린다 |
| 확정 결정 4 | 결제 PG는 Toss. 이 제품의 예약 결제와 호스트 유료 플랜은 Phase 2(01장 D2) |
| 확정 결정 5 | org 기준 스키마, 1인 1워크스페이스. 호스트의 숙소는 호스트 개인 조직에 속하고 게스트는 `auth.uid()`로만 식별한다 |
| 확정 결정 22 | 인증 단계 A Mock → B Google + 이메일 → C1 카카오·C2 네이버. 원본이 이미 3개 제공자를 다뤄 본 경험(콜백 응답 구조, 네이버 state)은 07장 2절에 참고로 남긴다 |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `D:\WorkSpace\CloneCoding\Airbnb_CloneCoding` (`next-bnb`) | `docs/reviews/Airbnb_CloneCoding.md` | 약 60%, 동작 코드 | 검색·상세·예약 흐름, 등록 13단계 순서와 필드, 정적 데이터(`lib/staticData.ts`: 건물·침대·편의시설 목록), 리뷰·찜 개념, 카카오·네이버 응답 처리 지식, 테이블 컬럼 구성(`supabase/migrations/001_initial_schema.sql`) | 자체 JWT·refresh·OAuth 콜백, service_role 단일 접근, RLS 비활성 스키마, S3 업로드, Redux 6개 slice, styled-components, axios 전역 쿠키, JSON 파일 저장소(`lib/data`, `data/`), 원본 디자인 |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구사항(SY-F-001~036)과 수용 기준, 플랜과 AI·음성 크레딧 단가, 비기능 수치, 법/개인정보(숙박업 신고, 위치정보, AI·음성 고지), KPI, 열린 결정(D1~D14, 인증 단계 D15~D17은 8.1절) |
| `02_ARCHITECTURE.md` | 스택(Next.js 16 App Router, Tailwind CSS v4, FastAPI·LangGraph·Dify·음성·3D), 모듈 경계, 잡, AI 라우팅 기본값과 그래프 `stay.listing_assist`·`stay.review_summary`, 리뷰 높음 #5, #7 차단 설계, 배포, 환경변수, 인증 단계(9절) |
| `03_SCREENS_UX.md` | 화면 목록, 플로우(검색 → 예약, 등록 → 게시, 승인, 리뷰), 화면별 명세와 와이어프레임, AI 도우미·음성·위키 화면, 디자인 시스템, 랜딩과 3D 히어로, 인증 화면(7절), 호스트 셸(8절) |
| `04_API.md` | Route Handler, RPC 계약, 잡 페이로드, 웹훅(Phase 2 Toss), 외부 어댑터(지도, Storage, FastAPI, Dify), 오류 코드(SY###), 인증 단계 라우트(8절) |
| `05_DATA_MODEL.md` | 테이블 7개, 상태 전이(숙소·예약·리뷰), RLS, 리뷰 높음 #1~#4, #6 차단 설계, 모놀리스와 모듈러의 차이, 마이그레이션과 검증(PGlite 스모크 49/49), 시드 페르소나(10절: 공통 + `host`·`guest`) |
| `06_AGENT_PLAN.md` | 작업 목록(SY-06-###), 웨이브, 모델 비율, 리뷰 작업 흡수표(15행), 공용 모듈 요청, 완료 정의, 인증 단계 작업(8절) |
| `07_SOURCE_MIGRATION.md` | 원본 자산 분류, 이식 자산 상세, 폐기 목록, 복사 금지 결함(인증 단계 6절), 아카이브 절차 |
| `08_DESIGN_SYSTEM.md` | 디자인 시스템: 방향, 토큰(라이트/다크 대비 계산), 기본·제품 컴포넌트, 배지 매핑, 접근성, 구축 순서 |
| `design/tokens.css` | Tailwind v4 토큰 초안(`apps/web/src/styles/tokens.css`의 출발점) |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/migrations/0001_core_lite.sql` | `MONOLITH_CORE_LITE.sql` 사본. SECTION 6-A, 6-B, 9를 이유 주석과 함께 지웠다 |
| `supabase/monolith/migrations/0002_stay_domain.sql` | 도메인 테이블 7개, 트리거, RLS, 공개·호스트·게스트·정리 RPC. 현재는 이 파일이 정본(05장 8절) |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 2개(free만 활성, AI 키와 크레딧 포함), AI 라우팅 기본값 11행 + 체인 검사 |
| `supabase/monolith/tests/rls_smoke.mjs` | PGlite RLS·RPC 스모크 49항목(05장 9절) |

## 5. DB 구조 선택

| 단계 | 구조 | 이유 |
|---|---|---|
| 개발·베타 | 모놀리스(단독 Supabase, `public` 스키마) | 숙소 사진·검색 트래픽과 지도 조회가 다른 제품과 성격이 달라 단독 프로젝트로 시작한다(제안). 원본도 단독 Supabase였다(`001_initial_schema.sql:1-4`). 모놀리스 SQL은 PGlite 스모크를 통과했다(05장 9절) |
| 계정 공유가 필요해지면 | 모듈러(`stay` 스키마, 번호 2700) | 다른 NOMAD 제품과 로그인·크레딧을 합칠 때. 조각 `_supabase-modular/migrations/2700_stay.sql`은 SY-06-002가 만든다 |

모놀리스 스키마는 `public`이다(`MONOLITH_CORE_LITE.sql` 머리말). 최종 확인은 사용자 결정으로 남긴다(01장 D12).
