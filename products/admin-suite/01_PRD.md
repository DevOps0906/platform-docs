# 01 PRD: Admin Suite

이 문서는 공유 코어 `packages/admin-kit`(KIT)와 앱 3개(ERP, HMS, SMS)를 절마다 나눠 적는다(확정 결정 2). 근거 표기에서 `analysis`는 `docs/products/00_MERGE_ANALYSIS.md`다.

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(사내 규정·매뉴얼 RAG, 기관 운영 위키, LangGraph `admin.assistant`, 채팅 업무 어시스턴트)과 업무 음성 질의를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 3D 히어로는 공개 랜딩이 없어 적용하지 않는다(03장 4절). **hms는 사용자 결정(2026-10-13)으로 전용 서버만 쓴다**: 상용 AI·음성 API 없음, 공용 GPU·음성 서버 없음, 공용 Dify 없음. 아래 hms 항목은 모두 이 결정을 전제로 한다.

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
| 3D 히어로 | 적용 제외 | 공개 랜딩이 없는 업무용 앱(`docs/products/_design-guide/HERO_3D.md:92`). 로그인 화면은 가볍게 유지(03장 4절) |
| KIT: AI 업무 어시스턴트(채팅 위젯, 권한 확인 → 문서 검색 → 출처 포함 답변 → compliance) | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| KIT: 사내 규정·매뉴얼 RAG 컬렉션(업로드, 색인, 역할별 공개 범위) | MVP | 확정 결정 13 |
| KIT: 기관 운영 위키(규정·매뉴얼을 정리한 기관별 위키, 검수·게시) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| KIT: AI 처리 방식 선택(erp, sms: 국외 이전 동의 / hms: 전용 서버 고정) | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| ERP, SMS: 업무 음성 질의(말하기 → STT → 어시스턴트 → 읽어 주기) | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`) |
| HMS: 임상 가이드라인·운영 매뉴얼 어시스턴트(환자 정보 제외, 전용 서버) | MVP | 확정 결정 13, 사용자 결정 2026-10-13 |
| HMS: 음성 질의(전용 `hms-voice` 서버) | MVP | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:48` |
| AI 사용량·한도 화면 | P1 | 제안 |
| SMS: 학생용 AI 어시스턴트 | Phase 2 | 제안: 미성년자 접근은 학교 승인과 법정대리인 동의 절차 확인 뒤(D-16) |
| HMS: 환자 데이터 요약·차트 보조 AI | Phase 3 이후 | 제안: 의료정보 AI 처리와 의료기기 해당 여부 법무 확인 필요(D-13) |
| HMS: 진료 음성 구술(받아쓰기) | Phase 2 | 제안: 진료 내용 음성은 `hms-voice` 전용 서버 + 접근 기록 설계 후(D-19) |
| 사내 업무 DB 질의(재고 수치, 출석 수치를 자연어로 조회) | Phase 2 | 제안: 읽기 전용 도구와 역할별 쿼리 허용 목록 설계 필요 |

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

### 3.6 AI 업무 어시스턴트, 위키, 음성 (2026-10-13)

