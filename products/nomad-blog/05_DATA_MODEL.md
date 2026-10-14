# 05 데이터 모델: NOMAD Blog

작성일 2026-10-12. 정본 SQL: 모듈러 `docs/products/_supabase-modular/migrations/1300_blog.sql`(아래 `1300:줄`), 모놀리스 `supabase/monolith/migrations/0002_blog_domain.sql`. 확정 결정 12에 따라 제휴 테이블은 core에 두고 blog 스키마에는 원고, 원고-제휴 링크 매핑, 그리고 원고를 발행하는 데 필요한 채널 계정·발행 기록만 둔다.

2026-10-13 개정: 확정 결정 13~17에 따른 AI·음성 코어 객체의 참조와 라우팅 기본값 행(9절 `1300_blog.sql` 9절)을 더했다. 제품 전용 AI 테이블은 만들지 않았다(6절 표).

## 1. 개요와 ERD

```
core.organizations
 ├─ blog.channel_accounts ──(credential_id)──> core.encrypted_credentials
 │       ▲                                          ▲
 │       │                                          └─ core.affiliate_accounts(naver_brandconnect 가 같은 자격증명 공유 가능)
 ├─ blog.posts ──(brandconnect_application_id)──> core.brandconnect_applications
 │    │  └──(ai_job_id)──> core.jobs
 │    ├─ blog.post_affiliate_links ──(link_id)──> core.affiliate_links ──> core.affiliate_clicks
 │    └─ blog.post_publications ──(channel_account_id)──> blog.channel_accounts
 │                               └──(job_id)──> core.jobs
 └─ (참조만) core.app_entitlements, core.plans, core.wallets, core.credit_ledger, core.affiliate_disclosures, core.audit_log
```

## 2. 테이블

표준 컬럼(`DB_CONVENTIONS.md` 3장): 네 테이블 모두 `id uuid`, `org_id`(cascade), `created_at`을 갖고, UPDATE가 있는 세 테이블은 `updated_at` + `core.set_updated_at` 트리거, 사용자 노출 엔티티는 `created_by`(FK 없음)를 갖는다.

### 2.1 `blog.channel_accounts` (`1300:59`)

목적: 발행 채널 계정 메타데이터. 비밀(비밀번호, 세션 쿠키, 애플리케이션 비밀번호)은 `core.encrypted_credentials`에만 있다.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `channel` | text | N | - | naver, tistory, wordpress, instagram |
| `label` | text | N | '' | 60자 이하 |
| `blog_url` | text | Y | - | `https://`만 |
| `external_account_id` | text | Y | - | 네이버 blog_id, 티스토리 이름, WP 사용자 id |
| `credential_id` | uuid | Y | - | → `core.encrypted_credentials`, set null |
| `status` | text | N | pending | pending, active, needs_reauth, error, revoked |
| `automation_risk_consented_at/by`, `automation_risk_notice_version` | timestamptz/uuid/text | Y | - | Playwright 자동 게시 위험 동의 |
| `session_expires_at`, `last_verified_at`, `last_published_at`, `last_error` | - | Y | - | 운영 정보 |
| `locked_by_job`, `locked_until` | uuid/timestamptz | Y | - | 계정당 브라우저 1개 임대 잠금 |

제약: `unique (org_id, channel, external_account_id)`. 쓰기: service_role과 제품 RPC만(`guard_privileged_write`).

### 2.2 `blog.posts` (`1300:102`)

목적: 원고. 순수 콘텐츠 컬럼만 사용자가 직접 쓴다.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `title` | text | N | '' | 200자 이하 |
| `body_json` | jsonb | N | 빈 TipTap doc | 500KB 이하 |
| `body_html` | text | Y | - | 서버 렌더 + sanitize 결과. 사용자 쓰기 금지 |
| `excerpt`, `category`, `target_keyword` | text | Y | - | 300/60/100자 |
| `tags` | text[] | N | {} | 30개 이하 |
| `template` | text | N | info | info, compare, guide, essay, experience |
| `experience_note` | text | Y | - | experience면 50자 이상(CHECK) |
| `cover_image_path` | text | Y | - | `<org_id>/blog/...`로 시작(CHECK) |
| `seo_score`, `seo_feedback` | int/jsonb | Y/N | -/[] | 서버 기록 |
| `brandconnect_application_id` | uuid | Y | - | 같은 조직의 블로그형 지원서(`target_kind='blog'`)만(트리거, 확정 결정 19) |
| `status` | text | N | draft | draft, generating, scheduled, publishing, published, partially_published, failed, archived |
| `compliance_verdict`, `compliance_issues`, `compliance_checked_at`, `compliance_ack_by/at` | - | - | unchecked | 서버 기록, WARN 확인은 RPC |
| `ai_job_id` | uuid | Y | - | → `core.jobs` |
| `version` | int | N | 1 | 콘텐츠 변경마다 +1(트리거) |
| `archived_at` | timestamptz | Y | - | 보관 시각 |

