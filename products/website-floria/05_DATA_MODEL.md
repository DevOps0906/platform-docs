# 05 데이터 모델: Floria (website-floria)

작성일 2026-10-12. SQL 정본은 `docs/products/_supabase-modular/migrations/2200_site.sql`이다. 모놀리스 `supabase/monolith/migrations/0002_website_floria_domain.sql`은 그 변환본이다.

## 1. 개요와 ERD

DB를 최소로 둔 이유: 사이트 콘텐츠(카피, 컬렉션, 이미지)는 바뀌는 빈도가 낮고 초대제 소수 운영자뿐이라 CMS 테이블이 필요 없다. 콘텐츠는 저장소의 `src/content/*.ts`가 정본이고(`docs/reviews/WebSite.md:240`, "콘텐츠를 데이터 파일로"), 가격·단위 충돌도 한 곳에서 해결된다. DB에는 방문자가 남기는 데이터만 둔다.

| 테이블 | 필요한 이유 |
|---|---|
| `sites` | 한 폼 백엔드를 여러 사이트가 공유(`00_MERGE_ANALYSIS.md:1065`). 문의가 어느 조직·사이트 것인지, 접수 on/off, 동의 문구 버전, 보존 기간을 사이트별로 갖는다. 분석이 말한 "테이블 1~2개"(`_supabase-modular/ARCHITECTURE.md:42`)보다 하나 많은 이유 |
| `inquiries` | 문의 본문과 처리 상태 |
| `newsletter_subscribers` | 이중 동의 상태와 수신 거부 이력 |

```
core.organizations (참조)
  └─ site.sites (org_id)
       ├─ site.inquiries (org_id, site_id)
       └─ site.newsletter_subscribers (org_id, site_id)
core.app_entitlements (참조: app 'site') / core.org_members (참조: 역할) / core.audit_log (RPC가 기록)
core.rate_limit_buckets (참조: RPC가 키로 사용)
```

## 2. 테이블

공통: `id uuid`, `created_at`, `updated_at`(`core.set_updated_at` 트리거), 쓰기 보호 `core.guard_privileged_write` 트리거. `created_by`는 `sites`에만 있다(방문자는 사용자가 아니다). `deleted_at`은 두지 않는다(하드 삭제가 개인정보 삭제 요구에 맞다).

### 2.1 `site.sites`

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id | uuid | N | gen_random_uuid() | PK |
| org_id | uuid | N | - | FK `core.organizations` on delete cascade |
| slug | text | N | - | 유일. `^[a-z][a-z0-9-]{1,38}[a-z0-9]$`. 공개 API가 사이트를 식별하는 값 |
| name | text | N | - | 1~80자 |
| brand_key | text | N | 'floria' | 브랜드 구분(`floria`, `flora_sentiment` 등) |
| allowed_origins | text[] | N | '{}' | CORS/Origin 허용 목록, 최대 10 |
| notify_email | text | Y | - | 알림 수신 주소 |
| accepts_inquiries | boolean | N | true | 문의 접수 on/off |
| accepts_newsletter | boolean | N | true | 구독 접수 on/off |
| inquiry_retention_days | integer | N | 365 | 30~1095 (제안) |
| privacy_policy_version | text | N | 'v1' | 폼이 보인 동의 문구 버전 |
| status | text | N | 'active' | active, paused |
| created_by | uuid | Y | - | FK 없음 |
| created_at, updated_at | timestamptz | N | now() | |

### 2.2 `site.inquiries`

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id | uuid | N | gen_random_uuid() | PK. 접수번호는 앞 8자리 대문자 |
| org_id | uuid | N | - | FK `core.organizations` on delete cascade |
| site_id | uuid | N | - | FK `site.sites` on delete cascade |
| kind | text | N | - | custom_order, wedding, corporate, workshop, subscription, press, other |
| name | text | N | - | 1~80자 |
| email | text | N | - | 소문자 정규화, 형식 CHECK, 254자 이하 |
| phone | text | Y | - | `^[0-9+() -]{6,30}$` |
| message | text | N | - | 10~2000자 |
| locale | text | N | 'ko' | ko, en |
| source_path | text | Y | - | `/`로 시작, 200자 이하 |
| consent_version, consent_at | text, timestamptz | N | -, now() | 동의 기록 |
| status | text | N | 'new' | new, read, replied, archived, spam |
| spam_score, spam_reasons | smallint, text[] | N | 0, '{}' | 0~100. 사유: no_timing, too_fast, many_links, html_tags |
| staff_note | text | Y | - | 1000자 이하 |
| notified_at, read_at, replied_at, archived_at | timestamptz | Y | - | 알림/전이 시각 |
| created_at, updated_at | timestamptz | N | now() | |

