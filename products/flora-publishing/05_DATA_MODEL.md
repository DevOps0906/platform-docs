# 05 데이터 모델: FLORA Publishing

작성일 2026-10-12. 정본 SQL은 `docs/products/_supabase-modular/migrations/1000_publishing.sql`(아래 "조각:줄"). 모놀리스 `supabase/monolith/migrations/0002_publishing_domain.sql`은 조각을 변환한 것이다. 규칙은 `docs/products/_platform-core/DB_CONVENTIONS.md`(아래 DBC).

## 1. 개요와 ERD

```
core.organizations (참조만)
 ├── publishing.books ───────────────┬── publishing.chapters ── publishing.sections ──> core.jobs (last_job_id)
 │     ├─> publishing.custom_personas │
 │     ├─> publishing.cover_images ───┘(cover_image_id)          cover_images ──> core.jobs
 │     ├── publishing.book_exports ──> core.jobs, core.credit_ledger
 │     ├── publishing.generation_runs ──> core.jobs (parent_job_id)
 │     └── publishing.manuscript_uploads (book_id 선택) ──> core.jobs
 ├── publishing.member_settings (org_id, user_id)
 ├── publishing.custom_personas
 └── publishing.webhook_endpoints ──> core.encrypted_credentials
       └── publishing.webhook_deliveries
publishing.waitlist (테넌트 아님)
코어 사용: core.plans/app_entitlements(플랜 해석), core.wallets/credit_ledger(크레딧), core.jobs, Storage 버킷 3개, core.audit_log
```

복합 키 규칙: 하위 테이블은 `(book_id, org_id) → books(id, org_id)`, sections는 `(chapter_id, book_id) → chapters(id, book_id)`까지 걸어, 다른 조직이나 다른 책의 행을 참조할 수 없다(RLS 스모크에서 23503 확인).

## 2. 테이블

모든 테넌트 테이블: `org_id uuid not null references core.organizations(id) on delete cascade`, `created_at`, UPDATE가 있으면 `updated_at` + `core.set_updated_at` 트리거(DBC 3장, 5장). 열거형은 text + CHECK(DBC 6장).

### 2.1 books (조각:118-167)

목적: 책 1권 = 프로젝트 1개. 위저드 상태, 판형, 페르소나, 기획안, 책 정보, 공개 여부.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | N | `gen_random_uuid()` | PK. `unique(id, org_id)` |
| `org_id` | uuid | N | - | 조직 |
| `title` | text | N | '제목 없음' | 1~200자 |
| `subtitle`, `author_name` | text | Y | - | 200자, 100자 |
| `genre` | text | Y | - | novel, essay, poetry, self_help, nonfiction_business, it_tech, children, fantasy_genre |
| `format_key` | text | N | 'A5' | A6, B6, A5, shinkuk, B5, A4_variant |
| `persona_id` | text | Y | - | 카탈로그 JSON 키(64자) |
| `custom_persona_id` | uuid | Y | - | `(custom_persona_id, org_id)` → custom_personas |
| `taste_config` | jsonb | Y | - | 서버가 집필 시작 때 고정한 Taste 스냅샷(사용자 GRANT 없음) |
| `tone` | jsonb | N | '{}' | 어조 슬라이더 3축 |
| `layout_settings` | jsonb | N | '{}' | Auto-Fit 미세조정(본문 pt, 행간, 여백 4방향) |
| `plan_brief` | jsonb | Y | - | 선택한 기획안 + 타겟 독자, 강조 톤 |
| `book_info` | jsonb | N | '{}' | 부제, 키워드 5, 소개 200자, 출판사, `isbn_reference` |
| `step_state` | jsonb | N | '{}' | 위저드 UI 상태(후보 캐시, 완료 단계) |
| `current_step` | smallint | N | 1 | 1~10 |
| `source` | text | N | 'wizard' | wizard, upload, seed |
| `seed_key` | text | Y | - | seed_01~03 |
| `cover_image_id` | uuid | Y | - | → cover_images(id), on delete set null. 같은 책·succeeded만(트리거) |
| `status` | text | N | 'draft' | 3절 |
| `writing_started_at`, `completed_at` | timestamptz | Y | - | 전이 트리거가 기록 |
| `is_public`, `slug`, `published_at` | bool, text, timestamptz | N/Y/Y | false | Phase 2. RPC만 변경. `is_public`이면 slug 필수(CHECK) |
| `word_count` | integer | N | 0 | 서버 갱신 |
| `created_by` | uuid | Y | - | FK 없음(DBC 3장). 사용자 INSERT면 트리거가 `auth.uid()`로 강제 |
| `deleted_at` | timestamptz | Y | - | 휴지통. 사용자 복구 불가(`PB010`) |

