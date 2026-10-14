# 05 데이터 모델: 신비로운AI

정본 SQL: 모듈러 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1100_astro.sql`, 모놀리스 `supabase/monolith/migrations/0002_astro_domain.sql`(같은 본문을 12장 규칙으로 변환). 원본 FD DDL 3개 테이블(`FortuneDocs/PRD.MD:103-143`)과 AA의 이름만 있던 테이블(`docs/reference/reviews/Astro_AI.md:48`)을 대체한다.

## 1. 개요와 ERD

```
core.organizations (참조만)
 ├─ astro.preferences        (org 1:1, 기본 테마·이메일 발송)
 ├─ astro.subjects           (보관함 대상, 암호문)
 │    └─ astro.readings      (subject_id+org_id 복합 FK, on delete cascade. 타로는 subject 없음 가능)
 │         ├─ astro.reading_renders (reading_id+org_id 복합 FK, cascade)
 │         │     └─ astro.deliveries (render_id+org_id, reading_id+org_id 복합 FK, cascade)
 │         ├─ core.credit_ledger (credit_ledger_id, 참조만)
 │         └─ core.jobs          (job_id, on delete set null)
 ├─ astro.consents           (동의 증빙, subject_id on delete set null)
astro.themes (전역 참조 데이터) ← readings.theme_key, reading_renders.theme_key, preferences.default_theme_key
```

복합 FK(`(subject_id, org_id) → subjects(id, org_id)`)로 다른 조직 대상을 참조하는 리딩을 DB가 거부한다(스모크 테스트 23503 확인).

AI·음성(2026-10-13)은 코어 표만 참조하고 제품 AI 표를 만들지 않는다(이유는 6절):

```
core AI·음성 (참조만)
 ├─ core.ai_conversations   (사용자 본인, dify_user, channel text/voice)
 │    ├─ core.ai_messages   (citations, provider, credits)
 │    └─ core.voice_sessions ─ core.voice_jobs (feature voice_chat / narration, store_audio=false)
 ├─ core.ai_runs            (graph astro.reading, job_id = astro.readings.job_id, credit_ledger_id = readings.credit_ledger_id)
 │    └─ core.ai_run_steps  (노드 chart, retrieve, draft, compliance, assemble)
 ├─ core.ai_usage           (run_id, conversation_id, feature, settled_at)
 ├─ core.ai_org_settings    (국외 이전 동의) <-> astro.consents(kind overseas_transfer)
 ├─ 운영자 지식 조직(ASTRO_KNOWLEDGE_ORG_ID)만
 │    ├─ core.ai_collections astro-knowledge(kind rag), astro-wiki(kind wiki), 임베딩 oss-embed
 │    │    └─ core.ai_documents ─ core.ai_chunks (vector(1024), HNSW)
 │    └─ core.wiki_pages ─ core.wiki_links, core.wiki_revisions
 └─ core.ai_routing_settings (org null, app astro, 10행: 9절)