IP, User-Agent는 저장하지 않는다(개인정보 최소화).

### 2.3 `site.newsletter_subscribers`

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| id | uuid | N | gen_random_uuid() | PK. 토큰 payload의 `sid` |
| org_id, site_id | uuid | N | - | FK |
| email | text | Y | - | 해지 30일 후 또는 삭제 요청 시 NULL. `unsubscribed`일 때만 NULL 허용(CHECK) |
| email_hash | text | N | - | sha256 hex 64자. `(site_id, email_hash)` 유일. 재발송 방지용 이력 |
| locale | text | N | 'ko' | |
| status | text | N | 'pending' | pending, confirmed, unsubscribed |
| consent_version, consent_at | text, timestamptz | N | -, now() | 2년 재확인 일정 계산용(법무 확인 필요) |
| source_path | text | Y | - | |
| confirm_sent_at, confirm_sent_count | timestamptz, smallint | Y, N | -, 0 | 확인 메일 재발송 상한 5 |
| confirmed_at, unsubscribed_at | timestamptz | Y | - | 전이 트리거가 설정 |
| created_at, updated_at | timestamptz | N | now() | |

## 3. 상태 전이

| 테이블 | 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|---|
| inquiries | new | read, replied, spam, archived | 멤버(`set_inquiry_status`) 또는 service_role | `read_at`/`replied_at`/`archived_at` 설정, 감사 로그 |
| inquiries | read | new, replied, spam, archived | 같음 | 같음 |
| inquiries | replied | archived | 같음 | `archived_at` |
| inquiries | archived | read | 같음 | 재열람 |
| inquiries | spam | new | 같음 | 오탐 복구 |
| newsletter | pending | confirmed, unsubscribed | service_role RPC | `confirmed_at`/`unsubscribed_at` |
| newsletter | confirmed | unsubscribed | service_role RPC, `erase_subscriber` | |
| newsletter | unsubscribed | pending | `subscribe_newsletter`(새 동의) | 시각 초기화 |

선택: 부수 효과가 시각 설정뿐이라 BEFORE UPDATE 트리거(`inquiry_status_transition`, `newsletter_status_transition`)로 강제한다. 위반은 22023이고 service_role 직접 쓰기에도 적용된다(`DB_CONVENTIONS.md:224`). 감사 로그는 RPC가 남긴다. `sites.status`는 단순 on/off라 전이 트리거를 두지 않는다.

## 4. RLS 정책

모든 테이블 RLS ON. 쓰기 정책은 없다. 쓰기는 SECURITY DEFINER RPC와 service_role뿐이라 `DB_CONVENTIONS.md` 8장 조건(쓰기 정책을 줄 때의 조건)은 해당하지 않는다. 세 테이블에 `guard_privileged_write` 이중 잠금을 붙였다.

| 테이블 | SELECT (authenticated) | INSERT/UPDATE/DELETE | GRANT |
|---|---|---|---|
| sites | `core.is_org_member(org_id) and core.has_entitlement(org_id,'site')` | 정책 없음 | authenticated: select만 |
| inquiries | `core.has_org_role(org_id, array['owner','admin','member']) and core.has_entitlement(org_id,'site')` (viewer 제외: 개인정보) | 정책 없음 | select만 |
| newsletter_subscribers | inquiries와 동일 | 정책 없음 | select만 |

anon에게는 테이블 권한이 없다. 비멤버 B가 `org_id = A`로 INSERT하는 경로가 없고, 직접 INSERT/UPDATE/DELETE는 GRANT 부재로 42501이다.

함수 EXECUTE:

| 함수 | anon | authenticated | service_role |
|---|---|---|---|
| submit_inquiry | O | O | O |
| set_inquiry_status, delete_inquiry, erase_subscriber, update_site_settings | X | O (함수 안에서 `is_service_caller` + 역할 + 엔타이틀먼트) | O |
| subscribe/confirm/unsubscribe_newsletter, provision_site, purge_expired | X | X | O (함수 안에서도 `is_service_caller`) |

