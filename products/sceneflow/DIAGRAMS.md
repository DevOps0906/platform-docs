# DIAGRAMS: SceneFlow (sceneflow) UML 시각화

작성일 2026-10-23. 이해관계자(기획·개발·운영·법무) 소통용 그림 모음입니다. 정본은 각 문서이며, 그림과 문서가 다르면 문서가 우선입니다. GitHub에서 그림이 바로 렌더링됩니다(Mermaid).

**제품 한 줄 정의**: 말로 지시하면 AI가 편집안을 만들고 승인하면 실행하는 AI 자동편집(주력, SF-5)으로, 스토리보드 하나에서 롱폼 1편 + 장면 단위 쇼츠 + 언어판(KO/JA/EN)을 만들어 다채널에 배포하는 조직 단위 영상 SaaS입니다(`README.md` 1절).

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `08_AGENCY_OPERATIONS.md`(참고), `SECURITY.md`(미작성 초안, 아래 "문서 불일치" 참조), 공통 맥락은 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`, `SECURITY_BASELINE.md`, `CORE_SPEC.md`.

**표기**: 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·조건부, "(제안)" = 문서가 확정 전이라고 적은 값. 스토리보드 트랙(Track S, 2026-10-18)과 AI 자동편집(2026-10-18) 이후의 정본 장(01장 10~11장, 02장 10~11장, 03장 8~9장, 04장 9~10장, 05장 11~12장)을 기준으로 그렸습니다. Track E·F(Lofi, 플레이리스트)는 Phase 2라 그림에서 흐릿하게만 표시합니다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1 | 사용자와 기능 | 유스케이스(flowchart) | `01_PRD.md` 1절, 2절, 3.1절, 10~11장 |
| 2 | 구성요소 | 컴포넌트(flowchart) | `02_ARCHITECTURE.md` 2절, 7절, 10.1절, 11.1절 |
| 3 | 데이터 모델 | 클래스 | `05_DATA_MODEL.md` 2.1절, 2.13절, 2.16절, 2.19~2.21절, 11~12장 |
| 4-1 | 스토리보드 생성 | 시퀀스 | `04_API.md` 9.1절, 9.4절, 9.5절, `01_PRD.md` VD-F-130~131 |
| 4-2 | AI 편집안 적용과 되돌리기 | 시퀀스 | `04_API.md` 10.1~10.2절, `01_PRD.md` VD-F-146~151 |
| 4-3 | 마스터 컷 렌더와 쇼츠 추출 | 시퀀스 | `04_API.md` 9.1절, 9.4절, `02_ARCHITECTURE.md` 10.3절, VD-F-136~137 |
| 4-4 | 업로드 검사와 고객 승인 | 시퀀스 | `04_API.md` 2절 업로드 행, `03_SCREENS_UX.md` 2.2.2절 |
| 5-1 | 스토리보드 상태 | 상태 머신 | `05_DATA_MODEL.md` 11.3절, 12.4절 |
| 5-2 | 쇼츠·변형본 컷 상태 | 상태 머신 | `05_DATA_MODEL.md` 11.3절 |
| 5-3 | 편집안 상태 | 상태 머신 | `05_DATA_MODEL.md` 12.4절 |
| 5-4 | 업로드 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 5-5 | 고객 승인 상태 | 상태 머신 | `05_DATA_MODEL.md` 3절 |
| 6 | 화면 흐름 | flowchart | `03_SCREENS_UX.md` 1절, 7.3절, 8~9장 |
| 7 | 보안 경계 | flowchart | `04_API.md` 1절, `05_DATA_MODEL.md` 4절, 7절, `02_ARCHITECTURE.md` 2절, 7절, `SECURITY_BASELINE.md` |

## 1. 사용자와 기능

읽는 법: 왼쪽은 사람, 가운데는 MVP 기능, 오른쪽은 P1과 Phase 2입니다. 첫 고객은 현우(SF-4)이고, 지훈(대행)은 그다음입니다. 기능 옆 번호는 `01_PRD.md`의 기능 ID입니다.

```mermaid
flowchart LR
  P1(["현우<br/>지식·역사 채널 1인<br/>첫 고객 SF-4"])
  P2(["민재·수진<br/>Track A·B 크리에이터"])
  P3(["지훈<br/>대행 운영 PD<br/>Advanced"])
  P4(["태호<br/>음원·플리 채널"])
  CL(["대행 고객사<br/>토큰 링크 사용"])

  subgraph MVP["MVP"]
    S1["스토리보드 생성·편집<br/>VD-F-130~132, 141"]
    S2["장면 다시 만들기·소재<br/>VD-F-133~134"]
    S3["미리보기·마스터 컷 렌더<br/>VD-F-135~136, 139"]
    S4["쇼츠 추출 최대 10편<br/>VD-F-137"]
    S5["출처 칸·사실 확인 경고<br/>VD-F-138"]
    AI1["AI 편집 지시·자동 다듬기<br/>VD-F-146~147"]
    AI2["무음·군더더기 컷·자막 강조<br/>VD-F-148~150"]
    AI3["화면비·해상도·변형본<br/>VD-F-143~145"]
    TA["Track A 더빙 숏폼<br/>VD-F-030"]
    TB["Track B 커머스 숏폼·랜딩<br/>VD-F-031, 060"]
    RD["레이더·주제 점수<br/>VD-F-010~013"]
    UP["업로드·compliance·제휴 문구<br/>VD-F-062, 071~072"]
    NC["네이버 클립 업로드<br/>VD-F-075"]
    CH["AI 채널 코치·가이드 위키<br/>VD-F-100~102"]
    AG["대행 고객·승인·리포트<br/>VD-F-120~126"]
  end

  subgraph P1G["P1"]
    X1["적합도·리테이크·챕터<br/>VD-F-152~154"]
    X2["프리셋·B-roll·썸네일<br/>NLE·연도 점검 VD-F-155~159"]
  end

  subgraph PH2["Phase 2"]
    Y1["Track E Lofi·Track F 플리"]
    Y2["외부 대행사 화이트라벨 D-24<br/>추적 리프레임·립싱크"]
  end

  P1 --> S1
  P1 --> AI1
  P1 --> S4
  P1 --> CH
  P2 --> TA
  P2 --> TB
  P2 --> RD
  P2 --> UP
  P2 --> NC
  P3 --> AG
  CL -->|"승인 또는 수정 요청"| AG
  P4 -.-> Y1
  P3 -.-> Y2
  S1 --> S2
  S2 --> S3
  S3 --> S4
  S3 --> S5
  AI1 --> AI2
  AI1 --> AI3
  S3 --> UP
  AI1 -.-> X1
  AI1 -.-> X2
