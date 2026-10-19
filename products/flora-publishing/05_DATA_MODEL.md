# 05 데이터 모델: FLORA Publishing

2026-10-13 개정: AI·음성(확정 결정 13~17)은 코어 표(`core.ai_*`, `core.wiki_*`, `core.voice_*`)만 참조하고 제품 AI 표를 만들지 않는다(이유는 6절). 이번 개정의 DB 변경은 `1000_publishing.sql` 15절(AI·음성 라우팅 기본값 12행, free·basic 플랜 AI 키 6개, 체인 검사)뿐이며 표 구조는 바꾸지 않았다.

2026-10-14 FLORA 개편(검토용): 제품 표 `publishing.agent_tasks` 1개와 사용자 RPC `decide_agent_task` 1개를 더했다(2.5절, `1000_publishing.sql` 16절). 실행·원가·검수 기록을 위한 새 실행 이벤트 표, 승인 이력 표, 비용 원장은 만들지 않았다: 실행 단계는 `core.jobs`·`core.ai_run_steps`, 비용은 `core.ai_usage`·`core.credit_ledger`, 결정 이력은 `core.audit_log`가 이미 정본이다(제안서 8절 "기존 모델이 있으면 확장").

작성일 2026-10-12. 정본 SQL은 `docs/products/_supabase-modular/migrations/1000_publishing.sql`(아래 "조각:줄"). 모놀리스 `supabase/monolith/migrations/0002_publishing_domain.sql`은 조각을 변환한 것이다. 규칙은 `docs/products/_platform-core/DB_CONVENTIONS.md`(아래 DBC).

## 1. 개요와 ERD

