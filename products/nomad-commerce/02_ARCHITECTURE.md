# 02 아키텍처: NOMAD Commerce

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router + `proxy.ts` | 16.2.7 | `sellingstudio/PRD.md:16`, `docs/reviews/sellingstudio.md:13` |
| UI | React, Tailwind CSS, shadcn/ui, sonner | 19.2 / v4 | 같은 줄 |
| 상태 | Zustand(UI 상태만. 큐 루프 금지) | 5 | `docs/reviews/Nomad-AI-Factory_V.2.md:44` |
| 검증 | zod | 4 | `docs/reviews/sellingstudio.md:14` |
| 캔버스(Phase 2) | @xyflow/react | 12 (V.2의 "v11" 표기는 오류) | `docs/reviews/Nomad-AI-Factory_V.2.md:54` |
| DB/인증/스토리지/Realtime | Supabase(PostgreSQL 15) | - | 확정 결정 5 |
| 워커 | Node 22 컨테이너(Railway), Puppeteer + Sharp + Noto Sans KR | Sharp 0.34+ | `sellingstudio/PRD.md:34`, `docs/reviews/Nomad-AI-Factory_V.2.md:106` |
| 엑셀 | SheetJS(xlsx) | 고정 버전 | `sellingstudio/PRD.md:36` |
| 결제 | Toss Payments | - | 확정 결정 4 |
| 패키지 관리 | pnpm 모노레포, lockfile 커밋, `latest` 금지 | - | `SECURITY_BASELINE.md` 13장 |

영상 렌더(Python FFmpeg)는 nomad-video 소유이며 commerce는 워커 API만 호출한다(확정 결정 6, C-6 `docs/products/00_MERGE_ANALYSIS.md:956`).

## 2. 모듈 경계

| 모듈 | 디렉토리 | 책임 |
|---|---|---|
| 도메인 상수 | `packages/commerce-domain/` | 18슬롯, 유형별 기본 슬롯, 필수 슬롯, 8단계 phase·진행률, 마켓 규격 표, features 파서, 크레딧 단가, 마진 계산, zod 스키마 |
| 금지어 매처 | `packages/commerce-compliance/` | `banned_words` 로드, 한글 경계 매칭, 치환, 하이라이트(escape), core compliance 모듈 주입 |
| 안전 fetch | `packages/commerce-net/` | URL 허용 목록, DNS 해석 후 사설 IP 차단, 리다이렉트 3회, 2MB, 10초 |
| 소싱 | `packages/commerce-sourcing/amazon/`, `excel/` | ASIN 추출·공급자 어댑터, 엑셀 파서(오너클랜, 자유 양식) |
| 마켓 어댑터 | `packages/commerce-markets/coupang/`, `smartstore/` | 서명, 카테고리, 상품 등록, 상태 조회, 오류 정규화 |
| 웹 앱 | `apps/nomad-commerce/` | 화면, Route Handler, 세션, 결제 화면 |
| 웹 API | `apps/nomad-commerce/app/api/<영역>/` | products, sourcing, detail-pages, ai, listings, uploads, exports, market-accounts, billing, webhooks |
| 워커 | `services/commerce-worker/src/<영역>/` | runtime(루프·디스패처·크론), detail, images, render, convert, import, upload, export |
| DB | `docs/products/_supabase-modular/migrations/1400_commerce.sql`(정본), 모놀리스 변환본 | 05장 |

