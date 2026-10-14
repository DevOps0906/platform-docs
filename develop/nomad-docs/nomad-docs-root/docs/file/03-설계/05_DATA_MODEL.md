# 05 데이터 모델: NOMAD Docs

작성일 2026-10-13. 정본 SQL은 모듈러 조각 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2300_docs.sql`(아래 `2300`)이고, 모놀리스 `supabase/monolith/migrations/0002_nomad_docs_domain.sql`은 변환본이다(8절). 표기와 규칙은 `docs/file/03-설계/공용코어/DB_CONVENTIONS.md`를 따른다. 근거 없는 수치·정책은 "제안"이다. 기능 ID는 `01_PRD.md` 3장, API는 `04_API.md`, 아키텍처는 `02_ARCHITECTURE.md`가 정본이다.

검증 결과(2026-10-13, PGlite, `D:/WorkSpace/platform/docs/products/_tools-sqlcheck`): 모듈러 core 0000~0009 + seed + 2300 적용 정순·역순 OK, 모놀리스 0001 + 0002 + seed OK, RLS 스모크 59/59(모듈러), 59/59(모놀리스), 권한 감사(PUBLIC EXECUTE 남은 제품 함수 0, search_path 없는 DEFINER 0, RLS 꺼진 테이블 0).

재검증(2026-10-14, 교차검증 반영 후): 모듈러 전 제품 체인(0000~0009 + seed + 1000~2300, 정순·역순·재실행) OK, 모놀리스 0001 + 0002 + seed OK, RLS 스모크 105/105(모듈러), 105/105(모놀리스), 권한 감사 0건. 추가 객체: `checklist_item_versions`, `project_code_counters`, `daily_credit_usage`, `generation_runs.progress`, 뷰 `project_pipeline`·`project_activity`, 함수 `cancel_generation`·`reconcile_generation_runs`·`report_generation_progress`·`charge_daily_cap`·`reserve_credits`.

## 1. 개요와 ERD

설계 원칙(`2300`:8-19 머리 주석, 기준서 2장).

| 원칙 | 데이터 모델에서의 구현 |
|---|---|
| 입력 한 번, 문서 여러 개 | 정본은 `projects.profile`, `checklist_answers`, `requirements`, `artifacts`, `line_items`, `parties`. 문서(`document_versions.content`)는 정본의 투영이며 정본이 바뀌면 `documents.needs_regeneration=true`(트리거 `mark_documents_stale`, `2300`:1100) |
| 효과 엔진은 결정적 | 체크리스트 효과로 생긴 행은 `source='checklist'`, `source_key='<item_key>#<effect_id>'`. 사용자가 고친 행은 `is_user_modified=true`가 되어 재적용 때 보존된다(트리거, `2300`:729) |
| 숫자는 DB가 계산 | 요구사항·산출물 코드(FR-001, SCR-001)는 트리거, 금액은 생성 컬럼 `line_items.amount_krw`, 합계·VAT는 뷰 `project_totals`, 문서번호는 `next_doc_number` |
| 버전은 불변 | `document_versions` append-only(DC003), 확정 문서는 title 포함 불변, 개정은 `create_revision`이 새 문서를 만든다 |
| 조직 격리 | 모든 테넌트 테이블에 `org_id` + 자식은 `(parent_id, org_id)` 복합 FK. 다른 조직 부모를 가리키는 행은 23503(또는 그 전에 42501) |
| 고위험 문서 | `doc_types`가 CHECK로 "고위험이면 template만, 고지문 버전 필수"를 강제(`2300`:84). 생성·확정 전에 `risk_acknowledgements` 확인(DC007) |

텍스트 ERD(들여쓰기 = 참조 방향, `[core]`는 코어 테이블 참조만).

```
[core] organizations
├── workspace_settings (1:1)
├── parties (kind: self | client | vendor | freelancer)
│   └── projects (client_party_id → parties, 복합 FK)
│       ├── checklist_answers (PK project_id + item_key) ──→ checklist_items [카탈로그]
│       ├── requirements (FR/NFR/CON 코드) ─┐
│       ├── artifacts (SCR/MS/DLV/TC/API/TBL) │
│       ├── line_items (amount_krw 생성 컬럼) │   view project_totals
│       ├── uploads ──→ [core] ai_documents │
│       ├── documents ──→ doc_types [카탈로그]
│       │   ├── document_versions (append-only) ←── doc_exports, signature_requests(Phase 3)
│       │   ├── approval_steps (Phase 2)
│       │   └── generation_runs ──→ [core] jobs, credit_ledger, ai_runs
│       └── trace_links (requirements → artifact | document_section | clause | line_item | acceptance_item)
├── doc_counters (조직·유형·연도)
├── risk_acknowledgements (조직·유형·고지문 버전)
├── integration_connections ──→ [core] encrypted_credentials
│   ├── field_mappings
│   ├── external_refs (내부 엔티티 ↔ 외부 엔티티 1:1)
│   └── sync_runs ──→ [core] jobs
└── webhook_endpoints ──→ [core] encrypted_credentials
    └── webhook_deliveries

카탈로그(플랫폼 공통, org 없음): doc_types ─ doc_type_versions, checklist_items, clauses(org_id null = 표준), runtime_config
```

테이블 28개(카탈로그 5, 워크스페이스 2, 프로젝트 정본 6, 문서 9, 연동 6). 뷰 1개(`project_totals`). 함수 34개(9절).

## 2. 테이블

공통: 모든 테이블은 RLS ON, `revoke all ... from public, anon, authenticated` 뒤 필요한 GRANT만 준다. UPDATE가 있는 테이블은 `core.set_updated_at` 트리거를 붙였다(`DB_CONVENTIONS.md` 5장). "표준 컬럼"은 `DB_CONVENTIONS.md` 3장 기준이다. 아래 컬럼 표는 `2300`에서 그대로 옮겼다(설명 = SQL 주석과 CHECK 허용 값).

### 2.1 카탈로그(플랫폼 공통)

#### `docs.doc_types`

목적: 문서 유형 카탈로그. 위험도·생성 방식·단계·단가·패키지 순서·문서번호 접두사·고지문 버전. 표준 컬럼: created_at, updated_at. 정의 `2300`:66.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `code` | text | 아니오 |  |  |
| `name` | text | 아니오 |  |  |
| `category` | text | 아니오 |  |  |
| `risk_level` | text | 아니오 | `'low'` | 값: low, high |
| `generation_mode` | text | 아니오 |  | 값: template, hybrid, ai |
| `phase` | text | 아니오 | `'mvp'` | 값: mvp, phase2, phase3 |
| `credits` | integer | 아니오 |  |  |
| `in_package` | text[] | 아니오 | `'{}'` | 포함되는 패키지 code 목록(예: outsourcing_basic, shorts_agency). 한 유형이 여러 패키지에 속할 수 있다(quote, sow, acceptance) |
| `package_order` | integer | 예 |  | 패키지 생성 순서(의존). 유형마다 한 값이라 패키지들이 같은 순서 체계를 쓴다(`01_PRD.md` 3.5.1절) |
| `number_prefix` | text | 아니오 | `'DOC'` | 문서번호 {TYPE}(01_PRD 3.6) |
| `notice_version` | text | 예 |  | 고위험 유형의 현재 고지문 버전(risk_acknowledgements 와 대조) |
| `is_active` | boolean | 아니오 | `true` |  |
| `sort_order` | integer | 아니오 | `100` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint doc_types_high_risk_template_check check (risk_level = 'low' or generation_mode = 'template')`; `constraint doc_types_high_risk_notice_check check (risk_level = 'low' or notice_version is not null)`

#### `docs.doc_type_versions`

