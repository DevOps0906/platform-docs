# CLAUDE.md: NOMAD Commerce

개발 에이전트 지침. 이 문서와 `_platform-core/SECURITY_BASELINE.md`가 원본 프로젝트 관행보다 우선한다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md` → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` |
| 3 | UI 작업이면 `docs/products/_design-guide/` 전부 |
| 4 | DB 정본 `docs/products/_supabase-modular/migrations/1400_commerce.sql` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 서버(Route Handler, 워커)에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 선차감 | 유료 작업은 Route Handler 안에서 `consume_credits` → 작업 → 실패 시 `refund_credits`. 별도 차감 API를 만들지 않는다 |
| 플랜·모델 | `entitled_plan_code` + `plans.features`로만 판정. 요청 바디·쿠키의 plan/role/model은 무시 |
| 마켓 키 | `core.encrypted_credentials`에만. 응답은 마스킹, 로그 금지, 복호화는 워커 upload에서만 |
| compliance | FAIL은 내보내기·업로드 불가, WARN은 `acknowledge_compliance_warning` 후에만 |
| 생성 금지 | AI 후기·평점·"전문가 추천", "단순 변심 반품 불가", "이 제품은 건강기능식품이 아닙니다" 자동 문구, 허위 수치 카피 |
| 코어 | `core.*`를 ALTER하거나 commerce 스키마에 플랜·크레딧·잡 테이블을 다시 만들지 않는다. `_platform-core/`, `_supabase-modular/`의 다른 파일을 수정하지 않는다(필요하면 06장 6절 요청) |
| 원본 | sellingstudio 등 원본 코드는 07장 "이식" 항목만, 2절 수정과 함께 옮긴다 |

## 3. 디렉토리와 소유 경계

| 경로 | 내용 | 소유 작업 |
|---|---|---|
| `packages/commerce-domain/` | 슬롯, phase, 규격, features, 단가, 마진 | CM-06-006 |
| `packages/commerce-compliance/` | 금지어 매처 | CM-06-017 |
| `packages/commerce-net/` | 안전 fetch | CM-06-008 |
| `packages/commerce-sourcing/{amazon,excel}/` | 소싱 | CM-06-018, 019 |
| `packages/commerce-markets/{coupang,smartstore}/` | 마켓 어댑터 | CM-06-021, 022 |
| `apps/nomad-commerce/app/api/<영역>/` | Route Handler | 06장 2절 표 |
| `apps/nomad-commerce/app/(app)/<화면>/`, `components/<영역>/` | 화면 | CM-06-027~031 |
| `services/commerce-worker/src/<영역>/handler.ts` | 워커 핸들러(자동 로드) | CM-06-012~024 |

자기 작업의 소유 경로 밖 파일은 수정하지 않는다. 공용 인덱스 파일을 만들지 않는다.

## 4. 코어 사용 규칙

| 용도 | 쓰는 것 |
|---|---|
| 세션 | `requireSession('commerce', { roles })` → `session_context` 1회 |
| 크레딧 | `credits.consume/refund/withCredits`, 멱등 키 `consume:commerce:<request_id>` |
| 잡 | `jobs.enqueue({ queue: 'commerce.<type>', jobType, idempotencyKey: 'job:commerce:<request_id>', creditLedgerId })`. 상세페이지는 `detail_pages`(waiting)만 쓰고 enqueue는 디스패처가 한다 |
| 자격증명 | `CredentialVault.put/get`, 연결 해제는 `revoke_credential` |
| 감사 | 마켓 계정 추가·삭제, 내보내기, 환불은 `auditAsService`. WARN 확인은 RPC가 기록 |
| Storage | `<org_id>/commerce/<entity>/<uuid>.<ext>`, 내보내기는 `exports` 버킷 서명 URL 7일 |
| 오류 | SQLSTATE → HTTP는 `04_API.md` 7절 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16.2.7, React 19.2, Tailwind v4, shadcn/ui, Zustand 5(UI 상태만), zod 4, @xyflow/react 12(Phase 2), Node 22 워커 |
| Next 16 | `cookies()`/`headers()`/`params` await, 미들웨어는 `proxy.ts` |
| 타입 | `any` 금지, `supabase gen types typescript --schema core,commerce > apps/nomad-commerce/types/supabase.ts` |
| 린트 | `no-explicit-any`, `no-console`(로거 사용) |
| 외부 호출 | `AbortSignal.timeout`, 응답은 zod 검증 |
| 컴포넌트 | 300줄 이하, 서버 컴포넌트 우선 |
| 디자인 토큰 | `apps/nomad-commerce/app/globals.css`의 `@theme`(03장 4.3 색·서체). 하드코딩 hex 금지 |
| 의존성 | 버전 고정, lockfile 커밋 |

## 6. 테스트와 완료 조건

| 검사 | 명령 |
|---|---|
| 타입·린트·빌드 | `pnpm -F nomad-commerce typecheck && pnpm -F nomad-commerce lint && pnpm -F nomad-commerce build`, 워커 동일 |
| 단위 | `pnpm -F @nomad/commerce-domain test` 등 패키지별 |
| SQL | `cd docs/products/_tools-sqlcheck && node check.mjs mod <0000~0007> ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1400_commerce.sql` |
| RLS | `tests/rls/`(CM-06-003) |
| E2E | `tests/e2e/billing/`, `tests/e2e/flows/` |

완료 정의는 `06_AGENT_PLAN.md` 7절.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: 분리된 크레딧 차감, 비원자 차감, 바디의 plan/model, 무서명 웹훅과 `USING(true)`, 쿠키 권한, 평문 키 API, 사용자 URL 직접 fetch와 원문 HTML 저장, 요청의 테이블 이름, 한글 `\b` 정규식, `globalThis` 잡, 공개 AI 프록시, 클라이언트 한도 판단, localStorage 키, LLM 추정 환율, SSE + 브라우저 큐, env 단일 마켓 키, `FOR ALL` 정책, 반품 불가·건기식 부정 자동 문구, AI 후기, 콜백 오픈 리다이렉트, 0키 폴백, mock 응답으로 장애 숨기기.