규칙: 앱과 워커는 `packages/*`만 공유한다. 앱 코드에서 워커 코드를 import하지 않는다. 06장 소유 경계는 이 표를 따른다.

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 로그인, `requireSession('commerce')`, `session_context` | `apps/nomad-commerce/proxy.ts`, Route Handler 진입부 | SHARED_MODULES 2장 |
| org | 개인 조직(1인 1워크스페이스). 멤버 초대 화면은 MVP에 없음 | 레이아웃 | 3장 |
| credits | 선차감, 환불, `withCredits` | `app/api/detail-pages/`, `app/api/ai/`, 워커 실패 경로 | 4장. 단가는 `packages/commerce-domain`이 주입 |
| toss | 구독 빌링키, 크레딧팩 | `app/api/billing/` | 5장 |
| webhooks | Toss, fal 수신(서명·멱등) | `app/api/webhooks/` | 6장 |
| oauth | MVP 미사용(마켓은 키 방식). Phase 2 SNS | - | 7장 |
| 자격증명(vault) | 마켓 API 키 암호화 저장·복호화 | `app/api/market-accounts/`, 워커 upload | 7장 `CredentialVault` |
| llm gateway | storyline, copy, naming, keywords, vision, analyze, translate, notice_autofill, category_suggest, compliance | 워커 detail, `app/api/ai/` | 8장 |
| fal client | 슬롯 이미지, 누끼, STT | 워커 images, `app/api/ai/voice` | 9장, `enable_safety_checker=true` |
| sns uploader | Phase 2 소비 | - | 11장 |
| automation-core | Phase 2 노드 등록 | `apps/nomad-commerce/lib/automation/` | 12장 |
| compliance | 규칙(commerce 사전) + LLM 판정 | 워커 verify, 편집 저장 | 13장 |
| storage | `org-files`(원본·마스터·변환본), `exports`(ZIP/엑셀) | 워커, 업로드 | 14장 |
| audit | WARN 확인, 마켓 계정 추가/삭제, 결제 환불, 내보내기 | RPC, Route Handler | 15장 |
| jobs | 모든 비동기 작업 | 워커 | 16장 |
| affiliate | 사용하지 않음 | - | 확정 결정 12 |
| weasyprint | 사용하지 않음 | - | 확정 결정 3 |

## 4. 잡과 워커

