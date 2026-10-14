# M2 reader-membership 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M2_reader-membership.md`, 결제 규칙 `D:/WorkSpace/platform/docs/products/local-news/01_PRD.md` 4절, 코어 결제 계약 `docs/file/03-설계/공용코어/SHARED_MODULES.md` 5·6장. 독자 로그인 단계는 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 독자 행 | 로그인 콜백 뒤 `news.ensure_reader`(약관·개인정보 버전, 만 14세 이상 확인), 내 계정(닉네임·지역·탈퇴) | P0 |
| 결제 연결 | 신문사 편집국 설정: Toss 클라이언트 키·시크릿 키 저장(`core.encrypted_credentials`), 자동결제 계약 여부 체크 | P1 |
| 후원 | 일시 후원(결제창 → confirm), 정기 후원(빌링키) | P1 |
| 멤버십 | 등급 관리, 가입(빌링키 발급 → 첫 결제), 갱신 잡, 해지 예약, `past_due` 재시도 | P1 |
| 페이월 | `paywall_rules` 설정 화면, 미터 쿠키, 프리미엄 기사(`is_premium`) 본문 서버 차단 | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/reader-membership/server/index.ts` | `ensureReader`, `requireReader`(02장 9.2절), `decideAccess`, 결제 시작·확정 |
| `.../server/readers.ts` | `news.ensure_reader`(멱등), 탈퇴(`news.withdraw_reader`) |
| `.../server/toss.ts` | 신문사 키 복호화(요청마다, 서버 전용) → Toss confirm·빌링 API → `news.record_donation`·`news.record_membership`(service). 코어 `toss` 패키지의 HTTP 클라이언트를 재사용하고 주문 저장만 M2 표(04장 6절) |
| `.../server/meter.ts` | 미터 쿠키 서명·검증(HMAC, 월·조직 키), 남은 건수 |
| `.../schema.ts` | checkout·confirm·billing-key 입력(04장 2.1절) |
| `.../components/` | 후원·멤버십 화면, 미터 배너, 등록·구독 게이트, 편집국 독자·등급·결제 설정 화면 |
| `worker/src/handlers/news.stats/news.membership_renew.ts` | 매일 09:00 KST 정기 청구, 3회 실패 `past_due` → 만료 |
| `apps/web/src/app/api/r/membership/{tiers,checkout,confirm,billing-key,cancel}` | 독자 API |
| `apps/web/src/app/api/webhooks/toss/[org_id]/route.ts` | 코어 `receiveWebhook` + 그 신문사 키로 결제 조회 API 재확인(04장 5절) |
| `apps/web/src/app/(reader)/_t/[host]/{membership,account}` | 독자 화면 |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 로그인 콜백(`finishLogin` 제품 훅)에서 `ensureReader` 호출, 첫 로그인은 약관·만 14세 확인 화면 | 같은 계정 A·B 신문 가입 시 행 2개 |
| 2 | 탈퇴: 상태 `withdrawn`(이메일 비움은 트리거) → 이벤트 `news.reader.withdrawn` | M5 댓글 작성자 익명 표시 |
| 3 | 편집국 결제 설정 화면: 키 저장(암호화), 테스트 결제 버튼, "자동결제 계약 완료" 체크 | 키 평문이 응답·로그에 없음 |
| 4 | 일시 후원: `POST /api/r/membership/checkout`이 `order_id` 생성·금액 확정 → Toss 결제창 → `POST /api/r/membership/confirm`이 서버 confirm(금액 대조) → `news.record_donation` | 금액 변조 시 금액 불일치 오류 + 결제 취소 요청 |
| 5 | 웹훅 수신 `/api/webhooks/toss/[org_id]`: 멱등은 코어, Toss 서명 검증 방식이 미확인이므로 그 신문사 키로 결제 조회 API를 다시 불러 확정(04장 5절) | 중복 웹훅 200, 상태 변화 없음 |
| 6 | 멤버십: `POST /api/r/membership/billing-key`(카드 등록 창 authKey) → 빌링키 암호화 저장(`billing_credential_id`) → 첫 청구 → `active` | 빌링키 요약만 화면 표시 |
| 7 | 갱신 잡 `news.membership_renew`(매일 09:00 KST): 결제일 승인, 3회 실패면 `past_due` → 만료 | 테스트 키로 실패 시나리오 |
| 8 | 페이월: 기사 상세는 `news.read_article`(프리미엄 잠금은 DB가 멤버 여부로 판정) + `decideAccess`(미터). 잠긴 본문은 동적 렌더(ISR 캐시에 유료 본문을 넣지 않음) | 비회원 HTML 소스에 유료 본문 없음 |
| 9 | 미터 배너(남은 건수), 등록·구독 유도 화면, 닫기 허용 설정 | N+1번째 기사에서 게이트 |
| 10 | 플랫폼 수수료 집계: `platform_fee_bps` 기록 → 월 청구 리포트(운영) | 수수료 합계가 결제 합계 × bps와 일치 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| Toss Payments 자동결제 | 신문사가 자기 가맹점으로 자동결제 계약(리스크 검토·추가 계약 필요). 결제 일정은 우리 잡이 관리 | https://docs.tosspayments.com/guides/v2/billing (2026-10-15 열람 확인) |
| 카드 자동결제 연동 | 결제창 방식 카드 등록 → 빌링키 발급 → 승인 API | https://docs.tosspayments.com/guides/v2/billing/integration , API 레퍼런스 https://docs.tosspayments.com/reference |
| Toss 웹훅 | 개발자센터 웹훅 메뉴에서 MID별 등록, 이벤트 `PAYMENT_STATUS_CHANGED`·`BILLING_DELETED`·`CANCEL_STATUS_CHANGED` 선택. 10초 안 200 응답, 실패 시 최대 7회 재전송(1·4·16·64·256·1024·4096분). 서명 검증 방법은 이 문서에 없음(미확인, 레퍼런스 확인) | https://docs.tosspayments.com/guides/v2/webhook (2026-10-15 열람 확인) |
| 샘플 | 공식 샘플 프로젝트 | https://github.com/tosspayments/tosspayments-sample |

웹훅 URL은 신문사마다 MID가 다르므로 `/api/webhooks/toss/<org_id>`로 나눕니다(04장 5절). 신문사 온보딩 안내문에 이 URL 등록 절차를 넣습니다.

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 미터 쿠키 서명·위조·월 경계(KST), `decideAccess` 표(`paywall_rules.mode` 4종 × 회원·비회원 × 미터 남음·소진 × `exempt_types`) |
| 결제 | Toss 테스트 키로 성공·실패·금액 불일치·중복 confirm·웹훅 중복 |
| RLS | 독자는 자기 `readers`·`memberships`·`donations`만, 편집국은 자기 신문사만, `reader_other`는 0행 |
| E2E | 페르소나 `reader` 후원 → 영수 메일, `reader_member` 프리미엄 열람, `anon` 미터 소진 |

## 6. 운영 점검표

- [ ] 결제일 갱신 잡 성공률, `past_due` 건수 주간 확인
- [ ] 신문사별 Toss 키 유효성(테스트 승인 실패) 알림
- [ ] 웹훅 `failed` 건 0 유지, Toss 실패 메일 수신 확인
- [ ] 월 플랫폼 수수료 청구 리포트 대조
- [ ] 탈퇴 유예 만료 파기 잡 실행 기록

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 정기 후원 버튼이 안 보임 | 신문사 자동결제 계약 미완료 체크 | 정상 동작. 계약 후 체크 |
| confirm 후 상태가 `pending` | successUrl 처리 전에 브라우저 닫힘 | 웹훅 보조 반영 + 주기 재조정(Toss 조회 API) |
| 미터가 매번 초기화 | 쿠키 도메인이 서브도메인·커스텀 도메인마다 다름 | 정상(도메인별 미터). 대표 도메인 301로 하나로 모음 |
| 유료 본문이 검색 결과에 노출 | ISR 캐시에 본문 포함 | 본문 동적 렌더 확인, M6 `isAccessibleForFree` 표시 확인 |
