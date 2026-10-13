# 05 데이터 모델: Floria (website-floria)

작성일 2026-10-12. SQL 정본은 `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2200_site.sql`이다. 모놀리스 `supabase/monolith/migrations/0002_website_floria_domain.sql`은 그 변환본이다.

2026-10-13 개정: AI·음성(확정 결정 13~17)을 위해 `site.sites`에 스위치 컬럼 2개(`accepts_ai_chat`, `accepts_voice`)와 RPC `site.update_ai_settings`를 더했다. **제품 전용 AI 테이블은 만들지 않았다**(6장에 이유). 기능별 라우팅 기본값 8행은 모듈러 2200 11절과 모놀리스 `seed.sql`에 있다. 방문자 대화·지식·위키·음성 기록은 모두 `core.*` 공용 테이블에 둔다.

## 1. 개요와 ERD

DB를 최소로 둔 이유: 사이트 콘텐츠(카피, 컬렉션, 이미지)는 바뀌는 빈도가 낮고 초대제 소수 운영자뿐이라 CMS 테이블이 필요 없다. 콘텐츠는 저장소의 `src/content/*.ts`가 정본이고(`docs/reference/reviews/WebSite.md:240`, "콘텐츠를 데이터 파일로"), 가격·단위 충돌도 한 곳에서 해결된다. DB에는 방문자가 남기는 데이터만 둔다.

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

AI·음성 (모두 core 참조, 제품 테이블 없음. org_id = site.sites.org_id)
core.ai_conversations (org_id, app_id=site, visitor_key) ─ core.ai_messages, core.ai_runs ─ core.ai_run_steps
core.ai_collections ─ core.ai_documents ─ core.ai_chunks      (지식 RAG)
core.wiki_pages ─ core.wiki_links, core.wiki_revisions         (브랜드 지식 위키)
core.voice_sessions (visitor_key) ─ core.voice_jobs
core.ai_usage (조직 단위 원가 기록), core.ai_routing_settings (app=site 8행), core.ai_org_settings (국외 이전 동의)
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
| accepts_ai_chat | boolean | N | false | AI 상담(방문자 채팅) on/off. 기본 꺼짐. `update_ai_settings`로만 변경 |
| accepts_voice | boolean | N | false | 음성 상담 on/off. 기본 꺼짐. CHECK `sites_voice_needs_chat_check`: `accepts_voice`는 `accepts_ai_chat`이 true일 때만 true |
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

`sites.accepts_ai_chat`·`accepts_voice`는 단순 on/off라 전이 트리거를 두지 않는다. 음성이 상담에 종속되는 규칙은 테이블 CHECK와 `update_ai_settings`(상담을 끄면 음성도 함께 끔)가 강제한다.

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
| set_inquiry_status, delete_inquiry, erase_subscriber, update_site_settings, update_ai_settings | X | O (함수 안에서 `is_service_caller` + 역할 + 엔타이틀먼트) | O |
| subscribe/confirm/unsubscribe_newsletter, provision_site, purge_expired | X | X | O (함수 안에서도 `is_service_caller`) |

`submit_inquiry`는 공개 함수이므로 호출자 판정이 없다. 대신 비인가 쓰기를 막는 것은 (1) 유일한 anon 쓰기 경로라는 구조, (2) DB 내 레이트 리밋(사이트 100/시간·500/일, 이메일 3/시간·6/일), (3) 허니팟·검증·스팸 점수, (4) 사이트·엔타이틀먼트 확인이다. 역할 비교는 `core.has_org_role`(exists 반환)을 써서 NULL 비교 문제가 없다(`SECURITY_BASELINE.md` 2장).

코어 AI 테이블의 접근(`D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:614-642`, `0009_core_voice.sql:81-87`): 방문자(anon)는 `core.ai_*`·`wiki_*`·`voice_*`에 접근 권한이 없다. 방문자 대화는 `user_id`가 null이라 `ai_conversations_select`(`user_id = auth.uid()`)에 걸리지 않아 어떤 authenticated 사용자도 읽지 못하고, 모든 읽기·쓰기는 Route Handler(service_role)가 쿠키 일치를 확인한 뒤 한다. 운영자는 `ai_documents`·`wiki_pages`·`wiki_revisions`·`ai_org_settings`·`ai_usage`를 조직 멤버 RLS로 읽는다. `ai_chunks`는 사용자에게 SELECT가 없고 검색은 service_role의 `match_ai_chunks`만 한다.

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

