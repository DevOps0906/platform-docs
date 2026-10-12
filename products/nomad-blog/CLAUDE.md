# CLAUDE.md: NOMAD Blog

개발 에이전트 지침. 작성일 2026-10-12. 이 문서와 `docs/products/_platform-core/SECURITY_BASELINE.md`가 충돌하면 SECURITY_BASELINE이 이긴다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md`(특히 4장 요금, 6장 법·금지 문구), `02_ARCHITECTURE.md`, `04_API.md`, `05_DATA_MODEL.md` |
| 3 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 소유 디렉토리 |
| 4 | 이식 대상이면 `07_SOURCE_MIGRATION.md` 2절(수정할 점)과 4절(복사 금지) |
| 5 | UI 작업이면 `_design-guide/DESIGN_PRINCIPLES.md`, `03_SCREENS_UX.md` 4절 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role 키 | 서버 파일(Route Handler, `src/server/**`, 워커)에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 선차감 | AI 호출 전 `consume_credits`, 실패 시 환불. 잡은 `p_credit_ledger_id`로 연결 |
| 코어 재정의 금지 | 인증, 조직, 크레딧, 결제, 웹훅, OAuth, 자격증명, 잡, Storage, 감사, 제휴 테이블·함수를 blog에 다시 만들지 않는다 |
| 수정 금지 | `_platform-core/`, `_supabase-modular/`의 다른 파일, `packages/core-*`. 필요하면 06장 6절 요청 |
| 대가성 문구 | 제휴 링크·스폰서 원고에는 글 상단 문구가 반드시 들어간다. 끄는 옵션, 숨김 스타일을 만들지 않는다 |
| 브랜드커넥트·자동 게시 | 위험 동의(owner/admin, 고지문 버전) 없이 Playwright 작업을 실행하지 않는다. CAPTCHA 우회·봇 감지 우회·프록시 순환 금지 |
| 생성 콘텐츠 | 사용자 메모 없는 체험담, 지어낸 수치, 가상 후기 금지(01장 6.5절) |
| 원본 | 원본 폴더를 고치지 않는다. YSM은 `git show 5f6d262:<경로>`로만 읽는다 |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 담당 작업 |
|---|---|---|
| `src/app/(marketing)/`, `(auth)/`, `(app)/*` | 화면 | 06장 표 |
| `src/app/api/**`, `src/app/r/` | Route Handler | 06장 표 |
| `src/server/{session,entitlements,ai,publish,affiliate,channels,compliance,brandconnect,billing,automation}/` | 서버 서비스 | 디렉토리별 1개 작업 |
| `src/features/editor/` | TipTap 확장 | BL-06-007 |
| `packages/blog-render/` | 렌더·sanitize·대가성 문구 | BL-06-008 |
| `workers/blog-worker/src/{runtime,channels/*,handlers/*,observability}/` | 워커 | 06장 표 |
| `supabase/` | 마이그레이션, 테스트 | BL-06-001, BL-06-028 |

다른 작업의 디렉토리는 `index.ts` 공개 인터페이스만 import한다. 웹 코드는 워커 코드를 import하지 않는다.

## 4. 코어 사용 규칙

| 상황 | 쓸 것 |
|---|---|
| Route Handler 진입 | `requireSession('blog', { roles })` → zod 검증 |
| 플랜 판정 | `src/server/entitlements`(내부에서 `entitled_plan_code` + `plans.features`). 클라이언트 판정은 UX 보조 |
| AI 호출 | llm gateway `complete`/`withCredits`, purpose는 `02_ARCHITECTURE.md` 5절 |
| 잡 | `enqueue_job(org, 'blog', queue, job_type, payload, ..., p_idempotency_key='job:blog:<request_id>')`. 큐 `blog.ai`, `blog.publish`, `blog.browser` |
| 발행 행 | service_role INSERT. DB 게이트(컴플라이언스, 동의, 계정 상태)가 거부하면 SQLSTATE를 04장 7절로 매핑 |
| 비밀 | `CredentialVault.put/get`. 페이로드에는 `credential_id`만 |
| 제휴 | `AffiliateApi.createShortLink(sourceApp 'blog', sourceRef post id)` + `blog.post_affiliate_links` INSERT. 문구는 `effective_disclosure(org, provider, 'blog_top')` |
| 감사 | 사용자 세션은 제품 RPC/`write_audit`, 서버는 `auditAsService` |
| 쓰기 결과 | Supabase 쓰기의 `error`를 항상 검사하고 0행 갱신을 오류로 취급 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16 App Router, React 19, TypeScript strict, Tailwind v4, shadcn/ui, TipTap, zod, TanStack Query, Playwright. `latest` 금지, lockfile 커밋 |
| 동적 라우트 | `params`는 Promise로 받고 await |
| 타입 생성 | `supabase gen types typescript --local --schema core,blog > src/types/supabase.ts`. Supabase 결과를 `any`로 캐스팅하지 않는다 |
| 디자인 토큰 | `src/styles/tokens.css`(03장 4.3절). 컴포넌트 안 hex 금지, 아이콘은 lucide, 이모지 금지 |
| 파일 크기 | 컴포넌트 파일 400줄 이하 |
| 로그 | 구조화 로거, 비밀·쿠키·원고 전문 금지 |
| 문구 | 사용자 노출 문구는 한국어, 오류는 원인과 해결 방법 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -w tsc --noEmit && pnpm -w lint && pnpm -w build` | 0 오류 |
| `node docs/products/_tools-sqlcheck/check.mjs mod <0000~0007> <seed> <1300_blog.sql>` | OK |
| `node docs/products/_tools-sqlcheck/check.mjs mono <0001_core_lite> <0002_blog_domain> <seed>` | OK |
| `pnpm test:rls`(BL-06-028) | 모듈러·모놀리스 0 실패 |
| `pnpm test:e2e`(BL-06-029, 030, 037) | 결제·발행·생성 통과, 대가성 문구 포함률 100% |
| 디자인 | `DESIGN_PRINCIPLES.md` 7단계 체크리스트 |

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약:

| 금지 | 대체 |
|---|---|
| `x-internal-call`, 자기 HTTP 호출 | 잡, 함수 직접 호출 |
| Route Handler 안 Playwright | 워커 |
| 세션 쿠키·비밀번호·키 평문 저장, 전역 env 제휴 키, 0키 폴백 | `encrypted_credentials`, 키 없으면 기동 실패 |
| 웹훅 서명 선택 검증, orderId 파싱 | 공용 webhooks, `payment_orders` |
| 발행 불확실을 성공 처리 후 자동 재시도 | `unconfirmed` + 사용자 확인 |
| 봇 감지 우회, CAPTCHA 풀이, 프록시 순환 | 일반 입력, CAPTCHA 시 중단 |
| 가상 후기 프롬프트, 폴백 가짜 데이터, Mock 응답 | 금지 지시, 오류 표시와 환불 |
| sanitize 없는 `dangerouslySetInnerHTML` | 서버 렌더 + sanitize |
| 사용자 지정 URL 무검사 fetch | 공인 https, 리다이렉트 제한 |
| 대시보드 더미 배열, 난수 지표 | 실데이터 또는 빈 상태 |
| Mock 로그인, 기본 역할 admin | `requireSession`, 프로필 없으면 로그아웃 |
