# FLORA Publishing (flora-publishing)

작성일 2026-10-12. 단계 2 제품 기획서. 장 구조는 `docs/file/03-설계/공용코어/DOC_TEMPLATE.md` 2.1절을 따른다.

## 1. 한 줄 정의

FLORA Publishing은 원고는 있지만 편집·조판 경험이 없는 1인 작가가 AI와 함께 기획, 집필, 판형 조정을 거쳐 인쇄용 PDF와 ePub을 완성하는 전자책 출판 SaaS다(`docs/reference/00_MERGE_ANALYSIS.md:53`).

| 항목 | 내용 | 근거 |
|---|---|---|
| 대상 사용자 | 1인 작가·에세이스트, 콘텐츠를 책으로 묶으려는 크리에이터, 소규모 독립 출판사 | `Flora-v2/PRD.md:18-24` |
| MVP 범위 | 전자책만(사진집, 룩북, 오디오북 전권, 캔버스 제외. 원고 낭독·미리듣기는 포함) | 확정 결정 7, `docs/reference/00_MERGE_ANALYSIS.md:15` |
| 과금 | 크레딧팩 + 저가 구독(Toss Payments) | 확정 결정 4, 8, `docs/reference/00_MERGE_ANALYSIS.md:12`, `:16` |
| 백엔드 | Next.js + FastAPI(출판 엔진 `engine/`, AI 서비스 `api/`). WeasyPrint 렌더 서비스는 astro-ai와 공용이며 이 제품이 소유 | 확정 결정 3, `docs/reference/00_MERGE_ANALYSIS.md:11`, `docs/file/03-설계/공용코어/SHARED_MODULES.md:37` |
| 테넌시 | org 기준 스키마, 운영은 1인 1워크스페이스 | 확정 결정 5, `docs/reference/00_MERGE_ANALYSIS.md:13` |
| AI·음성·3D (2026-10-13) | 책별 RAG, 책 설정집 위키, LangGraph 초안 그래프 `publishing.draft`(개요 → 초안 → 일관성 검사 → 교정 → compliance), Dify 글쓰기 도우미 채팅, 받아쓰기·채팅 음성·원고 낭독(미리듣기), 상용/오픈소스 모델 이원화와 국외 이전 동의, 원고 낱장이 제본되는 3D 히어로, Tailwind CSS v4 디자인 시스템(주 레퍼런스 Atlassian, 보조 Primer) | 확정 결정 13~17(`docs/reference/00_MERGE_ANALYSIS.md:21-25`) |

## 2. 통합 근거

