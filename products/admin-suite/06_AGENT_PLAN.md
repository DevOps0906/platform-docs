# 06 에이전트 작업 계획: Admin Suite

작업 ID 접두사: `ADM`(admin-suite 공통. 앱별 SQLSTATE 접두사 ER/SM/HM과 별개로 제품 단위 하나를 쓴다, 제안).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 아래 표의 디렉토리만 만진다. 두 작업이 같은 파일을 만지지 않는다 |
| admin-kit 먼저 | 앱 작업은 W1(admin-kit) 산출물의 공개 API만 import한다. admin-kit 수정이 필요하면 해당 admin-kit 작업 소유자에게 요청 |
| SQL 정본 | 모듈러 조각 2개와 hms 모놀리스는 Fable 작업만 수정. erp/sms 모놀리스 도메인 파일은 변환 스크립트(ADM-06-004)만 생성 |
| 앱 내부 분할 | `apps/<app>/src/app/(app)/<화면>/`과 `apps/<app>/src/server/<도메인>.ts`를 같은 작업이 소유. 공통 `apps/<app>/src/access.ts`, `src/theme/`, `src/proxy.ts`는 테마/내비 작업이 소유 |
| 테스트 | `tests/rls/`, `tests/db/`, `tests/e2e/<app>/`, `tests/e2e/billing/`은 테스트 작업만 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ADM-06-001 | erp/sms 모듈러 조각 확정·적용(로컬 Supabase), config schemas 등록 | `docs/products/_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql` | 없음 | P0 | M | Fable | 체커 OK, 모듈러 스모크 92항목 통과, `supabase db reset` 성공 | ERP 리뷰 5장 #1,#3,#8,#9, School 5장 #3, 05장 7절 |
| ADM-06-002 | hms 모놀리스 도메인 SQL 확정(의료정보 보호) | `docs/products/admin-suite/supabase/monolith/hms/` | 없음 | P0 | L | Fable | 체커 OK, hms 스모크 52항목 통과, 민감 테이블 SELECT GRANT 0 | Hospital 5장 #1,#3,#9,#12, HMS-F-014 |
| ADM-06-003 | erp/sms 모놀리스 lite·seed 검증 | `docs/products/admin-suite/supabase/monolith/erp/seed.sql`, `sms/seed.sql`, 각 `0001_core_lite.sql` | ADM-06-001 | P0 | S | Fable | 체커 OK, 스모크 erp 21, sms 19 통과 | 05장 8절 |
| ADM-06-004 | 조각 → 모놀리스 변환 스크립트 + CI diff 검사 | `tools/admin-suite/to-monolith.py`, `.github/workflows/sql-check.yml` | ADM-06-001 | P1 | S | Haiku | 스크립트 재실행 결과와 커밋된 `0002_<app>_domain.sql` diff 0 | `DB_CONVENTIONS.md` 12장 제안 |
| ADM-06-005 | 모노레포 골격 + `db:types` | `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `scripts/db-types.mjs`, `packages/admin-kit/package.json` | 없음 | P0 | S | Haiku | `pnpm db:types --app erp` 가 타입 생성, `pnpm -r build` 통과 | ERP 5장 #13, Hospital 5장 #5, School 5장 #7 |
| ADM-06-006 | admin-kit Supabase 래퍼와 세션 | `packages/admin-kit/src/supabase/` | ADM-06-005 | P0 | S | Opus | 앱이 `createAdminClients(appId)`만으로 3종 클라이언트와 `getSession`을 얻음 | KIT-F-001 |
| ADM-06-007 | admin-kit 가드: `createAdminProxy`, `requireRole`, `defineAccess` | `packages/admin-kit/src/auth/` | ADM-06-006 | P0 | M | Fable | 프로필 없음 → 로그아웃, pending → /pending, 매트릭스 밖 → 403(RSC 페이로드 없음), 역할 기본값 없음 | ERP 5장 #4,#5, Hospital 5장 #2,#14, School 5장 #2,#4, KIT-F-002~004 |
| ADM-06-008 | KST 날짜 유틸 + 단위 테스트 | `packages/admin-kit/src/date/` | ADM-06-005 | P0 | S | Sonnet | 00:30 KST, 23:59 KST, 월말 경계 테스트 12개 통과 | ERP 5장 #7, Hospital 5장 #4, School 5장 #6 |
| ADM-06-009 | admin-kit UI(AppShell 햄버거, DataTable, FormModal, ConfirmDialog, Toast, KpiCard, Chart) | `packages/admin-kit/src/ui/` | ADM-06-005 | P0 | L | Sonnet | 375/768/1024/1440px 스크린샷 가로 스크롤 0, 로그아웃 버튼, axe 위반 0 | ERP 5장 #6, Hospital 5장 #13, School 5장 #4,#10, KIT-F-008~009 |
| ADM-06-010 | `useRealtimeTable` | `packages/admin-kit/src/realtime/` | ADM-06-006 | P1 | S | Opus | 한 화면 채널 1개, payload 부분 갱신, 언마운트 해제 테스트 | ERP 5장 #8, Hospital 5장 #11, School 5장 #9 |
| ADM-06-011 | 가입 승인/초대 공통 흐름(화면 조각 + 서버 함수, Auth Admin 초대) | `packages/admin-kit/src/members/` | ADM-06-007 | P0 | M | Opus | 앱이 RPC 이름을 주입해 승인제·초대제 모두 동작, 본인 초대 차단 | KIT-F-005~007, School 5장 #8 |
| ADM-06-012 | 감사 로그 뷰어 | `packages/admin-kit/src/audit/` | ADM-06-009 | P1 | S | Sonnet | owner/admin만 표시, 기간·action 필터 | KIT-F-012 |
| ADM-06-013 | 플랜/구독 화면과 Route Handler(공용 toss 모듈 호출) | `packages/admin-kit/src/billing/` | ADM-06-007 | P2 | M | Fable | standard 구독 confirm 후 엔타이틀먼트 standard, PM001 시 주문 상태에 의존하지 않음 | 01장 4절 |
| ADM-06-014 | ERP 인증·가입(승인제)·대기 화면 | `apps/erp/src/app/(auth)/`, `apps/erp/src/app/pending/` | ADM-06-011 | P0 | M | Opus | signUp에 `signup_app`, `full_name`, 승인 후 accept까지 E2E 통과 | ERP 5장 #2,#4 |
| ADM-06-015 | ERP 재고 화면과 서버 | `apps/erp/src/app/(app)/inventory/`, `apps/erp/src/server/inventory.ts`, `apps/erp/src/server/images.ts` | ADM-06-001, ADM-06-009 | P0 | M | Opus | 감소 조정, ER001 메시지, 위험 재고 `is_low_stock` 필터, 이미지 경로 강제 | ERP 5장 #3,#8,#13, ERP-F-001~003,014 |
| ADM-06-016 | ERP 판매 화면과 서버 | `apps/erp/src/app/(app)/sales/`, `apps/erp/src/server/sales.ts` | ADM-06-001, ADM-06-009 | P0 | M | Opus | 상태 탭, 취소 사유, 재시도 멱등 | ERP 5장 #3,#9, ERP-F-004~005 |
| ADM-06-017 | ERP 대시보드 + 판매 추이 | `apps/erp/src/app/(app)/dashboard/` | ADM-06-008, ADM-06-010 | P1 | M | Opus | `dashboard_metrics` 1회 호출, 전체 행 조회 0, 실시간 최근 변동 | ERP 5장 #7,#10, ERP-F-006~008 |
| ADM-06-018 | ERP 인사·부서·가입 요청 | `apps/erp/src/app/(app)/hr/`, `apps/erp/src/app/(app)/me/`, `apps/erp/src/server/hr.ts` | ADM-06-011 | P1 | M | Opus | 부서 CRUD, 권한 모달(자기 자신 비활성), 가입 코드 재발급 | ERP 5장 #11, ERP-F-009~012 |
| ADM-06-019 | ERP 설정 | `apps/erp/src/app/(app)/settings/` | ADM-06-018 | P2 | S | Sonnet | 저장 유지, URL/키 표시 0 | ERP 5장 #12, ERP-F-013 |
| ADM-06-020 | ERP 테마·내비·proxy·access 매트릭스 | `apps/erp/src/theme/`, `apps/erp/src/access.ts`, `apps/erp/src/proxy.ts`, `apps/erp/src/app/layout.tsx` | ADM-06-007, ADM-06-009 | P1 | S | Sonnet | 중복 라우트 0, 메뉴가 역할별로만 보임 | ERP 5장 #5,#6 |
| ADM-06-021 | HMS 의료정보 서버 계층(AES-256-GCM, 키 버전, 접근 사유) | `apps/hms/src/server/phi/` | ADM-06-002 | P0 | M | Fable | 키 누락 시 기동 실패, 복호화는 서버에서만, 암호문 클라이언트 전송 0 | Hospital 5장 #3,#5, 01장 6.2절 |
| ADM-06-022 | HMS 인증·직원 관리 | `apps/hms/src/app/(auth)/`, `apps/hms/src/app/(app)/staff/`, `apps/hms/src/server/staff.ts` | ADM-06-011, ADM-06-021 | P0 | M | Opus | OVERRIDE/verify-admin 없음, 초대·역할 변경, 자기 변경 차단 | Hospital 5장 #2, HMS-F-001 |
| ADM-06-023 | HMS 환자 목록/등록/상세/360 차트 | `apps/hms/src/app/(app)/patients/`, `apps/hms/src/server/patients.ts` | ADM-06-021 | P0 | L | Opus | 동의 필수, 성별 실데이터, 타임라인 병합, 접근 기록 1행/열람 | Hospital 5장 #6,#9, HMS-F-002~004,008 |
| ADM-06-024 | HMS 예약 캘린더 | `apps/hms/src/app/(app)/calendar/`, `apps/hms/src/server/appointments.ts` | ADM-06-023 | P1 | M | Opus | 주말 포함 주별 뷰, 빈 슬롯 예약, 범위 조회, visit_type 범례 | Hospital 5장 #7,#12, HMS-F-005 |
| ADM-06-025 | HMS 실시간 대기열 | `apps/hms/src/app/(app)/queue/` | ADM-06-010, ADM-06-024 | P0 | M | Opus | 채널 1개, KST 당일 대기번호, 담당의만 진료 시작 | Hospital 5장 #3,#4,#11, HMS-F-006~007 |
| ADM-06-026 | HMS 검사 | `apps/hms/src/app/(app)/lab/`, `apps/hms/src/server/lab.ts` | ADM-06-023 | P1 | M | Opus | 빈 값 저장 불가, 저장 후 목록 갱신, 승인(입력자 제외), 의뢰 | Hospital 5장 #10, HMS-F-009~011 |
| ADM-06-027 | HMS 수납·대시보드·접근 기록 화면 | `apps/hms/src/app/(app)/billing/`, `apps/hms/src/app/(app)/dashboard/`, `apps/hms/src/app/(app)/settings/access-log/` | ADM-06-025 | P1 | M | Opus | 하드코딩 0, 취소/노쇼 분리, 접근 기록 필터·CSV | Hospital 5장 #4,#8, HMS-F-012~014 |
| ADM-06-028 | HMS 테마·내비·proxy·access | `apps/hms/src/theme/`, `apps/hms/src/access.ts`, `apps/hms/src/proxy.ts`, `apps/hms/src/app/layout.tsx` | ADM-06-007, ADM-06-009 | P1 | S | Sonnet | 메뉴 자물쇠 노출 0, 대비 4.5:1 | Hospital 5장 #14(라벨 중복 제거) |
| ADM-06-029 | SMS HEAD 자산 이식 + 인증·초대 수락 | `apps/sms/src/app/(auth)/`, `apps/sms/src/app/invite/` | ADM-06-011 | P0 | M | Opus | 07장 2절 목록 이식 완료, 학생 첫 로그인 → `/student/dashboard` | School 5장 #1,#8 |
| ADM-06-030 | SMS 학급·과목·구성원 관리 | `apps/sms/src/app/(app)/admin/classes/`, `.../subjects/`, `.../members/`, `apps/sms/src/server/roster.ts` | ADM-06-029 | P0 | M | Opus | zod 검증, `requireRole('admin')`, 14세 미만 동의 체크 | School 5장 #5, SMS-F-001~004 |
| ADM-06-031 | SMS 출석 체크 보드 | `apps/sms/src/app/(app)/admin/attendance/`, `apps/sms/src/server/attendance.ts` | ADM-06-030, ADM-06-010 | P0 | M | Opus | 일괄 저장 200건, SM002 메시지, 학급 필터 구독 | SMS-F-005~007 |
| ADM-06-032 | SMS 관리자/학생 대시보드 + 추이 + 알림 | `apps/sms/src/app/(app)/admin/dashboard/`, `.../admin/trend/`, `apps/sms/src/app/(app)/student/` | ADM-06-031, ADM-06-008 | P1 | M | Opus | 출석률 정의 일치(100% 초과 0), payload 부분 갱신, 학생 5초 알림 | School 5장 #6,#9,#12, SMS-F-008~011 |
| ADM-06-033 | SMS 테마·내비(lucide)·proxy·access | `apps/sms/src/theme/`, `apps/sms/src/access.ts`, `apps/sms/src/proxy.ts`, `apps/sms/src/app/layout.tsx` | ADM-06-007, ADM-06-009 | P2 | S | Sonnet | 이모지 0, 빌드 로그에 Proxy 항목 | School 5장 #10 |
| ADM-06-034 | RLS/권한 회귀 테스트(모듈러 + 모놀리스 3종) | `tests/rls/` | ADM-06-001, ADM-06-002, ADM-06-003 | P0 | M | Fable | `SECURITY_BASELINE.md` 15장 + `DB_CONVENTIONS.md` 13.3 + 이 제품 항목, CI에서 실패 0 | `SECURITY_BASELINE.md` 0장, 05장 7절 |
| ADM-06-035 | 역할·경로 E2E(Playwright) | `tests/e2e/erp/`, `tests/e2e/hms/`, `tests/e2e/sms/` | ADM-06-020, ADM-06-028, ADM-06-033 | P0 | M | Opus | 역할 x 경로 매트릭스 전 조합 기대 상태 코드, 비로그인 리다이렉트, 사이드바 링크 404 0 | 02장 6절, School 리뷰 #1,#2 |
| ADM-06-036 | 결제 E2E(Toss 테스트 키) | `tests/e2e/billing/` | ADM-06-013 | P1 | M | Opus | standard 구독 성공, 금액 위조 PM001, 웹훅 서명 실패 401 | `DOC_TEMPLATE.md` 작업 규칙 |
| ADM-06-037 | ERP 동시성·멱등 DB 테스트 | `tests/db/erp/` | ADM-06-001 | P0 | S | Opus | 동시 판매 50건 후 음수 0, 수량 = 이동 합, 같은 request_id 1행 | ERP 5장 #3 |
| ADM-06-038 | 저장소 위생: .gitignore, .env.example, README, 원본 archive, 금지 env 검사 | `.gitignore`, `.env.example`, `apps/*/README.md`, `archive/README.md`, `packages/admin-kit/src/env/` | ADM-06-005 | P0 | S | Haiku | `.env*` 무시, `OVERRIDE_PASSWORD` 존재 시 기동 실패, nested git 0 | ERP 5장 #14, Hospital 5장 #14, School 5장 #11 |
| ADM-06-039 | 린트/TS 설정(`eslint .`, Next 16 규칙, no-explicit-any) | `eslint.config.mjs`, `tsconfig.base.json` | ADM-06-005 | P1 | S | Haiku | `pnpm lint` 오류 0, `next lint` 사용 0 | ERP 5장 #14, School 5장 #11 |
| ADM-06-040 | 디자인 MASTER.md와 로그인 화면 | `design-system/admin-suite/` | ADM-06-009 | P1 | S | Sonnet | 03장 4절 토큰 반영, 7단계 체크리스트 통과 | 03장 4절 |

P0 작업과 테스트 대응: SQL(001~003) → 034, 037 / admin-kit 가드·UI(006~009, 011) → 035, 008 단위 테스트 / 앱 P0 화면(014~016, 021~023, 025, 029~031) → 035 / 위생(005, 038) → CI.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 005 | 3 | 없음 | DB 조각·모놀리스 적용, 모노레포 골격 |
| W1 | 003, 004, 006, 008, 009, 038, 039 | 7 | W0 | 모놀리스 검증, 변환기, admin-kit 기초 |
| W2 | 007, 010, 021, 034, 037, 040 | 6 | 006, 001~003 | 가드, Realtime, PHI 계층, RLS·동시성 테스트 |
| W3 | 011, 012, 020, 028, 033 | 5 | 007, 009 | 가입 흐름, 앱 셸 3개 |
| W4 | 014, 015, 016, 022, 023, 029, 030 | 7 | W3 | 앱 P0 화면 |
| W5 | 017, 018, 024, 025, 026, 031, 013 | 7 | W4 | 대시보드, 인사, 캘린더, 대기열, 검사, 출석, 결제 |
| W6 | 019, 027, 032, 035, 036 | 5 | W5 | 잔여 화면, E2E |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 7 (001, 002, 003, 007, 013, 021, 034) | 17.5% | 14 / 68 = 20.6% |
| Opus | 21 | 52.5% | 40 / 68 = 58.8% |
| Sonnet | 8 (008, 009, 012, 019, 020, 028, 033, 040) | 20.0% | 10 / 68 = 14.7% |
| Haiku | 4 (004, 005, 038, 039) | 10.0% | 4 / 68 = 5.9% |
| 합계 | 40 | 100% | 68 |

## 5. 리뷰 작업 흡수표

| 리뷰 | 5장 # | 작업 요약 | 흡수 작업 ID |
|---|---|---|---|
| ERP-Wesite | 1 | RLS 재작성(재귀 제거, 역할 상승 차단) | ADM-06-001, ADM-06-034 |
| ERP-Wesite | 2 | handle_new_user + signUp 메타데이터 | ADM-06-014(코어 트리거 사용) |
| ERP-Wesite | 3 | record_sale/record_inventory_move RPC | ADM-06-001, ADM-06-015, ADM-06-016, ADM-06-037 |
| ERP-Wesite | 4 | permissions + requireRole + /pending | ADM-06-007, ADM-06-014 |
| ERP-Wesite | 5 | proxy.ts 전환, 중복 라우트 삭제 | ADM-06-007, ADM-06-020 |
| ERP-Wesite | 6 | 사이드바 필터, 햄버거 | ADM-06-009, ADM-06-020 |
| ERP-Wesite | 7 | kstDayRange | ADM-06-008, ADM-06-017 |
| ERP-Wesite | 8 | Realtime publication, reload 제거, ADJUSTMENT 표시, is_low_stock | ADM-06-001, ADM-06-010, ADM-06-015 |
| ERP-Wesite | 9 | 판매 상태와 취소 RPC | ADM-06-001, ADM-06-016 |
| ERP-Wesite | 10 | 판매 추이, dashboard_metrics | ADM-06-017 |
| ERP-Wesite | 11 | 부서 CRUD, phone/position | ADM-06-018 |
| ERP-Wesite | 12 | 설정 화면 정리 | ADM-06-019 |
| ERP-Wesite | 13 | gen types, 모달 분리, 미사용 액션 삭제 | ADM-06-005, ADM-06-015 |
| ERP-Wesite | 14 | lint, .env.example, gitlink 정리 | ADM-06-038, ADM-06-039 |
| Hospital | 1 | 스키마 + RLS + 트리거 | ADM-06-002 |
| Hospital | 2 | proxy 역할 차단, PageGuard/verify-admin 제거 | ADM-06-007, ADM-06-022 |
| Hospital | 3 | 쓰기 서버 이전 + 상태 전이 검증 | ADM-06-002, ADM-06-021, ADM-06-025 |
| Hospital | 4 | KST 유틸 | ADM-06-008, ADM-06-025, ADM-06-027 |
| Hospital | 5 | gen types, as any 제거 | ADM-06-005, ADM-06-021 |
| Hospital | 6 | 환자 등록 + 검색 | ADM-06-023 |
| Hospital | 7 | 캘린더 범위·슬롯 예약·Realtime·주말 | ADM-06-024 |
| Hospital | 8 | 대시보드 실데이터 + 수납 스키마 | ADM-06-002, ADM-06-027 |
| Hospital | 9 | 360 타임라인 lab 병합, 성별, 기록 등록 | ADM-06-002, ADM-06-023 |
| Hospital | 10 | 검사 갱신·승인·의뢰·빈 값 방지 | ADM-06-026 |
| Hospital | 11 | 대기열 단일 구독·부분 갱신 | ADM-06-010, ADM-06-025 |
| Hospital | 12 | visit_type | ADM-06-002, ADM-06-024 |
| Hospital | 13 | 미사용 UI 정리/shadcn 치환 | ADM-06-009 |
| Hospital | 14 | ROLE_HOME 중복 제거, README, nested git | ADM-06-028, ADM-06-038 |
| School | 1 | 작업 트리 정리, HEAD 복원 | ADM-06-029, ADM-06-038 |
| School | 2 | src/proxy.ts 이전, 루프 방지 | ADM-06-007, ADM-06-033 |
| School | 3 | 0001_init.sql(RLS, 트리거, unique, Realtime) | ADM-06-001 |
| School | 4 | 레이아웃 역할 재검증, 로그아웃 | ADM-06-007, ADM-06-009 |
| School | 5 | requireRole + zod + 오류 반환 타입 | ADM-06-030 |
| School | 6 | KST + 출석률 분모 통일 | ADM-06-008, ADM-06-032 |
| School | 7 | gen types, any 제거 | ADM-06-005 |
| School | 8 | 학생 초대·학급 배정 | ADM-06-011, ADM-06-029, ADM-06-030 |
| School | 9 | RealtimeFeed 부분 갱신, 집계 RPC | ADM-06-010, ADM-06-032 |
| School | 10 | 반응형, lucide | ADM-06-009, ADM-06-033 |
| School | 11 | package.json, .env.example, README | ADM-06-038, ADM-06-039 |
| School | 12 | 출석 추이 그래프 | ADM-06-032 |

리뷰 5장 작업 40개(ERP 14 + Hospital 14 + School 12) = 이 표 40행.

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 |
|---|---|---|
| 팀 조직 생성 함수 `core.create_team_organization(p_name, p_owner, p_app_id)` (service_role, 엔타이틀먼트 manual 포함) | `_platform-core` | 지금은 프로비저닝 스크립트가 코어 테이블에 직접 INSERT해야 한다. 함수가 있으면 감사와 검증을 한 곳에서 한다 |
| 모놀리스 lite에서 `purge_organization`을 크레딧 절 밖으로 분리 | `_platform-core` | 크레딧 절을 지운 제품(admin-suite 3앱)은 조직 파기 함수가 없다 |
| `confirm_payment_order` 금액 불일치 시 주문 failed 영속화 | `_platform-core` | 알려진 결함(`DB_CONVENTIONS.md` 13.2). 제품은 의존하지 않는다 |
| 통합 seed의 erp/sms default 플랜 features 갱신 | `_supabase-modular/seed.sql` 담당 | 조각이 `on conflict do nothing`이라 01장 4절 features 키가 반영되지 않는다 |
| 팀 운영 예외 확인 | 사용자(확정 결정 5) | "1인 1워크스페이스" 운영 원칙과 달리 admin-suite는 고객사 조직에 다수 멤버가 필수다 |

## 7. 완료 정의

| 조건 | 명령/기준 |
|---|---|
| 빌드 | `pnpm -r build` 성공(앱 3개 + admin-kit) |
| 타입 | `pnpm -r typecheck` 오류 0, `pnpm db:types` 후 diff 0 |
| 린트 | `pnpm lint` 오류 0(`no-explicit-any`, 이모지 아이콘 금지 규칙 포함) |
| SQL | `node check.mjs mod ... 0007 ... 1600_erp.sql 1700_sms.sql` OK, `mono-erp/mono-sms/mono-hms` OK |
| RLS 스모크 | `tests/rls` 전 항목 통과(현재 기준 모듈러 92, erp 21, sms 19, hms 52 이상) |
| E2E | 역할 x 경로 매트릭스, 가입 승인/초대, 판매, 접수→진료→검사, 출석 |
| 결제 E2E | Toss 테스트 키(ADM-06-036, Phase 2 범위) |
| 작업 | 06장 작업 40개 완료 |
