# DIAGRAMS: Toon Factory UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 이 폴더의 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid). 전체 구조는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일입니다.

**제품 한 줄 정의**: 이야기를 넣으면 AI가 회차 콘티(컷 구성, 대사)를 짜고, 미리 만든 캐릭터 모듈(포즈와 표정)로 컷을 조립하며, 배경은 AI로 생성해 인스타툰 PNG/ZIP, 세로 스크롤 웹툰 이미지, 9:16 MP4로 내보내는 AI 웹툰 제작 도구입니다(`README.md` 1절).

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`(미작성 상태, 7번 그림 참고), 공통 `../_platform-core/SECURITY_BASELINE.md`.

**표기**: **실선 화살표** = 호출·데이터 흐름, **점선** = 검증·참조·보조 경로, "(제안)" = 문서가 제안이라고 한 값. 기능 ID는 `TN-F-nnn`(01_PRD), 오류 코드는 `TNnnn`(04_API 7절)입니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1 | 사용자와 기능 | 유스케이스 관점 | 01_PRD 1절, 2절, 3절 |
| 2 | 구성요소 | 컴포넌트 | 02_ARCHITECTURE 2절, 3절, 4절, 7절 |
| 3 | 데이터 모델 | 클래스 | 05_DATA_MODEL 1~4절 |
| 4-1 | AI 콘티 생성 | 시퀀스 | 04_API 2절, 4절, 02_ARCHITECTURE 4절, 5.2절 |
| 4-2 | 내보내기와 협찬 승인 | 시퀀스 | 04_API 2절, 05_DATA_MODEL 2.6절, 02_ARCHITECTURE 4절 |
| 4-3 | Pro 구독 결제 | 시퀀스 | 04_API 2절, 03_SCREENS_UX 2.3절 |
| 4-4 | AI 채팅 한 턴 | 시퀀스 | 04_API 2.1절, 6.2절 |
| 5-1 | 생성·내보내기 실행 상태 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-2 | 협찬 상태 | 상태 머신 | 05_DATA_MODEL 2.6절, 3절 |
| 5-3 | 에셋 팩 상태 | 상태 머신 | 05_DATA_MODEL 2.1절, 3절 |
| 6 | 화면 흐름 | 흐름도 | 03_SCREENS_UX 1절, 2절, 8절 |
| 7 | 보안 경계 | 신뢰 경계 | 05_DATA_MODEL 4절, 7절, 02_ARCHITECTURE 6절, 04_API 1절 |

## 1. 사용자와 기능

읽는 법: 왼쪽이 역할, 오른쪽이 기능입니다. 실선 박스 안은 MVP(Pro 전용은 표시), 점선으로 이어진 박스는 Phase 2·3입니다. 역할별 접근은 03_SCREENS_UX 1절 표를 따릅니다.

```mermaid
flowchart LR
  M(["member<br/>하린·도윤·서진"])
  AD(["owner / admin"])
  V(["viewer<br/>읽기 전용"])
  PA(["platform_admin"])

  subgraph MVP["MVP"]
    direction TB
    F1["작품·회차·컷·캐스트<br/>TN-F-001~006"]
    F2["모듈형 에디터<br/>TN-F-010~016"]
    F3["AI 콘티·대사·배경<br/>TN-F-020~024"]
    F4["설정 위키·노트·RAG<br/>TN-F-050~054"]
    F5["창작 채팅·음성<br/>TN-F-055~057"]
    F6["PNG·ZIP·스트립 내보내기<br/>TN-F-030~032, 038"]
    F7["카탈로그 운영·라이선스<br/>TN-F-044"]
    F8["Pro 구독·크레딧팩<br/>TN-F-041~043"]
    F9["AI 처리 방식 동의<br/>TN-F-059"]
  end

  subgraph PRO["MVP (Pro 전용)"]
    direction TB
    P1["9:16 MP4 내보내기<br/>TN-F-033"]
    P2["MP4 음성 입히기<br/>TN-F-058"]
    P3["브랜디드 툰 협찬<br/>TN-F-070~073"]
  end

  subgraph LATER["Phase 2·3"]
    direction TB
    L1["SNS 직접 업로드<br/>TN-F-080 (Phase 2)"]
    L2["숏툰 모션·자막<br/>TN-F-081 (Phase 2)"]
    L3["광고주 외부 검토 링크<br/>(Phase 2)"]
    L4["공개 작품 페이지 GEO<br/>(Phase 3)"]
  end

  M --> F1
  M --> F2
  M --> F3
  M --> F4
  M --> F5
  M --> F6
  M --> P1
  M --> P2
  M --> P3
  AD --> F8
  AD --> F9
  AD -->|"승인 기록"| P3
  V -.->|"읽기만"| F1
  PA --> F7
  P1 -.-> L1
  P1 -.-> L2
  P3 -.-> L3
  F1 -.-> L4
