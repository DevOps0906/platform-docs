# WebSite 코드 리뷰

리뷰 대상: `D:\WorkSpace\platform\WebSite` 하위 5개 정적/마케팅 사이트 (Biz_Website, Botanic_Architecture, Floria_Neo, Floria_NEO_02, Lucury Website).
본문의 경로는 모두 `WebSite/` 기준 상대경로이며, `경로:줄번호` 형식으로 근거를 표기한다. 이미지·동영상은 열지 않고 파일 크기와 메타데이터(ffprobe)만 확인했다. node_modules, dist 내부 코드는 읽지 않았다(Biz_Website는 dist/index.html과 번들 내 문자열만 확인).

리뷰 시점 git 상태 요약: `Botanic_Architecture`만 커밋 대상(20개 파일 추적, 최근 3커밋 `0b7f3fa`, `8463f9a`, `54c9f68`). `Floria_Neo`, `Floria_NEO_02`, `Lucury Website`는 미추적(`??`). `Biz_Website`는 하위 내용(dist/, node_modules/)이 전부 루트 `.gitignore`에 걸려 git 에서는 폴더가 존재하지 않는 것과 같다. 루트 `WebSite/.vite/deps_temp_*` 는 Vite 의존성 캐시 잔재(ignored).

## 1. 프로젝트 개요

### Biz_Website

- 한 줄 설명: "Platform — 더 빠르게, 더 스마트하게" 라는 한국어 B2B SaaS 랜딩 페이지의 **빌드 산출물만** 남아 있는 폴더. 소스 코드(src/, index.html, package.json, vite.config)가 없다.
- 목적/대상: SaaS 제품 소개 및 무료 체험 유도(번들 문자열: "무료로 시작하기", "데모 보기", "성과 분석", "워크플로우 자동화", "보안 강화").
- 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 프론트 | React + Vite + Tailwind CSS 3, lucide-react | `Biz_Website/node_modules` 최상위에 react, react-dom, vite, tailwindcss, lucide-react, autoprefixer 존재. `node_modules/.package-lock.json:2` name `platform-website` v0.1.0 |
| 백엔드/DB | 없음 | — |
| 인프라 | 미정 (dist 는 절대경로 `/assets/` 참조, `dist/index.html:11-12`) | — |
| 폰트 | Google Fonts Inter 5가중치 (`dist/index.html:8-10`) | — |

- 현재 완성도 추정: **측정 불가(소스 0%)**. 빌드 결과물(`dist/assets/index-R8aSe9M1.js` 171KB, `index-BO-aMU7M.css` 22KB) 자체는 완성된 랜딩 1페이지로 보이지만, 수정·재배포가 불가능한 상태다.
- 핵심 기능(번들 문자열 기준): 히어로 CTA, 핵심 기능 6카드, 신뢰 지표(전체 매출/활성 사용자 대시보드 목업), 모바일 메뉴(aria 문구 "메뉴 열기/닫기" 존재).

### Botanic_Architecture

- 한 줄 설명: 럭셔리 다크 테마의 플로럴 스튜디오 "Floria — Botanic Architecture" 단일 페이지 랜딩. PRD.md 와 CLAUDE.md(구현 지시서)가 함께 있고, `floria/` 에 React 구현이 있다.
- 목적/대상(PRD.md §2): 갤러리 디렉터, 럭셔리 이벤트 기획자, 하이엔드 개인 고객. GEO(생성형 검색 최적화)를 설계 목표로 명시(PRD.md §4).
- 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 프론트 | React 19.2, Vite 8, JSX(TS 아님), 인라인 style 객체 | `floria/package.json:26-27,42`, `floria/src/App.jsx` 전체 |
| 스타일 | Tailwind v4 플러그인이 설정만 되어 있고 실제 미사용 | `floria/vite.config.js:3,6`, `floria/package.json:32,41` vs `floria/src/index.css`(Tailwind `@import` 없음), `App.jsx` 에 className 1곳(`:135`) |
| 아이콘 | lucide-react (devDependencies 에 잘못 위치) | `floria/package.json:40` |
| 폰트 | Google Fonts Playfair Display + Inter (CSS `@import`) | `floria/src/index.css:1` |
| 테스트/도구 | Playwright 스크린샷 스크립트 5종(gitignore 처리) | `floria/capture*.mjs`, `floria/verify.mjs`, `floria/.gitignore:26-31` |
| 백엔드 | 없음 (뉴스레터 폼은 state 만 변경) | `App.jsx:710-713` |

- 현재 완성도 추정: **약 55%**. 7개 섹션 마크업·애니메이션은 모두 구현됐으나 (1) 참조하는 로컬 이미지 10개가 리포에 없어 상품/아카이브/히어로가 깨진 상태, (2) 반응형이 사실상 없음, (3) PRD 가 요구한 JSON-LD/메타 미구현, (4) 폼 백엔드 없음.
- 핵심 기능: 고정 헤더+모바일 드롭다운, 히어로, Curated Assemblages(3 상품), Architecture of Nature(3단계), Archives(벤토 5개), Clarity(리뷰 5개 비정형 그리드), Brand Ethos, CTA 뉴스레터, 푸터 워터마크. IntersectionObserver 기반 페이드인 훅 `useFadeIn` (`App.jsx:31-47`).

### Floria_Neo

- 한 줄 설명: 위 Floria 디자인과 동일한 7개 섹션을 가진 **정적 HTML 1장**. 마크업 특성(`<html lang="en" style="">`, `class=""` 잔재, `lh3.googleusercontent.com/aida-public/...` 이미지)으로 보아 AI 디자인 도구(Stitch 계열)에서 내보낸 프로토타입이다.
- 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 프론트 | 순수 HTML + Tailwind Play CDN(`cdn.tailwindcss.com`) + 인라인 `tailwind.config` | `Floria_Neo/index.html:5,9-26` |
| 스타일 | `<style>` 블록 56줄 | `index.html:27-82` |
| 이미지 | 외부 googleusercontent 12개 URL, 로컬 `Hero-bg.jpg`(88KB), `hero_original.jpg`(282KB, 미사용) | `index.html:35,41,46,106,141-145,150,196-217,226` |
| JS | 없음(폼 핸들러 없음) | `index.html:324-332` |

- 현재 완성도 추정: **약 40%(프로토타입)**. 시각적 완성도는 높지만 빌드/배포 가능한 사이트가 아니다(Play CDN, 임시 이미지 URL, 모든 링크 `href="#"`).
- 핵심 기능: Botanic_Architecture 와 동일 섹션 구성(한국어 카피). 가격이 `$145/$185/$110`(Botanic 은 `₩180,000` 등)으로 서로 다름.

### Floria_NEO_02

