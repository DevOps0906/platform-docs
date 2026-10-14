# M2 reader-membership: 독자·후원·멤버십·페이월

작성일 2026-10-15. 표 정본 `docs/products/local-news/05_DATA_MODEL.md`, 결제 규칙 정본 `docs/products/local-news/01_PRD.md` 4절, 인증 단계 정본 `docs/products/_platform-core/AUTH_ROADMAP.md`와 01장 인증 절.

## 1. 목적과 범위

독자는 플랫폼 공통 Supabase 계정을 갖고, 신문사마다 `readers` 행 1개를 갖는다(신문사 조직의 멤버가 아니다). 이 모듈은 그 독자 행과 독자가 신문사에 내는 돈(후원·멤버십), 그리고 무료 열람 한도(미터)를 소유한다.

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 독자 가입 = 그 신문사 `readers` 행 생성(`news.ensure_reader`), 독자 프로필·탈퇴, 만 14세 이상 확인 | NW-F-006(독자 행 부분) |
| 확장(P1) | 일시·정기 후원, 유료 멤버십 등급, 미터형 페이월(월 N건 무료), 프리미엄 기사, 영수 안내 | NW-F-035, 036 |
| 하지 않음 | 플랫폼이 독자 돈을 받아 정산(D-4 권고안이 아님), 카드 정보 직접 수집, 로그인 수단 구현(코어 auth) | - |

## 2. 벤치마크

| 제품 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Ghost 멤버십 | 무료·유료·무상(complimentary) 독자 구분, 매직 링크 로그인, 공개 범위 4단(공개·회원·유료·특정 등급), 서버에서 본문 보호, 발행인이 자기 결제 계정을 연결하고 플랫폼 수수료 0% | Stripe 연결(국내는 Toss), 이메일만 쓰는 독자 식별 | https://docs.ghost.org/members (2026-10-15 열람 확인) |
| Newspack 독자 수익·Access Control | 이메일만으로 독자 계정, 등록벽과 페이월을 콘텐츠별로, 미터 카운트다운 배너, 게이트 우선순위, 기관 접근(도메인·IP), 콘텐츠 선물, 뉴스레터 링크로 1시간 우회 | WooCommerce 기반 결제 | https://help.newspack.com/reader-activation-system/ , https://help.newspack.com/?p=17054 (2026-10-15 열람 확인) |
| Piano Composer | 페이월 = 적용 페이지 + 사용자 세그먼트 + 트리거 + 행동, 페이지뷰 미터가 한도에 도달("Expired")하면 제안 표시, 닫기 허용 여부, 프리미엄·하드·미터·동적 4모델 | 구독 가능성 점수(동적 페이월), 견적형 가격 | https://docs.piano.io/en/subscriptions/getting-started-module-4-building-paywalls (2026-10-15 열람 확인) |
| Toss Payments 자동결제 | 빌링키 발급 후 결제일마다 서버가 승인, 결제 일정은 가맹점이 직접 관리, 자동결제는 리스크 검토·추가 계약 후 사용 | 브랜드페이 | https://docs.tosspayments.com/guides/v2/billing (2026-10-15 열람 확인) |

결론: Ghost처럼 "신문사 자기 결제 계정, 플랫폼 수수료는 별도 청구"(D-4 권고)를 택하고, Piano처럼 페이월을 규칙 4요소로 정의하되 1차는 "미터 + 프리미엄" 두 모델만 만든다.

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `readers`, `membership_tiers`, `memberships`, `donations`, `paywall_rules` |
| 소유 RPC | `news.ensure_reader`, `news.set_paywall_rule`, `news.upsert_membership_tier`, `news.set_reader_status`(편집국 차단), `news.record_donation`·`news.record_membership`(service, 05장 SQL. 04장의 `news.record_reader_payment` 제안과 이름 맞춤 필요), `news.withdraw_reader`(05장 SQL), 페이월 판정은 서버 함수 |
| 쓰는 코어 | auth(`session_context`, 로그인 단계), webhooks(`receiveWebhook`, 수신 경로 `/api/webhooks/toss/[org_id]`, `docs/products/local-news/04_API.md` 5절), encrypted_credentials(신문사 Toss 시크릿 키·독자 빌링키), jobs(정기 결제 잡), audit |
| 쓰는 모듈 | M1 `articles.is_premium`·`type` 읽기(페이월 판정) |
| 소비자 | M5(댓글 작성자 = 독자 행), M4(구독자 연결), M8(독자 수·후원 합계 리포트), 독자 화면(내 계정, 후원 페이지) |

## 4. 데이터 (요약, 상세 `docs/products/local-news/05_DATA_MODEL.md`)

