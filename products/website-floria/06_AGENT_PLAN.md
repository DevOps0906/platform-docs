# 06 에이전트 작업 계획: Floria (website-floria)

작성일 2026-10-12. 약어 `SI`(site). 작업 ID `SI-06-###`. 앱 루트 `apps/website-floria/`(아래 경로는 이 루트 기준, `supabase/`, `archive/`, `apps/api/`, `infra/`, `worker/`는 저장소 루트).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md` 4장) 작업 16개(SI-06-033~048)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고 내용이 바뀐 기존 작업은 005(디자인 시스템 2단계로 확대), 001·002·003·004·008~011·014·015·020·023~027(수용 기준과 선행 보강)이다. 작업 수 48개(2026-10-14 인증 단계 B 작업 SI-06-049 추가로 49개, 8절)는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. 여기에는 기존 연계 사이트 P2 작업 3개와 AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘어난 16개가 들어 있고, 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉터리 단위 분할 | 한 디렉터리는 한 작업만 소유한다. 공유 파일(`package.json`, `next.config.ts`)은 SI-06-001/002가 소유하고 다른 작업은 변경 요청만 한다 |
| 콘텐츠와 컴포넌트 분리 | `src/content/`는 SI-06-006만, 섹션 컴포넌트는 섹션마다 별도 디렉터리 |
| 쓰기 경로 | 공개 쓰기는 SI-06-016/017의 Route Handler 한 줄기. 다른 작업이 service_role 클라이언트를 import하지 않는다 |
| 코어 | 수정 금지. 필요하면 6절에 요청 |
| 테스트 | P0 작업마다 대응 테스트가 있다(작업 표 마지막 열이 아니라 수용 기준에 인용) |
| AI 서비스 경계 | `apps/api/`(저장소 루트)는 SI-06-036이 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. site 확장은 작업별로 나눈다: 040 `app/ai/products/site/knowledge.py`, 041 `app/ai/products/site/wiki_config.py`, 043 `app/ai/graphs/site_consult.py`·`app/ai/compliance/site.py`, 044 `app/ai/tools/site/` |
| AI 게이트 경계 | `src/app/api/ai/`, `src/server/ai/`는 SI-06-037만 쓴다. `src/app/api/voice/`는 046, `src/app/api/admin/ai/`는 038, `src/app/api/admin/knowledge/`·`admin/wiki/`·`src/app/api/internal/`는 041 소유. 서명 토큰 발급 모듈은 037만 만들고 다른 작업은 import한다 |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `packages/ui-3d`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(6~12) |
| 지식 원고 | `content/knowledge/`는 SI-06-039만 쓴다. 원고 자료(사례, 식물 정보, FAQ)는 운영자가 제공한다(01장 D-11). 자료가 없으면 039는 템플릿·린트·샘플 구조까지만 완료하고 색인 대상은 비운다 |
| 사람 작업 | SI-06-034(디자인 시스템 3단계)는 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(008~011, 014, 015, 020~022, 038, 041, 042, 045, 047)은 SI-06-035(4단계) 뒤에 시작한다(`docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md:39-49`) |
| 장착 요청 | 상담 위젯 마운트는 `src/app/(site)/layout.tsx`(SI-06-011 소유), 3D 히어로 마운트는 `src/components/sections/hero/`(SI-06-008 소유)에 각 1줄을 요청해서 한다. `/guide` 라우트는 `src/lib/routes.ts`(011)에 등록 요청 |

## 2. 작업 목록

모델 기준은 `DOC_TEMPLATE.md` 1장. 결제 E2E(Toss) 작업은 필수 항목이지만 이 제품에는 결제가 없어 해당 없음이고, 폼 E2E(SI-06-025)가 대신한다.

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| SI-06-001 | 앱 스캐폴드(Next 16, TS, Tailwind CSS v4, ESLint, lockfile) | `package.json`, `tsconfig*.json`, `eslint.config.*`, `postcss.config.*` | 없음 | P0 | S | Haiku | `npm ci && npm run lint && npm run build`가 빈 페이지로 통과. `latest` 태그 0개. 중첩 `.git` 없음. Tailwind 4.x 고정, `tailwind.config.js`와 `@tailwind base` 0건 | 리뷰 5장 #15, 02장 1절 |
| SI-06-002 | 보안 헤더, CSP, 환경변수 검증, 린트 규칙(인라인 grid 금지, 외부 호스트 금지) | `next.config.ts`, `src/lib/env.ts`, `proxy.ts`, `eslint-rules/` | 001 | P0 | S | Opus | 필수 환경변수 누락 시 기동 실패(02장 8절). 스위치가 켜진 사이트에서 AI 변수가 없으면 기동 실패. 응답에 CSP `script-src 'self'`, `img-src 'self' data:`, `connect-src`는 자기 도메인과 Turnstile만, `Permissions-Policy: microphone=(self)`. JSX style의 grid 키는 린트 오류 | 리뷰 #4, #6 |
| SI-06-003 | DB 적용, 타입 생성, Supabase 클라이언트 3종, 모놀리스 변환 스크립트 | `supabase/migrations/`, `src/lib/supabase/`, `src/types/db.ts`, `scripts/to-monolith.mjs` | 001 | P0 | S | Opus | 로컬 Supabase에서 2200 적용 성공(AI 스위치 컬럼, `update_ai_settings`, 라우팅 8행 포함, 2회 적용 멱등, `ai_routing_settings` app `site` 8행). `scripts/to-monolith.mjs` 출력이 문서 폴더의 0002와 일치. 관리자 클라이언트는 브라우저 번들에 없음(번들 검색 0건) | 05장 8절 |
| SI-06-004 | RLS/권한 회귀 테스트(모듈러+모놀리스) | `tests/rls/` | 003 | P0 | M | Fable | 05장 스모크 항목 전부 자동화: B의 타 조직 0행, anon 직접 쓰기 42501, 서비스 전용 RPC의 anon/authenticated 42501, viewer 0행, 전이 위반 22023. 코어 PUBLIC EXECUTE 점검(6절)을 별도 경고 항목으로 보고. AI 항목 추가: anon의 `core.ai_*`·`wiki_*`·`voice_*` 접근 42501, 방문자 대화(`user_id` null)를 authenticated가 SELECT하면 0행, `update_ai_settings`를 member·viewer·anon이 호출하면 42501, `sites` 직접 UPDATE 42501, `match_ai_chunks`·`resolve_ai_route`를 authenticated가 호출하면 42501, `ai_chunks` SELECT 42501 | `SECURITY_BASELINE.md` 15장, 16장 |
| SI-06-005 | 디자인 시스템 2단계: Tailwind CSS v4 토큰(`tokens.css` `@theme`, 라이트/다크), 폰트 self-host, UUPM 초안 대조, `MASTER.md`, 기본 UI 컴포넌트와 배리언트, 미리보기 `/dev/components` | `src/styles/`, `public/fonts/`, `design-system/MASTER.md`, `src/components/ui/`, `src/app/dev/components/` | 001, 033 | P0 | M | Sonnet | 03장 4.3 토큰이 `@theme` CSS 변수로 존재, 컴포넌트에 hex 0개, 03장 3.7절 기본 컴포넌트 전부 라이트/다크 미리보기, `tailwind.config.js`·v3 문법 0, Tailwind 4.x 고정, `COMPONENTS.md` 배리언트 표 초안, 대비 4.5:1. 폰트 가중치 4개 이하, `font-display: swap`, 외부 폰트 요청 0, 폰트 라이선스 기록. `/dev/components`는 프로덕션 빌드에서 404 | 리뷰 #17, 5장 #14, DESIGN_PRINCIPLES 3~5단계, DESIGN_SYSTEM 4장 2단계 |
| SI-06-006 | 콘텐츠 스키마와 데이터 파일 통합(Botanic 베이스, Floria_Neo 카피 비교, 가격/단위 단일화, 후기 규칙, claims) | `src/content/` | 001 | P0 | M | Opus | `collections.ts` 등에 통화 혼재 0. `testimonials`는 `consent_ref` 없으면 빌드 실패하는 타입. `claims.verified=false` 항목은 렌더 대상에서 제외. Floria_Neo 코드는 import하지 않음 | 리뷰 5장 #7(축소: 리뷰는 Fable 권고, 설계는 본 기획 02·05장에서 확정했으므로 구현은 Opus), 4장 구조 제안 |
| SI-06-007 | 이미지 파이프라인과 자산 매니페스트 검사 | `scripts/optimize-images.mjs`, `scripts/check-assets.mjs`, `public/images/` | 001 | P0 | M | Opus | 원본 → WebP(장당 300KB 이하, 제안) 변환. `content/`가 참조하는 자산 누락 0, 외부 이미지 호스트 0, `LICENSES.md` 없으면 실패 | 리뷰 #3, #6, 5장 #2 |
| SI-06-008 | Header + Hero(비대칭 레이아웃, 3D 장면 슬롯과 정지 이미지 자리) | `src/components/sections/hero/`, `src/components/layout/header/` | 005, 006, 007, 035 | P0 | M | Sonnet | 03장 4.4 후보 A(오른쪽 구역은 3D 온실 구조물 자리). 정지 이미지 자리가 크기 지정으로 CLS 0. 375~1440px 가로 스크롤 0. `prefers-reduced-motion`에서 연출 정지. 인라인 grid 0. 3D 장착은 SI-06-047이 슬롯에 1줄 요청 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/nomad-design-modules/_design-guide/REFERENCES.md:16-23`). | 리뷰 #4, 5장 #3, #12 |
| SI-06-009 | Collections + Process 섹션 | `src/components/sections/collections/`, `.../process/` | 005, 006, 007, 035 | P0 | M | Sonnet | 카드 3개, 모바일 1열. 가격 비표시(D-3 전). 프로세스는 `<ol>` 3항목 | 리뷰 #4, 5장 #3, #12 |
| SI-06-010 | Archive + Ethos + 조건부 Clarity + 문의 CTA 섹션 | `src/components/sections/archive/`, `.../ethos/`, `.../clarity/`, `.../cta/` | 005, 006, 007, 035 | P0 | M | Sonnet | 아카이브 5분류의 링크가 모두 유효. 후기 0건이면 Clarity가 DOM에 없음. `href="#"` 0개 | 리뷰 #4, 5장 #3, #12 |
| SI-06-011 | 레이아웃, 라우트 레지스트리, NotFound, sitemap | `src/components/layout/footer/`, `src/lib/routes.ts`, `src/app/not-found.tsx`, `src/app/sitemap.ts`, `src/app/(site)/layout.tsx` | 005, 006, 035 | P0 | S | Sonnet | 문자열 경로 직접 사용 시 린트 오류. 임의 경로가 헤더/푸터 포함 404. sitemap이 레지스트리와 일치. `/guide` 라우트 등록 요청 수용(042 전에는 GNB 미노출). 상담 위젯 마운트 1줄 요청 수용(045) | 리뷰 #7, 5장 #10 |
| SI-06-012 | SEO/GEO: 메타, OG, canonical, robots, JSON-LD(실제 사업자 정보만) | `src/lib/seo/`, `src/app/layout.tsx`, `src/app/robots.ts` | 006, 011 | P0 | S | Sonnet | `lang="ko"`, title/description/OG 존재. `business.ts`가 비면 JSON-LD 미출력. `555` 전화번호, `aggregateRating` 0개 | 리뷰 #19, 5장 #8 |
| SI-06-013 | 접근성 수정 | 각 컴포넌트 파일(소유자 작업과 순차 협의), `tests/a11y/` | 008, 009, 010, 011 | P1 | M | Sonnet | axe serious 이상 0건, 본문 대비 4.5:1 이상, 아이콘 버튼 `aria-label`, 헤딩 순서, 키보드만으로 문의 제출 가능 | 리뷰 #12~#15, #27, 5장 #9 |
| SI-06-014 | 문의 폼 UI(`/contact`, CTA 연결) | `src/app/(site)/contact/`, `src/components/forms/inquiry/` | 005, 011, 035 | P0 | M | Sonnet | 03장 3.2 명세. 오류 문구는 고칠 방법 제시. 실패 시 입력 유지. 허니팟은 화면 밖 배치+`aria-hidden`. `/contact?from=consult`이면 sessionStorage의 `inquiry_hint`(종류, 초안)로 종류·내용을 채우되 자동 제출이 없고 방문자가 고칠 수 있으며 `source_path`는 `/consult` | 리뷰 #33, 5장 #11, 01장 SI-F-025 |
| SI-06-015 | 뉴스레터 폼, 확인/해지 페이지 UI | `src/components/forms/newsletter/`, `src/app/(site)/newsletter/` | 005, 011, 035 | P0 | S | Sonnet | GET은 버튼만 표시, POST로 확정. 항상 같은 성공 문구 | 5장 #11 |
| SI-06-016 | `POST /api/inquiries`: Origin, 크기, Turnstile, IP 해시 레이트 리밋, zod, RPC 호출, 오류 매핑 | `src/app/api/inquiries/`, `src/lib/forms/` | 002, 003 | P0 | M | Opus | 04장 2절 오류 표와 일치. 5회/시간 초과 429+Retry-After. Turnstile 실패 403. 허용 목록 밖 Origin 403. service_role 키가 클라이언트 번들에 없음 | 리뷰 5장 #11, 04장 |
| SI-06-017 | 뉴스레터 API(subscribe/confirm/unsubscribe), HMAC 토큰, 확인 메일, List-Unsubscribe | `src/app/api/newsletter/`, `src/lib/newsletter/`, `src/lib/mail/` | 002, 003 | P0 | M | Opus | 구독 응답이 가입 여부와 무관하게 동일. 만료 토큰 410. 같은 토큰 2회 확정 멱등. 해지 토큰은 만료 없음 | 5장 #11, 04장 |
| SI-06-018 | 문의 알림 워커 | `worker/notify/` | 003, 017 | P1 | S | Opus | 접수 후 2분 이내 1통. 중복 0. `notify_email`이 없으면 건너뜀. 메일 본문에 개인정보 없음 | 01장 SI-F-009 |
| SI-06-019 | 콘솔 인증 Stage A(확정 결정 22): 인증 모듈 경계(`AUTH_ROADMAP.md` 3.1절 `getAuthConfig`·`isMockAuthAllowed`·`listLoginOptions`·`finishLogin`), Mock 로그인(`POST /api/dev/login`, `/admin/login` 개발용 패널, `MOCK AUTH · 로컬 전용` 배지), `scripts/dev/seed-users.mjs` + 제품 훅 `seed-users.site.mjs`(05장 10절, `provision_site` 완료·미완료 운영자), 가드(env zod, 404, 서버 컴포넌트 분기)와 서버 가드(`requireSession`, 사이트 등록 게이트, 프로필 없음 → 로그아웃). 초대 메일 수락·비밀번호 설정·재설정 화면은 Stage B(SI-06-049)로 옮김 | `src/lib/auth/`(`oauth/` 제외), `src/app/(console)/admin/(auth)/login/`(`providers/` 제외), `src/app/(console)/admin/(auth)/no-access/`, `src/app/(console)/admin/layout.tsx`, `src/app/api/dev/login/`, `scripts/dev/` | 002, 003 | P0 | M | Fable | 비로그인 401, 프로필 없음 로그아웃, viewer는 문의 접근 거부, 서버에서 검사, 기본 역할 admin 없음. Mock 기준: `owner` 페르소나 로그인 → `entitled=true`·사이트 1행·`/admin/inquiries`, `site_pending` → "등록된 사이트가 없습니다"만, `no_app` → `/admin/no-access`, `outsider`로 owner 조직 문의·구독자 0행, `AUTH_MODE=mock VERCEL_ENV=production npm run build` 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404·개발용 패널 없음, 시드 스크립트는 원격 URL이면 exit 1·2회 실행 멱등, `DEV_SEED_PASSWORD`가 번들에 0 | `SECURITY_BASELINE.md` 11장, `AUTH_ROADMAP.md` 2장, 3.1~3.2절, 9장 |
| SI-06-020 | 콘솔 문의 목록, 상세, 상태 변경, 삭제 | `src/app/(console)/admin/inquiries/` | 019, 035 | P0 | M | Sonnet | 03장 3.3~3.4. 전이 위반은 안내 문구. 목록은 컬럼 명시 select, 25건 페이지. `source_path`가 `/consult`인 문의에 "상담에서" 배지 | 01장 SI-F-008 |
| SI-06-021 | 콘솔 구독자 목록, 삭제 요청 처리 | `src/app/(console)/admin/subscribers/` | 019, 035 | P1 | S | Sonnet | `erase_subscriber` 후 이메일이 "삭제됨" 표시. member는 처리 버튼 없음 | SI-F-012 |
| SI-06-022 | 콘솔 설정(알림 이메일, 접수 on/off, 동의 버전) | `src/app/(console)/admin/settings/` | 019, 035 | P1 | S | Sonnet | owner/admin만 변경. 동의 버전 변경 경고 표시 | SI-F-013 |
| SI-06-023 | 개인정보처리방침, 동의 문구, 푸터 사업자 정보, AI 고지문(법무 검토 게이트 포함) | `src/app/(site)/privacy/`, `src/content/legal.ts`(SI-06-006과 협의: 파일만 분리), `src/content/ai-notice.ts` | 006 | P0 | S | Sonnet | 수집 항목, 목적, 보존, 위탁·국외 이전(사업자 확정 후), 거부 권리 포함. AI 상담·음성 항목(질문 마스킹 저장, 30일 보존, 방문자 쿠키, 제3자·국외 이전은 운영자 동의 시, Dify 로그 30일, 음성 원본 미저장)과 상담 시작 고지문·음성 처리 고지문·국외 이전 고지문의 문구와 버전 상수(02장 8절 환경변수와 같은 값), AI 생성 표시 문구. 법무 확인 체크리스트(01장 6절)가 PR에 첨부 | 01장 6절 |
| SI-06-024 | CI 품질 게이트: lint, tsc, build, Lighthouse 예산, `check-assets`, `check-budget`, `check-repo`(중첩 .git, LFS, dist-only) | `.github/workflows/website-floria.yml`, `scripts/check-budget.mjs`, `scripts/check-repo.mjs` | 001, 007 | P0 | M | Opus | LCP ≤ 2.5s, 첫 화면 전송 ≤ 2MB. 영상 10MB 초과, `autoplay`+`preload="auto"`, 외부 CDN 문자열, 중첩 `.git` 발견 시 실패. 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 초과와 정지 이미지 150KB 초과 시 실패, 위젯·3D의 외부 모델/이미지 요청 0. 인증 금지 문자열 검사(쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈 밖의 `AUTH_MODE` 참조) 0건, `AUTH_MODE=mock VERCEL_ENV=production npm run build` 실패 확인 | 리뷰 #1, #2, #3, #5, #6, #8, 5장 #15, HERO_3D 2절, `AUTH_ROADMAP.md` 2.4절, 9장 |
| SI-06-025 | e2e: 뷰포트 4종, 링크 크롤, 문의/구독 폼 흐름, JSON-LD 검증, 상담 흐름 | `tests/e2e/` | 008, 009, 010, 011, 014, 015, 016, 017, 019, 020, 045, 046 | P0 | M | Opus | 375/768/1024/1440px에서 scrollWidth ≤ clientWidth(상담 패널 연 상태 포함). 내부 링크 404 0건. 문의 제출→접수번호, 4번째 제출 429. 구독 확인 흐름 통과. 상담 1턴(목 제공자) → 문의 전환 → 접수번호(`source_path` `/consult`), 쿠키 없는 컨텍스트에서 대화 이어 쓰기 404, 스위치 off면 위젯 DOM 없음, 3D 4상태(풀, 모바일 단순판, 정지 이미지, reduced-motion) 렌더 확인. 콘솔 흐름은 Mock 페르소나 storageState로 실행(`globalSetup`이 `/api/dev/login`으로 `owner`·`site_pending`·`viewer` 상태 저장): owner 문의 상태 변경, site_pending 안내만, viewer 문의 거부 | 리뷰 #4, #7, 5장 #3, `AUTH_ROADMAP.md` 2.1절 |
| SI-06-026 | API·가드 통합 테스트(Vitest+로컬 Supabase) | `tests/api/` | 016, 017, 019, 037 | P0 | M | Opus | 04장 오류 표의 모든 코드 재현(2.2절 AI 코드: `ai_disabled`, `ai_turn_limit`, `ai_rate_limited`, `ai_budget_exhausted`, `voice_notice_required`, `consent_version_mismatch` 포함). 허니팟은 200이지만 행 0. 콘솔 권한(viewer/member/owner) 매트릭스 | 04장 7절 |
| SI-06-027 | pg_cron 등록, 퍼지 런북 | `supabase/ops/` | 003 | P1 | S | Opus | 매일 03:30 KST `purge_expired` 등록. 같은 스케줄에 30일 지난 방문자 상담 대화(`ai_conversations`, 메시지는 cascade)와 만료 `voice_sessions` 정리 등록(코어 요청 12 전까지 직접 DELETE). 만료 데이터 0건 확인 쿼리 | SI-F-021, 01장 5장 상담 기록 보존 |
| SI-06-028 | 사이트 등록 스크립트와 초대 온보딩 절차 | `scripts/provision-site.mjs`, `docs-ops/ONBOARDING.md`(앱 내부 운영 문서) | 003 | P0 | S | Opus | 초대(`inviteUserByEmail`) → service_role 엔타이틀먼트 부트스트랩 → `provision_site` → 콘솔에 사이트 표시. Stage A에서는 로컬 초대로 만든 사용자와 시드 페르소나 로그인으로 확인하고, 초대 메일 링크 → 비밀번호 설정 → 로그인 실경로는 SI-06-049(Stage B)에서 확인. 엔타이틀먼트 없는 조직은 거부 | SI-F-020, `AUTH_ROADMAP.md` 2.5절 |
| SI-06-029 | 원본 정리와 아카이브: Floria_Neo 카피 추출 후 보관, `.vite` 캐시, Biz_Website dist 보관, Lucury 저장소 경계 결정 절차 | `archive/`(저장소 루트), 07장 절차 | 006 | P1 | S | Opus | `archive/WebSite-*`에 원본 이동 계획서 작성, 중첩 `.git` 처리 방식(서브모듈 또는 제거) 결정 기록. 실행은 사용자 승인 후(git 쓰기 포함) | 리뷰 #5, #8, #34, 5장 #5 |
| SI-06-030 | 연계: Lucury 영상 1080p 트랜스코딩, 프레임 WebP 재추출·점진 로드, 저장소 경계 | 별도 저장소 `Lucury Website`(이 앱 밖) | 016 | P2 | L | Opus | 초기 전송 10MB 이하, 프레임 총합 4MB 이하, 로더 없이 첫 프레임 표시, CTA를 폼 백엔드로 연결 | 리뷰 #1, #2, 5장 #1, #5, #6 |
| SI-06-031 | 연계: Flora Sentiment(NEO_02) 라우팅 보강, 코드 정리, 폼 백엔드 연결 | 별도 저장소 `Floria_NEO_02`(이 앱 밖) | 016 | P2 | M | Opus | 미정의 라우트 0, `*` NotFound, `vercel.json` rewrites, 폼 3곳이 `/api/inquiries` 호출 | 리뷰 #7, #24, 5장 #10, #13 |
| SI-06-032 | 연계: Biz_Website 소스 복원 또는 재구현 결정·실행 | 별도 저장소 | 029 | P2 | L | Opus | 원본 `platform-website` 탐색 결과 기록. 없으면 dist를 레퍼런스로 재구현하고 `src/` 커밋 | 리뷰 #5, 5장 #4 |
| SI-06-033 | 디자인 시스템 1단계: 레퍼런스 확정(공개 사이트 DESIGN_PRINCIPLES + HERO_3D, 콘솔 Primer, 위젯 구조 Astryx 패턴 확인), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.7절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. 공개 사이트에 B2B 레퍼런스를 적용하지 않는다는 점 명시. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D-17). 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/nomad-design-modules/_design-guide/REFERENCES.md:267` website-floria 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/nomad-design-modules/_design-guide/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| SI-06-034 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | 005 | P0 | M | 사람(보조 Sonnet) | 03장 3.7절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 라이트 토큰 초안 확정, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| SI-06-035 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | 034 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| SI-06-036 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, site 설정(app, 컬렉션 이름), JWKS 검증(방문자 `sub`), 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/site/`, `app/ai/compliance/site.py`, `app/ai/products/site/knowledge.py`, `wiki_config.py` 제외), `apps/api/tests/platform/` | 003 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 컬렉션 요청 거부, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 방문자 토큰이 허용 scope 밖(`graph:site.consult` 외 그래프, `rag` 쓰기) 요청 시 거부, 필수 변수 누락 시 기동 실패 | 02장 2.1·5절, AI_ARCHITECTURE 2·4·8장 |
| SI-06-037 | AI 게이트(방문자): `GET /api/ai/config`, 대화 생성(Turnstile, 방문자 쿠키), 채팅 중계(Dify, 장애 시 FastAPI 직접), 서명 토큰 발급, 입력 마스킹, 레이트 리밋 5종·사이트 일일 상한, 대화 조회·종료·삭제 | `src/app/api/ai/`, `src/server/ai/` | 002, 003, 016, 036 | P0 | L | Fable | 04장 2.2절 계약 충족. 쿠키 없거나 다른 쿠키로 대화 이어 쓰기 404, 11번째 턴 409, 방문자 11번째/시간 429, 사이트 상한 도달 후 새 턴 429 + 문의 안내, 마스킹 후 전화·이메일·주민번호 형식이 로그·DB·FastAPI 요청에 0, 스위치 off 시 404, Dify 차단 시 `/tools/answer-direct`로 응답, 개인키·service_role 키가 클라이언트 번들에 0, 원문 IP 저장 0, 상담이 `site.*`에 쓴 행 0, 모든 호출이 `ai_usage`에 운영자 조직 행으로 남는다 | 01장 SI-F-022, 028, AI_ARCHITECTURE 2.3 |
| SI-06-038 | 콘솔 AI 설정: `/admin/ai`(스위치, 국외 이전 동의, 사용량, 미답변 질문)와 관리 API | `src/app/(console)/admin/ai/`, `src/app/api/admin/ai/` | 019, 035, 037 | P0 | M | Opus | owner/admin만 변경, member 읽기 전용, viewer 거부. 동의 시 `ai_org_settings.cross_border_notice`와 고지문 버전 일치, 철회 직후 다음 요청부터 상용 0. 스위치 변경 감사 1행(`site.ai_settings`). 색인 문서 0건이면 켜기 전 확인 대화상자. 사용량은 제공자·기능별 집계, 미답변 질문은 마스킹본만 | 01장 SI-F-027 |
| SI-06-039 | 지식 원고: 시공 사례·식물 정보·FAQ와 금지 규칙 파일(`banned.json`, `claims`·`business`에서 생성) | `content/knowledge/` | 006 | P0 | L | Sonnet | 원고 메타데이터(작성자, 검수일, `verified`, 사례는 `consent_ref`)가 없으면 린트 실패. 고객 식별정보(이름, 연락처, 정확한 주소) 0, 금지 문구 검사 0, `verified:false` 항목 0, 분량 사례 5·식물 20·FAQ 30(제안, 운영자 제공 자료 기준). 운영자 검수 기록(01장 D-11) | 01장 SI-F-023, 029 |
| SI-06-040 | RAG 색인과 평가: 사이트 조직 컬렉션(`floria-knowledge`, `floria-wiki`, oss-embed), 색인 스크립트, 검색 평가셋 30문항 | `apps/api/app/ai/products/site/knowledge.py`, `scripts/knowledge/`, `apps/api/tests/site/retrieval/` | 036, 039 | P0 | M | Opus | 재현율@6 0.8 이상(제안), 다른 조직 컬렉션 검색 거부(42501), `verified:false`·`consent_ref` 없는 사례를 색인하면 스크립트가 실패, 컬렉션당 임베딩 모델 1종, 10분 넘은 `indexing` 문서를 `failed`로 돌림 | 01장 SI-F-023 |
| SI-06-041 | 지식·위키 운영: 지식 → 위키 ingest(draft), `/admin/knowledge`, `/admin/wiki` 화면과 API, 주 1회 lint(워커 트리거) | `apps/api/app/ai/products/site/wiki_config.py`, `src/app/(console)/admin/knowledge/`, `src/app/(console)/admin/wiki/`, `src/app/api/admin/knowledge/`, `src/app/api/admin/wiki/`, `src/app/api/internal/`, `worker/notify/lint-tick.ts`(018이 호출 1줄 등록) | 019, 035, 037, 040 | P0 | M | Opus | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 표시가 붙은 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, lint 결과 화면 표시, 쓰기마다 감사 1행, 워커 키 없는 `/api/internal/wiki-lint` 401 | 01장 SI-F-024, LLM_WIKI 3장 |
| SI-06-042 | 공개 지식 페이지 `/guide`(목록, 검색, 페이지, 출처, 관련) | `src/app/(site)/guide/` | 035, 041 | P1 | M | Sonnet | `published`만 노출(draft 0), "AI가 정리하고 운영자가 검수한 문서" 표시, Lighthouse 접근성 95, 금지 문구 0, `aggregateRating`·`555` 0, 모든 내부 링크 200, sitemap에 포함 | 01장 SI-F-024, D-16 |
| SI-06-043 | LangGraph 그래프 `site.consult`(question → retrieve → answer → inquiry → compliance), 체크포인트, 실행 기록, 평가셋 | `apps/api/app/ai/graphs/site_consult.py`, `apps/api/app/ai/compliance/site.py`, `apps/api/tests/site/graph/` | 036, 039, 040 | P0 | L | Opus | 1턴 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 근거가 없으면 `answer` 모델 호출 0(`no_source`), `inquiry_hint`만 만들고 DB 쓰기 0, 금지 규칙 평가셋 40문항 위반 0, 인젝션 문장 10개에서 시스템 지시 노출·범위 밖 응답 0, `compliance` 2회 실패 시 정형 안전 응답, 상용·오픈소스 경로 모두 평가셋 통과 | 01장 SI-F-025, 029 |
| SI-06-044 | Dify `site-chat`(분류 노드, HTTP 노드)과 `/tools/answer` site 확장(대화 매핑 검증, 모드 consult, 인용 기록), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/site/`, `apps/api/tests/site/chat/` | 037, 040, 043 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 답변 출처 1개 이상 또는 `no_source`, `off_topic` 분기 고정 답변, 평가셋 30문항 금지 문구 0, DSL에 키 0, 응답이 04장 6.2절 JSON 형식 | 01장 SI-F-022, 025, 04장 6.2절 |
| SI-06-045 | 상담 위젯: 패널, 메시지 스레드, 출처 칩, 고지·입력 안내, 문의 전환 버튼, 대화 지우기 | `src/components/ai-consult/` | 035, 037 | P0 | M | Sonnet | 03장 3.6절 구성, 375px 전체 화면 시트, `aria-live`, ESC·포커스 이동, 한도·상한·실패·근거 없음 상태 표시, 스위치 off 시 DOM 없음, 문의 버튼이 `/contact?from=consult`로 이동하고 초안은 sessionStorage에만 둔다. 마운트는 011 파일에 1줄 요청 | 01장 SI-F-022, 03장 5절 |
| SI-06-046 | 방문자 음성 상담: `/api/voice/*`(sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기 | `src/app/api/voice/`, `src/components/voice/` | 037, 045 | P0 | M | Opus | 고지 미확인 STT 403, 30초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 상담 정상, 방문자 STT 5회/시간 초과 429, TTS 입력은 DB 메시지만·500자 초과 422, 음성 스위치 off 시 404, 음성은 상담이 켜져 있을 때만 | 01장 SI-F-026 |
| SI-06-047 | 3D 히어로: 온실 구조물(PC·태블릿 풀 3D, 모바일 단순판, 정지 이미지 대체, 성능 예산) | `src/components/hero3d/`, `public/hero/` | 035, 008 | P0 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 금색·잎 일러스트 패턴·별 파티클 0, 연출은 로드 때 1회 약 3초. 장착은 008 파일에 1줄 요청 | 01장 SI-F-030, 03장 4.8절 |
| SI-06-048 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 방문자 쿠키 결합, 국외 동의 필터, 강제 오픈소스, 방문자 한도·사이트 상한, 라우팅 seed 스냅샷) | `apps/api/tests/site/security/`, `tests/ai/`, `scripts/ai-routing/` | 036, 037, 043, 044, 046 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 8행 × 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 쿠키 없는/다른 쿠키 대화 이어 쓰기 404, 미동의 조직 상용 호출 0(상담·음성·임베딩·위키), 한도 초과 429, 스위치 off 404, 상담이 `site.inquiries`에 쓴 행 0, 모든 호출 `ai_usage` 기록, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |

작업 수 49(2026-10-14 인증 단계 B 1개 추가, C1·C2는 제외 제품이라 없음, 8절). 테스트 대응: 049 → `tests/auth/`(자체 콜백 단위 테스트)·025(Mock E2E 계속 녹색)·수동 점검표(B-5), SI-06-002/003 → 026·004, 005~012 → 025·024, 014/015 → 025, 016/017 → 026, 019/020 → 004·026, 023 → 법무 체크리스트, 028 → 026. AI·음성·3D(2026-10-13): 036 → 048, 037 → 026·048, 038 → 026, 039 → 040, 040 → 043, 041 → 026, 042 → 025, 043·044 → 평가셋·048, 045 → 025, 046 → 048, 047 → 024·025, 033~035 → 디자인 시스템 4단계 검증.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 033 | 2 | 없음 | 빌드되는 빈 앱, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 002, 003, 006, 007 | 4 | W0 완료 | CSP/환경변수, DB 적용+타입(AI 스위치·라우팅 8행 포함), 콘텐츠 데이터, 자산 파이프라인 |
| W1-D | 005 → 034 → 035(직렬) | 1 | 001, 033 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 004, 008, 009, 010, 011, 016, 017, 019, 023, 024, 027, 028, 036, 039 | 14 | W1 완료, 화면은 035 | RLS 테스트, 섹션, 라우트, 공개 API, 콘솔 가드, 법적 문구·고지문, 게이트, AI 서비스 설치, 지식 원고 |
| W3 | 012, 013, 014, 015, 018, 020, 021, 022, 029, 037, 040, 047 | 12 | W2 해당 선행 완료 | SEO, 접근성, 폼 UI, 알림, 콘솔 화면, 아카이브 계획, AI 게이트, RAG 색인, 3D 히어로 |
| W4 | 026, 038, 041, 043, 045 | 5 | W3 해당 선행 완료 | 통합 테스트, 콘솔 AI 설정, 위키 운영, 상담 그래프, 상담 위젯 |
| W5 | 042, 044, 046 | 3 | W4 해당 선행 완료 | 공개 지식 페이지, Dify 채팅, 음성 상담 |
| W6 | 049(G1 통과 후 먼저), 025, 048 | 3 | W5 완료. 049는 G1(`AUTH_ROADMAP.md` 4장), 025·048은 049 완료 후 마감 | 인증 Stage B(Google + 초대 메일), e2e 전체, AI 보안 회귀. **MVP 출시(공개 베타) 조건** |
| W7 | 030, 031, 032 | 3 | MVP 출시 후 | 연계 사이트(P2). 인증 C1·C2는 제외라 G2 후 작업 없음 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 6 | 12.5% | 13 / 87 = 14.9% |
| Opus | 23 | 47.9% | 42 / 87 = 48.3% |
| Sonnet | 18 | 37.5% | 31 / 87 = 35.6% |
| Haiku | 1 | 2.1% | 1 / 87 = 1.1% |

비율은 모델 작업 48개 기준이다. 사람 작업 1개(SI-06-034, M)는 비율에서 뺐다. 2026-10-14 인증 B(SI-06-049, Fable M) 추가 전(모델 47개)은 Fable 10.6%, Opus 48.9%, Sonnet 38.3%, Haiku 2.1%였다. 2026-10-13 이전(32개)은 Fable 6.3%, Opus 50.0%, Sonnet 40.6%, Haiku 3.1%였다.

Opus가 큰 이유: 이 제품의 비 UI 작업이 API, 게이트, 그래프, RAG, 테스트, 연계 사이트 L 작업이기 때문이다. Fable은 권한·RLS(004, 019 인증 Stage A, 049 인증 Stage B)와 AI 보안 경계(서명 토큰 검증 036, AI 게이트의 쿠키 결합·한도·마스킹 037, AI 회귀 048)를 맡는다. 그래프·RAG·Dify·음성·위키 운영 구현은 Opus, 상담 위젯·공개 지식 페이지·3D 히어로·지식 원고는 Sonnet이다(`docs/products/_platform-core/DOC_TEMPLATE.md:253`).

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
| 3 | `apps.signup_policy='invite'` 강제(가입 시 초대 테이블 검증) | 해결(2026-10-13 코어 반영 완료): invite 앱은 가입 트리거가 엔타이틀먼트를 만들지 않고 `bootstrap_app_for_org`는 비 service 호출자에 42501 |
| 4 | 메일 발송 공용 모듈(확인/알림 메일) 필요 여부 | 현재 `SHARED_MODULES.md` 16개에 없음. 사업자 확정(D-6) 후 제품 로컬로 둘지 결정 |
| 5 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가(금액 불일치 시 failed 주문 기록). 이 제품은 결제가 없어 해당 없음 | `DB_CONVENTIONS.md:296` |
| 6 | ai-gateway: 비로그인 방문자 상담 공용 규약. 방문자 쿠키 발급·`visitor_key` 해시 규칙, 토큰 `sub=visitor:<key>` 발급, 레이트 리밋 키 규약, 크레딧 없는 모드(선차감·정산 생략, `ai_usage.settled_at`을 기록 시점에 채움), 사이트 일일 상한 훅을 `packages/ai-gateway`에 추가 | `AI_ARCHITECTURE.md:54-56`, `:130`은 방향만 있고 구현 규약이 없다. 그때까지 `src/server/ai/`(SI-06-037)에 구현 |
| 7 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게. 그때까지 `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| 8 | core-voice: `VoiceAdapter` ctx에 `visitorKey`(userId 없음)와 길이·횟수 상한 옵션을 명시 | `0009_core_voice.sql`은 방문자 소유를 지원(`voice_sessions.visitor_key`)하지만 TS 계약에는 `userId?`만 있다. 그때까지 Route Handler가 한도를 강제 |
| 9 | ai-service: (a) `/tools/answer`·`/tools/answer-direct`에서 제품 그래프를 동기 실행하는 훅 (b) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키(`dify.aux`)로 해석 (c) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md:149-158` 목록에 없음) | Dify 보조 노드 라우팅과 관리자 위키 편집. 그때까지 (a) site 확장 `app/ai/tools/site/` (b) Dify에 기능별 모델 이름을 따로 등록 (c) `wiki_config.py`에 임시 구현 |
| 10 | 공용 Dify: `site-chat` 앱 생성, 내부 키 환경 변수, 로그 보존 30일 | 공용 인프라는 코어 소유. 없으면 상담은 FastAPI 직접 경로(`/tools/answer-direct`)로만 동작 |
| 11 | `ai_usage`·`ai_org_settings` 읽기: 크레딧 없는 앱의 조직 멤버 조회 허용 범위(원가 지표 집계)와 `settled_at` 의미를 코어 문서에 명시 | 이 제품의 `/admin/ai` 사용량 화면이 의존. `0003`의 `ai_usage_select`(조직 멤버)를 사용 중이며 문서화만 요청 |
| 12 | `core.purge_ai_conversations(app_id, days)`(service_role): 방문자 대화 보존 정리와 감사 기록 | 앱이 `core.ai_conversations`를 직접 DELETE하지 않게. 그때까지 SI-06-027이 스케줄에서 직접 DELETE |

## 7. 완료 정의

| 조건 | 기준 |
|---|---|
| 빌드/타입/린트 | `npm run build`, `tsc --noEmit`, `npm run lint` 통과 |
| SQL | 문서 폴더 체커 OK(모놀리스, 모듈러), RLS 스모크 통과(SI-06-004) |
| 게이트 | SI-06-024의 예산·자산·리포 검사 통과 |
| e2e | SI-06-025 통과 |
| 결제 E2E | 해당 없음(결제 없음) |
| AI·음성 | `pytest apps/api` 통과, SI-06-048 녹색, 그래프 평가셋(금지 규칙 40문항·인젝션 10문장)을 상용·오픈소스 경로 모두 통과, 대화 평가셋 30문항 금지 문구 0, 검색 평가셋 재현율@6 0.8 이상, 상담이 `site.*`에 쓴 행 0 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(SI-06-035) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 법무 | 01장 6절 법무 확인 체크리스트 완료(AI·음성 개인정보와 대화 규칙 포함), 열린 결정 D-1~D-3, D-6, D-7, D-10~D-12, D-14 확정 |
| 작업 | 06장 2절 P0 전부 완료(W0~W6), 8절 인증 Stage B(SI-06-049, P0, 테스트 `tests/auth/`·025·수동 점검표)와 G1 `[DECISION]` 포함. P1은 출시 후 2주 안. P2(W7)는 별도 일정 |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md` 9장. 이 제품은 8장 매트릭스에서 C1·C2가 "제외"라 C 작업을 만들지 않는다(01장 8.1절: 운영자 전용 콘솔, 초대 메일+Google로 충분). 기존 인증 작업 SI-06-019는 Stage A로 범위를 바꿨고(2절 행), 새 작업은 B 1개다.

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| SI-06-049 | Stage B: Google OAuth 전환 + 초대 메일 화면. `/admin/login`의 "Google로 계속하기"·이메일 폼, 초대 메일 수락(비밀번호 설정)·비밀번호 재설정 화면, `/auth/callback`(`finishLogin` 3.2절 전체, invite 앱이라 `bootstrap_app_for_org` 호출 없음), `/admin/no-access` 안내, 배포 체크리스트(Google·Supabase 대시보드·`AUTH_PROVIDERS=google,email`) | `src/lib/auth/oauth/`, `src/app/(console)/admin/(auth)/login/providers/`(019 소유 폴더의 하위, 019 완료 후 이어 받음), `src/app/(console)/admin/(auth)/accept-invite/`, `src/app/(console)/admin/(auth)/reset-password/`, `src/app/auth/callback/`, `tests/auth/`, `docs-ops/AUTH_DEPLOY_CHECKLIST.md`. 변경 요청: `supabase/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`(003), `docs-ops/ONBOARDING.md` 초대 절차 문구(028), `/admin/no-access`의 "초대받은 이메일로 로그인하세요" 문구(019, 1줄 요청) | 019, 028, 035, 그리고 G1 | P0 | M | Fable | `AUTH_ROADMAP.md` 5.3절 그대로: B-1 새 Google 계정 첫 로그인 → invite 앱이므로 `entitled=false`이고 `/admin/no-access`(초대받은 이메일과 같은 Google 계정은 기존 사용자로 로그인되어 콘솔 진입, 크레딧 원장 행 0 유지). B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → `/admin`. B-3 `code` 없음·재사용·만료 → `/admin/login?error=callback`, 서버 오류 로그에 토큰·코드 없음. B-4 배포 빌드(`VERCEL_ENV=production`)에서 `/api/dev/login` 404, 로그인 화면에 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(SI-06-025 콘솔 흐름) 계속 녹색, Google 실로그인은 사람이 수동 점검표(데스크톱·모바일 각 1회, 초대받은 계정·초대받지 않은 계정)로 확인하고 task `log.md`에 기록. B-6 운영 대시보드 Google 설정, Redirect URLs, `AUTH_PROVIDERS` 값이 배포 체크리스트와 일치. 제품 추가: 초대 메일 링크 → 비밀번호 설정 → 로그인 → `site_pending`과 같은 안내 → `provision_site` 후 문의 목록(SI-06-028 실경로), 공개 사이트·상담 위젯에 로그인 버튼 0 | `AUTH_ROADMAP.md` 5장, 3.2절, 9장, 01장 SI-F-020 |

| 항목 | 내용 |
|---|---|
| 게이트 G1 | `AUTH_ROADMAP.md` 4장 6개 조건. 이 제품 해석: (1) W0~W5 P0 완료(049·025·048 제외) (2) 핵심 플로우 E2E(문의 접수, 구독, 상담 → 문의 전환, 콘솔 문의 처리) Mock 페르소나로 녹색 (3) SI-06-004 RLS 스모크와 `outsider` 거부 (4) 결제 E2E 해당 없음 (5) 단계 분기 코드가 인증 모듈 밖 0건(SI-06-024) (6) Google Cloud 프로젝트·OAuth 동의 화면(개인정보처리방침 `/privacy` URL 포함)·웹 클라이언트·운영 Supabase 프로젝트 준비. 판정은 사람이 하고 task `log.md`에 `[DECISION] G1 통과` |
| 웨이브 | 049는 W6(마지막 기능 웨이브 W5 다음, 공개 베타 직전 통합·E2E 웨이브)의 맨 앞. 025·048은 049 완료 후 마감한다(3절 W6 행) |
| 게이트 G2와 C | 해당 없음. C1 카카오·C2 네이버는 제외라 G2 이후 작업이 없다. 재검토 조건은 01장 D-21 |
| Stage A 웨이브 | SI-06-019는 W2 그대로. 그보다 앞 웨이브(W0~W1, 003의 DB 적용)는 시드 스크립트 없이 SQL·단위 테스트로 검증한다(`AUTH_ROADMAP.md` 9장 A 작업 행) |
| 환경 검증 위치 | 인증 env zod 검증은 `src/lib/auth/`(019)가 하고 `src/lib/env.ts`(002)에는 호출 1줄을 요청한다(1절 공유 파일 규칙) |
| 공용 모듈 요청 | 없음. 브리지 경로를 쓰지 않으므로 `staged/0010_core_auth_identity_links.sql` 적용 요청도 없다 |

인증 단계 반영으로 생긴 문서 간 정리(기존 줄은 그대로 두고 여기에 기록):

| 위치 | 내용 |
|---|---|
| 2절 SI-06-025 선행 | 콘솔 흐름을 Mock storageState로 돌리므로 019, 020을 선행에 더했다(W6라 웨이브 변화 없음) |
| 2절 SI-06-019 소유 | `src/app/(console)/admin/(auth)/`에서 `login/`(`providers/` 제외)과 `no-access/`는 019가 갖는다(`no_app` 페르소나가 A단계에서 `/admin/no-access`를 쓰므로). `login/providers/`는 019 소유 폴더의 하위라 019 완료 뒤 049가 이어 받고(W2 → W6 직렬), `accept-invite/`·`reset-password/`는 049가 새로 만든다. `/admin/no-access` 문구 추가는 049가 019 파일에 1줄 요청 |
| 05장 8장 "가입" 행 | 모놀리스 자동 엔타이틀먼트는 invite 강제 이전 스모크 기록이다. 현재 기대값은 05장 10절(`no_app` 두 형태 모두 `entitled=false`) |
