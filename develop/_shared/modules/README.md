# 공용모듈 개발 지시서 색인 (compliance · media · editorial · community · search · membership · ads)

작성일 2026-10-15. local-news에서 꺼낸 공용모듈 7개를 **어떻게 만들고, 어떻게 모든 제품에 적용하는가**를 다룹니다. "무엇을 만드는가"(표·함수·규칙)는 기획서 `products/_platform-core/common-modules/`가 정본이고, 이 폴더는 만드는 순서·패키지 구성·외부 서비스·테스트·적용 절차입니다. 형식은 소셜 로그인 지시서(`../auth/README.md`)와 같습니다.

| 모듈 | 개발서 | 기획서 | 첫 적용 제품(기준 구현) |
|---|---|---|---|
| compliance | [`compliance.md`](compliance.md) | `products/_platform-core/common-modules/compliance.md` | website-floria·study-note |
| media | [`media.md`](media.md) | `products/_platform-core/common-modules/media.md` | flora-publishing |
| editorial | [`editorial.md`](editorial.md) | `products/_platform-core/common-modules/editorial.md` | nomad-blog |
| community | [`community.md`](community.md) | `products/_platform-core/common-modules/community.md` | microweb-studio |
| search | [`search.md`](search.md) | `products/_platform-core/common-modules/search.md` | local-news |
| membership | [`membership.md`](membership.md) | `products/_platform-core/common-modules/membership.md` | local-news(앞 제품이 채택하면 그 제품) |
| ads | [`ads.md`](ads.md) | `products/_platform-core/common-modules/ads.md` | local-news |

## 1. 먼저 정할 것 (사람 결정)

| ID | 결정 | 권고 | 근거 |
|---|---|---|---|
| CMX-1 | 공용화 시점 | 계약 먼저, 첫 적용 제품이 처음부터 패키지로 | 기획서 `README.md` 6장 |
| CMX-2 | DB 번호 재배정(0100~0999를 50 단위로) | 채택 | 기획서 `README.md` 2장 |
| M-D2 | 배포 방식 | 비공개 npm(GitHub Packages) `@nomad/<모듈>`, 인증 모듈과 같은 방식 | `products/_platform-core/COMMON_MODULES_ROADMAP.md` 7장, `../auth/README.md` AUTH-D2 |
| CMX-3 | 검색 엔진 | Postgres(PGroonga → pg_trgm) | `search.md` |
| CMX-4 | 최종 이용자 결제 수취 | 고객사 자기 Toss 가맹 | `membership.md` |

## 2. 패키지 저장소 구성 (제안)

