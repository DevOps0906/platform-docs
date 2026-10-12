# 04 API: NOMAD Commerce

코드 블록은 계약 예시다. 구현 파일이 아니다.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 `/api/*`(웹훅 제외) 첫 줄에서 `requireSession('commerce', { roles })`(SHARED_MODULES 2장). 미로그인 401, pending/suspended 403, `entitled=false` 402 |
| 역할 | 쓰기는 owner/admin/member, 계정·결제는 owner/admin. 역할 비교는 `ctx.org?.role`이 없으면 거부(SECURITY_BASELINE 2장) |
| 플랜 | `core.entitled_plan_code` + `plans.features`(01장 4.4)만. 요청 바디의 plan/model 값은 무시 |
| 멱등 | 클라이언트가 요청마다 UUID `request_id` 전송. 서버 키 `consume:commerce:<request_id>`, `job:commerce:<request_id>`(`CORE_SPEC.md` 4.4) |
| 크레딧 | Route Handler에서 `consume_credits` 선차감 후 저장·잡 등록. 클라이언트가 부르는 별도 차감 API 없음 |
| DB 쓰기 | 사용자 콘텐츠(products, shipping_templates, listing_drafts, banned_words)는 RLS 하 사용자 클라이언트로 가능. 나머지는 `createAdminClient()`(service_role)로만 |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. code는 7절 |
| 레이트 리밋 | `core.rate_limit_hit('commerce:<route>:<org_id>', 60, 60)`. 초과 429 |
| 입력 | zod. 문자열 길이 상한, URL은 `packages/commerce-net` 검사 |
| 타임아웃 | 외부 호출 `AbortSignal.timeout`(LLM 60초, 공급자 15초, 마켓 30초) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/products` | member+ | 상품 콘텐츠 필드 | product | 0 | - | CM002→403 |
| `PATCH /api/products/[id]` | member+ | 부분 필드 | product | 0 | - | 404 |
| `POST /api/products/bulk` | member+ | `{ ids[≤500], action: archive, restore, delete 중 하나 }` | `{ affected }` | 0 | - | CM002 |
| `POST /api/sourcing/amazon` | member+ | `{ request_id, inputs: string[≤20] }`(URL 또는 ASIN) | `{ batch_id, accepted[], rejected[] }` | 건당 1 | consume_credits, enqueue_job | 400 URL, 402 |
| `POST /api/sourcing/excel` | member+ | `{ request_id, storage_path, supplier: ownerclan 또는 custom }` | `{ batch_id }` | 0 | enqueue_job | 400 형식 |
| `POST /api/sourcing/excel/[batch]/mapping` | member+ | `{ column_mapping }` | batch | 0 | enqueue_job | 409 상태 |
| `POST /api/detail-pages` | member+ / `detail_types`, `slot_sets` | `{ request_id, items: [{ product_id, page_type, slot_set, slots?, template, target_markets }] (≤50) }` | `{ detail_page_ids[] }`(waiting) | 9/14 x 개수 | consume_credits(1회, 합계) | 402, 403, 422 슬롯 |
| `POST /api/detail-pages/[id]/cancel` | member+ | - | page | 환불 | refund_credits(waiting) / cancel_job(queued) | 409(generating은 `cancel_requested_at`만) |
| `POST /api/detail-pages/[id]/retry` | member+ | `{ request_id }` | page | 9/14 | consume_credits | 409 상태 |
| `POST /api/detail-pages/[id]/slots/[code]/regenerate` | member+ | `{ request_id, quality: standard 또는 high, prompt_override?(≤500) }` | job | 1 / 3 | consume_credits, enqueue_job | 409 |
| `PATCH /api/detail-pages/[id]/copy` | member+ | `{ copy }` | page(verdict 재계산) | 0(규칙), LLM 재판정 선택 시 1 | - | 422 sanitize |
| `POST /api/detail-pages/[id]/acknowledge` | member+ | `{ note? }` | page | 0 | `commerce.acknowledge_compliance_warning` | CM008, CM009 |
| `POST /api/ai/names` | member+ | `{ request_id, product_id }` | 상품명 3안 + 키워드 | 1 | withCredits | 402 |
| `POST /api/ai/autofill` | member+ | `{ request_id, listing_draft_id, target: category, notice, tags 중 하나 }` | 제안값(저장 안 함) | 1 | withCredits | 402 |
| `POST /api/ai/voice` | member+ / `voice_input` | `{ request_id, storage_path }`(오디오 10MB) | 구조화 텍스트 | 1 | withCredits | 403 |
| `POST /api/ai/benchmark` | member+ / `url_benchmark` | `{ request_id, url }`(허용 도메인) | 분석 요약 | 2 | withCredits | 400 SSRF 차단 |
| `POST /api/ai/vision` | member+ | `{ request_id, storage_paths[≤10] }` | 상품 속성 | 0(생성 단가 포함, 단독 호출 시 1) | withCredits | 402 |
| `POST /api/listings` / `PATCH /api/listings/[id]` | member+ | 폼 필드 | draft + 서버 계산 completeness | 0 | - | 404 |
| `POST /api/uploads` | member+ / `market_api` | `{ request_id, listing_draft_ids[≤50] }` | `{ upload_ids[] }` | 0 | enqueue_job | CM004~CM008 |
| `POST /api/uploads/[id]/retry` | member+ | `{ request_id }` | upload | 0 | enqueue_job | 409 |
| `POST /api/exports` | member+ / excel·zip | `{ request_id, kind, market, detail_page_ids[≤500] }` | export | 0 | enqueue_job | CM007, CM004 |
| `GET /api/exports/[id]/download` | 멤버 | - | 302 서명 URL(7일) | 0 | - | 410 만료 |
| `POST /api/market-accounts` | owner/admin / `market_slots` | `{ market, slot_no, label, vendor_id?, secrets: { access_key, secret_key } 또는 { client_id, client_secret } }` | 계정(마스킹) | 0 | vault put + audit | CM003, CM006, 422 검증 실패 |
| `POST /api/market-accounts/[id]/verify` | owner/admin | - | 결과 | 0 | - | 502 마켓 |
| `DELETE /api/market-accounts/[id]` | owner/admin | - | - | 0 | `revoke_credential` + status disabled | - |
| `POST /api/billing/orders` | owner/admin | `{ kind: subscription 또는 credit_pack, plan_code? , pack_code? }` | `{ orderId, amount, customerKey }` | - | payment_orders INSERT | 409 |
| `POST /api/billing/confirm` | owner/admin | `{ paymentKey, orderId, amount }` | 결과 | - | Toss confirm → `confirm_payment_order` | PM001/PM409/PM410 |
| `POST /api/billing/billing-key` | owner/admin | `{ authKey }` | 카드 요약 | - | billing_keys INSERT(암호문) | 502 |
| `POST /api/billing/subscription` | owner/admin | `{ action: upgrade, downgrade, cancel 중 하나, plan_code? }` | 구독 | - | `apply_subscription_transition` | SB001 |
| `POST /api/webhooks/toss` | 공개 | rawBody | 200 | - | webhook_events | 401 서명 |
| `POST /api/webhooks/fal?token=` | 공개 | rawBody | 200 | - | webhook_events | 401 |

## 3. RPC (SECURITY DEFINER)

| 함수 | 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|---|
| `commerce.acknowledge_compliance_warning` | `(p_detail_page_id uuid, p_note text default null)` | authenticated, service_role | `is_service_caller()` 또는 `has_org_role(owner,admin,member)`, `has_entitlement`, status ready, verdict warn | `commerce.detail_pages` 행, `write_audit('detail_page.compliance_warn_ack')` | P0002, 42501, CM008, CM009 |
| `commerce.commerce_features` | `(p_org_id uuid) returns jsonb` | service_role | - | 플랜 features | - |
| `commerce.commerce_limit` | `(p_org_id uuid, p_key text, p_default int) returns int` | service_role | - | 한도 | - |
| `commerce.commerce_transition_allowed` | `(p_table text, p_from text, p_to text) returns boolean` | authenticated, service_role | immutable | 허용 여부 | - |

코어 RPC(`consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `confirm_payment_order`, `apply_subscription_transition`, `revoke_credential`, `rate_limit_hit`, `session_context`, `bootstrap_app_for_org`)는 `_platform-core/CORE_SPEC.md`를 인용만 한다.

