# DIAGRAMS: Floria (website-floria) UML 시각화

작성일 2026-10-23. 이 문서는 `website-floria`의 기획 문서를 그림으로 옮긴 것이다. 정본은 각 문서이며 그림과 문서가 다르면 문서가 우선한다. GitHub에서 Mermaid가 바로 렌더링된다. 전체 플랫폼 구조는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`와 같은 스타일로 맞췄다. 이 제품은 규모가 작아(DB 테이블 3개, 결제·크레딧·잡 없음) 그림 수를 줄였다.

**제품 한 줄 정의**: 고급 주거·갤러리·기업 공간의 식물 설치를 의뢰하려는 방문자가 작업물을 보고 문의 또는 뉴스레터 구독으로 이어지게 하는 Floria "Botanic Architecture" 브랜드 사이트와, 그 문의를 받아 처리하는 초대제 운영 콘솔. 방문자 AI 상담(문의 전환), 음성 상담, 브랜드 지식 위키, 3D 히어로가 MVP에 들어 있다.

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `MCP.md`. 공통은 `../_platform-core/SECURITY_BASELINE.md`, `CORE_SPEC.md`, `AI_ARCHITECTURE.md`.

**표기**: 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·구독, "(제안)" = 문서가 제안이라 한 값. Phase 2·3 항목은 이름에 `P2`, `P3`를 붙였다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1 | 사용자와 기능 | 유스케이스(flowchart) | 01_PRD 1장, 2장, 3장 |
| 2 | 구성요소 | 컴포넌트(flowchart) | 02_ARCHITECTURE 2절, 4절, 5절, 7절 |
| 3 | 데이터 모델 (site 3표 + 코어 AI 참조) | 클래스(classDiagram) | 05_DATA_MODEL 1~4절, 6절 |
| 4-A | 시퀀스: 문의 접수와 알림 | 시퀀스 | 03_SCREENS_UX 2.1절, 04_API 2~3절, 01_PRD SI-F-006~009 |
| 4-B | 시퀀스: 뉴스레터 이중 동의 | 시퀀스 | 03_SCREENS_UX 2.2절, 04_API 2.1절, 01_PRD SI-F-010~011 |
| 4-C | 시퀀스: AI 상담에서 문의 전환 | 시퀀스 | 03_SCREENS_UX 2.5절, 02_ARCHITECTURE 5.3절, 01_PRD SI-F-022~025 |
| 5-A | 상태: 문의 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-B | 상태: 뉴스레터 구독 | 상태 머신 | 05_DATA_MODEL 3절 |
| 6 | 화면 흐름 | flowchart | 03_SCREENS_UX 1절, 2절 |
| 7 | 보안 신뢰 경계 | flowchart | 05_DATA_MODEL 4절·7절, 01_PRD 5~6장, 02_ARCHITECTURE 6~7절 |
| 8-1 | 구성요소: API 위에 얹는 MCP 층 | 컴포넌트(flowchart) | MCP 1~3절, MCP_BASELINE 1·7절 |
| 8-3 | 도구 위험 등급과 노출 단계 | flowchart | MCP 1·2절, MCP_BASELINE 2절 |

> 이 제품의 `SECURITY.md`는 아직 템플릿 상태("작성 필요")라서 7번 그림은 `05_DATA_MODEL` 4·7장, `01_PRD` 5·6장, `02_ARCHITECTURE` 6·7장을 근거로 그렸다. 맨 끝 "문서 불일치" 참고.

---

## 1. 사용자와 기능

**읽는 법**: 사람 역할 3종(방문자, 스튜디오 운영자, 플랫폼 관리자)과 기능이다. 방문자는 로그인이 없고, 운영자는 초대받은 소수다. 기능 ID는 `SI-F-###`이며 MVP는 실선 묶음, Phase 2·3은 점선 묶음이다. Phase 구분은 01_PRD 2장 표를 그대로 따랐다.

