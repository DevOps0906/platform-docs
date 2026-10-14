# 04 API: Toon Factory

작성일 2026-10-12. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다. 제품 RPC 정본은 `docs/products/_supabase-modular/migrations/2000_toon.sql`.

2026-10-13 개정: AI·음성 Route Handler(2.1절), 그래프 호출과 새 잡 페이로드(4절), FastAPI 엔드포인트와 Dify 계약(6.1·6.2절), AI 오류 코드(7절)를 추가했다. 제품 스키마 함수는 늘리지 않았다(AI 표를 만들지 않음, 05장 6절).

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 Route Handler는 진입부에서 `requireSession('toon')`(`SHARED_MODULES.md:46-72`). 미로그인 401, pending/suspended 403, 엔타이틀먼트 없음 402. 세션은 모든 인증 단계(A Mock, B Google·이메일, C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다. 단계별 로그인 경로는 8절 |
| 콘텐츠 CRUD | 작품, 캐스트, 회차, 컷은 브라우저가 `supabase.schema('toon')`로 직접 읽고 쓴다(RLS + 한도 트리거). 서버가 콘텐츠를 대신 쓸 때도 사용자 세션 클라이언트를 써서 RLS와 한도를 그대로 적용한다. service_role로 콘텐츠를 쓰는 것은 운영 도구뿐 |
| 서버 전용 | 크레딧, 잡 등록, 서명 URL, 내보내기 행, AI 생성 행, 결제는 Route Handler(service_role) |
| 멱등 | 유료·비동기 요청 본문에 클라이언트 UUID `requestId`. 키: `consume:toon:<requestId>`, `job:toon:<requestId>`(`CORE_SPEC.md:185-194`). `toon.generations.request_id`, `toon.exports.request_id` 유일 |
| 선차감 위치 | 엔타이틀먼트·플랜 검사 → 입력 검증 → compliance → `consume_credits` → 제품 행 INSERT → `enqueue_job`. 잡 등록 실패 시 같은 요청에서 `refund_credits` |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. `code`는 SQLSTATE 또는 제품 코드 |
| 레이트 리밋 | `core.rate_limit_hit('toon:<route>:<org_id>', limit, window)`. 값은 01장 5절 |
| 입력 검증 | zod. 본문 1MB 상한(웹훅 포함) |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify·FastAPI·LLM·음성 제공자를 직접 호출하지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:299`). Next.js → FastAPI는 EdDSA 서명 토큰(`iss=toon`, `aud=platform-ai:toon`, 10분), Dify 경로는 대화 매핑이다 |
| AI 선차감·정산 | 채팅·음성·위키 갱신은 `consume_credits` 선차감 → 호출 → 정산(`refund_credits` 또는 추가 차감). 콘티·대사·배경은 정액 선차감(차액 없음). 키: `conv:<id>:turn:<n>`, `voice:<id>`, `run:<id>`, `consume:toon:<requestId>` (01장 4.6절) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 코어/제품 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/session` | 로그인 | - | `SessionContext` + `features` | 0 | `core.session_context('toon')`, `toon.plan_features` | 401 |
| `POST /api/catalog/sign` | member | `{ assetIds: uuid[1..200], variant: 'editor' }` | `{ urls: {assetId: url}, denied: uuid[] , expiresAt }` | 0 | `toon.org_asset_access` → Storage 서명 URL(`toon-catalog`, 15분) | 403 `TN003`(전부 거부 시), 429 |
| `POST /api/storyboard` | member | `{ requestId, episodeId, synopsis(1..2000), cutCount(4..30), tone: 'daily'\|'info'\|'comic'\|'emotional', castIds: uuid[1..6] }` | 202 `{ jobId }` | 3 | `consume_credits`, `enqueue_job('toon.ai','storyboard.generate')`(워커가 그래프 `toon.storyboard` 실행, 4.1절) | 402 `CR001`, 422(인스타툰 cutCount>10), `TN006` |
| `POST /api/dialogue/polish` | member | `{ requestId, cutId, layerId, text(1..120), tone }` | `{ options: string[3] }` | 1 | 서명 토큰 scope `graph:toon.dialogue` → FastAPI `POST /graphs/toon.dialogue/runs`(동기), `consume_credits`(정액 1), 실패 시 `refund_credits` | 402, `TN006` |
| `POST /api/logline` | member | `{ requestId, keywords: string[1..5](각 1..20), genre?, tone, format: 'instatoon'\|'webtoon', castIds?: uuid[0..6], step: 'logline'\|'synopsis', pickedLogline?(1..80) }` | `{ loglines: string[3] }` 또는 `{ synopsis, beats: string[] }` | 1(같은 `requestId`의 두 단계 합계) | 서명 토큰 scope `graph:toon.logline` → FastAPI `POST /graphs/toon.logline/runs`(동기), `consume_credits`(정액 1, 첫 단계에서), 실패 시 `refund_credits`. 결과는 저장하지 않는다(사용자가 "작품에 적용"하면 브라우저가 RLS로 `series.synopsis` 또는 `episodes.logline` 갱신) | 402, `TN006` |
| `POST /api/generations` | member | `{ requestId, kind: 'background', prompt(1..500), seriesId?, width, height(256..2048), numImages(1..2) }` | 202 `{ generationId, jobId }` | 4 x n | compliance 규칙 → 국외 이전 동의 확인(`core.ai_org_settings`, 미동의 `TN007`) → `consume_credits` → `toon.generations` INSERT → `enqueue_job('toon.ai','image.generate')` | 402, 403 `TN007`, 413(용량), `TN006`, 429 |
| `POST /api/exports` | member | `{ requestId, episodeId, kind: 'png'\|'zip'\|'webtoon_strip'\|'mp4', options: { gutterPx?(0..200), gutterColor?, splitHeight?(640..1600), format?: 'jpg'\|'png', transition?: 'cut'\|'crossfade', zoom?: boolean, bgmAssetId?, aiLabelVisible: boolean, aiLabelOptOutConfirmed?: true, voice?: { mode: 'off'\|'dialogue' }, purpose?: 'final'\|'review' }, preset?: 'instagram_carousel'\|'webtoon_canvas'\|'naver_challenge'\|'vertical_9x16' }` | 202 `{ exportId, jobId }`(`voice.mode='dialogue'`이면 `jobId: null`이고 이어서 `POST /api/voice/video-lines`) | mp4만 3(음성은 `video-lines`에서 따로 선차감) | `toon.plan_features`, `toon.monthly_export_count`, `toon.org_asset_access`, `consume_credits`(mp4), `toon.exports` INSERT(watermark는 서버 값), `enqueue_job('toon.render','export.<kind>')`, 가시 표기 해제 시 감사 `export.ai_label_opt_out` | 403 `TN002`(음성은 `features.video_voice`도 확인), 403 `TN003`, 422 `TN004`, 429 `TN005`, 402, 409 `TN008`(협찬 미승인 회차의 최종 내보내기), 422(프리셋 규격 위반: 캐러셀 10장 초과 등, 프리셋·종류 불일치는 DB 23514) |
| `GET /api/exports/{id}/download?i=` | member | 파일 인덱스 | 302 서명 URL(1시간) | 0 | Storage `exports`, 감사 `export.download` | 404, 410(만료) |
| `POST /api/sponsorships/{id}/decide` | owner/admin | `{ decision: 'approved'\|'changes_requested', note?(..500) }` | `{ status }` | 0 | 사용자 세션 `rpc toon.decide_sponsorship`(감사 `sponsorship.<decision>`) | 403(42501), 409(22023: 검토 중이 아님) |
| `POST /api/jobs/{id}/cancel` | member | - | `{ status }` | 환불 | 사용자 세션 `core.cancel_job` → service로 제품 행 `canceled` 미러 | 409 `JB002` |
| `POST /api/billing/checkout` | owner/admin | `{ kind: 'subscription', planCode: 'pro' }` 또는 `{ kind: 'credit_pack', packCode }` | `{ orderId, amountKrw, customerKey }` | 0 | `payment_orders` INSERT(금액은 DB) | 409(이미 Pro) |
| `POST /api/billing/confirm` | owner/admin | `{ paymentKey, orderId, amount }` | `{ status }` | 지급 | Toss confirm → `core.confirm_payment_order` | 409 `PM001`/`PM409`, 404 `PM404` |
| `POST /api/billing/billing-key` | owner/admin | `{ authKey, orderId }` | `{ subscription }` | 지급 | 빌링키 발급 → 암호화 저장 → 첫 청구 → `confirm_payment_order` | 402(카드 거절) |
| `POST /api/billing/cancel` | owner/admin | - | `{ cancelAtPeriodEnd: true }` | 0 | `core.apply_subscription_transition(..., 'canceled')` | 409 `SB001` |
| `POST /api/webhooks/toss` | 공개(서명) | raw | 200 | - | `receiveWebhook` → 상태 동기화만 | 401 |
| `POST /api/webhooks/fal` | 공개(서명 미확인) | raw | 200 | - | `receiveWebhook`, `request_id` 대조 | 401, 404 |
| `POST /api/admin/catalog/packs/{id}/verify` | platform_admin | `{ licenseRef, note }` | `{ pack }` | 0 | service UPDATE `toon.asset_packs` + 감사 `asset_pack.verify` | 403 |
| `POST /api/admin/catalog/packs/{id}/publish` | platform_admin | `{ status: 'published'\|'retired' }` | `{ pack }` | 0 | service UPDATE + 감사 | 409(검증 없음, CHECK 23514) |

브라우저 직접 호출(RLS): `toon.series`, `series_characters`, `episodes`, `cuts`, `sponsorships`(2026-10-13 2차. INSERT는 DB가 `features.sponsorship`을 검사해 `TN002`, 상태는 `draft`/`in_review`/`closed`만 직접 변경) CRUD, `rpc toon.save_cut_doc`, `rpc toon.reorder_cuts`, `rpc toon.archive_user_asset`, `toon.catalog_assets`, `toon.generations`/`user_assets`/`exports` 조회, `core.jobs` Realtime.


### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다. 모든 핸들러는 진입부에서 `requireSession('toon')`을 호출한다. 작품·컷·내보내기 id는 사용자 세션 클라이언트(RLS)로 먼저 읽어 같은 조직 것인지 확인한다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/ai/conversations` | member 이상, `features.ai_chat` | `{ series_id: uuid, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `series_id`는 같은 조직 작품만 | 404 작품, 403 엔타이틀먼트·플랜 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000), series_id, mode: 'setting'\|'idea' }` | SSE `delta`, `citations`, `suggestions`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `series_id`, `mode`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/ai/knowledge/notes` | member 이상 | `{ series_id, title(1..80), body_md(1..20000), request_id }` | 202 `{ document_id }` | 0 | FastAPI `/rag/ingest`(scope `rag`, 컬렉션 `settings-<series_id>`, source_type `text`) | `rate_limit_hit('toon:note:<org>', 30, 3600)` | 404 작품, 409 중복(`content_hash`), 413, 422(작품당 10개 초과) |
| `GET /api/ai/knowledge/notes?series_id=` | member 이상 | 쿼리 | `[{ id, title, chars, status }]` | 0 | 서버가 조직·작품을 확인한 뒤 조회(service) | - | 404 |
| `DELETE /api/ai/knowledge/notes/[id]` | member 이상 | - | 204 | 0 | FastAPI 문서·청크 삭제(scope `rag`) | 감사 `knowledge.note.delete` | 404 |
| `POST /api/ai/wiki/ingest` | member 이상 | `{ series_id, mode: 'create'\|'append_episode', episode_id?, request_id }` | 202 `{ job_id }` | 선차감 2, 정산 1~4 | FastAPI `/wiki/ingest`(scope `wiki`), 잡 `wiki.ingest`(큐 `toon.knowledge`) | `consume_credits(run:<id>)`, `enqueue_job` | 402, 404, 429 |
| `GET /api/ai/wiki/pages?series_id=`, `GET /api/ai/wiki/pages/[...slug]?series_id=` | member 이상(viewer 읽기) | 쿼리 | 페이지 목록·본문·링크·이력 | 0 | FastAPI `GET /wiki/pages/{slug}`(scope `wiki`) | - | 404 |
| `PATCH /api/ai/wiki/pages/[...slug]` | member 이상 | `{ series_id, expected_version, body_md?, status?: 'published'\|'archived', voice_key?, reason? }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 6절 요청 10) | 감사 `wiki.edit`/`wiki.publish` | 403, 409 출처 없는 페이지 확정, 409 `WIKI_VERSION_CONFLICT` |
| `POST /api/ai/wiki/lint` | member 이상 | `{ series_id, request_id }` | 202 `{ job_id }` | 1(정액) | FastAPI `/wiki/lint`(scope `wiki`), 잡 `wiki.lint` | `consume_credits(run:<id>)` | 402, 429 |
| `POST /api/voice/consent` | member 이상 | `{ notice_version }` | 204 | 0 | - | `write_audit('voice.notice_ack', { notice_version })` | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | member 이상, `features.voice_chat` | `{ conversation_id }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, request_id }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'toon','voice_chat','stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/voice/dialogue` | member 이상, `features.dialogue_voice` | `{ cut_id, layer_id, voice_key?, request_id }`(텍스트는 저장된 `cuts.doc`의 말풍선에서 읽는다. 클라이언트 텍스트 불가) | `audio/mpeg` 스트림 | 글자 수 × 단가, 천 자 단위 올림(대사 120자 이하이므로 1) | `dialogue_voice`/`tts` 체인(대체 허용, 대체 시 응답 헤더 `X-Voice-Fallback: 1`) | `voice_jobs`, `consume_credits(voice:<request_id>)`, 캐시 키 `(cut revision, layer_id, voice_key)` → Storage `exports/<org>/toon/voice-preview/` 24시간 | 404 컷, 422 `VOICE_TEXT_TOO_LONG`(120자 초과)·sfx 말풍선, 402, 429, 503(환불됨) |
| `POST /api/voice/video-lines` | member 이상, `features.video_voice` | `{ export_id, offset?: int, limit?: int(1..10) }` | NDJSON `{ step: 'line', n, total }` ... `{ done: true }` | 대사 총 글자 수 × 단가, 천 자 단위 올림(첫 호출에 전체 선차감) | `video_voice`/`tts` 체인에서 시작 제공자 1개 고정, 대체 금지(scope `voice`) | `exports.options.voice` 갱신, Storage `exports/<org>/toon/voice/<export_id>/`, `consume_credits(voice:<request_id>)`, 완료 시 `enqueue_job('toon.render','export.mp4')`, 실패 시 `refund_credits` + `exports.status='failed'`(service) | 403 `TN002`, 409(이미 준비됨), 422 `TN004`(길이), 402, 429, 502 `EXPORT_VOICE_FAILED`(환불됨) |
| `POST /api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 발급만: scope `graph:toon.storyboard` 또는 `graph:toon.image_prompt`, `feat`=`toon.storyboard` 또는 `toon.prompt_en`, `org`·`sub`는 `core.jobs` 행의 `org_id`·`created_by` | `core.jobs` 조회(`status='running'`, `app_id='toon'`, `job_type` 일치) | 401 `INTERNAL_KEY_INVALID`, 409 잡 상태, 429 |
| `POST /api/internal/ai-settle` | 워커 스케줄(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`). 설정 위키는 사용자 조직 데이터지만 `core.wiki_pages`를 브라우저에 직접 열지 않고 위 `GET /api/ai/wiki/*`가 조직·작품을 확인한 뒤 돌려준다(청크·임베딩 대량 조회 차단 원칙, `docs/products/_platform-core/SECURITY_BASELINE.md`의 청크 열람 금지 규칙과 같은 취지).

