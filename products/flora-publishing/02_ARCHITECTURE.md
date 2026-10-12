# 02 아키텍처: FLORA Publishing

작성일 2026-10-12. 공용 모듈은 `docs/products/_platform-core/SHARED_MODULES.md`(아래 SM)와 `CORE_SPEC.md`(아래 CS)를 참조만 한다. 분석은 `docs/products/00_MERGE_ANALYSIS.md:줄`(아래 "분석:줄").

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router, React, TypeScript strict, Tailwind v4, shadcn v4(@base-ui), `src/proxy.ts` | Next 16.2.x(basic-master-module 기준 16.2.9 제안), React 19.2 | `Flora-v2/PRD.md:493-497`, 분석:1334 |
| 에디터 | Tiptap(ProseMirror) | 2.x 고정(제안) | `flora-publisher/frontend/docs/prd/03_features.md:107` |
| API(제품 로직) | Next Route Handlers(Node 런타임) | 위와 같음 | 01장 D1 권고(b) |
| TS 워커 | Node 20 + `packages/core-jobs` 워커 루프 | Node 20 LTS | SM 16장 |
| 출판 엔진 | FastAPI + Python 3.11 + pdfplumber, python-docx(mammoth 대체 가능), nh3(sanitize), ebooklib 또는 v1 ePub3 빌더 | FastAPI 0.115, Python 3.11.9 | 확정 결정 3, `docs/reviews/Flora-v2.md:14`, `:128` |
| PDF 렌더 서비스 | `services/render-weasyprint`(FastAPI 컨테이너, WeasyPrint + Noto CJK) | WeasyPrint 62 이상(제안) | SM 10장, 확정 결정 3 |
| DB/인증/Storage | Supabase(PostgreSQL 15, Auth, Storage, Realtime) | 15 | `_PRODUCT_AGENT_BRIEF.md:68` |
| 결제 | Toss Payments(일반결제, 빌링키) | API v1 | 확정 결정 4 |
| LLM | 공용 LLM 게이트웨이(Anthropic 직접 + OpenRouter 폴백, fast/quality) | - | SM 8장, 분석:154 |
| 이미지 | 공용 fal 클라이언트 | - | SM 9장 |
| 배포 | Vercel(web), Railway(TS 워커, 엔진, 렌더 서비스, private network) | - | `Flora-v2/PRD.md:505`, `docs/reviews/SellingDocs.md:77` |

확정 결정 6(TS 오케스트레이션 + Python 미디어)은 video용이지만 같은 원칙을 따른다: LLM 생성 잡은 TS 워커, 문서 처리 잡은 Python 엔진.

## 2. 모듈 경계

```
apps/flora-publishing/
  web/                         Next.js (Vercel)
    src/proxy.ts               라우트 보호(session_context)
    src/app/(marketing)/       랜딩, 가격, 법무
    src/app/(auth)/            로그인, 가입, 재설정
    src/app/auth/callback/     OAuth 콜백(next 화이트리스트)
    src/app/(app)/dashboard/   대시보드, 책 목록, 설정, 결제
    src/app/(app)/books/[id]/  위저드, 에디터, 완성/내보내기
    src/app/admin/             운영자 화면
    src/app/(public)/b/[slug]/ 공개 책 페이지(Phase 2)
    src/app/api/               Route Handlers (04장 2절)
    src/features/<feature>/    화면 단위 컴포넌트와 훅(wizard, editor, books, billing, settings, landing)
    src/server/                서버 전용: prompts/, personas/, pricing/, features/, engine-client/, sanitize/
    src/data/                  personas.json(60종), formats.json(6종), seeds/*.json(3종), themes.json(7종)
  worker/                      TS 워커 (Railway)
    src/handlers/              write-section, write-all, refine-all, cover, webhook-deliver, purge
  engine/                      FastAPI 출판 엔진 (Railway, private)
    app/parsers/               txt, md, docx, pdf
    app/html/                  HTML 조립, 템플릿(v1 html-templates 이식), sanitize
    app/presets/               판형 프리셋 -> @page CSS (v1 print-presets 이식)
    app/epub/                  ePub3 빌더(v1 이식)
    app/jobs/                  Python 워커: parse, render.pdf(렌더 서비스 호출), export_epub
services/render-weasyprint/    공용 PDF 렌더 서비스 (flora-publishing 소유, astro 소비)
supabase/                      모놀리스 마이그레이션 또는 모듈러 조각 링크, tests/
```

