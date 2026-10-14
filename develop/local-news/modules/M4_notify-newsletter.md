# M4 notify-newsletter 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M4_notify-newsletter.md`, 표 `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md`. 공용 `notify` 후보 설계는 `D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 4.1절. 이 모듈은 나중에 공용 notify로 꺼낼 첫 기준 구현 후보이므로 채널 어댑터 경계를 지킵니다.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 목록 | 신문사별 뉴스레터 목록(아침 브리핑·속보·주간·사용자 정의), 광고 포함 여부 | P0 |
| 구독 | 구독 폼(Turnstile), 이중 동의 확인 메일, 48시간 뒤 재안내 1회, 확인 페이지, 원클릭 수신 거부, 내 구독 관리 | P0 |
| 발송 | 회차 편집(브리핑 자동 구성 초안), 예약, 발송 잡(묶음), 제공자 웹훅(반송·스팸 신고), 통계 | P0 |
| 법정 | 광고성 목록 `(광고)` 제목·야간 동의, 2년 수신동의 확인 통지 잡 | P0 |
| 웹 푸시 | 서비스 워커, 구독 등록, 속보 발송, 만료 정리 | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/notify-newsletter/server/index.ts` | `NewsletterApi`, `PushApi` |
| `.../server/email/` 어댑터 `resend.ts`, `ses.ts` | `EmailAdapter` 구현 2개(`EMAIL_PROVIDER`로 선택). 트랜잭션 메일 공용 위치(`apps/web/src/server/email/`, 04장 6절)와 같은 어댑터를 쓰고, 공용 추출 때 그대로 이동 |
| `.../server/subscriptions.ts` | `news.subscribe_newsletter`·`confirm`·`unsubscribe`(service) 호출, 토큰 HMAC(`NEWSLETTER_TOKEN_HMAC_KEY`, DB에는 해시만) |
| `.../server/compose.ts` | 아침 브리핑 초안: 전날 KST 06시 이후 게시 기사, 섹션별 상위(M8 조회) |
| `.../server/render-email.ts` | 메일 HTML(인라인 CSS)·텍스트판, RFC 8058 헤더, 광고성 `(광고)` 표기 |
| `worker/src/handlers/news.newsletter/` | `news.newsletter_send`(수신자 확정 → 500명 자식 잡), `news.newsletter_batch`(제공자 배치 API), `news.push_send`(VAPID, 404·410 정리), `news.reconsent`(월 1회 2년 재확인) |
| `apps/web/public/sw.js` | 서비스 워커(`push`, `notificationclick`, `pushsubscriptionchange`) |
| `apps/web/src/app/api/r/newsletter/{subscribe,confirm,unsubscribe}`, `.../api/r/push/subscriptions` | 독자 API(04장 2.1절) |
| `apps/web/src/app/api/webhooks/email/route.ts` | 반송·스팸 신고 → 억제 + 구독 `bounced` |
| `apps/web/src/app/api/newsroom/newsletter/*` | 편집국 목록·회차·통계 |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 이메일 제공자 결정(MD-1)과 발신 서브도메인 DNS 인증(4장) | 테스트 메일이 Gmail·네이버 메일함 받은편지함 도착 |
| 2 | `EmailAdapter` 2종, 웹훅 서명 검증(코어 `receiveWebhook`) | 반송 웹훅 → `bounced` |
| 3 | 구독 폼·이중 동의·확인 페이지 | `pending`에는 어떤 회차도 안 감 |
| 4 | 수신 거부: GET은 안내+버튼, POST는 즉시 해지. 헤더 `List-Unsubscribe`(https + mailto), `List-Unsubscribe-Post: List-Unsubscribe=One-Click` | 메일 앱 "구독 취소" 버튼 동작 |
| 5 | 회차 편집·예약, `news.newsletter_send` → `news.newsletter_batch`(500명, 제공자 429·5xx만 3회 재시도), 월 한도 검사(`news_newsletter_monthly`) | 한도 초과 예약 거부 |
| 6 | 광고성 처리: 목록 `contains_ads`·회차 `contains_ad`면 제목 앞 `(광고)`(SQL CHECK), 21~08시 예약은 야간 동의자만 | 야간 동의자 0이면 예약 거부 |
| 7 | 브리핑 자동 구성(초안만, 편집국 확인 후 예약) | 기사 0건이면 회차 미생성 |
| 8 | `news.reconsent`(월 1회): `reconfirm_due_at` 도래 구독자 통지, 확인 시 `reconfirmed_at` 갱신. 무응답 처리 상태는 05장과 맞춤(02장은 `expired`, 05장 SQL 상태 목록에는 없음) | 시드 데이터로 대상 추출 |
| 9 | (P1) VAPID 키 생성, 서비스 워커, 구독 등록 UI(사용자 동작 뒤에만 권한 요청), 속보 발송 | 거부한 브라우저에 재요청 안 함 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| Resend | 도메인 추가·인증(DNS 레코드는 "add a domain" 문서), 발신은 서브도메인(예 `news-mail.<플랫폼>`)으로 평판 격리, 인증 뒤 DMARC 설정 권장 | https://resend.com/docs/dashboard/domains/introduction (2026-10-15 열람 확인) |
| Amazon SES | 도메인 신원 생성(루트 도메인 입력, Easy DKIM 기본 2048비트), CNAME 3개 게시(반영 최대 72시간), 리전마다 별도 신원, 샌드박스 해제(프로덕션 액세스 요청) 필요 | https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html (2026-10-15 열람 확인) |
| 원클릭 수신 거부 | `List-Unsubscribe`(https URI 1개 포함) + `List-Unsubscribe-Post: List-Unsubscribe=One-Click`, 두 헤더를 DKIM 서명 `h=`에 포함 | https://datatracker.ietf.org/doc/html/rfc8058 (2026-10-15 열람 확인) |
| Gmail 대량 발신자 요건 | SPF·DKIM·DMARC, 원클릭 해지, 스팸 신고율 기준 | https://support.google.com/a/answer/81126 (본문 미확인, 구현 전 열람) |
| Web Push | `PushManager.subscribe({ userVisibleOnly: true, applicationServerKey })`(P-256 공개키, Chrome·Edge는 `userVisibleOnly: true` 필수), HTTPS 필요, endpoint 비밀 | https://developer.mozilla.org/en-US/docs/Web/API/PushManager/subscribe , https://developer.mozilla.org/en-US/docs/Web/API/Push_API (2026-10-15 열람 확인) |
| VAPID | ES256(P-256), JWT `aud`=푸시 서비스 origin, `exp` 24시간 이내, `sub`=`mailto:` 또는 `https:` 연락처 | https://datatracker.ietf.org/doc/html/rfc8292 (2026-10-15 열람 확인) |
| Turnstile | 구독 폼 봇 방지, 서버에서 토큰 검증 | https://developers.cloudflare.com/turnstile/ (구현 시 확인) |
| 카카오 알림톡(P2) | 비즈메시지 대행사 선택(M-D5), 발신 프로필·템플릿 사전 검수 | 미확인(대행사별 문서) |

VAPID 키는 플랫폼 1쌍(모든 신문사 공용, 제안). 신문사마다 키를 나누면 키 관리 부담만 커지고 얻는 것이 적습니다. 키를 바꾸면 기존 구독이 모두 무효가 되므로 교체 계획 없이 바꾸지 않습니다.

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 토큰 해시·만료, 광고성 제목·야간 판정(KST), RFC 8058 헤더 생성, 브리핑 기사 선택 |
| 어댑터 | Resend·SES 목(mock) 서버로 429·5xx 재시도, 웹훅 서명 실패 401 |
| RLS | 구독 표 독자 직접 SELECT는 자기 행만, endpoint 컬럼 사용자 SELECT 불가 |
| E2E | 구독 → 메일함(로컬은 Inbucket/Mailpit, Supabase 로컬 스택 포함 여부 미확인) 확인 링크 → 회차 수신 → 해지 |
| 수동 | Gmail·네이버·다음 메일함 도착·스팸함 여부, 안드로이드 Chrome·데스크톱 푸시 수신 |

## 6. 운영 점검표

- [ ] 발신 도메인 SPF·DKIM·DMARC 통과(메일 헤더 확인), 월 1회
- [ ] 반송률·스팸 신고율 주간 확인(제공자 대시보드)
- [ ] 회차 `failed`·부분 발송 알림 수신
- [ ] 2년 통지 잡 실행 기록
- [ ] 월 발송량이 플랜 한도의 80%면 신문사 알림

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 확인 메일이 스팸함 | 발신 도메인 인증 미완료, DMARC 없음 | 4장 DNS 확인, 서브도메인 평판 쌓기(소량부터) |
| SES에서 일부 주소만 발송 | 샌드박스 상태 | 프로덕션 액세스 요청 |
| 원클릭 해지 버튼이 안 보임 | 헤더가 DKIM 서명에 포함되지 않음 | 제공자 설정에서 서명 헤더 확인 |
| 푸시 구독 실패 | HTTP(비보안) 환경, `userVisibleOnly` 누락 | HTTPS·localhost에서만, 옵션 확인 |
| 푸시가 갑자기 전부 실패 | VAPID 키 교체 | 키 원복, 교체는 재구독 캠페인과 함께 |
