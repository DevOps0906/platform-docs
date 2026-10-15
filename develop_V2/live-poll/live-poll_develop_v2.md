# live-poll 개발 방법 V2: 공용모듈 적용판 (Live Poll)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/live-poll/live-poll_develop.md`](../../develop/live-poll/live-poll_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `poll` / `LP` |
| 개발 단계(`products/README.md` 개발 순서) | 4 |
| 채택 공용모듈 | compliance, community(부분 채택) |
| 보류 공용모듈 | ads |
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
| 이 제품에서 쓰는 곳 | 진행자 가입 약관·처리방침, 진행자 가이드·FAQ의 개인정보 안내(032), 청중 참여 안내 |
| 공용모듈이 대체하는 것 | 약관·처리방침 본문 → `policy_documents`, 진행자 가입 동의 → `consents` |
| 제품에 남는 것 | 청중 익명 참여 규칙(로그인 없음) |
| 제품 주입 값 | `profileKind: kr_business` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 community (댓글·방명록·신고, `community` 0350)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 조직 금칙어 설정(021)과 금칙어 검사 함수만 |
| 공용모듈이 대체하는 것 | `poll.banned_words` → `community.banned_words`(app `poll`), 금칙어 매칭 → community `filters` |
| 제품에 남는 것 | Q&A 질문·추천(`qna_questions`, `qna_upvotes`), 모더레이션 패널(019), 실시간 전달 |
| 제품 주입 값 | 금칙어 동작 `review`(Q&A 대기 큐로) |
| 기획·개발 정본 | [`common-modules/community.md`](../../products/_platform-core/common-modules/community.md), [`_shared/modules/community.md`](../../develop/_shared/modules/community.md) |

### 2.3 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| ads | 지금 기획에 스폰서·광고 기능이 없음 | 행사 스폰서 배너를 팔기로 정할 때(발표 화면 슬롯) |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013000350_community.sql             ← 추가(패키지 변환본)
20261013001000_poll_domain.sql           ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `poll.banned_words` | 표 삭제 → `community.banned_words` |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| LP-V2-01 | community 적용(부분 채택: SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | W0 완료, `@nomad/community` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 021 |
| LP-V2-02 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W5 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 032 |
| LP-V2-03 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | LP-V2-01, LP-V2-02 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| LP-06-021 | 설정 화면: 조직 금칙어 추가/삭제(owner/admin) | 축소 | 금칙어 추가·삭제 화면은 community 설정 컴포넌트 |
| LP-06-019 | Q&A 모더레이션 패널: 대기 큐, 승인/거절/답변 완료/숨김, 진행자 토픽 수신… | 연결 | 질문 접수 시 community 금칙어 검사 결과로 대기 큐 여부 결정 |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'poll', ... }) — 2.1절 주입 값
src/lib/community/index.ts        createModule({ appId: 'poll', ... }) — 2.2절 주입 값
supabase/seed.sql                 <스키마>.settings 행, 정책 문서 초안, 프리셋
```

공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.

## 6. 검증 추가 항목

- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색
- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색
- [ ] compliance: 가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시
- [ ] community: 비회원 글·비밀번호 삭제, 금칙어 3동작, 신고 → 임시조치 → 기한 처리
- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)

## 7. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |
| V2-LP-1 | Q&A 전체를 community로 옮길지 | 옮기지 않음(실시간·익명 투표 성격). 금칙어만 |
