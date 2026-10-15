# 04 API: NOMAD Blog

작성일 2026-10-12. 코어 RPC는 `docs/file/03-설계/공용코어/CORE_SPEC.md`를 인용만 한다. 제품 RPC 정본은 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1300_blog.sql`이다. 2026-10-13 개정: AI·음성 Route Handler(2.1절), AI 잡 페이로드(4절), FastAPI 엔드포인트와 Dify 계약(6.1·6.2절), AI 오류 코드(7절)를 더했다. 공용 규칙은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`를 인용만 한다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 `/api/**`(웹훅, `/r`, `/api/dev/login` 제외)는 진입부에서 `requireSession('blog', { roles })`. 미로그인 401, pending/suspended 403, `entitled=false` 402. 세션은 모든 인증 단계(A Mock·B Google·C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(8절, 확정 결정 22) |
| 입력 검증 | zod 스키마. 실패 422 + 필드 오류 |
| 멱등 | 생성·발행·지원 요청은 클라이언트 UUID `request_id` 필수. 키: `consume:blog:<request_id>`, `job:blog:<request_id>`, 발행 행 `idempotency_key = pub:<request_id>:<channel_account_id>` |
| 크레딧 선차감 | Route Handler에서 service_role로 `consume_credits` → `enqueue_job(p_credit_ledger_id)` 또는 동기 호출(`withCredits`). 사용자 RPC 안에서 차감하지 않는다(`DB_CONVENTIONS.md` 11장). AI·음성의 선차감·정산은 2.1절의 라우트에서만 한다 |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. `message`는 사용자 문구. 예외 원문·스택 금지 |
| 레이트 리밋 | `core.rate_limit_hit` 키 `blog:<route>:<org_id>`. 생성 60회/분, 브랜드커넥트 지원 `brandconnect:apply:<account_id>` 5회/시간(video 클립형 요청과 합산, `SECURITY_BASELINE.md` 8장), `/r` `affiliate:r:<ip_hash>` 60회/분 |
| 감사 | 01장 BL-F-006 행동은 서버가 `auditAsService` 또는 제품 RPC 내부 `write_audit` |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어/제품 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/ai/keywords` | member+ | `{ request_id, topic(1~100자), channel: naver\|tistory\|wordpress }` | `{ keywords: [{keyword, volume_est, competition_est, intent, reason}] (10) }` | 1 | `consume_credits`, 실패 시 `refund_credits` | 402 CR001, 502 AI_FAILED(환불됨) |
| POST `/api/ai/outline` | member+ | `{ request_id, keyword, template }` | `{ titles: string[3], outline: string[] }` | 1 | 같음 | 같음 |
| POST `/api/posts` | member+ | `{ title?, template?, target_keyword? }` | `{ post }` | 0 | 브라우저 직접 INSERT도 가능(RLS) | 403 |
| POST `/api/posts/:id/generate` | member+, quality는 `ai_modes` 포함 | `{ request_id, keyword, template, length: short\|medium\|long, tone?, mode: fast\|quality, outline?, title?, experience_note?(experience 필수 50자+), affiliate_auto?: boolean(Pro+), material_ids?: uuid[] }` | `{ job_id }` 202 | 그래프 정액 5/8(+1) | `consume_credits` → posts.status generating(service) → `enqueue_job('blog.ai','blog.generate')`(핸들러가 그래프 `blog.post_draft` 실행, 2026-10-13) | 402, 403 PLAN_REQUIRED, 409 BL001(generating/publishing) |
| POST `/api/posts/:id/rewrite` | member+ | `{ request_id, selection(1~1,500자), instruction(1~200자) }` | `{ text }` | 1 | `withCredits` | 402, 502 |
| POST `/api/posts/:id/tags` | member+ | `{ request_id }` | `{ tags: string[≤10] }` | 1 | `withCredits` | 402 |
| POST `/api/posts/:id/seo` | member+ | `{}` | `{ score, items: [{rule, ok, message}] }` 및 posts.seo_* 저장(service) | 0 | - | - |
| POST `/api/posts/:id/compliance` | member+ | `{ request_id }` | `{ verdict, issues, suggestions }` | 1(LLM 단계) | compliance `check` → posts.compliance_* 저장(service) | 402, LLM 오류 시 verdict=warn |
| POST `/api/posts/:id/compliance/ack` | member+ | `{}` | `{ post }` | 0 | `blog.acknowledge_compliance_warning` | 409 BL003 |
| POST `/api/posts/:id/publish` | member+, 예약은 `schedule` | `{ request_id, targets: [{channel_account_id}] (1~10), scheduled_at?, policy_ack?: ['naver_coupang'] }` | `{ publications: [{id, status, job_id}] }` 202 | 0 | 서버 순서: 엔타이틀먼트 → `blog.monthly_post_usage` 한도 → 채널 정책 경고 확인 → AI 승인 확인(그래프로 만든 원고: `posts.ai_job_id`의 `core.ai_runs.status='succeeded'`) → 렌더 미리 검증 → 발행 행 INSERT(DB 게이트) → `enqueue_job('blog.publish' 또는 'blog.browser', 'blog.publish.<channel>', run_after=scheduled_at)` → 행에 job_id | 402 BL004, 409 BL003/BL005/BL006/`AI_APPROVAL_REQUIRED`/23505(진행 중 발행), 422 |
| POST `/api/publications/:id/cancel` | member+ | `{}` | `{ publication }` | 0 | `blog.cancel_publication`(내부 `core.cancel_job`) | 409 BL002/JB002 |
| POST `/api/publications/:id/retry` | member+ | `{ request_id }` | `{ publication, job_id }` | 0 | service: failed → queued, 새 잡 | 409 BL001 |
| POST `/api/publications/:id/resolve` | member+ | `{ published_url: https URL \| null }` | `{ publication }` | 0 | `blog.resolve_unconfirmed_publication` | 409 BL001, 422 |
| POST `/api/posts/:id/archive` | member+ | `{ archived: boolean }` | `{ post }` | 0 | `blog.set_post_archived` | 409 22023 |
| POST `/api/channels` | owner/admin | `{ channel, label, blog_url?, username?, secret(비밀번호 또는 앱 비밀번호) }` | `{ channel_account }` | 0 | 플랜 한도 검사 → `CredentialVault.put` → channel_accounts INSERT(service, status pending) → wordpress는 동기 검증, naver/tistory는 동의 확인 후 `blog.channel.verify` 잡 | 403 PLAN_LIMIT, 409 BL005(동의 필요), 422 URL_NOT_ALLOWED |
| POST `/api/channels/:id/consent` | owner/admin | `{ notice_version }` | `{ channel_account }` | 0 | `blog.consent_channel_automation_risk` | 409 NOTICE_OUTDATED(서버 현재 버전과 다름) |
| POST `/api/channels/:id/verify` | owner/admin | `{ request_id }` | `{ job_id }` | 0 | `enqueue_job('blog.browser','blog.channel.verify')` | 409 |
| DELETE `/api/channels/:id` | owner/admin | - | `{ channel_account }` | 0 | `blog.disconnect_channel_account` | 403 |
| POST `/api/affiliate/accounts` | owner/admin | `{ provider, partner_id?, access_key?, secret_key?, label? }` | `{ account }` | 0 | `CredentialVault.put` + `AffiliateApi.connectAccount` | 422 |
| GET `/api/affiliate/search` | member+, `affiliate` | `?provider=coupang&q=&limit≤20` | `{ products }` | 0 | 어댑터 `searchProducts` | 409 PROVIDER_NO_SEARCH(텐핑 등) |
| POST `/api/posts/:id/affiliate-links` | member+ | `{ provider, product \| manual_url, placement, position }` | `{ link_id, short_url, affiliate_url, card }` | 0 | `createShortLink`(source_app blog, source_ref post id) + `post_affiliate_links` INSERT(service) | 422 URL_NOT_ALLOWED |
| DELETE `/api/posts/:id/affiliate-links/:linkId` | member+ | - | 204 | 0 | 매핑 DELETE(service). `affiliate_links`는 `is_active=false` | - |
| GET `/api/affiliate/stats` | owner/admin | `?range=7d\|30d` | `{ by_link, by_post, by_provider }` | 0 | `affiliate_clicks` 집계 | - |
| PUT `/api/settings/disclosure` | owner/admin | `{ provider, body(10~300자, 이해관계 단어 포함) }` | `{ id }` | 0 | `core.upsert_affiliate_disclosure(org, provider, 'blog_top', body)` | 422 DISCLOSURE_WEAK |
| POST `/api/brandconnect/accounts` | owner/admin, `brandconnect` | `{ channel_account_id }`(자격증명 공유) | `{ account }` | 0 | `connectAccount(provider naver_brandconnect, credential_id)` | 403 |
| POST `/api/brandconnect/accounts/:id/consent` | owner/admin | `{ notice_version }` | `{ ok }` | 0 | `core.consent_brandconnect_risk` + 감사 `blog.brandconnect.risk_notice_ack` | 409 NOTICE_OUTDATED |
| DELETE `/api/brandconnect/accounts/:id/consent` | owner/admin | - | `{ ok }` | 0 | service: `risk_consented_at=null`, 대기 지원 잡 `cancel_job`, 감사 | - |
| POST `/api/brandconnect/scan` | member+ | `{ request_id, account_id, keyword? }` | `{ job_id }` | 0 | 하루 4회 제한 → `enqueue_job('blog.browser','brandconnect.scan')` | 429 |
| POST `/api/brandconnect/applications` | member+ | `{ request_id, account_id, campaign_id, campaign_type, target_url(블로그 주소), brand_name?, product_name?, category?, message(≤1,000자) }` | `{ application_id, job_id }` | 0 | `campaign_type='clip'`이면 409 `CLIP_CAMPAIGN_USE_VIDEO`(BL-F-036). 그 외 `rate_limit_hit(5/h, 20/d)` → `core.create_brandconnect_application(target_kind='blog', source_app='blog')` → `enqueue_job('brandconnect.apply')` | 403 42501(동의 없음), 409, 429 |
| POST `/api/brandconnect/handoff` | member+ | `{ account_id, campaign: { campaign_id, title, brand, deadline, reward } }` | `{ redirect_url }` | 0 | video 엔타이틀먼트 확인 → video 클립 캠페인 지원 화면 URL(서명된 1회용 파라미터, 10분) 반환. 지원서는 video가 만든다(BL-F-036) | 403(video 없음) |
| POST `/api/brandconnect/message` | member+ | `{ request_id, campaign, draft }` | `{ message }` | 1 | `withCredits` | 402 |
| POST `/api/billing/orders` | owner/admin | `{ kind: subscription\|credit_pack, plan_code?, pack_code? }` | `{ orderId, amountKrw, customerKey }` | 0 | `TossApi.createOrder` | 422 |
| POST `/api/billing/confirm` | owner/admin | `{ orderId, paymentKey, amount }` | `{ payment }` | 0 | `TossApi.confirm` → `confirm_payment_order` | 409 PM001(운영 알림 + Toss 취소), PM409, PM410 |
| POST `/api/exports` | owner/admin | `{ request_id, post_ids?(≤500), format: md\|html }` | `{ job_id }` | 0 | `enqueue_job('blog.export')` | - |
| GET `/r/:code` | 누구나 | - | 302 | 0 | `rate_limit_hit` → `record_affiliate_click`(service) | 404(없음·비활성), 429 |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158`, `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:22-38`을 따른다. 브라우저는 Dify·FastAPI·음성 서버를 직접 호출하지 않는다. 위 표의 단건 AI 라우트(`keywords`, `outline`, `rewrite`, `tags`, `brandconnect/message`)는 계약을 바꾸지 않고 내부에서 `packages/core-ai` 래퍼가 FastAPI `POST /tools/blog/assist`를 서명 토큰(scope `chat`, `feat=blog.assist`, 제안)으로 호출한다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| POST `/api/onboarding/ai-consent` | owner/admin | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, 감사 `blog.ai.cross_border_ack` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| POST `/api/ai/conversations` | member+, `features.ai_chat` | `{ post_id?: uuid, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `post_id`는 같은 조직 원고만 | 404 원고, 403 엔타이틀먼트·플랜 |
| POST `/api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..2000), post_id? }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `post_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| POST `/api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| DELETE `/api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| POST `/api/posts/:id/ai-approve` | member+ | `{ run_id }` | `{ post }` | 0 | FastAPI 그래프 재개 `POST /graphs/runs/{id}/resume`(scope `graph:blog.post_draft`, 공용 목록에 없음, 06장 AI-R7) | 서버가 `posts.compliance_verdict`가 pass/ack된 warn인지 확인 → 재개 → 감사 `blog.ai.draft_approved` | 409 `BL003`(FAIL·미검사·무효), 409 `AI_RUN_NOT_WAITING`, 404 |
| POST `/api/posts/:id/ai-reject` | member+ | `{ run_id, reason?: ≤200자 }` | `{ post }` | 0 | FastAPI 그래프 취소(같은 scope) | 감사 `blog.ai.draft_rejected` | 409 `AI_RUN_NOT_WAITING` |
| POST `/api/voice/consent` | member+ | `{ notice_version }` | 204 | 0 | - | 감사 `blog.voice.notice_ack {notice_version}` | 409 `CONSENT_VERSION_MISMATCH` |
| POST `/api/voice/sessions` | member+, `features.voice_chat` 또는 `dictation` | `{ conversation_id?, purpose: 'chat'\|'dictation' }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT(받아쓰기는 `conversation_id` null) | 403 `VOICE_CONSENT_REQUIRED` |
| POST `/api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4), session_id, request_id, feature: 'voice_chat'\|'dictation' }`(받아쓰기 20MB·5분, 채팅 5MB·60초) | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'blog',feature,'stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| POST `/api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| POST `/api/materials` | member+ | multipart md/txt/pdf(10MB 이하) `{ title, contains_pii?: boolean, request_id }` | `{ document_id }` 202 | 색인 2 선차감 | FastAPI `/rag/ingest`(scope `rag`) → 잡 `blog.ai.rag_ingest` | Storage `org-files/<org>/blog/materials/<uuid>`, `consume_credits(run:<id>)`, 감사 `blog.ai.document_upload` | 409 `MATERIAL_DUPLICATE`, 400 `MATERIAL_TYPE_NOT_ALLOWED`, 403 `PLAN_LIMIT`, 402 |
| DELETE `/api/materials/[id]` | member+ | - | 204 | 0 | FastAPI 문서·청크 삭제(scope `rag`) | 감사 `blog.ai.document_delete` | 404 |
| POST `/api/wiki/ingest`, POST `/api/wiki/lint` | member+, `features.product_wiki` | `{ document_ids?: uuid[], request_id }` | `{ run_id }` | ingest 3 / lint 2 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) → 잡 `blog.ai.wiki_*` | `consume_credits(run:<id>)` | 403 `PLAN_REQUIRED`, 402 |
| PATCH `/api/wiki/pages/[...slug]` | member+ | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 AI-R4) | 감사 `blog.wiki.publish`/`blog.wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |
| POST `/api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 발급만: scope `graph:blog.post_draft`, `feat=blog.post_draft`, `org`·`sub`는 `core.jobs` 행의 `org_id`·`created_by` | `core.jobs` 조회(`status='running'`, `app_id='blog'`, `job_type='blog.generate'`) | 401 `INTERNAL_KEY_INVALID`, 409 잡 상태, 429 |
| POST `/api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`), `core.ai_documents`, `core.wiki_pages`(자기 조직 멤버). `ai_chunks`는 사용자에게 열지 않는다.

