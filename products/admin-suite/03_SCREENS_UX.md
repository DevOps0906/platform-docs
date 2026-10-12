# 03 화면과 UX: Admin Suite

## 1. 정보 구조와 화면 목록

플랜 접근 열: 세 앱 모두 기능 게이팅은 수량 한도(01장 4절)뿐이라 화면 단위 플랜 제한이 없다("전체"). Phase 2 엑셀 내보내기 버튼만 `export_xlsx`로 숨긴다.

### 1.1 공통(admin-kit 제공, 앱마다 같은 경로)

| 경로 | 화면 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|
| `/login` | 로그인(이메일, Google) | 비로그인 | 전체 | P0 |
| `/signup` | 가입(ERP만 공개, HMS/SMS는 초대 링크 전용) | 비로그인 | 전체 | P0 |
| `/pending` | 승인 대기 안내 + 가입 코드 입력 + 요청 상태 | 로그인(pending) | 전체 | P0 |
| `/invite/accept` | 초대 수락 | 초대받은 본인 | 전체 | P0 |
| `/no-access` | 접근 권한 없음(워크스페이스 없음, 정지) | 로그인 | 전체 | P0 |
| `/settings/account` | 계정(이름, 비밀번호, 로그아웃) | 전원 | 전체 | P0 |
| `/settings/audit` | 감사 로그 | owner/admin | 전체 | P1 |
| `/settings/billing` | 플랜과 구독(erp, sms) | owner | 전체 | P2 |

### 1.2 ERP

| 경로 | 화면 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|
| `/dashboard` | 대시보드(지표, 위험 재고, 최근 변동, 판매 추이) | 전원 | 전체(추이 기간은 `sales_trend_days`) | P0 |
| `/inventory` | 상품 목록 + 입출고/조정 | master_admin, inventory_manager, sales_manager(조회+출고) | 전체 | P0 |
| `/inventory/[id]` | 상품 상세 + 이동 이력 | 위와 같음 | 전체 | P1 |
| `/sales` | 판매 목록, 등록, 완료, 취소 | master_admin, sales_manager | 전체 | P0 |
| `/hr` | 임직원 목록, 권한 변경 모달 | master_admin | 전체 | P0 |
| `/hr/requests` | 가입 요청 승인/거절, 가입 코드 | master_admin | `max_members` | P0 |
| `/hr/departments` | 부서 트리 | master_admin | 전체 | P1 |
| `/me` | 내 정보(전화 수정) | 전원 | 전체 | P1 |
| `/settings` | 회사 설정 | master_admin | 전체 | P2 |

### 1.3 HMS

| 경로 | 화면 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|
| `/dashboard` | 관리자 대시보드 | admin | 전체 | P1 |
| `/queue` | 실시간 대기열 + 가용 토글 | doctor, admin | 전체 | P0 |
| `/calendar` | 예약 캘린더(월/주/일) | staff, admin(조회+생성), doctor(조회) | 전체 | P0 |
| `/patients` | 환자 목록/검색/등록 | staff, doctor, admin | 전체 | P0 |
| `/patients/[id]` | 환자 상세(원무 정보) | staff, admin | 전체 | P0 |
| `/patients/[id]/chart` | 환자 360 차트(진료기록, 검사) | doctor | 전체 | P0 |
| `/lab` | 검사 작업 목록 + 결과 입력/승인 | lab_tech, doctor | 전체 | P0 |
| `/billing` | 수납 | staff, admin | 전체 | P1 |
| `/staff` | 직원 초대/역할/상태 | admin | `max_staff` | P0 |
| `/settings/access-log` | 의료정보 접근 기록 | admin | 전체 | P0 |

### 1.4 SMS

