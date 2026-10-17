# NOMAD Blog (nomad-blog)

작성일 2026-10-12. 단계 2 제품 기획 산출물이다. 장 구조는 `docs/products/_platform-core/DOC_TEMPLATE.md` 2.1절을 따른다.

## 1. 한 줄 정의

키워드 하나로 AI가 블로그 원고를 쓰고, 제휴 상품 카드와 대가성 문구를 자동으로 넣은 뒤, 네이버 블로그·티스토리·워드프레스에 예약 발행까지 해 주는 조직 단위 SaaS다. 블로그 원고에 붙는 네이버 브랜드커넥트 지원도 이 제품이 자동으로 제출한다.

| 항목 | 내용 |
|---|---|
| 대상 사용자 | 제휴 수익(쿠팡파트너스, 네이버 브랜드커넥트, 텐핑, 네이버쇼핑 커넥트)을 노리는 1인 블로그 운영자, 블로그 여러 개를 운영하는 제휴 마케터, 자체 워드프레스로 정보성 글을 쌓는 소상공인 |
| 핵심 가치 | 원고 작성 시간 단축, 채널별 수동 복붙 제거, 대가성 문구 누락으로 생기는 표시광고법 위험 차단 |
| 브랜드 | NOMAD Blog (`docs/products/_supabase-modular/seed.sql:16`의 앱 이름) |
| 모듈러 스키마 / 앱 id | `blog` (`docs/products/README.md:16`) |
| 로그인 단계 (2026-10-14) | MVP 개발은 Mock 로그인(Stage A, 로컬 시드 계정으로 실제 JWT) → G1 → 공개 베타 전 Google + 이메일(Stage B, P0) → G2 → 카카오(C1)·네이버(C2, 둘 다 P1. 네이버 블로거 비중이 커서 검수 신청을 G2 직후 먼저). 사용자 로그인은 블로그 채널(네이버·티스토리 게시 계정) 연결과 별개다. 확정 결정 22, 정본 `docs/products/_platform-core/AUTH_ROADMAP.md`, 이 제품 적용은 02장 9절 |

2026-10-13부터 AI 계층이 MVP에 들어간다(확정 결정 13~17). 사용자의 브랜드·상품·캠페인 자료를 RAG로 색인하고, 토픽·키워드 위키로 정리하며, LangGraph `blog.post_draft`(키워드 리서치 → 자료 검색 → 초안 → 제휴 링크·대가성 점검 → SEO 점검 → 규정 검사 → 사람 승인)가 원고를 만든다. 글쓰기 도우미 채팅(공용 Dify 앱 `blog-chat`)과 음성 받아쓰기·음성 대화, 상용/오픈소스 LLM 이원화와 온보딩 국외 이전 동의, 3D 히어로(원고 시트가 접혀 채널 카드로 발행됨)가 함께 들어간다. 네이버 브랜드커넥트 완전 자동 지원과 위험 동의, 제휴 대가성 문구 규칙은 확정 결정 12 그대로이며 AI가 바꾸지 않는다.

## 2. 통합 근거

| 근거 | 내용 | 출처 |
|---|---|---|
| 확정 결정 1 | 블로그는 영상(shortsflow)과 분리한 단독 제품이다. 공유하는 것은 `_platform-core`뿐이다. 블로그 게시기(네이버/티스토리/워드프레스)는 blog가 소유한다. commerce의 블로그 원고 기능은 commerce 범위에서 뺀다 | `docs/products/00_MERGE_ANALYSIS.md:9` |
| 확정 결정 12 | 제휴 링크, 클릭 통계, 대가성 문구는 `_platform-core` affiliate 모듈이 맡는다. blog는 본문에 제휴 상품 카드와 링크를 자동 삽입하고 글 상단에 대가성 문구를 자동 삽입한다. 네이버 브랜드커넥트 지원은 blog가 소유하며 완전 자동(Playwright)으로 한다 | `docs/products/00_MERGE_ANALYSIS.md:20` |
| C-5-1 (b) 결정 | CA는 플랜 단위가 포스팅 수(Free 10건 / Pro 50건)라서 숏츠 크레딧 모델과 맞지 않고, Shorts PRD v0.4에는 블로그가 없다 | `docs/products/00_MERGE_ANALYSIS.md:692-702` |
| 실제 블로그 기능의 위치 | Nomad-BlogStudio는 블로그 제품이 아니다. 실제 블로그 기능은 Shorts Maker 안의 CA와 YSM Track D에만 있다 | `docs/products/00_MERGE_ANALYSIS.md:53-56` |
| D-5-8 | commerce는 원고 생성까지만 하고 발행은 블로그 제품이 맡는 안을 권장했다. 확정 결정 1로 commerce의 원고 기능 자체가 빠졌으므로 상품형 원고 템플릿(정보형/비교형)은 blog가 흡수한다 | `docs/products/00_MERGE_ANALYSIS.md:939-942`, `nomad-ai-factory/CLAUDE.md:242` |

