# CLAUDE.md: Admin Suite

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `README.md`, `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | 맡은 작업의 SQL: `_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql`, `supabase/monolith/<app>/` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | 서버 파일에서만. 프로비저닝, `approve_profile`, Auth Admin 초대, 스케줄에만 쓴다. 도메인 쓰기는 사용자 세션 RPC |
| 크레딧 | 해당 없음. 크레딧 RPC를 호출하지 않는다 |
| 코어 재정의 금지 | 인증, 조직, 감사, storage, toss, webhooks는 `_platform-core`를 쓴다. admin-kit는 래퍼만 |
| 수정 금지 | `_platform-core/`, `_supabase-modular/`의 다른 파일, 원본 프로젝트 폴더 |
| hms 격리 | hms 코드·키·데이터를 통합 DB나 다른 앱과 섞지 않는다. hms 조각을 만들지 않는다 |
| 역할 | 관리자 역할은 core owner/admin에서 파생. 도메인 역할은 도메인 테이블. 어떤 경로로도 사용자가 자기 역할을 바꿀 수 없다 |

## 3. 디렉토리와 소유 경계

`02_ARCHITECTURE.md` 2절, `06_AGENT_PLAN.md` 1절 요약: `packages/admin-kit/src/{supabase,auth,members,date,realtime,ui,audit,billing}`는 앱 이름을 모른다. `apps/<app>/src/access.ts`가 역할·홈·매트릭스의 유일한 정의. 화면 디렉토리와 `src/server/<도메인>.ts`는 같은 작업이 소유. 작업 표에 없는 디렉토리를 만지지 않는다.

## 4. 코어 사용 규칙

| 항목 | 규칙 |
|---|---|
| 진입부 | 모든 Route Handler/Server Action 첫 줄 `requireSession(appId)` → `requireRole(appId, roles)` |
| 프록시 | 앱 `src/proxy.ts`는 `createAdminProxy(access)` 한 줄. 역할 기본값 금지, 프로필 없음 로그아웃 |
| 가입 | ERP `signUp({ options: { data: { signup_app: 'erp', full_name } } })`. HMS/SMS는 초대만 |
| 감사 | 도메인 RPC가 `write_audit`를 부른다. 서버 직접 쓰기(프로비저닝)는 service INSERT로 남긴다 |
| 의료정보 | `apps/hms/src/server/phi/`만 `HMS_PHI_KEY_*`를 읽는다. 민감 읽기는 RPC(`get_patient_detail`, `get_patient_chart`, `list_lab_worklist`)만, 열람 사유 필수. 목록 화면 렌더 시 `log_phi_access('view.<screen>')` |
| 날짜 | `kstDayRange()` 등 admin-kit date만. `toISOString().split('T')` 금지 |
| Realtime | `useRealtimeTable`만, 채널명 `<app>:<org>:<entity>` |
| 결제 | Phase 2. 공용 toss 모듈. `confirm_payment_order` PM001이면 별도 호출로 `fail_payment_order`를 부른다 |

## 5. 코드 규칙

| 항목 | 값 |
|---|---|
| 스택 | Next.js 16, React 19, Tailwind 4, `@supabase/ssr` 0.12, zod, lucide-react. `latest` 태그 금지, lockfile 커밋 |
| 린트 | `pnpm lint`(`eslint .`), `no-explicit-any` 오류 |
| 타입 생성 | `pnpm db:types --app erp|sms|hms` (모듈러 `--schema core,erp` 등, 모놀리스 public) |
| 디자인 토큰 | `apps/<app>/src/theme/tokens.css`(03장 4.3절). 컴포넌트 안 hex 하드코딩 금지, 이모지 아이콘 금지, `alert()` 금지 |
| SQL 변경 | 조각을 고치면 `tools/admin-suite/to-monolith.py`로 erp/sms 모놀리스를 재생성하고 체커를 돌린다 |

## 6. 테스트와 완료 조건

`06_AGENT_PLAN.md` 7절. 명령:

```
cd docs/products/_tools-sqlcheck
node check.mjs mod ../_supabase-modular/migrations/0000_core_extensions_and_schema.sql ... 0007_core_function_privileges.sql ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1600_erp.sql ../_supabase-modular/migrations/1700_sms.sql
node check.mjs mono-hms ../admin-suite/supabase/monolith/hms/migrations/0001_core_lite.sql ../admin-suite/supabase/monolith/hms/migrations/0002_hms_domain.sql ../admin-suite/supabase/monolith/hms/seed.sql
pnpm test:rls && pnpm test:e2e && pnpm -r build && pnpm -r typecheck && pnpm lint
```

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: OVERRIDE 비밀번호·verify-admin, 프로필 없으면 admin, 클라이언트 PageGuard, 정책 안 자기참조 재귀와 `FOR ALL`, 브라우저 직접 update, 읽기-계산-쓰기 재고 차감, 가짜 상태·하드코딩 KPI, UTC 날짜 문자열, 루트 middleware, 빈 값 0 대체, 실 URL·키 노출, `.env` 커밋, `as any`.