```
core.organizations (참조만)
 ├── publishing.books ───────────────┬── publishing.chapters ── publishing.sections ──> core.jobs (last_job_id)
 │     ├─> publishing.custom_personas │
 │     ├─> publishing.cover_images ───┘(cover_image_id)          cover_images ──> core.jobs
 │     ├── publishing.book_exports ──> core.jobs, core.credit_ledger
 │     ├── publishing.generation_runs ──> core.jobs (parent_job_id)
 │     ├── publishing.agent_tasks ──> core.jobs, generation_runs, core.ai_runs, core.credit_ledger, agent_tasks(retry_of)  (2026-10-14)
 │     └── publishing.manuscript_uploads (book_id 선택) ──> core.jobs
 ├── publishing.member_settings (org_id, user_id)
 ├── publishing.custom_personas
 └── publishing.webhook_endpoints ──> core.encrypted_credentials
       └── publishing.webhook_deliveries
publishing.waitlist (테넌트 아님)
core AI·음성 (참조만, 6절)
 ├─ core.ai_conversations / ai_messages   (글쓰기 도우미 대화, 본인만 SELECT, books와 DB 연결 없음: book_id는 Dify 입력과 서버 확인)
 ├─ core.ai_collections book-<book_id>(rag), book-<book_id>-wiki(wiki), 임베딩 oss-embed
 │    └─ core.ai_documents ─ core.ai_chunks (vector(1024), HNSW)       <- 참고 파일, 원고 스냅샷(source_type product)
 ├─ core.wiki_pages / wiki_links / wiki_revisions   (slug books/<book_id>/..., 책 설정집)
 ├─ core.ai_runs / ai_run_steps   (graph publishing.draft·publishing.assist, job_id = core.jobs.id, credit_ledger_id)
 ├─ core.ai_usage, ai_org_settings(국외 이전 동의), voice_sessions, voice_jobs
 └─ core.ai_routing_settings (org null, app publishing, 12행: 9절)
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
| `book_info` | jsonb | N | '{}' | 부제, 키워드 5, 소개 200자, 출판사, `isbn_reference`, `ai_open_source_only`(boolean, 기본 없음 = false. 책 단위 오픈소스 전용 AI 스위치, 01장 PB-F-056·D12. 서버가 책 정보 생성 결과를 병합할 때 이 키를 덮어쓰지 않는다. D12에서 전용 컬럼으로 승격하면 PB-06-001 후속 마이그레이션) |
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

### 2.5 agent_tasks (2026-10-14, 조각 16절)

목적: 에이전트 작업 1건(사용자 요청 1건) = 행 1개. 실행·검수·재시도·원가 추적의 기준 id. 서버만 쓴다.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | N | `gen_random_uuid()` | PK |
| `org_id` | uuid | N | - | 조직 |
| `book_id` | uuid | Y | - | `(book_id, org_id)` → books, cascade. 페르소나 합성처럼 책 없는 동작은 null |
| `agent_key` | text | N | - | planning, research, writing, editing, publishing, content |
| `action` | text | N | - | 레지스트리 동작 키(`^[a-z][a-z0-9_]{1,40}$`, 02장 10.1절) |
| `origin` | text | N | 'workspace' | workspace, wizard, editor, admin_retry |
| `status` | text | N | 'queued' | queued, running, succeeded, partial, failed, canceled |
| `approval_status` | text | N | 'not_required' | not_required, pending, approved, partially_applied, rejected, expired |
| `approval_decided_by`, `approval_decided_at`, `approval_note` | uuid, timestamptz, text(500) | Y | - | 결정 3종이면 `decided_at` 필수(CHECK) |
| `input_summary`, `result_summary` | jsonb | N | '{}' | 범위 id·개수, 결과 id 목록(`saved`, `suggested`, `failed`, 취소 시 `remaining`). 원고 본문·프롬프트 금지 |
| `job_id` | uuid | Y | - | → core.jobs, set null |
| `generation_run_id` | uuid | Y | - | → generation_runs, set null |
| `ai_run_id` | uuid | Y | - | → core.ai_runs, set null |
| `credit_ledger_id` | bigint | Y | - | → core.credit_ledger, 첫 차감 행(표시용). 작업의 전체 원장은 `credit_ledger.ref_type='agent_task'`, `ref_id=<id>`로 묶는다(차감이 소제목마다 여러 행일 수 있다) |
| `credits_estimated`, `credits_used` | integer | N | 0 | 0 이상 |
| `request_id` | text | N | - | 8~64자. `unique(org_id, request_id)` 멱등 |
| `retry_of` | uuid | Y | - | → agent_tasks, set null(원래 행 삭제 때만 null로 바뀔 수 있다). 부분 유니크(재시도 1회) |
| `attempt` | smallint | N | 1 | 1~10. 첫 작업은 1, 재시도는 원래 + 1(트리거). `origin='admin_retry'`면 `retry_of` 필수 |
| `error_code`, `error_message` | text | Y | - | 64자, 500자(사용자에게 보여도 되는 문장만) |
| `requested_by` | uuid | Y | - | FK 없음(DBC 3장) |
| `created_at`, `started_at`, `finished_at`, `updated_at` | timestamptz | - | - | 전이 트리거가 시각 기록 |

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
| agent_tasks.status(2026-10-14) | queued | running, canceled, failed | 서버 | started_at | 트리거 `agent_tasks_transition`(조각 16절) |
| | running | succeeded, partial, failed, canceled | 서버 | finished_at | 같음 |
| agent_tasks.approval_status | not_required | pending(상태가 succeeded·partial·canceled일 때만) | 서버 | - | 같음 |
| | pending | approved, partially_applied, rejected(사용자 RPC `decide_agent_task`), expired(서버, 30일) | 사용자·서버 | approval_decided_at, 감사 `agent_task.decide` | 같음 + RPC |
| agent_tasks 신원 컬럼 | - | 변경 불가(org, book, agent, action, request_id, retry_of, attempt, origin). 예외: 원래 행 삭제 시 FK가 `retry_of`를 null로 | - | 위반 22023 | 같음 |
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
| agent_tasks(2026-10-14) | 멤버 + 엔타이틀먼트 | 없음 | 없음(결정은 RPC) | 없음 | select. + guard. INSERT 트리거가 재시도 규칙(`PB013`)과 시작 상태를 강제 |
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
| `agent_tasks_org_created_idx`, `agent_tasks_book_created_idx` | 실행 이력(조직·책별 최근순) |
| `agent_tasks_review_idx (org_id, created_at desc) where approval_status='pending'` | 검수 대기함, 사이드바 배지 |
| `agent_tasks_active_idx (status, created_at) where queued/running` | 운영 콘솔 작업 큐, 동기화 크론 |
| `agent_tasks_job_idx`, `agent_tasks_one_retry_idx`, `agent_tasks_request_uniq` | 잡 → 작업 역추적, 재시도 1회, 요청 멱등 |
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
| Realtime `supabase_realtime` | `publishing.sections`, `publishing.generation_runs`, `publishing.agent_tasks`(2026-10-14) 추가 | 발행 목록에 제품 테이블만 추가 |
| `core.ai_runs`, `core.ai_usage`, `core.audit_log` | agent_tasks.ai_run_id FK, 운영 콘솔 원가·추적, 결정 감사 | 안 함 |

### 6.1 AI·음성 코어 객체와 제품 규칙 (2026-10-13)

AI·음성 코어 객체(`docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| 코어 객체 | 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 글쓰기 도우미 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | web(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `publishing.draft`·`publishing.assist` 실행 기록, 위키 lint 결과. 조직 구성원이 SELECT(진행 칩 표시) | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, web 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 12행(9절), 경로 결정 | seed, FastAPI, web 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의와 고지문 버전 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 책별 자료·원고 컬렉션(이용자 조직). `ai_chunks`는 사용자 SELECT 없음 | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions`, `purge_wiki_page` | 책 설정집. 조직 구성원이 SELECT, 쓰기는 FastAPI만 | FastAPI |
| `voice_sessions`, `voice_jobs` | 받아쓰기·채팅 음성·낭독 작업 기록(`store_audio=false`) | web 음성 |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, web |

이름·경로 규칙(제품이 정하는 값, 코어 표를 바꾸지 않는다):

| 대상 | 규칙 |
|---|---|
| RAG 컬렉션 | 책마다 `book-<book_id>`(kind `rag`)와 `book-<book_id>-wiki`(kind `wiki`). 둘 다 `embedding_provider='oss-embed'`. `match_ai_chunks`는 책 컬렉션 id를 넘겨 호출하므로 책 사이 검색이 섞이지 않는다. 책 생성 시가 아니라 첫 색인·설정집 만들기 때 만든다 |
| 문서 `source_type` | 참고 파일 `upload`, 원고 스냅샷 `product`(소제목별 1문서, `content_hash`로 변경 감지), 설정집 임베딩 `wiki` |
| 설정집 slug | `books/<book_id>/index`, `books/<book_id>/characters/<name>`(`page_type='entity'`), `books/<book_id>/terms/<term>`(`concept`), `books/<book_id>/style/<name>`·`books/<book_id>/timeline`(`topic`). `book_id`의 uuid 문자(소문자 16진수와 하이픈)는 slug CHECK(`^[a-z0-9]+(-[a-z0-9]+)*(/...)*$`)를 통과한다(PGlite로 확인, 9절) |
| 낭독 파일 | `exports/<org_id>/publishing/narration/<book_id>/<scope_id>-<content_hash>.mp3`. `voice_jobs.storage_path`는 `store_audio=false`일 때 NULL이어야 하므로(CHECK `voice_jobs_no_store_check`) 파일 위치는 위 결정적 경로가 정본이고 DB에 컬럼을 두지 않는다 |
| 개인정보 표시 | 업로드 때 선택하면 `ai_documents.contains_pii=true`, 그 문서에서 만든 위키 페이지 `derived_from_pii=true`. 책 단위 스위치는 `books.book_info.ai_open_source_only` |

제품 AI 표를 만들지 않은 이유(`docs/products/_platform-core/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 결정 | 이유 |
|---|---|---|
| 책-컬렉션 연결 표 | 만들지 않음 | 컬렉션 이름 규칙(`book-<book_id>`)과 `(org_id, app_id, name)` 유일 제약으로 충분 |
| 동의 증빙 표(astro-ai의 `consents` 방식) | 만들지 않음(D16) | 국외 이전은 `ai_org_settings`(고지문 버전·시각·동의자), 음성 처리 고지는 `core.audit_log`(`voice.notice_ack`)로 증빙한다. 감사 로그 보존이 2년(제안)이라 분쟁 증빙에 부족하면 전용 표로 전환 |
| 책 AI 개인정보 컬럼 | 만들지 않음(D12) | `book_info` 키로 시작. 승격 여부는 D12에서 결정 |
| 일관성 메모·초안 제안 저장 | 만들지 않음 | 자식 잡 `result`(`core.jobs`)와 `ai_run_steps.output`에 남긴다. 편집기가 다시 열릴 때도 메모를 보여야 하므로 코어 잡 결과 보존 기간(`CORE_SPEC.md` 14장, 구현 시 확인)이 짧으면 `sections.ai_notes jsonb` 컬럼을 PB-06-001 후속으로 추가한다 |
| 낭독 파일 표 | 만들지 않음 | 결정적 Storage 경로 |
| 챕터 초안 실행 추적 | 기존 `generation_runs` + `core.ai_runs.job_id` | `generation_runs.parent_job_id`의 자식 잡 `write_section`마다 `ai_runs` 1행 |

삭제 연쇄: 책 영구 삭제(`publishing.purge`)는 그 책의 컬렉션 두 개(문서·청크 cascade)와 설정집 페이지를 `purge_wiki_page`로 지우고, 낭독 파일을 Storage에서 지운다. 대화·메시지는 책과 DB로 연결되지 않으므로 이용자가 대화 삭제를 요청할 때 지운다. 조직 purge는 `core.ai_*`, `core.wiki_*`, `core.voice_*`의 `org_id ... on delete cascade`로 따라 지워진다. 인프라에 남는 사본: Dify 대화 로그(30일 보존).

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
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) | 같음 |
| AI 라우팅 기본값 | `1000_publishing.sql` 15.1절 | `seed.sql`(같은 12행) | 모듈러 쪽은 제공자 행이 있을 때만 체인 검사(15.3절) |
| 플랜 AI 키(6개) | `1000_publishing.sql` 15.2절 병합 UPDATE(모듈러 `seed.sql` 반영 요청 R7) | `seed.sql` free·basic `features`에 직접 | 서버는 누락 키를 Free 값으로 읽는다 |
| 앱 등록 | `core.apps` + 모듈러 seed | `public.apps` 1행(`schema_name='public'`) → 가입 시 메타데이터 없이 자동 부트스트랩 | `DBC` 12장 |
| 플랜 seed | 모듈러 seed(2026-10-13 모놀리스 seed와 일치, features 16키) | `seed.sql`에 features 16키 | 같음. 서버 기본값은 키 누락 대비로 유지 |
| PostgREST | `[api].schemas`에 `publishing` 추가, 클라이언트 `supabase.schema('publishing')` | 기본 노출 | - |
| 월 지급 | `run_monthly_credit_grants()` | `run_subscription_rollover()` + `run_monthly_credit_grants()` | DBC 12장 |
| 결제 실패 기록(코어 수정 반영, 2026-10-13) | `confirm_payment_order`는 금액 불일치 시 `PM001`을 올린다(계약 불변, 같은 호출의 UPDATE는 롤백). 주문 failed 기록은 service_role 전용 `fail_payment_order`가 맡는다 | 같음(`public.fail_payment_order`) | `PM001`이면 Route Handler가 별도 호출로 `fail_payment_order(order_id, 'amount_mismatch', {...})`를 부르고, 이어 Toss 취소 요청 + 운영 알림을 한다. 남은 created 주문은 코어 `expire_stale_payment_orders`가 정리한다. 코어 수정은 하지 않는다 |

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `docs/products/_supabase-modular/migrations/1000_publishing.sql` | 번호 1000(범위 1000~1099). 스키마, `core.apps` 등록, 헬퍼 3, 테이블 12, 트리거 함수 9, 사용자 RPC 2, RLS·GRANT, Realtime, 14절 함수 EXECUTE 최종 회수(PUBLIC·anon, `0007_core_function_privileges.sql`과 같은 규칙), 15절 AI·음성 기본값(라우팅 12행, free·basic AI 키 6개, 체인 검사), 16절 `agent_tasks`(2026-10-14: 표 1, 트리거 함수 2, 사용자 RPC 1, RLS, Realtime) |
| `supabase/monolith/migrations/0001_core_lite.sql` | `_platform-core/MONOLITH_CORE_LITE.sql` 복사본(OAuth state, affiliate 절 제거) |
| `supabase/monolith/migrations/0002_publishing_domain.sql` | 위 조각의 모놀리스 변환본 |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 free/basic(features 22키: 기존 16 + AI 6), 크레딧팩 2종, AI 라우팅 기본값 12행 + 체인 검사. 제품 seed 없음(카탈로그는 코드 JSON) |

