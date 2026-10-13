# 06 에이전트 작업 계획: NOMAD Commerce

작업 ID는 `CM-06-###`(DB_CONVENTIONS 1장 SQLSTATE 접두사 `CM`).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/products/_design-guide/DESIGN_SYSTEM.md` 4장) 작업 17개(CM-06-041~057)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 001·002·004·005(수용 기준 보강), 006·017·020·031(소유 경로 조정), 011·013(그래프 호출로 변경, 선행 추가), 012·027·029·032·033·035·036·038(수용 기준 또는 선행 보강)이다. 작업 수 57개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘어난 것이고, 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다. 웨이브는 3절에서 다시 짰다(011과 013은 그래프 선행 때문에 W5로 이동).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 작업마다 디렉토리(또는 파일)를 하나 이상 소유하고, 다른 작업의 소유 경로를 수정하지 않는다. 필요한 변경은 소유 작업에 요청 |
| 공유 등록 지점 없음 | 워커 핸들러는 `services/commerce-worker/src/<영역>/handler.ts` 규약으로 런타임이 자동 로드한다(CM-06-012). 화면 메뉴는 `packages/commerce-domain/nav.ts` 상수(CM-06-006)를 읽는다. 공용 인덱스 파일을 여러 작업이 고치지 않는다 |
| 패키지 경계 | 앱과 워커는 `packages/commerce-*`만 공유(02장 2절). `_platform-core` 패키지는 소비만 |
| 코어 불변 | `core.*`, `_platform-core/`, `_supabase-modular/`의 다른 파일을 고치지 않는다. 필요하면 6절 요청 |
| 테스트 동반 | P0 작업은 수용 기준에 자체 테스트를 포함하고, 교차 검증은 CM-06-003(RLS), CM-06-026(결제), CM-06-035(플로우)가 맡는다 |
| 모델 | Fable: 결제, 권한, RLS, 데이터 모델, AI 보안 경계 / Opus: 기능, API 연동, 그래프, 테스트 설계 / Sonnet: UI, 랜딩, 컴포넌트, 문서, 규칙 원고 / Haiku: 보일러플레이트, 린트, 문구, 반복 점검 |
| AI 서비스 경계 | `apps/api/`는 CM-06-045가 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. commerce 확장은 작업별로 나눈다: 048 `app/ai/products/commerce/knowledge.py`, 049 `wiki_config.py`, 051 `app/ai/graphs/commerce_*.py`·`app/ai/compliance/commerce.py`·`packages/commerce-domain/schema/`, 052 `app/ai/tools/commerce/` |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6.1절에 요청한다(R-2~R-5) |
| 언어 중립 파일 | `packages/commerce-compliance/rules/`, `fixtures/`는 CM-06-017 소유, `packages/commerce-domain/schema/`는 CM-06-051 소유. FastAPI는 빌드 때 복사해 읽기만 한다 |
| AI 라우트 소유 | `app/api/ai/`는 하위 폴더 단위로 나눈다: `{conversations,chat}` 046, `{names,autofill,benchmark,vision}` 011, `voice-structure` 054, `shorts-script` 055. `app/api/voice/`는 `narrations/` 055, 나머지 054. `app/api/internal/`·`onboarding/` 046 |
| 사람 작업 | CM-06-043(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 화면 진입 조건 | 디자인 시스템 4단계(CM-06-044)가 끝나기 전에는 화면 작업(027, 032, 050, 053, 056)을 시작하지 않는다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| CM-06-001 | DB 조각 적용, `config.toml` 스키마 노출, 타입 생성 | `supabase/migrations/1400_commerce.sql`(제품 저장소 복사본), `apps/nomad-commerce/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, 체커 OK, `--schema core,commerce` 타입 생성. 스키마 변경 시 05장 동기화. 조각 20절 적용 후 `ai_routing_settings`(org null, app commerce) 14행과 플랜 AI 키 4개, 2회 반복 적용 OK | V2 #2, v1 #1·#4, CM #6, 05장 |
| CM-06-002 | 모놀리스 변환 스크립트(HEADER 제거, 접두사·schemaname 치환) | `scripts/db/commerce-monolith.sh` | CM-06-001 | P1 | S | Haiku | 조각 → `0002_commerce_domain.sql` 재생성 결과가 저장본과 diff 0, mono 체커 OK. 조각 20절 ↔ `seed.sql`의 라우팅 14행·플랜 AI 키가 같은 값인지 스냅샷 비교 | DB_CONVENTIONS 12장 |
| CM-06-003 | RLS/권한 회귀 테스트(PGlite + 로컬 Supabase) | `tests/rls/` | CM-06-001 | P0 | M | Fable | 05장 9절 항목 60개 + SECURITY_BASELINE 15장 전부 통과. CI에서 실패 시 머지 차단 | SECURITY_BASELINE 15장, V2 #2·#4 |
| CM-06-004 | 앱 골격 이식(sellingstudio → 모노레포): 라우트 그룹, core-db 클라이언트, 의존성 고정, 미사용 의존성 제거, CSP 강화 | `apps/nomad-commerce/{package.json,next.config.ts,app/layout.tsx,app/globals.css}` | 없음 | P0 | M | Sonnet | `pnpm build` 통과, `unsafe-eval`·사설 IP 없음, `latest` 0건, Stripe·미사용 14개 제거, Tailwind CSS v4 설정(`@import "tailwindcss"`, `@theme`)만 사용하고 `tailwind.config.js` 0, `globals.css`가 `styles/tokens.css`(CM-06-042)를 import | V2 #3, v1 #1·#6, SS #9·#13 |
| CM-06-005 | 환경변수 검증(zod)과 `.env.example`(앱·워커) | `apps/nomad-commerce/lib/env.ts`, `services/commerce-worker/src/env.ts`, `.env.example` 2개 | CM-06-004 | P0 | S | Haiku | 02장 8절 필수 키 누락 시 기동 실패 테스트, `CREDENTIALS_KEY` 0키 폴백 없음, AI 필수 키(`AI_TOKEN_PRIVATE_KEY`, `AI_SERVICE_URL`, `DIFY_*` 등) 누락 시 앱 기동 실패, 앱·워커 env에 LLM 제공자 키 0 | CM #13, v1 #12 |
| CM-06-006 | 도메인 상수 패키지: 18슬롯, 유형별 기본 슬롯, 필수 슬롯, 8단계 phase, 마켓 규격, features 파서, 크레딧 단가, 마진 계산, nav | `packages/commerce-domain/`(`schema/` 제외, CM-06-051 소유) | 없음 | P0 | M | Opus | 단위 테스트: 모든 유형 기본값이 T-1·L-3 포함, 10/15장 개수, 쿠팡 6,000px → 3분할, 마진 공식, features 기본값(01장 4.4) | V2 #1·#9, v1 #10, 01장 3.6 |
| CM-06-007 | 인증·세션: 로그인(이메일/Google/Kakao), 콜백 `next` 화이트리스트·origin 고정, `requireSession`, `proxy.ts`, 모의 인증 없음 | `apps/nomad-commerce/app/(auth)/`, `apps/nomad-commerce/proxy.ts`, `apps/nomad-commerce/lib/session/` | CM-06-004 | P0 | M | Fable | `next=//evil.com` → `/dashboard`, 쿠키 위조로 관리자 403, 요청당 `session_context` 1회 | CM #1·#2·#4, SS #5·#7, v1 #1 |
| CM-06-008 | 안전 fetch(허용 도메인, DNS 후 사설 IP 차단, 리다이렉트 3회, 2MB, 10초) | `packages/commerce-net/` | 없음 | P0 | S | Fable | 169.254.169.254, 10.0.0.0/8, IPv6 루프백, DNS 리바인딩 테스트 차단 | CM #3, SS #5, V2 #7 |
| CM-06-009 | 마켓 계정·자격증명: vault 저장, 마스킹 응답, 검증 호출, 슬롯, 연결 해제(`revoke_credential`), 감사 | `apps/nomad-commerce/app/api/market-accounts/`, `apps/nomad-commerce/lib/credentials/` | CM-06-001, CM-06-007 | P0 | M | Fable | 응답·로그·DB 평문 키 0건(테스트로 grep), 슬롯 초과 CM003→403, 다른 조직 자격증명 CM006 | V2 #5, v1 #3, CM #2 |
| CM-06-010 | 생성 요청 API + 크레딧 선차감 + 취소/재시도 + 부분 환불 규약 | `apps/nomad-commerce/app/api/detail-pages/`(copy·acknowledge 제외 경로), `apps/nomad-commerce/lib/generation/` | CM-06-001, CM-06-006, CM-06-007 | P0 | M | Fable | 잔액 부족 402·잡 0건, 같은 request_id 2회 → 원장 1행, waiting 취소 즉시 환불, p95 800ms | V2 #4, SS #1·#2, v1 #2 |
| CM-06-011 | 동기 AI 라우트: 상품명·키워드, 자동완성, URL 벤치마킹, Vision을 서명 토큰으로 FastAPI 그래프 `commerce.assist`에 연결(`withCredits`, zod 출력 검증, 타임아웃 30초). fal whisper STT 경로 폐기 | `apps/nomad-commerce/app/api/ai/{names,autofill,benchmark,vision}/` | CM-06-007, CM-06-008, CM-06-046, CM-06-051 | P0 | M | Opus | 실패 시 환불 행 1개, 플랜 밖 기능 403, 외부 호출 타임아웃 테스트, 요청 바디의 모델·제공자 값 무시, 앱 코드에 LLM·OpenRouter 호출 0건(검색 테스트), 벤치마킹 본문은 `commerce-net`으로만 가져와 텍스트만 전달 | v1 #2, SS #2·#10 |
| CM-06-012 | 워커 런타임: claim 루프, 핸들러 자동 로드, 디스패처(조직별 동시성), 크론(환율, 업로드 폴링, 만료, 소진 알림), 하트비트·취소 | `services/commerce-worker/src/runtime/`, `services/commerce-worker/package.json` | CM-06-001, CM-06-005, CM-06-006 | P0 | M | Opus | Pro 조직 5건 요청 시 generating 최대 2, 워커 재시작 후 잡 재개, 환율 실패 시 이전 값 유지, AI 정산 크론(5분, `/api/internal/ai-settle` 호출)과 위키 lint 주간 등록, 상품 스펙 색인 보정 크론 등록(엔드포인트는 CM-06-046·048 소유, 스텁으로 검증) | V2 #6, CM #9, SS #11, v1 #10 |
| CM-06-013 | 상세페이지 파이프라인(prepare·storyline·copy는 잡 토큰으로 FastAPI 그래프 `commerce.detail_page` 호출, compose, verify, assemble), sanitize, 리뷰형 생성 금지 | `services/commerce-worker/src/detail/` | CM-06-012, CM-06-017, CM-06-051 | P0 | L | Opus | 10슬롯 p95 240초(스테이징), 진행률이 3.6절 표와 일치, 후기·평점 생성 0건, 슬롯 일부 실패 시 부분 환불, 그래프 `failed`·120초 초과 시 `fail_job(retryable)` 후 3회 실패하면 자동 환불, 그래프 출력 zod 재검증, 워커 번들·env에 LLM 키 0, `ai_runs.credit_ledger_id`가 상세페이지 원장과 같음 | V2 #8, 01장 CM-F-022 |
| CM-06-014 | 슬롯 이미지 엔진: fal 제출·웹훅 상관, birefnet, 플랜별 모델, Storage 복사, 재시도 3회 | `services/commerce-worker/src/images/` | CM-06-012 | P0 | M | Opus | 바디의 plan 무시(테스트), 30분 미도착 → 실패·환불, 지원 크기만 전달 | SS #3·#10, CM #9 |
| CM-06-015 | Puppeteer 인포그래픽·법적고지 템플릿, 한글 폰트 Docker 이미지 | `services/commerce-worker/src/render/`, `services/commerce-worker/Dockerfile` | CM-06-006 | P0 | M | Sonnet | D-2/D-5/D-7/D-8/D-9/L-1~3 렌더 스냅샷 테스트, 컨테이너 기동 시 Noto Sans KR 확인, L-1은 health_food_status별 문안만 | V2 #8, 01장 6절 |
| CM-06-016 | 마켓 변환·분할·검증(Sharp) + 단위 테스트 | `services/commerce-worker/src/convert/` | CM-06-006 | P0 | M | Opus | 쿠팡 썸네일 1000x1000 흰배경 5MB 이하, 상세 분할 경계 테스트, 검증 오류 문구 | V2 #9, SS #14 |
| CM-06-017 | 금지어 매처(한글 경계, escape, 치환, 하이라이트 XSS 방지) + compliance 주입 | `packages/commerce-compliance/`(`rules/*.json`, `fixtures/` 포함) | 없음 | P0 | S | Opus | "화장품" 등 한글 매칭 테스트, 특수문자 단어 RegExp 오류 0, `<mark>` 출력 escape, 언어 중립 규칙 파일(`rules/*.json`: 금지 문형, 보장 표현, 자동 삽입 금지)과 공용 테스트 벡터(`fixtures/`)를 제공해 FastAPI 노드(CM-06-051)가 같은 파일을 읽음 | V2 #10, CM #8 |
| CM-06-018 | 아마존 소싱: ASIN 추출, 공급자 어댑터, import.amazon 핸들러 | `packages/commerce-sourcing/amazon/`, `services/commerce-worker/src/import-amazon/` | CM-06-008, CM-06-012 | P0 | M | Opus | URL을 fetch하지 않음(네트워크 목 테스트), 없는 ASIN 환불, 중복 ASIN은 기존 상품 반환 | V2 #7, CM #3 |
| CM-06-019 | 엑셀 파서(오너클랜, 자유 양식 + 매핑), import.excel 핸들러 | `packages/commerce-sourcing/excel/`, `services/commerce-worker/src/import-excel/` | CM-06-012 | P0 | M | Opus | 500행 2분 이내, 행별 오류 기록, 한도 초과 skipped | V2 #7 |
| CM-06-020 | 상품·소싱 Route Handler | `apps/nomad-commerce/app/api/products/`(`[id]/specs/` 제외), `apps/nomad-commerce/app/api/sourcing/` | CM-06-007, CM-06-018, CM-06-019, CM-06-048 | P0 | M | Opus | 요청에서 테이블·컬럼 이름을 받지 않음, CM002→403 매핑, 상품 저장·수정 성공 뒤 `lib/ai/rag-hooks.ts`의 `enqueueProductIndex`(CM-06-048 제공 인터페이스) 호출 | CM #3, 05장 7절 CM #6 |
| CM-06-021 | 쿠팡 Wing 어댑터(서명, 카테고리, 등록, 상태 조회, 오류 정규화) | `packages/commerce-markets/coupang/` | CM-06-006 | P0 | L | Opus | 공식 문서 예제로 서명 테스트, 4xx 필드 오류 → 폼 필드 매핑, 샌드박스(있으면) 등록 1건 | V2 #11 |
| CM-06-022 | 스마트스토어 커머스 API 어댑터 | `packages/commerce-markets/smartstore/` | CM-06-006 | P0 | L | Opus | 토큰 발급·캐시, 등록 1건(테스트 계정), 오류 정규화 | V2 #11 |
| CM-06-023 | 등록 폼·업로드 API, 완성도 서버 계산, upload 핸들러, 상태 폴링 | `apps/nomad-commerce/app/api/listings/`, `apps/nomad-commerce/app/api/uploads/`, `services/commerce-worker/src/upload/` | CM-06-009, CM-06-021, CM-06-022 | P0 | M | Opus | CM004~CM008 → 422/403/409, 같은 request_id 업로드 1건, rejected 사유 저장 | V2 #11, CM #7 |
| CM-06-024 | 엑셀(플레이오토 호환)/ZIP 내보내기 API와 핸들러 | `apps/nomad-commerce/app/api/exports/`, `services/commerce-worker/src/export/` | CM-06-016 | P0 | M | Opus | 쿠팡·스마트스토어 시트 4개씩, ZIP 마켓별 폴더, 서명 URL 7일, free 엑셀 403 | SS #14 |
| CM-06-025 | Toss 결제(구독 빌링키, 크레딧팩, 업·다운그레이드, 해지), 웹훅(Toss, fal) 수신 | `apps/nomad-commerce/app/api/billing/`, `apps/nomad-commerce/app/api/webhooks/`, `apps/nomad-commerce/app/(app)/billing/` | CM-06-007 | P0 | M | Fable | 금액은 DB에서만, customerKey `org_<id>`, 서명 실패 401·중복 200, PM001 시 `fail_payment_order` 호출 + Toss 취소 호출 + 알림 | V2 #12, CM #14, SS #3·#12 |
| CM-06-026 | 결제 E2E(Toss 테스트 키) | `tests/e2e/billing/` | CM-06-025 | P0 | M | Opus | 구독 → 엔타이틀먼트 starter·150크레딧 1회, 크레딧팩 50 지급, 같은 confirm 재호출 멱등, 해지 예약 | DOC_TEMPLATE 2.7 |
| CM-06-027 | 앱 셸·대시보드(KPI 실데이터, 환율, 크레딧, 소진 알림 표시) | `apps/nomad-commerce/app/(app)/layout.tsx`, `apps/nomad-commerce/app/(app)/dashboard/`, `apps/nomad-commerce/components/shell/` | CM-06-007, CM-06-044 | P0 | M | Sonnet | 목 상수 0건, 서버 컴포넌트에서 1회 조회, 375px 레이아웃 | v1 #8, CM #11, SS #8 |
| CM-06-028 | 상품DB·소싱 화면(가상 스크롤 표, 일괄 바, 엑셀 매핑) | `apps/nomad-commerce/app/(app)/products/`, `apps/nomad-commerce/app/(app)/sourcing/`, `apps/nomad-commerce/components/products/` | CM-06-020, CM-06-027 | P0 | L | Sonnet | 2,000행 스크롤, 빈 상태 문구, 키보드 선택 | V2 #13, CM #11, v1 #11 |
| CM-06-029 | 상세페이지 화면(생성 모달 개별/다중, 큐 패널, 뷰어, 인라인 편집, WARN 확인, copy 저장 API) | `apps/nomad-commerce/app/(app)/detail-pages/`, `apps/nomad-commerce/components/detail/`, `apps/nomad-commerce/app/api/detail-pages/[id]/copy/`, `apps/nomad-commerce/app/api/detail-pages/[id]/acknowledge/` | CM-06-010, CM-06-027 | P0 | L | Sonnet | Realtime 진행률 복원, 컴포넌트 300줄 이하 분해, FAIL이면 버튼 비활성, compliance 패널이 issues의 근거 위키 링크·기준일과 "AI가 생성한 콘텐츠"를 표시 | V2 #13, SS #6 |
| CM-06-030 | 등록 폼·업로드 이력·내보내기 화면 | `apps/nomad-commerce/app/(app)/listings/`, `apps/nomad-commerce/app/(app)/uploads/`, `apps/nomad-commerce/app/(app)/exports/`, `apps/nomad-commerce/components/listing/` | CM-06-023, CM-06-024, CM-06-027 | P0 | M | Sonnet | 완성도 바, 필드 오류 이동, 만료 다운로드 재생성 | V2 #11 |
| CM-06-031 | 설정 화면(마켓 계정, 배송·반품 템플릿, 금지어) | `apps/nomad-commerce/app/(app)/settings/`(`ai/` 제외, CM-06-046 소유), `apps/nomad-commerce/components/settings/` | CM-06-009, CM-06-027 | P0 | M | Sonnet | 반품 제한은 4코드 체크박스만, 키 입력 후 마스킹 표시, 기본 금지어 읽기 전용 | CM #12 |
| CM-06-032 | 랜딩·가격 페이지(03장 4절) | `apps/nomad-commerce/app/(marketing)/`, `apps/nomad-commerce/components/marketing/` | CM-06-004, CM-06-044 | P0 | M | Sonnet | 01장 6절 금지 문구 0건(체크리스트), 허위 수치·후기 0건, DESIGN_PRINCIPLES 7단계 12항목, 히어로 자리는 정지 이미지(`public/hero/box-shelf.avif`, CM-06-056 소유)로 먼저 구현하고 3D는 CM-06-056이 장착 | V2 #14, v1 #11 |
| CM-06-033 | 법적 문서(약관, 처리방침, AI 고지)와 법률 검토 의뢰 패키지(반품 4코드, L-1 문안, 구매대행 고지, 고시 책임) | `apps/nomad-commerce/content/legal/`, `apps/nomad-commerce/app/(marketing)/legal/` | CM-06-004 | P0 | S | Sonnet | 검토 전 문안은 "검토 중" 표시, 제3자 제공자 목록 포함, 국외 이전 고지문·음성 처리 고지문과 AI 고지 페이지 문구가 `AI_CROSS_BORDER_NOTICE_VERSION`·`AI_VOICE_NOTICE_VERSION` 상수와 같은 버전 | V2 #14, 01장 6절 |
| CM-06-034 | UI 문구 상수와 오류 코드 → 사용자 문구 매핑 | `apps/nomad-commerce/lib/copy/` | CM-06-006 | P1 | S | Haiku | 04장 7절 코드 전부 매핑, 사과·모호 문구 0건 | DESIGN_PRINCIPLES 카피 규칙 |
| CM-06-035 | 핵심 플로우 E2E(가입 → 아마존 목 → 생성 → WARN 확인 → ZIP → 업로드 목) | `tests/e2e/flows/` | CM-06-011, CM-06-013, CM-06-028, CM-06-029, CM-06-030 | P0 | M | Opus | 03장 2.1~2.5 플로우 통과, 소셜 로그인 콜백 루프 없음 | CM #4, 02장 6절 |
| CM-06-036 | CI(tsc, lint `no-explicit-any`·`no-console`, build, SQL 체커, RLS 스모크) | `.github/workflows/nomad-commerce.yml` | CM-06-003 | P1 | S | Haiku | PR마다 실행, 실패 시 차단. `pytest apps/api`, 라우팅 seed 스냅샷(CM-06-057), `tailwind.config.js`·`bg-[#...]` 금지 검사 포함 | v1 #7, SECURITY_BASELINE 13장 |
| CM-06-037 | 원본 아카이브(4개 → `archive/`), 노출 키 재발급 체크리스트, 시안·zip 정리 | `archive/`, `docs/archive-checklist-commerce.md` | CM-06-035 | P1 | S | Haiku | 07장 5절 체크 항목 전부, 원본 코드가 빌드 경로에 없음 | v1 #4·#5, CM #10 |
| CM-06-038 | Phase 2 상품 쇼츠: video 워커 API 호출, 음원 선택 | `apps/nomad-commerce/lib/integrations/video/`, `apps/nomad-commerce/app/(app)/shorts/` | CM-06-035, CM-06-055 | P2 | M | Opus | 렌더 코드 0줄(호출만), 실패 환불, 내레이션 mp3 경로(CM-06-055)와 상세페이지 이미지 경로를 video 워커 API로 전달 | V2 #15, C-6 |
| CM-06-039 | Phase 2 자동화 노드(automation-core 등록), SNS 업로더 소비, 대량 등록 | `apps/nomad-commerce/lib/automation/` | CM-06-035 | P2 | L | Opus | 엣지 없는 그래프 실행 거부, 노드 단위 크레딧 | V2 #15, v1 #6·#9, CM #5, SS #15 |
| CM-06-040 | Phase 2 Capacitor 원격 셸 | `apps/nomad-commerce-mobile/` | CM-06-035 | P2 | M | Opus | `CAP_SERVER_URL` 환경 분리, cleartext 없음, 스토어 빌드 성공 | SS #4, 확정 결정 9 |
| CM-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Primer, 상태 배지 Atlassian 보조, 채팅 Astryx 패턴 확인, 랜딩 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D-13). 고문(Fable) 검토 기록 | DESIGN_SYSTEM 4장 1단계, 9절 |
| CM-06-042 | 디자인 시스템 2단계: 토큰(`tokens.css` `@theme`, 라이트/다크)과 기본 컴포넌트·배리언트(03장 3.2절), `/dev/components` | `apps/nomad-commerce/styles/tokens.css`, `apps/nomad-commerce/components/ui/`, `apps/nomad-commerce/app/dev/components/` | CM-06-004, CM-06-041 | P0 | M | Sonnet | 컴포넌트 1개 단위 작업 지시(DESIGN_SYSTEM 8장 템플릿)로 기본 세트 전부 구현, hex 직접 사용 0(린트), `tailwind.config.js` 0, 라이트/다크 전환 `data-theme` 하나, 컴팩트/기본 밀도, StatusBadge 전 상태, `/dev/components`는 프로덕션 빌드에서 제외 | DESIGN_SYSTEM 4장 2단계, 6장 |
| CM-06-043 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | CM-06-042 | P0 | M | 사람(보조 Sonnet) | 03장 3.2절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인, 다크 토큰 값 확정. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| CM-06-044 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | CM-06-043 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0. 화면 작업(027, 032, 050, 053, 056)의 진입 조건 | DESIGN_SYSTEM 4장 4단계 |
| CM-06-045 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, commerce 설정(app, `COMMERCE_KNOWLEDGE_ORG_ID`, 컬렉션 이름), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/commerce/`, `app/ai/compliance/commerce.py`, `app/ai/products/commerce/` 제외), `apps/api/tests/platform/` | CM-06-001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org의 상품 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 필수 변수 누락 시 기동 실패 | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| CM-06-046 | AI 게이트: 대화 생성·바인딩 검증, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰·잡 토큰 발급, 정산 엔드포인트, AI 단가, 온보딩·설정의 국외 이전 동의, 음성 처리 고지 기록 | `apps/nomad-commerce/app/api/ai/{conversations,chat}/`, `apps/nomad-commerce/app/api/internal/`, `apps/nomad-commerce/app/api/onboarding/`, `apps/nomad-commerce/app/onboarding/`, `apps/nomad-commerce/app/(app)/settings/ai/`, `apps/nomad-commerce/lib/ai/`(`rag-hooks.ts` 제외) | CM-06-007, CM-06-045 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 잡 토큰은 running `detail.generate` 잡에만(다른 상태·타입 409), 동의 시 `ai_org_settings` 고지문 버전과 감사 `ai.cross_border.ack` 일치, 정산 호출 뒤 10분 넘은 `settled_at is null` 0, 하루 턴 상한 429 | 01장 CM-F-045, 049, 050 |
| CM-06-047 | 마켓 규칙 원고(쿠팡·스마트스토어: 상품명 규칙, 이미지 규격, 고시 유형, 대표 반려 사유, 금지어·표시광고 지침, 건기식 규칙) | `content/knowledge/` | CM-06-006, CM-06-017 | P0 | L | Sonnet | 항목마다 마켓·기준일·출처·작성자·검수일 메타데이터(출처를 확인 못 한 항목은 "출처 확인 필요"), 금지 문구 규칙 검사 0, `commerce-domain` 마켓 규격 상수와 다른 항목은 0건이거나 명시, 운영자 검수 기록(01장 D-9) | 01장 CM-F-041 |
| CM-06-048 | RAG 색인: 운영자 조직 컬렉션 `commerce-rules`·`commerce-wiki`(oss-embed), 셀러 조직 `commerce-products`(상품·스펙 시트) 색인 훅·보정 크론·purge 연동, 색인 스크립트, `/dify/retrieval` 설정, 검색 평가셋(규칙 40문항·상품 30문항) | `apps/api/app/ai/products/commerce/knowledge.py`, `scripts/knowledge/`, `apps/api/tests/commerce/retrieval/`, `apps/nomad-commerce/app/api/products/[id]/specs/`, `apps/nomad-commerce/lib/ai/rag-hooks.ts` | CM-06-045, CM-06-047 | P0 | M | Opus | 재현율@8 0.8 이상(제안), 다른 조직 컬렉션 요청 42501, 외부 지식 응답에 셀러 조직 데이터 0, 컬렉션당 임베딩 모델 1종, 상품 삭제 purge 뒤 문서·청크 0, 색인 실패가 상품 저장을 막지 않음, 스펙 업로드 월 20건 한도(D-11) | 01장 CM-F-040, 041 |
| CM-06-049 | 마켓 규칙 위키 운영: 규칙 원고 → 위키 ingest(draft), 게시·편집·이력·lint 관리자 화면과 API, 주 1회 lint 잡 | `apps/api/app/ai/products/commerce/wiki_config.py`, `apps/nomad-commerce/app/admin/wiki/`, `apps/nomad-commerce/app/admin/knowledge/`, `apps/nomad-commerce/app/api/admin/wiki/`, `apps/nomad-commerce/app/api/admin/knowledge/` | CM-06-044, CM-06-048 | P0 | M | Opus | 새 페이지 draft, 출처·기준일 없는 페이지 게시 409, 사람 소유 표시(`<!-- owner:user -->`) 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, lint 결과 화면 표시, 모든 쓰기 감사 1행 | 01장 CM-F-042, LLM_WIKI 3장 |
| CM-06-050 | 공개 위키 화면(마켓 탭, 목록·검색, 페이지, 출처·기준일·관련) | `apps/nomad-commerce/app/(marketing)/wiki/` | CM-06-044, CM-06-049 | P0 | M | Sonnet | `published`만 노출(draft 0), "AI가 정리하고 운영자가 검수한 문서"·기준일·정책 변경 안내 표시, 기준일 6개월 초과 경고, Lighthouse 접근성 95, 01장 6절 금지 문구 0, 공개 범위는 01장 D-9 결정을 따름 | 01장 CM-F-042 |
| CM-06-051 | LangGraph 그래프 `commerce.detail_page`(6노드)와 `commerce.assist`(4노드), 체크포인트, 실행 기록, 출력 스키마(JSON 스키마 1개에서 pydantic·zod 생성), compliance 규칙 파일 연동 | `apps/api/app/ai/graphs/commerce_detail_page.py`, `apps/api/app/ai/graphs/commerce_assist.py`, `apps/api/app/ai/compliance/commerce.py`, `apps/api/app/ai/graphs/prompts/commerce/`, `packages/commerce-domain/schema/`, `apps/api/tests/commerce/graph/` | CM-06-006, CM-06-017, CM-06-045, CM-06-048 | P0 | L | Opus | 생성 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 상품 행에 없는 수치 0, 후기·평점 문형 0, 걸린 슬롯만 1회 재작성하고 그래도 FAIL이면 verdict fail, 공용 금지어 테스트 벡터를 pytest와 vitest가 모두 통과, 평가셋 20건을 상용·오픈소스 경로 모두 통과, `compliance_only` 모드, 규칙 검색 실패 시 verdict 최소 warn | 01장 CM-F-043, 044, 051 |
| CM-06-052 | Dify `commerce-chat`(질문 분류, HTTP 노드, 외부 지식)와 `/tools/answer` commerce 확장(모드 rules·product, 바인딩 대조, 마스킹, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/commerce/`, `apps/api/tests/commerce/chat/` | CM-06-046, CM-06-048 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `product_id` 바인딩 403, 답변 출처 1개 이상 또는 `no_source`, 평가셋에서 승인·반려 보장·법률 단정 문형 0, 마켓 키 형식 입력 마스킹, DSL에 키 0 | 01장 CM-F-045, 051, 04장 6.2절 |
| CM-06-053 | 채팅 패널과 대화 목록(스트리밍, 출처 칩, 규칙 기준일, 크레딧 안내, AI 생성 표시, 대상 바인딩) | `apps/nomad-commerce/components/ai-chat/`, `apps/nomad-commerce/app/(app)/chat/` | CM-06-044, CM-06-046 | P0 | M | Sonnet | 03장 3.1절 구성, 375px 전체 화면 시트, `aria-live`, 402 충전 모달, 대체·근거 없음·환불 상태 표시. 앱 셸 장착은 CM-06-027 파일에 1줄 요청 | 01장 CM-F-045 |
| CM-06-054 | 음성 대화와 상품 설명 음성 입력: `/api/voice/*`(consent, sessions, stt, tts)와 `/api/ai/voice-structure`, 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기, 상품 폼·생성 모달 장착 요청 | `apps/nomad-commerce/app/api/voice/`(`narrations/` 제외), `apps/nomad-commerce/app/api/ai/voice-structure/`, `apps/nomad-commerce/components/voice/` | CM-06-046, CM-06-053 | P0 | M | Opus | 고지 미확인 STT 403, 채팅 60초·상품 입력 120초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 입력 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지만, 구조화 결과가 zod를 통과한 필드만 채움, `voice_input` 플랜 밖 403, 구조화는 STT 작업당 3회 | 01장 CM-F-046, 047 |
| CM-06-055 | 쇼츠 내레이션: 스크립트 생성 API(`commerce.assist` 작업 `shorts_script`), `/api/voice/narrations`(선차감, 시작 제공자 고정·대체 금지, Storage 저장·재사용 해시, 정산), 내레이션 패널·플레이어, `/narrations` | `apps/nomad-commerce/app/api/ai/shorts-script/`, `apps/nomad-commerce/app/api/voice/narrations/`, `apps/nomad-commerce/components/narration/`, `apps/nomad-commerce/app/(app)/narrations/` | CM-06-029, CM-06-046, CM-06-051, CM-06-054 | P0 | M | Opus | 한 내레이션의 `ai_usage` 제공자 1종·`fallback_from` null, 중간 실패 강제 테스트에서 파일 0 + 환불 1행, 같은 스크립트·보이스 재요청 차감 0, 미동의 조직은 처음부터 oss-voice, 600자 초과·금지어 FAIL 422, 상품 삭제 purge에 내레이션 파일 포함, 영상 렌더 코드 0줄 | 01장 CM-F-048 |
| CM-06-056 | 3D 히어로: 상품 상자 → 패널 펼침 → 진열대(PC·태블릿), 상자 열림만(모바일), 정지 이미지 대체, 성능 예산 | `apps/nomad-commerce/components/hero3d/`, `apps/nomad-commerce/public/hero/` | CM-06-044 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 보라/핑크 그라디언트·별 파티클·지구본·네온 그리드 0, 마켓 로고 0 | 01장 CM-F-052, 03장 4.5절 |
| CM-06-057 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 바인딩 위조, 국외 동의 필터, 강제 오픈소스, 선차감·정산·환불, 라우팅 seed 스냅샷, LLM 키 위치 검사) | `apps/api/tests/commerce/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | CM-06-046, CM-06-051, CM-06-052, CM-06-054 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 14행 × 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 다른 조직 상품 바인딩 403, 미동의 조직 상용 호출 0, 앱·워커 번들과 env에 LLM 키 0, 원장 drift 0, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 006, 008, 017, 041 | 6 | 없음 | DB 적용·타입(AI 기본값 포함), 앱 골격, 도메인 상수, 안전 fetch, 금지어 매처·규칙 파일, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 005, 007, 015, 016, 021, 022, 045 | 9 | W0 | 모놀리스 스크립트, RLS 테스트, env, 인증, 렌더 템플릿, 변환, 마켓 어댑터 2개, AI 서비스 설치 |
| W1-D | 042 → 043 → 044(직렬) | 1 | 004, 041 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 009, 010, 012, 025, 027, 032, 033, 046, 047 | 9 | W1(007, 005, 045), 화면(027, 032)은 044 | 계정, 생성 API, 워커 런타임, 결제, 셸, 랜딩, 법적 문서, AI 게이트, 마켓 규칙 원고 |
| W3 | 014, 018, 019, 023, 024, 034, 036, 048, 056 | 9 | W2(012, 009, 047) | 이미지, 소싱, 업로드, 내보내기, 문구, CI, RAG 색인, 3D 히어로 |
| W4 | 020, 026, 028, 029, 030, 031, 049, 051, 052, 053 | 10 | W3(048) | 소싱 API, 결제 E2E, 화면 4종, 위키 운영, 생성·보조 그래프, Dify 채팅, 채팅 패널 |
| W5 | 011, 013, 050, 054 | 4 | W4(046, 051, 049, 053) | 보조 AI 라우트, 상세페이지 파이프라인(그래프 연결), 공개 위키, 음성 대화·상품 음성 입력 |
| W6 | 035, 055, 057 | 3 | W5 | 플로우 E2E, 쇼츠 내레이션, AI 보안 회귀. MVP 출시 조건 |
| W7 | 037 | 1 | W6 | 아카이브 → 베타 |
| W8(Phase 2) | 038, 039, 040 | 3 | 베타 출시 | 쇼츠 영상 연동, 자동화, 모바일 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 10 | 17.9% | 20 / 112 = 17.9% |
| Opus | 26 | 46.4% | 55 / 112 = 49.1% |
| Sonnet | 15 | 26.8% | 32 / 112 = 28.6% |
| Haiku | 5 | 8.9% | 5 / 112 = 4.5% |
| 합계 | 56 | 100% | 112 |

비율은 모델 작업 56개 기준이다. 사람 작업 1개(CM-06-043, M)는 비율에서 뺐다(전체 57개). 2026-10-13 이전(40개)은 Fable 17.5%, Opus 47.5%, Sonnet 22.5%, Haiku 12.5%였다. Fable은 데이터 모델, RLS, 결제, 크레딧 차감 경로, 개인정보 삭제에 더해 AI 보안 경계(서명 토큰 검증 045, AI 게이트의 선차감·정산·동의 046, AI 회귀 057)를 맡는다. 그래프·RAG·Dify·음성 구현은 Opus, 채팅 패널·공개 위키·3D 히어로·규칙 원고·디자인 시스템 구현은 Sonnet이다(`docs/products/_platform-core/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