목적: 유형별 버전(섹션 구조, 필수 입력, lint 규칙, 템플릿 경로). 게시 후 불변. 표준 컬럼: id, created_at, updated_at. 정의 `2300`:100.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `doc_type_code` | text | 아니오 |  | FK docs.doc_types. |
| `version` | integer | 아니오 |  |  |
| `structure` | jsonb | 아니오 | `'[]'::jsonb` | [{key,title,kind: fixed\|variable\|ai\|table, ...}] |
| `required_fields` | text[] | 아니오 | `'{}'` |  |
| `lint_rules` | jsonb | 아니오 | `'[]'::jsonb` |  |
| `template_ref` | text | 예 |  | 저장소 템플릿 경로(`templates/<code>/v<n>.html.j2`) |
| `checksum` | text | 예 |  | 템플릿 파일 sha256 |
| `published_at` | timestamptz | 예 |  | null = 초안(운영자 편집 가능) |
| `retired_at` | timestamptz | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (doc_type_code, version)`; `constraint doc_type_versions_structure_check check (jsonb_typeof(structure) = 'array')`; `constraint doc_type_versions_lint_check check (jsonb_typeof(lint_rules) = 'array')`

#### `docs.checklist_items`

목적: 체크리스트 항목과 결정적 효과(effects). 표준 컬럼: created_at, updated_at. 정의 `2300`:136.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `key` | text | 아니오 |  |  |
| `group_key` | text | 아니오 |  |  |
| `label` | text | 아니오 |  |  |
| `help` | text | 예 |  |  |
| `input_type` | text | 아니오 |  |  |
| `options` | jsonb | 아니오 | `'[]'::jsonb` |  |
| `effects` | jsonb | 아니오 | `'[]'::jsonb` | 결정적 효과 엔진 입력: [{when, create: requirement\|artifact\|line_item\|clause, ...}] |
| `applies_to` | text[] | 아니오 | `'{}'` | 비면 전체 project_type. dev 전용 항목은 `{web,app,ai,mixed,other}`, shorts_agency 항목은 `{content}`(`01_PRD.md` 3.3.1절) |
| `is_required` | boolean | 아니오 | `false` |  |
| `version` | integer | 아니오 | `1` | 트리거 `checklist_items_bump_version`이 관리(직접 지정 무시). 효과·선택지·입력 형식·적용 유형·필수 여부가 바뀌면 +1, 이력은 `checklist_item_versions` |
| `is_active` | boolean | 아니오 | `true` |  |
| `sort_order` | integer | 아니오 | `100` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint checklist_items_options_check check (jsonb_typeof(options) = 'array')`; `constraint checklist_items_effects_check check (jsonb_typeof(effects) = 'array')`

#### `docs.checklist_item_versions`

