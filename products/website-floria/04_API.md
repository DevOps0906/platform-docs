# 04 API: Floria (website-floria)

작성일 2026-10-12. 코드 블록은 계약 예시다. 수치 중 근거가 없는 것은 제안이다.

2026-10-13 개정: 방문자 AI 상담·음성 Route Handler(2.2절), 운영 AI 관리 Route Handler, 제품 RPC `update_ai_settings`(3장), FastAPI·Dify 계약(6장), AI 오류 코드(7장)를 추가했다. 서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다.

## 1. 원칙

| 항목 | 내용 |
|---|---|
| 인증 | 공개 API 3종은 로그인 없음. 콘솔은 `requireSession('site')`(401 미로그인, 403 pending/suspended, 402 대신 403 엔타이틀먼트 없음)(`SHARED_MODULES.md` 2장). 세션은 모든 인증 단계(A Mock, B Google)에서 실제 Supabase JWT이고 `requireSession`은 같다(8절) |
| 쓰기 경로 | 방문자 쓰기는 Route Handler가 service_role로 `site.*` RPC를 호출한다. 브라우저의 직접 RPC 호출은 설계에서 제외(DB는 방어 2선으로 `submit_inquiry`만 anon에 연다). AI 상담은 `site.*`에 쓰지 않고 `core.ai_*`에만 쓴다(문의 전환은 방문자가 기존 `POST /api/inquiries`로 직접 제출) |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler가 부른다(`docs/products/_platform-core/SECURITY_BASELINE.md:299`) |
| 방문자 식별 | 서명된 쿠키 `__Host-site_vid`(HttpOnly, Secure, SameSite=Lax)를 `/api/ai/conversations`가 발급한다. `visitor_key = sha256(쿠키 값)`만 DB에 저장하고, 매 턴 쿠키와 대화의 `visitor_key`가 같아야 한다. 대화 id만으로는 이어 쓸 수 없다 |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT를 발급: `iss=site`, `aud=platform-ai:site`, `org`(= `sites.org_id`), `app=site`, `sub=visitor:<visitor_key>`(방문자) 또는 사용자 id(운영 콘솔), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 사이트 행에서만 가져오고 요청 본문의 org는 쓰지 않는다(`docs/products/_platform-core/AI_ARCHITECTURE.md:33-42`) |
| AI 레이트 리밋 | 01_PRD.md 5장 표의 키 규약 `site:ai-start:*`, `site:ai-turn:*`, `site:voice-stt:*`, `site:voice-tts:*`. 초과 시 429 + `Retry-After` |
| 스트리밍 | 상담은 SSE(`text/event-stream`). Dify HTTP 노드가 전체 답을 돌려준 뒤 전달하므로 그 전에는 `status` 이벤트만 간다 |
| 크레딧 | 없음. AI·음성도 크레딧 선차감·정산·환불이 없고 운영자 조직 예산으로 처리한다(01_PRD.md 4.1절) |
| 멱등 | 문의: 클라이언트 `request_id`는 쓰지 않는다. 중복 제출은 이메일당 레이트 리밋이 막는다. 확인/해지는 DB 함수가 멱등이다 |
| 응답 봉투 | 성공 `{ "ok": true, "data": {...} }`, 실패 `{ "ok": false, "error": { "code": "...", "message": "..." } }` |
| 레이트 리밋 | 01_PRD.md 5장 표. Route Handler는 IP 해시 키로 `core.rate_limit_hit` 호출, 초과 시 429+`Retry-After` |
| IP 해시 | `sha256(salt(yyyy-mm-dd, IP_HASH_SALT_SEED) + ip)`의 hex. 원문 IP는 저장·로그하지 않는다 |
| 본문 크기 | 16KB 초과는 413 |
| Origin | `Origin`이 `sites.allowed_origins`(없으면 `NEXT_PUBLIC_SITE_URL`)에 없으면 403. CORS `*` 금지 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/inquiries` | 공개 | `kind` enum 7, `name` 1~80, `email`, `phone?` 정규식, `message` 10~2000, `locale` ko/en, `consent_version` 문자열, `source_path?`, `hp`(허니팟), `elapsed_ms` 정수, `turnstile_token` | `{reference}` 8자리 | 0 | `site.submit_inquiry` | 400 `invalid_input`, 403 `forbidden_origin`/`captcha_failed`, 413, 422 `consent_required`, 429 `rate_limited`, 404 `site_unavailable`, 500 |
| `POST /api/newsletter/subscribe` | 공개 | `email`, `locale`, `consent_version`, `source_path?`, `hp`, `elapsed_ms`, `turnstile_token` | 항상 `202 {}`(구독 여부 비공개) | 0 | `site.subscribe_newsletter` 후 `send_confirmation=true`면 확인 메일 | 400, 403, 422, 429, 500. 이미 확정/허니팟도 202 |
| `POST /api/newsletter/confirm` | 공개(토큰) | `token` | `{status}` | 0 | `site.confirm_newsletter` | 400 `invalid_token`, 410 `expired_token`, 404 |
| `POST /api/newsletter/unsubscribe` | 공개(토큰) | `token`. 원클릭은 `List-Unsubscribe=One-Click` 본문 | `{status}` | 0 | `site.unsubscribe_newsletter` | 400, 404 → 같은 완료 문구 |
| `GET /api/health` | 공개 | - | `{status:"ok", version}` 만(비밀 없음) | 0 | 없음 | - |

`GET`으로 상태를 바꾸는 엔드포인트는 없다. 확인/해지 페이지(`/newsletter/...`)의 GET은 토큰 검증만 하고 버튼을 보인다(메일 보안 스캐너 선열람 대응).

콘솔 변경은 별도 API 없이 서버 액션에서 사용자 세션 클라이언트로 RPC를 호출한다(RLS와 RPC 내부 검사가 권한을 판정). 콘솔 조회는 컬럼 명시 `select`.

### 2.1 토큰 규격

| 항목 | 내용 |
|---|---|
| 형식 | `base64url(JSON payload) + "." + base64url(HMAC-SHA256(key, payload))` |
| payload | `{ "sid": "<subscriber uuid>", "typ": "c" 또는 "u", "exp": <unix 초, 확인은 발급+48h(제안), 해지는 생략> }` |
| 검증 | 상수 시간 비교, `typ` 일치, `exp` 확인. 실패는 400/410 |
| 키 | `SITE_TOKEN_HMAC_KEY` 32바이트 이상, 없으면 기동 실패 |
| 이유 | DB에 토큰을 저장하지 않아도 되고, 토큰이 유출돼도 해당 구독자 1명의 확인/해지만 가능하다 |

### 2.2 AI·음성 Route Handler (2026-10-13)

모든 AI Route Handler는 `runtime = 'nodejs'`다. 사이트 스위치(`sites.accepts_ai_chat`, `accepts_voice`)가 꺼져 있으면 `config`를 뺀 나머지는 404 `ai_disabled`다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `GET /api/ai/config` | 공개 | - | `{ chat, voice, notice_version, voice_notice_version }`(스위치 off면 둘 다 false, 항상 200, `Cache-Control: max-age=60`) | 0 | 없음 | `site.sites` 조회(`SITE_SLUG`, service_role) | - |
| `POST /api/ai/conversations` | 공개 | `{ notice_version, turnstile_token, channel: 'text'\|'voice' }` | `{ conversation_id }` + Set-Cookie(방문자 쿠키가 없으면 발급) | 0 | 없음 | Origin, Turnstile `siteverify`, `rate_limit_hit` 2종(`site:ai-start:ip`, `:v`), `ai_conversations` INSERT(service_role: org=`sites.org_id`, app `site`, `visitor_key`, `dify_user`=HMAC(org:visitor)) | 403 `forbidden_origin`/`captcha_failed`, 404 `ai_disabled`, 409 `consent_version_mismatch`, 429 `ai_rate_limited` |
| `POST /api/ai/chat` | 대화 주인(쿠키) | `{ conversation_id, request_id(uuid), message(1..300) }` | SSE `status`, `message`, `citations`, `inquiry_hint`, `fallback`, `done` / `error` | 0 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki graph:site.consult`, `conv`=대화 id, `feat=site.consult`) | `rate_limit_hit` 4종(턴 방문자·IP·사이트 시간당·일일), 사용자 `ai_messages` INSERT(마스킹본), `ai_usage` 기록은 FastAPI | 404 대화, 409 `ai_turn_limit`/`ai_conversation_closed`, 413 `input_too_long`, 429 `ai_rate_limited`/`ai_budget_exhausted`, 503 `ai_unavailable` |
| `GET /api/ai/conversations/[id]` | 대화 주인(쿠키) | - | `{ messages: [{ role, content, citations, created_at }] }` | 0 | - | `ai_messages` SELECT(service_role, 쿠키 일치 확인 후) | 404 |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete`(개인정보 없음) | 404 |
| `POST /api/voice/sessions` | 대화 주인, `accepts_voice` | `{ conversation_id, voice_notice_version }`(서버 상수와 같아야 함) | `{ session_id }` | 0 | - | `voice_sessions` INSERT(`visitor_key`) | 403 `voice_notice_required`, 404 `voice_disabled`, 409 `consent_version_mismatch` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 3MB 이하, 30초 이하), session_id, request_id }` | `{ text, duration_seconds, provider }` | 0 | `resolve_ai_route(org,'site','voice_consult','stt')` → 오픈소스 `/stt`(scope `voice`) 또는 ElevenLabs SDK | `voice_jobs`(`store_audio=false`), `ai_usage`, `rate_limit_hit('site:voice-stt:*')` | 403 `voice_notice_required`, 413 `voice_too_long`, 429, 503 `ai_unavailable` |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만, 500자 이하만) | `audio/mpeg` 스트림 | 0 | `voice_consult`/`tts` 체인(대체 허용) | `voice_jobs`, `ai_usage`, `rate_limit_hit('site:voice-tts:*')` | 404, 422 `tts_text_too_long`, 429, 503 |
| `POST /api/internal/wiki-lint` | 워커(`X-Worker-Key`) | - | `{ run_id }` | 0 | FastAPI `/wiki/lint`(scope `wiki`, org=사이트 조직) | - | 401 `internal_key_invalid` |
| `PATCH /api/admin/ai/settings` | owner, admin | `{ accepts_ai_chat?: boolean, accepts_voice?: boolean }` | 사이트 행 | 0 | - | 사용자 세션 `rpc('update_ai_settings')` | 403, 404 |
| `POST /api/admin/ai/cross-border` | owner, admin | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | - | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })` | 409 `consent_version_mismatch`, 403 |
| `GET /api/admin/ai/usage` | owner, admin, member | `?days=30`(최대 90) | 제공자·기능·상용/오픈소스별 집계 | 0 | - | `core.ai_usage` SELECT(RLS 조직 멤버) | 403 |
| `GET /api/admin/ai/unanswered` | owner, admin, member | `?days=30` | 근거 없음 질문(마스킹본)과 횟수 | 0 | - | service_role로 `ai_messages` 집계(citations가 빈 assistant 직전의 user 메시지), 감사 `ai.unanswered.read` | 403 |
| `POST /api/admin/knowledge/documents` | owner, admin | multipart md(2MB 이하), `{ title, doc_type: 'case'\|'plant'\|'faq', reviewed_at, consent_ref? }` | `{ document_id }` | 0 | FastAPI `/rag/ingest`(scope `rag`, org=사이트 조직, `source_type=text`) | 감사 `knowledge.upload` | 400 `consent_ref_required`(case), 409 중복(`content_hash`), 403 |
| `POST /api/admin/wiki/ingest`, `POST /api/admin/wiki/lint` | owner, admin | `{ document_ids?: uuid[] }` | `{ run_id }` | 0 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | - | 403 |
| `PATCH /api/admin/wiki/pages/[...slug]` | owner, admin | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 6절 요청 9) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 `source_required`, 409 `wiki_version_conflict` |

읽기는 Route Handler 없이 RLS로 직접 한다: 콘솔의 `core.ai_documents`, `core.wiki_pages`, `core.wiki_revisions`, `core.ai_org_settings`(조직 멤버, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:620-632`). 방문자 대화(`user_id` null)는 어떤 authenticated 사용자도 읽지 못한다(`ai_conversations_select`가 `user_id = auth.uid()`, `:636-638`). 공개 위키 `/guide`는 서버 컴포넌트가 사이트 조직의 `published` 페이지만 service_role로 읽어 ISR로 그린다(사용자 입력이 쿼리에 들어가지 않는 slug 조회만).