```

## 2. 구성요소

읽는 법: 브라우저는 Supabase(RLS)와 Next.js만 부릅니다. LLM은 FastAPI만, ElevenLabs는 Next.js만, fal은 워커만 호출합니다. 점선은 서명 토큰·잡 토큰 같은 검증이 붙는 경로입니다. 코어(인증·크레딧·결제·잡·감사)는 `core` 한 묶음으로 줄였습니다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["Next.js 화면<br/>에디터(Fabric 뷰)"]
    CH["채팅 시트·마이크"]
  end

  subgraph WEB["Next.js (Vercel)"]
    RH["Route Handler<br/>storyboard·exports·billing"]
    AIG["AI 게이트 /api/ai/*"]
    VG["음성 /api/voice/*"]
    INT["/api/internal<br/>잡 토큰·AI 정산"]
  end

  subgraph WK["toon-worker (Railway)"]
    WA["toon.ai 큐<br/>콘티·배경"]
    WR["toon.render 큐<br/>PNG·ZIP·스트립·MP4<br/>fabric/node·FFmpeg"]
  end

  subgraph AIS["AI 서비스"]
    FA["FastAPI apps/api<br/>그래프 4개·위키·RAG<br/>compliance"]
    DF["Dify toon-chat"]
  end

  subgraph SB["Supabase"]
    CORE["core 스키마<br/>크레딧·결제·잡·감사"]
    TN["toon 스키마<br/>작품·컷·내보내기"]
    ST["Storage<br/>카탈로그·내보내기"]
    VEC["pgvector<br/>설정 임베딩"]
  end

  subgraph EXT["외부 서비스"]
    TOSS[("Toss Payments")]
    FAL[("fal 이미지")]
    LLM[("상용·오픈소스 LLM")]
    VOX[("ElevenLabs·<br/>오픈소스 음성")]
  end

  UI -->|"RLS 직접 CRUD"| TN
  UI --> RH
  CH --> AIG
  CH --> VG
  RH -->|"consume_credits<br/>enqueue_job"| CORE
  RH --> TOSS
  AIG --> DF
  AIG -.->|"EdDSA 서명 토큰"| FA
  DF -.->|"내부 키"| FA
  VG --> VOX
  WA --> CORE
  WR --> CORE
  WA --> INT
  INT -.->|"잡 토큰 발급"| WA
  WA -.->|"잡 토큰"| FA
  WA --> FAL
  WR --> ST
  FA --> LLM
  FA --> VEC
  RH --> ST
```

## 3. 데이터 모델

읽는 법: `toon` 스키마의 핵심 테이블 11개와 코어 참조 3개입니다. `org_id`는 모든 테넌트 테이블에 있고(카탈로그 제외) 다른 조직의 부모를 가리키면 복합 FK가 `23503`으로 막습니다. 접근 주체는 각 클래스의 note에 적었습니다. 컬럼은 05_DATA_MODEL 2절의 핵심만 담았습니다.

