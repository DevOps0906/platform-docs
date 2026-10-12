# 06 에이전트 작업 계획: Floria (website-floria)

작성일 2026-10-12. 약어 `SI`(site). 작업 ID `SI-06-###`. 앱 루트 `apps/website-floria/`(아래 경로는 이 루트 기준, `supabase/`와 `archive/`는 저장소 루트).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉터리 단위 분할 | 한 디렉터리는 한 작업만 소유한다. 공유 파일(`package.json`, `next.config.ts`)은 SI-06-001/002가 소유하고 다른 작업은 변경 요청만 한다 |
| 콘텐츠와 컴포넌트 분리 | `src/content/`는 SI-06-006만, 섹션 컴포넌트는 섹션마다 별도 디렉터리 |
| 쓰기 경로 | 공개 쓰기는 SI-06-016/017의 Route Handler 한 줄기. 다른 작업이 service_role 클라이언트를 import하지 않는다 |
| 코어 | 수정 금지. 필요하면 6절에 요청 |
| 테스트 | P0 작업마다 대응 테스트가 있다(작업 표 마지막 열이 아니라 수용 기준에 인용) |

## 2. 작업 목록

모델 기준은 `DOC_TEMPLATE.md` 1장. 결제 E2E(Toss) 작업은 필수 항목이지만 이 제품에는 결제가 없어 해당 없음이고, 폼 E2E(SI-06-025)가 대신한다.

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| SI-06-001 | 앱 스캐폴드(Next 16, TS, Tailwind v4, ESLint, lockfile) | `package.json`, `tsconfig*.json`, `eslint.config.*`, `postcss.config.*` | 없음 | P0 | S | Haiku | `npm ci && npm run lint && npm run build`가 빈 페이지로 통과. `latest` 태그 0개. 중첩 `.git` 없음 | 리뷰 5장 #15, 02장 1절 |
| SI-06-002 | 보안 헤더, CSP, 환경변수 검증, 린트 규칙(인라인 grid 금지, 외부 호스트 금지) | `next.config.ts`, `src/lib/env.ts`, `proxy.ts`, `eslint-rules/` | 001 | P0 | S | Opus | 필수 환경변수 누락 시 기동 실패. 응답에 CSP `script-src 'self'`, `img-src 'self' data:`. JSX style의 grid 키는 린트 오류 | 리뷰 #4, #6 |
| SI-06-003 | DB 적용, 타입 생성, Supabase 클라이언트 3종, 모놀리스 변환 스크립트 | `supabase/migrations/`, `src/lib/supabase/`, `src/types/db.ts`, `scripts/to-monolith.mjs` | 001 | P0 | S | Opus | 로컬 Supabase에서 2200 적용 성공. `scripts/to-monolith.mjs` 출력이 문서 폴더의 0002와 일치. 관리자 클라이언트는 브라우저 번들에 없음(번들 검색 0건) | 05장 8절 |
| SI-06-004 | RLS/권한 회귀 테스트(모듈러+모놀리스) | `tests/rls/` | 003 | P0 | M | Fable | 05장 스모크 항목 전부 자동화: B의 타 조직 0행, anon 직접 쓰기 42501, 서비스 전용 RPC의 anon/authenticated 42501, viewer 0행, 전이 위반 22023. 코어 PUBLIC EXECUTE 점검(6절)을 별도 경고 항목으로 보고 | `SECURITY_BASELINE.md` 15장 |
| SI-06-005 | 디자인 토큰, 폰트 self-host, UUPM 초안 대조 | `src/styles/`, `public/fonts/`, `design-system/MASTER.md` | 001 | P0 | S | Sonnet | 03장 4.3 토큰이 CSS 변수로 존재, 컴포넌트에 hex 0개. 폰트 가중치 4개 이하, `font-display: swap`, 외부 폰트 요청 0, 폰트 라이선스 기록 | 리뷰 #17, 5장 #14 |
| SI-06-006 | 콘텐츠 스키마와 데이터 파일 통합(Botanic 베이스, Floria_Neo 카피 비교, 가격/단위 단일화, 후기 규칙, claims) | `src/content/` | 001 | P0 | M | Opus | `collections.ts` 등에 통화 혼재 0. `testimonials`는 `consent_ref` 없으면 빌드 실패하는 타입. `claims.verified=false` 항목은 렌더 대상에서 제외. Floria_Neo 코드는 import하지 않음 | 리뷰 5장 #7(축소: 리뷰는 Fable 권고, 설계는 본 기획 02·05장에서 확정했으므로 구현은 Opus), 4장 구조 제안 |
| SI-06-007 | 이미지 파이프라인과 자산 매니페스트 검사 | `scripts/optimize-images.mjs`, `scripts/check-assets.mjs`, `public/images/` | 001 | P0 | M | Opus | 원본 → WebP(장당 300KB 이하, 제안) 변환. `content/`가 참조하는 자산 누락 0, 외부 이미지 호스트 0, `LICENSES.md` 없으면 실패 | 리뷰 #3, #6, 5장 #2 |
| SI-06-008 | Header + Hero(비대칭 레이아웃, 로드 리빌 1개) | `src/components/sections/hero/`, `src/components/layout/header/` | 005, 006, 007 | P0 | M | Sonnet | 03장 4.4 후보 A. 375~1440px 가로 스크롤 0. `prefers-reduced-motion`에서 리빌 정지. 인라인 grid 0 | 리뷰 #4, 5장 #3, #12 |
| SI-06-009 | Collections + Process 섹션 | `src/components/sections/collections/`, `.../process/` | 005, 006, 007 | P0 | M | Sonnet | 카드 3개, 모바일 1열. 가격 비표시(D-3 전). 프로세스는 `<ol>` 3항목 | 리뷰 #4, 5장 #3, #12 |
| SI-06-010 | Archive + Ethos + 조건부 Clarity + 문의 CTA 섹션 | `src/components/sections/archive/`, `.../ethos/`, `.../clarity/`, `.../cta/` | 005, 006, 007 | P0 | M | Sonnet | 아카이브 5분류의 링크가 모두 유효. 후기 0건이면 Clarity가 DOM에 없음. `href="#"` 0개 | 리뷰 #4, 5장 #3, #12 |
| SI-06-011 | 레이아웃, 라우트 레지스트리, NotFound, sitemap | `src/components/layout/footer/`, `src/lib/routes.ts`, `src/app/not-found.tsx`, `src/app/sitemap.ts` | 005, 006 | P0 | S | Sonnet | 문자열 경로 직접 사용 시 린트 오류. 임의 경로가 헤더/푸터 포함 404. sitemap이 레지스트리와 일치 | 리뷰 #7, 5장 #10 |
| SI-06-012 | SEO/GEO: 메타, OG, canonical, robots, JSON-LD(실제 사업자 정보만) | `src/lib/seo/`, `src/app/layout.tsx`, `src/app/robots.ts` | 006, 011 | P0 | S | Sonnet | `lang="ko"`, title/description/OG 존재. `business.ts`가 비면 JSON-LD 미출력. `555` 전화번호, `aggregateRating` 0개 | 리뷰 #19, 5장 #8 |
| SI-06-013 | 접근성 수정 | 각 컴포넌트 파일(소유자 작업과 순차 협의), `tests/a11y/` | 008, 009, 010, 011 | P1 | M | Sonnet | axe serious 이상 0건, 본문 대비 4.5:1 이상, 아이콘 버튼 `aria-label`, 헤딩 순서, 키보드만으로 문의 제출 가능 | 리뷰 #12~#15, #27, 5장 #9 |
| SI-06-014 | 문의 폼 UI(`/contact`, CTA 연결) | `src/app/(site)/contact/`, `src/components/forms/inquiry/` | 005, 011 | P0 | M | Sonnet | 03장 3.2 명세. 오류 문구는 고칠 방법 제시. 실패 시 입력 유지. 허니팟은 화면 밖 배치+`aria-hidden` | 리뷰 #33, 5장 #11 |
| SI-06-015 | 뉴스레터 폼, 확인/해지 페이지 UI | `src/components/forms/newsletter/`, `src/app/(site)/newsletter/` | 005, 011 | P0 | S | Sonnet | GET은 버튼만 표시, POST로 확정. 항상 같은 성공 문구 | 5장 #11 |
| SI-06-016 | `POST /api/inquiries`: Origin, 크기, Turnstile, IP 해시 레이트 리밋, zod, RPC 호출, 오류 매핑 | `src/app/api/inquiries/`, `src/lib/forms/` | 002, 003 | P0 | M | Opus | 04장 2절 오류 표와 일치. 5회/시간 초과 429+Retry-After. Turnstile 실패 403. 허용 목록 밖 Origin 403. service_role 키가 클라이언트 번들에 없음 | 리뷰 5장 #11, 04장 |
| SI-06-017 | 뉴스레터 API(subscribe/confirm/unsubscribe), HMAC 토큰, 확인 메일, List-Unsubscribe | `src/app/api/newsletter/`, `src/lib/newsletter/`, `src/lib/mail/` | 002, 003 | P0 | M | Opus | 구독 응답이 가입 여부와 무관하게 동일. 만료 토큰 410. 같은 토큰 2회 확정 멱등. 해지 토큰은 만료 없음 | 5장 #11, 04장 |
| SI-06-018 | 문의 알림 워커 | `worker/notify/` | 003, 017 | P1 | S | Opus | 접수 후 2분 이내 1통. 중복 0. `notify_email`이 없으면 건너뜀. 메일 본문에 개인정보 없음 | 01장 SI-F-009 |
| SI-06-019 | 콘솔 인증과 서버 가드(`requireSession`, 사이트 등록 게이트, 프로필 없음 → 로그아웃) | `src/lib/auth/`, `src/app/(console)/admin/(auth)/`, `src/app/(console)/admin/layout.tsx` | 002, 003 | P0 | M | Fable | 비로그인 401, 프로필 없음 로그아웃, 사이트 없는 조직은 안내만, viewer는 문의 접근 거부. 클라이언트 가드에 의존하지 않고 서버에서 검사. 기본 역할 admin 없음 | `SECURITY_BASELINE.md` 11장 |
| SI-06-020 | 콘솔 문의 목록, 상세, 상태 변경, 삭제 | `src/app/(console)/admin/inquiries/` | 019 | P0 | M | Sonnet | 03장 3.3~3.4. 전이 위반은 안내 문구. 목록은 컬럼 명시 select, 25건 페이지 | 01장 SI-F-008 |
| SI-06-021 | 콘솔 구독자 목록, 삭제 요청 처리 | `src/app/(console)/admin/subscribers/` | 019 | P1 | S | Sonnet | `erase_subscriber` 후 이메일이 "삭제됨" 표시. member는 처리 버튼 없음 | SI-F-012 |
| SI-06-022 | 콘솔 설정(알림 이메일, 접수 on/off, 동의 버전) | `src/app/(console)/admin/settings/` | 019 | P1 | S | Sonnet | owner/admin만 변경. 동의 버전 변경 경고 표시 | SI-F-013 |
| SI-06-023 | 개인정보처리방침, 동의 문구, 푸터 사업자 정보(법무 검토 게이트 포함) | `src/app/(site)/privacy/`, `src/content/legal.ts`(SI-06-006과 협의: 파일만 분리) | 006 | P0 | S | Sonnet | 수집 항목, 목적, 보존, 위탁·국외 이전(사업자 확정 후), 거부 권리 포함. 법무 확인 체크리스트(01장 6절)가 PR에 첨부 | 01장 6절 |
| SI-06-024 | CI 품질 게이트: lint, tsc, build, Lighthouse 예산, `check-assets`, `check-budget`, `check-repo`(중첩 .git, LFS, dist-only) | `.github/workflows/website-floria.yml`, `scripts/check-budget.mjs`, `scripts/check-repo.mjs` | 001, 007 | P0 | M | Opus | LCP ≤ 2.5s, 첫 화면 전송 ≤ 2MB. 영상 10MB 초과, `autoplay`+`preload="auto"`, 외부 CDN 문자열, 중첩 `.git` 발견 시 실패 | 리뷰 #1, #2, #3, #5, #6, #8, 5장 #15 |
| SI-06-025 | e2e: 뷰포트 4종, 링크 크롤, 문의/구독 폼 흐름, JSON-LD 검증 | `tests/e2e/` | 008, 009, 010, 011, 014, 015, 016, 017 | P0 | M | Opus | 375/768/1024/1440px에서 scrollWidth ≤ clientWidth. 내부 링크 404 0건. 문의 제출→접수번호, 4번째 제출 429. 구독 확인 흐름 통과 | 리뷰 #4, #7, 5장 #3 |
| SI-06-026 | API·가드 통합 테스트(Vitest+로컬 Supabase) | `tests/api/` | 016, 017, 019 | P0 | M | Opus | 04장 오류 표의 모든 코드 재현. 허니팟은 200이지만 행 0. 콘솔 권한(viewer/member/owner) 매트릭스 | 04장 7절 |
| SI-06-027 | pg_cron 등록, 퍼지 런북 | `supabase/ops/` | 003 | P1 | S | Opus | 매일 03:30 KST `purge_expired` 등록. 만료 데이터 0건 확인 쿼리 | SI-F-021 |
| SI-06-028 | 사이트 등록 스크립트와 초대 온보딩 절차 | `scripts/provision-site.mjs`, `docs-ops/ONBOARDING.md`(앱 내부 운영 문서) | 003 | P0 | S | Opus | 초대 메일 → 로그인 → `provision_site` → 콘솔에 사이트 표시. 엔타이틀먼트 없는 조직은 거부 | SI-F-020 |
| SI-06-029 | 원본 정리와 아카이브: Floria_Neo 카피 추출 후 보관, `.vite` 캐시, Biz_Website dist 보관, Lucury 저장소 경계 결정 절차 | `archive/`(저장소 루트), 07장 절차 | 006 | P1 | S | Opus | `archive/WebSite-*`에 원본 이동 계획서 작성, 중첩 `.git` 처리 방식(서브모듈 또는 제거) 결정 기록. 실행은 사용자 승인 후(git 쓰기 포함) | 리뷰 #5, #8, #34, 5장 #5 |
| SI-06-030 | 연계: Lucury 영상 1080p 트랜스코딩, 프레임 WebP 재추출·점진 로드, 저장소 경계 | 별도 저장소 `Lucury Website`(이 앱 밖) | 016 | P2 | L | Opus | 초기 전송 10MB 이하, 프레임 총합 4MB 이하, 로더 없이 첫 프레임 표시, CTA를 폼 백엔드로 연결 | 리뷰 #1, #2, 5장 #1, #5, #6 |
| SI-06-031 | 연계: Flora Sentiment(NEO_02) 라우팅 보강, 코드 정리, 폼 백엔드 연결 | 별도 저장소 `Floria_NEO_02`(이 앱 밖) | 016 | P2 | M | Opus | 미정의 라우트 0, `*` NotFound, `vercel.json` rewrites, 폼 3곳이 `/api/inquiries` 호출 | 리뷰 #7, #24, 5장 #10, #13 |
| SI-06-032 | 연계: Biz_Website 소스 복원 또는 재구현 결정·실행 | 별도 저장소 | 029 | P2 | L | Opus | 원본 `platform-website` 탐색 결과 기록. 없으면 dist를 레퍼런스로 재구현하고 `src/` 커밋 | 리뷰 #5, 5장 #4 |

