# 06 에이전트 작업 계획: Stock Dashboard

작성일 2026-10-12. 작업 ID는 `ST-06-###`. 앱 루트는 `apps/stock-dashboard/`(아래 경로는 이 루트 기준). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장. 리뷰는 이 제품의 주 담당을 Fable로 권했다(`docs/reviews/Stock_Trader_nomad.md:139`). 이번 계획은 키 보관, RLS, 시세 워커, 결제, 주문처럼 실수 비용이 큰 작업만 Fable에 두고 나머지는 Opus/Sonnet/Haiku로 내렸다.

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/products/_design-guide/DESIGN_SYSTEM.md` 4장) 작업 17개(ST-06-035~051)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 011(디자인 시스템 2단계), 021(진단을 그래프 경유로), 010·017·018·020·022·023·024·028(선행에 037 추가), 001·002·003·005·025·026(수용 기준 보강)이다. 작업 수 51개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다(2026-10-14 인증 단계 작업 3개 ST-06-052~054를 8절에 더해 54개, 확정 결정 22). AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘어난 것이고, 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다. 유사투자자문업 법률 의견(01_PRD D-3)이 아직 없으므로 AI 작업의 수용 기준은 모두 "사실 요약만, 투자 권유 금지 검사 필수"를 전제로 쓴다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 표의 "소유 파일/디렉토리"만 만들고 고친다. 다른 작업 디렉토리의 파일이 필요하면 선행 작업으로 두고 공개 인터페이스(export)만 쓴다 |
| 공유 파일 | `package.json`, `next.config.ts`, `src/app/layout.tsx`, `src/proxy.ts`는 ST-06-006만 수정한다. 의존성 추가가 필요한 작업은 PR 설명에 적고 006 담당이 반영한다(제안: 병렬 충돌 방지) |
| DB | `supabase/`와 모듈러 조각은 ST-06-001(스키마), ST-06-003(테스트)만. 스키마 변경은 Fable, 조각을 고치고 002 스크립트로 모놀리스를 재생성 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일은 수정하지 않는다. 필요하면 6절 코어 요청 |
| 하위 디렉토리 분할 | `src/lib/ai/`는 021 소유, 단 `src/lib/ai/compare/`는 030. `src/app/api/ai/diagnoses/`는 021, `ideas/`는 029, `compare/`는 030. `workers/stock-jobs/src/` 하위 폴더(`sync/`, `reference/`, `eval/`, `orders/`, `watchdog/`)는 작업별로 나눈다. 진입점 `workers/stock-jobs/src/index.ts`는 013 소유 |
| AI 서비스 경계 | `apps/api/`는 ST-06-038이 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. stock 확장은 작업별로 나눈다: 040 `app/ai/compliance/stock.py`, 041 `app/ai/products/stock/knowledge.py`·`disclosures.py`, 043 `app/ai/products/stock/wiki_config.py`, 045 `app/ai/graphs/`·`app/ai/products/stock/prompts/`, 046 `app/ai/tools/stock/` |
| AI 게이트 경계 | `src/app/api/ai/`는 하위 폴더별로 소유가 다르다: `chat/`, `conversations/` 등 공통은 039, `diagnoses/`는 021, `research/`·`briefings/`는 049, `ideas/`는 029, `compare/`는 030. `src/app/api/voice/`는 048(`briefings/`는 049) |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(R-6~R-11) |
| 언어 중립 파일 | `src/content/banned.json`은 ST-06-026 소유. FastAPI는 빌드 때 복사해 읽기만 한다 |
| 사람 작업 | ST-06-036(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(010, 017, 018, 020, 022, 023, 024, 028, 043, 044, 047, 049, 050)은 ST-06-037(4단계) 뒤에 시작한다(`docs/products/_design-guide/DESIGN_SYSTEM.md:48`) |
| 금융 보호선 | 어떤 AI 작업도 보유 수량·금액·평단을 FastAPI·Dify·음성 제공자에 보내지 않고, 사용자 노출 텍스트는 투자 권유 금지 검사(ST-06-040)를 통과시킨다. 이 두 규칙을 어기는 변경은 리뷰에서 막는다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ST-06-001 | DB 적용과 타입 생성: 모놀리스 0001~0003 + seed 적용, 타입 생성 | `supabase/migrations/`, `supabase/seed.sql`, `src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, 타입에 `broker_connections` 등 19개 테이블 존재, 체커 OK, 코어 AI 테이블(`ai_*`, `wiki_*`, `voice_*`) 존재, `ai_routing_settings`(org null, app stock) 12행, beta·pro features AI 키 5개, `ai_reports_advice_check_passed_check` 존재. 이유: 데이터 모델·RLS | 리뷰 5장 #4, 05장 |
| ST-06-002 | 조각 → 모놀리스 변환 스크립트와 CI 체크 | `scripts/db/` | 001 | P0 | S | Haiku | 스크립트 결과가 저장된 0002/0003과 바이트 단위 동일, CI에서 체커 2종 실행. 조각 14.1절은 0002 끝으로, 14.2~14.4절은 `seed.sql`로 나뉘어 생성된다. 이유: 반복 변환 | `DB_CONVENTIONS.md:264` |
| ST-06-003 | RLS/권한 회귀 테스트(필수) | `supabase/tests/` | 001 | P0 | M | Fable | 05장 4.1 표 75항목 + 추가 5항목(advice_check CHECK, kind 확장, voice_processing) 자동화, 모듈러·모놀리스 둘 다 0 실패, CI 필수 단계. 이유: 권한 | `SECURITY_BASELINE.md` 15장 |
| ST-06-004 | 증권사 API spike: 후보 3곳의 토큰, 잔고, 체결, 시세 WS, 모의투자, 호출 한도, 약관 | `spikes/broker/`, `docs/spike/broker.md` | 없음 | P0 | M | Opus | 결과표(항목 x 증권사, 확인/불가/미확인)와 1곳 선정 근거, 약관 원문 인용. 실키는 커밋하지 않음 | 리뷰 5장 #2, 리뷰 #5 |
| ST-06-005 | 법률 검토 패키지: 질의서(투자자문/유사투자자문과 AI 요약·브리핑 범위, 마이데이터, 시세 재배포, 국외 이전, 공시·뉴스 데이터 이용), 고지·약관·처리방침 초안 | `docs/legal/` | 없음 | P0 | S | Sonnet | 01_PRD 6장 표의 "미확인" 항목이 질의서에 모두 있음, 고지 문안 버전 `2026-10-12`. `docs/legal/data-sources.md`에 소스(DART, KIND, 뉴스)별 약관 URL·확인일·확인자·`terms_ref` 칸이 있다(01_PRD D-10) | 리뷰 5장 #1, 리뷰 #3·#4 |
| ST-06-006 | 앱 골격 + 인증 Stage A(2026-10-14): Next 16.2.9, Supabase 클라이언트 3종, `proxy.ts`(세션·베타·동의 리다이렉트), env 검증, 인증 모듈 경계 `src/lib/auth/`(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`), Mock 로그인(`POST /api/dev/login`·`/api/dev/logout`, `/login` 개발용 패널, 상단 `MOCK AUTH · 로컬 전용` 배지), 공통 시드 `scripts/dev/seed-users.mjs`(`db:seed-users`, 제품 훅 호출), 가드, `/no-access`. 이메일 가입·비밀번호 재설정 화면과 Google은 ST-06-052(Stage B)로 옮겼다 | `package.json`, `next.config.ts`, `src/app/layout.tsx`, `src/proxy.ts`, `src/lib/supabase/`, `src/lib/env.ts`, `src/lib/auth/`, `src/app/login/`, `src/app/no-access/`, `src/app/api/dev/`, `scripts/dev/seed-users.mjs` | 001 | P0 | M | Opus | 필수 env 누락 시 기동 실패, 비로그인 `/dashboard` → `/login`, 베타 없음 → `/no-access`, 미동의 → `/onboarding/disclaimer`. Stage A: `no_app` 페르소나 로그인 → `entitled=false` → `/no-access`, 본인 `bootstrap_app_for_org('stock')` 42501, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404·로그인 화면에 개발용 패널 없음, Supabase 호스트가 로컬이 아니면 Mock 기동 실패·시드 exit 1, 인증 모듈 밖 `AUTH_MODE` 참조 0(CI grep), 쿠키·localStorage 역할/플랜 쓰기 0, `finishLogin` 단위 테스트(`next=//evil.com` → 기본 경로). invite 앱이라 `owner`의 `entitled=true`는 ST-06-009 훅 뒤에 확인한다 | 리뷰 5장 #3, AUTH_ROADMAP 2장·3.1~3.2절 |
| ST-06-007 | 보안 유틸: 계좌 마스킹·HMAC, vault 래퍼(server-only), 로그 마스킹, 키 미설정 기동 실패 | `src/lib/security/` | 006 | P0 | M | Fable | 단위 테스트: 마스킹 결과가 CHECK 통과, 로그 출력에 키·계좌 원문 0건, `CREDENTIALS_KEY` 없으면 throw. 이유: 보안 핵심 | 리뷰 5장 #5, 리뷰 #1 |
| ST-06-008 | `BrokerAdapter` 계약, `MockBroker`(샘플 배지 데이터), 어댑터 계약 테스트 스위트 | `src/lib/broker/core/`, `src/lib/broker/mock/` | 004 | P0 | S | Opus | Mock이 계약 스위트 통과, 모든 DTO에 `isSample` | 리뷰 5장 #6, 리뷰 #9 |
| ST-06-009 | 베타 초대·수락: 발급 API(토큰 1회 노출), 수락 API(3장 시퀀스), `/invite/[token]`(A단계는 개발용 패널 로그인 후 수락), 시드 제품 훅(Stage A 페르소나: 초대 수락·미수락, 05장 10절) | `src/app/api/beta/`, `src/app/api/admin/beta/`, `src/app/invite/`(`continue/` 제외), `scripts/dev/seed-users.stock.mjs` | 006, 007 | P0 | M | Fable | 다른 이메일 수락 403, 재사용 400, 수락 뒤 플랜 beta·크레딧 300, 재호출 시 크레딧 중복 없음. Stage A: `owner` 페르소나 로그인 → `entitled=true`·beta·잔액 300, `outsider`로 `owner` 조직 도메인 행 0행, `invitee` → `/no-access`이고 시드가 출력한 링크로 수락 → beta, `beta_revoked` → 403 `ST_BETA`, 시드 2회 실행 시 초대·크레딧 중복 0. 이유: 엔타이틀먼트 변경 | 01_PRD ST-F-001, 리뷰 #4, AUTH_ROADMAP 2.2절 |
| ST-06-010 | 고지 동의와 법적 페이지(AI 처리 방식 단계는 ST-06-039의 `src/app/onboarding/ai/`) | `src/app/onboarding/disclaimer/`, `src/app/legal/`, `src/app/api/consents/` | 005, 006, 037 | P0 | S | Sonnet | 동의 2종 기록, 버전 변경 시 재동의 화면 | ST-F-002 |
| ST-06-011 | 디자인 시스템 2단계: Tailwind CSS v4 토큰(`tokens.css` `@theme`, 라이트/다크), 기본 컴포넌트와 배리언트, 미리보기 `/dev/components`, AppShell, 장 시간 바 | `src/styles/`, `src/components/ui/`, `src/components/shell/`, `src/app/dev/components/` | 006, 035 | P0 | M | Sonnet | 03장 4.3절 토큰만 사용(하드코딩 hex 0), 03장 3.8절 기본 컴포넌트 전부 라이트/다크 미리보기, `tailwind.config.js`·v3 문법 0, Tailwind 4.x 고정, 컴포넌트는 `--color-up`/`--color-down` 의미 토큰만 참조(D-5 미결), `COMPONENTS.md` 배리언트 표 초안, 장 시간 바가 `market_calendar`로 구간 표시, 375px 깨짐 없음, 대비 4.5:1 | 리뷰 5장 #3, 03장 4절, DESIGN_SYSTEM 4장 2단계 |
| ST-06-012 | 증권사 연결 API와 화면 | `src/app/api/connections/`, `src/app/(app)/settings/connections/` | 007, 008 | P0 | M | Opus | 상한 초과 409, live는 플래그 꺼짐 시 403, 키 오류 시 `error` 행, 응답·로그에 키 없음 | ST-F-003, ST-F-004 |
| ST-06-013 | 동기화 워커(`stock.sync`), 워커 진입점, 스케줄 | `workers/stock-jobs/src/index.ts`, `workers/stock-jobs/src/sync/`, `workers/stock-jobs/package.json` | 001, 008 | P0 | L | Opus | 같은 체결 2회 동기화 → 1행, 오류 5회 → 연결 error, org 불일치 잡은 재시도 없는 실패, service_role 사용 | 리뷰 5장 #9, ST-F-005 |
| ST-06-014 | 실제 증권사 어댑터(조회 전용) | `src/lib/broker/<선정 증권사>/` | 004, 008 | P1 | L | Opus | 계약 스위트를 모의투자 서버에서 통과, 토큰 캐시·갱신, 호출 한도 설정값 준수 | 리뷰 5장 #9 |
| ST-06-015 | 시세 중계 워커: WS 구독, SSE 팬아웃, 토큰 검증, 지연 감시 | `workers/quote-relay/` | 007, 008 | P0 | L | Fable | 다른 조직 토큰으로 구독 불가, 틱 → SSE p95 1초(Mock 부하 100 연결), 10/60초 상태 이벤트, 틱 DB 저장 0. 이유: 상주 프로세스·장애 처리 | 리뷰 5장 #10, 리뷰 #6 |
| ST-06-016 | 스트림 토큰 라우트와 시세 스토어(zustand 종목별 셀렉터) | `src/app/api/stream-token/`, `src/lib/quotes/` | 015 | P0 | M | Opus | 토큰 60초·1회용, 한 종목 틱에 다른 행 리렌더 0(Profiler 테스트) | 리뷰 5장 #10, 리뷰 #10 |
| ST-06-017 | 대시보드 UI: 탭, KPI 밴드, 보유 그리드 블링크, AI 요약 패널 | `src/app/(app)/dashboard/`, `src/components/portfolio/` | 011, 016, 037 | P0 | M | Sonnet | Total 합계 = 연결 합, 샘플 배지, reduced-motion 시 깜빡임 없음 | 리뷰 5장 #7 |
| ST-06-018 | 종목 상세 모달과 재무지표 API | `src/components/instrument/`, `src/app/api/instruments/` | 017 | P1 | S | Sonnet | 지표마다 출처·기준기간, 값 없으면 "-"와 사유 | 리뷰 5장 #8 |
| ST-06-019 | 참조 데이터 배치: 재무지표(DART), 캘린더, 일봉 | `workers/stock-jobs/src/reference/` | 013 | P1 | M | Opus | 휴장일 적재 후 동기화 주기 전환, DART 실패 종목 `missing` 기록 | 리뷰 #12, #14 |
| ST-06-020 | 매매 일지: 필터, 메모, CSV | `src/app/(app)/trades/`, `src/app/api/trades/` | 011, 037 | P1 | M | Sonnet | CSV UTF-8 BOM, 1만 행 초과 413, 다른 사람 메모 수정 불가 | ST-F-009, 리뷰 5장 #9 |
| ST-06-021 | AI 진단 라우트: 비율 스냅샷 조립, 위험 규칙(TS), 그래프 `stock.diagnosis` 호출(서명 토큰), zod, 크레딧, NDJSON 진행·결과 | `src/lib/ai/`(compare 제외), `src/app/api/ai/diagnoses/` | 007, 010, 026, 039, 045 | P0 | M | Opus | 실패 시 환불 행 1개, 가격 키 포함 출력 저장 불가, `advice_check` 없는 결과 저장 불가(`23514`), 입력에 없는 종목 → 재생성 → 실패, 일 상한 429, FastAPI 요청 본문에 금액·수량·계좌 문자열 0(요청 캡처 테스트) | 리뷰 5장 #11, 리뷰 #3·#11 |
| ST-06-022 | AI 진단 화면과 이력 | `src/app/(app)/ai/`(compare 제외), `src/components/ai/` | 011, 021, 037 | P1 | S | Sonnet | 고지·AI 배지·모델명·기준 시각 표시, 매수/매도 버튼 없음, 진행 3단계(근거 → 작성 → 검사) 표시, 검사 차단 시 환불 안내 | 리뷰 5장 #12 |
| ST-06-023 | 초대 전용 랜딩 `/` | `src/app/(marketing)/` | 011, 037, 050 | P1 | S | Sonnet | noindex, 03장 안 A, 금지 문구 점검 통과, 히어로에 ST-06-050 장착, 히어로 영역에 `%`·수익 관련 단어 0 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/products/_design-guide/REFERENCES.md:16-23`). | 03장 4절 |
| ST-06-024 | 운영자 화면(초대, 베타 회수, 동기화 오류, 전역 킬 스위치) | `src/app/(admin)/`, `src/app/api/admin/kill-switch/` | 009, 037 | P1 | S | Sonnet | platform_admin 외 403, 모든 쓰기 audit | ST-F-012 |
| ST-06-025 | E2E 테스트: 초대 → 가입 → 동의 → mock 연결 → 대시보드 → 진단, 베타 없는 계정 차단, AI 채팅 조언 거절, 요약 근거 없음 환불, 브리핑 낭독은 검사 통과분만 | `tests/e2e/` | 009, 012, 017, 021, 047, 049 | P0 | M | Opus | Playwright 시나리오 9개 통과(정상 1, 차단 5, AI 3: 조언 요청 거절, 근거 없음 환불, 브리핑 낭독). Mock 페르소나 storageState로 실행(`globalSetup`이 `/api/dev/login`으로 페르소나별 저장, 초대 수락 시나리오는 `invitee`의 시드 초대 링크). 같은 시나리오가 G1 증거이고 ST-06-052 뒤 다시 녹색(B-5) | 7절, AUTH_ROADMAP 2.1·5.3절 |
| ST-06-026 | 금칙어 사전(한국어 경계 처리)과 카피 점검 체크리스트 | `src/content/` | 005 | P0 | S | Haiku | 01_PRD 6.6 표의 예시 문구가 사전에 모두 걸림, 정상 상태 설명 문구 오탐 0. `banned.json`(언어 중립, 카테고리 7종: 권유, 가격 제시, 보장·단정, 시점 지시, 평가 어휘, 인용 목표주가, 비교 우위)을 FastAPI가 복사해 읽을 수 있고 `version`을 가진다 | 01_PRD 6.6 |
| ST-06-027 | 개발 문서와 `.env.example` 정리 | `.env.example`, `README.md`(앱 루트) | 006 | P1 | S | Haiku | 02장 8절 변수와 9절 인증 단계 변수 전부(`AUTH_MODE` 로컬 기본 `mock`, `DEV_SEED_PASSWORD`는 로컬 전용 표시), 실값 없음 | 리뷰 5장 #15 |
| ST-06-028 | 계정 설정: 동의 이력, 내 데이터 내려받기, 탈퇴 | `src/app/(app)/settings/account/`, `src/app/api/me/` | 010, 037 | P1 | S | Sonnet | JSON에 키·계좌 원문 없음, 탈퇴 시 조직 soft delete | 01_PRD 6.2 |
| ST-06-029 | (P2) AI 아이디어, 성과 배치 `idea-eval-v1`, 내부 리더보드 | `workers/stock-jobs/src/eval/`, `src/app/api/ai/ideas/`, `src/app/api/leaderboard/`, `src/app/(app)/leaderboard/` | 021, 019, 045 | P2 | M | Opus | 규칙 단위 테스트(다음 개장일 시가, 정지 종목), n<20 순위 미표시 | 리뷰 5장 #13, ST-F-013 |
| ST-06-030 | (P2) AI 3사 비교 | `src/lib/ai/compare/`, `src/app/api/ai/compare/`, `src/app/(app)/ai/compare/` | 021, 045 | P2 | M | Opus | 모델명 하드코딩 0, 한 모델 실패 시 부분 환불 | ST-F-014, 리뷰 #16 |
| ST-06-031 | (P2) 결제: pro 주문, confirm, Toss 웹훅, 결제 E2E(Toss 테스트 키, 필수) | `src/app/api/billing/`, `src/app/api/webhooks/toss/`, `src/app/(app)/settings/billing/`, `tests/e2e/billing/` | 005(법률 의견), 009 | P2 | M | Fable | 테스트 키로 결제 → pro 엔타이틀먼트·400 크레딧, 금액 위조 → PM001 + `fail_payment_order` + 취소 + 알림, 서명 없는 웹훅 401. 이유: 결제 | 확정 결정 4, ST-F-016 |
| ST-06-032 | (P3) 모의주문 모듈: 미리보기, 비중 검사, 확인, 제출 워커, 킬 스위치·한도 API | `src/lib/orders/`, `src/app/api/orders/`, `src/app/api/kill-switch/`, `src/app/api/order-limits/`, `workers/stock-jobs/src/orders/` | 003, 014 | P2 | L | Fable | `ORDERS_ENABLED=false`면 라우트 404, 제출 재시도 0회, 킬 스위치 뒤 제출 → blocked. 이유: 돈이 걸린 로직 | 리뷰 5장 #14, 리뷰 #2 |
| ST-06-033 | (P3) 주문 패널, 확인 화면(60초), 한도·킬 스위치 화면, 모의투자 배너 | `src/app/(app)/orders/`, `src/app/(app)/settings/limits/`, `src/components/orders/` | 032 | P2 | M | Sonnet | 확인 전 주문 생성 없음, 만료 표시, "모의투자" 배너 상시 | 리뷰 5장 #14 |
| ST-06-034 | (P3) 주문 안전장치 테스트 + 자동 킬 스위치 감시(시세 60초, 오류 3회, 잔고 불일치 1%) | `supabase/tests/orders/`, `tests/orders/`, `workers/stock-jobs/src/watchdog/` | 032 | P2 | M | Fable | 조건별 자동 스위치 작동, 사용자 해제 42501, 동시 주문 50건에서 일 한도 초과 0 | 리뷰 5장 #14, 리뷰 #2 |
| ST-06-035 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Primer, 상태 배지 Atlassian, 채팅 Astryx 패턴 확인, 랜딩 HERO_3D), 가져올 것·안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.8절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D-17). D-5 미결 상태와 `--color-up`/`--color-down` 토큰 규칙 기록. 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/products/_design-guide/REFERENCES.md:205` stock-dashboard 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/products/_design-guide/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| ST-06-036 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | 011 | P0 | M | 사람(보조 Sonnet) | 03장 3.8절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| ST-06-037 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `COMPONENTS.md` | 036 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| ST-06-038 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, stock 설정(app, `STOCK_KNOWLEDGE_ORG_ID`, 컬렉션 이름, `STOCK_RAG_SOURCES` 파서), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/stock/`, `app/ai/compliance/stock.py`, `app/ai/products/stock/` 제외), `apps/api/tests/platform/` | 001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 필수 변수 누락 시 기동 실패, 요청 스키마에 수량·금액·계좌 필드가 있으면 거부. 이유: 서명 토큰·조직 격리 | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| ST-06-039 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 그래프 실행 요청 헬퍼(서명 토큰), 턴·정액 선차감·정산, 정산 크론, AI 단가, 온보딩 AI 처리 방식(국외 이전 동의) | `apps/stock-dashboard/src/app/api/ai/`(`diagnoses/`, `research/`, `briefings/`, `ideas/`, `compare/` 제외), `src/app/api/internal/`, `src/app/api/onboarding/`, `src/app/onboarding/ai/`, `src/server/ai/`, `src/server/ai-pricing.ts` | 006, 007, 038 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 동의 시 `ai_org_settings`·`consents` 버전 일치, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 요청·로그에 보유 수량·금액·계좌 0, `STOCK_AI_ENABLED=false`면 503과 차감 0. 이유: 돈·동의 경계 | 01장 ST-F-026, 029, 030 |
| ST-06-040 | 투자 권유 금지 검사 모듈: `advice_check`(규칙 사전 + LLM 판정, fail-closed)와 `compliance` 규칙, 평가셋 120문장, 그래프·채팅·위키가 부르는 공통 함수 | `apps/api/app/ai/compliance/stock.py`, `apps/api/tests/stock/advice/` | 026, 038 | P0 | M | Fable | 평가셋 위반 차단 98% 이상·정상 오탐 5% 이하(제안), 위반 유형 7종 테스트 문장 전부 차단, 판정 모델 경로를 제거하면 통과 0(fail-closed), 로그에 위반 원문 0, `rules_version`이 결과에 기록. 이유: 법적 위험의 핵심 방어선 | 01장 ST-F-022 |
| ST-06-041 | 공시 RAG 수집·색인: DART 공시 수집 잡, 청크·임베딩(oss-embed), 컬렉션 `stock-disclosures`, 소스 허용 목록(`STOCK_RAG_SOURCES`, `terms_ref`), 검색 평가셋 40문항 | `apps/api/app/ai/products/stock/knowledge.py`, `disclosures.py`, `apps/api/tests/stock/retrieval/`, `apps/api/tests/fixtures/` | 001, 005, 038 | P0 | M | Opus | `terms_ref` 없는 소스 색인 `ST_SOURCE_DISABLED`, 합성 공시 평가셋 재현율@8 0.8 이상, 다른 조직 컬렉션 요청 `42501`, 같은 접수번호 재수집 중복 0, 컬렉션당 임베딩 모델 1종, 개발·테스트는 합성 문서만 사용(실제 수집은 D-10 확정 뒤) | 01장 ST-F-024, D-10 |
| ST-06-042 | 해설집 원고(주식 용어·공시 해설) | `content/knowledge/` | 005, 026 | P0 | M | Sonnet | 용어 80항목 이상(제안: PER, PBR, ROE, EPS, 배당수익률, 유상증자, 감자, 전환사채, 정정공시, 자기주식 취득 등), 항목마다 작성자·검수일·출처 메타데이터, `banned.json` 검사 위반 0(가격·권유 표현 없음), 운영자 검수 기록 | 01장 ST-F-025 |
| ST-06-043 | 위키 운영: 해설집 → 위키 ingest(draft), 게시·편집·이력·lint 관리자 화면과 API, 주 1회 lint 잡 | `apps/api/app/ai/products/stock/wiki_config.py`, `src/app/(admin)/admin/wiki/`, `src/app/(admin)/admin/knowledge/`, `src/app/api/admin/wiki/`, `src/app/api/admin/knowledge/` | 037, 040, 041, 042 | P0 | M | Opus | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, ingest 결과가 규칙 사전 통과, lint 결과 화면 표시, 소스별 이용 조건 확인 기록 표시, 모든 쓰기 감사 1행 | 01장 ST-F-025, LLM_WIKI 3장 |
| ST-06-044 | 위키 화면(`/wiki` 목록·검색·페이지·출처·관련) | `src/app/(app)/wiki/` | 037, 043 | P1 | S | Sonnet | 비로그인 `/login` 이동, `published`만 노출(draft 0), "AI가 정리하고 운영자가 검수한 문서" 표시, noindex, 금지 문구 0 | 01장 ST-F-025, D-16 |
| ST-06-045 | LangGraph 그래프 `stock.research_summary`(retrieve → summarize → advice_check → compliance, summary·briefing 모드)와 `stock.diagnosis`(explain → advice_check → compliance), 체크포인트, 실행 기록, 출력 스키마 | `apps/api/app/ai/graphs/stock_research_summary.py`, `stock_diagnosis.py`, `apps/api/app/ai/products/stock/prompts/`, `apps/api/tests/stock/graph/` | 038, 040, 041 | P0 | L | Opus | 실행 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 문장마다 출처 1개 이상, 입력 외 종목 0, 위반 시 1회 재생성·2회 실패 시 run failed(`ADVICE_BLOCKED`), compliance가 마지막 노드, 수량·금액 필드 입력 거부, 요약 평가셋 20건을 상용·오픈소스 경로 모두 통과 | 01장 ST-F-011, 023 |
| ST-06-046 | Dify `stock-chat`(분류 노드, 고정 거절 노드, HTTP 노드)와 `/tools/answer` stock 확장(모드 research·term, 의도 판정, 마스킹, advice_check·compliance 후처리), 채팅 평가셋 60문항 | `infra/dify/`, `apps/api/app/ai/tools/stock/`, `apps/api/tests/stock/chat/` | 039, 040, 041 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 평가셋 조언 요청·우회 30문항 전부 거절, 사실 질문 답변 출처 1개 이상 또는 `no_source`, Dify 분류를 틀리게 주입해도 조언 거절, DSL에 키 0, 모델 생성 텍스트를 직접 내보내는 Dify 노드 0 | 01장 ST-F-026, 04장 6.2절 |
| ST-06-047 | 채팅 패널과 대화 목록(출처 칩, 거절 카드, 크레딧 안내, AI 생성 표시) | `src/components/ai-chat/`, `src/app/(app)/chat/` | 037, 039 | P0 | M | Sonnet | 03장 3.7절 구성, 375px 전체 화면 시트, `aria-live`, 402 충전 모달, 거절·대체·근거 없음·환불 상태 표시, 고정 안내 문구. 대시보드 장착은 ST-06-017 파일에 1줄 요청 | 01장 ST-F-026, 03장 5절 |
| ST-06-048 | 음성 질의: `/api/voice/*`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기 | `src/app/api/voice/`(`briefings/` 제외), `src/components/voice/` | 039, 047 | P0 | M | Opus | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, 음성 명령으로 주문·연결 호출 0, TTS 입력은 DB의 assistant 메시지만 | 01장 ST-F-027 |
| ST-06-049 | 리서치 요약·브리핑 API와 화면, 브리핑 낭독(`/api/voice/briefings`)과 플레이어 | `src/app/api/ai/research/`, `src/app/api/ai/briefings/`, `src/app/api/voice/briefings/`, `src/app/(app)/research/`, `src/app/(app)/briefing/`, `src/components/briefing/` | 037, 039, 045, 048 | P0 | M | Opus | 03장 3.7절 구성. 검사 통과 전 대본으로 TTS 호출 0(임의 텍스트 요청 거부), 한 낭독의 `ai_usage` 제공자 1종·`fallback_from` null, 중간 실패 시 파일 0 + 환불 1행, 같은 브리핑 재요청 차감 0, 미동의 조직은 처음부터 oss-voice, 근거 없음은 환불 | 01장 ST-F-023, 028 |
| ST-06-050 | 3D 히어로: 시세 흐름 지형(PC·태블릿), 2D 지형 단면(모바일), 정지 이미지, 성능 예산, 수익 약속 방지 단위 테스트 | `src/components/hero3d/`, `public/hero/` | 037 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 상승/하락 색·`%`·종목명 0, 앞/뒤 1/3 평균 높이 비 0.8~1.25 단위 테스트, 데이터는 고정 시드 샘플 | 01장 ST-F-031, 03장 4.5절 |
| ST-06-051 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 선차감·정산·환불, 라우팅 seed 스냅샷, 투자 권유 금지 우회 시나리오, 보유 내역 비유출) | `apps/api/tests/stock/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | 039, 040, 045, 046, 048, 049 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 12개 x 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, 원장 drift 0, 판정 경로 차단 시 AI 출력 0, 요청 캡처에서 금액·수량·계좌 문자열 0, 음성으로 주문 호출 0, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 005, 035 | 4 | 없음 | DB·타입(AI 기본값 포함), 증권사 선정, 법률 질의서·고지 초안·소스 확인 기록 틀, 디자인 레퍼런스(1단계) |
| W1 | 002, 003, 006, 008, 026, 038 | 6 | W0 완료 | 변환 스크립트, RLS 테스트, 앱 골격, 어댑터 계약, 금칙어 사전, AI 서비스 설치 |
| W2 | 007, 011, 027, 040, 041, 042 | 6 | 006 완료(011은 035도) | 보안 유틸, 디자인 시스템 2단계, 환경 정리, 투자 권유 금지 검사, 공시 RAG, 해설집 원고 |
| W2-D | 036 → 037(직렬) | 1 | 011 | 디자인 시스템 3~4단계(사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W3 | 009, 010, 012, 013, 015, 039, 045, 050 | 8 | W2 완료, 화면은 037 | 초대, 동의 화면, 연결, 동기화, 시세 워커, AI 게이트, AI 그래프, 3D 히어로 |
| W4 | 014, 016, 019, 020, 021, 024, 028, 043, 046, 047 | 10 | W3 | 실어댑터, 시세 스토어, 배치, 일지, AI 진단 라우트, 운영자, 계정, 위키 운영, Dify 채팅, 채팅 패널 |
| W5 | 017, 022, 023, 044, 048 | 5 | W4 | 대시보드, 진단 화면, 랜딩, 위키 화면, 음성 질의 |
| W6 | 018, 049 | 2 | 017·048 완료 | 종목 상세 모달, 리서치 요약·브리핑·낭독 |
| W7 | 052(G1 통과 후 먼저), 025, 051 | 3 | W6 + G1(052) | Google 로그인 전환(Stage B), E2E, AI 보안 회귀 → **MVP 완료**(초대 베타 공개) |
| W8(P2) | 029, 030, 031, 053·054(G2 통과 후, 선택) | 5 | MVP + 법률 의견(031), 053·054는 G2 + 01_PRD D-19 | 아이디어/리더보드, 3사 비교, 결제, 카카오·네이버 로그인 |
| W9(P3) | 032 | 1 | 사용자 결정(01_PRD D-4) | 주문 모듈 |
| W10(P3) | 033, 034 | 2 | 032 완료 | 주문 UI, 안전장치 테스트 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 14 (001, 003, 007, 009, 015, 031, 032, 034, 038, 039, 040, 051, 052, 054) | 26.4% | 31/98 = 31.6% |
| Opus | 20 (004, 006, 008, 012, 013, 014, 016, 019, 021, 025, 029, 030, 037, 041, 043, 045, 046, 048, 049, 053) | 37.7% | 40/98 = 40.8% |
| Sonnet | 16 (005, 010, 011, 017, 018, 020, 022, 023, 024, 028, 033, 035, 042, 044, 047, 050) | 30.2% | 24/98 = 24.5% |
| Haiku | 3 (002, 026, 027) | 5.7% | 3/98 = 3.1% |
| 합계 | 53 | 100% | 98 |

비율은 모델 작업 53개 기준이다(2026-10-14 인증 단계 052 Fable M, 053 Opus S, 054 Fable M 추가. 그 전 50개 기준은 Fable 24.0%, Opus 38.0%, Sonnet 32.0%, Haiku 6.0%, 가중 29.0/41.9/25.8/3.2%). 사람 작업 1개(ST-06-036, M)는 비율에서 뺐다. 2026-10-13 이전(34개)은 Fable 23.5%, Opus 35.3%, Sonnet 32.4%, Haiku 8.8%였다. 새 Fable 작업(038, 039, 040, 051)은 서명 토큰·조직 격리, 선차감·동의 경계, 투자 권유 금지 검사, AI 보안 회귀처럼 법과 돈이 걸린 경계다. 그래프·RAG·Dify·음성 구현은 Opus, 채팅 패널·위키 화면·3D 히어로·해설집 원고는 Sonnet이다(`docs/products/_platform-core/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

리뷰 5장 작업 15개(`docs/reviews/Stock_Trader_nomad.md:116-130`) 전부를 흡수했다.

| 리뷰 5장 # | 작업 | 흡수한 작업 ID |
|---|---|---|
| 1 | PRD 보강(개인/공개 결정, 주문 범위, 데이터 모델, 수익률 규칙, 비기능, 안전장치) | 이 기획서 01~05장(완료), ST-06-005(법률 확인) |
| 2 | 증권사 API 기술 검증 | ST-06-004 |
| 3 | 프로젝트 골격, 다크 테마 토큰 | ST-06-006, ST-06-011, ST-06-035, ST-06-036, ST-06-037 |
| 4 | 스키마와 RLS | ST-06-001, ST-06-003 |
| 5 | 키 보관 모듈 | ST-06-007 |
| 6 | `BrokerAdapter`, `MockBroker` | ST-06-008 |
| 7 | 대시보드 UI | ST-06-017, ST-06-011 |
| 8 | 종목 상세 모달 | ST-06-018 |
| 9 | 실제 증권사 어댑터, 매매 일지 동기화 | ST-06-014, ST-06-013, ST-06-020 |
| 10 | 시세 워커 | ST-06-015, ST-06-016 |
| 11 | AI 진단 라우트 | ST-06-021, ST-06-026, ST-06-040, ST-06-045 |
| 12 | AI 어드바이저 패널 UI | ST-06-022, ST-06-047 |
| 13 | 성과 배치와 내부 리더보드 | ST-06-029 |
| 14 | 모의투자 주문 모듈 | ST-06-032, ST-06-033, ST-06-034 |
| 15 | `claude.md` 정리 | ST-06-027, 이 폴더 `CLAUDE.md` |

## 6. 공용 모듈 요청

코어는 이 제품이 바꾸지 않는다. 아래는 `_platform-core` 담당(Fable)에게 남길 요청이다.

| ID | 요청 | 이유 | 제품 측 임시 대응 |
|---|---|---|---|
| R-1 | `apps.signup_policy = 'invite'` 강제: `on_signup_app_bootstrap`/`bootstrap_app_for_org`가 invite 앱이면 엔타이틀먼트를 만들지 않거나 초대 확인 훅을 호출 | 해결(2026-10-13 코어 반영 완료): invite 앱은 가입 트리거가 구독·엔타이틀먼트를 만들지 않고 `bootstrap_app_for_org`는 비 service 호출자에 42501(이전에는 누구나 stock 엔타이틀먼트를 얻었다) | `beta_access` 게이트를 2차 게이트로 유지(스모크로 검증) |
| R-2 | 엔타이틀먼트 플랜 변경 RPC(`change_entitlement_plan(org, app, plan_code, source, actor)`, service_role, 구독·엔타이틀먼트·감사를 한 트랜잭션) | 베타 전환이 서버의 UPDATE 2회 + grant로 나뉜다 | 04장 3절 순서 + 멱등 키 |
| R-3 | `confirm_payment_order` 금액 불일치 시 주문 `failed` 기록(알려진 결함, `DB_CONVENTIONS.md:296`) | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가 | PM001 시 별도 호출 후 취소·감사·알림(04장 5절) |
| R-4 | `adjust_credits`(`CORE_SPEC.md:237`) | Phase 2 환불 시 미사용 크레딧 조정 | Phase 2 전까지 불필요 |
| R-5 | 공용 패키지 `packages/core-auth`의 vault가 `provider` 접두사 규칙(`broker:<broker>:<env>`)을 허용하는지 확인 | 연결별 자격증명 구분 | 제품 규칙으로 사용 |
| R-6 | `_supabase-modular/seed.sql`: stock beta·pro `features`에 `ai_chat`, `ai_chat_turns_per_day`, `ai_research_per_day`, `voice_chat`, `briefing` 추가 | seed가 1900보다 나중에 실행되면 14.3절 병합 UPDATE가 덮어써진다 | 서버가 누락 키를 기본값으로 읽는다(01_PRD 4.3절) |
| R-7 | ai-service: (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | Dify 분류 노드 라우팅(`dify.aux`)과 관리자 위키 편집 | (a) Dify에 기능별 모델 이름을 따로 등록 (b) `app/ai/products/stock/wiki_config.py`에 임시 구현 |
| R-8 | ai-service 라우터: 제공자를 지정해 호출하는 옵션(Phase 2 3사 비교용). 동의·강제 오픈소스 필터는 유지 | 체인 순서 대체로는 같은 입력을 3개 모델에 보낼 수 없다 | Phase 2 착수 때까지 불필요 |
| R-9 | `_design-guide` 3D 키트: 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/products/_design-guide/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| R-10 | 공용 Dify: `stock-chat` 앱 생성, 내부 키 환경 변수, 외부 지식 `stock-wiki` 등록, 로그 보존 30일 | 공용 인프라는 코어 소유 | 없음(필수). 장애 시 `/tools/answer-direct` |
| R-11 | core-voice: 기능별 대체 금지 옵션(`feature='briefing'`)과 "시작 제공자 고정" 동작을 `VoiceAdapter` 계약에 명시 | `VOICE_ARCHITECTURE.md` 3장 대체 금지를 코드 계약으로 강제 | 브리핑 Route Handler가 체인 첫 제공자 하나만 넘겨 호출 |

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
| AI·음성 | `pytest apps/api` 통과, ST-06-051 녹색, 요약 평가셋 20건을 상용·오픈소스 경로 모두 통과, 투자 권유 평가셋 120문장·채팅 평가셋 60문항 기준 충족, 브리핑 대체 금지 테스트 통과 | `pytest apps/api`, `pnpm test:ai` |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(ST-06-037) 완료, `tailwind.config.js`·hex 하드코딩 0 | 체크리스트 |
| 데이터 이용 | 실제 공시 수집은 D-10 확정과 `docs/legal/data-sources.md` 확인 뒤에만 켠다 | 체크리스트 |
| 작업 | 이 장 MVP(P0/P1) 작업 전부 완료(W0~W7) | - |

P0 작업과 테스트 대응:

| P0 작업 | 대응 테스트 |
|---|---|
| 001, 009, 052 | 003(RLS), 025(E2E, Mock storageState. 052 뒤 재실행 B-5), 052 콜백 단위 테스트(B-2, B-3)와 Google 수동 점검표(B-5) |
| 002 | 002 자체 CI 비교 |
| 004 | 008 계약 스위트(실서버 실행은 014) |
| 005, 010 | 025(동의 리다이렉트) |
| 006, 011, 017 | 025, 006 Mock 가드 검사(`AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, live `/api/dev/login` 404) |
| 007 | 007 단위 테스트 |
| 008 | 계약 스위트 |
| 012, 013 | 025 + 013 통합 테스트(중복 체결) |
| 015, 016 | 015 부하 테스트, 016 Profiler 테스트 |
| 021, 026 | 021 단위(가격 키, 환불), 026 사전 테스트 |
| 025 | 자기 자신 |
| 035, 037, 044, 050 | 036(사람 검토), 025, 050 자체 단위 테스트 |
| 038, 039 | 051 |
| 040 | 040 평가셋(자기 자신), 051 |
| 041 | 041 평가셋·테스트 |
| 042, 043 | 043 규칙 사전 검사, ingest 테스트 |
| 045, 046 | 045·046 평가셋, 051 |
| 047, 048, 049 | 025(AI 3종), 051 |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md` 9장. 기존 인증 작업은 ST-06-006(앱 골격 + 인증 모듈·Mock 로그인·가드·`finishLogin`)과 ST-06-009(초대·수락 + 시드 제품 훅)이고, 둘 다 같은 행 안에서 Stage A 범위로 바꿨다(웨이브 W1, W3 그대로). W0~W2 작업(001~005, 008, 026, 035, 038, 040~042 등)은 시드 스크립트(공통은 006, stock 제품 훅은 009·W3) 없이 SQL·단위 테스트로 검증한다. 이 제품은 invite 앱이라 C1·C2는 P2 선택이다(`AUTH_ROADMAP.md:333`).

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| ST-06-052 | Stage B: Google OAuth 전환 + 이메일·초대 화면. `/login`에 "Google로 계속하기"와 이메일+비밀번호 폼, `/invite/[token]`의 "Google로 계속하기"(초대 쿠키 → OAuth → `/invite/continue` → 수락), 이메일 가입(초대 화면 안)·비밀번호 재설정 화면, `/auth/callback`(`finishLogin` 전체), 온보딩 첫 단계 약관 동의, 배포 체크리스트 | `src/components/auth/`, `src/app/auth/`, `src/app/invite/continue/`, `docs/ops/auth-checklist.md`. 예외: `supabase/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`만(001 소유 파일). `/login` 페이지(006), `/invite/[token]` 페이지(009), `/onboarding/disclaimer`(010)에는 `src/components/auth/` 컴포넌트 장착 1줄씩 요청 | 006, 009, 010 + G1(`[DECISION] G1 통과`) | P0 | M | Fable | AUTH_ROADMAP 5.3 B-1~B-6 그대로: B-1 새 Google 계정 첫 로그인 → invite 앱이라 `entitled=false`·`/no-access`, 같은 계정이 초대 링크로 들어오면 수락 → beta·300 크레딧 1회(재로그인 3회 뒤에도 원장 행 수 같음). B-2 `next=//evil.com`·`https://evil.com`·`/\evil.com` → 기본 경로. B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 로그에 토큰·코드 0. B-4 `VERCEL_ENV=production` 빌드에서 `/api/dev/login` 404·개발용 패널 없음·`AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(ST-06-025) 계속 녹색, Google 실로그인은 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)를 task `log.md`에. B-6 운영 대시보드 Google 설정·Redirect URLs·`AUTH_PROVIDERS=google,email`이 체크리스트와 일치. 제품 추가: 초대 이메일과 다른 Google 계정 → `ST031` + "초대받은 이메일로 로그인하세요", 새 사용자 엔타이틀먼트 0. 초대 토큰 원문이 리디렉트 URL·서버 로그에 0(D-23). 이유: 세션 발급·엔타이틀먼트 경계 | 01_PRD ST-F-001·8.1절, AUTH_ROADMAP 5장, 02장 9절, 03장 7절, 04장 8절 |
| ST-06-053 | Stage C1: 카카오 로그인(P2 선택). `kakao` 제공자 버튼(`/login`, `/invite/[token]`), config, 이메일 정책(01_PRD D-20 (a) 권장), 초대 수락 시 이메일 일치 유지 | `src/components/auth/kakao/`(052 소유 `src/components/auth/`의 하위 폴더, 052 완료 후 이어 받음), `supabase/config.toml`의 `[auth.external.kakao]`만(001 소유 파일, 052 예외와 같은 방식) | 052 + G2 + 01_PRD D-19 | P2 | S | Opus | AUTH_ROADMAP 7.1.3 C1-1~C1-5 그대로(C1-1의 "B-1과 같은 결과"는 이 제품에서 `entitled=false` → 초대 수락 후 beta). 이메일 없는 카카오 계정은 초대 수락 화면에서 "초대받은 이메일이 있는 계정으로 로그인하세요", 엔타이틀먼트 0. 운영 `AUTH_PROVIDERS`에 `kakao`는 콘솔 설정 확인 후에만 | 01_PRD 8.1절, AUTH_ROADMAP 7.1절 |
| ST-06-054 | Stage C2: 네이버 로그인(P2 선택). 스파이크(0.5일) → `custom:naver` 또는 서버 브리지, 등록 스크립트, 브리지면 `/auth/naver/start`·`/auth/naver/callback`, 설정 → 로그인 방법(연결·해제, AUTH_ROADMAP 7.3절) | `src/components/auth/naver/`, `src/components/auth/login-methods/`, `src/app/auth/naver/`(브리지일 때만. 셋 다 052 소유 디렉토리의 하위 폴더라 052 완료 후 이어 받음), `scripts/auth/register-naver-provider.mjs`. 설정 → 로그인 방법 장착은 028 소유 `src/app/(app)/settings/account/`에 1줄 요청 | 052 + G2 + 01_PRD D-19 | P2 | M | Fable | AUTH_ROADMAP 7.2.4 C2-1~C2-6 그대로: C2-1 스파이크 결과 `[DECISION]`과 `NAVER_AUTH_PATH` 일치, C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 결과(이 제품은 초대 수락 전 `entitled=false`), C2-3 재로그인 5회 같은 `user_id`, C2-4 (브리지) state 변조·재사용·쿠키 없음·다른 브라우저 재생 거부, C2-5 (브리지) 같은 이메일 Google 가입자 → `email_in_use`·새 사용자 0, C2-6 검수 통과 전 운영 `AUTH_PROVIDERS`에 `naver` 없음. 이유: 브리지는 세션 발급 경로 | 01_PRD 8.1절, AUTH_ROADMAP 7.2·7.3절 |

게이트와 웨이브(3절 표에도 반영):

| 게이트 | 판정 | 다음 작업 |
|---|---|---|
| G1 | 사람(대표님)이 `AUTH_ROADMAP.md:177-184` 6항목을 확인하고 task `log.md`에 `[DECISION] G1 통과`. 이 제품의 항목 1은 W0~W6 P0 기능 작업 완료, 항목 2는 ST-06-025 시나리오를 Mock storageState로 실행한 결과, 항목 4(결제)는 MVP에 결제가 없어 해당 없음, 항목 6은 Google 콘솔·운영 Supabase 준비 + ST-06-005 약관·처리방침 URL | W7 맨 앞 ST-06-052, 이어서 025 최종·051 |
| G2 | 사람이 `AUTH_ROADMAP.md:223-229` 확인(초대 베타 Google 실사용 2주, 콜백 오류율 1% 미만 등 제안값). 항목 3은 open 앱 기준이라 이 제품은 "초대 수락자 중 `entitled=false` 0"으로 읽는다 | W8 ST-06-053·054(01_PRD D-19에서 착수를 정한 경우만) |

| 항목 | 기록 |
|---|---|
| 작업 수 | 51 → 54(모델 작업 50 → 53). 4절 표를 다시 계산했다 |
| 소유 경계 | `src/app/invite/`는 009, 그 안의 `continue/`만 052. `src/components/auth/`·`src/app/auth/`는 052이고 053·054는 그 하위 폴더(`kakao/`, `naver/`, `login-methods/`, `auth/naver/`)를 052 완료 뒤 이어 받는다(직렬이라 동시 쓰기 없음). `/login`(006), `/invite/[token]`(009), `/onboarding/disclaimer`(010), `/settings/account`(028)에는 컴포넌트 장착 1줄 요청. `supabase/config.toml`은 001 소유이고 052·053은 자기 제공자 블록만 고친다 |
| 불일치 1: G1과 E2E 순서 | AUTH_ROADMAP은 G1에 "핵심 플로우 E2E 녹색"을 요구하고 B 작업을 통합·E2E 웨이브 맨 앞에 둔다. 이 제품의 E2E(025)는 W7이라, W7 시작 때 025 담당이 시나리오를 먼저 Mock으로 실행해 G1 증거로 쓰고, 052 완료 뒤 같은 시나리오를 다시 녹색으로 만들어 025를 닫는다(B-5) |
| 불일치 2: 약관 동의 기록 | 첫 OAuth 로그인 뒤 약관 동의를 온보딩 첫 단계에 두지만 `consents.kind`(`1900_stock.sql:567`)에 약관 kind가 없다. 선택지 (a) 투자 고지 동의 화면에서 이용약관·처리방침 동의를 함께 받고 `investment_disclaimer` 같은 버전으로 묶어 기록(스키마 변경 없음, 제안) (b) kind 추가(스키마 변경, ST-06-001·003 갱신). 052 착수 전 결정 |
| 불일치 3: 매직링크 | 03장 1절 `/login`은 매직링크를 적었고 AUTH_ROADMAP 1장은 범위 밖으로 둔다. 01_PRD D-22로 남겼다(이 작업에서 기존 표기를 지우지 않음) |
| 코어 요청(조건부) R-12 | ST-06-054가 브리지 경로를 택하면 코어 담당에게 `docs/products/_platform-core/staged/0010_core_auth_identity_links.sql` 적용을 요청한다(코어 1회 적용, 이 제품은 모놀리스라 변환본 반영도 함께 요청) |
| MockBroker | 인증 Mock(Stage A)과 증권사 `MockBroker`(ST-06-008, 샘플 연결)는 다른 개념이다. 인증 단계 전환은 `MockBroker`와 "샘플 데이터" 배지에 영향을 주지 않는다 |
