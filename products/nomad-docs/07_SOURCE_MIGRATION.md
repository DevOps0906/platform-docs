# 07 원본 이식과 폐기: NOMAD Docs

작성일 2026-10-13. NOMAD Docs는 신규 제품이라 전용 원본 저장소가 없다(설계 기준서 1장, `README.md:22`). 이 장의 "원본"은 `README.md:40-51`의 이식 원천 6개다: flora-publishing(설계), flora v1(코드), SellingDocs(기획), FortuneDocs(기획), platform-docs 문서 표준, admin-suite ERP(스키마). 이식은 개발 단계에서 새 앱 저장소에 "새로 작성하며 패턴을 참고"하거나 "데이터·템플릿을 복사 후 수정"하는 두 방식뿐이고, 원천 폴더와 원천 제품 문서는 수정하지 않는다(5절).

근거 표기: 분석 = `docs/products/00_MERGE_ANALYSIS.md`(아래 "분석:줄"), 리뷰 = `docs/reviews/<이름>.md:줄`, 이 폴더 문서는 파일 이름만 쓴다. 대상 위치의 `web/`, `worker/`, `api/`, `tpl/`, `int/` 약어는 `06_AGENT_PLAN.md` 머리 표와 같다.

AI 관련 원천 자산 점검: 원천의 AI 사용은 flora v1의 `call_llm`/OpenRouter 폴백(`docs/reviews/flora.md:16`), SellingDocs PRD의 LLM 4사 직접 연동 계획(`docs/reviews/SellingDocs.md:57`), FortuneDocs의 Multi-LLM 해설 계획(`docs/reviews/FortuneDocs.md:46`)이다. 호출 경로는 하나도 옮기지 않고 ai-service 라우터(확정 결정 17, 분석:25)로 대체한다. 체크리스트 효과 엔진, RFP 추출, 회의록, 프로젝트 채팅·위키, 음성 대화, 연동 어댑터, 3D 히어로는 원천에 없어 모두 신규다.

## 1. 원본별 자산 분류

상태는 원천 자산의 구현 상태(동작/부분/목업/기획만), 처리는 이식(복사 후 수정)/참고(패턴만, 새로 작성)/폐기다(`docs/products/_platform-core/DOC_TEMPLATE.md:14`, `:297`).

### 1.1 flora-publishing (설계, 패턴 베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| LangGraph 초안 그래프 패턴(outline → draft → consistency → proofread → compliance, compliance 뒤 output만) | 기획만 | 참고 | `api/app/ai/graphs/docs_generate.py`(load_context → plan_sections → fill_template → draft_ai_sections → consistency_check → lint → compliance → output) | `docs/products/flora-publishing/01_PRD.md:107`, `02_ARCHITECTURE.md:287-306` |
| 단건 보조 그래프 `publishing.assist`(compose → generate → compliance) | 기획만 | 참고 | `api/app/ai/graphs/docs_assist.py` | `docs/products/flora-publishing/06_AGENT_PLAN.md:74` |
| Tiptap 편집기 + 선택영역 툴바 + Diff 카드 + 서버 sanitize | 기획만 | 참고 | `web/src/features/editor/`, `web/src/lib/server/sanitize/` | `docs/products/flora-publishing/01_PRD.md:78` |
| sanitize 허용 목록(p, h2~h4, 목록, a[https], img[Storage 경로] 등) | 기획만 | 이식(목록 확장) | `tpl/sanitize-allowlist.json`(TS·Python 공용) | `docs/products/flora-publishing/04_API.md:24`, `02_ARCHITECTURE.md:141` |
| 업로드 계약(서명 URL → 완료 검증, 20MB, 매직바이트, 서버 생성 경로) | 기획만 | 참고 | `web/src/app/api/projects/[id]/uploads/`, `web/src/app/api/uploads/` | `docs/products/flora-publishing/01_PRD.md:87` |
| RLS 복합 FK `(parent_id, org_id)`, 상태 전이 트리거, 컬럼 GRANT 패턴 | 기획만(SQL 검증 완료) | 참고 | `2300_docs.sql`(이미 반영) | `docs/products/flora-publishing/05_DATA_MODEL.md:33`, `05_DATA_MODEL.md:17` |
| 크레딧 선차감 → 잡 → `fail_job` 자동 환불 흐름, `generation_runs` 멱등 키 | 기획만 | 참고 | `docs.start_generation`, `worker/src/handlers/docs-generate.ts` | `docs/products/flora-publishing/02_ARCHITECTURE.md:74`, `05_DATA_MODEL.md:828` |
| AI 게이트(대화 매핑, 서명·잡 토큰, 턴 선차감·정산, 국외 이전 온보딩) | 기획만 | 참고 | `web/src/app/api/ai/`, `web/src/lib/server/ai/` | `docs/products/flora-publishing/01_PRD.md:104`, `06_AGENT_PLAN.md:70` |
| 아웃바운드 웹훅(HTTPS URL, HMAC, 5회 재시도, failing) | 기획만 | 참고 | `web/src/app/api/webhook-endpoints/`, `worker/src/handlers/webhook-deliver.ts` | `docs/products/flora-publishing/01_PRD.md:96` |
| 탈퇴·데이터 삭제(30일 유예 → purge) | 기획만 | 참고 | `web/src/app/api/account/`, `worker/src/handlers/purge.ts` | `docs/products/flora-publishing/01_PRD.md:98` |
| 공용 렌더 서비스 `services/render-weasyprint`(WeasyPrint + Noto CJK + `url_fetcher` 허용 목록) | 기획만 | 참고(소비자로 호출만, 소유는 flora-publishing) | 워커 `render-pdf`·`render-docx` 핸들러 | `docs/products/flora-publishing/02_ARCHITECTURE.md:16`, `:67`, `docs/products/_platform-core/SHARED_MODULES.md:269` |
| 판형 6종·Auto-Fit·표지·페르소나 60종·ePub·낭독·3D 책 소재 | 기획만 | 폐기 | - | 3절 DS-04~DS-08 |

