# 07 원본 이식과 폐기: Stay(가칭)

근거 약어: 리뷰 = `docs/reviews/Airbnb_CloneCoding.md`, 원본 = `D:/WorkSpace/CloneCoding/Airbnb_CloneCoding/`(아래 경로는 원본 루트 기준), SQL = `supabase/monolith/migrations/0002_stay_domain.sql`.

## 1. 원본별 자산 분류

원본은 동작하는 Next.js 14 Pages Router 코드다(완성도 약 60%, 리뷰:18). 서버 코드는 리뷰 높음 7건(리뷰:55-61) 때문에 재작성하고, 화면 흐름·필드 구성·정적 데이터만 가져온다. 코드를 파일 단위로 복사하지 않는다. "이식"은 내용(목록, 순서, 검증 규칙)을 새 구조로 옮긴다는 뜻이다.

AI 관련 원본 자산: 없다(리뷰:15 "AI 없음"). 숙소 도우미, 자연어 검색, 소개 작성, 리뷰 요약, 호스트 위키, 음성, 3D 히어로는 전부 신규이고 설계 정본은 `_platform-core`의 AI·음성 문서다.

| 자산(파일/디렉토리) | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `pages/room/register/*.tsx` 13개(단계 순서) | 동작 | 이식(순서·단계 구성) | SY-06-011, 01장 SY-F-014 | 리뷰:24 |
| `components/room/register/*` 21개(필드, 검증, 체크리스트) | 동작 | 참고(필드·검증 규칙만, UI는 새 디자인) | SY-06-011 | 리뷰:43 |
| `store/registerRoom.ts`(246줄, 등록 상태 모델) | 동작 | 이식(필드 목록 → `listings` 컬럼), Redux는 폐기 | 05장 2.1절, SY-06-010 | `store/registerRoom.ts:6` |
| `lib/staticData.ts`(419줄: 건물 유형 6종 묶음, 침대 유형, 국가, 편의시설·공용공간) | 동작 | 이식 | `apps/web/src/lib/static-data.ts`, SY-06-045 | `lib/staticData.ts:26-131`, `:134`, `:396`, `:412` |
| `components/home/searchRoomBar/*` 6개 + `hooks/useSearchRoomDate.ts` | 동작 | 참고(입력 항목: 위치, 체크인, 체크아웃, 인원) | SY-06-014, SY-06-024 | 리뷰:23 |
| `components/room/main/*` 4개(목록 + 지도) | 동작 | 참고(목록·지도 동기화 동작만) | SY-06-014, 01장 SY-F-004 | `components/room/main/RoomListMap.tsx` |
| `components/room/detail/*` 6개(사진, 편의시설, 예약 박스, 리뷰) | 동작 | 참고(정보 구성) | SY-06-015, SY-06-016, SY-06-020 | 리뷰:23 |
| `components/common/*` 8개(Button, Input, Selector, DatePicker, Counter 등) | 동작 | 폐기(shadcn/ui 기반 새 컴포넌트) | 3절 #14, SY-06-008 | 리뷰:43 |
| `hooks/useDebounce.ts`, `useModal.tsx`, `useValidateMode.ts` | 동작 | 참고(디바운스 400ms 동작만), 나머지 폐기 | SY-06-014 | `hooks/useDebounce.ts` |
| `lib/auth/jwt.ts`, `lib/auth/cookies.ts` | 동작 | 폐기 | 3절 #1, #2 | 리뷰:62, :74 |
| `lib/auth/oauth/google.ts`, `kakao.ts`, `naver.ts` | 동작 | 참고(카카오·네이버 응답 구조 지식), 코드 폐기 | 3절 #4, SY-06-040, 041 | `lib/auth/oauth/naver.ts`, `pages/api/auth/naver/callback.ts:33-39` |
| `pages/api/auth/*` 11개(signup, login, logout, me, refresh, 3개 제공자 시작·콜백) | 동작 | 폐기(Supabase Auth) | 3절 #3, #4 | 리뷰:62-64, :69 |
| `pages/api/rooms/index.ts`, `[id].ts`, `[id]/reviews.ts`, `mine.ts` | 부분(권한 없음) | 폐기(RPC·RLS로 재작성) | SQL 11·12절, SY-06-010 | 리뷰:55-56, :66-68 |
| `pages/api/reservations/index.ts`, `[id].ts` | 부분(권한·겹침 검사 없음) | 폐기(재작성) | SQL `create_reservation`, SY-06-016 | 리뷰:57, :65 |
| `pages/api/wishlists/index.ts`, `[roomId].ts` | 동작 | 폐기(재작성, 개념 유지) | SQL `toggle_wishlist`, SY-06-021 | `pages/api/wishlists/[roomId].ts` |
| `pages/api/files/upload.ts` | 부분(무인증) | 폐기 | 3절 #9, SY-06-012 | 리뷰:58 |
| `pages/api/maps/location.ts`, `places/index.ts`, `places/[placeId].ts` | 동작 | 참고(Geocoding·Places 호출 형식), 공개 키 사용은 폐기 | SY-06-013 | 리뷰:70 |
| `lib/api/*.ts` 6개(axios 인스턴스, Silent Refresh 인터셉터, API 함수) | 동작 | 폐기 | 3절 #11 | `lib/api/index.ts:28-60` |
| `lib/db/mappers.ts`(121줄, snake ↔ camel, 비밀번호 제거) | 동작 | 폐기(생성 타입 `supabase.ts`로 대체) | SY-06-001 | `lib/db/mappers.ts` |
| `lib/data/*.ts` 4개, `data/*.json` 3개 | 미사용 | 폐기 | 3절 #15 | 리뷰:75 |
| `store/index.ts`, `user.ts`, `auth.ts`, `common.ts`, `room.ts`, `searchRoom.ts` | 동작 | 폐기(서버 컴포넌트 + URL 상태) | 3절 #12 | 리뷰:44 |
| `styles/GlobalStyle.ts`, `styles/palette.ts`(Airbnb 계열 빨강) | 동작 | 폐기 | 3절 #13, #19 | `styles/palette.ts:5`, `:8` |
| `public/static/image/home/*.jpg` 3개, `user/default_user_profile_image.jpg` | 동작 | 폐기(출처·라이선스 미확인) | 3절 #18 | 리뷰:79 |
| `public/static/svg/*`(logo, header, register, room 등 아이콘) | 동작 | 폐기(로고는 상표 모방, 아이콘은 lucide 등으로 대체) | 3절 #19 | `public/static/svg/logo/logo.svg` |
| `supabase/migrations/001_initial_schema.sql` | 동작 | 참고(컬럼 구성), 스키마는 폐기 | 05장 2절, 3절 #5~#7 | 리뷰:60 |
| `__tests__/` 3개, `__mocks__/svgMock.tsx`, `jest.config.ts` | 부분 | `mappers.test.ts` 개념만 참고, 나머지 폐기 | 3절 #17, SY-06-030, 037 | 리뷰:77 |
| `pages/sitemap.xml.tsx`, `pages/robots.txt.tsx` | 동작 | 참고(대상 경로), App Router `sitemap.ts`·`robots.ts`로 재작성 | SY-06-023 | `pages/sitemap.xml.tsx` |
| `pages/dashboard.tsx`(355줄), `pages/mypage.tsx`, `pages/host/dashboard.tsx`, `components/host/*` | 동작 | 폐기(게스트 `/trips`, 호스트 `/host`로 재구성) | 3절 #16 | 리뷰:80 |
| `pages/_app.tsx`, `pages/_document.tsx` | 동작 | 폐기(App Router 레이아웃) | 3절 #20 | 리뷰:59, :79 |
| `CLAUDE.md`(원본) | 부분(현행과 불일치) | 참고(미구현 기능 목록만) | 01장 머리말, 3절 #21 | `CLAUDE.md:17`, `:320` |
| `Airbnb_CloneCoding/`, `Airbnb_CloneCoding_fin/`(빈 하위 저장소, `.gitattributes`만) | 비어 있음 | 폐기 | 3절 #22, 5절 | 리뷰:81 |
| `.env.local`, `.gitignore`, `package.json` 의존성 | 설정 | 폐기(새 `.env.example`, 새 스택) | 3절 #8~#11, SY-06-006 | 리뷰:61, :71-72 |
| 숙소 도우미, 자연어 검색, 소개 작성, 리뷰 요약, 호스트 위키, 음성, 3D 히어로 | 원본에 없음 | 신규 | 01장 SY-F-027~036, SY-06-024~036 | `DOC_TEMPLATE.md` 2.2절 |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| 정적 데이터(`lib/staticData.ts`) | `apps/web/src/lib/static-data.ts`로 옮긴다(SY-06-045). 이름 오타 수정: `amentityList` → `amenityList`, `convinienceList` → `convenienceList`, `houstBuildingTypeList` → `houseBuildingTypeList`. 생년월일용 `monthList`·`dayList`·`yearList`(`:4-23`)는 생일을 받지 않으므로 옮기지 않는다(01장 6절). `countryList`는 KR 기본, 나머지는 Phase 2 다국어 때 |
| 등록 13단계 | 단계 순서와 필드는 유지(01장 SY-F-014). 바뀌는 점: 단계마다 서버 저장(draft, `register_step`), 위치 단계는 `listing_private`에 저장, 사진은 Storage 서명 업로드, 체크리스트는 `transition_listing`의 SY010 빠진 항목으로 표시. 라우트 이름 `amentities`는 `amenities`로 |
| 등록 상태 모델(`store/registerRoom.ts`) | 필드 → `listings` 컬럼 매핑: `bedList` → `bed_list`, `publicBedList` → `public_bed_list`, `startDate`/`endDate` → `available_from`/`available_to`, `amentities` → `amenities`. 클라이언트 전역 상태는 두지 않고 폼 상태 + 서버 저장 |
| 검색 바·목록·지도 | 입력 항목은 유지. 바뀌는 점: 지도 경계(남서·북동)로 검색(원본 비대칭 범위 폐기, 리뷰:67), 어린이 0.5명 계산 폐기(인원 = 성인 + 어린이), 날짜는 예약 겹침까지 제외(`search_listings`), 상태는 URL 쿼리 |
| 상세·예약 박스 | 정보 구성 유지. 바뀌는 점: 서버 컴포넌트 렌더(`get_listing_public`), 불가 날짜 달력(`listing_unavailable_ranges`), 가격 계산은 서버 스냅샷과 같은 공식(01장 SY-F-007) |
| 지도 API 호출 형식 | Geocoding·Places 요청 형식은 참고. 서버 전용 키(`GOOGLE_MAPS_SERVER_KEY`)로 Route Handler에서만 호출하고, 지도 제공자는 어댑터 뒤에 둔다(D6) |
| 카카오·네이버 응답 처리 지식 | 코드가 아니라 확인된 사실로만 쓴다(SY-06-040, 041): 카카오 사용자 정보가 `kakao_account` 아래 중첩(`lib/auth/oauth/kakao.ts:36-50`), 네이버는 `state` 필수이고 응답이 `response` 아래 중첩(`pages/api/auth/naver/callback.ts:15-33`), 네이버 이름은 한국어 실명 한 덩어리. 생일 합성(`:35-39`)은 하지 않는다 |
| 원본 스키마 컬럼 | `rooms` 컬럼 구성을 `listings`·`listing_private`로 나눴다(05장 2.1·2.2절). id는 bigint → uuid, 사용자 FK는 `auth.users` |
| 원본 CLAUDE "미구현 기능" | 01장 2절 범위 표의 MVP/Phase 근거로만 쓴다 |