```

## 2. 구성요소

읽는 법: 브라우저는 Next.js(Route Handler)만 부르고, 무거운 일은 `core.jobs` 큐를 거쳐 오케스트레이터와 미디어 워커가 합니다. FastAPI(텍스트·그래프)와 미디어 워커(영상·오디오)는 서로 호출하지 않으며, 둘을 이어 주는 것은 오케스트레이터와 `core.jobs`입니다.

```mermaid
flowchart TB
  BR["브라우저<br/>편집기·미리보기"]

  subgraph WEB["Next.js 웹 (Vercel)"]
    RH["Route Handler<br/>requireSession·zod"]
    SD["server domain<br/>storyboards·clients 등"]
    AG["AI 게이트<br/>/api/ai·/api/internal"]
  end

  subgraph SUP["Supabase (모듈러 video 스키마)"]
    CORE["core<br/>크레딧·잡·감사"]
    VID["video 스키마<br/>storyboards 등"]
    ST["Storage video-media<br/>서명 URL"]
    RT["Realtime core.jobs"]
  end

  subgraph WK["워커 (Railway)"]
    OR["video-orchestrator<br/>BullMQ·Node"]
    MC["media-worker CPU<br/>FFmpeg"]
    MG["media-worker GPU<br/>Whisper"]
  end

  RD[("Upstash Redis")]
  FA["FastAPI apps/api<br/>video.storyboard·edit_plan"]
  DF["Dify 공용<br/>video-chat"]
  GPU["공용 GPU 서버<br/>oss-llm·oss-voice"]

  subgraph EXT["외부 서비스"]
    FAL["fal 이미지"]
    EL["ElevenLabs"]
    LLM["상용 LLM"]
    SNS["YouTube·Meta·TikTok<br/>네이버 클립"]
    TOSS["Toss Payments"]
  end

  BR --> RH
  RH --> SD
  SD -->|"consume_credits<br/>enqueue_job"| CORE
  SD -->|"사용자 세션 RPC"| VID
  RT -.->|"RLS 하에서 구독"| BR
  AG -->|"EdDSA 서명 토큰"| FA
  AG --> DF
  SD -->|"edit_plan 동기 호출"| FA
  OR --- RD
  OR -->|"claim·complete"| CORE
  OR -->|"잡 토큰 요청"| AG
  OR -->|"storyboard.generate"| FA
  OR --> FAL
  OR --> EL
  OR -->|"media.* 자식 잡"| CORE
  MC -->|"claim_jobs"| CORE
  MG -->|"claim_jobs"| CORE
  MC --> ST
  FA --> LLM
  FA --> GPU
  MG -->|"Whisper"| ST
  OR --> SNS
  RH <-->|"승인 확인"| TOSS
