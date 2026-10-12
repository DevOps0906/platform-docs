# 04 API: Live Poll

조각 = `docs/products/_supabase-modular/migrations/1800_poll.sql`. 모놀리스는 같은 함수가 `public.`에 있다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 진행자 인증 | `requireSession('poll')`(`SHARED_MODULES.md` 2장). 진행자 쓰기는 대부분 브라우저에서 RLS(문항/선택지 draft 편집, 행사 제목/설정)와 authenticated RPC로 직접 한다. Route Handler는 CSV, 오버레이 키처럼 서버 처리가 필요한 것만 |
| 청중 인증 | Supabase 세션 없음. Route Handler가 쿠키 `lp_pt_<eventId>`(httpOnly, Secure, SameSite=Lax, 7일)의 참가자 토큰(32바이트 base64url)을 읽어 service_role RPC에 넘긴다. 토큰이 없으면 `/api/p/join`만 허용 |
| IP | `x-forwarded-for` 첫 값(Vercel이 설정)을 `HMAC-SHA256(POLL_IP_HMAC_SECRET, yyyy-mm-dd + ip)` hex로 바꿔 `p_ip_hash`로만 넘긴다. 원문 IP는 로그에도 남기지 않는다 |
| 멱등 | 투표는 서버 unique가 멱등을 보장한다(재시도 안전, 두 번째는 PL005). 행사 생성은 클라이언트 `request_id`를 받아 Route Handler 없이 RPC를 쓰므로 버튼 중복 클릭은 UI에서 막는다(제안: 필요하면 `idempotency_key` 컬럼 추가) |
| 크레딧 | 없음 |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }`. 청중 RPC의 jsonb `{ok,code}`를 그대로 매핑 |
| 레이트 리밋 | RPC 안에서 `core.rate_limit_hit`(01장 5절). Route Handler는 본문 크기 4KB 상한 |
| 캐시 | 청중/오버레이 API는 `Cache-Control: no-store`, `X-Robots-Tag: noindex` |
| 폴링 금지 | 스냅샷 API는 입장 직후, 재구독 직후, seq 공백, 15초 무수신에만 호출한다. 주기 호출 금지(원본 CLAUDE:8) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/p/join` | 청중 | `{code: /^\d{6}$/, nickname?: string<=30, passcode?: string 4..12}` | `{participant_id, event_id, topic, rejoined}` + Set-Cookie | 0 | `poll.join_event` | PL001, PL002, PL003, PL004, PL007, PL008, PL009, PL013, PL429 |
| GET `/api/p/snapshot?event=<id>` | 청중(쿠키) | - | `{seq, state, me, topic}` | 0 | `poll.participant_snapshot` | PL002, PL009, PL429 |
| POST `/api/p/realtime-token` | 청중(쿠키) | `{event_id}` | `{token, expires_at, topic}` (JWT: role anon, `poll_topic`, `poll_aud:'participant'`, exp 6h) | 0 | `participant_snapshot`로 토큰 유효성과 live 여부 확인 후 서명 | PL002, PL009 |
| POST `/api/p/vote` | 청중(쿠키) | `{poll_id: uuid, option_ids?: uuid[]<=10, rating?: int 1..10}` | `{vote_id}` | 0 | `poll.cast_vote` | PL002, PL005, PL006, PL007, PL009, PL429 |
| POST `/api/p/question` | 청중(쿠키) | `{body: string 1..300, show_nickname: boolean}` | `{question_id, status}` | 0 | `poll.ask_question` | PL002, PL007, PL009, PL010, PL429 |
| POST `/api/p/upvote` | 청중(쿠키) | `{question_id: uuid}` | `{already}` | 0 | `poll.upvote_question` | PL002, PL006, PL009, PL429 |
| GET `/api/overlay/snapshot?event=<id>&k=<key>` | 오버레이 키 | - | `{seq, state, topic}` | 0 | `poll.overlay_snapshot` | PL009 |
| POST `/api/overlay/realtime-token` | 오버레이 키 | `{event_id, k}` | `{token, topic}` (`poll_aud:'overlay'`) | 0 | `poll.overlay_snapshot` | PL009 |
| POST `/api/host/events/[id]/overlay-key` | owner/admin/member | - | `{url}` (키 포함 URL, 1회 표시) | 0 | `poll.rotate_overlay_key`(사용자 세션) | 42501 |
| GET `/api/host/events/[id]/export.csv` | owner/admin/member/viewer, `export_csv` | `?type=polls|qna` | text/csv UTF-8 BOM | 0 | RLS SELECT(`poll_results`, `polls`, `poll_options`, `qna_questions`) + service INSERT `core.audit_log`(`event.export`) | 403(플랜), 404 |
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

코어 RPC는 `CORE_SPEC.md` 1.3 표를 따른다(`session_context`, `bootstrap_app_for_org`, `write_audit`, `rate_limit_hit`, Phase 2 `confirm_payment_order`).

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