## 3. 폐기 목록과 사유

폐기 22건. 리뷰 5장 작업 #12(의존성 교체), #14(죽은 코드 정리)가 가리킨 항목을 포함한다.

| # | 항목 | 근거 | 사유 |
|---|---|---|---|
| 1 | 자체 JWT 서명·검증 `lib/auth/jwt.ts`, `jsonwebtoken` 8 | 리뷰:71-72 | Supabase Auth가 세션 JWT를 발급한다. 자체 토큰은 RLS의 `auth.uid()`와 연결되지 않는다 |
| 2 | 토큰 쿠키 헬퍼 `lib/auth/cookies.ts` | 리뷰:74 | `Secure` 플래그 없음. 세션 쿠키는 `@supabase/ssr`이 관리한다 |
| 3 | Refresh 회전 `pages/api/auth/refresh.ts`, 로그인·가입·로그아웃·me Route | 리뷰:62, :69 | 저장·폐기 없는 회전(리뷰 #8), 예외 객체 응답(#15). Supabase Auth가 refresh를 처리한다 |
| 4 | OAuth 시작·콜백 6개 Route와 `lib/auth/oauth/*` | 리뷰:63-64, :73 | state 없음(#9), 같은 이메일 충돌(#10), Set-Cookie 덮어쓰기(#19). 인증 단계 B·C가 Supabase 제공자로 대체 |
| 5 | `refresh_tokens` 테이블 | `supabase/migrations/001_initial_schema.sql:29-37` | 참조 0건. Supabase Auth의 세션 테이블을 쓴다 |
| 6 | bigint 자체 `users` 테이블(password 컬럼 포함) | `001_initial_schema.sql:9-26` | 코어 `profiles` + `auth.users`. 비밀번호를 앱 테이블에 두지 않는다 |
| 7 | RLS 비활성 스키마 | `001_initial_schema.sql:115-123` | 리뷰 #6. 새 스키마는 전 테이블 RLS(05장 4절) |
| 8 | service_role 단일 클라이언트 `lib/supabase.ts` | `lib/supabase.ts:7-10` | 사용자 요청은 사용자 세션 클라이언트. service_role은 잡·크론·운영만(CLAUDE.md 2절) |
| 9 | S3 업로드 Route `pages/api/files/upload.ts`, `aws-sdk` v2 | 리뷰:58, :72 | 무인증 public-read(#4), SDK 지원 종료. Supabase Storage `public-assets` |
| 10 | `formidable` 1 | 리뷰:72 | 서버가 파일 본문을 받지 않는다(서명 업로드) |
| 11 | axios 0.21과 Silent Refresh 인터셉터 `lib/api/index.ts`, `lib/api/*.ts` | `lib/api/index.ts:28-60`, 리뷰:72 | 서버 컴포넌트·서버 함수가 직접 호출. 클라이언트 fetch는 `fetch` |
| 12 | Redux Toolkit + next-redux-wrapper, `store/*` 6개 slice, `redux` | 리뷰:44, :78 | SSR → Redux 주입 왕복 불필요. 서버 상태는 서버 컴포넌트, 필터는 URL 쿼리 |
| 13 | styled-components 6, `styles/GlobalStyle.ts`, `styled-reset` | 리뷰:22 | Tailwind CSS v4 + shadcn/ui(02장 1절) |
| 14 | `components/common/*` 8개 | 리뷰:43 | 새 디자인 시스템 컴포넌트(SY-06-008) |
| 15 | JSON 파일 저장소 `lib/data/*`, `data/*.json` | 리뷰:75 | import 0건, 2020년 데이터 |
| 16 | 중복 대시보드 `pages/dashboard.tsx`, `pages/mypage.tsx`, `pages/host/dashboard.tsx` | 리뷰:80 | 게스트 `/trips`·`/wishlist`, 호스트 `/host/*`로 재구성(03장 1절) |
| 17 | 가짜 로그인 테스트 `__tests__/auth/login.test.ts`, jest 설정 | 리뷰:77 | 핸들러를 import하지 않는다. RLS 회귀(SY-06-030), E2E(SY-06-037)로 대체 |
| 18 | 원본 이미지 `public/static/image/home/*.jpg`, `user/default_user_profile_image.jpg` | 리뷰:79 | 출처·라이선스 미확인. 시드·랜딩 이미지는 직접 만든다(05장 10.2절) |
| 19 | Airbnb 모방 시각 요소: `styles/palette.ts`(`#ff5a5f`, `#E51E53`), `public/static/svg/logo/*`, 화면 배치 | `styles/palette.ts:5`, `:8` | 타사 상표·트레이드 드레스 모방 금지(01장 6절, D14) |
| 20 | `pages/_app.tsx`(전역 Cookie), `pages/_document.tsx`, babel 플러그인 2개, `@types/styled-components`, `@types/react-redux` | 리뷰:59, :78 | App Router 레이아웃으로 대체. 전역 쿠키는 리뷰 #5 |
| 21 | 원본 `CLAUDE.md`의 현행과 다른 절(마이그레이션 "예정", "알려진 버그") | `CLAUDE.md:17`, `:320` | 코드와 불일치. 새 지침은 이 폴더 `CLAUDE.md` |
| 22 | 빈 하위 저장소 `Airbnb_CloneCoding/`, `Airbnb_CloneCoding_fin/` | 리뷰:81 | `.gitattributes`만 있다. 상위 저장소에 중첩 저장소로 들어갈 위험 |

## 4. 복사 금지 결함

`docs/products/_platform-core/SECURITY_BASELINE.md` 14장의 일반 항목과 리뷰에서 찾은 원본 고유 결함이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 요청 body의 사용자 id(`hostId`, `userId`)로 소유자 결정 | `pages/api/rooms/index.ts:93`, `:99`, `pages/api/reservations/index.ts:42`, `:67` | 남의 명의로 숙소·예약 생성(리뷰 #2, #3) | `auth.uid()`만. RPC에 사용자 id 인자를 두지 않는다 |
| body 전체를 펼쳐 update(`...req.body`) | `pages/api/rooms/[id].ts:67-73` | mass assignment로 `host_id` 변경(리뷰 #1) | zod 허용 목록 + 컬럼 GRANT |
| 쓰기 Route의 인증·소유권 검사 누락 | `pages/api/rooms/[id].ts:65-112` | 누구나 수정·삭제(리뷰 #1) | RLS + `has_org_role` RPC |
| 서버 프로세스 전역 상태에 요청 쿠키 저장(`axios.defaults.headers.common.Cookie`) | `pages/_app.tsx:27-32` | 동시 요청 간 쿠키 누출(리뷰 #5) | 요청 단위 Supabase 클라이언트(SY-06-004) |
| 무인증 업로드, `ACL: "public-read"`, 원본 파일명을 키에 포함 | `pages/api/files/upload.ts:13-52` | 비용 공격, 악성 파일 호스팅, 파일명 노출(리뷰 #4) | 세션 확인 후 서명 URL, 경로 `<org_id>/listings/<listing_id>/<uuid>.<ext>` |
| 응답 후 다시 상태 코드 쓰기(응답 흐름 누락) | `pages/api/files/upload.ts:43-52` | "headers already sent" | 모든 분기에서 한 번만 return |
| RLS 비활성 + service_role로 모든 요청 처리 | `001_initial_schema.sql:115-123`, `lib/supabase.ts:7-10` | DB 방어 0(리뷰 #6) | 전 테이블 RLS, 사용자 세션 클라이언트 |
| service_role 키를 브라우저 번들·`NEXT_PUBLIC_` 변수에 두기 | `SECURITY_BASELINE.md` 14장 | 전체 데이터 접근 | `src/lib/supabase/admin.ts`는 서버 전용, `server-only` import |
| 예외 객체·DB 오류 메시지를 그대로 응답 | `pages/api/auth/login.ts:51-54`, `pages/api/rooms/index.ts:131-134` | 스키마·제약 이름 노출(리뷰 #15) | `{code, message}` 표준 응답(04장 7절), 내부 오류는 로그만 |
| `NEXT_PUBLIC_` 키를 서버 호출에 사용 | `pages/api/maps/location.ts:12`, `places/index.ts:14` | 리퍼러 제한과 서버 호출 양립 불가, 키 남용(리뷰 #16) | 브라우저 키(리퍼러 제한)와 서버 키(IP·API 제한) 분리 |
| OAuth 인가 요청에 `state` 없음 | `lib/auth/oauth/google.ts:6-16`, `kakao.ts:6-13` | 로그인 CSRF(리뷰 #9) | Supabase Auth 제공자(state·PKCE 내장) |
| 같은 응답에서 `Set-Cookie`를 두 번 설정해 앞의 값 덮어쓰기 | `pages/api/auth/naver/callback.ts:22-25`, `:86` | state 쿠키 미삭제(리뷰 #19) | 쿠키는 배열로 한 번에 설정 |
| 조회 후 삽입으로 중복 방지(DB 제약 없음) | `pages/api/rooms/[id]/reviews.ts:65-75` | 경합 시 중복(리뷰 #12) | 유니크 제약 + `unique_violation` 변환(SQL `create_review`) |
| 날짜 겹침을 코드에서만 검사하거나 검사하지 않음 | `pages/api/reservations/index.ts:51-76` | 이중 예약(리뷰 #11) | 배타 제약 `reservations_no_overlap` |
| 비밀을 저장소에 커밋(`.env.local`), `.gitignore` 누락 | `.gitignore:1` | 비밀 유출(리뷰 #7) | `.gitignore` 보강, 비밀 스캔 CI(SY-06-006) |
| 정확한 주소·좌표를 공개 응답에 포함 | 원본 `rooms` 단일 테이블(`001_initial_schema.sql:56-63`) | 호스트 주소 노출 | `listing_private` 분리, 공개 좌표 소수 2자리 |
| 타사 상표·브랜드 색·로고 복제 | `styles/palette.ts:5`, `:8`, `public/static/svg/logo/*` | 상표 분쟁 | 새 브랜드(D1)와 토큰(SY-06-008) |

## 5. 아카이브 절차

아래는 원본 저장소를 정리하는 **사람이 할 일**이다. 이 문서 묶음은 원본 저장소를 바꾸지 않았다.

| 단계 | 할 일 | 비고 |
|---|---|---|
| 1 | `.gitignore`에 `.next/`, `.env*`, `*.tsbuildinfo`, `.DS_Store`, `.swc/`, `node_modules/` 추가 | 현재 `node_modules` 한 줄뿐(`.gitignore:1`) |
| 2 | `git rm -r --cached node_modules .next .env.local .DS_Store tsconfig.tsbuildinfo` | 커밋 0개 상태라 인덱스만 비우면 된다. 이미 푸시했다면 이력 재작성이 필요하다 |
| 3 | AWS 액세스 키(`ACCESSKEY_ID`, `SECRET_ACCESSKEY_ID`)와 `JWT_SECRET`을 폐기·재발급 | 인덱스에 올라간 적이 있으므로 노출된 것으로 본다 |
| 4 | `Airbnb_CloneCoding/`, `Airbnb_CloneCoding_fin/` 안에 `.git`과 `.gitattributes` 외 파일이 없는지 확인한 뒤 삭제 | 각 원격(`theBestTrade/...`)의 "Initial commit" 하나뿐(리뷰:81) |
| 5 | 원본을 `archive/Airbnb_CloneCoding`로 옮기거나 읽기 전용 표시 | 새 개발은 `D:\WorkSpace\DEV\airbnb\`(develop 안내서) |
| 6 | 원본 `CLAUDE.md` 머리에 "이 저장소는 보관용. 기획은 docs/products/airbnb" 한 줄 추가 | 선택 |

용량 참고(2026-10-20 측정): 원본 폴더 775MB = `node_modules` 508MB + `.next` 135MB + `.git` 129MB(인덱스에 올라간 `node_modules`·`.next` 때문) + `public` 1.1MB + 소스 1MB 미만(TS/TSX 약 11,600줄). 1~2단계만 해도 저장소는 수 MB로 줄고, 재작성으로 소스 크기가 줄어드는 효과는 작다.

## 6. 인증 단계 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키에 역할·사용자 id를 넣는 Mock 로그인 | `AUTH_ROADMAP.md` 2장 | 실제 JWT·RLS를 거치지 않아 권한 버그를 숨긴다 | Stage A: 로컬 시드 계정으로 실제 Supabase 로그인(SY-06-003) |
| `mock-auth.ts`처럼 클라이언트에서 세션을 꾸미는 파일 | `AUTH_ROADMAP.md` 2.5절 | 배포에 섞이면 인증 우회 | `/api/dev/login`은 로컬 Supabase에서만, 운영 빌드 404 |
| 콜백 `next` 파라미터 무검증 리다이렉트 | `AUTH_ROADMAP.md` 3.2절 | 오픈 리다이렉트 | 내부 경로(`/`로 시작, `//` 금지)만 허용(SY-06-039) |
| 원본 자체 JWT·refresh·쿠키 코드 재사용 | `lib/auth/jwt.ts`, `lib/auth/cookies.ts`, `pages/api/auth/refresh.ts` | 폐기 #1~#3. RLS와 연결되지 않는다 | `@supabase/ssr` 세션 |
| `state` 없는 Google·카카오 인가 요청 | `lib/auth/oauth/google.ts:6-16`, `kakao.ts:6-13` | 로그인 CSRF | Supabase 제공자 흐름(C1), 네이버는 D16 경로 |
| 같은 이메일 계정이 있으면 실패하는 OAuth 신규 생성 | `pages/api/auth/google/callback.ts:43-60` | 사용자가 로그인하지 못한다 | Supabase 자동 연결 정책 + `AUTH_ROADMAP.md` 7.3절 계정 연결 화면 |
