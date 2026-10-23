# DIAGRAMS: Arch Studio UML 시각화

작성일 2026-10-23. 이 문서는 `arch-studio`의 기획 문서를 그림으로 옮긴 것이다. 정본은 각 문서이며 그림과 문서가 다르면 문서가 우선한다. GitHub에서 Mermaid가 바로 렌더링된다. 전체 플랫폼 구조는 `../_platform-core/ARCHITECTURE_DIAGRAMS.md`를 본다.

**제품 한 줄 정의**: 건축사무소·시공사 설계자가 Windows PC에 설치하는 데스크톱 앱(Tauri 2)에서 대지를 불러와 법규 엔벨로프, 매스, 실시간 판정, 기획설계 도면 시트(DXF·SVG·PDF)를 만들고, 클라우드(웹·FastAPI)에서 법규 검토, AI 렌더, 제안서 PDF를 크레딧으로 쓰는 제품이다. 영구 라이선스는 시리얼 번호로 PC 2대에 활성화한다.

**근거 문서**: `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `MCP.md`. 공통은 `../_platform-core/SECURITY_BASELINE.md`, `CORE_SPEC.md`, `AI_ARCHITECTURE.md`.

**표기**: 실선 화살표 = 호출·데이터 흐름, 점선 = 검증·참조·서명 확인, "(제안)" = 문서가 제안이라 한 값. Phase 2·3 항목은 이름에 `P2`, `P3`를 붙였다.

**다른 제품과 다른 점**: 이 제품은 웹 서비스가 아니라 설치형 앱이다. 사용자 데이터의 정본은 PC의 로컬 SQLite이고, 로컬 기능의 권한은 서버가 서명한 라이선스 파일을 앱의 Rust 코어가 검증해서 정한다. 클라우드 기능(검토, 렌더, 제안서, 규칙 팩, 업데이트)은 호출마다 서버가 `arch.org_features`로 판정한다. 그래서 2번과 7번 그림에 설치·배포 경계와 라이선스 검증 경로를 따로 그렸다.

| # | 그림 | UML 종류 | 근거 문서 절 |
|---|---|---|---|
| 1-A | 사용자와 기능 (MVP) | 유스케이스(flowchart) | 01_PRD 1장, 2장, 3장, 9.2절 |
| 1-B | 사용자와 기능 (Phase 2, 3, 열린 결정) | 유스케이스(flowchart) | 01_PRD 2장, 9.2절 |
| 2-A | 구성요소: 설치 앱과 클라우드 | 컴포넌트(flowchart) | 02_ARCHITECTURE 2장 구성도, 2.2절, 4절 |
| 2-B | 배포와 라이선스 검증 | 배치(flowchart) | 02_ARCHITECTURE 2.2절, 7절, 01_PRD 4.4절 |
| 3-A | 데이터 모델: 카탈로그와 라이선스 | 클래스(classDiagram) | 05_DATA_MODEL 2.1~2.7절 |
| 3-B | 데이터 모델: 조직 데이터와 AI 실행 | 클래스(classDiagram) | 05_DATA_MODEL 2.8~2.14절 |
| 3-C | 데이터 모델: 로컬 SQLite | 클래스(classDiagram) | 05_DATA_MODEL 2.16절 |
| 4-A | 시퀀스: 시리얼 구매에서 활성화까지 | 시퀀스 | 03_SCREENS_UX 2.6절, 04_API 5절, AR-F-017·018 |
| 4-B | 시퀀스: 데스크톱 로그인(딥링크 PKCE) | 시퀀스 | 02_ARCHITECTURE 9.2절, 03_SCREENS_UX 2.1절 |
| 4-C | 시퀀스: AI 렌더(선차감과 환불) | 시퀀스 | 04_API 6장, 05_DATA_MODEL 3절·7절, AR-F-013 |
| 4-D | 시퀀스: 업데이트와 규칙 팩 자격 | 시퀀스 | 02_ARCHITECTURE 7절, 04_API 3장, 03_SCREENS_UX 2.7절 |
| 5-A | 상태: 라이선스 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-B | 상태: 기기 활성화 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-C | 상태: AI 실행 | 상태 머신 | 05_DATA_MODEL 3절 |
| 5-D | 상태: 조직 기능 상태(org_features) | 상태 머신 | 05_DATA_MODEL 3절, 01_PRD 4.3절 |
| 6-A | 화면 흐름: 데스크톱 | flowchart | 03_SCREENS_UX 1.1절, 2장 |
| 6-B | 화면 흐름: 웹 | flowchart | 03_SCREENS_UX 1.2절, 2.6절 |
| 7 | 보안 신뢰 경계 | flowchart | 02_ARCHITECTURE 6절, 05_DATA_MODEL 7절, 01_PRD 5장·6장 |
| 8-1 | 로컬 앱과 MCP 후보 위치 | 컴포넌트(flowchart) | MCP.md 1~3절, 05_DATA_MODEL 2.16절, 04_API 1절 |
| 8-3 | 도구 등급과 노출 단계 | flowchart | MCP.md 2절, _platform-core/MCP_BASELINE.md 2절 |

> 이 제품의 `SECURITY.md`는 아직 템플릿 상태("작성 필요")라서 7번 그림은 `02_ARCHITECTURE` 6장(위험 #1~#14), `05_DATA_MODEL` 7장(위험 #4~#20), `01_PRD` 5·6장을 근거로 그렸다. 맨 끝 "문서 불일치" 참고.

---

## 1. 사용자와 기능

### 그림 1-A. MVP 기능

**읽는 법**: 사람 역할(설계자, 건축주, 운영자)과 기능 묶음이다. 기능 ID는 `AR-F-###`. 점선 상자 안은 서버가 있어야 하는 기능, 나머지는 PC 안에서 로그인 없이 동작하는 로컬 기능이다. 도면 엔진 묶음(AR-F-028~034)은 2026-10-16에 추가된 범위(PRD 9장)다.

