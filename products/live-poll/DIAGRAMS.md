# DIAGRAMS: Live Poll UML 시각화

작성일 2026-10-23. 이 문서는 `live-poll`의 기획 문서를 그림으로 옮긴 것이다. 정본은 각 문서이며 그림과 문서가 다르면 문서가 우선한다. GitHub에서 Mermaid가 바로 렌더링된다. 전체 플랫폼 구조는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일로 맞췄다.

**제품 한 줄 정의**: 진행자(강연자, 행사 진행자, 방송인)가 행사(방)를 만들면 청중이 로그인 없이 6자리 코드나 QR로 들어와 투표하고 질문하며, 결과가 발표 화면과 OBS 오버레이에 실시간으로 반영되는 웹 서비스. 진행자용 AI 어시스턴트, Q&A AI 정리, 행사 위키, 음성이 MVP에 들어 있다.

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`. 공통은 `../_platform-core/SECURITY_BASELINE.md`, `CORE_SPEC.md`, `AI_ARCHITECTURE.md`.

**표기**: 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·구독, "(제안)" = 문서가 제안이라 한 값. Phase 2·3 항목은 이름에 `P2`, `P3`를 붙였다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-A | 사용자와 기능 (MVP) | 유스케이스(flowchart) | 01_PRD 1장, 2장, 3장 |
| 1-B | 사용자와 기능 (Phase 2, 3) | 유스케이스(flowchart) | 01_PRD 2장 |
| 2-A | 구성요소: 투표와 실시간 | 컴포넌트(flowchart) | 02_ARCHITECTURE 2절, 4절, 5-1절, 7절 |
| 2-B | 구성요소: AI와 음성 | 컴포넌트(flowchart) | 02_ARCHITECTURE 2절(AI), 4절, 5-3~5-5절 |
| 3 | 데이터 모델 | 클래스(classDiagram) | 05_DATA_MODEL 1~4절 |
| 4-A | 시퀀스: 청중 입장과 투표 | 시퀀스 | 03_SCREENS_UX 2.2절, 04_API 2~3절, 02_ARCHITECTURE 5-1절 |
| 4-B | 시퀀스: 문항 진행과 결과 전파 | 시퀀스 | 03_SCREENS_UX 2.3절, 04_API 3절, 02_ARCHITECTURE 4절 |
| 4-C | 시퀀스: Q&A와 AI 정리 | 시퀀스 | 03_SCREENS_UX 2.4절, 2.8절, 01_PRD LP-F-013~015, 029, 030 |
| 4-D | 시퀀스: 청중 음성 질문 | 시퀀스 | 02_ARCHITECTURE 5-4절, 01_PRD LP-F-032 |
| 5-A | 상태: 행사 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-B | 상태: 문항 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-C | 상태: Q&A 질문 | 상태 머신 | 05_DATA_MODEL 3절, 01_PRD LP-F-013, 015 |
| 6 | 화면 흐름 | flowchart | 03_SCREENS_UX 1절, 2절 |
| 7 | 보안 신뢰 경계 | flowchart | 05_DATA_MODEL 7절, 02_ARCHITECTURE 5-1·5-4·6절, 01_PRD 6장 |

> 이 제품의 `SECURITY.md`는 아직 템플릿 상태("작성 필요")라서 7번 그림은 `05_DATA_MODEL` 7장, `02_ARCHITECTURE` 5·6장, `01_PRD` 6장을 근거로 그렸다. 맨 끝 "문서 불일치" 참고.

---

## 1. 사용자와 기능

### 그림 1-A. MVP 기능

**읽는 법**: 사람 역할 3종(진행자, 청중, 방송 시청 화면)과 기능 묶음이다. 기능 ID는 `LP-F-###`. 청중과 OBS 오버레이는 로그인이 없고(참가자 토큰, 오버레이 키) 진행자만 로그인한다.

