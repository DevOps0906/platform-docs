# DIAGRAMS: NOMAD Blog (nomad-blog) UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid).

**제품 한 줄 정의**: 키워드 하나로 AI가 블로그 원고를 쓰고, 제휴 상품 카드와 대가성 문구를 자동으로 넣은 뒤, 네이버 블로그·티스토리·워드프레스에 예약 발행까지 해 주며, 네이버 브랜드커넥트 지원도 자동 제출하는 조직 단위 SaaS입니다(`README.md` 1절).

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`, `MCP.md`(미작성 초안, 아래 "문서 불일치" 참조), 공통 맥락은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`.

**표기**: 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·조건부, "(제안)" = 문서가 확정 전이라고 적은 값. `01_PRD.md` 2절의 범위 표가 "제안"이라 적혀 있어, MVP/Phase 구분은 그 표를 그대로 따랐습니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1 | 사용자와 기능 | 유스케이스(flowchart) | `01_PRD.md` 1절, 2절, 3장 |
| 2 | 구성요소 | 컴포넌트(flowchart) | `02_ARCHITECTURE.md` 2절, 4절, 7절 |
| 3 | 데이터 모델 | 클래스 | `05_DATA_MODEL.md` 1~4절, 6절 |
| 4-1 | AI 원고 생성과 사람 승인 | 시퀀스 | `04_API.md` 2절, 2.1절, 4절, `01_PRD.md` BL-F-051~052 |
| 4-2 | 검사와 발행 | 시퀀스 | `04_API.md` 2절, 4절, `01_PRD.md` BL-F-043~048 |
| 4-3 | 브랜드커넥트 동의·탐색·지원 | 시퀀스 | `04_API.md` 2절, `01_PRD.md` BL-F-030~036 |
| 4-4 | AI 도우미 채팅 한 턴 | 시퀀스 | `04_API.md` 2.1절, 6.2절, `01_PRD.md` BL-F-055 |
| 5-1 | 원고 상태 | 상태 머신 | `05_DATA_MODEL.md` 3.1절 |
| 5-2 | 발행 상태 | 상태 머신 | `05_DATA_MODEL.md` 3.2절 |
| 5-3 | 채널 계정 상태 | 상태 머신 | `05_DATA_MODEL.md` 3.3절 |
| 5-4 | AI 초안 실행(run)과 승인 | 상태 머신 | `02_ARCHITECTURE.md` 5.2절 |
| 6 | 화면 흐름 | flowchart | `03_SCREENS_UX.md` 1절, 2장 |
| 7 | 보안 경계 | flowchart | `04_API.md` 1절, `05_DATA_MODEL.md` 4절, 7절, `01_PRD.md` 6.4절, `SECURITY_BASELINE.md` |
| 8-1 | 웹 경로와 MCP 층 (제안) | 컴포넌트 | `MCP.md` 2·3절, `04_API.md` 1절 |
| 8-2 | 발행 준비와 사람 확정 | 시퀀스 | `MCP.md` 6절, `04_API.md` 2절 |
| 8-3 | 도구 위험 등급과 노출 단계 | 블록 | `MCP.md` 1·2절 |

## 1. 사용자와 기능

읽는 법: 왼쪽은 사람, 가운데는 MVP 기능, 오른쪽은 Phase 2입니다. 기능 옆 번호는 `01_PRD.md`의 기능 ID입니다. 이 제품의 MVP 범위는 문서가 "제안"이라고 밝힌 값입니다.

```mermaid
flowchart LR
  P1(["김지현<br/>직장인 부업 블로거"])
  P2(["박성훈<br/>제휴 마케터 다계정"])
  P3(["이수아<br/>1인 브랜드 워드프레스"])

  subgraph MVP["MVP"]
    W1["키워드 추천·제목 3안<br/>BL-F-010, 013"]
    W2["AI 원고 생성 템플릿 5종<br/>BL-F-011~012, 051"]
    W3["에디터·SEO·태그·다시쓰기<br/>BL-F-014~017"]
    W4["쿠팡 카드 삽입·수동 링크<br/>BL-F-020~023"]
    W5["대가성 문구 자동 삽입<br/>끌 수 없음 BL-F-024"]
    W6["컴플라이언스 검사<br/>BL-F-048"]
    W7["발행 전 사람 승인<br/>BL-F-052"]
    W8["네이버·티스토리·WP 발행<br/>즉시·예약 BL-F-043~047"]
    W9["브랜드커넥트 탐색·지원<br/>BL-F-030~036"]
    W10["제휴 클릭 통계<br/>BL-F-027"]
    W11["자료 RAG·토픽 위키<br/>BL-F-053~054"]
    W12["도우미 채팅·음성<br/>BL-F-055~057"]
  end

  subgraph PH2["Phase 2"]
    X1["인스타그램 카드 BL-F-049<br/>반복 시리즈 BL-F-050"]
    X2["원고에서 클립 대본 OSMU<br/>BL-F-037"]
    X3["무인 자동 지원 규칙<br/>n8n 브릿지·AI 대표 이미지"]
  end

  P1 --> W1
  P1 --> W2
  P1 --> W8
  P2 --> W8
  P2 --> W9
  P2 --> W10
  P3 --> W11
  P3 --> W3
  P3 --> W12
  W1 --> W2
  W2 --> W3
  W3 --> W4
  W4 --> W5
  W5 --> W6
  W2 --> W7
  W6 --> W8
  W9 -.-> X2
  W8 -.-> X1
  W9 -.-> X3
```

