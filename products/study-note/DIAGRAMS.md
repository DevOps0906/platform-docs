# Study Note (study-note) UML 다이어그램

작성일 2026-10-23. 제품 한 줄 정의: 수업이나 회의 원문을 붙여넣으면 서버가 AI 모델 2개로 병렬 정리한 뒤 통합 모델이 하나의 "학습 일지"로 합쳐 주고 TXT와 보관함에 남기며, 노트·교재를 과목별로 색인(RAG)해 개념 위키·퀴즈·Q&A 채팅·강의 녹음 노트 생성까지 제공하는 학습 노트 정리 서비스입니다(`README.md` 1절).

근거 문서: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`, `MCP.md`, 공통 맥락은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. 어긋난 곳은 파일 끝 "문서 불일치"에 적었습니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid).

표기: **실선 화살표** = 호출·데이터 흐름, **점선** = 검증·참조·구독, "(제안)" = 문서가 제안값이라고 밝힌 것. 기능 ID(NT-F-###)는 `01_PRD.md` 3절의 ID입니다.

`SECURITY.md`는 아직 템플릿 상태("작성 필요")라서, 7절 보안 그림은 `01_PRD` 6장, `02` 6절, `04` 1절, `05` 7절에 흩어진 보안 설계를 모은 것입니다. `06_AGENT_PLAN.md`와 `07_SOURCE_MIGRATION.md`는 작업 관리 문서라 그림에서 뺐습니다.

| 번호 | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-1 | 사용자와 기능: 일지 정리 | 유스케이스 관점 flowchart | `01_PRD` 2절, 3절 |
| 1-2 | 사용자와 기능: AI 학습 | 유스케이스 관점 flowchart | `01_PRD` 2절, 3절 |
| 1-3 | 운영자, 로그인 단계, Phase 구분 | 유스케이스 관점 flowchart | `01_PRD` 2절, 8.1절 |
| 2-1 | 구성요소: 웹·워커·AI·외부 서비스 | 컴포넌트 | `02` 2절, 4절, 7절 |
| 2-2 | 구성요소: AI 계층 상세 | 컴포넌트 | `02` 4.1절, 5.2절, `04` 6.1절, 6.2절 |
| 3-1 | 데이터 모델 | 클래스 | `05` 1절, 2절, 4절, 6절 |
| 3-2 | AI 기능의 데이터가 놓이는 곳 | flowchart | `05` 1절, 6절 |
| 4-1 | 일지 정리 실행 (NT-F-003, 006, 017) | 시퀀스 | `04` 2절, 3절, `02` 4절 |
| 4-2 | 노트 정리 그래프 (NT-F-020, 021, 028) | 시퀀스 | `02` 4.1절, `04` 2.1절 |
| 4-3 | 강의 녹음에서 노트 생성 (NT-F-026) | 시퀀스 | `04` 2.1절, `03` 2.6절 |
| 4-4 | AI 채팅 한 턴 (NT-F-024, 028) | 시퀀스 | `04` 2.1절, 6.2절 |
| 5-1 | 일지 상태 `entries.status` | 상태 머신 | `05` 3.1절 |
| 5-2 | 실행 상태 `runs.status` | 상태 머신 | `05` 3.2절 |
| 5-3 | 카드 상태 `run_steps.status` | 상태 머신 | `05` 3.3절 |
| 5-4 | 문서 색인 상태 `ai_documents.status` | 상태 머신 | `01_PRD` NT-F-020, 031 |
| 6-1 | 화면 흐름: 공개·가입·온보딩 | flowchart | `03` 1절, 2.1절, 7절 |
| 6-2 | 화면 흐름: 앱 셸 | flowchart | `03` 1절, 2절, 8절 |
| 7-1 | 보안 경계 | flowchart (신뢰 경계) | `01_PRD` 6장, `02` 6절, `05` 7절 |
| 8-1 | API 위에 얹는 MCP 구성 | 컴포넌트(flowchart) | `MCP` 1~3절, `MCP_BASELINE` 1·7절 |
| 8-2 | 정리 준비와 사람 확정 | 시퀀스 | `MCP` 2·6절, `04` 2.1절 |
| 8-3 | 도구 위험 등급과 노출 단계 | flowchart | `MCP` 2절, `MCP_BASELINE` 2절 |

## 1. 사용자와 기능

### 그림 1-1. 일지 정리 (원본에서 이어받은 기능)

읽는 법: 회원이 날짜와 원문을 넣고 [정리하기]를 누르면 기본 카드 2장과 통합 카드가 나오고, 카드별 재요청·취소·TXT·보관함으로 이어집니다. 점선 상자의 비용 보호는 사용자가 누르는 기능이 아니라 서버가 거는 제한입니다(NT-F-014). 모두 MVP입니다.

```mermaid
flowchart LR
  M(["회원<br/>owner, admin, member"])

  M --> L["가입 로그인<br/>NT-F-001"]
  M --> I["일지 입력<br/>날짜 + 원문 Free 5000자<br/>NT-F-002"]
  M --> MD["모델 3종 선택<br/>등급별 화이트리스트<br/>NT-F-009"]
  I --> CR["예상 크레딧 표시<br/>NT-F-011"]
  I --> RUN["정리 실행<br/>2모델 병렬 + 통합<br/>NT-F-003"]
  MD --> RUN
  RUN --> CARD["결과 카드 3장<br/>NT-F-004"]
  RUN --> CAN["실행 취소 환불<br/>NT-F-007"]
  CARD --> RT["카드별 재요청<br/>NT-F-006"]
  CARD --> TXT["TXT 다운로드 복사<br/>NT-F-005"]
  CARD --> HIS["보관함 + 휴지통 30일<br/>NT-F-008"]
  M --> EXP["JSON 내보내기 계정 삭제<br/>NT-F-013"]
  M --> TH["테마 system light dark<br/>NT-F-010"]

  GUARD["비용 보호 NT-F-014<br/>분당 6회, 조직 동시 2건<br/>일일 상한, 이메일 인증"]
  GUARD -.-> RUN
