# 06 에이전트 작업 계획: NOMAD Docs

작성일 2026-10-13. 작업 ID는 `DC-06-###`(약어 DC는 SQLSTATE 접두사와 같다, 설계 기준서 1장). 모델 기준은 `docs/file/03-설계/공용코어/DOC_TEMPLATE.md:23-34`(Fable: 결제·권한·RLS·데이터 모델, Opus: 기능·API·테스트, Sonnet: UI·문서·설정, Haiku: 보일러플레이트·문구·반복 점검). 이 폴더 문서는 파일 이름만 쓴다(`01_PRD.md:162` = `docs/file/02-요구사항/01_PRD.md:162`). `2300` = `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2300_docs.sql`.

경로는 앱 저장소 기준이며 아래 약어를 쓴다(`02_ARCHITECTURE.md:34-69`).

| 약어 | 실제 경로 |
|---|---|
| `web/` | `apps/nomad-docs/` (Next.js, Vercel) |
| `worker/` | `apps/nomad-docs-worker/` (TS 워커, Railway) |
| `api/` | `apps/api/` (공용 ai-service. docs 확장은 `app/ai/graphs/docs_*.py`, `app/ai/products/docs/`, `app/ai/tools/docs/`) |
| `tpl/` | `packages/docs-templates/` |
| `int/` | `packages/docs-integrations/` |

2026-10-14 확정 결정 22(`docs/reference/00_MERGE_ANALYSIS.md:30`)로 DC-06-014의 범위를 인증 Stage A(Mock 로그인)로 바꾸고 인증 단계 작업 3개(DC-06-063 Stage B, 064 C1 카카오, 065 C2 네이버, 8절)를 더했으며 007·057·059(수용 기준)도 함께 고쳤다.

