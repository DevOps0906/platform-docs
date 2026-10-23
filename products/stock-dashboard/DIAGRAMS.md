# DIAGRAMS: Stock Dashboard UML 시각화

작성일 2026-10-23. 이 문서는 `stock-dashboard`의 기획 문서를 그림으로 옮긴 것이다. 정본은 각 문서이며 그림과 문서가 다르면 문서가 우선한다. GitHub에서 Mermaid가 바로 렌더링된다. 전체 플랫폼 구조는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일로 맞췄다.

**제품 한 줄 정의**: 본인이 직접 연결한 증권사 계좌(1차는 모의투자)의 잔고·보유·체결을 한 화면에서 조회하고, AI가 포트폴리오의 분산과 위험 요인을 "진단"해 주는 초대제 개인 투자 대시보드. 종목 추천과 매수가·목표가·손절가는 제시하지 않는다.

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`. 공통은 `../_platform-core/SECURITY_BASELINE.md`, `CORE_SPEC.md`, `AI_ARCHITECTURE.md`.

**표기**: 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·구독, "(제안)" = 문서가 제안이라 한 값(확정 전). Phase 2·3 항목은 노드 이름에 `P2`, `P3`를 붙였다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-A | 사용자와 기능 (MVP) | 유스케이스(flowchart) | 01_PRD 1장, 2장, 3.1절 |
| 1-B | 사용자와 기능 (Phase 2, 3, 보류) | 유스케이스(flowchart) | 01_PRD 2장, 3.2~3.3절 |
| 2-A | 구성요소: 웹, 워커, 코어 | 컴포넌트(flowchart) | 02_ARCHITECTURE 2~4절, 7절 |
| 2-B | 구성요소: AI 경로 | 컴포넌트(flowchart) | 02_ARCHITECTURE 2절(AI 경계), 5절 |
| 3-A | 데이터 모델: 베타, 연결, 동기화 | 클래스(classDiagram) | 05_DATA_MODEL 1~2절, 4절 |
| 3-B | 데이터 모델: AI 리포트, 모의주문 | 클래스(classDiagram) | 05_DATA_MODEL 2.7~2.8절, 4절 |
| 4-A | 시퀀스: 초대 수락과 부트스트랩 | 시퀀스 | 03_SCREENS_UX 2.1절, 04_API 2~3절 |
| 4-B | 시퀀스: 계좌 연결과 동기화 | 시퀀스 | 01_PRD ST-F-003~005, 04_API 2절, 02_ARCHITECTURE 4절 |
| 4-C | 시퀀스: AI 포트폴리오 진단 | 시퀀스 | 02_ARCHITECTURE 5.4절, 01_PRD ST-F-011, 022, 030 |
| 4-D | 시퀀스: 모의주문 확인 (P3) | 시퀀스 | 03_SCREENS_UX 2.5절, 04_API 2~3절, 01_PRD ST-F-018~021 |
| 5-A | 상태: 초대와 베타 접근 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-B | 상태: 증권사 연결 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-C | 상태: AI 리포트 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-D | 상태: 모의주문 (P3) | 상태 머신 | 05_DATA_MODEL 3절 |
| 6 | 화면 흐름 | flowchart | 03_SCREENS_UX 1절, 2절, 8절 |
| 7 | 보안 신뢰 경계 | flowchart | 05_DATA_MODEL 7절, 02_ARCHITECTURE 2절·6절, 01_PRD 6장, SECURITY_BASELINE |

> 이 제품의 `SECURITY.md`는 아직 템플릿 상태(자산, 위협, 수치가 "작성 필요")라서 7번 그림은 `05_DATA_MODEL` 7장, `02_ARCHITECTURE` 2·6장, `01_PRD` 6장의 보안 서술을 근거로 그렸다. 자세한 내용은 맨 끝 "문서 불일치"에 있다.

---

## 1. 사용자와 기능

### 그림 1-A. MVP 기능

**읽는 법**: 왼쪽이 역할, 오른쪽이 기능 묶음이다. 기능 노드에 문서의 기능 ID(`ST-F-###`)를 붙였다. 초대받은 투자자(베타 사용자)가 쓰는 기능과 운영자 기능을 나눴다.