사용자 GRANT: INSERT(org_id + 콘텐츠 10개 컬럼), UPDATE(콘텐츠 10개 컬럼), DELETE(`1300:752-756`). 트리거 `blog.posts_guard`(`1300:154`): 사용자 INSERT는 status draft·created_by=auth.uid() 강제, 사용자 UPDATE의 보호 컬럼 변경 42501(2차 잠금), 콘텐츠가 바뀌면 version+1과 검사 결과 무효화.

### 2.3 `blog.post_affiliate_links` (`1300:244`)

목적: 원고와 `core.affiliate_links` 매핑. 대가성 문구 필요 여부 계산의 근거.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `post_id` | uuid | N | - | → `blog.posts` cascade |
| `link_id` | uuid | N | - | → `core.affiliate_links` cascade |
| `provider` | text | N | - | 4개 제공자 |
| `placement` | text | N | card | card, inline, cta |
| `position` | int | N | 0 | 본문 내 순서 |
| `card_snapshot` | jsonb | N | {} | 삽입 시점 상품명·가격·이미지 |
| `inserted_by` | text | N | user | user, auto |

제약: `unique (post_id, link_id)`. 트리거 `post_affiliate_links_consistency`(DEFINER, `1300:270`): 원고·링크·행의 조직이 같고 링크가 `source_app='blog'`이며 제공자가 같아야 한다(service_role 쓰기에도 적용).

### 2.4 `blog.post_publications` (`1300:300`)

목적: 원고 x 채널 계정 발행 1건의 상태와 결과.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| `post_id`, `channel_account_id`, `channel` | - | - | - | 계정 삭제 시 set null |
| `status` | text | N | queued | queued, scheduled, publishing, published, unconfirmed, failed, canceled |
| `scheduled_at` | timestamptz | Y | - | scheduled면 필수(CHECK) |
| `job_id` | uuid | Y | - | → `core.jobs` |
| `attempts` | int | N | 0 | publishing 진입마다 +1 |
| `external_post_id`, `published_url`, `published_at` | - | Y | - | URL은 https |
| `rendered_hash` | text | Y | - | 보낸 HTML sha256 |
| `requires_disclosure`, `disclosure_included`, `affiliate_link_count` | bool/bool/int | N | false/false/0 | 필요 여부와 링크 수는 DB 트리거가 계산 |
| `idempotency_key` | text | Y | - | unique |

제약: `post_publications_disclosure_check`(`1300:328`) — publishing/published/unconfirmed 상태는 `not requires_disclosure or disclosure_included`. 부분 유니크 `post_publications_active_uniq`(같은 원고·계정의 진행 중 발행 1개), `post_publications_external_uniq`(같은 외부 글 중복 기록 방지).

## 3. 상태 전이

### 3.1 `posts.status` (`blog.posts_status_transition`, `1300:214` + 집계 `blog.sync_post_status`, `1300:436`)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| draft | generating | 생성 라우트(service) | ai_job_id 기록 |
| generating | draft | 워커(성공·실패 모두) | 실패면 last_error, 잡이 환불 |
| draft/failed/published/partially_published/scheduled/publishing | 발행 집계 상태 | 발행 행 트리거 | 집계: 진행 중 있음 → publishing, 예약만 → scheduled, 성공+실패 → partially_published, 성공만 → published, 실패만 → failed, 전부 취소 → draft |
| generating/scheduled/publishing 이외 | archived | `blog.set_post_archived` | archived_at |
| archived | draft | `blog.set_post_archived(false)` | archived_at null |

`generating`, `archived`는 집계가 덮어쓰지 않는다. 위반은 22023.

### 3.2 `post_publications.status` (`blog.post_publications_transition`, `1300:400`)

