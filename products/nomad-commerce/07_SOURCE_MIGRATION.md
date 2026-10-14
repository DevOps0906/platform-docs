# 07 원본 이식과 폐기: NOMAD Commerce

AI 관련 원본 자산(2026-10-13 점검): 원본의 AI 사용은 OpenRouter 모델 맵과 프롬프트(`sellingstudio/lib/llm/openrouter.ts:3-8`, `nomad-ai-factory/frontend/lib/ai/index.ts:57-88`), V.2 문서의 상세페이지 프롬프트·금지어 목록(`Nomad-AI-Factory_V.2/DETAIL_PAGE_SYSTEM.md:497-511`), fal 이미지·fal whisper STT(`sellingstudio/lib/image/fal.ts:13-51`, `sellingstudio/PRD.md:58`)뿐이다. 이 자산들은 아래 표의 AI 행으로 새 구조(FastAPI 라우터, 그래프 프롬프트, core-voice)에 대응한다. RAG, 마켓 규칙 위키, Dify 채팅, 음성 대화, 쇼츠 내레이션, 3D 히어로는 원본에 없어 모두 신규다.

## 1. 원본별 자산 분류

### 1.1 sellingstudio (코드 베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `proxy.ts`, `lib/proxy.ts` | 동작 | 이식 | `apps/nomad-commerce/proxy.ts` | `docs/reviews/sellingstudio.md:34` |
| `lib/supabase/{client,server,admin}.ts` | 동작 | 이식(core-db 패키지가 대체하면 참고) | `packages/core-db`(소비) | `:41`, SHARED_MODULES 2장 |
| `lib/llm/openrouter.ts`, `prompts.ts`, `analyze.ts` | 동작 | 참고(모델 맵·프롬프트) → FastAPI 라우터 설정(`core.ai_model_prices` 모델 행)과 그래프 프롬프트 파일. OpenRouter 직접 호출 코드는 이식하지 않는다 | `apps/api/app/ai/graphs/prompts/commerce/` | `sellingstudio/lib/llm/openrouter.ts:3-8` |
| 음성 STT(fal whisper) 입력 기능 | 동작 | 폐기 → `packages/core-voice`(오픈소스 우선, ElevenLabs 대체)와 `commerce.assist` 작업 `voice_structure`로 대체 | `apps/nomad-commerce/app/api/voice/`, `app/api/ai/voice-structure/` | `sellingstudio/PRD.md:58`, 확정 결정 16 |
| `lib/image/fal.ts` | 동작 | 참고 → core fal client | `services/commerce-worker/src/images/` | `sellingstudio/lib/image/fal.ts:13-51` |
| `app/api/generate/*`(6개) | 부분 | 이식(재작성) | `apps/nomad-commerce/app/api/ai/`, `app/api/detail-pages/` | `docs/reviews/sellingstudio.md:37` |
| `app/api/webhook/fal` | 부분 | 재작성 | `apps/nomad-commerce/app/api/webhooks/fal/` | `:38` |
| `app/api/crawl/url` | 부분 | 재작성(안전 fetch) | `app/api/ai/benchmark/` | `:39` |
| `app/api/auth/callback` | 동작 | 이식 + next 화이트리스트(B단계 `finishLogin`, `AUTH_ROADMAP.md` 3.2절) | `app/auth/callback/`(URL `/auth/callback`, CM-06-058. 06장 8.1절) | `:40` |
| `app/api/credits/{use,status}` | 부분 | 폐기(core 크레딧) | - | `:36` |
| `components/studio/StudioNewForm.tsx`(2,919줄) | 동작 | 참고(입력 5종, 프리셋 18종, 엑셀 업로드) → 분해 | `components/detail/`, `components/products/` | `:45`, `StudioNewForm.tsx:531-548,618` |
| `components/studio/StudioViewer.tsx` | 동작 | 이식(Realtime 카드 뷰어) | `components/detail/` | `:20` |
| `components/landing/landing-page.tsx`(1,213줄) | 동작 | 참고(구조만), 카피 재작성 | `app/(marketing)/` | 분석:766 |
| `components/dashboard/pages.tsx`(2,515줄) | 목업 | 폐기(MOCK 탭) | - | `:46`, `:66` |
| `supabase/migrations/001` 가입 트리거, Realtime 설정 | 동작 | 참고(core가 대체) | - | `:15` |
| `supabase/migrations/002` | 동작 | 폐기(개인 이메일 시드) | - | `:72` |
| `lib/capacitor/`, `capacitor.config.ts`, `android/`, `ios/` | 부분 | 보류(Phase 2, 확정 결정 9) | `apps/nomad-commerce-mobile/` | `:48`, `:62` |
| `lib/store/{authStore,creditStore}` | 동작 | 참고 | `apps/nomad-commerce/lib/stores/` | `:43` |