### 2.2 chapters (조각:171-186), sections (조각:188-214)

| 테이블 | 핵심 컬럼 | 제약 |
|---|---|---|
| chapters | `book_id`, `position` 1~20, `title` 1~200자 | `unique(book_id, position) deferrable initially deferred`(드래그 정렬 한 트랜잭션), `unique(id, book_id)`, `(book_id, org_id)` FK cascade |
| sections | `book_id`, `chapter_id`, `position` 1~10, `title`, `paragraph_target` 1~5, `body_html`(200KB), `char_count`(트리거 계산), `gen_status`, `last_job_id`, `last_error`, `revision`, `updated_by` | `unique(chapter_id, position) deferrable`, `(chapter_id, book_id)`·`(book_id, org_id)` FK cascade. `gen_status`, `last_job_id`, `last_error`, `revision`은 사용자 GRANT 없음 |

### 2.3 서버 전용 테이블

| 테이블 | 목적 | 핵심 컬럼 | 제약 |
|---|---|---|---|
| `cover_images` (조각:219-244) | 표지 후보 | `style`(5종), `provider` 'fal', `model`, `prompt` ≤ 4000, `storage_path`(첫 폴더 = org_id), `status`, `job_id` | 경로 CHECK, `(book_id, org_id)` FK |
| `manuscript_uploads` (조각:257-282) | 원고 업로드 | `storage_path` unique(`<org>/publishing/...`), `original_name`(표시용 255자), `ext` txt/md/docx/pdf, `bytes` 1~20MB, `status`, `parsed_outline`, `raw_deleted_at` | 경로 CHECK, `(book_id, org_id)` FK `on delete set null (book_id)` |
| `book_exports` (조각:289-318) | 내보내기 기록 | `format` pdf/epub, `status`, `job_id`, `credit_ledger_id` → core.credit_ledger, `content_hash`, `watermark`, `preset`, `storage_path`, `bytes`, `pages`, `expires_at` | 재사용 인덱스(book, format, hash) |
| `generation_runs` (조각:325-354) | 전체 생성/다듬기 실행 | `kind`, `mode`, `parent_job_id`, `status`, 집계 4종, `credits_estimated/used`, `cancel_requested_at/by` | 책당 진행 1개 부분 유니크 |
| `webhook_endpoints` (조각:382-403) | 아웃바운드 웹훅 | `url` https ≤ 2000, `events` ⊂ {book.completed, export.succeeded, export.failed}, `secret_credential_id` → core.encrypted_credentials, `status`, `consecutive_failures` | 평문 비밀 컬럼 없음 |
| `webhook_deliveries` (조각:405-421) | 전송 기록 | bigint identity, `event_id`, `status`, `http_status`, `attempts`, `next_attempt_at` | `unique(endpoint_id, event_id)` 멱등 |
| `waitlist` (조각:426-434) | 대기자 | `email`(형식 CHECK, `lower(email)` 유니크), `consent_marketing`, `ip_hash` | 테넌트 아님. 정책 없음 |

### 2.4 사용자 쓰기 테이블

| 테이블 | 목적 | 핵심 컬럼 |
|---|---|---|
| `custom_personas` (조각:98-113) | 나만의 페르소나 | `name` 1~60자, `base_persona_ids` ≤ 3, `taste_config`, `status` active/archived. INSERT는 서버만 |
| `member_settings` (조각:360-374) | 사용자 화면 설정 | PK `(org_id, user_id)`, `theme_key` 7종, `favorite_persona_ids` ≤ 60, `llm_mode`, `editor_prefs` |

## 3. 상태 전이

