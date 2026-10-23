# DIAGRAMS: 로컬뉴스 클라우드(가칭, local-news) UML 시각화

작성일 2026-10-23. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 Mermaid로 바로 렌더링됩니다.

**제품 한 줄 정의:** 기자 1~10명 규모의 지역신문이 기사 작성, 데스크 승인, 독자 사이트, 광고, 뉴스레터, 법정 표기를 한 곳에서 운영하도록, 신문사마다 자기 제호와 도메인으로 쓰는 멀티테넌트 뉴스룸 SaaS.

**근거 문서:** `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `MCP.md`, 공통은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`. 주의: 이 제품의 `SECURITY.md`는 아직 빈 양식이라 그림 7은 `05_DATA_MODEL.md` 7절, `02_ARCHITECTURE.md` 6절, `01_PRD.md` 6절을 근거로 그렸습니다(문서 불일치 1).

**표기:** 실선 = 호출·데이터 흐름, 점선 = 검증·참조·Phase 2 이후, "(제안)" = 문서가 제안이라고 한 값. 우선순위는 `01_PRD.md` 2절을 따라 P0 = MVP, P1 = Phase 2, P2 = Phase 3입니다. `NW-F-###`은 기능 ID, `NW###`은 오류 코드입니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-1 | 편집국 역할별 기능 | 유스케이스(flowchart) | 01 3절, 03 1.2절 |
| 1-2 | 독자·광고주·운영자 기능 | 유스케이스(flowchart) | 01 3절, 03 1.1·1.3절 |
| 2-1 | 웹, 호스트 분기, DB | 컴포넌트(flowchart) | 02 2·10절, 04 1절 |
| 2-2 | 워커, AI, 외부 서비스 | 컴포넌트(flowchart) | 02 3·4·7절, 04 6절 |
| 3 | 데이터 모델(핵심 14개) | 클래스 | 05 1~4절 |
| 4-1 | 기사 작성에서 게시·반영까지 | 시퀀스 | 04 2.2절·3절, 02 4절, 03 2.2절 |
| 4-2 | 보도자료 AI 초안 | 시퀀스 | 04 2.4절, 02 5절, 01 NW-F-050 |
| 4-3 | 뉴스레터 이중 동의 구독 | 시퀀스 | 04 2.1절, 03 2.4절, 05 7절 #12 |
| 4-4 | 정정·반론 청구 | 시퀀스 | 04 2.1·2.2절, 03 2.5절, 05 7절 #6 |
| 5-1 | 기사 상태 | 상태 머신 | 05 3절 |
| 5-2 | 정정 청구 상태 | 상태 머신 | 05 3절 |
| 5-3 | 개설 신청 상태 | 상태 머신 | 05 3절 |
| 5-4 | 뉴스레터 구독 상태 | 상태 머신 | 05 3절 |
| 6-1 | 독자 사이트 화면 흐름 | flowchart | 03 1.1절 |
| 6-2 | 편집국 콘솔 화면 흐름 | flowchart | 03 1.2절, 2.1~2.3절 |
| 6-3 | 개설과 운영 화면 흐름 | flowchart | 03 1.3절, 2.1절 |
| 7 | 보안 신뢰 경계 | flowchart | 05 7절, 02 6·10절, 01 6절 |
| 8-1 | API 위에 얹는 MCP 구성 | 컴포넌트(flowchart) | `MCP` 1~3절, `MCP_BASELINE` 1·7절 |
| 8-3 | 도구 위험 등급과 노출 단계 | flowchart | `MCP` 2절, `MCP_BASELINE` 2절 |

## 1. 사용자와 기능

### 1-1. 편집국 역할별 기능

**읽는 법:** 왼쪽은 `news.staff` 역할 6종, 오른쪽은 그 역할이 쓰는 기능입니다. 실선은 MVP(P0), 점선은 Phase 2(P1)입니다. 기자와 기고자의 글은 반드시 데스크 승인을 거칩니다.

```mermaid
flowchart LR
  PUB(["발행인 publisher<br/>편집인 editor"])
  DSK(["데스크 desk"])
  RPT(["기자 reporter"])
  CON(["기고자 contributor"])
  ADM(["광고담당 ad_manager"])

  PUB --> F1["매체정보 NW-F-002"]
  PUB --> F2["구성원 초대 역할<br/>NW-F-004"]
  PUB --> F3["정정 청구 결정<br/>NW-F-027"]
  DSK --> F4["승인 게시 예약<br/>NW-F-012"]
  DSK --> F5["홈 편집 NW-F-013"]
  DSK --> F6["제보함 NW-F-025"]
  DSK --> F7["컴플라이언스 대시보드<br/>NW-F-041"]
  DSK --> F14["뉴스레터 NW-F-037"]
  RPT --> F8["기사 에디터 NW-F-010"]
  RPT --> F9["보도자료 AI 초안<br/>NW-F-050"]
  RPT --> F10["인터뷰 받아쓰기<br/>NW-F-054"]
  RPT --> F11["AI 어시스턴트 NW-F-053"]
  CON --> F12["자기 초안 작성<br/>NW-F-010"]
  ADM --> F13["광고 슬롯 캠페인<br/>NW-F-030"]

  PUB -.-> P1["후원 멤버십 NW-F-035"]
  PUB -.-> P2["지원사업 리포트 NW-F-061"]
  PUB -.-> P3["해지 내보내기 NW-F-064"]
  DSK -.-> P4["댓글 모더레이션 NW-F-026"]
  ADM -.-> P5["업소 공고 증빙<br/>NW-F-033 034"]
```

