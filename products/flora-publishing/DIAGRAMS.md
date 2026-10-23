# DIAGRAMS: FLORA Publishing UML 시각화

작성일 2026-10-23. 정본은 이 폴더의 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid).

**제품 한 줄 정의**: 원고는 있지만 편집·조판 경험이 없는 1인 작가가 AI와 함께 기획, 집필, 판형 조정을 거쳐 인쇄용 PDF와 ePub을 완성하는 전자책 출판 SaaS(`README.md` 1절).

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`, `MCP.md`, 공통 맥락은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`.

**표기**: 실선 화살표는 호출·데이터 흐름, 점선은 검증·참조·주기 실행입니다. "(제안)"은 문서가 제안이라고 밝힌 값입니다. 기능 ID `PB-F-###`는 `01_PRD.md` 3장, `PB-06-###`는 `06_AGENT_PLAN.md`의 작업입니다. 보안 규칙 번호 `§n`은 `SECURITY_BASELINE.md`의 장 번호입니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-a | 작가가 쓰는 기능 (MVP) | 유스케이스 | `01_PRD.md` 2·3장, `03_SCREENS_UX.md` 1절 |
| 1-b | 역할별 추가 기능과 Phase 구분 | 유스케이스 | `01_PRD.md` 2장, 3.1절 |
| 2-a | 배포 단위와 호출 관계 | 컴포넌트 | `02_ARCHITECTURE.md` 2·3·7절 |
| 2-b | 에이전트 실행 계층 (제품 고유 모듈) | 컴포넌트 | `02_ARCHITECTURE.md` 10절, `04_API.md` 9절 |
| 3 | 데이터 모델 | 클래스 | `05_DATA_MODEL.md` 1·2·4절 |
| 4-a | 전체 순차 생성 | 시퀀스 | `01_PRD.md` PB-F-017·047·057, `02_ARCHITECTURE.md` 4절, `04_API.md` 2절 |
| 4-b | 검수 승인 | 시퀀스 | `01_PRD.md` PB-F-058, `02_ARCHITECTURE.md` 10.3절, `04_API.md` 9.1절 |
| 4-c | 크레딧팩 결제 | 시퀀스 | `01_PRD.md` PB-F-035, `03_SCREENS_UX.md` 2.3절, `04_API.md` 2·5절 |
| 4-d | PDF 내보내기 | 시퀀스 | `01_PRD.md` PB-F-024·026, `02_ARCHITECTURE.md` 4절, `04_API.md` 2절 |
| 5-a | books 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-b | sections 생성 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절, `02_ARCHITECTURE.md` 10.3절 |
| 5-c | generation_runs 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-d | agent_tasks 실행 상태 | 상태 머신 | `05_DATA_MODEL.md` 2.5·3절 |
| 5-e | agent_tasks 검수 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절, `04_API.md` 3절 |
| 5-f | book_exports 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-g | manuscript_uploads 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 6-a | 작가 핵심 화면 흐름 | 화면 흐름 | `03_SCREENS_UX.md` 1·2·10절 |
| 6-b | 에이전트·결제·설정·운영 화면 흐름 | 화면 흐름 | `03_SCREENS_UX.md` 1·8·10절 |
| 7-a | 보안 신뢰 경계 | 배치+흐름 | `01_PRD.md` 6절, `02_ARCHITECTURE.md` 6절, `05_DATA_MODEL.md` 7절 |
| 7-b | 위협과 통제 지도 | 블록 | `02_ARCHITECTURE.md` 6절, `05_DATA_MODEL.md` 7절 |
| 8-1 | 웹 경로와 MCP 층 (제안) | 컴포넌트 | `MCP.md` 2·3절, `04_API.md` 1절 |
| 8-2 | 내보내기 준비와 사람 확정 | 시퀀스 | `MCP.md` 6절, `04_API.md` 2절 |
| 8-3 | 도구 위험 등급과 노출 단계 | 블록 | `MCP.md` 1·2절 |

## 1. 사용자와 기능

역할은 코어 조직 역할 owner, admin, member, viewer와 운영자 platform_admin입니다(`03_SCREENS_UX.md` 1절). 플랜은 Free와 Basic 둘이며 Basic에서만 열리는 기능에 "(Basic)"을 붙였습니다.

### 그림 1-a. 작가가 쓰는 기능 (MVP)

읽는 법: 왼쪽 역할이 오른쪽 기능을 씁니다. viewer는 읽기 전용입니다. 괄호의 ID는 `01_PRD.md` 3장 기능 번호이고, AI 묶음 5개는 모두 MVP입니다.

