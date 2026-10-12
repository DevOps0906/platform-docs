# 02 아키텍처: 신비로운AI

이 장은 분석이 요구한 "아키텍처 단일 결정 문서"(`docs/products/00_MERGE_ANALYSIS.md:404`)다. 원본 문서 사이의 모순(`docs/reviews/Astro_AI.md:47`, `:59`)은 아래 결정으로 닫는다.

| 쟁점 | 결정 | 근거 |
|---|---|---|
| 크레딧 차감 위치 | Next.js Route Handler(Vercel)가 service_role로 `core.consume_credits`를 호출한다. Edge Function 단계는 없다 | `docs/reviews/Astro_AI.md:82`, `docs/products/_platform-core/CORE_SPEC.md:172-181` |
| LLM 키 위치 | `astro-worker`(Railway)에만 둔다. Vercel 환경에는 LLM 키가 없다 | `AA/공통/CLAUDE.md:241`, `docs/reviews/Astro_AI.md:83` |
| 데이터 접근 | 읽기는 브라우저/RSC가 RLS SELECT로 직접 한다(암호문 컬럼은 GRANT 없음). 쓰기는 Route Handler와 워커만(service_role), 사용자 RPC는 `cancel_reading` 하나와 `preferences` 직접 쓰기뿐 | `docs/reviews/Astro_AI.md:59`, `docs/products/_platform-core/SECURITY_BASELINE.md:4장` |
| 진행률 | `astro.readings` `postgres_changes` 구독. broadcast 금지 | `docs/reviews/Astro_AI.md:84` |
| 사주 계산 위치 | 결정적 TS 엔진 `packages/saju-engine`. 브라우저(프리뷰, 데모 UI), Route Handler(리딩 생성 시 재계산·저장, Live Demo)에서 같은 코드를 쓴다. LLM은 수치를 만들지 않는다 | `docs/reviews/Astro_AI.md:86`, `docs/reviews/FortuneDocs.md:47`, `:67` |
| PDF | 공용 WeasyPrint 렌더 서비스(FastAPI). Puppeteer 없음 | 확정 결정 3, `docs/products/_platform-core/SHARED_MODULES.md:251-275` |

경로 표기: `AA/`는 `Astro AI/기획안/`, `FD/`는 `FortuneDocs/`.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router, React | 16.2.x(LTS), 19 | `AA/공통/CLAUDE.md:11`, `docs/reviews/FortuneDocs.md:66` |
| 스타일 | Tailwind CSS v4(CSS 변수 토큰), shadcn/ui | 4.x | `AA/공통/CLAUDE.md:12-13`, `docs/reviews/Astro_AI.md:66` |
| 상태 | Zustand(리딩 시작 스테퍼만), 나머지는 RSC | 5.x | `AA/대시보드/CLAUDE_DASHBOARD.md:158-187` |
| 인증/DB | Supabase Auth, Postgres 15, RLS, Storage, Realtime | `@supabase/ssr` | `docs/products/_platform-core/SHARED_MODULES.md:46-72` |
| 워커 | Node 22 + TS(`astro-worker`, core-jobs `runWorker`) | - | `docs/products/_platform-core/SHARED_MODULES.md:402-424`. 확정 결정 3의 FastAPI는 렌더 서비스가 맡는다 |
| PDF | WeasyPrint + Noto CJK(공용 `services/render-weasyprint`, Python/FastAPI) | 공용 서비스 버전 | 확정 결정 3, `AA/공통/CLAUDE.md:159-176` |
| LLM | 코어 LLM 게이트웨이: Anthropic 직접(Claude, 고품질) + OpenRouter 폴백 | 모델 ID는 설정값(원본 `claude-sonnet-4-6`, `AA/공통/CLAUDE.md:17`) | `docs/products/00_MERGE_ANALYSIS.md:331`, 01장 D-2 |
| 이메일 | Resend | - | `AA/공통/CLAUDE.md:19` |
| 결제 | Toss Payments 일반결제(MVP), 빌링키(Phase 2) | - | 확정 결정 4 |
| 검증 | zod(웹/워커 경계), Vitest(엔진·서버), Playwright(E2E), Lighthouse CI | - | `docs/products/_platform-core/SECURITY_BASELINE.md:10장` |
| 배포 | Vercel(웹), Railway(`astro-worker`, 공용 렌더 서비스), Supabase | - | `AA/공통/CLAUDE.md:21-22` |

## 2. 모듈 경계