| 테이블.컬럼 | 현재 | 허용 전이 | 누가 | 부수 효과 | 구현 |
|---|---|---|---|---|---|
| books.status | draft | writing, archived | 사용자, 서버 | writing 진입 시 `writing_started_at`, 서버가 Taste 고정 | 트리거 `books_before_update`(조각:476) |
| | writing | draft, ready, archived | 같음 | - | 같음 |
| | ready | writing, completed, archived | 같음 | completed 시 `completed_at`, 웹훅 `book.completed` | 같음 |
| | completed | writing, archived | 같음 | 완성 해제 시 `is_public=false` | 같음 |
| | archived | draft | 같음 | - | 같음 |
| sections.gen_status | empty/edited/generated/failed | queued → generating → generated 또는 failed | 서버(워커) | 사용자 본문 수정 시 자동 edited. queued/generating 중 사용자 편집 `PB005` | 트리거 `sections_before_write`(조각:548) |
| book_exports.status | queued | running, failed, canceled | 서버 | started_at | 트리거(조각:599) |
| | running | queued(재시도), succeeded, failed | 서버 | finished_at | 같음 |
| | succeeded | expired | 서버(purge) | 파일 삭제 | 같음 |
| generation_runs.status | queued | running, canceled, failed | 서버, 취소 요청은 RPC | started_at | 트리거(조각:626) + `request_generation_cancel` |
| | running | succeeded, partial, failed, canceled | 서버 | finished_at, 미처리 자식 cancel_job(환불) | 같음 |
| manuscript_uploads.status | pending_upload → uploaded → parsing → parsed / failed → expired | (parsing → uploaded는 재시도) | 서버 | 파싱 24시간 뒤 원본 삭제, `raw_deleted_at` | 트리거(조각:652) |
| cover_images.status | queued → running → succeeded/failed | - | 서버 | - | 서버 코드(단순 순서, 부수 효과 없음) |

## 4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| books | `is_org_member(org_id) and has_entitlement(org_id,'publishing')`; anon: `is_public and status='completed' and deleted_at is null and slug is not null` | `has_org_role(org_id, owner/admin/member) and has_entitlement` | using `has_org_role(편집자)`, with check 같음 + 엔타이틀먼트 | `has_org_role(owner/admin)` | select, delete, 컬럼 insert/update(조각:863-871). anon은 공개 컬럼 10개만 select |
| chapters, sections | 멤버 + 엔타이틀먼트 | 편집자 + 엔타이틀먼트 | 편집자, with check | 편집자 | 컬럼 단위 insert/update(조각:893-912) |
| custom_personas | 멤버 + 엔타이틀먼트 | 없음(서버, 트리거 42501) | `name, status`만, 편집자 | owner/admin | select, delete, update(name, status) |
| member_settings | `user_id = auth.uid() and is_org_member` | 같음 + 엔타이틀먼트 | 같음 | 없음 | select, insert, update |
| cover_images, manuscript_uploads, book_exports, generation_runs | 멤버 + 엔타이틀먼트 | 없음 | 없음 | 없음 | select. + `guard_privileged_write` |
| webhook_endpoints, webhook_deliveries | owner/admin + 엔타이틀먼트 | 없음 | 없음 | 없음 | select. + guard |
| waitlist | 없음 | 없음 | 없음 | 없음 | 없음. + guard |

사용자 쓰기 정책을 준 테이블(books, chapters, sections, custom_personas, member_settings)의 DBC 8장 조건 충족 근거:

| 조건 | 충족 방식 |
|---|---|
| (a) `with check`에 멤버십 + 엔타이틀먼트 | 모든 INSERT/UPDATE 정책에 있음. org_id는 UPDATE GRANT에서 빠져 다른 조직으로 옮길 수 없음 |
| (b) 권한·과금 컬럼 없음 | books의 `is_public`, `slug`, `taste_config`, `word_count`와 sections의 `gen_status`, `last_job_id`는 컬럼 GRANT에서 제외(스모크에서 42501 확인). 과금은 코어 원장에만 있음 |
| (c) 상태 컬럼은 전이 트리거 | books.status, sections.gen_status 트리거. 플랜 한도는 INSERT 트리거(`PB001~PB004`) |

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `books_org_updated_idx (org_id, updated_at desc) where deleted_at is null` | 대시보드 최근 책, 목록 |
| `books_org_status_idx (org_id, status) where deleted_at is null` | 상태 필터, 쿼터 카운트 |
| `books_deleted_idx (deleted_at) where not null` | 휴지통 purge |
| `sections_book_idx (book_id, chapter_id, position)` | 에디터 로드, HTML 조립 |
| `chapters_book_position_uniq`, `sections_chapter_position_uniq` | 순서 조회 겸 유일성 |
| `book_exports_reuse_idx (book_id, format, content_hash) where succeeded` | 재사용 판정 |
| `book_exports_org_month_idx (org_id, created_at)` | Free 월 내보내기 횟수 |
| `book_exports_expiry_idx (expires_at) where succeeded` | 만료 purge |
| `generation_runs_one_active_per_book_idx` | 동시 실행 방지 |
| `custom_personas_org_idx`, `cover_images_book_idx`, `manuscript_uploads_org_idx`, `webhook_*_org_idx` | 목록 |