- 한 줄 설명: 폴더명은 Floria 지만 실제 브랜드는 **"Flora Sentiment"** — 크림/세이지 톤의 라이트 테마 꽃 구독·클래스 커머스 사이트(Home/Shop/Subscription/Classes 4페이지). 세 Floria 폴더 중 유일하게 TypeScript + 컴포넌트 분리 + 데이터 레이어를 갖춘 코드베이스.
- 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 프론트 | React 19.2 + TypeScript 6.0 + Vite 8 + react-router-dom 7 | `Floria_NEO_02/package.json:13-36` |
| UI | Tailwind v4 (`@theme` 토큰), shadcn(base-nova 스타일, @base-ui/react) — button/card/badge/input/accordion 설치, 실제 사용은 accordion 1개 | `components.json:3`, `src/index.css:2-42`, `src/pages/FlowerClassPage.tsx:4` |
| 이미지 | 전부 Unsplash 원격 URL | `src/data/products.ts`, `src/pages/*.tsx` |
| 빌드 | `tsc -b && vite build`; dist/ 로컬 존재(389KB, JS 329KB), `.gitignore:11` 로 제외 | `package.json:8`, `dist/assets/index-DJwYCIIb.js` 328,798B |
| 백엔드 | 없음(폼 3곳 `preventDefault` 만) | `Footer.tsx:83`, `SubscriptionPage.tsx:181`, `FlowerClassPage.tsx:145` |

- 현재 완성도 추정: **약 60%**. 4페이지 UI와 필터/정렬, 아코디언 FAQ, 품절 처리까지 구현됐으나 결제·장바구니·위시리스트·문의 등 모든 CTA 가 동작하지 않고, 헤더/푸터가 가리키는 7개 라우트가 정의되지 않아 빈 화면이 뜬다. `title` 과 패키지명이 `temp-init` 그대로다(`index.html:7`, `package.json:2`).
- 핵심 기능: 월간 큐레이션 상품 그리드, 상황별 필터·가격 정렬(`ShopPage.tsx:14-23`), 구독 플랜 3종 카드, 클래스 일정·좌석·품절, FAQ 아코디언, 인스타 그리드, 뉴스레터 폼.

### Lucury Website

- 한 줄 설명: 폴더명은 "Lucury(Luxury 오타)" 이지만 실제 콘텐츠는 **"한울건설 HANUL CONSTRUCTION"** 건설사 브랜드 사이트. 전체화면 배경 영상 + GSAP ScrollTrigger 로 150프레임 캔버스 스크럽 연출을 하는 1페이지 정적 사이트. 내부에 **별도 git 리포(.git, Git LFS)** 가 중첩되어 있다.
- 기술 스택

| 구분 | 내용 | 근거 |
|---|---|---|
| 프론트 | 순수 HTML/CSS/JS, GSAP 3.12.5 + ScrollTrigger (cdnjs) | `Lucury Website/index.html:334-336`, `js/main.js:7` |
| 스타일 | 커스텀 CSS 1,306줄, CSS 변수 디자인 토큰 | `css/style.css:9-26` |
| 미디어 | `HeroMov/` mp4 3개 합계 254MB, `assets/frames/` JPEG 150장 23MB | ffprobe: 01=3840x2160 35.9s 25Mbps 112MB, 02=1920x1080 15s 9.5Mbps 17.8MB, 03=3840x2160 10.5s 94Mbps 124MB |
| 이미지 | `picsum.photos` 랜덤 플레이스홀더 6개 | `index.html:144,168,212,225,239,249` |
| 폰트 | Google Fonts Outfit 7가중치 + JetBrains Mono (`<style>@import`) | `index.html:8-10` |
| VCS | 중첩 리포 `origin = github.com/DevOps0906/Lucury_Website.git`, `*.mp4` LFS | `.git/config`, `.gitattributes:1` |

- 현재 완성도 추정: **약 65%**. 마크업·접근성 기본(aria-expanded, `prefers-reduced-motion`, `loading="lazy"`, width/height)이 5개 중 가장 잘 갖춰졌다. 그러나 미디어 전송량(초기 로드 약 260MB)이 배포 불가 수준이고, 실제 사진이 전부 플레이스홀더이며, "프로젝트" 섹션이 존재하지 않는다.
- 핵심 기능: 고정 네비+모바일 메뉴, 히어로 영상, 통계 스트립, 스크롤 핀 프레임 시퀀스(텍스트 3단계), 회사소개 벤토 5카드, 서비스 지그재그 2+카드 2, CTA 영상 배너(mailto), 푸터.

## 2. 구조 분석

### Biz_Website

| 경로 | 역할 |
|---|---|
| `Biz_Website/dist/index.html` | 빌드된 진입 HTML(lang=ko, description 메타 있음, `#root` 마운트) |
| `Biz_Website/dist/assets/index-R8aSe9M1.js` | React 번들 171KB(해시 1종만 존재 -> 단일 빌드) |
| `Biz_Website/dist/assets/index-BO-aMU7M.css` | Tailwind 산출 CSS 22KB |
| `Biz_Website/node_modules/` | 89MB, 98개 패키지(ignored) |

데이터 흐름: 정적 SPA. 소스가 없어 더 이상 추적 불가. `node_modules/.package-lock.json` 의 패키지명 `platform-website` 로 원본 리포를 찾는 것이 유일한 단서다.

### Botanic_Architecture

| 경로 | 역할 |
|---|---|
| `Botanic_Architecture/PRD.md` | 제품 요구사항(7섹션, 디자인 시스템, GEO 전략, 비기능 요구) |
| `Botanic_Architecture/CLAUDE.md` | 코드 생성 지시서(Tailwind 전용, lucide, JSON-LD 스키마). 실제 구현과 불일치 |
| `Botanic_Architecture/Images/floria-top.webp`, `floria-bottom.webp` | 디자인 레퍼런스 캡처 473KB(사이트에서 미사용, 커밋됨) |
| `floria/index.html` | Vite 진입. `lang="en"`, `<title>floria</title>`, 메타/OG/JSON-LD 없음 |
| `floria/src/main.jsx` | StrictMode 마운트 |
| `floria/src/App.jsx` (904줄) | Header/Hero/CuratedAssemblages/ArchitectureOfNature/TheArchives/Clarity/BrandEthos/CTABanner/Footer 전부 단일 파일, 인라인 style |
| `floria/src/index.css` | 리셋 + 폰트 `@import` + 미사용 반응형 클래스(`:96-110`) |
| `floria/public/` | favicon.svg, icons.svg 만 존재 — App.jsx 가 참조하는 `/Hero-bg.jpeg`, `/prod1~3.jpg`, `/arch-bg.jpeg`, `/archive4~8.jpg` 없음 |
| `floria/capture*.mjs`, `verify.mjs`, `check_floria.mjs` | Playwright 디버그 스크립트(gitignore) |

