# CLAUDE.md: 신비로운AI

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md` → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` 4절 |
| 3 | UI 작업이면 `docs/products/_design-guide/DESIGN_PRINCIPLES.md`, `REFERENCES.md` astro-ai 절 |

원본 기획(`Astro AI/기획안/`, `FortuneDocs/`)은 참고용이다. 이 폴더와 충돌하면 이 폴더가 이긴다.

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role 키 | 서버 파일(Route Handler, `src/server/`, 워커)에서만. `NEXT_PUBLIC_` 금지. `createAdminClient`는 권한 확인 뒤에만 생성 |
| 크레딧 선차감 | `POST /api/readings`, `POST /api/readings/[id]/renders`에서만 `consume_credits`. 잡 생성 전에 차감, 이후 실패는 `refund_credits` 또는 `fail_job` 자동 환불 |
| LLM 키 | `astro-worker`에만. Vercel 환경에 두지 않는다 |
| 개인정보 | 실명·생년월일시·질문·수신 이메일은 `packages/astro-crypto`로 암호화해 `*_ciphertext`에만. 로그와 LLM 요청에 평문 금지(LLM에는 `{{호칭}}` 토큰) |
| 수치 | 오행·십신·대운은 `packages/saju-engine` 값만. LLM 출력 수치는 버린다 |
| 코어 재정의 금지 | 플랜·크레딧·결제·잡·감사 테이블과 함수를 `astro`에 만들지 않는다. `core.*` ALTER 금지 |
| 수정 금지 | `_platform-core/`, `_supabase-modular/`의 다른 파일, 공용 렌더 서비스. 필요하면 06장 6절 요청 |
| 마이그레이션 | `supabase/`는 AS-06-001 담당만 수정 |
| 문구 | 01장 6.4절 금지 문구(가상 후기, 허위 수치, 의료·금융 단정) |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 소유 작업 |
|---|---|---|
| `packages/saju-engine/` | 만세력 엔진(SPEC, fixtures, src, scripts) | 004, 005, 024(`src/demo/`), 030 |
| `packages/astro-report/` | prompts, schema, rules / theme / templates / eval | 011 / 013 / 014 / 033 |
| `packages/astro-crypto/` | PII 암호화 | 006 |
| `apps/astro-ai/src/app/api/<폴더>/` | Route Handler | subjects·consents 007, billing 008, auth 009, readings 010, deliveries 016, admin 022, demo 024, account 026 |
| `apps/astro-ai/src/app/` 화면 | (auth) 003, dashboard/subjects 018, dashboard/readings 020, dashboard 나머지 021, admin 022, (marketing) 023, legal 025 |
| `apps/astro-ai/src/components/` | ui 017, chart 019, subjects 018, reading 020 |
| `apps/astro-worker/src/` | index·generate·sweeper 012, render 015, delivery 016, purge 026, observability 034 |
| `supabase/` | migrations·tests | 001, 002 |
| `e2e/` | flows 028, billing 029 |

## 4. 코어 사용 규칙

| 항목 | 방법 |
|---|---|
| 세션 | 모든 Route Handler 첫 줄 `const ctx = await requireSession('astro')`. 조직은 `ctx.org.id`만 사용, 요청 본문의 `org_id` 무시 |
| 어드민 | `ctx.platform_role === 'platform_admin'` 확인 후 admin 클라이언트. 모든 쓰기 `auditAsService` |
| 크레딧 | `credits.consume({ appId: 'astro', idempotencyKey: 'consume:astro:<request_id>', ref: { type: 'reading', id } })`. 단가는 `src/server/pricing.ts` |
| 잡 | `jobs.enqueue({ queue: 'astro.reading', jobType: 'astro.reading.generate', creditLedgerId, idempotencyKey: 'job:astro:<request_id>', maxAttempts: 2 })` |
| 워커 | `runWorker` + `heartbeat`. 최종 실패는 `fail_job(retryable=false)`. 리딩 상태는 전이 표(05장 3절)대로만 |
| 사용자 RPC | `rpc('cancel_reading')` 하나. `preferences`만 사용자 세션으로 쓴다 |
| 레이트 리밋 | `src/server/ratelimit`(`core.rate_limit_hit`, 키 `astro:<route>:<id>`) |
| Storage | PDF는 `exports/<org_id>/astro/pdf/<uuid>.pdf`, 다운로드는 7일 서명 URL |
| 감사 | `subject.create/update/delete`, `reading.cancel/delete`, `account.export/delete`, `payment.refund`, `credits.admin_grant`, `delivery.retry` |
| 스키마 전환 | `SUPABASE_DB_SCHEMA`(core/public), `ASTRO_DB_SCHEMA`(astro/public) |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16.2.x, React 19, Tailwind v4, shadcn/ui, Zustand(리딩 스테퍼만), Node 22 워커. `latest` 태그 금지, lockfile 커밋 |
| 런타임 | Route Handler는 `export const runtime = 'nodejs'`. Edge 금지 |
| 검증 | 모든 입력 zod `strict()`. `any` 금지 |
| 타입 생성 | `supabase gen types typescript --local --schema core,astro > apps/astro-ai/src/types/supabase.ts`(모놀리스는 `--schema public`) |
| 린트 | `pnpm lint`, `pnpm typecheck` |
| 디자인 토큰 | `apps/astro-ai/src/styles/tokens.css`(03장 4.3절). 컴포넌트에 hex 금지, 이모지 아이콘 금지(Lucide) |
| HTML | 리포트 템플릿은 모든 텍스트 escape, 외부 URL 0 |
| 오류 | 장애를 숨기지 않는다. 실패와 환불 여부를 사용자에게 보여 준다(03장 5절) |

## 6. 테스트와 완료 조건

| 명령 | 목적 |
|---|---|
| `pnpm --filter saju-engine test` | 골든 100건 |
| `node docs/products/_tools-sqlcheck/check.mjs mod ...0000~0007 seed 1100_astro.sql` | 모듈러 SQL |
| `node docs/products/_tools-sqlcheck/check.mjs mono 0001_core_lite.sql 0002_astro_domain.sql seed.sql` | 모놀리스 SQL |
| `pnpm test:rls` | RLS 회귀(AS-06-002) |
| `pnpm e2e` / `pnpm e2e:billing` | 핵심 5플로우 / Toss 테스트 키 결제 |
| `pnpm lhci` | 랜딩 Lighthouse |

완료 조건은 `06_AGENT_PLAN.md` 7절.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: 크레딧 RPC를 브라우저에서 호출, 읽고-빼고-쓰는 차감, 웹훅만으로 지급, 클라이언트 금액 신뢰, `FOR ALL` 정책, role 확인 없는 service_role 액션, broadcast 진행률, 업로드 CSS를 렌더러에 투입, QuickChart 같은 외부 렌더러로 개인정보 전송, 생년월일시 평문 저장, 메모리 레이트 리밋, `\b` 한글 금지어 매칭, Edge Function 생성 경로, Puppeteer, 가상 후기·평점·카운터.