Storage exports/<org_id>/astro/narration/<reading_id>.mp3 (낭독, 리딩·대상 삭제 시 함께 삭제)
```

## 2. 테이블

### 2.1 `astro.themes`

목적: PDF 테마 레지스트리(MVP 2종). 사용자 업로드 없음.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `key` | text PK | N | - | `^[a-z][a-z0-9-]{1,40}$`. `mystical-dark`, `oracle-gold`(원본 키 유지, `Astro AI/기획안/공통/DESIGN.md:46-47`) |
| `name` | text | N | - | 표시 이름 |
| `config` | jsonb | N | - | ThemeConfig(색 6개, 서체, A4 프리셋, 표지 스타일). object만 |
| `tier` | text | N | `basic` | basic/premium |
| `is_active` | boolean | N | true | 공개 읽기 필터 |
| `sort_order` | int | N | 0 | |
| `preview_path` | text | Y | - | 렌더 서비스로 만든 첫 페이지 이미지(`public-assets`) |
| `created_at`, `updated_at` | timestamptz | N | now() | 표준 |

### 2.2 `astro.subjects`

목적: 보관함 대상(FD `fortune_targets` 대체, `docs/reference/reviews/FortuneDocs.md:99`).

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid PK | N | gen_random_uuid() | |
| `org_id` | uuid FK core.organizations | N | - | cascade |
| `alias` | text | N | - | 1~20자 호칭 |
| `relation` | text | N | - | self/family/partner/friend/other |
| `gender` | text | N | - | male/female. NOT NULL(대운 순역행 필수, FD #2) |
| `calendar_type` | text | N | solar | solar/lunar |
| `is_leap_month` | boolean | N | false | 음력일 때만 true 허용 |
| `birth_time_unknown` | boolean | N | false | true면 삼주 분석 |
| `zi_hour_mode` | text | N | unified | unified(23시부터 다음 날 일주) / split(야자시·조자시 구분) |
| `birth_place_label`, `birth_longitude` | text, numeric(7,4) | Y | - | 진태양시 보정. null이면 127.0 |
| `name_ciphertext` | text | N | - | 실명(없으면 호칭) AES-256-GCM `v<n>:iv:ct:tag` |
| `birth_ciphertext` | text | N | - | `{"date","time"}` 원문 입력 |
| `key_version` | smallint | N | - | 키 세대 |
| `third_party_consent_at`, `consent_version` | timestamptz, text | Y | - | 본인이 아니면 필수(CHECK) |
| `created_by` | uuid | Y | - | FK 없음 |
| `created_at`, `updated_at` | timestamptz | N | now() | |

제약: 조직당 `relation='self'` 1행(부분 유니크), `(id, org_id)` 유니크. 상한 20명은 서버가 `features.max_subjects`로 강제.

### 2.3 `astro.readings`

목적: 리딩 1건 = 차감 1건 = 잡 1건.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid PK | N | | |
| `org_id` | uuid FK | N | | cascade |
| `subject_id` | uuid | Y | | 복합 FK. saju/combined는 필수(CHECK) |
| `kind` | text | N | | saju/tarot/combined |
| `theme_key` | text FK themes | N | | 최초 렌더 테마 |
| `question_ciphertext`, `key_version` | text, smallint | Y | | 질문(200자) 암호문 |
| `tarot_cards` | jsonb | Y | | tarot/combined면 길이 3 배열 필수, saju면 null |
| `chart` | jsonb | Y | | 엔진 원국 스냅샷(4주, 오행, 십신, 대운) |
| `engine_version` | text | Y | | 엔진 semver(재현성) |
| `status` | text | N | queued | 3절 |
| `progress` | smallint | N | 0 | 0~100 |
| `credits_charged` | int | N | | 15/20/30, 불변 |
| `credit_ledger_id` | bigint FK core.credit_ledger | Y | | 불변 |
| `job_id` | uuid FK core.jobs | Y | | set null |
| `request_id` | uuid | N | | 유일, 멱등 |
| `content`, `content_chars` | jsonb, int | Y | | 장 JSON(`{{호칭}}` 토큰) |
| `current_render_id` | uuid FK reading_renders | Y | | 최신 성공 렌더 |
| `error_code`, `error_message` | text | Y | | |
| `created_by`, `created_at`, `updated_at`, `started_at`, `completed_at`, `failed_at`, `canceled_at` | | | | 전이 시각은 트리거가 채움 |

### 2.4 `astro.reading_renders`

목적: PDF 렌더 이력. 최초 렌더(`is_initial`, 리딩당 1행, 0cr) + 재생성(5cr).

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id`, `org_id`, `reading_id` | uuid | N | | 복합 FK cascade |
| `theme_key` | text FK | N | | |
| `is_initial` | boolean | N | false | |
| `status` | text | N | queued | queued/rendering/succeeded/failed |
| `pdf_path` | text | Y | | `<org_id>/astro/pdf/%` 형식만(CHECK) |
| `pdf_pages`, `pdf_bytes` | int | Y | | |
| `credits_charged`, `credit_ledger_id`, `job_id`, `request_id` | | | | readings와 같은 규칙 |
| `error_code`, `created_by`, `created_at`, `updated_at`, `completed_at` | | | | |

### 2.5 `astro.deliveries`

목적: 이메일 발송 outbox(AA `delivery_logs` 대체, `docs/reference/reviews/Astro_AI.md:85`).

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | bigint identity | N | | |
| `org_id`, `reading_id`, `render_id` | uuid | N | | 복합 FK cascade |
| `channel` | text | N | email | MVP email만. 카카오는 Phase 2에서 CHECK 확장 |
| `status` | text | N | pending | 3절 |
| `recipient_masked` | text | Y | | `a***@x.com` 표시용 |
| `recipient_ciphertext`, `key_version` | text, smallint | Y | | 수신 주소 암호문 |
| `attempts`, `max_attempts` | int | N | 0, 3 | 5분 간격 3회(`Astro AI/기획안/공통/PRD.md:86`) |
| `next_attempt_at` | timestamptz | N | now() | |
| `locked_by`, `provider_message_id`, `last_error`, `sent_at` | | Y | | |
| `created_at`, `updated_at` | | N | | |

