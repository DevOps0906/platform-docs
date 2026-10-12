# webcraft-agency-simulator 코드 리뷰

## 1. 프로젝트 개요

- 한 줄 설명: 업종(병원, 법률, 여행, 교육, 커머스 등)과 제작 등급(Basic/Pro/Premium/Custom)을 고르면 해당 조합의 홈페이지 시안과 CRM 대시보드 미리보기를 보여 주는 웹 에이전시 영업용 시뮬레이터. 랜딩 페이지, 포트폴리오, 가격표, 모킹 로그인과 관리자 대시보드(모듈 구매/ON-OFF 시뮬레이션)를 포함한다.
- 목적/대상 사용자: 웹 제작 상담 시 고객에게 "등급별로 무엇을 받는지"를 시각적으로 보여 주는 영업 도구. 실제 SaaS 가 아니라 기획 시연용이다(README.md:7-8 "demonstration and prototyping purposes only").
- 출처: Google Vertex AI Studio export 템플릿(backend 프록시 + frontend Vite). nexus-micro-web-builder 와 backend/server.js 가 동일하고, frontend/vertex-ai-proxy-interceptor.js 는 116번째 줄 PROXY_HEADER 값만 다르다(diff 로 확인).

### 기술 스택

| 영역 | 기술 | 비고 |
|------|------|------|
| 프론트 | React 19.2.5, TypeScript 6.0.3, Vite 8.0.10, Tailwind CSS(CDN 런타임) | frontend/package.json 의존성 전부 `latest` |
| UI | lucide-react 1.11.0 | `import * as Icons` 로 전체 번들 포함 |
| 백엔드 | Node.js, Express 5, google-auth-library, ws, express-rate-limit | Vertex AI 프록시 템플릿 원본, 미사용 |
| DB | 없음 | 모든 데이터는 constants 정적 배열, 상태는 메모리 |
| 인프라 | npm workspaces(frontend, backend), concurrently | 배포 설정 없음, .gitignore 없음 |
| AI | 백엔드 Vertex AI 프록시 존재, 프론트 호출 코드 0건 | 사실상 AI 미사용 |

### 현재 완성도 추정: 약 50%

- 근거(완성): `tsc --noEmit` 오류 0건, `vite build` 성공(단일 번들 936kB, gzip 244kB). 홈 -> 시뮬레이터(업종 x 등급 x 디바이스 프리뷰) -> 모킹 로그인 -> 관리자 대시보드 흐름이 App.tsx 의 `currentView` 상태로 동작한다.
- 근거(미완): 로그인/결제/외부 연동이 모두 클라이언트 모킹(pages/Login.tsx:14-26, pages/AdminDashboard.tsx:54-59, 90). "무료 견적 상담하기" 버튼에 핸들러 없음(pages/Home.tsx:33). 고아 컴포넌트와 중복 상수 파일이 다수 남아 있고, 백엔드는 쓰이지 않는다.

### 핵심 기능 목록

