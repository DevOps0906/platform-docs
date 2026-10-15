# 05 데이터 모델: NOMAD Book Trailer (book-trailer)

작성일 2026-10-15. 정본 SQL은 모듈러 조각 `docs/products/_supabase-modular/migrations/2600_trailer.sql`(아래 "2600:줄")이고 모놀리스 `supabase/monolith/migrations/0002_trailer_domain.sql`은 변환본이다(8절). 표기·규칙은 `docs/products/_platform-core/DB_CONVENTIONS.md`를 따른다. 검증: PGlite `check.mjs --vector` 모듈러(코어 + seed + 제품 조각 16개 정순·역순)·모놀리스 모두 OK, RLS·권한 스모크 124/124(모듈러·모놀리스 각각, `supabase/monolith/tests/rls_smoke.sql`, 러너 `run-smoke.mjs`).

## 1. 개요와 ERD

스키마 `trailer`, 앱 id `trailer`, 번호 범위 2600~2699(`DB_CONVENTIONS.md` 2장 다음 빈 범위, 2400 arch-studio 제안·2500 news 다음. 표 등록은 코어 요청 R-T2). SQLSTATE 접두사 `TR`(스키마 머리글자, `DB_CONVENTIONS.md` 1장 규칙).

```
core.organizations ─┬─ trailer.books ──────────────┬─ trailer.purchase_links ── trailer.link_clicks (service)
                    │   (원고·표지 경로, 권리 확인)   ├─ trailer.brand_kits (book_id null = 조직 기본)
                    │                               ├─ trailer.book_digests (service, 책당 1행)
                    │                               └─ trailer.trailers ─┬─ trailer.briefs (불변 버전)
                    │                                   │ grammar_code ──┼─ trailer.scenes ── trailer.scene_assets (service)
                    │                                   │ template_code  ├─ trailer.metadata_packs
                    │                                   │ brand_kit_id   ├─ trailer.renders (service, 스냅샷)
                    │                                   │ music_track_id └─ trailer.reviews (service, P1)
                    └─ trailer.generation_runs (service: digest/brief/storyboard/scene_image/narration/meta)

카탈로그(org 없음, service 쓰기): trailer.grammars ── trailer.templates, trailer.music_tracks, trailer.runtime_config
코어 참조: core.jobs(잡), core.credit_ledger(선차감), core.ai_*(RAG·위키·실행 기록), core.voice_*(음성), storage(org-files, exports, trailer-*)
```

모든 하위 테이블은 `(부모 id, org_id)` 복합 FK로 같은 조직 행만 가리킨다(다른 조직 행 연결은 23503, 스모크 "B 다른 조직 책으로 자기 조직 트레일러").

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 조직 소유 테이블은 `org_id`, `created_at`, `updated_at`(트리거 `core.set_updated_at`), 사용자 쓰기 테이블은 `created_by default auth.uid()`. 컬럼 전체는 SQL이 정본이고 아래는 설계 판단이 들어간 컬럼만 적는다.

### 2.1 runtime_config (2600:167) — 카탈로그

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `key` | text PK | 운영 상수 이름 |
| `value_int` | integer | 값. seed 8행(2600:2126): 조직 동시 실행 4, 동시 렌더 2, 인용 80/300자, 원고 600,000자, 승인 링크 7일, 렌더 보존 14/90일 |

사용자 GRANT 없음. 서버·함수만 `trailer.config_int`(2600:175)로 읽는다.

### 2.2 grammars (2600:186), templates (2600:209) — 카탈로그

| 테이블 | 핵심 컬럼 | 제약 |
|---|---|---|
| `grammars` | `code`, `book_genres text[]`, `beats jsonb`(비트 3~10개: key, label, share_pct, scene_kinds), `narration_style`, `music_mood`, `status` | 장르 값은 publishing 장르 8종 + other. 비트 형식은 앱 로더가 zod로 재검증(share_pct 합 100) |
| `templates` | `code`, `grammar_code` FK, `composition_id`(Remotion 컴포지션 이름), `formats text[]`, `tier`(free/premium), `params_schema`, `preview_path` | 포맷은 5종 안에서만. 공개된 템플릿만 렌더(`start_render`) |

