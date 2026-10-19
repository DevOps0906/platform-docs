# Airbnb_CloneCoding 코드 리뷰

대상: `D:\WorkSpace\CloneCoding\Airbnb_CloneCoding` (패키지명 `next-bnb`, git 커밋 0개, 2026-10-20 기준). `node_modules`, `.next`, `.swc`는 읽지 않았다.

## 1. 프로젝트 개요

- 한 줄 설명: Airbnb를 따라 만든 숙소 공유 웹앱. 숙소 검색(지도 + 날짜 + 인원), 숙소 상세, 13단계 숙소 등록, 예약, 리뷰, 찜, 이메일·Google·카카오·네이버 로그인을 Next.js 한 프로젝트(Pages Router + API Routes)에 담았다.
- 목적/대상 사용자: 학습용 클론코딩. 사용자는 숙소를 찾는 게스트와 숙소를 올리는 호스트 두 부류다. 역할 구분 컬럼은 없고 "숙소를 올린 사람 = 호스트"다(`supabase/migrations/001_initial_schema.sql:42-44`).

| 구분 | 기술 |
| --- | --- |
| 프론트 | Next.js 14.2.35(Pages Router), React 18.3, TypeScript 5.9, Redux Toolkit 2 + next-redux-wrapper 8, styled-components 6(SWC), react-datepicker 3, axios 0.21 (`package.json:14-45`) |
| 백엔드 | Next.js API Routes 25개(`pages/api/**`). 서버는 Supabase service_role 클라이언트 하나로 모든 테이블에 접근(`lib/supabase.ts:7-10`) |
| DB | Supabase PostgreSQL. 테이블 6개(users, refresh_tokens, rooms, reservations, reviews, wishlists), RLS 전부 비활성(`supabase/migrations/001_initial_schema.sql:118-123`). 레거시 JSON 파일 저장소(`lib/data/*`, `data/*.json`)가 남아 있으나 import 0건 |
| 인프라 | 로컬 개발 상태. 배포 설정·CI 없음. 이미지 업로드는 AWS S3 v2 SDK(`pages/api/files/upload.ts:3`) |
| AI | 없음 |

