# VERIFICATION: 3단계 SQL 통합 검증

검증일 2026-10-12. 도구: PGlite(`docs/products/_tools-sqlcheck/`, prelude가 Supabase auth/roles/storage/realtime/cron/vault를 흉내 냄). 검증 스크립트는 저장소 밖 임시 폴더에서 실행했다. 클라우드 리소스는 쓰지 않았다.

## 1. 요약

| 과제 | 결과 |
|---|---|
| 1. 모듈러 전체 적용(한 DB) | 순서 A(core → seed → 조각 13개), 순서 B(core → 조각 13개 → seed) 모두 OK. 충돌 없음 |
| 2. 제품별 모놀리스 적용 | 14세트 모두 OK |
| 3. 전역 권한 감사 | PUBLIC EXECUTE 남은 함수 0개, search_path 없는 DEFINER 0개, RLS 꺼진 테이블 0개. 낮은 위험 1건(core, 9장) |
| 4. 교차 조직 RLS 스모크 | 제품 테이블 129개 중 B가 A 조직 데이터를 본 테이블 0개, B의 INSERT/UPDATE/DELETE 허용 0건. core 권한 상승/조회 시도 19건 전부 차단 |
| 5. seed 대조 | `seed.sql`을 13개 앱 모놀리스 seed와 같은 값으로 재작성. 플랜/팩 전 행 일치(자동 비교), 적용 순서 무관, 재실행 멱등 |
| 6. 결함 수정 | 조각 수정 0건, core 수정 0건, seed 1건 |

## 2. 과제 1: 모듈러 전체 적용

| 순서 | 적용 파일(순서대로) | 결과 |
|---|---|---|
| A | `0000`~`0007` → `seed.sql` → `1000_publishing` `1100_astro` `1200_video` `1300_blog` `1400_commerce` `1500_microweb` `1600_erp` `1700_sms` `1800_poll` `1900_stock` `2000_toon` `2100_notes` `2200_site` | 22파일 OK |
| B | `0000`~`0007` → 조각 13개(번호순) → `seed.sql` | 22파일 OK |
| C(재실행) | A 순서 뒤에 `seed.sql` → 조각 13개 → `seed.sql`을 한 번 더 | OK. 최종 apps/plans/credit_packs 상태가 A와 같음 |
| A = B | 두 순서의 `core.apps`, `core.plans`, `core.credit_packs` 전체 행 JSON 비교 | 동일(seed 수정 후) |

교차 조각 충돌 점검 결과.

| 항목 | 점검 내용 | 결과 |
|---|---|---|
| 객체 이름 | 조각이 `core.`/`public.`에 함수, 테이블, 트리거를 만들거나 ALTER하는지 | 없음. 모든 조각은 자기 스키마에만 객체를 만든다 |
| core.apps upsert | 13개 조각이 각자 1행 `on conflict (id) do nothing` | 충돌 없음. 최종 값은 seed(`do update`) |
| core.plans/credit_packs | blog, erp, sms, stock, notes 조각이 자기 플랜/팩을 `do nothing`으로 넣음 | 수정 전에는 순서 A에서 seed의 옛 샘플 값이 이겼다(blog free 월 10cr 등). seed를 정본 값으로 바꿔 순서 무관하게 같은 결과 |
| 정책 이름 | `storage.objects` 정책 12개(core 9 + video 1 + toon 2) | 중복 없음 |
| Realtime | `supabase_realtime`에 22개 테이블(core.jobs + 제품 21) | 중복 추가 없음(조각마다 존재 확인 후 추가) |
| Storage 버킷 | `exports`, `org-files`, `public-assets`, `video-media`, `toon-catalog`, `toon-previews`, `toon-user-assets` | id 중복 없음 |
| cron | 조각이 실제로 등록하는 잡 없음(주석 예시만) | 해당 없음 |
| 기본 플랜 | `plans_one_default_per_app_idx` | 앱마다 is_default 정확히 1행(13앱) |

## 3. 과제 2: 제품별 모놀리스 적용

각 세트를 새 DB에 `migrations/*.sql`(번호순) → `seed.sql` 순서로 적용했다.

