# 04 API: 신비로운AI

모든 Route Handler는 `apps/astro-ai/src/app/api/` 아래, `runtime = 'nodejs'`다(Edge 금지, 02장 6절 FD #6). 코어 RPC 시그니처는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 진입부 `requireSession('astro')`(`docs/products/_platform-core/SHARED_MODULES.md:79-81`). 미로그인 401, pending/suspended 403, 엔타이틀먼트 없음 402. 어드민은 `platform_role='platform_admin'` 아니면 403. 세션은 모든 인증 단계(A Mock, B Google + 이메일, C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(8절) |
| 조직 | 요청 본문의 `org_id`를 받지 않는다. 세션의 개인 조직(`ctx.org.id`)만 쓴다 |
| 멱등 | 쓰기 요청은 클라이언트가 만든 UUID `request_id`를 보낸다. 차감 키 `consume:astro:<request_id>`, 잡 키 `job:astro:<request_id>`, 테이블 `request_id` 유일 |
| 크레딧 선차감 위치 | 리딩은 `POST /api/readings`, `POST /api/readings/[id]/renders`의 Route Handler만. AI·음성은 `POST /api/ai/chat`, `POST /api/voice/stt`·`tts`·`narrations`(2.1절)와 정산 크론만. 사용자 RPC 안에서는 차감하지 않는다 |
| 검증 | 모든 입력은 zod. 알 수 없는 키 거부(`strict()`) |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. `code`는 7장 |
| 레이트 리밋 | `core.rate_limit_hit` 키 `astro:<route>:<org_id 또는 ip_hash>`. 초과 429 + `Retry-After` |
| 쓰기 경로 | service_role(`createAdminClient`)은 권한 확인 뒤에만 사용. 사용자 세션 클라이언트로 쓸 수 있는 것은 `preferences`, `rpc('cancel_reading')`, `rpc('set_ai_cross_border_ack')`(owner, `ack_by` 기록용)뿐 |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler가 부른다(`docs/products/_platform-core/SECURITY_BASELINE.md:299`) |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT를 발급: `iss=astro`, `aud=platform-ai:astro`, `org`, `app=astro`, `sub`(사용자 id), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 세션 또는 잡 행에서만 가져온다(`docs/products/_platform-core/AI_ARCHITECTURE.md:33-42`) |
| AI 멱등 키 | 채팅 `conv:<id>:turn:<n>`(n은 서버가 센 턴 번호. 같은 `request_id` 재전송은 `astro:ai-req:<request_id>` 버킷 1회로 막는다), 음성 `voice:<voice_job_id>`(클라이언트 `request_id`를 `voice_jobs.id`로 쓴다), 리딩 `consume:astro:<request_id>`(기존) |
| AI 선차감·정산 | 선차감은 제공자 호출 전 Route Handler에서, 정산은 응답 종료 직후 같은 Route Handler에서. 연결이 끊기면 `/api/internal/ai-settle`(워커가 5분마다 호출)이 처리 |
| 스트리밍 | 채팅은 SSE(`text/event-stream`), 낭독 진행은 NDJSON 스트림 |
| AI 레이트 리밋 | `astro:ai-chat:<user>` 20회/60초, `astro:ai-chat-day:<user>` 200회/86400초, `astro:voice-stt:<user>` 10회/60초, `astro:narration:<org>` 5회/3600초, `astro:ai-token:worker` 120회/60초(01장 5절) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/auth/welcome` | 로그인(이메일 인증 완료 또는 Google 확인, C단계부터 카카오·네이버 확인 포함) | 없음 | `{ granted: boolean, balance }` | +30(1회) | `grant_credits(org, features.welcome_credits, 'astro', 'welcome_credits', 'pack', 'signup', user_id, 'signup:<org>:astro')`, `rate_limit_hit('astro:signup:<ip_hash>', 3, 86400)` | 이메일 미인증 409, 보류 429 |
| `GET /api/subjects` | owner | - | `[{ id, alias, relation, gender, day_pillar, birth_summary }]`(복호화 요약) | 0 | - | - |
| `POST /api/subjects` | owner | `{ request_id, alias(1..20), relation, gender, birth_date, birth_time?, birth_time_unknown, calendar_type, is_leap_month, zi_hour_mode, birth_place_code?, real_name?, third_party_consent?: true, consent_version }` | `{ id }` | 0 | `write_audit('subject.create')` | 400 동의 누락, 409 상한(`max_subjects`)/본인 중복, 422 존재하지 않는 음력일 |
| `GET /api/subjects/[id]` | owner | - | 복호화된 입력 + 원국(`chart`) | 0 | - | 404 |
| `GET /api/subjects/[id]/chart` | owner | - | 엔진 결과(4주, 오행, 십신, 대운) | 0 | - | 404 |
| `PATCH /api/subjects/[id]` | owner | `POST` 필드 부분 | `{ id }` | 0 | `write_audit('subject.update')` | 404, 409(진행 중 리딩) |
| `DELETE /api/subjects/[id]` | owner/admin | `{ confirm_alias }` | 204 | 0 | `write_audit('subject.delete')`; 파일 삭제 실패분은 `enqueue_job('astro.storage.purge')` | 409 진행 중 리딩, 422 호칭 불일치 |
| `POST /api/readings` | owner, `features.readings` | `{ request_id, kind: saju\|tarot\|combined, subject_id?, tarot_cards?: [{card 0..21, reversed, position: past\|present\|future}] x3, question?(≤200), theme_key }` | 202 `{ reading_id, status }` / 같은 `request_id` 재요청 200 | 15/20/30 | `rate_limit_hit('astro:readings:<org>', 10, 60)`, `consume_credits`, `enqueue_job`, 실패 시 `refund_credits` | 402 `CR001`, 403 종류·테마 불허, 409 진행 중 3건, 422 카드 중복 |
| `GET /api/readings/[id]` | owner | - | 리딩 + 현재 렌더 + 발송 상태 | 0 | - | 404 |
| `POST /api/readings/[id]/cancel` | owner | - | 리딩 | 환불 | 사용자 세션 `rpc('cancel_reading')` | 409 `AS002`/`JB002` |
| `POST /api/readings/[id]/renders` | owner | `{ request_id, theme_key }` | 202 `{ render_id }` | 5 | `consume_credits('consume:astro:<request_id>')`, `enqueue_job('astro.render.regenerate')` | 409 리딩 미완료, 402 |
| `GET /api/readings/[id]/download?render=` | owner | render id(선택) | `{ url, expires_at }`(7일) | 0 | `rate_limit_hit('astro:download:<org>', 60, 3600)` | 404, 409 렌더 미완료 |
| `DELETE /api/readings/[id]` | owner/admin | - | 204 | 0 | `write_audit('reading.delete')` | 409 진행 중 |
| `POST /api/deliveries/[id]/resend` | owner | `{ email? }` | `{ status: 'pending' }` | 0 | `rate_limit_hit('astro:resend:<org>', 3, 86400)` | 409 상태가 dead/sent 아님 |
| `PATCH /api/consents` | owner | `{ marketing_email: boolean }` | 204 | 0 | - | - |
| `POST /api/demo/preview` | 비로그인 허용 | `{ birth_date, birth_time?, calendar_type, is_leap_month, gender }` | `{ pillars, keywords: string[3] }` | 0 | `rate_limit_hit('astro:demo:<ip_hash>', 3, 86400)` | 429. 입력 저장·로그 금지 |
| `POST /api/billing/orders` | owner | `{ credit_pack_code }` | `{ orderId, amount, customerKey, orderName }` | 0 | `payment_orders` INSERT(service_role, 금액은 `credit_packs`) | 404 |
| `POST /api/billing/confirm` | owner | `{ paymentKey, orderId, amount }` | `{ balance }` | +팩 | Toss confirm API → `confirm_payment_order` | 409 `PM001`(운영 알림 + Toss 취소, 별도 트랜잭션), `PM409`, `PM410`, 404 `PM404` |
| `POST /api/webhooks/toss` | 공개 | Toss 본문 | 200 | 0 | `webhook_events` | 401 서명 실패, 200 중복 |
| `GET /api/account/export` | owner | - | JSON(보관함 복호화 + 리딩 본문 + 결제 내역) | 0 | `write_audit('account.export')`, 일 1회 | 429 |
| `POST /api/account/delete` | owner | `{ confirm: '탈퇴' }` | 204 | 0 | 조직 `deleted_at` 설정(service_role), `write_audit('account.delete')`, 30일 뒤 `purge_organization` | 409 진행 중 리딩 |
| `GET /api/admin/users?q=` | platform_admin | 이메일/UID | 사용자, 잔액, 리딩 수 | 0 | - | 403 |
| `POST /api/admin/credits/grant` | platform_admin | `{ org_id, amount(1..10000), reason(≥5자), request_id }` | 원장 행 | +n | `grant_credits(..., 'admin_grant', 'pack', ..., 'admin:<request_id>')`, 감사 | 403 |
| `POST /api/admin/refunds` | platform_admin | `{ payment_key, amount, reason(≥5자) }` | 결제 | 조정 | Toss 취소 API → `payments` 갱신 → 미사용 크레딧 차감(코어 `adjust_credits` 요청 R-1 전까지는 `consume_credits(reason='refund_adjust')`) → 감사 | 403, 409 사용분 초과 |
| `GET /api/admin/deliveries?status=dead` | platform_admin | - | 목록 | 0 | - | 403 |
| `POST /api/admin/deliveries/[id]/retry` | platform_admin | - | `{ status }` | 0 | 감사 `delivery.retry` | 403 |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, `consents(overseas_transfer)` INSERT(service_role) | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/ai/conversations` | owner, `features.ai_chat` | `{ reading_id?: uuid, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `reading_id`는 같은 조직·`completed`만 | 404 리딩, 403 엔타이틀먼트·플랜 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000), reading_id? }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `reading_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/voice/consent` | owner | `{ notice_version }` | 204 | 0 | - | `consents(voice_processing)` INSERT | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | owner, `features.voice_chat` | `{ conversation_id }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, request_id }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'astro','voice_chat','stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/voice/narrations` | owner, `features.narration` | `{ reading_id, request_id }` | NDJSON `{ step: 'chapter', n, total }` ... `{ done: true, url, expires_at }`. 파일이 이미 있으면 200 `{ url, expires_at }` | 본문 글자 수 × 단가 선차감, 실제 정산 | `narration`/`tts` 체인에서 시작 제공자 1개 고정, 대체 금지(scope `voice`) | `voice_jobs`(feature `narration`), Storage `exports/<org_id>/astro/narration/<reading_id>.mp3`, `consume_credits`/`refund_credits`, `rate_limit_hit('astro:narration:<org>', 5, 3600)` | 409 `NARRATION_NOT_READY`, 402, 429, 502 `NARRATION_FAILED`(환불됨) |
| `GET /api/voice/narrations/[reading_id]` | owner | - | `{ url, expires_at, provider }`(7일 서명 URL) | 0 | - | `rate_limit_hit('astro:download:<org>', 60, 3600)` | 404 |
| `POST /api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 발급만: scope `graph:astro.reading`, `feat=astro.reading`, `org`·`sub`는 `core.jobs` 행의 `org_id`·`created_by` | `core.jobs` 조회(`status='running'`, `app_id='astro'`, `job_type='astro.reading.generate'`) | 401 `INTERNAL_KEY_INVALID`, 409 잡 상태, 429 |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 |
| `POST /api/admin/knowledge/documents` | platform_admin | multipart md(2MB 이하), `{ title }` | `{ document_id }` | 0(운영자 조직 사용량) | FastAPI `/rag/ingest`(scope `rag`, `org`=`ASTRO_KNOWLEDGE_ORG_ID`) | Storage 운영자 조직 폴더, 감사 `knowledge.upload` | 409 중복, 403 |
| `POST /api/admin/wiki/ingest`, `POST /api/admin/wiki/lint` | platform_admin | `{ document_ids?: uuid[] }` | `{ run_id }` | 0 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | - | 403 |
| `PATCH /api/admin/wiki/pages/[...slug]` | platform_admin | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 R-10) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`). 공개 위키는 서버 컴포넌트가 운영자 조직의 `published` 페이지를 service_role로 읽어 ISR로 그린다(사용자 입력이 쿼리에 들어가지 않는 slug 조회만).

