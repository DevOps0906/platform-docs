# 05 데이터 모델: NOMAD Commerce

정본 SQL: `docs/products/_supabase-modular/migrations/1400_commerce.sql`(이하 "조각"). 모놀리스 `supabase/monolith/migrations/0002_commerce_domain.sql`은 조각의 기계 변환본이다.

## 1. 개요와 ERD

```
core.organizations (참조만)
 ├─ import_batches ──< products >── (core.jobs, 참조)
 │                       ├─< detail_pages ──< detail_page_slots
 │                       │        └─< market_images
 │                       └─< listing_drafts >── shipping_templates
 │                                 │        >── market_accounts ── core.encrypted_credentials
 │                                 └─< market_uploads >── market_accounts, detail_pages, products
 ├─ export_files (product_ids[], detail_page_ids[])
 └─ banned_words (org_id null = 제품 기본 사전)
전역: exchange_rates, market_categories
코어 FK: detail_pages.credit_ledger_id → core.credit_ledger, *.job_id → core.jobs
```

조직 간 참조 오염을 막기 위해 자식 테이블은 `(org_id, <parent>_id)` 복합 FK로 부모 `unique (org_id, id)`를 참조한다. 선택 참조는 PG15 `on delete set null (<col>)`로 org_id를 지우지 않는다.

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 모든 테넌트 테이블에 `id uuid`, `org_id`(cascade), `created_at`, UPDATE 테이블은 `updated_at` + `core.set_updated_at`. `created_by`는 FK 없음.

| 테이블 | 목적 | 핵심 컬럼 | 제약 | 사용자 쓰기 | 조각 줄 |
|---|---|---|---|---|---|
| `import_batches` | 엑셀/아마존 가져오기 실행 | source_type(excel/amazon), supplier, file_path, column_mapping, status, total/imported/skipped/failed_rows, errors, job_id | status CHECK + 전이 | 없음 | `1400_commerce.sql:141-163` |
| `products` | 상품DB | source_type/supplier/ref/url, title(1~300), title_optimized(≤100), brand, origin_country, is_health_food, health_food_status, is_overseas, source_price/currency, sell_price_krw(10원 단위), stock(999), images(jsonb 배열), attributes, tags, banned_words_found, status(active/archived), deleted_at | `products_source_uniq`(org, supplier, ref), 상품 수 트리거 | 콘텐츠 컬럼만(컬럼 GRANT) | `:170-210`, 트리거 `:216-250` |
| `detail_pages` | AI 상세페이지 | product_id, version, page_type(8종 CHECK, MVP 3종은 서버 게이팅), slot_set(10/15), slots(18코드 부분집합, T-1·L-3 포함, 3~18개), template, target_markets, status, progress, current_phase(8단계), credits_charged, credit_ledger_id, job_id, request_id(unique), copy, html_content(sanitize), compliance_verdict/issues, warn_acknowledged_at/by, cancel_requested_at, error_* | 복합 FK → products cascade | 없음(WARN 확인 RPC만) | `:253-298` |
| `detail_page_slots` | 슬롯별 생성 상태 | slot_code(18), position, render_method(cutout/ai_scene/infographic/legal), status, copy_ko, image_prompt_en, template_data, master_path, provider_request_id(unique, fal), model, attempts | unique(page, slot) | 없음 | `:307-332` |
| `market_images` | 마켓별 변환본 | market(9), kind(thumbnail/detail), part_no, storage_path, width/height/bytes/format, validation | unique(page, market, slot, kind, part) | 없음 | `:339-358` |
| `market_accounts` | 마켓 다계정 슬롯 | market, slot_no, label, credential_id → `core.encrypted_credentials`, vendor_id(비밀 아님), status, last_verified_at, last_error | unique(org, market, slot_no), 슬롯·자격증명 트리거 | 없음 | `:364-382`, `:385-421` |
| `shipping_templates` | 배송·반품 템플릿 | name, template_type, shipping(jsonb, 마켓별), dispatch_days(1~30), return_window_days(7~90), exchange_allowed(기본 true), return_fee_krw, initial_shipping_fee_krw, restriction_codes(4코드만), return_address, contact_phone, is_default | 조직당 기본 1개 | 전체(콘텐츠) | `:426-447` |
| `listing_drafts` | 마켓 등록 폼 | product_id, detail_page_id, market, market_account_id, shipping_template_id, category_code/path, display_name, form_data, notice_info, completeness_pct, missing_fields, status | 복합 FK 4개, 상품 x 계정 활성 1개 | 콘텐츠 컬럼만(status·completeness 제외) | `:455-485` |
| `market_uploads` | 업로드 이력 | listing_draft_id, product_id, detail_page_id, market, market_account_id, job_id, status, market_product_id, market_url, request_snapshot(비밀 제외), response_summary, error_*, attempts, idempotency_key(unique), submitted_at, decided_at | `(market_account_id, market_product_id)` unique, 게이트 트리거 | 없음 | `:494-527`, 게이트 `:534-568` |
| `export_files` | 엑셀/ZIP | kind, market, product_ids[], detail_page_ids[](각 ≤500), status, storage_path(exports 버킷), file_bytes, row_count, expires_at, job_id | 게이트 트리거 | 없음 | `:572-613` |
| `banned_words` | 금지어 사전 | org_id(null=기본), word(1~50), category, match_mode, severity(fail/warn), replacement, is_active | 기본: unique(category, word), 조직: unique(org, category, word) | 조직 행만 owner/admin | `:618-634`, 기본 21행 `:977-999` |
| `exchange_rates` | 환율 캐시(전역) | currency(5), unit, rate_krw, source, rate_date(date), fetched_at | unique(currency, rate_date) | 없음 | `:642-651` |
| `market_categories` | 마켓 카테고리(전역) | market, category_code, parent_code, name, path, depth, is_leaf, notice_type | pk(market, code) | 없음 | `:653-664` |

