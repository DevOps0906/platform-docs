# 02 아키텍처: Stock Dashboard

작성일 2026-10-12. 원본에는 백엔드, DB, 인증이 없다(`docs/reviews/Stock_Trader_nomad.md:17`, `:45`). 이 문서는 리뷰 4.1 권장 아키텍처(`:66-73`)를 `_platform-core` 위에 구체화한다. 공용 모듈은 참조만 하고 재정의하지 않는다(`docs/products/_platform-core/SHARED_MODULES.md:473`).

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router(Node 런타임), React | 16.2.9, 19 | `docs/products/00_MERGE_ANALYSIS.md:1333`(basic-master-module 디벨롭), `docs/reviews/Stock_Trader_nomad.md:68` |
| 스타일/UI | Tailwind CSS v4, shadcn/ui, Lucide | v4 | `docs/reviews/Stock_Trader_nomad.md:68`, `구현해야 할 프로젝트/Stock_Trader_nomad/claude.md:9` |
| 차트 | Recharts 3 (하나로 고정. Chart.js 미사용) | 3.x | `docs/reviews/Stock_Trader_nomad.md:16`, `:68`, `:94` |
| 시세 상태 | zustand(종목별 셀렉터) | 5.x(제안) | `docs/reviews/Stock_Trader_nomad.md:48`, `docs/products/00_MERGE_ANALYSIS.md:1277` |
| 서버 상태 | TanStack Query(스냅샷, 리포트 같은 요청-응답 데이터만) | 5.x | `docs/reviews/Stock_Trader_nomad.md:93` |
| 검증 | zod(Route Handler 입력, AI 출력) | 3.x | `docs/products/_platform-core/SECURITY_BASELINE.md:171` |
| 인증/DB | Supabase Auth + Postgres 15 + RLS, 모놀리스(`public`) | - | `docs/products/_supabase-modular/ARCHITECTURE.md:43` |
| 워커 | Node 22 LTS 상주 프로세스 2개: `quote-relay`(시세 중계), `stock-jobs`(core.jobs 소비) | 제안 | `docs/reviews/Stock_Trader_nomad.md:71`. 확정 결정 6은 video 대상이며 이 제품은 Python 미디어 처리가 없어 TS 워커만 쓴다 |
| LLM | `_platform-core` llm gateway(OpenRouter + Anthropic 직접) | - | `docs/products/_platform-core/SHARED_MODULES.md:198-226` |
| 결제 | Toss Payments(Phase 2) | - | 확정 결정 4 |
| 재무지표 | DART 오픈API(직접 계산) 우선, 증권사 제공분 보조 | 미확인 | `docs/reviews/Stock_Trader_nomad.md:50` |

## 2. 모듈 경계

앱 루트는 `apps/stock-dashboard/`(제안). 06장 소유 경계의 기준이다.

| 모듈 | 디렉토리 | 책임 | 의존 |
|---|---|---|---|
| 셸·인증 | `src/proxy.ts`, `src/lib/supabase/`, `src/components/shell/` | 세션 갱신, 라우트 보호, `session_context`, 고지 동의 확인 | packages/core-db |
| 보안 유틸 | `src/lib/security/` | 계좌번호 마스킹·HMAC, 로그 마스킹, 자격증명 vault 호출 래퍼(server-only) | packages/core-auth |
| 브로커 | `src/lib/broker/` (`core/`, `mock/`, `<broker>/`) | `BrokerAdapter` 계약과 구현. UI는 어댑터 결과 타입만 본다 | 보안 유틸 |
| 시세 클라이언트 | `src/lib/quotes/` | SSE 구독, 재연결, zustand 스토어, 지연 배지 판정 | 없음(브라우저) |
| AI | `src/lib/ai/` | 입력 스냅샷 조립, 위험 수준 규칙, 프롬프트, zod 출력 스키마, 금칙어 검사 | llm gateway, credits |
| 주문(Phase 3) | `src/lib/orders/` | 주문 미리보기, 한도 판정 보조(비중), 확인 RPC 호출 | 브로커, RPC |
| 화면 | `src/app/(app)/`, `src/app/(marketing)/`, `src/app/(admin)/`, `src/components/<영역>/` | 03장 화면 | 위 전부 |
| API | `src/app/api/<영역>/` | 04장 Route Handler | 위 전부 |
| 시세 중계 워커 | `workers/quote-relay/` | 사용자별 증권사 WebSocket 구독, SSE 팬아웃, 지연 감시 | 브로커 계약(공유 패키지로 추출) |
| 잡 워커 | `workers/stock-jobs/` | `stock.*` 잡 처리(동기화, 재무지표, 캘린더, 성과 평가, 주문 제출) | core-jobs, 브로커 |
| DB | `supabase/` | 마이그레이션, seed, 테스트 | 없음 |

