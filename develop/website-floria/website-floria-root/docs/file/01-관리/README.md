# Floria (website-floria)

작성일 2026-10-12. 작업 루트 `D:\WorkSpace\platform`. 이 폴더에는 문서와 SQL만 있다. 앱 코드는 만들지 않았다.

## 1. 한 줄 정의

고급 주거, 갤러리, 기업 공간의 식물 설치를 의뢰하려는 사람이 작업물을 보고 문의 또는 뉴스레터 구독으로 이어지게 하는 Floria "Botanic Architecture" 브랜드 사이트와, 그 문의를 받아 처리하는 초대제 운영 콘솔이다. 2026-10-13부터 방문자 AI 상담(시공 사례·식물 정보·FAQ RAG, LangGraph `site.consult`, 문의 전환), 방문자 음성 상담, 브랜드 지식 위키(`/guide`), 3D 온실 구조물 히어로가 MVP에 들어간다(확정 결정 13~17).

| 구분 | 내용 | 근거 |
|---|---|---|
| 대상 사용자 | (1) 방문자: 갤러리 디렉터, 이벤트 기획자, 하이엔드 개인 고객(로그인 없음) (2) 스튜디오 운영자: 문의를 받고 처리하는 초대받은 소수 | `WebSite/Botanic_Architecture/PRD.md:17-21`(타겟 오디언스 2장) |
| 제품 성격 | 마케팅 사이트 + 문의/뉴스레터 백엔드 + 방문자 AI 상담. 요금, 크레딧, 결제가 없다 | `D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:42` |
| AI 요약 | 비로그인 방문자 상담(운영자 조직 예산, 크레딧 없음, 강한 레이트 리밋). 지식은 운영자가 공개하는 자료뿐. 기본 꺼짐 스위치와 운영자 조직의 국외 이전 동의 전에는 국내 오픈소스 모델만 쓴다. 상담은 문의 초안만 만들고 제출은 기존 문의 폼이 처리한다 | 01_PRD.md SI-F-022~030 |
| 앱 ID / 스키마 | `core.apps.id = site`, 모듈러 스키마 `site`, 마이그레이션 번호 2200 | `D:/WorkSpace/platform/docs/products/README.md:23` |
| 가입 정책 | `invite`. 코어가 강제하며(2026-10-13), 추가로 `provision_site`(service_role)로 사이트를 등록해야 콘솔이 열린다 | 05_DATA_MODEL.md 4장 |

## 2. 통합 근거

이 폴더는 분석이 "유지(별도 저장소)"로 판정한 WebSite 그룹(`docs/reference/00_MERGE_ANALYSIS.md:1002`, `:1060`) 중 Floria "Botanic Architecture" 사이트를 제품으로 승격하고, 분석이 "신규(WebSite와 공유)"로 적은 공용 폼 백엔드(`docs/reference/00_MERGE_ANALYSIS.md:1065`)를 이 제품의 `site` 스키마가 소유하도록 정한 것이다. 분석의 판정과 다른 점은 아래 표에 모두 적었다.

| 항목 | 분석/확정 결정 | 이 기획의 해석 | 이유 |
|---|---|---|---|
| WebSite 5개 사이트의 코드 통합 | 코드를 합치지 않고 별도 저장소로 유지(`00_MERGE_ANALYSIS.md:1094` 권고 B) | 합치지 않는다. Floria(Botanic)만 이 제품의 앱으로 새로 구성하고 나머지 4개는 "연계 사이트"로 둔다 | 스택(HTML, JSX, TSX)과 미디어 규모(Lucury 529MB)가 서로 달라 합칠 이유가 없다(`:1004`) |
| 폼 백엔드 | 서버리스 1개, WebSite와 공유(`:1065`) | `site.sites`에 사이트를 등록하면 어느 사이트든 같은 문의/뉴스레터 RPC를 쓴다 | 허니팟과 레이트 리밋을 사이트마다 다시 만드는 것을 막는다 |
| 기술 기반 | 마이크로웹은 Next.js 16 + Supabase 이전을 권고(`:1089`) | 같은 근거로 Next.js 16 + Supabase를 쓴다(제안) | 서버 Route Handler에 service_role을 두고 slug별 OG/JSON-LD를 만들 수 있다 |
| Floria 3종(Botanic, Floria_Neo, NEO_02) | 리뷰는 NEO_02 기반 단일 프로젝트 통합을 권고(`docs/reference/reviews/WebSite.md:239`) | Botanic을 베이스로, Floria_Neo는 카피 출처로만 흡수. NEO_02는 이름만 비슷한 별개 브랜드(Flora Sentiment)라 합치지 않는다(`00_MERGE_ANALYSIS.md:1007`) | 한 프로젝트에 두 브랜드를 넣으면 토큰 세트와 법적 고지가 섞인다 |
| 출판 SaaS "FLORA"와의 관계 | 이름만 같고 무관, 합치면 안 됨(`:1007`) | 무관. 코드, 브랜드, DB 모두 분리한다 | 상표와 사용자 혼동 방지 |

