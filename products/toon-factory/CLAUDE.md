# CLAUDE.md: Toon Factory

개발 에이전트 지침. 원본 `Toon-Factory/Claude.md`를 대체한다. 주석, 문서, UI 문구는 한국어로 쓰고 식별자는 영어로 쓴다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md` → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` 4절 |
| 3 | UI 작업이면 `docs/products/_design-guide/DESIGN_PRINCIPLES.md`, `design-system/toon-factory/MASTER.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| 비밀 | `SUPABASE_SERVICE_ROLE_KEY`, `FAL_KEY`, `TOSS_SECRET_KEY`, 빌링키 암호화 키는 서버·워커에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 | 유료 작업은 `consume_credits` 선차감 → 제품 행 → `enqueue_job`. 실패 환불은 `fail_job`/`refund_credits`. 브라우저에서 크레딧 RPC 호출 금지 |
| 결과물 | 최종 PNG/ZIP/스트립/MP4는 워커만 만든다. 브라우저 다운로드용 렌더 코드 금지. 워터마크는 `exports.watermark`만 믿는다 |
| 에셋 | 원본·편집용 경로를 클라이언트로 보내지 않는다. 서명 URL은 `toon.org_asset_access` 통과분만 |
| AI 표시 | 메타데이터 표시는 끌 수 없다. 가시 표기 해제는 사용자 확인 + 감사 로그 |
| 코어 | 플랜·구독·크레딧·결제·잡 테이블을 제품 스키마에 만들지 않는다. `core.*` ALTER 금지. `_platform-core`, `_supabase-modular`의 다른 파일 수정 금지(6장 6절 요청으로) |
| DB 변경 | SQL은 Fable 작업(TN-06-001, 002, 038)만. 모놀리스 파일은 변환 스크립트로만 재생성 |

## 3. 디렉토리와 소유 경계

`apps/toon/`(앱), `packages/toon-doc/`(문서 스키마·렌더·레이아웃·콘티 변환·프리셋·템플릿), `services/toon-worker/`(잡 핸들러, 미디어, 스케줄), `tools/`(카탈로그 등록, 모놀리스 변환, 문구 검사), `supabase/`. Fabric 코드는 `apps/toon/src/components/canvas/`와 `packages/toon-doc/src/render/`에만 둔다. 상태 원천은 `editorStore` 문서이고 Fabric은 뷰다. 작업별 소유 디렉토리는 06장 2절 표가 정본이다.

## 4. 코어 사용 규칙

| 용도 | 사용법 |
|---|---|
| 세션 | Route Handler 첫 줄 `const ctx = await requireSession('toon')`. 역할은 `ctx.org.role`, 기능은 `toon.plan_features(org)` |
| 가입 | `signUp({ options: { data: { signup_app: 'toon' } } })`. SSO 사용자는 `bootstrap_app_for_org('toon')` |
| 크레딧 | `credits.consume({ orgId, amount: priceOf('toon', action), appId: 'toon', reason, ref: { type: 'job', id: requestId }, idempotencyKey: 'consume:toon:' + requestId })` |
| 잡 | `jobs.enqueue({ queue: 'toon.ai' 또는 'toon.render', jobType, payload, creditLedgerId, idempotencyKey: 'job:toon:' + requestId })` |
| 콘텐츠 쓰기 | 서버에서도 사용자 세션 클라이언트로(RLS, 한도 트리거 적용). service_role 콘텐츠 쓰기는 운영 도구만 |
| 감사 | 다운로드, AI 가시 표기 해제, 카탈로그 검증·공개, 에셋 보관 |
| 레이트 리밋 | `rate_limit_hit('toon:<route>:<org_id>', ...)`, 값은 01장 5절 |
| Realtime | `core.jobs` 구독. 별도 채널 금지 |

## 5. 코드 규칙

| 항목 | 내용 |
|---|---|
| 스택 | Next.js 16, TypeScript strict(`any` 금지), Tailwind v4, shadcn/ui, Fabric 6, Zustand 5 + immer, zod. 버전 고정, `latest` 금지 |
| 입력 | Route Handler 입력은 zod. 문서는 `packages/toon-doc` 스키마로 검증 |
| 성능 | 캔버스 갱신은 rAF로 묶고, 저장은 1.5초 디바운스(최대 10초) |
| 타입 생성 | `supabase gen types typescript --local --schema core,toon > packages/toon-doc/src/db-types.ts` |
| 디자인 | 색·서체·간격은 CSS 변수(토큰)로만. 아이콘은 Lucide. 이모지 금지 |
| 문구 | 01장 6.5절 금지 문구 사용 금지. 오류 문구는 무엇이 잘못됐고 어떻게 고치는지 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -r build && pnpm -r typecheck && pnpm -r lint` | 0 오류 |
| `node docs/products/_tools-sqlcheck/check.mjs ...` | 모듈러·모놀리스 OK |
| `pnpm test:rls` | TN-06-002 전 항목 통과 |
| `pnpm test` | 에디터 커버리지 80%, 골든 이미지 차이 0.5% 이하 |
| `pnpm test:e2e` | 핵심 플로우와 결제 E2E(Toss 테스트 키) 통과 |
| 금지 문구 검사 | `tools/copy-lint` 통과 |

## 7. 금지 패턴

07장 4절 요약: 클라이언트 결과물 렌더, 공개 버킷 프리미엄 에셋, Fabric `toObject` 저장, 스톡 변형 카탈로그, fal 안전 필터 끄기, 키 없을 때 placeholder, 크레딧 RPC 직접 호출, 웹훅 서명 생략, `customerKey = Date.now()`, 셀프 플랜 변경 정책, localStorage 잠금 해제, 프로필 없으면 admin, 정책 안 `org_members` 직접 조회, org_id 없는 FK, 사용자 파일명 경로, `.env` 커밋.