검증 결과(2026-10-12, `docs/products/_tools-sqlcheck`):

| 검사 | 결과 |
|---|---|
| `node check.mjs --vector mono 0001_core_lite.sql 0002_publishing_domain.sql seed.sql` | OK 3/3 (2026-10-13 재검증, AI 표가 있어 `--vector` 필수) |
| `node check.mjs --vector mod 0000~0009 seed.sql 1000_publishing.sql` | OK 12/12 (2026-10-13 재검증, 2026-10-14 16절 추가 후 재검증 OK) |
| `agent_tasks` 동작 스모크(2026-10-14, PGlite, service 세션) | 상태 역행 22023, 신원 컬럼 변경 22023, 결정 후 `approval_decided_at` 기록, 이중 결정 `PB012`, 같은 `request_id` 23505, 같은 작업 두 번째 재시도 23505, 진행 중 작업 재시도 `PB013`, 취소 작업 → 검수 대기 허용, 첫 작업 `attempt<>1` 22023, `admin_retry` 원래 행 없음 22023, 재시도가 있는 원래 행 삭제 시 `retry_of` null 모두 기대대로. 같은 스모크를 모놀리스 0002 변환본에도 돌려 OK |
| 반복 실행 | 두 구조 모두 제품 SQL 2회 적용 OK |
| AI 기본값(2026-10-13, PGlite) | 제품 파일 2회 적용 후 `ai_routing_settings`(org null, app publishing) 12행. free·basic `features`에 AI 키 6개 병합. 미동의 조직 `resolve_ai_route`: `publishing.draft`·`publishing.assist`·`chat` = oss-llm, `wiki.ingest` = oss-llm, `narration` = oss-voice, `voice_chat` stt/tts = oss-voice, `publishing.dictation` = oss-voice, `publishing.knowledge` = oss-embed. 동의 후: `publishing.draft` = anthropic > openai > google > oss-llm, `wiki.ingest` = oss-llm > anthropic, `narration` = elevenlabs > oss-voice, `dify.aux` = oss-llm(동의 후에도). 컬렉션 `book-<uuid>`와 위키 slug `books/<uuid>/characters/seo-jin`이 CHECK를 통과 |
| RLS 스모크(PGlite, 사용자 A·B·C + anon) | 모듈러 57/57, 모놀리스 57/57 통과 |

