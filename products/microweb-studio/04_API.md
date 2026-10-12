# 04 API: Microweb Studio

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 스튜디오 라우트는 `requireSession('microweb', {roles})`(`SHARED_MODULES.md` 2장) + `studio_access` 확인. 공개 라우트는 무인증이며 쓰기는 service_role 전용 DB 함수만 부른다 |
| 읽기 | 사용자 세션 클라이언트(RLS). 하객 페이지는 anon 키. service_role은 `src/server/`에서만 |
| 멱등 | 쓰기 요청은 `request_id`(UUID) 헤더 `Idempotency-Key`. 크레딧 `consume:microweb:<request_id>`, 잡 `job:microweb:<request_id>` |
| 크레딧 | 셀프 모드 첫 게시만 라우트에서 선차감. 실패 시 잡 환불 또는 라우트 `refund_credits` |
| 응답 봉투 | `{ ok: true, data }` / `{ ok: false, error: { code, message } }` |
| IP | 원문 저장 금지. `ip_hash = sha256(daily_salt(IP_HASH_SALT_SEED, KST 날짜) + ip)` hex 64자 |
| 레이트 리밋 | 하객/문의 쓰기는 DB 함수 안에서(`1500_microweb.sql:1089`, `:1147`, `:1205`), AI 축하말·업로드는 라우트에서 `core.rate_limit_hit` |
| 공개 쓰기 공통 | 본문 16KB 상한, 허니팟 필드 `website`가 차 있으면 200 `ok`로 응답하고 저장하지 않음, Origin 검사(같은 사이트) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| GET `/i/[slug]`(페이지) | 누구나 | slug | HTML, `noindex`, `s-maxage=30` | 0 | anon select `site_publications` | 404, 410 |
| GET `/api/public/[slug]/bgm` | 누구나 | slug | 302 서명 URL(1시간) | 0 | `is_site_live` | 404 |
| POST `/api/public/[slug]/guestbook` | 누구나 | name(1~20), body(1~500), relation enum?, ai_assisted bool, website(허니팟) | `{id}` | 0 | `submit_guestbook_entry` | 410 closed, 422 invalid/spam, 429 |
| POST `/api/public/[slug]/rsvp` | 누구나 | guest_name, side, attending, party_size 1~10, meal?, message 200? | `{id}` | 0 | `submit_rsvp` | 410, 422, 429 |
| POST `/api/public/[slug]/greeting` | 누구나 | name(1~20), relation enum | `{text}` 200자 | 0(ai_usage 기록) | `is_site_live`, `rate_limit_hit('microweb:greeting:ip:<hash>',5,3600)`, 사이트 30일 300 | 404, 429, 502 |
| POST `/api/public/leads` | 누구나 | name, phone?, email?(하나 필수), kind?, template_code?, tier?, industry?, event_on?, simulator(8KB), message 2000, privacy_consent=true, website | `{id}` | 0 | `create_lead(MICROWEB_STUDIO_ORG_ID, ...)` + 메일 알림 | 422, 429 |
| GET `/p/[token]`(페이지) | 토큰 | token 48 hex | 시안 렌더(서명 URL 이미지) | 0 | service select by `preview_token_hash` | 404 |
| POST `/api/public/preview/[token]/approve` | 토큰 | name 1~40 | `{site_id}` | 0 | `record_customer_approval` | 410 MW013 |
| POST `/api/studio/sites` | owner/admin/member | template_code, title, slug, event_at? | site | 0 | `create_site` | 409 slug, 403, 409 MW005 |
| PATCH `/api/studio/sites/[id]` | 같음 | title?, content?(블록 zod), event_at?, expires_at?, slug?, 토글 3개 | site | 0 | 사용자 세션 UPDATE(RLS, 컬럼 GRANT) | 409 MW002/MW003, 422 |
| POST `/api/studio/sites/[id]/transition` | draft/review: member 이상, unpublished/archived: owner/admin | to, reason? | site | 0 | `transition_site` → unpublished면 `site.unpublish_assets` enqueue | 403, 409 MW001 |
| POST `/api/studio/sites/[id]/consent` | member 이상 | basis | site | 0 | `confirm_disclosure_consent` | 403 |
| POST `/api/studio/sites/[id]/preview-token` | member 이상 | ttl_hours 1~336 | `{url}` 한 번만 | 0 | `issue_preview_token` | 403, 409 |
| POST `/api/studio/sites/[id]/assets/upload-url` | member 이상 | kind, mime, bytes | `{path, signedUrl, token}` | 0 | 서버가 경로 생성 `<org>/microweb/site-photo/<uuid>.<ext>`, rate limit 업로드 60/시간 | 413, 415 |
| POST `/api/studio/sites/[id]/assets/complete` | member 이상 | path | asset | 0 | service INSERT `site_assets` + enqueue `asset.process` | 400 경로 불일치 |
| DELETE `/api/studio/assets/[id]` | member 이상 | - | 204 | 0 | service: Storage 삭제 → 행 삭제 | 403 |
| POST `/api/studio/sites/[id]/publish` | owner/admin | expires_at?, request_id | `{job_id}` 202 | 셀프 첫 게시: 템플릿 `self_publish_credits` | `consume_credits` → `request_publish` → `enqueue_job` | 402, 409 MW001/6/7/8/9, 422 블록 |
| POST `/api/studio/guestbook/[id]/moderate` | member 이상 | status | entry | 0 | `moderate_guestbook_entry` | 403 |
| GET `/api/studio/sites/[id]/rsvp.csv` | owner/admin | - | CSV(UTF-8 BOM) | 0 | RLS select + service audit `rsvp.export` | 403 |
| POST `/api/studio/leads/[id]/status` | member 이상 | to, note? | lead | 0 | `set_lead_status` | 409 MW001 |
| DELETE `/api/studio/leads/[id]` | owner/admin | - | 204 | 0 | `delete_lead` | 403 |
| POST `/api/studio/orders` | owner/admin | customer_name, amount_krw, template_code?, tier?, lead_id?, site_id? | order | 0 | `create_order` | 403, 422 |
| POST `/api/studio/orders/[id]/transition` | owner/admin | to, payment_method?, payment_reference?, note? | order | 0 | `transition_order` | 409 MW001, 422 |
| POST `/api/billing/orders`(Phase 2) | owner/admin, self_service | credit_pack_code | `{orderId, amount, customerKey}` | 0 | service INSERT `core.payment_orders`(금액은 `credit_packs`에서) | 404 |
| POST `/api/billing/confirm`(Phase 2) | owner/admin | paymentKey, orderId, amount | payment | +팩 | Toss confirm → `core.confirm_payment_order` | 4절 |
| POST `/api/webhooks/toss`(Phase 2) | Toss | rawBody | 200 | 0 | `webhook_events` | 401 |
| 관리자(platform_admin, service) | - | studio_access 부여/회수, 템플릿/포트폴리오 편집 | - | 0 | service INSERT/UPDATE + 감사 | 403 |

