# 05 데이터 모델: Stay(가칭)

정본 SQL: `supabase/monolith/migrations/0002_stay_domain.sql`(아래 "SQL:줄"). 모듈러 조각 `docs/products/_supabase-modular/migrations/2700_stay.sql`은 아직 없고 SY-06-002가 이 파일에서 만든다(8절). 그때부터 정본은 모듈러 조각으로 넘어간다.

원본 스키마(`원본 supabase/migrations/001_initial_schema.sql`)와 달라진 점: bigint 자체 `users` 테이블 대신 Supabase Auth + 코어 `profiles`·`organizations`, `refresh_tokens` 폐기, `rooms` → `listings` + `listing_private` 분리, `availability_blocks` 신규, 예약 겹침 배타 제약, 리뷰를 예약에 묶음, 모든 테이블 RLS.

## 1. 개요와 ERD

```
auth.users / public.profiles / public.organizations (코어, 참조만)
  └─ listings (org_id = 호스트 조직, status, 공개 좌표, 요금, 별점)
       ├─ listing_private (listing_id PK, 정확한 주소·좌표·체크인 안내)   1:1
       ├─ listing_photos (listing_id, storage_path = <org_id>/listings/<listing_id>/...)
       ├─ availability_blocks (listing_id, period daterange)   exclude(listing_id =, period &&)
       ├─ reservations (listing_id, guest_user_id → auth.users, stay daterange, status)
       │      exclude(listing_id =, stay &&) where status in (requested, confirmed)
       │    └─ reviews (reservation_id unique, rating, host_reply)
       └─ wishlists (user_id, listing_id) PK
public.app_entitlements / plans (features 읽기만), rate_limit_buckets, audit_log, Storage public-assets 버킷
```

테넌트 일관성은 복합 FK로 DB가 강제한다: `listing_private(listing_id, org_id)`, `listing_photos(listing_id, org_id)`, `availability_blocks(listing_id, org_id)`, `reservations(listing_id, org_id)`, `reviews(listing_id, org_id)` → `listings(id, org_id)`(SQL:125, :143, :162, :199, :227; 기준 유니크 SQL:101). 예약의 `org_id`는 항상 숙소의 호스트 조직이다.

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 도메인 테이블은 `org_id`(FK cascade)와 `created_at`을 가진다. 예외는 `wishlists`(사용자 개인 행이라 `user_id`만). UPDATE가 있는 테이블은 `updated_at` + `set_updated_at` 트리거(SQL:246-259). `deleted_at`은 `listings`만.

### 2.1 `listings` (SQL:50)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id, org_id | uuid | N | | 호스트 조직 |
| status | text | N | 'draft' | draft, published, unlisted, suspended |
| register_step | smallint | N | 1 | 등록 마법사 단계 1~13(원본 13단계) |
| large_building_type, building_type | text | Y | | 40자 이하. 값 목록은 앱 정적 데이터(원본 `lib/staticData.ts`) |
| room_type | text | N | 'entire' | entire, private, shared |
| is_set_up_for_guest | boolean | N | false | 게스트 전용 공간 여부 |
| max_guests | smallint | N | 1 | 1~16 |
| bedroom_count, bed_count | smallint | N | 1 | 0~50, 0~100 |
| bed_list, public_bed_list | jsonb | N | [] | 침실별 침대 배열(8KB), 공용 공간 침대(4KB) |
| bathroom_count | numeric(3,1) | N | 1 | 0.5 단위 허용 |
| bathroom_type | text | N | 'private' | private, shared |
| country, city, district | text | N | 'KR', '', '' | 공개 표시용 지역 |
| public_lat, public_lng | numeric(5,2) | Y | | 공개 대략 좌표. `listing_private` 트리거가 채운다 |
| amenities, conveniences | text[] | N | {} | 60개, 30개 이하 |
| title / description / house_rules | text | N | '' | 50 / 5,000 / 2,000자 이하. 게시 조건은 RPC가 검사 |
| price_per_night | integer | Y | | 10,000~10,000,000원 |
| cleaning_fee | integer | N | 0 | 0~1,000,000원 |
| min_nights, max_nights | smallint | N | 1, 30 | 1~30, 1~90, min ≤ max |
| check_in_time, check_out_time | time | N | 15:00, 11:00 | |
| instant_book | boolean | N | false | 켜면 예약이 바로 confirmed(D8) |
| available_from, available_to | date | Y | | 운영 기간(원본 `start_date`, `end_date`) |
| cover_photo_path | text | Y | | 대표 사진. 없으면 position 최소 사진 |
| rating_avg, review_count | numeric(2,1), int | Y/N | null, 0 | 리뷰 트리거가 유지 |
| published_at, suspended_reason | | Y | | |
| created_by | uuid | Y | | FK 없음 |
| created_at, updated_at, deleted_at | timestamptz | | | |

