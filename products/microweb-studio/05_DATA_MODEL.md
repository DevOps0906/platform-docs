# 05 데이터 모델: Microweb Studio

정본 SQL: `docs/products/_supabase-modular/migrations/1500_microweb.sql`(아래 `1500:`으로 줄 인용). 모놀리스 사본: `supabase/monolith/migrations/0002_microweb_domain.sql`.

2026-10-13 개정: AI·음성 기본값과 음성 연결을 1500 조각 20절(`1500:1549-1674`)로 더했다. 20절은 파일 끝에만 붙였고 기존 표 정의의 줄 번호(`1500:37` 등)는 그대로다. 제품 전용 AI 표는 만들지 않았고 방명록 항목에 컬럼 2개(`voice_job_id`, `has_voice`), service 전용 함수 1개(`attach_guestbook_voice`), `site_assets.kind`에 `voice` 값 1개만 더했다(6절에 이유).

## 1. 개요와 ERD

```
core.organizations (참조만)
  ├── microweb.studio_access (1:1, 초대제 허용 목록)
  ├── microweb.sites ──┬── microweb.site_publications (1:1, 공개 스냅샷, anon 읽기)
  │      │             ├── microweb.site_assets (1:N, Storage 메타. kind voice = 인사말 음성 mp3)
  │      │             ├── microweb.guestbook_entries (1:N, 하객. voice_job_id → core.voice_jobs 0..1)
  │      │             └── microweb.rsvp_responses (1:N, 하객)
  │      └── template_id → microweb.templates (전역 카탈로그)
  ├── microweb.leads (스튜디오 조직의 견적 문의)
  └── microweb.production_orders (lead_id?, site_id?)
microweb.portfolio_items (전역)
sites.publish_ledger_id → core.credit_ledger, sites.publish_job_id / site_publications.job_id → core.jobs
guestbook_entries.voice_job_id → core.voice_jobs (하객 음성 원본은 voice-audio 버킷, 20.4절)
```

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 모든 테넌트 표에 `org_id`(cascade), `created_at`, UPDATE 가능한 표에 `updated_at` + `core.set_updated_at`(`1500:329`). 상태는 text + CHECK.

| 표 | 목적 | 주요 컬럼(타입, 제약) | 줄 |
|---|---|---|---|
| `templates` | nexus 12개 모델 카탈로그 | code unique `^[a-z][a-z0-9_]{2,40}$`, kind(12종), status planned/beta/released/retired, release_phase mvp/phase2/phase3/backlog, agency_price_min/max_krw(범위 검사), self_publish_credits, allowed_blocks/required_blocks(text[], required ⊂ allowed), default_content, preview_mockup jsonb | `1500:37` |
| `portfolio_items` | 쇼룸 포트폴리오 | slug, category microweb/website/detail_page, tier, external_url https만, image_path, client_permission_at, status draft/published/hidden. published는 동의와 이미지 필수 | `1500:71` |
| `studio_access` | 초대제 베타 허용 목록 | org_id PK, mode agency/self_service, max_active_sites 0~1000(기본 3), granted_by/at, revoked_at | `1500:95` |
| `sites` | 편집본 | template_id, kind, slug unique(4~40자, 예약어 금지), title 1~80, status 7종, content jsonb object 256KB, event_at, expires_at(예식+365일 이하), 토글 3개, noindex(기본 true, 사용자 변경 불가), 공개 동의 3컬럼, preview_token_hash/expires_at, customer_approved_at/name, publish_ledger_id, publish_charged_at, publish_job_id, 전이 시각들 | `1500:112` |
| `site_publications` | 공개 스냅샷 | site_id PK, slug unique, version, content, og_title 80/og_description 160/og_image_url https, is_live, published_at, expires_at not null, unpublished_at, job_id | `1500:167` |
| `site_assets` | 업로드 메타 | kind hero/gallery/og/bgm/voice/other, storage_path unique(첫 세그먼트 = org_id, 둘째 = microweb), mime 4종(voice는 audio/mpeg만), bytes 1~15MB, status uploaded/processing/ready/failed, exif_stripped(ready면 필수, bgm·voice 제외), variants, public_paths, caption 100, sort_order | `1500:190`, kind `voice`는 20.5절 `1500:1665-1674`가 제약 3개를 교체 |
| `guestbook_entries` | 방명록 | author_name 1~20, body 1~500, relation 5종, ai_assisted, status visible/hidden/spam, ip_hash 16~128, moderated_by/at. 20.4절 추가: `voice_job_id`(→ core.voice_jobs, on delete set null, 작업당 1개 유니크), `has_voice`(generated: voice_job_id is not null) | `1500:219`, `1500:1613-1621` |
| `rsvp_responses` | 참석 여부 | guest_name 1~20, side side_a/side_b/none, attending yes/no/undecided, party_size 1~10, meal, message 200, ip_hash | `1500:242` |
| `leads` | 견적 문의 | source 5종, name 1~40, phone(국내 형식)/email(형식) 중 하나 필수, kind, template_code, tier, industry, event_on date, simulator jsonb 8KB, message 2000, privacy_consent_at not null, status 6종, status_note, ip_hash, purge_after 기본 +1년 | `1500:260` |
| `production_orders` | 대행 제작 장부 | lead_id/site_id(set null), customer_name, amount_krw 0~1억, status 7종, payment_method 4종, payment_reference(12자리 이상 숫자열 금지), 전이 시각들, paid 이후 상태는 paid_at+method 필수 | `1500:296` |

