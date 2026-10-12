# 04 API: Toon Factory

작성일 2026-10-12. 코어 RPC는 `docs/products/_platform-core/CORE_SPEC.md`를 인용만 한다. 제품 RPC 정본은 `docs/products/_supabase-modular/migrations/2000_toon.sql`.

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 Route Handler는 진입부에서 `requireSession('toon')`(`SHARED_MODULES.md:46-72`). 미로그인 401, pending/suspended 403, 엔타이틀먼트 없음 402 |
| 콘텐츠 CRUD | 작품, 캐스트, 회차, 컷은 브라우저가 `supabase.schema('toon')`로 직접 읽고 쓴다(RLS + 한도 트리거). 서버가 콘텐츠를 대신 쓸 때도 사용자 세션 클라이언트를 써서 RLS와 한도를 그대로 적용한다. service_role로 콘텐츠를 쓰는 것은 운영 도구뿐 |
| 서버 전용 | 크레딧, 잡 등록, 서명 URL, 내보내기 행, AI 생성 행, 결제는 Route Handler(service_role) |
| 멱등 | 유료·비동기 요청 본문에 클라이언트 UUID `requestId`. 키: `consume:toon:<requestId>`, `job:toon:<requestId>`(`CORE_SPEC.md:185-194`). `toon.generations.request_id`, `toon.exports.request_id` 유일 |
| 선차감 위치 | 엔타이틀먼트·플랜 검사 → 입력 검증 → compliance → `consume_credits` → 제품 행 INSERT → `enqueue_job`. 잡 등록 실패 시 같은 요청에서 `refund_credits` |
| 응답 봉투 | 성공 `{ data }`, 실패 `{ error: { code, message, details? } }`. `code`는 SQLSTATE 또는 제품 코드 |
| 레이트 리밋 | `core.rate_limit_hit('toon:<route>:<org_id>', limit, window)`. 값은 01장 5절 |
| 입력 검증 | zod. 본문 1MB 상한(웹훅 포함) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 코어/제품 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/session` | 로그인 | - | `SessionContext` + `features` | 0 | `core.session_context('toon')`, `toon.plan_features` | 401 |
| `POST /api/catalog/sign` | member | `{ assetIds: uuid[1..200], variant: 'editor' }` | `{ urls: {assetId: url}, denied: uuid[] , expiresAt }` | 0 | `toon.org_asset_access` → Storage 서명 URL(`toon-catalog`, 15분) | 403 `TN003`(전부 거부 시), 429 |
| `POST /api/storyboard` | member | `{ requestId, episodeId, synopsis(1..2000), cutCount(4..30), tone: 'daily'\|'info'\|'comic'\|'emotional', castIds: uuid[1..6] }` | 202 `{ jobId }` | 3 | `consume_credits`, `enqueue_job('toon.ai','storyboard.generate')` | 402 `CR001`, 422(인스타툰 cutCount>10), `TN006` |
| `POST /api/dialogue/polish` | member | `{ requestId, cutId, layerId, text(1..120), tone }` | `{ options: string[3] }` | 1 | LLM 게이트웨이 `withCredits` | 402, `TN006` |
| `POST /api/generations` | member | `{ requestId, kind: 'background', prompt(1..500), seriesId?, width, height(256..2048), numImages(1..2) }` | 202 `{ generationId, jobId }` | 4 x n | compliance 규칙 → `consume_credits` → `toon.generations` INSERT → `enqueue_job('toon.ai','image.generate')` | 402, 413(용량), `TN006`, 429 |
| `POST /api/exports` | member | `{ requestId, episodeId, kind: 'png'\|'zip'\|'webtoon_strip'\|'mp4', options: { gutterPx?(0..200), gutterColor?, splitHeight?(640..1600), format?: 'jpg'\|'png', transition?: 'cut'\|'crossfade', zoom?: boolean, bgmAssetId?, aiLabelVisible: boolean, aiLabelOptOutConfirmed?: true } }` | 202 `{ exportId, jobId }` | mp4만 3 | `toon.plan_features`, `toon.monthly_export_count`, `toon.org_asset_access`, `consume_credits`(mp4), `toon.exports` INSERT(watermark는 서버 값), `enqueue_job('toon.render','export.<kind>')`, 가시 표기 해제 시 감사 `export.ai_label_opt_out` | 403 `TN002`, 403 `TN003`, 422 `TN004`, 429 `TN005`, 402 |
| `GET /api/exports/{id}/download?i=` | member | 파일 인덱스 | 302 서명 URL(1시간) | 0 | Storage `exports`, 감사 `export.download` | 404, 410(만료) |
| `POST /api/jobs/{id}/cancel` | member | - | `{ status }` | 환불 | 사용자 세션 `core.cancel_job` → service로 제품 행 `canceled` 미러 | 409 `JB002` |
| `POST /api/billing/checkout` | owner/admin | `{ kind: 'subscription', planCode: 'pro' }` 또는 `{ kind: 'credit_pack', packCode }` | `{ orderId, amountKrw, customerKey }` | 0 | `payment_orders` INSERT(금액은 DB) | 409(이미 Pro) |
| `POST /api/billing/confirm` | owner/admin | `{ paymentKey, orderId, amount }` | `{ status }` | 지급 | Toss confirm → `core.confirm_payment_order` | 409 `PM001`/`PM409`, 404 `PM404` |
| `POST /api/billing/billing-key` | owner/admin | `{ authKey, orderId }` | `{ subscription }` | 지급 | 빌링키 발급 → 암호화 저장 → 첫 청구 → `confirm_payment_order` | 402(카드 거절) |
| `POST /api/billing/cancel` | owner/admin | - | `{ cancelAtPeriodEnd: true }` | 0 | `core.apply_subscription_transition(..., 'canceled')` | 409 `SB001` |
| `POST /api/webhooks/toss` | 공개(서명) | raw | 200 | - | `receiveWebhook` → 상태 동기화만 | 401 |
| `POST /api/webhooks/fal` | 공개(서명 미확인) | raw | 200 | - | `receiveWebhook`, `request_id` 대조 | 401, 404 |
| `POST /api/admin/catalog/packs/{id}/verify` | platform_admin | `{ licenseRef, note }` | `{ pack }` | 0 | service UPDATE `toon.asset_packs` + 감사 `asset_pack.verify` | 403 |
| `POST /api/admin/catalog/packs/{id}/publish` | platform_admin | `{ status: 'published'\|'retired' }` | `{ pack }` | 0 | service UPDATE + 감사 | 409(검증 없음, CHECK 23514) |

브라우저 직접 호출(RLS): `toon.series`, `series_characters`, `episodes`, `cuts` CRUD, `rpc toon.save_cut_doc`, `rpc toon.reorder_cuts`, `rpc toon.archive_user_asset`, `toon.catalog_assets`, `toon.generations`/`user_assets`/`exports` 조회, `core.jobs` Realtime.

## 3. RPC (SECURITY DEFINER)

SECURITY INVOKER 함수도 이 절에 함께 적는다.

| 함수 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `toon.has_toon_access()` | authenticated(정책 안) | auth.uid()의 활성 멤버십 + toon 엔타이틀먼트 | boolean | - |
| `toon.plan_features(p_org_id)` | authenticated, service | `is_service_caller()` 또는 `is_org_member` | jsonb | 42501 |
| `toon.feature_int(features, key, default)` | 내부 | - | int | - |
| `toon.save_cut_doc(p_cut_id, p_doc, p_expected_revision)` | authenticated(INVOKER, RLS 적용) | revision 일치 | 새 revision | `TN409`, `P0002`, `23514`(문서 형식) |
| `toon.reorder_cuts(p_episode_id, p_cut_ids)` | authenticated(INVOKER) | id 목록이 회차 컷과 정확히 일치 | void | `P0002`, `22023` |
| `toon.org_asset_access(p_org_id, p_asset_ids)` | authenticated, service | 서비스 또는 멤버 + 엔타이틀먼트 | `(asset_id, tier, allowed)` | 42501 |
| `toon.monthly_export_count(p_org_id)` | authenticated, service | 서비스 또는 멤버 | int(KST 월) | 42501 |
| `toon.archive_user_asset(p_user_asset_id)` | authenticated | 서비스 또는 `has_org_role(owner,admin,member)` + 감사 | void | `P0002`, 42501 |

트리거 함수(`enforce_plan_limits` `TN001`, `bump_cut_revision`, `enforce_run_status_transition` 22023)는 EXECUTE를 열지 않는다. 코어 RPC: `consume_credits`/`refund_credits`(`CORE_SPEC.md:152-160`), `enqueue_job`/`claim_jobs`/`heartbeat_job`/`complete_job`/`fail_job`/`cancel_job`(`:278-307`), `confirm_payment_order`(`:210-221`), `rate_limit_hit`(`:332-340`).

## 4. 잡 페이로드 계약

공통: 비밀값을 넣지 않는다. `org_id`는 `core.jobs.org_id`에서 읽는다.

### 4.1 `storyboard.generate`

```json
{
  "payload": { "episode_id": "uuid", "series_id": "uuid", "request_id": "uuid", "format": "instatoon|webtoon",
               "synopsis": "string", "cut_count": 8, "tone": "daily",
               "cast": [{ "character_id": "uuid", "display_name": "미나", "role_note": "주인공",
                          "poses": ["wave", "sit"], "expressions": ["smile", "angry"] }] },
  "result": { "script": { "v": 1, "title": "string", "cuts": [
      { "index": 1, "scene": "출근길 지하철", "background_hint": "crowded subway car, morning",
        "shot": "wide|medium|close",
        "characters": [{ "character_id": "uuid", "pose_code": "wave", "expression_code": "smile", "position": "left|center|right", "flip": false }],
        "dialogues": [{ "speaker_character_id": "uuid|null", "type": "speech|thought|narration|sfx", "text": "60자 이하" }] } ] },
    "usage_id": 123 },
  "progress": "10 프롬프트 구성 / 60 생성 / 90 검증 / 100 저장"
}
```

검증: 컷 수 = `cut_count`, 컷당 캐릭터 0~3, 대사 0~4, 코드가 cast의 목록 밖이면 첫 포즈/첫 표정으로 바꾸고 `result.warnings`에 남긴다. 성공 시 워커가 `toon.episodes.script`에 저장하고 `status='storyboarded'`.

### 4.2 `image.generate`

```json
{
  "payload": { "generation_id": "uuid", "kind": "background", "prompt": "한국어", "style_preset": "flat_line",
               "width": 1080, "height": 1350, "num_images": 1, "model": "화이트리스트 ID", "seed": null },
  "result": { "user_asset_ids": ["uuid"], "fal_request_id": "string", "prompt_en": "string", "refunded_images": 0 },
  "progress": "10 프롬프트 변환 / 30 제출 / 30~90 대기(폴링 2초) / 95 저장"
}
```

워커: LLM `toon.prompt_en` → fal 제출(`webhook_url`, 안전 필터 ON) → 폴링 또는 웹훅 이벤트 확인 → 이미지를 `toon-user-assets/<org>/toon/user_assets/<uuid>.png`로 복사, 256px 썸네일 → `toon.user_assets`(source `ai_generated`, `ai_generated=true`, model) → `generations.status='succeeded'`. 안전 필터 거부: `fail_job(retryable=false)`.

### 4.3 `export.png` / `export.zip` / `export.strip` / `export.mp4`

```json
{
  "payload": { "export_id": "uuid", "episode_id": "uuid", "kind": "png|zip|webtoon_strip|mp4" },
  "result": { "output_paths": ["<org>/toon/exports/<export_id>/01.png"], "bytes": 123456, "duration_ms": 25000,
              "ai_label": true, "files": 10 },
  "progress": "컷 i/n 렌더 / 인코딩 / 업로드"
}
```

워터마크, AI 표기, 옵션은 페이로드가 아니라 `toon.exports` 행(`watermark`, `ai_label_visible`, `options`)에서 읽는다. 컷 문서는 잡 시작 시 DB에서 읽은 스냅샷을 쓴다(진행 중 편집은 반영하지 않음). 결과 `expires_at = now() + 30일`.

### 4.4 `cut.thumbnail`

`{ "payload": { "cut_id": "uuid", "revision": 3 }, "result": { "thumbnail_path": "..." } }`. revision이 바뀌었으면 건너뛴다.

## 5. 웹훅

| 수신 | 서명 | event_id | 처리 |
|---|---|---|---|
| Toss | Toss 문서 기준(미확인) | `paymentKey + status + 발생시각` 해시(`CORE_SPEC.md:249`) | 결제 취소·가상계좌 상태 동기화만. 지급은 confirm 경로 |
| fal | fal 문서 기준(미확인). 확인 전에는 `request_id`가 `toon.generations.fal_request_id`와 일치하는지만 확인 | `request_id` | `webhook_events`에 기록. 워커 폴링이 결과를 확정(웹훅은 보조) |

발신 웹훅 없음(automation-core 미사용).

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 | 쿼터/비용 |
|---|---|---|---|
| LLM 게이트웨이 | 워커(콘티, 프롬프트), Route Handler(대사) | 폴백 1회 → 환불 + `ai_usage.status='error'` | 레이트 리밋 01장 5절 |
| fal | 워커 | 제출 실패 재시도 3회(지수 백오프), 30분 미완료 실패, 안전 거부 재시도 없음 | 모델 화이트리스트 |
| Toss | Route Handler, 워커 스케줄 | `SHARED_MODULES.md:134` | - |
| Supabase Storage | Route Handler(서명), 워커(읽기/쓰기) | 업로드 실패 재시도 3회 후 잡 실패 | 파일 상한 01장 5절 |

## 7. 오류 코드

| 코드 | 의미 | 발생 | HTTP |
|---|---|---|---|
| `TN001` | 플랜 한도(작품/회차/컷) | DB 트리거 | 403 |
| `TN002` | 플랜에 없는 내보내기 종류 | Route Handler | 403 |
| `TN003` | 플랜 등급 밖 에셋 사용 | Route Handler, 워커 | 403 |
| `TN004` | MP4 길이 초과 | Route Handler | 422 |
| `TN005` | 월 이미지 내보내기 한도 | Route Handler | 429 |
| `TN006` | 프롬프트·대사 규칙 위반 | Route Handler | 422 |
| `TN409` | 컷 revision 충돌 | `toon.save_cut_doc` | 409 |
| `23514` | 문서 형식·라이선스 CHECK 위반 | DB | 422 |
| `23503` | 다른 조직 부모 참조(복합 FK) | DB | 404 |
| 코어 코드 | `42501`→403, `CR001`→402, `P0002`→404, `22023`/`JB002`/`SB001`→409, `PM001`/`PM409`→409 + 알림 | `CORE_SPEC.md:397-418` | - |
