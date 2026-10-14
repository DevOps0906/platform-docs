# 04 API: 로컬뉴스 클라우드(가칭)

작성일 2026-10-15. 신규 기획. 코어 RPC는 `docs/file/03-설계/공용코어/CORE_SPEC.md`(아래 CS), 공용 모듈은 `SHARED_MODULES.md`(아래 SM), 화이트라벨 API는 `Multi-tenant_Theming/03_CODE_STRUCTURE.md` 5장(아래 MT)을 인용만 한다. 코드 블록은 계약 예시다. RPC 이름·인자·SQLSTATE는 `05_DATA_MODEL.md`와 SQL(`2500_news.sql`, 모놀리스 `0003_local_news_domain.sql`)이 정본이며, 이 문서는 DB 설계 요약 v1(2026-10-15)의 함수 목록·역할 묶음·SQLSTATE에 맞췄다. 모듈러 이름(`news.*`)으로 적고 모놀리스에서는 같은 이름이 `public.*`에 있다.

## 1. 원칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| 호스트 경계 | `/api/r/*`는 테넌트 호스트에서만, `/api/newsroom/*`·`/api/ai/*`·`/api/voice/*`·`/api/tenant/*`는 newsroom 호스트에서만, `/api/ops/*`는 ops 호스트에서만 응답한다. 다른 호스트면 404 | 02장 10.1절 |
| 조직 출처 | 독자 API의 조직은 `getTenant()`(Host 해석) 결과만, 편집국 API는 `session_context`의 `org`만 RPC의 `p_org`로 넘긴다. 요청 본문·쿼리의 `org_id`는 받지 않는다(예외: 초대 수락은 초대받은 조직 id를 받고 DB가 본인 초대인지 확인) | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:287`과 같은 원칙 |
| 인증 | 독자 공개 API는 로그인 없음. 독자 로그인 API는 `requireReader()`(세션 + 해석된 신문사의 활성 `news.readers` 행). 편집국은 `requireSession('news')` + `news.staff` 역할(DB `news.assert_staff`가 다시 검사). 운영은 `platform_role='platform_admin'`(아니면 404). 세션은 모든 인증 단계에서 실제 Supabase JWT(8절) | SM 2장, `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 0장 |
| 독자 페이지 데이터 | 독자 페이지는 Route Handler가 아니라 서버 컴포넌트가 anon 키로 `news.read_article`, `news.serve_ads`, `news.most_read`, `news.list_comments`를 불러 ISR로 렌더한다. 프리미엄 본문은 캐시된 페이지에 넣지 않고 `GET /api/r/articles/[slug]/body`(세션, `no-store`)로 받는다 | 02장 10.3절 |
| 순서 | 인증 → zod → Origin 검사(독자 쓰기: `Origin` = 요청 호스트) → 봇 차단 → 레이트 리밋 → features·역할 → 크레딧 선차감(AI만) → RPC → 캐시 태그 무효화 → 실패 시 환불 | CS 4.3 |
| 봇 차단 | 독자 비로그인 쓰기(구독, 제보, 정정 청구, 매직 링크)는 Turnstile + 허니팟 `hp`(비어야 함) + `elapsed_ms` 3,000 이상(제안). 허니팟 걸림은 성공처럼 202, Turnstile 실패는 403 | website-floria 04장 1절과 같은 방식 |
| 레이트 리밋 | Route Handler: `core.rate_limit_hit('news:<route>:<org>:<ip 해시 또는 user>', limit, window)`. DB도 신문사 단위 상한을 다시 건다(`NW011`). 기본값은 01장 5절, 없으면 표의 제안값 | CS 12장 |
| IP 해시 | `sha256(salt(yyyy-mm-dd, RATE_LIMIT_IP_SALT) + ip)`. 원문 IP는 저장·로그하지 않는다 | `SECURITY_BASELINE.md` 12장 |
| 멱등 | 결제·발송·AI·비동기 요청은 `request_id`(UUID v4) 필수. 차감 키 `consume:news:<request_id>`, 잡 키 `job:news:<request_id>` | CS 4.4, SM 18장 |
| DB 접근 | 편집국 쓰기는 사용자 세션으로 `news.*` DEFINER RPC만(`save_article` 등, 직접 INSERT·UPDATE 없음). 읽기는 RLS. 독자 비로그인 쓰기는 Route Handler가 service_role로 RPC 호출 | `SECURITY_BASELINE.md` 4장 |
| 응답 봉투 | 성공 `{ ok: true, data }`, 실패 `{ ok: false, error: { code, message, details? } }`. 402는 `details: { required, balance }` | 제안 |
| 본문 크기 | JSON 64KB(기사 저장은 1MB), 파일은 서명 업로드 URL로만 | 제안 |
| sanitize | 기사 블록 JSON → 서버 렌더 시 허용 목록 HTML. 임베드는 YouTube(`youtube-nocookie.com`)·지도 허용 목록 id만 저장(임의 iframe 금지) | `SECURITY_BASELINE.md` 10장 |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT 발급: `iss=news`, `aud=platform-ai:news`, `org`(세션 또는 잡 행), `app=news`, `sub`, `conv`, `feat`, `scope`, `jti`, `exp`(10분) | `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:33-42` |

역할 약어(`news.staff.role`): P=publisher, E=editor, D=desk, R=reporter, C=contributor, A=ad_manager. "D+"는 P·E·D, "E+"는 P·E. 플랜 열은 `core.plans.features` 키(01장 4절).

## 2. Route Handler

### 2.1 독자 API (테넌트 호스트)