### 1-2. 독자, 광고주, 운영자

**읽는 법:** 방문자는 로그인 없이 읽고 제보·정정 청구·뉴스레터 구독을 합니다. 점선은 Phase 2(P1) 이후이고, 독자 Q&A 챗봇은 Phase 3(P2)입니다.

```mermaid
flowchart LR
  V(["방문자"])
  RD(["독자 로그인"])
  BZ(["지역 업소 지자체 홍보"])
  OP(["플랫폼 운영자<br/>platform_admin"])

  V --> A1["기사 섹션 지역 열람<br/>NW-F-021"]
  V --> A2["검색 많이 본 뉴스<br/>NW-F-022"]
  V --> A3["제보 투고 NW-F-025"]
  V --> A4["정정 반론 청구<br/>NW-F-027"]
  V --> A5["뉴스레터 구독 NW-F-037"]
  RD --> A6["독자 가입 로그인<br/>NW-F-006"]
  RD -.-> B1["댓글 신고 NW-F-026"]
  RD -.-> B2["후원 멤버십 NW-F-035"]
  RD -.-> B3["경조사 신청 NW-F-024"]
  RD -.-> B4["독자 Q&A 챗봇 NW-F-056<br/>Phase 3"]
  BZ -.-> B5["업소 셀프 광고 NW-F-033"]
  BZ -.-> B6["공고 게재 증빙 NW-F-034"]
  OP --> C1["개설 신청 심사<br/>NW-F-001 062"]
  OP --> C2["신문사 정지 플랜 도메인<br/>NW-F-062"]
```

## 2. 구성요소

### 2-1. 웹, 호스트 분기, DB

**읽는 법:** 한 Next.js 앱이 Host 헤더로 독자, 편집국, 운영, 마케팅으로 갈립니다. 독자 사이트는 요청 경로에서 DB를 거의 보지 않고 ISR 캐시로 렌더하며, 편집국 쓰기는 사용자 세션으로 `news` 스키마 RPC만 부릅니다.

```mermaid
flowchart TB
  R["독자 브라우저<br/>신문사 도메인"]
  N["편집국 브라우저<br/>newsroom 호스트"]
  O["운영자 브라우저<br/>ops 호스트"]
  M["마케팅 방문자<br/>루트 도메인"]

  subgraph WEB["web Next.js Vercel 프로젝트 1개"]
    PX["proxy.ts<br/>Host 분기 헤더 재작성"]
    RG["reader 그룹<br/>ISR 독자 사이트"]
    NG["newsroom 그룹<br/>편집국 콘솔"]
    OG["ops 그룹 제안<br/>운영 콘솔"]
    MG["marketing 그룹"]
    API["Route Handler<br/>api r newsroom ops tenant"]
    AIG["AI 게이트<br/>api ai voice"]
    INT["api internal<br/>revalidate ai-token ai-settle"]
    MOD["modules M1 M8 local-life"]
  end

  subgraph SB["Supabase 단독 프로젝트 모놀리스"]
    AU["Auth"]
    RPC["news 스키마 RPC 와 RLS<br/>테이블 40개"]
    TEN["resolve_tenant<br/>tenant_themes tenant_domains"]
    JB["core jobs"]
    ST["Storage public-assets org-files"]
    CRD["credits wallets"]
  end

  R --> PX
  N --> PX
  O --> PX
  M --> PX
  PX --> RG
  PX --> NG
  PX --> OG
  PX --> MG
  RG -->|"anon 키 공개 RPC"| RPC
  RG --> TEN
  RG --> API
  NG -->|"사용자 세션"| RPC
  NG --> API
  NG --> AIG
  OG --> API
  API --> MOD
  MOD -->|"service_role 서버 한정"| RPC
  AIG -->|"선차감"| CRD
  API -->|"enqueue_job"| JB
  API --> ST
  PX -.->|"세션 확인"| AU
  INT -->|"워커 서명 호출"| RG
```

### 2-2. 워커, AI, 외부 서비스

**읽는 법:** 잡의 소유(큐, 재시도)는 TS 워커, LLM 호출은 FastAPI 그래프입니다. web과 워커에는 LLM 키가 없고, 브라우저는 Dify와 FastAPI를 직접 부르지 않습니다.

