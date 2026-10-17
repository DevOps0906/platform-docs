# 05 데이터 모델: SceneFlow (sceneflow)

2026-10-13 개정: AI·음성은 코어 `core.ai_*`, `core.wiki_*`, `core.voice_*`를 그대로 쓰고 제품 전용 AI 테이블을 만들지 않았다(6절). 1200 조각에는 11절(AI·음성 기본값: 라우팅 17행, 플랜 AI 키, 체인 검사)만 추가했고 `video` 테이블 22개와 정책은 그대로다.

정본 SQL: `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1200_video.sql`(아래 `1200:`으로 인용). 모놀리스 변환본: `supabase/monolith/migrations/0002_video_domain.sql`.

## 1. 개요와 ERD

```
core.organizations (참조만)
 ├─ video.channels ─────────── core.encrypted_credentials (credential_id)
 ├─ video.radar_reports         video.trend_videos (조직 없음, 플랫폼 공용)
 ├─ video.sources ──────────── video.trend_videos, core.jobs
 │    └─ video.productions (A/B/C) ── core.jobs(root), core.credit_ledger
 ├─ video.longform_projects (D)
 │    ├─ video.longform_sections (1..10)
 │    └─ video.longform_highlights (1..3, OSMU)
 ├─ video.music_tracks (E, 관리 단위 = 곡)
 ├─ video.music_library (F용 라이선스 곡)
 ├─ video.playlists (F, 관리 단위 = 플리)
 │    └─ video.playlist_items ── music_tracks | music_library (정확히 하나)
 ├─ video.outputs ── productions | longform_projects | longform_highlights | music_tracks | playlists (정확히 하나)
 │    └─ video.uploads ── video.channels, core.jobs
 │         ├─ video.upload_links ── core.affiliate_links
 │         ├─ video.compliance_checks
 │         └─ video.analytics_snapshots
 ├─ video.landing_pages ── core.affiliate_links (primary, related[])
 ├─ video.linkinbio_profiles
 │    └─ video.linkinbio_items ── landing_pages | core.affiliate_links
 ├─ video.workflows (Phase 2 저장)
 ├─ video.banned_words
 └─ video.clients (대행 고객, 2026-10-13)
      ├─ video.client_channels ── video.channels (채널당 고객 1)
      ├─ video.client_reviews ── video.uploads (고객 승인, 토큰 해시)
      └─ video.client_reports (월 1행, PDF)
video.productions.client_id → video.clients, video.uploads.brandconnect_application_id → core.brandconnect_applications
Storage: video-media 버킷(제품 소유, 서버 쓰기만), core org-files/exports/public-assets
```

## 2. 테이블

표준 컬럼(DB_CONVENTIONS 3장): 모든 테넌트 테이블은 `id uuid`(로그성은 identity), `org_id`(cascade), `created_at`. UPDATE가 있는 테이블은 `updated_at` + `core.set_updated_at` 트리거(1200:836-846). 상태는 text + CHECK.

### 2.1 channels (1200:341)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| platform | text | N | - | youtube/instagram/tiktok/threads/naver_clip(2026-10-13) |
| credential_id | uuid | Y | - | `core.encrypted_credentials`. 평문 토큰 컬럼 없음 |
| external_channel_id, name, handle | text | N/Y/Y | - | 플랫폼 식별자 |
| role | text | N | main | main/commerce/trend/longform/lofi/playlist/insurance(E=lofi, F=playlist 분리) |
| target_language / target_country | text | N | KO / KR | 원본 ja_group/en_group 역할을 언어 컬럼으로 대체 |
| daily_quota_units / quota_used_today / quota_reset_at | int/int/tstz | N/N/Y | 10000 / 0 | YouTube 쿼터 |
| status | text | N | active | active/paused/error/revoked |
| last_error, created_by, updated_at | - | - | - | - |
| automation_consent_version / automation_consented_at / automation_consented_by | text/tstz/uuid | Y | - | 브라우저 자동화 채널(naver_clip) 위험 동의. `video.consent_clip_automation_risk`만 쓴다. 둘 다 null이거나 둘 다 값(CHECK `channels_automation_consent_check`). 버전이 `video.clip_notice_version()`과 다르면 업로드 INSERT VD015 |

제약: `unique(org_id, platform, external_channel_id)`. 쓰기: service_role + RPC.

### 2.2 trend_videos (1200:367) — 조직 없음

| 이름 | 타입 | 설명 |
|---|---|---|
| id | bigint identity | - |
| source | text | playboard/serpapi/tiktok/google_trends/youtube_api |
| country / period / category / rank | text/text/text/int | KR/US/JP, realtime/daily/weekly |
| external_video_id, title, channel_external_id | text | - |
| views, views_24h | bigint | - |
| growth_rate | numeric NULL | 계산 불가면 null(난수 금지) |
| weighted_score | numeric | - |
| is_estimated | boolean | 추정치 표시 |
| collected_at | timestamptz | - |

### 2.3 radar_reports (1200:388)

kind(channel_finder/bling/topic_score), params, result, citations(jsonb 배열, bling은 1개 이상 CHECK), trend_score 0~100, credit_ledger_id, created_by. append-only.

### 2.4 sources (1200:404)

track(A/B/C), platform(douyin/xiaohongshu/youtube/tiktok), source_url(https만), external_video_id, title_original, thumbnail_url, likes_count, duration_sec, rights_basis(public_free/creative_commons/licensed/own, 필수), rights_note, phash, storage_path, status(requested/downloading/ready/failed/purged), trend_video_id, job_id, downloaded_at, purge_after, purged_at, last_error. 부분 유니크 `(org_id, platform, external_video_id)`.

### 2.5 productions (1200:436)

| 이름 | 타입 | 설명 |
|---|---|---|
| track / mode | text | A/B/C, C만 mode(ai_generate/re_edit) 필수(CHECK) |
| source_id / topic / topic_score | uuid/text/int | - |
| languages | text[] | 1~3개, KO/JA/EN 부분집합 |
| options | jsonb | silence_cut, layer_composite, voice(`{provider, voice_id_by_lang}`: 작업 시작 때 고정된 제공자·보이스, 02장 5.3절 같은 목소리 규칙), script(`{mode, script_run_id?}`) |
| watermark | boolean | 렌더 워커가 플랜으로 설정 |
| status | text | queued/processing/partial/ready/failed/canceled |
| root_job_id / credit_ledger_id | uuid/bigint | `core.jobs`, `core.credit_ledger` |
| credits_charged / credits_refunded | int | refunded <= charged CHECK |
| request_id | uuid unique | 멱등 |
| client_id | uuid | 대행 고객(`video.clients`, on delete set null). 같은 조직 검사(VD002) |
| started_at / finished_at / last_error | - | - |

### 2.6 longform_projects (1200:467)

title(1~200자), category(knowledge/radio/viral_remake), topic, topic_score, languages, storyline, target_minutes(3~60, 기본 10), status(draft/storyboard/generating/review/encoding/ready/failed/canceled), root_job_id, credit_ledger_id, created_by(default `auth.uid()`). 사용자 편집 컬럼: title, category, topic, languages, storyline, target_minutes.

### 2.7 longform_sections (1200:490)