### 1.2 flora v1 (코드, 약 55%)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `api/routers/export.py` `_try_weasyprint`, `build_pdf_from_html`(WeasyPrint 경로) | 동작(컨테이너에서 실패) | 참고(교훈만: 렌더는 공용 서비스, 폰트는 fontconfig 이름) | `tpl/` A4 공문서 CSS, 코어 요청 C-1 | `docs/reviews/flora.md:75`, 분석:113 |
| `api/routers/export.py` `content_disposition`(RFC 5987 한글 파일명) | 동작 | 이식 | `web/src/app/api/exports/` | `docs/reviews/flora.md:169` |
| `frontend/src/lib/html-templates.ts`, `app/api/books/build-html/route.ts`(HTML 조립) | 동작(단락 escape 누락) | 참고(구조만, Jinja autoescape로 새로 작성) | `tpl/templates/<doc_type>/v1/document.html.j2` | `docs/reviews/flora.md:78`, 분석:112 |
| `api/routers/upload.py` 계열 파서(txt, md, docx, pdf) | 부분 | 참고(파서 라이브러리 선택만) | `api/app/ai/products/docs/parsers/` | 분석:116, `docs/products/flora-publishing/07_SOURCE_MIGRATION.md:23` |
| `api/routers/export.py` DOC 내보내기(Word 호환 HTML) | 동작(진짜 docx 아님) | 폐기 | - | DS-01 |
| `api/routers/export.py` Typst, fpdf2 폴백 | 동작 | 폐기 | - | DS-02, DS-03 |
| `api/routers/export.py` `build_epub` | 동작 | 폐기 | - | DS-04 |
| `frontend/src/lib/personas.ts`(60종), `print-presets.ts` | 동작 | 폐기 | - | DS-05, DS-06 |
| `api/routers/tts.py`, `f5-tts/` | 동작(경로 조작 취약점) | 폐기 | - | DS-07 |
| `api/routers/automation.py`(n8n 전역 키), React Flow 캔버스 | 부분 | 폐기 | - | DS-09, DS-10 |
| `api/routers/billing.py`(Stripe, 서명 미검증) | 부분 | 폐기 | - | DS-15 |
| `api/routers/llm.py` `call_llm`, `_call_via_openrouter`, mock 폴백, `/debug-api-keys` | 동작 | 폐기(ai-service 라우터가 대체) | - | DS-20, `docs/reviews/flora.md:101` |
| `frontend/.../new/ebook/page.tsx`(4,095줄), `manuscript/page.tsx`(1,422줄) | 동작 | 폐기 | - | DS-21 |
| `frontend/src/hooks/use-is-pro.ts`, `PasswordUnlockModal` | 동작 | 폐기 | - | DS-18 |

### 1.3 SellingDocs (기획만, 약 35%)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| "구조화 JSON → HTML 템플릿 → PDF" 파이프라인 | 기획만 | 참고 | `docs.generate` 그래프 + `tpl/` + `render.pdf` | `README.md:48`, `docs/reviews/SellingDocs.md:77` |
| 목차 → 챕터별 생성(2단계 파이프라인, 단계별 단가) | 기획만 | 참고(섹션 단위 생성, 패키지 부모·자식 잡) | `docs.package`, `draft_ai_sections` | `docs/reviews/SellingDocs.md:72`, `:80` |
| `deduct_credits` 원자 차감·환불 교훈 | 기획만 | 참고(코어 `consume_credits` + `start_generation` 한 트랜잭션) | `2300`:1837 | `docs/reviews/SellingDocs.md:68`, `:92` |
| Route Handler 순서 규칙(인증 → 크레딧 → 처리) | 기획만 | 참고 | `04_API.md:10`, `CLAUDE.md` | `docs/reviews/SellingDocs.md:70` |
| sellingstudio Supabase 클라이언트 3종·`proxy.ts`·auth callback | 동작(sellingstudio) | 참고(코어 auth 골격 사용) | `web/src/lib/supabase/`, `web/src/proxy.ts` | `docs/reviews/SellingDocs.md:88-89` |
| 단일 JSON 일괄 생성, Next/Vercel 안 WeasyPrint, LLM 4사 직접 연동, QuickChart, 공개 서가, ePub(epub-gen-memory) | 기획만 | 폐기 | - | DS-11~DS-14, DS-16, DS-04 |
| 빈 `Claude.md`, `add.md` | 빈 파일 | 폐기(이 폴더 `CLAUDE.md`가 대체) | - | `docs/reviews/SellingDocs.md:50` |