```mermaid
flowchart TB
  WEB["web 서버<br/>AI 게이트 Route Handler"]
  SB["Supabase<br/>jobs ai_usage"]

  subgraph RW["Railway"]
    WK["TS 워커<br/>큐 6개 publish newsletter<br/>ingest ai stats domain"]
    FA["FastAPI apps/api<br/>그래프 3개 RAG"]
  end

  DF["Dify 공유<br/>앱 news-assistant"]
  PG["pgvector<br/>news-archive news-policy"]

  subgraph MODEL["모델"]
    GPU["공용 GPU 서버<br/>oss-llm oss-embed oss-voice"]
    COM["상용 LLM<br/>국외 이전 동의 시"]
    EL["ElevenLabs TTS"]
  end

  subgraph EXT["외부"]
    TOSS["Toss 신문사 가맹<br/>독자 결제"]
    MAIL["메일 제공자 미정"]
    PUSH["Web Push VAPID"]
    VER["Vercel 도메인 API"]
    SBA["Supabase 관리 API"]
    TS["Cloudflare Turnstile"]
    WTH["기상청 에어코리아<br/>조건 미확인"]
  end

  WEB -->|"서명 토큰"| FA
  WEB --> DF
  DF -->|"내부 키 tools/answer"| FA
  WK -->|"claim_jobs"| SB
  WK -->|"잡 토큰"| FA
  WK -->|"revalidate"| WEB
  FA --> PG
  FA --> GPU
  FA -->|"체인에 있을 때만"| COM
  WEB --> GPU
  WK --> EL
  WK --> MAIL
  WK --> PUSH
  WK --> VER
  WK --> SBA
  WEB --> TOSS
  WEB --> TS
  WEB -.-> WTH
```

## 3. 데이터 모델

**읽는 법:** `news` 스키마 40개 중 핵심 14개입니다. 모든 테이블에 `org_id`(신문사 조직)가 있고, 하위 테이블은 `(x_id, org_id)` 복합 FK로 다른 신문사 행을 참조하지 못합니다. 사용자 INSERT·UPDATE·DELETE 권한은 어느 테이블에도 없고 쓰기는 RPC와 service_role만 합니다.

```mermaid
classDiagram
  class newspapers {
    uuid org_id
    text status
    text title
    text media_kind
    boolean comments_enabled
    timestamptz profile_completed_at
  }
  class staff {
    uuid org_id
    uuid user_id
    text role
    text status
    text byline_name
  }
  class sections {
    uuid id
    uuid org_id
    text slug
    uuid parent_id
  }
  class media_assets {
    uuid id
    text storage_path
    text alt_text
    text credit
  }
  class articles {
    uuid id
    uuid org_id
    text type
    text origin
    text status
    boolean ai_assisted
    text sponsor_label
    timestamptz embargo_until
    timestamptz published_at
  }
  class article_revisions {
    uuid article_id
    text kind
    text note
  }
  class readers {
    uuid org_id
    uuid user_id
    text nickname
    text status
    boolean marketing_opt_in
  }
  class memberships {
    uuid reader_id
    uuid tier_id
    text status
    text provider
  }
  class comments {
    uuid article_id
    uuid reader_id
    text status
    timestamptz temp_blocked_until
  }
  class ad_campaigns {
    uuid advertiser_id
    text pricing
    timestamptz starts_at
    text status
  }
  class ad_creatives {
    uuid campaign_id
    uuid slot_id
    text label
    text click_url
    text status
  }
  class newsletter_subscriptions {
    uuid list_id
    text email_hash
    text status
    boolean ad_consent
    timestamptz reconfirm_due_at
  }
  class tips {
    uuid reader_id
    text kind
    text status
    uuid assigned_to
    timestamptz retention_until
  }
  class correction_requests {
    uuid article_id
    text kind
    text status
    timestamptz notify_due_at
    timestamptz publish_due_at
  }

  newspapers "1" --> "*" staff : 편집국
  newspapers "1" --> "*" sections : 분류
  sections "1" --> "*" articles : 섹션
  media_assets "1" --> "*" articles : 대표 사진
  staff "1" --> "*" articles : 바이라인 작성자
  articles "1" --> "*" article_revisions : append-only 이력
  articles "1" --> "*" comments : 기사별 댓글
  readers "1" --> "*" comments : 작성자
  readers "1" --> "*" memberships : 신문사 Toss 가맹
  readers "0..1" --> "*" newsletter_subscriptions : 선택 연결
  readers "0..1" --> "*" tips : 선택 연결
  ad_campaigns "1" --> "*" ad_creatives : 소재
  articles "0..1" --> "*" correction_requests : 대상 기사

  note for newspapers "필수 10항목이 비면 공개 차단. anon은 공개 컬럼만 SELECT"
  note for staff "정책은 is_newsroom 하나로 판정. 조직당 publisher 1명"
  note for articles "anon은 article_is_live 만족 행의 공개 컬럼만. 본문은 read_article 로만"
  note for article_revisions "UPDATE 불가. 정정 이력 보존"
  note for readers "본인과 CHIEF 만 SELECT. 데스크 기자 광고담당은 0행"
  note for memberships "본인과 CHIEF 만. Toss 키는 core encrypted_credentials"
  note for comments "anon 권한 없음. 공개 목록은 list_comments 함수"
  note for ad_creatives "ADS 역할만. 노출은 serve_ads 함수. 라벨 4종 CHECK"
  note for newsletter_subscriptions "토큰은 해시만 저장. 해시 컬럼은 GRANT 없음"
  note for tips "데스크와 배정 기자만. 첨부는 RESTRICTIVE 정책"
  note for correction_requests "접수 시각 통지 기한은 트리거 계산 불변. 데스크 열람"
```