공용모듈은 제품 저장소가 아니라 별도 저장소 하나(`D:\WorkSpace\DEV\nomad-modules\`, pnpm workspace)에서 만듭니다. 기준 구현 제품은 이 저장소를 로컬 링크(`pnpm link`)로 쓰면서 함께 개발하고, v1.0부터 GitHub Packages로 배포합니다.

```
nomad-modules/
├── packages/
│   ├── compliance/   media/   editorial/   community/   search/   membership/   ads/
│   │   ├── src/server/index.ts      공개 서버 API(기획서 "공개 API")
│   │   ├── src/ui/                  React 서버·클라이언트 컴포넌트(shadcn/ui, Tailwind CSS v4 의미 토큰만)
│   │   ├── src/schema.ts            zod 입력 검증, 공용 타입
│   │   ├── sql/<번호>_<스키마>.sql   모듈러 통합 조각(정본)
│   │   ├── sql/to_monolith.py       단독 프로젝트용 public 변환(local-news 변환 스크립트와 같은 방식)
│   │   ├── sql/tests/rls_smoke.sql  RLS 스모크
│   │   ├── test/contract/           모든 제품이 그대로 돌리는 계약 테스트
│   │   └── CHANGELOG.md             버전마다 "제품이 할 일"
│   └── testing/                     공용 시드(조직 2개·멤버·최종 이용자·비회원), PGlite 러너
└── .github/workflows/               SQL 체커, 스모크, 타입·린트, 계약 테스트
```

| 규칙 | 내용 |
|---|---|
| 의존 방향 | compliance·media → (없음), community·editorial·ads → compliance·media, membership → compliance. 역방향 import 금지(기획서 `README.md` 4장) |
| 코어 | 코어 함수(`core.is_org_member`, `core.enqueue_job`, `core.write_audit`, `core.rate_limit_hit`, `core.encrypted_credentials`)는 호출만. 다시 만들지 않습니다 |
| 제품 주입 | 제품마다 다른 값은 `createModule({ appId, ... })` 초기화 옵션과 `<스키마>.settings` 행으로만. 패키지 안에 제품 이름 분기 금지 |
| UI | 디자인 토큰 의미 이름만(`--color-surface` 등). 테넌트 테마가 그대로 적용돼야 합니다(Multi-tenant Theming) |
| 문구 | 모든 사용자 노출 문구는 한국어, `src/ui/messages.ko.ts` 한 곳 |

## 3. 만드는 순서

의존이 없는 것부터, 첫 적용 제품의 개발 순서(`products/README.md` "개발 순서")에 맞춥니다.

| 차례 | 모듈 | 함께 개발하는 제품 | 끝나는 조건 |
|---|---|---|---|
| 1 | compliance v1(정책·동의·`kr_business` 프로필·라벨) | website-floria, study-note(1단계) | 두 제품 가입·푸터·마케팅 동의 동작, 계약 테스트 녹색 |
| 2 | media v1 | flora-publishing(2단계), 두 번째 적용 nomad-docs 또는 nomad-commerce | 업로드 → 사본 → 대체 텍스트 필수 동작 |
| 3 | editorial v1 | nomad-blog(3단계) | 초안 → 승인 → 예약 게시, AI 초안 사람 승인 강제 |
| 4 | community v1 | microweb-studio(4단계, 방명록) | 비회원 글·신고·임시조치 |
| 6 | search v1 | local-news(6단계) 또는 먼저 채택한 제품 | 한국어 부분 일치, 공개 범위 판정 |
| 6 | ads v1 | local-news(6단계) | 슬롯 높이 예약, 노출·클릭 집계, 리포트 CSV |
| 6 | membership v1 | local-news(6단계) 또는 먼저 채택한 제품 | 고객사 가맹 키로 정기결제·후원·페이월 |
| 6 | local-news 전환 | local-news | M1~M8을 공용 패키지로 바꿔도 E2E 녹색(`develop/local-news/modules/README.md`) |

모듈 하나를 만드는 작업 순서(모든 모듈 같음):

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 기획서 3장대로 SQL 조각 작성(번호는 기획서 `README.md` 2장) | SQL 체커(`products/_tools-sqlcheck/check.mjs`) 정순·역순 OK |
| 2 | RLS 스모크: 조직 2개 교차 누출 0, anon·최종 이용자·멤버별 허용·거부 | 스모크 전부 통과 |
| 3 | 모놀리스 변환 스크립트 + 변환본 스모크 | 모놀리스 스모크 통과 |
| 4 | `src/server/` 공개 API(zod 검증, 오류 코드 → 사용자 문구 매핑) | 단위 테스트 |
| 5 | 잡 핸들러(워커 `handlers/<모듈>/`)와 이벤트 | 재시도·멱등 테스트 |
| 6 | `src/ui/` 컴포넌트 + 접근성 검사(axe) | 위반 0 |
| 7 | 계약 테스트 `test/contract/` | 녹색 |
| 8 | 기준 구현 제품에 적용(5장 절차) | 제품 E2E 녹색 |
| 9 | v1.0 출시(사람 승인) | `CHANGELOG.md` |

## 4. 버전과 출시

| 버전 | 들어가는 것 | 출시 조건 |
|---|---|---|
| v0.x | 기준 구현 제품과 함께 개발(로컬 링크) | 기준 제품 E2E 녹색 |
| v1.0 | 기획서 MVP 전부, 계약 테스트, 모놀리스 변환 | 두 번째 제품이 설치만으로 동작(제품 코드는 주입 파일·어댑터만) |
| v1.x | 기획서 "확장" 항목 | 계약 테스트 추가 |

- semver. 표·함수 이름이나 주입 값이 바뀌면 메이저를 올리고 SQL 이전 스크립트를 함께 냅니다.
- 출시는 사람 승인 후. 에이전트는 PR까지만 만듭니다. 제품은 정확한 버전으로 고정합니다(`latest` 금지).

## 5. 모든 제품에 적용하기

### 5.1 적용표

어떤 제품에 어떤 모듈을 쓰는지는 기획서 `products/_platform-core/common-modules/README.md` 1장(15개 제품 × 11개 모듈)이 정본입니다. 각 제품 기획 문서는 이번에 고치지 않았습니다(대표님 결정 A). **제품 개발을 시작할 때** 아래 절차의 1번에서 그 제품 문서에 반영합니다.

### 5.2 제품 하나에 적용하는 절차 (에이전트 작업 1개)

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 적용표 ●·○ 확인 → 채택 결정을 task `log.md`에 `[DECISION]`으로 → 그 제품 `06_AGENT_PLAN.md` 공용 모듈 요청 표에 소비 행(모듈, 버전, 쓰는 기능 ID) 추가 | 기획 문서 갱신 후 `build_root.py <제품>` 경로 누락 0 |
| 2 | DB: 모듈러 통합이면 조각을 `products/_supabase-modular/migrations/`에, 단독 프로젝트면 변환본을 `supabase/migrations/`에(제품 도메인 마이그레이션보다 앞 번호) | `supabase db reset` + 모듈 스모크 |
| 3 | `pnpm add @nomad/<모듈>@<정확한 버전>` | lockfile 커밋 |
| 4 | 제품 주입 파일 `src/lib/<모듈>/index.ts` 1개(`appId`, 설정, 어댑터·가드 등록) | 빌드 녹색 |
| 5 | seed: `<스키마>.settings` 행, 제품용 프리셋·라벨 위치·정책 문서 초안 | 시드 2회 멱등 |
| 6 | 제품 확장 표(필요할 때만)와 어댑터(search `toSearchDocument`, editorial 가드, 캐시 무효화 콜백) | 단위 테스트 |
| 7 | 계약 테스트를 제품 CI에 연결 + 제품 E2E | 녹색 |
| 8 | 같은 기능의 제품 자체 구현이 있으면 제거(호환 뷰는 한 릴리스) | 금지 패턴 검사 |

패키지가 새 버전을 내면 3·7번만 다시 합니다.

### 5.3 제품별 메모

| 제품 | 주의 |
|---|---|
| website-floria | compliance 기준 구현. 방문자 로그인 없음 → 문의·뉴스레터 동의 기록(subject `email`)과 푸터. 이미지는 정적 자산이라 media 미적용 |
| study-note | membership(유료 강좌)은 lms 모듈 착수 때 함께 판단 |
| flora-publishing | media 기준 구현(원고·표지 업로드). 인쇄용 산출물(PDF·ePub)은 media 밖 |
| nomad-blog | editorial 기준 구현. 외부 플랫폼 발행(네이버·티스토리)은 제품 기능으로 editorial `published` 이벤트를 구독 |
| microweb-studio | community 방명록은 비회원 + 비밀번호. 하객 개인정보 최소 수집 |
| live-poll | 지금 기획에 광고 기능이 없어 ads는 후보만. 실시간 Q&A는 community 금칙어 검사만 쓰고 전달·검수 화면은 제품 것 |
| toon-factory | 유료 회차를 하면 membership `access_rules`(target `toon.episode`) |
| admin-suite | hms는 의료정보 격리로 공용모듈 표에 환자 데이터를 넣지 않음(compliance 동의 기록만) |
| arch-studio | 설치형. 라이선스 서버 쪽에서 compliance(약관·동의)만 |
| local-news | 모든 모듈의 출처. 1차는 `news` 스키마로 만들고 공용 v1.0이 나오면 전환(`develop/local-news/modules/README.md`) |

### 5.4 적용 현황표 (개발 시작 후 갱신)

| 제품 | compliance | media | editorial | community | search | membership | ads |
|---|---|---|---|---|---|---|---|
| (제품마다 1행) | 버전 | | | | | | |

## 6. 테스트 공통

| 층 | 내용 |
|---|---|
| SQL | 체커 정순·역순, RLS 스모크(교차 조직 누출 0, 역할별 허용·거부, `FOR ALL` 0, `search_path` 없는 DEFINER 0) |
| 계약 | 공개 API 입력 검증, 오류 코드, 멱등(같은 키 2회), 상태 전이 표 전부 |
| 제품 | 기준 구현 제품 E2E(Playwright), 접근성(axe), 성능(LCP·CLS: media·ads) |

## 7. 공식 문서 링크

| 주제 | 링크 |
|---|---|
| Supabase RLS | https://supabase.com/docs/guides/database/postgres/row-level-security |
| Supabase Storage(서명 업로드 URL) | https://supabase.com/docs/guides/storage |
| Supabase 이미지 변환 | https://supabase.com/docs/guides/storage/serving/image-transformations |
| Supabase pg_cron | https://supabase.com/docs/guides/database/extensions/pg_cron |
| Supabase 전문 검색 | https://supabase.com/docs/guides/database/full-text-search |
| GitHub Packages(npm) | https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-npm-registry |
| 국가법령정보센터 | https://www.law.go.kr |
