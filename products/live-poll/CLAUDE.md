# CLAUDE.md: Live Poll

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | `docs/products/_supabase-modular/migrations/1800_poll.sql`(DB 정본) |
| 4 | UI 작업이면 `docs/products/_design-guide/` 3개 문서 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `POLL_IP_HMAC_SECRET`은 서버 파일에서만. `NEXT_PUBLIC_` 금지. `createAdminClient`는 `src/app/api/**`와 워커에서만 import |
| 청중 경로 | 청중 브라우저는 DB에 직접 접근하지 않는다. `/api/p/*` → service_role RPC만. anon 키로 `poll` 스키마를 읽는 코드를 만들지 않는다 |
| 크레딧 | 이 제품은 크레딧을 쓰지 않는다. 크레딧 RPC를 호출하지 않는다 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*`를 수정하지 않는다. 필요하면 06장 6절에 요청 |
| DB 변경 | 스키마 변경은 모듈러 조각(18xx)에서 Fable 담당. 모놀리스 파일은 변환 스크립트로만 만든다 |
| 폴링 금지 | 주기적 fetch 금지. 스냅샷은 입장, 재구독, seq 공백, 15초 무수신 때만 |
| IP | 원문 IP를 DB, 로그, 감사에 남기지 않는다. HMAC 값만 레이트 리밋 키로 |

## 3. 디렉토리와 소유 경계

`apps/live-poll/` 아래: `(marketing)` 랜딩, `(auth)` 로그인, `(host)` 진행자, `present` 발표, `overlay` 오버레이, `(participant)` 청중, `api/p` 청중 API, `api/host` 진행자 API, `api/overlay` 오버레이 API, `lib/realtime` 훅, `lib/realtime-auth` JWT, `lib/poll` 도메인, `components` UI, `supabase` DB. 워커는 `services/poll-broadcaster/`. 작업별 소유 디렉토리는 06장 2절 표가 정본이며 남의 디렉토리는 읽기만 한다.

## 4. 코어 사용 규칙

| 항목 | 규칙 |
|---|---|
| 세션 | 진행자 라우트 진입부 `requireSession('poll')`. 역할은 `session_context`의 `org.role`. 프로필 없으면 로그아웃 |
| 가입 | `signUp({ options: { data: { signup_app: 'poll' } } })`. 기존 사용자 첫 진입은 `bootstrap_app_for_org('poll')` |
| 플랜 | 기능 게이팅은 서버에서 `entitled_plan_code` + `plans.features`(01장 4절 키). DB 한도는 RPC가 강제 |
| 잡 | `core.jobs`를 쓰지 않는다. 브로드캐스트는 워커가 `poll.collect_broadcasts` |
| 감사 | 진행자 RPC는 내부에서 `write_audit`. CSV 내보내기는 Route Handler가 service INSERT(`event.export`) |
| 레이트 리밋 | RPC 내부 `core.rate_limit_hit`. 키 규약 `poll:<route>:<id>` |
| 결제(Phase 2) | `CORE_SPEC.md` 5장 시퀀스. PM001이면 별도 호출로 `fail_payment_order` 후 Toss 취소 + 알림 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16.2.9, React 19, Tailwind v4, shadcn/ui, supabase-js 2.x, `@supabase/ssr`, zod, Recharts 3(콘솔만), Node 22(워커) |
| 실시간 | `useEventChannel`만 채널을 만든다. 컴포넌트는 props만. 수신 반영은 rAF로 묶는다. `postgres_changes` 금지 |
| 타입 | `supabase gen types typescript --local --schema core,poll > src/types/supabase.ts`. `as any` 금지 |
| 입력 | Route Handler 입력은 zod. 본문 4KB 상한 |
| 렌더 | 닉네임/질문은 텍스트로만 렌더. `dangerouslySetInnerHTML` 금지 |
| 메타 | `/e/*`, `/present/*`, `/overlay/*`, `/events/*`는 `robots: noindex` + `X-Robots-Tag` |
| 디자인 | 토큰은 `src/styles/tokens.css`, 기준은 `design-system/live-poll/MASTER.md`. 하드코딩 hex 금지 |
| 린트 | `pnpm lint`, `pnpm typecheck` |

## 6. 테스트와 완료 조건

06장 7절. 명령: `pnpm test`(단위), `pnpm test:e2e`(Playwright), `pnpm test:rls`(LP-06-026), `pnpm test:load`(LP-06-027, 수동), SQL 체커 `cd docs/products/_tools-sqlcheck && node check.mjs mod ...`(06장 7절과 05장 9절의 파일 순서).

## 7. 금지 패턴

07장 4절 요약: 이벤트마다 전체 재조회, 훅 중복 호출로 채널 중복, 연결 상태 미표시, `as any`, RLS 자기참조/`USING(true)`, 프로필 없으면 admin, 실키 `.env` 커밋, `FOR ALL` 정책, 한글 `\b` 금칙어, 공개 채널 메시지 신뢰, 레이트 리밋 히트 뒤 raise, IP 원문 저장, Supabase 익명 로그인 사용(코어 요청 해결 전).