### 2.2 `listing_private` (SQL:114)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| listing_id | uuid | N | | PK, 복합 FK |
| org_id | uuid | N | | |
| street_address, detail_address, postcode | text | N | '' | 200, 200, 10자 이하 |
| lat, lng | numeric(9,6) | Y | | 정확한 좌표 |
| checkin_guide | text | N | '' | 현관·주차 안내 3,000자. 확정 게스트만 본다 |
| created_at, updated_at | timestamptz | N | now() | |

### 2.3 `listing_photos` (SQL:132)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id, org_id, listing_id | uuid | N | | 복합 FK |
| storage_path | text | N | | `<org_id>/listings/<listing_id>/%` 체크 + 전역 유니크(SQL:144-145) |
| position | smallint | N | 0 | 0~99 |
| width, height | int | Y | | 변환 잡이 채운다 |
| caption | text | N | '' | 200자 이하. 도우미 근거에 쓰인다 |
| created_at, updated_at | timestamptz | N | now() | |

### 2.4 `availability_blocks` (SQL:152)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id, org_id, listing_id | uuid | N | | |
| start_date, end_date | date | N | | 반열림 [start, end), 365일 이하 |
| period | daterange | N | 생성 컬럼 | 배타 제약 대상(SQL:164) |
| note | text | N | '' | 200자 |
| created_by, created_at | | | | |

### 2.5 `reservations` (SQL:172)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id | uuid | N | | |
| org_id | uuid | N | | 호스트 조직 |
| listing_id | uuid | N | | FK on delete restrict(예약이 있는 숙소는 물리 삭제 불가) |
| guest_user_id | uuid | N | | `auth.users`, on delete restrict(탈퇴 시 익명화 절차, 01장 5절) |
| check_in, check_out | date | N | | check_in < check_out, 90박 이하 |
| stay | daterange | N | 생성 컬럼 | 배타 제약 대상(SQL:201) |
| nights | smallint | N | 생성 컬럼 | |
| adult_count, children_count, infant_count | smallint | N | 1, 0, 0 | 1~16, 0~15, 0~5 |
| status | text | N | 'requested' | 3절 |
| nightly_price, cleaning_fee, service_fee, total_price | integer | N | | 예약 시점 스냅샷. service_fee MVP 0 |
| guest_message, cancel_reason | text | N/Y | | 1,000자, 500자 |
| expires_at | timestamptz | Y | | requested 응답 기한(생성 + 24시간) |
| responded_at, canceled_at, completed_at, created_at, updated_at | timestamptz | | | |

### 2.6 `reviews` (SQL:214)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id, org_id, listing_id | uuid | N | | |
| reservation_id | uuid | N | | 유니크(예약당 1개) |
| guest_user_id | uuid | N | | |
| rating | smallint | N | | 1~5 |
| content | text | N | | 10~1,000자 |
| status | text | N | 'visible' | visible, hidden(운영자) |
| host_reply, host_replied_at | | Y | | 1~500자, 1회 |
| created_at, updated_at | timestamptz | N | now() | |

### 2.7 `wishlists` (SQL:235)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| user_id | uuid | N | | PK 일부 |
| listing_id | uuid | N | | PK 일부, 숙소 삭제 시 cascade(소프트 삭제는 `delete_listing`이 지운다) |
| created_at | timestamptz | N | now() | |