```mermaid
flowchart LR
  W(["작가<br/>owner·admin·member"])
  V(["viewer<br/>읽기 전용"])

  subgraph BOOK["'책 만들기'"]
    A1["10단계 위저드<br/>PB-F-006"]
    A2["원고 업로드 (Basic)<br/>PB-F-027"]
    A3["전체 순차 생성 (Basic)<br/>PB-F-017"]
    A4["에디터와 마이크로 프롬프트<br/>PB-F-018"]
    A5["AI 표지 3후보<br/>PB-F-021"]
    A6["PDF·ePub 내보내기<br/>PB-F-024·025"]
  end

  subgraph AIB["'AI·음성'"]
    B1["책별 자료 RAG<br/>PB-F-045"]
    B2["책 설정집 위키<br/>PB-F-046"]
    B3["글쓰기 도우미 채팅<br/>PB-F-049"]
    B4["받아쓰기와 낭독 미리듣기<br/>PB-F-050·052"]
    B5["검수 대기함<br/>PB-F-057·058"]
  end

  PAY["크레딧팩·Basic 구독<br/>PB-F-035"]

  W --> A1
  W --> A2
  W --> A3
  W --> A4
  W --> A5
  W --> A6
  W --> B1
  W --> B2
  W --> B3
  W --> B4
  W --> B5
  W --> PAY
  V -.->|"열람만"| A4
  V -.->|"열람만"| A6
```

### 그림 1-b. 역할별 추가 기능과 Phase 구분

읽는 법: MVP(P1)은 MVP 범위지만 우선순위가 P1인 기능, Phase 2 이후와 폐기·범위 제외는 문서의 구분 그대로입니다. 점선은 "아직 만들지 않음"입니다.

```mermaid
flowchart LR
  OA(["owner·admin"])
  PA(["platform_admin"])
  W(["작가"])

  subgraph P1["'MVP (P1)'"]
    C1["웹훅 알림 연동<br/>PB-F-036"]
    C2["에이전트 작업 공간<br/>PB-F-059"]
    C3["에디터 3단과 AI 패널<br/>PB-F-060"]
    C4["운영 콘솔<br/>PB-F-061"]
    C5["나만의 페르소나 합성<br/>PB-F-011"]
    C6["옴니버스 모드<br/>PB-F-020"]
  end

  subgraph P2["'Phase 2'"]
    D1["공개 책 페이지<br/>PB-F-040"]
    D2["번역<br/>PB-F-041"]
    D3["워크플로 빌더<br/>PB-F-062"]
    D4["콘텐츠 에이전트<br/>PB-F-063"]
    D5["오디오북 전권<br/>PB-F-042"]
  end

  E1["판매·정산<br/>Phase 3 이후"]
  E2["사진집·룩북·캔버스<br/>폐기"]
  E3["교육 프로그램<br/>범위 제외"]

  OA --> C1
  PA --> C4
  W --> C2
  W --> C3
  W --> C5
  W --> C6
  OA -.-> D1
  W -.-> D2
  W -.-> D3
  W -.-> D4
  W -.-> D5
  OA -.-> E1
  W -.-> E2
  W -.-> E3
```

## 2. 구성요소

### 그림 2-a. 배포 단위와 호출 관계

읽는 법: 위가 사용자 쪽, 아래가 데이터입니다. 브라우저는 web만 부르고 Dify·FastAPI·제공자는 web이나 워커가 대신 부릅니다. 코어 부분은 `core` 한 상자로 줄였습니다.

```mermaid
flowchart TB
  BR["브라우저"]

  subgraph VER["'Vercel: web (Next.js)'"]
    RH["Route Handler<br/>requireSession 후 zod"]
    AG["에이전트 레지스트리<br/>withAgentTask"]
    GW["AI 게이트<br/>/api/ai · /api/voice"]
  end

  subgraph RLW["'Railway'"]
    WK["TS 워커<br/>생성·표지·웹훅·purge"]
    EN["출판 엔진 FastAPI<br/>파싱·HTML 조립·ePub"]
    RS["render-weasyprint<br/>private, astro 공용"]
    AI["AI 서비스 api/<br/>라우터·RAG·위키·그래프"]
  end

  subgraph SB["'Supabase 모듈러'"]
    CORE["core<br/>크레딧·잡·감사·AI 표"]
    PUB["publishing 스키마<br/>테이블 13개"]
    ST["Storage<br/>org-files · exports"]
  end

  DIFY["Dify 공용<br/>publishing-chat"]
  GPU["공용 GPU 서버<br/>oss-llm · oss-embed · oss-voice"]
  LLM["상용 LLM"]
  EL["ElevenLabs"]
  FAL["fal 표지"]
  TOSS["Toss Payments"]

  BR --> RH
  BR --> GW
  RH -->|"세션 + RLS"| PUB
  RH -->|"service_role"| CORE
  AG --> PUB
  RH -->|"내부 토큰 (미리보기)"| EN
  GW -->|"EdDSA 서명 토큰"| AI
  GW -->|"user + 대화 id"| DIFY
  DIFY -->|"내부 키"| AI
  GW -->|"국외 동의 조직만"| EL
  AI --> GPU
  AI --> LLM
  WK -->|"claim · complete"| CORE
  WK -->|"잡 토큰"| AI
  WK --> FAL
  EN -->|"X-Render-Token"| RS
  EN --> ST
  RH <-->|"confirm · 웹훅"| TOSS
  FAL -.->|"완료 웹훅"| RH
```

### 그림 2-b. 에이전트 실행 계층 (제품 고유 모듈)

읽는 법: 새 실행 엔진은 없습니다. 기존 Route Handler를 `withAgentTask`가 감싸 `agent_tasks` 1행을 만들고, 잡을 끝내는 쪽이 그 행을 갱신합니다. 점선은 주기 동기화와 읽기 경로입니다.