### 5.1 `docs/reviews/Nomad-AI-Factory_V.2.md` 5장(15)

| 리뷰 작업 | 내용 요약 | 흡수 작업 |
|---|---|---|
| #1 | 문서 충돌 결정표 | 01장 3.5·3.6, 4장(이 기획에서 결정) + CM-06-006 |
| #2 | 멀티테넌트 데이터 모델·RLS | CM-06-001, CM-06-003 |
| #3 | 프로젝트 골격 | CM-06-004 |
| #4 | 사용량 서버 집행 | CM-06-010, CM-06-001(트리거) |
| #5 | 자격증명 암호화 | CM-06-009 |
| #6 | 생성 실행 기반 | CM-06-012 |
| #7 | 소싱 | CM-06-018, CM-06-019, CM-06-008 |
| #8 | 상세페이지 파이프라인 | CM-06-013, CM-06-014, CM-06-015 |
| #9 | 마켓 이미지 변환 | CM-06-016 |
| #10 | 금지어 필터 | CM-06-017 |
| #11 | 쿠팡·스마트스토어 배포 | CM-06-021, CM-06-022, CM-06-023, CM-06-030 |
| #12 | Toss 정기결제 | CM-06-025 |
| #13 | 핵심 화면 | CM-06-028, CM-06-029 |
| #14 | 컴플라이언스 문구 | CM-06-032, CM-06-033 |
| #15 | Phase 2 확장 | CM-06-038, CM-06-039 |

