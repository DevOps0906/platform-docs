# 04 API: NOMAD Commerce

코드 블록은 계약 예시다. 구현 파일이 아니다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 `/api/*`(웹훅, `/api/dev/login` 제외) 첫 줄에서 `requireSession('commerce', { roles })`(SHARED_MODULES 2장). 미로그인 401, pending/suspended 403, `entitled=false` 402. 세션은 모든 인증 단계(A Mock·B Google·C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(8절, `AUTH_ROADMAP.md` 0장) |
| 역할 | 쓰기는 owner/admin/member, 계정·결제는 owner/admin. 역할 비교는 `ctx.org?.role`이 없으면 거부(SECURITY_BASELINE 2장) |
| 플랜 | `core.entitled_plan_code` + `plans.features`(01장 4.4)만. 요청 바디의 plan/model 값은 무시 |
| 멱등 | 클라이언트가 요청마다 UUID `request_id` 전송. 서버 키 `consume:commerce:<request_id>`, `job:commerce:<request_id>`(`CORE_SPEC.md` 4.4) |
| 크레딧 | Route Handler에서 `consume_credits` 선차감 후 저장·잡 등록. 클라이언트가 부르는 별도 차감 API 없음 |
| DB 쓰기 | 사용자 콘텐츠(products, shipping_templates, listing_drafts, banned_words)는 RLS 하 사용자 클라이언트로 가능. 나머지는 `createAdminClient()`(service_role)로만 |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. code는 7절 |
| 레이트 리밋 | `core.rate_limit_hit('commerce:<route>:<org_id>', 60, 60)`. 초과 429 |
| 입력 | zod. 문자열 길이 상한, URL은 `packages/commerce-net` 검사 |
| 타임아웃 | 외부 호출 `AbortSignal.timeout`(공급자 15초, 마켓 30초). AI는 FastAPI 호출이며 보조 그래프 `commerce.assist` 대기 30초, 상세페이지 그래프 120초(워커). LLM·음성 제공자는 Route Handler·워커에서 직접 부르지 않는다 |
| AI 경로 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰(`lib/ai/token.ts`만 발급), Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. 요청 바디·쿼리의 org, 제공자, 모델 값은 무시한다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:278-300`) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/products` | member+ | 상품 콘텐츠 필드 | product | 0 | - | CM002→403 |
| `PATCH /api/products/[id]` | member+ | 부분 필드 | product | 0 | - | 404 |
| `POST /api/products/bulk` | member+ | `{ ids[≤500], action: archive, restore, delete 중 하나 }` | `{ affected }` | 0 | - | CM002 |
| `POST /api/products/[id]/specs` | member+ | multipart 스펙 시트(md, txt, csv, xlsx, 2MB 이하) | `{ document_id }`(색인은 비동기) | 0 | FastAPI `/rag/ingest` 등록(scope `rag`, 셀러 조직), `rate_limit_hit('commerce:specs:<org>', 20, 2592000)`(월 20건, D-11) | 413, 422, 429 |
| `POST /api/sourcing/amazon` | member+ | `{ request_id, inputs: string[≤20] }`(URL 또는 ASIN) | `{ batch_id, accepted[], rejected[] }` | 건당 1 | consume_credits, enqueue_job | 400 URL, 402 |
| `POST /api/sourcing/excel` | member+ | `{ request_id, storage_path, supplier: ownerclan 또는 custom }` | `{ batch_id }` | 0 | enqueue_job | 400 형식 |
| `POST /api/sourcing/excel/[batch]/mapping` | member+ | `{ column_mapping }` | batch | 0 | enqueue_job | 409 상태 |
| `POST /api/detail-pages` | member+ / `detail_types`, `slot_sets` | `{ request_id, items: [{ product_id, page_type, slot_set, slots?, template, target_markets }] (≤50) }` | `{ detail_page_ids[] }`(waiting) | 9/14 x 개수 | consume_credits(1회, 합계) | 402, 403, 422 슬롯 |
| `POST /api/detail-pages/[id]/cancel` | member+ | - | page | 환불 | refund_credits(waiting) / cancel_job(queued) | 409(generating은 `cancel_requested_at`만) |
| `POST /api/detail-pages/[id]/retry` | member+ | `{ request_id }` | page | 9/14 | consume_credits | 409 상태 |
| `POST /api/detail-pages/[id]/slots/[code]/regenerate` | member+ | `{ request_id, quality: standard 또는 high, prompt_override?(≤500) }` | job | 1 / 3 | consume_credits, enqueue_job | 409 |
| `PATCH /api/detail-pages/[id]/copy` | member+ | `{ copy }` | page(verdict 재계산) | 0(규칙), LLM 재판정 선택 시 1 | - | 422 sanitize |
| `POST /api/detail-pages/[id]/acknowledge` | member+ | `{ note? }` | page | 0 | `commerce.acknowledge_compliance_warning` | CM008, CM009 |
| `POST /api/ai/names` | member+ | `{ request_id, product_id }` | 상품명 3안 + 키워드 | 1 | withCredits + FastAPI 그래프 `commerce.assist`(작업 `names`, 2.1절 공통) | 402 |
| `POST /api/ai/autofill` | member+ | `{ request_id, listing_draft_id, target: category, notice, tags 중 하나 }` | 제안값(저장 안 함) | 1 | withCredits + `commerce.assist`(작업 `autofill`) | 402 |
| `POST /api/ai/voice` | - | 폐기(2026-10-13). fal whisper STT 대신 `POST /api/voice/stt`(feature `product_voice`)와 `POST /api/ai/voice-structure`(2.1절) | - | - | - | - |
| `POST /api/ai/benchmark` | member+ / `url_benchmark` | `{ request_id, url }`(허용 도메인) | 분석 요약 | 2 | withCredits. `commerce-net`이 본문을 가져와 텍스트만 `commerce.assist`(작업 `benchmark`)에 넘긴다 | 400 SSRF 차단 |
| `POST /api/ai/vision` | member+ | `{ request_id, storage_paths[≤10] }` | 상품 속성 | 0(생성 단가 포함, 단독 호출 시 1) | withCredits + `commerce.assist`(작업 `vision`, 기능 `commerce.vision`) | 402, 503 `AI_UNAVAILABLE`(오픈소스 멀티모달 미서빙, D-16) |
| `POST /api/listings` / `PATCH /api/listings/[id]` | member+ | 폼 필드 | draft + 서버 계산 completeness | 0 | - | 404 |
| `POST /api/uploads` | member+ / `market_api` | `{ request_id, listing_draft_ids[≤50] }` | `{ upload_ids[] }` | 0 | enqueue_job | CM004~CM008 |
| `POST /api/uploads/[id]/retry` | member+ | `{ request_id }` | upload | 0 | enqueue_job | 409 |
| `POST /api/exports` | member+ / excel·zip | `{ request_id, kind, market, detail_page_ids[≤500] }` | export | 0 | enqueue_job | CM007, CM004 |
| `GET /api/exports/[id]/download` | 멤버 | - | 302 서명 URL(7일) | 0 | - | 410 만료 |
| `POST /api/market-accounts` | owner/admin / `market_slots` | `{ market, slot_no, label, vendor_id?, secrets: { access_key, secret_key } 또는 { client_id, client_secret } }` | 계정(마스킹) | 0 | vault put + audit | CM003, CM006, 422 검증 실패 |
| `POST /api/market-accounts/[id]/verify` | owner/admin | - | 결과 | 0 | - | 502 마켓 |
| `DELETE /api/market-accounts/[id]` | owner/admin | - | - | 0 | `revoke_credential` + status disabled | - |
| `POST /api/billing/orders` | owner/admin | `{ kind: subscription 또는 credit_pack, plan_code? , pack_code? }` | `{ orderId, amount, customerKey }` | - | payment_orders INSERT | 409 |
| `POST /api/billing/confirm` | owner/admin | `{ paymentKey, orderId, amount }` | 결과 | - | Toss confirm → `confirm_payment_order` | PM001/PM409/PM410 |
| `POST /api/billing/billing-key` | owner/admin | `{ authKey }` | 카드 요약 | - | billing_keys INSERT(암호문) | 502 |
| `POST /api/billing/subscription` | owner/admin | `{ action: upgrade, downgrade, cancel 중 하나, plan_code? }` | 구독 | - | `apply_subscription_transition` | SB001 |
| `POST /api/webhooks/toss` | 공개 | rawBody | 200 | - | webhook_events | 401 서명 |
| `POST /api/webhooks/fal?token=` | 공개 | rawBody | 200 | - | webhook_events | 401 |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158`, `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:22-38`을 따른다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner/admin | `{ granted: boolean, notice_version }`(서버 상수 `AI_CROSS_BORDER_NOTICE_VERSION`과 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`(감사는 코어가 기록) | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/ai/conversations` | member+, `features.ai_chat` | `{ channel: 'text'\|'voice', product_id?, detail_page_id?, upload_id? }`(0~1개 바인딩) | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). 바인딩 대상은 같은 조직 행만 | 404/403 `AI_BINDING_FORBIDDEN`, 403 플랜 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000) }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, 바인딩 id). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종(분당, 일, 조직), `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/voice/consent` | member+ | `{ notice_version }` | 204 | 0 | - | `core.write_audit(org, 'ai.voice_notice.ack', 'user', <user_id>, after {notice_version})`(service_role) | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | member+, `features.voice_chat` | `{ conversation_id }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED`, 403 플랜 |
| `POST /api/voice/stt` | member+. `voice_chat`은 세션 주인, `product_voice`는 `features.voice_input` | multipart `{ audio(webm/ogg/mp4), feature: 'voice_chat'\|'product_voice', session_id?, request_id }`. voice_chat 60초·5MB, product_voice 120초·10MB | `{ text, duration_seconds, provider, voice_job_id }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'commerce',<feature>,'stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인, `features.voice_chat` | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/ai/voice-structure` | member+, `features.voice_input` | `{ request_id, voice_job_id, text(≤3000) }`(`voice_job_id`는 같은 사용자의 최근 1시간 안 `product_voice` 성공 작업, 작업당 3회까지) | `{ fields: { title?, bullets?, attributes?, usage? } }`(저장 안 함) | 0(STT 선차감에 포함) | FastAPI 그래프 `commerce.assist`(작업 `voice_structure`, scope `graph:commerce.assist`) | `ai_runs`, `rate_limit_hit('commerce:voice-structure:<voice_job_id>', 3, 3600)` | 404 작업, 409 한도 초과, 503(환불 대상 없음) |
| `POST /api/ai/shorts-script` | member+, `features.shorts_narration` | `{ request_id, product_id\|detail_page_id, seconds: 15\|30\|50 }` | `{ script, issues[] }`(저장 안 함) | 1 | FastAPI 그래프 `commerce.assist`(작업 `shorts_script`) | `withCredits`, 같은 조직 상품·상세페이지만 | 402, 403, 404, 503 |
| `POST /api/voice/narrations` | member+, `features.shorts_narration` | `{ request_id, script(1..600), voice: 'default'\|'oss', product_id, detail_page_id? }` | `{ url, expires_at, provider, voice_job_id }`(이미 있으면 200 같은 형식, 차감 0) | 글자 수 × 단가 선차감, 실제 정산 | `shorts_narration`/`tts` 체인에서 시작 제공자 1개 고정, 대체 금지(scope `voice`) | `voice_jobs`(feature `shorts_narration`), Storage `exports/<org_id>/commerce/narration/<product_id>/<hash16>.mp3`, `consume_credits`/`refund_credits`, `rate_limit_hit('commerce:narration:<org>', 10, 3600)` | 422 `NARRATION_SCRIPT_REJECTED`(금지어 FAIL), 402, 429, 502 `NARRATION_FAILED`(환불됨) |
| `GET /api/voice/narrations/[voice_job_id]` | 작업 주인 | - | `{ url, expires_at, provider }`(7일 서명 URL) | 0 | - | `rate_limit_hit('commerce:download:<org>', 60, 3600)` | 404, 410 만료 |
| `POST /api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 발급만: scope `graph:commerce.detail_page`, `feat=commerce.detail_page`, `org`·`sub`는 `core.jobs` 행의 `org_id`·`created_by` | `core.jobs` 조회(`status='running'`, `app_id='commerce'`, `job_type='detail.generate'`) | 401 `INTERNAL_KEY_INVALID`, 409 잡 상태, 429 |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 |
| `POST /api/admin/knowledge/documents` | platform_admin | multipart md(2MB 이하), `{ title, market, as_of(date), source }` | `{ document_id }` | 0(운영자 조직 사용량) | FastAPI `/rag/ingest`(scope `rag`, `org`=`COMMERCE_KNOWLEDGE_ORG_ID`) | Storage 운영자 조직 폴더, 감사 `knowledge.upload` | 409 중복, 403 |
| `POST /api/admin/wiki/ingest`, `POST /api/admin/wiki/lint` | platform_admin | `{ document_ids?: uuid[] }` | `{ run_id }` | 0 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | - | 403 |
| `PATCH /api/admin/wiki/pages/[...slug]` | platform_admin | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 R-2) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처·기준일 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |

상품 스펙 색인 요청(`commerce.ai.rag_ingest`)은 사용자 Route Handler가 아니라 상품 저장·스펙 시트 업로드(`POST /api/products`, `PATCH /api/products/[id]`, 스펙 업로드 `POST /api/products/[id]/specs`)가 서버 안에서 FastAPI `/rag/ingest`(scope `rag`, 토큰 org = 셀러 조직)를 호출해 등록한다. `POST /api/products/[id]/specs`는 member+, md·txt·csv·xlsx 2MB 이하, 조직 월 20건(D-11), 0크레딧이며 오류는 413, 422, 429다.

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`). 공개 위키는 서버 컴포넌트가 운영자 조직의 `published` 페이지를 service_role로 읽어 ISR로 그린다(사용자 입력이 쿼리에 들어가지 않는 slug 조회만).