```

### 그림 1-2. AI 학습 기능

읽는 법: 위 줄이 자료가 들어오는 길(업로드·강의 녹음), 가운데가 정리 그래프와 결과물(요약·위키·퀴즈), 아래가 그것을 활용하는 채팅·퀴즈 풀이입니다. 과목은 별도 테이블이 아니라 위키 페이지로 표현합니다(D-16, 3-2 그림). 모두 MVP입니다.

```mermaid
flowchart LR
  M(["회원"])
  V(["방문자"])

  V --> H3["랜딩 3D 히어로<br/>NT-F-029"]
  M --> OB["AI 처리 방식 동의<br/>국외 이전 선택<br/>NT-F-019"]
  M --> UP["노트 교재 업로드 색인<br/>권한 확인 필수<br/>NT-F-020"]
  M --> LEC["강의 녹음 노트 생성<br/>제3자 음성 고지<br/>NT-F-026"]
  LEC -->|"전사본을 문서로 등록"| UP
  UP --> ORG["노트 정리 그래프<br/>요약 개념 퀴즈<br/>NT-F-021"]
  ORG --> WIKI["과목별 개념 위키<br/>직접 편집 가능<br/>NT-F-022"]
  ORG --> QZ["퀴즈 풀이 채점<br/>객관식 OX 단답<br/>NT-F-023"]
  M --> CHAT["Q&A 채팅<br/>내 노트 근거 + 출처 칩<br/>NT-F-024"]
  CHAT --> VC["음성 대화<br/>STT TTS<br/>NT-F-025"]
  QZ --> QV["퀴즈 음성 문제 답<br/>NT-F-027"]
  WIKI --> LINT["위키 점검 수동<br/>크레딧 선차감"]
  M --> DEL["AI 데이터 삭제 보존<br/>NT-F-031"]
```

### 그림 1-3. 운영자, 로그인 단계, Phase 구분

읽는 법: 운영자 기능은 MVP에 없고 Phase 2의 모델 카탈로그 관리뿐입니다. 로그인은 Stage A→B→C 순서로 켜지고, 아래 두 상자는 MVP 밖 항목입니다. 구분은 `01_PRD.md` 2절 표 그대로입니다. Pro 플랜과 크레딧팩은 베타 동안 `is_active=false`입니다.

```mermaid
flowchart TB
  O(["platform_admin"])
  O --> ADM["모델 카탈로그 관리<br/>활성 등급 크레딧 편집<br/>NT-F-015, Phase 2"]

  subgraph AUTHS["로그인 단계 (확정 결정 22)"]
    SA["Stage A Mock<br/>로컬 시드 계정"]
    SB["Stage B Google + 이메일<br/>P0, 공개 베타 전"]
    SC1["Stage C1 카카오 P1"]
    SC2["Stage C2 네이버 P1"]
  end
  SA --> SB --> SC1
  SB --> SC2

  subgraph P2["Phase 2"]
    A1["결제 Pro 구독 크레딧팩<br/>Toss, NT-F-012"]
    A2["모델 카탈로그 동기화<br/>크레딧 단가 보정"]
    A3["퀴즈 응시 기록 오답 노트<br/>D-15"]
    A4["비회원 AI 체험<br/>보이스 선택 클로닝"]
    A5["위키 점검 예약 실행<br/>일지 최종본 노트 연동"]
  end

  subgraph P3["Phase 3"]
    B1["복습 플래시카드<br/>NT-F-018, D-5"]
    B2["팀 조직 공유<br/>과목 위키 공유"]
  end
```

## 2. 구성요소

### 그림 2-1. 웹·워커·AI·외부 서비스

읽는 법: 일지 정리(위 경로)는 Route Handler가 DB 함수 `start_run`을 불러 차감·실행·잡을 한 번에 만들고 TS 워커가 OpenRouter를 호출합니다. AI 기능(아래 경로)은 FastAPI가 맡습니다. 웹 앱(Vercel)에는 LLM 키가 없고, 점선은 구독 또는 Phase 2입니다.

```mermaid
flowchart TB
  subgraph CL["브라우저"]
    UI["작업실 노트 위키<br/>채팅 퀴즈 강의 녹음<br/>3D 히어로"]
  end

  subgraph WEB["apps/study-note Next.js, Vercel"]
    RH["Route Handler<br/>/api/notes, /api/ai, /api/voice<br/>requireSession notes"]
    INT["/api/internal<br/>ai-settle"]
  end

  subgraph RWY["Railway"]
    WRK["study-note-worker TS<br/>잡 notes.organize<br/>cron-ai 정산 5분"]
    API["FastAPI apps/api<br/>그래프 notes.organize<br/>tools, rag, wiki<br/>잡 소비자 notes.ai"]
  end

  subgraph SUP["Supabase"]
    NOTES["notes 스키마<br/>테이블 7개"]
    CORE["core<br/>크레딧 잡 감사<br/>ai_* wiki_* voice_*"]
    STO["Storage<br/>org-files, voice-audio"]
    RT["Realtime<br/>runs, run_steps"]
  end

  OR["OpenRouter<br/>모델 13종 화이트리스트"]
  DIFY["Dify 공용<br/>notes-chat"]
  GPU["공용 GPU 서버<br/>oss-llm oss-embed oss-voice"]
  LLMC["상용 LLM"]
  EL["ElevenLabs"]
  TOSS["Toss Payments<br/>Phase 2"]

  UI --> RH
  UI -->|"서명 업로드 URL"| STO
  RH -->|"사용자 세션 + RLS"| NOTES
  RH -->|"service_role: start_run"| NOTES
  RH -->|"consume_credits, 대화 매핑"| CORE
  RH --> DIFY
  RH -->|"EdDSA 서명 토큰"| API
  RH --> GPU
  RH --> EL
  DIFY -->|"내부 키 + 대화 id"| API
  WRK -->|"claim, heartbeat, complete"| CORE
  WRK -->|"record_step, finish_run"| NOTES
  WRK --> OR
  WRK -->|"워커 키"| INT
  API --> CORE
  API --> GPU
  API --> LLMC
  RT -.->|"RLS 하에서 구독"| UI
  RH -.->|"confirm"| TOSS
