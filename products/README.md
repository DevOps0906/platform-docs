# docs/products — 통합 제품 기획 인덱스

`docs/reviews/`의 25개 코드 리뷰와 통합 전 기능 분석(`00_MERGE_ANALYSIS.md`)을 바탕으로 비슷한 계열 프로젝트를 합치고, 빠진 기획을 채운 결과물이다. 이 폴더 아래에는 문서와 SQL만 있다. 원본 프로젝트 폴더는 수정하지 않았다.

## 폴더 구성

| 폴더 | 종류 | 원본 프로젝트 | 모듈러 스키마 | 마이그레이션 번호 |
|---|---|---|---|---|
| `_platform-core/` | 공통 | basic-master-module + 그룹 간 공통 결함 | `core` | 0000~0099 |
| `_design-guide/` | 공통 | 신규 | - | - |
| `_supabase-modular/` | 공통 | 신규 (통합 DB) | 전체 | - |
| `flora-publishing/` | 통합 | Flora-v2, flora, flora-publisher, SellingDocs | `publishing` | 1000 |
| `astro-ai/` (신비로운AI) | 통합 | Astro AI, FortuneDocs | `astro` | 1100 |
| `nomad-video/` (NOMAD AI Factory) | 통합 | NOMAD Shorts Maker, Nomad-BlogStudio, Youtube_shots_Maker | `video` | 1200 |
| `nomad-blog/` | 분리 신설 | Shorts Maker 내 Content Automator, Youtube_shots_Maker Track D | `blog` | 1300 |
| `nomad-commerce/` (NOMAD Commerce) | 통합 | Nomad-AI-Factory_V.2, nomad-ai-factory, nomad-ai-commerce, sellingstudio | `commerce` | 1400 |
| `microweb-studio/` | 통합 | premium-wedding-invitation, nexus-micro-web-builder, webcraft-agency-simulator | `microweb` | 1500 |
| `admin-suite/` | 통합(공유 코어 + 앱 3개) | ERP-Wesite, Hospital, School_Management_System | `erp`, `sms` (hms는 제외) | 1600, 1700 |
| `live-poll/` | 단독 | 구현해야 할 프로젝트/Slido_Project | `poll` | 1800 |
| `stock-dashboard/` | 단독 | 구현해야 할 프로젝트/Stock_Trader_nomad | `stock` | 1900 |
| `toon-factory/` | 단독 | Toon-Factory | `toon` | 2000 |
| `study-note/` | 단독 | study-note-organizer-codex-01 | `notes` | 2100 |
| `website-floria/` | 단독 | WebSite | `site` | 2200 |

## 제품 폴더 표준 구성

| 파일 | 내용 |
|---|---|
| `README.md` | 한 줄 정의, 통합 근거, 원본 매핑 |
| `01_PRD.md` | 페르소나, MVP와 Phase 범위, 기능 요구사항과 수용 기준, 요금/크레딧, 비기능 수치, 법/개인정보, KPI |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 잡/워커, AI 라우팅, 리뷰 "높음" 결함의 차단 설계 |
| `03_SCREENS_UX.md` | 화면 목록, 사용자 플로우, 메인페이지 디자인 방향 |
| `04_API.md` | Route Handler / RPC / Edge Function 명세 |
| `05_DATA_MODEL.md` | 테이블, RLS 정책, 모놀리스와 모듈러의 차이 |
| `06_AGENT_PLAN.md` | 멀티에이전트 개발 작업 분해(작업 ID, 소유 파일 경계, 의존성, 권장 모델, 수용 기준) |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기 자산, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 마이그레이션과 seed |

## DB 두 가지 구조

| 구조 | 위치 | 설명 |
|---|---|---|
| 모놀리스 | `<제품>/supabase/monolith/` | 제품마다 Supabase 프로젝트 1개. 인증, 조직, 크레딧 같은 공통 테이블을 제품 안에 축소해 포함한다. |
| 모듈러(통합) | `_supabase-modular/` | Supabase 프로젝트 1개에 `core` 스키마와 제품별 스키마를 둔다. 공통 테이블과 RLS 헬퍼를 core에 한 번만 정의한다. hms(병원)는 의료정보 격리를 위해 제외한다. |

## 모델 배치 원칙

| 모델 | 담당 |
|---|---|
| Fable 5.1 | 결제, 권한, RLS, 데이터 모델 같은 실수 비용이 큰 설계 (이번 작업에서는 `_platform-core`와 통합 DB core만) |
| Opus 5.5 | 기획 통합 분석, 기능 설계, API 연동, 테스트 설계, 검증 |
| Sonnet 5.5 | UI/메인페이지 구현, 컴포넌트, 문서 정리 |
| Haiku 5.5 | 보일러플레이트, 린트/타입 정리, 문구, 체크리스트 점검 |

## 확정 결정
`00_MERGE_ANALYSIS.md` 상단의 "확정 결정" 표를 따른다. 2026-10-12에 결정 12(제휴마케팅 공용 모듈)가 추가되었다.

## 진행 상태 (2026-10-13)