| 기능 | 상태 |
|------|------|
| 랜딩(히어로, 웹/상세페이지 포트폴리오 필터, 가격표) | 동작 |
| 업종 x 등급 시뮬레이터, 데스크톱/태블릿/모바일 프리뷰 | 동작(pages/Simulator.tsx + components/pricing/*) |
| 소셜 로그인(카카오/네이버/구글) + 권한 선택 | 모킹(즉시 성공) |
| 관리자 대시보드: 모듈 구매/토글, 설정 탭, GitHub/Supabase 연동 | 모킹(alert, 로컬 state) |
| 견적 상담 문의 | 미구현 |
| Vertex AI 연동 | 코드 없음 |

## 2. 구조 분석

| 경로 | 역할 | 비고 |
|------|------|------|
| package.json | 루트 workspace, `npm run dev` 로 프론트+백엔드 동시 실행 | concurrently `latest` |
| backend/server.js (455줄) | Vertex AI REST/WS 프록시, ADC 인증, rate limit | 템플릿 원본, 호출처 없음 |
| backend/.env.local | GCP 프로젝트/리전/PROXY_HEADER | **git 에 커밋되어 origin/main 에 push 됨** |
| frontend/index.tsx | 엔트리, 인터셉터 import(1행) | |
| frontend/App.tsx (72줄) | `currentView` 4개 화면 전환, 선택 tier/industry, currentUser | 라우터 없는 상태 기반 네비게이션 |
| frontend/pages/Home.tsx, Simulator.tsx, Login.tsx, AdminDashboard.tsx | 4개 화면 | AdminDashboard 715줄 단일 컴포넌트 |
| frontend/components/layout/Header.tsx, Footer.tsx | 실제 사용되는 헤더/푸터 | |
| frontend/components/pricing/Pricing{Basic,Pro,Premium,Custom}.tsx | 등급별 시안 렌더러(180~260줄씩) | 사용 중 |
| frontend/constants/geoMeta.ts (202줄) | INDUSTRIES, TIERS, CRM_MODULES, 색상/프레임워크 스타일 맵 | 실제 데이터 원천 |
| frontend/constants.ts (180줄) | INDUSTRIES, TIERS, CRM_MODULES, PRICING_PLANS 의 구버전 | Pricing.tsx 가 PRICING_PLANS 만 사용, 나머지는 geoMeta 와 중복 |
| frontend/components/Header.tsx, Footer.tsx, Simulator.tsx, PromoBanners.tsx | 구버전 컴포넌트 | 고아 코드(import 0건) |
| frontend/components/portfolio/PortfolioTabs.tsx, ThumbnailBook.tsx, constants/portfolioBook.ts | 1줄 스텁 / 0바이트 | 고아 코드 |
| frontend/vertex-ai-proxy-interceptor.js | fetch/WebSocket 가로채기 shim | 대상 호출 없음 |
| webcraft-agency-simulator/ (하위 폴더) | `.git` + `.gitattributes` 만 있는 별도 저장소 | **중복 아님, 실수로 생긴 빈 중첩 repo** |
| .claude/ | tsc 검사 PostToolUse hook, 커밋/셋업 스킬 | 정상 |

하위 폴더 확인 결과: `webcraft-agency-simulator/webcraft-agency-simulator/` 는 소스 사본이 아니라 같은 origin(theBestTrade/webcraft-agency-simulator)을 가진 별도 git 저장소로, 커밋 5d0f978 에 `.gitattributes` 1개만 있다. 상위 저장소에는 `.gitmodules` 없이 gitlink(mode 160000)로 커밋(4622c33)되어 있어, 클론하면 빈 디렉토리만 생긴다. 자기 자신의 원격을 하위에 다시 클론한 흔적으로 보이며 삭제 대상이다.

데이터 흐름: App 이 `currentView` 로 화면을 바꾸고, 가격표/포트폴리오에서 선택한 `tierId`, `industryId` 를 Simulator 에 초기값으로 넘긴다. Simulator 는 geoMeta 의 INDUSTRIES/TIERS 를 읽어 `switch(activeTier.id)` 로 4개 Pricing 컴포넌트 중 하나를 그린다. Login 은 선택한 role 로 가짜 User 를 만들어 App 에 올리고 AdminDashboard 가 role 과 하드코딩 비밀번호로 설정 화면 접근을 제어한다. 서버 통신과 영속화는 없다.

## 3. 발견된 문제점

| # | 심각도 | 분류 | 위치(경로:줄) | 내용 |
|---|--------|------|---------------|------|
| 1 | 높음 | 설정 | 저장소 루트(.gitignore 없음) | 추적 파일 8,706개 중 8,655개가 node_modules(lucide-react 3,923, rxjs 2,266 등). `.git` 28MB. `git status` 에 node_modules/.vite 캐시 변경이 계속 잡힘 |
| 2 | 높음 | 보안 | backend/.env.local:16-20 | GCP 프로젝트 ID 와 PROXY_HEADER 가 커밋되어 origin/main 에 push 됨(현재 비공개 저장소로 추정, 비인증 접근 404). README 는 이 파일을 로컬 생성물로 안내 |
| 3 | 높음 | 구조 | backend/server.js:1-455, frontend/index.tsx:1 | 프론트에 Vertex AI 호출이 없는데 프록시 백엔드가 `npm run dev` 에 묶여, ADC 로그인 없으면 실행 불가(server.js:22-30). nexus 와 동일한 공통 문제 |
| 4 | 높음 | 구조 | webcraft-agency-simulator/ (gitlink 5d0f978) | `.gitmodules` 없는 중첩 git 저장소. 클론 시 빈 폴더, 서브모듈 경고 유발 |
| 5 | 중간 | 보안 | frontend/vertex-ai-proxy-interceptor.js:116 | PROXY_HEADER 시크릿이 프론트 번들에 하드코딩(템플릿 공통). 127.0.0.1 바인딩이라 당장 위험은 낮음 |
| 6 | 중간 | 보안 | backend/server.js:232, 309 | 클라이언트 headers 가 Authorization 을 덮어쓸 수 있음. 500 응답에 error 객체 원문 노출(템플릿 공통) |
| 7 | 중간 | 설정 | backend/server.js:10, backend/package.json:12-18 | `node-fetch` 를 import 하지만 dependencies 에 없음(phantom dependency) |
| 8 | 중간 | 설정 | frontend/package.json:10-19, package.json:8 | 의존성 전부 `latest`. lock 삭제 시 메이저 변경 위험 |
| 9 | 중간 | 구조 | frontend/pages/AdminDashboard.tsx:17-715 | 715줄 단일 컴포넌트에 모달 2개, 사이드바, overview/모듈/settings 4탭, 상태 10개가 혼재 |
| 10 | 중간 | 구조 | frontend/constants.ts:3-180, frontend/constants/geoMeta.ts:3-148 | INDUSTRIES/TIERS/CRM_MODULES 가 두 파일에 존재하며 내용이 이미 어긋남(constants.ts:8 병원 항목 9개 vs geoMeta 7개) |
| 11 | 중간 | 성능 | 빌드 결과, frontend/pages/AdminDashboard.tsx:8, components/pricing/*.tsx:3 | `import * as Icons from 'lucide-react'` 로 아이콘 전체 포함, 단일 번들 936kB. 코드 스플리팅 없음 |
| 12 | 중간 | 보안 | frontend/pages/AdminDashboard.tsx:90, pages/Login.tsx:12-26 | 설정 잠금 비밀번호 '1234' 하드코딩, 로그인 시 권한을 사용자가 직접 선택. 데모로는 무방하나 외부 공개 배포 시 오해 소지 |
| 13 | 낮음 | 품질 | components/Header.tsx, Footer.tsx, Simulator.tsx, PromoBanners.tsx, portfolio/PortfolioTabs.tsx, portfolio/ThumbnailBook.tsx, constants/portfolioBook.ts | 고아/스텁 파일 7개(import 0건, portfolioBook.ts 0바이트) |
| 14 | 낮음 | 품질 | frontend/pages/Home.tsx:11, 33 | Home 의 onNavigate 타입에 'login' 누락(Header 는 'login' 사용, strict:false 라 통과). "무료 견적 상담하기" 버튼 핸들러 없음 |
| 15 | 낮음 | 설정 | frontend/index.html:7, 13, 81, frontend/vite.config.ts:10 | Tailwind CDN 런타임(프로덕션 비권장), Pretendard 폰트 미로드, 존재하지 않는 `/index.js` 참조, 미사용 API_KEY define |
| 16 | 낮음 | 설정 | frontend/tsconfig.json:15-16 | `strict: false`, `noImplicitAny: false` 로 #14 같은 타입 불일치가 검출되지 않음. .claude hook 의 tsc 검사가 사실상 무력 |

### 심각도 높음 상세

**#1 node_modules 커밋.** 루트에 .gitignore 가 없어 최초 커밋(a6900c6)에 node_modules 전체가 들어갔다. 추적 파일의 99% 가 의존성이며, 이후 `npm install` 이나 Vite 실행만으로 diff 가 생겨 실제 변경을 알아보기 어렵다. .gitignore 추가 후 `git rm -r --cached node_modules frontend/node_modules` 로 추적을 끊어야 하고, 저장소 크기를 줄이려면 히스토리 재작성이 필요하다. nexus-micro-web-builder 에는 없던, 이 프로젝트 고유의 문제다.

**#2 .env.local 커밋.** nexus 리뷰에서는 .gitignore 로 제외되어 정상이었으나 여기서는 커밋 후 push 까지 되었다. 값 자체는 ADC 기반이라 직접적인 자격 증명은 아니지만, GCP 프로젝트 ID 노출과 "시크릿은 커밋하지 않는다"는 원칙 위반이다. 백엔드를 제거하면 파일 자체가 불필요해지므로 #3 과 함께 처리하고, 저장소가 공개될 가능성이 있다면 히스토리에서도 제거한다.

**#3 미사용 백엔드.** 앱의 모든 기능은 정적 데이터와 로컬 state 로 동작한다. 그런데 `npm run dev` 가 concurrently 로 백엔드를 함께 띄우고, 백엔드는 GCP 환경변수나 PROXY_HEADER 가 없으면 `process.exit(1)` 한다. AI 기능이 없는 데모를 보려고 gcloud 설치와 로그인이 필요한 구조이며, nexus-micro-web-builder, premium-wedding-invitation 과 공통된 템플릿 잔재다.

**#4 중첩 저장소.** 하위 `webcraft-agency-simulator/` 는 소스 중복이 아니라 빈 git 저장소다. gitlink 로만 기록되어 있어 다른 환경에서 클론하면 내용 없는 폴더가 생기고, 일부 도구는 서브모듈 오류를 낸다. 디렉토리를 삭제하고 `git rm --cached webcraft-agency-simulator` 로 gitlink 를 제거하면 된다.

## 4. 효율성 개선 제안

- 구조/아키텍처: backend/, 인터셉터, 하위 중첩 repo 를 제거하고 단일 Vite 정적 사이트로 축소. constants.ts 의 PRICING_PLANS 를 geoMeta.ts(또는 constants/pricing.ts)로 옮기고 constants.ts 삭제. AdminDashboard 를 `admin/Sidebar`, `admin/OverviewView`, `admin/SettingsView`, `admin/PurchaseModal`, `admin/PasswordModal` 로 분리.
- 성능: `import * as Icons` 를 `iconName -> 컴포넌트` 명시 맵(constants/icons.ts)으로 교체해 tree-shaking 회복. 화면 4개를 `React.lazy` 로 분할(특히 AdminDashboard, Simulator). Tailwind 를 `@tailwindcss/vite` 빌드 타임으로 전환(색상 클래스가 geoMeta 에 리터럴로 있어 전환 안전).
- 개발 생산성: .gitignore 추가, `latest` 를 lock 기준 버전으로 고정, tsconfig `strict: true` 단계적 적용, `typecheck` 스크립트 추가. 고아 파일 삭제.
- 운영/배포: 정적 사이트라 Vercel/Netlify 로 즉시 배포 가능. 외부 공개 시 Login/Admin 화면에 "데모" 배지를 노출하고, 견적 상담 버튼은 폼 서비스(Formspree, Google Form) 또는 카카오 채널 링크로 연결. CLAUDE.md 의 백엔드/GCP 섹션 재작성.

## 5. 수정 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 예상 규모 | 권장 모델 | 선정 이유 |
|---|------|----------|-----------|-----------|-----------|
| 1 | 루트 .gitignore 추가(node_modules, dist, .env*, .vite), `git rm -r --cached` 로 node_modules 와 backend/.env.local 추적 해제 | P0 | S | Sonnet 5.5 | 설정 파일 정리, 명령이 정해져 있음 |
| 2 | 하위 `webcraft-agency-simulator/` 중첩 repo 삭제 및 gitlink 제거 | P0 | S | Sonnet 5.5 | 단순 정리 |
| 3 | backend/, vertex-ai-proxy-interceptor.js, index.tsx:1 import, vite.config.ts 프록시/define, 루트 workspaces/concurrently 제거하여 단일 Vite 프로젝트화 | P0 | S | Sonnet 5.5 | nexus 와 동일한 기계적 삭제 작업 |
| 4 | 히스토리에서 node_modules 와 .env.local 제거(git filter-repo) 후 force push 여부 판단, 저장소 공개 여부 확인 | P1 | M | Opus 5.5 | 히스토리 재작성은 실수 시 복구 비용이 커서 하위 모델 부적합 |
| 5 | 고아 파일 7개 삭제(#13), constants.ts 의 PRICING_PLANS 를 constants/pricing.ts 로 이동 후 constants.ts 삭제 | P0 | S | Sonnet 5.5 | import 그래프가 명확 |
| 6 | 의존성 `latest` 를 lock 기준 버전으로 고정, tsconfig strict 활성화 후 발생 타입 오류 정리(Home onNavigate 타입 등) | P1 | S | Sonnet 5.5 | 린트/타입 오류 정리 |
| 7 | `import * as Icons` 를 명시적 아이콘 맵으로 교체(AdminDashboard, Simulator, pricing 4종, PortfolioFilter) | P1 | M | Sonnet 5.5 | 반복적 치환 작업 |
| 8 | AdminDashboard 715줄을 Sidebar/Overview/Settings/모달 컴포넌트로 분리, 모듈 구매 상태를 커스텀 훅(useModuleStore)으로 추출 | P1 | M | Opus 5.5 | 3~6개 파일 리팩토링과 상태 정리 |
| 9 | Pricing{Basic,Pro,Premium,Custom} 공통 레이아웃(헤더/디바이스 프레임/섹션) 추출 | P2 | M | Opus 5.5 | 중복 구조 파악과 추상화 설계 필요 |
| 10 | Tailwind CDN -> @tailwindcss/vite 전환, index.html 의 CSS 변수/keyframes 를 index.css 로 이동, Pretendard CDN 추가, `/index.js` 참조 제거 | P1 | S | Sonnet 5.5 | 스타일/설정 |
| 11 | 화면 4개 React.lazy 코드 스플리팅, 번들 500kB 미만 확인 | P2 | S | Sonnet 5.5 | 설정 수준 최적화 |
| 12 | "무료 견적 상담하기" 를 업종/등급 선택값을 포함한 문의 폼(외부 폼 서비스 연동)으로 구현 | P2 | M | Opus 5.5 | 명확히 정의된 중간 규모 기능 + 외부 연동 |
| 13 | Login/Admin 화면에 데모 표시, CLAUDE.md 와 README 를 정적 데모 기준으로 재작성 | P1 | S | Sonnet 5.5 | 문서화/문구 |

## 6. 종합 평가

- 강점 3개
  1. 업종 9종 x 등급 4종 조합으로 시안, 타이포 추천, UI 프레임워크 스타일까지 바뀌는 시뮬레이터가 영업 도구로서 설득력이 있다(pages/Simulator.tsx, constants/geoMeta.ts).
  2. 타입 검사와 프로덕션 빌드가 모두 통과하며, 상태가 App 의 `currentView` 중심으로 단순해 흐름 파악이 쉽다.
  3. CLAUDE.md, .claude hook/스킬이 갖춰져 있어 AI 보조 개발 환경이 이미 정리되어 있다.
- 약점 3개
  1. node_modules 와 .env.local 이 커밋되어 저장소 위생이 가장 심각한 문제다(추적 파일 99% 가 의존성).
  2. 미사용 Vertex AI 백엔드, 빈 중첩 저장소, 고아 컴포넌트, 중복 상수 파일 등 잔재가 실제 코드보다 혼란을 더 준다.
  3. AdminDashboard 715줄 단일 컴포넌트와 lucide 전체 import 로 유지보수성과 번들 크기가 나쁘다.
- 모델별 비율(13개 작업 기준): Fable 0% / Opus 31%(4개) / Sonnet 69%(9개)
- 권장 진행 순서
  1. 1단계(P0, 반나절): .gitignore, node_modules/.env 추적 해제, 중첩 repo 삭제, 백엔드 제거, 고아 파일 정리.
  2. 2단계(P1): 히스토리 정리 판단, 버전 고정과 strict 타입, 아이콘 맵, AdminDashboard 분리, Tailwind 빌드 전환, 문서 재작성.
  3. 3단계(P2): Pricing 공통화, 코드 스플리팅, 견적 문의 폼.
- 최종 권고: **계속 발전(정적 데모로 축소 후)**. nexus-micro-web-builder 는 기획 쇼케이스라 아카이브가 맞았지만, 이 프로젝트는 고객 상담에 직접 쓸 수 있는 시뮬레이터와 가격표가 이미 동작하고 있어 실사용 가치가 있다. 다만 같은 Vertex 템플릿 잔재를 공유하므로, 1단계 정리 결과(백엔드 제거, .gitignore, 단일 Vite 구조)를 nexus/premium-wedding-invitation 과 공통 "정적 데모 템플릿" 정리 절차로 묶어 처리하면 효율적이다.
- 주 담당 모델: **Sonnet 5.5**. 남은 작업 대부분이 삭제, 설정 파일, 아이콘 치환, 스타일 전환, 문서화처럼 정의가 명확한 반복 작업이며, 실제 인증/결제/데이터 저장이 없어 실수 비용이 낮다. 단, git 히스토리 재작성(작업 4)은 되돌리기 어려운 작업이므로 Opus 5.5 에 맡기고, AdminDashboard 분리와 Pricing 공통화 같은 다중 파일 리팩토링도 Opus 5.5 가 담당하는 것이 적절하다.