| 세트 | 파일 | 결과 |
|---|---|---|
| astro-ai | 0001_core_lite, 0002_astro_domain, seed | OK |
| flora-publishing | 0001_core_lite, 0002_publishing_domain, seed | OK |
| live-poll | 0001_core_lite, 0002_poll_domain, seed | OK |
| microweb-studio | 0001_core_lite, 0002_microweb_domain, seed | OK |
| nomad-blog | 0001_core_lite, 0002_blog_domain, seed | OK |
| nomad-commerce | 0001_core_lite, 0002_commerce_domain, seed | OK |
| nomad-video | 0001_core_lite, 0002_video_domain, seed | OK |
| stock-dashboard | 0001_core_lite, 0002_stock_domain, 0003_stock_orders_paper, seed | OK |
| study-note | 0001_core_lite, 0002_study_note_domain, seed | OK |
| toon-factory | 0001_core_lite, 0002_toon_domain, seed | OK |
| website-floria | 0001_core_lite, 0002_website_floria_domain, seed | OK |
| admin-suite/erp | 0001_core_lite, 0002_erp_domain, seed | OK |
| admin-suite/hms | 0001_core_lite, 0002_hms_domain, seed | OK |
| admin-suite/sms | 0001_core_lite, 0002_sms_domain, seed | OK |

## 4. 과제 5: seed 대조와 수정

정본은 각 제품 `01_PRD.md` 4장이고, 그 값을 옮긴 각 모놀리스 `seed.sql`을 기준으로 맞췄다. 수정 후 13개 앱 전부에 대해 모놀리스 DB(`public.plans/credit_packs`)와 통합 DB(`core.plans/credit_packs`)의 행(code, name, 가격, 주기, 월/가입 크레딧, 이월, features, is_default, is_active, sort_order / 팩 code, name, credits, 가격, is_active, sort_order)을 JSON으로 자동 비교해 모두 같음을 확인했다.

| 앱 | 수정 전(`seed.sql` 옛 버전) | 수정 후(모놀리스와 동일) | 근거 문서 |
|---|---|---|---|
| publishing | features 4키 | free/basic features 16키, description 추가. 금액/크레딧 동일 | flora-publishing/01_PRD.md 4장, 06장 R1 |
| astro | starter `signup_credits=30`, features `{"readings":["saju","tarot"],"pdf_themes":2}`. 팩 100/300/1000/2000(보너스 없음, pack_1000 39,900원) | `signup_credits=0`, features에 `combined`, 테마 키 배열, `max_subjects`, `email_delivery`, `welcome_credits=30`. 팩 100 / 330(12,900) / 800(27,900, pack_700) / 2,400(69,900) | astro-ai/01_PRD.md 4장, 8장 D-3 |
| video | 플랜 동일. 팩 정가 4종만 | Advanced 30% 할인 `adv_pack_*` 4종 추가 | nomad-video/01_PRD.md 4장, 06장 |
| blog | free 월 10cr, features 2키. pro/business, 팩은 조각에만 있어 순서 A에서 free가 옛 값 | free 월 20cr + 10키, pro 29,000/300cr, business 99,000/1,500cr, 팩 3종 | nomad-blog/01_PRD.md 4.1절 |
| commerce | free features 3키(`market_api` 없음 → 업로드 CM007 차단, `zip_export` 없음), pro market_slots 8, enterprise 20, 팩 없음 | 4플랜 12키(free `market_api`=쿠팡/스마트스토어, `zip_export=true`, slots 1/3/10/-1, slot_sets, concurrency, image_quality), 팩 50/120/200 | nomad-commerce/01_PRD.md 4.1/4.4절 |
| microweb | free features `{}`, 팩 없음 | features 8키, 팩 pack_30/pack_60(비활성) | microweb-studio/01_PRD.md 4장 |
| erp | default features `{}`, standard 없음 | default/standard features 4키(조각과 같은 값) | admin-suite/01_PRD.md 4절 |
| sms | default features `{}`, standard 없음 | default/standard features 4키 | admin-suite/01_PRD.md 4절 |
| poll | free features `max_participants`만, 이름 Free | free 10키, 이름 `Free(베타)`, pro/business 행(비활성) | live-poll/01_PRD.md 4장 |
| stock | default만 | default + beta(월 300cr) + pro(비활성) | stock-dashboard/01_PRD.md 4장 |
| toon | free/pro features 2키 | 10키, export에 `webtoon_strip`, 팩 100/300 | toon-factory/01_PRD.md 4절 |
| notes | free features `{}` | free 4키, pro(비활성), 팩 2종(비활성) | study-note/01_PRD.md 4장 |
| site | default `{}` | 변경 없음 | website-floria/01_PRD.md 4장 |