## 4. 잡 페이로드 계약

비밀값은 payload에 넣지 않는다(`credential_id`만). 진행 메시지는 `heartbeat_job(p_progress, p_message)`.

```ts
// detail.generate
type DetailGeneratePayload = { detail_page_id: string; org_id: string; image_quality: 'draft'|'standard'|'pro'|'ultra' }
type DetailGenerateResult  = { status: 'ready'; slots_completed: number; slots_failed: string[]; partial_refund: number; verdict: 'pass'|'warn'|'fail' }
// progress message: `${phase}:${done}/${total}` 예 "images:5/10"

// detail.slot_regenerate
type SlotRegeneratePayload = { detail_page_id: string; slot_code: SlotCode; quality: 'standard'|'high'; prompt_override?: string }

// import.amazon / import.excel
type ImportAmazonPayload = { batch_id: string; asins: Array<{ asin: string; marketplace: 'US'|'JP'|'DE'|'UK'|'CA' }> }
type ImportExcelPayload  = { batch_id: string; storage_path: string; supplier: 'ownerclan'|'custom'; column_mapping?: Record<string, string> }
type ImportResult        = { imported: number; skipped: number; failed: number }

// upload.coupang / upload.smartstore
type UploadPayload = { upload_id: string; market_account_id: string; credential_id: string }
type UploadResult  = { market_product_id: string; status: 'submitted'|'approved' }

// export.excel / export.zip
type ExportPayload = { export_id: string }
type ExportResult  = { storage_path: string; bytes: number; rows?: number }
```