## 2. 구성요소

읽는 법: Redis 없이 `core.jobs`가 큐입니다. 웹(Vercel)은 Playwright를 돌리지 않고 잡만 넣으며, 브라우저 자동 조작은 모두 Railway의 `blog-worker`가 합니다. FastAPI는 텍스트와 그래프만 다루고 원고 저장은 워커가 합니다.

```mermaid
flowchart TB
  BR["브라우저<br/>TipTap 에디터"]

  subgraph WEB["Next.js 웹 (Vercel)"]
    RH["Route Handler<br/>requireSession·zod"]
    SV["server 모듈<br/>publish·render·affiliate"]
    GATE["AI 게이트<br/>/api/ai·/api/voice·/api/internal"]
  end

  subgraph SUP["Supabase 모듈러 프로젝트"]
    CORE["core<br/>크레딧·잡·제휴·감사"]
    BLG["blog 스키마<br/>posts 등 4테이블"]
    ST["Storage org-files"]
    RT["Realtime 잡 진행률"]
  end

  subgraph WK["blog-worker (Railway)"]
    WL["워커 루프<br/>claim·heartbeat"]
    CH["채널 어댑터<br/>naver·tistory·wordpress"]
    BC["브랜드커넥트 핸들러<br/>scan·apply·sync"]
  end

  FA["FastAPI apps/api<br/>blog.post_draft·tools"]
  DF["Dify 공용 blog-chat"]
  GPU["공용 GPU 서버<br/>oss-llm·oss-voice"]

  subgraph EXT["외부"]
    NV["네이버 블로그·티스토리<br/>브랜드커넥트"]
    WP["워드프레스 REST"]
    CP["쿠팡파트너스 API"]
    LLM["상용 LLM"]
    EL["ElevenLabs"]
    TOSS["Toss Payments"]
    VID["video 앱<br/>클립형 캠페인"]
  end

  BR --> RH
  RH --> SV
  SV -->|"consume_credits<br/>enqueue_job"| CORE
  SV -->|"사용자 세션 RPC"| BLG
  BR --> GATE
  GATE -->|"EdDSA 서명 토큰"| FA
  GATE --> DF
  GATE --> EL
  DF -->|"내부 키"| FA
  FA --> LLM
  FA --> GPU
  RT -.->|"RLS 하에서 구독"| BR
  WL -->|"claim_jobs"| CORE
  WL -->|"잡 토큰 요청"| GATE
  WL -->|"blog.generate"| FA
  WL --> CH
  WL --> BC
  CH --> NV
  CH --> WP
  BC --> NV
  SV --> CP
  RH <-->|"승인 확인"| TOSS
  RH -.->|"handoff 1회용 URL"| VID
```

## 3. 데이터 모델

읽는 법: `blog` 스키마에는 테이블이 4개뿐이고(위쪽 4개), 제휴·잡·자격증명·AI 실행은 `core`의 테이블을 참조합니다(아래쪽, 열은 문서에 이름이 나온 것만 적었습니다). 사용자는 원고 콘텐츠 열만 직접 쓰고 나머지는 서버·워커·RPC가 씁니다. 별도 AI 테이블은 만들지 않았습니다(`05` 6절).

