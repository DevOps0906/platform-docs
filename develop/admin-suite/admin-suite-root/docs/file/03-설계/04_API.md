# 04 API: Admin Suite

스키마 표기: 모듈러는 `erp.*`, `sms.*`, 코어 `core.*`. 모놀리스는 전부 `public.*`(함수 이름과 시그니처 동일). hms는 모놀리스만이라 `public.*`.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | Route Handler/Server Action 첫 줄 `requireSession(appId)`(`SHARED_MODULES.md` 2장) → `requireRole(appId, roles)`(admin-kit). 앱 역할은 `<app>.my_role(org)` 결과 |
| 2차 검사 | 모든 쓰기 RPC가 DB 안에서 `is_service_caller()` 또는 역할 헬퍼로 다시 검사한다. 앱 검사를 생략해도 데이터는 열리지 않는다 |
| 호출 주체 | 도메인 쓰기는 사용자 세션 클라이언트로 RPC 호출(감사 행위자 = 사용자). service_role은 프로비저닝, `approve_profile`, Auth Admin 초대, 스케줄에만 |
| 멱등 | 판매는 `request_id`(클라이언트 UUID, 8~100자) 필수. 입출고는 선택. 같은 키 재호출은 기존 행 반환 |
| 크레딧 | 해당 없음(차감 작업 없음) |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }`. `code`는 SQLSTATE 또는 HTTP 사유 |
| 입력 검증 | zod. RPC 인자 타입은 `pnpm db:types` 생성 타입 |
| 레이트 리밋 | 01장 5절. 키 `<app>:<route>:<user_id 또는 ip_hash>`, `rate_limit_hit`(service_role) |
| 캐시 | 모든 인증 응답 `Cache-Control: private, no-store`. hms 의료 응답은 필수 |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler가 부른다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299`). 진입부는 다른 Route Handler와 같다: `requireSession(appId)` → `requireRole(appId, roles)`. 단 AI 경로는 역할 목록 대신 "허용 컬렉션이 1개 이상인 역할"을 `collections.json`으로 판정한다(SMS student는 거부) |
| 서명 토큰 | `src/server/ai/token.ts`(admin-kit gateway)가 EdDSA JWT를 발급: `iss=<app>`, `aud=platform-ai:<app>`, `org`, `app`, `sub`(사용자 id), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 세션에서만 가져온다(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:33-42`). 토큰 클레임에 역할을 넣지 않는다(역할은 FastAPI가 DB에서 확정, 02장 5.3절) |
| AI 크레딧 | 해당 없음. 선차감·정산·환불 없음(01장 4.1절, D-10). 한도는 `features.ai_*` + `core.rate_limit_hit`. `CR001`은 발생하지 않는다 |
| AI 레이트 리밋 | 키 `<app>:ai-chat:<user>` 20회/60초, `<app>:ai-chat-day:<user>` `ai_turns_per_day`/86400초, `<app>:voice-stt:<user>` 10회/60초, `<app>:ai-upload:<org>` 20회/3600초, `<app>:wiki-ingest:<org>` 5회/3600초(01장 4.1절) |
| 스트리밍 | 채팅은 SSE(`text/event-stream`): 이벤트 `delta`, `citations`, `fallback`, `done` / `error`. 응답 봉투 규칙은 JSON 응답에만 적용 |
| 멱등 | 채팅 `request_id`(클라이언트 UUID)로 같은 질문 재전송 시 새 턴을 만들지 않고 이전 턴을 반환. 한도 카운트도 1회만 |

## 2. Route Handler

대부분의 화면은 Server Component가 사용자 세션으로 테이블/RPC를 직접 읽고, 쓰기는 Server Action을 쓴다. 별도 Route Handler가 필요한 것만 적는다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/auth/callback` | 공개 | `code` | 302 역할 홈 | - | `session_context` | 프로필 없음 → 로그아웃 |
| `POST /api/erp/join` | 로그인(pending 포함) | `{ joinCode: /^[A-Z2-9]{8}$/, name: 1..80, message?: ..500 }` | join_request | - | (`erp.request_join`) | P0002, ER005, 429 |
| `POST /api/erp/join-requests/:id/decide` | master_admin, `max_members` | `{ approve: boolean, erpRole, departmentId?, note? }` | join_request | - | `erp.decide_join_request` → 승인 시 service_role `approve_profile(user)` | 42501, ER002, 402(한도) |
| `POST /api/erp/products/:id/image` | master_admin, inventory_manager, `storage_mb` | `{ mime: jpeg/png/webp, size <= 5MB }` | 서명 업로드 URL, path | - | storage 정책 | 413, 415 |
| `GET /api/erp/sales/trend` | master_admin, sales_manager | `{ from, to, bucket }` 기간 <= `sales_trend_days` | 버킷 배열 | - | `erp.sales_trend` | 22023 |
| `POST /api/sms/members/invite` | admin, `max_students` | `{ email, smsRole, displayName, classId?, studentNo?, guardianConsent?: true(14세 미만) }` | member | - | service_role Auth `inviteUserByEmail({data:{signup_app:'sms'}})` → 사용자 세션 `sms.invite_school_member` | 22023, 402 |
| `POST /api/hms/staff/invite` | admin, `max_staff` | `{ email, role, displayName, specialty? }` | staff_profile | - | Auth 초대 → `invite_staff` | 22023, 402 |
| `POST /api/hms/patients` | admin, staff | `{ chartNo, name, sex, birthDate, phone, bloodType?, allergies?, crmTags[], consent: true }` | patient | - | 서버가 phone 암호화 → `register_patient` | HM006, 23505(차트번호) |
| `GET /api/hms/patients/:id` | admin, staff, doctor | `?purpose=` | 상세(phone 복호화) | - | `get_patient_detail` | 42501, 22023 |
| `GET /api/hms/patients/:id/chart` | doctor | `?purpose=treatment` | 타임라인(본문 복호화) | - | `get_patient_chart` | 42501 |
| `POST /api/hms/records` | doctor | `{ patientId, appointmentId?, recordType, body: 1..20000, amendsId? }` | record id | - | 서버 암호화 → `add_medical_record` | 22023 |
| `GET /api/hms/access-log.csv` | admin | `{ from, to }` | CSV | - | `phi_access_log` SELECT + `write_audit('phi_access_log.export')` | 403 |
| `POST /api/billing/checkout` | owner(erp, sms) Phase 2 | `{ planCode: 'standard' }` | Toss 결제창 파라미터 | - | `payment_orders` INSERT(service) | 409 |
| `POST /api/billing/confirm` | owner | `{ paymentKey, orderId, amount }` | 구독 | - | `confirm_payment_order` | PM001/PM404/PM409/PM410 |
| `POST /api/webhooks/toss` | 공개(서명) | rawBody | 200 | - | `webhook_events` | 401 |

### 2.1 AI·음성 Route Handler (2026-10-13)

세 앱이 같은 경로를 쓴다(구현은 `packages/admin-kit/src/ai/gateway/`의 팩토리, 앱 폴더에는 얇은 re-export). 서명 토큰 scope와 호출 대상은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158`, `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:22-38`을 따른다. 크레딧은 전부 해당 없음이라 표에서 뺐다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/ai/consent` (erp, sms만) | owner | `{ granted: boolean, noticeVersion }`(서버 상수와 같아야 함) | 204 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })` | 409 `CONSENT_VERSION_MISMATCH`, 403, hms는 라우트 없음(404) |
| `POST /api/ai/conversations` | 허용 컬렉션 있는 역할, `ai_assistant` | `{ channel: 'text'\|'voice' }` | `{ conversationId }` | 없음 | `ai_conversations` INSERT(service_role, erp·sms는 `dify_user`=HMAC(org:user)) | 403 `AI_DISABLED`·`AI_NO_PERMISSION` |
| `POST /api/ai/chat` | 대화 주인 | `{ conversationId, requestId, message(1..1000) }` | SSE `delta`, `citations`, `fallback`, `done` / `error` | erp, sms: Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`). Dify 장애 시와 **hms 항상** FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=admin.assistant`) | `rate_limit_hit` 3종, 사용자 `ai_messages` INSERT | 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 422 `AI_PHI_BLOCKED`(hms), 403 `AI_NO_PERMISSION`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 503 `AI_UNAVAILABLE` |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | erp, sms: Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), `write_audit('ai.conversation.delete')` | 404 |
| `GET /api/ai/knowledge/documents` | 앱 관리자 | `?collection=&status=` | 문서 목록(제목, 상태, 청크 수, 검수일) | - | `ai_documents` SELECT(service_role, 조직 필터) | 403 |
| `POST /api/ai/knowledge/documents` | 앱 관리자, `ai_docs_max` | multipart `{ file(md, txt, pdf, docx, 20MB 이하), collection, noPii: true, reviewedAt? }` | `{ documentId }` | FastAPI `/rag/ingest`(scope `rag`) | `ai-docs` 버킷 저장(service_role), `ai_documents` INSERT, `write_audit('ai.knowledge.upload')` | 409 중복(`content_hash`), 402 상한, 413, 415, 422 `AI_DOC_PII_DETECTED`(hms는 환자 정보), 403 |
| `POST /api/ai/knowledge/documents/[id]/retry` | 앱 관리자 | - | `{ documentId }` | FastAPI `/rag/ingest` | `ai_documents.status='pending'` | 404, 409 상태 |
| `DELETE /api/ai/knowledge/documents/[id]` | 앱 관리자 | - | 204 | FastAPI(청크 삭제) | `ai_documents.status='deleted'`, 감사 | 404 |
| `POST /api/ai/wiki/ingest`, `POST /api/ai/wiki/lint` | 앱 관리자, `ai_wiki` | `{ documentIds?: uuid[] }` | `{ runId }` | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | - | 403, 429 |
| `PATCH /api/ai/wiki/pages/[...slug]` | 앱 관리자, `ai_wiki` | `{ expectedVersion, bodyMd?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 R-10과 같은 요청) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |
| `GET /api/ai/usage` | 앱 관리자(전원은 본인 남은 질문 수만) | `?from=&to=` | 집계 | - | `ai_usage` 집계(service_role) | 403 |
| `POST /api/voice/consent` | 로그인 + `ai_voice` | `{ noticeVersion }` | 204 | - | `write_audit('ai.voice.notice_ack', 고지문 버전)` + 서명된 쿠키 | 409 `CONSENT_VERSION_MISMATCH`, 403 `AI_DISABLED` |
| `POST /api/voice/sessions` | 로그인 + `ai_voice` | `{ conversationId }` | `{ sessionId }` | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), sessionId, requestId }` | `{ text, durationSeconds, provider }` | `resolve_ai_route(org, app, 'voice_chat', 'stt')` → erp, sms: `oss-voice` → (동의 시) ElevenLabs SDK / **hms: `hms-voice`만**(scope `voice`) | `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 429, 503 |
| `POST /api/voice/tts` | 메시지 주인 | `{ messageId, requestId }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | `voice_chat`/`tts` 체인(hms는 `hms-voice`만) | `voice_jobs`, `ai_usage` | 404, 429, 503 |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`). 위키 페이지 읽기는 서버 컴포넌트가 사용자의 허용 컬렉션 범위로 필터해 service_role로 읽는다(사용자 입력은 slug 조회뿐).