### 1.4 FortuneDocs (기획만, 약 40%)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| "결정적 값은 서버가 계산하고 LLM은 해석만" 원칙 | 기획만 | 참고 | 금액·VAT·기간·번호는 DB(`project_totals`, 트리거, `next_doc_number`), 그래프는 읽기만 | `docs/reviews/FortuneDocs.md:47`, `01_PRD.md:21` |
| 구조화 리포트 JSON → PDF | 기획만 | 참고 | `document_versions.content`(섹션 배열) → `body_html` → `render.pdf` | `docs/reviews/FortuneDocs.md:70` |
| Puppeteer PDF, 만세력·사주 도메인, Multi-LLM 역할 분담 | 기획만 | 폐기 | - | DS-12, DS-17, DS-16 |

### 1.5 platform-docs 문서 표준

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `docs/products/_platform-core/DOC_TEMPLATE.md` 장 구조와 표 컬럼(PRD 기능 표, 아키텍처, API, 데이터 모델, 작업 표) | 동작(문서 표준) | 참고(`req_spec`·`sow`·설계서류 섹션 구조와 표 컬럼) | `tpl/templates/req_spec/v1/structure.json`, `sow`, Phase 2 `api_spec`·`db_design` | `docs/products/_platform-core/DOC_TEMPLATE.md:36-335` |
| 수용 기준 작성 규칙("무엇을 하면 무엇이 보인다", 수치 포함) | 동작 | 참고 | 요구사항 `acceptance_criteria` 도움말, lint `L-UNTRACED` | `docs/products/_platform-core/DOC_TEMPLATE.md:20` |
| `docs/develop/_shared/tools/build_root.py`의 산출물 등록부(ID, 산출물명, 단계, 상태, 버전, 경로, 상위 ID) | 동작(스크립트) | 참고(데이터 모델만) | `documents`(상태·버전·`supersedes_document_id`), `trace_links`(상위 연결) | `docs/develop/_shared/tools/build_root.py:9`, `:214` |
| `docs/products/_STRUCTURE_CHECK.md` 품질 점검(필수 파일, 장 구조, 이모지/HTML, 경로, 차단 설계 표) | 동작(점검 결과) | 참고(점검 항목 → lint 규칙) | `tpl/templates/*/v1/lint_rules.json`(필수 섹션, `L-REQUIRED-CLAUSE`), DC-06-021 | `docs/products/_STRUCTURE_CHECK.md:5-26`, `docs/products/_platform-core/DOC_TEMPLATE.md:337-351` |
| 내부 개발 전용 표기(모델 배정, `경로:줄` 근거, P0~P2 등급의 의미) | 동작 | 폐기 | - | DS-23 |

### 1.6 admin-suite ERP (연동 대상 스키마)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `erp.products`(sku, name, category, price, is_active) | 기획만(SQL 검증) | 참고(읽기 전용 매핑) | `int/src/admin-suite-erp/`, 비용 단가 카탈로그 | `docs/products/_supabase-modular/migrations/1600_erp.sql:113`, `04_API.md:227` |
| `erp.sales`(quantity, unit_price, total_price, status) | 기획만 | 참고(Phase 2 `invoice` 입력) | 같음 | `docs/products/_supabase-modular/migrations/1600_erp.sql:154`, `04_API.md:228` |
| `erp.employees` | 기획만 | 참고(Phase 3 인사 문서, MVP·Phase 2 미사용) | - | `docs/products/_supabase-modular/migrations/1600_erp.sql:76`, `04_API.md:229` |
| `erp` 스키마 쓰기, 사용자 세션 교차 GRANT | - | 폐기(만들지 않음) | - | `02_ARCHITECTURE.md:189`, 코어 요청 C-7 |

## 2. 이식 자산 상세

"참고" 자산은 코드를 복사하지 않고 새로 작성하므로 아래에는 실제로 파일·데이터를 옮기는 자산과, 참고하되 원천과 반드시 달라야 하는 점이 있는 자산을 적는다.

