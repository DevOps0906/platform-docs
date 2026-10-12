# 01 PRD: Admin Suite

이 문서는 공유 코어 `packages/admin-kit`(KIT)와 앱 3개(ERP, HMS, SMS)를 절마다 나눠 적는다(확정 결정 2). 근거 표기에서 `analysis`는 `docs/products/00_MERGE_ANALYSIS.md`다.

## 1. 페르소나와 핵심 과제

| 앱 | 페르소나 | 상황 | 목표 | 좌절(원본 근거) |
|---|---|---|---|---|
| ERP | 김재고(물류팀 재고 관리자, 38세) | 하루 수십 건 입출고를 기록하고 안전재고 이하 품목을 매일 아침 확인 | 입출고와 판매가 동시에 일어나도 수량이 맞는 것 | 동시 판매 시 재고가 한 건만 차감되고, 감소 조정이 불가능(`docs/reviews/ERP-Wesite.md:68`, `:78`) |
| ERP | 박대표(마스터 관리자, 52세) | 신규 직원 가입 승인, 오늘 매출 확인 | 승인된 사람만 들어오고 직원이 자기 권한을 못 올리는 것 | 누구나 콘솔에서 자기를 Master Admin으로 바꿀 수 있음(`docs/reviews/ERP-Wesite.md:88`) |
| HMS | 이원무(원무과, 29세) | 환자 접수, 예약, 수납 | 오전 9시 이전 예약도 대기열에 바로 보이는 것 | KST 00~09시 데이터가 전날로 집계(`docs/reviews/Hospital.md:87`) |
| HMS | 정의사(내과 전문의, 45세) | 대기 환자 호출, 진료기록 작성, 검사 의뢰 | 환자 이력을 한 화면 타임라인으로 보는 것 | 타임라인이 실데이터와 무관(`docs/reviews/Hospital.md:65`) |
| SMS | 최교사(1학년 담임, 34세) | 매 교시 출석 체크 | 태블릿에서 한 번에 체크하고 학생 화면에 즉시 반영 | 출석 보드가 작업 트리에서 삭제됨(`docs/reviews/School_Management_System.md:67`) |
| SMS | 한학생(고1) | 이번 달 지각·결석 확인 | 내 기록만 실시간으로 보는 것 | 학생 대시보드 없음(`docs/reviews/School_Management_System.md:58`) |

핵심 과제 3개

| # | 과제 | 측정 |
|---|---|---|
| 1 | 세 앱 모두 접근제어가 실질적으로 깨져 있다(`analysis:1110`). 서버·DB에서 역할을 강제하고 자기 권한 상승을 원천 차단한다 | 05장 RLS 스모크 테스트 전 항목 통과 |
| 2 | 재고·예약·검사·출석의 상태와 수량이 동시성·시간대와 무관하게 정확해야 한다 | 동시 판매 50건 후 재고 음수 0건, KST 경계 테스트 통과 |
| 3 | 공통 코드는 한 번만 만들고 세 앱이 같은 버전을 쓴다(`analysis:1206-1212`) | admin-kit 외부에 Supabase 클라이언트/가드/날짜 코드가 0개 |

## 2. 범위: MVP와 Phase

| 기능 | 단계 | 근거 |
|---|---|---|
| KIT: 인증, 프로필 상태 게이트, 서버 가드, 역할 매트릭스, AppShell, DataTable, KST 유틸, Realtime 훅, 감사 로그 화면 | MVP | `analysis:1120-1155` |
| KIT: 승인제(ERP)·초대제(SMS, HMS) 가입 | MVP | 사용자 결정 "가입 정책 C"(`analysis:1242`) |
| KIT: Toss 구독(standard 플랜) | Phase 2 | 원본에 결제 근거 없음. 출시는 계약형(수동 엔타이틀먼트) 제안 |
| ERP: 상품, 입출고/조정, 판매(상태/취소), 대시보드, 직원/부서, 가입 승인 | MVP | `analysis:1159-1169` |
| ERP: 판매 추이 차트, 설정 저장, 상품 이미지 | MVP 직후(P1) | `docs/reviews/ERP-Wesite.md:128`, `:130` |
| ERP: 엑셀 내보내기 | Phase 2 | `docs/products/_design-guide/SKILLS.md:46` |
| HMS: 직원 초대/역할, 환자 등록/검색/상세, 예약 캘린더, 실시간 대기열, 진료기록, 검사 의뢰/입력/승인, 접근 기록 | MVP | `analysis:1171-1182` |
| HMS: 수납, 관리자 대시보드 실데이터 | P1 | `Hospital/PRD.md:19`, `docs/reviews/Hospital.md:120` |
| HMS: 결과지 첨부(Storage), 처방전 출력 | Phase 2 | 근거 없음, 제안 |
| SMS: 학급/과목 CRUD, 구성원 초대·배정, 출석 체크 보드, 관리자 통계, 학생 대시보드 | MVP | `analysis:1183-1190` |
| SMS: 출석 추이 그래프, 학생 실시간 알림 | P1 | `docs/reviews/School_Management_System.md:108`, `:22` |
| 공개 마케팅 랜딩 | 없음 | 내부 시스템, 로그인 화면만(`docs/products/_design-guide/REFERENCES.md:165`) |