## 3. RPC (SECURITY DEFINER)

| 함수 | 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|---|
| `commerce.acknowledge_compliance_warning` | `(p_detail_page_id uuid, p_note text default null)` | authenticated, service_role | `is_service_caller()` 또는 `has_org_role(owner,admin,member)`, `has_entitlement`, status ready, verdict warn | `commerce.detail_pages` 행, `write_audit('detail_page.compliance_warn_ack')` | P0002, 42501, CM008, CM009 |
| `commerce.commerce_features` | `(p_org_id uuid) returns jsonb` | service_role | - | 플랜 features | - |
| `commerce.commerce_limit` | `(p_org_id uuid, p_key text, p_default int) returns int` | service_role | - | 한도 | - |
| `commerce.commerce_transition_allowed` | `(p_table text, p_from text, p_to text) returns boolean` | authenticated, service_role | immutable | 허용 여부 | - |

코어 RPC(`consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `confirm_payment_order`, `apply_subscription_transition`, `revoke_credential`, `rate_limit_hit`, `session_context`, `bootstrap_app_for_org`)와 AI·음성 코어 RPC(`set_ai_cross_border_ack`는 사용자 세션, `resolve_ai_route`·`match_ai_chunks`는 service_role만)는 `docs/file/03-설계/공용코어/CORE_SPEC.md`와 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql`을 인용만 한다. 제품 AI RPC는 만들지 않았다(05장 6절).

## 4. 잡 페이로드 계약

비밀값은 payload에 넣지 않는다(`credential_id`만). 진행 메시지는 `heartbeat_job(p_progress, p_message)`.

```ts
// detail.generate
type DetailGeneratePayload = { detail_page_id: string; org_id: string; image_quality: 'draft'|'standard'|'pro'|'ultra' }
type DetailGenerateResult  = { status: 'ready'; slots_completed: number; slots_failed: string[]; partial_refund: number; verdict: 'pass'|'warn'|'fail'; ai_run_id: string }
// progress message: `${phase}:${done}/${total}` 예 "images:5/10"

// detail.slot_regenerate
type SlotRegeneratePayload = { detail_page_id: string; slot_code: SlotCode; quality: 'standard'|'high'; prompt_override?: string }

// import.amazon / import.excel
type ImportAmazonPayload = { batch_id: string; asins: Array<{ asin: string; marketplace: 'US'|'JP'|'DE'|'UK'|'CA' }> }
type ImportExcelPayload  = { batch_id: string; storage_path: string; supplier: 'ownerclan'|'custom'; column_mapping?: Record<string, string> }
type ImportResult        = { imported: number; skipped: number; failed: number }

// upload.coupang / upload.smartstore
type UploadPayload = { upload_id: string; market_account_id: string; credential_id: string }
type UploadResult  = { market_product_id: string; status: 'submitted'|'approved' }

// export.excel / export.zip
type ExportPayload = { export_id: string }
type ExportResult  = { storage_path: string; bytes: number; rows?: number }

// commerce.ai.rag_ingest (FastAPI 큐 commerce.ai)
type RagIngestPayload = { document_id: string; collection: 'commerce-rules' | 'commerce-products' }
type RagIngestResult  = { chunks: number; embedding_provider: string; embedding_model: string }
// commerce.ai.wiki_ingest / commerce.ai.wiki_lint
type WikiIngestPayload = { document_ids: string[] }
type WikiIngestResult  = { created: number; updated: number; draft_slugs: string[] }
type WikiLintResult    = { contradictions: string[]; stale: string[]; orphans: string[]; broken_links: string[]; unsourced: string[] }
```

| 잡 | 진행률 규칙 |
|---|---|
| detail.generate | 01장 3.6절 phase 표 |
| import | 처리 행 / 전체 행 |
| upload | validating 20, uploading 60, submitted 100 |
| export | 처리 페이지 / 전체 |
| commerce.ai.* | `chunking`, `embedding:<n>/<total>`, `done` / 위키는 `page:<n>/<total>` |

### 4.1 FastAPI 그래프 계약

워커가 잡 토큰(02장 4.1절)으로 부르는 `commerce.detail_page`의 계약이다. 입력에는 비밀값·개인정보가 없고, FastAPI가 상품 행을 DB에서 읽는다(요청 본문의 org 무시).

```json
// POST {AI_SERVICE_URL}/graphs/commerce.detail_page/runs   (Authorization: Bearer <잡 토큰>)
{ "detail_page_id": "uuid", "job_id": "uuid", "mode": "full" }
// 202
{ "run_id": "uuid", "status": "queued" }
// GET /graphs/runs/{run_id} 완료 시
{ "status": "succeeded",
  "output": {
    "names": ["...", "...", "..."],
    "description": { "hook": "...", "body": "...", "evidence": "...", "cta": "..." },
    "slots": [ { "slot_code": "T-1", "copy_ko": "...", "image_prompt_en": "...", "template_data": {} } ],
    "market_text": { "coupang": { "title": "...", "tags": [], "notice": {}, "description": "..." },
                     "smartstore": { "title": "...", "tags": [], "notice": {}, "description": "..." } },
    "verdict": "pass|warn|fail",
    "issues": [ { "field": "slots.D-3.copy_ko", "word": "...", "severity": "fail|warn", "rule_ref": "wiki:markets/coupang/title|banned:<id>", "suggestion": "..." } ],
    "citations": [ { "type": "chunk", "id": 123 }, { "type": "wiki", "slug": "markets/coupang/title", "as_of": "2026-09-01" } ] },
  "ai_run_id": "uuid" }
// 실패 시 { "status": "failed", "error": "input_invalid|provider_unavailable|graph_timeout" }
```

- `mode`는 `full`(전체 6노드)과 `compliance_only`(편집 후 재판정: `banned_check` → `compliance`만, 1크레딧 `PATCH /api/detail-pages/[id]/copy`의 LLM 재판정 선택 시) 두 가지다(제안).
- verdict `fail`은 오류가 아니다. 상세페이지는 `ready`가 되고 업로드·내보내기가 CM004로 막힌다(기존 규칙). 그래프 `failed`만 잡 재시도·환불 대상이다.
- 규칙 검색(`retrieve`)이 실패하면 근거 없이 진행하고 verdict 최소 `warn`, issues에 "규칙 근거 없음"을 남긴다(제안).
- 출력 스키마는 `packages/commerce-domain/schema/detail-page-graph.schema.json` 하나에서 pydantic과 zod를 만든다. 워커는 zod로 다시 검증하고 `market_text`는 `packages/commerce-domain` 마켓 규격으로 한 번 더 검사한다.

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태(취소, 가상계좌) | 시크릿 검증(방식 미확인, SHARED_MODULES 6장) | paymentKey + status + 시각 해시 | 상태 동기화만. 지급은 confirm 경로 |
| 수신 | fal 이미지 완료 | URL 토큰 `FAL_WEBHOOK_SECRET` 비교 + `request_id`가 `detail_page_slots.provider_request_id`에 있는지 대조 | fal `request_id` | 이미지를 `org-files`로 복사 후 슬롯 갱신. 모르는 request_id는 ignored |
| 발신(Phase 2) | `product.sourced`, `detail_page.created`, `market.uploaded` | HMAC-SHA256(`timestamp.rawBody`), 사용자별 시크릿 | - | automation-core 소유(`Nomad-AI-Factory_V.2/CLAUDE.md:601-633`의 이벤트 이름 재사용) |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 인증 | 실패 처리 | 쿼터/비고 |
|---|---|---|---|---|
| 쿠팡 Wing Open API | 워커 upload | 셀러 Access/Secret 키 HMAC-SHA256 서명 + vendorId | 5xx·429 재시도 3회, 4xx 즉시 실패(필드 오류 매핑) | 등록 후 승인 요청과 승인 결과 조회가 필요한지 미확인. 상태 폴링 10분 |
| 네이버 커머스 API(스마트스토어) | 워커 upload | 셀러 client_id/secret → 전자서명 토큰(방식 미확인) | 같음 | 호출 한도 미확인. 토큰 캐시는 메모리, DB 저장 안 함 |
| 아마존 상품 데이터 공급자 | 워커 import | 플랫폼 키(env) | 없는 ASIN은 행 실패 + 환불 | 건당 과금(미확인) |
| 한국수출입은행 환율 | 워커 크론 | 플랫폼 키 | 실패 시 이전 값 유지 + 경고 | 일 1회 |
| FastAPI AI 서비스(그래프) | 워커 `detail/`(잡 토큰), Route Handler(`commerce.assist`, 서명 토큰) | EdDSA 서명 토큰 | 체인 대체(라우터) → 금지어 재작성 1회(그래프) → `failed` → `fail_job(retryable)` → 자동 환불. 120초(상세페이지)·30초(보조) 안에 끝나지 않으면 실패 | 상세페이지당 LLM 호출은 `extract`·`copy`(슬롯 병렬)·`convert`(길이 초과 시)·`compliance`. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `app/api/ai/chat` | 앱 키 | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `app/api/voice/*` | `ELEVENLABS_API_KEY` | 채팅용은 체인 다음으로 대체(`voice_jobs.fallback_from`), 내레이션은 대체 없이 실패 + 환불 | 요금·상업 이용 조건·데이터 보관 구현 시 확인(D-12) |
| 오픈소스 음성 서버 | `app/api/voice/*`(서명 토큰 scope `voice`) | 서명 토큰 | 같음 | 요청당 STT 10분·TTS 5,000자 상한(`docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:61`). commerce는 60초·120초·600자 |
| fal | 워커 images (STT에는 쓰지 않음) | 플랫폼 키 | 제출 실패 즉시 환불, 30분 미도착 실패 | safety checker on |
| Toss | Route Handler, 워커 | 시크릿 키 | core 규약 | - |
| video 워커(Phase 2) | Route Handler | 서비스 토큰 | 렌더 실패 환불 | C-6. 입력은 내레이션 mp3 경로와 상세페이지 이미지 경로, 렌더·결합 코드는 shortsflow 소유 |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158` 중 commerce가 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | commerce 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류·규칙 요약 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`, `wiki.query`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R-2). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `product`: 매핑 org의 상품·상세페이지·업로드인지 확인 → 해당 행 + 상품 스펙 컬렉션 검색 → `chat` 모델. 모드 `rules`는 Dify 외부 지식 경로가 기본이고 이 엔드포인트는 대체 경로에서 쓴다. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리(모드는 FastAPI가 분류) |
| `POST /dify/retrieval` | Dify 외부 지식 | 내부 키 | 운영자 조직의 `commerce-rules`와 `commerce-wiki` 컬렉션만. 셀러 조직 데이터 금지 |
| `POST /graphs/commerce.detail_page/runs`, `GET /graphs/runs/{id}` | 워커 | 잡 토큰 scope `graph:commerce.detail_page`, `jti` 1회 | 상세페이지 텍스트 생성(4.1절 계약) |
| `POST /graphs/commerce.assist/runs`, `GET /graphs/runs/{id}` | Next.js Route Handler | 서명 토큰 scope `graph:commerce.assist`, `jti` 1회 | 보조 AI 6작업(02장 5.2절) |
| `POST /rag/ingest` | Next.js 서버(상품 저장·스펙 업로드), 관리자 | 서명 토큰 scope `rag` | 상품 스펙 색인(셀러 조직), 규칙 원고 색인(운영자 조직) |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-2) | Next.js 관리자 | 서명 토큰 scope `wiki` | 마켓 규칙 위키 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`commerce-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `commerce-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_COMMERCE`(Next.js 서버 전용). 정의는 `infra/dify/commerce-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `product_id`·`detail_page_id`·`upload_id`(선택, UUID 문자열, 대화 시작 때만). 서명 토큰, org, 마켓 키, 사업자번호는 넣지 않는다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `product`: HTTP 요청 노드 → 답변 / 분기 `rules`: 지식 검색 노드(외부 지식 `commerce-rules` → `/dify/retrieval`) → LLM 노드(model `wiki.query`) → 답변 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, mode: "product" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title, as_of }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | `product` 분기는 FastAPI가 `ai_messages.citations`를 기록하고, `rules` 분기는 Next.js가 Dify 응답의 검색 출처 메타데이터로 기록한다 |
| 첫 표시 지연 | `product` 분기는 HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다(01장 5절) |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| CM001 | 상태 전이 위반 | 409 |
| CM002 | 상품 수 한도 | 403(업그레이드 안내) |
| CM003 | 마켓 계정 슬롯 한도 | 403 |
| CM004 | compliance FAIL | 422 |
| CM005 | WARN 미확인 | 422 |
| CM006 | 마켓 계정 무효(다른 조직, 비활성, 키 없음, 마켓 불일치) | 409 |
| CM007 | 플랜 미허용 기능 | 403 |
| CM008 | 상세페이지 미완료 | 409 |
| CM009 | 확인할 WARN 없음 | 409 |
| 23514 | CHECK 위반(필수 슬롯, 반품 기간 등) | 422 |
| 23503 | 다른 조직 행 참조(복합 FK) | 404 |
| 코어 | 42501→403, CR001→402, P0002/PM404→404, 22023/SB001/JB002/PM410→409, PM001/PM409→409 + 운영 알림, OA001→400 | `CORE_SPEC.md` 15장 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 |
| 앱 코드 `AI_BINDING_FORBIDDEN` | 대화에 묶으려는 상품·상세페이지·업로드가 다른 조직 것 | 403 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한(`ai_chat_turns_per_day`) | 429 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 60초(채팅) 또는 120초(상품 입력), 5MB 또는 10MB 초과 | 413 |
| 앱 코드 `NARRATION_SCRIPT_REJECTED` | 스크립트가 600자를 넘거나 금지어 FAIL | 422 |
| 앱 코드 `NARRATION_FAILED` | 내레이션 생성 실패(선차감 환불 완료) | 502 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 `expected_version` 불일치 | 409 |
| 앱 코드 `INTERNAL_KEY_INVALID` | 워커 키 불일치 | 401 |