seed: 문법 6종(2600:2137), 템플릿 6종(무료 3, 프리미엄 3, 2600:2183). 08_DESIGN_SYSTEM.md 6장이 연출 정의다.

### 2.3 music_tracks (2600:230) — 카탈로그

| 컬럼 | 설명 |
|---|---|
| `mood`, `bpm`, `duration_ms`, `tier` | 고르기 조건 |
| `license_source`, `license_ref`, `commercial_use_allowed`, `license_verified_at/by` | 라이선스 기록. 공개(`published`)는 검증 + 상업 이용 허용일 때만(CHECK `music_tracks_publish_license_check`) |
| `storage_path` | 원본(버킷 `trailer-catalog`, 렌더러만). 사용자에게 컬럼 GRANT 없음 |
| `preview_path` | 30초 미리듣기(버킷 `trailer-previews`, 공개) |

### 2.4 books (2600:258)

| 컬럼 | 타입 | 쓰기 | 설명 |
|---|---|---|---|
| 서지 정보 | text/date | 멤버 | 제목(1~200), 부제, 저자, 출판사, 장르, 언어(ko/en/ja), ISBN(`^97[89][0-9]{10}$`), 출간일, 소개(2,000), 대상 독자(300) |
| `source` | text | 멤버(INSERT만) | upload / paste. `flora`는 서버(`import_flora_book`)만, `flora_book_id`와 짝(CHECK) |
| `manuscript_path`, `cover_path` | text | 멤버 | 자기 조직 폴더 + 정해진 파일명만(CHECK, 다른 조직 폴더 23514) |
| `manuscript_sha256`, `manuscript_chars` | text, int | 서버 | 파싱 결과. 원문 텍스트는 DB에 두지 않는다 |
| `digest_status` | text | 서버 | none → queued → ready / failed(3절) |
| `rights_ack_version/at/by` | text, timestamptz, uuid | RPC | `acknowledge_rights`만(6절). 버전·시각은 짝(CHECK) |
| `status`, `deleted_at` | text, timestamptz | 멤버 | active/archived, soft delete(30일 뒤 purge) |

### 2.5 purchase_links (2600:303), link_clicks (2600:497)

| 테이블 | 핵심 컬럼 | 설명 |
|---|---|---|
| `purchase_links` | `store`(9종), `url`(https만, 2,000자), `is_affiliate`, `short_code`(10자 소문자·숫자, 유일), `click_count`(서버 캐시), `is_active`, `sort_order` | 책당 10개(트리거). `click_count`는 사용자 GRANT 없음 |
| `link_clicks` | `link_id`, `clicked_at`, `referrer`(500), `ip_hash`(64 hex), `user_agent`(300), `tag`(영상·플랫폼 태그) | 서버만 기록(`record_link_click`). 원 IP 컬럼 없음 |

### 2.6 brand_kits (2600:325)

| 컬럼 | 설명 |
|---|---|
| `book_id` | null이면 조직 기본 키트, 값이 있으면 그 책 전용(복합 FK) |
| `palette jsonb` | 3~6개 `{role, hex}`, 역할 6종 중복 불가(CHECK `trailer.valid_palette`, 2600:134) |
| `font_display`, `font_body` | OFL 한국어 서체 목록 안에서만(08_DESIGN_SYSTEM.md 4.2절) |
| `logo_path` | 자기 조직 `trailer/brand/` 폴더만 |
| `source` | cover_extract / manual |

### 2.7 trailers (2600:350)