## 3. 기능 요구사항과 수용 기준

### 3.1 admin-kit (KIT)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| KIT-F-001 | Supabase 클라이언트 3종 | 통합 | `_platform-core` auth 모듈의 클라이언트를 재수출만 한다. 자체 구현 금지 | admin-kit 외부에서 `createServerClient` 직접 호출 0건 | `analysis:1124`, `SHARED_MODULES.md` 2장 |
| KIT-F-002 | 서버 라우트 가드 `createAdminProxy` | 통합+디벨롭 | 세션 갱신 → `session_context(app, org)` 1회 → 미로그인 `/login`, 프로필 없음 로그아웃, pending `/pending`, suspended 403, 엔타이틀먼트 없음 `/no-access`, 역할 미허용 경로 403 | 역할별 미허용 URL 직접 입력 시 RSC 페이로드 없이 403 HTML | `analysis:1125`, `docs/reviews/Hospital.md:83` |
| KIT-F-003 | 역할→페이지 매트릭스 팩토리 | 통합 | 앱이 `defineAccess({role: PageKey[]})`로 선언. 메뉴 필터와 가드가 같은 매트릭스를 쓴다 | 매트릭스 밖 메뉴는 렌더되지 않는다(자물쇠 노출 금지) | `Hospital/src/lib/permissions.ts:5-10`, `docs/reviews/Hospital.md:73` |
| KIT-F-004 | `requireRole(app, roles)` | 신규 | 모든 Server Action/Route Handler 첫 줄. DB RPC가 2차 검사 | 미허용 역할 호출 시 403, DB까지 가지 않음 | `docs/reviews/ERP-Wesite.md:122` |
| KIT-F-005 | 가입 승인제 | 디벨롭 | 가입 코드(8자) 입력 → 가입 요청 → 관리자 승인(역할·부서 지정) → 본인 수락 → 활성. pending 사용자는 `/pending` 안내 | 승인 전 도메인 테이블 SELECT 0행 | `ERP-Wesite/PRD.md:39`, `analysis:1129` |
| KIT-F-006 | 초대제 | 신규 | 관리자가 이메일 입력 → 서버가 Auth Admin 초대(미가입자) → 도메인 RPC로 초대 행 생성 → 본인 수락 | 수락 전 `has_access=false` | `analysis:1130`, `docs/reviews/School_Management_System.md:104` |
| KIT-F-007 | 사용자 수명주기 | 신규(기획 공백 2) | 아래 3.5절 표 | 정지 즉시 다음 요청부터 403 | `analysis:1229` |
| KIT-F-008 | AppShell | 통합 | 사이드바(역할 필터) + 헤더 + 로그아웃 + 1024px 미만 햄버거 | 375px에서 가로 스크롤 없음 | `docs/reviews/ERP-Wesite.md:84` |
| KIT-F-009 | DataTable/FormModal/ConfirmDialog/Toast/KpiCard/차트 래퍼 | 통합 | 행 선택, 페이지당 행 수 20/50/100, 서버 페이지네이션, `alert()` 금지 | 1만 행 테이블 첫 페이지 500ms 이내 | `ERP-Wesite/CLAUDE.md` 5절 |
| KIT-F-010 | KST 날짜 유틸 | 신규 | `kstDayRange(date)`, `kstMonthRange`, `formatKst`. DB 집계 RPC도 KST 경계 | 00:30 KST 데이터가 당일로 집계 | `analysis:1147` |
| KIT-F-011 | `useRealtimeTable` | 통합 | 채널 1개, payload 부분 갱신, `<app>:<org>:<entity>` 채널명, 언마운트 시 해제 | 같은 화면 구독 채널 수 = 1 | `docs/reviews/Hospital.md:61` |
| KIT-F-012 | 감사 로그 화면 | 디벨롭 | `core.audit_log` 조회(owner/admin). 필터: 기간, 행위자, action | 역할 변경 1건 → 목록 1행 | `analysis:1138`, `CORE_SPEC.md` 11장 |
| KIT-F-013 | 계정 설정 | 통합 | 표시 이름, 비밀번호 변경, 로그아웃만. 프로젝트 URL/키 표시 금지 | 화면에 `supabase.co` 문자열 0개 | `docs/reviews/ERP-Wesite.md:72` |
| KIT-F-014 | 타입 생성 | 신규 | `pnpm db:types`가 앱별 스키마 타입 생성. `as any` 금지 | lint `no-explicit-any` 오류 0 | `analysis:1154` |