AI·음성 코어 객체(2026-10-13, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | floria 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 방문자 상담 대화 매핑과 메시지(`visitor_key`, 마스킹본, 30일 후 삭제) | Next.js(대화 생성, user 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `site.consult` 실행 기록(턴마다 1행), 위키 ingest·lint 결과 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 원가 기록. 크레딧이 없어 `settled_at`을 기록 시점에 채운다. 모놀리스는 SECTION 11이 원장 외래키 없이 만든다 | FastAPI, Next.js 음성 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 8행(9장), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 운영자 조직의 국외 이전 동의 | 콘솔(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 시공 사례·식물 정보·FAQ 지식(사이트 조직만) | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions`, `purge_wiki_page` | 브랜드 지식 위키(사이트 조직만) | FastAPI(쓰기), Next.js 서버(공개 읽기) |
| `voice_sessions`, `voice_jobs` | 방문자 음성 상담(`visitor_key`, `store_audio=false`) | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |

제품 AI 표를 만들지 않은 이유(`docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 상담-문의 연결 표 | 상담에서 넘어온 문의를 추적 | `inquiries.source_path = "/consult"`(기존 컬럼). 대화 id는 문의에 저장하지 않는다(방문자 대화와 문의를 서버가 잇지 않는 것이 개인정보에 유리) |
| AI 사용 한도 표 | 방문자·사이트별 일일 한도 | `core.rate_limit_hit` 키(`site:ai-turn:*` 등)와 환경변수 상한 |
| 지식 원고 표 | 사례·식물·FAQ 관리 | 저장소 `content/knowledge/*.md`(정본) + `core.ai_documents`(색인 상태) |
| 미답변 질문 표 | 원고 보강 | `ai_messages`에서 `citations`가 빈 assistant 직전 user 메시지를 서버가 집계(마스킹본, 30일) |
| 음성 고지 확인 표 | 음성 처리 고지 증빙 | `voice_sessions` 행(생성 요청에 고지문 버전이 서버 상수와 같아야만 만든다) |
| 스위치 | AI on/off | 표가 아니라 `site.sites` 컬럼 2개(운영자가 쓰는 값이고 plan 행은 사용자가 쓸 수 없어 `plans.features`에 둘 수 없다) |

**코어 점검 결과(코어는 수정하지 않았다).** PGlite로 모듈러 0000~0006+seed를 적용한 뒤 `anon` 역할로 확인했다. 스키마 한정 `alter default privileges ... revoke execute on functions from public`은 PUBLIC 기본 EXECUTE를 없애지 못한다. 그래서 명시적 `revoke`가 없는 코어 함수는 anon이 호출할 수 있었다. 실제로 `core.rate_limit_hit`, `run_monthly_credit_grants`, `expire_stale_payment_orders`, `purge_rate_limit_buckets`, `reap_stale_jobs`가 anon에서 성공했고, `confirm_payment_order`는 인자 검사(PM404)까지 도달했다. 이 함수들의 내부 `is_privileged_session()` 검사는 DEFINER 안에서 항상 true라 방어가 되지 않는다(`SECURITY_BASELINE.md` 1장과 같은 원리). 모놀리스(`SECTION 10`이 전부 회수)는 영향이 없다. 이 제품의 영향: anon이 `rate_limit_hit`로 임의 키를 소진할 수 있으나 우리 키는 사이트 uuid를 포함하고 uuid를 공개하지 않으므로 직접 영향은 작다. 이 제품 함수는 모두 명시적 revoke를 하므로 영향을 받지 않는다. 코어 수정 요청은 06장 6절.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

리뷰 높음 8건(#1~#8)은 모두 성능, 버그, 품질, 구조, 설정 분류라 보안·데이터 결함이 아니다. 차단 설계 8건은 `02_ARCHITECTURE.md` 6장 표에 있다(행 8개 = 높음 8건). 아래는 리뷰 밖에서 이 DB가 새로 갖는 위험과 차단이며 높음 건수에 세지 않는다.

| 위험 | 출처 | 차단 설계 |
|---|---|---|
| 폼에 백엔드가 없어 문의가 사라지거나 mailto에 의존(리뷰 #33, 낮음) | `docs/reference/reviews/WebSite.md:214` | `submit_inquiry` + 콘솔 |
| 공개 쓰기 경로의 홍수, 스팸 | 새 위험 | DB 내 레이트 리밋 4종, 허니팟, 점수, 앞단 CAPTCHA+IP 제한 |
| 익명의 문의 열람/변조 | 새 위험 | anon 테이블 권한 없음, 쓰기 정책 없음, guard 트리거, 스모크 테스트 |
| 구독 계정 열거 | 새 위험 | 항상 같은 응답, 확인/해지 service_role 전용 |
| 메일 보안 스캐너가 확인 링크를 선열람해 구독 확정 | 새 위험 | GET은 상태 불변, 버튼 POST로 확정 |
| 타 조직 문의 열람 | 새 위험 | 정책: 멤버십+엔타이틀먼트. viewer 제외 |
| 개인정보 장기 보존 | 새 위험 | `purge_expired`, 사이트별 보존일 |
| 동의 문구 변경 후 구버전 폼 제출 | 새 위험 | `privacy_policy_version` 불일치 시 SI004 |
| 방문자 대화 탈취(대화 id 추측) | 새 위험(AI) | 서명된 방문자 쿠키 해시 `visitor_key` 일치를 매 턴 검사, `ai_conversations` 소유자 CHECK(23514), 방문자 대화는 RLS로 아무도 읽지 못함 |
| 비용 남용(익명 대량 호출) | 새 위험(AI) | Turnstile(상담 시작), 레이트 리밋 5종, 사이트 일일 상한, 입력·턴·토큰 상한, 스위치 기본 꺼짐 |
| 프롬프트 인젝션으로 허위 정보·연락처 생성 | 새 위험(AI) | 검색 결과를 "자료"로만 전달, 그래프 `compliance` 노드(금지 규칙 파일), 연락처는 `business.ts` 값만 |
| 타 조직 지식 접근 | 새 위험(AI) | `match_ai_chunks`가 org·app 필터 강제, 복합 외래키(23503), 서명 토큰 `org`만 신뢰 |
| 국외 이전 우회 | 새 위험(AI) | `resolve_ai_route`가 동의 없는 조직의 체인에서 상용 제공자를 제거, 대체도 실패 처리. 임베딩은 오픈소스 고정 |
| 대화에 섞인 개인정보 장기 보존 | 새 위험(AI) | 서버 마스킹, 30일 후 삭제, 방문자 삭제 요청 경로, 운영자는 원문 열람 불가 |

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
| AI 테이블 | `0008_core_ai.sql`, `0009_core_voice.sql` | `0001_core_lite.sql`의 SECTION 11(AI)·12(음성). 크레딧·잡 외래키 없음, `ai_usage`는 원장 없이 생성 |
| 라우팅 기본값 | `2200_site.sql` 11절 | `seed.sql` 끝(같은 8행 + 체인 검사). 앱 행이 먼저 들어간 뒤 실행된다 |
| 크레딧·잡·Storage | 코어 사용 가능하나 이 제품은 쓰지 않음 | SECTION 3, 4, 7, 8이 제거돼 있어 AI도 `consume_credits`·`core.jobs`·Storage를 쓸 수 없다(02장 4.1절: FastAPI 백그라운드로 대체) |

## 9. 마이그레이션 파일

| 구분 | 파일 | 내용 |
|---|---|---|
| 모듈러 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/2200_site.sql` | 스키마, `core.apps` 등록, 테이블 3(`sites`에 AI 스위치 2컬럼), 트리거, RLS, RPC 11, EXECUTE 정리, 스케줄 주석, 11절 AI·음성 기본값(라우팅 8행 + 체인 검사) |
| 모듈러 seed | `D:/WorkSpace/platform/docs/products/_supabase-modular/seed.sql`(기존) | `('site', 'default')` 행. 이 작업에서 수정하지 않음 |
| 모놀리스 | `supabase/monolith/migrations/0001_core_lite.sql` | 코어 축소판 |
| 모놀리스 | `supabase/monolith/migrations/0002_website_floria_domain.sql` | 위 조각의 변환 |
| 모놀리스 seed | `supabase/monolith/seed.sql` | apps 1행, 기본 플랜 1행, AI·음성 라우팅 기본값 8행 + 체인 검사. 크레딧팩 없음 |

검증(2026-10-12): 체커 모놀리스 3파일 OK, 모듈러 9파일 OK. RLS 스모크는 모듈러 72/73 통과(미통과 1건은 위 코어 점검 항목), 모놀리스 71/71 통과.

2026-10-13 재검증(PGlite `--vector`, `D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs`):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `2200_site.sql` | 전부 OK |
| `check.mjs --vector mono` 0001 + 0002 + `seed.sql` | 전부 OK |
| 제품 파일과 seed 2회 반복 적용 후 `ai_routing_settings`(org null, app site) | 8행(모듈러·모놀리스) |
| `sites` 신규 컬럼 | `accepts_ai_chat`, `accepts_voice` 기본 false |
| `update_ai_settings`(owner) | 상담 없이 음성만 켜기 → 둘 다 false 유지, 상담+음성 → 둘 다 true, 상담 끄기 → 음성도 false |
| `sites` 직접 UPDATE(authenticated), anon의 `update_ai_settings` | 42501(permission denied) |
| 미동의 조직 `resolve_ai_route` | `site.consult` = oss-llm, `voice_consult` stt·tts = oss-voice, `dify.aux` = oss-llm, `site.knowledge` = oss-embed |
| 동의 후 | `site.consult` = anthropic → openai → google → oss-llm, tts = elevenlabs → oss-voice, stt = oss-voice → elevenlabs, `dify.aux`는 계속 oss-llm(강제), 기능 키 ` SITE.Consult `(대소문자·공백)도 `site.consult` 행으로 해석 |

AI 기능별 기본값 행(정본 02장 5.1절): `site.consult`(llm, auto, anthropic → openai → google → oss-llm), `wiki.query`·`wiki.ingest`·`wiki.lint`(llm, auto, oss-llm → anthropic), `dify.aux`(llm, open_source, oss-llm, 강제), `site.knowledge`(embedding, open_source, oss-embed), `voice_consult` stt(auto, oss-voice → elevenlabs), `voice_consult` tts(auto, elevenlabs → oss-voice).

RLS 스모크 스크립트(`tests/rls/`, SI-06-004)는 2026-10-13 변경분(스위치 컬럼, `update_ai_settings`, 방문자 대화 접근 항목)을 아직 포함하지 않는다. 추가 항목은 SI-06-004와 SI-06-048의 수용 기준에 적었다.