| 현재 | 허용 전이 | 누가 | 부수 효과 |
|---|---|---|---|
| (없음) | queued, scheduled | 발행 라우트(service) | 게이트 트리거: 같은 조직, 계정 active, naver/tistory는 동의, 원고가 generating/archived 아님, 컴플라이언스 pass 또는 warn+확인(BL003/BL005/BL001). 링크 수·문구 필요 계산 |
| queued/scheduled | publishing | 워커 | attempts+1, 링크 수·문구 필요 재계산, 문구 미포함이면 23514 |
| queued/scheduled | canceled | `blog.cancel_publication` | `core.cancel_job`, canceled_at, 감사 |
| scheduled | queued | 워커(간격 규칙으로 재배치) | - |
| publishing | published | 워커 | published_at, 계정 last_published_at |
| publishing | unconfirmed | 워커(발행 클릭 후 URL 미확인) | 자동 재시도 없음 |
| publishing | failed, queued | 워커(`fail_job` 재시도 여부) | last_error |
| unconfirmed | published, failed | `blog.resolve_unconfirmed_publication` | 감사 |
| failed | queued | 재시도 라우트(service) | 새 잡 |

트리거를 고른 이유: 순서 강제만 필요한 전이는 트리거(`DB_CONVENTIONS.md` 10장), 감사·잡 취소 같은 부수 효과가 있는 사용자 전이는 RPC.

### 3.3 `channel_accounts.status`

| 현재 | 허용 전이 | 누가 |
|---|---|---|
| pending | active, error | 검증(라우트 또는 `blog.channel.verify`) |
| active | needs_reauth, error, revoked | 워커, `disconnect_channel_account` |
| needs_reauth/error | active, revoked | 재검증, 해제 |
| revoked | (종료) | 재연결은 새 행 |

## 4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE | GRANT(authenticated) |
|---|---|---|---|---|---|
| `channel_accounts` | `is_org_member(org_id) and has_entitlement(org_id,'blog')` | 없음 | 없음 | 없음 | SELECT |
| `posts` | 같음 | `with check (has_org_role(org_id, owner/admin/member) and has_entitlement)` | `using (has_org_role(...member) and has_entitlement and status not in (generating, publishing)) with check (같은 역할·엔타이틀먼트)` | `using (has_org_role(owner/admin) and status in (draft, failed, archived))` | SELECT, 컬럼 INSERT/UPDATE, DELETE |
| `post_affiliate_links` | 멤버 + 엔타이틀먼트 | 없음 | 없음 | 없음 | SELECT |
| `post_publications` | 멤버 + 엔타이틀먼트 | 없음 | 없음 | 없음 | SELECT |

anon에는 아무 권한이 없다(`1300:750`). `posts`에 쓰기 정책을 준 근거(`SECURITY_BASELINE.md` 4장 (a)~(c)): (a) 모든 쓰기 정책에 `with check`와 멤버·엔타이틀먼트 (b) 돈·권한·외부 발행 결과 컬럼은 컬럼 GRANT에서 빠짐 (c) status는 트리거와 RPC로만 바뀐다. 정책은 `org_members`를 직접 조회하지 않고 코어 헬퍼만 쓴다(42P17 방지). 함수 EXECUTE: 사용자 RPC 7개는 authenticated·service_role, 잠금 2개는 service_role만, 트리거 함수는 PUBLIC·anon·authenticated에서 회수(`1300:723-747`).

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `posts_org_updated_idx (org_id, updated_at desc)` | 원고 목록 |
| `posts_org_status_idx (org_id, status)` | 상태 필터, 대시보드 |
| `post_affiliate_links_post_idx (post_id, position)` | 에디터 카드, 렌더 |
| `post_affiliate_links_link_idx (link_id)` | 링크별 통계 → 원고 |
| `post_publications_org_created_idx (org_id, created_at desc)` | 월 사용량, 최근 발행 |
| `post_publications_org_schedule_idx (org_id, scheduled_at) where scheduled_at is not null` | 캘린더 |
| `post_publications_post_idx (post_id)` | 집계 트리거 |
| `post_publications_job_idx (job_id)` | 워커가 잡 → 발행 행 |
| `post_publications_active_uniq`, `post_publications_external_uniq` | 중복 발행 방지 |
| `channel_accounts_org_idx (org_id, channel)`, `channel_accounts_credential_idx` | 채널 목록, 자격증명 공유 검사 |

규모 가정(제안): 조직당 원고 수천, 발행 행 수만. 월 사용량은 `org_id, created_at` 범위 스캔으로 충분하다.

## 6. 코어 참조

