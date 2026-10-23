# DIAGRAMS: Microweb Studio UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 이 폴더의 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid). 전체 구조도는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일입니다.

**제품 한 줄 정의:** 하객에게 보내는 모바일 마이크로웹(1차 청첩장, 이후 돌잔치·부고장)을 템플릿 엔진으로 만들고, 같은 사이트의 쇼룸(포트폴리오, 가격표, 시뮬레이터, 견적 문의)으로 대행 제작을 파는 제품. AI 문구 제안, 문구 위키·RAG, 제작 상담 채팅, 음성 대화·인사말 음성·하객 음성 방명록이 MVP에 들어 있습니다 (`README.md` 1절).

**근거 문서:** `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`(미작성, 아래 7절 참조), 공통 `../_platform-core/SECURITY_BASELINE.md`, `CORE_SPEC.md`.

**표기:** 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·예약 실행, "(제안)" = 문서가 제안이라고 밝힌 값, "Phase 2" = MVP 이후. 숫자 MW-F-nnn은 `01_PRD.md` 기능 ID.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-1 | 사용자와 MVP 기능 | 유스케이스(flowchart) | `01_PRD.md` 1절, 2절 |
| 1-2 | Phase 2·3 기능 | 유스케이스(flowchart) | `01_PRD.md` 2절 |
| 2-1 | 구성요소: 웹·워커·저장소 | 컴포넌트 | `02_ARCHITECTURE.md` 2~4절, 7절 |
| 2-2 | 구성요소: AI 계층 | 컴포넌트 | `02_ARCHITECTURE.md` 2절, 5절, `04_API.md` 6절 |
| 3 | 데이터 모델 | 클래스 | `05_DATA_MODEL.md` 1~4절 |
| 4-1 | 대행 제작 게시 | 시퀀스 | `03_SCREENS_UX.md` F1, `04_API.md` 2절, `02_ARCHITECTURE.md` 4절 |
| 4-2 | 하객 음성 방명록 | 시퀀스 | `03_SCREENS_UX.md` F8, `04_API.md` 2절 |
| 4-3 | AI 문구·구성 제안 | 시퀀스 | `03_SCREENS_UX.md` F5, `04_API.md` 2절 |
| 4-4 | 셀프 결제와 발행 (Phase 2) | 시퀀스 | `03_SCREENS_UX.md` F4, `04_API.md` 2절 |
| 5-1 | 사이트 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-2 | 문의(lead) 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-3 | 제작 주문 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 6-1 | 화면 흐름: 공개 영역 | flowchart | `03_SCREENS_UX.md` 1절, F1~F3 |
| 6-2 | 화면 흐름: 스튜디오 | flowchart | `03_SCREENS_UX.md` 1절, 8절 |
| 7 | 보안 신뢰 경계 | flowchart | `04_API.md` 1절, `05_DATA_MODEL.md` 4절·7절, `01_PRD.md` 6절 |

## 1. 사용자와 기능

### 그림 1-1. 사용자와 MVP 기능

읽는 법: 왼쪽은 역할, 오른쪽은 MVP 기능입니다. 하객과 대행 고객은 로그인하지 않습니다(`02_ARCHITECTURE.md` 9.5절). 운영자만 초대제로 로그인합니다.

```mermaid
flowchart LR
  OP(["운영자 한결<br/>(대행 제작자)"])
  CU(["예비부부 서윤<br/>(대행 고객, 계정 없음)"])
  GU(["하객 민호<br/>(로그인 없음)"])
  KA(["지식 조직 관리자<br/>(platform_admin)"])

  subgraph SHOW["쇼룸 MVP"]
    direction TB
    S1["템플릿 카탈로그·포트폴리오<br/>가격표·시뮬레이터"]
    S2["견적 문의 저장<br/>MW-F-017"]
    S3["3D 히어로<br/>MW-F-036"]
  end
  subgraph GUEST["하객 페이지 MVP"]
    direction TB
    G1["청첩장 열람 /i/slug<br/>지도·계좌 복사·공유"]
    G2["방명록·RSVP<br/>MW-F-006, 008"]
    G3["AI 축하말 초안<br/>MW-F-007"]
    G4["음성 방명록<br/>MW-F-032"]
  end
  subgraph STUDIO["스튜디오 MVP"]
    direction TB
    T1["리드·제작 주문 장부<br/>MW-F-018, 019"]
    T2["사이트 편집기·사진 업로드<br/>MW-F-012, 013"]
    T3["시안 링크·고객 승인<br/>MW-F-016"]
    T4["게시·중단·만료<br/>MW-F-014, 015"]
    T5["AI 문구 제안·제작 상담 채팅<br/>MW-F-026, 029, 030"]
    T6["인사말 음성<br/>MW-F-031"]
  end
  subgraph KNOW["지식 관리 MVP"]
    direction TB
    K1["문구 코퍼스 색인<br/>MW-F-027"]
    K2["문구 위키 검수·게시<br/>MW-F-028"]
  end

  CU --> S1
  CU --> S2
  CU --> T3
  GU --> G1
  GU --> G2
  GU --> G3
  GU --> G4
  OP --> T1
  OP --> T2
  OP --> T4
  OP --> T5
  OP --> T6
  KA --> K1
  K1 --> K2
```

