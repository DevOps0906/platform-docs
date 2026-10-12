# 04 API: NOMAD Blog

작성일 2026-10-12. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다. 제품 RPC 정본은 `docs/products/_supabase-modular/migrations/1300_blog.sql`이다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 `/api/**`(웹훅, `/r` 제외)는 진입부에서 `requireSession('blog', { roles })`. 미로그인 401, pending/suspended 403, `entitled=false` 402 |
| 입력 검증 | zod 스키마. 실패 422 + 필드 오류 |
| 멱등 | 생성·발행·지원 요청은 클라이언트 UUID `request_id` 필수. 키: `consume:blog:<request_id>`, `job:blog:<request_id>`, 발행 행 `idempotency_key = pub:<request_id>:<channel_account_id>` |
| 크레딧 선차감 | Route Handler에서 service_role로 `consume_credits` → `enqueue_job(p_credit_ledger_id)` 또는 동기 호출(`withCredits`). 사용자 RPC 안에서 차감하지 않는다(`DB_CONVENTIONS.md` 11장) |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. `message`는 사용자 문구. 예외 원문·스택 금지 |
| 레이트 리밋 | `core.rate_limit_hit` 키 `blog:<route>:<org_id>`. 생성 60회/분, 브랜드커넥트 지원 `blog:bc:<account_id>` 5회/시간, `/r` `affiliate:r:<ip_hash>` 60회/분 |
| 감사 | 01장 BL-F-006 행동은 서버가 `auditAsService` 또는 제품 RPC 내부 `write_audit` |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어/제품 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/ai/keywords` | member+ | `{ request_id, topic(1~100자), channel: naver\|tistory\|wordpress }` | `{ keywords: [{keyword, volume_est, competition_est, intent, reason}] (10) }` | 1 | `consume_credits`, 실패 시 `refund_credits` | 402 CR001, 502 AI_FAILED(환불됨) |
| POST `/api/ai/outline` | member+ | `{ request_id, keyword, template }` | `{ titles: string[3], outline: string[] }` | 1 | 같음 | 같음 |
| POST `/api/posts` | member+ | `{ title?, template?, target_keyword? }` | `{ post }` | 0 | 브라우저 직접 INSERT도 가능(RLS) | 403 |
| POST `/api/posts/:id/generate` | member+, quality는 `ai_modes` 포함 | `{ request_id, keyword, template, length: short\|medium\|long, tone?, mode: fast\|quality, outline?, title?, experience_note?(experience 필수 50자+), affiliate_auto?: boolean(Pro+) }` | `{ job_id }` 202 | 3/6(+1) | `consume_credits` → posts.status generating(service) → `enqueue_job('blog.ai','blog.generate')` | 402, 403 PLAN_REQUIRED, 409 BL001(generating/publishing) |
| POST `/api/posts/:id/rewrite` | member+ | `{ request_id, selection(1~1,500자), instruction(1~200자) }` | `{ text }` | 1 | `withCredits` | 402, 502 |
| POST `/api/posts/:id/tags` | member+ | `{ request_id }` | `{ tags: string[≤10] }` | 1 | `withCredits` | 402 |
| POST `/api/posts/:id/seo` | member+ | `{}` | `{ score, items: [{rule, ok, message}] }` 및 posts.seo_* 저장(service) | 0 | - | - |
| POST `/api/posts/:id/compliance` | member+ | `{ request_id }` | `{ verdict, issues, suggestions }` | 1(LLM 단계) | compliance `check` → posts.compliance_* 저장(service) | 402, LLM 오류 시 verdict=warn |
| POST `/api/posts/:id/compliance/ack` | member+ | `{}` | `{ post }` | 0 | `blog.acknowledge_compliance_warning` | 409 BL003 |
| POST `/api/posts/:id/publish` | member+, 예약은 `schedule` | `{ request_id, targets: [{channel_account_id}] (1~10), scheduled_at?, policy_ack?: ['naver_coupang'] }` | `{ publications: [{id, status, job_id}] }` 202 | 0 | 서버 순서: 엔타이틀먼트 → `blog.monthly_post_usage` 한도 → 채널 정책 경고 확인 → 렌더 미리 검증 → 발행 행 INSERT(DB 게이트) → `enqueue_job('blog.publish' 또는 'blog.browser', 'blog.publish.<channel>', run_after=scheduled_at)` → 행에 job_id | 402 BL004, 409 BL003/BL005/BL006/23505(진행 중 발행), 422 |
| POST `/api/publications/:id/cancel` | member+ | `{}` | `{ publication }` | 0 | `blog.cancel_publication`(내부 `core.cancel_job`) | 409 BL002/JB002 |
| POST `/api/publications/:id/retry` | member+ | `{ request_id }` | `{ publication, job_id }` | 0 | service: failed → queued, 새 잡 | 409 BL001 |
| POST `/api/publications/:id/resolve` | member+ | `{ published_url: https URL \| null }` | `{ publication }` | 0 | `blog.resolve_unconfirmed_publication` | 409 BL001, 422 |
| POST `/api/posts/:id/archive` | member+ | `{ archived: boolean }` | `{ post }` | 0 | `blog.set_post_archived` | 409 22023 |
| POST `/api/channels` | owner/admin | `{ channel, label, blog_url?, username?, secret(비밀번호 또는 앱 비밀번호) }` | `{ channel_account }` | 0 | 플랜 한도 검사 → `CredentialVault.put` → channel_accounts INSERT(service, status pending) → wordpress는 동기 검증, naver/tistory는 동의 확인 후 `blog.channel.verify` 잡 | 403 PLAN_LIMIT, 409 BL005(동의 필요), 422 URL_NOT_ALLOWED |
| POST `/api/channels/:id/consent` | owner/admin | `{ notice_version }` | `{ channel_account }` | 0 | `blog.consent_channel_automation_risk` | 409 NOTICE_OUTDATED(서버 현재 버전과 다름) |
| POST `/api/channels/:id/verify` | owner/admin | `{ request_id }` | `{ job_id }` | 0 | `enqueue_job('blog.browser','blog.channel.verify')` | 409 |
| DELETE `/api/channels/:id` | owner/admin | - | `{ channel_account }` | 0 | `blog.disconnect_channel_account` | 403 |
| POST `/api/affiliate/accounts` | owner/admin | `{ provider, partner_id?, access_key?, secret_key?, label? }` | `{ account }` | 0 | `CredentialVault.put` + `AffiliateApi.connectAccount` | 422 |
| GET `/api/affiliate/search` | member+, `affiliate` | `?provider=coupang&q=&limit≤20` | `{ products }` | 0 | 어댑터 `searchProducts` | 409 PROVIDER_NO_SEARCH(텐핑 등) |
| POST `/api/posts/:id/affiliate-links` | member+ | `{ provider, product | manual_url, placement, position }` | `{ link_id, short_url, affiliate_url, card }` | 0 | `createShortLink`(source_app blog, source_ref post id) + `post_affiliate_links` INSERT(service) | 422 URL_NOT_ALLOWED |
| DELETE `/api/posts/:id/affiliate-links/:linkId` | member+ | - | 204 | 0 | 매핑 DELETE(service). `affiliate_links`는 `is_active=false` | - |
| GET `/api/affiliate/stats` | owner/admin | `?range=7d\|30d` | `{ by_link, by_post, by_provider }` | 0 | `affiliate_clicks` 집계 | - |
| PUT `/api/settings/disclosure` | owner/admin | `{ provider, body(10~300자, 이해관계 단어 포함) }` | `{ id }` | 0 | `core.upsert_affiliate_disclosure(org, provider, 'blog_top', body)` | 422 DISCLOSURE_WEAK |
| POST `/api/brandconnect/accounts` | owner/admin, `brandconnect` | `{ channel_account_id }`(자격증명 공유) | `{ account }` | 0 | `connectAccount(provider naver_brandconnect, credential_id)` | 403 |
| POST `/api/brandconnect/accounts/:id/consent` | owner/admin | `{ notice_version }` | `{ ok }` | 0 | `core.consent_brandconnect_risk` + 감사 `blog.brandconnect.risk_notice_ack` | 409 NOTICE_OUTDATED |
| DELETE `/api/brandconnect/accounts/:id/consent` | owner/admin | - | `{ ok }` | 0 | service: `risk_consented_at=null`, 대기 지원 잡 `cancel_job`, 감사 | - |
| POST `/api/brandconnect/scan` | member+ | `{ request_id, account_id, keyword? }` | `{ job_id }` | 0 | 하루 4회 제한 → `enqueue_job('blog.browser','brandconnect.scan')` | 429 |
| POST `/api/brandconnect/applications` | member+ | `{ request_id, account_id, campaign_id, blog_url, brand_name?, product_name?, category?, message(≤1,000자) }` | `{ application_id, job_id }` | 0 | `rate_limit_hit(5/h, 20/d)` → `core.create_brandconnect_application` → `enqueue_job('brandconnect.apply')` | 403 42501(동의 없음), 429 |
| POST `/api/brandconnect/message` | member+ | `{ request_id, campaign, draft }` | `{ message }` | 1 | `withCredits` | 402 |
| POST `/api/billing/orders` | owner/admin | `{ kind: subscription\|credit_pack, plan_code?, pack_code? }` | `{ orderId, amountKrw, customerKey }` | 0 | `TossApi.createOrder` | 422 |
| POST `/api/billing/confirm` | owner/admin | `{ orderId, paymentKey, amount }` | `{ payment }` | 0 | `TossApi.confirm` → `confirm_payment_order` | 409 PM001(운영 알림 + Toss 취소), PM409, PM410 |
| POST `/api/exports` | owner/admin | `{ request_id, post_ids?(≤500), format: md\|html }` | `{ job_id }` | 0 | `enqueue_job('blog.export')` | - |
| GET `/r/:code` | 누구나 | - | 302 | 0 | `rate_limit_hit` → `record_affiliate_click`(service) | 404(없음·비활성), 429 |

## 3. RPC (SECURITY DEFINER)

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `blog.cancel_publication(p_publication_id uuid)` | authenticated, service_role | `is_service_caller` 또는 `has_org_role(owner,admin,member)`. status queued/scheduled. 잡이 있으면 `core.cancel_job` | `blog.post_publications` | P0002, 42501, BL002, JB002 |
| `blog.resolve_unconfirmed_publication(p_publication_id uuid, p_published_url text)` | authenticated, service_role | 멤버(viewer 제외), status unconfirmed, URL https | 같음 | P0002, 42501, BL001, 22023 |
| `blog.acknowledge_compliance_warning(p_post_id uuid)` | authenticated, service_role | 멤버(viewer 제외), verdict warn | `blog.posts` | P0002, 42501, BL003 |
| `blog.set_post_archived(p_post_id uuid, p_archived boolean)` | authenticated, service_role | 멤버(viewer 제외), 전이 트리거 | `blog.posts` | P0002, 42501, 22023 |
| `blog.consent_channel_automation_risk(p_account_id uuid, p_notice_version text)` | authenticated, service_role | owner/admin, channel naver/tistory, 버전 필수 | `blog.channel_accounts` | P0002, 42501, 22023 |
| `blog.disconnect_channel_account(p_account_id uuid)` | authenticated, service_role | owner/admin. 공유되지 않은 자격증명만 `core.revoke_credential` | `blog.channel_accounts` | P0002, 42501 |
| `blog.monthly_post_usage(p_org_id uuid)` | authenticated, service_role | 멤버 또는 service | integer | 42501 |
| `blog.acquire_channel_lock(p_account_id, p_job_id, p_ttl_seconds)` | service_role 전용 | `is_privileged_session` | boolean | 42501 |
| `blog.release_channel_lock(p_account_id, p_job_id)` | service_role 전용 | 같음 | void | 42501 |

코어 RPC: `consume_credits`/`grant_credits`/`refund_credits`(`CORE_SPEC.md` 4.2절), `enqueue_job`/`claim_jobs`/`heartbeat_job`/`complete_job`/`fail_job`/`cancel_job`(9장), `effective_disclosure`/`upsert_affiliate_disclosure`/`consent_brandconnect_risk`/`create_brandconnect_application`/`record_affiliate_click`(13장), `confirm_payment_order`(5장), `rate_limit_hit`(12장), `write_audit`(11장).

## 4. 잡 페이로드 계약

모든 페이로드에 `org_id`, `request_id`를 넣는다. 비밀값은 넣지 않고 id만.

| `job_type` | payload | result | progress 메시지 |
|---|---|---|---|
| `blog.generate` | `{ post_id, keyword, template, length, tone?, mode, outline?, title?, experience_note_ref: 'post', affiliate_auto: boolean, affiliate_account_ids: uuid[] }` | `{ post_id, version, word_count, affiliate_cards: number, model, usage_id }` | 10 "개요 정리" → 50 "본문 작성" → 80 "제휴 상품 찾기" → 100 |
| `blog.publish.wordpress` | `{ publication_id, post_id, channel_account_id, rendered_hash }` | `{ external_post_id, published_url }` | 20 렌더 → 60 업로드 → 100 |
| `blog.publish.naver` / `blog.publish.tistory` | 같음 | `{ external_post_id?, published_url?, outcome: published\|unconfirmed, screenshot_path? }` | 10 잠금 → 30 로그인 확인 → 60 원고 입력 → 80 발행 클릭(이후 취소 불가) → 100 |
| `blog.channel.verify` | `{ channel_account_id }` | `{ status: active\|needs_reauth\|error, external_account_id, session_expires_at }` | - |
| `brandconnect.scan` | `{ affiliate_account_id, keyword? }` | `{ campaigns: [{campaign_id, title, brand, deadline, reward}] (≤50), scanned_at }` | - |
| `brandconnect.apply` | `{ application_id }` | `{ external_id?, outcome: submitted\|failed }` | 80 "제출 클릭" 이후 취소 불가 |
| `brandconnect.sync` | `{ affiliate_account_id }` | `{ updated: [{application_id, status}] }` | - |
| `blog.export` | `{ post_ids, format }` | `{ storage_path, count }` | 퍼센트 |

워커 처리 순서(발행): `claim` → 발행 행 `publishing`(DB가 링크 수·문구 필요 여부 재계산) → `acquire_channel_lock` → 렌더(DB 최신 원고, 대가성 문구 삽입, `disclosure_included` 기록) → 어댑터 → 결과 반영(`published`/`unconfirmed`/`failed`) → `complete_job`/`fail_job` → `release_channel_lock`.

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태 | 공용 webhooks 모듈(서명 필수) | `CORE_SPEC.md` 6장 | 상태 동기화만, 지급은 confirm 경로 |
| 수신 | n8n/Make 콜백(Phase 2) | HMAC 필수 | `X-Request-Id` | automation-core |
| 발신 | `post.published`, `post.failed`, `brandconnect.status_changed`(Phase 2, Business) | HMAC-SHA256 + 타임스탬프 | - | automation-core `emit`. 원본 "내 블로그" API 대체 |

## 6. 외부 API 어댑터

```ts
// workers/blog-worker 계약 예시(구현 파일 아님)
export interface ChannelPublisher {
  channel: 'naver' | 'tistory' | 'wordpress'
  verify(ctx: { account: ChannelAccount; secret: unknown }): Promise<{ externalAccountId: string; sessionExpiresAt?: string; session?: unknown }>
  publish(ctx: { account: ChannelAccount; secret: unknown; signal: AbortSignal; heartbeat(p: number, m: string): Promise<boolean> },
          post: { title: string; html: string; tags: string[]; coverPath?: string }): Promise<{ outcome: 'published' | 'unconfirmed'; externalPostId?: string; url?: string }>
}
```

| 대상 | 호출 위치 | 방식 | 실패 처리 | 쿼터/상한 |
|---|---|---|---|---|
| 워드프레스 REST(`/wp-json/wp/v2/posts`, `tags`, `media`) | 워커 | Basic(애플리케이션 비밀번호). 태그는 검색 후 없으면 생성(`NOMAD Shorts Maker/src/skill/channel-api/wordpress-client.ts:34-55`). Yoast 메타는 플러그인 있을 때만 | 401 → 채널 `error` + 재연결 요청. 5xx → 재시도 | 계정당 30건/일(제안) |
| 네이버 블로그(스마트에디터) | 워커 Playwright | 세션 쿠키 주입 → 글쓰기 → 제목 → 본문 HTML 붙여넣기 → 태그(최대 10) → 발행 → URL 파싱(`[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:180-288`) | 로그인·CAPTCHA 페이지 → `needs_reauth`, 재시도 없음. 발행 클릭 후 URL 미확인 → `unconfirmed` | 5건/일, 10분 간격(제안) |
| 티스토리 | 워커 Playwright | `NOMAD Shorts Maker/src/skill/playwright-engine/tistory-poster.ts:47-85`. 공식 API 제공 여부 미확인 | 네이버와 같음 | 같음 |
| 쿠팡파트너스 | 웹(서버) | HMAC `CEA algorithm=HmacSHA256`(`coupang-client.ts:5-12`), 조직 키 | 4xx → 사용자 오류 표시, 5xx → 1회 재시도 | 제공자 호출 한도 미확인 |
| 텐핑, 네이버쇼핑 커넥트 | - | 공개 API 미확인. 수동 URL 등록만 | - | - |
| 네이버 브랜드커넥트 | 워커 Playwright | `NOMAD Shorts Maker/src/skill/playwright-engine/brand-connect.ts`의 흐름을 셀렉터 상수 파일로 분리해 이식 | 셀렉터 미발견 → failed + 운영 알림(사이트 변경 감지). "지원 완료" 확인 실패 → failed + "네이버에서 확인해 주세요" | 5건/시간, 20건/일 |
| LLM | 웹·워커 | core llm gateway | 5절 | 조직당 60회/분 |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| `42501` | 권한 없음(역할, 비멤버, 동의 없음) | 403 |
| `CR001` | 크레딧 부족 | 402 |
| `BL001` | 원고/발행 상태가 요청을 허용하지 않음 | 409 |
| `BL002` | 취소할 수 없는 발행(실행 중·완료) | 409 |
| `BL003` | 컴플라이언스 미통과(FAIL, 미검사, WARN 미확인) | 409 |
| `BL004` | 월 발행 한도 초과(서버 판정) | 402 |
| `BL005` | 채널 사용 불가(비활성, 자동화 위험 동의 없음) | 409 |
| `BL006` | 채널 정책 경고 미확인(네이버 + 쿠팡) | 409 |
| `23505` | 같은 원고·계정의 진행 중 발행 존재 | 409 |
| `23514` | 대가성 문구 불변식 위반(서버 버그) | 500 + 운영 알림 |
| `22023` | 인자·상태 전이 오류 | 409 |
| `JB002` | 이미 실행 중인 잡 | 409 |
| `PM001`/`PM409`/`PM410` | 결제 확인 실패 | 409 + 운영 알림 |
| `P0002` | 대상 없음 | 404 |
| `AI_FAILED` | LLM 실패(환불 완료) | 502 |
| `URL_NOT_ALLOWED` | https 아님, 사설 IP, 허용 도메인 밖 | 422 |