`BrokerAdapter` 계약(예시, 구현 아님):

```ts
export interface BrokerAdapter {
  broker: 'mock' | 'kis' | 'kiwoom' | 'hana'
  env: 'paper' | 'live'
  verify(creds: BrokerCreds): Promise<{ accountMasked: string; accountRefHash: string }>   // 토큰 발급 테스트
  getBalance(ctx: ConnCtx): Promise<BalanceDto>          // cash_krw, purchase_krw, eval_krw
  getHoldings(ctx: ConnCtx): Promise<HoldingDto[]>
  getExecutions(ctx: ConnCtx, range: { from: string; to: string }): Promise<ExecutionDto[]>  // broker_exec_id 필수
  subscribeQuotes(ctx: ConnCtx, symbols: string[], onTick: (t: TickDto) => void): Promise<() => void>
  placeOrder?(ctx: ConnCtx, o: PaperOrderDto): Promise<{ brokerOrderId: string }>  // Phase 3, env='paper' 어댑터만 구현
}
```

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 세션, `requireSession('stock')`, 가입 `signup_app='stock'` | `src/proxy.ts`, 모든 Route Handler | 프로필 없으면 로그아웃(`SHARED_MODULES.md:53`) |
| org | 개인 조직 1개 운영 | 세션 컨텍스트 | 멤버 초대 화면 없음(1인 1워크스페이스, 확정 결정 5) |
| credits | AI 진단 선차감·환불 | `src/app/api/ai/` | `withCredits` 래퍼 |
| toss | Phase 2 pro 플랜 | `src/app/api/billing/` | 법률 검토 통과 후 |
| webhooks | Toss 웹훅(Phase 2) | `src/app/api/webhooks/toss/` | 지급은 confirm 경로 |
| oauth | 사용하지 않음(`oauth_states` 절 제거) | - | 증권사는 키 입력 방식. vault(`encrypted_credentials`)만 사용 |
| llm gateway | 진단, 아이디어, 3사 비교 | `src/lib/ai/` | purpose `stock_diagnosis`, `stock_idea` |
| compliance | 사용하지 않음(제품 금칙어 사전으로 대체) | - | 대상 플랫폼 목록에 금융 화면이 없다(`SHARED_MODULES.md:355`). 규칙 사전 방식만 차용 |
| storage | 사용하지 않음(절 제거) | - | CSV는 스트리밍 |
| audit | 베타 수락/회수, 연결 생성/해제, 한도 변경, 킬 스위치, 주문 확인 | RPC 내부, Route Handler(service) | `CORE_SPEC.md` 11장 |
| jobs | `stock.*` 잡 | `workers/stock-jobs/` | 큐 `stock.sync`, `stock.reference`, `stock.eval`, `stock.orders` |
| rate limit | 6장 값 | Route Handler | `rate_limit_hit` |
| fal, weasyprint, sns uploader, automation-core, affiliate | 사용하지 않음 | - | 해당 기능 없음 |

## 4. 잡과 워커

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `stock.sync` | `stock.sync` | TS(stock-jobs) | 없음 | 3회, 지수 백오프(60초 x 2^n) | 해당 없음 |
| `stock.fundamentals_refresh` | `stock.reference` | TS | 없음 | 3회 | 해당 없음 |
| `stock.calendar_load` | `stock.reference` | TS | 없음 | 3회 | 해당 없음 |
| `stock.daily_prices` | `stock.reference` | TS | 없음 | 3회 | 해당 없음 |
| `stock.idea_eval` (Phase 2) | `stock.eval` | TS | 없음 | 3회 | 해당 없음 |
| `stock.order_submit` (Phase 3) | `stock.orders` | TS | 없음 | 0회(재제출 금지, 실패 시 `failed` + 사람 확인) | 해당 없음 |

AI 진단은 잡이 아니라 Route Handler 스트리밍이다(첫 토큰 5초 목표). 페이로드는 04장 4절.

스케줄(UTC 크론 + KST 주석, service_role):

