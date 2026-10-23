# ARCHITECTURE_DIAGRAMS: 전체 구조 UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid).

표기: **실선 화살표** = 호출·데이터 흐름, **점선** = 검증·참조, "(제안)" = 확정 전 값. 같은 내용을 웹으로 본 페이지(목차, 읽는 법 포함)는 Claude 아티팩트로 게시했습니다: https://claude.ai/artifact/V1wKjsX2wAcdpbESxsyMUK (비공개, 공유 설정 필요).

| # | 그림 | UML 종류 | 누구에게 필요한가 | 근거 문서 |
|---|---|---|---|---|
| 1 | 시스템 컨텍스트 | 유스케이스/컨텍스트 | 전원 | `CORE_SPEC.md`, `AI_ARCHITECTURE.md` |
| 2 | 구성요소 구조 | 컴포넌트 | 개발·운영 | `AI_ARCHITECTURE.md` 1절, `CORE_SPEC.md` |
| 3 | 배포 구조 | 배치(Deployment) | 개발·운영·보안 | `_supabase-modular/ARCHITECTURE.md`, 제품 02 |
| 4 | 제품 지도와 공유 모듈 | 패키지 | 기획·경영 | `products/README.md`, `SHARED_MODULES.md` |
| 5 | 코어 데이터 모델 | 클래스(개념) | 개발·법무 | `_supabase-modular/migrations/` |
| 6 | 로그인과 콜백 | 시퀀스 | 개발·보안 | `AUTH_ROADMAP.md` 3.2절 |
| 7 | 크레딧 선차감과 잡 | 시퀀스 | 개발·운영 | `CORE_SPEC.md` 4.3절 |
| 8 | 결제 확인 | 시퀀스 | 개발·보안·법무 | `CORE_SPEC.md` 5.2절 |
| 9 | AI 채팅 | 시퀀스 | 개발·보안 | `AI_ARCHITECTURE.md` 2절 |
| 10 | 잡·인증 단계·Stay 상태 | 상태 머신 | 개발·기획 | `CORE_SPEC.md` 9절, `AUTH_ROADMAP.md`, `airbnb/05_DATA_MODEL.md` |
| 11 | 보안 신뢰 경계 | 배치+흐름 | 보안·경영·법무 | `SECURITY_BASELINE.md` |
| 12 | 보안 통제 지도 | 블록 | 전원 | `SECURITY_BASELINE.md` 1~22장 |

## 1. 시스템 컨텍스트: 누가 무엇을 쓰는가

```mermaid
flowchart LR
  V(["방문자<br/>(비로그인)"])
  M(["회원<br/>(게스트·독자·구매자)"])
  H(["제작자·호스트·셀러<br/>(조직 owner/admin)"])
  A(["기관 직원<br/>(ERP·HMS·SMS)"])
  O(["플랫폼 운영자<br/>(platform_admin)"])

  subgraph PL["NOMAD 플랫폼 (제품 17개)"]
    direction TB
    P["제품 웹앱<br/>Next.js"]
    C["공통 코어<br/>인증·조직·크레딧·결제·잡·감사"]
    AI["AI 계층<br/>RAG·LangGraph·Dify·음성"]
  end

  V -->|"둘러보기·검색·챗봇 맛보기"| P
  M -->|"가입·예약·구매·생성"| P
  H -->|"등록·발행·업로드·정산"| P
  A -->|"업무·진료·출결"| P
  O -->|"조회·환불·정지"| P
  P --> C
  P --> AI

  PAY[("Toss Payments")]
  MAP[("지도·날씨·환율")]
  MKT[("쿠팡·스마트스토어<br/>SNS·서점")]
  MAIL[("이메일 발송")]
  LLM[("상용 LLM·음성")]
  C --- PAY
  P --- MAP
  P --- MKT
  P --- MAIL
  AI --- LLM
```