## 3. RPC (SECURITY DEFINER)

SECURITY INVOKER 함수도 이 절에 함께 적는다.

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `toon.has_toon_access()` | authenticated(정책 안) | auth.uid()의 활성 멤버십 + toon 엔타이틀먼트 | boolean | - |
| `toon.plan_features(p_org_id)` | authenticated, service | `is_service_caller()` 또는 `is_org_member` | jsonb | 42501 |
| `toon.feature_int(features, key, default)` | 내부 | - | int | - |
| `toon.save_cut_doc(p_cut_id, p_doc, p_expected_revision)` | authenticated(INVOKER, RLS 적용) | revision 일치 | 새 revision | `TN409`, `P0002`, `23514`(문서 형식) |
| `toon.reorder_cuts(p_episode_id, p_cut_ids)` | authenticated(INVOKER) | id 목록이 회차 컷과 정확히 일치 | void | `P0002`, `22023` |
| `toon.org_asset_access(p_org_id, p_asset_ids)` | authenticated, service | 서비스 또는 멤버 + 엔타이틀먼트 | `(asset_id, tier, allowed)` | 42501 |
| `toon.monthly_export_count(p_org_id)` | authenticated, service | 서비스 또는 멤버 | int(KST 월) | 42501 |
| `toon.archive_user_asset(p_user_asset_id)` | authenticated | 서비스 또는 `has_org_role(owner,admin,member)` + 감사 | void | `P0002`, 42501 |
| `toon.decide_sponsorship(p_sponsorship_id, p_decision, p_note)` | authenticated, service | 서비스 또는 `has_org_role(owner,admin)`, 상태가 `in_review`일 때만 + 감사 | void | `P0002`, 42501, 22023 |

