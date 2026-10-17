# 설득형 랜딩 템플릿 (제품별 개별 파일)

`LANDING_PERSUASION.md`의 7칸 구조(히어로, 막히는 지점, 원인, 방식, 왜 이 플랫폼인가, 비용 비교, 행동)를 NOMAD 랜딩 키트의 화면 구조로 그린 템플릿이다. 제품마다 데이터 파일 1개와 결과 페이지 1개가 따로 있다. 제품끼리 합치지 않는다.

## 1. 구성

| 경로 | 역할 |
|---|---|
| `engine.html` | 공통 엔진. 화면 7개(설득형 메인, 왜 이 플랫폼인가, 주장 장부, 도입 단계, 비교 계산기, 인사이트, 템플릿 사용법)와 움직임을 그린다 |
| `data/<제품>.json` | 제품 데이터. 작성 규칙은 `DATA_BRIEF.md` |
| `build.py` | JSON 1개를 엔진에 넣어 `dist/<제품>.html`을 만든다. 계산기 식은 이때 함수로 바꿔 넣는다 |
| `dist/<제품>.html` | 제품 전용 결과 페이지. 외부 의존은 Google Fonts뿐이다 |

```
python3 build.py              # data/ 아래 전부
python3 build.py nomad-docs   # 한 제품만
```

## 2. 움직임

| 위치 | 움직임 |
|---|---|
| 히어로 | 대상 칩 → 대형 글자 → 문장 → CTA 카드 순서로 등장. 대상 칩을 하나씩 밝히는 순환, CTA 문구 타이핑, 공식 칸 순차 강조, CTA 카드 포인터 기울기 |
| 처리 흐름 | 단계 레일과 이중 타임라인이 같은 단계를 함께 켠다. 멈춤 버튼 있음 |
| 원인 비교 | 기존 방식 문장에 줄이 그어지고 제품 방식 문장이 체크 표시와 함께 들어온다 |
| 판정표 | ○△✕가 행 순서로 나타나고 우리 열에 빛이 지나간다. 정직성 점검 막대가 찬다 |
| 숫자 | 비용 비교 막대와 차이 금액, 도입 단계 가격이 이전 값에서 새 값으로 움직인다 |
| 탭 | 페르소나·도입 단계 탭의 밑줄이 미끄러지고 내용이 교차해 바뀐다 |
| 스크롤 | 화면 아래에 있던 블록만 보일 때 올라온다. 위쪽 진행 막대 |
| 배경 | 제품 강조색 빛이 천천히 떠다니고 포인터 주변이 밝아진다 |

모든 움직임은 `prefers-reduced-motion: no-preference`일 때만 켠다. 동작 줄이기를 켜면 전부 멈추고 같은 내용이 그대로 보인다.

## 3. 결과 페이지

| 제품 | 데이터 | 아티팩트 | 비고 |
|---|---|---|---|
| FLORA Publishing | `data/flora-publishing.json` | https://claude.ai/artifact/TDJKm4WRe5UpZgGPAzJJEz | 적용 제품. 인사이트 3편 |
| NOMAD Docs | `data/nomad-docs.json` | https://claude.ai/artifact/7wmQx9WRp7gv8va5SzdVbE | 적용 제품. 인사이트 3편 |
| Arch Studio | `data/arch-studio.json` | https://claude.ai/artifact/XyiMhEA8jTMeZtRVNB1bcz | 적용 제품 |
| Admin Suite | `data/admin-suite.json` | https://claude.ai/artifact/3YhN17Q6N4ZMdyKbYYj59o | 후보(도입 영업용) |
| 로컬뉴스 클라우드(가칭) | `data/local-news.json` | https://claude.ai/artifact/BDxY1ozLxGjzKiNkBxTxq8 | 후보(신문사 도입 문의) |
| 신비로운AI | `data/astro-ai.json` | https://claude.ai/artifact/6kvpVjTAaRpfizGPkcy9ZB | 초안 |
| NOMAD Book Trailer | `data/book-trailer.json` | https://claude.ai/artifact/9W8yjfiZaEWbYcXegvBC1p | 초안 |
| Live Poll | `data/live-poll.json` | https://claude.ai/artifact/7HCW985QggQp4LyXt8dJj8 | 초안 |
| Microweb Studio | `data/microweb-studio.json` | https://claude.ai/artifact/WrcyWVYevBUz6548oGsdYg | 초안 |
| NOMAD Blog | `data/nomad-blog.json` | https://claude.ai/artifact/HPwZqWQQt56wkkJDcRxYwy | 초안 |
| NOMAD Commerce | `data/nomad-commerce.json` | https://claude.ai/artifact/TRMuXutU8yv2XQsFMfqPLW | 초안 |
| NOMAD AI Factory | `data/nomad-video.json` | https://claude.ai/artifact/2CCz973ubHfNNWj7pa3pJS | 초안 |
| Stock Dashboard | `data/stock-dashboard.json` | https://claude.ai/artifact/BNX3jaG1YFXPU4JJ9gSpqG | 초안 |
| Study Note | `data/study-note.json` | https://claude.ai/artifact/LFcA1dbwBxGMcTN2BbkMqb | 초안 |
| Toon Factory | `data/toon-factory.json` | https://claude.ai/artifact/UtbXomcD5ztzL3UDeAfbF5 | 초안 |
| Floria | `data/website-floria.json` | https://claude.ai/artifact/341xPb933t11DYW3cL6sHo | 초안 |

"초안"은 `LANDING_PERSUASION.md` 8장에서 적합도 낮음으로 둔 제품이다. 즉시 가입형이라 긴 논증 랜딩이 첫 행동을 늦출 수 있으므로, 실제 랜딩에는 판정표 한 칸이나 비교 계산기처럼 일부만 골라 쓰는 것을 먼저 검토한다(제안). 아티팩트 링크는 소유자 전용이며 공유는 각 페이지의 공유 메뉴에서 한다.

## 4. 데이터 점검 기준

| 항목 | 기준 |
|---|---|
| 페르소나 | 3명의 `id`와 `scene`이 장부 앞 3행과 같다 |
| 판정표 | 우리 열에 △·✕가 1개 이상, 우리 열 ○에는 증거 ID가 있다 |
| 장부 상태 | `draft`·`hold`만 쓴다. `ok`는 검증 뒤에 바꾼다 |
| 아이콘 | `DATA_BRIEF.md`의 아이콘 목록 안에서만 고른다 |
| 계산기 | 기본값으로 계산한 비용이 모두 숫자다. 제품 쪽 가격·크레딧은 제품 01장 4장 값 |
| 가격 | 기획 문서의 제안값이다. 01장 4장이 바뀌면 JSON을 고치고 다시 빌드한다 |
