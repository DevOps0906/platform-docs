# NOMAD Docs (nomad-docs)

작성일 2026-10-13. 신규 단독 제품, 공개 베타, 가입 개방(`core.apps.id='docs'`, `signup_policy='open'`, `status='beta'`). 이 폴더는 기획 문서와 SQL만 있고 앱 코드는 없다(`D:/WorkSpace/platform/docs/products/_PRODUCT_AGENT_BRIEF.md:6`). 브랜드 최종명은 열린 결정 D-1이다(`01_PRD.md` 8장).

## 1. 한 줄 정의

회사·거래처·프로젝트 정보를 한 번 입력하고 체크리스트에 체크하면, 체크 하나가 요구사항·화면·비용·계약 조항·검수 항목까지 연결되어 실무 문서 묶음(견적서, 과업지시서, 요구사항정의서, WBS, 화면목록, 개발용역계약서, 검수확인서, 회의록)을 한 번에 만들고, 버전·요구사항 추적표·PDF/DOCX 내보내기와 CRM·ERP 연동까지 이어지는 문서 자동화 SaaS다.

| 대상 | 상황 | 단계 |
|---|---|---|
| 1인 개발자·프리랜서 | 외주 수주 때마다 견적서·계약서·요구사항정의서를 처음부터 다시 쓴다 | MVP |
| 5~30인 외주 개발사·에이전시 | PM이 제안·견적·계약·검수 문서를 프로젝트마다 맞춰 만들고 버전을 관리한다 | MVP(팀 기능은 Phase 2) |
| 사내 PM | 사내 개발 요청의 요구사항정의서·WBS·회의록을 정리한다 | MVP |
| 정부지원사업 준비 스타트업 | 사업계획서·지원사업 신청서와 개발 외주 문서를 함께 만든다 | Phase 2(`biz_plan`, D-12) |

AI 요약: RFP·참고 자료를 프로젝트별로 색인(RAG, `docs.knowledge`)하고, RFP에서 체크리스트 답과 요구사항 후보를 추출하며(`docs.extract`), LangGraph `docs.generate`가 템플릿 섹션은 결정적으로 채우고 서술 섹션만 LLM으로 쓴다. 프로젝트 근거 Q&A 채팅(Dify `docs-chat`, 출처 표시), 프로젝트 용어 위키, 회의 녹음 → 회의록 + 요구사항 후보(STT 오픈소스 강제), 음성 대화를 MVP에 둔다. 계약서 등 고위험 문서는 MVP에서 템플릿 생성만 허용하고 AI가 조항을 만들거나 고치지 않는다.

## 2. 통합 근거

