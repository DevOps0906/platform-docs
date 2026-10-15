# website-floria 개발 방법 V2: 공용모듈 적용판 (Floria (Botanic Architecture))

작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). V1 안내서 [`develop/website-floria/website-floria_develop.md`](../../develop/website-floria/website-floria_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. 공통 규칙은 [`develop_V2/_shared/V2_RULES.md`](../../develop_V2/_shared/V2_RULES.md).

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 앱 id / 작업 접두어 | `site` / `SI` |
| 개발 단계(`products/README.md` 개발 순서) | 1 |
| 채택 공용모듈 | compliance |
| 보류 공용모듈 | media, editorial |
| 이 제품의 역할 | compliance 기준 구현 |
| 기존 공용모듈 | notify 보강분(뉴스레터 목록·이중 동의, 017·021)은 notify v1이 나오면 `site.newsletter_subscribers`를 `notify.list_subscriptions`로 옮긴다(이번 V2 범위 밖, 06장 메모만). |

## 1. 진행 순서

| 순서 | 할 일 | 문서 |
|---|---|---|
| 1 | V1 0~6장: 사전 준비, setup 스크립트, project-profile, 로컬 DB 기동 전까지 | V1 안내서 |
| 2 | 공용모듈 SQL 추가와 도메인 파일 이름 바꾸기, 제품 표 정리 | 이 문서 3장 |
| 3 | `06_AGENT_PLAN.md`에 V2 작업 추가, V1 작업 축소·대체 반영 → 개발 묶음 다시 만들기 | 이 문서 4장, V2_RULES 4장 |
| 4 | V1 8~10장 사이클로 웨이브 진행(V2 작업은 해당 웨이브 맨 앞) | V1 안내서 |
| 5 | 검증 추가 항목 | 이 문서 6장 |

## 2. 공용모듈 적용 상세

### 2.1 compliance (법정 표기·동의·라벨, `compliance` 0150) — 기준 구현

| 항목 | 내용 |
|---|---|
| 이 제품에서 쓰는 곳 | 개인정보처리방침·동의 문구·푸터 사업자 정보(023), 콘솔 설정의 처리방침 버전(022), 문의·뉴스레터 폼 동의, 콘솔 AI 설정의 국외 이전 동의(038) |
| 공용모듈이 대체하는 것 | `site.sites.privacy_policy_version`, `site.inquiries.consent_version`·`consent_at`, `site.newsletter_subscribers.consent_version`·`consent_at` → `compliance.policy_documents` 버전과 `compliance.consents`(subject `email` 해시), 푸터 사업자 정보 → `legal_profiles`(`kr_business`) |
| 제품에 남는 것 | 문의 접수 RPC와 스팸 점수, 뉴스레터 이중 동의 흐름(017) |
| 제품 주입 값 | `profileKind: kr_business`, 방문자 로그인 없음 → 폼 제출 때 `recordConsent({ subject: { kind: "email", hash } })` |
| 기획·개발 정본 | [`common-modules/compliance.md`](../../products/_platform-core/common-modules/compliance.md), [`_shared/modules/compliance.md`](../../develop/_shared/modules/compliance.md) |

### 2.2 보류한 모듈

| 모듈 | 보류 이유 | 다시 검토할 때 |
|---|---|---|
| media | 이미지가 빌드 때 들어가는 정적 자산(007 매니페스트 검사)이고 업로드 기능이 없음 | 콘솔에서 시공 사례 사진을 올리게 될 때(editorial과 함께) |
| editorial | 시공 사례·소식은 지금 정적 콘텐츠·지식 원고(039) | 콘솔에서 사례·소식을 직접 게시하게 될 때 |

## 3. DB 변경

V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):

```
20261013000001_core_lite.sql
20261013000150_compliance.sql            ← 추가(패키지 변환본)
20261013001000_website_floria_domain.sql ← 20261013000002에서 이름 변경
```

| 대상 | 변경 |
|---|---|
| `site.sites` | `privacy_policy_version` 삭제 → `compliance.current_policy` |
| `site.inquiries` | `consent_version`, `consent_at` 삭제 → `compliance.consents`(purpose `privacy`, evidence: inquiry id) |
| `site.newsletter_subscribers` | `consent_version`, `consent_at` 삭제 → `compliance.consents`(purpose `marketing_email`). 확인·해지 시각 컬럼은 유지 |
| `site.submit_inquiry` 등 RPC | 인자 `p_consent_version`, `p_privacy_policy_version` 대신 서버가 `compliance.current_policy`로 버전을 정하고 기록 |

## 4. 작업 계획 변경

### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)

| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |
|---|---|---|---|---|---|
| SI-V2-01 | `@nomad/compliance` v0.x 구현(`nomad-modules` 저장소) | W2 맨 앞 | W0 완료 | Opus(+Fable 계획 검토) | `_shared/modules/compliance.md` 3장 전부, 계약 테스트 녹색 |
| SI-V2-02 | compliance 적용(SQL 변환본, 주입 파일, seed, 어댑터) | W2 맨 앞 | SI-V2-01 | Sonnet | `_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: 023, 022, 038 |
| SI-V2-03 | V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사 | E2E 작업과 같은 웨이브 | SI-V2-02 | Sonnet | 제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0 |

### 4.2 V1 작업 변경

| V1 작업 | 작업명(06장) | 변경 | 내용 |
|---|---|---|---|
| SI-06-023 | 개인정보처리방침, 동의 문구, 푸터 사업자 정보, AI 고지문(법무 검토 게이트 포… | 대체 | 처리방침·동의 문구·푸터는 compliance 기준 구현 작업(V2)이 만든다. 제품은 문구 원고와 사업자 정보 seed만 |
| SI-06-022 | 콘솔 설정(알림 이메일, 접수 on/off, 동의 버전) | 축소 | 콘솔 설정에서 처리방침 버전 입력 제거(정책 게시 화면은 compliance 관리 UI) |
| SI-06-017 | 뉴스레터 API(subscribe/confirm/unsubscribe), HMAC… | 연결 | 구독 확인 시 `recordConsent(marketing_email)` |
| SI-06-038 | 콘솔 AI 설정: `/admin/ai`(스위치, 국외 이전 동의, 사용량, 미답변… | 연결 | 국외 이전 동의를 `recordConsent(cross_border_ai)`로 |

변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.

## 5. 디렉토리와 주입 파일

```
src/lib/compliance/index.ts       createModule({ appId: 'site', ... }) — 2.1절 주입 값
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
| V2-SI-1 | compliance 관리 화면을 콘솔에 넣을지, 플랫폼 운영자만 쓸지 | 콘솔에 넣음(단일 사이트 운영자) |