| 모듈 | 책임 | 하지 않는 것 |
|---|---|---|
| web | 인증·세션, 크레딧 선차감, 동기 LLM 호출(스트리밍 포함), Toss, 잡 enqueue, 서명 URL 발급, 화면 | PDF 렌더, 파일 파싱, 장시간 루프 |
| worker(TS) | `publishing.llm`, `publishing.media`, `publishing.events` 큐: 섹션 생성, 전체 생성 오케스트레이션, 표지(fal), 웹훅 발송, 휴지통 purge | HTML/PDF 생성 |
| engine(Python) | `publishing.doc`, `publishing.render` 큐: 업로드 파싱, HTML 조립(미리보기 포함), ePub, 렌더 서비스 호출, Storage 저장 | LLM 호출, 크레딧 차감(선차감은 enqueue 측이 이미 함) |
| render-weasyprint | HTML + 프리셋 → PDF. url_fetcher 허용 목록, 폰트 검증 | DB 접근(경로·job_id만 받는다), 인증된 사용자 요청 직접 수신 |

데이터 정본은 DB다. 클라이언트는 원고 HTML을 서버로 보내 렌더시키지 않는다. 렌더·메타데이터·ePub은 `book_id`만 받아 서버가 DB에서 읽는다(`docs/reviews/Flora-v2.md:115`).

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 가입(`signup_app='publishing'`), 세션, `requireSession` | web `proxy.ts`, 모든 Route Handler | SM 2장 |
| org | 개인 조직(1인 1워크스페이스). 멤버 초대 UI 없음 | 세션 컨텍스트 | SM 3장 |
| credits | 선차감-환불, `withCredits`, `priceOf`(단가표는 `web/src/server/pricing`) | Route Handler, TS 워커 | CS 4.3 |
| toss | 팩·구독 주문, confirm, 빌링키, 정기결제 워커 | `web/src/app/api/billing/*`, 공용 정기결제 워커 | SM 5장 |
| webhooks | Toss·fal 수신 검증과 멱등, 아웃바운드 HMAC 서명 | `/api/webhooks/toss`, `/api/webhooks/fal`, worker `webhook-deliver` | SM 6장 |
| llm gateway | 모든 텍스트 생성(purpose별, fast/quality) | Route Handler, TS 워커 | SM 8장 |
| fal client | 표지 3후보, Storage 복사 | TS 워커 `cover` | SM 9장 |
| weasyprint render | PDF 생성(이 제품이 소유·운영) | engine `render.pdf` 잡 → 렌더 서비스 | SM 10장 |
| storage | `org-files`(원고 업로드, 표지), `exports`(PDF, ePub), `public-assets`(공개 책 표지 사본, Phase 2) | web(서명 URL), engine, worker | SM 14장 |
| audit | 공개 전환, 생성 취소, 운영자 조정, 환불, 탈퇴 | RPC 내부, 서버 경로 | SM 15장 |
| jobs | 모든 비동기 작업 상태 정본, Realtime 진행률 | 전 계층 | SM 16장 |
| 자격증명(oauth 모듈의 vault 부분) | 아웃바운드 웹훅 서명 비밀 보관 | web(등록 시 put), worker(get) | SM 7장 `CredentialVault`. OAuth state는 쓰지 않는다 |
| rate limit | 생성 API, 미리보기, 대기자, 웹훅 수신 | Route Handler | CS 12장 |
| 쓰지 않음 | sns uploader, automation-core, compliance, affiliate | - | 자동화 캔버스·n8n 폐기(분석:138-140), SNS·제휴 없음 |

