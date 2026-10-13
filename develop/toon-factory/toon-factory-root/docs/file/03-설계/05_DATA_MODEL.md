# 05 데이터 모델: Toon Factory

작성일 2026-10-12. 정본 SQL: `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2000_toon.sql`(아래 `2000:줄`). 모놀리스는 같은 본문을 변환한 `supabase/monolith/migrations/0002_toon_domain.sql`.

2026-10-13 개정: AI·음성은 코어 표만 참조하고 제품 AI 표를 만들지 않았다(6절에 이유). 제품 스키마 표·컬럼·RLS는 바뀌지 않았다. 바뀐 것은 라우팅 기본값 14행과 플랜 AI 키 병합(8·9절), 컷 문서 선택 필드(02장 2.2절, DB 변경 없음)뿐이다.

## 1. 개요와 ERD

```
core.organizations ─┬─ toon.series (org_id) ─┬─ toon.series_characters ─── toon.characters
                    │        │ (id, org_id)  └─ toon.episodes (series_id, org_id)
                    │        │                        └─ toon.cuts (episode_id, org_id)   doc jsonb = 레이어 판별 유니온
                    ├─ toon.generations ── core.jobs, core.credit_ledger
                    │        └─ toon.user_assets (generation_id)
                    └─ toon.exports ── toon.episodes(set null), core.jobs, core.credit_ledger

카탈로그(org 없음, 플랫폼 소유)
toon.asset_packs ─┬─ toon.characters ── toon.assets(kind pose|expression)
                  └─ toon.assets(kind background|prop|bubble|effect_text|bgm)
toon.catalog_assets (security_invoker 뷰, 경로 컬럼 제외)

Storage: toon-catalog(비공개, 정책 없음) / toon-previews(공개 읽기) / toon-user-assets(멤버 읽기, 서버 쓰기) / core exports
```

AI·음성(2026-10-13)은 코어 표만 참조한다:

```
core AI·음성 (참조만)
 ├─ core.ai_org_settings    (국외 이전 동의: cross_border_ack_at, cross_border_notice 고지문 버전, ack_by)
 ├─ core.ai_conversations   (사용자 본인, dify_user, channel text/voice)  -- 작품 연결은 Dify 입력 series_id + 서버 대조
 │    ├─ core.ai_messages   (citations, provider, credits)
 │    └─ core.voice_sessions ─ core.voice_jobs (feature voice_chat / dialogue_voice / video_voice, store_audio=false)
 ├─ core.ai_collections     (settings-<series_id> kind rag, wiki-<series_id> kind wiki, oss-embed)
 │    ├─ core.ai_documents  (설정 노트 source_type text, 위키 source_type wiki)
 │    └─ core.ai_chunks     (사용자 SELECT 없음, match_ai_chunks만)
 ├─ core.wiki_pages / wiki_links / wiki_revisions  (작품 설정 위키, slug 접두사 s-<작품 id 앞 8자>/)
 └─ core.ai_runs ─ core.ai_run_steps  (graph toon.storyboard / toon.dialogue / toon.image_prompt / wiki.lint)
```

리뷰가 요구한 `project → cuts → layers`(`docs/reference/reviews/Toon-Factory.md:67`)를 작품(series) → 회차(episodes) → 컷(cuts) → 레이어(`cuts.doc.layers`)로 구현했다. 회차를 둔 이유는 연재(주 2회) 페르소나와 회차 단위 콘티·내보내기 때문이다.

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 모든 테넌트 테이블에 `id uuid`, `org_id`(cascade), `created_at`, 갱신 테이블에 `updated_at` + `core.set_updated_at` 트리거. 소프트 삭제는 `user_assets`만(`deleted_at`). 콘텐츠는 owner/admin 하드 삭제(연쇄).

### 2.1 카탈로그