```mermaid
flowchart LR
  HOST(["진행자<br/>강연자 · 방송인<br/>로그인 필요"])
  AUD(["청중<br/>로그인 없음<br/>참가자 토큰"])
  OBS(["방송 시청 화면<br/>OBS 오버레이 키"])

  subgraph H1["진행자 기능"]
    F1["가입 · 로그인<br/>LP-F-001"]
    F2["행사 생성 코드 QR<br/>LP-F-002"]
    F3["행사 상태 제어<br/>LP-F-003"]
    F4["문항 편집 · 진행<br/>LP-F-004 005"]
    F6["결과 공개 규칙<br/>LP-F-006"]
    F11["발표 화면<br/>LP-F-011"]
    F15["Q&A 모더레이션<br/>LP-F-015"]
    F16["금칙어 · 입장 잠금<br/>LP-F-016 017"]
    F20["결과 보존 · CSV<br/>LP-F-020"]
  end

  subgraph A1["청중 기능"]
    F7["코드 입장 · 닉네임<br/>LP-F-007"]
    F8["1인 1표 소프트 제한<br/>LP-F-008"]
    F9["실시간 결과 · 재연결<br/>LP-F-009 010"]
    F13["Q&A 질문 · 추천<br/>LP-F-013 014"]
    F32["음성 질문<br/>LP-F-032"]
  end

  subgraph AI1["진행자 AI 기능"]
    F25["AI 어시스턴트 채팅<br/>LP-F-025"]
    F26["행사 자료 색인<br/>LP-F-026 027"]
    F28["행사 위키<br/>LP-F-028"]
    F29["Q&A AI 정리<br/>LP-F-029 030"]
    F31["음성 대화 · 읽어 주기<br/>LP-F-031 033"]
    F34["국외 이전 동의 · 라우팅<br/>LP-F-034"]
  end

  F12["OBS 오버레이<br/>LP-F-012"]

  HOST --> F1 --> F2 --> F3
  HOST --> F4
  HOST --> F11
  HOST --> F15
  HOST --> F16
  HOST --> F20
  F4 -.-> F6
  AUD --> F7 --> F8
  AUD --> F9
  AUD --> F13
  AUD --> F32
  OBS --> F12
  HOST --> F25
  HOST --> F26 --> F28
  HOST --> F29
  HOST --> F31
  F1 -.-> F34
  F29 -.->|"사람이 적용"| F15
```

### 그림 1-B. Phase 2, Phase 3

**읽는 법**: 01_PRD 2장에서 MVP 밖으로 둔 항목이다. 점선은 선행 조건이다.

```mermaid
flowchart LR
  HOST(["진행자"])
  AUD(["청중"])

  subgraph P2["Phase 2"]
    P2A["유료 플랜 Pro Business<br/>Toss 결제"]
    P2B["공동 진행자<br/>팀 멤버"]
    P2C["주관식 · 워드클라우드<br/>투표 변경 허용"]
    P2D["청중용 AI 채팅"]
    P2E["크레딧팩 · AI 자동 실행<br/>질문 군집 컬럼"]
    P2F["Turnstile 봇 챌린지"]
    P2G["다국어 EN · 행사 로고"]
    P2H["참가자 개별 삭제 요청"]
  end

  subgraph P3["Phase 3"]
    P3A["퀴즈 모드<br/>정답 · 순위"]
    P3B["Redis 집계"]
  end

  C1["결제 흐름 확정 결정 4"]
  C2["방문자 키 · 예산 설계 D10"]
  C3["봇 공격 관측"]

  HOST --> P2A
  HOST --> P2B
  HOST --> P2C
  HOST --> P2E
  AUD --> P2D
  AUD --> P2F
  HOST --> P2G
  HOST --> P2H
  HOST --> P3A
  P3A -.-> P3B
  P2A -.-> C1
  P2D -.-> C2
  P2F -.-> C3
```

---

## 2. 구성요소

### 그림 2-A. 투표와 실시간

