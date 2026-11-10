# 09 DIAGRAMS: BM-Core

> 모든 수치는 예시(제안)이며 실제 데이터로 교체한다. 다이어그램은 Mermaid 텍스트로 관리하고 렌더링은 도구가 한다.

## 00 도구 분담

| 도구 | 담당 | 이유 |
|---|---|---|
| Mermaid | 01~16 (16종 전부) | 구조·흐름·시퀀스·상태·ERD·일정·점수 분포·비율·퍼널·사분면 등 정적 도식. 문서·PR에 코드 그대로 포함 |
| Recharts | 대시보드 경제성 차트(BEP·LTV·CAC·매출 전망 실측 값), Waterfall·Funnel | 값이 계산 결과에 따라 바뀌고 화면 인터랙션이 필요 |
| React Flow | 인터랙티브 BM 캔버스 | 노드 편집·드래그 등 사용자 조작 |

원칙: Mermaid 문자열을 직접 관리하지 않고, Postgres 정규화 데이터를 정본으로 Mermaid 코드를 생성한다(Diagram Engine). React Flow·PDF·AI 문서가 같은 데이터를 재사용한다. 본 문서의 코드는 현재 수기 작성본이며, 정본 데이터 연결 후 생성 방식으로 대체한다.

## 01 전체 비즈니스 운영 구조

아이디어부터 사업계획서 생성까지 전체 흐름과 스코어 기준 분기(80점·60~79점·40~59점·40점 미만, 예시 제안).

```mermaid
flowchart TD
    I["아이디어"] --> W["Wizard 7단계 입력"]
    W --> DB[("정규화 데이터 저장<br/>Postgres")]
    DB --> E["계산 엔진<br/>결정론적 계산"]
    DB --> L["린 검증 실험"]
    DB --> AI["AI 분석 제안"]
    E --> SC["스코어카드"]
    L --> SC
    AI --> SC
    SC --> J{"평가 점수"}
    J -->|"80점 이상"| M1["MVP 투자 검토"]
    J -->|"60~79점"| M2["추가 검증"]
    J -->|"40~59점"| M3["범위 축소"]
    J -->|"40점 미만"| M4["재검토"]
    M1 --> R["사업계획서 생성"]
    M2 --> R
    M3 --> R
    M4 --> R
```

## 02 Wizard 사용자 여정

Wizard 1~7단계를 거쳐 분석 대시보드에 도달하는 순서.

```mermaid
flowchart LR
    S1["1 고객"] --> S2["2 가치"] --> S3["3 가격"] --> S4["4 경제성"] --> S5["5 사업 파트"] --> S6["6 린 검증"] --> S7["7 평가"] --> D["분석 대시보드"]
```

## 03 기술 아키텍처

Frontend, Application, Infra 세 계층과 각 구성 요소, 비동기 작업 경로.

```mermaid
flowchart LR
    subgraph FE["Frontend"]
        NX["Next.js·shadcn/ui"]
        CH["Mermaid + Recharts"]
    end
    subgraph APP["Application"]
        BM["BM Service"]
        CE["Calculation Engine"]
        VS["Validation Service"]
        AO["AI Orchestrator"]
        RS["Report Service"]
    end
    subgraph INF["Infra"]
        PG[("PostgreSQL")]
        AU["Auth"]
        ST["Storage"]
        BW["Background Worker"]
    end
    NX --> BM
    CH --> BM
    BM --> CE
    BM --> VS
    BM --> AO
    BM --> RS
    BM --> PG
    BM --> AU
    AO --> BW
    RS --> BW
    RS --> ST
```

## 04 ERD (개념 모델)

팀장 요소 목록 기반 개념 ERD(수기 작성). 마이그레이션 확정 후 `sql2erd`로 재생성하여 대체한다.

```mermaid
erDiagram
    ORGANIZATION ||--o{ PROJECT : owns
    PROJECT ||--o{ PROJECT_VERSION : versions
    PROJECT_VERSION ||--o{ BUSINESS_PART : has
    BUSINESS_PART ||--o{ PRICING_PLAN : offers
    BUSINESS_PART ||--o{ COST_ITEM : incurs
    PROJECT_VERSION ||--o{ ASSUMPTION : defines
    PROJECT_VERSION ||--o{ SCENARIO : models
    SCENARIO ||--o{ CALCULATION_RUN : produces
    PROJECT_VERSION ||--o{ HYPOTHESIS : tests
    HYPOTHESIS ||--o{ EXPERIMENT : validates
    EXPERIMENT ||--o{ EVIDENCE : produces
    PROJECT_VERSION ||--o{ SCORECARD : evaluates
    PROJECT_VERSION ||--o{ REPORT : exports
```

