# local-news 공통모듈 기획서 색인 (M1~M8)

작성일 2026-10-15. 로컬뉴스 클라우드(가칭, app id `news`)의 공통모듈 8개를 정의한다. 1차는 모두 `news` 스키마 안 모듈별 절로 만들고, 다른 제품이 쓰기 시작하면 `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 3장 공용 스키마로 꺼낸다(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:40`, `:65-81`). 이 폴더는 모듈 경계·계약·규칙만 적고, 표의 컬럼 정본은 `docs/products/local-news/05_DATA_MODEL.md`, 라우트·오류 코드 정본은 `docs/products/local-news/04_API.md`, 기능 수용 기준 정본은 `docs/products/local-news/01_PRD.md` 3절이다. 개발 순서·디렉토리·테스트는 `docs/develop/local-news/modules/README.md`.

| 문서 형식 근거 | 이 폴더에서 따르는 것 |
|---|---|
| `docs/products/_platform-core/SHARED_MODULES.md:32-57`, `:58-485` | 모듈마다 소유/소비, 코어 SQL(여기서는 `news` 표), TS 계약 예시, 실패 동작 |
| `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:83-210` | MVP/확장 구분, 연결 모듈, 개인정보 |
| `docs/products/_platform-core/SHARED_MODULES.md:486-494` | 재정의 금지, 서버 경계, 멱등 키, 실패 숨기기 금지 |
| 05장 SQL(`2500_news.sql` 1차본, 2026-10-15) | 표·상태·RPC·SQLSTATE 이름. 이 폴더의 이름은 이것에 맞췄다(다른 장과의 차이는 6장 MQ-5) |

## 1. 모듈 색인

| ID | 파일 | 책임 | 소유 표(`news.`) | 소비 기능(NW-F) | 우선 |
|---|---|---|---|---|---|
| M1 | `M1_newsroom-cms.md` | 신문사 개설·편집국 구성, 기사 작성·데스크 워크플로·버전, 미디어, 홈 편집, 지면, 라이브 기사, 이관·내보내기 | `newspaper_applications`(05장 SQL에서 추가), `newspapers`, `staff`, `sections`, `regions`, `tags`, `articles`, `article_revisions`, `article_regions`, `article_tags`, `media_assets`, `home_layouts`, `print_editions`, `live_updates` | 001, 004, 010~017, 063, 064 (020·021 화면이 읽음) | P0 |
| M2 | `M2_reader-membership.md` | 신문사별 독자 행, 후원(일시·정기), 유료 멤버십, 미터형 페이월 | `readers`, `membership_tiers`, `memberships`, `donations`, `paywall_rules` | 006(독자 행), 035, 036 | P0(독자 행) / P1 |
| M3 | `M3_ad-manager.md` | 광고 슬롯·캠페인·소재·집계, 외부 광고망 태그, 업소 디렉토리, 지자체 공고 | `ad_slots`, `advertisers`, `ad_campaigns`, `ad_creatives`, `ad_daily_stats`, `local_listings`, `public_notices` | 023(공고 목록), 030~034 | P0 / P1 |
| M4 | `M4_notify-newsletter.md` | 뉴스레터 목록·이중 동의 구독·발송·통계, 속보 웹 푸시 | `newsletter_lists`, `newsletter_subscriptions`, `newsletter_issues`, `push_subscriptions` | 037, 038 | P0 / P1 |
| M5 | `M5_community.md` | 댓글·신고·임시조치, 독자 제보·투고, 경조사 신청 | `comments`, `comment_reports`, `tips`, `life_events` | 024, 025, 026 | P0(제보) / P1 |
| M6 | `M6_distribution-seo.md` | RSS, 뉴스 사이트맵, 구조화 데이터·OG·canonical, 통신사 전재 계약, 포털 전송 기록, AI 크롤러 정책, SNS 공유 | `wire_contracts`, `syndication_settings` | 040, 042, 043, 045 | P0 / P1 |
| M7 | `M7_compliance-desk.md` | 필요적 게재사항 판정, 법정 푸터, 자체기사 비율, 정정·반론·추후보도 SLA, 선거 모드, 광고·AI 표시 규칙 | `correction_requests`, `election_periods` + 함수 `compliance_weekly_stats`, `is_profile_complete` | 002, 017, 027, 028, 032, 041, 044 | P0 |
| M8 | `M8_search-analytics.md` | 기사 검색, 조회 집계·많이 본 뉴스, 편집국 대시보드, 지원사업 리포트 | `article_view_hourly` + 뷰·함수(`most_read`, `increment_article_views`) | 022, 060, 061 | P0 / P1 |
| - | (제품 기능) local-life | 행사 캘린더, 날씨·미세먼지 블록. 모듈이 아니라 제품 기능이다 | `events` | 023 | P1 |