```mermaid
flowchart LR
  USER(["설계자<br/>건축사무소 · 시공사"])
  CLIENT(["건축주<br/>제안서 수신"])
  OPS(["운영자<br/>빌드 · 규칙 팩 게시"])

  subgraph LOCAL["PC 안에서 동작 (로컬 기능)"]
    SITE["대지 불러오기<br/>AR-F-001"]
    ENV["법규 엔벨로프<br/>AR-F-002"]
    MASS["매스 모델러<br/>AR-F-003"]
    JUDGE["실시간 판정 패널<br/>AR-F-004~007"]
    PROG["체크리스트 · 면적표 · 공사비<br/>AR-F-011·012"]
    DRAFT["도면 시트: 배치도 · 면적도 · 일조사선<br/>AR-F-028~031"]
    EXPORT["파일 출력: DXF SVG PDF IFC glTF 3dm<br/>AR-F-016·038"]
    AUTO["P1: 평면 편집기 · 매스 자동 제안<br/>AR-F-032·033"]
  end

  subgraph CLOUD["서버가 필요한 기능"]
    REVIEW["클라우드 법규 검토<br/>AR-F-008"]
    CHAT["법규 질의 채팅 · 위키<br/>AR-F-009·010"]
    RENDER["AI 렌더<br/>AR-F-013"]
    PROP["제안서 PDF<br/>AR-F-014"]
    INTAKE["P1: 대화·음성 요구 입력<br/>AR-F-015·034"]
  end

  subgraph ACCT["계정과 라이선스"]
    BUY["시리얼 구매 · 발급<br/>AR-F-017"]
    ACT["기기 활성화 · 해제 (PC 2대)<br/>AR-F-018"]
    UPD["업데이트 권한 · 폴백<br/>AR-F-019"]
    CRED["크레딧 · 플랜 · 체험<br/>AR-F-020·021"]
  end

  USER --> SITE
  USER --> ENV
  USER --> MASS
  USER --> JUDGE
  USER --> PROG
  USER --> DRAFT
  USER --> EXPORT
  USER --> AUTO
  USER --> REVIEW
  USER --> CHAT
  USER --> RENDER
  USER --> PROP
  USER --> INTAKE
  USER --> BUY
  USER --> ACT
  USER --> UPD
  USER --> CRED
  PROP -.->|"제안서 PDF 수신"| CLIENT
  OPS --> UPD
```

### 그림 1-B. Phase 2, 3과 열린 결정

**읽는 법**: MVP 이후 기능이다. `P2`는 Phase 2, `P3`는 Phase 3, "열린 결정"은 PRD가 아직 정하지 않은 항목이다. 범위 밖 항목은 맨 아래에 따로 표시했다.

```mermaid
flowchart LR
  USER(["설계자"])

  subgraph P2["Phase 2"]
    LGPU["P2 로컬 GPU 렌더<br/>AR-F-022"]
    BYOK["P2 사용자 키 연결<br/>AR-F-023"]
    SKP["P2 SketchUp 매스 전송<br/>AR-F-024 (조건부)"]
    WL["P2 화이트라벨<br/>AR-F-025"]
    CONS["P2 시공 단계 문서<br/>AR-F-026"]
    LAYOUT["P2 AI 실 배치 초안<br/>AR-F-035"]
    ELEV["P2 입면 개략도<br/>AR-F-036"]
    DXFIN["P2 기존 DXF 평면 참조<br/>AR-F-037"]
  end

  subgraph P3["Phase 3"]
    SCAN["P3 스캔 도면 벡터화<br/>AR-F-037"]
  end

  subgraph OPEN["열린 결정"]
    DWG["DWG 입출력 D-22"]
    SKETCHUP["SketchUp 파일 D-11"]
  end

  subgraph OUT["범위 밖"]
    LEGAL["인허가용 설계도서"]
  end

  USER --> LGPU
  USER --> BYOK
  USER --> SKP
  USER --> WL
  USER --> CONS
  USER --> LAYOUT
  USER --> ELEV
  USER --> DXFIN
  USER --> SCAN
  USER -.-> DWG
  USER -.-> SKETCHUP
  USER -.-> LEGAL
```

---

## 2. 구성요소와 배포

### 그림 2-A. 설치 앱과 클라우드 구성요소

**읽는 법**: 위쪽 큰 상자가 사용자 PC에 설치된 앱, 아래쪽이 운영사 클라우드다. 무거운 계산(판정, 매스, 도면 생성)은 PC의 워커가 하고, 클라우드는 라이선스, 규칙 팩 배포, AI, 결제를 맡는다. 화면은 Tauri API를 직접 부르지 않고 `shell-bridge`를 거친다. 점선은 서명 검증이다.

```mermaid
flowchart TB
  subgraph PC["사용자 PC (Windows 10/11 x64, 설치형 앱)"]
    UI["WebView2 UI<br/>apps/desktop + features + ui"]
    EW["engine.worker<br/>rules · massing · geometry"]
    DW["drafting.worker<br/>drafting · io"]
    BR["shell-bridge<br/>NativeBridge · LicenseClient"]
    RUST["Rust 코어<br/>fs · local_db · secrets · device · updater · deeplink · export"]
    LIC["license.rs<br/>Ed25519 서명 검증"]
    DB[("로컬 SQLite<br/>사용자 데이터 정본")]
    KC[("OS 키체인<br/>세션 토큰")]
  end

  subgraph CLOUD["운영사 클라우드"]
    WEB["apps/web (Vercel)<br/>Route Handler · 계정 포털"]
    API["apps/api (Railway)<br/>FastAPI · LangGraph"]
    WORK["workers/arch-jobs (Railway)"]
    SB[("Supabase<br/>core + arch 스키마 · Storage")]
    DIFY["Dify arch-chat (공용)"]
    FAL["fal 이미지 생성"]
    WP["WeasyPrint (공용 private)"]
    TOSS["Toss Payments"]
  end

  UI -->|"postMessage"| EW
  UI -->|"postMessage"| DW
  UI --> BR
  BR -->|"invoke"| RUST
  RUST --> DB
  RUST --> KC
  RUST --> LIC
  LIC -.->|"라이선스 파일 서명 확인"| DB
  BR -->|"HTTPS Bearer"| WEB
  UI -->|"RLS 읽기 · Realtime"| SB
  WEB -->|"service RPC"| SB
  WEB -->|"EdDSA 서명 토큰"| API
  API --> DIFY
  API --> SB
  WEB -->|"결제 확정 웹훅"| TOSS
  WORK -->|"claim_jobs"| SB
  WORK -->|"잡 토큰"| API
  WORK --> FAL
  WORK --> WP
```

### 그림 2-B. 배포와 라이선스 검증 경로

**읽는 법**: 설치 파일이 사용자 PC까지 가는 길(왼쪽에서 오른쪽)과, 시리얼이 라이선스 파일로 바뀌어 PC에서 검증되는 길(아래)이다. 서버는 시리얼 원문을 저장하지 않고 SHA-256 해시만 저장한다. 업데이트 자격은 `build_date <= updates_until`로 정한다.

