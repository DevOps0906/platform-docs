# Price_Plans — 플랫폼 가격 플랜

작성일 2026-10-14. 모든 플랫폼(제품 SaaS 14개와 서비스 사업)의 가격 플랜을 한곳에서 관리하는 폴더입니다.
공용 방법(`_common/`)으로 가격을 정하고, 플랫폼마다 폴더 하나에 단계별(초기·중기·장기) 가격 계획을 둡니다.

## 1. 폴더 구조

```
Price_Plans/
├── README.md                      이 문서(인덱스, 상태, 규칙)
├── _common/                       모든 플랫폼 공용 방법
│   ├── PRICING_PRINCIPLES.md      가격 결정 원칙·절차·공식·판매 모델·단계 정의
│   ├── COST_BASELINE.md           공용 인프라 원가(호스팅, DB, 빌더) 확인일 포함
│   └── PRICE_PLAN_TEMPLATE.md     플랫폼별 PRICE_PLAN.md 장 구조
├── Web-App-Agency/                서비스 사업: 웹/앱 에이전시 + 네이버 블로그 스킨
│   ├── README.md
│   ├── PRICE_PLAN.md              가격 플랜 본문(초기·중기·장기)
│   ├── 01_MARKET_BENCHMARK.md     시장 단가, 벤치마크 모델
│   ├── 02_SERVICE_CATALOG.md      상품 등급, 기술, 제작기간, AI 에이전트 배치
│   ├── 03_HOSTING_DATA.md         호스팅 선택, DB·리드 저장 방식
│   ├── 04_OPERATIONS.md           계약·견적·범위·결제·납품 운영
│   └── 05_ROADMAP.md              실행 순서, KPI, 열린 결정
└── <제품>/PRICE_PLAN.md           제품 SaaS 14개(products/ 폴더와 같은 이름)
```

요청한 폴더 이름은 "Web/App Agency"였지만 경로 구분자 `/`를 폴더 이름에 쓸 수 없어 `Web-App-Agency`로 만들었습니다.

## 2. 플랫폼 목록과 상태

| 플랫폼 | 유형 | 가격 플랜 | 상태 | 현재 요금 정본 |
|---|---|---|---|---|
| Web-App-Agency | 서비스(대행) | [`Web-App-Agency/PRICE_PLAN.md`](Web-App-Agency/PRICE_PLAN.md) | 초안 | 이 폴더가 정본(제품 DB 없음) |
| admin-suite | 제품 SaaS | [`admin-suite/PRICE_PLAN.md`](admin-suite/PRICE_PLAN.md) | 초안 | `products/admin-suite/01_PRD.md` 4장 |
| astro-ai | 제품 SaaS | [`astro-ai/PRICE_PLAN.md`](astro-ai/PRICE_PLAN.md) | 초안 | `products/astro-ai/01_PRD.md` 4장 |
| flora-publishing | 제품 SaaS | [`flora-publishing/PRICE_PLAN.md`](flora-publishing/PRICE_PLAN.md) | 초안 | `products/flora-publishing/01_PRD.md` 4장 |
| live-poll | 제품 SaaS | [`live-poll/PRICE_PLAN.md`](live-poll/PRICE_PLAN.md) | 초안 | `products/live-poll/01_PRD.md` 4장 |
| local-news | 제품 SaaS(멀티테넌트) | [`local-news/PRICE_PLAN.md`](local-news/PRICE_PLAN.md) | 초안 | `products/local-news/01_PRD.md` 4장 |
| microweb-studio | 제품 SaaS + 대행 | [`microweb-studio/PRICE_PLAN.md`](microweb-studio/PRICE_PLAN.md) | 초안 | `products/microweb-studio/01_PRD.md` 4장 |
| nomad-blog | 제품 SaaS | [`nomad-blog/PRICE_PLAN.md`](nomad-blog/PRICE_PLAN.md) | 초안 | `products/nomad-blog/01_PRD.md` 4장 |
| nomad-commerce | 제품 SaaS | [`nomad-commerce/PRICE_PLAN.md`](nomad-commerce/PRICE_PLAN.md) | 초안 | `products/nomad-commerce/01_PRD.md` 4장 |
| nomad-docs | 제품 SaaS | [`nomad-docs/PRICE_PLAN.md`](nomad-docs/PRICE_PLAN.md) | 초안 | `products/nomad-docs/01_PRD.md` 4장 |
| nomad-video | 제품 SaaS + 대행 | [`nomad-video/PRICE_PLAN.md`](nomad-video/PRICE_PLAN.md) | 초안 | `products/nomad-video/01_PRD.md` 4장 |
| stock-dashboard | 제품 SaaS | [`stock-dashboard/PRICE_PLAN.md`](stock-dashboard/PRICE_PLAN.md) | 초안 | `products/stock-dashboard/01_PRD.md` 4장 |
| study-note | 제품 SaaS | [`study-note/PRICE_PLAN.md`](study-note/PRICE_PLAN.md) | 초안 | `products/study-note/01_PRD.md` 4장 |
| toon-factory | 제품 SaaS | [`toon-factory/PRICE_PLAN.md`](toon-factory/PRICE_PLAN.md) | 초안 | `products/toon-factory/01_PRD.md` 4장 |
| website-floria | 마케팅 사이트 | [`website-floria/PRICE_PLAN.md`](website-floria/PRICE_PLAN.md) | 해당 없음(요금 없음) | `products/website-floria/01_PRD.md` 4장 |

상태 값: 미작성 / 초안 / 검토 / 확정. 확정이 되면 아래 3장의 정본 반영 절차를 밟습니다.

## 3. 규칙

| 규칙 | 내용 |
|---|---|
| 정본 관계 | 제품 SaaS의 플랜 코드·가격·크레딧 정본은 지금처럼 각 제품 `01_PRD.md` 4장과 `seed.sql`이다(확정 결정 8, `products/00_MERGE_ANALYSIS.md:16`). 이 폴더는 그 위의 전략(단계별 계획, 원가, 경쟁 가격, 판매 모델)을 담는다 |
| 정본 반영 | 이 폴더에서 가격을 "확정"으로 바꾸면 해당 제품 `01_PRD.md` 4장과 seed를 고치는 task를 따로 만든다. 이 폴더만 고치고 PRD를 그대로 두지 않는다 |
| 서비스 사업 | 제품 DB가 없는 서비스 사업(Web-App-Agency 등)은 이 폴더의 `PRICE_PLAN.md`가 정본이다 |
| 공용 방법 | 새 플랫폼은 `_common/PRICE_PLAN_TEMPLATE.md` 장 구조를 그대로 쓴다. 공용 원칙을 바꾸려면 `_common/`을 먼저 고친다 |
| 표기 | 저장소 공통 표기법(`products/_platform-core/DOC_TEMPLATE.md` 0장)을 따른다. 한국어, Markdown 표, 근거 없는 수치는 "제안", 확인하지 않은 외부 사실은 "미확인" |
| 외부 가격 | 외부 서비스 가격은 확인일과 출처 URL을 함께 적고, 분기마다 `_common/COST_BASELINE.md`를 다시 확인한다 |
| 변경 방법 | 저장소 규칙대로 브랜치 → PR → main 병합 |

## 4. 읽는 순서

1. `_common/PRICING_PRINCIPLES.md`(공용 방법) → `_common/COST_BASELINE.md`(원가)
2. 플랫폼 폴더의 `PRICE_PLAN.md`
3. 서비스 사업은 `README.md`의 문서 목록 순서대로(시장 → 상품 → 가격 → 호스팅·데이터 → 운영 → 로드맵)