제약: `(render_id, channel)` 유일.

### 2.6 `astro.consents`

목적: 동의 증빙(append). 철회는 `granted=false` 새 행. kind: terms_required, privacy_required, third_party_birth, overseas_transfer, marketing_email, voice_processing(2026-10-13 추가). 컬럼: `id`, `org_id`, `user_id`, `subject_id`(set null), `kind`, `version`, `granted`, `ip_hash`, `created_at`.

| kind | 의미 | 함께 기록 |
|---|---|---|
| `overseas_transfer` | 상용 AI·음성 제공자(국외) 이전 선택 동의(01장 AS-F-035). `version` = 고지문 버전 | `core.set_ai_cross_border_ack`가 `core.ai_org_settings`에 같은 버전을 남긴다 |
| `voice_processing` | 첫 마이크 사용 전 음성 처리 고지 확인(녹음 원본 미저장) | 없음. 녹음을 저장하지 않으므로 `voice_jobs.consent_*`는 비워 둔다 |

CHECK는 표를 이미 만든 DB에도 반영되도록 `drop constraint if exists` + `add constraint`로 다시 건다(`D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1100_astro.sql:374-378`).

### 2.7 `astro.preferences`

목적: 조직 설정. `org_id` PK, `default_theme_key`(FK, 기본 mystical-dark), `email_delivery_enabled`(true), `updated_by`, `created_at`, `updated_at`. 권한·과금·상태 컬럼이 없어 멤버 쓰기를 허용한다(`docs/file/03-설계/공용코어/DB_CONVENTIONS.md:8.1절`).

## 3. 상태 전이

모두 BEFORE 트리거(`*_check_transition`)가 강제하며 service_role 쓰기에도 적용된다. 위반은 `AS001`.

### 3.1 `readings.status`

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| (INSERT) | queued만 | Route Handler | 차감 원장, 잡 생성 |
| queued | generating, failed, canceled | 워커 / 스위퍼 / `cancel_reading` | canceled: `cancel_job`이 환불, 감사 |
| generating | rendering, queued(잡 재시도), failed | 워커 | failed: `fail_job` 최종 실패가 자동 환불 |
| rendering | completed, queued(재시도), failed | 워커 | completed: progress 100, 발송 행 생성 |
| completed, failed, canceled | 없음 | - | 재생성은 `reading_renders`로 |

불변: `org_id`, `kind`, `request_id`, `credits_charged`, 한 번 설정된 `credit_ledger_id`.

### 3.2 `reading_renders.status`

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| (INSERT) | queued | Route Handler | 재생성은 5cr 차감 |
| queued | rendering, failed | 워커 | |
| rendering | succeeded(`pdf_path` 필수), queued, failed | 워커 | succeeded: `readings.current_render_id` 갱신 |

### 3.3 `deliveries.status`

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| (INSERT) | pending, skipped | 워커 | skipped: 이메일 발송 꺼짐 |
| pending | sending, skipped, dead | `claim_due_deliveries` / 어드민 | attempts+1 |
| sending | sent, pending(+5분), dead(attempts ≥ max) | `finish_delivery` | |
| dead | pending | 재발송 API / 어드민 | attempts 초기화는 서버가 함께 수행, 감사 |

## 4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) | 이중 잠금 |
|---|---|---|---|---|---|---|
| themes | `is_active` (anon 포함) | 없음 | 없음 | 없음 | select(anon, authenticated) | guard |
| subjects | `is_org_member(org_id) and has_entitlement(org_id,'astro')` | 없음 | 없음 | 없음 | 암호문 2개 제외 컬럼 select | guard |
| readings | 같음 | 없음 | 없음 | 없음 | `question_ciphertext`, `key_version`, `credit_ledger_id` 제외 컬럼 select | guard + 전이 트리거 |
| reading_renders | 같음 | 없음 | 없음 | 없음 | select | guard + 전이 트리거 |
| deliveries | 같음 | 없음 | 없음 | 없음 | 암호문 제외 컬럼 select | guard + 전이 트리거 |
| consents | `is_org_member(org_id)` | 없음 | 없음 | 없음 | select | guard |
| preferences | 멤버 + 엔타이틀먼트 | `with check (멤버 + 엔타이틀먼트)` | `using/with check` 같음 | 없음(조직 cascade만) | select, insert, update | 없음(순수 설정) |