## 3. 상태 전이

| 테이블 | 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|---|
| listings | draft | published | 호스트(owner/admin/member), `transition_listing` | 게시 조건 검사(SY010), `published_at` 최초 기록, 감사 |
| listings | published | unlisted | 호스트 | 검색에서 빠짐. 기존 예약 유지 |
| listings | unlisted | published | 호스트 | 게시 조건 재검사 |
| listings | draft/published/unlisted | suspended | 운영자(service_role) `suspend_listing` | 사유 기록. 호스트 편집 불가(RLS) |
| listings | suspended | unlisted | 운영자 | 사유 지움 |
| listings | 임의(삭제되지 않음) | 소프트 삭제(`deleted_at`) | owner/admin `delete_listing` | 남은 활성 예약 있으면 SY007. 찜 삭제 |
| reservations | requested | confirmed / declined | 호스트 `respond_reservation`(만료 전) | `responded_at`, 감사 |
| reservations | requested | expired | 정리 RPC(매시간) | |
| reservations | requested | canceled_by_guest | 게스트 | 게스트 개인 조직에 감사 |
| reservations | confirmed | canceled_by_guest | 게스트(체크인 전날까지) | |
| reservations | confirmed | canceled_by_host | 호스트 owner/admin(체크인 전, 사유 필수) | |
| reservations | confirmed | completed | 정리 RPC(체크아웃 ≤ 오늘) | 리뷰 작성 가능(14일) |
| reviews | visible | hidden | 운영자(service_role 직접 UPDATE, Phase 2 화면) | 평균 별점 재계산 트리거 |

전이는 RPC 안의 허용 쌍 검사로 강제한다(SQL:671, :817, :845, :988). 테이블 상태 컬럼에는 사용자 UPDATE 권한이 없다(컬럼 GRANT에 `status` 없음, SQL:323-329).

## 4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| listings | 조직 멤버 + `stay` 엔타이틀먼트 + 미삭제 | RPC `create_listing` | 멤버(owner/admin/member), 미삭제, suspended 아님 | RPC(소프트) | select, update(비상태 컬럼 30개) |
| listing_private | 조직 멤버 또는 confirmed/completed 예약 게스트 | `create_listing`이 같이 만듦 | 멤버 | 숙소 cascade | select, update(주소·좌표·안내) |
| listing_photos | 조직 멤버 | 멤버 + 숙소 미삭제·미정지 + 30장 미만 + 경로 체크 | 멤버(position, caption) | 멤버 | select, insert(7컬럼), update(2컬럼), delete |
| availability_blocks | 조직 멤버 | RPC `block_dates` | 없음 | RPC `unblock_dates` | select |
| reservations | 게스트 본인 또는 호스트 조직 멤버 | RPC `create_reservation` | RPC만 | 없음 | select |
| reviews | 작성자 본인 또는 호스트 조직 멤버 | RPC `create_review` | RPC `reply_review` | 없음 | select |
| wishlists | 본인 | RPC `toggle_wishlist` | 없음 | 본인 | select, delete |

anon은 모든 테이블 권한이 없다. 비로그인 화면은 공개 RPC 4개(`search_listings`, `get_listing_public`, `listing_unavailable_ranges`, `listing_reviews_public`)만 쓴다(SQL:500-620, EXECUTE는 SQL 끝 GRANT). 공개 RPC는 published·미삭제 숙소만 돌려주고 `listing_private` 컬럼과 게스트 id를 넣지 않는다.