```mermaid
flowchart LR
  subgraph BUILD["빌드와 게시 (CI)"]
    TAG["태그 푸시<br/>desktop-release.yml"]
    SIGN["코드 서명 + 업데이트 서명"]
    REL[("arch-releases 버킷<br/>builds · rule-packs")]
    BROW["arch.builds · rule_packs 행<br/>status published"]
  end

  subgraph SERVER["서버 (Vercel + Supabase)"]
    DLP["웹 /download<br/>서명 URL"]
    UPS["GET /api/updates/...<br/>arch.eligible_build"]
    ISS["arch.issue_license<br/>serial_hash 저장"]
    ACTV["POST /api/license/activate<br/>arch.activate_license"]
    SGN["라이선스 파일 서명<br/>Ed25519 · kid"]
  end

  subgraph DEVICE["사용자 PC"]
    INST["NSIS 설치 프로그램<br/>WebView2 부트스트랩"]
    APP["설치된 앱"]
    LSTORE["license_store<br/>서명 파일 사본"]
    VER["license.rs 검증<br/>서명 · device_hash"]
    UPD["Rust updater<br/>업데이트 서명 확인"]
  end

  TAG --> SIGN --> REL --> BROW
  BROW --> DLP
  DLP -->|"내려받기"| INST --> APP
  APP -->|"시리얼 + device_hash"| ACTV
  ISS -.->|"주문 확정 후 이메일 시리얼"| APP
  ACTV --> SGN -->|"라이선스 파일"| LSTORE
  LSTORE --> VER
  VER -->|"로컬 기능 허용"| APP
  APP --> UPD
  UPD -->|"Bearer"| UPS
  UPS -.->|"자격 빌드만"| BROW
```

---

## 3. 데이터 모델

### 그림 3-A. 카탈로그와 라이선스 (서버 `arch` 스키마)

**읽는 법**: 상자가 테이블이고 안은 핵심 컬럼만이다. `licenses`는 구매한 조직(`org_id`)의 것이고 시리얼 원문은 저장하지 않는다. `license_activations`는 PC 한 대당 한 행이며 해제되면 되살리지 않고 새 행을 만든다. 접근 주체는 각 상자 아래 note에 적었다.

```mermaid
classDiagram
  class runtime_config {
    +text key PK
    +integer value_int
    +text note
  }
  class license_skus {
    +text code PK
    +integer price_krw
    +integer includes_updates_months
    +integer bonus_credits
    +integer max_activations
    +integer max_quantity
    +jsonb fallback_features
    +boolean is_active
  }
  class licenses {
    +uuid org_id
    +text sku_code FK
    +uuid order_id FK
    +text serial_hash
    +text serial_last5
    +text status
    +timestamptz purchased_at
    +date updates_until
    +integer max_activations
    +uuid_array extension_order_ids
  }
  class license_activations {
    +uuid org_id
    +uuid license_id FK
    +text source
    +text device_hash
    +text device_label
    +timestamptz activated_at
    +timestamptz last_seen_at
    +timestamptz deactivated_at
    +text deactivation_kind
  }
  class builds {
    +text version
    +text platform
    +text channel
    +text status
    +date build_date
    +text storage_path
    +text signature
    +text sha256
  }
  class rule_packs {
    +text version
    +text status
    +date basis_date
    +text storage_path
    +text sha256
    +text signature
    +text kid
    +timestamptz published_at
  }
  class rule_pack_changes {
    +uuid rule_pack_id FK
    +text title
    +text kind
    +date effective_from
    +text law_ref
  }
  class payment_orders {
    +uuid id
  }
  license_skus "1" --> "*" licenses : sku_code
  payment_orders "1" --> "0..1" licenses : order_id
  licenses "1" --> "*" license_activations : license_id
  rule_packs "1" --> "*" rule_pack_changes : rule_pack_id
  note for runtime_config "RLS 정책 없음. 서버(service)만 읽고 사용자에게는 RPC 결과만"
  note for license_skus "anon·authenticated가 is_active 행을 읽음. fallback_features 열은 제외"
  note for licenses "조직 멤버가 읽음. serial_hash order_id status_reason 열 제외. 쓰기는 issue_license·extend_updates·service만"
  note for license_activations "조직 멤버가 읽음. device_hash 열 제외. 쓰기는 activate_license·activate_plan_device·deactivate_activation만"
  note for builds "정책 없음. service만. 사용자는 업데이트 API 결과만"
  note for rule_packs "has_arch_access 사용자가 published·withdrawn 읽음. storage_path 제외. 쓰기는 service(CI 게시)"
  note for payment_orders "core.payment_orders. 코어 테이블 참조만 표시"
```

참고: `cost_catalogs`(개략 공사비 단가표)는 `builds`·`rule_packs`와 같은 게시 상태(draft, published, withdrawn)를 쓰며 RLS 정책이 없다. 컬럼이 많아 위 그림에서는 뺐다.

### 그림 3-B. 조직 데이터와 AI 실행 (서버 `arch` 스키마)

**읽는 법**: 위쪽 두 테이블은 사용자가 RPC로 저장하는 조직 데이터(표제란, 클라우드 사본)이고, 나머지는 AI 실행 기록 4종(`renders`, `reviews`, `intake_runs`, `proposals`)과 대지 조회 기록이다. AI 실행 테이블은 사용자 SELECT만 있고 쓰기는 service RPC(`start_ai_run`, `finish_ai_run`, `fail_ai_run`)만 한다. 공통 실행 컬럼(`request_id`, `status`, `credits`, `credit_ledger_id`, `job_id`)은 `renders` 칸 기준으로 적었다.