코어 모듈(인증, 조직, 엔타이틀먼트, Toss, 웹훅, 자격증명 암호화, 잡, Storage, 감사, 레이트 리밋, AI 계층, 화이트라벨 Theming)은 참조만 한다(`docs/products/_platform-core/SHARED_MODULES.md:486-490`). 이 8개 모듈 안에서 코어를 다시 만들지 않는다.

## 2. 의존 그래프

화살표는 "호출하거나 읽는다"는 뜻이다. 쓰기 방향은 항상 소유 모듈의 RPC나 공개 API를 거친다(3장).

```text
                 코어(auth, org, entitlements, toss, webhooks, encrypted_credentials,
                      jobs, storage, audit, rate_limit, ai-gateway, Theming resolve_tenant)
                                  ^ (모든 모듈이 사용)
                                  |
   M7 compliance-desk  <-------- M1 newsroom-cms --------> M6 distribution-seo
   (규칙 함수: 게시 게이트,        (기사 원본, 상태 전이)      (wire 계약 판정 함수,
    라벨, 선거 엠바고)                |   ^                     RSS·사이트맵·JSON-LD)
        ^   ^   ^                     |   | (기사 읽기 전용)
        |   |   |      이벤트 news.article.*  +------------------+------------------+
        |   |   |                     v                          |                  |
        |   |   +---- M3 ad-manager (라벨 규칙)       M4 notify-newsletter     M5 community
        |   +-------- M5 community (선거 댓글 정책)    (브리핑·속보 푸시)      (댓글·제보·경조사)
        +------------ M4 (광고성 표기 규칙)                 |                       |
                                                           v                       v
                      M2 reader-membership  <---------- (독자 연결: reader_id) ------+
                      (독자 행, 등급, 페이월)
                                  |
                                  v
   M8 search-analytics: M1·M2·M3·M4·M7을 읽기 전용 뷰·함수로만 읽는다(쓰지 않는다)
```

| 의존 | 방식 | 이유 |
|---|---|---|
| M1 → M7, M6 | DB 함수 호출(`news.publish_article` 안에서 `news.is_profile_complete`, 라벨·엠바고 판정, wire 계약 판정) | 게시 차단은 서버·DB가 해야 한다. 클라이언트 판정은 보조(`docs/products/_platform-core/SECURITY_BASELINE.md:179-190`) |
| M4, M5, M6, M8 → M1 | 기사 읽기 전용(공개 뷰 또는 공개 TS API), 이벤트 구독 | 기사 원본은 M1만 바꾼다 |
| M5, M4 → M2 | `readers.id` 참조, `ensureReader` 호출 | 댓글·구독의 주체는 그 신문사 독자 행 |
| M3, M4, M5 → M7 | 표시 규칙 함수(광고 라벨, `(광고)` 제목 표기, 선거 댓글 정책) | 법규 규칙의 소유자를 한 곳(M7)으로 모은다 |
| M8 → 전부 | 읽기 전용 뷰·집계 함수 | 리포트는 다른 모듈 데이터를 바꾸지 않는다 |
| M7 → M1 | 읽기 전용 뷰(주간 통계, 정정 대상 기사) | M7은 M1 TS 코드를 import 하지 않는다(순환 방지) |

순환 금지 규칙: TS import 방향은 위 표의 화살표만 허용한다. 역방향이 필요하면 이벤트로 바꾼다.

## 3. 경계 규칙