```mermaid
classDiagram
  class asset_packs {
    code
    style_preset
    tier
    license_source
    license_ref
    license_verified_at
    status
  }
  class characters {
    pack_id
    code
    name
    status
  }
  class assets {
    pack_id
    character_id
    kind
    storage_path
    editor_path
    preview_path
    anchors
  }
  class series {
    org_id
    title
    format
    canvas_width
    canvas_height
    status
  }
  class series_characters {
    series_id
    character_id
    display_name
  }
  class episodes {
    series_id
    number
    script
    status
    sponsorship_id
  }
  class cuts {
    episode_id
    position
    doc
    duration_ms
    revision
  }
  class sponsorships {
    series_id
    advertiser_name
    compensation_kind
    disclosure_text
    virtual_character
    status
    decided_by
  }
  class generations {
    org_id
    kind
    prompt
    status
    job_id
    credit_ledger_id
    request_id
  }
  class user_assets {
    generation_id
    source
    ai_generated
    storage_path
    deleted_at
  }
  class exports {
    episode_id
    kind
    preset
    status
    watermark
    ai_label
    sponsorship_id
    disclosure_text
    request_id
  }
  class core_jobs {
    status
  }
  class core_credit_ledger {
    amount
  }
  class core_organizations {
    id
  }

  asset_packs "1" --> "many" characters
  characters "1" --> "many" assets
  asset_packs "1" --> "many" assets
  core_organizations "1" --> "many" series
  series "1" --> "many" series_characters
  characters "1" --> "many" series_characters
  series "1" --> "many" episodes
  episodes "1" --> "many" cuts
  series "1" --> "many" sponsorships
  sponsorships "0..1" --> "many" episodes : restrict
  generations "1" --> "many" user_assets
  episodes "0..1" --> "many" exports : set null
  sponsorships "0..1" --> "many" exports : set null
  generations ..> core_jobs
  exports ..> core_jobs
  generations ..> core_credit_ledger
  exports ..> core_credit_ledger

  note for asset_packs "카탈로그는 org 없음. published는 status가 published이고 has_toon_access 또는 platform_admin만 SELECT. 쓰기는 service"
  note for assets "원본 경로 2개는 authenticated 컬럼 GRANT 없음. 사용자는 catalog_assets 뷰만 읽음"
  note for cuts "멤버 + 엔타이틀먼트 RLS. 쓰기는 save_cut_doc과 한도 트리거. DELETE는 owner admin"
  note for sponsorships "멤버 쓰기 + 상태 트리거. approved와 changes_requested는 decide_sponsorship만 owner admin"
  note for exports "사용자는 SELECT만. INSERT와 UPDATE는 service. watermark는 서버 결정"
  note for generations "사용자는 SELECT만. INSERT는 Route Handler(service). request_id 유일"
```

## 4. 핵심 시퀀스

### 4-1. AI 콘티 생성 (TN-F-020, TN-F-052)

읽는 법: 위에서 아래로 시간 순서입니다. 검증 → 크레딧 선차감 → 잡 등록 순서가 04_API 1절의 규칙이며, 실패하면 환불합니다. 워커는 LLM 키가 없어서 잡 토큰으로 FastAPI 그래프를 부릅니다.

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant RH as POST /api/storyboard
  participant C as core
  participant W as toon-worker
  participant INT as /api/internal/ai-token
  participant FA as FastAPI toon.storyboard

  B->>RH: requestId, episodeId, synopsis, cutCount, tone, castIds
  RH->>RH: requireSession toon (401 403 402)
  RH->>RH: zod 검증, cutCount 범위 (422)
  RH->>RH: compliance 규칙 (TN006)
  RH->>C: consume_credits consume:toon:requestId (3 또는 5)
  alt 잔액 부족
    C-->>RH: CR001
    RH-->>B: 402
  else 정상
    RH->>C: enqueue_job toon.ai storyboard.generate
    RH-->>B: 202 jobId
  end
  W->>C: claim_jobs 큐 toon.ai
  W->>INT: job_id + X-Worker-Key
  INT->>C: 잡 running 확인 (app toon, job_type 일치)
  INT-->>W: 서명 토큰 scope graph:toon.storyboard
  W->>FA: POST /graphs/toon.storyboard/runs
  FA-->>W: 컷 초안 (compliance 통과분)
  W->>C: episodes.script 저장 후 complete_job
  alt LLM 실패 최종
    W->>C: fail_job (자동 환불)
  end
  C-->>B: Realtime 진행률