### 3.2 ERP

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| ERP-F-001 | 상품 CRUD | 유지 | SKU(조직 내 유일, 영숫자·`_-` 64자), 이름, 카테고리, 단가(0 이상), 안전재고. 초기 수량은 0, 이후 입고로만 | 같은 SKU 재등록 시 409 | `docs/reviews/ERP-Wesite.md:35` |
| ERP-F-002 | 입출고/조정 | 디벨롭 | `record_inventory_move`: IN/OUT 양수, ADJUSTMENT 부호 있음 + 사유 2자 이상. 결과 수량 음수 불가(ER001). `request_id` 멱등 | 감소 조정 -2 성공, 음수 결과 ER001 | `docs/reviews/ERP-Wesite.md:78`, `:121` |
| ERP-F-003 | 재고 부족 판별 | 디벨롭 | `is_low_stock = quantity <= safety_stock` 생성 컬럼. 위험 재고 표는 이 값으로 필터 | 정상 품목만 있을 때 위험 표 0행 | `docs/reviews/ERP-Wesite.md:79` |
| ERP-F-004 | 판매 등록 | 디벨롭 | `record_sale`: 단가는 상품 단가로 서버 고정, `quantity >= n` 조건부 차감 + SALE 이력 한 트랜잭션. sales_manager가 재고 차감 권한 없이도 성공 | 동시 50건 후 재고 = 초기 - 성공 건수 | `docs/reviews/ERP-Wesite.md:91` |
| ERP-F-005 | 판매 상태와 취소 | 디벨롭 | pending/completed/canceled. 취소 사유 필수, completed 취소 시 재고 복원(SALE_CANCEL) | 취소 후 재고 원복, 재취소 ER002 | `docs/reviews/ERP-Wesite.md:127` |
| ERP-F-006 | 대시보드 지표 | 디벨롭 | 당일(KST) 매출 합·건수·취소 건수, 활성 SKU, 부족 SKU, 활성 직원, 부족 품목 5개. RPC 1회 | 전체 행 조회 0회 | `ERP-Wesite/PRD.md:55`, `docs/reviews/ERP-Wesite.md:102` |
| ERP-F-007 | 판매 추이 | 디벨롭 | 시간(당일)/일(당월)/월 버킷, KST 기준, 최대 366일 | 23:30 KST 판매가 그날 23시 버킷 | `ERP-Wesite/PRD.md:57` |
| ERP-F-008 | 최근 재고 변동 실시간 | 디벨롭 | `erp.inventory_moves` INSERT 구독, 상품명은 클라이언트 상품 맵으로 보강, reload 금지 | 새 이력 1초 이내 상단 표시 | `docs/reviews/ERP-Wesite.md:76` |
| ERP-F-009 | 부서 CRUD | 디벨롭 | 이름(조직 내 유일, 60자), 상위 부서(트리) | 마스터 관리자만 생성 | `docs/reviews/ERP-Wesite.md:129` |
| ERP-F-010 | 임직원 디렉토리 | 디벨롭 | 이름, 부서, 직급, 전화, ERP 역할, 상태. 본인은 전화만 수정 | staff는 본인 행만 조회 | `ERP-Wesite/PRD.md:79` |
| ERP-F-011 | 권한 변경 모달 | 통합(KIT 승격) | ERP 역할(재고/판매/일반)과 상태(활성/정지). 자기 자신 불가. 마스터 관리자 = core owner/admin | 본인 역할 변경 시 42501 | `docs/reviews/ERP-Wesite.md:39` |
| ERP-F-012 | 가입 승인 | 디벨롭 | KIT-F-005. 가입 코드 조회/재발급은 마스터 관리자 | 재발급 뒤 이전 코드 P0002 | `ERP-Wesite/PRD.md:39` |
| ERP-F-013 | 설정 | 디벨롭 | 회사명, 기본 안전재고, 재고 부족 알림 on/off 저장 | 저장 후 새로고침해도 유지 | `docs/reviews/ERP-Wesite.md:73` |
| ERP-F-014 | 상품 이미지 | 신규 | `org-files/<org>/erp/product/<uuid>.<ext>`, 5MB, jpeg/png/webp | 다른 경로 저장 시 22023 | `ERP-Wesite/PRD.md:25` |