## 3. RPC (SECURITY DEFINER)

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `blog.cancel_publication(p_publication_id uuid)` | authenticated, service_role | `is_service_caller` 또는 `has_org_role(owner,admin,member)`. status queued/scheduled. 잡이 있으면 `core.cancel_job` | `blog.post_publications` | P0002, 42501, BL002, JB002 |
| `blog.resolve_unconfirmed_publication(p_publication_id uuid, p_published_url text)` | authenticated, service_role | 멤버(viewer 제외), status unconfirmed, URL https | 같음 | P0002, 42501, BL001, 22023 |
| `blog.acknowledge_compliance_warning(p_post_id uuid)` | authenticated, service_role | 멤버(viewer 제외), verdict warn | `blog.posts` | P0002, 42501, BL003 |
| `blog.set_post_archived(p_post_id uuid, p_archived boolean)` | authenticated, service_role | 멤버(viewer 제외), 전이 트리거 | `blog.posts` | P0002, 42501, 22023 |
| `blog.consent_channel_automation_risk(p_account_id uuid, p_notice_version text)` | authenticated, service_role | owner/admin, channel naver/tistory, 버전 필수 | `blog.channel_accounts` | P0002, 42501, 22023 |
| `blog.disconnect_channel_account(p_account_id uuid)` | authenticated, service_role | owner/admin. 공유되지 않은 자격증명만 `core.revoke_credential` | `blog.channel_accounts` | P0002, 42501 |
| `blog.monthly_post_usage(p_org_id uuid)` | authenticated, service_role | 멤버 또는 service | integer | 42501 |
| `blog.acquire_channel_lock(p_account_id, p_job_id, p_ttl_seconds)` | service_role 전용 | `is_privileged_session` | boolean | 42501 |
| `blog.release_channel_lock(p_account_id, p_job_id)` | service_role 전용 | 같음 | void | 42501 |

