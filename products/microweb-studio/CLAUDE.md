# CLAUDE.md: Microweb Studio

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | `docs/products/_design-guide/DESIGN_PRINCIPLES.md`(UI 작업 전) |
| 4 | DB 정본 `docs/products/_supabase-modular/migrations/1500_microweb.sql` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 `src/server/`와 `worker/`에서만. `NEXT_PUBLIC_` 접두사 금지 |
| 하객 경로 | `/i/*`, `/api/public/*`에서 이미지 생성 AI 호출 금지. 범용 AI 프록시 금지. AI는 `api/public/[slug]/greeting` 하나 |
| 공개 읽기 | 하객 페이지는 anon 키로 `site_publications`만 읽는다. `sites`를 공개 경로에서 service_role로 읽지 않는다(예외: `/p/[token]` 시안) |
| 하객/문의 쓰기 | `submit_guestbook_entry`, `submit_rsvp`, `create_lead`(service 전용, 리밋 내장)만. 테이블 직접 INSERT 금지 |
| 크레딧 | 셀프 게시만 라우트에서 선차감(`consume:microweb:<request_id>`), 실패 시 잡 환불. 사용자 RPC 안에서 크레딧을 건드리지 않는다 |
| 결제 | PM001이면 별도 호출로 `fail_payment_order`를 부른다(04장 2절) |
| 코어 | 공용 모듈을 다시 만들지 않는다. `_platform-core`, `_supabase-modular`의 다른 파일, core 마이그레이션 수정 금지. 필요하면 06장 6절 요청 |
| 개인정보 | IP 원문 저장·로그 금지, 사진 EXIF 제거, 감사 로그에 이름·연락처·본문 금지 |
| 문구 | 01장 6절 금지 문구(미검증 수치, 근거 없는 할인, 가상 후기, 가짜 포트폴리오) 금지 |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 소유 작업 |
|---|---|---|
| `src/engine/{schema,blocks,themes,share}` | 블록 엔진(데이터 소스 모름) | 004, 005, 006, 008 |
| `src/app/i`, `src/app/p` | 하객, 시안 | 007, 017 |
| `src/app/(showroom)`, `src/showroom` | 쇼룸 | 020~025 |
| `src/app/studio`, `src/studio` | 운영자 화면 | 014, 018, 019 |
| `src/app/api/public`, `src/app/api/studio`, `src/app/api/admin`, `src/app/api/billing` | 라우트 | 009, 010, 013, 015, 016, 025, 026, 027 |
| `src/server` | service_role 서비스 계층 | 작업별 하위 폴더 |
| `worker/` | `microweb.media` 워커 | 011, 012 |
| `supabase/`, `scripts/db/` | DB(정본은 모듈러 조각) | 002, 030 |

같은 파일을 두 작업이 만지지 않는다. 경계는 `06_AGENT_PLAN.md` 2장 표가 정본이다.

## 4. 코어 사용 규칙

| 용도 | 방법 |
|---|---|
| 세션 | `requireSession('microweb', { roles })` → `ctx.org.id`. 그 뒤 `studio_access` 확인(없으면 `/pending`) |
| 사용자 쓰기 | 사용자 세션 클라이언트 + `supabase.schema('microweb').rpc(...)` 또는 허용된 컬럼 UPDATE |
| 크레딧 | `credits.consume` → `rpc request_publish(site, actor, ledger)` → `jobs.enqueue({ creditLedgerId })` |
| 잡 | 큐 `microweb.media`, job_type `asset.process`, `site.publish`, `site.unpublish_assets`, `site.purge`. 진행률은 `core.jobs` Realtime |
| 레이트 리밋 | DB 함수 내장분 외 라우트는 `core.rate_limit_hit('microweb:<route>:<key>', n, sec)` |
| 감사 | RPC가 기록. 서버 경로(CSV 내보내기, 업로드 삭제, 결제 불일치)는 service INSERT |
| 스키마 전환 | `SUPABASE_DB_SCHEMA=core`(모듈러) / `public`(모놀리스). 제품 스키마는 모듈러 `microweb`, 모놀리스 `public` |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16 App Router, React 19, TS strict, Tailwind 4 빌드, zod, sharp(워커) |
| 버전 | lockfile 커밋, `latest` 금지 |
| 타입 | `supabase gen types typescript --local --schema core,microweb > src/types/supabase.ts`. `any` 캐스팅 금지 |
| 상태 값 | DB CHECK와 같은 `as const` 배열 + zod |
| 디자인 토큰 | `src/styles/tokens.css`(쇼룸), `src/engine/themes/<theme>.css`(템플릿). 컴포넌트에 hex 금지 |
| 아이콘 | lucide 명시 import만 |
| 모놀리스 SQL | 손으로 고치지 않는다. 모듈러 조각 수정 → `scripts/db/to-monolith` 재생성 |

## 6. 테스트와 완료 조건

| 검사 | 명령/기준 |
|---|---|
| SQL | `cd docs/products/_tools-sqlcheck && node check.mjs mod <0000~0007> ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1500_microweb.sql` OK, mono도 OK |
| RLS | `supabase/tests` 스모크 mod/mono 87/87 |
| 앱 | `tsc --noEmit`, `eslint`, `next build` 0오류 |
| E2E | F1~F3(대행, 하객, 문의) 녹색, 출시 체크리스트 12항목, 하객 JS 150KB 이하 |
| 결제 E2E | Phase 2 출시 조건 |
| 위생 | gitleaks 0, 추적 node_modules 0, 앱 아래 중첩 `.git` 0 |

## 7. 금지 패턴

| 패턴 | 대체 |
|---|---|
| 클라이언트가 모델/본문/헤더를 정하는 AI 프록시, 번들 속 시크릿 헤더 | 고정 purpose 서버 엔드포인트 |
| 방문마다 이미지 생성, AI 지도 | 업로드 사진, 카카오맵 임베드/딥링크 |
| `.env*` 커밋 | gitignore + gitleaks, 노출 시 재발급 |
| 하객에게 보이는 삭제 버튼, 검증 없는 insert | 운영자 RPC, service 전용 제출 함수 |
| 실패를 고정 문구로 숨김 | 오류 표시와 대안 안내 |
| 비밀번호 우회('1234'), 역할 직접 선택, 클라이언트만의 권한 판정 | core auth + RLS + `studio_access` |
| constants 하드코딩 커플 데이터 | content JSON + DB |
| 가짜 SRI, placeholder 키 | 공식 SRI, env |
| 미검증 수치, 정가 대비 할인, picsum 포트폴리오 | 실제 결과물, 동의받은 납품작 |
| `latest`, Tailwind CDN, `import * as Icons` | 고정 버전, 빌드 Tailwind, 명시 import |