### 그림 1-2. Phase 2·3 기능

읽는 법: `01_PRD.md` 2절 표에서 MVP 밖으로 둔 기능을 구분 그대로 모았습니다.

```mermaid
flowchart TB
  subgraph P2["Phase 2"]
    direction TB
    A1["돌잔치·부고장 템플릿"]
    A2["셀프서비스 편집 + Toss 크레딧팩 발행<br/>MW-F-025"]
    A3["쇼룸 비로그인 방문자 AI 상담"]
    A4["사용자 보이스 선택<br/>본인 음성 복제"]
    A5["HEIC 사진 지원"]
  end
  subgraph P3["Phase 3 이후"]
    direction TB
    B1["히어로 AI 보정 1회"]
    B2["나머지 9개 모델<br/>(카탈로그에 준비 중으로만 노출)"]
  end
  subgraph OPT["선택"]
    direction TB
    C1["카카오·네이버 로그인<br/>Stage C, P2 선택"]
  end
```

## 2. 구성요소

### 그림 2-1. 웹·워커·저장소

읽는 법: 하객 쓰기는 anon이 DB에 직접 쓰지 못하고 Route Handler가 service_role 전용 DB 함수를 부릅니다. 운영자 쓰기는 사용자 세션과 RLS, 게시 같은 무거운 작업은 `microweb.media` 큐의 워커가 맡습니다. AI 계층은 그림 2-2.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    SHW["쇼룸"]
    GST["하객 페이지 /i/slug"]
    PRV["시안 /p/token"]
    STD["스튜디오 편집기"]
  end

  subgraph WEB["Next.js 앱 (Vercel)"]
    PUB["api/public/*<br/>방명록·RSVP·문의·승인"]
    STA["api/studio/*<br/>사이트·업로드·게시"]
    BIL["api/billing/*<br/>Phase 2"]
    AIG["AI 게이트<br/>(그림 2-2)"]
    ENG["engine<br/>블록 JSON을 렌더"]
  end

  subgraph WK["워커 microweb.media (Railway 제안)"]
    J1["asset.process<br/>EXIF 제거·파생본"]
    J2["site.publish<br/>스냅샷 생성"]
    J3["site.unpublish_assets<br/>site.purge"]
    J4["voice.transcode"]
    CR["크론<br/>expire 10분·purge 매일<br/>voice_expire 매시·ai_settle 5분"]
  end

  subgraph DB["Supabase"]
    CORE["core 스키마<br/>조직·크레딧·잡·감사"]
    MW["microweb 스키마<br/>테이블 10개"]
    ORG[("Storage org-files<br/>비공개")]
    PA[("Storage public-assets<br/>게시 파생본만")]
    VA[("Storage voice-audio<br/>하객 음성")]
    RT["Realtime 진행률"]
  end

  EXT1[("카카오 지도·공유")]
  EXT2[("Toss Payments<br/>Phase 2")]
  EXT3[("운영자 알림 메일")]

  SHW --> PUB
  GST -->|"anon 읽기"| MW
  GST --> PUB
  PRV --> PUB
  STD --> STA
  STD --> ENG
  GST --> ENG
  PUB -->|"service_role RPC"| MW
  STA -->|"사용자 세션 RLS"| MW
  STA --> CORE
  STA -->|"서명 URL"| ORG
  CORE -->|"claim_jobs"| J1
  CORE -->|"claim_jobs"| J2
  CORE -->|"claim_jobs"| J3
  CORE -->|"claim_jobs"| J4
  J1 --> ORG
  J2 --> PA
  J3 --> PA
  J3 --> VA
  CR --> MW
  CORE --> RT
  RT -.-> STD
  GST -.-> EXT1
  BIL --> EXT2
  PUB --> EXT3