```mermaid
flowchart LR
  REQ["작가 요청<br/>request_id"]
  REG["registry.ts<br/>6 에이전트 · 동작"]
  WAT["withAgentTask<br/>멱등 org_id + request_id"]
  OLD["기존 처리 함수<br/>동기 호출 또는 enqueue"]
  AT[("agent_tasks")]
  LED[("credit_ledger<br/>ref_type agent_task")]
  JOB[("core.jobs<br/>payload agent_task_id")]
  FIN["잡 종료 측 갱신<br/>worker · engine · api"]
  SYNC["agent-sync 크론<br/>워커 5분마다"]
  DEC["decision API<br/>decide_agent_task"]
  OPS["운영 콘솔<br/>/api/admin/*"]

  REQ --> REG --> WAT
  WAT -->|"INSERT queued"| AT
  WAT --> OLD
  OLD -->|"선차감 consume_credits"| LED
  OLD -->|"enqueue_job"| JOB
  JOB --> FIN
  FIN -->|"상태 · 사용 크레딧 · pending"| AT
  SYNC -.->|"낡은 queued 환불 · 30일 pending 만료"| AT
  AT --> DEC
  OPS -.->|"agent_tasks → jobs → ai_runs → ledger"| AT
```

## 3. 데이터 모델

### 그림 3. publishing 스키마 핵심 테이블 11개와 코어 참조 2개

읽는 법: 화살표는 외래키 방향입니다. 모든 테넌트 테이블은 `org_id`를 갖고 하위 표는 `(book_id, org_id)` 복합 FK로 다른 조직 행을 참조할 수 없습니다. 접근 주체는 각 클래스 옆 노트에 적었습니다. 이 스키마는 테이블 13개이며 그림에서 `member_settings`와 `waitlist`는 뺐습니다(`waitlist`는 테넌트가 아니고 사용자 정책이 없습니다).

```mermaid
classDiagram
  class books {
    id uuid
    org_id uuid
    title text
    format_key text
    persona_id text
    status text
    current_step smallint
    source text
    is_public boolean
    deleted_at timestamptz
  }
  class chapters {
    id uuid
    book_id uuid
    position smallint
    title text
  }
  class sections {
    id uuid
    chapter_id uuid
    position smallint
    body_html text
    gen_status text
    last_job_id uuid
    revision integer
  }
  class cover_images {
    id uuid
    book_id uuid
    style text
    provider text
    storage_path text
    status text
    job_id uuid
  }
  class manuscript_uploads {
    id uuid
    book_id uuid
    storage_path text
    ext text
    bytes integer
    status text
    raw_deleted_at timestamptz
  }
  class book_exports {
    id uuid
    book_id uuid
    format text
    status text
    job_id uuid
    credit_ledger_id bigint
    content_hash text
    watermark boolean
    expires_at timestamptz
  }
  class generation_runs {
    id uuid
    book_id uuid
    kind text
    mode text
    parent_job_id uuid
    status text
    credits_estimated integer
    credits_used integer
    cancel_requested_at timestamptz
  }
  class agent_tasks {
    id uuid
    book_id uuid
    agent_key text
    action text
    origin text
    status text
    approval_status text
    job_id uuid
    generation_run_id uuid
    ai_run_id uuid
    credit_ledger_id bigint
    request_id text
    retry_of uuid
    attempt smallint
  }
  class custom_personas {
    id uuid
    name text
    base_persona_ids text
    status text
  }
  class webhook_endpoints {
    id uuid
    url text
    events text
    secret_credential_id uuid
    status text
    consecutive_failures integer
  }
  class webhook_deliveries {
    id bigint
    endpoint_id uuid
    event_id uuid
    status text
    http_status integer
    attempts integer
    next_attempt_at timestamptz
  }
  class core_jobs {
    id uuid
    status text
  }
  class core_credit_ledger {
    id bigint
    ref_type text
    ref_id text
    refund_of bigint
  }

  books "1" --> "*" chapters : 포함
  chapters "1" --> "*" sections : 포함
  books "1" --> "*" cover_images : 표지 후보
  books "1" --> "*" book_exports : 내보내기
  books "1" --> "*" generation_runs : 생성 실행
  books "1" --> "*" agent_tasks : 에이전트 작업
  books "1" --> "*" manuscript_uploads : 업로드 선택
  books "*" --> "0..1" custom_personas : custom_persona_id
  sections "*" --> "0..1" core_jobs : last_job_id
  book_exports "*" --> "0..1" core_jobs : job_id
  book_exports "*" --> "0..1" core_credit_ledger : 차감 행
  generation_runs "*" --> "0..1" core_jobs : parent_job_id
  agent_tasks "*" --> "0..1" core_jobs : job_id
  agent_tasks "*" --> "0..1" generation_runs : 실행 단위
  agent_tasks "*" --> "0..1" core_credit_ledger : 첫 차감 행
  agent_tasks "*" --> "0..1" agent_tasks : retry_of
  webhook_endpoints "1" --> "*" webhook_deliveries : 전송 기록

  note for books "읽기 조직 멤버 + 엔타이틀먼트. 쓰기 owner admin member. 삭제 owner admin. 공개 전환은 RPC만"
  note for sections "컬럼 단위 GRANT. gen_status last_job_id revision은 사용자 쓰기 제외. 전이는 트리거"
  note for agent_tasks "멤버는 SELECT만. 쓰기는 서버 service_role. 검수 결정은 RPC decide_agent_task"
  note for book_exports "서버 전용 쓰기. cover_images manuscript_uploads generation_runs도 같음"
  note for webhook_endpoints "owner admin만 SELECT. 비밀은 core.encrypted_credentials. 평문 컬럼 없음"
  note for custom_personas "INSERT는 서버만. 사용자는 name status만 수정"
```