| 주기 | 동작 |
|---|---|
| 장중 5분(평일 00:00~06:30 UTC = 09:00~15:30 KST, `market_calendar.is_open`일 때) | 활성 연결마다 `stock.sync`(balance, holdings) enqueue. 멱등 키 `job:stock:sync:<conn>:<5분 버킷>` |
| 06:40 UTC(15:40 KST) | `stock.sync`(executions) |
| 장외 60분 | `stock.sync`(balance, holdings) |
| 매일 09:00 UTC(18:00 KST) | `stock.daily_prices`, Phase 2 `stock.idea_eval` |
| 매주 일요일 | `stock.fundamentals_refresh` |
| 매년 12월 + 공지 변경 시 수동 | `stock.calendar_load` |
| 매 1분 | `stock.expire_pending_orders()`(Phase 3), 초대 만료 처리 |
| 코어 | `run_monthly_credit_grants`, `reap_stale_jobs(600)` 등(`CORE_SPEC.md` 14장) |

시세 중계 워커(`quote-relay`):

| 항목 | 설계 |
|---|---|
| 연결 단위 | 브라우저 SSE 1개 = (사용자, 조직, 연결 목록). 워커는 연결별 증권사 WebSocket 1개를 공유하고 같은 조직의 SSE에만 팬아웃 |
| 인증 | Next `/api/stream-token`이 HMAC-SHA256 토큰(60초, org_id, user_id, connection_ids, symbols 최대 40)을 발급. `EventSource`는 헤더를 못 보내므로 쿼리 토큰. 워커는 서명·만료 검증 후 1회 사용 처리 |
| 키 | 워커가 service_role로 `encrypted_credentials`를 복호화(서버 전용). 키는 프로세스 메모리에만 |
| 재연결 | 증권사 WS 끊김 시 1, 2, 4, 8, 최대 30초 백오프. 브라우저는 `retry: 3000` |
| 지연 감시 | 장중 종목별 마지막 틱 시각을 추적해 SSE `status` 이벤트(`ok`/`delayed`/`stale`) 전송. Phase 3에서는 60초 stale 시 연결 범위 자동 킬 스위치 |
| 저장 | 틱을 DB에 저장하지 않는다(재배포·저장 최소화, 01_PRD 6.1) |
| 구독 정리 | 마지막 SSE가 닫히면 30초 뒤 증권사 구독 해제 |

## 5. AI 라우팅