| 표 | 핵심 컬럼(요약) | 비고 |
|---|---|---|
| `readers` | `org_id`, `user_id`, 닉네임, 이메일(탈퇴 시 비움), 상태(active·blocked·withdrawn), `is_over_14`(참만 허용), 약관·개인정보 동의 버전·시각, 마케팅 수신 동의, 관심 지역, 차단 사유, 탈퇴 시각 | (`org_id`, `user_id`) 유일. 신문사는 자기 행만 본다. 상태 전이는 트리거 |
| `membership_tiers` | 코드, 이름, 설명, 가격(원, 1,000~10,000,000), 결제 주기(`month`·`year`), 혜택 목록, 활성, 정렬 | 신문사 편집 |
| `memberships` | 독자, 등급, 상태(pending·active·past_due·canceled·expired), 현재 기간 시작·끝, 기간 끝 해지 예약, 빌링키 자격증명 id(`core.encrypted_credentials`), 외부 참조, 플랫폼 수수료 bps | 독자당 살아 있는 멤버십 1개. 전이는 트리거 |
| `donations` | 독자(null 가능), 표시 이름, 익명 여부, 메시지, 금액(원), 종류(`once`·`recurring`), 상태(pending·paid·failed·canceled·refunded), `order_id`·`payment_key`, 환불액, 플랫폼 수수료 bps·원 | 주문 id·금액은 생성 뒤 변경 불가(트리거) |
| `paywall_rules` | 모드(`off`·`meter`·`premium_only`·`meter_and_premium`), 월 무료 건수(기본 10), 미터 제외 유형(기본 `press_release`), 안내 문구 | 신문사당 1행. 프리미엄 여부는 기사 컬럼 `articles.is_premium`(M1) |

정기 결제 회차 기록(회차별 승인·실패)을 둘 표가 M2 소유 표 목록에 없다. 변경 제안: `membership_payments`(또는 `donations`에 `membership_id` 연결). 05장에서 결정한다(`README.md` MQ-1).

## 5. 인터페이스

```ts
// src/modules/reader-membership/server/index.ts — 계약 예시(구현 파일 아님)
export interface ReaderContext { readerId: string; orgId: string; status: 'active' | 'blocked' | 'withdrawn'; hasActiveMembership: boolean; tierCode: string | null }
export type AccessDecision =
  | { allow: true; reason: 'paywall_off' | 'exempt_type' | 'member' | 'meter'; remaining?: number }
  | { allow: false; gate: 'register' | 'subscribe'; remaining: 0 }

export interface ReaderMembershipApi {
  ensureReader(input: { orgId: string; nickname: string; termsVersion: string; privacyVersion: string; isOver14: true; marketingOptIn?: boolean }): Promise<ReaderContext>  // rpc news.ensure_reader, 멱등. 비공개 신문사 NW002, 차단 NW008
  getReader(orgId: string): Promise<ReaderContext | null>
  withdraw(orgId: string): Promise<void>                                      // rpc news.withdraw_reader, 활성 멤버십이 남아 있으면 NW004(먼저 해지)
  // 프리미엄 잠금은 DB(news.read_article)가 멤버 여부로 판정하고, 미터(월 무료 건수)만 앱이 쿠키로 센다
  decideAccess(input: { orgId: string; articleId: string; reader: ReaderContext | null; meterCookie: string | null }): Promise<{ decision: AccessDecision; nextMeterCookie: string | null }>
  checkout(input: { orgId: string; kind: 'membership' | 'donation'; tierId?: string; amountKrw?: number; recurring: boolean; requestId: string }): Promise<{ orderId: string; amountKrw: number; orderName: string; customerKey: string }>  // POST /api/r/membership/checkout
  confirm(orderId: string, paymentKey: string, amountKrw: number): Promise<void>     // 서버: 신문사 키로 Toss confirm → news.record_donation / news.record_membership(service), 금액 불일치 오류(코드 정본 05장)
  issueBillingKey(input: { orgId: string; tierId: string; authKey: string; requestId: string }): Promise<void>  // 빌링키 발급 → 첫 청구
  cancelMembership(orgId: string): Promise<void>                                     // 기간 끝 해지
}
```

| 이벤트 | 발생 | 구독 |
|---|---|---|
| `news.reader.joined` | 첫 `ensure_reader` | M4 환영 메일(동의 있을 때만), M8 |
| `news.reader.withdrawn` | 탈퇴 | M5 댓글 작성자 표시 익명화, M4 구독 해지 |
| `news.membership.activated` / `.past_due` / `.canceled` | 결제 결과 | 독자 메일, M8 |
| `news.donation.paid` / `.refunded` | 확정·환불 | 영수 메일, M8 |

## 6. 상태·규칙