### 1.2 Nomad-AI-Factory_V.2 (기획 정본)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `MARKET_IMAGE_SPEC.md` 규격·슬롯·변환·검증 코드 | 기획만 | 이식 | `packages/commerce-domain/`, `services/commerce-worker/src/convert/` | `docs/reviews/Nomad-AI-Factory_V.2.md:30` |
| `DETAIL_PAGE_SYSTEM.md` 유형·추천·스토리라인 프롬프트·파이프라인·금지어 | 기획만 | 이식(리뷰형 후기·`brand` 하드코딩 제외). 프롬프트는 그래프 프롬프트 파일로, 파이프라인 8단계는 워커 `detail/`로, 금지어는 `banned_words` | `apps/api/app/ai/graphs/prompts/commerce/`, `services/commerce-worker/src/detail/`, `banned_words` | `:29` |
| `MARKET_IMAGE_SPEC.md`, `MARKET_REGISTER_FORM.md`의 마켓별 규칙 서술(상품명·이미지·고시) | 기획만 | 참고 → 마켓 규칙 원고의 출처 후보(공식 가이드로 기준일·출처를 확인한 항목만 원고화. 확인 못 하면 "출처 확인 필요") | `content/knowledge/` | `docs/reviews/Nomad-AI-Factory_V.2.md:30-31` |
| `MARKET_REGISTER_FORM.md` 필드·완성도·템플릿 | 기획만 | 이식(반품 불가·건기식 부정 문구 제외) | `packages/commerce-domain/forms/`, `listing_drafts` | `:31` |
| `PRD.md` IA·가격표 | 기획만 | 이식(01장) | 01장 | `Nomad-AI-Factory_V.2/PRD.md:296-301` |
| `CLAUDE.md` 엑셀 필드맵, 이벤트 이름 | 기획만 | 이식 | `packages/commerce-sourcing/excel/` | `Nomad-AI-Factory_V.2/CLAUDE.md:553-575`, `:601-633` |
| `CLAUDE.md` 큐·SSE 예제, 규칙 일부 | 기획만 | 폐기 | - | 3절 |
| `DESIGN.md` 컴포넌트 상태·빈 상태·접근성 | 기획만 | 참고(토큰은 03장으로 교체) | 03장 | `:32` |
| `MASTER_SPEC`, `DESIGN_FOR_STITCH`, `STITCH_UI_DESIGN_PLAN` | 기획만 | 폐기(중복) | - | 3절 |
| `LANDING_PAGE_STITCH_PROMPT.md` | 기획만 | 폐기(허위 수치·후기) | - | 3절 |

### 1.3 nomad-ai-factory (v1)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `frontend/lib/ai/index.ts` 리스팅 프롬프트, 톤·채널 가이드 | 동작 | 이식(zod 검증) | `services/commerce-worker/src/detail/prompts/` | `docs/reviews/nomad-ai-factory.md:90`, `nomad-ai-factory/frontend/lib/ai/index.ts:57-88` |
| `backend/server.js` 모델 화이트리스트, json 모드, max_tokens | 동작 | 참고(core llm gateway 기본값) | - | `:91`, `nomad-ai-factory/backend/server.js:42-70` |
| `components/workflow/Canvas.tsx` 위상 정렬 | 목업 | 참고(Phase 2 automation-core) | - | `:92`, `Canvas.tsx:58-59` |
| `app/dashboard/sourcing/page.tsx` 상수 | 동작 | 이식 | `packages/commerce-domain/` | `:94` |
| 나머지 | - | 폐기 | - | 3절 |

### 1.4 nomad-ai-commerce

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| 화면 흐름(수집 탭, 다계정 선택 업로드, 진행률) | 부분 | 참고 | 03장 | `docs/reviews/Nomad-AI-Factory_V.2.md:117` |
| `app/api/execute-flow` 노드 실행기 분리 구조 | 부분 | 참고(Phase 2) | - | `docs/reviews/nomad-ai-commerce.md:142` |
| `lib/utils/plan-policy.ts` | 동작 | 참고(형태만, 값은 01장) | - | `nomad-ai-commerce/lib/utils/plan-policy.ts:13-45` |
| 나머지 코드 | - | 폐기 | - | 3절 |