코어 RPC: `consume_credits`/`grant_credits`/`refund_credits`(`CORE_SPEC.md` 4.2절), `enqueue_job`/`claim_jobs`/`heartbeat_job`/`complete_job`/`fail_job`/`cancel_job`(9장), `effective_disclosure`/`upsert_affiliate_disclosure`/`consent_brandconnect_risk`/`create_brandconnect_application`/`record_affiliate_click`(13장), `confirm_payment_order`(5장), `rate_limit_hit`(12장), `write_audit`(11장).

## 4. 잡 페이로드 계약

모든 페이로드에 `org_id`, `request_id`를 넣는다. 비밀값은 넣지 않고 id만.

| `job_type` | payload | result | progress 메시지 |
|---|---|---|---|
| `blog.generate` | `{ post_id, keyword, template, length, tone?, mode, outline?, title?, experience_note_ref: 'post', affiliate_auto: boolean, affiliate_account_ids: uuid[], material_ids?: uuid[] }` | `{ post_id, version, word_count, affiliate_cards: number, run_id, awaiting_approval: boolean, model, usage_id }` | 10 "키워드 정리" → 25 "자료 찾는 중" → 55 "본문 작성" → 75 "제휴·SEO 점검" → 90 "규정 검사" → 100 |
| `blog.publish.wordpress` | `{ publication_id, post_id, channel_account_id, rendered_hash }` | `{ external_post_id, published_url }` | 20 렌더 → 60 업로드 → 100 |
| `blog.publish.naver` / `blog.publish.tistory` | 같음 | `{ external_post_id?, published_url?, outcome: published\|unconfirmed, screenshot_path? }` | 10 잠금 → 30 로그인 확인 → 60 원고 입력 → 80 발행 클릭(이후 취소 불가) → 100 |
| `blog.channel.verify` | `{ channel_account_id }` | `{ status: active\|needs_reauth\|error, external_account_id, session_expires_at }` | - |
| `brandconnect.scan` | `{ affiliate_account_id, keyword?, campaign_type? }` | `{ campaigns: [{campaign_id, title, brand, deadline, reward, campaign_type: 'blog'\|'clip'\|'shopping_connect'\|'unknown'}] (≤50), scanned_at }` | - |
| `brandconnect.apply` | `{ application_id, source_app: 'blog'\|'video' }` | `{ external_id?, outcome: submitted\|failed }` | 80 "제출 클릭" 이후 취소 불가. video가 만든 클립형 지원서도 이 잡으로 처리(cross-app, `SHARED_MODULES.md` 17장). 워커는 지원서의 `target_kind`로 제출 양식(블로그 주소/클립 채널 주소)을 고른다 |
| `brandconnect.sync` | `{ affiliate_account_id }` | `{ updated: [{application_id, status}] }` | - |
| `blog.export` | `{ post_ids, format }` | `{ storage_path, count }` | 퍼센트 |
| `blog.ai.rag_ingest` | `{ document_id, collection: 'blog-materials', contains_pii }` | `{ document_id, chunks, embedding_provider, embedding_model }` | 퍼센트 |
| `blog.ai.wiki_ingest` | `{ document_ids[], run_id }` | `{ pages_touched: number(≤5/문서), run_id }` | 퍼센트 |
| `blog.ai.wiki_lint` | `{ run_id, trigger: 'manual'\|'weekly' }` | `{ issues: [{kind, slug, message}], run_id }` | - |