AI·음성용 제품 함수는 없다. 코어 `set_ai_cross_border_ack`는 온보딩에서 사용자 세션으로, `resolve_ai_route`는 service_role로만 부른다.

트리거 함수(`enforce_plan_limits` `TN001`, `bump_cut_revision`, `enforce_run_status_transition` 22023, `enforce_sponsorship_status` `TN002`/42501/22023, `apply_export_sponsorship` `TN008`)는 EXECUTE를 열지 않는다. 코어 RPC: `consume_credits`/`refund_credits`(`CORE_SPEC.md:152-160`), `enqueue_job`/`claim_jobs`/`heartbeat_job`/`complete_job`/`fail_job`/`cancel_job`(`:278-307`), `confirm_payment_order`(`:210-221`), `rate_limit_hit`(`:332-340`).

## 4. 잡 페이로드 계약

공통: 비밀값을 넣지 않는다. `org_id`는 `core.jobs.org_id`에서 읽는다.

### 4.1 `storyboard.generate`

```json
{
  "payload": { "episode_id": "uuid", "series_id": "uuid", "request_id": "uuid", "format": "instatoon|webtoon", "use_wiki": true,
               "synopsis": "string", "cut_count": 8, "tone": "daily",
               "cast": [{ "character_id": "uuid", "display_name": "미나", "role_note": "주인공",
                          "poses": ["wave", "sit"], "expressions": ["smile", "angry"] }] },
  "result": { "script": { "v": 1, "title": "string", "cuts": [
      { "index": 1, "scene": "출근길 지하철", "background_hint": "crowded subway car, morning",
        "shot": "wide|medium|close",
        "characters": [{ "character_id": "uuid", "pose_code": "wave", "expression_code": "smile", "position": "left|center|right", "flip": false }],
        "dialogues": [{ "speaker_character_id": "uuid|null", "type": "speech|thought|narration|sfx", "text": "60자 이하", "voice_key": "young_f|null" }],
        "prompt_en": "string|null", "negative_prompt": "string|null",
        "consistency": [{ "character_id": "uuid", "rule": "존댓말만 쓴다", "evidence_slug": "s-1a2b3c4d/characters/mina", "severity": "warn|error" }],
        "blocked": false } ] },
    "warnings": ["cut 3: pose_code fallback"], "run_id": "uuid", "usage_id": 123 },
  "progress": "10 줄거리 / 35 컷 분할 / 60 일관성 검사 / 80 이미지 프롬프트 / 90 compliance / 100 저장"
}
```

