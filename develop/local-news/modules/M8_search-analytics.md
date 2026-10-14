# M8 search-analytics 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M8_search-analytics.md`, 표 `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md`, 비기능 수치 `D:/WorkSpace/platform/docs/products/local-news/01_PRD.md`.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 조회 수집 | 비콘 `/api/r/view`(봇 필터, 30분 중복 제거, IP 해시 레이트 리밋), 묶음 증분 RPC | P0 |
| 많이 본 뉴스 | `news.most_read`(1시간·24시간), 블록 컴포넌트, 5분 캐시 | P0 |
| 검색 | 검색 페이지(제목·본문, 섹션·지역·기간 필터), 검색 함수 | P0 |
| 편집국 대시보드 | 오늘 기사·조회·유입 분류·많이 본·기자별 | P0 |
| 월 리포트 | 지원사업·ABC 리포트(PDF·CSV) | P1 |
| local-life 연계 | 날씨·미세먼지 블록은 M8이 아니라 제품 기능이지만 외부 API 캐시 규칙이 비슷해 이 문서 4장에 설정을 함께 둔다 | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/search-analytics/server/index.ts` | `SearchAnalyticsApi` |
| `.../components/ViewBeacon.tsx` | 기사 화면 표시 후 1회 `sendBeacon`(프리렌더 제외) |
| `.../components/MostReadBlock.tsx` | 많이 본 뉴스 블록(`news:<org>:most-read`, 60초 최대 수명) |
| `.../server/views.ts` | Host → 조직, 봇 UA 필터, `rate_limit_hit('news:view:<org>:<ip>:<article>', 1, 1800)` 통과분만 `news.increment_article_views(article_id, count, at)`(service, 1회 1~1,000건·48시간 이내) |
| `.../server/search.ts` | 검색어 정규화(2~50자), 2글자 분기, `news.search_articles(org, query, limit, offset)`. 섹션·지역·기간 필터는 SQL 인자에 없어 변경 제안(05장) |
| `.../server/dashboard.ts`, `.../server/report.ts` | 집계 함수 호출, 리포트 잡 enqueue |
| `worker/src/handlers/news.stats/` | `news.stats_rollup`(10분: 버킷 합산·많이 본 무효화·일 집계), `news.support_report`(P1 월 리포트, 렌더 서비스) |
| `apps/web/src/app/api/r/{view,search,most-read}` | 독자 API(04장 2.1절) |
| `apps/web/src/app/api/newsroom/stats/*`, `apps/web/src/app/(reader)/_t/[host]/search` | 편집국 통계 API, 검색 화면 |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | `pg_trgm` 확장과 검색 인덱스 적용 여부 확인(마이그레이션 정본 05장) | `\dx`에 `pg_trgm` |
| 2 | 비콘 라우트 `/api/r/view`: 항상 204, 본문 1KB 상한, Host로 조직 결정(본문의 org 무시), 게시 기사만 | 초안 id 비콘 무시 |
| 3 | 봇 UA 목록, 30분 중복 제거는 `rate_limit_hit` 키(조직·IP 해시·기사, 1800초)로(04장 2.1절) | 같은 IP 재조회 1회 |
| 4 | 샤드 증분 + `news.stats_rollup` 10분 합산(02장 4절) | 부하 테스트(5장 시나리오) |
| 5 | `most_read` 블록, 캐시 태그 `news:<org>:most-read`(60초 최대 수명, 롤업 때 무효화) | 내린 기사 다음 갱신에서 제외 |
| 6 | 검색: `websearch_to_tsquery('simple', q)` 접두 일치 + 제목 `similarity` 보조, 2글자 이하는 제목 접두 경로 | 시드 1만 건에서 p95 측정 |
| 7 | 편집국 대시보드(오늘·기자별·많이 본), reporter는 자기 기사만(제안) | 원 데이터와 합계 일치 |
| 8 | (P1) 월 리포트: M7 비율, M3 광고 비중, M2 독자·후원, M4 구독자 | 리포트 수치 = 각 모듈 함수 값 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| PostgreSQL pg_trgm | GIN(`gin_trgm_ops`)으로 `ILIKE`·유사도 가속, 기본 임계값 0.3. 트라이그램이 없는 짧은 패턴은 전체 인덱스 스캔 | https://www.postgresql.org/docs/15/pgtrgm.html (2026-10-15 열람 확인) |
| Supabase 전문 검색 | 생성 tsvector 컬럼 + GIN, `websearch_to_tsquery` | https://supabase.com/docs/guides/database/full-text-search (2026-10-15 열람 확인) |
| Supabase 확장 목록 | `pg_trgm` 있음, `pg_bigm` 목록에 없음(2026-10-15 확인) → 한국어 2-gram 확장은 1차에서 쓰지 않음 | https://supabase.com/docs/guides/database/extensions |
| 참여 시간(P2 참고) | Parse.ly 하트비트(`inc` 누적 초), 참여 = 영상 재생 또는(최근 상호작용 그리고 포커스). Chartbeat 평균 참여 시간 = 총 참여 시간 / 페이지뷰 | https://docs.parse.ly/engaged-time/ , https://help.chartbeat.com/hc/en-us/articles/360040970854-FAQ-Chartbeat-Engaged-Time-versus-Google-Analytics-visit-duration-metrics (2026-10-15 열람 확인) |
| 외부 검색(P2) | Meilisearch·Typesense 비교는 D-7 재검토 때 | 미확인 |
| 공공데이터포털(local-life) | 기상청 단기예보 조회서비스: 개발 계정 트래픽 10,000(일 기준으로 추정, 미확인), 격자 좌표 `nx`·`ny`, 발표 시각 `base_time`. 에어코리아 대기오염정보: 페이지 열람 차단(미확인). 신문사 지역별 1개 요청을 캐시해 공유(신문사 수 × 갱신 주기로 트래픽 계산) | https://www.data.go.kr/data/15084084/openapi.do (2026-10-15 열람 확인), https://www.data.go.kr/data/15073861/openapi.do (미확인) |

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 봇 UA 판정, 버킷 시각(UTC 정시 저장, KST 표시), 검색어 정규화(공백·특수문자·2글자 이하) |
| SQL | `most_read` 결과 = 버킷 합, 내림 기사 제외, anon 실행 가능·다른 표 접근 불가 |
| 부하 | 속보 시나리오(제안: 신문사 1곳 분당 3,000 비콘) 동안 비콘 오류율·DB CPU |
| E2E | 기사 열람 → 1분 안 많이 본 뉴스 반영, 검색으로 찾기, 대시보드 수치 |

## 6. 운영 점검표

- [ ] 비콘 오류율·거부율(봇·레이트 리밋) 일 지표
- [ ] `article_view_hourly` 크기 증가 추이, 오래된 버킷 일 단위 롤업·보관 정책(제안: 90일 뒤 일 합계로)
- [ ] 검색 p95 주간 확인, 느린 검색어 상위 목록(해시·집계만)
- [ ] 월 리포트 생성 성공(매월 1일)
- [ ] 공공데이터포털 트래픽 한도 80% 경고(local-life)

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| "용인시" 검색이 "용인시는" 기사를 못 찾음 | 'simple' 사전은 조사를 떼지 않음 | 접두 일치(`:*`) 확인, 제목 유사도 보조 |
| 2글자 지명 검색이 느림 | 트라이그램 없음 → 인덱스 전체 스캔 | 2글자 이하 분기 경로 사용 |
| 조회 수가 0으로 남음 | 광고 차단기가 `/api/r/view` 차단, 또는 Host 해석 실패 | 경로 이름 중립화(제안), 도메인 상태 확인 |
| 많이 본 뉴스가 하루 늦게 바뀜 | 캐시 태그 무효화 누락 | 5분 TTL과 이벤트 무효화 둘 다 확인 |
