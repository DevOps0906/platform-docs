# 신비로운AI (astro-ai) UML 다이어그램

작성일 2026-10-23. 제품 한 줄 정의: 만세력 엔진이 결정적으로 계산한 사주 원국과 사용자가 뽑은 타로 3장을 AI가 해설해, 본인과 가족·지인의 리포트를 A4 책자형 PDF로 소장하게 하고 이메일과 대시보드로 전달하는 크레딧팩 결제형 SaaS입니다(`README.md` 1절).

근거 문서: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`, `MCP.md`, 공통 맥락은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. 문서끼리 어긋난 곳은 파일 끝 "문서 불일치"에 적었습니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid).

표기: **실선 화살표** = 호출·데이터 흐름, **점선** = 검증·참조·구독, "(제안)" = 문서가 제안값이라고 밝힌 것. 기능 ID(AS-F-###)는 `01_PRD.md` 3절의 ID입니다.

06_AGENT_PLAN.md(작업 계획)와 07_SOURCE_MIGRATION.md(원본 이관)는 제품 구조가 아니라 개발 작업 관리 문서라 그림에서 뺐습니다.

| 번호 | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-1 | 사용자와 기능: 방문자·회원 (MVP) | 유스케이스 관점 flowchart | `01_PRD` 2절, 3절 |
| 1-2 | 운영자 기능과 Phase 구분 | 유스케이스 관점 flowchart | `01_PRD` 2절, 3절, `02` 9절 |
| 2-1 | 구성요소: 웹·워커·AI·외부 서비스 | 컴포넌트 | `02` 결정표, 2절, 4절, 7절 |
| 2-2 | 구성요소: AI 계층 상세 | 컴포넌트 | `02` 5절, `04` 6.1절, 6.2절 |
| 3-1 | 데이터 모델 | 클래스 | `05` 1절, 2절, 4절, 6절 |
| 4-1 | 리딩 생성 (AS-F-009~012, 018, 029) | 시퀀스 | `02` 4절, `04` 2절, 4절 |
| 4-2 | 크레딧팩 결제 (AS-F-019) | 시퀀스 | `04` 2절, 5절, `03` 2.4절 |
| 4-3 | AI 채팅 (AS-F-032, 036) | 시퀀스 | `04` 2.1절, 6.2절, `03` 2.6절 |
| 4-4 | 이메일 발송 outbox (AS-F-017) | 시퀀스 | `05` 3.3절, `04` 3절 |
| 5-1 | 리딩 상태 `readings.status` | 상태 머신 | `05` 3.1절 |
| 5-2 | 렌더 상태 `reading_renders.status` | 상태 머신 | `05` 3.2절 |
| 5-3 | 발송 상태 `deliveries.status` | 상태 머신 | `05` 3.3절 |
| 6-1 | 화면 흐름: 공개·가입·온보딩 | flowchart | `03` 1절, 2.1절, 7절 |
| 6-2 | 화면 흐름: 대시보드와 어드민 | flowchart | `03` 1절, 2.2~2.4절, 8절 |
| 7-1 | 보안 경계 | flowchart (신뢰 경계) | `SECURITY.md` 1~2절, `SECURITY_BASELINE` |
| 8-1 | API 위에 얹는 MCP 구성 | 컴포넌트(flowchart) | `MCP` 1~3절, `MCP_BASELINE` 1·7절 |
| 8-2 | 리딩 준비와 사람 확정 | 시퀀스 | `MCP` 2·6절, `04` 2절 |
| 8-3 | 도구 위험 등급과 노출 단계 | flowchart | `MCP` 2절, `MCP_BASELINE` 2절 |

## 1. 사용자와 기능

### 그림 1-1. 방문자와 회원의 MVP 기능

읽는 법: 왼쪽 위 두 사람이 사용자입니다. 방문자는 로그인 없이 랜딩·Live Demo·위키만 쓰고, 회원은 보관함에 대상을 등록한 뒤 리딩을 만들고 PDF로 받습니다. 상자 안 숫자는 크레딧 단가(01장 4.2절)입니다. 모든 상자가 MVP 범위입니다.

```mermaid
flowchart LR
  V(["방문자<br/>비로그인"])
  M(["회원<br/>owner 본인 조직"])

  V --> L["랜딩 + 3D 히어로<br/>AS-F-023, 037"]
  V --> D["Live Demo 키워드 3개<br/>AS-F-024, LLM 없음"]
  V --> W["용어 위키 /wiki<br/>AS-F-031"]

  M --> A1["로그인 + 환영 크레딧 30<br/>AS-F-001, 002"]
  A1 --> A2["AI 처리 방식 동의<br/>AS-F-035"]
  M --> S1["프로필 보관함<br/>AS-F-003"]
  S1 --> S2["제3자 동의 확인<br/>AS-F-004"]
  S1 --> S3["원국 프리뷰 + 대운<br/>AS-F-007, 008"]
  M --> R1["사주 리딩 15<br/>AS-F-009"]
  M --> R2["타로 3카드 20<br/>AS-F-010"]
  M --> R3["통합 리딩 30<br/>AS-F-011"]
  R1 --> P1["A4 PDF + 테마 2종<br/>AS-F-013, 014"]
  R2 --> P1
  R3 --> P1
  P1 --> E1["이메일 발송 서명 URL<br/>AS-F-017"]
  P1 --> P2["테마 변경 재생성 5<br/>AS-F-015"]
  P1 --> P3["PDF 재다운로드 무료<br/>AS-F-016"]
  P1 --> AI3["리딩 낭독 TTS<br/>AS-F-034"]
  M --> C1["크레딧팩 4종 Toss<br/>AS-F-019"]
  M --> AI1["AI 채팅 선차감 3<br/>AS-F-032"]
  AI1 --> AI2["음성 대화 STT TTS<br/>AS-F-033"]
  M --> X["내보내기 + 탈퇴<br/>AS-F-027"]
