# 04 API: Live Poll

조각 = `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1800_poll.sql`. 모놀리스는 같은 함수가 `public.`에 있다.

2026-10-13 개정: `/api/ai/*`, `/api/voice/*`, 청중 음성 질문 `/api/p/voice-question`, FastAPI 엔드포인트, Dify 계약, AI 오류 코드를 추가했다. 새 RPC는 없다(AI는 기존 RPC와 코어 AI·크레딧 RPC를 쓴다).

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 진행자 인증 | `requireSession('poll')`(`SHARED_MODULES.md` 2장). 세션은 모든 인증 단계(A Mock, B Google·이메일, C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(8절, `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 0장). 진행자 쓰기는 대부분 브라우저에서 RLS(문항/선택지 draft 편집, 행사 제목/설정)와 authenticated RPC로 직접 한다. Route Handler는 CSV, 오버레이 키처럼 서버 처리가 필요한 것만 |
| 청중 인증 | Supabase 세션 없음(인증 단계와 무관, Mock 단계에서도 같다). Route Handler가 쿠키 `lp_pt_<eventId>`(httpOnly, Secure, SameSite=Lax, 7일)의 참가자 토큰(32바이트 base64url)을 읽어 service_role RPC에 넘긴다. 토큰이 없으면 `/api/p/join`만 허용 |
| IP | `x-forwarded-for` 첫 값(Vercel이 설정)을 `HMAC-SHA256(POLL_IP_HMAC_SECRET, yyyy-mm-dd + ip)` hex로 바꿔 `p_ip_hash`로만 넘긴다. 원문 IP는 로그에도 남기지 않는다 |
| 멱등 | 투표는 서버 unique가 멱등을 보장한다(재시도 안전, 두 번째는 PL005). 행사 생성은 클라이언트 `request_id`를 받아 Route Handler 없이 RPC를 쓰므로 버튼 중복 클릭은 UI에서 막는다(제안: 필요하면 `idempotency_key` 컬럼 추가) |
| 크레딧 | 투표·일반 질문·입장·오버레이 경로는 없음. AI·음성 경로(`/api/ai/*`, `/api/voice/*`, `/api/p/voice-question`)만 2.1절 표대로 선차감·정산 |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }`. 청중 RPC의 jsonb `{ok,code}`를 그대로 매핑 |
| 레이트 리밋 | RPC 안에서 `core.rate_limit_hit`(01장 5절). Route Handler는 본문 크기 4KB 상한 |
| 캐시 | 청중/오버레이 API는 `Cache-Control: no-store`, `X-Robots-Tag: noindex` |
| 폴링 금지 | 스냅샷 API는 입장 직후, 재구독 직후, seq 공백, 15초 무수신에만 호출한다. 주기 호출 금지(원본 CLAUDE:8). AI 실행 진행은 SSE로 받고, 색인 상태 같은 AI 비동기 결과도 주기 조회하지 않는다(화면 진입·새로고침 버튼 때 1회) |
| AI·음성 경계 | 진행자 브라우저는 `/api/ai/*`, `/api/voice/*`만, 청중 브라우저는 `/api/p/*`만 부른다. Dify, FastAPI, LLM·음성 제공자는 Route Handler가 부른다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299`). 청중 참가자 쿠키는 `/api/ai/*`, `/api/voice/*`에서 항상 401 |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT를 발급: `iss=poll`, `aud=platform-ai:poll`, `org`, `app=poll`, `sub`(진행자 사용자 id, 청중 음성은 `visitor:pt:<participant_id>`), `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분). org는 세션 또는 참가자 토큰이 가리키는 행사에서만 가져온다(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:33-42`) |
| AI 멱등 키 | 채팅 `conv:<id>:turn:<n>`(같은 `request_id` 재전송은 `poll:ai-req:<request_id>` 버킷 1회로 막는다), 음성 `voice:<voice_job_id>`(클라이언트 `request_id`를 `voice_jobs.id`로 쓴다), 청중 음성 묶음 `voice-block:<event_id>:<n>`, 그래프·색인·위키 `run:<ai_run_id>` |
| AI 선차감·정산 | 선차감은 제공자 호출 전 Route Handler에서, 정산은 응답 종료 직후 같은 Route Handler에서. 연결이 끊기면 `/api/internal/ai-settle`(워커가 5분마다 호출)이 처리 |
| 스트리밍 | 채팅과 Q&A 정리는 SSE(`text/event-stream`) |
| AI 레이트 리밋 | `poll:ai-chat:<user>` 20회/60초, `poll:ai-chat-day:<user>` `ai_chat_turns_per_day`회/86400초, `poll:voice-stt:<user>` 10회/60초, `poll:qna-assist:<org>` 10회/3600초, `poll:materials:<org>` 20회/3600초, 청중 음성 5중 키는 02장 5-4절 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/p/join` | 청중 | `{code: /^\d{6}$/, nickname?: string<=30, passcode?: string 4..12}` | `{participant_id, event_id, topic, rejoined}` + Set-Cookie | 0 | `poll.join_event` | PL001, PL002, PL003, PL004, PL007, PL008, PL009, PL013, PL429 |
| GET `/api/p/snapshot?event=<id>` | 청중(쿠키) | - | `{seq, state, me, topic, ai: {audience_voice: boolean}}` (`ai`는 핸들러가 service_role로 `events.settings`를 읽어 덧붙인다. RPC 응답은 바뀌지 않는다) | 0 | `poll.participant_snapshot` | PL002, PL009, PL429 |
| POST `/api/p/realtime-token` | 청중(쿠키) | `{event_id}` | `{token, expires_at, topic}` (JWT: role anon, `poll_topic`, `poll_aud:'participant'`, exp 6h) | 0 | `participant_snapshot`로 토큰 유효성과 live 여부 확인 후 서명 | PL002, PL009 |
| POST `/api/p/vote` | 청중(쿠키) | `{poll_id: uuid, option_ids?: uuid[]<=10, rating?: int 1..10}` | `{vote_id}` | 0 | `poll.cast_vote` | PL002, PL005, PL006, PL007, PL009, PL429 |
| POST `/api/p/question` | 청중(쿠키) | `{body: string 1..300, show_nickname: boolean}` | `{question_id, status}` | 0 | `poll.ask_question` | PL002, PL007, PL009, PL010, PL429 |
| POST `/api/p/upvote` | 청중(쿠키) | `{question_id: uuid}` | `{already}` | 0 | `poll.upvote_question` | PL002, PL006, PL009, PL429 |
| GET `/api/overlay/snapshot?event=<id>&k=<key>` | 오버레이 키 | - | `{seq, state, topic}` | 0 | `poll.overlay_snapshot` | PL009 |
| POST `/api/overlay/realtime-token` | 오버레이 키 | `{event_id, k}` | `{token, topic}` (`poll_aud:'overlay'`) | 0 | `poll.overlay_snapshot` | PL009 |
| POST `/api/host/events/[id]/overlay-key` | owner/admin/member | - | `{url}` (키 포함 URL, 1회 표시) | 0 | `poll.rotate_overlay_key`(사용자 세션) | 42501 |
| GET `/api/host/events/[id]/export.csv` | owner/admin/member/viewer, `export_csv` | `?type=polls\|qna` | text/csv UTF-8 BOM | 0 | RLS SELECT(`poll_results`, `polls`, `poll_options`, `qna_questions`) + service INSERT `core.audit_log`(`event.export`) | 403(플랜), 404 |
| POST `/api/billing/checkout` (Phase 2) | owner/admin | `{plan_code}` | `{order_id, amount_krw, customer_key}` | 0 | 서버 `payment_orders` INSERT | 409 |
| POST `/api/billing/confirm` (Phase 2) | owner/admin | `{paymentKey, orderId, amount}` | `{plan_code}` | 0 | Toss confirm → `core.confirm_payment_order` | PM001, PM404, PM409, PM410 |

진행자가 브라우저에서 직접 부르는 경로(supabase-js, 세션):

| 동작 | 호출 |
|---|---|
| 행사 만들기 | `rpc('create_event', {p_org_id, p_title, p_description, p_settings})` |
| 제목/설명/설정/입장 잠금 수정 | `schema('poll').from('events').update({title, description, settings, join_locked})` |
| 문항/선택지 편집(draft) | `from('polls').insert/update/delete`, `from('poll_options').insert/update/delete` |
| 시작/종료/보관 | `rpc('transition_event', {p_event_id, p_to})` |
| 문항 열기/닫기 | `rpc('transition_poll', {p_poll_id, p_to})` |
| 현재 문항 | `rpc('set_current_poll', {p_event_id, p_poll_id})` |
| 실시간 집계 | `rpc('host_poll_results', {p_poll_id})` (진행자 토픽 수신 시) |
| 모더레이션/차단 | `rpc('moderate_question')`, `rpc('block_participant')` |
| 비밀번호 | `rpc('set_event_passcode', {p_event_id, p_passcode})` |
| 삭제 | `rpc('delete_event', {p_event_id})` |
| 금칙어 | `from('banned_words').insert({org_id, word})/delete` |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158`, `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:5-20`를 따른다. 진행자 경로는 모두 `requireSession('poll')` + 역할 owner/admin/member(조회는 viewer 허용).

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner/admin | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, 감사 `ai.consent` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/ai/conversations` | owner/admin/member, `features.ai_chat` | `{ event_id?: uuid, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)). `event_id`는 같은 조직 행사만 | 404 행사, 403 엔타이틀먼트·플랜 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000), event_id? }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 3, 정산 1~5 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `event_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 `consume_credits`/`refund_credits` + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close`, `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | 삭제는 Dify 대화 삭제 API(구현 시 확인) | 닫기: `status='closed'`. 삭제: 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `POST /api/ai/materials` | owner/admin/member, `features.event_wiki`와 무관, 한도 `materials_max_docs`·`materials_max_mb` | multipart `{ event_id, file(md\|txt\|pdf, 10MB 이하), contains_pii?: boolean, request_id }` | `{ document_id, status:'pending' }` | 문서당 1~10 선차감 | FastAPI `/rag/ingest`(scope `rag`, 컬렉션 `event-<event_id>`) | Storage `org-files/<org_id>/poll/materials/<event_id>/<uuid>.<ext>`, `ai_collections`·`ai_documents`(FastAPI), `core.jobs`(`poll.ai.rag_ingest`), `consume_credits(run:<id>)`, 감사 `materials.upload` | 400 형식, 409 중복(content_hash), 402, 413, 422 `AI_MATERIALS_LIMIT` |
| `GET /api/ai/materials?event=<id>`, `DELETE /api/ai/materials/[document_id]` | 조직 멤버(삭제는 member 이상) | - | 문서 목록 `{id,title,status,chunks,byte_size,updated_at}` / 204 | 0 | 삭제는 FastAPI 문서 삭제(scope `rag`) | 목록은 RLS로 `core.ai_documents` 직접 읽기도 가능. 삭제는 문서·청크·Storage 파일 | 404 |
| `POST /api/ai/qna-archive` | owner/admin/member | `{ event_id, request_id }`(행사 `ended`만) | `{ document_id }` | 문서당 1~10 | FastAPI `/rag/ingest`(scope `rag`, 컬렉션 `qna-archive`, 본문은 서버가 마스킹해 `source_type='text'`로 전달) | `core.jobs`(`poll.ai.qna_archive`), `ai_documents.contains_pii=true` | 409 행사 종료 전·질문 0건, 402 |
| `POST /api/ai/wiki/ingest`, `POST /api/ai/wiki/lint` | owner/admin/member, `features.event_wiki` | `{ document_ids?: uuid[], event_id? }` | `{ run_id }` | 문서당 3 / 조직 2 선차감 | FastAPI `/wiki/ingest`, `/wiki/lint`(scope `wiki`) | `core.jobs`(`poll.ai.wiki_ingest`, `poll.ai.wiki_lint`) | 402, 403 |
| `GET /api/ai/wiki/pages/[...slug]`, `PATCH /api/ai/wiki/pages/[...slug]` | 조회: 조직 멤버, 수정: owner/admin/member | `{ expected_version, body_md?, status?: 'published'\|'archived', reason(5자 이상) }` | 페이지 | 0 | FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 사람 소유 표시, scope `wiki`, 06장 R-6) | 감사 `wiki.publish`/`wiki.edit` | 403, 409 출처 없는 페이지 게시, 409 `WIKI_VERSION_CONFLICT` |
| `POST /api/ai/qna-assist` | owner/admin/member, `features.qna_assist` | `{ event_id, mode: 'all'\|'moderate'\|'cluster'\|'summary', request_id }` | SSE `progress{node}`, `result{run_id}`, `done` / `error` | 질문 수 구간 선차감 5/12/24 | FastAPI `POST /graphs/poll.qna_assist/runs`(scope `graph:poll.qna_assist`, `jti` 1회) | `consume_credits(run:<id>)`, `rate_limit_hit('poll:qna-assist:<org>', 10, 3600)`, 행사당 실행 수는 `ai_runs`(graph, `input->>'event_id'`) 개수로 확인, 환불 | 402, 404 행사, 400 질문 0건, 429 `AI_QNA_ASSIST_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `GET /api/ai/qna-assist/[run_id]` | 조직 멤버 | - | `{ status, output? }`(재접속 때 1회 조회) | 0 | - | `core.ai_runs`(RLS 조직 멤버) | 404 |
| `POST /api/voice/consent` | owner/admin/member | `{ notice_version }` | 204 | 0 | - | 감사 `voice.notice_ack`(고지문 버전) | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | 진행자, `features.voice_chat` | `{ conversation_id }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT(`user_id`) | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, request_id }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산 | `resolve_ai_route(org,'poll','voice_chat','stt')` → 오픈소스 `/stt` 또는 ElevenLabs SDK(scope `voice`) | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(텍스트는 DB의 assistant 메시지에서만 읽는다) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`tts` 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/voice/qna-summary` | owner/admin/member | `{ run_id, request_id }`(요약 텍스트는 `ai_runs.output.summary`에서만 읽는다. 임의 텍스트 불가) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `qna_read_aloud`/`tts` 체인(대체 허용) | `voice_jobs`(feature `qna_read_aloud`), `consume_credits(voice:<request_id>)` | 404, 400(텍스트 필드 전송), 402, 503(환불됨) |
| `POST /api/host/events/[id]/audience-voice` | owner/admin/member, `features.voice_question` | `{ enabled: boolean }` | `{ enabled }` | 0 | - | 켤 때 지갑 잔액 1 이상 확인 후 service_role로 `events.settings.audience_voice` 갱신, 감사 `event.audience_voice`. 직접 `events.settings` 업데이트로 켜도 청중 경로가 같은 검사를 다시 한다 | 402, 403 |
| `POST /api/p/voice-question` | 청중(쿠키), 행사 `settings.audience_voice`=true | multipart `{ audio(webm/ogg/mp4, 500KB 이하, 20초 이하), request_id }` | `{ text, duration_seconds }`(저장하지 않음) | 4건 묶음마다 1 선차감(진행자 지갑) | 서명 토큰(`sub=visitor:pt:<participant_id>`, scope `voice`, feat `voice_question`) → 오픈소스 `/stt`. 상용 대체 없음 | `participant_snapshot`(참가자·차단·live 확인), `rate_limit_hit` 5종(02장 5-4절), `consume_credits(voice-block:<event_id>:<n>)`, `voice_sessions`(visitor_key `pt:<participant_id>`), `voice_jobs`(`store_audio=false`, `user_id` null) | 401 PL009, 409 PL002, 429 `RATE_LIMITED`/`AI_VOICE_LIMIT`, 413 `VOICE_TOO_LONG`, 402은 `AI_VOICE_LIMIT`로 변환(청중에게 지갑 상태를 노출하지 않음), 503 |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), 종료된 행사의 쓰지 않은 음성 묶음 `refund_credits`, `consume_credits`/`refund_credits` | 401 |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:82-88`), `core.ai_documents`, `core.ai_runs`, `core.wiki_pages`(조직 멤버, 같은 파일 `:625-632`).

## 3. RPC (SECURITY DEFINER)

모든 함수는 `set search_path = ''`이며 객체를 스키마 한정으로 쓴다. 진행자 RPC는 `core.is_service_caller()` + `core.has_org_role(...)`(NULL 안전)로 판정하고, service 전용 RPC는 EXECUTE를 service_role에만 주고 안에서 `core.is_privileged_session()`으로 2차 확인한다(`SECURITY_BASELINE.md` 1장 표).

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `create_event(p_org_id uuid, p_title text, p_description text, p_settings jsonb)` | authenticated | owner/admin/member, 엔타이틀먼트, 조직당 30/시간, `max_events` | `poll.events` | 42501, PL429, PL012, PL014 |
| `transition_event(p_event_id uuid, p_to text)` | authenticated | 멤버(viewer 제외), 엔타이틀먼트, 허용 전이, 재개 24시간, `max_live_events` | `poll.events` | P0002, 42501, PL011, PL012 |
| `set_current_poll(p_event_id uuid, p_poll_id uuid)` | authenticated | 멤버, 행사 draft/live, 같은 행사 문항 | `poll.events` | P0002, 42501, PL011, 22023 |
| `transition_poll(p_poll_id uuid, p_to text)` | authenticated | 멤버, 엔타이틀먼트, 허용 전이, 행사 live, 선택지 2~10, `polls_per_event` | `poll.polls` | P0002, 42501, PL002, PL007, PL011, PL012 |
| `moderate_question(p_question_id uuid, p_to text)` | authenticated | 멤버, 대상 상태 | `poll.qna_questions` | P0002, 42501, 22023 |
| `block_participant(p_participant_id uuid, p_blocked boolean)` | authenticated | 멤버 | void | P0002, 42501 |
| `rotate_overlay_key(p_event_id uuid)` | authenticated | 멤버 | text(원문 키, 1회) | P0002, 42501 |
| `set_event_passcode(p_event_id uuid, p_passcode text)` | authenticated | owner/admin, 4~12자 | void | P0002, 42501, 22023 |
| `delete_event(p_event_id uuid)` | authenticated | owner/admin | void | P0002, 42501 |
| `host_poll_results(p_poll_id uuid)` | authenticated | 멤버 + 엔타이틀먼트 | jsonb `{total, counts}` | P0002, 42501 |
| `join_event(p_code text, p_token text, p_nickname text, p_ip_hash text, p_passcode text)` | service_role | 실패 IP 버킷, 코드, live, 재입장, 비밀번호, 잠금, 정원, 닉네임 | jsonb | 42501, 22023(토큰 형식, 다른 행사 토큰). 업무 오류는 jsonb code |
| `cast_vote(p_token text, p_poll_id uuid, p_option_ids uuid[], p_rating int)` | service_role | 참가자, 차단, 20/분, 같은 행사 문항, live, open, 형식 | jsonb `{ok, vote_id}` | 42501 |
| `ask_question(p_token text, p_body text, p_show_nickname boolean)` | service_role | 참가자, live, Q&A 켜짐, 3/분, 행사당 20, 금칙어 | jsonb `{ok, question_id, status}` | 42501 |
| `upvote_question(p_token text, p_question_id uuid)` | service_role | 참가자, 60/분, 같은 행사 공개 질문, live | jsonb `{ok, already}` | 42501 |
| `participant_snapshot(p_token text)` | service_role | 참가자, 30/분, 행사 archived/삭제 아님 | jsonb `{ok, seq, state, me?, topic?}` | 42501 |
| `overlay_snapshot(p_event_id uuid, p_overlay_key text)` | service_role | 키 해시 일치, live/ended | jsonb `{ok, seq, state, topic}` | 42501 |
| `collect_broadcasts(p_limit int, p_heartbeat_seconds int)` | service_role(워커) | - | table `(event_id, topic, payload)` | 42501 |
| `purge_expired_events()` | service_role(스케줄) | - | jsonb 건수 | 42501 |

코어 RPC는 `CORE_SPEC.md` 1.3 표를 따른다(`session_context`, `bootstrap_app_for_org`, `write_audit`, `rate_limit_hit`, Phase 2 `confirm_payment_order`). AI·음성 경로는 코어 `consume_credits`, `refund_credits`, `resolve_ai_route`, `set_ai_cross_border_ack`, `match_ai_chunks`와 기존 제품 RPC(`moderate_question`, `participant_snapshot`)만 쓰고 새 제품 RPC는 만들지 않는다.

## 4. 잡 페이로드 계약

`core.jobs`를 쓰지 않는다. 대신 Realtime Broadcast 메시지 계약을 정한다.

토픽 `poll:<org_id>:<event_id>`, event 이름은 payload의 `type`과 같다.

```json
{ "type": "state", "seq": 42,
  "state": {
    "event": { "id": "uuid", "title": "강연 A", "status": "live", "join_locked": false,
               "participant_count": 87, "qna_enabled": true, "state_version": 9 },
    "poll": { "id": "uuid", "kind": "single_choice", "title": "만족도", "status": "open",
              "max_choices": 1, "rating_scale": 5, "results_visibility": "live",
              "options": [ { "id": "uuid", "label": "매우 만족" } ],
              "results": { "total": 78, "counts": { "<option_id>": 41 } } },
    "qna": [ { "id": "uuid", "body": "자료 공유되나요?", "nickname": "청중1", "status": "visible", "upvotes": 12, "created_at": "..." } ] } }
```

```json
{ "type": "hb", "seq": 43, "event_id": "uuid" }
```

| 필드 규칙 | 내용 |
|---|---|
| `poll` | 현재 문항이 없거나 draft면 null |
| `poll.results` | `results_visibility`가 host_only이거나 after_close인데 열려 있으면 null |
| `qna` | Q&A가 꺼져 있으면 null. 공개 질문 상위 30개(추천 수, 작성 순) |
| ended | `{event:{id,title,status,state_version}, poll: null 또는 공유 설정 시 마지막 문항, qna: null}` |
| 진행자 토픽 `poll:<org>:<event>:host` | `{type:'host', pending_count, last_question_at}` (Phase 1 구현 시 워커가 같은 틱에 보냄. 조각의 `collect_broadcasts`는 공개 토픽만 반환하므로 LP-06-010에서 워커가 `qna_questions` pending 수를 service로 조회해 추가) |

AI 작업(2026-10-13)의 페이로드. `core.jobs.payload`는 `{ "app":"poll", "org_id", "event_id", "ai_run_id", ... }`이고 비밀·청중 원문을 담지 않는다.

| `job_type` | payload | result | progress |
|---|---|---|---|
| `poll.ai.rag_ingest` | `{ document_id, collection: "event-<event_id>", contains_pii }` | `{ chunks, tokens }` | `{ stage: "split"\|"embed"\|"store", pct }` |
| `poll.ai.qna_archive` | `{ event_id, document_id }` | `{ chunks, masked_count }` | 위와 같음 |
| `poll.ai.wiki_ingest` | `{ document_ids[], event_id? }` | `{ pages_created, pages_updated, pages_proposed }` | `{ stage, pct }` |
| `poll.ai.wiki_lint` | `{ org_id }` | `{ findings: { contradiction, stale, orphan, broken_link, no_source } }` | - |
| `poll.ai.purge_event` | `{ }` | `{ collections, documents, runs, pages, files }` | - |

그래프 `poll.qna_assist` 입력과 출력(`POST /graphs/poll.qna_assist/runs`, 결과는 `core.ai_runs.output`):

```json
{ "input":  { "event_id": "uuid", "mode": "all", "limit": 600 },
  "output": { "summary": "접수 질문 86건 중 31건이 일정 변경에 관한 것입니다 ...",
              "clusters": [ { "label": "일정 변경", "question_ids": ["uuid"], "count": 31, "representative_id": "uuid" } ],
              "flags": [ { "question_id": "uuid", "label": "abuse", "reason": "비하 표현" } ],
              "stats": { "total": 86, "answered": 12, "pending": 20 } } }
```

SSE `/api/ai/qna-assist` 이벤트: `event: progress` `data: {"node":"moderate"}` ... `event: result` `data: {"run_id":"uuid"}` → `event: done`. 오류는 `event: error` `data: {"code":"AI_UNAVAILABLE","refunded":true}`.

클라이언트 적용 규칙: `seq <= lastSeq`면 버림. `seq > lastSeq + 1`이면 이 메시지를 적용한 뒤 스냅샷 1회(1초 디바운스). `type='hb'`는 lastSeq와 마지막 수신 시각만 갱신.

## 5. 웹훅

| 방향 | 내용 |
|---|---|
| 수신 | Phase 2 Toss 결제 웹훅만. `SHARED_MODULES.md` 6장 `receiveWebhook` 그대로(서명 필수, `(provider,event_id)` 멱등, 지급은 confirm 경로) |
| 발신 | 없음(MVP). Phase 3 후보: `event.ended` 결과 요약을 사용자 웹훅 URL로(automation-core 서명 규약) |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| Supabase Realtime Broadcast HTTP API(`/realtime/v1/api/broadcast`, private, 여러 메시지 배치) | 브로드캐스터 워커 | 3회 재시도(100/300/900ms), 실패 시 다음 틱이 최신 상태를 다시 보낸다(상태 전체 전송이라 유실 복구) | 미확인: 플랜별 초당 메시지/동시 접속 한도. LP-06-027에서 측정 |
| Toss Payments(Phase 2) | `api/billing/*` | `SHARED_MODULES.md` 5장 | - |
| QR 생성 | 클라이언트 라이브러리(오프라인 생성) | - | 외부 호출 없음 |
| FastAPI AI 서비스(그래프, RAG, 위키, 도구) | `src/app/api/ai/*`, `src/app/api/voice/*` | 체인 대체(라우터) → 노드 재시도(그래프) → 실패 시 `ai_runs.status='failed'` → 선차감 환불. 120초 안에 끝나지 않으면 실패 처리 | 질문 600건 상한, 호출당 LLM 5~15회 |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*` | 체인 다음(오픈소스)으로 대체(`voice_jobs.fallback_from`). 청중 음성 질문에는 쓰지 않는다 | 요금·상업 이용 조건 구현 시 확인 |
| 오픈소스 음성 서버 | `src/app/api/voice/*`, `src/app/api/p/voice-question`(서명 토큰 scope `voice`) | 실패 시 대체 없이 429/503 + 환불(청중 음성). 진행자 음성은 체인 다음 제공자 | 요청당 STT 10분·TTS 5,000자 상한(`docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:61`). poll은 진행자 60초, 청중 20초 |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158` 중 poll이 쓰는 것과 제품 그래프다.

| 엔드포인트 | 호출자 | 인증 | poll 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`, `wiki.query`)로 받아 라우팅(제안, 06장 R-6). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `assist`: 매핑 org의 `event-<id>` 컬렉션·`qna-archive`·행사 위키 검색 → `chat` 모델. 검색 근거에 `contains_pii` 청크가 있으면 오픈소스 강제. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다. 모드 `howto`: 제품 공통 지식(사용 방법) |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /dify/retrieval` | Dify 외부 지식 | 내부 키 | 운영자 조직의 사용 방법 FAQ 컬렉션만. 사용자 조직 데이터 금지 |
| `POST /graphs/poll.qna_assist/runs`, `GET /graphs/runs/{id}` | Next.js | 서명 토큰 scope `graph:poll.qna_assist`, `jti` 1회 | Q&A 정리(4절 계약) |
| `POST /rag/ingest` | Next.js | 서명 토큰 scope `rag` | 자료·아카이브 색인 |
| `POST /wiki/ingest`, `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장(R-6) | Next.js | 서명 토큰 scope `wiki` | 행사 위키 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다).

### 6.2 Dify Chatflow 계약 (`poll-assistant`)

| 항목 | 값 |
|---|---|
| 앱 | `poll-assistant`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_POLL`(Next.js 서버 전용). 정의는 `infra/dify/poll-assistant.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `event_id`(선택, UUID 문자열, 대화 시작 때만). 서명 토큰, org, 청중 정보는 넣지 않는다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → 분기 `assist`: HTTP 요청 노드 → 답변 / 분기 `howto`: 지식 검색 노드(외부 지식 → `/dify/retrieval`) → LLM 노드(model `wiki.query`) → 답변 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, event_id, mode: "assist" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title }], no_source: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | `assist` 분기는 FastAPI가 `ai_messages.citations`를 기록하고, `howto` 분기는 Next.js가 Dify 응답의 검색 출처 메타데이터로 기록한다 |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| PL001 | 코드에 맞는 행사 없음 | 404 |
| PL002 | 행사가 진행 중이 아님(준비/종료/보관) | 409 |
| PL003 | 입장 잠금 | 423 |
| PL004 | 참가 정원 초과 | 409 |
| PL005 | 이미 투표함 | 409 |
| PL006 | 문항이 열려 있지 않거나 이 행사의 것이 아님 | 409 |
| PL007 | 입력 형식(선택 수, 평점 범위, 길이, 선택지 수) | 422 |
| PL008 | 금칙어 닉네임 | 422 |
| PL009 | 참가자 토큰/오버레이 키 무효 또는 차단 | 401 |
| PL010 | Q&A 꺼짐 | 409 |
| PL011 | 허용되지 않은 상태 전이 | 409 |
| PL012 | 플랜 한도 | 402 |
| PL013 | 입장 비밀번호 틀림 | 401 |
| PL014 | 코드 발급 실패(빈 코드 없음) | 503 |
| PL429 | 레이트 리밋 | 429 |
| 42501, 22023, P0002 | 코어 규약(`CORE_SPEC.md` 15장) | 403, 409, 404 |
| `CR001` | 크레딧 부족(AI·음성 선차감 실패) | 402 + `{ balance, required }`. 청중 경로는 `AI_VOICE_LIMIT`로 변환 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생) | 403 |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 + "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한 | 429 |
| 앱 코드 `AI_MATERIALS_LIMIT` | 행사 자료 문서 수·용량 한도 | 422 |
| 앱 코드 `AI_QNA_ASSIST_LIMIT` | 행사당 Q&A 정리 실행 한도(`qna_assist_runs_per_event`) | 429 |
| 앱 코드 `AI_VOICE_LIMIT` | 청중 음성 질문 한도 소진·지갑 잔액 부족·행사 `audience_voice` 꺼짐 | 429 |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 진행자 음성 처리 고지 미확인 | 403 |
| 앱 코드 `VOICE_TOO_LONG` | 진행자 60초·5MB, 청중 20초·500KB 초과 | 413 |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 `expected_version` 불일치 | 409 |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전 불일치 | 409 |
| 앱 코드 `RATE_LIMITED` | 레이트 리밋(PL429와 같은 의미, AI 경로) | 429 + `Retry-After` |

## 8. 인증 단계 라우트 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절. 아래 라우트는 진행자 로그인에만 쓰인다. 청중 경로(`/api/p/*`, 참가자 토큰 쿠키)와 오버레이 경로(`/api/overlay/*`, 오버레이 키)는 인증 단계와 무관하며 이 절의 라우트를 거치지 않는다.

| 메서드 경로 | 단계 | 입력 | 출력 | 처리 | 오류 |
|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | `{ persona: string, next?: string }`(persona는 05장 10절 키 목록 화이트리스트) | 303 → `finishLogin` 결과 경로 | `isMockAuthAllowed()` 확인 → 쿠키 세션용 서버 클라이언트로 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('poll', next)`. 레이트 리밋 대상 아님(로컬 전용) | 판정이 거짓이면 404(존재 자체를 숨김). 알 수 없는 persona 400. 시드 안 된 계정 401 + "`db:seed-users`를 먼저 실행하세요" |
| `GET /auth/callback?code&next` | B부터(C 재사용) | `code`(PKCE), `next` | 302 | `finishLogin('poll', next)`: (1) `exchangeCodeForSession` (2) `session_context('poll')` 1회 (3) `entitled=false`이면 poll은 open 앱이므로 `rpc('bootstrap_app_for_org', { p_app_id: 'poll' })` 1회 후 재조회(크레딧 멱등) (4) `status` 분기: suspended → 403(pending은 approval 앱 전용이라 poll에는 없다) (5) 첫 로그인이고 베타 약관 동의 기록이 없으면 `/onboarding`(기록 방식은 LP-06-049에서 정한다. 제안: `core.write_audit` `terms.accept`에 약관 버전), 아니면 `next` 화이트리스트(`/`로 시작, `//`·`@`·`\` 없음, origin `NEXT_PUBLIC_APP_URL` 고정) 또는 기본 `/events` (6) 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 없음) | `code` 없음·재사용·만료 → `/login?error=callback`. 프로필 없음 → 로그아웃 후 `/login`. `next=//evil.com` → `/events` |
| `GET /auth/naver/start?next=` | C2 브리지 경로만 | `next` | 302 → 네이버 authorize | 32바이트 state를 HttpOnly·Secure·SameSite=Lax 서명 쿠키(HMAC `AUTH_BRIDGE_SECRET`, 10분)에 저장. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 429 |
| `GET /auth/naver/callback?code&state` | C2 브리지 경로만 | `code`, `state` | 302 | 쿠키 state 상수 시간 비교·삭제 → 서버 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links`(코어 `staged/0010_core_auth_identity_links.sql`)로 사용자 찾기·생성 → `generateLink`+`verifyOtp`로 세션 → `finishLogin('poll', next)`. 네이버 토큰 저장 안 함 | `/login?error=state`(불일치·없음·만료), `/login?error=email_in_use`(같은 이메일 기존 사용자, 자동 연결 안 함), `/login?error=callback` |

`supabase_custom` 경로를 채택하면(01장 D20) 네이버도 `/auth/callback`을 그대로 쓰고 브리지 라우트 2개는 만들지 않는다.

| 오류 코드 | 의미 | HTTP / 이동 |
|---|---|---|
| `error=callback` | OAuth 코드 교환 실패(없음·재사용·만료) | `/login?error=callback` |
| `error=state` | 브리지 state 불일치·없음·만료 | `/login?error=state` |
| `error=email_in_use` | 브리지: 같은 이메일의 다른 방법 가입자 존재 | `/login?error=email_in_use` |
