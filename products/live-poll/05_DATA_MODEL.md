# 05 데이터 모델: Live Poll

정본 SQL: `docs/products/_supabase-modular/migrations/1800_poll.sql`(아래 "조각:줄"). 모놀리스 사본: `supabase/monolith/migrations/0002_poll_domain.sql`.

## 1. 개요와 ERD

```
core.organizations (참조만)
  └─ poll.events (org_id, code 6자리, status)
       ├─ poll.polls (event_id, kind, status)            events.current_poll_id → polls
       │    ├─ poll.poll_options (poll_id)
       │    ├─ poll.votes (poll_id, participant_id, option_ids[] | rating)   unique(poll_id, participant_id)
       │    └─ poll.poll_results (poll_id PK, 확정 집계)
       ├─ poll.participants (event_id, token_hash unique)   Supabase 사용자 아님
       │    ├─ poll.votes
       │    ├─ poll.qna_questions (participant_id, status)
       │    └─ poll.qna_upvotes (question_id, participant_id) unique
       └─ (Realtime 토픽 poll:<org_id>:<event_id>)
  └─ poll.banned_words (org_id null = 플랫폼 기본)
core.app_entitlements / core.plans (플랜 features 읽기만), core.rate_limit_buckets(레이트 리밋), core.audit_log
```

테넌트 일관성은 복합 FK로 DB가 강제한다: `polls(event_id, org_id) → events(id, org_id)`, `votes(poll_id, event_id) → polls(id, event_id)`, `votes(participant_id, event_id) → participants(id, event_id)`. 다른 행사의 문항에 다른 행사 참가자의 표가 들어갈 수 없다.

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 모든 테이블에 `org_id`(FK cascade), `created_at`. UPDATE가 있는 테이블은 `updated_at` + `core.set_updated_at` 트리거. `deleted_at`은 events만.

### 2.1 `poll.events` (조각:66)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id | uuid | N | gen_random_uuid() | |
| org_id | uuid | N | | 조직 |
| code | text | N | | `^[0-9]{6}$`, archived/삭제 전 유일(부분 유니크) |
| title / description | text | N | / '' | 1~120 / 0~500자 |
| status | text | N | 'draft' | draft, live, ended, archived |
| join_locked | boolean | N | false | 신규 입장 막기 |
| passcode_hash | text | Y | | sha256(event_id:passcode) |
| settings | jsonb | N | {} | object, 4KB 이하. `qna_enabled`(true), `qna_moderation`(false), `allow_anonymous`(true), `share_results_after_end`(false) |
| current_poll_id | uuid | Y | | 발표 중 문항(FK set null) |
| max_participants | int | N | 100 | live 전환 시 플랜 값 고정 |
| overlay_key_hash | text | Y | | 오버레이 키 sha256 |
| state_version | bigint | N | 1 | 공개 상태 변경 카운터(트리거) |
| broadcast_state_version, broadcast_vote_seq, broadcast_qna_seq, broadcast_participant_count, broadcast_seq, broadcast_at | | N/Y | 0/null | 워커가 마지막으로 보낸 값 |
| started_at, ended_at, archived_at, retention_until, purged_at | timestamptz | Y | | 상태 시각, 보존 만료, 원본 삭제 시각 |
| created_by | uuid | Y | | FK 없음 |
| created_at, updated_at, deleted_at | timestamptz | | | |

### 2.2 `poll.polls` (조각:112)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id, org_id, event_id | uuid | N | | 복합 FK (event_id, org_id) |
| position | int | N | 0 | 순서 |
| kind | text | N | single_choice | single_choice, multiple_choice, rating |
| title | text | N | | 1~200자 |
| max_choices | smallint | N | 1 | 1~10 |
| rating_scale | smallint | N | 5 | 2~10 |
| results_visibility | text | N | live | live, after_close, host_only |
| status | text | N | draft | draft, open, closed. 행사당 open 1개(부분 유니크) |
| opened_at, closed_at | timestamptz | Y | | |
| created_by, created_at, updated_at | | | | |

### 2.3 `poll.poll_options` (조각:150)

id, org_id, poll_id(복합 FK), position, label(1~120자), created_at, updated_at. 문항당 최대 10개(INSERT 정책), 열 때 2~10개 검사.

### 2.4 `poll.participants` (조각:165)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id, org_id, event_id | uuid | N | | 복합 FK |
| token_hash | text | N | | sha256(참가자 토큰) hex, 전역 유일. 진행자에게 컬럼 GRANT 없음 |
| nickname | text | Y | | 1~30자 |
| is_blocked | boolean | N | false | |
| joined_at, last_seen_at | timestamptz | N | now() | |

### 2.5 `poll.votes` (조각:184)

