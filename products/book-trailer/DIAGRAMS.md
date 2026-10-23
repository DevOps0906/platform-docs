# DIAGRAMS: NOMAD Book Trailer UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 이 폴더의 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid). 전체 구조는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일입니다.

**제품 한 줄 정의**: 원고(PDF·EPUB·DOCX·MD·TXT)나 FLORA 책을 넣으면 AI가 "팔리는 훅"을 찾아 브리프를 만들고, 장르별 문법으로 스토리보드를 짜고, 장면 이미지·내레이션·자막·음악을 붙여 쇼츠(9:16)·유튜브(16:9)·인스타(1:1, 4:5)·표지 루프 영상을 한 번에 렌더하고, 구매 링크 클릭까지 측정하는 북트레일러 자동화 SaaS입니다(`README.md` 1절).

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`, `MCP.md`(미작성 상태, 7번 그림 참고), 공통 `../_platform-core/SECURITY_BASELINE.md`.

**표기**: **실선 화살표** = 호출·데이터 흐름, **점선** = 검증·참조·보조 경로, "(제안)" = 문서가 제안이라고 한 값, "(P1)" = MVP 직후 단계. 기능 ID는 `TR-F-nnn`(01_PRD), 오류 코드는 `TRnnn`(04_API 7절)입니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1 | 사용자와 기능 | 유스케이스 관점 | 01_PRD 1절, 2절, 3절 |
| 2 | 구성요소 | 컴포넌트 | 02_ARCHITECTURE 2절, 3절, 4절, 7절 |
| 3 | 데이터 모델 | 클래스 | 05_DATA_MODEL 1절, 2절, 4절 |
| 4-1 | 원고 분석과 브리프 | 시퀀스 | 04_API 2절, 3절, 4절, 03_SCREENS_UX 2.1절 |
| 4-2 | 장면 이미지·내레이션 생성 | 시퀀스 | 04_API 2절, 6절, 02_ARCHITECTURE 4절 |
| 4-3 | 멀티포맷 렌더 | 시퀀스 | 04_API 2절, 3절, 02_ARCHITECTURE 4절 |
| 4-4 | 구매 링크 클릭과 외부 승인 | 시퀀스 | 04_API 2절, 3절, 03_SCREENS_UX 2.5절 |
| 5-1 | 실행·렌더 상태 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-2 | 분석 상태와 트레일러 상태 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-3 | 외부 승인 상태 | 상태 머신 | 05_DATA_MODEL 2.15절, 3절 |
| 6 | 화면 흐름 | 흐름도 | 03_SCREENS_UX 1절, 2절, 8절 |
| 7 | 보안 경계 | 신뢰 경계 | 05_DATA_MODEL 4절, 7절, 02_ARCHITECTURE 2절, 6절, 04_API 1절 |
| 8-1 | 웹 경로와 MCP 층 (제안) | 컴포넌트 | MCP.md 2·3절, 04_API 1·2절 |
| 8-2 | 렌더 준비와 사람 확정 | 시퀀스 | MCP.md 6절, 04_API 2절 |
| 8-3 | 도구 위험 등급과 노출 단계 | 블록 | MCP.md 1·2절 |

## 1. 사용자와 기능

읽는 법: 왼쪽이 역할, 오른쪽이 기능입니다. 실선은 MVP, 점선은 P1·Phase 2입니다. 역할 접근은 03_SCREENS_UX 1절 표, 플랜(free, creator, publisher)은 01_PRD 4절을 따릅니다.

```mermaid
flowchart LR
  W(["member<br/>서연·하은"])
  AD(["owner / admin"])
  VW(["viewer<br/>읽기 전용"])
  PUB(["publisher 팀<br/>도윤 (P1)"])
  EXT(["저자·편집자<br/>토큰 링크 (P1)"])
  BUY(["독자<br/>구매 링크 클릭"])
  PA(["플랫폼 관리자"])

  subgraph MVP["MVP"]
    direction TB
    A1["책 등록·권리 확인·표지 키트<br/>TR-F-010~014"]
    A2["원고 분석·브리프 3안<br/>TR-F-020~023"]
    A3["스토리보드·장면 편집<br/>TR-F-030~034"]
    A4["이미지·내레이션·음악·자막<br/>TR-F-040~044"]
    A5["멀티포맷 렌더·미리보기<br/>TR-F-050~054"]
    A6["메타데이터·구매 링크·클릭<br/>TR-F-060~062"]
    A7["코치 채팅·위키·음성<br/>TR-F-100~104"]
    A8["결제·플랜<br/>TR-F-001~003"]
    A9["운영자 카탈로그<br/>TR-F-120"]
  end

  subgraph P1["P1 / Phase 2"]
    direction TB
    B1["FLORA 가져오기 TR-F-015"]
    B2["YouTube 업로드 TR-F-063"]
    B3["외부 승인 링크·팀<br/>TR-F-071, 072"]
    B4["클론 목소리·화이트라벨<br/>TR-F-130, 133 (Phase 2)"]
  end

  W --> A1
  W --> A2
  W --> A3
  W --> A4
  W --> A5
  W --> A6
  W --> A7
  AD --> A8
  AD -->|"삭제"| A1
  VW -.->|"읽기만"| A3
  PA --> A9
  BUY --> A6
  PUB -.-> B3
  EXT -.->|"승인·수정 요청"| B3
  W -.-> B1
  W -.-> B2
  AD -.-> B4