```mermaid
flowchart LR
  INV(["베타 투자자<br/>초대받은 개인"])
  OPS(["운영자<br/>platform_admin"])

  subgraph ACC["계정과 동의"]
    F1["초대제 가입<br/>베타 게이트 ST-F-001"]
    F2["투자 고지와 동의<br/>ST-F-002"]
    F29["AI 국외 이전 동의<br/>ST-F-029"]
  end

  subgraph PORT["계좌와 포트폴리오"]
    F3["증권사 연결 모의투자<br/>ST-F-003"]
    F4["키 암호화 보관, 마스킹<br/>ST-F-004"]
    F5["동기화 조회 전용<br/>ST-F-005"]
    F6["포트폴리오 홈<br/>ST-F-006"]
    F7["시세 중계, 블링크<br/>ST-F-007"]
    F8["종목 상세 모달<br/>ST-F-008"]
    F9["매매 일지<br/>ST-F-009"]
    F10["장 운영 정보<br/>ST-F-010"]
  end

  subgraph AIF["AI 기능"]
    F11["AI 포트폴리오 진단<br/>ST-F-011"]
    F23["리서치 요약<br/>ST-F-023"]
    F26["AI 리서치 채팅<br/>ST-F-026"]
    F27["음성 질의<br/>ST-F-027"]
    F28["브리핑 생성, 낭독<br/>ST-F-028"]
    F25["용어 해설 위키<br/>ST-F-025"]
    F22["투자 권유 금지 검사<br/>ST-F-022"]
    F30["크레딧 선차감, 정산<br/>ST-F-030"]
  end

  subgraph ADM["운영"]
    F12["운영자 화면<br/>초대, 킬 스위치 ST-F-012"]
    F24["공시 RAG 색인<br/>ST-F-024"]
    F31["3D 히어로 랜딩<br/>ST-F-031"]
  end

  INV --> F1 --> F2 --> F29
  INV --> F3 --> F5 --> F6
  F3 -.-> F4
  INV --> F6
  INV --> F7
  INV --> F8
  INV --> F9
  INV --> F11
  INV --> F26
  F26 --> F27
  INV --> F28
  INV --> F25
  F11 -.-> F22
  F23 -.-> F22
  F26 -.-> F22
  F11 -.-> F30
  OPS --> F12
  OPS --> F24
  F24 -.-> F23
  INV -.-> F10
```

### 그림 1-B. Phase 2, Phase 3, 보류와 폐기

**읽는 법**: 문서의 범위 표(01_PRD 2장)에서 MVP 밖에 있는 항목이다. 실선은 해당 Phase에서 열리는 기능, 점선은 선행 조건이다. 보류·폐기 항목은 오른쪽에 모았다.

```mermaid
flowchart LR
  INV(["베타 투자자"])
  OPS(["운영자"])

  subgraph P2["Phase 2"]
    F13["AI 관심 아이디어, 성과 평가<br/>내부 리더보드 ST-F-013"]
    F14["AI 3사 비교<br/>ST-F-014"]
    F15["실계좌 조회 연결<br/>ST-F-015"]
    F16["유료 플랜 Toss<br/>ST-F-016"]
    F17["두 번째 증권사<br/>ST-F-017"]
  end

  subgraph P3["Phase 3 선택"]
    F18["모의투자 주문<br/>ST-F-018"]
    F19["주문 한도<br/>ST-F-019"]
    F20["킬 스위치<br/>ST-F-020"]
    F21["주문 감사<br/>ST-F-021"]
  end

  subgraph HOLD["보류와 폐기"]
    H1["브리핑 정기 자동 생성, 푸시<br/>보류 D-15"]
    H2["뉴스 본문 색인<br/>조건부 D-10"]
    H3["실전 주문<br/>범위 밖"]
    H4["공개 리더보드, 스크래핑<br/>폐기"]
  end

  COND1["법률 검토 통과"]
  COND2["spike와 약관 확인"]

  INV --> F13
  INV --> F14
  INV --> F18
  INV --> F20
  OPS --> F20
  F16 -.-> COND1
  F15 -.-> COND2
  F17 -.-> COND2
  F18 --> F19
  F18 --> F21
  F20 -.-> F18
```

---

## 2. 구성요소

### 그림 2-A. 웹, 워커, 코어

**읽는 법**: 브라우저는 Next.js 앱(Route Handler)과 시세 중계 워커의 SSE만 부른다. 증권사와 AI 제공자는 서버와 워커만 호출한다. 이 제품은 모놀리스(전용 Supabase 프로젝트)이므로 코어는 `core-lite`로 같은 DB 안에 있다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["화면 · zustand 시세 스토어<br/>EventSource"]
  end

  subgraph WEB["Next.js 앱 (Vercel)"]
    PX["proxy.ts<br/>세션 · 라우트 보호"]
    RH["Route Handler<br/>/api/connections · /api/trades 등"]
    STK["stream-token 발급<br/>HMAC 60초"]
    BRK["BrokerAdapter<br/>mock · 증권사 1곳"]
    AIG["AI 게이트 /api/ai · /api/voice<br/>(그림 2-B)"]
  end

  subgraph WK["워커 (Railway)"]
    QR["quote-relay<br/>증권사 WS 유지, SSE 팬아웃"]
    SJ["stock-jobs<br/>sync · reference · eval · orders"]
  end

  subgraph DB["Supabase 모놀리스 (전용 프로젝트)"]
    CORE["core-lite<br/>조직 · 크레딧 · 잡 · 감사 · 자격증명"]
    PROD["제품 테이블 19개<br/>beta · broker · trades · ai_reports 등"]
    RT["Realtime<br/>holdings · order_requests"]
  end

  subgraph EXT["외부"]
    BRKX[("증권사 API<br/>모의투자")]
    DART[("DART 공시")]
    TOSS[("Toss P2")]
  end

  UI --> PX --> RH
  UI --> STK
  UI -->|"SSE 토큰"| QR
  RH --> BRK --> BRKX
  RH -->|"사용자 세션 RLS"| PROD
  RH -->|"service_role"| CORE
  RH -->|"enqueue_job"| CORE
  SJ -->|"claim · heartbeat · complete"| CORE
  SJ --> BRKX
  SJ --> DART
  SJ --> PROD
  QR -->|"복호화한 키로 구독"| BRKX
  QR -.->|"자격증명 읽기"| CORE
  RT -.-> UI
  RH <-->|"P2 승인 확인 · 웹훅"| TOSS
  AIG --> CORE
