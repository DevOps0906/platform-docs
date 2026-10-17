# _supabase-modular: 통합 Supabase 프로젝트

## 1. 이것은 무엇인가

Supabase 프로젝트 1개에 `core` 스키마와 제품별 스키마를 함께 두는 "모듈러(통합) DB"의 정본이다. 인증, 조직, 플랜, 구독, 결제, 크레딧 원장, 보안 헬퍼, 잡 테이블을 `core`에 한 번만 정의하고, 각 제품은 자기 스키마에 도메인 테이블만 만든다. 모든 제품이 같은 사용자 계정(SSO)과 같은 크레딧 지갑(조직당 1개)을 공유한다.

여기 있는 것은 문서와 SQL뿐이다. 클라우드 리소스를 만들지 않는다. 실제 프로젝트에 적용할 때는 이 폴더를 저장소의 `supabase/`로 복사하거나 심볼릭 링크로 연결한다.

| 항목 | 값 |
|---|---|
| Supabase 프로젝트 수 | 1 (hms 제외) |
| PostgreSQL | 15 |
| 공통 스키마 | `core` |
| 제품 스키마 | `publishing`, `astro`, `video`, `blog`, `commerce`, `microweb`, `erp`, `sms`, `poll`, `stock`, `toon`, `notes`, `site`, `docs`, `news`, `trailer` |
| 제외 | `hms` (병원). 의료정보 격리 때문에 별도 프로젝트(모놀리스)로만 운영 |
| 멱등성 | 모든 core 마이그레이션은 반복 실행 가능 (`if not exists`, `create or replace`, `drop ... if exists`) |

## 2. 파일 목록과 적용 순서

| 순서 | 파일 | 내용 |
|---|---|---|
| 1 | `migrations/0000_core_extensions_and_schema.sql` | pgcrypto, `core` 스키마, 기본 권한, `set_updated_at`, `jwt_role`, `is_privileged_session`, `guard_privileged_write` |
| 2 | `migrations/0001_core_identity.sql` | `profiles`, `organizations`, `org_members`, 가입 트리거(개인 조직 + owner 멤버십 + 앱 부트스트랩 호출), `personal_org_id()` |
| 3 | `migrations/0002_core_billing.sql` | `apps`, `plans`, `credit_packs`, `billing_keys`, `subscriptions`, `app_entitlements`, `payment_orders`, `payments`, `webhook_events`, 구독 상태 머신 `apply_subscription_transition()` |
| 4 | `migrations/0003_core_credits.sql` | `wallets`, `credit_ledger`(append-only), `ai_usage`, `credit_balances` 뷰, `consume_credits` / `grant_credits` / `refund_credits`, `run_monthly_credit_grants()`, 가입 부트스트랩 실제 구현, `confirm_payment_order()`, `purge_organization()` |
| 5 | `migrations/0004_core_security.sql` | 헬퍼 `is_org_member` / `has_org_role` / `has_entitlement` / `current_org_ids` / `is_platform_admin` / `session_context`, core 전 테이블 RLS 정책, 권한 컬럼 보호 트리거, 멤버 관리 함수, `audit_log`, `oauth_states`, `encrypted_credentials`, `rate_limit_buckets` |
| 6 | `migrations/0005_core_jobs_storage.sql` | `jobs` + `enqueue_job` / `claim_jobs`(SKIP LOCKED) / `heartbeat_job` / `complete_job` / `fail_job`(자동 환불) / `cancel_job` / `reap_stale_jobs`, Realtime 발행, Storage 버킷 3개와 "폴더 = org_id" 정책 |
| 7 | `migrations/0006_core_affiliate.sql` | 제휴마케팅 공용 모듈(확정 결정 12): `affiliate_accounts`, `affiliate_links`(단축 코드), `affiliate_clicks`, `affiliate_disclosures`(끌 수 없는 대가성 문구), `brandconnect_applications`(상태 전이 트리거, 위험 동의 필수), `record_affiliate_click` / `effective_disclosure` / `upsert_affiliate_disclosure` / `consent_brandconnect_risk` / `create_brandconnect_application` |
| 7-1 | `migrations/0007_core_function_privileges.sql` | core 전 함수의 PUBLIC EXECUTE 회수(스키마 기본 권한으로는 회수되지 않음). 명시적으로 부여한 권한은 유지 |
| 7-2 | `migrations/0008_core_ai.sql` | AI 계층(확정 결정 13, 14, 17): 확장 `vector`, `ai_providers`, `ai_model_prices`, `ai_routing_settings`, RAG(`ai_collections`, `ai_documents`, `ai_chunks` HNSW), 위키(`wiki_pages`, `wiki_links`, `wiki_revisions`), 대화(`ai_conversations`, `ai_messages`), 그래프 실행(`ai_runs`, `ai_run_steps`), 스키마 `ai_runtime`, 함수 `match_ai_chunks` / `resolve_ai_route` / `set_ai_routing`(`AI001`). pgvector가 필요하므로 체커는 `--vector` |
| 7-3 | `migrations/0009_core_voice.sql` | 음성(확정 결정 16): `voice_sessions`, `voice_jobs`, 버킷 `voice-audio`, `expire_voice_audio` |
| 8 | `migrations/1000_publishing.sql` 이후 | 제품 조각. 번호 범위는 아래 표 |
| 9 | `seed.sql` | `core.apps` 전 제품 행, 샘플 플랜/크레딧팩, 제공자별 기본 대가성 문구, AI 제공자·단가·기본 라우팅 행(파일 끝) |