| 규칙 | 내용 | 근거 |
|---|---|---|
| 재정의 금지 | 코어 모듈과 다른 모듈의 표·함수·타입을 복사해 다시 만들지 않는다. 필요한 기능이 없으면 소유 모듈에 요청(06장 작업)으로 남긴다 | `docs/products/_platform-core/SHARED_MODULES.md:490` |
| 쓰기는 소유 모듈만 | 다른 모듈 표에 INSERT/UPDATE/DELETE 하지 않는다. 소유 모듈의 RPC(`news.*`) 또는 공개 TS API(`src/modules/<모듈>/server/index.ts`, `docs/products/local-news/02_ARCHITECTURE.md` 2절 모듈 모양)를 부른다 | `docs/products/_platform-core/SECURITY_BASELINE.md:97-108` |
| 상태는 RPC로 | 상태 컬럼이 있는 표(기사, 멤버십, 캠페인, 구독, 댓글, 정정 청구)는 전이 RPC 또는 전이 트리거로만 바꾼다. 허용 밖 전이는 `22023` | `docs/products/_platform-core/DB_CONVENTIONS.md:221-230` |
| 읽기는 뷰·함수로 | 다른 모듈 데이터를 읽을 때는 소유 모듈이 공개한 뷰·함수만 쓴다. 표 구조를 직접 가정하지 않는다(추출 때 깨지지 않게) | 제안 |
| 외래키 | 다른 모듈 표를 FK로 참조하는 것은 허용(예: `comments.article_id → articles.id`). 삭제 동작은 소유 모듈이 정한다 | 제안 |
| 이벤트 | 이름 `<영역>.<대상>.<동작>`(예 `news.article.published`)은 모듈 사이 약속을 부르는 논리 이름이다. 별도 이벤트 버스는 두지 않는다. 전달은 (a) 상태를 바꾼 Route Handler가 같은 요청 안에서 부르는 후처리(캐시 무효화 등) (b) `core.jobs` 잡(예: `news.article.published` → `news.post_publish`, `docs/products/local-news/02_ARCHITECTURE.md` 4절) (c) 외부 구독자용 발신 웹훅(`docs/products/local-news/04_API.md` 5절). 멱등 키 `<event>:<entity_id>:<version>` | `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:153`, `docs/products/_platform-core/SHARED_MODULES.md:492` |
| 놓친 이벤트 | 잡 enqueue 전에 서버가 멈추는 경우에 대비해 결과가 중요한 일은 주기 작업이 DB 상태로 다시 맞춘다(예: 예약 게시 pg_cron 1분 재enqueue, `news.stats_rollup`, `news.correction_sla`, `02_ARCHITECTURE.md` 4절). 전용 outbox 표는 두지 않는다(MQ-2) | `docs/products/local-news/02_ARCHITECTURE.md` 4절 |
| 테넌트 | 모든 표에 `org_id`. 독자 사이트 요청은 Host → `resolve_tenant`로 정한 조직만 쓴다. 요청 본문의 org 값은 믿지 않는다 | `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:5-15` |
| 실패 표시 | 장애를 mock 응답으로 숨기지 않는다 | `docs/products/_platform-core/SHARED_MODULES.md:493` |

## 4. 모듈 이벤트 목록 (요약)

| 모듈 | 발행 이벤트 | 주요 구독자 |
|---|---|---|
| M1 | `news.newspaper.approved`, `news.staff.joined`, `news.article.submitted`, `.approved`, `.rejected`, `.published`, `.updated`, `.unpublished`, `.corrected`, `news.home.published`, `news.live.posted` | M6(사이트맵·캐시), M4(속보 푸시·브리핑), M8(대시보드), M7(정정 연결) |
| M2 | `news.reader.joined`, `news.reader.withdrawn`, `news.membership.activated`, `.past_due`, `.canceled`, `news.donation.paid`, `.refunded` | M4(환영 메일), M8(독자 수) |
| M3 | `news.ad.campaign.started`, `.ended`, `news.ad.creative.reviewed`, `news.listing.published`, `news.notice.published` | M8(리포트), 캐시 무효화 |
| M4 | `news.newsletter.confirmed`, `.unsubscribed`, `news.newsletter.issue.sent`, `news.push.sent` | M8 |
| M5 | `news.comment.posted`, `.reported`, `.temp_blocked`, `news.tip.received`, `news.life_event.submitted` | 편집국 알림, M8 |
| M6 | `news.wire.contract.expiring`, `.expired` | M1(전재 기사 비노출 처리 요청) |
| M7 | `news.correction.received`, `.sla_warning`, `.overdue`, `news.compliance.ratio_warning`, `news.election.started`, `.ended` | 편집국 알림, M5(댓글 정책) |
| M8 | 없음(소비 전용) | - |

## 5. 추출 계획 (두 번째 제품이 쓰면 공용 스키마로)