```

## 2. 구성요소

읽는 법: 제품 고유 모듈은 오케스트레이터, 렌더러, 컴포지션 패키지입니다. 오케스트레이터는 fal·ElevenLabs 키를, FastAPI는 LLM 키를 가지며 서로 직접 호출하지 않습니다(02_ARCHITECTURE 2절 "렌더러와 FastAPI의 경계"). 미리보기와 서버 렌더는 같은 컴포지션 코드를 씁니다. 코어는 `core` 한 묶음으로 줄였습니다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["앱 화면·작업실<br/>Remotion Player 미리보기"]
    PUBP["공개 페이지<br/>/b/code, /review/token"]
  end

  subgraph WEB["Next.js (Vercel)"]
    API["Route Handler<br/>requireSession trailer"]
    AIG["AI 게이트·음성<br/>/api/ai, /api/voice"]
    INT["/api/internal<br/>잡 토큰·AI 정산"]
  end

  subgraph WK["워커 (Railway)"]
    ORC["오케스트레이터<br/>큐 trailer.ai<br/>fal·TTS 호출"]
    REN["렌더러 Remotion<br/>큐 trailer.render, trailer.media"]
  end

  CMP["packages/<br/>trailer-compositions"]

  subgraph AIS["AI 서비스"]
    FA["FastAPI apps/api<br/>그래프 4종·파서<br/>인용 대조·compliance"]
    DF["Dify trailer-chat"]
  end

  subgraph SB["Supabase"]
    CORE["core 스키마<br/>크레딧·결제·잡·감사"]
    TR["trailer 스키마<br/>start_run·start_render"]
    ST["Storage<br/>media·catalog·exports"]
    VEC["pgvector<br/>원고 청크"]
  end

  subgraph EXT["외부"]
    FAL[("fal Flux")]
    VOX[("ElevenLabs·<br/>오픈소스 음성")]
    LLM[("상용·오픈소스 LLM")]
    TOSS[("Toss Payments")]
    YT[("YouTube (P1)")]
  end

  UI --> API
  UI -.-> CMP
  PUBP --> TR
  API -->|"service RPC<br/>검사·선차감·enqueue"| TR
  TR --> CORE
  API --> TOSS
  UI --> AIG
  AIG --> DF
  AIG -.->|"EdDSA 서명 토큰"| FA
  DF -.->|"내부 키"| FA
  ORC --> INT
  INT -.->|"잡 토큰"| ORC
  ORC -.->|"잡 토큰"| FA
  ORC --> FAL
  ORC --> VOX
  ORC --> ST
  REN -.-> CMP
  REN --> ST
  REN --> CORE
  FA --> LLM
  FA --> VEC
  ORC -.-> YT
```

