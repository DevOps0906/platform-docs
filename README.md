# platform-docs — NOMAD 통합 플랫폼 기획·개발 문서 저장소

여러 SaaS 프로젝트의 코드 리뷰를 근거로 제품을 통합 기획하고, 제품마다 바로 개발을 시작할 수 있는 개발 묶음(설치 스크립트 + 근거 문서 + DB)과 가격·화이트라벨·데스크톱·모바일 공용 설계를 담은 저장소입니다. **앱 코드는 없고 문서(Markdown)와 SQL만** 있습니다. 실제 개발은 이 저장소가 아니라 개발 묶음을 붙인 별도 개발 폴더에서 합니다(6장).

로컬 위치는 `D:\WorkSpace\platform\docs`를 기준으로 합니다. 문서 안의 경로가 이 위치를 씁니다.

## 0. 한눈에 보기 (2026-10-18 기준)

| 항목 | 수 | 위치 |
|---|---|---|
| 원본 프로젝트 코드 리뷰 | 25개(PDF 25개) | `reviews/`, PDF는 별도 레포 PDF_Collections |
| 확정 결정 | 22개 | `products/00_MERGE_ANALYSIS.md` 상단 |
| 기획 제품 | 16개(모두 01~07 완료). BM·사업성은 별도 레포 BM-CORE(10장) | `products/<제품>/` |
| 개발 묶음 | 16개, 작업 합계 1,011개 | `develop/<제품>/` |
| 공용모듈 개발서(V2) | 16개 | `develop_V2/<제품>/` |
| 공용모듈 기획 | 7개(제안) + 기존 4개 보강 | `products/_platform-core/common-modules/` |
| 가격 플랜 | 제품 15개 + 서비스 사업 1개(arch-studio는 아직 없음, 요금은 01_PRD 4장) | `Price_Plans/` |
| 공용 설계 가이드 | 화이트라벨, 데스크톱(Tauri), 모바일(Capacitor) | `Multi-tenant_Theming/`, `Tauri/`, `Capacitor/` |
| 통합 DB 조각 | 코어 10개 + 제품 17개 | `products/_supabase-modular/migrations/` |
| 설득형 랜딩 템플릿 | 공통 1개 + 제품별 16개 | `nomad-design-modules/_design-guide/templates/persuasion-landing/` |
| 전체 파일 | 1,540개, 폴더 434개(별도 레포 `nomad-design-modules`, `PDF_Collections` 제외, 이 중 파일 1,065개는 `develop/*/*-root/`에 생성된 사본) | [`FOLDER_TREE.md`](FOLDER_TREE.md) |

## 1. 문서가 흐르는 순서

이 저장소의 문서는 아래 순서로 만들어졌고, 앞 단계가 뒤 단계의 근거입니다.

```
reviews/  원본 25개 코드 리뷰(결함, 이식할 자산)
   │
   ▼
products/00_MERGE_ANALYSIS.md  통합 분석 + 확정 결정 22개(분석 본문보다 우선)
   │
   ├──▶ products/_platform-core/   공용 코어 규격(인증·조직·크레딧·결제·잡·AI·음성·보안·DB 규칙)
   ├──▶ nomad-design-modules/_design-guide/  (별도 레포) 디자인 시스템, 3D 히어로, 레퍼런스
   ├──▶ products/_supabase-modular/ 통합 DB(core + 제품 스키마)
   │
   ▼
products/<제품>/  제품 기획서 01~07 + CLAUDE.md + 모놀리스 SQL     ← 무엇을 만드는가(정본)
   │
   ├──▶ Price_Plans/<제품>/   가격 분석·단계별 계획(요금 정본은 각 01_PRD 4장)
   │
   ▼
develop/<제품>/   개발 안내서 + setup 스크립트 + <제품>-root/(기획서 사본 묶음)   ← 어떻게 시작하는가
develop_V2/<제품>/  공용모듈을 쓸 때 바뀌는 부분만 적은 개발서
   │
   ▼
D:\WorkSpace\DEV\<제품>\   실제 개발 폴더(이 저장소 밖, Claude Code 멀티에이전트로 개발)

공용 설계(모든 제품이 필요할 때 참조): Multi-tenant_Theming/  Tauri/  Capacitor/  common-modules/
```

## 2. 폴더 지도

폴더 444개를 모두 펼친 트리는 [`FOLDER_TREE.md`](FOLDER_TREE.md)에 있습니다(`python3 -I _tools/folder_tree.py`로 다시 만듦).