## 4. 핵심 시퀀스

### 그림 4-a. 전체 순차 생성 (PB-F-017, 047, 057)

읽는 법: 위쪽은 web이 하는 일(권한, 한도, 선차감 직전 검사)이고 아래쪽은 워커가 챕터 단위로 그래프를 돌리는 반복입니다. `request_id`는 멱등 키이며 크레딧은 소제목마다 선차감되고 실패하면 환불됩니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 작가
  participant W as web Route Handler
  participant D as core + publishing DB
  participant K as TS 워커
  participant A as AI 서비스 api

  U->>W: POST /api/books/id/write-all (request_id, mode)
  W->>W: requireSession → zod → 레이트 리밋 → features write_all
  alt 잔액이 예상 합계보다 적음
    W-->>U: 402 (required, balance)
  end
  W->>D: generation_runs INSERT + agent_tasks INSERT (멱등 org_id + request_id)
  alt 책당 진행 중 실행이 있음
    D-->>W: 23505
    W-->>U: 409
  end
  W->>D: enqueue_job 부모 잡 (키 job:publishing:request_id)
  W-->>U: 접수됨 (run, estimated_credits)
  K->>D: claim_jobs publishing.llm
  loop 챕터마다 동시 창 3
    K->>D: consume_credits (소제목마다 멱등 키)
    alt CR001
      K->>D: 남은 챕터 skipped 처리 후 중단
    end
    K->>W: POST /api/internal/ai-token (X-Worker-Key, job_id)
    W-->>K: 잡 토큰 (org는 잡 행에서만)
    K->>A: POST /graphs/publishing.draft/runs
    A->>A: 토큰 검증 → books.org_id 일치 → outline → draft → consistency → proofread → compliance
    K->>A: GET /graphs/runs/id (2초 간격)
    A-->>K: 출력
    K->>D: zod 재검증 → sanitize → 빈 소제목은 generated 저장, 본문 있던 소제목은 제안으로만
  end
  alt 소제목 3회 실패
    K->>D: fail_job 환불
  end
  K->>D: complete_job + agent_tasks 갱신 (pending)
  D-->>U: Realtime 진행률
```

### 그림 4-b. 검수 승인 (PB-F-058)

읽는 법: 제안 본문은 새 저장소 없이 `core.jobs.result` 등 기존 위치에서 읽습니다. 반영(PATCH)은 사용자 세션과 RLS 그대로이고, 결정 기록만 RPC가 합니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 작가
  participant W as web Route Handler
  participant D as publishing DB

  U->>W: GET /api/agent-tasks/id
  W->>D: agent_tasks + 제안 읽기 (RLS 멤버)
  W-->>U: task, timeline, review.items
  U->>W: PATCH /api/books/id/sections/sid (revision)
  W->>D: sections UPDATE (사용자 세션, RLS)
  alt revision 불일치
    D-->>W: 충돌
    W-->>U: 409 stale_revision
  end
  U->>W: POST /api/agent-tasks/id/decision (approved 또는 partially_applied 또는 rejected)
  W->>W: requireSession → zod
  W->>D: RPC decide_agent_task (편집자만, pending만)
  alt pending이 아님
    D-->>W: 오류
    W-->>U: 409
  end
  D->>D: approval_decided_at 기록 + 감사 agent_task.decide
  W->>D: 승인한 AI 초안은 edited로, 거부한 초안은 본문 비우고 empty로 (서버 경로)
  W-->>U: task (approval_status 갱신)
```

### 그림 4-c. 크레딧팩 결제 (PB-F-035)

읽는 법: 주문은 서버가 먼저 저장하고 금액의 정본은 서버 주문입니다. 지급은 confirm 경로에서만 일어나며 웹훅은 상태 동기화 보조입니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as owner admin
  participant W as web Route Handler
  participant T as Toss Payments
  participant D as core DB

  U->>W: POST /api/billing/orders (kind credit_pack, code)
  W->>W: requireSession → 역할 owner admin 확인
  W->>D: payment_orders INSERT (서버가 금액 결정)
  W-->>U: orderId, amountKrw, customerKey
  U->>T: 결제창에서 결제
  T-->>U: 성공 복귀 /dashboard/billing/success
  U->>W: POST /api/billing/confirm (paymentKey, orderId, amount)
  W->>T: confirm 요청
  W->>D: confirm_payment_order (서버 주문 금액과 대조)
  alt 금액 불일치 PM001
    W->>T: 승인 취소 요청
    W-->>U: 409 + 운영 알림
  end
  D->>D: pack 버킷 grant 원장 1행 (멱등)
  W-->>U: payment, balance
  T-->>W: POST /api/webhooks/toss (서명 검증 + 멱등)
  W->>D: webhook_events (상태 동기화만)