그래프 계약(`POST /graphs/blog.post_draft/runs` 입력 → 출력): 입력 `{ post_id, keyword, template, length, tone?, mode, outline?, title?, experience_note?(마스킹 후), affiliate_auto, material_ids? }`에는 비밀·자격증명 필드가 없다. 출력 `{ title, outline[], body(TipTap JSON), excerpt, tags[], sources: [{type: 'material'|'wiki', id or slug, title}], affiliate: { warnings[], requires_disclosure, product_keywords[] }, seo: { items[] }, compliance: { verdict, issues[] } }`. 워커가 zod로 다시 검증하고 `blog.posts`에 저장한다. 대기 중 run은 `GET /graphs/runs/{id}`에서 `approve` 스텝이 `running`이다.

워커 처리 순서(발행): `claim` → 발행 행 `publishing`(DB가 링크 수·문구 필요 여부 재계산) → `acquire_channel_lock` → 렌더(DB 최신 원고, 대가성 문구 삽입, `disclosure_included` 기록) → 어댑터 → 결과 반영(`published`/`unconfirmed`/`failed`) → `complete_job`/`fail_job` → `release_channel_lock`.

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태 | 공용 webhooks 모듈(서명 필수) | `CORE_SPEC.md` 6장 | 상태 동기화만, 지급은 confirm 경로 |
| 수신 | n8n/Make 콜백(Phase 2) | HMAC 필수 | `X-Request-Id` | automation-core |
| 발신 | `post.published`, `post.failed`, `brandconnect.status_changed`(Phase 2, Business) | HMAC-SHA256 + 타임스탬프 | - | automation-core `emit`. 원본 "내 블로그" API 대체 |