작업 수 32. 테스트 대응: SI-06-002/003 → 026·004, 005~012 → 025·024, 014/015 → 025, 016/017 → 026, 019/020 → 004·026, 023 → 법무 체크리스트, 028 → 026.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001 | 1 | 없음 | 빌드되는 빈 앱 |
| W1 | 002, 003, 005, 006, 007 | 5 | W0 완료 | CSP/환경변수, DB 적용+타입, 토큰, 콘텐츠 데이터, 자산 파이프라인 |
| W2 | 004, 008, 009, 010, 011, 016, 017, 019, 023, 024, 027, 028 | 12 | W1 완료 | 섹션, 라우트, 공개 API, 콘솔 가드, 게이트, RLS 테스트 |
| W3 | 012, 013, 014, 015, 018, 020, 021, 022, 026, 029 | 10 | W2 해당 선행 완료 | SEO, 접근성, 폼 UI, 알림, 콘솔 화면, 통합 테스트, 아카이브 계획 |
| W4 | 025 | 1 | W3의 014/015 포함 선행 완료 | e2e 전체 |
| W5 | 030, 031, 032 | 3 | MVP 출시 후 | 연계 사이트(P2) |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 2 | 6.3% | 4/52 = 7.7% |
| Opus | 16 | 50.0% | 28/52 = 53.8% |
| Sonnet | 13 | 40.6% | 19/52 = 36.5% |
| Haiku | 1 | 3.1% | 1/52 = 1.9% |