## 2. 이식 자산 상세

| 자산 | 고칠 점 |
|---|---|
| 생성 라우트 | 각 라우트 안에서 `consume_credits` → 작업 → 실패 `refund_credits`. 플랜·모델은 서버 결정. 결과 저장도 서버(service_role). 클라이언트 `selling_pages` insert 제거 |
| fal 호출 | `enable_safety_checker=true`, 웹훅 URL 토큰 + request_id 대조, 결과를 Storage로 복사, `final_url` 대신 `master_path` |
| openrouter 호출 | core gateway 경유, 타임아웃 60초, 폴백 1회, `ai_usage` 기록, `JSON.parse` 대신 zod |
| URL 벤치마킹 | `BROWSERLESS_TOKEN`/`BROWSERLESS_API_KEY` 불일치 제거, `packages/commerce-net` 사용, 원문 저장 금지, 2크레딧을 core 원장에 |
| auth callback | `next`는 `/`로 시작하고 `//`·`@` 없는 경로만, origin은 env 고정, 프로필 insert는 가입 트리거에 맡김(중복 제거) |
| StudioNewForm | 탭별 컴포넌트 + 오케스트레이션 훅. 대량 생성 루프는 서버 다중 생성 API 1회 호출로 |
| V.2 변환 코드 | 마스터에서만 파생, 단위 테스트, 11번가 3MB 규칙 유지 |
| V.2 금지어 | `\b` 없이 한글 경계 매칭, `REPLACEMENTS['효과']` 제거, 출처는 `banned_words` 하나 |
| V.2 등록 폼 | 쿠팡·스마트스토어 필드만, 반품 제한은 4코드, 고시 ⑨의 "건강기능식품이 아닙니다" 자동 삽입 제거 |
| v1 프롬프트 | 환율 추정 지시 제거(환율은 `exchange_rates`), temperature 0.3(제안: JSON 수치 안정) |

## 3. 폐기 목록과 사유

분석 "폐기" 항목(D-2 5개 + D-3 17개) + 확정 결정으로 범위에서 빠진 1개 = 23개.

| # | 대상 | 사유 | 근거 |
|---|---|---|---|
| 1 | eBay/Walmart 소싱 | MVP 범위 축소 | 분석:776 |
| 2 | 별도 Vector DB 서비스 설계 | V2 MVP 보류 목록. 2026-10-13 확정 결정 13으로 Supabase pgvector RAG가 MVP에 들어왔고(01장 CM-F-040, 041), 별도 벡터 DB 서비스는 쓰지 않는다 | 분석:802 |
| 3 | 제휴 링크 매칭(MonetizeNode) | 크리에이터 수익화. core affiliate + video/blog 소관 | 분석:814, 957, 확정 결정 12 |
| 4 | Cron/고마진 상품 알림 | 엔진·스케줄러가 빈 함수, MVP 제외 | 분석:836 |
| 5 | 사용자 API 키 localStorage(BYOK) | XSS 한 번이면 전부 유출 | 분석:839 |
| 6 | v1 Vite SPA, HashRouter, Tailwind CDN, `index.html` 커스텀 CSS | Next 16 전환 | 분석:857 |
| 7 | v1 Express 프록시 CORS `*`, IP 레이트리밋, `/api-proxy` | 인증 없는 공개 AI 프록시 | 분석:858 |
| 8 | v1 `vertex-ai-proxy-interceptor.js`, `vite.config.ts` 더미 define | AI Studio 템플릿 잔재 | 분석:859 |
| 9 | v1 인증 3벌, `pages/`, `contexts/`, `lib/actions`, `lib/media`, `lib/commerce`, 설정 폼 2벌 | 죽은 코드 약 4,500줄 | 분석:860 |
| 10 | v1 `reactflow` v11 + CDN CSS | @xyflow v12로 재작성 | 분석:861 |
| 11 | v1 `schema.sql`, `main.html`, `structer.zip`, `CLAUDE_v0.md` | 구 문서·시안 | 분석:862 |
| 12 | CM 모의 인증·쿠키 권한(`mock-login`, `nomad_role`, `nomad_plan`) | 권한 위조. 허용되는 Mock은 AUTH_ROADMAP 2장(로컬 시드 계정으로 실제 Supabase JWT, 배포 환경 404, CM-06-007)뿐이다 | 분석:863, `docs/products/_platform-core/AUTH_ROADMAP.md:30` |
| 13 | CM `globalThis` 잡, `mock-market-accounts`, `CustomProcessingNode`, 로그아웃 3중 | 서버리스 비호환, 죽은 코드 | 분석:864 |
| 14 | CM `execute-flow` HTTP 자기 호출, `tableName` insert, `raw_html`, 정규식 아마존 파싱, exchangerate.host | 보안·동작 결함 | 분석:865 |
| 15 | SS `/api/credits/use` 분리 차감, 클라이언트 `selling_pages` insert, `USING(true)` 정책 | 과금 우회, 무결성 붕괴 | 분석:866 |
| 16 | SS 미사용 의존성 14개, `AuthProvider`, `projectStore`, `fal.ts` 미사용 함수, `MOCK_*` 탭, 루트 `image*.png` | 정리 대상 | 분석:867 |
| 17 | SS Stripe | Toss 단일 PG(확정 결정 4) | 분석:868 |
| 18 | SS CSP `unsafe-eval`, 사설 IP, 002 개인 이메일 시드 | 설정 결함 | 분석:869 |
| 19 | V2 디자인 문서 중복(DESIGN, MASTER_SPEC, DESIGN_FOR_STITCH, STITCH_UI_DESIGN_PLAN) | 사실 하나에 출처 하나 | 분석:870 |
| 20 | V2 CLAUDE 예제(Zustand 큐 + SSE, 청크 버퍼링 버그), `@xyflow/react v11` 표기, `<form>` 금지, localStorage "아티팩트" 규칙, `middleware.ts` | 복사 시 결함 재발 | 분석:871 |
| 21 | V2 랜딩 허위 수치·후기, 리뷰형 AI 후기·평점, 반품 불가·건기식 부정 문구 자동 삽입 | 표시광고법·전자상거래법 위반 소지 | 분석:872 |
| 22 | DALL-E 3 | fal Flux로 교체 | 분석:873 |
| 23 | 블로그 원고·발행(CM 지역뉴스, v1 GEO 블로그) | commerce 범위 밖, nomad-blog 소유 | 확정 결정 1(분석:9), 분석:813 |

