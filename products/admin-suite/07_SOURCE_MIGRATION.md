# 07 원본 이식과 폐기: Admin Suite

원본 폴더는 수정하지 않는다. 읽기는 파일 열람과 `git show <커밋>:<경로>`만 쓴다.

## 1. 원본별 자산 분류

### 1.1 ERP-Wesite

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `supabase/migrations/001_initial_schema.sql` 테이블 정의 | 부분 | 참고(스키마 재작성) | `1600_erp.sql` | `docs/reviews/ERP-Wesite.md:57` |
| 같은 파일 RLS 정책 | 결함 | 폐기 | - | `:65-66` |
| `app/actions/inventory.ts`, `sales.ts` | 부분(비원자) | 참고(RPC로 교체) | `apps/erp/src/server/` | `:68` |
| `app/actions/hr.ts` | 부분 | 참고 | `apps/erp/src/server/hr.ts` | `:39` |
| `app/actions/logs.ts` | 부분 | 폐기(감사 로그 화면으로 대체) | admin-kit audit | `analysis:1138` |
| `components/{inventory,sales,hr,dashboard}/*Client.tsx` | 동작 | 이식(모달 분리, admin-kit UI로 교체) | `apps/erp/src/app/(app)/*` | `:54`, `:107` |
| `components/settings/SettingsClient.tsx` | 목업 | 폐기(현재 내용) | - | `:72-73` |
| `components/layout/{Sidebar,Header}.tsx` | 동작 | 참고(AppShell로 흡수) | admin-kit ui | `analysis:1145` |
| `app/(dashboard)/{inventory,sales,hr,settings}/page.tsx` | 중복 | 폐기 | - | `:74` |
| `middleware.ts`, `lib/supabase/*` | 부분 | 폐기(admin-kit 흡수) | - | `analysis:1223` |
| `types/index.ts` | 수기 | 폐기(생성 타입) | - | `:106` |
| `PRD.md`, `UI DESIGN.md`, `ERP-Website.pen` | 기획 | 참고 | 01장, 03장 | - |
| `ERP_Website/`(gitlink) | 빈 저장소 | 폐기 | - | `:9`, `:83` |

### 1.2 Hospital

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `src/proxy.ts` | 부분 | 참고(골격만, 역할 기본값 제거) | admin-kit auth | `docs/reviews/Hospital.md:56` |
| `src/lib/permissions.ts` | 동작 | 이식(형태만, 서버 강제) | `apps/hms/src/access.ts` | `analysis:1131` |
| `src/lib/lab-ranges.ts` | 동작 | 이식(seed `lab_test_catalog`) | `hms/seed.sql` | `:34` |
| `src/hooks/use-realtime-queue.ts`, `components/queue/*` | 동작(이중 구독) | 이식(단일 구독으로) | `apps/hms/src/app/(app)/queue/` | `:61` |
| `src/app/(dashboard)/calendar/*` | 부분 | 이식(범위 조회, 주말, 슬롯 예약 추가) | `apps/hms/.../calendar/` | `:63`, `:75` |
| `src/app/(dashboard)/patients/*` | 부분 | 이식(성별, 타임라인 실데이터) | `apps/hms/.../patients/` | `:65` |
| `src/app/(dashboard)/lab/*` | 동작 | 이식(검증·승인 추가) | `apps/hms/.../lab/` | `:68` |
| `components/dashboard/*` 차트 | 목업 | 참고(레이아웃만) | `apps/hms/.../dashboard/` | `:64` |
| `components/layout/with-page-guard.tsx`, `page-guard.tsx` | 결함 | 폐기 | - | `:54` |
| `src/app/api/auth/verify-admin/route.ts`, `OVERRIDE_PASSWORD` | 결함 | 폐기 | - | `:55` |
| `src/components/ui/`(shadcn 10개), zustand | 미사용 | 폐기 | - | `:71` |
| `src/types/supabase.ts`(수기) | 수기 | 폐기 | - | `:67` |
| `PRD.md`, `CLAUDE.md`, `Design_UI.md` | 기획 | 참고 | 01장, 03장 | - |