쓰기 정책을 준 테이블(listings, listing_private, listing_photos)의 근거(`DB_CONVENTIONS.md` 8장 조건): 상태·소유 컬럼은 GRANT에서 빠져 있고, 조직 경계는 복합 FK와 `has_org_role`이 함께 막으며, 사진 경로는 CHECK 제약이 조직·숙소 접두사를 강제한다(SQL:144). Storage 객체 자체는 코어 `public_assets_*` 정책(폴더 = org_id)이 막는다.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `listings_search_geo_idx (public_lat, public_lng) where published` | 지도 경계 검색 |
| `listings_search_city_idx (city, price_per_night) where published` | 도시 + 가격 검색 |
| `listings_org_idx (org_id, created_at desc)` | 호스트 숙소 목록 |
| `listing_photos_listing_idx (listing_id, position)` | 상세 사진, 카드 대표 사진 |
| `reservations_no_overlap` (GiST, 부분) | 겹침 판정 + `stay_range_is_free` |
| `availability_blocks_no_overlap` (GiST) | 차단 겹침 판정 |
| `reservations_guest_idx (guest_user_id, check_in desc)` | 내 여행 |
| `reservations_org_status_idx (org_id, status, check_in)` | 호스트 예약함 탭 |
| `reservations_expiry_idx (expires_at) where requested` | 정리 RPC |
| `reviews_listing_idx (listing_id, created_at desc) where visible` | 공개 리뷰 목록 |

검색 카드는 `stay_listing_card` 한 함수가 대표 사진·호스트 이름을 하위 조회로 붙인다. 목록 20개 기준 하위 조회 40회지만 같은 쿼리 안이라 왕복은 1회다(원본 N+1 HTTP 왕복과 다름, 리뷰:68). 숙소가 1만 개를 넘으면 `cover_photo_path` 필수화와 PostGIS 전환을 검토한다(제안, 06장 6절 R-3).

## 6. 코어 참조

| 코어 객체 | 용도 |
|---|---|
| `organizations`, `profiles` | 호스트 조직, 표시 이름·사진(공개 RPC가 owner의 profile을 읽음) |
| `app_entitlements`, `plans` | `stay_plan_feature_int`가 features 읽기(읽기만) |
| `is_org_member`, `has_org_role`, `has_entitlement`, `personal_org_id` | RLS와 RPC 판정 |
| `is_service_caller` | 호스트 RPC의 service 경로, service 전용 RPC 판정 |
| `rate_limit_hit` | 숙소 생성·예약·리뷰·찜 레이트 리밋(`stay_rate_limit`, SQL:444) |
| `write_audit` | 숙소·예약 감사. 게스트 행동은 게스트 개인 조직에 기록(write_audit은 조직 멤버만 허용) |
| `set_updated_at` | 트리거 |
| Storage `public-assets` 버킷과 정책 | 숙소 사진(공개 읽기, 쓰기는 폴더 = org_id 멤버) |
| `jobs`, `enqueue_job` | 사진 변환, 숙소 색인, 위키 ingest, 리뷰 요약, 알림 메일(02장 4절) |

`public.*` 코어 테이블 ALTER 없음. 코어 테이블 쓰기 없음(감사·레이트 리밋은 코어 함수 경유). seed의 `ai_routing_settings` INSERT와 `plans` 행은 이 제품(app `stay`) 자신의 데이터다.

AI·음성 코어 객체(0001 SECTION 11, 12):

| 코어 객체 | stay 용도 | 쓰는 쪽 |
|---|---|---|
| `wallets`, `credit_ledger`, `consume_credits`, `refund_credits` | AI·음성 선차감과 정산, 가입 크레딧 100 | Next.js 서버(service_role) |
| `ai_conversations`, `ai_messages` | 숙소 도우미 대화(본인만 SELECT) | Next.js, FastAPI |
| `ai_runs`, `ai_run_steps` | `stay.listing_assist`, `stay.review_summary` 실행 기록 | FastAPI |
| `ai_usage` | 호출별 사용량, 정산 | FastAPI, Next.js 음성 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 11행(seed), 경로 결정 | seed, FastAPI |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의 | 온보딩·설정 |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 숙소별 컬렉션 `listing-<listing_id>`(공개 정보), 호스트 위키 원문 | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 호스트 위키(slug 접두사 `listings/<listing_id>/`) | FastAPI(쓰기), Next.js(읽기) |
| `voice_sessions`, `voice_jobs` | 도우미 음성 대화 | Next.js |

