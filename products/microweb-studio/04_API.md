# 04 API: Microweb Studio

2026-10-13 개정: AI·음성 Route Handler(2.1절), 하객 음성 방명록·인사말 음성 라우트, `attach_guestbook_voice` RPC, FastAPI 엔드포인트와 Dify 계약(6.1, 6.2절), AI 오류 코드를 더했다. 서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 스튜디오 라우트는 `requireSession('microweb', {roles})`(`SHARED_MODULES.md` 2장) + `studio_access` 확인. 공개 라우트는 무인증이며 쓰기는 service_role 전용 DB 함수만 부른다. 세션은 모든 인증 단계(A Mock, B Google + 초대 메일, C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(8절) |
| 읽기 | 사용자 세션 클라이언트(RLS). 하객 페이지는 anon 키. service_role은 `src/server/`에서만 |
| 멱등 | 쓰기 요청은 `request_id`(UUID) 헤더 `Idempotency-Key`. 크레딧 `consume:microweb:<request_id>`, 잡 `job:microweb:<request_id>` |
| 크레딧 | 셀프 모드 첫 게시만 라우트에서 선차감. 실패 시 잡 환불 또는 라우트 `refund_credits` |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }` |
| IP | 원문 저장 금지. `ip_hash = sha256(daily_salt(IP_HASH_SALT_SEED, KST 날짜) + ip)` hex 64자 |
| 레이트 리밋 | 하객/문의 쓰기는 DB 함수 안에서(`1500_microweb.sql:1089`, `:1147`, `:1205`), AI 축하말·하객 음성·스튜디오 AI·업로드는 라우트에서 `core.rate_limit_hit` |
| 공개 쓰기 공통 | 본문 16KB 상한(하객 음성 업로드 라우트만 2MB), 허니팟 필드 `website`가 차 있으면 200 `ok`로 응답하고 저장하지 않음, Origin 검사(같은 사이트) |
| AI 호출 인증 | Next.js가 EdDSA 서명 토큰을 발급해 FastAPI·음성 서버를 부른다(`iss=microweb`, `aud=platform-ai:microweb`, 수명 10분). 하객은 `sub=visitor:<visitor_key>`(서명된 방문자 쿠키의 해시). Dify에는 토큰을 넘기지 않고 대화 매핑만 쓴다. 브라우저는 Dify·FastAPI·제공자를 직접 호출하지 않는다 |
| AI 크레딧 | 셀프서비스는 시작 전 선차감 후 정산(`conv:<id>:turn:<n>`, `run:<id>`, `voice:<id>`), 대행 모드는 D-9 권고안대로 0 크레딧 + `ai_usage` 기록 + 공정 사용 상한. 하객 기능은 항상 0 크레딧 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| GET `/i/[slug]`(페이지) | 누구나 | slug | HTML, `noindex`, `s-maxage=30` | 0 | anon select `site_publications` | 404, 410 |
| GET `/api/public/[slug]/bgm` | 누구나 | slug | 302 서명 URL(1시간) | 0 | `is_site_live` | 404 |
| POST `/api/public/[slug]/guestbook` | 누구나 | name(1~20), body(1~500), relation enum?, ai_assisted bool, voice_token?, website(허니팟) | `{id, voice: boolean}` | 0 | `submit_guestbook_entry` → (`voice_token`이 있고 쿠키 해시·slug가 맞으면) `attach_guestbook_voice` → 성공 시 `voice_jobs.expires_at`을 사이트 공개 만료 + 30일로 연장(service). attach 실패(`invalid`, `already`)여도 텍스트 항목은 남기고 음성은 폐기 | 410 closed, 422 invalid/spam, 429 |
| POST `/api/public/[slug]/rsvp` | 누구나 | guest_name, side, attending, party_size 1~10, meal?, message 200? | `{id}` | 0 | `submit_rsvp` | 410, 422, 429 |
| POST `/api/public/[slug]/greeting` | 누구나 | relation enum, tone enum(`polite`/`friendly`). 하객 이름은 받지 않는다 | `{text}` 200자 | 0(`ai_usage` 기록) | `is_site_live`, `rate_limit_hit('microweb:greeting:ip:<hash>',5,3600)`, 사이트 30일 300. 서명 토큰(`sub=visitor:<key>`, scope `graph:microweb.guest_greeting`)으로 FastAPI `POST /graphs/microweb.guest_greeting/runs` | 404, 429, 503 `AI_UNAVAILABLE` |
| GET `/api/public/[slug]/voice-greeting` | 누구나 | slug | 302 서명 URL(1시간) | 0 | `is_site_live` → 스냅샷 `greeting.voice_asset_id` → service로 `site_assets`(kind voice, ready) 조회 → 서명. 응답 `Cache-Control: private` | 404 |
| POST `/api/public/[slug]/guestbook/voice/consent` | 누구나 | `{ notice_version }`(서버 상수 `GUEST_VOICE_NOTICE_VERSION`과 같아야 함) | 204 + 서명된 방문자 쿠키(`HttpOnly`, `SameSite=Lax`, 24시간) | 0 | `is_site_live`, 사이트 `guestbook_voice` 확인, `rate_limit_hit('microweb:gvoice:consent:<ip>',5,600)`, `voice_sessions` INSERT(`visitor_key`=쿠키 해시, service) | 404, 409 `CONSENT_VERSION_MISMATCH`, 429 |
| POST `/api/public/[slug]/guestbook/voice/transcribe` | 쿠키 소지 하객 | multipart `{ audio(webm/ogg/mp4, 2MB 이하, 30초 이하), website(허니팟) }` | `{ caption, duration_seconds, voice_token }` | 0(`ai_usage` 기록) | 쿠키·세션 확인 → 사이트·블록 옵션 `voice_enabled`·`features.guestbook_voice`·30일 100건 확인 → `rate_limit_hit` IP 해시당 10분 2·하루 5, 사이트 하루 50 → 매직바이트·길이 검사 → `voice_jobs` INSERT(`store_audio=true`, `consent_kind='third_party_notice'`, `notice_version`, `consent_at`, `expires_at=now+1h`) → `voice-audio`에 저장 → 오픈소스 STT(`microweb_guestbook_voice`, scope `voice`). `voice_token`은 서버가 서명한 1시간 토큰(job, 방문자 해시, slug) | 403 `VOICE_CONSENT_REQUIRED`, 404, 413 `VOICE_TOO_LONG`, 415, 422, 429, 503 `VOICE_UNAVAILABLE`(대체 없음) |
| DELETE `/api/public/[slug]/guestbook/voice` | 쿠키 소지 하객 | `{ voice_token }` | 204 | 0 | 토큰 검증 후 `voice_jobs` 만료 처리 + 파일 삭제(제출 전 취소) | 403 `VOICE_TOKEN_INVALID` |
| GET `/api/public/[slug]/guestbook/[entry_id]/voice` | 누구나 | slug, entry_id | 302 서명 URL(5분), `Cache-Control: private, no-store` | 0 | `is_guestbook_public`, 항목 visible·`has_voice`, 스냅샷 방명록 블록 `voice_public=true`일 때만. `rate_limit_hit('microweb:gvoice:play:<ip>',60,600)` | 404 |
| POST `/api/public/leads` | 누구나 | name, phone?, email?(하나 필수), kind?, template_code?, tier?, industry?, event_on?, simulator(8KB), message 2000, privacy_consent=true, website | `{id}` | 0 | `create_lead(MICROWEB_STUDIO_ORG_ID, ...)` + 메일 알림 | 422, 429 |
| GET `/p/[token]`(페이지) | 토큰 | token 48 hex | 시안 렌더(서명 URL 이미지) | 0 | service select by `preview_token_hash` | 404 |
| POST `/api/public/preview/[token]/approve` | 토큰 | name 1~40 | `{site_id}` | 0 | `record_customer_approval` | 410 MW013 |
| POST `/api/studio/sites` | owner/admin/member | template_code, title, slug, event_at? | site | 0 | `create_site` | 409 slug, 403, 409 MW005 |
| PATCH `/api/studio/sites/[id]` | 같음 | title?, content?(블록 zod), event_at?, expires_at?, slug?, 토글 3개 | site | 0 | 사용자 세션 UPDATE(RLS, 컬럼 GRANT) | 409 MW002/MW003, 422 |
| POST `/api/studio/sites/[id]/transition` | draft/review: member 이상, unpublished/archived: owner/admin | to, reason? | site | 0 | `transition_site` → unpublished면 `site.unpublish_assets` enqueue | 403, 409 MW001 |
| POST `/api/studio/sites/[id]/consent` | member 이상 | basis | site | 0 | `confirm_disclosure_consent` | 403 |
| POST `/api/studio/sites/[id]/preview-token` | member 이상 | ttl_hours 1~336 | `{url}` 한 번만 | 0 | `issue_preview_token` | 403, 409 |
| POST `/api/studio/sites/[id]/assets/upload-url` | member 이상 | kind, mime, bytes | `{path, signedUrl, token}` | 0 | 서버가 경로 생성 `<org>/microweb/site-photo/<uuid>.<ext>`, rate limit 업로드 60/시간 | 413, 415 |
| POST `/api/studio/sites/[id]/assets/complete` | member 이상 | path | asset | 0 | service INSERT `site_assets` + enqueue `asset.process` | 400 경로 불일치 |
| DELETE `/api/studio/assets/[id]` | member 이상 | - | 204 | 0 | service: Storage 삭제 → 행 삭제 | 403 |
| POST `/api/studio/sites/[id]/publish` | owner/admin | expires_at?, request_id | `{job_id}` 202 | 셀프 첫 게시: 템플릿 `self_publish_credits` | `consume_credits` → `request_publish` → `enqueue_job` | 402, 409 MW001/6/7/8/9, 422 블록 |
| POST `/api/studio/guestbook/[id]/moderate` | member 이상 | status | entry | 0 | `moderate_guestbook_entry` | 403 |
| GET `/api/studio/guestbook/[id]/voice` | member 이상 | - | 302 서명 URL(5분) | 0 | 사용자 세션 RLS로 항목 조회(`has_voice`) → service로 `voice_jobs.storage_path` 조회 → 서명. 감사는 남기지 않음(재생) | 403, 404 |
| DELETE `/api/studio/guestbook/[id]` | owner/admin | - | 204 | 0 | service: `voice_jobs` 조회 → `voice-audio` 파일 삭제 + `expired` 처리 → 항목 삭제, 감사 `guestbook.delete`(본문 제외). UI는 RLS 직접 삭제 대신 이 경로만 쓴다 | 403, 404 |
| POST `/api/studio/sites/[id]/ai-copy` | member 이상, `features.ai_copy` | `{ tone('polite'\|'warm'\|'concise'), memo?(500자), request_id }` | `{ run_id }` 202 | 4.1절(셀프 선차감 2, 대행 0) | 사이트 한도(30일 20회)·사용자 한도(5회/시간), (셀프) `consume_credits(run:<run_id>)`, 서명 토큰(scope `graph:microweb.invitation_copy`) → FastAPI `POST /graphs/microweb.invitation_copy/runs`. 메모는 전화·계좌·이메일 패턴 마스킹 후 전송 | 402 `CR001`, 403, 409 MW003, 429 `AI_COPY_LIMIT`, 503 `AI_UNAVAILABLE`(환불됨) |
| GET `/api/studio/sites/[id]/ai-copy/[run_id]` | 실행한 사용자 | - | `{ status, steps[], variants[3], composition, citations[] }` | 0 | FastAPI `GET /graphs/runs/{id}`(scope 같음). 완료 시 정산(`settled_at`) | 404 |
| POST `/api/studio/sites/[id]/ai-copy/[run_id]/apply` | member 이상 | `{ variant: 1..3, blocks: string[], base_updated_at }` | site | 0 | 서버가 선택한 블록의 props를 현재 `content`에 병합(블록 zod·템플릿 `allowed_blocks` 재검증) → 사용자 세션 UPDATE(RLS, 컬럼 GRANT). 감사 `site.ai_copy_apply`(본문 제외) | 409 편집 충돌·MW003, 422 블록 |
| POST `/api/studio/sites/[id]/voice-greeting` | member 이상, `features.voice_greeting` | `{ mode: 'tts', request_id }` | `{ asset_id }` | 천 자 단위(오픈소스 1 / ElevenLabs 5, 셀프) | 인사말 본문은 DB 인사말 블록에서만 읽는다(600자 이하). 선차감 → `resolve_ai_route('microweb_voice_greeting','tts')`로 제공자 1개 고정 → mp3를 `org-files`에 저장 → `site_assets`(kind voice) INSERT → `asset.process` | 402, 422 길이, 429, 503(환불됨) |
| POST `/api/studio/sites/[id]/voice-greeting/upload-url` | member 이상 | `{ mime('audio/webm'\|'audio/ogg'\|'audio/mp4'), bytes(5MB 이하), self_confirmed: true }` | `{ path, signedUrl, token }` | 0 | 서버가 경로 생성 `<org>/microweb/site-voice-src/<uuid>.<ext>`, 업로드 rate limit | 413, 415, 422 확인 누락 |
| POST `/api/studio/sites/[id]/voice-greeting/complete` | member 이상 | `{ path }` | `{ job_id }` 202 | 0 | 경로 접두사 확인 → `enqueue_job('voice.transcode')` → 변환 후 `site_assets` INSERT와 `asset.process` | 400 경로 불일치 |
| GET `/api/studio/sites/[id]/rsvp.csv` | owner/admin | - | CSV(UTF-8 BOM) | 0 | RLS select + service audit `rsvp.export` | 403 |
| POST `/api/studio/leads/[id]/status` | member 이상 | to, note? | lead | 0 | `set_lead_status` | 409 MW001 |
| DELETE `/api/studio/leads/[id]` | owner/admin | - | 204 | 0 | `delete_lead` | 403 |
| POST `/api/studio/orders` | owner/admin | customer_name, amount_krw, template_code?, tier?, lead_id?, site_id? | order | 0 | `create_order` | 403, 422 |
| POST `/api/studio/orders/[id]/transition` | owner/admin | to, payment_method?, payment_reference?, note? | order | 0 | `transition_order` | 409 MW001, 422 |
| POST `/api/billing/orders`(Phase 2) | owner/admin, self_service | credit_pack_code | `{orderId, amount, customerKey}` | 0 | service INSERT `core.payment_orders`(금액은 `credit_packs`에서) | 404 |
| POST `/api/billing/confirm`(Phase 2) | owner/admin | paymentKey, orderId, amount | payment | +팩 | Toss confirm → `core.confirm_payment_order` | 4절 |
| POST `/api/webhooks/toss`(Phase 2) | Toss | rawBody | 200 | 0 | `webhook_events` | 401 |
| 관리자(platform_admin, service) | - | studio_access 부여/회수, 템플릿/포트폴리오 편집 | - | 0 | service INSERT/UPDATE + 감사 | 403 |

### Toss confirm 실패 처리

`core.confirm_payment_order`는 금액 불일치(PM001) 때 raise를 올린다(계약 불변, 같은 호출의 주문 UPDATE는 롤백). 주문 `failed` 기록은 service_role 전용 `fail_payment_order`(2026-10-13 코어 반영)를 별도 호출로 부른다.

| 단계 | 동작 |
|---|---|
| 1 | confirm 전에 라우트가 `payment_orders.amount_krw`와 요청 amount를 직접 대조, 다르면 Toss confirm을 호출하지 않고 409 |
| 2 | Toss 승인 뒤 RPC가 PM001/PM409를 내면(PM001이면 먼저 별도 호출로 `fail_payment_order(order_id,'amount_mismatch',{...})`) Toss 결제 취소 API 호출 → service 감사 INSERT `payment.confirm_mismatch`(order_id, 금액) → 운영 알림 |
| 3 | PM001 주문은 `fail_payment_order`로 `failed`가 된다. 그 밖에 `created`로 남은 주문은 `expire_stale_payment_orders`가 1시간 뒤 `expired`로 바꾼다. UI는 라우트 응답으로 실패를 보여 준다 |
| 4 | 코어 수정은 반영 완료(06장 6절) |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다. 크레딧 열은 셀프서비스 기준이고 대행 모드는 D-9 권고안(0 크레딧 호출 + 한도)이다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner/admin | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/ai/conversations` | member 이상, `features.ai_chat` | `{ site_id?: uuid, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `site_id`는 같은 조직 사이트만 | 404 사이트, 403 엔타이틀먼트·플랜 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000), site_id? }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 1, 정산 1~2 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `site_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/voice/consent` | member 이상 | `{ notice_version }` | 204 | 0 | - | 사용자 세션 `rpc('write_audit', { p_org_id, p_action: 'voice.consent', p_target_type: 'user', p_target_id, p_after: { notice_version } })`(actor는 `auth.uid()`로 강제). 확인 여부는 service가 같은 행위자의 최신 `voice.consent` 감사 행 버전이 현재 고지문 버전과 같은지로 판정한다(별도 표 없음, 05장 6절) | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | member 이상, `features.voice_chat` | `{ conversation_id }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, request_id }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'microweb','voice_chat','stt')` → 오픈소스 `/stt` 또는 ElevenLabs SDK(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 |
| `POST /api/admin/knowledge/documents` | platform_admin | multipart md(2MB 이하), `{ title, author, reviewed_on, license }` | `{ document_id }` | 0(지식 조직 사용량) | FastAPI `/rag/ingest`(scope `rag`, `org`=`MICROWEB_KNOWLEDGE_ORG_ID`) | Storage 지식 조직 폴더, 감사 `knowledge.upload` | 409 중복, 422 PII 패턴, 403 |
| `POST /api/admin/wiki/ingest`, `POST /api/admin/wiki/lint` | platform_admin | `{ document_ids?: uuid[] }` | `{ run_id }` | 0 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | - | 403 |
| `PATCH /api/admin/wiki/pages/[...slug]` | platform_admin | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 R-10) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`). 스튜디오 위키 화면은 서버 컴포넌트가 지식 조직의 `published` 페이지를 service_role로 읽어 보여 준다(사용자 입력이 쿼리에 들어가지 않는 slug 조회만, 공개 웹에는 노출하지 않음).

