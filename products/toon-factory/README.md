# Toon Factory (toon-factory)

작성일 2026-10-12. 단계 2 제품 기획 산출물이다. 구조는 `docs/products/_platform-core/DOC_TEMPLATE.md` 2.1절을 따른다.

## 1. 한 줄 정의

이야기를 넣으면 AI가 회차 콘티(컷 구성, 대사)를 짜고, 미리 만든 캐릭터 모듈(포즈와 표정)로 컷을 조립하며, 배경은 AI로 생성해 인스타툰 PNG/ZIP, 세로 스크롤 웹툰 이미지, 9:16 MP4로 내보내는 AI 웹툰 제작 도구다.

| 항목 | 내용 |
|---|---|
| 대상 사용자 | 그림 실력보다 이야기를 가진 인스타툰·웹툰 지망 작가, SNS 마케터, 지식 크리에이터, 1인 창업자(`Toon-Factory/PRD.md:13`, `docs/reviews/Toon-Factory.md:10`) |
| 핵심 차별점 | AI 이미지의 약점인 캐릭터 일관성을 "생성"이 아니라 "조립"으로 해결한다(`Toon-Factory/PRD.md:15-17`). AI는 캐릭터를 그리지 않고 콘티, 대사, 배경만 맡는다(MVP) |
| AI 요약(2026-10-13) | 작품 설정 위키(캐릭터 바이블)와 설정 RAG, 콘티 그래프 `toon.storyboard`(줄거리 → 컷 분할 → 캐릭터 일관성 검사 → 이미지 프롬프트 → compliance), 창작 어시스턴트 채팅(Dify `toon-chat`), 음성 대화·대사 음성 미리듣기·MP4 음성 입히기, 3D 히어로가 MVP에 들어간다(확정 결정 13~17). AI 생성 표시와 이미지 생성 저작권 규칙은 그대로 유지한다 |
| 앱 ID / 스키마 | `toon` / 모듈러 `toon`, 모놀리스 `public` |
| SQLSTATE / 작업 ID 접두사 | `TN` (`docs/products/_platform-core/DB_CONVENTIONS.md:22`) |

## 2. 통합 근거

단독 제품이다. 합친 원본이 없다(`docs/products/README.md:22`). 분석은 이 프로젝트를 "기획만" 상태로 분류했고(`docs/products/00_MERGE_ANALYSIS.md:1292`), 원본 기획 완성도는 약 20%다(`docs/reviews/Toon-Factory.md:21`). 그래서 이 폴더의 문서는 원본을 옮기는 것보다 빈 기획을 채우는 비중이 크다.

