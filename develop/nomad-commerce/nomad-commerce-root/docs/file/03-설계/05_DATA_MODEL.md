# 05 데이터 모델: NOMAD Commerce

정본 SQL: `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1400_commerce.sql`(이하 "조각"). 모놀리스 `supabase/monolith/migrations/0002_commerce_domain.sql`은 조각의 기계 변환본이다.

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

AI·음성(2026-10-13)은 코어 표만 참조하고 제품 AI 표를 만들지 않는다(이유는 6절):

```
core AI·음성 (참조만)
 ├─ core.ai_conversations   (사용자 본인, dify_user, channel text/voice, 대화 시작 때 바인딩한 상품·상세페이지·업로드는 Dify 입력 변수와 FastAPI 대조로만)
 │    ├─ core.ai_messages   (citations, provider, credits)
 │    └─ core.voice_sessions ─ core.voice_jobs (feature voice_chat / product_voice / shorts_narration, store_audio=false)
 ├─ core.ai_runs            (graph commerce.detail_page: job_id = detail_pages.job_id, credit_ledger_id = detail_pages.credit_ledger_id / graph commerce.assist)
 │    └─ core.ai_run_steps  (노드 extract, retrieve, copy, banned_check, convert, compliance / input_check, generate, validate, compliance)
 ├─ core.ai_usage           (run_id, conversation_id, feature, settled_at)
 ├─ core.ai_org_settings    (국외 이전 동의, 증빙은 감사 ai.cross_border.ack/revoke)
 ├─ 셀러 조직: core.ai_collections commerce-products(kind rag, oss-embed) ─ core.ai_documents ─ core.ai_chunks (vector(1024), HNSW)
 ├─ 운영자 지식 조직(COMMERCE_KNOWLEDGE_ORG_ID)만
 │    ├─ core.ai_collections commerce-rules(kind rag), commerce-wiki(kind wiki), 임베딩 oss-embed
 │    │    └─ core.ai_documents ─ core.ai_chunks
 │    └─ core.wiki_pages ─ core.wiki_links, core.wiki_revisions
 └─ core.ai_routing_settings (org null, app commerce, 14행: 9절)
Storage exports/<org_id>/commerce/narration/<product_id>/<hash16>.mp3 (쇼츠 내레이션, 상품 purge 때 함께 삭제)
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
| `export_files` | 엑셀/ZIP | kind, market, product_ids[], detail_page_ids[] (각 ≤500), status, storage_path(exports 버킷), file_bytes, row_count, expires_at, job_id | 게이트 트리거 | 없음 | `:572-613` |
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

AI·음성 코어 객체(2026-10-13, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | commerce 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 셀러 어시스턴트 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `commerce.detail_page`·`commerce.assist` 실행 기록, 위키 lint 결과 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, Next.js 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 14행(9절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의와 고지문 버전, 감사 행 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 마켓 규칙 컬렉션(운영자 조직), 상품 스펙 컬렉션(셀러 조직) | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 마켓 규칙 위키(운영자 조직만) | FastAPI(쓰기), Next.js 서버(공개 읽기) |
| `voice_sessions`, `voice_jobs` | 음성 대화, 상품 설명 STT, 쇼츠 내레이션 TTS | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |
| `write_audit` | 음성 처리 고지 확인(`ai.voice_notice.ack`) 증빙 | Next.js(service_role) |

제품 AI 표를 만들지 않은 이유(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 대화-대상 연결 표 | 채팅이 어느 상품·상세페이지·업로드를 근거로 하는지 | Dify 입력(대화 시작 때 `product_id`/`detail_page_id`/`upload_id`) + FastAPI가 매핑 org와 대상 org를 매번 대조. 대체 경로는 Next.js가 요청마다 바인딩 id를 받아 같은 확인 |
| 내레이션 파일 표 | 쇼츠 음성 파일 위치와 재사용 | 결정적 Storage 경로 `exports/<org_id>/commerce/narration/<product_id>/<hash16>.mp3`(`hash16` = 스크립트·보이스·제공자 해시 앞 16자) + `voice_jobs`(feature `shorts_narration`, `characters`, `provider_id`, `storage_path`). 목록은 `voice_jobs` 본인 행 |
| 상세페이지-그래프 연결 컬럼 | 상세페이지의 AI 실행 추적 | `ai_runs.job_id = detail_pages.job_id`, `ai_runs.credit_ledger_id = detail_pages.credit_ledger_id` |
| 동의 표(`consents`) | 국외 이전·음성 처리 고지 증빙 | 국외 이전은 `core.ai_org_settings`(고지문 버전) + 감사 `ai.cross_border.ack/revoke`, 음성 처리 고지는 감사 `ai.voice_notice.ack`. 녹음을 저장하지 않으므로 `voice_jobs.consent_*`는 비워 둔다 |
| 상품 스펙 문서 표 | 상품별 색인 상태 | `core.ai_documents`(셀러 조직 컬렉션 `commerce-products`, 문서 메타데이터에 `product_id`). 상품 삭제 purge가 이 문서를 함께 지운다(CM-06-048) |
| 규칙 원고 표 | 원고 관리 | `core.ai_documents`(운영자 지식 조직) + 원고 파일 `content/knowledge/` |
| 챗 바인딩 대상 FK | 다른 조직 대상 참조 차단 | 표가 없으므로 FK 대신 FastAPI의 org 대조와 테스트(CM-06-057) |

조각은 `core.*`를 ALTER하지 않는다. 플랜·크레딧·결제·잡 테이블을 `commerce`에 다시 만들지 않는다. 조각 20.2절의 `core.plans` UPDATE는 commerce 자신의 플랜 행 `features`에 AI 키를 병합하는 데이터 변경이며 표 구조는 바꾸지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

보안·데이터 17건을 다룬다.

비보안 5건은 `02_ARCHITECTURE.md` 6절. 합계 22.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reference/reviews/Nomad-AI-Factory_V.2.md` 3장 #2 | `docs/reference/reviews/Nomad-AI-Factory_V.2.md:45` | 플랜 한도·동시성이 클라이언트 상수 | 크레딧: Route Handler가 `core.consume_credits` 선차감(`migrations/0003_core_credits.sql:130-198`). 한도: 트리거 `products_enforce_quota`(`1400_commerce.sql:216-250`, CM002), `market_accounts_enforce`(`:385-421`, CM003), `market_uploads_gate`(`:534-568`, CM007), `export_files_gate`(`:596-613`). 동시성: 디스패처. 스모크 테스트에서 31번째 상품 CM002 확인 | CM-06-010, CM-06-003 |
| `docs/reference/reviews/Nomad-AI-Factory_V.2.md` 3장 #3 | `docs/reference/reviews/Nomad-AI-Factory_V.2.md:46` | 단일 env 마켓 키, `_enc` 암호화 방식 미정 | 셀러별 키를 `core.encrypted_credentials`(AES-256-GCM, `key_version`, `migrations/0004_core_security.sql:604-623`)에, `market_accounts.credential_id`로 연결. 다른 조직·앱 자격증명 연결은 CM006(`:385-421`). env 마켓 키 없음(02장 8절) | CM-06-009 |
| `docs/reference/reviews/Nomad-AI-Factory_V.2.md` 3장 #4 | `docs/reference/reviews/Nomad-AI-Factory_V.2.md:47` | `user_id = auth.uid()` 공통 정책 불성립, WITH CHECK·역할 보호 없음 | org 기준 정책 + 모든 쓰기 정책 with check, 전역 테이블 읽기 전용, 역할·플랜은 core 컬럼 보호(`migrations/0004_core_security.sql:187-231`). 4절 표. 스모크: 자기 플랜/역할/지갑 변경 42501 | 4절, CM-06-003 |
| `docs/reference/reviews/Nomad-AI-Factory_V.2.md` 3장 #5 | `docs/reference/reviews/Nomad-AI-Factory_V.2.md:48` | 리뷰형 AI 후기·평점, 랜딩 허위 수치 | `page_type` MVP 3종만 서버 허용, 리뷰형은 실제 리뷰 입력 테이블이 생길 때까지 생성 불가. 프롬프트·템플릿에 후기 생성 없음. 랜딩 카피는 01장 6절 금지 목록 통과(CM-06-032 수용 기준) | 01장 CM-F-027, CM-06-013, CM-06-032 |
| `docs/reference/reviews/Nomad-AI-Factory_V.2.md` 3장 #6 | `docs/reference/reviews/Nomad-AI-Factory_V.2.md:49` | 반품 불가 자동 삽입, 건기식 부정 문구 자동 삽입 | `shipping_templates` CHECK: 청약철회 7일 이상, 제한 사유 4개 법정 코드만(`:426-447`, 자유 문구 불가). L-1 슬롯은 `products.health_food_status`가 unknown이면 skipped, "건강기능식품이 아닙니다" 자동 문구 없음. 문안은 법률 검토 | CM-06-033, CM-06-015 |
| `docs/reference/reviews/nomad-ai-factory.md` 3장 #1 | `docs/reference/reviews/nomad-ai-factory.md:57` | 인증 없는 공개 AI 프록시, CORS `*` | Express 프록시 폐기. LLM 호출은 FastAPI 라우터에서만 하고(서명 토큰 필수, 키는 FastAPI 전용), Route Handler(`requireSession`)가 토큰을 발급하며 워커는 잡 토큰만 받는다. 레이트 리밋 조직당 60회/분 | 04장 1절, CM-06-011 |
| `docs/reference/reviews/nomad-ai-factory.md` 3장 #2 | `docs/reference/reviews/nomad-ai-factory.md:58` | 한도·사용량 기록이 클라이언트 | 사용량 원장은 core `credit_ledger`(append-only), 브라우저 INSERT 42501(스모크 확인). 한도는 트리거 | CM-06-010 |
| `docs/reference/reviews/nomad-ai-factory.md` 3장 #3 | `docs/reference/reviews/nomad-ai-factory.md:59` | 14개 서비스 키 localStorage 평문 | BYOK 기능 없음(07장 폐기). 외부 키는 플랫폼 env(AI) 또는 `encrypted_credentials`(마켓)만. 브라우저에 키 미전달 | CM-06-009 |
| `docs/reference/reviews/nomad-ai-factory.md` 3장 #4 | `docs/reference/reviews/nomad-ai-factory.md:60` | 스키마·RLS가 저장소에 없어 재현 불가 | 조각 1개 + 모놀리스 변환본 + seed, PGlite 체커 OK, RLS 스모크 60/59항목 통과(9절) | 9절, CM-06-001 |
| `docs/reference/reviews/nomad-ai-commerce.md` 3장 #1 | `docs/reference/reviews/nomad-ai-commerce.md:58` | 쿠키로 인증·관리자 통과 | 역할은 `core.org_members.role`·`profiles.platform_role`만, `session_context`로 서버 판정. 쿠키 역할 Mock 금지, 개발용 로그인은 AUTH_ROADMAP 2장의 로컬 시드 계정만(실제 JWT, 배포 환경 404, 10절) | CM-06-007 |
| `docs/reference/reviews/nomad-ai-commerce.md` 3장 #2 | `docs/reference/reviews/nomad-ai-commerce.md:59` | 사용자 URL SSRF, raw_html 저장 | 아마존은 ASIN만 추출하고 서버가 URL을 fetch하지 않음. URL 벤치마킹은 `packages/commerce-net`(허용 도메인, 사설 IP·메타데이터 IP 차단, 리다이렉트 3회, 2MB, 10초). 원문 HTML 컬럼 없음 | CM-06-008, CM-06-018 |
| `docs/reference/reviews/nomad-ai-commerce.md` 3장 #3 | `docs/reference/reviews/nomad-ai-commerce.md:60` | 인증 없는 GET이 전 사용자 키 평문 반환 | `market_accounts`에 비밀 컬럼 없음, 사용자는 RLS 하 자기 조직만, 요약은 `credential_summaries`(암호문 제외). 키 입력 API는 owner/admin + 응답 마스킹 | CM-06-009 |
| `docs/reference/reviews/nomad-ai-commerce.md` 3장 #6 | `docs/reference/reviews/nomad-ai-commerce.md:63` | 요청 바디 `tableName`으로 임의 테이블 insert | 블로그 원고 기능 제거(확정 결정 1). 테이블 이름을 요청에서 받는 API 없음. service_role 쓰기는 고정 테이블만, 서버 전용 테이블은 guard 트리거 | 07장, CM-06-020 |
| `docs/reference/reviews/sellingstudio.md` 3장 #1 | `docs/reference/reviews/sellingstudio.md:58` | 생성 라우트 6개가 크레딧 미확인 | 생성·AI 라우트는 전부 자기 안에서 `consume_credits` → 작업 → 실패 환불(`withCredits`). 별도 차감 API 없음 | CM-06-010, CM-06-011 |
| `docs/reference/reviews/sellingstudio.md` 3장 #2 | `docs/reference/reviews/sellingstudio.md:59` | SELECT 후 UPDATE 비원자 차감 | core `consume_credits`(지갑 `FOR UPDATE`, 멱등 키, `migrations/0003_core_credits.sql:160-194`)만 사용 | CM-06-010 |
| `docs/reference/reviews/sellingstudio.md` 3장 #3 | `docs/reference/reviews/sellingstudio.md:60` | 이미지 모델을 바디 `plan`으로 결정 | 모델은 워커가 `features.image_quality`(엔타이틀먼트 기준)로 결정. 잡 payload의 image_quality도 서버가 채움 | CM-06-014 |
| `docs/reference/reviews/sellingstudio.md` 3장 #4 | `docs/reference/reviews/sellingstudio.md:61` | fal webhook 무검증 + `USING(true)` UPDATE 정책 | fal 웹훅은 URL 토큰 + request_id 대조 + `webhook_events` 멱등. 슬롯 테이블에 사용자 쓰기 정책 없음 + guard 트리거(`:697-698`) | CM-06-025, CM-06-003 |

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
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| AI 라우팅 기본값 | `1400_commerce.sql` 20.1절(`:1027-1043`) | `seed.sql`(같은 14행) |
| 플랜 AI 키 | `1400_commerce.sql` 20.2절 병합 UPDATE(`:1045-1051`, 모듈러 `seed.sql` 반영 요청 R-1) | `seed.sql` 플랜 행 `features`에 직접 |
| 체인 검사 | 20.3절 DO 블록(`:1053-1069`, 제공자 행이 없으면 건너뜀) | `seed.sql` 끝 DO 블록(제공자는 0001이 먼저 넣음) |
| PostgREST | `config.toml [api].schemas`에 `commerce` 추가, 타입 `--schema core,commerce` | 기본 |