## 3. RPC (SECURITY DEFINER)

모든 함수 `set search_path = ''`, 스키마 한정, EXECUTE는 `1500_microweb.sql:1445` 이후에서 정리.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `has_studio_access(org)` | authenticated(정책) | 멤버 + 엔타이틀먼트 + 허용 목록 | boolean | - |
| `is_site_live(site)`, `is_guestbook_public(site)` | anon, authenticated(정책) | 스냅샷 is_live, 만료 전 | boolean | - |
| `create_site(org, template_code, title, slug, event_at)` | authenticated, service | `is_service_caller` 또는 owner/admin/member + 허용 목록, 템플릿 beta/released, 활성 상한 | sites | 42501, MW004, MW005, 23505 |
| `transition_site(site, to, reason)` | authenticated, service | draft/review: member 이상, unpublished/archived: owner/admin | sites | 42501, MW001, P0002 |
| `issue_preview_token(site, ttl_hours)` | authenticated, service | member 이상, publishing/archived 불가 | text(원문 1회) | 42501, MW003 |
| `confirm_disclosure_consent(site, basis)` | authenticated, service | member 이상 | sites | 42501, 22023 |
| `moderate_guestbook_entry(entry, status)` | authenticated, service | member 이상 | guestbook_entries | 42501, 22023 |
| `set_lead_status(lead, to, note)` / `delete_lead(lead)` | authenticated, service | member 이상 / owner/admin | leads / void | 42501, MW001 |
| `create_order(...)`, `transition_order(...)`, `attach_order_site(order, site)` | authenticated, service | owner/admin, 같은 조직의 lead/site | production_orders | 42501, MW001, 22023 |
| `request_publish(site, actor, ledger)` | service_role | actor owner/admin, 허용 목록, 동의, 만료일, 대행: 결제 주문+고객 승인 / 셀프: 미환불·미사용 consume 원장 | sites(publishing) | 42501, MW001, MW006~MW009 |
| `finalize_publish(site, job, content, og...)` | service_role | publishing | site_publications | MW001 |
| `fail_publish(site, error)` | service_role | publishing만 처리 | sites | - |
| `record_customer_approval(token_hash, name)` | service_role | 유효 토큰, draft/review | uuid | MW013, 22023 |
| `submit_guestbook_entry(slug, name, body, relation, ai_assisted, ip_hash)` | service_role | 게시 중, 방명록 켜짐, 리밋, URL/중복 | (entry_id, result) | 결과 코드 |
| `attach_guestbook_voice(entry, voice_job)` | service_role | 같은 조직·`app_id='microweb'`·기능 `microweb_guestbook_voice`·STT·성공·`store_audio`·`consent_kind='third_party_notice'`인 작업만, 항목당 1개·작업당 1개 | text(`ok`/`not_found`/`invalid`/`already`) | 42501 (`1500_microweb.sql:1613-1663`) |
| `submit_rsvp(slug, ...)` | service_role | 게시 중, RSVP 켜짐, 예식 전, 리밋 | (rsvp_id, result) | 결과 코드 |
| `create_lead(org, ..., consent, ip_hash)` | service_role | 대행 모드 허용 목록, 동의, 리밋, 링크 3개 이상 스팸 | (lead_id, result) | 결과 코드 |
| `expire_sites()` | service_role(스케줄) | - | setof uuid | - |
| `purge_expired_data()` | service_role(스케줄) | - | jsonb 건수 | - |