베이스 선정: 코드 베이스는 NOMAD Shorts Maker 안의 Content Automator(CA)다. CA는 원고 생성, 키워드 추천, SEO 점수, 네이버/티스토리 Playwright 게시, 워드프레스 REST 게시, 쿠팡 링크 검색과 삽입, 브랜드커넥트 Playwright 골격, TipTap 멀티채널 에디터를 이미 갖췄다(`docs/reviews/NOMAD_Shorts_Maker.md:42`, `:60`). YSM Track D에서는 네이버 스마트에디터 3.0 처리(제목·iframe·태그·발행 URL 파싱·CAPTCHA 감지)와 Celery 재시도 구조의 설계만 가져온다(`[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:180-288`). 저장소는 새로 만든다. CA는 user 기준 스키마(`NOMAD Shorts Maker/supabase/migrations/001_initial.sql:8`)이고 영상 제품과 같은 저장소에 섞여 있어(`docs/reviews/NOMAD_Shorts_Maker.md:10`) 그대로 확장할 수 없다.

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| NOMAD Shorts Maker 안의 Content Automator(`src/skill/**`, `src/components/posts/*`, `src/app/api/{posts,ai,coupang,brand-connect,accounts,schedules}`) | `docs/reviews/NOMAD_Shorts_Maker.md` | 저장소 전체 약 35%. CA 부분은 "구현(Playwright, Meta Graph), 내부 호출 인증 우회"(`:42`) | 원고·키워드·SEO 로직, Playwright 게시 3종, 워드프레스 클라이언트, 쿠팡 HMAC 클라이언트, 브랜드커넥트 Playwright 골격, TipTap 에디터와 5탭 보조 패널 구성 | user 기준 9테이블, `x-internal-call`, 평문 세션 저장, Mock 브랜드커넥트 추천, 내 블로그 클라이언트, 폴백 해시태그, 플랜 3벌 |
| Youtube_shots_Maker Track D(`[5f6d262]` 스냅샷) | `docs/reviews/Youtube_shots_Maker.md` | 작업 트리 약 5%, 스냅샷 55~60%(`:36-38`) | 스마트에디터 3.0 게시 절차, 발행 URL 파싱, 재시도 지수 백오프 설계, AES-GCM 키 길이 검증 방식 | FastAPI/Celery 런타임, 가상 후기를 요구하는 프롬프트, LLM 실패 시 가짜 원고 폴백, 봇 감지 우회 코드, 네이버쇼핑 Mock 폴백 |
| nomad-ai-commerce 11단계(지역뉴스 블로그) | `docs/reviews/nomad-ai-commerce.md` | 리뷰 기준 | 없음(요구사항 문장만 참고) | `tableName` 임의 테이블 insert 라우트(`docs/reviews/nomad-ai-commerce.md:63`) |
| nomad-ai-factory(v1) GEO 블로그 원고 | `docs/reviews/nomad-ai-factory.md` | 리뷰 기준 | 정보형/감성형/스펙비교형 3버전 원고 템플릿 개념(`nomad-ai-factory/CLAUDE.md:234`, `:242`) | BlogNode, 결과물 보관함 마크다운 저장 구조 |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase, 기능 요구사항과 수용 기준(AI·음성·3D 포함), 요금과 크레딧(AI 단가 4.6절), 비기능 수치, 법·약관·브랜드커넥트 위험 고지·AI 개인정보 규칙, KPI, 열린 결정(D-1~D-21, 인증 단계 D-22~D-24는 8.1절. 8절 #12 네이버 소셜 로그인은 결정 22로 해소) |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계, 공용 모듈 사용, 잡과 워커, AI 라우팅 기본값 12행과 그래프 `blog.post_draft`, 리뷰 "높음" 결함 중 구조 결함 차단 설계, 배포, 환경변수, 인증 단계(9절: 단계표, 채널 로그인과의 분리, 인증 env, 외부 콘솔) |
| `03_SCREENS_UX.md` | 화면 목록, 핵심 플로우, 화면별 명세(AI 채팅·음성·자료·위키·승인 화면, 디자인 시스템), 랜딩 디자인 방향(레퍼런스·브리프·토큰·3D 히어로), 상태와 오류, 인증 단계별 로그인 화면·오류·약관 위치·로그인 방법(7절) |
| `04_API.md` | Route Handler(`/api/ai/*`, `/api/voice/*` 포함), 제품 RPC, 잡 페이로드, 웹훅, 외부 어댑터(FastAPI 엔드포인트, Dify 계약), 오류 코드, 인증 단계 라우트(8절: `/api/dev/login`, `/auth/callback`, 네이버 브리지) |
| `05_DATA_MODEL.md` | `blog` 스키마 4테이블, 상태 전이, RLS, 보안·데이터 결함 차단 설계, 모놀리스 차이, 검증 결과, 개발용 시드 페르소나(10절, 스키마 변경 없음, `owner_pro` 포함) |
| `06_AGENT_PLAN.md` | 멀티에이전트 작업 59개(AI·음성·3D·디자인 시스템 16개, 인증 단계 3개(BL-06-057~059, 8절) 포함), 웨이브, 모델 비율, 리뷰 작업 흡수표, 코어 요청(AI-R1~R7, 인증 8.3절) |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기 자산, 분석 "폐기" 전 항목, 복사 금지 결함, 아카이브 절차, 인증 단계 복사 금지(6절: 원본 `mock-auth`, 쿠키 역할 Mock, 콜백 `next` 무검증) |
| `CLAUDE.md` | 개발 에이전트 지침, 인증 단계 규칙(8절) |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 `0001_core_lite.sql`(코어 원본 그대로), `0002_blog_domain.sql`, `seed.sql`(AI 라우팅 기본값 12행 포함) |
| `../_supabase-modular/migrations/1300_blog.sql` | 통합 DB용 `blog` 스키마 조각 |

2026-10-13 확정 결정 19: 브랜드커넥트 지원서가 블로그형/클립형으로 나뉘었다. blog는 블로그형을 만들고 클립형 캠페인은 video로 넘기며(BL-F-036), 블로그 원고를 클립 대본으로 넘기는 OSMU는 Phase 2다(BL-F-037). 코어 변경은 `../_platform-core/CORE_SPEC.md` 16.1절.

## 5. DB 구조 선택

| 항목 | 선택 | 이유 |
|---|---|---|
| 1차(출시) | 모듈러 | video와 같은 사용자층이고 공용 모듈만 공유한다(`docs/products/_supabase-modular/ARCHITECTURE.md:34`). 같은 계정과 조직 지갑으로 영상·블로그를 함께 쓰는 크로스 셀이 가능하다 |
| 2차 | 유지 | 위와 같음 |
| 모놀리스 | 준비만 | `supabase/monolith/`는 단독 배포가 필요할 때(예: 블로그만 별도 운영) 쓴다. 코어 [선택] 절을 하나도 지우지 않았다. blog는 결제, 크레딧, 자격증명, 잡, Storage, affiliate를 모두 쓴다 |
| 모놀리스 스키마 | `public` | `_platform-core/MONOLITH_CORE_LITE.sql` 결정을 따른다. 최종 사용자 확인 대기(05장 8절) |