### Toss confirm 실패 처리

`core.confirm_payment_order`는 금액 불일치(PM001) 때 raise를 올린다(계약 불변, 같은 호출의 주문 UPDATE는 롤백). 주문 `failed` 기록은 service_role 전용 `fail_payment_order`(2026-10-13 코어 반영)를 별도 호출로 부른다.

| 단계 | 동작 |
|---|---|
| 1 | confirm 전에 라우트가 `payment_orders.amount_krw`와 요청 amount를 직접 대조, 다르면 Toss confirm을 호출하지 않고 409 |
| 2 | Toss 승인 뒤 RPC가 PM001/PM409를 내면(PM001이면 먼저 별도 호출로 `fail_payment_order(order_id,'amount_mismatch',{...})`) Toss 결제 취소 API 호출 → service 감사 INSERT `payment.confirm_mismatch`(order_id, 금액) → 운영 알림 |
| 3 | PM001 주문은 `fail_payment_order`로 `failed`가 된다. 그 밖에 `created`로 남은 주문은 `expire_stale_payment_orders`가 1시간 뒤 `expired`로 바꾼다. UI는 라우트 응답으로 실패를 보여 준다 |
| 4 | 코어 수정은 반영 완료(06장 6절) |

## 3. RPC (SECURITY DEFINER)