쓰기 정책을 준 `preferences`는 (a) `with check`에 멤버십과 엔타이틀먼트, (b) 권한·과금·상태 컬럼 없음, (c) 상태 없음이라 `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:4장` 완화 조건을 만족한다. 정책 안에서 `org_members`를 직접 조회하지 않고 코어 헬퍼만 쓴다. `FOR ALL` 정책 없음.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `subjects_org_created_idx (org_id, created_at desc)` | 보관함 목록 |
| `subjects_one_self_per_org_idx (org_id) where relation='self'` | 본인 1명 제약 |
| `readings_org_created_idx (org_id, created_at desc)` | 홈·히스토리 |
| `readings_subject_idx (subject_id)` | 대상 상세의 리딩 목록, 삭제 연쇄 |
| `readings_active_idx (status, created_at) where status in (queued, generating, rendering)` | 진행 중 3건 제한, 스위퍼 |
| `reading_renders_reading_idx (reading_id, created_at desc)` | 렌더 이력 |
| `reading_renders_one_initial_idx (reading_id) where is_initial` | 최초 렌더 1행 |
| `deliveries_due_idx (next_attempt_at) where status='pending'` | 발송 루프 클레임 |
| `deliveries_org_created_idx (org_id, created_at desc)` | 발송 상태 표시 |
| `consents_org_user_idx (org_id, user_id, kind, created_at desc)` | 현재 동의 상태 조회 |

예상 규모(제안): MAU 5,000 × 월 리딩 2건 = 월 1만 행. 파티셔닝 불필요.

## 6. 코어 참조

| core 객체 | 용도 |
|---|---|
| `organizations` | 모든 테이블 `org_id` FK |
| `credit_ledger` | `readings.credit_ledger_id`, `reading_renders.credit_ledger_id` |
| `jobs` | `job_id` |
| `apps` | `'astro'` 등록(조각 머리, `on conflict do nothing`) |
| `is_org_member`, `has_org_role`, `has_entitlement`, `is_service_caller`, `is_privileged_session`, `write_audit`, `set_updated_at`, `guard_privileged_write`, `cancel_job` | 정책, 함수, 트리거 |
| `consume_credits`, `grant_credits`, `refund_credits`, `enqueue_job`, `confirm_payment_order`, `rate_limit_hit` | 서버(service_role)만 호출 |

