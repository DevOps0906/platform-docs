# 설득형 랜딩 템플릿 (제품별 개별 파일)

## 0. 공통 템플릿에서 시작한다

모든 제품 랜딩은 공통 템플릿 하나에서 만든다. 공통 템플릿은 엔진(`engine.html`)과 기본 구매 여정, 채울 자리를 표시한 데이터(`data/_common.json`)로 이루어진다. 결과 페이지: https://claude.ai/artifact/4Tyhp5nsHVZtjBgRZMBKTf

| 순서 | 할 일 |
|---|---|
| 1 | `data/_common.json`을 `data/<제품>.json`으로 복사하고 `key`를 폴더명으로 바꾼다 |
| 2 | 기획 문서(01장 1·3·4·6장, 03장, `Price_Plans/<제품>/PRICE_PLAN.md` 4장)로 [ ] 자리를 채운다 |
| 3 | `journey`에 "<제품> ○○ 여정" 이름과 단계·하위 페이지를 개발 요건에 맞게 적는다(`DATA_BRIEF.md` 3판) |
| 4 | `node validate.js`가 `ALL OK`인지 확인한다 |
| 5 | `python3 build.py <제품>`으로 `dist/<제품>.html`을 만든다 |

| 제품 | 여정 이름 | 단계 | 상태 |
|---|---|---|---|
| 공통 템플릿 | 구매 여정 | 01 문제 · 02 해결 · 03 비교 · 04 검증 · 05 도입 (15페이지) | 기본값 |
| FLORA Publishing | FLORA 출간 여정 | 01 막힘 · 02 기획(J1, 위저드 1~6) · 03 집필(J3, 위저드 7) · 04 출간(J2, 위저드 8~10) · 05 비교 · 06 시작 (20페이지) | 적용 |
| 나머지 15개 | 구매 여정(공통) | 2판 엔진으로 만든 결과 페이지가 게시돼 있다 | 여정 맞춤 전. 맞출 때 3판 엔진으로 다시 빌드 |

`LANDING_PERSUASION.md`의 7칸 구조(히어로, 막히는 지점, 원인, 방식, 왜 이 플랫폼인가, 비용 비교, 행동)를 NOMAD 랜딩 키트의 화면 구조로 그린 템플릿이다. 제품마다 데이터 파일 1개와 결과 페이지 1개가 따로 있다. 제품끼리 합치지 않는다.

## 1. 구성

| 경로 | 역할 |
|---|---|
| `engine.html` | 공통 엔진(2판). 구매 여정 GNB와 하위 GNB, 페이지 10~15개, 움직임을 그린다 |
| `data/<제품>.json` | 제품 데이터. 작성 규칙은 `DATA_BRIEF.md` |
| `build.py` | JSON 1개를 엔진에 넣어 `dist/<제품>.html`을 만든다. 계산기 식은 이때 함수로 바꿔 넣는다 |
| `validate.js` | 데이터 규칙 검사(페르소나·장부 일치, 판정표 정직성, 경쟁사 필드, 계산기 식). 마지막 줄이 `ALL OK`여야 한다 |
| `dist/<제품>.html` | 제품 전용 결과 페이지. 외부 의존은 Google Fonts뿐이다 |

```
python3 build.py              # data/ 아래 전부
python3 build.py nomad-docs   # 한 제품만
node validate.js              # 데이터 검사
```

## 2. 메뉴 구조 (2판)

A-RMS 랜딩의 "GNB 드롭다운 + 하위 페이지 + 다음 편으로 잇기" 구조를 구매 여정 순서로 바꿨다.

| 줄 | 내용 |
|---|---|
| GNB | 01 문제 → 02 해결 → 03 비교 → 04 검증 → 05 도입. 지금 단계까지 연결선이 채워지고, 단계에 올리면 하위 페이지 목록이 펼쳐진다 |
| 하위 GNB | 현재 단계의 하위 페이지(예: 3-1 경쟁 지형, 3-2 판정표, 3-3 맞지 않는 경우). 본 페이지는 체크, 현재 페이지 밑줄은 읽은 정도만큼 찬다. 오른쪽에 전체 위치(6 / 15)와 이전·다음 |
| 진행 막대 | 하위 GNB 아래 막대가 전체 여정 중 위치를 보여 준다 |
| 페이지 끝 | "다음" 카드로 다음 하위 페이지를 연다. 마지막은 시작 행동 |