ERP 역할 매트릭스(`analysis:1241` 권고 A)

| 화면 | master_admin | inventory_manager | sales_manager | staff |
|---|---|---|---|---|
| 대시보드 | O | O | O | O |
| 재고(조회) | O | O | O | - |
| 재고(등록/수정/입출고/조정) | O | O | 출고만(제안) | - |
| 판매 | O | - | O | - |
| 인사/부서/가입 승인 | O | - | - | 본인 정보만 |
| 설정, 감사 로그 | O | - | - | - |

### 3.3 HMS

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| HMS-F-001 | 직원 초대/역할 | 디벨롭 | admin이 doctor/staff/lab_tech 초대, 역할·상태 변경(자기 자신 불가). OVERRIDE 비밀번호 없음 | lab_tech가 `/patients` 직접 입력 시 403 | `docs/reviews/Hospital.md:81` |
| HMS-F-002 | 환자 등록 | 디벨롭 | 차트번호(병원 내 유일), 이름, 성별, 생년월일, 연락처(암호화), 혈액형, 알레르기, CRM 태그(최대 10). 개인정보 수집 동의 체크 필수 | 동의 없이 HM006 | `docs/reviews/Hospital.md:66` |
| HMS-F-003 | 환자 검색 | 디벨롭 | 이름 접두, 차트번호, 전화 끝 4자리. 최대 50건. 검색 행위 기록 | 검색 1회 → 접근 기록 1행 | `docs/reviews/Hospital.md:118` |
| HMS-F-004 | 환자 360 | 디벨롭 | 기본정보(성별 실데이터), 알레르기 경고, CRM 태그, 예약+진료기록+검사 병합 타임라인(시간 역순). 진료 내용은 doctor만 | admin(비의사)이 차트 열람 시 42501 | `docs/reviews/Hospital.md:65`, `:121` |
| HMS-F-005 | 예약 캘린더 | 디벨롭 | 월/주(7일)/일, 의사 필터, 빈 슬롯 클릭 → 예약 생성, 현재 범위만 조회, visit_type 4종 | 주별 뷰에 토·일 표시, 겹치는 예약 HM002 | `docs/reviews/Hospital.md:63`, `:75` |
| HMS-F-006 | 실시간 대기열 | 디벨롭 | checked_in 이후 상태를 의사별로 표시, 채널 1개, 진료 시작/완료는 담당의 또는 admin만 | 접수 1초 이내 의사 화면 반영(PRD 0.2초 목표는 측정 지표) | `Hospital/PRD.md:51-55`, `:77` |
| HMS-F-007 | 의사 가용 토글 | 유지 | 본인만. false면 신규 예약 생성 HM003 | 다른 의사 토글 시 42501 | `Hospital/PRD.md:55` |
| HMS-F-008 | 진료기록/처방 | 디벨롭 | doctor 작성, 본문 앱 계층 암호화, 수정 불가(정정은 새 행 amends_id) | UPDATE 시 42501 | `Hospital/PRD.md:17` |
| HMS-F-009 | 검사 의뢰 | 디벨롭 | doctor가 CBC/LFT/UA 의뢰 | 의뢰 즉시 작업 목록 표시 | `docs/reviews/Hospital.md:122` |
| HMS-F-010 | 검사 결과 입력 | 유지+디벨롭 | 모든 항목 숫자 필수(빈 값 0 대체 금지), 정상범위 이탈 키 서버 계산 + Medical Red 표시, 저장 후 목록 갱신 | 누락 항목 HM004 | `docs/reviews/Hospital.md:68` |
| HMS-F-011 | 검사 승인 | 디벨롭 | lab_tech 또는 doctor, 입력자와 다른 사람(제안: 이중 확인). 승인 후 값 불변, 정정은 재개방(사유) | 입력자 본인 승인 HM005 | `Hospital/PRD.md:21` |
| HMS-F-012 | 수납 | 디벨롭(P1) | 예약당 1건, 미수→수납→환불(admin), 결제수단 4종 | 환불 사유 없으면 22023 | `Hospital/PRD.md:19` |
| HMS-F-013 | 관리자 대시보드 | 디벨롭(P1) | 오늘 예약/내원/완료/취소/노쇼 분리, 신규 환자, 오늘·어제·이번 달 수납액, 진료과 비율. 하드코딩 0 | 취소와 노쇼가 다른 숫자 | `docs/reviews/Hospital.md:62`, `:64` |
| HMS-F-014 | 접근 기록 | 신규(기획 공백 3) | 민감정보 조회/작성 전부 `phi_access_log`(행위자, 역할, 환자, 사유, 건수). 열람 사유 필수. admin만 조회 | 차트 열람 1회 → 1행, UPDATE 불가 | `analysis:1230` |

