# 05 데이터 모델: Admin Suite

경로 약어: `F1600` = `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql`, `F1700` = `.../1700_sms.sql`, `HMS2` = `D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/hms/migrations/0002_hms_domain.sql`.

## 1. 개요와 ERD

```
core.organizations (테넌트 = 고객사/학교/병원. 코어 참조만)
 ├─ core.org_members (owner/admin = 앱 관리자 역할의 원천)
 ├─ core.app_entitlements (erp/sms/hms 이용 여부)
 │
 ├─ erp.workspaces 1:1 ── erp.join_codes 1:1
 │   ├─ erp.departments (트리: parent_id)
 │   ├─ erp.employees (org, user) ── department_id → departments
 │   ├─ erp.join_requests (org, user, status)
 │   ├─ erp.products ── erp.inventory_moves (append-only)
 │   │                └─ erp.sales ── inventory_moves.sale_id
 │
 ├─ sms.workspaces 1:1
 │   ├─ sms.classes ── sms.subjects (class_id)
 │   ├─ sms.members (org, user, sms_role, class_id)
 │   └─ sms.attendance (student x subject x date 유일)
 │
 └─ (hms 모놀리스, public) workspaces 1:1
     ├─ staff_profiles (org, user, role)
     ├─ patients ── patient_private 1:1 (민감)
     │   ├─ appointments (doctor_id → staff_profiles)
     │   │   ├─ medical_records (append-only, 암호문)
     │   │   ├─ lab_tests ── lab_test_catalog(전역)
     │   │   └─ visit_charges (예약당 1)
     └─ phi_access_log (append-only)
```

AI·음성(2026-10-13)은 코어 표만 참조하고 제품 AI 표를 만들지 않는다(이유는 2.4절):

```
core AI·음성 (참조만, 모놀리스는 public)
 ├─ ai_conversations (본인만 SELECT, dify_user는 erp·sms만)
 │    ├─ ai_messages (citations, provider, model)
 │    └─ voice_sessions ─ voice_jobs (feature voice_chat, store_audio=false)
 ├─ ai_runs (graph admin.assistant, 본문 없는 메타데이터만) ─ ai_run_steps
 ├─ ai_usage (원가 기록, 차감 없음)
 ├─ ai_org_settings (국외 이전 동의: erp, sms만. hms 조직은 사용 안 함)
 ├─ ai_collections (역할별 공개 범위당 1개: 01장 3.7절) ─ ai_documents ─ ai_chunks (vector(1024), HNSW, 사용자 SELECT 없음)
 ├─ wiki_pages ─ wiki_links, wiki_revisions ("위키 대상" 컬렉션 문서에서만 생성)
 └─ ai_routing_settings (org null, app erp/sms 8행, hms 7행: 9절)
Storage ai-docs/<org>/<app>/<collection>/<document_id>.<ext> (사용자 정책 없음, service_role 전용)
```

공통 설계: 테넌트 테이블은 모두 `org_id → core.organizations on delete cascade`. 같은 조직 내부 참조는 `(org_id, id)` 복합 FK로 조직을 건너뛰는 참조를 DB가 거부한다. 도메인 데이터를 가지려면 `<app>.workspaces` 행이 있어야 한다(서버 프로비저닝). 가입 트리거가 만드는 개인 조직은 엔타이틀먼트가 있어도 workspace가 없어 접근 불가다(스모크 테스트 "C insert product into own personal org" 42501).

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 모든 테이블에 `created_at`, UPDATE가 있는 테이블에 `updated_at` + `core.set_updated_at` 트리거, 행위자 `created_by`/`marked_by` 등은 FK 없는 uuid. 상태는 text + CHECK.

### 2.1 erp (F1600)

| 테이블 | 목적 | 주요 컬럼(타입, 제약) | 표준 컬럼 |
|---|---|---|---|
| `workspaces` | ERP 고객사 | `org_id` uuid PK FK, `company_name` text 1..120, `status` active/suspended, `default_safety_stock` int 0..1e6, `low_stock_alert` bool, `settings` jsonb | created_at, updated_at |
| `join_codes` | 가입 코드(사용자 접근 불가) | `org_id` PK FK workspaces, `join_code` text unique `^[A-HJ-NP-Z2-9]{8}$`, `rotated_at` | - |
| `departments` | 부서 트리 | `id` uuid, `org_id`, `name` 1..60 (org 내 유일), `parent_id` (복합 FK, `on delete set null (parent_id)`), `sort_order`, `created_by` | 전부 |
| `employees` | 임직원 + ERP 역할 | PK(`org_id`,`user_id`), `display_name` ..80, `department_id`(복합 FK), `position` ..40, `phone` `^[0-9+() -]{7,20}$`, `erp_role` inventory_manager/sales_manager/staff, `status` active/suspended, `joined_at` | 전부 |
| `join_requests` | 승인제 가입 요청 | `id`, `org_id`, `user_id`, `applicant_name` 1..80, `message` ..500, `status` pending/approved/rejected/canceled, `decided_by`, `decided_at`, `decision_note`. 부분 유니크(org,user) where pending | 전부 |
| `products` | 상품 | `id`, `org_id`, `sku` (org 내 유일), `name` 1..200, `category` 1..60, `price` numeric(12,2)>=0, `quantity` int>=0, `safety_stock` int>=0, `is_low_stock` 생성 컬럼, `image_path`(`<org>/erp/product/` 강제), `is_active`, `created_by` | 전부 |
| `inventory_moves` | 재고 이동 이력 | `id` bigint identity, `org_id`, `product_id`(복합 FK), `move_type` IN/OUT/ADJUSTMENT/SALE/SALE_CANCEL, `quantity_delta` <>0, `quantity_after` >=0, `reason` ..300, `sale_id`, `request_id`(org 내 유일), `created_by` | created_at만(append-only) |
| `sales` | 판매 | `id`, `org_id`, `product_id`(복합 FK), `quantity`>0, `unit_price`, `total_price` 생성, `status` pending/completed/canceled, `sold_by`, `sold_at`, `completed_at`(completed면 필수), `canceled_at/by`, `cancel_reason`, `request_id` not null(org 내 유일) | 전부 |

