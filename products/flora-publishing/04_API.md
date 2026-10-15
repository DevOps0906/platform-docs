# 04 API: FLORA Publishing

2026-10-13 개정: AI·음성 Route Handler(2.1절), 그래프·AI 잡 페이로드(4절), 이 제품이 쓰는 FastAPI 엔드포인트와 Dify 계약(6.1, 6.2절), AI 오류 코드(7절)를 더했다. 브라우저는 `/api/ai/*`, `/api/voice/*`만 부르고 Dify·FastAPI·AI 제공자는 Route Handler가 부른다(`docs/products/_platform-core/SECURITY_BASELINE.md:299`).

작성일 2026-10-12. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`(아래 CS)를 인용만 한다. 공용 모듈 인터페이스는 `SHARED_MODULES.md`(아래 SM). 코드 블록은 계약 예시다.

## 1. 원칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| 인증 | 모든 Route Handler 첫 줄 `const ctx = await requireSession('publishing')`. 미로그인 401, pending/suspended 403, `entitled=false` 402. 공개 예외: `/api/waitlist`, `/api/webhooks/toss`, `/api/webhooks/fal`, `/api/public/books/[slug]`(Phase 2), 로그인 경로(`/api/dev/login` A 로컬 전용, `/auth/callback`, `/auth/naver/*`, 8절). 세션은 모든 인증 단계(Mock·Google·카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다 | SM 2장, `docs/reviews/Flora-v2.md:114`, `docs/products/_platform-core/AUTH_ROADMAP.md` 0장 |
| 순서 | 인증 → 입력 zod 검증 → 레이트 리밋 → 엔타이틀먼트·features 확인 → 크레딧 선차감 → 처리(동기 호출 또는 enqueue) → 실패 시 환불 | CS 4.3, `docs/reviews/SellingDocs.md:70` |
| 멱등 | 유료·비동기 요청은 본문에 `request_id`(UUID v4) 필수. 차감 키 `consume:publishing:<request_id>`, 잡 키 `job:publishing:<request_id>` | CS 4.4, SM 18장 |
| DB 접근 | 사용자 콘텐츠(books, chapters, sections, member_settings) 읽기·쓰기는 세션 클라이언트(RLS 적용). 서버 전용 테이블과 코어 RPC는 `createAdminClient`(service_role)로, 호출 전에 `ctx.org.id`와 대상 행의 `org_id` 일치를 확인 | `SECURITY_BASELINE.md` 4장, 11장 |
| 응답 봉투 | 성공 `{ ok: true, data }`, 실패 `{ ok: false, error: { code, message, details? } }`. 402는 `details: { required, balance }` | 제안 |
| 레이트 리밋 | `core.rate_limit_hit('publishing:<route>:<org_id>', limit, window)`. 기본은 01장 5절 | CS 12장 |
| 스트리밍 | 섹션 단건·보조 집필만 `text/event-stream`을 POST 응답으로. 클라이언트는 fetch + ReadableStream. EventSource 금지 | `docs/reviews/Flora-v2.md:105` |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler가 부른다. 책 소유 확인은 항상 서버가 `books.org_id = ctx.org.id`로 한다 | `docs/products/_platform-core/SECURITY_BASELINE.md:299` |
| 서명 토큰 | `web/src/server/ai/token.ts`가 EdDSA JWT를 발급: `iss=publishing`, `aud=platform-ai:publishing`, `org`, `app=publishing`, `sub`(사용자 id), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 세션 또는 잡 행에서만 가져온다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:33-42` |
| AI 멱등 키 | 채팅 `conv:<id>:turn:<n>`(n은 서버가 센 턴 번호. 같은 `request_id` 재전송은 `publishing:ai-req:<request_id>` 버킷 1회로 막는다), 음성 `voice:<voice_job_id>`(클라이언트 `request_id`를 `voice_jobs.id`로 쓴다), 초안 `consume:publishing:<run_id>:<section_id>`, 색인 `rag:<document_id>`, 위키 `run:<ai_run_id>` | 제안 |
| AI 선차감·정산 | 선차감은 제공자 호출 전 Route Handler(또는 enqueue 직전)에서, 정산은 응답 종료 직후 같은 Route Handler에서. 연결이 끊기면 `/api/internal/ai-settle`(워커가 5분마다 호출)이 처리 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| AI 레이트 리밋 | `publishing:ai-chat:<user>` 20회/60초, `publishing:ai-chat-day:<user>` `ai_chat_turns_per_day`회/86400초, `publishing:voice-stt:<user>` 10회/60초, `publishing:narration:<org>` 5회/3600초, `publishing:ai-token:worker` 120회/60초 | 01장 5절 |
| 스트리밍(AI) | 채팅은 SSE(`text/event-stream`), 낭독 진행은 NDJSON 스트림 | 제안 |
| sanitize | LLM 결과와 사용자 HTML은 서버에서 허용 목록 sanitize 후 저장(p, h2~h4, strong, em, u, s, blockquote, ul, ol, li, br, hr, a[href https], figure, img[src Storage 경로], figcaption, table 계열). 렌더 직전 엔진이 nh3로 한 번 더 | `docs/reviews/SellingDocs.md:55`, `SECURITY_BASELINE.md` 10장 |

## 2. Route Handler

플랜 열: F = Free 가능, B = Basic 필요(features 키). 크레딧은 `01_PRD.md` 4.3절.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/session` | 로그인 | - | `SessionContext` | 0 | `session_context` | 401 |
| `POST /api/books` | member+ / F | `{ title?, source:'wizard'\|'seed', seed_key? }` | `{ book }` | 0 | - | 409 `PB001`(쿼터) |
| `GET /api/books` | 멤버 / F | `?status&trash=bool&cursor` | `{ items, next }` | 0 | - | - |
| `PATCH /api/books/[id]` | member+ / F | 콘텐츠 컬럼 부분집합(`step_state`, `current_step`, `format_key`, `layout_settings`, `tone`, `plan_brief`, `book_info`, `cover_image_id`, `status`) | `{ book }` | 0 | - | 409 `22023`, `PB006`, `PB011` |
| `DELETE /api/books/[id]` | owner/admin / F | - | `{ ok }`(soft delete) | 0 | `write_audit` | 404 |
| `POST /api/books/[id]/restore` | owner/admin / F | - | `{ book }` | 0 | - | 409 `PB001`(복구 시 쿼터 재검사) |
| `POST /api/books/[id]/titles` | member+ / F | `{ request_id, direction? }` | `{ candidates: [{title, subtitle, reason}] }` | 1 | `consume/refund_credits` | 402, 502 `llm_failed` |
| `POST /api/books/[id]/plans` | member+ / F | `{ request_id, target_reader?, emphasis_tone? }` | `{ plans: [3] }` | 2 | 같음 | 402, 502 |
| `POST /api/books/[id]/toc` | member+ / F | `{ request_id, chapters 1..20, sections_per_chapter 1..10, paragraphs 1..5 }` | `{ tocs: [3] }`(저장 안 함) | 2 | 같음 | 402, 403 `plan_limit`(설정값이 플랜 초과) |
| `PUT /api/books/[id]/structure` | member+ / F | `{ chapters: [{ id?, title, sections: [{ id?, title, paragraph_target }] }] }` | `{ chapters }` | 0 | - | 409 `PB002~PB004`, `PB005`(생성 중 섹션 삭제) |
| `POST /api/books/[id]/sections/[sid]/generate` | member+ / F(quality는 B) | `{ request_id, mode:'fast'\|'quality', overwrite?:bool }` | SSE `delta`, `done{ section }`. 본문이 있는 소제목에 `overwrite=true`면 저장하지 않고 `done{ suggestion }`(Diff, 2026-10-14) | 1/2 | 같음 | 402, 403, 409 `PB005`, 409 `generation_active` |
| `POST /api/books/[id]/assist` | member+ / B `writing_assist` | `{ request_id, section_id, action:'continue'\|'expand'\|'refine'\|'custom', selection_text ≤ 2000, instruction? ≤ 500 }` | SSE, `done{ suggestion }`(저장 안 함, Diff 적용은 클라이언트가 PATCH) | 1 | 같음 | 402, 403, 422 |
| `PATCH /api/books/[id]/sections/[sid]` | member+ / F | `{ title?, body_html?, paragraph_target?, revision }` | `{ section }` | 0 | - | 409 `stale_revision`, `PB005` |
| `POST /api/books/[id]/write-all` | member+ / B `write_all` | `{ request_id, mode, overwrite: bool, section_ids?, chapter_ids? }`(`overwrite`는 본문이 있는 소제목도 대상에 넣되 결과는 제안으로만 돌려준다) | `{ run, estimated_credits }` | 소제목별 2/4(그래프 초안, 01장 4.6절. 챕터 단위 자식 잡) | `enqueue_job` | 402(예상치 부족), 409 `generation_active` |
| `POST /api/books/[id]/refine-all` | member+ / B `writing_assist` | `{ request_id, mode }` | `{ run, chunks }` | 청크별 | `enqueue_job` | 402, 409 |
| `POST /api/generation-runs/[id]/cancel` | member+ / F | - | `{ run }` | 0(대기분 환불) | `publishing.request_generation_cancel` | 409 `PB007` |
| `POST /api/books/[id]/covers` | member+ / F | `{ request_id, style, bg_color?, font_style? }` | `{ covers: [3], job_id }` | 6 | `consume_credits`, `enqueue_job` | 402 |
| `POST /api/books/[id]/metadata` | member+ / F | `{ request_id }` | `{ book_info }`(저장 전 제안) | 1 | `consume/refund_credits` | 409 `manuscript_empty` |
| `GET /api/books/[id]/preview` | 멤버 / F | `?pages=1..10` | `text/html`(sandbox iframe용) | 0 | - | 429 |
| `POST /api/books/[id]/exports` | member+ / F | `{ request_id, format:'pdf'\|'epub', options:{ toc:bool, running_header:bool, ai_notice:bool } }` | `{ export, reused: bool }` | PDF 2 / ePub 1 / 재사용 0 | `consume_credits`, `enqueue_job` | 402, 403 `plan_limit`(월 한도), 409 `manuscript_empty` |
| `GET /api/exports/[id]/download` | 멤버 / F | - | 302 → 서명 URL(7일) | 0 | - | 404, 410 `expired` |
| `POST /api/uploads` | member+ / B `upload` | `{ file_name, ext, bytes ≤ 20MB, rights_confirmed: true }` | `{ upload_id, signed_upload_url, token }` | 0 | - | 413, 415, 403 |
| `POST /api/uploads/[id]/complete` | member+ / B | - | `{ upload, job_id }` | 0 | `enqueue_job` | 413(실제 크기), 415(매직바이트) |
| `POST /api/uploads/[id]/create-book` | member+ / B | `{ format_key, genre? }` | `{ book }` | 0 | - | 409 `PB001~PB004`(초과분 목록 `details`) |
| `POST /api/seeds/[seed_key]/duplicate` | member+ / F | - | `{ book }` | 0 | - | 409 `PB001` |
| `POST /api/personas/blend` | member+ / B `persona_blend` | `{ request_id, name, base_persona_ids ≤ 3, sample_text ≤ 5000 }` | `{ persona }` | 3 | `consume/refund_credits` | 402, 403 |
| `PATCH /api/settings` | 본인 / F | `{ theme_key?, favorite_persona_ids?, llm_mode? }` | `{ settings }` | 0 | - | 409 `PB008` |
| `POST /api/billing/orders` | owner/admin | `{ kind:'credit_pack'\|'subscription', code }` | `{ orderId, amountKrw, customerKey, expiresAt }` | 0 | 서버 `payment_orders` INSERT | 403, 404 |
| `POST /api/billing/confirm` | owner/admin | `{ paymentKey, orderId, amount }` | `{ payment, balance }` | 지급 | Toss confirm → `confirm_payment_order` | 409 `PM001`(+ Toss 취소 요청), `PM409`, `PM410` |
| `POST /api/billing/billing-key` | owner/admin | `{ authKey }` | `{ card_masked, subscription }` | 0 | 빌링키 발급 → 첫 주문 → `confirm_payment_order` | 402 결제 실패 |
| `POST /api/billing/subscription/cancel` | owner/admin | - | `{ subscription }`(해지 예약) | 0 | `apply_subscription_transition` | 409 `SB001` |
| `POST /api/webhook-endpoints` | owner/admin / B `webhooks` | `{ url https, events[] }` | `{ endpoint, secret }`(비밀은 이번 응답에서만) | 0 | vault put | 422 `url_not_allowed`(사설 IP, localhost, 비 https), 409 5개 초과 |
| `DELETE /api/webhook-endpoints/[id]` | owner/admin | - | `{ ok }`(disabled + 비밀 revoke) | 0 | `revoke_credential` | 404 |
| `POST /api/webhook-endpoints/[id]/test` | owner/admin | - | `{ delivery }` | 0 | `enqueue_job` | 429 |
| `POST /api/account/delete` | owner | `{ confirm_text: '삭제합니다' }` | `{ purge_at }` | 0 | 서버 조직 soft delete + 감사 | 422 |
| `POST /api/waitlist` | 공개 | `{ email, consent_marketing }` | `{ ok }` | 0 | `rate_limit_hit` | 429 |
| `GET /api/waitlist/count` | 공개 | - | `{ count }`(실제 행 수) | 0 | - | - |
| `POST /api/webhooks/toss` | 공개(서명) | raw body | 200 | - | `webhook_events` | 401 서명, 200 중복 |
| `POST /api/webhooks/fal` | 공개(검증) | raw body | 200 | - | `webhook_events` | 401, 200 중복 |
| `POST /api/admin/credits/adjust` | platform_admin | `{ org_id, amount, reason ≥ 10자 }` | `{ ledger }` | 조정 | `grant_credits` 또는 코어 adjust(요청 중, 06장 6절) + `audit_log` | 403 |
| `POST /api/books/[id]/visibility` (Phase 2) | owner/admin / B `public_page` | `{ is_public, slug? }` | `{ book }` | 0 | `publishing.set_book_visibility` | 409 `PB009`, 409 `slug_taken` |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다. 플랜 열의 `ai_chat` 등은 01장 4.4절 features 키다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, `write_audit('ai.consent.cross_border')`(service_role) | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `PUT /api/books/[id]/ai-privacy` | member+ | `{ open_source_only: boolean }` | `{ book }` | 0 | 없음 | `books.book_info.ai_open_source_only` 병합 UPDATE(세션 클라이언트, RLS), `write_audit('book.ai_privacy')` | 404 |
| `GET /api/books/[id]/references` | 멤버 / `book_wiki` | - | `[{ document_id, name, status, chunks, contains_pii }]` | 0 | 없음 | 책 컬렉션의 `ai_documents`(service_role, `ctx.org.id` 확인) | 404 |
| `POST /api/books/[id]/references` | member+ / `rag_files_max` | `{ file_name, ext(txt\|md\|docx\|pdf), bytes ≤ 20MB, rights_confirmed: true, contains_pii: boolean, request_id }` | `{ upload_id, signed_upload_url, token }` | 색인 예상치 표시, 차감은 색인 잡 enqueue 때 | 없음 | `manuscript_uploads` INSERT(service_role, `book_id` 설정), 완료는 `POST /api/uploads/[id]/complete`(기존). 파싱 결과 md가 만들어지면 `publishing.ai_index` enqueue + `consume_credits('rag:<document_id>')` | 403 `plan_limit`, 413, 415 |
| `DELETE /api/books/[id]/references/[document_id]` | member+ | - | 204 | 0 | `rag` | 문서·청크 삭제(FastAPI), 감사 `reference.delete` | 404 |
| `POST /api/books/[id]/wiki/ingest` | member+ / `book_wiki` | `{ request_id, document_ids?: uuid[] }` | `{ run_id }` | 선차감 3, 정산 1~10 | FastAPI `/wiki/ingest`(scope `wiki`, `org`=세션 조직) | `consume_credits('run:<ai_run_id>')`, `enqueue_job('publishing.wiki_ingest')` | 402, 409 진행 중, 403 |
| `POST /api/books/[id]/wiki/lint` | member+ / `book_wiki` | `{ request_id }` | `{ run_id }` | 2 | FastAPI `/wiki/lint`(scope `wiki`) | 같음 | 402, 409 |
| `GET /api/books/[id]/wiki/pages?status=` | 멤버 / `book_wiki` | slug 접두사 `books/<id>/`로 고정(서버가 책 소유 확인 뒤 조회) | `[{ slug, title, status, page_type, version, last_editor, stale_since }]` | 0 | 없음. `core.wiki_pages`·`wiki_revisions` RLS SELECT(조직 구성원, `0008_core_ai.sql:604-632`)를 세션 클라이언트로 읽는다 | - | 404 |
| `GET /api/books/[id]/wiki/pages/[...slug]` | 멤버 / `book_wiki` | - | 페이지(본문, 출처, 관련, 이력 요약) | 0 | 위와 같음 | - | 404 |
| `PATCH /api/books/[id]/wiki/pages/[...slug]` | member+ / `book_wiki` | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 코어 요청 R14) | 감사 `wiki.publish`/`wiki.edit` | 409 `WIKI_NO_SOURCE`(출처 없는 페이지 채택), 409 `WIKI_VERSION_CONFLICT`, 404 |
| `POST /api/ai/conversations` | 로그인 / `ai_chat` | `{ book_id?: uuid, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `book_id`는 같은 조직의 삭제되지 않은 책만 | 404 책, 403 엔타이틀먼트·플랜 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000), book_id? }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `book_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/voice/consent` | 로그인 | `{ notice_version }` | 204 | 0 | - | `write_audit('voice.notice_ack', { version })` | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | 로그인 / `voice_dictation` | `{ conversation_id?: uuid, book_id? }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT(받아쓰기는 `conversation_id` 없이) | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하), session_id, request_id, purpose: 'dictation'\|'chat', book_id?, segment_seconds ≤ 120(chat은 60) }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'publishing', purpose==='dictation' ? 'publishing.dictation' : 'voice_chat','stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`). `book_id`의 오픈소스 전용 스위치가 켜져 있으면 오픈소스만 | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/voice/narrations` | member+ / `narration` | `{ book_id, scope: 'section'\|'chapter', scope_id, request_id }` | NDJSON `{ step: 'part', n, total }` ... `{ done: true, url, expires_at }`. 같은 본문 해시 파일이 있으면 200 `{ url, expires_at }` | 본문 글자 수 × 단가 선차감, 실제 정산 | `narration`/`tts` 체인에서 시작 제공자 1개 고정, 대체 금지(scope `voice`) | `voice_jobs`(feature `narration`), Storage `exports/<org_id>/publishing/narration/<book_id>/<scope_id>-<content_hash>.mp3`(경로가 DB 정본, `voice_jobs.storage_path`는 `store_audio=false`라 비운다), `consume_credits`/`refund_credits`, `rate_limit_hit('publishing:narration:<org>', 5, 3600)` | 403 `plan_required`, 409 `manuscript_empty`, 413 `NARRATION_TOO_LONG`(8,000자 초과), 402, 429, 502 `NARRATION_FAILED`(환불됨) |
| `GET /api/voice/narrations/[scope_id]?book_id=` | 멤버 | - | `{ url, expires_at, provider }`(7일 서명 URL) | 0 | - | Storage 목록 조회 + `rate_limit_hit('publishing:download:<org>', 60, 3600)` | 404 |
| `POST /api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 발급만: `core.jobs` 행의 `org_id`·`created_by`로 scope 결정 — `publishing.write_section`은 `graph:publishing.draft`, `publishing.refine_chunk`·`publishing.cover_generate`는 `graph:publishing.assist` | `core.jobs` 조회(`status='running'`, `app_id='publishing'`, 허용 `job_type` 목록) | 401 `INTERNAL_KEY_INVALID`, 409 잡 상태, 429 |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 |

단건 생성 Route Handler(`titles`, `plans`, `toc`, `sections/[sid]/generate`, `assist`, `metadata`, `personas/blend`)는 위 표 2절의 계약을 그대로 두고 내부 호출만 `publishing.assist` 그래프(`POST /graphs/publishing.assist/runs`, 사용자 세션에서 발급한 서명 토큰 scope `graph:publishing.assist`)로 바꾼다. 스트리밍 응답은 그래프 SSE가 지원되면 중계하고, 아니면 `GET /graphs/runs/{id}`로 받은 완성본을 SSE로 흘려보낸다(01장 D13).

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`).

엔진 내부(공개 인터넷에서 호출 불가, `X-Internal-Token`):

| 메서드 경로 | 호출자 | 입력 | 출력 |
|---|---|---|---|
| `GET /health` | 플랫폼 | - | `{ ok, fonts_ok, render_ok }` |
| `POST /internal/preview` | web | `{ org_id, book_id, pages ≤ 10 }` | sanitize된 HTML |
| `POST /internal/content-hash` | web | `{ org_id, book_id, format, options }` | `{ content_hash }`(재사용 판정용) |

## 3. RPC (SECURITY DEFINER)

제품 스키마 함수. 코어 RPC(`consume_credits`, `grant_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `confirm_payment_order`, `apply_subscription_transition`, `write_audit`, `rate_limit_hit`, `session_context`)는 CS 4~12장 그대로.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `publishing.request_generation_cancel(p_run_id uuid)` | authenticated, service_role | `is_service_caller()` 아니면 `has_org_role(org, owner/admin/member)`. 상태 queued/running. 감사 `generation_run.cancel_request` | `publishing.generation_runs` | `P0002`, `42501`, `PB007` |
| `publishing.set_book_visibility(p_book_id uuid, p_is_public boolean, p_slug text default null)` | authenticated, service_role | `is_service_caller()` 아니면 `has_org_role(org, owner/admin)`, 엔타이틀먼트, 공개 시 `status='completed'` + `features.public_page` + slug 형식. 감사 `book.publish_page`/`book.unpublish_page` | `publishing.books` | `P0002`, `42501`, `PB009`, `22023`, `23505` |
| `publishing.decide_agent_task(p_task_id uuid, p_decision text, p_note text default null)`(2026-10-14) | authenticated, service_role | `p_decision` ∈ approved, partially_applied, rejected. `is_service_caller()` 아니면 `has_org_role(org, owner/admin/member)` + 엔타이틀먼트. `approval_status='pending'`만. 메모 500자. 감사 `agent_task.decide` | `publishing.agent_tasks` | `P0002`, `42501`, `PB012`, `22023` |
| `publishing.book_plan_limit(p_org_id uuid, p_key text, p_default integer)` | authenticated, service_role | 비멤버면 기본값만 반환(타 조직 플랜 비노출) | integer(-1 무제한) | - |
| `publishing.book_plan_flag(p_org_id uuid, p_key text, p_default boolean)` | 위와 같음 | 위와 같음 | boolean | - |
| `publishing.book_theme_allowed(p_org_id uuid, p_theme_key text)` | 위와 같음 | 위와 같음 | boolean | - |

AI·음성 코어 RPC 인용(제품 AI RPC는 새로 만들지 않는다): `set_ai_cross_border_ack`(사용자 세션, owner, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575`), `resolve_ai_route`(service_role: FastAPI, Next.js 음성, `:419-476`), `match_ai_chunks`(FastAPI만, `:369-412`), `purge_wiki_page`(책 영구 삭제·개인정보 삭제 요청, `:578-601`). `set_ai_routing`(`:483-550`)은 제품 화면에서 부르지 않는다. 녹음을 저장하지 않으므로 `expire_voice_audio`는 쓰지 않는다.

모두 `set search_path = ''`, `revoke execute ... from public, anon`(`_supabase-modular/migrations/1000_publishing.sql` 0절, 12절). 사용자용 RPC 안에서 크레딧을 차감하지 않는다(`DB_CONVENTIONS.md` 11장).

## 4. 잡 페이로드 계약

공통: 비밀값을 넣지 않는다. 경로는 서버가 만든 Storage 경로만. 2026-10-14부터 작업형 잡(`write_section`, `write_all`, `refine_all`, `cover_generate`, `render.pdf`, `export_epub`, `ai_index`, `wiki_ingest`, `wiki_lint`)의 페이로드에 선택 필드 `agent_task_id: uuid`를 더한다. 잡을 끝내는 쪽이 이 id로 `publishing.agent_tasks`를 갱신한다(02장 10.2절). 자식 잡은 부모의 id를 물려받고 부모(또는 단독 잡)만 행을 끝낸다. `progress`는 0~100, `progress_message`는 한국어 한 줄.

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `publishing.write_section` | `{ book_id, chapter_id, section_ids: uuid[](같은 챕터, 1~10), run_id?, mode, overwrite, omnibus: bool }`(페르소나·어조는 서버가 DB에서 합성, 페이로드에 넣지 않는다) | `{ saved: uuid[], suggested: uuid[], failed: uuid[], char_count, ai_run_id: uuid, notes: [{ section_id, kind, message }] }` | "개요 만드는 중" → "초안 쓰는 중 2/5" → "설정집과 맞춰 보는 중" → "교정 중"(`ai_run_steps`에서 계산) |
| `publishing.write_all` | `{ run_id, book_id, chapter_ids: uuid[], section_ids: uuid[], mode, overwrite, omnibus }`(챕터 순서대로 `publishing.write_section` 자식 잡 enqueue) | `{ done, failed, skipped, credits_used }` | "8/15 소제목 완료" |
| `publishing.refine_all` | `{ run_id, book_id, chunk_chars: 2000, mode }` | `{ chunks, suggestions_saved }` | "5/15 구간 다듬는 중" |
| `publishing.refine_chunk` | `{ run_id, book_id, section_id, offset, length, mode }` | `{ suggestion_html }`(자식 잡 `result`에만 저장, 원문 미변경. 클라이언트가 `core.jobs`를 RLS로 읽어 Diff 표시) | - |
| `publishing.cover_generate` | `{ book_id, cover_ids: uuid[3], style, prompt_vars: { title, genre, mood } }` | `{ succeeded: uuid[], failed: uuid[] }` | "표지 2/3 완료" |
| `publishing.parse_manuscript` | `{ upload_id, storage_path, ext }` | `{ chapters, sections, paragraphs, char_count }`(outline은 `manuscript_uploads.parsed_outline`) | "문서 구조 읽는 중" |
| `publishing.parse_reference` | `{ upload_id, document_id, storage_path, ext }`(`book_id`가 있는 업로드의 참고 파일. 정규화 md를 `<org>/publishing/rag/<uuid>.md`에 저장하고 `publishing.ai_index`를 enqueue) | `{ md_path, char_count }` | "참고 파일 읽는 중" |
| `render.pdf` | `{ export_id, book_id, preset: { page, width_mm, height_mm, margins_mm{top,right,bottom,left,inner_extra}, font_pt, line_height }, options: { watermark: bool, toc, running_header, ai_notice, cover_image_path? } }` | `{ storage_path, pages, bytes, duration_ms }` | "PDF 조판 중" |
| `publishing.export_epub` | `{ export_id, book_id, options: { ai_notice, cover_image_path? } }` | `{ storage_path, bytes, epubcheck_errors: 0 }` | "ePub 만드는 중" |
| `publishing.webhook_deliver` | `{ endpoint_id, event_id, event_type, data }` | `{ http_status, attempts }` | - |
| `publishing.purge` | `{ kind: 'books'\|'uploads'\|'exports'\|'narrations', before: timestamptz }`(`books`는 책 컬렉션·설정집 페이지도 삭제) | `{ deleted_rows, deleted_objects }` | - |
| `publishing.ai_index`(FastAPI) | `{ document_id: uuid, collection: 'book-<book_id>' }` | `{ chunks: int, embedding_provider, embedding_model }` | `chunking`, `embedding:<n>/<total>`, `done` |
| `publishing.wiki_ingest`(FastAPI) | `{ book_id, document_ids?: uuid[] }` | `{ created: int, updated: int, draft_slugs: string[] }` | `page:<n>/<total>` |
| `publishing.wiki_lint`(FastAPI) | `{ book_id }` | `{ contradictions, stale, orphans, broken_links, unsourced }`(각 slug 목록) | - |

그래프 실행 계약(워커 ↔ FastAPI, 잡 토큰):

```
// POST /graphs/publishing.draft/runs  (Authorization: Bearer <잡 토큰>)
{ "book_id": "uuid", "chapter_id": "uuid", "section_ids": ["uuid"], "mode": "fast|quality", "overwrite": false, "omnibus": false }
// 202
{ "run_id": "uuid", "status": "queued" }
// GET /graphs/runs/{run_id} 완료 시
{ "status": "succeeded",
  "output": { "sections": [ { "section_id": "uuid", "body_html": "...", "char_count": 2310,
                              "notes": [ { "kind": "consistency", "ref": "books/<id>/characters/seojin", "message": "..." } ] } ],
              "citations": [ { "type": "chunk", "id": 123 }, { "type": "wiki", "slug": "books/<id>/terms/..." } ] } }
// 실패 시 { "status": "failed", "error": "compliance_failed|provider_unavailable|book_not_found" }
```

`output.sections[].body_html`은 워커가 zod로 다시 검증하고 sanitize한 뒤 저장한다. 두 스키마는 `api/app/ai/products/publishing/schema/section.schema.json` 하나에서 생성한다(제안). 책 소유는 FastAPI가 `books.org_id = token.org`로 다시 확인한다.

렌더 서비스 계약은 SM 10장 `RenderPdfRequest`/`RenderPdfResponse`를 그대로 쓴다(`app_id: 'publishing'`). 이 제품이 소유자로서 정하는 세부:

| 항목 | 값 |
|---|---|
| 엔드포인트 | `POST /render/pdf`, `GET /health`(Noto CJK 확인), `X-Render-Token` 필수, 요청 본문 상한 20MB(제안) |
| url_fetcher | `RENDER_ALLOWED_ASSET_HOSTS`의 https 호스트만. `file://`, `data:` 외 스킴, 사설·링크로컬 IP, 리다이렉트 거부. 실패 시 이미지 생략이 아니라 렌더 실패(재시도 불가) |
| 시간 | 120초 타임아웃, 초과 시 프로세스 단위 강제 종료 |
| 동시성 | 컨테이너당 4(제안), 초과 요청 429 → 엔진이 재큐잉 |
| 출력 | Storage `exports/<org_id>/<app_id>/pdf/<uuid>.pdf` |

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 방식 | event_id 출처 | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태(취소, 가상계좌 입금) | Toss 웹훅 검증 방식(미확인, SM 6장) | `paymentKey + status + 발생시각` 해시(CS 6장) | `webhook_events` INSERT → 상태 동기화만. 지급은 confirm 경로 |
| 수신 | fal 완료 | fal 서명(미확인). 확인 전에는 `request_id`가 우리 잡 payload의 값과 일치하는지만 대조 | `request_id` | 이미지 Storage 복사 → `cover_images` 갱신 → 잡 complete/fail |
| 발신 | `book.completed` | HMAC-SHA256(`timestamp.rawBody`), `X-Signature`, `X-Timestamp`, 5분 허용 | `event_id` UUID | `webhook_deliveries` 멱등(`endpoint_id, event_id`) |
| 발신 | `export.succeeded` | 같음 | 같음 | 본문 `{ book_id, export_id, format, pages, download_url }`. 서명 URL 유효 24시간(제안: 외부 자동화가 받아 갈 시간) |
| 발신 | `export.failed` | 같음 | 같음 | 본문 `{ book_id, export_id, format, error_code }` |
| 수신 | AI·음성 | 해당 없음 | - | Dify, ElevenLabs, FastAPI는 웹훅을 쓰지 않는다(그래프 완료는 워커가 상태 조회, 낭독은 동기 스트림) |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| FastAPI AI 서비스(그래프) | web `publishing.assist` 호출, 워커 `write-section.ts` 등(잡 토큰) | 체인 대체(라우터) → 노드 재시도 → `failed` → 환불. mock 금지. 120초(assist)·300초(draft) 안에 끝나지 않으면 실패 + 환불 | 조직당 60회/분(제품 레이트 리밋). 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*` | 채팅·받아쓰기는 체인 다음으로 대체(`voice_jobs.fallback_from`), 낭독은 대체 없이 실패 + 환불 | 요금·상업 이용 조건 구현 시 확인 |
| 오픈소스 음성 서버 | `src/app/api/voice/*`(서명 토큰 scope `voice`) | 같음 | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). publishing은 구간 120초·낭독 구간 5,000자 이하로 나눈다 |
| fal | 공용 fal 클라이언트(TS 워커) | 제출 실패 즉시 환불, 30분 미도착 `fail_job` | 동시 3(책당 1회 생성) |
| Toss | 공용 toss 모듈(web, 정기결제 워커) | CS 5장. `PM001`은 운영 알림 + 승인 취소 요청 | - |
| WeasyPrint 렌더 서비스 | 엔진 | 4절 | 동시 4/컨테이너 |
| Supabase Storage | web(서명 URL), 엔진·워커(service_role) | 업로드 완료 검증 실패 시 객체 삭제 | 버킷 상한(org-files 50MB, exports 200MB) |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 publishing이 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | publishing 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R14). 조직 데이터·원고 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `book`: `book_id`가 매핑 org의 책인지 확인 → 원고·채택된 설정집·참고 파일 검색 → `chat` 모델. 모드 `craft`: 책 근거 없이 일반 글쓰기 상담. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | web(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /graphs/publishing.draft/runs`, `POST /graphs/publishing.assist/runs`, `GET /graphs/runs/{id}` | 워커(draft, 잡 토큰), web(assist, 사용자 토큰) | scope `graph:<name>`, `jti` 1회 | 4절 계약 |
| `POST /rag/ingest` | web | 서명 토큰 scope `rag` | 참고 파일·원고 색인(컬렉션 `book-<book_id>`) |
| `POST /wiki/ingest`, `POST /wiki/lint`, 페이지 저장(사람 편집, R14) | web | 서명 토큰 scope `wiki` | 책 설정집. 읽기(목록·페이지)는 RLS로 직접 하므로 `GET /wiki/pages/{slug}`는 쓰지 않는다 |

쓰지 않는 것: `POST /dify/retrieval`(외부 지식을 쓰지 않는다), `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(web이 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`publishing-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `publishing-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_PUBLISHING`(web 서버 전용). 정의는 `infra/dify/publishing-chat.yml`(키 없음) |
| 호출 | web `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `book_id`(선택, UUID 문자열, 대화 시작 때만). 서명 토큰, org, 원고 본문, 이름은 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `book`(`book_id`가 있을 때): HTTP 요청 노드 → 답변 / 분기 `craft`: HTTP 요청 노드(모드 `craft`) → 답변. 외부 지식·내장 지식베이스 노드는 없다 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, book_id, mode: "book"\|"craft" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type: "chunk"\|"wiki"\|"section", id or slug, title }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다(01장 5절) |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP | 발생 위치 |
|---|---|---|---|
| `PB001` | 책 수 한도 | 409 | `books` INSERT 트리거 |
| `PB002` | 챕터 수 한도 | 409 | `chapters` 트리거 |
| `PB003` | 소제목 합계 한도 | 409 | `sections` 트리거 |
| `PB004` | 단락 목표 한도 | 409 | `sections` 트리거 |
| `PB005` | 생성 중인 섹션 편집 | 409 | `sections` 트리거 |
| `PB006` | 다른 책 또는 미완료 표지 선택 | 409 | `books` 트리거 |
| `PB007` | 취소할 수 없는 실행 상태 | 409 | `request_generation_cancel` |
| `PB008` | 플랜에 없는 테마 | 409 | `member_settings` 트리거 |
| `PB009` | 공개 조건 미충족 | 409 | `set_book_visibility` |
| `PB010` | 삭제한 책의 직접 복구 | 409 | `books` 트리거(복구는 서버 API) |
| `PB011` | 집필 시작 후 페르소나 변경 | 409 | `books` 트리거 |
| `PB012` | 검수 대기가 아닌 작업에 결정(2026-10-14) | 409 | `decide_agent_task` |
| `PB013` | 끝나지 않았거나 재시도할 수 없는 작업의 재시도(2026-10-14) | 409 | `agent_tasks` INSERT 트리거 |
| `22023` | 상태 전이 위반, 인자 오류 | 409 | 전이 트리거 |
| `23505` | 중복(진행 중 실행, slug) | 409 | 유니크 인덱스 |
| `23503` | 다른 조직·책 행 참조 | 422 | 복합 FK |
| 코어 코드 | `42501` 403, `CR001` 402, `P0002`/`PM404` 404, `PM001`/`PM409` 409 + 알림, `JB002` 409 | - | CS 15장 매핑 |
| 앱 코드 | `plan_required` 403, `plan_limit` 403, `llm_failed` 502, `render_failed` 502, `manuscript_empty` 409, `stale_revision` 409, `generation_active` 409, `url_not_allowed` 422, `expired` 410 | - | Route Handler |
| AI 코어 코드 | `AI001`(플랫폼이 강제한 오픈소스 범위를 해제하려 함, 운영 도구에서만 발생) 403, `AI002`(국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함, 제품 화면은 `set_ai_routing`을 부르지 않는다) 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" | - | 코어 `set_ai_routing` |
| AI 앱 코드 | `AI_UNAVAILABLE` 503(체인의 모든 제공자 실패, 선차감 환불 완료), `AI_CONVERSATION_CLOSED` 409(닫힌 대화 또는 대화당 50턴 초과), `AI_DAILY_LIMIT` 429, `CONSENT_VERSION_MISMATCH` 409, `INTERNAL_KEY_INVALID` 401(워커 키 또는 Dify 내부 키 불일치), `AI_OPEN_SOURCE_UNAVAILABLE` 503(오픈소스 전용 책에서 오픈소스 서버 실패, 환불 완료, 상용 대체 없음) | - | Route Handler |
| 음성 앱 코드 | `VOICE_CONSENT_REQUIRED` 403, `VOICE_TOO_LONG` 413, `NARRATION_TOO_LONG` 413, `NARRATION_FAILED` 502(중간 실패, 대체 없음, 환불 완료) | - | Route Handler |
| 에이전트·운영 앱 코드(2026-10-14) | `agent_unknown` 404(레지스트리에 없는 에이전트·동작), `agent_unavailable` 403(콘텐츠 에이전트 등 Phase 2), `retry_exists` 409(같은 작업 두 번째 재시도, 23505), `refund_missing` 409(원래 작업 실패분 환불 원장 없음), `manuscript_access_denied` 403(이용자 허용 없는 원고 열람, 01장 D27) | - | Route Handler |
| 위키 앱 코드 | `WIKI_VERSION_CONFLICT` 409(`expected_version` 불일치, `docs/products/_platform-core/LLM_WIKI.md:31`), `WIKI_NO_SOURCE` 409(출처 없는 페이지 채택) | - | Route Handler |
| FastAPI | `AI_TOKEN_INVALID` 401(서명, `aud`, scope, 만료, `jti` 재사용) | - | `api/` |

## 8. 인증 단계 경로 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절이다. 아래 경로만 단계(`AUTH_MODE`, 제공자 목록)를 읽는다(02장 9.2절). 로그인 뒤의 모든 API는 1절 원칙 그대로다.

| 메서드 경로 | 단계 | 입력 | 처리 | 출력 | 오류 |
|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | `{ persona: 'owner'\|'admin'\|'member'\|'viewer'\|'outsider'\|'no_app'\|'suspended'\|'ops'\|'basic', next?: string }`(zod, 목록 밖이면 422) | `isMockAuthAllowed()` 확인 → 쿠키 세션용 서버 클라이언트로 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('publishing', next)` | `{ ok: true, data: { redirect } }` + 세션 쿠키 | 판정 거짓이면 404(본문 없음, 존재를 숨긴다). 시드 계정 없음 401 + "`node scripts/dev/seed-users.mjs --app publishing`을 먼저 실행하세요". 레이트 리밋 대상 아님 |
| `GET /auth/callback` | B·C | `?code&next` | `exchangeCodeForSession`(PKCE, `@supabase/ssr` 서버 클라이언트) → `finishLogin`: `session_context('publishing')` 1회 → `entitled=false`면(open 앱) `rpc('bootstrap_app_for_org', { p_app_id: 'publishing' })` 1회 후 재조회(모놀리스는 무동작) → `status` 분기(pending → `/pending`, suspended → 403 `/suspended`) → `next` 화이트리스트(`/`로 시작, `//`·`@`·`\` 없음, 아니면 `/dashboard`, origin은 `APP_URL` 고정) → 감사 `auth.login`(provider, 첫 로그인 여부. 토큰·코드 미기록) | 302 | `code` 없음·재사용·만료 → `/login?error=callback`. 프로필 없음 → 로그아웃 후 `/login` |
| `GET /auth/naver/start` | C2 브리지 경로 채택 시만 | `?next&link?` | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분)에 넣고 네이버 authorize로 302. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 302 | 429 |
| `GET /auth/naver/callback` | C2 브리지 경로 채택 시만 | `?code&state` | 쿠키 state 상수 시간 비교 후 삭제 → 서버가 client secret으로 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(`provider='naver'`, `provider_user_id=response.id`) 조회 → 있으면 magiclink `generateLink` + `verifyOtp`로 세션, 없고 같은 이메일 사용자도 없으면 `auth.admin.createUser` + 링크 행 → `finishLogin`. 네이버 토큰은 저장하지 않는다 | 302 | state 불일치·없음·만료 → `/login?error=state`. 연결 없음 + 같은 이메일 사용자 있음 → `/login?error=email_in_use`(자동 연결 금지) |

`supabase_custom` 경로(C2 스파이크 성공)면 네이버도 `signInWithOAuth({ provider: 'custom:naver' })` → `GET /auth/callback`을 그대로 쓰고 위 두 브리지 경로는 만들지 않는다. 카카오(C1)는 `signInWithOAuth({ provider: 'kakao' })` → `GET /auth/callback`이다.

| 오류 코드(인증 단계) | HTTP·이동 | 발생 위치 |
|---|---|---|
| `error=callback` | `/login?error=callback` | `/auth/callback` 1단계 실패 |
| `error=state` | `/login?error=state` | `/auth/naver/callback`(브리지) |
| `error=email_in_use` | `/login?error=email_in_use` | `/auth/naver/callback`(브리지) |
| `dev_login_unavailable` | 404(본문 없음) | `/api/dev/login`, `isMockAuthAllowed()` 거짓 |
| `dev_seed_missing` | 401 | `/api/dev/login`, 시드 계정 없음 |
| `invalid_persona` | 422 | `/api/dev/login` zod |

## 9. 에이전트·운영 API (2026-10-14 FLORA 개편)

요구는 01장 3.1절, 설계는 02장 10절. 새 실행 엔진이 없으므로 "작업 시작"은 레지스트리가 기존 Route Handler의 처리 함수를 부르는 얇은 진입점이다. 기존 경로(2절)는 그대로 쓰며 `withAgentTask`로 감싸져 같은 `agent_tasks` 행을 만든다.

### 9.1 작가용

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어·제품 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/agents` | 멤버 / F | - | `{ agents: [{ key, name, description, actions: [{ key, label, unit_credits, feature, locked, approval }] }] }`(플랜 잠금은 서버 features로 계산) | 0 | - | - |
| `POST /api/agent-tasks` | member+ / 동작별 | `{ request_id, agent, action, book_id?, scope?: { chapter_ids?, section_ids?, selection? }, options?: { mode?, overwrite?, style?, format? } }` | 동기 동작: 기존 응답 + `{ task }`. 비동기: `{ task, job_id?, run_id? }`. 스트리밍 동작(`section_generate`, `assist_*`, `examples`, `style_check`, `source_check`)은 이 경로로 시작하지 않고 기존 SSE 경로를 쓴다(같은 행이 생긴다) | 레지스트리 단가(01장 4.3·4.6절) | 기존 처리와 같음 | 404 `agent_unknown`, 403 `agent_unavailable`·`plan_required`, 402, 409 `generation_active` |
| `GET /api/agent-tasks` | 멤버 / F | `?book_id&agent&status&approval=pending&cursor&limit≤50` | `{ items: [task], next }`(최근순) | 0 | - | - |
| `GET /api/agent-tasks/[id]` | 멤버 / F | - | `{ task, timeline: [{ at, kind: 'queued'\|'started'\|'step'\|'finished'\|'decided', label, detail? }], review?: { items: [{ section_id, kind: 'suggestion'\|'ai_draft'\|'note', title, before_html?, after_html?, note? }] }, credits: { estimated, used, refunded } }`. `review`는 검수 대기일 때만, 본문은 같은 조직 멤버에게만(RLS 세션으로 읽는다) | 0 | - | 404 |
| `POST /api/agent-tasks/[id]/cancel` | member+ / F | - | `{ task }` | 0(대기분 환불) | `request_generation_cancel`(실행 단위 작업) 또는 `cancel_job` | 409 `PB007`, 409(동기 작업은 취소 없음) |
| `POST /api/agent-tasks/[id]/retry` | member+ / 동작별 | `{ request_id }` | `{ task }`(새 행, `retry_of`, `attempt+1`, 범위는 02장 10.4절: 실패분, 취소면 남은 것까지) | 재시도 범위만 새로 차감 | 기존 처리 | 409 `PB013`, 409 `retry_exists`, 409 `refund_missing`, 402 |
| `POST /api/agent-tasks/[id]/decision` | member+ / F | `{ decision: 'approved'\|'partially_applied'\|'rejected', applied_section_ids?: uuid[], approved_draft_ids?: uuid[], rejected_draft_ids?: uuid[], note? ≤ 500 }`. 제안 반영은 클라이언트가 먼저 `PATCH sections`(revision)로 하고 서버가 `applied_section_ids`의 revision 상승을 확인한다. 빈 소제목 AI 초안은 서버가 승인분 `gen_status='edited'`, 거부분 본문 비움·`empty`로 바꾼다(`generated`인 것만). 그 뒤 결정 기록 | `{ task }` | 0 | `publishing.decide_agent_task` | 409 `PB012`, 409 `stale_revision`, 422(partially_applied인데 목록 없음) |

### 9.2 내부

| 메서드 경로 | 호출자 | 입력 | 동작 |
|---|---|---|---|
| `POST /api/internal/agent-sync` | 워커 크론 5분(워커 키 `PUBLISHING_WORKER_INTERNAL_KEY`) | - | 잡이 끝났는데 `running`인 행 마감, 15분 넘은 `queued`(잡 없음) → 연결 차감 중 환불 없는 것 환불 후 `failed`, 30일 지난 `pending` → `expired`. 처리 수 반환. 레이트 리밋 20회/시간 |

### 9.3 운영 콘솔 (`platform_admin`, 모두 service_role 서버 조회, 조회마다 감사 `admin.view`)

| 메서드 경로 | 입력 | 출력 | 오류 |
|---|---|---|---|
| `GET /api/admin/overview` | `?from&to` | `{ users, active_tasks, ai_cost_krw, failed_tasks, alerts: [...], recent: [...] }`(값이 없으면 null) | 404(비운영자) |
| `GET /api/admin/tasks` | `?status&agent&org_id&from&to&cursor` | `{ items, next }` | - |
| `GET /api/admin/trace/[id]` | `id` = agent_task id 또는 job id | `{ request, jobs, ai_runs: [{ graph, status, steps }], usage: [{ provider, model, calls, cost_usd_micros, fallback }], results: { saved, suggested, failed }, ledger: [{ entry_type, amount, refund_of }] }`(본문·프롬프트·토큰 값 없음) | 404 |
| `POST /api/admin/tasks/[id]/retry` | `{ request_id, reason ≥ 10자 }` | `{ task }`(`origin='admin_retry'`) | 409 `refund_missing`, `retry_exists`, `PB013` |
| `GET /api/admin/agents` | `?from&to` | `{ rows: [{ agent, action, runs, success_rate, p95_ms, top_errors: [{ code, count }] }] }` | - |
| `GET /api/admin/costs` | `?from&to&group_by=model\|agent\|org\|feature` | `{ rows: [{ key, calls, cost_usd_micros, cost_krw, credits_consumed, margin }] }`. `group_by=agent`는 작업 없는 채팅·음성을 `conversational` 행으로 둔다(합계 = 전체 `ai_usage`) | - |
| `GET /api/admin/users`, `POST /api/admin/users/[id]/status` | `{ status: 'active'\|'suspended', reason ≥ 10자 }` | `{ profile }` + 감사 | 409(자기 자신 정지) |
| `GET /api/admin/books` | `?status&org_id&export_failed=bool` | 본문 제외 컬럼 | - |
| `POST /api/admin/books/[id]/manuscript-view` | `{ reason ≥ 10자 }` | 이용자가 허용한 경우만 10분 서명 미리보기 URL + 감사 `admin.manuscript_view` | 403 `manuscript_access_denied` |
| `GET /api/admin/settings` | - | 라우팅 기본값, 플랜 features(읽기 전용) | - |
| `GET /api/admin/audit` | `?action&org_id&from&to&cursor` | `{ items, next }` | - |
| `POST /api/admin/credits/adjust` | 2절 그대로 | | |
