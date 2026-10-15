# search: 한국어 검색 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/search`, 스키마 `search`(0450~0499), 오류 코드 `SR###`. 출처: local-news M8의 기사 검색(`news.search_articles`, 열린 질문 MQ-6 필터 부족)과 필터·정렬 요구. 개발서 `docs/develop/_shared/modules/search.md`.

## 1. 문제

nomad-docs(문서·거래처), local-news(기사), nomad-commerce(상품 DB), flora(원고·자료), admin-suite(기관 데이터)가 검색을 요구한다. PostgreSQL 기본 전문 검색(`to_tsvector`)은 한국어 형태소를 모른다. "서울시에서"로 저장된 글이 "서울시"로 잘 안 찾아진다. 제품마다 `ILIKE '%…%'`로 때우면 느리고 정확도가 낮다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | 공용 색인 표(출처 종류·id), 한국어 부분 일치 검색, 필터(facets: 종류·태그·기간·제품별 키), 정렬(관련도·최신), 공개 범위(공개·최종 이용자·직원), 동의어, 색인 잡(이벤트 → upsert/삭제), 검색 기록(개인 식별 없이) |
| 확장 | 의미 검색(pgvector 하이브리드, 코어 AI 청크와 별도), 자동 완성, 오타 교정, 인기 검색어, 외부 엔진 어댑터 |
| 제품에 남김 | 색인 문서로 바꾸는 어댑터(`toSearchDocument`)는 각 제품·모듈이 작성 |
| 코어와 구분 | 코어 `core.match_ai_chunks`는 AI 답변용 RAG(조직 지식). search는 사람이 쓰는 검색창. 같은 데이터를 둘 다 색인할 수 있으나 표는 따로 |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `search.documents` | `id`, `org_id`, `app_id`, `source_type`(예 `editorial.entry`, `docs.document`, `commerce.product`), `source_id`, `visibility`(`public`, `end_users`, `staff`), `title`, `body_text`(태그 제거 본문, 앞 2만 자), `url`, `tags`(text[]), `facets`(jsonb), `published_at`, `updated_at`, `lang`(기본 `ko`), 색인 컬럼(엔진 선택 SR-D1에 따름) | 읽기: `search.query` 함수만(공개 범위 판정 포함). 쓰기: `search.upsert_document`, `search.delete_document`(service, 잡). unique(`source_type`, `source_id`) |
| `search.synonyms` | `org_id`(null = 공통), `app_id`, `term`, `synonyms`(text[]) | org admin |
| `search.query_stats` | `org_id`, `app_id`, `day`, `query_norm`(정규화 문자열), `searches`, `zero_result`, `clicks` | service 쓰기, org 멤버 읽기. 사용자 id·IP 저장 안 함 |

함수 `search.query(org, app, q, filters jsonb, sort, limit, offset)`는 호출자의 공개 범위를 서버에서 정한다(anon → `public`, 최종 이용자 → `public`+`end_users`, 조직 멤버 → 전부). 결과에는 하이라이트 조각과 facet 개수를 같이 준다.

오류 코드: `SR001` 질의가 너무 짧음(1글자, 제품 설정으로 조정), `SR002` 허용 밖 필터 키, `SR003` 색인 문서 크기 초과.

## 4. 한국어 검색 방식 (결정 SR-D1)

| 방식 | 장점 | 단점 | 확인 필요 |
|---|---|---|---|
| (a) PGroonga 확장 | 한국어·일본어 전문 검색에 강함, 부분 일치·하이라이트 | 확장 사용 가능 여부·버전은 Supabase 프로젝트에서 확인 | Supabase 확장 목록 |
| (b) pg_trgm(3글자 조각) + `simple` 전문 검색 | 기본 제공, 부분 일치, 설정 단순 | 2글자 이하 질의 약함, 관련도 거침 | - |
| (c) 외부 엔진(Meilisearch, Typesense 등) | 오타 허용·속도 | 서버 추가, DB와 동기화, RLS 밖이라 공개 범위를 직접 구현 | 요금·호스팅 |

권고: **(a) 우선, 쓸 수 없으면 (b)**. 문서 수가 제품당 수십만 건을 넘거나 오타 허용이 매출에 중요해지면 (c)를 어댑터로 추가. 공개 범위 판정은 어느 방식이든 `search.query` 안에서 한다.

## 5. 색인 흐름

| 단계 | 동작 |
|---|---|
| 1 | 소유 모듈이 게시·수정·비공개 이벤트 발행(예 `editorial.entry.published`) |
| 2 | 잡 `search.index`가 어댑터 `toSearchDocument(source)`로 문서 생성 → `upsert_document` |
| 3 | 비공개·삭제 이벤트 → `delete_document` |
| 4 | 주 1회 재조정 잡: 출처 표와 색인 건수 비교, 누락분 다시 색인 |

## 6. 공개 API (TS 계약 예시)

```ts
// @nomad/search/server
registerAdapter(sourceType: string, adapter: { load(id: string): Promise<unknown>; toSearchDocument(src: unknown): SearchDocument | null })
query(input: { appId; orgId; q: string; filters?: Record<string, string | string[]>; sort?: 'relevance' | 'recent'; page?: number }): Promise<SearchResult>
reindex(appId: string, orgId: string, sourceType?: string): Promise<{ queued: number }>
// @nomad/search/ui
<SearchBox appId /> <SearchResults result facets />
```

## 7. 실패 동작

색인 잡 실패는 재시도 후 실패 목록에 남기고 재조정 잡이 다시 처리. 검색 함수 오류는 빈 결과로 숨기지 않고 "검색을 잠시 쓸 수 없습니다" 안내.

## 8. local-news에서 옮기는 것

| local-news | 공용 |
|---|---|
| `news.search_articles` | `search.query` + 어댑터 `news.article` |
| 섹션·지역·기간 필터 부족(MQ-6) | `facets`(`section`, `region`) + `published_at` 범위 필터로 해결 |
| 많이 본 뉴스 | search가 아니라 editorial `most_viewed` |

## 9. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| SR-D1 | 한국어 검색 방식 | 4장 (a) → (b) |
| SR-D2 | 의미 검색 | 확장. 쓰기 시작하면 임베딩 비용은 크레딧 대상이 아니라 플랫폼 비용 |
| SR-D3 | 검색 기록 보존 | 일 단위 집계만, 원문 질의 90일(제안) |