## 3. 데이터 모델

읽는 법: `trailer` 스키마 17개 중 핵심 14개입니다(`book_digests`, `reviews`, `runtime_config`는 5번 그림과 문서 참고). 모든 하위 테이블은 `(부모 id, org_id)` 복합 FK로 같은 조직 행만 가리킵니다. 접근 주체는 note에 적었고, 서버 컬럼은 사용자 GRANT가 없고 트리거가 되돌립니다.

```mermaid
classDiagram
  class grammars {
    code
    book_genres
    beats
    status
  }
  class templates {
    code
    grammar_code
    composition_id
    formats
    tier
  }
  class music_tracks {
    mood
    bpm
    tier
    license_source
    license_verified_at
    storage_path
  }
  class books {
    org_id
    title
    genre
    source
    manuscript_path
    digest_status
    rights_ack_version
    deleted_at
  }
  class purchase_links {
    book_id
    store
    url
    is_affiliate
    short_code
    click_count
  }
  class link_clicks {
    link_id
    clicked_at
    ip_hash
    tag
  }
  class brand_kits {
    book_id
    palette
    font_display
    font_body
  }
  class trailers {
    book_id
    grammar_code
    template_code
    formats
    duration_s
    spoiler_level
    voice
    music_rights_ack
    current_brief_id
    status
  }
  class briefs {
    trailer_id
    version
    source
    content
  }
  class scenes {
    trailer_id
    position
    kind
    text
    narration
    quote_verified
    visual
    revision
  }
  class scene_assets {
    scene_id
    kind
    source
    ai_generated
    rights_ack
    status
  }
  class metadata_packs {
    trailer_id
    platform
    link_ids
    has_affiliate
    disclosure
  }
  class generation_runs {
    kind
    credits_reserved
    credit_ledger_id
    idempotency_key
    job_id
    status
  }
  class renders {
    trailer_id
    format
    resolution
    watermark
    ai_label
    snapshot
    request_id
    status
    expires_at
  }

  grammars "1" --> "many" templates
  grammars "1" --> "many" trailers
  templates "1" --> "many" trailers
  music_tracks "0..1" --> "many" trailers
  books "1" --> "many" trailers
  books "1" --> "many" purchase_links
  books "0..1" --> "many" brand_kits
  brand_kits "0..1" --> "many" trailers : set null
  purchase_links "1" --> "many" link_clicks
  trailers "1" --> "many" briefs
  trailers "1" --> "many" scenes
  trailers "1" --> "many" metadata_packs
  trailers "1" --> "many" renders
  scenes "1" --> "many" scene_assets
  generation_runs ..> books
  generation_runs ..> trailers
  generation_runs ..> scenes
  metadata_packs ..> purchase_links : link_ids

  note for grammars "카탈로그 3종은 org 없음. 공개 행 + has_trailer_access 또는 platform_admin만 SELECT. 쓰기 GRANT 없음. music_tracks는 storage_path 컬럼 SELECT 제외"
  note for books "멤버 + 엔타이틀먼트 RLS. 해시, 분석 상태, 권리 확인 컬럼은 GRANT 없음. acknowledge_rights RPC만 기록"
  note for trailers "voice, storyboard_version, music_rights_ack_at/by는 서버 전용. approved는 480p가 아닌 성공 렌더 필요"
  note for scenes "end_card는 사용자가 만들거나 바꿀 수 없음. quote_ref, quote_verified, revision은 서버와 트리거"
  note for briefs "불변 버전. 사용자 INSERT는 manual만. UPDATE와 DELETE 정책 없음"
  note for link_clicks "서버만 기록 record_link_click. 원 IP 컬럼 없음"
  note for generation_runs "사용자는 SELECT만. start_run, finish_run, fail_run은 service_role 전용"
  note for renders "사용자는 SELECT만. watermark와 ai_label은 start_render가 플랜으로 결정. 480p는 항상 워터마크"
  note for metadata_packs "has_affiliate와 disclosure는 트리거가 채움. 사용자가 지워도 다시 들어감"
```