| 자산 | 수정할 점 |
|---|---|
| flora-publishing 초안 그래프 패턴 | 노드를 문서 조립용으로 바꾼다: `plan_sections`·`fill_template`은 결정적(LLM 0회), `draft_ai_sections`는 `kind=ai` 섹션만, `risk_level='high'`면 건너뜀. compliance 뒤 `lint`를 앞에 둔다. 사람 승인 interrupt는 두지 않는다(초안 버전만 추가, `02_ARCHITECTURE.md:298`). 소제목 정액 선차감 대신 문서 유형 단가(2/6/12) |
| flora-publishing 편집기·Diff 카드 | 문단 단위가 아니라 섹션 단위 노드. 고정·표·조항 섹션 잠금 확장 추가, 변수 칩(금액·당사자)은 편집 불가 + "정본에서 수정" 링크. 저장은 Tiptap 출력 그대로가 아니라 섹션 배열을 Route Handler가 sanitize 후 새 버전으로. 고위험 유형은 AI 툴바 비활성 |
| sanitize 허용 목록 | `table`, `colgroup`, `col`, `th[colspan,rowspan]`, `td[colspan,rowspan]`, `section[data-key]` 추가(제안, `02_ARCHITECTURE.md:141`). TS·Python이 같은 JSON 파일을 읽고 해시 일치 테스트 |
| 업로드 계약 | 원고 대신 RFP·참고 자료·회의 녹음. 문서 20MB·300쪽, 녹음 200MB와 플랜 `minutes_max_minutes`. "사용 권한 있음" 확인(감사), `contains_pii` 표시, 녹음은 제3자 고지 버전 필수. 파싱 결과는 LLM 전송 전 주민등록번호 마스킹 |
| 크레딧 흐름 | 단건 선차감은 `docs.start_generation`(service_role) 안에서 run + `enqueue_job` + `consume_credits`를 한 트랜잭션으로. 패키지는 부모 `p_credits=0`, 자식 단위 차감·환불, 실패 자식의 하류는 canceled + 환불 |
| v1 `content_disposition` | Python → TS. 서명 URL의 `download` 파라미터에 적용. 파일명은 `<문서번호>_<유형명>.<ext>`(제안), 사용자 입력 제목은 표시용으로만 |
| v1 HTML 조립 교훈 | 마크다운 → HTML 변환을 쓰지 않는다. 섹션 HTML은 Jinja autoescape 템플릿(변수)과 sanitize된 AI 섹션뿐. 이미지 src는 Storage 경로를 서버가 서명 URL로 변환(직인 포함) |
| v1 WeasyPrint 경로 교훈 | 제품 컨테이너를 만들지 않는다. CSS는 `font-family: "Noto Sans CJK KR"`(fontconfig 이름)만, 파일 경로 금지. A4 공문서 프리셋(머리말·꼬리말, "n / N", 간인)은 코어 요청 C-1 |
| SellingDocs 파이프라인 | "책 1권 = JSON 1개"를 "문서 1개 = 잡 1개, 문서 안 = 섹션 JSON"으로. 금액·날짜·번호는 JSON에 LLM이 쓰지 않고 변수 스냅샷에서만 |
| FortuneDocs 원칙 | 사주 계산 대신 견적 계산에 적용: `line_items.amount_krw` 생성 컬럼, 뷰 `project_totals`(round, 1.1절 I-5), 기간 일수, `req_code` 트리거. consistency_check는 숫자 토큰을 서버 값과 대조하고 다르면 조용히 교체하지 않고 실패 |
| 문서 표준(DOC_TEMPLATE, 등록부, 점검표) | 내부 표기(모델, `경로:줄`, 작업 ID)를 빼고 고객 문서 용어로 바꾼다: 요구사항 ID FR/NFR/CON, 화면 SCR, 마일스톤 MS, 산출물 DLV. 등록부의 "상위 ID"는 `trace_links`로, "상태·버전"은 `documents.status`·`document_versions`로. 점검표 항목은 유형별 `lint_rules`로 옮기고 운영자 카탈로그(DC-06-049)에서 버전 관리 |
| admin-suite ERP 스키마 | 읽기만. service_role 함수가 같은 org + `docs`·`erp` 두 엔타이틀먼트를 확인한 뒤 Canonical 타입으로 변환. `price numeric(12,2)` → 원 정수(반올림, 제안). 모놀리스 배포에서는 쓰지 않고 Phase 3 API 방식 |

## 3. 폐기 목록과 사유

설계 기준서 5장 "버리는 것"과 `README.md:44-51` "버리는 것" 열을 빠짐없이 옮기고, 이식 원천에서 분석이 "폐기"로 분류한 항목 중 이 제품과 관련된 것을 더했다. ID는 이 제품 고유(`DS-##`)다.