## 3. 상태 전이

전이 트리거는 service_role 쓰기에도 적용된다(`DB_CONVENTIONS.md` 10장). 위반은 MW001.

### sites (`1500:375`)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| (INSERT) | draft만 | `create_site` | 감사 `site.create` |
| draft | review, publishing, archived | review: member 이상(`transition_site`) / publishing: `request_publish` / archived: owner/admin | review 전 시안 토큰 발급 가능 |
| review | draft, publishing, archived | 같음 | - |
| publishing | published, draft, unpublished, expired | `finalize_publish` / `fail_publish`(service) | 스냅샷 생성 또는 이전 상태 복구. 30분 초과는 `expire_sites`가 실패 처리 |
| published | publishing(재게시), unpublished, expired | `request_publish` / owner/admin / `expire_sites` | 중단·만료 시 스냅샷 is_live=false, 파생본 삭제 잡 |
| unpublished | publishing, expired, archived | owner/admin / service | - |
| expired | publishing(만료일 연장 후), archived | owner/admin | - |
| archived | 없음(종단) | - | 30일 뒤 `site.purge` |

편집 잠금(`1500:409`): 사용자 세션은 publishing/archived 편집 불가(MW003), 만료일은 미래만, 첫 게시 뒤 slug는 누구도 변경 불가(MW002). 만료일 변경은 트리거가 스냅샷에 반영(`1500:439`).

### leads (`1500:456`)

| 현재 | 허용 전이 | 누가 |
|---|---|---|
| new | contacted, quoted, lost, spam | member 이상(`set_lead_status`) |
| contacted | quoted, won, lost, spam | 같음 |
| quoted | won, lost, spam | 같음 |
| lost | contacted | 같음 |
| won, spam | 없음 | - |

### production_orders (`1500:480`)

| 현재 | 허용 전이 | 누가 | 조건 |
|---|---|---|---|
| (INSERT) | quoted만 | owner/admin | - |
| quoted | paid, canceled | owner/admin | paid는 결제수단 필수 |
| paid | in_production, refunded | owner/admin | - |
| in_production | delivered, refunded | owner/admin | - |
| delivered | closed, refunded | owner/admin | - |
| closed, canceled, refunded | 없음 | - | - |

guestbook_entries.status는 visible/hidden/spam 사이를 `moderate_guestbook_entry`로만 바꾼다(사용자 UPDATE GRANT 없음).