| 단계 | 하위 페이지 | 데이터가 없으면 |
|---|---|---|
| 01 문제 | 막히는 장면, 원인 | 항상 있음 |
| 02 해결 | 처리 흐름, 핵심 기능, 결과물 | 기능·결과물은 `features`·`outputs`가 있을 때만 |
| 03 비교 | 경쟁 지형, 판정표, 맞지 않는 경우 | 경쟁 지형은 `competitors`·`market`이 있을 때만 |
| 04 검증 | 증거, 주장 장부, 검증 단계, 논증 글 | 논증 글은 `insight`가 있을 때만 |
| 05 도입 | 요금 단계, 비교 계산기, 자주 묻는 질문 | FAQ는 `faq`가 있을 때만 |

경쟁 지형 페이지는 경쟁사 실명·가격·강점·약점을 담은 내부 검토 시안이다. 공개 랜딩에는 범주 이름만 쓰고, 실명 비교는 비교광고 기준 확인 뒤 게시한다(제안). nomad-docs·arch-studio 등 제품 문서에 "대안은 범주 이름만" 규칙이 있는 경우 그 규칙이 공개 랜딩에 우선한다.

## 3. 움직임

| 위치 | 움직임 |
|---|---|
| 메뉴 | 현재 단계 번호가 빛나고 연결선이 채워진다. 다음 페이지로 가면 화면이 오른쪽에서, 이전으로 가면 왼쪽에서 들어온다 |
| 경쟁 지형 | 경쟁사 점이 차례로 나타나고, 점과 카드에 올리면 서로 강조된다. 범주 필터로 점과 카드가 함께 걸러진다 |
| 핵심 기능 | 기능을 고르면 상세 카드의 아이콘·문장·세부 항목이 차례로 바뀐다 |
| 히어로 | 대상 칩 → 대형 글자 → 문장 → CTA 카드 순서로 등장. 대상 칩을 하나씩 밝히는 순환, CTA 문구 타이핑, 공식 칸 순차 강조, CTA 카드 포인터 기울기 |
| 처리 흐름 | 단계 레일과 이중 타임라인이 같은 단계를 함께 켠다. 멈춤 버튼 있음 |
| 원인 비교 | 기존 방식 문장에 줄이 그어지고 제품 방식 문장이 체크 표시와 함께 들어온다 |
| 판정표 | ○△✕가 행 순서로 나타나고 우리 열에 빛이 지나간다. 정직성 점검 막대가 찬다 |
| 숫자 | 비용 비교 막대와 차이 금액, 도입 단계 가격이 이전 값에서 새 값으로 움직인다 |
| 탭 | 페르소나·도입 단계 탭의 밑줄이 미끄러지고 내용이 교차해 바뀐다 |
| 스크롤 | 화면 아래에 있던 블록만 보일 때 올라온다. 위쪽 진행 막대 |
| 배경 | 제품 강조색 빛이 천천히 떠다니고 포인터 주변이 밝아진다 |

모든 움직임은 `prefers-reduced-motion: no-preference`일 때만 켠다. 동작 줄이기를 켜면 전부 멈추고 같은 내용이 그대로 보인다.

## 4. 결과 페이지