### 2.2 sms (F1700)

| 테이블 | 목적 | 주요 컬럼 | 표준 컬럼 |
|---|---|---|---|
| `workspaces` | 학교 | `org_id` PK, `school_name`, `school_year` 2000..2100, `status`, `teacher_backfill_days` 0..60(기본 7, 제안), `settings` | 전부 |
| `classes` | 학급 | `id`, `org_id`, `name` 1..40(유일), `grade` 1..12, `homeroom_teacher_id`, `created_by` | 전부 |
| `subjects` | 과목(학급 소속) | `id`, `org_id`, `class_id`(복합 FK cascade), `name`(학급 내 유일), `teacher_id` | 전부 |
| `members` | 교사/학생 | PK(`org_id`,`user_id`), `sms_role` teacher/student, `display_name`, `class_id`(복합 FK set null), `student_no`(org 내 유일), `status` invited/active/suspended, `invited_by`, `invited_at`, `joined_at`. CHECK: 교사는 class_id/student_no 없음 | 전부 |
| `attendance` | 출석 | `id`, `org_id`, `class_id`, `subject_id`(복합 FK), `student_id`, `attend_date` date(KST 수업일), `status` present/late/early_leave/absent, `note` ..200, `marked_by`. 유일(org, student, subject, date) | 전부 |

`attend_date`는 시각이 아닌 달력 날짜라 date를 쓴다(`DB_CONVENTIONS.md` 4장 "date에 시각을 넣지 않는다"에 부합). 원본의 한글 상태 리터럴(`School_Management_System/src/lib/types.ts`)은 영문 코드로 바꾸고 라벨은 UI에서 매핑한다.

### 2.3 hms (HMS2, 모놀리스 public)

| 테이블 | 목적 | 주요 컬럼 | 사용자 GRANT |
|---|---|---|---|
| `workspaces` | 병원 | `org_id` PK, `hospital_name`, `status`, `phi_log_retention_days` >=730 | SELECT |
| `staff_profiles` | 직원과 의료 역할 | PK(org,user), `role` doctor/staff/lab_tech, `display_name`, `specialty`, `is_available`, `status` invited/active/suspended | SELECT |
| `patients` | 환자 디렉토리(최소 식별) | `id`, `org_id`, `chart_no`(유일), `name`, `sex` M/F/U, `birth_year`, `phone_last4`, `has_allergy`, `crm_tags` text[] <=10, `last_visit_at`, `deleted_at` | SELECT(RLS) |
| `patient_private` | 민감 항목 | `patient_id` PK, `birth_date`, `phone_ciphertext`, `blood_type`, `allergies`, `memo_ciphertext`, `key_version`, `privacy_consent_at` not null | 없음(RPC만) |
| `appointments` | 예약/대기열 | `id`, `org_id`, `patient_id`, `doctor_id`(복합 FK → staff_profiles, set null), `scheduled_at` timestamptz, `duration_min` 5..240, `visit_type` first/return/checkup/procedure, `status` 6종, `queue_no`, 전이 시각 4개, `cancel_reason`, `admin_note`(비진료) | SELECT(RLS) |
| `medical_records` | 진료기록/처방 | `id`, `org_id`, `patient_id`, `appointment_id`, `author_id`, `record_type` progress/prescription/order_note, `body_ciphertext`, `key_version`, `amends_id` | 없음(RPC만), append-only |
| `lab_test_catalog` | 검사 항목·정상범위(전역) | `code` PK, `name`, `parameters` jsonb 배열 | SELECT |
| `lab_tests` | 검사 | `id`, `org_id`, `patient_id`, `appointment_id`, `test_code`, `status` 5종, `result_values` jsonb, `abnormal_keys` text[], 요청/시작/결과/승인/취소 행위자·시각, `correction_reason`. CHECK 승인자 <> 입력자 | 없음(RPC만) |
| `visit_charges` | 수납 | `id`, `org_id`, `appointment_id`(유일), `patient_id`, `amount_krw` 0..1억, `status` unpaid/paid/refunded/void, `method`, 시각, `refund_reason`, `handled_by` | SELECT(RLS) |
| `phi_access_log` | 의료정보 접근 기록 | `id` bigint, `org_id`, `actor_id`, `actor_role`, `action` `<entity>.<verb>`, `patient_id`, `target_type/id`, `purpose`, `row_count`, `created_at` | SELECT(admin), append-only |

### 2.4 AI·음성 (코어 참조, 제품 AI 표 없음)

