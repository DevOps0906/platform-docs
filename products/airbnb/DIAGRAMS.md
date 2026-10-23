# DIAGRAMS: Stay(가칭, airbnb) UML 시각화

작성일 2026-10-23. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 Mermaid로 바로 렌더링됩니다.

**제품 한 줄 정의:** 게스트가 지도와 날짜·인원으로 숙소를 찾아 예약을 요청하고, 개인 호스트가 13단계 마법사로 숙소를 올려 예약을 승인·관리하는 숙소 공유 웹 서비스(MVP는 결제 없는 예약 요청·확정).

**근거 문서:** `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `10_HOST_DASHBOARD.md`, `SECURITY.md`, `MCP.md`, 공통은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`.

**표기:** 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·Phase 2, "(제안)" = 문서가 제안이라고 한 값. 노드 안 `SY-F-###`은 `01_PRD.md` 3절 기능 ID입니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-1 | 게스트와 방문자의 기능 | 유스케이스(flowchart) | 01 2~3절, 03 1절 |
| 1-2 | 호스트와 운영자의 기능 | 유스케이스(flowchart) | 01 2~3절, 10 2절 |
| 2-1 | 웹·DB·외부 구성요소 | 컴포넌트(flowchart) | 02 2·3·7절, 04 6절 |
| 2-2 | AI·잡 구성요소 | 컴포넌트(flowchart) | 02 3~5절, 04 2.1·4·6절 |
| 3 | 데이터 모델 | 클래스 | 05 1~4절, 11절 |
| 4-1 | 예약 요청에서 승인까지 | 시퀀스 | 04 2·3절, 01 SY-F-008·009·024 |
| 4-2 | 숙소 AI 도우미 질문 | 시퀀스 | 04 2.1·6.2절, 01 SY-F-027·034 |
| 4-3 | 소개 작성 도우미와 게시 | 시퀀스 | 04 2·2.1절, 01 SY-F-014·017·029 |
| 4-4 | 사진 업로드 | 시퀀스 | 04 2·4절, 01 SY-F-015 |
| 5-1 | 숙소 상태 | 상태 머신 | 05 3절 |
| 5-2 | 예약 상태 | 상태 머신 | 05 3절 |
| 5-3 | 리뷰 상태 | 상태 머신 | 05 3절 |
| 6-1 | 게스트 화면 흐름 | flowchart | 03 1·2절 |
| 6-2 | 호스트 화면 흐름 | flowchart | 03 1·2·8절, 10 2절 |
| 7 | 보안 신뢰 경계 | flowchart | SECURITY 1~4절, SECURITY_BASELINE |
| 8-1 | API 위에 얹는 MCP 구성 | 컴포넌트(flowchart) | MCP 1~3절, MCP_BASELINE 1·7절 |
| 8-2 | 예약 준비와 사람 확정 | 시퀀스 | MCP 2·6절 |
| 8-3 | 도구 위험 등급과 노출 단계 | flowchart | MCP 2절, MCP_BASELINE 2절 |

## 1. 사용자와 기능

### 1-1. 게스트와 방문자

**읽는 법:** 왼쪽이 사람, 오른쪽이 기능입니다. 실선은 MVP, 점선은 Phase 2입니다. 방문자는 로그인 없이 검색과 상세만 쓰고, 나머지는 로그인 후 씁니다.

```mermaid
flowchart LR
  V(["방문자<br/>비로그인"])
  G(["게스트<br/>로그인"])

  subgraph PUB["공개 기능 MVP"]
    S["숙소 검색 SY-F-003"]
    D["숙소 상세 SY-F-005"]
    CAL["예약 불가 달력 SY-F-006"]
  end

  subgraph MEM["로그인 후 MVP"]
    R["예약 요청 즉시 예약<br/>SY-F-008"]
    T["내 여행 SY-F-012"]
    C["게스트 취소 SY-F-010"]
    RV["리뷰 작성 SY-F-019"]
    W["찜 SY-F-021"]
    CH["숙소 AI 도우미 SY-F-027"]
    NL["말로 찾기 SY-F-028"]
    VO["음성 대화 SY-F-032"]
  end

  subgraph P2["Phase 2"]
    PAY["예약 결제 Toss"]
    MSG["호스트 게스트 메시지"]
    VAI["방문자 AI 도우미"]
  end

  V --> S
  V --> D
  V --> CAL
  G --> R
  G --> T
  G --> C
  G --> RV
  G --> W
  G --> CH
  G --> NL
  CH -.-> VO
  V -.-> VAI
  G -.-> PAY
  G -.-> MSG
```