| 항목 | 내용 | 근거 |
|---|---|---|
| 통합 대상 | 없다. 기존 리뷰 대상 프로젝트를 합친 제품이 아니라 신규 제품이다. 대신 기존 제품 설계와 리뷰에서 검증된 패턴을 "이식 원천"으로 가져온다(3장) | 설계 기준서 1장 |
| 베이스 | 코드 베이스 없음. 설계 패턴 베이스는 `flora-publishing`(LangGraph 초안 그래프, Tiptap 편집기와 Diff 카드, 업로드 파서, 크레딧 선차감·환불). 이유: 같은 "구조화 데이터 → 섹션 생성 → HTML → WeasyPrint PDF" 흐름이고 이미 높음 결함 25건의 차단 설계를 거쳤다 | `D:/WorkSpace/platform/docs/products/flora-publishing/01_PRD.md:78`, `:87`, `:107`, `D:/WorkSpace/platform/docs/products/flora-publishing/05_DATA_MODEL.md:208` |
| 확정 결정 적용 | 3 FastAPI + 공용 WeasyPrint 렌더(제품은 소비자로 추가, 코어 요청 C-1), 4 Toss, 5 org 기준 스키마와 1인 1워크스페이스, 13 AI 계층(FastAPI LangGraph, pgvector RAG), 14 Dify 앱 1개(`docs-chat`), 15 3D 히어로, 16 음성(회의 녹음, 음성 대화), 17 LLM 이원화와 국외 이전 동의 | `docs/reference/00_MERGE_ANALYSIS.md:11-13`, `:21-25` |
| 확정 결정 밖 | 결정 7(MVP 범위)과 8(플랜 정본)은 이 제품을 다루지 않는다. 범위는 설계 기준서 4장, 요금은 전부 제안(`01_PRD.md` 4장, D-4) | `docs/reference/00_MERGE_ANALYSIS.md:15-16` |
| 공유하는 것 | `_platform-core` 공용 모듈만 인용한다: auth, org, credits, toss, webhooks, oauth, weasyprint render, storage, audit, jobs, compliance, ai-gateway, ai-service, dify, core-voice, llm-wiki. 재정의하지 않는다 | `docs/file/03-설계/공용코어/SHARED_MODULES.md:264-290`, `:353-376`, `:492-500` |
| 다른 제품과의 관계 | admin-suite ERP(`erp` 스키마)를 Phase 2에 읽기 전용으로 연동한다(품목 → 비용 항목 단가, 판매 → 거래명세서). 같은 모듈러 DB에서 service_role 함수만 읽고 사용자 세션에 교차 스키마 GRANT를 주지 않는다(코어 요청 C-7) | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql:113`, `:154` |

### 2.1 리뷰 "높음" 결함 차단 범위

이 제품은 기존 원본의 코드를 옮기지 않지만, 이식하는 자산과 같은 계열의 실패가 반복될 수 있는 원천의 "높음" 결함은 전부 차단 설계 대상으로 삼는다. 합계 14건이며 보안·데이터 결함은 `05_DATA_MODEL.md` 7절, 나머지는 `02_ARCHITECTURE.md` 6절에 둔다.

| 리뷰 | 높음 수 | 대상 여부 | 이유 | 근거 |
|---|---|---|---|---|
| `docs/reference/reviews/SellingDocs.md` | 4 | 대상 | 이식하는 핵심 파이프라인("구조화 JSON → HTML 템플릿 → PDF")의 원천이다. #1 WeasyPrint 런타임 불일치(렌더를 Next/Vercel에서 돌리려 함), #2 크레딧 차감 경계 부재, #3 에이전트 규칙 문서 부재, #4 단일 JSON 일괄 생성은 모두 문서 묶음 생성(패키지 8종)에서 그대로 재발할 수 있다 | `docs/reference/reviews/SellingDocs.md:48-51` |
| `docs/reference/reviews/flora.md` | 10 | 대상 | export 경로(WeasyPrint 단일화, Noto CJK)와 업로드 파서를 v1에서 이식한다. 같은 경로에 붙어 있던 무인증 LLM 엔드포인트(#1), 웹훅 서명 미검증(#2, 이 제품은 HubSpot·Make 수신 웹훅이 있음), 플랜 자기 상향(#3), 업로드 경로 조작(#4), WeasyPrint SSRF(#5), 클라이언트 Pro 잠금(#6), 배포 설정 오류(#7, #8), 이벤트 루프 차단(#9), 편집 지시 유실(#10)은 이 제품의 업로드·렌더·AI 다시 쓰기·연동 경로에서 같은 형태로 다시 생길 수 있다 | `docs/reference/reviews/flora.md:68-77` |
| `docs/reference/reviews/FortuneDocs.md` | 6 | 제외 | 가져오는 것은 "결정적 값은 서버가 계산하고 LLM은 해석만 한다"는 원칙 하나다(`:47`). #1~#3은 만세력·절기·대운 계산 규칙으로 이 제품 도메인에 없다. #4(`FOR ALL` RLS), #5(크레딧 원자 차감 부재), #6(Puppeteer on Vercel)는 일반 결함이지만 같은 계열을 SellingDocs #1·#2와 flora #3·#5의 차단 설계가 이미 덮고, 원천 자산(만세력 코드, Puppeteer 경로)을 하나도 옮기지 않는다. 해당 결함의 정본 차단 설계는 astro-ai가 소유한다 | `docs/reference/reviews/FortuneDocs.md:40-45`, `D:/WorkSpace/platform/docs/products/astro-ai/02_ARCHITECTURE.md:205-207`, `D:/WorkSpace/platform/docs/products/astro-ai/05_DATA_MODEL.md:269-271` |
| `D:/WorkSpace/platform/docs/reviews/Flora-v2.md` | 9 | 제외 | Flora-v2에서 가져오는 자산이 없다. #1·#2(로그인 토큰 폐기, Bearer 미전송), #6~#9(업로드·전체 집필·내보내기 계약 불일치, `tsc` 실패)는 v2 프론트-백엔드 계약 결함이고, #3~#5는 v1 #1·#3·#6의 미해결 반복이라 flora v1 차단 설계로 이미 덮인다. 정본 차단 설계는 flora-publishing이 소유한다 | `D:/WorkSpace/platform/docs/reviews/Flora-v2.md:61-69`, `D:/WorkSpace/platform/docs/products/flora-publishing/02_ARCHITECTURE.md:240-245`, `D:/WorkSpace/platform/docs/products/flora-publishing/05_DATA_MODEL.md:212-214` |

## 3. 원본 매핑

원본 프로젝트가 없으므로 이식 원천을 원본 매핑으로 쓴다. 상세는 `07_SOURCE_MIGRATION.md`.

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| flora-publishing(설계) | `D:/WorkSpace/platform/docs/products/flora-publishing/` | 기획만 | LangGraph 초안 그래프 패턴(개요 → 초안 → 일관성 → 교정 → compliance), Tiptap + 선택영역 툴바 + Diff 카드 + 서버 sanitize, 업로드 파서(txt/md/docx/pdf, 매직바이트, 20MB), RLS 복합 FK·상태 전이 트리거 패턴, 크레딧 선차감·환불 흐름 | 판형·표지·페르소나 60종·ePub·TTS 낭독·3D 책 소재 |
| flora v1 | `docs/reference/reviews/flora.md` | 약 55%(`docs/reference/reviews/flora.md:23`) | export 경로 교훈(WeasyPrint 단일화, Noto CJK 폰트), 업로드 파서 | Word 호환 HTML(.doc), Typst, 페르소나, n8n 전역 키 |
| SellingDocs | `docs/reference/reviews/SellingDocs.md` | 약 35%(`docs/reference/reviews/SellingDocs.md:20`) | "구조화 JSON → HTML 템플릿 → PDF" 파이프라인, 크레딧 원자 차감 교훈, 챕터(섹션) 분리 생성 | 단일 JSON 일괄 생성, Next/Vercel 안의 WeasyPrint |
| FortuneDocs | `docs/reference/reviews/FortuneDocs.md` | 약 40%(`docs/reference/reviews/FortuneDocs.md:21`) | "결정적 값은 서버 계산, LLM은 해석만" 원칙(`:47`), 구조화 리포트 → PDF | 만세력·사주 도메인 |
| platform-docs 문서 표준 | `docs/file/03-설계/공용코어/DOC_TEMPLATE.md`, `docs/develop/_shared/tools/build_root.py`, `D:/WorkSpace/platform/docs/products/_STRUCTURE_CHECK.md` | 기획만 | `req_spec`·`sow`·설계서류의 장 구조와 표 컬럼, 산출물 ID·등록부(상태·버전·상위 ID) 모델, 품질 점검표 → lint 규칙 | 내부 개발 전용 표기(모델 배정, `경로:줄` 근거) |
| admin-suite ERP | `D:/WorkSpace/platform/docs/products/admin-suite/`, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql` | 기획만 | 연동 대상 스키마(`erp.products`, `erp.sales`, `erp.employees`) | 없음(읽기만) |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, 범위, 기능 요구사항(DC-F-001~045), 체크리스트 효과 엔진 명세, 문서 유형 표, 요금/크레딧(전부 제안), 비기능 수치, 법/개인정보/금지 문구, KPI, 열린 결정(D-1~D-12) |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계(효과 엔진, 생성 그래프, 렌더, 연동 어댑터), 공용 모듈 사용, 잡 타입, AI 라우팅, 리뷰 "높음" 비보안 결함의 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 플로우(가입 → 첫 패키지 → 결제 포함), 체크리스트 마법사·편집기·추적표 화면 명세, 랜딩 디자인 방향(3D 히어로), 상태/오류, 접근성 |
| `04_API.md` | Route Handler, RPC(SECURITY DEFINER), 잡 페이로드 계약, 수신·발신 웹훅, 외부 API 어댑터(HubSpot, ERP), 오류 코드(`DC001`~`DC010`) |
| `05_DATA_MODEL.md` | 스키마 `docs` 테이블(카탈로그, 워크스페이스, 프로젝트, 문서, 연동, 운영), 상태 전이, RLS, 코어 참조, 리뷰 "높음" 보안·데이터 결함의 차단 설계, 모놀리스와 모듈러 차이 |
| `06_AGENT_PLAN.md` | 문서 간 불일치 정리와 타당성 교차검증 기록(1장), 작업 목록(`DC-06-###`), 웨이브, 모델별 비율, 리뷰 작업 흡수표, 코어 요청(C-1~C-7) |
| `07_SOURCE_MIGRATION.md` | 이식 원천별 자산 분류, 이식 자산 상세, 폐기 목록과 사유, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/` | `monolith/migrations/0001_core_lite.sql`(코어 축소판 복사본), `0002_nomad_docs_domain.sql`(도메인), `monolith/seed.sql`(앱·플랜·크레딧팩·카탈로그 seed), `monolith/tests/rls_smoke.sql`(RLS·권한 회귀 59항목, `DOC_TEMPLATE.md` 2.10절) |
| `../_supabase-modular/migrations/2300_docs.sql` | 모듈러 조각(스키마 `docs`, 번호 2300~2399). 모놀리스 0002와 같은 도메인 모델 |

## 5. DB 구조 선택

| 항목 | 내용 |
|---|---|
| 1차 출시 | 모듈러(스키마 `docs`, 조각 `2300_docs.sql`). `DB_CONVENTIONS.md` 2장 번호 표의 다음 빈 범위다(`docs/file/03-설계/공용코어/DB_CONVENTIONS.md:26-41`, 마지막 `2200~2299 site`) |
| 이유 | (1) Phase 2 admin-suite ERP 연동은 같은 모듈러 DB의 `erp` 스키마를 service_role 함수로 읽는 방식이 가장 단순하다. ERP는 1차 모듈러다(`D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:44`). (2) 공용 WeasyPrint 렌더 서비스와 크레딧팩 모델을 flora-publishing과 같은 구조로 쓴다(같은 이유로 publishing이 모듈러, `:36`). (3) 코어 인증만으로 가입 개방 베타가 가능하다(study-note 근거 `:39`). `ARCHITECTURE.md:31-46` 표에는 이 제품 행이 없으므로 위 세 행에서 유추한 판단이다(제안) |
| 모놀리스 제공 이유 | 고객사 전용 설치형(설치형 판매, 기밀 RFP를 다른 제품과 같은 DB에 두기 싫은 고객)이나 베타를 독립 Supabase 프로젝트로 먼저 띄울 때 쓴다. 같은 함수 이름과 시그니처를 유지하고 `SUPABASE_DB_SCHEMA`만 바꾼다. 모놀리스에서는 ERP 교차 스키마 읽기가 불가능하므로 ERP 연동은 Phase 3 API 방식(코어 요청 C-2 API 키)으로 바뀐다 |
| 이동 | 모놀리스 → 모듈러 흡수 절차는 `D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:50-59`를 따른다 |
| 코어 사용 | 크레딧 선차감, 잡 큐, Storage(`org-files`, `exports`), 자격증명 vault(`core.encrypted_credentials`, 연동 토큰), OAuth state(HubSpot), 웹훅 이벤트, AI·음성 테이블(`core.ai_*`, `core.wiki_*`, `core.voice_*`)을 쓰므로 모놀리스 코어 축소판에서도 해당 SECTION을 유지한다. 제거 범위와 사유는 `0001_core_lite.sql` 안 주석에 적는다 |
| 주의 | `docs.clauses`, `docs.doc_type_versions`, `docs.checklist_items`는 org가 없는 플랫폼 카탈로그라 service_role만 쓴다. 조직 맞춤 조항(`clauses.org_id` 값 있음)은 Phase 2에서 쓰기 경로를 연다(`01_PRD.md` DC-F-019, DC-F-045) |
