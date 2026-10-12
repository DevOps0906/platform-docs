# CLAUDE.md: Stock Dashboard

개발 에이전트 지침. 이 제품은 돈과 금융 규제가 걸린 초대제 베타다. 애매하면 멈추고 묻는다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md`(특히 6장 법·금지 문구), `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `06_AGENT_PLAN.md`(자기 작업 행), `07_SOURCE_MIGRATION.md` 4장 |
| 3 | 디자인 작업이면 `docs/products/_design-guide/` 전부 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`, `CREDENTIALS_KEY_V<n>`, `ACCOUNT_HASH_KEY`, `STREAM_TOKEN_SECRET`는 서버·워커 전용. `NEXT_PUBLIC_` 금지. 해당 모듈은 `import 'server-only'` |
| 증권사 키 | `encrypted_credentials`에만. 평문 컬럼, localStorage, 로그, 오류 메시지, 감사 로그, 잡 payload에 넣지 않는다. 키가 없으면 기동 실패(0키 폴백 금지) |
| 계좌번호 | 입력 즉시 마스킹 + HMAC 후 원문 폐기. 화면·CSV·로그에는 마스킹 값만 |
| 조회 전용 | MVP·Phase 2에는 주문 코드 경로가 없다. Phase 3도 `env='paper'`만. 실전 주문 코드는 어떤 브랜치에도 만들지 않는다 |
| AI | 매수·매도 권유, 매수가·목표가·손절가를 생성·저장·표시하지 않는다. AI는 주문을 만들지 않는다 |
| 크레딧 | AI 호출 전 `consume_credits` 선차감, 실패 시 `refund_credits`. 사용자 RPC 안에서 차감하지 않는다 |
| 베타 게이트 | 도메인 데이터 접근은 RLS `has_stock_access`에 맡긴다. 서버에서 org_id 필터만으로 보호했다고 판단하지 않는다 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일을 수정하지 않는다. 코어 재정의 금지. 필요하면 06장 6절 요청 |
| 스키마 | 정본은 `_supabase-modular/migrations/1900_stock.sql`. 모놀리스 파일은 변환 스크립트로만 재생성 |
| 문구 | 01_PRD 6.6 금지 문구. 수익률 예시, 후기, "추천 종목", 보장 표현 금지 |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 소유 작업 |
|---|---|---|
| `src/proxy.ts`, `src/lib/supabase/`, 루트 설정 | 골격 | ST-06-006 |
| `src/lib/security/` | 마스킹, HMAC, vault 래퍼 | ST-06-007 |
| `src/lib/broker/` | 어댑터 계약, Mock, 실증권사 | ST-06-008, 014 |
| `src/lib/quotes/` | SSE, zustand 스토어 | ST-06-016 |
| `src/lib/ai/` | 진단(021), `compare/`(030) | ST-06-021, 030 |
| `src/lib/orders/` | Phase 3 | ST-06-032 |
| `src/app/(app)/`, `(marketing)/`, `(admin)/`, `src/components/<영역>/` | 화면 | 06장 표 |
| `src/app/api/<영역>/` | Route Handler | 06장 표 |
| `workers/quote-relay/` | 시세 중계 | ST-06-015 |
| `workers/stock-jobs/src/<sync\|reference\|eval\|orders\|watchdog>/` | 잡 | 013, 019, 029, 032, 034 |
| `supabase/` | 마이그레이션, 테스트 | ST-06-001, 003 |

다른 작업의 디렉토리를 고치지 않는다. 공유 파일(`package.json` 등) 변경은 006 담당에게 요청한다.

## 4. 코어 사용 규칙

| 상황 | 사용 |
|---|---|
| Route Handler 진입 | `requireSession('stock')` → 베타·동의 확인 |
| 세션 정보 | `session_context('stock')` 1회 |
| 크레딧 | `withCredits({ amount: 10, reason: 'stock_diagnosis', idempotencyKey: 'consume:stock:<request_id>' }, fn)` |
| 잡 | `enqueue_job(queue 'stock.<type>', job_type 'stock.<action>', idempotency 'job:stock:<request_id>')`. payload에 비밀 금지 |
| 자격증명 | `CredentialVault.put/get`(provider `broker:<broker>:<env>`), 해제는 `revoke_credential` |
| 감사 | 사용자 경로 `write_audit`, 서버 경로 service INSERT. action `stock.<entity>.<verb>` |
| 레이트 리밋 | `rate_limit_hit('stock:<route>:<org>', limit, window)` |
| 제품 RPC | `record_consent`, `set_order_limits`, `engage_kill_switch`, `release_kill_switch`, `confirm_paper_order`(사용자), 나머지는 service |

새 SECURITY DEFINER 함수를 만들 때: `set search_path = ''`, 객체 스키마 한정, authenticated에 열면 `core.is_service_caller()` + `has_org_role`(또는 `coalesce(role,'')`), service 전용이면 `is_privileged_session()` + EXECUTE를 service_role에만. 실패를 기록해야 하는 경로는 raise 대신 상태를 남기고 반환한다.

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16.2.9, React 19, Tailwind v4, shadcn/ui, Recharts 3, zustand, zod, TanStack Query(서버 데이터만), Node 22 워커 |
| 타입 | TS strict, Supabase 생성 타입 사용, `any`로 우회 금지. `supabase gen types typescript --local > src/types/supabase.ts` |
| 린트 | ESLint flat, `latest` 버전 태그 금지, lockfile 커밋 |
| 시간 | DB는 timestamptz(UTC), 표시는 KST. "오늘"은 KST 자정 경계를 서버가 계산 |
| 숫자 | 금액은 원 단위 정수(numeric), 표시 시 천 단위 구분, 손익은 부호와 색 함께 |
| 디자인 토큰 | `src/styles/tokens.css`(03장 4.3). 컴포넌트에 hex 하드코딩 금지 |
| 모델명 | llm gateway 설정에서만. 코드·UI 문자열에 모델 버전 하드코딩 금지 |
| 샘플 | `is_sample` 또는 mock 연결 데이터에는 "샘플 데이터" 배지 |

## 6. 테스트와 완료 조건

06장 7절이 정본이다. 요약:

| 검사 | 명령(제안) |
|---|---|
| 빌드·타입·린트 | `pnpm -F stock-dashboard build typecheck lint`, 워커 `build` |
| SQL 체커 | `cd docs/products/_tools-sqlcheck && node check.mjs mono ...` / `mod ...` |
| RLS 스모크 | `pnpm test:rls`(모듈러·모놀리스 둘 다 0 실패) |
| E2E | `pnpm test:e2e` |
| 비밀 번들 검사 | `pnpm check:bundle-secrets` |

## 7. 금지 패턴

07장 4절 요약: 크레딧 RPC 권한 미회수, 비원자 차감, 웹훅 서명 미검증, 토큰 평문·0키 폴백, 세션 없는 워커, `FOR ALL` 정책, 프로필 없으면 admin, 정책 자기참조, 공개 AI 프록시, `.env` 커밋, 한글 `\b` 금칙어, 증권사 키 클라이언트 노출, 계좌번호 로그, 샘플 무표시, AI의 주문 직접 생성, Vercel 장시간 SSE, `EventSource` AI 스트리밍, 시세 재배포, raise 뒤 상태 기록 기대, 스크래핑, GEO/JSON-LD 성과 노출, Context로 시세 관리.