RLS 스모크 주요 항목: B가 A 조직의 제품 테이블 11개 SELECT 0행, B의 A 조직 INSERT 42501, A 책 UPDATE/DELETE 0행, 다른 책 참조 INSERT 23503, B의 `request_generation_cancel`·`set_book_visibility`(A 행) 42501, `book_plan_limit`(A 조직) 기본값만 반환, 자기 엔타이틀먼트·지갑·profiles.platform_role·org_members.role 변경 42501, `grant_credits`·`consume_credits` 42501, 서버 전용 테이블 사용자 INSERT 42501, 컬럼 GRANT 밖 컬럼(`is_public`, `gen_status`, `org_id`) UPDATE 42501, 상태 전이 위반 22023, Free 4번째 책 `PB001`, Pro 테마 `PB008`, 엔타이틀먼트 정지 조직 INSERT 42501, anon 비공개 책 0행, anon의 제품 함수 EXECUTE 없음·트리거 함수는 authenticated도 EXECUTE 없음(PUBLIC 경유 차단). 스크립트는 PB-06-029 작업에서 `supabase/tests/`로 옮긴다.

2026-10-14 추가할 RLS 스모크(PB-06-029): B가 A 조직 `agent_tasks` SELECT 0행, 사용자 세션 `agent_tasks` INSERT·UPDATE·DELETE 42501(guard), B의 `decide_agent_task`(A 행) 42501, viewer의 `decide_agent_task` 42501, 엔타이틀먼트 정지 조직의 결정 42501, anon의 `decide_agent_task` EXECUTE 없음.

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경은 없다. 인증 단계는 코어 계약(`session_context`, 가입 트리거, `bootstrap_app_for_org`)을 그대로 쓰고, Stage A의 Mock 로그인은 로컬 Supabase에 시드한 실제 계정으로 로그인한다(`docs/products/_platform-core/AUTH_ROADMAP.md` 2장). C2에서 브리지 경로를 택하면 코어 `docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`의 `core.auth_identity_links`를 참조만 한다(제품 테이블 추가 없음, 06장 8.3절 R15).

