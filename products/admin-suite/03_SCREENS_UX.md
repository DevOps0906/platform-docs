# 03 화면과 UX: Admin Suite

## 1. 정보 구조와 화면 목록

플랜 접근 열: 세 앱 모두 기능 게이팅은 수량 한도(01장 4절)뿐이라 화면 단위 플랜 제한이 없다("전체"). Phase 2 엑셀 내보내기 버튼만 `export_xlsx`로 숨긴다.
화면 표의 `패턴` 열은 `docs/design-module/_design-guide/DASHBOARD_PATTERNS.md`(구조 A~O), `시각` 열은 `docs/design-module/_design-guide/DASHBOARD_VISUAL.md`(시각 V-A~V-N, 1장 분석 절차)를 따른다. 값은 제안이며 화면 착수 시 1장 7단계로 다시 확인한다(2026-10-16).


### 1.1 공통(admin-kit 제공, 앱마다 같은 경로)

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/login` | 로그인. 단계별(7절): A 개발용 로그인 패널(페르소나 버튼)만 + 상단 `MOCK AUTH · 로컬 전용` 배지, B erp·sms Google + 이메일 / hms 이메일만(D-21 전), C erp·sms 카카오·네이버 추가(P2 선택, hms 제외) | 고유 | - | 비로그인 | 전체 | P0 |
| `/signup` | 가입(ERP만 공개, HMS/SMS는 초대 링크 전용). Stage B부터 화면 구현(A에는 없음, Mock `join_requested` 페르소나로 대체). OAuth 가입은 `/login`의 같은 버튼 | 고유 | - | 비로그인 | 전체 | P0 |
| `/pending` | 승인 대기 안내 + 가입 코드 입력 + 요청 상태 | 고유 | - | 로그인(pending) | 전체 | P0 |
| `/invite/accept` | 초대 수락. A는 초대 대기 페르소나가 로그인한 상태에서 수락 버튼만, B에서 초대 메일 링크의 비밀번호 설정과 OAuth 첫 로그인 약관 동의(7.3절)를 더한다 | 고유 | - | 초대받은 본인 | 전체 | P0 |
| `/no-access` | 접근 권한 없음(워크스페이스 없음, 정지). Stage B부터 invite 앱(sms, hms)에서 초대와 다른 이메일로 OAuth 로그인한 경우 "초대받은 이메일로 로그인하세요" 안내(7.2절) | 고유 | - | 로그인 | 전체 | P0 |
| `/settings/account` | 계정(이름, 비밀번호, 로그아웃). Stage C 도입 시 erp·sms에 "로그인 방법" 구역 추가(7.4절, hms 없음) | H | - | 전원 | 전체 | P0 |
| `/settings/audit` | 감사 로그 | H + B | V-D(#26) | owner/admin | 전체 | P1 |
| `/settings/billing` | 플랜과 구독(erp, sms) | H | - | owner | 전체 | P2 |
| 채팅 패널(모든 앱 화면 오른쪽 시트), `/assistant` | AI 업무 어시스턴트(텍스트·음성), 대화 목록 | A의 AI 패널 + B(목록) | - | 로그인 + 허용 컬렉션이 1개 이상인 역할(SMS student 제외) | `features.ai_assistant`, 질문은 `ai_turns_per_day`(사용자 하루)·`ai_turns_per_month`(조직 월), 음성은 `ai_voice` | P0 |
| `/settings/ai` | AI 처리 방식(상용 AI 국외 이전 동의 / 국내 오픈소스만). **hms에는 없음** | H | - | owner | 전체 | P0 |
| `/settings/knowledge` | 규정·매뉴얼 문서 업로드, 색인 상태, 컬렉션 | H + B | - | 앱 관리자(erp master_admin, sms admin, hms admin) | `ai_docs_max` | P0 |
| `/wiki`, `/wiki/[...slug]` | 기관 운영 위키 목록·페이지(허용 컬렉션 범위만 표시) | B → G페이지 | - | 허용 컬렉션 역할 | `ai_wiki` | P0 |
| `/settings/wiki` | 위키 검수·게시, 변경 이력, 점검 결과 | H + B + J(편집기) | - | 앱 관리자 | `ai_wiki` | P0 |
| `/settings/ai-usage` | AI 사용량·한도 | H + L(사용량) | - | 앱 관리자 | 전체 | P1 |
| `/dev/components` | 컴포넌트 미리보기(라이트/다크, 디자인 시스템 3단계) | 고유 | - | 개발 환경만(프로덕션 빌드 제외) | - | P0 |

### 1.2 ERP

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/dashboard` | 대시보드(지표, 위험 재고, 최근 변동, 판매 추이) | C → B | V-B(#31) | 전원 | 전체(추이 기간은 `sales_trend_days`) | P0 |
| `/inventory` | 상품 목록 + 입출고/조정 | B + G시트 | V-D(#26) | master_admin, inventory_manager, sales_manager(조회+출고) | 전체 | P0 |
| `/inventory/[id]` | 상품 상세 + 이동 이력 | G | - | 위와 같음 | 전체 | P1 |
| `/sales` | 판매 목록, 등록, 완료, 취소 | B | V-D(#26) | master_admin, sales_manager | 전체 | P0 |
| `/hr` | 임직원 목록, 권한 변경 모달 | B | V-D(#26) | master_admin | 전체 | P0 |
| `/hr/requests` | 가입 요청 승인/거절, 가입 코드 | B | V-D(#26) | master_admin | `max_members` | P0 |
| `/hr/departments` | 부서 트리 | 고유(부서 트리) | - | master_admin | 전체 | P1 |
| `/me` | 내 정보(전화 수정) | H | - | 전원 | 전체 | P1 |
| `/settings` | 회사 설정 | H | - | master_admin | 전체 | P2 |

### 1.3 HMS

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/dashboard` | 관리자 대시보드 | C → B | - | admin | 전체 | P1 |
| `/queue` | 실시간 대기열 + 가용 토글 | D(의사별 열) | - | doctor, admin | 전체 | P0 |
| `/calendar` | 예약 캘린더(월/주/일) | E | - | staff, admin(조회+생성), doctor(조회) | 전체 | P0 |
| `/patients` | 환자 목록/검색/등록 | B → G페이지 | V-D(#26) | staff, doctor, admin | 전체 | P0 |
| `/patients/[id]` | 환자 상세(원무 정보) | G | - | staff, admin | 전체 | P0 |
| `/patients/[id]/chart` | 환자 360 차트(진료기록, 검사) | G(진료 타임라인) | - | doctor | 전체 | P0 |
| `/lab` | 검사 작업 목록 + 결과 입력/승인 | B + G시트(입력 패널) | V-D(#26) | lab_tech, doctor | 전체 | P0 |
| `/billing` | 수납 | B | V-D(#26) | staff, admin | 전체 | P1 |
| `/staff` | 직원 초대/역할/상태 | B | V-D(#26) | admin | `max_staff` | P0 |
| `/settings/access-log` | 의료정보 접근 기록 | B(접근 기록) | V-D(#26) | admin | 전체 | P0 |

### 1.4 SMS

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/admin/dashboard` | 출석 통계 + 학급별 출석률 + 실시간 피드 | B 변형(오늘 출결) + 숫자 1~2개 | - | admin, teacher | 전체 | P0 |
| `/admin/attendance` | 출석 체크 보드 | O(출석 그리드) | V-D(#26) | admin, teacher | 전체 | P0 |
| `/admin/classes` | 학급 CRUD | B | V-D(#26) | admin(쓰기), teacher(조회) | `max_classes` | P0 |
| `/admin/subjects` | 과목 CRUD | B | V-D(#26) | admin(쓰기), teacher(조회) | 전체 | P0 |
| `/admin/members` | 교사/학생 초대, 학급 배정, 역할·상태 | B + G시트 | V-D(#26) | admin | `max_students` | P0 |
| `/admin/trend` | 출석 추이 | L | - | admin, teacher | `attendance_trend_days` | P1 |
| `/student/dashboard` | 내 출석 요약 + 오늘 과목 + 실시간 알림 | 고유(내 출석 요약) | - | student | 전체 | P0 |

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

### 2.8 AI 질문 (erp, sms: Dify 경유 / hms: 직접 경로)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 아무 앱 화면 | 헤더의 "어시스턴트" 버튼 → 채팅 패널 열기 | `POST /api/ai/conversations` → `core.ai_conversations` 행(erp, sms는 `dify_user`=HMAC) | `ai_assistant` 꺼짐 403 `AI_DISABLED`, student 403 |
| 2 | 채팅 패널 | 질문 입력(1,000자) → 보내기 | 서버가 형식 마스킹(hms는 환자 식별정보면 차단) → 하루·조직 월 한도 확인 → erp, sms: Dify Chat API → HTTP 노드 `/tools/answer` / hms: FastAPI `/tools/answer-direct` | 한도 429 `AI_DAILY_LIMIT`/`AI_MONTHLY_LIMIT`, hms 환자 식별정보 422 `AI_PHI_BLOCKED` |
| 3 | 같은 화면 | 스트리밍 답변 읽기 | 그래프 `admin.assistant`: `permission`(DB 역할 확인, 허용 컬렉션 계산) → `retrieve` → `answer` → `compliance` | 허용 컬렉션 없음 403 `AI_NO_PERMISSION`, 근거 없음 "근거 자료를 찾지 못했습니다" |
| 4 | 같은 화면 | 출처 칩 열기 | 출처(문서 제목, 컬렉션, 검수일) 표시. 위키 페이지면 `/wiki/...` 링크 | - |
| 5 | 같은 화면 | 제공자 장애 | 체인 대체(해당 시 "다른 AI 모델로 답했습니다" 표시). hms는 대체 없음 | 전부 실패 503 `AI_UNAVAILABLE`, 오류 띠 |

### 2.9 문서 업로드 → 색인 → 위키 게시 (앱 관리자)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/settings/knowledge` | 컬렉션 선택(공개 범위), 파일 선택(md, txt, pdf, docx, 20MB), "개인정보(hms는 환자 정보)를 포함하지 않았음" 체크 | 서버가 형식·탐지 검사 → `ai-docs` 버킷 저장 → `core.ai_documents`(pending) → FastAPI `/rag/ingest`(서명 토큰) | 탐지 실패 422 `AI_DOC_PII_DETECTED`, 중복 409, 상한 402 |
| 2 | 같은 화면 | 색인 상태 확인 | pending → indexing → ready(청크 수 표시) | failed → 오류 메시지 + 재시도 |
| 3 | `/settings/wiki` | (ready 직후, "위키 대상" 컬렉션 문서만) 새 draft 페이지 검토, 문단 수정, 게시 | 위키 ingest가 draft 생성. 수정은 FastAPI 경유(`expected_version`, 사람 소유 표시). 게시 → `published` | 출처 없는 페이지 게시 불가, 버전 충돌 409 `WIKI_VERSION_CONFLICT` |
| 4 | `/settings/wiki` | 주간 점검 결과 확인 | lint 결과 표시(모순, 낡음, 고아, 깨진 링크, 출처 없음) | - |

### 2.10 음성 질의

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 채팅 패널 | 마이크 버튼을 처음 누름 | 음성 처리 고지 모달(목적, 원본 미저장, 처리 제공자: erp·sms는 국외 여부 / hms는 "병원 전용 서버") → 확인 시 `POST /api/voice/consent`(감사 기록) | 거부 → 텍스트 입력 유지 |
| 2 | 같은 화면 | 누르고 말하기(최대 60초, 경과 시간 막대) | MediaRecorder → `POST /api/voice/stt`(`store_audio=false`) → 변환 텍스트 | 마이크 권한 거부·미지원 브라우저 안내, STT 실패 "다시 말하기" |
| 3 | 같은 화면 | 변환 텍스트 확인·수정 → 보내기 | 2.8절 2~5단계(대화 `channel='voice'`) | hms는 변환 텍스트도 PHI 패턴 검사 |
| 4 | 같은 화면 | "읽어 주기"(자동 재생은 설정에서, 기본 꺼짐) | `POST /api/voice/tts {message_id}` → 오디오 스트림 | TTS 실패 → 텍스트 답변은 그대로 |

### 2.11 AI 처리 방식 선택 (erp, sms 온보딩, hms 없음)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 첫 로그인한 owner의 `/settings/ai`(첫 진입 시 안내 배너) | "상용 AI 사용(국외 이전 동의)" 또는 "국내 오픈소스만" 선택. 고지문(제공자, 이전 국가, 항목, 목적, 보유 기간) 펼쳐 보기 | `POST /api/ai/consent` → 동의 시 사용자 세션 `core.set_ai_cross_border_ack(org, true, 고지문 버전)` | 선택 없이 닫으면 미동의(오픈소스만) |
| 2 | 설정 | 언제든 철회 | `set_ai_cross_border_ack(org, false, ...)`. 다음 요청부터 상용 제공자 제외 | 고지문 버전 불일치 409 `CONSENT_VERSION_MISMATCH` |

hms 조직의 `/settings/ai` 경로는 존재하지 않고(404), 설정 화면 머리에 "AI는 병원 전용 서버에서만 처리됩니다" 안내 한 줄만 표시한다.

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

### 3.1 AI 업무 어시스턴트, 음성, 지식·위키 화면

공통 요소는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:106-110`(음성)와 `docs/products/_platform-core/LLM_WIKI.md:45`(위키)를 따른다. 컴포넌트는 `packages/admin-kit/src/ai/`에 두고 앱 3개가 같은 것을 쓴다.

| 화면 | 목적 | 구성 | 데이터 출처 | 행동 | 크레딧 표시 |
|---|---|---|---|---|---|
| 채팅 패널 | 규정·매뉴얼 질문 | 머리: 제목, 대화 새로 시작, 닫기. 본문: 메시지 스레드(스트리밍, 출처 칩, "AI가 생성한 답변", 대체 표시). 바닥: 마이크 버튼, 입력(1,000자, 개인정보 안내), 보내기, 오늘 남은 질문 수 | `core.ai_conversations`, `core.ai_messages`(RLS 본인), `POST /api/ai/chat`(SSE) | 보내기, 중지, 출처 열기, 읽어 주기, 새 대화 | 없음(크레딧 미사용). 남은 질문 수만 표시 |
| 대화 목록 `/assistant` | 지난 대화 | 대화 행: 제목, 마지막 시각, 삭제 | `core.ai_conversations` | 열기, 삭제 요청 | 없음 |
| 음성 입력 | 말로 묻기 | 누르고 말하기 버튼, 경과 시간 막대, 남은 시간, 변환 텍스트 미리보기·수정 | `POST /api/voice/stt` | 녹음, 취소, 수정 후 보내기 | 없음 |
| 음성 처리 고지 모달 | 녹음 전 고지 | 목적, 원본 미저장, 처리 제공자, 확인/취소 | `POST /api/voice/consent` | 확인, 취소 | 없음 |
| `/settings/knowledge` | 문서 관리 | 컬렉션 탭(공개 범위 이름과 읽을 수 있는 역할 표시), 문서 표(제목, 상태 pending/indexing/ready/failed, 청크 수, 검수일, 올린 사람), 업로드 대화상자(확인 체크 포함) | `core.ai_documents`, `core.ai_collections`, `/api/ai/knowledge/*` | 업로드, 재시도, 삭제(보관), 검수일 갱신 | 문서 수 / `ai_docs_max` |
| `/wiki` | 운영 위키 찾기 | 검색, 분류(컬렉션 범위), 페이지 행(제목, 요약 1줄, 검수 상태) | 서버가 `core.wiki_pages`를 읽되 사용자 허용 컬렉션 페이지만(service_role 서버 렌더, 사용자 입력은 slug 조회뿐) | 검색, 열기 | 없음 |
| `/wiki/[...slug]` | 규정 이해 | 제목, 요약, 본문, "출처"(문서), "관련"(위키 링크), "AI가 정리하고 기관 관리자가 검수한 문서", "이 내용으로 질문하기" | 같음 | 관련 이동, 채팅 시작 | 없음 |
| `/settings/wiki` | 검수·게시 | 페이지 표(draft/published/archived, 마지막 편집자 agent/user, 낡음 표시), 편집기, 변경 이력(`wiki_revisions`), 점검 결과 탭 | `core.wiki_pages`, `core.wiki_revisions`, `core.ai_runs`(wiki.lint) | 게시, 보관, 수정, 제안 반영 | 없음 |
| `/settings/ai-usage` | 사용량·한도 | 기간별 질문 수·음성 분, 제공자별 호출 수와 대체 발생, 오늘 한도 상태 | `core.ai_usage` 집계 RPC(구현 시 확인) | 기간 변경 | 원가 환산 크레딧을 "참고"로 표시 |
| `/settings/ai` (erp, sms) | AI 처리 방식 | 두 선택지 카드 대신 라디오 2개 + 고지문 펼침 + 현재 상태 | `core.ai_org_settings` | 동의, 철회 | 없음 |

채팅 패널 와이어프레임(PC 오른쪽 시트 400px, 375px에서는 전체 화면):

```
+------------------------------------------+
| 어시스턴트                  [새 대화] [x] |
+------------------------------------------+
| (AI) 반품은 수령 후 7일 안에 ...          |
|      출처 [구매·반품 규정 2025-03 검수]    |
|      AI가 생성한 답변                      |
| (나) 해외 거래처는 어떻게 하나요           |
+------------------------------------------+
| 개인정보는 적지 마세요                      |
| [마이크] [질문을 입력하세요        ] [보내기]|
| 오늘 남은 질문 27                          |
+------------------------------------------+
```

hms 채팅 패널은 같은 구성에 두 가지가 다르다: 머리에 "병원 전용 서버에서 처리됩니다. 환자 이름·차트번호·연락처를 적지 마세요" 고정 배너, 답변 상단에 "AI가 생성한 참고 답변이며 임상 판단을 대신하지 않습니다".

### 3.2 디자인 시스템

`docs/design-module/_design-guide/DESIGN_SYSTEM.md`를 따른다(9절 제품 문서 반영 규칙). 이 절은 admin-suite의 선택만 적는다.

| 항목 | 내용 | 근거 |
|---|---|---|
| 주 레퍼런스 | **Primer**(정보 밀도, 표·목록·상태 표시, 컴팩트/기본 두 밀도) + 보조 **Atlassian**(권한 표시, 상태 배지/로젠지, 모달·사이드바 중첩, 승인 흐름). AI 채팅·음성·위키 화면은 Astryx 패턴(존재·라이선스 미확인, D-18)을 참고하되 확인 실패 시 Primer + shadcn/ui 패턴. 랜딩은 없다 | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:51-61` |
| 가져올 것 | Primer: 컴팩트(행 32px)/기본(행 40px) 밀도, 숫자 열 정렬, 상태 라벨(아이콘 + 텍스트), 필터 바. Atlassian: 역할·상태 배지, 승인/대기/정지 흐름 표시, 권한 없는 항목은 숨김(자물쇠 노출 금지는 기존 규칙). Astryx(확인 후): 메시지 스레드 구조, 출처 칩 | 같은 곳 |
| 가져오지 않을 것 | 라이브러리 설치(`@primer/react`, Atlassian, Astryx 패키지), Primer 색·Octicons(Lucide 사용), StyleX, 마케팅 랜딩 패턴 | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:14`, `:61` |
| 스택 | Next.js 16.x, React 19.x, Tailwind CSS v4(4.x 고정), shadcn/ui(Tailwind v4 지원 버전, 구현 시 확인), lucide-react. `tailwind.config.js`와 v3 문법 금지 | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:63-73` |
| 토큰 파일(정답) | 앱별 `apps/<app>/src/theme/tokens.css`의 `@theme` 블록과 라이트/다크 변수 + 공통 기반 `packages/admin-kit/src/theme/base.css`(간격, radius, 밀도). 앱 토큰 값은 4.3절 토큰 플랜(ERP 코발트, HMS 야간 병동, SMS 칠판 인디고). 의미 기반 이름: `--color-surface`, `--color-surface-raised`, `--color-text`, `--color-text-muted`, `--color-border`, `--color-accent`, `--color-success`, `--color-warning`, `--color-danger`, `--radius-panel`(8px), `--radius-control`(6px), `--radius-badge`(999px), `--space-row-compact`(32px), `--space-row-default`(40px). 전환은 `data-theme` 하나 | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:26-37` |
| 라이트/다크 | 세 앱 모두 두 벌의 토큰을 둔다. 기본값: ERP, SMS 라이트(장부 회색/분필 회색 바탕), HMS 다크(야간 병동 바탕, 장시간 응시). 앱마다 기본 모드는 바뀌지 않고 사용자가 계정 설정에서 전환(제안) | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:70` |
| 컴포넌트(정답) | `packages/admin-kit/src/ui/`(shadcn/ui를 토큰으로 재스타일). 앱은 토큰만 바꿔 같은 컴포넌트를 쓴다. 컴포넌트 안 hex 금지(린트로 `bg-[#...]` 차단, ADM-06-039) | 같은 곳 |
| 문서 | `docs/file/03-설계/디자인/DESIGN.md`(1절 레퍼런스와 방향, 토큰 표), `COMPONENTS.md`(배리언트 표). 코드가 이긴다 | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:32` |
| 시각 확인 | 앱마다 `/dev/components` 라이트/다크 스크린샷(Storybook은 쓰지 않는다) | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:33` |
| 작업 순서 | `DESIGN_SYSTEM.md` 4장 1~4단계를 06장 W0~W1에 둔다: 1단계 ADM-06-041(W0), 2단계 ADM-06-042(W1), 3단계 사람 비주얼 검토 ADM-06-043, 4단계 ADM-06-044. 앱 화면 작업은 044 뒤 | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:39-49` |

기본 컴포넌트와 배리언트(수치는 제안, 3단계 사람 검토에서 확정):

| 컴포넌트 | 배리언트 | 크기 | 상태 |
|---|---|---|---|
| Button | primary, secondary, ghost, danger | sm 32 / md 36 / lg 40px | 기본, 호버, 포커스, 비활성, 로딩 |
| Input, Textarea, Select, Combobox | default, error | md 36px | 기본, 포커스, 비활성, 오류 |
| Checkbox, Radio, Switch | - | md | 기본, 포커스, 비활성 |
| DataTable | compact(행 32px), default(행 40px) | - | 빈 상태, 로딩 스켈레톤, 행 선택 |
| StatusBadge(로젠지) | 판매(pending, completed, canceled), 가입 요청(pending, approved, rejected), 예약·검사(HMS 상태 11종), 출석 4상태(SMS), AI 문서(pending, indexing, ready, failed), 위키(draft, published, archived) | sm | 아이콘 + 텍스트(색만으로 구분하지 않음) |
| RoleBadge | 앱별 역할(master_admin 등) | sm | - |
| Dialog, ConfirmDialog, Sheet(채팅 패널 400px, 모바일 전체 화면), Toast | - | - | 열림, 닫힘 |
| Tabs, Tooltip, Skeleton, EmptyState | - | - | - |

제품 고유 컴포넌트(기본 세트 뒤): AppShell, FormModal, KpiText(매출 1개 크게), AttendanceToggle(출석 4색), QueueTicket(대기번호), LabRangeBar(정상범위 막대), ChatPanel, MessageBubble, CitationChip, VoiceButton, KnowledgeTable, WikiArticle.

## 4. 메인페이지(랜딩) 디자인 방향

공개 마케팅 랜딩은 없다(`docs/design-module/_design-guide/REFERENCES.md:165`, `SKILLS.md:98`). 이 제품의 "메인페이지"는 각 앱의 로그인 화면과 로그인 직후 역할 홈이다. 절차는 `DESIGN_PRINCIPLES.md` 1~5단계를 따른다.

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

### 4.5 3D 히어로: 적용하지 않음 (2026-10-13)

2026-10-13 확정 결정 15(전 제품 메인페이지 히어로 3D)에 대해 admin-suite는 **적용 제외**다. 이유: 공개 마케팅 랜딩이 없는 내부 업무용 앱이고(`docs/design-module/_design-guide/REFERENCES.md:165`), `HERO_3D.md` 5장 표도 admin-suite를 "적용 제외(제안). 공개 랜딩이 없는 업무용 앱이라 로그인 화면만 가볍게"로 두었다(`docs/design-module/_design-guide/HERO_3D.md:92`). 따라서 이 장 4.1~4.4의 디자인 방향(토큰, 피할 인상, 안 B 로그인 화면)은 바뀌지 않았다.

| 항목 | 규칙 |
|---|---|
| 3D 소재·장면 | 없음. three.js, React Three Fiber, drei 의존성 0(02장 2절 린트 규칙). 3D 대체 정지 이미지, 기기별 3D 구성도 만들지 않는다 |
| 로그인 화면 | 4.3절 안 B(좌측 정렬 2열). 오른쪽 열은 앱 주제 그림 1개(ERP 입출고 전표, HMS 대기번호표, SMS 출석부 칸)를 인라인 SVG로, 로그인 폼은 HTML. 로드 시퀀스·스크롤 연동·자동 재생 모션 없음. `prefers-reduced-motion`에서 모션 0 |
| 성능(제안) | 로그인 LCP 2.5초 이하(`HERO_3D.md:38`과 같은 값을 채택), 3D 번들 0 |
| 접근성 | 장식 SVG `aria-hidden`, 폼 필드 레이블과 키보드 순서 보장 |
| 재검토 조건 | 공개 마케팅 랜딩이 생기면 그 랜딩에만 `HERO_3D.md` 표준을 적용한다(앱 화면에는 적용하지 않는다) |

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
| compliance WARN/FAIL | 제품 도메인 compliance는 해당 없음. AI 답변은 그래프 compliance 노드가 걸러 재작성하고, 끝내 걸리면 "근거 문서를 직접 확인하세요" 안내로 대체 |
| 잡 진행률 | 해당 없음(문서 색인 상태만 `/settings/knowledge`에 표시) |
| AI 답변 생성 중 | 스트리밍 + 중지 버튼. erp, sms는 Dify 경로라 전체 답이 오기 전 "근거를 찾는 중" 표시 |
| 대체 모델로 답함 (erp, sms) | 답변 아래 작은 표시 "다른 AI 모델로 답했습니다" |
| AI 실패(모든 제공자) | 오류 띠 "지금은 답변을 만들 수 없습니다. 잠시 뒤 다시 시도하세요"(hms는 "병원 전용 AI 서버에 연결할 수 없습니다. 관리자에게 알려 주세요"). 다른 서버로 대체하지 않았음을 hms에서만 명시 |
| 근거 없음 | 안내 + 위키 검색 링크 "근거 자료를 찾지 못했습니다" |
| 권한 없는 문서 | 답변에서 권한 밖 문서의 존재를 암시하지 않는다. 허용 범위 안에 근거가 없으면 위 "근거 없음"과 같은 문구 |
| 환자 식별정보 감지 (hms) | 입력란 아래 경고 "환자 정보가 포함된 것 같습니다. 이름·차트번호·연락처를 빼고 다시 입력하세요". 전송 차단 |
| 하루 질문 한도 | 입력 비활성 "오늘 질문 30개를 모두 썼습니다. 내일 다시 이용하세요"(숫자는 플랜 값) |
| 마이크 권한 거부 | 마이크 버튼 비활성 + 안내 "마이크 권한이 꺼져 있습니다. 텍스트로 물어보세요" |
| 음성 미지원 브라우저·`ai_voice` 꺼짐 | 마이크 버튼 숨김 |
| 음성 변환 실패 | "말씀을 알아듣지 못했습니다. 다시 말하거나 입력해 주세요" |
| 국외 이전 미동의(erp, sms) | 채팅 패널 상단 한 줄 "국내 오픈소스 AI로 답하고 있습니다. 설정에서 바꿀 수 있습니다"(owner에게만 링크) |
| 문서 반입 거절 | "개인정보로 보이는 내용이 있어 올릴 수 없습니다. 해당 부분을 지우고 다시 올려 주세요"(hms: 환자 정보) |
| 위키 페이지 없음 | 404 + 검색 "아직 정리되지 않은 내용입니다" |

## 6. 접근성과 반응형

| 항목 | 기준 |
|---|---|
| 키보드 | 표 행 이동(위/아래), 출석 그리드 숫자키 1~4로 상태 선택(제안), 모든 버튼 `:focus-visible` |
| 대비 | 본문 4.5:1 이상. HMS 다크에서 #E2E8F0/#0F172A 확인. 상태는 색 + 아이콘 + 텍스트 |
| 폭 | 1024px 미만 햄버거 사이드바, 375px에서 표는 가로 스크롤 컨테이너(페이지 전체 가로 스크롤 없음). 출석 보드는 768px 태블릿 우선 |
| 모션 | `prefers-reduced-motion` 시 대기열 깜빡임(Live 배지) 정지 |
| 채팅 | 메시지 목록 `aria-live="polite"`(스트리밍은 완료 때 한 번 읽음), 출처 칩 키보드 접근, 375px에서 전체 화면 시트 |
| 음성 | 음성은 텍스트 입력의 대안이며 모든 기능은 음성 없이 쓸 수 있다. 녹음 중 상태를 텍스트로도 표시. 읽어 주기는 스페이스(재생/정지) |

## 7. 인증 단계별 화면 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.1절(Mock 화면), 3.2절(콜백), 5.2절(B 화면), 7.3절(로그인 방법)이다. 로그인 화면의 레이아웃(4.3절 안 B, 좌측 정렬 2열)은 단계와 무관하게 같고 왼쪽 열의 로그인 수단만 바뀐다.

### 7.1 로그인 화면 단계별 구성

| 단계 | erp | sms | hms | 공통 |
|---|---|---|---|---|
| A | "개발용 로그인" 패널: 공통 페르소나 + erp 페르소나 버튼(05장 10절), 현재 로그인 페르소나, 로그아웃 | 같은 패널(sms 페르소나) | 같은 패널(hms 페르소나) | 모든 화면 상단 고정 배지 `MOCK AUTH · 로컬 전용`. 실제 제공자 버튼·이메일 폼을 렌더하지 않는다. Mock 허용 판정이 거짓이면 패널 코드 자체를 렌더하지 않는다(서버 컴포넌트) |
| B | "Google로 계속" + 이메일·비밀번호 폼 + "가입 코드가 있나요? 가입"(4.3절 와이어프레임 그대로) + 비밀번호 재설정 링크 | "Google로 계속" + 이메일·비밀번호 폼(가입 링크 없음, "초대 메일을 받으셨나요?" 안내) | 이메일·비밀번호 폼만(가입 링크 없음). Google 버튼은 D-21 확정 전 없음 | 개발용 패널·배지 없음. 4.3절 와이어프레임의 `[Google로 계속]`은 B단계 erp·sms 표시다 |
| C | B + 카카오·네이버 버튼(D-24 도입 시) | 같음 | 변화 없음(제외) | 카카오 버튼은 카카오 디자인 가이드 색·문구(미확인), 네이버는 검수 통과 전 운영에 노출하지 않는다 |

### 7.2 콜백과 오류 상태

`/auth/callback`은 화면이 아니라 라우트다(04장 8.2절). 사용자에게 보이는 결과만 적는다.

| 상황 | 이동 | 표시 문구(제안) |
|---|---|---|
| `error=callback`(코드 없음·재사용·만료) | `/login?error=callback` | "로그인을 완료하지 못했습니다. 다시 시도해 주세요" |
| `error=state`(C2 브리지만) | `/login?error=state` | "로그인 요청이 만료되었습니다. 다시 시도해 주세요" |
| `error=email_in_use`(C2 브리지만) | `/login?error=email_in_use` | "이미 다른 방법으로 가입한 이메일입니다. 그 방법으로 로그인한 뒤 설정에서 네이버를 연결하세요" |
| `error=no_profile` | 로그아웃 후 `/login?error=no_profile` | "계정 정보를 찾을 수 없습니다. 관리자에게 문의하세요"(02장 6절) |
| erp OAuth 첫 로그인(기관 소속 없음) | `/pending` | 2.2절 1단계를 건너뛰고 2단계(가입 코드 입력)부터. 약관 동의(7.3절)가 먼저 |
| sms·hms 초대와 같은 이메일로 첫 로그인 | `/invite/accept` | 2.3절 2단계 |
| sms·hms 초대와 다른 이메일로 OAuth 로그인 | `/no-access` | "이 계정으로 받은 초대가 없습니다. 초대받은 이메일로 로그인하세요" + 로그아웃 버튼 |
| suspended | 403 | "정지된 계정입니다. 관리자에게 문의하세요" |

### 7.3 첫 OAuth 로그인 뒤 약관 동의 위치

OAuth 가입은 가입 폼을 거치지 않으므로 이 제품의 온보딩 첫 단계에서 이용약관·개인정보처리방침 동의를 받는다(`AUTH_ROADMAP.md` 5.2절). 별도 `/onboarding/terms` 경로를 만들지 않는다.

| 앱 | 위치 | 이유 |
|---|---|---|
| erp | `/pending` 첫 단계(가입 코드 입력 전). 이메일 가입자는 `/signup` 폼에서 이미 동의했으므로 건너뛴다 | erp 온보딩은 `/pending`에서 시작한다(2.2절) |
| sms, hms | `/invite/accept` 수락 버튼 위 체크 2개 | 초대제의 첫 화면이 수락 화면이다(2.3절). SMS 14세 미만 학생의 법정대리인 동의는 초대 단계(학교)가 받는다(01장 6.3절) |

### 7.4 설정 → 로그인 방법 (Stage C, erp·sms만)

`/settings/account` 안의 구역. 연결된 제공자 목록, 연결(`linkIdentity`), 해제(남는 로그인 수단이 1개 이상일 때만), 감사 `auth.identity_link`·`auth.identity_unlink`(`AUTH_ROADMAP.md` 7.3절). D-24가 "도입하지 않음"이면 만들지 않는다. hms는 Stage C 제외라 이 구역이 없다.

## 8. 대시보드 셸과 좌측 GNB (2026-10-19 추가, 원본 프로젝트 메뉴 이행)

이 장은 admin-suite 앱 3개(erp, hms, sms)의 공통 셸(헤더 + 좌측 GNB)과 홈 구성을 정한다. 목적은 원본 프로젝트의 메뉴와 기능이 모두 새 구조 어딘가로 이행되게 하는 것이다: ERP-Wesite 화면 5개(대시보드/재고/판매/인사/설정, `docs/reviews/ERP-Wesite.md:23`, 사이드바 링크 라우트 `:51`), Hospital 핵심 기능 7개(`docs/reviews/Hospital.md:19-25`, 화면 경로 `:39-43`), School_Management_System 사이드바 4개 메뉴와 HEAD에만 남은 관리자·학생 화면(`docs/reviews/School_Management_System.md:17`, `:37`, `:39`), basic-master-module의 기본 AppShell 제안(`docs/reviews/basic-master-module.md:103`). 1절 화면 표의 경로·역할·플랜·우선순위는 그대로이고, 이 장은 메뉴 순서·묶음·셸 동작과 새 경로 1개(sms `/admin/settings`)만 더한다. 셸 컴포넌트는 admin-kit AppShell(KIT-F-008, 01장 3.1절) 하나이고 앱은 메뉴 배열과 토큰만 바꾼다. 다른 제품과 `_design-guide` 공용 패턴은 바꾸지 않는다(admin-suite 전용).

세 앱은 따로 배포되는 별개 앱이다(확정 결정 2, README 2절). 그래서 한 앱 안에 다른 앱으로 가는 전환 메뉴를 두지 않는다. 메뉴 묶음은 앱마다 다르고, 공통 화면(1.1절 `/assistant`, `/wiki`, `/settings/*`)만 세 앱이 같은 이름·같은 경로로 쓴다.

디자인 시안: Design 캔버스 "Admin Suite 대시보드 · GNB 초안". 시안 기본은 ERP 앱, master_admin 역할, standard 플랜 화면이다. 캔버스의 앱 전환(ERP · HMS · SMS · SMS 학생)은 메뉴 묶음을 비교하기 위한 시안 보기 전용이며 실제 앱 헤더에는 없다. 시안의 토큰은 ERP 라이트(4.3절)이고 HMS 야간 병동 다크, SMS 칠판 인디고는 8.6절 표에 적는다. 시안의 수치·이름·데이터는 모두 [예시]다.

### 8.1 결정 상태

| 항목 | 상태 | 이 장의 기본값 |
|---|---|---|
| 앱 전환 메뉴 | 확정(확정 결정 2, 앱 3개 별도 배포. hms는 별도 DB) | 헤더·GNB에 다른 앱 링크를 두지 않는다. 시안 캔버스의 전환은 보기 전용 |
| 역할 밖 메뉴 | 확정(KIT-F-003 "매트릭스 밖 메뉴는 렌더되지 않는다(자물쇠 노출 금지)", 01장 3.1절, 이 장 5절 "권한 없음") | 렌더하지 않는다. 직접 URL은 서버 403(5절) |
| 플랜 기능이 꺼진 메뉴(`ai_wiki`, `ai_assistant`) | 미정(01장 D-25) | 숨긴다(역할 밖 메뉴와 같은 방식) |
| hms 역할 홈과 MVP 동안 admin 홈 | 미정(01장 D-26) | doctor `/queue`, staff `/calendar`, lab_tech `/lab`, admin은 `/dashboard`(P1) 전까지 `/queue`(제안) |
| sms 학교 설정 화면 | 미정(01장 D-27) | 새 경로 `/admin/settings`를 둔다(8.4절) |
| 헤더 메뉴 검색 | 미정(01장 D-28) | 메뉴 이름만 찾는 검색을 둔다(제안). 업무 데이터 검색은 하지 않는다 |
| 앱 표시 이름 | 미정(01장 D-9) | "Admin Suite ERP", "Admin Suite Hospital", "Admin Suite School"(상표 확인 전) |

### 8.2 헤더

| 위치 | 요소 | 규칙 |
|---|---|---|
| 맨 위(Stage A만) | 고정 배지 `MOCK AUTH · 로컬 전용` | 7.1절 그대로. 배포 환경에서는 렌더하지 않는다 |
| 왼쪽 | 햄버거(1024px 미만만, 6절), GNB 접기/펼치기(제안), 앱 이름 "Admin Suite ERP"(D-9) | 접기 상태는 사용자별로 기억(localStorage, 실패해도 기본 펼침). 역할·플랜은 localStorage에 쓰지 않는다(CLAUDE.md 인증 단계 규칙) |
| 가운데 | 검색 버튼 "메뉴 검색 ⌘K"(제안, D-28) | 지금 역할에 보이는 메뉴 이름과 8.7절 원본 이름(예: "인사" → 임직원)만 찾는다. 상품·환자·학생 같은 업무 데이터를 찾지 않는다. hms 환자 검색은 접근 기록 대상이라(HMS-F-003) `/patients` 화면 안에서만 한다. 원본 ERP 헤더 검색은 동작 없는 장식이었다(`docs/reviews/ERP-Wesite.md:80`) |
| 오른쪽 | + 새로 만들기 ▼(제안) | 역할이 할 수 있는 등록만. erp: 판매 등록, 입출고 기록, 상품 등록. hms: 예약 만들기, 환자 등록. sms: 출석 체크, 구성원 초대. 각 항목은 해당 화면이나 그 화면의 기존 모달·시트를 연다(새 화면 없음). 원본 ERP 헤더 액션 버튼은 어느 페이지도 연결하지 않은 무동작이었다(`docs/reviews/ERP-Wesite.md:80`) |
| 오른쪽 | 어시스턴트 버튼 | 2.8절 1단계, 3.1절 채팅 패널(오른쪽 시트 400px). `ai_assistant`가 꺼졌거나 sms student면 버튼을 숨긴다(1.1절 채팅 패널 행) |
| 오른쪽 | 계정 메뉴: 이름 + 역할 배지(RoleBadge, 3.2절), 플랜 이름(owner에게만, 제안), 로그아웃 | 로그아웃은 AppShell에 둔다(01장 3.5절). 원본 School은 로그아웃이 작업 트리 어디에도 없었다(`docs/reviews/School_Management_System.md:53`) |
| 헤더 아래 띠 | Realtime 연결 끊김 "실시간 연결이 끊겼습니다. 다시 연결 중" + 마지막 갱신 시각 | 5절 그대로 |
| 두지 않는 것 | 알림 벨, 크레딧 잔액 | 원본 ERP 알림 벨은 장식뿐이었고(`docs/reviews/ERP-Wesite.md:80`) 이식 대상에서 버렸다(README 3절 "헤더 장식"). 크레딧은 이 제품에 없다(CLAUDE.md 2절) |

### 8.3 GNB 메뉴 순서

모든 표는 그 앱에서 가장 넓은 역할(erp master_admin, hms admin, sms admin) 기준이다. 다른 역할은 01장 역할 매트릭스(3.2절 ERP 표, 1.3·1.4절 역할 접근 열)에 있는 메뉴만 보고, 묶음 안 메뉴가 0개면 묶음 제목도 숨긴다. 우선순위 배지(P1, P2, Phase 2)는 시안과 문서 표시용이며, 코드에서는 경로가 생긴 메뉴만 배열에 넣는다(사이드바 링크 404 0, 06장 ADM-06-035).

#### 8.3.1 ERP (시안 기본)

| 묶음 | 메뉴 | 경로(1절) | 탭·하위 | 배지 | 원본 |
|---|---|---|---|---|---|
| (맨 위) | 홈 | `/dashboard` | 8.5절 | - | ERP-Wesite 대시보드 |
| 재고·판매 | 재고 | `/inventory` | 카테고리 필터 · 상품 상세 `/inventory/[id]`(P1) · 입출고/조정 시트 | 부족 SKU 수 | ERP-Wesite 재고 |
| 재고·판매 | 판매 | `/sales` | 상태 탭(전체/대기/완료/취소) · 등록 모달 | - | ERP-Wesite 판매 |
| 인사 | 임직원 | `/hr` | 권한 변경 모달 | - | ERP-Wesite 인사, 권한 수정 모달 |
| 인사 | 가입 요청 | `/hr/requests` | 가입 코드 조회·재발급 | 대기 수 | ERP PRD Pending 승인 |
| 인사 | 부서 | `/hr/departments` | 부서 트리 | P1 | ERP-Wesite 부서(조회만) |
| 인사 | 내 정보 | `/me` | 전화 수정 | P1 | ERP PRD 임직원 정보 |
| 지식 | 어시스턴트 대화 | `/assistant` | 대화 목록(채팅은 헤더 버튼) | - | 확정 결정 13 |
| 지식 | 운영 위키 | `/wiki`, `/wiki/[...slug]` | 검색 · 분류 | - | 확정 결정 13 |
| AI·지식 관리 | 문서 관리 | `/settings/knowledge` | 컬렉션 탭 · 업로드 | 색인 실패 수 | 확정 결정 13 |
| AI·지식 관리 | 위키 검수 | `/settings/wiki` | 페이지 · 변경 이력 · 점검 결과 | - | 확정 결정 13 |
| AI·지식 관리 | AI 사용량 | `/settings/ai-usage` | 기간 변경 | P1 | KIT-F-020 |
| AI·지식 관리 | AI 처리 방식 | `/settings/ai` | 국외 이전 동의·철회 | - | 확정 결정 17 |
| 관리 | 회사 설정 | `/settings` | 회사명 · 기본 안전재고 · 재고 부족 알림 | P2 | ERP-Wesite 설정 |
| 관리 | 감사 로그 | `/settings/audit` | 기간 · 행위자 · action 필터 | P1 | ERP-Wesite 시스템 로그 |
| 관리 | 플랜과 구독 | `/settings/billing` | - | Phase 2 | 없음(01장 2절 Toss 구독) |
| (아래 고정) | 계정 | `/settings/account` | 이름 · 비밀번호 · 로그인 방법(Stage C, 7.4절) | - | KIT-F-013 |

ERP 역할별로 보이는 메뉴(01장 3.2절 매트릭스): inventory_manager 홈·재고·지식, sales_manager 홈·재고(조회+출고)·판매·지식, staff 홈·내 정보·지식(`erp-rules-all`만). AI·지식 관리와 관리 묶음은 master_admin만 본다(문서 관리·위키 검수는 1.1절 "앱 관리자", AI 처리 방식·플랜은 owner).

#### 8.3.2 HMS

| 묶음 | 메뉴 | 경로(1절) | 탭·하위 | 배지 | 원본 |
|---|---|---|---|---|---|
| (맨 위) | 관리자 대시보드 | `/dashboard` | 8.5절 | P1 | Hospital 관리자 대시보드 |
| 접수·진료 | 예약 캘린더 | `/calendar` | 월 · 주 · 일, 의사 필터 | - | Hospital 예약 캘린더 |
| 접수·진료 | 대기열 | `/queue` | 의사별 열 · 가용 토글 | 대기 수 | Hospital 실시간 대기열 |
| 접수·진료 | 환자 | `/patients` | 환자 상세 `/patients/[id]` · 환자 360 차트 `/patients/[id]/chart`(doctor) | - | Hospital 환자 목록·상세 |
| 접수·진료 | 검사 | `/lab` | 상태 필터 · 입력 패널 | 승인 대기 수 | Hospital 실험실 검사 입력 |
| 접수·진료 | 수납 | `/billing` | - | P1 | Hospital PRD 수납 |
| 지식 | 어시스턴트 대화 | `/assistant` | - | - | 확정 결정 13 |
| 지식 | 운영 위키 | `/wiki`, `/wiki/[...slug]` | - | - | 확정 결정 13 |
| AI·지식 관리 | 문서 관리 | `/settings/knowledge` | - | 색인 실패 수 | 확정 결정 13 |
| AI·지식 관리 | 위키 검수 | `/settings/wiki` | - | - | 확정 결정 13 |
| AI·지식 관리 | AI 사용량 | `/settings/ai-usage` | - | P1 | KIT-F-020 |
| 관리 | 직원 | `/staff` | 초대 · 역할 · 상태 | - | Hospital 역할 4개 |
| 관리 | 의료정보 접근 기록 | `/settings/access-log` | 기간 · 행위자 · 환자 필터 | - | 기획 공백 3 |
| 관리 | 감사 로그 | `/settings/audit` | - | P1 | KIT-F-012 |
| (아래 고정) | 계정 | `/settings/account` | 이름 · 비밀번호(로그인 방법 구역 없음) | - | - |

"접수·진료" 묶음의 순서는 2.5절 흐름(예약 → 접수·대기열 → 차트 → 검사 → 수납) 그대로다. hms에는 `/settings/ai`(2.11절 끝, 404)와 `/settings/billing`(contract 플랜)이 없다. 역할별: doctor 대기열·캘린더(조회)·환자·검사·지식, staff 캘린더·환자·수납·지식, lab_tech 검사·지식(1.3절 역할 접근 열).

#### 8.3.3 SMS

| 묶음 | 메뉴 | 경로(1절) | 탭·하위 | 배지 | 원본 |
|---|---|---|---|---|---|
| (맨 위) | 홈 | `/admin/dashboard` | 8.5절 | - | School 관리자 대시보드 |
| 출석 | 출석 체크 | `/admin/attendance` | 학급 · 과목 · 날짜 선택 바 | 미체크 수 | School HEAD 출석 체크 보드 |
| 출석 | 출석 추이 | `/admin/trend` | 학급 필터 · 기간 | P1 | School PRD F-DASH-01 |
| 학급 | 학급 | `/admin/classes` | - | - | School HEAD 학급 CRUD |
| 학급 | 과목 | `/admin/subjects` | - | - | School HEAD 과목 CRUD |
| 학급 | 구성원 | `/admin/members` | 교사·학생 초대 · 학급 배정 | - | School HEAD 학생 관리 |
| 지식 | 어시스턴트 대화 | `/assistant` | - | - | 확정 결정 13 |
| 지식 | 운영 위키 | `/wiki`, `/wiki/[...slug]` | - | - | 확정 결정 13 |
| AI·지식 관리 | 문서 관리 | `/settings/knowledge` | - | 색인 실패 수 | 확정 결정 13 |
| AI·지식 관리 | 위키 검수 | `/settings/wiki` | - | - | 확정 결정 13 |
| AI·지식 관리 | AI 사용량 | `/settings/ai-usage` | - | P1 | KIT-F-020 |
| AI·지식 관리 | AI 처리 방식 | `/settings/ai` | - | - | 확정 결정 17 |
| 관리 | 학교 설정 | `/admin/settings`(새 경로, 8.4절) | 학교 이름 · 학년도 · 교사 출석 수정 기간 | (제안) | School HEAD 설정 |
| 관리 | 감사 로그 | `/settings/audit` | - | P1 | KIT-F-012 |
| 관리 | 플랜과 구독 | `/settings/billing` | - | Phase 2 | 없음(01장 2절) |
| (아래 고정) | 계정 | `/settings/account` | 로그인 방법(Stage C, 7.4절) | - | School 로그아웃(삭제된 settings 추정) |

teacher는 홈·출석 체크·출석 추이·학급(조회)·과목(조회)·지식을 본다(1.4절, D-2 B). student는 다른 셸 메뉴를 쓴다:

| 묶음 | 메뉴 | 경로(1절) | 탭·하위 | 배지 | 원본 |
|---|---|---|---|---|---|
| (맨 위) | 내 출석 | `/student/dashboard` | - | - | School HEAD 학생 대시보드 |
| 지식 | 운영 위키 | `/wiki` | `sms-guide-all` 범위만(01장 3.7절) | - | 확정 결정 13 |
| (아래 고정) | 계정 | `/settings/account` | - | - | - |

student 셸에는 어시스턴트 버튼, 마이크, 새로 만들기, 메뉴 검색을 두지 않는다(D-16 A, SMS-F-013).

원본 사이드바의 정확한 메뉴 이름은 원본 파일(`ERP-Wesite/components/layout/Sidebar.tsx:10-16`, `Hospital/src/components/layout/sidebar.tsx`, `School_Management_System/src/components/ui/Sidebar.tsx:6-9`)에 있으나 이 저장소에 없다(미확인). ERP는 리뷰의 화면 5개(`docs/reviews/ERP-Wesite.md:23`), Hospital은 화면 경로(`docs/reviews/Hospital.md:39-43`), School은 404로 이어진 3개 경로 + 대시보드(`docs/reviews/School_Management_System.md:17`, `:37`)로 추정했다. 원본 파일을 확인하면 8.3절과 8.7절 표를 고친다.

### 8.4 학교 설정 (sms `/admin/settings`, 새 경로)

| 항목 | 내용 |
|---|---|
| 목적 | 학교 단위 설정을 저장한다. 데이터와 RPC는 이미 있으나(05장 `sms.workspaces`의 `school_name`, `school_year`, `teacher_backfill_days` 0..60 기본 7, 04장 `sms.update_workspace_settings`) 1.4절에 화면 경로가 없다. 원본 HEAD에는 `admin/settings` 화면이 있었다(`docs/reviews/School_Management_System.md:17`, `:39`) |
| 구성 | 폼 1개: 학교 이름, 학년도, 교사 출석 수정 기간(일, 0~60). 수정 기간 아래에 "교사는 오늘(KST)부터 n일 전까지 출석을 고칠 수 있습니다. 관리자는 제한이 없습니다"(SMS-F-006) |
| 데이터 | `sms.workspaces` |
| 행동 | 저장(`sms.update_workspace_settings`, 감사 기록). 범위 밖 값은 입력칸 오류 |
| 패턴 / 시각 | H / -(ERP `/settings`와 같음) |
| 권한 / 플랜 | admin / 전체 |
| 우선순위 | P2(제안, ERP `/settings`와 같은 단계). 소유 작업은 sms 화면 작업에 더한다(06장 반영은 별도 승인 후) |

D-27이 (b)로 정해지면 이 경로를 만들지 않고 8.3.3절 표에서 행을 지운다.

### 8.5 홈 구성 (ERP `/dashboard`, 1.2절 홈 행 구체화)

위에서 아래 순서. 4.3절 와이어프레임과 4.4절 판정을 따라 큰 숫자는 "오늘 매출" 1개만 두고 나머지 지표는 한 줄 텍스트로 쓴다(KPI 카드 나열 금지, `docs/design-module/_design-guide/DASHBOARD_PATTERNS.md:128` "ERP: C(매출 1개 크게)").

| 순서 | 영역 | 내용 | 누르면 |
|---|---|---|---|
| 1 | 오늘 처리할 일(제안) | 부족 재고 SKU, 대기 판매, 가입 요청 대기, 색인 실패 문서. 각 개수, 0이면 칩을 숨긴다. 역할에 보이는 메뉴의 칩만 | 재고, 판매, 가입 요청, 문서 관리 |
| 2 | 오늘 매출 | 당일(KST) 매출 합 1개 크게 + 한 줄 텍스트(판매·취소 건수, 활성 SKU, 부족 SKU, 활성 직원). `erp.dashboard_metrics` 1회(ERP-F-006) | 판매 |
| 3 | 위험 재고 표(넓게) + 최근 재고 변동(좁게) | 위험 재고: `is_low_stock` 품목만(ERP-F-003), SKU·이름·수량·안전재고. 최근 변동: 실시간 5건, 수량 증감 +/- 표기(ERP-F-008) | 상품 상세, 재고 |
| 4 | 판매 추이(P1) | 시간(당일) 버킷, KST(ERP-F-007). 기간은 `sales_trend_days` 안에서 | 판매 |

HMS와 SMS 홈:

| 앱 | 경로 | 순서(위 → 아래) | 근거 |
|---|---|---|---|
| hms admin | `/dashboard`(P1) | 1 오늘 처리할 일(제안: 검사 승인 대기, 미수 수납) → 2 오늘 예약·내원·완료·취소·노쇼(분리된 숫자, 한 줄) → 3 진료과 비율 + 수납액(오늘·어제·이번 달) | HMS-F-013. 원본 하드코딩 KPI는 버린다(`docs/reviews/Hospital.md:64`). P1 전까지 admin 홈은 D-26 |
| hms doctor·staff·lab_tech | `/queue`, `/calendar`, `/lab` | 각 화면이 홈(D-26 기본값). 홈 전용 화면을 따로 만들지 않는다 | 4.2절 주된 일 |
| sms admin·teacher | `/admin/dashboard` | 1 오늘 처리할 일(미체크 학급·교시) → 2 숫자 1~2개(오늘 출석률, 미체크 수) → 3 학급별 출석률 + 실시간 피드 | 1.4절 홈 행, `DASHBOARD_PATTERNS.md:128` "SMS: 오늘 처리할 일(출결)", SMS-F-008 |
| sms student | `/student/dashboard` | 이번 달 출석률, 지각·조퇴·결석 횟수, 오늘 과목 목록 | 3절 표, SMS-F-009 |

### 8.6 셸 동작 규칙

| 항목 | 규칙 |
|---|---|
| 폭 | 펼침 240px, 접힘 64px 아이콘 레일(제안). 원본 ERP는 260px 고정에 햄버거가 없었다(`docs/reviews/ERP-Wesite.md:84`). 접힌 상태에서 메뉴 이름은 툴팁, 개수 배지는 점 |
| 현재 위치 | 왼쪽 3px 막대(`--color-accent`) + 배경 + `aria-current="page"`. 헤더 아래 경로 표시("Admin Suite ERP › 묶음 › 메뉴"). 경로 표시에 환자·학생·직원 이름을 넣지 않는다(메뉴 이름까지만) |
| 역할 밖 메뉴 | 렌더하지 않는다. 자물쇠·흐린 메뉴로도 보이지 않는다(KIT-F-003). 원본 Hospital은 권한 없는 메뉴를 자물쇠와 함께 클릭 가능하게 노출해 우회 경로를 안내했다(`docs/reviews/Hospital.md:73`) |
| 플랜 | 화면 단위 플랜 잠금이 없다(1절 머리). 기능 키가 꺼진 메뉴(`ai_wiki` false의 위키·위키 검수, `ai_assistant` false의 어시스턴트 대화)는 D-25 기본값으로 숨긴다. 수량 한도 초과는 해당 화면의 402 안내(5절) |
| 개수 배지 | erp 재고(부족 SKU, 경고색), 가입 요청(대기), hms 대기열(대기), 검사(승인 대기), sms 출석 체크(오늘 미체크), 문서 관리(색인 실패, 위험색). 0이면 숨긴다. 값은 서버 집계 RPC에서 받고 화면에서 하드코딩하지 않는다 |
| 반응형 | 1024px 미만은 GNB를 숨기고 햄버거 → 왼쪽 서랍(264px, 배경 딤, 바깥 누르면 닫힘). 검색·계정 메뉴는 서랍 안으로. 출석 보드는 768px 태블릿 우선(6절) |
| 접근성 | GNB는 `<nav aria-label>`, 묶음 제목은 목록 머리, 메뉴 버튼 높이 40px(`--space-row-default`) 이상, `:focus-visible` 포커스 링, 서랍은 포커스 가둠 + Esc 닫기. 상태 배지는 아이콘 + 텍스트(색만으로 구분하지 않음, 3.2절) |
| 앱별 토큰 | 셸은 `apps/<app>/src/theme/tokens.css`의 의미 기반 이름만 쓴다(3.2절). ERP 라이트: 코발트 전표 #0047AB(accent), 장부 회색 #F8FAFC, 먹선 #1E293B, 괘선 #CBD5E1, 경고 오렌지 #FF8C00(부족 배지만). HMS 다크: 야간 병동 #0F172A, 패널 #1E293B, 차트 회백 #E2E8F0, 수술포 청록 #14B8A6, 메디컬 레드 #E11D48(경고만). SMS 라이트: 칠판 인디고 #4F46E5, 분필 회색 #F9FAFB, 잉크 #111827, 출석 4색은 출석 화면 범례와 함께만(4.3절) |
| 셸 밖 화면 | `/login`, `/signup`, `/pending`, `/invite/accept`, `/no-access`, `/dev/components`는 GNB 없이 그린다(1.1절) |
| 금지 | 메뉴 이모지(원본 School 이모지 아이콘, `docs/reviews/School_Management_System.md:62`), 자물쇠 메뉴, 하드코딩 개수·KPI, 컴포넌트 안 hex, 앱 전환 링크, 헤더에서 업무 데이터 검색 |

### 8.7 원본 메뉴 → 새 위치

| 원본 | 원본 메뉴·기능 | 새 위치 |
|---|---|---|
| ERP-Wesite(화면 5개, `docs/reviews/ERP-Wesite.md:23`, `:51`) | 대시보드 · 재고 · 판매 · 인사 · 설정 | 홈 · 재고 · 판매 · 임직원 · 회사 설정(P2) |
| ERP-Wesite | 역할별 메뉴 접근 제어 미구현(`:30`), Pending 승인(`:29`), 부서(`:37`), 권한 수정 모달(`:39`), Storage 이미지(`:40`) | 역할 매트릭스 GNB(8.3절) · 가입 요청 + 셸 밖 `/pending` · 부서(P1) · 임직원 권한 모달 · 재고 상품 상세(P1, ERP-F-014) |
| ERP-Wesite | 시스템 로그(`app/actions/logs.ts`, `:53`, `:90`) | 감사 로그(P1, master_admin만) |
| ERP-Wesite | 중복 라우트 `/inventory` 등(`:52`, `:74`) | 버림. 1.2절 경로 하나만 |
| ERP-Wesite | 헤더 검색·알림 벨·액션 버튼(`:80`) | 메뉴 검색(제안, D-28) · 버림(벨) · 새로 만들기(제안) |
| ERP-Wesite | 설정 화면의 프로젝트 URL·키 표시(`:72`), 저장 목업(`:73`) | 버림 · 회사 설정 실제 저장(ERP-F-013) |
| Hospital(기능 목록, `docs/reviews/Hospital.md:19-25`, 화면 `:39-43`) | 관리자 대시보드 · 환자 목록/상세 · 예약 캘린더 · 실시간 대기열 · 실험실 검사 입력 | 관리자 대시보드(P1) · 환자 · 예약 캘린더 · 대기열 · 검사 |
| Hospital | 로그인 역할 선택 UI(`:19`, `:60`) · 비밀번호 임시 접근 게이트(`:25`) · 자물쇠 메뉴(`:73`) | 버림(07장 4절). 역할은 DB만, 역할 밖 메뉴는 렌더하지 않음 |
| Hospital | `ROLE_HOME`/`ROLE_LABEL` 3곳 복제(`:72`) | `apps/hms/src/access.ts` 한 곳(02장 2절). 홈 값은 D-26 |
| Hospital | (원본에 없음) 수납, 직원 초대, 접근 기록 | 수납(P1) · 직원 · 의료정보 접근 기록 |
| School_Management_System(사이드바 4개, `docs/reviews/School_Management_System.md:37`) | 대시보드 · 학급 · 과목 · 출석(3개는 404, `:17`) | 홈 · 학급 · 과목 · 출석 체크 |
| School_Management_System(HEAD만, `:17`, `:39`) | `admin/students` · `admin/settings` · 학생 대시보드 | 구성원 · 학교 설정(새 경로, D-27) + 계정(로그아웃, `:53`) · 내 출석 |
| School_Management_System | 학생 실시간 알림 `RealtimeStudentNotif`(`:22`, `:36`) | 내 출석 화면 5초 토스트(SMS-F-011, P1). GNB 메뉴 없음 |
| School_Management_System | 이모지 아이콘(`:62`) | 버림. lucide 아이콘 |
| basic-master-module | 기본 AppShell(사이드바 + 헤더) 제안(`docs/reviews/basic-master-module.md:103`) | admin-kit AppShell(KIT-F-008) 하나로 세 앱 공용 |
| basic-master-module | 로그인·콜백·로그아웃 골격(`:76`, `:101`) | 셸 밖 인증 화면(7절) · 계정 메뉴 로그아웃 |
| basic-master-module | 기본 랜딩 `app/page.tsx`(`:64`) | 버림(공개 랜딩 없음, 4절) |

### 8.8 1절과 달라진 점

| 1절 위치 | 이전 | 지금 |
|---|---|---|
| 화면 표 전체 | 메뉴 순서·묶음 없음 | 8.3절 순서가 GNB 정본. 1절 행은 고치지 않는다 |
| 1.4절 SMS | 학교 설정 경로 없음(데이터·RPC만 있음) | `/admin/settings` 추가(8.4절, D-27 결정 전 기본값) |
| 1.1절 공통 | 공통 화면 묶음 없음 | 세 앱 모두 "지식"(대화·위키), "AI·지식 관리", "관리" 묶음으로 같은 이름·같은 순서. hms는 `/settings/ai`, `/settings/billing` 행이 원래 없다 |
| 1.2절 ERP 홈 행 | "대시보드(지표, 위험 재고, 최근 변동, 판매 추이)" | 8.5절 4개 영역으로 구체화. 맨 위 "오늘 처리할 일" 줄은 새로 제안 |
| 1.2절 ERP `/settings` 우선순위 | P2 | GNB 배지는 1.2절대로 P2. 01장 2절은 "설정 저장"을 MVP 직후(P1)로 적어 서로 다르다(미확인, 어느 쪽이 맞는지 확인 후 한쪽을 고친다) |