### 1-2. 호스트와 운영자

**읽는 법:** 호스트는 숙소를 올리고 예약에 답하며, 운영자는 MVP에서 스크립트로만 일합니다. 점선은 Phase 2입니다.

```mermaid
flowchart LR
  H(["호스트<br/>owner admin member"])
  O(["운영자<br/>service_role 스크립트"])

  subgraph HM["호스트 기능 MVP"]
    W13["등록 13단계 마법사<br/>SY-F-014"]
    PH["사진 업로드 SY-F-015"]
    PUBL["게시 비공개 삭제<br/>SY-F-017"]
    BLK["날짜 차단 SY-F-018"]
    RES["예약함 승인 거절<br/>SY-F-009 SY-F-013"]
    HC["호스트 취소 SY-F-011"]
    RR["리뷰 답글 SY-F-020"]
    LA["소개 작성 도우미<br/>SY-F-029"]
    WK["호스트 위키 SY-F-031"]
    HT["호스트 유형 SY-F-037"]
  end

  subgraph OM["운영 MVP"]
    SU["숙소 정지 SY-F-022"]
    MA["자동 정리 매시간<br/>SY-F-023"]
  end

  subgraph P2["Phase 2"]
    PLUS["Host Plus 유료 플랜"]
    CO["공동 호스트 초대"]
    CON["운영 콘솔"]
  end

  H --> W13
  H --> PH
  H --> PUBL
  H --> BLK
  H --> RES
  H --> HC
  H --> RR
  H --> LA
  H --> WK
  H --> HT
  O --> SU
  O --> MA
  H -.-> PLUS
  H -.-> CO
  O -.-> CON
```

## 2. 구성요소

### 2-1. 웹, DB, 외부 서비스

**읽는 법:** 브라우저는 Next.js 웹만 부릅니다. 화면은 사용자 세션으로 DB(RLS와 RPC)를 부르고, service_role은 서버 전용 작업에만 씁니다. 코어 공통은 `ARCHITECTURE_DIAGRAMS.md` 그림 2와 같습니다.

```mermaid
flowchart TB
  UI["브라우저<br/>화면 지도 위젯"]

  subgraph WEB["웹 Next.js 16 Vercel icn1"]
    PUBP["공개 화면<br/>검색 상세 예약"]
    GST["게스트 화면<br/>내 여행 찜"]
    HST["호스트 화면<br/>마법사 예약함 달력"]
    SRV["도메인 서버 계층<br/>zod 허용 목록 RPC 호출"]
    API["Route Handler<br/>search uploads maps"]
    ADM["admin.ts service_role<br/>잡 enqueue 운영만"]
  end

  subgraph SB["Supabase 서울"]
    AUTH["Auth"]
    RPC["RPC 공개 4 호스트 9 게스트 6"]
    TBL["도메인 테이블 7개 RLS"]
    ST["Storage public-assets"]
    JOBS["core jobs"]
  end

  subgraph EXT["외부"]
    GM["Google Maps"]
    OW["OpenWeather 서버 프록시"]
    FX["환율 제공자 미정"]
  end

  UI --> PUBP
  UI --> GST
  UI --> HST
  PUBP --> SRV
  GST --> SRV
  HST --> SRV
  UI --> API
  SRV -->|"사용자 세션"| RPC
  RPC --> TBL
  SRV --> AUTH
  API -->|"서명 업로드 URL"| ST
  UI -->|"사진 PUT"| ST
  API --> GM
  API --> OW
  API -.-> FX
  SRV --> ADM
  ADM -->|"enqueue_job"| JOBS
```