```mermaid
classDiagram
  class channel_accounts {
    +uuid id
    +uuid org_id
    +text channel
    +uuid credential_id
    +text status
    +timestamptz automation_risk_consented_at
    +timestamptz locked_until
  }
  class posts {
    +uuid id
    +uuid org_id
    +text title
    +jsonb body_json
    +text template
    +text status
    +text compliance_verdict
    +uuid brandconnect_application_id
    +uuid ai_job_id
    +int version
  }
  class post_affiliate_links {
    +uuid post_id
    +uuid link_id
    +text provider
    +text placement
    +jsonb card_snapshot
    +text inserted_by
  }
  class post_publications {
    +uuid id
    +uuid post_id
    +uuid channel_account_id
    +text status
    +timestamptz scheduled_at
    +uuid job_id
    +bool requires_disclosure
    +bool disclosure_included
    +text published_url
    +text idempotency_key
  }
  class encrypted_credentials {
    +uuid id
  }
  class affiliate_links {
    +uuid id
    +text source_app
    +text source_ref
    +bool is_active
  }
  class affiliate_clicks {
    +uuid link_id
  }
  class affiliate_accounts {
    +uuid id
    +text provider
  }
  class affiliate_disclosures {
    +text provider
    +text placement
  }
  class brandconnect_applications {
    +uuid id
    +text target_url
    +text target_kind
    +text source_app
  }
  class jobs {
    +uuid id
    +text status
  }
  class ai_runs {
    +uuid job_id
    +text status
  }

  channel_accounts "*" --> "0..1" encrypted_credentials : credential_id
  affiliate_accounts "*" ..> "0..1" encrypted_credentials : 자격증명 공유 가능
  posts "1" --> "*" post_affiliate_links : 제휴 매핑
  post_affiliate_links "*" --> "1" affiliate_links : link_id
  affiliate_links "1" --> "*" affiliate_clicks : 클릭 기록
  posts "1" --> "*" post_publications : 채널별 발행
  channel_accounts "1" --> "*" post_publications : channel_account_id
  post_publications "*" --> "0..1" jobs : job_id
  posts "*" --> "0..1" jobs : ai_job_id
  jobs "1" <.. "0..1" ai_runs : job_id
  posts "*" --> "0..1" brandconnect_applications : 블로그형만
  post_publications ..> affiliate_disclosures : 문구 필요 여부 계산

  note for posts "RLS: 멤버 + 엔타이틀먼트 조회. 콘텐츠 열 INSERT와 UPDATE는 owner admin member. 보호 열 변경은 42501. DELETE는 owner admin 그리고 draft failed archived만"
  note for channel_accounts "조회만 허용. 쓰기는 service_role과 RPC. 비밀은 encrypted_credentials에만 있음"
  note for post_publications "조회만 허용. 쓰기는 서버와 워커. 문구 미포함이면 publishing 이후 23514"
  note for post_affiliate_links "조회만 허용. 같은 조직과 source_app blog를 트리거가 검사"
  note for affiliate_clicks "클릭 상세 조회는 owner admin"
```

## 4. 핵심 시퀀스

### 4-1. AI 원고 생성과 사람 승인 (BL-F-051, 052)

읽는 법: 크레딧은 먼저 차감하고(`request_id` 멱등) 생성은 잡으로 넘깁니다. 그래프는 `approve` 노드에서 멈춰 사용자 승인을 기다리며, 승인 전에는 발행할 수 없습니다. 이 승인 확인은 DB 불변식이 아니라 서버 규칙입니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler
  participant DB as Supabase core+blog
  participant WK as blog-worker
  participant FA as FastAPI blog.post_draft

  U->>API: POST /api/posts/id/generate (키워드, 템플릿, request_id)
  API->>API: requireSession, zod, 플랜 게이팅 (고품질 모드는 ai_modes)
  API->>DB: consume_credits (그래프 정액 5 또는 8, 자동 삽입 +1)
  API->>DB: posts status generating (service)
  API->>DB: enqueue_job blog.ai blog.generate
  API-->>U: 202 job_id
  DB-->>U: Realtime 진행률
  WK->>API: POST /api/internal/ai-token (X-Worker-Key, job_id)
  API-->>WK: 잡에 묶인 서명 토큰 (scope graph:blog.post_draft)
  WK->>FA: POST /graphs/blog.post_draft/runs
  Note over FA: keyword, retrieve, draft, affiliate_check, seo_check, compliance
  FA-->>WK: approve 노드에서 대기 (ai_runs running)
  WK->>DB: 원고 저장, complete_job, posts status draft
  alt 도달 전 최종 실패
    WK->>DB: fail_job (선차감 자동 환불)
  end
  U->>API: POST /api/posts/id/ai-approve (run_id)
  API->>API: compliance_verdict가 pass 또는 확인된 warn인지 확인
  alt FAIL 미검사 또는 원고가 바뀜
    API-->>U: 409 BL003
  else 정상
    API->>FA: 그래프 재개 (scope graph:blog.post_draft)
    API->>DB: 감사 blog.ai.draft_approved
    API-->>U: 승인됨, 발행 가능
  end
