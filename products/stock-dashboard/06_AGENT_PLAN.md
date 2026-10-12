# 06 에이전트 작업 계획: Stock Dashboard

작성일 2026-10-12. 작업 ID는 `ST-06-###`. 앱 루트는 `apps/stock-dashboard/`(아래 경로는 이 루트 기준). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장. 리뷰는 이 제품의 주 담당을 Fable로 권했다(`docs/reviews/Stock_Trader_nomad.md:139`). 이번 계획은 키 보관, RLS, 시세 워커, 결제, 주문처럼 실수 비용이 큰 작업만 Fable에 두고 나머지는 Opus/Sonnet/Haiku로 내렸다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 표의 "소유 파일/디렉토리"만 만들고 고친다. 다른 작업 디렉토리의 파일이 필요하면 선행 작업으로 두고 공개 인터페이스(export)만 쓴다 |
| 공유 파일 | `package.json`, `next.config.ts`, `src/app/layout.tsx`, `src/proxy.ts`는 ST-06-006만 수정한다. 의존성 추가가 필요한 작업은 PR 설명에 적고 006 담당이 반영한다(제안: 병렬 충돌 방지) |
| DB | `supabase/`와 모듈러 조각은 ST-06-001(스키마), ST-06-003(테스트)만. 스키마 변경은 Fable, 조각을 고치고 002 스크립트로 모놀리스를 재생성 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일은 수정하지 않는다. 필요하면 6절 코어 요청 |
| 하위 디렉토리 분할 | `src/lib/ai/`는 021 소유, 단 `src/lib/ai/compare/`는 030. `src/app/api/ai/diagnoses/`는 021, `ideas/`는 029, `compare/`는 030. `workers/stock-jobs/src/` 하위 폴더(`sync/`, `reference/`, `eval/`, `orders/`, `watchdog/`)는 작업별로 나눈다. 진입점 `workers/stock-jobs/src/index.ts`는 013 소유 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ST-06-001 | DB 적용과 타입 생성: 모놀리스 0001~0003 + seed 적용, 타입 생성 | `supabase/migrations/`, `supabase/seed.sql`, `src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, 타입에 `broker_connections` 등 19개 테이블 존재, 체커 OK. 이유: 데이터 모델·RLS | 리뷰 5장 #4, 05장 |
| ST-06-002 | 조각 → 모놀리스 변환 스크립트와 CI 체크 | `scripts/db/` | 001 | P0 | S | Haiku | 스크립트 결과가 저장된 0002/0003과 바이트 단위 동일, CI에서 체커 2종 실행. 이유: 반복 변환 | `DB_CONVENTIONS.md:264` |
| ST-06-003 | RLS/권한 회귀 테스트(필수) | `supabase/tests/` | 001 | P0 | M | Fable | 05장 4.1 표 75항목 자동화, 모듈러·모놀리스 둘 다 0 실패, CI 필수 단계. 이유: 권한 | `SECURITY_BASELINE.md` 15장 |
| ST-06-004 | 증권사 API spike: 후보 3곳의 토큰, 잔고, 체결, 시세 WS, 모의투자, 호출 한도, 약관 | `spikes/broker/`, `docs/spike/broker.md` | 없음 | P0 | M | Opus | 결과표(항목 x 증권사, 확인/불가/미확인)와 1곳 선정 근거, 약관 원문 인용. 실키는 커밋하지 않음 | 리뷰 5장 #2, 리뷰 #5 |
| ST-06-005 | 법률 검토 패키지: 질의서(투자자문/유사투자자문, 마이데이터, 시세 재배포, 국외 이전), 고지·약관·처리방침 초안 | `docs/legal/` | 없음 | P0 | S | Sonnet | 01_PRD 6장 표의 "미확인" 항목이 질의서에 모두 있음, 고지 문안 버전 `2026-10-12` | 리뷰 5장 #1, 리뷰 #3·#4 |
| ST-06-006 | 앱 골격: Next 16.2.9, Supabase 클라이언트 3종, `proxy.ts`(세션·베타·동의 리다이렉트), env 검증 | `package.json`, `next.config.ts`, `src/app/layout.tsx`, `src/proxy.ts`, `src/lib/supabase/`, `src/lib/env.ts` | 001 | P0 | M | Opus | 필수 env 누락 시 기동 실패, 비로그인 `/dashboard` → `/login`, 베타 없음 → 안내, 미동의 → `/onboarding/disclaimer` | 리뷰 5장 #3 |
| ST-06-007 | 보안 유틸: 계좌 마스킹·HMAC, vault 래퍼(server-only), 로그 마스킹, 키 미설정 기동 실패 | `src/lib/security/` | 006 | P0 | M | Fable | 단위 테스트: 마스킹 결과가 CHECK 통과, 로그 출력에 키·계좌 원문 0건, `CREDENTIALS_KEY` 없으면 throw. 이유: 보안 핵심 | 리뷰 5장 #5, 리뷰 #1 |
| ST-06-008 | `BrokerAdapter` 계약, `MockBroker`(샘플 배지 데이터), 어댑터 계약 테스트 스위트 | `src/lib/broker/core/`, `src/lib/broker/mock/` | 004 | P0 | S | Opus | Mock이 계약 스위트 통과, 모든 DTO에 `isSample` | 리뷰 5장 #6, 리뷰 #9 |
| ST-06-009 | 베타 초대·수락: 발급 API(토큰 1회 노출), 수락 API(3장 시퀀스), `/invite/[token]` | `src/app/api/beta/`, `src/app/api/admin/beta/`, `src/app/invite/` | 006, 007 | P0 | M | Fable | 다른 이메일 수락 403, 재사용 400, 수락 뒤 플랜 beta·크레딧 300, 재호출 시 크레딧 중복 없음. 이유: 엔타이틀먼트 변경 | 01_PRD ST-F-001, 리뷰 #4 |
| ST-06-010 | 고지 동의와 법적 페이지 | `src/app/onboarding/`, `src/app/legal/`, `src/app/api/consents/` | 005, 006 | P0 | S | Sonnet | 동의 2종 기록, 버전 변경 시 재동의 화면 | ST-F-002 |
| ST-06-011 | 디자인 토큰, AppShell, 장 시간 바 | `src/styles/`, `src/components/shell/` | 006 | P0 | M | Sonnet | 03장 4.3 토큰만 사용(하드코딩 hex 0), 장 시간 바가 `market_calendar`로 구간 표시, 375px 깨짐 없음 | 리뷰 5장 #3, 03장 4절 |
| ST-06-012 | 증권사 연결 API와 화면 | `src/app/api/connections/`, `src/app/(app)/settings/connections/` | 007, 008 | P0 | M | Opus | 상한 초과 409, live는 플래그 꺼짐 시 403, 키 오류 시 `error` 행, 응답·로그에 키 없음 | ST-F-003, ST-F-004 |
| ST-06-013 | 동기화 워커(`stock.sync`), 워커 진입점, 스케줄 | `workers/stock-jobs/src/index.ts`, `workers/stock-jobs/src/sync/`, `workers/stock-jobs/package.json` | 001, 008 | P0 | L | Opus | 같은 체결 2회 동기화 → 1행, 오류 5회 → 연결 error, org 불일치 잡은 재시도 없는 실패, service_role 사용 | 리뷰 5장 #9, ST-F-005 |
| ST-06-014 | 실제 증권사 어댑터(조회 전용) | `src/lib/broker/<선정 증권사>/` | 004, 008 | P1 | L | Opus | 계약 스위트를 모의투자 서버에서 통과, 토큰 캐시·갱신, 호출 한도 설정값 준수 | 리뷰 5장 #9 |
| ST-06-015 | 시세 중계 워커: WS 구독, SSE 팬아웃, 토큰 검증, 지연 감시 | `workers/quote-relay/` | 007, 008 | P0 | L | Fable | 다른 조직 토큰으로 구독 불가, 틱 → SSE p95 1초(Mock 부하 100 연결), 10/60초 상태 이벤트, 틱 DB 저장 0. 이유: 상주 프로세스·장애 처리 | 리뷰 5장 #10, 리뷰 #6 |
| ST-06-016 | 스트림 토큰 라우트와 시세 스토어(zustand 종목별 셀렉터) | `src/app/api/stream-token/`, `src/lib/quotes/` | 015 | P0 | M | Opus | 토큰 60초·1회용, 한 종목 틱에 다른 행 리렌더 0(Profiler 테스트) | 리뷰 5장 #10, 리뷰 #10 |
| ST-06-017 | 대시보드 UI: 탭, KPI 밴드, 보유 그리드 블링크, AI 요약 패널 | `src/app/(app)/dashboard/`, `src/components/portfolio/` | 011, 016 | P0 | M | Sonnet | Total 합계 = 연결 합, 샘플 배지, reduced-motion 시 깜빡임 없음 | 리뷰 5장 #7 |
| ST-06-018 | 종목 상세 모달과 재무지표 API | `src/components/instrument/`, `src/app/api/instruments/` | 017 | P1 | S | Sonnet | 지표마다 출처·기준기간, 값 없으면 "-"와 사유 | 리뷰 5장 #8 |
| ST-06-019 | 참조 데이터 배치: 재무지표(DART), 캘린더, 일봉 | `workers/stock-jobs/src/reference/` | 013 | P1 | M | Opus | 휴장일 적재 후 동기화 주기 전환, DART 실패 종목 `missing` 기록 | 리뷰 #12, #14 |
| ST-06-020 | 매매 일지: 필터, 메모, CSV | `src/app/(app)/trades/`, `src/app/api/trades/` | 011 | P1 | M | Sonnet | CSV UTF-8 BOM, 1만 행 초과 413, 다른 사람 메모 수정 불가 | ST-F-009, 리뷰 5장 #9 |
| ST-06-021 | AI 진단 라우트: 스냅샷 조립, 위험 규칙, 프롬프트, zod, 금칙어, 크레딧, 스트리밍 | `src/lib/ai/`(compare 제외), `src/app/api/ai/diagnoses/` | 007, 010, 026 | P0 | M | Opus | 실패 시 환불 행 1개, 가격 키 포함 출력 저장 불가, 입력에 없는 종목 → 재생성 → 실패, 일 상한 429 | 리뷰 5장 #11, 리뷰 #3·#11 |
| ST-06-022 | AI 진단 화면과 이력 | `src/app/(app)/ai/`(compare 제외), `src/components/ai/` | 011, 021 | P1 | S | Sonnet | 고지·AI 배지·모델명·기준 시각 표시, 매수/매도 버튼 없음 | 리뷰 5장 #12 |
| ST-06-023 | 초대 전용 랜딩 `/` | `src/app/(marketing)/` | 011 | P1 | S | Sonnet | noindex, 03장 안 A, 금지 문구 점검 통과 | 03장 4절 |
| ST-06-024 | 운영자 화면(초대, 베타 회수, 동기화 오류, 전역 킬 스위치) | `src/app/(admin)/`, `src/app/api/admin/kill-switch/` | 009 | P1 | S | Sonnet | platform_admin 외 403, 모든 쓰기 audit | ST-F-012 |
| ST-06-025 | E2E 테스트: 초대 → 가입 → 동의 → mock 연결 → 대시보드 → 진단, 베타 없는 계정 차단 | `tests/e2e/` | 009, 012, 017, 021 | P0 | M | Opus | Playwright 시나리오 6개 통과(정상 1, 차단 5) | 7절 |
| ST-06-026 | 금칙어 사전(한국어 경계 처리)과 카피 점검 체크리스트 | `src/content/` | 005 | P0 | S | Haiku | 01_PRD 6.6 표의 예시 문구가 사전에 모두 걸림, 정상 상태 설명 문구 오탐 0 | 01_PRD 6.6 |
| ST-06-027 | 개발 문서와 `.env.example` 정리 | `.env.example`, `README.md`(앱 루트) | 006 | P1 | S | Haiku | 02장 8절 변수 전부, 실값 없음 | 리뷰 5장 #15 |
| ST-06-028 | 계정 설정: 동의 이력, 내 데이터 내려받기, 탈퇴 | `src/app/(app)/settings/account/`, `src/app/api/me/` | 010 | P1 | S | Sonnet | JSON에 키·계좌 원문 없음, 탈퇴 시 조직 soft delete | 01_PRD 6.2 |
| ST-06-029 | (P2) AI 아이디어, 성과 배치 `idea-eval-v1`, 내부 리더보드 | `workers/stock-jobs/src/eval/`, `src/app/api/ai/ideas/`, `src/app/api/leaderboard/`, `src/app/(app)/leaderboard/` | 021, 019 | P2 | M | Opus | 규칙 단위 테스트(다음 개장일 시가, 정지 종목), n<20 순위 미표시 | 리뷰 5장 #13, ST-F-013 |
| ST-06-030 | (P2) AI 3사 비교 | `src/lib/ai/compare/`, `src/app/api/ai/compare/`, `src/app/(app)/ai/compare/` | 021 | P2 | M | Opus | 모델명 하드코딩 0, 한 모델 실패 시 부분 환불 | ST-F-014, 리뷰 #16 |
| ST-06-031 | (P2) 결제: pro 주문, confirm, Toss 웹훅, 결제 E2E(Toss 테스트 키, 필수) | `src/app/api/billing/`, `src/app/api/webhooks/toss/`, `src/app/(app)/settings/billing/`, `tests/e2e/billing/` | 005(법률 의견), 009 | P2 | M | Fable | 테스트 키로 결제 → pro 엔타이틀먼트·600 크레딧, 금액 위조 → PM001 + 취소 + 알림(주문 failed 미기록 코어 결함에 의존하지 않음), 서명 없는 웹훅 401. 이유: 결제 | 확정 결정 4, ST-F-016 |
| ST-06-032 | (P3) 모의주문 모듈: 미리보기, 비중 검사, 확인, 제출 워커, 킬 스위치·한도 API | `src/lib/orders/`, `src/app/api/orders/`, `src/app/api/kill-switch/`, `src/app/api/order-limits/`, `workers/stock-jobs/src/orders/` | 003, 014 | P2 | L | Fable | `ORDERS_ENABLED=false`면 라우트 404, 제출 재시도 0회, 킬 스위치 뒤 제출 → blocked. 이유: 돈이 걸린 로직 | 리뷰 5장 #14, 리뷰 #2 |
| ST-06-033 | (P3) 주문 패널, 확인 화면(60초), 한도·킬 스위치 화면, 모의투자 배너 | `src/app/(app)/orders/`, `src/app/(app)/settings/limits/`, `src/components/orders/` | 032 | P2 | M | Sonnet | 확인 전 주문 생성 없음, 만료 표시, "모의투자" 배너 상시 | 리뷰 5장 #14 |
| ST-06-034 | (P3) 주문 안전장치 테스트 + 자동 킬 스위치 감시(시세 60초, 오류 3회, 잔고 불일치 1%) | `supabase/tests/orders/`, `tests/orders/`, `workers/stock-jobs/src/watchdog/` | 032 | P2 | M | Fable | 조건별 자동 스위치 작동, 사용자 해제 42501, 동시 주문 50건에서 일 한도 초과 0 | 리뷰 5장 #14, 리뷰 #2 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 005 | 3 | 없음 | DB·타입, 증권사 선정, 법률 질의서·고지 초안 |
| W1 | 002, 003, 006, 008, 026 | 5 | W0 완료 | 변환 스크립트, RLS 테스트, 앱 골격, 어댑터 계약, 금칙어 사전 |
| W2 | 007, 010, 011, 027 | 4 | 006 완료 | 보안 유틸, 동의, 디자인 셸 |
| W3 | 009, 012, 013, 015, 021, 023 | 6 | W2 완료 | 초대, 연결, 동기화, 시세 워커, AI 라우트, 랜딩 |
| W4 | 014, 016, 019, 020, 022, 024, 028 | 7 | W3 완료 | 실어댑터, 시세 스토어, 배치, 일지, AI 화면, 운영자, 계정 |
| W5 | 017 | 1 | 016 완료 | 대시보드 |
| W6 | 018, 025 | 2 | 017 완료 | 모달, E2E → MVP 완료 |
| W7(P2) | 029, 030, 031 | 3 | MVP + 법률 의견(031) | 아이디어/리더보드, 3사 비교, 결제 |
| W8(P3) | 032 | 1 | 사용자 결정(01_PRD 8장 #4) | 주문 모듈 |
| W9(P3) | 033, 034 | 2 | 032 완료 | 주문 UI, 안전장치 테스트 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 8 (001, 003, 007, 009, 015, 031, 032, 034) | 23.5% | 18/61 = 29.5% |
| Opus | 12 (004, 006, 008, 012, 013, 014, 016, 019, 021, 025, 029, 030) | 35.3% | 25/61 = 41.0% |
| Sonnet | 11 (005, 010, 011, 017, 018, 020, 022, 023, 024, 028, 033) | 32.4% | 15/61 = 24.6% |
| Haiku | 3 (002, 026, 027) | 8.8% | 3/61 = 4.9% |
| 합계 | 34 | 100% | 61 |

## 5. 리뷰 작업 흡수표

리뷰 5장 작업 15개(`docs/reviews/Stock_Trader_nomad.md:116-130`) 전부를 흡수했다.

| 리뷰 5장 # | 작업 | 흡수한 작업 ID |
|---|---|---|
| 1 | PRD 보강(개인/공개 결정, 주문 범위, 데이터 모델, 수익률 규칙, 비기능, 안전장치) | 이 기획서 01~05장(완료), ST-06-005(법률 확인) |
| 2 | 증권사 API 기술 검증 | ST-06-004 |
| 3 | 프로젝트 골격, 다크 테마 토큰 | ST-06-006, ST-06-011 |
| 4 | 스키마와 RLS | ST-06-001, ST-06-003 |
| 5 | 키 보관 모듈 | ST-06-007 |
| 6 | `BrokerAdapter`, `MockBroker` | ST-06-008 |
| 7 | 대시보드 UI | ST-06-017, ST-06-011 |
| 8 | 종목 상세 모달 | ST-06-018 |
| 9 | 실제 증권사 어댑터, 매매 일지 동기화 | ST-06-014, ST-06-013, ST-06-020 |
| 10 | 시세 워커 | ST-06-015, ST-06-016 |
| 11 | AI 진단 라우트 | ST-06-021, ST-06-026 |
| 12 | AI 어드바이저 패널 UI | ST-06-022 |
| 13 | 성과 배치와 내부 리더보드 | ST-06-029 |
| 14 | 모의투자 주문 모듈 | ST-06-032, ST-06-033, ST-06-034 |
| 15 | `claude.md` 정리 | ST-06-027, 이 폴더 `CLAUDE.md` |

## 6. 공용 모듈 요청

코어는 이 제품이 바꾸지 않는다. 아래는 `_platform-core` 담당(Fable)에게 남길 요청이다.

| # | 요청 | 이유 | 제품 측 임시 대응 |
|---|---|---|---|
| 1 | `apps.signup_policy = 'invite'` 강제: `on_signup_app_bootstrap`/`bootstrap_app_for_org`가 invite 앱이면 엔타이틀먼트를 만들지 않거나 초대 확인 훅을 호출 | 현재 approval만 처리(`migrations/0003_core_credits.sql:400-402`). 누구나 stock 엔타이틀먼트를 얻는다 | `beta_access` 게이트(스모크로 검증) |
| 2 | 엔타이틀먼트 플랜 변경 RPC(`change_entitlement_plan(org, app, plan_code, source, actor)`, service_role, 구독·엔타이틀먼트·감사를 한 트랜잭션) | 베타 전환이 서버의 UPDATE 2회 + grant로 나뉜다 | 04장 3절 순서 + 멱등 키 |
| 3 | `confirm_payment_order` 금액 불일치 시 주문 `failed` 기록(알려진 결함, `DB_CONVENTIONS.md:296`) | raise가 UPDATE를 롤백 | 의존하지 않음. 서버가 취소·감사·알림(04장 5절) |
| 4 | `adjust_credits`(`CORE_SPEC.md:237`) | Phase 2 환불 시 미사용 크레딧 조정 | Phase 2 전까지 불필요 |
| 5 | 공용 패키지 `packages/core-auth`의 vault가 `provider` 접두사 규칙(`broker:<broker>:<env>`)을 허용하는지 확인 | 연결별 자격증명 구분 | 제품 규칙으로 사용 |

## 7. 완료 정의

| 항목 | 기준 | 명령(제안) |
|---|---|---|
| 빌드 | `next build`, 워커 2개 `tsc -p` 성공 | `pnpm -F stock-dashboard build`, `pnpm -F quote-relay build`, `pnpm -F stock-jobs build` |
| 타입·린트 | `tsc --noEmit`, ESLint 0 오류 | `pnpm -F stock-dashboard typecheck lint` |
| SQL | 체커 2종 OK, 변환 결과 동일 | `node check.mjs mono ...`, `node check.mjs mod ...`, `scripts/db/check-mono.sh` |
| RLS 스모크 | ST-06-003 전 항목 0 실패(모듈러·모놀리스) | `pnpm test:rls` |
| E2E | ST-06-025 통과 | `pnpm test:e2e` |
| 결제 E2E | ST-06-031(Phase 2 출시 조건) | `pnpm test:e2e billing` |
| 보안 점검 | 클라이언트 번들에 `SERVICE_ROLE`, `CREDENTIALS_KEY`, `appSecret` 0건, 로그 샘플 마스킹 | `pnpm check:bundle-secrets` |
| 법률 | ST-06-005 의견 반영 전 공개 랜딩·유료 플랜 금지 | 체크리스트 |
| 작업 | 이 장 MVP(P0/P1) 작업 전부 완료 | - |

P0 작업과 테스트 대응:

| P0 작업 | 대응 테스트 |
|---|---|
| 001, 009 | 003(RLS), 025(E2E) |
| 002 | 002 자체 CI 비교 |
| 004 | 008 계약 스위트(실서버 실행은 014) |
| 005, 010 | 025(동의 리다이렉트) |
| 006, 011, 017 | 025 |
| 007 | 007 단위 테스트 |
| 008 | 계약 스위트 |
| 012, 013 | 025 + 013 통합 테스트(중복 체결) |
| 015, 016 | 015 부하 테스트, 016 Profiler 테스트 |
| 021, 026 | 021 단위(가격 키, 환불), 026 사전 테스트 |
| 025 | 자기 자신 |