Opus가 큰 이유: 이 제품의 비 UI 작업이 API, 게이트, 테스트, 연계 사이트 L 작업이기 때문이다. 권한·RLS(004, 019)만 Fable이다.

## 5. 리뷰 작업 흡수표

리뷰 5장(`docs/reviews/WebSite.md:271-287`)의 15개 작업.

| 리뷰 # | 작업 | 흡수한 작업 ID |
|---|---|---|
| 1 | Lucury 영상 최적화 | SI-06-030, 게이트는 SI-06-024 |
| 2 | Botanic 누락 이미지 복구 | SI-06-007, SI-06-006 |
| 3 | Botanic 반응형 복원 | SI-06-008, 009, 010, 025 |
| 4 | Biz_Website 소스 복원 | SI-06-032, 보관은 SI-06-029 |
| 5 | Lucury 리포 경계 정리 | SI-06-029, SI-06-030 |
| 6 | Lucury 프레임 시퀀스 최적화 | SI-06-030 |
| 7 | Floria 3종 통합 설계 | SI-06-006(콘텐츠 통합), SI-06-001(단일 프로젝트). NEO_02는 합치지 않는다(README 2장) |
| 8 | SEO/GEO 공통 적용 | SI-06-012 |
| 9 | 접근성 수정 | SI-06-013 |
| 10 | NEO_02 라우팅 보강 | SI-06-011(이 앱), SI-06-031(NEO_02) |
| 11 | 폼 백엔드 연동 | SI-06-014, 015, 016, 017, 031 |
| 12 | Botanic 스타일 마이그레이션 | SI-06-008, 009, 010 |
| 13 | NEO_02 코드 정리 | SI-06-031 |
| 14 | 폰트/외부 스크립트 로딩 최적화 | SI-06-005, SI-06-002 |
| 15 | CI/품질 게이트 | SI-06-024 |