```mermaid
classDiagram
  class drafting_profiles {
    +uuid org_id
  }
  class cloud_projects {
    +uuid org_id
    +text local_id
    +text name
    +text storage_path
    +integer version
  }
  class renders {
    +uuid org_id
    +uuid request_id
    +text variant
    +text status
    +integer credits
    +uuid credit_ledger_id
    +uuid job_id
    +jsonb options
    +text output_path
    +boolean ai_label
    +timestamptz expires_at
    +timestamptz purged_at
  }
  class reviews {
    +text variant
    +text rule_pack_version
    +date application_date
    +text municipality_code
    +jsonb judgment
    +jsonb result
    +text disclaimer_version
  }
  class intake_runs {
    +text variant
    +text source
    +text input_kind
    +text input_text
    +uuid stt_job_id
    +text notice_version
    +jsonb result
    +timestamptz expires_at
  }
  class proposals {
    +text variant
    +text template_version
    +text content_path
    +text content_sha256
    +uuid_array render_ids
    +text_array sheet_paths
  }
  class site_lookups {
    +uuid org_id
    +date lookup_date
    +text pnu_hash
  }
  class jobs {
    +uuid id
  }
  class credit_ledger {
    +uuid id
  }
  renders --> jobs : job_id
  renders --> credit_ledger : credit_ledger_id
  reviews --> jobs : job_id
  intake_runs --> jobs : job_id
  proposals --> jobs : job_id
  renders "1" --> "*" renders : source_render_id 업스케일
  proposals "1" --> "*" renders : render_ids 12개 이하
  note for drafting_profiles "조직 멤버+엔타이틀먼트가 읽음. 쓰기는 upsert_drafting_profile(owner·admin). 건축주 이름 키 금지. 나머지 컬럼은 문서 미확인"
  note for cloud_projects "조직 멤버+엔타이틀먼트가 읽음. 쓰기는 save_cloud_project만. 기대 버전이 다르면 AR041"
  note for renders "조직 멤버+엔타이틀먼트가 읽기만. 쓰기는 start_ai_run·finish_ai_run·fail_ai_run(service)만"
  note for reviews "접근 규칙은 renders와 같음. 출처 없는 결과는 finish_ai_run이 차단 AR033"
  note for intake_runs "접근 규칙은 renders와 같음. 90일 뒤 purge_expired가 삭제"
  note for proposals "접근 규칙은 renders와 같음. 같은 내용·템플릿 재요청은 0크레딧 새 행"
  note for site_lookups "정책 없음. service 전용. 주소 원문 없이 HMAC 해시만"
  note for jobs "core.jobs. 코어 참조만 표시"
  note for credit_ledger "core.credit_ledger. 코어 참조만 표시"
```

### 그림 3-C. 로컬 SQLite (데스크톱, 사용자 데이터 정본)

**읽는 법**: PC 안의 테이블이다. 화면은 SQL을 직접 쓰지 않고 Rust 명령 `local_db_*`만 부른다. 아래쪽 4개(`license_store`, `rule_pack_cache`, `cost_catalog_cache`, `drafting_profile_cache`)는 서버 값의 서명 사본 또는 읽기 캐시다. 권한 판정에는 `license_store`의 서명 파일만 쓰고 `local_settings`는 쓰지 않는다.

```mermaid
classDiagram
  class projects {
    +TEXT id PK
    +TEXT name
    +TEXT site_label
    +TEXT cloud_project_id
  }
  class model_revisions {
    +TEXT id PK
    +TEXT project_id FK
    +INTEGER rev
    +INTEGER schema_version
    +TEXT engine_version
    +TEXT design_model
    +TEXT sha256
  }
  class sheets {
    +TEXT id PK
    +TEXT project_id FK
    +TEXT sheet_spec
    +TEXT annotation_overrides
    +INTEGER based_on_rev
  }
  class judgment_snapshots {
    +TEXT id PK
    +TEXT project_id FK
    +INTEGER rev
    +TEXT rule_pack_version
    +TEXT application_date
    +TEXT result
  }
  class exports {
    +TEXT id PK
    +TEXT project_id FK
    +TEXT sheet_ids
    +TEXT format
    +TEXT rule_pack_version
  }
  class render_items {
    +TEXT id PK
    +TEXT project_id FK
    +TEXT cloud_render_id
    +INTEGER ai_label
  }
  class local_settings {
    +TEXT key PK
    +TEXT value
  }
  class license_store {
    +TEXT activation_id PK
    +TEXT file
    +TEXT kid
    +TEXT issued_at
    +TEXT max_issued_at_seen
  }
  class rule_pack_cache {
    +TEXT version PK
    +TEXT sha256
    +TEXT signature
    +TEXT published_at
    +INTEGER pending_changes
  }
  class cost_catalog_cache {
    +TEXT version PK
    +TEXT items
    +TEXT fetched_at
  }
  class drafting_profile_cache {
    +TEXT org_id PK
    +TEXT profile
    +TEXT fetched_at
  }
  projects "1" --> "*" model_revisions
  projects "1" --> "*" sheets
  projects "1" --> "*" judgment_snapshots
  projects "1" --> "*" exports
  projects "1" --> "*" render_items
  note for license_store "서버가 서명한 라이선스 파일 사본. Rust license.rs만 읽고 검증. 권한 판정의 유일한 근거"
  note for local_settings "UI 설정과 org_features 표시용 캐시. 권한 판정 입력 금지"
  note for rule_pack_cache "서버 규칙 팩의 읽기 캐시. 서명과 published_at이 updates_until 이하인 팩만 엔진에 전달"
  note for cost_catalog_cache "서버 단가표 사본. 읽기 캐시"
  note for drafting_profile_cache "서버 표제란 설정 사본. 편집은 온라인에서만"
```

---

## 4. 핵심 시퀀스

### 그림 4-A. 시리얼 구매에서 기기 활성화까지

**읽는 법**: 결제 확정은 화면 리다이렉트가 아니라 Toss 웹훅(또는 서버 confirm)으로만 인정하며, 같은 후처리를 두 경로가 불러도 주문 id 멱등으로 한 번만 발급된다. 서버에는 시리얼 해시만 남고 원문은 이메일로만 간다. 거부 코드는 `AR###`.

```mermaid
sequenceDiagram
  autonumber
  actor U as 설계자
  participant APP as 데스크톱 앱
  participant BR as 시스템 브라우저(웹)
  participant WEB as web-api
  participant TOSS as Toss
  participant DB as Supabase arch
  participant MAIL as 이메일

  U->>APP: 라이선스 구매 클릭
  APP->>BR: openExternal 웹 pricing
  BR->>WEB: POST /api/checkout (license_sku)
  WEB-->>BR: 이메일 미확인이면 AR005 거부
  WEB->>TOSS: 결제창 생성
  TOSS->>WEB: POST /api/webhooks/toss (서명 검증)
  WEB->>DB: core.webhook_events 멱등 확인
  WEB->>DB: arch.issue_license(order_id) 주문 id 멱등
  DB-->>WEB: 시리얼 원문 (해시만 저장)
  WEB->>MAIL: 시리얼 발송 후 원문 폐기
  U->>APP: 시리얼 붙여넣기 + 이 PC에서 활성화
  APP->>WEB: POST /api/license/activate (Bearer, serial, device_hash)
  WEB->>WEB: 레이트 리밋 IP당 10회/시간
  WEB->>DB: arch.activate_license
  DB-->>WEB: AR002 무효, AR006 다른 조직, AR003 정지·환불
  DB-->>WEB: 활성 수가 2 이상이면 AR001 (409)
  WEB->>WEB: 라이선스 파일 Ed25519 서명
  WEB-->>APP: 라이선스 파일
  APP->>APP: Rust license.rs 서명·device_hash 검증 후 license_store 저장
```