```

## 3. 데이터 모델

읽는 법: Track S의 중심은 `storyboards`이고, 렌더 결과는 기존 `outputs`와 `uploads` 경로를 그대로 탑니다. 사용자는 대부분 읽기(SELECT)만 하고 쓰기는 서버 또는 RPC입니다. 편집안 테이블 `edit_presets`, `pronunciation_lexicon`과 `video.productions`(Track A·B)는 그림 크기 때문에 뺐습니다. `outputs`, `uploads`, `channels`는 자주 쓰는 열만 적었습니다.

```mermaid
classDiagram
  class storyboard_templates {
    +text code
    +text status
  }
  class storyboards {
    +uuid id
    +uuid org_id
    +uuid client_id
    +text format
    +text aspect
    +text resolution
    +int fps
    +text template_code
    +text status
    +int version
    +int revision
    +uuid root_job_id
  }
  class scenes {
    +uuid id
    +int ord
    +text kind
    +int duration_ms
    +text narration
    +text motion_preset
    +bool shorts_candidate
    +bool source_required
    +int revision
  }
  class scene_assets {
    +uuid id
    +text kind
    +text lang
    +text aspect
    +text status
    +text storage_path
    +text rights_basis
  }
  class clip_transcripts {
    +uuid scene_asset_id
    +text provider
  }
  class storyboard_cuts {
    +uuid id
    +text kind
    +text aspect
    +uuid scene_ids
    +text hook_text
    +text status
  }
  class storyboard_snapshots {
    +uuid id
    +int version
    +jsonb snapshot
  }
  class edit_plans {
    +uuid id
    +text source
    +jsonb commands
    +int estimate_credits
    +text base_fingerprint
    +text status
  }
  class outputs {
    +uuid id
    +uuid storyboard_cut_id
    +text language
    +text aspect
    +text status
  }
  class uploads {
    +uuid id
    +text platform
    +bool has_affiliate
    +text status
  }
  class channels {
    +uuid id
    +text platform
    +uuid credential_id
    +text status
  }
  class clients {
    +uuid id
    +text name
    +bool review_required
    +text status
  }
  class client_reviews {
    +uuid id
    +text token_hash
    +timestamptz expires_at
    +text decision
  }

  storyboard_templates "1" <-- "*" storyboards : template_code
  clients "1" <-- "*" storyboards : client_id
  storyboards "1" --> "*" scenes : 장면 1 to 240
  scenes "1" --> "*" scene_assets : ready 1개 + superseded
  scene_assets "1" --> "0..1" clip_transcripts : clip 소재
  storyboards "1" --> "*" storyboard_cuts : master 1, short 10, variant 3
  storyboards "1" --> "*" storyboard_snapshots : 렌더마다 1행
  storyboard_cuts "1" --> "*" storyboard_snapshots : cut_id
  storyboards "1" --> "*" edit_plans : AI 편집안
  storyboard_cuts "1" --> "*" outputs : storyboard_cut_id
  outputs "1" --> "*" uploads : output_id
  channels "1" --> "*" uploads : channel_id
  clients "1" --> "*" client_reviews : client_id
  uploads "1" --> "*" client_reviews : upload_id

  note for storyboards "RLS: 멤버 + 엔타이틀먼트 조회. INSERT와 일부 UPDATE는 owner admin member. status와 root_job_id는 컬럼 GRANT에서 제외. DELETE는 owner admin"
  note for scenes "직접 쓰기 42501. 사용자 RPC save_scene 등 revision 낙관적 동시성. 서버는 apply_storyboard_result"
  note for scene_assets "서버만 쓰기 finish_scene_asset. 경로 첫 폴더 = org_id. clip은 권리 근거 필수 VD019"
  note for storyboard_snapshots "서버만 INSERT. UPDATE와 DELETE는 service도 거부"
  note for edit_plans "서버 INSERT. 사용자는 apply undo reject RPC로만 상태 변경"
  note for client_reviews "token_hash는 사용자 SELECT 열에서 제외. 쓰기는 서버 RPC만"
  note for clients "owner admin 쓰기, features.agency 필요"