## 05 AI 분석 시퀀스

Wizard 저장 경로와 AI 분석 요청부터 승인·저장에 이르는 흐름.

```mermaid
sequenceDiagram
    participant U as 사용자
    participant W as Wizard
    participant API as API
    participant DB as PostgreSQL
    participant AO as AI Orchestrator
    participant CE as 계산 엔진
    U->>W: 단계 입력
    W->>API: PUT /versions/:id/wizard/:step
    API->>DB: 버전 저장
    DB-->>API: 저장 완료
    API-->>W: 저장 결과
    U->>W: AI 분석 요청
    W->>API: POST /ai/suggestions
    API->>DB: 작업 생성
    API->>AO: 분석 요청
    AO->>DB: 데이터 조회
    AO->>CE: 계산 요청
    CE-->>AO: 계산 결과
    AO-->>API: 제안(suggested)
    API-->>W: 검증된 제안 표시
    U->>W: 승인 또는 거절
    alt 승인
        W->>API: 제안 반영 요청
        API->>DB: 새 버전 저장
    else 거절
        W->>API: 제안 폐기
    end
```

## 06 린 검증 의사결정 트리

검증 단계별 통과 기준(예시 제안)을 확인하고, 미달 시 문제 재정의·가치 제안 개선·가격 검증으로 분기.

```mermaid
flowchart TD
    Q1{"인터뷰 20명<br/>문제 공감 70% 이상?"} -->|"예"| Q2{"랜딩 사전예약<br/>전환 5% 이상?"}
    Q1 -->|"아니오"| R1["문제 재정의"]
    Q2 -->|"예"| Q3{"노코드 데모<br/>유료 의향 10명 이상?"}
    Q2 -->|"아니오"| R2["가치 제안 개선"]
    Q3 -->|"예"| Q4{"첫 매출<br/>결제 5건 이상?"}
    Q3 -->|"아니오"| R3["가격 검증"]
    Q4 -->|"예"| MVP["유료 MVP 개발"]
    Q4 -->|"아니오"| R3
```

## 07 사업성 점수 분포

5개 축의 점수 분포(만점 20점 기준, 예시 제안).

```mermaid
xychart-beta
    title "사업성 점수 분포 (예시 제안)"
    x-axis ["시장성", "수익성", "검증도", "실행가능성", "확장성"]
    y-axis "점수" 0 --> 20
    bar [14, 16, 4, 17, 16]
```

## 08 평가 상태 전이

평가 상태 값(영문 enum 이름)과 전이 조건. 80점 이상이면서 필수 조건을 충족해야 Ready가 된다(예시 제안).

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Validating
    Validating --> Scored
    Scored --> OnHold: blocking 조건 있음(점수 무관)
    Scored --> Ready: 80점 이상, blocking 없음
    Scored --> NeedsValidation: 60~79점
    Scored --> Redesign: 40~59점
    Scored --> OnHold: 40점 미만
    Ready --> Approved: 승인
    Ready --> OnHold: 보류
    NeedsValidation --> Draft: 재평가
    Redesign --> Draft: 재평가
    OnHold --> Draft: 재평가
    Approved --> [*]
```

## 09 개발 로드맵 Gantt

12주 개발 일정. 시작일은 예시이며 1~2주 검증·설계부터 12주 결제·계측·운영까지 구간별로 나눈다.

```mermaid
gantt
    title BM-Core 12주 로드맵 (시작일 예시)
    dateFormat YYYY-MM-DD
    section 설계·검증
    시장 검증·설계 (1~2주) :s1, 2026-11-16, 14d
    section 핵심 기능
    인증·조직·프로젝트·Wizard (3~4주) :s2, 2026-11-30, 14d
    계산·시나리오·검증·스코어 (5~7주) :s3, 2026-12-14, 21d
    section 출시 준비
    PDF·AI 제안·작업 큐 (8~9주) :s4, 2027-01-04, 14d
    보안·E2E·베타 (10~11주) :s5, 2027-01-18, 14d
    결제·계측·운영 (12주) :s6, 2027-02-01, 7d