| 경로 | 화면 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|
| `/admin/dashboard` | 출석 통계 + 학급별 출석률 + 실시간 피드 | admin, teacher | 전체 | P0 |
| `/admin/attendance` | 출석 체크 보드 | admin, teacher | 전체 | P0 |
| `/admin/classes` | 학급 CRUD | admin(쓰기), teacher(조회) | `max_classes` | P0 |
| `/admin/subjects` | 과목 CRUD | admin(쓰기), teacher(조회) | 전체 | P0 |
| `/admin/members` | 교사/학생 초대, 학급 배정, 역할·상태 | admin | `max_students` | P0 |
| `/admin/trend` | 출석 추이 | admin, teacher | `attendance_trend_days` | P1 |
| `/student/dashboard` | 내 출석 요약 + 오늘 과목 + 실시간 알림 | student | 전체 | P0 |

## 2. 사용자 플로우

### 2.1 조직 프로비저닝(운영자) → 첫 로그인

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 운영자 CLI | 고객사 이름, owner 이메일 입력 | service_role: Auth 초대 → 조직(비개인) 생성 → owner 멤버십 → `app_entitlements(source=manual)` → `<app>.register_workspace` → `approve_profile` | owner 이메일 중복 → 기존 사용자에 연결 |
| 2 | 초대 메일 → `/invite/accept` | 비밀번호 설정 | 세션 생성, `session_context(app, org)` | 링크 만료 → 재발송 요청 안내 |
| 3 | 앱 홈 | 첫 진입 | 역할 홈으로 리다이렉트(access.ts) | 워크스페이스 없음 → `/no-access` |

### 2.2 ERP 가입(승인제)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/signup` | 이름, 이메일, 비밀번호 | `signUp({ data: { signup_app: 'erp', full_name } })`, 이메일 인증 | 이메일 중복 → 로그인 안내 |
| 2 | `/pending` | 회사에서 받은 가입 코드 8자 입력 | `erp.request_join` | 코드 무효 P0002 → "코드를 다시 확인하세요"(5회/시간 제한) |
| 3 | `/hr/requests`(마스터 관리자) | 역할·부서 선택 후 승인 | `erp.decide_join_request` → 서버가 `approve_profile` | 상한 초과 → 402 "플랜 인원 한도" |
| 4 | `/pending`(신청자) | "가입 완료" 버튼 | `core.accept_invite` → 홈 | 거절됨 → 거절 사유 표시 |

### 2.3 SMS/HMS 초대(초대제)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/admin/members` 또는 `/staff` | 이메일, 역할, (학생) 학급·학번 / (직원) 진료과 입력. 14세 미만 동의 확인 체크(SMS) | 서버: 미가입이면 Auth Admin 초대 → 사용자 세션 RPC `invite_school_member`/`invite_staff` | 본인 초대 22023, 한도 초과 402 |
| 2 | 초대 메일 → `/invite/accept` | 비밀번호 설정 후 수락 | `accept_school_invite` / `accept_staff_invite` | 초대 없음 P0002 |
| 3 | 역할 홈 | - | `my_role`로 홈 결정 | - |

### 2.4 ERP 판매 등록

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/sales` | "판매 등록" → 상품 검색, 수량 | 클라이언트가 `request_id`(UUID) 생성 | - |
| 2 | 모달 | "판매 등록" | Server Action → `requireRole` → `erp.record_sale` | ER001 → "재고가 n개 부족합니다" / ER003 비활성 상품 |
| 3 | 목록 | - | Realtime으로 대시보드·재고 갱신 | 네트워크 오류 → 같은 `request_id`로 재시도(멱등) |

### 2.5 HMS 접수 → 진료 → 검사

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/calendar` | 빈 슬롯 클릭 → 환자 검색/선택 → 예약 | `create_appointment` | HM002 겹침, HM003 의사 불가 |
| 2 | `/calendar` 또는 `/queue` | 내원 시 "접수" | `transition_appointment(checked_in)`, 대기번호 부여 | HM001 상태 불가 |
| 3 | `/queue`(의사) | "진료 시작" | `in_consultation`, Realtime 반영 | 담당의 아님 42501 |
| 4 | `/patients/[id]/chart` | 진료기록 작성, 검사 의뢰 | 서버 암호화 → `add_medical_record`, `request_lab_test`, 접근 기록 | 키 누락 시 500(기동 단계에서 차단) |
| 5 | `/lab` | 시작 → 값 입력 → 저장 | `start_lab_test`, `save_lab_result`(이탈 키 계산) | HM004 누락 값 |
| 6 | `/lab`(다른 직원) | 승인 | `approve_lab_result` | HM005 본인 승인 |
| 7 | `/queue` | "진료 완료" | `completed`, `/billing`에 미수 생성(`record_charge`) | - |