```

## 4. 핵심 시퀀스

### 4-1. 스토리보드 생성 (VD-F-130, 131)

읽는 법: 크레딧은 Route Handler가 먼저 차감하고(`request_id` 멱등), 생성은 잡으로 넘어갑니다. 그래프 결과는 FastAPI가 서버 RPC로 한 번에 저장하며, 길이와 장면 수를 DB가 다시 검사합니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler
  participant DB as Supabase core+video
  participant OR as 오케스트레이터
  participant FA as FastAPI video.storyboard

  U->>API: POST /api/storyboards (형식, 길이, 템플릿, 주제, request_id)
  API->>API: requireSession, zod, 플랜 한도 VD009
  API->>API: 주제 점수 60 게이트 VD010
  API->>DB: consume_credits (대본 쇼츠 3 또는 롱폼 5)
  API->>DB: storyboards INSERT (status draft)
  API-->>U: storyboard
  U->>API: POST /api/storyboards/id/generate (request_id)
  API->>DB: consume_credits (쇼츠 4 또는 롱폼 10분당 8)
  API->>DB: enqueue_job storyboard.generate
  API-->>U: jobId
  DB-->>U: Realtime 진행률
  OR->>API: /api/internal/ai-token (잡에 묶인 토큰)
  OR->>FA: POST /graphs/video.storyboard/runs
  FA->>DB: apply_storyboard_result (service_role)
  Note over DB: 길이 합계 VD017, 장면 수 VD018 재검사
  alt 검사 통과
    DB-->>FA: storyboards ready, version 증가
    OR->>DB: complete_job
  else 길이 범위 2회 이탈
    OR->>DB: fail_job (선차감 자동 환불)
  end
```

### 4-2. AI 편집안 적용과 되돌리기 (VD-F-146, 151)

읽는 법: AI는 허용 명령 17종의 목록(EDL)만 만들고 서버가 검사합니다. 승인 전에는 장면이 바뀌지 않으며, 적용은 한 트랜잭션입니다. 편집안을 만든 뒤 스토리보드가 바뀌었으면 지문 불일치로 `VD409`가 납니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler
  participant FA as FastAPI video.edit_plan
  participant DB as Supabase core+video
  participant OR as 오케스트레이터

  U->>API: POST /api/storyboards/id/edit-plans (text, request_id)
  API->>API: 게이팅 features.ai_edit
  API->>DB: consume_credits (지시 1)
  API->>DB: storyboard_fingerprint
  API->>FA: POST /graphs/video.edit_plan/runs (서명 토큰)
  FA-->>API: 편집 명령 목록
  API->>API: EDL 검사 (허용 목록 밖 VD023, 100개 이하)
  API->>API: 금지 문구 compliance 재통과
  API->>DB: edit_plans INSERT proposed (service)
  API-->>U: 전후 비교 + 예상 크레딧
  U->>API: POST /api/edit-plans/id/apply (command_ids, request_id)
  API->>DB: rpc apply_edit_plan (사용자 세션)
  alt 지문이 다름
    DB-->>API: VD409 (다시 제안받기)
  else 렌더 중
    DB-->>API: VD020
  else 적용 성공
    DB-->>API: applied, pending_regenerate
    opt pending_regenerate가 있음
      API->>DB: consume_credits (명령별 request_id)
      API->>OR: enqueue scene.image 또는 scene.narration
    end
  end
  U->>API: POST /api/edit-plans/id/undo
  API->>DB: rpc undo_edit_plan (가장 최근 적용분만)