### 2-2. AI와 잡

**읽는 법:** 브라우저는 `/api/ai/*`, `/api/voice/*`, `/api/host/wiki/*`만 부릅니다. Dify, FastAPI, 모델 제공자는 웹 서버 뒤에 있습니다. 크레딧은 웹 서버가 선차감하고 FastAPI가 정산 데이터를 남깁니다.

```mermaid
flowchart TB
  UI["브라우저"]

  subgraph WEB["웹 Next.js"]
    GATE["AI 게이트 /api/ai/*<br/>서명 토큰 선차감"]
    VOI["음성 /api/voice/*"]
    WKI["위키 /api/host/wiki/*"]
  end

  DIFY["Dify 공유 1개<br/>앱 stay-assistant"]

  subgraph RW["Railway"]
    FA["FastAPI apps/api<br/>RAG 그래프 2개 위키"]
    WK["잡 워커 runner<br/>크론 정산"]
  end

  subgraph LLM["모델"]
    COM["상용 LLM<br/>국외 이전 동의 시"]
    OSS["오픈소스 LLM 임베딩 음성"]
    EL["ElevenLabs"]
  end

  subgraph SB["Supabase"]
    CR["wallets credit_ledger"]
    AIT["ai_runs ai_usage ai_chunks"]
    JB["jobs"]
  end

  MAIL["이메일 발송 서비스 미정"]

  UI --> GATE
  UI --> VOI
  UI --> WKI
  GATE -->|"consume_credits"| CR
  GATE --> DIFY
  GATE -->|"Dify 장애 시 직접 경로"| FA
  DIFY -->|"내부 키 tools/answer"| FA
  WKI --> FA
  VOI --> EL
  VOI --> OSS
  FA --> COM
  FA --> OSS
  FA --> AIT
  WK -->|"claim_jobs"| JB
  WK --> FA
  WK --> MAIL
  WK -->|"정산 5분"| CR
```

## 3. 데이터 모델

**읽는 법:** 도메인 테이블 7개(`listings`부터 `wishlists`)와 코어 참조 3개, 호스트 유형 제안 1개입니다. 테넌트는 `org_id`, 게스트는 `guest_user_id`나 `user_id`로 구분합니다. 모든 테이블은 RLS가 켜져 있고 anon 권한은 없으며, 상태 컬럼은 사용자 UPDATE 권한에서 빠져 있습니다.

```mermaid
classDiagram
  class organizations {
    uuid id
    core 참조만
  }
  class profiles {
    uuid id
    core 참조만
  }
  class listings {
    uuid id
    uuid org_id
    text status
    smallint register_step
    numeric public_lat
    numeric public_lng
    int price_per_night
    boolean instant_book
    numeric rating_avg
    int review_count
    timestamptz deleted_at
  }
  class listing_private {
    uuid listing_id
    uuid org_id
    text street_address
    numeric lat
    numeric lng
    text checkin_guide
  }
  class listing_photos {
    uuid id
    uuid listing_id
    text storage_path
    smallint position
    text caption
  }
  class availability_blocks {
    uuid id
    uuid listing_id
    date start_date
    date end_date
    daterange period
  }
  class reservations {
    uuid id
    uuid org_id
    uuid listing_id
    uuid guest_user_id
    date check_in
    date check_out
    daterange stay
    text status
    int total_price
    timestamptz expires_at
  }
  class reviews {
    uuid id
    uuid reservation_id
    uuid guest_user_id
    smallint rating
    text status
    text host_reply
  }
  class wishlists {
    uuid user_id
    uuid listing_id
  }
  class host_profiles {
    uuid org_id
    text host_type
    text verify_status
  }

  organizations "1" --> "*" listings : 호스트 조직
  listings "1" --> "1" listing_private : 정확한 주소
  listings "1" --> "*" listing_photos : 최대 30장
  listings "1" --> "*" availability_blocks : 차단 기간
  listings "1" --> "*" reservations : 겹침 배타 제약
  reservations "1" --> "0..1" reviews : 예약당 1개
  listings "1" --> "*" wishlists : 찜
  profiles "1" --> "*" reservations : 게스트
  organizations "1" --> "0..1" host_profiles : 제안

  note for listing_private "SELECT 조직 멤버 또는 confirmed completed 예약 게스트"
  note for reservations "SELECT 게스트 본인 또는 호스트 조직 멤버. 쓰기는 RPC만"
  note for reviews "SELECT 작성자 또는 호스트 조직. 쓰기는 RPC만"
  note for wishlists "본인만. org_id 없음"
  note for host_profiles "제안 D18. 조직 owner만 읽기 쓰기"
```

