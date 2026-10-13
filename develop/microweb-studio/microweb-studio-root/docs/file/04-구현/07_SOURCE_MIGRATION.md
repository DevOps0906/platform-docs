# 07 원본 이식과 폐기: Microweb Studio

AI 관련 원본 자산(2026-10-13 점검): 세 원본의 AI는 모두 Vertex AI Studio 템플릿에서 나온 Gemini 호출뿐이다. premium의 `services/gemini.ts`(축하말)와 `services/imageService.ts`(Imagen), 세 원본 공통의 범용 프록시 `backend/server.js`와 인터셉터다(`docs/reference/reviews/premium-wedding-invitation.md:59-64`). RAG, 위키, Dify, LangGraph, 음성(STT·TTS), 3D, 디자인 시스템은 원본에 없어 모두 신규다. 이식하는 것은 축하말의 프롬프트 의도 하나이고 새 구조(FastAPI 그래프 `microweb.guest_greeting`)에서 다시 쓴다. nexus 원본의 모바일 목업 구조는 3D 히어로가 아니라 카탈로그 썸네일(`preview_mockup`)에만 참고한다.

## 1. 원본별 자산 분류

### premium-wedding-invitation (베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `frontend/components/Hero.tsx` | 동작(AI 이미지) | 이식(UI·모션만) | `src/engine/blocks/hero` | `docs/reference/reviews/premium-wedding-invitation.md:29` |
| `frontend/components/Invitation.tsx` | 동작(정적) | 이식 | `blocks/greeting`, `blocks/hosts` | `:30` |
| `frontend/components/Calendar.tsx` | 동작 | 이식 | `blocks/calendar` | `:30` |
| `frontend/components/Gallery.tsx` | 동작(picsum) | 이식 + 라이트박스·lazy | `blocks/gallery` | `:105` |
| `frontend/components/Location.tsx` | 부분(AI 지도) | 딥링크·교통 안내만 이식 | `blocks/location`, `blocks/transport` | `:31`, `:79` |
| `frontend/components/Contact.tsx` | 동작 | 이식(하드코딩 번호 제거) | `blocks/contacts`, `blocks/accounts`, `blocks/wreath` | `:32`, `premium-wedding-invitation/CLAUDE.md:269` |
| `frontend/components/Guestbook.tsx` | 부분(localStorage) | UI만 이식, 저장은 API | `blocks/guestbook` | `:33`, `:65` |
| `frontend/App.tsx`(음악, 토스트, 공유, confetti) | 동작 | 이식(자동 재생 없음) | `blocks/bgm`, `src/engine/share/` | `CLAUDE.md:71-77` |
| `frontend/services/gemini.ts` | 부분 | 참고(프롬프트 의도만) | `apps/api/app/ai/graphs/microweb_guest_greeting.py`(서버 상수 프롬프트), 호출 경로는 `src/app/api/public/[slug]/greeting/` | `:61` |
| `frontend/services/imageService.ts` | 동작 | 폐기 | - | `:59-60` |
| `frontend/services/supabase.ts` | 목업 | 폐기(core-db 사용) | - | `:16` |
| `frontend/constants.ts`, `types.ts` | 동작(1커플) | 참고(블록 스키마 필드 원천) | `src/engine/schema/` | `:71` |
| `backend/`, `vertex-ai-proxy-interceptor.js` | 동작 | 폐기 | - | `:61-64` |

### nexus-micro-web-builder

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `frontend/data/models.ts` | 동작(정적) | 이식(데이터) | `templates` 카탈로그(`1500_microweb.sql:1510`) | `docs/reference/reviews/nexus-micro-web-builder.md:108` |
| 모델별 벤토 카드(디자인/영업 메모) | 동작 | 참고(내부 기획 자료) | `templates.summary`, 운영 문서 | `00_MERGE_ANALYSIS.md:1042` |
| `frontend/components/MobileMockup.tsx` | 동작(하드코딩) | 참고 → 선언형 `preview_mockup` | `src/showroom/components/catalog/` | `:69`, `:85` |
| `frontend/components/Sidebar.tsx`(산점도) | 동작(임의 스코어) | 폐기 | - | `:31` |
| `pages/`, `contexts/`, `services/`, `components/ui/`, `components/layout/`, `Calendar.tsx` | 컴파일 불가 잔재 | 폐기 | - | `:63-64`, `:73` |
| `backend/`, 인터셉터 | 미사용 | 폐기 | - | `:62` |