## 4. 핵심 시퀀스

### 4-1. 기사 작성에서 게시·반영까지 (NW-F-010, 012, 017)

**읽는 법:** 위에서 아래로 시간 순서입니다. 승인은 사람만 할 수 있고(서버·AI는 `NW006`), 예약 게시는 워커 크론 한 곳에서만 돌립니다. 게시 후에는 캐시 태그를 무효화하고 새 버전이 보이는지 확인합니다.

```mermaid
sequenceDiagram
  actor RP as 기자
  actor DK as 데스크
  participant W as 편집국 API
  participant DB as news RPC
  participant WK as TS 워커
  participant RD as 독자 사이트 ISR

  RP->>W: PATCH articles id
  W->>DB: save_article 사용자 세션
  DB-->>W: draft 저장 이력 기록
  RP->>W: POST submit
  W->>DB: submit_article
  DB->>DB: 유형 섹션 사진 출처 alt 검사
  DB-->>W: submitted
  DK->>W: POST review approve
  W->>DB: review_article
  alt 서버 또는 AI 호출
    DB-->>W: NW006
  else 사람 데스크
    DB-->>W: approved approved_by 기록 감사
  end
  DK->>W: POST schedule at
  W->>DB: schedule_article
  DB-->>W: scheduled
  loop 매분 크론
    WK->>DB: run_scheduled_publishing skip locked
    DB->>DB: assert_publishable
    alt 요건 미충족
      DB-->>WK: approved 로 되돌림 사유 기록
    else 통과
      DB-->>WK: published
    end
  end
  WK->>DB: enqueue news.post_publish
  WK->>RD: POST internal revalidate HMAC 서명
  WK->>RD: 공개 URL 요청 x-article-version 대조
  opt 속보
    WK->>WK: news.push_send enqueue
  end
  WK->>WK: news.ai_index enqueue
```

### 4-2. 보도자료 AI 초안 (NW-F-050)

**읽는 법:** 크레딧을 먼저 차감하고 잡이 돌며, 그래프는 `draft` 상태 저장까지만 하고 게시 경로가 없습니다. 실패하거나 300초를 넘으면 자동 환불되고, 게시에는 데스크의 사람 승인이 필수입니다.

```mermaid
sequenceDiagram
  actor RP as 기자
  participant W as web AI 게이트
  participant C as 코어 크레딧
  participant Q as jobs 큐
  participant WK as TS 워커
  participant F as FastAPI 그래프
  participant DB as news RPC

  RP->>W: POST api ai press-draft request_id source_text
  W->>W: 세션 역할 R 이상 또는 C 확인 zod 검증
  W->>W: 레이트 리밋
  W->>C: consume_credits news.draft 단가 멱등 키 request_id
  alt 잔액 부족
    C-->>W: 402 required balance
    W-->>RP: 잔액 안내
  else 선차감 성공
    W->>Q: enqueue news.ai_press_draft
    W-->>RP: job_id
    WK->>Q: claim_jobs
    WK->>W: POST internal ai-token X-Worker-Key
    W-->>WK: 잡 토큰 scope graph news.press_to_draft
    WK->>F: 그래프 실행
    F->>F: classify mask extract_facts draft
    F->>F: fact_check style_check compliance output
    alt 실패 또는 300초 초과
      F-->>WK: failed
      WK->>C: fail_job 자동 환불
    else 성공
      F-->>WK: 초안 블록 JSON
      WK->>DB: articles draft press_release ai_press_release ai_assisted
      WK-->>RP: article_id
    end
  end
  RP->>W: 고쳐 쓰고 제출
  Note over RP,DB: 게시는 데스크 review_article 사람 승인 필수
```

### 4-3. 뉴스레터 이중 동의 구독 (NW-F-037)

**읽는 법:** 구독 신청은 로그인 없이 가능하지만 봇 방어를 통과해야 하고, 확인 링크를 눌러야 발송 대상이 됩니다. 응답은 항상 202라서 가입된 이메일인지 알 수 없습니다.

