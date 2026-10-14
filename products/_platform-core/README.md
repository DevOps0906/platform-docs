# _platform-core — 모든 제품이 쓰는 공통 코어 규격

13개 제품이 공유하는 인증·조직·크레딧·결제·잡·저장소·감사·AI·음성의 규격입니다. 제품 작업에서는 이 폴더를 고치지 않고, 필요하면 각 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적습니다.

| 파일 | 내용 |
|---|---|
| [`CORE_SPEC.md`](CORE_SPEC.md) | 플랫폼 공통 코어 명세(인증, 조직·역할, 엔타이틀먼트, 크레딧, Toss 결제, 잡, 브랜드커넥트 등) |
| [`SHARED_MODULES.md`](SHARED_MODULES.md) | 공용 모듈 경계와 인터페이스(누가 소유하고 누가 쓰는지, 예: PDF 렌더는 flora-publishing 소유) |
| [`SECURITY_BASELINE.md`](SECURITY_BASELINE.md) | 모든 제품이 지켜야 하는 보안 규칙(RLS, service_role, 웹훅 서명, AI 보안 등) |
| [`DB_CONVENTIONS.md`](DB_CONVENTIONS.md) | 제품 스키마 작성 규칙(이름, 번호 범위, RLS 패턴, 모놀리스 변환) |
| [`DOC_TEMPLATE.md`](DOC_TEMPLATE.md) | 제품 기획서(README, 01~07, CLAUDE.md)의 장 구조 정본 |
| [`AI_ARCHITECTURE.md`](AI_ARCHITECTURE.md) | AI 계층(RAG, LangChain·LangGraph, Dify, 모델 라우팅, 서명 토큰) |
| [`LLM_WIKI.md`](LLM_WIKI.md) | 제품 지식 위키와 개발용 프로젝트 위키 |
| [`VOICE_ARCHITECTURE.md`](VOICE_ARCHITECTURE.md) | 음성 대화·제품 음성 기능, ElevenLabs·오픈소스 이원화 |
| [`MONOLITH_CORE_LITE.sql`](MONOLITH_CORE_LITE.sql) | 제품별 단독 Supabase 프로젝트(모놀리스)용 코어 SQL 축소판. 제품 `supabase/monolith/migrations/0001_core_lite.sql`의 원본 |
| [`AUTH_ROADMAP.md`](AUTH_ROADMAP.md) | 인증 단계 규격(2026-10-14): Mock(로컬 시드 계정) → Google OAuth → 카카오·네이버, 게이트 G1·G2, Mock 가드, 콜백 공통 처리, 제품별 적용 매트릭스 |
| [`staged/`](staged/) | 보류 마이그레이션. `0010_core_auth_identity_links.sql`은 네이버 브리지 경로를 택할 때만 적용(`AUTH_ROADMAP.md` 7.2.3절) |

통합 DB(모듈러) 버전의 코어 SQL은 [`../_supabase-modular/migrations/0000~0009`](../_supabase-modular/migrations/)입니다.