### 5.2 `docs/reviews/nomad-ai-factory.md` 5장(13)

| 리뷰 작업 | 내용 요약 | 흡수 작업 |
|---|---|---|
| #1 | Next 골격·초기 마이그레이션 | CM-06-004, CM-06-001 |
| #2 | AI 호출 경계 | CM-06-011, CM-06-010 |
| #3 | 사용자 키 서버 암호화 | CM-06-009 |
| #4 | v1 유지 시 JWT 검증 | 해당 없음: v1은 운영하지 않고 아카이브(CM-06-037) |
| #5 | v1 저장소 정리 | CM-06-037 |
| #6 | 버전 고정·@xyflow v12 | CM-06-004, CM-06-039 |
| #7 | `as any`·console.log | CM-06-036(린트 규칙) |
| #8 | 대시보드 목 데이터 | CM-06-027 |
| #9 | 자동화 엔진 | CM-06-039(core automation-core 소비) |
| #10 | 환율 API·마진 | CM-06-012, CM-06-006 |
| #11 | 대형 페이지 분해 | CM-06-032, CM-06-028 |
| #12 | CLAUDE.md·env 예시 | 이 폴더 `CLAUDE.md`, CM-06-005 |
| #13 | 주문 CRUD | 범위 밖: 판매관리 Phase 3(01장 2절) |

