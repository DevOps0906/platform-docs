# flora-publishing 개발 방법 V2: 공용모듈 적용판 (FLORA Publishing)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/flora-publishing/flora-publishing_develop.md`](../../develop/flora-publishing/flora-publishing_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `publishing` / `PB` |
| 개발 단계(`products/README.md` 개발 순서) | 2 |
| 채택 공용모듈 | compliance, media |
| 보류 공용모듈 | community, membership, editorial |
| 이 제품의 역할 | media 기준 구현 |
| 기존 공용모듈 | notify(작업 완료·결제), analytics, cms(랜딩)는 기존 공용모듈 로드맵 Phase 1 그대로. |

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
| 이 제품에서 쓰는 곳 | 법무 페이지 5종(약관, 처리방침, 환불, AI 이용 안내 등, 025), 가입 동의, 대기 명단의 마케팅 동의 |
| 공용모듈이 대체하는 것 | `publishing.waitlist.consent_marketing` → `compliance.consents`(subject `email`), 법무 페이지 본문 → `policy_documents` |
| 제품에 남는 것 | 원고 저작권 안내 문구(제품 원고) |
| 제품 주입 값 | `profileKind: kr_ecommerce`(유료 플랜 판매), `signupConsents` 필수 terms·privacy·refund |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 media (미디어 라이브러리, `media` 0250) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 원고 업로드(서명 URL·완료 검증, 015), 표지 이미지, 탈퇴 시 파일 정리(036) |
| 공용모듈이 대체하는 것 | `publishing.manuscript_uploads`의 저장 경로·용량·MIME·해시 → `media.assets`(kind `file`), `publishing.cover_images` → `media.assets`(kind `image`) + 프리셋 `cover_1600x2560`(제품 추가) |
| 제품에 남는 것 | 원고 파싱 잡(업로드 완료 이벤트 `media.asset.ready` 구독), 인쇄용 산출물 `book_exports`(PDF·ePub), 책별 RAG 참고 파일(045, 코어 AI) |
| 제품 주입 값 | `presets: { cover_1600x2560 }`, `allowedMime`(docx, hwp, txt, md, pdf, 이미지), `maxUploadMb: 50`(제안), 표지 `requireAlt: true` |
| 기획·개발 정본 | [`common-modules/media.md`](../../products/_platform-core/common-modules/media.md), [`_shared/modules/media.md`](../../develop/_shared/modules/media.md) |

### 2.3 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| community | 독자 리뷰 기능이 기획에 없음 | 작가 독자 페이지를 만들 때 |
| membership | 작가 유료 멤버십은 확장 아이디어 단계 | 멤버십 확장 착수 때(`COMMON_MODULES_ROADMAP.md` 4.7절 lms와 함께) |
| editorial | 원고는 웹에 게시하지 않고 인쇄·전자책으로 내보냄. 장·절 버전은 제품 구조(chapters, sections) | 작가 블로그·연재 게시 기능을 만들 때 |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013000250_media.sql                 ← 추가(패키지 변환본)
20261013001000_publishing_domain.sql     ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `publishing.manuscript_uploads` | 파일 메타 컬럼 삭제, `asset_id`(→ `media.assets`)와 파싱 상태만 남김 |
| `publishing.cover_images` | 표 삭제 → `books.cover_asset_id`(→ `media.assets`) |
| `publishing.waitlist` | `consent_marketing` 삭제 → `compliance.consents` |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| PB-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W1 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 025 |
| PB-V2-02 | `@nomad/media` v0.x 구현(`nomad-modules` 저장소) | W2 맨 앞 | W0 완료 | Opus | `_shared/modules/media.md` 3장 전부, 계약 테스트 녹색 |
| PB-V2-03 | media 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | PB-V2-02 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 015, 036 |
| PB-V2-04 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | PB-V2-01, PB-V2-03 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| PB-06-015 | 원고 업로드(서명 URL, 완료 검증, 파싱 잡, 파서 4종, 책 생성) | 축소 | 서명 URL·완료 검증·중복 검사는 media. 제품은 파싱 잡과 원고 상태 |
| PB-06-036 | 탈퇴·데이터 삭제와 purge 잡(휴지통, 업로드 원본, 만료 내보내기, 조직 30… | 연결 | 탈퇴 purge에서 `media.detach` 후 media 휴지통 규칙을 따름 |
| PB-06-025 | 법무 페이지 5종 문구(약관, 처리방침, 환불, AI 고지, 사업자 정보) | 축소 | 법무 페이지 본문은 `policy_documents` seed, 화면은 compliance 컴포넌트 |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'publishing', ... }) — 2.1절 주입 값
src/lib/media/index.ts            createModule({ appId: 'publishing', ... }) — 2.2절 주입 값
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
| V2-PB-1 | HWP 업로드 허용 | 허용(국내 원고 비중), 변환은 파싱 잡 |
| V2-PB-2 | 표지 프리셋 크기 | 1600x2560(전자책 표지 일반 비율 1:1.6, 플랫폼별 규격은 확인 필요) |