## 4. 핵심 시퀀스

### 4-1. 예약 요청에서 승인까지 (SY-F-008, 009, 024)

**읽는 법:** 위에서 아래로 시간 순서입니다. 게스트 ID는 요청 본문이 아니라 세션에서 오고, 같은 기간의 이중 예약은 DB 배타 제약이 최종 판정합니다. 이 흐름은 크레딧을 쓰지 않습니다.

```mermaid
sequenceDiagram
  actor G as 게스트
  participant W as 웹 서버
  participant DB as Supabase RPC
  participant Q as jobs 큐
  participant WK as 워커
  actor H as 호스트

  G->>W: requestReservation 기간 인원 메시지
  W->>W: requireSession 와 zod 허용 목록 검증
  W->>DB: create_reservation 사용자 세션
  DB->>DB: auth.uid 확인 레이트 리밋 10 per hour
  DB->>DB: 게시 숙소 자기 숙소 아님 박수 인원 검사
  alt 겹치는 예약 또는 차단
    DB-->>W: SY003 배타 제약
    W-->>G: 409 날짜 변경 안내
  else 통과
    alt instant_book
      DB-->>W: confirmed
    else 승인 필요
      DB-->>W: requested expires_at 24시간
    end
    W->>Q: enqueue_job stay.notify.email
    W-->>G: reservation_id status total_price
  end
  WK->>Q: claim_jobs
  WK-->>H: 예약 요청 메일 주소 미포함
  H->>W: respondReservation accept
  W->>DB: respond_reservation 사용자 세션
  alt 만료 후 응답
    DB-->>W: SY007
  else 만료 전
    DB->>DB: requested 에서 confirmed 또는 declined 감사 기록
    DB-->>W: status
    W->>Q: enqueue_job stay.notify.email
  end
  G->>W: my_trips 조회
  W->>DB: my_trips
  DB-->>G: confirmed 일 때만 정확한 주소 포함
```

### 4-2. 숙소 AI 도우미 질문 (SY-F-027, 034)

**읽는 법:** 턴마다 먼저 크레딧을 선차감하고, 답이 전달되지 않으면 환불합니다. 근거는 숙소 공개 정보와 발행된 위키뿐이며 정확한 주소는 근거에 들어가지 않습니다.

```mermaid
sequenceDiagram
  actor G as 게스트
  participant W as 웹 AI 게이트
  participant C as 코어 크레딧
  participant D as Dify
  participant F as FastAPI
  participant L as LLM 라우터

  G->>W: POST ai/chat conversation_id request_id message
  W->>W: 세션 확인 ai_chat 플랜 키 대화 주인 확인
  W->>W: rate_limit_hit 분당 20턴 일일 한도
  W->>C: consume_credits conv id turn n 멱등 키
  alt 잔액 부족
    C-->>W: CR001
    W-->>G: 402
  else 선차감 성공
    W->>D: chat-messages dify_user HMAC
    alt Dify 정상
      D->>F: tools/answer 내부 키 대화 매핑
    else Dify 장애
      W->>F: tools/answer-direct 서명 토큰 10분
    end
    F->>F: 컬렉션 listing id 와 발행 위키 검색
    F->>L: resolve_ai_route 국외 이전 동의 반영
    L-->>F: 답변
    F-->>W: answer citations provider fallback
    W-->>G: SSE delta citations done
    W->>C: 실제 사용량으로 정산
  end
  opt 응답 미전달
    W->>C: refund_credits
  end
```

