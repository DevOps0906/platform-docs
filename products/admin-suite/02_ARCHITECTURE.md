# 02 아키텍처: Admin Suite

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 모노레포 | pnpm workspace + Turborepo | pnpm 9, turbo 2 (제안) | 확정 결정 2(`packages/admin-kit` + `apps/*`) |
| 프레임워크 | Next.js App Router, React | 16.x, 19.x | 세 원본 모두 Next 16 + React 19(`docs/reviews/ERP-Wesite.md:14`, `docs/reviews/Hospital.md:10`, `docs/reviews/School_Management_System.md:10`) |
| 라우트 보호 | `src/proxy.ts`(Next 16 Proxy) | - | `docs/reviews/ERP-Wesite.md:82`, `docs/reviews/School_Management_System.md:63` |
| 스타일 | Tailwind CSS 4 + shadcn(코어 UI만) | 4.x | `analysis:1149`(Hospital 미사용 shadcn을 코어 UI로 대체) |
| 아이콘 | lucide-react | 최신 고정 버전 | `analysis:1190` |
| 차트 | recharts 래퍼(admin-kit) | 3.x | `docs/reviews/Hospital.md:10` |
| DB/인증 | Supabase(PostgreSQL 15, Auth, Realtime, Storage), `@supabase/ssr` | ssr 0.12 | `analysis:1124` |
| 검증 | zod | 3.x | `SECURITY_BASELINE.md` 10장 |
| 테스트 | Vitest(단위), Playwright(E2E), PGlite(RLS 스모크) | - | `DB_CONVENTIONS.md` 13장 |
| 배포 | Vercel(앱 3개 각각), Supabase(erp/sms: 통합 또는 고객사별, hms: 병원별) | - | 7절 |

백엔드는 Next.js Route Handler/Server Action + Supabase RPC만 쓴다. 확정 결정 3(FastAPI)은 출판·사주 대상이라 적용하지 않는다. 확정 결정 6(영상 워커)도 해당 없음.

## 2. 모듈 경계

```
packages/admin-kit/            공유 코어(앱 비의존). 도메인 테이블 이름을 모른다.
  src/supabase/                 _platform-core 클라이언트 재수출 + 앱 스키마 선택(SUPABASE_DB_SCHEMA)
  src/auth/                     createAdminProxy, requireSession 래퍼, requireRole, defineAccess(역할→페이지)
  src/members/                  승인제/초대제 화면 조각과 서버 함수(앱이 RPC 이름을 주입)
  src/date/                     kstDayRange, kstMonthRange, formatKst
  src/realtime/                 useRealtimeTable
  src/ui/                       AppShell, DataTable, FormModal, ConfirmDialog, Toast, KpiCard, Chart
  src/audit/                    감사 로그 뷰어
  src/billing/                  Phase 2 플랜 화면(공용 toss 모듈 호출만)
apps/erp/                      ERP 도메인. src/app/(auth|app)/..., src/server/*, src/theme, src/access.ts
apps/hms/                      HMS 도메인. + src/server/phi/(암호화, 접근 기록 RPC 호출)
apps/sms/                      SMS 도메인
docs/products/_supabase-modular/migrations/1600_erp.sql, 1700_sms.sql   모듈러 조각(정본)
docs/products/admin-suite/supabase/monolith/{erp,hms,sms}/              모놀리스 SQL
tests/rls, tests/e2e, tests/db                                           회귀 테스트
```

| 경계 규칙 | 내용 |
|---|---|
| admin-kit → 앱 의존 금지 | admin-kit는 `erp`, `hms`, `sms` 문자열과 도메인 RPC 이름을 하드코딩하지 않는다. 앱이 설정 객체로 주입한다 |
| 앱 → 앱 의존 금지 | `apps/erp`가 `apps/hms`를 import하지 않는다 |
| 역할 정의 위치 | 앱의 `src/access.ts`(역할 목록, 홈 경로, 라벨, 페이지 매트릭스) 한 곳. `ROLE_HOME`/`ROLE_LABEL` 3중 복제 금지(`docs/reviews/Hospital.md:72`) |
| 쓰기 경로 | Server Action → `requireRole` → 도메인 RPC(사용자 세션). service_role은 프로비저닝, `approve_profile`, Auth Admin 초대에만 |
| 의료정보 | `apps/hms/src/server/phi/`만 복호화 키를 읽는다. 클라이언트 컴포넌트로 암호문·키를 보내지 않는다 |

## 3. 공용 모듈 사용