### 그림 4-B. 데스크톱 로그인 (딥링크 PKCE)

**읽는 법**: 앱 안 웹뷰에서 OAuth를 하지 않고 시스템 브라우저를 쓴다. 복귀 URL(`archstudio://auth/callback`)은 Rust가 허용 목록으로 검사하고, 앱이 직전에 시작한 시도(10분 이내, 1회)일 때만 코드를 교환한다. 토큰은 키체인에만 저장한다. 루프백 방식(b)은 딥링크가 막힐 때의 대안이다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 설계자
  participant UI as 앱 화면
  participant BR as shell-bridge auth
  participant RUST as Rust deeplink.rs
  participant SB as 시스템 브라우저
  participant SUPA as Supabase Auth
  participant WEB as web-api
  participant KC as OS 키체인

  U->>UI: Google로 계속하기
  BR->>BR: PKCE verifier 생성 후 키체인 보관, 시도 시각 기록
  BR->>SUPA: signInWithOAuth (skipBrowserRedirect, redirectTo archstudio)
  BR->>SB: openExternal 로그인 URL
  SB->>SUPA: 사용자 로그인
  SUPA-->>SB: archstudio://auth/callback?code
  SB->>RUST: 딥링크 전달 (single-instance)
  RUST->>RUST: 스킴·호스트·경로 허용 목록과 길이 검사
  RUST->>BR: 콜백 이벤트
  BR->>BR: 진행 중 시도가 있고 10분 이내인지 확인 (아니면 무시)
  BR->>SUPA: exchangeCodeForSession(code)
  BR->>KC: 세션 토큰 저장 (localStorage 0건)
  BR->>WEB: POST /api/auth/finish (Bearer)
  WEB->>WEB: 제공자 허용 검사, 첫 로그인이면 개인 조직 + 체험 14일 + 가입 크레딧 30
  WEB-->>UI: next 온보딩 또는 프로젝트
```

### 그림 4-C. AI 렌더 (선차감, 폴링, 환불)

**읽는 법**: 데스크톱은 금액을 보내지 않고 서버가 단가표로 계산한다. 실행 행 생성, 잡 생성, 크레딧 선차감은 `arch.start_ai_run` 한 트랜잭션이다. `request_id`가 같으면 재전송해도 이중 차감되지 않는다. 실패하면 `refund:job:<job_id>` 키로 환불해 `refunded`가 된다. 도면·3D 원본은 보내지 않고 깊이·윤곽 이미지만 올린다.

```mermaid
sequenceDiagram
  autonumber
  actor U as 설계자
  participant APP as 데스크톱 앱
  participant WEB as web-api
  participant DB as Supabase arch + core
  participant W as arch-jobs 워커
  participant FAL as fal

  U->>APP: 렌더 요청 (프리셋)
  APP->>WEB: POST /api/uploads/sign (purpose render_input)
  APP->>WEB: POST /api/ai/render (request_id, 입력 경로, 프리셋)
  WEB->>WEB: 세션·member+·ai_render 기능·렌더 API 조직당 20회/분 확인
  WEB->>DB: arch.start_ai_run (service RPC, org는 세션에서 결정)
  DB->>DB: 엔타이틀먼트·동시 3건(AR030)·일일 상한(AR034) 검사
  DB->>DB: consume_credits 멱등 키 consume:arch:request_id
  DB->>DB: 실행 행 queued + enqueue_job
  DB-->>WEB: run_id, job_id, credits
  WEB-->>APP: 202 run_id
  W->>DB: claim_jobs
  W->>FAL: 이미지 생성 요청 (결과는 폴링)
  alt 성공
    FAL-->>W: 이미지
    W->>DB: finish_ai_run (출력 경로 검사, AI 표시, 90일 만료)
    DB-->>APP: Realtime 또는 상태 조회로 succeeded
  else 실패 또는 시간 초과
    W->>DB: fail_ai_run
    DB->>DB: refund_credits 키 refund:job:job_id, 상태 refunded
    DB-->>APP: 실패와 환불 표시
  end
```

### 그림 4-D. 업데이트와 규칙 팩 자격

**읽는 법**: 업데이트 만료(폴백) 상태를 가르는 두 검사다. 빌드는 `build_date <= updates_until`, 규칙 팩은 `published_at <= updates_until`일 때만 받는다. 앱은 서버 응답과 별개로 팩 서명도 확인한다. 만료되면 로컬 기능은 마지막 자격 버전으로 계속 되고 클라우드 검토는 `AR012`로 막힌다.

```mermaid
sequenceDiagram
  autonumber
  participant APP as 데스크톱 앱
  participant RUST as Rust updater · license.rs
  participant WEB as web-api
  participant DB as Supabase arch

  APP->>RUST: 시작 시 라이선스 파일 updates_until 확인
  RUST->>WEB: POST /api/license/refresh (하루 1회, 제안)
  WEB->>DB: org_features 판정 후 재서명
  WEB-->>RUST: 새 라이선스 파일 (연장되었다면 새 updates_until)
  RUST->>WEB: GET /api/updates/target/arch/current_version (Bearer)
  WEB->>DB: arch.eligible_build(org, platform, current)
  alt 자격 빌드 있음
    WEB-->>RUST: 서명 URL (짧은 수명)
    RUST->>RUST: 업데이트 서명 검증 후 설치
  else 자격 빌드 없음
    WEB-->>RUST: 자격 빌드 없음
  end
  APP->>WEB: GET /api/rule-packs
  WEB->>DB: arch.eligible_rule_packs
  WEB-->>APP: 자격 팩 목록 + 이후 개정 제목만
  APP->>WEB: GET /api/rule-packs/version/download
  WEB-->>APP: 서명 URL 또는 AR011 (자격 없음)
  APP->>RUST: 팩 매니페스트 서명 + published_at 확인
  RUST-->>APP: 폴백이면 배너 판정 기준 규칙 팩 버전과 이후 개정 건수 표시
```

---

## 5. 상태 머신

### 그림 5-A. 라이선스 (`licenses.status`)

**읽는 법**: 전이는 모두 서버(service)가 한다. 사용자가 바꾸지 못한다. `refunded`·`revoked`는 종료 상태이고 전이 시 활성 기기를 모두 해제한다. `suspended`는 기기를 남기되 활성화·refresh·클라우드 기능을 `AR003`으로 거부한다. 전이 검사는 `enforce_license_transition` 트리거다.

```mermaid
stateDiagram-v2
  [*] --> active : issue_license 주문 확정 웹훅
  active --> suspended : 운영자 service
  active --> refunded : 환불 웹훅 service
  active --> revoked : 운영자 service
  suspended --> active : 운영자 service
  suspended --> refunded : 환불 웹훅 service
  suspended --> revoked : 운영자 service
  refunded --> [*]
  revoked --> [*]
  note right of active : updates_until은 extend_updates로 증가만 가능