`toon.asset_packs`(`2000:93-114`): 에셋 묶음과 라이선스.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| code | text | N | - | 유일, `^[a-z][a-z0-9_]{1,40}$` |
| name, description | text | N, Y | - | |
| style_preset | text | N | flat_line | AI 배경 프롬프트에 붙는 화풍 키 |
| tier | text | N | free | free/premium |
| license_source | text | N | - | in_house/commissioned/licensed_commercial |
| license_ref | text | N | - | 계약·증빙 식별자 3~200자 |
| commercial_use_allowed | boolean | N | true | |
| license_verified_at/by | timestamptz/uuid | Y | - | 운영자 검증 |
| status | text | N | draft | draft/published/retired. published는 검증 필수(CHECK) |

`toon.characters`(`2000:116-127`): pack_id, code(팩 안 유일), name, status.

`toon.assets`(`2000:129-154`):

| 컬럼 | 타입 | NULL | 설명 |
|---|---|---|---|
| pack_id, character_id | uuid | N, Y | pose/expression이면 character_id 필수, 그 외 null(CHECK) |
| kind | text | N | pose/expression/background/prop/bubble/effect_text/bgm |
| code, name | text | N | (pack, character, kind, code) `unique nulls not distinct` |
| tier | text | N | free/premium |
| storage_path | text | N | `toon-catalog` 원본. 사용자에게 컬럼 GRANT 없음 |
| editor_path | text | Y | `toon-catalog` 1024px. 사용자에게 컬럼 GRANT 없음 |
| preview_path | text | N | `toon-previews` 256px |
| mime | text | N | png/webp/svg/mp3. bgm ⇔ audio/mpeg(CHECK) |
| width, height, duration_ms | int | Y | |
| anchors | jsonb | N | 포즈의 `head {x,y,r,s}` 정규화 좌표 |
| tags, status, sort_order | | N | |

### 2.2 작품

`toon.series`(`2000:169-185`): title(1~80), format(instatoon/webtoon), canvas_width(320~2048), canvas_height(320~4096), genre, synopsis(2,000), style_pack_id, status(active/archived), metadata, created_by(기본 `auth.uid()`). `unique (id, org_id)`는 하위 복합 FK 대상.

`toon.series_characters`(`2000:188-200`): series_id + org_id 복합 FK, character_id(카탈로그), display_name(1~40), role_note(300). `unique (series_id, character_id)`.

`toon.episodes`(`2000:202-219`): 복합 FK(series_id, org_id), number(1~9999, 작품 안 유일), title(80), logline(500), script jsonb(콘티, 128KB 상한), status(draft/storyboarded/editing/done).

`toon.cuts`(`2000:221-244`):

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| episode_id | uuid | N | - | 복합 FK(episode_id, org_id) |
| position | int | N | - | 0~999. `unique (episode_id, position) deferrable initially deferred`(한 문장 재정렬) |
| width, height | int | N | - | 320~2048 / 320~4096 |
| doc | jsonb | N | `{"v":1,"layers":[]}` | 02장 2.2절 스키마. CHECK: object, `v` 숫자, `layers` 배열 60개 이하, 256KB 이하 |
| duration_ms | int | N | 2500 | 500~10,000 |
| revision | int | N | 1 | 트리거가 관리(낙관적 동시성) |
| thumbnail_path | text | Y | - | 서버 생성 |

DB CHECK는 문서의 겉모양만 막고, 레이어 판별 유니온의 세부는 앱(zod)과 렌더 워커가 검증한다(워커는 검증 실패 시 `fail_job(retryable=false)`).

### 2.3 서버 기록

`toon.generations`(`2000:250-276`): kind(background/prop), prompt(1~1000), prompt_en, negative_prompt, style_preset, model, seed, width/height(256~2048), num_images(1~4), status, job_id, credit_ledger_id, credits, fal_request_id(유일), request_id(유일), error, finished_at.

`toon.user_assets`(`2000:280-300`): generation_id, kind, source(ai_generated/upload), ai_generated, model, storage_path(`toon-user-assets`), preview_path, width, height, bytes, label, deleted_at. CHECK: `(source='ai_generated') = ai_generated`, AI면 model 필수.