원칙: 처음 쓰는 제품 안 `src/modules/<모듈>/`에 만들고, 두 번째 제품이 쓸 때 패키지와 공용 스키마로 꺼낸다(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:40`). 추출 전까지 다른 제품은 이 모듈을 복사하지 않는다.

| 모듈 | 추출 대상 | 공용 스키마(번호) | 추출 조건(제안) | 뉴스 전용으로 남는 것 |
|---|---|---|---|---|
| M1 | 블록 에디터(문단·소제목·사진·인용·표·임베드)와 블록 렌더러만 | `cms`(0800) | 두 번째 제품이 블록 에디터를 쓸 때 | 기사 워크플로, 바이라인, 지면, 홈 편집 |
| M2 | 독자(최종 사용자) 계정 행, 등급형 멤버십, 후원 | `growth`(0900) 검토, 결제는 코어 | flora-publishing 멤버십 확장(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:173`) 착수 때 | 미터형 페이월 규칙(기사 단위) |
| M3 | 슬롯·캠페인·소재·집계 | `ads`(신규 제안, 번호 범위 미정. 0100~0999는 이미 배정됨, `:69-79`) | 광고 슬롯이 필요한 두 번째 제품(nomad-blog 등 후보, 미확인) | 지자체 공고, 기사형 광고 라벨 |
| M4 | 목록·이중 동의 구독·발송 기록·웹 푸시 | `notify`(0100) | notify v1 착수 때(`:87-98`). 가장 먼저 꺼낼 후보 | 아침 브리핑 자동 구성 |
| M5 | 제보·투고 접수함 | `support`(0700) 일부 | support v1 착수 때(`:204`) | 댓글 임시조치(언론 맥락), 경조사 |
| M6 | RSS·일반 사이트맵·OG 생성기 | `cms`(0800) SEO 부분 | cms 착수 때 | 뉴스 사이트맵, NewsArticle, 전재 계약, 포털 전송 |
| M7 | 없음 | - | - | 전부(신문법·언론중재법·공직선거법 전용) |
| M8 | 이벤트 규격·외부 도구 연결 | `analytics`(새 스키마 없음, `:148-156`) | analytics 래퍼 도입 때 | 조회 시간 버킷, 많이 본 뉴스, 지원사업 리포트 |

추출할 때 지킬 것:

| 단계 | 할 일 |
|---|---|
| 1 | 공개 API(`server/index.ts`)와 이벤트 이름을 그대로 유지한 채 패키지 `@nomad/<모듈>`로 옮긴다(배포 방식은 `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:238` M-D2) |
| 2 | `news.<표>`를 공용 스키마 표로 옮기는 마이그레이션 + `news`에는 호환 뷰를 남긴다(한 릴리스 동안) |
| 3 | `app_id` 컬럼을 추가해 제품 구분(공용 모듈 표 규칙, `:81`) |
| 4 | 계약 테스트를 패키지로 옮기고 local-news가 패키지로 바꿔도 E2E 녹색인지 확인 |
| 5 | `SHARED_MODULES.md`에 장 추가, 각 제품 06장 공용 모듈 요청 표 갱신(`:244-253`) |

## 6. 열린 질문 (모듈 공통)

| ID | 질문 | 권고(제안) | 관련 |
|---|---|---|---|
| MQ-1 | 독자 결제 주문·빌링키 저장 위치: 코어 `payment_orders`·`billing_keys`는 "조직이 플랫폼에 내는 돈"(customerKey `org_<id>` 고정, `docs/products/_platform-core/SHARED_MODULES.md:163`)이라 독자 결제와 맞지 않는다 | M2 표에 주문 id·상태를 두고 빌링키는 `core.encrypted_credentials`에 저장. 코어에 "주체=독자" 확장을 요청할지 D-4와 함께 결정 | M2, D-4 |
| MQ-2 | 이벤트 outbox 표를 둘지 | 1차는 잡 enqueue + 주기 재조정(02장 4절과 같음). 유실이 문제 되면 `news.event_outbox` 추가 | 전 모듈 |
| MQ-3 | 금칙어·댓글 기본값 등 M5 설정이 M1 표(`newspapers.banned_words`, `newspapers.comments_enabled`, 05장 SQL)에 있다 | 쓰기는 M1 매체·설정 RPC로만, 해석(금칙어 매칭·댓글 허용 판정)은 M5. 추출 때 M5 설정 표로 분리 | M1, M5 |
| MQ-4 | `ads` 공용 스키마 번호 범위 | 추출 시점에 결정(지금 정하지 않음) | M3 |
| MQ-5 | 장 사이 이름 불일치 | 해결(2026-10-15): 02·04장을 05장 SQL(오류 코드 NW001~NW015, 반려 = `draft`, 댓글 `hidden`, 경조사 `personnel`·`people`, 정정 `rebuttal`, `record_donation`·`record_membership`, `register_`·`revoke_push_subscription`)에 맞췄다 | 전 모듈 |
| MQ-6 | 검색 필터(섹션·지역·기간)가 `news.search_articles` 인자에 없음 | 인자 추가(변경 제안) 또는 1차는 필터 없이 | M8 |
| MQ-7 | 대시보드 "유입" 지표에 필요한 유입 분류 컬럼이 `article_view_hourly`에 없음 | 1차 미제공, 필요 시 버킷 키 확장 | M8 |