### 3.4 SMS

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| SMS-F-001 | 학급 CRUD | 유지(복원) | 이름(학교 내 유일), 학년 1~12, 담임 | admin만 쓰기 | `docs/reviews/School_Management_System.md:39` |
| SMS-F-002 | 과목 + 학급 매핑 | 유지(복원) | 과목은 학급에 속한다(HEAD 구조), 담당 교사 선택 | 같은 학급 같은 과목명 409 | `School_Management_System/PRD.md:94` |
| SMS-F-003 | 구성원 초대 | 신규 | admin이 교사/학생 초대, 학생은 학급·학번 지정(F-CLASS-02) | 수락 전 출석 대상 아님 | `docs/reviews/School_Management_System.md:104` |
| SMS-F-004 | 역할/학급 변경 | 통합 | admin만, 자기 자신 불가 | 학생 본인 역할 변경 42501 | `docs/reviews/School_Management_System.md:49` |
| SMS-F-005 | 출석 체크 보드 | 유지(복원) | 학급+과목+날짜 선택 → 학생 그리드 → 4상태 버튼, 일괄 저장(최대 200건), upsert | 같은 학생·과목·날짜 1행 | `School_Management_System/PRD.md:100-102` |
| SMS-F-006 | 출석 날짜 제한 | 신규(제안) | 미래 불가. 교사는 KST 오늘 기준 7일(학교 설정 0~60) 이전까지만, admin 무제한 | 교사 30일 전 수정 SM002 | 제안: 사후 조작 방지 |
| SMS-F-007 | 실시간 동기화 | 유지 | `sms.attendance` 구독(학급 필터), 학생 화면은 RLS로 본인 행만 수신 | 교사 변경 1초 이내 학생 화면 반영 | `School_Management_System/PRD.md:104` |
| SMS-F-008 | 관리자 통계 | 디벨롭 | 출석률 = (출석+지각+조퇴)/기록 수, 정시 출석률 = 출석/기록 수, 미체크 = 기대(학급별 활성 학생 x 과목) - 기록. 학급별 같은 정의 | 100% 초과 불가 | `docs/reviews/School_Management_System.md:55`, `analysis:1232` |
| SMS-F-009 | 학생 대시보드 | 유지(복원) | 이번 달 출석률, 지각/조퇴/결석 횟수, 오늘 과목 | 다른 학생 기록 0행 | `School_Management_System/PRD.md:88` |
| SMS-F-010 | 출석 추이 | 디벨롭(P1) | 일별 출석률, 학급 필터, 최대 366일 | 기간 초과 22023 | `School_Management_System/PRD.md:86` |
| SMS-F-011 | 학생 실시간 알림 | 디벨롭(P1) | 본인 출석 상태 변경 시 5초 토스트 | 지각 처리 즉시 알림 | `docs/reviews/School_Management_System.md:22` |

### 3.5 사용자 수명주기(기획 공백 2)

| 단계 | ERP(승인제) | HMS(초대제) | SMS(초대제) | 공통 규칙 |
|---|---|---|---|---|
| 조직 생성 | 플랫폼 운영자가 서버 스크립트로 조직 + owner + 엔타이틀먼트(manual) + `register_workspace` | 같음 | 같음 | 사용자가 조직을 만들 수 없다 |
| 가입 | 가입 폼(`signup_app=erp`) → 프로필 pending → 가입 코드로 `request_join` | 관리자가 이메일 초대 → 초대 메일 링크로 비밀번호 설정 | 같음 | 개인 조직이 생겨도 workspace가 없어 도메인 데이터 접근 불가 |
| 승인/수락 | 마스터 관리자 `decide_join_request` → 서버가 `approve_profile` → 본인 `accept_invite` | 본인 `accept_staff_invite` | 본인 `accept_school_invite` | 관리자는 자기 자신을 승인·초대할 수 없다 |
| 역할 변경 | `set_employee_role` | `set_staff_role` | `set_member_role` | 자기 역할 변경 불가, core admin 권한은 core `change_member_role`만 |
| 정지 | `set_employee_status(suspended)` | `set_staff_status` | `set_member_status` | 다음 요청부터 `has_access=false` |
| 탈퇴/제거 | core `remove_member` | 같음 | 같음 | 업무 기록(created_by 등)은 남는다 |
| 로그아웃 | AppShell 하단 | 같음 | 같음 | 세션 쿠키 제거 후 `/login` |