```

### 4-3. 마스터 컷 렌더와 쇼츠 추출 (VD-F-136, 137)

읽는 법: 렌더는 요청 시점의 스냅샷 하나만 읽습니다. 서버 검사에 통과해야 크레딧이 빠지고 스냅샷이 생기며, 워커는 테이블에 직접 쓰지 않고 완료 보고만 합니다. 쇼츠는 같은 마스터 컷에서 후보를 고른 뒤 컷마다 스냅샷을 만들어 렌더합니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 브라우저
  participant API as Route Handler
  participant DB as Supabase core+video
  participant OR as 오케스트레이터
  participant MW as media-worker
  participant FA as FastAPI

  U->>API: POST /api/storyboards/id/render (languages, request_id)
  API->>API: 서버 검사 VD009 VD017 VD018 VD019 VD001
  API->>DB: consume_credits (렌더 + TTS + 출처 점검 1)
  API->>DB: snapshot_storyboard (status rendering)
  API->>DB: enqueue_job storyboard.render
  API-->>U: rootJobId, cutId, snapshotVersion
  OR->>FA: 출처 점검 video.step source_check
  OR->>DB: media.scene_clip 자식 잡 (video.media.cpu)
  MW->>DB: claim_jobs, 스냅샷에서 장면 읽기
  MW->>MW: scene_clip, scene_concat, stt, compose, bgm_mix, encode
  MW->>DB: complete_job
  alt 하나 이상 성공
    OR->>DB: outputs 행 기록, storyboards rendered
  else 전부 실패
    OR->>DB: storyboards ready로 복귀, 자동 환불
  end
  DB-->>U: Realtime 진행률
  U->>API: POST /api/storyboards/id/shorts (step pick)
  API->>DB: consume_credits (선정 2)
  OR->>FA: POST /graphs/video.shorts_pick/runs
  U->>API: POST /api/storyboards/id/shorts (step render, cut_ids)
  API->>DB: 컷마다 snapshot_storyboard (한도 VD021)
  API->>DB: consume_credits (컷 언어당 3) 후 enqueue storyboard.shorts
```

### 4-4. 업로드 검사와 고객 승인 (VD-F-071, 072, 123)

읽는 법: 대가성 문구는 업로드 생성 때 서버가 넣고(끌 수 없음), 검사에서 차단·경고·통과가 갈립니다. 대행 고객 채널이면 고객 승인이 있어야 예약할 수 있습니다. 고객은 로그인 없이 토큰 링크로만 접근합니다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 운영자
  actor C as 고객사 담당자
  participant API as Route Handler
  participant DB as Supabase core+video
  participant OR as 오케스트레이터
  participant SNS as 플랫폼

  U->>API: POST /api/uploads (outputId, request_id)
  API->>DB: uploads INSERT draft (대가성 문구 삽입)
  U->>API: POST /api/uploads/id/check
  API->>DB: consume_credits (LLM 검사 1), enqueue compliance.check
  alt 차단
    DB-->>U: blocked (draft로 돌아가 수정)
  else 경고
    DB-->>U: awaiting_confirm
    U->>API: POST /api/uploads/id/acknowledge
    API->>DB: approved (사유 확인 기록)
  else 통과
    DB-->>U: approved
  end
  U->>API: POST /api/uploads/id/client-review (features.agency)
  API->>API: 토큰 32바이트 생성 후 sha256
  API->>DB: open_client_review (token_hash만 저장)
  API-->>C: 승인 링크 메일
  C->>API: GET /review/token (IP 해시당 30회 10분)
  C->>API: POST /api/review/token (decision, reviewerName)
  API->>DB: decide_client_review (service)
  alt 승인
    DB-->>U: client_review에서 예약 가능
  else 수정 요청
    DB-->>U: uploads draft로 복귀
  end
  U->>API: POST /api/uploads/id/schedule
  API->>API: 승인 전이면 VD016
  API->>DB: consume_credits (채널당 1), enqueue upload.platform
  OR->>SNS: 업로드 실행
  OR->>DB: published 또는 failed
```

## 5. 상태 머신

읽는 법: 허용되지 않은 전이는 DB 트리거가 22023으로 막으며 service_role에도 적용됩니다. 화살표 옆 글자는 전이를 일으키는 주체입니다.

### 5-1. 스토리보드 `storyboards.status` (05장 11.3절)

```mermaid
stateDiagram-v2
  [*] --> draft: 사용자 생성
  draft --> ready: 서버 생성 결과 반영
  draft --> archived
  ready --> draft: 전체 다시 생성 Route Handler
  ready --> rendering: 서버 스냅샷
  ready --> archived
  rendering --> rendered: 서버 렌더 종료
  rendering --> ready: 서버 전부 실패
  rendered --> ready: 사용자 RPC 장면 수정
  rendered --> rendering: 서버 다시 렌더
  rendered --> archived
  archived --> [*]