### 5.3 `docs/reviews/nomad-ai-commerce.md` 5장(14)

| 리뷰 작업 | 내용 요약 | 흡수 작업 |
|---|---|---|
| #1 | 모의 인증 제거·미들웨어 | CM-06-007 |
| #2 | API 인증 가드·market-accounts | CM-06-007, CM-06-009 |
| #3 | tableName 주입·SSRF | CM-06-008, CM-06-020, CM-06-018 |
| #4 | 소셜 로그인 연결 | CM-06-007, CM-06-035 |
| #5 | 워크플로우 엔진 | CM-06-039 |
| #6 | 스키마 보강·타입 | CM-06-001 |
| #7 | 업로드 잡 DB 전환 | CM-06-023 |
| #8 | 금지어 정규식 | CM-06-017 |
| #9 | 환율·썸네일 size | CM-06-012, CM-06-014 |
| #10 | 죽은 코드 | CM-06-037(CM 코드는 이식하지 않음) |
| #11 | 서버 컴포넌트·실데이터 | CM-06-027, CM-06-028 |
| #12 | 어드민 설정 영속화 | CM-06-031 |
| #13 | env·문서 | CM-06-005 |
| #14 | 결제 | CM-06-025 |

### 5.4 `docs/reviews/sellingstudio.md` 5장(15)