작업 수는 65개(Phase 2 shorts_agency DC-06-060, 2026-10-14 추가 CRM 워크스페이스 DC-06-061·생성 진행 애니메이션 DC-06-062, 인증 단계 DC-06-063~065 포함)로 `DOC_TEMPLATE.md:266`의 15~40개 권장을 넘는다. 확정 결정 13~17(AI·Dify·3D·음성·LLM 이원화)이 MVP 필수이고, 디자인 시스템 4단계와 Phase 2 연동 4개가 더해졌다. 검증할 수 있는 크기(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다(flora-publishing 55개와 같은 판단, `D:/WorkSpace/platform/docs/products/flora-publishing/06_AGENT_PLAN.md:3`).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 경로는 한 작업만 쓴다(`D:/WorkSpace/platform/docs/products/_PRODUCT_AGENT_BRIEF.md:56-57`). 공용 설정(`web/package.json`, `web/next.config.ts`, 루트 레이아웃)은 DC-06-004만 수정하고, 다른 작업은 의존성 추가를 004 담당에게 요청하거나 같은 웨이브가 끝난 뒤 순차 반영한다 |
| Route Handler 분할 | `web/src/app/api/` 아래는 리소스 디렉토리마다 소유자가 다르다(2절 표). 하위 디렉토리를 다른 작업이 소유하면 상위 작업은 그 디렉토리에 파일을 만들지 않는다(예: `api/ai/`는 033, `api/ai/assist/`는 025) |
| 서버 공용 코드 | `web/src/lib/server/<영역>/`도 영역별 단일 소유(http 012, pricing·features 013, pii 015, totals 016, sanitize 028, ai 033, import 037, kpi 050). 다른 작업은 import만 한다 |
| SQL | DB 변경은 DC-06-001(Fable)만. 모듈러 `2300`이 정본이고 모놀리스 `0002`는 DC-06-002 변환 스크립트로만 다시 만든다(`05_DATA_MODEL.md:892`). 컬럼·함수가 필요하면 001에 요청 |
| 코어 불변 | `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*`, `packages/ai-gateway`, `packages/core-voice`, 공용 ai-service 원본, 공용 렌더 서비스 `services/render-weasyprint`(flora-publishing 소유), 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 코어 요청 |
| AI 서비스 경계 | `api/`의 공용 부분과 docs 설정은 006. docs 확장은 작업별: `products/docs/prompts/`·`context.py`·`templates_loader.py`는 022, `products/docs/rules/`·`compliance/docs.py`·`products/docs/lint/`는 021, `graphs/docs_extract.py` 023, `graphs/docs_minutes.py`·`products/docs/minutes_stt.py` 024, `graphs/docs_assist.py` 025, `products/docs/parsers/` 031, `products/docs/knowledge.py` 032, `tools/docs/` 034, `products/docs/wiki_config.py` 035 |
| 템플릿 패키지 | `tpl/`(템플릿·구조·lint 규칙 JSON·조항 골격·`sanitize-allowlist.json`·`checksums.json`)은 020 소유. `tpl/tests/`만 026 소유. 다른 작업은 읽기만 하며 게시 시 `doc_type_versions.checksum`과 일치해야 한다(`02_ARCHITECTURE.md:77`) |
| 디자인 시스템 순서 | 화면 작업(038~045)은 DC-06-011(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:48`). 컴포넌트는 `DESIGN_SYSTEM.md:84-94` 템플릿으로 1개씩 맡긴다 |
| 사람 작업 | DC-06-010(디자인 시스템 3단계, 비주얼 검토)은 사람이 수행한다. Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다(`DESIGN_SYSTEM.md:45`) |
| 장착 지점 | 편집기(040)가 채팅 패널·마이크 버튼 장착 지점을 제공하고, 043은 040 파일에 1줄 장착을 요청한다 |
| 테스트 소유 | 테스트 디렉토리는 테스트 작업이 소유한다(`supabase/tests/` 003, `web/tests/effects/` 019, `api/tests/docs/graphs/`·`api/eval/docs/`·`tpl/tests/`·`worker/tests/render/` 026, `web/tests/integration/` 056, `web/e2e/billing/` 048, `web/e2e/flows/` 057, `api/tests/docs/security/`·`web/e2e/ai/` 058). 기능 작업은 자기 디렉토리 안 단위 테스트(`*.test.ts`, `test_*.py`)만 쓴다 |
| 고위험 문서 | `risk_level='high'`(MVP `dev_contract`)는 template만, AI 조항 생성·수정 금지, 확정 전 고지 동의(`01_PRD.md:107`). D-3 법무 검토 전에는 `doc_types.is_active=false`로 배포한다(`01_PRD.md:398`). 이 규칙을 깨는 코드 경로를 만드는 작업은 수용 기준 미달이다 |

### 1.1 문서 간 불일치 정리 기록

작성 중 01~05와 SQL 사이에서 아래 불일치를 찾았고, 2026-10-13에 **모두 문서를 고쳐 "구현 기준" 열로 통일했다**(위치 열의 줄 번호는 수정 전 기준). 구현 에이전트는 이 표를 다시 판단하지 않고 01~05 본문을 따른다. DB 관련은 SQL(`2300`)이 정본(`05_DATA_MODEL.md:3`), API 관련은 04장이 정본(`03_SCREENS_UX.md:7`)이라는 기존 우선순위를 적용했다. 근거 없는 선택은 "제안"이다.

| # | 불일치 | 위치 | 구현 기준 | 처리 작업 |
|---|---|---|---|---|
| I-1 | `source_key` 구분자 `#` 대 `:` | `01_PRD.md:162`, `05_DATA_MODEL.md:16` vs `02_ARCHITECTURE.md:119` | `<item_key>#<effect_id>`(01·05가 둘, 제안) | 017, 018 |
| I-2 | effects jsonb 문법이 세 가지(객체 키별 배열 + `when` / `rules[{if,then}]` + `kind` / 배열 + `target`) | `01_PRD.md:177-193`, `02_ARCHITECTURE.md:98-105`, `2300`:3002, `05_DATA_MODEL.md:116` | seed가 실제로 들어 있는 `2300`:3002 형식(배열 원소 `{id, target, when?, ...}`)을 정본 스키마로 확정하고 JSON Schema를 `tpl/schema/effects.schema.json`에 둔다(제안) | 017, 020, 049 |
| I-3 | 엔진 함수 이름 `computeEffects` 대 `planEffects` | `01_PRD.md:160` vs `02_ARCHITECTURE.md:113` | `computeEffects`(목표 집합 계산, TS) 하나로 통일하고, 현재 행과의 diff·적용은 DB 함수 `apply_checklist_effects`가 한 트랜잭션으로 한다(02장 2.1절 수정) | 017 |
| I-4 | 입력 해시 sha256(카탈로그 checksum 포함) 대 md5(버전·일단가·답만) | `02_ARCHITECTURE.md:108` vs `2300`:1872-1887 | DB 함수 `checklist_answers_hash`가 정본(`p_expected_hash` 비교 주체) | 017, 018 |
| I-5 | VAT 반올림 `round` 대 `floor` | `01_PRD.md:96` vs `02_ARCHITECTURE.md:157` | 뷰 `project_totals`의 `round`(`2300`:950) | 016, 021 |
| I-6 | 문서번호 서식 토큰 `{PREFIX}-{YYYY}-{NNNN}` / `{TYPE}-{YYYY}-{NNN}` / `{TYPE}-{YYYY}-{SEQ:4}` | `01_PRD.md:89`, `:263`, `02_ARCHITECTURE.md:159`, `04_API.md:30`, `05_DATA_MODEL.md:191` | `{TYPE}-{YYYY}-{SEQ:4}`(DB 기본값과 CHECK `like '%{SEQ%'`, `05_DATA_MODEL.md:199`). 422 조건은 `{SEQ` 누락 | 015 |
| I-7 | 생성 API 레이트 리밋 20회/분 대 60회/분 | `01_PRD.md:369`, `:123` vs `04_API.md:16` | 20회/분(01장 수용 기준 "21번째 429"가 검증 대상) | 012 |
| I-8 | 조직 동시 생성 초과·일일 상한의 오류 코드: 01장은 409 `DC002`·503, SQL은 둘 다 `DC006` | `01_PRD.md:126` vs `2300`:2194, `:1985` | SQL `DC006`을 받고 Route Handler가 `details.reason`(`concurrency` 429, `daily_cap` 503)으로 HTTP를 나눈다(01장 DC-F-039 수정) | 012, 027 |
| I-9 | `docs.minutes`(llm) 라우팅: auto·강제 아님 대 open_source·강제 | `02_ARCHITECTURE.md:283` vs `supabase/monolith/seed.sql:57`, `2300`:3081, `05_DATA_MODEL.md:941` | seed(강제 오픈소스). D-11 권고 (a)와 같다(`01_PRD.md:477`) | 024, 058 |
| I-10 | 주민등록번호 패턴 `[1-4]`(외국인 `[5-8]` 별도 언급) 대 `[1-8]`, 오류 코드 `pii_rrn_blocked` 대 `pii_detected` | `01_PRD.md:247`, `:381`, `:87` vs `04_API.md:33`, `:252` | 패턴 `\d{6}-?[1-8]\d{6}`, 코드 `pii_detected`(04장 정본) | 015, 021 |
| I-11 | 녹음 고지 미확인 오류 403 `minutes_notice_required` 대 422 `recording_notice_required` | `01_PRD.md:113` vs `04_API.md:73`, `:252` | 422 `recording_notice_required`(04장 정본) | 024 |
| I-12 | 직인 이미지 형식 PNG/JPG 대 SQL CHECK `png|webp` | `01_PRD.md:89`, `04_API.md:31` vs `2300`:317 | SQL CHECK(`png|webp`)를 정본으로 하고 01·04장을 PNG/WebP로 고쳤다. JPG 업로드는 클라이언트에서 PNG로 변환 후 올린다(제안) | 001, 015 |
| I-13 | 토큰 파일 경로 `apps/nomad-docs/src/styles/tokens.css` 대 `apps/web/src/styles/tokens.css` | `02_ARCHITECTURE.md:58` vs `03_SCREENS_UX.md:674` | `apps/nomad-docs/src/styles/tokens.css`(03장의 `apps/web/` 표기를 모두 `apps/nomad-docs/`로 고침) | 009 |
| I-14 | 편집기 라우트 `(app)/documents/[id]` 대 `/app/projects/[pid]/documents/[did]` | `02_ARCHITECTURE.md:42` vs `03_SCREENS_UX.md:46` | URL은 03장, 파일은 `apps/nomad-docs/src/app/(app)/app/projects/[pid]/documents/[did]/`(02장 수정) | 040 |
| I-15 | 회의 녹음 상한 "200MB·3시간" 대 `VOICE_TOO_LONG`(제안 120분) 대 플랜 키 `minutes_max_minutes`(30/120/180) | `01_PRD.md:113` vs `04_API.md:76` vs `01_PRD.md:298` | 플랜 키가 상한, 파일은 200MB | 024 |
| I-16 | 업로드 확장자 `hwpx?` 포함 대 txt·md·docx·pdf | `04_API.md:73` vs `01_PRD.md:108` | hwpx 제외(D-5 Phase 3) | 031 |
| I-17 | `create_revision` 진행 중 개정본 있음 `DC002`가 04장에 없음 | `04_API.md:123` vs `2300`:2712, `05_DATA_MODEL.md:922` | SQL 기준(409 `DC002`) | 028 |
| I-18 | 05장 표 변환 잔재: `webhook_endpoints`에 가짜 행(`and` / `url`), `field_mappings` CHECK 잘림, 7절 작업 ID 빈칸(`DC-06-`) | `05_DATA_MODEL.md:672`, `:582`, `:828` | SQL 기준으로 05장 재생성, 7절 빈칸은 DC-06-027 | 반영 완료 |

### 1.2 타당성 교차검증 기록 (2026-10-13)

기획 작성과 분리된 검토 에이전트의 교차검증 결과다(구 `REVIEW_CROSSCHECK.md`, 제품 폴더 구조를 다른 제품과 맞추려고 이 절로 옮김). 아래 "반드시 고칠 것"은 출시 전 조건이다.

검토자: 기획 작성에 참여하지 않은 독립 검토 에이전트(Opus 5.5, 고문 역할. 사용자 요청으로 Fable 대신 Opus 사용). 저장소 파일은 수정하지 않았고, 보안 탐침은 작업 공간 밖의 PGlite 스크립트로만 실행했다. [검증]은 직접 실행하거나 코드를 읽어 확인한 사실, [판단]은 검토자의 추론 또는 미확인 외부 사실이다. 줄 번호는 검토 시점 기준이다.

#### 1.2.1 종합 판정: 조건부 통과

DB 기본 방어는 튼튼하다. 다만 핵심 약속을 깨는 빈틈이 SQL에서 실제로 재현되어, 출시 전 수정을 조건으로 건다.

| 구분 | 내용 |
|---|---|
| DB 기본 방어 [검증] | SQL 체커 12개 파일 OK, RLS 스모크 모듈러·모놀리스 각 59/59 통과. 권한 감사(PUBLIC EXECUTE, search_path 누락, RLS 꺼짐) 0건. 다른 조직 접근(복합 FK, `project_totals`, 사용자 RPC 7종)은 탐침에서 모두 차단 |
| 재현된 핵심 빈틈 [검증] | 계약서 법무 게이트(D-3)가 seed에서 이미 꺼져 있음, 낡은 문서·lint 미실행 편집본도 확정됨, 대기 중 생성 잡 취소 시 실행·문서가 영구 정지, 버전 전달 뒤 환불되는 경로, 카탈로그 버전 관리 부재로 효과 엔진 결정성 미보장 |
| 사업 [판단] | MVP 범위(문서 8종 + RAG·채팅·위키 + 회의 녹음·음성 + 3D 히어로, 작업 59개)가 1인 창업자의 첫 검증용으로 과대. 공용 렌더 서비스가 아직 없음(PDF도 다른 제품에 의존). 단가가 플랫폼 원가표보다 낮게 잡힘 |

#### 1.2.2 발견 사항

| # | 영역 | 심각도 | 위치 | 문제 | 권고 수정 |
|---|---|---|---|---|---|
| 1 | 문서정합성·법률 | 높음 | `2300_docs.sql:2532`, `:2548-2552`, 모놀리스 `0002:2525` / `01_PRD.md:384`, `06_AGENT_PLAN.md:32`, `CLAUDE.md:20` | [검증] seed에서 `dev_contract`가 `is_active=true`. `on conflict do update`가 `is_active`를 덮어써서 운영자가 꺼도 마이그레이션을 다시 돌리면 켜진다. 문서는 "D-3 전 false" | seed를 `false`로, upsert 갱신 대상에서 `is_active` 제외. RLS 스모크에 "D-3 전 계약서 생성 거부" 추가 |
| 2 | DB보안·정합 | 높음 | `2300:2180-2241`, `03_SCREENS_UX.md:115`, `04_API.md:60` | [검증] 단가 변경으로 `needs_regeneration=true`인 견적서도 확정됨. service INSERT 편집 버전은 lint 기본값(빈 오류)이라 `finalize_document`를 통과. 편집 후 lint 실행 주체가 04장에 없음 | `finalize_document`에 `needs_regeneration=false` 검사, `inputs_hash`와 현재 정본 해시 일치 요구, lint 실행 표시 컬럼 필수화, 편집 저장 API에 lint 명시 |
| 3 | 기술·크레딧 | 높음 | 코어 `0005_core_jobs_storage.sql:240-267`, `2300:1129-1132`, `:1974-1978`, `03_SCREENS_UX.md:388` | [검증] 대기 잡을 `core.cancel_job`으로 취소하면 환불은 되지만 `generation_runs=queued`, `documents=generating`이 남음. 3건 취소 시 조직 전체 생성 DC006, 해당 문서 DC002로 영구 차단. 취소 권한은 viewer 포함 전 멤버 | 제품 `docs.cancel_generation` RPC(잡 취소 + 실행 canceled + 문서 복구 한 트랜잭션), UI는 이것만 사용, 정리 스케줄 |
| 4 | 크레딧 | 높음 | 코어 `0005:221-224`, `2300:2087-2089`, `CLAUDE.md:68` | [검증] `finish_generation` 커밋 뒤 워커가 죽으면 재시도 DC001 → 최종 `fail_job`이 환불. "버전 전달 + 환불"과 재시도마다 LLM 비용 | 워커가 잡 시작 시 실행이 succeeded면 즉시 `complete_job`. 코어에 "실행 succeeded면 환불 금지" 요청(C-12) |
| 5 | 기술 | 중간 | `2300:2096-2124`, `:2048-2050`, `02_ARCHITECTURE.md:226` | [검증] 재시도 가능한 실패에 `fail_generation`을 먼저 부르면 실행이 failed로 굳어 재큐잉 잡을 끝낼 수 없음. 부르지 않으면 문서가 generating에 남음 | 최종 실패에만 `fail_generation`, 재시도 동안은 running 유지를 명문화 |
| 6 | 효과엔진 | 높음 | `2300:136-155`, `:336`, `:1667-1680`, `01_PRD.md:161`, `:166` | [검증] `checklist_items` PK가 `key` 하나라 이력 없이 제자리 수정. 효과를 비워도 해시 동일. `projects.checklist_version` 고정이 실효 없음 | 불변 `checklist_item_versions(key, version, effects, published_at)`, 프로젝트는 버전 묶음 참조, 해시에 effects 체크섬 포함 |
| 7 | 효과엔진 | 중간 | `2300:1726-1740`, `:1790-1793`, `01_PRD.md:90` | [검증] 문서가 추적 중인 요구사항은 체크 해제 후 재체크해도 `rejected`로 남음 | UPDATE 경로에서 엔진 행 `status`를 `accepted`로 복원 |
| 8 | 문서정합성 | 중간 | `2300:533-534` / `01_PRD.md:91` | [검증] 가장 큰 FR-003을 지우고 다시 추가하면 FR-003 재사용(수용 기준은 재사용 없음) | 프로젝트·접두사별 카운터 테이블 |
| 9 | DB·과금 | 중간 | `2300:383`, `:418-437`, `:396-397` | [검증] member가 소프트 삭제 → 새로 생성 → 복구로 Free 한도 2개를 넘어 활성 4개 | `deleted_at` 해제 시 한도 검사, 소프트 삭제 권한을 owner/admin으로 |
| 10 | DB | 중간 | `2300:228`, `:1656-1660`, `:873` | [검증] 서식 `{YYYY}-{SEQ:4}`이면 두 번째 유형 확정 시 23505로 영구 실패, `{YYYY}`를 빼면 다음 해 충돌 | CHECK에 `{TYPE}`/`{PREFIX}`와 `{YYYY}`/`{YY}` 필수 |
| 11 | 비용 | 중간 | `2300:1980-1987`, `01_PRD.md:356` | [검증] 일일 상한이 `generation_runs`만 합산. 추출·회의록·채팅·색인·내보내기는 상한 밖 | `credit_ledger`의 `app_id='docs'` 기준 또는 모든 차감 경로에 공통 상한 |
| 12 | 문서정합성 | 중간 | `04_API.md:12` vs `2300:1875` | [검증] 패키지 자식 키 `<run_id>:<doc_type_code>`가 정규식 `[A-Za-z0-9-]`에 막혀 22023, 자식 생성 불가 | 자식 키를 `<run_id>-<seq>`로 바꾸거나 정규식 확장 |
| 13 | DB | 낮음 | `2300:443-449`, `:493` | [검증] 체크리스트 답 값 형식 미검증(`"ultra"` 저장됨) | 서버 zod와 함께 `input_type`·`options` 검사 트리거 |
| 14 | 문서정합성 | 낮음 | `CLAUDE.md:64`, `:92`, `06_AGENT_PLAN.md:112` | [검증] 01장 인용 줄 번호가 8줄 밀림 | 줄 번호 재생성 스크립트로 일괄 갱신 |
| 15 | 일정·기술 | 높음 | `docs/file/03-설계/공용코어/SHARED_MODULES.md:267`, `README.md:46`, `06_AGENT_PLAN.md:194` | [검증] PDF·DOCX 모두 flora-publishing 소유 렌더 서비스 의존, flora-publishing은 기획만. 핵심 결과물이 다른 제품 일정에 묶임 | 첫 릴리스는 이 제품 워커 안 WeasyPrint로 PDF만, DOCX는 MVP 제외 |
| 16 | AI·사업 | 높음 | `_supabase-modular/seed.sql:229-230`, `01_PRD.md:292`, `:300`, `:329` | [판단] 자체 원가표 기준 hybrid 문서 약 72크레딧 상당을 6크레딧에, 채팅 6~8크레딧 상당을 1크레딧에 받음. GPU 고정비 회수 계획 없음 | 베타 2주 원가 측정(D-4)을 출시 조건으로, hybrid 10~12·채팅 2 시나리오 준비, GPU 고정비를 손익표에 포함 |
| 17 | 법률 | 높음 | `01_PRD.md:384`, `:455` | [판단] 변호사법 109조 위험 미확인. 법률문서 자동작성 서비스의 형사 사건 선례가 있음(결과 확인 필요). "체크 → 조항 자동 포함"이 개별 판단 제공으로 비칠 여지 | D-3에서 변호사 서면 의견 확보, 조항 자동 선택을 "사용자 선택 + 설명"으로 바꿀지 검토 |
| 18 | 법률 | 중간 | `01_PRD.md:378`, `:109` | [판단] RFP·회의 속 제3자에 대해 NOMAD는 수탁자이므로 국외 이전 근거는 위탁계약(DPA)과 고객 처리방침 고지여야 함 | 이용약관에 처리위탁 조항, 국외 수탁자·국가 목록, 고객 책임 조항, 법무 확인 |
| 19 | 법률 | 중간 | `01_PRD.md:382`, `:461` | [판단] AI 기본법(2026-01 시행으로 알려짐, 시행령 확인 필요)의 생성형 AI 고지·표시 의무 미인용. D-9 (a) "메타데이터만"은 미달 가능 | 조문·시행령 기준을 6장에 추가, D-9에서 (a) 제거 |
| 20 | 표준계약서 | 낮음 | `01_PRD.md:385`, `2300` clauses | [검증] 조항 9개가 모두 draft라 계약서 확정 불가인데 생성 크레딧은 차감됨 | 1번 비활성화로 해결 |
| 21 | PII | 중간 | `01_PRD.md:233`, `:373` | [판단] `\d{6}-?[1-8]\d{6}`가 13자리 계좌번호·주문번호도 막음(대금 조항 계좌번호 422 가능) | 생년월일 유효성 + 검증숫자 검사, 오탐 회귀 테스트 |
| 22 | NFR | 중간 | `01_PRD.md:363`, `:351`, `:348` | [판단] 다중 서비스 직렬 구성 1인 운영으로 월 99.5%는 비현실적, 음성·추출 p95는 GPU 용량 의존 | 베타 SLO 99%, 음성·추출 p95는 측정 후 확정 |
| 23 | 사업 | 중간 | `01_PRD.md:12`, `:269`, `:279` | [검증] 지불 의사가 가장 높은 에이전시 PM의 팀 기능이 Phase 2 | 첫 유료 타깃을 프리랜서로 좁히거나 공유 링크·2인 좌석을 앞당김 |
| 24 | 연동 | 낮음 | `01_PRD.md:62`, `:458`, `:280` | [검증] HubSpot 약관·한도·앱 심사 미확인(Phase 2라 MVP는 막지 않음). team 플랜 가치가 연동에 의존 | 국내 고객 인터뷰 전 연동 개발 착수 금지(Make/n8n 웹훅만) |
| 25 | 일정 | 높음 | `06_AGENT_PLAN.md:15`, `:127-135`, `01_PRD.md:29` | [판단] 작업 59개, 웨이브 W0~W7, 1인 검수 병목, 코어 요청 4건 선행. 현실적으로 4~6개월 | 1.2.3 축소 릴리스로 작업 20개 안팎 재편 |

#### 1.2.3 사업 타당성 [판단]

| 항목 | 평가 |
|---|---|
| 목표 시장 | 국내 외주 개발 프리랜서·소형 에이전시는 실재하지만 작고, 수주 문서 업무는 월 4~6건으로 빈도가 낮다 |
| 지불 의사 | 프리랜서는 월 1~2만원도 망설인다. 지불 이유는 "고객 앞에서 프로답게 보이는 견적서·과업지시서 + 분쟁 예방". 에이전시는 지불 의사가 높지만 팀·승인·서식 맞춤(Phase 2)을 요구 |
| 무료 대안 | 공공 표준계약서(hwp), 엑셀 견적 템플릿, 외주 중개 플랫폼의 계약 도구, 범용 AI 채팅 |
| 차별점 | "체크 하나가 견적·요구사항·화면·검수·추적표에 같은 숫자와 ID로 반영되는 결정성". 해자는 AI가 아니라 효과 엔진과 조항·체크리스트 카탈로그 품질. RAG 채팅·위키·음성은 차별점이 아니라 원가 |
| 범위 판단 | 8종 + AI + 음성 + 3D는 첫 검증으로 과대. 확정 결정 13~17을 MVP 필수로 묶은 것(`01_PRD.md:29`)이 가장 큰 범위 리스크 |

권고 첫 릴리스(v0, 6~8주, 작업 20개 안팎):

| 항목 | 내용 |
|---|---|
| 범위 | 견적서, 과업지시서(template), 요구사항정의서, WBS, 추적표 5종 + PDF. 체크리스트 15개와 효과 엔진, 확정·버전, Toss 크레딧팩만. AI는 0 또는 hybrid 섹션 1개. 음성·위키·Dify·3D·DOCX·계약서 제외 |
| 검증 순서 | 랜딩·가격표로 대기자 100명 → 프리랜서·에이전시 10곳 인터뷰 + 컨시어지(수동 제작) 5건 → 출시 후 4주 활성화율 40%·팩 결제 10건 → RFP 추출(가장 강한 AI 가치) 추가 |

#### 1.2.4 반드시 고칠 것(출시 전)

| 순서 | 내용 | 발견 # |
|---|---|---|
| 1 | `dev_contract` seed 비활성, upsert 덮어쓰기 제거 | 1, 20 |
| 2 | `finalize_document`에 정본 최신성·lint 실행 게이트 | 2 |
| 3 | 제품 전용 생성 취소 RPC, 성공 후 환불·재시도 순서 계약 | 3, 4, 5 |
| 4 | 체크리스트 카탈로그 불변 버전화, 해시 확장, 재체크 시 상태 복원 | 6, 7 |
| 5 | 코드 카운터, 프로젝트 한도 우회 차단, 문서번호 서식 CHECK, 자식 멱등 키 정규식 | 8, 9, 10, 12 |
| 6 | 일일 상한을 모든 차감 경로로 확대, 단가 재산정 | 11, 16 |
| 7 | PDF 렌더 자체 확보 또는 C-1 일정 확정 | 15 |
| 8 | 위 수정마다 RLS 스모크 회귀 항목 추가 | 전체 |

반영 현황(2026-10-14, `2300_docs.sql`·모놀리스 `0002`·`rls_smoke.sql` 105항목, 모듈러·모놀리스 105/105):

| 순서 | 상태 | 반영 내용 |
|---|---|---|
| 1 | 반영 | `dev_contract` seed `is_active=false`, upsert 갱신 대상에서 `is_active` 제외(운영자 값 보존) |
| 2 | 반영 | `finalize_document`: `needs_regeneration` · 생성 버전 `inputs_hash` 대조(DC010), `lint_result.ran_at` 필수(DC005). 편집 저장 경로 lint 명시(02장 2.2절) |
| 3 | 반영 | `docs.cancel_generation`(잡 취소 + 실행 canceled + 문서 복구), `docs.reconcile_generation_runs`(코어 `cancel_job` 직접 호출·잡 정리기 대비), `finish_generation`이 잡 `refund_on_failure=false`, 실패·재시도 계약(02장 4절). 코어 요청 없이 해결 |
| 4 | 반영 | `checklist_item_versions`(불변 이력) + 효과·선택지 변경 시 version 자동 증가, `checklist_answers_hash`에 항목 version·단가 카탈로그 포함, 재체크 시 rejected → accepted 복원 |
| 5 | 반영 | `project_code_counters`(코드 재사용 없음), 소프트 삭제·복구 owner/admin 전용 + 복구 시 한도 검사(무제한 플랜 null 처리 포함), 문서번호 서식 CHECK(유형·연도 토큰 필수), 패키지 자식 멱등 키 `:`·`_` 허용 |
| 6 | 일부 | 일일 상한을 `docs.daily_credit_usage` + `docs.reserve_credits`로 모든 차감 경로에 적용(반영). 단가 재산정은 D-4(베타 원가 측정) 결정 사항 |
| 7 | 결정 필요 | PDF 렌더 소유(C-1 일정 또는 이 제품 워커 임시 렌더)는 소유자 결정(1.2.5절) |
| 8 | 반영 | 위 각 항목 회귀 테스트 46개 추가(`supabase/monolith/tests/rls_smoke.sql` 2026-10-14 블록, 모듈러·모놀리스 105/105) |

독립 검토(2026-10-14, 작성에 참여하지 않은 Opus 검토 에이전트, PGlite 재현)에서 위 수정의 빈틈 8건이 나왔고 7건을 같은 날 고쳤다: (1) 생성 밖 차감 멱등 키를 생성 키와 같은 네임스페이스로 재사용해 과금을 피하는 경로 → 생성은 `consume:docs:gen:`, 그 밖은 `consume:docs:<작업>:`로 나누고 `reserve_credits`가 금액·사유·조직 불일치 재사용을 거부 (2) 다른 조직 키로 남의 원장 행을 돌려받는 경로 → 42501 (3) 생성 중 바뀐 정본이 완료 때 지워지던 문제 → `generating`도 재생성 필요로 표시하고 표시 해제는 `start_generation`에서 (4) 사용자가 직접 rejected로 둔 요구사항을 재적용이 되돌리던 문제 → 상태 변경도 사용자 수정으로 표시 (5) 무제한 플랜의 보관 해제가 막히던 문제 → `set_project_status`의 중복 한도 검사 제거(트리거가 판정) (6) `next_project_code` 직접 호출로 번호 소모 → 트리거 안에서만 (7) 패키지 취소가 이미 실행 중인 자식까지 취소로 표시하던 문제 → 잡이 실제 취소된 자식만. 남은 1건(viewer가 코어 `cancel_job`으로 취소)은 코어 요청 C-12다. 또 2300은 아직 어떤 DB에도 적용 전이라 `create table` 본문을 직접 고쳤다. 한 번이라도 원격에 적용한 뒤에는 고치지 않고 새 번호 파일(`2310_docs_*.sql`)로 쌓는다.

#### 1.2.5 결정이 필요한 것(소유자)

| 결정 | 권고 |
|---|---|
| MVP 범위(D-2 확장) | 1.2.3 v0로 축소하고, 확정 결정 13~17의 MVP 필수를 이 제품에서만 해제 |
| D-3, D-8 계약서 | 변호사 서면 의견 전까지 계약서 비공개, 조항 자동 선택 방식 재검토 |
| D-4 요금 | 원가 측정 전 공개 가격 확정 금지, Free 월 30크레딧 반복 지급 유지 여부 |
| 첫 유료 고객 | 프리랜서(지금 범위로 가능) 또는 에이전시(팀 기능 선행) 중 하나 |
| 렌더 소유 | 공용 서비스를 기다릴지, 이 제품 워커에 먼저 둘지 |
| D-9, 국외 이전 | AI 기본법 표시 방식과 처리위탁(DPA) 구조를 법무와 확정 |
| 오픈소스 강제 기능 | GPU 서버 월 고정비를 감당할지, 회의록을 v0에서 뺄지 |

검증하지 못한 것: Supabase Realtime의 실제 RLS 필터링(publication 등록과 SELECT 정책만 구조 확인), 법령 시행일·조문, 선례 사건 결과, HubSpot 약관, LLM 실단가.

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| DC-06-001 | SQL 적용과 타입 생성: 모듈러 조각 `2300` 적용, 1.1절 I-12 수정, Phase 2 ERP 읽기 함수 자리(C-7 뒤), 타입 생성 | `supabase/migrations/2300_docs.sql`(앱 저장소 사본), `supabase/config.toml`(`[api].schemas`에 `docs`), `web/src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공. `node check.mjs --vector mod 0000~0009 seed.sql 2300_docs.sql` OK. 라우팅 기본값 13행, `doc_types` MVP 8종 활성(`dev_contract`는 seed부터 `is_active=false`, D-3 법무 검토 뒤 운영자가 켠다. 재실행이 켠 값을 덮지 않는다). 2026-10-14 반영분(1.2.4절 1~6) 포함. `supabase gen types typescript --local --schema core,docs` 결과와 커밋된 타입 diff 0 | `05_DATA_MODEL.md:894-941`, SellingDocs 5장 #1, #4 |
| DC-06-002 | 모놀리스 변환 스크립트(`docs.`→`public.`, `core.`→`public.`, 함수 34개 이름 목록 EXECUTE 회수, `@monolith-seed` 블록을 `seed.sql`로) | `scripts/nomad-docs/to-monolith.*`, `supabase/monolith/**`(tests 제외) | DC-06-001 | P0 | S | Opus | 스크립트 출력이 `supabase/monolith/migrations/0002_nomad_docs_domain.sql`과 diff 0. `--check` 모드가 CI에서 불일치 시 실패. `node check.mjs --vector mono 0001 0002 seed` OK | `05_DATA_MODEL.md:876-892` |
| DC-06-003 | RLS/권한 회귀 테스트 자동화: `rls_smoke.sql`(105항목: 기본 59 + 2026-10-14 교차검증 회귀·신규 기능·독립 검토 회귀 46) 러너(`@S@`/`@C@` 치환, `-- AS` 역할 전환, `expect=` 판정)를 CI에 연결, `SECURITY_BASELINE.md` 15장 AI 항목과 1.1절 I-12 회귀 추가 | `supabase/tests/`, `scripts/nomad-docs/rls-runner.*` | DC-06-001, DC-06-002 | P0 | M | Fable | 모듈러·모놀리스 두 대상에서 105/105 + 추가 항목(타인 `ai_conversations` 0행, `ai_chunks` SELECT 42501, `resolve_ai_route` authenticated 42501, 사용자 세션 `erp.products` SELECT 42501 또는 0행) 전부 통과. 하나라도 실패하면 CI 병합 차단 | `supabase/monolith/tests/rls_smoke.sql:1-3`, `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:238-276`, flora 5장 #2, #8 |
| DC-06-004 | web 골격: Next.js 16.2.x 앱, `src/proxy.ts`(`signup_app='docs'`), `@supabase/ssr` 클라이언트 3종, env zod 검증, 루트 레이아웃, 저장소 `CLAUDE.md`(이 폴더 CLAUDE.md 참조만), `.gitignore`(`.env*`) | `web/` 루트 설정(package.json, next.config.ts, tsconfig.json, eslint, `postcss` Tailwind CSS v4 설정), `web/src/proxy.ts`, `web/src/lib/supabase/`, `web/src/lib/env.ts`, `web/src/app/layout.tsx`, `web/CLAUDE.md` | 없음 | P0 | M | Opus | 필수 env 하나라도 빠지면 `next dev` 기동 실패. 미로그인 `/app` → `/login`. TS strict, `latest` 의존성 0, `tailwind.config.js`·`@tailwind base` 0. `web/CLAUDE.md`가 비어 있으면 CI 실패 | SellingDocs 5장 #2, #3, flora 5장 #15, `02_ARCHITECTURE.md:363-398` |
| DC-06-005 | TS 워커 골격: `claim_jobs` 루프(`docs.generate`, `docs.export`, `docs.integration`), 핸들러 레지스트리, 하트비트, env 검증, payload zod | `worker/` 루트 설정, `worker/src/main.ts`, `worker/src/lib/`, `worker/src/handlers/index.ts` | 없음 | P0 | M | Opus | 빈 핸들러 잡을 `complete_job`. payload에 금액·HTML·비밀 필드가 있으면 zod 거부. 워커 env에 LLM 키 0(기동 검사). `SIGTERM` 시 진행 잡 하트비트 중단 후 종료 | `02_ARCHITECTURE.md:75`, `:220-253`, `04_API.md:142` |
| DC-06-006 | ai-service 설치(docs 설정): 공용 ai-service 적용, app `docs` 설정, JWKS 검증(`aud=platform-ai:docs`), 잡 토큰 scope, 국외 이전 필터 연동, 기동 시 `tpl` 체크섬 검사, 비동기 HTTP만 | `api/`(아래 docs 확장 경로 제외: `app/ai/graphs/docs_*.py`, `app/ai/products/docs/**`, `app/ai/tools/docs/`, `app/ai/compliance/docs.py`), `api/tests/platform/` | DC-06-001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401. 토큰 org와 다른 org 문서 요청 403. 미동의 조직의 라우팅 결과에 상용 제공자 0. `DOCS_TEMPLATES_DIR` 체크섬 불일치 유형은 비활성 + 운영 알림. `requests`·동기 SDK import 0(pytest 검사) | `02_ARCHITECTURE.md:81-90`, `:319`, flora 5장 #1, #4, #6 |
| DC-06-007 | CI: tsc, lint, build, Vitest, pytest·ruff, SQL 체커(`--vector`), RLS 러너, 모놀리스 `--check`, actionlint, 금지 문자열·비밀 검사, `CLAUDE.md` 빈 파일 검사, 웹 번들의 렌더 클라이언트·three.js 경로 import 검사 | `.github/workflows/nomad-docs.yml` | DC-06-004, DC-06-005 | P0 | S | Sonnet | PR마다 실행, 하나라도 실패하면 병합 불가. step 레벨 `if`에 `secrets` 0(actionlint). `tailwind.config.js` 존재, `.env` 커밋, `flora_pro_unlocked`·`'1234'` 문자열이 있으면 실패. 인증 단계 검사(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2.4절, 9장): 쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈 밖의 `AUTH_MODE` 참조(허용: `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/app/auth/`, `web/src/app/api/dev/login/`)가 있으면 실패, `AUTH_MODE=mock VERCEL_ENV=production npm run build`가 실패하는지 확인(DC-06-014 가드가 들어온 뒤 켠다) | SellingDocs 3장 #3, flora 3장 #7, 5장 #5, #15 |
| DC-06-008 | 디자인 시스템 1단계: 레퍼런스 확정(앱 Atlassian 주 + Primer 보조, AI 화면 Astryx 패턴 확인, 랜딩 `HERO_3D.md`), 가져올 것·안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | `03_SCREENS_UX.md:670-672` 표가 1절에 있다. Astryx 존재·라이선스 확인 결과 또는 미확인 시 대체안 기록. 고문(Fable) 검토 기록 1건 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/file/03-설계/디자인/REFERENCES.md:309` nomad-docs 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md:29-38`). | `DESIGN_SYSTEM.md:43`, `03_SCREENS_UX.md:664-679` |
| DC-06-009 | 디자인 시스템 2단계: Tailwind CSS v4 토큰(`@theme`, 라이트/다크, `data-theme`), 기본 컴포넌트·배리언트, 미리보기 `/dev/components` | `web/src/styles/`, `web/src/components/ui/`, `web/src/app/dev/components/` | DC-06-004, DC-06-008 | P0 | M | Sonnet | `03_SCREENS_UX.md:674`, `:677-689`의 토큰 이름과 기본 컴포넌트 전부 라이트/다크 미리보기. hex 하드코딩 0, `tailwind.config.js` 0, Tailwind CSS v4 4.x 고정, 대비 4.5:1, `COMPONENTS.md` 배리언트 표 초안 | `DESIGN_SYSTEM.md:44`, 1.1절 I-13 |
| DC-06-010 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트). Sonnet이 스크린샷·점검표를 준비하고 판정과 수치 수정은 사람이 한다 | `docs/file/03-설계/디자인/review/` | DC-06-009 | P0 | M | Sonnet | 기본 컴포넌트 전부의 스크린샷과 사람이 고친 수치 기록, 포커스 링·대비 확인, `--color-seal` 사용처가 직인·확정 표시·3D 히어로뿐인지 확인. 이 단계는 줄이지 않는다 | `DESIGN_SYSTEM.md:45` |
| DC-06-011 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정, 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | DC-06-010 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치. 피그마 노드 id·외부 파일 링크 0 | `DESIGN_SYSTEM.md:46` |
| DC-06-012 | API 공통: `requireSession('docs')` 래퍼, zod 파이프, 응답 봉투, `request_id`, SQLSTATE → HTTP 매핑(DC001~DC010, 코어 코드), 레이트 리밋(1.1절 I-7, I-8), `apiFetch`, Realtime 잡 구독 훅 | `web/src/lib/server/http/`, `web/src/lib/client/` | DC-06-004 | P0 | M | Opus | 모든 Route Handler가 래퍼를 거치는지 린트 규칙으로 검사. `04_API.md:242-261` 매핑 표대로 응답. 생성 API 21번째/분 429. `P0002` → 404(`.single()` 500 금지). 실패를 mock 응답으로 숨기는 코드 0 | `04_API.md:5-20`, flora 5장 #1, #10, #13 |
| DC-06-013 | 크레딧 단가표(`priceOf`)와 features 해석기(서버 전용 `docs.org_features`, 키 없으면 Free 기본값) | `web/src/lib/server/pricing/`, `web/src/lib/server/features/` | DC-06-001 | P0 | M | Fable | `priceOf`가 `01_PRD.md:301-316`과 같다(단위 테스트, 패키지 28). features 11개 키가 `01_PRD.md:285-299`과 같고 키 누락 시 Free 값. 클라이언트에서 플랜을 판정하는 코드 경로 0 | `01_PRD.md:273-347`, flora 5장 #8, flora 3장 #6 |
| DC-06-014 | 인증 Stage A(2026-10-14 범위 변경): 인증 모듈 경계(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`, 첫 진입 온보딩 경로 `onboarding.ts`, 02장 9.6절), Mock 로그인(`POST /api/dev/login`, `/login` 개발용 패널, 상단 배지 `MOCK AUTH · 로컬 전용`), `scripts/dev/seed-users.mjs` + 제품 훅 `seed-users.docs.mjs`(05장 10절), 가드(env zod, 404, 빌드 검사), `finishLogin`의 `next` 화이트리스트와 첫 진입 워크스페이스 보장(self 당사자·`workspace_settings` 1행), 이메일 인증 전 실행 차단 가드(`email_confirmed_at`), 회사 정보 온보딩(`/onboarding/company`). 이메일 가입·메일 인증·비밀번호 재설정 화면과 Google·콜백 라우트는 B(DC-06-063)로 옮겼다 | `web/src/lib/auth/`, `web/src/app/api/dev/login/`, `web/src/app/(auth)/login/`(A 구성, 063이 이어 받음), `web/src/components/dev-auth/`, `scripts/dev/`, `web/src/app/onboarding/company/` | DC-06-001, DC-06-004, DC-06-012 | P0 | M | Fable | `owner` 페르소나 로그인 → `/onboarding/ai` → `/onboarding/company` → `/app`, 새로고침 유지, `session_context('docs')` `entitled=true`·`plan_code='free'`·잔액 80(가입 50 + 월 30). `no_app` 로그인 → `finishLogin`이 `bootstrap_app_for_org` 1회(모듈러), 재로그인 3회 뒤 가입 크레딧 원장 1행. 재로그인 10회에도 `workspace_settings`·self 당사자 각 1행. `outsider`로 owner 조직 `projects`·`parties`·`documents` 0행. `finishLogin` 단위 테스트 `next=//evil.com`·`https://evil.com`·`/\evil.com`·`@evil.com` → `/app`. 테스트가 만든 미인증 계정의 생성 요청 403 `email_not_verified`. `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404·개발용 패널 미렌더. 시드 스크립트가 원격 URL이면 exit 1, 2회 실행해도 크레딧 1회. 인증 모듈 밖 `AUTH_MODE` 참조 0 | DC-F-001, SellingDocs 5장 #3, AUTH_ROADMAP 2장, 3.1·3.2절 |
| DC-06-015 | 워크스페이스·직인·거래처 API, 서버 PII lint(주민등록번호 패턴, 1.1절 I-10), 사업자등록번호 체크섬, 문서번호 서식 검증(I-6) | `web/src/app/api/workspace/`, `web/src/app/api/parties/`(`import/` 제외), `web/src/lib/server/pii/` | DC-06-012 | P0 | M | Opus | member의 `PATCH /api/workspace` 403. 직인 2MB 초과 413, 매직바이트 불일치 415. 메모에 `900101-1234567` 저장 422 `pii_detected`. 체크섬 오류 422. 서식에 `{SEQ` 없으면 422. 삭제 거래처 30일 복원 | DC-F-002, DC-F-003, `04_API.md:29-36` |
| DC-06-016 | 프로젝트·요구사항·산출물·비용 항목 API와 합계(`project_totals` 읽기), 상태 전이 RPC 호출, 사용자 수정 표시(`is_user_modified`) | `web/src/app/api/projects/route.ts`, `web/src/app/api/projects/[id]/route.ts`, `.../[id]/status/`, `.../[id]/requirements/`, `.../[id]/artifacts/`, `.../[id]/line-items/`(`import/` 제외), `web/src/app/api/requirements/`, `web/src/app/api/artifacts/`, `web/src/app/api/line-items/`, `web/src/lib/server/totals/` | DC-06-012, DC-06-013 | P0 | L | Opus | Free 3번째 프로젝트 403 `DC006`. 수동 FR 2건 → FR-004, FR-005, 삭제 후 새 행 FR-006. 요청 본문의 `amount_krw`·`req_code` 무시. 수량 2.5 × 400,000 = 1,000,000. 항목 합계 3,250,000 → VAT 325,000, 총액 3,575,000(1.1절 I-5) | DC-F-004, DC-F-007~009, `04_API.md:37-53` |
| DC-06-017 | 효과 엔진 순수 함수: `computeEffects(items, answers, settings)` → 목표 집합, `diffEffects(target, current)` → `EffectPlan`(add, update, remove, keepUserModified, clauses, affectedDocTypes). 시각·난수·LLM·I/O 없음 | `web/src/features/effects-engine/` | DC-06-001 | P0 | L | Opus | 1.1절 I-1~I-3 기준 반영. `feat.payment` 체크 → FR 2 + NFR 1, SCR 2, 비용 1, 조항 `dev.pg_responsibility`. 사용자 수정 행은 update·remove에 없고 keepUserModified에 있다. 항목 200·답 200 계산 50ms 이하. 파일 안에 `Date`, `Math.random`, `fetch` 사용 0(린트) | DC-F-006, `01_PRD.md:154-196`, `02_ARCHITECTURE.md:92-126` |
| DC-06-018 | 체크리스트 API와 효과 적용: 답 저장(input_type별 zod), 후보 확인(`docs.confirm_checklist_suggestions`), `effects/preview`, `effects/apply`(service_role `docs.apply_checklist_effects`, `p_expected_hash`) | `web/src/app/api/projects/[id]/checklist/`, `web/src/app/api/projects/[id]/effects/` | DC-06-016, DC-06-017 | P0 | M | Fable | `feat.payment` 적용 p95 3초. 같은 답 재적용 변경 0. 미리보기 뒤 답이 바뀌면 409 `DC010`. archived 프로젝트 409 `DC001`. `req_spec` 초안이 있으면 1초 안에 `needs_regeneration=true`. 확인 전 추출 후보로 생긴 정본 행 0. 적용마다 감사 1행 | DC-F-005, DC-F-006, `04_API.md:42-46`, `2300`:1898 |
| DC-06-019 | 효과 엔진 속성 테스트(fast-check 등): 결정성, 멱등, 순서 무관성, 사용자 수정 보존, 출처 격리 + 골든 스냅샷 | `web/tests/effects/` | DC-06-017 | P0 | M | Opus | 무작위 답 집합 1,000개에서 (1) 같은 입력 2회 계산 결과 바이트 동일 (2) 답 배열 순서를 섞어도 동일 (3) 계산 결과를 현재 상태로 넣고 다시 diff하면 변경 0 (4) `is_user_modified` 행은 계획의 update·remove에 0건 (5) `source<>'checklist'` 행 변경 0. 빈 프로젝트 2개에 같은 답 → 요구사항(code, title, priority) 목록 동일 | DC-F-006 수용 기준(`01_PRD.md:93`) |
| DC-06-020 | 문서 템플릿 패키지: MVP 9종(`quote`, `sow`, `req_spec`, `wbs`, `screen_list`, `dev_contract`, `acceptance`, `minutes`, `trace_matrix`) v1의 `structure.json`, `document.html.j2`, `sections/*.j2`(autoescape), `lint_rules.json`, A4 공문서 CSS(Noto Sans CJK KR, fontconfig 이름만), `dev_contract` 조항 골격(draft), `sanitize-allowlist.json`, `checksums.json`, effects JSON Schema | `tpl/`(`tpl/tests/` 제외) | DC-06-001 | P0 | L | Opus | 9종 각 `structure`의 섹션 key·kind가 `01_PRD.md:141-151`와 같다. `checksums.json`이 `doc_type_versions.checksum` seed와 일치. 템플릿에 금액 계산식 0(변수만). 폰트 파일 경로(`C:/`, `.ttf`) 0. 조항 본문은 D-8 전 운영자 작성분만, `source_note` 필수 | DC-F-010, DC-F-019, `02_ARCHITECTURE.md:128-147`, SellingDocs 5장 #8, flora 5장 #7 |
| DC-06-021 | compliance·lint 규칙: 규칙 사전(법률 자문 단정, 보장 표현, 고유식별정보), lint 엔진(`L-AMOUNT-MATCH`, `L-PAY-100`, `L-PERIOD`, `L-PARTY`, `L-REQ-REF`, `L-REQUIRED-CLAUSE`, `L-RRN`, `L-UNTRACED`, `L-AI-CLAIM`, `L-BANNED`) | `api/app/ai/products/docs/rules/`, `api/app/ai/products/docs/lint/`, `api/app/ai/compliance/docs.py` | DC-06-006, DC-06-020 | P0 | M | Opus | 규칙마다 양성·음성 단위 테스트 2개 이상. 견적 3,575,000과 계약 3,500,000 → error 1건 + 두 문서 위치. 없는 FR-099 → error. 지급 비율 합 90% → error. "법적 효력 보장" → FAIL. 한글 금지어를 `\b` 경계로 매칭하는 코드 0. 코드 검사 p95 3초 | DC-F-016, `01_PRD.md:237-250`, `:398-411` |
| DC-06-022 | LangGraph `docs.generate`(load_context → plan_sections → fill_template → draft_ai_sections → consistency_check → lint → compliance → output), 프롬프트, 컨텍스트 로더(금액·기간 읽기 전용 뷰), 템플릿 로더. 노드 경계마다 `docs.report_generation_progress`(collecting → drafting(섹션별) → assembling → linting, DC-F-048), 결과 `lint_result`에 `ran_at`·`rules` 포함 | `api/app/ai/graphs/docs_generate.py`, `api/app/ai/products/docs/prompts/`, `api/app/ai/products/docs/context.py`, `api/app/ai/products/docs/templates_loader.py` | DC-06-006, DC-06-020, DC-06-021 | P0 | L | Fable | template 유형 LLM 호출 0, `dev_contract` 1건의 `core.ai_usage` LLM 행 0. hybrid는 kind=ai 섹션만 섹션별 JSON(pydantic) 생성. LLM 출력의 숫자가 서버 값과 다르면 1회 재작성 후 lint 오류(조용한 교체 0). `body_html` 2MB 초과 실패. 버전 저장은 `docs.finish_generation` 1회. 서술 섹션마다 근거 1개 이상 | DC-F-011, `02_ARCHITECTURE.md:302-321`, SellingDocs 3장 #4, 5장 #5 |
| DC-06-023 | LangGraph `docs.extract`(parse → index → extract_checklist → extract_requirements → dedupe → compliance → output)와 추출·후보 수락 API | `api/app/ai/graphs/docs_extract.py`, `web/src/app/api/projects/[id]/extract/`, `web/src/app/api/projects/[id]/suggestions/` | DC-06-018, DC-06-031, DC-06-032, DC-06-033 | P0 | L | Opus | 40쪽 RFP p95 3분. 후보마다 쪽 번호와 인용 200자 이하. 카탈로그에 없는 key 후보 저장 0. 확인 전 정본 행 0. 실패 시 10크레딧 환불 1행. 인젝션 문구가 든 RFP 샘플 3종에서 지시 수행 0 | DC-F-022, `02_ARCHITECTURE.md:309`, `04_API.md:75`, `:74` |
| DC-06-024 | 회의록: LangGraph `docs.minutes`, STT 10분 분할 호출(`meeting_minutes`, 오픈소스 강제), 회의록 API, 녹음 고지 검사(1.1절 I-11, I-15), 원본 24시간 삭제 표시(`uploads.expires_at`) | `api/app/ai/graphs/docs_minutes.py`, `api/app/ai/products/docs/minutes_stt.py`, `web/src/app/api/projects/[id]/minutes/` | DC-06-006, DC-06-031, DC-06-033 | P0 | L | Opus | 고지 버전 없이 업로드 422 `recording_notice_required`. `feature in ('meeting_minutes','docs.minutes')`의 상용 제공자 `ai_usage` 0. 결정 사항·할 일 표 존재. 후보는 확인 전 정본 0행. STT·그래프 실패 시 전액 환불. 텍스트 붙여넣기만으로 회의록 생성 가능 | DC-F-026, `01_PRD.md:113`, 1.1절 I-9 |
| DC-06-025 | LangGraph `docs.assist`(선택 영역 다시 쓰기·요약·표 변환 → compliance)와 `/api/ai/assist` | `api/app/ai/graphs/docs_assist.py`, `web/src/app/api/ai/assist/` | DC-06-006, DC-06-021, DC-06-033 | P0 | M | Opus | 선택 영역 4,000자 초과 422 `selection_too_long`(잘라서 처리 0). 결과는 Diff 제안만, 저장 0. `dev_contract` 문서 호출 403 `assist_disabled_high_risk`. 실패 시 1크레딧 환불. p95 20초 | DC-F-013, flora 3장 #10, 5장 #7 |
| DC-06-026 | 생성·렌더 골든과 평가: 9종 template 골든 HTML, hybrid 평가셋 20건(숫자 일치, 근거 표시), 한글 골든 PDF·DOCX(두부 0), extract 평가셋 10건, 비동기 위반 검사 | `api/tests/docs/graphs/`, `api/eval/docs/`, `tpl/tests/`, `worker/tests/render/` | DC-06-022, DC-06-029 | P0 | L | Opus | 골든 9종 diff 0. 평가셋 20건을 상용·오픈소스 두 경로로 통과(숫자 불일치 0). A4 20쪽 PDF p95 30초, `pdffonts`에 Noto CJK 포함, 두부 문자 0. template 생성 p95 5초 | `01_PRD.md:355-359`, flora 3장 #8, #9 |
| DC-06-027 | 생성 요청 API와 워커 핸들러: 단일 문서(`docs.start_generation`), 패키지 `outsourcing_basic`(부모 잡, 의존 순서, 자식 단위 차감·환불·하류 취소), 취소 API | `web/src/app/api/projects/[id]/documents/`, `web/src/app/api/projects/[id]/packages/`, `web/src/app/api/generation-runs/`, `worker/src/handlers/docs-generate.ts`, `worker/src/handlers/docs-package.ts` | DC-06-005, DC-06-013, DC-06-016, DC-06-022 | P0 | L | Fable | 필수 입력 누락 422 `DC004` + `details.missing`(잔액 변화 0). 같은 문서 재요청 409 `DC002`. 고지 미동의 428 `DC007`. 8종 패키지 p95 4분, 예상 28 크레딧. `req_spec` 강제 실패 시 sow·acceptance·trace_matrix canceled, 환불 합 = 실패·취소 자식 단가 합. 같은 `request_id` 재전송 차감 1회. 워커 env LLM 키 0 | DC-F-011, DC-F-012, DC-F-039, `04_API.md:55-57`, SellingDocs 3장 #2, 5장 #5 |
| DC-06-028 | 문서 API: 편집 저장(섹션 단위, 잠금 섹션 거부, 서버 sanitize, `expected_version`), 버전 목록·diff, 확정(`docs.finalize_document`), 보관, 개정본, 고지 동의 | `web/src/app/api/documents/[id]/route.ts`, `.../versions/`, `.../finalize/`, `.../archive/`, `.../revision/`, `web/src/app/api/risk-acks/`, `web/src/lib/server/sanitize/` | DC-06-012, DC-06-020 | P0 | L | Opus | `<script>`, `onerror=` 저장 후 `body_html`에 0건(TS sanitize가 `tpl/sanitize-allowlist.json` 사용). 잠금 섹션 변경 422 `locked_section`. 구버전 저장 409 `DC010`. 확정 후 편집 409 `DC003`. 같은 해 견적 3건 확정 QT-2026-0001~0003, 동시 10건 중복 0. 진행 중 개정본 있음 409 `DC002`(I-17) | DC-F-013~015, DC-F-020, `04_API.md:61-68`, `:69`, SellingDocs 5장 #9 |
| DC-06-029 | 내보내기: `render.pdf`(A4 공문서 프리셋, Free 워터마크 강제), `render.docx`(C-1 반영 전 403 `format_unavailable`), 패키지 ZIP(`docs.export_zip`), 같은 버전·형식 재사용, 다운로드 서명 URL, RFC 5987 파일명 | `worker/src/handlers/render-pdf.ts`, `worker/src/handlers/render-docx.ts`, `worker/src/handlers/export-zip.ts`, `web/src/app/api/documents/[id]/exports/`, `web/src/app/api/projects/[id]/exports/`, `web/src/app/api/exports/` | DC-06-005, DC-06-028 | P0 | L | Opus | web 코드에 렌더 호출 0(enqueue만). Free DOCX 403 `DC006`, Free PDF는 `watermark` 요청값과 무관하게 true. 같은 버전 PDF 재요청 0크레딧·같은 파일. 렌더 실패 시 1크레딧 환불. ZIP은 구성 PDF ready 확인 후 생성, ZIP 자체 차감 0. 서명 URL 7일, 만료 후 410 | DC-F-018, `04_API.md:69-71`, `:143-145`, `:167-180`, SellingDocs 3장 #1, 5장 #6 |
| DC-06-030 | 추적표 빌더와 API: `trace_links` 집계(요구사항 × 화면·요구사항정의서 절·WBS 마일스톤·검수 항목), 빈칸 계산, `trace_matrix` 문서 변수 공급 | `web/src/app/api/projects/[id]/trace/`, `web/src/lib/server/trace/` | DC-06-018, DC-06-022 | P0 | M | Opus | FR 10개 중 화면 연결 없는 2개가 빈칸 2로 반환. 요구사항 추가 후 `trace_matrix` 문서 `needs_regeneration=true`. 행 정렬이 `req_code` 순으로 결정적 | DC-F-017, `01_PRD.md:104` |
| DC-06-031 | 업로드: 서명 업로드 URL, 완료 검증(크기·MIME·매직바이트·쪽수), 서버 생성 경로 `<org>/docs/uploads/<uuid>.<ext>`, 파서(txt, md, docx, pdf), 업로드 권한 확인 감사, LLM 전송 전 주민등록번호 마스킹 | `web/src/app/api/projects/[id]/uploads/`, `web/src/app/api/uploads/`, `api/app/ai/products/docs/parsers/` | DC-06-006, DC-06-012 | P0 | M | Opus | 21MB 413, 301쪽 422, 확장자만 pdf인 실행 파일 415, `rights_confirmed` 없으면 403. 원본 파일명이 `storage_path`에 0. 샘플 4종 파싱 결과 기대값 일치. 파싱은 스레드풀(이벤트 루프 블로킹 0) | DC-F-021, flora 3장 #4, 5장 #3, 1.1절 I-16 |
| DC-06-032 | RAG 색인과 평가셋: 프로젝트별 컬렉션 `docs.knowledge`(oss-embed 고정), `rag.index` 처리, 삭제 반영, 검색 평가셋 30문항 | `api/app/ai/products/docs/knowledge.py`, `api/tests/docs/retrieval/` | DC-06-031 | P0 | M | Opus | 40쪽 PDF p95 90초 ready. 프로젝트 A 질의에 B 청크 0. 다른 컬렉션 id 요청 42501. 재현율@8 0.8 이상(제안). 색인 실패 시 색인 크레딧 환불. 삭제 자료가 검색·추출 근거에서 즉시 0 | DC-F-021, `02_ARCHITECTURE.md:20`, `04_API.md:155` |
| DC-06-033 | AI 게이트: 대화 생성(`dify_user` HMAC), 채팅 중계(Dify `docs-chat`, 장애 시 `/tools/answer-direct`), 턴 선차감·정산, 서명 토큰·잡 토큰 발급(`/api/internal/ai-token`), 정산 크론 엔드포인트, 온보딩 국외 이전 동의 | `web/src/app/api/ai/`(`assist/` 제외), `web/src/app/api/internal/`, `web/src/app/api/onboarding/`, `web/src/app/onboarding/ai/`, `web/src/lib/server/ai/` | DC-06-006, DC-06-012, DC-06-013 | P0 | L | Fable | `04_API.md:94-113` 계약 충족. 같은 `request_id` 재전송 차감 1회. 응답 미전달 턴 환불 1행. 잡 토큰은 running 잡과 허용 `job_type`에만(그 외 409). 미동의 조직 `ai_usage` 상용 0. 철회 직후 다음 요청부터 상용 0. 정산 후 1시간 넘은 `settled_at is null` 0 | DC-F-023, DC-F-025, `02_ARCHITECTURE.md:81-89`, flora 5장 #1 |
| DC-06-034 | Dify `docs-chat`(질문 분류 `dify.aux`, HTTP 노드)과 `/tools/answer` docs 확장(프로젝트 컨텍스트 로더, 법률 판단 거절, 출처), 대화 평가셋 30문항 | `infra/dify/docs-chat.yml`, `api/app/ai/tools/docs/`, `api/tests/docs/chat/` | DC-06-032, DC-06-033, DC-06-035 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403. 다른 조직 `project_id` 404. 답변 100%에 출처 또는 `no_source`. 평가셋 법률 판단 질문 10개 전부 거절 문구, 금지 문구 0. DSL에 키 0. 채팅 첫 토큰 p95 6초 | DC-F-023, `04_API.md:238-240`, `01_PRD.md:432-440` |
| DC-06-035 | 프로젝트 용어 위키 백엔드: `wiki.ingest`(색인·회의록 직후), 페이지 종류 매핑(party → entity, term·acronym → concept, decision → topic), 사용자 편집 저장(`expected_version`), lint | `api/app/ai/products/docs/wiki_config.py`, `web/src/app/api/projects/[id]/wiki/` | DC-06-032 | P0 | M | Opus | RFP 1건 색인 후 갱신 페이지 5개 이하. 사용자 소유 블록 에이전트 수정 0. 오래된 version 저장 409 `WIKI_VERSION_CONFLICT`. 모든 쓰기 감사 1행. 다른 프로젝트 slug 404 | DC-F-024, `01_PRD.md:111`, `04_API.md:104-106` |
| DC-06-036 | 음성 대화: `/api/voice/consent`, `stt`, `tts`(DB의 assistant 메시지만), 마이크 버튼·녹음 중 표시·읽어 주기 컴포넌트 | `web/src/app/api/voice/`, `web/src/features/voice/` | DC-06-033 | P0 | M | Opus | 첫 사용 고지 없이 STT 403 `VOICE_CONSENT_REQUIRED`. 60초 자동 중지. `store_audio=false` 100%. 임의 텍스트 TTS 403. 마이크 거부 시 텍스트 채팅 정상. STT·TTS 실패 환불 1행 | DC-F-027, `04_API.md:107-109` |
| DC-06-037 | CSV/Excel 가져오기: 거래처, 비용 단가표(`workspace_settings.defaults`), UTF-8·CP949 감지, 열 매핑, 미리보기(`dry_run`), 오류 행 CSV | `web/src/app/api/parties/import/`, `web/src/app/api/projects/[id]/line-items/import/`, `web/src/lib/server/import/` | DC-06-015, DC-06-016 | P0 | M | Opus | 5,000행 30초 안 반영. 체크섬 오류 12행 건너뜀 + 오류 CSV. 주민등록번호 패턴 셀 행 거부. 5,001행 422, 5MB 초과 413. `dry_run=true`에서 쓰기 0 | DC-F-028, `04_API.md:36`, `:53` |
| DC-06-038 | 앱 셸과 화면 1: 사이드바, 대시보드(`/app`), 거래처, 프로젝트 목록·만들기·홈, 설정(워크스페이스, 회사, 직인, 문서번호, AI 처리 방식) | `web/src/app/(app)/layout.tsx`, `web/src/app/(app)/dashboard/`, `web/src/app/(app)/settings/`, `web/src/app/(app)/parties/`, `web/src/app/(app)/projects/page.tsx`, `web/src/app/(app)/projects/new/`, `web/src/features/{parties,projects,settings}/` | DC-06-011, DC-06-014, DC-06-015, DC-06-016 | P0 | L | Sonnet | `03_SCREENS_UX.md:27-80` 경로·역할 접근 일치(viewer는 쓰기 버튼 숨김). 375/768/1024/1440px 깨짐 0. 빈 상태 문구 전부. `DC006` 잠금 안내 문구 `03_SCREENS_UX.md:1107` | DC-F-002~004, SellingDocs 5장 #10, flora 5장 #9 |
| DC-06-039 | 화면 2: 체크리스트 마법사 3단계 + 효과 미리보기 패널, 요구사항 보드(키보드 대안 이동), 산출물, 비용 항목과 합계 | `web/src/app/(app)/projects/[id]/`(`documents/`, `package/`, `exports/`, `trace/`, `uploads/`, `meetings/`, `wiki/` 제외), `web/src/features/checklist/`, `web/src/features/requirements/`, `web/src/features/costs/` | DC-06-011, DC-06-018 | P0 | L | Sonnet | 필수 12개 중 9개 답 → 진행률 75%와 누락 링크 3개. 새로고침 후 답 유지(디바운스 800ms). "결제" 미리보기에 "요구사항 3, 화면 2, 비용 1, 조항 1". 금액 열 tabular 숫자·오른쪽 정렬. 사용자 수정 행의 "출처 체크 해제됨" 경고 | DC-F-005~009, `03_SCREENS_UX.md:252-348` |
| DC-06-040 | 문서 편집기: Tiptap 섹션 노드, 고정 섹션 잠금, 변수 칩, 선택영역 툴바(`docs.assist`), Diff 카드(적용/취소), lint·compliance 패널, 저장(서버 sanitize 결과로 갱신), 채팅·마이크 장착 지점 | `web/src/features/editor/`, `web/src/app/(app)/projects/[id]/documents/[did]/`(`versions/` 제외) | DC-06-011, DC-06-025, DC-06-028 | P0 | L | Opus | 잠긴 금액 셀 편집 불가 + "비용 항목에서 수정" 링크. Diff 적용 시 해당 섹션만 새 버전. `dev_contract`에서 AI 툴바 0. 생성 중 문서는 읽기 전용. 클라이언트 HTML을 렌더로 보내는 경로 0 | DC-F-013, flora 3장 #10, SellingDocs 5장 #9, 1.1절 I-14 |
| DC-06-041 | 화면 3: 문서 목록(재생성 필요 배지), 패키지 생성기(예상 크레딧, 자식 진행 Realtime), 버전 이력·비교, 확정 대화 상자(게이트·WARN 확인), 개정본, 고위험 고지 모달, 내보내기 기록 | `web/src/app/(app)/projects/[id]/documents/page.tsx`, `.../package/`, `.../exports/`, `web/src/app/(app)/projects/[id]/documents/[did]/versions/`, `web/src/features/documents/`, `web/src/features/exports/` | DC-06-011, DC-06-027, DC-06-028, DC-06-029 | P0 | L | Sonnet | 잔액 20에서 패키지 버튼 옆 "8 크레딧 부족" 안내. 자식 완료마다 1초 안 진행 갱신. WARN 확정은 체크박스 없이 버튼 비활성. 고지 모달 문구 = `01_PRD.md:421`. 상태 lozenge 아이콘 + 텍스트 | DC-F-012, DC-F-014, DC-F-015, DC-F-020, `03_SCREENS_UX.md:349-495`, `:630-639` |
| DC-06-042 | 화면 4: 추적표 보기(빈칸 강조), 자료 올리기·색인 상태, RFP 추출 검토(후보 채택·거절, 근거 인용), 회의 녹음·업로드·회의록 화면 | `web/src/app/(app)/projects/[id]/trace/`, `.../uploads/`, `.../meetings/`, `web/src/features/{trace,uploads,meetings}/` | DC-06-011, DC-06-023, DC-06-024, DC-06-030 | P0 | M | Sonnet | 빈칸 셀은 색 + 아이콘 + 텍스트. 녹음 전 제3자 고지 매번 표시(`01_PRD.md:397`). 후보마다 근거 쪽 번호 표시. 마이크 없이 텍스트 붙여넣기 경로 노출 | DC-F-017, DC-F-021, DC-F-022, DC-F-026, `03_SCREENS_UX.md:496-558` |
| DC-06-043 | 화면 5: 채팅 패널(스트리밍, 출처 칩, AI 생성 표시, 크레딧 안내, 대체·근거 없음 상태), 대화 목록, 음성 버튼 장착, 위키 목록·페이지·이력·점검 | `web/src/features/ai-chat/`, `web/src/features/wiki/`, `web/src/app/(app)/chat/`, `web/src/app/(app)/projects/[id]/wiki/` | DC-06-011, DC-06-034, DC-06-035, DC-06-036 | P0 | M | Sonnet | 375px 전체 화면 시트, `aria-live`. 402 충전 모달. 버전 충돌 모달. 편집기 장착은 040 파일에 1줄 요청 | DC-F-023, DC-F-024, DC-F-027, `03_SCREENS_UX.md:559-600` |
| DC-06-044 | 메인페이지(랜딩)와 요금 페이지: 03장 4절 토큰·레이아웃 안, 히어로 오버레이에 045 장착, 샘플 PDF는 "예시" 표기 | `web/src/app/(marketing)/`(`legal/` 제외), `web/src/features/landing/` | DC-06-011, DC-06-045 | P0 | M | Sonnet | 03장 4.7절 카피만 사용, 금지 문구 점검 0건(`01_PRD.md:404-417`). 레퍼런스는 `03_SCREENS_UX.md:894-900`의 URL만. 가상 후기·허위 수치 0. 요금 표가 `01_PRD.md:277-324`과 일치 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/file/03-설계/디자인/REFERENCES.md:16-23`). | DC-F-041, SellingDocs 5장 #10 |
| DC-06-045 | 3D 히어로: 체크 → 서류 낱장 → 묶음 → 직인(PC·태블릿 풀 3D, 모바일 절충, 정지 이미지 대체, 킬 스위치) + 3D 영상 레이어(DC-F-049: 장면 오프라인 렌더 → hero-loop MP4·WebM·모바일·포스터, 단계 선택 실시간 3D → 영상 → 정지 이미지, 영상 킬 스위치) | `web/src/features/hero3d/`, `web/public/hero/`, `scripts/nomad-docs/hero-record/` | DC-06-011 | P1 | L | Sonnet | `docs/file/03-설계/디자인/HERO_3D.md:70-75` 수용 기준 전부. three.js import가 이 디렉토리 밖에 0. 토큰 밖 3D 색 0. `NEXT_PUBLIC_HERO3D_ENABLED=false`에서 정지 이미지 | DC-F-041, `03_SCREENS_UX.md:1005-1055` |
| DC-06-046 | 법무 페이지·고지문·문구 사전: 이용약관, 개인정보처리방침(국외 이전 표), AI 생성물 안내, 계약서 초안 고지, 고지문 버전 상수 4종, 금지 문구·접근성 점검표 | `web/src/app/(marketing)/legal/`, `web/content/legal/`, `web/src/copy/`, `docs/nomad-docs/checklists/` | DC-06-004 | P0 | M | Haiku | `01_PRD.md:381-430` 항목 전부 반영, "법률 자문이 아닙니다" 문구, 고지문 버전이 env(`DOCS_RISK_NOTICE_VERSION` 등)와 일치. 금지 문구 검색 0건, 이모지 0. 법무 검토 필요 표시 | DC-F-020, DC-F-041, `01_PRD.md:404-430` |
| DC-06-047 | Toss 결제: 크레딧팩 주문·confirm, Pro 빌링키·구독 해지, Toss 웹훅(서명·멱등), 결제 화면(`/app/billing`) | `web/src/app/api/billing/`, `web/src/app/api/webhooks/toss/`, `web/src/app/(app)/billing/`, `web/src/features/billing/` | DC-06-012, DC-06-013 | P0 | L | Fable | 테스트 키 `pack_100` → 잔액 +100, grant 1행. 같은 confirm 재호출 지급 1회. 금액 변조 `PM001` + `fail_payment_order` + 운영 알림. 위조 웹훅 401. 브라우저 `rpc('grant_credits')` 42501 | DC-F-038, SellingDocs 5장 #13, flora 5장 #2 |
| DC-06-048 | 결제 E2E(Toss 테스트 키): 팩 구매, Pro 구독, 정기결제 실패 → past_due, 해지, 금액 변조 | `web/e2e/billing/` | DC-06-047 | P0 | M | Opus | 시나리오 5개 통과, 원장 drift 0, 각 시나리오 잔액 기대값 일치 | SellingDocs 5장 #13, flora 5장 #2 |
| DC-06-049 | 운영자 카탈로그 관리: 유형 버전·체크리스트 항목(effects 스키마 검증)·조항 초안 → 샘플 프로젝트 미리보기 → 게시(service_role, 불변), 운영 상한 `/admin/ops` | `web/src/app/admin/`, `web/src/app/api/admin/`, `web/src/lib/server/catalog/` | DC-06-013, DC-06-017, DC-06-020 | P0 | M | Fable | 일반 사용자 `/admin` 403. effects 스키마 위반 게시 422. 게시 버전 수정 409 `DC003`. 체크섬 불일치 422. 출처 메모 없는 조항 게시 불가. 게시·폐기마다 감사 1행 | DC-F-040, `04_API.md:92`, `03_SCREENS_UX.md:652-662` |
| DC-06-050 | KPI 이벤트와 집계 쿼리: 활성화(30분 안 첫 패키지), 확정률, 편집 거리, 생성 성공률, 유료 전환, 체크리스트 완료율, 후보 채택률, 환불 비율, 미정산 `ai_usage` | `web/src/lib/server/kpi/`, `scripts/nomad-docs/kpi/` | DC-06-027 | P1 | S | Haiku | `01_PRD.md:442-461` 지표 14개마다 읽기 전용 SQL 1개 이상, 대상 테이블·기간이 표와 일치. 이벤트에 문서 본문·개인정보 0 | `01_PRD.md` 7장 |
| DC-06-051 | 계정 데이터 내보내기·삭제와 정리 스케줄: 조직 JSON + 확정 PDF ZIP, soft delete → 30일 → `purge_organization`, 내보내기 30일 만료, 회의 녹음 원본 24시간 삭제, 업로드 원본 90일 | `web/src/app/api/account/`, `worker/src/handlers/purge.ts`, `worker/src/cron/` | DC-06-005, DC-06-029 | P1 | M | Fable | 삭제 요청 30일 뒤 조직 `docs` 행 0, Storage 객체 0, 감사 기록 유지. 녹음 원본 완료 24시간 뒤 0개. 유예 중 로그인 복구 가능. 공개 크론 라우트 0(워커 스케줄) | DC-F-042, `01_PRD.md:371-376`, `02_ARCHITECTURE.md:241-247` |
| DC-06-052 | 연동 어댑터 프레임워크(Phase 2): `IntegrationAdapter`·Canonical 타입, 필드 매핑 적용, `applyCanonical` + `docs.upsert_external_ref`, 연결·콜백·매핑·동기화·해지 API, `integration.sync` 핸들러, 수신 웹훅 디스패처 | `int/src/{types,canonical,mapping}/`, `int/tests/`, `web/src/app/api/integrations/`(`inbound/` 제외), `worker/src/handlers/integration-sync.ts` | DC-06-001, DC-06-012 | P2 | L | Opus | 같은 외부 id 2회 pull에도 내부 1행. etag 같으면 건너뜀, 내부 수정 뒤 외부 변경은 덮지 않고 `conflicts` +1. 해지 후 동기화 409 `DC009`. OAuth state 재사용 `OA001`. 자격증명 평문 0 | DC-F-030~032, `02_ARCHITECTURE.md:162-198` |
| DC-06-053 | 발신 웹훅과 n8n(Phase 2): 엔드포인트 등록(https, 사설 IP 거부, 발송 직전 DNS 재검사), 이벤트 emit, `webhook.deliver`(HMAC, 5회 재시도), 수신 `/api/integrations/inbound/[endpointToken]`(토큰 해시 + HMAC + `event_id` 멱등) | `web/src/app/api/webhook-endpoints/`, `web/src/app/api/integrations/inbound/`, `web/src/lib/server/events/`, `worker/src/handlers/webhook-deliver.ts`, `int/src/{make,n8n}/` | DC-06-052 | P2 | M | Opus | `https://10.0.0.1/`, `localhost`, DNS가 사설 IP로 풀리는 호스트 전부 422 또는 발송 차단. 수신 측이 `X-Signature` 검증 성공. 5회 실패 후 `failing`. 같은 `event_id` 재전송 1회만 반영. 본문에 연락처·문서 본문 0 | DC-F-029, DC-F-032, `04_API.md:189-202`, flora 3장 #2, #5 |
| DC-06-054 | HubSpot 어댑터(Phase 2, D-6): OAuth, 딜·회사·연락처 pull, 확정 문서 링크 push, 딜 단계 웹훅 → "문서 생성 제안" 알림(자동 생성 0) | `int/src/hubspot/` | DC-06-052 | P2 | M | Opus | 엔드포인트·스코프·서명 방식을 HubSpot 공식 문서로 확인한 기록(미확인 해소). 서명 불일치 401. 딜 단계 변경 후 생성 run 0. 429는 `Retry-After` 준수 | DC-F-030, `04_API.md:220-228` |
| DC-06-055 | admin-suite ERP 어댑터(Phase 2): service_role 함수로 `erp.products`(단가) → 비용 카탈로그, `erp.sales` → `invoice` 입력, 같은 org + 두 앱 엔타이틀먼트 검사(C-7 뒤, DB 함수는 001에 요청) | `int/src/admin-suite-erp/` | DC-06-052, DC-06-001 | P2 | M | Fable | docs만 쓰는 조직은 연결 422 `entitlement_missing`. 사용자 세션의 `erp` GRANT 0(003 회귀). `price numeric(12,2)` → 원 정수 반올림. `total_price` 불일치 시 경고 | DC-F-031, `04_API.md:230-236`, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql:113`, `:154` |
| DC-06-056 | web 통합 테스트: 무세션 401, 402 `details`, 크레딧 동시성 50회, 레이트 리밋, 생성·추출·렌더 실패 환불, DC001~DC010 각 1개 이상, sanitize, PII lint, 금액·번호 본문 무시 | `web/tests/integration/` | DC-06-027, DC-06-028, DC-06-029, DC-06-037 | P0 | M | Opus | 동시 consume 50회 음수 잔액 0, drift 0. 실패 경로마다 환불 행 1개. SQLSTATE 10종 매핑 HTTP 일치 | SellingDocs 5장 #14 |
| DC-06-057 | 핵심 플로우 E2E: (a) 첫 로그인(Stage A는 `no_app` 페르소나, 063 후 스테이징은 이메일 가입) → AI 온보딩 → 회사 정보 → 프로젝트 → 체크리스트 → 패키지 → 확정 → PDF (b) RFP → 추출 → 확인 → 효과 → 재생성 (c) 회의 텍스트 → 회의록 → 후보 수락 (d) 채팅 1턴(목 제공자) (e) 3D 히어로 3기기 렌더 스모크. Playwright `globalSetup`(`web/e2e/flows/global-setup.ts`, Playwright 설정 등록은 004에 1줄 요청)이 페르소나마다(`no_app` 제외, 03장 7.3절) `/api/dev/login`으로 `storageState`를 만든다 | `web/e2e/flows/` | DC-06-038~DC-06-044, DC-06-047 | P0 | M | Opus | Mock 페르소나 storageState로 로컬에서 5개 플로우 통과(G1 근거, W6 종료 직후 먼저), DC-06-063 완료 후 스테이징에서 재실행해 통과. (a)는 30분 KPI 목표 경로를 10분 안에 완주(자동화). 새로고침 후 세션 유지. `outsider`로 owner 조직 프로젝트·문서 URL 직접 접근 404 | `03_SCREENS_UX.md` 2절, AUTH_ROADMAP 2.1절 E2E 행 |
| DC-06-058 | AI·음성 보안·라우팅 회귀: 서명 토큰 위조·만료·재사용, 대화 매핑, 국외 동의 필터, 강제 오픈소스(`meeting_minutes`, `docs.minutes`, `dify.aux`), 고위험 문서 LLM 0, 선차감·정산·환불, 라우팅 seed 스냅샷 | `api/tests/docs/security/`, `web/e2e/ai/`, `scripts/nomad-docs/ai-routing/` | DC-06-024, DC-06-025, DC-06-033, DC-06-034, DC-06-036 | P0 | M | Fable | `resolve_ai_route` 스냅샷(13행 × 동의 유/무)이 seed와 일치(1.1절 I-9). 위조 토큰 401, 타인 대화 404, 미동의 조직 상용 0, `dev_contract` LLM 행 0, 원장 drift 0. 실패 시 병합 차단 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:278-305` |
| DC-06-059 | 배포 설정: Vercel(web), Railway(worker, api), 렌더 서비스 private network 연결(`RENDER_SERVICE_URL`, `X-Render-Token`), env 문서 | `infra/nomad-docs/`, `docs/nomad-docs/ops/env.md` | DC-06-005, DC-06-006 | P0 | S | Sonnet | env 문서 = `02_ARCHITECTURE.md` 8절 + 9.3절(`AUTH_MODE`, `AUTH_PROVIDERS`, `DOCS_TERMS_VERSION`, 누락 0). 배포 환경은 Mock 금지(`AUTH_MODE=live`)이므로 Stage A 동안은 스테이징 헬스체크·로그인 없는 화면까지 확인하고, 스테이징 가입 → PDF 1회 성공은 DC-06-063 완료 후 확인. 렌더 서비스 공개 URL 호출 불가 확인 | flora 5장 #5, #15, SellingDocs 3장 #1 |
| DC-06-060 | shorts_agency 패키지(Phase 2, DC-F-046, 확정 결정 21): content 체크리스트 14개 게시(효과 스키마 검증, `catalog:<key>` 단가 해석), 템플릿 7종(`content_brief`, `video_service_contract`, `channel_access_mandate`, `brand_guide_ack`, `ad_disclosure_checklist`, `monthly_report`, `service_intro`) v1, lint `L-NO-GUARANTEE`·`L-AD-DISCLOSURE`, 패키지 단계(`01_PRD.md` 3.5.1절), 위임 동의서 고지문 상수, 월간 리포트 KPI 입력(수동·CSV). 계약 템플릿·lint는 Opus가 직접, 나머지 화면·설정은 Sonnet 보조 | `tpl/content_brief/` 외 6개, `web/src/features/effects-engine/`(catalog 토큰만), `web/src/app/api/projects/[id]/packages/`(package_code 분기), `api/app/ai/products/docs/rules/`(lint 2종) | DC-06-020, DC-06-021, DC-06-027, DC-06-049 | P2 | L | Opus | content 프로젝트 체크리스트에 dev 전용 항목 0개. 월 12편 × 130,000원이 quote·sow·video_service_contract에 같은 값. `delivery.naver_clip_upload` 켜면 `vsc.automation_risk`·제약 요구사항 생성. 성과 보장 문구가 있는 계약서 확정 시 `DC005`. 업로드 대행 끄면 패키지 5종·18크레딧. 계약서·위임 동의서는 D-3·D-15 전 `is_active=false` 유지. RLS 러너 두 대상 통과 | `01_PRD.md` DC-F-046, 3.1.1·3.3.1·3.5.1·6.4절, `2300_docs.sql` 25절 |
| DC-06-061 | CRM형 워크스페이스(DC-F-047): AppShell 확장(왼쪽 내비·상단 명령 막대), 커맨드 팔레트(⌘K), 파이프라인 보드·표(`/app/pipeline`, 뷰 `docs.project_pipeline`, Realtime `documents`로 카드 이동), 거래처 360(RecordSidebar·ActivityTimeline, 뷰 `docs.project_activity`), API `GET /api/pipeline`·`/api/search`·`/api/{projects,parties}/[id]/activity` | `web/src/features/pipeline/`, `web/src/app/(app)/pipeline/`, `web/src/app/api/pipeline/`, `web/src/app/api/search/`, `web/src/app/api/projects/[id]/activity/`, `web/src/app/api/parties/[id]/activity/` | DC-06-011, DC-06-012, DC-06-038 | P0 | M | Sonnet | 견적서 확정 후 새로고침 없이 카드가 quoted 열로 이동. 다른 조직 프로젝트·거래처·문서가 보드·팔레트·타임라인에 0건(E2E + RLS 러너 뷰 항목). 끌어 놓기로 단계가 바뀌지 않는다. 키보드만으로 팔레트 → 프로젝트 → 문서 생성. 50카드 보드 첫 렌더 p95 1.5초. 거래처 상세(038 소유 화면)는 이 작업의 RecordSidebar·ActivityTimeline 컴포넌트를 쓴다 | `03_SCREENS_UX.md` 3.26절, `01_PRD.md` DC-F-047 |
| DC-06-062 | 문서 생성 단계별 진행 애니메이션(DC-F-048): GenerationProgress(StageRail·SectionLane·SheetAssembler), 단일 오버레이와 패키지 레인, Realtime `generation_runs.progress` 구독(끊기면 3초 폴링), 대기 중 [취소](`/api/generation-runs/[id]/cancel` → `docs.cancel_generation`), 상단 진행 칩, reduced-motion·`aria-live` | `web/src/features/progress/` | DC-06-011, DC-06-022, DC-06-027 | P0 | M | Sonnet | E2E에서 stage 순서(queued → collecting → drafting → assembling → linting → done)가 서버 progress와 같다. 시간 기반 가짜 진행률 0(코드 검사). 대기 중 취소 → 환불 표시 → 같은 문서 즉시 재생성 가능. reduced-motion에서 애니메이션 0. transform·opacity 외 애니메이션 속성 0 | `03_SCREENS_UX.md` 3.27절, `01_PRD.md` DC-F-048 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 004, 005, 008 | 4 | 없음 | DB 조각 적용, 타입, web·워커 골격, 디자인 레퍼런스(1단계) |
| W1 | 002, 003, 006, 007, 012, 013, 017, 020, 046 | 9 | W0 완료 | 모놀리스 변환, RLS 러너, ai-service, CI, API 공통, 단가·features, 효과 엔진, 템플릿 9종, 법무 문구 |
| W1-D | 009 → 010 → 011(직렬) | 1 | 004, 008 완료 | 디자인 시스템 2~4단계. 010은 사람이 수행. 011 완료가 모든 화면 작업(038~045)의 진입 조건 |
| W2 | 014, 015, 016, 019, 021, 031, 033, 047 | 8 | W1 완료 | 인증 Stage A(Mock 로그인·시드·가드, 8.2절), 워크스페이스·거래처, 정본 API, 효과 엔진 속성 테스트, compliance·lint, 업로드, AI 게이트, 결제 |
| W3 | 018, 022, 028, 032, 036, 037, 038, 045, 049, 059 | 10 | W2 완료, 038·045는 011 완료 | 효과 적용, 생성 그래프, 문서 API, RAG, 음성, CSV, 화면 1, 3D 히어로(+ 3D 영상), 운영자 카탈로그, 배포 |
| W4 | 023, 024, 025, 027, 029, 030, 035, 039, 044, 048, 061, 062 | 12 | W3 완료. 029의 DOCX는 C-1 반영 전 비활성으로 진행 | 추출·회의록·다시 쓰기 그래프, 생성 요청·패키지, 내보내기, 추적표, 위키, 화면 2, 랜딩, 결제 E2E, CRM 워크스페이스, 생성 진행 애니메이션 |
| W5 | 026, 034, 040, 041, 042, 051 | 6 | W4 완료 | 골든·평가, Dify 채팅, 편집기, 화면 3·4, 계정 삭제·정리 |
| W6 | 043, 050 | 2 | W5 완료 | 화면 5(채팅·위키), KPI |
| W7 | 063(G1 통과 후 먼저), 056, 057, 058 | 4 | W6 완료. 063은 G1 통과(`[DECISION] G1 통과`) 후 시작하고 056·057·058의 공개 베타 마무리(스테이징·B 구성 재실행)는 063 완료를 기다린다. G1 근거인 Mock 핵심 플로우 E2E는 057이 W6 종료 직후 로컬에서 먼저 녹색으로 만든다(8.2절) | Google 로그인 전환(Stage B), 통합·E2E·AI 회귀. 녹색이면 공개 베타(MVP). `dev_contract` 활성은 D-3 법무 검토 완료가 별도 조건 |
| W8 | 052 → 053, 054, 055, 060 / 064, 065(G2 통과 후) | 1 → 4, 064·065 병렬 2 | MVP 출시 후, team 플랜(C-5) 준비. 064·065는 G2 통과(`[DECISION] G2 통과`) 후, 둘은 병렬 가능(네이버 검수 신청은 G2 직후) | 연동 프레임워크, 발신 웹훅·n8n, HubSpot, admin-suite ERP, shorts_agency(Phase 2), 카카오 로그인(C1), 네이버 로그인(C2) |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 16 (001, 003, 006, 013, 014, 018, 022, 027, 033, 047, 049, 051, 055, 058, 063, 065) | 24.6% | 36 / 142 = 25.4% |
| Opus | 33 (002, 004, 005, 011, 012, 015, 016, 017, 019, 020, 021, 023, 024, 025, 026, 028, 029, 030, 031, 032, 034, 035, 036, 037, 040, 048, 052, 053, 054, 056, 057, 060, 064) | 50.8% | 74 / 142 = 52.1% |
| Sonnet | 14 (007, 008, 009, 010, 038, 039, 041, 042, 043, 044, 045, 059, 061, 062) | 21.5% | 29 / 142 = 20.4% |
| Haiku | 2 (046, 050) | 3.1% | 3 / 142 = 2.1% |
| 합계 | 65 | 100% | 142 |

비율은 작업 65개 기준이다(2026-10-14 갱신: DC-06-010은 판정을 사람이 하지만 준비 작업 모델을 Sonnet으로 적는다. DC-06-060은 Opus 주도, 061·062 Sonnet 추가. 인증 단계 3개 추가: 063·065 Fable M, 064 Opus S. 그 전 62개는 Fable 22.6%, Opus 51.6%, Sonnet 22.6%, Haiku 3.2%, 가중 137). 규모 내역: Fable M 12·L 4, Opus S 3·M 19·L 11, Sonnet S 3·M 7·L 4, Haiku S 1·M 1. Fable은 DB·RLS·결제·크레딧 차감 경로(013, 027, 033, 047), 권한 경계(006, 014, 049, 055, 인증 Stage B 063, 네이버 세션 발급 경로 065), 체크리스트 효과의 원자 적용(018), 고위험 문서 규칙이 걸린 생성 그래프(022), AI 보안 회귀(058), 개인정보 삭제(051)를 맡는다. 나머지 그래프·RAG·위키·Dify·음성·편집기는 Opus, 화면·3D 히어로·디자인 시스템 구현은 Sonnet이다(`DOC_TEMPLATE.md:253`). Haiku 비율이 낮은 이유: 타입 생성은 001, 반복 점검은 CI(007)가 맡아 남는 보일러플레이트가 적다.

## 5. 리뷰 작업 흡수표

대상은 이식 원천 리뷰 중 "높음" 차단 대상과 같은 두 리뷰다(`README.md:31-36`). `docs/reference/reviews/SellingDocs.md` 5장 14건(`:112-125`)과 `docs/reference/reviews/flora.md` 5장 15건(`:149-163`), 합계 29행. 이 제품은 원본 코드를 고치지 않으므로 "흡수"는 같은 결함이 재발하지 않게 하는 작업을 뜻한다. 폐기된 원천 기능에 관한 항목은 "해당 없음"과 이유를 적는다(07장 3절).

| 리뷰 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| `docs/reference/reviews/SellingDocs.md` 5장 #1 | PDF 엔진 결정과 데이터 모델 v2 | DC-06-001(데이터 모델은 `2300`으로 확정), DC-06-029(공용 WeasyPrint 렌더 소비), 코어 요청 C-1 |
| SellingDocs 5장 #2 | `Claude.md` 작성 | 이 폴더 `CLAUDE.md`, DC-06-004(`web/CLAUDE.md`), DC-06-007(빈 파일 CI 검사) |
| SellingDocs 5장 #3 | 골격 복제, shadcn, Supabase 클라이언트·proxy·auth callback 이식 | DC-06-004, DC-06-009(shadcn/ui), DC-06-014(Stage A, `finishLogin`), DC-06-063(Stage B 콜백) |
| SellingDocs 5장 #4 | 마이그레이션(profiles, books, chapters, credit_logs, exports, 차감 RPC) | DC-06-001(코어 원장·`generation_runs`·`document_versions`·`doc_exports`), DC-06-003 |
| SellingDocs 5장 #5 | 목차 → 챕터별 생성 라우트(차감·환불) | DC-06-027(문서 1개 = 잡 1개, 패키지 부모·자식), DC-06-022(섹션 단위 생성) |
| SellingDocs 5장 #6 | WeasyPrint Docker 서비스 + export/pdf | DC-06-029(컨테이너는 flora-publishing 소유 공용 서비스, docs는 소비자), DC-06-026(한글 골든) |
| SellingDocs 5장 #7 | export/epub 라우트 | 해당 없음: 업무 문서 제품이라 ePub을 만들지 않는다(07장 3절 DS-04). 형식은 PDF·DOCX·ZIP |
| SellingDocs 5장 #8 | 판형 프리셋 + Paged Media CSS | DC-06-020(A4 공문서 CSS, `@page`, 쪽번호 "n / N"), 코어 요청 C-1(A4 프리셋) |
| SellingDocs 5장 #9 | Tiptap 편집기, 자동 저장, sanitize | DC-06-040, DC-06-028(서버 sanitize, `expected_version`) |
| SellingDocs 5장 #10 | 대시보드, 크레딧 모달, 랜딩 | DC-06-038, DC-06-041(예상 크레딧·부족 안내), DC-06-044 |
| SellingDocs 5장 #11 | QuickChart 차트 삽입 | 해당 없음: 차트 삽입 없음. 사용자 데이터 외부 전송 위험으로 폐기(07장 3절 DS-13). 문서의 표는 HTML table |
| SellingDocs 5장 #12 | 공개 서가 + JSON-LD | 해당 없음: 공개 서가·GEO 없음(07장 3절 DS-14). 읽기 전용 외부 공유 링크는 DC-F-037(Phase 2)이며 이 계획에 작업으로 배정하지 않았다(제안: Phase 2 착수 때 추가) |
| SellingDocs 5장 #13 | 결제 + 웹훅 서명 | DC-06-047(Toss), DC-06-048 |
| SellingDocs 5장 #14 | 크레딧 동시성 테스트, env zod | DC-06-056, DC-06-004, DC-06-005 |
| `docs/reference/reviews/flora.md` 5장 #1 | 백엔드 인증 통합, `/debug-api-keys` 삭제 | DC-06-012(`requireSession` 래퍼 강제), DC-06-006(ai-service 서명 토큰), DC-06-033. 디버그 엔드포인트는 이식하지 않는다(07장 3절 DS-20) |
| flora 5장 #2 | 결제 웹훅 서명 검증, `user_plans` RLS SELECT 전용 | DC-06-047(Stripe 대신 Toss, 서명·멱등), DC-06-003(사용자 플랜 쓰기 42501), DC-06-013 |
| flora 5장 #3 | 파일/URL 하드닝(업로드 파일명, `cover_url`, `url_fetcher`, 로컬 경로) | DC-06-031(서버 생성 경로, 매직바이트), DC-06-029(서버 조립 HTML만 렌더, `url_fetcher`는 렌더 소유자), DC-06-053(웹훅 URL SSRF). 레퍼런스 WAV 업로드는 해당 없음(07장 3절 DS-07) |
| flora 5장 #4 | 동기 호출 비동기화 | DC-06-006(비동기 클라이언트만, 동기 import 검사), DC-06-022, DC-06-031(파싱 스레드풀) |
| flora 5장 #5 | 배포 설정 복구(Dockerfile 폰트, deploy.yml, Python 버전) | DC-06-059, DC-06-007(actionlint), DC-06-026(한글 골든). 렌더 이미지 폰트는 공용 렌더 소유자(코어 요청 C-1에 DOCX 폰트 검사 포함) |
| flora 5장 #6 | 의존성 재생성, 로깅, mock은 dev만 | DC-06-006(lockfile, 구조화 로그), DC-06-012(mock 응답 금지), DC-06-007 |
| flora 5장 #7 | AI 고도화 파이프라인 수정, build-html escape | DC-06-025(선택 영역 전체, 초과 422), DC-06-020(Jinja autoescape), DC-06-028(sanitize) |
| flora 5장 #8 | 플랜 제한 서버 강제 | DC-06-013, DC-06-001(`enforce_project_limit`, `start_generation`의 `doc_phase`), DC-06-003 |
| flora 5장 #9 | 4,095줄 페이지 분해 | DC-06-038, DC-06-039, DC-06-040, DC-06-041(기능 디렉토리 단위 분할. 원본 페이지는 이식하지 않음, 07장 3절 DS-21) |
| flora 5장 #10 | `lib/api.ts` 확장(토큰 주입, 타입) | DC-06-012(`apiFetch`, raw `fetch` 린트 차단) |
| flora 5장 #11 | TTS 산출물 Storage 저장 | 해당 없음: 낭독·오디오북 기능이 없다(07장 3절 DS-07). 음성 대화의 읽어 주기는 저장하지 않는 스트림(DC-06-036, `store_audio=false`) |
| flora 5장 #12 | waitlist 경로·테이블·시드 수치 제거 | 해당 없음: 대기자 명단 기능이 없다(07장 3절 DS-22). 허위 수치 금지는 DC-06-046 점검표가 맡는다 |
| flora 5장 #13 | `db.py` 오류 처리, ePub uuid5 | DC-06-012(`P0002` → 404, `.single()` 500 금지). ePub uuid5는 해당 없음(07장 3절 DS-04) |
| flora 5장 #14 | `f5-tts/` 벤더링 제거 | 해당 없음: F5-TTS를 쓰지 않는다(비상업 라이선스, 07장 3절 DS-07). 음성은 core-voice(DC-06-036) |
| flora 5장 #15 | 문서·잡파일 정리, 프론트 `.env` 키 제거 | DC-06-004(`.gitignore`, env 비커밋), DC-06-007(비밀 검사), DC-06-059(env 문서) |

행 수 29 = 리뷰 5장 작업 수 29(SellingDocs 14, flora 15). 흡수 23행(SellingDocs 11, flora 12, 일부 하위 항목이 해당 없음인 행 포함), 해당 없음 6행(SellingDocs #7, #11, #12, flora #11, #12, #14).

## 6. 공용 모듈 요청

코어 변경은 제품이 하지 않는다. C-1~C-7은 설계 기준서 12장, C-8 이후는 이번 계획에서 추가로 찾은 것이다.

| ID | 요청 | 이유 | 대상 | 막히는 작업 / 우회 |
|---|---|---|---|---|
| C-1 | 공용 렌더 서비스에 `POST /render/docx`(python-docx/docxtpl) 추가, `RenderPdfRequest.app_id`에 `'docs'` 추가, A4 공문서 프리셋(머리말·꼬리말, 쪽번호 "n / N", 간인 표시 옵션), DOCX 경로에도 기동 폰트 검사, 렌더 큐 이름 확정(제안 `docs.render`) | DC-F-018 DOCX와 공문서 서식(`04_API.md:174-187`) | `services/render-weasyprint`(flora-publishing 소유), `SHARED_MODULES.md` 10장 | 029의 DOCX. 반영 전 403 `format_unavailable`, PDF는 기존 `/render/pdf` |
| C-2 | 조직 API 키 모듈(해시 저장, 스코프, 회수) | 공개 REST API(DC-F-033, Phase 3) | `_platform-core` | Phase 3. 그 전 작업 없음 |
| C-3 | 모듈러 `seed.sql`에 `docs` 앱·플랜·크레딧팩 행 추가(제품은 모놀리스 seed만 소유) | seed 실행 순서에 따라 조각의 `@monolith-seed` 보충이 덮일 수 있다(`05_DATA_MODEL.md:886`) | `_supabase-modular/seed.sql` | 반영(2026-10-13, seed에 docs 앱·플랜 3·팩 3 추가). 조각 보충은 그대로 두며 최종 값은 seed |
| C-4 | `docs/file/03-설계/디자인/REFERENCES.md`에 nomad-docs 절(랜딩 + 로그인 후 CRM 패턴 Attio·HubSpot·Pipedrive·Linear, `03_SCREENS_UX.md` 3.26절), `HERO_3D.md`에 제품 소재 행과 "3D 영상" 대체 단계(실시간 3D → 영상 → 정지 이미지, 영상 예산 2MB·모바일 1MB, `03_SCREENS_UX.md` 4.6.1절) 추가 | 랜딩 레퍼런스가 다른 제품 절에서 빌려 왔다(`03_SCREENS_UX.md:892`) | `_design-guide` | 반영(2026-10-14): `REFERENCES.md:309` nomad-docs 절(랜딩·앱 5개 + CRM 서비스 4개, URL 확인), `HERO_3D.md` 5장 소재 행과 6장 영상 단계. 044·045는 이 기준으로 진행 |
| C-5 | 팀 조직 생성 함수(team 플랜) | `members_max` 5, 승인 흐름(Phase 2) | `_platform-core` | W8과 Phase 2 team 플랜 |
| C-6 | core webhooks 아웃바운드 `emit`의 재시도 스케줄·실패 집계 표준화 | 제품 `webhook_deliveries`와 중복 방지(`02_ARCHITECTURE.md:195`) | `_platform-core` webhooks | 053은 제품 테이블로 진행 |
| C-7 | 교차 스키마 읽기 규약(제품 → `erp`) 문서화: service_role 함수, 같은 org + 두 앱 엔타이틀먼트, 사용자 세션 GRANT 금지 | admin-suite ERP 연동(`02_ARCHITECTURE.md:193`) | `_platform-core` DB_CONVENTIONS, admin-suite | 055 |
| C-8 | `core.adjust_credits(p_org_id, p_amount, p_reason, p_ref_type, p_ref_id, p_idempotency_key)`(음수 허용, service_role) | 크레딧팩 환불 시 미사용분 회수, 운영자 수동 조정(`docs/file/03-설계/공용코어/CORE_SPEC.md:242`). 다른 제품과 같은 요청(`D:/WorkSpace/platform/docs/products/README.md:110`) | `_platform-core` credits | 047의 환불 처리. 반영 전 운영자가 Toss 취소만 하고 크레딧 회수는 수동 기록 |
| C-9 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) | 12개 제품이 같은 판정 로직을 따로 만들지 않게(`docs/file/03-설계/디자인/HERO_3D.md:56`) | `_design-guide` | 045는 `hero3d/` 안에 같은 인터페이스로 둔다 |
| C-10 | 공용 Dify에 `docs-chat` 앱 생성, `DIFY_INTERNAL_API_KEY`(docs 전용 값), 로그 보존 30일, 대화 삭제 API 확인. 계정 삭제 시 AI 표 연쇄 + Storage + Dify 대화 정리 절차 | 공용 인프라는 코어 소유(`02_ARCHITECTURE.md:21`, `:332`) | 공용 Dify, `purge_organization` | 034(앱 정의 파일까지만), 051 |
| C-11 | ai-service: (a) OpenAI 호환 `/v1/chat/completions`의 `model`을 기능 키로 해석(`dify.aux` 강제 오픈소스) (b) 위키 사용자 편집 저장 엔드포인트 | Dify 보조 노드 라우팅(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:151`)과 DC-F-024 사용자 편집. flora-publishing R14와 같은 요청 | 공용 ai-service | 034, 035 |
| C-12 | `core.cancel_job`에 역할 검사(owner/admin 또는 잡을 만든 사용자, viewer 거부) 추가 | 지금은 조직 멤버 누구나(viewer 포함) 대기 잡을 취소·환불할 수 있어 `docs.cancel_generation`의 역할 검사를 우회한다(2026-10-14 독립 검토, PGlite 재현). 제품은 `reconcile_generation_runs`로 상태 정합만 지킨다 | `_platform-core` jobs(0005) | 막히는 작업 없음. 반영 전에는 viewer 취소가 가능하다(금전 손실은 없음: 환불은 조직 지갑으로) |

## 7. 완료 정의

| 조건 | 확인 명령·기준 |
|---|---|
| 빌드·타입·린트 | `npm run lint && npx tsc --noEmit && npm run build`(web, worker) 녹색 |
| 단위·속성 테스트 | `npm run test`(Vitest, `web/tests/effects/` 속성 테스트 포함) 녹색 |
| Python | `pytest apps/api -k docs`, `ruff check apps/api` 녹색 |
| SQL(모듈러) | `D:/WorkSpace/platform/docs/products/_tools-sqlcheck`에서 `node check.mjs --vector mod 0000_*.sql ... 0009_*.sql seed.sql 2300_docs.sql` OK |
| SQL(모놀리스) | `node check.mjs --vector mono 0001_core_lite.sql 0002_nomad_docs_domain.sql seed.sql` OK, `node scripts/nomad-docs/to-monolith.mjs --check` 불일치 0 |
| 타입 | `supabase gen types typescript --local --schema core,docs > apps/nomad-docs/src/types/supabase.ts` 결과가 커밋본과 같다(CI 비교) |
| RLS 스모크 | `node scripts/nomad-docs/rls-runner.mjs --target mod`와 `--target mono` 전 항목(105 이상) 통과(DC-06-003) |
| 결제 E2E | `npx playwright test e2e/billing` 5개 시나리오 통과(Toss 테스트 키, DC-06-048) |
| 핵심 플로우 E2E | `npx playwright test e2e/flows` 5개 플로우 통과(DC-06-057, Mock 페르소나로 로컬 먼저, 063 후 스테이징 재실행) |
| 인증 단계 | Stage B: `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 5.3절 B-1~B-6(DC-06-063, B-5 Google 실로그인은 수동 점검표). CI 인증 검사(DC-06-007): 인증 모듈 밖 `AUTH_MODE` 참조 0, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패 |
| AI·음성 | `npx playwright test e2e/ai`, `pytest apps/api/tests/docs/security` 녹색(DC-06-058). 평가셋(hybrid 20, 검색 30, 채팅 30, 추출 10)을 상용·오픈소스 두 경로로 통과. `meeting_minutes`·`docs.minutes` 상용 호출 0 |
| 고위험 문서 | `dev_contract` 생성의 LLM `ai_usage` 0, D-3 법무 검토 완료 전 `doc_types.is_active=false` |
| 3D·디자인 시스템 | `HERO_3D.md:70-75` 수용 기준(DC-06-045), 디자인 시스템 4단계(DC-06-011) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | 2절 P0·P1 작업 전부 완료(P2 = DC-06-052~055, 060 제외). P2는 Phase 2 완료 조건. 8절 인증 단계 작업 중 063(P0)은 MVP 출시 조건이고, 064·065(P1)는 G2 이후 작업이라 MVP 완료 정의에서 제외 |

P0 작업과 대응 테스트 작업:

| P0 작업 | 대응 테스트 작업 |
|---|---|
| 001, 002, 013, 018, 049 | 003, 056 |
| 004, 012, 014(Stage A), 015, 016, 037, 063(Stage B) | 056, 057(Mock 페르소나 storageState, 063 후 스테이징 재실행), 063 수동 점검표(B-5) |
| 017 | 019 |
| 020, 021, 022, 023, 024, 025, 029 | 026, 058 |
| 027, 028, 030 | 056, 057, 026 |
| 006, 031, 032, 033, 034, 035, 036 | 058, 057(032·034는 자체 평가셋 포함) |
| 047 | 048 |
| 038, 039, 040, 041, 042, 043, 044, 046, 061, 062 | 057, 046 점검표 |
| 005, 007, 059 | CI 자체 실행 결과, 스테이징 배포 확인(057) |
| 008, 009, 010, 011 | 디자인 시스템 4단계 문서-코드 일치 검사(011), 010은 사람 검토 기록 |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(9장 작업 계획 반영 규칙, 8장 매트릭스의 nomad-docs 행: `docs`, open, 프리랜서·에이전시, A 추가 페르소나 없음, B Google + 이메일, C1 P1, C2 P1)다. Stage A는 기존 DC-06-014가 맡고(2절에서 범위 변경), 아래 3개를 새로 더한다. 작업 ID는 기존 최대 062 다음부터.

### 8.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| DC-06-063 | 인증 Stage B: Google OAuth 전환 + 이메일 가입·메일 인증·비밀번호 재설정 화면, `/auth/callback`(`finishLogin` 연결), 첫 OAuth 로그인 뒤 약관 동의 단계(`/onboarding/terms`, 온보딩 경로 계산에 약관 단계 추가), 배포 체크리스트(Google 콘솔·Supabase Providers·Redirect URLs·`AUTH_PROVIDERS`), Google 실로그인 수동 점검표 | `web/src/app/(auth)/`(014에서 이어 받음: login B 구성, signup, reset-password), `web/src/app/auth/callback/`, `web/src/app/onboarding/terms/`, `web/src/features/onboarding-terms/`, `web/src/app/api/terms/`, `web/src/lib/auth/onboarding.ts`(014 완료 후 이 파일만 이어 받음), `supabase/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`(001 완료 후 이 절만 이어 받음), `docs/nomad-docs/ops/auth-checklist.md` | DC-06-014, DC-06-033, DC-06-046, DC-06-059. 진입 조건 G1(`[DECISION] G1 통과`) | P0 | M | Fable | AUTH_ROADMAP 5.3절 그대로: B-1 새 Google 계정 첫 로그인 → `session_context('docs')` `entitled=true`, `plan_code='free'`, 가입 50(pack) + 월 30(plan) = 잔액 80이 1회만 지급(재로그인 3회 뒤에도 원장 행 수 같음, `D:/WorkSpace/platform/docs/products/_supabase-modular/seed.sql:138`). B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → `/app`(온보딩이 남았으면 02장 9.6절 단계). B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 오류 로그에 토큰·코드 없음. B-4 `VERCEL_ENV=production` 빌드에서 `/api/dev/login` 404, 로그인 화면에 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(DC-06-057 핵심 플로우) 계속 녹색, Google 실로그인은 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인하고 task `log.md`에 기록. B-6 운영 대시보드 Google 설정, Redirect URLs, `AUTH_PROVIDERS=google,email`이 배포 체크리스트와 일치. 제품 추가: 이메일 가입 → 메일 인증 → `/onboarding/ai` → `/onboarding/company` → `/app`, 메일 인증 전 생성 요청 403 `email_not_verified`, Google 로그인 사용자의 `email_confirmed_at` 값 확인 결과를 `[DECISION]`으로 기록(01장 D-21), 로그인 Google 클라이언트가 `GOOGLE_API_KEY`(ai-service)·HubSpot 연동 OAuth와 다른 프로젝트·자격증명(01장 D-22), 같은 이메일 가입자의 Google 로그인은 같은 `user_id`(Supabase 자동 연결), 약관 동의 기록 없는 첫 OAuth 사용자는 `/onboarding/terms` → `/onboarding/ai` 순서(03장 7.3절), 로그인 화면 제공자 버튼은 `listLoginOptions`의 `oauth` 항목을 그리는 같은 컴포넌트(C에서 화면 수정 없이 버튼 추가) | AUTH_ROADMAP 5장, 9장 B 작업, DC-F-001, 03장 7절, 01장 8.1절 D-21·D-22 |
| DC-06-064 | 인증 Stage C1: 카카오 로그인(Supabase 기본 제공자 `kakao`), 설정 → 로그인 방법(연결·해제, 03장 7.4절) | `web/src/lib/auth/providers/kakao.ts`(014 완료 후 이 파일만), `web/src/features/login-methods/`(`/app/settings/login-methods` 페이지 파일은 038 소유 `web/src/app/(app)/settings/`에 1줄 장착 요청), `supabase/config.toml`의 `[auth.external.kakao]`·`[auth] enable_manual_linking`(063 완료 후 이어 받음), `docs/nomad-docs/ops/auth-checklist.md` 카카오 절(063 완료 후 이어 받음) | DC-06-063. 진입 조건 G2(`[DECISION] G2 통과`), 01장 D-18 확정 | P1 | S | Opus | AUTH_ROADMAP 7.1.3절 그대로: C1-1 새 카카오 계정 첫 로그인 → B-1과 같은 결과(엔타이틀먼트·크레딧 1회). C1-2 비즈 앱(a)이면 Google로 가입한 같은 이메일 사용자가 카카오로 로그인 → 같은 `user_id`(자동 연결은 제공자 이메일 인증 확인 시에만, 미확인이면 수동 연결 7.3절). C1-3 (b)면 이메일 없는 사용자가 결제 전 연락 이메일 입력 화면을 본다. C1-4 표시 이름은 카카오 닉네임, 없으면 `user` 규칙. C1-5 버튼은 카카오 디자인 가이드의 색·문구(미확인: 최신판 확인 후 반영). 계정 연결 화면(7.3절): 연결·해제, 마지막 수단 해제 거부, 감사 `auth.identity_link`·`auth.identity_unlink` | AUTH_ROADMAP 7.1, 7.3절, 9장 C1 작업, 01장 D-18 |
| DC-06-065 | 인증 Stage C2: 네이버 로그인(스파이크 0.5일 → `custom:naver` 또는 서버 브리지), 네이버 검수 자료, 설정 → 로그인 방법의 네이버 행 | `web/src/lib/auth/providers/naver.ts`(014 완료 후 이 파일만), `scripts/auth/register-naver-provider.mjs`(제안), `web/src/app/auth/naver/`(브리지 경로일 때만), `docs/nomad-docs/ops/naver-review/`(검수 캡처) | DC-06-063(로그인 방법 화면의 네이버 행은 064 완료 후 064 파일에 요청). 진입 조건 G2. 브리지면 코어 C-13(8.3절) 적용 후 | P1 | M | Fable | AUTH_ROADMAP 7.2.4절 그대로: C2-1 스파이크 결과가 `[DECISION]`으로 기록되고 `NAVER_AUTH_PATH`가 그 값이다. C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 결과. C2-3 같은 네이버 계정 재로그인 5회 → 같은 `user_id`, 사용자 수 증가 0. C2-4 (브리지) state 변조·재사용·쿠키 없음 → 거부, 세션 미생성, 다른 브라우저에서 받은 콜백 URL 재생 → 거부. C2-5 (브리지) 같은 이메일의 Google 가입자가 네이버로 처음 로그인 → `email_in_use` 안내, 새 사용자 0. C2-6 네이버 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않는다 | AUTH_ROADMAP 7.2절, 9장 C2 작업, 01장 D-19 |

### 8.2 게이트와 웨이브

| 게이트·웨이브 | 작업 | 진입 조건 | 판정 |
|---|---|---|---|
| Stage A | DC-06-014(W2) | 없음. W0의 001·004, W1의 012 뒤. 014보다 앞 웨이브(W0·W1) 작업은 시드 스크립트 없이 SQL·단위 테스트로 검증한다(RLS 러너 003은 SQL 안 `-- AS` 역할 전환을 쓰므로 영향 없음) | - |
| G1 | - | AUTH_ROADMAP 4장: 2절 MVP P0 기능 작업 완료(인증 B·C와 공개 베타 직전 통합 작업 056·057·058 제외), 핵심 플로우 E2E(DC-06-057)가 Mock 페르소나로 로컬 녹색, RLS 스모크(DC-06-003)와 `outsider` 교차 테넌트 거부, 결제 E2E(DC-06-048, Toss 테스트 키), 단계 분기 코드가 인증 모듈 밖 0건(DC-06-007 CI), Google Cloud 프로젝트(로그인 전용, AI 키·HubSpot 연동 OAuth와 분리, 01장 D-22)·OAuth 동의 화면·웹 클라이언트 ID·운영 Supabase 프로젝트 준비(AUTH_ROADMAP 5.1절) | 사람(대표님)이 task `log.md`에 `[DECISION] G1 통과` |
| Stage B | DC-06-063 | W7의 맨 앞(마지막 기능 웨이브 W6 다음, 공개 베타 직전 통합·E2E 웨이브). 056·057·058의 스테이징·B 구성 재실행은 063 완료를 기다린다 | - |
| G2 | - | AUTH_ROADMAP 6장: Google 실로그인 공개 베타 운영 2주(제안), 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안), open 앱 신규 가입자 중 `entitled=false` 0, 카카오 디벨로퍼스 앱·비즈 앱 전환(01장 D-18), 네이버 애플리케이션 등록·검수 자료 준비 | 사람이 `[DECISION] G2 통과` |
| Stage C | DC-06-064, DC-06-065 | W8(MVP 출시 후 웨이브, 052~055·060과 같은 웨이브), G2 통과 후. 064·065 병렬 가능 | - |

### 8.3 코어 요청 (6절 표에 이어서)

| ID | 요청 | 이유 | 대상 | 막히는 작업 / 우회 |
|---|---|---|---|---|
| C-13 | C2 스파이크가 실패해 브리지 경로를 택하면 코어 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`(`core.auth_identity_links`) 적용 | 브리지 로그인은 네이버 고유 id로 사용자를 찾는다. 코어는 한 번만 적용하고 모든 제품이 쓴다(AUTH_ROADMAP 9장 공용 모듈 요청). `supabase_custom` 경로면 요청하지 않는다 | `_platform-core` | 065의 브리지 경로. 다른 제품이 먼저 적용했으면 요청 없이 진행 |

### 8.4 기존 문서와 달라진 점

| 항목 | 이전 | 지금 | 반영 |
|---|---|---|---|
| DC-06-014 범위 | 인증 화면과 콜백(이메일 가입, Google), 회사 정보 온보딩 | Stage A(Mock 로그인, 시드, 가드, `finishLogin`, 온보딩 경로 계산) + 회사 정보 온보딩. 이메일·Google 화면과 콜백은 063 | 2절 014 행 |
| `web/src/app/(auth)/` 소유 | 014 단독 | 014(A 구성) → 063이 이어 받음(직렬이라 동시 쓰기 없음) | 2절 014 행, 8.1절 063 행 |
| `web/src/app/auth/callback/` 소유 | 014 | 063(A에는 콜백이 없다. `/api/dev/login`이 `finishLogin`을 직접 부른다) | 2절 014 행, 8.1절 063 행 |
| `web/src/lib/auth/` 소유 | 없음 | 014. 063은 `onboarding.ts`, 064는 `providers/kakao.ts`, 065는 `providers/naver.ts`만 014 완료 후 이어 받는다 | 8.1절 |
| 온보딩 약관 단계 | 없음(이메일 가입 폼에서 동의) | OAuth 첫 로그인용 `/onboarding/terms`를 063이 만들고, 온보딩 순서(약관 → AI 처리 방식 → 회사 정보)는 02장 9.6절 | 02장 9.6절, 03장 7.3절 |
| DC-06-007 수용 기준 | 금지 문자열 `flora_pro_unlocked`·`'1234'` | 인증 단계 CI 검사 추가(쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈 밖 `AUTH_MODE`, 배포 빌드 Mock 실패) | 2절 007 행 |
| DC-06-057 수용 기준 | 스테이징에서 통과, (a)는 가입부터 | Mock 페르소나 storageState로 로컬 먼저(G1 근거), 063 후 스테이징 재실행. (a)는 `no_app` 첫 로그인부터 | 2절 057 행 |
| DC-06-059 수용 기준 | 스테이징 가입 → PDF | 배포 환경은 Mock 금지라 스테이징 가입 확인은 063 완료 후. env 문서에 9.3절 포함 | 2절 059 행 |
| 01장 열린 결정 | D-1~D-17 | 카카오 이메일 정책 D-18, 네이버 경로 D-19, 이메일 가입 유지 D-20, Google 사용자 `email_confirmed_at` 판정 D-21, 로그인 Google 클라이언트 분리 D-22를 01장 8.1절에 새로 둠 | 01장 8.1절 |
| 공용 파일 요청 | - | 014: 상단 배지 `MOCK AUTH · 로컬 전용`의 레이아웃 장착(`web/src/app/layout.tsx`)과 `package.json` 스크립트 `db:seed-users`는 DC-06-004에 1줄 요청(1절 원칙). 064의 `/app/settings/login-methods` 장착은 038에 1줄 요청 | 1절 원칙 그대로 |
| 작업 수 | 62개 | 65개 | 머리말, 4절 |

### 8.5 남은 확인 사항

| 항목 | 내용 | 처리 |
|---|---|---|
| G1 전 스테이징 | Stage A는 로컬 전용이고, `AUTH_MODE=live`에서 로그인 수단이 0개면 web 기동이 실패한다(`AUTH_ROADMAP.md` 3.3절, 02장 9.3절). 그래서 W3의 배포 설정(DC-06-059)은 063 전에는 스테이징 web에서 로그인을 확인할 수 없고, 로그인 수단 없이 web을 띄울 수도 없다 | 059는 063 전까지 워커·ai-service·렌더 연결과 헬스 체크까지만 확인한다. 스테이징 web 기동에 로그인 수단이 꼭 필요하면 Google 동의 화면 "테스트" 게시 상태로 `AUTH_PROVIDERS=google`을 먼저 켜는 안(제안)을 사람이 정한다(`[DECISION]`) |
| 미인증 계정 로그인 | 로컬 `[auth.email] enable_confirmations = true`(`AUTH_ROADMAP.md` 3.4절 표 A행)에서 `email_confirmed_at` 없는 계정이 비밀번호 로그인할 수 있는지 미확인. DC-F-001 Stage A 수용 기준(미인증 계정 생성 요청 403 `email_not_verified`)은 그 계정의 세션이 있어야 E2E로 돌릴 수 있다 | 로그인이 막히면 서버 가드 단위 테스트(`requireSession('docs')` 래퍼, DC-06-012)로 확인하고 E2E는 063의 "메일 인증 전 생성 403"으로 미룬다. 결과는 014 task `log.md`에 `[DECISION]` |
