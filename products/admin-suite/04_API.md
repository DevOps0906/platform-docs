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

## 3. RPC (SECURITY DEFINER)

모든 사용자용 RPC: `set search_path = ''`, 호출자 판정 `is_service_caller()`, 역할은 exists 헬퍼 또는 `coalesce`, EXECUTE는 authenticated + service_role만(PUBLIC/anon 회수). 코어 RPC는 `CORE_SPEC.md` 2.4, 3, 11장을 인용만 한다.

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

해당 없음: `core.jobs`를 쓰지 않는다(모든 쓰기가 동기 RPC).

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss(Phase 2, erp/sms 구독) | `SHARED_MODULES.md` webhooks 절 | `CORE_SPEC.md` 6장 규칙 | 상태 동기화만. 지급은 confirm 경로 |
| 발신 | 없음 | - | - | - |

## 6. 외부 API 어댑터

| API | 위치 | 실패 처리 |
|---|---|---|
| Supabase Auth Admin `inviteUserByEmail` | `packages/admin-kit/src/members/server.ts` | 이메일 중복 → 기존 사용자 id로 계속. 실패 시 도메인 RPC 호출 안 함 |
| Toss(Phase 2) | 공용 toss 모듈 | `CORE_SPEC.md` 5장. 금액 불일치 시 주문 failed 기록이 되지 않는 코어 결함(`DB_CONVENTIONS.md` 13.2)이 있어 앱은 PM001을 받으면 서버 로그와 운영 알림을 남기고 주문 상태에 의존하지 않는다 |

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
| 플랜 한도 | Route Handler 판정 | 402 |
| 코어 코드 | `CORE_SPEC.md` 15장 매핑 | - |

SQLSTATE 접두사: erp `ER`, sms `SM`은 `DB_CONVENTIONS.md` 1장 제안을 따른다. hms `HM`은 그 표에 없어 이 문서가 새로 정했다(제안).