## 2. 구성요소: 한 요청이 지나가는 길

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["화면·채팅 위젯<br/>(Dify·FastAPI·LLM 직접 호출 금지)"]
  end

  subgraph WEB["제품 웹 서버 (Next.js, Vercel)"]
    SA["Server Action<br/>Route Handler"]
    GATE["AI 게이트 /api/ai/*<br/>인증·엔타이틀먼트·크레딧·서명 토큰"]
    MW["proxy.ts<br/>세션·헤더·레이트 리밋"]
  end

  subgraph DB["Supabase (ap-northeast-2)"]
    AUTH["Auth"]
    CORE["core 스키마<br/>조직·크레딧·결제·잡·감사"]
    PROD["제품 스키마<br/>stay·astro·commerce …"]
    VEC["pgvector<br/>ai_chunks"]
    ST["Storage"]
    RT["Realtime<br/>(잡 진행률)"]
  end

  subgraph WK["워커"]
    Q["BullMQ 오케스트레이터<br/>(TS)"]
    PY["미디어·렌더 처리<br/>(Python·FFmpeg·WeasyPrint)"]
  end

  subgraph AIL["AI 서비스"]
    DIFY["Dify<br/>(공용 자체 호스팅)"]
    FAPI["FastAPI<br/>라우터·RAG·그래프·도구"]
    LLMC["상용 LLM"]
    LLMO["오픈소스 LLM<br/>(vLLM)"]
  end

  PAYX["Toss Payments"]

  UI --> MW --> SA
  UI --> GATE
  SA -->|"사용자 세션 + RLS"| DB
  SA -->|"service_role (서버만)"| CORE
  GATE -->|"대화 매핑 기록"| CORE
  GATE -->|"user + 대화 id"| DIFY
  GATE -->|"EdDSA 서명 토큰"| FAPI
  DIFY -->|"내부 키 + 대화 id"| FAPI
  FAPI --> VEC
  FAPI --> LLMC
  FAPI --> LLMO
  SA -->|"enqueue_job"| CORE
  Q -->|"claim · heartbeat · complete"| CORE
  Q --> PY
  PY --> ST
  RT -.->|"RLS 하에서 구독"| UI
  SA <-->|"승인 확인·웹훅"| PAYX
  AUTH -.-> MW
```

## 3. 배포 구조: 어디에 무엇이 놓이는가

```mermaid
flowchart TB
  subgraph NET["인터넷"]
    BR["브라우저"]
  end

  subgraph VER["Vercel (icn1)"]
    W1["제품 웹앱 × N<br/>(제품별 배포)"]
  end

  subgraph SUP["Supabase (ap-northeast-2)"]
    subgraph MOD["모듈러 프로젝트 1개 (기본값)"]
      K["core"]
      S1["stay"]
      S2["astro"]
      S3["commerce · video · publishing · …"]
    end
    subgraph MONO["모놀리스 (제품별 단독 프로젝트)"]
      HMS["admin-suite HMS (의료, 강제)"]
      STK["stock-dashboard (개인용)"]
    end
  end

  subgraph RWY["Railway (제안)"]
    FA["FastAPI AI 서비스"]
    WRK["잡 워커"]
  end

  subgraph SELF["자체 호스팅 (제안)"]
    DF["Dify (공용, HMS 제외)"]
    GPU["공용 GPU: vLLM"]
    HMSX["HMS 전용: hms-llm · hms-embed · hms-voice"]
  end

  subgraph EXT["외부 SaaS"]
    TOSS["Toss"]
    GM["지도·OpenWeather"]
    RES["Resend"]
    CLOUD["상용 LLM·음성"]
  end

  BR --> W1
  W1 --> MOD
  W1 -.-> MONO
  W1 --> FA
  W1 --> DF
  FA --> MOD
  FA --> GPU
  FA --> CLOUD
  WRK --> MOD
  DF --> FA
  HMS --- HMSX
  W1 --> TOSS
  W1 --> GM
  W1 --> RES
```

> 선택 기준: 기본은 모듈러(계정·크레딧 지갑 공유, 코어 보안 코드 한 번만 수정). 의료정보(HMS)와 개인용 증권 키(stock-dashboard)는 격리가 필요해 모놀리스. 코어 변경은 전 제품 RLS/RPC 회귀 테스트를 통과해야 적용.

## 4. 제품 지도와 공유 모듈

```mermaid
flowchart LR
  subgraph CORE["공통 (_platform-core · _supabase-modular · _design-guide)"]
    K1["core 스키마<br/>인증·조직·크레딧·결제"]
    K2["AI 계층 · 음성 · 위키"]
    K3["보안 기준 · 반응형 기준"]
  end

  subgraph PUB["출판·문서"]
    FL["flora-publishing<br/>PDF 렌더(WeasyPrint) 소유"]
    ND["nomad-docs"]
    BT["book-trailer"]
    SN["study-note"]
  end

  subgraph VID["영상·콘텐츠"]
    SF["sceneflow<br/>SNS 업로더·렌더 워커 소유"]
    NB["nomad-blog"]
    TF["toon-factory"]
  end

  subgraph BIZ["커머스·서비스"]
    CM["nomad-commerce"]
    ST["Stay (airbnb)"]
    LN["local-news"]
    MW["microweb-studio"]
    WF["website-floria"]
    LP["live-poll"]
  end

  subgraph OPS["운영·특수"]
    AD["admin-suite<br/>ERP · SMS (모듈러) / HMS (모놀리스)"]
    AS["astro-ai<br/>생년월일시 암호화"]
    AR["arch-studio (설치형)"]
    SD["stock-dashboard (모놀리스)"]
  end

  PUB --> CORE
  VID --> CORE
  BIZ --> CORE
  OPS --> CORE

  AS -. "PDF 렌더" .-> FL
  CM -. "SNS 업로드" .-> SF
  TF -. "렌더 워커" .-> SF
  BT -. "원고 가져오기" .-> FL
  BT -. "영상 파이프라인" .-> SF
  ND -. "렌더·AI 공유" .-> FL
