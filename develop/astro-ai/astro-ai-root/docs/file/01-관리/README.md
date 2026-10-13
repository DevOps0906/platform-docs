# 신비로운AI (astro-ai)

## 1. 한 줄 정의

만세력 엔진이 결정적으로 계산한 사주 원국과 사용자가 뽑은 타로 3장을 AI가 해설해, 본인과 가족·지인의 리포트를 A4 책자형 PDF로 소장하게 하고 이메일과 대시보드로 전달하는 크레딧팩 결제형 SaaS다. 2026-10-13부터 AI 채팅(내 사주 질문, 용어 설명), 음성 대화, 리딩 낭독, 사주 용어 위키, 3D 히어로가 MVP에 들어간다(확정 결정 13~17).

| 항목 | 내용 |
|---|---|
| 대상 사용자 | 자기 이해나 가족 선물용으로 사주·타로 리포트를 소장하려는 20~40대(`Astro AI/기획안/공통/PRD.md:21`, `FortuneDocs/PRD.MD:15`, `docs/file/03-설계/디자인/REFERENCES.md:61`) |
| MVP | 사주 + 타로 + 통합 리딩, 크레딧팩 일회 결제(확정 결정 7, `docs/reference/00_MERGE_ANALYSIS.md:16`) |
| 플랜 정본 | Astro AI 단가표(확정 결정 8, `docs/reference/00_MERGE_ANALYSIS.md:17`, `Astro AI/기획안/공통/PRD.md:29-58`) |
| 서비스명 | 신비로운AI, 폴더 `astro-ai`(확정 결정 10, `docs/reference/00_MERGE_ANALYSIS.md:19`) |

## 2. 통합 근거

| 근거 | 내용 |
|---|---|
| 같은 시장, 둘 다 코드 없음 | 두 원본 모두 기획 문서만 있다(`docs/reference/reviews/Astro_AI.md:3`, `docs/reference/reviews/FortuneDocs.md:3`). 같은 고객에게 같은 결과물(사주 PDF)을 판다(`docs/reference/reviews/Astro_AI.md:97`) |
| 베이스 = Astro AI 기획 세트 | 요금표, 크레딧 단가, 대시보드 19개 화면, 랜딩 11섹션, 결제·발송·금지사항 등 플랫폼 골격이 정의된 쪽이다(`docs/reference/00_MERGE_ANALYSIS.md:293`). 완성도 55%(`docs/reference/reviews/Astro_AI.md:20`) |
| FortuneDocs에서 가져오는 것 | 정확도의 근간인 입력 모델(성별, 음양력, 윤달, 야자시/조자시), 다중 프로필 보관함, 대운 타임라인, 원국 프리뷰, "평생 사주를 책 한 권으로 소장" 포지셔닝(`docs/reference/00_MERGE_ANALYSIS.md:299-304`). 완성도 40%(`docs/reference/reviews/FortuneDocs.md:21`) |
| 백엔드 | Next.js + FastAPI, WeasyPrint 렌더 서비스는 flora-publishing과 공용(확정 결정 3, `docs/reference/00_MERGE_ANALYSIS.md:12`) |
| 결제 | Toss Payments(확정 결정 4, `docs/reference/00_MERGE_ANALYSIS.md:13`) |
| 테넌시 | org 기준 스키마, 운영은 1인 1워크스페이스(확정 결정 5, `docs/reference/00_MERGE_ANALYSIS.md:14`) |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `Astro AI/기획안/` (13개 문서) | `docs/reference/reviews/Astro_AI.md` | 약 55% | 크레딧 단가표와 크레딧팩 4종, 사주/타로/통합 리딩 정의, 리딩 품질 기준(2,500자/4,000자), 대시보드 IA, 랜딩 구조와 GEO 문서, WeasyPrint + Noto CJK, Taste(ThemeConfig) 구조, Resend 이메일, 최소 어드민 요구 | Edge Function 단계, Puppeteer 미리보기, 웹훅 중심 결제, broadcast 진행률, 마켓플레이스·크리에이터, 멀티버티컬, 가상 평점·후기·카운터, 다국어, Apple 로그인, Storybook(07장 3절) |
| `FortuneDocs/` (`PRD.MD`, `CLAUDE.MD`) | `docs/reference/reviews/FortuneDocs.md` | 약 40% | 입력 모델, 다중 프로필 보관함, 실시간 원국 프리뷰, 대운 타임라인, 챕터 구조화 JSON, 현대적 재해석 프롬프트 원칙, ePub(Phase 2), 소장형 포지셔닝 | KASI 음력 간지 직접 사용, Puppeteer, Vercel AI SDK 3사 체인, QuickChart, LLM이 만드는 오행 점수, `FOR ALL` RLS, 해설서 편집 화면, Edge 런타임 원칙, 대화 잔재(07장 3절) |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구와 수용 기준, 크레딧 단가와 팩, 비기능 수치, 법·개인정보·금지 문구, KPI, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계, 공용 모듈 사용, 잡과 워커, AI 라우팅 기본값과 그래프 `astro.reading`, 리뷰 "높음" 결함 중 기술·아키텍처 항목의 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 핵심 플로우, 화면별 명세, 메인페이지 디자인 방향(레퍼런스, 브리프, 토큰 플랜), 상태·오류·빈 화면 |
| `04_API.md` | Route Handler, 제품 RPC, 잡 페이로드, 웹훅, 외부 API, 오류 코드 |
| `05_DATA_MODEL.md` | `astro` 스키마 7개 테이블, 상태 전이, RLS, 보안·데이터 결함 차단 설계, 모놀리스와 모듈러 차이, 검증 결과 |
| `06_AGENT_PLAN.md` | 작업 54개(AI·음성·3D·디자인 시스템 16개 포함), 소유 경계, 웨이브, 모델 비율, 리뷰 작업 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본별 자산 분류, 폐기 목록과 사유, 복사 금지 결함, 아카이브 절차 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 `0001_core_lite.sql`(코어 축소판), `0002_astro_domain.sql`, `seed.sql` |
| `../_supabase-modular/migrations/1100_astro.sql` | 통합 DB의 `astro` 스키마 조각(같은 도메인 모델) |

## 5. DB 구조 선택

| 항목 | 결정 | 이유 |
|---|---|---|
| 기본 | 모듈러(`_supabase-modular`, `astro` 스키마) | SSO와 공용 크레딧 지갑을 쓰는 기본값이다(`D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:74`). 출판(flora-publishing)과 렌더 서비스·결제 코드를 공유한다 |
| 대안 | 모놀리스(`supabase/monolith/`, `public` 스키마) | 생년월일시라는 민감 개인정보를 다른 제품과 같은 DB에 두지 않으려는 경우. 스키마를 `public`으로 둔 것은 `MONOLITH_CORE_LITE.sql`을 따른 것이며 최종 확정은 사용자 결정 대기다(01장 8절 D-9) |
| 같은 점 | 테이블, 정책, 함수 이름과 시그니처 | 앱은 `SUPABASE_DB_SCHEMA`(`core`/`public`)와 제품 스키마 이름(`astro`/`public`)만 바꾼다(`docs/file/03-설계/공용코어/CORE_SPEC.md:40`) |
