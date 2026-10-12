# 06 에이전트 작업 계획: NOMAD Commerce

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 작업마다 디렉토리(또는 파일)를 하나 이상 소유하고, 다른 작업의 소유 경로를 수정하지 않는다. 필요한 변경은 소유 작업에 요청 |
| 공유 등록 지점 없음 | 워커 핸들러는 `services/commerce-worker/src/<영역>/handler.ts` 규약으로 런타임이 자동 로드한다(CM-06-012). 화면 메뉴는 `packages/commerce-domain/nav.ts` 상수(CM-06-006)를 읽는다. 공용 인덱스 파일을 여러 작업이 고치지 않는다 |
| 패키지 경계 | 앱과 워커는 `packages/commerce-*`만 공유(02장 2절). `_platform-core` 패키지는 소비만 |
| 코어 불변 | `core.*`, `_platform-core/`, `_supabase-modular/`의 다른 파일을 고치지 않는다. 필요하면 6절 요청 |
| 테스트 동반 | P0 작업은 수용 기준에 자체 테스트를 포함하고, 교차 검증은 CM-06-003(RLS), CM-06-026(결제), CM-06-035(플로우)가 맡는다 |
| 모델 | Fable: 결제, 권한, RLS, 데이터 모델 / Opus: 기능, API 연동, 테스트 설계 / Sonnet: UI, 랜딩, 컴포넌트, 문서 / Haiku: 보일러플레이트, 린트, 문구, 반복 점검 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| CM-06-001 | DB 조각 적용, `config.toml` 스키마 노출, 타입 생성 | `supabase/migrations/1400_commerce.sql`(제품 저장소 복사본), `apps/nomad-commerce/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, 체커 OK, `--schema core,commerce` 타입 생성. 스키마 변경 시 05장 동기화 | V2 #2, v1 #1·#4, CM #6, 05장 |
| CM-06-002 | 모놀리스 변환 스크립트(HEADER 제거, 접두사·schemaname 치환) | `scripts/db/commerce-monolith.sh` | CM-06-001 | P1 | S | Haiku | 조각 → `0002_commerce_domain.sql` 재생성 결과가 저장본과 diff 0, mono 체커 OK | DB_CONVENTIONS 12장 |
| CM-06-003 | RLS/권한 회귀 테스트(PGlite + 로컬 Supabase) | `tests/rls/` | CM-06-001 | P0 | M | Fable | 05장 9절 항목 60개 + SECURITY_BASELINE 15장 전부 통과. CI에서 실패 시 머지 차단 | SECURITY_BASELINE 15장, V2 #2·#4 |
| CM-06-004 | 앱 골격 이식(sellingstudio → 모노레포): 라우트 그룹, core-db 클라이언트, 의존성 고정, 미사용 의존성 제거, CSP 강화 | `apps/nomad-commerce/{package.json,next.config.ts,app/layout.tsx,app/globals.css}` | 없음 | P0 | M | Sonnet | `pnpm build` 통과, `unsafe-eval`·사설 IP 없음, `latest` 0건, Stripe·미사용 14개 제거 | V2 #3, v1 #1·#6, SS #9·#13 |
| CM-06-005 | 환경변수 검증(zod)과 `.env.example`(앱·워커) | `apps/nomad-commerce/lib/env.ts`, `services/commerce-worker/src/env.ts`, `.env.example` 2개 | CM-06-004 | P0 | S | Haiku | 02장 8절 필수 키 누락 시 기동 실패 테스트, `CREDENTIALS_KEY` 0키 폴백 없음 | CM #13, v1 #12 |
| CM-06-006 | 도메인 상수 패키지: 18슬롯, 유형별 기본 슬롯, 필수 슬롯, 8단계 phase, 마켓 규격, features 파서, 크레딧 단가, 마진 계산, nav | `packages/commerce-domain/` | 없음 | P0 | M | Opus | 단위 테스트: 모든 유형 기본값이 T-1·L-3 포함, 10/15장 개수, 쿠팡 6,000px → 3분할, 마진 공식, features 기본값(01장 4.4) | V2 #1·#9, v1 #10, 01장 3.6 |
| CM-06-007 | 인증·세션: 로그인(이메일/Google/Kakao), 콜백 `next` 화이트리스트·origin 고정, `requireSession`, `proxy.ts`, 모의 인증 없음 | `apps/nomad-commerce/app/(auth)/`, `apps/nomad-commerce/proxy.ts`, `apps/nomad-commerce/lib/session/` | CM-06-004 | P0 | M | Fable | `next=//evil.com` → `/dashboard`, 쿠키 위조로 관리자 403, 요청당 `session_context` 1회 | CM #1·#2·#4, SS #5·#7, v1 #1 |
| CM-06-008 | 안전 fetch(허용 도메인, DNS 후 사설 IP 차단, 리다이렉트 3회, 2MB, 10초) | `packages/commerce-net/` | 없음 | P0 | S | Fable | 169.254.169.254, 10.0.0.0/8, IPv6 루프백, DNS 리바인딩 테스트 차단 | CM #3, SS #5, V2 #7 |
| CM-06-009 | 마켓 계정·자격증명: vault 저장, 마스킹 응답, 검증 호출, 슬롯, 연결 해제(`revoke_credential`), 감사 | `apps/nomad-commerce/app/api/market-accounts/`, `apps/nomad-commerce/lib/credentials/` | CM-06-001, CM-06-007 | P0 | M | Fable | 응답·로그·DB 평문 키 0건(테스트로 grep), 슬롯 초과 CM003→403, 다른 조직 자격증명 CM006 | V2 #5, v1 #3, CM #2 |
| CM-06-010 | 생성 요청 API + 크레딧 선차감 + 취소/재시도 + 부분 환불 규약 | `apps/nomad-commerce/app/api/detail-pages/`(copy·acknowledge 제외 경로), `apps/nomad-commerce/lib/generation/` | CM-06-001, CM-06-006, CM-06-007 | P0 | M | Fable | 잔액 부족 402·잡 0건, 같은 request_id 2회 → 원장 1행, waiting 취소 즉시 환불, p95 800ms | V2 #4, SS #1·#2, v1 #2 |
| CM-06-011 | 동기 AI 라우트: 상품명·키워드, 자동완성, 음성, URL 벤치마킹, Vision(`withCredits`, zod 출력 검증, 타임아웃) | `apps/nomad-commerce/app/api/ai/` | CM-06-007, CM-06-008 | P0 | M | Opus | 실패 시 환불 행 1개, 플랜 밖 기능 403, 외부 호출 타임아웃 테스트 | v1 #2, SS #2·#10 |
| CM-06-012 | 워커 런타임: claim 루프, 핸들러 자동 로드, 디스패처(조직별 동시성), 크론(환율, 업로드 폴링, 만료, 소진 알림), 하트비트·취소 | `services/commerce-worker/src/runtime/`, `services/commerce-worker/package.json` | CM-06-001, CM-06-005, CM-06-006 | P0 | M | Opus | Pro 조직 5건 요청 시 generating 최대 2, 워커 재시작 후 잡 재개, 환율 실패 시 이전 값 유지 | V2 #6, CM #9, SS #11, v1 #10 |
| CM-06-013 | 상세페이지 파이프라인(prepare, storyline, copy, compose, verify, assemble), sanitize, 리뷰형 생성 금지 | `services/commerce-worker/src/detail/` | CM-06-012, CM-06-017 | P0 | L | Opus | 10슬롯 p95 240초(스테이징), 진행률이 3.6절 표와 일치, 후기·평점 생성 0건, 슬롯 일부 실패 시 부분 환불 | V2 #8, 01장 CM-F-022 |
| CM-06-014 | 슬롯 이미지 엔진: fal 제출·웹훅 상관, birefnet, 플랜별 모델, Storage 복사, 재시도 3회 | `services/commerce-worker/src/images/` | CM-06-012 | P0 | M | Opus | 바디의 plan 무시(테스트), 30분 미도착 → 실패·환불, 지원 크기만 전달 | SS #3·#10, CM #9 |
| CM-06-015 | Puppeteer 인포그래픽·법적고지 템플릿, 한글 폰트 Docker 이미지 | `services/commerce-worker/src/render/`, `services/commerce-worker/Dockerfile` | CM-06-006 | P0 | M | Sonnet | D-2/D-5/D-7/D-8/D-9/L-1~3 렌더 스냅샷 테스트, 컨테이너 기동 시 Noto Sans KR 확인, L-1은 health_food_status별 문안만 | V2 #8, 01장 6절 |
| CM-06-016 | 마켓 변환·분할·검증(Sharp) + 단위 테스트 | `services/commerce-worker/src/convert/` | CM-06-006 | P0 | M | Opus | 쿠팡 썸네일 1000x1000 흰배경 5MB 이하, 상세 분할 경계 테스트, 검증 오류 문구 | V2 #9, SS #14 |
| CM-06-017 | 금지어 매처(한글 경계, escape, 치환, 하이라이트 XSS 방지) + compliance 주입 | `packages/commerce-compliance/` | 없음 | P0 | S | Opus | "화장품" 등 한글 매칭 테스트, 특수문자 단어 RegExp 오류 0, `<mark>` 출력 escape | V2 #10, CM #8 |
| CM-06-018 | 아마존 소싱: ASIN 추출, 공급자 어댑터, import.amazon 핸들러 | `packages/commerce-sourcing/amazon/`, `services/commerce-worker/src/import-amazon/` | CM-06-008, CM-06-012 | P0 | M | Opus | URL을 fetch하지 않음(네트워크 목 테스트), 없는 ASIN 환불, 중복 ASIN은 기존 상품 반환 | V2 #7, CM #3 |
| CM-06-019 | 엑셀 파서(오너클랜, 자유 양식 + 매핑), import.excel 핸들러 | `packages/commerce-sourcing/excel/`, `services/commerce-worker/src/import-excel/` | CM-06-012 | P0 | M | Opus | 500행 2분 이내, 행별 오류 기록, 한도 초과 skipped | V2 #7 |
| CM-06-020 | 상품·소싱 Route Handler | `apps/nomad-commerce/app/api/products/`, `apps/nomad-commerce/app/api/sourcing/` | CM-06-007, CM-06-018, CM-06-019 | P0 | M | Opus | 요청에서 테이블·컬럼 이름을 받지 않음, CM002→403 매핑 | CM #3, 05장 7절 CM #6 |
| CM-06-021 | 쿠팡 Wing 어댑터(서명, 카테고리, 등록, 상태 조회, 오류 정규화) | `packages/commerce-markets/coupang/` | CM-06-006 | P0 | L | Opus | 공식 문서 예제로 서명 테스트, 4xx 필드 오류 → 폼 필드 매핑, 샌드박스(있으면) 등록 1건 | V2 #11 |
| CM-06-022 | 스마트스토어 커머스 API 어댑터 | `packages/commerce-markets/smartstore/` | CM-06-006 | P0 | L | Opus | 토큰 발급·캐시, 등록 1건(테스트 계정), 오류 정규화 | V2 #11 |
| CM-06-023 | 등록 폼·업로드 API, 완성도 서버 계산, upload 핸들러, 상태 폴링 | `apps/nomad-commerce/app/api/listings/`, `apps/nomad-commerce/app/api/uploads/`, `services/commerce-worker/src/upload/` | CM-06-009, CM-06-021, CM-06-022 | P0 | M | Opus | CM004~CM008 → 422/403/409, 같은 request_id 업로드 1건, rejected 사유 저장 | V2 #11, CM #7 |
| CM-06-024 | 엑셀(플레이오토 호환)/ZIP 내보내기 API와 핸들러 | `apps/nomad-commerce/app/api/exports/`, `services/commerce-worker/src/export/` | CM-06-016 | P0 | M | Opus | 쿠팡·스마트스토어 시트 4개씩, ZIP 마켓별 폴더, 서명 URL 7일, free 엑셀 403 | SS #14 |
| CM-06-025 | Toss 결제(구독 빌링키, 크레딧팩, 업·다운그레이드, 해지), 웹훅(Toss, fal) 수신 | `apps/nomad-commerce/app/api/billing/`, `apps/nomad-commerce/app/api/webhooks/`, `apps/nomad-commerce/app/(app)/billing/` | CM-06-007 | P0 | M | Fable | 금액은 DB에서만, customerKey `org_<id>`, 서명 실패 401·중복 200, PM001 시 Toss 취소 호출 + 알림(코어 결함 의존 안 함) | V2 #12, CM #14, SS #3·#12 |
| CM-06-026 | 결제 E2E(Toss 테스트 키) | `tests/e2e/billing/` | CM-06-025 | P0 | M | Opus | 구독 → 엔타이틀먼트 starter·150크레딧 1회, 크레딧팩 50 지급, 같은 confirm 재호출 멱등, 해지 예약 | DOC_TEMPLATE 2.7 |
| CM-06-027 | 앱 셸·대시보드(KPI 실데이터, 환율, 크레딧, 소진 알림 표시) | `apps/nomad-commerce/app/(app)/layout.tsx`, `apps/nomad-commerce/app/(app)/dashboard/`, `apps/nomad-commerce/components/shell/` | CM-06-007 | P0 | M | Sonnet | 목 상수 0건, 서버 컴포넌트에서 1회 조회, 375px 레이아웃 | v1 #8, CM #11, SS #8 |
| CM-06-028 | 상품DB·소싱 화면(가상 스크롤 표, 일괄 바, 엑셀 매핑) | `apps/nomad-commerce/app/(app)/products/`, `apps/nomad-commerce/app/(app)/sourcing/`, `apps/nomad-commerce/components/products/` | CM-06-020, CM-06-027 | P0 | L | Sonnet | 2,000행 스크롤, 빈 상태 문구, 키보드 선택 | V2 #13, CM #11, v1 #11 |
| CM-06-029 | 상세페이지 화면(생성 모달 개별/다중, 큐 패널, 뷰어, 인라인 편집, WARN 확인, copy 저장 API) | `apps/nomad-commerce/app/(app)/detail-pages/`, `apps/nomad-commerce/components/detail/`, `apps/nomad-commerce/app/api/detail-pages/[id]/copy/`, `apps/nomad-commerce/app/api/detail-pages/[id]/acknowledge/` | CM-06-010, CM-06-027 | P0 | L | Sonnet | Realtime 진행률 복원, 컴포넌트 300줄 이하 분해, FAIL이면 버튼 비활성 | V2 #13, SS #6 |
| CM-06-030 | 등록 폼·업로드 이력·내보내기 화면 | `apps/nomad-commerce/app/(app)/listings/`, `apps/nomad-commerce/app/(app)/uploads/`, `apps/nomad-commerce/app/(app)/exports/`, `apps/nomad-commerce/components/listing/` | CM-06-023, CM-06-024, CM-06-027 | P0 | M | Sonnet | 완성도 바, 필드 오류 이동, 만료 다운로드 재생성 | V2 #11 |
| CM-06-031 | 설정 화면(마켓 계정, 배송·반품 템플릿, 금지어) | `apps/nomad-commerce/app/(app)/settings/`, `apps/nomad-commerce/components/settings/` | CM-06-009, CM-06-027 | P0 | M | Sonnet | 반품 제한은 4코드 체크박스만, 키 입력 후 마스킹 표시, 기본 금지어 읽기 전용 | CM #12 |
| CM-06-032 | 랜딩·가격 페이지(03장 4절) | `apps/nomad-commerce/app/(marketing)/`, `apps/nomad-commerce/components/marketing/` | CM-06-004 | P0 | M | Sonnet | 01장 6절 금지 문구 0건(체크리스트), 허위 수치·후기 0건, DESIGN_PRINCIPLES 7단계 12항목 | V2 #14, v1 #11 |
| CM-06-033 | 법적 문서(약관, 처리방침, AI 고지)와 법률 검토 의뢰 패키지(반품 4코드, L-1 문안, 구매대행 고지, 고시 책임) | `apps/nomad-commerce/content/legal/`, `apps/nomad-commerce/app/(marketing)/legal/` | CM-06-004 | P0 | S | Sonnet | 검토 전 문안은 "검토 중" 표시, 제3자 제공자 목록 포함 | V2 #14, 01장 6절 |
| CM-06-034 | UI 문구 상수와 오류 코드 → 사용자 문구 매핑 | `apps/nomad-commerce/lib/copy/` | CM-06-006 | P1 | S | Haiku | 04장 7절 코드 전부 매핑, 사과·모호 문구 0건 | DESIGN_PRINCIPLES 카피 규칙 |
| CM-06-035 | 핵심 플로우 E2E(가입 → 아마존 목 → 생성 → WARN 확인 → ZIP → 업로드 목) | `tests/e2e/flows/` | CM-06-028, CM-06-029, CM-06-030 | P0 | M | Opus | 03장 2.1~2.5 플로우 통과, 소셜 로그인 콜백 루프 없음 | CM #4, 02장 6절 |
| CM-06-036 | CI(tsc, lint `no-explicit-any`·`no-console`, build, SQL 체커, RLS 스모크) | `.github/workflows/nomad-commerce.yml` | CM-06-003 | P1 | S | Haiku | PR마다 실행, 실패 시 차단 | v1 #7, SECURITY_BASELINE 13장 |
| CM-06-037 | 원본 아카이브(4개 → `archive/`), 노출 키 재발급 체크리스트, 시안·zip 정리 | `archive/`, `docs/archive-checklist-commerce.md` | CM-06-035 | P1 | S | Haiku | 07장 5절 체크 항목 전부, 원본 코드가 빌드 경로에 없음 | v1 #4·#5, CM #10 |
| CM-06-038 | Phase 2 상품 쇼츠: video 워커 API 호출, 음원 선택 | `apps/nomad-commerce/lib/integrations/video/`, `apps/nomad-commerce/app/(app)/shorts/` | CM-06-035 | P2 | M | Opus | 렌더 코드 0줄(호출만), 실패 환불 | V2 #15, C-6 |
| CM-06-039 | Phase 2 자동화 노드(automation-core 등록), SNS 업로더 소비, 대량 등록 | `apps/nomad-commerce/lib/automation/` | CM-06-035 | P2 | L | Opus | 엣지 없는 그래프 실행 거부, 노드 단위 크레딧 | V2 #15, v1 #6·#9, CM #5, SS #15 |
| CM-06-040 | Phase 2 Capacitor 원격 셸 | `apps/nomad-commerce-mobile/` | CM-06-035 | P2 | M | Opus | `CAP_SERVER_URL` 환경 분리, cleartext 없음, 스토어 빌드 성공 | SS #4, 확정 결정 9 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 006, 008, 017 | 5 | 없음 | DB 적용·타입, 앱 골격, 도메인 상수, 안전 fetch, 금지어 매처 |
| W1 | 002, 003, 005, 007, 015, 016, 021, 022 | 8 | W0 | 모놀리스 스크립트, RLS 테스트, env, 인증, 렌더 템플릿, 변환, 마켓 어댑터 2개 |
| W2 | 009, 010, 011, 012, 025, 027, 032, 033 | 8 | W1(007, 005) | 계정, 생성 API, AI 라우트, 워커 런타임, 결제, 셸, 랜딩, 법적 문서 |
| W3 | 013, 014, 018, 019, 023, 024, 034 | 7 | W2(012, 009) | 파이프라인, 이미지, 소싱, 업로드, 내보내기, 문구 |
| W4 | 020, 026, 028, 029, 030, 031, 036 | 7 | W3 | 소싱 API, 결제 E2E, 화면 4종, CI |
| W5 | 035, 037 | 2 | W4 | 플로우 E2E, 아카이브 → 베타 |
| W6(Phase 2) | 038, 039, 040 | 3 | 베타 출시 | 쇼츠, 자동화, 모바일 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 7 | 17.5% | 13 / 78 = 16.7% |
| Opus | 19 | 47.5% | 41 / 78 = 52.6% |
| Sonnet | 9 | 22.5% | 19 / 78 = 24.4% |
| Haiku | 5 | 12.5% | 5 / 78 = 6.4% |
| 합계 | 40 | 100% | 78 |

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
| `_supabase-modular/seed.sql` | commerce 플랜 features를 01장 4.1/4.4로 갱신(free·starter의 `market_api`, market_slots 1/3/10/-1, slot_sets, concurrency, image_quality 등), commerce 크레딧팩 3행 추가 | seed는 샘플이고 01장이 정본(`seed.sql:3-8`). 현재 free는 업로드가 CM007로 막힌다(스모크 확인) |
| `core.plans` | 이월 비율(예: `carry_over_pct`) 지원 검토 | SS 이월 50/100%(01장 8절 결정 2) |
| core credits | `adjust_credits`(음수 조정) | 크레딧팩 환불(`CORE_SPEC.md` 5.4) |
| core `confirm_payment_order` | 금액 불일치 시 failed 저장(현재 raise가 롤백) | 알려진 결함(`DB_CONVENTIONS.md` 13.2). 제품은 의존하지 않음 |
| core jobs | 조직별 동시성 claim 옵션 | 지금은 commerce 디스패처로 우회(02장 4절) |
| compliance 모듈 | 제품 사전 주입 인터페이스(`checkRules(input, dict)`) 확정 | commerce `banned_words` 사용 |
| llm gateway | purpose `storyline`, `notice_autofill`, `category_suggest` 등록 | 02장 5절 |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `pnpm -F nomad-commerce build`, `tsc --noEmit`, `eslint` 0 오류, 워커 동일 |
| SQL | `_tools-sqlcheck` mod·mono OK |
| RLS 스모크 | CM-06-003 전 항목 통과 |
| 결제 E2E | CM-06-026 통과(Toss 테스트 키) |
| 플로우 E2E | CM-06-035 통과 |
| 06장 작업 | P0·P1 전부 완료, P2는 Phase 2 |
| 법률 검토 | 01장 6절 4개 문안 검토 완료 전 유료 출시 금지 |

P0 작업과 검증 작업 대응: DB·권한(001, 007, 008, 009) → 003 / 결제(025) → 026 / 생성·소싱·업로드·내보내기·화면(006, 010~024, 027~031) → 각 작업 단위 테스트 + 035 / 랜딩·법적(032, 033) → 032 체크리스트 + 법률 검토.
