# microweb-studio 개발 방법 V2: 공용모듈 적용판 (Microweb Studio)

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/microweb-studio/microweb-studio_develop.md`](../../develop/microweb-studio/microweb-studio_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `microweb` / `MW` |
| 개발 단계(`products/README.md` 개발 순서) | 4 |
| 채택 공용모듈 | compliance, media, community |
| 보류 공용모듈 | ads, editorial |
| 이 제품의 역할 | community 기준 구현 |
| 기존 공용모듈 | tenancy는 V1 설계대로, notify(초대·리드 알림), analytics, cms(쇼룸)는 기존 로드맵대로. |

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
| 이 제품에서 쓰는 곳 | 약관·처리방침·하객 개인정보 고지(029), 견적 문의 리드 동의(019), 사이트 공개 동의(대가성·공개 범위) |
| 공용모듈이 대체하는 것 | `microweb.leads.privacy_consent_at` → `compliance.consents`(subject `email`), `microweb.sites.disclosure_consent_*` → purpose `microweb.disclosure` |
| 제품에 남는 것 | 계좌·연락처 노출 설정(사이트 편집기) |
| 제품 주입 값 | `profileKind: kr_ecommerce`(팩 판매), 제품 목적 코드 `microweb.disclosure` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 media (미디어 라이브러리, `media` 0250)

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 업로드 파이프라인(010), 편집기 사진(014), 하객 음성 방명록(051, kind `audio`) |
| 공용모듈이 대체하는 것 | `microweb.site_assets` → `media.assets` + `usages`(owner `microweb.site`), 서명 업로드·완료 검증 → media |
| 제품에 남는 것 | 쇼룸 포트폴리오 이미지 매니페스트, 인사말 TTS 생성(050) |
| 제품 주입 값 | `presets: { square_1080, card_640 }`, `strip_exif: true`(하객 사진 위치정보) |
| 기획·개발 정본 | [`common-modules/media.md`](../../products/_platform-core/common-modules/media.md), [`_shared/modules/media.md`](../../develop/_shared/modules/media.md) |

### 2.3 community (댓글·방명록·신고, `community` 0350) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 하객 방명록(비회원 이름·비밀번호), 방명록 숨김·스팸·삭제(018), 음성 방명록 글(051) |
| 공용모듈이 대체하는 것 | `microweb.guestbook_entries` → `community.posts`(author `guest`, `relation`은 `meta`), 하객 쓰기 라우트의 IP 해시·레이트 리밋(009) → community |
| 제품에 남는 것 | RSVP(`rsvp_responses`), 음성 녹음·고지 흐름(051, 녹음 파일은 media) |
| 제품 주입 값 | `targetTypes: [microweb.site]`, 정책 `{ who: anyone, guest_allowed: true, moderation: post }`, 금칙어 플랫폼 공통 |
| 기획·개발 정본 | [`common-modules/community.md`](../../products/_platform-core/common-modules/community.md), [`_shared/modules/community.md`](../../develop/_shared/modules/community.md) |

### 2.4 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| ads | 부고장·청첩장 협찬은 사업 결정 전 | 협찬 상품을 팔기로 정할 때 |
| editorial | 사이트 게시(013)는 크레딧 소비가 묶인 단일 게시 흐름 | 사이트 버전 관리·예약 공개가 필요할 때 |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013000250_media.sql                 ← 추가(패키지 변환본)
20261013000350_community.sql             ← 추가(패키지 변환본)
20261013001000_microweb_domain.sql       ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `microweb.guestbook_entries` | 표 삭제 → `community.posts`(+ `threads` target `microweb.site`) |
| `microweb.site_assets` | 표 삭제 → `media.assets` + `media.usages` |
| `microweb.leads` | `privacy_consent_at` 삭제 → `compliance.consents` |
| `microweb.sites` | `disclosure_consent_at`, `_by`, `_basis` 삭제 → `compliance.consents` |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| MW-V2-01 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | W0 완료, `@nomad/compliance` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 029, 019 |
| MW-V2-02 | media 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | W0 완료, `@nomad/media` 출시 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 010, 014, 051 |
| MW-V2-03 | `@nomad/community` v0.x 구현(`nomad-modules` 저장소) | W2 맨 앞 | W0 완료 | Opus | `_shared/modules/community.md` 3장 전부, 계약 테스트 녹색 |
| MW-V2-04 | community 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | MW-V2-03 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 009, 018, 051 |
| MW-V2-05 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | MW-V2-01, MW-V2-02, MW-V2-04 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| MW-06-009 | 하객 쓰기 라우트(방명록, RSVP), IP 해시, 허니팟, Origin 검사 | 대체 | 방명록 쓰기는 community `createPost`(비회원). RSVP 쓰기만 제품 |
| MW-06-018 | 하객 관리: 방명록 숨김/스팸/삭제, RSVP 합계·CSV(감사 기록) | 축소 | 방명록 관리 화면은 community `ModerationQueue`. RSVP 합계 화면은 제품 |
| MW-06-010 | 업로드 파이프라인: 서명 업로드 URL, 완료 검증, 삭제(Storage+행) | 대체 | 업로드 파이프라인은 media 적용 작업으로 |
| MW-06-051 | 하객 음성 방명록: 고지·동의, 방문자 쿠키, 업로드·STT(오픈소스 강제),… | 연결 | 음성 파일은 media(kind `audio`), 글은 community |
| MW-06-029 | 법적 고지와 문구: 약관, 개인정보처리방침, 하객 고지, 금지 문구 점검 목록 | 축소 | 법적 고지 본문은 `policy_documents` seed |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'microweb', ... }) — 2.1절 주입 값
src/lib/media/index.ts            createModule({ appId: 'microweb', ... }) — 2.2절 주입 값
src/lib/community/index.ts        createModule({ appId: 'microweb', ... }) — 2.3절 주입 값
supabase/seed.sql                 <스키마>.settings 행, 정책 문서 초안, 프리셋
```

공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.

## 6. 검증 추가 항목

- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색
- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색
- [ ] compliance: 가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시
- [ ] media: 같은 파일 두 번 업로드 시 같은 자산, 사본 프리셋 생성, 사용 중 자산 삭제 거부(`MD003`)
- [ ] community: 비회원 글·비밀번호 삭제, 금칙어 3동작, 신고 → 임시조치 → 기한 처리
- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)

## 7. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |
| V2-MW-1 | 방명록 비회원 비밀번호를 받을지 | 받음(본인 삭제용), 실패 5회 잠금 |