시드는 `scripts/dev/seed-users.mjs --app publishing`(공통, AUTH_ROADMAP 2.3절)이 공통 페르소나를 만든 뒤 제품 훅 `scripts/dev/seed-users.publishing.mjs`(제안)를 실행한다. 원격 호스트면 즉시 종료하고, 두 번 실행해도 크레딧이 두 번 지급되지 않는다. 이메일 도메인 `.test`, 비밀번호는 `DEV_SEED_PASSWORD`(출력하지 않음).

### 10.1 공통 페르소나 (AUTH_ROADMAP 2.2절)

| 키 | 만드는 경로 | 기대 `session_context('publishing')` | publishing에서 확인하는 것 |
|---|---|---|---|
| `owner` | `auth.admin.createUser`(`user_metadata.signup_app='publishing'`) → 가입 트리거 `core.handle_new_user` | 개인 조직 owner, `entitled=true`, `plan_code='free'`, `credit_balance=20` | 01장 PB-F-001 Stage A 수용 기준, Free 한도(`PB001~PB004`, 워터마크, 월 내보내기 2회), 온보딩 2단계(03장 7.3절) |
| `admin` | 생성 후 owner가 `invite_member(org, user, 'admin')` → 본인 `accept_invite` | owner 조직의 admin | 책 삭제·복구, 결제 화면 접근(owner/admin), 웹훅 등록 |
| `member` | 같은 방법(`member`) | owner 조직의 member | 책 생성·집필 가능, `/dashboard/billing` 접근 불가 |
| `viewer` | 같은 방법(`viewer`) | owner 조직의 viewer | 위저드 읽기 전용(03장 1절), 쓰기 API 403 |
| `outsider` | `signup_app='publishing'`으로 생성(다른 개인 조직) | 자기 조직 owner | 교차 테넌트: owner 조직의 `books`·`sections`·`book_exports`·대화·위키 0행, 다른 책 `book_id`로 채팅 404, 다른 컬렉션 RAG 42501 |
| `no_app` | `signup_app` 없이 생성 | 모듈러: `entitled=false` → `finishLogin`이 `bootstrap_app_for_org('publishing')` 1회 후 `entitled=true`. 모놀리스: 가입 트리거가 자동 부트스트랩해 처음부터 `entitled=true` | OAuth 첫 로그인 경로(B-1)를 A단계에서 미리 검증. 재로그인 3회 뒤 가입 크레딧 원장 행 1개 |
| `suspended` | 생성 후 service_role로 `status=suspended` | 403 | `/suspended` 안내, 모든 API 403 |
| `ops` | 생성 후 service_role로 `platform_role=platform_admin` | 운영자 | `/admin` 접근(일반 사용자는 404, PB-F-005), 수동 조정 감사 1행 |

