# DIAGRAMS: NOMAD Commerce UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 이 폴더의 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid). 전체 구조도는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일입니다.

**제품 한 줄 정의:** 쿠팡·스마트스토어 셀러가 아마존·국내 도매 상품을 상품DB에 모으고, AI로 슬롯형 상세페이지(이미지 10장/15장, 카피, 금지어 검사)를 만든 뒤 마켓 규격으로 변환해 API 업로드하거나 엑셀/ZIP으로 내려받는 SaaS (`README.md` 1절).

**근거 문서:** `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`, `MCP.md`, 공통 `../_platform-core/SECURITY_BASELINE.md`, `CORE_SPEC.md`.

**표기:** 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·비동기 폴링, "(제안)" = 문서가 제안이라고 밝힌 값. 숫자 CM-F-nnn은 `01_PRD.md` 기능 ID.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-1 | 사용자와 MVP 기능 | 유스케이스(flowchart) | `01_PRD.md` 1절, 2절 |
| 1-2 | Phase 2·3 기능과 범위 밖 | 유스케이스(flowchart) | `01_PRD.md` 2절 |
| 2-1 | 구성요소: 웹·워커·코어·외부 | 컴포넌트 | `02_ARCHITECTURE.md` 2~4절, 6절 |
| 2-2 | 구성요소: AI 계층 | 컴포넌트 | `02_ARCHITECTURE.md` 개정표, `04_API.md` 6.1절 |
| 3 | 데이터 모델 | 클래스 | `05_DATA_MODEL.md` 1~4절 |
| 4-1 | 상세페이지 생성과 크레딧 | 시퀀스 | `04_API.md` 2절, `02_ARCHITECTURE.md` 4.1절 |
| 4-2 | 크레딧팩 결제 확인 | 시퀀스 | `04_API.md` 2절, `03_SCREENS_UX.md` 2.2절 |
| 4-3 | 마켓 업로드 | 시퀀스 | `04_API.md` 2절, `03_SCREENS_UX.md` 2.4절 |
| 4-4 | 셀러 어시스턴트 채팅 | 시퀀스 | `04_API.md` 2.1절, 6.2절 |
| 5-1 | 상세페이지 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-2 | 슬롯 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-3 | 마켓 업로드 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 6 | 화면 흐름 | flowchart | `03_SCREENS_UX.md` 1절, 2절 |
| 7 | 보안 신뢰 경계 | flowchart | `SECURITY.md` 1~4절 |
| 8-1 | API 위에 얹는 MCP 구성 | 컴포넌트(flowchart) | `MCP.md` 1~3절, `MCP_BASELINE.md` 1·7절 |
| 8-2 | 상세페이지 생성 준비와 사람 확정 | 시퀀스 | `MCP.md` 2·6절, `04_API.md` 2절 |
| 8-3 | 도구 위험 등급과 노출 단계 | flowchart | `MCP.md` 2절, `MCP_BASELINE.md` 2절 |

## 1. 사용자와 기능

### 그림 1-1. 사용자와 MVP 기능

읽는 법: 왼쪽은 사용자 역할(페르소나), 오른쪽은 MVP 기능입니다. 선은 "누가 주로 쓰는가"를 뜻합니다. 역할 권한은 `04_API.md` 1절(쓰기 owner/admin/member, 계정·결제 owner/admin)을 따릅니다.

```mermaid
flowchart LR
  P1(["부업 셀러 민지<br/>(하루 5개 상품)"])
  P2(["다마켓 셀러 준호<br/>(계정 3개)"])
  P3(["건기식 소싱러 수아"])
  OP(["플랫폼 운영자<br/>(platform_admin)"])

  subgraph MVP["MVP 기능"]
    direction TB
    F1["아마존·엑셀 가져오기<br/>CM-F-010, 011"]
    F2["상품DB 관리<br/>CM-F-012"]
    F3["AI 상세페이지 생성<br/>10/15슬롯, 3유형"]
    F4["금지어·compliance 게이트<br/>CM-F-025"]
    F5["마켓 이미지 변환<br/>CM-F-030"]
    F6["엑셀·ZIP 내보내기<br/>CM-F-031, 032"]
    F7["쿠팡·스마트스토어 업로드<br/>CM-F-037"]
    F8["셀러 어시스턴트 채팅·음성<br/>CM-F-045, 046"]
    F9["Toss 구독·크레딧팩<br/>CM-F-005"]
    F10["마켓 규칙 위키 열람<br/>CM-F-042"]
  end
  subgraph ADM["운영자 기능 MVP"]
    A1["규칙 원고 색인<br/>CM-F-041"]
    A2["위키 검수·게시"]
  end

  P1 --> F1
  P1 --> F3
  P2 --> F7
  P2 --> F6
  P3 --> F4
  P1 --> F8
  P2 --> F9
  P1 --> F10
  F1 --> F2
  F2 --> F3
  F3 --> F4
  F4 --> F5
  F5 --> F6
  F5 --> F7
  OP --> A1
  A1 --> A2
  A2 --> F10
```

