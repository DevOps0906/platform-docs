# 05 데이터 모델: 로컬뉴스 클라우드(가칭) (local-news)

작성일 2026-10-15. 신규 기획(원본 프로젝트·리뷰 없음). 정본 SQL은 `docs/products/_supabase-modular/migrations/2500_news.sql`(아래 "조각:줄")이다. 모놀리스 `supabase/monolith/migrations/0003_local_news_domain.sql`은 조각을 `DB_CONVENTIONS.md` 12장 규칙으로 변환한 것이고 직접 고치지 않는다. 규칙 문서는 `docs/products/_platform-core/DB_CONVENTIONS.md`(아래 DBC), `SECURITY_BASELINE.md`(아래 SB). 이름·ID·결정의 정본은 마스터 브리프(1차 DB 구조 = 모놀리스 단독 프로젝트, 결정 D-2)다.

## 1. 개요와 ERD

설계 원칙:

| 원칙 | 내용 | 근거 |
|---|---|---|
| 테넌트 = 신문사 | 신문사 1곳 = `core.organizations` 1행(`is_personal=false`) + `news.newspapers` 1행. 모든 제품 테이블에 `org_id` | DBC 3장, 마스터 브리프 1장 |
| 편집국 = 코어 멤버 + 도메인 역할 | `core.org_members`(active) + `news.staff`(active, 역할 6종). 코어 매핑 publisher=owner, editor=admin, 나머지=member. 정책은 `news.is_newsroom(org, roles)` 하나로 판정 | 마스터 브리프 2장, 조각:1767-1803 |
| 독자는 조직 멤버가 아니다 | `news.readers(org_id, user_id)`. 같은 사람이 A·B 신문의 독자가 될 수 있고 신문사는 자기 독자 행만 본다 | 마스터 브리프 2장, 6장 |
| 방문자는 공개 컬럼만 | anon 은 공개 조건(신문사 활성 + 필요적 게재사항 완성 + 엔타이틀먼트 활성 + 게시 시각 도래 + 엠바고 해제)을 만족한 행의 공개 컬럼만 SELECT. 기사 본문·댓글·독자·제보는 공개 함수로만 | DBC 7장 "공개 읽기", 조각:1805-1861 |
| 쓰기는 RPC 와 service_role 만 | 40개 테이블 전부 사용자 INSERT/UPDATE/DELETE GRANT 없음, `FOR ALL` 정책 0개, 쓰기 정책 0개, `guard_privileged_write` 이중 잠금 | DBC 8장, 조각:1720-1746 |
| 상태 전이는 트리거, 누가는 RPC | 상태 컬럼마다 BEFORE UPDATE 트리거가 허용 전이 외 22023. 역할·요건은 SECURITY DEFINER RPC 가 검사 | DBC 10장 |
| 법은 DB 제약으로 | 기사형 광고 라벨, AI 고지, 보도자료 AI 초안 유형 고정, 여론조사 표시, '(광고)' 메일 제목, 정정 기한 불변은 CHECK·트리거가 강제 | 7장 |
| 공통모듈 8개는 1차로 한 스키마 안의 절 | M1~M8(+ local-life)을 `news` 스키마 절로 둔다. 다른 제품이 쓰면 `COMMON_MODULES_ROADMAP.md` 3장 공용 스키마로 추출 | 마스터 브리프 3장 |

```
core.organizations (참조: 신문사 = 조직)
 ├── news.newspapers (org 1:1, 매체정보·법정 푸터·댓글 스위치·금칙어)        <- news.newspaper_applications (개설 신청, 승인 시 org 생성)
 ├── news.staff (org_id, user_id) ──(같은 키)── core.org_members
 ├── M1 newsroom-cms
 │    ├── news.sections / news.regions / news.tags (자기참조 parent, (id, org_id) 유일)
 │    ├── news.wire_contracts (M6, 기사보다 먼저 생성)
 │    ├── news.media_assets
 │    ├── news.articles ──> sections, wire_contracts, media_assets (hero)  [(x_id, org_id) 복합 FK]
 │    │     ├── news.article_revisions (append-only, 공개 정정 메모)
 │    │     ├── news.article_regions ──> regions,  news.article_tags ──> tags
 │    │     ├── news.live_updates
 │    │     ├── news.comments ──> readers  └── news.comment_reports ──> readers
 │    │     └── news.article_view_hourly (M8)
 │    ├── news.home_layouts, news.print_editions
 ├── M2 reader-membership: news.readers ──> regions
 │    ├── news.membership_tiers ── news.memberships ──> readers, core.encrypted_credentials(신문사 Toss 가맹 키)
 │    ├── news.donations ──> readers(선택)
 │    └── news.paywall_rules (org 1:1)
 ├── M3 ad-manager: news.ad_slots, news.advertisers ── news.ad_campaigns ── news.ad_creatives ──> ad_slots
 │    ├── news.ad_daily_stats ──> ad_creatives
 │    ├── news.local_listings ──> readers, regions
 │    └── news.public_notices ──> regions
 ├── M4 notify-newsletter: news.newsletter_lists ── news.newsletter_subscriptions ──> readers(선택)
 │    ├── news.newsletter_issues ──> newsletter_lists
 │    └── news.push_subscriptions ──> readers(선택)
 ├── M5 community: news.tips ──> readers(선택), news.life_events ──> readers(선택)
 ├── M6 distribution-seo: news.syndication_settings (org 1:1)
 ├── M7 compliance-desk: news.correction_requests ──> articles, readers(선택) ; news.election_periods ; 뷰 news.correction_sla
 └── local-life: news.events ──> regions
코어 참조(6장): core.app_entitlements·plans(플랜 해석), core.subscriptions, core.credit_ledger(월 AI 크레딧), core.audit_log,
  core.rate_limit_buckets, core.encrypted_credentials, Storage 버킷(public-assets, org-files), core.ai_*·wiki_*·voice_*(AI·음성)
화이트라벨(Multi-tenant_Theming): core.tenant_themes·tenant_domains·resolve_tenant(org_id 키, 이 조각은 직접 참조하지 않는다)
```

모듈별 테이블 수:

| 모듈 | 테이블 | 수 |
|---|---|---|
| M1 newsroom-cms | newspaper_applications, newspapers, staff, sections, regions, tags, media_assets, articles, article_revisions, article_regions, article_tags, home_layouts, print_editions, live_updates | 14 |
| M2 reader-membership | readers, membership_tiers, memberships, donations, paywall_rules | 5 |
| M3 ad-manager | ad_slots, advertisers, ad_campaigns, ad_creatives, ad_daily_stats, local_listings, public_notices | 7 |
| M4 notify-newsletter | newsletter_lists, newsletter_subscriptions, newsletter_issues, push_subscriptions | 4 |
| M5 community | comments, comment_reports, tips, life_events | 4 |
| M6 distribution-seo | wire_contracts, syndication_settings | 2 |
| M7 compliance-desk | correction_requests, election_periods (+ 뷰 correction_sla, 함수 compliance_weekly_stats) | 2 |
| M8 search-analytics | article_view_hourly (+ 함수 most_read, search_articles) | 1 |
| local-life | events | 1 |
| 합계 | | 40 |

## 2. 테이블

공통(DBC 3장): `id uuid primary key default gen_random_uuid()`(집계 원장 `ad_daily_stats`는 `bigint identity`, `article_view_hourly`·`article_regions`·`article_tags`는 복합 PK), `org_id uuid not null references core.organizations(id) on delete cascade`, `created_at`, UPDATE가 있는 테이블은 `updated_at` + `core.set_updated_at` 트리거(조각:1720-1746 일괄), 열거형은 text + CHECK(DBC 6장), 행위자 컬럼(`created_by`, `approved_by` 등)은 FK 없는 uuid. `deleted_at`은 두지 않는다: 기사는 `archived` 상태로, 분류는 `is_active=false`로, 독자는 `withdrawn`으로 내리고 개인정보 삭제는 행 단위 비식별화다. 예외: `newspaper_applications.org_id`는 승인 전 조직이 없어 nullable이다(신청자 개인 조직 `applicant_org_id`가 Storage 첫 폴더). `staff.user_id`와 `readers.user_id`는 멤버십 성격이라 `auth.users(id) on delete cascade`(코어 `org_members`와 같은 방식).

교차 신문사 참조 차단: 하위 테이블은 `(x_id, org_id) → 부모(id, org_id)` 복합 FK다(부모에 `unique (id, org_id)`). 다른 신문의 섹션·사진·계약·독자·댓글을 참조하면 23503(스모크 7절).

### 2.1 M1: 신문사·편집국

`news.newspaper_applications` (조각:83-112) 목적: 신문사 개설 신청(NW-F-001). 승인 전에는 조직이 없다.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| applicant_id | uuid | N | - | 신청자 auth 사용자 |
| applicant_org_id | uuid | N | - | 신청자 개인 조직(FK). 등록증 경로 첫 폴더 |
| org_id | uuid | Y | - | 승인 후 생성된 신문사 조직(on delete set null) |
| slug | text | N | - | 서브도메인 슬러그 `^[a-z][a-z0-9-]{1,30}[a-z0-9]$`. 예약어(www, newsroom, login, admin, api 등) 거부(NW001) |
| title, media_kind | text | N | - | 제호(1~80), internet/daily/weekly/monthly/other |
| registration_no, registration_date, publisher_name | text, date, text | N | - | 정기간행물 등록 정보 |
| contact_email, contact_phone | text | N | - | 형식 CHECK |
| certificate_path | text | N | - | 등록증 사본. CHECK `is_org_path(applicant_org_id, certificate_path, 'applications')` |
| status | text | N | 'pending' | pending, approved, rejected, withdrawn |
| plan_code, decided_at, decided_by, decision_note | | Y | - | 승인 결과 |

제약: 진행 중 신청은 슬러그당 1건·신청자당 1건(부분 유니크).