## 4. 핵심 시퀀스

### 4-1. 원고 분석과 브리프 (TR-F-010, 012, 020, 021)

읽는 법: 위에서 아래로 시간 순서입니다. 권리 확인(`TR003`)과 선행 단계(`TR004`)는 DB 함수 `start_run` 안에서 검사하고, 선차감·잡 등록도 같은 트랜잭션입니다. Route Handler는 크레딧 RPC를 직접 부르지 않습니다.

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant RH as Route Handler
  participant DB as trailer start_run
  participant ORC as 오케스트레이터
  participant FA as FastAPI 그래프

  B->>RH: POST /api/uploads/sign (원고)
  RH-->>B: 서명 업로드 URL (413 415)
  B->>RH: POST /api/uploads/complete
  RH->>RH: 크기 MIME 매직바이트 재검사
  RH->>DB: enqueue book.parse (service)
  B->>RH: POST /api/books/id/rights version
  RH->>DB: acknowledge_rights + 감사 로그
  B->>RH: POST /api/books/id/digest request_id
  RH->>RH: requireSession, zod, 플랜 사전 검사
  RH->>DB: start_run digest 20 + 10만자당 8
  Note over DB: 멱등 run:trailer:request_id, 권리 TR003, 선행 TR004, 진행 중 TR002, 선차감 CR001
  DB-->>RH: generation_runs 202
  ORC->>DB: claim_jobs trailer.ai
  ORC->>FA: 잡 토큰 scope graph:trailer.digest
  FA-->>ORC: 장 요약 인물 주제 청크 색인
  ORC->>DB: finish_run (digest_status ready)
  B->>RH: POST /api/trailers/id/brief (8 크레딧)
  RH->>DB: start_run brief
  ORC->>FA: 그래프 trailer.brief
  FA->>FA: 인용을 원고와 글자 단위 대조, compliance
  FA-->>ORC: 브리프 3안
  ORC->>DB: finish_run (briefs source ai)
  alt 최종 실패
    ORC->>DB: fail_job 자동 환불 후 fail_run
  end
```

### 4-2. 장면 이미지·내레이션 생성 (TR-F-040, 041, 042)

읽는 법: 이미지와 TTS는 오케스트레이터가 호출합니다(LLM 키 없음). 내레이션은 첫 결과에서 제공자·보이스가 고정되고, 이후 다른 목소리 결과는 `finish_run`이 거부합니다(같은 목소리 규칙).

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant RH as Route Handler
  participant DB as trailer start_run
  participant ORC as 오케스트레이터
  participant FAL as fal Flux
  participant V as 음성 제공자

  B->>RH: POST /api/scenes/id/image request_id
  RH->>DB: start_run scene_image 3 크레딧
  DB-->>RH: 202 (TR004 TR005 CR001)
  ORC->>DB: claim_jobs trailer.ai
  ORC->>FAL: 영어 프롬프트 + 스타일 프리셋 + seed
  alt 안전 검사 차단
    FAL-->>ORC: 차단
    ORC->>DB: fail_job 환불, 재시도 없음
    DB-->>B: 장면 설명을 바꿔 주세요
  else 정상
    FAL-->>ORC: 이미지
    ORC->>DB: finish_run (scene_assets ai_generated true, ready)
  end
  B->>RH: POST /api/scenes/id/narration request_id
  RH->>DB: start_run narration (EL 2 또는 OSS 1)
  ORC->>V: TTS (voice 고정 전이면 선택값, 이후 고정값)
  V-->>ORC: 오디오
  ORC->>DB: finish_run
  Note over DB: 첫 결과면 trailers.voice 고정. 다른 제공자나 보이스는 거부
  DB-->>B: Realtime 진행률
```

### 4-3. 멀티포맷 렌더 (TR-F-050, 052, 080)