```

### 그림 2-2. AI 계층 상세

읽는 법: 왼쪽 Next.js 엔드포인트가 오른쪽 FastAPI 도구·그래프를 부릅니다. 그래프 `notes.organize`는 5개 노드이고 `compliance`에서 걸린 항목만 해당 노드로 돌아가 1회 다시 씁니다(점선). 채팅은 그래프가 아니라 `/tools/answer` 도구 경로입니다. 이 제품은 `/dify/retrieval`을 쓰지 않습니다(`04` 6.1절).

```mermaid
flowchart LR
  subgraph NX["Next.js"]
    DOC["/api/notes/documents<br/>업로드 URL 등록"]
    ORG["/api/ai/organize<br/>선차감 + 토큰"]
    CH["/api/ai/chat"]
    QZ["/api/ai/quizzes/*<br/>정답 제거 후 반환"]
    LEC["/api/voice/lectures/*<br/>강의 조각 STT"]
  end

  DIFY["Dify notes-chat<br/>질문 분류 dify.aux"]

  subgraph FA["FastAPI apps/api"]
    ING["/rag/ingest<br/>컬렉션 rag:s-sid"]
    GR["/graphs/notes.organize/runs"]
    CON["jobs/consumer.py<br/>큐 notes.ai"]
    T1["/tools/answer<br/>모드 notes"]
    T2["/tools/answer-direct<br/>Dify 장애 시"]
    RO["라우터 resolve_ai_route"]
  end

  subgraph GRAPH["그래프 notes.organize"]
    G1["upload"] --> G2["summary"] --> G3["link"] --> G4["quiz"] --> G5["compliance"]
    G5 -.->|"걸린 항목 1회"| G2
  end

  subgraph DATA["core 테이블"]
    AD["ai_documents, ai_chunks"]
    WP["wiki_pages, wiki_links<br/>wiki_revisions"]
    AR["ai_runs, ai_run_steps<br/>ai_usage"]
    CV["ai_conversations<br/>ai_messages"]
  end

  GPU["oss-llm oss-embed oss-voice"]
  LLMC["상용 LLM"]

  DOC --> ING --> AD
  ORG --> GR --> CON --> G1
  G1 --> AD
  G3 --> WP
  G5 --> AR
  CH --> DIFY --> T1
  CH -.->|"Dify 5xx 또는 10초"| T2
  T1 --> AD
  T1 --> WP
  T1 --> CV
  T1 --> RO
  G2 --> RO
  QZ --> AR
  LEC --> GPU
  RO --> GPU
  RO --> LLMC
```

## 3. 데이터 모델

### 그림 3-1. `notes` 스키마 7개 테이블과 코어 참조 4개

읽는 법: 선은 FK입니다. 제품 테이블 7개(model_catalog, runtime_config, cost_guard, user_settings, entries, runs, run_steps)와 코어 참조 4개를 그렸습니다. 일지 한 건에 실행이 여러 번(카드 재요청 포함) 붙고, 실행 한 건에 카드 3장(base1, base2, merge)이 붙습니다. 상자 아래 note가 RLS와 쓰기 주체입니다.

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
  class ai_usage {
    bigint id
  }
  class model_catalog {
    text model_id
    text display_name
    text provider
    text tier
    int credits_per_call
    boolean is_free
    boolean is_active
  }
  class runtime_config {
    text key
    int value_int
  }
  class cost_guard {
    date day
    int used_credits
  }
  class user_settings {
    uuid org_id
    uuid user_id
    text base_model_1
    text base_model_2
    text merge_model
    text theme
  }
  class entries {
    uuid id
    uuid org_id
    date entry_date
    text input_text
    text status
    text final_text
    text keywords
    uuid last_run_id
    timestamptz deleted_at
  }
  class runs {
    uuid id
    uuid entry_id
    uuid request_id
    text idempotency_key
    uuid parent_run_id
    text status
    int credits_charged
    int credits_refunded
    bigint credit_ledger_id
    uuid job_id
  }
  class run_steps {
    uuid id
    uuid run_id
    text role
    text model_id
    text status
    int credits
    int latency_ms
    bigint ai_usage_id
  }

  organizations "1" --> "*" entries : org_id cascade
  organizations "1" --> "*" user_settings : org_id cascade
  entries "1" --> "*" runs : entry_id cascade
  entries "1" --> "0..1" runs : last_run_id set null
  runs "1" --> "3" run_steps : UNIQUE run_id role
  runs --> credit_ledger : credit_ledger_id
  runs --> jobs : job_id
  run_steps --> ai_usage : ai_usage_id
  user_settings --> model_catalog : 모델 3개 set null
  runs --> model_catalog : 실행 시점 모델 ID 복사

  note for entries "SELECT 멤버 + 엔타이틀먼트 휴지통 행도 읽힘. INSERT UPDATE 컬럼 GRANT 제한. DELETE owner admin. 상태 결과 컬럼은 사용자 변경 불가 트리거 2차"
  note for runs "SELECT 멤버 + 엔타이틀먼트. 쓰기 없음. start_run record_step finish_run은 service_role 전용. 취소만 request_run_cancel"
  note for run_steps "runs와 같음. SELECT만. 전이는 record_step이 강제"
  note for user_settings "SELECT INSERT UPDATE 자기 행만. API Key 컬럼 없음"
  note for model_catalog "전역. is_active 행만 SELECT. 쓰기는 service_role"
  note for runtime_config "정책 없음 전부 거부. service만. daily_credit_cap 5000과 max_active_runs_per_org 2 제안"
  note for cost_guard "정책 없음 전부 거부. start_run이 KST 일 단위 업서트"
```

