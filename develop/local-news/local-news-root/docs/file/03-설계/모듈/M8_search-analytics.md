# M8 search-analytics: 검색·조회 집계·대시보드·리포트

작성일 2026-10-15. 표 정본 `docs/file/03-설계/05_DATA_MODEL.md`, 비기능 수치 정본 `docs/file/02-요구사항/01_PRD.md` 비기능 절.

## 1. 목적과 범위

독자에게는 "많이 본 뉴스"와 기사 검색을, 편집국에는 오늘의 숫자를, 발행인에게는 지원사업·ABC 제출용 월 리포트를 준다. 다른 모듈 데이터를 읽기만 하는 소비 전용 모듈이다(조회 집계 표만 소유).

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 기사 검색(제목·본문, 섹션·지역·기간 필터), 조회 수 수집(봇 필터·중복 제거·레이트 리밋), 시간 버킷 집계, 많이 본 뉴스(1시간·24시간), 편집국 대시보드(오늘 기사·조회·유입 분류·많이 본·기자별) | NW-F-022, 060 |
| 확장(P1) | 지원사업·ABC 리포트 패키지(월 발행 실적, 자체기사 비율, 광고 비중, 독자 수) PDF·CSV | NW-F-061 |
| 확장(P2) | 체류(참여) 시간 측정, 외부 검색 엔진(Meilisearch·Typesense), 외부 분석 도구 연결(analytics 래퍼) | D-7 |
| 하지 않음 | 개인별 열람 이력 저장(독자 프로파일링), 광고 타기팅용 데이터 판매 | - |

## 2. 벤치마크

| 제품·규격 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Parse.ly | 참여 시간 정의 "영상 재생 중 또는(최근 상호작용 그리고 창 포커스)", 페이지뷰 + 하트비트(누적 참여 초 `inc`) 구조, 재순환율 지표 | 유료 SaaS 연동(1차) | https://docs.parse.ly/engaged-time/ , https://docs.parse.ly/ (2026-10-15 열람 확인) |
| Chartbeat | 스크롤·마우스·키 입력으로 참여를 판단, 기간 평균 참여 시간 = 총 참여 시간 / 페이지뷰, 실시간 현재 독자 화면 | 실시간 동시 접속(1차 제외) | https://help.chartbeat.com/hc/en-us/articles/360040970854-FAQ-Chartbeat-Engaged-Time-versus-Google-Analytics-visit-duration-metrics (2026-10-15 열람 확인) |
| PostgreSQL pg_trgm | `similarity`, `%`(기본 임계값 0.3), `word_similarity`, GIN/GiST 인덱스로 `LIKE`·`ILIKE` 가속. 트라이그램을 뽑을 수 없는 패턴은 전체 인덱스 스캔으로 떨어짐 | - | https://www.postgresql.org/docs/15/pgtrgm.html (2026-10-15 열람 확인) |
| Supabase 전문 검색·확장 목록 | 저장 생성 tsvector 컬럼 + GIN, `websearch_to_tsquery`(사용자 검색어 문법). 확장 목록에 `pg_trgm`은 있고 `pg_bigm`은 없음 | - | https://supabase.com/docs/guides/database/full-text-search , https://supabase.com/docs/guides/database/extensions (2026-10-15 열람 확인) |
| 한국 언론사 홈(경향·한라·용인시민신문) | "많이 본 뉴스" 5~10건은 거의 필수 블록 | 실시간 순위 조작 가능한 구조 | https://www.khan.co.kr , https://www.ihalla.com , https://www.yongin21.co.kr (조사 에이전트 2026-10-15 열람, 이 문서에서 재확인 안 함) |

결론: 1차는 Postgres만으로 검색(D-7 권고)하고, 한국어 형태소 분석 대신 "tsvector('simple') 접두 일치 + 제목 트라이그램 유사도"를 섞는다. `pg_bigm`은 Supabase 확장 목록에 없으므로 1차 선택지에서 뺀다(02장의 pg_bigm "미확인" 표기를 "Supabase 확장 목록에 없음, 2026-10-15 확인"으로 갱신 제안).

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `article_view_hourly` |
| 소유 함수·뷰 | `news.increment_article_views`(service), `news.most_read`(공개), 검색 함수(이름 정본 `04_API.md`), 대시보드 집계 함수, 월 리포트 뷰 |
| 소유하지 않는 것 | 검색용 생성 컬럼(M1 `articles`에 있음, 인덱스와 함수만 M8) |
| 쓰는 코어 | rate_limit(조회 비콘), jobs(큐 `news.stats` 롤업·리포트 생성), storage(`exports` 리포트 PDF), WeasyPrint 렌더(flora 소유 공용 서비스, `docs/file/03-설계/공용코어/SHARED_MODULES.md:44`) |
| 읽는 모듈 | M1(기사), M2(독자 수·후원 합계), M3(광고 노출·매출 비중), M4(구독자 수·열람률), M5(제보·댓글 수), M7(`compliance_weekly_stats`) |

