# 02 아키텍처: Floria (website-floria)

작성일 2026-10-12. 모든 버전은 리뷰가 확인한 원본 버전 또는 제안이다. 제안은 이유를 적었다.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 프레임워크 | Next.js App Router | 16 | `docs/products/00_MERGE_ANALYSIS.md:1089`(platform-core Next.js 16 + Supabase 권고). 서버 Route Handler에 service_role을 두고 메타/JSON-LD를 서버에서 만들어야 해서 정적 SPA(Vite)를 쓰지 않는다(제안) |
| UI | React | 19.2 | `docs/reviews/WebSite.md:34`, `:66` |
| 언어 | TypeScript | 6.0 | `docs/reviews/WebSite.md:66`(NEO_02 설정 재사용). Botanic의 JSX는 TS로 전환(작업 12) |
| 스타일 | Tailwind CSS v4 `@theme` 토큰 | 4 | `docs/reviews/WebSite.md:67`. 인라인 style 객체 금지(`:185`) |
| 아이콘 | lucide-react(dependencies에 둔다) | 리뷰 확인 버전 | `docs/reviews/WebSite.md:36`, `:260` |
| 폰트 | Pretendard(본문), Gowun Batang(제목) self-host, `font-display: swap`, 가중치 합계 4개 이하 | 제안 | 리뷰 `:198`, `:250`(preconnect/self-host, 가중치 축소). 라이선스(OFL) 확인은 SI-06-005 수용 기준 |
| DB/인증 | Supabase(PostgreSQL 15, Auth) | 모듈러 `site` 스키마 또는 모놀리스 `public` | 05_DATA_MODEL.md |
| 이미지 | sharp로 빌드 전 WebP/AVIF 변환, `next/image` 대신 정적 `<picture>` 또는 `next/image` unoptimized 중 택일(구현 단계) | sharp | 리뷰 `:249`(`vite-imagetools` 또는 sharp). Next에서는 sharp |
| 검증 | zod | 최신 안정 | 경계 검증 규칙 `SECURITY_BASELINE.md:171` |
| 테스트 | Vitest(단위/통합), Playwright(e2e, 뷰포트, 링크 크롤), axe | 제안 | 원본의 Playwright 스크립트 5종을 정식 테스트로 전환(`docs/reviews/WebSite.md:38`, `:259`) |
| 호스팅 | Vercel(앱), Supabase(DB) | 제안 | 워커가 필요한 것은 알림 1개뿐이라 Railway 소형 프로세스 또는 Supabase 스케줄을 쓴다 |
| 패키지 관리 | lockfile 커밋, `latest` 태그 금지 | - | `SECURITY_BASELINE.md:210` |

AI(LLM, 이미지 생성) 레이어는 없다.

## 2. 모듈 경계

앱은 `apps/website-floria/`(제안: 모노레포 안, 중첩 `.git` 금지)에 둔다. 06장 소유 파일 경계의 기준이 되는 디렉터리 분할이다.