| 공용 모듈(`SHARED_MODULES.md`) | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 클라이언트 3종, `session_context`, `requireSession` | `packages/admin-kit/src/supabase`, `src/auth` | admin-kit는 래핑만 |
| org | `invite_member`, `accept_invite`, `change_member_role`, `remove_member`, `transfer_ownership`, `approve_profile` | 도메인 RPC 내부, admin-kit members | 도메인 역할은 앱 스키마 테이블(`CORE_SPEC.md` 1.1) |
| audit | `write_audit`(도메인 RPC 내부), 감사 로그 화면 | 도메인 SQL, `src/audit` | |
| storage | 상품 이미지 `org-files/<org>/erp/product/<uuid>` | `apps/erp/src/server/images.ts` | erp만 |
| toss | standard 플랜 구독(Phase 2) | `packages/admin-kit/src/billing` | hms 미사용 |
| webhooks | Toss 웹훅(Phase 2) | 같음 | |
| credits, oauth, llm, fal, weasyprint, sns uploader, automation-core, compliance, jobs, affiliate | 사용 안 함 | - | 모놀리스 lite에서 해당 절 제거(05장 8절) |

## 4. 잡과 워커

해당 없음: 모든 쓰기는 동기 RPC이고 비동기 생성 작업이 없다. 스케줄 작업만 있다.

| 스케줄 | 호출 | 대상 | 주기 |
|---|---|---|---|
| 구독 굴림 | `run_subscription_rollover()`(모놀리스) / `core.run_monthly_credit_grants()`(모듈러) | erp, sms | 매일 00:10 KST |
| 주문 만료 | `expire_stale_payment_orders()` | erp, sms(Phase 2) | 매시 |
| 레이트 리밋 정리 | `purge_rate_limit_buckets()` | 전부 | 매일 |
| 접근 기록 파기 | `public.purge_phi_access_log()` | hms | 매일 03:00 KST |
| 재고 대사 | 상품 수량 = 이동 합 검사(읽기 전용 쿼리) | erp | 매주 |

## 5. AI 라우팅