모노레포 안 디렉토리 단위로 소유를 나눈다. 06장 작업의 소유 경계가 이 표를 따른다.

| 디렉토리 | 모듈 | 책임 | 의존 |
|---|---|---|---|
| `packages/saju-engine/` | 만세력 엔진 | 순수 함수: 양음력 변환, 절기 테이블, 4주, 십신, 오행 점수, 대운, Live Demo 키워드. I/O 없음, 브라우저·Node 공용 | 없음 |
| `packages/astro-report/prompts/`, `schema/`, `rules/` | 리포트 계약 | 장별 프롬프트, 현대적 재해석 사전, 출력 zod 스키마, 금지 표현 규칙 | saju-engine 타입 |
| `packages/astro-report/templates/`, `theme/` | 리포트 HTML | 책자 HTML 조립(escape), 오행 SVG 차트, `ThemeConfig → CSS 변수` 변환기 | prompts/schema |
| `apps/astro-ai/src/app/(marketing)/` | 랜딩, 가격, 샘플, 법적 페이지, `/llms.txt` | SSR 공개 페이지 | saju-engine(데모 UI) |
| `apps/astro-ai/src/app/(auth)/` | 로그인, 가입, 콜백 | Supabase Auth, `signup_app='astro'` | core-db |
| `apps/astro-ai/src/app/dashboard/` | 사용자 대시보드 | 홈, 보관함, 리딩 시작, 리딩 상세, 히스토리, 크레딧, 설정 | components/* |
| `apps/astro-ai/src/app/admin/` | 최소 어드민 | `platform_admin` 전용 화면 | api/admin |
| `apps/astro-ai/src/app/api/` | Route Handler | 04장 2절. 하위 폴더별 소유가 다르다(06장 1절) | core-* 패키지, server/* |
| `apps/astro-ai/src/server/` | 서버 전용 유틸 | `crypto/`(PII 암호화), `pricing.ts`, `ratelimit/`, `welcome-credits.ts` | core-* |
| `apps/astro-ai/src/components/` | UI | `ui/`(토큰·기본 컴포넌트), `chart/`(원국·오행·대운), `subjects/`, `reading/` | saju-engine |
| `apps/astro-worker/src/` | 워커 | `handlers/generate.ts`, `handlers/render.ts`, `handlers/purge.ts`, `delivery/`, `sweeper.ts` | astro-report, core-ai, core-jobs |
| `supabase/` | DB | 마이그레이션(모듈러 조각 사본 또는 모놀리스), `tests/` RLS 회귀 | - |
| `e2e/` | E2E | Playwright 시나리오 | 전체 |

## 3. 공용 모듈 사용

재정의하지 않는다. 기능이 모자라면 06장 6절에 코어 요청으로 남긴다.

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 세션, `requireSession('astro')`, 가입 `signup_app` | `proxy.ts`, 레이아웃, 모든 Route Handler 진입부 | 프로필 없으면 로그아웃(`docs/products/_platform-core/SHARED_MODULES.md:53`) |
| org | 개인 조직 1개만 노출 | 대시보드 레이아웃 | 멤버 초대 화면 없음(1인 1워크스페이스) |
| credits | 리딩·재생성 차감, 환영 크레딧 지급, 환불 | `api/readings`, `api/readings/[id]/renders`, `api/auth/welcome`, `api/admin/*` | 단가는 `server/pricing.ts`. 동기 실패 시 `refund_credits` |
| toss | 크레딧팩 주문·승인·취소 | `api/billing/*`, `api/admin/refunds` | `confirm_payment_order` 금액 대조 |
| webhooks | Toss 웹훅 수신(상태 동기화만) | `api/webhooks/toss` | 서명 검증 방식 미확인(`docs/products/_platform-core/SHARED_MODULES.md:174`) |
| llm gateway | 장별 해설 생성, 폴백 | `astro-worker/handlers/generate.ts` | 리딩 단위로 이미 차감했으므로 장별 호출은 `credits: 0` + `ai_usage.ledger_id` 연결(코어 요청 R-3) |
| weasyprint render | PDF 렌더 | `astro-worker/handlers/generate.ts`, `render.ts` | `app_id='astro'`, 내부 토큰, private network |
| storage | PDF 저장(`exports`), 테마 미리보기(`public-assets`) | 워커, `api/readings/[id]/download` | 경로 `<org>/astro/pdf/<uuid>.pdf` |
| jobs | `astro.reading.generate`, `astro.render.regenerate`, `astro.storage.purge` | Route Handler(enqueue), 워커(claim/complete/fail) | 4절 |
| audit | 리딩 취소, 대상 삭제, 탈퇴, 환불, 어드민 쓰기 | Route Handler, `cancel_reading` | `<entity>.<verb>` |
| rate limit | 생성, 데모, 다운로드, 가입 | `server/ratelimit` | `core.rate_limit_hit`, 키 `astro:<route>:<org 또는 ip_hash>` |
| fal client | 사용 안 함(MVP) | - | 테마 이미지는 정적 자산 |
| oauth, sns uploader, automation-core, affiliate, compliance | 사용 안 함 | - | 외부 연동·자동 게시·제휴 없음. 금지 표현은 제품 규칙 검사(01장 6.4절) |

## 4. 잡과 워커

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `astro.reading.generate` | `astro.reading` | TS(`astro-worker`) | 15/20/30(리딩 종류) | 장 단위 1회 + 잡 `max_attempts=2`, 지수 백오프 60초 | 최종 실패(`fail_job` 자동), 대기 중 취소(`cancel_reading`) |
| `astro.render.regenerate` | `astro.render` | TS(`astro-worker`) → 렌더 서비스 | 5 | `max_attempts=2` | 최종 실패 |
| `astro.storage.purge` | `astro.maintenance` | TS(`astro-worker`) | 없음 | `max_attempts=5` | 해당 없음 |
| 발송 루프(잡 아님) | `astro.deliveries` outbox | TS(`astro-worker` 30초 주기) | 없음 | 5분 간격 3회(`finish_delivery`) | 해당 없음 |
| 정합성 스위퍼(잡 아님) | - | TS(`astro-worker` 5분 주기) | 없음 | - | `core.jobs`가 failed/canceled인데 리딩이 진행 상태면 리딩을 `failed`로 맞춘다(환불은 `fail_job`이 이미 수행) |

리딩 생성 시퀀스:

| 단계 | 주체 | 동작 | 실패 처리 |
|---|---|---|---|
| 1 | 브라우저 | `POST /api/readings` + `request_id`(UUID) | - |
| 2 | Route Handler | `requireSession('astro')`, `features.readings`에 종류 포함 확인, 테마 허용 확인 | 401/402/403 |
| 3 | Route Handler | `rate_limit_hit('astro:readings:<org>', 10, 60)`, 진행 중 리딩 3건 이하 | 429 |
| 4 | Route Handler | 같은 `request_id` 리딩이 있으면 그대로 200 반환(멱등) | - |
| 5 | Route Handler | 대상 로드(admin 클라이언트, `org_id` 일치 확인) → 생년월일시 복호화 → `saju-engine`으로 원국 계산 | 404/422 |
| 6 | Route Handler | `consume_credits(..., 'consume:astro:<request_id>')` | `CR001` → 402 |
| 7 | Route Handler | `readings`(queued) + `reading_renders`(is_initial) INSERT → `enqueue_job(..., p_credit_ledger_id, 'job:astro:<request_id>', max_attempts 2)` → `readings.job_id` 갱신 | 6 이후 실패 시 `refund_credits(ledger, 'enqueue_failed', null, 'refund:enqueue:<request_id>')` 후 500 |
| 8 | 워커 | `claim_jobs('astro.reading')` → 리딩 `generating` → 장별 LLM 병렬(동시 3) → zod·금지 표현 검사 → `content` 저장 | 장 1회 재생성 → 그래도 실패면 `fail_job` |
| 9 | 워커 | 리딩 `rendering` → HTML 조립(실명은 이 시점에 복호화해 템플릿에 삽입) → 렌더 서비스 POST → 렌더 `succeeded`, 리딩 `completed` | 렌더 실패 → `fail_job(retryable=false)` |
| 10 | 워커 | 이메일 발송이 켜져 있으면 `deliveries` INSERT → `complete_job` | 발송 실패는 리딩 성공에 영향 없음 |

## 5. AI 라우팅

| purpose | 모델(quality / 폴백) | 크레딧 | 폴백 | 비고 |
|---|---|---|---|---|
| `astro.saju.chapter` | Claude Sonnet 계열 / OpenRouter 같은 계열 | 0(리딩 단위 차감) | 1회 | 장당 `maxTokens` 1,800(제안: 장당 500~900자) |
| `astro.tarot.chapter` | 같음 | 0 | 1회 | 카드 의미 사전을 시스템 프롬프트에 포함 |
| `astro.combined.bridge` | 같음 | 0 | 1회 | 사주·타로 연결 2장 |
| `astro.summary` | Claude Haiku 계열(fast) / OpenRouter | 0 | 1회 | 표지 한 줄 요약, 목차 부제 |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 입력 최소화 | 호칭 토큰 `{{호칭}}`, 성별, 원국 수치, 대운 나이, 타로 카드, 질문만. 실명·생년월일 원문은 보내지 않는다 | 01장 6.1절 |
| 수치 고정 | 오행 점수, 십신, 대운은 엔진 값을 그대로 주입하고 LLM 출력의 수치는 버린다 | `docs/reviews/FortuneDocs.md:47` |
| 출력 형식 | 장별 JSON `{title, body, highlights[]}`를 zod로 검증 | `docs/reviews/FortuneDocs.md:102` |
| 사용자 노출 모드 | 없음(품질 고정). "빠름/고품질" 2모드는 이 제품에서 쓰지 않는다 | 제안: 리포트 품질 편차 방지 |
| 이미지·음성 제공자 | 없음 | - |

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 "높음"은 Astro AI 8건, FortuneDocs 6건, 합계 14건이다. 기술·아키텍처 7건은 이 표에, 보안·데이터 7건은 `05_DATA_MODEL.md` 7장에 있다.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Astro_AI.md` 3장 #1 | `docs/reviews/Astro_AI.md:47` | 생성 경로가 문서마다 다름(Edge Function, Next, FastAPI) | 이 장 머리 결정표로 단일화: 차감은 Route Handler, LLM은 `astro-worker`, PDF는 공용 렌더 서비스. Edge Function과 `CLAUDE_TEMPLATE.md`의 `generateReading` 단일 함수는 폐기(07장 3절). `CLAUDE.md` 2장에 같은 규칙 | 02장 4절, AS-06-003, AS-06-010, AS-06-012 |
| `docs/reviews/Astro_AI.md` 3장 #3 | `docs/reviews/Astro_AI.md:49` | 만세력 사양 부재(음양력, 성별, 생시 모름, 절기 월주, 자시, 경도) | `packages/saju-engine` 사양서(SPEC.md)와 골든 테스트 100건을 엔진 구현보다 먼저 확정. 입력 모델 컬럼은 05장 `astro.subjects`. 사양 항목은 01장 AS-F-006 | AS-06-004, AS-06-005 |
| `docs/reviews/Astro_AI.md` 3장 #7 | `docs/reviews/Astro_AI.md:53` | 결제가 웹훅 중심, confirm 없음 | 코어 시퀀스(`docs/products/_platform-core/CORE_SPEC.md:210-221`): 주문 선저장 → 결제창 → successUrl → 서버 confirm API → `confirm_payment_order` 금액 대조·멱등 지급. 웹훅은 취소 동기화만. 금액 불일치는 `PM001`이며(같은 호출의 주문 UPDATE는 롤백) Route Handler가 별도 호출로 `fail_payment_order(order_id, 'amount_mismatch', {...})`(service_role, 2026-10-13 코어 반영)를 불러 주문을 failed로 남기고 이어 운영 알림과 Toss 취소를 수행 | 04장 2절 billing, AS-06-008, AS-06-029 |
| `docs/reviews/Astro_AI.md` 3장 #8 | `docs/reviews/Astro_AI.md:54` | 가상 평점·후기·카운터를 구조화 데이터와 랜딩에 넣음 | 리뷰 분류는 보안이지만 DB 객체와 무관한 법무·마케팅 결함이라 이 장에 둔다. JSON-LD에서 `aggregateRating`, `Review` 제거, 후기 마퀴 섹션 삭제, 카운터는 DB 집계값 + 집계 시각 + 1,000건 미만 숨김. CI에서 빌드 산출물에 `aggregateRating` 문자열이 있으면 실패 | 01장 6.4절, 03장 4절, AS-06-023 |
| `docs/reviews/FortuneDocs.md` 3장 #1 | `docs/reviews/FortuneDocs.md:40` | KASI 음력 간지 직접 사용으로 년·월주 오류, 시주 없음, 진태양시·서머타임 미정 | 로컬 절기 절입 시각 테이블(1900~2100) 기반 결정적 엔진. KASI는 배치 검증 스크립트에서만 호출(`packages/saju-engine/scripts/verify-kasi`). 런타임에 외부 만세력 API 호출 0 | AS-06-005, AS-06-030 |
| `docs/reviews/FortuneDocs.md` 3장 #2 | `docs/reviews/FortuneDocs.md:41` | 대운 순역행·대운수 규칙 없음, 성별 NULL 허용 | 엔진 사양: 남·양년간 또는 여·음년간이면 순행, 아니면 역행. 대운수는 출생 시각과 다음(순행)/이전(역행) 절입 시각 사이 일수 ÷ 3(나머지 처리 규칙은 SPEC.md에서 확정, 골든 테스트로 고정). DB는 `subjects.gender not null` + CHECK(05장) | AS-06-004, AS-06-005, 05장 2절 |
| `docs/reviews/FortuneDocs.md` 3장 #6 | `docs/reviews/FortuneDocs.md:45` | Puppeteer는 Vercel 서버리스·Edge에서 동작 안 함, 한글 폰트 없음 | PDF는 Railway의 공용 WeasyPrint 컨테이너(Noto CJK 포함, 기동 시 폰트 존재 검사)만 쓴다. Vercel에서는 렌더하지 않고, Edge 런타임을 쓰지 않는다(모든 Route Handler `runtime = 'nodejs'`). 테마 미리보기도 같은 서비스의 첫 페이지 이미지 | 02장 7절, AS-06-015 |

## 7. 배포 토폴로지

| 구성요소 | 위치 | 공개 여부 | 통신 |
|---|---|---|---|
| `apps/astro-ai` | Vercel(서울 리전 선호, 미확인) | 공개 | Supabase(anon key + 쿠키, service_role는 서버 함수만) |
| `apps/astro-worker` | Railway | 비공개(인바운드 없음) | Supabase(service_role), 렌더 서비스(private network), Anthropic/OpenRouter, Resend |
| `services/render-weasyprint` | Railway(flora-publishing 소유, 공용) | 비공개 | `X-Render-Token` + private network(`docs/products/_platform-core/SHARED_MODULES.md:259`) |
| Supabase | 모듈러 통합 프로젝트(기본) 또는 astro 단독 프로젝트 | API 공개(RLS) | Storage `exports` 서명 URL |
| 스케줄 | pg_cron 또는 워커 크론 | - | `reap_stale_jobs`, `expire_stale_payment_orders`, `purge_rate_limit_buckets`(코어), 발송 루프 30초, 스위퍼 5분, 탈퇴 30일 purge 일 1회 |

렌더 호출 경로: `astro-worker` → `POST http://render-weasyprint.railway.internal/render/pdf`(`app_id='astro'`, `job_id`, sanitize된 HTML, A4 프리셋) → 렌더 서비스가 `exports/<org>/astro/pdf/<uuid>.pdf`에 저장 → 경로 반환 → 워커가 `reading_renders` 갱신. 사용자는 `GET /api/readings/[id]/download`가 발급하는 7일 서명 URL로만 받는다.

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 동작 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 브라우저/SSR 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | Route Handler, 워커 | 서버 전용 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`/`public` 전환 | 서버 전용 | 기본 `core` |
| `ASTRO_DB_SCHEMA` | `astro`/`public` 전환 | 서버 전용 | 기본 `astro` |
| `ASTRO_PII_KEY_V1`(… `V<n>`), `ASTRO_PII_KEY_VERSION` | 생년월일시·이름·질문·수신자 암호화(AES-256-GCM, 32바이트 base64) | 서버 전용(웹 + 워커) | 기동 실패. 0키 폴백 금지(`docs/products/_platform-core/SECURITY_BASELINE.md:5장`) |
| `TOSS_CLIENT_KEY` | 결제창 | 공개(`NEXT_PUBLIC_TOSS_CLIENT_KEY`) | 결제 화면 비활성 + 오류 표시 |
| `TOSS_SECRET_KEY` | confirm/취소 API | 서버 전용 | 기동 실패 |
| `TOSS_WEBHOOK_SECRET` | 웹훅 검증(방식 미확인) | 서버 전용 | 웹훅 라우트 401 고정 |
| `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY` | LLM | 워커 전용(Vercel에 넣지 않음) | 워커 기동 실패 |
| `RENDER_SERVICE_URL`, `RENDER_SERVICE_TOKEN` | 렌더 서비스 | 워커 전용 | 워커 기동 실패 |
| `RESEND_API_KEY`, `MAIL_FROM` | 이메일 | 워커 전용 | 발송 루프만 비활성 + 운영 알림 |
| `IP_HASH_SALT_SEED` | IP 일 단위 솔트 해시(레이트 리밋, 동의 기록) | 서버 전용 | 기동 실패 |
| `APP_BASE_URL` | successUrl, 이메일 링크 | 서버 전용 | 기동 실패 |
