# 07 원본 이식과 폐기: Floria (website-floria)

작성일 2026-10-12. 원본 경로는 `WebSite/` 기준. 이 기획은 원본을 수정하지 않았고 git 쓰기 명령을 실행하지 않았다.

AI 관련 원본 자산(2026-10-13 점검): 원본에는 AI 기능이 없다. AI와 닿는 것은 (1) Botanic `PRD.md:15`의 GEO(생성형 검색 엔진 최적화) 전략 문장과 (2) Botanic `CLAUDE.md`(Claude 3.5용 코드 생성 지시서)뿐이다. RAG, 위키, Dify, 음성, 3D 히어로는 모두 원본에 없어 이 제품이 새로 만든다(02장 5절). 상담 지식(시공 사례, 식물 정보, FAQ)에 쓸 수 있는 원고도 원본 저장소에는 없다. 사례·식물·FAQ 자료는 운영자가 제공해야 하며(01장 D-11), 원본의 카피(PRD 7섹션)는 FAQ 후보 문장의 출처로만 참고한다. 원본의 가상 후기 5건과 50마일/80km 주장은 상담 지식에도 들어가지 않는다(금지 규칙 파일 `content/knowledge/rules/banned.json`이 막는다).

## 1. 원본별 자산 분류

### 1.1 Botanic_Architecture (베이스, 약 55%)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md` 7섹션 구성과 카피 | 기획만 | 이식(카피) | `src/content/` | `Botanic_Architecture/PRD.md:69-141` |
| `PRD.md` GEO 전략 | 기획만(코드 미구현) | 이식(실제 사업자 정보로 재작성). 생성형 검색 노출은 사이트 JSON-LD와 공개 지식 페이지 `/guide`(SI-06-042)로 잇는다 | `src/lib/seo/` | `PRD.md:15`, `:49-67`, 리뷰 `:200` |
| `PRD.md` 7섹션 카피 중 질문형 문장 | 기획만 | 참고(FAQ 후보). 증빙 없는 주장은 제외하고 운영자 검수 후 지식 원고로 | `content/knowledge/` | `PRD.md:69-141`, 01장 D-11 |
| `CLAUDE.md` 구현 지시서 | 오래됨 | 참고만(Claude 3.5 대상, 하드코딩 권장). AI 계층 지침은 이 폴더 `CLAUDE.md`가 대신한다 | - | 리뷰 `:211` |
| `floria/src/App.jsx` 904줄 | 부분(이미지 누락, 반응형 없음) | 참고 후 재작성 | `src/components/sections/` | 리뷰 `:114` |
| `useFadeIn` 훅 | 동작 | 폐기(전 섹션 페이드는 생성형 기본값 11번). 로드 리빌 1개로 대체 | - | 리뷰 `:295`, 03장 4.6절 |
| `Images/floria-top.webp`, `floria-bottom.webp` | 참고 캡처 473KB | 참고용 보관 | `archive/` | 리뷰 `:111` |
| `floria/capture*.mjs`, `verify.mjs` Playwright 스크립트 | 동작(디버그) | 이식(정식 e2e로 전환) | `tests/e2e/` | 리뷰 `:117`, `:259` |
| `floria/package.json` | 부분 | 참고(lucide-react가 devDependencies에 있는 오류 수정) | `package.json` | 리뷰 `:36` |

### 1.2 Floria_Neo (프로토타입, 약 40%)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `index.html` 한국어 카피 | 목업 | 참고(카피 비교 자료) | `src/content/` 확정 시 인용 | 리뷰 `:229` |
| Tailwind Play CDN, googleusercontent 이미지 | 목업 | 폐기 | - | 리뷰 `:187` |
| `Hero-bg.jpg`, `hero_original.jpg`, 0바이트 `Images` | 미사용 | 폐기 | - | 리뷰 `:202` |

### 1.3 Floria_NEO_02 = Flora Sentiment (별개 브랜드, 약 60%)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| 전체 앱 | 부분 | 이식하지 않음(별도 저장소 유지) | 연계 사이트 SI-06-031 | `00_MERGE_ANALYSIS.md:1007` |
| `src/data/*.ts` 레이어, `@theme` 토큰 패턴 | 동작 | 패턴만 참고 | `src/content/`, `src/styles/` | 리뷰 `:294` |
| 폼 3곳(`preventDefault`만) | 목업 | 연계 시 `/api/inquiries`로 교체 | SI-06-031 | 리뷰 `:214` |