`toon.exports`(`2000:303-330`): episode_id(set null), kind(png/zip/webtoon_strip/mp4), status, plan_code, watermark(서버 결정), ai_label, ai_label_visible(CHECK: 표기 해제는 AI 레이어가 있을 때만 의미), options, job_id, credit_ledger_id, credits, request_id(유일), output_paths, bytes, duration_ms, error, started_at, finished_at, expires_at.

### 2.4 쓰지 않는 것

플랜, 구독, 크레딧, 결제, 잡 테이블은 제품 스키마에 만들지 않는다(`DB_CONVENTIONS.md:237`). 월 내보내기 한도는 별도 쿼터 테이블 없이 `toon.exports` 카운트로 판정한다(`CORE_SPEC.md:138`). AI·음성 전용 제품 표도 만들지 않는다(6절).

### 2.5 Storage

| 버킷 | 공개 | 상한 | 정책 | 경로 |
|---|---|---|---|---|
| `toon-catalog` | 비공개 | 20MB | 없음(service_role만) | `<pack_code>/{orig,editor}/<asset_id>.png` |
| `toon-previews` | 공개 | 1MB, webp/png | SELECT anon, authenticated | `<pack_code>/<asset_id>.webp` |
| `toon-user-assets` | 비공개 | 20MB, png/webp | SELECT 멤버(첫 폴더 org_id), 쓰기 정책 없음 | `<org_id>/toon/user_assets/<uuid>.png` |
| `exports`(core) | 비공개 | 200MB | 코어 정책(서버 쓰기, 멤버 읽기) | `<org_id>/toon/exports/<export_id>/<file>` |

## 3. 상태 전이

| 테이블.컬럼 | 현재 | 허용 전이 | 누가 | 부수 효과 / 강제 방식 |
|---|---|---|---|---|
| generations.status, exports.status | (insert) | queued만 | service | 트리거 `enforce_run_status_transition`(`2000:431-470`), 위반 22023 |
| 같음 | queued | running, canceled, failed | 워커, 취소 라우트 | canceled는 `core.cancel_job` 환불 후 미러 |
| 같음 | running | succeeded, failed, queued(재시도) | 워커 | 종료 시 `finished_at` 자동 |
| 같음 | succeeded/failed/canceled | 없음 | - | 종료 |
| asset_packs.status | draft | published(검증 필수), retired | platform_admin(service) | CHECK + 감사 |
| episodes.status | 자유 | draft/storyboarded/editing/done 사이 | 사용자, 워커(storyboarded) | 표시용이라 트리거 없음(돈·권한 무관) |
| cuts.revision | n | n+1(doc/크기/시간 변경 시) | 트리거 `bump_cut_revision` | 사용자가 값을 지정해도 덮어씀 |
| user_assets.deleted_at | null | now() | `toon.archive_user_asset` | 감사 `user_asset.archive` |

## 4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| asset_packs, characters | `(status='published' and toon.has_toon_access()) or core.is_platform_admin()` | 없음 | 없음 | 없음 | select + guard 트리거 |
| assets | 위와 같음 | 없음 | 없음 | 없음 | 경로 2개를 뺀 컬럼 select + guard |
| catalog_assets(뷰) | security_invoker로 assets 정책 적용 | - | - | - | select |
| series, series_characters, episodes, cuts | `is_org_member(org_id) and has_entitlement(org_id,'toon')` | with check 같은 식 + 한도 트리거 | using/with check 같은 식 | `has_org_role(org_id, owner/admin)` | select, insert, update, delete |
| generations, exports | 멤버 + 엔타이틀먼트 | 없음 | 없음 | 없음 | select + guard |
| user_assets | `deleted_at is null` + 멤버 + 엔타이틀먼트 | 없음 | 없음 | 없음 | select + guard |

쓰기 정책을 준 4개 테이블의 조건(`SECURITY_BASELINE.md:108`): (a) with check에 멤버+엔타이틀먼트, (b) 돈·권한·과금 컬럼 없음(플랜 한도는 트리거가 DB에서 강제), (c) 상태 컬럼(episodes.status)은 표시용. 다른 조직 부모를 참조하는 INSERT는 복합 FK가 23503으로 막는다(FK 검사는 RLS를 우회하므로 org_id까지 묶었다).

