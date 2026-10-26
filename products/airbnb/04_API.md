# 04 API: Stay(가칭)

SQL = `supabase/monolith/migrations/0002_stay_domain.sql`. 모듈러 조각이 생기면(SY-06-002) 같은 함수가 `stay.` 스키마에 있다.

원본 API Routes 25개(`docs/reviews/Airbnb_CloneCoding.md:35-39`)는 이식하지 않는다. 새 경계는 서버 컴포넌트·Server Action(도메인 서버 계층 `src/server/<도메인>/`)과 꼭 필요한 Route Handler, 그리고 DB의 SECURITY DEFINER RPC다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 사용자 세션 | 로그인 필요 경로는 `requireSession('stay')`. DB 호출은 요청 단위 사용자 세션 클라이언트(`src/lib/supabase/server.ts`)로만 하며 RLS와 RPC 내부 `auth.uid()`가 권한을 판정한다. service_role(`admin.ts`)은 잡 enqueue·크론·운영 스크립트만(02장 2절) |
| 비로그인 | 공개 RPC 4개만 anon 키로 부른다(`search_listings`, `get_listing_public`, `listing_unavailable_ranges`, `listing_reviews_public`). 테이블 직접 조회 없음 |
| 사용자 id | 입력에 사용자 id·호스트 id·조직 id(본인 조직 지정 외)를 받지 않는다. 받더라도 무시한다(리뷰:56-57 #2, #3) |
| 입력 검증 | zod 허용 목록. 정의되지 않은 필드는 버린다(`.strip()`). 숙소 수정은 05장 4절 컬럼 GRANT 목록과 같은 필드만 |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }`. `message`는 사용자 문구. 예외 객체·DB 오류 원문·제약 이름을 응답하지 않는다(리뷰:69 #15). 서버 로그에는 요청 id와 SQLSTATE만 |
| 오류 매핑 | RPC의 SQLSTATE(SY###, 42501, CR001 등)를 7절 표로 HTTP 상태와 문구로 바꾼다(`src/lib/http/errors.ts`) |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`, `/api/host/wiki/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler가 부른다(`SECURITY_BASELINE.md:299`) |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT 발급: `iss=stay`, `aud=platform-ai:stay`, `org`, `app=stay`, `sub`(사용자 id), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 세션에서만(`AI_ARCHITECTURE.md:33-42`) |
| 크레딧 | 2.1절 경로만 선차감·정산. 2절 경로는 0 |
| 멱등 | 예약은 배타 제약이 중복을 막아 재시도해도 두 번째는 SY003이다. 찜은 토글이라 클라이언트가 응답 상태로 화면을 맞춘다. AI는 `conv:<id>:turn:<n>`, `run:<ai_run_id>`, `voice:<voice_job_id>` |
| 캐시 | 검색 Route Handler는 `Cache-Control: no-store`. 상세 RSC는 `revalidate` 60초(제안). 로그인 화면·`/host/*`·`/trips/*`는 `noindex` |
| 레이트 리밋 | DB: RPC 내부(01장 5절). Route Handler: `stay:search:<ip_hmac>` 120/분, `stay:upload:<user>` 60/시간, `stay:geocode:<user>` 60/분(제안). 본문 상한 16KB(업로드 서명 요청 제외) |
| IP | `x-forwarded-for` 첫 값을 `HMAC-SHA256(STAY_IP_HMAC_SECRET, yyyy-mm-dd + ip)`로 바꿔 레이트 리밋 키에만. 원문 IP는 저장·로그하지 않는다 |

## 2. Route Handler

"SA"는 Server Action(같은 원칙, HTTP 경로 대신 함수 이름), "RSC"는 서버 컴포넌트 렌더다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| GET `/api/search` | 누구나 | `?sw_lat&sw_lng&ne_lat&ne_lng`(4개 모두 또는 없음, 숫자), `city?: string<=60`, `check_in?`, `check_out?`(ISO 날짜, 둘 다 또는 없음), `guests: int 1..16 = 1`, `min_price?`, `max_price?`(int), `room_type?: entire\|private\|shared`, `limit: 1..50 = 20`, `offset: >=0` | `{ items: ListingCard[], next_offset }` | 0 | `search_listings` | 400 SY002, 429 SY429 |
| RSC `/listings/[id]` | 누구나(비공개는 호스트 조직만) | `id: uuid` | 상세 HTML(메타·OG) | 0 | `get_listing_public`, `listing_reviews_public`(첫 10건), 리뷰 요약은 `ai_runs` 최신 성공 행(서버, service_role 읽기 전용) | 404 SY001 |
| GET `/api/listings/[id]/unavailable` | 누구나 | `?from&to`(400일 이하) | `{ ranges: [{start_date, end_date}] }` | 0 | `listing_unavailable_ranges` | 400 SY002, 404 SY001 |
| GET `/api/listings/[id]/reviews` | 누구나 | `?limit 1..50&offset` | `{ items }` | 0 | `listing_reviews_public` | - |
| SA `createListingDraft` | 로그인, `max_listings` | `{ org_id?: uuid }`(생략 시 개인 조직) | `{ listing_id }` | 0 | `create_listing` | 403 42501, 403 SY012, 429 SY429 |
| SA `saveListingStep` | 호스트(owner/admin/member) | `{ listing_id, step: 1..13, fields }`. `fields`는 단계별 zod(05장 4절 GRANT 컬럼 30개 안에서만), 위치 단계는 `listing_private` 필드(주소 3개, lat/lng, checkin_guide) | `{ listing, missing: string[] }` | 0 | RLS UPDATE `listings`, `listing_private` | 404(0행 = 권한 없음 포함), 400 검증 |
| SA `transitionListing` | 호스트 | `{ listing_id, to: published\|unlisted }` | `{ status }` | 0 | `transition_listing` | 422 SY010(`missing` 목록), 409 SY007, 403 42501 |
| SA `deleteListing` | owner/admin | `{ listing_id }` | 204 | 0 | `delete_listing` | 409 SY007, 403 42501 |
| POST `/api/uploads/listing-photo` | 호스트, `photos_per_listing` | `{ listing_id: uuid, content_type: image/jpeg\|image/png\|image/webp, size: int <= 10485760 }` | `{ upload_url, path }`. path = `<org_id>/listings/<listing_id>/<uuid>.<ext>`(원본 파일명 미사용) | 0 | 서버가 사용자 세션으로 숙소 조회(RLS)로 조직 확인 → Storage `createSignedUploadUrl` | 401, 403(다른 조직), 409(30장), 413, 415, 429 |
| SA `confirmListingPhoto` | 호스트 | `{ listing_id, path, position?: 0..99, caption?: <=200 }` | `{ photo_id }` | 0 | RLS INSERT `listing_photos`, `enqueue_job('stay.photo.process')` | 403 23514(경로), 409(30장) |
| SA `reorderPhotos`, `deletePhoto`, `setCoverPhoto` | 호스트 | `{ listing_id, photo_ids[] }` / `{ photo_id }` / `{ listing_id, path }` | 204 | 0 | RLS UPDATE/DELETE `listing_photos`, UPDATE `listings.cover_photo_path` | 404 |
| GET `/api/maps/geocode` | 로그인 | `?q: string 2..200` | `{ results: [{address, lat, lng, city, district, postcode}] }` | 0 | 없음(Google Geocoding, 서버 키) | 429, 502 |
| GET `/api/maps/places` | 로그인(검색 바 자동완성은 누구나, IP 한도) | `?input: string 1..100&session_token` | `{ predictions: [{place_id, text}] }` | 0 | 없음(Places Autocomplete) | 429, 502 |
| GET `/api/maps/places/[placeId]` | 누구나(IP 한도) | `placeId` | `{ lat, lng, city }` | 0 | 없음 | 404, 429 |
| SA `requestReservation` | 로그인 | `{ listing_id, check_in, check_out, adults: 1..16, children: 0..15, infants: 0..5, message?: <=1000 }` | `{ reservation_id, status, total_price }` | 0 | `create_reservation` | 400 SY002/SY004/SY005, 404 SY001, 409 SY003, 403 SY006, 429 SY429, 403 42501(정지) |
| SA `respondReservation` | 호스트(owner/admin/member) | `{ reservation_id, accept: boolean }` | `{ status }` | 0 | `respond_reservation`, `enqueue_job('stay.notify.email')` | 409 SY007, 403 42501 |
| SA `hostCancelReservation` | owner/admin | `{ reservation_id, reason: string 5..500 }` | `{ status }` | 0 | `host_cancel_reservation`, 메일 enqueue | 409 SY007, 400 22023, 403 42501 |
| SA `guestCancelReservation` | 게스트 본인 | `{ reservation_id, reason?: <=500 }` | `{ status }` | 0 | `guest_cancel_reservation`, 메일 enqueue | 404 SY001, 409 SY007 |
| RSC `/trips` | 로그인 | - | 내 여행 화면 | 0 | `my_trips` | - |
| RSC `/host/reservations` | 호스트 조직 멤버 | `?status` | 예약함 화면 | 0 | `host_reservations` | 403 42501 |
| SA `blockDates` / `unblockDates` | 호스트 | `{ listing_id, start, end, note?: <=200 }` / `{ block_id }` | `{ block_id }` / 204 | 0 | `block_dates` / `unblock_dates` | 400 SY002, 409 SY003, 404 SY001 |
| SA `submitReview` | 게스트(완료 예약) | `{ reservation_id, rating: int 1..5, content: string 10..1000 }` | `{ review_id }` | 0 | `create_review` | 404 SY001, 403 SY008, 409 SY009, 429 |
| SA `replyReview` | 호스트 | `{ review_id, reply: string 1..500 }` | `{ review_id }` | 0 | `reply_review` | 409 SY009, 403 42501 |
| SA `toggleWishlist` | 로그인 | `{ listing_id }` | `{ wished: boolean }` | 0 | `toggle_wishlist` | 404 SY001, 429 |
| RSC `/wishlist` | 로그인 | - | 찜 화면 | 0 | `my_wishlist` | - |
| GET `/sitemap.xml`, `/robots.txt` | 누구나 | - | XML / 텍스트 | 0 | `search_listings` 대신 service_role 읽기 전용 쿼리(published, 미삭제 id·updated_at) | - |

### 2.1 AI·음성 Route Handler

서명 토큰 scope와 호출 대상은 `AI_ARCHITECTURE.md:132-160`, `VOICE_ARCHITECTURE.md:5-20`을 따른다. 크레딧은 01장 4.2절 선차감 예상치이고 끝나면 실제 사용량으로 정산한다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| POST `/api/onboarding/ai-consent` | 로그인(개인 조직 owner) | `{ granted: boolean, notice_version }` | 204 | 0 | 없음 | `set_ai_cross_border_ack`, 감사 `ai.consent` | 409 `CONSENT_VERSION_MISMATCH` |
| POST `/api/ai/conversations` | 로그인, `ai_chat` | `{ listing_id: uuid, channel: text\|voice }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). 숙소는 published여야 함(`get_listing_public`) | 404 SY001, 403 `AI001` |
| POST `/api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message: 1..500 }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 1(오픈소스)·2(상용), 정산 | Dify Chat API(입력 `platform_conversation_id`, `listing_id`). 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `feat=chat`) | `rate_limit_hit`(분·일), `consume_credits(conv:<id>:turn:<n>)`, `ai_messages`, 정산 `refund_credits` | 402 `CR001`, 404 대화, 429 `AI_DAILY_LIMIT`, 503 `AI_UNAVAILABLE`(환불됨) |
| POST `/api/ai/search-parse` | 로그인, `search_assist` | `{ request_id, text: 1..200 }` | `{ filters: {city?, region_text?, check_in?, check_out?, guests?, min_price?, max_price?, room_type?}, confidence }` | 1 | FastAPI `POST /llm/stay.search_parse`(scope `llm`, `feat=stay.search_parse`) | `consume_credits(search:<request_id>)`, 실패 환불 | 402 `CR001`, 422 `AI_PARSE_FAILED`(환불, 일반 폼으로), 429 `AI_DAILY_LIMIT` |
| POST `/api/ai/listing-assist` | 호스트, `listing_assist` | `{ listing_id, request_id, tone?: 담백\|따뜻함\|간결 }` | SSE 노드 진행 + `result{titles[3], description}` | 3(오픈소스)·5(상용), 호스트 조직 지갑 | FastAPI `POST /graphs/stay.listing_assist/runs`(scope `graph`, `feat=stay.listing_assist`) | `consume_credits(run:<ai_run_id>)`, `ai_runs` | 402, 403 42501(다른 조직 숙소), 429, 503(환불) |
| GET `/api/ai/listing-assist/[run_id]` | 호스트 | - | `{ status, result? }` | 0 | FastAPI `GET /graphs/runs/{id}` | `ai_runs`(조직 일치 확인) | 404 |
| POST `/api/host/wiki/documents` | 호스트, `host_wiki`, `host_wiki_max_docs` | multipart `file`(md/txt/pdf, 10MB), `listing_id` | `{ document_id, job_id }` | 3·5(문서당, 잡 시작 시) | Storage `org-files/<org_id>/stay/wiki/<listing_id>/<uuid>.<ext>` → `enqueue_job('stay.wiki.ingest')` | `ai_documents`, `consume_credits(run:<ai_run_id>)` | 409(`content_hash` 중복), 413, 403(한도) |
| GET `/api/host/wiki/pages`, `/api/host/wiki/pages/[slug]` | 호스트 조직 멤버 | `?listing_id` | 페이지 목록 / 본문·이력 | 0 | FastAPI `GET /wiki/pages/{slug}`(scope `wiki`) | `wiki_pages`(slug 접두사 `listings/<listing_id>/`) | 404 |
| PATCH `/api/host/wiki/pages/[slug]` | 호스트 | `{ blocks, expected_version, publish?: boolean }` | `{ version, status }` | 0 | FastAPI 위키 저장(scope `wiki`) | `wiki_revisions` | 409 버전 충돌 |
| POST `/api/host/wiki/lint` | 호스트 | `{ listing_id }` | `{ run_id }` | 2·3 | FastAPI `POST /wiki/lint` | `consume_credits(run:<id>)` | 402 |
| POST `/api/voice/notice-ack` | 로그인 | `{ notice_version }` | 204 | 0 | 없음 | `write_audit('voice.notice_ack')` | 409 버전 불일치 |
| POST `/api/voice/stt` | 로그인, `voice_chat`, 고지 확인 | multipart `audio`(webm/ogg/mp4, 30초·3MB), `request_id`, `conversation_id` | `{ text }` | 분당 1·2(30초 단위 올림) | core-voice(오픈소스 서버는 scope `voice`) | `voice_jobs`(`store_audio=false`), `consume_credits(voice:<request_id>)` | 403 `VOICE_NOTICE_REQUIRED`, 413, 429 |
| POST `/api/voice/tts` | 대화 주인 | `{ message_id, request_id }`(저장된 assistant 메시지만, 임의 텍스트 불가) | `audio/mpeg` 스트림 | 1,000자당 1·3 | core-voice | `voice_jobs`, `consume_credits` | 404, 400(임의 텍스트), 402 |

## 3. RPC (SECURITY DEFINER)

모든 함수는 `set search_path = ''`이고 SQL 끝 루프가 EXECUTE를 회수한 뒤 아래 호출자에게만 준다(SQL:1123-1170).

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `stay_today()` | anon, authenticated | 없음(서울 날짜) | date | - |
| `search_listings(p_sw_lat numeric, p_sw_lng numeric, p_ne_lat numeric, p_ne_lng numeric, p_city text, p_check_in date, p_check_out date, p_guests integer, p_min_price integer, p_max_price integer, p_room_type text, p_limit integer, p_offset integer)` | anon, authenticated | 날짜 쌍, 과거 날짜. published·미삭제, 경계·인원·가격·유형, 날짜 있으면 박수·운영 기간·`stay_range_is_free` | setof jsonb(카드) | SY002 |
| `get_listing_public(p_listing_id uuid)` | anon, authenticated | published 또는 호출자가 조직 멤버 | jsonb(카드 + 상세 + 사진 + 호스트) | SY001 |
| `listing_unavailable_ranges(p_listing_id uuid, p_from date, p_to date)` | anon, authenticated | 범위 400일 이하, published | table(start_date, end_date) | SY001, SY002 |
| `listing_reviews_public(p_listing_id uuid, p_limit integer, p_offset integer)` | anon, authenticated | published 숙소의 visible 리뷰 | setof jsonb(이름 가림) | - |
| `create_listing(p_org_id uuid default null)` | authenticated | 활성 사용자, 조직 멤버(owner/admin/member), 엔타이틀먼트, 20/시간, `max_listings` | listings | 42501, SY012, SY429 |
| `transition_listing(p_listing_id uuid, p_to text)` | authenticated | 조직 멤버, 허용 전이, 게시 조건(제목·설명·요금·위치·사진 5장) | listings | SY001, SY007, SY010, 42501 |
| `suspend_listing(p_listing_id uuid, p_suspend boolean, p_reason text default null)` | service_role | service 호출자 | listings | SY007, 42501 |
| `delete_listing(p_listing_id uuid)` | authenticated | owner/admin, 남은 활성 예약 없음 | void | SY001, SY007, 42501 |
| `block_dates(p_listing_id uuid, p_start date, p_end date, p_note text default '')` | authenticated | 조직 멤버, 날짜, 예약·차단과 겹침 없음 | availability_blocks | SY001, SY002, SY003, 42501 |
| `unblock_dates(p_block_id uuid)` | authenticated | 조직 멤버 | void | SY001, 42501 |
| `respond_reservation(p_reservation_id uuid, p_accept boolean)` | authenticated | 호스트 조직 멤버, requested·미만료 | reservations | SY001, SY007, 42501 |
| `host_cancel_reservation(p_reservation_id uuid, p_reason text)` | authenticated | owner/admin, confirmed·체크인 전, 사유 5자 이상 | reservations | SY001, SY007, 22023, 42501 |
| `reply_review(p_review_id uuid, p_reply text)` | authenticated | 호스트 조직 멤버, 답글 없음 | reviews | SY001, SY009, 42501 |
| `host_reservations(p_org_id uuid, p_status text default null, p_limit integer default 50, p_offset integer default 0)` | authenticated | 조직 멤버 | setof jsonb(예약 + 숙소 제목 + 게스트 표시 이름) | 42501 |
| `create_reservation(p_listing_id uuid, p_check_in date, p_check_out date, p_adults integer, p_children integer default 0, p_infants integer default 0, p_message text default '')` | authenticated | 활성 사용자, 10/시간, published, 자기 숙소 아님, 날짜, 박수, 인원, 운영 기간, 비어 있음, 배타 제약 | reservations | SY001~SY006, SY429, 42501 |
| `guest_cancel_reservation(p_reservation_id uuid, p_reason text default null)` | authenticated | 게스트 본인, requested 또는 confirmed·체크인 전날까지 | reservations | SY001, SY007 |
| `create_review(p_reservation_id uuid, p_rating integer, p_content text)` | authenticated | 게스트 본인, completed·체크아웃 14일 이내, 10/시간, 예약당 1개 | reviews | SY001, SY008, SY009, SY429, 23514(범위) |
| `toggle_wishlist(p_listing_id uuid)` | authenticated | 활성 사용자, 120/분, 추가 시 published | boolean | SY001, SY429 |
| `my_wishlist()` | authenticated | 활성 사용자 | setof jsonb | 42501 |
| `my_trips()` | authenticated | 활성 사용자. confirmed·completed만 `private` 포함 | setof jsonb | 42501 |
| `stay_run_maintenance()` | service_role | service 호출자 | jsonb `{expired, completed, at}` | 42501 |

내부 헬퍼(EXECUTE 없음, DEFINER 함수 안에서만): `stay_clean_text`, `stay_plan_feature_int`, `stay_require_active_user`, `stay_rate_limit`, `stay_listing_card`, `stay_range_is_free`. 트리거 함수: `listing_private_sync_public_geo`, `reviews_refresh_listing_rating`.

## 4. 잡 페이로드 계약

`enqueue_job(p_job_type, p_payload, ...)`(코어 SECTION 7). 큐 `stay`. 모든 페이로드에 `org_id`가 있고 워커는 처리 전 대상 행의 `org_id`와 일치하는지 다시 확인한다.

| job_type | 페이로드 | 멱등 키 | 결과 |
|---|---|---|---|
| `stay.photo.process` | `{ org_id, listing_id, photo_id, path }` | `photo:<photo_id>` | 640px·2048px webp 변환본을 `<path 확장자 전>_640.webp`, `_2048.webp`로 저장, `listing_photos.width/height` 갱신 |
| `stay.ai.index_listing` | `{ org_id, listing_id, action: upsert\|deactivate, listing_updated_at }` | `index:<listing_id>:<listing_updated_at>` | 컬렉션 `listing-<listing_id>` 재색인 또는 비활성. 입력은 `get_listing_public`과 같은 공개 필드 + 캡션 + published 위키만 |
| `stay.wiki.ingest` | `{ org_id, listing_id, document_id, ai_run_id, user_id }` | `run:<ai_run_id>` | 위키 페이지 draft 생성·갱신(문서당 5페이지 이하), 정산 |
| `stay.ai.review_summary` | `{ org_id, listing_id, reason: daily\|threshold }` | `summary:<listing_id>:<yyyy-mm-dd>` | `ai_runs`(graph `stay.review_summary`) 1행, 오픈소스만 |
| `stay.notify.email` | `{ org_id, reservation_id, event: requested\|confirmed\|declined\|expired\|canceled_by_guest\|canceled_by_host, to: host\|guest }` | `mail:<reservation_id>:<event>:<to>` | 수신자 이메일은 워커가 service_role로 `auth.users`에서 조회(페이로드에 이메일 없음). 본문에 상세주소 미포함(확정 메일은 "내 여행에서 확인" 링크) |

## 5. 웹훅

MVP는 없다(결제 없음, 01장 D2).

| Phase 2 | 내용 |
|---|---|
| POST `/api/webhooks/toss` | 예약 결제·Host Plus 정기결제. 서명 검증 → `webhook_events` 멱등 기록 → `confirm_payment_order`(코어 SECTION 3, `0001_core_lite.sql`의 `confirm_payment_order`) 호출. 금액 불일치 `PM001`이면 `fail_payment_order` 후 Toss 취소 |
| 예약 연결 | Phase 2 마이그레이션 `0003_stay_*.sql`에서 `reservations`에 `payment_order_id`를 추가하고 결제 승인 시 requested → confirmed 전이를 RPC로 묶는다(설계는 D2·D4 결정 뒤) |

## 6. 외부 API 어댑터

### 6.1 FastAPI 엔드포인트 (`AI_ARCHITECTURE.md` 8장 중 이 제품이 쓰는 것)

| 엔드포인트 | 호출자 | 용도 |
|---|---|---|
| `POST /tools/answer` | Dify HTTP 노드(내부 키 + 대화 매핑) | 숙소 도우미 답변(컬렉션 `listing-<id>` + published 위키, 출처 포함) |
| `POST /tools/answer-direct` | Next.js(Dify 장애 시, 서명 토큰) | 같은 처리 |
| `POST /rag/ingest`, `POST /rag/search` | 워커(`stay.ai.index_listing`) | 숙소 공개 정보 색인 |
| `POST /wiki/ingest`, `GET /wiki/pages/{slug}`, `POST /wiki/lint` | Next.js, 워커 | 호스트 위키 |
| `POST /graphs/stay.listing_assist/runs`, `GET /graphs/runs/{id}` | Next.js(서명 토큰, scope `graph`) | 소개 작성 도우미(SSE) |
| `POST /graphs/stay.review_summary/runs` | 워커(service 토큰) | 리뷰 요약 |
| `POST /llm/stay.search_parse` | Next.js(서명 토큰, scope `llm`) | 자연어 검색 해석(JSON 스키마 출력). 제품 전용 엔드포인트(`app/ai/llm/stay_search_parse.py`) |

### 6.2 Dify Chatflow 계약 (`stay-assistant`)

| 항목 | 내용 |
|---|---|
| 호출 | Next.js가 Dify Chat API `POST /chat-messages`(`response_mode=streaming`, `user=dify_user`) |
| `dify_user` | `HMAC(DIFY_USER_HMAC_SECRET, org_id:user_id)`. Dify에 사용자 id·이메일을 보내지 않는다 |
| 입력 변수 | `platform_conversation_id`(코어 `ai_conversations.id`), `listing_id`. Dify는 이 값으로 FastAPI에 근거 범위를 요청할 뿐 숙소 데이터를 저장하지 않는다 |
| 노드 | 질문 분류(LLM, `dify.aux` 오픈소스) → HTTP 노드 `POST {AI_SERVICE_URL}/tools/answer`(헤더 내부 키, 본문 `platform_conversation_id`, `query`) → 답변 노드(FastAPI 응답 그대로) |
| 응답 | `{ answer, citations: [{source: listing\|wiki, field_or_slug, excerpt}], provider, fallback }` |
| 범위 밖 질문 | 예약 가능 여부·가격 질문은 "예약 화면의 달력과 가격을 확인하세요"로 답하고 RPC를 호출하지 않는다(실시간 값 단정 금지, 01장 6.1절) |
| 로그 | Dify 대화 로그 30일 |

### 6.3 Google Maps (지도 어댑터 Google 구현, 01장 D6)

| 항목 | 내용 |
|---|---|
| 지도 렌더 | 브라우저 키(리퍼러 제한), Maps JavaScript API. 공개 좌표(소수 2자리)만 핀으로. 정확 좌표는 확정 게스트의 내 여행 지도에서만 |
| 지오코딩 | `GET /api/maps/geocode` → Geocoding API(서버 키, `language=ko`, `region=kr`) |
| 자동완성 | `GET /api/maps/places` → Places Autocomplete(세션 토큰으로 과금 묶음, 미확인: 현재 과금 방식) |
| 캐시 | 지도 타일·지오코딩 응답을 서버에 장기 저장하지 않는다. 저장하는 값은 호스트가 핀으로 확정한 좌표뿐(미확인: Maps Platform 약관의 저장 허용 조항) |
| 교체 | `MapProvider` 인터페이스(render, geocode, autocomplete, placeDetail)를 지키면 카카오·네이버 구현으로 바꿀 수 있다. 구현 대상은 Google·카카오맵·네이버 지도 3종이며 `MAP_PROVIDER`로 고른다(D6) |

### 6.4 이메일 발송

| 항목 | 내용 |
|---|---|
| 제공자 | 미정(구현 시 선택, 미확인: 국내 수신률·가격). 어댑터 `apps/api/app/jobs/notify.py`의 `send(to, template, vars)` 하나로 감싼다 |
| 템플릿 | 예약 요청(호스트), 확정·거절·만료(게스트), 취소(상대방). 한국어, 상세주소·전화번호 미포함 |
| 수신 거부 | 거래 메일은 필수 발송, 마케팅 메일은 MVP에 없음 |

### 6.5 날씨 (OpenWeatherMap)

| 항목 | 내용 |
|---|---|
| 용도 | 숙소 상세·카드·호스트 홈에 현재 날씨와 5일 예보 표시 |
| 호출 위치 | 서버(`GET /api/weather?lat&lng`)만. 브라우저에 키를 주지 않는다. 키는 `OPENWEATHER_API_KEY` |
| 좌표 | 숙소의 **공개 좌표(소수 2자리)**만 쓴다. 정확한 좌표·주소는 보내지 않는다 |
| 플랜 | 무료 플랜: 현재 날씨, 3시간 단위 5일 예보, 지오코딩 포함. 분당 60회, 월 100만 회(공식 가격 페이지 확인). One Call 계열은 무료 플랜에 포함되지 않는다 |
| 캐시 | 좌표 격자별 서버 캐시 10~30분(제안). 호출 수를 숙소 수가 아니라 지역 수에 비례하게 한다 |
| 표시 규칙 | 화면에 "Weather data © OpenWeather" 표기(약관: 숨은 문서에만 두면 불충분). 예보는 "예상"으로 표기하고 예약 가능 여부·가격과 섞지 않는다 |
| 장애 | 실패하면 위젯만 숨긴다. 예약·검색 흐름은 영향받지 않는다 |
| 미확인 | 상용 서비스에 쓸 때의 정확한 약관 전문, 한국 지역 데이터 정확도, 서버 캐시 허용 범위 |

### 6.6 환율 표기 (D19)

| 항목 | 내용 |
|---|---|
| 용도 | 원화 가격 옆에 외화 환산(USD·JPY·CNY 등)을 **참고용**으로 표기. 결제·정산 통화는 KRW |
| 제공자 | 미정(D19). 후보: 한국수출입은행 환율 정보(공공데이터포털 등록, 요청 도메인이 `oapi.koreaexim.go.kr`로 변경됐다는 안내 확인, 갱신 주기·인증키 요건은 페이지에 없어 미확인) 또는 상용 환율 API |
| 호출 | 서버 크론 하루 1회~수회가 값을 `fx_rates` 캐시에 저장. 화면은 캐시만 읽는다 |
| 표시 규칙 | "참고용 환산 · 기준일 YYYY-MM-DD" 표기. 영업일이 아닌 날은 마지막 값을 쓰고 기준일을 그대로 보여 준다 |
| 금지 | 환산 금액을 결제 금액·예약 확정 금액으로 쓰지 않는다. 예약 금액은 항상 원화 |
| 미확인 | 제공자별 이용 약관, 매매기준율과 송금 환율 중 표시 기준 |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| SY001 | 대상 없음 또는 공개되지 않음(숙소, 예약, 리뷰, 차단). 남의 예약도 존재를 숨기려고 SY001 | 404 |
| SY002 | 날짜 오류(체크아웃 ≤ 체크인, 과거, 한쪽만, 범위 초과) | 400 |
| SY003 | 날짜 사용 불가(예약·차단과 겹침, 운영 기간 밖, 동시 요청에서 짐) | 409 |
| SY004 | 인원 초과 또는 인원 값 오류 | 400 |
| SY005 | 최소·최대 박수 밖 | 400 |
| SY006 | 자기 숙소 예약 | 403 |
| SY007 | 허용되지 않는 상태 전이(숙소·예약), 활성 예약 있는 숙소 삭제 | 409 |
| SY008 | 리뷰 작성 불가(완료 전, 14일 경과) | 403 |
| SY009 | 중복(리뷰, 답글) | 409 |
| SY010 | 게시 조건 미충족. 메시지에 빠진 항목(`title,description,price,location,photos`) | 422 |
| SY011 | 예약(미사용) | - |
| SY012 | 플랜 숙소 수 한도. 결제 수단이 없는 베타라 "결제 필요(402)"가 아니라 권한 한도로 보고 403으로 돌려주며 Phase 2 Host Plus 안내를 붙인다 | 403 |
| SY429 | 레이트 리밋(DB 버킷) | 429 |
| 42501 | 권한 없음(비멤버, 역할 부족, 정지 계정, anon의 RPC) | 403 |
| 23514 | 제약 위반(사진 경로, 별점 범위 등 입력 검증을 통과한 뒤 DB가 거부) | 400 |
| 22023 | 잘못된 인자(호스트 취소 사유 부족) | 400 |
| CR001 | 크레딧 부족(코어) | 402 |
| AI001 | AI 기능 비활성(플랜 키 false, 코어) | 403 |
| AI_DAILY_LIMIT | 하루 AI 한도 초과 | 429 |
| AI_PARSE_FAILED | 자연어 검색 해석 실패(환불, 일반 폼으로) | 422 |
| AI_UNAVAILABLE | AI 제공자·Dify·FastAPI 장애(선차감 환불됨) | 503 |
| VOICE_NOTICE_REQUIRED | 음성 처리 고지 미확인 | 403 |
| CONSENT_VERSION_MISMATCH | 고지문 버전 불일치 | 409 |

## 8. 인증 단계 라우트

| 라우트 | 단계 | 내용 |
|---|---|---|
| POST `/api/dev/login` | A만 | `{ persona }` → 시드 계정 `signInWithPassword` → `finishLogin`. `isMockAuthAllowed()`가 거짓이면(배포 환경, 비루프백 Supabase) 404 |
| GET `/auth/callback` | B·C | `?code&next` → `exchangeCodeForSession` → `finishLogin('stay', next)`. `next`는 내부 경로만(02장 9.4절) |
| GET `/api/auth/naver/start`, `/api/auth/naver/callback` | C2 브리지 경로만(D16) | state 쿠키 발급·검증, 네이버 토큰 교환, 세션 발급 → `finishLogin`. `supabase_custom` 경로면 만들지 않는다. 원본 `pages/api/auth/naver*.ts`는 참고만(07장 6절) |
| `/login`, `/signup`, `/reset-password` | A·B·C | 화면. `listLoginOptions('stay')` 결과로 버튼 렌더 |

원본의 `/api/auth/signup`, `/login`, `/logout`, `/me`, `/refresh`, `/google*`, `/kakao*`는 만들지 않는다. 로그아웃은 브라우저 클라이언트 `supabase.auth.signOut()`, 현재 사용자는 서버 컴포넌트의 `session_context('stay')`다.