데이터 흐름: 모든 콘텐츠(상품 3, 단계 3, 리뷰 5, 푸터 링크)가 `App.jsx` 상단 상수(`IMG`, `PRODUCTS`, `STEPS`, `REVIEWS`)에 하드코딩. 네비게이션은 `<button>` + `scrollIntoView` 로 앵커를 대체(URL 해시 없음). 뉴스레터 폼은 로컬 state 로 "등록됨" 표시만 한다.

### Floria_Neo

| 경로 | 역할 |
|---|---|
| `Floria_Neo/index.html` (405줄) | 전체 페이지. `<head>` 에 Tailwind Play CDN + config + 커스텀 CSS, `<body>` 에 7섹션 |
| `Floria_Neo/Hero-bg.jpg` (88KB) | 히어로 배경 — 그러나 `index.html:106` 인라인 style 이 외부 URL 로 덮어써 사실상 미사용 |
| `Floria_Neo/hero_original.jpg` (282KB) | 미사용 원본 |
| `Floria_Neo/Images` | 0바이트 **파일**(폴더가 아님) — 생성 실수 |

데이터 흐름: 없음(정적). 모든 내비·CTA 가 `href="#"`, 폼은 `action` 없이 GET 제출 -> 페이지 리로드.

### Floria_NEO_02

| 경로 | 역할 |
|---|---|
| `src/main.tsx` -> `src/App.tsx` | BrowserRouter, `Layout` 중첩 라우트 4개(`/`, `shop`, `subscription`, `classes`) |
| `src/components/layout/{Layout,Header,Footer}.tsx` | 공통 레이아웃. Header 의 `/contact`, Footer 의 `/journal` `/care` `/about` `/shipping` `/privacy` `/faq` 는 미정의 라우트 |
| `src/pages/{Home,Shop,Subscription,FlowerClass}Page.tsx` | 페이지. 리뷰/기프트/인스타 데이터는 페이지 내부 상수 |
| `src/components/shared/{Product,Class,Subscription,Testimonial}Card.tsx` | 도메인 카드 컴포넌트 |
| `src/components/ui/*` | shadcn(base-ui) 프리미티브 5종, accordion 만 사용 |
| `src/data/{products,classes,subscriptions}.ts` | 타입 + 목 데이터 |
| `src/index.css` | Tailwind v4 `@theme` 디자인 토큰(sage/cream/gold 등) — 그러나 컴포넌트는 `#6B7C5C` 같은 hex 를 직접 사용 |
| `src/App.css`, `src/assets/{hero.png,react.svg,vite.svg}`, `README.md` | Vite 템플릿 잔재(App.css 는 어디서도 import 되지 않음) |
| `dist/` | 로컬 빌드 산출물(ignored) |

데이터 흐름: 정적 목 데이터 -> 페이지 -> 카드. Shop 은 `useState` 2개로 필터/정렬. 위시리스트(`ProductCard.tsx:12`)는 카드 로컬 state 로 새로고침 시 소멸. 모든 "Start Subscription / Book Seat / Quick View / Request Custom Bouquet" 버튼은 핸들러가 없다.

### Lucury Website

| 경로 | 역할 |
|---|---|
| `index.html` (338줄) | 시맨틱 마크업(nav/section/article/header/footer), `lang="ko"`, description 메타 |
| `css/style.css` (1,306줄) | 토큰, 레이아웃, 반응형 3단계(1024/768/480), reduced-motion |
| `js/main.js` (316줄) | GSAP 초기상태·히어로 타임라인·네비 스크롤·버거·150프레임 프리로드·ScrollTrigger 핀 |
| `HeroMov/hero_archi_01.mp4` 112MB | 히어로 배경(`index.html:48`) |
| `HeroMov/hero_archi_03.mp4` 124MB | CTA 배경(`index.html:271`) |
| `HeroMov/hero_archi_02.mp4` 17.8MB | HTML 에서 미참조(프레임 추출 원본, `main.js:4`) |
| `assets/frames/frame_0001~0150.jpg` 23MB | 캔버스 스크럽용 프레임 |
| `assets/README.txt` | "hero.mp4 / mid.mp4 를 넣으라"는 안내 — 실제 파일명과 불일치(구 버전 문서) |
| `.git/`, `.gitattributes` | 중첩 리포 + LFS. `.git/lfs/objects` 에 mp4 3개가 그대로 복제되어 폴더 총 529MB |

데이터 흐름: 로드 시 `preloadFrames()` 가 150장을 동시에 요청하고 전부 완료된 뒤에만 `initFrameScroll()` 로 핀 타임라인을 만든다(`main.js:227-250`). 그 전까지 스크롤 섹션은 로더 화면이다. 영상 2개는 `autoplay preload="auto"` 로 로드 즉시 다운로드된다.

### Floria 3종의 관계

| 항목 | Botanic_Architecture/floria | Floria_Neo | Floria_NEO_02 |
|---|---|---|---|
| 브랜드 | Floria(다크) | Floria(다크) | Flora Sentiment(라이트) |
| 섹션 구성 | 7섹션 랜딩 | 동일 7섹션 | 4페이지 커머스 |
| 구현 | React+inline style | HTML+Tailwind CDN | React+TS+Tailwind v4+router |
| 이미지 | 로컬(누락)+Unsplash | googleusercontent 임시 | Unsplash |
| 가격 표기 | ₩180,000 | $145 | ₩85,000 |
| 로컬 소싱 문구 | 80km | 50마일 | 없음 |
| git | 추적 | 미추적 | 미추적 |

Botanic 과 Floria_Neo 는 같은 디자인(`Images/floria-top.webp`, `floria-bottom.webp`)에서 나온 두 벌의 구현이며 카피·가격·단위까지 서로 어긋나 있다. Floria_NEO_02 는 이름만 비슷한 별개 브랜드로, 셋 중 유일하게 재사용 가능한 아키텍처를 가진다.

## 3. 발견된 문제점