```

### 그림 4-d. PDF 내보내기 (PB-F-024, 026)

읽는 법: 워터마크는 서버가 `features.watermark`로 정하고 클라이언트 값은 무시합니다. 같은 내용 해시의 결과가 있으면 재사용하며 크레딧은 0입니다. 실패하면 자동 환불됩니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 작가
  participant W as web Route Handler
  participant D as core + publishing DB
  participant E as 출판 엔진
  participant R as render-weasyprint
  participant S as Storage exports

  U->>W: POST /api/books/id/exports (request_id, format pdf, options)
  W->>W: requireSession → zod → 레이트 리밋 → 월 내보내기 한도 확인
  alt Free 월 2회 초과
    W-->>U: 403 plan_limit
  end
  W->>E: POST /internal/content-hash (내부 토큰)
  alt 같은 해시의 결과가 있음
    W-->>U: export, reused true (0 크레딧)
  end
  W->>D: consume_credits 2 (멱등 키 request_id)
  alt CR001
    W-->>U: 402
  end
  W->>D: book_exports INSERT + enqueue_job render.pdf
  W-->>U: export (queued)
  E->>D: claim_jobs publishing.render
  E->>D: book_id로 DB에서 원고 읽기 (클라이언트 HTML 없음)
  E->>E: HTML 조립 + nh3 재sanitize + 판형 프리셋
  E->>R: POST /render/pdf (X-Render-Token)
  R->>S: PDF 저장 (url_fetcher 허용 목록만)
  alt 렌더 실패
    E->>D: fail_job 자동 환불 + 웹훅 export.failed
  end
  E->>D: complete_job → book_exports succeeded + 웹훅 export.succeeded
  U->>W: GET /api/exports/id/download
  W-->>U: 302 서명 URL (7일)
```

## 5. 상태 머신

모든 전이는 DB 트리거로 강제되어 service_role 쓰기에도 적용됩니다. 전이를 일으키는 주체를 화살표 라벨에 적었습니다.

### 그림 5-a. books.status

읽는 법: 사용자나 서버가 바꿉니다. writing 진입 때 서버가 Taste를 고정하고, completed가 되면 웹훅 `book.completed`가 나가며, 완성을 해제하면 `is_public=false`가 됩니다.

```mermaid
stateDiagram-v2
  [*] --> draft
  draft --> writing : 사용자·서버 (Taste 고정)
  draft --> archived : 사용자·서버
  writing --> draft : 사용자·서버
  writing --> ready : 사용자·서버
  writing --> archived : 사용자·서버
  ready --> writing : 사용자·서버
  ready --> completed : 사용자·서버 (book.completed)
  ready --> archived : 사용자·서버
  completed --> writing : 사용자·서버 (is_public 해제)
  completed --> archived : 사용자·서버
  archived --> draft : 사용자·서버
```

### 그림 5-b. sections.gen_status

읽는 법: 생성 흐름은 서버(워커)가 queued → generating → generated 또는 failed로 옮깁니다. 사용자가 본문을 고치면 트리거가 edited로 바꾸고, 생성 중(queued·generating)의 사용자 편집은 `PB005`로 막힙니다. 검수에서 승인한 AI 초안은 edited, 거부한 초안은 본문을 비우고 empty로 돌아갑니다.

```mermaid
stateDiagram-v2
  [*] --> empty
  empty --> queued : 서버·워커
  edited --> queued : 서버·워커
  generated --> queued : 서버·워커
  failed --> queued : 서버·워커
  queued --> generating : 서버·워커
  generating --> generated : 서버·워커
  generating --> failed : 서버·워커
  empty --> edited : 사용자 편집 (트리거)
  generated --> edited : 사용자 편집 또는 검수 승인
  generated --> empty : 검수 거부 (본문 비움)
```

### 그림 5-c. generation_runs.status

읽는 법: 서버만 바꾸고, 취소 요청은 RPC `request_generation_cancel`이 접수합니다. 책당 진행 중 실행은 부분 유니크 인덱스로 1개입니다.

```mermaid
stateDiagram-v2
  [*] --> queued
  queued --> running : 서버
  queued --> canceled : 서버 (취소 RPC)
  queued --> failed : 서버
  running --> succeeded : 서버
  running --> partial : 서버
  running --> failed : 서버
  running --> canceled : 서버 (대기 자식 환불)
  succeeded --> [*]
  partial --> [*]
  failed --> [*]
  canceled --> [*]
```

### 그림 5-d. agent_tasks.status

읽는 법: 서버가 기록기(`withAgentTask`)와 잡 종료 측에서 바꿉니다. 재시도는 상태 전이가 아니라 새 행(`retry_of`, `attempt` 증가)이며 failed, partial, canceled에서만 허용됩니다(`PB013`).

```mermaid
stateDiagram-v2
  [*] --> queued
  queued --> running : 서버
  queued --> canceled : 서버
  queued --> failed : 서버 (402 또는 stale_queued)
  running --> succeeded : 서버
  running --> partial : 서버
  running --> failed : 서버
  running --> canceled : 서버
  failed --> [*] : 재시도는 새 행
  partial --> [*] : 재시도는 새 행
  canceled --> [*] : 재시도는 새 행
  succeeded --> [*]
```

### 그림 5-e. agent_tasks.approval_status

