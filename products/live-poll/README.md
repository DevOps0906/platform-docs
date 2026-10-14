# Live Poll (live-poll)

## 1. 한 줄 정의

강연자, 행사 진행자, 방송인이 행사(방)를 만들면 청중이 로그인 없이 6자리 코드나 QR로 들어와 투표하고 질문하며, 결과가 발표 화면과 OBS 오버레이에 실시간으로 반영되는 웹 서비스다. 2026-10-13부터 진행자용 AI 어시스턴트(행사 자료·과거 Q&A 근거), Q&A AI 정리(분류·군집·요약), 행사 위키, 음성(진행자 음성 대화, 청중 음성 질문, 요약 읽어 주기), 3D 히어로가 MVP에 들어간다(확정 결정 13~17). 청중 원문(질문, 음성)은 항상 국내 오픈소스 모델로만 처리하고, 청중에게는 AI 채팅을 제공하지 않는다.

| 대상 | 상황 |
|---|---|
| 진행자(호스트) | 강연, 사내 타운홀, 세미나, 라이브 방송. 노트북으로 진행자 콘솔과 발표 화면을 띄운다 |
| 청중(참가자) | 행사장 휴대폰, 방송 시청자. 가입 없이 코드로 입장한다 |

제품명 "Slido"는 상용 서비스 상표라서 쓰지 않는다(`docs/reviews/Slido_Project.md:50`). 작업명은 seed의 앱 이름 "Live Poll"(`docs/products/_supabase-modular/seed.sql:21`)이고, 최종 브랜드명은 01장 8절의 열린 결정이다.

## 2. 통합 근거

단독 제품이다. 합칠 원본이 없다(`docs/products/README.md:20`). 분석은 다른 그룹과의 연결이 약하니 단독으로 유지하라고 권했다(`docs/products/00_MERGE_ANALYSIS.md:1269`).

| 근거 | 내용 |
|---|---|
| 베이스 | 원본은 기획 문서 2개(PRD 35줄, CLAUDE 22줄)뿐이고 코드가 없다(`docs/reviews/Slido_Project.md:3`). `_platform-core`가 출발점이다(`docs/products/00_MERGE_ANALYSIS.md:1342`) |
| 확정 결정 4 | 결제 PG는 Toss. 베타 기간에는 무료만 열고 유료 플랜은 Phase 2에 연다 |
| 확정 결정 5 | org 기준 스키마, 운영은 1인 1워크스페이스. 진행자는 개인 조직으로 쓴다 |
| 분석 처리표 | 유지 2, 디벨롭 3, 폐기 3, 신규 1묶음(`docs/products/00_MERGE_ANALYSIS.md:1252-1262`) |
| 기획 공백 | 원본 기획은 약 35%만 채워져 있다(`docs/reviews/Slido_Project.md:19`). 실시간 구조, 코드 입장, 중복 투표, 레이트 리밋, 발표 화면, 모더레이션, Q&A를 01~05장에서 새로 정했다 |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `구현해야 할 프로젝트/Slido_Project/` (PRD.md, CLAUDE.md) | `docs/reviews/Slido_Project.md` | 기획 약 35%, 코드 없음 | 호스트/참가자 플로우, 대기/시작/종료 제어, OBS 모드, 무새로고침 전환, 폴링 금지, 훅/UI 분리, 재연결 명시 원칙 | Socket.io/FastAPI 스택 후보, Redis 집계(2단계 보류), 방 페이지 GEO, IP 기반 하드 1인 1표, IP 해시 영구 저장 |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구사항(LP-F-001~037)과 수용 기준, 플랜과 AI·음성 크레딧 단가, 비기능 수치, 법/개인정보(AI·음성 고지 포함), KPI, 열린 결정(D1~D18) |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계, 실시간 구조(브로드캐스터 워커 + private Broadcast), AI 라우팅 기본값과 그래프 `poll.qna_assist`, 청중 음성 질문 경로, 리뷰 높음 #1, #2 차단 설계 |
| `03_SCREENS_UX.md` | 화면 목록, 플로우, 진행자 콘솔/발표 화면/오버레이/청중 화면 명세, AI 패널·음성·위키 화면, 디자인 시스템, 랜딩 디자인 방향과 3D 히어로 |
| `04_API.md` | Route Handler(AI·음성 포함), RPC, 브로드캐스트 메시지 계약, FastAPI·Dify 계약, 오류 코드(PL###, AI·음성 코드) |
| `05_DATA_MODEL.md` | 테이블 9개(제품 전용 AI 표 없음과 그 이유), 상태 전이, RLS, 리뷰 높음 #3, #4 차단 설계, 모놀리스와 모듈러의 차이 |
| `06_AGENT_PLAN.md` | 작업 51개(AI·음성·3D·디자인 시스템 16개, 인증 단계 B·C 3개 포함, LP-06-###), 웨이브, 모델 비율, 리뷰 작업 흡수표, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본 자산 분류, 폐기 목록, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/migrations/0001_core_lite.sql` | `MONOLITH_CORE_LITE.sql` 사본. SECTION 6-A, 6-B, 9를 이유 주석과 함께 지웠다(4, 7, 8은 AI 계층 때문에 복원) |
| `supabase/monolith/migrations/0002_poll_domain.sql` | 모듈러 조각 `1800_poll.sql`을 public 스키마로 변환한 것 |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 3개(free만 활성, AI 키와 크레딧 포함), AI 라우팅 기본값 12행 |
| `../_supabase-modular/migrations/1800_poll.sql` | 모듈러 `poll` 스키마 조각(정본) |

## 5. DB 구조 선택

| 단계 | 구조 | 이유 |
|---|---|---|
| 출시(베타) | 모듈러(`poll` 스키마). 같은 DB에 코어 AI·음성 객체(`0008`, `0009`)가 있다 | 계정과 조직을 다른 제품과 공유하고 코어 보안 코드를 한 번만 유지한다(`docs/products/_supabase-modular/ARCHITECTURE.md:74`) |
| 트래픽이 늘면 | 모놀리스로 분리 검토 | Realtime 채널 부하가 다른 제품에 영향을 줄 수 있다(`docs/products/_supabase-modular/ARCHITECTURE.md:40`). 이동 절차는 같은 문서 4.2절. 모놀리스 SQL은 `supabase/monolith/`에 미리 두었고 체커를 통과했다 |

모놀리스 스키마는 `public`이다(`MONOLITH_CORE_LITE.sql` 머리말). 최종 확인은 사용자 결정으로 남긴다(05장 8절).