`pending`은 approval 앱 전용이라 만들지 않는다(publishing `signup_policy='open'`, `docs/products/_supabase-modular/seed.sql:13`).

### 10.2 제품 훅 행 (publishing 도메인)

AUTH_ROADMAP 8장의 publishing "A 추가 페르소나"는 "-"(필수 추가 없음)이다. 아래 행은 Basic 게이팅과 온보딩 E2E를 Mock으로 돌리기 위한 제안이다.

| 키 | 만드는 경로 | 기대 결과 | 확인하는 것 |
|---|---|---|---|
| `basic`(제안) | `signup_app='publishing'`으로 생성 → service_role로 `core.subscriptions`에 basic 플랜 `trialing` 행 INSERT → `core.apply_subscription_transition(<sub>, 'active', 'dev_seed')`(`docs/products/_supabase-modular/migrations/0002_core_billing.sql:265`) → `grant_credits`(bucket `plan`, 멱등 키 `dev-seed:basic:<org>`, 200) | `plan_code='basic'`, `credit_balance=220`(가입 20 + plan 200, 제안) | 전체 순차 생성, 업로드, 어조, 보조 집필, quality 모드, 페르소나 합성, 낭독, 웹훅이 열린다(01장 4.4절). 실제 결제 경로는 PB-06-030이 Toss 테스트 키로 따로 검증한다 |
| 약관 동의 기록 | `admin`, `member`, `viewer`, `outsider`, `basic`에 감사 행(제안: 행동 `terms.accept`, 약관 버전)을 service_role로 만든다. `owner`, `no_app`은 만들지 않는다 | 앞의 페르소나는 로그인 직후 `/dashboard`, `owner`·`no_app`은 `/onboarding` 약관 단계 | 03장 7.3절 온보딩 경로와 기능 E2E를 분리 |
| AI 국외 이전 동의 | 만들지 않는다(모든 페르소나 미동의로 시작) | 오픈소스 체인 | 동의 경로는 E2E(PB-06-037)가 `owner`로 직접 통과시킨다. 상용 체인이 필요한 테스트는 테스트 안에서 `set_ai_cross_border_ack`(owner)를 부른다 |

