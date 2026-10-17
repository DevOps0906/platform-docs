# 04 API: SceneFlow (sceneflow)

2026-10-13 개정: AI·음성 Route Handler(2.1절), AI·음성 잡 페이로드(4절), FastAPI 엔드포인트와 Dify Chatflow 계약(6.1, 6.2절), AI 오류 코드(7절)를 추가했다. 오케스트레이터 TS와 Python 미디어 워커, FastAPI AI 서비스의 경계는 02장 2절이다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 `/api/**`(웹훅·공개 제외)는 진입부에서 `requireSession('video', { roles })`(SHARED_MODULES 2장). 조직은 세션에서 결정하고 요청 본문의 `orgId`를 받지 않는다(BS #5, #12). 세션은 모든 인증 단계(A Mock·B Google·C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다. 로그인 경로는 8절(확정 결정 22) |
| 입력 검증 | zod. Track `A-F`, 언어 `KO/JA/EN`, URL 도메인 허용 목록, `limit` 1~100 |
| 멱등 | 생성·결제·업로드 요청 본문에 클라이언트 UUID `request_id` 필수. 서버는 `consume:video:<request_id>`, `job:video:<request_id>`로 사용. 같은 키 재요청은 기존 결과 반환 |
| 크레딧 | 선차감은 Route Handler(service_role)에서 `consume_credits` → `enqueue_job(p_credit_ledger_id)`. 사용자 RPC 안에서 차감하지 않는다 |
| 응답 봉투 | 성공 `{ "ok": true, "data": ... }`, 실패 `{ "ok": false, "error": { "code": "VD009", "message": "...", "detail": {...} } }` |
| 레이트 리밋 | 키 `video:<route>:<org_id 또는 ip_hash>`, Redis 카운터(CORE_SPEC 12장). 생성 60회/분/조직 |
| 게이팅 | `entitled_plan_code` + features(01장 4절). 서버 판정이 정본, DB 정책이 2차 |
| AI·음성 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler(또는 오케스트레이터)가 부른다(`docs/products/_platform-core/SECURITY_BASELINE.md:299`) |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT를 발급: `iss=video`, `aud=platform-ai:video`, `org`, `app=video`, `sub`(사용자 id), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 세션 또는 잡 행에서만 가져온다(docs/products/_platform-core/AI_ARCHITECTURE.md:33-42) |
| AI 멱등 키 | 채팅 `conv:<id>:turn:<n>`(n은 서버가 센 턴 번호. 같은 `request_id` 재전송은 `video:ai-req:<request_id>` 버킷 1회로 막는다), 음성 `voice:<voice_job_id>`(클라이언트 `request_id`를 `voice_jobs.id`로 쓴다), 그래프 정밀 모드 `run:<ai_run_id>`, 기존 생산 `consume:video:<request_id>` |
| AI 선차감·정산 | 선차감은 제공자 호출 전 Route Handler에서, 정산은 응답 종료 직후 같은 Route Handler에서. 연결이 끊기면 `/api/internal/ai-settle`(오케스트레이터 크론이 5분마다 호출)이 처리 |
| 스트리밍 | 채팅은 SSE(`text/event-stream`) |
| AI 레이트 리밋 | `video:ai-chat:<user>` 20회/60초, `video:ai-chat-day:<user>` 200회/86400초, `video:voice-stt:<user>` 10회/60초, `video:voice-sample:<user>` 20회/3600초, `video:ai-graph:<org>` 30회/3600초, `video:ai-token:worker` 120회/60초(01장 5절) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| GET `/api/session` | 로그인 | - | SessionContext | - | `session_context` | 401 |
| POST `/api/billing/orders` | owner/admin | `{kind, planCode?\|packCode?, request_id}` | `{orderId, amountKrw, customerKey}` | - | INSERT `payment_orders` | 403(adv 팩 비Advanced), 409 |
| POST `/api/billing/confirm` | owner/admin | `{paymentKey, orderId, amount}` | 결제 결과 | - | `confirm_payment_order` | PM001/PM409 → 409 + 취소, PM404 → 404 |
| POST `/api/billing/billing-key` | owner/admin | `{authKey}` | `{cardMasked}` | - | billing_keys INSERT(서버) | 400 |
| POST `/api/billing/cancel` | owner/admin | `{reason}` | 구독 | - | `apply_subscription_transition` | SB001 → 409 |
| GET `/api/channels` | 전 역할 | - | 채널 목록 | - | RLS select | - |
| POST `/api/channels/connect` | owner/admin | `{platform, role, targetLanguage, riskAck: true}` | `{authorizeUrl}` | - | `create_oauth_state` | VD004 → 403 |
| POST `/api/channels/connect/naver-clip` | owner/admin, `features.platforms`에 `naver_clip` | `{role, targetLanguage, profileUrl}` | `{sessionId}`(서버 브라우저 로그인 세션 시작. 사용자가 네이버 로그인 창에서 직접 인증, 비밀번호를 서버가 받지 않음) | - | 로그인 완료 시 credential INSERT(provider `naver`) + channels INSERT(service) | VD004 → 403, VD003 → 409 |
| POST `/api/channels/[id]/clip-consent` | owner/admin | `{noticeVersion: 'clip-2026-10-v1', checks: [true,true,true], typed: '동의합니다'}` | 채널(동의 시각) | - | `video.consent_clip_automation_risk` | VD015 → 409(버전 불일치), 22023 → 400(naver_clip 아님), 42501 → 403 |
| DELETE `/api/channels/[id]/clip-consent` | owner/admin | - | 채널 | 대기 중 클립 업로드 환불 | `video.revoke_clip_automation_consent` + queued `upload.naver_clip` 잡 `cancel_job` | 42501 → 403 |
| GET `/api/channels/callback/[platform]` | 공개(state로 사용자 확정) | `code, state` | 302 `/dashboard/channels` | - | `consume_oauth_state`, credential INSERT, channels INSERT | OA001 → 400, VD003 → 409 |
| PATCH `/api/channels/[id]` | owner/admin | `{role?, targetLanguage?, targetCountry?, status?}` | 채널 | - | `video.update_channel_settings` | 42501 → 403 |
| DELETE `/api/channels/[id]` | owner/admin | - | 채널(revoked) | - | `video.disconnect_channel` | 403 |
| POST `/api/sources` | member+ | `{url, track, rightsBasis, rightsNote?, request_id}` | 소스 | 1 | consume, enqueue `source.download` | 422 도메인, 402 |
| GET `/api/radar/playboard` | Basic+ | `{country, period, category?}` | 랭킹 | 0 | RLS select | 403 |
| POST `/api/radar/channel-finder` | Pro+ | `{maxSubscribers, minAvgViews, days}` | 리포트 id | 2 | consume, enqueue | 402, 403 |
| POST `/api/radar/bling` | Pro+ | `{topic, request_id}` | 리포트 id | 5 | consume, enqueue | 429 VD012 |
| POST `/api/productions/estimate` | member+ | 생성 입력과 같음 | `{total, breakdown}` | 0 | - | 422 |
| POST `/api/productions` | member+ | `{track, mode?, sourceId?, topic?, languages[], options{silenceCut, layerComposite}, request_id}` | production + rootJobId | 단가 합계 | consume, enqueue `production.run` | VD009, VD010, 402, 429(동시 생산 상한) |
| GET `/api/productions/[id]` | 전 역할 | - | production + outputs + job | - | RLS | 404 |
| POST `/api/productions/[id]/cancel` | member+ | - | production | 환불 | `cancel_job`(queued) / 워커 취소 신호(running) | JB002 → 409 |
| POST `/api/longform` | Pro+ member+ | `{title, category, topic, languages, targetMinutes}` | 프로젝트 | 0 | RLS insert | 403 |
| POST `/api/longform/[id]/score` | Pro+ | `{request_id}` | `{score, alternatives}` | 2 | withCredits | - |
| POST `/api/longform/[id]/storyline` | Pro+ | `{request_id}` | 스토리라인 | 5 | withCredits | VD010 |
| POST `/api/longform/[id]/storyboard` | Pro+ | `{request_id}` | 섹션 10 | 0(스토리라인에 포함) | service upsert sections | VD005 |
| POST `/api/longform/[id]/render` | Pro+ | `{request_id}` | rootJobId | 이미지 30 + TTS(언어당 5/10분) + 인코딩 10/10분 | consume, enqueue `longform.render` | 402 |
| POST `/api/longform/[id]/highlights` | Pro+ osmu | `{request_id}` | 하이라이트 3 | 11 | consume, enqueue | 409(롱폼 미완료) |
| POST `/api/music` | Pro+ suno | `{title, genre, prompt, mood?, bpm?, request_id}` | 곡 | 23 | consume, enqueue `music.generate` | 402 |
| POST `/api/music/[id]/package` | Pro+ | - | 패키지 서명 URL | 0 | enqueue `music.package` | 409 |
| POST `/api/music/[id]/distribution` | member+ | `{status, note?, isrc?}` | 곡 | 0 | `video.set_music_distribution_status` | 22023 → 409 |
| POST `/api/library` | Pro+ member+ | `{title, artist, licenseType, licenseProofPath, audioPath, licenseExpiresAt?, youtubeMonetizationAllowed, attributionText?}` | 라이브러리 곡 | 0 | RLS insert(파일은 org-files 업로드 후 경로) | 23514 |
| POST `/api/playlists` | Pro+ member+ | `{title, mood, targetDurationMin, language}` | 플리 | 0 | RLS insert | 42501 → 403 |
| PUT `/api/playlists/[id]/items` | member+ | `{items: [{musicTrackId?\|libraryTrackId?}]}` | 항목 | 0 | RLS insert/update/delete(트랜잭션) | VD005, VD006 |
| POST `/api/playlists/[id]/render` | Pro+ | `{request_id}` | rootJobId | 20/35/95 | consume, enqueue `playlist.render` | 409(합계 시간 목표 ±5% 밖) |
| POST `/api/uploads` | member+ | `{outputId, channelId?, platform, title, description, tags, visibility, scheduledAt?, paidPromotion, affiliateLinkIds[], brandconnectApplicationId?, request_id}` | upload(draft, 문구 삽입 완료) | 0 | `effective_disclosure`, affiliate 링크, uploads INSERT(service). `naver_clip`은 `injectDisclosure(..., { target: 'title_hashtag' })`로 `disclosure_title`·`disclosure_hashtag`를 채움. 지원서는 `accepted` 상태만 연결 | VD008, VD002, VD015(클립 동의 없음) → 409, 23514(문구 누락) → 422 |
| POST `/api/uploads/[id]/check` | member+ | `{request_id}` | 검사 결과 | 1(LLM 단계) | consume, enqueue `compliance.check` | - |
| POST `/api/uploads/[id]/acknowledge` | member+ | `{note?}` | upload(approved) | 0 | `video.acknowledge_compliance_warning` | VD011, VD008 |
| POST `/api/uploads/[id]/schedule` | member+ | `{scheduledAt}` | upload(scheduled) | 1/채널 | consume, enqueue `upload.<platform>`(run_after). 네이버 클립은 계정당 3건/시간·15건/일 넘으면 다음 가능 시각으로 `run_after` | VD008, VD016(고객 승인 필요) → 409 |
| POST `/api/uploads/[id]/client-review` | member+, `features.agency` | `{ttlHours?: 1~336, note?}` | `{reviewId, expiresAt, linkSentTo}` | 0 | 서버가 32바이트 토큰 생성 → sha256 → `video.open_client_review`(service) → 고객 담당자 메일(링크 원문은 응답·로그에 남기지 않음, 메일 실패 시 1회만 링크 표시) | VD008, VD016(고객 미연결) → 409 |
| GET `/review/[token]` (페이지) | 공개(토큰) | - | 미리보기(서명 URL 10분), 제목·설명·태그·대가성 문구, 고객명 | 0 | 서버가 토큰 해시로 조회(service), `rate_limit` IP 해시당 30회/10분 | 404(없음·만료·이미 결정은 같은 화면 "사용할 수 없는 링크") |
| POST `/api/review/[token]` | 공개(토큰) | `{decision: 'approved'\|'changes_requested', reviewerName(1~40자), comment?(<=2000자)}` | `{decision}` | 0 | `video.decide_client_review`(service), 담당자 알림 | VD008 → 409, 404 |
| POST `/api/uploads/[id]/cancel` | member+ | - | upload | 환불 | `video.cancel_upload` | VD008 |
| GET/POST `/api/affiliate/accounts` | owner/admin | `{provider, partnerId?, apiKey?, secretKey?}` | 계정 | 0 | credential INSERT + affiliate_accounts INSERT(service) | 422 |
| GET `/api/affiliate/search` | member+ | `{provider='coupang', q}` | 상품 | 0 | 어댑터 | 501(capability 없음) |
| POST `/api/affiliate/links` | member+ | `{provider, product{name, productUrl}, affiliateUrl?(수동 제공자), sourceRef}` | `{shortCode, shortUrl}` | 0 | `new_affiliate_short_code`, affiliate_links INSERT | 422 |
| PUT `/api/affiliate/disclosures` | owner/admin | `{provider, placement, body(>=10자)}` | 문구 | 0 | `upsert_affiliate_disclosure` | 22023 |
| PATCH `/api/landings/[id]` | member+ | `{productName?, headline?, features?}` | 랜딩 | 0 | RLS update | 23514 |
| POST `/api/landings/[id]/status` | member+ | `{status}` | 랜딩 | 0 | `video.set_landing_status` | VD001, VD009 |
| GET `/r/[code]` | 공개 | - | 302 | 0 | `rate_limit`, `record_affiliate_click`(service) | 404 → `/` |
| GET `/landing/[slug]` (페이지) | 공개 | - | ISR 3600초 | 0 | `video.get_public_landing`(anon), `video.record_landing_view`(service, IP 해시 10분 1회) | 404 |
| GET `/lb/[handle]` (페이지) | 공개 | - | ISR 300초(제안) | 0 | `video.get_public_linkinbio`(anon) | 404 |
| GET `/api/analytics` | 전 역할 | `{from, to, channelId?, clientId?}` | 집계 | 0 | RLS select | - |
| GET/POST `/api/clients` | 조회 전 역할 / 생성 owner/admin, `features.agency` | `{name, brandName?, businessNo?, contact{name,email,phone}, packageCode, contractStart?, contractEnd?, monthlyQuota?, reviewRequired, reportDay, notes?}` | 고객 | 0 | RLS select / insert | 42501 → 403, 23505 → 409(같은 이름) |
| PATCH/DELETE `/api/clients/[id]` | owner/admin | 위 필드 일부 | 고객 | 0 | RLS update / delete | 42501 → 403 |
| POST `/api/clients/[id]/status` | owner/admin | `{status: 'active'\|'paused'\|'ended'}` | 고객 | 0 | `video.set_client_status` | 22023 → 409 |
| POST/DELETE `/api/clients/[id]/channels` | owner/admin | `{channelId, ownership: 'client'\|'agency'}` | 고객 채널 | 0 | RLS insert / delete | VD002 → 403, 23505 → 409(다른 고객에 묶임) |
| GET `/api/clients/[id]/reports` | 전 역할 | - | 월별 리포트 목록 + PDF 서명 URL | 0 | RLS select, Storage 서명 URL | - |
| POST `/api/clients/[id]/reports` | owner/admin | `{periodMonth: 'YYYY-MM', request_id}` | `{reportId, jobId}` | 0 | service upsert `client_reports`(generating) + enqueue `client_report.build` | 409(생성 중) |
| POST `/api/clients/[id]/reports/[reportId]/sent` | owner/admin | - | 리포트(sent) | 0 | service update + 감사 `client_report.sent` | 22023 |
| GET `/api/brandconnect/campaigns` | member+, `features.brandconnect_clip` | `{q?}` | 클립형 캠페인 목록(blog 스캔 결과 중 `campaign_type='clip'`) | 0 | blog 스캔 잡 결과 읽기(service) | 501(캠페인 유형 판별 불가 시 빈 목록이 아니라 사유) |
| POST `/api/brandconnect/handoff/accept` | member+ | `{handoffToken}`(blog `POST /api/brandconnect/handoff`가 발급, 같은 조직만) | `{campaign{id, title, brand, deadline, reward}}` → 지원 확인 화면 | 0 | 토큰 검증(service) | 404(만료·다른 조직) |
| POST `/api/brandconnect/applications` | member+, `features.brandconnect_clip` | `{accountId, campaignId, channelId(naver_clip), message, brand?, product?, category?}` | 지원서(draft → submitting) | 0 | `core.create_brandconnect_application(account, campaign, target_url=채널 URL, 'clip', 'video', brand, product, category, message)` → 코어가 `brandconnect.apply` enqueue | 42501 → 403(위험 동의 없음·엔타이틀먼트 없음), 23505 → 409(이미 지원) |
| POST `/api/webhooks/toss` | 공개(서명) | rawBody | 200 | - | `webhook_events` | 401 |
| POST `/api/webhooks/fal` | 공개(서명 미확인, request_id 대조) | rawBody | 200 | - | `webhook_events`, 잡 갱신 | 401 |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| POST `/api/onboarding/ai-consent` | owner/admin | `{ granted: boolean, notice_version, external_notice_ack: boolean }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, 외부 서비스 고지 확인은 `write_audit('ai.external_notice_ack')` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| POST `/api/ai/conversations` | 전 역할, `features.ai_chat` | `{ context_ref?: 'channel:<uuid>'\|'upload:<uuid>'\|'production:<uuid>', channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `context_ref` 대상은 같은 조직만(대화에는 저장하지 않고 Dify 입력과 이후 요청에서 전달) | 404 대상, 403 플랜 |
| POST `/api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000) }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| POST `/api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| DELETE `/api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| POST `/api/ai/script` | member+, 정밀 모드는 `features.ai_script` | `{ track: 'B'\|'C'\|'D', mode: 'precise', topic, languages[], channel_id?, longform_id?, request_id }` | `{ run_id, plans: [...] }`(`trend`·`plan` 끝, interrupt에서 대기) | 선차감 5(숏폼) / 8(롱폼). 주제 점수 60 게이트 선행(VD010) | 그래프 `video.script`(scope `graph:video.script`, `feat=video.script`, `jti` 1회) | `consume_credits(run:<ai_run_id>)`, `core.ai_runs` | 403 `VD009`, 409 `VD010`, 402, 429, 503(환불됨) |
| POST `/api/ai/script/[run_id]/resume` | 실행 주인(또는 owner/admin) | `{ plan_index, edits? }` | `{ status: 'running' }` 그리고 `GET`으로 결과 | 0(선차감에 포함) | 같은 그래프 thread 재개(새 `jti`) | `core.ai_runs` | 404, 409 `VD014`(만료·이미 재개) |
| GET `/api/ai/script/[run_id]` | 실행 주인(또는 owner/admin) | - | `{ status, plans?, script?, metadata? }` | 0 | - | 서버가 `created_by` 본인 또는 owner/admin만 허용(`core.ai_runs` select 정책은 조직 멤버 전체, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:616-627`) | 404 |
| POST `/api/wiki/documents` | owner/admin | multipart md(2MB 이하), `{ title }` | `{ document_id }` | 0 | FastAPI `/rag/ingest`(scope `rag`, 조직 컬렉션 `video-brand`) | 조직 Storage `org-files`, 감사 `wiki.upload` | 409 중복, 413, 403 |
| POST `/api/wiki/ingest`, POST `/api/wiki/lint` | owner/admin | `{ document_ids?: uuid[] }` | `{ run_id }` | ingest 2 / lint 1 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | `consume_credits(run:<ai_run_id>)` | 402, 403 |
| PATCH `/api/wiki/pages/[...slug]` | owner/admin | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 R-V9) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |
| POST `/api/voice/consent` | 전 역할 | `{ notice_version }` | 204 | 0 | - | 감사 `voice.notice_ack` | 409 `CONSENT_VERSION_MISMATCH` |
| POST `/api/voice/sessions` | 전 역할, `features.voice_chat` | `{ conversation_id? }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED` |
| POST `/api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, feature: 'voice_chat'\|'dictation', request_id }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'video',feature,'stt')` → ElevenLabs SDK 또는 오픈소스 `/stt`(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| POST `/api/voice/tts` | 대상 주인 | `{ source: 'message'\|'script_run', id, section?, request_id }`(텍스트는 DB의 assistant 메시지 또는 `ai_runs` 대본에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| POST `/api/voice/sample` | member+ | `{ language, provider, voice_id, text(1..100), request_id }` | `audio/mpeg` 스트림 | 선차감 1 | `narration`/`tts`에서 선택한 제공자 하나, 대체 없음(scope `voice`). 사용자가 보낸 100자 이하 텍스트만 허용(남용은 선차감과 레이트 리밋으로 제한) | `voice_jobs`(feature `narration`), `consume_credits(voice:<request_id>)` | 409 `VOICE_PROVIDER_UNAVAILABLE`, 402, 429 |
| POST `/api/internal/ai-token` | 오케스트레이터(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 발급만: scope는 잡 유형이 정한다(`ai.script`→`graph:video.script`, `ai.tts`→`voice`, `ai.rag_ingest`·`ai.trend_ingest`→`rag`, `ai.wiki_*`→`wiki`, `ai.step`→`graph:video.step`). `org`·`sub`는 `core.jobs` 행의 `org_id`·`created_by` | `core.jobs` 조회(`status='running'`, `app_id='video'`, 허용 job_type) | 401 `INTERNAL_KEY_INVALID`, 409 잡 상태, 429 |
| POST `/api/internal/ai-settle` | 오케스트레이터(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits`, 만료된 정밀 모드 대기 실행(24시간) 환불 | 401 |

기존 `POST /api/productions`, `POST /api/longform/*`의 입력에 추가된 필드(2절 표 해당 행): `script: { mode: 'quick'|'precise', script_run_id? }`(정밀 모드 결과를 이어 쓸 때), `voice: { provider: 'elevenlabs'|'oss-voice'|'auto', voice_id_by_lang }`. 서버는 `auto`를 시작 때 쓸 수 있는 첫 제공자로 해석해 확정값을 `options.voice`와 잡 payload에 쓴다(02장 5.3절). 선택한 제공자가 체인에서 빠져 있으면 409 `VOICE_PROVIDER_UNAVAILABLE`. 읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만), `core.wiki_pages`·`wiki_revisions`(조직 멤버).

## 3. RPC (SECURITY DEFINER)

제품 스키마 함수(`docs/products/_supabase-modular/migrations/1200_video.sql`). 코어 RPC는 CORE_SPEC 인용만.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `video.org_has_feature(p_org uuid, p_key text, p_value text default null)` | authenticated, service_role | 비멤버면 false(`is_service_caller` 또는 `is_org_member`) | boolean | - |
| `video.plan_features(p_org uuid)` | service_role | EXECUTE만 | jsonb | 42501 |
| `video.update_channel_settings(p_channel_id, p_role, p_target_language, p_target_country, p_status)` | authenticated | `is_service_caller` 또는 `has_org_role(owner,admin)`, 엔타이틀먼트, status는 active/paused만, 전이 트리거, 채널 한도 트리거 | `video.channels` | P0002, 42501, 22023, VD003 |
| `video.disconnect_channel(p_channel_id)` | authenticated | owner/admin. `core.revoke_credential` 호출 | `video.channels` | P0002, 42501 |
| `video.acknowledge_compliance_warning(p_upload_id, p_note)` | authenticated | owner/admin/member, 상태 awaiting_confirm, 최신 verdict warn, 감사 `upload.compliance_ack` | `video.uploads` | P0002, 42501, VD008, VD011 |
| `video.cancel_upload(p_upload_id)` | authenticated | owner/admin/member, 상태 허용 목록, queued 잡은 `core.cancel_job`, running이면 거부 | `video.uploads` | P0002, 42501, VD008 |
| `video.set_landing_status(p_landing_id, p_status)` | authenticated | owner/admin/member, 공개 시 `coupang_landing` + 제휴 링크 필수 | `video.landing_pages` | P0002, 42501, 22023, VD001, VD009 |
| `video.consent_clip_automation_risk(p_channel_id, p_version)` | authenticated | owner/admin, `naver_clip` 채널만, 버전 = `video.clip_notice_version()`, 감사 `channel.clip_risk_consent` | `video.channels` | P0002, 42501, 22023, VD015 |
| `video.revoke_clip_automation_consent(p_channel_id)` | authenticated | owner/admin, 감사 `channel.clip_risk_revoke`. 잡 취소는 Route Handler | `video.channels` | P0002, 42501 |
| `video.set_client_status(p_client_id, p_status)` | authenticated | owner/admin, 전이 트리거(active↔paused, → ended), 감사 `client.status` | `video.clients` | P0002, 42501, 22023 |
| `video.open_client_review(p_upload_id, p_token_hash, p_expires_at, p_requested_by)` | service_role | 업로드 approved/client_review, 채널이 고객에 묶임, 만료 14일 이내, 이전 pending 취소, 업로드 → client_review, 감사 | `video.client_reviews` | P0002, VD008, VD016, 22023 |
| `video.decide_client_review(p_token_hash, p_decision, p_reviewer_name, p_comment)` | service_role | pending만, 만료면 expired로 닫아 반환, 수정 요청이면 업로드 → draft, 감사 | `video.client_reviews` | P0002, VD008, 22023 |
| `video.clip_notice_version()` | 트리거·RPC 내부 | 상수 `clip-2026-10-v1` | text | - |
| `video.set_music_distribution_status(p_track_id, p_status, p_note, p_isrc)` | authenticated | owner/admin/member, 사용자는 submitted/live/rejected/takedown만, 전이 트리거 | `video.music_tracks` | P0002, 42501, 22023 |
| `video.get_public_landing(p_slug)` | anon, authenticated | published + 엔타이틀먼트. 공개 컬럼과 단축 코드, 대가성 문구만 | jsonb 또는 null | - |
| `video.get_public_linkinbio(p_handle)` | anon, authenticated | is_published + 엔타이틀먼트. 활성 항목, 공개 랜딩, 활성 링크만 | jsonb 또는 null | - |
| `video.purge_expired_sources(p_limit)` | service_role | `is_privileged_session`(EXECUTE가 1차 잠금) | `(source_id, org_id, storage_path)` | 42501 |
| `video.reset_channel_quotas()` | service_role | 같음 | integer | 42501 |
| `video.record_landing_view(p_slug)` | service_role | 같음 | void | 42501 |

제품 AI·음성 RPC는 만들지 않았다(05장 6절). AI는 코어 `set_ai_cross_border_ack`, `resolve_ai_route`, `match_ai_chunks`, `purge_wiki_page`와 FastAPI를 쓴다.

사용하는 코어 RPC: `session_context`, `bootstrap_app_for_org`, `consume_credits`, `grant_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `reap_stale_jobs`, `confirm_payment_order`, `apply_subscription_transition`, `expire_stale_payment_orders`, `create_oauth_state`, `consume_oauth_state`, `revoke_credential`, `write_audit`, `new_affiliate_short_code`, `record_affiliate_click`, `effective_disclosure`, `upsert_affiliate_disclosure`, `run_monthly_credit_grants`, `create_brandconnect_application`(2026-10-13, 9개 인자, `target_kind='clip'`, `source_app='video'`)(CORE_SPEC 1.3 표, 13장).

## 4. 잡 페이로드 계약

공통: 비밀값을 payload에 넣지 않고 `credential_id`만. 경로는 Storage 경로(`video-media/<org_id>/video/<entity>/<uuid>.<ext>`). 진행률 메시지는 `heartbeat_job(p_progress 0~100, p_message)`.

| `job_type` | payload | result | progress 메시지 예 |
|---|---|---|---|
| `production.run` | `{production_id, track, mode, source_id?, topic?, languages[], options{silence_cut, layer_composite, watermark}, script{mode, script_run_id?}, voice{provider, voice_id_by_lang}}`. `voice.provider`는 `auto`를 시작 때 해석한 확정값(`elevenlabs`\|`oss-voice`)을 다시 써 넣고 이후 단계는 이 값만 쓴다 | `{outputs: [{language, output_id, status}], refunded_credits}` | `"stt"`, `"translate:JA"`, `"encode:KO"` |
| `source.download` | `{source_id, url, platform}` | `{storage_path, duration_sec, phash, likes_count, title_original}` | `"download 40%"` |
| `media.stt` | `{input_path, language_hint?: 'zh'\|'ko'\|'en'\|'ja', word_timestamps: true, usage: {feature: 'video.stt', production_id}}` | `{segments: [{start, end, text}], language, transcript_path, audio_seconds, provider: 'oss-voice', model}` (워커가 `core.ai_usage` 행도 기록) | `"whisper 60%"` |
| `media.separate` | `{input_path}` | `{vocals_path, accompaniment_path}` | - |
| `media.silence_cut` | `{input_path, threshold_db: -30, min_silence_sec: 0.5}` | `{output_path, removed_sec, cut_map: [[start,end]]}` | - |
| `media.compose` | `{video_path, audio_path, ass_path, emphasis_ass_path?, reaction_layer?, template_path?, watermark: bool, size: '1080x1920'\|'1920x1080'}` | `{output_path}` | - |
| `media.encode` | `{input_path, preset: 'short'\|'longform', fps: 30\|60}` | `{output_path, duration_sec, bytes}` | - |
| `media.kenburns` | `{images: [{path, duration_sec}], size}` | `{output_path}` | - |
| `media.watermark_remove` | `{input_path, region?}` | `{output_path}` | - |
| `media.loop` | `{audio_path, image_path, size: '1920x1080'}` | `{output_path, duration_sec}` | - |
| `media.playlist_concat` | `{items: [{audio_path, duration_sec}], image_path, crossfade_sec: 2, target_sec}` | `{output_path, timestamps: [{position, start_sec}]}` | `"concat 12/20"` |
| `media.highlight_cut` | `{input_path, start_sec, end_sec, reframe: '9:16'}` | `{output_path}` | - |
| `ai.translate` | `{segments, source_lang, target_lang, tone: 'dopamine'\|'reviewer'\|'neutral'}` | `{segments}` | - |
| `ai.script` | `{track, mode: 'quick'\|'precise', topic, languages[], structure: {hook:15, body:30, cta:5}, channel_id?, script_run_id?}` 또는 `{longform_id, mode}` | `{script_run_id, script}` 또는 `{script_run_id, sections: 10}` + `{metadata: {title, description_body, tags}}`(대가성 문구 자리는 비어 있음) | `"trend"`, `"plan"`, `"script"`, `"compliance"`, `"metadata"` |
| `ai.tts` | `{text_segments, language, provider: 'elevenlabs'\|'oss-voice', voice_id, narration_group_id}` (provider·voice는 시작 때 고정된 값. 대체 없음) | `{audio_path, duration_sec, voice_job_ids: [], provider, voice_id}` | `"tts 2/3"` |
| `ai.step` | `{kind: 'translate'\|'analyze'\|'bling'\|'compliance_llm'\|'playlist_meta', input, request_id}` (D-20 (a): FastAPI 그래프 `video.step`) | `{output, run_id}` | - |
| `ai.trend_ingest` | `{countries: ['KR','US','JP'], periods}` (운영자 조직) | `{collection_id, chunks}` | - |
| `ai.rag_ingest` | `{collection: 'video-performance'\|'video-scripts'\|'video-brand', source_ids: [], full?: bool}` | `{document_ids, chunks, skipped_over_limit}` | - |
| `ai.wiki_ingest` / `ai.wiki_lint` | `{document_ids?}` / `{}` | `{run_id, pages_changed}` / `{run_id, findings}` | - |
| `ai.settle` | `{}` | `{settled, refunded}` | - |
| `ai.image` | `{prompts: [], size, model: 'flux-pro'\|'flux-ultra'}` | `{image_paths: []}` | - |
| `longform.render` | `{longform_id, languages[]}` | `{outputs: [{language, output_id}]}` | `"section 4/10"` |
| `longform.highlights` | `{longform_id, output_id}` | `{highlights: [{rank, start_sec, end_sec, output_id}]}` | - |
| `music.generate` | `{music_track_id, genre, prompt, mood?, bpm?}` | `{audio_path, cover_path, output_id, duration_sec}` | - |
| `music.package` | `{music_track_id}` | `{package_path}` | - |
| `playlist.render` | `{playlist_id}` | `{output_id, tracklist: [{position, title, start_sec}], pinned_comment_body, thumbnail_path}` | - |
| `compliance.check` | `{upload_id, platform, title, description, tags, transcript_path?, llm: bool}` | `{compliance_check_id, verdict}` | - |
| `upload.youtube` 등 | SHARED_MODULES 11장 `UploadInput` + `{upload_id}` | `UploadResult` + `{pinned: bool}` | `"upload 55%"` |
| `upload.naver_clip` | SHARED_MODULES 11장 `UploadInput` + `{upload_id, consent_version}`(워커가 실행 직전 채널의 동의 버전을 다시 확인, 다르면 실패·환불) | `UploadResult`(`pinned` 없음, `post_url`) | `"login"`, `"form"`, `"publish"` |
| `client_report.build` | `{report_id, client_id, period_month}` | `{pdf_path, kpis}` | `"aggregate"`, `"render"` |
| `radar.playboard` | `{countries: ['KR','US','JP'], periods}` | `{inserted}` | - |
| `radar.channel_finder` / `radar.bling` | `{report_id, params}` | `{report_id}` | - |
| `analytics.sync` | `{org_id?}` | `{snapshots}` | - |

## 5. 웹훅

| 수신 | 서명 방식 | event_id | 처리 |
|---|---|---|---|
| Toss | 코어 webhooks(서명 방식은 Toss 문서 기준, 미확인) | paymentKey+status+시각 해시 | 상태 동기화만, 지급은 confirm 경로 |
| fal | 미확인. 확인 전에는 `request_id`가 우리 잡의 것인지 대조 | `request_id` | 이미지 단계 완료 → 결과를 `video-media`로 복사 |
| Suno | 콜백 지원 여부 미확인. 기본은 폴링 | task id | 곡 단계 완료 |
| Distrokid(Phase 2) | 서명 필수(없으면 연동하지 않음, SM #16) | 제공자 id | 유통 상태 갱신 |
| Make/n8n 콜백(Phase 2) | HMAC-SHA256 필수(automation-core) | `X-Request-Id` | 플로우 잡 상태 |

발신(Phase 2, automation-core): `production.completed`, `upload.published`, `playlist.ready`, `music.ready`. HMAC-SHA256(`timestamp.rawBody`).

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터·비고 |
|---|---|---|---|
| YouTube Data API v3 | `packages/sns-uploader/src/youtube` | 재시도 3회, 토큰 갱신 1회 실패 시 `credentials.status=error`와 재연결 요청, 쿼터 초과 → 대체 채널 → 재예약 | 채널 기본 10,000 units/day(ADD:155), 업로드 1건 단위 비용은 미확인 |
| YouTube Analytics API | orchestrator `analytics` | 일 1회, 실패 시 다음 날 | - |
| Meta Graph(IG Reels, Threads) | `sns-uploader/src/meta` | 재시도 3회 | 앱 심사 일정 별도 |
| TikTok Content Posting | `sns-uploader/src/tiktok` | 재시도 3회 | 앱 감사 필요(MA:607) |
| 네이버 클립 크리에이터 PC 웹(공식 API 아님) | `sns-uploader/src/naver-clip`(Playwright) | 재시도 1회, 셀렉터 실패 시 `failed` + 환불 + 운영 알림, 로그인 만료 시 `channels.status=error` + 재연결 요청. `NAVER_CLIP_UPLOAD_ENABLED=false`로 즉시 끔 | 공식 업로드 API 미확인(2026-10-13). 계정당 3건/시간·15건/일(제안). 약관상 자동화 허용 여부 미확인(D-23) |
| 네이버 브랜드커넥트 | blog 소유 Playwright 어댑터(`brandconnect.apply`) | blog 규칙 | video는 지원서 생성만(코어 RPC) |
| DeepL | orchestrator `steps/translate` | 재시도 3회 → 실패(환불). 코어 라우팅 대상이 아님(D-21) | - |
| ElevenLabs(TS SDK) | Next.js `/api/voice/*`(샘플·읽어 주기), orchestrator `steps/tts`(내레이션, D-22) | 대화형은 체인 다음으로 대체(`voice_jobs.fallback_from`), 내레이션·샘플은 대체 없이 실패 + 환불. OpenAI TTS-1-HD 백업은 제거(D-14) | 요금·상업 이용 조건·데이터 보관은 구현 시 확인 |
| 오픈소스 음성 서버 | Next.js `/api/voice/*`, orchestrator `steps/tts`(서명 토큰 scope `voice`) | 같음 | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). 숏폼 대본은 구간 단위로 나눠 호출 |
| FastAPI AI 서비스(그래프) | orchestrator `steps/script`, `steps/ai-step`, Next.js `/api/ai/*` | 체인 대체(라우터) → 부분 재작성 1회(그래프) → `failed` → 환불. 120초 안에 끝나지 않으면 실패 | 대본 1건당 LLM 호출 4~8회. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| fal | 공용 fal client | 30분 미도착 실패, 환불 | `enable_safety_checker=true` |
| Suno | orchestrator `music` | 실패 시 환불 | 공식 API 미확인 |
| 쿠팡파트너스 | 공용 affiliate 어댑터 | 링크 없이 업로드 진행(문구도 미삽입) | HMAC 키는 `encrypted_credentials` |
| 텐핑, 네이버쇼핑 커넥트 | 공용 affiliate 어댑터(수동 등록 capability) | - | 공개 API 미확인. YSM CLAUDE의 엔드포인트 명세(`git show 5f6d262:Youtube_shots_Maker/CLAUDE.md` 852-866행)는 검증되지 않은 설계라 쓰지 않는다 |
| SerpApi, RapidAPI, Google Trends | orchestrator `radar` | 실패 시 이전 스냅샷 유지, 난수 대체 금지 | 프록시 풀 경유(소싱·스크래핑만) |
| Toss | 코어 toss | CORE_SPEC 5장 | - |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 video가 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | video 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류·용어 설명 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`, `wiki.query`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 R-V9). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `coach`: 매핑 org의 조직 컬렉션(`video-performance`, `video-scripts`, `video-brand`)과 게시된 위키 + 운영자 컬렉션(`video-trends`) 검색 → `chat` 모델. `context_ref`는 매핑 org 소유인지 확인. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /dify/retrieval` | Dify 외부 지식 | 내부 키 | 운영자 조직의 `video-guide`·`video-trends`만. 사용자 조직 데이터 금지 |
| `POST /graphs/video.script/runs`, `POST /graphs/video.script/runs/{id}/resume`, `GET /graphs/runs/{id}` | Next.js, 오케스트레이터 | 서명 토큰(잡 토큰 포함) scope `graph:video.script`, `jti` 1회 | 대본 그래프. UI 시작 정밀 모드는 `plan` 뒤 interrupt |
| `POST /graphs/video.step/runs` | 오케스트레이터 | 잡 토큰 scope `graph:video.step` | 파이프라인 LLM 단계(D-20) |
| `POST /rag/ingest` | Next.js, 오케스트레이터 | 서명 토큰 scope `rag` | 조직 컬렉션(조직 id=토큰 org), 운영자 컬렉션(`VIDEO_KNOWLEDGE_ORG_ID` 토큰, 운영자 작업만) |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-V9) | Next.js | 서명 토큰 scope `wiki` | 위키 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`video-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `video-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_VIDEO`(Next.js 서버 전용). 정의는 `infra/dify/video-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `context_ref`(선택, `channel:<uuid>`·`upload:<uuid>`·`production:<uuid>` 문자열, 대화 시작 때만). 서명 토큰, org, 채널 토큰, 개인정보는 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`). FastAPI는 `context_ref` 대상이 매핑 org 소유인지 매번 확인한다. DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `coach`: HTTP 요청 노드 → 답변 / 분기 `guide`: 지식 검색 노드(외부 지식 `video-guide` → `/dify/retrieval`) → LLM 노드(model `wiki.query`) → 답변 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, context_ref, mode: "coach" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title, is_estimated? }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | `coach` 분기는 FastAPI가 `ai_messages.citations`를 기록하고, `guide` 분기는 Next.js가 Dify 응답의 검색 출처 메타데이터로 기록한다 |
| 첫 표시 지연 | `coach` 분기는 HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다(01장 5절) |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| VD001 | 필요한 연결 없음(랜딩 공개에 제휴 링크 없음 등) | 409 |
| VD002 | 참조 대상 조직 불일치 | 403 |
| VD003 | YouTube 채널 한도 초과 또는 엔타이틀먼트 없음 | 409 |
| VD004 | 플랜에 없는 플랫폼 | 403 |
| VD005 | 상태 잠금으로 편집 불가 | 409 |
| VD006 | 플리 곡 출처 부적합(미완성, 라이선스 만료, 수익화 불가) | 422 |
| VD007 | 제휴 링크와 대가성 문구 불일치 | 422 |
| VD008 | 업로드 상태에서 허용되지 않는 동작 | 409 |
| VD009 | 플랜 기능 없음(Track, 랜딩 등) | 403 |
| VD010 | 주제 점수 60 미만 | 409 |
| VD011 | compliance 게이트 미충족(FAIL 또는 WARN 미확인) | 409 |
| VD012 | 월 한도 초과(블링 등) | 429 |
| 22023 | 상태 전이 위반, 인자 오류 | 409 |
| 23514 | CHECK 위반(대가성 문구, 출처 없는 블링 등) | 422 |
| VD013 | 같은 목소리 규칙 위반: 재생성 요청의 제공자·보이스가 기록된 값과 다름(앱 코드, DB 미사용) | 422 |
| VD014 | 정밀 모드 실행이 만료됐거나 이미 재개됨(앱 코드) | 409 |
| VD015 | 네이버 클립 자동 업로드 위험 동의 없음 또는 고지문 버전 불일치(DB 트리거·RPC) | 409 + "채널 설정에서 위험 안내에 동의해 주세요" |
| VD016 | 고객 승인 필요: 고객 채널 업로드를 승인 없이 예약하려 함, 또는 고객에 묶이지 않은 채널에 승인 요청(DB 트리거·RPC) | 409 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한 | 429 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 60초 또는 5MB 초과 | 413 |
| 앱 코드 `VOICE_PROVIDER_UNAVAILABLE` | 선택한 내레이션 엔진을 쓸 수 없음(국외 이전 미동의, 비활성, 언어 미지원). 대체하지 않음 | 409 |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전이 서버 값과 다름 | 409 |
| 앱 코드 `INTERNAL_KEY_INVALID` | 오케스트레이터 키 또는 Dify 내부 키 불일치 | 401 |
| 앱 코드 `AI_INDEX_LIMIT` | 조직 월 색인 청크 상한 초과(색인 보류) | 429 |
| FastAPI `AI_TOKEN_INVALID` | 서명, `aud`, scope, 만료, `jti` 재사용 | 401 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 저장 시 `expected_version`이 현재 버전과 다름(`docs/products/_platform-core/LLM_WIKI.md:31`) | 409 |
| 코어 코드 | `42501`→403, `CR001`→402, `P0002`/`PM404`→404, `SB001`/`JB002`/`PM410`→409, `PM001`/`PM409`→409+운영 알림, `OA001`→400 | CORE_SPEC 15장 |

## 8. 로그인 경로 (2026-10-14 추가, 확정 결정 22)

정본: `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절. 이 절의 경로는 사용자 계정 로그인만 다룬다. 채널 연결 OAuth(`POST /api/channels/connect`, `GET /api/channels/callback/[platform]`, `core.oauth_states`)와 네이버 클립 브라우저 로그인 세션(`POST /api/channels/connect/naver-clip`)은 2절 그대로이며 단계와 무관하다.

| 메서드 경로 | 단계 | 역할 | 입력(zod 요약) | 출력 | 처리 | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/dev/login` | A(로컬 전용) | 공개(판정이 참일 때만 존재) | `{ persona: 'owner'\|'admin'\|'member'\|'viewer'\|'outsider'\|'no_app'\|'suspended'\|'ops'\|'adv_owner'\|'adv_member', next?: string }` | 302 `next`(화이트리스트) 또는 `/dashboard` | `isMockAuthAllowed()` 확인 → 쿠키 세션 서버 클라이언트로 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('video', next)` | 판정 거짓 → 404(존재 자체를 숨김). 알 수 없는 페르소나 422, 시드 안 됨 → 401 + "`node scripts/dev/seed-users.mjs --app video`를 먼저 실행하세요". 레이트 리밋 없음(로컬 전용) |
| GET `/auth/callback` | B·C1·C2(`custom:naver`) | 공개 | `code`, `next?` | 302 | `finishLogin`: (1) `exchangeCodeForSession`(PKCE) (2) `session_context('video')` 1회 (3) `entitled=false`이면 video는 open 앱이므로 `rpc('bootstrap_app_for_org', { p_app_id: 'video' })` 1회 후 재조회(크레딧 멱등 `signup:<org>:video`) (4) `status` 분기: suspended 403 (5) `next`가 `/`로 시작하고 `//`·`@`·`\` 없을 때만, 아니면 `/dashboard`(첫 로그인이면 온보딩, 03장 7.3절). origin은 `NEXT_PUBLIC_APP_URL` 고정 (6) 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 없음) | `code` 없음·재사용·만료 → `/login?error=callback`. 프로필 없음 → 로그아웃 후 `/login` |
| GET `/auth/naver/start` | C2 브리지 채택 시만 | 공개 | `next?` | 302 네이버 authorize | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 서명 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분)에 저장. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 429 |
| GET `/auth/naver/callback` | C2 브리지 채택 시만 | 공개 | `code`, `state` | 302 | state 상수 시간 비교·쿠키 삭제 → 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(provider `naver`, 네이버 고유 id)로 사용자 찾기 → 없으면 같은 이메일 사용자 확인 → `generateLink`+`verifyOtp`로 세션 → `finishLogin`. 네이버 토큰은 저장하지 않는다 | state 불일치·없음·만료 → `/login?error=state`. 같은 이메일 기존 사용자 → `/login?error=email_in_use`(자동 병합 금지) |

`core.oauth_states`는 브리지 state에 쓰지 않는다(로그인 전에는 사용자·조직이 없어 `user_id not null`을 채울 수 없다, `AUTH_ROADMAP.md` 7.2.3절). 채널 연결 state와 브리지 state는 저장소가 다르다.

오류 코드(앱 코드, DB 미사용):

| 코드 | 의미 | HTTP |
|---|---|---|
| `AUTH_CALLBACK_FAILED` | 콜백 코드 교환 실패. 사용자에게는 `/login?error=callback` | 302 |
| `AUTH_STATE_INVALID` | (C2 브리지) state 불일치·재사용·만료 → `/login?error=state` | 302 |
| `AUTH_EMAIL_IN_USE` | (C2 브리지) 같은 이메일의 다른 로그인 수단 사용자 존재 → `/login?error=email_in_use` | 302 |
| `DEV_LOGIN_UNAVAILABLE` | Mock 판정 거짓. 응답 본문 없이 404 | 404 |

## 9. 스토리보드 API (2026-10-18 추가, 스토리보드 디벨롭)

정본은 01장 10장(VD-F-130~142, 단가 10.4절)이고 구조는 02장 10장이다. 기존 장의 줄은 바꾸지 않았다. 1절 원칙(인증, zod, `request_id` 멱등, Route Handler 선차감 → `enqueue_job`, 응답 봉투, 레이트 리밋)이 그대로 걸린다. Track 값은 이제 `A`, `B`, `S`, `E`, `F`다(1절 "Track `A-F`"와 2.1절 `/api/ai/script`의 `track: 'B'|'C'|'D'`는 이 장을 따라 `S`를 받는다. 새 `C`·`D` 생성 요청은 받지 않는다). 기존 `POST /api/longform/*`(2절)에는 새 코드를 넣지 않는다(01장 VD-F-142, D-34). 화면 경로는 `/dashboard/storyboards/...`(03장 8장)이다.

### 9.1 Route Handler

2절 표와 같은 열이다. 크레딧은 01장 10.4절 값이다. "(제안)"이 붙은 경로는 명세 7절 목록에 없지만 VD-F-132·134를 처리하려고 더한 것이다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/storyboards` | member+, `features.storyboard` | `{title, format: 'shorts'\|'longform', target_seconds(형식 프리셋 값만), template_code, topic, languages[](플랜 `languages` 안, 첫 값이 기본 언어), client_id?, script: {mode: 'quick'\|'precise', script_run_id?}, request_id}`. 화면비는 서버가 형식으로 정한다 | storyboard(draft, version 1) + `{scriptJobId?}` | 빠른 모드 대본 쇼츠 3 / 롱폼 5. 정밀 모드(`script_run_id`, `/api/ai/script`에서 이미 선차감)는 0 | 주제 점수 게이트(VD-F-013, 대본 단가에 포함) → `storyboards` INSERT(RLS) → consume → enqueue `ai.script`(빠른 모드, `{storyboard_id}`) | 403 `VD009`(storyboard=false, `storyboard_max_minutes` 초과), 409 `VD010` + `alternatives`, 402, 404(`script_run_id` 없음·다른 조직), VD002 → 403(다른 조직 `client_id`) |
| GET `/api/storyboards/[id]` | 전 역할 | - | storyboard + scenes(순서대로) + 장면별 `ready` 소재(서명 URL 10분) + cuts + 진행 중 잡 + `{length_gauge: {total_ms, min_ms, max_ms}, source_warnings, estimate}` | 0 | RLS select, Storage 서명 URL | 404 |
| POST `/api/storyboards/[id]/generate` | member+ | `{request_id}`(처음 생성과 전체 다시 생성이 같은 경로) | `{jobId}` | 쇼츠 4 / 롱폼 10분당 8(`ceil(target_seconds/600)`) | 대본 ready 확인 → consume → enqueue `storyboard.generate`. 레이트 리밋 `video:ai-graph:<org>`(1절) | 409 `VD020`(rendering), 409 22023(대본 없음), 402, 429 |
| PATCH `/api/scenes/[id]` | member+ | `{revision, patch: {narration?(≤600), on_screen_text?(≤160), visual_prompt?(≤600), duration_ms?, motion_preset?, music_cue?, chapter?, kind?, sources?(≤5: title, url, note)}}` | scene(새 revision) | 0 | 사용자 세션 `rpc('video.save_scene', {p_scene_id, p_revision, p_patch})` | 409 `VD409`(detail에 현재 revision), 409 `VD020`, 422 23514, 403 42501, 404 |
| POST `/api/storyboards/[id]/reorder` | member+ | `{scene_ids: uuid[](현재 장면 전부), revision}` | scenes(새 순서) + storyboard revision | 0 | `video.reorder_scenes` | 409 `VD409`, 409 `VD020`, 409 22023(집합 불일치) |
| POST `/api/storyboards/[id]/scenes` (제안) | member+ | `{after_scene_id?, kind, duration_ms, revision}` | scene | 0 | `video.add_scene` | 422 `VD018`, 409 `VD409`, 409 `VD020` |
| DELETE `/api/scenes/[id]` (제안) | member+ | `{revision}`(스토리보드 revision) | 204 | 0 | `video.delete_scene` | 409 `VD409`, 409 `VD020`, 409 22023(마지막 장면) |
| POST `/api/scenes/[id]/shorts-candidate` (제안) | member+ | `{value: boolean}` | scene | 0 | `video.set_shorts_candidate` | 409 `VD020`, 409 22023(쇼츠 형식 스토리보드) |
| POST `/api/scenes/[id]/regenerate` | member+ | `{part: 'image'\|'narration', lang?(narration 필수), reuse_asset_id?(image만), request_id}` | `{jobId}` 또는 재사용이면 scene_asset | image 3, narration 1(1장면 1언어), 재사용 0(원장 행 없음) | 재사용: 같은 조직 `ready` 이미지 확인 → `finish_scene_asset`(service, `reused_from_asset_id`). 그 밖: consume → enqueue `scene.image` / `scene.narration`. 내레이션 제공자·보이스는 스토리보드에 처음 기록된 값 | 409 `VD020`, 422 `VD013`(보이스 불일치), 422(`text_card`·`title` 장면의 image), 402, 404 |
| POST `/api/storyboards/[id]/assets` (제안) | member+ | `{images: boolean, narration?: {lang, provider: 'elevenlabs'\|'oss-voice'\|'auto', voice_id}, request_id}` | `{jobIds[]}` | image: 소재 없는 `image` 장면 수 x 3. narration: 4.1절 정액(쇼츠 언어당 ElevenLabs 5 / 오픈소스 2, 롱폼 10분 언어당 5 / 2) | 이미지는 장면마다 consume(`consume:video:<request_id>:<scene_id>`) → enqueue `scene.image`. 내레이션은 consume 1회 → enqueue `scene.narration` 1잡(장면 묶음). `auto`는 시작 때 확정값으로 바꿔 기록(02장 5.3절) | 409 `VD020`, 409 `VOICE_PROVIDER_UNAVAILABLE`, 402 |
| POST `/api/scenes/[id]/upload` (제안) | member+ | `{kind: 'image'\|'clip', path(org-files 자기 조직 경로), rights_basis(clip 필수), rights_note(clip 필수)}` | scene_asset | 0 | 경로 접두 확인 → `finish_scene_asset`(service, `ai_generated=false`). clip 길이·코덱 확인은 렌더 1단계에서 | 422 `VD019`, 422 23514(다른 조직 경로), 413(500MB 초과) |
| POST `/api/storyboards/[id]/render` | member+ | `{languages[](storyboard languages 안), voice?: {provider, voice_id_by_lang}, bgm?: {library_track_id}\|null, request_id}` | `{rootJobId, cutId, snapshotVersion}` | 렌더(쇼츠 언어당 3, 롱폼 10분당 10을 언어판마다, 제안) + 내레이션이 없는 언어의 4.1절 TTS 정액 + 출처 점검 1 | 서버 검사(VD009, VD017, VD018, VD019, VD001) → consume → `video.snapshot_storyboard`(service) → enqueue `storyboard.render`. 동시 생산 상한(01장 5장)에 포함 | 403 `VD009`, 422 `VD017`·`VD018`·`VD019`, 409 `VD001`(소재 없는 장면, detail `scene_ids`), 409 `VD020`(이미 렌더 중), 402, 429 |
| POST `/api/storyboards/[id]/shorts` | member+, `shorts_extract_max` ≥ 1 | `{step: 'pick', max_cuts(1~10), request_id}` 또는 `{step: 'render', cut_ids[], vertical: 'crop'\|'regenerate'(기본값 D-32), languages[], request_id}` | pick: `{rootJobId}` → 제안 컷(`storyboard_cuts` kind `short`) / render: `{rootJobId, snapshotVersions[]}` | pick 2 / render 컷·언어당 3 + `regenerate`면 세로 이미지 장면 수 x 3 | `longform` + ready 마스터 컷 확인 → consume → (render) 컷마다 `snapshot_storyboard` → enqueue `storyboard.shorts` | 409 22023(쇼츠 형식, 마스터 없음, 비연속 장면), 403 `VD009`(플랜 한도 초과, 제안), 422 `VD021`(11번째 컷), 402 |
| GET `/api/storyboards/[id]/snapshots/[version]` | 전 역할 | - | 스냅샷 jsonb(9.4절 키) 읽기 전용 | 0 | RLS select `storyboard_snapshots` | 404 |

기존 Route Handler에서 바뀌는 동작:

| 경로 | 변경 |
|---|---|
| POST `/api/uploads` | `outputId`의 `storyboard_cut_id`가 있으면 서버가 그 컷 스냅샷의 장면 출처로 "참고 자료" 목록을 설명란에 넣는다. 대가성 문구 첫 줄 뒤(VD-F-062 순서, VD-F-138). AI 생성 소재가 있으면 01장 10.5절 AI 생성 표시 문구를 기본으로 넣는다 |
| POST `/api/uploads/[id]/check` | 스냅샷의 출처 점검 WARN을 compliance 항목으로 넘긴다. FAIL로 올리지 않는다(D-33) |
| POST `/api/internal/ai-token` | 잡 유형 → scope 대응에 더한다: `storyboard.generate`→`graph:video.storyboard`, `storyboard.shorts`→`graph:video.shorts_pick`, `storyboard.source_check`→`graph:video.step`, `scene.narration`·`storyboard.render`(TTS 단계)→`voice` |

### 9.2 RPC

3절 표와 같은 열이다. 이름은 명세 6절(05장 11장)과 같다. 인자 중 명세에 없는 것은 "(제안)"으로 적었다.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `video.save_scene(p_scene_id uuid, p_revision int, p_patch jsonb)` | authenticated | owner/admin/member, 엔타이틀먼트 `storyboard`, 스토리보드 status가 `rendering`이 아님, `revision = p_revision`, 패치 키 허용 목록, 글자 수·sources 5개 이하. 성공 시 장면 revision +1, `rendered`면 `ready`로(제안) | `video.scenes` | P0002, 42501, VD409, VD020, 22023, 23514 |
| `video.reorder_scenes(p_storyboard_id uuid, p_scene_ids uuid[], p_revision int)` | authenticated | 위와 같은 권한·상태, `p_scene_ids`가 현재 장면 집합과 같음, 스토리보드 `revision = p_revision`(01장 VD-F-132, 인자는 제안). `ord` 다시 매김(deferrable unique) | `video.storyboards`(새 revision) | P0002, 42501, VD409, VD020, 22023 |
| `video.add_scene(p_storyboard_id uuid, p_after_scene_id uuid, p_kind text, p_duration_ms int, p_revision int)`(인자는 제안) | authenticated | 위와 같음, 장면 수 240 이하와 형식별 상한(쇼츠 12) | `video.scenes` | P0002, 42501, VD409, VD020, VD018, 22023 |
| `video.delete_scene(p_scene_id uuid, p_revision int)`(인자는 제안) | authenticated | 위와 같음, 마지막 장면 삭제 금지. 소재는 지우지 않는다(스냅샷 참조) | void | P0002, 42501, VD409, VD020, 22023 |
| `video.set_shorts_candidate(p_scene_id uuid, p_value boolean)` | authenticated | 위와 같은 권한·상태, `longform`만 | `video.scenes` | P0002, 42501, VD020, 22023 |
| `video.apply_storyboard_result(p_storyboard_id uuid, p_ai_run_id uuid, p_scenes jsonb, p_expected_version int)`(인자는 제안) | service_role | `is_service_caller`, version 일치, 장면 수(VD018)·길이 합계(VD017) 재검사, enum. 장면 교체, version +1, status `ready` | `video.storyboards` | 42501, VD017, VD018, 22023 |
| `video.finish_scene_asset(p_scene_id uuid, p_kind text, p_lang text, p_storage_path text, p_ai_generated boolean, p_rights_basis text, p_reused_from_asset_id uuid)`(인자는 제안) | service_role | 경로가 자기 조직 폴더(CHECK), clip은 `rights_basis` 필수, 같은 장면·종류·언어의 기존 `ready` → `superseded` | `video.scene_assets` | 42501, VD019, 23514, P0002 |
| `video.snapshot_storyboard(p_storyboard_id uuid, p_cut_kind text, p_scene_ids uuid[], p_hook_text text)`(인자는 제안) | service_role | 마스터: VD017·VD018·VD019, 모든 장면 소재 `ready`(VD001), status → `rendering`. 쇼츠: 연속 장면, 컷 10개 이하(VD021). 컷 행 upsert + 스냅샷 1행 | `(cut_id, snapshot_id, version)` | 42501, VD001, VD017, VD018, VD019, VD020, VD021, 22023 |

렌더 종료 때 `storyboards.status`(rendering → rendered/ready)와 `storyboard_cuts.status`는 오케스트레이터가 service_role로 바꾸고 전이 트리거가 검사한다(05장 11장).

### 9.3 잡 공통 규칙

4절 공통 규칙 그대로다: payload에 비밀값·원문 대본 전체를 넣지 않고 id와 Storage 경로만, 경로는 `video-media/<org_id>/video/storyboards/<storyboard_id>/<uuid>.<ext>`(제안), 진행률은 `heartbeat_job`. 렌더 계열 워커는 payload가 아니라 스냅샷에서 장면을 읽는다.

### 9.4 잡 페이로드 계약

4절 표와 같은 열이다.

| `job_type` | payload | result | progress 메시지 예 |
|---|---|---|---|
| `storyboard.generate` | `{storyboard_id, script_run_id, template_code, format, aspect, target_seconds, base_language, expected_version}` | `{ai_run_id, version, scene_count}`(장면 저장은 FastAPI가 `apply_storyboard_result`로 1회) | `"beats"`, `"scenes"`, `"claims"`, `"validate"`, `"compliance"` |
| `scene.image` | `{scene_id, storyboard_id, prompt(서버 조립: 시각 설명 + 스타일 접미어 + 금지 접미어), size: '1920x1080'\|'1080x1920', model: 'flux-pro'\|'flux-ultra', seed, purpose: 'scene'\|'vertical'}` | `{scene_asset_id, storage_path, seed, model, width, height}` | - |
| `scene.narration` | `{storyboard_id, scene_ids[], language, provider: 'elevenlabs'\|'oss-voice', voice_id, narration_group_id}`(시작 때 고정된 값, 대체 없음) | `{assets: [{scene_id, scene_asset_id, storage_path, duration_ms}], voice_job_ids[], provider, voice_id}` | `"tts 12/40"` |
| `storyboard.render` | `{storyboard_id, cut_id, snapshot_id, languages[], voice: {provider, voice_id_by_lang}}`(워터마크·BGM·장면은 스냅샷에서) | `{outputs: [{language, output_id, status}], source_warnings: [{scene_id, kind}], refunded_credits}` | `"narration:JA"`, `"source_check"`, `"scene 12/40"`, `"concat:KO"`, `"subtitle:KO"`, `"bgm:KO"`, `"encode:KO"` |
| `storyboard.source_check` | `{storyboard_id, snapshot_id}` | `{run_id, warnings: [{scene_id, kind: 'no_source'\|'weak_source', note}]}` | - |
| `storyboard.shorts` | pick: `{storyboard_id, phase: 'pick', master_snapshot_id, max_cuts}` / render: `{storyboard_id, phase: 'render', cuts: [{cut_id, snapshot_id}], vertical: 'crop'\|'regenerate', languages[]}` | pick: `{ai_run_id, cut_ids[]}` / render: `{outputs: [{cut_id, language, output_id, status}], refunded_credits}` | `"pick"`, `"hook"`, `"cut 2/5:KO"` |
| `media.scene_clip`(제안) | `{snapshot_id, scene_id, kind, duration_ms, motion_preset, image_path?, clip_path?, text?, layout: 'landscape'\|'portrait', size: '1920x1080'\|'1080x1920', fps: 30, hold_ms_by_lang?: {KO: 0, JA: 400}}` | `{output_path, duration_ms}` | - |
| `media.scene_concat`(제안) | `{clips: [{path, duration_ms}], narration: [{start_ms, path}], language}` | `{output_path, duration_ms}` | `"concat 12/40"` |
| `media.bgm_mix`(제안) | `{video_path, bgm_path\|null, duck_db: -12, fade_ms: 2000}` | `{output_path}` | - |
| `media.compose`, `media.encode`, `media.stt` | 4절 그대로. Track S는 `media.compose`에 `reaction_layer: null`, `template_path: null`, `emphasis_ass_path`(image 장면 화면 문구)를 넣는다 | 4절 그대로 | - |

스냅샷 `snapshot` 키(제안, 05장 11장 jsonb와 같아야 한다): `storyboard`(id, version, revision, format, aspect, target_seconds, template_code, languages, voice), `cut`(id, kind, aspect, scene_ids, hook_text), `scenes`(ord, id, kind, duration_ms, narration, on_screen_text, motion_preset, music_cue, chapter, sources, `assets`: {image?, clip?, narration_by_lang}), `bgm`(library_track_id, path, license_type 또는 null), `watermark`, `has_ai_assets`, `total_ms`. 계약 스키마는 TS(zod)와 Python(pydantic) 두 곳에 같게 두고 동치 테스트로 묶는다(제안, book-trailer `docs/products/book-trailer/04_API.md:97`과 같은 방식).

### 9.5 FastAPI 엔드포인트와 그래프 계약

6.1절 표와 같은 열이다.

| 엔드포인트 | 호출자 | 인증 | video 사용 |
|---|---|---|---|
| `POST /graphs/video.storyboard/runs`, `GET /graphs/runs/{id}` | 오케스트레이터(`storyboard.generate`) | 잡 토큰 scope `graph:video.storyboard`, `jti` 1회 | 장면 목록 생성. interrupt 없음. 결과는 FastAPI가 `apply_storyboard_result`로 저장 |
| `POST /graphs/video.shorts_pick/runs`, `GET /graphs/runs/{id}` | 오케스트레이터(`storyboard.shorts` pick 단계) | 잡 토큰 scope `graph:video.shorts_pick` | 쇼츠 컷 후보와 훅 문구. 컷 행은 오케스트레이터가 service_role로 쓴다 |
| `POST /graphs/video.step/runs`(kind `source_check`, 제안) | 오케스트레이터(`storyboard.source_check`) | 잡 토큰 scope `graph:video.step` | 출처 점검. 기능 키 `video.analyze`(제안) |

Next.js는 이 그래프들을 직접 부르지 않는다(사람 승인 단계가 그래프 안에 없다).

그래프 입출력(02장 10.9절 노드 순서):

| 그래프 | 입력 | 출력 | 서버 재검증 |
|---|---|---|---|
| `video.storyboard` | `{storyboard_id, script_run_id(대본은 FastAPI가 ai_runs에서 읽는다), template: {code, beats: [{name, weight}], default_scene_seconds}, format, aspect, target_seconds, base_language}` | `{scenes: [장면 JSON], total_ms, compliance: {verdict, items}}` | 장면 수, 길이 합계 ±10%, 글자 수, enum. 실패면 `VD017`·`VD018`로 run `failed` + 환불 |
| `video.shorts_pick` | `{storyboard_id, master_snapshot_id, max_cuts}` | `{cuts: [{scene_ids[](연속), duration_ms(≤60000), hook_text(≤40자, 제안), reason}], compliance}` | 연속성, 겹침 없음, 컷 길이, 개수 ≤ `min(max_cuts, 10)` |
| `video.step` kind `source_check` | `{scenes: [{scene_id, narration, on_screen_text, source_required, sources}]}` | `{warnings: [{scene_id, kind, note}]}` | 장면 id가 스냅샷 안에 있는지 |

장면 JSON(`video.storyboard` 출력 원소):

```json
{
  "ord": 1,
  "chapter": "1부 시대 배경 | null",
  "kind": "image | clip | text_card | title",
  "duration_ms": 8000,
  "narration": "600자 이하",
  "on_screen_text": "160자 이하",
  "visual_prompt": "600자 이하",
  "motion_preset": "zoom_in | zoom_out | pan_left | pan_right | static",
  "music_cue": "문자열 | null",
  "shorts_candidate": false,
  "source_required": true,
  "sources": [{ "title": "근거 문서 제목", "url": "근거 id가 있는 URL만", "note": "근거 id" }]
}
```

`sources`는 근거 id(RAG 청크·검색 결과)가 있을 때만 채우고, 없으면 빈 배열이다. 그래프는 URL을 지어내지 않는다(01장 VD-F-138). `clip` 장면은 그래프가 만들지 않고 사용자가 편집기에서 바꾼다(제안).

### 9.6 오류 코드

7절 표와 같은 열이다. HTTP 대응은 제안이다.

| 코드 | 의미 | HTTP |
|---|---|---|
| VD017 | 장면 길이 합계가 목표 길이 ±10% 밖(그래프 결과 저장, 렌더 요청) | 422 + detail `{total_ms, min_ms, max_ms}` |
| VD018 | 장면 수 한도 초과(쇼츠 3~12, 롱폼 분당 3~8, 최대 240) | 422 + detail `{count, min, max}` |
| VD019 | `clip` 장면에 권리 근거(`rights_basis`, 근거 메모) 없음 | 422 + "원본의 권리 근거를 선택해 주세요" |
| VD020 | 렌더 중(`rendering`) 편집·다시 만들기·렌더 재요청 | 409 + "렌더가 끝난 뒤 다시 시도해 주세요" |
| VD021 | 쇼츠 컷 10개 초과 | 422 |
| VD409 | 낙관적 동시성 충돌: 장면 또는 스토리보드 revision이 현재 값과 다름 | 409 + detail `{current_revision}`. 화면은 최신본을 다시 불러온다 |

기존 코드의 Track S 쓰임: `VD001`(렌더할 장면에 `ready` 소재 없음, detail `scene_ids`), `VD009`(storyboard 엔타이틀먼트 없음, `storyboard_max_minutes`·`shorts_extract_max` 초과), `VD010`(주제 점수 60 미만), `VD013`(장면 내레이션 보이스가 기록된 값과 다름), `22023`(비연속 쇼츠 컷, 쇼츠 형식에 쇼츠 추출, 마스터 컷 없음, 마지막 장면 삭제).