**읽는 법**: 투표는 Route Handler가 service_role RPC로 `votes`에 INSERT만 한다. 별도의 브로드캐스터 워커가 250ms마다 변경을 모아 Supabase Realtime의 private 채널로 보낸다. 청중과 오버레이는 DB 권한 없이 Realtime 수신만 한다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    AUDB["청중 휴대폰<br/>/join /e/code"]
    HOSTB["진행자 콘솔 · 발표 화면"]
    OBSB["OBS 브라우저 소스<br/>/overlay"]
  end

  subgraph WEB["Next.js (Vercel icn1)"]
    PAPI["/api/p/*<br/>입장 투표 질문 추천 스냅샷"]
    OAPI["/api/overlay/*<br/>스냅샷 · 토큰"]
    HAPI["/api/host/*<br/>CSV · 오버레이 키"]
    RTK["realtime-token<br/>단기 JWT 6시간"]
    BILL["/api/billing/* P2"]
  end

  subgraph BC["브로드캐스터 (Railway 2대, 리더 1)"]
    LOOP["collect_broadcasts 루프<br/>250ms 틱, hb 5초"]
    CRON["정리 스케줄<br/>purge_expired_events"]
  end

  subgraph SUP["Supabase (ap-northeast-2)"]
    PG["poll 스키마<br/>events polls votes qna 등 9개"]
    CORE["core<br/>조직 · 엔타이틀먼트 · 레이트 리밋 · 감사"]
    RT["Realtime<br/>private 토픽 poll:org:event"]
    AUTH["Auth<br/>진행자만"]
  end

  TOSS[("Toss P2")]

  AUDB --> PAPI
  OBSB --> OAPI
  PAPI -->|"service_role RPC"| PG
  OAPI --> PG
  PAPI --> RTK
  OAPI --> RTK
  HOSTB -->|"세션 + RLS 직접"| PG
  HOSTB --> HAPI
  HOSTB -.-> AUTH
  LOOP -->|"collect_broadcasts"| PG
  LOOP -->|"Broadcast HTTP API"| RT
  CRON --> PG
  RT -.->|"구독"| AUDB
  RT -.->|"구독"| HOSTB
  RT -.->|"구독"| OBSB
  PG --- CORE
  BILL <--> TOSS