longform_id, position(1~10, `unique(longform_id, position)`), heading, script(jsonb 언어별), image_prompt, image_path, clip_path, narration_paths, duration_sec, status(draft/image_pending/image_ready/failed). `narration_paths` jsonb 규약(2026-10-13, 서버 쓰기 전용 컬럼이며 사용자 GRANT에 없음, `1200_video.sql:948-949`): `{"KO": {"path": "...", "provider": "oss-voice", "voice_id": "...", "voice_job_id": "..."}}`. 첫 섹션의 provider·voice_id가 그 언어의 같은 목소리 기준이다(DB 제약 없음, 앱 규칙과 테스트로 보장). 원본의 sections jsonb 통째 갱신(BS #20)을 정규화로 대체.

### 2.8 longform_highlights (1200:510)

longform_id, rank(1~3 유니크), start_sec, end_sec(`end>start`, 길이 60초 이하), reason, status(proposed/rendering/ready/failed).

### 2.9 music_tracks (1200:527) — Track E

title, genre(lofi/chill/ambient/white_noise), prompt, mood, bpm(40~200), rights_basis(suno_generated만), provider_task_id, audio_path, cover_path, duration_sec, status(requested/generating/ready/failed/archived), distribution_status(none/packaged/submitted/live/rejected/takedown), distribution_note, isrc(형식 CHECK), package_path, distributed_at, job_id, credit_ledger_id, request_id unique.

### 2.10 music_library (1200:558) — Track F 라이선스 곡

title, artist, license_type(purchased/royalty_free/commissioned/cc_by), license_source, license_proof_path(필수), license_expires_at, youtube_monetization_allowed(필수), attribution_text(cc_by면 필수), audio_path(필수), duration_sec, status(active/expired/revoked).

### 2.11 playlists (1200:581) — Track F

title, mood(cafe/drive/study/sleep/work/rain/healing/workout/other), target_duration_min(30/60/180), language, visual_style, cover_prompt, description_body, pinned_comment_body, tracklist(jsonb), thumbnail_path, status(draft/rendering/ready/failed/canceled), root_job_id, credit_ledger_id.

### 2.12 playlist_items (1200:606)

playlist_id, position(>=1, `unique(playlist_id, position) deferrable initially deferred`로 재정렬 허용), music_track_id 또는 library_track_id(정확히 하나 CHECK), start_sec, duration_sec.

### 2.13 outputs (1200:622)

kind(short/longform/highlight/music_loop/playlist), 소유 FK 5개 중 정확히 하나(CHECK)와 kind 일치, language, aspect(9:16/16:9), video_path, thumbnail_path, duration_sec, title, description_body(문구 삽입 전 본문), tags, watermark, status(pending/ready/failed/purged). 부분 유니크 `(production_id, language)`.

### 2.14 landing_pages (1200:656)

production_id, slug(유니크, `^[a-z0-9][a-z0-9-]{2,63}$`), product_name, headline, features(배열 3개 이하), youtube_video_id, primary_link_id, related_link_ids(3개 이하), status(draft/published/unpublished), view_count, published_at.

### 2.15 linkinbio_profiles / linkinbio_items (1200:680, :694)

프로필: org_id 유니크(조직당 1개), handle(유니크, 예약어 제외 CHECK), display_name, bio(300자), avatar_path, is_published. 항목: profile_id, kind(link/landing/affiliate/video)와 대상 컬럼 일치 CHECK, title, url(https만), landing_page_id, affiliate_link_id, position, is_active.

### 2.16 uploads (1200:715)

| 이름 | 타입 | 설명 |
|---|---|---|
| output_id / channel_id / platform / language | - | 출력물, 채널(플랫폼 일치·활성 트리거 검사) |
| title(1~100자) / description / pinned_comment / tags / visibility | - | 최종 게시 문구(대가성 문구 포함) |
| scheduled_at | tstz | 예약 |
| paid_promotion | boolean | 기본 false. 자동 설정은 제안 단계 |
| has_affiliate / disclosure_description / disclosure_pinned | bool/text/text | 대가성 문구 강제 CHECK `uploads_disclosure_check` |
| disclosure_title / disclosure_hashtag | text/text | naver_clip 전용: 코어 `video_description` 배치 문구를 `injectDisclosure(target 'title_hashtag')`로 제목 앞·첫 해시태그에 넣은 값. CHECK가 `starts_with(title, disclosure_title)`, `tags[1] = disclosure_hashtag` 확인 |
| brandconnect_application_id | uuid | 선정된 브랜드커넥트 지원서(`core.brandconnect_applications`). 값이 있으면 제휴 링크가 없어도 대가성 문구 필수 |
| status | text | draft/checking/blocked/awaiting_confirm/approved/client_review/scheduled/uploading/published/failed/canceled |
| compliance_check_id / compliance_ack_by / compliance_ack_at | - | 게이트 |
| job_id / credit_ledger_id / platform_post_id / post_url / published_at / attempts / last_error / request_id | - | `unique(channel_id, platform_post_id)`로 중복 발행 방지 |

### 2.17 upload_links (1200:761), compliance_checks (1200:773), analytics_snapshots (1200:795)

upload_links: upload_id, link_id(`core.affiliate_links`), placement(video_description/video_pinned_comment), position. compliance_checks: upload_id, verdict(pass/warn/fail), stages, issues, suggestions, llm_failed, usage_id(`core.ai_usage`), credit_ledger_id. analytics_snapshots: upload_id, captured_at, views, likes, comments, watch_time_sec, `unique(upload_id, captured_at)`.

### 2.18 workflows (1200:809), banned_words (1200:822)

workflows: name, graph(nodes·edges 배열 CHECK), is_active(사용자 GRANT 없음, Phase 2). banned_words: word(1~60자), severity(warn/fail), `unique(org_id, word)`.

대가성 문구 CHECK 규칙(`has_affiliate or brandconnect_application_id is not null`일 때):

| 플랫폼 | 필수 |
|---|---|
| naver_clip | `disclosure_title`(2자 이상)로 제목 시작 + `tags[1] = disclosure_hashtag` + `disclosure_description`(10자 이상)으로 설명 시작. 고정 댓글 없음 |
| 그 외 | 설명란 첫 줄(`disclosure_description`) + 고정 댓글 첫 줄(`disclosure_pinned`), 각 10자 이상(기존 규칙) |

### 2.19 clients (대행 고객, VD-F-120)

| 이름 | 타입 | 설명 |
|---|---|---|
| name(1~120자) / brand_name / business_no | text | `unique(org_id, name)` |
| contact_name / contact_email / contact_phone | text | 고객 담당자(승인 메일·리포트 수신). 개인정보: 계약 종료 후 1년 보존(제안) |
| brand_guide_path / brand_wiki_ref | text | 브랜드 가이드 원본(org-files) / 위키 문서 키(VD-F-122) |
| package_code | text | produce / produce_upload / full_ops(`08_AGENCY_OPERATIONS.md` 2장) |
| contract_start / contract_end | date | end >= start CHECK |
| monthly_quota | int | 월 편수(업로드 준수율 분모) |
| review_required | bool | 기본 true. true면 고객 채널 업로드는 고객 승인 뒤에만 예약(VD016) |
| report_day | int | 1~28, 리포트 생성일 |
| status | text | active/paused/ended. `set_client_status` RPC로만 |

### 2.20 client_channels (VD-F-121)

client_id, channel_id, ownership(client/agency). `unique(channel_id)`: 채널 하나는 고객 하나에만. 고객·채널 모두 같은 조직(VD002).

### 2.21 client_reviews (VD-F-123)

| 이름 | 타입 | 설명 |
|---|---|---|
| client_id / upload_id | uuid | 같은 조직(VD002) |
| token_hash | text unique | sha256 hex 64자. 원문 토큰은 저장하지 않는다. 사용자 SELECT 컬럼에서 제외 |
| expires_at | tstz | 요청 시각 + 1~336시간(기본 72) |
| decision | text | pending/approved/changes_requested/expired/canceled. 업로드당 pending 1개(부분 unique 인덱스) |
| reviewer_name / comment(<=2000자) / decided_at / requested_by | - | 고객 입력과 감사 |

### 2.22 client_reports (VD-F-124)

client_id, period_month(월 첫날만 CHECK), kpis jsonb(`views`, `watch_time_sec`, `likes`, `comments`, `uploads_published`, `upload_adherence`, `subscriber_gain`(수집 플랫폼만), `completion_rate`(제공 플랫폼만, 없으면 null = "미제공"), `affiliate_clicks`, `top`/`bottom` 업로드 id 3개), summary, pdf_path(core exports 버킷), status(generating/ready/failed/sent), job_id, sent_at. `unique(client_id, period_month)`. 쓰기 service_role만.

## 3. 상태 전이

모두 `video.enforce_status_transition()`(1200:103-138) 트리거. 허용 쌍 외에는 22023이며 service_role 쓰기에도 적용된다.

| 테이블.컬럼 | 현재 → 허용 | 누가 | 부수 효과 |
|---|---|---|---|
| channels.status | active→paused/error/revoked, paused→active/error/revoked, error→active/revoked | owner/admin RPC, 서버(토큰 오류) | active 진입 시 채널 한도 트리거 |
| sources.status | requested→downloading/failed, downloading→ready/failed, failed→requested, ready→purged | 서버 | ready 시 `purge_after=now()+24h` |
| productions.status | queued→processing/failed/canceled, processing→ready/partial/failed/canceled | 서버 | failed/canceled 시 잡 자동 환불 |
| outputs.status | pending→ready/failed, failed→pending, ready→purged | 서버 | - |
| longform_projects.status | draft→storyboard/canceled, storyboard→draft/generating/canceled, generating→review/failed/canceled, review→storyboard/encoding, encoding→ready/failed, failed→storyboard | 서버 | 사용자 편집은 draft/storyboard/review에서만(VD005) |
| longform_sections.status | draft→image_pending, image_pending→image_ready/failed, image_ready→image_pending, failed→image_pending | 서버 | - |
| longform_highlights.status | proposed→rendering, rendering→ready/failed, failed→rendering | 서버 | - |
| music_tracks.status | requested→generating/failed, generating→ready/failed, failed→requested, ready→archived | 서버 | - |
| music_tracks.distribution_status | none→packaged, packaged→submitted/none, submitted→live/rejected, rejected→packaged, live→takedown | 서버(packaged), 사용자 RPC(나머지) | 감사 기록 |
| music_library.status | active→expired/revoked, expired→active/revoked | 서버 | 만료 곡은 플리 추가 불가(VD006) |
| playlists.status | draft→rendering/canceled, rendering→ready/failed/draft, failed→draft, ready→draft | 서버 | 사용자 편집은 draft에서만 |
| landing_pages.status | draft→published, published→unpublished, unpublished→published/draft | 사용자 RPC | 공개 조건 검사 + 감사 |
| uploads.status | draft→checking/canceled, checking→blocked/awaiting_confirm/approved/draft, blocked→draft/canceled, awaiting_confirm→approved/draft/canceled, approved→client_review/scheduled/canceled, client_review→scheduled/draft/canceled, scheduled→uploading/canceled, uploading→published/failed/scheduled, failed→scheduled/canceled | 서버, 사용자 RPC(확인·취소), 고객 결정(service) | approved 진입은 compliance 게이트(VD011). 고객 채널(`review_required`)은 approved→scheduled 금지, client_review→scheduled는 approved 결정이 있어야(VD016). 취소 시 queued 잡 취소·환불 |
| clients.status | active→paused/ended, paused→active/ended | owner/admin RPC | 감사 `client.status` |
| client_reviews.decision | pending→approved/changes_requested/expired/canceled | 서버(고객 결정·만료·재요청) | changes_requested면 업로드 → draft |
| client_reports.status | generating→ready/failed, failed→generating, ready→sent/generating | 서버 | sent는 감사 `client_report.sent` |

## 4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| channels, radar_reports, sources, productions, longform_highlights, outputs, uploads, upload_links, compliance_checks, analytics_snapshots | `is_org_member(org_id) and has_entitlement(org_id,'video')` | 없음 | 없음 | 없음 | select. 이중 잠금 `guard_privileged_write` |
| trend_videos | `exists(current_org_ids() o where org_has_feature(o,'radar','playboard'))` | 없음 | 없음 | 없음 | select + guard |
| longform_projects | 멤버+엔타이틀먼트 | `has_org_role(owner,admin,member)` + 엔타이틀먼트 + `org_has_feature(org,'tracks','D')` | 같은 역할, using/with check | owner/admin | insert/update 컬럼 단위, delete |
| longform_sections | 같음 | 역할 + Track D | 역할 | owner/admin | 컬럼 단위 |
| music_tracks | 같음 | 없음 | 역할(title만) | 없음 | update(title) |
| music_library | 같음 | 역할 + Track F | 역할 | owner/admin | 컬럼 단위 |
| playlists, playlist_items | 같음 | 역할 + Track F | 역할 | owner/admin | 컬럼 단위 |
| landing_pages | 같음 | 없음(서버 생성) | 역할(product_name, headline, features) | 없음 | update 컬럼 |
| linkinbio_profiles | 같음 | owner/admin | owner/admin | owner/admin | 컬럼 단위 |
| linkinbio_items, workflows | 같음 | 역할 | 역할 | owner/admin | 컬럼 단위 |
| banned_words | 같음 | 역할 | 없음 | owner/admin | insert 컬럼, delete |
| clients | 같음 | owner/admin + `org_has_feature(org,'agency')` | 같음 | owner/admin | insert/update 컬럼 단위(status 제외), delete |
| client_channels | 같음 | owner/admin + agency | 없음 | owner/admin | insert 컬럼, delete |
| client_reviews | 같음(컬럼 단위 SELECT, `token_hash` 제외) | 없음 | 없음 | 없음 | select 컬럼 + guard |
| client_reports | 같음 | 없음 | 없음 | 없음 | select + guard |
| storage `video-media` | 멤버 + 엔타이틀먼트(`storage_org_id(name)`) | 없음(서버) | 없음 | 없음 | - |

쓰기 정책을 준 테이블의 조건 충족(SECURITY_BASELINE 4장): (a) 모든 쓰기 정책에 `with check`, (b) 돈·권한·상태 컬럼은 컬럼 GRANT에서 제외(status, credit_ledger_id, root_job_id, is_active, view_count 등. 스모크 테스트에서 `status` 지정 INSERT 42501 확인), (c) 상태는 전이 트리거, 부모 상태 잠금은 `guard_user_edit`(1200:140), 교차 조직 참조는 `check_refs`(1200:178)가 VD002로 거부. viewer는 쓰기 불가.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `channels_pick_idx (org_id, platform, target_language, role) where status='active'` | 대체 채널 선택 |
| `trend_videos_lookup_idx (country, period, collected_at desc, weighted_score desc)` | 레이더 랭킹 |
| `radar_reports_org_idx (org_id, kind, created_at desc)` | 블링 월 사용량 집계 |
| `sources_dedup_uniq`, `sources_phash_idx`, `sources_purge_idx (purge_after) where status='ready'` | 중복 차단, 24시간 삭제 |
| `productions_org_idx`, `productions_status_idx` | 목록, 동시 생산 수 |
| `outputs_short_lang_uniq`, `outputs_org_idx` | 언어판 조회 |
| `uploads_due_idx (scheduled_at) where status='scheduled'` | 예약 발행 스캔(10분) |
| `compliance_checks_upload_idx`, `analytics_snapshots_org_idx`, `linkinbio_items_profile_idx`, `landing_pages_org_idx` | 상세·대시보드 |

예상 규모(제안): 조직당 월 업로드 1,000건, 스냅샷 하루 1행/업로드. analytics_snapshots는 1년 보존 후 월 파티션 검토.

## 6. 코어 참조

| core 객체 | 용도 | ALTER |
|---|---|---|
| `organizations` | 모든 테넌트 FK | 안 함 |
| `apps`, `plans`, `app_entitlements` | `video` 등록(1200:30), features 판정 | 안 함 |
| `credit_ledger` | 생산·플리·곡·검사 원장 연결 | 안 함 |
| `jobs` | 루트/자식 잡, 소스·곡·업로드 잡 | 안 함 |
| `encrypted_credentials`, `revoke_credential` | 채널 토큰 | 안 함 |
| `affiliate_links`, `affiliate_disclosures` | 업로드·랜딩·링크인바이오 | 안 함 |
| `is_org_member`, `has_org_role`, `has_entitlement`, `current_org_ids`, `is_service_caller`, `is_privileged_session`(service 전용 함수만), `write_audit`, `set_updated_at`, `guard_privileged_write`, `cancel_job`, `storage_org_id` | 정책·함수·트리거 | 안 함 |

AI·음성 코어 객체(2026-10-13, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`). 모두 참조만 하고 ALTER하지 않는다.

| core 객체 | video 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 채널 코치 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `video.script`·`video.step` 실행 기록(입력은 요약만, `input` jsonb에 비밀 금지), 위키 lint 결과. 정밀 모드 interrupt 대기 중 run은 `running`이고 마지막 완료 노드가 `plan` | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`). 미디어 워커의 Whisper STT도 kind `stt`, provider `oss-voice`, feature `video.stt`로 직접 기록 | FastAPI, Next.js 음성, 오케스트레이터 TTS, 미디어 워커(service_role), 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 17행(9절), 경로 결정 | seed, FastAPI, Next.js 음성, 오케스트레이터 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 운영자 지식 조직(`VIDEO_KNOWLEDGE_ORG_ID`)의 `video-trends`·`video-guide`, 각 조직의 `video-performance`·`video-scripts`·`video-brand` | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 조직별 채널·브랜드 가이드 위키, 운영자 가이드 | FastAPI(쓰기), Next.js(읽기는 RLS) |
| `voice_sessions`, `voice_jobs` | 음성 대화·받아쓰기·샘플·내레이션 작업. 내레이션은 구간마다 1행(provider, voice_id, characters) | Next.js, 오케스트레이터 |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |

제품 AI 표를 만들지 않은 이유(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 대화-채널/업로드 연결 표 | 채팅이 어느 채널·업로드를 맥락으로 하는지 | Dify 입력 `context_ref`(`channel:<uuid>` 등 비밀이 아닌 식별자, 대화 시작 때만) + FastAPI가 매핑 org와 대상 org를 매번 대조. 대체 경로는 Next.js가 요청마다 `context_ref`를 받아 같은 확인. `ai_conversations`에는 컨텍스트 컬럼이 없다(`0008_core_ai.sql:205-220`) |
| 보이스 선택 저장 | 작업별 제공자·보이스 고정 | `productions.options.voice`(기존 jsonb), `longform_sections.narration_paths`(기존 jsonb), `voice_jobs.provider_id`·`voice_id` |
| 대본 그래프 결과 | 정밀 모드 기획안·대본 보관 | `ai_runs.output`(jsonb), 확정된 대본은 기존 `longform_sections.script`·`productions` 입력으로 이어짐 |
| 음성 처리 고지 증빙 | 마이크 고지 확인 기록 | 감사 기록(`write_audit`, action `voice.notice_ack`). 녹음 원본을 저장하지 않으므로 보관 동의 표가 필요 없음 |
| 성과·대본 색인 목록 | 무엇을 색인했는지 | `core.ai_documents`(조직 컬렉션)와 `analytics_snapshots`·`productions`의 id를 문서 메타데이터에 기록 |
| 위키 가이드 문서 | 브랜드 문서 관리 | `core.ai_documents` + 조직 Storage `org-files` |

조각은 `core.*`를 ALTER하지 않는다. 11.2절의 `core.plans` UPDATE는 video 자신의 플랜 행 `features`에 AI 키를 병합하는 데이터 변경이며 표 구조는 바꾸지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

19건(02장 6절 7건과 합쳐 26건).

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reference/reviews/NOMAD_Shorts_Maker.md` 3장 #1 | `supabase/migrations/001_initial_schema.sql:455-499` | `add_credits` EXECUTE 미회수로 브라우저에서 충전 | 제품 크레딧 함수 없음. 코어 `grant_credits` 등은 service_role 전용(`migrations/0003_core_credits.sql:369-375`). 제품 service 함수도 `revoke ... from public, anon, authenticated`(1200:1385-1450). 스모크: B `grant_credits` 42501 | VID-06-002 |
| SM #2 | `src/app/api/webhooks/toss/route.ts:19-51` | 서명 없으면 통과, orderId 파싱으로 플랜·크레딧 변경 | 코어 webhooks "서명 없으면 거부", 지급은 confirm 경로만(CORE_SPEC 6장). 웹훅 핸들러는 상태 동기화만 | VID-06-006, 025 |
| SM #4 | `src/app/api/posts/[id]/publish/route.ts:23-30` | `x-internal-call` 헤더 하나로 인증 우회 | 내부 HTTP 호출 금지, 함수 직접 호출. 예약 발행은 워커 크론(service_role)이 수행. 공개 라우트에 내부 헤더 분기 없음(CLAUDE.md 7장) | VID-06-003, 027 |
| SM #5 | `src/app/api/channels/oauth/route.ts:16-18` | OAuth state(base64 JSON)를 신뢰해 타 조직에 채널 연결 | `core.create_oauth_state`(멤버십 확인) → 콜백 `consume_oauth_state`가 org/user 확정. 채널 INSERT는 그 org로만, `check_refs`·`enforce_channel_limit` | VID-06-008 |
| SM #6 | `src/app/dashboard/layout.tsx:4-14`, `src/lib/mock-auth.ts` | 대시보드 세션 확인 없음, Mock 로그인 노출 | `proxy.ts` + 레이아웃 서버 가드(`session_context`), Mock 로그인 파일 미이식(쿠키 역할 Mock 금지). 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(실제 JWT, `isMockAuthAllowed()` 거짓이면 `/api/dev/login` 404, 배포 빌드에서 `AUTH_MODE=mock`이면 빌드 실패, 10절 페르소나). 모든 데이터는 RLS(스모크 B 0행) | VID-06-003, 004(Stage A), 039(CI 금지 문자열) |
| SM #7 | `src/lib/crypto.ts:4` | 암호화 키 없으면 0키 폴백 | 토큰은 `core.encrypted_credentials`, 키는 `CREDENTIALS_KEY_V<n>` 없으면 기동 실패(02장 8절) | VID-06-003, 008 |
| SM #8 | `src/lib/supabase/server.ts:4-48` | 웹훅/cron/워커가 쿠키 anon 클라이언트로 RLS에 막혀 무동작 | 3계층 클라이언트(`createAdminClient`는 서버·워커 전용), 모든 쓰기 error 검사. 사용자 쓰기 정책 없는 테이블은 guard 트리거라 실수 시 조용히 0행이 아니라 42501로 드러남 | VID-06-003, 015 |
| `docs/reference/reviews/Nomad-BlogStudio.md` 3장 #1 | `001_initial_schema.sql:286-287` | `org_members` FOR ALL로 타 조직 자가 가입 | 코어 `org_members`는 정책 없음 + guard(`migrations/0001_core_identity.sql:90`). 제품 정책은 `FOR ALL` 금지, 헬퍼만 사용 | VID-06-001, 002 |
| BS #2 | `001_initial_schema.sql:226-234` | 멤버가 `credit_balance`, `plan_id` 직접 수정 | 잔액은 `core.wallets`, 플랜은 `app_entitlements`(SELECT만). 제품 테이블에 잔액·플랜 컬럼 없음. 스모크: B wallets/entitlements/subscriptions UPDATE 42501 | VID-06-002 |
| BS #3 | `002_rpc_functions.sql:6-50` | `refund_credits` 권한 검사 없음 | 코어 refund는 service 전용, 제품은 Route Handler/워커에서만 호출 | VID-06-005 |
| BS #4 | `src/app/api/billing/confirm/route.ts:32-34` | orderId split 실패, 금액 미검증, 멱등 없음 | `payment_orders` 선저장 + `confirm_payment_order` 금액 대조·멱등. PM001이면 서버가 별도 호출로 `fail_payment_order`를 불러 주문을 failed로 기록한 뒤 운영 알림·Toss 취소 | VID-06-006, 007 |
| BS #5 | `src/app/api/billing/checkout/route.ts:10-31` | 요청 본문의 orgId, 클라이언트 금액 | org는 세션에서, 금액은 plans/credit_packs에서. Advanced 할인 팩은 서버가 플랜 확인 | VID-06-006 |
| BS #6 | `src/app/api/webhooks/toss/route.ts`, `webhooks/make/route.ts` | 웹훅 서명 없음, 임의 jobId done | 서명 필수, 잡 상태는 `complete_job`(워커 id 일치)만. Make 콜백은 Phase 2 automation-core HMAC | VID-06-025 |
| BS #7 | `src/lib/billing/credits.ts:53-56` | refund가 Promise 객체를 값으로 넣어 잔액 복구 불가 | 코어 `refund_credits` + `fail_job` 자동 환불, 부분 환불은 `p_amount`. 스모크: drift 0(코어) | VID-06-005, 015 |
| BS #8 | `src/lib/billing/credits.ts:22-73` | 비원자 차감, 오류 무시 | 코어 `consume_credits` 원자 차감(FOR UPDATE), 멱등 키. 클라이언트 오류는 throw로 전파 | VID-06-005 |
| BS #9 | `src/app/(auth)/signup/page.tsx:21-25` | 가입 시 조직 미생성 | 코어 `handle_new_user` + `signup_app='video'` 부트스트랩. 스모크: 가입 직후 조직·엔타이틀먼트 확인 | VID-06-004 |
| `docs/reference/reviews/Youtube_shots_Maker.md` 3장 #2 | `[5f6d262] backend/routers/oauth.py:76-92` | state 서명 없음, user_id 신뢰 | SM #5와 같은 코어 OAuth state. FastAPI 라우터 미이식 | VID-06-008 |
| YSM #3 | `[5f6d262] app/api/auth/naver/callback/route.ts:54-86` | 네이버 이메일로 기존 계정에 자동 로그인 | MVP는 네이버 로그인 없음(A Mock, B 이메일+Google). 네이버는 결정 22로 Stage C2(G2 후): `custom:naver` 또는 브리지, 브리지면 네이버 고유 id(`auth_identity_links`)로만 찾고 같은 이메일 기존 사용자는 `email_in_use`로 거부, 연결은 로그인 상태에서만. 이메일 자동 병합 금지 | 01장 8절 D-5·8.1절 D-27, 06장 8절 VID-06-065 |
| YSM #4 | `[5f6d262] backend/routers/studio.py:306-340` | task_id 소유권 미확인 | 진행·결과 조회는 `core.jobs` RLS(조직 멤버만) + `productions` RLS. API는 세션 org와 행 org를 대조, 불일치 404. 스모크: B 제품 테이블 0행 | VID-06-002, 017 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `video` | `public`(코어 lite와 같은 스키마. 사용자 최종 확인 대기) |
| 파일 | `_supabase-modular/migrations/1200_video.sql` | `supabase/monolith/migrations/0002_video_domain.sql`(변환본, 직접 수정 금지) |
| 변환 규칙 | - | (a) 스키마 블록 제거 (b) `core.`→`public.` (c) `video.`→`public.` (d) 도메인 테이블 `revoke all ... from public, anon, authenticated` 후 GRANT(DB_CONVENTIONS 12장) |
| 코어 | 0000~0006 | `0001_core_lite.sql`(전 [선택] 절 유지, 머리말에 사유) |
| apps/plans seed | 공용 `seed.sql`(video 3개 유료 플랜, 팩 4종) | 제품 `seed.sql`(apps 1행, 플랜 4개, 팩 8종 = 정가 4 + Advanced 할인 4, video 문구 8행) |
| 가입 부트스트랩 | `signup_app` 필수 | apps 1행이면 자동 |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| AI 라우팅 기본값 | `1200_video.sql` 11.1절 | `seed.sql`(같은 17행) |
| 플랜 AI 키 | `1200_video.sql` 11.2절 병합 UPDATE(모듈러 `seed.sql` 반영 요청 R-V1) | `seed.sql` 플랜 4행의 `features`에 직접 |
| 체인 검사 | 11.3절 DO 블록(제공자 행이 없으면 건너뜀) | `seed.sql` 끝 DO 블록(제공자는 0001이 먼저 넣음) |
| 함수 이름 충돌 | 없음 | `public`에 코어와 같은 이름 없음(검증 OK) |

## 9. 마이그레이션 파일

| 파일 | 내용 | 검증 |
|---|---|---|
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1200_video.sql` | 스키마, 헬퍼 3(`clip_notice_version` 추가), 트리거 함수 4, 테이블 26(2026-10-13 대행 4개 추가), 정책, RPC 11(사용자 9 + 공개 2), service 함수 5(`open_client_review`, `decide_client_review` 추가), `video-media` 버킷, 10절 `revoke execute on all functions in schema video from public` 후 역할별 GRANT(코어 0007과 같은 규칙), **11절 AI·음성 기본값(라우팅 17행, 플랜 AI 키, 체인 검사; 2026-10-13)** | 체커 OK(0000~0009 + seed 뒤, `--vector`), 2회 연속 적용 OK |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 lite 복사본 | 체커 OK |
| `supabase/monolith/migrations/0002_video_domain.sql` | 위 조각의 public 변환본 | 체커 OK |
| `supabase/monolith/seed.sql` | apps, 플랜 4(AI 키 포함), 팩 8, 대가성 문구 8, AI 라우팅 기본값 17행 + 체인 검사 | 체커 OK(`--vector mono`), 반복 적용 OK |
| RLS 스모크(06장 VID-06-002가 저장소로 옮김) | B 비멤버 21개 테이블 0행, 쓰기·RPC 42501, 자기 권한 상승 42501, 공개 RPC, 게이트(VD002/VD003/VD004/VD007/VD011/22023/23514) | 모듈러 65/65, 모놀리스 65/65 |
| 2026-10-13 추가 행동 검사(클립·대행) | 클립 동의 없음 VD015, 다른 조직 동의 42501, 구버전 동의 VD015, 동의 컬럼 직접 수정 42501, 클립 제휴 업로드 제목·해시태그 문구 누락 23514, 고객 생성(agency) / 다른 조직 고객 0행·42501, status 직접 수정 42501, 고객 승인 전 예약 VD016, 승인 요청 RPC authenticated 42501, `token_hash` 조회 42501, 두 번 결정 VD008, 리포트 월 첫날 CHECK 23514, 사용자 리포트 INSERT 42501, YouTube 기존 문구 규칙 유지 23514 | 모듈러 33/33, 모놀리스 33/33(PGlite, VID-06-002에 편입) |

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경은 없다(코어·`video` 조각 그대로). 인증 단계는 로그인 수단만 바꾸고 `profiles`·`org_members`·`app_entitlements`·RLS는 그대로다. C2에서 브리지 경로를 택할 때만 코어 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`을 참조하며 video 조각은 바꾸지 않는다.

시드는 `scripts/dev/seed-users.mjs --app video`(공통, `AUTH_ROADMAP.md` 2.3절)가 공통 페르소나를 만든 뒤 제품 훅 `scripts/dev/seed-users.video.mjs`가 아래 제품 행을 더한다. 로컬 Supabase(`127.0.0.1`·`localhost`)가 아니면 즉시 종료한다. 이메일은 `.test` 도메인(제안), 비밀번호는 `DEV_SEED_PASSWORD`(출력 금지).

| 키 | 이메일 | 만드는 방법(RPC/서비스 경로) | 기대 `session_context('video')` | 쓰임 |
|---|---|---|---|---|
| `owner` | `owner@dev.test` | `auth.admin.createUser(user_metadata.signup_app='video')` → 가입 트리거 `core.handle_new_user` → `on_signup_app_bootstrap` | 개인 조직 owner, `entitled=true`, `plan_code=starter`, `credit_balance=100`(가입 크레딧 1회, 멱등 키 `signup:<org>:video`) | 기본 사용자. VD-F-001 수용 기준 |
| `admin`, `member`, `viewer` | `admin@dev.test` 등 | 생성 후 `owner`로 로그인한 클라이언트가 `core.invite_member(owner_org, uid, role)` → 각 사용자가 `core.accept_invite(owner_org)` | owner 조직의 해당 역할, Starter | 역할 분기(owner/admin만 채널 연결·클립 동의, viewer 읽기 전용). Starter의 `team_members=1`은 서버 판정만이라 시드가 넘어서지만 역할 검사용이다. 팀 상한 검사는 `adv_*`로 한다 |
| `outsider` | `outsider@dev.test` | `signup_app='video'`로 생성(다른 개인 조직) | 자기 조직 owner, Starter | 교차 테넌트 RLS 거부(9절 스모크 B와 같은 기대: 제품 테이블 0행, 쓰기 42501) |
| `no_app` | `no_app@dev.test` | `signup_app` 없이 생성 | 모듈러: `entitled=false`, 첫 진입에서 `bootstrap_app_for_org('video')` 후 Starter. 모놀리스: apps 1행이라 가입 트리거가 자동 부트스트랩해 처음부터 `entitled=true` | OAuth 첫 로그인 경로(`finishLogin` 3번)를 A단계에서 검증(모듈러) |
| `suspended` | `suspended@dev.test` | 생성 후 service_role로 `core.profiles.status='suspended'` | 403 | 차단 확인 |
| `ops` | `ops@dev.test` | 생성 후 service_role로 `platform_role='platform_admin'` | 운영자 | 운영자 컬렉션(`VIDEO_KNOWLEDGE_ORG_ID`) 관리, 운영 화면 |
| `adv_owner`(제품 행) | `adv_owner@dev.test` | `signup_app='video'`로 생성 → service_role이 그 조직의 `core.subscriptions.plan_id`와 `core.app_entitlements.plan_id`를 `advanced` 플랜으로 갱신(`source='manual'`, 결제 경로가 아님) → 필요하면 `core.grant_credits`(service_role, 멱등 키 `dev-seed:<org>:video:advanced`)로 월 크레딧 5,000 지급(제안) | 조직 owner, `plan_code=advanced`, `features.agency=true`, `team_members=5`, `max_channels=40` | Advanced 게이팅(VD-F-092 팀, VD-F-120~126 대행, Track D/F `org_has_feature`), 결제 E2E와 분리된 플랜 상태 |
| `adv_member`(제품 행) | `adv_member@dev.test` | `signup_app='video'`로 생성 → `adv_owner`로 로그인한 클라이언트가 `core.invite_member(adv_org, uid, 'member')` → 본인이 `core.accept_invite(adv_org)` | `adv_owner` 조직의 member, `plan_code=advanced` | Advanced 팀 멤버 화면, member가 클립 동의(403)·고객 생성(42501)을 못 하는지, 팀 상한(5인) 서버 판정 |

`pending` 페르소나는 만들지 않는다(video는 open 앱이라 승인 대기가 없다). 대행 고객·고객 채널·채널 연결 같은 도메인 데이터는 시드하지 않고 각 테스트가 만든다(제안: 시드는 로그인 주체만 책임진다). 채널 연결 OAuth 토큰과 네이버 클립 세션은 시드 대상이 아니다(사용자 로그인과 별개, `CredentialVault`).

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| `no_app` | `signup_app` 없으면 엔타이틀먼트 없음 → 첫 진입·콜백에서 `bootstrap_app_for_org` | apps 1행이면 가입 트리거가 자동 부트스트랩(`supabase/monolith/migrations/0001_core_lite.sql:38`) → `no_app`도 `entitled=true`. 기대값만 다르고 코드는 같다 |
| 함수 이름 | `core.invite_member`, `core.accept_invite`, `core.bootstrap_app_for_org` | `public.` 같은 이름 |
| `--app` 여러 개 | 통합 DB에서 다른 앱과 함께 시드할 수 있다(두 번째 앱부터 `bootstrap_app_for_org`) | 해당 없음 |

## 11. 스토리보드 트랙 데이터 (2026-10-18 추가, 스토리보드 디벨롭)

확정 SF-1로 Track C Mode1과 Track D를 Track S(스토리보드 트랙)로 합쳤다(01장 10장, VD-F-130~142). 정본 SQL은 `1200_video.sql` 12절(1200:1929-3035)이다. 위쪽 절은 고치지 않았다. 기존 테이블 변경은 12절의 ALTER·UPDATE로만 했다. 새 테이블 6개, 함수 19개(헬퍼 4, 트리거 함수 7, 사용자 RPC 5, 서버 RPC 3), 정책 9개.

### 11.1 ERD 조각

```
video.storyboard_templates (code PK, 플랫폼 공용, 운영자 seed 5종)
core.organizations
 └─ video.storyboards ── storyboard_templates(template_code), video.clients(client_id), core.ai_runs(script_ai_run_id), core.jobs(root_job_id)
      ├─ video.scenes (ord 1..240)
      │    └─ video.scene_assets (image | narration | clip, ready 1개 + superseded 이력) ── scene_assets(reused_from_asset_id)
      ├─ video.storyboard_cuts (master 1 + short 최대 10)
      │    └─ video.outputs.storyboard_cut_id (2026-10-18 추가 FK) → video.uploads (기존 경로 그대로)
      └─ video.storyboard_snapshots (렌더마다 1행, cut_id, 읽기 전용)
Storage: video-media 버킷 <org_id>/video/scenes/<scene_id>/<uuid>.<ext>
```

Track S는 `video.productions`를 쓰지 않는다. 렌더 결과는 기존 `outputs` → `uploads` → compliance 경로를 그대로 탄다.

### 11.2 테이블

#### storyboard_templates (1200:2016-2027)

| 열 | 타입 | 설명 |
|---|---|---|
| code | text PK | `^[a-z][a-z0-9_]{2,39}$`. seed 5종: `knowledge_explainer`, `history_documentary`, `list_topn`, `story_radio`, `product_review`(1200:2988-3021) |
| label | text | 1~60자 |
| beats | jsonb | 배열 1~20개. `{key, label, share(목표 길이 비율, 합 1.0), kind(장면 종류 기본값)}` |
| default_scene_seconds | int | 2~30초. 그래프 결과에 장면 길이가 없을 때 쓴다 |
| status | text | active/retired |

쓰기는 운영자 seed만(guard). 모놀리스는 seed.sql 끝(seed.sql:98-148).

#### storyboards (1200:2029-2065)

| 열 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| client_id | uuid | Y | - | 대행 고객(`video.clients`, set null). 같은 조직 검사(VD002) |
| title | text | N | - | 1~200자 |
| format / aspect / target_seconds | text/text/int | N | - | 프리셋 CHECK `storyboards_preset_check`(1200:2057): 쇼츠 9:16 15/30/45/60/90초, 롱폼 16:9 180/300/600/1200/1800/3600초 |
| template_code | text | N | - | `storyboard_templates.code` |
| topic | text | Y | - | 300자 이하. 주제 점수 60 게이트(VD-F-013)는 Route Handler가 본다 |
| script_ai_run_id | uuid | Y | - | 대본 그래프 `video.script` 실행(`core.ai_runs`, 같은 조직 검사) |
| languages | text[] | N | {KO} | 1~3개, KO/JA/EN |
| voice_provider / voice_id | text/text | Y | - | 내레이션 목소리 고정(`elevenlabs`/`oss`). 둘 다 null이거나 둘 다 값(1200:2061). 만들 때만 사용자가 고르고 이후는 서버만. 장면 내레이션 다시 만들기는 이 값을 따른다(02장 5.3절 같은 목소리) |
| status | text | N | draft | draft/ready/rendering/rendered/archived(11.3절) |
| version | int | N | 0 | 마지막 렌더 스냅샷 번호. `snapshot_storyboard`만 올린다 |
| revision | int | N | 1 | 장면 구성(추가·삭제·순서·전체 생성) 변경 번호. reorder/add/delete RPC의 낙관적 동시성 기준 |
| root_job_id / last_error | uuid/text | Y | - | 진행 중 루트 잡(`video.orchestrate` 큐), 마지막 오류. 서버만 |

플랜 한도 트리거 `enforce_storyboard_limits`(1200:2219-2238): `features.storyboard`가 없거나 롱폼 길이가 `storyboard_max_minutes`를 넘으면 VD009(모든 호출자).

#### scenes (1200:2067-2093)

| 열 | 타입 | 설명 |
|---|---|---|
| storyboard_id / ord | uuid/int | ord 1~240, `unique(storyboard_id, ord) deferrable initially deferred`(1200:2090)로 한 번에 재정렬 |
| chapter | text | 1~80자, null 허용. 편집기 챕터 묶음 |
| kind | text | image/clip/text_card/title(MVP 4종). 엔드카드 없음 |
| duration_ms | int | 1,000~60,000(제안) |
| narration / on_screen_text / visual_prompt | text | 600자 / 160자 / 600자 이하 |
| motion_preset | text | zoom_in/zoom_out/pan_left/pan_right/static, 기본 static |
| music_cue | text | intro/build/drop/calm/outro 또는 null(제안, trailer와 같은 값) |
| shorts_candidate | bool | 쇼츠 후보 표시. 바꿔도 revision은 그대로 |
| sources | jsonb | 배열 최대 5개 `{title(1~200자, 필수), url(http/https), note(300자)}`. 검사 함수 `valid_scene_sources`(1200:1962-1986) |
| source_required | bool | 사실 주장 장면 표시. 그래프(서버)만 쓴다. true인데 sources가 비면 출처 경고(VD-F-138, D-33 전에는 WARN) |
| revision | int | 내용 열이 바뀔 때만 트리거 `scenes_before_update`(1200:2344-2364)가 1 올린다. ord·shorts_candidate는 제외 |

쓰기는 사용자 RPC(11.5절)와 서버만. 직접 INSERT/UPDATE는 42501.

#### scene_assets (1200:2095-2127)

| 열 | 타입 | 설명 |
|---|---|---|
| scene_id | uuid | cascade |
| kind | text | image/narration/clip |
| lang | text | narration만 필수, 나머지 null(CHECK) |
| aspect | text | 16:9/9:16. image 필수(쇼츠용 세로 이미지를 따로 보관), clip 선택, narration 없음(1200:2115) |
| status | text | ready/superseded. `(scene, kind, lang, aspect)`마다 ready 1개(부분 unique, 1200:2124) |
| storage_path | text | 자기 조직 폴더 CHECK `scene_assets_path_check`(1200:2119): 첫 폴더 = org_id, `<org>/video/scenes/<scene>/<uuid>.<ext>` |
| rights_basis / rights_note | text | clip은 둘 다 필수이고 ai_generated=false(1200:2117, 23514). RPC는 먼저 VD019로 거부 |
| ai_generated | bool | AI 생성 표시 기본값(01장 10.5절) |
| reused_from_asset_id | uuid | 이미지 재사용(같은 조직 image만, 0크레딧) |
| meta | jsonb | provider, model, voice_id, voice_job_id, duration_ms, width, height(4KB 이하) |

쓰기는 서버만(guard). 사용자 업로드는 서버가 검사 뒤 video-media 경로로 옮긴다(제안).

#### storyboard_cuts (1200:2129-2151)

| 열 | 타입 | 설명 |
|---|---|---|
| kind | text | master(스토리보드당 1개, 부분 unique) / short |
| aspect | text | master는 스토리보드 화면비, short는 9:16만 |
| scene_ids | uuid[] | 1~240개. short는 12개 이하이고 ord가 연속(트리거, 22023) |
| hook_text | text | short만, 100자 이하 |
| status | text | proposed/rendering/ready/failed |
| ord | int | master 0, short 1~10. `unique(storyboard_id, kind, ord)` |
| job_id / last_error | - | 렌더 잡과 오류 |

쇼츠 수 한도: `least(10, features.shorts_extract_max)`를 넘으면 VD021(1200:2323-2331). 쓰기는 서버만.

#### storyboard_snapshots (1200:2153-2165)

id, org_id(RLS용, 명세에 추가), storyboard_id, cut_id, version(`unique(storyboard_id, version)`), snapshot(jsonb 2MB 이하), created_at. snapshot = `{storyboard{…, voice_provider, voice_id}, cut{…}, scenes[{…, assets{"image:16:9", "clip", "narration:KO"…}}]}`. UPDATE는 service도 거부(42501, 1200:2367-2374).

#### 기존 테이블 변경 (1200:2167-2193)

| 대상 | 변경 |
|---|---|
| outputs | `storyboard_cut_id` FK 추가(cascade). `outputs_owner_check`를 6개 중 정확히 하나로 교체, `outputs_kind_owner_check`에 `kind in ('short','longform') and storyboard_cut_id is not null` 추가. 부분 unique `(storyboard_cut_id, language)`. 참조 검사는 새 함수 `check_output_refs`(1200:2379-2398)로 `outputs_check_refs` 트리거를 다시 건다(1200:2439-2441) |
| productions.track, sources.track | 값 C는 기존 행 호환으로 남기고 "신규 생성 금지" 주석만(제안, DB 차단 없음) |
| longform_projects/sections/highlights | 지우지 않음. "Track S로 대체, 삭제는 D-34" 주석(11.8절) |
| core.plans features | 병합 UPDATE(1200:3022-3035). 아래 표 |

| 플랜 | storyboard | storyboard_max_minutes | shorts_extract_max |
|---|---|---|---|
| Starter | false | 0 | 0 |
| Basic | true | 10 | 3 |
| Pro | true | 30 | 10 |
| Advanced | true | 60 | 10 |

모두 제안 값(01장 10.4절). Starter 값과 Starter의 `shorts_extract_max` 0은 명세에 없어 새로 정했다(제안). 모듈러 `seed.sql`이 이 조각보다 나중에 실행되면 덮어써지므로 seed 반영을 코어에 요청한다(11절 R-V1과 같은 경로).

### 11.3 상태 전이

새 함수 `video.enforce_storyboard_transition()`(1200:1989-2012). 기존 함수의 표를 고치지 않으려고 따로 만들었다. 허용 쌍 외에는 22023이며 service_role에도 적용된다.

| 테이블.열 | 현재 → 허용 | 누가 | 부수 효과 |
|---|---|---|---|
| storyboard_templates.status | active↔retired | 운영자 seed | - |
| storyboards.status | draft→ready/archived, ready→draft/rendering/archived, rendering→rendered/ready, rendered→ready/rendering/archived. archived는 끝(제안) | 서버(생성 결과·스냅샷·렌더 종료), 사용자 RPC(rendered→ready) | 전체 다시 생성은 Route Handler가 ready→draft 후 잡. rendered에서 장면을 고치면 RPC가 ready로 돌린다 |
| scene_assets.status | ready→superseded | 서버, save_scene(내레이션 문구 변경 시) | 이전 소재 보관(되돌리기 P1) |
| storyboard_cuts.status | proposed→rendering, rendering→ready/failed, failed→rendering, ready→rendering | 서버 | 렌더가 끝나면 워커가 컷 ready/failed, 스토리보드 rendered/ready, outputs 행을 service_role로 쓴다 |

편집 잠금: rendering 중 사용자 수정·삭제는 VD020, archived 수정은 VD005(`guard_storyboard_edit` 1200:2198-2216, RPC 공통 검사 `lock_storyboard_for_edit` 1200:2489-2522).

### 11.4 RLS와 GRANT (1200:2443-2485)

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| storyboard_templates | `exists(current_org_ids() o where org_has_feature(o,'storyboard'))` | 없음 | 없음 | 없음 | select + guard |
| storyboards | 멤버 + 엔타이틀먼트 | owner/admin/member + 엔타이틀먼트 + `org_has_feature(org,'storyboard')` | 같은 역할, using/with check | owner/admin | insert 열(org_id, client_id, title, format, aspect, target_seconds, template_code, topic, languages, voice_provider, voice_id), update 열(client_id, title, topic, languages), delete |
| scenes | 멤버 + 엔타이틀먼트 | 없음(RPC) | 없음(RPC) | 없음(RPC) | select + guard |
| scene_assets, storyboard_cuts, storyboard_snapshots | 멤버 + 엔타이틀먼트 | 없음(서버) | 없음 | 없음 | select + guard |

사용자 RPC는 SECURITY DEFINER이고 `is_service_caller` 또는 `has_org_role(owner/admin/member)`로 판정한다(viewer 불가). 서버 RPC는 `is_privileged_session`이 아니면 42501이고 authenticated EXECUTE를 회수했다. 12.8절(1200:2978-2986)이 이 절 함수의 PUBLIC EXECUTE를 회수한다.

### 11.5 RPC와 오류 코드

| 함수 | 호출자 | 핵심 규칙 | 오류 |
|---|---|---|---|
| `save_scene(p_scene_id, p_revision, p_patch)` (1200:2527-2580) | authenticated | 장면 revision 일치. 키는 chapter, duration_ms, narration, on_screen_text, visual_prompt, motion_preset, music_cue, sources. 내레이션이 바뀌면 그 장면 ready 내레이션 소재 superseded | P0002, 42501, VD009, VD020, VD005, VD409, 22023, 23514 |
| `reorder_scenes(p_storyboard_id, p_scene_ids, p_revision)` (1200:2582-2615) | authenticated | 스토리보드 revision 일치, 장면 id 전부. 스토리보드 revision + 1 | 위와 같음 |
| `add_scene(p_storyboard_id, p_revision, p_ord, p_kind, p_duration_ms)` (1200:2617-2658) | authenticated | 스토리보드 revision 일치. 상한 넘으면 VD018. 앞 장면 챕터를 이어받음 | 위 + VD018 |
| `delete_scene(p_scene_id, p_revision, p_scene_revision)` (1200:2660-2694) | authenticated | 스토리보드 revision 일치, 장면 revision은 선택. 그 장면을 포함한 proposed/failed 쇼츠 컷 삭제 | 위와 같음 |
| `set_shorts_candidate(p_scene_id, p_value)` (1200:2696-2720) | authenticated | revision 증가 없음 | P0002, 42501, VD009, VD020, VD005 |
| `apply_storyboard_result(p_storyboard_id, p_scenes, p_ai_run_id)` (1200:2728-2792) | service_role | draft만. 장면 수(VD018)·길이 합계 ±10%(VD017). 기존 장면과 렌더 전 컷을 지우고 새로 넣음 → ready. 감사 `storyboard.generate` | 42501, P0002, VD005, VD017, VD018, 22023 |
| `finish_scene_asset(p_scene_id, p_kind, p_storage_path, p_lang, p_aspect, …)` (1200:2796-2859) | service_role | 같은 슬롯 이전 ready → superseded. clip은 권리 근거·메모(VD019). image 화면비 기본값 = 스토리보드 화면비 | 42501, P0002, VD019, 22023, 23514 |
| `snapshot_storyboard(p_storyboard_id, p_cut_id)` (1200:2863-2976) | service_role | ready/rendered만. 마스터: 장면 수·길이 합계. 쇼츠: 연속·90초 이하(제안). clip 권리(VD019), image 소재(마스터는 같은 화면비). 스냅샷 1행, version + 1, 컷 rendering, 마스터면 스토리보드 rendering. 감사 `storyboard.snapshot` | 42501, P0002, VD005, VD017, VD018, VD019, 22023 |

새 SQLSTATE: VD017 장면 길이 합계 범위 밖, VD018 장면 수 범위 밖, VD019 clip 권리 근거 없음, VD020 렌더 중 편집, VD021 쇼츠 컷 한도 초과, VD409 낙관적 동시성 충돌. 길이 합계와 장면 수 하한은 편집 중에는 막지 않고(게이지 표시만) 생성 결과 반영과 렌더 스냅샷에서 막는다.

잡: `core.jobs`에 queue·kind CHECK가 없어 DB 변경이 없다. 렌더 루트 잡은 `video.orchestrate` 큐, FFmpeg 단계(`media.scene_clip`, `media.scene_concat`, `media.bgm_mix`)는 `video.media.cpu` 자식 잡이다(04장 새 장).

### 11.6 인덱스

| 인덱스 | 조회 패턴 |
|---|---|
| `storyboards_org_idx (org_id, created_at desc)`, `storyboards_status_idx (org_id, status)`, `storyboards_client_idx` | 목록, 렌더 중 수, 고객별 |
| `scenes_ord_uniq (storyboard_id, ord)` | 편집기 장면 목록 |
| `scenes_shorts_idx (storyboard_id, ord) where shorts_candidate` | 쇼츠 추출 후보 |
| `scenes_source_warn_idx (storyboard_id) where source_required and sources='[]'` | 출처 경고 수 |
| `scene_assets_one_ready_uniq`, `scene_assets_scene_idx`, `scene_assets_reuse_idx (org_id, created_at desc) where ready image` | 현재 소재, 이력, 이미지 재사용 고르기 |
| `storyboard_cuts_one_master`, `storyboard_cuts_ord_uniq` | 컷 목록 |
| `storyboard_snapshots_version_uniq`, `storyboard_snapshots_cut_idx` | 버전 열람(`GET …/snapshots/[version]`) |
| `outputs_storyboard_cut_lang_uniq (storyboard_cut_id, language)` | 컷 언어판 |

규모(제안): 롱폼 1편 40~80장면, 장면당 소재 이력 5행 이하. 스냅샷은 렌더당 1행, 240장면 기준 약 0.5MB.

### 11.7 모놀리스 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 위치 | `1200_video.sql` 12절 | `0002_video_domain.sql` 끝 12절(같은 변환 규칙 (a)~(d)) |
| 스키마 | `video` | `public` |
| 기본 권한 | default privileges | 새 테이블 6개 `revoke all … from public, anon, authenticated` 후 service_role GRANT(0002 12.5절 앞 블록) |
| 템플릿 5종, 플랜 키 | 12.9절 | `seed.sql` 끝(seed.sql:98-148). 위쪽 플랜 upsert가 features를 덮어써서 그 뒤에 병합 |
| 함수 EXECUTE 정리 | `in schema video` | `in schema public` |
| 이름 충돌 | 없음 | `public`에 같은 이름 없음(검사 OK) |

검증(2026-10-18): 체커 `--vector mod`(0000~0009 + seed + 1200, 1200 2회 연속) OK, `--vector mono`(0001 + 0002 + seed, 0002·seed 2회 연속) OK. 행동 검사 56/56(모듈러·모놀리스 각각, PGlite): VD009 롱폼 한도, 23514 프리셋, 상태 직접 수정 42501, 장면 직접 INSERT 42501, 서버 RPC 사용자 호출 42501, VD018, VD017, VD005, VD409(장면·스토리보드), 다른 조직 42501·0행, VD019, 경로 CHECK, 소재 superseded, VD020(RPC·직접 수정), 스냅샷 수정 42501, 잘못된 전이 22023, outputs 소유 2개 23514, 쇼츠 비연속 22023, VD021(Basic 3편), rendered→ready.

### 11.8 기존 Track D 테이블 처리 (D-34)

| 테이블 | 지금 | 대체 | 이전 경로(VD-F-142, 개발 착수 전 정리 작업) |
|---|---|---|---|
| longform_projects | 지우지 않음, 주석 "Track S로 대체, 신규 생성 안 함, 삭제는 D-34" | storyboards(format longform) | title·topic·languages 복사, target_minutes×60을 가장 가까운 프리셋으로, template_code는 category로 정함(knowledge→knowledge_explainer, radio→story_radio, viral_remake→knowledge_explainer, 제안), status는 draft |
| longform_sections | 지우지 않음, 주석 | scenes | position→ord, heading→chapter, script(언어별)의 storyline 언어 문구→narration, image_prompt→visual_prompt, image_path는 서버가 scene_assets로 옮김 |
| longform_highlights | 지우지 않음, 주석 | storyboard_cuts(kind short) | 시간 구간이라 장면 단위로 바로 옮길 수 없다. 이전하지 않고 기존 출력물만 남긴다(제안) |

정책·RPC는 그대로 두어 기존 행 읽기와 진행 중 작업이 깨지지 않는다. 새 코드는 Track D 경로에 넣지 않는다. 삭제 시점은 D-34(이전 완료 확인 뒤)이며 그때 outputs의 longform_id·highlight_id와 CHECK도 함께 정리한다.