```

### 4-2. 검사와 발행 (BL-F-043~048)

읽는 법: 발행 요청은 서버가 여러 단계를 순서대로 확인한 뒤 발행 행을 만들고, DB 트리거가 마지막 관문(대가성 문구 불변식)을 맡습니다. 발행 버튼을 누른 뒤 결과가 불확실하면 자동 재시도하지 않습니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler
  participant DB as Supabase core+blog
  participant WK as blog-worker
  participant CHN as 네이버 티스토리 WP

  U->>API: POST /api/posts/id/compliance (request_id)
  API->>DB: consume_credits (LLM 단계 1)
  API->>DB: compliance 결과 저장 (verdict)
  opt verdict가 warn
    U->>API: POST /api/posts/id/compliance/ack
    API->>DB: rpc acknowledge_compliance_warning
  end
  U->>API: POST /api/posts/id/publish (targets, scheduled_at, request_id)
  API->>API: 엔타이틀먼트, 월 한도 BL004, 채널 정책 BL006
  API->>API: AI 승인 확인 AI_APPROVAL_REQUIRED, 렌더 미리 검증
  API->>DB: post_publications INSERT (DB 게이트 BL003 BL005)
  API->>DB: enqueue_job blog.publish.channel (run_after = 예약 시각)
  API-->>U: 202 publications
  WK->>DB: claim_jobs, 발행 행 publishing (문구 필요 재계산)
  WK->>DB: acquire_channel_lock (계정당 브라우저 1개)
  WK->>WK: 렌더, 대가성 문구 삽입, sanitize
  WK->>CHN: 발행 (간격 10분, 하루 상한)
  alt 발행 확인
    WK->>DB: published, published_url
  else 버튼 후 URL 미확인
    WK->>DB: unconfirmed (자동 재시도 없음)
  else 버튼 전 실패
    WK->>DB: fail_job 재시도 최대 3회
  end
  WK->>DB: release_channel_lock
  DB-->>U: Realtime 상태 칩
```

### 4-3. 브랜드커넥트 동의·탐색·지원 (BL-F-030~036)

읽는 법: 공식 API가 없어 Playwright로 진행하므로 위험 동의 없이는 지원 잡이 만들어지지 않습니다. 클립형 캠페인은 blog가 지원하지 않고 video로 넘깁니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler
  participant DB as Supabase core+blog
  participant WK as blog-worker
  participant NV as 네이버 브랜드커넥트

  U->>API: POST /api/brandconnect/accounts (owner admin)
  API->>DB: connectAccount (자격증명 공유)
  U->>API: POST /api/brandconnect/accounts/id/consent (notice_version)
  API->>DB: consent_brandconnect_risk + 감사
  alt 고지문 버전이 다름
    API-->>U: 409 NOTICE_OUTDATED
  end
  U->>API: POST /api/brandconnect/scan (하루 4회)
  API->>DB: enqueue_job brandconnect.scan
  WK->>NV: 공개 캠페인 목록 읽기
  WK->>DB: complete_job (campaign_type 포함)
  U->>API: POST /api/brandconnect/applications (campaign_type, message)
  alt 클립형
    API-->>U: 409 CLIP_CAMPAIGN_USE_VIDEO (handoff 안내)
  else 블로그형
    API->>API: rate_limit_hit (5건 시간, 20건 일)
    API->>DB: create_brandconnect_application (target_kind blog)
    API->>DB: enqueue_job brandconnect.apply
    WK->>NV: 지원서 제출 (CAPTCHA 우회 없음)
    WK->>DB: submitted 또는 failed
  end
  WK->>NV: brandconnect.sync 하루 1회
  WK->>DB: accepted 또는 rejected 반영