## 4. 잡과 워커

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `publishing.write_section` | `publishing.llm` | TS | 섹션당 1(fast)/2(quality), enqueue 직전 | 3회, 지수 백오프(코어 기본 60초 x 2^n, 첫 재시도는 `run_after` 10초로 단축 제안) | 3회 소진 또는 재시도 불가 실패 → `fail_job` 자동 환불. 취소된 대기 잡 → `cancel_job` 환불 |
| `publishing.write_all` | `publishing.llm` | TS | 없음(자식이 각각 차감). 시작 전 예상 합계를 잔액과 비교해 부족하면 402 | 0(부모는 재시도하지 않음, 회수 시 실행 `failed`) | 해당 없음 |
| `publishing.refine_all` | `publishing.llm` | TS | 없음(청크 자식 잡이 각각 1) | 0 | 위와 같음 |
| `publishing.refine_chunk` | `publishing.llm` | TS | 청크당 1 | 2회 | 실패 자동 환불 |
| `publishing.cover_generate` | `publishing.media` | TS | 6(3후보) | 1회(제출 실패만) | 후보별 실패분 `refund_credits(p_amount=2)` 부분 환불. 안전 필터 거부는 재시도 없이 환불 |
| `publishing.parse_manuscript` | `publishing.doc` | Python | 0 | 2회 | 해당 없음 |
| `render.pdf` | `publishing.render` | Python(엔진 → 렌더 서비스) | 2 | 1회(네트워크·타임아웃만). HTML/CSS 오류는 재시도 불가 | 최종 실패 자동 환불 |
| `publishing.export_epub` | `publishing.doc` | Python | 1 | 1회 | 최종 실패 자동 환불 |
| `publishing.webhook_deliver` | `publishing.events` | TS | 0 | 5회(1분, 5분, 30분, 2시간, 6시간, 제안) | 해당 없음 |
| `publishing.purge` | `publishing.maintenance` | TS(일 1회) | 0 | 3회 | 해당 없음 |

전체 순차 생성 흐름(분석:98, `flora-publisher/frontend/docs/prd/03_features.md:86-97`):

| 단계 | 동작 |
|---|---|
| 1 | Route Handler: 엔타이틀먼트·`write_all` 기능 확인 → 대상 섹션(본문 없는 것, 또는 덮어쓰기 선택분) 수 x 단가 = 예상치. 잔액 < 예상치면 402 + 부족량 |
| 2 | `generation_runs` INSERT(service_role) + 부모 잡 enqueue(멱등 키 `job:publishing:<request_id>`). 책당 진행 실행 1개는 부분 유니크 인덱스가 강제(23505 → 409) |
| 3 | 부모 핸들러: 창 크기 3으로 자식 `write_section` enqueue. 자식마다 `consume_credits(idempotency 'consume:publishing:<run_id>:<section_id>')` 후 enqueue. `CR001`이면 남은 섹션을 `skipped`로 세고 중단 |
| 4 | 자식 완료 → 섹션 `generated` 저장(sanitize), `done_sections+1`. 3회 실패 → 섹션 `failed`, 환불(코어) |
| 5 | 부모는 30초마다 하트비트와 `cancel_requested_at` 확인. 취소면 대기 자식 `cancel_job`(환불), 실행 중 자식은 끝나게 둔다 → 실행 `canceled` |
| 6 | 종료: 실패 0이면 `succeeded`, 일부 실패면 `partial`. 앞 챕터 요약(옴니버스 모드면 생략)은 챕터 첫 섹션 생성 직전에 원고에서 계산 |

## 5. AI 라우팅

모델 이름은 게이트웨이 설정으로 바꾼다(SM 8장 `resolveModel`). 아래는 기본값 제안.