```

### 그림 2-B. AI와 음성

**읽는 법**: AI 경로는 투표·브로드캐스트 경로와 분리돼 있어 AI 서비스가 죽어도 투표는 정상이다. 진행자 브라우저는 `/api/ai/*`, `/api/voice/*`만, 청중은 `/api/p/voice-question`만 AI에 닿는다. Q&A 정리는 잡이 아니라 Route Handler가 그래프를 호출하고 SSE로 진행을 전달한다(로컬 측정 결과에 따라 잡으로 바꿀 수 있음, 02_ARCHITECTURE 4절).

```mermaid
flowchart TB
  HB["진행자 브라우저<br/>어시스턴트 · Q&A 정리 · 음성"]
  AB["청중 브라우저<br/>음성 질문 마이크"]

  subgraph NX["Next.js"]
    AIG["/api/ai/*<br/>세션 · 역할 · 선차감"]
    VG["/api/voice/*<br/>STT · TTS · 요약 낭독"]
    PVQ["/api/p/voice-question<br/>5중 한도 · 오픈소스 STT 전용"]
    SIGN["EdDSA 서명 토큰<br/>iss=poll"]
    SET["/api/internal/ai-settle<br/>워커 키"]
  end

  DIFY["Dify poll-assistant<br/>분류 + HTTP 노드"]

  subgraph FA["FastAPI ai-service (Railway)"]
    QG["그래프 poll.qna_assist<br/>load moderate cluster summarize compliance"]
    TL["도구 /tools/answer<br/>assist howto"]
    ING["rag_ingest · wiki_ingest<br/>잡 poll.ai.*"]
    CMP["compliance poll"]
  end

  BCW["브로드캐스터 워커"]
  CORE[("core<br/>ai_runs ai_messages ai_documents wiki_pages<br/>jobs credit")]
  OSS["오픈소스 LLM · 임베딩 · 음성"]
  COM["상용 LLM · ElevenLabs<br/>국외 이전 동의 조직만"]
  VOTE["투표 경로 cast_vote<br/>AI와 분리"]

  HB --> AIG
  HB --> VG
  AB --> PVQ
  AIG --> SIGN --> QG
  AIG -->|"채팅"| DIFY
  AIG -.->|"Dify 장애 시 직접"| TL
  DIFY -->|"내부 키 + 대화 id"| TL
  QG --> CMP
  TL --> CMP
  VG --> OSS
  VG --> COM
  PVQ --> OSS
  QG --> OSS
  QG -.-> COM
  ING --> CORE
  AIG -->|"consume · refund"| CORE
  BCW -->|"5분마다"| SET
  SET --> CORE
  FA --> CORE
  VOTE -. "호출하지 않음" .- FA
```

---

## 3. 데이터 모델

### 그림 3. `poll` 스키마 9개 테이블

**읽는 법**: 행사(`events`)가 중심이고 문항 계열(`polls` → `poll_options`, `votes`, `poll_results`)과 참가자 계열(`participants` → `qna_questions`, `qna_upvotes`)이 달린다. 하위 테이블은 `(event_id, org_id)` 같은 복합 FK로 다른 행사·조직의 행을 붙일 수 없다. RLS 접근 주체는 note에 적었다. 진행자 판정은 `is_org_member + has_entitlement('poll')`(읽기), `has_org_role(owner, admin, member)`(쓰기)이다.

```mermaid
classDiagram
  class events {
    id
    org_id
    code 6자리
    title
    status draft live ended archived
    join_locked
    passcode_hash
    settings jsonb
    current_poll_id
    max_participants
    overlay_key_hash
    state_version
    broadcast_seq
    retention_until
  }
  class polls {
    id
    event_id
    position
    kind single multiple rating
    title
    max_choices
    results_visibility live after_close host_only
    status draft open closed
  }
  class poll_options {
    id
    poll_id
    position
    label
  }
  class participants {
    id
    event_id
    token_hash sha256
    nickname
    is_blocked
    last_seen_at
  }
  class votes {
    id bigint
    poll_id
    participant_id
    option_ids
    rating
  }
  class poll_results {
    poll_id PK
    total_votes
    counts jsonb
    finalized_at
  }
  class qna_questions {
    id
    participant_id
    body 300자
    show_nickname
    status pending visible answered hidden rejected
    hidden_reason
    change_seq
  }
  class qna_upvotes {
    id
    question_id
    participant_id
    change_seq
  }
  class banned_words {
    id
    org_id null이면 플랫폼 기본
    word
    normalized
  }

  events "1" --> "*" polls : 복합 FK event_id org_id
  polls "1" --> "2..10" poll_options : 선택지
  events "1" --> "*" participants : 입장
  polls "1" --> "*" votes : unique poll_id participant_id
  participants "1" --> "*" votes
  polls "1" --> "0..1" poll_results : 닫힐 때 확정
  participants "1" --> "*" qna_questions
  qna_questions "1" --> "*" qna_upvotes : unique 질문 참가자
  events ..> polls : current_poll_id
  banned_words ..> qna_questions : 금칙어 판정

  note for events "SELECT 진행자 멤버+엔타이틀먼트<br/>UPDATE 컬럼 4개만 직접<br/>생성 상태 삭제는 RPC"
  note for polls "쓰기 진행자 draft만<br/>status는 transition_poll RPC만"
  note for participants "SELECT 진행자 token_hash 제외<br/>쓰기 service_role만<br/>IP 컬럼 없음"
  note for votes "쓰기 service_role cast_vote만<br/>UPDATE 없음 투표 변경 불가"
  note for qna_questions "쓰기 ask_question service_role<br/>상태는 moderate_question RPC"
  note for banned_words "자기 조직 행만 SELECT<br/>owner admin이 편집"
```

---

## 4. 핵심 시퀀스

### 그림 4-A. 청중 입장과 투표 (LP-F-007~010)

**읽는 법**: 청중에게는 로그인 대신 서버 발급 참가자 토큰(httpOnly 쿠키, DB에는 sha256만)이 있다. 중복 투표는 IP가 아니라 `unique(poll_id, participant_id)`로 막는다. IP는 HMAC으로 바꿔 입장 실패 레이트 리밋 키에만 쓴다.

```mermaid
sequenceDiagram
  autonumber
  actor A as 청중
  participant B as 청중 브라우저
  participant N as Next.js /api/p
  participant D as DB poll RPC
  participant R as Realtime

  A->>B: 6자리 코드 입력 또는 QR
  B->>N: POST /api/p/join code, nickname
  N->>N: IP를 HMAC SHA256 날짜+ip 으로 변환
  N->>D: join_event (service_role)
  alt 입장 가능
    D-->>N: participant_id, topic + 토큰 쿠키 발급
    N-->>B: Set-Cookie httpOnly
  else 코드 없음 잠금 정원 초과 비밀번호 오류
    D-->>N: PL001 PL003 PL004 PL013
    N-->>B: 안내 문구 (실패 IP 해시당 10분 30회 초과 시 PL429)
  end
  B->>N: POST /api/p/realtime-token
  N->>D: participant_snapshot 로 유효성 확인
  N-->>B: JWT role anon, 토픽 고정, 만료 6시간
  B->>R: private 채널 구독
  B->>N: GET /api/p/snapshot
  N-->>B: seq 와 현재 상태 1회
  B->>N: POST /api/p/vote poll_id, option_ids
  N->>D: cast_vote (service_role)
  alt 정상
    D-->>N: ok vote_id
    N-->>B: 제출 완료
  else 같은 토큰 2회째
    D-->>N: PL005
    N-->>B: 이미 투표했습니다
  else 닫힌 문항 또는 분당 20표 초과
    D-->>N: PL006 또는 PL429
  end
```

### 그림 4-B. 문항 진행과 결과 전파 (LP-F-005, 009, 011)

**읽는 법**: 진행자 쓰기는 브라우저에서 RLS와 RPC로 직접 한다. 투표 경로는 `events` 행을 건드리지 않고, 워커가 `max(votes.id)`와 `state_version` 등 변경 카운터를 비교해 묶어 보낸다. 워커가 죽어도 투표는 기록되고 클라이언트가 15초 무수신 뒤 스냅샷으로 복구한다.

```mermaid
sequenceDiagram
  autonumber
  actor H as 진행자
  participant HB as 진행자 콘솔
  participant D as DB poll RPC
  participant W as 브로드캐스터 워커
  participant R as Realtime
  participant C as 청중 · 발표 · 오버레이

  H->>HB: 문항 열기
  HB->>D: rpc transition_poll open (사용자 세션)
  Note over D: 멤버와 엔타이틀먼트 확인<br/>선택지 2~10 확인<br/>열린 문항이 있으면 닫고 확정<br/>current_poll_id 지정, state_version 증가
  D-->>HB: poll open
  loop 250ms 틱
    W->>D: collect_broadcasts 200, 5
    D-->>W: 변경된 행사의 topic 과 payload
    W->>R: Broadcast state 또는 hb (seq 단조 증가)
    R-->>C: 새 문항 투표 UI, 묶음 결과
  end
  Note over C: seq 공백 감지 또는 15초 무수신 시<br/>스냅샷 1회 조회로 복구
  H->>HB: 문항 닫기
  HB->>D: rpc transition_poll closed
  D->>D: poll_results 에 확정 집계 upsert
  H->>HB: 행사 종료
  HB->>D: rpc transition_event ended
  D->>D: 열린 문항 닫기, retention_until 설정
  W->>R: 최종 상태 1회 전송 후 hb 중단
```

### 그림 4-C. Q&A 질문과 AI 정리 (LP-F-013~015, 029, 030)

**읽는 법**: AI는 라벨과 군집을 제안만 하고 질문 상태는 바꾸지 않는다. 진행자가 선택해 `moderate_question`을 호출해야 상태가 바뀐다. 청중 원문을 읽는 단계는 국외 이전 동의와 상관없이 오픈소스 모델만 쓴다(01_PRD 6.1절).

```mermaid
sequenceDiagram
  autonumber
  actor A as 청중
  actor H as 진행자
  participant N as Next.js
  participant D as DB poll + core
  participant F as FastAPI poll.qna_assist

  A->>N: POST /api/p/question body, show_nickname
  N->>D: ask_question (service_role)
  Note over D: 참가자 live 차단 확인<br/>분당 3건, 행사당 20건<br/>금칙어 검사
  alt 금칙어 포함
    D-->>N: hidden, 작성자에겐 검토 중
  else 모더레이션 켜짐
    D-->>N: pending
  else 꺼짐
    D-->>N: visible
  end
  H->>N: Q&A AI 정리 실행 mode all
  N->>N: 세션 역할 features.qna_assist 확인
  N->>D: consume_credits 질문 수 구간 5, 12, 24
  N->>F: 서명 토큰 scope graph + POST /graphs/poll.qna_assist/runs
  F->>D: load 최근 600건 읽기 전용, 닉네임 제외
  F->>F: moderate, cluster, summarize
  F->>F: compliance 위반 문장만 1회 재작성
  F-->>N: SSE progress, result run_id, done
  N-->>H: 라벨 군집 요약 (AI가 정리한 내용 표시)
  alt 실패
    N->>D: refund_credits
  end
  H->>N: 제안 선택 후 적용
  loop 선택한 질문마다
    N->>D: rpc moderate_question (진행자 세션)
    D-->>N: 상태 변경 + moderated_by
  end
```

### 그림 4-D. 청중 음성 질문 (LP-F-032, 035)

**읽는 법**: 청중은 지갑이 없어 비용을 행사 소유 조직이 낸다. 그래서 STT 호출 전에 한도 5중 검사를 하고, 4건 묶음 단위로 진행자 지갑에서 선차감한다. STT 결과는 저장하지 않고 청중이 확인·수정한 뒤에야 일반 질문 경로(그림 4-C 1~3)로 들어간다.

```mermaid
sequenceDiagram
  autonumber
  actor A as 청중
  participant N as Next.js /api/p/voice-question
  participant D as DB core
  participant S as 오픈소스 음성 서버
  participant Q as /api/p/question

  A->>N: 음성 업로드 20초 이하 500KB 이하
  N->>D: 참가자 쿠키 확인 live 차단 audience_voice 켜짐
  N->>D: rate_limit_hit 5중 (참가자 분 2, 참가자 일, 행사 일, 행사 시간 120, IP HMAC 10분 20)
  alt 하나라도 초과
    N-->>A: 429 STT 호출 없음
  else 통과
    opt 행사 카운터가 4건 묶음 시작
      N->>D: consume_credits 1, voice-block 행사 n (멱등)
    end
    alt 잔액 부족
      N-->>A: 429 AI_VOICE_LIMIT 음성 질문이 닫혔습니다
    else 진행
      N->>S: 서명 토큰 sub visitor:pt:participant_id, scope voice
      S-->>N: text, duration (store_audio false)
      N-->>A: 변환 텍스트 300자 이내 (서버 저장 없음)
      A->>Q: 수정 후 질문 보내기
      Q->>D: ask_question 한도 금칙어 모더레이션 다시 적용
    end
  end
  Note over D: 행사 종료 후 정산 크론이<br/>쓰지 않은 묶음을 refund_credits
```

---

## 5. 상태 머신

전이는 트리거가 모든 쓰기(service_role 포함)에 강제한다. 허용되지 않은 전이는 `PL011`, 일부는 `22023`이다.

### 그림 5-A. 행사 `events.status`

**읽는 법**: 라벨은 전이를 일으키는 주체와 RPC이다. 정리 함수는 24시간 넘게 live인 행사를 종료하고 종료 7일 뒤 archived로 보내며 이때 코드를 반납한다.

```mermaid
stateDiagram-v2
  [*] --> draft : create_event 진행자
  draft --> live : transition_event 진행자 정원 고정
  draft --> archived : transition_event 진행자
  live --> ended : transition_event 진행자
  live --> ended : 정리 함수 24시간 초과
  ended --> live : transition_event 종료 24시간 이내 재개
  ended --> archived : transition_event 진행자
  ended --> archived : 정리 함수 7일 뒤 코드 반납
  archived --> [*]
```

### 그림 5-B. 문항 `polls.status`

**읽는 법**: 문항을 열면 같은 행사에 열린 다른 문항은 자동으로 닫히고 확정된다. 열린 뒤에는 내용이 고정된다.

```mermaid
stateDiagram-v2
  [*] --> draft : 진행자 INSERT
  draft --> open : transition_poll 내용 고정
  open --> closed : transition_poll 확정 집계 upsert
  closed --> open : transition_poll 재개 기존 표 유지
```

### 그림 5-C. Q&A 질문 `qna_questions.status`

**읽는 법**: 시작 상태는 입장 규칙에 따라 다르다(모더레이션 켜짐은 pending, 금칙어는 hidden, 그 외는 visible). 이후 전이는 진행자의 `moderate_question`이고, 참가자 차단 시 질문이 자동으로 숨겨진다.

```mermaid
stateDiagram-v2
  [*] --> pending : ask_question 모더레이션 켜짐
  [*] --> visible : ask_question 모더레이션 꺼짐
  [*] --> hidden : ask_question 금칙어
  pending --> visible : moderate_question 진행자
  pending --> rejected : moderate_question 진행자
  pending --> hidden : moderate_question 진행자
  visible --> answered : moderate_question 진행자
  visible --> hidden : moderate_question 진행자
  visible --> hidden : block_participant 자동
  answered --> visible : moderate_question 진행자
  hidden --> visible : moderate_question 진행자
  rejected --> visible : moderate_question 진행자
```

---

## 6. 화면 흐름

**읽는 법**: 세 갈래다. 가운데는 진행자(로그인), 오른쪽은 청중(로그인 없음), 아래는 방송용 오버레이(키). 점선은 새 창으로 여는 화면이다. 경로는 03_SCREENS_UX 1절 표기이다.

```mermaid
flowchart TB
  LAND["/ 랜딩 · /pricing<br/>3D 히어로"]

  subgraph HOSTS["진행자 로그인 필요"]
    LOGIN["/login · /signup<br/>/auth/callback"]
    ONB["/onboarding<br/>AI 처리 방식 선택"]
    EVL["/events<br/>행사 목록"]
    NEW["/events/new"]
    EDIT["/events/id/edit<br/>문항 · 설정"]
    MAT["/events/id/materials<br/>자료 색인"]
    LIVE["/events/id/live<br/>진행자 콘솔"]
    RES["/events/id/results<br/>결과 · CSV"]
    SET["/settings<br/>금칙어 · 로그인 방법"]
    WIKI["/wiki<br/>행사 위키"]
    PRES["/present/id<br/>발표 화면"]
  end

  subgraph AUDS["청중 로그인 없음"]
    JOIN["/join<br/>코드 입력"]
    ENT["/e/code<br/>입장 → 대기 → 투표 → 결과"]
    QNA["Q&A 탭 · 음성 질문"]
  end

  OVL["/overlay/id?k=<br/>OBS 오버레이"]

  LAND --> LOGIN --> ONB --> EVL
  LAND --> JOIN
  EVL --> NEW --> EDIT
  EDIT --> MAT
  EDIT -->|"행사 시작"| LIVE
  LIVE -.->|"새 창"| PRES
  LIVE -.->|"키 포함 URL 1회 표시"| OVL
  LIVE -->|"행사 종료"| RES
  EVL --> RES
  EVL --> SET
  MAT --> WIKI
  JOIN -->|"QR 도 같은 경로"| ENT
  ENT --> QNA
```

---

## 7. 보안 신뢰 경계

**읽는 법**: 신뢰 수준이 다른 세 종류의 클라이언트(진행자 세션, 청중 토큰, 오버레이 키)가 각각 다른 길로 DB에 닿는다. 청중과 오버레이는 DB 권한이 없고 Realtime 수신만 한다. `§`는 `../_platform-core/SECURITY_BASELINE.md`의 장 번호다. 이 제품의 `SECURITY.md`가 템플릿 상태라 자산·위협은 05_DATA_MODEL 7장, 02_ARCHITECTURE 5-1·5-4·6장, 01_PRD 6장에서 가져왔다.

```mermaid
flowchart TB
  subgraph Z0["구역 0. 인터넷 (신뢰 없음)"]
    ATK["공격자 · 봇<br/>코드 대입 · 투표 폭주 · 가짜 결과"]
    AUDB["청중 브라우저<br/>참가자 토큰 쿠키"]
    OBSB["OBS 오버레이<br/>키 ?k="]
    HOSTB["진행자 브라우저<br/>Supabase 세션"]
  end

  subgraph Z1["구역 1. Next.js (Vercel)"]
    EDGE["보안 헤더 §18 · noindex<br/>레이트 리밋 §8 §21"]
    PAPI["/api/p/*<br/>IP는 HMAC 키로만 사용 §12"]
    OAPI["/api/overlay/*<br/>키 해시 대조"]
    AIG["/api/ai · /api/voice<br/>진행자 세션만 §16"]
  end

  subgraph Z2["구역 2. 서버 전용 자격 (service_role)"]
    SR["service_role RPC<br/>cast_vote join_event 등 §4"]
    SIGN["JWT 발급 HS256 단기 6시간<br/>EdDSA 서명 토큰 §16"]
  end

  subgraph Z3["구역 3. DB와 Realtime"]
    RLS["RLS 멤버 + 엔타이틀먼트 §15<br/>복합 FK 조직 행사 격리"]
    GUARD["guard_privileged_write<br/>쓰기 이중 잠금"]
    PRIV["private 채널<br/>송신 정책 없음, 토픽 일치 JWT만 수신"]
    HASH["해시만 저장<br/>참가자 토큰 · 오버레이 키 · 비밀번호"]
  end

  subgraph Z4["구역 4. AI 서비스 (투표 경로와 분리)"]
    FAS["FastAPI · Dify 내부 키<br/>토큰 aud 검증"]
    FOSS["청중 원문 단계는<br/>오픈소스 강제"]
    COMP["compliance<br/>닉네임 제거 · 대표성 단정 금지"]
  end

  ATK -.-> EDGE
  AUDB --> EDGE --> PAPI --> SR
  OBSB --> OAPI --> SR
  HOSTB -->|"anon 키 + 세션"| RLS
  HOSTB --> AIG --> SIGN --> FAS
  SR --> GUARD --> RLS
  RLS --- HASH
  PAPI --> SIGN
  OAPI --> SIGN
  SIGN -.->|"토픽 JWT"| PRIV
  FAS --> FOSS
  FAS --> COMP
  AUDB -.->|"수신만"| PRIV
  OBSB -.->|"수신만"| PRIV
```

**위협과 대응 요약** (문서에 있는 것만)

| 위협 | 대응 | 근거 |
|---|---|---|
| IP 기반 1인 1표의 오차단과 우회 (리뷰 #3) | 참가자 토큰 단위 `unique(poll_id, participant_id)`, 소프트 제한 고지, 정원·잠금·비밀번호·분당 20표·참가자 차단 | 05_DATA_MODEL 7장, LP-F-008 |
| IP 해시 저장 = 개인정보 처리 (리뷰 #4) | 제품 테이블에 IP 없음, HMAC(비밀키+날짜)를 레이트 리밋 키에만, 버킷 1일 뒤 삭제 | 05_DATA_MODEL 7장 |
| 투표 폭주와 브로드캐스트 폭증 (리뷰 #1) | 투표는 INSERT만, 워커가 250ms로 묶어 전송 | 02_ARCHITECTURE 5-1·6장 |
| 가짜 결과 주입 | private 채널, 송신 정책 없음(service_role만), 토픽 일치 JWT만 수신 | 02_ARCHITECTURE 5-1절 |
| 코드 대입 | 실패만 IP 해시당 10분 30회, 초과 시 조회 자체 생략 | LP-F-019 |
| 오버레이 키 유출 | 해시 저장, 재발급 시 이전 키 즉시 무효 | LP-F-012 |
| 청중 자유 입력의 외부 모델 유출 | 청중 원문 단계 `force_open_source`, 청중은 `/api/ai/*` 통과 불가 | 01_PRD 6.1절, 02_ARCHITECTURE 2절 |
| 청중 음성 남용과 비용 | 5중 레이트 리밋, 4건 묶음 선차감, 오디오 비저장 | 02_ARCHITECTURE 5-4절 |
| AI가 질문을 임의 삭제 | AI는 제안만, 적용은 진행자의 `moderate_question` | LP-F-030 |

---

## 문서 불일치

1. **`SECURITY.md` 미작성**: 자산, 위협, 공통 규칙의 제품별 수치, 외부 서비스 이전 표가 모두 "(작성 필요)"다. 그림 7과 위 표는 다른 문서에서 가져왔으므로 SECURITY.md가 채워지면 다시 맞춘다.
2. **공동 진행자 범위**: `01_PRD` 2장은 공동 진행자(팀 멤버)를 Phase 2로 두었는데 `05_DATA_MODEL` 10절의 시드 페르소나와 `README.md`는 `host`·`cohost`를 MVP 개발용으로 둔다. 그림 1-B는 01_PRD를 따랐다. RLS의 쓰기 역할(owner, admin, member)은 MVP에 이미 있다.
3. **브로드캐스트 간격**: `01_PRD` LP-F-009는 인원별 간격(300명 이하 250ms, 1,000명 이하 500ms, 초과 1,000ms, 제안)을 말하고 `02_ARCHITECTURE` 4절은 MVP(참가자 100명 한도)는 모두 250ms 고정, 인원별 간격은 Phase 2라고 한다. 그림 4-B는 250ms 틱으로 그렸다.
4. **JWT 서명 방식 미확인**: `02_ARCHITECTURE` 5-1절은 Supabase 새 JWT 서명 체계에서 사용자 정의 JWT를 Realtime이 받는지 "미확인"이라 쓰고 대안(공개 채널 + 워커 Ed25519 서명)을 적었다. 그림 2-A와 7은 기본안(HS256 단기 JWT)으로 그렸다.

## 갱신 규칙

`01_PRD`, `02_ARCHITECTURE`, `03_SCREENS_UX`, `04_API`, `05_DATA_MODEL`, `SECURITY.md` 중 하나를 고치면 해당 그림(위 표의 근거 절)도 같은 변경에서 함께 고친다. 수정 뒤에는 Mermaid 검증을 다시 돌린다.