```

### 그림 5-B. 기기 활성화 (`license_activations`)

**읽는 법**: 한 행은 활성에서 해제로만 간다. 해제된 행을 되살리면 22023 오류이고, 같은 PC를 다시 쓰려면 새 행을 만든다. 해제 주체에 따라 `deactivation_kind`가 달라지고 셀프 해제만 30일 3회 한도(`AR004`)에 센다.

```mermaid
stateDiagram-v2
  [*] --> 활성 : activate_license 또는 activate_plan_device
  활성 --> 활성 : 같은 기기 재활성화 · refresh (last_seen_at 갱신)
  활성 --> 해제_self : owner 또는 admin 셀프 해제
  활성 --> 해제_support : 고객지원 service 해제
  활성 --> 해제_refund : 환불 전이 트리거
  활성 --> 해제_revoke : 회수 전이 트리거
  해제_self --> [*]
  해제_support --> [*]
  해제_refund --> [*]
  해제_revoke --> [*]
  note right of 활성 : 라이선스당 활성 2대 한도. 3번째는 AR001. 체험·월 구독은 1대
```

### 그림 5-C. AI 실행 (`renders`·`reviews`·`intake_runs`·`proposals`.`status`)

**읽는 법**: 전이를 바꾸는 주체는 service RPC뿐이다(`start_ai_run`, `finish_ai_run`, `fail_ai_run`, `reconcile_runs`). 시작 때 크레딧을 선차감하고, 실패하면 남은 차감액을 환불한 뒤 `refunded`가 된다. 전이 위반은 `enforce_run_transition`이 22023으로 막는다.

```mermaid
stateDiagram-v2
  [*] --> queued : start_ai_run 선차감 + 잡 생성
  queued --> running : 워커가 claim
  queued --> failed : fail_ai_run 또는 reconcile_runs
  running --> succeeded : finish_ai_run
  running --> failed : fail_ai_run 또는 reconcile_runs
  failed --> refunded : 남은 차감액 환불
  succeeded --> [*]
  refunded --> [*]
  note right of succeeded : 출력 경로·AI 표시·90일 만료 필수. 만료 후 purged_at 표시
```

### 그림 5-D. 조직 기능 상태 (`org_features.state`, 저장하지 않고 계산)

**읽는 법**: DB에 저장하는 값이 아니라 `arch.org_features(org)`가 날짜·라이선스·플랜으로 매번 계산하는 값이다. 상태에 따라 4.3절 표대로 기능 집합이 정해지고, 클라우드 기능은 호출마다 이 값으로 판정한다. 로컬 기능은 별도로 라이선스 파일이 정한다.

```mermaid
stateDiagram-v2
  [*] --> trial : 첫 로그인 부트스트랩 14일
  trial --> trial_expired : 14일 경과
  trial --> licensed : 영구 라이선스 활성화
  trial --> subscribed : 월 구독
  trial_expired --> licensed : 영구 라이선스 활성화
  trial_expired --> subscribed : 월 구독
  licensed --> licensed_fallback : updates_until 경과
  licensed_fallback --> licensed : 업데이트 연장 결제
  subscribed --> subscription_expired : 구독 만료
  subscription_expired --> subscribed : 재구독
  note right of licensed_fallback : 로컬 기능 유지, 규칙 팩 업데이트와 클라우드 검토 불가, AI 렌더는 크레딧으로 가능
```

---

## 6. 화면 흐름

### 그림 6-A. 데스크톱 화면

**읽는 법**: 설치 앱의 화면 이동이다. 첫 실행은 로그인, 온보딩, 프로젝트 목록 순이고, 프로젝트 안에서는 대지, 모델, 프로그램, 평면, 시트, 렌더, 제안서, 검토 화면을 오간다. 라이선스 구매와 크레딧 팩 구매는 앱 안 결제가 아니라 시스템 브라우저(웹)로 나간다. 영구 라이선스를 활성화한 PC는 로그인 없이 로컬 화면을 쓴다.

```mermaid
flowchart LR
  LOGIN["/login"]
  ONB["/onboarding<br/>약관 · 국외 이전 동의 · 체험 시작"]
  PROJ["/projects"]
  SITE["/projects/:id/site"]
  MODEL["/projects/:id/model<br/>모델러 + 판정"]
  PROG["/projects/:id/program"]
  PLANS["/projects/:id/plans (P1)"]
  SHEETS["/projects/:id/sheets"]
  RENDER["/projects/:id/render"]
  PROP["/projects/:id/proposal"]
  REVIEW["/projects/:id/review"]
  CHAT["/chat"]
  WIKI["/wiki"]
  LICENSE["/license"]
  CREDITS["/credits"]
  SET["/settings/drafting<br/>/settings/general"]
  WEB(["웹 브라우저<br/>pricing · 결제"])

  LOGIN --> ONB --> PROJ
  PROJ --> SITE --> MODEL
  MODEL --> PROG
  MODEL --> PLANS
  MODEL --> SHEETS
  MODEL --> RENDER
  MODEL --> REVIEW
  RENDER --> PROP
  SHEETS --> PROP
  PROJ --> CHAT
  PROJ --> WIKI
  PROJ --> LICENSE
  PROJ --> CREDITS
  PROJ --> SET
  LICENSE -->|"라이선스 구매 · 업데이트 연장"| WEB
  CREDITS -->|"팩 구매"| WEB
  WEB -.->|"시리얼 입력으로 복귀"| LICENSE
```

### 그림 6-B. 웹 화면

**읽는 법**: 웹에는 설계 화면이 없다. 랜딩, 가격, 다운로드, 계정 포털, 결제 결과만 있다. 결제 결과 화면은 확정 대기 상태를 보여 주고, 확정은 웹훅이 한다. 점선은 데스크톱 앱으로 돌아가는 길이다.

```mermaid
flowchart LR
  HOME["/ 랜딩 (3D 히어로)"]
  PRICE["/pricing"]
  DL["/download"]
  SAMP["/samples"]
  WLOGIN["/login"]
  CB["/auth/callback"]
  CHK["/checkout/result<br/>결제 확인 중"]
  LIC["/account/licenses"]
  DEV["/account/devices"]
  CR["/account/credits"]
  LEG["/legal/*"]
  APP(["데스크톱 앱"])

  HOME --> PRICE
  HOME --> DL
  HOME --> SAMP
  HOME --> LEG
  PRICE --> WLOGIN
  WLOGIN --> CB
  CB --> PRICE
  PRICE -->|"결제"| CHK
  CHK --> LIC
  LIC --> DEV
  LIC --> CR
  DL -.->|"설치"| APP
  LIC -.->|"시리얼 복사"| APP