AI·음성 코어 객체(2026-10-13, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | astro 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 채팅 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `astro.reading` 실행 기록, 위키 lint 결과 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, Next.js 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 10행(9절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 해설집·위키 컬렉션(운영자 지식 조직만) | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 사주 용어·해석 위키(운영자 지식 조직만) | FastAPI(쓰기), Next.js 서버(공개 읽기) |
| `voice_sessions`, `voice_jobs` | 음성 대화, STT·TTS·낭독 작업 | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |

제품 AI 표를 만들지 않은 이유(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 대화-리딩 연결 표 | 채팅이 어느 리딩을 근거로 하는지 | Dify 입력 `reading_id`(대화 시작 때) + FastAPI가 매핑 org와 리딩 org를 매번 대조. 대체 경로는 Next.js가 요청마다 `reading_id`를 받아 같은 확인 |
| 낭독 파일 표 | 낭독 mp3 위치와 재사용 | 결정적 Storage 경로 `exports/<org_id>/astro/narration/<reading_id>.mp3` + `voice_jobs`(feature `narration`, `characters`, `provider_id`) |
| 리딩-그래프 연결 컬럼 | 리딩의 AI 실행 추적 | `ai_runs.job_id = readings.job_id` |
| 녹음 동의 표 | 음성 처리 고지 증빙 | `astro.consents` kind `voice_processing` |
| 해설집 문서 표 | 원고 관리 | `core.ai_documents`(운영자 지식 조직) + 원고 파일 `content/knowledge/` |

조각은 `core.*`를 ALTER하지 않는다. 플랜·크레딧·결제·잡 테이블을 `astro`에 다시 만들지 않는다. 13.2절의 `core.plans` UPDATE는 astro 자신의 starter 행 `features`에 AI 키를 병합하는 데이터 변경이며 표 구조는 바꾸지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

나머지 7건(기술·아키텍처)은 `02_ARCHITECTURE.md` 6장. 합계 14건 = 리뷰 "높음" 14건(Astro AI 8, FortuneDocs 6).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reference/reviews/Astro_AI.md` 3장 #2 | `docs/reference/reviews/Astro_AI.md:48` | DB 스키마/ERD 없음, 이름만 있음 | 이 장 1~6절과 `1100_astro.sql`(7개 테이블, 상태 CHECK, 복합 FK, 인덱스). 체커 OK, RLS 스모크 65/65 | AS-06-001, AS-06-002 |
| `docs/reference/reviews/Astro_AI.md` 3장 #4 | `docs/reference/reviews/Astro_AI.md:50` | 실패 시 환불·재시도·상태 머신·멱등 키 없음 | `readings` 전이 트리거 + `credit_ledger_id`로 잡과 연결 → `core.fail_job` 최종 실패 자동 환불(`D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0005_core_jobs_storage.sql:231-234`), 대기 취소는 `astro.cancel_reading` → `core.cancel_job` 환불(스모크: 취소 후 잔액 30 복원). 멱등: `request_id` 유일 + `consume:astro:<id>`/`job:astro:<id>`. enqueue 실패 시 Route Handler 동기 환불. 스위퍼가 잡과 리딩 상태 불일치를 정리 | 3.1절, AS-06-010, AS-06-012 |
| `docs/reference/reviews/Astro_AI.md` 3장 #5 | `docs/reference/reviews/Astro_AI.md:51` | 업로드 ThemeConfig가 CSS로 렌더러에 들어가 SSRF·파일 읽기 | 사용자 테마 업로드 경로를 없앴다: `themes`는 guard 트리거로 service_role만 쓰고 사용자 정책 없음. 운영자 테마도 zod/pydantic 화이트리스트(hex 색 `^#[0-9A-F]{6}$`, 서체 열거형, 숫자 범위)를 통과한 값만 변환기가 CSS 변수로 만든다(`url(`, `@import`, `\` 문자 거부). 렌더 서비스 `url_fetcher`는 자체 Storage만(`docs/file/03-설계/공용코어/SHARED_MODULES.md:269`) | AS-06-013, AS-06-014 |
| `docs/reference/reviews/Astro_AI.md` 3장 #6 | `docs/reference/reviews/Astro_AI.md:52` | `approveTemplate`가 role 확인 없이 service_role로 승인 | 검수 기능은 폐기(07장). 어드민 쓰기 Route Handler는 `requireSession` 후 `platform_role='platform_admin'` 재검증을 service_role 클라이언트 생성보다 먼저 하고 감사 기록. 상태 컬럼이 있는 표는 사용자 쓰기 정책이 없고 guard 트리거로 이중 잠금(스모크: B의 `update readings` 42501) | 4절, AS-06-022 |
| `docs/reference/reviews/FortuneDocs.md` 3장 #3 | `docs/reference/reviews/FortuneDocs.md:42` | 입력 모델과 DDL 불일치(윤달, 자시, 출생지, 생시 모름 컬럼 없음) | `subjects`에 `is_leap_month`(음력 CHECK), `zi_hour_mode`, `birth_time_unknown`, `birth_longitude`, `gender NOT NULL`. 생시 모름이면 엔진이 삼주 분석(시주 null)으로 계산하도록 사양 고정 | 2.2절, AS-06-004 |
| `docs/reference/reviews/FortuneDocs.md` 3장 #4 | `docs/reference/reviews/FortuneDocs.md:43` | `fortune_books FOR ALL`로 사용자가 리포트 직접 INSERT, `WITH CHECK` 없음 | `readings`에 INSERT/UPDATE GRANT와 정책이 없고 guard 트리거로 42501. 생성은 차감 후 서버만. 사용자 쓰기 표(`preferences`)는 `with check` 필수, 다른 조직 대상 참조는 복합 FK로 거부(스모크: B 무료 생성 시도 42501, org_id 바꾸기 42501, 타 조직 subject 23503) | 4절, AS-06-002 |
| `docs/reference/reviews/FortuneDocs.md` 3장 #5 | `docs/reference/reviews/FortuneDocs.md:44` | 원자 차감·단가·환불·크레딧 로그·가입 트리거 없음 | 코어 `wallets FOR UPDATE` 원자 차감과 append-only 원장(`docs/file/03-설계/공용코어/CORE_SPEC.md:169-175`), 가입 트리거(`:77`)를 쓰고 제품 테이블에는 잔액 컬럼을 두지 않는다. 크레딧 RPC는 service_role 전용(스모크: B `grant_credits`/`consume_credits`/`update wallets` 42501). 단가는 01장 4.2절, 환불은 3.1절 | AS-06-010, AS-06-009 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `astro` + `core` | `public` 하나(최종 확정 대기, 01장 D-9) |
| 코어 | `0000~0006` 전부 | `0001_core_lite.sql`에서 SECTION 6-A(oauth_states), 6-B(encrypted_credentials), 9(affiliate) 제거. 3, 4, 6-C, 7, 8 유지 |
| apps 행 | `schema_name='astro'` | `schema_name='public'` |
| 가입 부트스트랩 | `signup_app='astro'` 필수 | apps 1행이라 자동 |
| 기본 권한 | 스키마에 기본 권한 없음 | 테이블마다 `revoke all from public, anon, authenticated` 후 GRANT |
| 가입 크레딧 | 모듈러 seed도 `signup_credits=0`(2026-10-13 갱신, 모놀리스와 일치) | `signup_credits=0` + `features.welcome_credits=30`(인증 후 서버 지급, 01장 D-3) |
| 크레딧팩 | 단가표 정본 4종(2026-10-13 갱신) | 단가표 정본 4종 |
| Realtime | `astro.readings`, `astro.reading_renders` 발행 | `public.` 같은 표 |
| 앱 설정 | `SUPABASE_DB_SCHEMA=core`, `ASTRO_DB_SCHEMA=astro` | 둘 다 `public` |
| PII 암호화 | 제품 표 암호문 컬럼(앱 계층). `core.encrypted_credentials`는 쓰지 않는다 | 같음(그래서 6-B 제거) |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| AI 라우팅 기본값 | `1100_astro.sql` 13.1절 | `seed.sql`(같은 10행) |
| starter AI 키 | `1100_astro.sql` 13.2절 병합 UPDATE(모듈러 `seed.sql` 반영 요청 R-9) | `seed.sql` starter `features`에 직접 |
| 체인 검사 | 13.3절 DO 블록(제공자 행이 없으면 건너뜀) | `seed.sql` 끝 DO 블록(제공자는 0001이 먼저 넣음) |

## 9. 마이그레이션 파일

| 파일 | 내용 | 검증(2026-10-12, PGlite) |
|---|---|---|
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1100_astro.sql` | 스키마, 7개 표, 전이 트리거 3개, RLS, 함수 3개, Realtime, 테마 2행, 13절 AI·음성 기본값(라우팅 10행, starter AI 키, 체인 검사) | `check.mjs mod` 0000~0007 + seed + 1100 OK, 2회 반복 적용 OK. 파일 끝 12절에서 `astro` 함수의 PUBLIC EXECUTE를 회수(0007과 같은 규칙), 모놀리스는 제품 함수만 하나씩 회수 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 축소판 복사본(제거 절은 주석, SECTION 11·12 AI·음성 포함) | `check.mjs mono` OK |
| `supabase/monolith/migrations/0002_astro_domain.sql` | 1100 조각을 변환(consents `voice_processing` 포함) | OK |
| `supabase/monolith/seed.sql` | apps 1행, starter 플랜(AI 키 포함), 크레딧팩 4종, AI 라우팅 기본값 10행 + 체인 검사 | OK, 반복 적용 OK |

2026-10-13 재검증(PGlite `--vector`, `D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs`):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `1100_astro.sql` | 전부 OK |
| `check.mjs --vector mono` 0001 + 0002 + `seed.sql` | 전부 OK |
| 제품 파일 2회 반복 적용 후 `ai_routing_settings`(org null, app astro) | 10행(모듈러·모놀리스) |
| starter `features` | 기존 키 + `ai_chat`, `ai_chat_turns_per_day`(200), `voice_chat`, `narration` |
| 미동의 조직 `resolve_ai_route` | `astro.reading` = oss-llm, `narration` = oss-voice, `voice_chat` stt = oss-voice, `astro.knowledge` = oss-embed |
| 동의 후 | `astro.reading` = anthropic → openai → google → oss-llm, `narration` = elevenlabs → oss-voice, `dify.aux`는 계속 oss-llm(강제), `WIKI.Lint `(대소문자·공백)도 `wiki.lint` 행으로 해석 |
| `consents` kind `voice_processing` INSERT | 성공 |
| 잘못된 체인 행(tts 기능에 anthropic) 뒤 13절 재적용 | `astro routing defaults: invalid chain providers` 예외 |

AI 기능별 기본값 행(정본 02장 5.1절): `astro.reading`, `chat`(llm, auto, anthropic → openai → google → oss-llm), `wiki.query`, `wiki.ingest`, `wiki.lint`(llm, auto, oss-llm → anthropic), `dify.aux`(llm, open_source, oss-llm, 강제), `astro.knowledge`(embedding, open_source, oss-embed), `voice_chat` stt(auto, oss-voice → elevenlabs), `voice_chat` tts(auto, elevenlabs → oss-voice), `narration` tts(auto, elevenlabs → oss-voice, 작업 중 대체 금지는 음성 어댑터).

RLS 스모크 결과(사용자 A·B 서로 다른 조직, X는 엔타이틀먼트 없음): 모듈러 65/65, 모놀리스 64/64(엔타이틀먼트 없는 조직 항목은 모놀리스 자동 부트스트랩이라 제외) 통과.

| 검사 | 기대 | 결과 |
|---|---|---|
| B가 A의 subjects, readings, reading_renders, deliveries, consents, preferences, core wallets/credit_ledger/jobs/app_entitlements/subscriptions SELECT | 0행 | 0행 |
| B 암호문 컬럼 SELECT(자기 조직 포함) | 42501 | 42501 |
| B subjects INSERT(A 조직, 자기 조직), readings UPDATE/INSERT, subjects DELETE, consents INSERT | 42501 | 42501 |
| B preferences INSERT(A) / org_id를 A로 UPDATE / A 행 UPDATE | 42501 / 42501 / 0행 | 일치 |
| B preferences 자기 조직 INSERT·UPDATE(양성) | 1행 | 1행 |
| B `cancel_reading`(A) / `claim_due_deliveries` / `finish_delivery` / `cancel_job`(A) | 42501 | 42501 |
| B wallets UPDATE, credit_ledger INSERT, `grant_credits`, `consume_credits`, app_entitlements·subscriptions UPDATE, profiles.platform_role UPDATE, org_members.role UPDATE | 42501 | 42501 |
| anon themes / subjects / readings | 2행 / 42501 / 42501 | 일치 |
| B 트리거 함수 직접 호출, anon `cancel_reading`(PUBLIC EXECUTE 회수 확인) | 42501 | 42501 |
| X(엔타이틀먼트 없음, 모듈러) preferences INSERT | 42501 | 42501 |
| A `cancel_reading`(자기 queued) → 잔액 복원 30, 잡 canceled, 재취소 | canceled / 30 / canceled / AS002 | 일치 |
| service 전이 위반(canceled→generating, kind 변경, INSERT completed, 렌더 succeeded without pdf) | AS001 | AS001 |
| service 카드 2장, saju에 subject 없음, 제3자 동의 없음, 다른 조직 PDF 경로 | 23514 | 23514 |
| service 다른 조직 subject 참조 | 23503 | 23503 |
| outbox 실패 1회 → pending, 3회 → dead, dead에 finish | pending / dead / AS003 | 일치 |
| 원장 drift | 0 | 0 |

스모크 스크립트는 저장소 `supabase/tests/rls_smoke`로 옮기는 작업이 AS-06-002다. 금액 불일치 시 주문 failed 기록은 코어 `fail_payment_order`(2026-10-13 반영)를 `PM001` 처리에서 별도 호출로 쓴다(02장 6절 AA #7).

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경 없음. 인증 단계는 코어 계약(`session_context`, RLS)을 그대로 쓰고, 이 제품은 표·컬럼·함수를 추가하지 않는다. C2에서 브리지 경로를 택하면 코어 보류 마이그레이션 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`(`core.auth_identity_links`)을 참조만 한다(06장 8절 R-14).

시드는 `scripts/dev/seed-users.mjs --app astro`(공통, `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2.3절)가 공통 행을 만든 뒤 제품 훅 `scripts/dev/seed-users.astro.mjs`(제안)를 실행한다. `supabase db reset` 뒤 로컬에서만 실행하고(호스트가 루프백이 아니면 종료), 계정은 `auth.admin.createUser(..., email_confirm: true, user_metadata: { signup_app: 'astro', full_name })`로 만들어 실제 가입 트리거를 탄다. astro는 가입 크레딧이 0이고(`signup_credits=0`, 8절) 환영 크레딧 30은 인증 확인 뒤 서버가 지급하므로(01장 AS-F-002), 지급 여부를 훅이 페르소나별로 정한다.

| 키 | 이메일 | 만드는 방법 | 기대 `session_context('astro')`와 잔액 | 쓰임 |
|---|---|---|---|---|
| `owner` | `owner@dev.test` | 공통 생성 후 훅이 service_role `grant_credits(org, 30, 'astro', 'welcome_credits', 'pack', 'signup', user_id, 'signup:<org>:astro')`(04장 2절 `POST /api/auth/welcome`과 같은 인자·멱등 키) | 개인 조직 owner, `entitled=true`, `plan_code='starter'`, 잔액 30, 원장 환영 행 1 | 기본 사용자, 리딩·채팅 E2E |
| `admin`, `member`, `viewer` | `admin@dev.test` 등 | 공통(owner 조직에 `invite_member` → `accept_invite`) | owner 조직의 각 역할. 본인 개인 조직에는 환영 크레딧을 지급하지 않는다(잔액 0) | 코어 역할 분기 회귀. astro 화면은 owner 기준(03장 1절)이고 멤버 초대 화면이 없다(02장 3절 org 행) |
| `outsider` | `outsider@dev.test` | 공통 생성 후 훅이 owner와 같은 방법으로 30 지급 | 자기 조직 owner, 잔액 30 | 교차 테넌트 거부: owner의 보관함·리딩·대화 0행, 다른 조직 `reading_id` 채팅 404 |
| `no_app` | `no_app@dev.test` | 공통(`signup_app` 없음) | 모듈러: `entitled=false` → 첫 Mock 로그인에서 `finishLogin`이 `bootstrap_app_for_org` 1회 → `entitled=true` → 환영 크레딧 30(1회). 모놀리스: 트리거가 자동 부트스트랩해 처음부터 `entitled=true`, 잔액 0 → 첫 로그인 뒤 30 | 첫 진입 부트스트랩과 환영 크레딧이 한 번만 일어나는지 |
| `suspended` | `suspended@dev.test` | 공통(service_role로 `status=suspended`) | 403 | 차단 확인 |
| `ops` | `ops@dev.test` | 공통(service_role로 `platform_role=platform_admin`) | 운영자 | `/admin`, `/admin/wiki`, `/admin/knowledge` |
| `welcome_pending` | `welcome_pending@dev.test` | `signup_app='astro'`, `email_confirm: true`로 생성하고 훅이 환영 크레딧을 지급하지 않는다(astro 추가 페르소나, `AUTH_ROADMAP.md` 8장) | `entitled=true`, `plan_code='starter'`, 잔액 0, 환영 원장 행 0. 첫 Mock 로그인 뒤 `finishLogin` 5번(04장 8절)이 지급해 잔액 30, 재로그인 3회 뒤에도 환영 원장 행 1 | 환영 크레딧 미지급 상태: "인증 확인 뒤 1회 지급"(AS-F-002) 경로를 Mock 단계에서 검증. B단계 B-1, C1-1, C2-2와 같은 기대값 |

| 규칙 | 내용 |
|---|---|
| `pending` | astro는 open 앱이라 만들지 않는다(approval 앱만) |
| 미인증 계정 | 로컬 `enable_confirmations = true`에서는 미인증 이메일의 비밀번호 로그인이 거부되므로(Supabase 동작, 미확인) "미인증 잔액 0" 기준은 Mock 페르소나가 아니라 AS-06-009의 서버 단위 테스트(`email_confirmed_at` null 사용자로 `/api/auth/welcome` 409)로 검사한다 |
| 멱등 키 공유 | 환영 크레딧 키 `signup:<org>:astro`는 코어 가입 크레딧 키(`migrations/0003_core_credits.sql:426`, `on_signup_app_bootstrap`)와 같은 문자열이다. astro 플랜의 `signup_credits=0`이라 코어는 이 키로 원장 행을 만들지 않고(`> 0`일 때만 지급), 그래서 환영 지급이 막히지 않는다. 모놀리스·모듈러 seed 모두 0이며(01장 D-3), 이 값을 0보다 크게 바꾸면 환영 크레딧이 멱등 처리로 지급되지 않으니 D-3을 다시 정한다 |
| IP 해시 보류와 반복 실행 | 같은 IP 해시 하루 3회 초과 보류(AS-F-002)는 실제로 지급할 때만 센다(제안: 멱등 키로 이미 지급된 조직이면 `rate_limit_hit`을 부르지 않는다). 로컬에서는 모든 페르소나가 같은 IP라, 먼저 세면 E2E를 반복할 때 `welcome_pending`·`no_app` 지급이 보류된다 |
| 재시드 | 멱등: 이미 있는 이메일은 건너뛰고 역할·상태만 맞춘다. `welcome_pending`이 한 번 로그인해 30을 받은 뒤 미지급 상태로 되돌리려면 `supabase db reset` 후 다시 시드한다(원장은 append-only라 훅이 회수하지 않는다) |
| 도메인 데이터 | 보관함 대상·리딩·대화는 시드하지 않는다(제안). E2E가 각 페르소나로 API를 호출해 만든다 |
| 모놀리스/모듈러 | 이 개발은 단독 `public` 모놀리스(01장 D-9, `docs/develop/astro-ai/astro-ai_develop.md` 1절)라 `no_app`도 자동 부트스트랩되어 402 경로를 볼 수 없다. 402·부트스트랩 검증은 모듈러 통합 DB에서만 의미가 있다(`--app`을 여러 번 주면 두 번째 앱부터 `bootstrap_app_for_org`) |