astro 가입 크레딧: 통합 seed도 astro 제품 문서의 가정(01_PRD.md 8장 D-3 (b))을 따라 `signup_credits=0`, `features.welcome_credits=30`이다. 30cr은 이메일 인증 또는 Google 로그인 확인 뒤 서버가 `grant_credits`(멱등 키 `signup:<org_id>:astro`)로 지급한다. 사용자가 (a) "가입 즉시 지급"을 고르면 모놀리스와 통합 seed 두 곳을 30으로 바꾸고 서버 지급 경로를 끈다.

기존 DB 갱신 경로: 옛 seed를 적용한 DB에 새 seed를 돌리면 astro `pack_1000`(정본에 없음)은 지우지 않고 `is_active=false`가 된다(`payment_orders` 참조 보호). 옛 seed → 조각 → 새 seed 순서로 확인했다.

## 5. 수정 목록

| 파일 | 위치 | 수정 전 | 수정 후 |
|---|---|---|---|
| `_supabase-modular/seed.sql` | 1-9 | 머리말 "금액과 크레딧은 샘플" | 정본(01_PRD 4장)과 모놀리스 seed 기준, 순서 무관 설명 |
| `_supabase-modular/seed.sql` | 12-27 | apps 13행 | 변경 없음 |
| `_supabase-modular/seed.sql` | 36-140 | 앱별로 흩어진 plans insert 6개(기본 13행 + video/commerce/publishing/toon), 일부 앱은 컬럼 일부만 갱신 | plans insert 1개, 13앱 31행, `description` 포함 전 컬럼 `do update` |
| `_supabase-modular/seed.sql` | 146-182 | credit_packs insert 3개(video 4, astro 4, publishing 2) | insert 1개, 8앱 28행 |
| `_supabase-modular/seed.sql` | 185-187 | 없음 | astro `pack_1000` 판매 중지(update, 멱등) |
| `_supabase-modular/seed.sql` | 193-207 | affiliate_disclosures 12행 | 변경 없음 |
| `_supabase-modular/VERIFICATION.md` | 신규 | 없음 | 이 문서 |

core(`0000`~`0007`)와 제품 조각(`1000`~`2200`), 모놀리스 파일은 수정하지 않았다. 통합 적용과 권한 감사에서 수정이 필요한 결함이 나오지 않았다.

## 6. 과제 3: 전역 권한 감사(모듈러 전체 적용 DB)

대상 스키마: core + 제품 13개. 함수 270개 중 SECURITY DEFINER 208개.

| 점검 | 결과 |
|---|---|
| PUBLIC에 EXECUTE가 남은 함수(전 함수) | 0 |
| `set search_path` 없는 DEFINER | 0 |
| anon/authenticated EXECUTE가 있는 트리거 함수 | 0 |
| anon/authenticated EXECUTE가 있는 DEFINER(트리거 제외) | 120. 전부 파일에서 명시 GRANT. 스키마 기본 권한으로 authenticated에 주는 곳 없음 |
| authenticated EXECUTE가 있는 DEFINER 안에서 `is_privileged_session()`/`current_user` 사용 | 0(그 함수들은 모두 service_role 전용) |
| RLS 꺼진 테이블(core + 제품, 154개) | 0 |
| RLS 켜짐 + 정책 0개(서비스 전용) | core.billing_keys, encrypted_credentials, oauth_states, rate_limit_buckets, webhook_events, erp.join_codes, notes.cost_guard, notes.runtime_config, publishing.waitlist, stock.beta_invites, stock.daily_prices |
| anon 테이블 권한 | core.apps/plans/credit_packs, astro.themes, microweb.templates, microweb.portfolio_items 뿐. 모두 활성/공개 행만 보는 정책 |
| 뷰 | core.credit_balances, toon.catalog_assets는 security_invoker. core.billing_key_summaries, credential_summaries는 owner 뷰(0004에서 org 필터 내장, 이전 단계 검토 대상), credit_ledger_reconciliation은 사용자 권한 없음 |

스키마별 사용자 노출 DEFINER 수.

