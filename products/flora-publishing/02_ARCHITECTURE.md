# 02 아키텍처: FLORA Publishing

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 FastAPI AI 서비스(`api/`), LangChain/LangGraph, pgvector RAG, 책 설정집 위키, 공용 Dify, 음성 어댑터, 3D 히어로, Tailwind CSS v4 디자인 시스템을 더했다. LLM 라우터 본체는 ai-service로 옮겨졌으므로(`docs/products/_platform-core/SHARED_MODULES.md:215`) LLM·임베딩 키는 `api/`에만 둔다.

작성일 2026-10-12. 공용 모듈은 `docs/products/_platform-core/SHARED_MODULES.md`(아래 SM)와 `CORE_SPEC.md`(아래 CS)를 참조만 한다. 분석은 `docs/products/00_MERGE_ANALYSIS.md:줄`(아래 "분석:줄").

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router, React, TypeScript strict, Tailwind CSS v4(4.x 고정, CSS 우선 설정 `@import "tailwindcss"`, `@theme`, `@custom-variant dark`. `tailwind.config.js`와 v3 문법 금지), shadcn/ui(Tailwind v4 지원 버전, @base-ui), `src/proxy.ts` | Next 16.2.x(basic-master-module 기준 16.2.9 제안), React 19.2 | `Flora-v2/PRD.md:493-497`, 분석:1334 |
| 에디터 | Tiptap(ProseMirror) | 2.x 고정(제안) | `flora-publisher/frontend/docs/prd/03_features.md:107` |
| API(제품 로직) | Next Route Handlers(Node 런타임) | 위와 같음 | 01장 D1 권고(b) |
| TS 워커 | Node 20 + `packages/core-jobs` 워커 루프 | Node 20 LTS | SM 16장 |
| 출판 엔진 | FastAPI + Python 3.11 + pdfplumber, python-docx(mammoth 대체 가능), nh3(sanitize), ebooklib 또는 v1 ePub3 빌더 | FastAPI 0.115, Python 3.11.9 | 확정 결정 3, `docs/reviews/Flora-v2.md:14`, `:128` |
| PDF 렌더 서비스 | `services/render-weasyprint`(FastAPI 컨테이너, WeasyPrint + Noto CJK) | WeasyPrint 62 이상(제안) | SM 10장, 확정 결정 3 |
| DB/인증/Storage | Supabase(PostgreSQL 15, Auth, Storage, Realtime) | 15 | `_PRODUCT_AGENT_BRIEF.md:68` |
| 결제 | Toss Payments(일반결제, 빌링키) | API v1 | 확정 결정 4 |
| AI 서비스 | FastAPI(Python) `api/`(= 공용 ai-service의 `apps/api`): 모델 라우터, RAG, 위키, 그래프, 도구. 제품 확장은 `app/ai/products/publishing/`만 둔다 | Python 3.12(제안, 구현 시 확인) | 확정 결정 3, 13, `docs/products/_platform-core/AI_ARCHITECTURE.md:132-160` |
| AI 오케스트레이션 | LangChain(채팅 모델, text splitter), LangGraph + `langgraph-checkpoint-postgres`(스키마 `ai_runtime`) | 구현 시 확인 | `docs/products/_platform-core/AI_ARCHITECTURE.md:83`, `:114` |
| LLM | FastAPI 라우터: 상용 `anthropic`(Claude), `openai`(ChatGPT), `google`(Gemini), `openrouter` + 오픈소스 `oss-llm`(vLLM, OpenAI 호환). 기능별 체인은 5.1절. 공용 LLM 게이트웨이(TS)는 `/api/ai/*` 호출용 얇은 래퍼로만 남는다 | 모델 id는 `core.ai_model_prices` 행으로 | 확정 결정 17, SM 8장(2026-10-13 변경) |
| RAG | Supabase pgvector(HNSW, cosine, 1024차원). 책별 컬렉션 임베딩은 `oss-embed` 고정 | pgvector 0.8 이상 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107`, `docs/products/_platform-core/DB_CONVENTIONS.md:315-327` |
| 채팅 운영 | 공용 자체 호스팅 Dify 1개, 제품 앱 `publishing-chat`(Chatflow) | 설치 버전 문서로 확인 | 확정 결정 14, `docs/products/_platform-core/AI_ARCHITECTURE.md:58-71` |
| 음성 | `packages/core-voice`: ElevenLabs TypeScript 공식 SDK + 공용 오픈소스 음성 서버(faster-whisper + silero-vad + 상업 이용 가능 한국어 TTS) | 구현 시 확인 | 확정 결정 16, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-73` |
| 3D | three.js + React Three Fiber + drei. 캔버스는 동적 import(`ssr: false`). 공용 키트 `packages/ui-3d`(제안) | React 19 호환 버전(구현 시 확인) | 확정 결정 15, `docs/design-module/_design-guide/HERO_3D.md:47-48`, `:56-68` |
| 이미지 | 공용 fal 클라이언트 | - | SM 9장 |
| 배포 | Vercel(web), Railway(TS 워커, 엔진, AI 서비스, 렌더 서비스), 공용 Dify·GPU 서버(운영사 자체 호스팅) | - | `Flora-v2/PRD.md:505`, `docs/reviews/SellingDocs.md:77` |

확정 결정 6(TS 오케스트레이션 + Python 미디어)은 video용이지만 같은 원칙을 따른다: 생성 잡의 소유(큐, 재시도, 저장)는 TS 워커, 문서 처리 잡은 Python 엔진이고, LLM 호출 자체는 2026-10-13부터 ai-service(`api/`)의 그래프가 한다. 워커와 web에는 LLM 키가 없다.

## 2. 모듈 경계