### 10.3 모놀리스와 모듈러 차이

| 항목 | 모듈러(`publishing` + `core`) | 모놀리스(단독 `public`, 개발 폴더 기본) |
|---|---|---|
| `no_app` | `entitled=false`로 생성, `finishLogin`의 `bootstrap_app_for_org`가 메운다 | 앱 행이 1개라 가입 트리거가 자동 부트스트랩(`entitled=true`), `finishLogin`의 부트스트랩 단계는 무동작 |
| 시드 대상 | `--app`을 여러 번 줄 수 있다(두 번째 앱부터 service_role `bootstrap_app_for_org`) | `--app publishing` 한 번 |

## 11. 책 구성 페이지 저장 (2026-10-20 추가, 검토용)

01장 11장(PB-F-070~076)의 저장 구조. 새 테이블은 만들지 않는다(1권 1행 JSON이면 충분, 제안). 2장 `books`의 기존 `layout_settings`(여백·본문 pt)와 `book_info`는 그대로 쓰고, 쪽별 편집 값만 새 컬럼 1개에 둔다.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `books.page_layout` | jsonb | N | '{}' | 쪽별 필드와 타이포. 키는 `cover`, `colophon`, `toc`, `chapter`, `content`, `epilogue`, `bookinfo`, `back`와 `preset`(예: `deep_navy_v1`). 각 쪽은 `{fields…, typo:{…}}`. 사용자 UPDATE 허용(원고와 같은 정책), 크기 제한 64KB(CHECK) |

예시 구조(값은 예시):

```json
{ "preset": "deep_navy_v1",
  "cover": { "publisher": "[예시] 출판사", "titleLine1": "[예시] 제목", "typo": { "titleSize": 38, "subtitleSize": 14 } },
  "toc":   { "entries": [ { "text": "제1장", "num": "3", "bold": true }, { "text": "소제목", "num": "3", "indent": true } ] } }
```

- 병합 규칙: 저장된 값이 기본값 위에 얹힌다(없는 키는 기본값). 두 파일의 `loadData`와 같은 방식이고, 서버가 조립할 때(PB-F-023) 적용한다. 이렇게 하면 새 필드가 추가돼도 옛 책이 깨지지 않는다.
- 검증: 키 화이트리스트(8종 + `preset`), 타이포 숫자 범위(PB-F-072), 모든 텍스트 escape. 쪽번호·판권 AI 표시 문구는 이 JSON이 아니라 서버가 고정으로 넣는다(사용자가 지울 수 없음).
- RLS: `books`의 기존 정책을 그대로 쓴다(4절). 새 정책 없음.
- 마이그레이션: `books`에 컬럼 추가 1건(기본 '{}', 기존 행 영향 없음). 파일 번호는 9절 규칙을 따르고 기획 승인 뒤에 만든다.
- `layout_settings`와의 관계: `layout_settings`는 판형별 본문 pt·행간·여백(PB-F-007), `page_layout`은 쪽별 내용·타이포다. 두 값이 충돌하면(예: 본문 크기) `layout_settings`가 이긴다(제안).

---

## 12. 제작 모드와 이미지 자리 (2026-10-20 추가, 검토용)

01장 13절 D44~D48의 데이터다. 아래는 제안이며 확정 전이다.

| 대상 | 필드·테이블 | 타입 | 설명 |
|---|---|---|---|
| `books.production_mode` | text | 기본 'prose' | 'prose'(글형), 'poetry'(시집형), 'picturebook'(그림책형), 'tech'(기술서형). 집필 시작 뒤 변경 불가 |
| `book_assets` | 테이블 | — | 책의 이미지 자리. `id, book_id, kind('screenshot'\|'diagram'\|'illustration'\|'poem_image'), anchor_section_id, page_no, status('empty'\|'filled'\|'stale'), source('upload'\|'ai'\|'mermaid'), storage_path, alt_text, meta jsonb(소프트웨어 버전·촬영일, 프롬프트, 시드), created_at` |
| `book_characters` | 테이블 | — | 그림책 캐릭터 시트. `id, book_id, name, description, style_ref_path, palette jsonb, locked_at` |
| `poems` | 테이블 | — | 시집형 시. `id, book_id, position, title, body, asset_id` |
| 이미지 생성 크레딧 | `credit_ledger` ref_type 'image_gen' | — | 선차감·실패 환불(01장 13.3절 D48). 단가 미정 |