```

### 그림 1-2. 운영자 기능, 로그인 단계, Phase 구분

읽는 법: 위쪽은 `platform_admin`만 쓰는 최소 어드민과 지식 관리(MVP)입니다. 가운데는 로그인 수단이 켜지는 순서, 아래쪽은 MVP에 들어가지 않는 Phase 2와 폐기 항목입니다. 구분은 `01_PRD.md` 2절 표 그대로입니다.

```mermaid
flowchart TB
  O(["platform_admin<br/>운영자"])

  subgraph OPS["MVP 운영자 기능"]
    U["유저 조회 + 크레딧 지급<br/>사유 필수, AS-F-022"]
    RF["결제 환불<br/>사유 필수, AS-F-020"]
    DM["발송 모니터 + 강제 재발송<br/>AS-F-022"]
    K["해설집 업로드 + 색인<br/>AS-F-030"]
    WK["위키 검수 + 게시<br/>AS-F-031"]
  end

  O --> U
  O --> RF
  O --> DM
  O --> K
  K --> WK

  subgraph AUTHS["로그인 단계 (확정 결정 22)"]
    SA["Stage A Mock<br/>로컬 시드 계정, MVP 개발"]
    SB["Stage B Google + 이메일<br/>P0, 공개 베타 전"]
    SC1["Stage C1 카카오 P1"]
    SC2["Stage C2 네이버 P1"]
  end

  SA --> SB --> SC1
  SB --> SC2

  subgraph PH2["Phase 2"]
    Q1["비회원 AI 상담"]
    Q2["보이스 선택 + 클로닝"]
    Q3["구독 플랜 + 빌링키<br/>연간 20% 할인"]
    Q4["궁합 2인 + 연간 운세"]
    Q5["카카오 알림톡"]
    Q6["ePub"]
  end

  subgraph OUT["Phase 3 이후 또는 폐기"]
    N1["마켓플레이스<br/>크리에이터 대시보드"]
    N2["멀티버티컬 기업 API 다국어"]
  end
```

## 2. 구성요소

### 그림 2-1. 웹·워커·AI·외부 서비스

읽는 법: 위에서 아래로 사용자 요청이 내려갑니다. 읽기는 브라우저가 RLS로 직접 하고, 쓰기는 Route Handler와 워커만 service_role로 합니다. LLM 키는 FastAPI에만 있고 워커와 Vercel에는 없습니다(`02` 결정표). 점선은 구독입니다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["대시보드 + 채팅 위젯<br/>3D 히어로"]
    ENG["saju-engine<br/>원국 프리뷰, 입력은 서버로 안 감"]
  end

  subgraph WEB["apps/astro-ai Next.js, Vercel"]
    MW["requireSession astro<br/>zod 검증, 레이트 리밋"]
    RH["Route Handler<br/>readings, billing, subjects"]
    GATE["AI 게이트<br/>/api/ai, /api/voice<br/>서명 토큰, 선차감, 정산"]
    INT["/api/internal<br/>ai-token, ai-settle"]
  end

  subgraph RWY["Railway"]
    WRK["astro-worker TS<br/>생성, 렌더, purge<br/>발송 루프, 스위퍼"]
    API["FastAPI apps/api<br/>그래프, RAG, 위키, 라우터"]
    RND["render-weasyprint<br/>공용 PDF 서비스"]
  end

  subgraph SUP["Supabase"]
    CORE["core<br/>크레딧, 잡, 결제, 감사<br/>ai_runs, ai_usage"]
    AST["astro 스키마<br/>테이블 7개"]
    STO["Storage exports<br/>PDF, 낭독 mp3"]
    RT["Realtime<br/>readings 변경"]
  end

  DIFY["Dify 공용<br/>astro-chat"]
  GPU["공용 GPU 서버<br/>oss-llm, oss-embed, oss-voice"]
  LLMC["상용 LLM"]
  EL["ElevenLabs"]
  TOSS["Toss Payments"]
  RS["Resend 이메일"]

  UI --> MW --> RH
  UI --> GATE
  ENG -.-> UI
  RH -->|"사용자 세션 + RLS"| AST
  RH -->|"service_role: consume_credits, enqueue_job"| CORE
  RH <--> TOSS
  GATE --> DIFY
  GATE -->|"EdDSA 서명 토큰"| API
  GATE --> EL
  GATE --> GPU
  DIFY -->|"내부 키 + 대화 id"| API
  WRK -->|"claim, heartbeat, complete"| CORE
  WRK -->|"워커 키 + job id"| INT
  WRK -->|"잡 토큰"| API
  WRK --> RND --> STO
  WRK --> RS
  API --> CORE
  API --> GPU
  API --> LLMC
  RT -.->|"RLS 하에서 구독"| UI
```

