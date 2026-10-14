# M6 distribution-seo 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M6_distribution-seo.md`, 라우트 `D:/WorkSpace/platform/docs/products/local-news/04_API.md`, 대표 도메인 규칙 `D:/WorkSpace/platform/docs/Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md`.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 메타 | 기사 상세 `<head>`: canonical, OG, 트위터 카드, NewsArticle JSON-LD(유료면 `isAccessibleForFree=false` + `hasPart`) | P0 |
| 피드 | `/rss.xml`(최신 50건, 제안), `/rss/[section].xml` | P0 |
| 사이트맵 | `/sitemap.xml`(색인), `/sitemap-news.xml`(48시간·1,000건 분할), `/sitemap-articles-[yyyy-mm].xml` | P0 |
| 설정 | 배포 설정 화면(`syndication_settings`): RSS·뉴스 사이트맵 사용, Google 뉴스 이름, 포털 제휴 상태 기록, AI 크롤러 정책, llms.txt | P0 / P1 |
| 전재 계약 | 계약 CRUD, 게시 게이트 판정, 만료 알림·만료 시 비노출 요청, 출처 문구 자동 삽입 | P1 |
| 크롤러 | `/robots.txt`(정책 3안 + 추가 줄), `/llms.txt` | P1 |
| SNS | 게시 후 자동 공유(코어 oauth 토큰) | P2 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/distribution-seo/server/index.ts` | `DistributionApi` |
| `.../server/head.ts` | 메타·JSON-LD 생성(직렬화 라이브러리, 문자열 결합 금지) |
| `.../server/feeds.ts` | RSS·사이트맵 XML(이스케이프 보장), RFC 822 `pubDate`, W3C `publication_date` |
| `.../server/robots.ts`, `.../server/llms.ts` | `ai_crawler_policy`별 출력, llms.txt |
| `.../server/wire.ts` | 계약 판정(DB 함수 래퍼), 출처 문구(렌더 시 삽입) |
| `.../cache.ts` | `news:<org>:feeds`(RSS·사이트맵·뉴스 사이트맵 공통 태그, 02장 10.3절) |
| `apps/web/src/app/(reader)/_t/[host]/{rss.xml,sitemap.xml,sitemap-news.xml,robots.txt,llms.txt}` | 얇은 라우트(02장 2절) |
| 전재 계약 만료 처리 | 만료 크론이 계약이 끝난 전재 기사를 비노출(판정 `news.wire_contract_valid`, 04장 7절 "만료 크론"). 위치는 06장 작업에서 정함(제안: `news.stats` 큐 일 1회) |
| `apps/web/src/app/api/newsroom/wire-contracts/*`, 배포 설정 화면 | 편집국 API·화면 |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | canonical 결정: 활성 커스텀 도메인 → 그 도메인, 없으면 서브도메인. 서브도메인 요청 301은 Theming `proxy.ts` | 커스텀 도메인 활성 전후 canonical 비교 |
| 2 | JSON-LD: `headline`, `image`(16x9·4x3·1x1 파생본), `datePublished`=최초 게시, `dateModified`=공개 수정 시각(KST 오프셋), `author`(기자 페이지 URL), `publisher`(신문사) | Rich Results Test 통과 |
| 3 | 유료 기사: `isAccessibleForFree=false`, `hasPart`(`WebPageElement`, `.paywalled` class 선택자) | 비회원 HTML의 유료 영역 class와 일치 |
| 4 | RSS: 채널 `title`·`link`·`description`, 항목 `guid`(isPermaLink), 본문 범위 설정, 유료는 요약만 | W3C Feed Validator 통과(미확인 도구 URL) |
| 5 | 뉴스 사이트맵: 48시간·`published`만, 1,000건 넘으면 분할 색인, `news:name`은 설정값 | 1,001건 시드로 파일 2개 |
| 6 | 일반 사이트맵(월별), 색인 파일 | 내림·엠바고 기사 0 |
| 7 | 게시·수정·내림 때 `news:<org>:feeds` 무효화(같은 요청 + `news.post_publish`) | 게시 1분 안 사이트맵 반영 |
| 8 | (P1) 전재 계약 화면, 게이트 판정, 출처 문구 삽입(편집 불가 블록), 만료 잡 | 만료 계약 기사 게시 거부 |
| 9 | (P1) robots 정책 3안(`allow`, `block_training`, `block_all`)과 llms.txt | 정책 변경 후 즉시 반영 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| Google 뉴스 사이트맵 규격 | 최근 2일, 파일당 `news:news` 1,000개, `news:name`은 Google 뉴스의 게시물 이름과 일치 | https://developers.google.com/search/docs/crawling-indexing/sitemaps/news-sitemap (2026-10-15 열람 확인) |
| Article 구조화 데이터 | 필수 속성 없음, 권장 속성 목록 | https://developers.google.com/search/docs/appearance/structured-data/article (2026-10-15 열람 확인) |
| NewsArticle | `dateline`, `printEdition`·`printPage`·`printSection`(지면 PDF 신문사) | https://schema.org/NewsArticle (2026-10-15 열람 확인) |
| 유료 콘텐츠 표시 | `isAccessibleForFree`, `hasPart`, class 선택자만 | https://developers.google.com/search/docs/appearance/structured-data/paywalled-content (2026-10-15 열람 확인) |
| RSS 2.0 | 필수 요소, `guid`, `pubDate` | https://www.rssboard.org/rss-specification (2026-10-15 열람 확인) |
| Google Search Console | 신문사가 자기 도메인 소유 확인 후 `/sitemap.xml` 제출(플랫폼 서브도메인은 플랫폼 계정에서 도메인 속성으로 관리, 제안) | https://search.google.com/search-console (구현 시 확인) |
| Google Publisher Center | Google 뉴스 게시물 이름 등록 | 미확인(구현 시 확인) |
| 네이버 서치어드바이저 | 사이트 등록·사이트맵·RSS 제출 | https://searchadvisor.naver.com (미확인, 이 도구로 열람 안 함) |
| AI 크롤러 | Google-Extended는 robots.txt 토큰(검색 노출 영향 없음). 다른 AI 봇 UA 목록은 정책 표로 관리하고 분기마다 갱신 | https://developers.google.com/search/docs/crawling-indexing/google-common-crawlers (2026-10-15 열람 확인) |
| llms.txt | H1 필수, 요약 인용문, 링크 목록. 표준이 아닌 제안 | https://llmstxt.org/ (2026-10-15 열람 확인) |

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | XML 이스케이프(제목의 `&`, `<`), 날짜 형식(RFC 822·W3C·ISO 8601 + KST), 48시간 경계, 분할 |
| 스냅샷 | 템플릿 신문사 1곳의 RSS·사이트맵·JSON-LD 스냅샷 |
| 노출 | 초안·엠바고·예약·내림 기사가 피드·사이트맵·JSON-LD에 없음 |
| 외부 검증(수동) | Rich Results Test, Search Console 사이트맵 상태, RSS 리더 구독 |

## 6. 운영 점검표

- [ ] Search Console 사이트맵 오류(신문사별, 접근 권한이 있는 경우) 월 1회
- [ ] 뉴스 사이트맵이 48시간 동안 비어 있는 신문사(게시 없음 → M7 주간 신규 게재 경고와 함께)
- [ ] 전재 계약 만료 14일 전 알림 수신
- [ ] AI 봇 UA 목록 분기 갱신
- [ ] 대표 도메인 변경 시 canonical·301 확인

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| Search Console "빈 사이트맵" 경고 | 48시간 동안 게시 없음 | 무해(Google 문서). 게시 경고는 M7 |
| canonical이 서브도메인으로 나감 | 커스텀 도메인 `active` 전, 또는 도메인 해석 실패 | Theming 도메인 상태 확인 |
| 유료 기사 클로킹 경고 | `hasPart` 선택자와 실제 class 불일치 | 렌더러 class 상수 공유 |
| 전재 기사 출처가 빠짐 | 출처 블록을 본문 저장 때 지움 | 출처 블록은 렌더 시 삽입(저장 본문에 넣지 않음) |