비밀값 컬럼은 없다. 마켓 키는 `core.encrypted_credentials`(provider `coupang_wing`, `naver_commerce`)에만 있다.

## 3. 상태 전이

전이는 `commerce.commerce_status_guard()` 트리거가 `commerce_transition_allowed()` 표(`:69-101`)로 강제한다. service_role 쓰기에도 적용되며 위반은 CM001.

| 테이블 | 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|---|
| detail_pages | (신규) | waiting | 생성 Route Handler | 크레딧 선차감, ledger 기록 |
| | waiting | queued, canceled | 디스패처 / 취소 API | queued: `enqueue_job(credit_ledger_id)`. canceled: `refund_credits` |
| | queued | generating, canceled, failed | 워커 / 취소 API(`cancel_job` 환불) | |
| | generating | ready, failed, canceled | 워커 | failed: `fail_job` 자동 환불. canceled: `cancel_requested_at` 확인 후 |
| | ready | archived | 서버 | |
| | archived | ready | 서버 | |
| | failed | waiting | 재시도 API | 새 차감 |
| detail_page_slots | (신규) pending | generating, skipped, failed | 워커 | skipped: L-1인데 health_food_status unknown 등 |
| | generating | completed, failed | 워커 | |
| | failed, completed | generating | 재생성 | 1/3크레딧 |
| import_batches | uploaded | parsing, failed | 워커 | |
| | parsing | completed, failed | 워커 | |
| listing_drafts | draft | ready, archived | 서버(완성도 100이면 ready) | |
| | ready | draft, archived | 서버 | |
| | archived | draft | 서버 | |
| market_uploads | queued | validating, canceled, failed | 워커 | INSERT 시 게이트(CM004~CM008) |
| | validating | uploading, failed | 워커 | |
| | uploading | submitted, failed | 워커 | |
| | submitted | approved, rejected, failed | 폴링 크론 | decided_at |
| | failed, rejected | queued | 재시도 API | |
| export_files | queued | running, canceled, failed | 워커 | |
| | running | succeeded, failed | 워커 | expires_at = +7일 |
| | succeeded | expired | 만료 크론 | 파일 삭제 |