### 그림 1-2. Phase 2·3 기능과 범위 밖

읽는 법: MVP 이후로 미룬 기능과 이 제품 범위 밖인 기능을 `01_PRD.md` 2절 표의 구분 그대로 모았습니다.

```mermaid
flowchart TB
  subgraph P2["Phase 2"]
    direction TB
    X1["유형 5종 추가<br/>(리뷰형은 실제 리뷰 입력 시만)"]
    X2["이미지로 생성 모드"]
    X3["도매꾹·온채널·아마존 CSV 파서"]
    X4["와디즈·11번가 규격 출력"]
    X5["지마켓·옥션·11번가·롯데온<br/>카페24·아임웹"]
    X6["상품 쇼츠 영상<br/>(sceneflow 워커 API)"]
    X7["카드뉴스·SNS 배포"]
    X8["자동화 캔버스·웹훅 발신"]
    X9["비회원 AI 상담"]
    X10["외부용 API Key·Capacitor 앱"]
  end
  subgraph P3["Phase 3"]
    direction TB
    Y1["판매관리<br/>(주문·정산·CS)"]
    Y2["브랜드킷·분석 대시보드"]
  end
  subgraph OUT["범위 밖"]
    direction TB
    Z1["블로그 원고·발행<br/>(nomad-blog 소유)"]
    Z2["제휴 링크·쿠팡파트너스<br/>(core affiliate)"]
  end
```

## 2. 구성요소

### 그림 2-1. 웹·워커·코어·외부 서비스

읽는 법: 브라우저의 요청은 Next.js Route Handler가 인증·크레딧·검증을 한 뒤 DB에 쓰고, 오래 걸리는 일은 `core.jobs`로 넘깁니다. 워커가 그 잡을 집어 외부 서비스와 통신합니다. AI 계층은 그림 2-2에서 따로 그립니다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["화면<br/>Next.js 클라이언트"]
  end

  subgraph WEB["웹 서버 (apps/nomad-commerce)"]
    MW["proxy.ts<br/>세션·헤더"]
    RH["Route Handler<br/>requireSession·zod·레이트 리밋"]
    WH["웹훅 수신<br/>Toss, fal"]
    AIG["AI 게이트<br/>(그림 2-2)"]
  end

  subgraph WK["워커 (services/commerce-worker, Node 22)"]
    DSP["디스패처 5초<br/>waiting → queued"]
    GEN["detail: 이미지·합성·변환"]
    IMP["import: 아마존·엑셀"]
    UPL["upload: 쿠팡·스마트스토어"]
    EXP["export: 엑셀·ZIP"]
    CRON["크론<br/>폴링·환율·만료·소진 알림"]
  end

  subgraph DB["Supabase"]
    CORE["core 스키마<br/>조직·크레딧·결제·잡·감사"]
    COM["commerce 스키마<br/>테이블 13개"]
    ST["Storage<br/>org-files, exports"]
    RT["Realtime<br/>잡 진행률"]
  end

  subgraph EXT["외부 서비스"]
    TOSS[("Toss Payments")]
    MKT[("쿠팡 Wing<br/>네이버 커머스API")]
    FAL[("fal 이미지")]
    AMZ[("아마존 상품 데이터 API")]
    FX[("한국수출입은행 환율")]
  end

  UI --> MW --> RH
  RH --> CORE
  RH --> COM
  RH --> AIG
  RH -->|"서명 URL"| ST
  RH -->|"enqueue_job"| CORE
  DSP -->|"enqueue_job"| CORE
  CORE -->|"claim_jobs"| GEN
  CORE -->|"claim_jobs"| IMP
  CORE -->|"claim_jobs"| UPL
  CORE -->|"claim_jobs"| EXP
  GEN --> FAL
  IMP --> AMZ
  UPL --> MKT
  CRON --> FX
  CRON -.->|"승인 상태 폴링"| MKT
  RH --> TOSS
  TOSS -.->|"상태 동기화만"| WH
  FAL -.->|"완료 웹훅"| WH
  WH --> CORE
  GEN --> COM
  GEN --> ST
  CORE --> RT
  RT -.-> UI