```

### 5-2. 컷 `storyboard_cuts.status` (05장 11.3절)

```mermaid
stateDiagram-v2
  [*] --> proposed: 서버 쇼츠 후보
  proposed --> rendering: 서버 컷 렌더 요청
  rendering --> ready: 서버 완료
  rendering --> failed: 서버 실패
  failed --> rendering: 서버 재시도
  ready --> rendering: 서버 다시 렌더
```

### 5-3. 편집안 `edit_plans.status` (05장 12.4절)

```mermaid
stateDiagram-v2
  [*] --> proposed: 서버 INSERT
  proposed --> applied: 사용자 apply_edit_plan
  proposed --> rejected: 사용자 reject_edit_plan
  proposed --> expired: 서버 24시간 뒤 (제안)
  proposed --> failed: 서버
  applied --> undone: 사용자 undo_edit_plan
  rejected --> [*]
  expired --> [*]
  failed --> [*]
  undone --> [*]
```

### 5-4. 업로드 `uploads.status` (05장 3절)

```mermaid
stateDiagram-v2
  [*] --> draft
  draft --> checking: 서버 검사 시작
  draft --> canceled
  checking --> blocked: 서버 FAIL
  checking --> awaiting_confirm: 서버 WARN
  checking --> approved: 서버 PASS
  checking --> draft
  blocked --> draft: 사용자 수정
  blocked --> canceled
  awaiting_confirm --> approved: 사용자 확인
  awaiting_confirm --> draft
  awaiting_confirm --> canceled
  approved --> client_review: 서버 승인 요청
  approved --> scheduled: 사용자 예약
  approved --> canceled
  client_review --> scheduled: 고객 승인
  client_review --> draft: 고객 수정 요청
  client_review --> canceled
  scheduled --> uploading: 워커 실행
  scheduled --> canceled
  uploading --> published: 워커
  uploading --> failed: 워커
  uploading --> scheduled: 워커 재시도
  failed --> scheduled
  failed --> canceled
  published --> [*]
  canceled --> [*]
```

### 5-5. 고객 승인 `client_reviews.decision` (05장 3절)

```mermaid
stateDiagram-v2
  [*] --> pending: 서버 open_client_review
  pending --> approved: 고객 결정 서버 기록
  pending --> changes_requested: 고객 결정 서버 기록
  pending --> expired: 서버 만료
  pending --> canceled: 서버 재요청
  changes_requested --> [*]: 업로드는 draft로
  approved --> [*]
  expired --> [*]
  canceled --> [*]