```

### 4-4. AI 도우미 채팅 한 턴 (BL-F-055, BL-F-059)

읽는 법: 브라우저는 `/api/ai/chat`만 부르고 Dify와 FastAPI는 서버 사이에서만 호출됩니다. 턴 시작 전에 선차감하고 끝나면 실제 사용량으로 정산하며, 결과가 전달되지 않으면 환불합니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler /api/ai/chat
  participant DB as Supabase core
  participant DF as Dify blog-chat
  participant FA as FastAPI tools

  U->>API: POST /api/ai/chat (conversation_id, message, request_id)
  API->>API: 대화 주인 확인, 레이트 리밋 20턴 분, 하루 상한
  API->>DB: consume_credits (선차감 3, 키 conv id turn n)
  API->>DB: ai_messages INSERT (사용자 메시지)
  API->>DF: Chat API (user dify_user, platform_conversation_id)
  DF->>FA: /tools/answer (내부 키 + 대화 매핑, 모드 write)
  FA->>FA: 원고 컨텍스트, 자료·위키 검색, compliance 후처리
  FA-->>DF: 답변 + 출처
  DF-->>API: 스트림
  API-->>U: SSE delta, citations, usage, done
  alt Dify 장애
    API->>FA: /tools/answer-direct (서명 토큰 scope chat rag wiki)
  end
  API->>DB: 정산 (차액 추가 차감 또는 refund_credits)
  Note over API,DB: 연결이 끊기면 /api/internal/ai-settle이 5분 주기로 정산
```

## 5. 상태 머신

읽는 법: 허용되지 않은 전이는 DB 트리거가 22023으로 막습니다. 화살표 옆 글자는 전이를 일으키는 주체입니다.

### 5-1. 원고 `posts.status` (05장 3.1절)

발행 중심 상태(예약, 발행 중, 게시, 일부 게시, 실패)는 발행 행(`post_publications`)의 집계로 정해집니다. 집계 규칙은 진행 중이 있으면 publishing, 예약만 있으면 scheduled, 성공과 실패가 섞이면 partially_published, 성공만이면 published, 실패만이면 failed, 전부 취소면 draft입니다. 집계 상태끼리는 서로 오갈 수 있어 그림에는 대표 경로만 그렸습니다.

```mermaid
stateDiagram-v2
  [*] --> draft: 사용자 INSERT
  draft --> generating: 서버 생성 라우트
  generating --> draft: 워커 성공 또는 실패
  draft --> scheduled: 집계 트리거 예약만
  draft --> publishing: 집계 트리거 진행 중
  scheduled --> publishing: 집계 트리거
  publishing --> published: 집계 트리거 성공만
  publishing --> partially_published: 집계 트리거 성공과 실패
  publishing --> failed: 집계 트리거 실패만
  failed --> publishing: 집계 트리거 재시도
  scheduled --> draft: 집계 트리거 전부 취소
  draft --> archived: RPC set_post_archived
  failed --> archived: RPC
  published --> archived: RPC
  archived --> draft: RPC 보관 해제
```

### 5-2. 발행 `post_publications.status` (05장 3.2절)

```mermaid
stateDiagram-v2
  [*] --> queued: 서버 발행 라우트 즉시
  [*] --> scheduled: 서버 발행 라우트 예약
  queued --> publishing: 워커 attempts 증가
  scheduled --> publishing: 워커
  scheduled --> queued: 워커 간격 규칙 재배치
  queued --> canceled: 사용자 RPC cancel_publication
  scheduled --> canceled: 사용자 RPC cancel_publication
  publishing --> published: 워커
  publishing --> unconfirmed: 워커 URL 미확인
  publishing --> failed: 워커 재시도 불가
  publishing --> queued: 워커 재시도 가능
  unconfirmed --> published: 사용자 RPC resolve
  unconfirmed --> failed: 사용자 RPC resolve
  failed --> queued: 서버 재시도 라우트
  published --> [*]
  canceled --> [*]
```

### 5-3. 채널 계정 `channel_accounts.status` (05장 3.3절)

```mermaid
stateDiagram-v2
  [*] --> pending: 서버 채널 연결
  pending --> active: 검증 성공
  pending --> error: 검증 실패
  active --> needs_reauth: 워커 로그인 또는 CAPTCHA 감지
  active --> error: 워커
  active --> revoked: 사용자 RPC disconnect
  needs_reauth --> active: 재검증
  needs_reauth --> revoked: 사용자 해제
  error --> active: 재검증
  error --> revoked: 사용자 해제
  revoked --> [*]: 재연결은 새 행
```

### 5-4. AI 초안 실행 `core.ai_runs`와 승인 (02장 5.2절)

```mermaid
stateDiagram-v2
  [*] --> running: 워커가 그래프 시작
  running --> waiting_approve: approve 스텝 running 이 상태는 run은 running 그대로
  waiting_approve --> succeeded: 사용자 ai-approve
  waiting_approve --> canceled: 사용자 ai-reject
  waiting_approve --> canceled: 서버 정리 잡 7일 (제안)
  running --> failed: 도달 전 최종 실패 자동 환불
  succeeded --> [*]
  canceled --> [*]
  failed --> [*]
```

