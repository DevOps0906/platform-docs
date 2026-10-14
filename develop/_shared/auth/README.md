# 소셜 로그인 개발 지시서 (Google · 카카오 · 네이버, 공용 모듈)

작성일 2026-10-15. 로그인 "기획"은 이미 끝나 있습니다. 정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`(확정 결정 22)이고, 14개 제품이 각자 01~07장, `CLAUDE.md`, 개발 안내서 19장에 반영했습니다. 이 문서는 그 기획을 **실제로 만드는 방법**입니다. 외부 콘솔에서 무엇을 어떤 순서로 누르는지, 공용 모듈을 어떻게 나누는지, 다 만든 뒤 모든 제품에 어떻게 적용하는지를 적습니다. 화면·메뉴 이름은 2026-10-15에 공식 문서로 확인한 것이며, 콘솔 화면은 자주 바뀌므로 작업 직전에 링크를 한 번 더 엽니다. 확인하지 못한 값은 "미확인"으로 적습니다.

| 문서 | 무엇을 보나 |
|---|---|
| `docs/products/_platform-core/AUTH_ROADMAP.md` | 단계(A Mock → B Google → C 카카오·네이버), 게이트 G1·G2, Mock 가드, 콜백 공통 처리, 수용 기준(B-1~B-6, C1-1~C1-5, C2-1~C2-6), 제품 매트릭스 |
| 이 문서 | 외부 설정 절차와 공식 링크, 공용 모듈 구조, 테스트, 전체 제품 적용 절차 |
| 각 제품 `docs/file/01-관리/06_AGENT_PLAN.md` 8절 | 그 제품의 인증 작업 ID, 웨이브, 수용 기준 |
| 각 제품 개발 안내서 19장 | 그 제품의 단계별 실행 순서와 요청 프롬프트 |

## 1. 먼저 정할 것 (사람 결정 3개)

모듈러 통합 DB를 쓰는 제품 11개(admin-suite erp·sms 포함)는 Supabase 프로젝트 1개를 같이 씁니다(`docs/products/_supabase-modular/ARCHITECTURE.md` 3절). Supabase는 제공자 설정(Google 클라이언트 id, 카카오 REST 키, 네이버 커스텀 제공자)을 **프로젝트마다 1세트** 둡니다. 그래서 통합 DB 제품들은 Google 동의 화면, 카카오 앱, 네이버 애플리케이션을 하나씩 같이 씁니다. 지금 문서들은 이 점을 제품별 설정처럼 적어 두었으므로 아래 결정으로 확정합니다.

| ID | 결정 | 선택지 | 권고 | 시점 |
|---|---|---|---|---|
| AUTH-D1 | 통합 DB 제품의 로그인 브랜드 | (a) 통합 계정 "NOMAD 계정" 1개: Google·카카오·네이버 앱을 1세트만 만들고 동의 화면 이름은 상위 브랜드(예: NOMAD AI Factory). 제품 로그인 화면에는 제품 브랜드와 "NOMAD 계정으로 로그인" 안내 (b) 제품마다 Supabase 프로젝트를 나눠 동의 화면도 제품 이름으로 | **(a)**. 아키텍처가 이미 통합 DB로 정해져 있고, 검수(네이버)·비즈 앱 전환(카카오)·브랜드 확인(Google)을 한 번만 받으면 됩니다. 한 계정으로 여러 제품을 쓰게 되어 교차 판매(같은 사용자에게 다른 제품 권유)에도 유리합니다. 단독 프로젝트 제품(stock-dashboard, hms, 고객사별 모놀리스, arch-studio를 단독으로 낼 경우)만 자기 이름으로 따로 만듭니다 | 첫 제품 G1 전 |
| AUTH-D2 | 공용 모듈 배포 방식 | (a) 레퍼런스 제품 코드를 복사(vendor)하고 `CORE_AUTH_VERSION` 파일로 버전 표시 (b) 비공개 npm 패키지 `@nomad/core-auth`(GitHub Packages) (c) git submodule | v0.x(Stage A, 레퍼런스 1개 제품)는 (a), **v1.0부터 (b)**. 제품 저장소가 14개라 복사 방식은 곧 버전이 갈라집니다. submodule은 Vercel 빌드·에이전트 작업에서 실수가 잦아 권하지 않습니다 | v1.0 추출 때 |
| AUTH-D3 | 레퍼런스 제품 | (a) flora-publishing(open) (b) study-note(open) + website-floria(invite) | **(a)**. 대표님이 flora를 먼저 완성해 검토한 뒤 다른 제품에 적용하기로 했습니다. invite 정책은 두 번째 적용 제품(website-floria 또는 microweb-studio)에서 검증합니다 | 지금 |

AUTH-D1이 (a)로 정해지면 통합 프로젝트에 다음 두 가지가 추가로 필요합니다.

| 항목 | 내용 |
|---|---|
| 제공자 허용 검사 | 통합 프로젝트에서 켠 제공자는 그 프로젝트의 모든 앱에서 기술적으로 쓸 수 있습니다. 그래서 각 앱 콜백(`finishLogin`)은 이번 로그인의 제공자가 그 앱의 `AUTH_PROVIDERS`에 없으면 로그아웃 후 `/login?error=provider`로 보냅니다(공용 모듈 v1.0 기능, 4.2절) |
| 메일 링크 | Supabase의 Site URL은 프로젝트에 1개입니다. 가입 확인·비밀번호 재설정 메일 템플릿은 Site URL 대신 요청 때 넘긴 `redirectTo`(템플릿 변수 `{{ .RedirectTo }}`)를 써서 각 제품 도메인으로 돌아오게 합니다([Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates): `{{ .RedirectTo }}`, `{{ .TokenHash }}`, `{{ .SiteURL }}` 확인. 확인 링크는 `{{ .RedirectTo }}`에 `token_hash`를 붙이는 방식으로 짠다) |

## 2. 전체 흐름

| 순서 | 단계 | 무엇을 | 누가 | 끝나는 조건 |
|---|---|---|---|---|
| 1 | A | 레퍼런스 제품에서 Mock 로그인·시드·`finishLogin`을 만든다(공용 모듈 v0.x) | 에이전트 | 레퍼런스 제품 G1 |
| 2 | 추출 | 레퍼런스 제품의 `src/lib/auth/`를 `@nomad/core-auth` v1.0으로 꺼내고 계약 테스트를 붙인다 | 에이전트 + 사람 승인 | 레퍼런스 제품이 패키지로 바꿔도 E2E 녹색 |
| 3 | B | Google + 이메일(·초대 메일) 전환. 외부 설정은 사람이 하고(5장) 코드는 이미 패키지에 있다 | 사람 + 에이전트 | 레퍼런스 제품 공개 베타, G2 |
| 4 | 적용 | 나머지 제품은 패키지를 설치하고 제품 훅만 쓴다(9장) | 에이전트 | 제품별 G1 |
| 5 | C1, C2 | 카카오(v1.1), 네이버(v1.2)를 패키지에 추가하고 G2를 통과한 제품부터 켠다 | 사람 + 에이전트 | 제품별 C 수용 기준 |

공용 모듈이 완성되는 것과 제품의 단계 전환은 별개입니다. 패키지는 A·B·C 코드를 모두 갖고, 각 제품은 자기 G1·G2를 통과한 뒤 환경변수(`AUTH_MODE`, `AUTH_PROVIDERS`)로만 단계를 바꿉니다.

## 3. 공용 모듈 구성 (`@nomad/core-auth`, 제안)

계약은 `AUTH_ROADMAP.md` 3장과 `docs/products/_platform-core/SHARED_MODULES.md` 20장이 정본입니다. 아래는 파일 배치입니다.

| 경로 | 책임 | 단계 |
|---|---|---|
| `src/config.ts` | `getAuthConfig()`: 환경변수 zod 검증. `AUTH_MODE=mock`인데 Mock 허용 판정이 거짓이면 기동 실패, live에서 로그인 수단 0개면 기동 실패, 앱별 허용값 밖의 제공자면 기동 실패 | A |
| `src/mock/` | `isMockAuthAllowed()`, 개발용 로그인 Route Handler 팩토리, 개발용 패널·`MOCK AUTH · 로컬 전용` 배지(서버 컴포넌트) | A |
| `src/finish-login.ts` | 콜백 공통 처리(`AUTH_ROADMAP.md` 3.2절 1~6번), 제공자 허용 검사(1장), `next` 화이트리스트, 감사 `auth.login` | A(Mock이 같은 함수를 지난다), B에서 완성 |
| `src/callback.ts` | `/auth/callback` Route Handler 팩토리(PKCE `exchangeCodeForSession` → `finishLogin`) | B |
| `src/providers/google.ts`, `kakao.ts`, `naver.ts` | `signInWithOAuth` 옵션, 버튼 메타데이터(공식 디자인 가이드 색·문구) | B, C1, C2 |
| `src/naver-bridge/` | 브리지 경로(`AUTH_ROADMAP.md` 7.2.3절). 스파이크가 실패했을 때만 사용 | C2(조건부) |
| `src/link/` | 설정 → 로그인 방법: 연결(`linkIdentity`), 해제, 마지막 수단 해제 거부 | C |
| `src/ui/` | `LoginOptions`(`listLoginOptions` 결과를 버튼으로), 이메일 폼, 오류 문구(`error=callback`, `state`, `email_in_use`, `provider`, `no_profile`) | A~C |
| `scripts/seed-users.mjs` | 공통 페르소나 시드(`AUTH_ROADMAP.md` 2.2·2.3절). 제품 훅을 `--app`으로 불러온다 | A |
| `test/contract/` | 모든 제품이 그대로 돌리는 계약 테스트: Mock 가드 404, `next` 화이트리스트, 콜백 오류 경로, 제공자 허용 검사, 시드 멱등 | A~C |

제품이 주입하는 값(제품 쪽 파일 `src/lib/auth/index.ts` 1개):

| 값 | 설명 | 예 |
|---|---|---|
| `appId` | `core.apps.id` | `publishing` |
| `signupPolicy` | open · approval · invite | admin-suite erp는 approval |
| `allowedProviders` | 이 앱에서 허용하는 제공자 | hms는 `['email']` |
| `homePath(ctx)` | 역할별 기본 경로 | `/dashboard` |
| `firstLoginPath` | OAuth 첫 로그인 뒤 약관 단계 위치 | flora `/onboarding`, erp `/pending` |
| `resolveOrg(user)` | 어느 조직으로 `session_context`를 부를지(기본: 개인 조직) | admin-suite는 활성 기관 멤버십(02장 9.2절) |
| 시드 훅 | `scripts/dev/seed-users.<app>.mjs` | 05장 10절 페르소나 |

제품 쪽 얇은 파일은 `src/app/api/dev/login/route.ts`, `src/app/auth/callback/route.ts`, `src/app/(auth)/login/page.tsx` 세 개이고 모두 팩토리 re-export입니다. 이 세 곳과 `src/lib/auth/` 밖에서 `AUTH_MODE`·`AUTH_PROVIDERS`를 읽지 않습니다(CI 금지 검사).

## 4. Stage A 만드는 순서 (레퍼런스 제품)

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 로컬 Supabase: `supabase start` → `supabase db reset`. `config.toml`의 외부 제공자는 모두 `enabled = false`(`AUTH_ROADMAP.md` 3.4절) | Studio `http://127.0.0.1:54323`에서 `core.apps`에 앱 행 |
| 2 | `.env.local`: `AUTH_MODE=mock`, `DEV_SEED_PASSWORD=<긴 임의 값>`. 커밋 금지, `NEXT_PUBLIC_*` 금지 | Supabase URL이 원격이면 기동 실패하는지 |
| 3 | `src/config.ts`, `src/mock/`, `src/finish-login.ts` 작성 | 단위 테스트: 판정 4조건, `next` 6가지 |
| 4 | `scripts/seed-users.mjs --app <app>` | 두 번 실행해도 사용자 수·크레딧 원장 행 수가 같다 |
| 5 | `/login` 개발용 패널, 상단 배지 | 페르소나마다 기대 경로(제품 05장 10절) |
| 6 | Playwright `globalSetup`이 페르소나별 `storageState` 저장 | 핵심 플로우 E2E 녹색 |
| 7 | CI: 금지 문자열(쿠키·localStorage 역할, `mock-auth`, 인증 모듈 밖 `AUTH_MODE`), `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패 | CI 녹색 |

## 5. Stage B: Google 로그인

### 5.1 Google Cloud 설정 (사람, Google Auth Platform)

2025년부터 Google Cloud 콘솔의 OAuth 설정은 "Google Auth Platform" 메뉴(개요, 브랜딩, 대상, 데이터 액세스, 클라이언트, 인증 센터)로 바뀌었습니다.

| 순서 | 화면 | 할 일 | 링크 |
|---|---|---|---|
| 1 | 프로젝트 | 로그인 전용 프로젝트를 만든다(AUTH-D1 (a)면 1개, 예: `nomad-account-login`) | https://console.cloud.google.com/home/dashboard |
| 2 | 브랜딩 | 앱 이름(동의 화면에 보임), 지원 이메일, 로고, 홈페이지·개인정보처리방침·이용약관 URL, 승인된 도메인(통합이면 모든 제품 도메인) | https://console.cloud.google.com/auth/branding |
| 3 | 대상 | 사용자 유형 "외부". 게시 전("테스트")에는 등록한 테스트 사용자만 로그인됩니다 | https://console.cloud.google.com/auth/audience |
| 4 | 데이터 액세스 | 범위는 `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`만. 민감·제한 범위를 넣으면 긴 검증 대상이 됩니다 | https://console.cloud.google.com/auth/scopes |
| 5 | 클라이언트 | "웹 애플리케이션" 클라이언트 생성. 승인된 JavaScript 원본 = 각 제품 origin(로컬 `http://localhost:3000`은 운영 전에 지움), 승인된 리디렉션 URI = `https://<project-ref>.supabase.co/auth/v1/callback`과 로컬 `http://127.0.0.1:54321/auth/v1/callback`. 리디렉션 URI는 앱 도메인이 아니라 Supabase 콜백입니다 | https://console.cloud.google.com/auth/clients/create |
| 6 | 인증 센터 | 로고를 넣었으면 브랜드 확인을 신청(영업일 기준 며칠). 공개 베타 전에 "프로덕션"으로 게시 | https://console.cloud.google.com/auth/verification |