## 6. 공용 모듈 요청

코어는 이 제품이 수정하지 않는다. 아래를 `_platform-core`에 요청한다.

| # | 요청 | 근거 |
|---|---|---|
| 1 | 모듈러 코어에서 서비스 전용 DEFINER 함수의 PUBLIC EXECUTE를 회수한다. 전역 `alter default privileges revoke execute on functions from public`과 함수별 명시 revoke. 확인된 anon 실행 가능 함수: `rate_limit_hit`, `run_monthly_credit_grants`, `expire_stale_payment_orders`, `purge_rate_limit_buckets`, `reap_stale_jobs`, `purge_expired_oauth_states`, `confirm_payment_order`(PM404까지 도달) 등 | 05장 6절 점검 |
| 2 | `core.rate_limit_hit`, `purge_*` 등 service 전용 함수의 내부 검사를 `is_privileged_session()`에서 EXECUTE 의존 구조로 문서화(DEFINER 안에서 항상 true) | `SECURITY_BASELINE.md` 1장 |
| 3 | `apps.signup_policy='invite'` 강제(가입 시 초대 테이블 검증) | stock 조각과 같은 사실(`1900_stock.sql:7`) |
| 4 | 메일 발송 공용 모듈(확인/알림 메일) 필요 여부 | 현재 `SHARED_MODULES.md` 16개에 없음. 사업자 확정(D-6) 후 제품 로컬로 둘지 결정 |
| 5 | 알려진 결함: `confirm_payment_order`는 금액 불일치 시 failed 주문을 남기지 못한다. 이 제품은 결제가 없어 의존하지 않는다 | `DB_CONVENTIONS.md:296` |

## 7. 완료 정의

| 조건 | 기준 |
|---|---|
| 빌드/타입/린트 | `npm run build`, `tsc --noEmit`, `npm run lint` 통과 |
| SQL | 문서 폴더 체커 OK(모놀리스, 모듈러), RLS 스모크 통과(SI-06-004) |
| 게이트 | SI-06-024의 예산·자산·리포 검사 통과 |
| e2e | SI-06-025 통과 |
| 결제 E2E | 해당 없음(결제 없음) |
| 법무 | 01장 6절 법무 확인 체크리스트 완료, 열린 결정 D-1~D-3, D-6, D-7 확정 |
| 작업 | 06장 2절 P0 전부 완료. P1은 출시 후 2주 안. P2는 별도 일정 |