## 4. RLS 정책

모든 13개 테이블 RLS ON(`:790-802`). 테이블 GRANT는 먼저 `revoke all ... from public, anon, authenticated` 뒤 필요한 것만(`:804-812`).

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| import_batches, detail_pages, detail_page_slots, market_images, market_accounts, market_uploads, export_files | `is_org_member(org_id) and has_entitlement(org_id,'commerce')` | 없음 | 없음 | 없음 | select. 이중 잠금 `guard_privileged_write` |
| products | 같음 | with check `has_org_role(owner,admin,member) and has_entitlement` | using/with check 같음 | owner/admin | select, delete, 컬럼 insert(20개), 컬럼 update(콘텐츠 + status, deleted_at) |
| shipping_templates | 같음 | 같음 | 같음 | owner/admin | select, delete, 컬럼 insert/update(org_id 제외) |
| listing_drafts | 같음 | 같음 | 같음 | owner/admin | select, delete, 컬럼 insert/update(status, completeness_pct, missing_fields 제외) |
| banned_words | `org_id is null or (멤버 and 엔타이틀먼트)` | `org_id is not null and has_org_role(owner,admin) and has_entitlement` | 같음(조직 행만) | 조직 행 owner/admin | select, delete, 컬럼 insert/update |
| exchange_rates, market_categories | `true`(로그인 사용자) | 없음 | 없음 | 없음 | select. 이중 잠금 |

쓰기 정책을 준 4개 테이블은 `DB_CONVENTIONS.md` 8.1 조건을 만족한다: 돈·권한·상태 전이 결과 컬럼이 없거나 컬럼 GRANT로 막았다(products의 banned_words_found, listing_drafts의 status/completeness는 서버 전용). 한도는 트리거가 강제한다. `FOR ALL` 정책 없음. 정책 안에서 `org_members` 직접 조회 없음.

함수 EXECUTE(`:935-955`): PUBLIC 전역 기본 EXECUTE를 `revoke execute on all functions in schema commerce`로 회수한 뒤(core 0007과 같은 규칙) `acknowledge_compliance_warning`만 authenticated, `commerce_transition_allowed`는 트리거 호출용으로 authenticated(데이터 접근 없는 immutable), 나머지는 service_role 또는 트리거 전용. 모든 DEFINER 함수는 `set search_path = ''`.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `products_org_created_idx (org_id, created_at desc) where deleted_at is null` | 상품DB 목록 |
| `products_source_uniq (org_id, source_supplier, source_ref)` | 가져오기 중복 방지 |
| `detail_pages_org_created_idx`, `detail_pages_product_idx (product_id, version desc)` | 목록, 상품별 최신 페이지 |
| `detail_pages_waiting_idx (org_id, created_at) where status='waiting'` | 디스패처 5초 주기 |
| `detail_page_slots_page_idx (detail_page_id, position)` | 뷰어 |
| `market_uploads_org_created_idx`, `market_uploads_submitted_idx (updated_at) where status='submitted'` | 이력, 폴링 |
| `export_files_expiry_idx (expires_at) where status='succeeded'` | 만료 크론 |
| `listing_drafts_org_updated_idx` | 폼 목록 |
| unique 제약 | `(org_id, id)` 복합 FK 대상 |

상품 수·슬롯 한도 트리거는 `pg_advisory_xact_lock(hashtext('commerce:products:<org>'))`로 직렬화한다. 2,000행 조직에서 count는 인덱스 범위 스캔.

## 6. 코어 참조

| 코어 객체 | 용도 |
|---|---|
| `core.organizations` | 모든 테넌트 FK |
| `core.is_org_member`, `has_org_role`, `has_entitlement`, `is_service_caller`, `is_privileged_session`(트리거), `set_updated_at`, `guard_privileged_write`, `write_audit` | 정책, 트리거, RPC |
| `core.app_entitlements`, `core.plans` | features 조회(`commerce_features`) |
| `core.jobs` | job_id FK, 진행률 Realtime |
| `core.credit_ledger` | detail_pages.credit_ledger_id |
| `core.encrypted_credentials` | market_accounts.credential_id |
| `core.apps` | 'commerce' 등록(`:31-32`) |
| Storage `org-files`, `exports` | 경로 `<org_id>/commerce/<entity>/<uuid>.<ext>` |