```

### 4-2. 내보내기와 협찬 승인 (TN-F-030, TN-F-033, TN-F-070~072)

읽는 법: 협찬 회차의 최종 내보내기는 DB 트리거가 승인 여부를 판정합니다. 워터마크·대가성 문구는 요청 값이 아니라 서버가 채운 `exports` 행의 값만 렌더 워커가 믿습니다.

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant RH as POST /api/exports
  participant DB as toon.exports
  participant C as core
  participant W as 렌더 워커
  participant ST as Storage

  B->>RH: requestId, episodeId, kind, options, preset
  RH->>RH: plan_features로 export 종류 확인 (TN002)
  RH->>RH: monthly_export_count (TN005), mp4 길이 (TN004)
  RH->>RH: org_asset_access 등급 확인 (TN003)
  opt kind 가 mp4
    RH->>C: consume_credits 3
  end
  RH->>DB: INSERT exports (service, watermark 서버 값)
  Note over DB: 트리거 apply_export_sponsorship가 협찬 행에서 문구 복사
  alt 협찬 미승인 + 최종 요청
    DB-->>RH: TN008
    RH-->>B: 409 검토용 시안만 가능
  else 허용
    RH->>C: enqueue_job toon.render export.kind
    RH-->>B: 202 exportId, jobId
  end
  W->>C: claim_jobs 큐 toon.render
  W->>W: watermark 값은 exports 행만 신뢰
  W->>W: org_asset_access 재확인 (실패 시 TN003, 재시도 없음)
  W->>ST: 렌더 결과 저장
  W->>C: complete_job, exports succeeded
  B->>RH: GET /api/exports/id/download
  RH->>C: 감사 export.download
  RH-->>B: 302 서명 URL 1시간
```

### 4-3. Pro 구독 결제 (TN-F-041)

읽는 법: 금액은 클라이언트가 아니라 DB의 주문 행이 정합니다. 지급은 confirm 경로에서만 일어나고 웹훅은 상태 동기화만 합니다.

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant RH as billing Route Handler
  participant C as core
  participant T as Toss
  participant WH as POST /api/webhooks/toss

  B->>RH: POST /api/billing/checkout subscription pro
  RH->>RH: 역할 owner admin 확인 (이미 Pro면 409)
  RH->>C: payment_orders INSERT (금액은 DB)
  RH-->>B: orderId, amountKrw, customerKey
  B->>T: 빌링키 발급창
  T-->>B: authKey
  B->>RH: POST /api/billing/billing-key authKey, orderId
  RH->>T: 빌링키 발급, 암호화 저장, 첫 청구
  alt 카드 거절
    T-->>RH: 실패
    RH-->>B: 402
  else 성공
    RH->>C: confirm_payment_order
    alt 금액 불일치
      C-->>RH: PM001
      RH-->>B: 409 승인 취소와 운영 알림
    else 정상
      C-->>RH: 구독 pro, 300 크레딧 지급
      RH-->>B: 워터마크 해제
    end
  end
  T-->>WH: 결제 상태 변경
  WH->>C: 서명 검증, 멱등 기록, 상태 동기화만
```

### 4-4. AI 채팅 한 턴 (TN-F-055, TN-F-060)

읽는 법: 브라우저는 Dify를 직접 부르지 않습니다. Dify가 5xx이거나 10초 무응답이면 FastAPI 직접 경로로 대체합니다. 크레딧은 선차감 후 실제 사용량으로 정산합니다.

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant G as POST /api/ai/chat
  participant C as core
  participant D as Dify toon-chat
  participant FA as FastAPI

  B->>G: conversation_id, request_id, message, series_id, mode
  G->>G: requireSession, 대화 주인 확인, 마스킹
  G->>C: rate_limit_hit 3종 (429)
  G->>C: consume_credits conv:id:turn:n (3)
  G->>C: ai_messages INSERT (user)
  G->>D: Chat API user=dify_user, 입력 series_id, mode
  D->>FA: POST /tools/answer + 내부 키
  FA->>FA: series_id 가 같은 조직 작품인지 확인
  FA-->>D: answer, citations, suggestions
  D-->>G: 스트리밍 응답
  alt Dify 5xx 또는 10초 무응답
    G-.->FA: /tools/answer-direct (서명 토큰)
  end
  G->>C: 정산 consume 또는 refund_credits
  G-->>B: SSE delta, citations, usage, done
```