## 4. 요금과 크레딧

정본 출처: 원본 3개 모두 요금 근거가 없다(`ERP-Wesite/PRD.md`, `Hospital/PRD.md`, `School_Management_System/PRD.md`). 아래 금액은 전부 제안이며, 확정 결정 8(플랜 정본)에도 admin-suite 항목이 없다. 크레딧 과금은 쓰지 않는다(AI 생성 기능 없음).

| 앱 | 코드 | 가격(월) | 월 크레딧 | 가입 크레딧 | 이월 | features | 비고 |
|---|---|---|---|---|---|---|---|
| erp | `default` | 0 | 0 | 0 | - | `max_members` 5, `storage_mb` 500, `export_xlsx` false, `sales_trend_days` 31 | 기본 플랜(계약형 출시) |
| erp | `standard` | 49,000원(제안) | 0 | 0 | - | `max_members` 50, `storage_mb` 10240, `export_xlsx` true, `sales_trend_days` 366 | Phase 2 Toss 구독 |
| sms | `default` | 0 | 0 | 0 | - | `max_students` 60, `max_classes` 3, `export_xlsx` false, `attendance_trend_days` 31 | |
| sms | `standard` | 39,000원(제안) | 0 | 0 | - | `max_students` 1500, `max_classes` 60, `export_xlsx` true, `attendance_trend_days` 366 | |
| hms | `contract` | 0(별도 계약) | 0 | 0 | - | `max_staff` 50, `phi_log_retention_days` 730, `export_xlsx` true | 온라인 결제 없음 |

크레딧 단가 표: 해당 없음(크레딧 차감 작업 없음). 크레딧팩: 해당 없음(모놀리스에서 SECTION 4 제거).

`core.plans.features` 키 해석(서버만 읽는다, `DB_CONVENTIONS.md` 11장)

| 키 | 타입 | 의미 | 키가 없을 때 | 판정 위치 |
|---|---|---|---|---|
| `max_members` | int | ERP 활성 직원 + 대기 초대 수 상한. -1 무제한 | 5 | `decide_join_request` 호출 전 Route Handler |
| `storage_mb` | int | 상품 이미지 총량 | 500 | 업로드 서명 URL 발급 전 |
| `export_xlsx` | bool | 엑셀 내보내기 | false | 내보내기 Route Handler |
| `sales_trend_days` | int | 판매 추이 조회 최대 일수 | 31 | `GET /api/erp/sales/trend` |
| `max_students`, `max_classes` | int | SMS 활성 학생/학급 상한 | 60 / 3 | 초대·학급 생성 Route Handler |
| `attendance_trend_days` | int | 출석 추이 최대 일수 | 31 | `GET /api/sms/attendance/trend` |
| `max_staff` | int | HMS 직원 수 상한 | 50 | 직원 초대 Route Handler |
| `phi_log_retention_days` | int | 접근 기록 보존(하한 730) | 730 | 프로비저닝 시 `workspaces.phi_log_retention_days`에 복사 |

seed 주의: 통합 DB `seed.sql`은 2026-10-13부터 모놀리스 seed와 같은 erp/sms 플랜 features를 담는다(`docs/products/_supabase-modular/VERIFICATION.md`). 조각은 `on conflict do nothing`이라 seed 값이 그대로 적용되며, 키가 없을 때의 기본값(위 표)은 대비용이다.

## 5. 비기능 요구사항

