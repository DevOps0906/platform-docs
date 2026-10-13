# Microweb Studio (microweb-studio)

## 1. 한 줄 정의

하객에게 보내는 모바일 마이크로웹(1차 청첩장, 2단계 돌잔치·부고장)을 템플릿 엔진으로 만들고, 같은 사이트의 쇼룸(포트폴리오, 가격표, 업종x등급 시뮬레이터, 견적 문의)으로 대행 제작을 파는 제품이다. 2026-10-13부터 AI 문구·구성 제안(LangGraph `microweb.invitation_copy`), 이벤트 종류별 문구 위키와 RAG, 제작 상담 AI 채팅(Dify), 음성 대화, 청첩장 인사말 음성, 하객 음성 방명록(STT 자막), 쇼룸 3D 히어로(봉투가 열려 미니 사이트가 됨)가 MVP에 들어간다(확정 결정 13~17).

| 대상 | 설명 |
|---|---|
| 1차 사용자 | 스튜디오 운영자(대행 제작자). 초대제 베타로 계정을 받는다 |
| 1차 고객 | 대행을 맡기는 예비부부, 소상공인. 계정 없이 문의, 시안 확인 링크, 결제(계좌이체)로 참여한다 |
| 최종 열람자 | 하객. 로그인 없이 `/i/:slug`를 연다 |
| 2단계 | 초대받은 셀프서비스 사용자. 직접 편집하고 크레딧(Toss)으로 발행한다 |

## 2. 통합 근거

| 근거 | 내용 |
|---|---|
| 확정 결정 11 | 대행 제작으로 시작해 셀프서비스로 확장하고, Next.js + platform-core로 이전한다(`docs/reference/00_MERGE_ANALYSIS.md:19`) |
| 베이스 선정 | premium-wedding-invitation이 하객이 실제로 쓰는 기능(계좌 복사, tel/sms, 지도 딥링크, 방명록, 공유)을 가진 유일한 원본이다(`docs/reference/00_MERGE_ANALYSIS.md:994`, `docs/reference/reviews/premium-wedding-invitation.md:22`, `:122`) |
| webcraft | 랜딩, 포트폴리오, 가격표, 시뮬레이터가 동작하므로 영업 프론트로 붙인다(`docs/reference/reviews/webcraft-agency-simulator.md:131`) |
| nexus | 상품이 아니라 기획 쇼케이스다. 12개 모델 데이터만 템플릿 카탈로그로 흡수하고 앱은 아카이브한다(`docs/reference/reviews/nexus-micro-web-builder.md:120`) |
| 공통 잔재 | 세 원본이 같은 Vertex AI Studio 템플릿(프록시, 인터셉터)에서 나와 한 번에 걷어낼 수 있다(`docs/reference/reviews/nexus-micro-web-builder.md:7`) |
| 테넌시 | org 기준 스키마, 운영은 1인 1워크스페이스(확정 결정 5, `docs/reference/00_MERGE_ANALYSIS.md:13`) |
| 결제 | Toss Payments(확정 결정 4). 셀프서비스 발행은 core 크레딧팩으로 판다 |
| 가입 정책 | 초대제 베타. `core.apps.signup_policy='invite'`, status `beta`(`D:/WorkSpace/platform/docs/products/_supabase-modular/seed.sql:18`) |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `premium-wedding-invitation/` | `docs/reference/reviews/premium-wedding-invitation.md` | 약 45% | 섹션 컴포넌트 7개(UI, 모션), 계좌 복사·tel/sms·지도 딥링크·달력·음악·공유 UX, 방명록 UI, 축하말 프롬프트 의도 | Vertex 범용 프록시/인터셉터/WS, 방문마다 Imagen 생성, AI 지도 이미지, constants 하드코딩, localStorage 방명록, 가짜 SRI |
| `nexus-micro-web-builder/` | `docs/reference/reviews/nexus-micro-web-builder.md` | 약 55% | `frontend/data/models.ts` 12개 모델(가격대, 디자인/영업 메모), 모바일 목업의 정보 구조 | 앱 본체(산점도, 기획서 다운로드), 고아 대시보드 템플릿, 백엔드 |
| `webcraft-agency-simulator/` | `docs/reference/reviews/webcraft-agency-simulator.md` | 약 50% | 업종 9 x 등급 4 시뮬레이터, `constants/geoMeta.ts`, 가격표(`PRICING_PLANS`), 포트폴리오 필터 UI, 상세페이지 포트폴리오 | 모킹 로그인, 관리자 대시보드, 설정 잠금 1234, 중복 constants, 고아 파일, 중첩 repo, 커밋된 node_modules와 `.env.local`, 미검증 수치 |
| `WebSite/`(참고) | `docs/reference/reviews/WebSite.md` | - | 포트폴리오 엔트리(링크, 스크린샷)만 | 코드 통합 없음(별도 저장소 유지, `docs/reference/00_MERGE_ANALYSIS.md:1002`) |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase, 기능 요구와 수용 기준(AI·음성 MW-F-026~036), 요금과 AI·음성 단가, 비기능, 법/개인정보/금지 문구(하객 녹음 고지 포함), KPI, 열린 결정 D-1~D-18 |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D·Tailwind CSS v4), 모듈 경계, 공용 모듈 사용, 잡, AI 라우팅 기본값 12행과 그래프 2개, 리뷰 "높음" 결함(구조) 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 플로우(F5~F9 AI·음성), 화면 명세, 디자인 시스템, 쇼룸 랜딩 3D 히어로와 청첩장 템플릿 디자인 방향 |
| `04_API.md` | Route Handler, RPC, 잡 페이로드, 웹훅, 외부 API, 오류 코드 |
| `05_DATA_MODEL.md` | `microweb` 스키마 10개 표(방명록 음성 연결 컬럼 2개 추가), 상태 전이, RLS, 리뷰 "높음" 결함(보안/데이터) 차단 설계, 모놀리스 차이 |
| `06_AGENT_PLAN.md` | 작업 53개(AI·음성·3D·디자인 시스템 18개 포함), 웨이브, 모델 비율, 리뷰 작업 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기, 복사 금지 결함, 노출된 `.env.local` 처리, 아카이브 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | `0001_core_lite.sql`(6-A, 6-B, 9절 제거), `0002_microweb_domain.sql`, `seed.sql` |
| 모듈러 조각 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1500_microweb.sql` |

## 5. DB 구조 선택

| 항목 | 결정 | 근거 |
|---|---|---|
| 1차 | 모듈러(`microweb` 스키마) | 대행 단계는 데이터가 작고 SSO·공용 지갑의 이점이 크다(`D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:41`) |
| 모놀리스 | 같은 도메인을 `public`에 둔 사본을 함께 유지 | 고객사별 분리나 독립 운영이 필요할 때를 대비. 스키마 `public`은 사용자 최종 확인 대기(05장 8절) |
| 검증 | 두 구조 모두 SQL 체커 OK, RLS 스모크 87/87 통과(05장 9절) | `D:/WorkSpace/platform/docs/products/_tools-sqlcheck/` |
