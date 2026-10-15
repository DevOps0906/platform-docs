# membership: 최종 이용자·등급·구독·후원·접근 규칙 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/membership`, 스키마 `membership`(0550~0599), 오류 코드 `MB###`. 출처: local-news M2(`docs/products/local-news/modules/M2_reader-membership.md`)와 열린 질문 MQ-1(독자 결제 위치), 코어 요청 R-5. 개발서 `docs/develop/_shared/modules/membership.md`.

## 1. 문제

코어의 조직·멤버·결제는 "고객사(조직)가 플랫폼에 돈을 내는" 구조다(`core` 결제 customerKey `org_<id>`). 그런데 local-news의 독자, flora 작가의 독자, study-note 유료 강좌 수강생, toon-factory 유료 회차 독자는 **고객사의 고객**(최종 이용자)이다. 이들을 조직 멤버로 넣으면 직원 화면과 데이터를 읽게 되는 권한 사고가 나고(local-news 07장 6절 금지 패턴), 결제 주체·수취인도 다르다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | 최종 이용자 행(고객사별, 조직 멤버 아님), 등급(무료·유료, 혜택 키), 정기 구독(빌링키 자동결제), 일시 후원·정기 후원, 결제 기록·환불, 콘텐츠 접근 규칙(무료·미터형·회원 전용·등급 전용), 혜택 판정 함수, 내 계정 화면(구독·결제 내역·해지) |
| 확장 | 쿠폰·체험 기간(growth와 연결), 선물 구독, 단체(기관) 구독, 앱 내 결제(iOS·Android), 영수증·기부금 영수증 |
| 제품에 남김 | 기사 단위 페이월 문구·노출 위치(local-news), 강좌 수강 진도(lms) |
| 코어와 구분 | 고객사가 플랫폼에 내는 구독료·크레딧은 코어 결제 그대로. membership은 고객사가 최종 이용자에게서 받는 돈만 |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `membership.end_users` | `id`, `org_id`, `app_id`, `user_id`(→ `auth.users`), `display_name`, `status`(`active`, `withdrawn`, `blocked`), `joined_at`, `withdrawn_at` | unique(`org_id`, `app_id`, `user_id`). 본인 읽기, org 멤버(역할 설정) 읽기. 쓰기: `membership.ensure_end_user`(본인 세션, 테넌트는 서버가 Host로 결정), `membership.withdraw` |
| `membership.tiers` | `id`, `org_id`, `app_id`, `code`, `name`, `price_monthly`, `price_yearly`, `benefits`(text[]: 예 `access.members_only`, `ads.off`, `newsletter.premium`), `status`(`draft`, `active`, `retired`), `sort` | 공개 읽기(활성), org admin 쓰기 |
| `membership.subscriptions` | `id`, `end_user_id`, `tier_id`, `status`(`trialing`, `active`, `past_due`, `canceled`, `expired`), `interval`(`month`, `year`), `current_period_start`, `current_period_end`, `cancel_at_period_end`, `billing_credential_id`(→ `core.encrypted_credentials`), `pg_customer_key` | 본인 읽기, org 멤버 읽기. 전이는 `membership.apply_subscription_event`(service: 결제 웹훅·갱신 잡) |
| `membership.payments` | `id`, `org_id`, `app_id`, `end_user_id`(후원은 비회원 가능 → null), `subscription_id`, `kind`(`subscription`, `donation`, `one_time`), `amount`, `currency`(`KRW`), `pg`(`toss`), `pg_order_id`(유일), `pg_payment_key`, `status`(`ready`, `paid`, `failed`, `canceled`, `refunded`, `partial_refunded`), `paid_at`, `refunded_amount`, `receipt_url`, `donor_name`, `donor_email_hash` | 본인 읽기, org 멤버(재무 역할) 읽기. 쓰기 service만 |
| `membership.access_rules` | `org_id`, `app_id`, `target_type`, `target_id`(null = 종류 전체 기본값), `rule`(`free`, `metered`, `end_users`, `tiers`), `meter_limit`(30일당 무료 열람 수), `tier_codes`(text[]) | 공개 읽기(규칙 판정용), org admin 쓰기 |
| `membership.meter_counts` | `org_id`, `app_id`, `viewer_key`(최종 이용자 id 또는 익명 쿠키 해시), `period_start`, `count` | service 전용 |
| `membership.settings` | `org_id`, `app_id`, `toss_credential_id`(고객사 자기 가맹 키), `donation_enabled`, `meter_default`, `withdraw_policy` | org admin, 키는 암호화 저장만 |

함수: `membership.is_end_user(org, app)`(RLS용), `membership.has_benefit(end_user_id, benefit)`, `membership.can_access(org, app, viewer, target_type, target_id)` → `{allowed, reason: 'free'|'meter'|'member'|'tier'|'meter_exhausted'|'tier_required', remaining}`.