```
apps/flora-publishing/
  web/                         Next.js (Vercel)
    src/proxy.ts               라우트 보호(session_context)
    src/app/(marketing)/       랜딩, 가격, 법무
    src/app/(auth)/            로그인, 가입, 재설정(단계별 구성: 9절. A 개발용 패널, B Google·이메일, C 카카오·네이버)
    src/app/auth/callback/     OAuth 콜백(finishLogin, next 화이트리스트). 단계 분기 코드는 src/lib/auth/·로그인 화면·콜백에만
    src/app/(app)/dashboard/   대시보드, 책 목록, 설정, 사용량·결제, agents/(에이전트 작업 공간·검수 대기·실행 이력, 10절)
    src/app/(app)/books/[id]/  위저드, 에디터, 완성/내보내기
    src/app/admin/             운영 콘솔(운영 홈, users, books, agents, jobs(실행 추적), billing, settings 열람, audit. 10.5절)
    src/app/(public)/b/[slug]/ 공개 책 페이지(Phase 2)
    src/app/api/               Route Handlers (04장 2절). AI·음성: api/ai/, api/voice/, api/internal/, api/onboarding/, 위키·참고 파일: api/books/[id]/wiki/, references/
    src/app/onboarding/        AI 처리 방식 선택(국외 이전 동의)
    src/app/dev/components/    컴포넌트 미리보기(라이트/다크 스크린샷용, 프로덕션 빌드에서 제외)
    src/styles/tokens.css      디자인 토큰 정답(Tailwind CSS v4 @theme, 라이트/다크)
    src/components/ui/         기본 컴포넌트(shadcn/ui를 토큰으로 재스타일)
    src/features/{ai-chat,wiki,voice,narration,hero3d}/   채팅 패널, 설정집 화면, 받아쓰기·채팅 음성, 낭독 플레이어, 3D 히어로(three.js는 hero3d/에서만 import)
    src/features/<feature>/    화면 단위 컴포넌트와 훅(wizard, editor, books, billing, settings, landing)
    src/server/agents/         에이전트 레지스트리(에이전트·동작 → 기존 처리 함수, 예상 크레딧, 승인 정책)와 agent_tasks 기록기 withAgentTask(10절)
    src/server/                서버 전용: ai/(서명 토큰, HMAC, 입력 마스킹), ai-pricing.ts, personas/, pricing/, features/, engine-client/, sanitize/ (프롬프트는 api/app/ai/products/publishing/prompts/로 이동)
    src/data/                  personas.json(60종), formats.json(6종), seeds/*.json(3종), themes.json(7종)
  worker/                      TS 워커 (Railway)
    src/handlers/              write-section(그래프 publishing.draft 호출), write-all, refine-all, cover, webhook-deliver, purge
  engine/                      FastAPI 출판 엔진 (Railway, private)
    app/parsers/               txt, md, docx, pdf
    app/html/                  HTML 조립, 템플릿(v1 html-templates 이식), sanitize
    app/presets/               판형 프리셋 -> @page CSS (v1 print-presets 이식)
    app/epub/                  ePub3 빌더(v1 이식)
    app/jobs/                  Python 워커: parse, render.pdf(렌더 서비스 호출), export_epub
  api/                         FastAPI AI 서비스 (Railway, 공개 HTTPS + 서명 토큰/내부 키)
    app/core/                  설정, Supabase service_role 클라이언트, 서명 토큰 검증, 오류 코드
    app/ai/{llm,rag,wiki,graphs,tools,compliance}/   공용 ai-service 부분(06장 PB-06-043 소유)
    app/ai/products/publishing/ 제품 확장: prompts/(언어 중립 md·json), rules/, knowledge.py, wiki_config.py
    app/ai/graphs/publishing_draft.py, publishing_assist.py
    app/ai/tools/publishing/   /tools/answer 확장(원고·설정집 컨텍스트 로더)
services/render-weasyprint/    공용 PDF 렌더 서비스 (flora-publishing 소유, astro 소비)
infra/dify/                    Dify 앱 정의(publishing-chat DSL, 키·비밀 없음)
supabase/                      모놀리스 마이그레이션 또는 모듈러 조각 링크, tests/
```

| 모듈 | 책임 | 하지 않는 것 |
|---|---|---|
| web | 인증·세션, 크레딧 선차감, 동기 LLM 호출(스트리밍 포함), Toss, 잡 enqueue, 서명 URL 발급, 화면 | PDF 렌더, 파일 파싱, 장시간 루프 |
| worker(TS) | `publishing.llm`, `publishing.media`, `publishing.events` 큐: 챕터 초안(잡 토큰으로 그래프 `publishing.draft` 실행 요청, 결과 저장), 전체 생성 오케스트레이션, 표지(fal), 웹훅 발송, 휴지통 purge | HTML/PDF 생성 |
| engine(Python) | `publishing.doc`, `publishing.render` 큐: 업로드 파싱, HTML 조립(미리보기 포함), ePub, 렌더 서비스 호출, Storage 저장 | LLM 호출, 크레딧 차감(선차감은 enqueue 측이 이미 함) |
| render-weasyprint | HTML + 프리셋 → PDF. url_fetcher 허용 목록, 폰트 검증 | DB 접근(경로·job_id만 받는다), 인증된 사용자 요청 직접 수신 |
| api(AI 서비스) | 모델 라우터(체인, 국외 동의 필터, 오픈소스 강제), RAG 색인·검색, 책 설정집 위키, LangGraph 그래프(`publishing.draft`, `publishing.assist`), `/tools/answer`, compliance, `ai_runs`·`ai_usage` 기록 | 사용자 세션 처리(서명 토큰 또는 내부 키 + 대화 매핑만 신뢰), 크레딧 선차감(enqueue·Route Handler 측이 이미 함. 정산은 `ai-settle`), 렌더, 파일 파싱 |

AI 모듈 경계(`docs/products/_platform-core/AI_ARCHITECTURE.md:5-14`를 인용, 재정의하지 않음):

| 경계 | 규칙 |
|---|---|
| 브라우저 ↔ 서버 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지(`docs/products/_platform-core/SECURITY_BASELINE.md:299`) |
| Next.js ↔ FastAPI·음성 서버 | EdDSA 서명 토큰(`iss=publishing`, `aud=platform-ai:publishing`, scope는 04장 2.1절). 개인키는 Next.js만 |
| Next.js ↔ Dify | 대화 매핑: `user=dify_user`, 입력 `platform_conversation_id`, 선택 입력 `book_id`. 토큰을 넘기지 않는다 |
| Dify ↔ FastAPI | 내부 키(`DIFY_INTERNAL_API_KEY`, publishing 전용) + 대화 매핑. 외부 지식 API는 쓰지 않는다(조직 데이터만 있고 제품 공통 지식 컬렉션이 없다) |
| 워커 ↔ FastAPI | 잡 토큰(Next.js `/api/internal/ai-token`이 잡 행의 org·사용자로 발급). 워커는 LLM 키가 없다 |
| engine ↔ api | 직접 호출하지 않는다. 참고 파일 파싱 결과(정규화 md)는 Storage를 거쳐 `/rag/ingest`로 넘어간다 |
| 3D 히어로 | `web/src/features/hero3d/`만 three.js를 import한다. 다른 화면은 3D 의존성이 없다 |