## 9. 마이그레이션 파일

| 파일 | 줄 수 | 내용 |
|---|---|---|
| `_supabase-modular/migrations/1400_commerce.sql` | 1074 | 헬퍼 5개, 테이블 13개, 트리거, RPC 1개, RLS, Realtime, 기본 금지어 21행, 20절 AI·음성 기본값(라우팅 14행, 플랜 AI 키 병합, 체인 검사) |
| `supabase/monolith/migrations/0001_core_lite.sql` | 2476 | 코어 lite(affiliate 절 제거) |
| `supabase/monolith/migrations/0002_commerce_domain.sql` | 985 | 조각 변환본. 스키마 전체 함수 회수 줄은 제거(public 전체에 적용되면 코어 권한이 사라짐), 함수별 회수와 0001 SECTION 10으로 대체 |
| `supabase/monolith/seed.sql` | 79 | apps 1행, 플랜 4개(AI 키 포함), 크레딧팩 3개, AI 라우팅 기본값 14행 + 체인 검사 |

검증(2026-10-12, PGlite `_tools-sqlcheck`):

| 검사 | 결과 |
|---|---|
| `node check.mjs mod` 0000~0007 + seed + 1400 | 전부 OK(조각 2회 연속 적용도 OK) |
| `node check.mjs mono` 0001 + 0002 + seed | 전부 OK |
| RLS 스모크 모듈러 | 60/60 통과 |
| RLS 스모크 모놀리스 | 59/59 통과 |