| 항목 | 값 | 근거 |
|---|---|---|
| 목록 첫 페이지 응답 | p95 500ms 이하(20행) | 제안 |
| RPC 쓰기 응답 | p95 300ms 이하 | 제안 |
| Realtime 반영 | 1초 이내(p95). HMS PRD 목표 0.2초는 측정 지표로 둔다 | `Hospital/PRD.md:77`, 제안 |
| 동시 판매 | 같은 상품 동시 50건에서 음수 재고 0건 | `docs/products/_supabase-modular/README.md:151` 패턴 |
| 업로드 | 상품 이미지 5MB, jpeg/png/webp | 제안 |
| 일괄 출석 | 1요청 200건 | 제안(학급 40명 x 5과목 여유) |
| 레이트 리밋 | 로그인/가입 IP당 10회/10분, `request_join` 사용자당 5회/시간, 환자 검색 사용자당 60회/분 | `SECURITY_BASELINE.md` 8장 + 제안 |
| 접근 기록 보존 | 730일 이상(hms) | 01장 6.2절 |
| 감사 로그 보존 | 2년(코어 제안) | `CORE_SPEC.md` 11장 |
| 가용성 | 업무 시간(08~20시 KST) 99.5% | 제안 |
| Lighthouse(SMS) | Performance 90 이상 | `School_Management_System/PRD.md:108` |
| 반응형 | 375/768/1024/1440px | `_design-guide/DESIGN_PRINCIPLES.md` 7단계 |
| 브라우저 | 최신 Chrome/Edge/Safari 2개 버전 | 제안 |

## 6. 법, 개인정보, 금지 문구

### 6.1 공통

| 항목 | 내용 |
|---|---|
| 개인정보(수집 항목) | ERP: 이름, 이메일, 전화, 부서, 직급. SMS: 이름, 이메일, 학번, 학급, 출석. HMS: 6.2절 |
| 목적 | 내부 업무 처리(재고·판매·인사 / 학사 출석 / 진료). 마케팅 이용 없음 |
| 보존 | 재직·재학·근무 기간 + 탈퇴 후 30일 유예 뒤 파기(제안). 업무 기록(입출고, 판매, 출석)은 회사·학교 기록으로 남고 행위자 id만 남는다 |
| 암호화 대상 컬럼 | ERP/SMS는 없음(전화는 업무 연락처). HMS는 6.2절 |
| 삭제 절차 | 사용자: core `remove_member` → 프로필 삭제는 운영자. 조직: soft delete → 30일 → 파기(코어 `purge_organization`는 크레딧 절과 함께 모놀리스에서 빠지므로 06장 6절 코어 요청) |
| 제3자 제공 | 없음. LLM/이미지 제공자 호출 없음. 차트 렌더도 자체(QuickChart 등 외부 렌더러 금지, `SECURITY_BASELINE.md` 10장) |
| 약관/고지 | 이용약관, 개인정보처리방침(고객사가 처리자, 플랫폼은 수탁자로 위탁 계약 명시, 제안), AI 생성 표시: 해당 없음(생성 기능 없음) |
| 제휴/광고 | 해당 없음(affiliate 모듈 미사용) |
| 플랫폼 약관 | 외부 플랫폼 자동화 없음 |

### 6.2 의료정보(HMS) 특례

| 항목 | 요구사항 | 근거/상태 |
|---|---|---|
| 데이터 격리 | 병원마다 단독 Supabase 프로젝트(모놀리스). 통합 DB에 hms 스키마 없음 | 확정 결정 2 |
| 수집 항목 | 차트번호, 이름, 성별, 생년월일, 연락처, 혈액형, 알레르기, CRM 태그, 진료기록, 처방, 검사값, 수납. 주민등록번호 수집 안 함 | 제안(고유식별정보 처리 회피) |
| 동의 | 환자 등록 시 개인정보 수집·이용 동의 시각 기록(`privacy_consent_at`), 없으면 등록 불가 | 제안 |
| 최소 권한 | staff: 진료 내용 접근 불가. lab_tech: 환자 연락처·진료기록 접근 불가, 검사 목록의 이름·차트번호만. admin(비의사): 진료 내용 불가, 통계와 접근 기록만 | `Hospital/PRD.md:13`, 05장 4절 |
| 접근 기록 | 민감 항목 조회·작성은 RPC로만, 같은 트랜잭션에서 `phi_access_log` 기록(행위자, 역할, 환자, 사유, 건수, 시각). 목록 화면은 `log_phi_access`로 화면 단위 기록 | 기획 공백 3(`analysis:1230`) |
| 접근 기록 보존·점검 | 730일 이상 보존, 관리자 월 1회 점검 화면 | "개인정보의 안전성 확보조치 기준" 접속기록 보관 조항은 미확인(법령 원문 확인 필요) |
| 진료기록 보존 | 진료기록은 append-only, 파기 대상 검토는 10년 기준(`retention_candidates`, 실제 삭제는 운영자 승인 후) | 의료법 시행규칙 보존 기간(진료기록부 10년 등)은 미확인 |
| 암호화 | 연락처, 메모, 진료기록 본문은 앱 계층 AES-256-GCM(`HMS_PHI_KEY_V<n>`, `key_version`). 키는 환경변수만, 없으면 기동 실패 | `SECURITY_BASELINE.md` 5장, 12장 |
| 전송 | TLS만. 의료 데이터 응답에 `Cache-Control: no-store` | 제안 |
| 공유 비밀번호 우회 | 금지(OVERRIDE 1234 폐기) | `docs/reviews/Hospital.md:81` |
| 규제 확인 | 의료기관 전자의무기록 관련 법정 요건(전자서명, 인증 등)은 미확인. MVP는 "행정/진료 보조 시스템"으로 고지하고 법정 EMR로 홍보하지 않는다 | 미확인, 01장 8절 |