```

## 5. 코어 데이터 모델 (개념도, 대표 항목만)

```mermaid
classDiagram
  class organizations {
    id
    name
    deleted_at
  }
  class profiles {
    id
    email
    display_name
  }
  class org_members {
    org_id
    user_id
    role
    status
  }
  class apps {
    id
    signup_policy
  }
  class plans {
    id
    app_id
  }
  class subscriptions {
    org_id
    plan_id
    status
  }
  class app_entitlements {
    org_id
    app_id
    status
  }
  class wallets {
    org_id
    balance
  }
  class credit_ledger {
    id
    amount
    reason
    idempotency_key
  }
  class payment_orders {
    id
    kind
    amount_krw
    status
  }
  class payments {
    payment_key
    amount_krw
    approved_at
  }
  class jobs {
    queue
    job_type
    status
    attempts
    credit_ledger_id
  }
  class encrypted_credentials {
    id
    key_version
    ciphertext
  }
  class audit_log {
    actor
    action
    target
  }
  class ai_conversations {
    id
    dify_user
    visitor_key
    status
  }
  class ai_messages {
    conversation_id
    role
  }
  class ai_usage {
    status
    cost
  }

  profiles "1" --> "*" org_members
  organizations "1" --> "*" org_members
  organizations "1" --> "*" app_entitlements
  apps "1" --> "*" app_entitlements
  apps "1" --> "*" plans
  organizations "1" --> "*" subscriptions
  plans "1" --> "*" subscriptions
  organizations "1" --> "1" wallets
  wallets "1" --> "*" credit_ledger
  organizations "1" --> "*" payment_orders
  payment_orders "1" --> "0..1" payments
  credit_ledger "1" --> "0..1" jobs
  organizations "1" --> "*" encrypted_credentials
  organizations "1" --> "*" audit_log
  organizations "1" --> "*" ai_conversations
  ai_conversations "1" --> "*" ai_messages
  ai_conversations "1" --> "*" ai_usage
```

> 모든 제품 테이블은 `org_id`로 이 코어에 묶이고, 접근은 RLS가 `org_members`로 판정합니다. 열 이름은 이해를 위한 대표값이며 정확한 정의는 `_supabase-modular/migrations/`입니다.

## 6. 로그인과 콜백 (인증 단계 공통)

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자
  participant W as 제품 웹(Next.js)
  participant G as 로그인 제공자<br/>(Mock·Google·카카오·네이버)
  participant A as Supabase Auth
  participant D as core(DB)

  U->>W: 로그인 시작
  W->>G: 인증 요청 (PKCE)
  G-->>W: /auth/callback?code
  W->>A: exchangeCodeForSession(code)
  A-->>W: 세션(JWT)
  W->>D: session_context(app)
  alt 프로필 없음
    W-->>U: 로그아웃 후 /login (기본 admin 금지)
  else 엔타이틀먼트 없음
    W->>D: bootstrap_app_for_org (1회)
  end
  alt 상태 pending
    W-->>U: /pending 안내
  else 상태 suspended
    W-->>U: 403
  else 정상
    W->>D: 감사 auth.login (토큰·코드 제외)
    W-->>U: next 경로로 이동 (`/`로 시작, `//`·`@`·`\` 금지)
  end