## 4. RLS 정책

모든 표 RLS ON, `revoke all ... from public, anon, authenticated` 뒤 허용 목록만(`1500:1332`). 함수는 개별 revoke + 스키마 전체 PUBLIC EXECUTE 회수(`1500:1506`). `has_studio_access(org) = is_org_member and has_entitlement(org,'microweb') and 허용 목록`(`1500:514`).

| 표 | SELECT | INSERT | UPDATE | DELETE | GRANT |
|---|---|---|---|---|---|
| templates | anon/auth: status <> retired | service | service | service | select(anon, auth) + guard 트리거 |
| portfolio_items | anon/auth: published | service | service | service | select + guard |
| studio_access | auth: `is_org_member(org_id)` | service | service | service | select + guard |
| sites | auth: `has_studio_access` | `create_site` RPC만 | auth: has_studio_access + owner/admin/member, using/with check 동일 | 없음(보관 후 워커) | select, update(title, content, event_at, expires_at, slug, 토글 3개) |
| site_publications | anon/auth: `is_live and expires_at > now()`; auth: has_studio_access | DEFINER/서비스 | DEFINER/서비스 | cascade | anon: 공개 9컬럼만(org_id 제외), auth: 전체 select + guard |
| site_assets | auth: has_studio_access | service(업로드 완료 라우트) | auth: 같음 | service | select, update(caption, sort_order) |
| guestbook_entries | anon/auth: visible and `is_guestbook_public(site_id)`; auth: has_studio_access | `submit_guestbook_entry`만 | RPC만 | auth: has_studio_access + owner/admin | anon 7컬럼 + `has_voice`, auth 10컬럼 + `has_voice`(ip_hash, `voice_job_id` 제외), delete(UI는 `DELETE /api/studio/guestbook/[id]`로 음성 파일과 함께 삭제) |
| rsvp_responses | auth: has_studio_access | `submit_rsvp`만 | 없음 | auth: owner/admin | select(ip_hash 제외), delete |
| leads | auth: has_studio_access | `create_lead`만 | RPC만 | `delete_lead` | select(ip_hash 제외) + guard |
| production_orders | auth: has_studio_access | RPC | RPC | 없음 | select + guard |

쓰기 정책을 주는 sites, site_assets는 `DB_CONVENTIONS.md` 8.1 조건을 만족한다: 쓰기 가능한 컬럼은 콘텐츠뿐이고 상태·과금·동의·게시 컬럼은 GRANT에서 빠지며 상태는 트리거가 강제한다.

초대제 베타: 코어는 `signup_policy='invite'` 앱에서 가입 트리거가 구독·엔타이틀먼트를 만들지 않고 `bootstrap_app_for_org`는 비 service 호출자에 42501을 낸다(2026-10-13 코어 반영, 운영자 service_role은 가능). `studio_access`는 2차 게이트로 유지하므로 엔타이틀먼트만 가진 조직도 `studio_access`가 없으면 0행이다.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `site_publications_live_idx (slug) where is_live` | 하객 페이지 slug 조회(가장 잦음) |
| `guestbook_entries_site_idx (site_id, created_at desc) where visible` | 하객 방명록 목록 |
| `guestbook_entries_dedupe_idx (site_id, ip_hash, created_at desc)` | 1시간 중복 검사 |
| `sites_org_status_idx`, `sites_expiry_idx`, `sites_publishing_idx` | 스튜디오 목록, 만료 스캔, 정체 게시 스캔 |
| `site_assets_site_idx (site_id, kind, sort_order)` | 편집기, 게시 잡 |
| `rsvp_responses_site_idx`, `leads_org_status_idx`, `leads_purge_idx`, `production_orders_*` | 관리 화면, 정리 |
| `templates_status_sort_idx`, `portfolio_items_status_sort_idx` | 쇼룸 |