### 4-3. 소개 작성 도우미와 게시 (SY-F-014, 017, 029)

**읽는 법:** AI 초안은 자동 저장되지 않고 호스트가 고른 안만 `listings`에 저장됩니다. 게시 전환은 RPC가 게시 조건을 검사하고, 통과하면 색인 잡이 돌아갑니다.

```mermaid
sequenceDiagram
  actor H as 호스트
  participant W as 웹 서버
  participant C as 코어 크레딧
  participant F as FastAPI 그래프
  participant DB as Supabase RPC
  participant Q as jobs 큐

  H->>W: POST ai/listing-assist listing_id request_id
  W->>W: 호스트 세션 listing_assist 플랜 키 조직 일치
  W->>C: consume_credits run ai_run_id 호스트 조직 지갑
  W->>F: graphs stay.listing_assist runs 서명 토큰
  F->>F: load 공개 필드와 캡션
  F->>F: draft 제목 3안 설명 1안
  F->>F: compliance 금지 문구 연락처 검사
  F-->>W: result titles description ai_runs 1행
  W-->>H: SSE 노드 진행과 결과
  H->>W: 안 선택과 수정 후 saveListingStep
  W->>DB: RLS UPDATE listings 허용 컬럼만
  H->>W: transitionListing published
  W->>DB: transition_listing
  alt 제목 설명 요금 위치 사진 5장 미충족
    DB-->>W: SY010 빠진 항목 목록
    W-->>H: 단계 링크로 안내
  else 충족
    DB->>DB: published_at 기록 감사
    W->>Q: enqueue_job stay.ai.index_listing
    W-->>H: published
  end
  opt 생성 실패
    W->>C: refund_credits
  end
```

### 4-4. 사진 업로드 (SY-F-015)

**읽는 법:** 파일은 브라우저가 Storage로 직접 올리지만, 업로드 주소는 서버가 세션과 조직을 확인한 뒤 경로를 정해 서명합니다. 경로 규칙은 DB CHECK가 한 번 더 강제합니다.

```mermaid
sequenceDiagram
  actor H as 호스트
  participant W as 웹 Route Handler
  participant DB as Supabase RLS
  participant ST as Storage public-assets
  participant Q as jobs 큐
  participant WK as 워커

  H->>W: POST uploads/listing-photo type size
  W->>W: 세션 확인 MIME 3종 10MB 레이트 리밋
  W->>DB: 사용자 세션으로 숙소 조회
  alt 다른 조직 숙소
    DB-->>W: 0행
    W-->>H: 403
  else 내 조직 숙소
    W->>ST: createSignedUploadUrl org id listings listing id uuid
    W-->>H: upload_url path
  end
  H->>ST: 파일 PUT
  H->>W: confirmListingPhoto path position caption
  W->>DB: INSERT listing_photos 경로 CHECK 30장 상한
  W->>Q: enqueue_job stay.photo.process
  WK->>ST: 640px 2048px webp 변환
  WK->>DB: width height 갱신
```

## 5. 상태 머신

### 5-1. 숙소 상태 (listings.status)

**읽는 법:** 화살표 옆이 전이를 일으키는 주체입니다. 호스트 전이는 `transition_listing`, 정지와 해제는 서비스 스크립트 `suspend_listing`입니다. 삭제는 상태가 아니라 `deleted_at` 소프트 삭제입니다.

```mermaid
stateDiagram-v2
  [*] --> draft : create_listing 호스트
  draft --> published : 호스트 게시 조건 검사
  published --> unlisted : 호스트
  unlisted --> published : 호스트 조건 재검사
  draft --> suspended : 운영자
  published --> suspended : 운영자
  unlisted --> suspended : 운영자
  suspended --> unlisted : 운영자 사유 삭제
  draft --> [*] : owner admin 소프트 삭제
  published --> [*] : owner admin 소프트 삭제
  unlisted --> [*] : owner admin 소프트 삭제
```