```mermaid
sequenceDiagram
  actor V as 방문자
  participant W as web Route Handler
  participant TS as Turnstile
  participant DB as news RPC
  participant WK as 워커
  participant ML as 메일 제공자

  V->>W: POST r newsletter subscribe email list_slug consent hp elapsed_ms token
  W->>W: Origin 검사 허니팟 hp 비어야 함
  alt 허니팟 걸림
    W-->>V: 202 성공처럼 응답
  else 통과
    W->>TS: siteverify
    alt Turnstile 실패
      W-->>V: 403
    else 통과
      W->>W: 레이트 리밋 elapsed 3000ms 이상
      W->>DB: subscribe_newsletter service 호출
      DB->>DB: pending 확인 토큰 해시만 저장
      DB-->>W: 확인 토큰
      W->>ML: 확인 메일 7일 유효
      W-->>V: 202 항상
    end
  end
  V->>W: 메일 링크 확인 버튼 POST confirm token
  W->>DB: confirm_newsletter
  alt 토큰 만료 또는 불일치
    DB-->>W: NW012
  else 정상
    DB->>DB: confirmed reconfirm_due_at 2년 뒤
    DB-->>W: confirmed
  end
  Note over V,ML: 발송은 편집국 send 요청 후 월 한도와 야간 21~08시 동의 검사 뒤 news.newsletter_send 에서 500명 단위 batch
  WK->>ML: 확인 완료 동의 유효 대상만 발송 해지 토큰 포함
```

### 4-4. 정정·반론 청구 (NW-F-027)

**읽는 법:** 접수 시각과 기한은 트리거가 계산하고 바꿀 수 없습니다. 접수 후 3일 안에 수용 여부를 통지하고, 수용하면 통지 후 7일 안에 게재해야 하며, 매시간 도는 잡이 기한을 지킵니다.

```mermaid
sequenceDiagram
  actor RQ as 청구인
  participant W as web Route Handler
  participant DB as news RPC
  actor ED as 편집인
  actor DK as 데스크
  participant WK as 워커

  RQ->>W: POST r corrections kind article_id claim_text 동의 hp token
  W->>W: 봇 방어 Turnstile 허니팟 레이트 리밋
  W->>DB: submit_correction_request service 호출
  DB->>DB: received 접수 시각 notify_due_at 접수 후 3일
  DB-->>W: reference received_at notify_due_at
  W-->>RQ: 접수 번호
  WK->>DB: 매시간 news.correction_sla 기한 24시간 전 알림 초과 표시
  ED->>W: POST corrections id respond decision note
  W->>DB: respond_correction_request
  alt 거부
    DB->>DB: rejected 사유 필수 통지 기록
  else 수용
    DB->>DB: accepted publish_due_at 통지 후 7일 감사
    DK->>W: POST articles id corrections correction_request_id
    W->>DB: record_article_correction
    DB->>DB: 청구 published 원기사 정정 표시 이력 append
    W->>W: 기사 캐시 태그 무효화
  end
```

## 5. 상태 머신

### 5-1. 기사 상태 (articles.status)

**읽는 법:** 화살표 옆이 전이 주체입니다. 상태 컬럼은 직접 쓸 수 없고 DB 트리거가 허용 쌍 외 전이를 막습니다(22023). `archived`에서는 나가는 전이가 없습니다.

```mermaid
stateDiagram-v2
  [*] --> draft : 작성자 save_article
  draft --> submitted : 작성자 또는 데스크 submit
  draft --> archived : 작성자 데스크
  submitted --> approved : 데스크 사람 승인
  submitted --> draft : 데스크 반려 사유 필수
  approved --> scheduled : 데스크 예약
  approved --> published : 데스크 즉시 게시
  approved --> draft : 데스크
  scheduled --> published : 서버 크론 매분
  scheduled --> approved : 예약 취소 또는 게시 실패
  published --> unpublished : 데스크 사유 필수
  published --> archived : 데스크
  unpublished --> published : 데스크 재게시
  unpublished --> draft : 데스크
  unpublished --> archived : 데스크
  archived --> [*]
```

### 5-2. 정정 청구 상태 (correction_requests.status)

**읽는 법:** 거부와 철회, 게재 완료가 끝 상태입니다. 수용 결정은 편집인 이상(CHIEF)이, 게재 기록은 데스크가 합니다.

```mermaid
stateDiagram-v2
  [*] --> received : 서버 웹 접수 또는 데스크 수기 입력
  received --> reviewing : 편집인 검토 시작
  received --> accepted : 편집인 수용
  received --> rejected : 편집인 거부 사유 필수
  received --> withdrawn : 청구인 철회
  reviewing --> accepted : 편집인
  reviewing --> rejected : 편집인 사유 필수
  reviewing --> withdrawn : 청구인 철회
  accepted --> published : 데스크 record_article_correction
  accepted --> withdrawn : 청구인 철회
  rejected --> [*]
  withdrawn --> [*]
  published --> [*]
```

