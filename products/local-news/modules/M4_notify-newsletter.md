# M4 notify-newsletter: 뉴스레터와 속보 웹 푸시

작성일 2026-10-15. 표 정본 `docs/products/local-news/05_DATA_MODEL.md`, 발송량 한도는 플랜 키 `news_newsletter_monthly`(`docs/products/local-news/01_PRD.md` 4절).

## 1. 목적과 범위

지역 독자와 매일 만나는 통로(뉴스레터)와 속보 통로(웹 푸시)를 만든다. 지역 매체 뉴스레터 구독자 중간값은 6,000명이다(https://inn.org/research/inn-index/2026-index/revenue-expenses/). 공용 `notify`(0100) 모듈의 첫 기준 구현이 될 수 있도록 채널 어댑터·동의·발송 기록을 분리해 만든다.

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 뉴스레터 목록(여러 개), 이중 동의 구독, 아침 브리핑 자동 구성(전날 게시 기사 + 편집 메모), 예약 발송, 수신 거부(원클릭), 반송·스팸 신고 처리, 열람·클릭 근사 통계, 2년 수신동의 확인 통지 | NW-F-037 |
| 확장(P1) | 속보 웹 푸시(주제 구독), 야간 광고성 발송 별도 동의 | NW-F-038 |
| 확장(P2) | 카카오 알림톡(비즈메시지 대행사, 템플릿 사전 검수), SMS | NW-F-038 P2 |
| 하지 않음 | 구독자 목록 구매·가져오기 후 바로 발송(이중 동의 없는 목록 금지), 자체 메일 서버 운영 | - |

## 2. 벤치마크

| 제품 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Ghost 뉴스레터·멤버 | 받은편지함 링크 클릭으로 확인한 사람만 회원, 비밀번호 없는 매직 링크, 회원별 이메일 수신 여부 필드 | Ghost 자체 메일 발송 인프라(Mailgun 결합) | https://docs.ghost.org/members (2026-10-15 열람 확인) |
| beehiiv 이중 동의 | 확인 전 상태 `Pending`, 확인 전에는 환영 메일 포함 어떤 메일도 안 보냄, 48시간 뒤 1회 재안내(Smart Nudge), 일부는 영구 Pending이 정상 | 성장 도구(추천 보상) | https://www.beehiiv.com/support/article/13081072798743-How-to-enable-double-opt-in-and-Smart-Nudge (2026-10-15 열람 확인) |
| Newspack 뉴스레터 | 등록·결제 흐름 안에서 뉴스레터 선택, 뉴스레터 링크로 페이월 1시간 우회(M2 연동 후보) | 외부 ESP 다중 연동 | https://help.newspack.com/reader-activation-system/ , https://help.newspack.com/?p=17054 (2026-10-15 열람 확인) |
| Substack | 개인 기자형 유료 뉴스레터 구조는 참고만(유료 구독 10% 수수료, 조사 에이전트 경쟁 표 기준) | 수수료형 모델 | 미확인(공식 문서 직접 열람 안 함) |
| RFC 8058 원클릭 수신 거부 | `List-Unsubscribe`(https URI) + `List-Unsubscribe-Post: List-Unsubscribe=One-Click`, 두 헤더를 DKIM 서명에 포함 | - | https://datatracker.ietf.org/doc/html/rfc8058 (2026-10-15 열람 확인) |
| Web Push(MDN, RFC 8292) | 서비스 워커 + `PushManager.subscribe({ userVisibleOnly: true, applicationServerKey })`, P-256 VAPID 키, 구독 endpoint는 비밀, `pushsubscriptionchange` 처리, CSRF 방어 | - | https://developer.mozilla.org/en-US/docs/Web/API/Push_API , https://developer.mozilla.org/en-US/docs/Web/API/PushManager/subscribe , https://datatracker.ietf.org/doc/html/rfc8292 (2026-10-15 열람 확인) |

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `newsletter_lists`, `newsletter_subscriptions`, `newsletter_issues`, `push_subscriptions` |
| 소유 RPC | `news.upsert_newsletter_list`, `news.subscribe_newsletter`, `news.confirm_newsletter`, `news.unsubscribe_newsletter`(토큰), `news.issue_newsletter_reconfirm`, `news.save_newsletter_issue`, `news.record_newsletter_issue_status`, `news.register_push_subscription`·`news.revoke_push_subscription` — 이름은 05장 SQL |
| 쓰는 코어 | jobs(큐 `news.newsletter`), webhooks(이메일 제공자 반송·스팸 신고), rate_limit(구독 폼), audit, encrypted_credentials(신문사별 발신 도메인 키가 필요할 때) |
| 쓰는 모듈 | M1 기사 읽기(브리핑 구성, 속보 대상), M2 `readers` 연결(로그인 독자 구독), M7 광고성 표기 규칙 |
| 소비자 | 독자 화면 구독 블록·내 구독 관리, M8 구독자 수·열람률 |

## 4. 데이터 (요약, 상세 `docs/products/local-news/05_DATA_MODEL.md`)

| 표 | 핵심 컬럼(요약) |
|---|---|
| `newsletter_lists` | slug, 이름, 설명, 종류(`morning_brief`·`breaking`·`weekly`·`custom`), 공개 여부, 광고 포함(`contains_ads`, 광고성), 상태(`active`·`archived`) |
| `newsletter_subscriptions` | 목록, 독자 id(선택), 이메일·이메일 해시((목록, 해시) 유일), 상태, 확인 토큰 해시·만료·재발송 횟수, 수신 거부 토큰 해시, 동의 문구 버전·시각, 광고 동의, 야간 동의, 확인 시각, 재확인 시각·다음 재확인 기한, 해지 시각·사유, 구독 경로 |
| `newsletter_issues` | 목록, 제목, 프리헤더, 본문 JSON, 포함 기사 id, 광고 포함, 상태, 예약·발송 시각, 수신자·전달·열람·클릭 수 |
| `push_subscriptions` | 독자 id(선택), endpoint·endpoint 해시((조직, 해시) 유일), 주제, 상태(`active`·`revoked`), 실패 횟수, 마지막 발송 시각 |

## 5. 인터페이스

```ts
// src/modules/notify-newsletter/server/index.ts — 계약 예시(구현 파일 아님)
export type SubscriptionStatus = 'pending' | 'confirmed' | 'unsubscribed' | 'bounced'   // 정본 05장
export interface EmailAdapter {                       // 공용 notify 추출 때 그대로 옮길 경계
  provider: 'resend' | 'ses'
  send(msg: { from: string; to: string; subject: string; html: string; text: string; headers: Record<string, string>; tags: Record<string, string> }): Promise<{ providerMessageId: string }>
  verifyWebhook(req: { headers: Headers; rawBody: string }): { ok: boolean; eventId: string; type: 'delivered' | 'bounced' | 'complained' | 'opened' | 'clicked'; email: string }
}
export interface NewsletterApi {
  subscribe(input: { orgId: string; listSlugs: string[]; email: string;   // 목록마다 rpc news.subscribe_newsletter(service, list_slug) 호출 consentVersion: string; nightConsent?: boolean; requestId: string; turnstileToken: string }): Promise<{ status: 'pending' }>
  confirm(token: string): Promise<{ orgId: string; lists: string[] }>        // rpc news.confirm_newsletter
  unsubscribe(token: string): Promise<void>                                   // rpc news.unsubscribe_newsletter, GET 안내 + POST 원클릭
  composeBriefing(orgId: string, listId: string, forDate: string): Promise<{ issueId: string }>  // 초안만, 사람 확인 후 예약(제안)
  scheduleIssue(issueId: string, at: Date): Promise<void>                     // 잡 news.newsletter_send → news.newsletter_batch(500명 단위)
}
export interface PushApi {
  register(input: { orgId: string; subscription: PushSubscriptionJSON; topics: string[]; requestId: string }): Promise<void>
  sendBreaking(orgId: string, articleId: string): Promise<{ queued: number }>  // editor 이상, 기사 게시 상태 확인
}
```

| 이벤트 | 발생 | 구독 |
|---|---|---|
| `news.newsletter.confirmed` / `.unsubscribed` | 확인·해지 | M8, 환영 메일(확인 뒤에만) |
| `news.newsletter.issue.sent` | 회차 발송 완료 | M8, 편집국 알림 |
| `news.push.sent` | 속보 푸시 | M8 |
| 구독: `news.article.published`(M1) | `is_breaking` 기사면 `news.post_publish`가 `news.push_send` enqueue(속보 표시는 편집인 이상이 게시 화면에서 켠다) | - |
| 구독: `news.reader.withdrawn`(M2) | 그 독자 구독 전부 해지 | - |

## 6. 상태·규칙

| 표 | 전이 |
|---|---|
| `newsletter_subscriptions` | `pending` → `confirmed`(확인 링크), `confirmed` → `unsubscribed` / `bounced`(하드 반송·스팸 신고, 억제 목록), `unsubscribed` → `pending`(재구독은 다시 이중 동의). 2년 재확인 무응답 처리(02장 `news.reconsent`의 `expired`)와 04장 웹훅 절의 `suppressed`는 05장 SQL 상태 목록에 없어 05장에서 맞춰야 한다 |
| `newsletter_issues` | `draft` → `scheduled` → `sending` → `sent` / `failed`, `scheduled` → `canceled` |
| `push_subscriptions` | `active` → `revoked`(제공자 404·410 또는 독자 해지) |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 이중 동의 | 확인 전에는 어떤 메일도 보내지 않는다(확인 메일 1통과 48시간 뒤 재안내 1통만, 제안) | beehiiv 이중 동의 문서 |
| 광고성 판단 | 광고가 들어간 목록은 광고성 정보로 보고 제목 앞 `(광고)`, 본문 끝 수신 거부 방법, 21시~08시 발송은 별도 야간 동의자에게만. 광고 없는 순수 뉴스 목록의 광고성 해당 여부는 법무 확인 전까지 광고성으로 취급(제안, 미확인) | 정보통신망법 제50조(`docs/products/local-news/01_PRD.md` 법 절), `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:94` |
| 2년 확인 | 동의일부터 2년마다 수신동의 사실(발신자, 동의 일자, 철회 방법)을 통지하는 잡 `news.reconsent`(월 1회). `reconfirm_due_at`(=확인 + 2년)은 트리거가 계산하고, 잡이 `news.issue_newsletter_reconfirm`으로 새 토큰을 받아 메일, 독자가 누르면 `news.confirm_newsletter`가 기한을 2년 늘린다. 시행령 조문·통지 항목은 law.go.kr 원문 미확인 | `docs/products/local-news/01_PRD.md` 6.1절, `docs/products/local-news/02_ARCHITECTURE.md` 4절 |
| 원클릭 해지 | 모든 메일에 RFC 8058 헤더, 해지 즉시 반영(다음 발송에서 제외) | RFC 8058 |
| 발신 도메인 | 플랫폼 공용 발신 서브도메인(예 `news-mail.<플랫폼>`)을 기본, 신문사 자기 도메인 발신은 DNS 인증(SPF·DKIM) 후 P1(제안). 서브도메인 분리로 평판 격리 | https://resend.com/docs/dashboard/domains/introduction |
| 한도 | 월 발송 수는 플랜 키 `news_newsletter_monthly`. 초과 예정 회차는 예약 단계에서 거부 | 01장 4절 |
| 속보 푸시 | 신문사당 시간당 상한(제안 3건), 편집인 이상만, 게시된 기사만 | 제안 |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| 제공자 오류(5xx·429) | 회차 잡이 수신자 묶음 단위로 재시도(지수 백오프). 3회 실패 묶음은 `failed` 기록 후 회차 `failed`, 편집국 알림. 부분 발송 수를 보여 준다 |
| 하드 반송·스팸 신고 웹훅(`/api/webhooks/email`) | 해당 구독 `bounced` + 억제 목록, 이후 발송 제외 |
| 웹 푸시 404·410 | 구독 `revoked`. 다른 오류는 `news.push_send` 재시도(2회) |
| 확인 토큰 만료(제안 7일) | 재구독 안내 화면 |
| 브리핑 자동 구성에 기사 0건 | 회차를 만들지 않고 편집국에 알림(빈 메일 발송 금지) |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 구독 폼 | 레이트 리밋(IP 해시), Turnstile, 허니팟. 같은 이메일 반복 구독은 확인 메일 재발송 상한 |
| 토큰 | 확인·해지 토큰은 해시만 저장, 원문은 메일 링크에만 |
| endpoint | 푸시 endpoint는 비밀이므로 사용자 SELECT 정책 없음, 서버만 읽는다(MDN Push API) |
| 열람 추적 | 열람 픽셀은 근사치(메일 앱의 사전 로드로 부풀 수 있음, 제안)로 표기, 개인별 열람 기록을 편집국에 노출하지 않고 회차 합계만 |
| 보관 | 해지 후 이메일은 수신 거부 증빙 목적의 해시만 남기고 파기(기간 제안 1년, 법무 확인 미확인) |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-037 | `pending` 주소로 발송 0건(`confirmed`만 발송), 해지 클릭 후 다음 회차 제외, 모든 메일에 `List-Unsubscribe`·`List-Unsubscribe-Post` 헤더, 광고성 목록 제목에 `(광고)`, 21~08시 예약은 야간 동의자만, 2년 통지 잡이 대상자를 뽑음 |
| NW-F-038 | 구독 거부 브라우저에 요청 반복 없음(한 번 거부 시 배너 숨김), 만료 endpoint 자동 정리, 시간당 상한 초과 시 거부 |

## 10. 추출 조건

`notify`(0100)가 착수되면(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:87-98`) `EmailAdapter`, 구독 동의·확인·해지, 발송 기록, 웹 푸시를 그대로 옮긴다. 이 모듈이 공용 notify의 첫 기준 구현 후보다. 아침 브리핑 자동 구성(기사 선택 규칙)은 뉴스 전용으로 남긴다.