id bigint identity(변경 감지 단조 번호), org_id, event_id, poll_id, participant_id, option_ids uuid[](0~10), rating smallint, created_at. 제약: unique(poll_id, participant_id), 선택지와 평점 중 정확히 하나. UPDATE 없음(투표 변경 불가).

### 2.6 `poll.poll_results` (조각:204)

poll_id(PK), org_id, event_id, total_votes, counts jsonb(`{"<option_id>": n}` 또는 `{"<rating>": n}`), finalized_at, updated_at. 문항 닫힘마다 upsert. 원본 투표 삭제 뒤에도 남는다.

### 2.7 `poll.qna_questions` (조각:218), `poll.qna_upvotes` (조각:240)

qna_questions: id, org_id, event_id, participant_id(복합 FK), body(1~300), show_nickname, status(pending/visible/answered/hidden/rejected), hidden_reason(banned_word/host/blocked_participant), change_seq(`poll.poll_change_seq`, UPDATE마다 갱신), moderated_by, moderated_at, created_at, updated_at.

qna_upvotes: id identity, org_id, event_id, question_id(복합 FK), participant_id, change_seq, created_at. unique(question_id, participant_id).

### 2.8 `poll.banned_words` (조각:257)

id, org_id(null = 플랫폼 기본), word(1~40), normalized(생성 컬럼 `normalize_text(word)`), created_by, created_at. 유일: (org 또는 0-uuid, normalized).

## 3. 상태 전이

전이는 트리거가 모든 쓰기(service_role 포함)에 강제하고, 부수 효과가 있는 전이는 RPC가 한다(`DB_CONVENTIONS.md` 10장).

| 테이블 | 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|---|
| events | draft | live, archived | 멤버(`transition_event`) | live: started_at, max_participants 고정, `max_live_events` 검사 |
| events | live | ended | 멤버, 정리 함수(24시간 초과) | 열린 문항 닫고 확정 집계, retention_until = now + 플랜 보존일 |
| events | ended | live(24시간 이내, 미삭제), archived | 멤버, 정리 함수(7일 뒤 archived) | archived: 코드 반납 |
| polls | draft | open | 멤버(`transition_poll`) | 다른 열린 문항 닫기+확정, current_poll_id 지정, 내용 고정 |
| polls | open | closed | 멤버 | 확정 집계 upsert |
| polls | closed | open | 멤버 | 재개(기존 표 유지) |
| qna_questions | pending | visible, rejected, hidden | 멤버(`moderate_question`) | moderated_by/at |
| qna_questions | visible | answered, hidden | 멤버, 차단 시 자동 hidden | |
| qna_questions | answered / hidden / rejected | visible | 멤버 | |
| participants.is_blocked | false ↔ true | | 멤버(`block_participant`) | 차단 시 질문 hidden(blocked_participant) |

트리거: `events_before_update`(조각:288, 22023 + org_id/code 불변 + state_version), `polls_before_write`(조각:316, 22023 + 열린 뒤 내용 고정 PL011), `qna_questions_before_update`(조각:349).

## 4. RLS 정책

진행자 판정 식: 읽기 `core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll')`, 쓰기 `core.has_org_role(org_id, array['owner','admin','member'])`(viewer 제외). anon은 `poll` 스키마 USAGE조차 없다(모듈러). 모놀리스는 public USAGE는 있으나 이 제품 테이블/함수 GRANT가 없다.

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| events | 멤버+엔타이틀먼트, `deleted_at is null` | 없음(`create_event`) | 쓰기 역할, archived/삭제 아님, with check 같음 | 없음(`delete_event`) | select, update(title, description, settings, join_locked) |
| polls | 멤버+엔타이틀먼트 | 쓰기 역할 + 같은 조직의 draft/live 행사 | 쓰기 역할 + status='draft'(using, with check) | owner/admin, open 아님 | select, delete, insert(8컬럼), update(6컬럼, status 제외) |
| poll_options | 멤버+엔타이틀먼트 | 쓰기 역할 + 부모 draft + 10개 미만 | 부모 draft | 부모 draft | select, delete, insert(4), update(position, label) |
| participants | 멤버+엔타이틀먼트 | 없음 | 없음 | 없음 | select(token_hash 제외 7컬럼) |
| votes, poll_results, qna_questions, qna_upvotes | 멤버+엔타이틀먼트 | 없음 | 없음 | 없음 | select |
| banned_words | 자기 조직 행만(org_id not null) | owner/admin + 엔타이틀먼트 | 없음 | owner/admin | select, delete, insert(org_id, word) |