근거: [Supabase: Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google), [Google: Manage OAuth App Branding](https://support.google.com/cloud/answer/15549049), [Google: 브랜드 확인 제출](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification). 로그인 버튼 모양은 [Google 로그인 브랜딩 가이드](https://developers.google.com/identity/branding-guidelines)를 따릅니다.

### 5.2 Supabase 설정

| 순서 | 할 일 | 링크 |
|---|---|---|
| 1 | Authentication → Sign In / Providers → Google 사용, 클라이언트 ID·시크릿 입력 | https://supabase.com/dashboard/project/_/auth/providers?provider=Google |
| 2 | URL Configuration: Site URL(통합이면 대표 도메인), Redirect URLs에 각 제품 `https://<도메인>/auth/callback`과 미리보기 도메인을 명시 등록(와일드카드 지양) | https://supabase.com/docs/guides/auth/redirect-urls |
| 3 | 로컬 `supabase/config.toml`: `[auth.external.google]` `enabled = true`, `client_id = "env(GOOGLE_CLIENT_ID)"`, `secret = "env(GOOGLE_CLIENT_SECRET)"`, `skip_nonce_check = false`. `additional_redirect_urls`에 `http://localhost:3000/auth/callback` | [Supabase CLI config](https://supabase.com/docs/guides/local-development/cli/config) |
| 4 | (선택) 대시보드 대신 관리 API `PATCH /v1/projects/{ref}/config/auth`로 같은 값을 스크립트화 | https://supabase.com/docs/reference/api/v1-update-auth-service-config |
| 5 | (선택) 동의 화면에 `<ref>.supabase.co` 대신 우리 도메인이 보이게 하려면 커스텀 도메인(`auth.<도메인>`) | https://supabase.com/docs/guides/platform/custom-domains |

### 5.3 앱 코드 흐름

| 순서 | 처리 | 참고 |
|---|---|---|
| 1 | 버튼 → 서버 액션이 `signInWithOAuth({ provider: 'google', options: { redirectTo: <APP_URL>/auth/callback?next=..., queryParams: { prompt: 'select_account' } } })` | Google API를 따로 부를 일이 없으면 `access_type: 'offline'`은 넣지 않습니다 |
| 2 | `/auth/callback`: `exchangeCodeForSession(code)` → `finishLogin` | [서버 사이드 인증(Next.js)](https://supabase.com/docs/guides/auth/server-side/nextjs), [PKCE](https://supabase.com/docs/guides/auth/sessions/pkce-flow) |
| 3 | 첫 OAuth 로그인 → 약관 단계(`firstLoginPath`) → 제품 온보딩 | `AUTH_ROADMAP.md` 5.2절 |
| 4 | 같은 이메일의 이메일 가입자는 Supabase가 자동으로 같은 사용자에 연결(이메일 인증된 경우) | [Identity Linking](https://supabase.com/docs/guides/auth/auth-identity-linking) |

### 5.4 자주 나는 오류

| 증상 | 원인 | 조치 |
|---|---|---|
| `redirect_uri_mismatch` | Google 클라이언트의 리디렉션 URI에 Supabase 콜백이 없음(앱 `/auth/callback`을 넣은 경우가 많음) | 5.1절 5번 |
| 로그인 후 Site URL로 튐 | `redirectTo`가 Redirect URLs 목록에 없음 | 5.2절 2번 |
| "액세스 차단됨" | 동의 화면이 "테스트" 상태인데 테스트 사용자가 아님 | 테스트 사용자 추가 또는 게시 |
| `/login?error=callback` | 코드 재사용·만료, 다른 브라우저에서 콜백 | 정상 동작. 다시 로그인 |

## 6. Stage C1: 카카오 로그인

### 6.1 카카오 디벨로퍼스 설정 (사람)

| 순서 | 할 일 | 링크 |
|---|---|---|
| 1 | 앱 생성(아이콘, 이름, 회사명, 카테고리, 대표 도메인). AUTH-D1 (a)면 앱 1개 | https://developers.kakao.com/console/app |
| 2 | 앱 → 플랫폼 키 → REST API 키 = `client_id` | [앱 설정](https://developers.kakao.com/docs/ko/app-setting/app) |
| 3 | REST API 키 → 클라이언트 시크릿 활성화 = `client_secret`(REST API 키는 시크릿이 기본 포함이라 토큰 요청에 필요) | [클라이언트 시크릿](https://developers.kakao.com/docs/ko/app-setting/app#client-secret) |
| 4 | 카카오 로그인 리다이렉트 URI = `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://localhost:54321/auth/v1/callback`. 없으면 `KOE006` | [리다이렉트 URI](https://developers.kakao.com/docs/ko/app-setting/app#redirect-uri) |
| 5 | 카카오 로그인 → 사용 설정 → 상태 ON. 꺼져 있으면 `KOE004` | [설정하기](https://developers.kakao.com/docs/ko/kakaologin/prerequisite) |
| 6 | 동의항목: `profile_nickname`, `profile_image`, `account_email`. 설정하지 않은 항목을 요청하면 `KOE205` | [동의항목](https://developers.kakao.com/docs/ko/kakaologin/utilize#scope) |
| 7 | `account_email`은 비즈 앱에서만 받습니다. 앱 → 일반 → 비즈니스 정보에서 비즈 앱 전환(사업자 정보, 심사 영업일 3~5일). 사업자등록이 없으면 "개인 개발자 비즈 앱" 전환이 있습니다(2026-05 데브톡 기준, 이메일 항목 승인 여부는 미확인) | [비즈 앱 전환 안내(데브톡)](https://devtalk.kakao.com/t/topic/149739) |
| 8 | (선택) 개인정보 국외이전 항목, 대표 채널, 로그아웃 리다이렉트 URI | 같은 설정하기 문서 |

운영 주체인 디지털노마드연구소는 사업자(출판사) 등록이 있으므로 일반 비즈 앱 전환으로 이메일 필수 동의(각 제품 01장의 카카오 이메일 결정 (a))를 받는 것을 권합니다.

### 6.2 Supabase 설정

| 순서 | 할 일 | 링크 |
|---|---|---|
| 1 | Authentication → Sign In / Providers → Kakao 사용, REST API 키·시크릿 입력 | [Supabase: Login with Kakao](https://supabase.com/docs/guides/auth/social-login/auth-kakao) |
| 2 | 이메일을 받지 못하는 경우에만 "Allow users without an email"을 켭니다(이메일 결정 (b)일 때) | 같음 |
| 3 | 로컬 `[auth.external.kakao]` `enabled = true`, `client_id = "env(KAKAO_CLIENT_ID)"`, `secret = "env(KAKAO_CLIENT_SECRET)"` | `AUTH_ROADMAP.md` 3.4절 |
| 4 | 계정 연결 화면을 쓰므로 `[auth] enable_manual_linking = true` | [Identity Linking](https://supabase.com/docs/guides/auth/auth-identity-linking) |

### 6.3 앱 코드와 확인

- 버튼: `signInWithOAuth({ provider: 'kakao', options: { redirectTo } })` → 같은 `/auth/callback`. 코드 추가는 `providers/kakao.ts`와 버튼 메타데이터뿐입니다.
- 버튼 모양: [카카오 로그인 디자인 가이드](https://developers.kakao.com/docs/ko/kakaologin/design-guide)의 색·문구·로고를 그대로 씁니다(임의 색 금지).
- 오류 코드 전체: [카카오 로그인 문제 해결](https://developers.kakao.com/docs/ko/kakaologin/trouble-shooting), 개념: [이해하기](https://developers.kakao.com/docs/ko/kakaologin/common), [REST API](https://developers.kakao.com/docs/ko/kakaologin/rest-api), [FAQ](https://developers.kakao.com/docs/ko/kakaologin/faq).
- 수용 기준: `AUTH_ROADMAP.md` 7.1.3절 C1-1~C1-5.

## 7. Stage C2: 네이버 로그인

### 7.1 네이버 개발자센터 설정 (사람)

네이버 개발자센터 문서는 이 문서 작성 도구로 열리지 않아 링크만 적습니다. 작업 전에 브라우저로 열어 메뉴 이름을 확인합니다(미확인).

| 순서 | 할 일 | 링크(미확인, 브라우저로 확인) |
|---|---|---|
| 1 | 애플리케이션 등록: 사용 API "네이버 로그인", 제공 정보에서 회원이름·이메일·프로필 사진을 "필수"로 | https://developers.naver.com/apps/#/register |
| 2 | 서비스 환경 PC웹: 서비스 URL = 대표 도메인, Callback URL = 경로에 따라(7.2절) Supabase 콜백 또는 앱 `/auth/naver/callback`. 한 애플리케이션에 서비스 URL·Callback URL을 몇 개까지 둘 수 있는지는 미확인 | 같음 |
| 3 | Client ID·Client Secret 확인. "개발 중" 상태에서는 멤버 관리에 등록한 테스트 아이디만 로그인됩니다 | 같음 |
| 4 | 로그인 버튼은 네이버 BI 가이드를 따른다 | https://developers.naver.com/docs/login/bi/bi.md |
| 5 | 검수 요청: 로그인 버튼부터 가입 완료까지 화면 캡처를 제출. 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않습니다(C2-6) | https://developers.naver.com/docs/login/overview/overview.md |
| 참고 | API 명세: authorize `https://nid.naver.com/oauth2.0/authorize`, token `https://nid.naver.com/oauth2.0/token`, 프로필 `https://openapi.naver.com/v1/nid/me`(필드가 `response` 아래 중첩) | https://developers.naver.com/docs/login/api/api.md, https://developers.naver.com/docs/login/devguide/devguide.md |

### 7.2 경로 결정 스파이크 (0.5일)

Supabase가 2026-04에 커스텀 OAuth/OIDC 제공자를 내놓아 네이버를 `custom:naver`로 붙일 수 있게 됐습니다([문서](https://supabase.com/docs/guides/auth/custom-oauth-providers), [발표](https://supabase.com/blog/custom-oauth-oidc-providers)). 확인한 사실과 남은 위험은 다음과 같습니다.

| 항목 | 내용 |
|---|---|
| 등록 방법 | 대시보드 Auth Providers → New Provider → "Manual configuration"(OAuth2), 또는 관리 API `auth.admin.customProviders.createProvider`. CLI `config.toml` 등록은 문서에 없음 |
| 필요한 값 | `provider_type: 'oauth2'`, `identifier: 'custom:naver'`, Client ID·Secret, Authorization URL, Token URL, UserInfo URL. 생성 폼이 보여 주는 Callback URL을 네이버에 등록 |
| 제한 | Free 플랜 프로젝트당 커스텀 제공자 3개, Pro 이상 무제한. PKCE 기본(`pkce_enabled: true`). 이메일이 없으면 기본 거부(`email_optional`로 완화 가능) |
| 남은 위험 | 네이버 프로필 응답은 `response.id`, `response.email`처럼 중첩되는데, 응답에서 id·이메일을 어떻게 읽는지(속성 매핑) 문서에 없음 → 스파이크로 확인 |

스파이크 순서와 통과 기준은 `AUTH_ROADMAP.md` 7.2.2절 그대로입니다. 등록은 `scripts/auth/register-naver-provider.mjs`로 남겨 스테이징·운영에 같은 값으로 재현합니다. 결과(`supabase_custom` 또는 `bridge`)는 `NAVER_AUTH_PATH`와 task `log.md` `[DECISION]`에 기록하고, 브리지면 코어 `staged/0010_core_auth_identity_links.sql`을 한 번만 적용합니다(`AUTH_ROADMAP.md` 7.2.3절). 로컬 CLI가 커스텀 제공자를 지원하지 않으면 네이버는 스테이징 프로젝트에서만 확인합니다.

## 8. 테스트 전략

| 대상 | 자동화 | 방법 |
|---|---|---|
| Mock 로그인, 권한·역할 분기, RLS | 자동 | 페르소나 `storageState` E2E, RLS 스모크, 계약 테스트(3장) |
| 콜백 오류 경로(`code` 없음·재사용, `next` 공격 문자열, 허용 밖 제공자) | 자동 | 콜백 단위 테스트(Supabase 클라이언트 목) |
| Google·카카오·네이버 실로그인 | 수동 | 점검표: 데스크톱·모바일 각 1회, 신규·기존 계정, 같은 이메일 연결, 연결 해제. 결과를 task `log.md`에 기록. 실제 제공자 화면은 자동화하지 않습니다(봇 탐지·약관) |
| 배포 설정 | 반자동 | 배포 체크리스트(`docs/<제품>/ops/auth-checklist.md`): 대시보드 제공자 설정, Redirect URLs, `AUTH_PROVIDERS`, `AUTH_MODE=live` |

## 9. 공용 모듈 완료 후 모든 제품에 적용하기

### 9.1 버전과 출시 규칙

| 버전 | 들어가는 것 | 출시 조건 |
|---|---|---|
| v0.x | Stage A(레퍼런스 제품 안, 복사 방식) | 레퍼런스 제품 Mock E2E 녹색 |
| v1.0 | 패키지 추출, Stage B(Google·이메일·초대 메일, 콜백, 약관 단계, 제공자 허용 검사), 계약 테스트 | 레퍼런스 제품 G2 직전 상태에서 B-1~B-6 통과 |
| v1.1 | C1 카카오, 로그인 방법 화면 | C1-1~C1-5 통과 |
| v1.2 | C2 네이버(스파이크 결과 경로) | C2-1~C2-6 통과 |

- 버전은 semver. 콜백 동작이나 제품 주입 값이 바뀌면 메이저를 올립니다. `CHANGELOG.md`에 "제품이 할 일"을 꼭 적습니다.
- 출시는 사람 승인 후. 에이전트는 패키지를 배포하지 않고 PR까지만 만듭니다.
- 제품 저장소의 `@nomad/core-auth`는 정확한 버전으로 고정합니다(`latest` 금지).

### 9.2 제품별 적용 순서와 메모

적용 순서는 개발 순서(`docs/products/README.md` "개발 순서")를 따르되 레퍼런스 제품(AUTH-D3)을 맨 앞에 둡니다.

| 순서 | 제품(app) | 가입 정책 | B | C1·C2 | 작업 A / B / C1 / C2 | 적용할 때 주의 |
|---|---|---|---|---|---|---|
| 0 | flora-publishing(`publishing`) | open | Google + 이메일 | P1 | PB-06-006 / 056 / 057 / 058 | 레퍼런스. 약관 단계 `/onboarding` |
| 1 | study-note(`notes`) | open | Google + 이메일 | P1 | NT-06-006 / 053 / 054 / 055 | 표준 open 앱 |
| 1 | website-floria(`site`) | invite | Google + 초대 메일 | 제외 | SI-06-019 / 049 / - / - | invite 첫 검증. 방문자는 로그인 없음 |
| 2 | astro-ai(`astro`) | open | Google + 이메일 | P1 | AS-06-003 / 055 / 056 / 057 | 환영 크레딧은 Google 로그인 확인 후 |
| 3 | nomad-video(`video`) | open | Google + 이메일 | P1 | VID-06-004 / 063 / 064 / 065 | 로그인용 Google 클라이언트와 YouTube 채널 연동용 클라이언트를 나눔 |
| 3 | nomad-blog(`blog`) | open | Google + 이메일 | P1 | BL-06-004 / 057 / 058 / 059 | 네이버 사용자 비중이 커서 C2 검수를 먼저 신청 |
| 3 | nomad-commerce(`commerce`) | open | Google + 이메일 | P1 | CM-06-007 / 058 / 059 / 060 | 기존 MVP 카카오 로그인을 C1으로 옮김 |
| 4 | microweb-studio(`microweb`) | invite | Google + 초대 메일 | P2 선택 | MW-06-003 / 054 / 055 / 056 | `studio_access` 허용 목록. 하객은 로그인 없음 |
| 4 | live-poll(`poll`) | open | Google + 이메일 | P1 | LP-06-003 / 049 / 050 / 051 | 진행자만 로그인. 청중·오버레이는 단계 무관 |
| 4 | toon-factory(`toon`) | open | Google + 이메일 | P1 | TN-06-004·027 / 067 / 068 / 069 | - |
| 4 | nomad-docs(`docs`) | open | Google + 이메일 | P1 | DC-06-014 / 063 / 064 / 065 | 회사 정보 온보딩이 약관 단계 다음 |
| 5 | admin-suite(`erp`, `sms`, `hms`) | approval / invite / invite | erp·sms Google + 이메일·초대, hms 이메일만 | erp·sms P2 선택, hms 제외 | ADM-06-007 / 058 / 059 / 060 | `resolveOrg`로 기관 조직 선택. hms는 단독 프로젝트라 제공자 앱을 따로 만들지 않음(이메일만) |
| 5 | stock-dashboard(`stock`) | invite | Google + 초대 링크 | P2 선택 | ST-06-006·009 / 052 / 053 / 054 | 모놀리스 단독 프로젝트: Google 클라이언트를 따로 만든다 |
| - | arch-studio(`arch`) | open | Google + 이메일 | P2 선택 | 06장 작성 시 정함 | 데스크톱 앱(Tauri)이라 앱 복귀 방식(01장 D-15: 딥링크·루프백)을 패키지 밖에 추가 |

### 9.3 제품 하나에 적용하는 절차 (에이전트 작업 1개)

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | `@nomad/core-auth`를 고정 버전으로 설치. 기존 자체 구현(`src/lib/auth/` 안 코드)은 지우고 3장의 제품 주입 파일만 남김 | 빌드 녹색 |
| 2 | 시드 훅 `scripts/dev/seed-users.<app>.mjs`를 제품 05장 10절대로 작성 | 시드 2회 멱등 |
| 3 | 계약 테스트(`test/contract/`)를 제품 CI에 연결 | 녹색 |
| 4 | 제품 Mock E2E 녹색 → 그 제품 G1 판정은 사람 | `[DECISION] G1 통과` |
| 5 | B: 외부 설정은 이미 끝난 통합 프로젝트(AUTH-D1 (a))면 Redirect URLs에 제품 도메인만 추가. 단독 프로젝트면 5장 전체 | 배포 체크리스트 |
| 6 | 배포 env: `AUTH_MODE=live`, `AUTH_PROVIDERS`(제품 01장 B 열) | B-4, B-6 |
| 7 | 수동 점검표 → `log.md` | B-5 |
| 8 | C는 그 제품 G2 후 `AUTH_PROVIDERS`에 `kakao`, `naver` 추가(패키지 v1.1·v1.2 이상) | C 수용 기준 |

패키지가 새 버전을 내면 같은 절차의 1·3·4번만 다시 합니다. 기획 문서를 고쳤으면 `docs/develop/_shared/tools/build_root.py`로 그 제품 묶음을 다시 만들고 경로 누락 0을 확인합니다.

### 9.4 적용 현황표 (운영 중 갱신)

| 제품 | 패키지 버전 | 현재 단계 | G1 | G2 | 메모 |
|---|---|---|---|---|---|
| (제품마다 1행) | | A / B / C1 / C2 | 날짜 | 날짜 | |

이 표는 개발이 시작되면 이 문서에서 직접 갱신합니다.

## 10. 공식 문서 링크 모음

| 분류 | 링크 | 확인 |
|---|---|---|
| Supabase | [Social Login 목록](https://supabase.com/docs/guides/auth/social-login), [Google](https://supabase.com/docs/guides/auth/social-login/auth-google), [Kakao](https://supabase.com/docs/guides/auth/social-login/auth-kakao), [Custom OAuth/OIDC Providers](https://supabase.com/docs/guides/auth/custom-oauth-providers), [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Next.js 서버 사이드 인증](https://supabase.com/docs/guides/auth/server-side/nextjs), [서버 클라이언트 만들기](https://supabase.com/docs/guides/auth/server-side/creating-a-client), [PKCE](https://supabase.com/docs/guides/auth/sessions/pkce-flow), [Identity Linking](https://supabase.com/docs/guides/auth/auth-identity-linking), [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates), [CLI config](https://supabase.com/docs/guides/local-development/cli/config), [signInWithOAuth](https://supabase.com/docs/reference/javascript/auth-signinwithoauth) | 2026-10-15 열람 확인(CLI config는 `[auth.external.<provider>]`의 `enabled`·`client_id`·`secret`·`skip_nonce_check`와 `[auth] enable_manual_linking`을 문서화, 커스텀 제공자는 언급 없음) |
| Google | [Auth Platform 개요](https://console.cloud.google.com/auth/overview), [브랜딩](https://console.cloud.google.com/auth/branding), [대상](https://console.cloud.google.com/auth/audience), [데이터 액세스](https://console.cloud.google.com/auth/scopes), [클라이언트](https://console.cloud.google.com/auth/clients), [인증 센터](https://console.cloud.google.com/auth/verification), [OAuth 앱 브랜딩 관리](https://support.google.com/cloud/answer/15549049), [브랜드 확인](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification), [로그인 버튼 가이드](https://developers.google.com/identity/branding-guidelines) | 콘솔 경로는 Supabase 문서 기준 확인 |
| 카카오 | [콘솔](https://developers.kakao.com/console/app), [설정하기](https://developers.kakao.com/docs/ko/kakaologin/prerequisite), [이해하기](https://developers.kakao.com/docs/ko/kakaologin/common), [REST API](https://developers.kakao.com/docs/ko/kakaologin/rest-api), [동의항목](https://developers.kakao.com/docs/ko/kakaologin/utilize#scope), [디자인 가이드](https://developers.kakao.com/docs/ko/kakaologin/design-guide), [문제 해결](https://developers.kakao.com/docs/ko/kakaologin/trouble-shooting), [앱 설정](https://developers.kakao.com/docs/ko/app-setting/app) | 설정하기 문서 2026-10-15 열람 확인 |
| 네이버 | [개요](https://developers.naver.com/docs/login/overview/overview.md), [API 명세](https://developers.naver.com/docs/login/api/api.md), [개발 가이드](https://developers.naver.com/docs/login/devguide/devguide.md), [BI 가이드](https://developers.naver.com/docs/login/bi/bi.md), [애플리케이션 등록](https://developers.naver.com/apps/#/register) | 미확인(도구 접근 불가). 브라우저로 확인 |

## 11. 점검표

- [ ] AUTH-D1(통합 계정 브랜드), AUTH-D2(배포 방식), AUTH-D3(레퍼런스 제품) 결정 기록
- [ ] 레퍼런스 제품 Stage A 완료, G1 통과
- [ ] `@nomad/core-auth` v1.0 추출, 계약 테스트 녹색, 레퍼런스 제품이 패키지로 교체 후 E2E 녹색
- [ ] Google Auth Platform 설정(5.1절), 브랜드 확인, 프로덕션 게시
- [ ] Supabase Google 제공자, Redirect URLs(모든 제품 도메인), 메일 템플릿 `redirectTo` 확인
- [ ] 레퍼런스 제품 B-1~B-6 통과, 공개 베타, G2
- [ ] 카카오 비즈 앱 전환, 이메일 필수 동의, v1.1
- [ ] 네이버 스파이크 → 경로 결정 → 검수 통과 → v1.2
- [ ] 9.2절 순서대로 제품 적용, 9.4절 현황표 갱신