```

## 10 수익 흐름 Sankey

월 매출이 변동비·공헌이익으로 나뉘고, 공헌이익이 고정비와 영업이익으로 배분되는 흐름(만원/월, 예시 제안).
노드 대응: Revenue=총매출, Variable cost=변동비, Contribution=공헌이익, Fixed cost=고정비, Operating profit=영업이익 (Mermaid sankey 파서가 한글 노드명을 받지 않아 영문 표기).

```mermaid
sankey-beta
Revenue,Variable cost,230
Revenue,Contribution,370
Contribution,Fixed cost,250
Contribution,Operating profit,120
```

## 11 고객 유입 퍼널

방문에서 첫 달 활성까지의 전환 단계(전환율은 예시 제안).

```mermaid
flowchart TD
    A["방문 2,000명"] -->|"전환 5%"| B["사전예약 100명"]
    B -->|"전환 20%"| C["유료 전환 20명"]
    C --> D["첫 달 활성"]
```

## 12 멀티테넌트 구조

조직별로 프로젝트와 BM 버전이 분리되고, Supabase Auth와 RLS로 조직 간 접근을 차단하는 구조.

```mermaid
flowchart LR
    AUTH["Supabase Auth"] --> RLS{"RLS 정책"}
    subgraph ORG_A["조직 A"]
        PA["프로젝트"] --> VA["BM Version"]
    end
    subgraph ORG_B["조직 B"]
        PB["프로젝트"] --> VB["BM Version"]
    end
    subgraph ORG_C["조직 C"]
        PC["프로젝트"] --> VC["BM Version"]
    end
    RLS -->|"조직 A 데이터만"| PA
    RLS -->|"조직 B 데이터만"| PB
    RLS -->|"조직 C 데이터만"| PC
```

## 13 사업 아이템 우선순위

수익성과 실행가능성 기준으로 사업 아이템 4개를 배치한 사분면(좌표는 예시 제안).

```mermaid
quadrantChart
    title 사업 아이템 우선순위 (좌표는 예시 제안)
    x-axis 낮은 실행가능성 --> 높은 실행가능성
    y-axis 낮은 수익성 --> 높은 수익성
    quadrant-1 "우선 추진"
    quadrant-2 "수익성 높고 실행 어려움"
    quadrant-3 "보류"
    quadrant-4 "실행 쉬움, 수익 낮음"
    BM-Core: [0.8, 0.8]
    BookForge: [0.7, 0.6]
    AI-CAD: [0.3, 0.7]
    Content-AI: [0.5, 0.3]
```

## 14 매출 성장 시나리오

1~6월 MRR 추이의 기준 시나리오(첫 번째 선)와 낙관 시나리오(두 번째 선). 6월 기준 값 262만원은 PRD의 MRR 시뮬레이션과 맞춘 값이고, 나머지 월별 값은 예시 제안이다.

```mermaid
xychart-beta
    title "매출 성장 시나리오 MRR (만원, 예시 제안)"
    x-axis ["1월", "2월", "3월", "4월", "5월", "6월"]
    y-axis "MRR (만원)" 0 --> 400
    line [30, 60, 100, 150, 200, 262]
    line [40, 85, 140, 210, 280, 350]
```

## 15 비용 구성

월 비용의 항목별 비율(%, 예시 제안).

```mermaid
pie showData
    title 비용 구성 (%, 예시 제안)
    "AI API" : 30
    "인프라" : 20
    "마케팅" : 25
    "고객지원" : 15
    "기타" : 10
```

## 16 기능 개발 우선순위

사업 가치와 구현 난이도 기준으로 주요 기능을 배치한 사분면(좌표는 예시 제안).

```mermaid
quadrantChart
    title 기능 개발 우선순위 (좌표는 예시 제안)
    x-axis 낮은 난이도 --> 높은 난이도
    y-axis 낮은 사업 가치 --> 높은 사업 가치
    quadrant-1 "가치 높음, 난이도 높음"
    quadrant-2 "가치 높음, 난이도 낮음 우선"
    quadrant-3 "가치 낮음, 난이도 낮음"
    quadrant-4 "가치 낮음, 난이도 높음 보류"
    Wizard: [0.3, 0.9]
    Economics: [0.4, 0.85]
    Scorecard: [0.35, 0.7]
    AI-Agent: [0.8, 0.6]
    PDF-Export: [0.5, 0.5]
    B2B-API: [0.9, 0.35]
```
