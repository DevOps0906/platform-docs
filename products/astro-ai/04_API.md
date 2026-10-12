# 04 API: 신비로운AI

모든 Route Handler는 `apps/astro-ai/src/app/api/` 아래, `runtime = 'nodejs'`다(Edge 금지, 02장 6절 FD #6). 코어 RPC 시그니처는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 진입부 `requireSession('astro')`(`docs/products/_platform-core/SHARED_MODULES.md:67-69`). 미로그인 401, pending/suspended 403, 엔타이틀먼트 없음 402. 어드민은 `platform_role='platform_admin'` 아니면 403 |
| 조직 | 요청 본문의 `org_id`를 받지 않는다. 세션의 개인 조직(`ctx.org.id`)만 쓴다 |
| 멱등 | 쓰기 요청은 클라이언트가 만든 UUID `request_id`를 보낸다. 차감 키 `consume:astro:<request_id>`, 잡 키 `job:astro:<request_id>`, 테이블 `request_id` 유일 |
| 크레딧 선차감 위치 | `POST /api/readings`, `POST /api/readings/[id]/renders`의 Route Handler만. 사용자 RPC 안에서는 차감하지 않는다 |
| 검증 | 모든 입력은 zod. 알 수 없는 키 거부(`strict()`) |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. `code`는 7장 |
| 레이트 리밋 | `core.rate_limit_hit` 키 `astro:<route>:<org_id 또는 ip_hash>`. 초과 429 + `Retry-After` |
| 쓰기 경로 | service_role(`createAdminClient`)은 권한 확인 뒤에만 사용. 사용자 세션 클라이언트로 쓸 수 있는 것은 `preferences`와 `rpc('cancel_reading')`뿐 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/auth/welcome` | 로그인 | 없음 | `{ granted: boolean, balance }` | +30(1회) | `grant_credits(org, features.welcome_credits, 'astro', 'welcome_credits', 'pack', 'signup', user_id, 'signup:<org>:astro')`, `rate_limit_hit('astro:signup:<ip_hash>', 3, 86400)` | 이메일 미인증 409, 보류 429 |
| `GET /api/subjects` | owner | - | `[{ id, alias, relation, gender, day_pillar, birth_summary }]`(복호화 요약) | 0 | - | - |
| `POST /api/subjects` | owner | `{ request_id, alias(1..20), relation, gender, birth_date, birth_time?, birth_time_unknown, calendar_type, is_leap_month, zi_hour_mode, birth_place_code?, real_name?, third_party_consent?: true, consent_version }` | `{ id }` | 0 | `write_audit('subject.create')` | 400 동의 누락, 409 상한(`max_subjects`)/본인 중복, 422 존재하지 않는 음력일 |
| `GET /api/subjects/[id]` | owner | - | 복호화된 입력 + 원국(`chart`) | 0 | - | 404 |
| `GET /api/subjects/[id]/chart` | owner | - | 엔진 결과(4주, 오행, 십신, 대운) | 0 | - | 404 |
| `PATCH /api/subjects/[id]` | owner | `POST` 필드 부분 | `{ id }` | 0 | `write_audit('subject.update')` | 404, 409(진행 중 리딩) |
| `DELETE /api/subjects/[id]` | owner/admin | `{ confirm_alias }` | 204 | 0 | `write_audit('subject.delete')`; 파일 삭제 실패분은 `enqueue_job('astro.storage.purge')` | 409 진행 중 리딩, 422 호칭 불일치 |
| `POST /api/readings` | owner, `features.readings` | `{ request_id, kind: saju\|tarot\|combined, subject_id?, tarot_cards?: [{card 0..21, reversed, position: past\|present\|future}] x3, question?(≤200), theme_key }` | 202 `{ reading_id, status }` / 같은 `request_id` 재요청 200 | 15/20/30 | `rate_limit_hit('astro:readings:<org>', 10, 60)`, `consume_credits`, `enqueue_job`, 실패 시 `refund_credits` | 402 `CR001`, 403 종류·테마 불허, 409 진행 중 3건, 422 카드 중복 |
| `GET /api/readings/[id]` | owner | - | 리딩 + 현재 렌더 + 발송 상태 | 0 | - | 404 |
| `POST /api/readings/[id]/cancel` | owner | - | 리딩 | 환불 | 사용자 세션 `rpc('cancel_reading')` | 409 `AS002`/`JB002` |
| `POST /api/readings/[id]/renders` | owner | `{ request_id, theme_key }` | 202 `{ render_id }` | 5 | `consume_credits('consume:astro:<request_id>')`, `enqueue_job('astro.render.regenerate')` | 409 리딩 미완료, 402 |
| `GET /api/readings/[id]/download?render=` | owner | render id(선택) | `{ url, expires_at }`(7일) | 0 | `rate_limit_hit('astro:download:<org>', 60, 3600)` | 404, 409 렌더 미완료 |
| `DELETE /api/readings/[id]` | owner/admin | - | 204 | 0 | `write_audit('reading.delete')` | 409 진행 중 |
| `POST /api/deliveries/[id]/resend` | owner | `{ email? }` | `{ status: 'pending' }` | 0 | `rate_limit_hit('astro:resend:<org>', 3, 86400)` | 409 상태가 dead/sent 아님 |
| `PATCH /api/consents` | owner | `{ marketing_email: boolean }` | 204 | 0 | - | - |
| `POST /api/demo/preview` | 비로그인 허용 | `{ birth_date, birth_time?, calendar_type, is_leap_month, gender }` | `{ pillars, keywords: string[3] }` | 0 | `rate_limit_hit('astro:demo:<ip_hash>', 3, 86400)` | 429. 입력 저장·로그 금지 |
| `POST /api/billing/orders` | owner | `{ credit_pack_code }` | `{ orderId, amount, customerKey, orderName }` | 0 | `payment_orders` INSERT(service_role, 금액은 `credit_packs`) | 404 |
| `POST /api/billing/confirm` | owner | `{ paymentKey, orderId, amount }` | `{ balance }` | +팩 | Toss confirm API → `confirm_payment_order` | 409 `PM001`(운영 알림 + Toss 취소, 별도 트랜잭션), `PM409`, `PM410`, 404 `PM404` |
| `POST /api/webhooks/toss` | 공개 | Toss 본문 | 200 | 0 | `webhook_events` | 401 서명 실패, 200 중복 |
| `GET /api/account/export` | owner | - | JSON(보관함 복호화 + 리딩 본문 + 결제 내역) | 0 | `write_audit('account.export')`, 일 1회 | 429 |
| `POST /api/account/delete` | owner | `{ confirm: '탈퇴' }` | 204 | 0 | 조직 `deleted_at` 설정(service_role), `write_audit('account.delete')`, 30일 뒤 `purge_organization` | 409 진행 중 리딩 |
| `GET /api/admin/users?q=` | platform_admin | 이메일/UID | 사용자, 잔액, 리딩 수 | 0 | - | 403 |
| `POST /api/admin/credits/grant` | platform_admin | `{ org_id, amount(1..10000), reason(≥5자), request_id }` | 원장 행 | +n | `grant_credits(..., 'admin_grant', 'pack', ..., 'admin:<request_id>')`, 감사 | 403 |
| `POST /api/admin/refunds` | platform_admin | `{ payment_key, amount, reason(≥5자) }` | 결제 | 조정 | Toss 취소 API → `payments` 갱신 → 미사용 크레딧 차감(코어 `adjust_credits` 요청 R-1 전까지는 `consume_credits(reason='refund_adjust')`) → 감사 | 403, 409 사용분 초과 |
| `GET /api/admin/deliveries?status=dead` | platform_admin | - | 목록 | 0 | - | 403 |
| `POST /api/admin/deliveries/[id]/retry` | platform_admin | - | `{ status }` | 0 | 감사 `delivery.retry` | 403 |

## 3. RPC (SECURITY DEFINER)

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `astro.cancel_reading(p_reading_id uuid)` | authenticated | `is_service_caller()` 아니면 `has_org_role(org, owner/admin/member)` + `has_entitlement(org,'astro')`, 상태 queued. 내부에서 `core.cancel_job`(환불), `core.write_audit('reading.cancel')` | `astro.readings` | `P0002`, `42501`, `AS002`, `JB002` |
| `astro.claim_due_deliveries(p_worker_id text, p_limit int)` | service_role | `is_privileged_session()`(EXECUTE가 service_role 전용) | `setof astro.deliveries`(pending → sending, attempts+1, SKIP LOCKED) | `42501` |
| `astro.finish_delivery(p_delivery_id bigint, p_ok boolean, p_error text, p_provider_message_id text, p_retry_after_seconds int default 300)` | service_role | 상태 sending | `astro.deliveries`(sent / pending + 5분 / dead) | `42501`, `P0002`, `AS003` |

코어 RPC 인용: `consume_credits`, `grant_credits`, `refund_credits`(`docs/products/_platform-core/CORE_SPEC.md:152-160`), `confirm_payment_order`(`:210-221`), `enqueue_job` ~ `cancel_job`(`:280-295`), `rate_limit_hit`(`:336`), `write_audit`(`:325`).

## 4. 잡 페이로드 계약

| `job_type` | payload | result | progress 메시지 |
|---|---|---|---|
| `astro.reading.generate` | `{ reading_id: uuid, render_id: uuid, kind, chapter_plan: string[] }` (비밀값·평문 개인정보 없음. 워커가 DB에서 읽고 복호화) | `{ chapters: int, chars: int, pdf_path, pages, llm_usage_ids: int[] }` | `writing:<n>/<total>`(10~70%), `rendering`(80%), `done`(100%) |
| `astro.render.regenerate` | `{ reading_id, render_id, theme_key }` | `{ pdf_path, pages, bytes }` | `rendering`, `done` |
| `astro.storage.purge` | `{ bucket: 'exports', paths: string[] }`(모두 `<org_id>/astro/` 접두사, 워커가 검증) | `{ removed: int }` | - |

장 출력 스키마(zod, `packages/astro-report/schema`):

```ts
// 계약 예시
const Chapter = z.object({
  key: z.enum(['temperament','elements','work','relations','daeun','year','tarot_past','tarot_present','tarot_future','tarot_advice','bridge_1','bridge_2']),
  title: z.string().min(4).max(40),
  body: z.string().min(300).max(2500),   // {{호칭}} 토큰 포함, 수치 문장 금지
  highlights: z.array(z.string().max(60)).min(1).max(3),
})
// 리딩 단위 검증: 사주 본문 합 ≥ 2,500자, 통합 ≥ 4,000자, 타로 ≥ 2,000자, {{호칭}} ≥ 3회, 금지 표현 0
```

렌더 서비스 요청은 공용 계약 `RenderPdfRequest`(`docs/products/_platform-core/SHARED_MODULES.md:265-272`)에 `app_id='astro'`, `preset.page='A4'`, 테마 CSS를 `html` 안 `<style>`로 넣는다. 외부 URL 참조는 없다(폰트는 렌더 컨테이너 로컬).

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태(취소, 부분취소) | 방식 미확인. 확인 전에는 수신 후 `paymentKey`로 Toss 결제 조회 API를 다시 호출해 상태를 재검증(`docs/reviews/Astro_AI.md:53`) | `paymentKey + status + 발생시각` 해시(`docs/products/_platform-core/CORE_SPEC.md:249`) | `payments.status` 동기화만. 크레딧 지급 없음 |
| 수신 | Resend 이벤트(bounce, complaint) | Resend 서명(svix, 미확인) | 이벤트 id | P1. dead 처리와 수신 거부 목록 |
| 발신 | 없음 | - | - | - |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터/비용 |
|---|---|---|---|
| Anthropic / OpenRouter | 워커 `generate.ts`(코어 LLM 게이트웨이) | 폴백 1회 → 장 재생성 1회 → `fail_job` → 자동 환불 | 리딩당 장 4~8회 호출. 원가 추적은 `ai_usage` |
| 렌더 서비스 | 워커 `generate.ts`, `render.ts` | 120초 타임아웃 → `fail_job(retryable=false)` | 내부 |
| Toss Payments | `api/billing/*`, `api/admin/refunds`, 웹훅 재조회 | confirm 실패 → 사용자 안내 + 운영 알림. 타임아웃 → 결제 조회 API로 재확인 후 판단 | - |
| Resend | 워커 `delivery/` | `finish_delivery(false)` → 5분 뒤 재시도, 3회 후 dead | 무료 한도 미확인 |
| KASI 특수천문정보 | `packages/saju-engine/scripts/verify-kasi`(CI 배치만) | 런타임 미사용 | 서비스 키 필요(미확인 한도) |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| `AS001` | 상태 전이 위반 또는 불변 컬럼 변경(트리거) | 409(사용자 경로에서 나오면 버그로 운영 알림) |
| `AS002` | queued가 아닌 리딩 취소 | 409 |
| `AS003` | sending이 아닌 발송 완료 처리 | 409(워커 내부) |
| `CR001` | 크레딧 부족 | 402 + `{ balance, required }` |
| `CR002`, `CR003` | 환불 대상 오류, 환불 초과 | 500 + 운영 알림 |
| `JB002` | 이미 실행 중인 잡 취소 | 409 "이미 만들기 시작해 취소할 수 없습니다" |
| `PM001` | 결제 금액 불일치 | 409 + 운영 알림 + Toss 취소 |
| `PM404` / `PM409` / `PM410` | 주문 없음 / 다른 결제키 / 상태 불가 | 404 / 409 / 409 |
| `42501` | 권한 없음 | 403 |
| `P0002` | 대상 없음 | 404 |
| `22023`, `23514` | 인자·제약 위반 | 400 또는 422 |
| `23505` | 중복(본인 2명 등) | 409 |
| 앱 코드 `RATE_LIMITED` | 레이트 리밋 | 429 |
| 앱 코드 `ENTITLEMENT_REQUIRED` | 앱 미시작 | 402 |