| 컬럼 | 쓰기 | 설명 |
|---|---|---|
| `grammar_code`, `template_code`, `brand_kit_id` | 멤버 | 카탈로그 FK, 키트는 같은 조직(복합 FK, 키트 삭제 시 `brand_kit_id`만 null) |
| `formats text[]` | 멤버 | 렌더할 포맷 1~5개 |
| `duration_s` | 멤버 | 15/30/45/60/90 |
| `spoiler_level` | 멤버 | none / teaser / light |
| `narration_mode`, `voice_pref` | 멤버 | voiceover/none, auto/elevenlabs/oss-voice |
| `voice jsonb` | 서버 | 첫 내레이션 때 고정된 제공자·보이스(같은 목소리 규칙). 사용자 GRANT 없음 + 트리거가 되돌림 |
| `music_track_id` / `music_path` + `music_rights_ack(_at/_by)` | 멤버 / 트리거 | 둘 중 하나만(CHECK). 업로드 경로가 바뀌면 확인 해제, 확인 시각·사람은 트리거가 기록 |
| `current_brief_id`, `selected_hook` | 멤버 | 현재 브리프(같은 조직 브리프만, 복합 FK) |
| `storyboard_version` | 서버 | 스토리보드 생성 때 +1 |
| `status` | 멤버 | active / approved / archived. approved는 480p가 아닌 성공 렌더가 있어야 한다(`TR004`) |

### 2.8 briefs (2600:395)

불변 버전. `version`은 트리거가 트레일러별 max+1(어드바이저리 락), `source`는 ai/manual. 사용자 INSERT는 manual만(정책 + 트리거가 source를 manual로 덮어써 AI 표시 위조 불가), UPDATE·DELETE 정책 없음. `content jsonb` 64KB 이하(형식 04장 4.2절).

### 2.9 scenes (2600:420)

| 컬럼 | 쓰기 | 설명 |
|---|---|---|
| `position` | 멤버 | 0~39, 트레일러 안 유일(지연 제약: 한 트랜잭션에서 순서를 바꿀 수 있다) |
| `kind` | 멤버(INSERT만) | 8종. `end_card`는 사용자가 만들 수 없고(정책) 바꿀 수 없다(GRANT 없음 + 트리거 `TR007`) |
| `duration_ms` | 멤버 | 500~15,000 |
| `text`, `narration` | 멤버 | 160자, 400자 |
| `quote_ref`, `quote_verified` | 서버 | 원고 위치와 대조 결과. 사용자가 인용 장면 `text`를 고치면 트리거가 `quote_verified=false`. `quote_verified`는 quote_card + 위치가 있을 때만(CHECK) |
| `visual jsonb` | 멤버 | prompt, style, motion, focus. 16KB 이하 |
| `music_cue` | 멤버 | intro/build/drop/calm/outro |
| `revision` | 트리거 | 내용이 바뀔 때만 +1(낙관적 동시성) |

트레일러당 엔드카드 1개(부분 유일 인덱스 `scenes_one_end_card_idx`, 2600:447). 트레일러 생성 트리거가 엔드카드를 만든다(DEFINER, 2600:796).

### 2.10 metadata_packs (2600:451)