### 그림 2-2. AI 계층 상세

읽는 법: 오른쪽 위 그래프 `astro.reading`이 리딩 본문을 만들고, 채팅과 위키는 그래프가 아니라 FastAPI 도구 경로(`/tools/*`)로 갑니다. 그래프의 `chart` 노드는 TS 엔진이 저장한 값을 읽기만 하고 LLM을 쓰지 않습니다. 점선은 `compliance`에서 걸린 장만 1회 다시 쓰는 경로입니다.

```mermaid
flowchart LR
  subgraph NX["Next.js"]
    GATE["/api/ai/chat<br/>AI 게이트"]
    VOICE["/api/voice/*<br/>core-voice"]
    ADM["/api/admin/knowledge, wiki<br/>platform_admin"]
    TKN["/api/internal/ai-token<br/>잡 토큰 발급"]
  end

  WRK["astro-worker<br/>handlers/generate.ts"]
  DIFY["Dify Chatflow<br/>astro-chat"]

  subgraph FA["FastAPI apps/api"]
    T1["/tools/answer<br/>모드 saju"]
    T2["/tools/answer-direct<br/>Dify 장애 시"]
    DR["/dify/retrieval<br/>외부 지식 API"]
    GR["/graphs/astro.reading/runs"]
    ING["/rag/ingest<br/>/wiki/ingest, lint"]
    RO["라우터 resolve_ai_route<br/>기능별 체인"]
  end

  subgraph GRAPH["그래프 astro.reading"]
    G1["chart<br/>LLM 없음"] --> G2["retrieve<br/>해설집 검색"] --> G3["draft<br/>장별 초안"] --> G4["compliance<br/>규칙 검사"] --> G5["assemble<br/>책자 섹션"]
    G4 -.->|"걸린 장 1회"| G3
  end

  subgraph DATA["core 테이블"]
    CH["ai_chunks<br/>astro-knowledge, astro-wiki"]
    WP["wiki_pages"]
    RN["ai_runs, ai_run_steps<br/>ai_usage"]
    CV["ai_conversations<br/>ai_messages"]
  end

  LLMC["상용 LLM"]
  OSS["oss-llm, oss-embed, oss-voice"]

  GATE --> DIFY
  GATE -.->|"Dify 5xx 또는 10초 무응답"| T2
  DIFY -->|"X-Internal-Key"| T1
  DIFY --> DR
  WRK --> TKN
  WRK -->|"잡 토큰"| GR --> G1
  G2 --> CH
  T1 --> CH
  T1 --> WP
  T1 --> CV
  T2 --> CH
  DR --> CH
  GR --> RN
  G3 --> RO
  T1 --> RO
  RO --> LLMC
  RO --> OSS
  ADM --> ING --> CH
  ING --> WP
  VOICE --> OSS
```

## 3. 데이터 모델

### 그림 3-1. `astro` 스키마 7개 테이블과 코어 참조 3개

읽는 법: 선은 FK(포함·참조)입니다. 제품 테이블 7개(themes, subjects, readings, reading_renders, deliveries, consents, preferences)와 참조만 하는 코어 테이블 3개를 그렸습니다. 모든 제품 테이블은 `org_id` 복합 FK로 다른 조직 행 참조를 DB가 거부합니다. 각 상자 아래 note가 RLS와 쓰기 주체입니다. AI·음성 테이블은 코어 것을 쓰고 제품 AI 표는 없습니다(`05` 6절).

```mermaid
classDiagram
  class organizations {
    uuid id
  }
  class credit_ledger {
    bigint id
  }
  class jobs {
    uuid id
  }
  class themes {
    text key
    jsonb config
    text tier
    boolean is_active
  }
  class subjects {
    uuid id
    uuid org_id
    text alias
    text relation
    text gender
    text calendar_type
    boolean is_leap_month
    boolean birth_time_unknown
    text zi_hour_mode
    text name_ciphertext
    text birth_ciphertext
    timestamptz third_party_consent_at
  }
  class readings {
    uuid id
    uuid org_id
    uuid subject_id
    text kind
    text theme_key
    jsonb tarot_cards
    jsonb chart
    text engine_version
    text status
    smallint progress
    int credits_charged
    bigint credit_ledger_id
    uuid job_id
    uuid request_id
    jsonb content
    uuid current_render_id
  }
  class reading_renders {
    uuid id
    uuid reading_id
    text theme_key
    boolean is_initial
    text status
    text pdf_path
    int credits_charged
  }
  class deliveries {
    bigint id
    uuid render_id
    text channel
    text status
    int attempts
    int max_attempts
    timestamptz next_attempt_at
    text recipient_ciphertext
  }
  class consents {
    bigint id
    uuid org_id
    uuid user_id
    uuid subject_id
    text kind
    text version
    boolean granted
  }
  class preferences {
    uuid org_id
    text default_theme_key
    boolean email_delivery_enabled
  }

  organizations "1" --> "*" subjects : org_id cascade
  organizations "1" --> "0..1" preferences : 1대1
  subjects "1" --> "*" readings : 복합 FK cascade
  readings "1" --> "*" reading_renders : 복합 FK cascade
  reading_renders "1" --> "*" deliveries : 복합 FK cascade
  subjects "1" --> "*" consents : set null
  themes "1" --> "*" readings : theme_key
  themes "1" --> "*" reading_renders : theme_key
  themes "1" --> "*" preferences : default_theme_key
  readings --> credit_ledger : 불변 참조
  readings --> jobs : set null

  note for subjects "SELECT: is_org_member + has_entitlement astro. 암호문 2개 컬럼은 GRANT 제외. 쓰기: service_role만"
  note for readings "SELECT 같음. question_ciphertext key_version credit_ledger_id 제외. 쓰기: Route Handler와 워커만. 전이 트리거 AS001"
  note for reading_renders "SELECT 멤버. 쓰기 service_role만. 전이 트리거"
  note for deliveries "SELECT 멤버. 암호문 제외. 쓰기: 워커 RPC claim_due_deliveries finish_delivery"
  note for consents "SELECT is_org_member. append 전용. 철회는 granted false 새 행"
  note for preferences "유일하게 멤버 직접 쓰기 허용. 권한 과금 상태 컬럼 없음"
  note for themes "전역 참조 데이터. is_active 행은 anon도 SELECT"
```