| 단계 | 내용 | 상태 | 산출물 |
|---|---|---|---|
| 0 | 폴더 골격, 통합 분석, 인덱스 | 완료 | `00_MERGE_ANALYSIS.md`, 이 문서 |
| 1 | 공용 코어, core DB, 디자인 가이드 | 완료 | `_platform-core/` 6개, `_supabase-modular/migrations/0000~0007`, `_design-guide/` 3개 |
| 2 | 제품 12개 기획과 DB | 완료 | 제품 폴더마다 문서 9개와 `supabase/`, 모듈러 조각 13개 |
| 3 | SQL 통합 검증, 구조 점검 | 완료 | `_supabase-modular/VERIFICATION.md`, `_STRUCTURE_CHECK.md` |
| 4 | 인덱스 마무리, 최종 보고 | 완료 | 이 절 |

## 제품별 결과

| 제품 | 리뷰 "높음" = 차단 설계 | 06장 작업 | RLS 스모크(모듈러 / 모놀리스) | 사용자 결정 위치 |
|---|---|---|---|---|
| flora-publishing | 25 | 38 | 57/57 / 57/57 | `flora-publishing/01_PRD.md` 8절 |
| astro-ai | 14 | 38 | 65/65 / 64/64 | `astro-ai/01_PRD.md` 8절 |
| nomad-video | 26 | 40 | 65/65 / 65/65 | `nomad-video/01_PRD.md` 8절 |
| nomad-blog | 16 | 40 | 69/69 / 67/67 | `nomad-blog/01_PRD.md` 8절 |
| nomad-commerce | 22 | 40 | 60/60 / 59/59 | `nomad-commerce/01_PRD.md` 8절 |
| microweb-studio | 10 | 35 | 87/87 / 87/87 | `microweb-studio/01_PRD.md` 8절 |
| admin-suite | 14 | 40 | 92/92 / erp 21, sms 19, hms 52 전부 통과 | `admin-suite/01_PRD.md` 8절 |
| live-poll | 4 | 32 | 79/79 / 77/77 | `live-poll/01_PRD.md` 8절 |
| stock-dashboard | 6 | 34 | 75/75 / 75/75 | `stock-dashboard/01_PRD.md` 8절 |
| toon-factory | 6 | 40 | 68/68 / 68/68 | `toon-factory/01_PRD.md` 8절 |
| study-note | 3 | 30 | 84/84 / 85/85 | `study-note/01_PRD.md` 8절 |
| website-floria | 8 | 32 | 72/73 (실패 1건은 core 결함, 0007로 해소, 단계 3 통합 검증 통과) / 71/71 | `website-floria/01_PRD.md` 8절 |
| 합계 | 154 | 439 | | |

통합 DB(core + 조각 13개 + seed) 결과는 `_supabase-modular/VERIFICATION.md`를 따른다.
- 두 가지 적용 순서 모두 OK다.
- PUBLIC EXECUTE 남은 함수 0개, search_path 없는 DEFINER 0개, RLS 꺼진 테이블 0개다.
- 교차 조직 누출은 129개 테이블에서 0건이다.

06장 작업의 모델 배분(439개)은 Fable 76(17.3%), Opus 211(48.1%), Sonnet 112(25.5%), Haiku 40(9.1%)이다.

## 개발 순서 (제안)

| 웨이브 | 대상 | 이유 |
|---|---|---|
| 0 | `_platform-core` 패키지, core DB 0000~0007, 통합 seed | 모든 제품이 의존한다 |
| 1 | study-note, website-floria | 범위가 작아 core 계약을 먼저 실전 검증한다 |
| 2 | flora-publishing, astro-ai | 공용 WeasyPrint 렌더 서비스를 함께 만든다 |
| 3 | nomad-video, nomad-blog, nomad-commerce | affiliate·SNS 업로더·잡 워커를 공유한다 |
| 4 | microweb-studio, live-poll, toon-factory | 독립 도메인이다 |
| 5 | admin-suite, stock-dashboard | 의료정보·금융 규제 확인이 먼저 필요하다 |

## 남은 코어 과제

| 과제 | 출처 |
|---|---|
| `signup_policy='invite'` 강제 (현재 stock, microweb, floria가 제품 게이트로 우회) | 제품 06장 6절 |
| `adjust_credits` RPC 추가 | 여러 제품 06장 6절 |
| `confirm_payment_order`가 금액 불일치 주문을 failed로 남기지 못함 | `_platform-core` 작성 보고 |
| `has_entitlement`/`entitled_plan_code`의 anon 호출 허용 여부 | `_supabase-modular/VERIFICATION.md` |
| 익명 사용자 가입 시 개인 조직 생성 건너뛰기 | `live-poll/06_AGENT_PLAN.md` 6절 |
| 팀 조직 생성 함수, `purge_organization`과 결제 기록 보존 충돌 | `admin-suite`, `astro-ai` 06장 6절 |
| storage 정책의 `owner` 컬럼 사용 확인, `write_audit` action 제한 | `_platform-core` 작성 보고 |
| 제품 문서에 남은 "모듈러 seed 불일치" 문장 정리(seed는 이미 정합화됨) | `_supabase-modular/VERIFICATION.md` |
| 로컬 Supabase(`supabase db reset`)에서 재검증 | 검증은 PGlite 기준 |