| # | 심각도 | 분류 | 위치(경로:줄) | 내용 |
|---|---|---|---|---|
| 1 | 높음 | 성능 | `Lucury Website/index.html:47-48`, `:270-271` | 4K 112MB(25Mbps, 오디오 포함)와 4K 124MB(94Mbps) mp4 를 `autoplay preload="auto"` 로 동시 로드. 초기 전송 약 236MB, poster/WebM/모바일 분기 없음 |
| 2 | 높음 | 성능 | `Lucury Website/js/main.js:227-250`, `assets/frames/` | 150장 JPEG(23MB)를 한 번에 전량 프리로드하고 완료 전까지 섹션을 로더로 가림. 리사이즈/WebP/점진 로딩 없음 |
| 3 | 높음 | 버그 | `Botanic_Architecture/floria/src/App.jsx:16-24,195` vs `floria/public/` | `/Hero-bg.jpeg`, `/prod1~3.jpg`, `/arch-bg.jpeg`, `/archive4~8.jpg` 10개 파일이 public/ 에 없음(favicon.svg, icons.svg 만 존재). 히어로·상품·아카이브 이미지 전부 깨짐 |
| 4 | 높음 | 품질 | `Botanic_Architecture/floria/src/App.jsx:241,421,567,571,646,817`, `src/index.css:96-110` | 그리드가 인라인 `gridTemplateColumns: '55% 45%'`, `'repeat(3,1fr)'` 등 고정값. index.css 의 반응형 클래스(`.hero-grid` 등)는 어떤 요소에도 부여되지 않아 데드코드. 모바일에서 3열 상품/리뷰/푸터가 그대로 노출 |
| 5 | 높음 | 구조 | `Biz_Website/` | 소스 없음. dist/ 와 node_modules/ 만 있고 둘 다 루트 `.gitignore:6,11` 로 제외되어 리포에 흔적이 0. 로컬 폴더 유실 시 사이트 복구 불가 |
| 6 | 높음 | 설정 | `Floria_Neo/index.html:5`, `:41,46,106,141,143,145,150,196,203,210,217,226` | Tailwind Play CDN(프로덕션 비권장, 런타임 컴파일) + `lh3.googleusercontent.com/aida-public/` 임시 서명 URL 12개. 만료 시 전 이미지 소실 |
| 7 | 높음 | 버그 | `Floria_NEO_02/src/App.tsx:11-17`, `Header.tsx:9`, `Footer.tsx:19-31` | `/contact` `/journal` `/care` `/about` `/shipping` `/privacy` `/faq` 라우트 미정의, catch-all 없음 -> 해당 링크 클릭 시 Layout 조차 렌더되지 않는 완전 빈 화면 |
| 8 | 높음 | 구조 | `Lucury Website/.git/config`, `.gitattributes:1` | 모노레포 안에 중첩 git 리포 + LFS. `.git/lfs/objects` 가 mp4 254MB 를 복제해 폴더 529MB. 상위 리포에 `git add` 하면 포인터만 들어가는 임베디드 리포가 되어 추적 불가 |
| 9 | 중간 | 성능 | `Lucury Website/HeroMov/hero_archi_02.mp4` | 17.8MB 영상이 HTML 에서 참조되지 않음(프레임 추출 원본). 배포 번들에 불필요 |
| 10 | 중간 | 품질 | `Lucury Website/index.html:144,168,212,225,239,249` | `picsum.photos/seed/...` 랜덤 플레이스홀더가 "대표 건축물", "건설 현장" 으로 노출. 외부 의존 + 브랜드 신뢰도 훼손 |
| 11 | 중간 | 버그 | `Lucury Website/index.html:25,61,288,309` | 네비 "프로젝트", 히어로 "포트폴리오 보기", 푸터 "포트폴리오" 가 `#projects` 로 가는데 `#projects` 는 `<footer>` 의 id. 프로젝트 섹션이 없음 |
| 12 | 중간 | 접근성 | `Lucury Website/css/style.css:16` + 사용처 `:413-414,551,796,846,900,1038,1052,1075,1086,1096` | `--text-muted: #424040` 이 `#080808` 위에서 대비 약 1.9:1 (WCAG AA 4.5:1 미달). eyebrow, 라벨, 푸터 저작권·약관 링크 등 10곳 |
| 13 | 중간 | 접근성 | `Botanic_Architecture/floria/src/App.jsx:288,406,475,499,562,626,695,798,858,864` | `#5a5a5a`(2.9:1), `#4a4a4a`(2.3:1), `#484848`, `#404040`(1.9:1), `#3a3a3a`(1.8:1), `#282828`, `#2a2a2a` 본문/리뷰 직함/푸터가 모두 AA 미달 |
| 14 | 중간 | 접근성 | `Botanic_Architecture/floria/src/App.jsx:113-116,127-128,302-303` 등 | hover 를 `onMouseOver/onMouseOut` 으로 style 직접 변경 -> 키보드 포커스에 대응 없음, focus 표시 없음. 네비는 `<button>` 으로 앵커 URL 미생성 |
| 15 | 중간 | 접근성 | `Floria_NEO_02/src/components/layout/Header.tsx:43-54`, `shared/ProductCard.tsx:46-54` | 아이콘 전용 버튼(Heart, ShoppingBag, Menu, 위시리스트)에 `aria-label` 없음. 프로젝트 전체에서 aria/loading 속성 1건 |
| 16 | 중간 | 성능 | `Botanic_Architecture/floria/src/App.jsx:194-204,368,528`, `Floria_NEO_02/src/pages/HomePage.tsx:85-90,139-143,184-188,225-229`, `Floria_Neo/index.html:141-217` | 모든 `<img>` 에 `loading="lazy"`, `width/height`, `srcset` 없음 -> CLS 및 불필요 다운로드. 히어로는 1600~1800px Unsplash 원본 1장 |
| 17 | 중간 | 성능 | `Botanic_Architecture/floria/src/index.css:1`, `Floria_NEO_02/src/index.css:1`, `Lucury Website/index.html:8-10` | Google Fonts 를 CSS `@import` 로 로드(렌더 블로킹, preconnect 없음). Lucury 는 Outfit 7가중치+Mono 2가중치, Botanic 은 Playfair 6+Inter 6 가중치 |
| 18 | 중간 | 구조 | `Botanic_Architecture/floria/vite.config.js:3,6`, `package.json:32,41`, `src/index.css` | Tailwind v4 플러그인·패키지가 설치·등록되어 있으나 CSS 에 `@import "tailwindcss"` 가 없고 className 도 1곳. 번들에 영향은 없지만 CLAUDE.md §1 "Tailwind 전용" 지시와 정면 불일치 |
| 19 | 중간 | 품질 | `Botanic_Architecture/CLAUDE.md §4`, `PRD.md §4`, `floria/index.html` | PRD/CLAUDE.md 가 핵심 목표로 둔 JSON-LD(LocalBusiness) 및 GEO 메타가 전혀 구현되지 않음. `lang="en"`, `<title>floria</title>`, description/OG 없음 |
| 20 | 중간 | 버그 | `Floria_Neo/index.html:69-74` | `.testimonial-grid { grid-template-columns: repeat(3,1fr) }` 에 미디어쿼리 없음 -> 모바일에서 3열 리뷰 카드 |
| 21 | 중간 | 버그 | `Floria_Neo/index.html:35` vs `:106` | `.hero-bg` 가 로컬 `Hero-bg.jpg` 를 지정하지만 같은 요소의 인라인 `style` 이 외부 URL 로 덮어씀. 로컬 이미지 2개(370KB) 모두 미사용. `Floria_Neo/Images` 는 0바이트 파일 |
| 22 | 중간 | 버그 | `Floria_NEO_02/src/pages/ShopPage.tsx:19-23` | 정렬 비교자가 "Newest" 에서 `b.isNew ? 1 : -1` 만 반환 — `a` 를 보지 않고 0 을 반환하지 않아 비일관(두 항목 모두 new 또는 모두 old 일 때 순서 뒤집힘) |
| 23 | 중간 | 설정 | `Floria_NEO_02/index.html:2,7`, `package.json:2`, `dist/index.html:7` | `lang="en"` 에 한국어 h1(`HomePage.tsx:94-95`), `<title>temp-init</title>`, 패키지명 `temp-init`, 메타/OG/favicon 외 SEO 없음 |
| 24 | 중간 | 설정 | `Floria_NEO_02/src/App.tsx:10` | BrowserRouter 사용인데 정적 호스팅용 SPA 리라이트 설정(`vercel.json`/`_redirects`/`404.html`) 없음 -> 새로고침 시 404. 329KB 단일 번들, `React.lazy` 없음 |
| 25 | 낮음 | 품질 | `Floria_NEO_02/src/App.css`, `src/assets/{hero.png,react.svg,vite.svg}`, `README.md` | Vite 템플릿 잔재. App.css 는 import 되지 않음 |
| 26 | 낮음 | 품질 | `Floria_NEO_02/src/pages/HomePage.tsx:4-12` = `Footer.tsx:4-12`; `src/index.css:8-35` vs `Header.tsx:17,20,32` 등 | `InstagramIcon` 중복 정의. `@theme` 토큰(`--color-sage` 등)을 정의해 두고 컴포넌트는 `#6B7C5C`, `#FAF7F2` hex 를 직접 사용 — 토큰 이중화 |
| 27 | 낮음 | 접근성 | `Floria_NEO_02/src/pages/HomePage.tsx:115,151,175` 등 | `text-[#6B7C5C]`(세이지) on `#FAF7F2` 대비 약 4.2:1 — `text-xs` eyebrow 에 사용되어 AA 미달 |
| 28 | 낮음 | 품질 | `Botanic_Architecture/floria/src/App.jsx:9-12,15` | 상수 `B,C,D,E`, `IMG.hero` 미사용. `lucide-react` 가 devDependencies(`package.json:40`). `<h2>` 다음 `<h5>`(`:380`) 헤딩 레벨 건너뜀 |
| 29 | 낮음 | 품질 | `Botanic_Architecture/floria/src/App.jsx:885-889` | `.order-btn` 을 모바일에서 숨기는 CSS 가 있지만 어떤 요소에도 `className="order-btn"` 이 없음. `nav { display:none }` 전역 선택자도 과도 |
| 30 | 낮음 | 품질 | `Botanic_Architecture/CLAUDE.md:3` | "대상: Claude 3.5 Sonnet", Unsplash 하드코딩 권장 등 지시서가 구현과 어긋나고 오래됨 |
| 31 | 낮음 | 설정 | `Lucury Website/index.html:334-336`, `:324` | GSAP CDN 스크립트에 `defer`/`integrity` 없음. 저작권 "2024 한울건설"(© 누락, 연도 고정). `assets/README.txt` 가 존재하지 않는 `hero.mp4/mid.mp4` 를 안내 |
| 32 | 낮음 | 품질 | `Lucury Website/css/style.css:1126,1138` | `.hero-btn`, `.scroll-video` 선택자가 HTML 에 없음(데드 CSS). 폴더명 `Lucury` 와 브랜드 `한울건설` 불일치 |
| 33 | 낮음 | 품질 | 모든 사이트 | 폼이 백엔드 없이 동작: Botanic `App.jsx:710-713`(state만), NEO_02 3곳 `preventDefault`, Floria_Neo `index.html:324`(핸들러 없음 -> GET 리로드), Lucury 는 `mailto:` 만 |
| 34 | 낮음 | 설정 | `WebSite/.vite/deps_temp_110532ef/` | WebSite 루트에서 vite 가 실행된 캐시 잔재. 삭제 대상 |