이중 잠금: participants, votes, poll_results, qna_questions, qna_upvotes에 `core.guard_privileged_write` 트리거(조각:371-385). GRANT나 정책이 실수로 열려도 사용자 세션 쓰기는 42501이다.

쓰기 정책을 주는 근거(`DB_CONVENTIONS.md` 8.1): events의 쓰기 컬럼은 콘텐츠(제목, 설명, 설정, 잠금)뿐이고 상태/코드/한도/브로드캐스트 컬럼은 GRANT가 없다. polls/poll_options는 draft 동안 순수 콘텐츠이며, 상태는 컬럼 GRANT에서 빠져 RPC로만 바뀐다. banned_words는 조직 콘텐츠다.

Realtime(`realtime.messages`, 조각:1462): 멤버는 `poll:<자기 org>:...` 토픽 수신, anon은 JWT `poll_topic`과 같은 토픽만 수신, 송신 정책 없음.

함수 EXECUTE: 조각 16절이 이 파일의 함수만 골라 public/anon/authenticated에서 회수하고, 모듈러는 core 0007과 같은 규칙으로 `revoke execute on all functions in schema poll from public, anon, authenticated`를 한 번 더 한 뒤(PUBLIC 전역 기본 EXECUTE는 default privileges로 지워지지 않는다), 진행자 RPC 10개와 `normalize_text`만 authenticated에 준다.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `events_code_active_uniq` (code) partial | 입장 시 코드 조회, 코드 유일성 |
| `events_live_idx` (broadcast_at) where live | 워커 틱마다 live 행사 순회 |
| `events_org_created_idx` | 행사 목록 |
| `polls_one_open_per_event_uniq` partial | 열린 문항 1개 강제 |
| `votes_poll_id_idx` (poll_id, id) | `max(id)` 변경 감지(역방향 인덱스 1건), 집계 |
| `votes_one_per_participant_uniq` | 중복 거절, 내 투표 조회 |
| `participants_token_uniq`, `participants_event_idx` | 토큰 조회, 참가자 수 |
| `qna_questions_event_seq_idx`, `qna_upvotes_event_seq_idx` | Q&A 변경 감지 |
| `qna_questions_event_status_idx` | 공개 목록, 모더레이션 큐 |

부하 가정: 투표 300건/초 = INSERT 300 + 레이트 리밋 upsert 300(참가자별 다른 행이라 경합 없음). 워커 틱(250ms)마다 live 행사당 인덱스 조회 4회, 변경 시 집계 1회. 3,000명 행사의 참가자 수 `count(*)`는 인덱스 스캔 3,000행으로 1ms 수준(제안, LP-06-027에서 측정).

## 6. 코어 참조

| core 객체 | 용도 |
|---|---|
| `core.organizations` | 모든 테이블 org_id FK |
| `core.apps` | 조각 머리에서 `('poll','Live Poll','poll','open','beta')` 등록(on conflict do nothing) |
| `core.app_entitlements`, `core.plans` | `plan_feature_int`가 features 읽기(읽기만) |
| `core.is_org_member`, `has_org_role`, `has_entitlement` | RLS와 RPC 판정 |
| `core.is_service_caller`, `core.is_privileged_session` | 진행자 RPC / service 전용 RPC 판정 |
| `core.rate_limit_hit`, `core.rate_limit_buckets` | 레이트 리밋. 버킷은 입장 실패 사전 차단을 위해 읽기만(쓰기 없음) |
| `core.write_audit` | 진행자 RPC 감사 |
| `core.set_updated_at`, `core.guard_privileged_write` | 트리거 |

`core.*` ALTER 없음. 코어 테이블 쓰기 없음(감사와 레이트 리밋은 코어 함수 경유).

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

