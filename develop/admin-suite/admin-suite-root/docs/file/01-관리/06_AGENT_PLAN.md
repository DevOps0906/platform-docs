# 06 에이전트 작업 계획: Admin Suite

작업 ID 접두사: `ADM`(admin-suite 공통. 앱별 SQLSTATE 접두사 ER/SM/HM과 별개로 제품 단위 하나를 쓴다, 제안).

2026-10-13 개정: AI 계층·음성·디자인 시스템(확정 결정 13~17, `docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 4장) 작업 17개(ADM-06-041~057)를 뒤에 붙였다. 3D 히어로 작업은 없다(03장 4.5절). 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 001·002·003(AI 기본값 수용 기준), 009(디자인 시스템 2단계 선행), 014~019·022~027·029~032(화면 작업은 044 뒤), 020·028·033(토큰 파일 소유가 042로 이동, 위젯 마운트), 035·038·039·040(AI·hms 격리·린트·로그인 화면)이다.

2026-10-14 개정: 확정 결정 22(`docs/reference/00_MERGE_ANALYSIS.md:30`, `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`)로 ADM-06-007의 범위에 인증 Stage A(Mock 로그인, 시드, `finishLogin`)를 더하고 인증 단계 작업 3개(ADM-06-058 Stage B, 059 C1 카카오, 060 C2 네이버, 8절)를 붙였다. 범위·수용 기준이 바뀐 기존 작업은 014·022·029(로그인 화면 A 구성, 이메일 가입 폼·초대 메일 화면은 058로), 035(Mock 페르소나 storageState), 038(`.env.example`), 039(인증 금지 검사)다. 059·060은 계획에 넣어 두고 01장 D-24가 "도입"일 때만 실행한다("도입하지 않음"이면 취소, P2 선택). 작업 수 60개(모델 작업 59)는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. AI·음성·디자인 시스템이 MVP 필수가 되면서 늘어난 것이며 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 아래 표의 디렉토리만 만진다. 두 작업이 같은 파일을 만지지 않는다 |
| admin-kit 먼저 | 앱 작업은 W1(admin-kit) 산출물의 공개 API만 import한다. admin-kit 수정이 필요하면 해당 admin-kit 작업 소유자에게 요청 |
| SQL 정본 | 모듈러 조각 2개와 hms 모놀리스는 Fable 작업만 수정. erp/sms 모놀리스 도메인 파일은 변환 스크립트(ADM-06-004)만 생성 |
| 앱 내부 분할 | `apps/<app>/src/app/(app)/<화면>/`과 `apps/<app>/src/server/<도메인>.ts`를 같은 작업이 소유. 공통 `apps/<app>/src/access.ts`, `src/theme/`, `src/proxy.ts`는 테마/내비 작업이 소유 |
| 테스트 | `tests/rls/`, `tests/db/`, `tests/e2e/<app>/`, `tests/e2e/billing/`은 테스트 작업만 |
| AI 서비스 경계 | `apps/api/` 기반(설치·설정·토큰 검증·라우터 연동)은 ADM-06-045. admin 확장은 하위 경로별로 나눈다: `app/ai/products/admin/knowledge.py` 049, `wiki_config.py` 050, `access.py` 045, `app/ai/graphs/admin_assistant.py`·`app/ai/compliance/admin.py` 051, `app/ai/tools/admin/` 048 |
| admin-kit AI 경계 | `packages/admin-kit/src/ai/`는 하위 경로별로 나눈다: `gateway/` 046, `collections.json`·`knowledge/server/` 049, `knowledge/ui/`·`wiki/` 050, `rules/` 051, `chat/` 052, `voice/` 053. 앱 `src/app/api/ai/`는 046(erp, sms)·047(hms)이 소유하고 `knowledge/`는 049, `wiki/`는 050이 소유한다. hms 음성은 054 |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(R-6~R-11) |
| hms 격리 소유 | hms 전용 서버 정의 `infra/hms-ai/`는 055, hms 직접 경로 047, hms 음성 054, 격리 회귀 057. 이 경로에서 공용 제공자·Dify·ElevenLabs를 import하는 코드를 만들지 않는다 |
| 사람 작업 | ADM-06-043(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 앱 화면 작업은 ADM-06-044(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:48`). 토큰 파일 `apps/<app>/src/theme/tokens.css`는 042 소유이고 020/028/033은 나머지 theme 파일만 소유한다 |
| SQL 정본 | AI 기본값(모듈러 조각 7절, 모놀리스 seed)도 위 SQL 정본 규칙을 따른다. 수정은 Fable 작업만 |
| 인증 단계 경계(2026-10-14) | `AUTH_MODE`·`AUTH_PROVIDERS`를 읽는 코드는 `packages/admin-kit/src/auth/`와 앱의 `api/dev/login/`, `auth/callback/`, `(auth)/`에만 둔다. 하위 경로 소유는 8.5절(007 Stage A, 058 B, 059 C1, 060 C2). 단계 전환은 사람이 G1·G2를 판정한 뒤(8.2절) |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ADM-06-001 | erp/sms 모듈러 조각 확정·적용(로컬 Supabase), config schemas 등록 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql` | 없음 | P0 | M | Fable | 체커 OK, 모듈러 스모크 92항목 통과, `supabase db reset` 성공. AI 기본값(조각 7절: 라우팅 erp 8행·sms 8행, 플랜 AI 키, `ai-docs` 버킷, 체인 검사)이 체커 OK, 2회 적용 OK | ERP 리뷰 5장 #1,#3,#8,#9, School 5장 #3, 05장 7절 |
| ADM-06-002 | hms 모놀리스 도메인 SQL 확정(의료정보 보호) | `D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/hms/` | 없음 | P0 | L | Fable | 체커 OK, hms 스모크 52항목 통과, 민감 테이블 SELECT GRANT 0. hms AI 기본값(seed: 라우팅 7행 + `hms-%` 체인 검사 + contract 플랜 AI 키 + 버킷)이 체커 OK, 모든 기능이 `hms-*`로만 해석 | Hospital 5장 #1,#3,#9,#12, HMS-F-014 |
| ADM-06-003 | erp/sms 모놀리스 lite·seed 검증 | `D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/erp/seed.sql`, `sms/seed.sql`, 각 `0001_core_lite.sql` | ADM-06-001 | P0 | S | Fable | 체커 OK, 스모크 erp 21, sms 19 통과. seed 반복 적용 후 라우팅 행 erp 8·sms 8, 플랜 features에 AI 키 5개 | 05장 8절 |
| ADM-06-004 | 조각 → 모놀리스 변환 스크립트 + CI diff 검사 | `tools/admin-suite/to-monolith.py`, `.github/workflows/sql-check.yml` | ADM-06-001 | P1 | S | Haiku | 스크립트 재실행 결과와 커밋된 `0002_<app>_domain.sql` diff 0 | `DB_CONVENTIONS.md` 12장 제안 |
| ADM-06-005 | 모노레포 골격 + `db:types` | `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `scripts/db-types.mjs`, `packages/admin-kit/package.json`, 앱별 로컬 프로젝트 `supabase/<app>/config.toml`(Stage A 설정: 외부 제공자 모두 끔, 2026-10-14. `[auth.external.*]`·`additional_redirect_urls`는 058·059가 이어 받음) | 없음 | P0 | S | Haiku | `pnpm db:types --app erp` 가 타입 생성, `pnpm -r build` 통과 | ERP 5장 #13, Hospital 5장 #5, School 5장 #7 |
| ADM-06-006 | admin-kit Supabase 래퍼와 세션 | `packages/admin-kit/src/supabase/` | ADM-06-005 | P0 | S | Opus | 앱이 `createAdminClients(appId)`만으로 3종 클라이언트와 `getSession`을 얻음 | KIT-F-001 |
| ADM-06-007 | admin-kit 가드 + 인증 Stage A(2026-10-14 범위 변경, 8절): `createAdminProxy`, `requireRole`, `defineAccess`, 인증 단계 모듈(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`의 기관 조직 분기, 개발용 로그인 핸들러 팩토리, 개발용 패널·`MOCK AUTH · 로컬 전용` 배지), 앱 3개의 `/api/dev/login` re-export, 시드 스크립트와 앱 훅 3개 | `packages/admin-kit/src/auth/`(`callback/`, `providers/`, `terms/`, `login-methods/` 하위 제외: 058·059·060 소유), `apps/erp/src/app/api/dev/login/`, `apps/sms/src/app/api/dev/login/`, `apps/hms/src/app/api/dev/login/`, `scripts/dev/`. 개발용 패널의 로그인 화면 장착은 014·022·029, 배지의 레이아웃 장착은 020·028·033, `package.json` 스크립트 `db:seed-users`는 005에 1줄 요청 | ADM-06-006 | P0 | M | Fable | 프로필 없음 → 로그아웃, pending → /pending, 매트릭스 밖 → 403(RSC 페이로드 없음), 역할 기본값 없음. Stage A(`AUTH_ROADMAP.md` 2장): `node scripts/dev/seed-users.mjs --app erp`(sms, hms 각각) 2회 실행해도 사용자 수 같음, 05장 10절 페르소나가 표의 기대 결과대로(`viewer` → `/no-access`, `outsider`의 기관 A org id RPC 42501, erp `join_requested` 도메인 SELECT 0행), Supabase 호스트가 루프백이 아니면 시드 즉시 종료, `isMockAuthAllowed()` 거짓(`AUTH_MODE=live`, 원격 호스트, `VERCEL_ENV` 존재)이면 `/api/dev/login` 404·패널 미렌더, `AUTH_MODE=mock`인데 판정이 거짓이면 앱 기동 실패, `AUTH_MODE=mock VERCEL_ENV=production`으로 `pnpm --filter <app> build`(3앱) 실패(`AUTH_ROADMAP.md` 2.4절), `finishLogin`이 활성 기관 멤버십이 있으면 `session_context(app, 기관 org)`로 분기하고 erp 활성 구성원에게 `bootstrap_app_for_org` 호출 0(04장 8.2절 3번), `next=//evil.com` → 역할 홈. 쿠키·localStorage에 역할·플랜 쓰기 0 | ERP 5장 #4,#5, Hospital 5장 #2,#14, School 5장 #2,#4, KIT-F-002~004, `AUTH_ROADMAP.md` 2장·3.1절, 05장 10절 |
| ADM-06-008 | KST 날짜 유틸 + 단위 테스트 | `packages/admin-kit/src/date/` | ADM-06-005 | P0 | S | Sonnet | 00:30 KST, 23:59 KST, 월말 경계 테스트 12개 통과 | ERP 5장 #7, Hospital 5장 #4, School 5장 #6 |
| ADM-06-009 | admin-kit UI(AppShell 햄버거, DataTable, FormModal, ConfirmDialog, Toast, KpiCard, Chart) | `packages/admin-kit/src/ui/` | ADM-06-005, ADM-06-042 | P0 | L | Sonnet | 375/768/1024/1440px 스크린샷 가로 스크롤 0, 로그아웃 버튼, axe 위반 0. AppShell 헤더에 어시스턴트 버튼 자리(ADM-06-052가 채움)와 `tokens.css` 변수만 사용(hex 0) | ERP 5장 #6, Hospital 5장 #13, School 5장 #4,#10, KIT-F-008~009 |
| ADM-06-010 | `useRealtimeTable` | `packages/admin-kit/src/realtime/` | ADM-06-006 | P1 | S | Opus | 한 화면 채널 1개, payload 부분 갱신, 언마운트 해제 테스트 | ERP 5장 #8, Hospital 5장 #11, School 5장 #9 |
| ADM-06-011 | 가입 승인/초대 공통 흐름(화면 조각 + 서버 함수, Auth Admin 초대) | `packages/admin-kit/src/members/` | ADM-06-007 | P0 | M | Opus | 앱이 RPC 이름을 주입해 승인제·초대제 모두 동작, 본인 초대 차단 | KIT-F-005~007, School 5장 #8 |
| ADM-06-012 | 감사 로그 뷰어 | `packages/admin-kit/src/audit/` | ADM-06-009 | P1 | S | Sonnet | owner/admin만 표시, 기간·action 필터 | KIT-F-012 |
| ADM-06-013 | 플랜/구독 화면과 Route Handler(공용 toss 모듈 호출) | `packages/admin-kit/src/billing/` | ADM-06-007 | P2 | M | Fable | standard 구독 confirm 후 엔타이틀먼트 standard, PM001 시 `fail_payment_order` 호출 후 취소·알림 | 01장 4절 |
| ADM-06-014 | ERP 로그인 화면(A 구성)·가입 코드 대기 화면(승인제). 이메일 가입 폼·비밀번호 재설정은 058(2026-10-14) | `apps/erp/src/app/(auth)/`(A 구성, 058이 이어 받음), `apps/erp/src/app/pending/` | ADM-06-007, ADM-06-011, ADM-06-044 | P0 | M | Opus | 로그인 화면이 admin-kit 개발용 패널을 장착(Mock 허용 판정 거짓이면 미렌더), Mock `pending` → 가입 코드 입력 → `join_requested` 상태, `join_rejected` 거절 사유 표시, owner 승인 후 accept까지 E2E 통과(Mock 페르소나). `signUp`의 `signup_app`·`full_name`은 058 수용 기준 | ERP 5장 #2,#4, 03장 7.1절 |
| ADM-06-015 | ERP 재고 화면과 서버 | `apps/erp/src/app/(app)/inventory/`, `apps/erp/src/server/inventory.ts`, `apps/erp/src/server/images.ts` | ADM-06-001, ADM-06-009, ADM-06-044 | P0 | M | Opus | 감소 조정, ER001 메시지, 위험 재고 `is_low_stock` 필터, 이미지 경로 강제 | ERP 5장 #3,#8,#13, ERP-F-001~003,014 |
| ADM-06-016 | ERP 판매 화면과 서버 | `apps/erp/src/app/(app)/sales/`, `apps/erp/src/server/sales.ts` | ADM-06-001, ADM-06-009, ADM-06-044 | P0 | M | Opus | 상태 탭, 취소 사유, 재시도 멱등 | ERP 5장 #3,#9, ERP-F-004~005 |
| ADM-06-017 | ERP 대시보드 + 판매 추이 | `apps/erp/src/app/(app)/dashboard/` | ADM-06-008, ADM-06-010, ADM-06-044 | P1 | M | Opus | `dashboard_metrics` 1회 호출, 전체 행 조회 0, 실시간 최근 변동 | ERP 5장 #7,#10, ERP-F-006~008 |
| ADM-06-018 | ERP 인사·부서·가입 요청 | `apps/erp/src/app/(app)/hr/`, `apps/erp/src/app/(app)/me/`, `apps/erp/src/server/hr.ts` | ADM-06-011, ADM-06-044 | P1 | M | Opus | 부서 CRUD, 권한 모달(자기 자신 비활성), 가입 코드 재발급 | ERP 5장 #11, ERP-F-009~012 |
| ADM-06-019 | ERP 설정 | `apps/erp/src/app/(app)/settings/` | ADM-06-018, ADM-06-044 | P2 | S | Sonnet | 저장 유지, URL/키 표시 0 | ERP 5장 #12, ERP-F-013 |
| ADM-06-020 | ERP 테마·내비·proxy·access 매트릭스 | `apps/erp/src/theme/`(`tokens.css` 제외), `apps/erp/src/access.ts`, `apps/erp/src/proxy.ts`, `apps/erp/src/app/layout.tsx`, `apps/erp/src/app/no-access/`(2026-10-14 소유 명시) | ADM-06-007, ADM-06-009, ADM-06-044 | P1 | S | Sonnet | 중복 라우트 0, 메뉴가 역할별로만 보임. 채팅 위젯·어시스턴트 버튼 마운트(ADM-06-052 요청 1줄). `tokens.css`는 ADM-06-042 소유 | ERP 5장 #5,#6 |
| ADM-06-021 | HMS 의료정보 서버 계층(AES-256-GCM, 키 버전, 접근 사유) | `apps/hms/src/server/phi/` | ADM-06-002 | P0 | M | Fable | 키 누락 시 기동 실패, 복호화는 서버에서만, 암호문 클라이언트 전송 0 | Hospital 5장 #3,#5, 01장 6.2절 |
| ADM-06-022 | HMS 로그인 화면(A 구성)·초대 수락·직원 관리. 초대 메일 비밀번호 설정은 058(2026-10-14) | `apps/hms/src/app/(auth)/`(A 구성, 058이 이어 받음), `apps/hms/src/app/invite/`(초대 수락, 2026-10-14 소유 명시), `apps/hms/src/app/(app)/staff/`, `apps/hms/src/server/staff.ts` | ADM-06-007, ADM-06-011, ADM-06-021, ADM-06-044 | P0 | M | Opus | OVERRIDE/verify-admin 없음, 초대·역할 변경, 자기 변경 차단. 로그인 화면이 개발용 패널을 장착, Mock `invited` 페르소나가 수락 후 `my_role` 확정 | Hospital 5장 #2, HMS-F-001 |
| ADM-06-023 | HMS 환자 목록/등록/상세/360 차트 | `apps/hms/src/app/(app)/patients/`, `apps/hms/src/server/patients.ts` | ADM-06-021, ADM-06-044 | P0 | L | Opus | 동의 필수, 성별 실데이터, 타임라인 병합, 접근 기록 1행/열람 | Hospital 5장 #6,#9, HMS-F-002~004,008 |
| ADM-06-024 | HMS 예약 캘린더 | `apps/hms/src/app/(app)/calendar/`, `apps/hms/src/server/appointments.ts` | ADM-06-023, ADM-06-044 | P1 | M | Opus | 주말 포함 주별 뷰, 빈 슬롯 예약, 범위 조회, visit_type 범례 | Hospital 5장 #7,#12, HMS-F-005 |
| ADM-06-025 | HMS 실시간 대기열 | `apps/hms/src/app/(app)/queue/` | ADM-06-010, ADM-06-024, ADM-06-044 | P0 | M | Opus | 채널 1개, KST 당일 대기번호, 담당의만 진료 시작 | Hospital 5장 #3,#4,#11, HMS-F-006~007 |
| ADM-06-026 | HMS 검사 | `apps/hms/src/app/(app)/lab/`, `apps/hms/src/server/lab.ts` | ADM-06-023, ADM-06-044 | P1 | M | Opus | 빈 값 저장 불가, 저장 후 목록 갱신, 승인(입력자 제외), 의뢰 | Hospital 5장 #10, HMS-F-009~011 |
| ADM-06-027 | HMS 수납·대시보드·접근 기록 화면 | `apps/hms/src/app/(app)/billing/`, `apps/hms/src/app/(app)/dashboard/`, `apps/hms/src/app/(app)/settings/access-log/` | ADM-06-025, ADM-06-044 | P1 | M | Opus | 하드코딩 0, 취소/노쇼 분리, 접근 기록 필터·CSV | Hospital 5장 #4,#8, HMS-F-012~014 |
| ADM-06-028 | HMS 테마·내비·proxy·access | `apps/hms/src/theme/`(`tokens.css` 제외), `apps/hms/src/access.ts`, `apps/hms/src/proxy.ts`, `apps/hms/src/app/layout.tsx`, `apps/hms/src/app/no-access/`, `apps/hms/src/app/(app)/settings/account/`(2026-10-14 소유 명시) | ADM-06-007, ADM-06-009, ADM-06-044 | P1 | S | Sonnet | 메뉴 자물쇠 노출 0, 대비 4.5:1. 채팅 위젯 마운트(ADM-06-052 요청 1줄). `tokens.css`는 ADM-06-042 소유 | Hospital 5장 #14(라벨 중복 제거) |
| ADM-06-029 | SMS HEAD 자산 이식 + 로그인 화면(A 구성)·초대 수락. 초대 메일 비밀번호 설정은 058(2026-10-14) | `apps/sms/src/app/(auth)/`(A 구성, 058이 이어 받음), `apps/sms/src/app/invite/` | ADM-06-007, ADM-06-011, ADM-06-044 | P0 | M | Opus | 07장 2절 목록 이식 완료(인증 관련은 07장 6절 복사 금지), Mock `student` 첫 로그인 → `/student/dashboard`, Mock `invited` 수락 → `has_access=true` | School 5장 #1,#8 |
| ADM-06-030 | SMS 학급·과목·구성원 관리 | `apps/sms/src/app/(app)/admin/classes/`, `.../subjects/`, `.../members/`, `apps/sms/src/server/roster.ts` | ADM-06-029, ADM-06-044 | P0 | M | Opus | zod 검증, `requireRole('admin')`, 14세 미만 동의 체크 | School 5장 #5, SMS-F-001~004 |
| ADM-06-031 | SMS 출석 체크 보드 | `apps/sms/src/app/(app)/admin/attendance/`, `apps/sms/src/server/attendance.ts` | ADM-06-030, ADM-06-010, ADM-06-044 | P0 | M | Opus | 일괄 저장 200건, SM002 메시지, 학급 필터 구독 | SMS-F-005~007 |
| ADM-06-032 | SMS 관리자/학생 대시보드 + 추이 + 알림 | `apps/sms/src/app/(app)/admin/dashboard/`, `.../admin/trend/`, `apps/sms/src/app/(app)/student/` | ADM-06-031, ADM-06-008, ADM-06-044 | P1 | M | Opus | 출석률 정의 일치(100% 초과 0), payload 부분 갱신, 학생 5초 알림 | School 5장 #6,#9,#12, SMS-F-008~011 |
| ADM-06-033 | SMS 테마·내비(lucide)·proxy·access | `apps/sms/src/theme/`(`tokens.css` 제외), `apps/sms/src/access.ts`, `apps/sms/src/proxy.ts`, `apps/sms/src/app/layout.tsx`, `apps/sms/src/app/no-access/`, `apps/sms/src/app/(app)/settings/account/`(2026-10-14 소유 명시) | ADM-06-007, ADM-06-009, ADM-06-044 | P2 | S | Sonnet | 이모지 0, 빌드 로그에 Proxy 항목. student 역할 화면에는 어시스턴트 버튼 0. `tokens.css`는 ADM-06-042 소유 | School 5장 #10 |
| ADM-06-034 | RLS/권한 회귀 테스트(모듈러 + 모놀리스 3종) | `tests/rls/` | ADM-06-001, ADM-06-002, ADM-06-003 | P0 | M | Fable | `SECURITY_BASELINE.md` 15장 + `DB_CONVENTIONS.md` 13.3 + 이 제품 항목, CI에서 실패 0 | `SECURITY_BASELINE.md` 0장, 05장 7절 |
| ADM-06-035 | 역할·경로 E2E(Playwright) | `tests/e2e/erp/`, `tests/e2e/hms/`, `tests/e2e/sms/`, `tests/e2e/global-setup.ts`, `playwright.config.ts`(2026-10-14, 페르소나 storageState) | ADM-06-020, ADM-06-028, ADM-06-033, ADM-06-046, ADM-06-052 | P0 | M | Opus | 역할 x 경로 매트릭스 전 조합 기대 상태 코드, 비로그인 리다이렉트, 사이드바 링크 404 0. AI 질문 1턴(목 제공자) 3앱 통과, SMS student의 `/api/ai/*` 403, 한도 초과 시 입력 비활성. 인증(2026-10-14): Playwright `globalSetup`이 05장 10절 페르소나마다 `/api/dev/login`으로 `storageState`를 저장해 로컬에서 먼저 녹색(G1 근거, 8.2절), 058 완료 후 B 구성 스테이징에서 비로그인·콜백 오류 경로 재실행 | 02장 6절, School 리뷰 #1,#2 |
| ADM-06-036 | 결제 E2E(Toss 테스트 키) | `tests/e2e/billing/` | ADM-06-013 | P1 | M | Opus | standard 구독 성공, 금액 위조 PM001, 웹훅 서명 실패 401 | `DOC_TEMPLATE.md` 작업 규칙 |
| ADM-06-037 | ERP 동시성·멱등 DB 테스트 | `tests/db/erp/` | ADM-06-001 | P0 | S | Opus | 동시 판매 50건 후 음수 0, 수량 = 이동 합, 같은 request_id 1행 | ERP 5장 #3 |
| ADM-06-038 | 저장소 위생: .gitignore, .env.example, README, 원본 archive, 금지 env 검사 | `.gitignore`, `.env.example`, `apps/*/README.md`, `archive/README.md`, `packages/admin-kit/src/env/` | ADM-06-005 | P0 | S | Haiku | `.env*` 무시, `OVERRIDE_PASSWORD` 존재 시 기동 실패, nested git 0. `.env.example`에 `AUTH_MODE=mock`, `AUTH_PROVIDERS`, `DEV_SEED_PASSWORD`(값 비움) 행(2026-10-14, 02장 9.3절). hms 배포에서 금지 AI 변수(`DIFY_*`, 상용 키, 공용 AI URL, 02장 5.5절) 하나라도 있으면 기동 실패 | ERP 5장 #14, Hospital 5장 #14, School 5장 #11 |
| ADM-06-039 | 린트/TS 설정(`eslint .`, Next 16 규칙, no-explicit-any) | `eslint.config.mjs`, `tsconfig.base.json` | ADM-06-005 | P1 | S | Haiku | `pnpm lint` 오류 0, `next lint` 사용 0. `bg-[#...]` 같은 임의 hex, `tailwind.config.js`, `@tailwind base` v3 문법, `apps/hms`의 `elevenlabs`·Dify import, 3D 라이브러리(three.js 계열) import 금지 규칙 포함. 인증 금지 검사(2026-10-14, `AUTH_ROADMAP.md` 2.4절): 쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, admin-kit `src/auth/`와 앱의 `api/dev/login/`·`auth/callback/`·`(auth)/` 밖의 `AUTH_MODE`·`AUTH_PROVIDERS` 참조 0 | ERP 5장 #14, School 5장 #11 |
| ADM-06-040 | 디자인 MASTER.md와 로그인 화면 | `design-system/admin-suite/` | ADM-06-044 | P1 | S | Sonnet | 03장 4절 토큰 반영, 7단계 체크리스트 통과. 로그인 화면에 3D 의존성 0, `prefers-reduced-motion`에서 모션 0(03장 4.5절) | 03장 4절 |
| ADM-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(주 Primer, 보조 Atlassian, AI 채팅 Astryx 확인), 가져올 것과 안 가져올 것, 3앱 테마 방향 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안(01장 D-18) 기록. 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/file/03-설계/디자인/REFERENCES.md:163` admin-suite 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| ADM-06-042 | 디자인 시스템 2단계: Tailwind CSS v4 토큰(`@theme`, 라이트/다크) 3앱, 기본 컴포넌트·배리언트, 앱별 미리보기 `/dev/components` | `packages/admin-kit/src/theme/`, `packages/admin-kit/src/ui/primitives/`, `apps/erp/src/theme/tokens.css`, `apps/hms/src/theme/tokens.css`, `apps/sms/src/theme/tokens.css`, `apps/erp/src/app/dev/components/`, `apps/hms/src/app/dev/components/`, `apps/sms/src/app/dev/components/` | ADM-06-005, ADM-06-041 | P0 | L | Sonnet | 03장 4.3절 토큰만 사용(hex 하드코딩 0), 03장 3.2절 기본 컴포넌트 전부 앱별 라이트/다크 미리보기, `tailwind.config.js`·v3 문법 0, Tailwind 4.x 고정, `COMPONENTS.md` 배리언트 표 초안, 대비 4.5:1(HMS 다크 #E2E8F0 / #0F172A 포함), 컴팩트(32px)/기본(40px) 밀도 토큰 | DESIGN_PRINCIPLES 3~5단계, DESIGN_SYSTEM 4장 2단계 |
| ADM-06-043 | 디자인 시스템 3단계: 사람 비주얼 검토(앱 3개 라이트/다크, 상태 6종, 크기 배리언트). 사람이 수행하는 작업 | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | ADM-06-042 | P0 | M | 사람(보조 Sonnet) | 03장 3.2절 기본 컴포넌트 전부의 앱별 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| ADM-06-044 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | ADM-06-043 | P0 | S | Opus | 문서 토큰 값과 3앱 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| ADM-06-045 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, admin 설정(앱 그룹 `api-shared`(erp, sms)·`api-hms`), JWKS 검증, 라우터·국외 동의 필터 연동, 역할 확인 허용 목록 모듈 | `apps/api/`(`app/core`, `app/ai/llm`, `app/ai/rag`의 설치·설정, `app/ai/products/admin/access.py`, `tests/platform/`). 049, 050, 051이 소유한 하위 경로는 제외 | ADM-06-001, ADM-06-002 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 컬렉션 요청 42501, 미동의 erp·sms 조직 라우팅에 상용 0, `dify.aux` 상용 0, hms 배포에서 금지 변수(02장 5.5절) 주입 시 기동 실패, 역할 조회가 허용 목록 테이블(02장 2절) 밖을 읽지 않음 | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| ADM-06-046 | AI 게이트(erp, sms): 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), EdDSA 서명 토큰, 마스킹, 하루 질문 한도, 국외 이전 동의 설정 화면·API | `packages/admin-kit/src/ai/gateway/`, `apps/erp/src/app/api/ai/`, `apps/sms/src/app/api/ai/`(`knowledge/`, `wiki/` 하위 제외), `apps/erp/src/app/(app)/settings/ai/`, `apps/sms/src/app/(app)/settings/ai/`, `apps/erp/src/server/ai/`, `apps/sms/src/server/ai/` | ADM-06-007, ADM-06-044, ADM-06-045 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `requestId` 재전송 시 한도 1회만 차감, 대화 주인이 아니면 404, Dify 차단 시 `/tools/answer-direct`로 응답, 하루 한도 초과 429, student 403, 동의 시 `ai_org_settings` 고지문 버전 일치, 크레딧 RPC 호출 0 | 01장 KIT-F-015, 018, 04장 1절 |
| ADM-06-047 | HMS AI 게이트(전용 직접 경로): Next.js → FastAPI 직접, 환자 식별정보 입력 차단, 금지 변수 기동 검사, Dify·상용 코드 경로 제외 | `apps/hms/src/app/api/ai/`(`knowledge/`, `wiki/` 하위 제외), `apps/hms/src/server/ai/`(`voice.ts` 제외) | ADM-06-007, ADM-06-045 | P0 | M | Fable | 04장 6.3절 계약. 주민등록번호·전화번호·차트번호 형식 입력 시 422이고 FastAPI 전송 0, 응답 `provider`가 `hms-%`가 아니면 폐기, `DIFY_*`·상용 키·공용 URL 환경변수 존재 시 기동 실패, `apps/hms` 번들에 Dify·ElevenLabs·상용 SDK import 0 | 01장 HMS-F-015, 017, 사용자 결정 2026-10-13 |
| ADM-06-048 | Dify 앱 `erp-assistant`, `sms-assistant`와 `/tools/answer` 연동(대화 매핑 검증, 응답 형식) | `infra/dify/`, `apps/api/app/ai/tools/admin/` | ADM-06-046, ADM-06-049 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 앱별 내부 키가 서로 통하지 않음(erp 키로 sms 대화 403), 답변 출처 1개 이상 또는 `no_source`, DSL에 키 0 | 04장 6.2절 |
| ADM-06-049 | RAG 색인: 역할별 컬렉션 생성, 문서 업로드 검증(형식·크기·개인정보/환자 정보 탐지), `ai-docs` 저장, 색인 작업, 역할 → 컬렉션 매핑 `collections.json` | `apps/api/app/ai/products/admin/knowledge.py`, `apps/api/tests/admin/retrieval/`, `packages/admin-kit/src/ai/collections.json`, `packages/admin-kit/src/ai/knowledge/server/`, `apps/erp/src/app/api/ai/knowledge/`, `apps/sms/src/app/api/ai/knowledge/`, `apps/hms/src/app/api/ai/knowledge/` | ADM-06-001, ADM-06-002, ADM-06-045 | P0 | M | Opus | 다른 조직 컬렉션 요청 42501, 주민등록번호·전화·이메일·계좌 형식 문서 422(hms는 차트번호 형식 포함), 같은 `content_hash` 409, `ai_docs_max` 초과 402, 컬렉션당 임베딩 모델 1종, 모든 역할의 `ai-docs` 객체 직접 다운로드 거부, `collections.json`이 01장 3.7절 표와 일치 | 01장 KIT-F-016, 3.7절 |
| ADM-06-050 | 기관 운영 위키와 지식·위키 관리 화면: 위키 ingest(위키 대상 컬렉션만), 게시·편집·이력·lint, 문서 관리 화면, 위키 열람 | `apps/api/app/ai/products/admin/wiki_config.py`, `packages/admin-kit/src/ai/knowledge/ui/`, `packages/admin-kit/src/ai/wiki/`, `apps/erp/src/app/(app)/settings/knowledge/`, `.../settings/wiki/`, `.../wiki/`, `apps/sms/src/app/(app)/settings/knowledge/`, `.../settings/wiki/`, `.../wiki/`, `apps/hms/src/app/(app)/settings/knowledge/`, `.../settings/wiki/`, `.../wiki/`, `apps/erp/src/app/api/ai/wiki/`, `apps/sms/src/app/api/ai/wiki/`, `apps/hms/src/app/api/ai/wiki/` | ADM-06-044, ADM-06-049 | P0 | M | Opus | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 표시가 붙은 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, "위키 대상 아님" 컬렉션 문서 ingest 거부, lint 결과 화면, 모든 쓰기 감사 1행, draft는 관리자 외 0명 노출 | 01장 KIT-F-016, 017, LLM_WIKI 3장 |
| ADM-06-051 | LangGraph `admin.assistant`(permission → retrieve → answer → compliance), 체크포인트, 실행 기록(본문 금지), 규칙 파일, 앱별 compliance(hms 임상 규칙 포함) | `apps/api/app/ai/graphs/admin_assistant.py`, `apps/api/app/ai/compliance/admin.py`, `packages/admin-kit/src/ai/rules/`, `apps/api/tests/admin/graph/` | ADM-06-045, ADM-06-049 | P0 | L | Opus | 질문 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`(본문 필드에 질문 문자열 0), 역할이 허용하지 않는 컬렉션 청크가 답변 근거에 0건, 허용 컬렉션 0이면 `AI_NO_PERMISSION`, 걸린 문장만 1회 재작성·2회 실패 시 안내 문구로 대체, hms는 진단·처방·용량 지시 문형 0, 업무·환자 테이블 쿼리 0 | 01장 KIT-F-015, HMS-F-015, 02장 5.2·5.3절 |
| ADM-06-052 | 채팅 위젯: 패널, 대화 목록, 스트리밍, 출처 칩, 한도 표시, 마이크 버튼·녹음 표시·변환 텍스트 수정 UI, hms 고정 배너, 접근성 | `packages/admin-kit/src/ai/chat/` | ADM-06-044, ADM-06-046 | P0 | M | Sonnet | 03장 3.1절 구성, 375px 전체 화면 시트, `aria-live`, 403·422·429·503 상태 표시, 대체 표시(erp, sms), hms 고정 배너와 임상 안내 문구, 음성 미지원·권한 거부 시 마이크 버튼 처리. 앱 레이아웃 장착은 020/028/033 파일에 1줄 요청 | 01장 KIT-F-015, 019, 03장 5절 |
| ADM-06-053 | 업무 음성 질의(erp, sms): `/api/voice/*`(consent, sessions, stt, tts), `core-voice` 연동, 오픈소스 우선 체인 | `packages/admin-kit/src/ai/voice/`, `apps/erp/src/app/api/voice/`, `apps/sms/src/app/api/voice/` | ADM-06-046, ADM-06-052 | P0 | M | Opus | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, 미동의 조직은 `oss-voice`만(ElevenLabs 호출 0), TTS 입력은 DB 메시지만, student 403 | 01장 KIT-F-019, ERP-F-016, SMS-F-013 |
| ADM-06-054 | HMS 음성(전용 `hms-voice`): `/api/voice/*`, 변환 텍스트 환자 식별정보 검사, ElevenLabs 코드 경로 제외 | `apps/hms/src/app/api/voice/`, `apps/hms/src/server/ai/voice.ts` | ADM-06-047, ADM-06-052, ADM-06-055 | P0 | M | Opus | STT·TTS 호출 대상이 `HMS_VOICE_BASE_URL`뿐이고 공용·상용 음성 호출 0(네트워크 목 검사), 변환 텍스트에 환자 식별정보 패턴이면 422, 음성 서버 장애 시 대체 없이 `AI_UNAVAILABLE`, `store_audio=false` 100%, 번들에 ElevenLabs SDK 0 | 01장 HMS-F-016, VOICE_ARCHITECTURE 3장 |
| ADM-06-055 | HMS 전용 AI 서버 배포 정의: `api-hms`(FastAPI), `hms-llm`(vLLM), `hms-embed`, `hms-voice`, 병원 전용 네트워크 정책(송신 차단), 헬스체크, 모델 반입 절차 | `infra/hms-ai/` | ADM-06-002, ADM-06-045 | P0 | M | Fable | 외부 인터넷 송신 없이 기동(모델은 사전 반입), `api-hms`가 `hms-*`만 호출, 공용 서버·상용 API 주소를 설정할 수 없음(환경 검사), 헬스체크 실패 시 앱이 `AI_UNAVAILABLE`, `HMS_PHI_KEY_*`가 컨테이너에 전달되지 않음, 병원 간 설정·키 공유 0 | 01장 HMS-F-017, 02장 5.5절, D-12 |
| ADM-06-056 | AI 평가셋: 질의-정답(erp 규정 40, sms 30, hms 가이드라인 30문항, 모두 개인정보 없는 샘플 문서), 권한 경계·금지 문구·범위 밖 질의 | `apps/api/tests/admin/eval/`, `scripts/ai-eval/` | ADM-06-049, ADM-06-051 | P1 | M | Opus | 앱별 재현율@8 0.8 이상(제안), 출처 정확도 95% 이상, 권한 경계 질의 30문항 위반 0, 금지 문구 질의 위반 0, erp·sms는 상용·오픈소스 두 경로, hms는 `hms-llm` 경로로만 실행 | AI_ARCHITECTURE 5장 평가, 01장 KIT-F-015 |
| ADM-06-057 | AI 보안·격리 회귀: 서명 토큰, 대화 매핑, 역할 경계, 컬렉션 접근, 국외 동의, hms 격리(금지 변수, 공용 호출 0, 환자 테이블 쿼리 0, 번들 검사), 코어 RLS 한계 검사, 라우팅 seed 스냅샷 | `apps/api/tests/admin/security/`, `tests/ai/`, `scripts/ai-routing/` | ADM-06-046, ADM-06-047, ADM-06-048, ADM-06-051, ADM-06-053, ADM-06-054 | P0 | M | Fable | `resolve_ai_route` 스냅샷(erp 8, sms 8, hms 7 기능 × 동의 유/무)이 02장 5.1·5.5절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 404, 역할 경계 위반 답변 0, 미동의 조직 상용 호출 0, hms `ai_usage.provider`가 `hms-%` 아닌 행 0과 금지 변수 5종 기동 실패, FastAPI의 환자 테이블 쿼리 0(쿼리 로그 허용 목록), 05장 4.5절 6항목 통과, CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 16장, 05장 4.5절 |

P0 작업과 테스트 대응: SQL(001~003) → 034, 037 / admin-kit 가드·UI(006~009, 011) → 035, 008 단위 테스트 / 앱 P0 화면(014~016, 021~023, 025, 029~031) → 035 / 위생(005, 038) → CI / AI·음성 P0(045~055) → 057, 056 / 디자인 시스템(041~044) → 043(사람 검토).

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 005, 041 | 4 | 없음 | DB 조각·모놀리스 적용(AI 기본값 포함), 모노레포 골격, 디자인 레퍼런스(1단계) |
| W1 | 003, 004, 006, 008, 038, 039, 042, 045 | 8 | W0 | 모놀리스 검증, 변환기, admin-kit 기초, 디자인 시스템 토큰·기본 컴포넌트(2단계), AI 서비스 설치 |
| W1-D | 043 → 044(직렬) | 1 | 042 | 사람 비주얼 검토(3단계), 코드를 정답으로 확정(4단계). 앱 화면 작업의 진입 조건 |
| W2 | 007, 009, 010, 021, 034, 037, 049, 055 | 8 | 006, 001~003, 042, 045 | 가드, admin-kit UI, Realtime, PHI 계층, RLS·동시성 테스트, RAG 색인, hms 전용 AI 서버 정의 |
| W3 | 011, 012, 020, 028, 033, 040, 046, 047, 050, 051 | 10 | 007, 009, 044 | 가입 흐름, 앱 셸 3개, 로그인 화면, AI 게이트(erp·sms, hms), 위키 운영, 그래프 `admin.assistant` |
| W4 | 014, 015, 016, 022, 023, 029, 030, 048, 052, 056 | 10 | W3 | 앱 P0 화면, Dify 앱, 채팅 위젯, AI 평가셋 |
| W5 | 017, 018, 024, 025, 026, 031, 013, 053, 054 | 9 | W4 | 대시보드, 인사, 캘린더, 대기열, 검사, 출석, 결제, 업무 음성(erp·sms), hms 음성 |
| W6 | 058(G1 통과 후 먼저), 019, 027, 032, 035, 036, 057 | 7 | W5. 058은 G1 통과(`[DECISION] G1 통과`) 후 시작하고 035·057의 출시 마무리(스테이징·B 구성 재실행)는 058 완료를 기다린다. G1 근거인 Mock 역할×경로 E2E는 035가 W5 종료 직후 로컬에서 먼저 녹색으로 만든다(8.2절) | Google·이메일·초대 메일 로그인 전환(Stage B), 잔여 화면, E2E, 결제 E2E, AI 보안·격리 회귀. MVP 출시(첫 기관 배포) 조건 |
| W7 | 059(G2 통과 후), 060(G2 통과 후) | 2 | MVP 출시 후, G2 통과(`[DECISION] G2 통과`)와 01장 D-24 "도입". 둘은 병렬 가능 | 카카오 로그인(C1), 네이버 로그인(C2). erp·sms만, hms 제외 |

같은 웨이브 안에서도 선행 작업 열이 우선한다(예: 024 → 025, 030 → 031). 3D 히어로 작업은 없다(03장 4.5절).

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 14 (001, 002, 003, 007, 013, 021, 034, 045, 046, 047, 055, 057, 058, 060) | 23.7% | 29 / 106 = 27.4% |
| Opus | 30 (기존 21 + 044, 048, 049, 050, 051, 053, 054, 056, 059) | 50.8% | 57 / 106 = 53.8% |
| Sonnet | 11 (008, 009, 012, 019, 020, 028, 033, 040, 041, 042, 052) | 18.6% | 16 / 106 = 15.1% |
| Haiku | 4 (004, 005, 038, 039) | 6.8% | 4 / 106 = 3.8% |
| 합계 | 59 | 100% | 106 |

비율은 모델 작업 59개 기준이다(2026-10-14 인증 단계 3개 추가: 058·060 Fable M, 059 Opus S). 사람 작업 1개(ADM-06-043, M)는 비율에서 뺐다. 2026-10-14 이전(56개)은 Fable 21.4%, Opus 51.8%, Sonnet 19.6%, Haiku 7.1%였다. 2026-10-13 이전(40개)은 Fable 17.5%, Opus 52.5%, Sonnet 20.0%, Haiku 10.0%였다. Fable은 AI 보안 경계(서명 토큰 검증 045, 게이트의 한도·동의·토큰 046, hms 직접 경로 047, hms 전용 서버 055, AI 격리 회귀 057)와 인증 세션 발급 경로(Stage A 007, Stage B 058, 네이버 브리지 060)를 맡고, 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 위젯과 디자인 시스템 토큰·컴포넌트는 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

| 리뷰 | 5장 # | 작업 요약 | 흡수 작업 ID |
|---|---|---|---|
| ERP-Wesite | 1 | RLS 재작성(재귀 제거, 역할 상승 차단) | ADM-06-001, ADM-06-034 |
| ERP-Wesite | 2 | handle_new_user + signUp 메타데이터 | ADM-06-014(코어 트리거 사용), ADM-06-058(이메일 가입 폼의 signUp 메타데이터, 2026-10-14) |
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

| ID | 요청 | 대상 | 이유 | 제품의 임시 대응 |
|---|---|---|---|---|
| R-1 | 팀 조직 생성 함수 `core.create_team_organization(p_name, p_owner, p_app_id)` (service_role, 엔타이틀먼트 manual 포함) | `_platform-core` | 지금은 프로비저닝 스크립트가 코어 테이블에 직접 INSERT해야 한다. 함수가 있으면 감사와 검증을 한 곳에서 한다 | 스크립트가 직접 INSERT |
| R-2 | 모놀리스 lite에서 `purge_organization`을 크레딧 절 밖으로 분리 | `_platform-core` | 크레딧 절을 지운 제품(admin-suite 3앱)은 조직 파기 함수가 없다 | 운영 도구 수동 절차 |
| R-3 | `confirm_payment_order` 금액 불일치 시 주문 failed 영속화 | `_platform-core` | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 별도 호출 | 없음 |
| R-4 | 통합 seed의 erp/sms default 플랜 features 갱신 | `_supabase-modular/seed.sql` 담당 | 해결(2026-10-13 코어 반영 완료): 통합 seed가 모놀리스 seed와 일치. 조각은 `on conflict do nothing`이라 seed 값이 그대로 적용된다 | 없음 |
| R-5 | 팀 운영 예외 확인 | 사용자(확정 결정 5) | "1인 1워크스페이스" 운영 원칙과 달리 admin-suite는 고객사 조직에 다수 멤버가 필수다 | 없음(확인 대기) |
| R-6 | ai-gateway에 "크레딧 미사용" 모드: `consume_credits` 없이 한도 판정·원가 기록만 | `packages/ai-gateway` | 이 제품은 크레딧 절을 제거했고(05장 8절) AI도 선차감하지 않는다(01장 4.1절, D-10). 공용 게이트가 선차감을 전제로 한다면 사용할 수 없다 | `packages/admin-kit/src/ai/gateway/`에 자체 구현(ADM-06-046) |
| R-7 | core-voice `VoiceAdapter`에 제공자 허용 목록 옵션과 hms용 "elevenlabs 코드 경로 제외" 빌드 | `packages/core-voice` | hms는 `hms-voice`만 쓰고 ElevenLabs·공용 `oss-voice` 구현을 번들에 넣지 않아야 한다(`VOICE_ARCHITECTURE.md:48`) | 앱 코드에서 어댑터 구성 시 허용 목록 전달 + 린트·번들 검사(ADM-06-039, 057) |
| R-8 | 공용 Dify에 앱 `erp-assistant`, `sms-assistant` 생성, 앱별 내부 키 환경 변수, 로그 보존 30일. hms 앱은 만들지 않는다 | 공용 Dify 운영(`docs/develop/_shared/dify/`) | 공용 인프라는 코어 소유 | 없음. 장애 시 `/tools/answer-direct` |
| R-9 | hms 전용 AI 서버(FastAPI + vLLM + 임베딩 + faster-whisper/TTS) 설치·운영 문서 | `docs/develop/_shared/`(llm, voice의 hms 변형) | 공용 문서는 공용 GPU 서버 기준이다. hms는 병원별 전용 세트와 오프라인 모델 반입이 필요하다 | `infra/hms-ai/`에 제품 문서 작성(ADM-06-055) |
| R-10 | ai-service: (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | `services/ai-service` | Dify 보조 노드 라우팅(`dify.aux`)과 관리자 위키 편집 | (a) Dify에 기능별 모델 이름을 따로 등록 (b) 제품 확장(`wiki_config.py`)에 임시 구현 |
| R-11 | ai-service에 앱 그룹 설정(`ADMIN_AI_APPS`)과 금지 환경변수 기동 검사 공용화 | `services/ai-service` | `api-shared`(erp, sms)와 `api-hms`가 같은 코드로 다른 규칙을 가진다(02장 5.5절) | 제품 확장(`access.py` 옆 설정 모듈)에 구현 |
| R-12 | 통합 `seed.sql`(erp/sms 플랜)에 AI 키 7개(`ai_assistant`, `ai_turns_per_day`, `ai_turns_per_month`, `ai_commercial_turns_per_month`, `ai_voice`, `ai_docs_max`, `ai_wiki`) 반영 | `_supabase-modular/seed.sql` 담당 | seed가 조각보다 나중에 실행되면 조각 7절의 병합 UPDATE가 덮어써질 수 있다 | 서버가 누락 키를 기본값으로 읽는다(01장 4.1절) |
| R-13 | 코어에 jobs 선택 절 복원 허용 또는 AI 색인용 경량 큐 제공 | `_platform-core` | 모놀리스 lite에서 jobs 절을 제거해 AI 색인이 FastAPI 내부 큐에 의존한다(02장 4절). 프로세스 재시작에 약하다 | FastAPI 내부 큐 + `ai_documents.status` 스위퍼 5분 |
| R-14 | **(높음, 차단 수준)** 코어 RLS 개정: `ai_documents`, `wiki_pages`, `wiki_links`, `wiki_revisions`, `ai_runs`, `ai_run_steps`, `ai_collections`의 SELECT를 조직 구성원 전원이 아니라 service_role 전용 또는 앱이 정한 역할로 좁힐 수 있게 한다(예: 앱별 `can_read_ai_object(app, org)` 훅) | `_platform-core`(`0008_core_ai.sql:623-633`, 모놀리스 SECTION 11) | 직원·학생이 PostgREST로 위키 본문과 run을 직접 읽어 역할별 공개 범위를 우회할 수 있다(05장 4.5절). 제품은 core.* 정책을 바꿀 수 없다(`DB_CONVENTIONS.md:238`) | 02장 5.3절 8항의 제품 규칙(run 본문 금지, 위키는 구성원 전원 공개 가능 컬렉션만, 제목 비밀 금지). 반영 전에는 제한 컬렉션 위키를 만들지 않는다(D-20) |

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
| AI·음성 | `pytest apps/api` 통과, ADM-06-057 녹색, 평가셋(ADM-06-056) 앱별 기준 통과, 미동의 조직 상용 호출 0, 질문·답변이 `ai_runs`에 남지 않음 |
| hms 격리 | hms 배포의 금지 변수 5종 기동 실패 테스트, `ai_usage.provider`가 `hms-%` 아닌 행 0, 환자 테이블 AI 쿼리 0, `apps/hms` 번들에 Dify·상용·ElevenLabs 코드 0 |
| 디자인 시스템 | 4단계(ADM-06-044) 완료, `tailwind.config.js`·hex 하드코딩 0, 3앱 `/dev/components` 라이트/다크 스크린샷 |
| 3D | 해당 없음(03장 4.5절). 3D 라이브러리 import 0 |
| 인증 | Stage A: 세 앱 시드 페르소나(05장 10절) 로그인과 Mock 역할×경로 E2E 녹색, 배포 빌드에서 `/api/dev/login` 404. Stage B(ADM-06-058): `AUTH_ROADMAP.md` 5.3절 B-1~B-6(앱별 해석은 8.1절) 통과와 사람 수동 점검표 기록. 단계 분기 코드가 인증 모듈 밖 0건(ADM-06-039) |
| 작업 | 2절 작업 57개(사람 작업 ADM-06-043 포함)와 8절 ADM-06-058 완료. 059·060(P2 선택, G2 이후)은 MVP 완료 정의에서 제외 |

P0 작업과 대응 테스트(인증, 2026-10-14): 007(Stage A) → 035(Mock 페르소나 storageState), 034(`outsider` 교차 테넌트) / 014·022·029(A 구성) → 035 / 058(Stage B) → 035(스테이징 재실행), 058 수동 점검표(B-5).

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(9장 작업 계획 반영 규칙, 8장 매트릭스의 admin-suite 행: erp approval, sms invite, hms 별도 DB. B는 erp·sms Google + 이메일·초대 메일, hms 이메일만. C는 erp·sms P2 선택, hms 제외)다. 이 제품 반영은 01장 2절·8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절. Stage A는 기존 ADM-06-007이 맡고(2절에서 범위 변경), 아래 3개를 새로 더한다. 작업 ID는 기존 최대 057 다음부터.

### 8.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ADM-06-058 | 인증 Stage B: erp Google + 이메일 가입·메일 인증·비밀번호 재설정, sms Google + 초대 메일(비밀번호 설정), hms 초대 메일 + 이메일 로그인만(D-21 전 Google 없음), `/auth/callback`(`finishLogin` 연결), 첫 OAuth 로그인 뒤 약관 단계(erp `/pending` 첫 단계, sms·hms `/invite/accept`), 앱별 `AUTH_PROVIDERS` 허용값 기동 검사, 배포 체크리스트(Google 콘솔·Supabase Providers·Redirect URLs, 프로젝트별), Google 실로그인 수동 점검표 | `packages/admin-kit/src/auth/callback/`, `packages/admin-kit/src/auth/providers/`(Google 버튼·이메일 폼, 앱별 `AUTH_PROVIDERS` 허용값 표 `allowed.ts`. `kakao.ts`·`naver.ts` 제외: 059·060. `getAuthConfig`의 허용값 검사 연결은 007 파일에 1줄 요청), `packages/admin-kit/src/auth/terms/`, `apps/erp/src/app/auth/callback/`, `apps/sms/src/app/auth/callback/`, `apps/hms/src/app/auth/callback/`, `apps/<app>/src/app/(auth)/`(014·022·029에서 이어 받음: login B 구성, erp `signup`, `reset-password`, 초대 메일 비밀번호 설정), `supabase/<app>/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`(005에서 이어 받음, erp·sms), `docs/admin-suite/ops/auth-checklist.md`. 약관 단계 장착은 `/pending`(014)·`/invite/accept`(sms 029, hms 022), "초대받은 이메일로 로그인하세요" 안내의 `/no-access` 장착은 020·028·033 파일에 1줄 요청 | ADM-06-007, ADM-06-014, ADM-06-022, ADM-06-029, ADM-06-038. 진입 조건 G1(`[DECISION] G1 통과`) | P0 | M | Fable | `AUTH_ROADMAP.md` 5.3절을 앱별로 옮긴다. B-1 erp: 새 Google 계정 첫 로그인 → 프로필 pending → 약관 단계 → `/pending` 가입 코드 입력(모듈러 통합 DB는 콜백이 `bootstrap_app_for_org('erp')` 1회, 모놀리스는 가입 트리거가 이미 부트스트랩해 호출 0, 04장 8.2절 3번·05장 10.5절)(재로그인 3회 뒤에도 pending 프로필 1개, 기존 활성 구성원이 Google로 로그인해도 pending 강등 0). sms: 초대와 같은 이메일의 Google 첫 로그인 → `/invite/accept`, 다른 이메일 → `entitled=false`, `/no-access` "초대받은 이메일로 로그인하세요". hms: 로그인 화면에 Google 버튼 0, `AUTH_PROVIDERS`에 `email` 외 값이 있으면 기동 실패, 초대 메일 링크로 비밀번호 설정 후 `/invite/accept`. B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → 역할 홈(`access.ts`). B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 오류 로그에 토큰·코드 없음. B-4 `VERCEL_ENV=production` 빌드(3앱)에서 `/api/dev/login` 404, 로그인 화면에 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(ADM-06-035) 계속 녹색, Google 실로그인(erp·sms)과 초대 메일 수락(3앱)은 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인하고 task `log.md`에 기록. B-6 Supabase 프로젝트별(erp·sms 통합 또는 고객사별, 병원별 hms) Providers·Redirect URLs·`AUTH_PROVIDERS`가 배포 체크리스트와 일치. 제품 추가: erp 이메일 가입이 `signUp({ options: { data: { signup_app: 'erp', full_name } } })`, 같은 이메일 가입자의 Google 로그인은 같은 `user_id`(Supabase 자동 연결), 감사 `auth.login` 1행/로그인(토큰·코드 없음) | `AUTH_ROADMAP.md` 5장, 9장 B 작업, KIT-F-005, KIT-F-006, 01장 D-21, 03장 7절, 04장 8.2절 |
| ADM-06-059 | 인증 Stage C1(erp·sms, D-24 "도입"일 때만): 카카오 로그인(Supabase 기본 제공자 `kakao`), 로그인 버튼, 설정 → 로그인 방법(연결·해제, 03장 7.4절) | `packages/admin-kit/src/auth/providers/kakao.ts`, `packages/admin-kit/src/auth/login-methods/`(`/settings/account` 장착은 erp 019, sms 033 파일에 1줄 요청), erp·sms `supabase/<app>/config.toml`의 `[auth.external.kakao]`(058 완료 후 이어 받음). 로그인 버튼은 `listLoginOptions`(007)가 `AUTH_PROVIDERS`로 렌더하므로 로그인 화면 파일을 고치지 않는다. 컴포넌트 변경이 필요하면 058·007 파일에 1줄 요청, erp·sms 허용값에 `kakao` 추가는 058의 `allowed.ts`에 1줄 요청, `docs/admin-suite/ops/auth-checklist.md` 카카오 절 | ADM-06-058. 진입 조건 G2(`[DECISION] G2 통과`), 01장 D-24 "도입", D-22 확정 | P2 | S | Opus | `AUTH_ROADMAP.md` 7.1.3절을 옮긴다. C1-1 새 카카오 계정 첫 로그인 → B-1과 같은 앱별 결과(erp `/pending`, sms 초대 없으면 `/no-access`). C1-2 비즈 앱(D-22 (a))이면 Google·이메일로 가입한 같은 이메일 사용자가 카카오로 로그인 → 같은 `user_id`(제공자 이메일 인증 확인 시에만 자동 연결, 미확인이면 7.3절 수동 연결). C1-3 (`AUTH_ROADMAP.md`의 (b) 분기를 이 제품에 맞춤) D-22가 (b)(이메일 없이 허용)면 이메일 없는 사용자는 초대·가입 승인이 이메일 기준이라 연결되지 않으므로 sms는 `/no-access`, erp는 `/pending`에서 "이메일이 있는 계정으로 로그인하세요"를 본다(이 제품은 결제 화면이 없어 연락 이메일 입력 화면 대신 안내). (a)면 이메일 동의를 거부한 로그인은 세션을 만들지 않고 같은 안내를 한다. C1-4 표시 이름은 카카오 닉네임, 없으면 `user` 규칙. C1-5 버튼은 카카오 디자인 가이드 색·문구(미확인: 최신판 확인 후 반영). hms 빌드에 카카오 코드 경로·버튼 0. 로그인 방법 화면: 연결·해제, 마지막 수단 해제 거부, 감사 `auth.identity_link`·`auth.identity_unlink` | `AUTH_ROADMAP.md` 7.1, 7.3절, 9장 C1 작업, 01장 D-22, D-24 |
| ADM-06-060 | 인증 Stage C2(erp·sms, D-24 "도입"일 때만): 네이버 로그인(스파이크 0.5일 → `custom:naver` 또는 서버 브리지), 네이버 검수 자료, 로그인 방법 화면의 네이버 행 | `packages/admin-kit/src/auth/providers/naver.ts`, `scripts/auth/register-naver-provider.mjs`(제안), `apps/erp/src/app/auth/naver/`, `apps/sms/src/app/auth/naver/`(브리지 경로일 때만), `docs/admin-suite/ops/naver-review/`(검수 캡처). 버튼·허용값은 059와 같은 방식(`listLoginOptions`, `allowed.ts`에 1줄 요청) | ADM-06-058(로그인 방법 화면의 네이버 행은 059 완료 후 059 파일에 요청). 진입 조건 G2, 01장 D-24 "도입". 브리지면 코어 R-15(8.4절) 적용 후 | P2 | M | Fable | `AUTH_ROADMAP.md` 7.2.4절을 옮긴다. C2-1 스파이크 결과가 `[DECISION]`으로 기록되고(01장 D-23) `NAVER_AUTH_PATH`가 그 값이다. C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 앱별 결과. C2-3 같은 네이버 계정 재로그인 5회 → 같은 `user_id`, 사용자 수 증가 0. C2-4 (브리지) state 변조·재사용·쿠키 없음 → 거부, 세션 미생성, 다른 브라우저에서 받은 콜백 URL 재생 → 거부. C2-5 (브리지) 같은 이메일의 Google·이메일 가입자가 네이버로 처음 로그인 → `email_in_use` 안내, 새 사용자 0. C2-6 네이버 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않는다. hms에서 `/auth/naver/*` 404 | `AUTH_ROADMAP.md` 7.2절, 9장 C2 작업, 01장 D-23, D-24, 04장 8.3절 |

### 8.2 게이트와 웨이브

| 게이트·웨이브 | 작업 | 진입 조건 | 판정 |
|---|---|---|---|
| Stage A | ADM-06-007(W2) | 006 뒤. 007보다 앞 웨이브(W0·W1) 작업은 시드 스크립트 없이 SQL·단위 테스트로 검증한다(001~003 체커·스모크, 008 단위 테스트) | - |
| G1 | - | `AUTH_ROADMAP.md` 4장을 이 제품에 맞춘다. 1) 2절 MVP P0 기능 작업 완료(W5까지. 인증 B·C와 출시 직전 통합 작업 035·057 제외) 2) 역할×경로 E2E(ADM-06-035)가 3앱 Mock 페르소나로 로컬 녹색 3) RLS 스모크(ADM-06-034)와 `outsider` 교차 테넌트 거부 4) 결제 E2E는 Phase 2(ADM-06-013·036, P2·P1)라 G1 조건에서 뺀다 5) 단계 분기 코드가 인증 모듈 밖 0건(ADM-06-039 CI) 6) erp·sms Google Cloud 프로젝트·OAuth 동의 화면(앱 이름은 01장 D-9)·웹 클라이언트 ID, 첫 기관 배포용 Supabase 프로젝트 준비(`AUTH_ROADMAP.md` 5.1절). hms는 Google 준비 없이 Supabase Email·초대 메일 템플릿만 | 사람(대표님)이 task `log.md`에 `[DECISION] G1 통과` |
| Stage B | ADM-06-058 | W6의 맨 앞(마지막 P0 기능 웨이브 W5 다음, 출시 직전 통합·E2E 웨이브. W6에 남은 019·027·032는 P1·P2 잔여 화면이라 058과 병렬). 035·057의 스테이징·B 구성 재실행은 058 완료를 기다린다 | - |
| G2 | - | `AUTH_ROADMAP.md` 6장을 이 제품에 맞춘다. 1) 첫 기관 배포 후 Google·이메일 실로그인 운영 2주(제안) 2) 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안) 3) open 앱 조건 대신: erp OAuth·이메일 신규 사용자 중 pending 프로필 없이 남은 사용자 0, sms·hms 초대 수락 실패(링크 만료 제외) 0 4) 01장 D-24 판정("도입"이면 카카오 디벨로퍼스 앱·비즈 앱 전환(D-22), 네이버 애플리케이션 등록·검수 자료) | 사람이 `[DECISION] G2 통과`와 D-24 결과를 함께 기록 |
| Stage C | ADM-06-059, ADM-06-060 | W7(MVP 출시 후), G2 통과와 D-24 "도입". 059·060 병렬 가능. D-24가 "도입하지 않음"이면 두 작업을 실행하지 않고 취소 사유를 task `log.md`에 남긴다 | - |

