# nomad-blog 개발 방법 V2: 공용모듈 적용판 (NOMAD Blog)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/nomad-blog/nomad-blog_develop.md`](../../develop/nomad-blog/nomad-blog_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `blog` / `BL` |
| 개발 단계(`products/README.md` 개발 순서) | 3 |
| 채택 공용모듈 | compliance, media, editorial |
| 보류 공용모듈 | community, search, ads |
| 이 제품의 역할 | editorial 기준 구현 |
| 기존 공용모듈 | notify, analytics, cms(랜딩)는 기존 로드맵대로. |

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
| 이 제품에서 쓰는 곳 | 채널 위험 동의 모달(023), 랜딩·약관·처리방침(026), 대가성 문구 설정(027), AI 작성 원고 표시 |
| 공용모듈이 대체하는 것 | `blog.channel_accounts.automation_risk_consented_at`·`_by` → `compliance.consents`(purpose `blog.channel_risk`), AI·대가성 표시 판정 → `required_labels` |
| 제품에 남는 것 | 대가성 문구 편집 화면(027, 코어 `upsert_affiliate_disclosure`), 금지 표현 체크리스트(036) |
| 제품 주입 값 | `profileKind: kr_ecommerce`, 라벨 위치 `ai_assisted: footer` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 media (미디어 라이브러리, `media` 0250)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 원고 이미지·대표 이미지(워드프레스 어댑터 대표 이미지, 013), 원고 목록 썸네일 |
| 공용모듈이 대체하는 것 | 원고 본문의 이미지 URL 직접 저장 → `media.assets` + `usages`(owner `editorial.entry`) |
| 제품에 남는 것 | 외부 플랫폼 업로드(각 어댑터가 media 사본 URL을 받아 업로드) |
| 제품 주입 값 | `presets: { blog_1200 }`, `requireAlt: true`(SEO) |
| 기획·개발 정본 | [`common-modules/media.md`](../../products/_platform-core/common-modules/media.md), [`_shared/modules/media.md`](../../develop/_shared/modules/media.md) |

### 2.3 editorial (콘텐츠 워크플로, `editorial` 0750) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 원고 상태(초안 → 검토 → 예약 → 발행), 예약 발행, 원고 목록·캘린더(021), 수정 이력 |
| 공용모듈이 대체하는 것 | `blog.posts`의 제목·본문·상태·예약 시각·AI 표시 → `editorial.entries`(entry_type `blog.post`), 발행 오케스트레이션의 상태 전이(014) → `editorial.transition` |
| 제품에 남는 것 | `blog.posts` 확장 표(채널, 키워드, 브랜드커넥트 연결), `post_publications`(채널별 외부 발행 기록), `post_affiliate_links`, 월 발행 한도(005 → 가드 `blog.monthly_quota_guard`) |
| 제품 주입 값 | `entryTypes: [blog.post]`, 워크플로 `draft → scheduled → published`(검토 단계 생략, 1인 사용자), `onPublished`: 채널별 발행 잡 enqueue, 가드 `blog.monthly_quota_guard` |
| 기획·개발 정본 | [`common-modules/editorial.md`](../../products/_platform-core/common-modules/editorial.md), [`_shared/modules/editorial.md`](../../develop/_shared/modules/editorial.md) |

### 2.4 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| community | 글이 외부 플랫폼(네이버·티스토리·워드프레스)에 게시돼 댓글도 외부 | - |
| search | 원고 목록 필터로 충분 | 원고가 계정당 수천 건을 넘을 때 |
| ads | 자체 사이트 광고 슬롯이 없음 | - |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013000250_media.sql                 ← 추가(패키지 변환본)
20261013000750_editorial.sql             ← 추가(패키지 변환본)
20261013001000_blog_domain.sql           ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `blog.posts` | 공통 필드(제목·본문·상태·예약·발행 시각·AI 표시) 삭제, `entry_id`(→ `editorial.entries`, PK 겸 FK) + 블로그 전용 필드만 남김 |
| `blog.channel_accounts` | 위험 동의 컬럼 2개 삭제 → `compliance.consents` |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| BL-V2-01 | media 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | W0 완료, `@nomad/media` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 013, 021 |
| BL-V2-02 | `@nomad/editorial` v0.x 구현(`nomad-modules` 저장소) | W2 맨 앞 | W0 완료 | Opus | `_shared/modules/editorial.md` 3장 전부, 계약 테스트 녹색 |
| BL-V2-03 | editorial 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | BL-V2-02 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 014, 021, 005 |
| BL-V2-04 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W3 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 023, 026, 027 |
| BL-V2-05 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | BL-V2-01, BL-V2-03, BL-V2-04 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| BL-06-014 | 발행 오케스트레이션: publish/cancel/retry/resolve 라우트,… | 축소 | 상태 전이·예약은 editorial. 제품은 채널별 발행·취소·재시도(외부 API) |
| BL-06-021 | 대시보드, 원고 목록, 캘린더 UI(서버 컴포넌트 + 실데이터) | 축소 | 상태 배지·전이 버튼·예약 대화상자·이력은 editorial UI, 캘린더 레이아웃만 제품 |
| BL-06-005 | features 해석, 월 발행 한도(`monthly_post_usage`), 채널… | 연결 | 월 발행 한도를 editorial 게시 가드로 등록 |
| BL-06-023 | 채널 화면과 위험 동의 모달(스크롤 완독, 체크 3개, 입력 확인) | 연결 | 동의 기록을 compliance로 |
| BL-06-013 | 워드프레스 REST 어댑터(태그, 대표 이미지, Yoast 메타 선택) | 연결 | 대표 이미지는 media 사본 URL 사용 |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'blog', ... }) — 2.1절 주입 값
src/lib/media/index.ts            createModule({ appId: 'blog', ... }) — 2.2절 주입 값
src/lib/editorial/index.ts        createModule({ appId: 'blog', ... }) — 2.3절 주입 값
src/lib/editorial/guards.ts       제품 게시 가드 함수 등록
supabase/seed.sql                 <스키마>.settings 행, 정책 문서 초안, 프리셋
```

공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.

## 6. 검증 추가 항목

- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색
- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색
- [ ] compliance: 가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시
- [ ] media: 같은 파일 두 번 업로드 시 같은 자산, 사본 프리셋 생성, 사용 중 자산 삭제 거부(`MD003`)
- [ ] editorial: AI·service 주체 게시 거부(`ED002`), 예약 게시가 재시작 후에도 실행, 게시 후 캐시 무효화
- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)

## 7. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |
| V2-BL-1 | 검토 단계를 둘지 | 1인 사용자 기본은 생략, 팀 플랜에서 켬(워크플로 org 덮어쓰기) |
