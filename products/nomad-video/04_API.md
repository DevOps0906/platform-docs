# 04 API: NOMAD AI Factory (nomad-video)

## 1. 원칙

| 항목 | 규칙 |
|---|---|
| 인증 | 모든 `/api/**`(웹훅·공개 제외)는 진입부에서 `requireSession('video', { roles })`(SHARED_MODULES 2장). 조직은 세션에서 결정하고 요청 본문의 `orgId`를 받지 않는다(BS #5, #12) |
| 입력 검증 | zod. Track `A-F`, 언어 `KO/JA/EN`, URL 도메인 허용 목록, `limit` 1~100 |
| 멱등 | 생성·결제·업로드 요청 본문에 클라이언트 UUID `request_id` 필수. 서버는 `consume:video:<request_id>`, `job:video:<request_id>`로 사용. 같은 키 재요청은 기존 결과 반환 |
| 크레딧 | 선차감은 Route Handler(service_role)에서 `consume_credits` → `enqueue_job(p_credit_ledger_id)`. 사용자 RPC 안에서 차감하지 않는다 |
| 응답 봉투 | 성공 `{ "ok": true, "data": ... }`, 실패 `{ "ok": false, "error": { "code": "VD009", "message": "...", "detail": {...} } }` |
| 레이트 리밋 | 키 `video:<route>:<org_id 또는 ip_hash>`, Redis 카운터(CORE_SPEC 12장). 생성 60회/분/조직 |
| 게이팅 | `entitled_plan_code` + features(01장 4절). 서버 판정이 정본, DB 정책이 2차 |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| GET `/api/session` | 로그인 | - | SessionContext | - | `session_context` | 401 |
| POST `/api/billing/orders` | owner/admin | `{kind, planCode?|packCode?, request_id}` | `{orderId, amountKrw, customerKey}` | - | INSERT `payment_orders` | 403(adv 팩 비Advanced), 409 |
| POST `/api/billing/confirm` | owner/admin | `{paymentKey, orderId, amount}` | 결제 결과 | - | `confirm_payment_order` | PM001/PM409 → 409 + 취소, PM404 → 404 |
| POST `/api/billing/billing-key` | owner/admin | `{authKey}` | `{cardMasked}` | - | billing_keys INSERT(서버) | 400 |
| POST `/api/billing/cancel` | owner/admin | `{reason}` | 구독 | - | `apply_subscription_transition` | SB001 → 409 |
| GET `/api/channels` | 전 역할 | - | 채널 목록 | - | RLS select | - |
| POST `/api/channels/connect` | owner/admin | `{platform, role, targetLanguage, riskAck: true}` | `{authorizeUrl}` | - | `create_oauth_state` | VD004 → 403 |
| GET `/api/channels/callback/[platform]` | 공개(state로 사용자 확정) | `code, state` | 302 `/dashboard/channels` | - | `consume_oauth_state`, credential INSERT, channels INSERT | OA001 → 400, VD003 → 409 |
| PATCH `/api/channels/[id]` | owner/admin | `{role?, targetLanguage?, targetCountry?, status?}` | 채널 | - | `video.update_channel_settings` | 42501 → 403 |
| DELETE `/api/channels/[id]` | owner/admin | - | 채널(revoked) | - | `video.disconnect_channel` | 403 |
| POST `/api/sources` | member+ | `{url, track, rightsBasis, rightsNote?, request_id}` | 소스 | 1 | consume, enqueue `source.download` | 422 도메인, 402 |
| GET `/api/radar/playboard` | Basic+ | `{country, period, category?}` | 랭킹 | 0 | RLS select | 403 |
| POST `/api/radar/channel-finder` | Pro+ | `{maxSubscribers, minAvgViews, days}` | 리포트 id | 2 | consume, enqueue | 402, 403 |
| POST `/api/radar/bling` | Pro+ | `{topic, request_id}` | 리포트 id | 5 | consume, enqueue | 429 VD012 |
| POST `/api/productions/estimate` | member+ | 생성 입력과 같음 | `{total, breakdown}` | 0 | - | 422 |
| POST `/api/productions` | member+ | `{track, mode?, sourceId?, topic?, languages[], options{silenceCut, layerComposite}, request_id}` | production + rootJobId | 단가 합계 | consume, enqueue `production.run` | VD009, VD010, 402, 429(동시 생산 상한) |
| GET `/api/productions/[id]` | 전 역할 | - | production + outputs + job | - | RLS | 404 |
| POST `/api/productions/[id]/cancel` | member+ | - | production | 환불 | `cancel_job`(queued) / 워커 취소 신호(running) | JB002 → 409 |
| POST `/api/longform` | Pro+ member+ | `{title, category, topic, languages, targetMinutes}` | 프로젝트 | 0 | RLS insert | 403 |
| POST `/api/longform/[id]/score` | Pro+ | `{request_id}` | `{score, alternatives}` | 2 | withCredits | - |
| POST `/api/longform/[id]/storyline` | Pro+ | `{request_id}` | 스토리라인 | 5 | withCredits | VD010 |
| POST `/api/longform/[id]/storyboard` | Pro+ | `{request_id}` | 섹션 10 | 0(스토리라인에 포함) | service upsert sections | VD005 |
| POST `/api/longform/[id]/render` | Pro+ | `{request_id}` | rootJobId | 이미지 30 + TTS(언어당 5/10분) + 인코딩 10/10분 | consume, enqueue `longform.render` | 402 |
| POST `/api/longform/[id]/highlights` | Pro+ osmu | `{request_id}` | 하이라이트 3 | 11 | consume, enqueue | 409(롱폼 미완료) |
| POST `/api/music` | Pro+ suno | `{title, genre, prompt, mood?, bpm?, request_id}` | 곡 | 23 | consume, enqueue `music.generate` | 402 |
| POST `/api/music/[id]/package` | Pro+ | - | 패키지 서명 URL | 0 | enqueue `music.package` | 409 |
| POST `/api/music/[id]/distribution` | member+ | `{status, note?, isrc?}` | 곡 | 0 | `video.set_music_distribution_status` | 22023 → 409 |
| POST `/api/library` | Pro+ member+ | `{title, artist, licenseType, licenseProofPath, audioPath, licenseExpiresAt?, youtubeMonetizationAllowed, attributionText?}` | 라이브러리 곡 | 0 | RLS insert(파일은 org-files 업로드 후 경로) | 23514 |
| POST `/api/playlists` | Pro+ member+ | `{title, mood, targetDurationMin, language}` | 플리 | 0 | RLS insert | 42501 → 403 |
| PUT `/api/playlists/[id]/items` | member+ | `{items: [{musicTrackId?|libraryTrackId?}]}` | 항목 | 0 | RLS insert/update/delete(트랜잭션) | VD005, VD006 |
| POST `/api/playlists/[id]/render` | Pro+ | `{request_id}` | rootJobId | 20/35/95 | consume, enqueue `playlist.render` | 409(합계 시간 목표 ±5% 밖) |
| POST `/api/uploads` | member+ | `{outputId, channelId?, platform, title, description, tags, visibility, scheduledAt?, paidPromotion, affiliateLinkIds[], request_id}` | upload(draft, 문구 삽입 완료) | 0 | `effective_disclosure`, affiliate 링크, uploads INSERT(service) | VD008, VD002 |
| POST `/api/uploads/[id]/check` | member+ | `{request_id}` | 검사 결과 | 1(LLM 단계) | consume, enqueue `compliance.check` | - |
| POST `/api/uploads/[id]/acknowledge` | member+ | `{note?}` | upload(approved) | 0 | `video.acknowledge_compliance_warning` | VD011, VD008 |
| POST `/api/uploads/[id]/schedule` | member+ | `{scheduledAt}` | upload(scheduled) | 1/채널 | consume, enqueue `upload.<platform>`(run_after) | VD008 |
| POST `/api/uploads/[id]/cancel` | member+ | - | upload | 환불 | `video.cancel_upload` | VD008 |
| GET/POST `/api/affiliate/accounts` | owner/admin | `{provider, partnerId?, apiKey?, secretKey?}` | 계정 | 0 | credential INSERT + affiliate_accounts INSERT(service) | 422 |
| GET `/api/affiliate/search` | member+ | `{provider='coupang', q}` | 상품 | 0 | 어댑터 | 501(capability 없음) |
| POST `/api/affiliate/links` | member+ | `{provider, product{name, productUrl}, affiliateUrl?(수동 제공자), sourceRef}` | `{shortCode, shortUrl}` | 0 | `new_affiliate_short_code`, affiliate_links INSERT | 422 |
| PUT `/api/affiliate/disclosures` | owner/admin | `{provider, placement, body(>=10자)}` | 문구 | 0 | `upsert_affiliate_disclosure` | 22023 |
| PATCH `/api/landings/[id]` | member+ | `{productName?, headline?, features?}` | 랜딩 | 0 | RLS update | 23514 |
| POST `/api/landings/[id]/status` | member+ | `{status}` | 랜딩 | 0 | `video.set_landing_status` | VD001, VD009 |
| GET `/r/[code]` | 공개 | - | 302 | 0 | `rate_limit`, `record_affiliate_click`(service) | 404 → `/` |
| GET `/landing/[slug]` (페이지) | 공개 | - | ISR 3600초 | 0 | `video.get_public_landing`(anon), `video.record_landing_view`(service, IP 해시 10분 1회) | 404 |
| GET `/lb/[handle]` (페이지) | 공개 | - | ISR 300초(제안) | 0 | `video.get_public_linkinbio`(anon) | 404 |
| GET `/api/analytics` | 전 역할 | `{from, to, channelId?}` | 집계 | 0 | RLS select | - |
| POST `/api/webhooks/toss` | 공개(서명) | rawBody | 200 | - | `webhook_events` | 401 |
| POST `/api/webhooks/fal` | 공개(서명 미확인, request_id 대조) | rawBody | 200 | - | `webhook_events`, 잡 갱신 | 401 |

## 3. RPC (SECURITY DEFINER)

제품 스키마 함수(`docs/products/_supabase-modular/migrations/1200_video.sql`). 코어 RPC는 CORE_SPEC 인용만.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `video.org_has_feature(p_org uuid, p_key text, p_value text default null)` | authenticated, service_role | 비멤버면 false(`is_service_caller` 또는 `is_org_member`) | boolean | - |
| `video.plan_features(p_org uuid)` | service_role | EXECUTE만 | jsonb | 42501 |
| `video.update_channel_settings(p_channel_id, p_role, p_target_language, p_target_country, p_status)` | authenticated | `is_service_caller` 또는 `has_org_role(owner,admin)`, 엔타이틀먼트, status는 active/paused만, 전이 트리거, 채널 한도 트리거 | `video.channels` | P0002, 42501, 22023, VD003 |
| `video.disconnect_channel(p_channel_id)` | authenticated | owner/admin. `core.revoke_credential` 호출 | `video.channels` | P0002, 42501 |
| `video.acknowledge_compliance_warning(p_upload_id, p_note)` | authenticated | owner/admin/member, 상태 awaiting_confirm, 최신 verdict warn, 감사 `upload.compliance_ack` | `video.uploads` | P0002, 42501, VD008, VD011 |
| `video.cancel_upload(p_upload_id)` | authenticated | owner/admin/member, 상태 허용 목록, queued 잡은 `core.cancel_job`, running이면 거부 | `video.uploads` | P0002, 42501, VD008 |
| `video.set_landing_status(p_landing_id, p_status)` | authenticated | owner/admin/member, 공개 시 `coupang_landing` + 제휴 링크 필수 | `video.landing_pages` | P0002, 42501, 22023, VD001, VD009 |
| `video.set_music_distribution_status(p_track_id, p_status, p_note, p_isrc)` | authenticated | owner/admin/member, 사용자는 submitted/live/rejected/takedown만, 전이 트리거 | `video.music_tracks` | P0002, 42501, 22023 |
| `video.get_public_landing(p_slug)` | anon, authenticated | published + 엔타이틀먼트. 공개 컬럼과 단축 코드, 대가성 문구만 | jsonb 또는 null | - |
| `video.get_public_linkinbio(p_handle)` | anon, authenticated | is_published + 엔타이틀먼트. 활성 항목, 공개 랜딩, 활성 링크만 | jsonb 또는 null | - |
| `video.purge_expired_sources(p_limit)` | service_role | `is_privileged_session`(EXECUTE가 1차 잠금) | `(source_id, org_id, storage_path)` | 42501 |
| `video.reset_channel_quotas()` | service_role | 같음 | integer | 42501 |
| `video.record_landing_view(p_slug)` | service_role | 같음 | void | 42501 |

사용하는 코어 RPC: `session_context`, `bootstrap_app_for_org`, `consume_credits`, `grant_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `reap_stale_jobs`, `confirm_payment_order`, `apply_subscription_transition`, `expire_stale_payment_orders`, `create_oauth_state`, `consume_oauth_state`, `revoke_credential`, `write_audit`, `new_affiliate_short_code`, `record_affiliate_click`, `effective_disclosure`, `upsert_affiliate_disclosure`, `run_monthly_credit_grants`(CORE_SPEC 1.3 표).

## 4. 잡 페이로드 계약

공통: 비밀값을 payload에 넣지 않고 `credential_id`만. 경로는 Storage 경로(`video-media/<org_id>/video/<entity>/<uuid>.<ext>`). 진행률 메시지는 `heartbeat_job(p_progress 0~100, p_message)`.

| `job_type` | payload | result | progress 메시지 예 |
|---|---|---|---|
| `production.run` | `{production_id, track, mode, source_id?, topic?, languages[], options{silence_cut, layer_composite, watermark}, voice{provider, voice_id_by_lang}}` | `{outputs: [{language, output_id, status}], refunded_credits}` | `"stt"`, `"translate:JA"`, `"encode:KO"` |
| `source.download` | `{source_id, url, platform}` | `{storage_path, duration_sec, phash, likes_count, title_original}` | `"download 40%"` |
| `media.stt` | `{input_path, language_hint?: 'zh'|'ko'|'en'|'ja', word_timestamps: true}` | `{segments: [{start, end, text}], language, transcript_path}` | `"whisper 60%"` |
| `media.separate` | `{input_path}` | `{vocals_path, accompaniment_path}` | - |
| `media.silence_cut` | `{input_path, threshold_db: -30, min_silence_sec: 0.5}` | `{output_path, removed_sec, cut_map: [[start,end]]}` | - |
| `media.compose` | `{video_path, audio_path, ass_path, emphasis_ass_path?, reaction_layer?, template_path?, watermark: bool, size: '1080x1920'|'1920x1080'}` | `{output_path}` | - |
| `media.encode` | `{input_path, preset: 'short'|'longform', fps: 30|60}` | `{output_path, duration_sec, bytes}` | - |
| `media.kenburns` | `{images: [{path, duration_sec}], size}` | `{output_path}` | - |
| `media.watermark_remove` | `{input_path, region?}` | `{output_path}` | - |
| `media.loop` | `{audio_path, image_path, size: '1920x1080'}` | `{output_path, duration_sec}` | - |
| `media.playlist_concat` | `{items: [{audio_path, duration_sec}], image_path, crossfade_sec: 2, target_sec}` | `{output_path, timestamps: [{position, start_sec}]}` | `"concat 12/20"` |
| `media.highlight_cut` | `{input_path, start_sec, end_sec, reframe: '9:16'}` | `{output_path}` | - |
| `ai.translate` | `{segments, source_lang, target_lang, tone: 'dopamine'|'reviewer'|'neutral'}` | `{segments}` | - |
| `ai.script` | `{track, topic, structure: {hook:15, body:30, cta:5}}` 또는 `{longform_id}` | `{script}` 또는 `{sections: 10}` | - |
| `ai.tts` | `{text_segments, language, provider: 'elevenlabs'|'openai', voice_id}` | `{audio_path, duration_sec}` | - |
| `ai.image` | `{prompts: [], size, model: 'flux-pro'|'flux-ultra'}` | `{image_paths: []}` | - |
| `longform.render` | `{longform_id, languages[]}` | `{outputs: [{language, output_id}]}` | `"section 4/10"` |
| `longform.highlights` | `{longform_id, output_id}` | `{highlights: [{rank, start_sec, end_sec, output_id}]}` | - |
| `music.generate` | `{music_track_id, genre, prompt, mood?, bpm?}` | `{audio_path, cover_path, output_id, duration_sec}` | - |
| `music.package` | `{music_track_id}` | `{package_path}` | - |
| `playlist.render` | `{playlist_id}` | `{output_id, tracklist: [{position, title, start_sec}], pinned_comment_body, thumbnail_path}` | - |
| `compliance.check` | `{upload_id, platform, title, description, tags, transcript_path?, llm: bool}` | `{compliance_check_id, verdict}` | - |
| `upload.youtube` 등 | SHARED_MODULES 11장 `UploadInput` + `{upload_id}` | `UploadResult` + `{pinned: bool}` | `"upload 55%"` |
| `radar.playboard` | `{countries: ['KR','US','JP'], periods}` | `{inserted}` | - |
| `radar.channel_finder` / `radar.bling` | `{report_id, params}` | `{report_id}` | - |
| `analytics.sync` | `{org_id?}` | `{snapshots}` | - |

## 5. 웹훅

| 수신 | 서명 방식 | event_id | 처리 |
|---|---|---|---|
| Toss | 코어 webhooks(서명 방식은 Toss 문서 기준, 미확인) | paymentKey+status+시각 해시 | 상태 동기화만, 지급은 confirm 경로 |
| fal | 미확인. 확인 전에는 `request_id`가 우리 잡의 것인지 대조 | `request_id` | 이미지 단계 완료 → 결과를 `video-media`로 복사 |
| Suno | 콜백 지원 여부 미확인. 기본은 폴링 | task id | 곡 단계 완료 |
| Distrokid(Phase 2) | 서명 필수(없으면 연동하지 않음, SM #16) | 제공자 id | 유통 상태 갱신 |
| Make/n8n 콜백(Phase 2) | HMAC-SHA256 필수(automation-core) | `X-Request-Id` | 플로우 잡 상태 |

발신(Phase 2, automation-core): `production.completed`, `upload.published`, `playlist.ready`, `music.ready`. HMAC-SHA256(`timestamp.rawBody`).

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터·비고 |
|---|---|---|---|
| YouTube Data API v3 | `packages/sns-uploader/src/youtube` | 재시도 3회, 토큰 갱신 1회 실패 시 `credentials.status=error`와 재연결 요청, 쿼터 초과 → 대체 채널 → 재예약 | 채널 기본 10,000 units/day(ADD:155), 업로드 1건 단위 비용은 미확인 |
| YouTube Analytics API | orchestrator `analytics` | 일 1회, 실패 시 다음 날 | - |
| Meta Graph(IG Reels, Threads) | `sns-uploader/src/meta` | 재시도 3회 | 앱 심사 일정 별도 |
| TikTok Content Posting | `sns-uploader/src/tiktok` | 재시도 3회 | 앱 감사 필요(MA:607) |
| DeepL / ElevenLabs / OpenAI TTS | orchestrator steps | 폴백 제공자 1회 → 실패 | - |
| fal | 공용 fal client | 30분 미도착 실패, 환불 | `enable_safety_checker=true` |
| Suno | orchestrator `music` | 실패 시 환불 | 공식 API 미확인 |
| 쿠팡파트너스 | 공용 affiliate 어댑터 | 링크 없이 업로드 진행(문구도 미삽입) | HMAC 키는 `encrypted_credentials` |
| 텐핑, 네이버쇼핑 커넥트 | 공용 affiliate 어댑터(수동 등록 capability) | - | 공개 API 미확인. YSM CLAUDE의 엔드포인트 명세(`git show 5f6d262:Youtube_shots_Maker/CLAUDE.md` 852-866행)는 검증되지 않은 설계라 쓰지 않는다 |
| SerpApi, RapidAPI, Google Trends | orchestrator `radar` | 실패 시 이전 스냅샷 유지, 난수 대체 금지 | 프록시 풀 경유(소싱·스크래핑만) |
| Toss | 코어 toss | CORE_SPEC 5장 | - |

## 7. 오류 코드

| 코드 | 의미 | HTTP |
|---|---|---|
| VD001 | 필요한 연결 없음(랜딩 공개에 제휴 링크 없음 등) | 409 |
| VD002 | 참조 대상 조직 불일치 | 403 |
| VD003 | YouTube 채널 한도 초과 또는 엔타이틀먼트 없음 | 409 |
| VD004 | 플랜에 없는 플랫폼 | 403 |
| VD005 | 상태 잠금으로 편집 불가 | 409 |
| VD006 | 플리 곡 출처 부적합(미완성, 라이선스 만료, 수익화 불가) | 422 |
| VD007 | 제휴 링크와 대가성 문구 불일치 | 422 |
| VD008 | 업로드 상태에서 허용되지 않는 동작 | 409 |
| VD009 | 플랜 기능 없음(Track, 랜딩 등) | 403 |
| VD010 | 주제 점수 60 미만 | 409 |
| VD011 | compliance 게이트 미충족(FAIL 또는 WARN 미확인) | 409 |
| VD012 | 월 한도 초과(블링 등) | 429 |
| 22023 | 상태 전이 위반, 인자 오류 | 409 |
| 23514 | CHECK 위반(대가성 문구, 출처 없는 블링 등) | 422 |
| 코어 코드 | `42501`→403, `CR001`→402, `P0002`/`PM404`→404, `SB001`/`JB002`/`PM410`→409, `PM001`/`PM409`→409+운영 알림, `OA001`→400 | CORE_SPEC 15장 |