저장 경로: `exports/<org_id>/publishing/assets/<book_id>/<asset_id>.<확장자>`. 책 삭제 시 함께 삭제한다. RLS는 `book_id`의 조직 기준(기존 `books`와 같음).

---

## 13. 발행본과 산출물 (2026-10-20 추가, 검토용)

01장 14절 D49~D54의 데이터다. 아래는 제안이며 확정 전이다. 기존 `book_exports`는 그대로 두고 발행본이 그것을 참조한다.

| 테이블 | 필드 | 설명 |
|---|---|---|
| `publishing.book_releases` | `id, org_id, book_id, version_label('1.0'…), content_hash, status('queued'\|'running'\|'succeeded'\|'partially_failed'\|'failed'), requested_by, created_at, completed_at, note` | 발행본. `content_hash`는 그 시점 원고·표지·판형 해시. 한 책의 `(book_id, content_hash)`는 중복 발행본을 만들지 않고 기존 것을 가리킨다 |
| `publishing.release_artifacts` | `id, release_id, format('pdf'\|'epub'\|'print_interior'\|'print_cover'\|'audiobook'), export_id → book_exports(pdf·epub), voice_job_ids uuid[](audiobook), status, storage_path, bytes, pages, spine_mm, expires_at, credit_ledger_id, meta jsonb(판형·용지·제본·블리드·구간 목록)` | 발행본의 형식별 산출물. 부분 실패는 산출물 단위로 기록 |
| `books.published_version` | text | 가장 최근 성공 발행본의 판. 서가·준비 목록에서 "개정판 가능" 판단에 쓴다 |

- 서가 쿼리: `book_releases` + `release_artifacts`를 조직 기준으로 조회(RLS는 `book_id`의 조직, 기존 `book_exports`와 같음).
- 보관: 산출물 파일은 90일(제안) 뒤 `expires_at`로 만료, 메타는 남긴다. 크레딧 규칙은 기존 선차감·환불을 그대로 쓴다(`ref_type='release_artifact'`).
- 일괄 발행은 책 × 형식마다 산출물 1행이고 각각 독립으로 성공·실패한다.

---

## 14. 연재물·편·권 (2026-10-20 추가, 검토용)

01장 15절 D55~D63의 데이터다. 아래는 제안이며 확정 전이다.

| 대상 | 필드·테이블 | 타입 | 설명 |
|---|---|---|---|
| `books.production_mode` | text | 값 추가 | 'serial'(연재형). 기존 값 4개는 12절 그대로 |
| `publishing.series` | 테이블 | — | 연재물. `id, org_id, title, genre('webnovel'), subgenre_tags text[], episodes_per_volume int 기본 25, target_chars int 기본 5000, weekly_goal int, created_at` |
| `books.series_id`, `books.volume_no` | uuid, int | null 허용 | 권인 책만 값이 있다. `(series_id, volume_no)` unique. 이 책의 챕터는 권 묶기 때 편에서 만든다 |
| `publishing.series_episodes` | 테이블 | — | 편. `id, series_id, episode_no, title, outline, body, char_count, summary, status('outline'\|'drafting'\|'done'\|'bound'), volume_book_id → books(null=아직 권에 안 묶임), updated_at`. `(series_id, episode_no)` unique |
| 설정집 | 기존 설정집 테이블 | — | `series_id`로도 참조할 수 있게 확장(제안) |
| 삽화 | `book_assets` | — | `episode_id` 컬럼 추가(null 허용, `kind='illustration'`) |

- 권 묶기: 트랜잭션 하나로 books 행 생성 + 선택한 편을 챕터로 복사 + `series_episodes.volume_book_id` 채움 + `status='bound'`. 한 편은 한 권에만 묶인다.
- 발행된 권(`books.published_version` 있음)의 편을 고치면 `bound` 편의 변경이 권 원고와 갈라지므로 "권에 반영" 확인 단계를 둔다(개정판으로 이어짐, D63). 이 부분의 UX는 확정 전.
- 집필 요청 입력: 설정집 + 최근 N편 `summary` + 이전 편 말미(≤800자 제안). 전문 주입 금지(D59).
- RLS는 `series.org_id` 기준이며 편·권은 부모 연재물의 조직을 따른다.
