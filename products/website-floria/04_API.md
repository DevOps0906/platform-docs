# 04 API: Floria (website-floria)

작성일 2026-10-12. 코드 블록은 계약 예시다. 수치 중 근거가 없는 것은 제안이다.

## 1. 원칙

| 항목 | 내용 |
|---|---|
| 인증 | 공개 API 3종은 로그인 없음. 콘솔은 `requireSession('site')`(401 미로그인, 403 pending/suspended, 402 대신 403 엔타이틀먼트 없음)(`SHARED_MODULES.md` 2장) |
| 쓰기 경로 | 방문자 쓰기는 Route Handler가 service_role로 `site.*` RPC를 호출한다. 브라우저의 직접 RPC 호출은 설계에서 제외(DB는 방어 2선으로 `submit_inquiry`만 anon에 연다) |
| 크레딧 | 없음 |
| 멱등 | 문의: 클라이언트 `request_id`는 쓰지 않는다. 중복 제출은 이메일당 레이트 리밋이 막는다. 확인/해지는 DB 함수가 멱등이다 |
| 응답 봉투 | 성공 `{ "ok": true, "data": {...} }`, 실패 `{ "ok": false, "error": { "code": "...", "message": "..." } }` |
| 레이트 리밋 | 01_PRD.md 5장 표. Route Handler는 IP 해시 키로 `core.rate_limit_hit` 호출, 초과 시 429+`Retry-After` |
| IP 해시 | `sha256(salt(yyyy-mm-dd, IP_HASH_SALT_SEED) + ip)`의 hex. 원문 IP는 저장·로그하지 않는다 |
| 본문 크기 | 16KB 초과는 413 |
| Origin | `Origin`이 `sites.allowed_origins`(없으면 `NEXT_PUBLIC_SITE_URL`)에 없으면 403. CORS `*` 금지 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/inquiries` | 공개 | `kind` enum 7, `name` 1~80, `email`, `phone?` 정규식, `message` 10~2000, `locale` ko/en, `consent_version` 문자열, `source_path?`, `hp`(허니팟), `elapsed_ms` 정수, `turnstile_token` | `{reference}` 8자리 | 0 | `site.submit_inquiry` | 400 `invalid_input`, 403 `forbidden_origin`/`captcha_failed`, 413, 422 `consent_required`, 429 `rate_limited`, 404 `site_unavailable`, 500 |
| `POST /api/newsletter/subscribe` | 공개 | `email`, `locale`, `consent_version`, `source_path?`, `hp`, `elapsed_ms`, `turnstile_token` | 항상 `202 {}`(구독 여부 비공개) | 0 | `site.subscribe_newsletter` 후 `send_confirmation=true`면 확인 메일 | 400, 403, 422, 429, 500. 이미 확정/허니팟도 202 |
| `POST /api/newsletter/confirm` | 공개(토큰) | `token` | `{status}` | 0 | `site.confirm_newsletter` | 400 `invalid_token`, 410 `expired_token`, 404 |
| `POST /api/newsletter/unsubscribe` | 공개(토큰) | `token`. 원클릭은 `List-Unsubscribe=One-Click` 본문 | `{status}` | 0 | `site.unsubscribe_newsletter` | 400, 404 → 같은 완료 문구 |
| `GET /api/health` | 공개 | - | `{status:"ok", version}` 만(비밀 없음) | 0 | 없음 | - |

`GET`으로 상태를 바꾸는 엔드포인트는 없다. 확인/해지 페이지(`/newsletter/...`)의 GET은 토큰 검증만 하고 버튼을 보인다(메일 보안 스캐너 선열람 대응).

콘솔 변경은 별도 API 없이 서버 액션에서 사용자 세션 클라이언트로 RPC를 호출한다(RLS와 RPC 내부 검사가 권한을 판정). 콘솔 조회는 컬럼 명시 `select`.

### 2.1 토큰 규격

| 항목 | 내용 |
|---|---|
| 형식 | `base64url(JSON payload) + "." + base64url(HMAC-SHA256(key, payload))` |
| payload | `{ "sid": "<subscriber uuid>", "typ": "c" 또는 "u", "exp": <unix 초, 확인은 발급+48h(제안), 해지는 생략> }` |
| 검증 | 상수 시간 비교, `typ` 일치, `exp` 확인. 실패는 400/410 |
| 키 | `SITE_TOKEN_HMAC_KEY` 32바이트 이상, 없으면 기동 실패 |
| 이유 | DB에 토큰을 저장하지 않아도 되고, 토큰이 유출돼도 해당 구독자 1명의 확인/해지만 가능하다 |

## 3. RPC (SECURITY DEFINER)

모든 함수는 `set search_path = ''`. SQL은 `docs/products/_supabase-modular/migrations/2200_site.sql`. 모놀리스는 `public.` 접두사로 같다.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `site.submit_inquiry(p_site_slug, p_kind, p_name, p_email, p_phone, p_message, p_locale, p_consent_version, p_source_path, p_honeypot, p_elapsed_ms) returns jsonb` | anon, authenticated, service_role | 사이트 active+접수 on+엔타이틀먼트, 사이트 홍수 제한, 허니팟, 입력 검증, 동의 버전, 이메일 제한, 일 한도, 스팸 점수 | `{ok, reference}`(허니팟이면 reference null) | SI001, SI002, SI003, SI004 |
| `site.subscribe_newsletter(p_site_slug, p_email, p_locale, p_consent_version, p_source_path, p_honeypot, p_elapsed_ms) returns jsonb` | service_role | `is_service_caller`, 위와 유사, 확인 메일 재발송 최대 5회 | `{ok, subscriber_id, status, send_confirmation}` | 42501, SI001~SI004 |
| `site.confirm_newsletter(p_subscriber_id) returns jsonb` | service_role | `is_service_caller` | `{ok, status, changed}`. pending만 confirmed로 | 42501, P0002 |
| `site.unsubscribe_newsletter(p_subscriber_id) returns jsonb` | service_role | `is_service_caller` | `{ok, status, changed}` | 42501, P0002 |
| `site.set_inquiry_status(p_id, p_to, p_note) returns site.inquiries` | authenticated | 소유 조직의 owner/admin/member, 엔타이틀먼트, 상태값, 메모 1000자, 전이 트리거 | 갱신된 행 | 42501, P0002, 22023 |
| `site.delete_inquiry(p_id) returns void` | authenticated | owner/admin | 없음 | 42501, P0002 |
| `site.erase_subscriber(p_id) returns void` | authenticated | owner/admin | 없음 | 42501, P0002 |
| `site.update_site_settings(p_site_id, p_name, p_notify_email, p_accepts_inquiries, p_accepts_newsletter, p_privacy_policy_version) returns site.sites` | authenticated | owner/admin, 엔타이틀먼트. null 인자는 "변경 없음" | 갱신된 행 | 42501, P0002 |
| `site.provision_site(p_org_id, p_slug, p_name, p_brand_key, p_allowed_origins, p_notify_email) returns site.sites` | service_role | 조직의 `site` 엔타이틀먼트 | 새 행 | 42501, 23505(slug 중복) |
| `site.purge_expired() returns jsonb` | service_role | `is_service_caller` | 삭제·비식별화 건수 | 42501 |

코어 RPC는 인용만 한다: `core.rate_limit_hit`(`CORE_SPEC.md` 12장), `core.write_audit`(11장), `core.session_context`(2.3절).

## 4. 잡 페이로드 계약

해당 없음. `core.jobs`를 쓰지 않는다(02_ARCHITECTURE.md 4장). 알림 워커의 입출력만 적는다.

| 단계 | 내용 |
|---|---|
| 입력 | `select id, site_id, kind, created_at from site.inquiries where notified_at is null and status = 'new' order by created_at limit 50` |
| 알림 대상 | 해당 사이트의 `notify_email`. 비어 있으면 건너뛰고 `notified_at`을 건드리지 않는다 |
| 메일 본문 | 종류, 접수 시각, 콘솔 링크. 이름, 이메일, 내용은 넣지 않는다(제안) |
| 완료 | `update site.inquiries set notified_at = now() where id = any(:ids)` |

## 5. 웹훅

| 구분 | 내용 |
|---|---|
| 수신 | MVP 없음. Phase 2: 메일 사업자의 바운스/스팸 신고 웹훅을 `webhook_events`(서명 검증, `(provider,event_id)` 멱등)로 받아 해당 구독자를 `unsubscribed`로 처리. 사업자 미정(D-6) |
| 발신 | 없음 |

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| CAPTCHA 검증(제안: Cloudflare Turnstile `siteverify`, 스펙 미확인) | `src/lib/forms/captcha.ts` | 검증 서비스 장애 시 폼 제출을 막는다(fail-closed, 스팸 유입 방지). 5초 타임아웃 | 사업자 기준(미확인) |
| 메일 발송(사업자 미정) | `src/lib/mail/`, `worker/notify/` | 확인 메일 실패: subscribe는 202를 유지하고 오류 로그, 사용자는 재신청 가능. 알림 실패: `notified_at` 유지, 다음 주기 재시도 | 미확인 |
| Supabase | `src/lib/supabase/` | RPC 오류는 7장 표로 매핑. 타임아웃 10초(제안) | 플랜 기준 |

## 7. 오류 코드

접두사 `SI`는 `DB_CONVENTIONS.md:22`의 site 제안값이다.

| SQLSTATE | 의미 | HTTP | error.code |
|---|---|---|---|
| SI001 | 레이트 리밋 초과 | 429 + `Retry-After` | `rate_limited` |
| SI002 | 사이트 없음, 중지, 접수 off, 엔타이틀먼트 없음(구분하지 않음) | 404 | `site_unavailable` |
| SI003 | 입력 검증 실패 | 422 | `invalid_input` |
| SI004 | 동의 누락 또는 정책 버전 불일치 | 422 | `consent_required` |
| 42501 | 권한 없음 | 403 | `forbidden` |
| 22023 | 인자 오류, 허용되지 않은 상태 전이 | 409 | `invalid_state` |
| P0002 | 대상 없음 | 404 | `not_found` |
| 23505 | slug 중복 | 409 | `conflict` |
| 그 외 | 예상 못 한 오류 | 500 | `server_error`(내부 메시지 비노출) |

앱 계층 코드: `captcha_failed` 403, `forbidden_origin` 403, `payload_too_large` 413, `invalid_token` 400, `expired_token` 410.
