# nomad-commerce 개발 방법 V2: 공용모듈 적용판 (NOMAD Commerce)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/nomad-commerce/nomad-commerce_develop.md`](../../develop/nomad-commerce/nomad-commerce_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `commerce` / `CM` |
| 개발 단계(`products/README.md` 개발 순서) | 3 |
| 채택 공용모듈 | compliance, media |
| 보류 공용모듈 | search |
| 이 제품의 역할 | 패키지 사용(구현하지 않음) |
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
| 이 제품에서 쓰는 곳 | 법적 문서(약관, 처리방침, AI 고지, 033), 생성 이미지 AI 표시 |
| 공용모듈이 대체하는 것 | 법적 문서 본문 → `policy_documents`, AI 생성 이미지 표시 판정 → `required_labels` |
| 제품에 남는 것 | 상세페이지 법적고지 템플릿(015, 셀러 상품 정보 고시), 마켓 금칙어 `commerce.banned_words` |
| 제품 주입 값 | `profileKind: kr_ecommerce` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 media (미디어 라이브러리, `media` 0250)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 상품 원본 이미지, 슬롯 이미지 엔진 결과(014), 등록 폼 업로드(023) |
| 공용모듈이 대체하는 것 | `commerce.market_images`의 저장 경로·크기·MIME → `media.assets`(+ `ai_generated` 표시), 업로드 API의 서명 URL·완료 검증 → media |
| 제품에 남는 것 | 슬롯 이미지 엔진(fal 제출·웹훅), 마켓 규격 리사이즈(`market_*` 프리셋은 제품 추가), `export_files` |
| 제품 주입 값 | `presets: { market_1000, market_780 }`(마켓 규격 확인 필요), `allowedMime` 이미지만 |
| 기획·개발 정본 | [`common-modules/media.md`](../../products/_platform-core/common-modules/media.md), [`_shared/modules/media.md`](../../develop/_shared/modules/media.md) |

### 2.3 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| search | 상품 DB 검색은 필터 목록으로 시작 | 상품이 계정당 1만 건을 넘을 때 |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013000250_media.sql                 ← 추가(패키지 변환본)
20261013001000_commerce_domain.sql       ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `commerce.market_images` | 파일 메타 컬럼 삭제 → `asset_id`(→ `media.assets`)와 마켓·슬롯 연결만 |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| CM-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 033 |
| CM-V2-02 | media 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W3 맨 앞 | W0 완료, `@nomad/media` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 014, 023 |
| CM-V2-03 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | CM-V2-01, CM-V2-02 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| CM-06-014 | 슬롯 이미지 엔진: fal 제출·웹훅 상관, birefnet, 플랜별 모델, Sto… | 연결 | 생성 결과를 `registerUpload` 대신 서버 등록(`media.register_generated`, 패키지 요청)으로 저장 |
| CM-06-023 | 등록 폼·업로드 API, 완성도 서버 계산, upload 핸들러, 상태 폴링 | 축소 | 서명 URL·완료 검증은 media |
| CM-06-033 | 법적 문서(약관, 처리방침, AI 고지)와 법률 검토 의뢰 패키지(반품 4코드, L… | 축소 | 법적 문서 본문은 `policy_documents` seed |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'commerce', ... }) — 2.1절 주입 값
src/lib/media/index.ts            createModule({ appId: 'commerce', ... }) — 2.2절 주입 값
supabase/seed.sql                 <스키마>.settings 행, 정책 문서 초안, 프리셋
```

공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.

## 6. 검증 추가 항목

- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색
- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색
- [ ] compliance: 가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시
- [ ] media: 같은 파일 두 번 업로드 시 같은 자산, 사본 프리셋 생성, 사용 중 자산 삭제 거부(`MD003`)
- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)

## 7. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |
| V2-CM-1 | AI 생성 이미지를 media에 서버 등록하는 API | media v1.1에 `registerGenerated` 추가 요청(업로드 없이 워커가 등록) |