### 1.4 Lucury Website(한울건설), Biz_Website

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| Lucury 마크업·접근성 기본(`prefers-reduced-motion`, `aria-expanded`) | 동작 | 체크리스트 근거로 참고 | 03장 6절 | 리뷰 `:293` |
| Lucury 영상 3개, 프레임 150장, `.git`+LFS | 동작(배포 불가) | 이식하지 않음. 연계 작업 | SI-06-030 | 리뷰 `:182-183`, `:189` |
| Biz_Website `dist/`, `node_modules/` | 빌드 산출물만 | 이식하지 않음. `dist/`는 보관 | `archive/` | 리뷰 `:186` |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| Botanic 카피 | 영문 헤딩+한글 설명 혼재를 한국어 평문으로 정리. 가격(₩180,000 / $120 / $145)은 D-3 전까지 제거. "50마일/80km"는 `claims.verified=false`. 리뷰어 이름 5건은 이식하지 않는다 |
| GEO 전략 | JSON-LD를 `content/business.ts`에서만 생성. LA 주소와 555 전화번호 예시 제거. `priceRange`는 근거 없으면 생략 |
| Playwright 스크립트 | 스크린샷 덤프를 단언문 테스트로 바꾸고 `tests/e2e/`로 이동. 로컬 경로 제거 |
| `package.json` | 의존성 버전 고정, `latest` 금지, lucide-react를 dependencies로 |
| 디자인 레퍼런스 캡처 | 저작권이 불명확한 이미지는 공개 저장소 자산으로 쓰지 않는다 |
| 원본 히어로 사진(`floria-top.webp`) | 2026-10-13 히어로가 3D 온실 구조물로 바뀌어 히어로 자산으로 쓰지 않는다. 정지 대체 이미지(`public/hero/greenhouse.avif`)는 3D 장면을 렌더해 만든다. 참고 캡처는 `archive/`에 둔다 |
| Botanic 토큰(#080808~#0B0B0B 배경) | 03장 4.3 토큰으로 대체(이미 반영). 3D 재질 색도 같은 토큰만 쓴다 |

## 3. 폐기 목록과 사유

분석(`docs/products/00_MERGE_ANALYSIS.md`)이 이 그룹에 명시적으로 "폐기"로 분류한 항목은 없다. 분석 판정은 "유지(별도 저장소)"(`:1060`)였다. 따라서 분석 분류 폐기는 0건이고, 아래는 리뷰와 이 기획의 결정에서 나온 폐기 목록이다(빠짐없이).

| # | 폐기 항목 | 사유 | 근거 |
|---|---|---|---|
| X-1 | Botanic `REVIEWS` 가상 후기 5건과 별점 UI | 가상 후기 금지(01장 6절) | `App.jsx:584-588` |
| X-2 | Floria_Neo 전체 코드(Play CDN, googleusercontent 12개 URL) | 프로덕션 비권장, 임시 서명 URL 만료 | 리뷰 `:187`, `:229` |
| X-3 | Floria_Neo `Hero-bg.jpg`, `hero_original.jpg`, 0바이트 `Images` 파일 | 미사용, 생성 실수 | 리뷰 `:202` |
| X-4 | Botanic 인라인 style 객체, `onMouseOver/onMouseOut` 호버 | 반응형 불가, 키보드 포커스 미대응 | 리뷰 `:185`, `:195` |
| X-5 | Botanic 미사용 상수 `B,C,D,E`, `IMG.hero`, `.order-btn` 데드 CSS, 전역 `nav{display:none}` | 데드코드 | 리뷰 `:209-210` |
| X-6 | Botanic `useFadeIn` 전 섹션 적용, 카드 호버 줌, `blur` 조명 원 | 생성형 기본값(03장 4.6) | 리뷰 `:295`, `CLAUDE.md` A절 |
| X-7 | Botanic `CLAUDE.md` "Tailwind 전용"+Unsplash 하드코딩 지시 | 구현과 불일치, 핫링크 금지 | 리뷰 `:199`, `:211` |
| X-8 | Botanic JSON-LD 예시의 LA 주소와 555 전화번호 | 가짜 연락처 | `CLAUDE.md:154-156` |
| X-9 | 달러·원화 혼재 가격 표기와 50마일/80km 이중 표기 | 데이터 충돌, 미검증 주장 | 리뷰 `:172-173` |
| X-10 | Botanic 디버그 `capture*.mjs`, `verify.mjs`, `check_floria.mjs` | 정식 테스트로 대체 | 리뷰 `:117` |
| X-11 | NEO_02 템플릿 잔재(`App.css`, `hero.png`, `react.svg`, `vite.svg`, Vite README, `temp-init` 명칭) | 사용되지 않음 | 리뷰 `:206` |
| X-12 | NEO_02 중복 `InstagramIcon`, hex 직접 사용 | 중복·토큰 이중화 | 리뷰 `:207` |
| X-13 | Lucury `hero_archi_02.mp4`(17.8MB), `assets/README.txt`, `.git/lfs/objects` 복제본 | 미참조·구버전 문서·중복 | 리뷰 `:190`, `:212`, `:189` |
| X-14 | Lucury `picsum.photos` 플레이스홀더 6개 | 외부 의존, 신뢰도 훼손 | 리뷰 `:191` |
| X-15 | Lucury 데드 CSS `.hero-btn`, `.scroll-video` | 데드코드 | 리뷰 `:213` |
| X-16 | `WebSite/.vite/deps_temp_*` | 의존성 캐시 잔재 | 리뷰 `:215` |
| X-17 | 모든 `href="#"` 링크와 `mailto:`만 있는 CTA | 비동작 | 리뷰 `:214` |
| X-18 | webcraft의 picsum 가짜 포트폴리오 9건을 대체하는 연동(참고) | 이 제품이 폐기하는 것이 아니라 microweb-studio가 WebSite 실제 납품작으로 교체한다는 분석 판정 | `00_MERGE_ANALYSIS.md:1048` |
| X-19 | Botanic `CLAUDE.md`의 "Tailwind 전용"처럼 버전 없이 "Tailwind"만 적은 지시 | v3 문법·`tailwind.config.js` 혼입 위험(`docs/products/_design-guide/DESIGN_SYSTEM.md:23`) | 지시·문서에 "Tailwind CSS v4"로 명시(AI 개발 지시 포함) |

## 4. 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 실키가 든 `.env` 커밋 | `SECURITY_BASELINE.md:235` | 키 유출. WebSite 3단계 깊이에서 `.env`는 발견되지 않았다 | `.env.example`만 커밋 |
| 인증 없는 공개 프록시, CORS `*` | `SECURITY_BASELINE.md:232` | 키 도용, 비용 | Origin 허용 목록 |
| 서명 없는 확인/해지 링크, GET으로 상태 변경 | 이 기획 | 메일 스캐너 선열람, 위조 | HMAC 토큰+POST |
| 가상 후기·미검증 수치 | App.jsx:584 | 허위 표시 | 증빙 데이터 규칙 |
| 외부 CDN/임시 URL 이미지 | 리뷰 #6 | 만료·추적 | 로컬 WebP, CSP |
| 정의되지 않은 라우트 링크, `href="#"` | 리뷰 #7 | 빈 화면 | 라우트 레지스트리+링크 크롤 |
| 인라인 grid 고정값 | 리뷰 #4 | 반응형 불가 | Tailwind CSS v4 유틸+린트 |
| 4K 영상 `autoplay preload="auto"`, 전량 프리로드 로더 | 리뷰 #1, #2 | 초기 전송 폭증 | 예산 게이트 |
| 중첩 `.git`+LFS | 리뷰 #8 | 상위 리포 추적 불가 | `check-repo` |
| 프로필 없으면 admin | `SECURITY_BASELINE.md:229` | 권한 상승 | 프로필 없으면 로그아웃 |
| 폼 오류를 성공으로 위장 | `SECURITY_BASELINE.md:188` | 문의 유실 | 오류 표시 |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | `docs/products/_platform-core/SECURITY_BASELINE.md:299` | 키 유출, 비용 남용 | LLM 키는 FastAPI 전용, ElevenLabs 키와 토큰 개인키는 Next.js 서버 전용 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `SECURITY_BASELINE.md:299` | 인증·한도 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·개인정보 | `SECURITY_BASELINE.md:285` | 평문 로그 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| 방문자 대화를 대화 id만으로 이어 쓰기 | `SECURITY_BASELINE.md:288` | 대화 탈취 | 서명 쿠키 해시 `visitor_key` 일치 |
| 익명 AI 호출에 한도 없음 | `docs/products/_platform-core/AI_ARCHITECTURE.md:130` | 비용 폭주 | Turnstile, 레이트 리밋 5종, 사이트 일일 상한, 스위치 기본 꺼짐 |
| AI 응답에 후기·평점·미검증 수치·가짜 연락처·가격 약속 | 01장 6절 | 허위 표시 | 그래프 `compliance` 노드와 규칙 파일 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용 | DB의 assistant 메시지(500자 이하)만 낭독 |
| 3D 재질에 토큰 밖 색, 금색, 별 파티클, 잎 일러스트 패턴 | `docs/products/_design-guide/HERO_3D.md:52-53`, `REFERENCES.md` website-floria 절 | 피할 인상 | 03장 4.8절 토큰 표 |
| 상담 지식에 고객 식별정보·동의 없는 사례 | 01장 6절 | 개인정보, 초상·저작권 | `consent_ref` 없는 사례는 색인 거부 |
| `user_plans FOR ALL`류 정책 | `SECURITY_BASELINE.md:226` | 셀프 변경 | 쓰기 정책 없음 |

## 5. 아카이브 절차

실행은 사용자 승인 후 별도 작업(SI-06-029)이 한다. 이 기획은 git 쓰기를 하지 않았다.

| 단계 | 내용 |
|---|---|
| 1 | `Botanic_Architecture`의 새 앱 이식 완료 후 원본 `floria/`를 `archive/WebSite-Botanic_Architecture/`로 이동. 커밋 `0b7f3fa`, `8463f9a`, `54c9f68` 이력은 유지 |
| 2 | `Floria_Neo`는 카피 추출 후 `archive/WebSite-Floria_Neo/`로 이동(리뷰 `:229` 권고) |
| 3 | `Lucury Website`: 서브모듈 전환 또는 `.git` 제거+모노레포 편입 중 사용자 결정. 영상은 저장소 밖(CDN/객체 스토리지)으로. LFS 원본 유실 위험이 있어 백업 후 진행 |
| 4 | `Biz_Website`: 원본 소스(`platform-website` 패키지) 탐색. `dist/`는 저장소 밖 보관소에 zip 사본. `node_modules/`는 삭제 |
| 5 | `WebSite/.vite` 삭제, `.gitignore`의 `dist/`, zip 규칙 점검 |
| 6 | 키 재발급: 원본에서 `.env`가 발견되지 않아 해당 없음. 단 구현 에이전트가 이동 전에 각 폴더의 `.env*`, `.zip`을 한 번 더 확인한다 |
| 7 | zip 중복 정리: 리뷰가 `.gitignore:40`의 zip 제외를 언급(`:267`). 저장소 안 zip을 찾아 한 사본만 남긴다 |

## 6. 인증 관련 복사 금지 (2026-10-14 추가, 확정 결정 22)

이 제품의 원본(WebSite 5개 사이트)에는 로그인 코드가 없다. 그래도 다른 제품 원본이나 예제에서 아래 패턴을 가져오지 않는다. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 JWT 로그인, 원격 DB·배포 환경 차단)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키 역할 Mock(`lib/mock-auth.ts` 프로덕션 노출, `mock-login`, `nomad_role`·`nomad_plan` 쿠키 권한) | `docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88`, `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96`(`AUTH_ROADMAP.md` 1장 인용) | 권한 위조, 프로덕션 노출 | `AUTH_ROADMAP.md` 2장 Mock(`/api/dev/login`, 시드 페르소나, 05장 10절). CI 금지 문자열(SI-06-024) |
| 콜백 `next` 무검증 리다이렉트 | `AUTH_ROADMAP.md` 3.2절 5번 | 오픈 리다이렉트 | `/`로 시작하고 `//`·`@`·`\` 없는 경로만, 아니면 `/admin`(SI-06-049 B-2) |
| 기능 코드의 `if (mock)`·페르소나 이메일 분기 | `AUTH_ROADMAP.md` 0장 불변 조건, 2.5절 | 배포 환경과 다른 권한 경로 | 권한은 `session_context`로만, 단계 분기는 `src/lib/auth/`·로그인 화면·콜백만 |