## 4. 핵심 시퀀스

### 그림 4-1. 리딩 생성 (AS-F-009~012, 018, 029)

읽는 법: 위쪽은 Route Handler가 검증·차감·잡 생성까지 한 번에 하고 202로 돌려보내는 구간, 아래쪽은 워커가 그래프를 부르고 PDF를 만드는 구간입니다. 검증·권한은 `requireSession`, 레이트 리밋, 멱등은 `request_id`, 크레딧은 선차감이고 최종 실패 시 `fail_job`이 자동 환불합니다. 상태 이름은 그림 5-1과 같습니다.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant RH as Route Handler
  participant DB as Supabase core+astro
  participant WK as astro-worker
  participant AI as FastAPI 그래프
  participant RS as render-weasyprint

  B->>RH: POST /api/readings + request_id
  RH->>RH: requireSession astro, zod strict, 종류와 테마 확인
  RH->>DB: rate_limit_hit astro:readings 10회/분, 진행 중 3건 이하
  alt 한도 초과
    RH-->>B: 429 + Retry-After
  end
  RH->>DB: 같은 request_id 리딩 조회
  alt 이미 있음
    RH-->>B: 200 기존 리딩 반환 멱등
  end
  RH->>RH: 대상 복호화 후 saju-engine으로 원국 계산
  RH->>DB: consume_credits consume:astro:request_id 15/20/30
  alt CR001 잔액 부족
    RH-->>B: 402 balance와 required
  end
  RH->>DB: INSERT readings queued + reading_renders is_initial
  RH->>DB: enqueue_job job:astro:request_id max_attempts 2
  Note over RH,DB: enqueue 실패 시 refund_credits enqueue_failed 후 500
  RH-->>B: 202 reading_id
  WK->>DB: claim_jobs astro.reading, readings generating
  WK->>RH: POST /api/internal/ai-token 워커 키 + job_id
  RH->>DB: core.jobs 확인 status running, app astro
  RH-->>WK: 잡 토큰 scope graph:astro.reading
  WK->>AI: POST /graphs/astro.reading/runs
  AI->>DB: ai_runs, ai_run_steps 기록 chart retrieve draft compliance assemble
  loop 2초 간격 최대 120초
    WK->>AI: GET /graphs/runs/id
  end
  WK->>WK: 출력 zod 재검증, content 저장
  WK->>DB: readings rendering
  WK->>RS: POST /render/pdf A4, 외부 URL 참조 거부
  RS-->>WK: pdf_path
  WK->>DB: 렌더 succeeded, 리딩 completed, 이메일 켜짐이면 deliveries INSERT
  WK->>DB: complete_job
  opt 그래프 failed 또는 시간 초과 또는 렌더 실패
    WK->>DB: fail_job 자동 환불, readings failed
  end
  DB-->>B: Realtime postgres_changes 진행률, RLS 적용
```

### 그림 4-2. 크레딧팩 결제 (AS-F-019)

읽는 법: 주문을 서버에서 먼저 저장하고 금액은 서버 값만 씁니다. 지급은 성공 URL 뒤 서버 confirm에서만 일어나고 웹훅은 상태 동기화뿐입니다. 같은 결제를 두 번 confirm해도 지급은 1회입니다(멱등). 금액이 다르면 `PM001`로 지급 0.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant RH as Route Handler
  participant DB as Supabase core
  participant T as Toss Payments

  B->>RH: POST /api/billing/orders credit_pack_code
  RH->>DB: payment_orders INSERT, 금액은 credit_packs 서버 값
  RH-->>B: orderId, amount, customerKey, orderName
  B->>T: 결제창에서 결제
  T-->>B: successUrl로 paymentKey, orderId, amount
  B->>RH: POST /api/billing/confirm
  RH->>T: Toss confirm API
  RH->>DB: confirm_payment_order 금액 대조 + 멱등 지급
  alt 금액 불일치 PM001
    RH->>T: 승인 취소 요청, 별도 호출
    RH-->>B: 409 + 운영 알림
  else 정상
    DB-->>RH: 지급 후 잔액
    RH-->>B: balance
  end
  T-)RH: 웹훅 POST /api/webhooks/toss
  RH->>T: paymentKey로 결제 조회 재검증
  RH->>DB: webhook_events 기록, payments.status 동기화만
  Note over RH,DB: 웹훅은 크레딧을 지급하지 않음. 서명 방식은 미확인이라 재조회로 검증
```