### webcraft-agency-simulator

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `frontend/constants/geoMeta.ts` | 동작 | 이식(단일 데이터 출처) | `src/showroom/data/industries.ts`, `tiers.ts` | `docs/reference/reviews/webcraft-agency-simulator.md:48` |
| `frontend/constants.ts`의 `PRICING_PLANS` | 동작 | 이식(할인가만, 정가 쌍 제거) | `src/showroom/data/pricing.ts` | `:49` |
| `frontend/pages/Simulator.tsx`, `components/pricing/*` | 동작 | 이식 + 공통 레이아웃 | `src/showroom/components/simulator/` | `:30`, `:110` |
| `frontend/components/Portfolio.tsx`, `PortfolioDesign.tsx`, `constants/portfolioDesign.ts` | 동작 | 이식(UI), 데이터는 DB | `src/showroom/components/catalog/` | `00_MERGE_ANALYSIS.md:1049` |
| `frontend/constants/portfolioWeb.ts` | 동작(picsum 가짜 9건) | 폐기(데이터) | `portfolio_items` | `00_MERGE_ANALYSIS.md:1048` |
| `frontend/components/Hero.tsx`(수치 히어로), `PromoBanner.tsx` | 동작 | 폐기(금지 문구) | - | `components/Hero.tsx:38-48`, `PromoBanner.tsx:12` |
| `frontend/pages/Login.tsx`, `AdminDashboard.tsx` | 목업 | 폐기 | - | `:31-32`, `:75` |
| 고아 7개, `constants.ts` 중복, 중첩 `webcraft-agency-simulator/` | 잔재 | 폐기 | - | `:73`, `:76`, `:89` |
| `backend/`, `backend/.env.local` | 미사용, 커밋됨 | 폐기 + 사고 대응(5절) | - | `:65-66` |
| `.claude/` hook, 스킬 | 정상 | 참고 | 앱 `.claude/` | `:54` |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| 섹션 컴포넌트 7개 | props를 `WEDDING_DATA` 대신 블록 props(zod)로, picsum/Unsplash 폴백 제거, 이미지는 `next/image` + 서명/공개 URL, 하드코딩 시간 문자열 제거(`premium-wedding-invitation.md:73`), 폰트 오타 제거(`:69`), 컴포넌트당 200줄 이하 유지 |
| 방명록 UI | 삭제 버튼 제거(하객), 제출은 `POST /api/public/[slug]/guestbook`, 결과 코드별 문구, Realtime 구독 대신 제출 후 재조회(공개 anon Realtime 금지) |
| 축하말 | 브라우저 genai 호출 제거, FastAPI 그래프 `microweb.guest_greeting`(라우팅 기능 `microweb_greeting`), 입력은 관계·어조 enum뿐(하객 이름을 모델에 보내지 않음), 실패 시 고정 문구 반환 금지(`gemini.ts:27-30`이 실패를 숨김) |
| 카카오 공유 | 키 `NEXT_PUBLIC_KAKAO_JS_KEY`, 공식 SRI, 템플릿 이미지 = og 파생본 |
| geoMeta/가격표 | 중복 파일 하나로, 색상 클래스 맵은 Tailwind CSS v4 `@source inline()` 또는 토큰으로, `import * as Icons` → 명시 맵 |
| 시뮬레이터 | `currentView` 상태 라우팅 → App Router 페이지, 선택값 → `/contact` 쿼리 |
| models.ts | 12행을 SQL 카탈로그로. `chartData`(산점도 스코어)는 버림. 가격 문자열은 min/max 정수 + `price_note` |

## 3. 폐기 목록과 사유

분석의 "폐기"(`00_MERGE_ANALYSIS.md:1022-1074`) 전부.