```

---

## 7. 보안 신뢰 경계

### 그림 7. 보안 신뢰 경계와 통제

**읽는 법**: 왼쪽에서 오른쪽으로 갈수록 신뢰가 높다. 사용자 PC(앱과 파일)는 믿지 않는 영역이고, 서버가 판정한다. 점선 화살표는 위협이 노리는 지점, 실선은 통제다. `§n`은 `../_platform-core/SECURITY_BASELINE.md`의 장 번호다. 이 제품 `SECURITY.md`가 비어 있어 통제 목록은 02_ARCHITECTURE 6장, 05_DATA_MODEL 7장에서 가져왔다.

```mermaid
flowchart LR
  subgraph UNTRUST["신뢰하지 않는 영역"]
    ATK(["공격자<br/>다른 앱 · 웹페이지"])
    FILE["라이선스 파일 · 로컬 SQLite<br/>사용자가 고칠 수 있음"]
    IMP["가져오는 DXF · 3D 파일"]
    BUNDLE["설치 파일 번들"]
  end

  subgraph PCTRUST["PC 안의 통제"]
    LICV["Rust license.rs<br/>Ed25519 서명 + device_hash 검증"]
    DLK["Rust deeplink.rs<br/>허용 목록 + 1회 시도 + 10분"]
    FSG["Rust fs.rs<br/>대화상자 경로만, 20MB 상한"]
    KCH["OS 키체인<br/>토큰 보관"]
    CSP["CSP · 원격 URL 로드 금지"]
  end

  subgraph SRV["서버의 통제"]
    ROUTE["Route Handler<br/>세션에서 org 결정 · 레이트 리밋 §8"]
    FEAT["org_features<br/>호출마다 기능 판정"]
    RPC["service RPC 전용 쓰기 §3 §4<br/>AI 실행 4테이블 사용자 쓰기 없음"]
    CRD["크레딧 선차감 + request_id 멱등 + 실패 환불"]
    HASH["시리얼 SHA-256만 저장<br/>활성 2대 · 해제 30일 3회"]
    STO["Storage 경로 정규식 검사 §10<br/>서명 URL만"]
    WH["Toss 웹훅 서명 검증 + 멱등 §6"]
    AUD["감사 write_audit §9"]
  end

  subgraph SECRET["서버만 가진 비밀 §5 §19"]
    KEYS["service_role · LLM · fal 키<br/>라이선스 서명 개인키 · 업데이트 서명 개인키"]
  end

  ATK -.->|"가짜 code 주입"| DLK
  ATK -.->|"위조·복사 파일"| FILE
  FILE --> LICV
  IMP --> FSG
  BUNDLE -.->|"비밀 유출 시도"| KEYS
  LICV -.->|"로컬 기능만 판정"| ROUTE
  DLK --> KCH
  KCH --> ROUTE
  ROUTE --> FEAT
  ROUTE --> RPC
  RPC --> CRD
  RPC --> HASH
  RPC --> STO
  RPC --> AUD
  WH --> RPC
  KEYS -.->|"번들에 넣지 않음 §11"| BUNDLE
```

---

## 8. 에이전트 접근 층 (MCP)

**읽는 법:** 이 제품은 프로젝트 데이터의 정본이 데스크톱 로컬 SQLite이고, 서버 API는 라이선스·결제·크레딧 AI 작업뿐입니다. 그래서 **MVP에서는 원격 MCP를 열지 않고 노출 도구가 0개**입니다. 아래 그림은 "열 경우의 모양"입니다. 정본은 `MCP.md`, 공통 규칙은 `../_platform-core/MCP_BASELINE.md`입니다. 점선은 후보이거나 미결정(D-M#)입니다. 준비·확정 흐름을 가진 도구가 없어 시퀀스 그림(8-2)은 없습니다.

### 그림 8-1. 로컬 앱과 MCP 후보 위치

```mermaid
flowchart LR
  subgraph U["사용자 PC"]
    UI["Tauri 화면<br/>모델러 판정 패널"]
    EW["Web Worker 엔진<br/>판정 도면 로컬 0크레딧"]
    RS["Rust 명령<br/>local_db 라이선스 파일"]
    DB["로컬 SQLite 정본<br/>projects judgment_snapshots"]
    AGL["사용자 MCP 클라이언트<br/>AI 에이전트"]
  end

  subgraph MCPL["MCP 후보 로컬 stdio D-M1"]
    LT["도구 2개 읽기<br/>필드 허용 목록 출력"]
    OFF["기본 꺼짐<br/>앱 설정에서 허용"]
  end

  subgraph CLOUD["클라우드 기존 경로"]
    RH["Route Handler<br/>라이선스 규칙 팩 AI 작업"]
    RPC["arch RPC 크레딧 선차감<br/>start_ai_run"]
  end

  subgraph REM["원격 MCP"]
    NR["MVP 열지 않음<br/>Bearer 인증 T-C1 미반영 D-M2"]
  end

  UI --> EW
  UI --> RS
  RS --> DB
  UI -->|"사용자가 실행할 때만"| RH
  RH --> RPC
  AGL -.->|"stdio"| OFF
  OFF -.-> LT
  LT -.->|"읽기 전용 D-M1"| RS
  AGL -. "호출 안 함" .-> RH
  NR -. "후보 계정 수준 읽기 2개" .-> RH
```

### 그림 8-3. 도구 위험 등급과 노출 단계

```mermaid
flowchart TB
  subgraph MVP["MVP 노출 도구 없음"]
    N0["원격 MCP 미개방"]
  end
  subgraph LOC["후보 로컬 R1 D-M1 결정 후"]
    T1["arch_local_list_projects"]
    T2["arch_local_get_judgment_record"]
  end
  subgraph REMC["후보 원격 R1 보류 D-M2"]
    R1["규칙 팩 버전 읽기"]
    R2["라이선스 상태 읽기"]
  end
  subgraph NO["만들지 않음"]
    X1["도면 모델 시트 원본<br/>대지 좌표 주소 PNU"]
    X2["건축주 이름 연락처"]
    X3["렌더 검토 제안서 크레딧 AI"]
    X4["라이선스 활성화 시리얼 결제"]
    X5["파일 쓰기 내보내기 로컬 DB 수정"]
  end
  MVP --> LOC
  MVP -.-> REMC
  LOC -.->|"사람이 앱 화면에서 실행"| X3