### 심각도 높음 상세

**#1 Lucury 히어로/CTA 영상 236MB.** `hero_archi_01.mp4` 는 3840x2160, 35.9초, 25Mbps 에 AAC 오디오 트랙까지 포함(muted 로 재생하므로 오디오는 순수 낭비)이고, `hero_archi_03.mp4` 는 10초짜리인데 94Mbps 로 인코딩되어 124MB 다. 두 영상 모두 `preload="auto" autoplay` 라 페이지 진입 즉시 다운로드가 시작되어 모바일 데이터 환경에서는 사이트가 사실상 열리지 않는다. 1080p/4~6Mbps H.264 + AV1/VP9 WebM 2종, `poster` 이미지, `preload="metadata"`, `matchMedia('(max-width: 768px)')` 에서 영상 미삽입으로 바꾸면 10MB 이하로 줄일 수 있다.

**#2 Lucury 150프레임 전량 프리로드.** `preloadFrames()` 는 150개 `Image` 를 동시에 생성해 23MB 를 요청하고 `loadedCount === FRAME_COUNT` 가 될 때까지 `initFrameScroll()` 을 호출하지 않는다. 느린 회선에서는 스크롤 섹션이 수십 초간 "Loading" 으로 멈춘다. 프레임을 960px WebP(장당 20~30KB)로 재추출하고, 초기 10장만 로드한 뒤 나머지를 `requestIdleCallback` 으로 채우거나, 아예 `<video>` 의 `currentTime` 을 스크롤에 바인딩하는 방식으로 교체하는 것이 적절하다.

**#3 Botanic 로컬 이미지 10개 누락.** `IMG` 맵과 Hero 의 `<img src="/Hero-bg.jpeg">` 가 가리키는 파일이 `public/` 에 없다. 커밋 `0b7f3fa` 이후 두 번의 스타일 수정 커밋이 있었지만 이미지는 한 번도 추적되지 않았으므로 로컬에만 있다가 유실되었거나 처음부터 추가되지 않은 것이다. 현재 클론해서 실행하면 히어로 배경, 상품 3개, Architecture 배경, 아카이브 5개가 모두 깨진 이미지 아이콘으로 표시된다.