```

## 6. 화면 흐름

읽는 법: 화살표는 사용자가 실제로 이동하는 순서입니다. 점선은 서버가 막거나 안내하는 분기(플랜·권한)입니다. 대시보드는 모두 `/dashboard/**` 아래에 있고, 편집기의 AI 패널과 검토 시트는 같은 경로 안에서 쿼리로 엽니다.

```mermaid
flowchart LR
  LP["/ 랜딩·3D 히어로"]
  LG["/login"]
  OT["/onboarding/terms<br/>첫 OAuth 로그인"]
  OA["/onboarding/ai"]
  HM["/dashboard 홈"]
  CHN["/dashboard/channels"]
  CON["/channels/id/clip-consent"]
  SBL["/dashboard/storyboards<br/>목록"]
  NEW["/storyboards/new<br/>5단계 마법사"]
  ED["/storyboards/id<br/>편집기 3단"]
  AIP["AI 편집 패널<br/>?plan= ?sheet="]
  RN["/storyboards/id/render<br/>마스터·쇼츠·언어판"]
  SNP["?snapshot=version<br/>읽기 전용"]
  PUB["/dashboard/publish/uploadId"]
  CLS["/dashboard/clients"]
  RV["/review/token<br/>고객 공개 화면"]
  BIL["/dashboard/billing"]
  PAY["/billing/success"]
  CHT["/dashboard/chat<br/>AI 채널 코치"]

  LP --> LG
  LG --> OT
  OT --> OA
  OA --> HM
  LG -->|"이메일 가입자는 건너뜀"| HM
  HM --> SBL
  HM --> CHN
  HM --> CHT
  CHN --> CON
  SBL --> NEW
  NEW -->|"스토리보드 만들기"| ED
  SBL --> ED
  ED --> AIP
  AIP -->|"적용"| ED
  ED --> RN
  ED --> SNP
  RN --> SNP
  RN -->|"업로드 준비"| PUB
  PUB -->|"고객 승인 요청"| RV
  RV -.->|"결정 후 알림"| PUB
  HM --> CLS
  CLS --> PUB
  HM --> BIL
  BIL --> PAY
  NEW -.->|"플랜 밖 길이 VD009 요금 안내"| BIL
```

## 7. 보안 경계

읽는 법: 바깥에서 안쪽으로 갈수록 신뢰가 높아지고, 마지막 방어선은 DB(RLS와 서버 RPC)입니다. 비밀키와 서명 개인키는 가장 안쪽 서버에만 있습니다. 공통 규칙은 `SECURITY_BASELINE.md`의 장 번호(§)로 표시했습니다. 이 제품의 `SECURITY.md`는 아직 비어 있어, 아래 값은 `04_API.md`, `05_DATA_MODEL.md`, `02_ARCHITECTURE.md`, `01_PRD.md`에서 가져왔습니다.

```mermaid
flowchart TB
  subgraph Z0["신뢰하지 않는 영역"]
    B["브라우저·봇·공개 링크 방문자"]
    CLN["대행 고객사<br/>토큰 링크만 소지"]
  end

  subgraph Z1["입구 Vercel"]
    H["보안 헤더·세션<br/>§18"]
    RL["레이트 리밋<br/>생성 60회 분 조직 §8 §21"]
    PUBR["공개 경로<br/>/review/token 30회 10분 IP 해시"]
  end

  subgraph Z2["앱 서버 신뢰"]
    RS["requireSession·zod<br/>org는 세션에서만 §11"]
    IDM["request_id 멱등<br/>선차감 후 enqueue"]
    TK["EdDSA 토큰 발급<br/>개인키는 Next.js만 §16"]
    EDL["EDL 허용 목록 검사<br/>VD023"]
  end

  subgraph Z3["데이터 최종 방어선"]
    RLS["RLS + guard 트리거<br/>컬럼 GRANT §1~4"]
    RPC["서버 RPC service_role<br/>EXECUTE 회수 §3"]
    ENC["encrypted_credentials<br/>평문 토큰 없음 §5"]
    STR["Storage video-media<br/>서명 URL 10분"]
    AUD["감사 로그 §9"]
  end

  subgraph Z4["워커와 AI 제한 신뢰"]
    OR["오케스트레이터<br/>서명 개인키 없음"]
    MW["media-worker<br/>AI 키 없음"]
    FA["FastAPI<br/>ElevenLabs 키 없음"]
  end

  subgraph Z5["외부 서비스"]
    EXT["fal·ElevenLabs·DeepL·LLM<br/>국외 이전 동의 §12 §16"]
    SNS["YouTube·Meta·TikTok·네이버 클립"]
    TOSS["Toss 웹훅<br/>서명 필수 §6"]
  end

  B --> H --> RL --> RS
  CLN --> PUBR --> RS
  RS --> IDM --> RPC
  RS --> TK
  RS --> EDL --> RLS
  RS --> RLS
  RPC --> AUD
  TK -->|"잡에 묶인 토큰"| OR
  TK --> FA
  OR --> RPC
  MW -->|"claim_jobs만"| RPC
  OR --> EXT
  OR --> SNS
  RPC --> ENC
  STR -.->|"조직 폴더 CHECK"| MW
  TOSS -->|"상태 동기화만"| RS
```

이 제품의 주요 위협과 대응(문서에 적힌 것만 모음. 정식 위협표는 `SECURITY.md` 작성 후 대체해야 합니다):

| 위협 | 대응(출처) | 공통 규칙 |
|---|---|---|
| 브라우저에서 크레딧·플랜 직접 변경 | 잔액은 `core.wallets`, 플랜은 엔타이틀먼트(SELECT만). 서버 함수 EXECUTE 회수(`05` 7절) | §3, §4 |
| 타 조직 채널 연결(OAuth state 위조) | `create_oauth_state` / `consume_oauth_state`가 org·user 확정(`05` 7절) | §7 |
| 웹훅 위조·결제 금액 조작 | 서명 필수, `payment_orders` 선저장 + `confirm_payment_order` 금액 대조(`05` 7절) | §6 |
| AI가 임의 명령 실행 | AI는 EDL만 만들고 서버가 허용 17종·권한·한도를 검사, 승인 전 변경 0(`01` SF-6) | §16 |
| 고객 승인 링크 탈취·추측 | 토큰은 32바이트, DB에는 sha256만, 사용자 SELECT에서 제외, 만료 1~336시간, IP 해시 30회/10분(`04` 2절, `05` 2.21절) | §8 |
| 브라우저가 AI·음성 제공자를 직접 호출 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 호출(`04` 1절) | §11, §16 |
| 타 조직 소재 경로 참조 | `storage_path` 첫 폴더 = org_id CHECK, `check_refs`가 교차 조직 참조를 VD002로 거부(`05` 4절, 11.2절) | §1, §4 |
| 원본 저작권·대가성 문구 누락 | clip은 `rights_basis` 필수(VD019), 제휴 링크가 있으면 문구 CHECK로 끌 수 없음(`01` 6절) | §12 |
| 개발용 로그인 노출 | 배포 빌드에서 `/api/dev/login` 404, 쿠키 역할 Mock 금지(`05` 7절 SM #6) | §17 |

## 문서 불일치

1. **`SECURITY.md`가 미작성 초안**입니다(자산, 위협, 제품별 수치가 모두 "작성 필요"). 7장 그림과 위협표는 다른 문서에서 모은 임시본이며, 세션 만료·CSP 도메인·감사 보존 기간 등 제품별 수치는 그림에 담지 못했습니다.
2. **서버 RPC 시그니처 차이**: `apply_storyboard_result`는 `04_API.md` 9.2절이 `(p_storyboard_id, p_ai_run_id, p_scenes, p_expected_version)`, `05_DATA_MODEL.md` 11.5절이 `(p_storyboard_id, p_scenes, p_ai_run_id)`입니다. `snapshot_storyboard`도 `04`는 `(p_storyboard_id, p_cut_kind, p_scene_ids, p_hook_text)`, `05`는 `(p_storyboard_id, p_cut_id)`이고, `delete_scene`의 인자도 다릅니다. 그림은 함수 이름만 썼고, `04`가 "(제안)", `05`가 SQL 정본(`1200_video.sql`)을 인용하므로 `05`를 우선으로 봅니다.
3. **`storyboards.version` 초깃값**: `04_API.md` 9.1절은 생성 직후 "version 1"이라 하고 `05_DATA_MODEL.md` 11.2절은 기본값 0입니다. 그림 4-1에는 숫자를 쓰지 않았습니다.
4. **`VD001`의 의미**: `04_API.md` 7절은 "필요한 연결 없음"인데 렌더 검사(9.2절)와 `02_ARCHITECTURE.md` 10.3절은 "모든 장면 소재 ready"에 씁니다. 그림 4-3은 후자(렌더 검사)를 따랐습니다.
5. **컷 종류와 화면비**: `05` 11장은 컷 `master`/`short`와 화면비 2종, 12장은 `variant`와 화면비 4종으로 넓혔습니다. 12장이 11장을 대체한다고 적혀 있어 그림 3·5-2는 12장 기준입니다.
6. **`/command` 경로**: `04` 9.1절의 `POST /api/storyboards/[id]/command`는 10.1절에서 `edit-plans`로 대체되었습니다. 그림은 `edit-plans`만 썼습니다.
7. **`Track` 값**: `04` 1절 "Track `A-F`"와 `/api/ai/script`의 `'B'|'C'|'D'`는 9장에서 `S`로 바뀐다고 적혀 있으나 앞 장 표는 그대로입니다(문서가 이미 인정). 그림은 S 기준입니다.

## 갱신 규칙

`README.md`, `01_PRD.md`~`05_DATA_MODEL.md`, `SECURITY.md` 중 이 그림의 근거 절을 고치면 이 파일의 해당 그림도 같은 변경에서 함께 고칩니다.