## 6. 외부 API 어댑터

```ts
// workers/blog-worker 계약 예시(구현 파일 아님)
export interface ChannelPublisher {
  channel: 'naver' | 'tistory' | 'wordpress'
  verify(ctx: { account: ChannelAccount; secret: unknown }): Promise<{ externalAccountId: string; sessionExpiresAt?: string; session?: unknown }>
  publish(ctx: { account: ChannelAccount; secret: unknown; signal: AbortSignal; heartbeat(p: number, m: string): Promise<boolean> },
          post: { title: string; html: string; tags: string[]; coverPath?: string }): Promise<{ outcome: 'published' | 'unconfirmed'; externalPostId?: string; url?: string }>
}
```

| 대상 | 호출 위치 | 방식 | 실패 처리 | 쿼터/상한 |
|---|---|---|---|---|
| 워드프레스 REST(`/wp-json/wp/v2/posts`, `tags`, `media`) | 워커 | Basic(애플리케이션 비밀번호). 태그는 검색 후 없으면 생성(`NOMAD Shorts Maker/src/skill/channel-api/wordpress-client.ts:34-55`). Yoast 메타는 플러그인 있을 때만 | 401 → 채널 `error` + 재연결 요청. 5xx → 재시도 | 계정당 30건/일(제안) |
| 네이버 블로그(스마트에디터) | 워커 Playwright | 세션 쿠키 주입 → 글쓰기 → 제목 → 본문 HTML 붙여넣기 → 태그(최대 10) → 발행 → URL 파싱(`[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:180-288`) | 로그인·CAPTCHA 페이지 → `needs_reauth`, 재시도 없음. 발행 클릭 후 URL 미확인 → `unconfirmed` | 5건/일, 10분 간격(제안) |
| 티스토리 | 워커 Playwright | `NOMAD Shorts Maker/src/skill/playwright-engine/tistory-poster.ts:47-85`. 공식 API 제공 여부 미확인 | 네이버와 같음 | 같음 |
| 쿠팡파트너스 | 웹(서버) | HMAC `CEA algorithm=HmacSHA256`(`coupang-client.ts:5-12`), 조직 키 | 4xx → 사용자 오류 표시, 5xx → 1회 재시도 | 제공자 호출 한도 미확인 |
| 텐핑, 네이버쇼핑 커넥트 | - | 공개 API 미확인. 수동 URL 등록만 | - | - |
| 네이버 브랜드커넥트 | 워커 Playwright | `NOMAD Shorts Maker/src/skill/playwright-engine/brand-connect.ts`의 흐름을 셀렉터 상수 파일로 분리해 이식 | 셀렉터 미발견 → failed + 운영 알림(사이트 변경 감지). "지원 완료" 확인 실패 → failed + "네이버에서 확인해 주세요" | 5건/시간, 20건/일 |
| LLM | 웹·워커 | core llm gateway | 5절 | 조직당 60회/분 |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158` 중 blog가 쓰는 것과 제품 확장이다.

| 엔드포인트 | 호출자 | 인증 | blog 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 AI-R4). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `write`: `post_id`가 매핑 org의 원고인지 확인 → 원고 앞 6,000자 + 자료·위키 검색 → `chat` 모델. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /tools/blog/assist` | Next.js 서버(단건 AI 라우트) | 서명 토큰 scope `chat`, `feat=blog.assist`(제안) | 다시쓰기, 태그, 키워드, 개요, 상품 키워드 추출, 메시지 다듬기. 입력 `{ purpose, mode: fast\|quality, ... }` (공용 목록에 없음, 06장 AI-R4) |
| `POST /graphs/blog.post_draft/runs`, `GET /graphs/runs/{id}` | 워커 | 잡 토큰 scope `graph:blog.post_draft`, `jti` 1회 | 초안 생성(4절 계약) |
| `POST /graphs/runs/{id}/resume`, `POST /graphs/runs/{id}/cancel` | Next.js 서버(`ai-approve`, `ai-reject`) | 서명 토큰 scope `graph:blog.post_draft`, `jti` 1회 | 승인 재개·반려(공용 목록에 없음, 06장 AI-R7) |
| `POST /rag/ingest` | Next.js 서버 | 서명 토큰 scope `rag` | 자료 색인(조직 컬렉션 `blog-materials`) |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(AI-R4) | Next.js 서버 | 서명 토큰 scope `wiki` | 위키 |