**#4 Botanic 반응형 부재.** `index.css:96-110` 에 `.hero-grid`, `.prod-grid`, `.archive-row1/2`, `.clarity-grid`, `.footer-grid` 미디어쿼리가 준비되어 있지만 `App.jsx` 는 해당 클래스를 어디에도 부여하지 않고 인라인 `gridTemplateColumns` 고정값을 쓴다. 인라인 style 은 외부 CSS 보다 우선순위가 높기 때문에 클래스를 붙여도 `!important` 없이는 덮어쓸 수 없다. 결과적으로 PRD §6 "모바일에서 카드 그리드가 세로로 떨어져야 한다" 요구가 전혀 충족되지 않는다.

**#5 Biz_Website 소스 부재.** 폴더에는 `dist/`(196KB)와 `node_modules/`(89MB)만 있고 `src/`, `index.html`, `package.json`, 설정 파일이 없다. 둘 모두 루트 `.gitignore` 에 걸려 git 에서는 폴더 자체가 보이지 않는다. 즉 리포를 클론한 다른 환경에서는 이 사이트가 존재하지 않으며, 로컬 디스크가 손상되면 복구 수단이 없다. `node_modules/.package-lock.json` 의 패키지명 `platform-website` 로 원본 위치를 먼저 찾고, 없으면 dist 를 참고해 재구현하거나 폴더를 정리해야 한다.

**#6 Floria_Neo 임시 이미지 URL + Play CDN.** `lh3.googleusercontent.com/aida-public/AB6AXu...` 형식 URL 은 AI 디자인 도구가 발급한 서명 URL 로 영구 호스팅이 보장되지 않는다. 또한 `cdn.tailwindcss.com` 은 브라우저에서 Tailwind 를 런타임 컴파일하는 개발용 스크립트로, 공식 문서가 프로덕션 사용을 금지한다(약 400KB JS, FOUC). 이 파일은 프로토타입으로만 취급하고 디자인 레퍼런스/카피 소스로 활용한 뒤 폐기하는 것이 맞다.

**#7 Floria_NEO_02 미정의 라우트.** `Routes` 안에 4개 라우트만 있고 `path="*"` 가 없다. react-router 는 매칭되는 라우트가 없으면 아무것도 렌더하지 않으므로 Header 의 "Contact", Footer 의 7개 링크를 클릭하면 헤더·푸터까지 사라진 백지가 뜬다. 최소한 `NotFound` 와 `/contact` 페이지, 나머지는 준비 중 안내 또는 링크 제거가 필요하다.

**#8 Lucury 중첩 git + LFS.** `Lucury Website/.git` 은 `github.com/DevOps0906/Lucury_Website.git` 을 origin 으로 하는 독립 리포이며 mp4 는 LFS 포인터다. 모노레포 `platform` 에서 이 폴더를 `git add` 하면 git 은 커밋 해시 하나만 기록하는 임베디드 리포(서브모듈 아님)로 취급하여 내용이 추적되지 않는다. `.git/lfs/objects` 에 영상 원본이 통째로 복제되어 디스크도 2배를 쓴다. 서브모듈로 공식화하거나 `.git` 을 제거해 모노레포로 편입하고 영상은 CDN/오브젙트 스토리지로 분리하는 결정이 선행되어야 한다.

## 4. 효율성 개선 제안

### 구조/아키텍처

- **Floria 3종 통합.** Botanic_Architecture/floria(디자인 정답, 반응형·이미지 미완)와 Floria_Neo(프로토타입)는 하나로 합치고, Floria_NEO_02 의 기술 스택(TS + Tailwind v4 `@theme` + router + `data/` 레이어)을 공통 베이스로 삼는다. 권장 구조: `WebSite/floria/` 단일 Vite 프로젝트에 `/`(Botanic 다크 랜딩) 과 `/shop`, `/subscription`, `/classes`(Flora Sentiment 페이지)를 라우트로 두고, 다크/라이트를 `@theme` 토큰 세트 2개로 분리한다. Flora Sentiment 가 실제로 별도 클라이언트라면 폴더명을 `Flora_Sentiment` 로 바꿔 혼동을 끊는다.
- **콘텐츠를 데이터 파일로.** Botanic 의 `PRODUCTS/STEPS/REVIEWS`, Floria_Neo 의 하드코딩 카피, NEO_02 의 페이지 내부 `testimonials/giftOptions` 를 `src/data/*.ts` 로 모으면 카피·가격·단위(₩ vs $, 80km vs 50마일) 불일치가 한 곳에서 해결된다.
- **Botanic 단일 904줄 파일 분해.** 섹션별 컴포넌트 파일 + 공용 `Section`, `FadeIn` 래퍼로 분리. 인라인 style 객체 대신 Tailwind 클래스(이미 설치됨)로 전환하면 hover/focus/반응형이 선언적으로 해결된다.
- **Lucury 리포 경계 정리.** 서브모듈(`git submodule add`) 또는 `.git` 제거 후 모노레포 편입 중 하나를 택하고, 폴더명을 `Hanul_Construction` 으로 정정한다. 영상·프레임은 리포 밖(S3/R2/Vercel Blob)으로 옮기고 리포에는 poster 와 저해상도 대체본만 둔다.
- **Biz_Website 처리 결정.** 원본 소스가 다른 경로/리포에 있는지 확인(패키지명 `platform-website`). 없으면 dist 를 레퍼런스로 Vite+React+Tailwind 로 재구현하고, 그것도 아니면 폴더를 삭제해 혼란을 제거한다.

### 성능

- 영상: 1080p 4~6Mbps H.264(mp4) + AV1 또는 VP9(webm) 2소스, 오디오 트랙 제거, `poster` 지정, `preload="metadata"`, 모바일/`prefers-reduced-data` 에서 `<source>` 미삽입. 길이도 10~15초 루프로 컷.
- 프레임 시퀀스: 150장 -> 960px WebP(또는 AVIF), 총 3~4MB 목표. 초기 N장만 로드 후 백그라운드 로드, 또는 `<video>` scrub 로 대체.
- 이미지 공통: 로컬 WebP/AVIF 변환, `width/height` 명시, 첫 화면 외 `loading="lazy" decoding="async"`, `srcset/sizes` 로 상품 카드 600px 급 제공. Vite 프로젝트는 `vite-imagetools` 또는 빌드 전 `sharp` 스크립트로 자동화.
- 폰트: CSS `@import` 대신 `<link rel="preconnect">` + `<link rel="stylesheet">`(또는 self-host + `font-display: swap`), 가중치는 실제 사용 3~4개로 축소. Botanic 의 `Pretendard` 는 선언만 있고 로드하지 않으므로(`App.jsx:54`) 로드 추가 또는 제거.
- 외부 CDN 의존 제거: Tailwind Play CDN(Floria_Neo), picsum(Lucury), googleusercontent(Floria_Neo). GSAP 는 npm 번들 또는 `defer` + SRI.
- NEO_02: 라우트별 `React.lazy` + `Suspense` 로 329KB 번들 분할. `@base-ui/react` 는 accordion 만 쓰므로 트리셰이킹 확인.