- 현재 완성도 추정: 약 60%
  - 근거: 검색, 상세, 등록 13단계, 예약 생성·취소, 리뷰 작성, 찜, 4종 로그인, Silent Refresh가 실제 Supabase와 연결되어 동작하는 코드다. 반면 쓰기 API 4개에 인증·소유권 검사가 없어(3장 #1~#4) 그대로는 공개할 수 없다. 결제, 호스트의 예약 승인·거절, 메시지, 날짜 겹침 방지, 테스트가 없다. `CLAUDE.md`는 Next 14 마이그레이션을 "예정"(`CLAUDE.md:17`), 버그 3개를 "수정 예정"(`CLAUDE.md:320`)으로 적었지만 코드에서는 이미 끝났다(`next.config.js`, `pages/api/auth/me.ts`, `pages/api/auth/logout.ts:9`).
- 핵심 기능 목록
  - 홈 검색 바(위치 자동완성, 체크인·체크아웃, 인원) → 숙소 목록 + Google 지도(`pages/room/index.tsx`)
  - 숙소 상세(사진, 편의시설, 리뷰, 평균 별점, 예약 박스)(`pages/room/[id].tsx`, `components/room/detail/*`)
  - 숙소 등록 13단계(건물 → 침실 → 욕실 → 위치 → 지도 → 편의시설 → 공용공간 → 사진 → 설명 → 제목 → 요금 → 날짜 → 체크리스트)(`pages/room/register/*`, `store/registerRoom.ts`)
  - 예약 생성·목록·취소(`pages/api/reservations/*`), 리뷰(`pages/api/rooms/[id]/reviews.ts`), 찜(`pages/api/wishlists/*`)
  - 이메일 가입·로그인(bcrypt), Google·카카오·네이버 OAuth, Access 15분 + Refresh 7일 JWT 쿠키, 401 시 자동 재발급(`lib/auth/*`, `lib/api/index.ts`)
  - 마이페이지·대시보드·호스트 대시보드(`pages/mypage.tsx`, `pages/dashboard.tsx`, `pages/host/dashboard.tsx`), `robots.txt`, `sitemap.xml`

## 2. 구조 분석

| 경로 | 역할 |
| --- | --- |
| `pages/_app.tsx` | Redux 래퍼, 첫 요청마다 `meAPI()`로 로그인 사용자 조회. SSR 때 요청 쿠키를 axios 전역 헤더에 넣음(`:27-32`) |
| `pages/room/index.tsx`, `pages/room/[id].tsx` | 목록·상세. `getServerSideProps`로 API를 다시 호출해 Redux에 넣음 |
| `pages/room/register/*.tsx` (13개) | 등록 단계 페이지. 상태는 `store/registerRoom.ts` 하나에 모음 |
| `pages/api/auth/*` (11개) | signup, login, logout, me, refresh, google/kakao/naver 시작·콜백 |
| `pages/api/rooms/*` | 목록·등록(`index.ts`), 단건 조회·수정·삭제(`[id].ts`), 리뷰(`[id]/reviews.ts`), 내 숙소(`mine.ts`) |
| `pages/api/reservations/*`, `wishlists/*` | 예약 생성·목록·취소, 찜 추가·해제 |
| `pages/api/files/upload.ts` | formidable로 받아 S3에 public-read 업로드 |
| `pages/api/maps/*` | Google Geocoding·Places 프록시 |
| `lib/auth/jwt.ts`, `cookies.ts`, `oauth/*` | 토큰 서명·검증, 쿠키 헬퍼, 3개 OAuth 제공자 URL·토큰 교환 |
| `lib/api/index.ts` | axios 인스턴스 + 401 Silent Refresh 인터셉터 |
| `lib/db/mappers.ts` | DB snake_case ↔ 앱 camelCase 변환, 비밀번호 제거(`storedUserToUser`) |
| `lib/data/*`, `data/*.json` | 2020년 JSON 파일 저장소. 사용처 없음 |
| `components/` (58개) | room/register 21, room/detail 6, room/main 4, home 7, common 8, auth 4, host 2, reservation 2, 헤더 등 |
| `store/` (6개 slice) | user, auth(모달), common(검증 모드), room, searchRoom, registerRoom |
| `supabase/migrations/001_initial_schema.sql` | 테이블 6개, RLS 비활성 |
| `__tests__/` (3개, 179줄) | Button 렌더, mappers, login(핸들러를 import하지 않는 가짜 테스트) |

데이터 흐름: 브라우저는 axios로 같은 앱의 `/api/*`를 부른다. API Route는 쿠키의 `access_token`을 `jsonwebtoken`으로 검증해 `userId`(bigint)를 얻고, service_role 클라이언트로 Supabase 테이블을 직접 읽고 쓴다. DB에는 RLS가 없으므로 권한 검사는 전부 API Route 코드에 있다. 그런데 숙소 등록·수정·삭제, 예약 생성, 파일 업로드 Route는 토큰을 아예 보지 않거나 요청 body의 `hostId`·`userId`를 그대로 쓴다. 페이지는 `getServerSideProps`에서 같은 API를 서버 측 axios로 다시 부르고, 이때 `_app.tsx`가 요청 쿠키를 axios 전역 기본 헤더에 넣는다.

## 3. 발견된 문제점

| # | 심각도 | 분류 | 위치 | 내용 |
| --- | --- | --- | --- | --- |
| 1 | 높음 | 보안 | `pages/api/rooms/[id].ts:65-112` | 숙소 PUT·DELETE에 로그인·소유자 검사가 없다. PUT은 `req.body` 전체를 펼쳐 update(`:67-73`)해 `host_id`를 포함한 모든 컬럼을 누구나 바꿀 수 있다 |
| 2 | 높음 | 보안 | `pages/api/rooms/index.ts:85-129` | 숙소 등록 POST에 인증이 없고 `hostId`를 body에서 받는다(`:93`, `:99`). 남의 이름으로 숙소를 올릴 수 있다 |
| 3 | 높음 | 보안 | `pages/api/reservations/index.ts:39-76` | 예약 생성 POST가 토큰을 보지 않고 body의 `userId`로 예약을 만든다(`:42`, `:67`). 비로그인 상태로 다른 사람 명의의 예약을 만들 수 있다 |
| 4 | 높음 | 보안 | `pages/api/files/upload.ts:13-52` | 업로드에 인증·형식·크기 제한이 없고 `ACL: "public-read"`(`:35`)로 아무 파일이나 공개 버킷에 올라간다. 원본 파일명이 키에 들어가고(`:27`, `:34`), 실패 시 응답 후 다시 405를 쓰려 한다(`:45-52`) |
| 5 | 높음 | 보안 | `pages/_app.tsx:27-32` | SSR 중 `axios.defaults.headers.common.Cookie`에 요청 쿠키를 넣는다. 서버 프로세스 전역 상태라 동시 요청 사이에 다른 사용자의 쿠키가 실려 나갈 수 있고, 지워지지도 않는다 |
| 6 | 높음 | 보안 | `supabase/migrations/001_initial_schema.sql:115-123`, `lib/supabase.ts:7-10` | 모든 테이블 RLS 비활성 + 모든 접근이 service_role. DB 계층의 방어가 0이라 API 코드 한 줄의 실수(#1~#3)가 곧 전체 데이터 변조로 이어진다 |
| 7 | 높음 | 설정 | `.gitignore:1`, git 인덱스 | `.gitignore`가 `node_modules` 한 줄뿐이다. 첫 커밋 전 인덱스에 `.env.local`(AWS 키, JWT 비밀), `node_modules` 4,962개, `.next` 225개가 이미 올라가 있다. 커밋·푸시하면 비밀이 공개 저장소에 남는다 |
| 8 | 중간 | 보안 | `pages/api/auth/refresh.ts:40-43`, `pages/api/auth/logout.ts:9`, `supabase/migrations/001_initial_schema.sql:29-37` | Refresh 토큰을 저장·폐기하지 않는다. `refresh_tokens` 테이블은 참조 0건. 로그아웃해도 탈취된 refresh 토큰은 7일간 유효하다 |
| 9 | 중간 | 보안 | `lib/auth/oauth/google.ts:6-16`, `lib/auth/oauth/kakao.ts:6-13` | Google·카카오 OAuth에 `state`가 없어 로그인 CSRF(공격자 계정으로 로그인시키기)를 막지 못한다. 네이버만 state를 쓴다 |
| 10 | 중간 | 버그 | `pages/api/auth/google/callback.ts:43-60` | 같은 이메일의 이메일 가입 계정이 있으면 `users.email` 유니크 위반으로 신규 생성이 실패하고 `google_signup_failed`로 끝난다. 계정 연결 흐름이 없다 |
| 11 | 중간 | 버그 | `pages/api/reservations/index.ts:51-76` | 날짜 겹침, 숙소 예약 가능 기간(`start_date`~`end_date`), 최대 인원, 체크아웃 > 체크인 검사가 없다. DB 제약도 없어(`001_initial_schema.sql:79-90`) 이중 예약이 그대로 저장된다 |
| 12 | 중간 | 버그 | `pages/api/rooms/[id]/reviews.ts:44-86`, `001_initial_schema.sql:95-102` | 숙박하지 않은 사용자도 리뷰를 쓸 수 있다. 중복 검사는 조회 후 삽입(`:65-75`)이고 DB 유니크 제약이 없어 동시 요청 시 중복된다 |
| 13 | 중간 | 버그 | `pages/api/rooms/index.ts:26-30`, `:34-45` | 위치 범위가 비대칭(-0.5 / +0.05)이라 검색 지점의 남서쪽만 나온다. 날짜 필터는 숙소 운영 기간만 보고 기존 예약은 보지 않으며, 어린이를 0.5명으로 센다 |
| 14 | 중간 | 성능 | `pages/api/rooms/index.ts:62-73`, `pages/api/rooms/[id].ts:38-46` | 목록에서 숙소마다 호스트를 따로 조회(N+1), 상세마다 리뷰 전체를 읽어 평균을 계산한다 |
| 15 | 중간 | 보안 | `pages/api/auth/login.ts:51-54`, `pages/api/rooms/index.ts:131-134` | 예외 객체·DB 오류 메시지를 그대로 응답한다(스키마·제약 이름 노출) |
| 16 | 중간 | 보안 | `pages/api/maps/location.ts:12`, `pages/api/maps/places/index.ts:14` | 서버 지오코딩에 브라우저 공개 키(`NEXT_PUBLIC_GOOGLE_MAP_API_KEY`)를 쓴다. HTTP 리퍼러 제한을 걸면 서버 호출이 막히고, 안 걸면 키가 남용된다 |
| 17 | 중간 | 설정 | `.env.local`, `lib/auth/jwt.ts:10`, `:19`, `lib/supabase.ts:8-9` | `.env.local`에는 `JWT_SECRET`만 있고 코드가 읽는 `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, OAuth 6쌍이 없다. 지금 상태로는 로그인과 DB가 동작하지 않는다 |
| 18 | 중간 | 설정 | `package.json:21-29`, `:69` | axios 0.21(알려진 취약점 다수, 미확인: 정확한 CVE 목록), jsonwebtoken 8, aws-sdk v2(지원 종료), formidable 1. jest 30에 ts-jest 29 |
| 19 | 낮음 | 버그 | `pages/api/auth/naver/callback.ts:22-25`, `:86` | state 쿠키 삭제 헤더를 `setTokenCookies`가 덮어써 state 쿠키가 남는다 |
| 20 | 낮음 | 보안 | `lib/auth/cookies.ts:15-16` | 토큰 쿠키에 `Secure` 플래그가 없다 |
| 21 | 낮음 | 구조 | `lib/data/*`, `data/*.json` | 사용처 없는 JSON 저장소와 2020년 데이터 |
| 22 | 낮음 | 품질 | `pages/room/register/amentities.tsx` 외 13개 파일 | `amentities` 오타가 라우트·컴포넌트·store에 퍼져 있고 DB 컬럼은 `amenities`(`pages/api/rooms/index.ts:119`) |
| 23 | 낮음 | 품질 | `__tests__/auth/login.test.ts` | 로그인 핸들러를 import하지 않고 테스트 안에 쓴 로직만 검증한다. API·통합 테스트 0개 |
| 24 | 낮음 | 설정 | `package.json`, 루트 | 락파일 2개(`package-lock.json`, `yarn.lock`), 미사용 의존성(babel 플러그인 2개, `redux`, `@types/react-redux`, `@types/styled-components`), lint·typecheck 스크립트 없음 |
| 25 | 낮음 | 성능 | `components/**` (`<img>` 27곳), `pages/_document.tsx:23` | `next/image` 미사용, 없는 `favicon.ico` 링크 |
| 26 | 낮음 | 구조 | `pages/dashboard.tsx`(355줄), `pages/mypage.tsx`, `pages/host/dashboard.tsx` | 대시보드 3개가 예약·숙소 목록을 중복 표시 |
| 27 | 낮음 | 설정 | `Airbnb_CloneCoding/`, `Airbnb_CloneCoding_fin/`, `.DS_Store`, `CLAUDE.md:17`, `:320` | 빈 하위 git 저장소 2개(각 `.gitattributes`만), macOS 파일, 현실과 다른 CLAUDE.md 절 |

### 심각도 높음 상세

**#1 숙소 수정·삭제 무인증.** `rooms/[id].ts`의 PUT과 DELETE는 쿠키를 읽지 않는다. `curl -X DELETE /api/rooms/1` 한 줄로 아무 숙소나 지워지고, PUT은 body를 그대로 펼치므로 `{"host_id": 내 id}`로 남의 숙소를 가져올 수 있다. 소유자 확인은 서버가 세션에서 얻은 사용자로 하고, 수정 가능한 컬럼은 허용 목록으로 제한해야 한다. 이 프로젝트는 RLS가 없어(#6) DB도 막아 주지 않는다.

**#2 숙소 등록의 hostId 신뢰.** 등록 API는 `hostId`를 body에서 받아 `host_id`에 넣는다. 비로그인 사용자도 등록할 수 있고 임의의 사용자 id를 호스트로 지정할 수 있다. 호스트 id는 반드시 서버 세션에서 정해야 한다.

**#3 예약 생성의 userId 신뢰.** 예약 목록 GET은 토큰을 검증하지만 같은 파일의 POST는 검증하지 않고 body의 `userId`를 쓴다. 다른 사람 명의로 예약을 쌓아 숙소 달력을 막을 수 있고(#11 이중 예약과 결합), 피해자의 예약 목록에 모르는 예약이 생긴다.

**#4 공개 업로드.** 업로드 Route는 인증 없이 어떤 파일이든 S3에 public-read로 올린다. 스토리지 비용 공격, 악성 파일 호스팅에 쓰일 수 있다. 원본 파일명이 키에 들어가 사용자 PC 파일명이 공개 URL에 노출되고, 응답을 보낸 뒤 405를 다시 쓰는 흐름(`:43-52`)은 "headers already sent" 오류를 만든다.

**#5 SSR 쿠키 전역 공유.** `_app.tsx`의 `getInitialProps`는 서버에서 요청마다 실행되는데, 쿠키를 axios 인스턴스의 전역 기본값에 쓴다. Node 프로세스는 요청을 동시에 처리하므로 A 사용자의 SSR이 B 사용자의 쿠키로 `/api/auth/me`를 부를 수 있다. 쿠키는 요청 단위로 만든 클라이언트나 호출 옵션으로만 넘겨야 한다.

**#6 RLS 비활성 + service_role 단일 경로.** 스키마는 의도적으로 RLS를 끄고 "서버에서만 접근"을 전제로 한다(`001_initial_schema.sql:116`). 이 전제에서는 API Route가 유일한 방어선인데 #1~#4처럼 그 방어선이 비어 있다. 키가 새거나 클라이언트용 키로 잘못 접근해도 막을 장치가 없다.

**#7 비밀이 담긴 인덱스.** 저장소는 커밋이 0개지만 인덱스에 `.env.local`이 올라가 있다. 이대로 첫 커밋을 만들어 원격(`theBestTrade/Airbnb_CloneCoding`)에 푸시하면 AWS 액세스 키와 JWT 비밀이 영구 이력에 남는다. `node_modules`·`.next`가 함께 올라가 `.git`이 약 129MB로 커졌다(코드는 1MB 미만).

## 4. 효율성 개선 제안

- 구조/아키텍처
  - 자체 JWT·refresh·OAuth 콜백(약 600줄)을 Supabase Auth(`@supabase/ssr`)로 바꾸면 #8, #9, #10, #19, #20과 `.env` 불일치(#17)가 함께 사라진다. 권한은 RLS + SECURITY DEFINER RPC로 DB에서 강제한다(#1~#3, #6).
  - Pages Router + Redux + styled-components를 App Router + 서버 컴포넌트 + Tailwind CSS v4 + shadcn/ui로 옮기면 `getServerSideProps` → API 재호출 → Redux 주입의 3단 왕복과 #5가 없어진다.
  - 예약 겹침은 코드가 아니라 DB 배타 제약(`exclude using gist`)으로 막는다(#11).
- 성능
  - 목록은 호스트 이름·대표 사진을 조인한 RPC 한 번으로(#14). 평균 별점은 리뷰 트리거가 숙소 행에 유지한다.
  - 지도 범위 검색은 지도 경계(남서·북동 좌표) 그대로 받고 위도·경도 인덱스를 쓴다(#13).
  - `next/image` + Supabase Storage 변환으로 사진 용량을 줄인다(#25).
- 개발 생산성
  - 죽은 코드(`lib/data`, `data/`), 오타 라우트, 미사용 의존성, 락파일 하나 정리(#21, #22, #24).
  - API 단위 테스트와 RLS 스모크 SQL을 둔다(#23).
- 운영/배포
  - `.gitignore` 보강 후 인덱스에서 `node_modules`, `.next`, `.env.local`을 빼고 AWS 키를 재발급한다(#7).
  - 서버용 Google Maps 키를 분리하고 API 제한을 건다(#16).

## 5. 수정 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 예상 규모 | 권장 모델 | 선정 이유 |
| --- | --- | --- | --- | --- | --- |
| 1 | `.gitignore`에 `.next`, `.env*`, `*.tsbuildinfo`, `.DS_Store`, `.swc` 추가, 인덱스에서 제거(`git rm -r --cached`), AWS·JWT 비밀 재발급 | P0 | S | Sonnet | 설정 작업이지만 비밀 유출을 막는 첫 단계 |
| 2 | 숙소 등록·수정·삭제 Route에 세션 사용자 기반 소유자 검사와 수정 컬럼 허용 목록 적용 | P0 | M | Fable | 권한 로직, 실수 비용이 큼 |
| 3 | 예약 생성 Route를 세션 사용자로 바꾸고 날짜·인원·운영 기간 검증, DB 배타 제약으로 겹침 차단 | P0 | M | Fable | 권한 + 데이터 무결성 |
| 4 | 업로드를 인증 사용자만, 이미지 MIME·10MB 제한, 키를 `<사용자>/<uuid>.<ext>`로, 응답 흐름 정리(또는 Supabase Storage로 교체) | P0 | M | Opus | 명확한 범위의 보안 수정 |
| 5 | `_app.tsx`의 전역 Cookie 헤더 제거, SSR 호출마다 쿠키를 요청 옵션으로 전달 | P0 | S | Opus | 동시성 버그, 2~3파일 |
| 6 | 테이블 RLS 활성화와 정책 작성, 쓰기를 RPC로 이동(또는 Supabase Auth 전환과 함께 재설계) | P0 | L | Fable | 데이터 모델·권한 재설계 |
| 7 | Refresh 토큰 해시 저장·회전·폐기 구현, Google·카카오 state 추가, 같은 이메일 계정 연결 처리 | P1 | M | Fable | 인증 로직 |
| 8 | 리뷰를 완료된 예약 1건당 1개로 제한(예약 FK + 유니크 제약) | P1 | S | Opus | 규칙이 명확한 데이터 제약 |
| 9 | 숙소 목록 검색을 지도 경계 기반 + 예약 겹침 제외 + 호스트 조인 1회 쿼리로 재작성 | P1 | M | Opus | 쿼리·API 개선 |
| 10 | 오류 응답 표준화(사용자 메시지 + 오류 코드, 내부 오류 비노출) | P1 | S | Sonnet | 반복 작업 |
| 11 | 서버 전용 Maps 키 분리, `.env.example` 작성, 코드와 변수명 일치 | P1 | S | Sonnet | 설정 정리 |
| 12 | 오래된 의존성 교체(axios 1.x 또는 fetch, aws-sdk v3, formidable 3, jsonwebtoken 9), 미사용 패키지·락파일 정리 | P1 | M | Opus | 호환성 확인 필요 |
| 13 | 로그인·예약·숙소 API 단위 테스트와 권한 회귀 테스트 작성, 가짜 테스트 교체 | P1 | M | Opus | 테스트 설계 |
| 14 | 죽은 코드·`amentities` 오타·빈 하위 저장소 정리, CLAUDE.md 현행화 | P2 | S | Haiku | 단순 정리(리뷰 템플릿 3등급 기준이면 Sonnet) |
| 15 | `next/image` 전환, favicon 추가, 대시보드 3개를 게스트·호스트 2개로 통합 | P2 | M | Sonnet | UI 정리 |

## 6. 종합 평가

- 강점
  - 숙소 공유 서비스의 핵심 흐름(검색 → 상세 → 예약, 13단계 등록, 리뷰, 찜)이 실제 DB와 끝까지 연결되어 있어 기획의 근거로 쓰기 좋다.
  - 등록 단계 상태(`store/registerRoom.ts`)와 정적 데이터(`lib/staticData.ts`: 건물 유형, 침대 유형, 편의시설)가 잘 정리되어 그대로 이식할 수 있다.
  - 카카오·네이버 응답 구조(중첩 `response`, 생일 합성)를 이미 다뤄 본 코드가 있어 한국 소셜 로그인 요구사항이 확인되어 있다.
- 약점
  - 쓰기 API 다수에 인증이 없고 DB에도 RLS가 없어 공개 배포가 불가능하다(#1~#6).
  - 예약의 핵심 불변식(날짜 겹침 금지, 숙박 후 리뷰)이 코드에도 DB에도 없다(#11, #12).
  - 비밀과 빌드 산출물이 git 인덱스에 올라가 있고, 문서(CLAUDE.md)가 실제 코드와 다르다(#7, #27).
- 모델별 비율(15개 작업): Fable 4개(27%), Opus 6개(40%), Sonnet 4개(27%), Haiku 1개(6%)
- 권장 진행 순서
  - 1단계: #1(비밀 정리) → #2, #3, #4, #5(공개 전 필수 보안)
  - 2단계: #6, #7, #8(권한·인증 재설계) → #9, #13
  - 3단계: #10, #11, #12, #14, #15(정리·품질)
- 주 담당 모델: Fable 5.1. 남은 일의 무게중심이 화면이 아니라 권한·인증·예약 무결성이다. 특히 #6(RLS 재설계)과 #7(인증)은 Supabase Auth로 갈아탈지 여부까지 함께 정해야 하는 구조 결정이고, 실수하면 남의 숙소·예약이 바뀌는 비용이 크다. 기능 구현과 테스트(#9, #12, #13)는 Opus, UI 정리는 Sonnet으로 내리는 구성이 맞다.