쓰지 않는 것: `POST /dify/retrieval`(조직 데이터만 있고 운영자 공통 지식이 MVP에 없다, D-18), `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`blog-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `blog-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_BLOG`(Next.js 서버 전용). 정의는 `infra/dify/blog-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `post_id`(선택, UUID 문자열, 대화 시작 때만). 서명 토큰, org, 채널 정보, 자격증명은 넣지 않는다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285`). `DOC_TEMPLATE`의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `write`: HTTP 요청 노드 → 답변 / 분기 `out_of_scope`(채널 로그인·결제·법률 자문 질문): 고정 안내 답변(설정 화면 링크) |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, post_id, mode: "write" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 외부 지식·내장 지식베이스 | 쓰지 않는다(조직 데이터는 외부 지식 API와 Dify 지식베이스 금지, `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:62-65`) |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다 |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| `42501` | 권한 없음(역할, 비멤버, 동의 없음) | 403 |
| `CR001` | 크레딧 부족 | 402 |
| `BL001` | 원고/발행 상태가 요청을 허용하지 않음 | 409 |
| `BL002` | 취소할 수 없는 발행(실행 중·완료) | 409 |
| `BL003` | 컴플라이언스 미통과(FAIL, 미검사, WARN 미확인) | 409 |
| `BL004` | 월 발행 한도 초과(서버 판정) | 402 |
| `BL005` | 채널 사용 불가(비활성, 자동화 위험 동의 없음) | 409 |
| `BL006` | 채널 정책 경고 미확인(네이버 + 쿠팡) | 409 |
| `23505` | 같은 원고·계정의 진행 중 발행 존재 | 409 |
| `23514` | 대가성 문구 불변식 위반(서버 버그) | 500 + 운영 알림 |
| `22023` | 인자·상태 전이 오류 | 409 |
| `JB002` | 이미 실행 중인 잡 | 409 |
| `PM001`/`PM409`/`PM410` | 결제 확인 실패 | 409 + 운영 알림 |
| `P0002` | 대상 없음 | 404 |
| `AI_FAILED` | LLM 실패(환불 완료) | 502 |
| `URL_NOT_ALLOWED` | https 아님, 사설 IP, 허용 도메인 밖 | 422 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| `AI_APPROVAL_REQUIRED` | 그래프로 만든 원고를 승인 전에 발행·예약하려 함 | 409 + "발행 전 확인을 먼저 해 주세요" |
| `AI_RUN_NOT_WAITING` | 승인 대기 중이 아닌 run을 승인·반려하려 함(이미 처리, 취소, 실패) | 409 |
| `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 |
| `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| `AI_DAILY_LIMIT` | 하루 채팅 턴 상한(`features.ai_chat_turns_per_day`) | 429 |
| `RATE_LIMITED` | 레이트 리밋 | 429 |
| `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | 403 |
| `VOICE_TOO_LONG` | 받아쓰기 5분·20MB, 채팅 질문 60초·5MB 초과 | 413 |
| `CONSENT_VERSION_MISMATCH` | 고지문 버전이 서버 값과 다름 | 409 |
| `MATERIAL_DUPLICATE` | 같은 내용(`content_hash`)의 자료가 이미 있음 | 409 |
| `MATERIAL_TYPE_NOT_ALLOWED` | 허용하지 않는 파일 형식·크기 | 400 |
| `PLAN_LIMIT`, `PLAN_REQUIRED` | 자료 문서 수 한도, 위키 플랜 부족 | 403 |
| `WIKI_VERSION_CONFLICT` | 위키 저장 시 `expected_version`이 현재 버전과 다름(`docs/file/03-설계/공용코어/LLM_WIKI.md:31`) | 409 |
| `INTERNAL_KEY_INVALID` | 워커 키 또는 Dify 내부 키 불일치 | 401 |
| FastAPI `AI_TOKEN_INVALID` | 서명, `aud`, scope, 만료, `jti` 재사용 | 401 |

## 8. 인증 단계 라우트 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(이하 AUTH_ROADMAP) 2장, 3.2절, 7.2.3절이다. 아래 라우트는 `src/lib/auth/`의 `getAuthConfig`, `isMockAuthAllowed`, `finishLogin`만 쓰고, 기능 라우트(2절)는 단계를 모른다. 블로그 채널 연결(2절 `/api/channels`, 네이버·티스토리 Playwright 로그인)은 이 절과 무관하다.

| 메서드 경로 | 단계 | 입력 | 처리 | 출력 | 오류 |
|---|---|---|---|---|---|
| POST `/api/dev/login` | A(로컬 전용) | `{ persona: 'owner'\|'admin'\|'member'\|'viewer'\|'outsider'\|'no_app'\|'suspended'\|'ops'\|'owner_pro', next? }`(zod, 목록 밖 422) | `isMockAuthAllowed()` 거짓이면 404(존재 자체를 숨김) → 쿠키 세션용 서버 클라이언트로 `signInWithPassword(<persona>@dev.test, DEV_SEED_PASSWORD)` → `finishLogin('blog', next)`(AUTH_ROADMAP 3.2절 2~5번, 아래 콜백 행의 (2)~(7). 시드 페르소나는 이메일 제공자 계정이라 (5) 약관 단계를 건너뛴다) | 303 → 반환 경로(`/dashboard` 기본) | 404(판정 거짓), 401 `DEV_PERSONA_MISSING`(시드 안 됨), 422. 레이트 리밋 대상 아님(로컬 전용) |
| POST `/api/dev/logout` | A | `{}` | 판정 거짓이면 404, `signOut` | 303 → `/login` | 404 |
| GET `/auth/callback` | B·C(C1 카카오, C2 `custom:naver` 포함) | `?code&next` | `finishLogin`: (1) `exchangeCodeForSession`(PKCE) (2) `session_context('blog')` 1회 (3) `entitled=false`면 `rpc('bootstrap_app_for_org', { p_app_id: 'blog' })` 1회 후 재조회(blog는 open. 모놀리스는 트리거가 이미 부트스트랩해 무동작) (4) pending → `/pending`, suspended → 403 화면 (5) OAuth 제공자 첫 로그인이고 약관 미동의면 `/onboarding/terms`(03장 7.3절. 이메일 가입자는 가입 폼에서 동의해 건너뜀) (6) `next` 화이트리스트(`/`로 시작, `//`·`@`·`\` 없음, origin `NEXT_PUBLIC_APP_URL` 고정) 아니면 `/dashboard` (7) 감사 `auth.login {provider, first_login}` | 302 | `/login?error=callback`(코드 없음·재사용·만료), 프로필 없음 → 로그아웃 후 `/login` |
| GET `/auth/naver/start` | C2 브리지 경로만(`NAVER_AUTH_PATH=bridge`) | `?next` | 32바이트 state → HttpOnly·Secure·SameSite=Lax 서명 쿠키(`AUTH_BRIDGE_SECRET`, 10분) → 네이버 authorize 302. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 302 | 429 |
| GET `/auth/naver/callback` | C2 브리지 경로만 | `?code&state` | 쿠키 state 상수 시간 비교 후 삭제 → 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(provider `naver`, `response.id`) 조회 → 있으면 매직링크 `verifyOtp`로 세션, 없고 같은 이메일 사용자도 없으면 `auth.admin.createUser` + 링크 행 → `finishLogin`. 네이버 토큰은 저장하지 않음 | 302 | `/login?error=state`(불일치·없음·만료), `/login?error=email_in_use`(같은 이메일의 다른 가입자, 자동 병합 금지), `/login?error=callback` |
| POST `/auth/link/naver`(제안) | C2 브리지, 설정 → 로그인 방법 | 로그인 세션 | 브리지 1~3번 후 링크 행 INSERT. 이미 다른 사용자에 연결된 네이버 id면 거부 | 302 → `/settings/login-methods` | 409 `IDENTITY_IN_USE` |

`supabase_custom` 경로(C2)와 카카오(C1)는 브라우저 `signInWithOAuth({ provider: 'custom:naver' \| 'kakao', options: { redirectTo: <APP_URL>/auth/callback?next=... } })`로 시작하고 같은 `/auth/callback`을 쓴다. Google(B)은 `queryParams: { prompt: 'select_account' }`를 더한다(AUTH_ROADMAP 5.2절).

| 오류 코드 | 의미 | HTTP |
|---|---|---|
| `DEV_PERSONA_MISSING` | 개발용 페르소나 계정이 로컬 DB에 없음(시드 스크립트 미실행) | 401 |
| `IDENTITY_IN_USE` | 그 네이버 id가 이미 다른 사용자에 연결됨 | 409 |
| 쿼리 `error=callback`, `error=state`, `error=email_in_use` | 03장 7.2절 문구 | 302 리다이렉트 |
