# admin-suite 개발 방법 V2: 공용모듈 적용판 (Admin Suite)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/admin-suite/admin-suite_develop.md`](../../develop/admin-suite/admin-suite_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `erp, sms, hms` / `ADM` |
| 개발 단계(`products/README.md` 개발 순서) | 5 |
| 채택 공용모듈 | compliance |
| 보류 공용모듈 | media, search |
| 이 제품의 역할 | 패키지 사용(구현하지 않음) |
| 기존 공용모듈 | notify(SMS 알림, 032)는 기존 로드맵대로. hms는 의료정보 격리로 공용모듈 표 사용을 compliance 동의 기록에만 한정. |

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
| 이 제품에서 쓰는 곳 | erp·sms·hms 로그인 화면의 약관·처리방침 동의(014, 022, 029), 기관 사업자 표기 |
| 공용모듈이 대체하는 것 | 가입 동의 기록 → `compliance.consents` |
| 제품에 남는 것 | hms 의료정보 동의·열람 기록(의료법 영역, hms 제품 표) |
| 제품 주입 값 | `profileKind: kr_business`. hms는 compliance 표에 환자 정보를 넣지 않고 직원 동의만 |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| media | SMS 자산 이식(029)은 정적 이미지 | - |
| search | 기관 데이터 검색은 제품 목록 필터 | - |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
supabase/erp/migrations/
  20261013000001_core_lite.sql
  20261013000150_compliance.sql          ← 추가
  20261013001000_erp_domain.sql        ← 20261013000002에서 이름 변경
supabase/sms/migrations/
  20261013000001_core_lite.sql
  20261013000150_compliance.sql          ← 추가
  20261013001000_sms_domain.sql        ← 20261013000002에서 이름 변경
supabase/hms/migrations/
  20261013000001_core_lite.sql
  20261013000150_compliance.sql          ← 추가
  20261013001000_hms_domain.sql        ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| 3개 앱 모두 | 제품 표 변경 없음. 앱 폴더(`supabase/erp`, `sms`, `hms`)마다 compliance 변환본 추가 |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| ADM-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W4 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 014, 022, 029 |
| ADM-V2-02 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | ADM-V2-01 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| ADM-06-014 | ERP 로그인 화면(A 구성)·가입 코드 대기 화면(승인제). 이메일 가입 폼·비밀… | 연결 | erp 가입 동의를 compliance로 |
| ADM-06-022 | HMS 로그인 화면(A 구성)·초대 수락·직원 관리. 초대 메일 비밀번호 설정은 0… | 연결 | hms 직원 초대 수락 동의를 compliance로 |
| ADM-06-029 | SMS HEAD 자산 이식 + 로그인 화면(A 구성)·초대 수락. 초대 메일 비밀번… | 연결 | sms 동의를 compliance로 |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'erp', ... }) — 2.1절 주입 값
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