## 3. RPC (SECURITY DEFINER)

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `astro.cancel_reading(p_reading_id uuid)` | authenticated | `is_service_caller()` 아니면 `has_org_role(org, owner/admin/member)` + `has_entitlement(org,'astro')`, 상태 queued. 내부에서 `core.cancel_job`(환불), `core.write_audit('reading.cancel')` | `astro.readings` | `P0002`, `42501`, `AS002`, `JB002` |
| `astro.claim_due_deliveries(p_worker_id text, p_limit int)` | service_role | `is_privileged_session()`(EXECUTE가 service_role 전용) | `setof astro.deliveries`(pending → sending, attempts+1, SKIP LOCKED) | `42501` |
| `astro.finish_delivery(p_delivery_id bigint, p_ok boolean, p_error text, p_provider_message_id text, p_retry_after_seconds int default 300)` | service_role | 상태 sending | `astro.deliveries`(sent / pending + 5분 / dead) | `42501`, `P0002`, `AS003` |

코어 RPC 인용: `consume_credits`, `grant_credits`, `refund_credits`(`docs/products/_platform-core/CORE_SPEC.md:157-165`), `confirm_payment_order`(`:215-226`), `enqueue_job` ~ `cancel_job`(`:285-300`), `rate_limit_hit`(`:341`), `write_audit`(`:330`).