실행: 워커가 `/api/internal/ai-token`으로 잡 토큰을 받아 FastAPI `POST /graphs/toon.storyboard/runs`를 호출하고 `GET /graphs/runs/{id}`로 상태를 확인한다(120초 제한, 초과 시 `fail_job`). `use_wiki=true`이고 작품 위키가 있으면 `plot`·`consistency` 노드가 위키를 쓴다. 그래프는 `ai_runs` 1행 + `ai_run_steps` 5행(`plot`, `panel_split`, `consistency`, `image_prompts`, `compliance`)을 남긴다. `consistency`는 `error` 컷을 1회 재작성하고, 남은 `warn`은 `consistency` 배열로 돌려준다. `compliance` 재작성 뒤에도 FAIL이면 그 컷은 `blocked: true`다(전체의 절반 초과면 잡 실패 + 환불).

검증: 컷 수 = `cut_count`, 컷당 캐릭터 0~3, 대사 0~4, 코드가 cast의 목록 밖이면 첫 포즈/첫 표정으로 바꾸고 `result.warnings`에 남긴다. 성공 시 워커가 `toon.episodes.script`에 저장하고 `status='storyboarded'`.

### 4.2 `image.generate`

```json
{
  "payload": { "generation_id": "uuid", "kind": "background", "prompt": "한국어", "style_preset": "flat_line",
               "width": 1080, "height": 1350, "num_images": 1, "model": "화이트리스트 ID", "seed": null },
  "result": { "user_asset_ids": ["uuid"], "fal_request_id": "string", "prompt_en": "string", "refunded_images": 0 },
  "progress": "10 프롬프트 변환 / 30 제출 / 30~90 대기(폴링 2초) / 95 저장"
}
```