```

### 그림 2-2. AI 계층

읽는 법: 브라우저는 `/api/ai/*`, `/api/voice/*`만 부릅니다. Dify, FastAPI, LLM·음성 제공자는 직접 부르지 않습니다(`04_API.md` 1절). 상세페이지 텍스트 생성은 워커가 잡 토큰으로, 보조 AI는 Route Handler가 서명 토큰으로 FastAPI 그래프를 실행합니다.

```mermaid
flowchart LR
  UI["브라우저<br/>채팅·마이크 위젯"]
  subgraph WEB["Next.js 서버"]
    GATE["AI 게이트 /api/ai/*<br/>/api/voice/*"]
    TOK["lib/ai/token.ts<br/>서명 토큰 발급 전용"]
    INT["/api/internal/ai-token<br/>/api/internal/ai-settle"]
    VC["core-voice 어댑터"]
  end
  WK["commerce-worker"]
  DIFY["Dify 앱 commerce-chat"]
  subgraph FA["FastAPI apps/api"]
    ROUTER["모델 라우터"]
    G1["그래프<br/>commerce.detail_page"]
    G2["그래프<br/>commerce.assist"]
    TOOLS["/tools/answer<br/>/dify/retrieval"]
    RAG["RAG·위키<br/>/rag/ingest, /wiki/*"]
  end
  subgraph DB["Supabase core"]
    AIT["ai_conversations·ai_messages<br/>ai_runs·ai_usage"]
    VEC["ai_chunks pgvector<br/>wiki_pages"]
  end
  LLM[("상용·오픈소스 LLM")]
  VOX[("ElevenLabs<br/>오픈소스 음성 서버")]

  UI --> GATE
  GATE --> TOK
  GATE -->|"채팅"| DIFY
  GATE -.->|"Dify 장애 시 answer-direct"| TOOLS
  GATE -->|"assist 작업"| G2
  GATE --> VC --> VOX
  DIFY --> TOOLS
  WK -->|"잡 토큰 요청"| INT
  WK -->|"detail_page 실행"| G1
  G1 --> ROUTER
  G2 --> ROUTER
  TOOLS --> ROUTER
  ROUTER --> LLM
  TOOLS --> VEC
  RAG --> VEC
  FA --> AIT
  GATE --> AIT
```

## 3. 데이터 모델

### 그림 3. 핵심 테이블과 관계

읽는 법: `commerce` 스키마 13개 테이블 중 핵심 11개와 참조하는 코어 3개입니다. 선 위 글자는 관계입니다. 모든 테이블은 `org_id`로 조직에 묶이고, 자식은 `(org_id, parent_id)` 복합 FK로 다른 조직 참조를 막습니다. `exchange_rates`, `market_categories`(전역, 로그인 사용자 SELECT만)는 생략했습니다.
접근 주체: 사용자가 직접 쓰는 테이블은 products, shipping_templates, listing_drafts(콘텐츠 컬럼만), banned_words(조직 행, owner/admin)뿐이고 나머지는 service_role 또는 RPC만 씁니다(`05_DATA_MODEL.md` 4절).

```mermaid
classDiagram
  class products {
    id uuid
    org_id uuid
    source_type
    title
    health_food_status
    sell_price_krw
    status
    deleted_at
  }
  class import_batches {
    id uuid
    source_type
    status
    total_rows
    job_id
  }
  class detail_pages {
    id uuid
    product_id
    page_type
    slot_set
    status
    current_phase
    credits_charged
    credit_ledger_id
    request_id
    compliance_verdict
  }
  class detail_page_slots {
    detail_page_id
    slot_code
    render_method
    status
    provider_request_id
  }
  class market_images {
    detail_page_id
    market
    kind
    storage_path
  }
  class market_accounts {
    id uuid
    market
    slot_no
    credential_id
    status
  }
  class shipping_templates {
    id uuid
    name
    return_window_days
    is_default
  }
  class listing_drafts {
    id uuid
    market
    category_code
    completeness_pct
    status
  }
  class market_uploads {
    id uuid
    market_product_id
    status
    idempotency_key
    job_id
  }
  class export_files {
    id uuid
    kind
    market
    status
    expires_at
  }
  class banned_words {
    org_id nullable
    word
    severity
    is_active
  }
  class core_organizations {
    id uuid
  }
  class core_jobs {
    id uuid
  }
  class core_encrypted_credentials {
    id uuid
  }

  core_organizations "1" --> "*" products : 조직 소유
  import_batches "1" --> "*" products : 가져오기
  products "1" --> "*" detail_pages : 버전
  detail_pages "1" --> "*" detail_page_slots : 슬롯
  detail_pages "1" --> "*" market_images : 마켓 변환본
  products "1" --> "*" listing_drafts : 등록 폼
  listing_drafts "*" --> "1" shipping_templates : 배송 템플릿
  listing_drafts "*" --> "1" market_accounts : 업로드 계정
  listing_drafts "1" --> "*" market_uploads : 업로드 이력
  market_accounts "*" --> "1" core_encrypted_credentials : 암호화 키
  detail_pages "*" ..> "1" core_jobs : job_id
  market_uploads "*" ..> "1" core_jobs : job_id
  export_files "*" ..> "*" detail_pages : detail_page_ids
  banned_words ..> detail_pages : 금지어 검사
```

## 4. 핵심 시퀀스

### 그림 4-1. 상세페이지 생성과 크레딧 (CM-F-003, 020~023, 043)

읽는 법: 요청 한 번에 크레딧 선차감, `detail_pages` waiting 저장, 큐 등록이 한 Route Handler에서 이뤄집니다. 실패하면 core가 자동 환불합니다. 텍스트 단계는 FastAPI 그래프, 이미지 단계는 워커입니다.

```mermaid
sequenceDiagram
  actor U as 셀러
  participant RH as POST /api/detail-pages
  participant CO as core RPC
  participant DB as commerce DB
  participant WK as 워커
  participant NX as /api/internal/ai-token
  participant FA as FastAPI 그래프
  participant FAL as fal

  U->>RH: request_id, items 최대 50
  RH->>RH: 세션·역할·플랜 features·zod 검증
  RH->>CO: consume_credits 9 또는 14 합계 1회
  alt 잔액 부족
    CO-->>RH: CR001
    RH-->>U: 402
  else 차감 성공
    CO-->>RH: ledger id
    RH->>DB: detail_pages INSERT status waiting
    RH-->>U: detail_page_ids
  end
  loop 디스패처 5초
    WK->>DB: waiting을 조직 동시성만큼 queued로
    WK->>CO: enqueue_job credit_ledger_id
  end
  WK->>CO: claim_jobs, phase prepare
  WK->>NX: job_id, X-Worker-Key
  NX->>CO: jobs 행이 running인지 확인
  NX-->>WK: 서명 토큰 10분 jti 1회
  WK->>FA: commerce.detail_page runs
  FA-->>WK: 카피, 프롬프트, verdict
  WK->>WK: zod 재검증 후 슬롯 기록
  WK->>FAL: 슬롯 이미지 요청
  FAL-->>WK: 완료 웹훅 토큰 대조
  WK->>DB: ready 또는 부분 실패
  alt 최종 실패
    WK->>CO: fail_job 자동 환불
  end
```

### 그림 4-2. 크레딧팩 결제 확인 (CM-F-005)

읽는 법: 금액은 클라이언트가 아니라 DB의 주문이 정합니다. 지급은 서버 confirm 경로에서만 일어나고, 웹훅은 상태 동기화만 합니다.

```mermaid
sequenceDiagram
  actor U as 셀러 owner
  participant RH as /api/billing
  participant DB as core DB
  participant T as Toss Payments
  participant WH as /api/webhooks/toss

  U->>RH: POST orders kind credit_pack
  RH->>RH: 역할 owner/admin 확인
  RH->>DB: payment_orders INSERT 금액은 DB
  RH-->>U: orderId, amount
  U->>T: 결제창
  T-->>U: paymentKey 리다이렉트
  U->>RH: POST confirm paymentKey, orderId, amount
  RH->>T: confirm 승인 요청
  T-->>RH: 승인 결과
  RH->>DB: confirm_payment_order 멱등
  alt 금액 불일치 PM001
    DB-->>RH: 오류
    RH->>T: 승인 취소 요청
    RH-->>U: 결제 확인 실패
  else 정상
    DB-->>RH: 크레딧 지급 1회
    RH-->>U: 결과
  end
  T-->>WH: 상태 변경 웹훅
  WH->>WH: 서명·event_id 멱등
  WH->>DB: 상태 동기화만
```

### 그림 4-3. 마켓 업로드 (CM-F-025, 033, 037)

읽는 법: compliance FAIL이나 WARN 미확인이면 INSERT 시점의 게이트 트리거가 막습니다(CM004~CM008). 같은 `request_id` 재전송은 업로드 1건으로 합쳐집니다(멱등 키). 마켓 키는 워커가 잡 실행 때만 복호화합니다.

```mermaid
sequenceDiagram
  actor U as 셀러
  participant RH as POST /api/uploads
  participant DB as commerce DB
  participant CO as core jobs
  participant WK as 워커 upload
  participant V as encrypted_credentials
  participant M as 쿠팡·스마트스토어
  participant CR as 폴링 크론 10분

  U->>RH: request_id, listing_draft_ids 최대 50
  RH->>RH: 세션·역할·features.market_api
  RH->>DB: market_uploads INSERT status queued
  alt FAIL 또는 WARN 미확인 또는 계정 무효
    DB-->>RH: CM004 CM005 CM006 CM008
    RH-->>U: 422 또는 409
  else 통과
    RH->>CO: enqueue_job idempotency
    RH-->>U: upload_ids
  end
  WK->>CO: claim_jobs
  WK->>DB: validating
  WK->>V: credential_id로 키 복호화
  WK->>DB: uploading
  WK->>M: 상품 등록 30초 타임아웃
  alt 5xx 또는 429
    M-->>WK: 오류
    WK->>WK: 재시도 3회
  else 4xx
    M-->>WK: 필드 오류
    WK->>DB: failed 사유 요약
  else 성공
    M-->>WK: market_product_id
    WK->>DB: submitted
  end
  CR->>M: 승인 상태 조회
  CR->>DB: approved 또는 rejected
```

### 그림 4-4. 셀러 어시스턴트 채팅 (CM-F-045, 050)

읽는 법: 질문은 마스킹 후 Dify로 가고, 상품 질문은 FastAPI `/tools/answer`가 같은 조직 행인지 대조해 답합니다. Dify가 죽으면 Next.js가 FastAPI 직접 경로로 우회합니다. 크레딧은 먼저 3 차감하고 실제 사용량(1~5)으로 정산합니다.

```mermaid
sequenceDiagram
  actor U as 셀러
  participant GT as /api/ai/chat
  participant CO as core RPC
  participant D as Dify commerce-chat
  participant FA as FastAPI tools
  participant DB as ai_messages

  U->>GT: conversation_id, request_id, message 1000자 이하
  GT->>GT: 세션·features.ai_chat·레이트 리밋 3종
  GT->>GT: 대화 주인 확인, 메시지 마스킹
  GT->>CO: consume_credits 3, 멱등 키 conv 턴
  alt 402 잔액 부족
    CO-->>GT: CR001
    GT-->>U: 충전 모달
  else 차감 성공
    GT->>D: chat-messages, dify_user, 바인딩 id
    alt Dify 5xx 또는 10초 무응답
      GT->>FA: answer-direct 서명 토큰
    else 정상
      D->>FA: tools/answer, X-Internal-Key
      FA->>FA: 매핑 org와 대상 org 대조
    end
    FA-->>GT: 답변, 출처, usage
    GT->>DB: user, assistant 메시지 기록
    GT->>CO: 실제 사용량으로 정산 또는 환불
    GT-->>U: SSE 답변과 출처 칩
  end
```

## 5. 상태 머신

### 그림 5-1. 상세페이지 `detail_pages`

읽는 법: 전이는 `commerce_status_guard()` 트리거가 강제하며 service_role도 예외가 아닙니다(위반 CM001). 괄호의 주체가 전이를 일으킵니다.

```mermaid
stateDiagram-v2
  [*] --> waiting : 생성 Route Handler 크레딧 선차감
  waiting --> queued : 디스패처
  waiting --> canceled : 취소 API 환불
  queued --> generating : 워커
  queued --> canceled : 취소 API cancel_job
  queued --> failed : 워커
  generating --> ready : 워커
  generating --> failed : 워커 fail_job 자동 환불
  generating --> canceled : 워커 cancel_requested_at 확인 후
  ready --> archived : 서버
  archived --> ready : 서버
  failed --> waiting : 재시도 API 새 차감
```

### 그림 5-2. 슬롯 `detail_page_slots`

읽는 법: 슬롯 단위 상태입니다. 일부 슬롯만 실패하면 페이지는 ready가 되고 실패 슬롯 수만큼 부분 환불됩니다. 다시 생성은 1크레딧(고화질 3).

```mermaid
stateDiagram-v2
  [*] --> pending
  pending --> generating : 워커
  pending --> skipped : 워커 L-1 건기식 상태 모름
  pending --> failed : 워커
  generating --> completed : 워커
  generating --> failed : 워커
  completed --> generating : 재생성 API
  failed --> generating : 재생성 API
```

### 그림 5-3. 마켓 업로드 `market_uploads`

읽는 법: INSERT 때 게이트 트리거(CM004~CM008)를 먼저 통과해야 queued가 됩니다. submitted 이후는 폴링 크론이 결과를 정합니다.

```mermaid
stateDiagram-v2
  [*] --> queued : 업로드 API 게이트 통과
  queued --> validating : 워커
  queued --> canceled : 워커
  queued --> failed : 워커
  validating --> uploading : 워커
  validating --> failed : 워커
  uploading --> submitted : 워커
  uploading --> failed : 워커
  submitted --> approved : 폴링 크론
  submitted --> rejected : 폴링 크론
  submitted --> failed : 폴링 크론
  failed --> queued : 재시도 API
  rejected --> queued : 재시도 API
```

그림으로 그리지 않은 나머지 상태 전이(`05_DATA_MODEL.md` 3절 그대로):

| 테이블 | 전이 | 주체 |
|---|---|---|
| import_batches | uploaded → parsing → completed, 각 단계에서 failed | 워커 |
| listing_drafts | draft ↔ ready(완성도 100이면 ready), draft/ready → archived, archived → draft | 서버 |
| export_files | queued → running → succeeded → expired, 각 단계에서 failed, queued → canceled | 워커, 만료는 크론(+7일) |

## 6. 화면 흐름

읽는 법: 로그인 후 `/dashboard`에서 시작해 가져오기, 상품DB, 생성, 결과 뷰어, 내보내기·업로드 순으로 이동합니다. 점선은 어느 화면에서나 여는 보조 패널입니다. 대시보드 셸·GNB 구성은 결정 대기(`01_PRD.md` 9절)라 메뉴 구조는 그리지 않았습니다.

```mermaid
flowchart TB
  LAND["/ 랜딩 3D 히어로"] --> LOGIN["/login"]
  LOGIN --> CB["/auth/callback"]
  LOGIN --> DASH
  CB --> DASH["/dashboard<br/>KPI·환율·최근 작업"]
  DASH --> ONB["/onboarding/ai<br/>AI 처리 방식·국외 이전 동의"]
  DASH --> SRC["/sourcing<br/>아마존·엑셀 탭"]
  SRC --> MAP["/sourcing/imports/id<br/>컬럼 매핑"]
  SRC --> PROD["/products<br/>상품DB"]
  MAP --> PROD
  PROD --> EDIT["/products/new, id<br/>수동 등록·음성 입력"]
  PROD --> GEN["생성 모달<br/>개별·다중"]
  GEN --> DPL["/detail-pages<br/>목록·큐 패널"]
  DPL --> VIEW["/detail-pages/id<br/>뷰어·편집·compliance"]
  VIEW --> LST["/listings/id<br/>등록 폼 6단계"]
  VIEW --> EXPS["/exports<br/>엑셀·ZIP"]
  LST --> UPS["/uploads<br/>이력·실패 로그"]
  DASH --> BILL["/billing<br/>플랜·크레딧팩"]
  DASH --> SET["/settings<br/>markets, shipping, banned-words"]
  SET --> LST
  CHAT(["채팅 패널·/chat"]) -.-> VIEW
  CHAT -.-> UPS
  NAR(["내레이션 패널·/narrations"]) -.-> VIEW
  WIKI["/wiki 마켓 규칙 위키"] -.-> CHAT
  ADM["/admin/knowledge, /admin/wiki<br/>운영자 전용"]
```

## 7. 보안 경계

읽는 법: 점선 네모는 신뢰 경계입니다. 자산(마켓 키, 결제, 크레딧)은 경계 안쪽 서버에만 있고 브라우저에 평문이 내려가지 않습니다. T번호는 `SECURITY.md` 2절 위협, §는 `../_platform-core/SECURITY_BASELINE.md` 장 번호입니다.

```mermaid
flowchart TB
  subgraph UNT["신뢰하지 않음"]
    BR["브라우저·셀러 입력<br/>URL, HTML, 금액"]
    TP["Toss·fal 웹훅 발신자"]
    BOT["봇·공개 입구"]
  end

  subgraph SRV["서버 경계 Next.js 와 워커"]
    GATE["Route Handler<br/>세션·역할·zod §2 §10"]
    NET["commerce-net<br/>ASIN만 추출, 사설 IP 차단 T4 §10"]
    SAN["서버 sanitize<br/>저장·렌더 T6 §10"]
    CHK["서버 confirm<br/>금액 대조·멱등 T2 §6"]
    CRD["consume_credits<br/>선차감 후 환불 T3"]
    CMP["금지어·compliance 게이트<br/>FAIL 차단 T5"]
    RL["레이트 리밋<br/>비회원 AI 없음 T7 §8 §21"]
  end

  subgraph DBZ["DB 경계 RLS·RPC"]
    TBL["commerce 테이블<br/>쓰기는 service_role과 RPC §4"]
    VAULT["encrypted_credentials<br/>마켓 키 암호화 T1 §5"]
    LED["credit_ledger·결제 주문"]
    AUD["audit_logs<br/>§9 §20"]
  end

  subgraph OUTB["외부로 나가는 데이터"]
    MK[("쿠팡·스마트스토어<br/>상품 등록 데이터")]
    AIX[("fal·Dify·LLM<br/>국외 이전 동의 대상 T8 §16")]
    TS[("Toss<br/>빌링키는 PG 보관")]
  end

  BR --> GATE
  BOT --> RL --> GATE
  TP -.->|"서명·토큰 검증"| CHK
  GATE --> NET
  GATE --> SAN
  GATE --> CRD
  GATE --> CMP
  GATE --> CHK
  CRD --> LED
  CHK --> LED
  SAN --> TBL
  CMP --> TBL
  GATE --> VAULT
  GATE --> AUD
  VAULT -.->|"워커만 복호화"| MK
  GATE --> AIX
  CHK --> TS
```

SECURITY.md 3절의 세션 만료, CSP 도메인, 레이트 리밋 수치, 감사 로그 보존, 백업, 알림 수신자는 "(작성 필요)"라서 그림에 수치를 넣지 않았습니다. 세션·헤더는 §18, 공급망은 §19, 운영은 §20, 계정 보호는 §21을 참조합니다.

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)가 같은 DB와 같은 확정 경로를 씁니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)입니다. 이 제품은 읽는 전용 RPC가 없어 읽기 도구가 테이블 SELECT(RLS)를 씁니다.

### 8-1. API 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["셀러 브라우저"]
    AG["AI 에이전트<br/>셀러 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    NX["Next.js 서버 계층<br/>requireSession Route Handler"]
    WK["워커 잡<br/>업로드 내보내기 생성"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>Bearer만 익명 없음"]
    RL["레이트 리밋 사용자 조직"]
    TL["도구 5개<br/>필드 허용 목록 출력"]
    SAN["상품명 이슈 untrusted 처리<br/>길이 제한 링크 제거"]
  end

  subgraph DB["DB 최종 방어선"]
    TB["products detail_pages<br/>market_uploads banned_words"]
    RLS["RLS 멤버십 엔타이틀먼트<br/>키 원가 스냅샷은 출력 제외"]
  end

  BR --> NX
  NX --> TB
  NX -.-> WK
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  TL -.->|"사용자 토큰 D-M1<br/>테이블 SELECT D-M3"| TB
  TB --> RLS
  TL -.->|"확인 링크 D-M2"| NX
```

### 8-2. 상세페이지 생성 준비와 사람 확정 (`commerce_prepare_detail_page`)

```mermaid
sequenceDiagram
  autonumber
  actor S as 셀러
  participant A as AI 에이전트
  participant M as MCP 서버
  participant D as DB 읽기
  participant W as 웹 생성 화면
  participant C as 크레딧 차감

  S->>A: 상품 5개 15장 상세페이지 만들어줘
  A->>M: commerce_prepare_detail_page 상품 목록 슬롯 구성
  M->>D: 상품과 기존 상세페이지 읽기
  D-->>M: 상품 상태 한도 정보
  Note over M: 저장하지 않음 크레딧 차감 안 함<br/>POST detail-pages 호출 안 함
  M-->>A: 가능 여부 필요 크레딧 확정 전 문구 확인 링크 15분
  A-->>S: 필요 크레딧은 이만큼이고 아직 시작 전입니다 링크에서 확인하세요
  S->>W: 링크 열기 로그인 세션 일치 확인
  W-->>S: 상품 슬롯 크레딧 표시
  S->>W: 생성 클릭
  W->>C: consume_credits 선차감 후 잡 등록 기존 경로
  C-->>W: 대기 상태 또는 CR001 CM002 CM007 오류
  W-->>S: 결과 안내
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R2["R2 조직 데이터 읽기 MVP"]
    T1["commerce_list_products"]
    T2["commerce_get_detail_page_status"]
    T3["commerce_list_market_uploads"]
  end
  subgraph R1["R1 입력 문구 검사 1.5"]
    T4["commerce_check_banned_words"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T5["commerce_prepare_detail_page"]
  end
  subgraph NO["만들지 않음"]
    N1["생성 업로드 내보내기 삭제"]
    N2["결제 크레딧 구매 구독"]
    N3["마켓 키 계정 추가 원가 공급사"]
    N4["WARN 확인 AI 보조 호출"]
  end
  R2 --> R1 --> PR
  PR -.->|"사람이 웹에서 확정"| N1
```

## 문서 불일치

- 해당하는 모순은 확인하지 못했습니다(없음). 다만 `SECURITY.md` 3절에 값이 비어 있는 항목이 있고, 마켓 API 약관·업로드 승인 조회 방식·환율 API 키는 문서가 "미확인"으로 둔 상태라 그림에서도 확정값으로 그리지 않았습니다.
- 참고(모순 아님): `README.md`는 AI·음성·3D 히어로를 MVP로 적고, `01_PRD.md` 2절은 카카오·네이버 로그인을 Stage C(P1, G2 후)로, 비회원 AI 상담을 Phase 2로 적습니다. 그림 1-1은 후자를 따랐습니다.
- MCP 작성 중 발견(`MCP.md` D-M3): `04_API.md`에는 상품·상세페이지·업로드를 읽는 전용 RPC나 GET Route Handler가 없고 화면은 서버 컴포넌트가 테이블을 직접 읽습니다. 그림 8-1은 MCP 읽기 도구가 같은 테이블을 사용자 세션 RLS로 SELECT하는 것으로 그렸습니다.
- MCP 작성 중 발견(`MCP.md` D-M4, D-M6): 금지어 매처의 외부 호출 함수 이름(`CM-06-017`)과 크레딧 잔액 조회 경로가 `04_API.md`에 없어 해당 도구는 "확인 필요"로 두었습니다.


## 갱신 규칙

`01_PRD.md`~`05_DATA_MODEL.md`, `SECURITY.md`를 고치면 이 그림도 같은 변경에서 함께 고칩니다. 검증은 `validate.py`로 모든 Mermaid 블록이 렌더링되는지 확인합니다.