| 근거 | 내용 |
|---|---|
| 확정 결정 4 | 결제는 Toss Payments(`docs/products/00_MERGE_ANALYSIS.md:12`) |
| 확정 결정 5 | org 기준 스키마, 운영은 1인 1워크스페이스(`:13`) |
| 확정 결정 8 | 플랜 정본은 제품 01_PRD. 이 제품은 모듈러 seed의 샘플(Pro 14,900원, 월 300크레딧, `docs/products/_supabase-modular/seed.sql:108-111`)을 그대로 쓰고 features 키만 확장한다(01_PRD 4절) |
| 그룹 연결 | 숏폼 내보내기는 NOMAD Shorts Maker의 FFmpeg 모듈(`ken-burns.ts`, `layer-composite.ts`, `watermark.ts`)과 이어진다(`docs/products/00_MERGE_ANALYSIS.md:1309`). MVP는 이 코드를 제품 워커로 이식하고, video의 미디어 워커와 공유할지는 01_PRD 8절 열린 결정이다 |
| 출발점 골격 | 리뷰는 Nomad-BlogStudio 골격을 권했고(`docs/reviews/Toon-Factory.md:86`), 플랫폼 공통 코어(`_platform-core`)가 인증, 조직, 크레딧, 결제를 대신한다(`docs/products/00_MERGE_ANALYSIS.md:1342`) |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `Toon-Factory/` (PRD.md, Design.md, Claude.md 3개, 코드 없음) | `docs/reviews/Toon-Factory.md` | 약 20%(`:21`) | 제품 비전과 대상(`PRD.md:7-17`), 모듈형 캔버스와 에셋 라이브러리 개념(`PRD.md:21-23`), 숏폼 변환(`PRD.md:25`), 3단 에디터 레이아웃(`Design.md:29`), Zustand 문서 모델 원칙(`Claude.md:15-19`) | FFmpeg.wasm 브라우저 렌더, LoRA 화풍 통일, 자동 누끼, B2B 마스코트, GEO(07장 3절) |
| `NOMAD Shorts Maker/src/lib/media/` (참고 자산) | `docs/reviews/NOMAD_Shorts_Maker.md` | 리뷰 참조 | `ken-burns.ts`, `layer-composite.ts`, `watermark.ts`의 FFmpeg 인자 구성 | BullMQ 파이프라인 연결부(미연결 상태, `docs/reviews/Toon-Factory.md:87`) |
| `Nomad-BlogStudio/` (골격 참고) | `docs/reviews/Nomad-BlogStudio.md` | 리뷰 참조 | Next 16 + Supabase SSR 디렉토리 구성, shadcn ui | `supabase/migrations/*`(RLS 결함, `docs/reviews/Toon-Factory.md:86`) |
| `sellingstudio/lib/image/fal.ts` (공용 fal 기준 구현) | `docs/reviews/sellingstudio.md` | 리뷰 참조 | `_platform-core` fal client를 통해서만 사용(`docs/products/_platform-core/SHARED_MODULES.md:228-249`) | `enable_safety_checker: false`(`sellingstudio/lib/image/fal.ts:24`) |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구사항과 수용 기준, 플랜과 크레딧 단가, 비기능 수치, 저작권·AI 생성 표시·플랫폼 제출 규칙, KPI, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계, 공용 모듈 사용, 잡과 워커, AI 라우팅 기본값 14행과 그래프 3개, 리뷰 #5·#6 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 핵심 플로우(AI 채팅·음성·설정 위키 포함), 화면별 명세, 디자인 시스템(Atlassian 주 레퍼런스), 랜딩 디자인 방향(3D 히어로), 상태·오류, 접근성 |
| `04_API.md` | Route Handler(AI·음성 포함), 제품 RPC, 잡 페이로드, 웹훅, 외부 API(FastAPI, Dify 계약), 오류 코드 |
| `05_DATA_MODEL.md` | 테이블, 상태 전이, RLS, 인덱스, 코어 참조(AI·음성은 코어 표만, 제품 AI 표 없음), 리뷰 #1~#4 차단 설계, 모놀리스/모듈러 차이 |
| `06_AGENT_PLAN.md` | 작업 66개(AI·음성·3D·디자인 시스템 19개, 2026-10-13 2차 보강 7개 포함), 소유 경계, 웨이브, 모델 비율, 리뷰 작업 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본 자산 분류, 이식 시 수정점, 폐기 목록, 복사 금지 결함 |
| `08_BENCHMARK.md` | 경쟁 AI 웹툰·숏툰 도구 비교표(12항목, 출처 포함), 격차 → 보강안 매핑, 분기별 반복 벤치마킹 방법(점검표, 점수 기준) |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/migrations/0001_core_lite.sql` | `_platform-core/MONOLITH_CORE_LITE.sql` 복사본. 6-A, 6-B, 9절 제거 |
| `supabase/monolith/migrations/0002_toon_domain.sql` | 도메인 테이블(모듈러 조각에서 변환) |
| `supabase/monolith/seed.sql` | apps, 플랜 2개(AI 키 포함), 크레딧팩 2개, 샘플 카탈로그 팩, AI 라우팅 기본값 14행 |
| `docs/products/_supabase-modular/migrations/2000_toon.sql` | 모듈러 조각(정본, 10절에 AI·음성 기본값, 11절에 내보내기 프리셋·브랜디드 툰) |

## 5. DB 구조 선택

기본값은 모듈러다. 이유는 (1) 크레딧과 결제를 다른 제품과 같은 원장·지갑으로 쓰면 크로스셀(예: video 사용자가 툰 숏폼을 만드는 경우)이 쉽고(`docs/products/_supabase-modular/ARCHITECTURE.md:74`), (2) 의료정보 같은 격리 요구가 없으며, (3) 숏폼 렌더를 video와 공유할 가능성이 있기 때문이다. 모놀리스는 단독 판매나 별도 법인 운영이 필요할 때를 위해 같은 도메인 모델로 함께 둔다(`ARCHITECTURE.md:75`). 두 파일은 같은 조각에서 변환하며(05장 9절), PGlite 체커와 RLS 스모크 테스트(68항목)를 두 구조 모두 통과했다(05장 4절).

## 6. 변경 이력

| 날짜 | 변경 | 근거 |
|---|---|---|
| 2026-10-13 | 2차 개정(확정 결정 20): 경쟁 도구 벤치마킹 문서 `08_BENCHMARK.md` 추가. 로그라인·시놉시스 생성(TN-F-024), 플랫폼 내보내기 프리셋(TN-F-038), 브랜디드 툰(TN-F-070~073)을 MVP에, SNS 직접 업로드(TN-F-080, 네이버 클립 포함)와 숏툰 모션(TN-F-081)을 Phase 2에 넣었다. SQL `2000_toon.sql` 11절(프리셋, `sponsorships`)과 모놀리스 변환본 갱신 | `08_BENCHMARK.md`, 01장 2절 |