## 4. 데이터 (요약, 상세 `docs/file/03-설계/05_DATA_MODEL.md`)

| 표·함수 | 핵심(요약) |
|---|---|
| `article_view_hourly` | `org_id`, `article_id`, `bucket_start`(UTC 정시, CHECK로 강제. 화면은 KST로 변환), `views`. 기본키 (기사, 버킷), 증분 upsert(04장은 샤드 증분 후 `news.stats_rollup` 10분 합산). 유입 분류(직접·검색·포털·SNS·뉴스레터·푸시)를 키에 넣을지는 변경 제안(대시보드 "유입" 요구) |
| `most_read(org, window, limit)` | 1시간·24시간 버킷 합, 게시 상태 기사만, `security definer` + anon 실행(공개) |
| `increment_article_views(article_id, count, at)` | service 전용. 1회 1~1,000건, 48시간 이내 시각만(그 밖은 `NW015`). 비공개 기사면 false |
| 월 리포트 뷰 | 월 게시 수·유형별 수, 자체기사 비율(M7), 광고 노출·매출(M3), 독자·구독자 수(M2·M4) |

## 5. 인터페이스

```ts
// src/modules/search-analytics/server/index.ts — 계약 예시(구현 파일 아님)
export interface SearchQuery { orgId: string; q: string; sectionId?: string; regionId?: string; from?: string; to?: string; page?: number }
export interface SearchHit { articleId: string; title: string; excerpt: string; publishedAt: string; score: number }
export interface SearchAnalyticsApi {
  search(query: SearchQuery): Promise<{ hits: SearchHit[]; total: number }>                 // rpc news.search_articles(org, query, limit, offset). SQL 시그니처에 섹션·지역·기간 필터가 없어 필터는 변경 제안
  recordView(beacon: { host: string; articleId: string; ipHash: string; ua: string; prerender: boolean }): Promise<'counted' | 'duplicate' | 'bot'>  // POST /api/r/view, 응답은 항상 204
  mostRead(orgId: string, window: '1h' | '24h', limit?: number): Promise<Array<{ articleId: string; views: number }>>  // rpc news.most_read
  dashboard(orgId: string, day: string): Promise<DashboardStats>                             // 편집국 전용
  monthlyReport(orgId: string, month: string, format: 'pdf' | 'csv'): Promise<{ jobId: string }>  // 잡 → exports 버킷
}
```

이벤트: 발행하지 않는다. 구독: `news.article.unpublished`(M1) → 많이 본 뉴스 캐시 무효화.

## 6. 상태·규칙

| 규칙 | 내용 | 근거 |
|---|---|---|
| 조회 수집 | 서버 렌더 시 세지 않고, 페이지가 화면에 표시된 뒤 브라우저 비콘으로 센다(ISR 캐시·크롤러 영향 제거) | `docs/file/03-설계/02_ARCHITECTURE.md` 조회수 경로 |
| 봇 필터 | 알려진 봇 UA 제외, JS 미실행 요청은 비콘이 없으므로 자동 제외 | 제안 |
| 중복 제거 | 같은 IP 해시 + 기사는 30분에 1회: `rate_limit_hit('news:view:<org>:<ip>:<article>', 1, 1800)` 통과분만 증분(`docs/file/03-설계/04_API.md` 2.1절). IP 원문은 저장하지 않는다 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:195` |
| 레이트 리밋 | IP 해시당 분당 60건(제안, `/r/[code]` 기준과 같게) | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:143-157` |
| 쓰기 경로 | 비콘 → Route Handler(검증) → `news.increment_article_views`(service, 샤드 증분) → `news.stats_rollup`(10분) 합산·많이 본 무효화. Redis 없이 시작 | `docs/file/03-설계/02_ARCHITECTURE.md` 4절 |
| 검색 | `tsvector('simple')` 생성 컬럼 + `websearch_to_tsquery` 접두 일치, 제목은 `pg_trgm` 유사도 보조. 2글자 이하 검색어는 트라이그램이 안 나와 인덱스 효율이 떨어지므로 제목 접두·`tsvector` 경로만(제안, 실측 필요) | pg_trgm 문서 |
| 한국어 한계 | 조사가 붙은 어절("용인시는")은 'simple' 토큰과 정확히 맞지 않는다. 접두 일치로 일부 보완, 정확도 목표는 01장 비기능에서 정함. 규모가 커지면 외부 검색(P2) | D-7 |
| 많이 본 뉴스 | 내림·엠바고 기사 제외, 캐시 태그 `news:<org>:most-read` 최대 60초(02장 10.3절), 상한 10건 | `docs/file/03-설계/04_API.md` 3절 |
| 유료 조회 | 페이월에 막힌 조회도 1회로 세되 리포트에서 구분(제안) | - |