`core.*` ALTER 없음. 플랜·크레딧·구독·결제·잡 테이블을 commerce 스키마에 다시 만들지 않았다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

보안·데이터 17건을 다룬다.

비보안 5건은 `02_ARCHITECTURE.md` 6절. 합계 22.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #2 | `docs/reviews/Nomad-AI-Factory_V.2.md:45` | 플랜 한도·동시성이 클라이언트 상수 | 크레딧: Route Handler가 `core.consume_credits` 선차감(`migrations/0003_core_credits.sql:130-198`). 한도: 트리거 `products_enforce_quota`(`1400_commerce.sql:216-250`, CM002), `market_accounts_enforce`(`:385-421`, CM003), `market_uploads_gate`(`:534-568`, CM007), `export_files_gate`(`:596-613`). 동시성: 디스패처. 스모크 테스트에서 31번째 상품 CM002 확인 | CM-06-010, CM-06-003 |
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #3 | `docs/reviews/Nomad-AI-Factory_V.2.md:46` | 단일 env 마켓 키, `_enc` 암호화 방식 미정 | 셀러별 키를 `core.encrypted_credentials`(AES-256-GCM, `key_version`, `migrations/0004_core_security.sql:604-623`)에, `market_accounts.credential_id`로 연결. 다른 조직·앱 자격증명 연결은 CM006(`:385-421`). env 마켓 키 없음(02장 8절) | CM-06-009 |
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #4 | `docs/reviews/Nomad-AI-Factory_V.2.md:47` | `user_id = auth.uid()` 공통 정책 불성립, WITH CHECK·역할 보호 없음 | org 기준 정책 + 모든 쓰기 정책 with check, 전역 테이블 읽기 전용, 역할·플랜은 core 컬럼 보호(`migrations/0004_core_security.sql:187-231`). 4절 표. 스모크: 자기 플랜/역할/지갑 변경 42501 | 4절, CM-06-003 |
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #5 | `docs/reviews/Nomad-AI-Factory_V.2.md:48` | 리뷰형 AI 후기·평점, 랜딩 허위 수치 | `page_type` MVP 3종만 서버 허용, 리뷰형은 실제 리뷰 입력 테이블이 생길 때까지 생성 불가. 프롬프트·템플릿에 후기 생성 없음. 랜딩 카피는 01장 6절 금지 목록 통과(CM-06-032 수용 기준) | 01장 CM-F-027, CM-06-013, CM-06-032 |
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #6 | `docs/reviews/Nomad-AI-Factory_V.2.md:49` | 반품 불가 자동 삽입, 건기식 부정 문구 자동 삽입 | `shipping_templates` CHECK: 청약철회 7일 이상, 제한 사유 4개 법정 코드만(`:426-447`, 자유 문구 불가). L-1 슬롯은 `products.health_food_status`가 unknown이면 skipped, "건강기능식품이 아닙니다" 자동 문구 없음. 문안은 법률 검토 | CM-06-033, CM-06-015 |
| `docs/reviews/nomad-ai-factory.md` 3장 #1 | `docs/reviews/nomad-ai-factory.md:57` | 인증 없는 공개 AI 프록시, CORS `*` | Express 프록시 폐기. LLM은 Route Handler(`requireSession`)와 워커에서만 core llm gateway로 호출. 레이트 리밋 조직당 60회/분 | 04장 1절, CM-06-011 |
| `docs/reviews/nomad-ai-factory.md` 3장 #2 | `docs/reviews/nomad-ai-factory.md:58` | 한도·사용량 기록이 클라이언트 | 사용량 원장은 core `credit_ledger`(append-only), 브라우저 INSERT 42501(스모크 확인). 한도는 트리거 | CM-06-010 |
| `docs/reviews/nomad-ai-factory.md` 3장 #3 | `docs/reviews/nomad-ai-factory.md:59` | 14개 서비스 키 localStorage 평문 | BYOK 기능 없음(07장 폐기). 외부 키는 플랫폼 env(AI) 또는 `encrypted_credentials`(마켓)만. 브라우저에 키 미전달 | CM-06-009 |
| `docs/reviews/nomad-ai-factory.md` 3장 #4 | `docs/reviews/nomad-ai-factory.md:60` | 스키마·RLS가 저장소에 없어 재현 불가 | 조각 1개 + 모놀리스 변환본 + seed, PGlite 체커 OK, RLS 스모크 60/59항목 통과(9절) | 9절, CM-06-001 |
| `docs/reviews/nomad-ai-commerce.md` 3장 #1 | `docs/reviews/nomad-ai-commerce.md:58` | 쿠키로 인증·관리자 통과 | 역할은 `core.org_members.role`·`profiles.platform_role`만, `session_context`로 서버 판정. 모의 로그인 없음 | CM-06-007 |
| `docs/reviews/nomad-ai-commerce.md` 3장 #2 | `docs/reviews/nomad-ai-commerce.md:59` | 사용자 URL SSRF, raw_html 저장 | 아마존은 ASIN만 추출하고 서버가 URL을 fetch하지 않음. URL 벤치마킹은 `packages/commerce-net`(허용 도메인, 사설 IP·메타데이터 IP 차단, 리다이렉트 3회, 2MB, 10초). 원문 HTML 컬럼 없음 | CM-06-008, CM-06-018 |
| `docs/reviews/nomad-ai-commerce.md` 3장 #3 | `docs/reviews/nomad-ai-commerce.md:60` | 인증 없는 GET이 전 사용자 키 평문 반환 | `market_accounts`에 비밀 컬럼 없음, 사용자는 RLS 하 자기 조직만, 요약은 `credential_summaries`(암호문 제외). 키 입력 API는 owner/admin + 응답 마스킹 | CM-06-009 |
| `docs/reviews/nomad-ai-commerce.md` 3장 #6 | `docs/reviews/nomad-ai-commerce.md:63` | 요청 바디 `tableName`으로 임의 테이블 insert | 블로그 원고 기능 제거(확정 결정 1). 테이블 이름을 요청에서 받는 API 없음. service_role 쓰기는 고정 테이블만, 서버 전용 테이블은 guard 트리거 | 07장, CM-06-020 |
| `docs/reviews/sellingstudio.md` 3장 #1 | `docs/reviews/sellingstudio.md:58` | 생성 라우트 6개가 크레딧 미확인 | 생성·AI 라우트는 전부 자기 안에서 `consume_credits` → 작업 → 실패 환불(`withCredits`). 별도 차감 API 없음 | CM-06-010, CM-06-011 |
| `docs/reviews/sellingstudio.md` 3장 #2 | `docs/reviews/sellingstudio.md:59` | SELECT 후 UPDATE 비원자 차감 | core `consume_credits`(지갑 `FOR UPDATE`, 멱등 키, `migrations/0003_core_credits.sql:160-194`)만 사용 | CM-06-010 |
| `docs/reviews/sellingstudio.md` 3장 #3 | `docs/reviews/sellingstudio.md:60` | 이미지 모델을 바디 `plan`으로 결정 | 모델은 워커가 `features.image_quality`(엔타이틀먼트 기준)로 결정. 잡 payload의 image_quality도 서버가 채움 | CM-06-014 |
| `docs/reviews/sellingstudio.md` 3장 #4 | `docs/reviews/sellingstudio.md:61` | fal webhook 무검증 + `USING(true)` UPDATE 정책 | fal 웹훅은 URL 토큰 + request_id 대조 + `webhook_events` 멱등. 슬롯 테이블에 사용자 쓰기 정책 없음 + guard 트리거(`:697-698`) | CM-06-025, CM-06-003 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 파일 | `_supabase-modular/migrations/1400_commerce.sql` | `supabase/monolith/migrations/0001_core_lite.sql`, `0002_commerce_domain.sql`, `seed.sql` |
| 스키마 | `commerce` | `public`(사용자 최종 확인 대기) |
| 코어 | `core` 0000~0006 | `MONOLITH_CORE_LITE.sql` 복사본. SECTION 9(affiliate)만 제거: commerce는 제휴 링크를 쓰지 않음(확정 결정 12). 3(Toss), 4(크레딧), 6-A(OAuth, Phase 2 SNS), 6-B(자격증명), 6-C(레이트 리밋), 7(jobs), 8(Storage) 유지 |
| 앱 등록 | 조각 머리 `insert into core.apps` | `seed.sql` apps 1행(가입 시 자동 부트스트랩) |
| 플랜 | 모듈러 `seed.sql`(2026-10-13 모놀리스 seed와 일치) | `seed.sql`이 01장 4.1과 동일 |
| 크레딧팩 | 모듈러 seed에 commerce 팩 3개(2026-10-13 반영) | `seed.sql` 3개 |
| 변환 | - | HEADER 블록 제거, `core.`/`commerce.` → `public.`, Realtime `schemaname` 치환(CM-06-002 스크립트) |
| PostgREST | `config.toml [api].schemas`에 `commerce` 추가, 타입 `--schema core,commerce` | 기본 |