예상 규모(제안): Basic 조직당 책 20권, 책당 섹션 60, 섹션 본문 평균 6KB → 조직당 약 7MB. RLS 헬퍼는 STABLE SECURITY DEFINER라 행마다 재평가되지만 `org_id` 인덱스로 범위가 작다.

## 6. 코어 참조

| 코어 객체 | 용도 | ALTER 여부 |
|---|---|---|
| `core.organizations` | 모든 테넌트 FK | 안 함 |
| `core.is_org_member`, `has_org_role`, `has_entitlement`, `is_service_caller`, `is_privileged_session`(guard 트리거 내부) | 정책, 트리거, RPC | 안 함 |
| `core.app_entitlements`, `core.plans` | `book_plan_limit/flag/theme_allowed`가 features를 읽음 | 안 함 |
| `core.apps` | 조각 머리에서 `publishing` 등록(on conflict do nothing) | 행 추가만 |
| `core.jobs` | sections, cover_images, manuscript_uploads, book_exports, generation_runs의 FK(on delete set null) | 안 함 |
| `core.credit_ledger` | book_exports.credit_ledger_id | 안 함 |
| `core.encrypted_credentials` | 웹훅 비밀 | 안 함 |
| `core.write_audit` | RPC 감사 | 안 함 |
| `core.set_updated_at`, `core.guard_privileged_write` | 트리거 | 안 함 |
| Storage `org-files`, `exports`, `public-assets` | 업로드·표지, 내보내기, 공개 표지(Phase 2) | 안 함. 경로 첫 폴더 = org_id를 CHECK로 한 번 더 확인 |
| Realtime `supabase_realtime` | `publishing.sections`, `publishing.generation_runs` 추가 | 발행 목록에 제품 테이블만 추가 |

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

