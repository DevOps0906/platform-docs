# search 개발 지시서 (`@nomad/search`)

기획 정본: `products/_platform-core/common-modules/search.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

공용 색인 표, 한국어 부분 일치 검색(엔진 SR-D1), 필터·facet 개수·하이라이트, 공개 범위 판정, 동의어, 어댑터 등록과 색인 잡, 주간 재조정 잡, 검색 집계, 검색창·결과 컴포넌트.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0450_search.sql` | 표 3개, `upsert_document`, `delete_document`, `query`. 엔진별 색인은 `sql/engine/pgroonga.sql` 또는 `sql/engine/trgm.sql` 중 하나만 적용 |
| `src/server/adapters.ts`, `query.ts`, `reindex.ts` | 공개 API |
| `worker/handlers/search/index.ts`, `reconcile.ts` | 색인·재조정 |
| `src/ui/SearchBox.tsx`, `SearchResults.tsx`, `FacetFilters.tsx` | 화면 |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | 엔진 스파이크(0.5일): 대상 Supabase 프로젝트에서 `create extension pgroonga` 가능 여부, 한국어 시험 질의 30개(조사 붙은 단어, 2글자, 영문 혼합) 정확도 비교 | 결과를 `[DECISION] SR-D1`로 기록 |
| 2 | SQL + 공개 범위 판정(anon·최종 이용자·멤버) | 비공개 문서가 anon 결과에 0건 |
| 3 | 어댑터 등록, 색인 잡(멱등 키 `search.index:<source_type>:<id>:<updated_at>`) | 같은 이벤트 2회 → 1행 |
| 4 | facet 필터(허용 키 목록, 그 밖 `SR002`), 정렬 | local-news 섹션·지역·기간 필터 동작 |
| 5 | 재조정 잡, 집계 | 출처와 색인 건수 차이 0 |
| 6 | UI: 검색어 강조, 결과 없음 안내, 키보드 탐색 | axe 위반 0 |

## 4. 외부 서비스·공식 문서

| 주제 | 링크 |
|---|---|
| PGroonga | https://pgroonga.github.io |
| Supabase PGroonga 확장 | https://supabase.com/docs/guides/database/extensions/pgroonga |
| pg_trgm | https://www.postgresql.org/docs/current/pgtrgm.html |
| Supabase 전문 검색 | https://supabase.com/docs/guides/database/full-text-search |
| Meilisearch(외부 엔진 선택 시) | https://www.meilisearch.com/docs |

## 5. 제품 주입 값

`adapters`(예 local-news `news.article`, nomad-docs `docs.document`), `facetKeys`(허용 필터), `minQueryLength`, 결과 URL 생성 함수.

## 6. 테스트

시험 질의 세트 정확도(상위 5개 안에 정답 비율, 목표 제안 80%), 공개 범위 3종, 삭제 후 결과 0, 2만 자 초과 본문 잘림, 응답 시간(문서 10만 건에서 p95 300ms 이하, 제안).

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| "서울시"로 "서울시에서" 글이 안 나옴 | `simple` 전문 검색만 쓴 경우. PGroonga 또는 pg_trgm 색인이 적용됐는지 확인 |
| 결과 수와 facet 개수가 다름 | facet 계산에도 같은 공개 범위 조건을 넣어야 함 |