2026-10-13 재검증(PGlite `--vector`, `D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs`):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `1400_commerce.sql` | 전부 OK (조각 2회 연속 적용도 OK) |
| `check.mjs --vector mono` 0001 + 0002 + `seed.sql` | 전부 OK (seed 2회 연속 적용도 OK) |
| 제품 파일 2회 반복 적용 후 `ai_routing_settings`(org null, app commerce) | 14행(모듈러·모놀리스) |
| 플랜 `features` | free(`ai_chat` true, 20턴, `voice_chat` false, `shorts_narration` false), starter·pro(true, 200, true, true), enterprise(true, 500, true, true). 기존 `voice_input` 유지 |
| 미동의 조직 `resolve_ai_route` | `commerce.detail_page`·`commerce.compliance`·`commerce.assist`·`commerce.vision`·`chat` = oss-llm, `commerce.knowledge` = oss-embed, `voice_chat`·`product_voice` stt·tts = oss-voice, `shorts_narration` = oss-voice |
| 동의 후 | `commerce.detail_page` = anthropic → openai → google → oss-llm, `commerce.assist` = google → openai → oss-llm, `chat` = openai → google → anthropic → oss-llm, `shorts_narration` = elevenlabs → oss-voice, `dify.aux`는 계속 oss-llm(강제), `Wiki.Lint`(대소문자·공백)도 `wiki.lint` 행으로 해석 |
| 잘못된 체인 행(tts 기능에 anthropic) 뒤 20절 재적용 | `commerce routing defaults: invalid chain providers` 예외 |
| RLS 스모크 | 테이블 변경이 없어 재실행하지 않았다(2026-10-12 결과 유지) |