문의 전환은 새 API가 없다. 방문자가 `/contact?from=consult`의 폼에서 `POST /api/inquiries`를 호출하며 `source_path`는 `/consult`다. `inquiry_hint`는 브라우저 sessionStorage에만 있고 서버에 저장되지 않는다.

## 3. RPC (SECURITY DEFINER)

모든 함수는 `set search_path = ''`. SQL은 `docs/products/_supabase-modular/migrations/2200_site.sql`. 모놀리스는 `public.` 접두사로 같다.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `site.submit_inquiry(p_site_slug, p_kind, p_name, p_email, p_phone, p_message, p_locale, p_consent_version, p_source_path, p_honeypot, p_elapsed_ms) returns jsonb` | anon, authenticated, service_role | 사이트 active+접수 on+엔타이틀먼트, 사이트 홍수 제한, 허니팟, 입력 검증, 동의 버전, 이메일 제한, 일 한도, 스팸 점수 | `{ok, reference}`(허니팟이면 reference null) | SI001, SI002, SI003, SI004 |
| `site.subscribe_newsletter(p_site_slug, p_email, p_locale, p_consent_version, p_source_path, p_honeypot, p_elapsed_ms) returns jsonb` | service_role | `is_service_caller`, 위와 유사, 확인 메일 재발송 최대 5회 | `{ok, subscriber_id, status, send_confirmation}` | 42501, SI001~SI004 |
| `site.confirm_newsletter(p_subscriber_id) returns jsonb` | service_role | `is_service_caller` | `{ok, status, changed}`. pending만 confirmed로 | 42501, P0002 |
| `site.unsubscribe_newsletter(p_subscriber_id) returns jsonb` | service_role | `is_service_caller` | `{ok, status, changed}` | 42501, P0002 |
| `site.set_inquiry_status(p_id, p_to, p_note) returns site.inquiries` | authenticated | 소유 조직의 owner/admin/member, 엔타이틀먼트, 상태값, 메모 1000자, 전이 트리거 | 갱신된 행 | 42501, P0002, 22023 |
| `site.delete_inquiry(p_id) returns void` | authenticated | owner/admin | 없음 | 42501, P0002 |
| `site.erase_subscriber(p_id) returns void` | authenticated | owner/admin | 없음 | 42501, P0002 |
| `site.update_site_settings(p_site_id, p_name, p_notify_email, p_accepts_inquiries, p_accepts_newsletter, p_privacy_policy_version) returns site.sites` | authenticated | owner/admin, 엔타이틀먼트. null 인자는 "변경 없음" | 갱신된 행 | 42501, P0002 |
| `site.update_ai_settings(p_site_id, p_accepts_ai_chat, p_accepts_voice) returns site.sites` | authenticated | owner/admin, 엔타이틀먼트. null 인자는 "변경 없음". 상담을 끄면 음성도 함께 꺼진다(음성은 상담이 켜져 있을 때만 켜짐, 테이블 CHECK). 감사 `site.ai_settings` | 갱신된 행 | 42501, P0002 |
| `site.provision_site(p_org_id, p_slug, p_name, p_brand_key, p_allowed_origins, p_notify_email) returns site.sites` | service_role | 조직의 `site` 엔타이틀먼트 | 새 행 | 42501, 23505(slug 중복) |
| `site.purge_expired() returns jsonb` | service_role | `is_service_caller` | 삭제·비식별화 건수 | 42501 |