| 폴더 | 무엇이 있나 | 성격 | 언제 보나 |
|---|---|---|---|
| `nomad-design-modules/` (이 저장소 밖) | 별도 레포 [nomad-design-modules](https://github.com/DevOps0906/nomad-design-modules): 공통 디자인 가이드(`_design-guide/`)와 설득형 랜딩 템플릿. 로컬은 `D:/WorkSpace/DEV/nomad-design-modules` | 정본(별도 레포) | 디자인 기준을 볼 때. 9장 |
| [`reviews/`](reviews/) | 원본 프로젝트 25개의 코드 리뷰(완성도, 결함 심각도, 이식할 자산) | 근거(읽기 전용) | 기획이 왜 이렇게 됐는지 확인할 때 |
| `PDF_Collections/` (이 저장소 밖) | 별도 레포 [PDF_Collections](https://github.com/DevOps0906/PDF_Collections): 코드 리뷰 PDF 25개(제품별)와 북트레일러 문서 PDF 20개. 로컬은 `D:/WorkSpace/DEV/PDF_Collections` | 근거 사본(별도 레포) | 인쇄·공유. 9장 |
| [`products/`](products/README.md) | 통합 분석, 공용 코어, 디자인 가이드, 통합 DB, 제품 16개 기획서 | **정본** | 무엇을 만들지 볼 때 |
| [`Price_Plans/`](Price_Plans/README.md) | 공용 가격 결정 방법(`_common/`), 제품별 가격 플랜, 서비스 사업 Web-App-Agency | 분석·계획(요금 정본은 01_PRD 4장) | 가격을 정하거나 바꿀 때 |
| [`develop/`](develop/README.md) | 제품별 개발 안내서, setup 스크립트(`.sh`/`.ps1`), 개발 폴더에 붙일 묶음(`<제품>-root/`), 공용 설치 가이드(`_shared/`) | 묶음은 생성물(`build_root.py`) | 개발을 시작할 때 |
| [`develop_V2/`](develop_V2/README.md) | 공용모듈 7개를 쓰는 제품별 개발서, V2 공통 규칙, 생성 스크립트 | 생성물(`gen_v2.py`) | 공용모듈로 개발할 때 |
| [`Multi-tenant_Theming/`](Multi-tenant_Theming/README.md) | 화이트라벨 공용 설계: 커스터마이징 5단계(L0~L5), 디자인 토큰 3계층, 커스텀 도메인, 코어 확장 SQL `0011`(제안)과 RLS 스모크 | 공용 설계(제안) | 고객사 브랜드로 바꿔 팔 때 |
| [`Tauri/`](Tauri/README.md) | 데스크톱 앱 공용 가이드: 로컬 SQLite와 Supabase 정본 배치, 인증(시스템 브라우저 + PKCE), 결제·라이선스·업데이트, 제품별 적용, 작업 분해 | 공용 설계(초안) | Windows·macOS 앱으로 만들 때 |
| [`Capacitor/`](Capacitor/README.md) | 모바일 앱 공용 가이드: 기획 지시(스토어 정책, 결제 전략, 푸시 동의, 개인정보)와 개발 지시(설정, 플러그인, 인증, 푸시, 출시) | 공용 설계(초안) | iOS·Android 앱으로 만들 때 |
| [`_tools/`](_tools/README.md) | 리뷰 작성 템플릿, md → PDF 변환기 | 도구 | 원본 리뷰를 추가할 때 |

### 2.1 `products/` 안쪽

| 경로 | 내용 |
|---|---|
| [`00_MERGE_ANALYSIS.md`](products/00_MERGE_ANALYSIS.md) | 통합 전 기능 분석과 확정 결정 22개. 상단 결정 표가 본문보다 우선 |
| [`_platform-core/`](products/_platform-core/README.md) | 공용 코어 규격: `CORE_SPEC`, `SHARED_MODULES`, `SECURITY_BASELINE`, `DB_CONVENTIONS`, `DOC_TEMPLATE`(제품 문서 장 구조), `AI_ARCHITECTURE`, `VOICE_ARCHITECTURE`, `LLM_WIKI`, `AUTH_ROADMAP`(인증 단계), `COMMON_MODULES_ROADMAP`, `MONOLITH_CORE_LITE.sql`, `staged/`(승인 전 코어 SQL) |
| [`_platform-core/common-modules/`](products/_platform-core/common-modules/README.md) | 공용모듈 7개 기획(compliance, media, editorial, community, search, membership, ads)과 15개 제품 적용표 |
| ~~`_design-guide/`~~ → [`nomad-design-modules/_design-guide/`](https://github.com/DevOps0906/nomad-design-modules/blob/master/_design-guide/README.md) (2026-10-30 별도 레포로 이관, 9장) | 디자인 원칙·시스템, 3D 히어로 표준, 모션(GSAP)·블로그 스킨 표준(제안), 관리자 대시보드 구조 패턴(A~O)과 시각 아키타입(V-A~V-N, 필수 분석 절차), Awwwards·Dribbble 레퍼런스, 디자인 스킬, 설득형 랜딩·"왜 이 플랫폼인가" 검증 규칙(`LANDING_PERSUASION.md`, 2026-10-17)과 설득형 랜딩 템플릿(`templates/persuasion-landing/`, 공통 1개 + 제품 16개) |
| [`_supabase-modular/`](products/_supabase-modular/README.md) | 통합 DB: 코어 `0000~0009` + 제품 조각, seed, 검증 기록 |
| [`_tools-sqlcheck/`](products/_tools-sqlcheck/README.md) | PGlite로 SQL 적용을 검사하는 도구(`node check.mjs --vector ...`) |
| `<제품>/` | 제품 기획서(2.2절 표준 구성) |
| [`_PRODUCT_AGENT_BRIEF.md`](products/_PRODUCT_AGENT_BRIEF.md), [`_STRUCTURE_CHECK.md`](products/_STRUCTURE_CHECK.md) | 기획 에이전트 공통 지시, 구조 점검 기록 |

### 2.2 제품 기획서 표준 구성 (모든 제품 공통)

| 파일 | 내용 |
|---|---|
| `README.md` | 한 줄 정의, 통합 근거, 원본 매핑, 문서 목록, DB 구조 선택 |
| `01_PRD.md` | 페르소나, MVP·Phase 범위, 기능 요구사항과 수용 기준, **요금(4장, 정본)**, 법·개인정보, KPI, **열린 결정(8장)** |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 잡·워커, AI 라우팅, 리뷰 "높음" 결함의 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 사용자 플로우, 메인페이지(3D 히어로) 디자인 방향 |
| `04_API.md` | Route Handler, RPC, 잡 계약, 웹훅, 오류 코드 |
| `05_DATA_MODEL.md` | 테이블, RLS, 함수, 상태 전이, 모놀리스·모듈러 차이 |
| `06_AGENT_PLAN.md` | 작업 목록(작업 ID, 소유 경로, 의존성, 권장 모델, 수용 기준), 웨이브, 공용 모듈 요청 |
| `07_SOURCE_MIGRATION.md` | 원본에서 가져올 것·버릴 것, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 마이그레이션·seed·RLS 스모크 |

일부 제품은 추가 문서가 있습니다: sceneflow `08_AGENCY_OPERATIONS.md`(쇼츠 대행 운영), toon-factory `08_BENCHMARK.md`(경쟁 비교), local-news `modules/`(모듈 M1~M8)와 `research/`(디자인 벤치마크, 시장·법규), book-trailer `08_DESIGN_SYSTEM.md`(앱 토큰 층 + 영상 토큰 층).

### 2.3 `develop/_shared/` (모든 개발 묶음이 같이 쓰는 설치 가이드)

| 경로 | 내용 |
|---|---|
| [`auth/`](develop/_shared/auth/README.md) | 소셜 로그인 개발 지시서(Google·카카오·네이버), 공용 인증 패키지 `@nomad/core-auth` 구성, 제품별 적용 순서 |
| [`modules/`](develop/_shared/modules/README.md) | 공용모듈 7개 개발 지시서(패키지 저장소 `nomad-modules` 구성, 버전·출시 규칙) |
| [`dify/`](develop/_shared/dify/README.md), [`llm/`](develop/_shared/llm/README.md), [`voice/`](develop/_shared/voice/README.md) | 공용 Dify, LLM 키·오픈소스 LLM 서버·라우팅, 음성 서버 |
| [`tools/build_root.py`](develop/_shared/tools/build_root.py) | `products/`를 고친 뒤 `<제품>-root/` 묶음을 다시 만드는 스크립트 |

## 3. 제품 목록 (16개)

개발 순서는 `develop/README.md` "권장 개발 순서"를 따릅니다(0단계 = 공용 코어). 작업 수는 V1 개발 묶음 기준입니다.

| 제품 | 무엇을 하는 서비스인가 | 스키마(번호) | 개발 순서 | 작업 수 | 기획 · 개발 · 가격 |
|---|---|---|---|---|---|
| study-note (Study Note) | 수업·회의 원문을 AI 2개가 정리하고 하나의 학습 일지로 합침 | `notes`(2100) | 1 | 55 | [기획](products/study-note/) · [개발](develop/study-note/) · [가격](Price_Plans/study-note/PRICE_PLAN.md) |
| website-floria (Floria) | 식물 설치 브랜드 홈페이지 + 문의·뉴스레터 운영 콘솔 | `site`(2200) | 1 | 49 | [기획](products/website-floria/) · [개발](develop/website-floria/) · [가격](Price_Plans/website-floria/PRICE_PLAN.md) |
| flora-publishing (FLORA Publishing) | 1인 작가가 AI와 기획·집필·판형 조정을 거쳐 인쇄 PDF·ePub 완성 | `publishing`(1000) | 2 | 65 | [기획](products/flora-publishing/) · [개발](develop/flora-publishing/) · [가격](Price_Plans/flora-publishing/PRICE_PLAN.md) |
| astro-ai (신비로운AI) | 사주 원국 + 타로 3장 AI 해설을 A4 책자형 PDF 리포트로 | `astro`(1100) | 2 | 57 | [기획](products/astro-ai/) · [개발](develop/astro-ai/) · [가격](Price_Plans/astro-ai/PRICE_PLAN.md) |
| nomad-docs (NOMAD Docs) | 체크리스트 한 번으로 견적서·요구사항정의서·계약서 등 실무 문서 묶음 생성, CRM형 작업 공간 | `docs`(2300) | 2 이후 | 65 | [기획](products/nomad-docs/) · [개발](develop/nomad-docs/) · [가격](Price_Plans/nomad-docs/PRICE_PLAN.md) |
| sceneflow (SceneFlow) | AI 자동편집(주력)으로 스토리보드 하나에서 롱폼·장면 단위 쇼츠·언어판을 만들고 다채널 배포, 드라마·커머스 숏폼 재편집, 쇼츠 대행(음원·플리는 Phase 2) | `video`(1200) | 3 | 114 | [기획](products/sceneflow/) · [개발](develop/sceneflow/) · [가격](Price_Plans/sceneflow/PRICE_PLAN.md) |
| nomad-blog (NOMAD Blog) | 키워드 하나로 블로그 원고 + 제휴 카드 + 대가성 문구, 예약 발행 | `blog`(1300) | 3 | 59 | [기획](products/nomad-blog/) · [개발](develop/nomad-blog/) · [가격](Price_Plans/nomad-blog/PRICE_PLAN.md) |
| nomad-commerce (NOMAD Commerce) | 셀러용 상품 소싱·AI 상세페이지·마켓 업로드 | `commerce`(1400) | 3 | 60 | [기획](products/nomad-commerce/) · [개발](develop/nomad-commerce/) · [가격](Price_Plans/nomad-commerce/PRICE_PLAN.md) |
| microweb-studio (Microweb Studio) | 모바일 청첩장 등 마이크로웹 템플릿 엔진 + 대행 제작 쇼룸 | `microweb`(1500) | 4 | 56 | [기획](products/microweb-studio/) · [개발](develop/microweb-studio/) · [가격](Price_Plans/microweb-studio/PRICE_PLAN.md) |
| live-poll (Live Poll) | Slido형 실시간 투표·Q&A, 방송 오버레이 | `poll`(1800) | 4 | 51 | [기획](products/live-poll/) · [개발](develop/live-poll/) · [가격](Price_Plans/live-poll/PRICE_PLAN.md) |
| toon-factory (Toon Factory) | 이야기 → 콘티 → 캐릭터 모듈 조립 → 인스타툰·웹툰·9:16 영상 | `toon`(2000) | 4 | 69 | [기획](products/toon-factory/) · [개발](develop/toon-factory/) · [가격](Price_Plans/toon-factory/PRICE_PLAN.md) |
| admin-suite (Admin Suite) | ERP·병원(HMS)·학교(SMS) 내부 관리 3종, 사내 규정 AI 어시스턴트 | `erp`(1600), `sms`(1700), hms는 단독 | 5 | 60 | [기획](products/admin-suite/) · [개발](develop/admin-suite/) · [가격](Price_Plans/admin-suite/PRICE_PLAN.md) |
| stock-dashboard (Stock Dashboard) | 본인 증권 계좌(1차 모의투자) 대시보드 + AI 포트폴리오 진단, 초대제 | `stock`(1900) | 5 | 54 | [기획](products/stock-dashboard/) · [개발](develop/stock-dashboard/) · [가격](Price_Plans/stock-dashboard/PRICE_PLAN.md) |
| local-news (로컬뉴스 클라우드, 가칭) | 여러 지역신문사가 쓰는 멀티테넌트 뉴스룸 SaaS(화이트라벨), 공용모듈 7개의 출처 | `news`(2500) | 6 | 56 | [기획](products/local-news/) · [개발](develop/local-news/) · [가격](Price_Plans/local-news/PRICE_PLAN.md) |
| book-trailer (NOMAD Book Trailer, 가칭) | 원고 → 훅 브리프 3안 → 장르 문법 스토리보드 → 규격 4종 + 표지 루프 트레일러 렌더(Remotion) → 구매 링크 클릭 측정 | `trailer`(2600) | 4(대행 판매로 수요 검증 후) | 60 | [기획](products/book-trailer/) · [개발](develop/book-trailer/) · [가격](Price_Plans/book-trailer/PRICE_PLAN.md) |
| arch-studio (Arch Studio, 가칭) | 설치형 AI 건축 설계 앱(Windows, Tauri 2): 정보 입력 → 도면 자동 생성(DXF·SVG·PDF), 법규 엔벨로프 판정, AI 렌더, 제안서, 시리얼 라이선스 | `arch`(2400) | 공용 코어 다음 언제든(설치형, 도면 스파이크 먼저) | 66 | [기획](products/arch-studio/) · [개발](develop/arch-studio/) · 가격 플랜 없음(요금은 01_PRD 4장) |

모든 제품이 같은 공용 기반(로그인·조직, 크레딧·결제, 잡 워커, AI 계층, 음성)을 쓰고, 공개 랜딩이 있는 제품은 3D 히어로를 씁니다. 제품별 상세 설명은 [`develop/README.md`](develop/README.md), 공용모듈 채택 현황은 [`develop_V2/README.md`](develop_V2/README.md)에 있습니다.

## 4. 어느 문서가 정본인가

같은 내용이 여러 곳에 있을 때 아래 순서로 판단합니다.

| 주제 | 정본 | 사본·참고 | 규칙 |
|---|---|---|---|
| 큰 방향 | `products/00_MERGE_ANALYSIS.md` 상단 확정 결정 | 분석 본문, 제품 문서 | 확정 결정과 다른 범위는 제품 문서에 쓰지 않는다 |
| 공용 규격 | `products/_platform-core/` | 제품 문서의 인용 | 제품이 공용 규격을 재정의하지 않는다. 바꿀 것은 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적는다 |
| 제품 기능 | `products/<제품>/01~07` | `develop/<제품>/<제품>-root/docs/file/` | `-root`는 `build_root.py`가 만든 사본이다. 직접 고치지 않고 `products/`를 고친 뒤 다시 만든다 |
| 요금·크레딧 | 제품 `01_PRD.md` 4장 + seed | `Price_Plans/<제품>/PRICE_PLAN.md` | 가격 플랜에서 바꾸기로 정하면 01_PRD 4장과 seed를 함께 고친다 |
| DB | `products/_supabase-modular/migrations/<번호>_<스키마>.sql`(모듈러 조각) | 제품 `supabase/monolith/` | 모놀리스는 변환본이다 |
| 공용모듈 개발서 | `develop_V2/<제품>/` | - | `gen_v2.py`가 제품 06장을 읽어 만든다. 06장을 고치면 다시 실행한다 |
| 인증 | `products/_platform-core/AUTH_ROADMAP.md`(확정 결정 22) | `develop/_shared/auth/README.md`(개발 지시) | 전 제품 같은 단계: A Mock → G1 → B Google(+이메일·초대) → G2 → C1 카카오·C2 네이버 |
| 표기 | `products/_platform-core/DOC_TEMPLATE.md` 0장 | - | 근거 없는 수치·정책은 "제안", 확인하지 않은 외부 사실은 "미확인" |

## 5. 목적별 읽는 순서

| 목적 | 순서 |
|---|---|
| 저장소 전체 파악 | 이 문서 → [`products/README.md`](products/README.md)(인덱스와 진행 상태) → `00_MERGE_ANALYSIS.md` 확정 결정 표 |
| 제품 하나 이해 | 제품 `README.md` → `01_PRD.md`(대표님 결정은 8장 "열린 결정") → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md` |
| 가격 결정 | [`Price_Plans/_common/PRICING_PRINCIPLES.md`](Price_Plans/_common/PRICING_PRINCIPLES.md) → 제품 `PRICE_PLAN.md` → 제품 `01_PRD.md` 4장. 수익모델·사업성 검토는 [BM-CORE `method/BM_METHOD.md`](https://github.com/theBestTrade/BM-CORE/blob/master/method/BM_METHOD.md)(BM 7단계) |
| 개발 시작 | [`develop/README.md`](develop/README.md) → `develop/<제품>/<제품>_develop.md` → setup 스크립트(6장) |
| 공용모듈로 개발 | [`develop_V2/README.md`](develop_V2/README.md) → `develop_V2/_shared/V2_RULES.md` → 제품 V2 개발서 → [`develop/_shared/modules/`](develop/_shared/modules/README.md) |
| 로그인 구현 | `AUTH_ROADMAP.md` → [`develop/_shared/auth/README.md`](develop/_shared/auth/README.md) → 제품 개발서 19장 |
| 화이트라벨 판매 | [`Multi-tenant_Theming/README.md`](Multi-tenant_Theming/README.md) → `06_ADOPTION_PLAN.md` → `07_SALES_AND_OPERATIONS.md` |
| 데스크톱·모바일 앱 | [`Tauri/README.md`](Tauri/README.md) 2장(웹 SDK 사용 시 주의점) → 12장(제품별 적용), [`Capacitor/README.md`](Capacitor/README.md) 3장(기획 지시) → 5장(제품별 적용) |
| 디자인 작업 | [`nomad-design-modules/README.md`](https://github.com/DevOps0906/nomad-design-modules/blob/master/README.md) → `_design-guide/DESIGN_PRINCIPLES.md` → 제품 `03_SCREENS_UX.md` 4절 |
| 원본 리뷰 추가 | [`_tools/README.md`](_tools/README.md) → `REVIEW_TEMPLATE.md` → `PDF_GUIDE.md` |

## 6. 개발하는 방법 (모든 제품 공통)

개발은 이 저장소에서 하지 않습니다. 멀티에이전트 베이스 레포를 복사해 제품별 개발 폴더를 만들고, 이 저장소의 개발 묶음을 그 위에 붙인 뒤 그 폴더에서 Claude Code로 개발합니다.

```
D:\WorkSpace\platform\docs\develop\<제품>\          ← 이 저장소(안내서, 스크립트, 묶음)
        │  setup 스크립트: 베이스 복사 → 초기화 → 묶음 붙여넣기 → 에이전트 모델 지정 → 무결성 점검
        ▼
D:\WorkSpace\DEV\<제품>\                             ← 개발 폴더(여기서 claude 실행)
  ├── docs\file\    근거 산출물(기획서 01~07, 공용 코어, 디자인)  ← 개발의 정답
  ├── docs\wiki\    개발 위키
  ├── supabase\     로컬 DB 마이그레이션·seed·RLS 테스트
  ├── apps\web\  apps\api\                          ← 여기에 코드를 만든다
  ├── .claude\agents\  _shared\  _templates\        ← 베이스(오케스트레이터 규칙, 승인 게이트)
  └── tasks\        작업 1개 = task 폴더 1개
```

| 단계 | 할 일 | 상세 |
|---|---|---|
| 0 준비 | Git, jq, Python, Node 20, Docker, Supabase CLI, Claude Code. 베이스 레포 `MultiAgent-Service-Fullstack-Tree-Framwork`를 `D:\WorkSpace\DEV\`에 받기 | 개발 가이드 2장 |
| 1 설치 | setup 스크립트를 드라이런으로 확인 후 실행 | 개발 가이드 3~5장 |
| 2 프로필 | `_shared/project-profile.md`에 스택 버전·명령 채우기 | 개발 가이드 6장 |
| 3 로컬 DB | `supabase start` → `supabase db reset` → 타입 생성 → 확인 쿼리 | 개발 가이드 7장 |
| 4 결정 | 착수 전 결정 확정, 산출물 상태를 "승인"으로 | 개발 가이드 8장 |
| 5 작업 | `06_AGENT_PLAN.md`의 작업을 웨이브(W0부터) 순서로 task로 만들어 요청 프롬프트로 지시 | 개발 가이드 9장 |
| 6 반복 | 계획 공격 → 구현 → 리뷰 → 위키 갱신 → 완료, 웨이브가 끝나면 다음 웨이브 | 개발 가이드 10장 |
| 7 공용모듈(선택) | 채택한 공용모듈이 있으면 `develop_V2/<제품>/` 개발서의 바뀌는 작업·DB 순서를 따른다 | `develop_V2/_shared/V2_RULES.md` |

에이전트 구성: 주 Opus(claude-main), 리뷰 Sonnet(claude-reviewer), 계획 공격 Fable(plan-challenger), 구현 Sonnet(도메인 expert). 작업마다 `06_AGENT_PLAN.md` 2절 "수용 기준"이 완료 조건이고, P0 작업은 대응 테스트 작업이 통과해야 완료입니다. 구현이 기획과 달라지면 코드를 조용히 맞추지 말고 산출물을 고치는 task를 따로 만듭니다.

개발 묶음(`<제품>-root/`)에는 `products/`의 기획서·공용 코어·디자인 문서만 들어갑니다. `Price_Plans/`, `Multi-tenant_Theming/`, `Tauri/`, `Capacitor/`, 공용모듈 기획서는 묶음에 복사되지 않으므로 지시할 때 `D:/WorkSpace/platform/docs/...` 원본 경로를 적습니다.

### 6.1 예시: NOMAD Docs로 첫 작업까지

설치(PowerShell 또는 Git Bash):
```powershell
pwsh -File D:\WorkSpace\platform\docs\develop\nomad-docs\setup-nomad-docs.ps1 -DryRun   # 할 일만 출력
pwsh -File D:\WorkSpace\platform\docs\develop\nomad-docs\setup-nomad-docs.ps1          # 실제 실행
```
```bash
bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh --dry-run
bash /d/WorkSpace/platform/docs/develop/nomad-docs/setup-nomad-docs.sh
```
마지막에 `결과: PASS=17 FAIL=0`과 `== ALL PASS ==`가 나오면 `D:\WorkSpace\DEV\nomad-docs\`가 준비된 것입니다. 대상 폴더가 이미 있으면 스크립트는 덮어쓰지 않고 멈춥니다.

프로필과 에이전트: `_shared/project-profile.md`에 스택(Next.js 16.2.x, React 19.2, Tailwind CSS v4, shadcn/ui, FastAPI 0.115 + Python 3.12, Supabase 등, 값은 개발 가이드 6장 표)을 적고, 개발 폴더에서 `claude` → `/agent-check`로 에이전트를 확인합니다.

로컬 DB:
```bash
cd /d/WorkSpace/DEV/nomad-docs
supabase start
supabase db reset
mkdir -p apps/web/src/types
supabase gen types typescript --local --schema public > apps/web/src/types/supabase.ts
```

| 확인(Studio SQL 편집기) | 기대값 |
|---|---|
| `select count(*) from public.ai_routing_settings where org_id is null and app_id = 'docs'` | 13 |
| `select count(*) from public.doc_types where phase = 'mvp' and is_active` | 8(계약서 `dev_contract`는 법무 검토 전 비활성) |
| `select code, signup_credits, monthly_credits, is_active from public.plans where app_id = 'docs'` | free 50/30, pro 0/400, team 0/1500 비활성 |

RLS 권한 테스트 105개는 `supabase/tests/rls_smoke.sql`에 있습니다(실행법: 개발 가이드 7.3절). W0는 결정 없이 시작할 수 있고, 계약서 공개(D-3 법무 검토)와 요금(D-4 베타 원가 측정 후)은 해당 웨이브 전에 정합니다.

첫 task(W0의 DC-06-001):
```
tasks/DC-06-001-db-apply/
├── task.md      baseline(근거 산출물 ID), workers_approved, write_scope: supabase/**, apps/web/src/types/**
├── context.md
└── log.md       [APPROVAL], [DECISION] 기록
```

Claude Code에 보내는 요청(베이스 `_templates/dev-request-prompt.md` 형식):
```
D:/WorkSpace/DEV/nomad-docs/docs/file 의 모든 파일(프로젝트 산출물)을 최대한 자세히 읽고 분석한다.

[요구사항]
DC-06-001: supabase/migrations 의 core_lite 와 nomad_docs_domain, seed 를 로컬 Supabase 에 적용하고
타입을 생성한다(단독 프로젝트, public 스키마). 완료 조건 = ① supabase db reset 오류 0건
② ai_routing_settings 의 app_id='docs' 행 13건 ③ doc_types mvp 활성 8종(dev_contract 비활성)
④ supabase/tests/rls_smoke.sql 105항목 통과 ⑤ 타입을 apps/web/src/types/supabase.ts 에 저장
⑥ 06_AGENT_PLAN.md 의 DC-06-001 수용 기준 충족.

[작업의 특성]
DB만 진행. 원격 db push 금지. 작업 대상 경로: supabase/(tests/ 제외), apps/web/src/types/

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남긴다.

main worker 는 claude-main 이 진행한다.
main worker 의 서브 에이전트는 supabase-expert 가 진행한다.
review role worker 는 claude-reviewer 가 진행한다.
review role worker 의 서브 에이전트는 plan-challenger, review-expert 가 병렬 진행한다.
```

| 웨이브 | 작업(예) | 끝나면 생기는 것 |
|---|---|---|
| W0 | 001 DB, 004 web 골격, 005 워커 골격, 008 디자인 레퍼런스 | 로컬 DB, 빈 앱 골격 |
| W1 / W1-D | 002~020, 046 / 디자인 시스템 009 → 010(사람 검토) → 011 | 모놀리스 변환, RLS 러너, AI 서비스, 효과 엔진, 디자인 토큰 |
| W2~W4 | 인증·정본 API·결제 → 생성 그래프·문서 API·화면 1 → 패키지·내보내기·CRM 화면(061)·생성 애니메이션(062) | 체크리스트 → 문서 생성 → PDF |
| W5~W7 | 편집기·채팅 → 위키·KPI → 통합·E2E·AI 보안 회귀 | 공개 베타(MVP) |
| W8 | 연동(n8n, HubSpot, ERP), 숏폼 대행 패키지 | Phase 2 |

## 7. 규칙

| 규칙 | 내용 |
|---|---|
| 공용 폴더 보호 | `_platform-core/`, `_supabase-modular/`(디자인 기준은 별도 레포 `nomad-design-modules`)는 제품 작업에서 고치지 않고 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적는다 |
| 생성물 직접 수정 금지 | `develop/<제품>/<제품>-root/`(`build_root.py`), `develop_V2/<제품>/`(`gen_v2.py`)는 원본을 고친 뒤 스크립트로 다시 만든다 |
| DB | 정본은 모듈러 조각이고 제품 모놀리스는 변환본이다. 원격 DB 적용(`supabase db push`)은 사람이 확인 후 실행한다. SQL은 `products/_tools-sqlcheck`로 적용 검사를 통과해야 한다 |
| 스택 | Tailwind CSS v4 고정(v3 문법·`tailwind.config.js` 금지). 의존성 버전 고정, `latest` 금지 |
| 로그인 | 전 제품 같은 단계(A Mock → G1 → B Google → G2 → C1 카카오·C2 네이버). 쿠키에 역할을 적는 Mock 금지. 정본 [`AUTH_ROADMAP.md`](products/_platform-core/AUTH_ROADMAP.md) |
| 비밀 | `service_role`, LLM·결제 키는 서버 전용. 사용자 API 키(BYOK)는 만들지 않는다(`SECURITY_BASELINE.md` 5장) |
| 표기 | 한국어, Markdown 표만(HTML·이모지 금지), 근거는 `상대경로:줄번호`, 근거 없는 수치·정책은 "제안", 확인하지 않은 외부 사실은 "미확인" |
| 변경 절차 | 이 저장소 변경은 브랜치 → PR → main 병합으로 한다 |

## 8. 현재 상태와 남은 일 (2026-10-16)

| 영역 | 상태 |
|---|---|
| 기획 | 16개 제품 완료(01~07, CLAUDE.md, SQL. book-trailer는 08_DESIGN_SYSTEM 추가, arch-studio는 2026-10-16 완료). 인증 단계(확정 결정 22) 반영. 검증 기록: `products/_supabase-modular/VERIFICATION.md`, `products/_STRUCTURE_CHECK.md` |
| 통합 DB | 코어 `0000~0009` + 제품 조각 17개(`1000~2300`, `2400_arch`, `2500_news`, `2600_trailer`). PGlite 기준 적용 검증 완료, 실제 Supabase 재검증은 남음 |
| 개발 묶음 | 16개 제품(작업 1,011개, 2026-10-18 sceneflow AI 자동편집 30개·스토리보드 트랙 19개 추가, book-trailer 2026-10-15·arch-studio 2026-10-16 추가, 2026-10-17 설득형 랜딩 15개 추가: flora-publishing·nomad-docs·arch-studio 각 5개), 공용모듈 V2 개발서 16개 |
| 공용모듈 | 7개 기획·개발 지시서 완료(상태: 제안). 패키지 저장소 `nomad-modules`는 아직 없음 |
| 가격 | 제품 15개 + Web-App-Agency 초안(정본은 각 PRD 4장) |
| 화이트라벨 | `Multi-tenant_Theming/` 설계 완료, 코어 확장 SQL `0011`은 제안(PGlite 적용·RLS 스모크 91/91 통과). 코어 반영은 승인 후 |
| 데스크톱·모바일 | `Tauri/`, `Capacitor/` 공용 가이드 초안. 코어 요청 T-C1~T-C8, M-C1~M-C4 미반영 |

### 8.1 저장소 점검에서 확인한 빈 곳

| # | 빈 곳 | 영향 | 다음 할 일 |
|---|---|---|---|
| 1 | arch-studio에 `Price_Plans/arch-studio/`가 없다(기획 01~07·SQL·개발 묶음은 2026-10-16 완료) | 가격 분석 근거 없음 | 가격 플랜 작성. 개발은 2일 도면 스파이크(AR-06-019)부터 |
| 2 | 승인 전 코어 SQL 2개: `products/_platform-core/staged/0010_core_auth_identity_links.sql`(네이버 브리지용), `Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql` | local-news 등 의존 제품 착수 지연 | 각각 C2 스파이크 결과, `06_ADOPTION_PLAN.md` 승인으로 결정 |
| 3 | 코어 요청 미반영: 일회성 상품 결제(설치형 판매), 셸 앱 Bearer 세션·CORS, 푸시 채널, `adjust_credits` 등(`products/README.md` "남은 코어 과제") | 설치형·앱·일부 크레딧 기능 착수 불가 | 코어 요청을 한 PR로 모아 처리 |
| 4 | 판매 모델 A(설치형) 정의가 "고객 API 키"를 전제하지만 `SECURITY_BASELINE.md`는 BYOK를 금지한다(`Price_Plans/_common/PRICING_PRINCIPLES.md` A행, Tauri 가이드 T-C5) | 설치형 제품 설계 기준 불명확 | 둘 중 하나를 고친다(arch-studio는 크레딧 게이트웨이 방식) |
| 5 | 개발 묶음에 `Price_Plans/`, `Multi-tenant_Theming/`, `Tauri/`, `Capacitor/`, 공용모듈 기획서가 들어가지 않는다 | 에이전트가 원본 경로를 따로 지시받아야 함 | 필요하면 `build_root.py`의 참조 목록에 추가 |

남은 결정은 각 제품 `01_PRD.md` 8장, 공용 과제는 [`products/README.md`](products/README.md) "남은 코어 과제"에 있습니다.

### 8.2 2026-10-17 설득형 랜딩 (검토용)

| 항목 | 내용 |
|---|---|
| 공용 규칙 | [`nomad-design-modules/_design-guide/LANDING_PERSUASION.md`](https://github.com/DevOps0906/nomad-design-modules/blob/master/_design-guide/LANDING_PERSUASION.md): 외부 자료 사용 원칙(구조만 쓰고 다른 회사의 문구·수치·비주얼은 쓰지 않음), "왜 이 플랫폼이어야 하는가" 판정표·증거 등급·주장 장부, 필요성 검증 단계(V0 인터뷰·칸 유무 교대 실험 → V1 과업 측정 → V2 실측 → V3 사례) |
| 적용 제품 | flora-publishing(01장 9장, 03장 9절, 06장 10절), nomad-docs(01장 9장, 03장 8장, 06장 9절), arch-studio(01장 10장, 03장 7장, 06장 8장). 각 제품 작업 5개 추가(합계 962개) |
| 서비스 상품 | Web-App-Agency 설득형 랜딩 패키지 AG-PL(`Price_Plans/Web-App-Agency/02_SERVICE_CATALOG.md` 6장, `PRICE_PLAN.md` 11장) |
| 문서 방식 | 기존 장의 줄 번호를 다른 문서가 인용하므로 각 문서 끝에 추가 장을 붙였다(같은 줄 안의 수정만 예외) |
| 랜딩 템플릿 | [`nomad-design-modules/_design-guide/templates/persuasion-landing/`](https://github.com/DevOps0906/nomad-design-modules/blob/master/_design-guide/templates/persuasion-landing/README.md): 공통 템플릿 1개(`data/_common.json`, 기본 "구매 여정")와 제품별 템플릿 16개(`data/<제품>.json` → `dist/<제품>.html`). 제품마다 개발 요건에 맞춘 "(제품) ○○ 여정"(5~7단계, 22~24페이지), Whisper 음성 지시 페이지, 경쟁사 강점·약점(내부 검토용) 포함. 만드는 법: `node validate.js` → `python3 build.py <제품>` |
| 템플릿 테마 | 불투명한 면과 한글 서체(Noto Sans KR)를 쓰는 어두운 단일 테마. 반투명 유리 카드·배경 흐림·영문 디스플레이 서체·빛이 훑는 효과는 쓰지 않는다. 제품마다 강조색만 다르다 |
| 남은 결정 | flora-publishing D28~D32, nomad-docs D-23~D-27, arch-studio D-27~D-30, Web-App-Agency AG-D-13·14. V0 인터뷰는 개발 전에 대표님이 진행 |

### 8.3 2026-10-18 영상 제품 이름 변경

| 항목 | 내용 |
|---|---|
| 이름 | NOMAD AI Factory → **SceneFlow**(같은 날 ShortsFlow를 거쳐 확정. 스토리보드로 숏폼·롱폼을 만드는 방향에 맞춰 "장면" 중심 이름으로). NOMAD AI Factory는 회사 브랜드(디지털노마드연구소, 문의 메일, 저작권 표기)로만 쓴다 |
| 폴더 | `nomad-video` → `sceneflow`: `products/sceneflow/`, `develop/sceneflow/`(`sceneflow_develop.md`, `setup-sceneflow.sh`·`.ps1`, `sceneflow-root/`), `develop_V2/sceneflow/`, `Price_Plans/sceneflow/`, 랜딩 템플릿 `data/sceneflow.json`·`dist/sceneflow.html` |
| 그대로 둔 것 | DB 스키마 `video`와 앱 ID `video`, 기능·작업 ID 접두어(VD-F, VD-06), SQL 파일 이름(`1200_video.sql`, `0002_video_domain.sql`). 제품 이름이 아니라 도메인 이름이라 바꾸면 DB·코어 규격까지 바뀐다. 원본 코드 리뷰(`reviews/`, `pdf/`)는 원본 프로젝트 이름 그대로 |
| 실제 개발 폴더 | `D:\WorkSpace\DEV\sceneflow\` (setup 스크립트 기본값) |

### 8.4 2026-10-18 SceneFlow 스토리보드 디벨롭 (검토용)

| 항목 | 내용 |
|---|---|
| 핵심 | 스토리보드 하나로 롱폼 1편 + 장면 단위 쇼츠 여러 편 + 언어판(KO/JA/EN). 첫 고객은 지식·역사 채널 운영자 |
| 확정 결정(사용자) | SF-1 Track C Mode1·D → **Track S** 통합(C Mode2는 A로), SF-2 MVP 렌더는 FFmpeg(Remotion은 Phase 2), SF-3 Track E·F(Lofi·플리) Phase 2, SF-4 첫 고객 지식·역사 채널 |
| 기획서 | `products/sceneflow/` 01장 10장(VD-F-130~142, 크레딧, 법·고지, D-30~D-37), 02장 10장(렌더 구조), 03장 8장(편집기 화면), 04장 9장(API·잡·오류 VD017~021·VD409), 05장 11장(테이블 6개), 06장 9장(작업 19개 VID-06-066~084), CLAUDE.md·README 끝 절, 08장 9장(롱폼 대행 패키지) |
| DB | `1200_video.sql` 12절·모놀리스 `0002` 끝 절: storyboards, scenes, scene_assets, storyboard_cuts, storyboard_snapshots, storyboard_templates. PGlite 적용·행동 검사 통과 |
| 가격·검증 | `Price_Plans/sceneflow/PRICE_PLAN.md` 11장(이익률 검증: 기본 단가로는 70% 미달 → D-31·D-36·D-37 함께 결정), 검증 키트 `01_VALIDATION_PLAN.md`~`04_INTAKE_AND_INTERVIEW.md` |
| 랜딩 | `templates/persuasion-landing/data/sceneflow.json` "SceneFlow 스토리보드 여정"(6단계 24페이지) |

### 8.5 2026-10-18 SceneFlow AI 자동편집·화면비·해상도 (검토용)

| 항목 | 내용 |
|---|---|
| 핵심 | **SceneFlow의 주력 기능은 AI 자동편집(확정 SF-5).** 한국어 텍스트·음성 지시 → AI 편집안(허용 명령 17종 EDL) → 장면별 전·후 비교와 예상 크레딧 → 일부·전체 승인 → 한 트랜잭션 실행 → 되돌리기 |
| 벤치마킹 | Descript(Underlord), CapCut, Opus Clip, Vrew, VEED, FireCut, Submagic, Wisecut, Kapwing, invideo AI, Premiere, DaVinci 등. 출처는 01장 11.10절 |
| 확정 결정(사용자) | SF-5 주력 기능 AI 자동편집, SF-6 AI는 편집 명령 목록만 만든다, SF-7 승인 전 변경 0·실행 전 비용 표시, SF-8 화면비와 형식 분리(16:9·9:16·1:1·4:5, 720p~4K, 24/30/60fps) |
| 기획서 | `products/sceneflow/` 01장 11장(VD-F-143~159, D-38~D-44), 02장 11장(편집 엔진·렌더 변경), 03장 9장(AI 편집 화면), 04장 10장(API·오류 VD022·VD023), 05장 12장(데이터), 06장 10장(작업 30개 VID-06-085~114), CLAUDE.md·README 끝 절 |
| DB | `1200_video.sql` 13절·모놀리스 `0002` 끝 절: edit_plans, edit_presets, pronunciation_lexicon, clip_transcripts, RPC apply/undo/reject_edit_plan. PGlite 적용, 행동 검사 기존 56 + 신규 62 통과(모듈러·모놀리스) |
| 가격 | `Price_Plans/sceneflow/PRICE_PLAN.md` 12장: 편집 LLM을 저가 모델로 두지 않으면 70% 미달, 2160p 배수 2배로는 렌더 원가를 덮지 못함 → SF-P-7~10 제안(D-38·D-39·D-41) |
| 대시보드 시안 | Design 캔버스 "SceneFlow AI 자동편집 대시보드"(A안 문서 토큰, B안 랜딩 엔진 테마, 둘 다 실제 동작) |


## 9. 디자인 요소는 별도 레포를 참고한다 (2026-10-30)

공통 디자인 요소는 이 저장소에서 분리해 **[nomad-design-modules](https://github.com/DevOps0906/nomad-design-modules)** 레포 하나에서만 관리합니다. 이 저장소에는 디자인 폴더(`products/_design-guide/`, `design-module/`)가 없습니다. 서브모듈도 쓰지 않습니다.

### 9.1 참고하는 방법

| 하고 싶은 일 | 방법 |
|---|---|
| 디자인 기준 읽기 | GitHub에서 읽는다: [`_design-guide/README.md`](https://github.com/DevOps0906/nomad-design-modules/blob/master/_design-guide/README.md) |
| 로컬에서 읽기 | `D:\WorkSpace\DEV\` 아래에 클론: `git clone https://github.com/DevOps0906/nomad-design-modules.git` → `D:\WorkSpace\DEV\nomad-design-modules\_design-guide\` |
| 최신으로 맞추기 | `git -C D:/WorkSpace/DEV/nomad-design-modules pull` |
| 문서에서 인용 | `nomad-design-modules/_design-guide/<파일>`. 이 저장소 문서의 `nomad-design-modules/...` 경로는 모두 그 레포 안의 경로다. 개발 묶음 안에서는 `_design-guide/<파일>` |
| 디자인 문서 수정 | 이 저장소가 아니라 `nomad-design-modules`에서 수정·커밋·푸시한다. 제품별 결정(레퍼런스 선택, 토큰 값, 화면)만 `products/<제품>/03_SCREENS_UX.md`에 적는다 |
| 개발 묶음 재생성 | `develop/_shared/tools/build_root.py`가 `DESIGN_REPO`(`D:/WorkSpace/DEV/nomad-design-modules`)에서 디자인 문서를 읽는다. 그 클론이 없으면 먼저 받는다. `develop/*/*-root/`의 `디자인/` 사본은 다음 재생성 때 갱신된다 |

레포에 있는 것: 디자인 시스템·원칙, 3D 히어로, 모션(GSAP, 제안), 네이버 블로그 스킨(제안), 레퍼런스, 대시보드 패턴, 설득형 랜딩 규칙과 템플릿.

이관하지 않은 디자인 관련 파일: `Multi-tenant_Theming/`(SQL·테스트가 `products/` 상대 경로를 읽음), `products/book-trailer/08_DESIGN_SYSTEM.md`, `products/local-news/research/DESIGN_BENCHMARK.md`(제품 문서 체계에 속함).

### 9.2 연관 레포

| 레포 | 역할 | 이 저장소와의 관계 |
|---|---|---|
| [nomad-design-modules](https://github.com/DevOps0906/nomad-design-modules) | 공통 디자인 가이드·템플릿 | 디자인 기준의 정본. 제품 문서가 경로로 인용 |
| [nomad-agent-os](https://github.com/DevOps0906/nomad-agent-os) | Claude Code AI 개발팀 설정(에이전트, 도구) | 제품 개발 폴더에서 기획·구현·디자인 에이전트를 돌릴 때 사용. BM 7단계는 `/bm <제품>`(계산은 `bm-calc`, 결과는 [BM-CORE](https://github.com/theBestTrade/BM-CORE)) |
| [nomad-blueprints-module](https://github.com/DevOps0906/nomad-blueprints-module) | 도메인별 기획 표 묶음 | 화면·API·데이터 기획 표를 가져올 때 |
| [nomad-docker-module](https://github.com/DevOps0906/nomad-docker-module) | 자체 호스팅 서비스 컨테이너 실행 템플릿 | 로컬·단일 서버 실행 시 |
| [nomad-secure-pack-module](https://github.com/DevOps0906/nomad-secure-pack-module) | 납품·규제용 보안 L3 | 공공·금융·대기업 납품, EU 판매 시 |
| [SceneFlow](https://github.com/DevOps0906/SceneFlow) | AI 자동편집 영상 SaaS | `products/sceneflow/`의 개발 레포 |
| [Arch-Studio](https://github.com/DevOps0906/Arch-Studio) | 건축 설계실무 도구 | `products/arch-studio/`의 개발 레포 |
| [nomad-classroom](https://github.com/DevOps0906/nomad-classroom) | 오프라인·하이브리드 교육 강의실 SaaS 기획 | 이 저장소 16개 제품에는 없는 별도 기획 레포 |
| [replica-collect-system](https://github.com/DevOps0906/replica-collect-system) | 서비스 분석·재구현 수집 시스템 | 레퍼런스 서비스 분석 시 |
| [PDF_Collections](https://github.com/DevOps0906/PDF_Collections) | 이 저장소 문서의 PDF 사본(코드 리뷰 25개, 북트레일러 20개) | `reviews/`와 제품 문서의 PDF 사본. 변환 도구(`_tools/md2pdf.py`, `book_trailer_pdf.py`)는 이 저장소에 있고 결과만 그 레포에 보관 |

위 표의 역할은 각 레포 README 첫머리를 근거로 적었습니다. 모듈 레포(blueprints·docker·secure-pack)의 설치는 각 README의 `nomad-os module add` 안내를 따릅니다.

## 10. BM과 사업계획서 자료는 BM-CORE 레포로 이동 (2026-11-11)

사업모델(BM) 7단계 방법론, 비즈니스 모델 캔버스, 사업계획서(PSST) 매핑, BM-Core SaaS 기획서는 **[theBestTrade/BM-CORE](https://github.com/theBestTrade/BM-CORE)** 레포에서 관리합니다. 이 저장소는 "무엇을 만드는가"(제품 기획), BM-CORE는 "왜 돈이 되는가"(고객·가격·단위경제·검증·점수)와 사업계획서 재료를 맡습니다.

| 옮긴 것 | BM-CORE 위치 |
|---|---|
| `Price_Plans/_common/BM_METHOD.md` | [`method/BM_METHOD.md`](https://github.com/theBestTrade/BM-CORE/blob/master/method/BM_METHOD.md) |
| `products/bm-core/`(README, 01~09, CLAUDE.md) | [`product/`](https://github.com/theBestTrade/BM-CORE/tree/master/product) |
| `products/bm-core/research/00_SOURCE_DESIGN.md` | [`research/`](https://github.com/theBestTrade/BM-CORE/tree/master/research) |

제품별 BM 결과는 BM-CORE `projects/<제품>/`에 둡니다. 가격 플랜(`Price_Plans/<제품>/PRICE_PLAN.md`)은 계속 이 저장소에 있습니다.

## 11. GitHub 레포 지도 (2026-11-11)

[DevOps0906](https://github.com/DevOps0906)·[theBestTrade](https://github.com/theBestTrade) 두 계정의 레포 143개(직접 만든 89개, 포크 54개)를 이 저장소 문서와 연결한 지도는 [`REPOSITORIES.md`](REPOSITORIES.md)에 있습니다.

| 어디에 | 무엇을 적었나 |
|---|---|
| `reviews/<원본>.md` 첫 줄 | 원본 레포 주소(로컬 원본 폴더의 `git remote origin` 근거). 찾을 수 없는 레포는 이름만 |
| `reviews/README.md` 표 | 원본 프로젝트 칸에 레포 주소 |
| `products/<제품>/README.md` 첫 줄 | 원본 레포 또는 개발 레포(sceneflow, arch-studio) |

다른 문서가 `파일:줄`로 인용하므로 줄을 추가하지 않고 첫 줄 끝에 붙였습니다. `develop/*/*-root/`의 사본은 `build_root.py`로 다시 만들 때 반영됩니다.