워커: 잡 토큰으로 그래프 `toon.image_prompt` 호출(`translate` → `compliance`) → fal 제출(`webhook_url`, 안전 필터 ON) → 폴링 또는 웹훅 이벤트 확인 → 이미지를 `toon-user-assets/<org>/toon/user_assets/<uuid>.png`로 복사, 256px 썸네일 → `toon.user_assets`(source `ai_generated`, `ai_generated=true`, model) → `generations.status='succeeded'`. 안전 필터 거부: `fail_job(retryable=false)`.

### 4.3 `export.png` / `export.zip` / `export.strip` / `export.mp4`

```json
{
  "payload": { "export_id": "uuid", "episode_id": "uuid", "kind": "png|zip|webtoon_strip|mp4" },
  "result": { "output_paths": ["<org>/toon/exports/<export_id>/01.png"], "bytes": 123456, "duration_ms": 25000,
              "ai_label": true, "files": 10 },
  "progress": "컷 i/n 렌더 / 인코딩 / 업로드"
}
```

워터마크, AI 표기, 옵션은 페이로드가 아니라 `toon.exports` 행(`watermark`, `ai_label_visible`, `options`)에서 읽는다. `kind='mp4'`이고 `options.voice.mode='dialogue'`이면 `exports.options.voice = { mode, provider, clips: [{ cut_id, layer_id, path, duration_ms, characters }] }`가 `video-lines` 단계에서 채워진 뒤에만 잡이 만들어진다. 워커는 `clips`의 경로(`exports/<org_id>/toon/voice/<export_id>/` 접두사)만 읽는다. 2026-10-13 2차: 프리셋은 `exports.preset`, 대가성 문구와 가상인물 표시는 `exports.disclosure_text`, `virtual_character_label`(DB 트리거가 협찬 행에서 복사)에서만 읽는다. 문구가 있으면 01장 TN-F-072 위치에 넣고, 렌더 결과 메타데이터에 `sponsored=true`, `disclosure`를 기록한다. 검토용 시안(`options.purpose='review'`)은 워터마크 외에 "검토용 시안" 띠를 넣는다. 컷 문서는 잡 시작 시 DB에서 읽은 스냅샷을 쓴다(진행 중 편집은 반영하지 않음). 결과 `expires_at = now() + 30일`.