| core 객체(모놀리스는 `public.`) | admin-suite 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 채팅 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `admin.assistant` 실행 기록, 위키 lint 결과. **본문 금지**(id, 개수, 상태만, 02장 5.3절 8항) | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량과 원가(`credits` 컬럼은 환산 값 기록용, 차감 없음) | FastAPI, Next.js 음성 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값(9절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의(erp, sms). hms는 호출하지 않는다 | 설정 화면(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 역할별 규정·매뉴얼 컬렉션(01장 3.7절) | FastAPI(쓰기·검색), Next.js(서버 업로드) |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 기관 운영 위키("위키 대상" 컬렉션만) | FastAPI(쓰기), Next.js 서버(읽기) |
| `voice_sessions`, `voice_jobs` | 음성 질의 | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가. hms는 `hms-llm`, `hms-embed`, `hms-voice`만 활성 | 코어 seed(모놀리스 SECTION 11) |
| Storage `ai-docs` 버킷 | AI 문서 원본(업로드 20MB, 사용자 정책 없음) | Next.js 서버(service_role) |

제품 AI 표를 만들지 않은 이유(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 문서 접근 권한 표(문서별 ACL) | 문서마다 허용 역할 | 공개 범위별 컬렉션 고정(01장 3.7절, D-15). 컬렉션 이름과 역할 매핑은 `collections.json` |
| AI 한도·사용량 표 | 질문 수 집계 | `core.rate_limit_hit` 카운터(하루 한도) + `ai_usage` 집계 |
| 음성 고지 확인 표 | 첫 사용 전 고지 증빙 | `write_audit('ai.voice.notice_ack')` + 서명된 쿠키. 녹음을 저장하지 않으므로 `voice_jobs.consent_*`는 비워 둔다 |
| 국외 이전 동의 표 | 동의 증빙 | `core.ai_org_settings`(동의 여부, 고지문 버전, 동의자, 시각) |
| 역할 확인용 뷰 | FastAPI가 service_role로 역할을 읽기 위해 | 허용 목록 테이블 직접 조회(`erp.employees`, `sms.members`, hms `staff_profiles`, `org_members`). 필요하면 ADM-06-045에서 결정 |

조각은 `core.*`를 ALTER하지 않는다. 플랜·크레딧·결제·잡 테이블을 앱 스키마에 다시 만들지 않는다.

## 3. 상태 전이

| 테이블.컬럼 | 현재 | 허용 전이 | 누가 | 부수 효과 | 강제 |
|---|---|---|---|---|---|
| erp.sales.status | pending | completed, canceled | master_admin, sales_manager | completed: 조건부 재고 차감 + SALE 이력 | 트리거 `sales_guard_transition` + RPC |
| | completed | canceled | 같음 | 재고 복원 + SALE_CANCEL 이력 + 감사 | 같음 |
| erp.join_requests.status | pending | approved, rejected | master_admin | approved: core 초대 멤버십 + employees 행 + 서버 `approve_profile` | 트리거 + RPC |
| | pending | canceled | 신청자 본인 | - | |
| erp.employees.status | active ↔ suspended | | master_admin(자기 자신·core admin 제외) | 감사 | RPC |
| sms.members.status | invited | active, suspended | 본인 수락 / admin | core accept_invite | 트리거 `members_guard_transition` + RPC |
| | active ↔ suspended | | admin | 감사 | |
| hms appointments.status | scheduled | checked_in | staff, admin | 대기번호(KST 당일 순번), checked_in_at | 트리거 + `transition_appointment` |
| | scheduled | canceled(사유), no_show(예약 시각 이후만) | staff, admin | 감사 | |
| | checked_in | in_consultation | 담당 doctor, admin | consult_started_at | |
| | checked_in | canceled | staff, admin | | |
| | in_consultation | completed | 담당 doctor, admin | completed_at, patients.last_visit_at | |
| hms lab_tests.status | requested | in_progress / canceled | lab_tech / doctor, admin | | 트리거 + RPC |
| | in_progress | resulted / canceled | lab_tech / doctor, admin | 이탈 키 계산, 접근 기록 | |
| | resulted | approved / in_progress(정정 사유) | lab_tech·doctor(입력자 제외) / lab_tech | approved 이후 값 불변 | |
| hms visit_charges.status | unpaid | paid, void | staff, admin | 감사 | 트리거 + RPC |
| | paid | refunded | admin(사유) | 감사 | |
| hms staff_profiles.status | invited → active(본인 수락), active ↔ suspended(admin) | | | 감사 | RPC |

취소와 노쇼를 별도 상태로 나눠 대시보드에서 섞이지 않게 했다(`docs/reference/reviews/Hospital.md:62`). 원본 PRD의 예약 전이 순서(`Hospital/PRD.md:79`)를 지킨다.

## 4. RLS 정책

모든 테이블 RLS ON. `FOR ALL` 정책 없음. 쓰기 정책이 있는 테이블은 `with check`가 있고 상태·권한·돈 컬럼이 없는 순수 콘텐츠 테이블뿐이다(`DB_CONVENTIONS.md` 8.1). 나머지 쓰기는 RPC + `guard_privileged_write` 트리거(이중 잠금).

### 4.1 erp

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| workspaces | `erp.has_access(org_id)` | - | - | - | select |
| join_codes | 없음 | - | - | - | 없음 |
| departments | `has_access` | `has_role(org,{master_admin})` | 같음(using + with check) | 같음 | select, insert, update, delete |
| employees | `(user_id = auth.uid() and has_access) or has_role({master_admin})` | - | - | - | select |
| join_requests | `user_id = auth.uid() or has_role({master_admin})` | - | - | - | select |
| products | `has_role({master_admin, inventory_manager, sales_manager})` | `has_role({master_admin, inventory_manager})` | 같음 | `has_role({master_admin})` | select, insert/update(컬럼: quantity 제외), delete |
| inventory_moves | `has_role({master_admin, inventory_manager, sales_manager})` | - | - | - | select |
| sales | `has_role({master_admin, sales_manager})` | - | - | - | select |

products 쓰기 정책 조건 근거: 상품은 콘텐츠 컬럼만 사용자 쓰기를 열고, 돈·수량 성격의 `quantity`는 컬럼 GRANT에서 제외 + `erp.guard_product_columns` 트리거(F1600:220)로 2중 차단한다. 가격(`price`) 변경은 재고·인사 권한 있는 역할만 가능하며 판매 금액은 판매 시점 단가로 `sales.unit_price`에 고정된다.

### 4.2 sms

| 테이블 | SELECT | 쓰기 | GRANT |
|---|---|---|---|
| workspaces | `sms.has_access` | RPC | select |
| classes, subjects | `has_access` | insert/update/delete: `sms.is_admin(org_id)`(with check) | select, insert, update, delete |
| members | `user_id = auth.uid() or sms.is_staff(org_id)` | RPC | select |
| attendance | `sms.is_staff(org_id) or (student_id = auth.uid() and has_access)` (F1700:266) | RPC | select |

### 4.3 hms

| 테이블 | SELECT | 쓰기 |
|---|---|---|
| workspaces | `has_access` | RPC(service) |
| staff_profiles | `user_id = auth.uid() or has_access` | RPC |
| patients | `deleted_at is null and has_role({admin, doctor, staff})` | RPC |
| appointments | `has_role({admin, doctor, staff})` | RPC |
| visit_charges | `has_role({admin, staff})` | RPC |
| lab_test_catalog | `is_active` | 없음 |
| phi_access_log | `has_access and has_org_role(owner, admin)` | DEFINER 내부만 |
| patient_private, medical_records, lab_tests | GRANT 없음(HMS2:450) | RPC |

### 4.4 헬퍼

`<app>.has_access`, `has_role`, `my_role`(sms는 `is_admin`, `is_staff`)는 SECURITY DEFINER + STABLE + `search_path=''`이며 exists로 판정해 NULL이 나오지 않는다(`SECURITY_BASELINE.md` 2장). 정책 안에서 `org_members`나 자기 테이블을 직접 조회하지 않아 42P17 재귀가 없다. `has_access`는 `core.profiles.status = 'active'`를 요구해 승인 전(pending) 사용자는 멤버십이 있어도 0행을 본다.

### 4.5 AI 코어 표 접근과 한계

코어 정책(`D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:607-642`, `0009_core_voice.sql:81-87`)을 그대로 쓴다. 제품이 정책을 추가하거나 바꾸지 않는다(`DB_CONVENTIONS.md:238`).

| 테이블 | authenticated SELECT | 쓰기 | 이 제품의 취급 |
|---|---|---|---|
| `ai_conversations`, `ai_messages`, `voice_sessions`, `voice_jobs` | 본인 행만 | service_role | 대화 본문은 여기에만 둔다 |
| `ai_chunks` | 없음 | service_role | 검색은 `match_ai_chunks`(service_role)로만 |
| `ai_documents`, `ai_collections`, `wiki_pages`, `wiki_links`, `wiki_revisions`, `ai_runs`, `ai_run_steps` | **같은 조직 구성원 전원** | service_role | 한계: 직원·학생이 PostgREST로 직접 읽을 수 있다. 제품 규칙으로 완화(02장 5.3절 8항): run에 본문 금지, 위키는 "위키 대상" 컬렉션만, 문서 제목은 비밀 금지. 근본 해결은 06장 R-14 |
| `ai_routing_settings`, `ai_org_settings` | 같은 조직(또는 플랫폼 기본) | service_role / `set_ai_cross_border_ack` | 라우팅 정보가 보여도 비밀이 아니다 |
| `ai_providers`, `ai_model_prices` | 활성 행 전체 | service_role | hms는 공용 제공자 `is_active=false`라 목록에도 나오지 않는다 |
| `storage.objects` `ai-docs` 버킷 | 정책 없음 = 접근 불가 | service_role | org-files처럼 구성원 전체 열람이 되지 않게 별도 버킷 |

회귀 테스트(ADM-06-057): (1) staff 세션이 `ai_chunks` 조회 42501, (2) 모든 역할이 `ai-docs` 객체 직접 다운로드 거부, (3) 다른 사람의 `ai_messages` 0행, (4) `ai_runs`/`ai_run_steps` 본문 필드에 질문 문자열이 없음, (5) 직원 세션이 제한 컬렉션 문서에서 만든 위키를 읽지 못함(R-14 이전에는 "만들지 않음"으로 확인), (6) `resolve_ai_route`·`match_ai_chunks`를 authenticated가 호출 시 42501.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `erp.products_low_stock_idx (org_id) where is_low_stock and is_active` | 대시보드 위험 재고 |
| `erp.sales_org_completed_idx (org_id, completed_at desc) where completed` | 당일 매출, 추이 |
| `erp.inventory_moves_org_created_idx` | 최근 변동 5건 |
| `erp.join_requests_pending_uniq` | 대기 요청 1건 보장 |
| `sms.attendance_uniq (org, student, subject, date)` | upsert 충돌 대상 |
| `sms.attendance_org_date_idx`, `class_date_idx`, `student_date_idx` | 일 통계, 학급별, 학생 월 요약 |
| `sms.members_class_idx where student` | 출석 그리드 학생 목록 |
| hms `appointments_org_time_idx`, `doctor_time_idx` | 캘린더 범위 조회, 겹침 검사 |
| hms `appointments_queue_idx where status in (checked_in, in_consultation)` | 대기열 |
| hms `patients_org_name_idx`, `org_phone_idx` | 검색 |
| hms `lab_tests_worklist_idx (org, status, requested_at)` | 검사 작업 목록 |
| hms `phi_access_log_*` (org/created, patient, actor) | 접근 기록 점검 |

예약 겹침 검사는 의사별 advisory lock 뒤 `tstzrange &&`로 판정한다. 병원 규모(일 수백 건)에서 GiST 제약은 과하다고 보고 넣지 않았다(제안).

## 6. 코어 참조

| core 객체(모놀리스 `public.`) | 용도 | ALTER 여부 |
|---|---|---|
| `organizations`, `org_members` | 테넌트, 관리자 역할 원천 | 안 함 |
| `profiles.status` | pending 차단(has_access) | 안 함 |
| `app_entitlements`, `has_entitlement` | 앱 이용 여부 | 안 함 |
| `is_org_member`, `has_org_role`, `is_service_caller`, `is_privileged_session`(트리거·service 전용 함수만), `guard_privileged_write`, `set_updated_at`, `write_audit` | 정책·함수·트리거 | 안 함 |
| `invite_member`, `accept_invite`, `change_member_role`, `remove_member`, `approve_profile` | 수명주기 | 안 함 |
| `apps`, `plans` | 조각 머리에서 `on conflict do nothing` 등록 | 데이터만 |
| Storage `org-files` | ERP 상품 이미지 | 안 함 |
| AI·음성: `ai_*`, `wiki_*`, `voice_*`, `match_ai_chunks`, `resolve_ai_route`, `set_ai_cross_border_ack`(erp, sms), `ai_providers`, `ai_model_prices` | 2.4절. 참조만, 제품 AI 표 없음 | 안 함 |
| 데이터만 추가: `ai_routing_settings` 기본 행, `plans.features` AI 키, `ai-docs` 버킷 행 | 9절 | 안 함(행 추가) |

프로비저닝(조직 생성, owner 멤버십, manual 엔타이틀먼트)은 service_role 서버 스크립트가 코어 테이블에 직접 쓴다(`CORE_SPEC.md` 1.1 "service_role 키를 가진 서버 코드"). 제품 SQL은 코어 테이블에 쓰지 않는다. 전용 코어 함수는 06장 6절에 요청한다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

02장 6절 8건 + 이 표 6건 = 리뷰 "높음" 14건.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reference/reviews/ERP-Wesite.md` 3장 #1 | `ERP-Wesite/supabase/migrations/001_initial_schema.sql:76-80` | profiles 자기 행 UPDATE/INSERT에 컬럼 제한이 없어 누구나 Master Admin·Active로 상승 | 역할을 profiles에 두지 않는다. 관리자 = `core.org_members.role`(사용자 쓰기 불가, guard 트리거 `migrations/0001_core_identity.sql` org_members_guard_write), 도메인 역할 = `erp.employees.erp_role`(GRANT 없음 + `employees_guard_write` + RPC `erp.set_employee_role`(F1600:651)의 master_admin 검사, 자기 자신 금지). profiles 상태는 코어 컬럼 GRANT + `guard_profile_columns`. 스모크: M `update employees set erp_role` 42501, `set_employee_role(self)` 42501, `change_member_role(self)` 42501, `update profiles set platform_role` 42501 | 4.1절, ADM-06-001, ADM-06-034 |
| `docs/reference/reviews/ERP-Wesite.md` 3장 #2 | `001_initial_schema.sql:83-89` | profiles 정책 안 profiles 서브쿼리 → 42P17 재귀, 전 테이블 연쇄 실패 | 정책은 DEFINER 헬퍼(`erp.has_access` F1600:287, `erp.has_role` F1600:305)만 부르고 헬퍼는 소유자 권한으로 읽어 RLS를 다시 타지 않는다. 정책 안에서 `org_members`·`employees` 직접 조회 0건(리뷰 체크리스트) | 4.4절, ADM-06-001 |
| `docs/reference/reviews/ERP-Wesite.md` 3장 #4 | `ERP-Wesite/app/actions/sales.ts:20-43`, `inventory.ts:40-64` | 읽기-계산-쓰기 비원자 처리, 판매 역할이 재고 차감 권한 없음 | `erp.record_sale`(F1600:825)이 `update ... set quantity = quantity - n where quantity >= n`(조건부) + sales INSERT + SALE 이력을 한 트랜잭션에서, DEFINER라 sales_manager도 차감 성공. `record_inventory_move`(F1600:771)는 `FOR UPDATE` 잠금. `quantity >= 0` CHECK가 최후 방어. `request_id` 멱등(advisory lock). 스모크: 초과 판매 ER001, 같은 키 재호출 수량 불변 | 2.1절, ADM-06-001, ADM-06-037 |
| `docs/reference/reviews/ERP-Wesite.md` 3장 #5 | `ERP-Wesite/app/(auth)/login/page.tsx:49` | 이메일 가입 시 이름 미전송, 프로필 트리거 없음 → 프로필 누락 | 코어 가입 트리거(`_supabase-modular/migrations/0001_core_identity.sql:113-160`)가 프로필·개인 조직을 항상 만든다. 가입 폼은 `options.data = { signup_app: 'erp', full_name }` 필수(zod). 승인제라 프로필은 pending(`0003_core_credits.sql:400-402`), 승인 후 `employees.display_name`은 신청 이름으로 채운다. 프로필 없음은 proxy가 로그아웃 처리 | ADM-06-014 |
| `docs/reference/reviews/Hospital.md` 3장 #4 | `Hospital/CLAUDE.md` 스키마, `queue-client.tsx:35-37` 등 | RLS 없음, 브라우저가 anon key로 appointments/staff_profiles/lab_results 직접 update | hms 모든 테이블 RLS ON + 사용자 쓰기 GRANT 0 + `guard_privileged_write` 일괄(HMS2 "이중 잠금" 블록). 상태 변경은 `transition_appointment`(HMS2:824)가 역할·담당의 검사, 가용 토글은 `set_my_availability`(본인만), 검사값은 `save_lab_result`(lab_tech만). 민감 테이블은 SELECT도 없음(RPC + `phi_access_log`). 스모크: staff `get_patient_chart` 42501, lab_tech patients 0행, 타 병원 0행 | 4.3절, ADM-06-002, ADM-06-034 |
| `docs/reference/reviews/School_Management_System.md` 3장 #3 | `School_Management_System/CLAUDE.md:80-87` | admin 정책이 profiles 자기참조(재귀), 정책·트리거 SQL 미커밋 | 정책은 `sms.is_admin/is_staff/has_access`(F1700:156) 헬퍼만 사용. 테이블·정책·트리거·Realtime publication 전부 조각과 모놀리스 마이그레이션으로 커밋되고 PGlite 체커와 RLS 스모크(학생 본인 출석만, 타 학교 0행, 역할 자기 변경 42501)를 CI에서 돈다 | 4.2절, ADM-06-001, ADM-06-034 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 | 비고 |
|---|---|---|---|
| 대상 | erp, sms | erp, sms, hms(hms는 모놀리스만) | 확정 결정 2 |
| 스키마 | `erp`, `sms` | `public` | lite 기본. 사용자 최종 확인 대기 |
| 도메인 SQL | `1600_erp.sql`, `1700_sms.sql`(정본) | `0002_<app>_domain.sql`(조각에서 변환 생성, hms는 직접 작성) | `DB_CONVENTIONS.md` 12장 변환 규칙 |
| 앱/플랜 등록 | 조각 머리 `on conflict do nothing` | `seed.sql` upsert | |
| 코어 lite 제거 절(erp) | - | SECTION 4, 6-A, 6-B, 7, 9 제거. 3(Toss), 6-C(레이트 리밋), 8(Storage, 상품 이미지) 유지 | |
| 코어 lite 제거 절(sms) | - | SECTION 4, 6-A, 6-B, 7, 8, 9 제거. 3, 6-C 유지 | |
| 코어 lite 제거 절(hms) | - | SECTION 3, 4, 6-A, 6-B, 7, 8, 9 제거. 6-C 유지 | 온라인 결제 없음(계약형) |
| SECTION 3 수정 | - | `confirm_payment_order`의 credit_pack 분기를 지우고 credit_pack 주문을 22023으로 거부 | lite 지침(SECTION 4 제거 시) |
| `purge_organization` | 코어 0003에 있음 | SECTION 4와 함께 빠짐 | 06장 6절 코어 요청 |
| PUBLIC EXECUTE | 조각 끝 `revoke execute on all functions in schema <app> from public`(0007 규칙) | 도메인 파일 끝 `... in schema public from public` | 트리거 함수 포함 |
| Realtime | `erp.products/inventory_moves/sales`, `sms.attendance` | 같은 테이블(public), hms `appointments`, `staff_profiles` | |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함). hms는 같은 절에서 공용 제공자를 비활성화하고 `hms-llm`, `hms-embed`, `hms-voice`만 활성(`0001_core_lite.sql:2020-2034`) | 세 모놀리스 모두 SECTION 11, 12 유지 |
| AI 라우팅 기본값 | 조각 끝 7절(erp 8행, sms 8행) | `seed.sql` 끝(erp 8행, sms 8행, hms 7행) | 같은 값. hms는 모듈러 조각이 없다 |
| 플랜 AI 키 | 조각 7절 병합 UPDATE(통합 `seed.sql` 반영은 06장 R-12) | `seed.sql` 플랜 삽입에 직접 | 키: `ai_assistant`, `ai_turns_per_day`, `ai_turns_per_month`, `ai_commercial_turns_per_month`(erp·sms), `ai_voice`, `ai_docs_max`, `ai_wiki` |
| `ai-docs` 버킷 | 조각 7절 | `seed.sql` 끝. sms, hms는 SECTION 8(Storage)을 제거했지만 `storage.buckets`는 Supabase 기본 제공이라 버킷 행만 넣는다 | 사용자 정책을 만들지 않는다 |
| 체인 검사 | 조각 끝 DO 블록(제공자 행이 있을 때만) | `seed.sql` 끝 DO 블록. hms는 모든 체인 제공자가 `hms-%`인지 추가 검사 | 어긋나면 적용 실패 |
| 크레딧 | 모듈러에는 크레딧 모듈이 있으나 사용하지 않음 | SECTION 4 제거(`consume_credits` 없음) | AI도 선차감하지 않는다(01장 4.1절) |
| 결제 실패 기록(코어 수정 반영, 2026-10-13) | `confirm_payment_order`는 금액 불일치 시 `PM001`(계약 불변). 주문 failed 기록은 `fail_payment_order`가 맡는다 | 같음 | PM001이면 별도 호출로 `fail_payment_order`(04장 6절) |

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql` | erp 스키마, 앱·플랜 등록, 테이블 8개, 트리거, 헬퍼 3개, RLS, RPC 16개 + 내부 2개, Realtime, PUBLIC 회수 |
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1700_sms.sql` | sms 스키마, 테이블 5개, 헬퍼 4개, RLS, RPC 12개, Realtime, PUBLIC 회수 |
| `supabase/monolith/erp/migrations/0001_core_lite.sql`, `0002_erp_domain.sql`, `seed.sql` | lite(절 제거), 변환된 도메인, apps 1행 + 플랜 2행 |
| `supabase/monolith/sms/migrations/0001_core_lite.sql`, `0002_sms_domain.sql`, `seed.sql` | 같음 |
| `supabase/monolith/hms/migrations/0001_core_lite.sql`, `0002_hms_domain.sql`, `seed.sql` | lite(절 제거), 의료정보 보호 도메인, apps 1행 + contract 플랜 + 검사 카탈로그 3종 |
| hms 조각 | 없음(통합 DB 제외) |
| AI 기본값(2026-10-13) | `1600_erp.sql` 7절(라우팅 8행, 플랜 AI 키, `ai-docs` 버킷, 체인 검사), `1700_sms.sql` 7절(같음), 모놀리스 `erp/seed.sql`, `sms/seed.sql`(같은 8행 + 플랜 features), `hms/seed.sql`(7행 + contract features + 버킷 + `hms-%` 검사) |

검증 결과(2026-10-12, PGlite): 모듈러(0000~0007 + seed + 1600 + 1700) OK, 모놀리스 erp/sms/hms 각 OK. 2026-10-13 AI 기본값 추가 후 재검증(`check.mjs --vector`, 모듈러는 0000~0009 + seed + 1600 + 1700): 모듈러 OK, 모놀리스 erp/sms/hms 각 OK, 마지막 파일 2회 반복 적용 OK, 라우팅 행 수 erp 8·sms 8·hms 7, 미동의 조직 `resolve_ai_route`는 erp·sms가 `oss-llm`/`oss-embed`/`oss-voice`, hms는 모든 기능에서 `hms-llm`/`hms-embed`/`hms-voice`(force_open_source true). RLS 스모크: 모듈러 92/92, 모놀리스 erp 21/21, sms 19/19, hms 52/52 통과. erp/sms 스키마에서 anon이 EXECUTE 가능한 함수 0개.

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경은 없다(코어 계약 그대로). 이 절은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2.2절 공통 페르소나를 admin-suite에 맞춰 옮기고 도메인 역할 행을 더한다. 시드는 `scripts/dev/seed-users.mjs --app <erp|sms|hms>`가 공통 행을 만든 뒤 앱 훅 `scripts/dev/seed-users.<app>.mjs`를 실행한다(ADM-06-007 소유). 앱마다 로컬 Supabase 프로젝트가 따로라(02장 7절, 개발 폴더 기준) 앱 하나씩 실행한다. 이메일은 모두 `<키>@dev.test`(예약 TLD, 실제 메일 없음), 비밀번호는 `DEV_SEED_PASSWORD`, 출력에 비밀번호를 쓰지 않는다. Supabase 호스트가 루프백이 아니면 즉시 종료한다.

**공통 페르소나를 그대로 쓰지 않는 이유**: admin-suite는 사용자가 조직을 만들 수 없고(01장 3.5절) 권한이 개인 조직이 아니라 운영자가 만든 기관 조직에 있다. 그래서 `owner`·`outsider`는 `signup_app` 가입이 아니라 운영자 프로비저닝 경로(service_role: 조직 생성 → owner 멤버십 → `app_entitlements(source=manual)` → `<app>.register_workspace` → `approve_profile`, 03장 2.1절)를 그대로 재현해 만든다. 나머지 역할은 owner 세션으로 실제 도메인 RPC를 호출해 만든다. service_role 직접 갱신은 `approve_profile`(이 제품의 실제 승인 경로, 04장 2절), `suspended`, `ops`뿐이다. 기대 결과의 `session_context`는 기관 조직 기준(`session_context(app, 기관 org)`)이고, 플랜은 erp·sms `default`, hms `contract`, 크레딧 잔액은 0(크레딧 미사용)이다.

### 10.1 공통 페르소나 (세 앱 공통, 앱마다 만듦)

| 키 | 만드는 방법(실제 경로) | 기대 결과 | 쓰임 |
|---|---|---|---|
| `owner` | 프로비저닝 재현: 기관 조직 "개발 기관 A" + owner 멤버십 + manual 엔타이틀먼트 + `register_workspace` + `approve_profile`. erp는 이어서 `erp.get_join_code`로 가입 코드를 읽어 훅이 다음 행에 쓴다 | `org.role=owner`, `entitled=true`, `my_role`: erp `master_admin`, sms `admin`, hms `admin` | 관리자 화면, 승인·초대 주체 |
| `admin` | owner 세션 `invite_member(org, user, 'admin')` → 본인 `accept_invite`. erp 모놀리스는 앱 행이 1개라 `signup_app` 없이 만든 계정도 가입 트리거가 pending으로 만들므로 `approve_profile`(viewer도 같음) | `org.role=admin`, `my_role`은 owner와 같은 관리자 역할 | 관리자 역할이 owner 전용 동작(소유권 이전)과 구분되는지 |
| `member` | 앱의 기본 도메인 역할(10.2~10.4절 표의 `member` 행) | 같은 표 | 역할 분기 |
| `viewer` | owner 세션 `invite_member(org, user, 'viewer')` → `accept_invite`(erp는 이어서 `approve_profile`). 도메인 행(employees·members·staff_profiles)은 만들지 않는다 | `entitled=true`이지만 `my_role` null → `/no-access`(02장 6절, `Hospital.md` 3장 #3 차단 설계) | "멤버십만 있고 도메인 역할 없음" 차단 |
| `outsider` | 프로비저닝 재현으로 다른 기관 조직 "개발 기관 B"의 owner | 자기 기관 owner. 기관 A의 도메인 행 0행, 기관 A org id로 RPC 호출 시 42501 | 교차 테넌트 RLS 거부. hms는 운영에서 병원마다 프로젝트가 따로지만 로컬 프로젝트 안의 조직 격리도 검증한다 |
| `no_app` | `signup_app` 없이 `auth.admin.createUser` | 10.5절(모놀리스/모듈러 차이) | 첫 진입 분기 |
| `pending` | erp만. `signup_app='erp'`로 생성, 가입 요청 없음 | 프로필 `status=pending` → `/pending` 가입 코드 입력 단계 | 승인제 첫 화면 |
| `suspended` | `member`와 같이 만든 뒤 service_role로 `profiles.status=suspended` | 403 | 차단 |
| `ops` | 생성 후 service_role로 `platform_role=platform_admin` | 이 제품에 운영자 화면은 없다(프로비저닝은 CLI, 02장 7절). 기관 멤버십이 없으면 `/no-access` | 선택(제안). `approve_profile`의 platform_admin 경로 단위 테스트용 |

### 10.2 erp 도메인 페르소나 (approval, 가입 코드)

| 키 | 만드는 방법(실제 RPC 경로) | 기대 결과 | 쓰임 |
|---|---|---|---|
| `member`(= staff) | `signup_app='erp'` 생성(pending) → 본인 `erp.request_join(<owner 조직 가입 코드>, 이름)` → owner `erp.decide_join_request(approve, 'staff')` → service `approve_profile` → 본인 `accept_invite` | `my_role=staff`, 대시보드만, `/inventory` 403, `employees`는 본인 행만 | 일반 직원 |
| `inventory_manager` | 같은 경로, 역할 `inventory_manager` | 재고 등록·입출고·조정 가능, `/sales` 403 | 재고 화면 |
| `sales_manager` | 같은 경로, 역할 `sales_manager` | 판매 가능, 입출고는 OUT만(D-3), 재고 차감은 `record_sale`로 성공 | 판매·동시성 |
| `join_requested`(가입 코드 대기자) | `signup_app='erp'` 생성 → `request_join` 까지만 | 프로필 pending, `join_requests.status=pending`, `/pending`에 "승인 대기", 도메인 SELECT 0행 | KIT-F-005 승인 전 차단, 승인 화면 목록 |
| `join_rejected` | `request_join` → owner `decide_join_request(reject, note)` | `/pending`에 거절 사유, 재신청 가능 | 거절 분기 |

### 10.3 sms 도메인 페르소나 (invite)

훅은 먼저 owner 세션으로 학급 "1-1"(학년 1)과 과목 1개를 만든다(`sms.classes`, `sms.subjects`는 admin 직접 쓰기, 4.2절).

| 키 | 만드는 방법(실제 RPC 경로) | 기대 결과 | 쓰임 |
|---|---|---|---|
| `member`(= teacher) | 생성 → owner `sms.invite_school_member(org, user, 'teacher', 이름)` → 본인 `sms.accept_school_invite(org)` | `my_role=teacher`, 출석 체크 가능, 과목 조회만, AI 질의 가능 | 교사 |
| `student` | 같은 경로, `student` + 학급 "1-1" + 학번 | `my_role=student`, `/student/dashboard`, 다른 학생 출석 0행, `/api/ai/*`·`/api/voice/*` 403 | 학생 화면, 미성년자 노출 범위 |
| `invited`(초대 대기) | 초대까지만(수락 안 함) | `members.status=invited`, `has_access=false`, `/invite/accept`로 이동 | 초대 수락 흐름 |

### 10.4 hms 도메인 페르소나 (invite, 로컬 hms 프로젝트만)

환자 데이터는 이 스크립트가 만들지 않는다(개발 환경에 실제 환자 데이터 금지, 개발 안내서 7절). 화면 개발용 가상 환자는 도메인 작업의 별도 픽스처가 만든다.

| 키 | 만드는 방법(실제 RPC 경로) | 기대 결과 | 쓰임 |
|---|---|---|---|
| `member`(= staff, 원무) | 생성 → owner(병원 admin) `invite_staff(org, user, 'staff', 이름)` → 본인 `accept_staff_invite(org)` | `my_role=staff`, 접수·예약 가능, `get_patient_chart` 42501 | 원무 |
| `doctor` | 같은 경로, `doctor` + 진료과 | `my_role=doctor`, 차트·진료기록 가능, 본인 가용 토글만 | 진료 |
| `lab_tech` | 같은 경로, `lab_tech` | `/patients` 403, 검사 작업 목록만 | 최소 권한 |
| `invited`(초대 대기) | 초대까지만 | `staff_profiles.status=invited`, `/invite/accept` | 초대 수락 흐름 |

### 10.5 모놀리스와 모듈러 차이 (`no_app`)

| 형태 | erp | sms | hms |
|---|---|---|---|
| 모놀리스(개발 기본, 앱별 단독 프로젝트) | 앱 행이 1개라 가입 트리거가 개인 조직을 자동 부트스트랩하고 approval이라 프로필 pending → `/pending` | invite라 트리거가 부트스트랩하지 않음 → `entitled=false` → `/no-access` | 같음(`/no-access`) |
| 모듈러 통합 DB(erp·sms) | `entitled=false` → `finishLogin`이 `bootstrap_app_for_org('erp')` 1회 → pending → `/pending`(04장 8.2절 3번 검증) | `/no-access`(invite라 부트스트랩하지 않음) | 해당 없음(통합 DB 제외) |

모듈러 통합 DB에서 `--app erp --app sms`를 함께 주면 두 훅을 차례로 실행하고 기관 조직을 앱마다 프로비저닝한다. admin-suite의 기관 엔타이틀먼트는 manual이므로 두 번째 앱에 `bootstrap_app_for_org`를 쓰지 않는다(`AUTH_ROADMAP.md` 2.3절 "모듈러 통합 DB" 행과 다른 점).