### 그림 4-3. AI 채팅 한 턴 (AS-F-032, 036)

읽는 법: 브라우저는 `/api/ai/*`만 부르고 Dify와 FastAPI는 서버끼리 부릅니다. 턴마다 제공자 호출 전에 3크레딧을 선차감하고 끝나면 실제 사용량(1~5)으로 정산해 차액을 환불합니다. 스트림이 끊기면 5분 주기 정산 크론이 처리합니다.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant G as AI 게이트 Next.js
  participant DB as Supabase core
  participant D as Dify astro-chat
  participant F as FastAPI

  B->>G: POST /api/ai/conversations reading_id, channel
  G->>DB: ai_conversations INSERT, dify_user는 HMAC, 리딩은 같은 조직 completed만
  B->>G: POST /api/ai/chat message 1~1000자 + request_id
  G->>G: requireSession, 엔타이틀먼트, 입력 마스킹
  G->>DB: rate_limit_hit 20회/60초와 200회/일
  alt 한도 초과
    G-->>B: 429
  end
  G->>DB: consume_credits 3, 키 conv:id:turn:n
  alt CR001 잔액 부족
    G-->>B: 402 충전 모달
  end
  G->>D: chat-messages user dify_user, platform_conversation_id, reading_id
  D->>F: POST /tools/answer 내부 키, 모드 saju
  F->>DB: 대화 매핑으로 org 확인, 원국 스냅샷, match_ai_chunks
  F->>F: chat 모델 호출 후 compliance 후처리
  F->>DB: ai_messages assistant 행 + citations
  F-->>D: answer, citations, usage
  D-->>G: 스트림
  G-->>B: SSE delta, citations, usage, done
  opt Dify 5xx 또는 10초 무응답
    G->>F: POST /tools/answer-direct 서명 토큰 scope chat rag wiki
    F-->>G: 같은 형식 응답 + 운영 알림
  end
  G->>DB: 정산 실제 1~5, 선차감보다 적으면 refund_credits
  opt 모든 제공자 실패
    G->>DB: 선차감 전액 환불
  end
  Note over G,DB: 연결이 끊기면 ai-settle 크론이 5분마다 settled_at null 행 정산
```

### 그림 4-4. 이메일 발송 outbox와 재발송 (AS-F-017)

읽는 법: 리딩 완료 때 발송 행이 만들어지고, 워커가 30초마다 `claim_due_deliveries`로 집어 갑니다. 실패하면 5분 뒤 재시도, 3회째 실패면 `dead`. 이메일에는 PDF를 붙이지 않고 서명 URL 링크만 보냅니다. 발송 실패는 리딩 성공에 영향이 없습니다.

```mermaid
sequenceDiagram
  participant WK as astro-worker
  participant DB as Supabase astro
  participant RM as Resend
  participant U as 회원 브라우저
  participant RH as Route Handler

  WK->>DB: deliveries INSERT pending, 이메일 끄면 skipped
  loop 30초 주기
    WK->>DB: claim_due_deliveries pending에서 sending, attempts+1, SKIP LOCKED
    WK->>RM: 메일 발송, 서명 URL 링크만
    alt 성공
      WK->>DB: finish_delivery ok, sent
    else 실패이고 attempts 미만 max
      WK->>DB: finish_delivery false, pending + 5분
    else attempts가 max 도달
      WK->>DB: finish_delivery false, dead
    end
  end
  U->>RH: POST /api/deliveries/id/resend
  RH->>DB: rate_limit_hit 일 3회, dead를 pending으로
  Note over RH,DB: 어드민은 POST /api/admin/deliveries/id/retry + 감사 delivery.retry
```

## 5. 상태 머신

### 그림 5-1. `readings.status`

읽는 법: 화살표 옆 글자가 전이를 일으키는 주체입니다. 전이는 BEFORE 트리거가 강제하고 service_role 쓰기에도 적용되어 위반은 `AS001`입니다. `completed`, `failed`, `canceled`는 끝 상태이고 재생성은 `reading_renders`로 합니다. `org_id`, `kind`, `request_id`, `credits_charged`는 바꿀 수 없습니다.

```mermaid
stateDiagram-v2
  [*] --> queued : Route Handler INSERT 차감과 잡 생성
  queued --> generating : 워커
  queued --> failed : 워커 또는 스위퍼
  queued --> canceled : cancel_reading 사용자 환불
  generating --> rendering : 워커
  generating --> queued : 잡 재시도
  generating --> failed : 워커 fail_job 자동 환불
  rendering --> completed : 워커 progress 100
  rendering --> queued : 잡 재시도
  rendering --> failed : 워커 fail_job 자동 환불
  completed --> [*]
  failed --> [*]
  canceled --> [*]