| 코어 객체 | 용도 | 비고 |
|---|---|---|
| `organizations`, `org_members`, `is_org_member`, `has_org_role`, `has_entitlement`, `is_service_caller`, `is_privileged_session`, `set_updated_at`, `guard_privileged_write`, `write_audit` | 테넌시, 정책, 트리거, 감사 | ALTER 없음 |
| `apps`, `plans`, `credit_packs` | 앱·플랜·팩 행 INSERT(`on conflict do nothing`, `1300:33-52`) | 행 추가만, 구조 변경 없음 |
| `encrypted_credentials`, `revoke_credential` | 채널·제휴 비밀 | FK |
| `jobs`, `enqueue_job`, `cancel_job` 등 | 생성·발행 잡 | FK, RPC |
| `affiliate_accounts`, `affiliate_links`, `affiliate_clicks`, `affiliate_disclosures`, `brandconnect_applications` + 함수 6개 | 제휴 전부 | 재정의하지 않음. blog는 매핑과 FK만 |
| `consume/grant/refund_credits`, `wallets`, `credit_ledger` | AI 과금 | 서버만 |
| `payment_orders`, `confirm_payment_order` | 결제 | `confirm_payment_order`는 금액 불일치 시 `PM001`을 올린다. 주문 failed 기록은 별도 호출 `fail_payment_order`(2026-10-13 코어 반영)로 한다 |

AI·음성 코어 객체(2026-10-13, `docs/products/_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql`):

| core 객체 | blog 용도 | 쓰는 쪽 |
|---|---|---|
| `ai_conversations`, `ai_messages` | 도우미 채팅 대화 매핑과 메시지(본인만 SELECT, `0008_core_ai.sql:635-642`) | Next.js(대화 생성, 사용자 메시지), FastAPI(assistant 메시지) |
| `ai_runs`, `ai_run_steps` | 그래프 `blog.post_draft` 실행 기록(`job_id` = `posts.ai_job_id`), 승인 대기 상태, 위키 lint 결과 | FastAPI |
| `ai_usage`(0008 확장 컬럼) | 호출별 사용량, 정산(`settled_at`) | FastAPI, Next.js 음성, 정산 크론 |
| `ai_routing_settings`, `resolve_ai_route` | 기능별 기본값 12행(9절), 경로 결정 | seed, FastAPI, Next.js 음성 |
| `ai_org_settings`, `set_ai_cross_border_ack` | 국외 이전 동의 | 온보딩·설정(사용자 세션) |
| `ai_collections`, `ai_documents`, `ai_chunks`, `match_ai_chunks` | 조직 자료 컬렉션 `blog-materials`, 위키 컬렉션 `blog-wiki` | FastAPI |
| `wiki_pages`, `wiki_links`, `wiki_revisions` | 조직 토픽·키워드 위키 | FastAPI(쓰기), Next.js(조직 멤버 읽기) |
| `voice_sessions`, `voice_jobs` | 받아쓰기·음성 대화 STT·TTS 작업(`store_audio=false`) | Next.js |
| `ai_providers`, `ai_model_prices` | 제공자·단가(코어 seed, 제품은 추가하지 않음) | FastAPI, Next.js |

제품 AI 표를 만들지 않은 이유(`docs/products/_platform-core/AI_ARCHITECTURE.md:165`의 "꼭 필요할 때만"):

| 후보 | 필요해 보인 이유 | 대신 쓰는 것 |
|---|---|---|
| 원고-자료 연결 표 | 어느 자료가 원고의 근거였는지 | 그래프 출력 `sources`를 `core.ai_run_steps.detail`(retrieve 스텝)에 기록하고, 승인 화면은 `posts.ai_job_id` → `ai_runs.job_id`로 읽는다. 채팅 출처는 `ai_messages.citations` |
| 승인 기록 표 | 발행 전 사람 승인 증빙 | `core.ai_runs`(run `succeeded`, `approve` 스텝 `succeeded`)와 감사 로그 `blog.ai.draft_approved`(행위자, 원고, run id) |
| 키워드 리서치 결과 표 | 추천 키워드·의도 보관 | `ai_run_steps.detail`(keyword 스텝)과 위키 `topic` 페이지 |
| 자료·위키 문서 표 | 브랜드·캠페인 자료 관리 | `core.ai_documents`, 파일은 Storage `org-files/<org>/blog/materials/<uuid>` |
| 음성 고지 동의 표 | 음성 처리 고지 증빙 | 감사 로그 `blog.voice.notice_ack {notice_version}`. 녹음 원본을 저장하지 않으므로 `voice_jobs` 동의 컬럼은 쓰지 않는다 |
| 국외 이전 동의 사본 | 동의 증빙 | `core.ai_org_settings.cross_border_ack_at/notice` + 감사 `blog.ai.cross_border_ack` |