`news.newspapers` (조각:118-148) 목적: 매체정보와 신문사 설정. 신문법 제21조 필요적 게재사항, 시행령 제7조의2 청소년보호책임자(research/MARKET_LEGAL.md 규제 표, https://www.wipo.int/wipolex/en/text/438729 , 현행 조문은 미확인).

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| org_id | uuid | N | - | 유일(조직 1:1) |
| application_id | uuid | Y | - | 개설 신청 |
| status | text | N | 'active' | active, suspended, closed |
| title | text | N | - | 제호(필수 10항목 중 1) |
| legal_name, registration_no, registration_date, publisher_name, editor_name, youth_officer_name, publish_address, phone, first_published_on | text/date | Y | - | 필수 10항목의 나머지 9. 하나라도 비면 비공개 |
| media_kind | text | N | 'internet' | 매체 종류 |
| privacy_officer_name, email, ethics_code_url | text | Y | - | 선택(개인정보 보호책임자, 대표 메일, 윤리강령 링크) |
| comments_enabled | boolean | N | false | 신문사 댓글 스위치. 기본 끔(D-6) |
| banned_words | text[] | N | '{}' | 댓글 금칙어(최대 500). anon GRANT 없음 |
| profile_completed_at | timestamptz | Y | - | 트리거 계산(조각:150-181). 필수 10항목이 모두 있으면 처음 완성 시각, 하나라도 비면 null. 사용자·서버 모두 직접 지정 불가(트리거가 덮어씀) |
| status_reason, created_by | | Y | - | |

`news.staff` (조각:189-212) 목적: 편집국 구성원과 도메인 역할. `(org_id, user_id)` 유일, 조직당 publisher 1명(부분 유니크 `staff_one_publisher_idx`).

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| user_id | uuid | N | - | auth 사용자(on delete cascade) |
| role | text | N | - | publisher, editor, desk, reporter, contributor, ad_manager |
| status | text | N | 'invited' | invited, active, removed |
| byline_name | text | N | - | 바이라인(1~40) |
| title_label, bio, photo_path, email_public | text | Y | - | 기자 페이지 공개 프로필. photo_path CHECK `<org>/news/staff/` |
| is_public_profile | boolean | N | true | 기자 페이지 공개 |
| invited_by, joined_at, removed_at | | Y | - | 전이 트리거가 시각 기록 |

`news.sections`, `news.regions`, `news.tags` (조각:245-289): `slug`(조직 안 유일), `name`(1~40), `sort_order`, `is_active`. sections·regions는 `parent_id` 자기참조 복합 FK. regions는 `level`(sido, sigungu, eupmyeondong, custom)과 `admin_code`(행정코드 숫자). tags 슬러그는 한글 허용.

`news.wire_contracts` (조각:294-312) 목적: 통신사 전재 계약(M6, NW-F-043). `provider`(yonhap, newsis, news1, other), `starts_on`·`ends_on`(date), `attribution_text`(필수, 출처 표기), `allow_full_text`, `status`(active, terminated). KST 날짜로 만료를 판정하고 만료·해지 계약의 wire 기사는 공개 조건에서 빠진다(`article_is_live`, 조각:1833-1850).

`news.media_assets` (조각:317-346) 목적: 미디어 라이브러리(NW-F-014). `storage_path` CHECK `<org>/news/media/`, `bucket`(public-assets 기본, org-files), `mime`, `width`, `height`, `bytes`, `alt_text`(필수 1~300), `credit`(출처 필수 1~200), `caption`, `copyright_holder`, `license`(own, wire, licensed, cc, reader, press_release, other), `ai_generated` + `ai_disclosure`(AI 이미지면 고지 필수 CHECK), `status`(active, archived), `published_at`(공개 기사가 처음 참조한 시각, `publish_article`이 기록). `(bucket, storage_path)` 유일.

### 2.2 M1: 기사

`news.articles` (조각:359-441) 목적: 기사. 상태는 3장.

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| slug | text | N | - | 조직 안 유일. 한글 허용, 미지정 시 `a` + 12자리 난수 |
| title, subtitle, summary | text | N/Y/Y | - | 300/300/1000자 |
| body | jsonb | N | '[]' | 블록 배열(문단, 소제목, 사진, 인용, 표, 임베드). anon GRANT 없음(본문은 `read_article`만) |
| body_text | text | N | '' | 검색용 평문(서버 생성). anon GRANT 없음 |
| type | text | N | 'original' | original 자체, wire 전재, press_release 보도자료, contribution 기고, sponsored 기사형 광고 |
| origin | text | N | 'human' | human, ai_press_release(보도자료 AI 초안), import(이관). 만든 뒤 불변(트리거), 서버만 human 외 값 지정 |
| section_id, author_id, byline | uuid, uuid, text | Y/Y/N | - | 섹션(복합 FK), 바이라인 주인(staff), 표시 바이라인 |
| status | text | N | 'draft' | 3장 |
| is_premium | boolean | N | false | 프리미엄(멤버만 본문) |
| sponsor_label | text | Y | - | CHECK `articles_sponsor_label_check`(조각:420-422): sponsored 면 '광고', '기사형 광고', '후원 콘텐츠', '협찬', 'AD' 중 하나 필수, 그 외 유형은 null |
| ai_assisted, ai_disclosure | boolean, text | N, Y | false | AI 보조면 고지 문구 5~300자 필수(조각:424) |
| wire_contract_id | uuid | Y | - | wire 유형만(복합 FK) |
| source_note | text | Y | - | 출처 표기(보도자료 제공 기관 등) |
| is_poll, poll_disclosure | boolean, text | N, Y | false | 여론조사 보도면 조사기관·표본 등 표시 10~1000자 필수(조각:429) |
| is_breaking, is_live, comments_enabled | boolean | N | false, false, true | 속보 바, 라이브 기사, 기사별 댓글(신문사 스위치와 AND) |
| embargo_until | timestamptz | Y | - | 엠바고. 이 시각 전에는 게시 상태여도 비공개 |
| hero_media_id, media_ids | uuid, uuid[] | Y, N | -, '{}' | 대표 사진(복합 FK), 본문 사진(최대 200, RPC 가 같은 조직 확인 23503) |
| seo | jsonb | N | '{}' | 메타 제목·설명·OG |
| review_note | text | Y | - | 반려 사유, 예약 게시 실패 사유 |
| submitted_at/by, approved_at/by, scheduled_for, published_at, first_published_at, unpublished_at, unpublish_reason, archived_at | | Y | - | 전이 시각. `approved_by`는 사람(auth.uid)만. `first_published_at`은 한 번 정해지면 불변(주간 지표 기준) |
| revised_at, revision_note, revision_count | | Y/Y/N | 0 | 게시 후 내용 수정 표시(공개, NW-F-017) |
| last_corrected_at, correction_count | | Y/N | 0 | 정정·반론·추후보도 표시 |
| legacy_id, legacy_url | text | Y | - | 이관 원본 id·URL(리디렉션 맵, NW-F-063). `(org_id, legacy_id)` 부분 유일 |
| search_tsv | tsvector | Y | - | 트리거 계산(제목 A, 부제·요약 B, 본문 C, `simple` 사전) |

추가 CHECK: `articles_ai_origin_check`(조각:426) origin 이 ai_press_release 면 type 은 press_release 이고 ai_assisted 는 true. `articles_wire_contract_check` 계약은 wire 유형만. `articles_published_at_check`, `articles_scheduled_for_check`.

`news.article_revisions` (조각:500-532) 목적: 저장·워크플로·정정 이력, append-only(UPDATE 22023, 삭제는 기사 삭제 연쇄와 service 만). `kind`(save, submit, approve, reject, schedule, publish, unpublish, archive, update, correction, clarification, rebuttal, follow_up), `status_after`, `title`·`body` 스냅샷, `note`, `is_public`(공개 메모: update 와 정정 계열만, CHECK), `correction_request_id`.

`news.article_regions`, `news.article_tags` (조각:536-557): `(article_id, region_id|tag_id)` PK, 양쪽 복합 FK. `save_article`이 통째로 교체한다.

`news.home_layouts` (조각:563-613): `template`(traditional = A 전통 신문형, magazine = B 모던 매거진형, feed = C 모바일 피드형), `blocks` jsonb 배열(최대 60, 블록 키·순서·ON/OFF·설정), `status`, `publish_at`, `published_at`, `published_by`, `version`. 조직당 게시본 1개(부분 유니크). 게시본·보관본의 blocks·template 수정 22023(복제해서 새 초안으로).

`news.print_editions` (조각:617-634): `edition_date`, `issue_no`(조직 안 유일), `title`, `pdf_path`(CHECK `<org>/news/print/*.pdf`, org-files 비공개, 서버 서명 URL), `page_count`, `status`(draft, published, archived), `published_at`. 플랜 `news_print_pdf`가 false 면 저장 NW014.

`news.live_updates` (조각:638-650): 라이브 기사 타임라인. `article_id`(복합 FK), `body`(1~5000), `is_pinned`, `status`(visible, hidden), `posted_at`, `posted_by`.

### 2.3 M2: 독자·멤버십

`news.readers` (조각:662-687) 목적: 신문사별 독자 행(NW-F-006).

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| user_id | uuid | N | - | auth 사용자. `(org_id, user_id)` 유일 |
| nickname | text | N | - | 2~20자. 조직 안 대소문자 무시 유일(탈퇴 제외) |
| email | text | Y | - | 가입 시 `core.profiles.email` 복사(신문사가 처리자, 탈퇴 시 null) |
| status | text | N | 'active' | active, blocked, withdrawn |
| is_over_14 | boolean | N | - | CHECK true. 만 14세 미만은 받지 않는다(법정대리인 동의 흐름은 Phase 2, 개인정보보호법) |
| terms_version, privacy_version, consent_at | text, text, timestamptz | N | -, -, now() | 동의 기록 |
| marketing_opt_in, marketing_opt_in_at | boolean, timestamptz | N, Y | false | 광고성 정보 수신(정보통신망법 제50조) |
| region_id, last_seen_at, blocked_reason, blocked_at, withdrawn_at | | Y | - | |

`news.membership_tiers` (조각:723-738): `code`, `name`, `description`, `price_krw`(1,000~10,000,000), `billing_interval`(month, year), `benefits` jsonb, `is_active`. 가격·주기·코드는 만든 뒤 바꾸지 않는다(새 등급, 22023).

`news.memberships` (조각:740-764): `reader_id`·`tier_id`(복합 FK), `status`, `started_at`, `current_period_start/end`, `cancel_at_period_end`, `canceled_at`, `ended_at`, `provider`('toss'), `billing_credential_id`(→ `core.encrypted_credentials`, 신문사 조직 소유만, 23503), `external_ref`, `last_event_id`(웹훅 멱등), `platform_fee_bps`(활성화 시점 플랜 `news_reader_fee_bps` 스냅샷). 독자당 진행 중(pending, active, past_due) 1건(부분 유니크).

`news.donations` (조각:795-817): `reader_id`(선택), `donor_display_name`, `is_anonymous`, `message`, `amount_krw`(불변), `kind`(once, recurring), `status`, `order_id`(유일, Toss orderId 형식, 멱등 키), `payment_key`(유일), `paid_at`, `canceled_at`, `refunded_amount_krw`(≤ 금액), `platform_fee_bps`, `platform_fee_krw`.

`news.paywall_rules` (조각:845-855): 조직 1:1. `mode`(off, meter, premium_only, meter_and_premium), `free_articles_per_month`(0~100), `exempt_types`(유형 배열), `cta_text`.

### 2.4 M3: 광고·업소·공고

| 테이블 | 조각 | 주요 컬럼 | 제약 |
|---|---|---|---|
| `ad_slots` | 865-880 | code, name, placement(home, section, article, mobile, all), width, height, is_active | 폭·높이 필수(레이아웃 공간 예약, CLS) |
| `advertisers` | 884-902 | name, kind(local_business, agency, institution, house, other), is_government, business_no, contact_name/email/phone, note, status | 정부·지자체는 직판 금액 > 0 캠페인 불가(NW013) |
| `ad_campaigns` | 906-924 | advertiser_id(복합 FK), pricing(flat, cpm, cpc, house), price_krw, starts_at, ends_at, priority(1~10), status | ends_at > starts_at |
| `ad_creatives` | 954-983 | campaign_id, slot_id(복합 FK), kind(image, text, external), media_path(`<org>/news/ads/`), external_network(gam, adsense) + external_unit_id, headline, click_url(https만), alt_text, label, status, reviewed_by/at | label 은 '광고', 'AD', '협찬', '후원'만. 종류별 필수 필드 CHECK. 임의 HTML 컬럼 없음 |
| `ad_daily_stats` | 1011-1021 | creative_id, day(KST date), impressions, clicks | `(creative_id, day)` 유일, 증분은 service 만 |
| `local_listings` | 1028-1058 | reader_id, applicant_user_id, business_name, category, region_id, address, phone, url, description, photo_path, contact_email, status, starts_at, ends_at, paid_at, payment_order_id, reviewed_by/at, review_note | active 면 기간 필수 |
| `public_notices` | 1087-1109 | issuer_name, notice_no, title, body, region_id, attachment_path(`<org>/news/notices/`), government_ad_ref(언론진흥재단 청약 참조), posted_from/until, status, published_at, archived_at | 결제 컬럼 없음(정부광고법: 재단 대행) |

### 2.5 M4: 뉴스레터·푸시

`news.newsletter_lists` (조각:1141-1157): `slug`, `name`, `description`, `kind`(morning_brief, breaking, weekly, custom), `is_public`, `contains_ads`(광고 포함 목록은 광고 수신 동의 필수), `consent_version`, `status`.

`news.newsletter_subscriptions` (조각:1163-1197) 목적: 이중 동의 구독(NW-F-037).

| 컬럼 | 타입 | NULL | 기본 | 설명 |
|---|---|---|---|---|
| list_id, reader_id | uuid | N, Y | - | 복합 FK(독자는 선택) |
| email, email_hash | text | Y, N | - | 소문자 정규화. 해시 sha256, `(list_id, email_hash)` 유일 |
| status | text | N | 'pending' | pending, confirmed, unsubscribed, bounced |
| confirm_token_hash, confirm_expires_at | text, timestamptz | Y | - | 확인·재확인 토큰의 sha256(원문 미저장). pending 이면 필수 CHECK |
| unsubscribe_token_hash | text | N | - | 해지 토큰 sha256(유일) |
| consent_version, consent_at, ad_consent, night_consent | | N | now(), false, false | 수신 동의, 광고성 정보 동의, 야간(21~08시) 동의(정보통신망법 제50조) |
| confirmed_at, reconfirmed_at | timestamptz | Y | - | 전이 트리거·재확인 RPC |
| reconfirm_due_at | timestamptz | Y | - | 트리거 계산 = (재확인 또는 확인 시각) + 2년(수신동의 2년 확인). 직접 지정 22023 |
| confirm_sent_count, unsubscribed_at, unsubscribe_reason, source_path | | | | 확인 메일 재발송 상한 5 |

토큰 해시 두 컬럼은 authenticated 컬럼 GRANT 에서도 빠진다(조각:2112).

`news.newsletter_issues` (조각:1239-1264): `list_id`, `subject`, `preheader`, `body` jsonb, `article_ids`, `contains_ad`, `status`, `scheduled_at`, `sent_at`, `recipients_count`, `delivered_count`, `open_count`, `click_count`. CHECK `newsletter_issues_ad_subject_check`: 광고 포함이면 제목이 '(광고)'로 시작. 발송 시작 후 제목·본문 수정 22023.

`news.push_subscriptions` (조각:1298-1316): `endpoint`(https), `endpoint_hash`(조직 안 유일), `p256dh`, `auth_secret`, `topics`(breaking, morning, local), `status`, `failure_count`, `last_sent_at`. 정책 없음(service 전용).

### 2.6 M5: 커뮤니티

| 테이블 | 조각 | 주요 컬럼 | 제약 |
|---|---|---|---|
| `comments` | 1326-1352 | article_id, reader_id, parent_id(같은 기사, `(parent_id, article_id)` 복합 FK), body(1~1000), status, status_reason, temp_blocked_until, report_count, moderation_label(ok, review, toxic: AI 보조), moderated_by/at, deleted_at | org·article·reader·body 불변(본문 수정 불가, 삭제 후 재작성) |
| `comment_reports` | 1382-1400 | comment_id, reporter_reader_id, reason(defamation, privacy, obscene, hate, spam, other), detail, is_rights_claim, status(open, actioned, dismissed), handled_by/at | `(comment_id, reporter_reader_id)` 유일 |
| `tips` | 1407-1432 | kind(tip, contribution), reader_id(선택), title, body(10~20000, 불변), contact_name/email/phone, wants_anonymity, attachment_paths(최대 5, `<org>/news/tips/`), consent_version, consent_at, status, assigned_to, staff_note, retention_until(기본 1년, 제안) | 배정 상태면 assigned_to 필수 |
| `life_events` | 1462-1485 | kind(obituary 부고, personnel 인사, people 동정, wedding 화촉), title, body, event_at, applicant_reader_id, applicant_name, applicant_phone, consent_version, is_paid, paid_at, status, published_at, reviewed_by/at, review_note | |

### 2.7 M6·M7·M8·local-life

| 테이블 | 조각 | 주요 컬럼 | 제약 |
|---|---|---|---|
| `syndication_settings` | 1512-1527 | 조직 1:1. rss_enabled, news_sitemap_enabled, google_news, naver_partnership·daum_partnership(none, search, content), ai_crawler_policy(allow, block_training 기본, block_all), llms_txt_enabled, robots_extra(2000자, `<>` 금지), sns_autoshare jsonb(P2) | |
| `correction_requests` | 1540-1578 | article_id(선택, 복합 FK) 또는 article_url, kind(correction 정정, rebuttal 반론, follow_up 추후보도), requester_name, requester_email/phone(하나 이상), requester_reader_id, claim_text(10~10000, 불변), requested_text, attachment_paths(`<org>/news/corrections/`), channel(web, email, mail, phone, arbitration), received_at(불변), notify_due_at(불변), status, decided_at/by, decision_note, notified_at, publish_due_at(정해지면 불변), published_at, published_revision_id | 트리거(조각:1580-1626): notify_due_at = received_at + 3일, 수용 시 publish_due_at = decided_at + 7일, 결정 시 notified_at 기록 |
| `election_periods` | 1631-1645 | name, election_day, poll_blackout_from/until(여론조사 공표 금지 기간), comment_policy(normal, disabled), source(platform, newsroom), status(active, canceled) | until > from. 운영자 행(source=platform)은 편집국이 고치지 못함 |
| `article_view_hourly` | 1652-1661 | (article_id, bucket_start) PK, views | bucket_start 는 UTC 정시(epoch % 3600 = 0 CHECK) |
| `events` | 1667-1691 | title, description, venue, address, region_id, starts_at, ends_at, is_all_day, url(https), image_path(`<org>/news/events/`), organizer, price_text, status, published_at | |

뷰 `news.correction_sla`(조각:2191-2199, `security_invoker = true`): `notify_overdue`(접수·검토 중이고 통지 기한 경과), `publish_overdue`(수용 후 게재 기한 경과). correction_requests 의 RLS 를 그대로 통과한다.

## 3. 상태 전이

모든 전이는 BEFORE UPDATE 트리거가 강제하고(허용 쌍 외 22023, service_role 직접 쓰기에도 적용, DBC 10장), 역할·요건은 RPC 가 검사한다. 부수 효과가 감사·기한·게시 요건이라 "트리거 + RPC" 둘 다 쓴다.

| 테이블.컬럼 | 현재 | 허용 전이 | 누가(RPC) | 부수 효과 |
|---|---|---|---|---|
| articles.status | draft | submitted, archived | 작성자·DESK `submit_article` / `archive_article`(기자·기고자는 자기 초안만) | submitted_at, 이력 |
| | submitted | approved, draft(반려) | DESK `review_article`. 승인은 사람(auth.uid)만, 서버·AI 는 NW006. 반려는 사유 필수 | approved_by, review_note, 감사 `article.approve/reject` |
| | approved | scheduled, published, draft | DESK `schedule_article`·`publish_article` | 게시 요건 검사(`assert_publishable`, 조각:3029-3055): 신문사 active(NW002), 매체정보 완성(NW003), 사람 승인(NW006), 전재 계약 유효(NW005), 여론조사 공표 금지 기간(NW007) |
| | scheduled | published, approved(예약 취소) | 서버 `run_scheduled_publishing`(매분) → `publish_article` | published_at = 예약 시각, 실패 시 approved 로 되돌리고 사유 기록 |
| | published | unpublished, archived | DESK `unpublish_article`(사유 필수)·`archive_article` | 사진 published_at, 감사, 캐시 태그 무효화(앱) |
| | unpublished | published(재게시), draft, archived | DESK | first_published_at 불변 |
| | archived | (없음) | - | - |
| articles 불변 컬럼 | - | org_id, origin, created_by, created_at, first_published_at(정해진 뒤) | - | 22023 |
| home_layouts.status | draft → scheduled/published/archived, scheduled → draft/published, published → archived | DESK `publish_home_layout` | 게시 시 이전 게시본 archived, version + 1, 감사 |
| print_editions.status | draft → published/archived, published → archived | CHIEF `save_print_edition`(RPC 가 검사) | published_at |
| staff.status | invited → active/removed, active → removed, removed → invited | `invite_staff`(CHIEF), `accept_staff_invite`(본인), `remove_staff` | 코어 `invite_member`·`accept_invite`·`remove_member`·`change_member_role` 동기화, 감사 |
| newspapers.status | active ↔ suspended, → closed | 서버 `set_newspaper_status` | 감사. closed 는 종결 |
| newspaper_applications.status | pending → approved/rejected/withdrawn | 서버 `approve_newspaper`·`reject_newspaper`, 신청자 `withdraw_newspaper_request` | 승인: 조직·owner·구독(trialing)·엔타이틀먼트(30일)·월 크레딧·신문사·발행인·기본 설정, 감사 |
| readers.status | active → blocked/withdrawn, blocked → active/withdrawn, withdrawn → active | 본인 `ensure_reader`·`withdraw_reader`, CHIEF `set_reader_status` | 탈퇴 시 email null, 마케팅 동의 해제, 구독 해지. 멤버십이 남으면 탈퇴 NW004 |
| memberships.status | pending → active/canceled/expired, active → past_due/canceled/expired, past_due → active/canceled/expired, canceled → active/expired | 서버 `record_membership` | started_at, canceled_at, ended_at, 수수료 스냅샷, 감사 |
| donations.status | pending → paid/failed/canceled, paid → canceled/refunded | 서버 `record_donation` | 수수료 계산. 금액·주문번호 불변 |
| ad_campaigns.status | draft → active/canceled, active → paused/ended, paused → active/ended | ADS `save_ad_campaign` | 감사 |
| ad_creatives.status | pending_review → approved/rejected/archived, approved → archived/pending_review, rejected → pending_review/archived | ADS 저장(내용 변경 시 자동 pending_review), CHIEF `review_ad_creative` | 감사 |
| local_listings.status | pending → approved/rejected/canceled, approved → active/canceled, active → expired/canceled | 독자 `submit_listing`, ADS `review_listing`, 서버 `activate_listing`(결제 후) | 기간·결제 기록 |
| public_notices.status | draft → published/archived, published → archived | ADS+desk `save_public_notice` | published_at, archived_at |
| newsletter_subscriptions.status | pending → confirmed/unsubscribed, confirmed → unsubscribed/bounced, unsubscribed/bounced → pending | 서버 `subscribe_newsletter`, 토큰 `confirm_newsletter`·`unsubscribe_newsletter` | confirmed_at, reconfirm_due_at 재계산, 확인 토큰 폐기 |
| newsletter_issues.status | draft → scheduled/canceled, scheduled → draft/sending/canceled, sending → sent/failed | DESK 저장(draft, scheduled, canceled만), 서버 `record_newsletter_issue_status` | sent_at, 발송 후 내용 잠금 |
| comments.status | visible → hidden/temp_blocked/deleted, hidden → visible/deleted, temp_blocked → visible/hidden/deleted | 독자 `report_comment`(권리침해 주장 → temp_blocked 30일, 신고 5건 → hidden), 작성자 `delete_my_comment`, DESK `moderate_comment` | temp_blocked_until, 신고 처리(actioned/dismissed), 감사 |
| tips.status | new → reviewing/assigned/dismissed/spam, reviewing → assigned/used/dismissed/spam, assigned → reviewing/used/dismissed, spam → new | DESK `set_tip_status`, 배정 기자는 reviewing/used | 감사(개인정보 제외) |
| life_events.status | pending → approved/rejected/withdrawn, approved → archived | DESK `review_life_event` | published_at |
| correction_requests.status | received → reviewing/accepted/rejected/withdrawn, reviewing → accepted/rejected/withdrawn, accepted → published/withdrawn | CHIEF `respond_correction_request`(거부 사유 필수), DESK `record_article_correction`(청구 연결 시 published) | decided_at·notified_at·publish_due_at(= +7일), 기한 불변, 감사 |
| events.status | draft → published/archived, published → canceled/archived, canceled → archived | EDITORIAL `save_event` | published_at |

## 4. RLS 정책

### 4.1 역할 묶음과 헬퍼

| 묶음 | 역할 | 쓰임 |
|---|---|---|
| ALL | publisher, editor, desk, reporter, contributor, ad_manager | 매체정보·분류·미디어·설정 읽기 |
| EDITORIAL | publisher, editor, desk, reporter | 기사 전체, 홈 편집, 지면, 조회 집계, 행사 |
| DESK | publisher, editor, desk | 승인·게시, 댓글 모더레이션, 제보, 정정 청구 조회, 홈 게시 |
| CHIEF | publisher, editor | 매체정보, 구성원, 독자 개인정보, 멤버십·후원, 광고 소재 승인, 정정 청구 결정, 계약·배포 설정 |
| ADS | publisher, editor, ad_manager | 광고주·캠페인·소재·집계, 업소, 공고(+ desk) |

헬퍼(모두 SECURITY DEFINER, STABLE, `search_path=''`, 조각:1767-1889): `staff_role(org)`, `has_staff_role(org, roles)`(exists, NULL 없음, SB 2장), `is_newsroom(org, roles)` = has_staff_role + `core.has_entitlement(org, 'news')`, `is_public_newspaper(org)`, `is_profile_complete(org)`, `article_is_live(org, status, published_at, embargo_until, type, wire_contract_id)`, `is_article_live(article_id)`, `can_view_article(article_id)`, `current_reader_id(org)`. 정책 안에서 `org_members`·`staff`를 직접 조회하지 않는다(42P17 방지, DBC 7장). anon 정책은 `core.has_entitlement`를 직접 부르지 않고(anon EXECUTE 없음, SB 3장) `is_public_newspaper` 안에서 엔타이틀먼트를 본다.

### 4.2 테이블별 정책과 GRANT

모든 테이블: RLS ON, `revoke all ... from public, anon, authenticated` 후 SELECT 만 다시 준다(조각:1745-1746). INSERT/UPDATE/DELETE 정책과 GRANT 는 어느 테이블에도 없으므로 DBC 8장 "쓰기 정책을 줄 때의 조건"은 해당하지 않는다. 사용자 세션의 직접 쓰기는 GRANT 부재(42501)가 1차, `guard_privileged_write` 트리거가 2차로 막는다.

| 테이블 | SELECT (authenticated) | SELECT (anon) | anon 컬럼 GRANT |
|---|---|---|---|
| newspaper_applications | 신청자 본인 or 플랫폼 운영자 | 없음 | - |
| newspapers | ALL or 운영자 | `is_public_newspaper(org_id)` | 제호·법정 푸터 항목·댓글 스위치(금칙어 제외) |
| staff | ALL(같은 조직) or 본인 | active + 공개 프로필 + 공개 신문 | id, org_id, role, byline_name, title_label, bio, photo_path, email_public |
| sections, regions, tags | `is_newsroom(ALL)` | is_active + 공개 신문 | 전체 |
| wire_contracts | EDITORIAL | 없음 | - |
| media_assets | ALL | active + published_at not null + 공개 신문 | 표시 컬럼(경로, 크기, alt, caption, credit, AI 표시) |
| articles | 엔타이틀먼트 + (EDITORIAL 전부 or contributor 자기 것 or ad_manager sponsored) | `article_is_live(...)` | 공개 컬럼 27개. body, body_text, search_tsv, review_note, 행위자 id 제외 |
| article_revisions | `can_view_article` | 없음(공개 메모는 `read_article`) | - |
| article_regions, article_tags | `can_view_article` | `is_article_live` | 전체 |
| home_layouts | EDITORIAL | published + 공개 신문 | template, blocks, version, published_at |
| print_editions | EDITORIAL | published + 공개 신문 | 메타만(PDF 경로 제외) |
| live_updates | `can_view_article` | visible + `is_article_live` | 본문·시각 |
| readers | 본인 or CHIEF | 없음 | - |
| membership_tiers | ALL | 활성 + 공개 신문 | 가격표 |
| memberships, donations | 본인(독자 행 경유) or CHIEF | 없음 | - |
| paywall_rules | ALL | 공개 신문 | 규칙 |
| ad_slots | ADS + desk | 활성 + 공개 신문 | 코드·위치·크기 |
| advertisers, ad_campaigns, ad_creatives, ad_daily_stats | ADS | 없음(노출은 `serve_ads`) | - |
| local_listings | 신청자 본인 or ADS | active + 기간 내 + 공개 신문 | 업소 공개 정보(연락 메일·결제·검토 메모 제외) |
| public_notices | ADS + desk | published + 공개 신문 | 공고 공개 정보 |
| newsletter_lists | ALL | active + 공개 + 공개 신문 | 목록 정보 |
| newsletter_subscriptions | 본인(독자 행) or CHIEF. 토큰 해시 컬럼은 GRANT 없음 | 없음 | - |
| newsletter_issues | DESK | 없음 | - |
| push_subscriptions | 정책 없음(service 전용) | 없음 | - |
| comments | 작성자 본인 or DESK | 없음(공개 목록은 `list_comments`) | - |
| comment_reports | 신고자 본인 or DESK | 없음 | - |
| tips | DESK or (배정된 reporter) | 없음 | - |
| life_events | 신청자 본인 or DESK | approved + 공개 신문 | 게재 정보(신청자 연락처 제외) |
| syndication_settings | ALL | 공개 신문 | robots·RSS 렌더링 항목 |
| correction_requests (+ 뷰 correction_sla) | 청구 독자 본인 or DESK | 없음 | - |
| election_periods | ALL | 없음 | - |
| article_view_hourly | EDITORIAL | 없음(`most_read`) | - |
| events | EDITORIAL | published·canceled + 공개 신문 | 행사 공개 정보 |

로그인한 독자(authenticated)에게는 공개 콘텐츠 정책을 주지 않는다. 독자 사이트는 공개 콘텐츠를 항상 anon 키(쿠키 없는 서버 클라이언트, ISR 캐시 공유)로 읽고, 독자 본인 데이터(독자 행, 내 댓글, 멤버십, 구독)만 사용자 세션으로 읽는다(02장 렌더링). 이 분리 덕분에 authenticated 에 넓은 컬럼 GRANT 를 주어도 비편집국 사용자는 기사 행 자체를 0행으로 본다(스모크 6절).

Storage(조각:2205-2219): 코어 `org-files` 정책은 조직 멤버 누구에게나 조직 폴더를 연다(`docs/products/_supabase-modular/migrations/0005_core_jobs_storage.sql:330-342`). 제보·정정 청구 첨부(`<org>/news/tips|corrections/`)는 제보자 보호를 위해 RESTRICTIVE 정책 4개(select·insert·update·delete, FOR ALL 아님)를 더해 DESK 만 읽고 사용자 세션은 쓰지 못한다(서버 업로드). 코어 정책은 바꾸지 않는다.

### 4.3 함수 EXECUTE

조각 12절(조각:5009-5140)이 이 스키마 함수 112개를 이름 목록으로 PUBLIC·anon·authenticated 에서 회수하고 아래만 다시 준다(목록 밖 news 함수가 생기면 모듈러 적용이 실패하도록 검사 포함). 이름 목록을 쓰는 이유: 모놀리스 변환본은 public 스키마라 `revoke ... on all functions in schema`가 코어 함수 권한까지 지운다.

| 대상 | 함수 |
|---|---|
| anon + authenticated | is_public_newspaper, is_profile_complete, article_is_live, is_article_live, read_article, serve_ads, list_comments, most_read, search_articles, confirm_newsletter, unsubscribe_newsletter |
| authenticated(함수 안에서 `is_service_caller` + 역할 + 엔타이틀먼트) | 편집국 RPC 전부, 독자 RPC(ensure_reader, withdraw_reader, post_comment, delete_my_comment, report_comment, submit_listing, submit_life_event, request_newspaper, withdraw_newspaper_request), 정책 헬퍼(staff_role, has_staff_role, is_newsroom, can_view_article, current_reader_id), CHECK 헬퍼(is_org_path, are_org_paths) |
| service_role 전용 | approve_newspaper, reject_newspaper, set_newspaper_status, record_membership, record_donation, record_ad_stats, activate_listing, subscribe_newsletter, issue_newsletter_reconfirm, record_newsletter_issue_status, register/revoke_push_subscription, submit_tip, increment_article_views, run_scheduled_publishing, 내부 헬퍼(assert_staff, plan_feature, add_revision, assert_keys, assert_publishable, token_hash, election_blackout_active, wire_contract_valid) |
| 아무에게도 안 줌 | 트리거 함수 19개 |

service 전용 함수도 본문 첫 줄에서 `core.is_service_caller()`를 다시 확인한다(EXECUTE 1차, 함수 2차, guard 3차, SB 1장). 편집국 RPC 의 호출자 판정은 내부 헬퍼 `news.assert_staff`(조각:2230-2252) 하나로 모았다: 서버면 'service', 편집국이면 역할, 아니면 42501, 엔타이틀먼트가 없으면 42501. `is_privileged_session()`은 쓰지 않는다.

### 4.4 사용자 정의 SQLSTATE

코어 접두사(CR, PM, SB, OA, JB, AU, AI, TM)와 겹치지 않는 `NW`(DBC 1장 규칙). 04장 7절 HTTP 매핑의 정본.

| 코드 | 뜻 | 대표 RPC | 화면 문구(제안) |
|---|---|---|---|
| NW001 | 개설 신청 중복·슬러그 사용 중·예약어 | request_newspaper, approve_newspaper | "이미 쓰이는 주소입니다. 다른 영문 주소를 입력해 주세요." |
| NW002 | 신문사 비공개·비활성(독자 기능 불가) | ensure_reader, subscribe_newsletter, submit_tip, 게시 | "지금은 이용할 수 없는 신문사입니다." |
| NW003 | 필요적 게재사항 미완성 | publish_article, schedule_article | "매체정보(청소년보호책임자 등)를 모두 입력해야 게시할 수 있습니다." |
| NW004 | 현재 상태에서 허용되지 않는 작업 | submit/review/publish/archive_article, invite_staff, respond_correction_request | "이미 처리된 항목입니다. 새로고침해 주세요." |
| NW005 | 전재 계약 없음·만료 | publish_article | "전재 계약이 만료되어 게시할 수 없습니다." |
| NW006 | 사람 승인 없음(서버·AI 단독 승인 금지) | review_article, publish_article | "데스크 승인이 필요합니다." |
| NW007 | 여론조사 공표 금지 기간 | publish_article, schedule_article | "선거 여론조사 공표 금지 기간입니다." |
| NW008 | 독자 미가입·차단·탈퇴 | post_comment, report_comment, submit_listing, submit_life_event | "독자 가입 후 이용할 수 있습니다." |
| NW009 | 댓글 꺼짐(신문사·기사·선거 정책) | post_comment | "이 기사는 댓글을 받지 않습니다." |
| NW010 | 금칙어 포함 | post_comment | "사용할 수 없는 표현이 있습니다." |
| NW011 | 레이트 리밋 | 독자·공개 쓰기 RPC | "잠시 후 다시 시도해 주세요." |
| NW012 | 토큰 무효·만료 | confirm_newsletter, unsubscribe_newsletter | "링크가 만료되었습니다. 다시 신청해 주세요." |
| NW013 | 정부광고 직판 금지 | save_ad_campaign | "정부·지자체 광고는 언론진흥재단을 통해 집행됩니다." |
| NW014 | 플랜 한도 초과 | invite_staff(news_staff_max), save_print_edition(news_print_pdf) | "현재 요금제 한도를 넘었습니다." |
| NW015 | 입력 오류(허용 밖 필드, 사유 누락, 범위 밖 값) | 대부분 | 필드별 안내 |

그 밖: 42501 권한, P0002 없음(존재 여부를 숨기려고 남의 행도 P0002), 22023 상태 전이·불변 컬럼, 23514 CHECK, 23503 교차 조직 참조, 23505 중복.

## 5. 인덱스와 성능

| 인덱스 | 조회 패턴 |
|---|---|
| `articles_public_idx (org_id, published_at desc) where status='published'` | 독자 홈·최신 기사, 사이트맵(최근 2일), RSS |
| `articles_section_public_idx (org_id, section_id, published_at desc) where published` | 섹션 페이지 |
| `articles_org_status_idx (org_id, status, updated_at desc)` | 편집국 기사함(상태 필터) |
| `articles_author_idx (org_id, created_by, status)` | 내 기사, 기고자 범위 |
| `articles_scheduled_idx (scheduled_for) where scheduled` | 매분 예약 게시 |
| `articles_first_published_idx (org_id, first_published_at)` | 주간 자체기사 지표 |
| `articles_search_idx` GIN(search_tsv), `articles_title_trgm_idx` GIN(title gin_trgm_ops) | 검색(`simple` 사전 + 제목 부분 일치 ILIKE) |
| `articles_legacy_uniq (org_id, legacy_id)` | 이관 중복 방지, 리디렉션 맵 |
| `article_view_hourly` PK (article_id, bucket_start), `(org_id, bucket_start desc)` | 많이 본 뉴스(1시간·24시간 버킷 합산), 대시보드 |
| `comments_article_idx (article_id, created_at desc) where visible` | 공개 댓글 목록 |
| `comments_org_status_idx`, `comment_reports_org_open_idx` | 모더레이션 큐 |
| `correction_requests_notify_due_idx`, `_publish_due_idx` | 기한 알림 워커 |
| `newsletter_subscriptions_*_token_uniq`, `_reconfirm_idx (reconfirm_due_at) where confirmed`, `_list_status_idx` | 토큰 조회, 2년 재확인 대상, 발송 대상 |
| `newsletter_issues_due_idx`, `home_layouts_scheduled_idx` | 예약 발송·홈 예약 게시 |
| `ad_campaigns_org_status_idx`, `ad_creatives_campaign_idx`, `ad_daily_stats_org_day_idx` | 광고 노출·집계 |
| `media_assets_org_created_idx`, `tips_org_status_idx`, `tips_assigned_idx`, `readers_org_created_idx`, `readers_nickname_uniq` | 목록, 닉네임 중복 |

예상 규모(제안): 인터넷 지역신문 1곳당 하루 기사 10~30건(평균 기자 4명, research/MARKET_LEGAL.md "사업체당 평균 기자 인터넷·주간 4명"), 연 1만 건 내외. 조회 버킷은 기사 수 × 시간이라 신문사 100곳·기사당 48시간 활동이면 하루 수십만 행이다. 워커가 90일 지난 버킷을 일 단위로 롤업·삭제한다(제안, 13절 스케줄). 속보 트래픽은 조회수 증분 경로(`/api/r/view` → service RPC)가 아니라 ISR 캐시가 받고, 증분은 서버가 몇 초 단위로 묶어 `p_count`(최대 1,000)로 보낸다. 검색은 형태소 분석 없이 `simple` + 제목 trigram 이라 조사 붙은 본문 단어("축제가")는 놓친다(D-7, pg_bigm 지원 미확인). 규모가 커지면 외부 검색(Meilisearch/Typesense, P2).

RLS 비용: 공개 정책의 `article_is_live`·`is_public_newspaper`는 STABLE DEFINER 라 행마다 평가되지만 `org_id` 인덱스로 범위가 한 신문사로 좁고, 독자 사이트는 ISR 로 DB 호출 자체가 적다.

## 6. 코어 참조

| core 객체 | 용도 | ALTER |
|---|---|---|
| `core.organizations`, `core.org_members` | 테넌트 FK, 편집국 멤버십(`approve_newspaper`가 조직·owner 를 만들고, 구성원은 코어 멤버 함수로) | 안 함(행 추가만) |
| `core.invite_member`, `accept_invite`, `change_member_role`, `remove_member` | 구성원 RPC 가 그대로 호출(코어 역할 검사·감사 재사용) | 안 함 |
| `core.is_org_member`, `has_entitlement`, `is_service_caller`, `is_platform_admin`, `is_privileged_session`(guard 내부) | 헬퍼·정책·RPC | 안 함 |
| `core.apps`, `core.plans`, `core.subscriptions`, `core.app_entitlements` | 앱 등록(invite), 플랜 5종, 승인 시 구독(trialing)·엔타이틀먼트(trial 30일) 생성, features 해석(`news.plan_feature`) | 안 함 |
| `core.grant_credits`, `core.credit_ledger` | 승인 시 첫 달 AI 크레딧(멱등 키 `monthly:<sub>:<date>`), 이후 월 지급은 코어 잡 | 안 함 |
| `core.encrypted_credentials` | 신문사 자기 Toss 가맹 키(provider `toss_merchant`, app `news`, 결정 D-4), 독자 정기결제 빌링키 참조(`memberships.billing_credential_id`, 제안) | 안 함 |
| `core.audit_log` / `core.write_audit` | 편집국·서버 쓰기 감사. 독자 행위는 기록하지 않는다(독자는 조직 멤버가 아니어서 `write_audit`가 42501) | 안 함 |
| `core.rate_limit_hit` | 개설 신청·댓글·신고·업소·경조사·제보·구독·정정 청구 레이트 리밋(키 `news:<용도>:<id>`) | 안 함 |
| `core.storage_org_id`, Storage 버킷 public-assets·org-files | 경로 첫 폴더 = org_id. 제보·정정 첨부는 제품 RESTRICTIVE 정책 추가 | 안 함 |
| `core.profiles` | 독자 가입 시 이메일 복사 | 안 함 |
| `core.jobs`(큐 publish·newsletter·ingest·ai·stats·domain) | 잡 페이로드는 04장. 이 조각은 잡 테이블을 참조하지 않는다 | 안 함 |
| Theming `core.resolve_tenant`, `tenant_themes`, `tenant_domains`, `theming_level` | 테넌트 해석·브랜딩·커스텀 도메인. 조각은 직접 참조하지 않는다(0011 없이도 적용, 9장). 플랜 `theming_level`이 단계 | 안 함 |

`core.*` ALTER 없음, 제품 스키마에 플랜·크레딧·결제·잡·자격증명 테이블을 다시 만들지 않음을 확인했다(DBC 11장).

AI·음성(`AI_ARCHITECTURE.md` 9장 "제품 AI 표는 꼭 필요할 때만"): 제품 AI 테이블은 만들지 않았다.

| 기능 | core 객체 | 제품 쪽 연결 |
|---|---|---|
| 보도자료 → 초안(`news.press_to_draft`) | `ai_runs`, `ai_run_steps`, `ai_usage` | 서버가 `save_article(origin='ai_press_release', type='press_release', ai_assisted, ai_disclosure)`로 초안 생성. 사람 승인 전 게시 불가(NW006). 실행 id 는 `ai_runs.metadata.article_id`(제안) |
| 편집국 어시스턴트(`news.assistant`) | `ai_conversations`, `ai_messages`(본인만), 컬렉션 `ai_collections`(과거 기사·사내 규정, 임베딩 oss-embed), `wiki_pages`(사내 규정 위키) | 게시 기사만 색인(초안·제보·독자 데이터는 색인 금지, 제안) |
| 댓글 모더레이션 보조 | `resolve_ai_route('news.moderation')` 오픈소스 강제 | 결과는 `comments.moderation_label`만. 판정 확정은 사람(`moderate_comment`) |
| 인터뷰 받아쓰기(STT) | `voice_sessions`, `voice_jobs`(`store_audio=false`) | 녹음 원본 미저장, 결과 텍스트는 기사 메모로만 |
| 오디오 기사(TTS) | `voice_jobs` | 화면에 AI 음성 표시 |
| 라우팅 | `ai_routing_settings` 14행(9장 seed) | 조직 국외 이전 동의 전에는 상용 체인이 빠진다(`resolve_ai_route`) |

인증 단계(A Mock → B Google·이메일 → C1 카카오·C2 네이버)는 스키마 변경이 없다. 독자 로그인도 코어 계정 + `ensure_reader` 한 경로다. C2 에서 브리지를 택하면 코어 `staged/0010_core_auth_identity_links.sql`의 `core.auth_identity_links`를 참조만 한다(`AUTH_ROADMAP.md` 10장).

## 7. 리뷰 "높음" 결함의 차단 설계 (보안, 데이터)

해당 리뷰 없음(신규 제품). 그래서 "위험 #n → 차단 설계" 표로 쓴다: 리뷰 "높음" 결함 대신 경쟁·업계·법규에서 나온 상위 위험을 "위험 #n"으로 둔다(마스터 브리프 0장). 보안·데이터 위험은 이 장, 그 밖은 02장 6절. 검증 열은 `supabase/monolith/tests/rls_smoke.sql`의 절 번호다.

| 위험 #n | 출처 | 위험 요약 | 차단 설계 | 검증 / 담당 |
|---|---|---|---|---|
| #1 | 새 위험(멀티테넌트 SaaS) | 신문사 사이 데이터 유출(다른 신문 초안·독자·청구 열람, 다른 신문 섹션·사진 참조) | 모든 정책이 `is_newsroom(org_id, …)`(staff + 코어 멤버 + 엔타이틀먼트), 하위 테이블 `(x_id, org_id)` 복합 FK(23503), 미디어 배열은 RPC 가 같은 조직 확인, 모든 RPC 가 대상 행의 org 로 `assert_staff` | 스모크 2·7절(B 발행인: A 기사·독자·이력·청구·후원 0행, A 기사 게시·저장 42501, A 섹션·사진 참조 23503) / 06장 DB·RLS 작업 |
| #2 | 언론중재·엠바고 관행, NW-F-012 | 독자·방문자가 미게시·엠바고·예약 기사를 본다 | anon 정책 `article_is_live`(게시 + 시각 도래 + 엠바고 해제 + 공개 신문 + 계약 유효), 본문 컬럼 anon GRANT 제외 → `read_article`만, 로그인 독자는 기사 테이블 0행, 검색·많이 본 뉴스·댓글 목록도 같은 판정 | 스모크 5·6·11절(초안·엠바고·예약 0행, `select *`·body 42501, read_article null) |
| #3 | 신문 편집권·데스크 관행, NW-F-012 | 기고자·기자가 데스크 승인 없이 게시 | 상태 컬럼 직접 쓰기 불가(GRANT 없음 + guard), 게시·승인·예약 RPC 는 DESK 만, 기고자는 자기 초안만·유형 contribution 고정, 서버는 예약 기사만 게시, 승인자는 사람(approved_by = auth.uid) | 스모크 4·5절(기고자 승인·게시·예약·직접 UPDATE 42501, 서버 approved 게시 42501) |
| #4 | 신문법 제6조 제3항(기사·광고 구분), research/MARKET_LEGAL.md 규제 표 | 광고·기사형 광고 라벨 우회(빈 라벨, 임의 문구, HTML 광고) | `articles_sponsor_label_check`(허용 라벨 5종, NULL 우회 차단, 일반 기사엔 라벨 금지), `ad_creatives.label` 허용 4종, 임의 HTML 컬럼 없음(이미지·텍스트·외부 광고망 단위 ID만), 노출은 `serve_ads`가 라벨과 함께만, 소재 수정 시 재검토 | 스모크 3·12절(라벨 없음·허용 밖·혼용 23514, 승인 전·수정 후 노출 0) |
| #5 | 신문법 제21조, 시행령 제7조의2(청소년보호책임자 첫 화면 표시), 미게재 과태료 | 법정 게재사항이 빠진 채 독자 사이트 공개 | `profile_completed_at` 트리거(필수 10항목), 미완성이면 `is_public_newspaper` false → 모든 anon 정책·공개 함수 0행, 게시·예약 NW003, 항목을 지우면 즉시 비공개 | 스모크 5절(C 신문: 게시 NW003, 완성 후 공개, 청소년보호책임자 삭제 → 기사·푸터 0행) |
| #6 | 언론중재법 제14·15조(3일 통지, 수용 시 7일 게재, research/MARKET_LEGAL.md), 미확인: 현행 조문 | 정정·반론 청구 기한을 놓치거나 기록을 고쳐 SLA 은폐 | 접수 시각·통지 기한(+3일)·게재 기한(+7일) 트리거 계산·불변(서버도 22023), 이력 append-only, 결정은 CHIEF + 감사, 기한 초과 뷰 `correction_sla`, 정정 기록이 청구를 published 로 연결, 웹 폼 청구는 서버 경유 | 스모크 10절(기한 변경 22023, 기한 초과 1건, 수용 후 +7일, 종류 불일치 NW015, 이력 수정 42501·22023) |
| #7 | 개인정보보호법(신문사 = 처리자, 플랫폼 = 수탁자, 마스터 브리프 1장) | 독자 개인정보가 다른 신문사·내부 비권한자에게 노출 | 독자는 조직 멤버가 아님, 독자 행은 본인 + CHIEF 만, 데스크·광고담당·기자 0행, 멤버십·후원·구독도 본인 + CHIEF, 구독 토큰 해시 컬럼 GRANT 없음, 탈퇴 시 email 삭제 | 스모크 8·13·15절 |
| #8 | 정보통신망법 제44조의2(임시조치), 게시판 개인정보 | 댓글로 독자 신원(이메일·계정 id) 노출, 권리침해 게시물 방치 | anon 은 댓글 테이블 권한 없음, `list_comments`는 닉네임·본문·시각만(탈퇴 독자는 '탈퇴한 독자'), 독자는 자기 댓글만, 권리침해 신고 즉시 임시조치 30일, 신고 5건 숨김(제안), 금칙어 부분 문자열 비교(한글 `\b` 금지, SB 14장) | 스모크 9절 |
| #9 | 신문법 시행령 제2조(주간 자체기사 30%), 네이버 뉴스제휴 보도자료 감점(research/MARKET_LEGAL.md 포털), AI기본법·언론계 AI 준칙 | AI 가 만든 보도자료 기사를 자체기사로 세어 비율을 부풀림, AI 표시 누락 | `origin` 불변, `articles_ai_origin_check`(AI 초안은 press_release + ai_assisted), 고지 문구 필수, 서버 AI 승인 금지(NW006), `compliance_weekly_stats`는 origin ai_press_release 를 자체기사에서 제외·별도 집계 | 스모크 3·4·17절(original 지정 23514, 유형 변경 23514, origin 변경 22023, 지표 원본 4 / 분모 6 / AI 1) |
| #10 | 포털 제휴·광고 단가가 조회 지표에 의존(새 위험) | 조회수 부풀리기(브라우저 직접 증분, 비공개 기사 조회, 대량·소급 증분) | 증분 RPC 는 service 전용(anon·독자·기자 42501), 공개 기사만, 1회 1~1,000, 48시간 안의 시각만, 집계 테이블 쓰기 GRANT 없음, 봇 필터·레이트 리밋은 `/api/r/view`(04장) | 스모크 11절 |
| #11 | 새 위험(유료 콘텐츠) | 프리미엄 본문이 API 로 새어 나감 | 본문 컬럼 anon GRANT 제외, `read_article`이 유효 멤버(active, past_due, 기간 남은 canceled) 또는 편집국에게만 본문 반환. 미터형(월 N건)은 서버 쿠키 카운트라 DB 강제 아님(한계로 명시) | 스모크 15절(방문자·비멤버 잠김, 멤버 열림) |
| #12 | 정보통신망법 제50조(사전 동의, 야간 별도 동의, '(광고)' 표기, 2년 재확인) | 동의 없는 발송, 토큰 탈취로 남의 구독 조작, 재확인 누락 | 이중 동의(확인 전 발송 대상 아님), 토큰 원문 미저장(sha256), 확인 토큰 1회용·만료, 광고 포함 목록은 광고 동의 필수, '(광고)' 제목 CHECK, 재확인 기한 트리거 계산, 구독 신청은 서버 경유(계정 열거 방지) | 스모크 13절 |
| #13 | 제보자 보호(취재 윤리) | 기고자·광고담당이 제보 원문·첨부·연락처를 열람 | 제보는 DESK + 배정 기자만, 첨부 폴더 Storage RESTRICTIVE 정책, 제보 접수는 서버 경유, 보존 기한(1년, 제안) | 스모크 14절 |
| #14 | 정부광고법(재단 대행), 공직선거법 제108조 | 정부광고 직판·여론조사 금지 기간 공표 | 정부 광고주 직판 금액 NW013, 공표 금지 기간 게시·예약 NW007, 선거 기간 댓글 정책 NW009 | 스모크 5·9·12절 |

## 8. 모놀리스와 모듈러의 차이

`DB_CONVENTIONS.md` 12장 기준. 1차 운영은 모놀리스(단독 Supabase 프로젝트)다(D-2 권고).

| 항목 | 모듈러(`news` + `core`) | 모놀리스(`public` 하나) |
|---|---|---|
| 코어 | `migrations/0000~0009` + Theming `0011`(제안 staged) | `0001_core_lite.sql`: `MONOLITH_CORE_LITE.sql` 복사, [선택] 절 중 SECTION 6-A(oauth_states, 외부 OAuth 연동 없음)·9(affiliate, video·blog 전용)만 제거(제거 사유 주석, `0001_core_lite.sql:1840`, `:2322`). 유지: 3(Toss, 신문사 플랫폼 구독), 4(크레딧, AI 월 크레딧), 6-B(신문사 Toss 가맹 키), 6-C(레이트 리밋), 7(잡), 8(Storage), 11(AI), 12(음성) |
| 화이트라벨 | Theming 0011 을 코어 확장으로 적용 | `0002_tenant_theming.sql` = 0011 의 `core.`→`public.` 변환본(`Multi-tenant_Theming/04_DATA_MODEL.md` 9장. 그 장의 예시 번호 0003 대신 브리프의 0002 를 썼다) |
| 제품 SQL | `2500_news.sql`(정본) | `0003_local_news_domain.sql` = 정본 변환(변환 스크립트 `docs/products/local-news/supabase/tools/to_monolith.py`: create schema·기본 권한·apps 등록 제거, `core.`·`news.`→`public.`, `@@MODULAR_ONLY` 구간 제거, 함수 권한 루프의 스키마 이름만 public). 직접 수정 금지 |
| 함수 권한 회수 | 이름 목록 + 목록 누락 검사 | 같은 이름 목록(누락 검사는 public 에 코어 함수가 있어 제외). 코어 함수 권한 보존(스모크: 발행인 `session_context` 정상) |
| 플랜·AI 라우팅 | 조각 14절(`on conflict do nothing`, 라우팅은 upsert). 모듈러 `seed.sql`에는 news 행이 아직 없다(코어 요청, 06장 6절) | `seed.sql`(upsert) |
| 앱 행 | `('news', …, schema_name 'news', 'invite')` | `('news', …, schema_name 'public', 'invite')`. invite 라 단일 앱 자동 부트스트랩도 일어나지 않는다 |
| 이름 충돌 | - | 함수 112·테이블 40·인덱스 이름이 코어 라이트·Theming 과 겹치지 않음을 확인(겹치면 `create or replace`가 코어 함수를 덮어쓰거나 `if not exists`가 인덱스를 건너뛴다) |
| PostgREST | `[api].schemas`에 `news` 추가, `supabase.schema('news')` | 기본 노출 |
| 앱 설정 | `SUPABASE_DB_SCHEMA=core`, `NEWS_DB_SCHEMA=news` | 둘 다 `public` |
| 전용 DB(판매 모델 B, 엔터프라이즈) | - | 같은 모놀리스 파일 + 신문사 1곳. 컨트롤 플레인 `tenant_deployments`에 기록(Theming 9장) |

## 9. 마이그레이션 파일

| 구분 | 파일 | 줄 | 내용 |
|---|---|---|---|
| 모듈러 | `docs/products/_supabase-modular/migrations/2500_news.sql` | 5,222 | 번호 2500(범위 2500~2599). 스키마, `core.apps` 등록(invite), pg_trgm, 테이블 40, 상태·불변 트리거 함수 19, 공통 트리거(updated_at·guard·RLS·권한 회수) 일괄, RLS 헬퍼 9, 정책·컬럼 GRANT, 뷰 1, Storage 제한 정책 4, RPC·내부 헬퍼 함수(트리거 포함 112), EXECUTE 정리, 스케줄 주석, 14절 플랜 5·AI 라우팅 14행·체인 검사 |
| 모놀리스 | `supabase/monolith/migrations/0001_core_lite.sql` | 3,282 | 코어 라이트(SECTION 6-A, 9 제거) |
| 모놀리스 | `supabase/monolith/migrations/0002_tenant_theming.sql` | 891 | Theming 0011 변환본 |
| 모놀리스 | `supabase/monolith/migrations/0003_local_news_domain.sql` | 5,142 | 2500 변환본 |
| 모놀리스 seed | `supabase/monolith/seed.sql` | 78 | apps 1행, 플랜 5행, AI 라우팅 14행 + 체인 검사. 크레딧팩 없음 |
| 테스트 | `supabase/monolith/tests/rls_smoke.sql`, `tests/run-smoke.mjs` | 1,093 / 131 | RLS·권한·워크플로 스모크 314항목(18절), PGlite 러너(`--target mono|mod`) |

seed 플랜(모두 제안, 정본 후보 01장 4절, VAT 별도, 무제한 값 없음):

| code | 월 가격 | AI 월 크레딧 | news_staff_max | news_custom_domains | news_newsletter_monthly | news_storage_gb | news_print_pdf | news_regional_editions | news_reader_fee_bps | news_api | news_support_reports | theming_level | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| news_trial | 0 | 300 | 3 | 0 | 5,000 | 10 | N | N | 0 | N | N | 2 | 기본 플랜(is_default). 승인 시 30일 만료 엔타이틀먼트 |
| news_starter | 99,000 | 300 | 3 | 0 | 5,000 | 10 | N | N | 300(3%) | N | N | 1 | |
| news_standard | 199,000 | 1,500 | 10 | 1 | 30,000 | 50 | N | N | 0 | N | N | 2 | |
| news_pro | 390,000 | 4,000 | 30 | 3 | 100,000 | 200 | Y | Y | 0 | Y | Y | 2 | |
| news_enterprise | 계약(0) | 10,000 | 200 | 5 | 500,000 | 1,000 | Y | Y | 0 | Y | Y | 3 | is_active=false(가격표 비노출, 운영자 부여) |

AI 라우팅 기본값(org null, app news, 조각:5187-5203 = seed): `news.draft`·`news.assistant`(llm, auto, anthropic → openai → google → oss-llm), `news.alt_text`(llm, auto, anthropic → google → openai → oss-llm), `news.headline`·`news.summary`·`news.proofread`(llm, auto, oss-llm → anthropic → openai), `news.moderation`(llm, open_source, oss-llm, 강제), `news.knowledge`(embedding, open_source, oss-embed), `news.tts`(tts, auto, elevenlabs → oss-voice), `news.stt`(stt, open_source, oss-voice, 강제), `wiki.query`·`wiki.ingest`·`wiki.lint`(llm, auto, oss-llm → anthropic), `dify.aux`(llm, open_source, oss-llm, 강제).

검증(2026-10-15, PGlite, `docs/products/_tools-sqlcheck`, 실행 위치 `products/_tools-sqlcheck`):

| 명령 | 결과 |
|---|---|
| `node check.mjs --vector mod ../_supabase-modular/migrations/0000~0009(10개, 순서대로) ../_supabase-modular/seed.sql ../../Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql ../_supabase-modular/migrations/2500_news.sql ../_supabase-modular/migrations/2500_news.sql` | 14파일 전부 OK(2500 두 번 적용 = 반복 실행 가능) |
| `node check.mjs --vector modnt ../_supabase-modular/migrations/000*.sql ../_supabase-modular/seed.sql ../_supabase-modular/migrations/2500_news.sql ../_supabase-modular/migrations/2500_news.sql` | OK(Theming 0011 없이도 적용) |
| `node check.mjs --vector full ../_supabase-modular/migrations/000*.sql ../_supabase-modular/seed.sql ../../Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql ../_supabase-modular/migrations/1*.sql ../_supabase-modular/migrations/2*.sql` | 27파일 전부 OK(1000~2300 전 제품 조각 + 2500, 이름 충돌 없음) |
| `node check.mjs --vector mono ../local-news/supabase/monolith/migrations/0001_core_lite.sql ../local-news/supabase/monolith/migrations/0002_tenant_theming.sql ../local-news/supabase/monolith/migrations/0003_local_news_domain.sql ../local-news/supabase/monolith/seed.sql ../local-news/supabase/monolith/migrations/0003_local_news_domain.sql ../local-news/supabase/monolith/seed.sql` | 6파일 전부 OK(0003 + seed 재적용) |
| 두 번 적용 후 상태(모듈러·모놀리스 같음) | `ai_routing_settings`(org null, app news) 14행, 플랜 5행(theming_level 2·1·2·2·3), apps news = invite, RLS 꺼진 news 테이블 0, FOR ALL 정책 0, news 쓰기 정책 0, anon·authenticated 테이블 쓰기 GRANT 0, `search_path` 없는 DEFINER 함수 0, anon EXECUTE 함수 = 4.3절 목록 11개 |
| 미동의 조직 `resolve_ai_route`(모듈러) | `news.moderation` = oss-llm(강제), `news.stt` = oss-voice(강제), `news.draft` = oss-llm, `news.knowledge` = oss-embed, `news.tts` = oss-voice |
| `node products/local-news/supabase/monolith/tests/run-smoke.mjs --target mono`(저장소 루트) | PASS=314 FAIL=0 |
| `node products/local-news/supabase/monolith/tests/run-smoke.mjs --target mod` | PASS=314 FAIL=0 |

스모크 절별 항목 수: 1 개설·프로비저닝 21, 2 구성원·역할 20, 3 기사 작성·유형 규칙 16, 4 워크플로 20, 5 게시 요건 31, 6 방문자 공개 범위 33, 7 교차 신문사 12, 8 독자 데이터 10, 9 댓글·신고 21, 10 정정 청구 SLA 22, 11 조회수·검색 19, 12 광고 19, 13 뉴스레터 21, 14 제보·Storage 12, 15 멤버십·프리미엄·후원 15, 16 홈·경조사·행사·공고 12, 17 주간 지표 5, 18 엔타이틀먼트 정지·테마 해석 5. SB 15장 공통 항목 중 코어 표(지갑·원장·구독) 항목은 코어 스모크(DBC 13.2)가 맡고, 이 파일은 제품 항목과 코어 경계(독자 비멤버, 초대제 엔타이틀먼트, `has_entitlement` anon 42501, `session_context`)를 검사한다.

검증 중 고친 결함(기록): (1) 기사형 광고 라벨 CHECK 가 `sponsor_label` NULL 에서 NULL 로 평가되어 통과하던 문제 → `is not null` 추가(조각:420-422). (2) URL CHECK 정규식 반복 상한 256 초과(`{3,1000}`)가 평가 시 2201B → 길이 검사와 분리. (3) 게시 후 댓글 스위치 같은 설정 변경까지 공개 수정 이력을 남기던 문제 → 내용 필드 변경만 공개 수정으로(조각:2829 `save_article`). (4) 모놀리스에서 함수 권한 일괄 회수가 코어 함수 권한까지 지우는 문제 → 이름 목록 방식.

남은 한계: 미터형 페이월은 DB 강제가 아니다(7장 #11). `article_view_hourly` 롤업·삭제와 제보 보존 만료 삭제, 정정 기한 알림, 수신동의 2년 재확인 메일은 워커 작업이다(13절 스케줄 주석). Supabase 실제 환경의 storage.objects 기본 권한·`auth.users` 접근은 PGlite 스텁으로 흉내 냈다(로컬 Supabase 재검증은 06장 작업).

## 10. 개발용 시드 페르소나 (Stage A, 2026-10-15 추가, 마스터 브리프 6장)

스키마 변경 없음. Stage A Mock 로그인은 로컬 Supabase 에 시드한 실제 계정으로 로그인한다(`AUTH_ROADMAP.md` 2장). 공통 스크립트 `scripts/dev/seed-users.mjs --app news`가 계정을 만든 뒤 제품 훅 `scripts/dev/seed-users.news.mjs`(제안)가 아래 "만드는 경로"를 실행한다. 원격 호스트면 즉시 종료, 이메일 도메인 `.test`, 비밀번호 `DEV_SEED_PASSWORD`(출력 금지). 두 번 실행해도 같은 결과(이미 있는 신문사 슬러그·독자 행은 건너뛴다).

이 제품의 특이점: `news`는 invite 앱이라 `signup_app=news`로 만들어도 가입 트리거가 엔타이틀먼트를 만들지 않는다(`docs/products/_supabase-modular/migrations/0001_core_identity.sql:149-154`, 모놀리스 `supabase/monolith/migrations/0001_core_lite.sql`의 같은 분기). 신문사는 실제 운영과 같은 경로인 `request_newspaper`(본인) → `approve_newspaper`(service_role)로만 생긴다. 독자는 엔타이틀먼트 없이 `ensure_reader`로 그 신문사의 독자 행만 만든다.

### 10.1 공통 페르소나 (AUTH_ROADMAP 2.2절, 브리프 6장 매핑)

| 키 | 이메일 | 만드는 경로(공통 → 제품 훅) | 기대 결과 | 확인하는 것 |
|---|---|---|---|---|
| `owner` = publisher | `owner@dev.test` | `signup_app=news`로 생성 → 훅: 본인 세션 `request_newspaper('dev-times', '개발타임즈', …, '<개인 조직>/news/applications/dev.pdf')` → service `approve_newspaper(<신청>, 'news_standard')` → `set_newspaper_profile`(필수 10항목) | 조직 `dev-times`(is_personal=false) owner, staff publisher, `session_context('news', <조직>)` entitled=true·plan `news_standard`, 크레딧 1,500, 독자 사이트 공개 | 개설·승인 경로, 매체정보 게이트, 편집국 전체 |
| `admin` = editor | `admin@dev.test` | owner 세션 `invite_staff(<조직>, <user>, 'editor', '김편집')` → 본인 `accept_staff_invite` | 코어 admin + staff editor | 매체정보·구성원·정정 결정(CHIEF) |
| `member` = reporter | `member@dev.test` | 같은 방법(reporter) | 코어 member + staff reporter | 자기 초안만 수정, 승인·게시 42501 |
| `viewer` | `viewer@dev.test` | 생성 후 owner 가 코어 `invite_member(<조직>, <user>, 'viewer')` → `accept_invite`(staff 행 없음) | 코어 viewer, 도메인 역할 없음 → 편집국 모든 표 0행 | 도메인 역할 없는 조직 멤버는 아무것도 못 본다(`/newsroom/no-access`) |
| `outsider` = 다른 신문사 발행인 | `outsider@dev.test` | `signup_app=news` → 훅: `request_newspaper('other-daily', …)` → service `approve_newspaper(…, 'news_trial')` → `set_newspaper_profile` | 자기 신문 owner. owner 신문의 기사·독자·청구·후원 0행 | 교차 신문사 격리(위험 #1) |
| `no_app` | `no_app@dev.test` | `signup_app` 없이 생성. 훅 없음 | 모듈러·모놀리스 모두 `entitled=false`, staff 0 → 편집국 콘솔은 개설 신청 안내 | 초대받지 않은 Google 계정(B단계 invite 분기)을 A에서 미리 검증 |
| `suspended` | `suspended@dev.test` | owner 신문에 reporter 로 초대·수락 → service 로 `profiles.status=suspended` | 403 | 차단 |
| `ops` | `ops@dev.test` | 생성 후 service 로 `platform_role=platform_admin` | 개설 신청 전체 조회, `compliance_weekly_stats` 조회, 기사 0행(편집국 아님) | 운영 콘솔(NW-F-062). 승인 쓰기는 화면이 아니라 서버(service_role) |
| `pending` | - | 만들지 않는다 | 해당 없음(approval 앱 전용) | - |

### 10.2 제품 페르소나 (news 도메인)

| 키 | 이메일 | 만드는 경로 | 기대 결과 | 확인하는 것 |
|---|---|---|---|---|
| `desk` | `desk@dev.test` | owner 가 `invite_staff(…, 'desk')` → 수락 | 승인·게시·예약, 댓글 모더레이션, 제보함 | 데스크 워크플로 |
| `contributor` | `contributor@dev.test` | `invite_staff(…, 'contributor')` → 수락 | 자기 기사만 보이고 유형은 contribution, 제출만 가능 | 위험 #3 |
| `ad_manager` | `ad_manager@dev.test` | `invite_staff(…, 'ad_manager')` → 수락 | 광고·업소·공고, 기사는 기사형 광고만, 독자·제보 0행 | 광고 분리 |
| `reader` | `reader@dev.test` | `signup_app` 없이 생성 → 본인 세션 `ensure_reader(<owner 신문>, '개발독자', 'v1', 'v1', true)` | `news.readers` 1행, 조직 멤버 아님, `session_context('news')` entitled=false | 독자 로그인·댓글·제보·경조사(독자 사이트) |
| `reader_member` | `reader_member@dev.test` | `ensure_reader` → service `record_membership(<신문>, <독자>, <등급>, 'active', now(), now()+1개월, 'dev', 'dev-seed:member')`(등급은 훅이 `upsert_membership_tier`로 1개 생성) | 프리미엄 본문 열림 | 멤버십·페이월 |
| `reader_other` | `reader_other@dev.test` | `ensure_reader(<outsider 신문>, …)` | owner 신문 독자 행 0, owner 신문 댓글 NW008 | 독자 데이터 격리(위험 #7) |
| `anon` | - | 계정 없음(시나리오) | 공개 기사 공개 컬럼, 본문은 `read_article`, 미게시·엠바고 0행 | 방문자 공개 범위(위험 #2) |

| 항목 | 내용 |
|---|---|
| 샘플 데이터(제안) | 훅이 owner 신문에 섹션 3(지역, 사회, 문화), 지역 1, 기사 5건(초안 1, 제출 1, 게시 2, 기사형 광고 1. 게시는 desk 세션 RPC 로), 뉴스레터 목록 1, 광고 슬롯 2를 만든다. 이름·연락처는 `*.test` 가짜 값만 |
| 스모크와의 관계 | `tests/rls_smoke.sql`의 행위자(P, E, D, R, K, M, X, U, W, V, N, O)는 위 페르소나와 같은 역할이다(P=owner, E=admin, D=desk, R=member, K=contributor, M=ad_manager, X=outsider, U=reader, W=reader_member, V=reader_other, O=ops). 러너는 계정을 SQL 로 직접 만들지만 신문사·구성원·독자는 같은 RPC 경로를 쓴다 |
| 독자 로그인 도메인 | Stage A 는 로컬 단일 호스트에서 테넌트 슬러그(`?tenant=dev-times` 또는 `dev-times.localhost`)로 독자 사이트를 연다(제안, 02장 라우팅과 맞춘다). Redirect URL 허용 목록 문제(D-3)는 B단계 일 |

### 10.3 모놀리스와 모듈러 차이

| 항목 | 모듈러(`news` + `core`) | 모놀리스(단독 `public`, 개발 기본) |
|---|---|---|
| `no_app` | `entitled=false` | invite 앱이라 단일 앱 자동 부트스트랩도 건너뛰어 `entitled=false`(같음) |
| `reader` | `entitled=false`, 독자 행 1 | 같음 |
| 시드 대상 | `--app news`(다른 앱과 함께 시드해도 news 는 위 훅 경로만) | `--app news` 한 번 |
| 플랜·라우팅 | 조각 14절이 넣음 | `seed.sql` |