읽는 법: 렌더 직전 compliance와 인용 검증이 서버에서 한 번 더 일어납니다. 워터마크·AI 표시는 요청 입력이 아니라 `start_render`가 플랜으로 정해 스냅샷에 고정하고, 렌더러는 스냅샷만 읽습니다.

```mermaid
sequenceDiagram
  autonumber
  participant B as 브라우저
  participant RH as POST renders
  participant DB as trailer start_render
  participant REN as 렌더러
  participant ST as Storage exports

  B->>RH: request_id, format, resolution, confirm 플래그
  RH->>RH: compliance 사전 검사 (FAIL이면 거부, WARN은 409 확인)
  RH->>DB: start_render
  Note over DB: 멱등, 권리 TR003, 포맷 해상도 플랜 TR005, 엔드카드 TR007, 인용 TR006, 음악 TR011, 동시 렌더 2
  DB->>DB: 워터마크 AI 표시 결정, 스냅샷 고정, 선차감 4~10
  DB-->>RH: renders 202
  REN->>DB: claim_jobs trailer.render
  REN->>REN: 스냅샷을 props로, 길이 보정, renderMedia
  REN->>ST: 영상 포스터 SRT 업로드
  REN->>DB: finish_render (경로 검사)
  alt 렌더 실패
    REN->>DB: fail_job 최종 실패 시 전액 환불, fail_render
  end
  B->>RH: GET /api/renders/id/download
  RH->>ST: 서명 URL 10분
  RH-->>B: 302 (만료 410)
```

### 4-4. 구매 링크 클릭과 외부 승인 (TR-F-062, 071, P1)

읽는 법: 로그인 없는 공개 입구 두 개입니다. 둘 다 앱 서버가 코드·토큰 해시만 service RPC에 넘기고 레이트 리밋이 붙습니다. 승인 링크 토큰 원문은 만들 때 한 번만 보여 주고 DB에는 sha256만 저장합니다.

```mermaid
sequenceDiagram
  autonumber
  participant R as 독자
  participant PG as 공개 라우트
  participant DB as trailer service RPC
  participant M as member
  participant A as 저자

  R->>PG: GET /b/code?t=태그
  PG->>PG: IP당 분당 60 (제안), 초과 429
  PG->>DB: record_link_click (ip_hash, 활성 링크만)
  DB-->>PG: 원 URL
  PG-->>R: 302 서점
  M->>PG: POST /api/reviews 렌더 1~5개 (publisher)
  PG->>DB: open_review (token sha256만 저장)
  DB-->>M: 링크 1회 표시
  A->>PG: GET /review/token
  A->>PG: POST decision, comment
  PG->>DB: decide_review (sha256 조회)
  alt 만료 또는 이미 결정
    DB-->>A: TR009 410
  else 승인
    DB->>DB: reviews approved, trailers approved
    DB-->>A: 결과
  end
```

## 5. 상태 머신

### 5-1. 실행·렌더 상태 (`generation_runs.status`, `renders.status`)

읽는 법: 사용자는 쓸 수 없고 서버(워커 포함)만 바꿉니다. 트리거 `enforce_run_status_transition`이 service에도 적용되어 허용 전이 밖은 `TR001`입니다. queued에서 succeeded로 바로 갈 수 없습니다.

```mermaid
stateDiagram-v2
  [*] --> queued : insert (start_run, start_render)
  queued --> running : 워커 클레임
  queued --> canceled : 취소
  queued --> failed : 서버
  running --> succeeded : finish_run, finish_render
  running --> failed : fail_run, fail_render
  running --> queued : 재시도
  succeeded --> [*]
  failed --> [*]
  canceled --> [*]
```

### 5-2. 분석 상태와 트레일러 상태 (`books.digest_status`, `trailers.status`)

읽는 법: 분석 상태는 서버가 바꾸고, 원고가 바뀌면 트리거가 `none`으로 되돌립니다. 트레일러는 멤버가 active와 archived를 오가고, approved는 480p가 아닌 성공 렌더가 있어야 하며(`TR004`) 승인 링크의 `decide_review`도 이 상태를 만듭니다.