`submit_inquiry`는 공개 함수이므로 호출자 판정이 없다. 대신 비인가 쓰기를 막는 것은 (1) 유일한 anon 쓰기 경로라는 구조, (2) DB 내 레이트 리밋(사이트 100/시간·500/일, 이메일 3/시간·6/일), (3) 허니팟·검증·스팸 점수, (4) 사이트·엔타이틀먼트 확인이다. 역할 비교는 `core.has_org_role`(exists 반환)을 써서 NULL 비교 문제가 없다(`SECURITY_BASELINE.md` 2장).

초대제: 코어는 `signup_policy='invite'` 앱에서 가입 트리거가 구독·엔타이틀먼트를 만들지 않고 `bootstrap_app_for_org`는 비 service 호출자에 42501을 낸다(2026-10-13 코어 반영, 운영자 service_role은 가능). 엔타이틀먼트가 있어도 사이트 행은 `provision_site`(service_role)로만 생기므로 등록되지 않은 조직은 볼 데이터와 쓸 수 있는 RPC가 없다. 이것이 2차 게이트로 유지된다.

## 5. 인덱스와 성능

| 인덱스 | 목적 / 조회 패턴 |
|---|---|
| `sites_org_idx (org_id)` | 콘솔의 조직별 사이트 조회 |
| `sites.slug` unique | 공개 API의 slug 조회 |
| `inquiries_site_status_idx (site_id, status, created_at desc)` | 콘솔 목록의 상태 필터+최신순 |
| `inquiries_org_created_idx (org_id, created_at desc)` | RLS 조건과 전체 목록 |
| `inquiries_created_idx (created_at)` | 보존 만료 삭제 |
| `inquiries_notify_idx (created_at) where notified_at is null and status='new'` | 알림 워커 폴링(부분 인덱스, 크기가 작다) |
| `newsletter_org_status_idx (org_id, status, created_at desc)` | 콘솔 목록 |
| `newsletter_purge_idx (status, updated_at)` | 퍼지 |
| `unique (site_id, email_hash)` | 재구독/중복 판정 |

예상 규모는 월 수십~수백 건(제안: 소규모 브랜드 사이트)이라 성능 병목은 없다. `rate_limit_buckets`는 매일 `purge_rate_limit_buckets()`로 정리한다(`CORE_SPEC.md` 14장).

## 6. 코어 참조

| 객체 | 용도 | ALTER |
|---|---|---|
| `core.organizations(id)` | FK | 안 함 |
| `core.is_org_member`, `has_org_role`, `has_entitlement`, `is_service_caller` | RLS와 RPC 검사 | 안 함 |
| `core.set_updated_at`, `core.guard_privileged_write` | 트리거 | 안 함 |
| `core.rate_limit_hit(key, limit, window)` | RPC 안의 레이트 리밋. DEFINER 안에서 호출 | 안 함 |
| `core.write_audit` | 상태 변경, 설정, 삭제, 퍼지 기록 | 안 함 |
| `core.apps`, `core.plans`(seed), `core.app_entitlements` | 앱 등록, 기본 플랜, 엔타이틀먼트 | 안 함 |
| `extensions.digest` | 이메일 해시(pgcrypto) | - |

`core.*` ALTER 없음을 확인했다.

**코어 점검 결과(코어는 수정하지 않았다).** PGlite로 모듈러 0000~0006+seed를 적용한 뒤 `anon` 역할로 확인했다. 스키마 한정 `alter default privileges ... revoke execute on functions from public`은 PUBLIC 기본 EXECUTE를 없애지 못한다. 그래서 명시적 `revoke`가 없는 코어 함수는 anon이 호출할 수 있었다. 실제로 `core.rate_limit_hit`, `run_monthly_credit_grants`, `expire_stale_payment_orders`, `purge_rate_limit_buckets`, `reap_stale_jobs`가 anon에서 성공했고, `confirm_payment_order`는 인자 검사(PM404)까지 도달했다. 이 함수들의 내부 `is_privileged_session()` 검사는 DEFINER 안에서 항상 true라 방어가 되지 않는다(`SECURITY_BASELINE.md` 1장과 같은 원리). 모놀리스(`SECTION 10`이 전부 회수)는 영향이 없다. 이 제품의 영향: anon이 `rate_limit_hit`로 임의 키를 소진할 수 있으나 우리 키는 사이트 uuid를 포함하고 uuid를 공개하지 않으므로 직접 영향은 작다. 이 제품 함수는 모두 명시적 revoke를 하므로 영향을 받지 않는다. 코어 수정 요청은 06장 6절.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