제품 AI 테이블을 만들지 않은 이유(`AI_ARCHITECTURE.md:165` "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 리뷰 요약 저장 표(`review_summaries`) | 상세마다 요약 표시 | `ai_runs`(graph `stay.review_summary`, `input->>'listing_id'`)의 최신 성공 행 `output`. 하루 1회 재생성 |
| 소개 초안 표 | 호스트가 초안을 다시 보기 | `ai_runs.output`(최근 10회). 고른 안만 `listings`에 저장 |
| 숙소-컬렉션 연결 표 | 어느 컬렉션이 어느 숙소 것인가 | 이름 규칙 `listing-<listing_id>`(`ai_collections` 유니크) |
| 음성 고지 확인 표 | 고지 증빙 | `audit_log`의 `voice.notice_ack` |

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

리뷰 높음 7건 중 #1, #2, #3, #4, #6은 여기, #5, #7은 02장 6절이다.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Airbnb_CloneCoding.md` 3장 #1 | `docs/reviews/Airbnb_CloneCoding.md:55`, `:85` | 숙소 PUT·DELETE 무인증, body 전체로 update(mass assignment) | (1) 숙소 쓰기는 RLS `listings_update`(조직 멤버 + 엔타이틀먼트, SQL:334)와 컬럼 GRANT(비상태 30개, SQL:323-329)로만 가능하다. `org_id`, `status`, `rating_avg`, `deleted_at`은 사용자 GRANT에 없어 body에 넣어도 42501. (2) 삭제는 `delete_listing` RPC(owner/admin, 활성 예약 검사, SQL:723). (3) Route Handler는 zod 허용 목록으로 필드를 거른다(04장 2절). (4) 스모크: outsider UPDATE 0행, 호스트 status 직접 변경 42501 | listings, SY-06-002, SY-06-010, SY-06-030 |
| 같은 문서 3장 #2 | `docs/reviews/Airbnb_CloneCoding.md:56`, `:87` | 숙소 등록 무인증, body의 `hostId` 신뢰 | `create_listing`은 인자로 사용자 id를 받지 않는다. 조직은 `personal_org_id()` 또는 호출자가 멤버인 조직만(SQL:626-653), 레이트 리밋 20/시간, 플랜 `max_listings`. INSERT 권한은 테이블에 없다 | create_listing, SY-06-010 |
| 같은 문서 3장 #3 | `docs/reviews/Airbnb_CloneCoding.md:57`, `:89` | 예약 생성 무인증, body의 `userId` 신뢰 | (1) `create_reservation`의 게스트는 `auth.uid()`뿐(SQL:914-972). anon EXECUTE 없음. (2) 날짜·박수·인원·운영 기간·자기 숙소 검사. (3) 겹침은 배타 제약 `reservations_no_overlap`(SQL:201)이 최종 판정하고 `exclusion_violation`을 SY003으로 바꾼다. (4) 사용자당 10건/시간. (5) 스모크: anon 호출 42501, 겹침 SY003, 직접 INSERT 42501 | reservations, SY-06-016, SY-06-030 |
| 같은 문서 3장 #4 | `docs/reviews/Airbnb_CloneCoding.md:58`, `:91` | 무인증 public-read 업로드, 원본 파일명 노출 | (1) S3 업로드 Route를 버리고 Supabase Storage `public-assets` 버킷을 쓴다. 버킷이 이미지 MIME 5종·10MB로 제한하고(코어 SECTION 8), 쓰기 정책은 폴더 첫 단계 = 호출자 조직(`storage_org_id`). (2) 업로드 URL은 Route Handler가 세션 확인 후 `<org_id>/listings/<listing_id>/<uuid>.<ext>`로만 서명 발급(04장 2절). 원본 파일명을 쓰지 않는다. (3) `listing_photos.storage_path` CHECK가 같은 접두사를 DB에서 다시 강제(SQL:144). (4) 숙소당 30장 상한(RLS) | listing_photos, SY-06-012 |
| 같은 문서 3장 #6 | `docs/reviews/Airbnb_CloneCoding.md:60`, `:95` | RLS 비활성 + service_role 단일 경로 | (1) 도메인 7개 테이블 모두 RLS 활성, anon 권한 0, authenticated는 SELECT + 제한된 컬럼 쓰기만(SQL:302-401). (2) 앱의 사용자 요청은 사용자 세션 클라이언트(`@supabase/ssr`)로 DB를 부른다. service_role은 서버 전용 작업(정리, 잡, 정지)에만(02장 2절, CLAUDE.md 2절). (3) 정확한 주소를 `listing_private`로 분리해 RLS가 공개 범위를 결정. (4) PGlite 스모크 49항목(9절)과 CI의 RLS 회귀 테스트(SY-06-030) | 9절, SY-06-002, SY-06-030 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러(예정) | 모놀리스(현재) |
|---|---|---|
| 스키마 | `stay` | `public`(D12) |
| 파일 | `_supabase-modular/migrations/2700_stay.sql`(SY-06-002가 생성) | `0001_core_lite.sql` + `0002_stay_domain.sql` + `seed.sql` |
| 정본 | 조각이 생기면 조각 | 지금은 `0002_stay_domain.sql`. 다른 제품과 순서가 반대인 이유: 원본이 단독 Supabase였고 처음 등록하는 제품이라 모놀리스부터 검증했다 |
| 머리 | 스키마 생성, USAGE, `core.apps` 등록 | 생략. apps/plans는 seed |
| 접두사 | `core.`, `stay.` | 모두 `public.` |
| 함수 이름 | 같음(`stay_` 접두사 헬퍼 포함) | 같음 |
| 코어 라이트에서 지운 절 | 해당 없음 | SECTION 6-A(OAuth state: Supabase Auth가 처리), 6-B(보관할 자격증명 없음), 9(affiliate). 남김: 3(Toss, Phase 2), 4(크레딧), 6-C(레이트 리밋), 7(잡), 8(Storage), 11(AI), 12(음성) |
| 확장 | btree_gist는 core 0000에 추가 요청(06장 6절 R-2) | 0002 머리에서 `create extension if not exists btree_gist` |
| AI 라우팅 기본값 | 조각 마지막 절(`@@modular-only`) | `seed.sql`(11행 + 체인 검사) |

## 9. 마이그레이션 파일

| 파일 | 내용 | 검증 |
|---|---|---|
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 라이트 사본(6-A, 6-B, 9 제거) | PGlite 0.3.15 적용 OK(2026-10-20) |
| `supabase/monolith/migrations/0002_stay_domain.sql` | 테이블 7, 트리거 함수 2, 내부 헬퍼 5, 공개 RPC 4, 호스트 RPC 9, 게스트 RPC 6, 정리 RPC 1, RLS, EXECUTE 정리 | PGlite 적용 OK, 2회 반복 적용 OK |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 2개, AI 라우팅 11행 + 체인 검사 | 적용 OK, 반복 적용 OK, 라우팅 11행 |
| `supabase/monolith/tests/rls_smoke.mjs` | 가입 → 숙소 생성·게시 → 검색 → 예약 요청·겹침·승인 → 주소 공개 범위 → 차단 → 완료 → 리뷰 → 찜 → 삭제까지 49항목 | 49/49 통과(2026-10-20, `docs/products/_tools-sqlcheck`의 `node_modules` 사용) |
| 다음 번호 | `0003_stay_*.sql`(숙박업 신고번호 컬럼 D7, Phase 2 결제 연결 컬럼) | - |

스모크가 확인한 대표 항목:

| 검사 | 결과 |
|---|---|
| anon `select * from listings` | 42501 |
| anon 검색·상세 | 1건, 응답에 상세주소 문자열 없음 |
| 겹치는 예약(다른 사용자) | SY003 |
| 자기 숙소 예약 / 인원 초과 / 과거 날짜 | SY006 / SY004 / SY002 |
| requested 게스트의 `listing_private` | 0행. 승인 후 1행 |
| 완료 전 리뷰 / 중복 리뷰 / 남의 예약 리뷰 | SY008 / SY009 / SY001 |
| authenticated의 `stay_run_maintenance` | 42501 |
| 평균 별점 트리거 | 4.0, 1건 |

## 10. 개발용 시드 페르소나 (Stage A)

스키마 변경 없음. 시드는 `scripts/dev/seed-users.mjs --app stay`(공통 페르소나, `AUTH_ROADMAP.md` 2.2, 2.3절) 뒤에 제품 훅 `scripts/dev/seed-users.stay.mjs`가 아래 행을 만든다. 로컬 Supabase에서만 실행하고 모든 쓰기는 실제 사용자 세션의 RPC·RLS 경로로 한다.

### 10.1 공통 페르소나 (이 제품 적용)

| 키 | 이메일 | 기대 결과(stay) |
|---|---|---|
| `owner` | `owner@dev.test` | 개인 조직 owner, `entitled=true`, `plan_code='free'`, 가입 크레딧 100 |
| `admin`, `member`, `viewer` | `admin@dev.test` 등 | owner 조직의 역할. viewer는 숙소 수정 0행, `create_listing` 42501 |
| `outsider` | `outsider@dev.test` | 다른 조직. owner 조직의 숙소·예약 0행 |
| `no_app` | `no_app@dev.test` | 모놀리스는 앱 행이 1개라 가입 트리거가 바로 부트스트랩(`entitled=true`) |
| `suspended` | `suspended@dev.test` | 모든 게스트·호스트 RPC 42501(`stay_require_active_user`) |
| `ops` | `ops@dev.test` | 운영 스크립트 실행 계정(Phase 2 운영 화면) |
| `pending` | 만들지 않음 | open 앱이라 승인 대기 없음 |

### 10.2 제품 훅 행

| 키 | 이메일 | 만드는 방법(RPC/RLS) | 기대 결과 | 쓰임 |
|---|---|---|---|---|
| `host` | `host@dev.test` | `create_listing` 2회 → RLS UPDATE로 필드·주소 입력 → 사진 5장 INSERT(로컬 Storage 더미 이미지) → 숙소 A `transition_listing('published')`, 숙소 B는 draft. 숙소 A에 `block_dates`(오늘+40~42일) | 숙소 A 검색 1건, 숙소 B 검색 0건 | 호스트 화면, 승인·취소 E2E |
| `guest` | `guest@dev.test` | `create_reservation`(숙소 A, 오늘+10~13일, 2명) → host가 `respond_reservation(true)`. 두 번째 예약(오늘+20~21일) requested로 둠 | 내 여행에 확정 1건(주소 보임), 요청 1건(주소 없음) | 게스트 화면, 리뷰 E2E(정리 RPC로 completed 전환은 테스트가 날짜를 옮겨 실행) |

| 항목 | 내용 |
|---|---|
| 멱등 | 같은 이메일이 있으면 건너뛴다. 숙소는 제목 `[DEV] 숙소 A`, `[DEV] 숙소 B`로 찾는다. 예약은 같은 기간이 있으면 만들지 않는다(배타 제약이 어차피 막는다) |
| 이미지 | 저장소에 넣는 더미 이미지는 직접 만든 단색·패턴 이미지(원본 `public/static/image/*.jpg` 사용 금지, 07장 4절) |
| 국외 이전 | 기본 미동의(오픈소스 경로). 상용 경로 테스트는 해당 세션에서 `set_ai_cross_border_ack` 호출 |

## 11. 호스트 유형 (D18)

| 항목 | 설계(제안) |
|---|---|
| 위치 | `stay.host_profiles`(조직당 1행) 신규 제안. 코어 `profiles`·`organizations`는 수정하지 않고 참조만 한다 |
| 컬럼 | `org_id`, `host_type`('individual'\|'business'), `display_name`, `business_no`, `business_name`, `representative`, `tax_email`, `lodging_kind`, `license_no`, `verify_status`(none/pending/approved/rejected) |
| RLS | 본인 조직 owner만 읽기·쓰기. 게스트에게는 공개하지 않고 표시 이름만 공개 RPC로 노출 |
| 증빙 파일 | 비공개 버킷, 운영자만 열람. 게스트 경로와 분리 |
| 금지 | 사업자번호·증빙을 로그·AI 경로에 넣지 않는다 |
| 미확인 | 보관 기간, 법정 보존 의무 |