코어 RPC(`session_context`, `consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `complete_job`, `fail_job`, `confirm_payment_order`, `rate_limit_hit`, `write_audit`)는 `CORE_SPEC.md`를 따른다. AI·음성 코어 RPC(`resolve_ai_route`, `match_ai_chunks`는 service_role만, `set_ai_cross_border_ack`는 owner/admin)는 `docs/products/_supabase-modular/migrations/0008_core_ai.sql`을 따르고 제품은 재정의하지 않는다.

## 4. 잡 페이로드 계약

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `asset.process` | `{ asset_id, org_id, site_id, storage_path, kind }` | `{ width, height, variants: { w400, w800, w1600, og? }, exif_stripped: true }` | "형식 확인" 10, "메타데이터 제거" 40, "크기별 저장" 90 |
| `site.publish` | `{ site_id, org_id, actor_id, request_id }` | `{ version, public_count, og_image_url }` | "사진 복사 n/m", "공개본 생성" 95 |
| `site.unpublish_assets` | `{ site_id, org_id, reason: 'unpublished' \| 'expired' }` | `{ removed }` | - |
| `site.purge` | `{ site_id, org_id }` | `{ removed_files, deleted: true }` | - |
| `voice.transcode` | `{ site_id, org_id, actor_id, source_path }` | `{ asset_id, duration_seconds }` | "형식 확인" 10, "mp3 변환" 60, "자산 등록" 90 |

규칙: `asset.process`는 kind `voice`(mp3)도 같은 매직바이트 검사를 하고 EXIF 규칙에서 `bgm`처럼 제외된다(`1500_microweb.sql:1665-1674`). `site.purge`는 사이트의 하객 음성 파일(`voice_jobs.storage_path`)과 인사말 음성 자산도 함께 지운다. 페이로드에 비밀값 없음. 워커는 시작할 때 사이트 상태를 다시 읽고 맞지 않으면 재시도 불가 실패. `asset.process`는 매직바이트 검사(jpeg/png/webp/mp3) 실패 시 재시도 불가, `site_assets.status='failed'`.

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신(Phase 2) | Toss 결제 상태 | Toss 방식(미확인, `SHARED_MODULES.md` 6장) | `paymentKey + status + 시각` 해시 | 상태 동기화만, 지급 없음 |
| 발신 | 없음 | - | - | 문의 알림은 메일 |

## 6. 외부 API 어댑터

| 외부 | 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| 카카오 JS SDK(공유, 지도) | 클라이언트, 공식 SRI | 미초기화 시 Web Share → 링크 복사 | 카카오 정책(미확인) |
| FastAPI AI 서비스(그래프) | `api/studio/sites/[id]/ai-copy`, `api/public/[slug]/greeting`(서명 토큰) | 체인 대체(라우터) → 걸린 안 재작성 1회(그래프) → `failed` → 선차감 환불. 120초 안에 끝나지 않으면 실패 처리 | 실행당 `draft_copy`·`propose_composition` 호출 2~4회. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*`, `voice-greeting` | 채팅용은 체인 다음으로 대체(`voice_jobs.fallback_from`), 인사말 음성은 시작 때 고른 제공자 하나로만 만들고 실패하면 파일 없이 환불. 하객 음성에는 쓰지 않는다 | 요금·상업 이용 조건 구현 시 확인(D-13) |
| 오픈소스 음성 서버 | `src/app/api/voice/*`, 하객 음성 라우트(서명 토큰 scope `voice`) | 실패하면 하객 음성은 대체 없이 실패(`VOICE_UNAVAILABLE`) | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). microweb은 30~60초·600자 |
| ffmpeg(워커) | `voice.transcode` | 변환 실패 → 자산 `failed` + 사용자 재업로드 안내 | 라이선스·이미지 크기 구현 시 확인(D-14) |
| 메일 발송 | `src/server/notify.ts` | 3회 재시도, 실패해도 리드는 저장(대시보드에 표시) | 제공자 한도 |
| Toss(Phase 2) | `api/billing/*` | 2절 결함 회피 | - |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 microweb이 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | microweb 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R-10). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `consult`: 문구 코퍼스·위키·템플릿 카탈로그 검색 + (선택) 사이트 컨텍스트(`site_id`가 매핑 org의 사이트인지 확인, 블록 종류·글자 수·상태만) + `chat` 모델. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /dify/retrieval` | Dify 외부 지식 | 내부 키 | 지식 조직의 `microweb-copy`, `microweb-templates`, 위키 컬렉션만. 사용자 조직 데이터 금지 |
| `POST /graphs/microweb.invitation_copy/runs`, `GET /graphs/runs/{id}` | Next.js 서버 | 서명 토큰 scope `graph:microweb.invitation_copy`, `jti` 1회 | 문구·구성 제안(입력 `{ template_code, tone, month, tokens, memo }`, 출력 `{ variants[3], composition, citations[] }`, pydantic 스키마는 `src/engine/schema/` 내보내기 파일과 같게) |
| `POST /graphs/microweb.guest_greeting/runs` | Next.js 하객 라우트 | 서명 토큰 scope `graph:microweb.guest_greeting`, `sub=visitor:<key>` | 입력 `{ relation, tone }`, 출력 `{ text }` (200자 이하) |
| `POST /rag/ingest` | Next.js 관리자 | 서명 토큰 scope `rag`(org=지식 조직) | 코퍼스 색인 |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-10) | Next.js 관리자 | 서명 토큰 scope `wiki` | 문구 위키 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`microweb-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `microweb-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_MICROWEB`(Next.js 서버 전용). 정의는 `infra/dify/microweb-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `site_id`(선택, 대화 시작 때만). 서명 토큰, org, 이름, 연락처는 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `consult`: HTTP 요청 노드 → 답변 / 분기 `out_of_scope`(인사·무관한 질문): 안내 문구 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, site_id, mode: "consult" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다 |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| MW001 | 허용되지 않은 상태 전이 | 409 |
| MW002 | 첫 게시 뒤 slug 변경 | 409 |
| MW003 | publishing/archived 편집 잠금 | 409 |
| MW004 | 사용할 수 없는 템플릿 | 422 |
| MW005 | 활성 사이트 상한 | 409 |
| MW006 | 공개 동의 없음 | 409 |
| MW007 | 만료일 없음/지남 | 422 |
| MW008 | 결제(주문 또는 크레딧) 없음 | 402 |
| MW009 | 고객 승인 없음 | 409 |
| MW013 | 시안 토큰 무효/만료 | 410 |
| 결과 `closed` / `invalid` / `spam` / `rate_limited` | 공개 쓰기 결과 | 410 / 422 / 422 / 429 |
| 23505 | slug 중복 | 409 |
| 코어 코드 | `CORE_SPEC.md` 15장 매핑(42501 → 403, CR001 → 402 등) | - |
| `CR001` | 크레딧 부족(셀프서비스 AI·음성 선차감) | 402 + `{ balance, required }` |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한 | 429 |
| 앱 코드 `AI_COPY_LIMIT` | 사이트 30일 문구 제안 상한 또는 사용자 시간당 상한 | 429 |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전 불일치(국외 이전, 음성 처리, 하객 녹음) | 409 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리·녹음 고지 미확인 | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 스튜디오 60초·5MB, 하객 30초·2MB 초과 | 413 |
| 앱 코드 `VOICE_UNAVAILABLE` | 하객 음성 STT 실패(오픈소스 서버 장애, 상용으로 대체하지 않음) | 503 |
| 앱 코드 `VOICE_TOKEN_INVALID` | `voice_token` 서명·만료·방문자·slug 불일치 | 403 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 `expected_version` 불일치 | 409 |

## 8. 인증 라우트 (2026-10-14 추가, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절. 응답 봉투는 1절과 같다(리다이렉트 라우트 제외). 단계 분기 코드는 이 라우트들과 `src/lib/auth/`, 로그인 화면에만 둔다.

| 메서드 경로 | 단계 | 역할 | 입력 | 출력 | 처리 | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/dev/login` | A(로컬 전용) | 누구나(로컬) | `{ persona: 'owner'\|'admin'\|'member'\|'viewer'\|'outsider'\|'no_app'\|'suspended'\|'ops'\|'studio_denied', next? }` | 302 `next` 또는 `/studio` | `isMockAuthAllowed()`(`AUTH_MODE=mock`, Supabase 호스트 `127.0.0.1`/`localhost`, `VERCEL_ENV`·`RAILWAY_ENVIRONMENT` 비어 있음) → 쿠키 세션 서버 클라이언트 `signInWithPassword(<persona>@dev.test, DEV_SEED_PASSWORD)` → `finishLogin('microweb', next)` | 판정 거짓이면 404(존재를 숨김). 모르는 페르소나 400. 레이트 리밋 대상 아님 |
| POST `/api/dev/logout` | A(로컬 전용) | 로그인 사용자 | - | 302 `/login` | 같은 판정 후 `signOut` | 판정 거짓이면 404 |
| GET `/auth/callback` | B·C1·C2(`custom:naver`) | 누구나 | `code`, `next?`, `error?` | 302 | `finishLogin('microweb', next)`: (1) `exchangeCodeForSession`(PKCE) (2) `session_context('microweb')` 1회 (3) invite 앱이라 `bootstrap_app_for_org`를 호출하지 않는다. `entitled=false`면 `/no-access` (4) pending `/pending`, suspended `/403` (5) 엔타이틀먼트가 있어도 `studio_access` 없으면 `/pending`(기존 가드) (6) `next`가 `/`로 시작하고 `//`·`@`·`\`가 없을 때만 그 경로, 아니면 `/studio`. origin은 `NEXT_PUBLIC_APP_URL` 고정 (7) 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 없음) | `code` 없음·재사용·만료 → `/login?error=callback`. 프로필 없음 → 로그아웃 후 `/login` |
| GET `/auth/naver/start` | C2 브리지 경로만 | 누구나 | `next?` | 302 네이버 authorize | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분)에 넣음. `rate_limit_hit('auth:naver:<ip 해시>',10,600)` | 429 |
| GET `/auth/naver/callback` | C2 브리지 경로만 | 누구나 | `code`, `state` | 302 | 쿠키 state 상수 시간 비교 → 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(네이버 id) 조회 → 연결 있음: magiclink `verifyOtp`로 세션 / 연결·같은 이메일 없음: `createUser` + 링크 행 / 같은 이메일 있음: 자동 연결 안 함 → 위 `finishLogin`. 네이버 토큰은 저장하지 않는다 | `state` 불일치·없음·만료 → `/login?error=state`, `/login?error=email_in_use`, `/login?error=callback` |

| 오류·리다이렉트 코드 | 의미 | 단계 |
|---|---|---|
| `/login?error=callback` | 코드 교환 실패(없음, 재사용, 만료) | B, C |
| `/login?error=state` | 브리지 state 불일치·만료 | C2 브리지 |
| `/login?error=email_in_use` | 같은 이메일의 다른 가입 수단이 있어 네이버를 자동 연결하지 않음 | C2 브리지 |
| `/no-access` | `entitled=false`(초대받지 않은 이메일로 로그인) | B, C |
| `/pending` | `studio_access` 없음 | A, B, C |
| 404 `/api/dev/*` | Mock 판정 거짓(배포 환경, 원격 DB) | A 가드 |

초대 메일 발송·`studio_access` 부여는 2절 "관리자(platform_admin, service)" 행과 MW-06-026이 소유하며 인증 단계와 무관하다. 로그인 레이트 리밋(01장 5절 "로그인 IP 10/10분")은 B단계 이후의 Supabase Auth 경로와 브리지 시작 라우트에 적용하고 `/api/dev/login`에는 적용하지 않는다.