공통 구현은 `packages/admin-kit/src/ai/`(앱 이름을 모른다)에 두고 앱이 설정 객체(앱 id, 역할 → 컬렉션 매핑, 라우팅 기능 키)를 주입한다(02장 2절). AI는 **읽기 전용**이다: 재고 변경, 판매 등록, 출석 기록, 진료기록 작성 같은 쓰기 도구를 어시스턴트에 주지 않는다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| KIT-F-015 | AI 업무 어시스턴트(채팅) | 신규 | 로그인 사용자 전용 채팅 위젯(오른쪽 시트). 질문 → 권한 확인 → 문서 검색 → 출처 포함 답변 → compliance(그래프 `admin.assistant`, 02장 5.2절). 스트리밍, 답변마다 출처, "AI가 생성한 답변" 표시, 메시지 1,000자, 대화당 50턴(제안). 답변은 사용자 역할이 볼 수 있는 컬렉션 안의 근거로만 만든다 | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다" 표시. 다른 사용자의 대화 id로 이어 쓰면 404. 역할이 볼 수 없는 컬렉션 문서가 근거에 포함된 답변 0건(회귀 테스트). 제공자 전부 실패 시 오류 표시(mock 응답 금지) | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:109-119` |
| KIT-F-016 | 규정·매뉴얼 RAG 컬렉션 | 신규 | 기관 관리자(erp master_admin, sms admin, hms admin)가 문서(md, txt, pdf, docx, 20MB 이하)를 올리면 서버가 `ai-docs` 버킷(service_role 전용)에 저장하고 색인한다. 컬렉션은 공개 범위(audience)별로 고정 3개 안팎(3.7절). 문서마다 올린 사람·검수일 메타데이터. 업로드 시 "개인정보를 포함하지 않았음" 확인 체크 필수. 문서 수 상한 `features.ai_docs_max`. 문서 제목·오류 메시지는 구성원 전원이 DB로 읽을 수 있으므로(3.7절 설명) 제목에 비밀 정보를 쓰지 않도록 업로드 화면에 안내 | 같은 내용(`content_hash`) 재업로드 409. 상한 초과 402. 색인 실패는 `failed` + 재시도 버튼. 다른 조직 컬렉션 지정 시 42501 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107` |
| KIT-F-017 | 기관 운영 위키 | 신규 | 색인된 규정·매뉴얼을 ingest가 `topic`, `concept`, `index` 페이지로 정리한다(기관·앱 단위, 기관 간 공유 없음). 새 페이지는 `draft`, 기관 관리자가 검수해 `published`로 바꾼다. 사람이 고친 블록은 에이전트가 덮어쓰지 않고, 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지 5개 상한. **코어 RLS가 `wiki_pages`를 같은 조직 구성원 전원에게 SELECT로 열어 두므로(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:623-633`) 역할별 공개 범위를 DB가 강제하지 못한다. 그래서 코어 개정(06장 R-14) 전까지 위키는 3.7절 "위키 대상" 컬렉션(구성원 전원에게 공개해도 되는 문서)에서만 만든다.** 주 1회 lint | draft 페이지는 관리자 외에 0명에게 노출. 출처(문서 id) 없는 페이지 게시 409. 버전 충돌 409. lint 결과(모순, 낡음, 고아, 깨진 링크, 출처 없음) 화면 표시 | `docs/products/_platform-core/LLM_WIKI.md:21-47` |
| KIT-F-018 | AI 처리 방식과 국외 이전 동의 | 신규 | erp, sms: 조직 owner가 온보딩에서 "상용 AI 사용(국외 이전 동의)" 또는 "국내 오픈소스만"을 고른다. 동의 시 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`, 설정에서 철회. 동의 전에는 모든 AI·음성 기능이 오픈소스 제공자만 쓴다. hms: 이 화면이 없다(상용 제공자는 DB에서 비활성, 전용 서버 고정) | 미동의 조직의 `ai_usage.provider`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. hms 조직의 `ai_usage.provider`는 `hms-*`뿐 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| KIT-F-019 | 업무 음성 질의(공통 UI) | 신규 | 채팅 위젯의 마이크 버튼(누르고 말하기, 최대 60초, 제안), 변환 텍스트 미리보기·수정 후 전송, 답변 "읽어 주기"(자동 재생 기본 꺼짐). 녹음 원본은 저장하지 않는다(`store_audio=false`). 첫 사용 전 음성 처리 고지 확인. 음성은 텍스트 입력의 대안이며 음성 없이 모든 기능을 쓸 수 있다 | 60초에서 녹음 자동 중지. `voice_jobs.store_audio=false` 100%. 마이크 권한을 거부해도 텍스트 채팅 정상. 고지 확인 없이 STT 호출 시 403 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`, `:106-110` |
| KIT-F-020 | AI 사용량·한도 | 신규(P1) | 관리자 화면: 기간별 질문 수, 음성 분 수, 제공자별 호출 수(원가 환산 크레딧 참고 표시), 오늘 한도 상태. 사용자 화면: 남은 오늘 질문 수 | 한도 도달 시 입력 비활성 + 안내. 표의 합계가 `ai_usage` 집계와 일치 | 제안 |
| ERP-F-015 | ERP 업무 어시스턴트 | 신규 | 사내 규정(구매·반품·재고 실사 규정, 휴가 규정)과 시스템 사용 매뉴얼을 근거로 답한다. 재고·판매 수치를 답하지 않는다(문서 기반만, DB 질의는 Phase 2). 컬렉션: `erp-rules-all`, `erp-rules-managers`, `erp-rules-admin` | staff가 `erp-rules-managers` 문서를 근거로 한 답변을 받지 못한다. "오늘 재고가 몇 개야" 같은 수치 질문은 "화면에서 확인하세요" 안내 | 제안 |
| ERP-F-016 | ERP 음성 업무 질의 | 신규 | KIT-F-019를 ERP에 적용. 창고·현장에서 손이 바쁠 때 규정 질문. 라우팅은 STT, TTS 모두 오픈소스 먼저(02장 5.1절) | 오픈소스 음성 서버 장애 시 동의한 조직만 ElevenLabs로 대체, 미동의면 실패 안내 | 제안 |
| HMS-F-015 | HMS 임상 가이드라인·운영 매뉴얼 어시스턴트 | 신규 | 병원이 올린 **환자 정보가 없는** 문서(진료 가이드라인, 감염관리 지침, 검사 절차, 원무 매뉴얼)만 근거로 답한다. 전용 서버(`hms-llm`, `hms-embed`)에서만 처리하고 공용 Dify를 쓰지 않는다. 환자 테이블(`patients`, `patient_private`, `medical_records`, `lab_tests`, `appointments`, `visit_charges`, `phi_access_log`)을 읽지 않는다. 입력에 환자 식별정보 패턴이 있으면 전송 전에 차단. 컬렉션: `hms-manuals-ops`, `hms-guidelines-clinical`, `hms-rules-admin` | 환자 테이블에 대한 AI 서비스 쿼리 0건(허용 목록 테스트). 주민등록번호·전화번호·차트번호 형식 입력 시 422 `AI_PHI_BLOCKED`. `ai_usage.provider`가 `hms-*`가 아닌 행 0 | 사용자 결정 2026-10-13, `docs/products/_platform-core/AI_ARCHITECTURE.md:70` |
| HMS-F-016 | HMS 음성 질의 | 신규 | KIT-F-019를 HMS에 적용하되 STT, TTS 모두 `hms-voice`(병원 전용 음성 서버)만 쓴다. 진료 관련 음성·텍스트는 공용 음성 서버와 ElevenLabs로 보내지 않는다. 진료 내용 구술(받아쓰기)은 이 기능 범위가 아니다 | 공용 음성 엔드포인트 환경변수가 설정돼 있으면 앱 기동 실패. 음성 서버 장애 시 다른 서버로 대체하지 않고 실패 안내 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:48` |
| HMS-F-017 | HMS 전용 AI 서버 고정과 격리 검사 | 신규 | hms 배포는 기동 시 AI 관련 환경변수를 검사한다: 공용 Dify(`DIFY_*`), 상용 키(`ANTHROPIC_API_KEY` 등), 공용 서버 URL(`OSS_LLM_BASE_URL` 등)이 하나라도 있으면 기동 실패. 라우팅은 DB(`force_open_source`, 제공자 `hms-*`)와 환경 두 곳에서 고정 | 금지 변수 주입 테스트 5종 전부 기동 실패. `resolve_ai_route`가 모든 기능에서 `hms-*`만 반환 | 사용자 결정 2026-10-13 |
| SMS-F-012 | SMS 학교 규정·매뉴얼 어시스턴트 | 신규 | 교직원(admin, teacher)이 학칙, 출결 처리 규정, 시스템 사용 매뉴얼을 근거로 질문한다. 학생 개인 정보와 출석 수치는 답하지 않는다. 컬렉션: `sms-rules-staff`, `sms-rules-admin`. 학생 접근은 MVP에서 제외(D-16) | student 역할이 `/api/ai/*`를 호출하면 403. teacher가 `sms-rules-admin` 문서를 근거로 한 답변을 받지 못한다 | 제안 |
| SMS-F-013 | SMS 음성 업무 질의 | 신규 | KIT-F-019를 SMS 교직원에게 적용. 교실에서 짧게 규정 질문 | 학생 계정에서 마이크 버튼 비노출, `/api/voice/*` 403 | 제안 |

### 3.7 AI 문서 공개 범위(audience)와 컬렉션

문서 단위 ACL은 만들지 않는다(D-15). 공개 범위마다 컬렉션 1개를 두고, 권한 확인 노드가 사용자의 앱 역할로 접근 가능한 컬렉션 목록을 정한다. 역할은 요청 본문이나 토큰이 아니라 DB(`erp.employees`, `sms.members`, hms `staff_profiles`, core `org_members`)에서 서버가 직접 확인한다(02장 5.3절).

| 앱 | 컬렉션(`ai_collections.name`) | 읽을 수 있는 역할 | 올릴 수 있는 역할 | 위키 대상 | 내용 예 |
|---|---|---|---|---|---|
| erp | `erp-rules-all` | master_admin, inventory_manager, sales_manager, staff | master_admin | 예 | 휴가·복무 규정, 시스템 사용 매뉴얼 |
| erp | `erp-rules-managers` | master_admin, inventory_manager, sales_manager | master_admin | 아니오 | 구매·반품·재고 실사 규정 |
| erp | `erp-rules-admin` | master_admin | master_admin | 아니오 | 인사·보안 내부 지침 |
| sms | `sms-guide-all` | admin, teacher(AI 질의). 학생은 위키 열람만(D-16 이전에는 AI 질의 불가) | admin | 예 | 학생에게 공개해도 되는 안내(시스템 사용법, 공통 일정 규칙) |
| sms | `sms-rules-staff` | admin, teacher | admin | 아니오 | 학칙 중 교직원용 부분, 출결 처리 규정 |
| sms | `sms-rules-admin` | admin | admin | 아니오 | 징계·인사 내부 지침 |
| hms | `hms-manuals-ops` | admin, doctor, staff, lab_tech | admin | 예 | 원무·접수 매뉴얼, 장비 사용법, 감염관리 지침 |
| hms | `hms-guidelines-clinical` | doctor, lab_tech | admin | 아니오 | 진료 가이드라인, 검사 절차·정상범위 해설(환자 정보 없음) |
| hms | `hms-rules-admin` | admin | admin | 아니오 | 병원 운영 내부 지침 |

"위키 대상 아니오" 컬렉션은 RAG 질의에만 쓰고 위키 페이지를 만들지 않는다. 이유: 코어 RLS가 `core.wiki_pages`, `core.ai_documents`, `core.ai_runs`, `core.ai_run_steps`를 같은 조직 구성원 전원에게 SELECT로 열어 두므로(사용자가 PostgREST로 직접 읽을 수 있음, `0008_core_ai.sql:623-633`) 위키 본문이 역할 범위를 우회한다. SMS는 학생도 조직 구성원이라 교직원용 위키는 학생에게 새는 문제가 있다. 6장 R-14(코어 정책 개정)이 반영되면 "위키 대상"을 전 컬렉션으로 넓힌다(D-20).

규칙: (1) 컬렉션의 임베딩 제공자는 erp, sms `oss-embed`, hms `hms-embed`로 고정하고 모델을 바꾸면 재색인한다. (2) 사람 이름·연락처 같은 개인정보가 들어간 문서는 올리지 않는다. 올린 뒤 `contains_pii`를 true로 표시하면 라우터가 오픈소스로만 처리한다(erp, sms). (3) 위키 페이지는 원본 문서와 같은 컬렉션 공개 범위를 이어받는다. (4) 사용자가 역할이 바뀌면 다음 요청부터 새 범위가 적용된다(캐시 금지).

## 4. 요금과 크레딧

정본 출처: 원본 3개 모두 요금 근거가 없다(`ERP-Wesite/PRD.md`, `Hospital/PRD.md`, `School_Management_System/PRD.md`). 아래 금액은 전부 제안이며, 확정 결정 8(플랜 정본)에도 admin-suite 항목이 없다. 크레딧 과금은 쓰지 않는다. 2026-10-13에 AI 기능이 들어왔지만 계약형 업무 앱이라 AI도 크레딧을 선차감하지 않고 플랜 포함 한도로 건다(4.1절, 열린 결정 D-10).

가격은 모두 **VAT 별도**다(고객이 사업자·기관인 B2B, 2026-10-14 결정, `Price_Plans/admin-suite/PRICE_PLAN.md` 10장 AS-P-1). 판매 플랜의 한도 값에는 -1(무제한)을 쓰지 않는다(AS-P-6, `Price_Plans/_common/PRICING_PRINCIPLES.md` 6장 무제한 금지). 키 해석의 -1은 내부 계약·운영용으로만 남긴다. 단계별 인상(erp 59,000원, sms 학생 단계 과금)·연간 결제·도입 셋업·AI 추가 팩은 Price_Plans 6장 단계 계획이며 이 표를 바꾸지 않는다.

| 앱 | 코드 | 가격(월, VAT 별도) | 월 크레딧 | 가입 크레딧 | 이월 | features | 비고 |
|---|---|---|---|---|---|---|---|
| erp | `default` | 0 | 0 | 0 | - | `max_members` 5, `storage_mb` 500, `export_xlsx` false, `sales_trend_days` 31 | 기본 플랜(계약형 출시) |
| erp | `standard` | 49,000원(제안) | 0 | 0 | - | `max_members` 50, `storage_mb` 10240, `export_xlsx` true, `sales_trend_days` 366 | Phase 2 Toss 구독 |
| sms | `default` | 0 | 0 | 0 | - | `max_students` 100, `max_classes` 5, `export_xlsx` false, `attendance_trend_days` 31 | 2026-10-14 60·3 → 100·5(AS-P-5, 경쟁사 무료 수준) |
| sms | `standard` | 39,000원(제안) | 0 | 0 | - | `max_students` 1500, `max_classes` 60, `export_xlsx` true, `attendance_trend_days` 366 | |
| hms | `contract` | 0(별도 계약) | 0 | 0 | - | `max_staff` 50, `phi_log_retention_days` 730, `export_xlsx` true | 온라인 결제 없음 |

크레딧 단가 표: 해당 없음(크레딧 차감 작업 없음, AI 포함. 4.1절은 원가 참고표). 크레딧팩: 해당 없음(모놀리스에서 SECTION 4 제거).

`core.plans.features` 키 해석(서버만 읽는다, `DB_CONVENTIONS.md` 11장)

| 키 | 타입 | 의미 | 키가 없을 때 | 판정 위치 |
|---|---|---|---|---|
| `max_members` | int | ERP 활성 직원 + 대기 초대 수 상한. -1 무제한(판매 플랜에는 쓰지 않음) | 5 | `decide_join_request` 호출 전 Route Handler |
| `storage_mb` | int | 상품 이미지 총량 | 500 | 업로드 서명 URL 발급 전 |
| `export_xlsx` | bool | 엑셀 내보내기 | false | 내보내기 Route Handler |
| `sales_trend_days` | int | 판매 추이 조회 최대 일수 | 31 | `GET /api/erp/sales/trend` |
| `max_students`, `max_classes` | int | SMS 활성 학생/학급 상한 | 100 / 5 | 초대·학급 생성 Route Handler |
| `attendance_trend_days` | int | 출석 추이 최대 일수 | 31 | `GET /api/sms/attendance/trend` |
| `max_staff` | int | HMS 직원 수 상한 | 50 | 직원 초대 Route Handler |
| `phi_log_retention_days` | int | 접근 기록 보존(하한 730) | 730 | 프로비저닝 시 `workspaces.phi_log_retention_days`에 복사 |

seed 주의: 통합 DB `seed.sql`은 2026-10-13부터 모놀리스 seed와 같은 erp/sms 플랜 features를 담는다(`docs/products/_supabase-modular/VERIFICATION.md`). 조각은 `on conflict do nothing`이라 seed 값이 그대로 적용되며, 키가 없을 때의 기본값(위 표)은 대비용이다. AI 키(아래 4.1절)는 조각 7절의 병합 UPDATE와 모놀리스 seed가 넣는다(통합 `seed.sql` 반영은 06장 6절 요청 R-12).

### 4.1 AI·음성 한도와 원가 참고 (2026-10-13)

크레딧을 선차감하지 않는다(D-10 A 확정, 2026-10-13 사용자 결정). `AI_ARCHITECTURE.md` 7장의 선차감·정산(`docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`)은 크레딧 모듈(모놀리스 SECTION 4)을 전제로 하는데 이 제품은 그 절을 제거했고(05장 8절), 계약형으로 파는 업무 앱에서 질문마다 과금하는 것은 맞지 않기 때문이다. 대신 아래 두 장치를 쓴다. 이 결정은 열린 결정 D-10이며, 뒤집으면 SECTION 4를 복원하고 04장 1절 AI 행을 선차감 방식으로 바꾼다.

| 장치 | 내용 | 판정 위치 |
|---|---|---|
| 플랜 포함 한도 | 아래 `features` 키. 사용자 하루 질문 한도 도달은 429 `AI_DAILY_LIMIT`, 조직 월 질문 한도 도달은 429 `AI_MONTHLY_LIMIT`, 조직 월 상용 경로 한도 도달은 오류 없이 오픈소스 경로로 처리(`force_open_source`와 같음), 기능 꺼짐은 403 `AI_DISABLED`, 문서 수 상한은 기존 플랜 한도처럼 402로 알린다 | AI 게이트(Route Handler) |
| 원가 기록 | 모든 호출을 `ai_usage`에 남기고 `credits` 컬럼에는 `ai_model_prices` 단가로 환산한 원가 크레딧을 기록한다. 차감은 하지 않는다(내부 원가 보고용, 제안) | FastAPI 라우터, 음성 어댑터 |

| 키 | 타입 | 의미 | 키가 없을 때 | 값(erp / sms default → standard, hms contract) |
|---|---|---|---|---|
| `ai_assistant` | bool | AI 어시스턴트와 위키 사용 허용 | true | true → true, hms true |
| `ai_turns_per_day` | int | 사용자당 하루 질문 수. -1 무제한(판매 플랜에는 쓰지 않음) | 30 | 30 → 200, hms 300 |
| `ai_turns_per_month` | int | 조직당 월 질문 수(구성원 합계, KST 달력 월). 2026-10-14 추가(AS-P-4) | 100 | 100 → 1500, hms 판정 안 함(전용 서버, 턴당 외부 원가 없음) |
| `ai_commercial_turns_per_month` | int | 조직당 월 상용 경로(Claude 등) 질문 수. 넘으면 그 달 남은 질문은 오픈소스 경로로만 처리. 2026-10-14 추가(AS-P-4) | 0 | 0 → 300, hms 해당 없음(상용 금지, 6.6절) |
| `ai_voice` | bool | 음성 질의 허용 | false | false → true, hms true |
| `ai_docs_max` | int | 조직당 색인 문서 수 상한 | 20 | 20 → 500, hms 1000 |
| `ai_wiki` | bool | 운영 위키 사용 허용(색인·ingest 비용이 있어 default 플랜 제외) | false | false → true, hms true |

원가 참고(`core.ai_model_prices` 기본 seed, 제안값. 상용 LLM 1k 입력 1, 출력 4 / 오픈소스 0.2, 0.5 / STT ElevenLabs 3·오픈소스 0.5 크레딧/분 / TTS ElevenLabs 5·오픈소스 1 크레딧/1천 자). hms 전용 제공자(`hms-*`)는 단가 행을 두지 않는다(병원 자체 장비라 원가 환산 불필요, 구현 시 확인).

| 작업 | 상용 경로 예 | 오픈소스 경로 예 | 비고 |
|---|---|---|---|
| 질문 1턴(입력 2천 토큰, 출력 500 토큰) | 약 4 | 약 0.65 | 근거 청크 8개 + 대화 이력 포함 추정 |
| 음성 질문 STT 30초 | 1.5 | 0.25 | 녹음 길이 기준 |
| 답변 읽어 주기 TTS 600자 | 3 | 0.6 | 글자 수 기준 |
| 문서 1건 색인(10쪽, 약 6천 토큰) | 임베딩 오픈소스 고정이라 약 0.06 | 같음 | `admin.knowledge`는 오픈소스 임베딩만(02장 5.1절) |
| 위키 ingest 문서 1건 | 약 6~10(오픈소스 먼저, 실패 시 상용 대체 시) | 약 2 | 문서 1건당 갱신 페이지 5개 상한 |

조직 월 한도 근거(2026-10-14, AS-P-4): 사용자당 하루 200턴 x 최대 50명은 상용 경로에서 standard 가격(VAT 별도)의 70% 매출총이익률을 지키지 못한다. 49,000원의 허용 원가 14,700원에서 인프라·결제 수수료 약 4,830원을 빼면 AI에 쓸 수 있는 원가는 월 지표 약 2,000이다. standard는 상용 300턴(약 1,200) + 오픈소스 1,200턴(약 780) = 약 1,980, default는 오픈소스 100턴(약 65)이다(`Price_Plans/admin-suite/PRICE_PLAN.md` 3장).

레이트 리밋(키 `<app>:<route>:<user_id>`, `core.rate_limit_hit`): 질문 사용자당 20회/60초, 하루 `ai_turns_per_day`, 조직 월 `ai_turns_per_month`(키 `<app>:ai-chat-month:<org>:<YYYYMM>`, 창 31일), 조직 월 상용 `ai_commercial_turns_per_month`(키 `<app>:ai-chat-commercial:<org>:<YYYYMM>`, 창 31일), STT 사용자당 10회/60초, 문서 업로드 조직당 20회/시간, 위키 ingest 조직당 5회/시간(제안).

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
| AI 채팅 첫 표시 | p95 3초 이하(스트리밍 첫 토큰). Dify HTTP 노드 경로(erp, sms)는 전체 답이 돌아온 뒤 표시되므로 p95 10초 이하이며 그동안 "근거를 찾는 중" 표시 | 제안: 04장 6.2절 |
| AI 답변 완료 | p95 15초 이하(출처 포함) | 제안 |
| STT(60초 발화) | p95 5초 이하(erp, sms 공용 GPU 서버 기준), hms는 병원 장비 사양에 따라 구현 시 측정 | 제안 |
| TTS 첫 오디오 | p95 2초 이하 | 제안 |
| 문서 색인 | 10쪽 문서 p95 60초 이하 | 제안 |
| AI 입력 상한 | 메시지 1,000자, 대화당 50턴, 음성 발화 60초·5MB, 문서 20MB | 제안 |
| AI 기록 보존 | `core.ai_messages`는 대화 삭제 또는 사용자 제거 후 30일, Dify 대화 로그(erp, sms) 30일 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |
| hms AI 격리 | 공용 서버·상용 API 호출 0건, 기동 시 금지 변수 검사 | 사용자 결정 2026-10-13 |

## 6. 법, 개인정보, 금지 문구

### 6.1 공통

| 항목 | 내용 |
|---|---|
| 개인정보(수집 항목) | ERP: 이름, 이메일, 전화, 부서, 직급. SMS: 이름, 이메일, 학번, 학급, 출석. HMS: 6.2절 |
| 목적 | 내부 업무 처리(재고·판매·인사 / 학사 출석 / 진료). 마케팅 이용 없음 |
| 보존 | 재직·재학·근무 기간 + 탈퇴 후 30일 유예 뒤 파기(제안). 업무 기록(입출고, 판매, 출석)은 회사·학교 기록으로 남고 행위자 id만 남는다 |
| 암호화 대상 컬럼 | ERP/SMS는 없음(전화는 업무 연락처). HMS는 6.2절 |
| 삭제 절차 | 사용자: core `remove_member` → 프로필 삭제는 운영자. 조직: soft delete → 30일 → 파기(코어 `purge_organization`는 크레딧 절과 함께 모놀리스에서 빠지므로 06장 6절 코어 요청) |
| 제3자 제공 | 이미지 제공자 호출 없음. 차트 렌더도 자체(QuickChart 등 외부 렌더러 금지, `SECURITY_BASELINE.md` 10장). AI·음성 제공자(erp, sms 한정)는 국외 이전에 동의한 조직의 요청에만 쓴다(6.5절). hms는 상용 AI·음성 제공자와 공용 AI 서버로 보내지 않는다(6.6절) |
| 약관/고지 | 이용약관, 개인정보처리방침(고객사가 처리자, 플랫폼은 수탁자로 위탁 계약 명시, 제안), AI 생성 표시: 어시스턴트 답변과 음성에 표시(6.5절) |
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
| AI 과장 (2026-10-13) | "AI가 업무를 대신합니다", "오류 없는 답변", "규정 위반 자동 차단", "진단을 보조하는 AI", "의료기기 인증 AI". 어시스턴트는 올려 둔 문서를 찾아 설명하는 도구이고 답변은 틀릴 수 있다고 안내한다 |
| AI 판단 대행 (2026-10-13) | 진단·처방·용량 지시, 개별 환자·학생에 대한 판단, 징계·인사 결정 권고, 법률 판단 확정. 생성 답변도 이 목록을 통과해야 한다(compliance 노드, 02장 5.2절) |

### 6.5 AI·음성 개인정보와 고지 (erp, sms 중심, 2026-10-13)

| 항목 | 내용 |
|---|---|
| 보내는 데이터 범위 | 질문(마스킹 후), 검색된 규정·매뉴얼 청크, 음성 질문 오디오(STT). 직원·학생·환자 개인정보 DB 행은 어떤 AI 제공자에도 보내지 않는다(어시스턴트가 업무 테이블을 읽지 않는다, KIT-F-015) |
| 문서 반입 | 업로드 화면에 "개인정보를 포함하지 않았음" 확인 필수. 서버가 주민등록번호·전화번호·이메일·계좌번호 형식을 탐지해 걸리면 업로드를 거절(erp, sms, 오탐은 관리자가 확인 후 재시도). 사람 이름이 많은 문서는 `contains_pii=true`로 표시해 오픈소스로만 처리 |
| 입력 마스킹 | 질문의 주민등록번호·전화번호·이메일·계좌번호 형식은 서버가 마스킹한 뒤 처리(제안). 입력란에 "개인정보를 적지 마세요" 안내 |
| 국외 이전(erp, sms) | 상용 AI·음성 제공자(LLM: Anthropic, OpenAI, Google, OpenRouter / 음성: ElevenLabs)는 국외 이전에 동의한 조직의 요청에만 쓴다. 조직 owner가 온보딩에서 고지문(제공자, 이전 국가, 항목, 목적, 보유 기간)을 보고 선택, 설정에서 철회. 증빙은 `core.ai_org_settings`(동의 여부, 고지문 버전, 동의자, 시각)이며 별도 동의 테이블을 만들지 않는다. 동의 방식(필수/선택)과 처리방침 공개만으로 가능한 범위는 개인정보 보호법 국외 이전 조항 기준으로 법무 확인(구현 시 확인, 미확인: 각 사업자의 리전 정책) |
| 처리 위탁 | 고객사가 개인정보처리자, 플랫폼은 수탁자(6.1절). AI 제공자와 오픈소스 서버·Dify의 위탁·보관 항목을 처리방침에 적는다(제안) |
| 녹음 | 녹음 원본은 저장하지 않는다(변환 후 폐기, `voice_jobs.store_audio=false`). 첫 마이크 사용 전 "녹음 목적, 원본 미저장, 처리 제공자(국외 여부)" 고지를 확인받고 서버가 `write_audit('ai.voice.notice_ack', 고지문 버전)`으로 증빙한다. 원본을 저장하지 않으므로 제3자 목소리 고지(`consent_kind=third_party_notice`)와 `voice-audio` 보관 동의는 받지 않는다(저장 기능 추가 시 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:94-95` 적용) |
| AI 생성 표시 | 답변마다 "AI가 생성한 답변", 읽어 주기 음성에 "AI가 생성한 음성입니다", 위키 페이지에 "AI가 정리하고 기관 관리자가 검수한 문서". 대체 모델로 답하면 "다른 AI 모델로 답했습니다" |
| 책임 안내 | 답변은 올려 둔 문서에 근거한 참고 정보이며 최종 판단과 책임은 사용자에게 있다. 근거 문서의 날짜(검수일)를 출처 칩에 표시 |
| Dify 로그 (erp, sms) | 대화 로그에 질문과 근거 문서 내용이 남으므로 조직 데이터 저장소로 관리한다(콘솔 계정 최소화, 2단계 인증, 보존 30일, `docs/products/_platform-core/AI_ARCHITECTURE.md:69`) |
| 삭제 | 대화 삭제 요청 시 `ai_messages`와 Dify 대화를 함께 삭제. 문서 삭제 시 청크, 그 문서에서 파생된 위키 페이지를 점검(`source_document_ids`, `core.purge_wiki_page`는 운영 도구) |

### 6.6 hms AI 특례: 전용 서버, 환자 정보 제외 (사용자 결정 2026-10-13)

| 항목 | 요구사항 | 근거/상태 |
|---|---|---|
| 서버 | LLM(`hms-llm`), 임베딩(`hms-embed`), 음성(`hms-voice`)은 hms 전용 서버. FastAPI 서비스도 hms 전용 배포. 상용 API 키, 공용 GPU·음성 서버, 공용 Dify 사용 금지 | `docs/products/_platform-core/AI_ARCHITECTURE.md:13`, `:70`, `VOICE_ARCHITECTURE.md:48`, 모놀리스 SECTION 11 |
| 경로 | 채팅은 Next.js → FastAPI 직접(`/tools/answer-direct`가 기본 경로). Dify 없음, 서명 토큰(EdDSA)만 사용 | `docs/products/_platform-core/AI_ARCHITECTURE.md:66` |
| 국외 이전 | 해당 없음(국외 제공자 비활성). 온보딩에 AI 처리 방식 선택 화면 없음 | KIT-F-018 |
| 반입 문서 | 환자 식별정보 없는 임상 가이드라인·운영 매뉴얼만. 업로드 시 "환자 정보를 포함하지 않았음" 확인 + 서버 탐지(주민등록번호, 전화번호, 차트번호 형식)로 거절. 환자 개별 사례·증례 문서 금지 | HMS-F-015 |
| 질문 입력 | 환자 식별정보 패턴이 있으면 전송 전에 차단(`AI_PHI_BLOCKED`). 마스킹 후 허용은 오탐·누락 위험이 커서 쓰지 않는다(D-14). 입력란에 "환자 이름, 차트번호, 연락처를 적지 마세요" 안내 | 제안 |
| 환자 DB 접근 | 어시스턴트는 환자·진료·검사·수납 테이블을 읽지 않는다. FastAPI의 DB 접근은 허용 목록(`ai_*`, `wiki_*`, `voice_*`, 역할 확인용 `staff_profiles`)으로 코드에서 제한하고 테스트로 고정(ADM-06-057). 그러므로 AI 호출은 `phi_access_log` 대상이 아니다. 접근 기록 설계가 필요한 환자 데이터 AI는 Phase 3(D-13) | 제안 |
| 임상 답변 규칙 | 진단 확정, 처방·용량 지시, 개별 환자 판단 금지. 모든 답변 상단에 "AI가 생성한 참고 답변이며 임상 판단을 대신하지 않습니다". 근거 문서의 검수일·작성자 표시. compliance 노드가 위반 문장을 걸러 1회 재작성, 2회 실패 시 "근거 문서를 직접 확인하세요" 안내 | 제안 |
| 의료기기 해당 여부 | 임상 의사결정 지원 소프트웨어는 의료기기로 분류될 수 있다. 이 기능은 문서 검색·요약 보조로 한정하고 환자별 판단·진단 기능을 넣지 않는다. 해당 여부와 광고 문구는 법무 확인(미확인) | 미확인 |
| 대화 기록 | `core.ai_messages`에 질문(차단·마스킹 통과분)과 답변을 저장. 보존 30일(제안). 병원 프로젝트 안에서만 보관 | 제안 |
| 음성 | 녹음 원본 미저장, 변환 텍스트도 병원 서버에서만 처리. 첫 사용 전 고지 확인(6.5절 녹음 항목과 같음) | HMS-F-016 |
| 보안 점검 | `HMS_PHI_KEY_*`는 AI 서비스(FastAPI)에 전달하지 않는다. AI 서비스는 암호화된 컬럼을 복호화할 수 없다 | 02장 8절 |

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
| AI 역할 범위 위반 | 0건 | 회귀 테스트(ADM-06-057) + `ai_messages.citations`의 컬렉션이 사용자 역할 허용 목록 밖인 행 수 | 상시 |
| hms 공용 제공자 호출 | 0건 | `ai_usage.provider`가 `hms-%`가 아닌 행 수, 네트워크 로그 | 상시 |
| AI 답변 출처 표시율 | 95% 이상(제안) | `ai_messages.citations`가 빈 배열이 아닌 assistant 메시지 비율(근거 없음 안내 제외) | 월 |
| AI 사용 확산 | 활성 직원의 30%가 월 1회 이상 질문(제안) | `ai_conversations` 사용자 수 / 활성 직원 수 | 3개월 |
| 문서 최신성 | 검수일이 1년 지난 색인 문서 비율 20% 이하(제안) | `ai_documents` 메타데이터 | 분기 |

## 8. 열린 결정

| ID | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-1 | 모놀리스 스키마 | `public`(lite 기본) / 앱 이름 스키마 | `public`. 사용자 최종 확인 대기 |
| D-2 | SMS 교사 역할 | A) PRD대로 admin/student 2역할 / B) teacher 추가(출석만) | B(제안). 교사에게 CRUD 권한을 주지 않기 위해 |
| D-3 | ERP sales_manager 재고 권한 | A) 없음 / B) 출고만 / C) 입출고 전부 | B("제한적 접근", `ERP-Wesite/PRD.md:47`) |
| D-4 | HMS admin의 진료기록 열람 | A) 허용 / B) doctor 역할 겸직 시만 | B(최소 권한) |
| D-5 | 검사 승인 이중 확인 | A) 입력자 본인 승인 허용 / B) 다른 사람만 | B(제안) |
| D-6 | 출시 과금 | A) 계약형(수동 엔타이틀먼트) / B) Toss 구독 즉시 | A로 출시, Phase 2 B |
| D-7 | 의료·미성년자 법령 세부 | 접속기록 보관 기간, 진료기록 보존 기간, 법정대리인 동의 절차 | 법무 확인(미확인 항목) |
| D-8 | School 작업 트리 삭제 | 의도/실수 | HEAD 복원(사용자 결정 A, `analysis:1243`). 삭제 의도는 원작성자 확인 필요(`analysis:1233`) |
| D-9 | 브랜드 | 원본 이름(NEXUS ERP, MEDIC-CRM) 유지 여부 | 상표 확인 전 "Admin Suite ERP/Hospital/School" |
| D-10 | AI 과금 방식 | A) 플랜 포함 한도(`features.ai_*`) + 원가 기록, 크레딧 미사용 / B) 모놀리스 SECTION 4 복원 + 조직별 월 AI 크레딧 선차감·정산(`AI_ARCHITECTURE.md` 7장 그대로) | **확정: A**(2026-10-13 사용자 결정). 계약형 업무 앱이고 질문 단위 과금은 도입 부담이 크다. B는 AI를 별도 상품으로 팔 때 다시 검토. 2026-10-14 조직 월 한도 키 2개 추가(4.1절, 결정됨(2026-10-14, Price_Plans 반영) AS-P-4) |
| D-11 | erp, sms 기본 라우팅 | A) `auto`(Claude 먼저), 국외 이전 동의가 없으면 오픈소스만 / B) 전 기능 `open_source` 고정(내부 문서 외부 전송 0) | A(02장 5.1절). 고객이 요구하면 조직 단위로 B(`force_open_source`) 적용 |
| D-12 | hms 전용 AI 서버 배치 단위 | A) 병원당 1세트(FastAPI + hms-llm + hms-embed + hms-voice) / B) hms 전용 공용 서버(병원 간 조직 격리는 서명 토큰으로) | A(제안). 비용이 크면 B를 법무 확인 뒤 허용(`02_ARCHITECTURE.md` 7절) |
| D-13 | hms AI 범위 | A) 가이드라인·운영 매뉴얼만(환자 정보 제외, MVP) / B) 환자 데이터 요약·차트 보조 | A. B는 Phase 3, 접근 기록 설계와 의료기기 해당 여부 확인 뒤 |
| D-14 | hms 질문 입력의 환자 식별정보 처리 | A) 탐지 시 전송 차단 / B) 마스킹 후 처리 | A(6.6절). 오탐은 사용자가 문구를 고쳐 재시도 |
| D-15 | 문서 공개 범위 구조 | A) 공개 범위별 컬렉션 고정(3.7절) / B) 문서별 허용 역할 지정(ACL) | A. B는 청크 메타데이터 필터와 권한 변경 시 재색인 설계가 필요해 Phase 2 |
| D-16 | SMS 학생의 AI 어시스턴트 접근 | A) MVP 제외, 교직원만 / B) 학생용 컬렉션 `sms-rules-all`로 허용 | A. 미성년자 접근은 학교 승인과 법정대리인 동의 절차 확인 뒤 Phase 2(6.3절) |
| D-17 | 위키 게시 승인 | A) 기관 관리자 검수 후 `published` / B) 자동 게시 | A. 자동 게시는 오류가 규정처럼 퍼진다 |
| D-18 | 채팅 위젯 레퍼런스 Astryx | 존재·라이선스 확인 뒤 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). ADM-06-041에서 결과 기록 |
| D-19 | hms 음성 모델과 진료 구술 | 한국어 의료 용어 STT 정확도, 전용 TTS 라이선스(코드·가중치 각각) 확인. 진료 구술은 Phase 2 | 구현 시 확인(`VOICE_ARCHITECTURE.md` 4.1절 후보). 구술은 접근 기록 설계 뒤 |
| D-20 | 위키 대상 컬렉션 범위 | A) 구성원 전원 공개 컬렉션만(3.7절, R-14 전) / B) 코어 RLS 개정(R-14) 뒤 전 컬렉션 | A로 출시, R-14 반영 뒤 B. 코어가 바뀌지 않으면 제한된 컬렉션의 위키는 만들지 않는다 |