| ID | 항목 | 원천 | 출처 | 사유 | 대체 |
|---|---|---|---|---|---|
| DS-01 | Word 호환 HTML(.doc) 내보내기 | flora v1 | `docs/reviews/flora.md:19`, 분석:115, :185 | 진짜 DOCX가 아니어서 서식·표가 깨지고 편집 시 손상 | 공용 렌더 서비스 `POST /render/docx`(python-docx/docxtpl, 코어 요청 C-1) |
| DS-02 | Typst PDF 경로 전체(`build-typst`, `export/typst`, `typst-presets.ts`) | flora v1 | 분석:114, :183 | PDF 엔진 2개 유지 비용, Typst CLI 의존 | 공용 WeasyPrint 렌더 하나 |
| DS-03 | fpdf2 폴백, html2pdf.js 클라이언트 PDF | flora v1 | 분석:184 | 한글 불가, 서식 미반영 | 공용 렌더 + Noto CJK |
| DS-04 | ePub 내보내기(v1 ePub3, v2 ePub2, SellingDocs epub-gen-memory) | flora v1, SellingDocs | 분석:116, `docs/reviews/SellingDocs.md:78` | 업무 문서(계약서·견적서)는 고정 서식이 필요하고 리플로우 형식 수요가 없다 | PDF, DOCX, ZIP(HWPX는 Phase 3, D-5) |
| DS-05 | 판형 프리셋·Auto-Fit·표지 디자인 | flora-publishing, flora v1 | `README.md:46` | 책 판형 개념이 없다. 업무 문서는 A4 하나 | A4 공문서 프리셋(C-1) |
| DS-06 | 페르소나 60종·Taste 문체 합성 | flora-publishing, flora v1 | `README.md:46-47`, 분석:94 | 업무 문서는 문체 선택이 아니라 표준 서식·용어 일관성이 핵심 | 프로젝트 용어 위키(DC-F-024), 유형별 프롬프트 |
| DS-07 | TTS 낭독·오디오북, F5-TTS 벤더링, 레퍼런스 WAV 보이스 클론 | flora-publishing, flora v1 | `README.md:46`, `docs/reviews/flora.md:71`, 분석:137, :202, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:57` | 제품에 낭독 수요 없음. F5-TTS 공개 가중치는 비상업 라이선스(CC-BY-NC), WAV 업로드는 경로 조작·음성 복제 동의 문제 | core-voice 음성 대화(DC-F-027, 저장하지 않음), 회의 STT(DC-F-026) |
| DS-08 | 3D 책 소재(낱장 → 제본 → 책장) | flora-publishing | `README.md:46` | 제품 소재가 다르다 | 체크 → 서류 낱장 → 묶음 → 직인(`03_SCREENS_UX.md:812-830`) |
| DS-09 | n8n 연동(전역 API 키 프록시) | flora v1·v2 | `README.md:47`, 분석:145 | 키 하나를 모든 테넌트가 공유해 격리 붕괴 | 조직별 수신 토큰(해시 저장) + HMAC 수신, 발신 웹훅(DC-F-029, DC-F-032) |
| DS-10 | React Flow AI 캔버스 | flora v1 | `docs/reviews/flora.md:31`, 분석:143 | 실행 엔진 없는 노드 UI, 위저드와 중복 | 3단계 체크리스트 마법사 + 결정적 효과 엔진 |
| DS-11 | 산출물 전체를 단일 JSON 한 번에 생성 | SellingDocs | `README.md:48`, `docs/reviews/SellingDocs.md:51`, 분석:182 | 출력 토큰·시간 제한으로 잘림·파싱 실패 | 문서 1개 = 잡 1개, 섹션별 JSON, 패키지 부모·자식 잡 |
| DS-12 | Next/Vercel Route Handler 안 WeasyPrint, Vercel 위 Puppeteer | SellingDocs, FortuneDocs | `README.md:48`, `docs/reviews/SellingDocs.md:48`, `docs/reviews/FortuneDocs.md:45`, 분석:181 | 서버리스에 Python·Pango·Chromium이 없어 런타임 불성립 | Railway private network의 공용 렌더 서비스, web은 enqueue만 |
| DS-13 | QuickChart 차트 삽입 | SellingDocs | `docs/reviews/SellingDocs.md:61`, 분석:120 | 사용자 데이터 외부 전송 | 문서 표는 HTML table, 차트는 Phase 2 이후 인라인 SVG(제안) |
| DS-14 | 공개 서가 + JSON-LD GEO | SellingDocs | `docs/reviews/SellingDocs.md:52`, 분석:119 | 고객 계약·견적 문서를 공개 색인할 이유가 없다(기밀) | 읽기 전용 만료 공유 링크(DC-F-037, Phase 2) |
| DS-15 | Stripe 결제 | flora v1 | `docs/reviews/flora.md:20`, `:69` | 확정 결정 4(전 제품 Toss), 원천은 서명 미검증 | 코어 Toss(confirm 정본 + 웹훅 서명·멱등) |
| DS-16 | LLM 4사 SDK 직접 연동, 사용자 모델 선택, Multi-LLM 역할 고정 분담 | SellingDocs, FortuneDocs, flora v1 | `docs/reviews/SellingDocs.md:57`, `docs/reviews/FortuneDocs.md:46`, 분석:159, :182 | 키·SDK 관리 부담, 모델별 단가 설명 불가 | ai-service 라우터 기능별 체인(`02_ARCHITECTURE.md:259-277`), 문서 유형 정액 단가 |
| DS-17 | 만세력·사주 도메인 | FortuneDocs | `README.md:49` | 도메인 무관(astro-ai 소유) | 없음 |
| DS-18 | Pro 잠금해제(`'1234'`, localStorage), 클라이언트 전용 플랜 판정 | flora v1·v2 | 분석:155, :201, `docs/reviews/flora.md:73` | 유료 기능 무료 사용 | 서버 `docs.org_features`, DB 트리거·RPC(DC006) |
| DS-19 | 사용자 API 키(BYOK) 평문 저장 | flora v1 | 분석:158, :199 | 평문 키 위험, 죽은 기능 | 만들지 않음. 연동 토큰만 `core.encrypted_credentials` |
| DS-20 | mock 폴백 응답, `/debug-api-keys` | flora v1 | 분석:160, :198, `docs/reviews/flora.md:92`, `:101` | 장애를 정상 응답으로 위장, 키 정보 노출 | 실패 표시 + 환불 + 구조화 로그 |
| DS-21 | v1 대형 단일 페이지(4,095줄 위저드, 1,422줄 manuscript) | flora v1 | 분석:190, `docs/reviews/flora.md:90` | 유지보수 불가 | 기능 디렉토리 단위 화면(DC-06-038~043) |
| DS-22 | in-memory waitlist와 시드 수치 147 | flora v1 | 분석:199, `docs/reviews/flora.md:82` | 허위 수치 | 대기자 명단 없음(가입 개방 베타). 랜딩에 수치 표시 금지(`01_PRD.md:403`) |
| DS-23 | platform-docs 내부 개발 표기(모델 배정, `경로:줄` 근거, 작업 ID) | 문서 표준 | `README.md:50` | 고객 문서에 의미 없는 내부 표기 | 요구사항·화면·마일스톤 코드와 추적표 |
| DS-24 | AI 표지·이미지 생성(제공자 7종) | flora v1 | 분석:109 | 업무 문서에 생성 이미지가 필요 없다. 직인은 사용자 업로드 | 직인 이미지(비공개 버킷) |
| DS-25 | 사진집·룩북, AI 조판(`/llm/layout`) | flora v1 | 분석:108, :146-147 | 도메인 무관, 목업 | 없음 |
| DS-26 | v1 동기 SDK·`requests` 호출 | flora v1 | 분석:186, `docs/reviews/flora.md:76` | 이벤트 루프 블로킹 | `httpx.AsyncClient`, 비동기 LangChain, `run_in_threadpool` |
| DS-27 | 실키가 든 `.env` 파일 | flora v1·v2 | 분석:203, `docs/reviews/flora.md:79` | 키 유출 | 복사하지 않음(5절). env는 배포 플랫폼 비밀로만 |

## 4. 복사 금지 결함

`docs/products/_platform-core/SECURITY_BASELINE.md:213-236` 14장 중 이 제품에 해당하는 항목(앞 15행)과 이식 원천 리뷰·이 제품 설계에서 찾은 고유 결함(뒤 행). 14장 항목 중 해당 없음: "OVERRIDE 비밀번호·verify-admin API"(`:228`, 의료 데이터 없음), "프로필 없으면 admin·클라이언트 PageGuard"(`:229`, Hospital 원천 없음), "사용자 WAV 경로 조작"(`:233`, WAV 기능 폐기 DS-07. 같은 계열의 경로 조작은 아래 "사용자 입력 파일명" 행이 막는다).

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 RPC EXECUTE 미회수 | `docs/products/_platform-core/SECURITY_BASELINE.md:219` | 브라우저에서 크레딧 지급 | 코어 RPC는 service_role만. RLS 러너가 `rpc('grant_credits')` 42501 확인(DC-06-003) |
| 비원자 크레딧 차감(읽고 → 빼고 → 쓰기) | `SECURITY_BASELINE.md:220`, `docs/reviews/SellingDocs.md:49` | 동시 요청으로 음수 잔액 | `docs.start_generation` 한 트랜잭션 + `core.consume_credits`, 동시성 50회 테스트(DC-06-056) |
| 웹훅 서명 미검증·선택적 검증, 시크릿 오용 | `SECURITY_BASELINE.md:221`, `docs/reviews/flora.md:69` | 위조 이벤트로 플랜 상승, 위조 프로젝트 생성 | Toss·HubSpot·Make/n8n 모두 원시 본문 서명 검증 + `core.webhook_events` 멱등. 수신 토큰은 sha256 해시만 저장 |
| `customerKey = Date.now()`, orderId 파싱으로 org/plan 추출 | `SECURITY_BASELINE.md:222` | 빌링키 충돌, 금액·대상 위조 | 코어 `payment_orders` 서버 생성, confirm 정본 |
| OAuth state 위조, 콜백 인증 결함 | `SECURITY_BASELINE.md:223` | 타인 계정에 CRM 연결 | `core.oauth_states` 서버 발급·1회 소비(`OA001`) |
| 토큰 평문 저장, 0키 폴백 | `SECURITY_BASELINE.md:224` | DB 유출 시 연동 계정 탈취 | `core.encrypted_credentials`, `CREDENTIALS_KEY_V<n>` 없으면 기동 실패 |
| 세션 없는 백그라운드 작업이 RLS에 막혀 무동작 | `SECURITY_BASELINE.md:225` | 장애가 조용히 숨겨짐 | 워커·ai-service는 service_role + 행의 `org_id` 대조, 실패는 `fail_job` |
| `user_plans FOR ALL` 정책(셀프 업그레이드) | `SECURITY_BASELINE.md:226`, `docs/reviews/flora.md:70` | 자기 플랜 변경 | `FOR ALL` 정책 0(`05_DATA_MODEL.md:735`), 플랜은 코어 엔타이틀먼트 SELECT만 |
| Pro 잠금해제 `'1234'`, localStorage 플래그 | `SECURITY_BASELINE.md:227`, `docs/reviews/flora.md:73` | 유료 기능 무료 사용 | 서버 features 해석(DC-06-013), CI 금지 문자열 검사(DC-06-007) |
| RLS 정책 안 자기참조 재귀(42P17) | `SECURITY_BASELINE.md:230` | 전체 거부 또는 우회 | 정책은 `is_org_member`·`has_org_role`·`has_entitlement`·`current_org_ids`만, `org_members` 직접 조회 0(`05_DATA_MODEL.md:735`) |
| 전역 n8n API 키 프록시 | `SECURITY_BASELINE.md:231`, 분석:145 | 테넌트 격리 붕괴 | 연결별 수신 토큰 + HMAC(DS-09) |
| 인증 없는 공개 AI 프록시, CORS `*` | `SECURITY_BASELINE.md:232` | 키 도용, 비용 폭증 | `/api/ai/*`는 `requireSession` + 서명 토큰, ai-service는 토큰 없으면 401 |
| 라우터 무인증(LLM/export/upload), `dev-user` 우회, 빈 JWT secret | `SECURITY_BASELINE.md:234`, `docs/reviews/flora.md:68`, `:80` | 무료 사용, 데이터 접근 | 모든 Route Handler 래퍼(린트 검사), JWKS 없으면 ai-service 기동 실패 |
| 실키가 든 `.env` 커밋 | `SECURITY_BASELINE.md:235`, `docs/reviews/flora.md:79` | 키 유출 | `.gitignore`, CI 비밀 검사, 원천 `.env` 복사 금지(5절) |
| 한글에 `\b` 경계 금지어 매칭 | `SECURITY_BASELINE.md:236` | 필터 무효 | compliance·`L-BANNED` 규칙은 한글 경계를 쓰지 않는 사전 매칭 + 단위 테스트(DC-06-021) |
| 사용자 입력 파일명·label을 Storage 경로에 사용 | `docs/reviews/flora.md:71` | 경로 조작 | 서버 생성 `<org_id>/docs/<purpose>/<uuid>.<ext>` + 첫 세그먼트 CHECK(`05_DATA_MODEL.md:832`), 원본 이름은 `original_name`만 |
| 서버가 사용자 URL fetch(`cover_url`), 렌더러 무제한 외부 fetch | `docs/reviews/flora.md:72` | SSRF(메타데이터 엔드포인트) | 렌더 입력은 서버 조립 HTML만, `url_fetcher` 허용 목록(공용 렌더), 웹훅 URL https + 사설 대역 CHECK + 발송 직전 DNS 재검사 |
| WeasyPrint를 Vercel·Route Handler에서 실행 | `docs/reviews/SellingDocs.md:48` | 배포 불가 | web은 `render.pdf`/`render.docx` enqueue만, 웹 번들의 렌더 클라이언트 import 린트 차단 |
| 산출물 전체를 단일 JSON으로 생성 | `docs/reviews/SellingDocs.md:51` | 잘림·타임아웃 | 문서·섹션 단위 생성(DS-11) |
| 빈 에이전트 규칙 문서 | `docs/reviews/SellingDocs.md:50` | 생성 코드 품질 통제 불가 | 이 폴더 `CLAUDE.md`, CI 빈 파일 검사 |
| step 레벨 `if`에서 `secrets` 사용 | `docs/reviews/flora.md:74` | 배포 워크플로 무효 | job 레벨 `env`, actionlint(DC-06-007) |
| Windows 폰트 경로 하드코딩, 폰트 없는 렌더 이미지 | `docs/reviews/flora.md:75` | 컨테이너에서 한글 두부 | fontconfig 이름 `Noto Sans CJK KR`만, 한글 골든 PDF·DOCX(DC-06-026) |
| async 핸들러 안 동기 호출 | `docs/reviews/flora.md:76` | 이벤트 루프 정지 | 비동기 클라이언트, CPU 작업 `run_in_threadpool`, 장시간 작업은 잡 |
| 선택 영역 일부(마지막 1,000자)만 처리하고 전체를 덮어씀 | `docs/reviews/flora.md:77` | 문서 손실 | `docs.assist` 4,000자 초과 422(절단 금지), Diff 수락 시 해당 섹션만 새 버전 |
| escape 없는 HTML 삽입 | `docs/reviews/flora.md:78` | XSS, PDF 주입 | Jinja autoescape + 서버 sanitize(TS·Python 같은 허용 목록) |
| 장애를 mock 응답으로 숨김, `except Exception` 무로깅 | `docs/reviews/flora.md:92` | 장애 은폐 | 실패 상태 + 환불 + 로그(본문·프롬프트 제외) |
| `.single()` 0행에서 500 | `docs/reviews/flora.md:83` | 404 대신 500 | `maybe_single`, `P0002` → 404 매핑(DC-06-012) |
| LLM이 금액·합계·VAT·문서번호를 생성하거나 조용히 수정 | `docs/reviews/FortuneDocs.md:47`, 설계 기준서 2장 원칙 4 | 문서 간 숫자 불일치, 계약 분쟁 | 서버 계산값만 변수로, consistency_check 불일치는 실패(`02_ARCHITECTURE.md:156`) |
| 고위험 문서(계약서)의 조항을 AI가 생성·수정 | 설계 기준서 2장 원칙 3, `01_PRD.md:392` | 법률사무 취급 위험(미확인), 책임 소재 | `doc_types` CHECK(high면 template만), `draft_ai_sections` 건너뜀, `docs.assist` 403, 채팅 조항 작성 거절 |
| 주민등록번호 등 고유식별정보 입력란·저장 | `01_PRD.md:381` | 법정 수집 제한 정보 | 입력란 없음, 서버 PII lint 422 `pii_detected`, 확정 lint `L-RRN`, 업로드는 LLM 전송 전 마스킹 |
| 클라이언트가 보낸 HTML·금액·`req_code`·문서번호를 그대로 저장·렌더 | `04_API.md:17-18` | 위조 문서, XSS | zod에 해당 필드 없음, 서버 sanitize 후 새 버전, 렌더는 DB의 `body_html`만 |
| 효과 엔진에 시각·난수·LLM·외부 호출 사용 | `01_PRD.md:161` | 같은 입력에 다른 결과, 추적성 붕괴 | 순수 함수 + 속성 테스트(DC-06-019), 린트로 `Date`·`Math.random`·`fetch` 차단 |
| 효과 엔진이 사용자 수정 행을 덮어쓰거나 삭제 | `01_PRD.md:159-160` | 사용자 작업 소실 | `is_user_modified` 보존, `apply_checklist_effects` 해시 비교(DC010) |
| 회의 녹음·전사본을 상용 제공자로 대체 전송 | `docs/products/_platform-core/SECURITY_BASELINE.md:297`, `supabase/monolith/seed.sql:57` | 제3자 음성·발언 국외 이전 | `meeting_minutes`·`docs.minutes` 강제 오픈소스, 실패 시 대체 없이 환불 |
| 브라우저에서 Dify·FastAPI·AI·렌더 서비스 직접 호출 | `SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*`, 제품 Route Handler만 |
| Dify 입력에 토큰·org·문서 본문 | `SECURITY_BASELINE.md:285` | Dify 로그에 평문 | 대화 매핑(`platform_conversation_id`, `dify_user`), 선택 입력 `project_id`만 |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | `SECURITY_BASELINE.md:284`, `:300` | 키 유출, 라우팅 우회 | LLM 키는 `apps/api`만, ElevenLabs·서명 개인키는 web 서버만 |
| 임의 텍스트 TTS | `docs/products/flora-publishing/07_SOURCE_MIGRATION.md:138` | 비용 남용 | TTS 입력은 DB의 assistant 메시지만(403) |
| 사람 소유 위키 블록 덮어쓰기 | `docs/products/_platform-core/LLM_WIKI.md:30` | 사용자 수정 소실 | `expected_version` 잠금, 에이전트는 제안만 |
| 웹훅·이벤트 본문에 연락처·문서 본문 포함 | `04_API.md:195` | 외부로 개인정보 유출 | id와 서명 링크만 |
| 토큰 밖 3D 재질 색, "Tailwind"만 적은 지시 | `docs/products/_design-guide/HERO_3D.md:52-53`, `docs/products/_design-guide/DESIGN_SYSTEM.md:23` | 제네릭 인상, v3 설정 혼입 | 토큰만, 지시와 문서에 "Tailwind CSS v4", `tailwind.config.js` 금지 |

## 5. 아카이브 절차

이 제품은 전용 원본 저장소가 없으므로 `archive/<원본>` 이동 대상이 없다. 이식 원천은 다른 제품의 소유이거나 공용 문서이므로 이 제품 작업이 옮기거나 지우지 않는다.

| 순서 | 작업 | 담당 |
|---|---|---|
| 1 | 아카이브 대상 없음을 확인한다. flora v1·Flora-v2·SellingDocs·FortuneDocs 원본 폴더의 아카이브는 각 소유 제품의 절차(`docs/products/flora-publishing/07_SOURCE_MIGRATION.md:174-184`, astro-ai 07장)가 맡는다 | 해당 없음 |
| 2 | 원천 폴더·원천 제품 문서(`flora-publishing/`, `admin-suite/`, `_platform-core/`, `_design-guide/`, `docs/reviews/`)를 읽기 전용으로 둔다. 필요한 변경은 06장 6절 코어 요청 또는 해당 제품 담당에게 요청한다. git으로 원천을 바꾸는 명령(checkout, reset, stash, add, commit)을 쓰지 않는다(`docs/products/_PRODUCT_AGENT_BRIEF.md:15`) | 모든 개발 에이전트 |
| 3 | 코드를 옮기는 자산은 1.2절 `content_disposition`과 2절의 허용 목록·템플릿 구조뿐이다. 옮길 때 원천의 `.env*`, `node_modules`, venv, 잡파일, `f5-tts/`를 새 저장소로 복사하지 않는다 | DC-06-020, DC-06-029 |
| 4 | 키 재발급은 필요 없다. 이 제품은 원천의 환경변수 파일을 복사하지 않고 모든 키를 새로 발급해 배포 플랫폼 비밀로만 둔다. 예외: 개발 중 원천의 `.env` 값을 실수로 복사·커밋했다면 해당 키(예: `SUPABASE_SERVICE_ROLE_KEY`, `OPENROUTER_API_KEY`)를 즉시 재발급하고 원천 소유 제품의 재발급 기록(`docs/products/flora-publishing/07_SOURCE_MIGRATION.md:182`)에 함께 남긴다 | DC-06-007(CI 비밀 검사), 사람 |
| 5 | zip 중복 정리 대상 없음(전용 원본 폴더가 없다) | 해당 없음 |
| 6 | 공용 렌더 서비스·공용 Dify·GPU 서버·ai-service 원본은 소비만 한다. 운영 책임과 변경 요청은 코어 요청 C-1, C-10, C-11 | 사람(운영) |