```

## 문서 불일치

그림을 그리며 확인한 문서 사이의 어긋남과, 문서에 없어서 그리지 못한 것이다. 그림은 아래 "그림에 쓴 쪽"을 따랐다.

| # | 위치 | 내용 | 그림에 쓴 쪽 |
|---|---|---|---|
| 1 | `SECURITY.md` | 자산, 위협, 제품별 수치가 모두 "작성 필요" 템플릿이다. SECURITY_BASELINE §22는 제품별 작성을 요구한다 | 7번 그림은 02장 6절, 05장 7절, 01장 5·6장으로 대체. SECURITY.md 작성 후 다시 맞춘다 |
| 2 | `05_DATA_MODEL` 2.8, 2.9절 이후 | `drafting_profiles`, `reviews`, `intake_runs`, `proposals`는 절 제목과 일부 컬럼만 보이고 전체 컬럼표가 없다 | 문서에 적힌 컬럼만 그렸다. `drafting_profiles`는 `org_id`만 표시 |
| 3 | `05_DATA_MODEL` 2.5절 `cost_catalogs` | 컬럼이 확인되지 않아 3-A 그림에서 뺐다 | 3-A 아래 문장으로만 설명 |
| 4 | `05_DATA_MODEL` 6절 `core.payment_orders` | `kind`에 일회성(영구 라이선스) 값이 없어 코어 요청 C-1이 필요하다고 적혀 있다 | 4-A 그림은 C-1이 반영된 것으로 가정했다 |
| 5 | `01_PRD` 4.4절 vs 02장 2.2절 | 라이선스 파일의 `offline_valid_until`은 PRD 필드 목록에 없고 02장이 더한 제안 필드다 | "(제안)"으로 취급, 5-D 그림에는 쓰지 않음 |
| 6 | `01_PRD` 9.2절 vs 3장 | AR-F-032·033·034는 9.2절에서 MVP(P1)인데 3장 기능표 번호 범위에는 AR-F-028~038이 9장에만 있다 | 9장을 따라 1-A에 P1로 표기 |
| 7 | `01_PRD` 4.3절 | 월 구독 만료와 체험 만료의 "열람·내보내기만" 범위가 로컬 파일 서명 기준(`offline_valid_until`)과 서버 기준 두 곳에서 정해진다 | 5-D는 서버 계산 상태만 그렸고, 로컬 판정은 2-B에서 라이선스 파일 경로로 표시 |
| 8 | `04_API` 5절 | Toss 웹훅 서명 방식과 이벤트 id 필드는 "미확인"이다 | 4-A는 "서명 검증"과 멱등까지만 쓰고 방식은 쓰지 않음 |
| 9 | `02_ARCHITECTURE` 9.2절 | 딥링크가 Supabase Redirect URLs에 등록되는지, Windows에서 동작하는지 미확인(D-15 스파이크). 막히면 루프백(b) | 4-B는 (a) 딥링크 경로를 그렸다 |
| 10 | 코드 서명 | 인증서 종류·비용 미확인(T-D5). 서명 전에는 SmartScreen 경고가 뜬다 | 2-B에 "코드 서명"만 표시, 경고는 03장 2.1절 참고 |
| 11 | `MCP.md` 전체 / `04_API.md` 1절 | 원격 MCP 인증이 기댈 Bearer 검증(코어 요청 T-C1)이 아직 반영 전이라고 04장이 적고 있다. MCP.md는 이를 원격 MCP를 열지 않는 이유 중 하나로 썼다 | 8-1에서 원격 MCP를 "MVP 열지 않음"으로 표시 |
| 12 | `MCP.md` D-M1 / `02_ARCHITECTURE.md` 2.1절, `05_DATA_MODEL.md` 2.16절 | 로컬 DB는 Rust `local_db_*` 명령으로만 접근한다고 하나 명령의 구체 이름이 문서에 없다. 로컬 MCP 도구가 부를 읽기 명령을 특정할 수 없다 | 8-1은 "Rust 명령"으로만 표기, MCP.md는 "확인 필요"로 표시 |
| 13 | `MCP.md` D-M1 / `CLAUDE.md` 7절 | 로컬 stdio MCP를 별도 프로세스로 번들에 넣으면 "사이드카 동봉 금지"에 걸린다. 앱 Rust가 서버를 겸하는 구성은 문서에 없다 | 8-1은 로컬 MCP를 점선 후보로만 그림 |
| 14 | `MCP.md` D-M3 / `05_DATA_MODEL.md` 2.16절 | 화면 판정은 매번 재계산(D 분류)이고 저장된 `judgment_snapshots`는 기록용이라고 한다. 따라서 로컬 읽기 도구가 줄 수 있는 것은 "현재 판정"이 아니라 마지막 기록뿐이다 | 도구 이름을 `arch_local_get_judgment_record`로 하고 출력에 기록 시점 문구를 넣음 |

그리지 못한 것: 플랫폼 공통 AI 계층(Dify, LangGraph 내부 그래프 `arch.review` `arch.intake`)의 노드 구조는 이 제품 문서가 아니라 `AI_ARCHITECTURE.md`에 있어 상세 시퀀스로 그리지 않았다. 환불 시 라이선스 해제(웹훅 환불 후처리)와 법규 검토 시퀀스도 4번에 넣지 않았다(2.2절 표와 `AR012` 규칙으로 4-D에 일부 반영).

## 갱신 규칙

1. 정본은 `01_PRD.md` ~ `05_DATA_MODEL.md`다. 문서가 바뀌면 이 파일의 해당 그림을 같은 날 고치고 맨 위 작성일을 갱신한다.
2. 그림을 고치면 위 표의 "근거 문서 절"도 함께 확인한다. 기능 ID(`AR-F-###`), 오류 코드(`AR###`), 테이블·컬럼 이름은 문서에 있는 것만 쓴다.
3. 한 그림은 노드 25개 이하로 유지한다. 넘으면 3-A, 3-B처럼 나눈다.
4. 문서가 "제안"이라고 한 값은 그림에서도 "(제안)"을 붙인다. 확정되면 지운다.
5. 문서끼리 어긋나면 한쪽을 골라 그리고 위 "문서 불일치"에 기록한다.
6. `SECURITY.md`가 채워지면 7번 그림의 자산, 위협, 통제를 그 문서 기준으로 다시 그리고 불일치 1번을 지운다.
7. 수정 후 Mermaid 검증(`validate.py`)을 돌려 모든 블록이 통과하는지 확인한다.