```

### 그림 2-B. AI 경로

**읽는 법**: 브라우저는 `/api/ai/*`와 `/api/voice/*`만 부른다. Next.js가 크레딧을 선차감하고 EdDSA 서명 토큰으로 FastAPI를 호출한다. 진단·요약·브리핑은 LangGraph 그래프, 채팅은 Dify를 거쳐 FastAPI 도구 경로로 간다. 모든 사용자 노출 텍스트는 `advice_check`와 `compliance`를 통과해야 한다.

```mermaid
flowchart TB
  UI["브라우저<br/>채팅 패널 · 진단 · 브리핑"]

  subgraph NX["Next.js AI 게이트"]
    GATE["Route Handler<br/>세션 · 동의 · 한도 · 선차감"]
    SIGN["EdDSA 서명 토큰 발급<br/>iss=stock"]
    SETTLE["/api/internal/ai-settle<br/>정산 크론"]
    VOICE["/api/voice<br/>STT · TTS · 낭독"]
  end

  DIFY["Dify stock-chat<br/>분류 노드 + HTTP 노드"]

  subgraph FA["FastAPI ai-service (Railway)"]
    GR["그래프<br/>stock.diagnosis<br/>stock.research_summary"]
    TL["도구 /tools/answer"]
    ADV["advice_check<br/>규칙 사전 → LLM 판정"]
    CMP["compliance<br/>금지 문구 · 스키마 · 출처"]
    RAG["RAG · 위키<br/>match_ai_chunks"]
  end

  subgraph MODEL["모델"]
    OSS["오픈소스 LLM · 임베딩 · 음성<br/>자체 호스팅 GPU"]
    COM["상용 LLM · ElevenLabs<br/>국외 이전 동의 조직만"]
  end

  CORE[("core-lite<br/>ai_runs · ai_messages · 크레딧")]
  DBP[("ai_reports")]
  SJ["stock-jobs<br/>5분마다 호출"]

  UI --> GATE
  UI --> VOICE
  GATE --> SIGN --> GR
  GATE -->|"채팅"| DIFY
  GATE -.->|"Dify 장애 시 직접"| TL
  DIFY -->|"내부 키 + 대화 id"| TL
  GR --> ADV --> CMP
  TL --> ADV
  GR --> RAG
  TL --> RAG
  GR --> OSS
  GR --> COM
  VOICE --> OSS
  VOICE --> COM
  GATE -->|"consume · refund"| CORE
  GATE --> DBP
  SJ --> SETTLE
  SETTLE --> CORE
  FA -->|"ai_runs · usage"| CORE
```

---

## 3. 데이터 모델

모든 테이블은 RLS ON이고 `FOR ALL` 정책이 없다. 도메인 테이블 읽기는 `stock.has_stock_access(org_id)`(멤버 + 엔타이틀먼트 + 베타 활성)이며 사용자 쓰기 정책은 `trade_notes`만 있다. 정본 SQL은 `_supabase-modular/migrations/1900_stock.sql`이다.

### 그림 3-A. 베타, 연결, 동기화

**읽는 법**: 조직(`core.organizations`, 참조만) 아래에 베타 접근과 증권사 연결이 달리고, 연결 아래에 시계열·보유·체결·메모가 달린다. 하위 테이블은 `(parent_id, org_id)` 복합 FK로 다른 조직의 행을 붙일 수 없다. 각 클래스의 note가 RLS 접근 주체다.

```mermaid
classDiagram
  class beta_invites {
    id
    email_normalized
    token_hash sha256
    status issued accepted revoked expired
    expires_at 14일 제안
  }
  class beta_access {
    org_id PK
    invite_id
    status active revoked
  }
  class consents {
    id
    org_id
    user_id
    kind
    version
    accepted_at
  }
  class broker_connections {
    id
    org_id
    broker mock kis kiwoom hana
    env paper live
    account_masked
    account_ref_hash
    credential_id
    status pending active error revoked
    orders_enabled
    consecutive_errors
  }
  class balance_snapshots {
    id
    connection_id
    captured_at
    cash_krw
    eval_krw
    is_sample
  }
  class holdings {
    connection_id
    symbol
    quantity
    avg_price
    synced_at
  }
  class trades {
    id
    connection_id
    broker_exec_id
    symbol
    side
    executed_at
  }
  class trade_notes {
    id
    trade_id
    body 2000자
    tags 10개
    created_by
  }
  class instruments {
    symbol PK
    name
    market
    sector
    is_active
  }
  class fundamentals {
    symbol
    fiscal_period
    per pbr roe
    source
    as_of
  }
  class market_calendar {
    trade_date PK
    is_open
    open_at
    close_at
  }
  class encrypted_credentials {
    core 참조만
    AES-256-GCM
  }

  beta_invites "1" --> "0..1" beta_access : 수락 시 생성
  beta_access "1" --> "*" broker_connections : 같은 조직
  broker_connections "1" --> "*" balance_snapshots : 시계열
  broker_connections "1" --> "*" holdings : 연결 x 종목 유일
  broker_connections "1" --> "*" trades : 연결 x 체결번호 유일
  trades "1" --> "*" trade_notes : 사용자 메모
  broker_connections ..> encrypted_credentials : credential_id
  instruments "1" --> "*" fundamentals : 출처 기준일
  holdings ..> instruments : symbol
  beta_access ..> consents : 같은 조직 동의

  note for beta_invites "접근 주체 service_role만<br/>사용자 GRANT 없음"
  note for beta_access "SELECT 조직 멤버<br/>쓰기 RPC redeem, revoke"
  note for consents "SELECT 본인만<br/>INSERT record_consent RPC만<br/>append-only"
  note for broker_connections "SELECT has_stock_access<br/>쓰기 service_role"
  note for trade_notes "유일한 사용자 쓰기 테이블<br/>작성자 수정, owner admin 삭제"
  note for encrypted_credentials "사용자 SELECT 불가 42501<br/>서버 service_role만"
  note for instruments "SELECT 공개 정보<br/>쓰기 service_role"
```

### 그림 3-B. AI 리포트와 모의주문

**읽는 법**: 위쪽은 AI 결과(진단·아이디어·리서치·브리핑이 `ai_reports` 한 표를 공유), 아래쪽은 Phase 3 모의주문 테이블이다. 제품 전용 AI 대화·위키·음성 표는 없고 코어 `core.ai_*`를 쓴다. 주문 표는 별도 마이그레이션(`0003_stock_orders_paper.sql`)이다.

```mermaid
classDiagram
  class ai_reports {
    id
    org_id
    kind diagnosis idea research briefing
    scope_connection_id
    status
    provider model
    input_hash
    output jsonb
    credits_charged
    credit_ledger_id
    request_id 멱등
  }
  class ai_report_items {
    report_id
    symbol
    risk_level low medium high
    weight_pct
    factors
  }
  class idea_evaluations {
    item_id
    horizon_days 5 20 60
    entry_date
    return_pct
    excess_pct
    rule_version
  }
  class daily_prices {
    symbol
    trade_date
    close
    source
  }
  class order_limits {
    org_id PK
    max_order_krw
    max_daily_krw
    max_orders_per_day
    max_price_deviation_pct
  }
  class kill_switches {
    scope global org connection
    is_active
    trigger_source
    reason
  }
  class order_requests {
    id
    connection_id
    client_order_id 멱등
    env paper만
    side
    order_type limit만
    quantity
    limit_price
    status
    block_reason
    confirm_expires_at
    broker_order_id
  }
  class order_events {
    order_id
    event
    from_status
    to_status
    actor_role
  }
  class credit_ledger {
    core 참조만
  }

  ai_reports "1" --> "*" ai_report_items : 종목별 위험
  ai_report_items "1" --> "*" idea_evaluations : P2 성과
  ai_reports ..> credit_ledger : credit_ledger_id
  idea_evaluations ..> daily_prices : 진입 평가 가격
  order_requests "1" --> "*" order_events : 모든 전이 기록
  order_limits ..> order_requests : 한도 판정
  kill_switches ..> order_requests : 켜지면 blocked
  ai_reports ..> order_requests : prefill_report_id

  note for ai_reports "SELECT has_stock_access<br/>쓰기 service_role만<br/>succeeded는 advice_check passed 필수<br/>가격 키 CHECK로 거부"
  note for daily_prices "사용자 GRANT 없음<br/>성과 계산 전용"
  note for order_requests "SELECT has_stock_access<br/>쓰기 RPC만<br/>env paper CHECK로 실전 불가"
  note for order_events "append-only<br/>UPDATE DELETE는 ST000"
  note for kill_switches "SELECT 전역 또는 has_stock_access<br/>전역 자동 해제는 service_role만"
```

---

## 4. 핵심 시퀀스

### 그림 4-A. 초대 수락과 부트스트랩 (ST-F-001)

**읽는 법**: 초대 토큰 원문은 링크에만 있고 DB에는 sha256만 있다. 서버가 service_role로 수락 RPC를 부르며, 만료(14일), 이메일 불일치, 이미 사용된 초대를 각각 다른 코드로 거절한다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 초대받은 사용자
  participant B as 브라우저
  participant N as Next.js 서버
  participant A as Supabase Auth
  participant D as DB stock + core

  U->>B: 초대 링크 열기 /invite/token
  B->>N: 이메일 가입 signUp signup_app=stock
  N->>A: 계정 생성
  A->>D: 가입 트리거 - 프로필, 개인 조직 생성
  N->>D: bootstrap_app_for_org stock (service_role)
  B->>N: POST /api/beta/redeem token
  Note over N: IP당 10회/10분 레이트 리밋
  N->>D: redeem_beta_invite sha256(token), user (service_role)
  alt 정상
    D-->>N: beta_access active, invite accepted
    N->>D: 구독과 엔타이틀먼트를 beta로 전환
    N->>D: grant_credits 300 멱등 키 monthly
    N->>D: audit stock.beta.plan_switch
    N-->>B: org_id, plan beta
  else 만료 14일 경과
    D-->>N: expired 기록 후 null
    N-->>B: 410
  else 이메일 불일치 또는 이미 사용
    D-->>N: ST031 또는 ST030
    N-->>B: 403 또는 400
  end
  B->>U: /onboarding/disclaimer 이동
```

### 그림 4-B. 계좌 연결과 동기화 (ST-F-003, 004, 005)

**읽는 법**: 키는 서버에서 `verify`를 통과한 뒤에만 암호화 저장된다. 계좌번호는 마스킹 값과 HMAC만 저장한다. 동기화는 `stock.sync` 잡이며 체결은 `(connection_id, broker_exec_id)` 유니크로 중복 없이 upsert한다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 베타 사용자 owner admin
  participant B as 브라우저
  participant N as Next.js Route Handler
  participant X as 증권사 API
  participant D as DB + core vault
  participant W as stock-jobs

  U->>B: 증권사, 앱키, 시크릿, 계좌번호 입력, 본인 계좌 체크
  B->>N: POST /api/connections request_id
  Note over N: 세션, 베타, 역할 검사<br/>조직당 시간당 5회 레이트 리밋
  N->>X: BrokerAdapter.verify 토큰 발급 테스트
  alt verify 실패
    N->>D: 연결 행 status error 와 원인 코드
    N-->>B: 원인 코드
  else 성공
    N->>D: vault put AES-256-GCM, 계좌 마스킹과 HMAC 저장
    N->>D: INSERT broker_connections active
    N->>D: enqueue_job stock.sync
    N-->>B: 마스킹된 연결
  end
  W->>D: claim 잡 (멱등 키 5분 버킷)
  W->>D: 자격증명 복호화 service_role
  W->>X: getBalance getHoldings getExecutions
  W->>D: upsert 스냅샷, 보유, 체결
  D-->>B: Realtime holdings 구독
  opt 연속 오류 5회
    W->>D: 연결 status error, 알림
  end
```

### 그림 4-C. AI 포트폴리오 진단 (ST-F-011, 022, 030)

**읽는 법**: 크레딧은 호출 전에 선차감하고, 검사에 실패하거나 시간 초과면 전액 환불한다. 모델에는 비율 스냅샷만 보내고 수량·금액·계좌번호는 보내지 않는다. 결과는 투자 권유 금지 검사를 통과한 뒤에만 저장·표시된다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 베타 사용자
  participant B as 브라우저
  participant N as Next.js AI 게이트
  participant D as DB core + ai_reports
  participant F as FastAPI 그래프 stock.diagnosis

  U->>B: 내 포트폴리오 진단하기 10 크레딧
  B->>N: POST /api/ai/diagnoses request_id
  N->>N: 세션, 최신 동의, 일 상한, 분당 3회 레이트 리밋
  N->>D: 같은 request_id 리포트 조회 (멱등)
  N->>N: 비율 스냅샷 조립, 위험 수준 서버 규칙 계산
  N->>D: consume_credits 정액 키 consume:stock:request_id
  alt 크레딧 부족 CR001
    N-->>B: 402
  else 진행
    N->>D: INSERT ai_reports queued
    N->>F: 서명 토큰 scope graph:stock.diagnosis + 스냅샷
    F->>F: 토큰 aud, scope, jti 1회 검증
    F->>F: explain 노드
    F->>F: advice_check 규칙 사전 + LLM 판정
    opt 위반 시 1회 재생성
      F->>F: explain 재실행 후 advice_check
    end
    F->>F: compliance 금지 문구, 스키마, 가격 키, AI 표시
    loop 2초 간격 최대 60초
      N->>F: GET /graphs/runs/id
    end
    alt 통과
      N->>D: ai_reports succeeded, output.advice_check.passed true
      N-->>B: NDJSON status, result, done
    else ADVICE_BLOCKED, 시간 초과, 검증 실패
      N->>D: ai_reports failed
      N->>D: refund_credits 전액
      N-->>B: NDJSON error
    end
  end
```

### 그림 4-D. 모의주문 확인 (Phase 3, ST-F-018~021)

**읽는 법**: 한도 위반과 킬 스위치는 예외가 아니라 `blocked` 상태 행으로 남는다. 사용자는 60초 안에 수량·가격·예상 금액을 보고 직접 확인해야 하고, 워커는 제출 직전에 킬 스위치를 다시 확인한다. 실전 주문 경로는 없다(DB에서 `env=paper`만 허용).

```mermaid
sequenceDiagram
  autonumber
  actor U as 생성자 본인
  participant B as 브라우저
  participant N as Next.js 서버
  participant D as DB stock RPC
  participant W as stock-jobs
  participant X as 증권사 모의투자

  U->>B: 종목, 매수 매도, 수량, 지정가 입력
  B->>N: POST /api/orders/preview client_order_id
  Note over N: paper_orders 플랜, ORDERS_ENABLED, paper_order_risk 동의 확인
  N->>X: 현재가 조회
  N->>D: create_paper_order (service_role)
  alt 한도 위반 또는 킬 스위치 또는 시세 지연
    D-->>N: status blocked 와 block_reason
    N-->>B: 사유 표시
  else 통과
    D-->>N: pending_confirm 60초
    N-->>B: 확인 화면 카운트다운
    U->>B: 모의주문 확인
    B->>N: POST /api/orders/id/confirm
    N->>D: confirm_paper_order (사용자 세션, 생성자 본인만)
    alt 60초 초과
      D-->>N: expired
    else 확인됨
      D-->>N: confirmed
      N->>D: enqueue_job stock.order_submit
    end
  end
  W->>D: apply_order_update submitted 직전 킬 스위치 재확인
  W->>X: 지정가 주문 제출 (재시도 0회)
  X-->>W: accepted, filled, rejected
  W->>D: 상태 전이와 order_events 기록
  D-->>B: Realtime order_requests
```

---

## 5. 상태 머신

전이는 모두 `stock.enforce_status_transition()` 트리거가 강제한다(위반 `22023`, service_role도 동일). 전이를 일으키는 주체를 화살표 라벨에 적었다.

### 그림 5-A. 초대와 베타 접근

**읽는 법**: 위 블록은 초대(`beta_invites`), 아래 블록은 베타 접근(`beta_access`)이다. 수락 RPC가 두 상태를 함께 움직인다.

```mermaid
stateDiagram-v2
  state "beta_invites" as INV {
    [*] --> issued : 운영자 API service
    issued --> accepted : redeem_beta_invite
    issued --> revoked : 운영자 회수
    issued --> expired : 만료 처리 14일 1분 주기
  }
  state "beta_access" as ACC {
    [*] --> active : redeem_beta_invite
    active --> revoked : revoke_beta_access
    revoked --> active : 재초대 재수락
  }
  accepted --> active : 수락 시 beta_access 생성
```

### 그림 5-B. 증권사 연결 `broker_connections`

**읽는 법**: mock 연결은 처음부터 `active`다. 워커가 연속 오류 5회를 감지하면 `error`로 바꾸고, 사용자가 다시 연결하면 `active`로 돌아온다. 해제하면 `revoked`이며 자격증명 암호문이 즉시 비워진다.

```mermaid
stateDiagram-v2
  [*] --> pending : service 연결 생성
  [*] --> active : service mock 연결
  pending --> active : 워커 verify 성공
  pending --> error : 워커 verify 실패
  pending --> revoked : 사용자 해제
  active --> error : 워커 연속 오류 5회
  active --> revoked : 사용자 해제
  error --> active : 사용자 재연결
  error --> revoked : 사용자 해제
  revoked --> [*]
```

### 그림 5-C. AI 리포트 `ai_reports`

**읽는 법**: 서버(Route Handler)가 모든 전이를 일으킨다. `queued` 생성 때 크레딧을 선차감하고 `failed` 또는 `canceled`로 가면 환불한다. 3분 넘게 `running`이면 정산 크론이 마무리하거나 환불한다.

```mermaid
stateDiagram-v2
  [*] --> queued : 서버 생성 + 크레딧 선차감
  queued --> running : 서버 그래프 호출
  queued --> canceled : 서버 + 환불
  queued --> failed : 서버 + 환불
  running --> succeeded : 서버 advice_check 통과 저장
  running --> failed : 서버 위반 시간초과 + 환불
  succeeded --> [*]
  failed --> [*]
  canceled --> [*]
```

### 그림 5-D. 모의주문 `order_requests` (Phase 3)

**읽는 법**: 괄호 없이 RPC 이름을 적었다. `create_paper_order`는 한도 위반이면 예외 대신 `blocked`를 반환한다. `submitted` 이후는 워커가 증권사 응답을 반영한다.

```mermaid
stateDiagram-v2
  [*] --> pending_confirm : create_paper_order
  [*] --> blocked : create_paper_order 한도 위반
  pending_confirm --> confirmed : confirm_paper_order 본인
  pending_confirm --> expired : expire_pending_orders 60초
  pending_confirm --> canceled : 사용자
  pending_confirm --> blocked : engage_kill_switch
  confirmed --> submitted : apply_order_update 워커
  confirmed --> blocked : apply_order_update 킬 스위치 재확인
  confirmed --> failed : apply_order_update
  submitted --> accepted : 워커
  submitted --> rejected : 워커
  submitted --> failed : 워커
  accepted --> partially_filled : 워커
  accepted --> filled : 워커
  accepted --> canceled : 워커
  accepted --> rejected : 워커
  partially_filled --> partially_filled : 워커
  partially_filled --> filled : 워커
  partially_filled --> canceled : 워커
  filled --> [*]
```

---

## 6. 화면 흐름

**읽는 법**: 위에서 아래로 첫 사용 여정(초대 → 동의 → 연결 → 진단)이고, 점선 박스는 Phase 2·3 화면이다. 경로는 03_SCREENS_UX 1절의 표기를 따랐다. 운영자 화면은 `platform_admin`만 들어간다.

```mermaid
flowchart TB
  LAND["/ 초대 전용 안내<br/>3D 히어로"]
  LOGIN["/login<br/>A 개발용 B Google 이메일 C 카카오 네이버"]
  INVITE["/invite/token<br/>초대 수락"]
  DISC["/onboarding/disclaimer<br/>투자 고지 · AI 처리 방식"]
  DASH["/dashboard<br/>포트폴리오 홈"]
  MODAL["종목 상세 모달<br/>/dashboard?symbol"]
  CONN["/settings/connections<br/>증권사 연결"]
  TRADES["/trades<br/>매매 일지 · CSV"]
  AI["/ai · /ai/id<br/>진단 실행과 이력"]
  RES["/research · /research/id<br/>리서치 요약"]
  CHAT["채팅 패널 · /chat<br/>텍스트와 음성"]
  BRF["/briefing<br/>브리핑 낭독"]
  WIKI["/wiki<br/>용어 해설"]
  ACCT["/settings/account<br/>동의 이력 · 내보내기 · 탈퇴"]
  LEGAL["/legal/terms · privacy · disclaimer"]

  subgraph ADMIN["운영자 platform_admin"]
    ABETA["/admin/beta<br/>초대 발급 회수"]
    AOPS["/admin/ops<br/>동기화 오류 · 킬 스위치"]
    AKNOW["/admin/knowledge<br/>해설집 · 공시 색인"]
    AWIKI["/admin/wiki<br/>검수 게시 lint"]
  end

  subgraph LATER["Phase 2, 3"]
    LB["/leaderboard P2"]
    CMP["/ai/compare P2"]
    BILL["/settings/billing P2"]
    ORD["/orders P3"]
    LIM["/settings/limits P3"]
  end

  LAND --> LOGIN
  LAND -.-> INVITE
  INVITE --> DISC
  LOGIN --> DASH
  DISC -->|"동의 후"| DASH
  DASH -.->|"동의 전 접근 시 이동"| DISC
  DASH --> MODAL
  DASH --> CONN
  DASH --> TRADES
  DASH --> AI
  DASH --> RES
  DASH --> CHAT
  DASH --> BRF
  CHAT --> WIKI
  DASH --> ACCT
  CONN -->|"연결 후 첫 동기화"| DASH
  AI --> RES
  ABETA --- AOPS
  AKNOW --- AWIKI
  AI -.-> CMP
  DASH -.-> LB
  ACCT -.-> BILL
  DASH -.-> ORD
  ORD --- LIM
  LEGAL -.-> DISC
```

---

## 7. 보안 신뢰 경계

**읽는 법**: 바깥에서 안쪽으로 신뢰가 올라간다. 브라우저는 Next.js 앱과 시세 중계 SSE만 부른다. 비밀(증권사 키)과 service_role은 서버·워커 구역 안에만 있고, 보유 수량·금액은 AI 구역으로 넘어가지 않는다. 노드 옆 `§`는 `../_platform-core/SECURITY_BASELINE.md`의 장 번호다. 이 제품의 `SECURITY.md`가 템플릿 상태라 자산·위협은 05_DATA_MODEL 7장, 02_ARCHITECTURE 6장, 01_PRD 6장에서 가져왔다.

```mermaid
flowchart TB
  subgraph Z0["구역 0. 인터넷 (신뢰 없음)"]
    BR["브라우저<br/>키 · 계좌번호 원문 없음 §11"]
    ATT["공격자 · 약관 위반 사용자"]
  end

  subgraph Z1["구역 1. Next.js 앱 (Vercel)"]
    EDGE["proxy.ts 세션 · 보안 헤더 §18<br/>레이트 리밋 §8 · 봇 방어 §21"]
    RHX["Route Handler<br/>zod 검증 §10 · 베타 게이트"]
    MASK["입력 마스킹 · 로그 마스킹 §12"]
  end

  subgraph Z2["구역 2. 서버 전용 (service_role · 키 복호화)"]
    VAULT["core.encrypted_credentials<br/>AES-256-GCM §5"]
    WK2["stock-jobs · quote-relay<br/>워커에 LLM 키 없음"]
    SIGN2["EdDSA 서명 토큰 §16<br/>개인키는 Next.js만"]
  end

  subgraph Z3["구역 3. DB (RLS) §3 §4 §15"]
    RLS["has_stock_access<br/>복합 FK 조직 격리"]
    CHK["CHECK 방어선<br/>가격 키 거부 · advice_check passed<br/>env paper · 계좌번호 마스킹"]
    AUD["audit_log §9<br/>order_events append-only"]
  end

  subgraph Z4["구역 4. AI 서비스"]
    FAS["FastAPI + Dify<br/>토큰 검증 · 내부 키 §16"]
    ADV2["advice_check, compliance<br/>투자 권유 금지"]
    OSSG["국내 오픈소스<br/>기본 경로"]
    COMG["상용 LLM 국외<br/>이전 동의 조직만"]
  end

  subgraph Z5["외부"]
    BRKY[("증권사 API<br/>본인 명의 키만")]
    DARTY[("DART 공시<br/>이용 조건 확인 소스만")]
  end

  ATT -.->|"키 탈취 · 타 조직 접근 시도"| EDGE
  BR --> EDGE --> RHX
  RHX --> MASK
  RHX -->|"사용자 세션"| RLS
  RHX -->|"service_role"| VAULT
  RHX --> SIGN2 --> FAS
  FAS --> ADV2
  FAS --> OSSG
  FAS --> COMG
  WK2 -.->|"복호화는 메모리에서만"| VAULT
  WK2 --> BRKY
  WK2 --> DARTY
  RLS --- CHK
  RHX --> AUD
  BR -->|"60초 1회용 토큰 SSE"| WK2
```

**위협과 대응 요약** (문서에 있는 것만; 번호는 리뷰 "높음" 결함 번호)

| 자산·위협 | 대응 | 근거 |
|---|---|---|
| 증권사 키·토큰·계좌번호 유출 (#1) | `encrypted_credentials`만 사용, 계좌번호는 마스킹과 HMAC만, 로그 마스킹, 사용자 SELECT 불가 | 05_DATA_MODEL 7장, SECURITY_BASELINE §5 |
| 주문 범위 확대·실전 주문 (#2) | MVP·P2는 조회 전용, `order_requests.env='paper'` CHECK, 사람 확인 60초, 킬 스위치 | 05_DATA_MODEL 7장, 01_PRD 3.3절 |
| 투자 권유·가격 제시 (#3) | 서버 규칙 위험 수준, 가격 키 CHECK, `advice_check` 후 compliance, 실패 시 환불 | 02_ARCHITECTURE 5.3절 |
| 마이데이터 해당·타인 계좌 (#4) | 초대제 + `has_stock_access`, 본인 명의 키만, 스크래핑 영구 제외 | 01_PRD 6.1절 |
| 시세 재배포 (#6) | 공용 피드 없음, 사용자 본인 연결로만 SSE, 틱 비저장 | 02_ARCHITECTURE 6장 |
| 보유 내역의 AI 유출 | 진단 입력은 비율 스냅샷만, 채팅에 수량·금액 미포함 | 02_ARCHITECTURE 2절 AI 경계 |

---

## 문서 불일치

1. **`SECURITY.md` 미작성**: 자산, 위협(T1~), 공통 규칙 제품별 수치(세션 만료, CSP 도메인, 2단계 인증 역할, 감사 보존 등), 외부 서비스 이전 표가 모두 "(작성 필요)"다. 그림 7과 위 요약 표는 `05_DATA_MODEL` 7장, `02_ARCHITECTURE` 2·6장, `01_PRD` 6장에서 가져왔고 SECURITY.md 값이 채워지면 다시 맞춰야 한다. 한편 `01_PRD` 5장은 감사 로그 2년, `order_events` 3년을 이미 적고 있어 SECURITY.md 3절 수치와 맞춰야 한다.
2. **상태 전이의 부분 기재**: `05_DATA_MODEL` 3절은 `ai_reports`에 `queued`, `running`, `succeeded`, `failed`, `canceled`가 나오지만 `succeeded` 이후 전이를 따로 적지 않았다(종료 상태로 그렸다). `beta_invites`의 `expired` 처리 주체는 "만료 처리"로만 쓰여 있고 02_ARCHITECTURE 4절의 "매 1분 초대 만료 처리"를 근거로 연결했다.
3. **GNB와 3.1절 와이어프레임**: `03_SCREENS_UX` 8.7절이 스스로 밝히듯 1절 화면 표와 3.1절 와이어프레임은 8.3절 GNB 정본과 다르다(헤더 상단 내비 → 좌측 GNB, 채팅 패널은 헤더 버튼). 그림 6은 1절 경로 기준이고 GNB 배치는 그리지 않았다. 결정 대기 D-24~D-27(Phase 2·3 메뉴, 운영자 셸, 설정 위치, 색)은 미정이다.

## 갱신 규칙

`01_PRD`, `02_ARCHITECTURE`, `03_SCREENS_UX`, `04_API`, `05_DATA_MODEL`, `SECURITY.md` 중 하나를 고치면 해당 그림(위 표의 근거 절)도 같은 변경에서 함께 고친다. 수정 뒤에는 Mermaid 검증을 다시 돌린다.
