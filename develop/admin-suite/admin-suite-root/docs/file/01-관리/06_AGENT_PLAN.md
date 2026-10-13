# 06 에이전트 작업 계획: Admin Suite

작업 ID 접두사: `ADM`(admin-suite 공통. 앱별 SQLSTATE 접두사 ER/SM/HM과 별개로 제품 단위 하나를 쓴다, 제안).

2026-10-13 개정: AI 계층·음성·디자인 시스템(확정 결정 13~17, `docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 4장) 작업 17개(ADM-06-041~057)를 뒤에 붙였다. 3D 히어로 작업은 없다(03장 4.5절). 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 001·002·003(AI 기본값 수용 기준), 009(디자인 시스템 2단계 선행), 014~019·022~027·029~032(화면 작업은 044 뒤), 020·028·033(토큰 파일 소유가 042로 이동, 위젯 마운트), 035·038·039·040(AI·hms 격리·린트·로그인 화면)이다. 작업 수 57개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. AI·음성·디자인 시스템이 MVP 필수가 되면서 늘어난 것이며 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다.

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

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ADM-06-001 | erp/sms 모듈러 조각 확정·적용(로컬 Supabase), config schemas 등록 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql` | 없음 | P0 | M | Fable | 체커 OK, 모듈러 스모크 92항목 통과, `supabase db reset` 성공. AI 기본값(조각 7절: 라우팅 erp 8행·sms 8행, 플랜 AI 키, `ai-docs` 버킷, 체인 검사)이 체커 OK, 2회 적용 OK | ERP 리뷰 5장 #1,#3,#8,#9, School 5장 #3, 05장 7절 |
| ADM-06-002 | hms 모놀리스 도메인 SQL 확정(의료정보 보호) | `D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/hms/` | 없음 | P0 | L | Fable | 체커 OK, hms 스모크 52항목 통과, 민감 테이블 SELECT GRANT 0. hms AI 기본값(seed: 라우팅 7행 + `hms-%` 체인 검사 + contract 플랜 AI 키 + 버킷)이 체커 OK, 모든 기능이 `hms-*`로만 해석 | Hospital 5장 #1,#3,#9,#12, HMS-F-014 |
| ADM-06-003 | erp/sms 모놀리스 lite·seed 검증 | `D:/WorkSpace/platform/docs/products/admin-suite/supabase/monolith/erp/seed.sql`, `sms/seed.sql`, 각 `0001_core_lite.sql` | ADM-06-001 | P0 | S | Fable | 체커 OK, 스모크 erp 21, sms 19 통과. seed 반복 적용 후 라우팅 행 erp 8·sms 8, 플랜 features에 AI 키 5개 | 05장 8절 |
| ADM-06-004 | 조각 → 모놀리스 변환 스크립트 + CI diff 검사 | `tools/admin-suite/to-monolith.py`, `.github/workflows/sql-check.yml` | ADM-06-001 | P1 | S | Haiku | 스크립트 재실행 결과와 커밋된 `0002_<app>_domain.sql` diff 0 | `DB_CONVENTIONS.md` 12장 제안 |
| ADM-06-005 | 모노레포 골격 + `db:types` | `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `scripts/db-types.mjs`, `packages/admin-kit/package.json` | 없음 | P0 | S | Haiku | `pnpm db:types --app erp` 가 타입 생성, `pnpm -r build` 통과 | ERP 5장 #13, Hospital 5장 #5, School 5장 #7 |
| ADM-06-006 | admin-kit Supabase 래퍼와 세션 | `packages/admin-kit/src/supabase/` | ADM-06-005 | P0 | S | Opus | 앱이 `createAdminClients(appId)`만으로 3종 클라이언트와 `getSession`을 얻음 | KIT-F-001 |
| ADM-06-007 | admin-kit 가드: `createAdminProxy`, `requireRole`, `defineAccess` | `packages/admin-kit/src/auth/` | ADM-06-006 | P0 | M | Fable | 프로필 없음 → 로그아웃, pending → /pending, 매트릭스 밖 → 403(RSC 페이로드 없음), 역할 기본값 없음 | ERP 5장 #4,#5, Hospital 5장 #2,#14, School 5장 #2,#4, KIT-F-002~004 |
| ADM-06-008 | KST 날짜 유틸 + 단위 테스트 | `packages/admin-kit/src/date/` | ADM-06-005 | P0 | S | Sonnet | 00:30 KST, 23:59 KST, 월말 경계 테스트 12개 통과 | ERP 5장 #7, Hospital 5장 #4, School 5장 #6 |
| ADM-06-009 | admin-kit UI(AppShell 햄버거, DataTable, FormModal, ConfirmDialog, Toast, KpiCard, Chart) | `packages/admin-kit/src/ui/` | ADM-06-005, ADM-06-042 | P0 | L | Sonnet | 375/768/1024/1440px 스크린샷 가로 스크롤 0, 로그아웃 버튼, axe 위반 0. AppShell 헤더에 어시스턴트 버튼 자리(ADM-06-052가 채움)와 `tokens.css` 변수만 사용(hex 0) | ERP 5장 #6, Hospital 5장 #13, School 5장 #4,#10, KIT-F-008~009 |
| ADM-06-010 | `useRealtimeTable` | `packages/admin-kit/src/realtime/` | ADM-06-006 | P1 | S | Opus | 한 화면 채널 1개, payload 부분 갱신, 언마운트 해제 테스트 | ERP 5장 #8, Hospital 5장 #11, School 5장 #9 |
| ADM-06-011 | 가입 승인/초대 공통 흐름(화면 조각 + 서버 함수, Auth Admin 초대) | `packages/admin-kit/src/members/` | ADM-06-007 | P0 | M | Opus | 앱이 RPC 이름을 주입해 승인제·초대제 모두 동작, 본인 초대 차단 | KIT-F-005~007, School 5장 #8 |
| ADM-06-012 | 감사 로그 뷰어 | `packages/admin-kit/src/audit/` | ADM-06-009 | P1 | S | Sonnet | owner/admin만 표시, 기간·action 필터 | KIT-F-012 |
| ADM-06-013 | 플랜/구독 화면과 Route Handler(공용 toss 모듈 호출) | `packages/admin-kit/src/billing/` | ADM-06-007 | P2 | M | Fable | standard 구독 confirm 후 엔타이틀먼트 standard, PM001 시 `fail_payment_order` 호출 후 취소·알림 | 01장 4절 |
| ADM-06-014 | ERP 인증·가입(승인제)·대기 화면 | `apps/erp/src/app/(auth)/`, `apps/erp/src/app/pending/` | ADM-06-011, ADM-06-044 | P0 | M | Opus | signUp에 `signup_app`, `full_name`, 승인 후 accept까지 E2E 통과 | ERP 5장 #2,#4 |
| ADM-06-015 | ERP 재고 화면과 서버 | `apps/erp/src/app/(app)/inventory/`, `apps/erp/src/server/inventory.ts`, `apps/erp/src/server/images.ts` | ADM-06-001, ADM-06-009, ADM-06-044 | P0 | M | Opus | 감소 조정, ER001 메시지, 위험 재고 `is_low_stock` 필터, 이미지 경로 강제 | ERP 5장 #3,#8,#13, ERP-F-001~003,014 |
| ADM-06-016 | ERP 판매 화면과 서버 | `apps/erp/src/app/(app)/sales/`, `apps/erp/src/server/sales.ts` | ADM-06-001, ADM-06-009, ADM-06-044 | P0 | M | Opus | 상태 탭, 취소 사유, 재시도 멱등 | ERP 5장 #3,#9, ERP-F-004~005 |
| ADM-06-017 | ERP 대시보드 + 판매 추이 | `apps/erp/src/app/(app)/dashboard/` | ADM-06-008, ADM-06-010, ADM-06-044 | P1 | M | Opus | `dashboard_metrics` 1회 호출, 전체 행 조회 0, 실시간 최근 변동 | ERP 5장 #7,#10, ERP-F-006~008 |
| ADM-06-018 | ERP 인사·부서·가입 요청 | `apps/erp/src/app/(app)/hr/`, `apps/erp/src/app/(app)/me/`, `apps/erp/src/server/hr.ts` | ADM-06-011, ADM-06-044 | P1 | M | Opus | 부서 CRUD, 권한 모달(자기 자신 비활성), 가입 코드 재발급 | ERP 5장 #11, ERP-F-009~012 |
| ADM-06-019 | ERP 설정 | `apps/erp/src/app/(app)/settings/` | ADM-06-018, ADM-06-044 | P2 | S | Sonnet | 저장 유지, URL/키 표시 0 | ERP 5장 #12, ERP-F-013 |
| ADM-06-020 | ERP 테마·내비·proxy·access 매트릭스 | `apps/erp/src/theme/`(`tokens.css` 제외), `apps/erp/src/access.ts`, `apps/erp/src/proxy.ts`, `apps/erp/src/app/layout.tsx` | ADM-06-007, ADM-06-009, ADM-06-044 | P1 | S | Sonnet | 중복 라우트 0, 메뉴가 역할별로만 보임. 채팅 위젯·어시스턴트 버튼 마운트(ADM-06-052 요청 1줄). `tokens.css`는 ADM-06-042 소유 | ERP 5장 #5,#6 |
| ADM-06-021 | HMS 의료정보 서버 계층(AES-256-GCM, 키 버전, 접근 사유) | `apps/hms/src/server/phi/` | ADM-06-002 | P0 | M | Fable | 키 누락 시 기동 실패, 복호화는 서버에서만, 암호문 클라이언트 전송 0 | Hospital 5장 #3,#5, 01장 6.2절 |
| ADM-06-022 | HMS 인증·직원 관리 | `apps/hms/src/app/(auth)/`, `apps/hms/src/app/(app)/staff/`, `apps/hms/src/server/staff.ts` | ADM-06-011, ADM-06-021, ADM-06-044 | P0 | M | Opus | OVERRIDE/verify-admin 없음, 초대·역할 변경, 자기 변경 차단 | Hospital 5장 #2, HMS-F-001 |
| ADM-06-023 | HMS 환자 목록/등록/상세/360 차트 | `apps/hms/src/app/(app)/patients/`, `apps/hms/src/server/patients.ts` | ADM-06-021, ADM-06-044 | P0 | L | Opus | 동의 필수, 성별 실데이터, 타임라인 병합, 접근 기록 1행/열람 | Hospital 5장 #6,#9, HMS-F-002~004,008 |
| ADM-06-024 | HMS 예약 캘린더 | `apps/hms/src/app/(app)/calendar/`, `apps/hms/src/server/appointments.ts` | ADM-06-023, ADM-06-044 | P1 | M | Opus | 주말 포함 주별 뷰, 빈 슬롯 예약, 범위 조회, visit_type 범례 | Hospital 5장 #7,#12, HMS-F-005 |
| ADM-06-025 | HMS 실시간 대기열 | `apps/hms/src/app/(app)/queue/` | ADM-06-010, ADM-06-024, ADM-06-044 | P0 | M | Opus | 채널 1개, KST 당일 대기번호, 담당의만 진료 시작 | Hospital 5장 #3,#4,#11, HMS-F-006~007 |
| ADM-06-026 | HMS 검사 | `apps/hms/src/app/(app)/lab/`, `apps/hms/src/server/lab.ts` | ADM-06-023, ADM-06-044 | P1 | M | Opus | 빈 값 저장 불가, 저장 후 목록 갱신, 승인(입력자 제외), 의뢰 | Hospital 5장 #10, HMS-F-009~011 |
| ADM-06-027 | HMS 수납·대시보드·접근 기록 화면 | `apps/hms/src/app/(app)/billing/`, `apps/hms/src/app/(app)/dashboard/`, `apps/hms/src/app/(app)/settings/access-log/` | ADM-06-025, ADM-06-044 | P1 | M | Opus | 하드코딩 0, 취소/노쇼 분리, 접근 기록 필터·CSV | Hospital 5장 #4,#8, HMS-F-012~014 |
| ADM-06-028 | HMS 테마·내비·proxy·access | `apps/hms/src/theme/`(`tokens.css` 제외), `apps/hms/src/access.ts`, `apps/hms/src/proxy.ts`, `apps/hms/src/app/layout.tsx` | ADM-06-007, ADM-06-009, ADM-06-044 | P1 | S | Sonnet | 메뉴 자물쇠 노출 0, 대비 4.5:1. 채팅 위젯 마운트(ADM-06-052 요청 1줄). `tokens.css`는 ADM-06-042 소유 | Hospital 5장 #14(라벨 중복 제거) |
| ADM-06-029 | SMS HEAD 자산 이식 + 인증·초대 수락 | `apps/sms/src/app/(auth)/`, `apps/sms/src/app/invite/` | ADM-06-011, ADM-06-044 | P0 | M | Opus | 07장 2절 목록 이식 완료, 학생 첫 로그인 → `/student/dashboard` | School 5장 #1,#8 |
| ADM-06-030 | SMS 학급·과목·구성원 관리 | `apps/sms/src/app/(app)/admin/classes/`, `.../subjects/`, `.../members/`, `apps/sms/src/server/roster.ts` | ADM-06-029, ADM-06-044 | P0 | M | Opus | zod 검증, `requireRole('admin')`, 14세 미만 동의 체크 | School 5장 #5, SMS-F-001~004 |
| ADM-06-031 | SMS 출석 체크 보드 | `apps/sms/src/app/(app)/admin/attendance/`, `apps/sms/src/server/attendance.ts` | ADM-06-030, ADM-06-010, ADM-06-044 | P0 | M | Opus | 일괄 저장 200건, SM002 메시지, 학급 필터 구독 | SMS-F-005~007 |
| ADM-06-032 | SMS 관리자/학생 대시보드 + 추이 + 알림 | `apps/sms/src/app/(app)/admin/dashboard/`, `.../admin/trend/`, `apps/sms/src/app/(app)/student/` | ADM-06-031, ADM-06-008, ADM-06-044 | P1 | M | Opus | 출석률 정의 일치(100% 초과 0), payload 부분 갱신, 학생 5초 알림 | School 5장 #6,#9,#12, SMS-F-008~011 |
| ADM-06-033 | SMS 테마·내비(lucide)·proxy·access | `apps/sms/src/theme/`(`tokens.css` 제외), `apps/sms/src/access.ts`, `apps/sms/src/proxy.ts`, `apps/sms/src/app/layout.tsx` | ADM-06-007, ADM-06-009, ADM-06-044 | P2 | S | Sonnet | 이모지 0, 빌드 로그에 Proxy 항목. student 역할 화면에는 어시스턴트 버튼 0. `tokens.css`는 ADM-06-042 소유 | School 5장 #10 |
| ADM-06-034 | RLS/권한 회귀 테스트(모듈러 + 모놀리스 3종) | `tests/rls/` | ADM-06-001, ADM-06-002, ADM-06-003 | P0 | M | Fable | `SECURITY_BASELINE.md` 15장 + `DB_CONVENTIONS.md` 13.3 + 이 제품 항목, CI에서 실패 0 | `SECURITY_BASELINE.md` 0장, 05장 7절 |
| ADM-06-035 | 역할·경로 E2E(Playwright) | `tests/e2e/erp/`, `tests/e2e/hms/`, `tests/e2e/sms/` | ADM-06-020, ADM-06-028, ADM-06-033, ADM-06-046, ADM-06-052 | P0 | M | Opus | 역할 x 경로 매트릭스 전 조합 기대 상태 코드, 비로그인 리다이렉트, 사이드바 링크 404 0. AI 질문 1턴(목 제공자) 3앱 통과, SMS student의 `/api/ai/*` 403, 한도 초과 시 입력 비활성 | 02장 6절, School 리뷰 #1,#2 |
| ADM-06-036 | 결제 E2E(Toss 테스트 키) | `tests/e2e/billing/` | ADM-06-013 | P1 | M | Opus | standard 구독 성공, 금액 위조 PM001, 웹훅 서명 실패 401 | `DOC_TEMPLATE.md` 작업 규칙 |
| ADM-06-037 | ERP 동시성·멱등 DB 테스트 | `tests/db/erp/` | ADM-06-001 | P0 | S | Opus | 동시 판매 50건 후 음수 0, 수량 = 이동 합, 같은 request_id 1행 | ERP 5장 #3 |
| ADM-06-038 | 저장소 위생: .gitignore, .env.example, README, 원본 archive, 금지 env 검사 | `.gitignore`, `.env.example`, `apps/*/README.md`, `archive/README.md`, `packages/admin-kit/src/env/` | ADM-06-005 | P0 | S | Haiku | `.env*` 무시, `OVERRIDE_PASSWORD` 존재 시 기동 실패, nested git 0. hms 배포에서 금지 AI 변수(`DIFY_*`, 상용 키, 공용 AI URL, 02장 5.5절) 하나라도 있으면 기동 실패 | ERP 5장 #14, Hospital 5장 #14, School 5장 #11 |
| ADM-06-039 | 린트/TS 설정(`eslint .`, Next 16 규칙, no-explicit-any) | `eslint.config.mjs`, `tsconfig.base.json` | ADM-06-005 | P1 | S | Haiku | `pnpm lint` 오류 0, `next lint` 사용 0. `bg-[#...]` 같은 임의 hex, `tailwind.config.js`, `@tailwind base` v3 문법, `apps/hms`의 `elevenlabs`·Dify import, 3D 라이브러리(three.js 계열) import 금지 규칙 포함 | ERP 5장 #14, School 5장 #11 |
| ADM-06-040 | 디자인 MASTER.md와 로그인 화면 | `design-system/admin-suite/` | ADM-06-044 | P1 | S | Sonnet | 03장 4절 토큰 반영, 7단계 체크리스트 통과. 로그인 화면에 3D 의존성 0, `prefers-reduced-motion`에서 모션 0(03장 4.5절) | 03장 4절 |
| ADM-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(주 Primer, 보조 Atlassian, AI 채팅 Astryx 확인), 가져올 것과 안 가져올 것, 3앱 테마 방향 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안(01장 D-18) 기록. 고문(Fable) 검토 기록 | DESIGN_SYSTEM 4장 1단계, 9절 |
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
| W6 | 019, 027, 032, 035, 036, 057 | 6 | W5 | 잔여 화면, E2E, 결제 E2E, AI 보안·격리 회귀. MVP 출시 조건 |

같은 웨이브 안에서도 선행 작업 열이 우선한다(예: 024 → 025, 030 → 031). 3D 히어로 작업은 없다(03장 4.5절).

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 12 (001, 002, 003, 007, 013, 021, 034, 045, 046, 047, 055, 057) | 21.4% | 25 / 101 = 24.8% |
| Opus | 29 (기존 21 + 044, 048, 049, 050, 051, 053, 054, 056) | 51.8% | 56 / 101 = 55.4% |
| Sonnet | 11 (008, 009, 012, 019, 020, 028, 033, 040, 041, 042, 052) | 19.6% | 16 / 101 = 15.8% |
| Haiku | 4 (004, 005, 038, 039) | 7.1% | 4 / 101 = 4.0% |
| 합계 | 56 | 100% | 101 |

비율은 모델 작업 56개 기준이다. 사람 작업 1개(ADM-06-043, M)는 비율에서 뺐다. 2026-10-13 이전(40개)은 Fable 17.5%, Opus 52.5%, Sonnet 20.0%, Haiku 10.0%였다. Fable은 AI 보안 경계(서명 토큰 검증 045, 게이트의 한도·동의·토큰 046, hms 직접 경로 047, hms 전용 서버 055, AI 격리 회귀 057)를 맡고, 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 위젯과 디자인 시스템 토큰·컴포넌트는 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

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
| R-12 | 통합 `seed.sql`(erp/sms 플랜)에 AI 키 5개(`ai_assistant`, `ai_turns_per_day`, `ai_voice`, `ai_docs_max`, `ai_wiki`) 반영 | `_supabase-modular/seed.sql` 담당 | seed가 조각보다 나중에 실행되면 조각 7절의 병합 UPDATE가 덮어써질 수 있다 | 서버가 누락 키를 기본값으로 읽는다(01장 4.1절) |
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
| 작업 | 06장 작업 57개 완료(사람 작업 ADM-06-043 포함) |