정책의 DEFINER 헬퍼는 STABLE이라 문장당 캐시된다. 하객 페이지는 anon 1회 조회 + CDN 30초.

## 6. 코어 참조

| core 객체 | 용도 | ALTER |
|---|---|---|
| `organizations`, `org_members` | FK, 역할 판정(`has_org_role`, `is_org_member`), `request_publish`의 actor 확인 | 없음 |
| `app_entitlements` via `has_entitlement` | 앱 접근 | 없음 |
| `credit_ledger` | 셀프 게시 차감 원장 FK와 검증 | 없음 |
| `jobs` | 게시 잡 FK | 없음 |
| `rate_limit_hit` | 하객/문의 리밋 | 없음 |
| `write_audit` | 모든 RPC 감사 | 없음 |
| `set_updated_at`, `guard_privileged_write`, `is_service_caller`, `is_privileged_session` | 트리거, 호출자 판정 | 없음 |
| `apps` | `microweb` 행(on conflict do nothing) | 없음 |
| Storage `org-files`, `public-assets` | 원본, 게시 파생본 | 없음 |

AI·음성 코어 객체(2026-10-13, `docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | microweb 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 제작 상담 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `microweb.invitation_copy`, `microweb.guest_greeting` 실행 기록, 위키 lint 결과 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`), 하객 기능 비용 추적 | FastAPI, Next.js 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 12행(9절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 문구 코퍼스·템플릿 설명·위키 컬렉션(지식 조직만) | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 이벤트 종류별 문구 위키(지식 조직만) | FastAPI(쓰기), Next.js 서버(스튜디오 읽기) |
| `voice_sessions`, `voice_jobs`, `voice-audio` 버킷, `expire_voice_audio` | 스튜디오 음성 대화(`store_audio=false`), 인사말 TTS 작업, 하객 음성 방명록(`store_audio=true`, `third_party_notice`) | Next.js, 워커(만료 삭제) |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |

제품 AI 표를 만들지 않은 이유(`docs/products/_platform-core/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 문구 제안 결과 표 | 3안과 구성 제안을 저장 | `core.ai_runs.output`(실행 기록) + 적용한 블록은 `sites.content` 자체. 적용 이벤트는 감사 `site.ai_copy_apply` |
| 대화-사이트 연결 표 | 상담이 어느 사이트를 근거로 하는지 | Dify 입력 `site_id`(대화 시작 때) + FastAPI가 매핑 org와 사이트 org를 매번 대조 |
| 음성 동의 표 | 스튜디오 음성 처리 고지 증빙 | `core.audit_log` 감사 `voice.consent`(행위자·고지문 버전, 사용자 세션 `write_audit`) |
| 하객 음성 표 | 음성 메시지와 방명록 연결 | **필요**: 하객 화면이 "음성이 있는 항목"을 알아야 하므로 `guestbook_entries`에 컬럼 2개만 더한다. 음성 원본·동의·만료는 `core.voice_jobs`가 이미 가진다 |
| 인사말 음성 표 | 인사말 mp3 위치 | `site_assets` kind `voice`(제약 교체만) + 인사말 블록 `voice_asset_id`(content JSON) |
| 코퍼스 문서 표 | 원고 관리 | `core.ai_documents`(지식 조직) + 원고 파일 `content/copy/` |

조각은 `core.*`를 ALTER하지 않는다. 20.2절의 `core.plans` UPDATE는 microweb 자신의 `free` 행 `features`에 AI 키를 병합하는 데이터 변경이며 표 구조는 바꾸지 않는다. 20.5절의 제약 교체와 20.4절의 컬럼 추가는 microweb 표에만 적용한다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

나머지 8건은 `02_ARCHITECTURE.md` 6장. 합계 10건 = 리뷰 "높음" 10건.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/premium-wedding-invitation.md` 3장 #3 | `premium-wedding-invitation/backend/server.js:18,313`, `frontend/vite.config.ts:11-15` | 공개 배포하면 범용 Vertex 프록시가 누구나 쓰는 오픈 프록시가 됨 | 범용 프록시를 만들지 않는다. 하객 공개 AI는 라우트 2개뿐이다: `POST /api/public/[slug]/greeting`, `POST /api/public/[slug]/guestbook/voice/transcribe`. 게시 중 사이트(`is_site_live`)만, 고정 라우팅 기능 키(`microweb_greeting`, `microweb_guestbook_voice`)와 서버 상수 프롬프트, 입력은 enum(관계, 어조)과 길이 제한된 오디오뿐(자유 문자열 0), 출력 200자, `core.rate_limit_hit`(축하말 IP 5/시간 + 사이트 30일 300, 음성 IP 해시당 10분 2건 + 사이트 하루 50건 + 30일 100건), 비용은 `core.ai_usage`. 클라이언트가 모델/헤더를 지정할 수 없다. 하객 음성은 오픈소스 강제(`force_open_source`)라 키 도용 대상이 되는 상용 키 경로가 없다 | 04장 2절, MW-06-016, MW-06-051 |
| `docs/reviews/webcraft-agency-simulator.md` 3장 #2 | `webcraft-agency-simulator/backend/.env.local:16-20` | GCP 프로젝트 ID와 PROXY_HEADER가 커밋되어 origin에 push | 노출 사고로 처리: 프록시 시크릿 폐기, GCP 프로젝트 키/ADC 점검, 저장소 공개 여부 확인 후 히스토리 정리 판단(07장 5절). 새 앱은 GCP 변수를 쓰지 않고, `.env*` gitignore + CI 시크릿 스캔(gitleaks)으로 재발 차단. 비밀은 서버 env와 `core` 규칙만(`SECURITY_BASELINE.md` 5장) | MW-06-033, MW-06-034 |

같은 장에 기록하는 데이터 보호 설계(리뷰 "중간" 이하 또는 기획 공백): 방명록 쓰기 무검증(`premium-wedding-invitation.md:65`) → service 전용 함수 + 리밋 + 스팸 검사 + 결과 코드 반환(리밋 카운트가 롤백되지 않게, `1500:1089`), 공개 페이지 개인정보(`00_MERGE_ANALYSIS.md:1083`) → 스냅샷 분리 + noindex + 만료 + 공개 동의 필수. 하객 음성(2026-10-13): 제3자 목소리라 `voice_jobs`의 `third_party_notice` 고지 제약(`0009_core_voice.sql:61-63`)으로 고지 없는 보관을 DB가 거부하고, 원본은 비공개 `voice-audio` 버킷에 두며 읽기 정책 없이 서버가 5분 서명 URL로만 중계하고, `expires_at`과 `site.purge`로 삭제한다. `voice_job_id`는 어떤 사용자 역할에도 GRANT하지 않는다(`has_voice`만 공개).

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `microweb` | `public`(코어 lite와 같은 스키마). 사용자 최종 확인 대기 |
| 코어 | 0000~0006 | `0001_core_lite.sql`: SECTION 6-A(oauth_states), 6-B(encrypted_credentials), 9(affiliate) 제거, 주석으로 사유 기록. Toss(3), 크레딧(4), 레이트 리밋(6-C), 잡(7), Storage(8) 유지 |
| 도메인 | `1500_microweb.sql` | `0002_microweb_domain.sql`: '@modular-only' 블록 제거, `core.`/`microweb.` → `public.` 기계 변환(본문 동일) |
| 앱 등록 | 조각 머리 + 모듈러 seed | `seed.sql`(`apps.schema_name='public'`) |
| 기본 권한 | 스키마 기본 권한 없음 | Supabase public 기본 권한을 코어 lite가 회수 + 도메인 파일이 표마다 revoke 후 GRANT |
| 플랜 features | 모듈러 seed는 `{}`(코드 기본값 사용) | `seed.sql`에 01장 4절 키 |
| 가입 | `signup_app='microweb'` 필요 | apps 1행이라 자동 부트스트랩 |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql` | `0001_core_lite.sql` SECTION 11·12 (이미 포함) |
| AI 라우팅 기본값 | 1500 조각 20.1~20.3절(`@modular-only` 블록, 체인 검사 포함) | `seed.sql` 끝(같은 12행 + 체인 검사). 기능 키는 점(.) 대신 밑줄(`microweb_copy`)이라 변환기가 건드리지 않는다 |
| 음성 연결 | 20.4~20.5절 | 같은 본문(`public.` 접두사 변환) |
| free 플랜 AI 키 | 20.2절 병합 UPDATE (모듈러 seed 반영은 06장 R-8) | `seed.sql` free 행 `features`에 직접 |

## 9. 마이그레이션 파일

| 파일 | 내용 | 검증(2026-10-12, PGlite) |
|---|---|---|
| `_supabase-modular/migrations/1500_microweb.sql` | 표 10, 트리거 함수 5, 헬퍼 4, 사용자 RPC 10, service RPC 11(`attach_guestbook_voice` 추가), 정책 17, 카탈로그 12행, 20절 AI·음성 기본값(라우팅 12행, free 플랜 AI 키, 체인 검사, 방명록 음성 컬럼, `site_assets.kind` voice) | `node check.mjs --vector mod 0000~0009 seed 1500` OK. 18절 끝의 `revoke execute on all functions in schema microweb from public`(core 0007과 같은 규칙)이 20절보다 앞이라 새 함수는 20.4절에서 개별 revoke/grant |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 lite 복사본(3개 절 제거) | `node check.mjs mono 0001 0002 seed` OK |
| `supabase/monolith/migrations/0002_microweb_domain.sql` | 모듈러 조각의 public 변환본(20.4~20.5절 포함, 20.1~20.3은 seed에) | 위와 같음 |
| `supabase/monolith/seed.sql` | apps, free 플랜(AI 키 포함), 크레딧팩 2(비활성), 포트폴리오 초안 4(draft), AI 라우팅 기본값 12행 + 체인 검사 | 위와 같음 |

RLS 스모크(모듈러 87/87, 모놀리스 87/87 통과) 주요 항목: B가 A 조직의 sites/site_assets/leads/production_orders/studio_access/rsvp 0행, A 초안 스냅샷 0행, 숨긴 방명록 0행 / B의 A 사이트 UPDATE·DELETE 0행, 직접 INSERT 42501, A 대상 사용자 RPC 9종 42501, service 전용 RPC 9종 42501 / B가 자기 sites.status·publish_charged_at·disclosure_consent_at, studio_access, app_entitlements, subscriptions, wallets, credit_ledger, grant/consume_credits, org_members.role, profiles.platform_role 변경 42501 / 엔타이틀먼트만 있는 C는 create_site 42501, 0행 / anon은 게시 중 스냅샷 1행, org_id·ip_hash 컬럼 42501, sites/rsvp/leads 등 42501 / 방명록 3건 후 rate_limited, 링크 spam, 미게시 closed / 상태 위반 MW001, slug 잠금 MW002, 동의 없음 MW006, 미결제 MW008 / 중단 후 anon 0행, 만료 처리, 도메인 파일 재적용 OK. 스크립트는 MW-06-030에서 저장소 `supabase/tests/`로 옮긴다.

2026-10-13 재검증(PGlite `--vector`, `docs/products/_tools-sqlcheck/check.mjs`와 임시 기능 검사 29항목, 모듈러·모놀리스 각각):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `1500_microweb.sql` | 전부 OK |
| `check.mjs --vector mono` 0001 + 0002 + `seed.sql` | 전부 OK |
| 제품 파일 2회 반복 적용 후 `ai_routing_settings`(org null, app microweb) | 12행(모듈러·모놀리스) |
| free `features` | 기존 키 + `ai_copy`, `ai_copy_runs_per_site_30d`(20), `ai_chat`, `ai_chat_turns_per_day`(100), `voice_chat`, `voice_greeting`, `guestbook_voice`, `guestbook_voice_per_site_30d`(100) |
| 미동의 조직 `resolve_ai_route` | `microweb_copy` = oss-llm, `microweb_voice_greeting` = oss-voice, `voice_chat` stt = oss-voice, `microweb_knowledge` = oss-embed |
| 동의 후 | `microweb_copy` = anthropic > openai > google > oss-llm, `microweb_greeting` = oss-llm > anthropic, `microweb_voice_greeting` = elevenlabs > oss-voice, `dify.aux`와 `microweb_guestbook_voice`는 동의 전후 모두 oss만 |
| `attach_guestbook_voice` | 정상 `ok`, 같은 항목·작업 재사용 `already`, 다른 기능·`self` 동의·미보관·미완료 작업 `invalid`, 없는 항목 `not_found`. anon·authenticated 실행 거부 |
| 컬럼 권한 | anon·authenticated는 `has_voice` 조회 가능, `voice_job_id` 조회는 permission denied |
| `site_assets` | kind `voice` + mp3 OK(EXIF 없이 ready OK), voice + 이미지 mime 거부, hero + mp3 거부, hero ready EXIF 없음 거부 |

RLS 스모크(기존 87항목)에 위 항목을 더한 목록은 MW-06-030이 `supabase/tests/`로 옮길 때 확정한다.

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경은 없다(코어 계약 그대로). 정본 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.2~2.3절. 공통 스크립트 `scripts/dev/seed-users.mjs --app microweb`이 공통 행을 만든 뒤 제품 훅 `scripts/dev/seed-users.microweb.mjs`가 아래 microweb 행을 처리한다(MW-06-003 소유). 대상 Supabase가 `127.0.0.1`/`localhost`가 아니면 즉시 종료하고, 이메일은 `<key>@dev.test`, 비밀번호는 `DEV_SEED_PASSWORD`다.

invite 앱 특이점: 가입 트리거는 `signup_app='microweb'`이어도 엔타이틀먼트를 만들지 않는다(`docs/products/_supabase-modular/migrations/0001_core_identity.sql:149-155`, 모놀리스도 apps 1행 자동 선택 뒤 같은 검사를 한다 `supabase/monolith/migrations/0001_core_lite.sql:260-266`). 그래서 공통 행의 "`signup_app=<app>`으로 생성 → `entitled=true`"가 이 제품에서는 성립하지 않고, 훅이 운영자 초대 경로(MW-06-026)와 같은 service_role 호출로 권한을 만든다.

### 10.1 공통 페르소나와 제품 훅 행 (AUTH_ROADMAP 2.2절·8장 microweb 행: `studio_access` 허용·미허용)

invite 앱이라 공통 행도 훅이 권한을 만들므로 한 표에 적는다. 제품 행은 `studio_denied`(미허용)이고 `owner`가 허용 쪽 기준 페르소나다.

| 키 | 만드는 방법(RPC/서비스 경로) | 기대 결과 | 쓰임 |
|---|---|---|---|
| `owner` | 공통 생성 후 훅: service_role `core.bootstrap_app_for_org('microweb', <owner 개인 조직>)`(`0003_core_credits.sql:440`) + service INSERT `microweb.studio_access(org_id, mode='agency', max_active_sites=3, granted_by=ops)`. 출력된 조직 id를 `.env.local`의 `MICROWEB_STUDIO_ORG_ID`에 넣는다(문의 `create_lead`는 agency 허용 목록 조직만 받는다, `1500_microweb.sql:1233`) | `session_context('microweb')` `entitled=true`, plan `free`, `has_studio_access=true`. `/studio` 진입, `create_site` 성공 | 기본 운영자(studio_access 허용) |
| `admin`, `member`, `viewer` | 공통: owner 세션으로 `core.invite_member(owner_org, uid, role)`, 각자 `core.accept_invite(owner_org)`(`0004_core_security.sql:317`, `:353`). 엔타이틀먼트·허용 목록은 owner 조직 것을 쓴다 | `session_context('microweb', <owner_org>)`에서 해당 역할, `has_studio_access(owner_org)=true`. member는 방명록 삭제 버튼 없음, viewer는 쓰기 RPC 42501 | 역할 분기 |
| `outsider` | 공통 생성 후 훅: 자기 개인 조직에 `bootstrap_app_for_org` + `studio_access`(agency) | 자기 조직에서는 `/studio` 사용 가능. owner 조직 sites·leads·production_orders 0행, owner 조직 대상 RPC 42501 | 교차 테넌트 RLS 거부 |
| `studio_denied` | 훅: 생성 후 `bootstrap_app_for_org`만, `studio_access` 행 없음 | `entitled=true`이지만 `has_studio_access=false`. `/studio` → `/pending`, sites 0행, `create_site` 42501(MW-F-024 수용 기준) | studio_access 미허용(2차 게이트) |
| `no_app` | 공통(`signup_app` 없이 생성). 훅은 아무것도 하지 않는다 | 모듈러·모놀리스 모두 `entitled=false`(invite 앱은 자동 부트스트랩 안 됨). 로그인 직후 `finishLogin`이 `/no-access`, `bootstrap_app_for_org` 호출 0 | 초대받지 않은 이메일로 로그인한 경우(B단계 `/no-access`)를 A단계에서 미리 검증 |
| `suspended` | 공통: service_role로 `status=suspended`. 훅이 `owner`처럼 권한을 먼저 부여 | 403 | 차단 확인 |
| `ops` | 공통: service_role로 `platform_role=platform_admin` | `/studio/admin/*`, `POST /api/admin/invites`·`/access` 허용(다른 페르소나는 403) | 운영자 초대·허용 목록 관리(MW-06-026), 지식·위키 관리 |
| `pending` | 만들지 않는다(approval 앱 전용) | - | - |
| 하객·시안·쇼룸 방문자 | 만들지 않는다. Supabase Auth 사용자가 아니다 | E2E는 페르소나 없이 `/i/[slug]`, `/p/[token]`, `/contact`를 연다(F2, F3, F8) | 로그인 없는 흐름(02장 9.5절) |

### 10.2 규칙과 모놀리스·모듈러 차이

| 규칙 | 내용 |
|---|---|
| 약관 동의 | A단계에는 약관 단계가 없다. B에서 MW-06-054가 약관 가드와 기록 방식(03장 7절)을 정하면 이 훅이 페르소나마다 동의 기록을 만든다(054가 003 소유 훅에 1줄 요청) |
| 멱등 | 이미 있는 이메일은 건너뛰고 역할·상태·`studio_access`만 맞춘다. `bootstrap_app_for_org`는 구독·엔타이틀먼트를 `on conflict do nothing`으로 만들고 free 플랜은 가입·월 크레딧이 0이라 원장 행이 생기지 않는다 |
| 모놀리스/모듈러 차이 | 모듈러 `--app microweb`과 모놀리스(`public` 스키마, `bootstrap_app_for_org`는 `public.`)는 같은 훅 순서를 쓴다. 차이는 함수 스키마 접두사(`SUPABASE_DB_SCHEMA`)뿐이고, `no_app`이 모놀리스에서도 `entitled=false`인 점이 공통 표(`AUTH_ROADMAP.md:59`)와 다르다(invite 검사 때문) |
| 셀프서비스(Phase 2) | `studio_access.mode='self_service'` 페르소나(`owner_self`, 제안)는 MW-06-027 착수 때 훅에 더한다 |
| 브리지 경로(C2) | 네이버 브리지를 택하면 코어 `core.auth_identity_links`(`docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`)를 참조만 한다. 제품 표는 만들지 않는다 |