## 3. RPC (SECURITY DEFINER)

모든 사용자용 RPC: `set search_path = ''`, 호출자 판정 `is_service_caller()`, 역할은 exists 헬퍼 또는 `coalesce`, EXECUTE는 authenticated + service_role만(PUBLIC/anon 회수). 코어 RPC는 `CORE_SPEC.md` 2.4, 3, 11장을 인용만 한다.

AI·음성 코어 RPC 인용(제품 AI RPC는 새로 만들지 않는다): `set_ai_cross_border_ack`(사용자 세션, owner/admin, erp·sms만 호출, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575`), `resolve_ai_route`(service_role: FastAPI, Next.js 음성, `:419-476`), `match_ai_chunks`(FastAPI만, `:369-412`), `purge_wiki_page`(운영 도구, `:578-601`). `set_ai_routing`(`:483-550`)은 제품 화면에서 부르지 않는다. 녹음을 저장하지 않으므로 `expire_voice_audio`는 쓰지 않는다. 크레딧 RPC(`consume_credits` 등)는 모놀리스에 없고 쓰지 않는다.

### 3.1 공통 헬퍼(앱마다 같은 이름)

| 함수 | 반환 | 의미 |
|---|---|---|
| `has_access(p_org uuid)` | boolean | 활성 프로필 + 활성 워크스페이스 + 엔타이틀먼트 + 활성 멤버십 + (core owner/admin 또는 활성 도메인 구성원 행) |
| `has_role(p_org uuid, p_roles text[])` (erp, hms) / `is_admin`, `is_staff` (sms) | boolean | 역할 판정. 관리자 역할은 core owner/admin에서 파생 |
| `my_role(p_org uuid)` | text | erp: master_admin/inventory_manager/sales_manager/staff, hms: admin/doctor/staff/lab_tech, sms: admin/teacher/student, 접근 불가 null |
| `register_workspace(p_org_id, p_name)` | workspace | service_role 전용 |

### 3.2 ERP

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `erp.get_join_code(p_org_id)` | authenticated | master_admin | text | 42501 |
| `erp.rotate_join_code(p_org_id)` | authenticated | master_admin | text | 42501, P0002 |
| `erp.update_workspace_settings(p_org_id, p_company_name, p_default_safety_stock, p_low_stock_alert)` | authenticated | master_admin, 감사 | workspace | 42501, P0002 |
| `erp.request_join(p_join_code, p_applicant_name, p_message)` | authenticated | 로그인, 이미 멤버 아님, 대기 요청 있으면 그 행 | join_request | P0002, ER005 |
| `erp.cancel_join_request(p_request_id)` | authenticated | 본인 pending | join_request | P0002 |
| `erp.decide_join_request(p_request_id, p_approve, p_erp_role, p_department_id, p_note)` | authenticated | master_admin, pending, 역할/부서 유효. 승인 시 `core.invite_member(...,'member')` + employees upsert, 감사 | join_request | 42501, ER002, 22023 |
| `erp.set_employee_role(p_org_id, p_user_id, p_erp_role)` | authenticated | master_admin, 자기 자신 불가, 감사 | employee | 42501, 22023, P0002 |
| `erp.set_employee_status(p_org_id, p_user_id, p_status)` | authenticated | master_admin, 자기 자신·core owner/admin 대상 불가, 감사 | employee | 42501, 22023 |
| `erp.update_employee_profile(p_org_id, p_user_id, p_department_id, p_position, p_phone, p_display_name)` | authenticated | master_admin, 부서 소속 확인, 감사 | employee | 42501, 22023 |
| `erp.update_my_contact(p_org_id, p_phone)` | authenticated | has_access, 본인 행 | employee | 42501 |
| `erp.record_inventory_move(p_product_id, p_move_type, p_quantity, p_reason, p_request_id)` | authenticated | master_admin/inventory_manager 전부, sales_manager OUT만. 멱등, 음수 결과 차단, ADJUSTMENT 사유 + 감사 | inventory_move | 42501, 22023, ER001 |
| `erp.record_sale(p_product_id, p_quantity, p_request_id, p_status)` | authenticated | master_admin/sales_manager, 단가 서버 고정, 조건부 차감 | sale | 42501, 22023, ER001, ER003 |
| `erp.complete_sale(p_sale_id)` | authenticated | 같음, pending만 | sale | ER002, ER001 |
| `erp.cancel_sale(p_sale_id, p_reason)` | authenticated | 같음, 사유, completed면 재고 복원, 감사 | sale | ER002, 22023 |
| `erp.dashboard_metrics(p_org_id)` | authenticated | has_access | jsonb | 42501 |
| `erp.sales_trend(p_org_id, p_from, p_to, p_bucket)` | authenticated | master_admin/sales_manager, 366일 | table | 42501, 22023 |

직접 테이블 쓰기(RLS 정책 + 컬럼 GRANT): `erp.departments`(master_admin), `erp.products`(master_admin/inventory_manager, quantity 제외 컬럼).

### 3.3 SMS

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `sms.update_workspace_settings(p_org_id, p_school_name, p_school_year, p_teacher_backfill_days)` | authenticated | admin | workspace | 42501 |
| `sms.invite_school_member(p_org_id, p_user_id, p_sms_role, p_display_name, p_class_id, p_student_no)` | authenticated | admin, 자기 초대 불가, 학급 소속, 대상이 core admin 아님. `core.invite_member` 호출 | member | 42501, 22023 |
| `sms.accept_school_invite(p_org_id)` | authenticated | 본인 invited, `core.accept_invite` 함께 | member | P0002 |
| `sms.set_member_role(p_org_id, p_user_id, p_sms_role)` | authenticated | admin, 자기 자신 불가 | member | 42501 |
| `sms.assign_class(p_org_id, p_user_id, p_class_id, p_student_no)` | authenticated | admin, 학생만 | member | SM003 |
| `sms.set_member_status(p_org_id, p_user_id, p_status)` | authenticated | admin, 자기 자신 불가 | member | 42501 |
| `sms.mark_attendance(p_subject_id, p_student_id, p_attend_date, p_status, p_note)` | authenticated | admin/teacher, 미래 불가, teacher 소급 한도, 학생이 그 학급 활성 학생 | attendance | SM001, SM002 |
| `sms.mark_attendance_bulk(p_subject_id, p_attend_date, p_entries jsonb)` | authenticated | 위 + 200건 | integer | 22023 |
| `sms.dashboard_stats(p_org_id, p_date)` | authenticated | admin/teacher | jsonb(01장 SMS-F-008 정의) | 42501 |
| `sms.attendance_trend(p_org_id, p_from, p_to, p_class_id)` | authenticated | admin/teacher, 366일 | table | 22023 |
| `sms.student_summary(p_org_id, p_month)` | authenticated | 활성 학생 본인 | jsonb | SM003 |

직접 테이블 쓰기: `sms.classes`, `sms.subjects`(admin).

### 3.4 HMS (모놀리스 `public`)

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `invite_staff(p_org_id, p_user_id, p_role, p_display_name, p_specialty)` | authenticated | admin, 자기 초대 불가 | staff_profile | 42501, 22023 |
| `accept_staff_invite(p_org_id)` | authenticated | 본인 invited | staff_profile | P0002 |
| `set_staff_role` / `set_staff_status(p_org_id, p_user_id, p_*)` | authenticated | admin, 자기 자신 불가, 감사 | staff_profile | 42501, HM001 |
| `set_my_availability(p_org_id, p_available)` | authenticated | 본인 doctor | staff_profile | 42501 |
| `register_patient(p_org_id, p_chart_no, p_name, p_sex, p_birth_date, p_phone_ciphertext, p_phone_last4, p_key_version, p_blood_type, p_allergies, p_crm_tags, p_consent)` | authenticated | admin/staff, 동의 필수, 접근 기록 | patient | HM006, 23505 |
| `update_patient(p_patient_id, ...)` | authenticated | admin/staff, 접근 기록, 감사 | patient | 42501 |
| `get_patient_detail(p_patient_id, p_purpose)` | authenticated | admin/doctor/staff, 사유, 접근 기록 | jsonb | 42501, 22023 |
| `search_patients(p_org_id, p_query)` | authenticated | admin/doctor/staff, 50건, 접근 기록 | setof patients | 22023 |
| `log_phi_access(p_org_id, p_action 'view.*', p_patient_id, p_row_count)` | authenticated | has_access | void | 22023 |
| `archive_patient(p_patient_id, p_reason)` | authenticated | admin, 감사 | patient | 42501 |
| `create_appointment(p_org_id, p_patient_id, p_doctor_id, p_scheduled_at, p_duration_min, p_visit_type, p_admin_note)` | authenticated | admin/staff, 의사 활성·가용, 겹침 잠금 검사 | appointment | HM002, HM003 |
| `transition_appointment(p_appointment_id, p_to, p_reason)` | authenticated | 05장 3절 표, 대기번호(KST 당일) | appointment | 42501, HM001 |
| `reschedule_appointment(p_appointment_id, p_scheduled_at)` | authenticated | admin/staff, scheduled만 | appointment | HM001, HM002 |
| `add_medical_record(p_patient_id, p_appointment_id, p_record_type, p_body_ciphertext, p_key_version, p_amends_id)` | authenticated | doctor, 예약-환자 일치, 접근 기록 | record | 42501, 22023 |
| `get_patient_chart(p_patient_id, p_purpose)` | authenticated | doctor, 접근 기록 | jsonb | 42501 |
| `request_lab_test(p_patient_id, p_appointment_id, p_test_code)` | authenticated | doctor | lab_test | 22023 |
| `list_lab_worklist(p_org_id, p_statuses)` | authenticated | lab_tech/doctor, 500건, 접근 기록 | table | 42501 |
| `start_lab_test` / `save_lab_result(p_test_id, p_values, p_correction_reason)` / `reopen_lab_result` | authenticated | lab_tech, 숫자 검증, 이탈 계산 | lab_test | HM004, HM001 |
| `approve_lab_result(p_test_id)` | authenticated | lab_tech/doctor, 입력자와 다른 사람 | lab_test | HM005 |
| `cancel_lab_test(p_test_id, p_reason)` | authenticated | doctor/admin | lab_test | 22023 |
| `record_charge`, `settle_charge`, `refund_charge` | authenticated | admin/staff(환불 admin) | visit_charge | HM001 |
| `dashboard_metrics(p_org_id)` | authenticated | admin | jsonb | 42501 |
| `purge_phi_access_log()`, `retention_candidates(p_org_id, p_years)` | service_role | 보존 하한 730일 / 10년 | integer / table | 42501, 22023 |

## 4. 잡 페이로드 계약

도메인 쓰기는 해당 없음: `core.jobs`를 쓰지 않는다(모든 쓰기가 동기 RPC). AI 색인·위키 작업은 FastAPI 내부 작업이며 `ai_documents.status`와 `ai_runs`로 추적한다(02장 4절). 계약:

| 작업 | payload | result | progress |
|---|---|---|---|
| `admin.ai.rag_ingest` | `{ documentId: uuid, collection: string }` | `{ chunks: int, embeddingProvider, embeddingModel }` | `chunking`, `embedding:<n>/<total>`, `done` |
| `admin.ai.wiki_ingest` | `{ documentIds: uuid[] }` | `{ created: int, updated: int, draftSlugs: string[] }` | `page:<n>/<total>` |
| `admin.ai.wiki_lint` | `{}` | `{ contradictions, stale, orphans, brokenLinks, unsourced }`(각 slug 목록) | - |

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss(Phase 2, erp/sms 구독) | `SHARED_MODULES.md` webhooks 절 | `CORE_SPEC.md` 6장 규칙 | 상태 동기화만. 지급은 confirm 경로 |
| 발신 | 없음 | - | - | - |
| 수신 | AI·음성 | 해당 없음 | - | Dify, FastAPI, 음성 서버는 웹훅을 쓰지 않는다(색인 상태는 `ai_documents.status` 폴링, 음성은 동기 요청) |

## 6. 외부 API 어댑터

| API | 위치 | 실패 처리 |
|---|---|---|
| Supabase Auth Admin `inviteUserByEmail` | `packages/admin-kit/src/members/server.ts` | 이메일 중복 → 기존 사용자 id로 계속. 실패 시 도메인 RPC 호출 안 함 |
| FastAPI AI 서비스(그래프) | `/api/ai/chat` | 체인 대체(라우터) → 재작성 1회(그래프) → 모두 실패 시 `AI_UNAVAILABLE`. 120초 타임아웃. 질문당 LLM 호출 1~2회, 원가는 `ai_usage`(run_id) |
| Dify Chat API (erp, sms) | `/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림. **hms는 호출하지 않는다**. 공용 인스턴스 |
| ElevenLabs(TS SDK, erp, sms) | `/api/voice/*` | 국외 이전 동의 조직만, 체인 다음 제공자로 대체(`voice_jobs.fallback_from`). **hms는 호출하지 않는다**. 요금·상업 이용 조건 구현 시 확인 |
| 오픈소스 음성 서버 | `/api/voice/*`(scope `voice`) | erp, sms: 공용 `oss-voice`(장애 시 체인 다음), hms: 전용 `hms-voice`(다른 서버로 대체하지 않음). 요청당 STT 10분·TTS 5,000자 상한(`VOICE_ARCHITECTURE.md:61`), 이 제품은 60초 |
| Toss(Phase 2) | 공용 toss 모듈 | `CORE_SPEC.md` 5장. 금액 불일치(PM001) 시 앱은 별도 호출로 `fail_payment_order`(2026-10-13 코어 반영)를 불러 주문을 failed로 남기고 서버 로그와 운영 알림을 남긴다 |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158` 중 admin-suite가 쓰는 것이다. 배포는 `api-shared`(erp, sms)와 `api-hms`(hms 전용)이며 엔드포인트는 같다.

| 엔드포인트 | 호출자 | 인증 | admin-suite 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 (erp, sms만) | 내부 키(앱별) | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R-10). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 (erp, sms만) | 내부 키 + 대화 매핑 | 그래프 `admin.assistant` 실행. 대화 매핑의 org·user로 `permission` 노드 실행 → 응답 `{ answer, citations, no_source, fallback, usage }`. assistant `ai_messages` 행을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js 서버 (erp, sms: Dify 장애 시 / hms: 항상) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /rag/ingest` | Next.js 서버 | 서명 토큰 scope `rag` | `ai-docs` 버킷 문서 색인(PHI·개인정보 탐지 포함) |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-10) | Next.js 서버 | 서명 토큰 scope `wiki` | 기관 운영 위키 |
| `POST /graphs/admin.assistant/runs` | (사용하지 않음) | - | 채팅은 요청-응답이라 도구 엔드포인트로 호출한다. 그래프 실행 REST는 평가셋 실행용으로만 열어 둔다(ADM-06-056, 서명 토큰 scope `graph:admin.assistant`) |

