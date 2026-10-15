# develop_V2 공통 규칙: 공용모듈을 쓰는 개발 방법

작성일 2026-10-15. 제품별 V2 개발서(`develop_V2/<제품>/<제품>_develop_v2.md`)가 모두 따르는 규칙입니다. 제품 문서에는 이 규칙을 반복하지 않고 그 제품에만 해당하는 값만 적습니다.

## 1. V1과 V2의 관계

| 항목 | V1(`develop/<제품>/`) | V2(`develop_V2/<제품>/`) |
|---|---|---|
| 설치 스크립트, 개발 묶음(`<제품>-root`) | 그대로 씀 | 새로 만들지 않음 |
| 사전 준비, project-profile, 로컬 DB, 결정, AI 계층, 위키, 디자인, 인증 | V1 안내서 각 장 | V1 그대로 |
| 법정 표기·동의, 미디어, 콘텐츠 워크플로, 댓글·방명록, 검색, 최종 이용자 구독, 광고 | 제품이 직접 구현 | **공용모듈 패키지를 설치하고 주입 값·어댑터만 작성** |
| 작업 계획 | `06_AGENT_PLAN.md` 작업 | 06장 작업 + V2 작업(`<접두어>-V2-NN`), 일부 V1 작업은 축소·대체 |

두 문서가 다르면 V2가 우선합니다. V2를 쓰지 않고 V1만으로 개발해도 되지만, 그 경우 해당 기능을 나중에 공용모듈로 옮기는 전환 작업이 생깁니다.

## 2. 공용모듈 요약

기획 정본 `products/_platform-core/common-modules/`, 개발 정본 `develop/_shared/modules/`.

| 모듈 | 패키지 | 스키마(모듈러 번호) | 모놀리스 파일 이름(V2) | 기준 구현 제품 |
|---|---|---|---|---|
| compliance | `@nomad/compliance` | `compliance`(0150) | `20261013000150_compliance.sql` | website-floria(두 번째 study-note) |
| media | `@nomad/media` | `media`(0250) | `20261013000250_media.sql` | flora-publishing |
| community | `@nomad/community` | `community`(0350) | `20261013000350_community.sql` | microweb-studio |
| search | `@nomad/search` | `search`(0450) | `20261013000450_search.sql` | local-news |
| membership | `@nomad/membership` | `membership`(0550) | `20261013000550_membership.sql` | local-news |
| ads | `@nomad/ads` | `ads`(0650) | `20261013000650_ads.sql` | local-news |
| editorial | `@nomad/editorial` | `editorial`(0750) | `20261013000750_editorial.sql` | nomad-blog |

기존 공용모듈 보강분(notify 뉴스레터·웹 푸시, analytics 콘텐츠 이벤트, cms 블록·SEO, tenancy 최종 이용자 분리)은 `products/_platform-core/COMMON_MODULES_ROADMAP.md` 4.11절을 따릅니다.

## 3. DB 규칙

| 규칙 | 내용 |
|---|---|
| 적용 순서 | 코어(`…000001_core_lite`) → (local-news만) 테넌트 테마(`…000002`) → 공용모듈(`…000150`~`…000750`, 번호 순) → 제품 도메인(`…001000` 이후) |
| 파일 이름 바꾸기 | V1 묶음의 제품 도메인 파일 `20261013000002_<제품>_domain.sql`을 `20261013001000_<제품>_domain.sql`로 바꿉니다(두 번째 도메인 파일이 있으면 `…001001`). **원격 DB에 한 번도 push 하지 않은 상태에서만** 합니다. 이미 push 했다면 이름을 바꾸지 말고 공용모듈을 새 마이그레이션(현재 시각 타임스탬프)으로 추가합니다 |
| 공용모듈 SQL 출처 | 패키지 안 `sql/monolith/<번호>_<스키마>.sql`(모놀리스 변환본)을 복사. 직접 고치지 않습니다. 고칠 일이 있으면 `nomad-modules` 저장소에 요청 |
| 모듈러 통합 DB | 조각 `products/_supabase-modular/migrations/<번호>_<스키마>.sql`이 정본(공용모듈 v1.0 출시 때 추가) |
| 제품 표 변경 | 공용모듈로 옮기는 표·컬럼은 제품 도메인 SQL에서 지우고, 제품 전용 필드만 확장 표(공용 표 id를 FK로)로 남깁니다. 개발 전이므로 호환 뷰는 필요 없습니다 |
| 검증 | `supabase db reset` → 제품 RLS 스모크 + 모듈 스모크(패키지 `sql/tests/`) 모두 통과 |