```

## 7. 크레딧 선차감과 잡 처리

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자
  participant W as 웹 서버
  participant D as core(DB)
  participant K as 워커

  U->>W: 생성 요청 (request id)
  W->>D: session_context 로 엔타이틀먼트 확인
  alt 플랜에 없는 기능
    W-->>U: 403
  end
  W->>D: consume_credits (멱등 키)
  alt 잔액 부족 (CR001)
    W-->>U: 402, 잡 생성 안 함
  end
  W->>D: enqueue_job (credit_ledger_id 연결)
  W-->>U: 접수됨 (진행률은 Realtime 구독)
  K->>D: claim_jobs (SKIP LOCKED)
  loop 60초 이하 간격
    K->>D: heartbeat_job (진행률)
  end
  alt 성공
    K->>D: complete_job
  else 실패
    K->>D: fail_job
    D->>D: 마지막 실패에서 refund_credits 자동 호출
  end
```

## 8. 결제 확인 (Toss 일반결제)

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자
  participant W as 웹 서버
  participant T as Toss
  participant D as core(DB)

  W->>D: payment_orders 생성 (금액은 plans·credit_packs에서 읽음)
  U->>T: 결제창 (orderId, amount)
  T-->>U: successUrl (paymentKey, orderId, amount)
  U->>W: successUrl 도착
  W->>T: confirm API (서버 시크릿 키)
  T-->>W: 승인 결과
  W->>D: confirm_payment_order (주문 잠금 → 금액 대조 → 지급, 한 트랜잭션)
  alt 금액 불일치 (PM001)
    D-->>W: 오류, 지급 없음
  else 성공
    D-->>W: 크레딧 지급 또는 구독 엔타이틀먼트
  end
  T-)W: 웹훅 (서명 검증, 멱등)
  Note over W,D: 웹훅은 상태 동기화만. 지급은 confirm 경로가 정본
```

## 9. AI 채팅 (Dify 경유, 조직 격리)

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자 또는 방문자
  participant W as Next.js /api/ai/*
  participant D as core(DB)
  participant F as Dify Chatflow
  participant P as FastAPI

  U->>W: 메시지 (대화 id)
  W->>W: 인증, 레이트 리밋, 대화 주인 확인 (방문자는 서명 쿠키 해시)
  W->>D: 첫 턴이면 ai_conversations 기록 (org, app, user, dify_user)
  W->>D: consume_credits (필요 시)
  W->>F: user=dify_user, platform_conversation_id
  F->>P: HTTP 노드: 내부 키 + 대화 id + sys.user
  P->>D: 대화 존재·active·dify_user 일치·app 일치 확인
  P->>P: 그 행의 org·user로만 RAG 검색 (본문의 org 값 무시)
  P-->>F: 근거 조각 + 출처
  F-->>W: 응답 스트림
  W-->>U: 답변 + 출처 (프롬프트 전문·토큰은 로그에 남기지 않음)
  Note over W,P: 서명 토큰 경로(EdDSA, 수명 10분 제안): Next.js가 개인키로 서명, FastAPI는 공개키로 검증만
```

## 10. 상태 머신

### 10.1 잡 (`core.jobs`)

```mermaid
stateDiagram-v2
  [*] --> queued: enqueue_job
  queued --> running: claim_jobs
  running --> running: heartbeat_job
  running --> succeeded: complete_job
  running --> queued: fail_job (재시도 가능, 지수 백오프)
  running --> failed: 재시도 소진 또는 불가 (자동 환불)
  running --> queued: reap_stale_jobs (하트비트 끊김)
  queued --> canceled: cancel_job (환불 포함)
  succeeded --> [*]
  failed --> [*]
  canceled --> [*]
```

### 10.2 인증 단계 (`AUTH_ROADMAP`)

```mermaid
stateDiagram-v2
  [*] --> StageA: 개발
  StageA: A. Mock 로그인 (로컬 시드 계정, 실제 JWT)
  StageB: B. Google OAuth
  StageC: C. 카카오(C1) · 네이버(C2)
  StageA --> StageB: 게이트 G1
  StageB --> StageC: 게이트 G2
  StageC --> [*]
  note right of StageA
    운영 환경에서는 거부.
    isMockAuthAllowed() 가 거짓이면 기동 실패
  end note
```

### 10.3 Stay 예약과 숙소

```mermaid
stateDiagram-v2
  direction LR
  state "예약" as R {
    [*] --> requested
    requested --> confirmed: 호스트 승인
    requested --> declined: 호스트 거절
    requested --> expired: 24시간 경과
    requested --> canceled_by_guest: 게스트 취소
    confirmed --> canceled_by_guest: 체크인 전날까지
    confirmed --> canceled_by_host: 사유 필수
    confirmed --> completed: 체크아웃 후
  }
  state "숙소" as L {
    [*] --> draft
    draft --> published: 게시 조건 통과
    published --> unlisted
    unlisted --> published
    draft --> suspended: 운영자
    published --> suspended: 운영자
    unlisted --> suspended: 운영자
  }
```

