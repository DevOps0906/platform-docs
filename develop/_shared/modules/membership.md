# membership 개발 지시서 (`@nomad/membership`)

기획 정본: `products/_platform-core/common-modules/membership.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

최종 이용자 행, 등급, 고객사 자기 Toss 가맹 키 등록·검증, 단건 결제(후원)·빌링키 정기결제, 결제 웹훅 처리, 갱신·실패 재시도·만료 잡, 해지·환불, 접근 규칙과 미터, 혜택 판정, 페이월·등급 카드·후원 버튼·내 멤버십 화면.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0550_membership.sql` | 표 7개, `ensure_end_user`, `withdraw`, `apply_subscription_event`, `record_payment`, `is_end_user`, `has_benefit`, `can_access` |
| `src/server/end-users.ts`, `checkout.ts`, `webhook.ts`, `access.ts`, `merchant-keys.ts` | 공개 API |
| `src/pg/toss.ts` | Toss 호출 어댑터(고객사 키를 `core.encrypted_credentials`에서 꺼내 요청마다 사용, 로그에 키·카드 정보 금지) |
| `worker/handlers/membership/renew.ts`, `reconcile-payments.ts` | 갱신·결제 재확인 |
| `src/ui/Paywall.tsx`, `TierCards.tsx`, `DonateButton.tsx`, `MyMembership.tsx`, `admin/` | 화면 |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | SQL: 최종 이용자는 조직 멤버가 아님(`core.org_members`에 행 생성 금지), `is_end_user` RLS 함수 | 최종 이용자가 직원 표 0행 |
| 2 | 고객사 키 등록: 암호화 저장 → 테스트 결제로 검증 → 성공 시 `settings` 활성 | 키 평문이 DB·로그 어디에도 없음 |
| 3 | 단건 결제(후원): 서버가 금액 계산 → 결제창 → 승인 → `payments.paid` | 금액 조작 시 `MB003` |
| 4 | 정기결제: 빌링키 발급 → 첫 결제 → `active`, 갱신 잡(재시도 1·3·7일, 제안) | 실패 → `past_due` → `expired` |
| 5 | 웹훅·재확인 잡: 응답 유실 시 주문 조회로 맞춤(멱등 키 `pg_order_id`) | 같은 웹훅 2회 → 1회 반영 |
| 6 | 접근 규칙·미터 + `Paywall` | 미터 소진 후 안내, 유료 등급 열람 |
| 7 | 해지·환불·탈퇴(개인 필드 비식별화, 결제 기록 유지) | 탈퇴 후 결제 내역 보존 |

## 4. 외부 서비스·공식 문서

| 주제 | 링크 |
|---|---|
| 토스페이먼츠 개발자 문서(결제위젯, 자동결제(빌링), 웹훅, 결제 조회·취소) | https://docs.tosspayments.com |
| 전자상거래법(거래 기록 보존), 개인정보 보호법 | https://www.law.go.kr |

고객사별 가맹 계약은 고객사가 Toss와 직접 맺습니다. 플랫폼이 대신 수취하는 구조는 법무 확인 전 만들지 않습니다(MB-D1).

## 5. 제품 주입 값

`appId`, 테넌트 해석 함수(Host → org, `core-tenancy`), `accessTargets`(예 `news.article`, `toon.episode`, `lms.course`), 혜택 키 목록, 페이월 문구, 결제 성공·실패 복귀 경로.

## 6. 테스트

결제 E2E(토스 테스트 키, 단건·정기·실패 카드·환불), 웹훅 서명 검증 실패 거부, 교차 테넌트(다른 신문사 독자 행 읽기 0), 미터 30일 경계, 해지 후 기간 끝까지 접근 유지.

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| 커스텀 도메인에서 결제 후 복귀 실패 | 성공·실패 URL을 요청 Host 기준으로 서버가 만들고, 허용 도메인(테넌트 도메인 목록)인지 검사 |
| 정기결제가 두 번 됨 | 갱신 잡 멱등 키 `renew:<subscription>:<period_start>` 누락 |