코어 RPC는 인용만 한다: `core.rate_limit_hit`(`CORE_SPEC.md` 12장), `core.write_audit`(11장), `core.session_context`(2.3절). AI·음성 코어 RPC(2026-10-13): `core.set_ai_cross_border_ack`(owner/admin, `0008_core_ai.sql:553-575`), `core.resolve_ai_route`·`core.match_ai_chunks`(service_role 전용), `core.purge_wiki_page`(service_role).

## 4. 잡 페이로드 계약

해당 없음. `core.jobs`를 쓰지 않는다(02_ARCHITECTURE.md 4장). 알림 워커의 입출력만 적는다.

| 단계 | 내용 |
|---|---|
| 입력 | `select id, site_id, kind, created_at from site.inquiries where notified_at is null and status = 'new' order by created_at limit 50` |
| 알림 대상 | 해당 사이트의 `notify_email`. 비어 있으면 건너뛰고 `notified_at`을 건드리지 않는다 |
| 메일 본문 | 종류, 접수 시각, 콘솔 링크. 이름, 이메일, 내용은 넣지 않는다(제안) |
| 완료 | `update site.inquiries set notified_at = now() where id = any(:ids)` |

AI 비동기 작업(지식 색인, 위키 ingest/lint)의 실행·상태 추적은 02_ARCHITECTURE.md 4.1절이 정한다(`core.jobs` 없음). 페이로드는 FastAPI 요청 본문이며 6.1절에 둔다.

