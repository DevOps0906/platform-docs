# NOMAD Book Trailer (book-trailer)

작성일 2026-10-15. 신규 단독 제품, 공개 베타, 가입 개방(`core.apps.id='trailer'`, `signup_policy='open'`, `status='beta'`). 이 폴더는 기획 문서와 SQL만 있고 앱 코드는 없다(`D:/WorkSpace/platform/docs/products/_PRODUCT_AGENT_BRIEF.md`). 브랜드 최종명은 열린 결정 D-1이다(`01_PRD.md` 8장).

## 1. 한 줄 정의

원고(PDF·EPUB·DOCX·MD·TXT)나 FLORA 책을 넣으면 AI가 원고를 읽고 "팔리는 훅"을 찾아 브리프를 만들고, 장르별 트레일러 문법으로 스토리보드를 짜고, 장면 이미지·내레이션·자막·음악을 붙여 쇼츠(9:16)·유튜브(16:9)·인스타(1:1, 4:5)·표지 루프 영상을 한 번에 렌더한 뒤, 구매 링크 클릭까지 측정하는 북트레일러 자동화 SaaS다.

| 대상 | 상황 | 단계 |
|---|---|---|
| 1인 출판사·작가 | 신간마다 홍보 영상이 필요하지만 외주(30초 22만 원~)는 매 권 맡기기 어렵다 | MVP |
| 중소 출판사 마케터 | 월 신간 여러 종, 규격 4종, 저자 승인 절차, 영상별 성과 측정 | MVP(승인 링크·팀은 P1) |
| 웹소설·전자책 작가 | 회차·신간 쇼츠를 스포일러 없이 꾸준히 | MVP |
| 출판 마케팅 대행사 | 여러 출판사 계정 대행, 자기 브랜드로 납품 | Phase 2(화이트라벨) |

AI 요약: 원고를 1회 분석해 장 요약·인물·주제와 RAG 색인을 만들고(`trailer.digest`), 브리프 3안(로그라인, 훅, 원고 대조 통과 인용, 스포일러 수준)을 낸다(`trailer.brief`). 장르 문법 6종에 맞춰 스토리보드(`trailer.storyboard`)와 플랫폼별 메타데이터(`trailer.meta`)를 만든다. 장면 이미지는 fal Flux(스타일 고정), 내레이션은 같은 목소리 규칙, 렌더는 Remotion 컴포지션(앱과 영상이 같은 디자인 토큰 체계). 책 근거 Q&A 코치(Dify `trailer-chat`, 출처 장·문단), 책 설정 위키, 음성 대화를 MVP에 둔다.

## 2. 통합 근거