```

### 그림 5-2. `reading_renders.status`

읽는 법: PDF 렌더 한 건의 상태입니다. 최초 렌더는 리딩 생성 때 함께 만들어지고(0크레딧), 테마 변경 재생성은 5크레딧을 차감한 새 행입니다. `succeeded`가 되려면 `pdf_path`가 필수이고, 그때 `readings.current_render_id`가 갱신됩니다.

```mermaid
stateDiagram-v2
  [*] --> queued : Route Handler INSERT
  queued --> rendering : 워커
  queued --> failed : 워커
  rendering --> succeeded : 워커 pdf_path 필수
  rendering --> queued : 잡 재시도
  rendering --> failed : 워커
  succeeded --> [*]
  failed --> [*]
```

### 그림 5-3. `deliveries.status`

읽는 법: 이메일 발송 outbox 한 건의 상태입니다. `dead`에서만 다시 `pending`으로 돌아갈 수 있고, 그때 시도 횟수 초기화와 감사 기록을 서버가 함께 합니다.

```mermaid
stateDiagram-v2
  [*] --> pending : 워커 INSERT
  [*] --> skipped : 워커 이메일 발송 꺼짐
  pending --> sending : claim_due_deliveries attempts+1
  pending --> skipped : 어드민
  pending --> dead : 어드민
  sending --> sent : finish_delivery 성공
  sending --> pending : finish_delivery 실패 5분 뒤
  sending --> dead : finish_delivery attempts가 max 이상
  dead --> pending : 재발송 API 또는 어드민
  sent --> [*]
  skipped --> [*]
```

## 6. 화면 흐름

### 그림 6-1. 공개 화면, 가입, 온보딩

읽는 법: 왼쪽 공개 화면은 로그인 버튼 없이 쓸 수 있습니다. 가입 뒤에는 콜백에서 환영 크레딧이 지급되고, OAuth 첫 로그인이면 약관 동의(제안 경로)를 거쳐 AI 처리 방식 동의 화면을 지난 뒤 대시보드로 갑니다. Stage A에서는 `/signup`과 `/auth/verify`가 없습니다.

```mermaid
flowchart LR
  LAND["/ 랜딩<br/>3D 히어로, Live Demo"]
  SMP["/sample"]
  PRC["/pricing"]
  LGL["/legal/*<br/>약관 개인정보 환불 면책"]
  WIKI["/wiki<br/>용어 위키"]
  LGN["/login<br/>Stage A는 개발용 패널"]
  SGN["/signup"]
  VRF["/auth/verify"]
  CB["/auth/callback<br/>환영 크레딧 30"]
  TRM["/onboarding/terms<br/>제안, OAuth 첫 로그인"]
  OAI["/onboarding/ai<br/>국외 이전 동의 선택"]
  DASH["/dashboard"]

  LAND --> SMP
  LAND --> PRC
  LAND --> LGL
  LAND --> WIKI
  LAND --> LGN
  LAND --> SGN
  SGN --> VRF --> CB
  LGN --> CB
  CB -->|"이메일 가입자"| OAI
  CB -->|"OAuth 약관 미동의"| TRM --> OAI
  CB -.->|"error=callback"| LGN
  OAI --> DASH
```

### 그림 6-2. 대시보드와 어드민

읽는 법: 왼쪽 위 `/dashboard`가 시작점입니다. 보관함에서 대상을 등록하고 리딩 시작 스테퍼 4단계를 거치면 리딩 상세로 가고, 잔액이 부족하면 크레딧 화면으로 보냅니다. 오른쪽 아래는 `platform_admin` 전용 별도 셸입니다. 우선순위 P1은 히스토리와 어드민 화면입니다(`03` 1절).

```mermaid
flowchart TB
  DASH["/dashboard<br/>홈"]
  SUBJ["/dashboard/subjects<br/>보관함 목록"]
  NEWS["/subjects/new<br/>등록 + 원국 프리뷰"]
  DET["/subjects/id<br/>명식 오행 대운"]
  STRT["/readings/new<br/>스테퍼 4단계"]
  READ["/readings/id<br/>진행 결과 PDF 낭독"]
  HIST["/dashboard/history<br/>P1"]
  CRED["/dashboard/credits<br/>잔액 팩 원장"]
  TOSS["Toss 결제창"]
  BS["/billing/success"]
  BF["/billing/fail"]
  SET["/dashboard/settings<br/>테마 동의 내보내기 탈퇴"]
  CHAT["채팅 패널<br/>/dashboard/chat"]

  ADM["/admin<br/>P1, platform_admin"]
  AU["/admin/users"]
  AP["/admin/payments"]
  AD["/admin/deliveries"]
  AK["/admin/knowledge"]
  AW["/admin/wiki, lint"]

  DASH --> SUBJ
  SUBJ --> NEWS
  SUBJ --> DET
  DET --> STRT
  DASH --> STRT
  STRT -->|"202"| READ
  STRT -->|"402 잔액 부족"| CRED
  DASH --> HIST --> READ
  READ -->|"이 리포트에 대해 묻기"| CHAT
  DASH --> CHAT
  DASH --> CRED
  CRED --> TOSS
  TOSS -->|"성공"| BS --> CRED
  TOSS -->|"취소 실패"| BF --> CRED
  DASH --> SET

  ADM --> AU
  ADM --> AP
  ADM --> AD
  ADM --> AK
  ADM --> AW