| 모듈 | 디렉터리 | 책임 | 의존 방향 |
|---|---|---|---|
| 콘텐츠 | `src/content/` | 카피, 컬렉션, 프로세스, 아카이브, 후기(동의 증빙 포함), 사업자 정보, 주장(`claims`)의 데이터와 타입. 외부 의존 없음 | 다른 모듈이 읽는다 |
| 디자인 토큰 | `src/styles/`, `public/fonts/` | CSS 변수, `@theme`, 폰트 선언 | 컴포넌트가 읽는다 |
| 공개 섹션 | `src/components/sections/` | Hero, Collections, Process, Archive, Ethos, Clarity(조건부), CTA | 콘텐츠, 토큰 |
| 레이아웃/라우트 | `src/components/layout/`, `src/lib/routes.ts` | Header, Footer, 라우트 레지스트리(링크의 단일 출처), NotFound | 섹션이 링크를 레지스트리에서만 만든다 |
| 공개 페이지 | `src/app/(site)/` | `/`, `/contact`, `/privacy`, `/newsletter/confirm`, `/newsletter/unsubscribe`, `not-found` | 위 모듈 |
| 폼 UI | `src/components/forms/` | 문의/뉴스레터 폼, 허니팟, 작성 시간 측정, Turnstile 위젯 | 공개 API만 호출 |
| 공개 API | `src/app/api/` | `/api/inquiries`, `/api/newsletter/*`, `/api/health` | `src/lib/forms`, `src/lib/newsletter`, `src/lib/supabase` |
| 폼 서버 로직 | `src/lib/forms/` | 입력 스키마(zod), Turnstile 검증, Origin 검사, IP 해시, 레이트 리밋 호출 | service_role 클라이언트 |
| 뉴스레터 서버 로직 | `src/lib/newsletter/`, `src/lib/mail/` | HMAC 토큰, 확인/해지 메일, 템플릿 | service_role 클라이언트 |
| Supabase 클라이언트 | `src/lib/supabase/` | 브라우저/서버/관리자 3종. 관리자 클라이언트는 서버 전용 | 환경변수 |
| 콘솔 | `src/app/(console)/admin/` | 로그인, 문의/구독자/설정 화면, 서버 가드 | 사용자 세션 클라이언트(RLS) |
| 인증 가드 | `src/lib/auth/` | `requireSession`, 사이트 등록 여부 게이트 | `core.session_context` |
| 알림 워커 | `worker/notify/` | 신규 문의 스캔, 메일 발송, `notified_at` 갱신 | service_role |
| 스크립트 | `scripts/` | 이미지 변환, 자산/예산/링크/리포 무결성 검사, 사이트 등록 CLI | CI |
| DB | `supabase/` | 마이그레이션(문서 폴더의 SQL을 복사), cron 등록 | - |
| 테스트 | `tests/e2e/`, `tests/api/`, `tests/rls/` | 06장 테스트 작업 | - |

핵심 규칙: 방문자 쓰기는 `src/app/api/` → service_role 클라이언트 → `site.*` RPC 한 줄기뿐이다. 브라우저에서 `supabase.rpc`로 쓰기 RPC를 직접 부르지 않는다(Turnstile과 IP 제한을 건너뛰기 때문이다). DB 쪽 `submit_inquiry`는 anon에게도 열려 있지만(05_DATA_MODEL.md 4장) 이는 방어 2선이다.

## 3. 공용 모듈 사용

`docs/products/_platform-core/SHARED_MODULES.md`의 16개 중 사용하는 것만 적었다. 재정의하지 않는다.

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 운영자 로그인, `session_context('site')` | `src/lib/auth/`, `proxy.ts` | 가입 폼은 두지 않는다. 초대 메일만 |
| org | 조직 멤버십, 역할(owner/admin/member/viewer) | RLS 헬퍼, 콘솔 | viewer는 문의를 읽지 못한다(05장) |
| audit | 상태 변경, 설정 변경, 삭제, 퍼지 기록 | RPC 안에서 `write_audit` | 개인정보 전문은 기록하지 않는다 |
| webhooks | 사용하지 않음(MVP). 메일 사업자 바운스/신고 수신은 Phase 2 | - | 사업자 확정(D-6) 뒤 `webhook_events` 사용 |
| storage | 사용하지 않음 | - | 이미지는 저장소 정적 자산. 업로드 기능이 없다 |
| 레이트 리밋 | `core.rate_limit_hit` | Route Handler(IP), RPC 내부(이메일/사이트) | 코어 모듈 표(`SHARED_MODULES.md`)에는 별도 항목이 없고 `CORE_SPEC.md` 12장이 정의한다 |
| credits, toss, oauth, llm gateway, fal, weasyprint, sns uploader, automation-core, compliance, jobs, affiliate | 사용하지 않음 | - | 이 제품에 해당 기능이 없다 |

## 4. 잡과 워커

`core.jobs`를 쓰지 않는다. 이유: 비동기 작업이 알림 메일 1종뿐이고 크레딧 선차감/환불이 없어, 잡 테이블의 재시도·환불 기능이 필요 없다.