읽는 법: pending이 되는 때는 실행 상태가 succeeded, partial, canceled일 때뿐입니다(서버). 결정 3종은 사용자가 RPC `decide_agent_task`로, 만료는 서버가 30일 뒤 처리합니다.

```mermaid
stateDiagram-v2
  [*] --> not_required
  not_required --> pending : 서버 (승인 정책이 pending)
  pending --> approved : 사용자 RPC
  pending --> partially_applied : 사용자 RPC
  pending --> rejected : 사용자 RPC
  pending --> expired : 서버 (30일)
  approved --> [*]
  partially_applied --> [*]
  rejected --> [*]
  expired --> [*]
```

### 그림 5-f. book_exports.status

읽는 법: 서버만 바꿉니다. 성공한 파일은 정리 잡(purge)이 만료시키며 이때 파일이 삭제됩니다.

```mermaid
stateDiagram-v2
  [*] --> queued
  queued --> running : 서버
  queued --> failed : 서버
  queued --> canceled : 서버
  running --> queued : 서버 (재시도)
  running --> succeeded : 서버
  running --> failed : 서버
  succeeded --> expired : 서버 (purge, 파일 삭제)
  failed --> [*]
  canceled --> [*]
  expired --> [*]
```

### 그림 5-g. manuscript_uploads.status

읽는 법: 서버가 옮깁니다. 파싱 24시간 뒤 원본을 삭제하고 `raw_deleted_at`을 기록합니다. 파싱 재시도는 parsing에서 uploaded로 되돌아갑니다.

```mermaid
stateDiagram-v2
  [*] --> pending_upload
  pending_upload --> uploaded : 서버 (complete 재검사)
  uploaded --> parsing : 서버
  parsing --> parsed : 서버
  parsing --> failed : 서버
  parsing --> uploaded : 서버 (재시도)
  parsed --> expired : 서버
  failed --> expired : 서버
  expired --> [*]
```

## 6. 화면 흐름

### 그림 6-a. 작가 핵심 화면 흐름

읽는 법: 실선은 사용자 이동, 점선은 조건부 이동입니다. 책 안 화면(위저드, 에디터, 설정집, 완성)은 좌측 GNB 대신 책 머리줄 셸을 씁니다(`03_SCREENS_UX.md` 10.4절, 기본값은 결정 대기 D33).

```mermaid
flowchart TB
  LAND["/ 랜딩 3D 히어로"]
  SIGN["/signup · /login"]
  CB["/auth/callback"]
  ONB["/onboarding<br/>AI 처리 방식 선택"]
  HOME["/dashboard 홈"]
  BOOKS["/dashboard/books 내 책"]
  NEW["/dashboard/books/new<br/>시작 방식 선택"]
  UP["/dashboard/books/new/upload<br/>Basic"]
  WIZ["/books/id/wizard?step=1..10"]
  ED["/books/id/editor"]
  WIKI["/books/id/wiki<br/>설정집"]
  FIN["/books/id/finish<br/>미리보기와 내보내기"]

  LAND --> SIGN --> CB --> ONB --> HOME
  HOME --> BOOKS
  HOME --> NEW
  NEW -->|"AI로 만들기 · 시드 3종"| WIZ
  NEW -.->|"내 원고로 시작"| UP
  UP --> WIZ
  BOOKS --> WIZ
  BOOKS --> ED
  WIZ -->|"7단계 집필"| ED
  ED <--> WIKI
  WIZ -->|"10단계"| FIN
  ED --> FIN
  FIN -.->|"PB001·402 등"| BOOKS
```

### 그림 6-b. 에이전트·결제·설정·운영 화면 흐름

읽는 법: 402를 만나면 결제 화면으로, 작업 실패나 검수는 에이전트 화면에서 처리합니다. `/admin`은 platform_admin 전용 별도 셸입니다.

```mermaid
flowchart TB
  HOME["/dashboard 홈"]
  AG["/dashboard/agents<br/>에이전트 · 검수 대기 · 실행 이력 · 대화"]
  TASK["/dashboard/agents/tasks/id<br/>타임라인 · 검수 · 재시도"]
  BILL["/dashboard/billing<br/>잔액 · 팩 구매 · 구독"]
  TOSS["Toss 결제창"]
  OK["/dashboard/billing/success"]
  NG["/dashboard/billing/fail"]
  SET["/dashboard/settings<br/>테마 · AI 처리 방식 · 계정 삭제"]
  WH["/dashboard/settings/webhooks<br/>Basic"]
  PER["/dashboard/personas"]
  ADM["/admin 운영 홈<br/>platform_admin"]
  ADS["/admin/users · books · agents<br/>jobs · billing · settings · audit"]

  HOME --> AG --> TASK
  HOME --> BILL
  HOME --> SET
  HOME --> PER
  SET --> WH
  BILL --> TOSS
  TOSS --> OK
  TOSS --> NG
  OK --> BILL
  NG --> BILL
  AG -.->|"402 잔액 부족"| BILL
  HOME -.->|"운영자 링크"| ADM
  ADM --> ADS
```

## 7. 보안 경계

`SECURITY.md`는 현재 초안(자산·위협·수치 표가 "작성 필요")이어서, 아래 그림은 `01_PRD.md` 6장, `02_ARCHITECTURE.md` 6절, `05_DATA_MODEL.md` 7절의 차단 설계에서 구성했습니다. 공통 규칙은 `SECURITY_BASELINE.md`의 장 번호로만 참조합니다.