AI·음성 코어 RPC 인용(제품 AI RPC는 새로 만들지 않는다): `set_ai_cross_border_ack`(사용자 세션, owner, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575`), `resolve_ai_route`(service_role: FastAPI, Next.js 음성, `:419-476`), `match_ai_chunks`(FastAPI만, `:369-412`), `purge_wiki_page`(운영 도구, `:578-601`). `set_ai_routing`(`:483-550`)은 제품 화면에서 부르지 않는다. 녹음을 저장하지 않으므로 `expire_voice_audio`는 쓰지 않는다.

## 4. 잡 페이로드 계약

| `job_type` | payload | result | progress 메시지 |
|---|---|---|---|
| `astro.reading.generate` | `{ reading_id: uuid, render_id: uuid, kind, chapter_plan: string[] }` (비밀값·평문 개인정보 없음. 워커가 DB에서 읽고 복호화) | `{ chapters: int, chars: int, pdf_path, pages, ai_run_id: uuid }`(사용량은 `core.ai_usage.run_id`로 조회) | `writing:<n>/<total>`(10~70%, 그래프 `ai_run_steps`에서 계산), `rendering`(80%), `done`(100%) |
| `astro.ai.rag_ingest`(FastAPI) | `{ document_id: uuid, collection: 'astro-knowledge' }` | `{ chunks: int, embedding_provider, embedding_model }` | `chunking`, `embedding:<n>/<total>`, `done` |
| `astro.ai.wiki_ingest`(FastAPI) | `{ document_ids: uuid[] }` | `{ created: int, updated: int, draft_slugs: string[] }` | `page:<n>/<total>` |
| `astro.ai.wiki_lint`(FastAPI) | `{}` | `{ contradictions, stale, orphans, broken_links, unsourced }`(각 slug 목록) | - |
| `astro.render.regenerate` | `{ reading_id, render_id, theme_key }` | `{ pdf_path, pages, bytes }` | `rendering`, `done` |
| `astro.storage.purge` | `{ bucket: 'exports', paths: string[] }`(모두 `<org_id>/astro/` 접두사, 워커가 검증) | `{ removed: int }` | - |

장 출력 스키마(zod, `packages/astro-report/schema`):

```ts
// 계약 예시
const Chapter = z.object({
  key: z.enum(['temperament','elements','work','relations','daeun','year','tarot_past','tarot_present','tarot_future','tarot_advice','bridge_1','bridge_2']),
  title: z.string().min(4).max(40),
  body: z.string().min(300).max(2500),   // {{호칭}} 토큰 포함, 수치 문장 금지
  highlights: z.array(z.string().max(60)).min(1).max(3),
})
// 리딩 단위 검증: 사주 본문 합 ≥ 2,500자, 통합 ≥ 4,000자, 타로 ≥ 2,000자, {{호칭}} ≥ 3회, 금지 표현 0
```

그래프 실행 계약(워커 ↔ FastAPI, 잡 토큰):

```
// POST /graphs/astro.reading/runs  (Authorization: Bearer <잡 토큰>)
{ "reading_id": "uuid", "job_id": "uuid" }
// 202
{ "run_id": "uuid", "status": "queued" }
// GET /graphs/runs/{run_id} 완료 시
{ "status": "succeeded",
  "output": { "chapters": [ /* 위 Chapter 스키마 */ ],
              "content_chars": 3120,
              "citations": [ { "type": "chunk", "id": 123 }, { "type": "wiki", "slug": "concepts/pyeonjae" } ],
              "engine_version": "1.0.0" } }
// 실패 시 { "status": "failed", "error": "compliance_failed|provider_unavailable|chart_invalid" }
```

FastAPI는 같은 Chapter 스키마를 pydantic으로 두고 워커가 zod로 다시 검증한다(두 스키마는 `packages/astro-report/schema/chapter.schema.json` 하나에서 생성, 제안).

렌더 서비스 요청은 공용 계약 `RenderPdfRequest`(`docs/products/_platform-core/SHARED_MODULES.md:278-285`)에 `app_id='astro'`, `preset.page='A4'`, 테마 CSS를 `html` 안 `<style>`로 넣는다. 외부 URL 참조는 없다(폰트는 렌더 컨테이너 로컬).

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태(취소, 부분취소) | 방식 미확인. 확인 전에는 수신 후 `paymentKey`로 Toss 결제 조회 API를 다시 호출해 상태를 재검증(`docs/reviews/Astro_AI.md:53`) | `paymentKey + status + 발생시각` 해시(`docs/products/_platform-core/CORE_SPEC.md:254`) | `payments.status` 동기화만. 크레딧 지급 없음 |
| 수신 | Resend 이벤트(bounce, complaint) | Resend 서명(svix, 미확인) | 이벤트 id | P1. dead 처리와 수신 거부 목록 |
| 발신 | 없음 | - | - | - |
| 수신 | AI·음성 | 해당 없음 | - | Dify, ElevenLabs, FastAPI는 웹훅을 쓰지 않는다(그래프 완료는 워커가 상태 조회, 낭독은 동기 스트림) |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터/비용 |
|---|---|---|---|
| FastAPI AI 서비스(그래프) | 워커 `generate.ts`(잡 토큰) | 체인 대체(라우터) → 장 재작성 1회(그래프) → `failed` → `fail_job` → 자동 환불. 120초 안에 끝나지 않으면 `fail_job` | 리딩당 `draft` 호출 4~8회. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*` | 채팅용은 체인 다음으로 대체(`voice_jobs.fallback_from`), 낭독은 대체 없이 실패 + 환불 | 요금·상업 이용 조건 구현 시 확인 |
| 오픈소스 음성 서버 | `src/app/api/voice/*`(서명 토큰 scope `voice`) | 같음 | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). astro는 60초·장 단위 |
| 렌더 서비스 | 워커 `generate.ts`, `render.ts` | 120초 타임아웃 → `fail_job(retryable=false)` | 내부 |
| Toss Payments | `api/billing/*`, `api/admin/refunds`, 웹훅 재조회 | confirm 실패 → 사용자 안내 + 운영 알림. 타임아웃 → 결제 조회 API로 재확인 후 판단 | - |
| Resend | 워커 `delivery/` | `finish_delivery(false)` → 5분 뒤 재시도, 3회 후 dead | 무료 한도 미확인 |
| KASI 특수천문정보 | `packages/saju-engine/scripts/verify-kasi`(CI 배치만) | 런타임 미사용 | 서비스 키 필요(미확인 한도) |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 astro가 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | astro 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류·용어 설명 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`, `wiki.query`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R-10). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `saju`: `reading_id`가 매핑 org의 리딩인지 확인 → 원국 스냅샷·관련 장 + 해설집·위키 검색 → `chat` 모델. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리(모드는 FastAPI가 분류) |
| `POST /dify/retrieval` | Dify 외부 지식 | 내부 키 | 운영자 조직의 `astro-knowledge`와 위키 컬렉션만. 사용자 조직 데이터 금지 |
| `POST /graphs/astro.reading/runs`, `GET /graphs/runs/{id}` | 워커 | 잡 토큰 scope `graph:astro.reading`, `jti` 1회 | 리딩 생성(4절 계약) |
| `POST /rag/ingest` | Next.js 관리자 | 서명 토큰 scope `rag`(org=운영자 지식 조직) | 해설집 색인 |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-10) | Next.js 관리자 | 서명 토큰 scope `wiki` | 위키 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`astro-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `astro-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_ASTRO`(Next.js 서버 전용). 정의는 `infra/dify/astro-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `reading_id`(선택, UUID 문자열, 대화 시작 때만). 서명 토큰, org, 이름, 생년월일은 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `saju`: HTTP 요청 노드 → 답변 / 분기 `term`: 지식 검색 노드(외부 지식 `astro-knowledge` → `/dify/retrieval`) → LLM 노드(model `wiki.query`) → 답변 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, reading_id, mode: "saju" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | `saju` 분기는 FastAPI가 `ai_messages.citations`를 기록하고, `term` 분기는 Next.js가 Dify 응답의 검색 출처 메타데이터로 기록한다 |
| 첫 표시 지연 | `saju` 분기는 HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다(01장 5절) |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| `AS001` | 상태 전이 위반 또는 불변 컬럼 변경(트리거) | 409(사용자 경로에서 나오면 버그로 운영 알림) |
| `AS002` | queued가 아닌 리딩 취소 | 409 |
| `AS003` | sending이 아닌 발송 완료 처리 | 409(워커 내부) |
| `CR001` | 크레딧 부족 | 402 + `{ balance, required }` |
| `CR002`, `CR003` | 환불 대상 오류, 환불 초과 | 500 + 운영 알림 |
| `JB002` | 이미 실행 중인 잡 취소 | 409 "이미 만들기 시작해 취소할 수 없습니다" |
| `PM001` | 결제 금액 불일치 | 409 + 운영 알림 + Toss 취소 |
| `PM404` / `PM409` / `PM410` | 주문 없음 / 다른 결제키 / 상태 불가 | 404 / 409 / 409 |
| `42501` | 권한 없음 | 403 |
| `P0002` | 대상 없음 | 404 |
| `22023`, `23514` | 인자·제약 위반 | 400 또는 422 |
| `23505` | 중복(본인 2명 등) | 409 |
| 앱 코드 `RATE_LIMITED` | 레이트 리밋 | 429 |
| 앱 코드 `ENTITLEMENT_REQUIRED` | 앱 미시작 | 402 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한 | 429 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 60초 또는 5MB 초과 | 413 |
| 앱 코드 `NARRATION_NOT_READY` | 리딩이 `completed`가 아님 | 409 |
| 앱 코드 `NARRATION_FAILED` | 낭독 중간 실패(대체 없음, 환불 완료) | 502 |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전이 서버 값과 다름 | 409 |
| 앱 코드 `INTERNAL_KEY_INVALID` | 워커 키 또는 Dify 내부 키 불일치 | 401 |
| FastAPI `AI_TOKEN_INVALID` | 서명, `aud`, scope, 만료, `jti` 재사용 | 401 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 저장 시 `expected_version`이 현재 버전과 다름(`docs/products/_platform-core/LLM_WIKI.md:31`) | 409 |

## 8. 인증 단계 경로 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절이다. 소유는 `src/lib/auth/`·`src/app/(auth)/`·`src/app/api/dev/`가 AS-06-003(A), 콜백 완성과 제공자 버튼이 AS-06-055(B), 카카오 AS-06-056(C1), 네이버 AS-06-057(C2)이다.

| 메서드 경로 | 단계 | 입력 | 처리 | 출력 | 오류 |
|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | `{ persona, next? }`(zod 열거형: 공통 페르소나 + `welcome_pending`) | `isMockAuthAllowed()` 거짓이면 404(존재 자체를 숨김) → 쿠키 세션 서버 클라이언트로 `signInWithPassword(<persona>@dev.test, DEV_SEED_PASSWORD)` → `finishLogin('astro', next)`(아래 2~8번. 코드 교환 1번만 없다. 시드 계정은 `email_confirm: true`라 5번 환영 크레딧 조건을 만족하고, 이메일 제공자 계정이라 6번 약관 단계는 건너뛴다) | 303 → `next`(화이트리스트) 또는 `/dashboard` | 404(판정 거짓), 400 알 수 없는 페르소나, 401 시드 계정 없음(시드 스크립트 미실행 안내). 레이트 리밋 대상 아님 |
| `GET /auth/callback` | B(C1·`custom:naver` 재사용) | `code`, `next?` | `finishLogin`: 1 `exchangeCodeForSession`(PKCE) → 2 `session_context('astro')` 1회 → 3 `entitled=false`면 `rpc('bootstrap_app_for_org', { p_app_id: 'astro' })` 1회 후 재조회(open 앱. 모놀리스는 무동작) → 4 status 분기(suspended 403) → 5 환영 크레딧: 로그인 수단이 확인된 경우(OAuth 제공자 또는 `email_confirmed_at` 있음) 서버가 `/api/auth/welcome`과 같은 함수(`src/server/welcome-credits.ts`)를 1회 호출(멱등 키 `signup:<org>:astro`, IP 해시 보류 규칙 동일) → 6 OAuth 제공자 로그인이고 약관 2종 동의 행이 없으면 `/onboarding/terms`(03장 7.3절) → 7 `next`가 `/`로 시작하고 `//`·`@`·`\` 없을 때만 그 경로, 아니면 `/dashboard`(origin 고정) → 8 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 없음) | 303 | `/login?error=callback`(코드 없음·재사용·만료), 프로필 없음 → 로그아웃 후 `/login` |
| `GET /auth/naver/start` | C2 브리지 경로만 | `next?` | 32바이트 state → HttpOnly·Secure·SameSite=Lax 서명 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분) → 네이버 authorize로 302. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 302 | 429 |
| `GET /auth/naver/callback` | C2 브리지 경로만 | `code`, `state` | 쿠키 state 상수 시간 비교 후 삭제 → 서버 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(provider `naver`, 네이버 고유 id) 조회 → 있으면 magiclink `generateLink` + `verifyOtp`로 세션 / 없고 같은 이메일 사용자 없으면 `createUser` + 링크 행 / 같은 이메일 사용자 있으면 거부 → `finishLogin` | 303 | `/login?error=state`, `/login?error=email_in_use`, `/login?error=callback`. 네이버 토큰·링크·코드는 저장·로그 금지 |

`supabase_custom` 경로를 채택하면 네이버도 `GET /auth/callback`을 그대로 쓰고 위 두 브리지 경로는 만들지 않는다(01장 D-20).

`POST /api/auth/welcome`(2절)은 그대로 둔다: 이메일 인증 직후 `/auth/verify` 복귀처럼 콜백을 거치지 않는 경우와 지급 보류 뒤 재시도에 쓴다. 콜백 5번과 같은 함수이므로 두 경로로 불려도 원장은 1행이다. 이메일 미인증이면 409(기존). Stage A 시드 계정은 `email_confirm: true`로 만들어 인증 완료 상태다.

| 오류 코드 | 의미 | HTTP / 이동 |
|---|---|---|
| 쿼리 `error=callback` | 코드 교환 실패 | 303 `/login?error=callback` |
| 쿼리 `error=state` | 브리지 state 불일치·없음·만료 | 303 `/login?error=state` |
| 쿼리 `error=email_in_use` | 브리지에서 같은 이메일의 다른 가입 수단 존재(자동 연결 금지) | 303 `/login?error=email_in_use` |

`/api/dev/login`은 Mock이 허용되지 않으면 오류 본문 없이 404만 돌려준다(별도 앱 오류 코드를 두지 않는다).