AI 기능별 기본값 행(정본 02장 5.1절): `commerce.detail_page`(llm, auto, anthropic → openai → google → oss-llm), `commerce.compliance`(llm, auto, openai → google → oss-llm), `commerce.assist`(llm, auto, google → openai → oss-llm), `commerce.vision`(llm, auto, openai → google → oss-llm), `chat`(llm, auto, openai → google → anthropic → oss-llm), `wiki.query`·`wiki.ingest`·`wiki.lint`(llm, auto, oss-llm → anthropic), `dify.aux`(llm, open_source, oss-llm, 강제), `commerce.knowledge`(embedding, open_source, oss-embed), `voice_chat` stt(auto, oss-voice → elevenlabs), `voice_chat` tts(auto, elevenlabs → oss-voice), `product_voice` stt(auto, oss-voice → elevenlabs), `shorts_narration` tts(auto, elevenlabs → oss-voice, 작업 중 대체 금지는 음성 어댑터).

스모크 항목: 비멤버 B가 A 조직 commerce 테이블 10개 + 조직 금지어 SELECT 0행, A 조직으로 INSERT 42501, A 행 UPDATE/DELETE 0행, 서버 전용 테이블 INSERT 42501(자기 조직 포함), 기본 금지어·환율 쓰기 거부, A 페이지 WARN 확인 RPC 42501, `commerce_features` 42501, 자기 지갑·원장·`grant_credits`·엔타이틀먼트 plan·`platform_role`·org_members role 변경 42501, `encrypted_credentials` SELECT 42501, 서버 컬럼(banned_words_found, listing status/completeness) UPDATE 42501, org_id 이동 42501, 다른 조직 상품 참조 23503, 반품 7일 미만·자유 제한 사유 23514, Free 31번째 상품 CM002, 엔타이틀먼트 없는 조직 INSERT 42501, 서버 경로 CM001/CM003/CM004/CM005/CM006/CM007/CM009와 필수 슬롯 23514, WARN 확인 후 업로드 성공과 감사 행. 모듈러 seed 샘플 free 플랜은 `market_api`가 없어 업로드가 CM007로 막힘을 확인한 뒤, 01장 정본 features로 갱신(요청 반영 가정)하고 나머지를 실행했다.

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경 없음. 인증 단계(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md`)는 코어 계약(`session_context`, RLS, 가입 트리거)을 그대로 쓰고, 이 제품은 테이블·컬럼·RPC를 더하지 않는다. C2 브리지 경로를 택하면 코어 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`(`core.auth_identity_links`)만 참조한다(코어가 1회 적용).

시드는 `supabase db reset` 뒤 `node scripts/dev/seed-users.mjs --app commerce`로 만든다. 로컬 Supabase에서만 동작하고(호스트가 `127.0.0.1`·`localhost`가 아니면 종료), 계정은 실제 가입 트리거(`core.handle_new_user`, `migrations/0001_core_identity.sql:113`)와 실제 RPC로 만든다.

공통 페르소나(`AUTH_ROADMAP.md` 2.2절)를 commerce에 적용한 결과:

| 키 | 만드는 방법 | 기대 `session_context('commerce')` | commerce에서 확인하는 것 |
|---|---|---|---|
| `owner` | `signup_app=commerce` | 개인 조직 owner, `entitled=true`, plan `free`, 월 15크레딧 1회 지급(가입 크레딧 0, 01장 4.1절) | 기본 사용자. CM-F-001 A 수용 기준, 핵심 플로우 E2E(CM-06-035), 국외 이전 미동의 상태(오픈소스 경로) |
| `admin` | owner 조직에 `invite_member(admin)` → `accept_invite` | owner 조직 admin | 마켓 계정·결제 화면 접근(04장 1절 역할) |
| `member` | 같음(member) | owner 조직 member | 생성·편집 가능, 마켓 계정·결제 403 |
| `viewer` | 같음(viewer) | owner 조직 viewer | 읽기만. 생성·편집 API 403, `products` INSERT 42501 |
| `outsider` | `signup_app=commerce`(다른 개인 조직) | 자기 조직 owner | 교차 테넌트: owner 조직의 13개 테이블 SELECT 0행, 다른 조직 `product_id` 채팅 바인딩 403(CM-06-057) |
| `no_app` | `signup_app` 없이 생성 | 모듈러: `entitled=false` → `finishLogin`이 `bootstrap_app_for_org('commerce')` 후 `entitled=true`, free. 모놀리스: 앱 행 1개라 가입 트리거가 자동 부트스트랩해 처음부터 `entitled=true` | OAuth 첫 로그인 부트스트랩 경로(B-1)를 A단계에서 미리 검증. 재로그인 3회 뒤 원장 행 수 같음 |
| `suspended` | 생성 후 service_role로 `status=suspended` | 403 | 차단 화면 |
| `ops` | 생성 후 service_role로 `platform_role=platform_admin` | 운영자 | `/admin/knowledge`, `/admin/wiki`(03장 1절). 로컬에서는 이 계정의 조직 id를 `COMMERCE_KNOWLEDGE_ORG_ID`로 쓴다(제안) |
| `pending` | 만들지 않는다 | - | commerce는 open 앱(`1400_commerce.sql:31`)이라 승인 대기 상태가 없다 |

commerce 도메인 행(제품 훅 `scripts/dev/seed-users.commerce.mjs`, 제안. `AUTH_ROADMAP.md` 8장은 commerce 추가 페르소나를 "-"로 두었고, 아래는 플랜·동의 분기를 E2E로 검증하려고 더하는 제안 행이다):

| 키 | 만드는 방법 | 기대 결과 | 쓰임 |
|---|---|---|---|
| `pro` | `signup_app=commerce` 후 service_role로 그 조직의 `core.subscriptions`·`core.app_entitlements` `plan_id`를 `pro` 플랜으로 바꾸고 `grant_credits(350, bucket 'plan', 멱등 키 'dev:pro:<org>')`(제안. 결제 E2E가 아니라 시드이므로 Toss 경로를 타지 않는다) | plan_code `pro`, `features.concurrency=2`, `voice_input`·`voice_chat`·`shorts_narration` true | 동시 생성 2건 제한(CM-F-023), 플랜 게이팅 기능(음성, 15슬롯, 엑셀) 화면 확인 |
| `ai_consent` | `signup_app=commerce` 후 본인 세션으로 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack: true, p_notice_version: AI_CROSS_BORDER_NOTICE_VERSION })`(`migrations/0008_core_ai.sql:553`) | `ai_org_settings.cross_border_notice` = 현재 버전, 감사 `ai.cross_border.ack` 1행, `resolve_ai_route`가 상용 체인 반환 | 국외 이전 동의 분기(CM-F-049), 상용 경로 평가셋 |

시드 결과의 기대값은 시드 스크립트가 표로 출력하고(비밀번호 제외), 두 번 실행해도 크레딧이 두 번 지급되지 않는다(멱등 키 `signup:<org>:commerce`, `dev:pro:<org>`). 기능 코드는 페르소나 이메일로 분기하지 않는다(권한은 `session_context`로만).

모놀리스와 모듈러의 차이(8절에 더한다): 모듈러 통합 DB는 `--app commerce`를 여러 앱과 함께 줄 수 있고 두 번째 앱부터 `bootstrap_app_for_org`를 호출한다. 모놀리스(이 제품 개발 기본, `public` 스키마)는 앱 행이 1개라 `no_app`도 가입 트리거가 자동 부트스트랩하므로 `finishLogin`의 3번 단계가 아무 일도 하지 않는다(같은 코드를 그대로 쓴다).