### 5-3. 개설 신청 상태 (newspaper_applications.status)

**읽는 법:** 승인하면 조직, 발행인, 구독(체험), 엔타이틀먼트(30일)가 한 번에 만들어집니다. 승인과 반려는 서버(운영자)만, 철회는 신청자만 할 수 있습니다.

```mermaid
stateDiagram-v2
  [*] --> pending : 신청자 request_newspaper
  pending --> approved : 운영자 approve_newspaper
  pending --> rejected : 운영자 reject_newspaper 사유 필수
  pending --> withdrawn : 신청자 철회
  approved --> [*]
  rejected --> [*]
  withdrawn --> [*]
```

### 5-4. 뉴스레터 구독 상태 (newsletter_subscriptions.status)

**읽는 법:** `pending`은 발송 대상이 아닙니다. `confirmed`가 된 뒤 2년이 지나면 재확인 메일을 보내고 30일 무응답이면 해지됩니다.

```mermaid
stateDiagram-v2
  [*] --> pending : 서버 subscribe_newsletter
  pending --> confirmed : 구독자 확인 토큰
  pending --> unsubscribed : 구독자 해지 토큰
  confirmed --> unsubscribed : 구독자 해지 또는 재확인 무응답
  confirmed --> bounced : 서버 메일 웹훅
  unsubscribed --> pending : 서버 재신청
  bounced --> pending : 서버 재신청
```

## 6. 화면 흐름

### 6-1. 독자 사이트

**읽는 법:** 독자 사이트(신문사 도메인)의 주요 화면 이동입니다. 실선은 MVP(P0), 점선은 Phase 2(P1)입니다. 매체정보가 미완성이면 모든 화면이 `/unavailable`로 막힙니다.

```mermaid
flowchart LR
  HOME["메인 /<br/>템플릿 A B C"]
  SEC["섹션 지역 태그<br/>/section /region /tag"]
  ART["기사 상세<br/>/article/id/slug"]
  SRCH["검색 /search"]
  MOST["많이 본 뉴스<br/>/most-read"]
  REP["기자 페이지"]
  TIP["제보 /tips"]
  COR["정정 청구 /corrections"]
  NL["뉴스레터 /newsletter"]
  NLC["확인 해지 재확인"]
  LOGIN["독자 로그인 /login"]
  ACC["내 정보 /account"]
  MEM["멤버십 /membership"]
  CMT["댓글"]
  LIFE["경조사 /life"]
  UNAV["공개 차단 /unavailable"]

  HOME --> SEC
  HOME --> SRCH
  HOME --> MOST
  SEC --> ART
  SRCH --> ART
  MOST --> ART
  ART --> REP
  ART --> TIP
  ART --> COR
  ART --> NL
  NL --> NLC
  ART --> LOGIN
  LOGIN --> ACC
  ACC --> MEM
  ART -.-> CMT
  ART -.-> MEM
  HOME -.-> LIFE
  HOME -.->|"매체정보 미완성 해지 정지"| UNAV
```

### 6-2. 편집국 콘솔

**읽는 법:** 로그인 후 대시보드에서 기사 흐름(작성, 승인, 홈 편집)과 독자·컴플라이언스 흐름으로 갈립니다. 같은 기능의 AI 화면은 보도자료함과 어시스턴트입니다.

```mermaid
flowchart LR
  LGN["편집국 로그인 /login"]
  DASH["대시보드 /dashboard"]
  ART["기사 목록 /articles"]
  EDT["기사 에디터<br/>/articles/id/edit"]
  PR["보도자료함<br/>/press-releases"]
  REV["승인 대기열 /review"]
  HE["홈 편집 /home-editor"]
  MED["미디어 /media"]
  TIPS["제보함 /tips"]
  COR["정정 청구 /corrections"]
  COMP["컴플라이언스 /compliance"]
  NLS["뉴스레터 /newsletter"]
  ADS["광고 /ads"]
  AST["AI 어시스턴트 /assistant"]
  SET["설정 /settings/*"]

  LGN --> DASH
  DASH --> ART
  DASH --> REV
  DASH --> COR
  DASH --> COMP
  ART --> EDT
  PR -->|"AI 초안 생성"| EDT
  EDT -->|"제출"| REV
  REV -->|"승인 후 게시"| HE
  EDT --> MED
  DASH --> TIPS
  DASH --> NLS
  DASH --> ADS
  DASH --> AST
  DASH --> SET
```

### 6-3. 개설과 운영

**읽는 법:** 신문사는 신청, 운영자 승인, 4단계 온보딩을 거쳐 첫 기사를 게시합니다. 운영 콘솔은 platform_admin이 아니면 404입니다.