| purpose | 모델(fast / quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `pub.title` | Anthropic 경량 / 표준 | 1 | OpenRouter 동급 1회 |
| `pub.plan` | 표준 / 상위 | 2 | 같음 |
| `pub.toc` | 표준 / 상위 | 2 | 같음 |
| `pub.section` | 표준 / 상위 | 1 / 2 | 같음 |
| `pub.assist`(continue, expand, refine) | 경량 / 표준 | 1 | 같음 |
| `pub.refine_chunk` | 표준 / 상위 | 1 | 같음 |
| `pub.metadata` | 경량 / 표준 | 1 | 같음 |
| `pub.persona_blend` | 표준 / 표준 | 3 | 같음 |
| `pub.upload_review` | 경량 / 경량 | 0(제목·기획 단가로 별도 과금) | 같음 |
| `pub.cover_prompt` | 경량 | 표지 단가에 포함 | 같음 |

| 제공자 | 용도 | 비고 |
|---|---|---|
| fal | 표지 이미지 3후보 | 모델 1개(01장 D11). 안전 필터 켬(SM 9장) |
| OpenRouter | LLM 폴백 | v1 `_call_via_openrouter` 설계를 게이트웨이가 대체 |
| TTS | 없음(Phase 2) | 01장 D2 |

프롬프트 규칙: 시스템 프롬프트 = 제품 공통 규칙 + 페르소나 Taste(JSON 단일 소스) + 어조(Basic) + Skill. 출력이 JSON인 purpose는 zod 스키마 검증, 1회 재요청 후 실패면 환불. mock 응답 금지(분석:155).

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 4건의 "높음" 항목 합계 25건 중 비보안 13건이 이 표에, 보안·데이터 12건은 `05_DATA_MODEL.md` 7절에 있다(13 + 12 = 25).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Flora-v2.md` 3장 #1 | `Flora-v2/frontend/src/app/(auth)/login/page.tsx:27-45` | GoTrue raw fetch 로그인이 세션 쿠키를 만들지 않음 | 로그인·가입은 `packages/core-db`의 `createBrowserClient().auth.*`만 쓴다. raw `/auth/v1` 호출을 린트 규칙(금지 문자열)으로 막고, E2E가 "로그인 → 새로고침 → /dashboard 유지"를 검사 | PB-06-006, PB-06-037 |
| `docs/reviews/Flora-v2.md` 3장 #2 | `frontend/src` Bearer 0건 | 프론트가 토큰을 안 보내 인증 API 전부 401 | 브라우저 → Next Route Handler는 같은 오리진 쿠키 세션(`createServerClient`). 브라우저가 FastAPI를 직접 부르지 않는다(엔진은 private). 클라이언트 fetch는 `web/src/lib/api/apiFetch` 하나만 쓴다 | PB-06-007, 2절 경계 |
| `docs/reviews/Flora-v2.md` 3장 #6 | `use-manuscript-upload.ts:31-44` vs `upload.py:13-23` | 업로드 2단계 프로토콜 불일치(422), 3곳 복제 | 계약 1개: 서명 업로드 URL → Storage 직접 업로드 → `POST /api/uploads/[id]/complete` → 파싱 잡. 훅 1개(`features/upload/useManuscriptUpload`). 계약은 04장 2절, zod 스키마 공유 | PB-06-015 |
| `docs/reviews/Flora-v2.md` 3장 #7 | `use-write-all.ts:28`, `llm.py:223` | EventSource(GET)로 POST 엔드포인트 호출 → 405 | 전체 생성은 HTTP 스트림이 아니라 서버 잡이다. 진행률은 `core.jobs`·`generation_runs` Realtime 구독. 섹션 단건 스트리밍은 `fetch(POST)` + ReadableStream만 쓰고 EventSource를 쓰지 않는다 | PB-06-013, PB-06-014 |
| `docs/reviews/Flora-v2.md` 3장 #8 | `completion-screen.tsx:33-36`, `export.py:15-20` | 내보내기에 본문 미전송, fpdf2 Helvetica 한글 예외, 3,000자 절단 | 내보내기 API 입력은 `book_id`와 형식뿐. 엔진이 DB에서 원고를 읽어 HTML 조립. fpdf2 제거, WeasyPrint + Noto CJK만. 절단 없음. 한글 골든 PDF 테스트(두부 0) | PB-06-016, PB-06-017, PB-06-032 |
| `docs/reviews/Flora-v2.md` 3장 #9 | `new/ebook/page.tsx:99,108` | 타입 오류로 `next build` 실패, CI 없음 | CI 필수 게이트: `tsc --noEmit`, lint, build, pytest, SQL 체커, RLS 스모크. main 보호 규칙으로 실패 시 병합 불가 | PB-06-005 |
| `docs/reviews/flora.md` 3장 #7 | `.github/workflows/deploy.yml:46,52` | step `if`에서 secrets 사용 → 워크플로 무효 | 배포는 Vercel·Railway Git 연동으로 하고 GitHub Actions는 검증만. 시크릿 분기는 job 레벨 `env`로. `actionlint`를 CI에 포함 | PB-06-005, PB-06-034 |
| `docs/reviews/flora.md` 3장 #8 | `api/Dockerfile:1-12`, `export.py:134-139` | 컨테이너에 pango/cairo/CJK 폰트 없음, 폰트 경로 Windows 하드코딩 | 렌더 서비스 Dockerfile에 `libpango-1.0-0 libpangoft2-1.0-0 libcairo2 fonts-noto-cjk` 설치, 폰트는 fontconfig 이름으로만 참조. 기동 시 `fc-list :lang=ko` 결과가 비면 프로세스 종료(헬스체크 실패) | PB-06-004 |
| `docs/reviews/flora.md` 3장 #9 | `llm.py:117`, `cover.py:173`, `export.py:199` | async 핸들러 안 동기 호출로 이벤트 루프 블로킹 | LLM·이미지 호출은 Python에서 하지 않는다(TS 게이트웨이). 엔진의 파싱·조립은 잡 워커 프로세스에서 실행하고, FastAPI 핸들러 안 블로킹 작업은 `run_in_threadpool`만. 렌더는 별도 서비스, 엔진은 `httpx.AsyncClient` | PB-06-003, PB-06-016 |
| `docs/reviews/flora.md` 3장 #10 | `transform/route.ts:22-35`, `llm.py:245-262` | AI 고도화가 마지막 1,000자만 처리 | "전체 다듬기"는 2,000자 청크 자식 잡으로 처리하고 청크 수 = 결과 수를 검사. 선택영역 다듬기는 선택 텍스트 전체를 받으며 서버가 길이를 검증. 결과는 Diff로 섹션별 수락(원고 전체 교체 금지) | PB-06-013, PB-06-014 |
| `docs/reviews/SellingDocs.md` 3장 #1 | `PRD.md:13,24,28,65,130` | WeasyPrint를 Next/Vercel에서 실행하려는 런타임 모순 | WeasyPrint는 Railway 컨테이너 렌더 서비스로만. Vercel 코드에는 렌더 호출 자체가 없고 잡 enqueue만 한다(SM 10장 "Vercel/Route Handler에서 실행 금지") | PB-06-004, PB-06-017 |
| `docs/reviews/SellingDocs.md` 3장 #3 | `Claude.md`, `add.md` 0바이트 | 에이전트 규칙 문서 부재 | 이 폴더 `CLAUDE.md`가 규칙 정본(스택, 클라이언트 3종, 라우트 순서 인증 → 크레딧 → 처리, zod, 금지 패턴). 앱 저장소 루트 `CLAUDE.md`는 이 파일을 참조 | CLAUDE.md, PB-06-002 |
| `docs/reviews/SellingDocs.md` 3장 #4 | `PRD.md:53-54,128` | 책 전체를 단일 JSON으로 생성 → 잘림, 타임아웃 | 생성은 제목 → 기획안 → 목차(JSON, 구조만) → 섹션 단위 생성(잡). 응답 1회의 최대 단위는 소제목 1개(본문 상한 200KB) | PB-06-011, PB-06-014 |

## 7. 배포 토폴로지

| 구성요소 | 위치 | 공개 여부 | 호출 경로 |
|---|---|---|---|
| web | Vercel | 공개(HTTPS) | 브라우저 → web. web → Supabase(anon + 세션, service_role), → 엔진 미리보기(내부 토큰, Railway 공개 도메인 + IP 허용 목록 또는 Vercel Secure Compute, 제안) |
| TS 워커 | Railway 서비스 | 비공개 | Supabase(service_role) `claim_jobs`, LLM 게이트웨이, fal |
| 엔진 | Railway 서비스 | 비공개(private network). 미리보기 엔드포인트만 내부 토큰으로 노출 | Supabase(service_role), 렌더 서비스(private) |
| 렌더 서비스 | Railway 서비스 | private network 전용 | 엔진(publishing), astro 엔진(astro-ai) → `POST /render/pdf` + `X-Render-Token` |
| DB/Storage/Auth | Supabase 모듈러 프로젝트(1개) | Supabase 표준 | 전 계층 |
| 스케줄 | pg_cron(코어 스케줄) + TS 워커 크론(purge, 만료 처리) | - | CS 14장 |

```
브라우저 ──HTTPS──> web(Vercel) ──> Supabase(Auth/DB/Storage/Realtime)
                      │  enqueue_job               ^ claim/complete
                      └──(내부 토큰, 미리보기)──> engine(Railway) ──private──> render-weasyprint
                                                    ^                               ^
                                   TS worker(Railway) ── LLM 게이트웨이, fal      astro 엔진
```

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 브라우저 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버·워커·엔진 | 비공개 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`(모듈러) 또는 `public`(모놀리스) | 비공개 | 기동 실패 |
| `SUPABASE_JWT_SECRET` 또는 JWKS URL | 엔진 내부 검증(필요 시) | 비공개 | 빈 값이면 기동 실패(`docs/reviews/Flora-v2.md:70`) |
| `ENGINE_URL`, `ENGINE_INTERNAL_TOKEN` | web → 엔진 미리보기 | 비공개 | 기동 실패 |
| `RENDER_SERVICE_URL`, `RENDER_SERVICE_TOKEN` | 엔진 → 렌더 서비스 | 비공개 | 기동 실패 |
| `RENDER_ALLOWED_ASSET_HOSTS` | url_fetcher 허용 호스트(Supabase Storage 도메인) | 비공개 | 기동 실패 |
| `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY` | LLM 게이트웨이 | 비공개 | 기동 실패(둘 다 필요) |
| `FAL_KEY` | 표지 | 비공개 | 기동 실패 |
| `TOSS_CLIENT_KEY` | 결제창 | 공개(`NEXT_PUBLIC_TOSS_CLIENT_KEY`) | 기동 실패 |
| `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | confirm, 빌링, 웹훅 검증 | 비공개 | 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 웹훅 비밀 암호화 | 비공개 | 기동 실패(0키 폴백 금지) |
| `RATE_LIMIT_IP_SALT` | IP 해시 솔트 시드 | 비공개 | 기동 실패 |
| `APP_URL` | 콜백·결제 성공/실패 URL | 비공개 | 기동 실패 |
| `WORKER_ID`, `WORKER_CONCURRENCY` | 워커 식별·동시성(기본 4, 제안) | 비공개 | 기본값 사용 |

모든 앱은 기동 시 zod(TS)·pydantic Settings(Python) 검증을 통과해야 한다. `.env`·`.env.local`은 커밋하지 않는다(`SECURITY_BASELINE.md` 5장).