오류 코드: `MB001` 최종 이용자 아님, `MB002` 등급 비활성, `MB003` 결제 금액 불일치(서버 재계산과 다름), `MB004` 이미 활성 구독, `MB005` 결제 키 미등록(고객사 설정 미완), `MB006` 탈퇴 이용자.

## 4. 결제 흐름 (고객사 자기 가맹 기준)

| 단계 | 동작 |
|---|---|
| 1 | 고객사가 콘솔에서 Toss 가맹 키 등록 → `core.encrypted_credentials` 저장, 테스트 결제 1건으로 검증 |
| 2 | 최종 이용자가 등급 선택 → 서버가 주문 생성(`payments.ready`, 금액은 서버가 등급에서 계산) |
| 3 | 결제창(단건) 또는 빌링키 발급(정기) → 승인 API를 서버가 고객사 키로 호출 |
| 4 | 웹훅(코어 웹훅 수신 → 서명 검증) → `apply_subscription_event` → 상태 전이 |
| 5 | 갱신일 잡 `membership.renew` → 자동결제 → 실패 시 `past_due` + notify, 재시도 일정(제안: 1·3·7일) 후 `expired` |
| 6 | 해지: `cancel_at_period_end = true`, 기간 끝나면 `canceled`. 환불은 고객사 정책(`settings`)과 결제 수단 규칙 |

플랫폼 수수료를 받을 경우 별도 정산(결정 MB-D2). 플랫폼이 돈을 받아 나눠 주는 구조는 전자금융업·정산 의무가 생길 수 있어 1차에서 피한다(법무 확인 필요).

## 5. 공개 API (TS 계약 예시)

```ts
// @nomad/membership/server
ensureEndUser(ctx: TenantCtx, userId: string): Promise<EndUser>
canAccess(ctx: TenantCtx, viewer: Viewer, target: { type: string; id: string }): Promise<AccessDecision>
startCheckout(ctx: TenantCtx, input: { tierCode?: string; donation?: { amount: number }; interval?: 'month' | 'year' }): Promise<CheckoutSession>
handlePgWebhook(ctx: TenantCtx, payload: unknown, signature: string): Promise<void>
cancel(ctx: TenantCtx, subscriptionId: string): Promise<void>
// @nomad/membership/ui
<Paywall decision /> <TierCards /> <DonateButton /> <MyMembership />
```

## 6. 이벤트

`membership.end_user.joined`, `.withdrawn`, `membership.subscription.activated`, `.past_due`, `.canceled`, `.expired`, `membership.payment.paid`, `.refunded`. notify(환영·결제 실패·만료 안내), analytics(전환).

## 7. 개인정보·법규

| 항목 | 규칙 |
|---|---|
| 처리 관계 | 고객사 = 개인정보처리자, 플랫폼 = 수탁자(위탁 계약 문구는 compliance 정책 문서) |
| 탈퇴 | 탈퇴 시 `end_users` 개인 필드 비식별화, 결제 기록은 전자상거래법 보존 기간 동안 유지(기간 법무 확인) |
| 카드 정보 | 저장하지 않음. 빌링키만 암호화 저장 |
| 정기결제 고지 | 갱신 전 안내 메일(notify). 고지 시점·방식은 법무 확인 |

## 8. 실패 동작

결제 승인 응답 유실 → 주문 조회 API로 재확인 잡(멱등 키 = `pg_order_id`). 웹훅과 리디렉션 결과가 다르면 PG 조회 결과가 정본. 접근 판정 오류 시 기본은 **차단이 아니라 무료 범위 공개**(유료 콘텐츠는 차단), 판정 오류를 로그로 남김.

## 9. local-news에서 옮기는 것

| local-news | 공용 |
|---|---|
| `news.readers` | `membership.end_users` |
| `news.membership_tiers`, `news.memberships` | `membership.tiers`, `membership.subscriptions` |
| `news.donations` | `membership.payments(kind='donation')` |
| `news.paywall_rules` | `membership.access_rules` + `can_access` |
| `news.record_donation`, `news.record_membership` | `apply_subscription_event`, 결제 기록 RPC |

## 10. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| MB-D1 | 수취 방식 | 고객사 자기 Toss 가맹(1차). 소규모 고객사용 플랫폼 일괄 수취는 법무·정산 검토 후 |
| MB-D2 | 플랫폼 수수료 | 1차 없음(구독료에 포함), 거래액 비례 수수료는 가격 정책에서 |
| MB-D3 | 익명 미터 기준 | 쿠키 해시(최종 이용자 로그인 시 합산 안 함) |
| MB-D4 | 코어 승격 여부 | `end_users` 개념은 tenancy와 묶여 여러 모듈이 참조하므로, 3개 이상 제품이 쓰면 코어로 승격 검토 |