```mermaid
stateDiagram-v2
  state "책 분석 digest_status" as D {
    [*] --> none
    none --> queued : start_run digest
    queued --> ready : finish_run
    queued --> failed : fail_run, reconcile_runs
    ready --> none : 원고 변경 (트리거)
    failed --> none : 원고 변경 (트리거)
  }
  state "트레일러 status" as T {
    [*] --> active
    active --> archived : 멤버
    archived --> active : 멤버
    active --> approved : 멤버 또는 decide_review
  }
```

### 5-3. 외부 승인 상태 (`reviews.status`, P1)

읽는 법: 종료 상태는 고정입니다. 전이는 서버(`decide_review`, 만료 크론, 철회)만 일으키고 트리거 `enforce_review_transition`이 강제합니다.

```mermaid
stateDiagram-v2
  [*] --> pending : open_review
  pending --> approved : 저자 decide_review
  pending --> changes_requested : 저자 decide_review
  pending --> expired : 만료 크론 7일
  pending --> revoked : 서버 철회
  approved --> [*]
  changes_requested --> [*]
  expired --> [*]
  revoked --> [*]
```

## 6. 화면 흐름

읽는 법: 가입 → 동의 → 책 등록 마법사 → 트레일러 만들기 → 단계 화면(브리프, 작업실, 렌더, 게시) 순서가 첫 사용 흐름입니다. 단계 화면은 트레일러 머리줄의 탭으로 이동합니다(8.5절, D-18 기본값). 점선은 P1 또는 어디서나 여는 화면입니다.

```mermaid
flowchart TB
  LAND["/ 랜딩 3D 히어로"]
  SAMP["/samples"]
  PRICE["/pricing"]
  LOGIN["/login<br/>/auth/callback"]
  TERMS["/onboarding/terms<br/>/onboarding/ai"]
  HOME["/home"]
  BOOKS["/books 목록"]
  BNEW["/books/new<br/>4단계 마법사"]
  BDET["/books/id<br/>개요·링크·성과·키트"]
  WIKI["/books/id/wiki"]
  TNEW["/trailers/new?book="]
  TLIST["/trailers 목록"]
  BRIEF["/trailers/id/brief"]
  STUDIO["/trailers/id/studio"]
  RENDERS["/trailers/id/renders"]
  PUBL["/trailers/id/publish"]
  COACH["/coach"]
  BILL["/settings/billing"]
  REVIEW["/review/token (P1)"]
  OPS["/ops/catalog"]

  LAND --> LOGIN
  LAND --> SAMP
  LAND --> PRICE
  LOGIN --> TERMS
  TERMS --> HOME
  HOME --> BNEW
  HOME --> BOOKS
  HOME --> TLIST
  BOOKS --> BDET
  BNEW --> BDET
  BDET --> TNEW
  BDET --> WIKI
  TNEW --> BRIEF
  TLIST --> BRIEF
  BRIEF --> STUDIO
  STUDIO --> RENDERS
  RENDERS --> PUBL
  STUDIO -.->|"코치 탭"| COACH
  HOME -.-> COACH
  STUDIO -.->|"잠금 업그레이드"| BILL
  RENDERS -.->|"승인 링크 (P1)"| REVIEW
  HOME -.->|"platform_admin"| OPS
```

## 7. 보안 경계

읽는 법: 바깥에서 안쪽으로 신뢰가 높아집니다. 이 제품의 `SECURITY.md`는 아직 양식만 있고 자산·위협 표가 비어 있어서(맨 끝 "문서 불일치"), 이 그림은 05_DATA_MODEL 4절·7절, 02_ARCHITECTURE 2절·6절, 04_API 1절의 차단 설계를 근거로 그렸습니다. 공통 규칙은 `SECURITY_BASELINE.md`의 장 번호(§)로 참조합니다. 리뷰 "높음" 번호는 `README.md` 2.1절의 두 리뷰(Shorts Maker, Toon-Factory) 번호입니다.