## 4. V2 작업 만들기

| 종류 | ID | 웨이브 | 모델 | 수용 기준 |
|---|---|---|---|---|
| 공용 패키지 구현(기준 구현 제품만) | `<접두어>-V2-NN` | 그 모듈을 쓰는 첫 V1 작업과 같은 웨이브, 맨 앞 | Opus(compliance·membership은 착수 전 Fable 계획 검토) | `develop/_shared/modules/<모듈>.md` 3장 전부, 계약 테스트 녹색, `nomad-modules` 저장소 PR |
| 공용모듈 적용 | `<접두어>-V2-NN` | 위와 같은 웨이브, 패키지 구현 다음 | Sonnet | `develop/_shared/modules/README.md` 5.2절 1~7번 |
| V2 전환 점검 | `<접두어>-V2-NN`(마지막) | E2E 작업과 같은 웨이브 | Sonnet | 모듈 계약 테스트를 제품 CI에 연결, 제품 E2E 녹색, 자체 구현 잔재 0(금지 패턴 검사) |

- V2 작업은 `06_AGENT_PLAN.md` 2절 작업 표 맨 아래에 추가하고, 3절 웨이브 표의 해당 웨이브 칸에 ID를 넣습니다. 이때 V1 작업의 선행 조건에 V2 작업 ID를 더합니다(개발서 4.2절 "변경" 열).
- **축소**: V1 작업 범위에서 공용모듈이 맡는 부분을 지우고 남는 제품 고유 부분만 수용 기준에 남깁니다. **대체**: V1 작업을 V2 적용 작업으로 바꾸고 V1 행은 "V2로 대체"로 표시합니다. **연결**: 범위는 그대로, 공용모듈 API를 쓰도록 수용 기준에 한 줄 추가합니다.
- 기획 문서를 고친 뒤 `develop/_shared/tools/build_root.py <제품>`으로 개발 묶음을 다시 만들고 경로 누락 0을 확인합니다.

## 5. 요청 프롬프트 (V2 적용 작업 예시)

```
D:/WorkSpace/DEV/<제품>/docs/file 의 산출물 중 baseline 으로 지정한 파일만 읽고 분석한다.
추가로 D:/WorkSpace/platform/docs/develop_V2/<제품>/<제품>_develop_v2.md 2장 해당 모듈 절과
D:/WorkSpace/platform/docs/develop/_shared/modules/<모듈>.md 5장(제품 주입 값)을 읽는다.

[요구사항]
<접두어>-V2-NN: @nomad/<모듈>@<버전>을 설치하고 제품 주입 파일 src/lib/<모듈>/index.ts, settings seed, 어댑터를 작성한다.
완료 조건 = develop/_shared/modules/README.md 5.2절 1~7번, 모듈 계약 테스트와 제품 RLS 스모크 녹색.

[작업의 특성]
작업 대상 경로: src/lib/<모듈>/, supabase/migrations/(공용모듈 변환본 복사만), supabase/seed.sql
공용모듈 SQL·패키지 코드는 고치지 않는다. 필요하면 log.md 에 요청으로 남긴다.

승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남긴다.
```

## 6. 공용모듈 저장소가 아직 없을 때

| 상황 | 할 일 |
|---|---|
| 기준 구현 제품 | 이 제품이 `D:\WorkSpace\DEV\nomad-modules\`(pnpm workspace)를 만들고 패키지 v0.x를 함께 개발합니다(`develop/_shared/modules/README.md` 2장). 제품은 `pnpm link`로 씁니다 |
| 그 밖의 제품 | 패키지 v1.0이 없으면 V1 방식으로 개발하고, 그 기능의 V1 작업에 "공용모듈 v1.0 출시 후 전환" 메모를 남깁니다. 또는 그 모듈을 쓰는 웨이브를 v1.0 출시 뒤로 미룹니다 |

## 7. 개발서 다시 만들기

제품별 V2 개발서는 `develop_V2/_shared/tools/gen_v2.py`가 만듭니다(제품 데이터는 스크립트 안 `PRODUCTS`). V1 작업 이름과 웨이브는 각 제품 `06_AGENT_PLAN.md`에서 읽어 오므로, 06장을 고친 뒤 `python -I gen_v2.py`를 다시 실행하면 V2 작업의 웨이브가 따라 바뀝니다.