### 그림 3-2. AI 기능의 데이터는 코어의 어디에 있는가

읽는 법: 이 제품은 AI용 제품 테이블을 새로 만들지 않았습니다(`05` 6절). 왼쪽이 사용자가 보는 개념, 오른쪽이 실제로 저장되는 코어 객체입니다. 과목 수는 플랜 키 `ai_subjects_max`로 제한합니다(Free 5).

```mermaid
flowchart LR
  S["과목"] --> S2["위키 index 페이지<br/>subjects/s-sid/index<br/>컬렉션 rag:s-sid, wiki:s-sid"]
  D["노트 교재 문서"] --> D2["ai_documents, ai_chunks<br/>Storage org-files"]
  SM["문서 요약"] --> SM2["위키 source 페이지<br/>sources/d-문서id 앞 8자리"]
  CP["개념 용어"] --> CP2["위키 concept 페이지<br/>wiki_links, wiki_revisions"]
  QZ["퀴즈 문항"] --> QZ2["ai_runs.output<br/>정답은 조회 API가 제거"]
  LE["강의 세션 조각"] --> LE2["voice_sessions, voice_jobs<br/>전사 조각 Storage seq.json"]
  CO["동의 증빙"] --> CO2["ai_org_settings 국외 이전<br/>voice_jobs.consent 보관 동의<br/>write_audit 키 4종"]
  CV["채팅 대화"] --> CV2["ai_conversations<br/>ai_messages"]
```

## 4. 핵심 시퀀스

### 그림 4-1. 일지 정리 실행 (NT-F-003, 006, 017)

읽는 법: Route Handler는 입력만 확인하고 DB 함수 `start_run` 한 번으로 검증·선차감·실행 생성·잡 생성을 한 트랜잭션에 끝냅니다(고아 과금 없음). 워커가 기본 모델 2개를 병렬로 부르고 두 결과가 모두 있을 때만 통합합니다. 중복 실행은 `NT002`, 잔액 부족은 `CR001`, 일일 상한은 `NT005`로 거절됩니다. 상태 이름은 그림 5-2, 5-3과 같습니다.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant RH as Route Handler
  participant DB as Supabase notes+core
  participant WK as study-note-worker
  participant OR as OpenRouter

  B->>RH: POST /api/notes/runs + request_id, entry, models
  RH->>RH: requireSession notes, 이메일 인증 확인, zod 검증
  RH->>DB: rate_limit_hit notes:run 6회/분
  RH->>DB: 일지 upsert 사용자 세션 RLS
  RH->>DB: start_run service_role
  Note over RH,DB: 한 트랜잭션: 멤버와 엔타이틀먼트 확인, 활성 실행 없음, 모델 등급, 조직 동시 2건, 일일 예산, consume_credits 선차감, runs와 run_steps 생성, enqueue_job
  alt NT002 NT004 NT005 NT006 CR001
    RH-->>B: 409 또는 402 또는 429, 잔액 변화 없음
  end
  RH-->>B: run, steps, estimated_credits
  WK->>DB: claim_jobs notes.organize
  WK->>DB: runs.job_id와 org_id 대조, 다르면 fail_job
  WK->>DB: 원문은 payload가 아니라 entries.input_text에서 읽기
  WK->>DB: record_step running 기본 단계
  par 기본 1 호출
    WK->>OR: base1 60초 타임아웃
  and 기본 2 호출
    WK->>OR: base2 60초 타임아웃
  end
  WK->>DB: record_step succeeded 또는 failed
  opt 기본 결과 2개 모두 있음
    WK->>OR: 통합 호출
  end
  WK->>WK: 출력 형식 검증 실패는 bad_format
  WK->>DB: finish_run final_text, keywords
  Note over WK,DB: 미성공 단계 크레딧 환불, 일지 organized, 보관 한도 정리
  WK->>DB: complete_job
  DB-->>B: Realtime run_steps로 카드 갱신
  opt 사용자 취소
    B->>RH: POST /api/notes/runs/id/cancel
    RH->>DB: request_run_cancel queued는 전액 환불, running은 단계 경계에서 중단
  end