```mermaid
flowchart TB
  subgraph Z0["① 신뢰하지 않는 영역"]
    B["브라우저·봇·타 조직 사용자<br/>독자·외부 저자(토큰)"]
  end

  subgraph Z1["② 입구 (Vercel)"]
    H["보안 헤더·세션·레이트 리밋<br/>/b/code IP당 60, /review IP당 20<br/>§8, §18, §21"]
  end

  subgraph Z2["③ 앱 서버 (신뢰)"]
    AZ["requireSession trailer<br/>org는 세션에서만<br/>§11"]
    VAL["zod 검증·업로드 매직바이트<br/>경로는 서버가 생성<br/>§10"]
    TK["서명 토큰 개인키<br/>오케스트레이터에는 없음<br/>§16, §19"]
  end

  subgraph Z3["④ 데이터 (최종 방어선)"]
    RLS["RLS + 복합 FK org_id<br/>EXECUTE 회수 서버 RPC<br/>§1~4, §15"]
    SRV["서버 컬럼 GRANT 없음 + 트리거 되돌림<br/>권리 확인·voice·워터마크·AI 표시"]
    CAT["음악 원본 비공개 버킷<br/>라이선스 CHECK (Toon #2, #6)"]
    AUD["감사 로그<br/>권리 확인·승인·FLORA<br/>§9"]
  end

  subgraph Z4["⑤ 워커·AI·외부 (제한 신뢰)"]
    ORC["오케스트레이터: fal·TTS 키<br/>LLM 키 없음 잡 토큰"]
    REN["렌더러: 스냅샷만 신뢰<br/>키 없음 공개 포트 없음"]
    FA["FastAPI: LLM 키만<br/>인용 대조·compliance §16"]
    WH["Toss 웹훅 서명 필수<br/>payment_orders 선저장 §6"]
  end

  subgraph Z5["⑥ 법적·정책 통제"]
    LAW["권리 확인 TR003·인용 TR006<br/>AI 표시·대가성 문구 TR008<br/>국외 이전 동의 AI002"]
  end

  B -->|"모든 요청"| Z1
  Z1 --> Z2
  Z2 -->|"사용자 세션"| RLS
  Z2 -->|"service_role 서버만"| SRV
  Z2 -.->|"토큰"| FA
  ORC -.->|"service_role"| SRV
  REN -.->|"service_role"| CAT
  WH --> Z2
  RLS --> AUD
  SRV -.-> LAW
```

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)는 같은 서버 계층과 RLS 조회를 거칩니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)입니다. 이 제품은 원고와 그 파생물(분석, 브리프, 장면)과 렌더 파일을 도구로 내보내지 않고, 생성·렌더·배포 도구를 만들지 않습니다. 읽는 범위가 좁아 이 층 전체를 베타 이후 호출 로그를 보고 넓히거나 접는 것이 기본안입니다(`MCP.md` D-M5).

### 8-1. 웹 경로 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["브라우저 마케터"]
    AG["AI 에이전트<br/>마케터 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    RH["Next.js Route Handler<br/>requireSession 후 zod"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>Bearer 토큰 필수"]
    RL["레이트 리밋 사용자"]
    TL["도구 6개<br/>필드 허용 목록 출력"]
    SAN["제목 라벨 untrusted 처리<br/>원고 파생물 파일 경로 제거"]
  end

  subgraph DB["DB 최종 방어선"]
    RLS["RLS 멤버십 엔타이틀먼트<br/>books trailers runs renders"]
    ST["클릭 통계 읽기<br/>경로 확인 D-M3"]
  end

  subgraph NO["MCP가 부르지 않는 것"]
    RUN["start_run start_render<br/>크레딧 차감 AI 호출 업로드 배포"]
  end

  BR --> RH
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  RH -->|"사용자 세션"| RLS
  RH --> RUN
  TL -->|"사용자 토큰 D-M1"| RLS
  TL -.->|"service 여부 확인"| ST
  TL -.->|"확인 링크 D-M2"| RH