### 4.4 `cut.thumbnail`

`{ "payload": { "cut_id": "uuid", "revision": 3 }, "result": { "thumbnail_path": "..." } }`. revision이 바뀌었으면 건너뛴다.


### 4.5 `rag.ingest` / `wiki.ingest` / `wiki.lint` (큐 `toon.knowledge`, FastAPI가 클레임)

```json
{
  "payload": { "series_id": "uuid", "collection": "settings-<series_id>|wiki-<series_id>", "document_ids": ["uuid"],
               "mode": "create|append_episode", "episode_id": "uuid|null", "request_id": "uuid" },
  "result": { "run_id": "uuid", "pages_created": 3, "pages_updated": 2, "pages_skipped_user_owned": 1,
              "lint": { "contradictions": 0, "stale": 1, "orphans": 0, "broken_links": 0, "no_source": 0 }, "usage_id": 123 },
  "progress": "10 청크 분할 / 40 임베딩 / 70 페이지 갱신 / 100 완료"
}
```

규칙: `org`·`app`은 `core.jobs` 행에서 읽고 페이로드의 값은 쓰지 않는다. 문서 1건당 갱신 페이지는 5개 이하(초과분은 다음 배치). 사람 소유 표시 블록은 건너뛰고 `pages_skipped_user_owned`에 센 뒤 개정 초안으로만 남긴다. `wiki.ingest`는 선차감 2, 정산 1~4(상한 초과분은 운영사 부담). 최종 실패는 `fail_job` + 환불.

## 5. 웹훅

| 수신 | 서명 | event_id | 처리 |
|---|---|---|---|
| Toss | Toss 문서 기준(미확인) | `paymentKey + status + 발생시각` 해시(`CORE_SPEC.md:249`) | 결제 취소·가상계좌 상태 동기화만. 지급은 confirm 경로 |
| fal | fal 문서 기준(미확인). 확인 전에는 `request_id`가 `toon.generations.fal_request_id`와 일치하는지만 확인 | `request_id` | `webhook_events`에 기록. 워커 폴링이 결과를 확정(웹훅은 보조) |

