# 05 데이터 모델: Study Note

작성일 2026-10-12. 정본 SQL: 모듈러 `docs/products/_supabase-modular/migrations/2100_notes.sql`(스키마 `notes`), 모놀리스 `supabase/monolith/migrations/0002_study_note_domain.sql`(`public`, 같은 본문을 변환). 약칭 DBC = `DB_CONVENTIONS.md`.

2026-10-13: AI·음성(확정 결정 13~17)은 코어 표(`core.ai_*`, `core.wiki_*`, `core.voice_*`)만 참조하고 **제품 AI 표를 새로 만들지 않았다**(6절에 이유). 제품 표 7개와 RLS는 그대로이며, 2100_notes.sql 14절과 모놀리스 `seed.sql`에 AI 라우팅 기본값 13행과 플랜 AI 키가 추가됐다.

## 1. 개요와 ERD

```
core.organizations (참조)
  |-- notes.entries            일지(원문 + 최종본)         사용자 쓰기: 원문/날짜/삭제표시
  |     |-- notes.runs         정리 실행 1회               사용자 읽기만
  |           |-- notes.run_steps   카드 3장(base1, base2, merge)   사용자 읽기만
  |-- notes.user_settings      사용자별 모델/테마          사용자 쓰기
notes.model_catalog            모델 화이트리스트(전역)     사용자 읽기만
notes.runtime_config           운영 상한                   service만
notes.cost_guard               일일 소비 합계              service만
참조: core.credit_ledger(runs.credit_ledger_id), core.jobs(runs.job_id), core.ai_usage(run_steps.ai_usage_id)
```

AI·음성(2026-10-13)은 코어 표만 참조한다. 제품 표와 FK로 묶지 않는다(과목·퀴즈·강의 조각의 위치는 6절 표):

```
core AI·음성 (참조만, app_id = 'notes')
 ├─ core.ai_collections      과목마다 2개: rag:s-<sid>(노트·교재), wiki:s-<sid>(위키 임베딩)
 │    └─ core.ai_documents ─ core.ai_chunks (사용자에게 SELECT 안 열림)
 ├─ core.wiki_pages ─ core.wiki_links / core.wiki_revisions     slug subjects/s-<sid>/...
 ├─ core.ai_conversations ─ core.ai_messages                    사용자 본인만 읽음
 ├─ core.ai_runs (graph notes.organize, output = 요약·퀴즈) ─ core.ai_run_steps
 ├─ core.voice_sessions ─ core.voice_jobs (feature voice_chat / quiz_voice / lecture_note)
 └─ core.ai_providers, ai_model_prices, ai_routing_settings, ai_org_settings
```

## 2. 테이블

표준 컬럼(DBC 3장): `org_id`(테넌트 테이블), `created_at`, `updated_at`+트리거(UPDATE 있는 테이블), `created_by`(FK 없음).

### 2.1 `model_catalog` (전역)

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `model_id` | text PK | N | | OpenRouter 모델 ID |
| `display_name`, `provider` | text | N | | 표시 이름, 공급사 배지 |
| `tier` | text | N | | `lite`/`standard`/`premium` |
| `credits_per_call` | integer | N | | 1~20 (CHECK) |
| `is_free`, `is_active` | boolean | N | false / true | 무료 모델 표시, 사용 가능 |
| `sort_order` | integer | N | 100 | |
| `deprecated_at` | timestamptz | Y | | 비활성 사유 시각 |

초기 13행은 원본 `constants.ts:3-17`의 모델이며 등급과 크레딧은 제안(01장 4.3). 원본 모델 ID의 현재 유효성은 미확인이다(구현 시 동기화 잡으로 확인).

### 2.2 `runtime_config`, `cost_guard` (service만)

| 테이블 | 컬럼 | 설명 |
|---|---|---|
| `runtime_config` | `key` PK, `value_int`, `note`, `updated_at` | `daily_credit_cap`=5000, `max_active_runs_per_org`=2 (제안) |
| `cost_guard` | `day` date PK(KST), `used_credits`, `updated_at` | `start_run`이 업서트로 증가. 상한 초과면 `NT005`로 롤백 |