### 1.3 School_Management_System

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| HEAD `3c19d1e`: `src/lib/actions.ts` | 동작 | 이식(RPC/정책으로, `requireRole` + zod) | `apps/sms/src/server/roster.ts` | `docs/reviews/School_Management_System.md:67` |
| HEAD: `src/app/admin/attendance/page.tsx` | 동작 | 이식 | `apps/sms/.../admin/attendance/` | `:67` |
| HEAD: `src/app/admin/{classes,subjects,students,settings}` | 동작 | 이식(students → members) | `apps/sms/.../admin/*` | `:39` |
| HEAD: `src/app/student/{layout,dashboard}` | 동작 | 이식 | `apps/sms/.../student/` | `:58` |
| 작업 트리 `src/app/admin/dashboard/page.tsx` | 부분 | 이식(분모 통일, RPC화) | `apps/sms/.../admin/dashboard/` | `:55` |
| `src/components/realtime/*` | 동작/미사용 | 이식(부분 갱신, 학생 알림 연결) | `apps/sms/...` | `:22`, `:59` |
| 루트 `middleware.ts` | 미로드 | 폐기(로직은 access.ts로) | - | `:48` |
| `src/components/ui/Sidebar.tsx` 이모지 | 동작 | 폐기(lucide) | - | `:62` |
| `CLAUDE.md` RLS 예시 | 결함 | 폐기 | - | `:49` |
| `PRD.md`, `Design_UI.md`, `.pen` | 기획 | 참고 | 01장, 03장 | - |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| ERP 화면 Client 컴포넌트 | 400줄 파일에서 모달 분리(`ProductFormModal`, `InventoryMoveModal`, `NewSaleModal`, `PermissionModal`), `revalidatePath` 대신 Server Action 반환 + `router.refresh`, 상태 가짜 생성 제거, ADJUSTMENT 부호 표시 |
| ERP 서버 액션 | 쓰기를 `erp.record_*`/`cancel_sale` RPC 호출로 교체, 첫 줄 `requireRole`, 클라이언트 금액 미사용 |
| Hospital permissions | `ROLE_ACCESS`를 `defineAccess`로 옮기고 proxy와 사이드바가 같은 매트릭스를 쓴다. 기본 역할 없음 |
| Hospital 대기열 훅 | 페이지에서 1회 호출, org 필터, payload로 부분 갱신, 상태 변경은 `transition_appointment` |
| Hospital lab 입력 | `parseFloat` 실패 시 0 대체 제거, 저장은 `save_lab_result`, 이탈 판정은 서버 결과 표시(클라이언트 즉시 표시는 보조) |
| Hospital 환자 상세 | 민감 항목은 `GET /api/hms/patients/:id`(서버 복호화, 접근 기록), 차트는 doctor 전용 경로 |
| School HEAD 액션 | `setStudentRole`(프로필 role 직접 update)은 폐기하고 `sms.set_member_role` RPC, `assignStudentClass`는 `sms.assign_class` |
| School 출석 보드 | upsert를 `mark_attendance_bulk`로, 상태 리터럴을 한글에서 코드(present/late/early_leave/absent)로, 채널명 `sms:<org>:attendance` |
| School 학생 대시보드 | 이번 달 통계를 `sms.student_summary`로, `RealtimeStudentNotif` 연결 |
| lab-ranges | 정상 범위 수치는 원본 그대로 seed로 옮겼다. 임상 검증 전 "참고 범위"로 표기 |

## 3. 폐기 목록과 사유

분석 "폐기" 분류(`analysis:1132`, `:1133`, `:1151`, `:1152`, `:1170`, `:1190`)와 "버려지는 것"(`analysis:1216-1224`) 전부다.

| # | 폐기 항목 | 사유 | 근거 |
|---|---|---|---|
| 1 | Hospital 클라이언트 PageGuard(`with-page-guard.tsx`, `page-guard.tsx`) | 잠금 상태에도 RSC 페이로드가 전송되고 DevTools로 우회된다. 서버 가드로 대체 | `analysis:1132`, `:1218` |
| 2 | Hospital 비밀번호 임시 접근(OVERRIDE 1234) | 공유 4자리로 모든 역할 우회 | `analysis:1133`, `:1218` |
| 3 | Hospital verify-admin API | 위 우회의 서버 측 구현, 시도 제한·감사 없음 | `analysis:1218` |
| 4 | ERP 중복 라우트 4개(`/inventory`, `/sales`, `/hr`, `/settings`) | 바이트 단위 중복이고 가드 밖 | `analysis:1170`, `:1219` |
| 5 | ERP 미사용 조회 액션(`getProducts`, `getProfiles`, `getSalesTransactions`, `getTodaySalesTotal`) | 호출되지 않는 이중 조회 경로 | `analysis:1219`, `docs/reviews/ERP-Wesite.md:81` |
| 6 | ERP 설정 화면 현재 내용 | 저장 안 되는 목업, 실 Supabase URL·anon key 노출. 코어는 계정 정보만 | `analysis:1151`, `:1219` |
| 7 | ERP 헤더 검색과 알림 벨 | 무동작 장식 | `analysis:1152`, `:1220` |
| 8 | Hospital 미사용 shadcn 10개, zustand | import 0건, admin-kit UI로 대체 | `analysis:1221` |
| 9 | Hospital `as any` 20건 | 타입 안전성 0, 생성 타입으로 대체 | `analysis:1221` |
| 10 | School 루트 `middleware.ts` | 위치 때문에 로드되지 않는 코드 | `analysis:1222` |
| 11 | School 이모지 아이콘 | lucide로 교체 | `analysis:1190`, `:1222` |
| 12 | 각 앱의 자체 Supabase 클라이언트, 가드, 날짜 코드 | admin-kit로 흡수(편차 재발 방지) | `analysis:1223` |
| 13 | ERP `ERP_Website` gitlink, Hospital/School nested git 이중 추적 | 모노레포로 정리 | `analysis:1224` |

