# M6 distribution-seo: 배포·검색 노출·전재 계약

작성일 2026-10-15. 표 정본 `docs/file/03-설계/05_DATA_MODEL.md`, 라우트 정본 `docs/file/03-설계/04_API.md`.

## 1. 목적과 범위

기사가 독자 사이트 밖(검색엔진, 포털, RSS 리더, AI 서비스, SNS)으로 나가는 경로를 소유한다. 한국 독자의 포털 경유 뉴스 이용은 2026년 61%이고 AI 챗봇 경유가 14%다(https://www.nocutnews.co.kr/news/6533916). 포털 제휴 심사에서 자체기사·검색 노출 기본기가 점수가 되므로(https://journalist.or.kr/news/article.html?no=60389) 기술 SEO는 P0다.

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 전체·섹션 RSS, 뉴스 사이트맵(최근 2일, 1,000건), 일반 사이트맵(월별), NewsArticle 구조화 데이터, OG·트위터 카드, canonical(대표 도메인), 유료 본문 표시(M2 연동) | NW-F-040 |
| 확장(P1) | 통신사 전재 계약 관리(출처 표시, 만료 시 비노출), AI 크롤러 정책(robots.txt, llms.txt), 포털 전송 기록 | NW-F-043, 045 |
| 확장(P2) | SNS 자동 공유 | NW-F-042 |
| 하지 않음 | 포털 제휴 대행(심사는 신문사 몫), 검색 순위 보장 문구 | - |

## 2. 벤치마크

| 제품·규격 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Google 뉴스 사이트맵 | 최근 2일 기사만, 파일당 `news:news` 1,000개(넘으면 분할), `news:publication`(name·language), `publication_date`는 최초 게시 시각(W3C), `news:title`은 사이트 제목 그대로, 2일 지난 항목 제거(빈 사이트맵 경고는 무해) | - | https://developers.google.com/search/docs/crawling-indexing/sitemaps/news-sitemap (2026-10-15 열람 확인) |
| Google Article 구조화 데이터 | 필수 속성 없음, 권장 `headline`, `image`(16x9·4x3·1x1), `datePublished`·`dateModified`(시간대 포함), `author.name`·`author.url`(기자 페이지) | - | https://developers.google.com/search/docs/appearance/structured-data/article (2026-10-15 열람 확인) |
| schema.org NewsArticle | Article 하위 타입, `dateline`, `printEdition`·`printPage`·`printSection`(지면 PDF가 있는 신문사) | - | https://schema.org/NewsArticle (2026-10-15 열람 확인) |
| Google 유료 콘텐츠 표시 | `isAccessibleForFree=false`, `hasPart`(WebPageElement) + class 선택자로 클로킹과 구분 | - | https://developers.google.com/search/docs/appearance/structured-data/paywalled-content (2026-10-15 열람 확인) |
| RSS 2.0 | 채널 필수 `title`·`link`·`description`, 항목은 title 또는 description 중 하나, `guid`(isPermaLink), `pubDate` RFC 822 | Atom 동시 제공(확장) | https://www.rssboard.org/rss-specification (2026-10-15 열람 확인) |
| Google-Extended·llms.txt | Google-Extended는 robots.txt 토큰이며 Gemini 학습·그라운딩 사용 제어, 검색 포함·순위에 영향 없음. llms.txt는 표준이 아닌 제안(H1 필수, 요약 인용문, 링크 목록) | llms.txt를 "AI 노출 보장"으로 홍보 | https://developers.google.com/search/docs/crawling-indexing/google-common-crawlers , https://llmstxt.org/ (2026-10-15 열람 확인) |
| Newspack | 콘텐츠 배포 개선(2025-08 릴리스) 참고 | WordPress 플러그인 | https://newspack.com/august-25-2025-ads-newsletters-and-content-distribution-improvements (제목만 확인, 본문 미확인) |

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `wire_contracts`, `syndication_settings` |
| 소유 함수·라우트 | `news.wire_contract_valid`(게시 판정이 호출), `news.upsert_wire_contract`, `news.set_syndication_settings`, `/rss.xml`, `/rss/[section].xml`, `/sitemap.xml`(색인), `/sitemap-news.xml`, `/sitemap-articles-[yyyy-mm].xml`, `/robots.txt`, `/llms.txt`, 기사 상세의 JSON-LD·메타 생성기 |
| 쓰는 코어 | Theming(`tenant_domains` 대표 도메인 → canonical), jobs(큐 `news.publish`의 사이트맵 갱신, 계약 만료 잡), audit |
| 쓰는 모듈 | M1 공개 기사 읽기, M1 `is_premium`과 M2 페이월 모드(유료 표시), M7 AI 보조 표시(구조화 데이터에는 넣지 않고 본문 표시만, 제안) |
| 소비자 | 독자 화면 `<head>`, 검색엔진·포털·RSS 리더, M1 게시 게이트(wire) |

## 4. 데이터 (요약, 상세 `docs/file/03-설계/05_DATA_MODEL.md`)

| 표 | 핵심 컬럼(요약) |
|---|---|
| `wire_contracts` | 통신사(`yonhap`·`newsis`·`news1`·`other`), 이름, 계약 번호, 시작일·종료일(`ends_on`), 필수 출처 문구(`attribution_text`), 전문 전재 허용, 상태(`active`·`terminated`), 메모. 만료는 상태가 아니라 `ends_on` 경과로 판정 |
| `syndication_settings` | 신문사당 1행: RSS 사용, 뉴스 사이트맵 사용, Google 뉴스 사용, 네이버·다음 제휴 상태(`none`·`search`·`content`, 기록용), AI 크롤러 정책(`allow`·`block_training`·`block_all`, 기본 `block_training`), llms.txt 사용, robots 추가 줄, SNS 자동 공유 설정 |

포털 전송 기록 표는 M6 소유 표 목록에 없다. 1차는 `core.jobs` 실행 기록 + 감사 로그로 남기고, 전송 건별 조회가 필요하면 `portal_deliveries`를 변경 제안으로 05장에 올린다.

## 5. 인터페이스

```ts
// src/modules/distribution-seo/server/index.ts — 계약 예시(구현 파일 아님)
export interface ArticleMetaInput { orgId: string; articleId: string }
export interface DistributionApi {
  buildArticleHead(input: ArticleMetaInput): Promise<{ canonical: string; og: Record<string, string>; jsonLd: Record<string, unknown> }>  // NewsArticle, 유료면 isAccessibleForFree=false + hasPart
  renderRss(orgId: string, opts?: { sectionSlug?: string; limit?: number }): Promise<string>           // 최신 게시 50건(제안)
  renderNewsSitemap(orgId: string, now: Date): Promise<string>                                       // 최근 48시간, 1,000건 초과 시 분할 색인
  renderRobots(orgId: string): Promise<string>                                                       // AI 크롤러 정책 + 사이트맵 위치
  renderLlmsTxt(orgId: string): Promise<string | null>                                                // 꺼져 있으면 404
  isWireAllowed(orgId: string, wireContractId: string, usage: 'web' | 'newsletter'): Promise<boolean> // DB 함수 래퍼(게시 게이트와 같은 판정)
}
```

| 이벤트 | 발생 | 구독 |
|---|---|---|
| `news.wire.contract.expiring` | `ends_on` 14일 전(제안) | 발행인·편집인 알림 |
| `news.wire.contract.expired` | 만료일 | M1에 해당 계약 기사 일괄 비노출 요청(M1 RPC 호출, 직접 쓰지 않음) |
| 구독: `news.article.published` / `.updated` / `.unpublished`(M1) | 사이트맵·RSS 캐시 태그 무효화, 검색엔진 핑(구글 핑 엔드포인트는 쓰지 않음, 제안) | - |

## 6. 상태·규칙

| 규칙 | 내용 | 근거 |
|---|---|---|
| canonical | 활성 커스텀 도메인이 있으면 그 도메인, 없으면 서브도메인. 서브도메인 요청은 대표 도메인으로 301 | `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:10` |
| 뉴스 사이트맵 | `published_at` 48시간 이내, 내림·엠바고·예약 기사 제외, `news:name`은 Google 뉴스 등록 이름과 같아야 한다(설정값) | Google 뉴스 사이트맵 문서 |
| 날짜 | `datePublished`=최초 게시, `dateModified`=공개 수정 시각(M1). KST 오프셋 포함 ISO 8601 | Google Article 문서 |
| 기자 | `author.url`은 기자 페이지(NW-F-021). 바이라인 없는 보도자료는 신문사 Organization | Google Article 문서 |
| 전재 기사 | 계약 만료(`ends_on` 경과)·해지(`terminated`)면 게시 불가(`news.wire_contract_valid` 거짓), 만료일에 기존 기사는 비노출 요청. 출처 문구는 본문 끝 자동 삽입(편집 불가). 전재 기사 색인 제외(noindex)는 신문사 선택(기본 끔, 제안) | 저작권·전재 계약(01장 법 절) |
| RSS 범위 | 기본 요약, 전문 피드는 신문사 선택. 유료 기사는 항상 요약만 | Newspack RSS 제한 옵션(https://help.newspack.com/?p=17054) |
| AI 크롤러 | 정책 3안(`allow` 전체 허용·`block_training` 학습용 봇만 차단·`block_all` AI 봇 전체 차단). Google-Extended 차단은 검색 노출에 영향이 없음을 설정 화면에 표시 | Google 크롤러 문서 |
| llms.txt | 기본 꺼짐. 켜면 매체 소개, 섹션 링크, 정정·윤리강령 링크만(기사 전문 목록 금지, 제안) | llms.txt 제안 문서 |

NewsArticle 필드 매핑(제안):

| JSON-LD | 출처 | 비고 |
|---|---|---|
| `headline` | `articles.title` | 110자 넘으면 자르지 않고 그대로(Google 권장은 "간결하게") |
| `image` | 대표 이미지 파생본 3비율 | 파생본은 M1 `news.media_derive` |
| `datePublished` / `dateModified` | `first_published_at` / `revised_at`(없으면 `published_at`) | `+09:00` 오프셋 |
| `author` | 바이라인 기자의 기자 페이지 URL과 이름. `press_release`·바이라인 없음은 `Organization` | 기고는 기고자 이름 |
| `publisher` | 제호, 로고(Theming 자산) | M1 `newspapers.title` |
| `isAccessibleForFree`, `hasPart` | `is_premium` + 페이월 모드 | M2 판정과 같은 규칙 |
| `printEdition` 등 | 지면 PDF가 연결된 기사만 | P1 |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| 사이트맵·RSS 생성 실패 | 마지막 성공본(캐시)을 계속 응답하고 오류 기록. 빈 파일로 덮지 않는다 |
| 대표 도메인 해석 실패 | 서브도메인 canonical로 렌더(`Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:77` 지연 규칙과 같게) |
| JSON-LD 직렬화 오류 | 해당 블록만 생략, 페이지는 렌더 |
| 계약 만료 비노출 요청 실패 | 재시도 잡, 실패 시 편집인 알림. 게시 게이트는 별도로 막혀 있으므로 새 게시는 불가 |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 노출 범위 | 피드·사이트맵에는 `published` 기사만. 엠바고·초안 URL이 새지 않게 테스트 |
| 출력 이스케이프 | XML·JSON-LD는 직렬화 라이브러리로 생성(문자열 결합 금지), 제목의 `<`·`&` 이스케이프 |
| 계약 정보 | 계약 번호·금액은 편집국 전용(공개 피드에 넣지 않음) |
| SNS 공유(P2) | 토큰은 코어 oauth·`encrypted_credentials`(`docs/file/03-설계/공용코어/SHARED_MODULES.md:188-209`) |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-040 | 뉴스 사이트맵에 48시간 넘은 기사 0, 1,001건이면 파일 2개, RSS가 RSS 2.0 필수 요소를 가짐, 유료 기사 JSON-LD에 `isAccessibleForFree=false`, 커스텀 도메인 활성 시 canonical이 그 도메인 |
| NW-F-043 | 만료 계약을 고른 기사 게시 거부, 만료일 뒤 기존 전재 기사 비노출, 출처 문구 삭제 불가 |
| NW-F-045 | 정책 변경 후 `/robots.txt` 반영(캐시 무효화), llms.txt 꺼짐이면 404 |
| NW-F-042(P2) | 게시 후 연결된 계정에 1회만 공유(멱등 키) |

## 10. 추출 조건

RSS·일반 사이트맵·OG 생성기는 공용 `cms`(0800)의 SEO 메타·사이트맵 기능(`D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:207`)이 착수되면 꺼낸다. 뉴스 사이트맵, NewsArticle, 전재 계약, 포털 전송은 뉴스 전용으로 남긴다.