## 5. 상태 머신

### 5-1. 생성·내보내기 실행 상태 (`generations.status`, `exports.status`)

읽는 법: 사용자는 쓸 수 없고 service만 바꿉니다. 트리거 `enforce_run_status_transition`이 허용 전이 밖이면 `22023`을 냅니다. 괄호는 전이를 일으키는 주체입니다.

```mermaid
stateDiagram-v2
  [*] --> queued : insert (service만)
  queued --> running : 워커
  queued --> canceled : 취소 라우트, core.cancel_job 환불
  queued --> failed : 워커
  running --> succeeded : 워커
  running --> failed : 워커
  running --> queued : 워커 재시도
  succeeded --> [*]
  failed --> [*]
  canceled --> [*]
```

### 5-2. 협찬 상태 (`sponsorships.status`)

읽는 법: 판정 상태(`approved`, `changes_requested`)는 owner/admin이 `decide_sponsorship`을 부를 때만 생깁니다. 사용자가 직접 바꾸면 `42501`입니다. 승인 뒤 핵심 내용을 고치면 자동으로 `in_review`로 돌아가고 결정 기록이 지워집니다.

```mermaid
stateDiagram-v2
  [*] --> draft : 멤버 INSERT (draft만)
  draft --> in_review : 멤버 검토 요청
  in_review --> draft : 멤버
  in_review --> approved : owner admin decide_sponsorship
  in_review --> changes_requested : owner admin decide_sponsorship
  changes_requested --> draft : 멤버
  changes_requested --> in_review : 멤버
  approved --> in_review : 내용 수정 시 자동
  approved --> closed : 멤버
  closed --> [*]
```

### 5-3. 에셋 팩 상태 (`asset_packs.status`)

읽는 법: `published`는 라이선스 검증(`license_verified_at/by`)이 있어야 CHECK를 통과합니다. 전이는 platform_admin(service)만 하고 감사 로그가 남습니다.

```mermaid
stateDiagram-v2
  [*] --> draft : catalog-import CLI
  draft --> published : platform_admin, 검증 필수
  draft --> retired : platform_admin
  published --> retired : platform_admin
  retired --> [*]
```

## 6. 화면 흐름

읽는 법: 가입 → AI 처리 방식 → 템플릿 → 에디터가 첫 사용 흐름이고, 에디터는 GNB가 없는 셸 밖 화면입니다. 협찬 경로는 문서끼리 다릅니다(맨 끝 "문서 불일치"). 이 그림은 8.4절의 새 경로를 따랐습니다.

```mermaid
flowchart TB
  LAND["/ 랜딩 3D 히어로"]
  PRICE["/pricing"]
  AUTH["/login /signup<br/>/auth/callback"]
  OBA["/onboarding/ai<br/>AI 처리 방식"]
  OBT["/app/onboarding<br/>템플릿 3종"]
  HOME["/app 작품 목록"]
  NEW["/app/series/new"]
  SER["/app/series/id<br/>회차·캐스트"]
  SB["콘티 storyboard"]
  ED["/editor/episodeId<br/>셸 밖 3단 에디터"]
  EXP["내보내기 패널<br/>?panel=export"]
  WIKI["설정 위키·노트"]
  SPO["/app/series/id/sponsorships"]
  CHAT["채팅 시트·/app/chat"]
  XH["/app/exports 기록"]
  LIB["/app/library"]
  BILL["/app/billing"]
  SET["/app/settings"]
  ADM["/admin/catalog"]

  LAND --> AUTH
  LAND --> PRICE
  AUTH --> OBA
  OBA --> OBT
  OBT --> ED
  AUTH --> HOME
  HOME --> NEW
  HOME --> SER
  NEW --> SER
  SER --> SB
  SB -->|"콘티 적용"| ED
  SER --> ED
  SER --> WIKI
  SER --> SPO
  ED --> EXP
  EXP --> XH
  ED -.-> CHAT
  SER -.-> CHAT
  HOME --> XH
  HOME --> LIB
  HOME --> BILL
  HOME --> SET
  SET -.->|"다시 열기"| OBA
  HOME -.->|"platform_admin"| ADM
```