## 8. 인증 단계 경로 (2026-10-14 추가, 확정 결정 22)

정본 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2.4절, 3.2절, 7.2.3절. 이 경로들은 `requireSession` 앞단(로그인 자체)이라 1절 인증 규칙의 예외다. 단계 분기는 `apps/nomad-commerce/lib/auth/`에서만 한다.

| 메서드 경로 | 단계 | 입력 | 동작 | 출력 | 오류 |
|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | `{ persona: 'owner'\|'admin'\|'member'\|'viewer'\|'outsider'\|'no_app'\|'suspended'\|'ops'\|'pro'\|'ai_consent', next? }`(제품 행 `pro`, `ai_consent`는 05장 10절) | `isMockAuthAllowed()`(`AUTH_MODE=mock`, Supabase 호스트 `127.0.0.1`·`localhost`, `VERCEL_ENV`·`RAILWAY_ENVIRONMENT` 비어 있음) 확인 → 서버 클라이언트로 `signInWithPassword(<persona>@dev.test, DEV_SEED_PASSWORD)` → 세션 쿠키 → `finishLogin('commerce', next)` | 302 `next`(화이트리스트) 또는 `/dashboard` | 판정 거짓이면 404(존재를 숨김), 모르는 페르소나 400, 시드 안 됨 409 "seed-users를 먼저 실행하세요"(제안) |
| `GET /auth/callback` | B·C(Google, 카카오, `custom:naver`) | `code`, `next?` | `finishLogin`: (1) `exchangeCodeForSession`(PKCE) (2) `session_context('commerce')` 1회 (3) `entitled=false`면 open 앱이므로 `rpc('bootstrap_app_for_org', { p_app_id: 'commerce' })` 1회 후 재조회(가입·월 크레딧 멱등, `migrations/0003_core_credits.sql:440-461`) (4) suspended → 403 (4-1) OAuth 제공자 첫 로그인이고 약관 동의 기록이 없으면 `/onboarding/terms`(03장 7절, CM-06-058. 이메일 가입자와 Mock 시드 페르소나는 이메일 제공자라 건너뜀) (5) `next`가 `/`로 시작하고 `//`·`@`·`\` 없을 때만, 아니면 `/dashboard`, origin은 `NEXT_PUBLIC_APP_URL` (6) 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 없음) | 302 | 코드 없음·재사용·만료 → `/login?error=callback`, 프로필 없음 → 로그아웃 후 `/login` |
| `GET /auth/naver/start` | C2(브리지 경로 채택 시만) | `next?` | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분)에 넣고 네이버 authorize로 302. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 302 | 429 |
| `GET /auth/naver/callback` | C2(브리지만) | `code`, `state` | state 상수 시간 비교 후 쿠키 삭제 → 서버가 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(코어 `staged/0010_core_auth_identity_links.sql`)로 사용자 찾기 → 매직링크 `verifyOtp`로 세션 → `finishLogin`. 네이버 토큰은 저장하지 않는다 | 302 | `/login?error=state`, `/login?error=email_in_use`, `/login?error=callback` |

| 오류 코드 | 의미 | 처리 |
|---|---|---|
| `error=callback` | OAuth 코드 교환 실패 | 로그인 화면 오류 띠(03장 7절), 서버 로그에 토큰·코드 없음 |
| `error=state` | (브리지) state 변조·재사용·만료·쿠키 없음 | 세션 미생성 |
| `error=email_in_use` | (브리지) 같은 이메일 다른 방법 가입자, 자동 연결하지 않음 | 03장 7절 문구 |
| 404 `/api/dev/login` | 배포 환경·원격 DB·`AUTH_MODE=live` | 경로가 없는 것처럼 응답 |

`/api/dev/login`은 레이트 리밋 대상이 아니다(로컬 전용). 빌드 검사: `AUTH_MODE=mock VERCEL_ENV=production pnpm -F nomad-commerce build`가 실패해야 하고, `AUTH_MODE=live` 빌드에서 `/api/dev/login`은 404다(`AUTH_ROADMAP.md` 2.4절).