정책이 테이블 파일(0001~0003)이 아니라 0004에 모여 있는 이유: 정책은 헬퍼 함수를 쓰고 헬퍼는 `org_members`와 `app_entitlements`에 의존한다. 테이블 파일에서는 RLS를 켜기만 하므로 0004 전까지는 "전부 거부" 상태이며, 이는 안전한 기본값이다.

로컬 적용:

```bash
supabase start
supabase db reset          # supabase/migrations/* 를 번호 순으로 적용한 뒤 seed.sql 실행
supabase gen types typescript --local --schema core,video > apps/shortsflow/src/types/supabase.ts
```

## 3. 마이그레이션 번호 범위

`docs/products/README.md`의 표를 따른다. 같은 범위 안에서는 10 단위로 올린다(`1000`, `1010`, ...).

| 범위 | 스키마 | 제품 |
|---|---|---|
| 0000~0099 | `core` | _platform-core |
| 1000~1099 | `publishing` | flora-publishing |
| 1100~1199 | `astro` | astro-ai |
| 1200~1299 | `video` | shortsflow |
| 1300~1399 | `blog` | nomad-blog |
| 1400~1499 | `commerce` | nomad-commerce |
| 1500~1599 | `microweb` | microweb-studio |
| 1600~1699 | `erp` | admin-suite (ERP) |
| 1700~1799 | `sms` | admin-suite (School) |
| 1800~1899 | `poll` | live-poll |
| 1900~1999 | `stock` | stock-dashboard |
| 2000~2099 | `toon` | toon-factory |
| 2100~2199 | `notes` | study-note |
| 2200~2299 | `site` | website-floria |
| 2300~2399 | `docs` | nomad-docs |
| 2400~2499 | `arch`(제안) | arch-studio(PRD 초안, 조각 없음) |
| 2500~2599 | `news` | local-news |
| 2600~2699 | `trailer` | book-trailer |

## 4. API에 스키마 노출

PostgREST는 `[api].schemas`에 적힌 스키마만 노출한다. `config.toml.example`을 복사해 `supabase/config.toml`로 쓰고, 제품 스키마를 추가할 때마다 목록에 넣는다. 호스팅 프로젝트에서는 Dashboard > Settings > API > Exposed schemas 에서 같은 목록을 설정한다.

클라이언트에서는 스키마를 명시한다.

```ts
// core: 기본 스키마로 고정 (env SUPABASE_DB_SCHEMA = 'core')
const supabase = createClient(url, key, { db: { schema: 'core' } })
await supabase.rpc('session_context', { p_app: 'video' })

// 제품 스키마
await supabase.schema('video').from('jobs_view').select('*')
```

`public`에는 제품 테이블을 만들지 않는다. `public`은 Supabase 기본 객체와 호환용으로만 남긴다.

## 5. hms 제외 사유

| 근거 | 내용 |
|---|---|
| `docs/reviews/Hospital.md:81` | 의료 데이터 시스템은 "민감 의료기록 API 탈취 방어"가 요구사항이며 공유 비밀번호 한 줄로 전 역할이 우회되는 현 상태에서 다른 도메인과 섞을 수 없다 |
| `00_MERGE_ANALYSIS.md:1110` | 병원은 의료정보라서 다른 도메인과 같은 DB나 같은 배포에 섞는 것 자체가 위험을 키운다 |
| `00_MERGE_ANALYSIS.md:1239` | DB 분리 결정: 앱별 분리, 의료정보 격리 |
| 확정 결정 2 | hms는 별도 DB로만 제공하고 모듈러 통합 DB에서 제외 |