| 근거 | 내용 | 출처 |
|---|---|---|
| 같은 제품 | 네 원본 모두 "1인 출판 AI SaaS"다. SellingDocs는 Flora-v2 기능의 부분집합이고, flora-publisher의 메뉴와 동봉 PRD도 v1/v2의 부분집합이다 | `docs/reference/reviews/SellingDocs.md:42`, `docs/reference/reviews/flora-publisher.md:115` |
| 베이스 = Flora-v2 | 세 리뷰가 모두 v2를 본선으로 권고한다. 기획 문서가 가장 상세하고(PRD 547줄, DESIGN 689줄) 프론트가 단계별 컴포넌트로 분해돼 있으며 LLM 호출이 비동기다 | `docs/reference/reviews/Flora-v2.md:189`, `docs/reference/reviews/flora.md:188`, `docs/reference/00_MERGE_ANALYSIS.md:55-60` |
| v1 엔진 이식 | v2는 완성도 약 30%로 끝까지 동작하지 않는다. v1의 검증된 엔진(WeasyPrint, ePub3, 판형 프리셋, 표지 제공자 라우팅, 다중 LLM 폴백)을 옮긴다 | `docs/reference/reviews/Flora-v2.md:23-26`, `:190`, `docs/reference/00_MERGE_ANALYSIS.md:62` |
| SD 흡수 | 크레딧 원자 차감과 챕터 테이블 분리 설계만 가져온다 | `docs/reference/00_MERGE_ANALYSIS.md:65`, `docs/reference/reviews/SellingDocs.md:81` |
| FP 흡수 | 집필 큐(재시도 3회)와 마이크로 프롬프트 에디터 흐름만 반영하고 코드는 아카이브 | `docs/reference/00_MERGE_ANALYSIS.md:66`, `flora-publisher/frontend/docs/prd/03_features.md:83-97`, `:110-127` |
| 확정 결정 | 3(Next + FastAPI, WeasyPrint 공용), 4(Toss), 5(org 테넌시), 7(전자책만), 8(크레딧팩 + 저가 구독) | `docs/reference/00_MERGE_ANALYSIS.md:5-20` |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `Flora-v2/` | `docs/reference/reviews/Flora-v2.md` | 약 30% (`:23`) | 10단계 위저드 구조와 단계 컴포넌트, 페르소나 60종 데이터, Auto-Fit 6종 키, 테마 7종, 시드 3종, 업로드 파서(txt/md/docx/pdf), 기획 문서 | GoTrue raw fetch 로그인, `user_plans FOR ALL`, `'1234'` 잠금해제, 수제 ePub2, fpdf2, 캔버스·n8n·Make 스텁, 죽은 코드 |
| `flora/` (v1) | `docs/reference/reviews/flora.md` | 약 55% (`:23`) | `call_llm` 폴백 설계, `export.py` WeasyPrint/ePub3, `print-presets.ts`(@page, 제책 여백), `html-templates.ts`, `build-html` 라우트, 표지 프롬프트, 어조 슬라이더, 옴니버스 프롬프트 | 4,095줄 위저드, Typst, DOC, mock 폴백, BYOK, F5-TTS 벤더링, Stripe 미검증 웹훅 |
| `flora-publisher/` | `docs/reference/reviews/flora-publisher.md` | 약 10% (`:19`) | PRD의 집필 큐(재시도 3회, 실패 챕터 표시)와 마이크로 프롬프트(선택영역 툴바, `/` 명령, Diff) 흐름, ₩9,900 저가 구독 가격 근거 | Vite SPA, Express Vertex 프록시, fetch/WebSocket 몽키패치, Google Books 검색, NextAuth |
| `구현해야 할 프로젝트/SellingDocs/` | `docs/reference/reviews/SellingDocs.md` | 기획 약 35% (`:20`) | 크레딧 차감 경계 요구, chapters 분리·`layout_settings`·`is_public`·`exports` 데이터 설계, 기획 입력 6필드 중 "타겟 독자, 강조 톤", GEO JSON-LD(Phase 2) | Route Handler에서 WeasyPrint 실행 가정, LLM 4사 직접 연동, 책 전체 단일 JSON 생성, QuickChart |
| `WeasyPrint - CSS Paged Media 명세.md` | 해당 없음 | 해당 없음 | PDF 템플릿 CSS 기준(@page :left/:right, :first, 쪽번호 counter, string-set 러닝 헤더, 점선 목차) | 없음 |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구사항(PB-F-###)과 수용 기준, 요금과 크레딧 단가, 비기능 수치, 법·개인정보·금지 문구, KPI, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계(Next / TS 워커 / FastAPI 엔진 / FastAPI AI 서비스 / 렌더 서비스), 공용 모듈 사용표, 잡 타입, AI 라우팅 기본값과 그래프 `publishing.draft`·`publishing.assist`, 리뷰 "높음" 비보안 결함 차단 설계 13건, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 핵심 플로우 11개, 화면별 명세, AI 채팅·음성·설정집 화면, 디자인 시스템, 메인페이지 디자인 방향(레퍼런스, 브리프, 토큰 플랜, 와이어프레임 2안, 3D 히어로), 상태·오류 |
| `04_API.md` | Route Handler, 제품 RPC, 잡 페이로드 계약, 렌더 서비스 계약, 웹훅, 외부 API, 오류 코드(PB###) |
| `05_DATA_MODEL.md` | 테이블 12개, 상태 전이, RLS 정책, 인덱스, 코어 참조, 리뷰 "높음" 보안·데이터 결함 차단 설계 12건, 모놀리스와 모듈러 차이, RLS 스모크 결과 |
| `06_AGENT_PLAN.md` | 작업 55개(AI·음성·3D·디자인 시스템 17개 포함, PB-06-###), 소유 경계, 웨이브, 모델 비율, 리뷰 5장 작업 55건 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/참고/폐기 자산, 이식 시 수정점, 분석 "폐기" 38건 전부와 사유, 복사 금지 결함, 아카이브 절차 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용: `0001_core_lite.sql`(코어 축소판, OAuth state와 affiliate 절 제거), `0002_publishing_domain.sql`, `seed.sql` |
| `../_supabase-modular/migrations/1000_publishing.sql` | 통합 DB용 `publishing` 스키마 조각(모놀리스 도메인의 정본). 15절에 AI·음성 라우팅 기본값 12행과 플랜 AI 키 6개 |

## 5. DB 구조 선택

| 항목 | 결정 | 근거 |
|---|---|---|
| 기본 배포 | 모듈러(통합 DB, `publishing` 스키마). astro-ai와 같은 계정(SSO)과 같은 크레딧 지갑을 쓰고, WeasyPrint 렌더 잡을 같은 `core.jobs`로 다룬다 | `docs/file/03-설계/공용코어/CORE_SPEC.md:36`, `D:/WorkSpace/platform/docs/products/_supabase-modular/README.md:5` |
| 모놀리스 | 같은 도메인 모델을 `public` 스키마로 변환해 둔다. 제품을 단독 프로젝트로 분리할 때 쓴다. 모놀리스 스키마 `public`은 사용자 최종 확인 대기 | `D:/WorkSpace/platform/docs/products/_platform-core/MONOLITH_CORE_LITE.sql:5-10`, `docs/file/03-설계/공용코어/DB_CONVENTIONS.md` 12장 |
| 정본 관계 | 모듈러 조각이 정본이다. 모놀리스 `0002_publishing_domain.sql`은 조각을 규칙대로 변환한 결과이며 직접 고치지 않는다 | `DB_CONVENTIONS.md` 12장 마지막 문단 |
| 검증 | 두 구조 모두 SQL 체커(`--vector`) OK, RLS 스모크 57항목 통과(05장 9절), AI 라우팅 기본값 12행 확인(2026-10-13) | `D:/WorkSpace/platform/docs/products/_tools-sqlcheck` |