발신 웹훅 없음(automation-core 미사용).

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 | 쿼터/비용 |
|---|---|---|---|
| FastAPI AI 서비스(그래프 3개, 위키, RAG, 도구) | 워커(`storyboard.generate`, `image.generate`, 잡 토큰), Route Handler(`dialogue/polish`, 위키, 노트, 서명 토큰) | 체인 대체(라우터) → 컷 재작성 1회(그래프) → 실패 → 환불 + `ai_usage.status='error'`. 콘티 120초 제한 | 콘티당 LLM 호출 3~6회. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*` | 채팅·미리듣기는 체인 다음으로 대체(`voice_jobs.fallback_from`), 영상 음성은 대체 없이 실패 + 환불 | 요금·상업 이용 조건 구현 시 확인(01장 D13) |
| 오픈소스 음성 서버 | `src/app/api/voice/*`(서명 토큰 scope `voice`) | 같음 | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). toon은 60초·120자 단위 |
| fal | 워커 | 제출 실패 재시도 3회(지수 백오프), 30분 미완료 실패, 안전 거부 재시도 없음 | 모델 화이트리스트 |
| Toss | Route Handler, 워커 스케줄 | `SHARED_MODULES.md:134` | - |
| Supabase Storage | Route Handler(서명), 워커(읽기/쓰기) | 업로드 실패 재시도 3회 후 잡 실패 | 파일 상한 01장 5절 |


### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 toon이 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | toon 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 6절 요청 10). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `setting`: `series_id`가 매핑 org의 작품인지 확인 → 작품 컬렉션(위키 + 노트) 검색 → `chat` 모델. 모드 `idea`: 같은 근거 + 창작 제안 허용. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다. 응답에 `suggestions`(말풍선 후보 텍스트)를 담는다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /graphs/toon.storyboard/runs`, `GET /graphs/runs/{id}` | 워커 | 잡 토큰 scope `graph:toon.storyboard`, `jti` 1회 | 콘티 생성(4.1절) |
| `POST /graphs/toon.image_prompt/runs` | 워커 | 잡 토큰 scope `graph:toon.image_prompt`, `jti` 1회 | 영어 프롬프트 변환 |
| `POST /graphs/toon.dialogue/runs` | Next.js 서버 | 서명 토큰 scope `graph:toon.dialogue` | 대사 3안(동기) |
| `POST /rag/ingest` | Next.js 서버 | 서명 토큰 scope `rag` | 설정 노트 색인 |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장 | Next.js 서버 | 서명 토큰 scope `wiki` | 작품 설정 위키 |

쓰지 않는 것: `POST /dify/retrieval`(제품 공통 지식이 없고 설정은 사용자 조직 데이터), `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`toon-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `toon-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_TOON`(Next.js 서버 전용). 정의는 `infra/dify/toon-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `series_id`(필수, UUID 문자열), `mode`(`setting`\|`idea`). 서명 토큰, org, 이름, 이메일은 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`) |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`: `creative` / `crisis` / `off_topic`) → `creative`: HTTP 요청 노드 → 답변 / `crisis`: 고정 안내(상담전화) / `off_topic`: 고정 안내(사용법·잡담은 이 채팅 범위 밖) |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, series_id, mode }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type: 'wiki'\|'note', slug or id, title }], suggestions: [{ kind: 'dialogue'\|'memo', text }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다(01장 5절) |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | 발생 | HTTP |
|---|---|---|---|
| `TN001` | 플랜 한도(작품/회차/컷) | DB 트리거 | 403 |
| `TN002` | 플랜에 없는 내보내기 종류 | Route Handler | 403 |
| `TN003` | 플랜 등급 밖 에셋 사용 | Route Handler, 워커 | 403 |
| `TN004` | MP4 길이 초과 | Route Handler | 422 |
| `TN005` | 월 이미지 내보내기 한도 | Route Handler | 429 |
| `TN006` | 프롬프트·대사 규칙 위반 | Route Handler | 422 |
| `TN007` | 국외 이전 동의 없이 AI 배경(fal) 요청 | Route Handler | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| `TN008` | 협찬 회차인데 협찬이 승인되지 않았는데 최종 내보내기 요청 | DB 트리거 `apply_export_sponsorship` | 409 + "광고주 승인 후 내보낼 수 있습니다. 검토용 시안으로 내보내 보세요" |
| `TN409` | 컷 revision 충돌 | `toon.save_cut_doc` | 409 |
| `23514` | 문서 형식·라이선스 CHECK 위반 | DB | 422 |
| `23503` | 다른 조직 부모 참조(복합 FK) | DB | 404 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 코어 | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 코어 | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | Route Handler | 503 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | Route Handler | 409 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한(`features.ai_chat_turns_per_day`) | Route Handler | 429 |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전이 서버 상수와 다름 | Route Handler | 409 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | Route Handler | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 60초 또는 5MB 초과 | Route Handler | 413 |
| 앱 코드 `VOICE_TEXT_TOO_LONG` | 대사 120자 초과 또는 sfx 말풍선 | Route Handler | 422 |
| 앱 코드 `EXPORT_VOICE_FAILED` | 영상 음성 준비 실패(선차감 환불 완료, 대체 안 함) | Route Handler | 502 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 `expected_version` 불일치 | FastAPI 경유 | 409 |
| 코어 코드 | `42501`→403, `CR001`→402, `P0002`→404, `22023`/`JB002`/`SB001`→409, `PM001`/`PM409`→409 + 알림 | `CORE_SPEC.md:397-418` | - |

## 8. 인증 단계 경로 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.1·2.4·3.2·7.2.3절이다. 아래 경로는 `requireSession` 대상이 아니다(로그인 전 경로). 나머지 Route Handler(2절)는 단계와 무관하게 그대로다.

| 메서드 경로 | 단계 | 입력 | 출력 | 처리 | 오류 |
|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | `{ persona: 'owner'\|'admin'\|'member'\|'viewer'\|'outsider'\|'no_app'\|'suspended'\|'ops'\|'pro_owner'\|'low_credit', next?: string }`(zod, 05장 10절 키만) | 303 → `finishLogin` 결과 경로 | `isMockAuthAllowed()` 확인 → 쿠키 세션 서버 클라이언트로 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('toon', next)`(아래 콜백 2~5번) | 판정 거짓이면 404(존재 숨김). 시드 없음 401 + 패널 안내. 레이트 리밋 대상 아님(로컬 전용) |
| `GET /auth/callback?code&next` | B·C(Google, 카카오, `custom:naver`) | 쿼리 | 302 | `finishLogin`: (1) `exchangeCodeForSession`(PKCE) → (2) `session_context('toon')` 1회 → (3) `entitled=false`이고 toon `signup_policy='open'`이므로 `rpc('bootstrap_app_for_org', { p_app_id: 'toon' })` 1회 후 재조회(모놀리스는 트리거가 이미 부트스트랩해 무동작) → (4) pending → `/pending`(toon은 open이라 발생 안 함), suspended → 403 → (5) 첫 로그인이고 약관 미동의면 `/onboarding/terms`, 아니면 `next` 화이트리스트(`/`로 시작, `//`·`@`·`\` 없음) 또는 `/app`. origin은 `NEXT_PUBLIC_APP_URL` 고정 → (6) 감사 `auth.login`(provider, 첫 로그인 여부). 토큰·코드는 로그에 남기지 않는다 | `/login?error=callback`(code 없음·재사용·만료), 프로필 없음 → 로그아웃 후 `/login` |
| `GET /auth/naver/start?next=` | C2(브리지 경로 채택 시만, 01장 D23) | 쿼리 | 302 네이버 authorize | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 서명 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분)에 넣음. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 429 |
| `GET /auth/naver/callback?code&state` | C2(브리지) | 쿼리 | 302 | 쿠키 state 상수 시간 비교 후 삭제 → 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(코어 보류 마이그레이션)로 사용자 조회 → 있으면 magiclink `verifyOtp`로 세션, 없고 같은 이메일 사용자도 없으면 `createUser` + 링크 행, 같은 이메일 사용자가 있으면 자동 연결 안 함 → `finishLogin`. 네이버 토큰은 저장하지 않는다 | `/login?error=state`, `/login?error=email_in_use`, `/login?error=callback` |

Mock 로그인도 `finishLogin`을 거치므로 `no_app` 페르소나로 3번(부트스트랩) 경로를 A단계에서 검증한다(모듈러). 로그인 방법 연결·해제(C단계, 03장 7.4절)는 브라우저 `linkIdentity`·`unlinkIdentity` + 서버 감사 기록이며 새 Route Handler는 네이버 브리지 연결(`/auth/naver/start?link=1`, 로그인 상태 필수)뿐이다.

오류 코드(7절 표에 더하는 앱 코드)

| 코드 | 의미 | HTTP/처리 |
|---|---|---|
| `error=callback` | 코드 교환 실패, code 없음·재사용·만료 | 302 `/login?error=callback` |
| `error=state` | 네이버 브리지 state 불일치·없음·만료 | 302 `/login?error=state` |
| `error=email_in_use` | 네이버 브리지 첫 로그인인데 같은 이메일 기존 사용자 | 302 `/login?error=email_in_use` |
| `/api/dev/login` 404 | Mock 판정 거짓(배포 환경, 원격 DB, `AUTH_MODE≠mock`) | 404 |