### 2.6 SMS 출석 체크

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/admin/attendance` | 학급, 과목, 날짜(기본 오늘 KST) 선택 | 학생 그리드 + 기존 기록 로드, `sms:<org>:attendance` 구독 | 학생 0명 → 빈 상태 |
| 2 | 그리드 | 상태 버튼 클릭(낙관적 반영), "일괄 저장" | `mark_attendance_bulk` | SM002 기간 초과, SM001 학급 불일치 |
| 3 | `/student/dashboard` | - | 본인 행 변경 수신 → 5초 토스트 | - |

### 2.7 결제(Phase 2, erp/sms)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/settings/billing` | standard 선택 | 서버가 `payment_orders` 선저장(금액은 plans) | - |
| 2 | Toss 결제창 | 결제 | successUrl 복귀 → 서버 confirm → `confirm_payment_order` | PM001 금액 불일치(주문 failed 기록은 별도 호출 `fail_payment_order`, 05장 6절) |
| 3 | 플랜 화면 | - | 엔타이틀먼트 standard | 결제 실패 → 기존 플랜 유지 |

## 3. 화면별 명세

| 화면 | 목적 | 구성 | 데이터 출처 | 행동 | 크레딧 표시 |
|---|---|---|---|---|---|
| ERP `/dashboard` | 오늘 상황 한눈에 | 상단 지표 4개(매출은 크게, 나머지는 작은 텍스트 행), 위험 재고 표, 최근 변동 5건, 판매 추이(시간) | `erp.dashboard_metrics`, `erp.sales_trend`, `erp.inventory_moves` Realtime | 위험 품목 클릭 → 상품 상세 | 없음 |
| ERP `/inventory` | 상품 관리 | 좌측 카테고리 필터 + 우측 고밀도 표(SKU, 이름, 수량, 안전재고, 상태 배지) + 상세 패널 | `erp.products`, `erp.inventory_moves` | 등록, 수정, 입고/출고/조정(조정은 부호 선택 + 사유) | 없음 |
| ERP `/sales` | 판매 처리 | 상태 탭(전체/대기/완료/취소), 표, 등록 모달 | `erp.sales` | 등록, 완료, 취소(사유) | 없음 |
| ERP `/hr` | 인사 | 직원 표 + 권한 모달(ERP 역할, 상태, 부서, 직급) | `erp.employees`, `core.org_members` | `set_employee_role`, `set_employee_status`, `update_employee_profile` | 없음 |
| HMS `/queue` | 진료 흐름 | 의사별 열(칸반형) 또는 단일 의사 리스트, 대기번호, 경과 시간, 알레르기 배지 | `appointments` Realtime(필터 org), `patients` | 진료 시작/완료, 가용 토글 | 없음 |
| HMS `/patients/[id]/chart` | 진료 | 좌측 환자 헤더(알레르기 Medical Red), 우측 타임라인(예약/기록/검사 아이콘 구분), 하단 작성 패널 | `get_patient_chart`(접근 기록) | 기록 작성, 정정, 검사 의뢰 | 없음 |
| HMS `/lab` | 검사 | 좌측 작업 목록(상태 필터), 우측 입력 패널(항목·단위·정상범위, 이탈 시 테두리 #E11D48 + 경고 아이콘) | `list_lab_worklist`, `lab_test_catalog` | 시작, 저장, 승인, 재개방 | 없음 |
| HMS `/settings/access-log` | 감사 | 기간·행위자·환자 필터, 사유, 건수 | `phi_access_log` | CSV 내보내기(P1, 기록 남김) | 없음 |
| SMS `/admin/attendance` | 출석 | 학급/과목/날짜 선택 바 + 학생 그리드(학번, 이름, 4상태 토글) + 일괄 저장 | `sms.members`, `sms.attendance` | 상태 변경, 일괄 저장 | 없음 |
| SMS `/student/dashboard` | 본인 확인 | 이번 달 출석률, 지각/조퇴/결석 횟수, 오늘 과목 목록 | `sms.student_summary`, `sms.attendance` Realtime | 없음 | 없음 |

## 4. 메인페이지(랜딩) 디자인 방향

공개 마케팅 랜딩은 없다(`docs/products/_design-guide/REFERENCES.md:165`, `SKILLS.md:98`). 이 제품의 "메인페이지"는 각 앱의 로그인 화면과 로그인 직후 역할 홈이다. 절차는 `DESIGN_PRINCIPLES.md` 1~5단계를 따른다.

### 4.1 레퍼런스

| 구분 | 제목 | 출처 | URL | 참고 포인트(가져올 것) | 적용 화면 |
|---|---|---|---|---|---|
| 앱 | ERP/Admin Dashboard | Dribbble | https://dribbble.com/shots/25055107-ERP-Admin-Dashboard | 시스템 상태, 재무 지표, 사용자 활동을 한 화면에서 보는 운영 요약 | ERP 홈, HMS 관리자 대시보드 |
| 앱 | Table data view for admin dashboard | Dribbble | https://dribbble.com/shots/22988094-Table-data-view-for-admin-dashboard | 행 선택 상태, 페이지네이션, 페이지당 행 수 드롭다운 | admin-kit DataTable |
| 앱 | School Management Dashboard (MindInventory) | Dribbble | https://dribbble.com/shots/21026510-School-Management-Dashboard | 출결·시간표를 한눈에 보는 위젯과 필터 | SMS 홈 |
| 앱 | Student Attendance Management System | Dribbble | https://dribbble.com/shots/20456718-Student-Attendance-Management-System-School-Admin-Dashboard | 출결 추적, 보고서, 결석 알림의 흐름 | SMS 출석 |
| 앱 | School Management Dashboard (CMARIX) | Dribbble | https://dribbble.com/shots/6372267-School-Management-Dashboard | 학생/직원 기록, 출결, 수납을 한 플랫폼에서 다루는 메뉴 구조 | SMS·HMS 내비게이션 구조 |

HMS 전용 레퍼런스는 `REFERENCES.md`에 없다. 위 표의 표·운영 요약 레퍼런스를 재사용하고, 새 레퍼런스가 필요하면 `REFERENCES.md`에 먼저 추가한다(인용 규칙).

### 4.2 브리프

| 항목 | ERP | HMS | SMS |
|---|---|---|---|
| 주제 | 입고·출고 전표, SKU 라벨, 안전재고 선 | 접수 번호표, 진료 대기 순서, 검사 정상범위 | 출석부 격자, 교시, 학급 반 번호 |
| 대상 | 사무실 PC 앞의 재고·영업 담당 | 접수대와 진료실의 병원 직원, 장시간 화면 응시 | 교실 태블릿을 든 교사, 휴대폰으로 확인하는 학생 |
| 주된 일 | 오늘 부족 재고와 매출을 확인하고 입출고를 기록 | 다음 환자를 놓치지 않고 진료·검사를 이어 감 | 한 교시 출석을 30초 안에 체크 |
| 고유 어휘 | 전표 번호, 수량 증감(+/-), 바코드형 SKU | 대기번호, 알레르기 경고, 정상범위 막대 | 출석부 칸, 출석/지각/조퇴/결석 4색 |
| 피할 인상 | 모든 KPI를 같은 카드로 나열하는 SaaS 카드 키트, 의미 없는 차트 장식(`REFERENCES.md:170`) | 같음 + 공포감을 주는 빨강 남용 | 같음 + 유아틱한 이모지(원본 폐기 항목) |

### 4.3 토큰 플랜

기존 토큰(`analysis:1155`, 사용자 결정 "디자인 A: 앱별 테마")을 후보로 두고 5단계 검토를 거쳤다.

| 앱 | 색(이름 hex) | 서체 역할 | 검토 결과 |
|---|---|---|---|
| ERP | 코발트 전표 #0047AB(주), 경고 오렌지 #FF8C00(부족·긴급만), 장부 회색 #F8FAFC(배경), 먹선 #1E293B(본문), 괘선 #CBD5E1 | 본문·표: Pretendard(한국어, tabular-nums), 숫자 강조: Pretendard SemiBold. 한 가족만 | 원본 토큰 유지(`ERP-Wesite/PRD.md:85-89`). 오렌지는 상태 의미일 때만, 버튼 기본색으로 쓰지 않는다 |
| HMS | 야간 병동 #0F172A(배경), 메디컬 레드 #E11D48(경고 전용), 수술포 청록 #14B8A6(정상·진행), 차트 회백 #E2E8F0(본문), 패널 #1E293B | 본문: Pretendard, 수치: Pretendard tabular | 원본 다크 테마 유지(`Hospital/PRD.md:73-75`). 생성형 기본값 2번(거의 검정 + 단일 강조)에 걸리는지 검토: 배경은 주제색(남색)이고 빨강은 경고에만 쓰며 청록으로 정상 상태를 표현해 단일 강조가 아니다. 장시간 응시 근거(PRD "눈의 피로 최소화")로 유지 |
| SMS | 칠판 인디고 #4F46E5(주), 분필 회색 #F9FAFB(배경), 잉크 #111827, 출석 #10B981 / 지각 #F59E0B / 결석 #EF4444 / 조퇴 #0EA5E9 | 본문: Noto Sans KR(원본 Inter+Noto에서 한 가족으로 축소), 숫자 tabular | 원본 토큰 유지(`REFERENCES.md:169`). 상태 4색은 범례와 함께 |

공통 원칙: (1) 상태색과 표 가독성이 주인공, (2) 위계는 크기보다 굵기와 색 대비, (3) 반경은 위계별로 다르게(패널 8px, 버튼 6px, 배지 999px), (4) 모션은 사용자 행동 응답만, (5) 대담함은 앱마다 한 곳: ERP 대시보드 상단의 "오늘 매출" 숫자, HMS 대기열의 대기번호, SMS 출석 그리드의 4색 토글.

로그인 화면 ASCII 와이어프레임(두 안 비교 후 B 선택)

```
안 A: 중앙 카드형(생성형 기본값 4번에 가까움) - 버림
+------------------------------------------+
|              [  로그인 카드  ]            |
+------------------------------------------+

안 B: 좌측 정렬 2열(선택)
+--------------------------------------------------+
| Admin Suite ERP                                  |
|                                                  |
| 로그인                    |  오늘 해야 할 일 예시  |
| [이메일            ]      |  (앱 주제 그림 1개:     |
| [비밀번호          ]      |   ERP 입출고 전표 /     |
| [로그인] [Google로 계속]  |   HMS 대기번호표 /      |
| 가입 코드가 있나요? 가입  |   SMS 출석부 칸)        |
+--------------------------------------------------+
```

ERP 홈 와이어프레임(좌측 정렬)

```
+--------+-----------------------------------------------+
| 사이드 | 오늘 매출 1,240,000원 (크게)   판매 12 취소 1 |
| 바     | SKU 312 · 부족 7 · 직원 18 (한 줄 텍스트)       |
| (역할  +-----------------------------+-----------------+
|  필터) | 위험 재고 표(부족 품목만)      | 최근 재고 변동  |
|        |                             | (실시간 5건)    |
|        +-----------------------------+-----------------+
|        | 판매 추이(시간, KST)                           |
+--------+-----------------------------------------------+
```

### 4.4 생성형 기본값 회피 검토

| # | 기본값 | 판정 |
|---|---|---|
| 4 | SaaS 카드 키트 | ERP 지표를 카드 4개로 나누지 않고 매출 1개만 크게, 나머지는 한 줄 텍스트 |
| 5 | 자간 넓힌 대문자 아이브로, 모노스페이스 데이터 라벨 | 쓰지 않는다. 숫자는 tabular 본문 서체 |
| 6 | 큰 숫자 히어로 | 운영 지표라 허용(`DESIGN_PRINCIPLES.md` 대시보드 절), 1개만 |
| 8, 9 | 대문자 라벨, 불필요한 라벨 | 한국어 라벨만 |
| 11 | 섹션 등장 효과, 카드 호버 전환 | 없음 |
| 12 | 습관적 기본 서체 | Inter 제거, 한국어 본문 서체 지정 |

카피는 01장 6.4절 금지 문구를 통과해야 한다. 예: 로그인 화면에 고객사 수, 절감률 같은 수치를 넣지 않는다.

## 5. 상태, 오류, 빈 화면

| 상황 | 표시 |
|---|---|
| Realtime 연결 끊김 | 헤더에 "실시간 연결이 끊겼습니다. 다시 연결 중" + 마지막 갱신 시각. 재연결 시 전체 재조회 1회 |
| 크레딧 부족(402) | 해당 없음(크레딧 없음). 플랜 한도 초과 402는 "현재 플랜의 인원 한도(50명)에 도달했습니다. 플랜을 확인하세요" |
| 권한 없음(403) | 서버 렌더 403 페이지: "이 화면은 판매 관리자만 볼 수 있습니다". 메뉴에 자물쇠를 노출하지 않는다 |
| 승인 대기 | `/pending`: 요청 상태(대기/거절 사유), 가입 코드 입력 |
| 재고 부족 ER001 | 모달 인라인: "재고가 3개 부족합니다(현재 2개)" |
| 상태 전이 불가 | "이미 취소된 판매입니다" 등 현재 상태를 말한다 |
| 검사 값 누락 HM004 | 해당 입력칸 강조 + "HGB 값을 입력하세요" |
| 네트워크 오류 | 토스트 + 재시도 버튼(지수 백오프 1s, 2s, 4s, 최대 3회, `School_Management_System/PRD.md:112`) |
| 빈 상태 | "아직 상품이 없습니다. 첫 상품을 등록하세요", "오늘 접수된 환자가 없습니다", "이 학급에 학생이 없습니다. 학생을 초대하세요" |
| compliance WARN/FAIL | 해당 없음 |
| 잡 진행률 | 해당 없음 |

## 6. 접근성과 반응형

| 항목 | 기준 |
|---|---|
| 키보드 | 표 행 이동(위/아래), 출석 그리드 숫자키 1~4로 상태 선택(제안), 모든 버튼 `:focus-visible` |
| 대비 | 본문 4.5:1 이상. HMS 다크에서 #E2E8F0/#0F172A 확인. 상태는 색 + 아이콘 + 텍스트 |
| 폭 | 1024px 미만 햄버거 사이드바, 375px에서 표는 가로 스크롤 컨테이너(페이지 전체 가로 스크롤 없음). 출석 보드는 768px 태블릿 우선 |
| 모션 | `prefers-reduced-motion` 시 대기열 깜빡임(Live 배지) 정지 |