| 메서드 경로 | 역할 | 입력(zod 요약) | 출력 | 크레딧 | 호출 RPC | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/r/view` | 공개(`sendBeacon`) | `{ article_id }` | 항상 204 | 0 | 봇 UA·프리렌더 제외, `rate_limit_hit('news:view:<org>:<ip>:<article>', 1, 1800)` 통과분만 `news.increment_article_views(article, 1, now())`(service) | 없음(실패해도 204) |
| `GET /api/r/articles/[slug]/body` | 공개(세션 있으면 사용) | - | `{ locked, body?, meter: { used, limit } }`(`private, no-store`) | 0 | `news.read_article`(사용자 세션 또는 anon). 미터는 서명 쿠키 카운트(DB 강제 아님, 05장 7절) | 404 |
| `GET /api/r/search` | 공개 | `?q(1..100자)&page≤20` | `{ items: [{ id, title, url, published_at, section }], next }`(s-maxage 60) | 0 | `news.search_articles(org, q, 20, offset)` | 422 `NW015`, 429(30회/분/IP) |
| `GET /api/r/most-read` | 공개 | `?window=1h\|24h&limit≤10` | `{ items }`(s-maxage 60) | 0 | `news.most_read` | - |
| `POST /api/r/newsletter/subscribe` | 공개 | `{ email, list_slug, consent_version, ad_consent?: bool, night_consent?: bool, hp, elapsed_ms, turnstile_token }` | 항상 202(구독 여부 비공개) | 0 | `news.subscribe_newsletter(org, list_slug, email, consent_version, ad_consent, night_consent, reader_user_id?, source_path)`(service). `send_confirmation`이면 반환된 확인 토큰으로 메일(7일) | 403 `captcha_failed`·`forbidden_origin`, 422 `NW015`(동의 누락·광고 동의 필요 목록), 429 `NW011`, 410 `NW002` |
| `POST /api/r/newsletter/confirm` | 공개(토큰) | `{ token }` | `{ status }` | 0 | `news.confirm_newsletter(token)`(DB가 해시 대조) | 400·410 `NW012` |
| `POST /api/r/newsletter/unsubscribe` | 공개(토큰) | `{ token, reason? }` 또는 `List-Unsubscribe=One-Click` 본문 | `{ status }` | 0 | `news.unsubscribe_newsletter(token, reason)` | `NW012` → 같은 완료 문구 |
| `POST /api/r/push/subscriptions` | 공개 | `{ endpoint(https), keys: { p256dh, auth }, topics: ['breaking'] }` | 201 | 0 | `news.register_push_subscription`(service) | 422, 429 |
| `DELETE /api/r/push/subscriptions` | 공개 | `{ endpoint }` | 204 | 0 | `news.revoke_push_subscription`(service) | - |
| `POST /api/r/tips/uploads` | 공개 | `{ file_name, ext(jpg\|png\|pdf\|mp4\|hwp\|docx), bytes ≤ 10MB, turnstile_token }` | `{ upload_id, signed_upload_url }`(10분, `org-files/<org>/news/tips/`) | 0 | - | 413, 415, 429(5회/시간/IP) |
| `POST /api/r/tips` | 공개 또는 독자 | `{ kind, title ≤ 120, body 10..10000, wants_anonymity: bool, contact_name?, contact_phone?, contact_email?, upload_ids ≤ 3, consent_version, hp, elapsed_ms, turnstile_token }` | `{ reference }` | 0 | 첨부 매직바이트 확인 → `news.submit_tip(org, fields, reader_user_id?)`(service) | 403, 413, 422 `NW015`, 429 `NW011`, 410 `NW002` |
| `POST /api/r/corrections` | 공개 또는 독자 | `{ article_id, kind: 'correction'\|'rebuttal'\|'follow_up', requester_name, requester_email\|requester_phone, claim_text 20..5000, requested_text ≤ 2000, consent_version, hp, elapsed_ms, turnstile_token }` | `{ reference, received_at, notify_due_at }` | 0 | `news.submit_correction_request(org, fields)`(service, `channel='web'`). 청구 기한(안 날 3개월·보도 후 6개월) 경과도 접수하고 표시만(판단은 편집국) | 404, 422 `NW015`, 429 `NW011` |
| `POST /api/r/account/join` | 로그인(독자 행 없음) | `{ nickname 2..20, terms_version, privacy_version, is_over_14: true, marketing_opt_in: bool, next? }` | `{ reader, redirect }` | 0 | `news.ensure_reader(org, nickname, terms_version, privacy_version, is_over_14, marketing_opt_in)`(사용자 세션) | 422 `NW015`(만 14세 미만 미지원), 409 `23505`(닉네임 중복), 403 `NW008`(차단), 410 `NW002` |
| `GET /api/r/account`, `PATCH /api/r/account` | 독자 | 수정: `{ nickname?, marketing_opt_in? }` | `{ reader, memberships, subscriptions }`(그 신문사 행만) | 0 | RLS SELECT / `news.ensure_reader`(같은 인자로 갱신) | 422 |
| `POST /api/r/account/leave` | 독자 | `{ confirm: true }` | 204(그 신문사 독자 탈퇴. 플랫폼 계정 삭제는 별도 안내) | 0 | `news.withdraw_reader(org)` | 409 `NW004`(활성 멤버십 먼저 해지) |
| `POST /api/r/comments` | 독자 | `{ article_id, body 2..1000, parent_id? }` | `{ comment }` | 0 | `news.post_comment` → `news.ai_moderation` enqueue | 403 `NW008`, 409 `NW009`(댓글 꺼짐·선거 기간), 422 `NW010`(금칙어), 429 `NW011` |
| `DELETE /api/r/comments/[id]` | 작성 독자 | - | 204 | 0 | `news.delete_my_comment` | 404 |
| `POST /api/r/comments/[id]/report` | 독자 | `{ reason enum, detail ≤ 1000, rights_claim: bool }` | 202 | 0 | `news.report_comment(id, reason, detail, rights_claim)`. 권리침해 주장은 DB가 즉시 `temp_blocked` 30일(정보통신망법 44조의2 임시조치), 신고 5건이면 `hidden` | 403 `NW008`, 422 `NW015`(자기 댓글), 429 `NW011` |
| `POST /api/r/life-events` | 독자 | `{ kind: 'obituary'\|'personnel'\|'people'\|'wedding', title, body ≤ 1500, event_at?, applicant_name, applicant_phone, consent_version }` | `{ life_event }`(유료 옵션은 결제 후 검토) | 0 | `news.submit_life_event(org, fields)` | 403 `NW008`, 429 `NW011`. P1 |
| `GET /api/r/membership/tiers` | 공개 | - | `{ tiers, donation_presets, client_key }`(신문사 Toss 클라이언트 키) | 0 | RLS SELECT | 404 `payments_not_configured` |
| `POST /api/r/membership/checkout` | 독자 | `{ kind: 'membership'\|'donation'\|'listing', tier_id?, amount?(1,000~1,000,000원), recurring: bool, listing_id?, request_id }` | `{ order_id, amount, order_name, customer_key }` | 0 | 서버가 금액을 등급표·업소 플랜에서 계산해 주문 기록(service). 플랫폼 수수료는 `news_reader_fee_bps`로 월 청구에 합산(결제액에서 떼지 않음, D-4·D-5) | 404, 422 |
| `POST /api/r/membership/confirm` | 독자 | `{ payment_key, order_id, amount }` | `{ membership \| donation \| listing }` | 0 | Toss confirm(**신문사 시크릿 키**, vault) → `news.record_membership` / `news.record_donation` / `news.activate_listing`(service) | 422 `NW015`(주문 불일치, Toss 취소 요청), 502 `toss_failed` |
| `POST /api/r/membership/billing-key` | 독자 | `{ auth_key, tier_id, request_id }` | `{ membership }` | 0 | 빌링키 발급(신문사 키, vault 저장) → 첫 청구 → `news.record_membership` | 402 결제 실패 |
| `POST /api/r/membership/cancel` | 독자 | - | `{ membership }`(기간 끝 해지) | 0 | `news.record_membership`(`canceled`) | 409 `NW004` |
| `POST /api/r/listings` | 독자 / 업소 셀프 광고 플랜(Standard 이상) | `{ business_name, category, address, phone, description ≤ 500, image_upload_ids ≤ 3, period_months: 1\|3\|6 }` | `{ listing }`(`pending` → 결제 → 검수) | 0 | `news.submit_listing(org, fields)` | 403 `NW008`·`NW014`, 429 `NW011`. P1 |
| `POST /api/r/ad-event` | 공개(`sendBeacon`) | `{ creative_id, type: 'impression' }` | 204 | 0 | 봇 제외, `rate_limit_hit` 통과분만 `news.record_ad_stats(creative, 오늘, 1, 0)`(service) | 없음 |
| `GET /r/ad/[creative_id]` | 공개 | - | 302 → DB의 `click_url`(https만, 오픈 리디렉트 금지) | 0 | 클릭 `news.record_ad_stats(creative, 오늘, 0, 1)` | 404(종료 캠페인) |
| `GET /api/r/life/weather` | 공개 | `?region=<code>` | `{ temp, sky, pm10_grade, pm25_grade, observed_at, source }`(s-maxage 1800) | 0 | 외부 어댑터(6절) | 503 → 블록 숨김 |

### 2.2 편집국 API (newsroom 호스트)

편집국 API의 크레딧은 모두 0이다(크레딧은 2.4절 AI·음성만).

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 호출 RPC | 오류 |
|---|---|---|---|---|---|
| `POST /api/newsroom/apply` | 로그인(조직 없음) | `{ slug, title, media_kind: 'internet'\|'daily'\|'weekly'\|'monthly'\|'other', registration_no, registration_date, publisher_name, contact_email, contact_phone, certificate_upload_id, message? }` | `{ application }` | `news.request_newspaper(...)` | 409 `NW001`(slug·진행 중 신청), 429 `NW011` |
| `POST /api/newsroom/apply/[id]/withdraw` | 신청자 | - | `{ application }` | `news.withdraw_newspaper_request` | 409 `NW004` |
| `GET/PUT /api/newsroom/profile` | 조회 멤버 / 저장 E+ | 필요적 게재사항(제호, 등록번호, 등록일, 발행인, 편집인, 청소년보호책임자, 발행소·전화, 최초발행일), 댓글 기본값 | `{ profile, complete, missing }` | `news.set_newspaper_profile(org, profile)`, `news.is_profile_complete` → 태그 `news:<org>:profile` | 409 `NW002`, 422 `NW015` |
| `POST /api/newsroom/staff/invites` | E+ / `news_staff_max` | `{ email, role(publisher 제외), byline_name, title_label? }` | `{ staff }` + 초대 메일 | 서버가 이메일로 사용자를 찾고 없으면 `auth.admin.inviteUserByEmail`(redirect `newsroom/auth/confirm?next=/invites`) → `news.invite_staff(org, user_id, role, byline_name, title_label)` | 409 `NW004`(이미 구성원), 403 `NW014`(기자 수 한도), 422 `NW015` |
| `POST /api/newsroom/staff/accept` | 초대받은 본인 | `{ org_id }` | `{ staff }` | `news.accept_staff_invite(org_id)` | 404, 409 |
| `PATCH /api/newsroom/staff/[user_id]`, `DELETE` 같은 경로 | E+ | `{ role }` / - | `{ staff }` | `news.set_staff_role` / `news.remove_staff`. 자기 역할 변경 금지, publisher는 소유권 이전으로만 | 403 `42501`, 422 `NW015` |
| `PATCH /api/newsroom/me` | 구성원 | `{ byline_name?, title_label?, bio? }` | `{ staff }` | `news.update_my_staff_profile` | 422 |
| `POST/PATCH /api/newsroom/taxonomy/[kind]` | D+ | `kind`=sections\|regions\|tags, 이름·slug·순서·색(템플릿 B) | 행 | `news.upsert_taxonomy(org, kind, id?, fields)` | 409 `23505`, 422 `NW015` |
| `POST /api/newsroom/articles`, `PATCH /api/newsroom/articles/[id]` | R+, C(자기 초안) | `{ fields: { title, subtitle, summary, body(블록), type, section_id, byline, region_ids, tag_ids, is_premium, sponsor_label, wire_contract_id, is_poll, poll_disclosure, is_breaking, is_live, comments_enabled, embargo_until, hero_media_id, seo, change_note? } }`(게시 후 수정은 `change_note` 필수) | `{ article }` | `news.save_article(org, id?, fields)`(자동 저장 10초) | 409 `NW004`(상태별 편집 불가), 422 `NW015`, 422 `23514`(광고 라벨·AI 고지·여론조사 표시 CHECK) |
| `POST /api/newsroom/articles/[id]/submit` | 작성자 | - | `{ article }` | `news.submit_article` | 409 `NW004` |
| `POST /api/newsroom/articles/[id]/review` | D+ | `{ decision: 'approve'\|'reject', note? }`(반려는 사유 필수) | `{ article }` | `news.review_article` | 409 `NW004`, 409 `NW006`(사람 편집자 아님), 422 `NW015` |
| `POST /api/newsroom/articles/[id]/publish` | D+ | `{ request_id }` | `{ article, url }` | `news.publish_article` → 태그 무효화 → `news.post_publish` enqueue | 409 `NW002`(신문사 비활성), `NW003`(매체정보 미완성), `NW004`, `NW005`(전재 계약), `NW006`(사람 승인 없음, AI 초안 포함), `NW007`(선거 여론조사 공표 금지) |
| `POST /api/newsroom/articles/[id]/schedule` | D+ | `{ at(90일 이내 미래), request_id }` | `{ article }` | `news.schedule_article(id, at)`(게시는 워커 크론, 02장 4절) | 위 게시 오류 + 422 `NW015` |
| `POST /api/newsroom/articles/[id]/unpublish`, `/archive` | D+(05장 역할 확정 시 맞춤) | `{ reason }` / - | `{ article }` | `news.unpublish_article` / `news.archive_article` → 태그 무효화 | 409 `NW004`, 422 `NW015` |
| `POST /api/newsroom/articles/[id]/corrections` | D+ | `{ kind: 'update'\|'correction'\|'clarification'\|'rebuttal'\|'follow_up', note 5..2000, correction_request_id? }` | `{ article }`(공개 `article_revisions` 행) | `news.record_article_correction` → 태그 무효화 | 409 `NW004`(게시 전·청구 미수용), 422 `NW015`(종류 불일치) |
| `POST /api/newsroom/articles/[id]/preview-link` | 작성자, D+ | - | `{ url, expires_at }`(10분, `noindex`) | - | - |
| `POST /api/newsroom/articles/[id]/live-updates`, `PATCH .../[uid]` | R+ | `{ body ≤ 2000, is_pinned? }` / `{ status, is_pinned? }` | `{ update }` | `news.add_live_update` / `news.set_live_update_status` → 태그 무효화 | 409 `NW004`(라이브 아님). P1 |
| `PUT /api/newsroom/home-layouts/[id?]`, `POST .../[id]/publish` | E+, D | `{ template: 'traditional'\|'magazine'\|'feed'(A/B/C), blocks: [{ key, enabled, order, config }], top_article_id?, sub_article_ids ≤ 6 }` / `{ at? }` | `{ layout }` | `news.save_home_layout` / `news.publish_home_layout(id, at)` → `news:<org>:home` | 409 `NW004`, 422 `NW015` |
| `POST /api/newsroom/media/upload-url`, `POST .../[id]/complete` | R+, C / `news_storage_gb` | `{ file_name, ext, bytes ≤ 20MB, credit, license, alt_text, caption? }` | `{ media_id, signed_upload_url }` / `{ media, job_id }` | `news.save_media_asset` → 매직바이트 확인 → `news.media_derive` | 413, 415, 403 `NW014` |
| `POST /api/newsroom/print-editions` | E+ / `news_print_pdf` | `{ edition_date, pdf_upload_id, pages }` | `{ edition }` | `news.save_print_edition` | 403 `NW014`. P1 |
| `GET /api/newsroom/readers`, `POST .../[id]/status` | E+ | `?q&status` / `{ status: 'active'\|'blocked', reason }` | 마스킹 목록 / `{ reader }` | RLS SELECT / `news.set_reader_status` | 422 `NW015` |
| `POST /api/newsroom/readers/export` | P | `{ request_id, reason ≥ 10자 }` | `{ job_id }` | `news.export`(kind readers) + 감사 `reader.export` | 429(1회/일) |
| `GET/PUT /api/newsroom/membership/(tiers\|paywall)` | E+ | 등급·가격·혜택 / 미터 모드·월 무료 건수 | 행 | `news.upsert_membership_tier`, `news.set_paywall_rule` | 422 `NW015`. P1 |
| `PUT /api/newsroom/newsletter/lists/[id?]`, `PUT .../issues/[id?]` | E+ / D+ | 목록: 이름·slug·광고 포함 여부. 호: `{ list_id, subject ≤ 100, blocks \| auto_briefing, contains_ad, scheduled_at? }`(광고 포함이면 제목 "(광고)" 강제) | 행 | `news.upsert_newsletter_list`, `news.save_newsletter_issue` | 422 `NW015` |
| `POST /api/newsroom/newsletter/issues/[id]/send` | E+ / `news_newsletter_monthly` | `{ request_id }` | `{ job_id, recipients }` | 월 한도·야간(21~08시는 야간 동의자만) 검사 → `news.newsletter_send` | 403 `plan_limit`, 409 `night_consent_none` |
| `POST /api/newsroom/push/breaking` | D+ | `{ article_id, title ≤ 60 }` | `{ job_id }` | `news.push_send` | 429(10회/시간), 409 미게시 기사 |
| `PUT /api/newsroom/ads/(slots\|advertisers\|campaigns\|creatives)/[id?]` | A, E+ | 슬롯: IAB 규격·위치. 캠페인: 광고주, 슬롯, 기간, 우선순위, 하우스 여부. 소재: 이미지·`click_url`(https)·`alt_text`·라벨 | 행 | `news.upsert_ad_slot`, `news.upsert_advertiser`, `news.save_ad_campaign`, `news.save_ad_creative` | 409 `NW013`(정부·지자체 광고 직판), 422 `NW015` |
| `POST /api/newsroom/ads/creatives/[id]/review`, `GET /api/newsroom/ads/stats` | E+ / A, E+ | `{ decision: 'approve'\|'reject'\|'archive' }` / `?from&to&campaign_id` | 행 / 일별 노출·클릭 | `news.review_ad_creative` / RLS SELECT | 422 |
| `POST /api/newsroom/(listings\|life-events)/[id]/review` | A·E+ / D+ | 업소 `{ decision: 'approve'\|'reject'\|'cancel'\|'expire', note? }`, 경조사 `{ decision: 'approve'\|'reject'\|'archive', note? }` | 행 | `news.review_listing` / `news.review_life_event` | 422 `NW015`. P1 |
| `PUT /api/newsroom/notices/[id?]`, `GET .../[id]/proof` | A, E+, D | `{ agency, title, body, starts_at, ends_at, status }` / - | 행 / 게재 증빙 CSV·PDF | `news.save_public_notice` | P1 |
| `GET /api/newsroom/tips`, `GET .../[id]`, `PATCH .../[id]` | P·E·D·R(배정) | `{ status: 'reviewing'\|'assigned'\|'used'\|'dismissed'\|'spam', assigned_to?, note? }` | 목록 / 상세(첨부 10분 서명 URL, 감사 `tip.view`) / 행 | RLS SELECT / `news.set_tip_status` | 422 `NW015`(편집국 아닌 배정) |
| `GET /api/newsroom/comments`, `POST .../[id]/moderate` | D+ | `?status=reported\|hidden\|temp_blocked` / `{ action: 'show'\|'hide'\|'temp_block'\|'delete', reason }` | 목록 / 행 | RLS SELECT / `news.moderate_comment` → 태그 무효화 | 422 `NW015` |
| `POST /api/newsroom/corrections` | D+ | 전화·우편 접수분 수기 입력(`channel`, `received_at` 90일 이내) | `{ reference }` | `news.submit_correction_request(org, fields)`(사용자 세션) | 422 `NW015` |
| `GET /api/newsroom/corrections`, `POST .../[id]/respond` | E+ | `?status&due=soon` / `{ decision: 'reviewing'\|'accept'\|'reject'\|'withdrawn', note }`(거부는 사유 필수) | 목록 / 행. 게재는 `/articles/[id]/corrections`에 `correction_request_id`로 | `news.respond_correction_request` | 409 `NW004`, 422 `NW015` |
| `GET /api/newsroom/compliance/weekly` | D+ | `?week_start(월요일)` | `{ total_published, original_count, press_release_count, ai_press_release_count, wire_count, contribution_count, sponsored_count, original_ratio, flags }` | `news.compliance_weekly_stats(org, week_start)`(주별로 반복 호출해 12주 그래프) | 422 `NW015` |
| `PUT /api/newsroom/(elections\|wire-contracts\|events\|syndication)/[id?]` | E+(행사는 R+) | 05장 허용 키 | 행 | `news.upsert_election_period`, `news.upsert_wire_contract`, `news.save_event`, `news.set_syndication_settings` | 422 `NW015`. P1 |
| `GET /api/newsroom/stats/dashboard`, `GET .../report` | 멤버 / E+·`news_support_reports` | `?date` / `?month` | 대시보드 / `{ job_id }` | RLS SELECT / `news.support_report` | 403. 리포트 P1 |
| `PUT /api/newsroom/settings/payments` | P | `{ toss_client_key, toss_secret_key }` | `{ client_key, secret_masked, verified_at }` | Toss 키 검증 호출 → `CredentialVault.put('toss_merchant')` + 감사 | 422 `toss_key_invalid` |
| `POST/DELETE /api/newsroom/webhook-endpoints` | E+ / `news_api` | `{ url https, events[] }` | `{ endpoint, secret }`(비밀은 이번 응답만) | vault put | 422 `url_not_allowed`, 409 5개 초과 |
| `POST /api/newsroom/import`, `GET .../[job_id]/report` | P, E | `{ source: 'rss'\|'csv'\|'xml'\|'sitemap', url? \| upload_id?, mapping, dry_run, request_id }` | `{ job_id }` / `{ imported, failed, redirects, broken_links }` | `news.import_run` | 403 `plan_limit`, 422 `url_not_allowed`. P1 |
| `POST /api/newsroom/export` | P | `{ request_id }` | `{ job_id }` | `news.export`(kind all) + 감사 | 429(1회/일) |
| `/api/newsroom/billing/*` | P | flora 04장 2절 결제 행과 같은 계약(플랫폼 가맹) | | 코어 toss | 코어 코드 |
| `/api/tenant/*` | 브랜딩 E+(owner·admin), 도메인 P·E / `news_custom_domains` | MT 5장 계약 그대로 | | `publish_tenant_theme`, `request_tenant_domain` 등 | `TM001`~`TM005`, 403 `plan_limit`(news 한도를 MT 상한보다 먼저) |

### 2.3 운영 API (ops 호스트, `platform_admin`, 조회마다 감사 `admin.view`)

| 메서드 경로 | 입력 | 출력 | 호출 RPC | 오류 |
|---|---|---|---|---|
| `GET /api/ops/applications` | `?status&cursor` | 신청 목록(등록증 10분 서명 URL) | service SELECT | - |
| `POST /api/ops/applications/[id]/approve` | `{ plan_code(기본 news_trial), note? }` | `{ org_id }` | `news.approve_newspaper(id, plan_code, note)`(service: 조직·owner·`staff(publisher)`·엔타이틀먼트 30일) | 409 `NW001`(slug), `NW004` |
| `POST /api/ops/applications/[id]/reject` | `{ note ≥ 10자 }` | `{ application }` | `news.reject_newspaper` | 409 `NW004`, 422 `NW015` |
| `POST /api/ops/newspapers/[org_id]/status` | `{ status: 'active'\|'suspended'\|'closed', reason }` | 신문사 | `news.set_newspaper_status`(service) + 캐시 `tenant:<org>` 무효화 | 409 `22023` |
| `GET /api/ops/(newspapers\|domains\|jobs)` | `?status` | 목록(본문 없음) | service SELECT | - |
| `POST /api/ops/credits/adjust` | `{ org_id, amount, reason ≥ 10자 }` | `{ ledger }` | 코어 `grant_credits` + 감사 | - |

### 2.4 AI·음성 Route Handler (newsroom 호스트)

서명 토큰 scope와 호출 대상은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158`, `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:22-48`을 따른다. 크레딧 단가는 01장 4절이 정본이다.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | P(owner) | `{ granted, notice_version }` | 204 | 0 | 사용자 세션 `set_ai_cross_border_ack` + 감사 | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/ai/press-draft` | R+, C | `{ request_id, source_text 200..30000 \| upload_id, section_hint? }` | `{ job_id }` → 완료 시 `{ article_id }`(draft, `press_release`, `origin='ai_press_release'`) | `news.draft` 단가 선차감 | 잡 `news.ai_press_draft` → 잡 토큰 `graph:news.press_to_draft` | 402 `CR001`, 413, 429(10회/시간/사용자) |
| `POST /api/ai/assist` | R+, C | `{ request_id, mode: 'headline'\|'summary'\|'proofread'\|'alt_text', article_id?, media_id?, text? ≤ 20000 }` | `{ suggestions }`(저장 안 함) | 모드별 단가, 실패 환불 | `POST /graphs/news.assist/runs`(scope `graph:news.assist`, 02장 5.2절 변경 제안) | 402, 503 `AI_UNAVAILABLE`(환불) |
| `POST /api/ai/conversations` | 멤버 / `ai_chat` | `{ channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | `ai_conversations` INSERT(service, `dify_user`=HMAC(org:user)) | 403 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message 1..2000 }` | SSE `delta`, `citations`, `fallback`, `usage`, `done` / `error` | 턴 선차감, 정산 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`). 장애 시 `/tools/answer-direct`(scope `chat rag wiki`, `feat=news.assistant`) | 402, 404, 409 `AI_CONVERSATION_CLOSED`, 429, 503(환불) |
| `POST .../conversations/[id]/close`, `DELETE .../conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제(구현 시 확인) | 404 |
| `POST /api/voice/consent`, `POST /api/voice/sessions` | 로그인 / 멤버 | `{ notice_version }` / `{ article_id? }` | 204 / `{ session_id }` | 0 | 감사 `voice.notice_ack` / `voice_sessions` INSERT | 409, 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4) ≤ 5MB, segment_seconds ≤ 120, session_id, request_id }` | `{ text, duration_seconds }`(원본 미저장) | 분당 단가 선차감·정산 | `resolve_ai_route(org,'news','news.stt','stt')` → 오픈소스 강제(scope `voice`) | 413 `VOICE_TOO_LONG`, 402, 503 `AI_OPEN_SOURCE_UNAVAILABLE`(환불, 상용 대체 없음) |
| `POST /api/voice/tts-article`, `GET .../[article_id]` | D+ / 멤버 | `{ article_id, request_id }`(게시 기사 본문만, 임의 텍스트 금지) / - | `{ job_id }` / `{ url, provider }` | 글자 수 단가 선차감 | 잡 `news.ai_tts`(대체 금지) | 409 미게시, 413 `TTS_TOO_LONG`(20,000자 초과, 제안), 402 |

### 2.5 내부 경로 (키 필수)

| 메서드 경로 | 호출자 | 입력 | 동작 | 오류 |
|---|---|---|---|---|
| `POST /api/internal/revalidate` | 워커(`X-Signature` = HMAC(`REVALIDATE_SECRET`, `ts.body`), 5분) | `{ tags: string[] ≤ 50, ts }` | 태그 무효화(형식 `news:<uuid>:...`·`tenant:`·`host:` 정규식만) | 401, 422 |
| `POST /api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | 잡 행(`running`, `app_id='news'`)으로 잡 토큰: `news.ai_press_draft` → `graph:news.press_to_draft`, `news.ai_tts` → `voice` | 401 `INTERNAL_KEY_INVALID`, 409 |
| `POST /api/internal/ai-settle` | 워커(5분) | - | 미정산 `ai_usage` 정산·환불 | 401 |

## 3. RPC (SECURITY DEFINER)

모두 `set search_path = ''`, `revoke execute ... from public, anon` 후 표의 호출자에게만 GRANT, 호출자 판정은 `is_service_caller()`, 역할 검사는 `news.assert_staff`. 코어 RPC(`session_context`, `consume/refund/grant_credits`, `enqueue_job` 등)는 CS 그대로. 독자 함수는 `core.write_audit`를 부르지 않는다(독자는 조직 멤버가 아니므로 행의 시각 컬럼이 기록). 시그니처는 DB 설계 요약 v1 기준이다. 역할 묶음: DESK=D+, CHIEF=E+, ADS=P·E·A, EDITORIAL=P·E·D·R.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `news.request_newspaper(p_slug, p_title, p_media_kind, p_registration_no, p_registration_date, p_publisher_name, p_contact_email, p_contact_phone, p_certificate_path, p_message)` / `news.withdraw_newspaper_request(p_application_id)` | authenticated | 진행 중 신청 1건, slug 사용 가능, 등록증 경로가 본인 폴더, 레이트 리밋 | `newspaper_applications` | `NW001`, `NW004`, `NW011` |
| `news.approve_newspaper(p_application_id, p_plan_code default 'news_trial', p_note)` / `news.reject_newspaper(p_application_id, p_note)` | service_role | `pending`만. 승인: 회사 조직·owner·`staff(publisher)`·엔타이틀먼트(30일 만료). 거부 사유 필수. 감사 | 조직 id / 신청 행 | `NW001`, `NW004`, `NW015` |
| `news.set_newspaper_profile(p_org, p_profile jsonb)` / `news.set_newspaper_status(p_org, p_status, p_reason)` | authenticated(E+) / service_role | 허용 키, 종료 신문사 거부 / 상태 전이 | `newspapers` | `NW002`, `NW015`, `22023` |
| `news.is_profile_complete(p_org)`, `news.is_public_newspaper(p_org)` | anon, authenticated | 공개 가능 값만 | boolean | - |
| `news.invite_staff(p_org, p_user_id, p_role, p_byline_name, p_title_label)` / `news.accept_staff_invite(p_org)` | authenticated | E+, publisher 초대 금지, 이미 구성원, `news_staff_max` / 본인 `invited` 행 | `staff` | `NW004`, `NW014`, `NW015` |
| `news.set_staff_role(p_org, p_user_id, p_role)` / `news.remove_staff(p_org, p_user_id)` / `news.update_my_staff_profile(p_org, p_fields)` | authenticated | E+, 자기 역할 변경 금지, publisher는 소유권 이전으로만 / 본인만 | `staff` | `42501`, `NW015` |
| `news.upsert_taxonomy(p_org, p_kind, p_id, p_fields)` | authenticated | D+, 종류·허용 키 | 행 | `NW015`, `23505` |
| `news.save_article(p_org, p_article_id, p_fields)` | authenticated | 작성자·D+, 상태별 편집 가능 범위(기자는 초안만), 활성 기자, 게시 후 `change_note` | `articles` | `NW004`, `NW015`, `23514` |
| `news.submit_article(p_article_id)` / `news.review_article(p_article_id, p_decision, p_note)` | authenticated | 전이, 승인은 사람 편집자(D+), 반려 사유 | `articles` | `NW004`, `NW006`, `NW015` |
| `news.publish_article(p_article_id)` / `news.schedule_article(p_article_id, p_at)` | authenticated(D+), service_role | `news.assert_publishable`: 신문사 활성(`NW002`), 매체정보(`NW003`), 사람 승인(`NW006`), 전재 계약(`NW005`), 선거 공표 금지(`NW007`), 상태(`NW004`). 예약은 90일 이내 | `articles` | 왼쪽 + `NW015` |
| `news.unpublish_article(p_article_id, p_reason)` / `news.archive_article(p_article_id)` | authenticated | 전이, 사유 필수, 감사 | `articles` | `NW004`, `NW015` |
| `news.record_article_correction(p_article_id, p_kind, p_note, p_correction_request_id)` | authenticated(D+) | 게시 기사, 공개 사유, 청구가 `accepted`이고 종류 일치 | `articles` | `NW004`, `NW015` |
| `news.run_scheduled_publishing()` | service_role(워커 크론 1분) | `scheduled_for <= now()` 기사와 예약 홈을 게시(`skip locked`), 실패 기사는 `approved`로 되돌리고 `review_note`에 사유 | `{ published, failed, layouts }` | `42501` |
| `news.save_media_asset`, `news.save_home_layout`, `news.publish_home_layout(p_layout_id, p_at)`, `news.save_print_edition`, `news.add_live_update(p_article_id, p_body, p_is_pinned)`, `news.set_live_update_status` | authenticated | 역할, 상태, 지면 PDF 플랜 | 행 | `NW004`, `NW014`, `NW015` |
| `news.ensure_reader(p_org, p_nickname, p_terms_version, p_privacy_version, p_is_over_14, p_marketing_opt_in)` / `news.withdraw_reader(p_org)` | authenticated | 공개 신문사, 차단 거부, 만 14세 미만 거부 / 활성 멤버십이면 거부 | `readers` | `NW002`, `NW008`, `NW015`, `NW004` |
| `news.set_reader_status(p_reader_id, p_status, p_reason)` | authenticated(E+) | 상태 값 | `readers` | `NW015` |
| `news.read_article(p_org, p_slug)` | anon, authenticated | 공개 조건(`article_is_live`), 프리미엄 본문은 유효 멤버·편집국만 | jsonb(`locked`) | - |
| `news.upsert_membership_tier`, `news.set_paywall_rule` | authenticated(E+) | 허용 키 | 행 | `NW015` |
| `news.record_membership(p_org, p_reader_id, p_tier_id, p_status, ...)` / `news.record_donation(p_org, p_order_id, p_status, p_amount_krw, p_fields)` | service_role | 주문·금액 일치, 수수료 계산, 전이 | 행 | `NW015`, `22023` |
| `news.upsert_ad_slot`, `news.upsert_advertiser`, `news.save_ad_campaign`, `news.save_ad_creative`, `news.review_ad_creative(p_id, p_decision)` | authenticated(A·E+) | 규격, 라벨, 정부광고 직판 금지 | 행 | `NW013`, `NW015` |
| `news.serve_ads(p_org, p_placement)` / `news.record_ad_stats(p_creative_id, p_day, p_impressions, p_clicks)` | anon, authenticated / service_role | 승인 소재·진행 캠페인·활성 슬롯 / 음수 금지 | table / 행 | `NW015` |
| `news.submit_listing(p_org, p_fields)` / `news.review_listing` / `news.activate_listing(p_id, p_starts_at, p_ends_at, p_payment_order_id)` / `news.save_public_notice` | authenticated(독자) / authenticated(A·E+) / service_role / authenticated | 독자 등록, 레이트 리밋 / 결정 값 / 결제 확인 후 | 행 | `NW008`, `NW011`, `NW015` |
| `news.upsert_newsletter_list`, `news.save_newsletter_issue` / `news.record_newsletter_issue_status` | authenticated / service_role | 허용 키, 과거 예약 금지 / 발송 집계 | 행 | `NW015` |
| `news.subscribe_newsletter(p_org, p_list_slug, p_email, p_consent_version, p_ad_consent, p_night_consent, p_reader_user_id, p_source_path)` / `news.issue_newsletter_reconfirm(p_subscription_id)` | service_role | 공개 신문사, 이메일 형식, 동의 버전, 광고 목록은 광고 동의, 재발송 5회 상한, 레이트 리밋 | `{ subscription_id, status, send_confirmation, confirm_token?, unsubscribe_token? }`(토큰은 해시만 저장) | `NW002`, `NW011`, `NW015` |
| `news.confirm_newsletter(p_token)` / `news.unsubscribe_newsletter(p_token, p_reason)` | anon, authenticated | 토큰 해시 대조, 만료 7일. 2년 재확인도 같은 확인 함수 | jsonb(`status`, `reconfirm_due_at`) | `NW012` |
| `news.register_push_subscription(p_org, p_endpoint, p_p256dh, p_auth, p_topics, p_reader_user_id)` / `news.revoke_push_subscription(p_org, p_endpoint)` | service_role | https 엔드포인트 | id / void | `NW015` |
| `news.post_comment(p_article_id, p_body, p_parent_id)` / `news.delete_my_comment(p_comment_id)` | authenticated(독자) | 활성 독자, 댓글 켬·선거 정책, 금칙어, 레이트 리밋 / 본인 | `comments` | `NW008`, `NW009`, `NW010`, `NW011`, `NW015` |
| `news.report_comment(p_comment_id, p_reason, p_detail, p_rights_claim)` / `news.moderate_comment(p_comment_id, p_action, p_reason)` / `news.list_comments(p_article_id, p_limit, p_before)` | authenticated(독자) / authenticated(D+) / anon, authenticated | 자기 댓글 신고 금지, 권리침해 주장 즉시 임시조치 30일, 신고 5건 `hidden` / `show`·`hide`·`temp_block`·`delete` / 공개 댓글만(닉네임) | 행 / table | `NW008`, `NW011`, `NW015` |
| `news.submit_tip(p_org, p_fields, p_reader_user_id)` / `news.set_tip_status(p_id, p_status, p_assigned_to, p_note)` | service_role / authenticated(P·E·D·R) | 공개 신문사, 허용 키, 레이트 리밋 / 배정 대상이 편집국 | jsonb(`reference`) / 행 | `NW002`, `NW011`, `NW015` |
| `news.submit_life_event(p_org, p_fields)` / `news.review_life_event` | authenticated(독자) / authenticated(D+) | 독자 등록, 레이트 리밋 / 결정 값 | 행 | `NW008`, `NW011`, `NW015` |
| `news.submit_correction_request(p_org, p_fields)` / `news.respond_correction_request(p_id, p_decision, p_note)` | service_role(웹 접수)·authenticated(D+ 수기) / authenticated(P·E) | 허용 키, `received_at` 90일 이내, 레이트 리밋 / `reviewing`·`accept`(7일 게재 기한 시작)·`reject`(사유)·`withdrawn` | jsonb(`reference`, `notify_due_at`) / 행 | `NW004`, `NW011`, `NW015` |
| `news.compliance_weekly_stats(p_org, p_week_start)` | authenticated(D+, 운영자), service_role | 월요일 시작 주, 계산 정본 1곳 | jsonb(유형별 건수, `original_ratio`, `flags`) | `NW015` |
| `news.upsert_wire_contract`, `news.set_syndication_settings`, `news.upsert_election_period`, `news.save_event` | authenticated(E+) | 허용 키 | 행 | `NW015` |
| `news.increment_article_views(p_article_id, p_count, p_at)` / `news.most_read(p_org, p_window, p_limit)` / `news.search_articles(p_org, p_query, p_limit, p_offset)` | service_role / anon, authenticated / anon, authenticated | 게시 기사, 수량 1..1000·48시간 이내 / `1h`·`24h` / 질의 1..100자 | boolean / table(article_id, slug, title, views) / table(article_id, slug, title, summary, published_at, rank) | `NW015` |

사용자용 RPC 안에서 크레딧을 차감하지 않는다(`docs/file/03-설계/공용코어/DB_CONVENTIONS.md` 11장). 상태를 바꾼 RPC를 부른 Route Handler가 같은 요청 안에서 캐시 태그를 무효화한다(02장 10.3절). 브리프 8절 이름과 DB 설계의 차이: 독자 결제는 `record_membership`·`record_donation`, 독자 탈퇴는 `withdraw_reader`, 개설 거부는 `reject_newspaper`로 분리됐다.

## 4. 잡 페이로드 계약

공통: 비밀값·개인정보 원문을 넣지 않는다(id만). 경로는 서버가 만든 Storage 경로만. `progress`는 0~100, `progress_message`는 한국어 한 줄.

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `news.scheduled_publish` | `{ tick_at }`(워커 크론 1분) | `{ published, failed, layouts, revalidated_tags }`. `run_scheduled_publishing` 반환에 id가 없으므로 워커가 `published_at >= tick_at` 기사·홈을 조회해 `news.post_publish`를 enqueue(05장에 id 반환 요청) | - |
| `news.post_publish` | `{ article_id, version, event: 'published'\|'updated'\|'unpublished'\|'corrected', breaking: bool }` | `{ tags, verified: bool, push_job_id?, webhook_events }` | - |
| `news.webhook_deliver` | `{ endpoint_id, event_id, event_type, data }` | `{ http_status, attempts }` | - |
| `news.newsletter_send` | `{ issue_id }` | `{ batches, recipients, skipped_no_consent }` | "1,200/5,000명 발송" |
| `news.newsletter_batch` | `{ issue_id, subscription_ids: uuid[](≤500) }` | `{ sent, failed, suppressed }` | - |
| `news.push_send` | `{ article_id, title, topic: 'breaking' }` | `{ sent, gone_revoked }` | - |
| `news.reconsent` | `{ before: date }` | `{ mailed, unsubscribed }`(`issue_newsletter_reconfirm`) | - |
| `news.import_run` / `news.import_batch` | `{ source, url?, upload_path?, mapping, dry_run }` / `{ run_job_id, items: [{ legacy_url, legacy_id }] }` | `{ total, batches }` / `{ imported, failed: [{ legacy_url, code }] }` | "300/1,200건 가져옴" |
| `news.media_fetch` / `news.media_derive` | `{ media_id, source_url? }` / `{ media_id }` | `{ variants: [{ width, path }] }` | - |
| `news.export` | `{ kind: 'all'\|'readers', reason? }` | `{ storage_path, bytes, expires_at }` | "기사 내보내는 중" |
| `news.ai_press_draft` | `{ source_path, section_hint?, requested_by }`(원문은 Storage에 두고 경로만) | `{ article_id, ai_run_id, flags: [{ kind: 'unverified_fact', text }] }` | "사실 정리 중" → "초안 쓰는 중" → "표기 점검 중" |
| `news.ai_tts` | `{ article_id, version, voice_key }` | `{ storage_path, characters, provider }` | "음성 만드는 중 3/8" |
| `news.ai_index`(FastAPI) | `{ collection: 'news-archive'\|'news-policy', article_id?, document_id?, op: 'upsert'\|'delete' }` | `{ chunks }` | - |
| `news.ai_moderation`(FastAPI) | `{ comment_id }` | `{ score, labels, action: 'none'\|'hide' }`(`hide`면 워커가 service로 `moderate_comment`) | - |
| `news.stats_rollup` / `news.compliance_weekly` / `news.correction_sla` | `{ since }` / `{ week_start }` / `{}` | `{ rows }` / `{ orgs, warnings }` / `{ notify_soon, publish_soon, overdue }` | - |
| `news.membership_renew` / `news.support_report` | `{ date }` / `{ month }` | `{ charged, failed, expired }` / `{ storage_path }` | - / "리포트 조판 중" |
| `news.domain_verify` / `news.domain_auth_redirect` | `{ domain_id }` / `{ domain_id, op: 'add'\|'remove' }` | `{ status }` / `{ registered: bool }` | - |

그래프 실행 계약(워커 ↔ FastAPI, 잡 토큰):

```
// POST /graphs/news.press_to_draft/runs   (Authorization: Bearer <잡 토큰, scope graph:news.press_to_draft>)
{ "source_path": "<org>/news/ai/press/<uuid>.txt", "section_hint": "society", "style_wiki": "newsroom/style" }
// 202 { "run_id": "uuid", "status": "queued" }
// GET /graphs/runs/{run_id} 완료 시
{ "status": "succeeded",
  "output": { "title_candidates": ["...", "...", "..."], "lead": "...", "blocks": [ { "type": "paragraph", "text": "..." } ],
              "facts": [ { "kind": "number", "value": "3억 원", "source_offset": 1203 } ],
              "flags": [ { "kind": "unverified_fact", "text": "..." } ], "embargo_until": null, "classified_as": "press_release" } }
// 실패 { "status": "failed", "error": "compliance_blocked|provider_unavailable|source_not_found" }
```

워커가 `blocks`를 zod로 재검증·sanitize한 뒤 기사를 만든다: `status='draft'`, `type='press_release'`, `origin='ai_press_release'`, `ai_assisted=true`, `ai_disclosure`(D-9 문구). `origin`은 생성 후 불변이므로 생성 경로(서비스 호출 `save_article`이 `origin`을 받는지, 전용 RPC가 필요한지)는 05장이 정한다(맞춤 필요). DB CHECK가 이 조합을 강제한다. `ai_run_id`는 잡 `result`에만 둔다. 그래프는 DB의 `articles`에 쓰지 않는다.

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 방식 | event_id 출처 | 처리 |
|---|---|---|---|---|
| 수신 | Toss(신문사 가맹) `POST /api/webhooks/toss/[org_id]` | Toss 웹훅 검증 방식 미확인(SM 6장). 검증 전에는 알림으로만 보고 **그 신문사 시크릿 키로 결제 조회 API를 다시 불러** 상태 확정 | `paymentKey + status + 발생시각` 해시 | `webhook_events` INSERT(멱등) → `record_membership`·`record_donation`(취소, 가상계좌 입금) |
| 수신 | Toss(플랫폼) `POST /api/webhooks/toss/platform` | 같음 | 같음 | 코어 구독 결제 동기화 |
| 수신 | 메일 제공자 `POST /api/webhooks/email` | Resend는 Svix 서명 헤더, SES는 SNS 서명 메시지(구현 시 확인) | 제공자 이벤트 id | `bounced`·`complained` → 구독 `bounced` + 억제 목록, `delivered` 집계. 열람은 참고 지표(메일 앱 보호 기능으로 부정확) |
| 수신 | Vercel 도메인 | 해당 없음(폴링, `news.domain_verify`) | - | - |
| 발신 | `article.published`, `article.updated`, `article.corrected`, `article.unpublished` | HMAC-SHA256(`timestamp.rawBody`), `X-Signature`, `X-Timestamp`, 5분 허용 | `event_id` UUID | 본문 `{ article_id, url, title, type, section, published_at, version }`(본문·개인정보 없음). `news_api` 플랜만 |
| 발신 | `newsletter.sent` | 같음 | 같음 | `{ issue_id, recipients, sent_at }` |

정정 청구·제보·독자 이벤트는 개인정보가 있어 발신 웹훅으로 내보내지 않는다. AI·음성은 웹훅을 쓰지 않는다(그래프 완료는 워커 상태 조회).

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터·조건 |
|---|---|---|---|
| Toss Payments(신문사 가맹) | `src/modules/reader-membership/server/toss.ts`(요청마다 vault에서 키 복호화) | confirm 실패 502 + 주문 실패. 주문 불일치 `NW015` + 결제 취소 요청 + 신문사 알림 | 신문사 계약 조건. 키 미설정 신문사는 멤버십 화면 비노출 |
| 메일(Resend 또는 Amazon SES, 제안) | `src/server/email/`(트랜잭션), 워커 `news.newsletter_batch` | 429·5xx는 잡 재시도, 영구 실패 주소는 억제 | 초당 한도·가격은 제공자 선정 시 확인 |
| Web Push(VAPID) | 워커 `news.push_send` | 404·410이면 `revoke_push_subscription`, 그 외 2회 재시도 | 페이로드 상한(구현 시 확인) |
| 기상청 단기예보, 에어코리아 대기오염(공공데이터포털) | `src/modules/local-life/server/weather.ts` | 실패·지연(3초) 시 블록 숨김, 가짜 값 금지 | 일일 호출 한도·상업 재배포 조건 **미확인**(D-8). 지역별 30분 캐시 |
| Google Ad Manager / AdSense | 브라우저 태그(GPT). `serve_ads`의 `external_network`·`external_unit_id`만 사용 | 태그 실패 시 하우스 광고 | 서버 API 없음. 계정·정책은 신문사 소유 |
| 포털(네이버·다음) | 없음. 크롤링 대상(뉴스 사이트맵, RSS, 구조화 데이터)만 제공 | - | 기사 전송·색인 요청 API는 있다고 가정하지 않음(미확인). 검색제휴 신청은 신문사가 직접(`docs/reference/research/MARKET_LEGAL.md` 포털) |
| Google 뉴스 | 뉴스 사이트맵(최근 2일, 1,000개), `NewsArticle` | - | `https://developers.google.com/search/docs/crawling-indexing/sitemaps/news-sitemap` |
| YouTube 임베드 | 영상 id만 저장, `youtube-nocookie.com` iframe 지연 로드 | 잘못된 id는 저장 거부 | oEmbed 제목 조회는 선택(구현 시 확인) |
| 지도 임베드 | 정적 지도 이미지 + 외부 지도 링크(제안) | - | 카카오·네이버 지도 SDK 키·약관 미확인 |
| Cloudflare Turnstile | 독자 폼 Route Handler `siteverify` | 실패 403, 3초 타임아웃이면 거부 | 한도 구현 시 확인 |
| Vercel 프로젝트 도메인 API | `/api/tenant/domains`, 워커 `news.domain_verify` | MT 4장(`Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:38-61`) | 프로젝트당 도메인 상한 미확인 |
| Supabase 관리 API | 워커 `news.domain_auth_redirect`(`PATCH /v1/projects/{ref}/config/auth` 허용 목록) | 5회 재시도 후 서브도메인 로그인 우회(02장 9.6절) | 허용 목록 상한 미확인 |
| FastAPI AI 서비스 | web(`news.assist`, 채팅 직접 경로), 워커(잡 토큰) | 체인 대체 → `failed` → 환불. mock 금지 | 조직당 60회/분(제안) |
| Dify Chat API | `/api/ai/chat` | 5xx·10초 무응답 → `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs, 오픈소스 음성 서버 | `/api/voice/*`, 워커 `news.ai_tts` | STT는 오픈소스만(대체 없음), TTS는 시작 제공자 고정 | 요청당 STT 10분·TTS 5,000자(`docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:61`) → 구간 분할 |
| WeasyPrint 렌더 서비스 | 워커 `news.support_report`(P1) | 1회 재시도 후 CSV만 제공 | SM 10장 |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

| 엔드포인트 | 호출자 | 인증 | news 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 노드 | 내부 키 | `model`=`dify.aux`(오픈소스 강제). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 그래프 `news.assistant` 동기 실행(`news-archive` 게시 기사 + `news-policy` 위키). assistant `ai_messages`는 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | web(Dify 장애) | 서명 토큰 `chat rag wiki` | 같음 |
| `POST /graphs/news.press_to_draft/runs`, `POST /graphs/news.assist/runs`, `GET /graphs/runs/{id}` | 워커(잡 토큰), web(사용자 토큰) | scope `graph:<name>`, `jti` 1회 | 4절 계약 |
| `POST /rag/ingest` | 워커 경유(`news.ai_index`) | 잡 토큰 `rag` | 컬렉션 `news-archive`, `news-policy`(`oss-embed`) |
| `POST /wiki/ingest`, `POST /wiki/lint` | web(사내 규정 설정 화면) | 서명 토큰 `wiki` | slug `newsroom/policies/...`, `newsroom/style` |

쓰지 않는 것: `POST /dify/retrieval`(외부 지식 미사용), `POST /tools/graph/{name}`(Dify에서 그래프 시작 안 함), `POST /rag/search`(web 직접 검색 안 함).

### 6.2 Dify Chatflow 계약 (`news-assistant`)

| 항목 | 값 |
|---|---|
| 앱 | `news-assistant`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_NEWS`(web 서버 전용), 정의 `infra/dify/news-assistant.yml`(키 없음) |
| 호출 | web `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수)만. 서명 토큰, org, 기사 원문, 제보 내용은 넣지 않는다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:286`) |
| 노드 | 시작 → 질문 분류(LLM 노드, 공급자 = FastAPI OpenAI 호환, model `dify.aux`) → HTTP 요청 노드 → 답변. 외부 지식·내장 지식베이스 노드 없음 |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`, 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, mode: "archive"\|"policy"\|"general" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type: "article"\|"wiki", id or slug, title, url? }], no_source: boolean, fallback: boolean, usage }` |
| 대화 이력 | Dify 보관 30일, 정본 `core.ai_messages` |
| 확인 | 노드 이름·입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인 |

## 7. 오류 코드

제품 SQLSTATE는 DB 설계 요약 v1(2026-10-15)과 같다. 05장이 정본이며 바뀌면 이 표를 맞춘다. 상태 전이·불변 컬럼 위반은 `22023`.

| 코드 | 의미 | HTTP | 대표 발생 위치 |
|---|---|---|---|
| `NW001` | 중복·이미 사용 중(slug, 진행 중 개설 신청) | 409 | `request_newspaper`, `approve_newspaper` |
| `NW002` | 신문사 비공개·비활성·종료 | 409(편집국), 410(독자 호스트) | `publish_article`, `ensure_reader`, `subscribe_newsletter`, `submit_tip` |
| `NW003` | 필요적 게재사항 미완성 | 409 | `publish_article` |
| `NW004` | 허용되지 않은 상태·상태 전이(이미 구성원, 활성 멤버십 상태의 탈퇴 포함) | 409 | 기사·홈·신청·정정 청구 RPC |
| `NW005` | 전재 계약 없음·만료 | 409 | `publish_article` |
| `NW006` | 사람 승인 없음(AI 초안 포함) | 409 | `review_article`, `publish_article` |
| `NW007` | 선거 여론조사 공표 금지 기간 | 409 | `publish_article` |
| `NW008` | 독자 등록 필요·차단된 독자 | 403 | `ensure_reader`, `post_comment`, `report_comment`, `submit_listing`, `submit_life_event` |
| `NW009` | 댓글 꺼짐(기사·신문사·선거 기간) | 409 | `post_comment` |
| `NW010` | 금칙어 포함 | 422 | `post_comment` |
| `NW011` | DB 레이트 리밋(신문사 단위) | 429 | 제출 RPC |
| `NW012` | 구독 토큰 무효·만료 | 400 / 410 | `confirm_newsletter`, `unsubscribe_newsletter` |
| `NW013` | 정부·지자체 광고 직판(정부광고법) | 409 | `save_ad_campaign` |
| `NW014` | 플랜 한도·플랜에 없는 기능 | 403 | `invite_staff`, `save_print_edition`, `submit_listing` |
| `NW015` | 입력 검증 실패(허용 밖 키, 사유 누락, 값 범위, 주문 불일치, 만 14세 미만) | 422 | 전 RPC |
| `22023` / `23505` / `23503` / `23514` | 인자 오류·트리거 전이 / 중복 / 다른 조직 참조 / CHECK(광고 라벨, AI 고지, 여론조사 표시, 경로) | 409 / 409 / 422 / 422 | 공통 |
| 코어 | `42501` 403, `CR001` 402, `P0002`·`PM404` 404, `PM001`·`PM409` 409 + 알림, `JB002` 409, `AI001` 403 | - | CS 15장(`docs/file/03-설계/공용코어/CORE_SPEC.md:404-426`) |
| Theming | `TM001`~`TM003` 409(테마 상태·대비), `TM004` 409(도메인 5개), `TM005` 409(이미 쓰는 도메인) | - | `Multi-tenant_Theming/04_DATA_MODEL.md` 7장 |
| 앱 코드 | `plan_required` 403, `plan_limit` 403, `captcha_failed` 403, `forbidden_origin` 403, `night_consent_none` 409, `query_invalid` 400, `stale_revision` 409, `url_not_allowed` 422, `payments_not_configured` 404, `toss_failed` 502, `toss_key_invalid` 422, `tenant_unavailable` 410 | - | Route Handler |
| AI·음성 앱 코드 | `AI_UNAVAILABLE` 503(환불 완료), `AI_OPEN_SOURCE_UNAVAILABLE` 503(강제 오픈소스 실패, 환불, 상용 대체 없음), `AI_CONSENT_REQUIRED` 403, `AI_CONVERSATION_CLOSED` 409, `AI_DAILY_LIMIT` 429, `CONSENT_VERSION_MISMATCH` 409, `VOICE_CONSENT_REQUIRED` 403, `VOICE_TOO_LONG` 413, `TTS_TOO_LONG` 413, `INTERNAL_KEY_INVALID` 401, FastAPI `AI_TOKEN_INVALID` 401 | - | Route Handler, `apps/api` |

## 8. 인증 단계 경로 (확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절과 02장 9절이다. 아래 경로만 단계(`AUTH_MODE`, 제공자 목록)를 읽는다. 로그인 뒤의 모든 API는 1절 원칙 그대로다.

| 메서드 경로 | 단계 | 호스트 | 입력 | 처리 | 출력 | 오류 |
|---|---|---|---|---|---|---|
| `POST /api/dev/login` | A(로컬 전용) | newsroom, 테넌트(`*.localhost`) | `{ persona, next? }`. newsroom: `owner`\|`admin`\|`member`\|`viewer`\|`outsider`\|`no_app`\|`suspended`\|`ops`\|`desk`\|`contributor`\|`ad_manager`. 테넌트: `reader`\|`reader_member`\|`reader_other`. 호스트와 맞지 않는 페르소나는 422 | `isMockAuthAllowed()` → `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('news', next, hostKind)`(02장 9.3절) | `{ ok: true, data: { redirect } }` + 세션 쿠키 | 판정 거짓 404(본문 없음), 시드 없음 401 + "`node scripts/dev/seed-users.mjs --app news`를 먼저 실행하세요", 422 `invalid_persona` |
| `POST /api/r/auth/magic-link` | B | 테넌트 | `{ email, next?, turnstile_token }` | Turnstile → `rate_limit_hit('news:magic:<ip>', 5, 3600)`, `news:magic:<email 해시>` 3회/시간 → `signInWithOtp({ email, options: { emailRedirectTo: https://<요청 호스트>/auth/confirm?next=... } })`(D-3 (a)) | 항상 202(가입 여부 비공개) | 403 `captcha_failed`, 429 |
| (브라우저 SDK) | B·C | newsroom, 테넌트 | - | `signInWithOAuth({ provider: 'google' \| 'kakao' \| 'custom:naver', options: { redirectTo: https://<요청 호스트>/auth/callback?next=... } })`. 편집국 이메일 로그인은 `signInWithPassword`(브라우저 클라이언트) | - | - |
| `GET /auth/callback` | B·C | 모든 로그인 호스트 | `?code&next` | `exchangeCodeForSession`(PKCE) → `finishLogin`: 제공자 허용 검사 → 독자: `getTenant()` → 그 신문사 `readers` 행 확인(없으면 `/account/welcome` → `POST /api/r/account/join` → `news.ensure_reader`), 차단이면 로그아웃 / 편집국: `resolveOrg` → `session_context('news', org)` → `news.staff` 확인 / 운영: `platform_admin` 확인 → `next` 화이트리스트(origin = 요청 호스트, 해석 도메인과 일치) → 감사 `auth.login`(독자는 감사 대신 `readers`의 시각 컬럼, 3절 머리말) | 302 | `code` 없음·재사용·만료 → `/login?error=callback`. 허용 밖 제공자 → `/login?error=provider` |
| `GET /auth/confirm` | B | 테넌트(독자 매직 링크), newsroom(가입 확인·비밀번호 재설정·편집국 초대) | `?token_hash&type&next` | `verifyOtp({ token_hash, type })` → `finishLogin`(위와 같음). 메일 템플릿은 `{{ .RedirectTo }}` + `token_hash`(`develop/_shared/auth/README.md:27`) | 302 | 만료·재사용 → `/login?error=callback` |
| `GET /auth/naver/start`, `GET /auth/naver/callback` | C2 브리지 채택 시만 | **newsroom만**(독자는 D-3 (b) 중앙 로그인 호스트를 택한 경우만 `login.<플랫폼>`) | flora 04장 8절과 같은 계약 | state 쿠키 HMAC(`AUTH_BRIDGE_SECRET`) → 토큰 교환 → `core.auth_identity_links` → 세션 → `finishLogin` | 302 | `/login?error=state`, `/login?error=email_in_use`(자동 연결 금지), 429 |
| `GET /auth/handoff` | B, D-3 (b) 또는 (a)의 우회 경로 | 테넌트 | `?code`(60초, 1회, 대상 호스트 고정, `LOGIN_HANDOFF_SECRET` 서명) | 중앙(또는 서브도메인) 로그인 호스트가 발급한 일회용 코드를 서버가 교환해 이 호스트의 세션 쿠키를 만든다(토큰을 URL에 싣지 않음) → `finishLogin` | 302 | `/login?error=handoff` |

카카오(C1)와 네이버(C2, `supabase_custom`)는 리디렉션 대상이 Supabase 콜백 1개라 테넌트 호스트가 늘어도 제공자 콘솔 설정은 바뀌지 않는다(02장 9.5절).

| 오류 코드(인증 단계) | HTTP·이동 | 발생 위치 |
|---|---|---|
| `error=callback` | `/login?error=callback` | `/auth/callback`, `/auth/confirm` 세션 확립 실패 |
| `error=provider` | 로그아웃 후 `/login?error=provider` | `finishLogin` 제공자 허용 검사(`develop/_shared/auth/README.md:26`) |
| `error=reader_blocked` | 로그아웃 후 `/login?error=reader_blocked` | 차단 독자(`NW008`) |
| `tenant_unavailable` | 410 "서비스 일시 중지" | `getTenant()` 결과 `null` |
| `error=state`, `error=email_in_use` | `/login?error=...` | 네이버 브리지(채택 시) |
| `error=handoff` | `/login?error=handoff` | 세션 전달 경로 |
| `dev_login_unavailable` | 404(본문 없음) | `/api/dev/login` 판정 거짓 |
| `dev_seed_missing` | 401 | `/api/dev/login` 시드 없음 |
| `invalid_persona` | 422 | `/api/dev/login` zod·호스트 불일치 |