hms는 `_platform-core/MONOLITH_CORE_LITE.sql`(public 스키마)을 코어로 쓰는 단독 Supabase 프로젝트로 배포한다. 감사 로그 범위(의료 데이터 조회 기록 포함 여부)와 보존 기간은 admin-suite의 01_PRD에서 정한다.

## 6. 제품이 조각을 추가하는 방법

1. `migrations/<NNNN>_<schema>.sql` 파일을 만든다. 번호는 3절의 범위.
2. 파일 머리에서 스키마를 만들고 권한을 준다.

```sql
create schema if not exists video;
grant usage on schema video to anon, authenticated, service_role;
alter default privileges in schema video grant all on tables to service_role;
alter default privileges in schema video grant all on sequences to service_role;
alter default privileges in schema video revoke execute on functions from public;
```

3. 테넌트 테이블은 `org_id uuid not null references core.organizations(id) on delete cascade`를 갖는다.
4. RLS를 켜고 core 헬퍼로 정책을 쓴다. 쓰기 정책에는 반드시 `with check`.

```sql
alter table video.jobs_meta enable row level security;
grant select, insert, update, delete on video.jobs_meta to authenticated;

create policy jobs_meta_select on video.jobs_meta for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'video'));
create policy jobs_meta_insert on video.jobs_meta for insert to authenticated
  with check (core.is_org_member(org_id) and core.has_entitlement(org_id, 'video'));
create policy jobs_meta_update on video.jobs_meta for update to authenticated
  using (core.is_org_member(org_id)) with check (core.is_org_member(org_id));
create policy jobs_meta_delete on video.jobs_meta for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']));
```

5. 앱을 등록한다(`seed.sql`에 이미 있으면 생략).

```sql
insert into core.apps (id, name, schema_name, signup_policy) values ('video', 'ShortsFlow', 'video', 'open')
on conflict (id) do nothing;
```

6. 크레딧/플랜/구독 테이블을 제품 스키마에 다시 만들지 않는다. `core.consume_credits` 등 RPC만 service_role로 호출한다.
7. `config.toml` `[api].schemas`에 스키마를 추가하고, 타입을 재생성한다.
8. 세부 규칙은 `../_platform-core/DB_CONVENTIONS.md`를 따른다.

## 7. 스케줄 (pg_cron 또는 외부 워커)

호스팅 프로젝트에서 pg_cron을 켠 뒤 아래를 등록한다. pg_cron이 없으면 같은 함수를 워커의 크론(`CRON_SECRET`으로 보호된 라우트가 아니라 워커 프로세스)에서 service_role로 호출한다.

| 주기 | 호출 | 목적 |
|---|---|---|
| 매일 00:10 KST (`10 15 * * *` UTC) | `select core.run_monthly_credit_grants();` | 월 플랜 크레딧 지급, 무료 구독 기간 굴림, 해지 예약 만료 |
| 매 10분 | `select core.reap_stale_jobs(600);` | 하트비트 끊긴 잡 재큐잉/실패 |
| 매 시간 | `select core.expire_stale_payment_orders();` | 미승인 주문 만료 |
| 매일 | `select core.purge_expired_oauth_states(); select core.purge_rate_limit_buckets();` | 정리 |

빌링키 정기결제(갱신 청구)는 DB 함수가 아니라 워커가 수행한다. Toss API 호출이 필요하기 때문이다. 워커는 `core.subscriptions`에서 `next_charge_at <= now()`인 행을 읽고, 청구 후 `core.confirm_payment_order()`를 호출한다. 자세한 흐름은 `../_platform-core/SHARED_MODULES.md`의 Toss billing 절에 있다.

## 8. 검증 (로컬)

| 검사 | 방법 |
|---|---|
| 사용자가 자기 role/plan/credit을 바꿀 수 없다 | authenticated JWT로 `update core.profiles set platform_role='platform_admin'` → 42501, `rpc('grant_credits')` → 42501 |
| 타 조직 가입 불가 | authenticated JWT로 `insert into core.org_members` → 42501 (정책 없음 + 트리거) |
| 차감 원자성 | 같은 조직에 `consume_credits`를 동시에 50회 호출 → 잔액 음수 없음, 원장 합 = 지갑 |
| 멱등 | 같은 `p_idempotency_key`로 2회 호출 → 원장 1행 |
| 결제 금액 대조 | `confirm_payment_order`에 다른 금액 → PM001, 주문 failed |
| 가입 트리거 | `auth.users` insert 후 profiles 1, organizations 1, org_members 1(owner), 앱 부트스트랩 시 entitlement 1 |
| Storage 격리 | 다른 org 폴더에 업로드 → 거부 |