| purpose | 모델(fast/quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `stock_diagnosis` | quality만(beta) | 10 | 게이트웨이 폴백 모델 1회 → 실패 시 환불 |
| `stock_idea` (Phase 2) | quality | 10 | 같음 |
| `stock_compare` (Phase 2) | 설정의 3개 모델 병렬 | 25 | 모델별 실패분 부분 환불 |

모델명은 `resolveModel(purpose, mode)` 설정에서 읽고 코드·UI에 하드코딩하지 않는다(`docs/reviews/Stock_Trader_nomad.md:54`). 이미지·음성 제공자는 없다.

진단 파이프라인:

| 단계 | 동작 |
|---|---|
| 1 | `requireSession('stock')`, 고지·국외 이전 동의 확인, 일 상한(`ai_diagnosis_per_day`)과 분당 3회 레이트 리밋 |
| 2 | 입력 스냅샷 조립(최신 스냅샷·보유·재무지표). sha256 → `input_hash`. 같은 해시로 10분 안에 성공한 리포트가 있으면 재사용 제안(과금 없음, 제안) |
| 3 | 위험 수준 규칙 계산(서버): 높음 = 비중 30% 이상 또는 평가손익률 -20% 이하, 중간 = 비중 15~30% 또는 손익률 -10~-20%, 낮음 = 그 외(제안, 리뷰 #15 서열 척도) |
| 4 | `consume_credits(10)` → `ai_reports` INSERT(queued → running) |
| 5 | 스트리밍 호출. 브라우저로는 NDJSON 델타 전송(`fetch(POST)` + `ReadableStream`, `docs/reviews/Stock_Trader_nomad.md:96`) |
| 6 | 완료 후 zod 검증(입력에 없는 종목·없는 종목코드 거부), 금칙어 검사. 실패면 1회 재생성 |
| 7 | 성공: `output` 저장(DB CHECK가 가격 키 거부), `ai_report_items` INSERT. 실패: `failed` + `refund_credits` |

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 "높음"은 6개(#1~#6)다. 보안·데이터 성격인 #1~#4는 `05_DATA_MODEL.md` 7장, 기술 리스크인 #5, #6은 여기에 둔다. 합계 6 = 6.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Stock_Trader_nomad.md` 3장 #5 | `docs/reviews/Stock_Trader_nomad.md:43` | 하나증권·키움의 연동 방식(REST/OCX, 모의투자, 호출 한도, 토큰 제한)이 미확인이라 증권사 선택이 아키텍처를 좌우한다 | (1) 착수 전 spike: 후보 3곳에 대해 토큰 발급, 잔고, 체결, 시세 WebSocket, 모의투자 서버, 호출 한도, 약관(제3자 서비스 허용)을 각각 확인하고 결과표를 남긴다. Windows 전용 OCX/COM만 있는 곳은 제외. (2) UI와 DB는 `BrokerAdapter` DTO만 본다. MockBroker가 같은 계약을 구현해 실데이터 전환 시 UI를 다시 쓰지 않는다(리뷰 #9). (3) DB는 `broker` CHECK(`mock`, `kis`, `kiwoom`, `hana`)로 지원 목록을 명시하고, 어댑터 계약 테스트 스위트를 공통으로 둔다 | ST-06-004, ST-06-008, ST-06-014 |
| `docs/reviews/Stock_Trader_nomad.md` 3장 #6 | `docs/reviews/Stock_Trader_nomad.md:44` | 증권사 실시간 시세는 WebSocket 상시 연결이라 Vercel 서버리스로 SSE를 유지할 수 없고, 개인 API 시세를 다른 사용자에게 재배포하면 약관과 충돌한다 | (1) 상주 워커 `quote-relay`(Railway)가 WebSocket을 유지하고 SSE로 중계한다. Vercel 함수는 60초 토큰 발급만 한다. (2) 시세는 사용자 본인 연결로만 받고 같은 조직 SSE에만 보낸다. 공용 시세 피드, 틱 저장, 다른 조직으로의 팬아웃이 없다. (3) 일봉은 성과 계산 전용 테이블(`daily_prices`, 사용자 GRANT 없음)이며 스모크 테스트에서 사용자 SELECT가 42501. (4) 지연 배지(10초/60초)로 지연을 숨기지 않는다 | ST-06-015, ST-06-016, `05_DATA_MODEL.md` daily_prices |

## 7. 배포 토폴로지

| 구성 | 위치 | 네트워크 |
|---|---|---|
| Next 앱 | Vercel(서울 리전 선호, 제안) | 공개. Route Handler만 service_role 사용 |
| Supabase(모놀리스) | 전용 프로젝트, 서울 리전(제안) | Postgres 직접 접속은 워커만, 나머지는 PostgREST |
| `quote-relay` | Railway(상주 1개, 베타) | 공개 HTTPS(SSE). 토큰 없는 요청 401. 증권사로 아웃바운드 WebSocket |
| `stock-jobs` | Railway(상주 1개) | 공개 포트 없음. Supabase(service_role), 증권사 REST, DART |
| LLM | OpenRouter/Anthropic | Next Route Handler에서만 호출 |
| 경계 | 브라우저 → (Next API, quote-relay SSE)만. 브라우저는 증권사, LLM, 워커 내부 API를 직접 부르지 않는다 | |

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 동작 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버/워커 쓰기 | 비공개 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `public`(모놀리스) / `core`(모듈러) | 비공개 | 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 증권사 키 AES-256-GCM | 비공개(앱·워커) | 기동 실패, 0키 폴백 금지 |
| `ACCOUNT_HASH_KEY` | 계좌번호 HMAC | 비공개 | 기동 실패 |
| `STREAM_TOKEN_SECRET` | quote-relay 토큰 HMAC(앱과 워커 공유) | 비공개 | 기동 실패 |
| `NEXT_PUBLIC_QUOTE_RELAY_URL` | SSE 엔드포인트 | 공개 | 시세 기능 비활성 + 배지 "시세 꺼짐" |
| `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY` | llm gateway | 비공개 | 기동 실패(AI 라우트) |
| `DART_API_KEY` | 재무지표 | 비공개(워커) | 재무지표 잡 실패, 모달에 "-" |
| `BROKER_LIVE_READ_ENABLED` | 실계좌 조회 허용 | 비공개 | 기본 false |
| `ORDERS_ENABLED` | Phase 3 모의주문 | 비공개 | 기본 false |
| `DISCLAIMER_VERSION`, `AI_TRANSFER_CONSENT_VERSION` | 고지·동의 버전 | 비공개 | 기동 실패 |
| `NEXT_PUBLIC_TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | Phase 2 결제 | 클라이언트 키만 공개 | 결제 라우트 비활성 |
| `APP_BASE_URL` | 초대 링크 생성 | 비공개 | 기동 실패 |
