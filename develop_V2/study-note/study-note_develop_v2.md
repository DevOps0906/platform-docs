# study-note 개발 방법 V2: 공용모듈 적용판 (Study Note)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/study-note/study-note_develop.md`](../../develop/study-note/study-note_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `notes` / `NT` |
| 개발 단계(`products/README.md` 개발 순서) | 1 |
| 채택 공용모듈 | compliance |
| 보류 공용모듈 | community, search, membership |
| 이 제품의 역할 | compliance 두 번째 적용(v1.0 출시 조건 검증) |
| 기존 공용모듈 | notify(가입·작업 완료 알림), analytics(전환 이벤트)는 기존 공용모듈 로드맵대로. |

## 1. 진행 순서

| 순서 | 할 일 | 문서 |
|---|---|---|
| 1 | V1 0~6장: 사전 준비, setup 스크립트, project-profile, 로컬 DB 기동 전까지 | V1 안내서 |
| 2 | 공용모듈 SQL 추가와 도메인 파일 이름 바꾸기, 제품 표 정리 | 이 문서 3장 |
| 3 | `06_AGENT_PLAN.md`에 V2 작업 추가, V1 작업 축소·대체 반영 → 개발 묶음 다시 만들기 | 이 문서 4장, V2_RULES 4장 |
| 4 | V1 8~10장 사이클로 웨이브 진행(V2 작업은 해당 웨이브 맨 앞) | V1 안내서 |
| 5 | 검증 추가 항목 | 이 문서 6장 |

## 2. 공용모듈 적용 상세

### 2.1 compliance (법정 표기·동의·라벨, `compliance` 0150) — 두 번째 적용(v1.0 출시 조건 검증)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 약관·개인정보처리방침 페이지와 첫 실행 동의 모달(021), 설정 화면의 동의 API(013 일부), AI 고지문(국외 이전·음성 처리·강의 녹음, 052) |
| 공용모듈이 대체하는 것 | 자체 동의 저장과 고지문 버전 관리 → `compliance.consents`, `policy_documents`(kind `terms`, `privacy`, `ai_notice`) |
| 제품에 남는 것 | 강의 녹음 시작 전 고지 모달의 흐름(045, 051)과 녹음 원본 처리 |
| 제품 주입 값 | `profileKind: kr_business`(플랫폼 운영자 표기, 플랫폼 공통 행), `signupConsents: { required: [terms, privacy], optional: [marketing_email, cross_border_ai] }` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| community | 질문 게시판이 아직 기획에 없음 | 과목별 Q&A를 만들 때 |
| search | 보관함 날짜·키워드 검색(019)은 본인 노트만 대상이라 제품 쿼리로 충분 | 노트가 사용자당 수천 건을 넘거나 공유 노트가 생길 때 |
| membership | 유료 강좌가 아직 기획에 없음 | lms 모듈 착수 때 함께 |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013001000_study_note_domain.sql     ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `notes.*` | 변경 없음(동의를 따로 저장하는 표가 없음). 동의 기록은 `compliance.consents`에 새로 쌓는다 |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| NT-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 021, 013, 052 |
| NT-V2-02 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | NT-V2-01 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| NT-06-021 | 약관/개인정보처리방침 페이지, 첫 실행 동의 모달 | 축소 | 약관·처리방침 본문은 `compliance.policy_documents` seed, 화면은 `ConsentCheckboxes`·`LegalFooter` 사용. 페이지 레이아웃만 제품 작업 |
| NT-06-013 | API: 모델 목록, 설정, 동의, 내보내기, 계정 삭제 | 연결 | 동의 API는 `recordConsent`·`hasConsent` 호출로 |
| NT-06-052 | AI 고지문: 국외 이전, 음성 처리, 강의 녹음(제3자), 업로드 권한 고지 문구… | 축소 | AI 고지문은 `policy_documents`(kind `ai_notice`) 버전으로 관리, 재동의는 `needsReconsent` |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'notes', ... }) — 2.1절 주입 값
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
| V2-NT-1 | 플랫폼 공통 정책만 쓸지(조직별 정책 없음) | 공통만(개인 사용자 SaaS) |