```

## 7. 보안 경계

### 그림 7-1. 자산·위협·대응의 신뢰 경계

읽는 법: 위에서 아래로 갈수록 믿을 수 있는 영역입니다. 상자 앞 T1~T8은 `SECURITY.md` 2절의 위협 번호이고, § 번호는 `SECURITY_BASELINE.md`의 장입니다. 가장 안쪽 데이터 영역(RLS, 암호화 컬럼, 감사 로그)이 최종 방어선입니다. 생년월일시는 앱 계층 AES-256-GCM으로 암호화해 키를 DB와 분리합니다.

```mermaid
flowchart TB
  subgraph Z0["① 신뢰하지 않는 영역"]
    BR["브라우저, 봇, PDF 링크를 받은 제3자"]
  end

  subgraph Z1["② 입구 Vercel"]
    LIM["T5 레이트 리밋<br/>Demo IP 해시당 3회/일<br/>리딩 10회/분, 진행 3건<br/>다운로드 60회/시간<br/>§8, §21"]
    HDR["보안 헤더 세션 쿠키<br/>§18"]
  end

  subgraph Z2["③ 앱 서버 신뢰"]
    ENC["T1 생년월일시 AES-256-GCM<br/>ASTRO_PII_KEY 버전별, 서버 환경변수<br/>§12"]
    CON["T2 제3자 동의 체크 + 약관 버전<br/>관계가 본인이 아니면 필수"]
    PAY["T4 서버 confirm + 금액 대조 + 멱등<br/>환불 사유 필수<br/>§6"]
    ADMR["T7 platform_admin 서버 재검증<br/>관리자 2단계 인증<br/>§9, §21"]
    TOK["서명 토큰 개인키 서버 전용<br/>§16"]
  end

  subgraph Z3["④ 데이터 최종 방어선"]
    RLS["RLS + 암호문 컬럼 GRANT 제외<br/>복합 FK로 타 조직 참조 거부<br/>§1~4"]
    AUD["감사 로그<br/>환불 크레딧 지급 대상 삭제<br/>§9, §20"]
    STO["T3 Storage 서명 URL<br/>이메일은 첨부 없이 링크"]
  end

  subgraph Z4["⑤ AI와 외부 제한 신뢰"]
    RND["T6 WeasyPrint url_fetcher<br/>자체 Storage만 허용<br/>§10"]
    AIR["T8 국외 이전 동의 없으면 오픈소스만<br/>contains_pii 문서도 오픈소스만<br/>§16"]
    TOSS["Toss 승인 취소 API"]
    RM["Resend 이메일 주소와 링크"]
  end

  BR -->|"모든 요청"| LIM
  LIM --> HDR
  HDR --> Z2
  ENC -->|"암호문만 저장"| RLS
  CON --> RLS
  PAY -->|"service_role 서버만"| RLS
  ADMR --> AUD
  TOK --> AIR
  RLS --> AUD
  STO -.->|"만료 URL"| BR
  PAY <--> TOSS
  Z2 --> RND
  Z2 --> RM
```

위협별 미결정(`SECURITY.md` 3절·6절): 세션 유휴·절대 만료, CSP 외부 허용 도메인, 감사 로그 보존 기간, 백업·복구 훈련 주기, 알림 수신자, 사고 대응 담당은 "작성 필요"이고, 유출 신고 시한·제3자 동의 문구·미성년 처리·국외 이전 고지·백업과 purge 충돌·운세 광고 규제는 "미확인" 또는 "미결정"이라 그림에 값을 넣지 않았습니다.

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)가 같은 Route Handler 응답과 RLS 읽기를 이용합니다. 이 제품은 생년월일시 등 민감 정보가 중심이라 노출 도구가 6개로 적고, 크레딧을 쓰는 도구는 없습니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)입니다.

### 8-1. API 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["브라우저 사용자"]
    AG["AI 에이전트<br/>회원 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    NX["Next.js 서버 계층<br/>requireSession Route Handler"]
    CR["크레딧 선차감<br/>POST api readings 등"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>익명 또는 Bearer"]
    RL["레이트 리밋 IP 사용자"]
    TL["도구 6개<br/>필드 허용 목록 출력"]
    SAN["위키 untrusted 처리<br/>민감 필드 제거"]
  end

  subgraph DB["DB 최종 방어선"]
    PUB["themes 공개 읽기<br/>anon RLS"]
    USR["readings 상태 읽기<br/>사용자 세션 RLS"]
    ENC["암호문 컬럼 제외<br/>생년월일시 질문 본문"]
  end

  BR --> NX
  NX --> CR
  NX -->|"사용자 세션"| USR
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  TL -->|"익명"| PUB
  TL -.->|"사용자 토큰 D-M1"| USR
  TL -.->|"공개 위키 RPC 신설 D-M3"| PUB
  USR --> ENC
  TL -.->|"확인 링크 D-M6"| NX
```

### 8-2. 리딩 준비와 사람 확정 (`astro_prepare_reading`)