### 8.3 앱별 해석 (단계 작업이 지킬 것)

| 항목 | erp | sms | hms |
|---|---|---|---|
| 첫 OAuth 로그인 결과 | 콜백이 `bootstrap_app_for_org('erp')` 1회 → pending → 약관 → `/pending` | 초대와 같은 이메일이면 `/invite/accept`, 아니면 `/no-access` | 해당 없음(Google 없음). 초대 메일 비밀번호 설정 → `/invite/accept` |
| `AUTH_PROVIDERS`(배포) | `google,email`(C 도입 시 `kakao`, `naver` 추가) | 같음 | `email`만. 다른 값이면 기동 실패(D-21 (b) 확정 시 병원 배포 단위로 `google`) |
| Supabase 프로젝트 | 모듈러 통합 DB 1개 또는 고객사별 모놀리스(README 5절 2차) | erp와 같음 | 병원마다 따로. 카카오·네이버 콘솔에 등록하지 않는다 |
| 시드 훅 | `scripts/dev/seed-users.erp.mjs` | `scripts/dev/seed-users.sms.mjs` | `scripts/dev/seed-users.hms.mjs`(로컬 hms 프로젝트만, 환자 데이터 없음) |

### 8.4 코어 요청 (6절 표에 이어서)

| ID | 요청 | 대상 | 이유 | 제품의 임시 대응 |
|---|---|---|---|---|
| R-15 | C2 스파이크가 실패해 브리지 경로를 택하면(01장 D-23 (b)) 코어 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`(`core.auth_identity_links`) 적용. erp·sms 모놀리스로 가는 고객사는 모놀리스 lite에도 같은 절 필요 | `_platform-core` | 브리지 로그인은 네이버 고유 id로 사용자를 찾는다. 코어는 한 번만 적용하고 모든 제품이 쓴다(`AUTH_ROADMAP.md` 9장 공용 모듈 요청). `supabase_custom` 경로이거나 D-24가 "도입하지 않음"이면 요청하지 않는다. hms는 해당 없음 | 없음. 반영 전에는 브리지 경로 060을 시작하지 않는다 |

### 8.5 기존 문서와 달라진 점

| 항목 | 이전 | 지금 | 반영 |
|---|---|---|---|
| ADM-06-007 범위 | admin-kit 가드(`createAdminProxy`, `requireRole`, `defineAccess`) | 가드 + Stage A(인증 단계 모듈, Mock 로그인, 시드 스크립트와 앱 훅 3개, `finishLogin` 기관 조직 분기) | 2절 007 행 |
| `packages/admin-kit/src/auth/` 소유 | 007 단독 | 007. 단 하위 `callback/`·`providers/`·`terms/`는 058, `providers/kakao.ts`·`login-methods/`는 059, `providers/naver.ts`는 060(하위 경로로 나눠 동시 쓰기 없음) | 2절 007 행, 8.1절 |
| `apps/<app>/src/app/(auth)/` 소유 | 014(erp), 022(hms), 029(sms) | 세 작업이 A 구성(개발용 패널 장착) → 058이 이어 받음(W4 → W6 직렬이라 동시 쓰기 없음) | 2절 014·022·029 행, 8.1절 058 행 |
| erp 이메일 가입 폼 | 014(`signUp`의 `signup_app`·`full_name`) | 058(B). A에서는 Mock `pending`·`join_requested`·`join_rejected` 페르소나로 대기 화면을 개발(03장 1절 `/signup` 행) | 2절 014 행 |
| 첫 OAuth 로그인 약관 | 없음(가입 폼에서 동의) | erp `/pending` 첫 단계, sms·hms `/invite/accept` 수락 버튼 위(03장 7.3절). 058이 `packages/admin-kit/src/auth/terms/`로 만들고 014·022·029 파일에 1줄 요청으로 장착 | 03장 7.3절, 8.1절 |
| 소유가 없던 경로(2026-10-14 명시) | `/no-access`, sms·hms `/settings/account`, hms `/invite/accept`, 앱별 `supabase/<app>/config.toml`, Playwright 공용 설정 | `/no-access`는 020·028·033, sms·hms `/settings/account`는 033·028(erp는 기존 019), hms `/invite/accept`는 022, `config.toml`은 005(B·C 절은 058·059가 이어 받음), `global-setup.ts`·`playwright.config.ts`는 035 | 2절 005·020·022·028·033·035 행 |
| ADM-06-035 수용 기준 | 역할×경로 매트릭스(로그인 방법 미정) | Mock 페르소나 storageState로 로컬 먼저(G1 근거), 058 후 B 구성 스테이징 재실행 | 2절 035 행 |
| ADM-06-039 금지 검사 | `OVERRIDE`·hex·v3 문법 등 | + 쿠키 역할 Mock, `mock-auth`, 인증 모듈 밖 `AUTH_MODE` 참조. `AUTH_MODE=mock` 배포 빌드 실패는 007 수용 기준(빌드 시 env 검사) | 2절 007·039 행 |
| 01장 결정 | D-1~D-20 | D-21(hms Google), D-22(카카오 이메일), D-23(네이버 경로), D-24(erp·sms Stage C 도입 여부)를 01장 8.1절에 새로 둠 | 01장 8.1절 |
| 공용 파일 요청 | - | 007: 개발용 패널의 로그인 화면 장착은 014·022·029, `MOCK AUTH · 로컬 전용` 배지의 레이아웃 장착은 020·028·033, `package.json` 스크립트 `db:seed-users`는 005에 1줄 요청. 058: 약관 단계 장착은 014·022·029. 059: `/settings/account` 장착은 그 화면 소유 작업에 1줄 요청 | 1절 원칙 그대로 |
| 작업 수 | 57개(모델 작업 56) | 60개(모델 작업 59). 059·060은 계획에 포함하고 D-24 "도입"일 때만 실행 | 머리말, 4절 |