### 4.1 검증 결과 (2026-10-12, PGlite)

체커: 모놀리스 `0001_core_lite.sql` → `0002_toon_domain.sql` → `seed.sql` OK, 모듈러 0000~0007 + seed + `2000_toon.sql` OK. 조각을 두 번 적용해도 OK(멱등). RLS 스모크 68항목, 모듈러·모놀리스 모두 68/68 통과. 주요 항목:

| 검사 | 기대 | 결과 |
|---|---|---|
| B가 A 조직 series/series_characters/episodes/cuts/generations/user_assets/exports SELECT | 0행 | 0행(7개 테이블) |
| B가 A 조직 app_entitlements, wallets SELECT | 0행 | 0행 |
| B가 `org_id=A`로 series INSERT | 42501 | 42501 |
| B가 자기 조직 회차로 A 작품 참조 | 23503 | 23503 |
| B가 A 컷 UPDATE / A 작품 DELETE | 0행 | 0행 |
| B `save_cut_doc`(A 컷) / `archive_user_asset`(A) / `plan_features`(A) / `org_asset_access`(A) / `monthly_export_count`(A) | P0002 / 42501 x4 | 일치 |
| B 자기 플랜 pro로 UPDATE, 원장 INSERT, `consume_credits`, `change_member_role`(A) | 42501 | 42501 |
| A 엔타이틀먼트·지갑 UPDATE, `grant_credits`, 자기 역할·platform_role 변경 | 42501 | 42501 |
| A가 generations/exports 직접 INSERT(워터마크 위조) | 42501 | 42501 |
| A가 `assets.storage_path` 조회 | 42501 | 42501 |
| A가 `toon-catalog` 객체 조회 / `toon-user-assets` 직접 업로드 | 0행 / 42501 | 일치 |
| 무료 두 번째 작품 | TN001 | TN001 |
| `save_cut_doc` 낡은 revision / 문서 형식 위반 | TN409 / 23514 | 일치 |
| 무료 조직 `org_asset_access`(free+premium) 허용 수 | 1 | 1 |
| 엔타이틀먼트 만료 조직: 카탈로그 / 작품 INSERT | 0행 / 42501 | 일치 |
| anon: `toon-previews` 읽기 / `toon.series` | 1행 / 42501 | 일치 |
| service: exports succeeded→running, succeeded로 INSERT | 22023 | 22023 |
| service: AI 출처-플래그 불일치, 라이선스 미검증 공개 | 23514 | 23514 |
| 함수 권한: anon EXECUTE 가능한 도메인 함수 / authenticated 트리거 함수 / authenticated 사용자 RPC | 0 / 0 / 8 | 일치 (조각 9절, 0007 규칙) |

스크립트는 TN-06-002가 `supabase/tests/toon/`로 옮긴다.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `series_org_updated_idx (org_id, updated_at desc)` | 작품 목록 |
| `episodes_series_number_uniq (series_id, number)` | 회차 목록 |
| `cuts_episode_position_uniq (episode_id, position)` | 에디터 진입, 렌더 |
| `assets_pack_kind_idx`, `assets_character_kind_idx` | 카탈로그 탭, 포즈/표정 |
| `generations_org_created_idx`, `generations_job_idx` | 생성 기록, 워커 미러 |
| `user_assets_org_created_idx` (부분: 미삭제) | 내 에셋 |
| `exports_org_created_idx`, `exports_org_month_idx`(부분), `exports_job_idx` | 기록, 월 카운트, 워커 |

예상 규모(제안): 조직당 컷 수천 개, 문서 평균 10KB. 한도 트리거는 조직 단위 advisory lock으로 동시 INSERT 경쟁을 막는다.

## 6. 코어 참조