대시보드·리포트 지표 정의(제안, 정본은 01장 KPI·비기능 절과 맞춘다):

| 지표 | 정의 | 출처 모듈 |
|---|---|---|
| 오늘 게시 | KST 오늘 `first_published_at` 건수(재게시 제외) | M1 |
| 조회 | `article_view_hourly.views` 합(봇·중복 제외분) | M8 |
| 유입 분류 | 05장 SQL 표에 유입 컬럼이 없어 1차는 제공하지 않는다. 필요하면 버킷 키에 분류(직접·검색·포털·SNS·뉴스레터·푸시)를 더하는 변경 제안 | M8 |
| 기자별 | `author_id`(없으면 바이라인) 기준 게시 수·조회 합 | M1, M8 |
| 자체기사 비율 | `news.compliance_weekly_stats` 값을 그대로 사용(다시 계산하지 않음) | M7 |
| 독자 수 | `readers.status='active'` 수, 유료 멤버 수(`memberships.status='active'`) | M2 |
| 구독자 수 | `newsletter_subscriptions.status='confirmed'` 수(목록별) | M4 |
| 광고 비중 | 지원사업 요건(광고 비중 50% 이하)은 신문사 전체 매출 대비라 플랫폼 데이터만으로 계산할 수 없다. 직판 광고 계약액(M3)·독자 결제액(M2)은 자동, 그 밖의 매출은 신문사가 리포트 생성 때 입력 | M2, M3, 입력 |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| 비콘 RPC 실패 | 조회 손실 허용(재시도 없음), 오류율 지표만 기록. 독자 화면에 영향 없음 |
| `most_read` 실패 | 마지막 캐시 또는 블록 숨김. 빈 목록을 "0건"으로 보이지 않는다 |
| 검색 시간 초과(제안 2초) | "검색이 지연됩니다" + 최신 기사 링크. 결과를 지어내지 않는다 |
| 리포트 잡 실패 | 잡 `failed`, 발행인 알림, 원인(어느 모듈 집계 실패) 표시 |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 개인 식별 | 조회 표에 독자 id·IP를 저장하지 않는다(시간 버킷 합계만). 레이트 리밋 키의 IP 해시는 30분 창이 지나면 의미가 없고 코어 `rate_limit_hit` 보존 규칙을 따른다 |
| 집계 공개 | 신문사 간 비교 집계를 독자·다른 신문사에 노출하지 않는다. 플랫폼 운영 집계는 운영자만 |
| 리포트 | `exports` 버킷 서명 URL 7일(`docs/file/03-설계/공용코어/SHARED_MODULES.md:386`) |
| 검색어 로그 | 1차는 저장하지 않는다(필요 시 해시·집계만, 제안) |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-022 | 1시간·24시간 많이 본 뉴스가 버킷 합과 일치, 봇 UA 비콘은 0 증가, 같은 IP·기사 30분 내 재조회 1회, 검색 p95 1초 이내(데이터 10만 건 기준 목표, 제안), 초안·엠바고 기사 검색 0 |
| NW-F-060 | 오늘 게시 수·조회·많이 본·기자별 수가 원 데이터와 일치, reporter는 자기 기사 통계만(제안) |
| NW-F-061 | 월 리포트 PDF·CSV에 발행 실적, 자체기사 비율(M7 함수 값과 동일), 광고 비중, 독자 수 |

## 10. 추출 조건

이벤트 규격과 외부 분석 도구 연결은 공용 `analytics`(새 스키마 없음, `D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:148-156`)가 착수되면 래퍼로 옮긴다. 시간 버킷 조회·많이 본 뉴스·지원사업 리포트는 뉴스 전용으로 남기고, 검색 함수는 다른 제품이 Postgres 검색을 쓸 때 패턴(생성 컬럼 + 함수)만 공유한다.