해당 없음: 세 앱 모두 AI 기능이 없다(`docs/reviews/ERP-Wesite.md:20`, `docs/reviews/Hospital.md:14`, `docs/reviews/School_Management_System.md:14`).

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 "높음"은 ERP 5건, Hospital 5건, School 4건으로 총 14건이다. 보안·데이터 결함 6건은 05장 7절에, 나머지 8건은 여기에 둔다(합계 14).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/ERP-Wesite.md` 3장 #3 | `ERP-Wesite/app/(dashboard)/layout.tsx:8-15`, `middleware.ts:28` | 로그인만 확인, status/role 미검사, 중복 라우트가 가드 밖 | `createAdminProxy`가 모든 경로(matcher 전체)에서 `session_context`로 pending → `/pending`, suspended → 403, 역할 매트릭스 밖 → 403. 레이아웃도 `requireSession`으로 재확인(2중). DB는 `erp.has_access`가 프로필 status active를 요구해 앱 가드가 뚫려도 0행. 중복 라우트는 만들지 않는다 | ADM-06-007, ADM-06-014, 05장 4절 |
| `docs/reviews/Hospital.md` 3장 #1 | `Hospital/src/components/layout/with-page-guard.tsx:11-27` | 클라이언트 PageGuard, 잠금 상태에도 RSC 페이로드 전송 | PageGuard 폐기. 판정은 proxy와 서버 레이아웃에서 끝나고 허용될 때만 children을 렌더한다. 민감 데이터는 RLS·RPC가 역할을 다시 검사하므로 UI 우회로 데이터를 얻을 수 없다 | ADM-06-007, ADM-06-022 |
| `docs/reviews/Hospital.md` 3장 #2 | `Hospital/src/app/api/auth/verify-admin/route.ts:6-9` | 공유 평문 비밀번호 "1234"로 전 역할 우회 | 기능 자체를 없앤다. 임시 권한이 필요하면 admin이 `set_staff_role`로 역할을 바꾸고 감사 로그가 남는다. `OVERRIDE_PASSWORD` 환경변수는 앱 기동 검사에서 "존재하면 기동 실패"로 막는다 | ADM-06-022, ADM-06-038 |
| `docs/reviews/Hospital.md` 3장 #3 | `Hospital/src/proxy.ts:43-48`, `:57`, `:69` | proxy 역할 미검사, 프로필 없으면 admin 기본값 | `session_context`가 null(프로필 없음)이면 로그아웃 후 `/login?error=no_profile`. 역할 기본값을 두지 않고 `my_role` null이면 `/no-access`. 경로 차단은 앱 `access.ts` 매트릭스로 | ADM-06-007 |
| `docs/reviews/Hospital.md` 3장 #5 | `Hospital/src/app/(dashboard)/dashboard/page.tsx:41`, `src/hooks/use-realtime-queue.ts:14` | UTC 날짜로 "오늘" 계산, KST 00~09시 데이터 누락 | admin-kit `kstDayRange()`가 KST 자정을 UTC timestamptz 범위로 반환. 집계 RPC(`dashboard_metrics`, `transition_appointment` 대기번호)는 SQL 안에서 `date_trunc('day', now() at time zone 'Asia/Seoul')`로 경계를 계산. 문자열 날짜 비교 금지 린트 | ADM-06-008, ADM-06-025, ADM-06-027 |
| `docs/reviews/School_Management_System.md` 3장 #1 | nested git status | 커밋된 기능 10개 파일이 작업 트리에서 삭제 | 사용자 결정 A(HEAD 복원). 원본 폴더는 수정하지 않고 `git show 3c19d1e:<path>`로 읽어 `apps/sms`에 이식 대상 목록(07장 2절)대로 옮긴다. 사이드바 링크는 `access.ts`에서 생성하므로 존재하지 않는 경로를 가리킬 수 없다(라우트 존재 테스트) | ADM-06-029, ADM-06-035 |
| `docs/reviews/School_Management_System.md` 3장 #2 | `School_Management_System/middleware.ts:1-76` | 루트 middleware가 로드되지 않아 가드 0 | 앱마다 `src/proxy.ts` 한 파일이 `createAdminProxy`를 export. CI가 `next build` 출력에 Proxy 항목이 있는지 확인하고, E2E가 비로그인 `/admin/dashboard` → `/login` 리다이렉트를 검사 | ADM-06-007, ADM-06-035 |
| `docs/reviews/School_Management_System.md` 3장 #4 | `.gitignore` 삭제, 상위 저장소 이중 추적 | `.env.local` 커밋 위험, 이중 저장소 | 모노레포 루트 `.gitignore`(`.env*`, `.next/`, `node_modules/`) + pre-commit 비밀값 검사. 원본은 `archive/`로 이동하고 nested `.git` 제거(07장 5절) | ADM-06-038 |

## 7. 배포 토폴로지

| 구성 | 배치 | 네트워크 경계 |
|---|---|---|
| `apps/erp` | Vercel 프로젝트 1개(서울 리전 icn1 제안) | 모듈러 DB(`erp` 스키마) 또는 고객사별 모놀리스 |
| `apps/sms` | Vercel 프로젝트 1개 | 모듈러 DB(`sms` 스키마) 또는 학교별 모놀리스 |
| `apps/hms` | 병원마다 Vercel 프로젝트 + Supabase 프로젝트 1쌍(제안: 서울 리전) | 통합 DB와 네트워크·키 공유 없음. service_role 키, `HMS_PHI_KEY_V<n>`는 병원 프로젝트에만 |
| Supabase 모듈러 | `_supabase-modular` 1개 | `config.toml [api].schemas`에 `erp`, `sms` 추가 |
| 프로비저닝 | 운영자 CLI(service_role, 로컬 실행) | 조직 생성 → owner 초대 → 엔타이틀먼트 manual → `register_workspace` |
| 스케줄 | pg_cron(4절) | 공개 크론 라우트 없음(`SECURITY_BASELINE.md` 13장) |

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 동작 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase URL | 공개 | 기동 실패 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon 키 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 프로비저닝, `approve_profile`, Auth Admin 초대 | 비공개 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`(모듈러) / `public`(모놀리스) | 비공개 | 기동 실패 |
| `ADMIN_APP_ID` | `erp` / `hms` / `sms` | 비공개 | 기동 실패 |
| `HMS_PHI_KEY_V1`(… `V<n>`), `HMS_PHI_KEY_CURRENT` | 의료정보 컬럼 암호화(AES-256-GCM, 32바이트 base64) | 비공개, hms만 | 기동 실패(0키 폴백 금지) |
| `OVERRIDE_PASSWORD` | 금지 변수 | - | 존재하면 기동 실패 |
| `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET`, `NEXT_PUBLIC_TOSS_CLIENT_KEY` | Phase 2 구독(erp, sms) | 시크릿 비공개 | 결제 기능 켜졌을 때만 필수 |