## 7. 보안 경계

읽는 법: 바깥에서 안쪽으로 신뢰가 높아집니다. 이 제품의 `SECURITY.md`는 아직 양식만 있고 자산·위협 표가 비어 있어서(맨 끝 "문서 불일치"), 이 그림은 05_DATA_MODEL 4절·7절, 02_ARCHITECTURE 6절, 04_API 1절의 차단 설계를 근거로 그렸습니다. 공통 규칙은 `SECURITY_BASELINE.md`의 장 번호(§)로 참조합니다. 리뷰 "높음" #1~#6은 `docs/reviews/Toon-Factory.md` 3장의 번호입니다.

```mermaid
flowchart TB
  subgraph Z0["① 신뢰하지 않는 영역"]
    B["브라우저·봇·다른 조직 사용자"]
  end

  subgraph Z1["② 입구 (Vercel)"]
    H["보안 헤더·세션·레이트 리밋<br/>§8, §18, §21"]
  end

  subgraph Z2["③ 앱 서버 (신뢰)"]
    AZ["requireSession toon<br/>플랜·역할·크레딧을 서버가 판정<br/>§11"]
    CMP["compliance 규칙 TN006<br/>zod 검증 1MB<br/>§10"]
    TK["서명 토큰 개인키 · fal 키는 워커만<br/>§16, §19"]
  end

  subgraph Z3["④ 데이터 (최종 방어선)"]
    RLS["RLS + 복합 FK + 한도 트리거<br/>§1~4, §15"]
    CAT["원본 에셋 비공개 버킷<br/>컬럼 GRANT 제거 (#2)"]
    EXPR["exports 사용자 쓰기 없음<br/>워터마크 서버 결정 (#1)"]
    LIC["라이선스 검증 없으면 공개 불가<br/>asset_packs CHECK (#6)"]
    AUD["감사 로그<br/>§9"]
  end

  subgraph Z4["⑤ 워커·AI·외부 (제한 신뢰)"]
    WK["렌더 워커: 에셋 등급 재확인<br/>watermark는 행의 값만"]
    FA["FastAPI: 잡 토큰 jti 1회<br/>LLM 키는 여기만 §16"]
    EXT["Toss·fal 웹훅 서명 검증<br/>fal 안전 필터 ON §6"]
  end

  subgraph Z5["⑥ 법적·정책 통제"]
    LAW["AI 생성 표시·대가성 문구<br/>국외 이전 동의 TN007<br/>협찬 미승인 TN008"]
  end

  B -->|"모든 요청"| Z1
  Z1 --> Z2
  Z2 -->|"사용자 세션"| RLS
  Z2 -->|"service_role 서버만"| CAT
  Z2 --> EXPR
  Z2 -.->|"토큰"| FA
  WK -.->|"service_role"| CAT
  EXT --> Z2
  RLS --> AUD
  Z2 -.-> LAW
  LIC -.-> CAT
```

## 문서 불일치

| # | 내용 | 그림에서 고른 쪽 |
|---|---|---|
| 1 | 협찬 화면 경로: `03_SCREENS_UX.md` 2.11절은 `/series/[id]/sponsorships`, 8.4절과 8.1절은 `/app/series/[seriesId]/sponsorships`(D26 미정, 기본값). 06_AGENT_PLAN TN-06-063도 앞쪽 경로 | 6번 그림은 8.4절 경로 |
| 2 | `SECURITY.md`가 양식 상태(자산, 위협, 수치 표가 "작성 필요")라 7번 그림에 쓸 제품 위협 표가 없음. 대신 05장 4절·7절, 02장 6절, 04장 1절을 근거로 사용 | 위 3개 문서 |
| 3 | `02_ARCHITECTURE.md` 4절 표에는 잡 유형 외에 동기 호출(로그라인)까지 11행인데 3절 jobs 행은 "10개 job_type"이라 적음. 구성요소 그림은 개수를 쓰지 않음 | 개수 미표기 |

## 갱신 규칙

`01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md` 중 하나를 고치면 이 문서의 해당 그림(위 표의 근거 절)도 같은 변경에서 함께 고칩니다.