| 리뷰 작업 | 내용 요약 | 흡수 작업 |
|---|---|---|
| #1 | 원자 차감 RPC | core `consume_credits` + CM-06-010 |
| #2 | 생성 라우트 차감·서버 insert | CM-06-010, CM-06-011 |
| #3 | USING(true) 삭제·fal 서명·final_url | CM-06-001, CM-06-025, CM-06-014 |
| #4 | Capacitor 배포 전략 | CM-06-040 |
| #5 | crawl SSRF·callback next | CM-06-008, CM-06-007 |
| #6 | StudioNewForm 분해 | CM-06-029 |
| #7 | 서버 조회 통합 | CM-06-007 |
| #8 | 대시보드 실데이터 | CM-06-027 |
| #9 | 미사용 의존성·죽은 코드 | CM-06-004, CM-06-037 |
| #10 | 타임아웃·재시도 | CM-06-011, CM-06-014 |
| #11 | 월 초기화·소진 알림 | core `run_monthly_credit_grants` + CM-06-012 |
| #12 | 추가 크레딧 결제 | CM-06-025(Stripe 대신 Toss) |
| #13 | CSP·문서·이메일 시드 | CM-06-004, CM-06-037 |
| #14 | Sharp 리사이즈·엑셀/ZIP | CM-06-016, CM-06-024 |
| #15 | 자동화 엔진 | CM-06-039 |