### 그림 7-a. 보안 신뢰 경계

읽는 법: 위에서 아래로 갈수록 데이터에 가깝고, 각 구역은 앞 구역을 믿지 않고 스스로 다시 검사합니다. 지켜야 할 자산은 원고(DB·Storage), 크레딧·결제, 웹훅 비밀·빌링키(`core.encrypted_credentials`, `core.billing_keys`), 서명 개인키(Next.js만)입니다.

```mermaid
flowchart TB
  subgraph Z0["'1 신뢰하지 않는 영역'"]
    B["브라우저·봇·외부 호출자"]
  end

  subgraph Z1["'2 입구 (Vercel)'"]
    H["보안 헤더·세션<br/>§18"]
    RL["레이트 리밋<br/>생성 조직 60/분 · 로그인 IP 10/10분<br/>§8 · §21"]
  end

  subgraph Z2["'3 web 서버 (신뢰)'"]
    AZ["requireSession 첫 줄<br/>플랜은 서버가 판정 §11"]
    VAL["zod · sanitize 허용 목록<br/>업로드 경로 서버 생성 §10"]
    CR["유료 동작은 선차감 후 처리<br/>실패 시 환불 §4"]
    TK["서명 토큰 개인키 보관<br/>§16"]
  end

  subgraph Z3["'4 데이터 (최종 방어선)'"]
    RLS["RLS + 컬럼 GRANT 제외<br/>전이·쿼터 트리거 §1 · §4"]
    ENC["웹훅 비밀·빌링키 암호화<br/>§5"]
    AUD["감사 로그 2년<br/>§9"]
  end

  subgraph Z4["'5 AI·외부 (제한 신뢰)'"]
    FP["api: 토큰 검증 · org 일치<br/>국외 동의 필터 §16"]
    DF["Dify: 내부 키만<br/>토큰 전달 금지"]
    WH["Toss·fal 웹훅<br/>서명 + 멱등 §6"]
  end

  subgraph Z5["'6 워커·렌더 (비공개)'"]
    WK["워커: LLM 키 없음"]
    RS["렌더: private · 토큰<br/>url_fetcher 허용 목록 §10"]
  end

  B -->|"모든 요청"| Z1
  Z1 --> Z2
  Z2 -->|"세션 + RLS"| RLS
  Z2 -->|"service_role (서버만)"| RLS
  Z2 --> FP
  Z2 --> DF
  WH --> Z2
  WK -->|"잡 토큰"| FP
  WK --> RLS
  Z2 -->|"내부 토큰"| RS
  RLS --> ENC
  RLS --> AUD
```

### 그림 7-b. 위협과 통제 지도

읽는 법: 왼쪽 위협은 리뷰에서 확인된 "높음" 결함이고 오른쪽이 이 제품의 차단 설계입니다(`02_ARCHITECTURE.md` 6절, `05_DATA_MODEL.md` 7절). 위협 이름 뒤 괄호는 원본 리뷰 번호입니다.

```mermaid
flowchart LR
  T1["무인증 LLM·내보내기<br/>Flora-v2 #3"]
  T2["플랜 자기 상향<br/>Flora-v2 #4 · #5"]
  T3["결제 웹훅 위조<br/>flora #2"]
  T4["업로드 경로 조작<br/>flora #4"]
  T5["SSRF·렌더 외부 fetch<br/>flora #5"]
  T6["범용 프록시 토큰 유출<br/>flora-publisher #1"]
  T7["크레딧 차감·환불 누락<br/>SellingDocs #2"]
  T8["개인정보 원고의 국외 이전<br/>PB-F-044 · 056"]

  C1["Route Handler requireSession<br/>엔진·렌더·api 비공개 + 토큰"]
  C2["plans·entitlements는 SELECT만<br/>쿼터 PB001~004 트리거"]
  C3["서명 실패 401<br/>지급은 confirm 경로만"]
  C4["서버 생성 경로 + 경로 CHECK<br/>원래 파일명은 표시용"]
  C5["cover_image_id만 받음<br/>url_fetcher 허용 호스트"]
  C6["프록시 이식 금지<br/>고정 제공자 URL만"]
  C7["원장 멱등 + 원자 차감<br/>재시도는 refund_missing 409"]
  C8["국외 이전 동의 필터<br/>책 단위 오픈소스 전용"]

  T1 --> C1
  T2 --> C2
  T3 --> C3
  T4 --> C4
  T5 --> C5
  T6 --> C6
  T7 --> C7
  T8 --> C8
```

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)는 같은 서버 계층과 RLS 조회를 거칩니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)입니다. 이 제품은 원고 본문을 도구로 내보내지 않는 것이 기본입니다.