확정 결정과의 관계: 결정 4(Toss)와 8(플랜 정본)은 이 제품에 적용 대상이 없다(결제 없음). 결정 5(org 기준 스키마, 1인 1워크스페이스)와 11(Next.js + platform-core)은 그대로 따른다(`00_MERGE_ANALYSIS.md:13`, `:19`).

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `WebSite/Botanic_Architecture` | `docs/reference/reviews/WebSite.md` | 약 55%(`:41`) | PRD의 7섹션 구성, 카피, GEO 전략, `useFadeIn` 개념, 디자인 레퍼런스 캡처 2장(참고용) | 인라인 style 904줄 단일 파일, 가상 후기 5건, 임시 가격, LA 주소와 555 전화번호가 든 가짜 연락처 JSON-LD 예시(`Botanic_Architecture/CLAUDE.md:154-156`), 디버그 `.mjs` |
| `WebSite/Floria_Neo` | 같음 | 약 40%(`:56`) | 한국어 카피(`index.html`)를 콘텐츠 비교 자료로만 | Tailwind Play CDN, googleusercontent 서명 URL 12개, 0바이트 `Images` 파일, 달러 가격 |
| `WebSite/Floria_NEO_02` (Flora Sentiment) | 같음 | 약 60%(`:72`) | 코드 구조 패턴(`data/` 레이어, `@theme` 토큰)을 참고. 앱은 별도 브랜드로 유지 | 미정의 라우트 7개, 템플릿 잔재, `temp-init` 명칭 |
| `WebSite/Lucury Website`(한울건설) | 같음 | 약 65%(`:88`) | 접근성 기본기(`prefers-reduced-motion`, `aria-expanded`)를 체크리스트 근거로 | 이 제품으로 이식하지 않음. 연계 사이트로 폼 백엔드만 공유 가능 |
| `WebSite/Biz_Website` | 같음 | 측정 불가(`:23`) | 없음. 소스가 없어 복원 전에는 제외 | `dist/`, `node_modules/`는 아카이브 대상 |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `README.md` | 이 문서 |
| `01_PRD.md` | 페르소나, 범위, 기능 요구사항(SI-F-###)과 수용 기준, 요금 없음 근거, 비기능 수치, 법/개인정보/금지 문구, KPI |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계, 공용 모듈 사용표, 잡 없음 근거, AI 라우팅 기본값 8행과 그래프 `site.consult`, 리뷰 "높음" 8건의 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 사용자 플로우, 화면별 명세(상담·음성·위키·콘솔 AI), 디자인 시스템 항목, 메인페이지 디자인 방향(레퍼런스, 토큰, 와이어프레임, 3D 히어로) |
| `04_API.md` | Route Handler(공개 4개 + AI·음성·관리), `site` 스키마 RPC 11개, 토큰 규격, FastAPI·Dify 계약, 오류 코드 |
| `05_DATA_MODEL.md` | 테이블 3개(제품 AI 테이블 없음, 코어 AI 테이블 참조), 상태 전이, RLS, 인덱스, 모놀리스/모듈러 차이 |
| `06_AGENT_PLAN.md` | 작업 48개(AI·음성·3D·디자인 시스템 16개 포함), 웨이브, 모델 비율, 리뷰 작업 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 이식/폐기 자산, 복사 금지 결함, 아카이브 절차 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/migrations/0001_core_lite.sql` | `D:/WorkSpace/platform/docs/products/_platform-core/MONOLITH_CORE_LITE.sql` 복사본. [선택] 7개 절만 주석과 함께 제거 |
| `supabase/monolith/migrations/0002_website_floria_domain.sql` | 도메인 테이블과 RPC(모듈러 조각을 변환한 것) |
| `supabase/monolith/seed.sql` | `apps` 1행, 기본 플랜 1행, AI·음성 라우팅 기본값 8행 |
| `../_supabase-modular/migrations/2200_site.sql` | 모듈러 조각(같은 도메인 모델) |

## 5. DB 구조 선택

| 항목 | 내용 |
|---|---|
| 1차 선택 | 모듈러(통합 DB). `_supabase-modular/ARCHITECTURE.md:42`가 "모듈러(폼 백엔드만), 문의/뉴스레터 테이블 1~2개"로 정했다. 이 기획은 테이블 3개(`sites`, `inquiries`, `newsletter_subscribers`)로 늘렸다. 늘린 이유는 05_DATA_MODEL.md 1장에 적었다 |
| 모놀리스 제공 | 제공한다. 마케팅 사이트만 따로 배포하는 고객사(예: 스튜디오가 자기 Supabase를 쓰는 경우)를 위한 대안이다. 스키마는 `public`이며 사용자 최종 확인 전 가정이다(05_DATA_MODEL.md 8장) |
| 코어에서 쓰는 것 | 인증/조직/멤버십, `app_entitlements`, 감사 로그, 레이트 리밋, AI·음성 코어 테이블(`ai_*`, `wiki_*`, `voice_*`). 크레딧, 결제, 잡, Storage, OAuth, 제휴는 쓰지 않는다 |
| 알려진 코어 이슈 | (1) `confirm_payment_order`는 금액 불일치 시 failed 주문을 남기지 못한다. 이 제품은 결제가 없어 의존하지 않는다 (2) 모듈러 코어에서 서비스 전용 함수에 PUBLIC EXECUTE가 남는 점검 결과를 05_DATA_MODEL.md 6장과 06_AGENT_PLAN.md 6장에 적었다. 코어는 수정하지 않았다 |