데이터 정본은 DB다. 클라이언트는 원고 HTML을 서버로 보내 렌더시키지 않는다. 렌더·메타데이터·ePub은 `book_id`만 받아 서버가 DB에서 읽는다(`docs/reviews/Flora-v2.md:115`).

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 가입(`signup_app='publishing'`), 세션, `requireSession`. 제품 앱의 인증 모듈 경계는 `web/src/lib/auth/`(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`). 단계 분기(`AUTH_MODE`, 제공자 목록)는 여기·로그인 화면·`/auth/callback`·`/api/dev/login`에만 둔다(9절) | web `proxy.ts`, 모든 Route Handler, 로그인 화면, 콜백 | SM 2장, `docs/products/_platform-core/AUTH_ROADMAP.md` 3.1절 |
| org | 개인 조직(1인 1워크스페이스). 멤버 초대 UI 없음 | 세션 컨텍스트 | SM 3장 |
| credits | 선차감-환불, `withCredits`, `priceOf`(단가표는 `web/src/server/pricing`) | Route Handler, TS 워커 | CS 4.3 |
| toss | 팩·구독 주문, confirm, 빌링키, 정기결제 워커 | `web/src/app/api/billing/*`, 공용 정기결제 워커 | SM 5장 |
| webhooks | Toss·fal 수신 검증과 멱등, 아웃바운드 HMAC 서명 | `/api/webhooks/toss`, `/api/webhooks/fal`, worker `webhook-deliver` | SM 6장 |
| llm gateway(`packages/core-ai/llm`) | 사용하지 않는다(2026-10-13). 단건 생성의 호출부는 얇은 래퍼로 `publishing.assist` 그래프를 부른다 | `web/src/server/ai/` | 라우터 본체가 ai-service로 옮겨졌다(SM 8장 2026-10-13 변경). LLM 호출의 purpose는 프롬프트 키로 남고 라우팅 기능은 5.1절 |
| ai-gateway | 대화 매핑, 서명 토큰 발급, 턴 선차감·정산, Dify 중계와 장애 시 직접 경로, 잡 토큰 발급 | `src/app/api/ai/`, `src/app/api/internal/`, `src/server/ai/` | `docs/products/_platform-core/SHARED_MODULES.md:498` |
| ai-service | 라우터, RAG(책별 자료), 위키(책 설정집), 그래프, 도구 `/tools/answer` | `api/` | 제품 확장은 2절 `api/` 행 |
| dify | 채팅 앱 `publishing-chat`(질문 분류, HTTP 노드) | `src/app/api/ai/chat` | Dify DB는 조직 데이터 저장소로 관리(로그 30일) |
| core-voice | 받아쓰기·채팅 음성 STT/TTS, 낭독(대체 금지 모드) | `src/app/api/voice/` | 낭독은 `feature='narration'`에서 대체를 끈다 |
| llm-wiki | 책 설정집(제품 지식 위키, 조직 데이터) | `api/`(ingest, lint, query), `src/app/api/books/[id]/wiki/` | 운영자 위키·공개 위키는 없다 |
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
| `publishing.write_section` | `publishing.llm` | TS 워커 → FastAPI 그래프 `publishing.draft`(잡 토큰). 한 챕터 안 소제목 1개 이상(`section_ids`)을 처리. 이름은 이전 계약 호환용 | 소제목당 2(fast)/4(quality), enqueue 직전(4.6절. 2026-10-13 변경 전 1/2) | 3회, 지수 백오프(코어 기본 60초 x 2^n, 첫 재시도는 `run_after` 10초로 단축 제안) | 3회 소진 또는 재시도 불가 실패 → `fail_job` 자동 환불. 취소된 대기 잡 → `cancel_job` 환불 |
| `publishing.write_all` | `publishing.llm` | TS | 없음(자식이 각각 차감). 시작 전 예상 합계를 잔액과 비교해 부족하면 402 | 0(부모는 재시도하지 않음, 회수 시 실행 `failed`) | 해당 없음 |
| `publishing.refine_all` | `publishing.llm` | TS | 없음(청크 자식 잡이 각각 1) | 0 | 위와 같음 |
| `publishing.refine_chunk` | `publishing.llm` | TS | 청크당 1 | 2회 | 실패 자동 환불 |
| `publishing.cover_generate` | `publishing.media` | TS | 6(3후보) | 1회(제출 실패만) | 후보별 실패분 `refund_credits(p_amount=2)` 부분 환불. 안전 필터 거부는 재시도 없이 환불 |
| `publishing.parse_manuscript` | `publishing.doc` | Python | 0 | 2회 | 해당 없음 |
| `publishing.parse_reference` | `publishing.doc` | Python | 0 | 2회 | 해당 없음. 끝나면 `publishing.ai_index` enqueue |
| `render.pdf` | `publishing.render` | Python(엔진 → 렌더 서비스) | 2 | 1회(네트워크·타임아웃만). HTML/CSS 오류는 재시도 불가 | 최종 실패 자동 환불 |
| `publishing.export_epub` | `publishing.doc` | Python | 1 | 1회 | 최종 실패 자동 환불 |
| `publishing.webhook_deliver` | `publishing.events` | TS | 0 | 5회(1분, 5분, 30분, 2시간, 6시간, 제안) | 해당 없음 |
| `publishing.purge` | `publishing.maintenance` | TS(일 1회) | 0 | 3회 | 해당 없음. 책 영구 삭제 시 `book-<id>` 컬렉션과 설정집 페이지(`purge_wiki_page`)도 지운다 |
| `publishing.ai_index` | `publishing.ai` | Python(FastAPI 워커) | 파일당 1(+10만 토큰마다 1) | `max_attempts=3` | 실패 시 문서 `failed` + 선차감 환불 |
| `publishing.wiki_ingest` | `publishing.ai` | Python(FastAPI 워커). 이용자가 "설정집 만들기"를 누를 때 | 3(정산 1~10) | `max_attempts=3` | 실패 시 환불. 새 페이지는 `draft` |
| `publishing.wiki_lint` | `publishing.ai` | Python(FastAPI 워커). 이용자가 "설정집 점검"을 누를 때 | 2 | `max_attempts=2` | 실패 시 환불 |
| AI 정산 크론(잡 아님) | - | TS(Next.js `/api/internal/ai-settle`, 워커가 5분마다 워커 키로 호출, 제안) | - | - | `ai_usage.settled_at is null`이고 10분 넘은 행을 실제 사용량으로 정산 또는 환불 |

전체 순차 생성 흐름(분석:98, `flora-publisher/frontend/docs/prd/03_features.md:86-97`). 2026-10-13: 3단계의 자식 잡은 소제목 1개가 아니라 챕터 1개(소제목 여러 개)이고, 생성 엔진은 그래프 `publishing.draft`다(아래 시퀀스).

| 단계 | 동작 |
|---|---|
| 1 | Route Handler: 엔타이틀먼트·`write_all` 기능 확인 → 대상 섹션(본문 없는 것, 또는 덮어쓰기 선택분) 수 x 단가 = 예상치. 잔액 < 예상치면 402 + 부족량 |
| 2 | `generation_runs` INSERT(service_role) + 부모 잡 enqueue(멱등 키 `job:publishing:<request_id>`). 책당 진행 실행 1개는 부분 유니크 인덱스가 강제(23505 → 409) |
| 3 | 부모 핸들러: 창 크기 3으로 자식 `write_section` enqueue. 자식마다 `consume_credits(idempotency 'consume:publishing:<run_id>:<section_id>')` 후 enqueue. `CR001`이면 남은 섹션을 `skipped`로 세고 중단 |
| 4 | 자식 완료 → 섹션 `generated` 저장(sanitize), `done_sections+1`. 3회 실패 → 섹션 `failed`, 환불(코어) |
| 5 | 부모는 30초마다 하트비트와 `cancel_requested_at` 확인. 취소면 대기 자식 `cancel_job`(환불), 실행 중 자식은 끝나게 둔다 → 실행 `canceled` |
| 6 | 종료: 실패 0이면 `succeeded`, 일부 실패면 `partial`. 앞 챕터 요약(옴니버스 모드면 생략)은 챕터 첫 섹션 생성 직전에 원고에서 계산 |

챕터 초안 그래프 실행 시퀀스(`publishing.write_section` 1건):

| 단계 | 주체 | 동작 | 실패 처리 |
|---|---|---|---|
| 1 | Route Handler(`write-all`) 또는 부모 잡 | 대상 소제목 확인, 소제목마다 `consume_credits('consume:publishing:<run_id>:<section_id>')`, 챕터 단위 자식 잡 enqueue(`job:publishing:<run_id>:<chapter_id>`) | `CR001`이면 남은 챕터를 `skipped`로 세고 중단 |
| 2 | 워커 | `claim_jobs('publishing.llm')` → 소제목 `generating` → `POST /api/internal/ai-token`(워커 키 + `job_id`)으로 잡 토큰 받기(Next.js가 `core.jobs` 행의 `status='running'`, `app_id='publishing'`, `job_type`을 확인하고 그 행의 `org_id`·`created_by`로 `scope=graph:publishing.draft` 토큰 발급) | 토큰 발급 실패면 `fail_job` |
| 3 | 워커 → FastAPI | `POST /graphs/publishing.draft/runs { book_id, section_ids, mode, omnibus, run_id }` → `GET /graphs/runs/{id}` 2초 간격(최대 300초) | 시간 초과·`failed`면 해당 소제목들 `failed` + `fail_job` 환불 |
| 3-1 | FastAPI | 토큰 서명·`aud`·scope·`jti` 1회 확인 → `books.org_id = token.org`이고 `job_id`의 잡이 그 책의 잡인지 확인 → `core.ai_runs`(graph `publishing.draft`, `job_id`, `credit_ledger_id`, `thread_id`) → 노드 실행, 노드마다 `ai_run_steps`·`ai_usage`. 크레딧은 이미 차감했으므로 추가 차감 없음 | 노드 실패는 `ai_runs.status='failed'` |
| 4 | 워커 | 출력 zod 재검증 → sanitize → 본문이 비어 있던 소제목은 `sections.body_html` 저장(`generated`), 본문이 있던 소제목은 잡 `result`에 제안으로만 저장 → `done_sections` 갱신 → `complete_job` | 저장 실패는 `fail_job` |

## 5. AI 라우팅

설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md:73-92`(LLM 라우터), `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`(음성)이다. 5.1~5.2절은 publishing 기능별 기본값과 그래프만 정하고, 5.3절은 이전의 purpose별 모델 표(단건 생성의 프롬프트 키)를 옮겨 둔 것이다.

### 5.1 기능별 라우팅 기본값

아래 표는 `docs/products/_supabase-modular/migrations/1000_publishing.sql` 15절과 `supabase/monolith/seed.sql`의 `ai_routing_settings`(org null, app `publishing`) 12행과 같다. 플랫폼 기본(`docs/products/_supabase-modular/seed.sql:249-254`)과 다른 점만 의미가 있고, 같은 값도 제품 의도를 남기려고 행으로 둔다.

| feature | kind | 모드 | 대체 체인 | 강제 오픈소스 | 쓰는 곳 | 이유 |
|---|---|---|---|---|---|---|
| `publishing.draft` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `publishing.draft`의 `outline`·`draft`·`consistency`·`proofread` 노드 | 초안 품질이 핵심이라 Claude 우선. 오픈소스 전용 책은 상용을 걸러 낸다(01장 6.1절) |
| `publishing.assist` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | 그래프 `publishing.assist`(제목, 기획안, 목차, 섹션 단건, 보조 집필, 청크 다듬기, 책 정보, 페르소나 합성) | 이전 `pub.*` purpose를 하나로 묶었다(장마다 다른 체인을 둘 이유가 없다) |
| `chat` | llm | auto | anthropic → openai → google → oss-llm | 아니오 | `/tools/answer`(글쓰기 도우미) | 원고 근거 대화의 한국어 품질 |
| `wiki.query` | llm | auto | oss-llm → anthropic | 아니오 | 설정집 근거 조회 | 설정집 페이지를 요약하는 일이라 오픈소스로 충분 |
| `wiki.ingest` | llm | auto | oss-llm → anthropic | 아니오 | 원고·참고 파일 → 설정집 제안 | 반복·대량 처리. 개인정보 유래 페이지는 오픈소스 강제(`LLM_WIKI.md:33`) |
| `wiki.lint` | llm | auto | oss-llm → anthropic | 아니오 | 설정집 점검 | 같음 |
| `dify.aux` | llm | open_source | oss-llm | 예 | Dify 질문 분류 노드(FastAPI `/v1/chat/completions`) | 조직을 알 수 없어 국외 이전 동의를 확인할 수 없다 |
| `publishing.knowledge` | embedding | open_source | oss-embed | 아니오(대체 없음) | 책별 컬렉션 색인과 검색 질의 | 동의하지 않은 사용자의 질의도 같은 모델로 임베딩해야 하고 원고에 개인정보가 있을 수 있어 국내 오픈소스로 고정. 모델을 바꾸면 컬렉션 재색인 |
| `publishing.dictation` | stt | auto | oss-voice → elevenlabs | 아니오 | 받아쓰기 | 대량·저비용(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:45`) |
| `voice_chat` | stt | auto | oss-voice → elevenlabs | 아니오 | 채팅 음성 질문 | 같음 |
| `voice_chat` | tts | auto | elevenlabs → oss-voice | 아니오 | 답변 읽어 주기 | 품질 우선 |
| `narration` | tts | auto | elevenlabs → oss-voice | 아니오 | 원고 낭독, 오디오북 미리듣기 | 품질 우선(국외 이전 미동의 조직은 oss-voice). 작업 도중 대체 금지(아래 규칙, auto 통일 2026-10-13 사용자 결정) |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 국외 이전 동의 | 동의하지 않은 조직은 `resolve_ai_route`가 상용 제공자를 체인에서 뺀다. 예상 결과(PGlite로 확인하는 항목은 PB-06-055): 미동의 조직의 `publishing.draft` 체인 = `oss-llm`, 동의 후 = anthropic → openai → google → oss-llm, `dify.aux`는 동의 후에도 `oss-llm`, `narration` 미동의 = `oss-voice` | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:419-476` |
| 낭독 대체 금지 | 음성 어댑터가 `feature='narration'`이면 대체를 끈다: 작업 시작 때 체인에서 쓸 수 있는 첫 제공자를 고르고 모든 구간을 그 제공자로 만든다. 한 구간이라도 실패하면 작업 실패 + 전액 환불. 체인의 `oss-voice`는 시작 전 선택용이다 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47` |
| 임베딩 고정 | 검색 질의 임베딩은 라우팅이 아니라 컬렉션에 기록된 `embedding_provider`·`embedding_model`을 쓴다 | `docs/products/_platform-core/DB_CONVENTIONS.md:315-327` |
| 오픈소스 전용 책 | 책의 `ai_open_source_only`가 켜져 있으면 ai-service 라우터가 그 책의 모든 호출에서 체인의 상용 제공자를 제외하고, 음성도 오픈소스 제공자로 시작한다. 상용으로 대체하지 않는다. 조직 단위 `force_open_source` 행과 별개의 호출 단위 강제이며 구현 방식은 코어 요청 R8 | 01장 PB-F-056, `docs/products/_platform-core/SECURITY_BASELINE.md:291` |
| OpenRouter | 플랫폼 제공자로 등록돼 있지만 publishing 기본 체인에는 넣지 않는다(같은 모델의 중복 경로이고 국외 이전 제공자만 늘어난다). 이전의 "Anthropic + OpenRouter 폴백"은 새 대체 체인으로 흡수됐다 | `docs/products/_supabase-modular/seed.sql:214-227` |
| 조직 재정의 | 제품 화면에서 `set_ai_routing`을 쓰지 않는다. 이용자가 고르는 것은 국외 이전 동의(온보딩·설정)와 책별 오픈소스 전용 스위치뿐이다 | 01장 PB-F-044 |
| seed 검사 | `1000_publishing.sql` 15.3절의 DO 블록이 체인 제공자의 존재·종류·오픈소스 모드를 검사하고 어긋나면 마이그레이션을 실패시킨다(제공자 행이 아직 없으면 건너뜀) | `1000_publishing.sql` 15절 |

### 5.2 LangGraph 그래프

| 그래프 | 노드 순서 | LLM 기능 | 사람 승인 | compliance | 실행 |
|---|---|---|---|---|---|
| `publishing.draft` | `outline` → `draft` → `consistency`(충돌 소제목만 `draft` 1회 재작성) → `proofread` → `compliance`(걸린 소제목만 `draft` 1회 재작성 → `compliance`) | `publishing.draft` | 없음. 본문이 있는 소제목은 덮어쓰지 않고 제안(Diff)으로만 돌려주므로 되돌리기 어려운 단계가 없고 실패는 환불로 복구된다 | 있음(필수 마지막 노드) | 워커 요청, FastAPI 비동기 실행, 체크포인트 thread = `ai_runs.thread_id` |
| `publishing.assist` | `compose` → `generate` → `compliance` | `publishing.assist` | 없음(결과는 저장 전 제안이거나 이용자가 선택) | 있음 | Route Handler 동기 요청(p95 30초). 스트리밍은 D13 |

| 노드 | 입력 | 동작 | 출력 | LLM |
|---|---|---|---|---|
| `outline` | `book_id`, `section_ids` | DB에서 책 제목·기획안·목차·페르소나 Taste·어조를 읽고(서버가 합성), 채택된 설정집 페이지와 앞 챕터 요약(옴니버스 모드면 생략)을 붙여 소제목별 개요(핵심 사건·정보·분량)를 만든다 | 소제목 개요 목록 | 있음 |
| `draft` | 개요, 근거 | 소제목별 초안(동시 3). 근거는 `match_ai_chunks(org, 'publishing', 임베딩, k=8, 책 컬렉션)`과 설정집 페이지. JSON 출력 `{section_id, body_html, notes[]}` | 초안 목록 | 있음 |
| `consistency` | 초안, 채택된 설정집 | 캐릭터 이름·관계·특징, 용어, 시제·시점이 설정집·앞 챕터와 충돌하는지 검사. 충돌 소제목은 `notes`에 근거를 붙여 1회 재작성하고 다시 검사 | 통과 / 메모 첨부 목록 | 있음 |
| `proofread` | 초안 | 맞춤법·문장 부호·반복 표현 교정. 의미·사실·고유명사 변경 금지(변경 비율 상한 검사, 제안 15%) | 교정본 | 있음 |
| `compliance` | 교정본 | `rules/banned.json`(01장 6.1절, PB-F-054): 실존 작가 사칭, 보장 표현, 의료·금융·법률 단정, 참고 파일 장문 일치, 출력 스키마 | 통과 / 걸린 소제목 | 없음(규칙) |

채팅은 그래프가 아니라 도구 경로다: `/tools/answer`(모드 `book`: 책 컨텍스트 로더 + 원고·설정집·참고 파일 검색 + `chat` 모델, 모드 `craft`: 일반 글쓰기 상담, 책 근거 없이 `chat` 모델). 후처리에 같은 compliance 규칙을 적용한다. 설정집 `ingest`·`lint`·`query`는 위키 모듈(`LLM_WIKI.md`)이며 그래프가 아니다.

### 5.3 단건 생성 purpose와 프롬프트 규칙

모델 이름은 ai-service 설정과 `core.ai_model_prices` 행으로 바꾼다. 아래는 이전 purpose(프롬프트 키)별 모델 등급 제안이며, 라우팅 기능은 `publishing.assist` 하나다(5.1절). 크레딧 열은 01장 4.3절이다.

| purpose | 모델(fast / quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `pub.title` | 경량 / 표준 | 1 | 체인의 다음 제공자 |
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
| OpenRouter | 기본 체인에 넣지 않는다(5.1절) | v1 `_call_via_openrouter` 설계를 라우터 체인이 대체 |
| ElevenLabs, 오픈소스 음성 서버 | 받아쓰기, 채팅 음성, 낭독 | 5.1절. 01장 D2는 닫힘 |

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
| `docs/reviews/flora.md` 3장 #9 | `llm.py:117`, `cover.py:173`, `export.py:199` | async 핸들러 안 동기 호출로 이벤트 루프 블로킹 | 엔진(`engine/`)에는 LLM 호출이 없다. LLM은 ai-service(`api/`)에서 async 클라이언트와 LangChain 비동기 API로만 호출하고, 이미지는 TS 워커가 fal로 호출한다. 엔진의 파싱·조립은 잡 워커 프로세스에서 실행하고, FastAPI 핸들러 안 블로킹 작업은 `run_in_threadpool`만. 렌더는 별도 서비스, 엔진은 `httpx.AsyncClient` | PB-06-003, PB-06-016 |
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
| AI 서비스(`api/`) | Railway | 공개 HTTPS. 서명 토큰 또는 내부 키가 없으면 401(Dify HTTP 노드와 Vercel이 호출하므로 private network만으로는 부족) | Supabase(service_role), 상용 LLM API, 공용 GPU 서버(`oss-llm`, `oss-embed`) |
| Dify(공용) | 운영사 자체 호스팅(`D:\WorkSpace\DEV\platform-dify\`, 제안) | 콘솔은 운영자만(2단계 인증) | web → Dify Chat API(앱 키), Dify → FastAPI `/tools/*`, `/v1/chat/completions`(내부 키) |
| 공용 GPU 서버 | 운영사 자체 호스팅(`oss-llm` vLLM, `oss-embed`, `oss-voice`) | 비공개(서명 토큰·내부 키) | FastAPI(LLM·임베딩), web 서버(음성) |
| ElevenLabs | 외부 SaaS(국외) | - | web 서버만(TS SDK) |
| 스케줄 | pg_cron(코어 스케줄) + TS 워커 크론(purge, 만료 처리, AI 정산 5분) | - | CS 14장 |

```
브라우저 ──HTTPS──> web(Vercel) ──> Supabase(Auth/DB/Storage/Realtime)
                      │  enqueue_job               ^ claim/complete
                      └──(내부 토큰, 미리보기)──> engine(Railway) ──private──> render-weasyprint
                                                    ^                               ^
                                   TS worker(Railway) ── fal               astro 엔진
                                      │ 잡 토큰
                                      └──> api(Railway, AI 서비스) ── 상용 LLM / GPU 서버(oss)
                                              ^ 서명 토큰(web) / 내부 키(Dify)
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
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OPENROUTER_API_KEY` | 상용 LLM | `api/` 전용(web·worker에 넣지 않음) | 해당 제공자만 비활성(체인에서 다음으로). 전부 없으면 오픈소스만 |
| `OSS_LLM_BASE_URL`, `OSS_EMBED_BASE_URL` | 오픈소스 LLM·임베딩 서버 | `api/` 전용 | `api/` 기동 실패(`publishing.knowledge` 임베딩과 미동의 조직 처리에 필수) |
| `VOYAGE_API_KEY` | 상용 임베딩 | `api/` 전용 | publishing은 `oss-embed`를 쓰므로 없어도 동작(플랫폼 기본값 호환용) |
| `AI_TOKEN_PRIVATE_KEY`, `AI_TOKEN_KID` | EdDSA(Ed25519) 서명 토큰 발급 | web 서버 전용 | 기동 실패 |
| `AI_TOKEN_JWKS_URL` | 서명 토큰 공개키 | `api/`, 오픈소스 음성 서버 | 기동 실패 |
| `AI_SERVICE_URL` | FastAPI 주소 | web 서버, worker | AI 기능 비활성 + 오류 표시, worker 기동 실패 |
| `DIFY_API_URL`, `DIFY_APP_KEY_PUBLISHING` | Dify Chat API, `publishing-chat` 앱 키 | web 서버 전용 | 채팅은 FastAPI 직접 경로(`/tools/answer-direct`)로만 동작 + 운영 알림 |
| `DIFY_INTERNAL_API_KEY` | Dify HTTP 노드 → FastAPI 인증(publishing 전용 값) | `api/`와 Dify 환경변수(비밀) | `api/` 기동 실패 |
| `DIFY_USER_HMAC_SECRET` | `dify_user = HMAC(org:sub)` | web 서버 전용 | 기동 실패 |
| `PUBLISHING_WORKER_INTERNAL_KEY` | 워커 → `/api/internal/ai-token`, `/api/internal/ai-settle` 인증 | web 서버, worker | 기동 실패 |
| `AI_CROSS_BORDER_NOTICE_VERSION`, `VOICE_NOTICE_VERSION` | 국외 이전·음성 처리 고지문 버전 | web 서버 | 기동 실패 |
| `ELEVENLABS_API_KEY` | 상용 STT·TTS | web 서버 전용 | ElevenLabs 비활성(체인에서 오픈소스로) |
| `OSS_VOICE_BASE_URL` | 오픈소스 음성 서버 | web 서버 전용 | 기동 실패 |
| `PUBLISHING_NARRATION_VOICE_ELEVENLABS`, `PUBLISHING_NARRATION_VOICE_OSS` | 낭독·읽어 주기 보이스 id(01장 D15) | web 서버 전용 | 기동 실패 |
| `NEXT_PUBLIC_HERO3D_ENABLED` | 3D 히어로 전체 끄기 스위치(장애 대응) | 공개 | 기본 true. false면 정지 이미지 |
| `FAL_KEY` | 표지 | worker 전용 | 기동 실패 |
| `TOSS_CLIENT_KEY` | 결제창 | 공개(`NEXT_PUBLIC_TOSS_CLIENT_KEY`) | 기동 실패 |
| `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | confirm, 빌링, 웹훅 검증 | 비공개 | 기동 실패 |
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | 웹훅 비밀 암호화 | 비공개 | 기동 실패(0키 폴백 금지) |
| `RATE_LIMIT_IP_SALT` | IP 해시 솔트 시드 | 비공개 | 기동 실패 |
| `APP_URL` | 콜백·결제 성공/실패 URL | 비공개 | 기동 실패 |
| `WORKER_ID`, `WORKER_CONCURRENCY` | 워커 식별·동시성(기본 4, 제안) | 비공개 | 기본값 사용 |

AI 관련 변수는 `docs/products/_platform-core/AI_ARCHITECTURE.md:160`의 목록을 따르며 `NEXT_PUBLIC_HERO3D_ENABLED` 말고는 모두 서버 전용이다. `AI_TOKEN_SECRET`(공유 비밀키)은 쓰지 않는다(EdDSA, `docs/products/_platform-core/SECURITY_BASELINE.md:284`).

모든 앱은 기동 시 zod(TS)·pydantic Settings(Python) 검증을 통과해야 한다. `.env`·`.env.local`은 커밋하지 않는다(`SECURITY_BASELINE.md` 5장).

## 9. 인증 단계 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`이고 이 절은 publishing(가입 정책 open, 로그인하는 사람은 작가)에 맞춰 옮긴 것이다. 세션·권한 판정(`session_context`, `requireSession('publishing')`, `proxy.ts`)과 RLS는 단계와 무관하게 같은 코드다(AUTH_ROADMAP 0장 불변 조건).

### 9.1 단계표 (이 제품 기준)

| 단계 | 언제 | 켜지는 로그인 | 이 제품 작업 | 다음 단계 게이트 |
|---|---|---|---|---|
| A | W0부터 MVP P0 기능이 Mock으로 모두 동작할 때까지 | 로컬 시드 페르소나(05장 10절) 원클릭 로그인. 제공자 버튼 없음 | PB-06-006(Stage A로 범위 변경) | G1(AUTH_ROADMAP 4장): 06장 2절 MVP P0 작업 완료, PB-06-037 핵심 플로우 E2E·PB-06-029 RLS 스모크·PB-06-030 결제 E2E가 Mock으로 녹색, 단계 분기 코드가 인증 모듈 밖에 0건, Google 콘솔 준비 |
| B | G1 통과 후, 공개 베타 전 | Google + 이메일(가입·메일 인증·비밀번호 재설정, 01장 D22) | PB-06-056(P0) | G2(AUTH_ROADMAP 6장): Google 실사용 공개 베타 2주(제안), 인증 P0·P1 장애 0, 콜백 오류율 1% 미만(제안), `entitled=false`로 남은 신규 가입자 0 |
| C1 | G2 통과 후 | 카카오(Supabase 기본 제공자 `kakao`) | PB-06-057(P1) | 7.1.3절 수용 기준 |
| C2 | G2 통과 후(C1과 병렬 가능, 네이버 검수 신청은 G2 직후) | 네이버(`custom:naver` 또는 서버 브리지, 스파이크로 결정) | PB-06-058(P1) | 7.2.4절 수용 기준 |

단계 전환은 사람(대표님)이 게이트를 판정하고 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 남긴 뒤에만 한다.

### 9.2 코드 위치와 단계 분기 규칙

| 위치 | 하는 일 | 단계 분기 허용 |
|---|---|---|
| `web/src/lib/auth/` | `getAuthConfig()`(env zod 검증, 잘못된 조합이면 기동 실패), `isMockAuthAllowed()`, `listLoginOptions('publishing')`, `finishLogin('publishing', next)` | 예 |
| `web/src/app/(auth)/login/` | `listLoginOptions` 결과로 개발용 패널(A)·Google 버튼과 이메일 폼(B)·카카오·네이버 버튼(C)을 렌더. 판정은 서버 컴포넌트에서 | 예 |
| `web/src/app/auth/callback/` | 코드 교환 → `finishLogin` | 예 |
| `web/src/app/api/dev/login/` | Stage A Mock 로그인(로컬 전용, 판정 거짓이면 404) | 예 |
| `web/src/app/auth/naver/` | C2 브리지 경로를 택한 경우만 | 예 |
| 그 밖의 모든 코드(`web/src/server/`, 기능 Route Handler, 화면, worker, engine, api) | `session_context`·`requireSession`만 쓴다. `AUTH_MODE`·페르소나 이메일로 분기하지 않는다 | 아니오(CI grep, 06장 PB-06-005) |

`finishLogin`은 AUTH_ROADMAP 3.2절 순서를 그대로 따른다: `session_context('publishing')` 조회 → `entitled=false`면(publishing은 open) `rpc('bootstrap_app_for_org', { p_app_id: 'publishing' })` 1회 후 재조회 → `status` 분기(`/pending`, 403) → `next` 화이트리스트(01장 PB-F-002, 기본 경로 `/dashboard`) → 감사 `auth.login`. 모놀리스(단독 `public` 스키마)는 앱 행이 1개라 가입 트리거가 자동 부트스트랩하므로 두 번째 단계가 아무 일도 하지 않는다(AUTH_ROADMAP 3.2절 끝).

### 9.3 환경변수 (AUTH_ROADMAP 3.3절 중 이 제품에 해당하는 것)

| 변수 | 단계 | 배치 | 없으면 |
|---|---|---|---|
| `AUTH_MODE` | A·B·C | web 서버 전용. worker·engine·api에는 두지 않는다 | `live`. 로컬 `.env.example` 기본값 `mock`. `mock`인데 `isMockAuthAllowed()`가 거짓이면 기동 실패 |
| `AUTH_PROVIDERS` | B·C | web 서버 전용. 운영 B: `google,email`, C1 후 `google,email,kakao`, C2 검수 통과 후 `naver` 추가 | live에서 로그인 수단 0개면 기동 실패 |
| `DEV_SEED_PASSWORD` | A(로컬 전용) | web 서버(로컬 `.env.local`)와 `scripts/dev/seed-users.mjs`. `NEXT_PUBLIC_*` 금지 | Mock 모드 기동 실패 |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | B | 로컬은 `supabase/config.toml`의 `env()`, 원격은 Supabase 대시보드에만. 앱 env(web·worker·engine·api)에 넣지 않는다 | 로컬 Google 버튼 비활성 |
| `KAKAO_CLIENT_ID`(REST API 키), `KAKAO_CLIENT_SECRET` | C1 | 같은 방식 | 카카오 버튼 비활성 |
| `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` | C2 | `supabase_custom`: 등록 스크립트(`scripts/auth/register-naver-provider.mjs`, 제안)만. `bridge`: web 서버 전용 | 네이버 버튼 비활성 |
| `NAVER_AUTH_PATH` | C2 | web 서버 전용 | `supabase_custom` |
| `AUTH_BRIDGE_SECRET` | C2 브리지 경로만 | web 서버 전용, 32바이트 이상 | 브리지 경로면 기동 실패 |

콜백 origin은 8절 `APP_URL`로 고정한다(AUTH_ROADMAP 3.2절의 `NEXT_PUBLIC_APP_URL`에 해당. 이 제품은 서버 전용 `APP_URL`을 쓴다). worker·engine·api(AI 서비스)는 로그인을 처리하지 않으므로 인증 단계 변수가 없다.

### 9.4 외부 콘솔과 배포 토폴로지

| 콘솔 | 단계 | 리디렉션 대상 | 메모 |
|---|---|---|---|
| Google Cloud(OAuth 동의 화면, 웹 클라이언트 ID) | B | `https://<project-ref>.supabase.co/auth/v1/callback`, 로컬 `http://127.0.0.1:54321/auth/v1/callback` | 범위는 `openid`, `email`, `profile`만. 동의 화면에 개인정보처리방침·이용약관 URL(`/legal/privacy`, `/legal/terms`, PB-06-025)이 필요하다. 공개 베타 전 "프로덕션" 게시 |
| Supabase 대시보드(Providers, URL Configuration) | B·C | Site URL = 운영 도메인, Redirect URLs = `https://<도메인>/auth/callback`(Vercel 미리보기 도메인은 명시 등록, 와일드카드 지양) | `AUTH_PROVIDERS`와 함께 배포 체크리스트(PB-06-034, B-6)로 확인 |
| 카카오 디벨로퍼스 | C1 | Supabase 콜백(위와 같음) | 동의항목 `profile_nickname`, `profile_image`, 비즈 앱이면 `account_email`(01장 D20) |
| 네이버 개발자센터 | C2 | `supabase_custom`이면 Supabase 콜백, `bridge`면 `https://<도메인>/auth/naver/callback` | 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않는다(C2-6) |

```
브라우저 ──> web(Vercel) /login ──signInWithOAuth──> Google·카카오(·네이버 custom) ──> Supabase /auth/v1/callback
                                                                                         │ code
브라우저 <── 세션 쿠키 <── web /auth/callback(exchangeCodeForSession → finishLogin) <───────┘
(C2 브리지) web /auth/naver/start ──> 네이버 authorize ──> web /auth/naver/callback ──> 세션 발급 → finishLogin
(A, 로컬) web /api/dev/login ──signInWithPassword(시드 계정)──> 로컬 Supabase(127.0.0.1:54321)
```

### 9.5 로그인 없는 사용자 흐름

랜딩(`/`), 요금, 법무 페이지, 대기자 명단(`/api/waitlist`), 공개 책 페이지(`/b/[slug]`, Phase 2)는 로그인이 없고 단계와 무관하다. 이 화면에 로그인 버튼을 새로 넣지 않는다(헤더의 기존 "로그인" 링크만 유지, AUTH_ROADMAP 8장 끝).

## 10. 에이전트 실행 계층과 운영 콘솔 (2026-10-14 FLORA 개편)

요구는 01장 3.1절(PB-F-057~061). 원칙은 하나다: **실행 엔진을 새로 만들지 않는다.** 6개 에이전트는 이미 있는 Route Handler·잡·그래프를 이름 붙여 묶고, 요청마다 `publishing.agent_tasks` 1행으로 실행·검수·재시도·원가를 추적한다. 제안서가 경고한 "UI 개발을 이유로 같은 기능의 실행 엔진을 새로 만드는 것"을 피하는 구조다.

### 10.1 레지스트리 (`web/src/server/agents/registry.ts`)

| `agent_key` | `action` | 처리(기존 소유 작업) | 동기/비동기 | 승인 정책 |
|---|---|---|---|---|
| planning | `titles`, `plans`, `toc`, `persona_blend` | `/api/books/[id]/titles`·`plans`·`toc`(011), `/api/personas/blend`(012) | 동기 | 모두 not_required. 후보 중 선택이 곧 결정이고, 목차는 구조 저장(`PUT structure`)이 확정이다 |
| research | `reference_index`, `wiki_ingest`, `wiki_lint` | 045, 046 | 비동기(`publishing.ai_index`, `wiki_ingest`, `wiki_lint`) | 모두 not_required(설정집은 페이지별 채택이 검수, 사용자 편집이라 작업 결정과 무관) |
| writing | `section_generate`, `chapter_draft`, `write_all` | 013, 014(그래프 `publishing.draft`) | 단건 스트리밍 / 비동기 | `chapter_draft`·`write_all`: 제안(본문 있던 소제목)이나 빈 소제목 AI 초안이 1개라도 있으면 pending(취소된 실행도 저장분이 있으면 pending). `section_generate`(스트리밍): not_required, 덮어쓰기는 그 자리 Diff 카드 |
| editing | `assist_continue`, `assist_expand`, `assist_refine`, `assist_custom`, `examples`, `style_check`, `source_check`, `refine_all` | 013(`/assist`), 014(`refine-all`) | 스트리밍 / 비동기 | 선택 영역 동작(스트리밍 7종): not_required, 그 자리의 Diff 카드·메모가 검수. `refine_all`(잡): pending |
| publishing | `metadata`, `covers`, `export_pdf`, `export_epub`, `narration` | 020, 019, 017, 018, 053 | 동기 / 비동기 | 모두 not_required. `metadata`·`covers`는 후보 선택이 결정, 내보내기는 직전 확인 모달이 최종 점검(다운로드를 막지 않음) |
| content | (Phase 2) | - | - | 외부 게시 전 pending |

### 10.2 기록기와 실행 순서

기존 Route Handler는 처리 함수를 `withAgentTask({ agent, action, origin }, handler)`로 감싼다. 감싸는 쪽이 아래 1~3, 7을 하고 기존 처리(4~6)는 그대로다.

| 순서 | 동작 | 위치 |
|---|---|---|
| 1 | `requireSession('publishing')` → zod → 레이트 리밋 → features(기존 04장 1절 순서) | Route Handler |
| 2 | `agent_tasks` INSERT(service_role, `status='queued'`, `request_id`, `input_summary`=범위 id·개수, `credits_estimated`). 같은 `(org_id, request_id)`가 있으면 그 행을 돌려주고 처리하지 않는다(멱등) | `withAgentTask` |
| 3 | 크레딧 선차감(기존 멱등 키 그대로: 단건 `consume:publishing:<request_id>`, 초안 `consume:publishing:<run_id>:<section_id>`, 색인 `rag:`, 위키 `run:`, 낭독 `voice:`). 모든 차감에 `p_ref_type='agent_task'`, `p_ref_id=<작업 id>`를 넘기고 첫 차감 행 id를 `credit_ledger_id`에 적는다. 차감이 실패하면(402 등) 행을 바로 `failed`(`error_code`)로 끝낸다(환불할 것 없음) | 기존 처리 + `withAgentTask` |
| 4 | 동기 처리 또는 `enqueue_job`. 잡 페이로드에 `agent_task_id`를 더한다(04장 4절) | 기존 처리 |
| 5 | 잡을 끝내는 쪽이 같은 행을 갱신: `status`, `credits_used`, `result_summary`(저장·제안·실패 개수), `ai_run_id`, 승인 정책에 따라 `approval_status='pending'` | worker `worker/src/lib/agent-tasks.ts`, engine `engine/app/agent_tasks.py`, api `app/ai/products/publishing/agent_tasks.py`(같은 계약, 059가 제공) |
| 6 | 실패는 기존대로 `fail_job` 자동 환불, 행은 `failed` + `error_code`·`error_message`(사용자에게 보여도 되는 문장만) | 같음 |
| 7 | 동기 처리는 응답 직전에 행을 끝낸다. 동기화 크론 `/api/internal/agent-sync`(워커가 5분마다, 워커 키)가 (a) 잡은 끝났는데 `running`인 행 마감 (b) 15분 넘게 `queued`이고 잡이 없는 행 → 연결된 차감(`ref_id`) 중 환불 없는 것을 `refund_credits`로 돌려준 뒤 `failed`(`error_code='stale_queued'`) (c) 30일 지난 `pending` → `expired`를 처리한다 | `withAgentTask`, 크론 |

채팅·받아쓰기·읽어 주기는 감싸지 않는다(01장 3.1절). 위키 사람 편집·채택은 작업이 아니라 사용자 편집이다.

원장 연결 규칙: `CORE_SPEC.md` 4.3절 예시는 `p_ref_type='job'`이다. 이 제품은 작업형 동작의 차감에 한해 `p_ref_type='agent_task'`, `p_ref_id=<작업 id>`를 쓴다. `ref_type`은 코어에서 자유 텍스트이고 `refund_credits`가 차감 행의 `ref_type`·`ref_id`를 그대로 복사하므로 환불도 같은 키로 찾힌다(코어 변경 없음). 잡 쪽 연결은 기존대로 `core.jobs.credit_ledger_id`다.

### 10.3 검수(승인) 흐름

| 단계 | 동작 |
|---|---|
| 1 | 저자가 검수 대기함 또는 에디터 AI 패널 "제안" 탭에서 항목(소제목별 제안, 메모)을 연다. 제안 본문은 기존 위치(`core.jobs.result`, `refine_chunk` 결과, 그래프 출력)에서 읽는다. 새 저장소를 만들지 않는다 |
| 2 | 승인한 항목만 `PATCH /api/books/[id]/sections/[sid]`(revision 확인)로 반영한다. 사용자 세션·RLS 그대로 |
| 3 | `POST /api/agent-tasks/[id]/decision { decision, note? }` → RPC `publishing.decide_agent_task`(편집자만, pending만, 감사 `agent_task.decide`) |
| 4 | 빈 소제목 AI 초안(01장 D26 (a))의 "검토 전" 표시는 새 컬럼 없이 소제목 자체로 판단한다: `sections.gen_status='generated'`이면 "검토 전". 저자가 고치면 기존 트리거가 `edited`로 바꾼다. 승인한 초안은 결정 API가 서버 경로로 `edited`(사람 확인)로 바꾸고, 거부한 초안은 본문을 비우고 `empty`로 돌린다(그사이 `edited`가 됐으면 건드리지 않음). 서버 경로는 트리거가 `revision`을 올리지 않으므로 두 경우 모두 `revision = revision + 1`을 직접 적어, 옛 초안을 연 에디터의 자동 저장이 `stale_revision`으로 막히게 한다. 작업 검수가 만료돼도 표시는 남는다 |

### 10.4 재시도와 중복 방지

| 규칙 | 구현 |
|---|---|
| 재시도 대상 | `failed`, `partial`, `canceled`만. DB 트리거가 강제(`PB013`) |
| 한 번만 | `retry_of` 부분 유니크. 같은 작업 두 번째 재시도는 23505 → 409 |
| 재시도 범위 | `failed`·`partial`: `result_summary.failed`(실패한 소제목·청크). `canceled`: `failed` + `result_summary.remaining`(취소로 처리하지 못한 것). 동기 단건 작업은 같은 입력 1건 |
| 이중 차감 방지 | 재시도는 새 `request_id`로 새로 차감한다. 그 전에 원래 작업의 원장(`ref_id=<원래 작업 id>`)을 확인해, 결과가 남지 않은 차감(실패·취소분)에 모두 환불 행(`refund_of`)이 있어야 한다. 하나라도 없으면 409 `refund_missing`. 차감이 아예 없던 작업(402로 끝난 것 등)은 확인 없이 재시도한다. 운영 콘솔 재실행도 같은 규칙 |
| 원래 행 불변 | 신원 컬럼(조직, 책, 에이전트, 동작, `request_id`, `retry_of`, `attempt`, `origin`)은 트리거가 바꾸지 못하게 한다. 예외: 원래 행이 지워질 때 FK가 `retry_of`를 null로 바꾸는 것만 허용 |

### 10.5 운영 콘솔 데이터 경로

| 화면 | 읽는 곳 | 규칙 |
|---|---|---|
| 운영 홈 | `core.profiles`·조직 수, `agent_tasks`(status queued·running·failed), `core.ai_usage` 기간 합, `core.audit_log` 최근 | 집계는 서버(service_role)에서만. 값이 없으면 "—" + 연결 상태(가짜 숫자 금지) |
| 작업 큐·실행 추적 | `agent_tasks` → `core.jobs`(부모·자식) → `core.ai_runs`·`ai_run_steps` → `core.ai_usage`(`run_id`, `request_id`) → `core.credit_ledger`(`ref_type='agent_task'`, `ref_id`, `refund_of`) | 한 화면에 6단계. 프롬프트·출력 본문은 보여 주지 않고 길이·상태·오류 코드만 |
| 원가 | `core.ai_usage.cost_usd_micros`(모델·기능·조직별), `credit_ledger` consume 합. 에이전트별 묶음은 `ai_usage.run_id`·`request_id` → 작업으로 잇고, 작업이 없는 채팅·음성은 "대화형" 묶음으로 둔다(합계가 전체 `ai_usage`와 같도록) | 원가는 운영자 API에만. 원화 환산율은 서버 상수(제안, 월 1회 갱신) |
| 사용자·권한, 출판 프로젝트 | `core.profiles`, `core.organizations`, `core.app_entitlements`, `publishing.books`(본문 제외 컬럼), `book_exports` | 계정 정지·복구는 service_role 서버 경로 + 감사. 원고 본문 열람은 01장 D27 |
| 설정 | `core.ai_routing_settings`(app publishing), `core.plans.features` | 열람만. 변경은 seed·마이그레이션(PB-06-001) |

모든 운영자 조회는 감사 `admin.view`(대상 종류·id, 본문 없음)를 남긴다. 실행 그래프 시각화(React Flow)는 Phase 2(PB-F-062)이며 MVP는 표·타임라인이다.

### 10.6 화면 영역과 디자인 레이어

| 영역 | 경로 그룹 | 디자인 레이어(`data-surface`) | 03장 |
|---|---|---|---|
| A 공개 메인페이지 | `(marketing)` | `marketing`(Editorial Publishing) | 4절, 8.3절 |
| B 작가 작업 공간 | `(app)/dashboard`, `(app)/books/[id]` | `workspace`(Writing Workspace) | 8.4절 |
| C 에이전트 작업 공간 | `(app)/dashboard/agents`, 에디터 AI 패널 | `workspace` | 8.5절 |
| D 운영 콘솔 | `admin` | `ops`(Agent Operations, 기본 밀도 compact) | 8.6절 |

레이어는 토큰을 새로 만들지 않고 같은 의미 토큰의 값만 바꾼다(03장 8.2절). 루트 레이아웃(PB-06-002 소유)이 경로 그룹별 `data-surface`를 붙인다.