승인 상태를 새 컬럼으로 두지 않는 대신 발행 라우트가 서버에서 `core.ai_runs`를 읽어 확인한다(04장 2절 publish 행). 이 확인은 DB 불변식이 아니라 서버 규칙이다. 그래서 06장 BL-06-056 회귀 테스트가 승인 없는 발행 요청 409를 검증한다. DB가 지키는 대가성 문구·컴플라이언스 게이트(BL003, 23514)는 그대로다.

`core.*`를 ALTER하는 문장이 조각에 없음을 확인했다. 9절의 `core.plans` UPDATE(9.2)는 blog 자신의 플랜 행 `features`에 AI 키를 병합하는 데이터 변경이며 표 구조는 바꾸지 않는다.

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/NOMAD_Shorts_Maker.md` 3장 #1 | `docs/reviews/NOMAD_Shorts_Maker.md:78` | `add_credits`/`deduct_credits` EXECUTE 미회수로 브라우저에서 크레딧 충전 | 리뷰 #1 → 차단 설계: blog 조각에 크레딧 함수가 없다. 차감은 코어 `consume_credits`(service_role 전용, `migrations/0003_core_credits.sql:370-375`)를 Route Handler가 호출. 제품 함수는 PUBLIC EXECUTE 회수 후 허용 목록만(`1300:723-747`). 스모크: 사용자 `grant_credits`/`consume_credits` 42501 | 4절, BL-06-027 |
| 같은 리뷰 #2 | `:79` | Toss 웹훅 서명 "있을 때만" 검증, orderId 파싱으로 플랜·크레딧 변경 | 리뷰 #2 → 차단 설계: 공용 webhooks 모듈만 사용(서명 없으면 401, `webhook_events` 멱등). 지급은 confirm 경로만, 웹훅은 상태 동기화 | BL-06-024 |
| 같은 리뷰 #3 | `:80` | checkout과 웹훅의 orderId 형식 불일치로 정상 결제 미처리 | 리뷰 #3 → 차단 설계: 주문은 `core.payment_orders` 선저장, orderId에서 정보를 파싱하지 않고 주문 행을 조회. blog에는 결제 테이블이 없다 | BL-06-024, BL-06-028 |
| 같은 리뷰 #5 | `:82` | OAuth 콜백이 state의 orgId를 신뢰, 세션·CSRF 검증 없음 | 리뷰 #5 → 차단 설계: OAuth가 필요한 채널(Phase 2 인스타그램)은 `create_oauth_state`/`consume_oauth_state`만 사용. 네이버·티스토리·워드프레스 연결은 로그인 세션의 owner/admin이 직접 하는 서버 라우트이고 org는 세션에서만 얻는다. 채널 행 쓰기는 service_role + guard | 2.1절, BL-06-009 |
| 같은 리뷰 #7 | `:84` | `ENCRYPTION_KEY` 없으면 0키로 암호화(사실상 평문). CA는 세션 쿠키를 평문 저장(`NOMAD Shorts Maker/src/app/api/accounts/[id]/connect/route.ts:30`) | 리뷰 #7 → 차단 설계: blog 테이블에 비밀 컬럼이 없다(세션 쿠키 포함 전부 `encrypted_credentials.ciphertext`). 키는 `CREDENTIALS_KEY_V<n>`, 누락 시 웹·워커 기동 실패. 스모크: 사용자 `encrypted_credentials` SELECT 42501 | 2.1절, 02장 8절, BL-06-009 |
| `docs/reviews/Youtube_shots_Maker.md` 3장 #2 | `docs/reviews/Youtube_shots_Maker.md:83` | OAuth state가 서명 없는 base64 JSON, user_id 신뢰 | 리뷰 #2 → 차단 설계: YSM OAuth 라우터를 이식하지 않는다. OAuth는 코어 `oauth_states`(32바이트 난수, 1회 소비, 10분 TTL, 멤버십 확인) | BL-06-009 |
| 같은 리뷰 #3 | `:84` | 네이버 로그인 시 이메일만으로 기존 계정에 매직 링크 발급, `listUsers` 1페이지 | 리뷰 #3 → 차단 설계: MVP에 네이버 소셜 로그인을 넣지 않는다. 확정 결정 22로 C2(G2 후, BL-06-059)에서 도입하며 이메일 자동 병합 금지, 네이버 고유 id 매핑과 로그인 상태에서의 명시적 연결만(01장 8.1절, `AUTH_ROADMAP.md` 7.2.3절 5c). 블로그 채널용 네이버 자격증명은 로그인 신원과 무관하며 조직 데이터로만 저장 | BL-06-004, BL-06-059 |
| 같은 리뷰 #4 | `:85` | 태스크 결과 조회가 소유권 미확인(IDOR) | 리뷰 #4 → 차단 설계: 잡 진행·결과는 `core.jobs` RLS(멤버만, `migrations/0005_core_jobs_storage.sql:51-54`)로만 읽고, 발행 행·매핑도 멤버+엔타이틀먼트 SELECT 정책. task id 기반 조회 API를 만들지 않는다. 스모크: 타 조직 사용자 jobs/발행 0행 | 4절, BL-06-027 |

## 8. 모놀리스와 모듈러의 차이

| 항목 | 모듈러 | 모놀리스 |
|---|---|---|
| 스키마 | `blog` + `core` | `public`(코어와 제품 모두). `_platform-core/MONOLITH_CORE_LITE.sql`의 결정이며 최종 사용자 확인 대기 |
| 함수 | `blog.cancel_publication` 등 | `public.cancel_publication` 등(이름·시그니처 동일) |
| 앱·플랜·팩 행 | 조각 머리 `on conflict do nothing` + 공용 seed | `seed.sql`(upsert) |
| 권한 | 조각이 명시 GRANT | 코어 SECTION 0이 기본 권한 회수, 0002가 `revoke all ... from public, anon, authenticated` 후 GRANT |
| 코어 [선택] 절 | 해당 없음 | 하나도 지우지 않음(Toss, 크레딧, OAuth/자격증명/레이트리밋, 잡, Storage, affiliate 모두 사용) |
| AI·음성 코어 | `0008_core_ai.sql`, `0009_core_voice.sql`(제공자·단가·플랫폼 기본 라우팅은 모듈러 `seed.sql`) | `0001_core_lite.sql` SECTION 11, 12(제공자·단가·플랫폼 기본 라우팅 포함) |
| AI 라우팅 기본값 | `1300_blog.sql` 9.1절 | `seed.sql`(같은 12행) |
| 플랜 AI 키 | `1300_blog.sql` 9.2절 병합 UPDATE(모듈러 `seed.sql` 반영 요청 AI-R2) | `seed.sql` 플랜 3행 `features`에 직접 |
| 체인 검사 | 9.3절 DO 블록(제공자 행이 없으면 건너뜀) | `seed.sql` 끝 DO 블록(제공자는 0001이 먼저 넣음) |
| 변환 | 정본 | 정본 조각을 `DB_CONVENTIONS.md` 12장 규칙으로 기계 변환(BL-06-002) |

## 9. 마이그레이션 파일

| 파일 | 내용 |
|---|---|
| `docs/products/_supabase-modular/migrations/1300_blog.sql` | 스키마, 앱·플랜 3·팩 3, 4테이블, 트리거 6, 사용자 RPC 7, 워커 RPC 2, 정책, Realtime, PUBLIC EXECUTE 최종 회수(8절), 9절 AI·음성 기본값(라우팅 12행, 플랜 AI 키, 체인 검사). 선행 0000~0009 |
| `supabase/monolith/migrations/0001_core_lite.sql` | 코어 원본 그대로(머리 주석만 추가) |
| `supabase/monolith/migrations/0002_blog_domain.sql` | 위 조각의 public 변환본 |
| `supabase/monolith/seed.sql` | apps 1, plans 3(AI 키 포함), credit_packs 3, 대가성 문구 blog_top 4, AI 라우팅 기본값 12행 + 체인 검사 |

2026-10-13 재검증(PGlite `--vector`, `docs/products/_tools-sqlcheck/check.mjs`):

| 검사 | 결과 |
|---|---|
| `check.mjs --vector mod` 0000~0009 + `seed.sql` + `1300_blog.sql` | 전부 OK |
| `check.mjs --vector mono` 0001 + 0002 + `seed.sql` | 전부 OK |
| 제품 파일 2회 반복 적용 후 `ai_routing_settings`(org null, app blog) | 12행(모듈러·모놀리스) |
| 플랜 3행 `features` | 기존 키 + `ai_chat`, `ai_chat_turns_per_day`(50/200/500), `voice_chat`, `dictation`, `rag_documents`(10/100/1000), `product_wiki`(false/true/true) |
| 미동의 조직 `resolve_ai_route` | `blog.post_draft` = oss-llm, `dictation` stt = oss-voice, `blog.knowledge` = oss-embed |
| 동의 후 | `blog.post_draft` = anthropic → openai → google → oss-llm, `voice_chat` tts = elevenlabs 먼저, `dify.aux`는 계속 oss-llm(강제), ` Wiki.Lint `(대소문자·공백)도 `wiki.lint` 행으로 해석 |

검증(2026-10-12, PGlite, `docs/products/_tools-sqlcheck`):

| 검사 | 결과 |
|---|---|
| `node check.mjs mod 0000~0007 + seed + 1300_blog.sql` | OK(반복 실행, seed 없이 적용도 OK) |
| blog 함수 15개의 PUBLIC EXECUTE(모듈러·모놀리스) | 0개. 조각 끝에 `revoke execute on all functions in schema blog from public`(0007 규칙), 모놀리스는 함수별 회수 |
| `node check.mjs mono 0001_core_lite + 0002_blog_domain + seed` | OK(반복 실행 OK) |
| RLS 스모크(모듈러) | 69항목 통과, 0 실패 |
| RLS 스모크(모놀리스) | 67항목 통과, 0 실패(엔타이틀먼트 없는 사용자 C 2항목은 단일 앱이라 제외) |

스모크 주요 항목: 다른 조직 사용자 B가 A의 posts/channel_accounts/post_affiliate_links/post_publications/affiliate_links/jobs 0행, A 조직에 원고 INSERT 42501, UPDATE·DELETE 0행, 발행 UPDATE·매핑 DELETE 42501, 제품 RPC 7개 42501, `upsert_affiliate_disclosure`·`consent_brandconnect_risk`·`create_brandconnect_application`(A) 42501, 자기 엔타이틀먼트·구독·지갑·역할·platform_role 변경 42501, `grant_credits`/`consume_credits`/원장 INSERT 42501, 채널 계정 INSERT 42501, `encrypted_credentials` SELECT 42501, 자기 조직 원고 INSERT 성공(양성 대조). A: status·compliance 컬럼 직접 변경 42501, 콘텐츠 변경 시 version 증가와 검사 무효화, 워커 잠금 RPC 42501. 서비스: 동의 없음 BL005, 미검사 BL003, 진행 중 중복 23505, 문구 없이 publishing 23514, 잘못된 전이 22023, 타 조직 링크 매핑 42501, 잠금 2중 획득 false, 취소 시 core 잡 canceled, 원고 집계 상태 계산, 공유 자격증명 해제 시 암호문 유지. 엔타이틀먼트 없는 조직(C) 원고 INSERT 42501. 스크립트는 BL-06-027이 `supabase/tests/`로 옮긴다.

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-14 추가, 확정 결정 22)

스키마 변경 없음. 인증 단계는 코어 계약(`core.profiles`, `org_members`, `app_entitlements`, `session_context`) 위에서 동작하고 blog 스키마는 바뀌지 않는다. C2에서 브리지 경로를 택하면 코어 `docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`을 참조만 한다(06장 6.2절 요청). 정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`(이하 AUTH_ROADMAP) 2.2·2.3절이다.