| 표 | 전이 | 누가 |
|---|---|---|
| `memberships` | `pending` → `active`·`canceled`·`expired`, `active` → `past_due`·`canceled`·`expired`, `past_due` → `active`·`canceled`·`expired`, `canceled` → `active`(재개)·`expired` | 서버(결제 결과), 독자(해지 예약), 편집국 owner(환불·강제 해지) |
| `donations` | `pending` → `paid`·`failed`·`canceled`, `paid` → `canceled`·`refunded` | 서버만 |
| `readers` | `active` ↔ `blocked`(편집국), `active`·`blocked` → `withdrawn`(본인), `withdrawn` → `active`(재가입) | RPC·전이 트리거 |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 결제 주체 | 독자 결제는 신문사 자기 Toss 가맹(시크릿 키를 `core.encrypted_credentials`에). 플랫폼 수수료(`news_reader_fee_bps`)는 플랫폼이 신문사에 월 별도 청구 | D-4 권고, `docs/products/_platform-core/SECURITY_BASELINE.md:110-121` |
| 자동결제 계약 | Toss 자동결제는 리스크 검토·추가 계약 후 사용 가능하므로 신문사 온보딩 체크리스트에 "자동결제 계약 완료"를 두고, 미완료면 정기 후원·멤버십 버튼을 숨긴다 | https://docs.tosspayments.com/guides/v2/billing |
| 금액 | 클라이언트 금액을 믿지 않는다. 등급 가격·후원 금액 범위는 서버가 정하고 confirm 때 대조 | `docs/products/_platform-core/SHARED_MODULES.md:145` |
| customerKey | 독자 결제는 `reader_<readers.id>`(제안). 코어의 `org_<orgId>`와 섞지 않는다 | `docs/products/_platform-core/SHARED_MODULES.md:163` |
| 미터 | 비로그인은 서버가 서명한 HttpOnly 쿠키(월·조직·기사 id 해시 목록)로 센다. 지우면 초기화되는 "부드러운" 벽임을 인정한다. 프리미엄 기사(`articles.is_premium`)는 미터와 무관하게 멤버가 아니면 서버가 본문을 보내지 않는다 | Piano 미터 모델, Ghost 서버 보호 |
| 검색엔진 | 유료 본문은 `isAccessibleForFree=false`와 `hasPart`(class 선택자)로 표시(M6가 출력) | https://developers.google.com/search/docs/appearance/structured-data/paywalled-content |
| 정기결제 실패 | 갱신 잡 `news.membership_renew`(매일 09:00 KST)가 청구, 3회 실패면 `past_due` → 만료(정본 `docs/products/local-news/02_ARCHITECTURE.md` 4절) | `docs/products/_platform-core/SHARED_MODULES.md:146` |
| 미성년 | 만 14세 미만은 독자 가입 불가(법정대리인 동의 흐름을 만들지 않는다, 제안) | 개인정보보호법(`docs/products/local-news/01_PRD.md` 법 절) |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| confirm 금액 불일치 | 주문 `failed`, Toss 취소 API 호출, 운영 알림. 독자에게 "결제 확인 실패, 승인 취소 요청" 표시 |
| 신문사 키 없음·무효 | 후원 버튼 비노출, 편집국 설정 화면에 경고. 독자에게 오류 페이지 대신 "현재 후원을 받을 수 없음" |
| 웹훅 서명 실패 | 401 + `webhook_events.signature_valid=false`. 지급(활성화)은 confirm 경로로만 |
| 빌링키 승인 실패 | `past_due`, 독자 메일, 재시도 잡. 3회 실패 후 `canceled` |
| 미터 쿠키 위조 | 서명 불일치면 새 쿠키(카운트 0이 아니라 한도에 가까운 보수값, 제안) |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 독자 데이터 | 처리자는 신문사, 플랫폼은 수탁자. 신문사 콘솔은 자기 `readers`만, 다른 신문사 독자 존재 여부를 알 수 없다(RLS + 집계 함수만) |
| 이메일 | `readers.email`은 그 신문사 연락용 사본(05장 SQL). 탈퇴 시 트리거가 비운다. 편집국 화면은 마스킹(제안) |
| 카드 | 카드 정보는 Toss SDK UI가 받는다. 빌링키는 암호화 저장, 요약만 노출 |
| 탈퇴 | `withdrawn` → 유예 30일(제안) 뒤 개인정보 파기, 결제 기록은 법정 보존 기간만 보관(기간 미확인, 01장 법 절) |
| 감사 | 환불·강제 해지·등급 가격 변경은 `audit_log` |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-006 | 같은 계정으로 A·B 신문 독자 가입 시 행 2개, A 편집국은 B 독자 행 0건. `ensure_reader` 두 번 호출해도 1행 |
| NW-F-035 | 금액 변조 요청은 금액 불일치 오류로 거부되고 주문 `failed`. 정기 결제 회차 실패 시 `past_due` 메일 |
| NW-F-036 | 무료 N건 초과 시 등록·구독 안내, `is_premium` 기사는 비회원 HTML에 본문이 없음(소스 보기로 확인), `exempt_types` 유형은 미터에서 빠짐 |

## 10. 추출 조건

flora-publishing의 멤버십 확장(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:173`)이 착수되면 독자 행·등급·후원을 공용(`growth` 0900 검토, 결제는 코어)으로 꺼낸다. 미터형 페이월(기사 단위 규칙)은 뉴스 전용으로 남긴다. 추출 전에 MQ-1(주문·빌링키 위치)을 코어 확장으로 해결해야 한다.