### 개발 생산성

- 공통 베이스 템플릿(Vite + React + TS + Tailwind v4 + ESLint + `@/` alias)을 하나 두고 모든 마케팅 사이트가 이를 복제하도록 한다(현재 Botanic 은 JSX, NEO_02 는 TSX, 나머지는 순수 HTML 로 제각각).
- 메타/OG/JSON-LD 를 생성하는 공용 `Seo` 컴포넌트(또는 `index.html` 템플릿)를 만들어 `lang`, title, description, og:image, canonical, LocalBusiness 스키마를 한 번에 해결.
- 중복 제거: NEO_02 `InstagramIcon` 2곳, 디자인 토큰 hex 직접 사용 -> `bg-primary`, `text-muted-foreground` 등 토큰 클래스. Botanic 의 hover 핸들러 수십 개 -> `hover:` 유틸.
- 템플릿 잔재 정리: NEO_02 `App.css`, `assets/hero.png`, `react.svg`, `vite.svg`, Vite README, `temp-init` 이름. Botanic 디버그 `.mjs` 5종은 `scripts/` 로 이동하거나 삭제.
- 타입/린트: Botanic 을 TS 로 전환(NEO_02 와 동일 설정 재사용), `lucide-react` 를 dependencies 로 이동.

### 운영/배포

- 각 Vite 프로젝트에 GitHub Actions(`npm ci && npm run lint && npm run build`) + Lighthouse CI 예산(LCP 2.5s, 총 전송 2MB 등). Lucury 는 영상 교체 전까지 배포 차단 기준으로 사용.
- SPA 호스팅 설정 파일(`vercel.json` rewrites 또는 Netlify `_redirects`)을 NEO_02 에 추가.
- 폼 백엔드: 뉴스레터/문의를 Vercel Function 또는 Supabase Edge Function 하나로 통일하고 각 사이트가 같은 엔드포인트를 호출(허니팟 + rate limit).
- Biz_Website 의 dist 는 소스 복구 전까지 별도 보관(zip 아카이브는 `.gitignore:40` 으로 제외되므로 리포 외부 저장소에).

## 5. 수정 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 예상 규모 | 권장 모델 | 선정 이유 |
|---|---|---|---|---|---|
| 1 | Lucury 영상 최적화: `hero_archi_01/03` 을 1080p H.264 4~6Mbps + WebM 으로 ffmpeg 트랜스코딩(오디오 제거, 15초 컷), `poster` 추가, `preload="metadata"`, 768px 이하에서 `<source>` 미삽입 스크립트, `hero_archi_02.mp4` 및 `assets/README.txt` 삭제 | P0 | M | Sonnet 5.5 | 명확한 에셋 변환·속성 수정 작업. 판단 요소 적음 |
| 2 | Botanic 누락 이미지 복구: `public/` 에 Hero-bg, prod1~3, arch-bg, archive4~8 을 WebP 로 추가(`Images/*.webp` 레퍼런스 또는 라이선스 확인된 사진), `IMG` 맵 정리, 미사용 상수 `B~E`, `IMG.hero` 제거, `width/height/loading` 부여 | P0 | S | Sonnet 5.5 | 파일 배치와 속성 추가 위주의 반복 작업 |
| 3 | Botanic 반응형 복원: 인라인 `gridTemplateColumns` 를 `className` + `index.css` 미디어쿼리(또는 Tailwind `md:` 유틸)로 전환, `.order-btn` 클래스 적용, 히어로 패딩/폰트 clamp 모바일 검증 | P0 | M | Sonnet 5.5 | UI/스타일 수정. 설계 변경 없음 |
| 4 | Biz_Website 소스 복원 또는 재구현: `platform-website` 원본 탐색 -> 없으면 dist 를 레퍼런스로 Vite+React+Tailwind 스캐폴드에 히어로/기능 6카드/대시보드 목업/모바일 메뉴 재구현, `src/` 를 커밋 | P0 | L | Opus 5.5 | 사양이 번들 문자열로 명확히 남아 있는 중간 규모 재구현. 아키텍처 판단은 적음 |
| 5 | Lucury 리포 경계 정리: 서브모듈화 또는 `.git` 제거 후 모노레포 편입 결정·실행, LFS 객체 정리, 영상을 외부 스토리지로 이전하고 URL 참조로 전환, 폴더명 `Hanul_Construction` 변경 | P1 | S | Opus 5.5 | 작업량은 작지만 git 히스토리·LFS 원본 유실 위험이 있어 한 단계 상위 모델 |
| 6 | Lucury 프레임 시퀀스 최적화: 150장 -> 960px WebP 재추출, 초기 10장 로드 후 `requestIdleCallback` 점진 로드, 로더를 첫 프레임 표시로 대체(또는 `<video>` currentTime 스크럽으로 교체), `drawFrame` DPR 대응 | P1 | M | Opus 5.5 | 로딩 전략 변경과 GSAP 타임라인 수정이 얽힌 중간 난이도 |
| 7 | Floria 3종 통합 설계 및 골격: `WebSite/floria` 단일 프로젝트(NEO_02 베이스)로 Botanic 다크 랜딩을 `/` 라우트·다크 토큰 세트로 포팅, `data/` 레이어로 카피·가격·단위 일원화, Floria_Neo 는 카피 추출 후 삭제, PRD/CLAUDE.md 를 새 구조에 맞게 갱신 | P1 | L | Fable 5.1 | 세 코드베이스를 가로지르는 아키텍처 재설계와 디자인 토큰/데이터 모델 통합 |
| 8 | SEO/GEO 공통 적용: 4개 사이트 `lang` 정정, title/description/OG/twitter/canonical/favicon, Botanic 에 PRD 의 LocalBusiness JSON-LD, `robots.txt`/`sitemap.xml`, NEO_02 `temp-init` 명칭 교체 | P1 | S | Sonnet 5.5 | 보일러플레이트 성격의 메타 작업 |
| 9 | 접근성 수정: 대비 미달 색상(Botanic `#4a4a4a` 계열, Lucury `--text-muted`, NEO_02 세이지 eyebrow)을 4.5:1 이상으로 조정, 아이콘 버튼 `aria-label`, Botanic 헤딩 레벨(h5->h3)·focus-visible·네비 `<a href="#id">` 전환, Floria_Neo 리뷰 그리드 반응형 | P1 | M | Sonnet 5.5 | 규칙이 명확한 UI 수정의 반복 |
| 10 | NEO_02 라우팅 보강: `/contact`, `/about`, `/faq`, `/privacy`, `/shipping` 페이지(최소 콘텐츠) + `*` NotFound, 라우트별 `React.lazy`, `vercel.json` rewrites, 미구현 링크(`/journal`, `/care`) 제거 또는 준비 중 처리 | P1 | M | Opus 5.5 | 2~5개 파일에 걸친 명확한 기능 구현 |
| 11 | 폼 백엔드 연동: 뉴스레터/문의 공용 서버리스 엔드포인트(Vercel Function 또는 Supabase) + 이메일 검증·허니팟·rate limit, Botanic `CTABanner`, NEO_02 3곳, Lucury CTA(mailto->폼) 연결, 성공/실패 UI | P2 | M | Opus 5.5 | 외부 API 연동과 입력 검증, 스팸 대응 설계 포함 |
| 12 | Botanic 스타일 마이그레이션: 인라인 style 객체 -> Tailwind v4 클래스(`@import "tailwindcss"` 추가), `onMouseOver` 핸들러 제거(`hover:`/`focus-visible:`), 섹션별 파일 분리, TS 전환, `lucide-react` dependencies 이동 | P2 | L | Opus 5.5 | 단일 904줄 파일의 체계적 리팩토링. 동작 변경은 없으나 범위가 넓음 |
| 13 | NEO_02 코드 정리: 템플릿 잔재(App.css, hero.png, react.svg, vite.svg, README) 삭제, `InstagramIcon` 공용화, hex 직접 사용 -> `@theme` 토큰 클래스, `ShopPage` 정렬 비교자 수정(`Number(b.isNew) - Number(a.isNew)`), 위시리스트 localStorage 유지 | P2 | S | Sonnet 5.5 | 린트성 정리와 단순 버그 수정 |
| 14 | 폰트/외부 스크립트 로딩 최적화: 3개 사이트 `@import` -> `<link preconnect>` + `<link>`(또는 self-host), 가중치 3~4개로 축소, Botanic `Pretendard` 로드 또는 제거, Lucury GSAP `defer` + SRI, picsum -> 실제 사진(WebP) 교체 | P2 | S | Sonnet 5.5 | 설정 파일·태그 수정 중심 |
| 15 | CI/품질 게이트: 각 Vite 프로젝트 GitHub Actions(lint/tsc/build), Lighthouse CI 예산(LCP, 총 전송량), 이미지 최적화 스크립트(sharp) 공용화, `WebSite/.vite` 캐시 삭제 및 `.gitignore` 점검 | P2 | M | Sonnet 5.5 | 보일러플레이트 워크플로 작성 |