리뷰 높음 8건(#1~#8)은 모두 성능, 버그, 품질, 구조, 설정 분류라 보안·데이터 결함이 아니다. 차단 설계 8건은 `02_ARCHITECTURE.md` 6장 표에 있다(행 8개 = 높음 8건). 아래는 리뷰 밖에서 이 DB가 새로 갖는 위험과 차단이며 높음 건수에 세지 않는다.

| 위험 | 출처 | 차단 설계 |
|---|---|---|
| 폼에 백엔드가 없어 문의가 사라지거나 mailto에 의존(리뷰 #33, 낮음) | `docs/reviews/WebSite.md:214` | `submit_inquiry` + 콘솔 |
| 공개 쓰기 경로의 홍수, 스팸 | 새 위험 | DB 내 레이트 리밋 4종, 허니팟, 점수, 앞단 CAPTCHA+IP 제한 |
| 익명의 문의 열람/변조 | 새 위험 | anon 테이블 권한 없음, 쓰기 정책 없음, guard 트리거, 스모크 테스트 |
| 구독 계정 열거 | 새 위험 | 항상 같은 응답, 확인/해지 service_role 전용 |
| 메일 보안 스캐너가 확인 링크를 선열람해 구독 확정 | 새 위험 | GET은 상태 불변, 버튼 POST로 확정 |
| 타 조직 문의 열람 | 새 위험 | 정책: 멤버십+엔타이틀먼트. viewer 제외 |
| 개인정보 장기 보존 | 새 위험 | `purge_expired`, 사이트별 보존일 |
| 동의 문구 변경 후 구버전 폼 제출 | 새 위험 | `privacy_policy_version` 불일치 시 SI004 |

## 8. 모놀리스와 모듈러의 차이

`DB_CONVENTIONS.md` 12장 기준.

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `site`, 코어 `core` | `public` 하나. 최종 사용자 확인 전 가정(`MONOLITH_CORE_LITE.sql` 머리) |
| 코어 사본 | 공유 | `0001_core_lite.sql`에서 [선택] 7개 절 제거: SECTION 3(Toss), 4(크레딧), 6-A(oauth_states), 6-B(encrypted_credentials), 7(jobs), 8(Storage), 9(affiliate). 유지: 0, 1, 5-A, 2, 6-C, 10 |
| 제거의 영향 | - | 크레딧이 없어 `session_context.credit_balance`는 0(동적 확인). 가입 부트스트랩은 SECTION 2의 크레딧 없는 1단계 버전이 그대로 동작. `rate_limit_buckets`(6-C)는 남겼다: 문의 폼 방어에 필요하기 때문 |
| 가입 | `signup_app=site` 메타데이터 필요 | `apps` 행이 1개면 자동. 스모크 테스트에서 메타데이터 없는 사용자도 엔타이틀먼트를 받는 것을 확인 |
| 권한 | 스키마 기본 권한 없음 + 명시 GRANT/REVOKE | SECTION 10이 public을 회수. 도메인 파일도 명시 revoke/grant |
| PostgREST | `config.toml [api].schemas`에 `site` 추가 | 기본 |
| 앱 설정 | `SITE_DB_SCHEMA=site`, `SUPABASE_DB_SCHEMA=core` | 둘 다 `public` |
| 변환 | - | 조각에서 스키마 생성 블록 제거, `core.`/`site.`를 `public.`으로 치환(스크립트화는 06장 SI-06-003) |

## 9. 마이그레이션 파일

| 구분 | 파일 | 내용 |
|---|---|---|
| 모듈러 | `docs/products/_supabase-modular/migrations/2200_site.sql` | 스키마, `core.apps` 등록, 테이블 3, 트리거, RLS, RPC 10, EXECUTE 정리, 스케줄 주석 |
| 모듈러 seed | `docs/products/_supabase-modular/seed.sql`(기존) | `('site', 'default')` 행. 이 작업에서 수정하지 않음 |
| 모놀리스 | `supabase/monolith/migrations/0001_core_lite.sql` | 코어 축소판 |
| 모놀리스 | `supabase/monolith/migrations/0002_website_floria_domain.sql` | 위 조각의 변환 |
| 모놀리스 seed | `supabase/monolith/seed.sql` | apps 1행, 기본 플랜 1행. 크레딧팩 없음 |

검증(2026-10-12): 체커 모놀리스 3파일 OK, 모듈러 9파일 OK. RLS 스모크는 모듈러 72/73 통과(미통과 1건은 위 코어 점검 항목), 모놀리스 71/71 통과.