```mermaid
flowchart LR
  VIS(["방문자<br/>갤러리 디렉터 · 개인 고객<br/>로그인 없음"])
  STAFF(["스튜디오 운영자<br/>owner admin member"])
  PADM(["플랫폼 관리자<br/>service_role 담당"])

  subgraph V1["방문자 기능 MVP"]
    F1["7섹션 브랜드 페이지<br/>컬렉션 · 프로세스 · 아카이브<br/>SI-F-001~004"]
    F6["문의 폼 접수번호<br/>SI-F-006 007"]
    F10["뉴스레터 이중 동의<br/>SI-F-010 011"]
    F22["AI 상담 채팅<br/>출처 표시 SI-F-022"]
    F25["문의 초안 전환<br/>SI-F-025"]
    F26["음성 상담 STT TTS<br/>SI-F-026"]
    F24P["지식 위키 열람 /guide<br/>SI-F-024"]
    F30["3D 히어로<br/>SI-F-030"]
  end

  subgraph S1["운영자 기능 MVP"]
    F8["문의 처리 콘솔<br/>상태 메모 SI-F-008"]
    F9["문의 알림 메일<br/>SI-F-009"]
    F27["AI 설정 · 국외 이전 동의<br/>SI-F-027"]
    F23["상담 지식 업로드 · RAG<br/>SI-F-023"]
    F24["위키 검수 게시<br/>SI-F-024"]
  end

  subgraph A1["관리자 기능 MVP"]
    F20["초대 · 로그인 · 사이트 등록<br/>SI-F-020"]
    F21["보존 기간 만료 삭제<br/>SI-F-021"]
  end

  subgraph P2["Phase 2 · 3"]
    P2A["구독자 관리 · 삭제 요청<br/>SI-F-012"]
    P2B["사이트 설정<br/>SI-F-013"]
    P2C["영문 버전 · 웨딩 페이지<br/>P2"]
    P2D["Journal MDX<br/>P3"]
    P2E["로그인 고객 상담 이력<br/>보이스 선택 P2"]
    P2F["온라인 결제<br/>미정 P3"]
  end

  VIS --> F1
  VIS --> F6
  VIS --> F10
  VIS --> F22 --> F25 -.->|"문의 폼으로 이동"| F6
  F22 --> F26
  VIS --> F24P
  VIS --> F30
  PADM --> F20
  PADM -.-> F21
  STAFF --> F8
  F6 -.-> F9 -.-> F8
  STAFF --> F27
  STAFF --> F23 --> F24
  STAFF -.-> P2A
  STAFF -.-> P2B
  VIS -.-> P2C
  VIS -.-> P2D
  VIS -.-> P2E
  VIS -.-> P2F
```

---

## 2. 구성요소

**읽는 법**: 공개 쓰기(문의, 구독, 상담)는 모두 Next.js Route Handler를 거쳐 DB의 SECURITY DEFINER RPC로 들어간다. 운영 콘솔은 로그인 세션과 RLS로 읽고 RPC로 쓴다. 잡 시스템(`core.jobs`)은 쓰지 않고, 알림 워커 하나가 1분 폴링한다. 크레딧이 없으므로 AI 비용은 운영자 조직이 낸다. 이 제품은 모듈러 통합 DB가 1차, 모놀리스가 대안이다(README 5장).

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    PUB["방문자 화면<br/>SSG 페이지 · 상담 위젯"]
    CON["운영 콘솔 /admin<br/>로그인 세션"]
  end

  subgraph WEB["Next.js (Vercel)"]
    FORM["/api/inquiries<br/>/api/newsletter/*"]
    AIG["/api/ai/* · /api/voice/*<br/>방문자 쿠키 검증"]
    SA["서버 액션<br/>콘솔 RPC 호출"]
    INT["/api/internal/wiki-lint<br/>워커 키"]
    SIGN["서명 토큰 발급<br/>EdDSA"]
  end

  WRK["알림 워커 (Railway 소형)<br/>1분 폴링 · 주 1회 lint 호출"]

  subgraph DB["Supabase 모듈러 (모놀리스 대안)"]
    SITE["site 스키마<br/>sites inquiries newsletter_subscribers"]
    CORE["core<br/>조직 · 엔타이틀먼트 · 레이트 리밋 · 감사"]
    AIC["core AI 표<br/>ai_conversations ai_messages ai_documents wiki_pages 등"]
  end

  subgraph AI["AI 계층"]
    DIFY["Dify site-chat"]
    FA["FastAPI<br/>그래프 site.consult · RAG · 위키"]
    OSS["오픈소스 LLM · 음성"]
    COM["상용 LLM · ElevenLabs<br/>국외 이전 동의 시만"]
  end

  EXT[("메일 사업자 미정<br/>Turnstile 제안")]
  LINK["연계 사이트<br/>allowed_origins CORS"]

  PUB --> FORM
  PUB --> AIG
  CON --> SA
  FORM -->|"submit_inquiry 등 RPC"| SITE
  SA -->|"세션 + RLS + RPC"| SITE
  AIG --> AIC
  AIG --> SIGN --> FA
  AIG --> DIFY --> FA
  FA --> AIC
  FA --> OSS
  FA -.-> COM
  WRK -->|"notified_at is null 조회"| SITE
  WRK --> EXT
  WRK --> INT --> FA
  FORM --> EXT
  SITE --- CORE
  LINK -.->|"POST /api/inquiries"| FORM