### 2.3 `user_settings`

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `org_id` | uuid | N | | PK(org_id, user_id), FK `core.organizations` cascade |
| `user_id` | uuid | N | | FK 없음 |
| `base_model_1`, `base_model_2`, `merge_model` | text | Y | | FK `model_catalog`(on delete set null). null이면 프리셋 |
| `theme` | text | N | `system` | `system`/`light`/`dark` |

API Key 컬럼은 없다(리뷰 #1, #7).

### 2.4 `entries`

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid PK | N | gen_random_uuid() | |
| `org_id` | uuid | N | | cascade |
| `created_by` | uuid | N | `auth.uid()` | 사용자는 INSERT 컬럼 GRANT에 없으며 기본값으로 채워진다 |
| `entry_date` | date | N | | 일지의 달력 날짜(KST, 시각이 아님. 리뷰 #5) |
| `input_text` | text | N | | 1~20,000자 CHECK. 플랜 한도는 `start_run`에서 |
| `status` | text | N | `draft` | `draft`/`organizing`/`organized` |
| `final_text` | text | Y | | `[핵심 키워드]` 제거된 통합본 |
| `keywords` | text[] | Y | | 정확히 2개 |
| `last_run_id` | uuid | Y | | FK `runs` set null |
| `organized_at`, `deleted_at` | timestamptz | Y | | 휴지통 표시 |

### 2.5 `runs`

| 컬럼 | 타입 | NULL | 설명 |
|---|---|---|---|
| `id`, `org_id`, `entry_id`, `created_by` | | | `entry_id` cascade |
| `request_id` uuid, `idempotency_key` text UNIQUE | | N | `run:notes:<request_id>` |
| `parent_run_id`, `retry_roles` text[] | | Y | 카드 재요청이면 부모와 대상 |
| `base_model_1`, `base_model_2`, `merge_model` | text | N | 실행 시점의 모델(카탈로그 변경과 무관) |
| `status` | text | N | queued/running/succeeded/partial/failed/canceled |
| `credits_charged`, `credits_refunded` | integer | N | 환불 ≤ 차감 CHECK |
| `credit_ledger_id`, `job_id` | | Y | `core.credit_ledger`, `core.jobs` |
| `cancel_requested_at`, `error_code`, `error_message` | | Y | |
| `queued_at`, `started_at`, `finished_at` | timestamptz | | |

### 2.6 `run_steps`

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `id`, `org_id`, `run_id` | | `UNIQUE(run_id, role)` |
| `role` | text | `base1`/`base2`/`merge` |
| `model_id` | text | 실제 호출 모델(폴백 시 갱신) |
| `status` | text | pending/running/succeeded/failed/skipped/reused/canceled |
| `credits` | integer | 이 단계에 선차감된 크레딧(재사용은 0) |
| `content`, `latency_ms`, `prompt_tokens`, `completion_tokens`, `ai_usage_id`, `error_code`, `error_message`, `started_at`, `finished_at` | | |

## 3. 상태 전이

### 3.1 `entries.status` (트리거 `entries_status_transition`, service_role에도 적용)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| draft | organizing | `start_run` | `last_run_id` 설정 |
| organizing | organized | `finish_run`(succeeded) | `final_text`, `keywords`, `organized_at` |
| organizing | draft | `finish_run`/`request_run_cancel`(성공 결과 없음, 이전 최종본 없음) | |
| organized | organizing | `start_run`(재정리) | |
| (organizing → organized, 이전 최종본 있고 새 실행 실패) | organized | `finish_run` | 이전 최종본 유지 |

### 3.2 `runs.status` (트리거 `runs_status_transition`)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| queued | running | `record_step` 첫 호출 또는 `finish_run` | `started_at` |
| queued | canceled | `request_run_cancel` | `core.cancel_job` 환불, 단계 canceled |
| running | succeeded | `finish_run` | 통합 성공 + 키워드 2개 |
| running | partial | `finish_run` | 이번 실행 단계 중 일부 성공. 실패/건너뛴 단계 크레딧 환불 |
| running | failed | `finish_run` | 성공한 실행 단계 없음. 전액 환불(멱등 키 `refund:job:<job_id>`로 `fail_job` 자동 환불과 겹치지 않음) |
| running | canceled | `finish_run` | `cancel_requested_at`이 있고 성공 단계 없음. 미실행분 환불 |
| 종료 상태 | 없음 | | 종료된 실행의 단계/종료 쓰기는 `NT003` |

### 3.3 `run_steps.status` (`record_step`이 강제)

| 현재 | 허용 전이 |
|---|---|
| pending | running, skipped, canceled, failed |
| running | succeeded, failed, canceled |
| reused, succeeded, failed, skipped, canceled | 없음 |

`finish_run`이 남은 pending은 skipped(취소 실행은 canceled), running은 failed(`aborted`)로 정리한다.

## 4. RLS 정책

모든 테이블 RLS ON. 코어 헬퍼만 사용하고 `org_members`를 직접 조회하지 않는다(DBC 7장). `FOR ALL` 정책 없음.

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT |
|---|---|---|---|---|---|
| `model_catalog` | `is_active` (authenticated) | 없음 | 없음 | 없음 | select. 쓰기는 service + `guard_privileged_write` |
| `runtime_config`, `cost_guard` | 정책 없음(전부 거부) | 없음 | 없음 | 없음 | 권한 없음 |
| `user_settings` | `user_id = auth.uid()` and 멤버 and 엔타이틀먼트 | `with check`: `user_id = auth.uid()` and `has_org_role(owner/admin/member)` and 엔타이틀먼트 | `using` 자기 행 + `with check` 자기 행 | 없음 | select, insert(컬럼 6개), update(모델 3개+테마) |
| `entries` | 멤버 and 엔타이틀먼트 (soft delete 행도 읽힘: 휴지통) | `with check`: `created_by = auth.uid()` and 역할 and 엔타이틀먼트 | `using`/`with check` 역할 | `has_org_role(owner/admin)` | select, insert(org_id, entry_date, input_text), update(entry_date, input_text, deleted_at), delete |
| `runs`, `run_steps` | 멤버 and 엔타이틀먼트 | 없음 | 없음 | 없음 | select만 |

쓰기 정책을 주는 `entries`, `user_settings`는 DBC 8.1의 "순수 콘텐츠" 조건을 충족한다: 돈, 권한, 한도 컬럼이 없고, 상태/결과 컬럼(`status`, `final_text`, `keywords`, `last_run_id`, `organized_at`)은 컬럼 GRANT(1차)와 `entries_guard_write` 트리거(2차)로 사용자 변경 불가, 상태는 전이 트리거로 강제된다.

SECURITY DEFINER 함수 EXECUTE 정리: 서비스 전용 5개(`start_run`, `record_step`, `finish_run`, `enforce_retention`, `purge_deleted`)와 내부 `org_features`는 `public, anon, authenticated`에서 회수하고 `service_role`에만 부여. `request_run_cancel`만 authenticated(내부에서 `is_service_caller()`+`has_org_role`). 모든 함수 `set search_path = ''`, 객체 스키마 한정. 서비스 전용 함수의 내부 판정은 `is_privileged_session()`(`SECURITY_BASELINE.md:23`).

## 5. 인덱스와 성능

| 인덱스 | 용도 |
|---|---|
| `entries_org_created_idx (org_id, created_at desc) where deleted_at is null` | 보관함 목록, 보존 정리 |
| `entries_org_date_idx (org_id, entry_date desc) where deleted_at is null` | 날짜 검색 |
| `entries_deleted_idx (deleted_at) where deleted_at is not null` | 휴지통 정리 |
| `runs_one_active_per_entry_uniq (entry_id) where status in ('queued','running')` | 일지당 활성 1개(리뷰 #3) |
| `runs_entry_created_idx`, `runs_org_active_idx` | 실행 이력, 조직 동시 실행 수 |
| `run_steps UNIQUE (run_id, role)`, `run_steps_org_idx` | 카드 조회, RLS |

예상 규모: 조직당 일지 ≤ 500, 일지당 실행 1~3회. 보존 정리는 조직 단위 윈도우 집계라 일지 수가 작아 부담이 없다.

## 6. 코어 참조

| 객체 | 용도 | ALTER 금지 확인 |
|---|---|---|
| `core.organizations` | `org_id` FK | 변경 없음 |
| `core.apps`, `core.plans`, `core.credit_packs` | 앱 등록, 플랜/크레딧팩 데이터 INSERT/UPDATE만(DDL 없음) | 변경 없음 |
| `core.app_entitlements` | `has_entitlement`, `org_features` | 읽기 |
| `core.is_org_member`, `has_org_role`, `has_entitlement`, `is_privileged_session`, `is_service_caller`, `set_updated_at`, `guard_privileged_write`, `write_audit` | 정책, 함수, 트리거 | 호출만 |
| `core.consume_credits`, `refund_credits`, `credit_ledger` | `start_run`/`finish_run` 안에서 | 호출만 |
| `core.jobs`, `enqueue_job`, `cancel_job` | 잡 생성/취소 | 호출만 |
| `core.ai_usage` | `run_steps.ai_usage_id` FK | 읽기 |

AI·음성 코어 객체(2026-10-13, `docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`). 모두 참조만 하고 ALTER하지 않는다:

| 객체 | 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 과목별 노트·교재 색인과 검색 | FastAPI(service_role). 사용자는 `ai_documents`만 RLS로 읽는다 |
| `wiki_pages`, `wiki_links`, `wiki_revisions`, `purge_wiki_page` | 과목별 개념 위키, 이력, 개인정보 삭제 | FastAPI |
| `ai_conversations`, `ai_messages` | 채팅 대화 매핑과 메시지 | Next.js(대화 생성), FastAPI(답변 기록) |
| `ai_runs`, `ai_run_steps`, `ai_runtime` 스키마 | 그래프 실행 기록과 LangGraph 체크포인트 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, Next.js 음성, 정산 크론 |
| `ai_providers`, `ai_model_prices`, `ai_routing_settings`, `resolve_ai_route`, `ai_org_settings`, `set_ai_cross_border_ack` | 제공자, 단가, 기능별 기본값(13행, 9절), 경로 결정, 국외 이전 동의 | seed, FastAPI, Next.js |
| `voice_sessions`, `voice_jobs`, `voice-audio` 버킷, `expire_voice_audio` | 음성 대화, 강의 조각 STT, 퀴즈 음성, 녹음 보관·만료 | Next.js, 워커 |
| `org-files` 버킷 | 교재·노트 업로드, 강의 전사 조각 | Next.js(서명 업로드 URL), FastAPI. 모놀리스는 `seed.sql`이 버킷을 만든다 |

제품 AI 표를 만들지 않은 이유(`docs/products/_platform-core/AI_ARCHITECTURE.md:162-166`의 "꼭 필요할 때만"):

| 필요해 보인 표 | 하려던 일 | 대신 쓴 코어 구조 |
|---|---|---|
| 과목 표 | 과목 이름, 목록, 삭제 | 위키 `index` 페이지 `subjects/s-<sid>/index`(제목 = 과목 이름)와 컬렉션 이름 규칙 `rag:s-<sid>`, `wiki:s-<sid>`. 과목 수는 `ai_subjects_max`로 제한(01장 3.2절, D-16) |
| 퀴즈 표 | 퀴즈 문항 저장 | `core.ai_runs.output`(graph `notes.organize`). 사용자는 RLS로 자기 조직 실행만 읽고, 문제 조회 API가 정답을 제거한다. 응시 기록은 MVP에서 저장하지 않음(D-15, Phase 2에 `notes.quiz_attempts`) |
| 요약 표 | 문서별 요약 | 위키 `source` 페이지(`subjects/s-<sid>/sources/d-<문서 id 앞 8자리>`) |
| 강의 표 | 강의 세션, 조각 순서, 전사 | `voice_sessions`(세션) + `voice_jobs`(조각별 STT 작업, 크레딧) + Storage 경로 `org-files/<org_id>/notes/lectures/<session_id>/<seq>.json`(순서 보존). 병합 뒤 문서로 등록하고 조각 파일은 삭제 |
| 동의 표 | 국외 이전, 음성, 강의 고지, 업로드 권한 증빙 | `core.ai_org_settings`(국외 이전, 고지문 버전), `voice_jobs.consent_*`(보관 동의), `write_audit` 키 4종: `notes_consent.ai_cross_border`, `notes_consent.voice`, `notes_consent.lecture_notice`, `notes_upload_rights` |
| 문서-그래프 연결 | 실행이 쓴 문서 추적 | `ai_runs.input`(문서 id 배열), 위키 페이지 `source_document_ids` |

조각 순서가 Storage 경로에 있어 `voice_jobs`에 순번 열을 요청할 수도 있으나, 순서는 병합 때 한 번만 쓰이고 조각 파일은 24시간 안에 삭제되므로 코어 변경을 요청하지 않는다(필요해지면 06장 C-8).

모듈러 조각이 `core.plans`에 하는 일: Free 플랜 `features`를 `'{}'`일 때만 채우고, `pro` 플랜과 크레딧팩 2종을 비활성으로 INSERT한다(모듈러 `seed.sql`은 제품이 수정하지 않는다. 코어 요청 C-4는 2026-10-13 반영 완료: seed가 모놀리스 seed와 일치). AI 키는 14.2절이 free/pro `features`에 병합한다(`features || ...`, 기존 키 유지, 반복 실행 가능). 조각은 `core.*`를 ALTER하지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| 리뷰 #1 → 차단 설계 | 리뷰 `:52` | API 키 번들 노출 | DB에는 키/토큰 컬럼이 없다(`user_settings`는 모델 ID와 테마뿐). LLM 키는 DB에도 저장하지 않고 워커 환경변수에만 둔다. `runs`/`run_steps`/잡 payload에도 비밀값이 없다. 비용 보호는 `cost_guard`+`runtime_config`(NT005)와 플랜 `allowed_tiers`로 키 유출 시 피해가 일일 상한에 묶이게 한다 | 02장 6절, NT-06-002, 003 |
| 리뷰 #2 → 차단 설계 | 리뷰 `:53` | `.gitignore` 부재, 중첩 `.git` | DB 해당 없음(저장소 위생). 02장 6절과 NT-06-001에서 차단 | 02장 6절 |
| 리뷰 #3 → 차단 설계 | 리뷰 `:54` | 동시 실행, 늦은 응답 덮어쓰기, 이중 과금 | `runs_one_active_per_entry_uniq` + `start_run`의 일지 행 `FOR UPDATE`(NT002), 멱등 키 `run:notes:<request_id>`/`consume:notes:`/`job:notes:`(재과금 없음), `record_step`/`finish_run`의 종료 실행 거부(NT003), 정리 중 원문 수정 잠금(NT001), 조직 동시 실행 제한(NT006), 선차감-실행 생성-잡 생성이 한 트랜잭션이라 고아 과금 없음 | NT-06-002, 003, 010 |

## 8. 모놀리스와 모듈러의 차이

DBC 12장 기준.

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `notes`. 코어 `core` | 모두 `public`. **`public` 스키마는 사용자 최종 확인 대기** (`MONOLITH_CORE_LITE.sql` 머리 주석) |
| 파일 | `migrations/2100_notes.sql` 1개 | `0001_core_lite.sql`, `0002_study_note_domain.sql`, `seed.sql` |
| 앱 등록, 플랜 seed | 조각 안(`apps` 등록) + 기존 `seed.sql`의 notes 행 | 0002에서 `apps` 등록, 플랜/팩은 `seed.sql` |
| 코어 | 0000~0006 전체 | 축소판에서 SECTION 6-A(oauth_states), 6-B(encrypted_credentials), 8(Storage), 9(affiliate) 제거. 3, 4, 6-C, 7 유지 |
| 가입 부트스트랩 | `signup_app='notes'` 필수 | apps 행이 1개면 자동 |
| 함수 EXECUTE 기본 | 스키마 단위 기본 권한 회수는 PUBLIC 기본 EXECUTE에 효과가 없다. 코어는 `0007_core_function_privileges.sql`로 core 전 함수를 회수했다(06장 C-1 해결). 제품 함수는 명시 회수 | 코어 SECTION 10이 public 전체를 회수 |
| Realtime | `supabase_realtime`에 `notes.runs`, `notes.run_steps` 추가 | `public.runs`, `public.run_steps` |
| 이름 충돌 | 없음 | `entries`, `runs`, `run_steps`, `start_run` 등 `public` 이름. 코어 `jobs`와 충돌 없음(확인함) |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| AI 라우팅 기본값 13행 | `2100_notes.sql` 14.1절 | `seed.sql`(같은 13행, 변환 스크립트(NT-06-004)는 14절을 변환 대상에서 제외하고 seed와 값을 비교) |
| 플랜 AI 키 | `2100_notes.sql` 14.2절 병합 UPDATE(코어 요청 C-6) | `seed.sql` free/pro `features`에 직접 |
| 업로드 버킷 `org-files` | 0005가 생성 | 코어 축소판이 SECTION 8을 제거했으므로 `seed.sql`이 `insert into storage.buckets`(이미 있으면 건너뜀). 사용자용 storage 정책은 없고 서버(service_role, 서명 업로드 URL)만 쓴다 |

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `docs/products/_supabase-modular/migrations/2100_notes.sql` | (2026-10-13: 14절 AI·음성 기본값 추가: 라우팅 13행, free/pro AI 키 병합, 체인 검사) 스키마, 7개 테이블, 트리거(`entries_guard_write`, `entries_status_transition`, `runs_status_transition`, updated_at, guard_privileged_write), 함수 7개, 정책, Realtime, 모델 13행, 운영 상한 2행, 플랜/팩 seed |
| `supabase/monolith/migrations/0001_core_lite.sql` | `MONOLITH_CORE_LITE.sql` 복사 + 위 4개 절 제거(주석) |
| `supabase/monolith/migrations/0002_study_note_domain.sql` | 위 조각의 변환본(`core.`/`notes.` → `public.`) |
| `supabase/monolith/seed.sql` | `apps` upsert, Free 플랜(features 포함, AI 키 포함), Pro 플랜(비활성), 크레딧팩 2종(비활성), AI 라우팅 기본값 13행 + 체인 검사, `org-files` 버킷 |

검증 결과(2026-10-13 AI 반영 후, PGlite): `check.mjs --vector mod`(0000~0009 + seed + 2100) OK, `--vector mono`(0001, 0002, seed) OK, 2100과 모놀리스 seed를 각각 2회 연속 적용해도 OK(반복 적용 가능). 아래 스모크 수치는 2026-10-12 측정값이며 AI 행 추가는 제품 표를 바꾸지 않아 영향이 없다.

검증 결과(2026-10-12, PGlite): 체커 모놀리스 OK, 모듈러 OK. RLS/기능 스모크 모놀리스 85/85, 모듈러 84/84 통과(+ 코어 결함 1건 관찰, 아래). 스모크 항목:

| 구분 | 항목 |
|---|---|
| 격리 | 타 조직 사용자가 entries/runs/run_steps/user_settings SELECT 0행, UPDATE/DELETE 0행, 타 조직으로 INSERT 42501, 자기 행을 타 조직으로 이동 42501, 엔타이틀먼트 없는 조직 0행 |
| 권한 | 상태/최종본 직접 변경 42501, `start_run`/`record_step`/`finish_run`/`enforce_retention` 호출 42501, 타 조직 실행 취소 42501, `model_catalog`/`runtime_config`/`cost_guard` 쓰기·읽기 거부, 플랜/크레딧/역할 자기 변경(wallets, credit_ledger, grant_credits, app_entitlements, subscriptions, org_members, profiles.platform_role) 42501 |
| 기능 | 선차감 4, 멱등 재호출, 활성 실행 중복 NT002, 프리미엄 모델 NT004, 크레딧 부족 CR001 후 고아 없음, 일일 상한 NT005 롤백, 부분 성공 환불 3, 카드 재요청(재사용 0 크레딧), 전부 실패 후 `fail_job` 이중 환불 없음, 원장 drift 0, 큐 취소 환불, 보존 50건, 휴지통/복원, 종료 실행 쓰기 NT003 |
| 관찰된 코어 결함(해결) | 모듈러에서 `core.enqueue_job`, `claim_jobs`, `confirm_payment_order` 등을 authenticated가 실행할 수 있었다. `0007_core_function_privileges.sql`이 PUBLIC EXECUTE를 회수해 해결했고 통합 검증에서 확인했다. 모놀리스는 SECTION 10이 막는다 |

### 9.1 AI 라우팅 기본값 검증 (2026-10-13, 모듈러 PGlite)

| 항목 | 결과 |
|---|---|
| `ai_routing_settings`(org null, app `notes`) 행 수 | 13 |
| free/pro `features`에 AI 키 병합 | 기존 키(`max_input_chars` 등)가 유지된 채 `ai_chat`, `ai_chat_turns_per_day`, `ai_subjects_max`, `ai_docs_max`, `ai_doc_max_chars`, `lecture_note`, `lecture_max_minutes`, `voice_chat`, `quiz_voice` 추가 확인 |
| 미동의 조직의 `resolve_ai_route` | `notes.organize`, `notes.quiz`, `chat`, `wiki.*` = `oss-llm`만. `notes.knowledge` = `oss-embed`. `lecture_note`, `voice_chat`, `quiz_voice` stt·tts = `oss-voice`만 |
| `set_ai_cross_border_ack(org, true, 'v1')` 후 | `notes.organize`, `notes.quiz` = oss-llm → anthropic → google. `chat` = oss-llm → anthropic → openai → google. `wiki.*` = oss-llm → anthropic. `voice_chat`·`quiz_voice` stt = oss-voice → elevenlabs, tts = elevenlabs → oss-voice |
| 동의 후에도 오픈소스로 남는 것 | `dify.aux`(강제), `notes.knowledge`(open_source), `lecture_note`(강제) |

AI 기능별 기본값 행(정본 02장 5.3절): `notes.organize`, `notes.quiz`(llm, auto, oss-llm → anthropic → google), `chat`(llm, auto, oss-llm → anthropic → openai → google), `wiki.query`, `wiki.ingest`, `wiki.lint`(llm, auto, oss-llm → anthropic), `dify.aux`(llm, open_source, oss-llm, 강제), `notes.knowledge`(embedding, open_source, oss-embed), `lecture_note`(stt, open_source, oss-voice, 강제), `voice_chat`·`quiz_voice` stt(auto, oss-voice → elevenlabs), `voice_chat`·`quiz_voice` tts(auto, elevenlabs → oss-voice).

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경 없음. 인증 단계는 코어 계약(`core.handle_new_user`, `session_context`, `invite_member`·`accept_invite`, `bootstrap_app_for_org`)을 그대로 쓰고 제품 테이블을 더하지 않는다. 네이버 브리지 경로를 택하면 코어 `auth_identity_links`(`docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`)만 참조한다(06장 C-11).

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.2·2.3절이다. 시드는 `scripts/dev/seed-users.mjs --app notes`(NT-06-006)가 `supabase db reset` 뒤에 로컬 DB에만 만든다. 이메일 도메인은 `.test`(제안).

### 10.1 공통 페르소나 (study-note에서의 기대 결과)

| 키 | 만드는 경로 | 기대 결과(study-note) |
|---|---|---|
| `owner` | `auth.admin.createUser(... user_metadata: { signup_app: 'notes' })` → 가입 트리거 | 개인 조직 owner, `session_context('notes')` `entitled=true`, `free`, 잔액 30(월 지급 1회). 정리 실행 가능 |
| `admin` | 생성 후 owner 세션 `invite_member(owner_org, uid, 'admin')` → 본인 세션 `accept_invite(owner_org)` | owner 조직 admin. `entries` 쓰기·실행 가능 |
| `member` | 같은 경로(`member`) | owner 조직 member. 실행 가능, `POST /api/notes/account/delete` 403(owner 전용) |
| `viewer` | 같은 경로(`viewer`) | owner 조직 viewer. 목록 읽기만, `entries` INSERT 42501(정책이 owner/admin/member만 허용, 4절), 실행 403 |
| `outsider` | `signup_app: 'notes'`로 별도 생성 | 자기 조직 owner. owner 조직의 `entries`·`runs`·`run_steps`·`user_settings`·`ai_documents` 0행(RLS 스모크와 같은 기대) |
| `no_app` | `signup_app` 없이 생성 | 이 제품의 개발 DB는 단독 모놀리스(`public`)라 앱 행이 1개여서 가입 트리거가 자동 부트스트랩해 `entitled=true`. 모듈러 통합 DB에서는 `entitled=false` → Mock 로그인의 `finishLogin`이 `bootstrap_app_for_org('notes')` 1회 후 `entitled=true`, 잔액 30(멱등 키로 재로그인 시 추가 지급 없음) |
| `suspended` | 생성 후 service_role로 `status=suspended` | 403 |
| `ops` | 생성 후 service_role로 `platform_role=platform_admin` | `/admin/models`(Phase 2) 접근 |
| `pending` | 만들지 않는다 | 이 앱은 open이라 approval 상태가 없다 |

### 10.2 study-note 도메인 페르소나 (제품 훅 `scripts/dev/seed-users.notes.mjs`)

| 키 | 만드는 경로 | 기대 결과 | 쓰는 테스트 |
|---|---|---|---|
| `unverified` | `auth.admin.createUser({ email_confirm: false, user_metadata: { signup_app: 'notes' } })` | `entitled=true`, 잔액 30이지만 `email_confirmed_at is null`. `POST /api/notes/runs`, `/api/ai/organize` 등 정리 실행 계열 403 `email_not_verified`(01장 NT-F-001). 읽기와 설정 저장은 가능 | NT-06-005, 024 |
| `low_credit` | `signup_app: 'notes'`로 생성 후 service_role `consume_credits(org, 27, 'notes', 'dev_seed', p_idempotency_key => 'dev-seed:low_credit:<org>')` | 잔액 3. 예상 4 크레딧 실행에서 UI가 "1 크레딧이 부족합니다"(NT-F-011), 강제 요청은 402 `CR001`이고 고아 실행·잡 0 | NT-06-024 |

훅은 모든 페르소나에 약관 동의 감사 기록(`notes_consent.terms`, 제안, 03장 7.3절)을 service_role로 남긴다. 이메일 가입자가 `/signup`에서 동의한 것과 같은 상태로 두어, B단계에서 생기는 `/onboarding/terms` 이동이 Mock E2E(NT-06-024)를 바꾸지 않게 한다.

| 확인 필요 | 내용 |
|---|---|
| `unverified` 로그인 | 로컬 `supabase/config.toml`의 `[auth.email] enable_confirmations = true`에서는 미인증 계정의 `signInWithPassword`가 거부될 수 있다(미확인). 거부되면 이 페르소나는 Mock 로그인 대상에서 빼고, 이메일 인증 가드는 `email_confirmed_at`을 null로 둔 세션 객체를 넣는 단위 테스트(NT-06-005)와 B단계 이메일 가입 E2E(NT-06-053)로 확인한다. 결과는 NT-06-006 task `log.md` `[DECISION]`(06장 8.5절) |
| `low_credit` 차감 | 시드용 차감도 원장(`credit_ledger`)에 남는다. 개발 DB 전용이라 원장 drift 검사에서 `reason='dev_seed'` 행은 정상으로 본다 |

### 10.3 시드 출력과 금지

| 항목 | 규칙 |
|---|---|
| 출력 | 페르소나·이메일·조직 id·플랜·잔액·`email_confirmed_at` 여부 표. 비밀번호(`DEV_SEED_PASSWORD`)는 출력하지 않는다 |
| 원격 차단 | `SUPABASE_URL` 호스트가 `127.0.0.1`·`localhost`가 아니면 exit 1 |
| 기능 코드 | 페르소나 이메일·키로 분기하지 않는다. 권한은 `session_context`로만(`AUTH_ROADMAP.md` 2.5절) |