시드는 `scripts/dev/seed-users.mjs --app blog`(공통 행) 뒤에 제품 훅 `scripts/dev/seed-users.blog.mjs`(blog 행)를 실행한다. 둘 다 Supabase 호스트가 `127.0.0.1`·`localhost`가 아니면 즉시 종료하고, 멱등이다(이미 있는 이메일은 건너뛰고 상태만 맞춤). 계정은 `auth.admin.createUser(..., email_confirm: true, user_metadata: { signup_app: 'blog' })`로 만들어 실제 가입 트리거(`migrations/0001_core_identity.sql:113`)를 탄다.

### 10.1 공통 페르소나 (AUTH_ROADMAP 2.2절, blog 기대값)

| 키 | 만드는 방법 | 기대 `session_context('blog')` | blog에서의 쓰임 |
|---|---|---|---|
| `owner` | `signup_app='blog'`. 이어서 owner 세션으로 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack: true, p_notice_version: AI_CROSS_BORDER_NOTICE_VERSION })`(`migrations/0008_core_ai.sql:553`) | 개인 조직 owner, `entitled=true`, `plan_code='free'`, `credit_balance=20`(01장 BL-F-001) | 기본 사용자. 원고 생성·검사·워드프레스 발행 E2E(BL-06-037), AI 기능(국외 이전 동의 완료 상태) |
| `admin` | 생성 후 owner 세션이 `invite_member(owner_org, admin, 'admin')` → admin 세션이 `accept_invite` | owner 조직 admin | 위험 동의·채널 연결·대가성 문구 편집(owner/admin) 양성 대조 |
| `member` | 같은 방법(member) | owner 조직 member | 동의 버튼 403(BL-F-031), 채널 연결 403, 원고 작성 허용 |
| `viewer` | 같은 방법(viewer) | owner 조직 viewer | 에디터 읽기 전용, 발행 요청 403 |
| `outsider` | `signup_app='blog'`(다른 개인 조직). 국외 이전 선택 안 함(`ai_org_settings` 행 없음) | 자기 조직 owner, Free | 교차 테넌트: owner 조직의 posts·channel_accounts·post_publications·`ai_conversations`·`wiki_pages` 0행, 다른 조직 `post_id`로 채팅 403. AI 버튼 잠김 → `/onboarding/ai` 이동 |
| `no_app` | `signup_app` 없이 생성 | 모듈러: `entitled=false` → `finishLogin`이 `bootstrap_app_for_org('blog')` 1회 후 `entitled=true`, 크레딧 20(재로그인해도 1회). 모놀리스: 앱 행 1개라 가입 트리거가 이미 부트스트랩해 처음부터 `entitled=true`(AUTH_ROADMAP 3.2절) | OAuth 첫 로그인 경로(B-1)의 A단계 사전 검증(모듈러) |
| `suspended` | 생성 후 service_role로 `status=suspended` | 403 | 정지 안내 화면 |
| `ops` | 생성 후 service_role로 `platform_role=platform_admin` | 운영자 | 운영 화면(있을 때) |
| `pending` | 만들지 않음 | - | blog는 open 앱(approval 아님) |

Free 플랜 `team_members=1`(`1300_blog.sql:38`)은 설정 > 멤버 초대 라우트(BL-06-027)의 서버 판정이고 코어 `invite_member`(`migrations/0004_core_security.sql:317`)는 플랜 한도를 보지 않는다. 시드는 RPC를 직접 불러 Free 조직에 admin·member·viewer를 만든다. 이것은 개발 데이터일 뿐이며 제품 초대 라우트의 Free 403 검사는 별도 테스트로 한다.

### 10.2 blog 도메인 페르소나 (제품 훅 `seed-users.blog.mjs`)

| 키 | 이메일 | 만드는 방법(실제 RPC·서비스 경로) | 기대 결과 | 쓰임 |
|---|---|---|---|---|
| `owner_pro` | `owner_pro@dev.test` | `signup_app='blog'`로 생성 → service_role로 `core.app_entitlements`의 plan을 `pro`로 바꾸고 `source='manual'`(제안: Toss 결제 경로는 결제 E2E BL-06-029가 검증하므로 시드는 직접 갱신) → `grant_credits(org, 300, 'blog', 'dev_seed_pro', 'plan', p_idempotency_key => 'dev:pro:<org>', p_reset_plan_bucket => true)`(이월 없음, 01장 4.1절) → owner 세션 `set_ai_cross_border_ack(true)` | `plan_code='pro'`, `credit_balance=300`(Free 월 20을 만료 처리 후 Pro 월 300, 01장 BL-F-004와 같은 값), 브랜드커넥트·예약 발행·고품질·제휴 자동 삽입·위키 사용 가능 | 캘린더·예약 발행, 브랜드커넥트 동의 화면, 위키(Pro 이상), 고품질 모드 게이팅 양성 대조 |

시드가 만들지 않는 것: 블로그 채널 계정(`blog.channel_accounts`)과 네이버·티스토리 자격증명, 브랜드커넥트 계정·동의, 제휴 계정·키. 블로그 게시용 네이버 계정은 사용자 로그인 신원과 무관한 조직 데이터(7절 YSM #3 행)이고 실제 비밀이 필요하므로 페르소나에 섞지 않는다. 발행 테스트는 로컬 WordPress 컨테이너와 녹화 픽스처(BL-06-030)를 쓰고, 테스트가 필요한 채널 행은 각 테스트가 service_role로 만들고 지운다.

### 10.3 모놀리스와 모듈러 차이

| 항목 | 모듈러(`core` 스키마) | 모놀리스(`public`, 이번 개발 기본) |
|---|---|---|
| `no_app` | `entitled=false`로 시작, `finishLogin` 부트스트랩 1회 | 가입 트리거가 자동 부트스트랩(`MONOLITH_CORE_LITE.sql` 머리말 b항), `bootstrap_app_for_org` 호출은 무동작. 같은 코드 |
| `--app` | 통합 DB면 여러 번 줄 수 있음(두 번째 앱부터 `bootstrap_app_for_org`) | `--app blog` 하나 |
| RPC 이름 | `core.invite_member` 등 | `public.` 같은 이름(05장 8절) |