## 6. 화면 흐름

읽는 법: 화살표는 사용자의 실제 이동 순서입니다. 점선은 서버가 막고 안내하는 분기입니다. 대시보드 영역은 모두 로그인 뒤 화면입니다.

```mermaid
flowchart LR
  LP["/ 랜딩 3D 히어로"]
  LG["/login /signup"]
  OA["/onboarding/ai"]
  DB["/dashboard"]
  CHN["/channels<br/>연결·위험 동의"]
  NEW["/posts/new<br/>키워드 마법사"]
  ED["/posts/id<br/>에디터 3단"]
  RV["/posts/id/review<br/>AI 초안 승인"]
  PB["/posts/id/publish<br/>검사·채널·예약"]
  CAL["/calendar"]
  AFF["/affiliate"]
  BC["/brandconnect"]
  MAT["/materials"]
  WIKI["/wiki"]
  AST["/assistant<br/>도우미 채팅"]
  DSC["/settings/disclosure"]
  BIL["/billing"]
  VID["video 앱<br/>클립 지원 화면"]

  LP --> LG
  LG --> OA
  OA --> DB
  DB --> CHN
  DB --> NEW
  NEW -->|"생성 잡 완료"| RV
  NEW --> ED
  RV -->|"승인"| ED
  RV -.->|"FAIL이면 승인 불가"| ED
  ED --> PB
  PB -.->|"미승인 AI_APPROVAL_REQUIRED"| RV
  PB -.->|"월 한도 BL004"| BIL
  PB --> CAL
  ED --> AFF
  DB --> BC
  BC -.->|"클립형은 handoff"| VID
  BC -->|"선정 후 원고 쓰기"| ED
  DB --> MAT
  MAT --> WIKI
  ED --> AST
  DB --> DSC
  DB --> BIL
```

## 7. 보안 경계

읽는 법: 바깥에서 안쪽으로 갈수록 신뢰가 높아지고, 마지막 방어선은 DB입니다. 이 제품의 특징은 공식 API가 없는 채널에 사용자 계정으로 로그인해 자동 조작하는 워커가 있다는 점이라, 워커와 외부 채널 경계를 따로 그렸습니다. 공통 규칙은 `SECURITY_BASELINE.md` 장 번호(§)로 표시했습니다. 이 제품의 `SECURITY.md`는 비어 있어 `04_API.md`, `05_DATA_MODEL.md`, `01_PRD.md` 6.4절, `02_ARCHITECTURE.md`에서 가져왔습니다.

```mermaid
flowchart TB
  subgraph Z0["신뢰하지 않는 영역"]
    B["브라우저·봇·방문자"]
    LK["제휴 단축 링크 방문자<br/>/r/code"]
  end

  subgraph Z1["입구 Vercel"]
    H["보안 헤더·세션<br/>§18"]
    RL["레이트 리밋<br/>생성 60회 분·로그인 10회 10분 §8 §21"]
    RLR["/r 60회 분 IP 해시<br/>§8"]
  end

  subgraph Z2["앱 서버 신뢰"]
    RS["requireSession·zod<br/>org는 세션에서만 §11"]
    SSRF["워드프레스 URL 검사<br/>https만·사설 IP 차단·리다이렉트 2회 §10"]
    SAN["본문 sanitize<br/>서버 렌더 결과만 표시 §10"]
    TK["EdDSA 토큰 발급<br/>개인키는 Next.js만 §16"]
    CON["위험 동의 확인<br/>채널·브랜드커넥트 owner admin"]
  end

  subgraph Z3["데이터 최종 방어선"]
    RLS["RLS + 컬럼 GRANT + 전이 트리거<br/>§1~4"]
    DCK["대가성 문구 CHECK<br/>disclosure_included"]
    ENC["encrypted_credentials<br/>평문 비밀 컬럼 없음 §5"]
    AUD["감사 로그 2년<br/>§9"]
  end

  subgraph Z4["워커와 AI 제한 신뢰"]
    WK["blog-worker<br/>LLM 키 없음·잡 토큰만"]
    FA["FastAPI<br/>서명 토큰 또는 내부 키 없으면 401"]
    DF["Dify<br/>토큰·개인정보 입력 금지"]
  end

  subgraph Z5["외부 채널과 서비스"]
    CHN["네이버·티스토리·브랜드커넥트<br/>CAPTCHA 우회 안 함"]
    EXT["LLM·ElevenLabs<br/>국외 이전 동의 §12 §16"]
    TOSS["Toss 웹훅<br/>서명 필수 §6"]
  end

  B --> H --> RL --> RS
  LK --> RLR --> RS
  RS --> SSRF
  RS --> SAN
  RS --> CON
  RS --> RLS
  RS --> TK
  RLS --> DCK
  RLS --> AUD
  TK -->|"잡 토큰"| WK
  TK --> FA
  TK --> DF
  WK -->|"service_role · claim_jobs"| RLS
  WK -->|"credential_id로 복호화"| ENC
  WK --> CHN
  FA --> EXT
  TOSS -->|"상태 동기화만"| RS
```