| # | 항목 | 원본 | 사유 | 근거 |
|---|---|---|---|---|
| 1 | AI 생성 지도 이미지 | premium | 실제 위치와 달라 하객을 오도 | `00_MERGE_ANALYSIS.md:1029`, `premium-wedding-invitation.md:60` |
| 2 | 범용 Vertex 프록시, 인터셉터, WS 프록시 | 세 원본 공통 | 공개 시 오픈 프록시, nexus·webcraft는 호출 0건 | `00_MERGE_ANALYSIS.md:1040`, `:1069` |
| 3 | 방문마다 실행되는 Imagen 생성 | premium | 하객 수에 비례한 비용, 회색 첫 화면 | `00_MERGE_ANALYSIS.md:1071` |
| 4 | 시장 분석 산점도 | nexus | 근거 없는 스코어(허위 수치) | `00_MERGE_ANALYSIS.md:1043` |
| 5 | 기획서 다운로드 | nexus | 내부 docs 이전으로 대체(리뷰 5장 #8 포함) | `00_MERGE_ANALYSIS.md:1045` |
| 6 | Landing/Login/Dashboard(Nexus Platform 고아 템플릿) | nexus | 컴파일 불가 잔재 | `00_MERGE_ANALYSIS.md:1046` |
| 7 | nexus 앱 본체(쇼케이스 화면) | nexus | 상품이 아님. 데이터만 카탈로그로 | `00_MERGE_ANALYSIS.md:1072` |
| 8 | 소셜 로그인 + 권한 직접 선택 | webcraft | 실제 인증은 platform-core | `00_MERGE_ANALYSIS.md:1054` |
| 9 | 관리자 대시보드 모듈 구매/ON-OFF UI | webcraft | 실제 기능 없음. CRM 모듈 6종 목록만 Custom 등급 옵션으로 흡수(리뷰 5장 #8 분리 작업 불필요) | `00_MERGE_ANALYSIS.md:1055` |
| 10 | 설정 잠금 비밀번호 1234, GitHub/Supabase 연동 안내 탭 | webcraft | 우회 비밀번호 패턴 금지 | `00_MERGE_ANALYSIS.md:1056`, `SECURITY_BASELINE.md` 11장 |
| 11 | 코어 대시보드(월별 매출, 유입 채널) | webcraft | 목업 수치. 외부 공개 시 오해 | `00_MERGE_ANALYSIS.md:1057` |
| 12 | 중복 constants.ts, 고아 컴포넌트 7개, 중첩 repo | webcraft | 저장소 위생 | `00_MERGE_ANALYSIS.md:1059`, `:1074` |
| 13 | Tailwind CDN 런타임, `latest` 의존성 | 세 원본 | 재현 불가 빌드, 프로덕션 비권장 | `00_MERGE_ANALYSIS.md:1074` |
| 추가 | 미검증 수치 히어로("500+", "98%"), 50% 할인 배너, picsum 포트폴리오 | webcraft | 01장 6절 금지 문구 | `components/Hero.tsx:38-48`, `PromoBanner.tsx:12` |

AI 계층 도입(2026-10-13)으로 생긴 추가 폐기. 분석 폐기 목록(위 13개) 밖이라 따로 번호를 붙인다.

| # | 항목 | 원본 | 사유 | 근거 |
|---|---|---|---|---|
| P-1 | 쇼룸 히어로의 "375px 휴대폰 iframe + 샘플 자동 스크롤" 단독 안 | 이 기획 03장 4.4절 안 A | 사용자 결정(확정 결정 15)으로 3D 히어로(안 C)가 대체. 샘플 프레임 자체는 3D 마지막 단계에서 유지 | 03장 4.4절 변경 기록 |
| P-2 | 게이트웨이 purpose `microweb_greeting`(LLM 게이트웨이 모델 맵) | 이 기획 02장 5절 이전 안 | 라우터가 ai-service로 옮겨져 기능 키 `microweb_greeting`으로 대체 | 02장 5.1절 |

## 4. 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 클라이언트가 모델명·본문·헤더를 지정하는 AI 프록시 | `premium-wedding-invitation/backend/server.js:198-237`, `:232` | 오픈 프록시, Authorization 덮어쓰기 | 고정 purpose 엔드포인트 1개 |
| 프론트 번들의 시크릿 헤더(PROXY_HEADER) | `vertex-ai-proxy-interceptor.js:116` | 번들에서 누구나 읽음 | 서버 env만, `NEXT_PUBLIC_` 금지 |
| 실키가 든 `.env` 커밋 | `webcraft-agency-simulator/backend/.env.local` | 키 유출(`SECURITY_BASELINE.md` 14장) | `.gitignore`, gitleaks |
| 인증 없는 공개 AI 프록시, CORS `*` | `SECURITY_BASELINE.md` 14장 | 키 도용 | 게시 사이트 + 레이트 리밋 |
| 장애를 고정 문구로 숨김 | `premium-wedding-invitation/frontend/services/gemini.ts:27-30` | 실패를 숨김(`SECURITY_BASELINE.md` 11장) | 오류 표시 + 직접 입력 |
| 누구나 보이는 삭제 버튼, 검증 없는 insert, `Date.now()` id | `frontend/components/Guestbook.tsx:53-63` | 타인 글 삭제, 타입 불일치 | 운영자 RPC, DB 기본 uuid |
| 가짜 SRI, placeholder 키 | `frontend/index.html:20` | 스크립트 차단 | 공식 SRI, env |
| 비밀번호 우회('1234'), 역할 직접 선택 로그인 | `webcraft-agency-simulator/frontend/pages/AdminDashboard.tsx:90`, `Login.tsx:12-26` | 권한 우회 | core auth + `studio_access` |
| 클라이언트 판정만의 권한 | 위와 같음 | `SECURITY_BASELINE.md` 11장 | 서버 `requireSession` + RLS |
| `latest` 버전, tsconfig 없음/strict false | 세 원본 package.json | 재현 불가 | lockfile, strict |
| 미검증 수치·할인 표기 | `components/Hero.tsx:38-48`, `constants.ts:142` | 표시광고 위반 소지 | 01장 6절 |
| 하객 방문 시 AI 이미지 생성 | `components/Hero.tsx:24-31` | 비용 폭증 | 업로드 사진 |
| LLM·음성 키를 브라우저·Vercel 외 서버·워커에 두기 | `SECURITY_BASELINE.md` 16장 | 키 유출, 비용 남용 | LLM 키는 FastAPI 전용, ElevenLabs 키와 토큰 개인키는 Next.js 서버 전용, 워커는 AI 키 없음 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*`, `/api/public/[slug]/*` |
| Dify 입력에 토큰·org·개인정보 | `SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| 실명·전화·계좌·사진을 AI 제공자에 전송 | 01장 6절 | 국외 이전, 개인 식별 | 호칭 토큰과 enum만, 메모는 패턴 마스킹 |
| 하객 이름을 축하말 프롬프트에 넣기 | 이 기획 이전 안 | 익명 입력이 국외 제공자로 감 | 관계·어조 enum만 |
| 하객 음성을 상용 STT(ElevenLabs)로 보내기 | `VOICE_ARCHITECTURE.md:46` | 하객은 국외 이전에 동의하지 않음 | 오픈소스 강제(`microweb_guestbook_voice`), 대체 없음 |
| 고지 없는 하객 음성 보관, 쿠키 없는 익명 음성 업로드 | `VOICE_ARCHITECTURE.md:94-95` | 제3자 녹음 동의 누락, 남용 | 고지 확인 후에만, 서명된 방문자 쿠키 + 엄격 레이트 리밋 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용, 과금 우회 | DB의 인사말 블록·assistant 메시지만 낭독 |
| 하객 방문마다 TTS/STT 호출 | `Hero.tsx:24-31`와 같은 패턴 | 비용이 방문 수에 비례 | 편집 시 1회 생성한 mp3 재생 |
| 고인·유명인·타인 음성 복제 | `VOICE_ARCHITECTURE.md:80` | 초상·음성 권리 | 제공하지 않음(본인 음성 복제는 Phase 2 이후 검토) |
| 3D 재질에 토큰 밖 색, 떨어지는 꽃잎·하트 파티클, 글로우 | `HERO_3D.md:52-53` | 피할 인상 | 03장 4.6절 토큰 표 |
| "Tailwind"만 적은 지시(v3 혼입), `tailwind.config.js` | `DESIGN_SYSTEM.md:63-73` | 버전 혼입 | "Tailwind CSS v4", CSS 우선 설정 |

## 5. 아카이브 절차

| 단계 | 작업 | 담당 |
|---|---|---|
| 1 | webcraft 노출 시크릿 사고 대응: (a) `backend/.env.local`의 PROXY_HEADER를 무효로 간주하고 어떤 서비스에서도 재사용하지 않는다 (b) 노출된 GCP 프로젝트 ID의 IAM, ADC 자격, 결제 경보, API 키 목록을 점검하고 불필요한 키를 폐기·재발급 (c) origin(`theBestTrade/webcraft-agency-simulator`)의 공개 여부와 포크 확인 (d) 공개됐거나 공개 예정이면 `git filter-repo`로 `.env.local`, `node_modules` 제거 후 force push 여부를 사용자와 결정 (e) 결과를 런북에 기록. 값 자체는 어떤 문서에도 옮기지 않는다 | MW-06-033(Opus) |
| 2 | 세 원본을 `archive/premium-wedding-invitation`, `archive/nexus-micro-web-builder`, `archive/webcraft-agency-simulator`로 이동(읽기 전용). 중첩 gitlink(5d0f978)는 이동 전에 제거 | MW-06-034 |
| 3 | 루트의 같은 이름 `.zip` 사본은 원본과 동일 여부 확인 후 하나만 보관(이번 작업에서는 읽지 않음) | MW-06-034 |
| 4 | nexus `models.ts`는 카탈로그 SQL로 옮겨졌으므로 아카이브만. 벤토 메모는 운영 문서로 | MW-06-035 |
| 5 | WebSite 저장소는 그대로 두고 포트폴리오에 링크·스크린샷만(고객 동의 후 published) | MW-06-024 |