```mermaid
sequenceDiagram
  autonumber
  actor U as 회원
  participant A as AI 에이전트
  participant M as MCP 서버
  participant D as DB 읽기
  participant W as 웹 리딩 화면

  U->>A: 사주 리딩 하나 만들고 싶어
  A->>M: astro_prepare_reading 종류 테마
  M->>D: 엔타이틀먼트 테마 잔액 진행 중 건수 읽기
  D-->>M: 읽기 결과
  Note over M: 저장하지 않음<br/>consume_credits 호출 안 함<br/>생년월일시 입력 안 받음
  M-->>A: 가능 여부 비용 15 확정 전 문구 확인 링크 15분
  A-->>U: 15크레딧이 필요합니다 아직 차감 전입니다 링크에서 진행하세요
  U->>W: 링크 열기 로그인 세션 일치 확인
  W-->>U: 대상 선택 질문 입력 크레딧 수 표시
  U->>W: 확인 버튼 클릭
  W->>D: POST api readings 선차감 멱등 request_id
  D-->>W: 202 reading_id 또는 CR001
  W-->>U: 만드는 중 안내
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R0["R0 익명 읽기"]
    T1["astro_list_themes MVP"]
    T2["astro_get_wiki_page 1.5 D-M3 후"]
  end
  subgraph R1["R1 로그인 읽기 1.5"]
    T3["astro_list_my_readings"]
    T4["astro_get_reading_status"]
    T5["astro_get_credit_balance"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T6["astro_prepare_reading"]
  end
  subgraph NO["만들지 않음"]
    N1["리딩 생성 취소 삭제 재렌더"]
    N2["보관함 생년월일시 원국 본문"]
    N3["AI 채팅 음성 낭독 결제 환불"]
    N4["다운로드 URL 계정 삭제 어드민"]
  end
  R0 --> R1 --> PR
  PR -.->|"사람이 웹에서 확정"| N1
```

## 문서 불일치

그림에는 아래 각 항목의 앞쪽(01·05·04 문서) 값을 골랐습니다.

| # | 내용 | 문서 A | 문서 B | 그림에서 고른 쪽 |
|---|---|---|---|---|
| 1 | 이메일 재발송이 가능한 상태 | `04_API.md` 2절: `POST /api/deliveries/[id]/resend`의 오류가 "상태가 dead/sent 아님" 409라서 sent에서도 재발송이 되는 것처럼 읽힘 | `05_DATA_MODEL.md` 3.3절: `sent`는 전이 없음, `dead`만 `pending`으로 | 05(그림 5-3, 4-4는 dead만) |
| 2 | PDF 서명 URL 만료 | `SECURITY.md` T3: "만료 시간 짧게" | `01_PRD.md` AS-F-016, `04_API.md`: 7일 서명 URL | 7일(01, 04). 보안 문서의 "짧게"가 7일보다 짧은 값을 뜻하는지 확인 필요 |
| 3 | Live Demo 입력 저장 여부 | `SECURITY.md` T5: "입력은 저장하지 않는지 확인 필요"(미확인) | `01_PRD.md` AS-F-024, `04_API.md`: 입력 저장·로그 금지(확정 문장) | 저장 안 함(01, 04) |
| 4 | 히스토리 화면의 범위 | `01_PRD.md` AS-F-021: 대시보드에 히스토리 포함(MVP 기능) | `03_SCREENS_UX.md` 1절: `/dashboard/history` 우선순위 P1 | 03의 P1 표기(그림 6-2) |
| 5 | MCP 공개 위키 읽기 | `MCP.md`의 `astro_get_wiki_page`는 읽기 전용 공개 RPC가 필요 | `04_API.md` 2.1절 하단: 공개 위키는 서버 컴포넌트가 service_role로 읽음(MCP 경로는 service_role 금지) | 그림 8-1에 점선(D-M3)으로 표시 |
| 6 | MCP 리딩 목록 | `MCP.md`의 `astro_list_my_readings`는 목록 읽기 경로가 필요 | `04_API.md`에는 `GET /api/readings/[id]`만 있고 목록 Route Handler 없음(`03_SCREENS_UX.md` 3절은 RLS로 `readings` 직접 읽기) | RLS 직접 읽기(D-M4) |
| 7 | MCP 잔액 읽기 | `MCP.md`의 `astro_get_credit_balance`는 잔액 읽기 경로가 필요 | `03_SCREENS_UX.md` 3절은 `credit_balances`를 쓰지만 `04_API.md`·`05_DATA_MODEL.md`에 정의 없음 | 정의 확인 필요(D-M5), 그림에서는 "DB 읽기"로만 표기 |
| 8 | 외부 AI 제공자 전송 범위 | `SECURITY.md` T8·`CLAUDE.md`: 생년월일시 원문과 실명은 어떤 AI 제공자에도 보내지 않음 | `MCP.md`: 에이전트의 모델 제공자는 이 제품이 통제하지 못하는 경로. 도구 출력에서 해당 필드를 빼는 것으로만 대응 | 도구 출력에서 제외(D-M7 법무 확인) |

## 갱신 규칙

`01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`를 고치면 해당 절의 그림도 같은 변경에서 함께 고칩니다(표의 "근거 문서 절" 참조).