AI 계층 도입(2026-10-13)으로 생긴 추가 폐기. 분석 목록 밖이라 따로 번호를 붙인다.

| ID | 폐기 항목 | 출처 | 사유 |
|---|---|---|---|
| P-24 | 워커·Route Handler의 OpenRouter 직접 호출과 제품별 모델 맵 하드코딩 | `sellingstudio/lib/llm/openrouter.ts:3-8`, 02장 5절(2026-10-12판) | LLM 키는 FastAPI 전용이고 제공자·모델은 `resolve_ai_route` 결과만 쓴다(확정 결정 17) |
| P-25 | fal whisper STT 경로 | `sellingstudio/PRD.md:58` | 음성은 core-voice로 이원화(확정 결정 16) |
| P-26 | 03장 4.3절의 "스크롤에 따라 롱이미지 띠가 갈라지는" 히어로 연출 | 03장 4.3절(2026-10-12판) | 사용자 결정 2026-10-13, 3D 히어로 표준으로 대체(03장 4.5절) |

## 4. 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 차감을 별도 API로 분리, 생성 라우트 무검사 | `sellingstudio/app/api/credits/use/route.ts:33-61`, `docs/reviews/sellingstudio.md:58` | 무료 사용 | 라우트 안 선차감(04장) |
| 읽고-빼고-쓰기 비원자 차감 | `docs/reviews/sellingstudio.md:59`, SECURITY_BASELINE 14장 | 음수 잔액 | core `consume_credits` |
| 요청 바디로 플랜·모델 결정 | `sellingstudio/app/api/generate/images/route.ts:15,33-34` | 비용 폭증 | `features.image_quality` |
| 웹훅 무서명, `USING(true) WITH CHECK(true)` | `docs/reviews/sellingstudio.md:61` | 타인 데이터 변조 | 서명·멱등, 정책 없음 + guard |
| 쿠키 기반 역할·플랜(`mock-login`, `nomad_role`, `nomad_plan`, `mock-auth`) | `nomad-ai-commerce/middleware.ts:5-8` | 권한 위조, 프로덕션 노출 | `session_context`. 허용되는 Mock은 AUTH_ROADMAP 2장(로컬 시드 계정 실제 로그인, `isMockAuthAllowed()` 가드). CI 금지 문자열(CM-06-036) |
| 인증 없는 키 반환 API, 평문 키 | `docs/reviews/nomad-ai-commerce.md:60` | 전 계정 탈취 | vault + 마스킹 |
| 사용자 URL 직접 fetch, 원문 HTML 저장 | `docs/reviews/nomad-ai-commerce.md:59`, `docs/reviews/sellingstudio.md:64` | SSRF | ASIN만 추출, 안전 fetch |
| 요청 바디 테이블 이름 | `docs/reviews/nomad-ai-commerce.md:63` | 임의 테이블 쓰기 | 고정 테이블 |
| 한글에 `\b` 금지어 정규식 | `docs/reviews/nomad-ai-commerce.md:65`, SECURITY_BASELINE 14장 | 필터 무효 | `packages/commerce-compliance` |
| `globalThis` 인메모리 잡 | `docs/reviews/nomad-ai-commerce.md:69` | 서버리스에서 404 | `core.jobs` |
| 공개 AI 프록시 CORS `*` | `docs/reviews/nomad-ai-factory.md:57` | 키 도용 | 인증된 Route Handler |
| 클라이언트 한도 판단, catch 후 진행 | `docs/reviews/nomad-ai-factory.md:58` | 무제한 사용 | DB 트리거 + 서버 |
| localStorage 키 저장 | `docs/reviews/nomad-ai-factory.md:59` | XSS 유출 | 없음(BYOK 폐기) |
| LLM 추정 환율 | `docs/reviews/nomad-ai-factory.md:72` | 마진 오류 | 수출입은행 캐시 |
| Route Handler SSE + 브라우저 큐 | `docs/reviews/Nomad-AI-Factory_V.2.md:44` | 배포 불가, 새로고침 시 중단 | 워커 + Realtime |
| 단일 env 마켓 키 | `Nomad-AI-Factory_V.2/CLAUDE.md:217-219` | 테넌트 격리 붕괴 | 셀러별 자격증명 |
| `user_id = auth.uid()` 공통 정책, `FOR ALL` | `docs/reviews/Nomad-AI-Factory_V.2.md:47`, SECURITY_BASELINE 14장 | 셀프 업그레이드 | org 정책 + with check |
| 반품 불가·건기식 부정 문구 자동 삽입 | `Nomad-AI-Factory_V.2/MARKET_REGISTER_FORM.md:241-244,274,282-285` | 위법 소지 | CHECK + 법률 검토 문안 |
| AI 생성 후기·평점 배너 | `Nomad-AI-Factory_V.2/DETAIL_PAGE_SYSTEM.md:37-59` | 기만 광고 | 생성 금지 |
| JSON-LD `brand` 하드코딩 | `docs/reviews/Nomad-AI-Factory_V.2.md:59` | 허위 정보 | 상품 브랜드(Phase 2) |
| Capacitor dev 서버 로드, cleartext | `sellingstudio/capacitor.config.ts:5-15` | 배포 불가·평문 | 원격 셸(Phase 2) |
| 콜백 `next` 미검증, Host 헤더 origin | `docs/reviews/sellingstudio.md:64` | 오픈 리다이렉트 | 화이트리스트 + env origin(`finishLogin` 5번, `AUTH_ROADMAP.md` 3.2절, B-2) |
| 실키 `.env` 커밋, 0키 폴백, 빈 JWT secret | SECURITY_BASELINE 14장 | 키 유출 | env 검증 기동 실패 |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | `docs/products/_platform-core/SECURITY_BASELINE.md:284`, 02장 머리 표 | 키 유출, 비용 남용 | LLM 키는 FastAPI 전용, ElevenLabs 키와 토큰 개인키는 Next.js 서버 전용 |
| 브라우저에서 Dify·FastAPI·제공자 직접 호출 | `docs/products/_platform-core/SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·개인정보·마켓 키 | `docs/products/_platform-core/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| 셀러 연락처·반품지 주소·마켓 키·사업자번호를 AI 요청에 포함 | 01장 6.1절 | 국외 이전, 키 유출 | 그래프 입력 스키마에서 제외, 채팅 입력 마스킹 |
| 클라이언트가 보낸 임의 텍스트를 그대로 TTS | 제안 | 음성 생성 남용, 과금 우회 | 읽어 주기는 DB의 assistant 메시지만, 내레이션은 600자 상한과 금지어 검사 통과 스크립트만 |
| 내레이션 도중 다른 제공자로 대체 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47` | 목소리가 바뀜 | 대체 금지, 실패 + 환불 |
| 위키·규칙 근거 없이 마켓 규정 단정, 승인·반려 보장 문형 | 01장 6.1절 | 허위 안내, 셀러 손해 | 근거 없음 응답, 기준일 표기, compliance 후처리 |
| 3D 재질에 토큰 밖 색, 보라/핑크 그라디언트·별 파티클·흔한 지구본 | `docs/products/_design-guide/HERO_3D.md:52-53` | 피할 인상 | 03장 4.5절 토큰 표 |
| "Tailwind로"만 지시해 v3 설정 생성 | `docs/products/_design-guide/DESIGN_SYSTEM.md:23` | v3 설정 혼입 | 지시와 문서에 Tailwind CSS v4 명시, `tailwind.config.js` 금지 |
| 마이그레이션에 개인 이메일 | `sellingstudio/supabase/migrations/002_add_admin_plan.sql:14-24` | 개인정보·권한 하드코딩 | platform_admin은 운영 스크립트로 |

## 5. 아카이브 절차

| 단계 | 내용 |
|---|---|
| 1 | 개발 저장소에서 `sellingstudio`, `nomad-ai-factory`, `nomad-ai-commerce`, `Nomad-AI-Factory_V.2`를 `archive/<원본>`으로 이동(CM-06-037). 이 기획 단계에서는 원본을 수정하지 않았다 |
| 2 | 원본 `.env.local`의 키(OpenRouter, fal, Supabase service_role, Browserless, Toss/Stripe)를 재발급하고 구 키 폐기 |
| 3 | `nomad-ai-factory/structer.zip`과 `structer_extracted/` 중복 중 zip 삭제, 시안 HTML은 `docs/design/`(`docs/reviews/nomad-ai-factory.md:47`) |
| 4 | `sellingstudio/image.png`, `image-1.png`, `tsconfig.tsbuildinfo` 제거 |
| 5 | sellingstudio 운영 Supabase 데이터가 있으면 `profiles`/`selling_pages`/`credit_logs`를 `_supabase-modular/ARCHITECTURE.md` 4.1 절차로 이관(크레딧은 `grant_credits(reason='migration')` 1회) |
| 6 | 원본 Supabase 프로젝트는 읽기 전용 2주 보관 후 정지 |

## 6. 인증 단계 관련 복사 금지 (2026-10-14 추가, 확정 결정 22)

3절 폐기 12번 행(`mock-login`, `nomad_role`, `nomad_plan`)과 4절 쿠키 권한·콜백 행에 이어서 본다. 원본의 모의 인증은 폐기이고 이식·참고 대상이 아니며 아래 복사 금지로만 남긴다. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 JWT, `isMockAuthAllowed()` 가드, 배포 환경 404)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키 역할 Mock(`mock-login` 라우트, `nomad_role`·`nomad_plan` 쿠키로 역할·플랜 판정) | `nomad-ai-commerce/middleware.ts:5-8`, 3절 12번 행(`docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96`, AUTH_ROADMAP 1장이 인용) | 권한 위조, 프로덕션 노출 | CM-06-007 Stage A Mock 로그인(`/api/dev/login`, 시드 페르소나), 권한은 `session_context`만. CI 금지 문자열(CM-06-036) |
| 다른 원본의 `mock-auth.ts`, localStorage 역할·플랜, `dev-user` 우회 | `docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88`, `docs/products/_platform-core/SECURITY_BASELINE.md` 17장 | 같은 결함 계열 | 같음 |
| 콜백 `next` 무검증, Host 헤더로 origin 구성 | `docs/reviews/sellingstudio.md:64`(4절 행) | 오픈 리다이렉트 | `finishLogin` 화이트리스트와 `NEXT_PUBLIC_APP_URL` 고정(04장 8절, CM-06-058 B-2) |
| MVP(A·B단계) 로그인 화면에 카카오 버튼 두기 | 01장 CM-F-001과 06장 CM-06-007의 이전 범위(이메일/Google/Kakao, 2026-10-13판) | 단계 순서 위반(카카오는 C1) | 카카오는 CM-06-059(G2 후). A단계 로그인 화면에는 실제 제공자 버튼이 없다 |
| 기능 코드의 `if (mock)`·페르소나 이메일 분기 | AUTH_ROADMAP 0장 불변 조건, 2.5절 | Mock과 실제 로그인의 권한 경로가 갈림 | 단계 분기는 `lib/auth/`, `app/(auth)/login/`, `app/auth/`, `app/api/dev/login/`에만(02장 9절) |