| 항목 | 값 |
|---|---|
| job_type / 큐 | 해당 없음 |
| 알림 워커 | `worker/notify/` 단일 프로세스, 1분 주기 폴링. `select ... where notified_at is null and status='new' order by created_at limit 50` 후 발송, 성공 시 `notified_at = now()`. 부분 인덱스 `inquiries_notify_idx`가 이 조회를 받친다 |
| 재시도 | 발송 실패 시 `notified_at`을 그대로 두어 다음 주기에 재시도. 같은 문의가 5회 연속 실패하면 로그 경보(제안) |
| 중복 방지 | 단일 프로세스 + 발송 직후 갱신. 다중 인스턴스가 필요해지면 `SELECT ... FOR UPDATE SKIP LOCKED` 함수를 코어 요청 없이 `site` 스키마에 추가한다(Phase 2) |
| 스케줄 | `site.purge_expired()` 매일 03:30 KST(`30 18 * * *` UTC), pg_cron 또는 워커. `CRON_SECRET` 공개 라우트 방식은 쓰지 않는다(`SECURITY_BASELINE.md:208`) |
| 크레딧 | 없음 |

## 5. AI 라우팅

해당 없음. LLM, 이미지, 음성, 영상 제공자를 쓰지 않는다. 텍스트와 사진은 사람이 만든다(AI 생성 이미지를 쓰게 되면 01_PRD.md 6장 표기 규칙을 적용한다).

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 `docs/reviews/WebSite.md` 3장의 심각도 "높음"은 8건(#1~#8)이다. 이 표의 행도 8개다. 대상 프로젝트가 이 제품의 앱이 아닌 항목(Lucury, Biz_Website)은 "그 코드를 이식하지 않는다" + "같은 결함이 이 제품에서 재발하지 않게 하는 게이트"를 함께 적었다. 보안·데이터 결함은 높음 항목에 없다(05_DATA_MODEL.md 7장).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/WebSite.md` 3장 #1 | `Lucury Website/index.html:47-48`, `:270-271`(리뷰 `:182`) | 4K 영상 2개(112MB, 124MB)를 `autoplay preload="auto"`로 동시 로드, 초기 전송 약 236MB | 이식하지 않는다(07장). 이 제품은 영상을 쓰지 않는다. 영상이 필요해지면 (1) 1080p 4~6Mbps, 오디오 없음, 10MB 이하 (2) `poster` 필수 (3) `preload="metadata"` (4) 768px 이하에서 `<source>` 미삽입. 이를 `scripts/check-budget`가 빌드 산출물에서 강제한다(영상 파일 10MB 초과 또는 `autoplay`+`preload="auto"` 조합 발견 시 실패, 첫 화면 전송 2MB 초과 시 Lighthouse CI 실패) | 06장 SI-06-024(게이트), SI-06-030(Lucury 연계 재작업) |
| `docs/reviews/WebSite.md` 3장 #2 | `Lucury Website/js/main.js:227-250`(리뷰 `:183`) | 프레임 150장(23MB)을 전량 프리로드하고 완료 전까지 섹션을 로더로 가림 | 이식하지 않는다. 이 제품은 스크롤 프레임 시퀀스를 쓰지 않는다. 스크롤 연출을 도입할 때의 규칙: 초기 렌더를 이미지 프리로드로 막지 않는다(로더 화면 금지), 초기 10장 이하만 즉시 로드하고 나머지는 `requestIdleCallback`, 프레임 총합 4MB 이하(리뷰 권고 3~4MB). 위 예산 게이트가 동일하게 검사한다 | SI-06-024, SI-06-030 |
| `docs/reviews/WebSite.md` 3장 #3 | `Botanic_Architecture/floria/src/App.jsx:16-24,195` vs `public/`(리뷰 `:184`) | 참조하는 로컬 이미지 10개가 `public/`에 없어 히어로, 상품, 아카이브가 모두 깨짐 | (1) 이미지는 `public/images/**`에 WebP로 커밋하고 코드는 `content/` 데이터의 `asset` 키로만 참조한다 (2) `scripts/check-assets`가 빌드 전에 `content/`가 참조하는 모든 경로의 존재, 확장자, 용량(장당 300KB 이하, 제안)을 검사해 누락 시 빌드 실패 (3) `public/images/LICENSES.md`에 출처/라이선스 기록, 없으면 실패 (4) 실제 사진 확보 전에는 단색+그라데이션 플레이스홀더를 쓰되 `NEXT_PUBLIC_ALLOW_PLACEHOLDERS`가 꺼진 프로덕션 빌드에서는 실패 | SI-06-007, SI-06-024 |
| `docs/reviews/WebSite.md` 3장 #4 | `Botanic_Architecture/floria/src/App.jsx:241,421,567,571,646,817`, `index.css:96-110`(리뷰 `:185`) | 그리드가 인라인 `gridTemplateColumns` 고정값, 반응형 CSS는 어떤 요소에도 붙지 않은 데드코드 | (1) 인라인 `style`의 `grid*`/`width` 사용 금지(ESLint 규칙 `no-restricted-syntax`로 JSX `style` 속성의 grid 키 차단) (2) 레이아웃은 Tailwind 반응형 유틸(`grid-cols-1 md:grid-cols-3`)만 (3) Playwright가 375/768/1024/1440px에서 `document.documentElement.scrollWidth <= clientWidth`와 3열 그리드의 모바일 1열을 검증 | SI-06-008~010, SI-06-025 |
| `docs/reviews/WebSite.md` 3장 #5 | `Biz_Website/`(리뷰 `:186`) | 소스 없이 `dist/`와 `node_modules/`만 있고 둘 다 `.gitignore`라 리포에 흔적 0 | 이식하지 않는다(소스가 없다). 재발 방지: `scripts/check-repo`가 `apps/*`에서 `package.json`과 `src/`(또는 `app/`) 없이 `dist/`만 있는 디렉터리를 CI에서 실패시킨다. 이 폴더는 복원 결정(SI-06-032) 전까지 `archive/WebSite-Biz_Website/`로 옮기고 `dist/`를 저장소 밖 보관소에 별도 사본으로 둔다(07장 5절) | SI-06-024, SI-06-029, SI-06-032 |
| `docs/reviews/WebSite.md` 3장 #6 | `Floria_Neo/index.html:5`, `:41,46,106,141...`(리뷰 `:187`) | Tailwind Play CDN과 googleusercontent 임시 서명 URL 12개 | 코드는 이식하지 않고 카피만 추출한다(작업 6). (1) 응답 헤더 CSP를 `script-src 'self'`, `img-src 'self' data:`로 설정해 외부 CDN 스크립트와 이미지 핫링크를 브라우저에서 차단 (2) `check-assets`가 `content/`와 소스에서 `cdn.tailwindcss.com`, `googleusercontent.com`, `picsum.photos`, `unsplash.com` 문자열 발견 시 실패 | SI-06-002, SI-06-006, SI-06-024 |
| `docs/reviews/WebSite.md` 3장 #7 | `Floria_NEO_02/src/App.tsx:11-17`, `Header.tsx:9`, `Footer.tsx:19-31`(리뷰 `:188`) | 정의되지 않은 라우트 7개로 이동하면 레이아웃까지 사라진 빈 화면 | (1) 모든 내부 링크는 `src/lib/routes.ts` 레지스트리의 키로만 만든다(문자열 경로 직접 입력 금지, 린트로 강제) (2) `app/not-found.tsx`가 헤더/푸터를 유지한 404를 렌더 (3) `sitemap.xml`을 레지스트리에서 생성 (4) CI 링크 크롤이 모든 내부 링크의 HTTP 200을 확인, 아직 만들지 않은 페이지(Shop, Journal)는 GNB에 넣지 않는다 | SI-06-011, SI-06-025, SI-06-031(NEO_02 연계) |
| `docs/reviews/WebSite.md` 3장 #8 | `Lucury Website/.git/config`, `.gitattributes:1`(리뷰 `:189`) | 모노레포 안 중첩 git + LFS, 상위 리포에서 추적 불가 | 이 제품의 `apps/website-floria/`는 중첩 `.git`을 두지 않는다. `scripts/check-repo`가 저장소 루트를 제외한 `.git` 디렉터리/파일과 `.gitattributes`의 `filter=lfs` 발견 시 CI 실패. Lucury는 서브모듈 또는 별도 저장소로 결정(SI-06-029 절차)하고 영상은 저장소 밖(CDN/객체 스토리지)에 둔다. 이 기획은 git 쓰기 명령을 실행하지 않았다 | SI-06-024, SI-06-029 |

## 7. 배포 토폴로지

| 구성 | 배치 | 네트워크 경계 |
|---|---|---|
| 웹 앱(Next.js) | Vercel. 공개 페이지는 정적 생성(SSG), 콘솔과 API는 서버 | 브라우저 → Vercel. service_role 키는 Vercel 서버 환경변수에만 있다 |
| DB/Auth | Supabase 프로젝트. 모듈러는 통합 프로젝트, 모놀리스는 전용 프로젝트 | 브라우저는 anon 키로 콘솔(로그인 사용자)만 접근. 공개 쓰기는 항상 Route Handler 경유 |
| 알림 워커 | Railway 소형 프로세스(제안). 또는 Vercel Cron 대신 Supabase 스케줄. `CRON_SECRET` 공개 라우트는 금지 | 워커 → Supabase(service_role), 워커 → 메일 사업자 |
| 메일 | 사업자 미정(D-6) | 서버에서만 호출 |
| CAPTCHA | Turnstile(제안, 미확인) | 서버가 `siteverify`로 검증 |
| 렌더 서비스 | 없음(WeasyPrint 등 불필요) | - |
| 연계 사이트 | 정적 사이트가 폼 백엔드를 쓰려면 이 앱의 `/api/inquiries`를 호출한다(CORS는 `sites.allowed_origins` 허용 목록만, `*` 금지). 허용 목록 검사는 Route Handler가 한다 | `SECURITY_BASELINE.md:232`(CORS `*` 금지) |

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 동작 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase URL | 공개 | 기동 실패 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 콘솔 로그인/조회용 anon 키 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 공개 API/워커의 RPC 호출 | 서버 전용(`NEXT_PUBLIC_` 금지) | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | 코어 스키마 이름(`core` 또는 `public`) | 서버 | 기동 실패 |
| `SITE_DB_SCHEMA` | 제품 스키마(`site` 또는 `public`) | 서버 | 기동 실패 |
| `SITE_SLUG` | 이 배포가 서비스하는 사이트 slug(기본 `floria`) | 서버 | 기동 실패 |
| `NEXT_PUBLIC_SITE_URL` | canonical, sitemap, OG의 절대 URL | 공개 | 기동 실패(빈 값 불허) |
| `SITE_TOKEN_HMAC_KEY` | 확인/해지 토큰 서명 키(32바이트 이상) | 서버 전용 | 기동 실패. 0키/빈 키 폴백 금지(`SECURITY_BASELINE.md:116`) |
| `IP_HASH_SALT_SEED` | IP 해시용 일 단위 솔트의 시드 | 서버 전용 | 기동 실패 |
| `TURNSTILE_SECRET_KEY` | CAPTCHA 서버 검증(제안, 사업자 확정 전) | 서버 전용 | 프로덕션 기동 실패. 개발에서만 우회 플래그 허용, 프로덕션 빌드에서 우회 코드 제거(`SECURITY_BASELINE.md:184`) |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | 위젯 사이트 키 | 공개 | 프로덕션 기동 실패 |
| `MAIL_API_KEY`, `MAIL_FROM` | 확인/알림 메일(사업자 미정) | 서버 전용 | 뉴스레터/알림 기능 비활성이 아니라 기동 실패 |
| `NOTIFY_POLL_MS` | 알림 워커 폴링 주기(기본 60000) | 서버 | 기본값 사용 |
| `NEXT_PUBLIC_ALLOW_PLACEHOLDERS` | 이미지 플레이스홀더 허용(개발 전용) | 공개 | 프로덕션에서 true면 빌드 실패 |

`.env`, `.env.local`은 커밋하지 않는다. `latest` 태그를 쓰지 않는다(`SECURITY_BASELINE.md:119`, `:210`).