```

### 8-2. 렌더 준비와 사람 확정 (`trailer_prepare_render`)

```mermaid
sequenceDiagram
  autonumber
  actor M as 마케터
  participant A as AI 에이전트
  participant S as MCP 서버
  participant D as DB RLS 조회
  participant W as 웹 렌더 화면

  M->>A: 이 트레일러 1080p 쇼츠로 렌더해줘
  A->>S: trailer_prepare_render 트레일러 포맷 해상도
  S->>D: 권리 확인 인용 검증 음악 권리 장면 수 읽기
  D-->>S: 조건 충족 여부
  Note over S: 저장 안 함 크레딧 차감 안 함<br/>start_render 호출 안 함
  S-->>A: 가능 여부 막는 사유 TR 코드 예상 크레딧 확정 전 문구 확인 링크 15분
  A-->>M: 아직 렌더 전입니다 링크에서 권리와 인용을 확인하세요
  M->>W: 링크 열기 로그인 세션 일치 확인
  W-->>M: 포맷 해상도 워터마크 AI 표시 크레딧 표시
  M->>W: 권리 인용 경고 확인 후 렌더 클릭
  W->>D: 기존 renders 경로 compliance 사전 검사 후 start_render 선차감
  D-->>W: 접수 또는 TR003 TR006 TR011 CR001 오류
  W-->>M: 진행 상태 안내 파일은 웹에서만 받기
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R1["R1 로그인 읽기 MVP"]
    T1["trailer_list_books"]
    T2["trailer_list_trailers"]
    T3["trailer_get_run_status"]
    T4["trailer_list_renders"]
    T5["trailer_get_link_stats"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T6["trailer_prepare_render"]
  end
  subgraph NO["만들지 않음"]
    N1["원고 분석 브리프 장면 내용"]
    N2["분석 이미지 내레이션 렌더 시작"]
    N3["렌더 파일 다운로드"]
    N4["권리 인용 음악 확인"]
    N5["승인 링크 유튜브 업로드 구매 링크 변경"]
  end
  R1 --> PR
  PR -.->|"사람이 웹에서 확정"| N2
```

## 문서 불일치

| # | 내용 | 그림에서 고른 쪽 |
|---|---|---|
| 1 | `SECURITY.md`가 양식 상태(자산, 위협, 수치 표가 "작성 필요")라 7번 그림에 쓸 제품 위협 표가 없음. 대신 05장 4절·7절, 02장 6절, 04장 1절을 근거로 사용 | 위 3개 문서 |
| 2 | 화면 내비게이션: `03_SCREENS_UX.md` 1절 머리말은 왼쪽 내비게이션 "홈, 책, 코치, 설정"이고 8.3절은 GNB 메뉴 순서를 새로 정하며, `/trailers` 목록(8.4절)은 1절 화면 목록에 없는 새 경로(D-19 미정) | 6번 그림은 8.4절의 `/trailers`와 8.5절의 단계 탭을 포함 |
| 3 | `03_SCREENS_UX.md` 8.5절은 단계 화면 머리줄을 D-18 기본값(제안)으로 둠. 확정 아님 | 6번 그림에 포함하되 본문에 제안 표시 |
| 4 | MCP 읽기 경로: `04_API.md`에는 책·트레일러·실행·렌더를 읽는 GET이 없고(통계 `GET /api/books/:id/stats`만 있음) 화면은 RLS 직접 조회와 Realtime 구독을 쓴다. 렌더 전 compliance 사전 검사는 `POST .../renders` 안에서 `start_render` 직전에 일어나 읽기 전용으로 따로 부를 수 없다(`MCP.md` D-M3, D-M4) | 그림 8-1은 RLS 조회를 실선으로, 통계의 읽기 방식은 점선(확인 필요)으로 그림 |

## 갱신 규칙

`01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md` 중 하나를 고치면 이 문서의 해당 그림(위 표의 근거 절)도 같은 변경에서 함께 고칩니다.
