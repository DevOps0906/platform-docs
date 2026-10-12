# Stock Dashboard (stock-dashboard)

작성일 2026-10-12. 원본 기획 완성도가 약 20%인 단독 프로젝트(`docs/reviews/Stock_Trader_nomad.md:21`)를 초대제 베타로 출시할 수 있는 수준까지 채운 기획서다. 원본 서비스명은 "InvestGEN"(`구현해야 할 프로젝트/Stock_Trader_nomad/PRD.md:4`)이었으나 이 폴더에서는 작업명 Stock Dashboard를 쓴다. 최종 브랜드명은 01_PRD 8장 열린 결정이다.

## 1. 한 줄 정의

본인이 직접 연결한 증권사 계좌(1차는 모의투자 계좌)의 잔고, 보유 종목, 체결 내역을 한 화면에서 조회하고, AI가 포트폴리오의 분산과 위험 요인을 "진단"해 주는 초대제 개인 투자 대시보드다. 종목을 추천하거나 매수가, 목표가, 손절가를 제시하지 않는다.

| 대상 사용자 | 설명 | 근거 |
|---|---|---|
| 1차(베타) | 운영자가 초대한 개인 투자자 30명 안팎(제안). 자기 계좌만 연결한다 | `docs/reviews/Stock_Trader_nomad.md:101`, `:61` |
| 원본 기획의 대상 | FOMO를 겪는 초보 투자자, 여러 증권사에 자산이 흩어진 투자자 | `구현해야 할 프로젝트/Stock_Trader_nomad/PRD.md:6-8` |

## 2. 통합 근거

| 항목 | 내용 | 근거 |
|---|---|---|
| 통합 여부 | 단독 제품. 다른 그룹과 합치지 않는다 | `docs/products/00_MERGE_ANALYSIS.md:1290`, `docs/products/README.md:22` |
| 베이스 | 원본에 코드가 없다. `_platform-core`(인증, 조직, 크레딧, Toss, 자격증명, 잡, 감사) 위에 새로 만든다 | `docs/reviews/Stock_Trader_nomad.md:3`, `docs/products/00_MERGE_ANALYSIS.md:1342` |
| 재사용 | Group F 코어의 KpiCard, 차트, AppShell 패턴 | `docs/products/00_MERGE_ANALYSIS.md:1290`, `docs/reviews/Stock_Trader_nomad.md:94` |
| 확정 결정 적용 | 4(Toss 단일 PG, Phase 2 유료 플랜), 5(org 기준 스키마, 1인 1워크스페이스) | `docs/products/00_MERGE_ANALYSIS.md:12-13` |
| 확정 결정 해당 없음 | 1~3, 6~12는 다른 제품 대상이다. 7(MVP 범위)과 8(플랜 정본)에 stock 항목이 없어 범위와 요금은 이 폴더 01_PRD가 정본이다 | `docs/products/00_MERGE_ANALYSIS.md:15-16` |
| 범위 축소 원칙 | 리뷰 4.4 MVP 축소안과 분석 표의 "디벨롭" 처리(증권사 1곳, 모의 계좌, AI 1개로 진단만)를 따른다 | `docs/reviews/Stock_Trader_nomad.md:101-102`, `docs/products/00_MERGE_ANALYSIS.md:1276-1278` |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `구현해야 할 프로젝트/Stock_Trader_nomad` (`PRD.md` 61행, `claude.md` 32행, 코드 없음) | `docs/reviews/Stock_Trader_nomad.md` | 약 20%(기획만) | 화면 구성(증권사/Total 탭, 보유 그리드 블링크, 종목 상세 모달과 재무지표 5종, AI 패널 위치), 매매 일지 동기화(조회 전용), 리더보드 개념(내부용, 규칙 고정) | 스크래핑, 공개 GEO/JSON-LD, 모델명 하드코딩, Context로 시세 관리, 종목별 매수가/목표가/손절가 추천(MVP), 실존 종목 극단 수익률 목업의 무표시 노출 |

세부 분류는 `07_SOURCE_MIGRATION.md`에 있다.

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구와 수용 기준, 요금/크레딧, 비기능 수치, 금융 규제와 금지 문구, KPI, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 공용 모듈 사용, 잡/워커(동기화, 시세 중계), AI 라우팅, 기술 리스크 차단 설계(리뷰 #5, #6), 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 플로우(초대 → 가입 → 첫 연결 → 첫 진단, 결제), 화면별 명세, 초대 랜딩 디자인 방향, 상태/오류 |
| `04_API.md` | Route Handler, 제품 RPC, 잡 페이로드, 웹훅, 증권사/DART/LLM 어댑터, 오류 코드 |
| `05_DATA_MODEL.md` | 테이블 19개, 상태 전이, RLS, 인덱스, 보안·데이터 차단 설계(리뷰 #1~#4), 모놀리스/모듈러 차이, RLS 스모크 결과 |
| `06_AGENT_PLAN.md` | 작업 34개, 웨이브, 모델 비율, 리뷰 5장 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본 자산 분류, 폐기 목록, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 마이그레이션 3개(`0001_core_lite`, `0002_stock_domain`, `0003_stock_orders_paper`)와 `seed.sql` |
| `../_supabase-modular/migrations/1900_stock.sql` | 같은 도메인 모델의 모듈러 조각 |

## 5. DB 구조 선택

| 항목 | 결정 | 근거 |
|---|---|---|
| 1차(출시) | 모놀리스. 이 제품 전용 Supabase 프로젝트, 스키마 `public`(`MONOLITH_CORE_LITE.sql` 규칙). `public` 스키마 사용은 사용자 최종 확인 대기 | `docs/products/_supabase-modular/ARCHITECTURE.md:43`, `:75`, `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:6-10` |
| 이유 | 증권사 키와 계좌 데이터의 격리, 법률 검토 전 단계, 다른 제품의 코어 결함이나 장애가 금융 데이터에 닿지 않게 하기 위해 | `docs/products/_supabase-modular/ARCHITECTURE.md:16`, `:19` |
| 모듈러 조각 | `1900_stock.sql`을 유지해 같은 도메인 모델이 통합 DB에서도 동작함을 검증한다(체커 OK, RLS 스모크 75/75). 재검토 시점은 법률 검토 완료와 Phase 2 결정 이후 | `docs/products/_supabase-modular/ARCHITECTURE.md:43` "재검토" |
| 이동 절차 | 모놀리스 → 모듈러는 `ARCHITECTURE.md` 4.1절 | `docs/products/_supabase-modular/ARCHITECTURE.md:50-59` |