리뷰 높음 4건 중 #1, #2는 02장 6절, #3, #4는 여기다.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Slido_Project.md` 3장 #3 | `docs/reviews/Slido_Project.md:41`, `:55` | IP 기반 1인 1표는 행사장 Wi-Fi/CGNAT 정상 사용자를 막고, LocalStorage/Cookie는 시크릿 창으로 우회된다. "로그인 불필요"와 "엄격한 1인 1표"는 양립하지 않는다 | (1) 중복 판정 단위는 서버 발급 참가자 토큰(httpOnly 쿠키, DB는 sha256만)이다. `votes` unique(poll_id, participant_id)(조각:195)가 1차 방지이고 IP로는 투표를 막지 않는다. (2) 허용 수준을 "소프트 제한"으로 01장 LP-F-008에 명시: 시크릿 창 재입장은 새 참가자로 허용, 대신 행사 정원(`max_participants`), 입장 잠금, 비밀번호, 참가자당 20표/분, 진행자 참가자 차단으로 남용 상한을 둔다. (3) Supabase 익명 로그인 대신 토큰을 쓰는 이유: 코어 `handle_new_user`가 모든 `auth.users` INSERT마다 프로필과 개인 조직, owner 멤버십을 만든다(`docs/products/_supabase-modular/migrations/0001_core_identity.sql:113-160`). 청중 3,000명이면 조직 3,000개가 생긴다. 코어를 고치지 않고(과제 규칙) 06장 6절에 "is_anonymous 사용자 건너뛰기" 요청으로 남긴다. (4) 스모크: 같은 토큰 2번째 투표 PL005, 다른 행사 토큰으로 투표 PL006 | participants, votes, LP-06-004, LP-06-005, LP-06-026 |
| `docs/reviews/Slido_Project.md` 3장 #4 | `docs/reviews/Slido_Project.md:42`, `:56` | "암호화된 IP 해시" 저장은 개인정보 처리다. 솔트, 보관 기간, 파기, 고지가 없고 솔트 없는 IPv4 해시는 역산된다 | (1) IP 원문과 IP 해시를 제품 테이블에 저장하지 않는다(participants에 IP 컬럼 없음). (2) Route Handler가 `HMAC-SHA256(POLL_IP_HMAC_SECRET, 날짜 + ip)`로 바꿔 레이트 리밋 키 `poll:join_fail:<hmac>`에만 쓴다. 비밀키는 환경변수(DB에 없음)라 DB가 유출돼도 역산할 수 없고, 날짜가 바뀌면 키가 바뀐다. (3) 버킷은 `core.purge_rate_limit_buckets`(1일)가 지운다. (4) 실패한 시도만 센다(입장 성공은 IP로 세지 않아 같은 NAT 정상 사용자 영향 없음). (5) 고지 문구와 보존 기간은 01장 6절 | `core.rate_limit_buckets`, `join_event`(조각:1018), LP-06-012 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `poll` | `public`(코어 라이트와 같은 규칙. 최종 확인은 사용자 결정 D6) |
| 파일 | `_supabase-modular/migrations/1800_poll.sql` | `0001_core_lite.sql` + `0002_poll_domain.sql` + `seed.sql` |
| 머리 | 스키마 생성, USAGE(authenticated, service_role), 기본 권한, `core.apps` 등록 | 생략(`@@modular-only` 블록 제거). apps/plans는 seed |
| 접두사 | `core.`, `poll.` | 모두 `public.` |
| 함수 권한 정리 | 이 파일 함수 이름 목록만(코어 함수 권한 보존) | 같은 목록. public의 코어 함수 권한을 건드리지 않는다 |
| 코어 라이트에서 지운 절 | 해당 없음 | SECTION 4(크레딧), 6-A(OAuth state), 6-B(자격증명), 7(jobs), 8(Storage), 9(affiliate). 남김: 3(Toss, Phase 2), 6-C(레이트 리밋, 필수) |
| `confirm_payment_order` | 원본 | credit_pack 분기는 크레딧 절 삭제 지시대로 `grant_credits` 호출을 지우고 22023으로 거부 |
| 플랜 | 모듈러 seed의 free(`max_participants`만) + 기본값 | seed에 free/pro/business 전체 features |
| 금칙어 기본 목록 | 조각 18절 | 같은 내용(변환본 18절) |
| 결제 실패 기록(코어 수정 반영, 2026-10-13) | `confirm_payment_order` 금액 불일치는 `PM001`(계약 불변, 같은 호출의 UPDATE는 롤백). 주문 failed 기록은 `fail_payment_order`가 맡는다: Phase 2 결제 Route Handler가 PM001을 받으면 별도 호출로 `fail_payment_order(order_id, 'amount_mismatch', {...})`를 부른 뒤 Toss 취소를 호출하고 운영 알림을 보낸다 | 같음 |

## 9. 마이그레이션 파일

| 파일 | 내용 | 검증 |
|---|---|---|
| `docs/products/_supabase-modular/migrations/1800_poll.sql` | 테이블 9, 시퀀스 1, 트리거 함수 3, 내부 함수 13, 진행자 RPC 10, 청중/워커/정리 RPC 8, RLS, Realtime 정책(조건부), 기본 금칙어 | 체커 OK(core 0000~0007 + seed 뒤), RLS 스모크 79/79 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 라이트 사본(6개 절 제거) | 체커 OK |
| `supabase/monolith/migrations/0002_poll_domain.sql` | 조각의 public 변환본. 직접 고치지 않고 변환 스크립트(LP-06-002)로 다시 만든다 | 체커 OK, RLS 스모크 77/77 |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 3개(free만 활성) | 체커 OK |
| 다음 번호 | 1810(인원별 브로드캐스트 간격, Phase 2) | - |