```mermaid
flowchart LR
  MK["플랫폼 소개 /"]
  LGN["편집국 로그인"]
  NOA["/no-access"]
  APL["개설 신청 /apply"]
  PND["/pending 심사 중"]
  OPA["운영 /applications"]
  ONB["/onboarding<br/>매체정보 브랜딩<br/>섹션 첫 기사"]
  DASH["대시보드"]
  OPN["운영 /newspapers"]
  OPD["운영 /domains /jobs"]

  MK --> LGN
  LGN --> NOA
  NOA --> APL
  APL --> PND
  PND --> OPA
  OPA -->|"승인"| ONB
  OPA -->|"반려 사유 통지"| NOA
  ONB --> DASH
  OPA --> OPN
  OPN --> OPD
```

## 7. 보안 경계

**읽는 법:** 바깥에서 안쪽으로 신뢰가 커지고, 마지막 방어선은 DB입니다. `#n`은 `05_DATA_MODEL.md` 7절 위험 번호(`02_ARCHITECTURE.md` 6절 위험은 `R#n`), `§`는 `SECURITY_BASELINE.md` 장 번호입니다. 이 제품 `SECURITY.md`가 비어 있어 자산·위협 표는 아직 그림에 반영하지 못했습니다.

```mermaid
flowchart TB
  subgraph Z0["신뢰하지 않는 영역"]
    VIS["방문자 봇<br/>#10 #12 #13"]
    OTH["다른 신문사 직원<br/>#1"]
    STF["기자 기고자<br/>#3"]
  end

  subgraph Z1["입구 Vercel proxy"]
    HOST["Host 판별 x-tenant 헤더 삭제<br/>R#15 §11"]
    BOT["Turnstile 허니팟 레이트 리밋<br/>§8 §21"]
    HDR["보안 헤더 CSP<br/>§18"]
  end

  subgraph Z2["앱 서버"]
    VAL["zod 허용 목록 sanitize<br/>임의 iframe 금지 §10"]
    ORG["조직은 Host 또는 세션에서만<br/>본문 org_id 무시 §11"]
    AIG["AI 게이트 서명 토큰<br/>제보 원문 AI 입력 금지 §16"]
    VLT["신문사 Toss 키 vault<br/>§5 §19"]
  end

  subgraph Z3["DB 최종 방어선"]
    RLS["is_newsroom RLS<br/>x_id org_id 복합 FK #1"]
    LIVE["article_is_live<br/>본문 anon GRANT 제외 #2"]
    TRG["상태 전이 트리거<br/>사람 승인 AI origin 불변 #3 #9"]
    LAW["라벨 CHECK 매체정보 완성<br/>정정 기한 불변 #4 #5 #6"]
    PII["독자 본인과 CHIEF만<br/>토큰 해시 제보 RESTRICTIVE #7 #12 #13"]
    AUD["감사 로그 §9"]
  end

  subgraph Z4["AI 외부 제한 신뢰"]
    OSS["moderation stt 오픈소스 강제<br/>국외 이전은 동의 시만 §16"]
    TOSS["Toss 웹훅 서명 재조회 멱등<br/>§6"]
  end

  VIS --> HOST
  OTH --> HOST
  STF --> HOST
  HOST --> BOT
  BOT --> HDR
  HDR --> VAL
  VAL --> ORG
  ORG -->|"사용자 세션"| RLS
  ORG -->|"service_role 서버 한정"| LIVE
  RLS --> TRG
  RLS --> LAW
  RLS --> PII
  RLS --> AUD
  ORG --> AIG
  AIG --> OSS
  TOSS --> VLT
  VLT -.-> PII
```

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)가 독자 사이트가 쓰는 공개 RPC를 읽기 전용으로 호출합니다. 편집국 쓰기(작성·승인·게시), 제보, 정정 청구, 댓글, 결제는 도구가 없어 승인 흐름 그림(8-2)은 없습니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 미결정(D-M#) 또는 신문사 허용 설정이 필요한 부분입니다.

### 8-1. API 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    RD["독자 브라우저<br/>신문사 도메인"]
    ST["편집국 브라우저"]
    AG["AI 에이전트<br/>독자 비서 편집국 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    RS["독자 사이트 서버 컴포넌트<br/>anon 키 ISR"]
    NR["편집국 Route Handler<br/>requireSession news"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>익명 또는 편집국 Bearer"]
    TN["신문사 해석<br/>resolve_tenant"]
    PL["AI 접근 허용 확인<br/>ai_crawler_policy D-M1"]
    RL["레이트 리밋 IP 신문사 일일 상한"]
    TL["도구 5개 읽기 전용<br/>필드 허용 목록 출력"]
    SAN["본문 발췌 untrusted 처리<br/>프리미엄 전재 본문 제외"]
  end

  subgraph DB["DB 최종 방어선"]
    PUB["공개 RPC<br/>read_article search_articles most_read"]
    STF["편집국 RPC<br/>compliance_weekly_stats"]
    RLS["article_is_live 판정<br/>엠바고 예약 초안 0행"]
  end

  RD --> RS
  ST --> NR
  RS --> PUB
  NR -->|"사용자 세션"| STF
  AG --> TR
  TR --> TN
  TN --> PL
  PL --> RL
  RL --> TL
  TL --> SAN
  TL -->|"익명 anon"| PUB
  TL -.->|"편집국 토큰 D-M2"| STF
  PUB --> RLS
  STF --> RLS
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R0["R0 익명 읽기 1.5 신문사 허용 후"]
    T1["news_search_articles"]
    T2["news_get_article"]
    T3["news_get_most_read"]
    T4["news_get_newspaper_info"]
  end
  subgraph R2["R2 편집국 읽기 1.5"]
    T5["news_get_compliance_weekly"]
  end
  subgraph NO["만들지 않음"]
    N1["작성 승인 게시 정정 게재<br/>사람 승인 규칙"]
    N2["제보 취재원 정정 청구인<br/>독자 명단 댓글"]
    N3["AI 초안 교정 크레딧 소비"]
    N4["독자 결제 광고 업소 경조사<br/>구성원 도메인 운영"]
  end
  R0 --> R2
  R0 -.->|"제보와 정정 청구는 웹 폼 링크 안내만"| N2
  R2 -.->|"게시는 데스크가 웹에서"| N1
```

## 문서 불일치

1. **`SECURITY.md` 미작성:** 자산, 위협, 제품별 수치, 외부 서비스 표가 모두 "(작성 필요)"이고 공통 규칙 범위를 "1~21장"으로 적었는데 현재 `SECURITY_BASELINE.md`는 22장까지 있습니다. 그림 7은 05 7절, 02 6절, 01 6절을 근거로 했고 SECURITY 위협 번호(T#)는 쓰지 않았습니다.
2. **라우트 그룹 수:** `README.md` 4절은 3개(reader, newsroom, ops), `02_ARCHITECTURE.md` 1절은 4개(marketing 포함), 03 1.4절도 marketing을 둡니다. 그림 2-1은 4개로 그렸습니다.
3. **기사 URL:** `02_ARCHITECTURE.md` 2절·6절은 `news/[id]/[slug]`, `03_SCREENS_UX.md` 1.1절은 `/article/[id]/[slug]`입니다. 그림 6-1은 03장 기준입니다.
4. **광고 비컨:** `03_SCREENS_UX.md` 2.6절은 `/api/r/ad`와 일 배치 집계, `04_API.md` 2.1절과 `02_ARCHITECTURE.md` 2절은 `/api/r/ad-event`가 집계 RPC를 바로 호출합니다. 그림에는 개별 경로를 넣지 않았습니다.
5. **뉴스레터 확정 상태명:** `03_SCREENS_UX.md` 2.4절은 확정 후 `active`, `05_DATA_MODEL.md`는 `confirmed`입니다. 그림 5-4는 05장 기준입니다.
6. **편집국 경로 접두:** `03_SCREENS_UX.md` 1.2절은 모든 경로가 `/[org]` 접두 아래이고, `02_ARCHITECTURE.md` 2절 트리는 접두 없이 적었습니다. 그림 6-2는 접두를 생략했습니다.
7. **MCP 신문사 공개 정보 읽기**: `MCP.md`의 `news_get_newspaper_info`는 필요적 게재사항을 익명이 읽는 경로가 필요한데 `04_API.md` 3절의 anon 허용 RPC는 `is_public_newspaper`·`is_profile_complete`이고 공개 프로필 조회 RPC가 없습니다(독자 푸터는 서버 컴포넌트가 읽는 것으로 추정, `MCP.md` D-M4). 그림 8-1은 "공개 RPC"로 묶어 그렸습니다.
8. **MCP 기사 반환 키**: `read_article`은 jsonb를 돌려주지만 `04_API.md` 3절·`05_DATA_MODEL.md`에 키 이름이 없습니다(`locked` 외). `MCP.md`의 출력 필드는 확인 전입니다(D-M5).
9. **AI 접근 정책의 단계**: `01_PRD.md` NW-F-045(AI 크롤러 정책)는 P1(Phase 2)이고 `syndication_settings.ai_crawler_policy`는 `05_DATA_MODEL.md`에 있습니다. `MCP.md`는 이 설정이 구현되기 전에는 익명 기사 도구를 열지 않는 것으로 제안했습니다(D-M1). 그림 8-1의 "AI 접근 허용 확인"은 그 제안입니다.

## 갱신 규칙

위 근거 문서(특히 `05_DATA_MODEL.md` 상태 전이 표, `04_API.md` 엔드포인트와 RPC, `02_ARCHITECTURE.md` 잡·구성, `SECURITY.md` 작성 시 위협표)를 고치면 해당 그림도 같은 변경에서 함께 고친다.