12건. 나머지 13건(비보안)은 `02_ARCHITECTURE.md` 6절. 합계 25 = 리뷰 4건의 "높음" 수(Flora-v2 9, flora 10, flora-publisher 2, SellingDocs 4).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Flora-v2.md` 3장 #3 | `api/routers/llm.py:25-336`, `export.py:23,45`, `upload.py:13,22` | LLM·내보내기·업로드·병합 무인증, 서버 키 무제한 사용 | 모든 유료 경로가 web Route Handler(`requireSession`) → 선차감(`consume_credits`, service_role 전용 EXECUTE `migrations/0003_core_credits.sql:370-375`) 뒤에만 존재. 엔진·렌더 서비스는 private network + 내부 토큰, 엔진 기동 시 토큰 미설정이면 종료. TOC 길이(챕터 20, 소제목 200) DB CHECK와 트리거 | 04장 1절, PB-06-007, PB-06-003 |
| `docs/reviews/Flora-v2.md` 3장 #4 | `supabase/migrations/002_rls.sql:13` | `user_plans FOR ALL`로 자기 플랜 상향 | 플랜·크레딧은 제품 스키마에 없다. `core.app_entitlements`, `core.wallets`는 SELECT 정책만 + guard 트리거(`migrations/0002_core_billing.sql:232-240`). 제품 조각에 `FOR ALL` 정책 0개. 스모크: 자기 엔타이틀먼트·지갑 UPDATE 42501 | 4절, PB-06-029 |
| `docs/reviews/Flora-v2.md` 3장 #5 | `password-unlock-modal.tsx:14-15`, `use-is-pro.ts:14-17` | `'1234'`와 localStorage로 max 플랜 | 플랜 판정은 서버 `entitled_plan_code` + features 해석(`web/src/server/features`)만. 잠금해제 모달·localStorage 플래그 코드는 이식 금지(07장 4절), CI에서 `flora_pro_unlocked`, `PasswordUnlock` 문자열 검색 시 실패 | PB-06-008, PB-06-005 |
| `docs/reviews/flora.md` 3장 #1 | `api/routers/llm.py:253-1726` | LLM 10개 엔드포인트 무인증, `/debug-api-keys` | 위 Flora-v2 #3과 같은 경계. Python 쪽에는 LLM 호출 경로가 없다. 디버그 엔드포인트 이식 금지 | PB-06-007, PB-06-011 |
| `docs/reviews/flora.md` 3장 #2 | `api/routers/billing.py:83-119` | Stripe 웹훅 서명 미검증으로 플랜 위조 | Stripe 제거, Toss. 지급은 confirm 경로(`confirm_payment_order`, 금액은 서버 주문 정본)만. 웹훅은 서명 검증 실패 401 + `webhook_events.signature_valid=false`, 지급하지 않음(`CORE_SPEC.md:241-247`) | PB-06-009, PB-06-030 |
| `docs/reviews/flora.md` 3장 #3 | `supabase/migrations/002_user_plans_and_persona.sql:23-25` | `user_plans for all` 권한 상승 | Flora-v2 #4와 같음 | PB-06-029 |
| `docs/reviews/flora.md` 3장 #4 | `api/routers/tts.py:59-71` | WAV 업로드 경로 조작 | 레퍼런스 WAV 기능 폐기(07장 3절). 남은 업로드(원고)는 서버가 경로 `<org>/publishing/manuscripts/<uuid>.<ext>` 생성, 원래 파일명은 표시용 컬럼에만, 경로 CHECK(조각:262), 매직바이트·크기 재검사 | PB-06-015 |
| `docs/reviews/flora.md` 3장 #5 | `api/routers/export.py:224-228`, `:195-200` | `cover_url` 서버 다운로드 SSRF, WeasyPrint 외부·`file://` fetch | 클라이언트가 URL을 보내지 않는다(표지는 `cover_image_id` → Storage 경로). 렌더 서비스 `url_fetcher`는 허용 호스트(https, 자체 Storage)만, 사설 IP·리다이렉트·`file://` 거부, 위반 시 렌더 실패(04장 4절). 웹훅 등록 URL도 사설 IP 거부 | PB-06-004, PB-06-032 |
| `docs/reviews/flora.md` 3장 #6 | `frontend/src/lib/admin.ts:17`, `use-is-pro.ts:13` | Pro 게이팅이 클라이언트 전용 | Flora-v2 #5와 같음. 추가로 쿼터는 DB 트리거(`PB001~PB004`), 테마는 `PB008`로 DB가 강제 | PB-06-008, PB-06-029 |
| `docs/reviews/flora-publisher.md` 3장 #1 | `backend/server.js:104-106`, `:113-115` | Vertex 프록시 `endpoint_location` 조작으로 GCP 토큰 유출 | 범용 프록시를 이식하지 않는다(07장 3절). LLM은 공용 게이트웨이의 고정 제공자 URL만 호출하고 사용자 입력으로 호스트를 만들지 않는다. 폴더 아카이브 | PB-06-033 |
| `docs/reviews/flora-publisher.md` 3장 #2 | `frontend/vertex-ai-proxy-interceptor.js:116`, `backend/server.js:194` | 하드코딩 프록시 헤더가 유일한 접근 제어 | 번들에 비밀을 두지 않는다(`NEXT_PUBLIC_` 금지 목록, `SECURITY_BASELINE.md` 5장). 서버 간 호출 토큰은 환경변수, 브라우저는 세션 쿠키로만 인증 | PB-06-002, PB-06-033 |
| `docs/reviews/SellingDocs.md` 3장 #2 | `PRD.md:48`, `:86-91` | 크레딧 차감 주체·시점·환불·원자성 부재 | 코어 원장(원자 차감 `wallets FOR UPDATE`, 멱등 키, 환불 비율, append-only, `migrations/0003_core_credits.sql:130-367`) + 01장 4.3절 단가표 + 04장 1절 순서. 잡 실패는 `fail_job` 자동 환불. 동시성 테스트(같은 조직 50회 동시 consume → 음수 없음, drift 0) | PB-06-008, PB-06-031 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 | 비고 |
|---|---|---|---|
| 스키마 | `publishing` + `core` | `public` 하나 | 모놀리스 스키마 `public`은 사용자 최종 확인 대기(작업 지시, `MONOLITH_CORE_LITE.sql:5-10`) |
| 코어 | `migrations/0000~0006` | `0001_core_lite.sql`: SECTION 6-A(OAuth state), 9(affiliate) 제거. 3, 4, 6-B, 6-C, 7, 8 유지 | 제거 사유는 파일 안 주석 |
| 제품 SQL | `1000_publishing.sql`(정본) | `0002_publishing_domain.sql` = 정본을 DBC 12장 규칙으로 변환(create schema 제거, `core.`/`publishing.` → `public.`, Realtime schemaname) | 직접 수정 금지, 변환 스크립트 작업 PB-06-001 |
| 앱 등록 | `core.apps` + 모듈러 seed | `public.apps` 1행(`schema_name='public'`) → 가입 시 메타데이터 없이 자동 부트스트랩 | `DBC` 12장 |
| 플랜 seed | 모듈러 seed(`seed.sql:33`, `:95`)의 features 4키 | `seed.sql`에 features 16키 | 금액·크레딧 같음. 키 차이는 서버 기본값으로 흡수, 코어 요청(06장 6절) |
| PostgREST | `[api].schemas`에 `publishing` 추가, 클라이언트 `supabase.schema('publishing')` | 기본 노출 | - |
| 월 지급 | `run_monthly_credit_grants()` | `run_subscription_rollover()` + `run_monthly_credit_grants()` | DBC 12장 |
| 알려진 코어 결함 | `confirm_payment_order` 금액 불일치 시 raise가 UPDATE를 롤백해 주문이 failed로 남지 않음(`DB_CONVENTIONS.md` 13.2) | 같음 | 제품은 이 동작에 의존하지 않는다: `PM001`이면 Route Handler가 별도 트랜잭션으로 운영 알림 + Toss 취소 요청을 하고, 주문 상태 정리는 코어 `expire_stale_payment_orders`에 맡긴다. 코어 수정은 하지 않는다 |

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `docs/products/_supabase-modular/migrations/1000_publishing.sql` | 번호 1000(범위 1000~1099). 스키마, `core.apps` 등록, 헬퍼 3, 테이블 12, 트리거 함수 9, 사용자 RPC 2, RLS·GRANT, Realtime, 14절 함수 EXECUTE 최종 회수(PUBLIC·anon, `0007_core_function_privileges.sql`과 같은 규칙) |
| `supabase/monolith/migrations/0001_core_lite.sql` | `_platform-core/MONOLITH_CORE_LITE.sql` 복사본(OAuth state, affiliate 절 제거) |
| `supabase/monolith/migrations/0002_publishing_domain.sql` | 위 조각의 모놀리스 변환본 |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 free/basic(features 16키), 크레딧팩 2종. 제품 seed 없음(카탈로그는 코드 JSON) |

