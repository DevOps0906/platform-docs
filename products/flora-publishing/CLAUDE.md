# CLAUDE.md: FLORA Publishing

개발 에이전트 지침. 이 파일과 01~07장이 원본 프로젝트(`Flora-v2/`, `flora/`, `flora-publisher/`, SellingDocs) 문서보다 우선한다. 모든 사용자 노출 문구는 한국어.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md`(기능 ID, 단가, features 키) → `02_ARCHITECTURE.md`(경계, 잡) → `04_API.md`(계약) → `05_DATA_MODEL.md`(테이블, RLS) |
| 3 | 화면 작업이면 `03_SCREENS_UX.md`와 `docs/products/_design-guide/DESIGN_PRINCIPLES.md` |
| 4 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 이식 대상(`07_SOURCE_MIGRATION.md` 2절, 금지 패턴 4절) |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 서버 파일(Route Handler, 워커, 엔진)에서만. `NEXT_PUBLIC_`에 비밀 금지 |
| 크레딧 선차감 | 유료 동작은 `consume_credits` → 처리 → 실패 시 `refund_credits`(잡은 `fail_job` 자동 환불). 차감 없이 LLM·이미지·렌더 호출 금지 |
| 코어 재정의 금지 | 인증, 조직, 크레딧, Toss, 웹훅, LLM, fal, 잡, Storage, 감사, 레이트 리밋은 `packages/core-*`를 import만. 같은 기능을 제품 안에 다시 만들지 않는다 |
| 수정 금지 | `_platform-core/`, `_supabase-modular/`의 다른 파일, `packages/core-*`. 필요하면 06장 6절 코어 요청에 적는다 |
| DB 변경 | `1000_publishing.sql`만, PB-06-001 담당만. 모놀리스 `0002`는 변환 스크립트로 재생성 |
| 서버가 정본 | 플랜·한도·워터마크 판정은 서버. 클라이언트 잠금은 UX 보조 |
| 렌더 위치 | WeasyPrint는 `services/render-weasyprint`에서만. Vercel 코드에서 PDF를 만들지 않는다 |
| mock 금지 | 실패를 성공처럼 반환하지 않는다. 실패와 환불을 사용자에게 보여 준다 |

## 3. 디렉토리와 소유 경계

| 위치 | 책임 | 소유 작업 |
|---|---|---|
| `web/src/app/api/<리소스>/` | Route Handler | 06장 2절 표의 리소스별 단일 작업 |
| `web/src/server/{http,pricing,features,prompts,personas,sanitize,books}/` | 서버 공용 코드 | 007, 008, 008, 011, 012, 013, 010 |
| `web/src/features/{wizard,editor,books,finish,personas,settings,billing,landing}/` | 화면 | 021, 022, 023, 023, 023, 023, 009, 024 |
| `worker/src/handlers/` | TS 잡(LLM, 표지, 웹훅, purge) | 014, 019, 026, 036 |
| `engine/app/` | 파싱, HTML 조립, 프리셋, ePub, 렌더 잡 | 003, 015, 016, 018, 017 |
| `services/render-weasyprint/` | 공용 PDF 렌더 | 004 |
| `supabase/` | 마이그레이션, 테스트 | 001, 029 |

다른 작업의 디렉토리에 파일을 만들지 않는다. 공용 설정(`web/package.json` 등)은 PB-06-002에 요청한다.

## 4. 코어 사용 규칙

| 상황 | 쓰는 것 |
|---|---|
| Route Handler 진입 | `const ctx = await requireSession('publishing')` 후 zod 검증, `rate_limit_hit` |
| 기능 게이팅 | `web/src/server/features`의 `feature(ctx, key)`(키 없으면 Free 기본값, 01장 4.4절) |
| 크레딧 | `credits.consume({ idempotencyKey: 'consume:publishing:<request_id>' })`, 동기 호출은 `withCredits` |
| 잡 | `jobs.enqueue({ queue: 'publishing.llm'|'publishing.media'|'publishing.doc'|'publishing.render'|'publishing.events', jobType, idempotencyKey: 'job:publishing:<request_id>', creditLedgerId })` |
| 진행률 | 클라이언트는 `core.jobs`, `publishing.generation_runs`, `publishing.sections` Realtime 구독 |
| 웹훅 비밀 | `CredentialVault.put/get`(provider `outbound_webhook`), 평문 컬럼 금지 |
| 감사 | 사용자 경로는 `write_audit`(RPC 내부에서 이미 기록), 서버 경로(환불, 운영자 조정, 탈퇴)는 service INSERT |
| Storage | 경로는 `orgPath({ orgId, appId: 'publishing', entity, ext })`만. 사용자 파일명은 표시용 컬럼에만 |
| DB 스키마 | 모듈러는 `supabase.schema('publishing')`, 코어는 `SUPABASE_DB_SCHEMA` |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16.2.x, React 19.2, TS strict, Tailwind v4, shadcn v4(`asChild` 없음, `buttonVariants()` + `<Link>`), Node 20, Python 3.11, FastAPI 0.115 |
| 의존성 | 버전 고정 + lockfile 커밋. `latest` 금지 |
| 린트 | ESLint flat, `ruff`. raw `fetch`는 `web/src/lib/api` 밖에서 금지(린트 규칙) |
| 타입 생성 | `supabase gen types typescript --local --schema core,publishing > web/src/types/supabase.ts` |
| 입력 검증 | 모든 경계 zod(TS) / pydantic(Python). `any`로 Supabase 타입 우회 금지 |
| 디자인 토큰 | `design-system/flora-publishing/MASTER.md`와 Tailwind 테마 변수. 컴포넌트 안 hex 금지. 아이콘은 Lucide |
| 스트리밍 | fetch POST + ReadableStream. EventSource 금지 |
| 문구 | 실패 문구는 원인과 다음 행동(환불 여부 포함). 금지 문구는 01장 6절 |

## 6. 테스트와 완료 조건

| 명령 | 기대 |
|---|---|
| `npm run lint && npx tsc --noEmit && npm run build` (web, worker) | 통과 |
| `pytest` (engine, services/render-weasyprint) | 통과 |
| `node check.mjs mod <0000~0007> seed.sql 1000_publishing.sql` (`docs/products/_tools-sqlcheck`) | 전부 OK |
| `node check.mjs mono 0001_core_lite.sql 0002_publishing_domain.sql seed.sql` | 전부 OK |
| RLS 스모크(`supabase/tests/`) | 05장 9절 항목 전부 통과 |
| 결제 E2E, 핵심 플로우 E2E | PB-06-030, PB-06-037 통과 |

완료 정의 전체는 06장 7절.

## 7. 금지 패턴

07장 4절 요약: `FOR ALL` 정책, `'1234'`/localStorage 잠금해제, 이메일 하드코딩 관리자, 무인증 LLM·업로드·내보내기, 빈 JWT secret 허용, 웹훅 서명 생략, 비원자 차감, 사용자 파일명을 경로로, 서버가 사용자 URL fetch, url_fetcher 무제한, 범용 AI 프록시, 전역 n8n 키, escape 없는 HTML/XML, mock 폴백, async 안 동기 호출, 마지막 1,000자 다듬기, EventSource POST, localStorage를 정본으로, 실키 `.env` 커밋, Windows 폰트 경로, 허위 수치.
