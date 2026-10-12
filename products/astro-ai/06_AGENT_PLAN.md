# 06 에이전트 작업 계획: 신비로운AI

작업 ID는 `AS-06-###`(DB_CONVENTIONS 1장 SQLSTATE 접두사 `AS`). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장: Fable(결제, 권한, RLS, 데이터 모델), Opus(기능 구현, API 연동, 테스트 설계), Sonnet(UI, 메인페이지, 컴포넌트, 문서), Haiku(보일러플레이트, 린트/타입, 문구, 반복 체크).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 디렉토리(또는 명시한 파일)는 한 작업만 쓴다. 다른 작업의 파일이 필요하면 선행 작업으로 두고 인터페이스만 import한다 |
| 공용 파일 | `apps/astro-ai/src/app/layout.tsx`, `src/proxy.ts`, `src/lib/`는 AS-06-003 소유. 이후 변경은 003 담당에게 요청 |
| 워커 핸들러 등록 | `apps/astro-worker/src/handlers/*.ts`는 파일명 규칙으로 자동 등록(레지스트리는 AS-06-012 소유). 각 핸들러 파일은 작업별로 따로 소유 |
| API 하위 폴더 | `src/app/api/<폴더>/` 단위로 소유가 다르다(아래 표) |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, 공용 렌더 서비스(`services/render-weasyprint`, flora-publishing 소유)는 수정하지 않는다. 필요하면 6절 요청 |
| 스키마 변경 | `supabase/` 마이그레이션은 AS-06-001만 쓴다. 컬럼 추가가 필요한 작업은 001 후속 작업으로 요청 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| AS-06-001 | DB 조각 적용, 타입 생성, 모듈러 → 모놀리스 변환 스크립트 | `supabase/migrations/`, `scripts/db/` | 없음 | P0 | M | Fable | `supabase db reset` 성공, `check.mjs` mod/mono OK, 변환 스크립트 결과가 `0002_astro_domain.sql`과 같다 | Astro 5장 #2, FD 5장 #3, 05장 |
| AS-06-002 | RLS/권한 회귀 테스트 자동화 | `supabase/tests/` | 001 | P0 | M | Fable | 05장 9절 65항목 + `SECURITY_BASELINE.md` 15장이 CI에서 통과, 실패 시 머지 차단 | SECURITY_BASELINE 15장 |
| AS-06-003 | 앱 골격: Next 16, core-db 클라이언트 3종, `proxy.ts`, `requireSession`, 레이아웃, 로그인·가입·콜백 | `apps/astro-ai/src/app/layout.tsx`, `src/proxy.ts`, `src/lib/`, `src/app/(auth)/` | 001 | P0 | M | Opus | 가입 시 `signup_app='astro'` 전송, 비로그인 `/dashboard` → `/login`, 프로필 없음 → 로그아웃 | Astro 5장 #3, FD 5장 #5 |
| AS-06-004 | 만세력 사양서와 골든 테스트 100건 | `packages/saju-engine/SPEC.md`, `packages/saju-engine/fixtures/` | 없음 | P0 | M | Fable | 01장 AS-F-006 항목 전부 규칙 명시, 골든 100건(분포 01장) 기대값과 출처(기존 만세력 2곳 대조) 기록 | Astro 5장 #6, FD 5장 #1 |
| AS-06-005 | 만세력 엔진 구현 | `packages/saju-engine/src/` | 004 | P0 | L | Fable | 골든 100건 통과, 브라우저 번들 150KB(gzip) 이하(제안), 같은 입력 같은 출력 | Astro 5장 #6, FD 5장 #2 |
| AS-06-006 | PII 암호화 패키지(AES-256-GCM, 키 버전) | `packages/astro-crypto/` | 없음 | P0 | S | Fable | 키 누락 시 예외로 기동 실패, 왕복 테스트, 키 버전 교체 재암호화 함수 | 01장 AS-F-005, SECURITY_BASELINE 12장 |
| AS-06-007 | 보관함·동의 API | `apps/astro-ai/src/app/api/subjects/`, `src/app/api/consents/` | 003, 005, 006 | P0 | M | Opus | 04장 2절 subjects 행 계약 충족, 21번째 409, 동의 없는 가족 400, 응답에 암호문 없음 | FD 5장 #8 |
| AS-06-008 | Toss 크레딧팩 결제(주문, confirm, 웹훅 재조회) | `apps/astro-ai/src/app/api/billing/orders/`, `src/app/api/billing/confirm/`, `src/app/api/webhooks/toss/`, `src/app/billing/` | 003 | P0 | M | Fable | 같은 결제 2회 confirm 지급 1회, 금액 변조 지급 0 + Toss 취소 호출, 웹훅 서명 실패 401 | Astro 5장 #5, FD 5장 #13 |
| AS-06-009 | 환영 크레딧과 가입 남용 방지 | `apps/astro-ai/src/app/api/auth/`, `src/server/welcome-credits.ts` | 003, 027 | P0 | S | Fable | 미인증 0cr, 인증 후 30cr, 같은 조직 2회 호출 원장 1행, 같은 IP 해시 하루 4번째 가입 보류 | FD 5장 #11, 01장 D-3 |
| AS-06-010 | 리딩 생성·재생성·취소·다운로드 API, 단가표 | `apps/astro-ai/src/app/api/readings/`, `src/server/pricing.ts` | 005, 006, 007, 027 | P0 | M | Fable | 잔액 부족 402, 같은 `request_id` 재요청 시 차감 1회, enqueue 실패 시 환불 행, 진행 중 4번째 409, 다운로드 URL 7일 | Astro 5장 #4, FD 5장 #4, #6 |
| AS-06-011 | 프롬프트, 현대적 재해석 사전, 장 출력 zod 스키마, 금지 표현 규칙 | `packages/astro-report/prompts/`, `schema/`, `rules/` | 004 | P0 | M | Opus | 사전 30항목 이상, 금지 규칙이 01장 6.4절 분류 전부 포함, 한글 경계 매칭 테스트 | FD 5장 #7 |
| AS-06-012 | 워커: 생성 핸들러, 핸들러 레지스트리, 정합성 스위퍼 | `apps/astro-worker/src/index.ts`, `src/handlers/generate.ts`, `src/sweeper.ts` | 010, 011, 014 | P0 | L | Opus | 장 병렬(동시 3), 장 재생성 1회, 최종 실패 시 환불 행 1, LLM 입력에 실명·생년월일 0, 리딩·잡 상태 불일치 5분 내 정리 | Astro 5장 #7 |
| AS-06-013 | ThemeConfig 스키마와 CSS 변수 변환기 | `packages/astro-report/theme/` | 없음 | P0 | S | Sonnet | hex·서체 열거형 외 값 거부, `url(`/`@import`/`\` 포함 시 거부 | Astro 5장 #8 |
| AS-06-014 | 책자 HTML 템플릿(표지, 판권면, 면책, 목차, 장), 오행 SVG | `packages/astro-report/templates/` | 011, 013 | P0 | L | Opus | 모든 텍스트 escape, 외부 URL 0, A4 사주 약 10쪽, 같은 본문을 두 테마로 렌더 시 텍스트 동일 | FD 5장 #10 |
| AS-06-015 | 렌더 클라이언트와 재생성 핸들러 | `apps/astro-worker/src/handlers/render.ts`, `src/render-client.ts` | 014 | P0 | M | Opus | 120초 타임아웃, 실패 시 5cr 환불, 성공 시 `current_render_id` 갱신 | FD 5장 #6 |
| AS-06-016 | 발송 outbox 루프, Resend, 재발송 API | `apps/astro-worker/src/delivery/`, `apps/astro-ai/src/app/api/deliveries/` | 012 | P1 | M | Opus | 5분 간격 3회 후 dead, 재발송 일 3회 제한, 메일에 첨부 없이 서명 URL | Astro 5장 #10 |
| AS-06-017 | 디자인 토큰, MASTER.md, 기본 UI 컴포넌트 | `apps/astro-ai/design-system/`, `src/styles/`, `src/components/ui/` | 003 | P0 | M | Sonnet | 03장 4.3절 토큰만 사용(hex 하드코딩 0), 4.4절 검토 기록, 대비 4.5:1 | DESIGN_PRINCIPLES 3~5단계 |
| AS-06-018 | 보관함 화면과 입력 폼(원국 프리뷰 연결) | `apps/astro-ai/src/components/subjects/`, `src/app/dashboard/subjects/` | 007, 017, 019 | P0 | M | Opus | 03장 2.2 플로우 통과, 프리뷰 100ms 이내, 존재하지 않는 음력일 폼 오류 | FD 5장 #8 |
| AS-06-019 | 원국 카드, 오행 막대 SVG, 대운 타임라인 | `apps/astro-ai/src/components/chart/` | 005, 017 | P0 | M | Sonnet | 金·水 테두리 대비, 표 마크업과 스크린리더 라벨, 375px에서 4열 유지 | FD 5장 #9 |
| AS-06-020 | 리딩 시작 스테퍼, 타로 부채꼴 선택, 진행률(Realtime), 결과 뷰어 | `apps/astro-ai/src/components/reading/`, `src/app/dashboard/readings/` | 010, 017, 019 | P0 | M | Opus | `postgres_changes` 구독으로 단계 표시, 402 시 충전 모달, 키보드로 카드 3장 선택 | Astro 5장 #9 |
| AS-06-021 | 대시보드 홈, 히스토리, 크레딧, 설정 | `apps/astro-ai/src/app/dashboard/page.tsx`, `dashboard/history/`, `dashboard/credits/`, `dashboard/settings/` | 008, 017 | P1 | M | Sonnet | 빈 상태·스켈레톤, 원장 표, 설정의 기본 테마 저장(사용자 세션 `preferences`) | Astro 5장 #11 |
| AS-06-022 | 최소 어드민(유저, 결제·환불, 크레딧 지급, 발송 모니터) | `apps/astro-ai/src/app/admin/`, `src/app/api/admin/` | 008, 010 | P1 | M | Opus | 일반 사용자 403, 사유 없는 환불·지급 400, 모든 쓰기 감사 1행 | Astro 5장 #12 |
| AS-06-023 | 랜딩, 샘플, 가격, JSON-LD, `/llms.txt` | `apps/astro-ai/src/app/(marketing)/page.tsx`, `(marketing)/layout.tsx`, `(marketing)/sample/`, `(marketing)/pricing/`, `public/llms.txt` | 017, 024 | P1 | M | Sonnet | 빌드 산출물에 `aggregateRating` 0, LCP 2.5초, Lighthouse 성능 90/접근성 95, 금지 문구 0 | Astro 5장 #13, FD 5장 #14 |
| AS-06-024 | Live Demo API와 키워드 규칙 | `apps/astro-ai/src/app/api/demo/`, `packages/saju-engine/src/demo/` | 005, 027 | P1 | S | Opus | IP 해시당 4번째 429, LLM 호출 0, 입력 로그 0 | Astro 5장 #14 |
| AS-06-025 | 법적 페이지(약관, 개인정보처리방침, 환불, 면책)와 동의 문구 | `apps/astro-ai/src/app/(marketing)/legal/`, `apps/astro-ai/content/legal/` | 없음 | P0 | S | Sonnet | 01장 6절 항목 전부 반영, 국외 이전 표, 통신판매업 정보 자리 | FD 5장 #14 |
| AS-06-026 | 대상 삭제, 탈퇴(30일 유예 purge), 데이터 내보내기, 파일 purge 핸들러 | `apps/astro-ai/src/app/api/account/`, `apps/astro-worker/src/handlers/purge.ts` | 007, 012 | P1 | M | Fable | 대상 삭제 후 리딩 0행·파일 0개(24시간), 탈퇴 30일 뒤 조직 0행, 감사 기록 | 01장 AS-F-026, AS-F-027 |
| AS-06-027 | 레이트 리밋 래퍼와 IP 해시 | `apps/astro-ai/src/server/ratelimit/` | 003 | P0 | S | Opus | 키 규약 `astro:<route>:<id>`, 원문 IP 저장 0, 429 + Retry-After | FD 5장 #11 |
| AS-06-028 | Playwright 핵심 5플로우 + Lighthouse CI | `e2e/flows/`, `.github/workflows/astro-e2e.yml` | 020, 021, 022, 023 | P1 | M | Opus | 가입, 리딩 생성, 실패 자동 환불, 어드민 환불, 대상 삭제 5개 녹색 | Astro 5장 #15 |
| AS-06-029 | 결제 E2E(Toss 테스트 키) | `e2e/billing/` | 008 | P0 | M | Opus | 팩 4종 결제 성공, 결제창 취소, 새로고침 재confirm 멱등, 금액 변조 차단 | FD 5장 #13, DOC_TEMPLATE 필수 |
| AS-06-030 | KASI 대조 배치 스크립트 | `packages/saju-engine/scripts/` | 005 | P1 | S | Opus | 1900~2100 음양력 변환과 절입 시각 샘플 1,000건 불일치 0, CI 수동 트리거 | FD 5장 #1, #13 |
| AS-06-031 | 원본 문서 정리와 아카이브 | `archive/`, `docs/astro-ai/` | 없음 | P0 | S | Haiku | 07장 5절 체크리스트 완료, 원본 대화 잔재·`[cite]` 미이식 확인 | FD 5장 #15, Astro 5장 #1 |
| AS-06-032 | 환경변수 검증, 타입 재생성 스크립트, 린트 설정 | `apps/astro-ai/src/env.ts`, `apps/astro-worker/src/env.ts`, 루트 `package.json` scripts, `eslint.config.mjs` | 003 | P0 | S | Haiku | 02장 8절 필수 변수 누락 시 기동 실패, `NEXT_PUBLIC_`에 비밀 0 | SECURITY_BASELINE 13장 |
| AS-06-033 | 리포트 품질 평가셋(골든 입력 20건 자동 검사) | `packages/astro-report/eval/` | 011 | P1 | S | Opus | 20건 모두 글자 수·호칭 3회·금지 표현 0·수치가 엔진 값과 일치 | 01장 AS-F-009~011 |
| AS-06-034 | 워커 관측(로그 마스킹, p95 지표) | `apps/astro-worker/src/observability/` | 012 | P1 | S | Opus | 로그에 실명·생년월일·이메일 0, T0→PDF p95 대시보드 | 01장 5절 |
| AS-06-035 | ePub 내보내기(Phase 2) | `packages/astro-report/epub/` | 014 | P2 | S | Sonnet | PDF와 같은 HTML 템플릿, ePubCheck 통과 | FD 5장 #12 |
| AS-06-036 | 카카오 알림톡(Phase 2) | `apps/astro-worker/src/delivery-kakao/` | 016 | P2 | M | Opus | 수신 동의 없는 번호 발송 0, 템플릿 심사 통과 후 활성 | 01장 2절 |
| AS-06-037 | 구독 플랜과 빌링키(Phase 2) | `apps/astro-ai/src/app/api/billing/subscriptions/` | 008 | P2 | L | Fable | 코어 5.3절 시퀀스, Master 월 3,000cr 공정 사용 서버 강제 | 01장 4.1절 |
| AS-06-038 | 궁합·연간 운세(Phase 2) | `packages/astro-report/phase2/`, `packages/saju-engine/src/compat/` | 005, 011 | P2 | L | Opus | 보관함에서 2명 선택, 연간 12섹션 병렬 생성 | 01장 2절 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 006, 013, 025, 031 | 6 | 없음 | DB 적용·타입, 엔진 사양, 암호화, 테마 변환기, 법적 문구, 원본 정리 |
| W1 | 002, 003, 005, 011 | 4 | W0 | RLS 회귀 CI, 앱 골격, 엔진, 프롬프트·스키마 |
| W2 | 007, 008, 014, 017, 027, 030, 032, 033 | 8 | W1(각 선행) | 보관함 API, 결제, 템플릿, 토큰, 레이트 리밋, KASI 대조, 평가셋 |
| W3 | 009, 010, 015, 019, 021, 024, 029 | 7 | W2 | 환영 크레딧, 리딩 API, 렌더, 차트 컴포넌트, 대시보드, 데모, 결제 E2E |
| W4 | 012, 018, 020, 022, 023 | 5 | W3 | 워커 생성, 보관함·리딩 화면, 어드민, 랜딩 |
| W5 | 016, 026, 028, 034 | 4 | W4 | 발송, 삭제·탈퇴, E2E, 관측. MVP 출시 조건 |
| W6 | 035, 036, 037, 038 | 4 | MVP 출시 | Phase 2 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 10 | 26.3% | 20 / 69 = 29.0% |
| Opus | 19 | 50.0% | 36 / 69 = 52.2% |
| Sonnet | 7 | 18.4% | 11 / 69 = 15.9% |
| Haiku | 2 | 5.3% | 2 / 69 = 2.9% |

Fable은 데이터 모델, RLS, 결제, 크레딧 차감 경로, 엔진 사양·구현(정확도가 제품 신뢰의 핵심, `docs/reviews/Astro_AI.md:125`), 개인정보 삭제를 맡는다.

## 5. 리뷰 작업 흡수표

| 리뷰 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| `docs/reviews/Astro_AI.md` 5장 #1 | 아키텍처 단일화, 문서 모순 해소 | 02장 머리 결정표(이 기획), AS-06-031 |
| Astro 5장 #2 | ERD와 마이그레이션 + RLS | AS-06-001, AS-06-002 |
| Astro 5장 #3 | 프로젝트 골격, proxy, 역할 매트릭스 | AS-06-003 |
| Astro 5장 #4 | 크레딧 RPC 재작성 | 코어 `consume/refund_credits` 사용 + AS-06-010 |
| Astro 5장 #5 | Toss 일반결제 confirm | AS-06-008 |
| Astro 5장 #6 | 만세력 엔진 + 골든 100건 | AS-06-004, AS-06-005 |
| Astro 5장 #7 | FastAPI 워커(Claude 분할 생성, WeasyPrint, 환불) | AS-06-012(TS 워커), AS-06-015(공용 FastAPI 렌더 호출) |
| Astro 5장 #8 | 테마 시스템 | AS-06-013 |
| Astro 5장 #9 | 리딩 시작 플로우 | AS-06-020 |
| Astro 5장 #10 | 발송 파이프라인 | AS-06-016 |
| Astro 5장 #11 | 사용자 대시보드 나머지 탭 | AS-06-021 |
| Astro 5장 #12 | 최소 어드민 | AS-06-022 |
| Astro 5장 #13 | 랜딩 + GEO, 가상 수치 제거 | AS-06-023 |
| Astro 5장 #14 | Live Demo API | AS-06-024 |
| Astro 5장 #15 | Playwright 5플로우 + Lighthouse | AS-06-028 |
| `docs/reviews/FortuneDocs.md` 5장 #1 | 만세력 규칙 명세 + 회귀 100건 | AS-06-004 |
| FD 5장 #2 | `lib/saju` 엔진 | AS-06-005 |
| FD 5장 #3 | DDL 재설계 | AS-06-001 |
| FD 5장 #4 | 크레딧 RPC + REVOKE | 코어(이미 service_role 전용) + AS-06-010, 검증은 AS-06-002 |
| FD 5장 #5 | 저장소 생성, 인증 골격 이식 | AS-06-003 |
| FD 5장 #6 | 생성 라우트(인증 → 소유 확인 → 차감 → 엔진 → LLM → insert → 환불) | AS-06-010, AS-06-012 |
| FD 5장 #7 | 프롬프트 설계 | AS-06-011 |
| FD 5장 #8 | 대상 관리 화면 + 동의 | AS-06-007, AS-06-018 |
| FD 5장 #9 | 원국 카드, 오행 SVG, 대운 타임라인 | AS-06-019 |
| FD 5장 #10 | 책 HTML 템플릿 + PDF | AS-06-014, AS-06-015 |
| FD 5장 #11 | 레이트 리밋, 가입 크레딧 남용 방지 | AS-06-009, AS-06-027 |
| FD 5장 #12 | ePub | AS-06-035 |
| FD 5장 #13 | Toss 충전 | AS-06-008, AS-06-029 |
| FD 5장 #14 | 랜딩, JSON-LD, 개인정보처리방침·면책 | AS-06-023, AS-06-025 |
| FD 5장 #15 | 문서 정리 | AS-06-031 |

## 6. 공용 모듈 요청

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 |
|---|---|---|---|---|
| R-1 | `_platform-core` 크레딧 | `adjust_credits`(음수 허용, service_role) 추가(`docs/products/_platform-core/CORE_SPEC.md:237` 제안) | 결제 환불 시 미사용 크레딧 회수 | `consume_credits(reason='refund_adjust')`로 회수 |
| R-2 | `_supabase-modular/seed.sql` | astro 크레딧팩을 단가표(330/800/2,400cr, 12,900/27,900원)로, starter `features`를 01장 4.6절로, `signup_credits=0`(01장 D-3 확정 시) | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치 | 서버가 `features` 누락 키를 403으로 처리하지 않도록 기본값 표를 둔다 |
| R-3 | LLM 게이트웨이 | `credits: 0` 호출 허용 + `ai_usage.ledger_id`에 리딩 원장 id 지정 | 리딩 단위 선차감 | 게이트웨이를 `withCredits` 없이 호출하는 내부 모드 |
| R-4 | `_platform-core` 삭제 | `purge_organization` 전에 `payments`, `payment_orders`를 5년 보존 아카이브로 옮기는 절차 | 전자상거래법 대금결제 기록 5년(01장 6.1절) | 탈퇴 purge 전 결제 기록을 운영 저장소로 내보내기(AS-06-026) |
| R-5 | `_platform-core` 결제 | `confirm_payment_order` 금액 불일치 시 주문 failed 기록 결함 수정(`docs/products/_platform-core/DB_CONVENTIONS.md:13.2절`) | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가 | Route Handler가 PM001 시 별도 호출로 `fail_payment_order`를 부르고 알림·취소 |
| R-6 | flora-publishing(렌더 서비스) | `app_id='astro'` 허용, A4 프리셋, 한자 포함 Noto Serif/Sans CJK KR 확인, 첫 페이지 PNG 미리보기 엔드포인트 | 공용 서비스 소비 | 없음(필수) |
| R-7 | `_platform-core` webhooks | Toss 웹훅 서명 방식 확인 결과 공유 | 미확인 사항 | 수신 후 결제 조회 API 재검증 |

## 7. 완료 정의

| 조건 | 기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -r build`, `tsc --noEmit`, `eslint` 오류 0 |
| DB | `check.mjs` mod/mono OK, RLS 회귀(AS-06-002) 전 항목 통과 |
| 엔진 | 골든 100건 통과, KASI 대조 불일치 0 |
| 결제 E2E | AS-06-029 녹색(Toss 테스트 키) |
| 핵심 E2E | AS-06-028 5플로우 녹색 |
| 성능 | T0 → PDF p95 60초 이하(스테이징 50건), 랜딩 Lighthouse 성능 90/접근성 95 |
| 법·문구 | 01장 6절 항목 반영, 빌드 산출물 `aggregateRating` 0, 금지 표현 검사 통과 |
| 작업 | W0~W5 작업 전부 완료(W6은 Phase 2) |