```

---

## 3. 데이터 모델

**읽는 법**: 제품 전용 테이블은 3개뿐이다(콘텐츠는 저장소 `src/content/*.ts`가 정본이라 CMS 표가 없고, AI 표도 만들지 않고 코어 `core.ai_*`, `wiki_*`, `voice_*`를 참조한다). 그래서 아래 그림은 `site` 3표와 AI가 쓰는 코어 표를 함께 그렸다. 코어 표는 이름만 적었고 컬럼은 05_DATA_MODEL 6절에 있는 용도만 note로 달았다. 모든 테이블 RLS ON, 쓰기 정책 없음(RPC와 service_role만).

```mermaid
classDiagram
  class sites {
    id
    org_id
    slug 유일
    name
    brand_key
    allowed_origins
    notify_email
    accepts_inquiries
    accepts_newsletter
    accepts_ai_chat 기본 꺼짐
    accepts_voice 기본 꺼짐
    inquiry_retention_days
    privacy_policy_version
    status active paused
  }
  class inquiries {
    id 접수번호 앞 8자리
    org_id
    site_id
    kind 7종
    name
    email
    message 10~2000자
    consent_version
    status new read replied archived spam
    spam_score
    staff_note
    notified_at
  }
  class newsletter_subscribers {
    id
    org_id
    site_id
    email 해지 후 NULL 가능
    email_hash sha256
    status pending confirmed unsubscribed
    consent_version
    confirm_sent_count
  }
  class organizations {
    core 참조
  }
  class ai_conversations {
    core 참조
    visitor_key 해시
    app_id site
  }
  class ai_messages {
    core 참조
    마스킹본 30일 후 삭제
  }
  class ai_documents {
    core 참조
    지식 색인 상태
  }
  class wiki_pages {
    core 참조
    draft published
  }
  class voice_sessions {
    core 참조
    store_audio false
  }

  organizations "1" --> "*" sites : org_id
  sites "1" --> "*" inquiries : site_id
  sites "1" --> "*" newsletter_subscribers : site_id
  organizations "1" --> "*" ai_conversations : org_id
  ai_conversations "1" --> "*" ai_messages
  ai_conversations "1" --> "*" voice_sessions
  organizations "1" --> "*" ai_documents : 사이트 조직 지식
  organizations "1" --> "*" wiki_pages : 브랜드 위키
  ai_conversations ..> inquiries : 서버가 잇지 않음 source_path만

  note for sites "SELECT 멤버+엔타이틀먼트<br/>쓰기 update_site_settings update_ai_settings RPC<br/>등록은 provision_site service_role"
  note for inquiries "SELECT owner admin member만 viewer 제외<br/>접수는 submit_inquiry 공개 RPC<br/>IP와 UA는 저장하지 않음"
  note for newsletter_subscribers "SELECT inquiries와 동일<br/>쓰기 service_role RPC만<br/>삭제 요청 시 이메일만 지우고 해시 유지"
  note for ai_conversations "방문자 대화는 user_id null<br/>RLS로 어떤 사용자도 못 읽음<br/>쿠키와 visitor_key 일치 매 턴 검사"
  note for ai_documents "방문자 anon 접근 권한 없음<br/>match_ai_chunks가 org app 필터 강제"
```

---

## 4. 핵심 시퀀스

### 그림 4-A. 문의 접수와 알림 (SI-F-006~009)

**읽는 법**: 방문자 폼은 Route Handler에서 1차(크기, Origin, Turnstile, IP 레이트 리밋)를 거르고, DB RPC 안에서 2차(접수 스위치, 동의 문구 버전, 레이트 리밋, 허니팟, 스팸 점수)를 거른다. 점수 60 이상은 `spam`으로 격리한다. 알림 메일에는 개인정보 전문 없이 콘솔 링크만 넣는다.

```mermaid
sequenceDiagram
  autonumber
  actor V as 방문자
  participant N as Next.js /api/inquiries
  participant D as DB site.submit_inquiry
  participant W as 알림 워커
  participant M as 메일
  actor S as 운영자

  V->>N: 종류, 이름, 이메일, 내용, 동의, 허니팟, 작성 시간
  N->>N: 본문 16KB 이하, Origin allowed_origins, Turnstile, IP당 5회/시간
  N->>D: submit_inquiry (anon 허용 공개 RPC)
  Note over D: 사이트 active, accepts_inquiries 확인 SI002<br/>동의 문구 버전 불일치 SI004<br/>이메일당 3/시간 6/일, 사이트 100/시간 500/일<br/>허니팟, 3초 미만 작성, 링크 3개 이상 점수 가산
  alt 점수 60 이상
    D-->>N: status spam 으로 격리 저장
  else 정상
    D-->>N: reference 접수번호 8자리, status new
  end
  alt 한도 초과
    N-->>V: 429 몇 분 뒤 다시
  else 접수
    N-->>V: 접수번호 표시
  end
  loop 1분 주기
    W->>D: status new 이고 notified_at is null 인 문의 조회 limit 50
    W->>M: 알림 메일 (콘솔 링크만)
    W->>D: notified_at 갱신
  end
  M-->>S: 새 문의 알림
  S->>D: set_inquiry_status read, replied (콘솔 RPC)
```

### 그림 4-B. 뉴스레터 이중 동의 (SI-F-010, 011)

**읽는 법**: 구독 요청의 응답은 항상 같은 `202`라서 가입 여부를 알 수 없다(계정 열거 방지). 확인 링크의 GET은 토큰 검증만 하고 버튼을 보이며, 상태는 버튼 POST에서만 바뀐다(메일 보안 스캐너 선열람 대응). 토큰은 HMAC 서명이라 DB에 저장하지 않는다.

```mermaid
sequenceDiagram
  autonumber
  actor V as 방문자
  participant N as Next.js /api/newsletter
  participant D as DB service_role RPC
  participant M as 메일

  V->>N: POST subscribe 이메일, 동의, 허니팟
  N->>D: subscribe_newsletter (service_role)
  D-->>N: send_confirmation 여부
  N-->>V: 항상 202 확인 메일을 보냈습니다
  opt send_confirmation 이 true
    N->>M: 확인 메일 HMAC 토큰 typ c 48시간 제안
  end
  V->>N: GET /newsletter/confirm 링크 열기
  N-->>V: 토큰 검증만 하고 구독 확인 버튼 표시 (상태 불변)
  V->>N: POST /api/newsletter/confirm token
  alt 토큰 만료
    N-->>V: 410 다시 신청
  else 정상
    N->>D: confirm_newsletter (pending 만 confirmed)
    D-->>N: ok, changed
    N-->>V: 구독 확인 완료 (두 번 눌러도 멱등)
  end
  V->>N: 해지 링크 또는 List-Unsubscribe 원클릭 POST
  N->>D: unsubscribe_newsletter
  N-->>V: 같은 완료 문구 (없는 구독이어도 동일)
```

### 그림 4-C. AI 상담에서 문의 전환 (SI-F-022~025, 028)

**읽는 법**: 크레딧이 없어서 선차감 대신 레이트 리밋 5종과 사이트 일일 상한으로 비용을 통제한다. 상담은 문의 초안(`inquiry_hint`)만 만들고 DB에 쓰지 않으며, 제출은 방문자가 `/contact` 폼에서 직접 한다. 답변은 근거가 있을 때만 생성하고 `compliance`를 통과해야 한다.

```mermaid
sequenceDiagram
  autonumber
  actor V as 방문자
  participant B as 브라우저 위젯
  participant N as Next.js /api/ai
  participant Df as Dify site-chat
  participant F as FastAPI site.consult
  participant D as DB core + site

  V->>B: 상담 버튼
  B->>N: GET /api/ai/config
  N-->>B: chat voice 스위치와 고지문 버전
  V->>B: 고지 확인 후 상담 시작
  B->>N: POST /api/ai/conversations notice_version, Turnstile
  N->>D: 레이트 리밋 2종 후 ai_conversations 생성 visitor_key
  N-->>B: conversation_id + 서명 방문자 쿠키
  V->>B: 질문 300자 이내
  B->>N: POST /api/ai/chat
  N->>N: 쿠키와 visitor_key 일치, 레이트 리밋 5종, 사이트 일일 상한
  N->>D: 마스킹본을 ai_messages 에 저장
  N->>Df: dify_user + platform_conversation_id
  Df->>F: HTTP 노드 /tools/answer 내부 키
  F->>F: question 인젝션 차단 주제 분류
  F->>D: retrieve match_ai_chunks 사이트 조직 published 위키
  alt 근거 없음
    F-->>N: no_source 응답 생성하지 않음
  else 근거 있음
    F->>F: answer 후 inquiry 힌트 후 compliance
    opt compliance 위반
      F->>F: answer 1회 재작성 후 재검사, 또 위반이면 정형 안전 응답
    end
  end
  F->>D: assistant 메시지와 ai_usage 기록 (settled_at 즉시)
  N-->>B: SSE message, citations, inquiry_hint, done
  opt Dify 5xx 또는 10초 무응답
    N->>F: /tools/answer-direct 서명 토큰 + 운영 알림
  end
  V->>B: 이 내용으로 문의하기
  B->>B: inquiry_hint 를 sessionStorage 에 두고 /contact?from=consult 이동
  Note over B,N: 이후는 그림 4-A와 같다 source_path 는 /consult
```

---

## 5. 상태 머신

전이는 `inquiry_status_transition`, `newsletter_status_transition` 트리거가 service_role 쓰기에도 강제한다(위반 `22023`).

### 그림 5-A. 문의 `inquiries.status`

**읽는 법**: 전이는 소속 조직의 멤버(`set_inquiry_status`) 또는 service_role이 일으키고 감사 로그가 남는다. `spam`은 오탐 복구 때만 `new`로 돌아갈 수 있다. 처음 상태 `new` 또는 `spam`은 접수 RPC가 점수로 정한다.

```mermaid
stateDiagram-v2
  [*] --> new : submit_inquiry 점수 60 미만
  [*] --> spam : submit_inquiry 점수 60 이상
  new --> read : 멤버 set_inquiry_status
  new --> replied : 멤버
  new --> spam : 멤버
  new --> archived : 멤버
  read --> new : 멤버
  read --> replied : 멤버
  read --> spam : 멤버
  read --> archived : 멤버
  replied --> archived : 멤버
  archived --> read : 멤버 재열람
  spam --> new : 멤버 오탐 복구
```

### 그림 5-B. 뉴스레터 `newsletter_subscribers.status`

**읽는 법**: 모든 전이는 service_role RPC가 일으킨다. 해지 뒤 다시 구독하면 새 동의로 `pending`부터 시작한다. 해지 30일 뒤나 삭제 요청(`erase_subscriber`) 때 이메일 원문만 지우고 `email_hash`와 해지 상태는 남긴다.

```mermaid
stateDiagram-v2
  [*] --> pending : subscribe_newsletter 새 동의
  pending --> confirmed : confirm_newsletter 확인 버튼
  pending --> unsubscribed : unsubscribe_newsletter
  confirmed --> unsubscribed : unsubscribe_newsletter 또는 erase_subscriber
  unsubscribed --> pending : subscribe_newsletter 새 동의
```

---

## 6. 화면 흐름

**읽는 법**: 위쪽은 로그인 없는 방문자 화면, 아래쪽은 운영자 콘솔이다. 점선은 메일 링크로 들어오는 경로나 Phase 2·3 화면이다. 경로는 03_SCREENS_UX 1절 표기이다.

```mermaid
flowchart TB
  subgraph PUBS["방문자 로그인 없음"]
    HOME["/ 브랜드 단일 페이지<br/>7섹션 · 3D 히어로"]
    CONTACT["/contact<br/>문의 폼"]
    WIDGET["상담 위젯<br/>모든 페이지 우하단"]
    GUIDE["/guide · /guide/slug<br/>지식 위키"]
    PRIV["/privacy"]
    NCONF["/newsletter/confirm"]
    NUNS["/newsletter/unsubscribe"]
    NF["404 헤더 푸터 유지"]
  end

  subgraph ADM["운영자 콘솔 초대제"]
    LOGIN["/admin/login<br/>A Mock B Google 이메일"]
    ACC["/admin/accept-invite<br/>/admin/reset-password"]
    NOA["/admin/no-access"]
    INQ["/admin/inquiries<br/>목록 필터"]
    INQD["/admin/inquiries/id<br/>상태 메모 삭제"]
    SUB["/admin/subscribers"]
    SET["/admin/settings"]
    AIS["/admin/ai<br/>스위치 · 국외 이전 · 사용량"]
    KNOW["/admin/knowledge<br/>지식 색인"]
    WIKI["/admin/wiki<br/>검수 · lint"]
  end

  P2["/weddings P2 · /journal P3"]

  HOME --> CONTACT
  HOME --> WIDGET
  WIDGET -->|"이 내용으로 문의하기"| CONTACT
  HOME --> GUIDE
  HOME --> PRIV
  CONTACT --> PRIV
  HOME -.-> NF
  NCONF -.->|"메일 링크"| HOME
  NUNS -.->|"메일 링크"| HOME
  HOME -.-> P2
  ACC -.->|"초대 메일"| LOGIN
  LOGIN -->|"권한 있음"| INQ
  LOGIN -->|"엔타이틀먼트 없음"| NOA
  INQ --> INQD
  INQ --> SUB
  INQ --> SET
  INQ --> AIS
  AIS --> KNOW --> WIKI
  WIKI -.->|"게시"| GUIDE
```

---

## 7. 보안 신뢰 경계

**읽는 법**: 이 제품에서 공개 쓰기 경로는 DB의 `submit_inquiry`와 AI 상담뿐이고, 나머지 쓰기는 service_role RPC나 운영자 RPC다. 방문자는 DB 테이블 권한이 전혀 없다. `§`는 `../_platform-core/SECURITY_BASELINE.md`의 장 번호이다. 이 제품의 `SECURITY.md`가 템플릿 상태라 자산·위협은 05_DATA_MODEL 7장, 01_PRD 5·6장, 02_ARCHITECTURE 6·7장에서 가져왔다.

```mermaid
flowchart TB
  subgraph Z0["구역 0. 인터넷 (신뢰 없음)"]
    BOT["스팸 봇 · 비용 남용 · 프롬프트 인젝션"]
    VIS["방문자 브라우저<br/>방문자 쿠키 __Host-site_vid"]
    STAFF["운영자 브라우저<br/>Supabase 세션"]
  end

  subgraph Z1["구역 1. Next.js 앱"]
    EDGE["보안 헤더 · 세션 쿠키 §18<br/>Turnstile · IP 레이트 리밋 §8 §21"]
    VAL["입력 검증 zod · Origin 허용 목록 §10<br/>CORS 별표 금지"]
    MASK["상담 입력 마스킹<br/>주민번호 전화 이메일 계좌"]
    TOK["HMAC 서명 토큰<br/>SITE_TOKEN_HMAC_KEY"]
  end

  subgraph Z2["구역 2. DB (RLS + 이중 잠금)"]
    PUBRPC["공개 RPC submit_inquiry<br/>DB 레이트 리밋 · 허니팟 · 점수"]
    SVRRPC["service_role 전용 RPC<br/>구독 확인 해지 사이트 등록 퍼지 §4"]
    RLS["RLS 멤버+엔타이틀먼트<br/>viewer 제외 · guard_privileged_write §15"]
    PURGE["purge_expired<br/>보존 만료 삭제 §12"]
  end

  subgraph Z3["구역 3. AI 계층"]
    FAS["FastAPI · Dify<br/>서명 토큰 · 내부 키 §16"]
    ROUTE["resolve_ai_route<br/>동의 없으면 상용 제외"]
    CMP["compliance<br/>가짜 후기 연락처 가격 약속 금지"]
    ORG["match_ai_chunks<br/>org app 필터 강제"]
  end

  BOT -.-> EDGE
  VIS --> EDGE --> VAL
  VAL --> PUBRPC
  VAL --> MASK --> FAS
  VAL --> TOK --> SVRRPC
  STAFF -->|"anon 키 + 세션"| RLS
  STAFF --> SVRRPC
  FAS --> ROUTE
  FAS --> ORG
  FAS --> CMP
  PURGE --- RLS
```

**위협과 대응 요약** (문서에 있는 것만)

| 위협 | 대응 | 근거 |
|---|---|---|
| 공개 쓰기 경로의 홍수·스팸 | 앞단 Turnstile+IP 제한, DB 내 레이트 리밋 4종, 허니팟, 작성 시간, 점수 60 이상 격리 | 05_DATA_MODEL 7장, SI-F-007 |
| 익명의 문의 열람·변조 | anon 테이블 권한 없음, 쓰기 정책 없음, `guard_privileged_write` | 05_DATA_MODEL 4·7장 |
| 구독 계정 열거, 스캐너 선열람 확정 | 항상 같은 202 응답, GET 상태 불변·버튼 POST로 확정, 토큰은 HMAC | 04_API 2절, 05_DATA_MODEL 7장 |
| 타 조직 문의 열람, 개인정보 노출 | 멤버십+엔타이틀먼트 정책, viewer 제외, IP와 UA 비저장 | 05_DATA_MODEL 2.2·4절 |
| 동의 문구 변경 후 구버전 폼 제출 | `privacy_policy_version` 불일치 시 SI004 | 05_DATA_MODEL 7장 |
| 개인정보 장기 보존 | `purge_expired`(문의 365일, spam 30일, 미확인 구독 7일 등 제안) | SI-F-021 |
| 방문자 대화 탈취(대화 id 추측) | 서명 쿠키 해시 `visitor_key` 매 턴 일치, 방문자 대화는 RLS로 누구도 못 읽음 | 05_DATA_MODEL 7장 |
| AI 비용 남용 | Turnstile, 레이트 리밋 5종, 사이트 일일 상한, 입력·턴·토큰 상한, 스위치 기본 꺼짐 | 01_PRD 5장, SI-F-028 |
| 프롬프트 인젝션·허위 정보 | 검색 결과를 자료로만 전달, `compliance`, 연락처는 `business.ts` 값만 | 05_DATA_MODEL 7장 |
| 타 조직 지식 접근, 국외 이전 우회 | `match_ai_chunks` org·app 필터, 동의 없는 조직의 상용 체인 제거 | 05_DATA_MODEL 7장 |

---

## 8. 에이전트 접근 층 (MCP)

**읽는 법**: 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)는 운영자 콘솔의 집계 읽기 2개만 사용자 세션과 RLS 뒤에서 읽는다. 방문자 쓰기(문의, 뉴스레터)와 방문자 AI 상담은 에이전트에 연결하지 않는다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`이다. 점선은 Phase 1.5 이후 또는 미결정(D-M#)이다. 쓰기·준비 도구가 없어 시퀀스(8-2)는 그리지 않았다.

### 8-1. 구성요소: API 위에 얹는 MCP 층

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    VIS["방문자 브라우저"]
    OPS["운영자 브라우저"]
    AG["운영자의 AI 에이전트"]
  end

  subgraph WEB["기존 웹 경로"]
    PUB["공개 Route Handler<br/>문의 뉴스레터 AI 상담<br/>Turnstile 허니팟 한도"]
    CON["콘솔 서버 액션<br/>requireSession site"]
  end

  subgraph MCPL["새 MCP 층 Phase 1.5 후보"]
    TR["Streamable HTTP<br/>Bearer만"]
    RL["사용자 레이트 리밋"]
    TL["도구 2개 집계 읽기<br/>개인정보 필드 제외"]
  end

  subgraph DB["DB 최종 방어선"]
    RPC["site submit_inquiry 등 RPC<br/>service_role 한 줄기"]
    TB["site inquiries 건수<br/>core ai_usage 집계"]
    RLS["RLS 소유 조직 멤버"]
  end

  VIS --> PUB
  PUB --> RPC
  OPS --> CON
  CON --> TB
  AG -.-> TR
  TR --> RL
  RL --> TL
  TL -.->|"사용자 토큰 D-M2<br/>집계 방식 D-M4"| TB
  TB --> RLS
  AG -.->|"연결 안 함"| PUB
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R2["R2 운영자 집계 읽기 1.5 후보"]
    T1["floria_get_ai_usage"]
    T2["floria_get_inquiry_counts"]
  end
  subgraph R0["R0 공개 읽기 보류 D-M1"]
    T3["floria_get_guide_page"]
  end
  subgraph NO["만들지 않음"]
    N1["문의 제출 뉴스레터 구독 확인 해지"]
    N2["문의 목록 본문 연락처 미답변 질문"]
    N3["설정 변경 AI 스위치 국외 이전 동의"]
    N4["방문자 AI 상담 재호출"]
  end
  R2 --> R0
  R2 -.->|"사람이 웹에서만"| N1
```

## 문서 불일치

1. **`SECURITY.md` 미작성**: 자산, 위협, 공통 규칙 제품별 수치, 외부 서비스 이전 표가 모두 "(작성 필요)"다. 그림 7과 위 표는 다른 문서에서 가져왔으므로 SECURITY.md가 채워지면 다시 맞춘다.
2. **구독자 관리와 사이트 설정의 단계**: `01_PRD` 2장은 구독자 관리와 사이트 설정(알림 이메일, 접수 중지, 동의 버전)을 Phase 2로 두는데 3장의 SI-F-012, SI-F-013은 단계 표기가 없고 `03_SCREENS_UX` 1절은 `/admin/subscribers`, `/admin/settings`를 P1로 둔다. 그림 1은 01_PRD 2장을 따랐다.
3. **코어 점검 결과 미반영**: `05_DATA_MODEL` 6절은 모듈러 코어에서 명시적 `revoke`가 없는 함수에 PUBLIC EXECUTE가 남는다는 점검 결과를 적고 코어는 고치지 않았다고 한다. 그림 7의 "service_role 전용 RPC"는 이 제품 함수가 `is_service_caller`로 2차 방어한다는 전제로 그렸다.
4. **MCP 작성 중 발견, 읽기 경로 부재**: `04_API.md`에는 문의 건수를 집계하는 RPC·Route Handler가 없고(콘솔은 컬럼 명시 select), 공개 `/guide` 위키는 service_role 서버 컴포넌트가 읽는데 anon은 `core.wiki_*` 권한이 없다. 그래서 `MCP.md`의 `floria_get_inquiry_counts`와 `floria_get_guide_page`는 새 읽기 경로가 필요하다(D-M1, D-M4). 그림 8-1은 집계를 사용자 세션 RLS로 읽는 것으로, 공개 읽기 도구는 그리지 않았다.
5. **MCP 작성 중 발견, `submit_inquiry`의 anon 허용**: `04_API.md` 3절은 `site.submit_inquiry`를 anon에도 열어 두고(방어 2선) 브라우저의 직접 RPC 호출은 설계에서 제외한다고 한다. 에이전트가 anon 키로 이 RPC를 직접 부르면 Turnstile·허니팟 검사를 우회하므로 `MCP.md`는 이 RPC를 호출하는 도구를 만들지 않는다. 필요하면 anon 직접 호출을 막는 방안은 별도 결정이다.


## 갱신 규칙

`01_PRD`, `02_ARCHITECTURE`, `03_SCREENS_UX`, `04_API`, `05_DATA_MODEL`, `SECURITY.md` 중 하나를 고치면 해당 그림(위 표의 근거 절)도 같은 변경에서 함께 고친다. 수정 뒤에는 Mermaid 검증을 다시 돌린다.