## 5. 웹훅

| 구분 | 내용 |
|---|---|
| 수신 | MVP 없음. Phase 2: 메일 사업자의 바운스/스팸 신고 웹훅을 `webhook_events`(서명 검증, `(provider,event_id)` 멱등)로 받아 해당 구독자를 `unsubscribed`로 처리. 사업자 미정(D-6) |
| 발신 | 없음 |

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| CAPTCHA 검증(제안: Cloudflare Turnstile `siteverify`, 스펙 미확인) | `src/lib/forms/captcha.ts` | 검증 서비스 장애 시 폼 제출을 막는다(fail-closed, 스팸 유입 방지). 5초 타임아웃 | 사업자 기준(미확인) |
| 메일 발송(사업자 미정) | `src/lib/mail/`, `worker/notify/` | 확인 메일 실패: subscribe는 202를 유지하고 오류 로그, 사용자는 재신청 가능. 알림 실패: `notified_at` 유지, 다음 주기 재시도 | 미확인 |
| Supabase | `src/lib/supabase/` | RPC 오류는 7장 표로 매핑. 타임아웃 10초(제안) | 플랜 기준 |
| FastAPI AI 서비스(그래프, 도구) | `src/app/api/ai/`(서명 토큰) | 체인 대체(라우터) → 답변 1회 재작성(그래프) → 정형 안전 응답. 20초 타임아웃 후 `ai_unavailable` | 상담 1턴당 `answer` 호출 1~2회. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*` | 운영자 조직이 국외 이전에 동의한 경우에만 체인에 있다. 실패·429 → 체인 다음(`voice_jobs.fallback_from`), 모두 실패 → 503 | 요금·상업 이용 조건·데이터 보관 구현 시 확인(01_PRD.md D-14) |
| 오픈소스 음성 서버 | `src/app/api/voice/*`(서명 토큰 scope `voice`) | 같음 | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). floria는 30초·500자 |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 floria가 쓰는 것이다.

| 엔드포인트 | 호출자 | 인증 | floria 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 6절 요청 9). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `consult`: 매핑 org(= 사이트 조직)의 지식·위키 컬렉션을 검색해 그래프 `site.consult`를 실행하고 assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다. 응답은 6.2절 형식 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki graph:site.consult` | `/tools/answer`와 같은 처리 |
| `POST /rag/ingest` | Next.js 관리자 | 서명 토큰 scope `rag`(org=사이트 조직) | 지식 색인(`source_type=text`, `doc_type`, `reviewed_at`, `consent_ref` 메타데이터). 내용 해시 중복은 409 |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(요청 9) | Next.js 관리자, 워커 경유 | 서명 토큰 scope `wiki` | 위키 |
| `GET /graphs/runs/{id}` | Next.js 관리자 | 서명 토큰 scope `graph:site.consult` | 운영 점검용(상담 실행 기록 조회) |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 직접 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다), `POST /dify/retrieval`(외부 지식 API를 쓰지 않고 그래프가 FastAPI 안에서 검색한다).

### 6.2 Dify Chatflow 계약 (`site-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `site-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_SITE`(Next.js 서버 전용). 정의는 `infra/dify/site-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`, `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID). 서명 토큰, org, 방문자 키, 개인정보는 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`) |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `consult`: HTTP 요청 노드 → 답변 / 분기 `off_topic`: 고정 안내 답변(같은 JSON 형식) |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, mode: "consult" }`, 타임아웃 20초 |
| HTTP 응답 | `{ answer, citations: [{ type: "case"\|"plant"\|"faq"\|"wiki", id or slug, title }], no_source: boolean, fallback: boolean, inquiry_hint: { kind, draft } \| null, usage: { provider, model, input_tokens, output_tokens } }` |
| 답변 노드 | HTTP 노드 본문(JSON 문자열)을 그대로 돌려주고 Next.js가 zod로 파싱한다. 파싱 실패는 `ai_unavailable`(제안, 구조화 출력 처리는 설치한 Dify 버전 문서로 구현 시 확인) |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages`(30일 후 삭제) |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

접두사 `SI`는 `DB_CONVENTIONS.md:22`의 site 제안값이다.

| SQLSTATE | 의미 | HTTP | error.code |
|---|---|---|---|
| SI001 | 레이트 리밋 초과 | 429 + `Retry-After` | `rate_limited` |
| SI002 | 사이트 없음, 중지, 접수 off, 엔타이틀먼트 없음(구분하지 않음) | 404 | `site_unavailable` |
| SI003 | 입력 검증 실패 | 422 | `invalid_input` |
| SI004 | 동의 누락 또는 정책 버전 불일치 | 422 | `consent_required` |
| 42501 | 권한 없음 | 403 | `forbidden` |
| 22023 | 인자 오류, 허용되지 않은 상태 전이 | 409 | `invalid_state` |
| P0002 | 대상 없음 | 404 | `not_found` |
| 23505 | slug 중복 | 409 | `conflict` |
| 그 외 | 예상 못 한 오류 | 500 | `server_error`(내부 메시지 비노출) |

앱 계층 코드: `captcha_failed` 403, `forbidden_origin` 403, `payload_too_large` 413, `invalid_token` 400, `expired_token` 410.

AI·음성 코드(2026-10-13). 이 제품의 `error.code`는 소문자 snake_case다.

| 코드 | 의미 | HTTP |
|---|---|---|
| `CR001` | 크레딧 부족. 이 제품 경로(방문자·운영자 모두 크레딧 없음)에서는 발생하지 않는다. 코어 AI 함수가 던지면 `ai_unavailable`로 처리하고 운영 알림 | 402(미사용) |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(같음) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| `ai_disabled` | 사이트의 상담/음성 스위치가 꺼져 있음 | 404 |
| `ai_unavailable` | 체인의 모든 제공자 실패, Dify·FastAPI 모두 실패 | 503 |
| `ai_conversation_closed` | 닫힌 대화 | 409 |
| `ai_turn_limit` | 대화당 10턴 초과 | 409 |
| `ai_rate_limited` | 방문자·IP·사이트 시간당 한도(응답에 `reason`: `visitor`/`ip`/`site`) | 429 + `Retry-After` |
| `ai_budget_exhausted` | 사이트 일일 상한(`SITE_AI_DAILY_TURNS`·`SITE_AI_DAILY_VOICE`) 도달. 응답에 문의 폼 경로 포함 | 429 |
| `input_too_long` | 메시지 300자 초과 | 413 |
| `consent_version_mismatch` | 상담·음성·국외 이전 고지문 버전이 서버 값과 다름 | 409 |
| `voice_notice_required` | 음성 처리 고지 미확인 | 403 |
| `voice_disabled` | 음성 스위치 꺼짐 | 404 |
| `voice_too_long` | 30초 또는 3MB 초과 | 413 |
| `tts_text_too_long` | 읽어 줄 답변이 500자 초과 | 422 |
| `consent_ref_required` | 시공 사례 지식에 고객 동의 증빙 없음 | 400 |
| `source_required` | 출처 없는 위키 페이지 게시 | 409 |
| `wiki_version_conflict` | 위키 저장 시 `expected_version`이 현재 버전과 다름(`docs/products/_platform-core/LLM_WIKI.md:31`) | 409 |
| `internal_key_invalid` | 워커 키 또는 Dify 내부 키 불일치 | 401 |
| FastAPI `ai_token_invalid` | 서명, `aud`, scope, 만료, `jti` 재사용 | 401 |

## 8. 인증 단계 엔드포인트 (2026-10-14 추가, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.2절. 이 제품은 C단계를 제외하므로 네이버 브리지 경로(`/auth/naver/*`)가 없다.

| 메서드 경로 | 단계 | 입력 | 출력 | 동작 | 오류 |
|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | `{ persona: string, next?: string }`. persona는 05장 10절 키 목록(zod enum) | 303 → `next`(화이트리스트) 또는 `/admin` | `isMockAuthAllowed()` 확인 → 쿠키 세션용 서버 클라이언트로 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('site', next)` | 판정이 거짓이면 404(존재 자체를 숨김). 모르는 persona 400 `invalid_input`. 레이트 리밋 대상 아님(로컬 전용) |
| `GET /auth/callback` | B | `code`, `next?` | 302 | `finishLogin('site', next)`: (1) `exchangeCodeForSession`(PKCE) (2) `session_context('site')` 1회 (3) invite 앱이므로 `bootstrap_app_for_org`를 호출하지 않는다. `entitled=false`면 `/admin/no-access` (4) pending → 안내, suspended → 403 (5) `next`가 `/`로 시작하고 `//`·`@`·`\`가 없을 때만 그 경로, 아니면 `/admin`. origin은 `NEXT_PUBLIC_SITE_URL` 고정 (6) 감사 `auth.login`(provider, 첫 로그인 여부. 토큰·코드 미기록) | 코드 없음·재사용·만료 → `/admin/login?error=callback`. 프로필 없음 → 로그아웃 후 `/admin/login` |
| `GET /auth/naver/start`, `GET /auth/naver/callback` | C2 | - | - | 만들지 않는다(C 제외) | - |

| 오류 코드(쿼리) | 의미 | 위치 |
|---|---|---|
| `error=callback` | 콜백 코드 교환 실패 | `/admin/login` |
| `error=state`, `error=email_in_use` | C2 브리지 전용 | 해당 없음 |
| `/admin/no-access` | 로그인은 됐으나 `site` 엔타이틀먼트 없음(초대받지 않은 이메일) | 콘솔 |

`finishLogin`은 `/api/dev/login`과 `/auth/callback`이 같이 쓴다. 그래서 A단계의 `site_pending`(엔타이틀먼트 있음, 사이트 없음)·`no_app`(엔타이틀먼트 없음) 페르소나로 B단계 분기를 미리 검증한다. 콘솔 변경은 계속 서버 액션 + 사용자 세션 클라이언트(2절 끝 문단)이며 단계와 무관하다.