### 5-2. 예약 상태 (reservations.status)

**읽는 법:** `requested`와 `confirmed`만 날짜를 점유합니다(배타 제약 대상). `instant_book` 숙소는 `requested`를 거치지 않고 `confirmed`로 시작합니다(`01_PRD.md` SY-F-008, `05_DATA_MODEL.md` 2.1절).

```mermaid
stateDiagram-v2
  [*] --> requested : 게스트 create_reservation
  [*] --> confirmed : 게스트 즉시 예약
  requested --> confirmed : 호스트 respond 만료 전
  requested --> declined : 호스트 respond 만료 전
  requested --> expired : 정리 RPC 매시간
  requested --> canceled_by_guest : 게스트
  confirmed --> canceled_by_guest : 게스트 체크인 전날까지
  confirmed --> canceled_by_host : 호스트 owner admin 사유 필수
  confirmed --> completed : 정리 RPC 체크아웃 후
  declined --> [*]
  expired --> [*]
  canceled_by_guest --> [*]
  canceled_by_host --> [*]
  completed --> [*]
```

### 5-3. 리뷰 상태 (reviews.status)

**읽는 법:** 리뷰는 완료된 예약의 게스트만 14일 안에 만듭니다. 숨김은 운영자가 service_role로 직접 바꾸며 평균 별점이 다시 계산됩니다.

```mermaid
stateDiagram-v2
  [*] --> visible : 게스트 create_review
  visible --> hidden : 운영자 service_role
  hidden --> [*]
```

## 6. 화면 흐름

### 6-1. 게스트 화면

**읽는 법:** 실선은 사용자 이동, 점선은 로그인이 필요해 `/login?next=`로 갔다가 돌아오는 경로입니다. 비로그인이 볼 수 있는 화면은 홈, 검색, 상세, 로그인, 가입뿐입니다.

```mermaid
flowchart LR
  HOME["홈 랜딩 /"]
  SRCH["검색 결과 /search"]
  DET["숙소 상세<br/>/listings/id"]
  BOOK["예약 확인<br/>/listings/id/book"]
  LOGIN["로그인 /login"]
  ONB["온보딩 /onboarding"]
  TRIPS["내 여행 /trips"]
  TDET["여행 상세 /trips/id"]
  REV["리뷰 작성<br/>/trips/id/review"]
  WISH["찜 /wishlist"]
  AIS["AI 도우미 시트"]
  SETAI["AI 설정 /settings/ai"]

  HOME --> SRCH
  SRCH --> DET
  DET --> BOOK
  DET --> AIS
  DET -.->|"비로그인 예약 찜"| LOGIN
  LOGIN -.->|"원래 화면 복귀"| DET
  LOGIN --> ONB
  BOOK --> TDET
  TRIPS --> TDET
  TDET --> REV
  DET --> WISH
  SETAI --> AIS
  HOME --> TRIPS
```

### 6-2. 호스트 화면

**읽는 법:** 호스트 화면만 좌측 GNB 셸 안에 있고, 등록 마법사는 GNB를 숨긴 전체 화면입니다. GNB 항목 수는 두 문서가 다릅니다(문서 불일치 1).

```mermaid
flowchart LR
  MODE["호스트 모드 전환"]
  HHOME["호스트 홈 /host"]
  RESV["예약함<br/>/host/reservations"]
  LIST["숙소 목록<br/>/host/listings"]
  NEW["새 숙소 시작<br/>/host/listings/new"]
  WIZ["등록 마법사 13단계<br/>edit/step"]
  CALN["달력<br/>listings/id/calendar"]
  WIKI["위키 /host/wiki"]
  SETH["호스트 되기<br/>/settings/host"]
  TRAVEL["여행 모드"]

  MODE -->|"숙소 0개"| NEW
  MODE -->|"숙소 있음"| HHOME
  HHOME --> RESV
  HHOME --> LIST
  HHOME --> CALN
  HHOME --> WIKI
  HHOME --> TRAVEL
  LIST --> NEW
  NEW --> WIZ
  WIZ -->|"게시 또는 나가기"| LIST
  LIST --> WIZ
  LIST --> CALN
  SETH -.->|"사업자 증빙 안내"| WIZ
```