### 6.3 미성년자(SMS) 특례

| 항목 | 요구사항 | 상태 |
|---|---|---|
| 법정대리인 동의 | 만 14세 미만 학생 계정은 학교가 법정대리인 동의를 받은 뒤 초대한다. 초대 화면에 확인 체크 필수 | 개인정보 보호법 제22조의2 취지, 세부 절차 미확인 |
| 노출 범위 | 학생은 본인 출석·본인 구성원 행만. 다른 학생 이름 목록 노출 없음 | 05장 4절 |
| 마케팅 | 학생 대상 광고·추적 스크립트 금지 | 제안 |

### 6.4 금지 문구

로그인 화면, 앱 내 안내, 영업 자료 모두에 적용한다.

| 금지 | 예 |
|---|---|
| 가상 후기·고객사 로고 | "OO병원이 선택한" 같은 미계약 고객 언급 |
| 허위 수치 | "업무 시간 70% 절감", 검증되지 않은 사용 기관 수 |
| 보장 표현 | "완벽한 보안", "해킹 100% 차단" |
| 의료 단정 | "진단 정확도 향상", 검사값 이탈 표시를 진단처럼 표현("빈혈입니다"). 표시는 "정상 범위 밖"까지만 |
| 법정 인증 오인 | 인증받지 않은 "EMR 인증", "의료법 완벽 준수" |
| 타사 상표 오용 | 원본 "NEXUS ERP", "MEDIC-CRM" 같은 이름의 상표 확인 전 사용 |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 권한 상승·교차 조직 노출 | 0건 | RLS 스모크 테스트(CI) + 감사 로그 이상 탐지 | 상시 |
| 재고 불일치 | 0건 | `products.quantity` = `inventory_moves` 합 비교 배치 | 주 1회 |
| ERP 가입 승인 소요 | 중앙값 24시간 이내 | `join_requests.decided_at - created_at` | 월 |
| HMS 접수→진료 시작 대기 | 측정만(기준선 수립) | `consult_started_at - checked_in_at` | 월 |
| HMS 접근 기록 누락 | 0건 | 민감 RPC 호출 수 = phi_access_log 행 수(로그 대조) | 주 |
| SMS 출석 체크 완료율 | 수업일 95% 이상 | `dashboard_stats.unchecked` = 0인 날 비율 | 월 |
| 공통 코드 편차 | admin-kit 밖 클라이언트/가드/날짜 코드 0 | 린트 규칙 | 상시 |

## 8. 열린 결정

| 항목 | 선택지 | 권고 |
|---|---|---|
| 모놀리스 스키마 | `public`(lite 기본) / 앱 이름 스키마 | `public`. 사용자 최종 확인 대기 |
| SMS 교사 역할 | A) PRD대로 admin/student 2역할 / B) teacher 추가(출석만) | B(제안). 교사에게 CRUD 권한을 주지 않기 위해 |
| ERP sales_manager 재고 권한 | A) 없음 / B) 출고만 / C) 입출고 전부 | B("제한적 접근", `ERP-Wesite/PRD.md:47`) |
| HMS admin의 진료기록 열람 | A) 허용 / B) doctor 역할 겸직 시만 | B(최소 권한) |
| 검사 승인 이중 확인 | A) 입력자 본인 승인 허용 / B) 다른 사람만 | B(제안) |
| 출시 과금 | A) 계약형(수동 엔타이틀먼트) / B) Toss 구독 즉시 | A로 출시, Phase 2 B |
| 의료·미성년자 법령 세부 | 접속기록 보관 기간, 진료기록 보존 기간, 법정대리인 동의 절차 | 법무 확인(미확인 항목) |
| School 작업 트리 삭제 | 의도/실수 | HEAD 복원(사용자 결정 A, `analysis:1243`). 삭제 의도는 원작성자 확인 필요(`analysis:1233`) |
| 브랜드 | 원본 이름(NEXUS ERP, MEDIC-CRM) 유지 여부 | 상표 확인 전 "Admin Suite ERP/Hospital/School" |