합계 57행 = 리뷰 5장 작업 57개.

## 6. 공용 모듈 요청

| 대상 | 요청 | 이유 |
|---|---|---|
| `_supabase-modular/seed.sql` | commerce 플랜 features를 01장 4.1/4.4로 갱신(free·starter의 `market_api`, market_slots 1/3/10/-1, slot_sets, concurrency, image_quality 등), commerce 크레딧팩 3행 추가 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치. 이전에는 free 업로드가 CM007로 막혔다 |
| `core.plans` | 이월 비율(예: `carry_over_pct`) 지원 검토 | SS 이월 50/100%(01장 8절 결정 2) |
| core credits | `adjust_credits`(음수 조정) | 크레딧팩 환불(`CORE_SPEC.md` 5.4) |
| core `confirm_payment_order` | 금액 불일치 시 failed 저장(현재 raise가 롤백) | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 별도 호출 |
| core jobs | 조직별 동시성 claim 옵션 | 지금은 commerce 디스패처로 우회(02장 4절) |
| compliance 모듈 | 제품 사전 주입 인터페이스(`checkRules(input, dict)`) 확정 | commerce `banned_words` 사용 |
| llm gateway | purpose `storyline`, `notice_autofill`, `category_suggest` 등록 | 대체됨(2026-10-13): 라우터 본체가 ai-service로 옮겨졌고 기능 키는 02장 5.1절 14행이 정한다. 요청 철회 |