## 6. 종합 평가

### 강점 3개

1. **Lucury Website 의 마크업·접근성 기본기.** `lang="ko"`, description 메타, `aria-expanded/aria-hidden` 토글(`js/main.js:48-49`), `prefers-reduced-motion` 분기(`main.js:9`, `style.css:1122-1156`), `loading="lazy"` + `width/height`, 3단계 미디어쿼리, CSS 변수 토큰 — 5개 사이트 중 가장 올바른 정적 사이트 뼈대다.
2. **Floria_NEO_02 의 코드 구조.** TS 타입이 있는 `data/` 레이어, 레이아웃/공용 카드/UI 프리미티브 분리, `@theme` 토큰, 필터·정렬·품절 같은 실제 상태 로직. 통합의 기술 베이스로 바로 쓸 수 있다.
3. **Botanic_Architecture 의 기획 문서.** PRD 와 구현 지시서가 섹션·카피·GEO 전략·비기능 요구까지 구체적이라 통합 후에도 요구사항 원본으로 유효하다. `useFadeIn` 훅처럼 재사용 가능한 작은 조각도 있다.

### 약점 3개

1. **미디어 자산 관리 부재.** Lucury 는 260MB 를 초기 로드하고, Botanic 은 이미지 10개를 리포에 넣지 않았고, Floria_Neo 는 만료 가능한 임시 URL 에 의존한다. WebP/AVIF 변환, lazy loading, srcset 이 어느 사이트에도 없다.
2. **같은 디자인의 3중 구현과 소스 유실.** Floria 가 3개 폴더에 흩어져 카피·가격·단위가 어긋나고, Biz_Website 는 소스 없이 빌드만 남았으며, Lucury 는 중첩 리포라 모노레포에서 추적되지 않는다. 5개 중 git 으로 온전히 관리되는 것은 Botanic 1개뿐이다.
3. **SEO/접근성 마감 부족.** 4개 사이트가 `lang="en"` 또는 메타/OG 없음, 다크 테마 본문 대비 1.8~2.9:1, 아이콘 버튼 라벨 없음, 비동작 폼과 `href="#"` 링크 다수. 마케팅 사이트의 목적(검색 노출·전환)에 직접 영향을 준다.

### 모델별 작업 비율

| 모델 | 작업 번호 | 비율 |
|---|---|---|
| Fable 5.1 | 7 | 1/15 ≈ 7% |
| Opus 5.5 | 4, 5, 6, 10, 11, 12 | 6/15 = 40% |
| Sonnet 5.5 | 1, 2, 3, 8, 9, 13, 14, 15 | 8/15 ≈ 53% |

### 권장 진행 순서

1. **1단계(배포 가능 상태 확보, P0):** 작업 1(Lucury 영상) -> 2(Botanic 이미지) -> 3(Botanic 반응형) -> 4(Biz_Website 소스 복원/결정). 이 네 가지가 끝나기 전에는 어느 사이트도 외부에 공개할 수 없다.
2. **2단계(구조 정리, P1):** 작업 5(Lucury 리포 경계) -> 7(Floria 통합 골격, Fable) -> 10(NEO_02 라우팅) -> 6(프레임 시퀀스) -> 8(SEO) -> 9(접근성). 7 이 끝난 뒤 8·9 를 통합된 코드베이스에 한 번만 적용한다.
3. **3단계(마감·운영, P2):** 작업 11(폼 백엔드) -> 12(Botanic 스타일 마이그레이션, 7 에 흡수 가능) -> 13·14(정리/로딩 최적화) -> 15(CI/Lighthouse 예산).

### 주 담당 모델

이 폴더의 주 담당 모델은 **Sonnet 5.5** 가 적합하다. 15개 작업 중 8개가 UI/스타일·메타·에셋·설정 정리이고, 코드 규모가 작은 정적 마케팅 사이트들이라 작업 단위가 명확하다. 다만 작업 7(Floria 3종 통합 설계)은 세 코드베이스의 데이터 모델과 디자인 토큰을 하나로 합치는 결정이 필요하므로 Fable 5.1 이 설계와 골격을 먼저 만들고, 그 뒤 Opus 5.5 가 라우팅·폼 연동·프레임 로딩 전략 같은 중간 난이도 기능을 채우고, 나머지 마감 작업을 Sonnet 5.5 가 반복 처리하는 흐름이 비용 대비 가장 효율적이다.