| 잡 | 진행률 규칙 |
|---|---|
| detail.generate | 01장 3.6절 phase 표 |
| import | 처리 행 / 전체 행 |
| upload | validating 20, uploading 60, submitted 100 |
| export | 처리 페이지 / 전체 |

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태(취소, 가상계좌) | 시크릿 검증(방식 미확인, SHARED_MODULES 6장) | paymentKey + status + 시각 해시 | 상태 동기화만. 지급은 confirm 경로 |
| 수신 | fal 이미지 완료 | URL 토큰 `FAL_WEBHOOK_SECRET` 비교 + `request_id`가 `detail_page_slots.provider_request_id`에 있는지 대조 | fal `request_id` | 이미지를 `org-files`로 복사 후 슬롯 갱신. 모르는 request_id는 ignored |
| 발신(Phase 2) | `product.sourced`, `detail_page.created`, `market.uploaded` | HMAC-SHA256(`timestamp.rawBody`), 사용자별 시크릿 | - | automation-core 소유(`Nomad-AI-Factory_V.2/CLAUDE.md:601-633`의 이벤트 이름 재사용) |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 인증 | 실패 처리 | 쿼터/비고 |
|---|---|---|---|---|
| 쿠팡 Wing Open API | 워커 upload | 셀러 Access/Secret 키 HMAC-SHA256 서명 + vendorId | 5xx·429 재시도 3회, 4xx 즉시 실패(필드 오류 매핑) | 등록 후 승인 요청과 승인 결과 조회가 필요한지 미확인. 상태 폴링 10분 |
| 네이버 커머스 API(스마트스토어) | 워커 upload | 셀러 client_id/secret → 전자서명 토큰(방식 미확인) | 같음 | 호출 한도 미확인. 토큰 캐시는 메모리, DB 저장 안 함 |
| 아마존 상품 데이터 공급자 | 워커 import | 플랫폼 키(env) | 없는 ASIN은 행 실패 + 환불 | 건당 과금(미확인) |
| 한국수출입은행 환율 | 워커 크론 | 플랫폼 키 | 실패 시 이전 값 유지 + 경고 | 일 1회 |
| OpenRouter(llm gateway) | 워커, Route Handler | 플랫폼 키 | 폴백 1회 후 환불 | `ai_usage` 기록 |
| fal | 워커 images, voice | 플랫폼 키 | 제출 실패 즉시 환불, 30분 미도착 실패 | safety checker on |
| Toss | Route Handler, 워커 | 시크릿 키 | core 규약 | - |
| video 워커(Phase 2) | Route Handler | 서비스 토큰 | 렌더 실패 환불 | C-6 |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| CM001 | 상태 전이 위반 | 409 |
| CM002 | 상품 수 한도 | 403(업그레이드 안내) |
| CM003 | 마켓 계정 슬롯 한도 | 403 |
| CM004 | compliance FAIL | 422 |
| CM005 | WARN 미확인 | 422 |
| CM006 | 마켓 계정 무효(다른 조직, 비활성, 키 없음, 마켓 불일치) | 409 |
| CM007 | 플랜 미허용 기능 | 403 |
| CM008 | 상세페이지 미완료 | 409 |
| CM009 | 확인할 WARN 없음 | 409 |
| 23514 | CHECK 위반(필수 슬롯, 반품 기간 등) | 422 |
| 23503 | 다른 조직 행 참조(복합 FK) | 404 |
| 코어 | 42501→403, CR001→402, P0002/PM404→404, 22023/SB001/JB002/PM410→409, PM001/PM409→409 + 운영 알림, OA001→400 | `CORE_SPEC.md` 15장 |