이 제품의 주요 위협과 대응(문서에 적힌 것만 모음. 정식 위협표는 `SECURITY.md` 작성 후 대체해야 합니다):

| 위협 | 대응(출처) | 공통 규칙 |
|---|---|---|
| 대가성 문구 누락으로 표시광고법 위반 | 문구 끌 수 없음, 발행 행 CHECK(`post_publications_disclosure_check`), 누락은 23514 + 운영 알림(`05` 2.4절, `04` 7절) | §4 |
| 채널 비밀(비밀번호·세션) 유출 | 모든 비밀은 `encrypted_credentials` 암호문에만, 키 `CREDENTIALS_KEY_V<n>` 없으면 기동 실패, 페이로드엔 `credential_id`만(`05` 7절, `02` 4절) | §5 |
| 워드프레스 URL을 이용한 서버 요청 위조(SSRF) | https만, 사설 IP·로컬 차단, 리다이렉트 2회, 응답 5MB(`01` BL-F-040) | §10 |
| 본문에 악성 HTML 삽입 | 서버 허용 목록 sanitize, 미리보기는 서버 렌더 결과만(`02` 1절, `01` BL-F-017) | §10 |
| 자동 게시로 인한 계정 제한 | 위험 고지·동의(버전 관리), 시간당·일일 한도, 계정당 브라우저 1개, 간격 10분, CAPTCHA 우회 금지(`01` 6.4절, BL-F-047) | §8 |
| 타 조직 채널·원고 접근 | RLS 멤버 + 엔타이틀먼트, org는 세션에서만, 교차 조직 참조 트리거(`05` 4절, `04` 1절) | §1, §11 |
| 브라우저가 AI 제공자를 직접 호출 | 브라우저는 `/api/ai/*`, `/api/voice/*`만, 워커에는 LLM 키 없음(`02` 2절) | §11, §16 |
| 결제 위조 | 주문 선저장 + `confirm_payment_order` 금액 대조, 웹훅은 상태 동기화만(`05` 7절) | §6 |
| 승인 없는 AI 초안 발행 | 발행 라우트가 `ai_runs` 상태를 읽어 `AI_APPROVAL_REQUIRED` 409. 단 DB 불변식이 아닌 서버 규칙이라 회귀 테스트로 보장(`05` 6절) | §16 |

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)는 같은 서버 계층과 RLS 조회를 거칩니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)입니다. 이 제품에는 익명 공개 읽기가 없어 모든 도구가 로그인 후 읽기입니다.

### 8-1. 웹 경로 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["브라우저 블로거"]
    AG["AI 에이전트<br/>블로거 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    RH["Next.js Route Handler<br/>requireSession 후 zod"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>Bearer 토큰 필수"]
    RL["레이트 리밋 사용자"]
    TL["도구 7개<br/>필드 허용 목록 출력"]
    SAN["발행본 본문 untrusted 처리<br/>초안 본문 자격증명 제외"]
  end

  subgraph DB["DB 최종 방어선"]
    RLS["RLS 멤버십 엔타이틀먼트<br/>posts publications channel_accounts"]
    RPC["blog.monthly_post_usage"]
  end

  subgraph NO["MCP가 부르지 않는 것"]
    WK["발행 잡 브라우저 잡<br/>AI 생성 크레딧 차감"]
  end

  BR --> RH
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  RH -->|"사용자 세션"| RLS
  RH --> RPC
  RH --> WK
  TL -->|"사용자 토큰 D-M1"| RLS
  TL --> RPC
  TL -.->|"확인 링크 D-M3"| RH