```

### 그림 4-2. 노트 정리 그래프 (NT-F-020, 021, 028)

읽는 법: 문서가 `ready`가 된 뒤 [AI로 정리]를 누르면 Next.js가 선차감하고 서명 토큰(수명 10분, 1회 사용)으로 FastAPI에 실행을 요청합니다. 실제 그래프는 FastAPI 잡 소비자가 돌립니다. 최종 실패는 `fail_job`이 자동 환불하고, 끝난 뒤 실제 사용량으로 정산해 차액을 환불합니다.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant NX as Next.js
  participant FA as FastAPI 소비자
  participant DB as Supabase core

  B->>NX: POST /api/notes/documents/upload-url
  NX-->>B: 서명 업로드 URL 20회/시간 제한
  B->>NX: POST /api/notes/documents 권한 확인 필수
  alt rights_confirmed 없음
    NX-->>B: 403 UPLOAD_RIGHTS_REQUIRED
  end
  NX->>FA: POST /rag/ingest scope rag
  FA->>DB: ai_documents pending, indexing, ready
  B->>NX: POST /api/ai/organize + request_id, 문서 1~5개
  NX->>NX: requireSession, 이메일 인증, ai_doc_max_chars, 레이트 리밋 6회/시간
  NX->>DB: 문서가 같은 조직 ready인지 확인
  alt 같은 문서에 활성 실행
    NX-->>B: 409
  end
  NX->>DB: consume_credits consume:notes:request_id
  alt CR001
    NX-->>B: 402
  end
  NX->>FA: POST /graphs/notes.organize/runs 토큰 scope graph:notes.organize
  FA->>DB: ai_runs queued + enqueue_job notes.ai job:notes:request_id
  FA-->>NX: run_id
  NX-->>B: run_id, estimated_credits, route
  FA->>DB: claim_jobs notes.ai
  loop 노드 upload summary link quiz compliance
    FA->>DB: ai_run_steps 기록, 30초마다 heartbeat_job
  end
  FA->>DB: 통과분만 커밋 위키 upsert expected_version, ai_runs.output
  alt 최종 실패
    FA->>DB: fail_job 자동 환불
  else 성공
    FA->>DB: complete_job
  end
  loop 2초 폴링
    B->>NX: GET /api/ai/runs/id RLS로 ai_runs 읽기
  end
  Note over NX,DB: 정산 크론이 5분마다 ai-settle 호출, 선차감보다 적게 썼으면 refund_credits
```

### 그림 4-3. 강의 녹음에서 노트 생성 (NT-F-026)

읽는 법: 강의에는 제3자 목소리가 담기므로 매번 고지를 확인받고, STT는 오픈소스 제공자로 강제하며 상용으로 대체하지 않습니다. 5분 조각마다 길이 기준으로 선차감하고, 조각이 실패하면 그 조각만 환불하고 재시도합니다. 끝난 전사본은 문서로 등록되어 그림 4-2 흐름으로 이어집니다.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant NX as Next.js
  participant DB as Supabase core+Storage
  participant G as 오픈소스 STT

  B->>NX: POST /api/voice/lectures subject, title, notice_version, keep_audio
  NX->>NX: requireSession, 플랜 lecture_note 확인
  alt 고지문 버전 불일치
    NX-->>B: 403 LECTURE_NOTICE_REQUIRED
  end
  NX->>DB: write_audit notes_consent.lecture_notice + voice_sessions INSERT
  NX-->>B: lecture_id, max_minutes, chunk_seconds 300
  loop 5분 조각
    B->>NX: POST /api/voice/lectures/id/chunks seq, audio
    NX->>DB: rate_limit_hit 30회/60초, consume_credits voice:id 조각 길이 기준
    NX->>NX: resolve_ai_route lecture_note stt 강제 오픈소스
    alt 허용 시간 초과
      NX-->>B: 413 VOICE_TOO_LONG
    end
    NX->>G: STT scope voice
    alt 조각 실패
      NX->>DB: 그 조각 환불
      NX-->>B: 502 LECTURE_CHUNK_FAILED 재시도 가능
    else 성공
      NX->>DB: 전사 조각 Storage seq.json, 원본 보관 선택 시만 voice-audio
      NX-->>B: seq, done, text_chars
    end
  end
  B->>NX: POST /api/voice/lectures/id/finish
  alt 조각 누락
    NX-->>B: 409 missing_seqs
  end
  NX->>DB: 전사 조각 seq 순서 병합, voice_sessions ended, 정산
  NX-->>B: transcript 수정 가능
  B->>NX: POST /api/notes/documents source text
  Note over B,NX: 이후 그림 4-2의 정리 그래프와 같음