생성 요청은 `detail_pages`(status `waiting`)로 먼저 저장하고, 워커의 디스패처가 조직별 `features.concurrency`만큼만 `core.enqueue_job`을 호출한다. core `claim_jobs`는 조직별 동시성을 모르므로 이 구조로 플랜 동시성을 집행한다(리뷰 V2 #1).

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `detail.generate` | `commerce.detail` | TS 워커 | 예(9/14, 요청 시. ledger를 잡에 연결) | 3회, 60초 x 2^n | 최종 실패·대기 중 취소 시 core 자동 환불. 일부 슬롯만 실패하면 페이지는 ready, 실패 슬롯 수 x 1 부분 환불 |
| `detail.slot_regenerate` | `commerce.detail` | TS | 예(1 또는 3) | 3회 | 실패 시 자동 환불 |
| `import.amazon` | `commerce.import` | TS | 예(건당 1) | 2회 | 공급자 오류·없는 ASIN 환불 |
| `import.excel` | `commerce.import` | TS | 아니오 | 1회 | - |
| `upload.coupang` / `upload.smartstore` | `commerce.upload` | TS | 아니오 | 3회(5xx·429만), 4xx는 즉시 실패 | - |
| `upload.poll_status` | `commerce.upload` | TS(크론 10분) | 아니오 | - | - |
| `export.excel` / `export.zip` | `commerce.export` | TS | 아니오 | 2회 | - |

| 크론(워커, service_role) | 주기 | 동작 |
|---|---|---|
| 디스패처 | 5초 | `waiting` 상세페이지를 조직별 남은 동시성만큼 `queued`로 바꾸고 `enqueue_job` |
| 업로드 상태 폴링 | 10분 | `submitted` 업로드의 마켓 승인 상태 조회 |
| 환율 | 평일 11:30 KST | 수출입은행 API → `exchange_rates` |
| 내보내기 만료 | 매일 | 7일 지난 `export_files` → expired, 파일 삭제 |
| 소진 알림 | 1시간 | 50/80/90% |
| core 스케줄 | core 문서 | `run_monthly_credit_grants`, `reap_stale_jobs(600)` 등 |

워커 규약: 하트비트 30초, `heartbeat_job`이 false면 중단(취소 신호). running 잡의 사용자 취소는 `detail_pages.cancel_requested_at`을 워커가 확인.

## 5. AI 라우팅

| purpose | 모델(fast / quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `storyline` | - / anthropic/claude-sonnet-4-6 | 상세페이지 단가 포함 | openai/gpt-5-mini 1회 |
| `copy` | openai/gpt-5-mini / anthropic/claude-sonnet-4-6 | 포함 | 반대쪽 모델 |
| `naming`, `keywords` | google/gemini-2-5-flash | 1 | gpt-5-mini |
| `vision` | openai/gpt-5-mini | 포함(입력 단계) | 없음, 실패 환불 |
| `analyze`(URL 벤치마킹) | deepseek/deepseek-chat-v4-flash | 2 | gemini-2-5-flash |
| `translate` | gemini-2-5-flash | 포함 | gpt-5-mini |
| `notice_autofill`, `category_suggest` | gemini-2-5-flash | 1 | gpt-5-mini |
| `compliance` | gpt-5-mini | 포함/재판정 1 | 실패 시 규칙 결과만으로 WARN |

모델 맵 출발점은 `sellingstudio/lib/llm/openrouter.ts:3-8`. 모델 ID는 미확인이며 core llm gateway 설정으로 교체한다. 모든 출력은 zod로 검증하고 실패 시 1회 재요청 후 실패.

| 이미지/음성 | 제공자 | 용도 | 플랜 |
|---|---|---|---|
| AI 씬 | fal flux schnell / dev / pro v1.1 / pro v1.1 ultra | ai_scene 슬롯 | `image_quality` draft/standard/pro/ultra(`sellingstudio/PRD.md:26-29`) |
| 누끼 | fal birefnet | cutout 슬롯(T-1, T-3) | 전 플랜 |
| STT | fal whisper | 음성 입력 | starter+ |
| 렌더 | Puppeteer(워커 내) | infographic, legal 슬롯 | 전 플랜 |

## 6. 리뷰 "높음" 결함의 차단 설계

보안·데이터 외 5건을 다룬다. 보안·데이터 17건은 05장 7절에 있다.

보안·데이터 17건은 `05_DATA_MODEL.md` 7절. 합계 22 = 리뷰 높음 22.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #1 | `docs/reviews/Nomad-AI-Factory_V.2.md:44` | 80~240초 생성을 Route Handler SSE 안에서 동기 실행, 큐는 브라우저 Zustand | Route Handler는 차감·저장·대기 등록만 하고 800ms 안에 반환. `detail_pages`(waiting) → 디스패처 → `core.jobs` → Node 워커 컨테이너(Puppeteer/Sharp). 진행률은 `core.jobs`와 `detail_page_slots` Realtime. SSE와 Zustand 큐 루프 없음. Vercel에 Puppeteer 없음 | 4절, CM-06-010, CM-06-012, CM-06-013 |
| `docs/reviews/Nomad-AI-Factory_V.2.md` 3장 #7 | `docs/reviews/Nomad-AI-Factory_V.2.md:50` | 슬롯 정의 3벌, 15장이 실제 18슬롯, `MANDATORY_SLOTS`가 educational 기본값과 모순 | 18슬롯 정본, 필수 T-1·L-3(01장 CM-F-020). `packages/commerce-domain` 단일 상수 + DB CHECK(`detail_pages_slots_check`, `slot_code` CHECK). 유형별 기본값이 필수를 포함하는지 단위 테스트 | CM-06-006, 05장 2절 |
| `docs/reviews/nomad-ai-commerce.md` 3장 #4 | `docs/reviews/nomad-ai-commerce.md:61` | 미들웨어(모의 세션 허용)와 레이아웃(Supabase만 인정)이 달라 로그인 불가 | 판정 경로를 `requireSession` 하나로: `proxy.ts`와 서버 레이아웃이 같은 `session_context`를 쓴다. 모의 로그인 경로 없음. 소셜 로그인 실제 연결 E2E | CM-06-007, CM-06-035 |
| `docs/reviews/nomad-ai-commerce.md` 3장 #5 | `docs/reviews/nomad-ai-commerce.md:62` | 워크플로우 엔진이 `default` 노드에서 실패, 엣지 무시 | MVP에 캔버스 없음. Phase 2는 core automation-core(엣지 필수, 위상 정렬, 미등록 노드 거부)에 commerce 노드만 등록 | CM-06-039, SHARED_MODULES 12장 |
| `docs/reviews/sellingstudio.md` 3장 #5 | `docs/reviews/sellingstudio.md:62` | Capacitor가 dev 서버를 평문으로 로드, 배포 불가 | MVP 제외(확정 결정 9). Phase 2: 배포 HTTPS URL 원격 셸, `CAP_SERVER_URL` 환경 분리, `cleartext`·`allowMixedContent`·외부 와일드카드 제거. 웹 MVP에는 `lib/capacitor`를 이식하지 않음 | CM-06-040, 07장 |

## 7. 배포 토폴로지

| 구성요소 | 위치 | 네트워크 |
|---|---|---|
| 웹(`apps/nomad-commerce`) | Vercel | 공개. Route Handler는 service_role 키를 서버에서만 사용 |
| 워커(`services/commerce-worker`) | Railway 컨테이너 1~N | 공개 포트 없음(헬스체크만 내부). Supabase, fal, OpenRouter, 마켓 API, 공급자 API로만 아웃바운드 |
| DB | Supabase 통합 프로젝트(모듈러) | RLS. 워커는 service_role |
| 웹훅 | `/api/webhooks/toss`, `/api/webhooks/fal` | 공개, 서명 검증·레이트 리밋·1MB 상한 |
| video 렌더(Phase 2) | nomad-video 워커 API | 내부 서비스 토큰 |

마켓 API 호출은 워커에서만 한다(키 복호화 지점을 하나로). 쿠팡 Open API가 호출 IP 등록을 요구하면(미확인) Railway 고정 아웃바운드 IP를 쓴다.

## 8. 환경변수

| 변수 | 용도 | 공개 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 클라이언트 | 예 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버, 워커 | 아니오 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core` 또는 `public` | 아니오 | 기동 실패 |
| `NEXT_PUBLIC_APP_URL` | 콜백 origin 고정 | 예 | 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 마켓 키 AES-256-GCM | 아니오 | 기동 실패(0키 폴백 금지) |
| `OPENROUTER_API_KEY` | LLM | 아니오 | 기동 실패 |
| `FAL_KEY`, `FAL_WEBHOOK_SECRET` | 이미지, 웹훅 URL 토큰 | 아니오 | 기동 실패 |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | 결제 | 클라이언트 키만 공개 | 기동 실패 |
| `AMAZON_DATA_PROVIDER`, `AMAZON_DATA_API_KEY` | 아마존 공급자 | 아니오 | 아마존 가져오기 비활성(엑셀은 동작) |
| `KOREAEXIM_API_KEY` | 환율 | 아니오 | 위젯 "환율 정보 없음" |
| `WORKER_ID`, `WORKER_CONCURRENCY_DETAIL` | 워커 | 아니오 | 기본값 |
| `VIDEO_WORKER_URL`, `VIDEO_WORKER_TOKEN` | Phase 2 쇼츠 | 아니오 | 쇼츠 메뉴 숨김 |

마켓 키는 환경변수에 두지 않는다(V.2의 `COUPANG_ACCESS_KEY`, `NAVER_COMMERCE_CLIENT_ID` 단일 값 폐기, `Nomad-AI-Factory_V.2/CLAUDE.md:217-219`).
