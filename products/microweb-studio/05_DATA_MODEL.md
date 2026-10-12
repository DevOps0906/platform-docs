# 05 데이터 모델: Microweb Studio

정본 SQL: `docs/products/_supabase-modular/migrations/1500_microweb.sql`(아래 `1500:`으로 줄 인용). 모놀리스 사본: `supabase/monolith/migrations/0002_microweb_domain.sql`.

## 1. 개요와 ERD

```
core.organizations (참조만)
  ├── microweb.studio_access (1:1, 초대제 허용 목록)
  ├── microweb.sites ──┬── microweb.site_publications (1:1, 공개 스냅샷, anon 읽기)
  │      │             ├── microweb.site_assets (1:N, Storage 메타)
  │      │             ├── microweb.guestbook_entries (1:N, 하객)
  │      │             └── microweb.rsvp_responses (1:N, 하객)
  │      └── template_id → microweb.templates (전역 카탈로그)
  ├── microweb.leads (스튜디오 조직의 견적 문의)
  └── microweb.production_orders (lead_id?, site_id?)
microweb.portfolio_items (전역)
sites.publish_ledger_id → core.credit_ledger, sites.publish_job_id / site_publications.job_id → core.jobs
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
| `site_assets` | 업로드 메타 | kind hero/gallery/og/bgm/other, storage_path unique(첫 세그먼트 = org_id, 둘째 = microweb), mime 4종, bytes 1~15MB, status uploaded/processing/ready/failed, exif_stripped(ready면 필수, bgm 제외), variants, public_paths, caption 100, sort_order | `1500:190` |
| `guestbook_entries` | 방명록 | author_name 1~20, body 1~500, relation 5종, ai_assisted, status visible/hidden/spam, ip_hash 16~128, moderated_by/at | `1500:219` |
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
| guestbook_entries | anon/auth: visible and `is_guestbook_public(site_id)`; auth: has_studio_access | `submit_guestbook_entry`만 | RPC만 | auth: has_studio_access + owner/admin | anon 7컬럼, auth 10컬럼(ip_hash 제외), delete |
| rsvp_responses | auth: has_studio_access | `submit_rsvp`만 | 없음 | auth: owner/admin | select(ip_hash 제외), delete |
| leads | auth: has_studio_access | `create_lead`만 | RPC만 | `delete_lead` | select(ip_hash 제외) + guard |
| production_orders | auth: has_studio_access | RPC | RPC | 없음 | select + guard |

쓰기 정책을 주는 sites, site_assets는 `DB_CONVENTIONS.md` 8.1 조건을 만족한다: 쓰기 가능한 컬럼은 콘텐츠뿐이고 상태·과금·동의·게시 컬럼은 GRANT에서 빠지며 상태는 트리거가 강제한다.

초대제 베타: core 부트스트랩은 `signup_policy='invite'`를 강제하지 않는다(`_supabase-modular/migrations/0003_core_credits.sql:400-402`는 approval만 처리). 그래서 엔타이틀먼트만 가진 조직(SSO로 `bootstrap_app_for_org('microweb')`를 부른 다른 앱 사용자 포함)은 `studio_access`가 없어 0행이다. 코어 수정은 06장 6절 요청.

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

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

나머지 8건은 `02_ARCHITECTURE.md` 6장. 합계 10건 = 리뷰 "높음" 10건.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/premium-wedding-invitation.md` 3장 #3 | `premium-wedding-invitation/backend/server.js:18,313`, `frontend/vite.config.ts:11-15` | 공개 배포하면 범용 Vertex 프록시가 누구나 쓰는 오픈 프록시가 됨 | 범용 프록시를 만들지 않는다. AI는 `POST /api/public/[slug]/greeting` 하나: 게시 중 사이트(`is_site_live`)만, 고정 purpose·모델·프롬프트, 입력 이름 20자+관계 enum, 출력 200자, `core.rate_limit_hit` IP 5/시간 + 사이트 30일 300, 비용은 `core.ai_usage`. 클라이언트가 모델/헤더를 지정할 수 없다 | 04장 2절, MW-06-016 |
| `docs/reviews/webcraft-agency-simulator.md` 3장 #2 | `webcraft-agency-simulator/backend/.env.local:16-20` | GCP 프로젝트 ID와 PROXY_HEADER가 커밋되어 origin에 push | 노출 사고로 처리: 프록시 시크릿 폐기, GCP 프로젝트 키/ADC 점검, 저장소 공개 여부 확인 후 히스토리 정리 판단(07장 5절). 새 앱은 GCP 변수를 쓰지 않고, `.env*` gitignore + CI 시크릿 스캔(gitleaks)으로 재발 차단. 비밀은 서버 env와 `core` 규칙만(`SECURITY_BASELINE.md` 5장) | MW-06-033, MW-06-034 |

같은 장에 기록하는 데이터 보호 설계(리뷰 "중간" 이하 또는 기획 공백): 방명록 쓰기 무검증(`premium-wedding-invitation.md:65`) → service 전용 함수 + 리밋 + 스팸 검사 + 결과 코드 반환(리밋 카운트가 롤백되지 않게, `1500:1089`), 공개 페이지 개인정보(`00_MERGE_ANALYSIS.md:1083`) → 스냅샷 분리 + noindex + 만료 + 공개 동의 필수.

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

## 9. 마이그레이션 파일

| 파일 | 내용 | 검증(2026-10-12, PGlite) |
|---|---|---|
| `_supabase-modular/migrations/1500_microweb.sql` | 표 10, 트리거 함수 5, 헬퍼 4, 사용자 RPC 10, service RPC 10, 정책 17, 카탈로그 12행 | `node check.mjs mod 0000~0007 seed 1500` OK. 끝에 `revoke execute on all functions in schema microweb from public`(core 0007과 같은 규칙) |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 lite 복사본(3개 절 제거) | `node check.mjs mono 0001 0002 seed` OK |
| `supabase/monolith/migrations/0002_microweb_domain.sql` | 모듈러 조각의 public 변환본 | 위와 같음 |
| `supabase/monolith/seed.sql` | apps, free 플랜, 크레딧팩 2(비활성), 포트폴리오 초안 4(draft) | 위와 같음 |

RLS 스모크(모듈러 87/87, 모놀리스 87/87 통과) 주요 항목: B가 A 조직의 sites/site_assets/leads/production_orders/studio_access/rsvp 0행, A 초안 스냅샷 0행, 숨긴 방명록 0행 / B의 A 사이트 UPDATE·DELETE 0행, 직접 INSERT 42501, A 대상 사용자 RPC 9종 42501, service 전용 RPC 9종 42501 / B가 자기 sites.status·publish_charged_at·disclosure_consent_at, studio_access, app_entitlements, subscriptions, wallets, credit_ledger, grant/consume_credits, org_members.role, profiles.platform_role 변경 42501 / 엔타이틀먼트만 있는 C는 create_site 42501, 0행 / anon은 게시 중 스냅샷 1행, org_id·ip_hash 컬럼 42501, sites/rsvp/leads 등 42501 / 방명록 3건 후 rate_limited, 링크 spam, 미게시 closed / 상태 위반 MW001, slug 잠금 MW002, 동의 없음 MW006, 미결제 MW008 / 중단 후 anon 0행, 만료 처리, 도메인 파일 재적용 OK. 스크립트는 MW-06-030에서 저장소 `supabase/tests/`로 옮긴다.