## 4. 복사 금지 결함

`SECURITY_BASELINE.md` 14장 중 해당 항목 + 리뷰에서 찾은 제품 고유 결함.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| OVERRIDE 비밀번호로 전 역할 우회, verify-admin API | `Hospital/src/app/api/auth/verify-admin/route.ts:6-9` | 의료 데이터 전면 노출 | 역할 변경 RPC + 감사, 금지 env 기동 검사 |
| 프로필 없으면 admin, 클라이언트 PageGuard | `Hospital/src/proxy.ts:57`, `:69` | 권한 상승, RSC 노출 | `createAdminProxy`(프로필 없음 로그아웃) |
| RLS 정책 안 자기참조 재귀 + 권한 상승 | `ERP-Wesite/supabase/migrations/001_initial_schema.sql:76-89`, `School_Management_System/CLAUDE.md:80-87` | 42P17 전면 장애 또는 셀프 상승 | DEFINER 헬퍼 + 역할 테이블 쓰기 차단 |
| `FOR ALL` 정책 | 같은 파일 `:83`, `:100`, `:117` | 의도치 않은 쓰기 허용 | 연산별 정책 + `with check` |
| 브라우저 anon key 직접 update(상태, 가용, 검사값) | `Hospital/src/app/(dashboard)/queue/queue-client.tsx:35-37`, `lab/lab-client.tsx:95-100` | 임의 레코드 변조 | RPC + guard 트리거 |
| 읽기-계산-쓰기 재고 차감 | `ERP-Wesite/app/actions/sales.ts:20-43` | 동시성 손실, 음수 재고 | 조건부 UPDATE RPC |
| 가짜 판매 상태, 하드코딩 KPI | `ERP-Wesite/components/sales/SalesClient.tsx:174-175`, `Hospital/src/app/(dashboard)/dashboard/page.tsx:69-71` | 장애를 mock으로 숨김(`SECURITY_BASELINE.md` 11장) | 실데이터 RPC, 빈 상태 표시 |
| UTC 날짜 문자열로 "오늘" 계산 | `toISOString().split("T")[0]` 3앱 공통 | KST 00~09시 누락 | `kstDayRange`, SQL KST 경계 |
| 루트 middleware(미로드) | `School_Management_System/middleware.ts` | 가드 0 | `src/proxy.ts` + 빌드 확인 |
| 빈 값 0 대체 저장 | `Hospital/src/app/(dashboard)/lab/lab-client.tsx:66` | 거짓 검사값 | 숫자 필수 검증(HM004) |
| 실 URL·키 화면 노출 | `ERP-Wesite/components/settings/SettingsClient.tsx:232-241` | 정보 노출 | 표시 금지 |
| 실키가 든 `.env` 커밋 위험, `.gitignore` 삭제 | `docs/reviews/School_Management_System.md:50` | 키 유출 | 루트 `.gitignore`, `.env.example`, 키 재발급 |
| `as any` 캐스팅 | `docs/reviews/Hospital.md:67` | 타입 우회 | 생성 타입 |

## 5. 아카이브 절차

| 단계 | 작업 |
|---|---|
| 1 | 모노레포에 `apps/erp`, `apps/hms`, `apps/sms` 이식 완료 후 원본 3개를 `archive/ERP-Wesite`, `archive/Hospital`, `archive/School_Management_System`으로 이동(읽기 전용, 빌드 대상 제외) |
| 2 | School은 이동 전에 nested 저장소 HEAD `3c19d1e`를 기준으로 보관(작업 트리 변경분은 별도 패치 파일로 보존). 작업 트리 삭제가 의도였는지 원작성자 확인 |
| 3 | nested `.git`(Hospital, School)과 ERP `ERP_Website` gitlink 제거, 상위 저장소 하나로 추적 |
| 4 | 키 재발급: 세 앱의 `.env.local`에 있던 Supabase anon key, Hospital `OVERRIDE_PASSWORD`는 폐기하고 새 프로젝트 키를 발급 |
| 5 | `.pen` 디자인 파일은 `archive/design/`로 이동, 중복 사본 정리 |