| 코어 객체 | 용도 |
|---|---|
| `core.organizations` | 모든 테넌트 FK |
| `core.apps` | `toon` 등록(`2000:29-30`) |
| `core.app_entitlements`, `core.plans` | `plan_features`, `has_toon_access` |
| `core.jobs`, `core.credit_ledger` | generations/exports FK |
| `core.is_org_member`, `has_org_role`, `has_entitlement`, `is_platform_admin`, `is_service_caller`, `storage_org_id`, `write_audit`, `set_updated_at`, `guard_privileged_write` | 정책, 함수, 트리거 |
| `consume/refund_credits`, `enqueue_job` 등 | 서버 코드에서만(SQL에서 호출하지 않음) |


AI·음성 코어 객체(2026-10-13, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | toon 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 채팅 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 3개와 위키 lint 실행 기록 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, Next.js 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 14행(9절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의(AI 배경 fal 호출 전 확인 포함) | 온보딩·설정(사용자 세션), Route Handler(읽기) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 작품별 설정 노트·위키 컬렉션 | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 작품 설정 위키(캐릭터 바이블) | FastAPI(쓰기), Next.js 서버(조직·작품 확인 후 읽기) |
| `voice_sessions`, `voice_jobs` | 음성 대화, STT·TTS·미리듣기·영상 음성 작업 | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |
| `write_audit` | 음성 처리 고지 확인(`voice.notice_ack`), 위키 편집·확정, 노트 삭제 | Route Handler |

제품 AI 표를 만들지 않은 이유(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 대화-작품 연결 표 | 채팅이 어느 작품 설정을 근거로 하는지 | Dify 입력 `series_id`(대화 시작 때) + FastAPI가 매핑 org와 `toon.series`의 org를 매번 대조. 대체 경로는 Next.js가 요청마다 `series_id`를 받아 같은 확인 |
| 작품-컬렉션 연결 컬럼 | 작품 설정 컬렉션 위치 | 결정적 이름 `settings-<series_id>`, `wiki-<series_id>`(`core.ai_collections` `unique (org_id, app_id, name)`). 작품이 삭제되면 일일 정리 스케줄이 이름의 `series_id`가 `toon.series`에 없는 컬렉션과 문서·청크·위키 페이지를 지운다(02장 4절, 계정 삭제는 `purge_organization` 연쇄) |
| 캐릭터별 목소리 표 | 말풍선 화자 → 보이스 | 컷 문서 `BubbleLayer.voiceKey`(02장 2.2절) + 위키 캐릭터 페이지의 `voice_key`. DB 변경 없음 |
| 음성 처리 동의 표 | 고지 확인 증빙 | `core.audit_logs`(`voice.notice_ack`, 고지문 버전). 녹음 원본을 저장하지 않으므로 녹음 보관 동의(`voice_jobs.consent_*`)는 해당 없음 |
| 국외 이전 동의 표 | 동의 증빙 | `core.ai_org_settings`(시각, 고지문 버전, 동의한 사용자) |
| 영상 음성 클립 표 | 클립 위치·재사용 | `exports.options.voice.clips` + 결정적 Storage 경로 `exports/<org_id>/toon/voice/<export_id>/` + `voice_jobs`(feature `video_voice`) |
| 설정 노트 문서 표 | 노트 관리 | `core.ai_documents`(source_type `text`, 작품 컬렉션) |
| 일관성 검사 결과 표 | 위반 목록 보관 | 콘티 JSON(`episodes.script`)의 `consistency`와 `ai_run_steps` |

플랜 AI 키(`ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `dialogue_voice`, `video_voice`)는 `core.plans.features` jsonb에 병합하는 데이터 변경이다(9절). 표 구조는 바뀌지 않는다.

`core.*`를 ALTER하지 않는다. 모듈러 seed 수정도 하지 않는다(features 확장은 2026-10-13 코어 반영 완료, 06장 6절).

PM001 처리: `core.confirm_payment_order`는 금액 불일치 시 `PM001`을 올리며 같은 호출의 UPDATE는 롤백된다(계약 불변). 주문 failed 기록은 service_role 전용 `fail_payment_order`(2026-10-13 코어 반영)가 맡는다. `PM001`을 받으면 Route Handler가 별도 호출로 `fail_payment_order(order_id, 'amount_mismatch', {...})`를 부르고, 서버 로그·운영 알림과 함께 Toss 취소 API를 호출한다. 코어 수정은 하지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

#1~#4는 여기, #5·#6은 02장 6절. 합계 6 = 리뷰 "높음" 6.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reference/reviews/Toon-Factory.md` 3장 #1 | `Toon-Factory/PRD.md:31`, `Design.md:17`, 리뷰 `:45`, `:65` | 브라우저 FFmpeg.wasm 렌더면 워터마크 제거와 무료 MP4 생성을 서버가 막을 수 없다 | (1) 모든 최종 결과물(PNG, ZIP, 스트립, MP4)은 서버 워커가 DB 문서와 원본 에셋으로 렌더한다. 브라우저에는 다운로드용 렌더 경로가 없다. (2) `toon.exports`는 사용자 쓰기 GRANT가 없고 guard 트리거가 있다(`2000:349-357`, `:665-676`). (3) `watermark`는 Route Handler가 플랜 `features.watermark`로 정해 기록하고 워커는 이 값만 읽는다. (4) 종류 허용은 `features.export`(`TN002`). (5) 결과는 `exports` 버킷 1시간 서명 URL. 남는 위험: 화면 캡처(편집 미리보기는 1024px 편집용 에셋 기준) | TN-06-018, TN-06-019, TN-06-020 |
| 같은 리뷰 #2 | `PRD.md:31`, `Design.md:15`, 리뷰 `:46`, `:66` | 프리미엄 에셋이 공개 버킷이면 URL만으로 라이브러리 수집 가능 | (1) 원본·편집용은 비공개 `toon-catalog`(정책 없음), 공개는 256px 썸네일 `toon-previews`만(`2000:679-697`). (2) `assets.storage_path/editor_path`는 컬럼 GRANT에서 뺐다(`2000:633-634`). (3) 편집용 서명 URL(15분)은 `toon.org_asset_access`로 플랜 `asset_tiers`를 확인한 뒤에만 발급, 조직당 600개/10분. (4) 렌더 워커가 같은 함수로 다시 확인해 등급 밖 에셋이 있으면 실패(`TN003`). (5) 카탈로그 읽기는 toon 엔타이틀먼트 사용자만(`has_toon_access`) | TN-06-011, TN-06-019 |
| 같은 리뷰 #3 | `Design.md:21-23`, 리뷰 `:47`, `:67` | 단일 `layers[]`라 컷 개념, 저장 구조가 없다 | series → episodes → cuts 테이블과 `cuts.doc` 자체 스키마(Fabric `toObject` 아님), 컷 크기·순서·노출 시간 컬럼, revision 낙관적 동시성(`save_cut_doc`), 문서 형식·크기 CHECK(`2000:238-243`), 테넌트 간 복합 FK(`2000:198`, `:215`, `:236`), 플랜 한도 트리거(`2000:359-408`) | 2절, TN-06-001, TN-06-005 |
| 같은 리뷰 #4 | `Design.md:7` vs `:23`, 리뷰 `:48`, `:68` | 레이어 필드가 6개뿐이라 표정 부착, 반전, 불투명도, 말풍선 텍스트·꼬리를 담지 못한다 | 판별 유니온 4종(character, bubble, image, text)과 공통 필드(02장 2.2절). 표정은 포즈 에셋 `anchors.head`(`assets.anchors`)로 위치를 계산해 부모-자식 레이어 없이 교체. z 순서는 배열 순서. zod 스키마와 버전 필드 `v`로 엔진 교체·마이그레이션 대비 | 02장 2.2절, TN-06-005, TN-06-010 |

## 8. 모놀리스와 모듈러의 차이

`DB_CONVENTIONS.md:242-264` 기준.

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `toon` | `public`(사용자 최종 확인 대기, 01장 8절 D7) |
| 코어 | `core` 0000~0006 | `0001_core_lite.sql`. 제거: 6-A oauth_states, 6-B encrypted_credentials, 9 affiliate(외부 OAuth와 제휴 기능 없음). 유지: 3 Toss, 4 크레딧, 6-C 레이트 리밋, 7 잡, 8 Storage |
| 앱 등록 | `core.apps('toon', schema 'toon')` | `public.apps('toon', schema 'public')`. 앱 행이 1개라 가입 메타데이터 없이도 부트스트랩 |
| 권한 | 스키마 기본 권한 없음 + 명시 GRANT | 도메인 테이블마다 `revoke all ... from public, anon, authenticated` 후 GRANT(`0002_toon_domain.sql` 6-9절) |
| features | 모듈러 seed가 2026-10-13부터 모놀리스 seed와 같은 전체 키를 담는다(이전에는 `watermark`, `export`만 있어 Pro도 무료 한도가 걸렸다) | `seed.sql`에 01장 4.1절 전체 키 |
| 크레딧팩 | 모듈러 seed에 2종(2026-10-13 반영) | `seed.sql`에 2종 |
| PostgREST | `[api].schemas`에 `toon` 추가 | 설정 불필요 |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| AI 라우팅 기본값 | `2000_toon.sql` 10.1절 | `seed.sql`(같은 14행) |
| 플랜 AI 키 | `2000_toon.sql` 10.2절 병합 UPDATE(모듈러 `seed.sql` 반영은 코어 요청, 06장 6절 요청 7) | `seed.sql` free·pro `features`에 직접 |
| 체인 검사 | 10.3절 DO 블록(제공자 행이 없으면 건너뜀) | `seed.sql` 끝 DO 블록(제공자는 0001이 먼저 넣음) |

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2000_toon.sql` | 모듈러 조각(번호 2000, 범위 2000~2099). 10절 AI·음성 기본값(라우팅 14행, free·pro AI 키, 체인 검사). Phase 2(캐릭터 시트, 업로드)는 `2010_toon_character_sheet.sql`로 추가 예정 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 lite 복사본(3개 절 제거, 주석) |
| `supabase/monolith/migrations/0002_toon_domain.sql` | 조각 변환본(TN-06-003 스크립트로 재생성) |
| `supabase/monolith/seed.sql` | apps 1행, free(기본)·pro 플랜(AI 키 포함), 크레딧팩 2종, 카탈로그 샘플 팩 1개(draft, 증빙 대기), AI 라우팅 기본값 14행 + 체인 검사 |

2026-10-13 재검증(PGlite `--vector`, `D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs`):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `2000_toon.sql` | 전부 OK |
| `check.mjs --vector mono` 0001 + 0002 + `seed.sql` | 전부 OK |
| 제품 파일 2회 반복 적용 후 `ai_routing_settings`(org null, app toon) | 14행(모듈러·모놀리스) |
| free·pro `features` | 기존 키 + `ai_chat`, `ai_chat_turns_per_day`(20 / 200), `voice_chat`, `dialogue_voice`, `video_voice`(false / true) |
| 기존 RLS 스모크 68항목 | 제품 표·정책 변경이 없어 그대로 유효. 라우팅 행 증가는 `resolve_ai_route` 스냅샷 테스트(TN-06-057)에서 확인 |

AI 기능별 기본값 행(정본 02장 5.1절): `toon.storyboard`, `toon.dialogue`, `chat`(llm, auto, anthropic → openai → google → oss-llm), `toon.consistency`, `toon.prompt_en`, `wiki.query`, `wiki.ingest`, `wiki.lint`(llm, auto, oss-llm → anthropic), `dify.aux`(llm, open_source, oss-llm, 강제), `toon.knowledge`(embedding, open_source, oss-embed), `voice_chat` stt(auto, oss-voice → elevenlabs), `voice_chat` tts·`dialogue_voice` tts(auto, elevenlabs → oss-voice), `video_voice` tts(auto, elevenlabs → oss-voice, 작업 중 대체 금지는 음성 어댑터가 강제).
