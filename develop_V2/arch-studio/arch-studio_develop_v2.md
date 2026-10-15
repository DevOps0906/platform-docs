# arch-studio 개발 방법 V2: 공용모듈 적용판 (Arch Studio(가칭))

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). 이 제품은 아직 V1 개발 묶음(`develop/arch-studio/`)이 없습니다. 06장을 쓸 때 이 문서의 공용모듈 결정을 반영합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `arch` / `AR` |
| 개발 단계(`products/README.md` 개발 순서) | 설치형(미정) |
| 채택 공용모듈 | compliance |
| 보류 공용모듈 | media, search |
| 이 제품의 역할 | 패키지 사용(구현하지 않음) |
| 기존 공용모듈 | 06장(작업 계획)이 아직 없어 V2 작업은 06장 작성 때 이 문서를 보고 만든다. |

## 1. 진행 순서

| 순서 | 할 일 | 문서 |
|---|---|---|
| 1 | 06장 작성: 이 문서 2·4장을 반영 | `products/arch-studio/` |
| 2 | 공용모듈 SQL 추가와 도메인 파일 이름 바꾸기, 제품 표 정리 | 이 문서 3장 |
| 3 | `06_AGENT_PLAN.md`에 V2 작업 추가, V1 작업 축소·대체 반영 → 개발 묶음 다시 만들기 | 이 문서 4장, V2_RULES 4장 |
| 4 | V1 8~10장 사이클로 웨이브 진행(V2 작업은 해당 웨이브 맨 앞) | V1 안내서 |
| 5 | 검증 추가 항목 | 이 문서 6장 |

## 2. 공용모듈 적용 상세

### 2.1 compliance (법정 표기·동의·라벨, `compliance` 0150)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 웹 가입·라이선스 구매 약관, 처리방침, AI 이용 안내(라이선스 서버 쪽) |
| 공용모듈이 대체하는 것 | - |
| 제품에 남는 것 | 설치형 앱 안의 오프라인 고지 문구 |
| 제품 주입 값 | `profileKind: kr_ecommerce`(시리얼 라이선스 판매) |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| media | 렌더 이미지는 사용자 PC에 저장 | 클라우드 렌더 갤러리를 만들 때 |
| search | 설치형 앱 안 검색은 로컬 | - |

## 3. DB 변경

| 대상 | 변경 |
|---|---|
| - | 라이선스 서버 DB에 compliance 변환본만 |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| AR-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W1 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: - |
| AR-V2-02 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | AR-V2-01 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

V1 작업 변경 없음(06장 작성 때 반영).

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'arch', ... }) — 2.1절 주입 값
supabase/seed.sql                 <스키마>.settings 행, 정책 문서 초안, 프리셋
```

공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.

## 6. 검증 추가 항목

- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색
- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색
- [ ] compliance: 가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시
- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)

## 7. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |
