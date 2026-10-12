# 04 API: FLORA Publishing

작성일 2026-10-12. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`(아래 CS)를 인용만 한다. 공용 모듈 인터페이스는 `SHARED_MODULES.md`(아래 SM). 코드 블록은 계약 예시다.

## 1. 원칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| 인증 | 모든 Route Handler 첫 줄 `const ctx = await requireSession('publishing')`. 미로그인 401, pending/suspended 403, `entitled=false` 402. 공개 예외: `/api/waitlist`, `/api/webhooks/toss`, `/api/webhooks/fal`, `/api/public/books/[slug]`(Phase 2) | SM 2장, `docs/reviews/Flora-v2.md:114` |
| 순서 | 인증 → 입력 zod 검증 → 레이트 리밋 → 엔타이틀먼트·features 확인 → 크레딧 선차감 → 처리(동기 호출 또는 enqueue) → 실패 시 환불 | CS 4.3, `docs/reviews/SellingDocs.md:70` |
| 멱등 | 유료·비동기 요청은 본문에 `request_id`(UUID v4) 필수. 차감 키 `consume:publishing:<request_id>`, 잡 키 `job:publishing:<request_id>` | CS 4.4, SM 18장 |
| DB 접근 | 사용자 콘텐츠(books, chapters, sections, member_settings) 읽기·쓰기는 세션 클라이언트(RLS 적용). 서버 전용 테이블과 코어 RPC는 `createAdminClient`(service_role)로, 호출 전에 `ctx.org.id`와 대상 행의 `org_id` 일치를 확인 | `SECURITY_BASELINE.md` 4장, 11장 |
| 응답 봉투 | 성공 `{ ok: true, data }`, 실패 `{ ok: false, error: { code, message, details? } }`. 402는 `details: { required, balance }` | 제안 |
| 레이트 리밋 | `core.rate_limit_hit('publishing:<route>:<org_id>', limit, window)`. 기본은 01장 5절 | CS 12장 |
| 스트리밍 | 섹션 단건·보조 집필만 `text/event-stream`을 POST 응답으로. 클라이언트는 fetch + ReadableStream. EventSource 금지 | `docs/reviews/Flora-v2.md:105` |
| sanitize | LLM 결과와 사용자 HTML은 서버에서 허용 목록 sanitize 후 저장(p, h2~h4, strong, em, u, s, blockquote, ul, ol, li, br, hr, a[href https], figure, img[src Storage 경로], figcaption, table 계열). 렌더 직전 엔진이 nh3로 한 번 더 | `docs/reviews/SellingDocs.md:55`, `SECURITY_BASELINE.md` 10장 |

## 2. Route Handler

플랜 열: F = Free 가능, B = Basic 필요(features 키). 크레딧은 `01_PRD.md` 4.3절.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/session` | 로그인 | - | `SessionContext` | 0 | `session_context` | 401 |
| `POST /api/books` | member+ / F | `{ title?, source:'wizard'|'seed', seed_key? }` | `{ book }` | 0 | - | 409 `PB001`(쿼터) |
| `GET /api/books` | 멤버 / F | `?status&trash=bool&cursor` | `{ items, next }` | 0 | - | - |
| `PATCH /api/books/[id]` | member+ / F | 콘텐츠 컬럼 부분집합(`step_state`, `current_step`, `format_key`, `layout_settings`, `tone`, `plan_brief`, `book_info`, `cover_image_id`, `status`) | `{ book }` | 0 | - | 409 `22023`, `PB006`, `PB011` |
| `DELETE /api/books/[id]` | owner/admin / F | - | `{ ok }`(soft delete) | 0 | `write_audit` | 404 |
| `POST /api/books/[id]/restore` | owner/admin / F | - | `{ book }` | 0 | - | 409 `PB001`(복구 시 쿼터 재검사) |
| `POST /api/books/[id]/titles` | member+ / F | `{ request_id, direction? }` | `{ candidates: [{title, subtitle, reason}] }` | 1 | `consume/refund_credits` | 402, 502 `llm_failed` |
| `POST /api/books/[id]/plans` | member+ / F | `{ request_id, target_reader?, emphasis_tone? }` | `{ plans: [3] }` | 2 | 같음 | 402, 502 |
| `POST /api/books/[id]/toc` | member+ / F | `{ request_id, chapters 1..20, sections_per_chapter 1..10, paragraphs 1..5 }` | `{ tocs: [3] }`(저장 안 함) | 2 | 같음 | 402, 403 `plan_limit`(설정값이 플랜 초과) |
| `PUT /api/books/[id]/structure` | member+ / F | `{ chapters: [{ id?, title, sections: [{ id?, title, paragraph_target }] }] }` | `{ chapters }` | 0 | - | 409 `PB002~PB004`, `PB005`(생성 중 섹션 삭제) |
| `POST /api/books/[id]/sections/[sid]/generate` | member+ / F(quality는 B) | `{ request_id, mode:'fast'|'quality', overwrite?:bool }` | SSE `delta`, `done{ section }` | 1/2 | 같음 | 402, 403, 409 `PB005`, 409 `generation_active` |
| `POST /api/books/[id]/assist` | member+ / B `writing_assist` | `{ request_id, section_id, action:'continue'|'expand'|'refine'|'custom', selection_text ≤ 2000, instruction? ≤ 500 }` | SSE, `done{ suggestion }`(저장 안 함, Diff 적용은 클라이언트가 PATCH) | 1 | 같음 | 402, 403, 422 |
| `PATCH /api/books/[id]/sections/[sid]` | member+ / F | `{ title?, body_html?, paragraph_target?, revision }` | `{ section }` | 0 | - | 409 `stale_revision`, `PB005` |
| `POST /api/books/[id]/write-all` | member+ / B `write_all` | `{ request_id, mode, overwrite: bool, section_ids? }` | `{ run, estimated_credits }` | 섹션별(자식 잡) | `enqueue_job` | 402(예상치 부족), 409 `generation_active` |
| `POST /api/books/[id]/refine-all` | member+ / B `writing_assist` | `{ request_id, mode }` | `{ run, chunks }` | 청크별 | `enqueue_job` | 402, 409 |
| `POST /api/generation-runs/[id]/cancel` | member+ / F | - | `{ run }` | 0(대기분 환불) | `publishing.request_generation_cancel` | 409 `PB007` |
| `POST /api/books/[id]/covers` | member+ / F | `{ request_id, style, bg_color?, font_style? }` | `{ covers: [3], job_id }` | 6 | `consume_credits`, `enqueue_job` | 402 |
| `POST /api/books/[id]/metadata` | member+ / F | `{ request_id }` | `{ book_info }`(저장 전 제안) | 1 | `consume/refund_credits` | 409 `manuscript_empty` |
| `GET /api/books/[id]/preview` | 멤버 / F | `?pages=1..10` | `text/html`(sandbox iframe용) | 0 | - | 429 |
| `POST /api/books/[id]/exports` | member+ / F | `{ request_id, format:'pdf'|'epub', options:{ toc:bool, running_header:bool, ai_notice:bool } }` | `{ export, reused: bool }` | PDF 2 / ePub 1 / 재사용 0 | `consume_credits`, `enqueue_job` | 402, 403 `plan_limit`(월 한도), 409 `manuscript_empty` |
| `GET /api/exports/[id]/download` | 멤버 / F | - | 302 → 서명 URL(7일) | 0 | - | 404, 410 `expired` |
| `POST /api/uploads` | member+ / B `upload` | `{ file_name, ext, bytes ≤ 20MB, rights_confirmed: true }` | `{ upload_id, signed_upload_url, token }` | 0 | - | 413, 415, 403 |
| `POST /api/uploads/[id]/complete` | member+ / B | - | `{ upload, job_id }` | 0 | `enqueue_job` | 413(실제 크기), 415(매직바이트) |
| `POST /api/uploads/[id]/create-book` | member+ / B | `{ format_key, genre? }` | `{ book }` | 0 | - | 409 `PB001~PB004`(초과분 목록 `details`) |
| `POST /api/seeds/[seed_key]/duplicate` | member+ / F | - | `{ book }` | 0 | - | 409 `PB001` |
| `POST /api/personas/blend` | member+ / B `persona_blend` | `{ request_id, name, base_persona_ids ≤ 3, sample_text ≤ 5000 }` | `{ persona }` | 3 | `consume/refund_credits` | 402, 403 |
| `PATCH /api/settings` | 본인 / F | `{ theme_key?, favorite_persona_ids?, llm_mode? }` | `{ settings }` | 0 | - | 409 `PB008` |
| `POST /api/billing/orders` | owner/admin | `{ kind:'credit_pack'|'subscription', code }` | `{ orderId, amountKrw, customerKey, expiresAt }` | 0 | 서버 `payment_orders` INSERT | 403, 404 |
| `POST /api/billing/confirm` | owner/admin | `{ paymentKey, orderId, amount }` | `{ payment, balance }` | 지급 | Toss confirm → `confirm_payment_order` | 409 `PM001`(+ Toss 취소 요청), `PM409`, `PM410` |
| `POST /api/billing/billing-key` | owner/admin | `{ authKey }` | `{ card_masked, subscription }` | 0 | 빌링키 발급 → 첫 주문 → `confirm_payment_order` | 402 결제 실패 |
| `POST /api/billing/subscription/cancel` | owner/admin | - | `{ subscription }`(해지 예약) | 0 | `apply_subscription_transition` | 409 `SB001` |
| `POST /api/webhook-endpoints` | owner/admin / B `webhooks` | `{ url https, events[] }` | `{ endpoint, secret }`(비밀은 이번 응답에서만) | 0 | vault put | 422 `url_not_allowed`(사설 IP, localhost, 비 https), 409 5개 초과 |
| `DELETE /api/webhook-endpoints/[id]` | owner/admin | - | `{ ok }`(disabled + 비밀 revoke) | 0 | `revoke_credential` | 404 |
| `POST /api/webhook-endpoints/[id]/test` | owner/admin | - | `{ delivery }` | 0 | `enqueue_job` | 429 |
| `POST /api/account/delete` | owner | `{ confirm_text: '삭제합니다' }` | `{ purge_at }` | 0 | 서버 조직 soft delete + 감사 | 422 |
| `POST /api/waitlist` | 공개 | `{ email, consent_marketing }` | `{ ok }` | 0 | `rate_limit_hit` | 429 |
| `GET /api/waitlist/count` | 공개 | - | `{ count }`(실제 행 수) | 0 | - | - |
| `POST /api/webhooks/toss` | 공개(서명) | raw body | 200 | - | `webhook_events` | 401 서명, 200 중복 |
| `POST /api/webhooks/fal` | 공개(검증) | raw body | 200 | - | `webhook_events` | 401, 200 중복 |
| `POST /api/admin/credits/adjust` | platform_admin | `{ org_id, amount, reason ≥ 10자 }` | `{ ledger }` | 조정 | `grant_credits` 또는 코어 adjust(요청 중, 06장 6절) + `audit_log` | 403 |
| `POST /api/books/[id]/visibility` (Phase 2) | owner/admin / B `public_page` | `{ is_public, slug? }` | `{ book }` | 0 | `publishing.set_book_visibility` | 409 `PB009`, 409 `slug_taken` |

엔진 내부(공개 인터넷에서 호출 불가, `X-Internal-Token`):

| 메서드 경로 | 호출자 | 입력 | 출력 |
|---|---|---|---|
| `GET /health` | 플랫폼 | - | `{ ok, fonts_ok, render_ok }` |
| `POST /internal/preview` | web | `{ org_id, book_id, pages ≤ 10 }` | sanitize된 HTML |
| `POST /internal/content-hash` | web | `{ org_id, book_id, format, options }` | `{ content_hash }`(재사용 판정용) |

## 3. RPC (SECURITY DEFINER)

제품 스키마 함수. 코어 RPC(`consume_credits`, `grant_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `confirm_payment_order`, `apply_subscription_transition`, `write_audit`, `rate_limit_hit`, `session_context`)는 CS 4~12장 그대로.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `publishing.request_generation_cancel(p_run_id uuid)` | authenticated, service_role | `is_service_caller()` 아니면 `has_org_role(org, owner/admin/member)`. 상태 queued/running. 감사 `generation_run.cancel_request` | `publishing.generation_runs` | `P0002`, `42501`, `PB007` |
| `publishing.set_book_visibility(p_book_id uuid, p_is_public boolean, p_slug text default null)` | authenticated, service_role | `is_service_caller()` 아니면 `has_org_role(org, owner/admin)`, 엔타이틀먼트, 공개 시 `status='completed'` + `features.public_page` + slug 형식. 감사 `book.publish_page`/`book.unpublish_page` | `publishing.books` | `P0002`, `42501`, `PB009`, `22023`, `23505` |
| `publishing.book_plan_limit(p_org_id uuid, p_key text, p_default integer)` | authenticated, service_role | 비멤버면 기본값만 반환(타 조직 플랜 비노출) | integer(-1 무제한) | - |
| `publishing.book_plan_flag(p_org_id uuid, p_key text, p_default boolean)` | 위와 같음 | 위와 같음 | boolean | - |
| `publishing.book_theme_allowed(p_org_id uuid, p_theme_key text)` | 위와 같음 | 위와 같음 | boolean | - |

모두 `set search_path = ''`, `revoke execute ... from public, anon`(`_supabase-modular/migrations/1000_publishing.sql` 0절, 12절). 사용자용 RPC 안에서 크레딧을 차감하지 않는다(`DB_CONVENTIONS.md` 11장).

## 4. 잡 페이로드 계약

공통: 비밀값을 넣지 않는다. 경로는 서버가 만든 Storage 경로만. `progress`는 0~100, `progress_message`는 한국어 한 줄.

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `publishing.write_section` | `{ book_id, section_id, run_id?, mode, overwrite, persona_ref: { id, custom_id? }, omnibus: bool }` | `{ section_id, char_count, model, usage_id }` | "1.2 설계도 속의 인간 생성 중" |
| `publishing.write_all` | `{ run_id, book_id, section_ids: uuid[], mode, overwrite, window: 3 }` | `{ done, failed, skipped, credits_used }` | "8/15 소제목 완료" |
| `publishing.refine_all` | `{ run_id, book_id, chunk_chars: 2000, mode }` | `{ chunks, suggestions_saved }` | "5/15 구간 다듬는 중" |
| `publishing.refine_chunk` | `{ run_id, book_id, section_id, offset, length, mode }` | `{ suggestion_html }`(자식 잡 `result`에만 저장, 원문 미변경. 클라이언트가 `core.jobs`를 RLS로 읽어 Diff 표시) | - |
| `publishing.cover_generate` | `{ book_id, cover_ids: uuid[3], style, prompt_vars: { title, genre, mood } }` | `{ succeeded: uuid[], failed: uuid[] }` | "표지 2/3 완료" |
| `publishing.parse_manuscript` | `{ upload_id, storage_path, ext }` | `{ chapters, sections, paragraphs, char_count }`(outline은 `manuscript_uploads.parsed_outline`) | "문서 구조 읽는 중" |
| `render.pdf` | `{ export_id, book_id, preset: { page, width_mm, height_mm, margins_mm{top,right,bottom,left,inner_extra}, font_pt, line_height }, options: { watermark: bool, toc, running_header, ai_notice, cover_image_path? } }` | `{ storage_path, pages, bytes, duration_ms }` | "PDF 조판 중" |
| `publishing.export_epub` | `{ export_id, book_id, options: { ai_notice, cover_image_path? } }` | `{ storage_path, bytes, epubcheck_errors: 0 }` | "ePub 만드는 중" |
| `publishing.webhook_deliver` | `{ endpoint_id, event_id, event_type, data }` | `{ http_status, attempts }` | - |
| `publishing.purge` | `{ kind: 'books'|'uploads'|'exports', before: timestamptz }` | `{ deleted_rows, deleted_objects }` | - |

렌더 서비스 계약은 SM 10장 `RenderPdfRequest`/`RenderPdfResponse`를 그대로 쓴다(`app_id: 'publishing'`). 이 제품이 소유자로서 정하는 세부:

| 항목 | 값 |
|---|---|
| 엔드포인트 | `POST /render/pdf`, `GET /health`(Noto CJK 확인), `X-Render-Token` 필수, 요청 본문 상한 20MB(제안) |
| url_fetcher | `RENDER_ALLOWED_ASSET_HOSTS`의 https 호스트만. `file://`, `data:` 외 스킴, 사설·링크로컬 IP, 리다이렉트 거부. 실패 시 이미지 생략이 아니라 렌더 실패(재시도 불가) |
| 시간 | 120초 타임아웃, 초과 시 프로세스 단위 강제 종료 |
| 동시성 | 컨테이너당 4(제안), 초과 요청 429 → 엔진이 재큐잉 |
| 출력 | Storage `exports/<org_id>/<app_id>/pdf/<uuid>.pdf` |

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 방식 | event_id 출처 | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태(취소, 가상계좌 입금) | Toss 웹훅 검증 방식(미확인, SM 6장) | `paymentKey + status + 발생시각` 해시(CS 6장) | `webhook_events` INSERT → 상태 동기화만. 지급은 confirm 경로 |
| 수신 | fal 완료 | fal 서명(미확인). 확인 전에는 `request_id`가 우리 잡 payload의 값과 일치하는지만 대조 | `request_id` | 이미지 Storage 복사 → `cover_images` 갱신 → 잡 complete/fail |
| 발신 | `book.completed` | HMAC-SHA256(`timestamp.rawBody`), `X-Signature`, `X-Timestamp`, 5분 허용 | `event_id` UUID | `webhook_deliveries` 멱등(`endpoint_id, event_id`) |
| 발신 | `export.succeeded` | 같음 | 같음 | 본문 `{ book_id, export_id, format, pages, download_url }`. 서명 URL 유효 24시간(제안: 외부 자동화가 받아 갈 시간) |
| 발신 | `export.failed` | 같음 | 같음 | 본문 `{ book_id, export_id, format, error_code }` |

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| Anthropic / OpenRouter | 공용 LLM 게이트웨이(web, TS 워커) | 폴백 1회 → 실패 시 환불 + `ai_usage.status='error'`. mock 금지 | 조직당 60회/분(제품 레이트 리밋) |
| fal | 공용 fal 클라이언트(TS 워커) | 제출 실패 즉시 환불, 30분 미도착 `fail_job` | 동시 3(책당 1회 생성) |
| Toss | 공용 toss 모듈(web, 정기결제 워커) | CS 5장. `PM001`은 운영 알림 + 승인 취소 요청 | - |
| WeasyPrint 렌더 서비스 | 엔진 | 4절 | 동시 4/컨테이너 |
| Supabase Storage | web(서명 URL), 엔진·워커(service_role) | 업로드 완료 검증 실패 시 객체 삭제 | 버킷 상한(org-files 50MB, exports 200MB) |

## 7. 오류 코드

| 코드 | 의미 | HTTP | 발생 위치 |
|---|---|---|---|
| `PB001` | 책 수 한도 | 409 | `books` INSERT 트리거 |
| `PB002` | 챕터 수 한도 | 409 | `chapters` 트리거 |
| `PB003` | 소제목 합계 한도 | 409 | `sections` 트리거 |
| `PB004` | 단락 목표 한도 | 409 | `sections` 트리거 |
| `PB005` | 생성 중인 섹션 편집 | 409 | `sections` 트리거 |
| `PB006` | 다른 책 또는 미완료 표지 선택 | 409 | `books` 트리거 |
| `PB007` | 취소할 수 없는 실행 상태 | 409 | `request_generation_cancel` |
| `PB008` | 플랜에 없는 테마 | 409 | `member_settings` 트리거 |
| `PB009` | 공개 조건 미충족 | 409 | `set_book_visibility` |
| `PB010` | 삭제한 책의 직접 복구 | 409 | `books` 트리거(복구는 서버 API) |
| `PB011` | 집필 시작 후 페르소나 변경 | 409 | `books` 트리거 |
| `22023` | 상태 전이 위반, 인자 오류 | 409 | 전이 트리거 |
| `23505` | 중복(진행 중 실행, slug) | 409 | 유니크 인덱스 |
| `23503` | 다른 조직·책 행 참조 | 422 | 복합 FK |
| 코어 코드 | `42501` 403, `CR001` 402, `P0002`/`PM404` 404, `PM001`/`PM409` 409 + 알림, `JB002` 409 | - | CS 15장 매핑 |
| 앱 코드 | `plan_required` 403, `plan_limit` 403, `llm_failed` 502, `render_failed` 502, `manuscript_empty` 409, `stale_revision` 409, `generation_active` 409, `url_not_allowed` 422, `expired` 410 | - | Route Handler |