## 7. 보안 경계

**읽는 법:** 바깥에서 안으로 들어올수록 신뢰가 커지고, 가장 안쪽 DB가 최종 방어선입니다. `T1`~`T8`은 `SECURITY.md` 2절 위협 번호이고 `§`는 `SECURITY_BASELINE.md` 장 번호입니다.

```mermaid
flowchart TB
  subgraph Z0["신뢰하지 않는 영역"]
    ATK["크롤러 봇 사기꾼<br/>T1 T3 T4 T5"]
    HJ["호스트 계정 탈취<br/>T2"]
  end

  subgraph Z1["입구 Vercel"]
    HDR["보안 헤더 CSP<br/>§18"]
    RLM["레이트 리밋 캡차<br/>T5 §8 §21"]
    MFA["호스트 관리자 2단계 인증 제안<br/>T2 §21"]
  end

  subgraph Z2["앱 서버"]
    VAL["zod 허용 목록<br/>필드 거름 §10"]
    FLT["외부 연락처 계좌 패턴 필터<br/>T3"]
    UPL["업로드 MIME 크기 재검사<br/>재인코딩 T6"]
    KEY["키는 서버 환경변수와 프록시<br/>T8 §19"]
  end

  subgraph Z3["DB 최종 방어선"]
    LP["listing_private 분리<br/>확정 게스트만 T1"]
    PUBC["공개 좌표 약 1km<br/>공개 RPC 4개만 anon"]
    EXC["배타 제약 이중 예약 차단"]
    RVW["후기는 완료 예약자만<br/>T4"]
    AUD["감사 로그 §9"]
  end

  subgraph Z4["AI 외부 제한 신뢰"]
    AIG["자료는 자료로만<br/>직접 호출 금지 T7 §16"]
    CORE["Dify 로그 30일<br/>org app 서버 확정"]
  end

  ATK --> HDR
  HJ --> MFA
  HDR --> RLM
  RLM --> VAL
  VAL --> FLT
  VAL --> UPL
  VAL -->|"사용자 세션"| LP
  VAL --> PUBC
  VAL --> EXC
  VAL --> RVW
  VAL --> AIG
  AIG --> CORE
  LP --> AUD
  KEY -.-> AIG
```

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)가 같은 DB RPC를 호출합니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)입니다.

### 8-1. API 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["브라우저 사용자"]
    AG["AI 에이전트<br/>게스트 비서 호스트 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    NX["Next.js 서버 계층<br/>Route Handler Server Action"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>익명 R0 또는 Bearer"]
    RL["레이트 리밋 IP 사용자"]
    TL["도구 8개<br/>필드 허용 목록 출력"]
    SAN["후기 소개글 untrusted 처리<br/>길이 제한 링크 제거"]
  end

  subgraph DB["DB 최종 방어선"]
    PUB["공개 RPC 4개<br/>anon"]
    USR["사용자 RPC<br/>my_trips my_wishlist host_reservations"]
    RLS["RLS 멤버십 검사<br/>listing_private 분리"]
  end

  BR --> NX
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  NX -->|"사용자 세션"| USR
  NX --> PUB
  TL -->|"익명"| PUB
  TL -.->|"사용자 토큰 D-M1"| USR
  PUB --> RLS
  USR --> RLS
  TL -.->|"확인 링크 D-M3"| NX