쓰지 않는 것: `POST /dify/retrieval`(조직 구분 없는 제품 공통 지식이 없다), `POST /tools/graph/{name}`, `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (erp, sms 전용)

| 항목 | 값 |
|---|---|
| 앱 | `erp-assistant`, `sms-assistant`(Chatflow 각 1개), 앱 키 `DIFY_APP_KEY`(각 앱 Next.js 서버 전용). 정의는 `infra/dify/*.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID)만. 서명 토큰, org, 이름, 역할은 넣지 않는다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285`) |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`: 인사·범위 밖 잡담 분기) → 업무 질문 분기: HTTP 요청 노드 → 답변 / 범위 밖 분기: 고정 안내 답변. Dify 내장 지식베이스와 외부 지식 API는 쓰지 않는다 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY_<APP>`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title, collection, reviewed_at }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다(01장 5절) |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:71`) |

### 6.3 hms 직접 경로 계약 (Dify 없음)

| 항목 | 값 |
|---|---|
| 호출 | 브라우저 → `POST /api/ai/chat`(hms Next.js) → `POST {AI_SERVICE_URL}/tools/answer-direct`(`api-hms`), `Authorization: Bearer <서명 토큰>` |
| 토큰 | 5분 이하 수명 권고(제안), `scope=chat rag wiki`, `aud=platform-ai:hms`, `conv`=대화 id, `jti` 1회 사용 |
| 본문 | `{ conversation_id, request_id, message }` (Next.js가 환자 식별정보 패턴을 검사해 걸리면 마스킹하지 않고 차단) |
| 응답 | SSE로 바꾸기 전 원본 `{ answer, citations, no_source, usage: { provider: 'hms-llm', model, input_tokens, output_tokens } }`. `provider`가 `hms-*`가 아니면 Next.js가 응답을 폐기하고 오류 처리(방어적 검사) |
| 대체 | 없음. `api-hms`/`hms-*` 장애 시 `AI_UNAVAILABLE` |
| 격리 검사 | 기동 시 금지 변수 검사(02장 5.5절), CI에서 `apps/hms` 번들에 Dify·ElevenLabs·상용 SDK import 0 확인(ADM-06-057) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| `42501` | 권한 없음 | 403 |
| `22023` | 인자 오류, 사유 누락 | 400 |
| `P0002` | 대상 없음, 가입 코드 무효 | 404 |
| `23505` | 중복(SKU, 차트번호, 학급명) | 409 |
| `ER001` | 재고 부족 | 409 |
| `ER002` | 판매/가입요청 상태 불가 | 409 |
| `ER003` | 비활성 상품 | 409 |
| `ER005` | 이미 멤버/초대됨 | 409 |
| `SM001` | 학생이 과목 학급의 활성 학생 아님 | 409 |
| `SM002` | 출석 날짜 범위 위반 | 409 |
| `SM003` | 학생 전용 동작 | 409 |
| `HM001` | 상태 전이 불가(예약, 검사, 수납, 직원) | 409 |
| `HM002` | 예약 겹침 | 409 |
| `HM003` | 의사 불가용 | 409 |
| `HM004` | 검사 값 오류 | 400 |
| `HM005` | 결과 입력자 본인 승인 | 409 |
| `HM006` | 개인정보 수집 동의 없음 | 400 |
| 플랜 한도 | Route Handler 판정(인원, 학생 수, 문서 수 `ai_docs_max` 포함) | 402 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. hms는 국외 제공자가 비활성이라 발생하지 않음) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| `CR001` | 크레딧 부족. 이 제품은 크레딧을 쓰지 않으므로 발생하지 않는다(`AI_DAILY_LIMIT`로 대체) | - |
| 앱 코드 `AI_DISABLED` | 플랜 `ai_assistant`/`ai_voice`/`ai_wiki` 꺼짐 | 403 |
| 앱 코드 `AI_NO_PERMISSION` | 역할이 읽을 수 있는 컬렉션이 없음, 비활성 사용자 | 403 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 질문 한도 | 429 |
| 앱 코드 `AI_PHI_BLOCKED` | hms 질문에 환자 식별정보 패턴 | 422 |
| 앱 코드 `AI_DOC_PII_DETECTED` | 문서에 개인정보(hms는 환자 정보) 패턴 | 422 |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자(hms는 전용 서버) 실패 | 503 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 60초 또는 5MB 초과 | 413 |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전이 서버 값과 다름 | 409 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 저장 시 `expected_version`이 현재 버전과 다름(`docs/file/03-설계/공용코어/LLM_WIKI.md:31`) | 409 |
| 앱 코드 `INTERNAL_KEY_INVALID` | Dify 내부 키 불일치(erp, sms) | 401 |
| FastAPI `AI_TOKEN_INVALID` | 서명, `aud`, scope, 만료, `jti` 재사용 | 401 |
| 코어 코드 | `CORE_SPEC.md` 15장 매핑 | - |

SQLSTATE 접두사: erp `ER`, sms `SM`은 `DB_CONVENTIONS.md` 1장 제안을 따른다. hms `HM`은 그 표에 없어 이 문서가 새로 정했다(제안).