### 6.1 AI 계층 코어 요청 (2026-10-13)

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 |
|---|---|---|---|---|
| R-1 | `_supabase-modular/seed.sql` | commerce 4개 플랜 `features`에 `ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `shorts_narration` 추가(01장 4.4절 값) | seed가 1400보다 나중에 실행되면 조각 20.2절 병합 UPDATE가 덮어써진다 | 서버가 누락 키를 기본값으로 읽는다(01장 4.4절) |
| R-2 | ai-service | (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) (c) 제품 확장 규약: 그래프를 `POST /graphs/{name}/runs`로 등록하는 레지스트리, `/tools/answer` 모드 확장점 | Dify 보조 노드 라우팅(`dify.aux`, `wiki.query`)과 관리자 위키 편집, commerce 그래프 2개 | (a) Dify에 기능별 모델 이름을 따로 등록 (b) `app/ai/products/commerce/wiki_config.py`에 임시 구현 |
| R-3 | `_platform-core` AI_ARCHITECTURE, ai-gateway | TS 워커가 그래프를 실행할 때 쓰는 잡 토큰 발급 규칙(Next.js `/api/internal/ai-token`, 워커 키 + running 잡 확인, org·sub는 잡 행에서)을 공용 규칙과 `packages/ai-gateway`에 추가 | 개인키는 Next.js에만 둔다는 규칙과 워커 기반 생성이 함께 필요. TS 워커를 쓰는 다른 제품(astro, publishing, video, blog)도 같은 문제 | commerce 제품 엔드포인트로 구현(04장 2.1절, 01장 D-14) |
| R-4 | core-voice | 기능별 대체 금지 옵션(`feature='shorts_narration'`)과 "시작 제공자 고정" 동작을 `VoiceAdapter` 계약에 명시 | `VOICE_ARCHITECTURE.md` 3장 대체 금지를 코드 계약으로 강제 | 내레이션 Route Handler가 체인 첫 제공자 하나만 넘겨 호출 |
| R-5 | 공용 Dify | `commerce-chat` 앱 생성, 내부 키 환경 변수, 외부 지식 `commerce-rules` 등록, 로그 보존 30일 | 공용 인프라는 코어 소유 | 없음(필수). 장애 시 `/tools/answer-direct` |
| R-6 | `_design-guide` 3D 키트 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/products/_design-guide/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| R-7 | compliance 모듈 | 언어 중립 규칙 파일과 공용 테스트 벡터를 제품이 주입하는 규약(`checkRules(input, dict)`의 JSON 규칙 버전)을 확정 | TS 매처(commerce-compliance)와 FastAPI compliance 노드가 같은 판정을 하도록 | commerce가 `packages/commerce-compliance/rules/`와 `fixtures/`로 자체 규약을 둔다(CM-06-017, 051) |
| R-8 | nomad-video | 쇼츠 렌더 워커 API 계약(입력: 음성 파일 경로, 이미지 경로, 분량; 출력: 영상 경로; 인증: 서비스 토큰)을 확정 | Phase 2 쇼츠 연동(CM-06-038). 렌더 엔진은 nomad-video 소유 | 내레이션 mp3까지만 MVP로 제공(01장 D-12) |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `pnpm -F nomad-commerce build`, `tsc --noEmit`, `eslint` 0 오류, 워커 동일 |
| SQL | `_tools-sqlcheck` mod·mono OK |
| RLS 스모크 | CM-06-003 전 항목 통과 |
| 결제 E2E | CM-06-026 통과(Toss 테스트 키) |
| 플로우 E2E | CM-06-035 통과 |
| 06장 작업 | W0~W7 작업 전부 완료(P0·P1), W8(P2)은 Phase 2 |
| 법률 검토 | 01장 6절 5개 문안(AI 고지문 포함) 검토 완료 전 유료 출시 금지 |
| AI·음성 | `pytest apps/api` 통과, CM-06-057 녹색, 그래프 평가셋 20건을 상용·오픈소스 경로 모두 통과, 채팅 평가셋 30문항 금지 문형 0, 내레이션 대체 금지 테스트 통과, 앱·워커에 LLM 키 0 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(CM-06-044) 완료, `tailwind.config.js`·hex 하드코딩 0 |

P0 작업과 검증 작업 대응: DB·권한(001, 007, 008, 009) → 003 / 결제(025) → 026 / 생성·소싱·업로드·내보내기·화면(006, 010~024, 027~031) → 각 작업 단위 테스트 + 035 / 랜딩·법적(032, 033) → 032 체크리스트 + 법률 검토 / AI·음성(045~055) → 각 작업 평가셋·단위 테스트 + 057.