| 스키마 | authenticated | 그중 anon도 | 호출자 검사 방식 |
|---|---|---|---|
| core | 23 | 7 | `is_service_caller()` + `has_org_role`/`auth.uid()`. anon 7개는 읽기 헬퍼 |
| publishing | 5 | 0 | `is_service_caller()` + 조직 역할 |
| astro | 1 | 0 | 같음 |
| video | 9 | 2 | 같음. anon 2개는 공개 랜딩/링크인바이오 조회 |
| blog | 7 | 0 | 같음 |
| commerce | 1 | 0 | 같음 |
| microweb | 13 | 2 | `microweb.require_org_role`(내부에서 `is_service_caller` 후 NULL 안전 역할 검사). anon 2개는 공개 여부 헬퍼 |
| erp | 19 | 0 | `is_service_caller()` + `erp.has_role/has_access`(auth.uid() not null, exists 기반) |
| sms | 15 | 0 | 같은 구조(`sms.is_admin/is_staff/has_access`). `mark_attendance_bulk`는 `mark_attendance`를 호출해 검사 위임 |
| poll | 10 | 0 | `is_service_caller()` + 조직 역할 |
| stock | 6 | 0 | 같음 |
| toon | 5 | 0 | 같음 |
| notes | 1 | 0 | 같음 |
| site | 5 | 1 | 같음. anon 1개는 `submit_inquiry`(공개 문의 폼, 허니팟/경과시간 검사, 의도된 공개 RPC) |

플래그(의도된 사용자용이 아니거나 호출자 검사가 없는 것).

| 함수 | 노출 | 판단 |
|---|---|---|
| `core.has_entitlement(uuid, text)`, `core.entitled_plan_code(uuid, text)` | anon, authenticated | 호출자 검사 없음. org UUID를 아는 사람은 로그인 없이 그 조직의 앱 이용 여부와 플랜 코드를 알 수 있다. 위험 낮음(UUID 추측 불가, 개인정보 아님). RLS 헬퍼로 쓰이므로 anon 회수 전 anon 정책 의존 여부 확인 필요. core 변경이라 이번에 고치지 않음(10장 결정 1) |
| `core.current_org_ids()`, `current_org_role`, `is_org_member`, `has_org_role`, `is_platform_admin` | anon, authenticated | 모두 `auth.uid()` 기준이라 anon은 빈 값/false. 문제 없음 |

NULL 안전성: 위 헬퍼는 모두 `exists(...)` 또는 `auth.uid() is not null and ...` 형태라 NULL을 돌려주지 않는다. `microweb.require_org_role`은 `p_org_id is null`을 먼저 거부한다.

## 7. 과제 4: 교차 조직 RLS 스모크(통합 DB)

준비: 순서 A로 만든 DB에 사용자 A, B를 `auth.users`에 넣어 개인 조직(owner)을 만들고, 13개 앱 전부를 `core.on_signup_app_bootstrap`으로 두 조직에 부여했다. 이어 제품 테이블 129개 전부에 A 조직 행을 1개 이상 넣었다(테스트 DB에서만 CHECK 제약 제거, 트리거 끔, FK는 A 조직의 부모 행으로 연결. core.affiliate_links, encrypted_credentials, affiliate_accounts도 채움). 승인제 앱 때문에 pending이 된 프로필과 erp/sms 워크스페이스는 active로 바꿔 A가 자기 데이터를 보는지(양성 대조)도 확인했다. 사용자 세션은 `set role authenticated` + JWT claim(sub, role=authenticated)으로 흉내 냈다.

| 구분 | 테이블 수 | A가 자기 행 조회 | B가 A 행 조회 | B가 A 조직으로 INSERT | B가 A 행 UPDATE | B가 A 행 DELETE |
|---|---|---|---|---|---|---|
| org_id가 있는 제품 테이블(사용자 권한 있음) | 110 | 전부 1행 이상 | 전부 0행 | 전부 차단 | 전부 0행 | 전부 0행 |
| 서비스 전용(사용자 권한 없음) | 6 | 권한 거부 | 권한 거부 | 차단 | 차단 | 차단 |
| 전역 카탈로그(org_id 없음, 공개 읽기) | 8 | 보임 | 보임(의도) | 차단 | 0행 | 0행 |
| 전역 카탈로그(게시 상태 행만 공개) | 5 | 0(테스트 행이 미게시 상태) | 0 | 차단 | 0행 | 0행 |
| 합계 | 129 | | B가 A 조직 데이터를 본 테이블 0 | 허용 0 | 허용 0 | 허용 0 |

서비스 전용 6개: erp.join_codes(org_id 있음), notes.cost_guard, notes.runtime_config, publishing.waitlist, stock.beta_invites, stock.daily_prices. 공개 읽기 카탈로그 8개: astro.themes, commerce.exchange_rates, commerce.market_categories, microweb.templates, notes.model_catalog, stock.fundamentals, stock.instruments, stock.market_calendar. 게시 상태 필터 5개: microweb.portfolio_items, toon.asset_packs, toon.assets, toon.characters, video.trend_videos.