```

### 그림 2-2. AI 계층

읽는 법: 스튜디오는 `/api/ai/*`, `/api/voice/*`, 하객은 `/api/public/[slug]/*`만 부릅니다. Dify, FastAPI, 제공자는 직접 부르지 않습니다. 워커는 FastAPI를 호출하지 않고 AI 제공자 키도 없습니다(`02_ARCHITECTURE.md` 2절). 하객 음성 방명록은 오픈소스 STT만 씁니다.

```mermaid
flowchart LR
  STD["스튜디오<br/>채팅·마이크·문구 제안"]
  GST["하객 페이지<br/>축하말·음성 방명록"]
  subgraph WEB["Next.js 서버"]
    GATE["AI 게이트 /api/ai/*<br/>/api/voice/*"]
    PGT["하객 라우트<br/>greeting, guestbook/voice"]
    TOK["서명 토큰 발급<br/>iss microweb"]
    VC["core-voice 어댑터"]
  end
  DIFY["Dify 앱 microweb-chat"]
  subgraph FA["FastAPI apps/api"]
    RT["모델 라우터"]
    G1["그래프<br/>microweb.invitation_copy"]
    G2["그래프<br/>microweb.guest_greeting"]
    TL["/tools/answer 모드 consult"]
    RG["RAG·위키"]
  end
  subgraph DB["Supabase core"]
    AIT["ai_conversations·ai_messages<br/>ai_runs·ai_usage"]
    VEC["ai_chunks·wiki_pages<br/>지식 조직 MICROWEB_KNOWLEDGE_ORG_ID"]
    VJ["voice_sessions·voice_jobs"]
  end
  LLM[("상용·오픈소스 LLM")]
  VOX[("ElevenLabs·오픈소스 음성")]

  STD --> GATE
  GST --> PGT
  GATE --> TOK
  PGT --> TOK
  GATE -->|"채팅"| DIFY
  GATE -.->|"Dify 장애 시"| TL
  GATE -->|"ai-copy"| G1
  PGT -->|"visitor 토큰"| G2
  DIFY -->|"내부 키"| TL
  G1 --> RT
  G2 --> RT
  TL --> RT
  RT --> LLM
  G1 --> VEC
  TL --> VEC
  RG --> VEC
  GATE --> VC
  PGT --> VC
  VC --> VOX
  VC --> VJ
  FA --> AIT
  GATE --> AIT
```

## 3. 데이터 모델

### 그림 3. 핵심 테이블과 관계

읽는 법: `microweb` 스키마 10개 테이블 전부와 참조하는 코어 4개입니다. 선 위 글자는 관계입니다.
접근 주체: 하객 쓰기(`guestbook_entries`, `rsvp_responses`)와 `leads` 생성은 service_role 전용 RPC만 합니다. `sites`는 콘텐츠 컬럼만 운영자 세션이 UPDATE하고 상태·과금·게시 컬럼은 RPC·트리거만 바꿉니다. `site_publications`는 anon이 공개 9컬럼만 읽습니다(게시 중, 만료 전). `templates`, `portfolio_items`는 전역으로 anon이 읽고 쓰기는 service뿐입니다. 운영자 읽기 조건은 `has_studio_access`(멤버 + 엔타이틀먼트 + `studio_access` 허용 목록).

```mermaid
classDiagram
  class studio_access {
    org_id uuid
    mode
    max_active_sites
    revoked_at
  }
  class templates {
    code
    kind
    status
    release_phase
    self_publish_credits
  }
  class sites {
    id uuid
    org_id uuid
    template_id
    slug
    status
    content
    expires_at
    preview_token_hash
    publish_ledger_id
    publish_job_id
  }
  class site_publications {
    site_id
    slug
    version
    is_live
    expires_at
  }
  class site_assets {
    id uuid
    kind
    storage_path
    status
    exif_stripped
  }
  class guestbook_entries {
    id uuid
    author_name
    body
    status
    voice_job_id
    has_voice
  }
  class rsvp_responses {
    id uuid
    guest_name
    attending
    party_size
  }
  class leads {
    id uuid
    source
    status
    privacy_consent_at
    purge_after
  }
  class production_orders {
    id uuid
    lead_id
    site_id
    amount_krw
    status
    payment_method
  }
  class portfolio_items {
    slug
    category
    status
    client_permission_at
  }
  class core_organizations {
    id uuid
  }
  class core_jobs {
    id uuid
  }
  class core_credit_ledger {
    id uuid
  }
  class core_voice_jobs {
    id uuid
  }

  core_organizations "1" --> "1" studio_access : 초대제 허용
  core_organizations "1" --> "*" sites : 조직 소유
  templates "1" --> "*" sites : template_id
  sites "1" --> "0..1" site_publications : 공개 스냅샷
  sites "1" --> "*" site_assets : 사진 음원 음성
  sites "1" --> "*" guestbook_entries : 하객
  sites "1" --> "*" rsvp_responses : 하객
  core_organizations "1" --> "*" leads : 스튜디오 조직
  leads "0..1" --> "*" production_orders : lead_id
  sites "0..1" --> "*" production_orders : site_id
  sites "*" ..> "0..1" core_credit_ledger : publish_ledger_id
  sites "*" ..> "0..1" core_jobs : publish_job_id
  guestbook_entries "*" ..> "0..1" core_voice_jobs : voice_job_id
```

`portfolio_items`는 다른 테이블과 FK가 없는 전역 쇼룸 데이터라 관계선이 없습니다.

## 4. 핵심 시퀀스

### 그림 4-1. 대행 제작 게시 (MW-F-014, 016, 019)

읽는 법: 대행 모드는 결제된 제작 주문과 고객 승인이 있어야 `request_publish`가 통과합니다(재게시는 승인 면제). 게시 잡이 실패하면 이전 상태로 복구됩니다. 셀프 모드의 크레딧 선차감은 그림 4-4.

```mermaid
sequenceDiagram
  actor OP as 운영자 owner/admin
  actor CU as 고객
  participant ST as api/studio
  participant DB as microweb DB
  participant WK as 워커 microweb.media
  participant PUB as site_publications

  OP->>ST: 주문 생성 후 transition paid, 결제수단 필수
  ST->>DB: create_order, transition_order
  OP->>ST: 공개 동의 기록
  ST->>DB: confirm_disclosure_consent
  OP->>ST: 시안 토큰 발급
  ST->>DB: issue_preview_token sha256만 저장
  ST-->>OP: 시안 링크 한 번만 표시
  CU->>ST: 시안 확인 후 승인
  ST->>DB: record_customer_approval
  alt 토큰 만료
    DB-->>CU: MW013
  end
  OP->>ST: POST publish, request_id
  ST->>ST: 역할 owner/admin, 블록 zod 검증
  ST->>DB: request_publish 주문과 승인 동의 만료일 확인
  alt 미결제 또는 미승인 또는 동의 없음
    DB-->>OP: MW008 MW009 MW006
  else 통과
    DB-->>ST: sites publishing
    ST->>WK: enqueue_job site.publish
    ST-->>OP: 202 job_id
  end
  WK->>WK: 파생본을 public-assets로 복사
  alt 성공
    WK->>DB: finalize_publish
    DB->>PUB: 스냅샷 is_live
  else 실패
    WK->>DB: fail_publish 이전 상태 복구
  end
```

### 그림 4-2. 하객 음성 방명록 (MW-F-006, 032)

읽는 법: 하객은 로그인이 없어서 서명된 방문자 쿠키와 IP 해시로 식별합니다. 음성은 오픈소스 STT만 쓰고 상용으로 대체하지 않습니다. 녹음 전 고지 확인이 먼저입니다.

```mermaid
sequenceDiagram
  actor G as 하객
  participant API as api/public/slug
  participant DB as microweb DB
  participant CO as core RPC
  participant STT as 오픈소스 음성 서버

  G->>API: voice/consent notice_version
  API->>API: 허니팟, Origin, 고지문 버전 확인
  API->>CO: rate_limit_hit IP 해시 10분 5회
  API->>DB: is_site_live, voice_sessions INSERT
  API-->>G: 방문자 쿠키 24시간
  G->>API: voice/transcribe 30초 2MB 이하
  API->>API: 쿠키, voice_enabled, 플랜 features 확인
  API->>CO: rate_limit_hit IP 10분 2건 하루 5건
  API->>STT: 서명 토큰 scope voice, microweb_guestbook_voice
  alt STT 실패
    STT-->>API: 오류
    API-->>G: 글로 남겨 주세요 상용 대체 없음
  else 성공
    STT-->>API: 자막
    API->>CO: voice_jobs store_audio true, 만료 1시간
    API-->>G: caption, voice_token
  end
  G->>API: guestbook 이름 본문 voice_token
  API->>DB: submit_guestbook_entry 리밋 URL 중복 검사
  alt rate_limited 또는 spam 또는 closed
    DB-->>G: 429 422 410
  else ok
    API->>DB: attach_guestbook_voice 같은 조직 third_party_notice 작업만
    API->>CO: 음성 만료를 공개 만료 + 30일로 연장
    API-->>G: id, voice true
  end
```

### 그림 4-3. AI 문구·구성 제안 (MW-F-026, 034, 035)

읽는 법: 셀프 모드는 시작 전 2크레딧을 선차감하고 대행 모드는 0크레딧에 사용량 기록과 공정 사용 상한입니다. 결과는 저장되지 않고 운영자가 "적용"을 눌러야 `sites.content`에 병합됩니다. 호출은 서명 토큰 1회용(`jti`)입니다.

```mermaid
sequenceDiagram
  actor OP as 운영자 member 이상
  participant ST as api/studio ai-copy
  participant CO as core RPC
  participant FA as FastAPI invitation_copy
  participant DB as microweb DB

  OP->>ST: tone, memo 500자, request_id
  ST->>ST: 세션, features.ai_copy, studio_access
  ST->>CO: rate_limit_hit 사이트 30일 20회, 사용자 5회 시간당
  opt 셀프 모드
    ST->>CO: consume_credits 2, 멱등 키 run
    alt 잔액 부족
      CO-->>ST: CR001
      ST-->>OP: 402
    end
  end
  ST->>FA: 서명 토큰 scope graph microweb.invitation_copy
  FA->>FA: intake 메모의 전화 계좌 마스킹
  FA->>FA: retrieve 지식 조직 컬렉션만
  FA->>FA: draft_copy 3안, propose_composition
  FA->>FA: compliance banned.json, 걸린 안 1회 재작성
  alt 모든 제공자 실패
    FA-->>ST: failed
    ST->>CO: refund_credits
    ST-->>OP: 다시 시도
  else 완료
    OP->>ST: GET run_id 폴링
    ST-->>OP: variants 3, composition, citations
    OP->>ST: apply variant, blocks, base_updated_at
    ST->>DB: 블록 zod와 allowed_blocks 재검증 후 UPDATE
    ST->>CO: 감사 site.ai_copy_apply 본문 제외
  end
```

### 그림 4-4. 셀프 결제와 발행 (Phase 2, MW-F-025)

읽는 법: 결제 금액은 `credit_packs`의 값이고 클라이언트 금액은 대조만 합니다. 금액 불일치(PM001)는 Toss 승인을 취소하고 주문을 `failed`로 기록합니다. 발행 시 크레딧을 선차감하고 잡 실패는 자동 환불입니다.

```mermaid
sequenceDiagram
  actor U as 셀프 사용자 owner/admin
  participant API as api/billing, api/studio
  participant T as Toss Payments
  participant CO as core RPC
  participant WK as 워커 site.publish

  U->>API: POST billing orders credit_pack_code
  API->>CO: payment_orders INSERT 금액은 credit_packs
  API-->>U: orderId, amount
  U->>T: 결제창
  U->>API: POST confirm paymentKey orderId amount
  API->>API: payment_orders 금액과 요청 금액 대조
  alt 불일치
    API-->>U: 409, Toss 호출 없음
  else 일치
    API->>T: confirm
    API->>CO: confirm_payment_order
    alt PM001 또는 PM409
      CO-->>API: 오류
      API->>CO: fail_payment_order amount_mismatch
      API->>T: 결제 취소 API
      API->>CO: 감사 payment.confirm_mismatch
    else 정상
      CO-->>API: 크레딧 지급
    end
  end
  U->>API: POST publish request_id
  API->>CO: consume_credits self_publish_credits
  alt 잔액 부족
    CO-->>API: CR001
    API-->>U: 402
  else 차감
    API->>CO: request_publish, enqueue_job
    WK->>CO: 최종 실패 시 fail_job 자동 환불
  end
```

## 5. 상태 머신

### 그림 5-1. 사이트 `sites`

읽는 법: 전이는 트리거가 강제하며 service_role 쓰기에도 적용됩니다(위반 MW001). 괄호 아닌 라벨의 주체가 전이를 일으킵니다. `archived`는 종단이며 30일 뒤 `site.purge`가 지웁니다. publishing 30분 초과는 `expire_sites`가 실패 처리합니다.

```mermaid
stateDiagram-v2
  [*] --> draft : create_site 만 허용
  draft --> review : 운영자 member 이상
  draft --> publishing : request_publish
  draft --> archived : owner/admin
  review --> draft : 운영자
  review --> publishing : request_publish
  review --> archived : owner/admin
  publishing --> published : finalize_publish
  publishing --> draft : fail_publish
  publishing --> unpublished : fail_publish
  publishing --> expired : fail_publish
  published --> publishing : request_publish 재게시
  published --> unpublished : owner/admin
  published --> expired : expire_sites 스케줄
  unpublished --> publishing : owner/admin
  unpublished --> expired : service
  unpublished --> archived : owner/admin
  expired --> publishing : 만료일 연장 후
  expired --> archived : owner/admin
  archived --> [*] : 30일 뒤 site.purge
```

### 그림 5-2. 문의 `leads`

읽는 법: 전이는 `set_lead_status`로만 하고 member 이상이 호출합니다. `won`, `spam`은 종단입니다. 문의는 1년 뒤 자동 삭제, 삭제 요청은 즉시 삭제합니다.

```mermaid
stateDiagram-v2
  [*] --> new : create_lead 하객 문의
  new --> contacted : member 이상
  new --> quoted : member 이상
  new --> lost : member 이상
  new --> spam : member 이상
  contacted --> quoted : member 이상
  contacted --> won : member 이상
  contacted --> lost : member 이상
  contacted --> spam : member 이상
  quoted --> won : member 이상
  quoted --> lost : member 이상
  quoted --> spam : member 이상
  lost --> contacted : member 이상
  won --> [*]
  spam --> [*]
```

### 그림 5-3. 제작 주문 `production_orders`

읽는 법: 모든 전이는 owner/admin이 합니다. `paid`로 가려면 결제수단이 필수이고 참조에 12자리 이상 숫자열은 거부됩니다(카드번호 저장 금지). `closed`, `canceled`, `refunded`는 종단입니다.

```mermaid
stateDiagram-v2
  [*] --> quoted : create_order 만 허용
  quoted --> paid : owner/admin 결제수단 필수
  quoted --> canceled : owner/admin
  paid --> in_production : owner/admin
  paid --> refunded : owner/admin
  in_production --> delivered : owner/admin
  in_production --> refunded : owner/admin
  delivered --> closed : owner/admin
  delivered --> refunded : owner/admin
  closed --> [*]
  canceled --> [*]
  refunded --> [*]
```

`guestbook_entries.status`(visible, hidden, spam)는 `moderate_guestbook_entry`로만 바뀌어 상태 머신으로 그리지 않았습니다.

## 6. 화면 흐름

### 그림 6-1. 공개 영역 (쇼룸, 하객, 시안)

읽는 법: 이 화면들은 로그인이 필요 없고 인증 단계(A/B/C)와 무관합니다. 쇼룸 헤더에 운영자 로그인 링크를 새로 넣지 않습니다(`02_ARCHITECTURE.md` 9.5절).

```mermaid
flowchart TB
  HOME["/ 쇼룸 랜딩<br/>3D 히어로"] --> TPL["/templates<br/>카탈로그"]
  HOME --> POR["/portfolio"]
  HOME --> PRC["/pricing"]
  HOME --> SIM["/simulator<br/>업종 x 등급"]
  TPL --> TD["/templates/code<br/>샘플 미리보기"]
  SIM -->|"선택값 전달"| CON["/contact<br/>견적 문의"]
  PRC --> CON
  TD --> CON
  CON --> DONE["접수 완료<br/>영업일 1일 안 연락"]
  KAKAO(["카카오톡 링크"]) --> GST["/i/slug<br/>하객 페이지"]
  GST --> MAP["지도 앱 딥링크"]
  GST --> ACC["계좌 복사·tel/sms"]
  GST --> GB["방명록·AI 초안·음성"]
  GST --> RSVP["참석 여부"]
  GST -->|"만료"| GONE["404 또는 410 안내"]
  MAIL(["운영자가 보낸 시안 링크"]) --> PV["/p/token<br/>시안 확인"]
  PV --> APR["이 시안으로 진행<br/>이름 입력"]
  PV -->|"토큰 만료"| EXP["새 링크 요청 안내"]
```

### 그림 6-2. 스튜디오 (운영자)

읽는 법: 초대 메일로 들어와 약관과 AI 처리 방식을 고른 뒤 `/studio`에서 시작합니다. `/pending`, `/no-access`는 허용 목록과 엔타이틀먼트가 없을 때 가는 안내 화면입니다. 대시보드 셸·GNB의 관리자 화면과 하객 관리 모아 보기는 결정 대기(`01_PRD.md` D-22, D-23)라 그리지 않았습니다.

```mermaid
flowchart TB
  INV(["초대 메일"]) --> AINV["/auth/invite<br/>비밀번호·약관"]
  LOGIN["/login"] --> ST
  AINV --> TERMS["/studio/onboarding/terms"]
  TERMS --> ONB["/studio/onboarding/ai<br/>국외 이전 동의 선택"]
  ONB --> HOME
  ST{"허용 목록과<br/>엔타이틀먼트"}
  ST -->|"없음"| PEND["/pending"]
  ST -->|"엔타이틀먼트 없음"| NOA["/no-access"]
  ST -->|"통과"| HOME["/studio<br/>오늘 처리할 일"]
  HOME --> LEADS["/studio/leads"]
  LEADS --> LD["/studio/leads/id"]
  LD --> ORD["/studio/orders<br/>제작 주문 장부"]
  HOME --> SITES["/studio/sites"]
  SITES --> NEW["/studio/sites/new"]
  NEW --> EDIT["/studio/sites/id<br/>편집기"]
  SITES --> EDIT
  EDIT --> GUESTS["/studio/sites/id/guests<br/>방명록·RSVP"]
  EDIT -.-> AIP(["AI 문구 제안 패널"])
  EDIT -.-> VGP(["인사말 음성"])
  HOME -.-> CHAT(["제작 상담 시트"])
  CHAT --> HIST["/studio/chat"]
  HOME --> WIKI["/studio/wiki<br/>문구 위키 읽기"]
  HOME --> SET["/studio/settings/ai"]
  HOME --> BILL["/studio/billing<br/>Phase 2"]
  ADM["/studio/admin/knowledge, wiki<br/>platform_admin 전용"]
```

## 7. 보안 경계

읽는 법: `SECURITY.md`는 아직 템플릿 상태(자산·위협·외부 서비스 표가 "작성 필요")라서, 이 그림은 같은 제품의 `04_API.md` 1절, `05_DATA_MODEL.md` 4절·7절, `01_PRD.md` 6절, `02_ARCHITECTURE.md` 5절에 적힌 통제를 신뢰 경계로 모은 것입니다. SECURITY.md가 채워지면 위협 번호(T)를 붙여 다시 그립니다. §는 `../_platform-core/SECURITY_BASELINE.md` 장 번호입니다.

```mermaid
flowchart TB
  subgraph UNT["신뢰하지 않음"]
    GU["하객·고객<br/>로그인 없음"]
    BOT["봇·스팸"]
    OPB["운영자 브라우저"]
  end

  subgraph SRV["서버 경계 Next.js"]
    PIN["공개 입구<br/>허니팟·Origin·16KB·레이트 리밋 §8 §21"]
    IPH["IP 해시 sha256 일 단위 솔트<br/>원문 저장 금지 §12"]
    SES["requireSession + studio_access<br/>§2 §17"]
    VAL["zod 검증·블록 스키마<br/>매직바이트·EXIF 제거 §10"]
    AIC["AI 게이트<br/>서명 토큰·입력 최소화·국외 동의 §16"]
  end

  subgraph DBZ["DB 경계 RLS·RPC"]
    ANON["anon은 게시 스냅샷 9컬럼만<br/>게시 중·만료 전"]
    WR["쓰기는 service 전용 RPC 또는<br/>컬럼 GRANT + 트리거 §4"]
    TRG["상태 전이 트리거 MW001<br/>service_role에도 적용"]
    AUD["감사 write_audit<br/>개인정보 제외 §9"]
  end

  subgraph STO["저장소 경계"]
    PRIV[("org-files 비공개<br/>서명 URL")]
    PUBA[("public-assets 이미지 전용<br/>게시 파생본")]
    VA[("voice-audio 비공개<br/>5분 서명 URL 중계")]
  end

  subgraph OUTB["외부로 나가는 데이터"]
    LLM[("상용 LLM·ElevenLabs<br/>국외 이전 동의 조직만")]
    OSS[("오픈소스 모델·음성<br/>하객 음성은 이쪽만")]
    TOSS[("Toss Phase 2<br/>서버 confirm·금액 대조 §6")]
  end

  GU --> PIN
  BOT --> PIN
  PIN --> IPH
  IPH --> WR
  OPB --> SES --> VAL --> WR
  WR --> TRG
  WR --> AUD
  ANON -.->|"공개 읽기"| GU
  VAL --> PRIV
  VAL --> PUBA
  PIN --> VA
  SES --> AIC
  PIN --> AIC
  AIC -->|"호칭 토큰·어조만 전송"| LLM
  AIC --> OSS
  SES --> TOSS
```

| 제품 고유 위험(문서에 적힌 것) | 대응(그림 7의 어느 상자) | 근거 |
|---|---|---|
| 하객 수만큼 늘어나는 AI 비용·오픈 프록시 | 범용 프록시 없음, 하객 AI 라우트 2개만, 게시 중 사이트만, 사이트 30일 한도 | `05_DATA_MODEL.md` 7절, `04_API.md` 2절 |
| 계좌·전화 공개 | 공개 동의 기록 전 게시 불가(MW006), noindex 기본, 만료 후 파생본 삭제 | `01_PRD.md` 6절, MW-F-004, MW-F-011 |
| 제3자(하객) 음성 | 고지 확인, 오픈소스 강제, 만료·삭제 경로, 14세 미만 보호자 안내(법무 확인 D-12) | `01_PRD.md` 6절, `02_ARCHITECTURE.md` 5.1절 |
| 시안 토큰 유출 | 토큰은 sha256만 저장, TTL 기본 7일 최대 14일 | MW-F-016 |
| 결제 기록의 카드번호 | 12자리 이상 숫자열 참조 거부 | MW-F-019 |
| 원본 프로젝트의 노출된 `.env.local` | 폐기·회전, gitleaks 시크릿 스캔 | `05_DATA_MODEL.md` 7절, `07_SOURCE_MIGRATION.md` |

SECURITY.md 3절(세션 만료, CSP 도메인, 레이트 리밋 수치, 감사 보존, 백업, 알림 수신자)은 전부 "(작성 필요)"라서 그림에 수치를 넣지 않았습니다. 세션·헤더 §18, 공급망 §19, 운영 §20은 공통 규칙을 참조합니다.

## 문서 불일치

- `SECURITY.md`가 템플릿 그대로(자산·위협·외부 서비스·고유 위험 모두 "작성 필요")인데, 같은 제품의 `01_PRD.md` 6절·`05_DATA_MODEL.md` 7절에는 보안 설계가 이미 구체적으로 있습니다. 그림 7은 후자를 따랐습니다. 또 SECURITY.md는 공통 규칙을 "1~21장"이라 하나 SECURITY_BASELINE은 22장까지 있습니다(22장은 제품별 SECURITY.md 규정).
- 그 밖의 모순은 확인하지 못했습니다. 참고: `04_API.md` 2절의 관리자 행(studio_access 부여, 템플릿·포트폴리오 편집)은 라우트만 있고 화면이 없습니다(`03_SCREENS_UX.md` 8.1절 D-22 결정 대기).

## 갱신 규칙

`01_PRD.md`~`05_DATA_MODEL.md`, `SECURITY.md`를 고치면 이 그림도 같은 변경에서 함께 고칩니다. SECURITY.md를 채우면 7절 그림을 위협 번호 기준으로 다시 그립니다.