| 항목 | 내용 | 근거 |
|---|---|---|
| 통합 대상 | 없다. 기존 리뷰 대상 프로젝트를 합친 제품이 아니라 신규 제품이다. 기존 제품 설계와 리뷰에서 검증된 패턴을 "이식 원천"으로 가져온다(3장) | 사용자 요청(2026-10-15) |
| 베이스 | 코드 베이스 없음. 설계 패턴 베이스는 nomad-video(이미지·TTS 경로, 같은 목소리 규칙, compliance 노드, 고객 승인)와 toon-factory(장면 단위 저장·재생성, 서버 렌더 워터마크, 라이선스 CHECK). 이유: 같은 "AI 에셋 → 합성 → 렌더" 흐름이고 이미 "높음" 결함 차단 설계를 거쳤다 | `D:/WorkSpace/platform/docs/products/nomad-video/02_ARCHITECTURE.md:176`, `:227-238`, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2000_toon.sql:94-115`, `:476-497` |
| 다른 제품과의 경계 | 책을 만드는 일은 flora-publishing, 다채널 예약·분석은 nomad-video, 캐릭터 일관성은 toon-factory가 소유한다. 이 제품은 "이미 나온 책을 홍보 영상으로" 하나에 집중하고 셋과는 연동(FLORA 가져오기 P1, nomad-video로 보내기·캐릭터 엔진 Phase 2)으로만 만난다 | `01_PRD.md` 2장, D-10 |
| 확정 결정 적용 | 4 Toss, 5 org 기준 스키마와 1인 1워크스페이스, 13 AI 계층(FastAPI LangGraph, pgvector RAG), 14 Dify 앱 1개(`trailer-chat`), 15 3D 히어로, 16 음성, 17 LLM 이원화와 국외 이전 동의, 22 인증 단계 | `docs/reference/00_MERGE_ANALYSIS.md:5-30` |
| 확정 결정 밖 | 결정 6(TS 오케스트레이션 + Python 미디어)은 nomad-video 범위다. 이 제품은 렌더 엔진을 D-2로 두고 Remotion(Node)으로 설계했다. 요금은 전부 제안(`01_PRD.md` 4장, `Price_Plans/book-trailer/PRICE_PLAN.md`) | `01_PRD.md` 2장 끝 |
| 공유하는 것 | `_platform-core` 공용 모듈만 인용한다: auth, org, credits, toss, webhooks, oauth, storage, audit, jobs, compliance, ai-gateway, ai-service, dify, core-voice, llm-wiki, sns-uploader(P1). 재정의하지 않는다 | `docs/file/03-설계/공용코어/SHARED_MODULES.md` |

### 2.1 리뷰 "높음" 결함 차단 범위

이 제품은 기존 원본의 코드를 옮기지 않지만, 이식하는 자산과 같은 계열의 실패가 반복될 수 있는 원천의 "높음" 결함은 전부 차단 설계 대상으로 삼는다. 합계 18건이며 보안·데이터 10건은 `05_DATA_MODEL.md` 7절, 비보안 8건은 `02_ARCHITECTURE.md` 6절에 둔다.

| 리뷰 | 높음 수 | 대상 여부 | 이유 | 근거 |
|---|---|---|---|---|
| `docs/reference/reviews/NOMAD_Shorts_Maker.md` | 12 | 대상 | 이식하는 미디어 파이프라인(이미지·TTS·합성·업로드)의 원천인 nomad-video의 원본이다. 크레딧 RPC 개방(#1), 웹훅 서명(#2), orderId(#3), 헤더 우회(#4), OAuth state(#5), Mock 로그인(#6), 0키 폴백(#7), 세션 없는 백그라운드(#8), 단계 동시 enqueue(#9), 워커 결합(#10), 빌드 실패(#11), Next 16 params(#12) 모두 이 제품의 생성·렌더·결제·업로드 경로에서 같은 형태로 다시 생길 수 있다 | `docs/reference/reviews/NOMAD_Shorts_Maker.md:78-89` |
| `docs/reference/reviews/Toon-Factory.md` | 6 | 대상 | 장면 단위 편집·렌더·워터마크·에셋 카탈로그를 이식한다. 브라우저 렌더 워터마크(#1), 공개 에셋 버킷(#2), 컷 단위 부재(#3), 레이어 필드 부족(#4), LoRA 일정 위험(#5), 스톡 라이선스(#6)는 트레일러 렌더·이미지 스타일·음악 카탈로그에서 그대로 재발할 수 있다 | `docs/reference/reviews/Toon-Factory.md:45-50` |
| `D:/WorkSpace/platform/docs/reviews/Youtube_shots_Maker.md` | - | 제외 | 이 제품은 YouTube 업로드를 공용 sns-uploader 소비자로만 쓴다. 해당 원본의 결함 차단 설계는 nomad-video가 소유한다 | `D:/WorkSpace/platform/docs/products/nomad-video/README.md` 2장, `D:/WorkSpace/platform/docs/products/nomad-video/02_ARCHITECTURE.md` 6장 |
| `D:/WorkSpace/platform/docs/reviews/flora.md`, `Flora-v2.md`, `SellingDocs.md` | - | 제외 | 업로드 계약·파서 교훈만 flora-publishing·nomad-docs 설계를 거쳐 참고한다(원천 코드 이식 없음). 같은 계열 결함(업로드 경로 조작, 렌더러 SSRF, 폰트 경로)은 `07_SOURCE_MIGRATION.md` 4절 복사 금지 표로 막고, 정본 차단 설계는 flora-publishing·nomad-docs가 소유한다 | `D:/WorkSpace/platform/docs/products/flora-publishing/02_ARCHITECTURE.md` 6장·`05_DATA_MODEL.md` 7장, `D:/WorkSpace/platform/docs/products/nomad-docs/README.md` 2.1절 |

## 3. 원본 매핑

원본 프로젝트가 없으므로 이식 원천을 원본 매핑으로 쓴다. 상세는 `07_SOURCE_MIGRATION.md`.

| 원본 프로젝트 | 리뷰 파일 | 완성도 | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| nomad-video(설계) | `D:/WorkSpace/platform/docs/products/nomad-video/` | 기획만 | 이미지 경로(fal, 안전 검사), 같은 목소리 규칙, compliance 노드, 고객 승인 링크, 크레딧 단가 구조, 잡 토큰, sns-uploader 소비 | BullMQ·Python 미디어 워커, FFmpeg 단일 엔진 결정, Track A~D·레이더 |
| toon-factory(설계·SQL) | `D:/WorkSpace/platform/docs/products/toon-factory/`, `2000_toon.sql` | 기획만(SQL 검증) | 장면 낙관적 동시성 저장, 장면 단위 재생성, 서버 렌더 워터마크, 음악 라이선스 CHECK, 비공개 원본·공개 미리보기 버킷 | Fabric.js 캔버스·말풍선·표정 교체, LoRA |
| flora-publishing(설계) | `D:/WorkSpace/platform/docs/products/flora-publishing/` | 기획만 | 업로드 계약, LangGraph 그래프 패턴, 30일 purge, FLORA 원고 가져오기(연동) | 판형·표지·페르소나·ePub 생성·낭독·3D 책 소재 |
| nomad-docs(설계) | `D:/WorkSpace/platform/docs/products/nomad-docs/` | 기획만 | "결정적 값은 서버" 원칙, RFC 5987 한글 파일명, 파서 선택, 진행률 규칙, `core.jobs` 단일 큐 구조 | 없음(참고만) |
| NOMAD Shorts Maker(코드) | `docs/reference/reviews/NOMAD_Shorts_Maker.md` | 약 35% | 켄번스·워터마크 움직임 교훈(구현은 새로 작성) | 메모리 버퍼 업로드, Mock 로그인, `x-internal-call`, user 스키마, 더미 대시보드 |
| Toon-Factory(기획) | `docs/reference/reviews/Toon-Factory.md` | 기획만 | 첫 진입 빠른 완성 경험, 공개 페이지 JSON-LD | 브라우저 FFmpeg.wasm 렌더 |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, 범위, 기능 요구사항(TR-F-001~135, TR-F-001은 인증 단계 A·B·C), 플랜·크레딧 단가(전부 제안), 비기능 수치, 법·개인정보·권리 확인·인용 한도·AI 표시·금지 문구·도서정가제·플랫폼 약관·대가성 문구, KPI, 열린 결정(D-1~D-17, 인증 D-14~D-17은 8.1절) |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계(web, 오케스트레이터, 렌더러, 컴포지션, FastAPI), 공용 모듈 사용, 잡·렌더 파이프라인·크론, AI 라우팅 16행, 그래프 4종, 같은 목소리 규칙, 이미지 스타일 고정, 리뷰 "높음" 비보안 8건 차단 설계, 배포, 환경변수, 인증 단계(9절) |
| `03_SCREENS_UX.md` | 화면 목록과 패턴, 플로우 7개, 화면 명세(홈, 책 등록 마법사, 책 상세, 브리프 비교, 작업실, 렌더 기록, 게시, AI·음성·위키), 랜딩 디자인 방향(레퍼런스, 토큰 플랜, 3D 히어로), 상태·오류, 접근성, 로그인 화면(7절) |
| `04_API.md` | Route Handler, AI·음성 경로, RPC, 잡 payload·브리프·장면·렌더 스냅샷 계약, 웹훅, 외부 어댑터, FastAPI·Dify 계약, 오류 코드(`TR001`~`TR011`, `TR409`), 로그인 경로(8절) |
| `05_DATA_MODEL.md` | 스키마 `trailer` 테이블 17개(카탈로그 4, 사용자 7, 서버 6), 상태 전이, RLS, 인덱스, 코어 참조, 리뷰 "높음" 보안·데이터 10건 차단 설계, 모놀리스와 모듈러 차이, 마이그레이션 파일, 개발용 시드 페르소나(10절) |
| `06_AGENT_PLAN.md` | 작업 60개(`TR-06-###`, 인증 단계 포함), 웨이브 W0~W7, 모델별 비율, 리뷰 작업 흡수표(SM 15 + Toon 14), 공용 모듈 요청 R-T1~R-T8, 완료 정의 |
| `07_SOURCE_MIGRATION.md` | 이식 원천별 자산 분류, 이식 상세, 폐기 목록(TS-01~12), 복사 금지 결함, 인증 단계 복사 금지(6절) |
| `08_DESIGN_SYSTEM.md` | 두 층 디자인 시스템: 층 A 앱 토큰(교정지·인쇄 먹·형광 밑줄 팔레트, 서체, `DESIGN.md` 초기값), 층 B 영상 토큰(표지 → 브랜드 키트, OFL 서체 8종, 캔버스·안전 영역·타입 스케일, 문법 6종, 모션, 자막, 믹스, 이미지 스타일, 장면 컴포넌트 8종, AI 표시·워터마크, 변주 규칙), 앱 컴포넌트(`COMPONENTS.md` 초기값), 접근성, 작업 지시 예시, 검증 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/` | `monolith/migrations/0001_core_lite.sql`(코어 축소판), `0002_trailer_domain.sql`(도메인), `monolith/seed.sql`(앱·플랜·크레딧팩·카탈로그), `monolith/tests/rls_smoke.sql`(RLS·권한 회귀 124항목) + `run-smoke.mjs`(PGlite 러너, `--target mod\|mono`) |
| `../_supabase-modular/migrations/2600_trailer.sql` | 모듈러 조각(스키마 `trailer`, 번호 2600~2699). 모놀리스 0002와 같은 도메인 모델 |

관련 폴더: `Price_Plans/book-trailer/PRICE_PLAN.md`(요금·판매 모델), `develop/book-trailer/`(개발 착수 가이드, 설치 스크립트, 개발 루트 번들).

## 5. DB 구조 선택

| 항목 | 내용 |
|---|---|
| 1차 출시 | 모듈러(스키마 `trailer`, 조각 `2600_trailer.sql`). 2400은 arch-studio(제안), 2500은 local-news가 먼저 잡았으므로(`D:/WorkSpace/platform/docs/products/README.md` 제품 표) 다음 빈 범위 2600~2699를 쓴다. SQLSTATE 접두사 `TR`. `DB_CONVENTIONS.md` 2장 표 등록은 공용 모듈 요청 R-T2 |
| 이유 | (1) FLORA 가져오기(P1)는 같은 모듈러 DB의 `publishing` 스키마를 service_role 함수(`import_flora_book`)로 읽는 방식이 가장 단순하다. (2) 공용 ai-service·sns-uploader·크레딧팩을 nomad-video·flora-publishing과 같은 구조로 쓴다. (3) 코어 인증만으로 가입 개방 베타가 가능하다 |
| 모놀리스 제공 이유 | 출판사 전용 설치형(원고를 다른 제품과 같은 DB에 두기 싫은 출판사, 화이트라벨 Phase 2)이나 베타를 독립 Supabase 프로젝트로 먼저 띄울 때 쓴다. 같은 함수 이름과 시그니처를 유지하고 `SUPABASE_DB_SCHEMA`만 바꾼다. 모놀리스에서는 FLORA 교차 스키마 읽기가 불가능해 `import_flora_book`이 `TR010`을 낸다 |
| 이동 | 모놀리스 → 모듈러 흡수 절차는 `D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md`를 따른다 |
| 코어 사용 | 크레딧 선차감, 잡 큐, Storage(`org-files`, `exports`), 자격증명 vault(채널 토큰, P1), OAuth state, 웹훅 이벤트, AI·음성 테이블(`core.ai_*`, `core.wiki_*`, `core.voice_*`)을 쓰므로 모놀리스 코어 축소판에서도 해당 섹션을 유지한다 |
| 검증 | `D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs --vector`로 모듈러 전체(코어 + seed + 조각 16개, 정순·역순)와 모놀리스 적용 OK. RLS 스모크 124/124(모듈러·모놀리스) |

변경 기록(장 구조는 `DOC_TEMPLATE.md` 2.1절 5장 그대로 두고 여기에 적는다):

| 날짜 | 변경 | 근거 |
|---|---|---|
| 2026-10-15 | 최초 작성: 기획 01~08, `2600_trailer.sql`, 모놀리스 3종, RLS 스모크 124항목, 작업 60개 | 사용자 요청(2026-10-15) |