## 9. 마이그레이션 파일

| 파일 | 줄 수 | 내용 |
|---|---|---|
| `_supabase-modular/migrations/1400_commerce.sql` | 1007 | 헬퍼 5개, 테이블 13개, 트리거, RPC 1개, RLS, Realtime, 기본 금지어 21행 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 2476 | 코어 lite(affiliate 절 제거) |
| `supabase/monolith/migrations/0002_commerce_domain.sql` | 985 | 조각 변환본. 스키마 전체 함수 회수 줄은 제거(public 전체에 적용되면 코어 권한이 사라짐), 함수별 회수와 0001 SECTION 10으로 대체 |
| `supabase/monolith/seed.sql` | 39 | apps 1행, 플랜 4개, 크레딧팩 3개 |

검증(2026-10-12, PGlite `_tools-sqlcheck`):

| 검사 | 결과 |
|---|---|
| `node check.mjs mod` 0000~0007 + seed + 1400 | 전부 OK(조각 2회 연속 적용도 OK) |
| `node check.mjs mono` 0001 + 0002 + seed | 전부 OK |
| RLS 스모크 모듈러 | 60/60 통과 |
| RLS 스모크 모놀리스 | 59/59 통과 |

스모크 항목: 비멤버 B가 A 조직 commerce 테이블 10개 + 조직 금지어 SELECT 0행, A 조직으로 INSERT 42501, A 행 UPDATE/DELETE 0행, 서버 전용 테이블 INSERT 42501(자기 조직 포함), 기본 금지어·환율 쓰기 거부, A 페이지 WARN 확인 RPC 42501, `commerce_features` 42501, 자기 지갑·원장·`grant_credits`·엔타이틀먼트 plan·`platform_role`·org_members role 변경 42501, `encrypted_credentials` SELECT 42501, 서버 컬럼(banned_words_found, listing status/completeness) UPDATE 42501, org_id 이동 42501, 다른 조직 상품 참조 23503, 반품 7일 미만·자유 제한 사유 23514, Free 31번째 상품 CM002, 엔타이틀먼트 없는 조직 INSERT 42501, 서버 경로 CM001/CM003/CM004/CM005/CM006/CM007/CM009와 필수 슬롯 23514, WARN 확인 후 업로드 성공과 감사 행. 모듈러 seed 샘플 free 플랜은 `market_api`가 없어 업로드가 CM007로 막힘을 확인한 뒤, 01장 정본 features로 갱신(요청 반영 가정)하고 나머지를 실행했다.