| 컬럼 | 쓰기 | 설명 |
|---|---|---|
| `platform` | 멤버(INSERT만) | 7종, 트레일러당 플랫폼 1행 |
| `title`, `description`, `hashtags`, `link_ids` | 멤버 | 100자, 5,000자, 30개(공백·# 중복 없음), 10개. 링크는 같은 조직·같은 책만(23503) |
| `has_affiliate`, `disclosure` | 트리거 | 링크 중 제휴가 있으면 true + 대가성 문구를 설명 첫 줄에 넣는다. 사용자가 지워도 다시 들어간다. CHECK가 최종 보장 |

### 2.11 book_digests (2600:479) — 서버

책당 1행. `manuscript_sha256`(분석 대상 원고), `chapters jsonb`(1~300개: n, title, chars, summary, key_passages 위치), `characters`, `themes`, `settings`, `ai_run_id`. 합계 512KB 이하.

### 2.12 scene_assets (2600:511) — 서버

| 컬럼 | 설명 |
|---|---|
| `kind` / `slot` | image·user_image → visual, narration → audio(생성 컬럼). 장면·슬롯마다 ready 1개(부분 유일 인덱스), 이전 것은 superseded |
| `source`, `ai_generated`, `provider`, `model` | AI 표시 무결성: 출처와 플래그 일치, AI면 제공자·모델 필수, user_image ↔ upload(CHECK) |
| `rights_ack` | 업로드는 권리 확인 필수(CHECK) |
| `storage_path` | `trailer-media/<org>/trailer/assets/<scene>/<uuid>.<ext>`(자기 조직 폴더 CHECK) |
| `seed`, `voice_id`, `duration_ms`, `chars`, `width`, `height`, `bytes`, `run_id` | 재현·정산·렌더용 |

### 2.13 generation_runs (2600:548) — 서버

| 컬럼 | 설명 |
|---|---|
| `kind` | digest / brief / storyboard / scene_image / narration / meta. 대상 조합 CHECK(digest는 책만, brief·storyboard·meta는 트레일러, 이미지·내레이션은 장면) |
| `credits_reserved`, `credit_ledger_id` | 선차감 금액과 원장 행 |
| `idempotency_key` | `run:trailer:<request_id>`(유일) |
| `job_id`, `ai_run_id` | `core.jobs`, `core.ai_runs` 연결 |
| `status` | 3절 상태 전이 |
| `payload`, `progress`, `error` | 실행 입력 요약, 진행 단계(Realtime), 오류 1,000자 |

### 2.14 renders (2600:582) — 서버

| 컬럼 | 설명 |
|---|---|
| `format`, `resolution` | 5종, 480p/720p/1080p |
| `plan_code`, `watermark`, `ai_label` | 요청 시점 플랜과 서버 결정. 480p는 항상 워터마크(CHECK), AI 에셋이 있으면 `ai_label=true`(CHECK `renders_ai_label_check`) |
| `snapshot jsonb` | 트레일러·책·템플릿·키트·음악·CTA·장면(에셋 경로 포함)·총 길이·AI 에셋 여부. 같은 스냅샷 = 같은 영상 |
| `credits`, `credit_ledger_id`, `request_id` | 선차감, 멱등(유일) |
| `output_path`, `poster_path`, `srt_path`, `bytes`, `duration_ms` | `exports/<org>/trailer/renders/<render_id>/` 아래만(`finish_render` 검사). succeeded면 출력 필수(CHECK) |
| `expires_at` | 보존 만료(free 14일, 유료 90일) |

### 2.15 reviews (2600:622) — 서버(P1)

`render_ids uuid[]`(1~5), `token_sha256`(유일, 사용자 GRANT 없음), `reviewer_label`, `status`(pending → approved/changes_requested/expired/revoked), `expires_at`, `decided_at`, `comment`(1,000).

## 3. 상태 전이

| 대상 | 현재 → 허용 | 누가 | 부수 효과 | 구현 |
|---|---|---|---|---|
| `books.digest_status` | none → queued(분석 시작) → ready(종료) / failed(실패·잡 정리) / 원고 변경 시 → none | 서버, 원고 변경은 트리거 | ready면 브리프 가능 | `start_run`, `finish_run`, `fail_run`, `reconcile_runs`, `books_before_update` |
| `generation_runs.status`, `renders.status` | (insert) queued → running / canceled / failed, running → succeeded / failed / queued(재시도) | 서버 | 종료 시 `finished_at`. 결과 저장 시 잡 `refund_on_failure=false` | `enforce_run_status_transition`(2600:924, service에도 적용, 위반 `TR001`) |
| `trailers.status` | active ↔ archived, active → approved(성공 렌더 필요) | 멤버, 승인 링크(서버) | archived면 실행·렌더 거부 | `trailers_before_write`, `decide_review` |
| `reviews.status` | pending → approved / changes_requested / expired / revoked, 종료 상태 고정 | 서버 | approved면 트레일러 approved | `enforce_review_transition`(2600:962) |
| `scene_assets.status` | ready → superseded | 서버 | 장면·슬롯 ready 1개 | `finish_run` |
| `scenes.quote_verified` | true → false(사용자가 문구 수정) | 트리거 | 렌더 시 `TR006` 또는 사용자 확인 | `scenes_before_write` |

## 4. RLS 정책

모든 테이블 RLS ON, `revoke all on all tables in schema trailer from anon, authenticated` 후 필요한 GRANT만(2600:1914~2070).

| 테이블 | SELECT | INSERT | UPDATE | DELETE | 쓰기 GRANT 범위 |
|---|---|---|---|---|---|
| grammars, templates, music_tracks | 공개 행 + `has_trailer_access()` 또는 플랫폼 관리자 | - | - | - | 없음(guard 트리거). music_tracks는 `storage_path` 제외 컬럼만 SELECT |
| runtime_config | - | - | - | - | 없음 |
| books | 멤버 + 엔타이틀먼트 | owner/admin/member + 엔타이틀먼트 + source in (upload, paste) | owner/admin/member | owner/admin | 서지 정보·경로·status·deleted_at. 해시·분석 상태·권리 확인 컬럼 없음 |
| purchase_links, brand_kits, metadata_packs | 멤버 + 엔타이틀먼트 | owner/admin/member + 엔타이틀먼트 | 같음 | owner/admin/member | `click_count`, `has_affiliate`, `disclosure`, `source` 제외 |
| trailers | 멤버 + 엔타이틀먼트 | owner/admin/member | owner/admin/member | owner/admin | `voice`, `storyboard_version`, `music_rights_ack_at/by` 제외 |
| briefs | 멤버 + 엔타이틀먼트 | source='manual' + owner/admin/member | - | - | INSERT만(id, org_id, trailer_id, source, content) |
| scenes | 멤버 + 엔타이틀먼트 | kind ≠ end_card + owner/admin/member | owner/admin/member | kind ≠ end_card + owner/admin/member | `kind`, `quote_ref`, `quote_verified`, `revision` 제외 |
| book_digests, link_clicks, scene_assets, generation_runs, renders | 멤버 + 엔타이틀먼트 | - | - | - | 없음(guard 트리거) |
| reviews | 멤버 + 엔타이틀먼트 | - | - | - | 없음. `token_sha256` 제외 컬럼만 SELECT |

쓰기 정책을 주는 테이블의 조건(`DB_CONVENTIONS.md` 8장): (1) 돈·권한·AI 표시가 걸린 컬럼에 GRANT가 없다, (2) 서버 컬럼은 트리거가 사용자 변경을 되돌린다(이중 잠금, 서버 판정은 `core.is_privileged_session()` = service_role 또는 DEFINER RPC 안), (3) 같은 조직 참조는 복합 FK, (4) viewer는 쓰기 정책 대상 역할이 아니다.

Storage(2600:2072): `trailer-media` 멤버 읽기(자기 조직 폴더 + 엔타이틀먼트), 쓰기 정책 없음(서버만). `trailer-catalog` 정책 없음(서버만). `trailer-previews` 공개 읽기.

함수 EXECUTE(2600:2094): 사용자에게는 헬퍼 8개와 `acknowledge_rights`, `save_scene`, `reorder_scenes`만. 나머지(서버 RPC 12개, 트리거 함수)는 service_role 전용. 서버 RPC는 DEFINER이므로 함수 안 `is_privileged_session()`은 2차 잠금이 아니다. 1차 잠금은 EXECUTE 회수이고 스모크가 사용자 호출 42501을 확인한다.

## 5. 인덱스와 성능

| 인덱스 | 조회 |
|---|---|
| `books_org_updated_idx (org_id, updated_at desc) where deleted_at is null` | 책 목록 |
| `trailers_org_updated_idx`, `trailers_book_idx` | 홈의 최근 트레일러, 책 상세 |
| `scenes_trailer_idx (trailer_id, position)`, `scenes_one_end_card_idx` | 스토리보드 편집, 엔드카드 유일 |
| `scene_assets_one_ready_idx (scene_id, slot) where ready` | 렌더 전 에셋 확인, 장면 썸네일 |
| `generation_runs_active_idx (org_id, status) where queued/running` | 동시 실행 판정(`start_run`) |
| `renders_active_idx`, `renders_trailer_idx`, `renders_expiry_idx (expires_at) where succeeded` | 동시 렌더 판정, 렌더 기록, 보존 만료 정리 |
| `link_clicks_link_idx (link_id, clicked_at desc)`, `link_clicks_org_idx` | 링크·태그별 기간 집계 |
| `purchase_links_book_idx (book_id, sort_order)` | 엔드카드 CTA(첫 활성 링크) |

예상 규모(제안): 조직당 책 100, 트레일러 2,000, 장면 4만, 클릭 월 수십만. 클릭 집계는 일 단위 머티리얼라이즈 뷰를 P1에 검토한다(R-T6).

## 6. 코어 참조

| 코어 객체 | 용도 | 비고 |
|---|---|---|
| `core.organizations`, `org_members`, `has_org_role`, `is_org_member`, `has_entitlement`, `is_platform_admin` | 조직·권한 | ALTER 없음 |
| `core.app_entitlements`, `core.plans` | 플랜 features(`trailer.plan_features`) | trailer 플랜 3행은 조각 12절이 do nothing으로 넣는다(모듈러 seed 반영은 R-T1) |
| `core.consume_credits`, `credit_ledger` | 선차감(`consume:trailer:run:<rid>`, `consume:trailer:render:<request_id>`) | 환불은 `core.fail_job`(refund_on_failure) |
| `core.enqueue_job`, `jobs`, `cancel_job` | 큐 `trailer.ai`, `trailer.render`(멱등 `job:trailer:...`) | `reconcile_runs`가 잡 상태를 실행·렌더에 반영 |
| `core.write_audit` | 권리 확인, 승인 링크, FLORA 가져오기 | |
| `core.storage_org_id`, 버킷 `org-files`, `exports` | 원고·표지·사용자 음악, 렌더 결과 | |
| `core.ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 책 원고 RAG(컬렉션 `trailer-book-<book_id>`, `oss-embed`) | 제품 전용 AI 테이블 없음(`AI_ARCHITECTURE.md` 9장) |
| `core.wiki_pages`, `wiki_revisions`, `purge_wiki_page` | 책 설정 위키 | |
| `core.ai_conversations`, `ai_messages`, `ai_runs`, `ai_run_steps`, `ai_usage`, `resolve_ai_route`, `set_ai_cross_border_ack` | 코치 채팅, 그래프 실행, 원가, 라우팅, 국외 이전 동의 | |
| `core.voice_sessions`, `voice_jobs` | 음성 대화, 내레이션 기록 | |
| `core.encrypted_credentials`, `oauth_states` | YouTube 채널(P1) | |
| `core.affiliate_*` | 쓰지 않는다 | source_app이 video·blog만이고 제공자가 제휴 네트워크 4종뿐이다(`0006_core_affiliate.sql:54-75`). 서점 구매 링크는 `purchase_links`가 맡는다. 코어 범용화는 R-T3 |

인증 단계는 스키마 변경이 없다. 네이버 브리지를 채택하면 코어 `auth_identity_links`를 참조만 한다(`AUTH_ROADMAP.md` 10장).

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

이식 원천 리뷰의 "높음" 18건(NOMAD Shorts Maker 12, Toon-Factory 6) 중 보안·데이터 10건을 여기, 나머지 8건은 02장 6절에 둔다(대상 선정 이유는 `README.md` 2.1절). 합계 18 = 차단 설계 18.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #1 | `docs/reviews/NOMAD_Shorts_Maker.md:78` | 크레딧 DEFINER 함수를 authenticated가 호출해 크레딧을 늘릴 수 있음 | 크레딧은 코어 `consume_credits`만, 호출은 service_role 전용 `start_run`·`start_render` 안에서만. 이 스키마의 서버 RPC는 EXECUTE를 사용자에게 주지 않는다(2600:2094~2120). 스모크 "A 서비스 전용 start_run 호출 42501" | `generation_runs`, `renders`, TR-06-001, 002 |
| 같은 리뷰 #2 | `:79` | 토스 웹훅 서명 선택 검증, orderId 파싱으로 플랜 변경 | 결제는 코어 `payment_orders` 선저장 → confirm 단일 경로, 웹훅 서명 필수(`CORE_SPEC.md` 5~6장). 이 제품은 결제 테이블을 만들지 않는다 | TR-06-013 |
| 같은 리뷰 #4 | `:81` | `x-internal-call` 헤더로 인증 우회 | 내부 호출은 함수 직접 호출, 워커는 service_role 클라이언트만. 공개 경로는 `/b/[code]`, `/review/[token]`, 웹훅뿐이고 각각 service RPC에 코드·토큰 해시만 넘긴다 | TR-06-003, 020 |
| 같은 리뷰 #5 | `:82` | OAuth 콜백이 state의 orgId를 신뢰 | YouTube 연결(P1)은 코어 `create_oauth_state`(서버 발급 nonce + 세션 대조)만. 로그인 OAuth와 채널 OAuth 분리(D-17) | TR-06-058 |
| 같은 리뷰 #6 | `:83` | 세션 없는 대시보드, 항상 노출되는 localStorage Mock 로그인 | `proxy.ts`가 `/home/**` 등 보호. Mock은 로컬 시드 계정으로 실제 JWT만(쿠키·localStorage 역할 금지, `AUTH_ROADMAP.md` 2장). RLS가 최종 방어(스모크 B·C·anon 항목) | TR-06-003, 004 |
| 같은 리뷰 #7 | `:84` | 암호화 키 미설정 시 0 키 폴백 | 이 스키마에 비밀 컬럼이 없다. 채널 토큰은 코어 `encrypted_credentials`(키 없으면 기동 실패, `SECURITY_BASELINE.md` 12장) | 02장 8절 환경변수 |
| `docs/reviews/Toon-Factory.md` 3장 #1 | `docs/reviews/Toon-Factory.md:45` | 브라우저 렌더라 워터마크 제거·무료 MP4 생성을 서버가 막을 수 없음 | 브라우저 미리보기(Remotion Player)는 프록시 저해상도 + 워터마크 오버레이, 다운로드 경로 없음. 파일은 서버 렌더러만 만들고 워터마크·AI 표시는 `start_render`가 플랜으로 결정(요청 입력 아님). `renders`는 사용자 쓰기 불가, 480p는 워터마크 CHECK, AI 에셋이 있으면 `ai_label` CHECK. 스모크 "A 렌더 워터마크 끄기 42501" | `renders`, TR-06-031, 032 |
| 같은 리뷰 #2 | `:46` | 공개 버킷에 프리미엄 에셋 → URL만으로 수집 | 카탈로그 음악 원본은 비공개 버킷 `trailer-catalog`(정책 없음, 렌더러만), 사용자에게 `storage_path` 컬럼 GRANT 없음, 공개 버킷 `trailer-previews`에는 30초 미리듣기·작은 미리보기만. 프리미엄 템플릿은 렌더 시 플랜 검사(`TR005`) | `music_tracks`, `templates`, TR-06-029 |
| 같은 리뷰 #3 | `:47` | 단일 캔버스 레이어뿐이라 컷·영상 단위가 없음 | 장면을 1급 테이블(`scenes`, 위치·길이·종류)로 두고 트레일러 → 장면 → 에셋 3단 구조. 렌더 스냅샷이 장면 배열을 고정 | `scenes`, `renders.snapshot` |
| 같은 리뷰 #4 | `:48` | 레이어 필드 부족으로 핵심 기능 표현 불가 | 장면 `visual jsonb`(prompt, style, motion, focus)의 형식을 04장 4.3절 zod·pydantic 스키마로 고정하고 크기 상한(16KB) CHECK. 화면 배치는 템플릿 컴포지션이 소유(사용자 자유 레이어 편집은 범위 밖) | `scenes`, 08_DESIGN_SYSTEM.md 7장 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러(`2600_trailer.sql`) | 모놀리스(`0002_trailer_domain.sql`) |
|---|---|---|
| 스키마 | `trailer` | `public`. `core.apps.schema_name='public'` |
| 함수·테이블 이름 | `trailer.*`, `core.*` | `public.*`(이름·시그니처 동일). 앱은 `SUPABASE_DB_SCHEMA`로 전환 |
| 스키마 전체 GRANT/REVOKE | `in schema trailer` | 도메인 테이블 17개·함수 32개 목록으로 바꿈(public의 코어 객체 권한을 건드리지 않는다) |
| 플랜·팩·라우팅 기본값 | 조각 12·13절(`@monolith-seed` 블록) | `seed.sql` |
| 코어 | 0000~0009 | `0001_core_lite.sql`(SECTION 9 affiliate 제거) |
| FLORA 가져오기 | 같은 DB의 `publishing.books`를 DEFINER가 읽는다 | publishing 스키마가 없어 `TR010` |
| 큐·기능 키 문자열 | `trailer.ai`, `trailer.render`, `trailer.digest` 등 | 그대로(앱 id·큐 이름은 스키마와 무관) |

변환은 `DB_CONVENTIONS.md` 12장 규칙을 따른 스크립트로 만들고(06장 TR-06-001 소유), 두 파일 본문은 변환 외에 같아야 한다.

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `docs/products/_supabase-modular/migrations/2600_trailer.sql` | 모듈러 조각(정본). 1 헬퍼, 2 카탈로그, 3 콘텐츠, 4 서버 기록, 5 트리거, 6 사용자 RPC, 7 서버 RPC, 8 RLS·GRANT, 9 Storage, 10 EXECUTE 정리, 11 카탈로그 seed, 12 플랜·팩, 13 AI 라우팅 16행 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 축소판 복사본(SECTION 9 제거, 사유 주석) |
| `supabase/monolith/migrations/0002_trailer_domain.sql` | 도메인 변환본 |
| `supabase/monolith/seed.sql` | apps 1행, 플랜 3, 팩 3, 라우팅 16 |
| `supabase/monolith/tests/rls_smoke.sql`, `run-smoke.mjs` | RLS·권한·RPC 회귀 124항목. `node products/book-trailer/supabase/monolith/tests/run-smoke.mjs --target mod\|mono` |

## 10. 개발용 시드 페르소나 (Stage A, 확정 결정 22)

스키마 변경 없음. `scripts/dev/seed-users.mjs --app trailer`가 로컬 Supabase에만 만든다(`AUTH_ROADMAP.md` 2.2~2.3절).

| 페르소나 | 조직·역할 | 플랜 | 확인하는 것 |
|---|---|---|---|
| `owner` | 개인 조직 owner | free | 가입 크레딧 60, 30초 9:16 체험, 워터마크, 1080p `TR005` |
| `creator_owner` | 개인 조직 owner | creator | 포맷 5종·1080p·프리미엄 템플릿·음악 업로드 |
| `pub_owner` / `pub_member` / `pub_viewer` | 출판사 팀 조직 owner / member / viewer | publisher | 팀 권한(viewer 읽기만, 책 삭제 owner만), 승인 링크(P1) |
| `outsider` | 다른 조직 owner | free | 교차 조직 0행·23503·P0002 |
| `no_app` | 엔타이틀먼트 없음 | - | 카탈로그 0행, 쓰기 42501 |
| `suspended` | 정지 계정 | - | 로그인 거부 |
| `ops` | 플랫폼 관리자 | - | 카탈로그 draft 조회, 라이선스 검증 |
