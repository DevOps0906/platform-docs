# develop_V2 — 공용모듈을 쓰는 제품별 개발서

작성일 2026-10-15. local-news 기획에서 꺼낸 공용모듈 7개(compliance, media, community, search, membership, ads, editorial)를 사용해 각 제품을 개발하는 방법을 제품마다 정리했습니다. `develop/`(V1)의 설치 스크립트·개발 묶음·안내서는 그대로 쓰고, 이 폴더의 개발서는 **공용모듈 때문에 바뀌는 부분**(채택 모듈, DB 순서, 추가 작업, 축소·대체되는 V1 작업, 주입 값, 검증)만 다룹니다.

| 문서 | 내용 |
|---|---|
| [`_shared/V2_RULES.md`](_shared/V2_RULES.md) | V2 공통 규칙: V1과의 관계, DB 파일 순서·이름, V2 작업 만드는 법, 요청 프롬프트, 공용모듈 저장소가 없을 때 |
| [`_shared/tools/gen_v2.py`](_shared/tools/gen_v2.py) | 제품별 개발서와 이 색인을 만드는 스크립트. 06장을 고친 뒤 다시 실행하면 V2 작업 웨이브가 따라 바뀝니다 |
| `products/_platform-core/common-modules/` | 공용모듈 기획서(무엇을 만드는가)와 15개 제품 적용표 |
| `develop/_shared/modules/` | 공용모듈 개발 지시서(패키지를 어떻게 만드는가) |

## 1. 제품별 개발서

| 개발 단계 | 제품 | V2 개발서 | 채택 공용모듈 | 이 제품이 만드는 패키지(기준 구현) | V2 작업 수 | 바뀌는 V1 작업 수 |
|---|---|---|---|---|---|---|
| 1 | study-note | [`study-note_develop_v2.md`](study-note/study-note_develop_v2.md) | compliance | - | 2 | 3 |
| 1 | website-floria | [`website-floria_develop_v2.md`](website-floria/website-floria_develop_v2.md) | compliance | compliance | 3 | 4 |
| 2 | astro-ai | [`astro-ai_develop_v2.md`](astro-ai/astro-ai_develop_v2.md) | compliance | - | 2 | 2 |
| 2 | flora-publishing | [`flora-publishing_develop_v2.md`](flora-publishing/flora-publishing_develop_v2.md) | compliance, media | media | 4 | 3 |
| 2 이후 | nomad-docs | [`nomad-docs_develop_v2.md`](nomad-docs/nomad-docs_develop_v2.md) | compliance, media | - | 3 | 2 |
| 3 | nomad-blog | [`nomad-blog_develop_v2.md`](nomad-blog/nomad-blog_develop_v2.md) | compliance, media, editorial | editorial | 5 | 5 |
| 3 | nomad-commerce | [`nomad-commerce_develop_v2.md`](nomad-commerce/nomad-commerce_develop_v2.md) | compliance, media | - | 3 | 3 |
| 3 | nomad-video | [`nomad-video_develop_v2.md`](nomad-video/nomad-video_develop_v2.md) | compliance | - | 2 | 3 |
| 4 | live-poll | [`live-poll_develop_v2.md`](live-poll/live-poll_develop_v2.md) | compliance, community(부분) | - | 3 | 2 |
| 4 | microweb-studio | [`microweb-studio_develop_v2.md`](microweb-studio/microweb-studio_develop_v2.md) | compliance, media, community | community | 5 | 5 |
| 4 | toon-factory | [`toon-factory_develop_v2.md`](toon-factory/toon-factory_develop_v2.md) | compliance, media | - | 3 | 3 |
| 5 | admin-suite | [`admin-suite_develop_v2.md`](admin-suite/admin-suite_develop_v2.md) | compliance | - | 2 | 3 |
| 5 | stock-dashboard | [`stock-dashboard_develop_v2.md`](stock-dashboard/stock-dashboard_develop_v2.md) | compliance | - | 2 | 2 |
| 6 | local-news | [`local-news_develop_v2.md`](local-news/local-news_develop_v2.md) | compliance, media, community, search, membership, ads, editorial | search, membership, ads | 12 | 10 |
| 설치형(미정) | arch-studio | [`arch-studio_develop_v2.md`](arch-studio/arch-studio_develop_v2.md) | compliance | - | 2 | 0 |

## 2. 공용모듈이 만들어지는 순서

패키지는 그 모듈을 처음 쓰는 제품(기준 구현)이 `nomad-modules` 저장소에서 함께 만들고, 뒤 제품은 출시된 버전을 설치만 합니다.

| 모듈 | 기준 구현 제품 | 다음에 쓰는 제품 |
|---|---|---|
| compliance | website-floria | study-note, astro-ai, flora-publishing, nomad-docs, nomad-blog, nomad-commerce, nomad-video, live-poll, microweb-studio, toon-factory, admin-suite, stock-dashboard, local-news, arch-studio |
| media | flora-publishing | nomad-docs, nomad-blog, nomad-commerce, microweb-studio, toon-factory, local-news |
| community | microweb-studio | live-poll, local-news |
| search | local-news | - |
| membership | local-news | - |
| ads | local-news | - |
| editorial | nomad-blog | local-news |

compliance는 website-floria가 만들고 study-note가 두 번째로 적용해 v1.0을 검증합니다. media는 flora-publishing, editorial은 nomad-blog, community는 microweb-studio, search·membership·ads는 local-news가 만듭니다. 기준 구현 제품보다 먼저 개발하는 제품이 그 모듈을 쓰려면 V1 방식으로 만들고 나중에 전환합니다(V2_RULES 6장).

## 3. 사용 순서

| 순서 | 할 일 |
|---|---|
| 1 | V1 안내서(`develop/<제품>/<제품>_develop.md`) 0~6장으로 개발 폴더를 만든다 |
| 2 | 이 폴더의 `<제품>/<제품>_develop_v2.md` 2~4장을 보고 공용모듈 SQL·작업을 반영한다 |
| 3 | V1 안내서 8~10장 사이클로 웨이브를 진행한다(V2 작업은 해당 웨이브 맨 앞) |
| 4 | 제품 V2 개발서 6장의 검증 항목을 완료 정의에 더한다 |