검증 결과(2026-10-12, `docs/products/_tools-sqlcheck`):

| 검사 | 결과 |
|---|---|
| `node check.mjs mono 0001_core_lite.sql 0002_publishing_domain.sql seed.sql` | OK 3/3 |
| `node check.mjs mod 0000~0007 seed.sql 1000_publishing.sql` | OK 10/10 |
| 반복 실행 | 두 구조 모두 제품 SQL 2회 적용 OK |
| RLS 스모크(PGlite, 사용자 A·B·C + anon) | 모듈러 57/57, 모놀리스 57/57 통과 |

RLS 스모크 주요 항목: B가 A 조직의 제품 테이블 11개 SELECT 0행, B의 A 조직 INSERT 42501, A 책 UPDATE/DELETE 0행, 다른 책 참조 INSERT 23503, B의 `request_generation_cancel`·`set_book_visibility`(A 행) 42501, `book_plan_limit`(A 조직) 기본값만 반환, 자기 엔타이틀먼트·지갑·profiles.platform_role·org_members.role 변경 42501, `grant_credits`·`consume_credits` 42501, 서버 전용 테이블 사용자 INSERT 42501, 컬럼 GRANT 밖 컬럼(`is_public`, `gen_status`, `org_id`) UPDATE 42501, 상태 전이 위반 22023, Free 4번째 책 `PB001`, Pro 테마 `PB008`, 엔타이틀먼트 정지 조직 INSERT 42501, anon 비공개 책 0행, anon의 제품 함수 EXECUTE 없음·트리거 함수는 authenticated도 EXECUTE 없음(PUBLIC 경유 차단). 스크립트는 PB-06-029 작업에서 `supabase/tests/`로 옮긴다.