목적: 체크리스트 항목의 불변 이력(교차검증 #6, 2026-10-14). `checklist_items` INSERT·의미 있는 UPDATE마다 트리거가 1행을 넣는다. UPDATE·DELETE는 DC003. 정의 `2300`:172.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `key` | text | 아니오 |  | 항목 key |
| `version` | integer | 아니오 |  | 항목 version(PK key + version) |
| `label`, `input_type` | text | 아니오 |  | 그 버전의 값 |
| `options`, `effects` | jsonb | 아니오 |  | 그 버전의 값 |
| `applies_to` | text[] | 아니오 |  | 그 버전의 값 |
| `is_required` | boolean | 아니오 |  | 그 버전의 값 |
| `captured_at` | timestamptz | 아니오 | `now()` |  |

#### `docs.clauses`

목적: 조항 라이브러리. org_id null = 플랫폼 표준(MVP), 값 있음 = 조직 맞춤(Phase 2). 표준 컬럼: id, org_id, created_at, updated_at, status. 정의 `2300`:244.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 예 |  | FK core.organizations. |
| `code` | text | 아니오 |  |  |
| `doc_type_code` | text | 아니오 |  | FK docs.doc_types. |
| `title` | text | 아니오 |  |  |
| `body_template` | text | 아니오 |  | {{var}} 치환. AI 가 수정하지 않는다 |
| `variables` | text[] | 아니오 | `'{}'` |  |
| `is_required` | boolean | 아니오 | `false` |  |
| `source_note` | text | 예 |  | 출처(표준계약서 원문 조항 번호 등, D-8) |
| `version` | integer | 아니오 | `1` |  |
| `status` | text | 아니오 | `'draft'` | 값: draft, published, retired |
| `sort_order` | integer | 아니오 | `100` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

#### `docs.runtime_config`

목적: 운영 상한(동시 생성, 일일 크레딧 상한). 사용자 접근 없음. 표준 컬럼: updated_at. 정의 `2300`:280.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `key` | text | 아니오 |  |  |
| `value_int` | integer | 아니오 |  |  |
| `note` | text | 예 |  |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

#### `docs.daily_credit_usage`

목적: 일일 플랫폼 크레딧 사용량(KST 날짜). `start_generation`과 `reserve_credits`가 같은 트랜잭션에서 더하고 `runtime_config.daily_credit_cap`과 비교한다(교차검증 #11). 환불은 빼지 않는다. 사용자 접근 없음. 정의 `2300`:297.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `day` | date | 아니오 |  | PK, KST 날짜 |
| `credits` | bigint | 아니오 | `0` | 그날 차감 합계 |

### 2.2 워크스페이스

#### `docs.workspace_settings`

목적: 조직당 1행. 문서번호 서식, 기본 일단가, VAT, 직인 경로. 표준 컬럼: org_id, created_at, updated_at. 정의 `2300`:308.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `doc_number_format` | text | 아니오 | `'{TYPE}-{YYYY}-{SEQ:4}'` |  |
| `default_day_rate_krw` | bigint | 아니오 | `0` |  |
| `vat_rate_bp` | integer | 아니오 | `1000` |  |
| `seal_image_path` | text | 예 |  |  |
| `defaults` | jsonb | 아니오 | `'{}'::jsonb` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint workspace_settings_number_format_check check (doc_number_format like '%{SEQ%' and char_length(doc_number_format) <= 60)`

#### `docs.parties`

목적: 당사자(자사·거래처·협력사·프리랜서). 주민등록번호 컬럼 없음, 사업자번호는 10자리만. 표준 컬럼: id, org_id, created_at, updated_at, created_by, deleted_at. 정의 `2300`:345.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `kind` | text | 아니오 |  | 값: self, client, vendor, freelancer |
| `name` | text | 아니오 |  |  |
| `biz_reg_no` | text | 예 |  |  |
| `representative` | text | 예 |  |  |
| `address` | text | 예 |  |  |
| `contact_name` | text | 예 |  |  |
| `contact_email` | text | 예 |  |  |
| `contact_phone` | text | 예 |  |  |
| `notes` | text | 예 |  |  |
| `created_by` | uuid | 예 | `auth.uid()` |  |
| `deleted_at` | timestamptz | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`

### 2.3 프로젝트 정본

#### `docs.projects`

목적: 프로젝트와 공통 프로필. 표준 컬럼: id, org_id, created_at, updated_at, created_by, deleted_at, status. 정의 `2300`:413.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `client_party_id` | uuid | 예 |  |  |
| `name` | text | 아니오 |  |  |
| `code` | text | 예 |  |  |
| `project_type` | text | 아니오 | `'web'` | 값: web, app, ai, mixed, other, content(Phase 2 숏폼 대행, DC-F-046) |
| `status` | text | 아니오 | `'draft'` | 값: draft, active, delivered, archived |
| `profile` | jsonb | 아니오 | `'{}'::jsonb` |  |
| `checklist_version` | integer | 아니오 | `1` |  |
| `start_date` | date | 예 |  |  |
| `end_date` | date | 예 |  |  |
| `currency` | text | 아니오 | `'KRW'` |  |
| `created_by` | uuid | 예 | `auth.uid()` |  |
| `deleted_at` | timestamptz | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `constraint projects_client_fk foreign key (client_party_id, org_id) references docs.parties (id, org_id) on delete set null (client_party_id)`; `constraint projects_dates_check check (start_date is null or end_date is null or end_date >= start_date)`

#### `docs.checklist_answers`

목적: 체크리스트 답. 추출·연동 후보는 is_confirmed=false. 표준 컬럼: org_id, created_at, updated_at. 정의 `2300`:545.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `project_id` | uuid | 아니오 |  |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `item_key` | text | 아니오 |  | FK docs.checklist_items. |
| `value` | jsonb | 아니오 | `'null'::jsonb` |  |
| `source` | text | 아니오 | `'user'` | 값: user, extract, integration |
| `is_confirmed` | boolean | 아니오 | `true` |  |
| `answered_by` | uuid | 예 | `auth.uid()` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `primary key (project_id, item_key)`; `constraint checklist_answers_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`

#### `docs.requirements`

목적: 요구사항(FR/NFR/CON 코드 자동). 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:701.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 아니오 |  |  |
| `req_code` | text | 아니오 |  |  |
| `kind` | text | 아니오 | `'functional'` | 값: functional, nonfunctional, constraint |
| `title` | text | 아니오 |  |  |
| `description` | text | 예 |  |  |
| `priority` | text | 아니오 | `'should'` | 값: must, should, could, wont |
| `acceptance_criteria` | text | 예 |  |  |
| `source` | text | 아니오 | `'manual'` | 값: checklist, extract, manual, integration, minutes |
| `source_key` | text | 예 |  |  |
| `is_user_modified` | boolean | 아니오 | `false` |  |
| `status` | text | 아니오 | `'proposed'` | 값: proposed, accepted, rejected, changed |
| `sort_order` | integer | 아니오 | `100` |  |
| `created_by` | uuid | 예 | `auth.uid()` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `unique (project_id, req_code)`; `constraint requirements_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`

#### `docs.artifacts`

목적: 산출물 항목(화면, 마일스톤, 산출물 등). 표준 컬럼: id, org_id, created_at, updated_at, created_by. 정의 `2300`:788.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 아니오 |  |  |
| `kind` | text | 아니오 |  | 값: screen, milestone, deliverable, test_case, api, table |
| `code` | text | 아니오 |  |  |
| `name` | text | 아니오 |  |  |
| `attributes` | jsonb | 아니오 | `'{}'::jsonb` |  |
| `source` | text | 아니오 | `'manual'` | 값: checklist, extract, manual, integration, minutes |
| `source_key` | text | 예 |  |  |
| `is_user_modified` | boolean | 아니오 | `false` |  |
| `sort_order` | integer | 아니오 | `100` |  |
| `created_by` | uuid | 예 | `auth.uid()` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `unique (project_id, code)`; `constraint artifacts_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`

#### `docs.project_code_counters`

목적: 요구사항·산출물 코드 일련번호(프로젝트·접두사별, 교차검증 #8). `next_project_code`만 쓴다. 지운 번호를 다시 쓰지 않는다. 사용자 접근 없음. 정의 `2300`:651.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `project_id` | uuid | 아니오 |  | FK docs.projects(cascade) |
| `prefix` | text | 아니오 |  | FR, NFR, CON, SCR, MS, DLV ... |
| `last_no` | integer | 아니오 |  | 마지막으로 준 번호 |

#### `docs.line_items`

목적: 비용 항목. 금액은 생성 컬럼. 표준 컬럼: id, org_id, created_at, updated_at, created_by. 정의 `2300`:870.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 아니오 |  |  |
| `category` | text | 아니오 | `'dev'` | 값: dev, design, pm, qa, infra, license, etc, production, channel_ops, media(뒤 3개는 content용) |
| `name` | text | 아니오 |  |  |
| `unit` | text | 아니오 | `'man_day'` | 값: man_day, man_month, ea, lump, per_video, per_month, per_channel(뒤 3개는 content용) |
| `quantity` | numeric(10, 2) | 아니오 | `1` |  |
| `unit_price_krw` | bigint | 아니오 | `0` |  |
| `amount_krw` | bigint | 예 | `생성: round(quantity * unit_price_krw)::bigint` |  |
| `source` | text | 아니오 | `'manual'` | 값: checklist, extract, manual, integration, minutes |
| `source_key` | text | 예 |  |  |
| `is_user_modified` | boolean | 아니오 | `false` |  |
| `sort_order` | integer | 아니오 | `100` |  |
| `created_by` | uuid | 예 | `auth.uid()` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `constraint line_items_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`

#### `docs.uploads`

목적: RFP·녹음·참고 자료 메타데이터. 서버만 쓴다. 표준 컬럼: id, org_id, created_at, updated_at, created_by. 정의 `2300`:964.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 예 |  |  |
| `purpose` | text | 아니오 |  | 값: rfp, minutes_audio, minutes_text, reference, template_docx |
| `original_name` | text | 예 |  | 표시용. 경로에는 쓰지 않는다 |
| `storage_path` | text | 아니오 |  |  |
| `mime` | text | 아니오 |  |  |
| `bytes` | bigint | 아니오 |  | 20MB(flora 업로드 파서 교훈) |
| `sha256` | text | 아니오 |  |  |
| `parse_status` | text | 아니오 | `'pending'` | 값: pending, parsing, parsed, failed, deleted |
| `ai_document_id` | uuid | 예 |  | FK core.ai_documents. |
| `error` | text | 예 |  |  |
| `expires_at` | timestamptz | 예 |  | 녹음 원본 기본 24시간(D-11 제안) |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint uploads_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`; `constraint uploads_storage_org_check check (split_part(storage_path, '/', 1) = org_id::text)`

### 2.4 문서

#### `docs.documents`

목적: 문서. 사용자는 title만. 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:1004.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 아니오 |  |  |
| `doc_type_code` | text | 아니오 |  | FK docs.doc_types. |
| `title` | text | 아니오 |  |  |
| `status` | text | 아니오 | `'draft'` |  |
| `current_version` | integer | 아니오 | `0` |  |
| `doc_number` | text | 예 |  |  |
| `finalized_at` | timestamptz | 예 |  |  |
| `finalized_by` | uuid | 예 |  |  |
| `archived_at` | timestamptz | 예 |  |  |
| `supersedes_document_id` | uuid | 예 |  |  |
| `needs_regeneration` | boolean | 아니오 | `false` |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `constraint documents_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id)`; `constraint documents_supersedes_fk foreign key (supersedes_document_id, org_id) references docs.documents (id, org_id)`; `constraint documents_final_number_check check (status <> 'final' or (doc_number is not null and finalized_at is not null and current_version >= 1))`

#### `docs.document_versions`

목적: 문서 버전(append-only). 표준 컬럼: id, org_id, created_at, created_by. 정의 `2300`:1133.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `document_id` | uuid | 아니오 |  |  |
| `version` | integer | 아니오 |  |  |
| `doc_type_version` | integer | 아니오 |  |  |
| `content` | jsonb | 아니오 | `'[]'::jsonb` |  |
| `body_html` | text | 예 |  |  |
| `variables_snapshot` | jsonb | 아니오 | `'{}'::jsonb` |  |
| `inputs_hash` | text | 예 |  |  |
| `lint_result` | jsonb | 아니오 | `'{"errors": [], "warnings": []}'::jsonb` |  |
| `compliance_verdict` | text | 아니오 | `'skipped'` |  |
| `created_kind` | text | 아니오 |  | 값: generated, edited, imported |
| `generation_run_id` | uuid | 예 |  |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `unique (document_id, version)`; `constraint document_versions_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade`; `constraint document_versions_content_check check (jsonb_typeof(content) = 'array')`

#### `docs.trace_links`

목적: 요구사항 추적 연결. 표준 컬럼: id, org_id, created_at. 정의 `2300`:1231.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `requirement_id` | uuid | 아니오 |  |  |
| `to_kind` | text | 아니오 |  |  |
| `to_ref` | text | 아니오 |  | artifact/line_item id, 섹션 key, 조항 code, 검수 항목 key |
| `document_id` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint trace_links_requirement_fk foreign key (requirement_id, org_id) references docs.requirements (id, org_id) on delete cascade`; `constraint trace_links_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade`

#### `docs.generation_runs`

목적: 생성 실행(크레딧·잡 연결). 표준 컬럼: id, org_id, created_at, updated_at, created_by, status, idempotency_key. 정의 `2300`:1260.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 아니오 |  |  |
| `document_id` | uuid | 예 |  |  |
| `doc_type_code` | text | 예 |  | FK docs.doc_types. |
| `package_code` | text | 예 |  |  |
| `parent_run_id` | uuid | 예 |  | FK docs.generation_runs. |
| `job_id` | uuid | 예 |  | FK core.jobs. |
| `ai_run_id` | uuid | 예 |  | FK core.ai_runs. |
| `status` | text | 아니오 | `'queued'` |  |
| `credits_reserved` | integer | 아니오 | `0` |  |
| `credits_settled` | integer | 예 |  |  |
| `credit_ledger_id` | bigint | 예 |  | FK core.credit_ledger. |
| `idempotency_key` | text | 아니오 |  |  |
| `error` | text | 예 |  |  |
| `progress` | jsonb | 아니오 | `'{}'::jsonb` | 단계 진행(DC-F-048) `{stage, section_key, step, total, at}`. `report_generation_progress`만 갱신, Realtime으로 화면에 전달 |
| `created_by` | uuid | 예 |  |  |
| `queued_at` | timestamptz | 아니오 | `now()` |  |
| `started_at` | timestamptz | 예 |  |  |
| `finished_at` | timestamptz | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `constraint generation_runs_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`; `constraint generation_runs_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade`; `constraint generation_runs_target_check check ((document_id is not null and doc_type_code is not null) or (document_id is null and package_code is not null))`

#### `docs.doc_exports`

목적: 내보내기 결과. 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:1338.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `project_id` | uuid | 아니오 |  |  |
| `document_version_id` | uuid | 예 |  |  |
| `format` | text | 아니오 |  | 값: pdf, docx, zip, hwpx |
| `status` | text | 아니오 | `'queued'` |  |
| `storage_path` | text | 예 |  |  |
| `bytes` | bigint | 예 |  |  |
| `pages` | integer | 예 |  |  |
| `sha256` | text | 예 |  |  |
| `job_id` | uuid | 예 |  | FK core.jobs. |
| `credit_ledger_id` | bigint | 예 |  | FK core.credit_ledger. |
| `watermark` | boolean | 아니오 | `true` |  |
| `expires_at` | timestamptz | 예 |  |  |
| `error` | text | 예 |  |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint doc_exports_project_fk foreign key (project_id, org_id) references docs.projects (id, org_id) on delete cascade`; `constraint doc_exports_version_fk foreign key (document_version_id, org_id) references docs.document_versions (id, org_id) on delete cascade`; `constraint doc_exports_target_check check ((format = 'zip') = (document_version_id is null))`; `constraint doc_exports_storage_org_check check (storage_path is null or split_part(storage_path, '/', 1) = org_id::text)`; `constraint doc_exports_ready_check check (status <> 'ready' or storage_path is not null)`

#### `docs.doc_counters`

목적: 문서번호 일련번호. 표준 컬럼: org_id, updated_at. 정의 `2300`:1404.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `doc_type_code` | text | 아니오 |  | FK docs.doc_types. |
| `year` | integer | 아니오 |  |  |
| `last_no` | integer | 아니오 | `0` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `primary key (org_id, doc_type_code, year)`

#### `docs.risk_acknowledgements`

목적: 고위험 문서 고지 동의. 표준 컬럼: id, org_id. 정의 `2300`:1428.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `doc_type_code` | text | 아니오 |  | FK docs.doc_types. |
| `notice_version` | text | 아니오 |  |  |
| `acked_by` | uuid | 예 |  |  |
| `acked_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (org_id, doc_type_code, notice_version)`

#### `docs.approval_steps`

목적: (Phase 2) 검토·승인 단계. 표준 컬럼: id, org_id, created_at, updated_at, status. 정의 `2300`:1450.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `document_id` | uuid | 아니오 |  |  |
| `version` | integer | 아니오 |  |  |
| `step_no` | integer | 아니오 |  |  |
| `approver_user_id` | uuid | 아니오 |  |  |
| `status` | text | 아니오 | `'pending'` | 값: pending, approved, rejected |
| `comment` | text | 예 |  |  |
| `decided_at` | timestamptz | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (document_id, version, step_no)`; `constraint approval_steps_document_fk foreign key (document_id, org_id) references docs.documents (id, org_id) on delete cascade`

#### `docs.signature_requests`

목적: (Phase 3) 전자서명 요청. 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:1482.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `document_version_id` | uuid | 아니오 |  |  |
| `provider` | text | 아니오 |  |  |
| `external_id` | text | 예 |  |  |
| `status` | text | 아니오 | `'draft'` |  |
| `signed_pdf_path` | text | 예 |  |  |
| `sha256` | text | 예 |  |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint signature_requests_version_fk foreign key (document_version_id, org_id) references docs.document_versions (id, org_id) on delete cascade`

### 2.5 연동

#### `docs.integration_connections`

목적: 외부 연동 연결. 자격증명은 core.encrypted_credentials 참조만. 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:1516.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `provider` | text | 아니오 |  |  |
| `kind` | text | 아니오 |  | 값: crm, erp, automation, file |
| `status` | text | 아니오 | `'pending'` |  |
| `credential_id` | uuid | 예 |  | FK core.encrypted_credentials. |
| `external_account_id` | text | 아니오 | `''` |  |
| `sync_direction` | text | 아니오 | `'pull'` | 값: pull, push, both |
| `settings` | jsonb | 아니오 | `'{}'::jsonb` | 비밀값 금지(커서, 파이프라인 id 등) |
| `inbound_token_hash` | text | 예 |  | n8n 수신 토큰의 sha256(원문은 1회 표시 후 버림) |
| `last_synced_at` | timestamptz | 예 |  |  |
| `last_error` | text | 예 |  |  |
| `revoked_at` | timestamptz | 예 |  |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`; `constraint integration_connections_token_hash_check check (inbound_token_hash is null or inbound_token_hash ~ '^[0-9a-f]{64}$')`

#### `docs.field_mappings`

목적: 외부 필드 ↔ 내부 경로 매핑. 표준 컬럼: id, org_id, created_at, updated_at. 정의 `2300`:1583.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `connection_id` | uuid | 아니오 |  |  |
| `entity` | text | 아니오 |  | 값: party, project, line_item, document |
| `external_field` | text | 아니오 |  |  |
| `internal_path` | text | 아니오 |  |  |
| `transform` | text | 아니오 | `'none'` | 값: none, date, money, enum_map |
| `enum_map` | jsonb | 예 |  |  |
| `is_active` | boolean | 아니오 | `true` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (connection_id, entity, internal_path)`; `constraint field_mappings_connection_fk foreign key (connection_id, org_id) references docs.integration_connections (id, org_id) on delete cascade`; `constraint field_mappings_enum_check check ((transform = 'enum_map') = (enum_map is not null and jsonb_typeof(enum_map) = 'object'))`; `constraint field_mappings_document_owner_check check (entity <> 'document' or internal_path in ('document.title', 'document.doc_number', 'document.pdf_url', 'document.status'))`

#### `docs.external_refs`

목적: 내부 엔티티 ↔ 외부 엔티티 1:1. 표준 컬럼: id, org_id, created_at, updated_at. 정의 `2300`:1645.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `connection_id` | uuid | 아니오 |  |  |
| `entity` | text | 아니오 |  | 값: party, project, line_item, document |
| `internal_id` | uuid | 아니오 |  |  |
| `external_type` | text | 아니오 |  |  |
| `external_id` | text | 아니오 |  |  |
| `etag` | text | 예 |  |  |
| `last_synced_at` | timestamptz | 아니오 | `now()` |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (connection_id, entity, internal_id)`; `unique (connection_id, entity, external_id)`; `constraint external_refs_connection_fk foreign key (connection_id, org_id) references docs.integration_connections (id, org_id) on delete cascade`

#### `docs.sync_runs`

목적: 동기화 실행 기록. 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:1676.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `connection_id` | uuid | 아니오 |  |  |
| `entity` | text | 아니오 |  | 값: party, project, line_item, document |
| `direction` | text | 아니오 |  | 값: pull, push |
| `status` | text | 아니오 | `'queued'` | 값: queued, running, succeeded, failed, canceled |
| `job_id` | uuid | 예 |  | FK core.jobs. |
| `stats` | jsonb | 아니오 | `'{}'::jsonb` | {created, updated, skipped, conflicts} |
| `started_at` | timestamptz | 예 |  |  |
| `finished_at` | timestamptz | 예 |  |  |
| `error` | text | 예 |  |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `constraint sync_runs_connection_fk foreign key (connection_id, org_id) references docs.integration_connections (id, org_id) on delete cascade`

#### `docs.webhook_endpoints`

목적: (Phase 2) 발신 웹훅 대상. 표준 컬럼: id, org_id, created_at, updated_at, created_by, status. 정의 `2300`:1712.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | uuid | 아니오 | `gen_random_uuid()` |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `url` | text | 아니오 |  |  |
| `events` | text[] | 아니오 |  |  |
| `secret_credential_id` | uuid | 예 |  | FK core.encrypted_credentials. |
| `status` | text | 아니오 | `'active'` | 값: active, disabled, failing |
| `failure_count` | integer | 아니오 | `0` |  |
| `created_by` | uuid | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (id, org_id)`

#### `docs.webhook_deliveries`

목적: (Phase 2) 발신 기록. 표준 컬럼: id, org_id, created_at, updated_at, status. 정의 `2300`:1741.

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `id` | bigint | 아니오 |  |  |
| `org_id` | uuid | 아니오 |  | FK core.organizations. |
| `endpoint_id` | uuid | 아니오 |  |  |
| `event_type` | text | 아니오 |  |  |
| `event_id` | uuid | 아니오 |  |  |
| `payload_hash` | text | 아니오 |  |  |
| `status` | text | 아니오 | `'pending'` | 값: pending, delivered, failed |
| `attempts` | integer | 아니오 | `0` |  |
| `response_status` | integer | 예 |  |  |
| `next_attempt_at` | timestamptz | 예 |  |  |
| `created_at` | timestamptz | 아니오 | `now()` |  |
| `updated_at` | timestamptz | 아니오 | `now()` |  |

제약: `unique (endpoint_id, event_id)`; `constraint webhook_deliveries_endpoint_fk foreign key (endpoint_id, org_id) references docs.webhook_endpoints (id, org_id) on delete cascade`


## 3. 상태 전이

모든 전이는 트리거로 강제되므로 service_role 쓰기에도 적용된다(`DB_CONVENTIONS.md` 10장 (a)). 부수 효과가 있는 전이는 RPC가 맡는다.

### 3.1 projects.status (`2300`:444)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| draft | active, archived | owner/admin(`set_project_status`) | archived는 활성 프로젝트 수에서 빠진다(플랜 한도) |
| active | delivered, archived | owner/admin | 없음 |
| delivered | active, archived | owner/admin | 없음 |
| archived | active | owner/admin | 다시 활성화할 때 `projects_max` 재검사(DC006) |

위반은 DC001. 사용자는 `status` 컬럼 GRANT가 없어 직접 UPDATE하면 42501이다(스모크 테스트 통과).

### 3.2 documents.status (`2300`:1043)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| draft | generating, final, archived | `start_generation`(service), `finalize_document`(개정본 draft에 버전이 있을 때), `archive_document` | generating: 실행 1건 생성, 크레딧 선차감 |
| generating | review, draft | `finish_generation`(review), `fail_generation`(버전이 있으면 review, 없으면 draft) | review: 새 버전 저장, `needs_regeneration=false` |
| review | generating, final, archived | 재생성, `finalize_document`, `archive_document` | final: 문서번호 부여, 감사 로그 `docs_document.finalize` |
| final | archived | `archive_document` | 그 밖의 변경은 DC003. 수정은 `create_revision`(새 draft 문서, `supersedes_document_id`) |
| archived | 없음 | | |

`final`이면 CHECK로 `doc_number`, `finalized_at`, `current_version >= 1`이 반드시 있다(`2300`:1025).

### 3.3 generation_runs.status (`2300`:1306)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| queued | running, failed, canceled | 워커(service) | failed: 크레딧 환불은 `core.fail_job`이 원장 행으로 한다(이중 환불 방지, `2300`:2310) |
| running | succeeded, failed, canceled | 워커 | succeeded: `credits_settled = credits_reserved` |
| succeeded, failed, canceled | 없음 | | 종료 행의 금액·대상 변경은 DC003 |

문서당 활성 실행 1개, 프로젝트·패키지당 활성 패키지 실행 1개는 부분 유니크 인덱스로 보장한다(DC002, `2300`:1291).

### 3.4 doc_exports.status (`2300`:1374)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| queued | rendering, failed | 워커 | |
| rendering | ready, failed | 워커(렌더 서비스 응답) | ready: `storage_path` 필수(CHECK) |
| ready | expired | 정리 스케줄(파일 30일, 제안) | Storage 객체 삭제 |

### 3.5 integration_connections.status (`2300`:1550)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| pending | active, error, revoked | OAuth 콜백·어댑터(service) | |
| active | error, revoked | 어댑터(토큰 갱신 실패 = error), owner/admin(`revoke_integration`) | revoked: 자격증명 revoke, 대기 동기화 잡 취소, 감사 |
| error | active, revoked | 재연결 성공, 해지 | |
| revoked | 없음 | | 같은 외부 계정 재연결은 새 행(부분 유니크가 revoked 제외) |

위반은 DC009(연동 상태 불가).

### 3.6 상태 전이가 없는 상태 컬럼

| 테이블.컬럼 | 이유 |
|---|---|
| `requirements.status`(proposed, accepted, rejected, changed) | 사용자 분류값. 전이 강제 없이 CHECK만. 효과 엔진은 문서가 추적 중인 요구사항을 지우는 대신 `rejected`로 바꾼다 |
| `uploads.parse_status` | 서버만 쓴다(guard). 재처리 때 되돌아갈 수 있다 |
| `clauses.status`, `approval_steps.status`(Phase 2), `signature_requests.status`(Phase 3), `sync_runs.status`, `webhook_deliveries.status`, `webhook_endpoints.status` | service만 쓰거나(guard) 해당 RPC가 검사한다 |

## 4. RLS 정책

읽기 기본식은 `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')`(`DB_CONVENTIONS.md` 7장). 쓰기 정책을 준 테이블은 8.1절 "순수 콘텐츠"이고, 상태·번호·금액·외부 결과 컬럼은 컬럼 GRANT에서 빼고 트리거로 2차 잠금했다. `FOR ALL` 정책은 없다. 정책 안에서 `org_members`를 직접 조회하지 않는다.

| 테이블 | SELECT | INSERT | UPDATE | DELETE | authenticated GRANT |
|---|---|---|---|---|---|
| `doc_types` | `exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs'))` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `doc_type_versions` | `published_at is not null and exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs'))` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `checklist_items` | `exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs'))` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `clauses` | `status = 'published' and ((org_id is null and exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs'))) or (org_id is not null and core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')))` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `runtime_config` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | 없음 |
| `checklist_item_versions` | `exists (select 1 from core.current_org_ids() o where core.has_entitlement(o, 'docs'))` | 정책 없음(거부) | 정책 없음(거부, 불변 트리거 DC003) | 정책 없음(거부) | select |
| `daily_credit_usage`, `project_code_counters` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | 없음(DEFINER 함수만 쓴다) |
| 뷰 `project_totals`, `project_pipeline`, `project_activity` | `security_invoker`: 원본 테이블 RLS 그대로 | - | - | - | select |
| `workspace_settings` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin'])` | 정책 없음(거부) | select; insert (org_id, doc_number_format, default_day_rate_krw, vat_rate_bp, seal_image_path, defaults); update (doc_number_format, default_day_rate_krw, vat_rate_bp, seal_image_path, defaults) |
| `parties` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | `core.has_org_role(org_id, array['owner', 'admin'])` | select; insert (org_id, kind, name, biz_reg_no, representative, address, contact_name, contact_email, contact_phone, notes); update (kind, name, biz_reg_no, representative, address, contact_name, contact_email, contact_phone, notes, deleted_at); delete |
| `projects` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | `core.has_org_role(org_id, array['owner', 'admin'])` | select; insert (org_id, client_party_id, name, code, project_type, profile, start_date, end_date); update (client_party_id, name, code, project_type, profile, start_date, end_date, deleted_at); delete |
| `checklist_answers` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | select; insert (project_id, org_id, item_key, value); update (value, source, is_confirmed, answered_by); delete |
| `requirements` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | select; insert (org_id, project_id, kind, title, description, priority, acceptance_criteria, status, sort_order); update (title, description, priority, acceptance_criteria, status, sort_order); delete |
| `artifacts` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | select; insert (org_id, project_id, kind, name, attributes, sort_order); update (name, attributes, sort_order); delete |
| `line_items` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs')` | select; insert (org_id, project_id, category, name, unit, quantity, unit_price_krw, sort_order); update (category, name, unit, quantity, unit_price_krw, sort_order); delete |
| `uploads` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `documents` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | `core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin', 'member'])` | 정책 없음(거부) | select; update (title) |
| `document_versions` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `trace_links` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `generation_runs` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `doc_exports` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `doc_counters` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `risk_acknowledgements` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `approval_steps` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `signature_requests` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `integration_connections` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select (id, org_id, provider, kind, status, credential_id, external_account_id, sync_direction, settings, last_synced_at, last_error, revoked_at, created_by, created_at, updated_at) |
| `field_mappings` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs') / with check: core.has_org_role(org_id, array['owner', 'admin'])` | `core.has_org_role(org_id, array['owner', 'admin'])` | select; insert (org_id, connection_id, entity, external_field, internal_path, transform, enum_map, is_active); update (external_field, transform, enum_map, is_active); delete |
| `external_refs` | `core.is_org_member(org_id) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `sync_runs` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `webhook_endpoints` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |
| `webhook_deliveries` | `core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'docs')` | 정책 없음(거부) | 정책 없음(거부) | 정책 없음(거부) | select |

사용자 쓰기 정책을 준 테이블의 8장 조건 충족 근거:

| 테이블 | 성격(`DB_CONVENTIONS.md` 8.1) | 컬럼 GRANT에서 뺀 것 | 2차 잠금 |
|---|---|---|---|
| `workspace_settings` | 설정 콘텐츠(owner/admin) | 없음(`org_id`는 INSERT만) | 정책 with check |
| `parties`, `projects` | 순수 콘텐츠 | `id`, `org_id`(UPDATE), `created_by`, `projects.status` | `guard_org_columns`, 프로젝트 한도 트리거(DC006) |
| `checklist_answers` | 순수 콘텐츠 | `source`, `is_confirmed`는 서버 관리 | `guard_checklist_answer_write`(사용자는 source='user'·확정 행만) |
| `requirements`, `artifacts` | 순수 콘텐츠 | `req_code`/`code`, `source`, `source_key`, `is_user_modified` | `*_before_write`(코드 서버 부여, 출처 고정, 수정 표시) |
| `line_items` | 순수 콘텐츠(견적 단가는 사용자 입력이며 플랫폼 돈이 아님) | `amount_krw`(생성 컬럼), `source*` | `line_items_before_write` |
| `documents` | title만 | 나머지 전부 | `documents_before_update`(title 외 변경 42501) |
| `field_mappings` | 연동 설정(owner/admin) | `org_id`, `connection_id`, `entity`, `internal_path`(UPDATE) | `guard_field_mapping_columns`, 문서 엔티티는 push 표시 필드만(CHECK) |

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `projects_org_status_idx (org_id, status, updated_at desc) where deleted_at is null` | 대시보드 프로젝트 목록 |
| `requirements_project_idx (project_id, kind, sort_order)` | 요구사항 보드, 요구사항정의서 생성 |
| `requirements_source_idx (project_id, source, source_key)` | 효과 엔진 diff(목표 집합 대조) |
| `artifacts_project_idx`, `line_items_project_idx` | 화면목록·WBS·견적서 생성, 합계 뷰 |
| `checklist_answers_pending_idx (project_id) where not is_confirmed` | RFP 추출 후보 검토 화면 |
| `documents_project_idx (project_id, doc_type_code, created_at desc)` | 프로젝트 문서 목록 |
| `documents_org_number_uniq (org_id, doc_number)` | 문서번호 중복 방지 |
| `documents_one_open_revision_uniq (supersedes_document_id)` | 원본당 진행 중 개정본 1건 |
| `generation_runs_one_active_per_document_uniq`, `generation_runs_one_active_package_uniq` | DC002(동시 생성 차단) |
| `generation_runs_org_active_idx (org_id) where status in (queued, running)` | 조직 동시 생성 한도(기본 3) 계산 |
| `generation_runs_created_idx (created_at)` | 기간별 생성 조회(일일 상한은 2026-10-14부터 `daily_credit_usage` 1행 잠금으로 계산) |
| `uploads_expires_idx (expires_at)` | 회의 녹음 원본 만료 정리(D-11, 기본 24시간 제안) |
| `integration_connections_live_uniq (org_id, provider, external_account_id) where status <> 'revoked'` | 같은 외부 계정 중복 연결 방지 |
| `external_refs` 유니크 2개 | 외부 1건 ↔ 내부 1건(중복 pull로 거래처가 둘 되지 않음) |
| `sync_runs_one_active_uniq` | 연결·엔티티·방향당 동기화 1건 |
| `webhook_deliveries (endpoint_id, event_id)` 유니크 | 같은 이벤트 중복 발송 방지 |

예상 규모(제안): 조직당 프로젝트 50, 프로젝트당 요구사항 200·산출물 300·비용 항목 100, 문서당 버전 30. 모든 목록 조회는 프로젝트 단위 인덱스로 끝나므로 1만 조직까지 별도 파티셔닝 없이 운영한다.

## 6. 코어 참조

`core.*` 객체는 참조만 하고 ALTER하지 않는다(`DB_CONVENTIONS.md` 11장). 제품 스키마에 플랜·크레딧·잡·자격증명 테이블을 다시 만들지 않았다.

| 코어 객체 | 용도 |
|---|---|
| `core.organizations`, `org_members`(헬퍼 경유) | 테넌시. 정책은 `is_org_member`, `has_org_role`, `has_entitlement`, `current_org_ids`만 쓴다 |
| `core.apps`, `plans`, `app_entitlements`, `credit_packs` | 앱 `docs` 등록, 플랜 features 해석(`docs.org_features`, 서버 전용) |
| `core.consume_credits`, `credit_ledger` | `start_generation`의 선차감(멱등 키 `consume:docs:gen:<request_id>`), 생성 밖 차감은 `reserve_credits`(`consume:docs:<작업>:<request_id>`), `generation_runs.credit_ledger_id` |
| `core.enqueue_job`, `jobs`, `fail_job` | 생성·패키지·추출·회의록·렌더·동기화·웹훅 잡. 실패 환불은 `fail_job` |
| `core.encrypted_credentials`, `revoke_credential` | 연동 토큰, 웹훅 서명 비밀(평문 컬럼 없음) |
| `core.ai_documents`, `ai_runs`, `ai_routing_settings`, `ai_providers` | 업로드 색인 연결, 그래프 실행 연결, 기능별 라우팅 기본값 13행 |
| `core.wiki_pages` | 프로젝트 용어 위키(제품 테이블 없음, 페이지 종류는 코어 허용 값만 사용) |
| `core.write_audit`, `audit_log` | 확정, 보관, 개정, 고지 동의, 연동 해지, 상태 변경 |
| `core.set_updated_at`, `guard_privileged_write`, `is_privileged_session`, `is_service_caller` | 표준 트리거와 판정 |
| Storage `org-files`, `exports` | 업로드·직인(`<org_id>/docs/...`), 내보내기 결과(서명 URL 7일) |

AI·음성 테이블(`core.ai_*`, `core.voice_*`)은 참조만 하며 제품 전용 AI 테이블은 두지 않았다(`AI_ARCHITECTURE.md` 9장).

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

대상은 이식 원천 리뷰의 "높음" 14건(SellingDocs 4, flora v1 10)이다(`README.md` 2장). 이 절은 보안·데이터 7건을 다루고, 나머지 7건은 `02_ARCHITECTURE.md` 6절이 다룬다. 7 + 7 = 14.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reference/reviews/SellingDocs.md` 3장 #2 | `docs/reference/reviews/SellingDocs.md:49` | 크레딧 차감 주체·시점·원자성·환불·장부가 없다 | `start_generation`이 실행 행 + `core.consume_credits`(원자, 멱등 `consume:docs:<request_id>`) + `core.enqueue_job`을 한 트랜잭션으로 처리(`2300`:2050). 실패 환불은 `core.fail_job` 단일 경로. 사용자는 원장·지갑에 쓰기 불가(스모크 테스트) | `generation_runs`, DC-06-027(생성 요청 API·워커) |
| `docs/reference/reviews/flora.md` 3장 #1 | `docs/reference/reviews/flora.md:68` | LLM 엔드포인트 무인증 | DB 쪽: 생성 RPC는 service_role 전용(`is_privileged_session`) + 행위자(`p_actor`)의 조직 멤버십을 함수 안에서 다시 검사(`2300`:2044). 앱 쪽: `/api/ai/*`는 ai-gateway 서명 토큰(`02_ARCHITECTURE.md` 5장) | `start_generation`, `04_API.md` 2장 |
| `docs/reference/reviews/flora.md` 3장 #2 | `docs/reference/reviews/flora.md:69` | 결제 웹훅 서명 미검증으로 플랜 상승 | 제품 테이블에 플랜·결제 상태가 없다. 결제는 코어 Toss confirm + `webhook_events` 서명·멱등(`CORE_SPEC.md` 5, 6장). 연동 수신 웹훅도 `inbound_token_hash`(sha256만 저장)로 검증 | `integration_connections`, 코어 결제 |
| `docs/reference/reviews/flora.md` 3장 #3 | `docs/reference/reviews/flora.md:70` | `user_plans` `FOR ALL` 정책으로 셀프 업그레이드 | `FOR ALL` 정책 0개. 플랜 판정은 서버 전용 `docs.org_features`(EXECUTE service_role만). 프로젝트 한도는 INSERT 트리거(DC006) | `projects`, `org_features` |
| `docs/reference/reviews/flora.md` 3장 #4 | `docs/reference/reviews/flora.md:71` | 사용자 label을 파일명으로 써서 경로 조작 | `uploads.storage_path`, `doc_exports.storage_path`, `signature_requests.signed_pdf_path`, `workspace_settings.seal_image_path`는 서버가 만든 `<org_id>/docs/<purpose>/<uuid>.<ext>` 형식만 CHECK로 허용하고 첫 세그먼트가 `org_id`와 같아야 한다(`2300`:982). 원본 파일명은 표시용 `original_name`에만 | `uploads`, `doc_exports` |
| `docs/reference/reviews/flora.md` 3장 #5 | `docs/reference/reviews/flora.md:72` | 서버가 사용자 URL을 가져오는 SSRF, 렌더러의 외부 리소스 fetch | 웹훅 URL은 https + 사설·루프백 대역 차단 CHECK(`2300`:1712), 발송 직전 DNS 재검증(앱). 렌더는 서버 조립 HTML만, 렌더 서비스 `url_fetcher` 허용 목록(`SHARED_MODULES.md` 10장). 업로드는 Route Handler가 매직바이트 검사 후 service로만 INSERT | `webhook_endpoints`, `uploads` |
| `docs/reference/reviews/flora.md` 3장 #6 | `docs/reference/reviews/flora.md:73` | 클라이언트 비밀번호·localStorage로 Pro 판정 | 형식(pdf/docx/zip)·워터마크·문서 단계·프로젝트 수는 모두 `plans.features`를 서버가 읽어 판정(`start_generation`의 `doc_phase` 검사 DC006, 내보내기 형식은 Route Handler). 클라이언트 플래그로 바뀌는 컬럼이 없다 | `org_features`, `start_generation` |
| (참고) 02장 처리 | `docs/file/03-설계/02_ARCHITECTURE.md` 6절 | SellingDocs #1, #3, #4, flora #7, #8, #9, #10 | 런타임·배포·파이프라인 결함이라 02장에서 차단 | 02장 6절 |

## 8. 모놀리스와 모듈러의 차이

`DB_CONVENTIONS.md` 12장 기준으로 이 제품에서 달라지는 것만 적는다.

| 항목 | 모듈러(`2300_docs.sql`) | 모놀리스(`0002_nomad_docs_domain.sql`) |
|---|---|---|
| 스키마 | `docs` | `public` |
| apps 등록 | `schema_name='docs'` | `schema_name='public'`(같은 app id `docs`) |
| 코어 접두사 | `core.` | `public.`(이름·시그니처 동일) |
| 함수 PUBLIC 회수 | 파일 끝 `revoke execute on all functions in schema docs from public` | 이 파일이 만든 함수 34개만 이름 목록으로 회수(public 전체 회수는 코어 SECTION 10) |
| 플랜·크레딧팩·라우팅 기본값 | 조각 안 `@monolith-seed` 블록(`on conflict do nothing`, 코어 요청 C-3 전까지) | `seed.sql`이 소유(같은 값) |
| 카탈로그(doc_types 등) | 조각 25절 | 0002 말미(같은 본문) |
| Realtime | `docs.generation_runs`, `doc_exports`, `documents` 발행 | `public.` 같은 세 테이블 |
| 코어 축소판 | 해당 없음 | `0001_core_lite.sql`은 `MONOLITH_CORE_LITE.sql` 복사본에서 SECTION 9(affiliate)만 제거. Toss, 크레딧, OAuth state, 자격증명, 레이트 리밋, 잡, Storage, AI, 음성 유지 |
| 내부 ERP 읽기 | service 함수가 `erp.*`를 읽는다(같은 DB, 두 앱 엔타이틀먼트 필수, `02_ARCHITECTURE.md`) | `erp` 스키마가 없으므로 Phase 3 API 방식 |

동기화 방법: 모놀리스 파일은 손으로 고치지 않고 변환 스크립트로 다시 만든다(06장 작업). 변환 규칙은 0002 머리 주석과 같다.

## 9. 마이그레이션 파일

| 파일 | 줄 수 | 내용 |
|---|---|---|
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2300_docs.sql` | 3203 | 스키마 `docs`, 테이블 31, 뷰 3, 함수 43, 카탈로그 seed, 라우팅 기본값 13행 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 3373 | 코어 축소판(SECTION 9 제거) |
| `supabase/monolith/migrations/0002_nomad_docs_domain.sql` | 3121 | 도메인(public 변환본) |
| `supabase/monolith/seed.sql` | 90 | apps 1행, 플랜 free/pro/team(team은 Phase 2라 비활성), 크레딧팩 3종, 라우팅 기본값 |
| `supabase/monolith/tests/rls_smoke.sql` | 330 | RLS·권한 회귀 테스트 105항목(2026-10-13 59 + 2026-10-14 46) |

함수 목록.

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `start_generation(org, project, document, doc_type, package, parent_job, credits, idempotency_key, actor)` | service_role | 멱등 키 형식, 행위자 멤버십, 엔타이틀먼트, 유형 단계, 고지 동의, 동시 생성·일일 상한 | `generation_runs` | 42501, 22023, P0002, DC001~DC003, DC006, DC007, CR001 |
| `finish_generation(run, content, body_html, variables, inputs_hash, lint, verdict, ai_run)` | service_role | 실행·문서 상태, 2MB, verdict | `document_versions` | DC001, 22023 |
| `fail_generation(run, error)` | service_role | 실행 상태. 마지막 시도 실패에서만 호출 | `generation_runs` | DC001 |
| `cancel_generation(run)` | authenticated(시작한 member, owner/admin), service_role | queued만, 대기 자식 포함, 먼저 정리 | `generation_runs` | DC001, 42501, P0002 |
| `reconcile_generation_runs(org default null)` | service_role, 내부 | 잡 canceled·failed인데 실행이 남은 행 | int | 42501 |
| `report_generation_progress(run, stage, section_key, step, total)` | service_role | stage 목록, 0 ≤ step ≤ total, 종료 실행 무시 | void | 22023 |
| `reserve_credits(org, actor, credits, reason, ref_type, ref_id, idempotency_key, metadata)` | service_role | 사유·멱등 키 형식, 멱등 재호출, 일일 상한 | bigint(ledger_id) | DC006, CR001, 22023 |
| `charge_daily_cap(credits)` | 내부(`start_generation`, `reserve_credits`) | `daily_credit_usage` 행 잠금 | void | DC006 |
| `apply_checklist_effects(project, plan, expected_hash)` | service_role | 입력 해시 일치, 사용자 수정 보존 | jsonb(추가·갱신·제거·유지 수) | DC010 |
| `checklist_answers_hash(project)` | service_role | | text | |
| `next_doc_number(org, doc_type)` | service_role | 행 잠금 | text | |
| `upsert_external_ref(connection, entity, internal_id, external_type, external_id, etag)` | service_role | 연결 active, 같은 조직 엔티티 | `external_refs` | DC009, 42501 |
| `finalize_document(document, expected_version, ack_warn)` | authenticated owner/admin | 상태, 버전, 정본 최신성(`needs_regeneration`, 입력 해시), 필수 입력, lint 실행·오류·compliance, WARN 확인, 고지 | `documents` | DC001, DC003, DC004, DC005, DC007, DC008, DC010 |
| `archive_document(document)` | authenticated owner/admin | 상태 | `documents` | DC001 |
| `create_revision(document)` | authenticated owner/admin | 확정 문서만, 진행 중 개정본 1건 | `documents` | DC001, DC002 |
| `set_project_status(project, to)` | authenticated owner/admin | 전이, 한도 | `projects` | DC001, DC006 |
| `confirm_checklist_suggestions(project, keys)` | authenticated member 이상 | 1~200개 | 확정 수 | 22023 |
| `ack_risk_notice(doc_type, notice_version)` | authenticated owner/admin | 고위험 유형, 현재 고지문 버전 | `risk_acknowledgements` | 22023 |
| `revoke_integration(connection)` | authenticated owner/admin | 이미 해지 | `integration_connections` | DC009 |
| `decide_approval(...)` | authenticated(지정 승인자) | Phase 2 | `approval_steps` | DC001 |
| `next_project_code`, `org_features`, `enforce_project_limit`, `mark_documents_stale` | 트리거·서버 내부 | DEFINER, 비멤버 직접 호출 42501 | | |
| 트리거 함수 19개 | 트리거 | 전이·불변·2차 잠금, 체크리스트 version·이력, 답 형식 검사(22023) | | DC001, DC003, 22023, 42501 |

seed 내용(전부 제안값, 정본은 `01_PRD.md` 3·4장).

| 대상 | 내용 |
|---|---|
| `doc_types` | MVP 9종(quote, sow, req_spec, wbs, screen_list, dev_contract, acceptance, minutes, trace_matrix) 중 8종 활성. `dev_contract`는 D-3 법무 검토 전 비활성으로 넣고, 재실행해도 운영자가 바꾼 활성 값을 덮지 않는다. Phase 2/3 유형 비활성. `dev_contract`는 고위험 + `notice-contract-2026-10-13`. Phase 2 shorts_agency 7종(content_brief, video_service_contract, channel_access_mandate, brand_guide_ack, ad_disclosure_checklist, monthly_report, service_intro) 비활성. 계약서는 `notice-contract-2026-10-13`, 위임 동의서는 `notice-channel-mandate-2026-10-13` |
| `doc_type_versions` | MVP 유형별 v1(섹션 구조, 필수 입력, lint 규칙 코드, 템플릿 경로). shorts_agency 7종은 v1 초안(`published_at` null, 사용자에게 보이지 않음) |
| `checklist_items` | 대표 항목(구축 유형, 로그인·결제 등 기능, 산출물, 계약 조건)과 효과. 전체 목록과 효과 문법은 `01_PRD.md` 3장. content 항목 14개(`applies_to={content}`, 3.3.1절) |
| `clauses` | `dev_contract` 표준 조항 골격 9개, `video_service_contract` 18개(`vsc.*`), `channel_access_mandate` 5개(`cam.*`, 출처 미확인 D-15). 원문 출처·이용 조건이 미확인(D-8)이라 전부 `status='draft'`(사용자에게 보이지 않음). 법무 검토(D-3) 후 운영자가 본문을 채워 `published`로 바꾼다. 그 전에는 `dev_contract` 확정을 lint `L-REQUIRED-CLAUSE`가 막는다 |
| `runtime_config` | `max_active_generations_per_org`=3, `daily_credit_cap` 등 |
| 플랜·크레딧팩 | free(가입 50, 월 30), pro(19,900원, 월 400), team(59,000원, 월 1,500, Phase 2 비활성), 팩 100/300/1,000 |
| `ai_routing_settings` | 기능별 13행. `docs.minutes`(llm)와 `meeting_minutes`(stt), `dify.aux`는 오픈소스 강제 |

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경은 없다. 인증 단계는 코어 계약(`session_context`, 가입 트리거, `bootstrap_app_for_org`)을 그대로 쓰고, Stage A의 Mock 로그인은 로컬 Supabase에 시드한 실제 계정으로 로그인한다(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2장). C2에서 브리지 경로를 택하면 코어 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`의 `core.auth_identity_links`를 참조만 한다(제품 테이블 추가 없음, 06장 8.3절 C-13).

시드는 `scripts/dev/seed-users.mjs --app docs`(공통, AUTH_ROADMAP 2.3절)가 공통 페르소나를 만든 뒤 제품 훅 `scripts/dev/seed-users.docs.mjs`(제안)를 실행한다. 원격 호스트면 즉시 종료하고, 두 번 실행해도 크레딧이 두 번 지급되지 않는다. 이메일 도메인 `.test`, 비밀번호는 `DEV_SEED_PASSWORD`(출력하지 않음). 워크스페이스 행(`workspace_settings`, self 당사자)은 시드가 만들지 않고 첫 로그인의 `finishLogin`이 만든다(02장 9.2절. 실제 가입과 같은 경로를 검증하기 위해서다).

### 10.1 공통 페르소나 (AUTH_ROADMAP 2.2절)

| 키 | 만드는 경로 | 기대 `session_context('docs')` | docs에서 확인하는 것 |
|---|---|---|---|
| `owner` | `auth.admin.createUser`(`user_metadata.signup_app='docs'`) → 가입 트리거 `core.handle_new_user` | 개인 조직 owner, `entitled=true`, `plan_code='free'`, `credit_balance=80`(가입 pack 50 + 월 plan 30) | 01장 DC-F-001 Stage A 수용 기준, Free 한도(`projects_max` 2 → 3번째 `DC006`, PDF만·워터마크, 채팅 30턴/일), 온보딩(03장 7.3절) |
| `admin` | 생성 후 owner가 `invite_member(org, user, 'admin')` → 본인 `accept_invite` | owner 조직의 admin | `PATCH /api/workspace`·직인·문서번호 설정 가능, 소프트 삭제·복구(owner/admin), 연동 화면 접근 |
| `member` | 같은 방법(`member`) | owner 조직의 member | 프로젝트·체크리스트·생성·편집 가능, `PATCH /api/workspace` 403, 소프트 삭제 403, `/app/billing` 쓰기 불가 |
| `viewer` | 같은 방법(`viewer`) | owner 조직의 viewer | 모든 프로젝트 화면 읽기 전용(03장 1절), 쓰기 API 403, 생성 취소(`docs.cancel_generation`) 거부 |
| `outsider` | `signup_app='docs'`으로 생성(다른 개인 조직) | 자기 조직 owner | 교차 테넌트: owner 조직의 `projects`·`parties`·`documents`·`document_versions`·`doc_exports`·대화·위키·파이프라인 뷰 0행, 다른 조직 `project_id`로 채팅 404, 다른 컬렉션 RAG 42501, 커맨드 팔레트 검색 0건 |
| `no_app` | `signup_app` 없이 생성 | 모듈러: `entitled=false` → `finishLogin`이 `bootstrap_app_for_org('docs')` 1회 후 `entitled=true`. 모놀리스: 가입 트리거가 자동 부트스트랩해 처음부터 `entitled=true` | OAuth 첫 로그인 경로(B-1)를 A단계에서 미리 검증. 재로그인 3회 뒤 가입 크레딧 원장 행 1개. 온보딩 E2E(DC-06-057 (a))의 첫 로그인 |
| `suspended` | 생성 후 service_role로 `status=suspended` | 403 | `/suspended` 안내, 모든 API 403 |
| `ops` | 생성 후 service_role로 `platform_role=platform_admin` | 운영자 | `/admin/catalog`·`/admin/ops` 접근(일반 사용자 403, DC-F-040), 카탈로그 게시 감사 1행 |

`pending`은 approval 앱 전용이라 만들지 않는다(docs `signup_policy='open'`, `D:/WorkSpace/platform/docs/products/_supabase-modular/seed.sql:26`). Free·Pro의 `members_max`는 1이지만 이 키는 화면·서버의 구성원 초대 경로(Phase 2, C-5)가 읽고 코어 `invite_member`(`D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0004_core_security.sql:317`)는 검사하지 않으므로, 역할 페르소나를 Free 조직에 만들 수 있다. 역할 분기는 MVP에서도 RLS·API 권한으로 존재하므로 이 페르소나로 검증한다.

### 10.2 제품 훅 행 (docs 도메인)

AUTH_ROADMAP 8장의 docs "A 추가 페르소나"는 "-"(필수 추가 없음)이다. 아래 행은 Pro 게이팅과 온보딩 분기를 Mock으로 돌리기 위한 제안이다.

| 키 | 만드는 경로 | 기대 결과 | 확인하는 것 |
|---|---|---|---|
| `pro`(제안) | `signup_app='docs'`으로 생성 → service_role로 `core.subscriptions`에 pro 플랜 `trialing` 행 INSERT → `core.apply_subscription_transition(<sub>, 'active', 'dev_seed')`(`D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0002_core_billing.sql:265`) → `grant_credits`(bucket `plan`, 멱등 키 `dev-seed:pro:<org>`, 400) | `plan_code='pro'`, pack 버킷 50 유지, plan 버킷에 400 지급(정확한 합계는 월 크레딧 버킷 처리에 따르므로 시드 출력 표로 확인, 제안) | `projects_max` 50, PDF 워터마크 없음, DOCX·ZIP 요청 가능(DOCX는 C-1 전 403 `format_unavailable`), 발신 웹훅(Phase 2), 채팅 200턴/일. 실제 결제 경로는 DC-06-048이 Toss 테스트 키로 따로 검증한다 |
| 약관 동의 기록 | 모든 페르소나에 감사 행(제안: 행동 `terms.accept`, 약관 버전 `DOCS_TERMS_VERSION`)을 service_role로 만든다. 단 `no_app`은 만들지 않는다 | B 이후에도 `no_app`만 `/onboarding/terms`부터 본다 | 03장 7.3절 약관 단계 E2E와 기능 E2E를 분리 |
| 자사 정보 | `outsider`, `pro` 조직의 self 당사자에 테스트 회사명·사업자등록번호(체크섬이 맞는 가짜 번호, 제안)를 service_role로 채운다. `owner` 조직(admin·member·viewer가 함께 쓰는 조직)과 `no_app` 조직은 비워 둔다 | `owner`·`admin`은 첫 로그인 때 `/onboarding/company`를 본다(02장 9.6절). 다른 조직은 바로 `/app` | 문서 생성 E2E가 회사 정보 입력 없이 시작할 수 있다 |
| AI 국외 이전 동의 | 만들지 않는다(모든 페르소나 미동의로 시작) | 오픈소스 체인 | 동의 경로는 E2E(DC-06-057)가 `no_app`으로 직접 통과시킨다. 상용 체인이 필요한 테스트는 테스트 안에서 `set_ai_cross_border_ack`(owner)를 부른다 |
| 고위험 문서 고지 동의 | 만들지 않는다 | `dev_contract` 첫 생성 시 `DC007` 428 | 고지 모달(03장 3.22절) 경로. `dev_contract`는 seed에서 비활성이므로 테스트 안에서만 켠다(D-3) |

### 10.3 모놀리스와 모듈러 차이

| 항목 | 모듈러(`docs` + `core`) | 모놀리스(단독 `public`, 개발 폴더 기본) |
|---|---|---|
| `no_app` | `entitled=false`로 생성, `finishLogin`의 `bootstrap_app_for_org`가 메운다 | 앱 행이 1개라 가입 트리거가 자동 부트스트랩(`entitled=true`), `finishLogin`의 부트스트랩 단계는 무동작 |
| 시드 대상 | `--app`을 여러 번 줄 수 있다(두 번째 앱부터 service_role `bootstrap_app_for_org`). admin-suite ERP 연동(DC-06-055) 확인용으로 `--app docs --app erp`를 줄 수 있다(제안) | `--app docs` 한 번 |
| 스키마 | 코어 `core.*`, 제품 `docs.*` | 모두 `public.*`(`SUPABASE_DB_SCHEMA=public`) |