```

### 그림 4-4. AI 채팅 한 턴 (NT-F-024, 028)

읽는 법: 브라우저는 `/api/ai/*`만 부르고 Dify와 FastAPI는 서버끼리 부릅니다. 제공자 호출 전에 오픈소스 경로 2, 상용 경로 5를 선차감하고 끝난 뒤 실제 사용량으로 정산합니다. 근거가 없으면 "노트 밖 일반 설명"으로 구분해 표시합니다.

```mermaid
sequenceDiagram
  participant B as 브라우저
  participant G as AI 게이트 Next.js
  participant DB as Supabase core
  participant D as Dify notes-chat
  participant F as FastAPI

  B->>G: POST /api/ai/conversations subject_id, channel
  G->>DB: ai_conversations INSERT, dify_user는 HMAC
  B->>G: POST /api/ai/chat message 1~1000자 + request_id
  G->>G: requireSession, 이메일 인증, 입력 마스킹
  G->>DB: rate_limit_hit 20회/60초와 하루 ai_chat_turns_per_day
  alt 한도 초과
    G-->>B: 429 AI_DAILY_LIMIT 등
  end
  G->>DB: consume_credits 2 또는 5, 키 conv:id:turn:n
  alt CR001
    G-->>B: 402
  end
  G->>D: chat-messages user dify_user, platform_conversation_id, subject_id
  D->>F: POST /tools/answer 내부 키, 모드 notes
  F->>DB: 대화 매핑으로 org와 과목 확인, match_ai_chunks rag:s-sid와 wiki:s-sid
  F->>F: chat 모델 호출 후 compliance 후처리
  F->>DB: ai_messages assistant 행 + citations
  F-->>D: answer, citations, no_source, usage
  D-->>G: 답변
  G-->>B: SSE delta, citations, usage, done
  opt Dify 5xx 또는 10초 무응답
    G->>F: POST /tools/answer-direct 서명 토큰 scope chat rag wiki
    F-->>G: 같은 형식 응답 + 운영 알림
  end
  G->>DB: 정산 실제 1부터 선차감값, 적게 썼으면 refund_credits
  opt 모든 제공자 실패
    G->>DB: 선차감 전액 환불
  end
  Note over G,DB: 스트림이 끊기면 ai-settle 크론이 5분마다 settled_at null 행 정산
```

## 5. 상태 머신

### 그림 5-1. `entries.status`

읽는 법: 일지 한 건의 상태입니다. 전이는 `entries_status_transition` 트리거가 강제하며 service_role에도 적용됩니다. 이전 최종본이 있는 일지에서 새 실행이 실패하면 `organized`로 돌아가 이전 최종본을 유지합니다. 휴지통은 상태가 아니라 `deleted_at` 컬럼입니다.

```mermaid
stateDiagram-v2
  [*] --> draft : 회원이 일지 저장
  draft --> organizing : start_run
  organizing --> organized : finish_run 성공 또는 실패했지만 이전 최종본 있음
  organizing --> draft : finish_run 또는 request_run_cancel 성공 결과와 이전 최종본 없음
  organized --> organizing : start_run 재정리
```

### 그림 5-2. `runs.status`

읽는 법: 실행 한 건의 상태입니다. 전이를 일으키는 함수 이름이 화살표 옆에 있습니다. 종료 상태에서는 단계나 종료 쓰기가 모두 `NT003`으로 거절되어 늦게 온 응답이 결과를 덮어쓰지 못합니다.

```mermaid
stateDiagram-v2
  [*] --> queued : start_run 선차감과 잡 생성
  queued --> running : record_step 첫 호출 또는 finish_run
  queued --> canceled : request_run_cancel 전액 환불
  running --> succeeded : finish_run 통합 성공 + 키워드 2개
  running --> partial : finish_run 일부 성공 나머지 환불
  running --> failed : finish_run 성공 단계 없음 전액 환불
  running --> canceled : finish_run 취소 요청 있고 성공 단계 없음
  succeeded --> [*]
  partial --> [*]
  failed --> [*]
  canceled --> [*]
```

### 그림 5-3. `run_steps.status`

읽는 법: 카드 한 장(base1, base2, merge)의 상태이며 `record_step`이 전이를 강제합니다. `reused`는 카드별 재요청에서 부모 실행의 성공 결과를 복사한 상태로 0크레딧입니다. 남은 `pending`은 `finish_run`이 `skipped`(취소 실행은 `canceled`)로, `running`은 `failed`(`aborted`)로 정리합니다.

```mermaid
stateDiagram-v2
  [*] --> pending : 실행 생성
  [*] --> reused : 재요청 시 부모 성공 결과 복사
  pending --> running : record_step
  pending --> skipped : record_step 또는 finish_run
  pending --> canceled : record_step 또는 finish_run
  pending --> failed : record_step
  running --> succeeded : record_step
  running --> failed : record_step 또는 finish_run aborted
  running --> canceled : record_step
  succeeded --> [*]
  failed --> [*]
  skipped --> [*]
  canceled --> [*]
  reused --> [*]
```

### 그림 5-4. 문서 색인 상태 `ai_documents.status`

읽는 법: 업로드한 노트·교재의 색인 상태입니다. 이 표는 `05_DATA_MODEL.md`가 아니라 `01_PRD.md` NT-F-020(pending, indexing, ready, failed)과 NT-F-031(deleted)의 서술을 그린 것이고, `failed`에서 다시 시도하는 전이는 `03` 2.5절의 [다시 시도] 버튼에서 가져왔습니다. 정확한 전이 규칙은 코어 SQL이 정본입니다.

```mermaid
stateDiagram-v2
  [*] --> pending : 문서 등록 Next.js
  pending --> indexing : FastAPI rag_ingest
  indexing --> ready : 색인 완료
  indexing --> failed : 색인 실패
  failed --> pending : 사용자 다시 시도
  ready --> deleted : 사용자 문서 삭제 청크 삭제
  failed --> deleted : 사용자 문서 삭제
  deleted --> [*]
```

## 6. 화면 흐름

### 그림 6-1. 공개 화면, 가입, 온보딩

읽는 법: 랜딩에서 가입·로그인으로 들어가 콜백을 거치고, OAuth 첫 로그인이면 약관 동의(`/onboarding/terms`, 제안 경로)를 지나 AI 처리 방식 동의를 한 뒤 작업실로 갑니다. Stage A에서는 `/login`이 개발용 패널뿐이고 `/signup`·`/verify`가 없습니다.

```mermaid
flowchart LR
  LAND["/ 랜딩<br/>3D 히어로"]
  LGL["/terms, /privacy"]
  SGN["/signup<br/>만 14세 이상 체크"]
  VRF["/verify<br/>이메일 인증 안내"]
  LGN["/login<br/>Stage A는 개발용 패널"]
  CB["/auth/callback"]
  TRM["/onboarding/terms<br/>OAuth 첫 로그인, 제안"]
  OAI["/onboarding/ai<br/>국외 이전 동의 선택"]
  APP["/app 작업실"]

  LAND --> LGL
  LAND --> SGN
  LAND --> LGN
  SGN --> VRF --> CB
  LGN --> CB
  CB -->|"이메일 가입자"| OAI
  CB -->|"OAuth 약관 미동의"| TRM --> OAI
  CB -.->|"오류"| LGN
  OAI --> APP
```

### 그림 6-2. 앱 셸 화면

읽는 법: `/app` 작업실이 첫 화면이고 GNB 두 묶음(일지, 학습)과 아래 고정 메뉴가 갈래입니다. 퀴즈 풀이는 목록 메뉴 없이 노트 상세에서 들어갑니다(결정 대기 D-25). 채팅 패널은 모든 `/app` 화면 위로 열립니다. `/app/billing`은 Phase 2 결제 전까지 잔액·사용 내역만 보입니다.

```mermaid
flowchart TB
  WORK["/app 작업실<br/>입력 + 결과 카드"]
  HIS["/app/history<br/>보관함 P1"]
  HID["/app/history/id<br/>카드 3장 복원 P1"]
  NOTE["/app/notes<br/>업로드 색인 상태"]
  NOD["/app/notes/id<br/>요약 개념 퀴즈"]
  QUIZ["/app/quiz/run_id<br/>퀴즈 풀이"]
  LEC["/app/lecture<br/>녹음 전사 확인"]
  SUB["/app/subjects<br/>과목 목록"]
  SBH["/app/subjects/sid<br/>위키 목차 문서"]
  WIKI["위키 페이지<br/>보기 편집 이력 백링크"]
  LINT["위키 점검 P1"]
  CHAT["채팅 패널<br/>/app/chat 대화 목록"]
  SET["/app/settings<br/>모델 테마 AI 처리 방식 내보내기"]
  BILL["/app/billing<br/>Phase 2"]

  WORK --> HIS --> HID
  WORK --> NOTE --> NOD --> QUIZ
  LEC -->|"노트로 정리"| NOTE
  WORK --> LEC
  WORK --> SUB --> SBH --> WIKI
  SBH --> LINT
  NOD -->|"이 노트에 대해 묻기"| CHAT
  WORK --> CHAT
  WORK --> SET
  WORK --> BILL
```

## 7. 보안 경계

### 그림 7-1. 자산·위협·대응의 신뢰 경계

읽는 법: 위에서 아래로 갈수록 믿을 수 있는 영역입니다. 이 제품의 `SECURITY.md`는 아직 비어 있어, 각 대응은 해당 문서에서 가져왔고 상자 끝에 출처를 적었습니다. § 번호는 `SECURITY_BASELINE.md` 장입니다. 핵심 자산은 서버 LLM 키(유출 시 비용), 강의 녹음의 제3자 음성, 업로드한 교재(저작물), 크레딧입니다. 최종 방어선은 DB의 RLS와 트랜잭션입니다.

```mermaid
flowchart TB
  subgraph Z0["① 신뢰하지 않는 영역"]
    BR["브라우저, 봇, 악의적 원문<br/>프롬프트 인젝션"]
  end

  subgraph Z1["② 입구 Vercel"]
    LIM["레이트 리밋<br/>실행 6회/분, 업로드 URL 20회/시간<br/>§8, §21"]
    ENV["NEXT_PUBLIC 비밀 이름 기동 실패<br/>빌드 산출물 sk-or 검사<br/>02 6절, §5, §19"]
  end

  subgraph Z2["③ 앱 서버 신뢰"]
    MASK["입력 마스킹 주민번호 전화 이메일 계좌<br/>원문 로그 금지<br/>01 6.2, §12"]
    UPR["업로드 권한 확인 필수<br/>write_audit notes_upload_rights"]
    TOK["서명 토큰 개인키 서버 전용<br/>Dify 입력에 토큰 org 금지<br/>§16"]
    QG["퀴즈 조회 시 정답 제거<br/>TTS는 DB 텍스트만<br/>04 2.1"]
  end

  subgraph Z3["④ 데이터 최종 방어선"]
    TX["start_run 단일 트랜잭션<br/>NT002 NT003 NT005 NT006<br/>일지당 활성 1개 유니크"]
    RLS["RLS + 컬럼 GRANT + 전이 트리거<br/>cost_guard runtime_config 전부 거부<br/>§1~4, §15"]
    AUD["감사 로그<br/>동의 4종 업로드 권한<br/>§9"]
  end

  subgraph Z4["⑤ AI와 외부 제한 신뢰"]
    WRKR["워커 잡과 실행 org 대조<br/>LLM 키는 워커 FastAPI만"]
    FAP["FastAPI 공개 HTTPS<br/>토큰 또는 내부 키 없으면 401<br/>§16"]
    OSS["강의 STT 오픈소스 강제<br/>contains_pii 문서 오픈소스만<br/>국외 이전 미동의 시 오픈소스만"]
    DFY["Dify 대화 로그 30일<br/>콘솔 운영자 2단계 인증"]
  end

  BR -->|"모든 요청"| LIM
  LIM --> ENV
  ENV --> Z2
  MASK --> FAP
  UPR --> RLS
  TOK --> FAP
  Z2 -->|"service_role 서버만"| TX
  TX --> RLS
  RLS --> AUD
  WRKR --> RLS
  FAP --> OSS
  FAP --> DFY
```

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 기존 웹 경로(위)는 그대로이고, 에이전트용 입구(아래)가 같은 Route Handler 응답과 RLS 읽기를 이용합니다. 이 제품은 학습자 원문이 중심이고 익명에게 줄 공개 데이터가 없어, 도구는 로그인 후 상태 조회와 비용 안내 5개(+ Phase 2 위키 1개)뿐입니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 Phase 2 또는 미결정(D-M#)입니다.

### 8-1. API 위에 얹는 MCP 구성

```mermaid
flowchart LR
  subgraph U["사용자 쪽"]
    BR["브라우저 학습자"]
    AG["AI 에이전트<br/>학습자 비서"]
  end

  subgraph WEB["기존 웹 경로"]
    NX["Next.js 서버 계층<br/>requireSession notes Route Handler"]
    CR["크레딧 선차감<br/>start_run ai organize"]
  end

  subgraph MCPL["새 MCP 층 mcp-server"]
    TR["Streamable HTTP<br/>Bearer 필수 익명 없음"]
    RL["레이트 리밋 사용자"]
    TL["도구 5개 Phase 2에 1개 추가<br/>필드 허용 목록 출력"]
    SAN["문서 제목 untrusted 처리<br/>본문 결과 퀴즈 정답 제외"]
  end

  subgraph DB["DB 최종 방어선"]
    RUN["runs run_steps ai_runs<br/>멤버 RLS"]
    DOC["ai_documents wiki_pages<br/>멤버 RLS"]
    OWN["본인 행만 걸러냄<br/>created_by 제안 D-M4"]
  end

  BR --> NX
  NX --> CR
  NX -->|"사용자 세션"| RUN
  AG --> TR
  TR --> RL
  RL --> TL
  TL --> SAN
  TL -.->|"사용자 토큰 D-M1 D-M2"| RUN
  TL -.->|"목록 읽기 D-M3"| DOC
  RUN --> OWN
  DOC --> OWN
  TL -.->|"확인 링크 D-M7"| NX
```

### 8-2. 정리 준비와 사람 확정 (`study_prepare_organize`)

```mermaid
sequenceDiagram
  autonumber
  actor L as 학습자
  participant A as AI 에이전트
  participant M as MCP 서버
  participant D as DB 읽기
  participant W as 웹 과목 화면

  L->>A: 이 문서 3개 정리하면 크레딧 얼마야
  A->>M: study_prepare_organize 과목 문서 id
  M->>D: 문서 상태 글자 수 한도 잔액 읽기
  D-->>M: 읽기 결과
  Note over M: 저장하지 않음<br/>consume_credits 호출 안 함<br/>문서 본문 입력 안 받음
  M-->>A: 가능 여부 예상 크레딧 확정 전 문구 확인 링크 15분
  A-->>L: 약 N크레딧이 필요합니다 아직 차감 전입니다 링크에서 진행하세요
  L->>W: 링크 열기 로그인 세션 일치 확인
  W-->>L: 문서 선택과 예상 크레딧 표시
  L->>W: 정리 시작 클릭
  W->>D: POST api ai organize 선차감 멱등 request_id
  D-->>W: run_id 또는 CR001 AI_PLAN_LIMIT
  W-->>L: 진행률 표시
```

### 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph R1["R1 로그인 읽기 1.5"]
    T1["study_list_subjects"]
    T2["study_list_documents"]
    T3["study_get_run_status"]
    T4["study_get_ai_run_status"]
  end
  subgraph PR["준비 저장 안 함 1.5"]
    T5["study_prepare_organize"]
  end
  subgraph P2["Phase 2 결정 후"]
    T6["study_get_wiki_page"]
  end
  subgraph NO["만들지 않음"]
    N1["일지 원문 정리 결과 위키 퀴즈 정답"]
    N2["정리 실행 재시도 취소 채팅 채점"]
    N3["강의 녹음 전사 음성"]
    N4["업로드 삭제 내보내기 계정 삭제 결제"]
  end
  R1 --> PR --> P2
  PR -.->|"사람이 웹에서 확정"| N2
```

## 문서 불일치

그림에는 아래 각 항목에서 표시한 쪽을 골랐습니다.

| # | 내용 | 문서 A | 문서 B | 그림에서 고른 쪽 |
|---|---|---|---|---|
| 1 | 제품 보안 문서의 상태 | `SECURITY.md`는 자산·위협·수치가 모두 "작성 필요"인 템플릿이고 "1~21장"을 가리킴 | `SECURITY_BASELINE.md`는 22장까지 있고 22장이 제품별 `SECURITY.md` 규칙 | 그림 7-1은 `01_PRD` 6장, `02` 6절, `04` 1절, `05` 7절 내용으로 구성, 장 번호는 baseline 기준 |
| 2 | 문서 색인 상태의 정의 위치 | `05_DATA_MODEL.md`에는 `ai_documents` 상태 전이 표가 없음(코어 객체라 참조만) | `01_PRD.md` NT-F-020, 031과 `03` 2.5절에만 상태 이름이 나옴 | 그림 5-4는 01·03에서 구성, 코어 SQL로 확인 필요 |
| 3 | 퀴즈 풀이 진입 경로 | `03_SCREENS_UX.md` 1절은 `/app/quiz/[run_id]`만 있고 목록 경로 없음 | 같은 문서 8.1절 D-25(퀴즈 목록 메뉴)가 결정 대기 | 목록 없이 노트 상세에서 진입(그림 6-2) |
| 4 | MCP 과목·문서 목록 | `MCP.md`의 `study_list_subjects`·`study_list_documents`는 목록 읽기 경로가 필요 | `04_API.md` 2.1절 하단은 RLS 직접 읽기만 말하고 목록 Route Handler와 `ai_documents` 컬럼 정의가 없음(`05_DATA_MODEL.md` 6절은 표 이름만) | 그림 8-1은 "멤버 RLS 읽기"로만 표기(D-M3) |
| 5 | MCP 본인 행 필터 | `MCP.md` 5절 MT4: 도구는 호출 사용자 본인이 만든 행만 돌려줌 | `05_DATA_MODEL.md` 4절: `runs`·`run_steps` SELECT는 조직 멤버 전체. `runs`에 `created_by`가 있는지 문서에 없음 | 그림 8-1의 "본인 행만 걸러냄"은 제안(D-M4) |
| 6 | MCP 예상 크레딧 읽기 | `MCP.md`의 `study_prepare_organize`는 한도와 예상 크레딧을 읽기만 해야 함 | `04_API.md` 3절: `notes.org_features`는 service 전용이고 예상 크레딧은 `POST /api/ai/organize` 응답(선차감과 한 번에)으로만 나옴 | 읽기 전용 경로 필요(D-M6), 그림 8-2는 "DB 읽기"로만 표기 |
| 7 | 보안 문서 범위 | `SECURITY.md`는 아직 템플릿("작성 필요")이고 MCP 위협 행(T2)은 그 표의 첫 실제 행임 | `MCP.md`: 학습자 원문·미성년·제3자 음성 통제는 `01_PRD.md` 6장에 흩어져 있음 | `MCP.md` 5절에 필요한 부분만 인용 |

## 갱신 규칙

`01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `SECURITY.md`를 고치면 해당 절의 그림도 같은 변경에서 함께 고칩니다(표의 "근거 문서 절" 참조).