모든 함수 `set search_path = ''`, 스키마 한정, EXECUTE는 `1500_microweb.sql:1445` 이후에서 정리.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `has_studio_access(org)` | authenticated(정책) | 멤버 + 엔타이틀먼트 + 허용 목록 | boolean | - |
| `is_site_live(site)`, `is_guestbook_public(site)` | anon, authenticated(정책) | 스냅샷 is_live, 만료 전 | boolean | - |
| `create_site(org, template_code, title, slug, event_at)` | authenticated, service | `is_service_caller` 또는 owner/admin/member + 허용 목록, 템플릿 beta/released, 활성 상한 | sites | 42501, MW004, MW005, 23505 |
| `transition_site(site, to, reason)` | authenticated, service | draft/review: member 이상, unpublished/archived: owner/admin | sites | 42501, MW001, P0002 |
| `issue_preview_token(site, ttl_hours)` | authenticated, service | member 이상, publishing/archived 불가 | text(원문 1회) | 42501, MW003 |
| `confirm_disclosure_consent(site, basis)` | authenticated, service | member 이상 | sites | 42501, 22023 |
| `moderate_guestbook_entry(entry, status)` | authenticated, service | member 이상 | guestbook_entries | 42501, 22023 |
| `set_lead_status(lead, to, note)` / `delete_lead(lead)` | authenticated, service | member 이상 / owner/admin | leads / void | 42501, MW001 |
| `create_order(...)`, `transition_order(...)`, `attach_order_site(order, site)` | authenticated, service | owner/admin, 같은 조직의 lead/site | production_orders | 42501, MW001, 22023 |
| `request_publish(site, actor, ledger)` | service_role | actor owner/admin, 허용 목록, 동의, 만료일, 대행: 결제 주문+고객 승인 / 셀프: 미환불·미사용 consume 원장 | sites(publishing) | 42501, MW001, MW006~MW009 |
| `finalize_publish(site, job, content, og...)` | service_role | publishing | site_publications | MW001 |
| `fail_publish(site, error)` | service_role | publishing만 처리 | sites | - |
| `record_customer_approval(token_hash, name)` | service_role | 유효 토큰, draft/review | uuid | MW013, 22023 |
| `submit_guestbook_entry(slug, name, body, relation, ai_assisted, ip_hash)` | service_role | 게시 중, 방명록 켜짐, 리밋, URL/중복 | (entry_id, result) | 결과 코드 |
| `submit_rsvp(slug, ...)` | service_role | 게시 중, RSVP 켜짐, 예식 전, 리밋 | (rsvp_id, result) | 결과 코드 |
| `create_lead(org, ..., consent, ip_hash)` | service_role | 대행 모드 허용 목록, 동의, 리밋, 링크 3개 이상 스팸 | (lead_id, result) | 결과 코드 |
| `expire_sites()` | service_role(스케줄) | - | setof uuid | - |
| `purge_expired_data()` | service_role(스케줄) | - | jsonb 건수 | - |

코어 RPC(`session_context`, `consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `complete_job`, `fail_job`, `confirm_payment_order`, `rate_limit_hit`, `write_audit`)는 `CORE_SPEC.md`를 따른다.

## 4. 잡 페이로드 계약

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `asset.process` | `{ asset_id, org_id, site_id, storage_path, kind }` | `{ width, height, variants: { w400, w800, w1600, og? }, exif_stripped: true }` | "형식 확인" 10, "메타데이터 제거" 40, "크기별 저장" 90 |
| `site.publish` | `{ site_id, org_id, actor_id, request_id }` | `{ version, public_count, og_image_url }` | "사진 복사 n/m", "공개본 생성" 95 |
| `site.unpublish_assets` | `{ site_id, org_id, reason: 'unpublished' \| 'expired' }` | `{ removed }` | - |
| `site.purge` | `{ site_id, org_id }` | `{ removed_files, deleted: true }` | - |

규칙: 페이로드에 비밀값 없음. 워커는 시작할 때 사이트 상태를 다시 읽고 맞지 않으면 재시도 불가 실패. `asset.process`는 매직바이트 검사(jpeg/png/webp/mp3) 실패 시 재시도 불가, `site_assets.status='failed'`.

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 | event_id | 처리 |
|---|---|---|---|---|
| 수신(Phase 2) | Toss 결제 상태 | Toss 방식(미확인, `SHARED_MODULES.md` 6장) | `paymentKey + status + 시각` 해시 | 상태 동기화만, 지급 없음 |
| 발신 | 없음 | - | - | 문의 알림은 메일 |

## 6. 외부 API 어댑터

| 외부 | 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| 카카오 JS SDK(공유, 지도) | 클라이언트, 공식 SRI | 미초기화 시 Web Share → 링크 복사 | 카카오 정책(미확인) |
| LLM 게이트웨이 | `api/public/greeting` | 폴백 1회 → 502와 직접 입력 안내 | 사이트 30일 300 |
| 메일 발송 | `src/server/notify.ts` | 3회 재시도, 실패해도 리드는 저장(대시보드에 표시) | 제공자 한도 |
| Toss(Phase 2) | `api/billing/*` | 2절 결함 회피 | - |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| MW001 | 허용되지 않은 상태 전이 | 409 |
| MW002 | 첫 게시 뒤 slug 변경 | 409 |
| MW003 | publishing/archived 편집 잠금 | 409 |
| MW004 | 사용할 수 없는 템플릿 | 422 |
| MW005 | 활성 사이트 상한 | 409 |
| MW006 | 공개 동의 없음 | 409 |
| MW007 | 만료일 없음/지남 | 422 |
| MW008 | 결제(주문 또는 크레딧) 없음 | 402 |
| MW009 | 고객 승인 없음 | 409 |
| MW013 | 시안 토큰 무효/만료 | 410 |
| 결과 `closed` / `invalid` / `spam` / `rate_limited` | 공개 쓰기 결과 | 410 / 422 / 422 / 429 |
| 23505 | slug 중복 | 409 |
| 코어 코드 | `CORE_SPEC.md` 15장 매핑(42501 → 403, CR001 → 402 등) | - |
