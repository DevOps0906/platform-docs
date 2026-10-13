# 05 데이터 모델: NOMAD AI Factory (nomad-video)

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
 └─ video.banned_words
Storage: video-media 버킷(제품 소유, 서버 쓰기만), core org-files/exports/public-assets
```

## 2. 테이블

표준 컬럼(DB_CONVENTIONS 3장): 모든 테넌트 테이블은 `id uuid`(로그성은 identity), `org_id`(cascade), `created_at`. UPDATE가 있는 테이블은 `updated_at` + `core.set_updated_at` 트리거(1200:836-846). 상태는 text + CHECK.

### 2.1 channels (1200:341)

| 이름 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| platform | text | N | - | youtube/instagram/tiktok/threads |
| credential_id | uuid | Y | - | `core.encrypted_credentials`. 평문 토큰 컬럼 없음 |
| external_channel_id, name, handle | text | N/Y/Y | - | 플랫폼 식별자 |
| role | text | N | main | main/commerce/trend/longform/lofi/playlist/insurance(E=lofi, F=playlist 분리) |
| target_language / target_country | text | N | KO / KR | 원본 ja_group/en_group 역할을 언어 컬럼으로 대체 |
| daily_quota_units / quota_used_today / quota_reset_at | int/int/tstz | N/N/Y | 10000 / 0 | YouTube 쿼터 |
| status | text | N | active | active/paused/error/revoked |
| last_error, created_by, updated_at | - | - | - | - |

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
| has_affiliate / disclosure_description / disclosure_pinned | bool/text/text | 대가성 문구 강제 CHECK(1200:749) |
| status | text | draft/checking/blocked/awaiting_confirm/approved/scheduled/uploading/published/failed/canceled |
| compliance_check_id / compliance_ack_by / compliance_ack_at | - | 게이트 |
| job_id / credit_ledger_id / platform_post_id / post_url / published_at / attempts / last_error / request_id | - | `unique(channel_id, platform_post_id)`로 중복 발행 방지 |

### 2.17 upload_links (1200:761), compliance_checks (1200:773), analytics_snapshots (1200:795)

upload_links: upload_id, link_id(`core.affiliate_links`), placement(video_description/video_pinned_comment), position. compliance_checks: upload_id, verdict(pass/warn/fail), stages, issues, suggestions, llm_failed, usage_id(`core.ai_usage`), credit_ledger_id. analytics_snapshots: upload_id, captured_at, views, likes, comments, watch_time_sec, `unique(upload_id, captured_at)`.

### 2.18 workflows (1200:809), banned_words (1200:822)

workflows: name, graph(nodes·edges 배열 CHECK), is_active(사용자 GRANT 없음, Phase 2). banned_words: word(1~60자), severity(warn/fail), `unique(org_id, word)`.

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
| uploads.status | draft→checking/canceled, checking→blocked/awaiting_confirm/approved/draft, blocked→draft/canceled, awaiting_confirm→approved/draft/canceled, approved→scheduled/canceled, scheduled→uploading/canceled, uploading→published/failed/scheduled, failed→scheduled/canceled | 서버, 사용자 RPC(확인·취소) | approved 진입은 compliance 게이트(VD011), 취소 시 queued 잡 취소·환불 |

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
| SM #6 | `src/app/dashboard/layout.tsx:4-14`, `src/lib/mock-auth.ts` | 대시보드 세션 확인 없음, Mock 로그인 노출 | `proxy.ts` + 레이아웃 서버 가드(`session_context`), Mock 로그인 파일 미이식. 모든 데이터는 RLS(스모크 B 0행) | VID-06-003, 004 |
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
| YSM #3 | `[5f6d262] app/api/auth/naver/callback/route.ts:54-86` | 네이버 이메일로 기존 계정에 자동 로그인 | MVP는 네이버 로그인 없음(이메일+Google). Phase 2에 로그인 상태에서만 명시적 연결(코어 요청), 이메일 자동 병합 금지 | 01장 8절 D-5, 06장 6절 |
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
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1200_video.sql` | 스키마, 헬퍼 2, 트리거 함수 4, 테이블 22, 정책, RPC 8(사용자 6 + 공개 2), service 함수 3, `video-media` 버킷, 10절 `revoke execute on all functions in schema video from public` 후 역할별 GRANT(코어 0007과 같은 규칙), **11절 AI·음성 기본값(라우팅 17행, 플랜 AI 키, 체인 검사; 2026-10-13)** | 체커 OK(0000~0009 + seed 뒤, `--vector`), 2회 연속 적용 OK |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 lite 복사본 | 체커 OK |
| `supabase/monolith/migrations/0002_video_domain.sql` | 위 조각의 public 변환본 | 체커 OK |
| `supabase/monolith/seed.sql` | apps, 플랜 4(AI 키 포함), 팩 8, 대가성 문구 8, AI 라우팅 기본값 17행 + 체인 검사 | 체커 OK(`--vector mono`), 반복 적용 OK |
| RLS 스모크(06장 VID-06-002가 저장소로 옮김) | B 비멤버 21개 테이블 0행, 쓰기·RPC 42501, 자기 권한 상승 42501, 공개 RPC, 게이트(VD002/VD003/VD004/VD007/VD011/22023/23514) | 모듈러 65/65, 모놀리스 65/65 |