> `listing_private`(정확한 주소·좌표·체크인 안내)는 예약이 `confirmed` 이후에만 게스트에게 열립니다. `requested` 상태의 게스트는 0행을 봅니다.

## 11. 보안 신뢰 경계

```mermaid
flowchart TB
  subgraph Z0["① 신뢰하지 않는 영역"]
    B["브라우저·봇·공격자"]
  end

  subgraph Z1["② 입구 (Vercel)"]
    H["보안 헤더·CSP·HSTS<br/>§18"]
    RL["레이트 리밋·봇 방어<br/>§8, §21"]
    SS["세션·쿠키 검증<br/>HttpOnly·Secure·SameSite"]
  end

  subgraph Z2["③ 앱 서버 (신뢰)"]
    AZ["권한 판정은 서버에서<br/>§11"]
    VAL["입력 검증(zod)·sanitize<br/>§10"]
    TK["서명 토큰 발급 (개인키 보관)<br/>§16"]
    SEC["비밀은 서버 환경변수만<br/>§19"]
  end

  subgraph Z3["④ 데이터 (최종 방어선)"]
    RLS["RLS + SECURITY DEFINER 허용 목록<br/>§1~4"]
    ENC["암호화 자격증명·민감 컬럼<br/>§5, §12"]
    AUD["감사 로그<br/>§9, §20"]
  end

  subgraph Z4["⑤ AI·외부 (제한 신뢰)"]
    FP["FastAPI: 공개키 검증, org는 서버 기록값만<br/>§16"]
    DF["Dify: 내부 키·대화 매핑, 토큰 전달 금지"]
    WH["웹훅: 서명 검증 + 멱등<br/>§6"]
  end

  subgraph Z5["⑥ 운영"]
    OPS["백업·복구 훈련·모니터링·사고 대응<br/>§20"]
    SCAN["시크릿·의존성 스캔<br/>§19"]
  end

  B -->|"모든 요청"| Z1
  Z1 --> Z2
  Z2 -->|"사용자 세션"| RLS
  Z2 -->|"service_role (서버만)"| RLS
  Z2 --> FP
  Z2 --> DF
  WH --> Z2
  RLS --> ENC
  RLS --> AUD
  OPS -.-> Z3
  SCAN -.-> Z2
```

## 12. 보안 통제 지도: 위협 → 통제

```mermaid
flowchart LR
  subgraph T["주요 위협"]
    T1["남의 조직 데이터 접근"]
    T2["키·비밀 유출"]
    T3["결제 금액 조작·중복 지급"]
    T4["봇·비용 폭증"]
    T5["AI 프롬프트 인젝션·타 조직 조회"]
    T6["계정 탈취·피싱"]
    T7["개인정보·의료정보 유출"]
    T8["개발용 우회가 운영에 남음"]
    T9["사고 후 복구 불가"]
  end

  subgraph C["통제 (SECURITY_BASELINE)"]
    C1["RLS·함수 권한 허용 목록·복합 외래키<br/>§1~4, §15, §16"]
    C2["encrypted_credentials·서버 환경변수·시크릿 스캔<br/>§5, §19"]
    C3["서버 confirm·금액 대조·멱등·웹훅 서명<br/>§6, CORE 5절"]
    C4["레이트 리밋·캡차·일일 상한<br/>§8, §21"]
    C5["서명 토큰·대화 매핑·자료는 자료로만<br/>§16"]
    C6["2단계 인증·이상 로그인 알림·재인증<br/>§17, §18, §21"]
    C7["컬럼 암호화·전용 서버·삭제 절차·국외 이전 고지<br/>§12, §16"]
    C8["Mock 가드·배포 빌드 404 검사<br/>§17"]
    C9["백업·복구 훈련·알림·사고 대응<br/>§20"]
  end

  T1 --> C1
  T2 --> C2
  T3 --> C3
  T4 --> C4
  T5 --> C5
  T6 --> C6
  T7 --> C7
  T8 --> C8
  T9 --> C9
```

## 갱신 규칙

- 구조가 바뀌는 문서(`CORE_SPEC`, `AI_ARCHITECTURE`, `AUTH_ROADMAP`, `SECURITY_BASELINE`, 제품 02·05)를 고치면 이 파일의 해당 그림도 같은 커밋에서 고친다.
- 새 제품은 4번 그림에 넣고, 보안 통제가 늘면 12번에 한 줄을 추가한다.
- 그림은 개요다. 열 이름, 수치, 예외는 정본 문서를 따른다.