core 권한 상승 시도(B 세션).

| 시도 | 결과 |
|---|---|
| A 조직 org_members에 B를 owner로 INSERT | 차단(테이블 쓰기 권한 없음) |
| B 자기 org_members 역할 변경 | 차단 |
| A 조직 org_members UPDATE | 차단 |
| profiles.platform_role = platform_admin | 차단 |
| app_entitlements 자기 플랜을 video advanced로 UPDATE | 차단 |
| app_entitlements INSERT | 차단 |
| subscriptions INSERT | 차단 |
| wallets.pack_balance UPDATE | 차단 |
| credit_ledger INSERT | 차단 |
| `core.grant_credits` 호출 | 차단(EXECUTE 없음) |
| `core.consume_credits`(A 조직) 호출 | 차단(EXECUTE 없음) |
| `core.refund_credits` 호출 | 차단(EXECUTE 없음) |
| `core.bootstrap_app_for_org('video', A 조직)` | 차단(owner/admin only) |
| `core.change_member_role(A 조직, B, owner)` | 차단(owner/admin only) |
| `core.accept_invite(A 조직)`(초대 없음) | 차단(no pending invitation) |
| A의 credit_ledger / wallets / org_members / app_entitlements 조회 | 0행 |

## 8. 실행 방법(재현)

| 단계 | 명령 |
|---|---|
| 통합 순서 A | `cd docs/products/_tools-sqlcheck && node check.mjs A ../_supabase-modular/migrations/000*.sql ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1*.sql ../_supabase-modular/migrations/2*.sql` |
| 통합 순서 B | `node check.mjs B ../_supabase-modular/migrations/000*.sql ../_supabase-modular/migrations/1*.sql ../_supabase-modular/migrations/2*.sql ../_supabase-modular/seed.sql` |
| 모놀리스 | `node check.mjs <제품> ../<제품>/supabase/monolith/migrations/*.sql ../<제품>/supabase/monolith/seed.sql` (admin-suite는 `monolith/{erp,hms,sms}`) |
| 감사/스모크/대조 | 저장소 밖 임시 스크립트(PGlite를 `_tools-sqlcheck/node_modules`에서 import). 필요하면 `_tools-sqlcheck/`로 옮겨 상시 회귀 테스트로 둘 수 있다 |

## 9. 남은 문제

| 번호 | 내용 | 영향 | 필요한 결정 |
|---|---|---|---|
| 1 | `core.has_entitlement`, `core.entitled_plan_code`가 anon에 EXECUTE. 호출자 검사 없음 | org UUID를 아는 비로그인 사용자가 앱 이용 여부/플랜 코드 조회 가능(낮음) | anon 회수 또는 `is_org_member` 조건 추가 여부(core 변경) |
| 2 | 제품 문서의 "모듈러 seed 갱신 요청"(admin-suite 06장, astro R-2, publishing R1, live-poll, microweb, blog, commerce, video, toon 06장)은 이번 seed로 해소됐지만 각 01_PRD/05_DATA_MODEL/06_AGENT_PLAN 본문은 옛 seed 줄 번호와 "샘플 값과 다르다" 문장을 그대로 담고 있다 | 문서 불일치 | 제품 문서 갱신 담당 지정(이번 작업 범위 밖) |
| 3 | astro 가입 크레딧 지급 시점(D-3) | 현재 (b) 인증 후 서버 지급 가정. 서버 지급 경로가 없으면 신규 사용자 0cr | D-3 확정 |
| 4 | 금액/크레딧 상당수가 "제안"(blog, commerce 일부, publishing, toon 팩, stock, poll, notes, microweb, erp/sms) | 확정 시 모놀리스 seed와 통합 seed를 함께 갱신 | 가격 확정 |
| 5 | 알려진 core 기능 요청(이번에 구현하지 않음): `adjust_credits`(운영자 수동 조정), `confirm_payment_order` 실패 상태 영속화, 초대제(`signup_policy='invite'`) 가입 강제 | 각 제품 문서에 우회 방법 기재됨 | core 담당 일정 |
| 6 | PGlite 검증 한계: 실제 Supabase의 `authenticator`/PostgREST 경로, pg_cron/pg_net/vault 실동작, Storage API 서명 URL은 흉내만 냄 | 로컬 Supabase(`supabase db reset`)에서 한 번 더 확인 권장 | 없음 |