```

### 8-2. 발행 준비와 사람 확정 (`blog_prepare_publish`)

```mermaid
sequenceDiagram
  autonumber
  actor B as 블로거
  participant A as AI 에이전트
  participant M as MCP 서버
  participant D as DB RLS와 RPC
  participant W as 웹 발행 화면

  B->>A: 이 글 네이버에 올려줘
  A->>M: blog_prepare_publish 원고 id
  M->>D: 원고 상태 규정 결과 월 사용량 채널 상태 읽기
  D-->>M: verdict 사용량 채널 status
  Note over M: 저장 안 함 잡 만들지 않음<br/>publish 경로 호출 안 함
  M-->>A: 가능 여부 막는 사유 확정 전 문구 확인 링크 15분
  A-->>B: 아직 발행 전입니다 링크에서 문구와 경고를 확인하세요
  B->>W: 링크 열기 로그인 세션 일치 확인
  W-->>B: 채널 선택 대가성 문구 정책 경고 표시
  B->>W: 발행 또는 예약 클릭
  W->>D: 기존 publish 경로 서버 검사 후 발행 행 INSERT와 잡 등록
  D-->>W: 접수 또는 BL003 등 오류
  W-->>B: 상태 안내
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R1["R1 로그인 읽기 MVP"]
    T1["blog_list_posts"]
    T2["blog_get_post"]
    T3["blog_list_publications"]
    T4["blog_list_channels"]
    T5["blog_get_monthly_usage"]
  end
  subgraph R2["R2 소유자 관리자 읽기 1.5"]
    T6["blog_get_affiliate_stats"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T7["blog_prepare_publish"]
  end
  subgraph NO["만들지 않음"]
    N1["발행 예약 재시도 취소"]
    N2["규정 경고 확인 AI 초안 승인"]
    N3["AI 생성 호출 크레딧 소비"]
    N4["채널 제휴 자격증명 브랜드커넥트 제출"]
  end
  R1 --> R2 --> PR
  PR -.->|"사람이 웹에서 확정"| N1
```

## 문서 불일치

1. **`SECURITY.md`가 미작성 초안**입니다(자산, 위협, 제품별 수치가 모두 "작성 필요"). 7장 그림과 위협표는 다른 문서에서 모은 임시본이며, 세션 만료·CSP 도메인·백업 주기 등 제품별 수치는 담지 못했습니다.
2. **발행 서버 검사 순서**: `01_PRD.md` BL-F-043은 "엔타이틀먼트 → 월 한도 → 채널 한도 → 컴플라이언스 상태 → 채널 정책 경고 확인 → 발행 행 INSERT"이고 AI 승인 확인은 컴플라이언스 상태 다음(3.7절 덧붙임)이라 적습니다. `04_API.md` 2절 publish 행은 "엔타이틀먼트 → 월 한도 → 채널 정책 경고 → AI 승인 → 렌더 검증 → INSERT"이며 컴플라이언스는 INSERT 때 DB 게이트가 판정합니다. 그림 4-2는 `04`(실행 순서 정본)를 따랐습니다.
3. **AI 초안 실행의 "대기" 상태**: `02_ARCHITECTURE.md` 5.2절은 `approve` 스텝이 running이고 run도 running이라고 적어, 별도 상태 이름이 없습니다. 그림 5-4의 `waiting_approve`는 읽기 쉽게 붙인 이름이며 실제 컬럼 값이 아닙니다.
4. **MVP 범위가 제안**: `01_PRD.md` 2절은 확정 결정 7이 blog의 MVP를 따로 정하지 않아 범위가 제안이라고 밝힙니다. 그림 1의 MVP/Phase 구분도 그 제안을 따랐습니다.
5. **원고 상태 집계 전이**: `05_DATA_MODEL.md` 3.1절은 집계 상태 사이 전이를 개별 쌍으로 나열하지 않고 규칙으로 서술합니다. 그림 5-1의 집계 상태 간 화살표는 그 규칙에서 읽어 낸 대표 경로입니다.
6. **MCP 읽기 경로**: `04_API.md`에는 원고·발행·채널 목록을 읽는 GET Route Handler가 없고 RLS 직접 조회만 있습니다(`MCP.md` D-M5). `GET /api/affiliate/stats`가 service_role로 집계하는지도 문서에 없습니다(D-M4). 그림 8-1은 RLS 조회를 실선으로 그렸고 통계 도구의 경로는 확정하지 않았습니다.
7. **MCP 플랜 한도**: `blog.monthly_post_usage`는 사용 건수만 반환하고 플랜 한도 값을 읽는 방법이 `04_API.md`에 없습니다(`MCP.md` D-M6). 그림은 "월 사용량 읽기"만 그렸습니다.

## 갱신 규칙

`README.md`, `01_PRD.md`~`05_DATA_MODEL.md`, `SECURITY.md` 중 이 그림의 근거 절을 고치면 이 파일의 해당 그림도 같은 변경에서 함께 고칩니다.