```

### 8-2. 예약 준비와 사람 확정 (`stay_prepare_reservation`)

```mermaid
sequenceDiagram
  autonumber
  actor G as 게스트
  participant A as AI 에이전트
  participant M as MCP 서버
  participant D as DB RPC
  participant W as 웹 예약 화면

  G->>A: 이 숙소 10월 30일부터 2박 예약해줘
  A->>M: stay_prepare_reservation 숙소 날짜 인원
  M->>D: 읽기 RPC 상세와 불가 날짜
  D-->>M: 가능 여부와 요금 정보
  Note over M: 저장하지 않음<br/>create_reservation 호출 안 함
  M-->>A: 가능 총액 확정 전 문구 확인 링크 15분
  A-->>G: 예약 가능합니다 아직 확정 전입니다 링크에서 확인하세요
  G->>W: 링크 열기 로그인 세션 일치 확인
  W-->>G: 숙소 날짜 금액 표시
  G->>W: 예약 요청 클릭
  W->>D: create_reservation 사용자 세션
  D-->>W: requested 또는 SY003 등 오류
  W-->>G: 결과 안내 호스트 응답 대기
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R0["R0 익명 읽기 MVP"]
    T1["stay_search_listings"]
    T2["stay_get_listing"]
    T3["stay_get_unavailable_dates"]
    T4["stay_get_listing_reviews"]
  end
  subgraph R1["R1 R2 로그인 읽기 1.5"]
    T5["stay_my_trips"]
    T6["stay_my_wishlist"]
    T7["stay_host_reservations"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T8["stay_prepare_reservation"]
  end
  subgraph W1["W1 쓰기 Phase 2"]
    T9["stay_toggle_wishlist"]
  end
  subgraph NO["만들지 않음"]
    N1["예약 확정 승인 취소"]
    N2["숙소 삭제 정지 결제"]
    N3["정확한 주소 좌표"]
  end
  R0 --> R1 --> PR --> W1
  PR -.->|"사람이 웹에서 확정"| N1
```

## 문서 불일치

1. **호스트 GNB 항목 수:** `10_HOST_DASHBOARD.md` 2절은 7개(홈, 예약, 숙소, 캘린더, 위키, 크레딧, 설정)이고 `03_SCREENS_UX.md` 8.1절은 6개(홈, 예약함, 숙소, 달력, 위키, 여행 모드로)입니다. 그림 6-2는 03장 경로 기준으로 그렸고 크레딧·설정은 `/settings/host`만 반영했습니다.
2. **인증 가드 파일명:** `02_ARCHITECTURE.md` 2절과 `06_AGENT_PLAN.md` SY-06-003은 `src/middleware.ts`, 공통 구성도는 `proxy.ts`입니다. 그림에는 파일명을 넣지 않았습니다.
3. **테이블 수와 호스트 유형:** `README.md`와 `05_DATA_MODEL.md` 머리는 "테이블 7개"인데 11절은 `stay.host_profiles` 신설을 제안합니다. 그림 3은 7개 + 제안 1개로 그렸고 `(제안)`을 붙였습니다. 모놀리스 SQL에는 아직 없습니다.
4. **`fx_rates`:** `04_API.md` 6.6절이 환율 캐시 `fx_rates`를 말하지만 `05_DATA_MODEL.md`에는 테이블이 없어 그림 3에서 뺐습니다.
5. **익명 호출 가능 RPC 수:** `04_API.md` 3절은 공개 RPC 4개와 `stay_today()`도 anon에 허용하고, `05_DATA_MODEL.md` 4절은 "공개 RPC 4개만"이라고 합니다. 그림은 4개로 적었습니다.

6. **MCP 가격 계산:** `MCP.md`의 `stay_prepare_reservation`이 총액을 돌려주려면 읽기용 가격 계산 RPC가 필요한데 `04_API.md` 3절에는 없고 `create_reservation`이 내부에서 계산합니다(`MCP.md` D-M5). 그림 8-2는 "요금 정보"를 DB가 준다고만 그렸습니다.
7. **MCP 인증:** 로그인 도구가 사용자 토큰을 어떻게 받는지 문서에 없습니다(`MCP.md` D-M1). 그림 8-1의 점선이 그 부분입니다.

## 갱신 규칙

위 근거 문서(특히 `05_DATA_MODEL.md` 상태 전이 표, `04_API.md` 엔드포인트, `SECURITY.md` 위협표)를 고치면 해당 그림도 같은 변경에서 함께 고친다.