| 제품 | 데이터 | 아티팩트 | 비고 |
|---|---|---|---|
| FLORA Publishing | `data/flora-publishing.json` | https://claude.ai/artifact/TDJKm4WRe5UpZgGPAzJJEz | 적용 제품. 인사이트 3편. 경쟁사 6곳·기능·결과물·FAQ 포함 |
| NOMAD Docs | `data/nomad-docs.json` | https://claude.ai/artifact/7wmQx9WRp7gv8va5SzdVbE | 적용 제품. 인사이트 3편 |
| Arch Studio | `data/arch-studio.json` | https://claude.ai/artifact/XyiMhEA8jTMeZtRVNB1bcz | 적용 제품. 경쟁사 6곳·기능·결과물·FAQ 포함 |
| Admin Suite | `data/admin-suite.json` | https://claude.ai/artifact/3YhN17Q6N4ZMdyKbYYj59o | 후보(도입 영업용) |
| 로컬뉴스 클라우드(가칭) | `data/local-news.json` | https://claude.ai/artifact/BDxY1ozLxGjzKiNkBxTxq8 | 후보(신문사 도입 문의) |
| 신비로운AI | `data/astro-ai.json` | https://claude.ai/artifact/6kvpVjTAaRpfizGPkcy9ZB | 초안. 경쟁사 6곳·기능·결과물·FAQ 포함 |
| NOMAD Book Trailer | `data/book-trailer.json` | https://claude.ai/artifact/9W8yjfiZaEWbYcXegvBC1p | 초안. 경쟁사 6곳·기능·결과물·FAQ 포함 |
| Live Poll | `data/live-poll.json` | https://claude.ai/artifact/7HCW985QggQp4LyXt8dJj8 | 초안 |
| Microweb Studio | `data/microweb-studio.json` | https://claude.ai/artifact/WrcyWVYevBUz6548oGsdYg | 초안 |
| NOMAD Blog | `data/nomad-blog.json` | https://claude.ai/artifact/HPwZqWQQt56wkkJDcRxYwy | 초안 |
| NOMAD Commerce | `data/nomad-commerce.json` | https://claude.ai/artifact/TRMuXutU8yv2XQsFMfqPLW | 초안. 경쟁사 6곳·기능·결과물·FAQ 포함 |
| NOMAD AI Factory | `data/nomad-video.json` | https://claude.ai/artifact/2CCz973ubHfNNWj7pa3pJS | 초안 |
| Stock Dashboard | `data/stock-dashboard.json` | https://claude.ai/artifact/BNX3jaG1YFXPU4JJ9gSpqG | 초안 |
| Study Note | `data/study-note.json` | https://claude.ai/artifact/LFcA1dbwBxGMcTN2BbkMqb | 초안 |
| Toon Factory | `data/toon-factory.json` | https://claude.ai/artifact/UtbXomcD5ztzL3UDeAfbF5 | 초안 |
| Floria | `data/website-floria.json` | https://claude.ai/artifact/341xPb933t11DYW3cL6sHo | 초안 |

"초안"은 `LANDING_PERSUASION.md` 8장에서 적합도 낮음으로 둔 제품이다. 즉시 가입형이라 긴 논증 랜딩이 첫 행동을 늦출 수 있으므로, 실제 랜딩에는 판정표 한 칸이나 비교 계산기처럼 일부만 골라 쓰는 것을 먼저 검토한다(제안). 아티팩트 링크는 소유자 전용이며 공유는 각 페이지의 공유 메뉴에서 한다.

## 5. 데이터 점검 기준

| 항목 | 기준 |
|---|---|
| 페르소나 | 3명의 `id`와 `scene`이 장부 앞 3행과 같다 |
| 판정표 | 우리 열에 △·✕가 1개 이상, 우리 열 ○에는 증거 ID가 있다 |
| 장부 상태 | `draft`·`hold`만 쓴다. `ok`는 검증 뒤에 바꾼다 |
| 아이콘 | `DATA_BRIEF.md`의 아이콘 목록 안에서만 고른다 |
| 경쟁사 | 범주는 alts 이름과 같고, 가격에 확인일, 강점 2개 이상, 약점은 확인 가능한 사실만, 출처 URL 또는 문서 경로 |
| 계산기 | 기본값으로 계산한 비용이 모두 숫자다. 제품 쪽 가격·크레딧은 제품 01장 4장 값 |
| 가격 | 기획 문서의 제안값이다. 01장 4장이 바뀌면 JSON을 고치고 다시 빌드한다 |