### 8-1. 웹 경로 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["브라우저 작가"]
    AG["AI 에이전트<br/>작가 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    RH["Next.js Route Handler<br/>requireSession 후 zod"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>Bearer 토큰 필수"]
    RL["레이트 리밋 사용자"]
    TL["도구 7개<br/>필드 허용 목록 출력"]
    SAN["제목 파일 이름 untrusted 처리<br/>본문 Diff 제외"]
  end

  subgraph DB["DB 최종 방어선"]
    RLS["RLS 멤버십 엔타이틀먼트<br/>books chapters sections agent_tasks"]
    CORE["core 위키 ai_documents<br/>읽기 경로 D-M5"]
  end

  subgraph NO["MCP가 부르지 않는 것"]
    CR["크레딧 차감 AI 호출<br/>렌더 내보내기 결제"]
  end

  BR --> RH
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  RH -->|"사용자 세션"| RLS
  RH --> CR
  TL -->|"사용자 토큰 D-M3"| RLS
  TL -.->|"RLS 확인 후 D-M5"| CORE
  TL -.->|"확인 링크 D-M4"| RH
```

### 8-2. 내보내기 준비와 사람 확정 (`publishing_prepare_export`)

```mermaid
sequenceDiagram
  autonumber
  actor W as 작가
  participant A as AI 에이전트
  participant M as MCP 서버
  participant D as DB RLS 조회
  participant S as 웹 내보내기 화면

  W->>A: 이 책 PDF로 내보내줘
  A->>M: publishing_prepare_export 책 id 형식
  M->>D: 책 상태 읽기 사용자 세션
  D-->>M: 상태 본문 유무
  Note over M: 저장 안 함 크레딧 차감 안 함<br/>exports 생성 호출 안 함
  M-->>A: 가능 여부 예상 크레딧 확정 전 문구 확인 링크 15분
  A-->>W: 내보낼 수 있습니다 아직 시작 전입니다 링크에서 확인하세요
  W->>S: 링크 열기 로그인 세션 일치 확인
  S-->>W: 형식 크레딧 표시
  W->>S: 내보내기 클릭
  S->>D: 기존 exports 경로 크레딧 선차감과 잡 등록
  D-->>S: 접수 또는 402 plan_limit 오류
  S-->>W: 진행 상태 안내
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R1["R1 로그인 읽기 MVP"]
    T1["publishing_list_books"]
    T2["publishing_get_book_outline"]
    T3["publishing_list_agent_tasks"]
    T4["publishing_get_agent_task"]
  end
  subgraph R15["R1 로그인 읽기 1.5"]
    T5["publishing_list_book_references"]
    T6["publishing_list_wiki_pages"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T7["publishing_prepare_export"]
  end
  subgraph NO["만들지 않음"]
    N1["원고 본문 Diff 내보낸 파일"]
    N2["AI 생성 호출 크레딧 소비"]
    N3["작업 승인 출간 유통 ISBN"]
    N4["결제 삭제 공개 전환 계정"]
  end
  R1 --> R15 --> PR
  PR -.->|"사람이 웹에서 확정"| N2
```

## 문서 불일치

| # | 내용 | 그림에서 고른 쪽 |
|---|---|---|
| 1 | `SECURITY.md`가 초안(자산, 위협, 수치 모두 "작성 필요")이어서 보안 그림의 근거가 `01_PRD.md` 6장, `02_ARCHITECTURE.md` 6절, `05_DATA_MODEL.md` 7절로 대체됨. 세션·CSP·감사 보존 등 제품 수치는 `SECURITY.md`에 없음 | 그림 7은 PRD·아키텍처·데이터 모델 문서의 값만 사용. `SECURITY.md` 작성 후 7-a, 7-b를 다시 맞출 것 |
| 2 | `SECURITY.md` 머리말은 공통 규칙을 "1~21장"으로 적지만 `SECURITY_BASELINE.md`에는 22장(제품별 `SECURITY.md`)까지 있음 | 그림은 §1~§21만 참조하므로 영향 없음 |
| 3 | 인증 로그인은 단계(Mock, Google+이메일, 카카오·네이버)로 켜지는데 `03_SCREENS_UX.md` 1절은 `/signup`이 Stage B부터라고 적음 | 그림 6-a는 최종(Stage B 이상) 흐름을 그림. Stage A에서는 `/login` 개발용 패널로 바로 `/dashboard`로 감 |
| 4 | MCP 읽기 경로: `04_API.md` 2.1절의 `GET /api/books/[id]/references`는 `ai_documents`를 service_role로 읽고, 책 구조(chapters, sections)를 읽는 Route Handler는 없음(RLS 직접 조회). MCP는 service_role을 쓰지 않으므로 `MCP.md` D-M5, D-M8 | 그림 8-1은 RLS 조회를 실선, 참고 파일·설정집 읽기를 점선(미확정)으로 그림 |
| 5 | MCP 내보내기 준비: `POST /api/books/[id]/exports`가 검사와 크레딧 차감을 함께 하고 읽기 전용 점검 함수가 없음(`MCP.md` D-M4) | 그림 8-2는 "책 상태 읽기"만 그림. 점검 함수는 확인 필요 |

그림에 못 담은 것: 글쓰기 도우미 채팅·음성·낭독 시퀀스(`03_SCREENS_UX.md` 2.9~2.11절), Basic 구독 빌링키 흐름(2.4절), 웹훅 발신 재시도(5회), 계정 삭제·purge, 로그인 Stage 상세(`AUTH_ROADMAP.md`), 3D 히어로·디자인 시스템.

## 갱신 규칙

- `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`를 고치면 이 파일의 해당 그림도 같은 커밋에서 고친다(상태 전이는 `05_DATA_MODEL.md` 3절 표 그대로 유지).
