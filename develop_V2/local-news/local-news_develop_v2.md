# local-news 개발 방법 V2: 공용모듈 적용판 (로컬뉴스 클라우드(가칭))

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/local-news/local-news_develop.md`](../../develop/local-news/local-news_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `news` / `NW` |
| 개발 단계(`products/README.md` 개발 순서) | 6 |
| 채택 공용모듈 | compliance, media, community, search, membership, ads, editorial |
| 보류 공용모듈 | 없음 |
| 이 제품의 역할 | search 기준 구현, membership 기준 구현, ads 기준 구현 |
| 기존 공용모듈 | notify 보강분(뉴스레터·웹 푸시, 028·029), cms 보강분(배포·SEO, 033), tenancy(Theming, 005·039)는 기존 공용모듈 v1이 나와 있으면 그것을 쓰고, 없으면 V1(`news` 스키마)대로. |

## 1. 진행 순서

| 순서 | 할 일 | 문서 |
|---|---|---|
| 1 | V1 0~6장: 사전 준비, setup 스크립트, project-profile, 로컬 DB 기동 전까지 | V1 안내서 |
| 2 | 공용모듈 SQL 추가와 도메인 파일 이름 바꾸기, 제품 표 정리 | 이 문서 3장 |
| 3 | `06_AGENT_PLAN.md`에 V2 작업 추가, V1 작업 축소·대체 반영 → 개발 묶음 다시 만들기 | 이 문서 4장, V2_RULES 4장 |
| 4 | V1 8~10장 사이클로 웨이브 진행(V2 작업은 해당 웨이브 맨 앞) | V1 안내서 |
| 5 | 검증 추가 항목 | 이 문서 6장 |

## 2. 공용모듈 적용 상세

### 2.1 compliance (법정 표기·동의·라벨, `compliance` 0150)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 필요적 게재사항 10개·법정 푸터(022), 광고·AI 표시, 독자 가입 동의, 준수 데스크(034) |
| 공용모듈이 대체하는 것 | `news.newspapers` 법정 표기 필드·`news.is_profile_complete` → `legal_profiles`(`kr_newspaper`)·`is_profile_complete`, 라벨 CHECK → `labels_ok` |
| 제품에 남는 것 | 자체기사 비율, 정정·반론보도(`correction_requests`), 선거 모드(`election_periods`) |
| 제품 주입 값 | `profileKind: kr_newspaper`, `publishGuard: true` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 media (미디어 라이브러리, `media` 0250)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 기사 사진·대체 텍스트·출처·저작권 만료(014), 이관 사진(018) |
| 공용모듈이 대체하는 것 | `news.media_assets` → `media.assets` |
| 제품에 남는 것 | - |
| 제품 주입 값 | `requireAlt: true`, 프리셋 `og_1200x630`, `hero_1600` |
| 기획·개발 정본 | [`common-modules/media.md`](../../products/_platform-core/common-modules/media.md), [`_shared/modules/media.md`](../../develop/_shared/modules/media.md) |

### 2.3 community (댓글·방명록·신고, `community` 0350)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 기사 댓글, 신고, 임시조치, 금칙어(031) |
| 공용모듈이 대체하는 것 | `news.comments`, `comment_reports`, `newspapers.banned_words`·`comments_enabled` → `community.*` |
| 제품에 남는 것 | 경조사(`life_events`), 제보(`tips`, support 모듈 전까지 제품), 선거 댓글 정책(가드) |
| 제품 주입 값 | `targetTypes: [editorial.entry]`, 기본 댓글 끔(D-6) |
| 기획·개발 정본 | [`common-modules/community.md`](../../products/_platform-core/common-modules/community.md), [`_shared/modules/community.md`](../../develop/_shared/modules/community.md) |

### 2.4 search (한국어 검색, `search` 0450) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 기사 검색(섹션·지역·기간 필터, 035) |
| 공용모듈이 대체하는 것 | `news.search_articles` → `search.query` + 어댑터 `news.article` |
| 제품에 남는 것 | 지원사업 리포트(035 일부) |
| 제품 주입 값 | `facetKeys: [section, region]` |
| 기획·개발 정본 | [`common-modules/search.md`](../../products/_platform-core/common-modules/search.md), [`_shared/modules/search.md`](../../develop/_shared/modules/search.md) |

### 2.5 membership (최종 이용자·구독·후원, `membership` 0550) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 독자 행(023), 후원·유료 멤버십·페이월(024) |
| 공용모듈이 대체하는 것 | `news.readers`, `membership_tiers`, `memberships`, `donations`, `paywall_rules` → `membership.*` |
| 제품에 남는 것 | 기사 단위 페이월 문구 |
| 제품 주입 값 | `accessTargets: [news.article]`, 신문사 자기 Toss 가맹(D-4) |
| 기획·개발 정본 | [`common-modules/membership.md`](../../products/_platform-core/common-modules/membership.md), [`_shared/modules/membership.md`](../../develop/_shared/modules/membership.md) |

### 2.6 ads (광고, `ads` 0650) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 광고 슬롯·캠페인·소재 검수·집계(025), 외부 광고망(027) |
| 공용모듈이 대체하는 것 | `news.ad_slots`, `advertisers`, `ad_campaigns`, `ad_creatives`, `ad_daily_stats` → `ads.*` |
| 제품에 남는 것 | 업소 디렉토리·지자체 공고(026), 정부광고 직판 금지(NW013 → `AD003`) |
| 제품 주입 값 | `publicBodyDirectSale: false` |
| 기획·개발 정본 | [`common-modules/ads.md`](../../products/_platform-core/common-modules/ads.md), [`_shared/modules/ads.md`](../../develop/_shared/modules/ads.md) |

### 2.7 editorial (콘텐츠 워크플로, `editorial` 0750)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 기사 작성 → 데스크 승인 → 예약 → 게시 → 정정, 수정 이력, 미리보기, 조회 집계 |
| 공용모듈이 대체하는 것 | `news.articles` 공통 필드, `article_revisions`, `article_view_hourly`, 게시 RPC → `editorial.*` |
| 제품에 남는 것 | 기사 확장 표(유형·바이라인·섹션·지역·태그·`is_poll`), 홈 편집, 지면, 라이브 |
| 제품 주입 값 | `entryTypes: [news.article]`, 가드 `compliance.is_profile_complete:kr_newspaper`, `news.election_guard` |
| 기획·개발 정본 | [`common-modules/editorial.md`](../../products/_platform-core/common-modules/editorial.md), [`_shared/modules/editorial.md`](../../develop/_shared/modules/editorial.md) |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000002_tenant_theming.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013000250_media.sql                 ← 추가(패키지 변환본)
20261013000350_community.sql             ← 추가(패키지 변환본)
20261013000450_search.sql                ← 추가(패키지 변환본)
20261013000550_membership.sql            ← 추가(패키지 변환본)
20261013000650_ads.sql                   ← 추가(패키지 변환본)
20261013000750_editorial.sql             ← 추가(패키지 변환본)
20261013001000_local_news_domain.sql     ← 20261013000003에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `2500_news.sql` / 모놀리스 `0003` | 공용모듈로 옮긴 표 15개(`media_assets`, `article_revisions`, `article_view_hourly`, 독자·멤버십 5개, 광고 5개, 댓글 2개)를 지우고, `articles`·`newspapers`는 공통 컬럼을 뺀 확장 표로 다시 작성(4.1절 SQL 작업). 뉴스레터·푸시 표 4개는 notify v1이 나올 때까지 유지. 스모크 314개 중 옮긴 표 항목은 모듈 스모크로 이동 |
| 공용모듈 순서 | `…000002_tenant_theming` 다음에 공용모듈 7개, 도메인은 `…001000_local_news_domain.sql` |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| NW-V2-01 | `@nomad/search` v0.x 구현(`nomad-modules` 저장소). SQL·스모크는 W0, 서버·UI는 적용 웨이브까지 | W0 → W5 맨 앞 | W0 시작 | Opus | `_shared/modules/search.md` 3장 전부, 계약 테스트 녹색 |
| NW-V2-02 | `@nomad/membership` v0.x 구현(`nomad-modules` 저장소). SQL·스모크는 W0, 서버·UI는 적용 웨이브까지 | W0 → W5 맨 앞 | W0 시작 | Opus(+Fable 계획 검토) | `_shared/modules/membership.md` 3장 전부, 계약 테스트 녹색 |
| NW-V2-03 | `@nomad/ads` v0.x 구현(`nomad-modules` 저장소). SQL·스모크는 W0, 서버·UI는 적용 웨이브까지 | W0 → W4 맨 앞 | W0 시작 | Opus | `_shared/modules/ads.md` 3장 전부, 계약 테스트 녹색 |
| NW-V2-04 | `2500_news.sql`·모놀리스 `0003`을 확장 표만 남기도록 다시 작성(공용모듈 7개 변환본을 앞에), 스모크 재배치 | W0 | NW-V2-01, NW-V2-02, NW-V2-03 | Fable | SQL 체커 정순·역순, 제품 스모크 + 모듈 스모크 녹색 |
| NW-V2-05 | editorial 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 011, 012, 037 |
| NW-V2-06 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W3 맨 앞 | NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 022, 034 |
| NW-V2-07 | media 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W3 맨 앞 | NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 014 |
| NW-V2-08 | ads 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W4 맨 앞 | NW-V2-03, NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 025, 027 |
| NW-V2-09 | search 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W5 맨 앞 | NW-V2-01, NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 035 |
| NW-V2-10 | membership 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W5 맨 앞 | NW-V2-02, NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 023, 024 |
| NW-V2-11 | community 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W6 맨 앞 | NW-V2-04 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 031 |
| NW-V2-12 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | NW-V2-05, NW-V2-06, NW-V2-07, NW-V2-08, NW-V2-09, NW-V2-10, NW-V2-11 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| NW-06-001 | DB 적용: 모놀리스 0001~0003·seed를 로컬 Supabase에 적용, 변… | 축소 | DB 적용에 공용모듈 7개 변환본 포함, `news` 조각은 확장 표만 |
| NW-06-011 | M1 서버: 기사 저장·제출·검토·예약·게시·게시 취소·정정 RPC 래퍼(zod),… | 축소 | M1 서버는 editorial·media 위 기사 확장 RPC만 |
| NW-06-012 | M1 화면: 블록 에디터(문단·소제목·사진·인용·표·임베드), 메타 패널(유형·섹션… | 축소 | 에디터·데스크 화면은 editorial UI + 신문 워크플로 설정 |
| NW-06-014 | 미디어 라이브러리(서명 업로드, 파생본, alt·출처 필수, AI 생성 표시)와 지… | 대체 | media 적용 |
| NW-06-022 | 법정 표기: 매체정보 설정 화면, 법정 푸터 컴포넌트(전 페이지), 정책 페이지,… | 축소 | 법정 표기 판정은 compliance `kr_newspaper`, 법정 푸터 화면만 제품 |
| NW-06-023 | M2 독자: 독자 가입(`ensure_reader`, 동의·만 14세 확인), 독자… | 축소 | 독자 행은 membership `ensureEndUser` |
| NW-06-024 | M2 결제: 신문사 Toss 가맹 키 등록(암호화 저장), 후원·멤버십 결제, 웹훅… | 축소 | 결제·구독은 membership 기준 구현과 함께 |
| NW-06-025 | M3 광고: 슬롯·광고주·캠페인·소재 검수, `serve_ads`, 노출·클릭 집계… | 대체 | ads 기준 구현 + 적용 |
| NW-06-031 | M5 댓글: 작성·신고·임시조치(권리침해 주장 즉시 30일)·모더레이션(+AI 보조… | 대체 | community 적용 |
| NW-06-035 | M8 검색·분석: `/api/r/view`(봇 필터·IP 해시 레이트 리밋·묶음 증… | 축소 | 검색은 search 기준 구현, 조회 집계는 editorial |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'news', ... }) — 2.1절 주입 값
src/lib/media/index.ts            createModule({ appId: 'news', ... }) — 2.2절 주입 값
src/lib/community/index.ts        createModule({ appId: 'news', ... }) — 2.3절 주입 값
src/lib/search/index.ts           createModule({ appId: 'news', ... }) — 2.4절 주입 값
src/lib/membership/index.ts       createModule({ appId: 'news', ... }) — 2.5절 주입 값
src/lib/ads/index.ts              createModule({ appId: 'news', ... }) — 2.6절 주입 값
src/lib/editorial/index.ts        createModule({ appId: 'news', ... }) — 2.7절 주입 값
src/lib/search/adapters/          toSearchDocument 어댑터(색인 대상마다 1개)
src/lib/editorial/guards.ts       제품 게시 가드 함수 등록
supabase/seed.sql                 <스키마>.settings 행, 정책 문서 초안, 프리셋
```

공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.

## 6. 검증 추가 항목

- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색
- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색
- [ ] compliance: 가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시
- [ ] media: 같은 파일 두 번 업로드 시 같은 자산, 사본 프리셋 생성, 사용 중 자산 삭제 거부(`MD003`)
- [ ] community: 비회원 글·비밀번호 삭제, 금칙어 3동작, 신고 → 임시조치 → 기한 처리
- [ ] search: 비공개 문서가 anon 결과에 0건, 시험 질의 세트 정확도
- [ ] membership: 최종 이용자가 직원 표 0행, 테스트 키로 단건·정기·환불, 웹훅 중복 1회 반영
- [ ] ads: 라벨 없는 소재 승인 거부, 광고 없는 슬롯 높이 유지(CLS 0.1 이하), 클릭 토큰 위조 거부
- [ ] editorial: AI·service 주체 게시 거부(`ED002`), 예약 게시가 재시작 후에도 실행, 게시 후 캐시 무효화
- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)

## 7. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |
| V2-NW-1 | 공용모듈 v1.0이 없는 모듈(search·membership·ads)을 이 제품이 패키지로 만들지, `news` 스키마로 먼저 만들지 | 패키지로 만듦(기준 구현, CMX-1) |
