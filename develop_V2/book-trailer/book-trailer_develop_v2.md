# book-trailer 개발 방법 V2: 공용모듈 적용판 (NOMAD Book Trailer(가칭))

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/book-trailer/book-trailer_develop.md`](../../develop/book-trailer/book-trailer_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `trailer` / `TR` |
| 개발 단계(`products/README.md` 개발 순서) | 4 |
| 채택 공용모듈 | compliance |
| 보류 공용모듈 | media, search, editorial |
| 이 제품의 역할 | 패키지 사용(구현하지 않음) |
| 기존 공용모듈 | notify(렌더 완료·승인 링크 만료 알림, 052), analytics(퍼널 이벤트만. 구매 링크 클릭은 제품 `link_clicks`), cms(랜딩·샘플 페이지)는 기존 로드맵대로. 화이트라벨(Phase 2)은 tenancy 검토. |

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
| 이 제품에서 쓰는 곳 | 법적 고지 페이지(약관, 개인정보, AI 표시 안내, 051), 가입 동의, 국외 이전 동의(016), 엔드카드 AI 표시 문구(031) |
| 공용모듈이 대체하는 것 | 법적 고지 본문 → `policy_documents`(kind `terms`, `privacy`, `ai_notice`, `refund`), 가입·국외 이전 동의 → `consents`(purpose `cross_border_ai` 등), 엔드카드 AI 표시 문구 → `label_definitions`(`ai_generated`, `ai_voice`) 텍스트 |
| 제품에 남는 것 | 책별 권리 확인(`trailer.books.rights_ack_*`, 감사 로그), 음악 권리 확인, 렌더 `ai_label` CHECK와 표시 여부 판정(`start_render`), 메타데이터 대가성 문구 트리거 |
| 제품 주입 값 | `profileKind: kr_ecommerce`(유료 플랜 판매), `signupConsents: { required: [terms, privacy, refund], optional: [marketing_email, cross_border_ai] }` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| media | 원고·표지·사용자 음악은 책·트레일러에 하나씩 붙는 고정 경로 파일이고 경로를 CHECK로 강제한다. 장면 에셋은 렌더 스냅샷이 경로를 고정해야 해서 공용 자산의 삭제·교체 흐름과 맞지 않는다 | 여러 책에서 같은 이미지·로고를 다시 쓰는 라이브러리가 필요할 때(브랜드 키트 로고, Phase 2 화이트라벨) |
| search | 책·트레일러 목록 필터와 책별 RAG(022)로 충분 | 출판사 계정의 책이 수백 권을 넘을 때 |
| editorial | 외부 승인 링크(057)는 로그인 없는 저자 1명의 승인·수정 요청이 핵심이라 editorial 1단 승인(조직 멤버 주체)과 다르다 | publisher 팀 안에서 마케터 → 편집장 다단계 승인을 만들 때 |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013001000_trailer_domain.sql        ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `trailer.*` | 변경 없음. 가입·국외 이전 동의 기록은 `compliance.consents`에 새로 쌓는다. 책 권리 확인(`books.rights_ack_*`)과 음악 권리 확인(`trailers.music_rights_ack*`)은 책·트레일러 단위 확인이라 제품에 남긴다 |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| TR-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W1 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 051, 016, 031 |
| TR-V2-02 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | TR-V2-01 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| TR-06-051 | 법적 고지 페이지·문구(약관, 개인정보, AI 표시 안내) | 축소 | 법적 고지 본문은 `policy_documents` seed, 화면은 `LegalFooter`·`ConsentCheckboxes`. 페이지 배치와 AI 표시 안내 원고만 제품 |
| TR-06-016 | AI 게이트: 대화, 서명·잡 토큰, 턴 선차감·정산·환불, 국외 이전 온보딩 | 연결 | 국외 이전 동의를 `recordConsent(cross_border_ai)`로도 남긴다. 코어 `set_ai_cross_border_ack` 호출은 그대로 |
| TR-06-031 | 렌더 파이프라인: 스냅샷 → props, 워터마크·AI 표시, 포스터·SRT·ZIP… | 연결 | 엔드카드 AI 표시 문구는 `label_definitions` 텍스트를 읽어 렌더 스냅샷에 고정. 표시 여부 판정과 `ai_label` CHECK는 제품 그대로 |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'trailer', ... }) — 2.1절 주입 값
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
| V2-TR-1 | 책 권리 확인 고지문(`rights-2026-10-v1`) 본문 버전을 compliance로 옮길지 | 본문 버전만 `policy_documents` 제품 kind(`rights_notice`, compliance 확장 요청)로, 책별 확인 기록은 제품 표 유지 |
