# local-news 공통모듈 개발 지시서 (M1~M8)

작성일 2026-10-15. 모듈 "기획"(책임·경계·계약·규칙)은 `D:/WorkSpace/platform/docs/products/local-news/modules/README.md`와 모듈별 기획서 8개가 정본입니다. 이 폴더는 그 기획을 **실제로 만드는 방법**입니다: 어떤 순서로 만들고, 파일을 어디에 두고, 외부 서비스를 어떻게 설정하고, 무엇으로 확인하고, 나중에 공용 패키지로 꺼내 다른 제품에 어떻게 적용하는지. 형식은 `D:/WorkSpace/platform/docs/develop/_shared/auth/README.md`(소셜 로그인 지시서)를 따릅니다. 외부 콘솔 화면·메뉴 이름은 2026-10-15 공식 문서 기준이며 자주 바뀌므로 작업 직전에 링크를 한 번 더 엽니다. 확인하지 못한 값은 "미확인"으로 적습니다.

| 문서 | 무엇을 보나 |
|---|---|
| `D:/WorkSpace/platform/docs/products/local-news/modules/README.md` | 모듈 색인, 의존 그래프, 경계 규칙, 이벤트 목록, 추출 계획 |
| `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md` | 표·RLS·상태 전이 정본 |
| `D:/WorkSpace/platform/docs/products/local-news/04_API.md` | Route Handler, RPC, 잡 페이로드, 오류 코드 정본 |
| `D:/WorkSpace/platform/docs/products/local-news/06_AGENT_PLAN.md` | 작업 ID `NW-06-###`, 웨이브, 권장 모델 |
| `docs/file/03-설계/공용코어/SHARED_MODULES.md` | 코어 모듈 계약(재정의 금지) |
| `docs/file/03-설계/공용코어/SECURITY_BASELINE.md` | 쓰기 경로, 비밀, 레이트 리밋, RLS 회귀 테스트 |
| 이 폴더 `M1_newsroom-cms.md` ~ `M8_search-analytics.md` | 모듈별 만들 것, 파일, 순서, 외부 설정, 테스트, 운영 점검표 |

## 1. 먼저 정할 것 (사람 결정)

| ID | 결정 | 권고 | 시점 | 관련 |
|---|---|---|---|---|
| D-4 | 독자 결제: 신문사 자기 Toss 가맹 vs 플랫폼 일괄 수납 | 신문사 자기 가맹 | M2 착수 전 | `M2_reader-membership.md` |
| D-6 | 댓글 기본값 | 기본 끔 | M5 착수 전 | `M5_community.md` |
| D-7 | 검색 엔진 | 1차 Postgres(`pg_trgm` + `tsvector`) | M8 착수 전 | `M8_search-analytics.md` |
| D-8 | 날씨·미세먼지 외부 API 조건 | 공공데이터포털 개발 계정으로 시작 | local-life 착수 전 | `M8_search-analytics.md` 4장 참고 |
| D-9 | AI 표시 문구, 자체기사 비율 제외 규칙 | `press_release`·`wire` 제외 | M7 착수 전 | `M7_compliance-desk.md` |
| MD-1 | 이메일 발송 제공자 | Resend(시작) 또는 Amazon SES(물량 커지면) | M4 착수 전 | `M4_notify-newsletter.md` |
| MD-2 | 모듈 패키지 배포 방식 | 인증 모듈 AUTH-D2와 같게: v0.x 제품 안, v1.0부터 비공개 npm `@nomad/<모듈>` | 첫 추출 때 | 6장 |

MD-1, MD-2는 이 문서가 새로 붙인 결정 번호(제안)입니다. 확정되면 `D:/WorkSpace/platform/docs/products/local-news/01_PRD.md` 열린 결정 표로 옮깁니다.

## 2. 만드는 순서 (웨이브 제안)

웨이브 번호와 작업 ID의 정본은 `D:/WorkSpace/platform/docs/products/local-news/06_AGENT_PLAN.md`입니다. 아래는 모듈 의존 그래프에서 나온 권장 순서입니다.

| 웨이브 | 모듈·부분 | 선행 | 끝나는 조건 |
|---|---|---|---|
| 0 | 코어 라이트, Theming(`resolve_tenant`), 인증 Stage A, 캐시 태그 정본(`apps/web/src/lib/cache/tags.ts`), 워커 큐 골격 | - | Mock 페르소나로 편집국·독자 로그인, 테넌트 Host 분기 |
| 1 | M1 기사·워크플로·미디어·홈 편집(P0), M7 매체정보 판정·법정 푸터·게시 게이트 | 0 | 기사 1건이 draft → published, 매체정보 미완성이면 독자 사이트 차단 |
| 2 | M6 RSS·사이트맵·JSON-LD, M8 조회 집계·많이 본·검색, M2 독자 행(`ensure_reader`), M5 제보(P0), M3 직판 슬롯·라벨(P0), M4 뉴스레터(P0), M7 정정 SLA·주간 통계 | 1 | P0 기능 수용 기준 녹색 |
| 3 | M2 후원·멤버십·페이월(P1), M5 댓글·경조사(P1), M4 웹 푸시(P1), M3 GAM·업소·공고(P1), M6 전재 계약·AI 크롤러(P1), M7 선거 모드(P1), M8 월 리포트(P1), M1 지면·라이브·이관·내보내기(P1) | 2 | P1 수용 기준 녹색 |
| 4 | M6 SNS 공유, M4 알림톡, M8 참여 시간·외부 검색(P2) | 3 | - |

웨이브 1에서 M1과 M7을 같이 만드는 이유: 게시 RPC(`news.publish_article`)가 M7 판정 함수를 부르므로 둘 중 하나만 있으면 게시 경로를 끝까지 시험할 수 없습니다.

## 3. 코드 규칙

### 3.1 디렉토리

모듈 모양의 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2절입니다(`server/`, `components/`, `schema.ts`, `cache.ts`, 공개 함수는 `server/index.ts`). 아래는 그 모양에 이 문서가 더하는 것(`test/`, 잡 핸들러 위치)만 적은 것입니다.

```text
apps/web/src/modules/<모듈>/          newsroom-cms(M1) reader-membership(M2) ad-manager(M3) notify-newsletter(M4)
                                      community(M5) distribution-seo(M6) compliance-desk(M7) search-analytics(M8)
  server/index.ts                     공개 서버 API. 다른 모듈은 이 파일만 import
  server/*.ts                         RPC 호출, zod 검증, 외부 어댑터 호출. 첫 줄 import 'server-only'
  components/                         화면 조각(디자인 토큰만). 라우트 페이지가 import
  schema.ts                           입력 계약(zod) = 기획서 5장 TS 계약의 구현
  cache.ts                            이 모듈이 무효화할 태그(이름은 apps/web/src/lib/cache/tags.ts 정본에서 가져옴)
  test/                               단위·계약 테스트(이 문서 제안)
worker/src/handlers/<queue>/<job_type>.ts   잡 핸들러(큐·job_type 정본 02장 4절). 모듈 server/ 함수를 재사용
apps/web/src/app/api/r/..., api/newsroom/..., api/webhooks/...   얇은 Route Handler(04장 2절)
```

| 규칙 | 내용 |
|---|---|
| 공개 API | 다른 모듈은 `@/modules/<모듈>/server`(= `server/index.ts`)만 import. 내부 파일 직접 import는 린트로 금지(eslint `no-restricted-imports`, 02장 2절 제안) |
| 의존 방향 | `D:/WorkSpace/platform/docs/products/local-news/modules/README.md` 2장 그래프 방향만. 역방향은 잡으로 바꿈. CI가 import 순환을 검사(madge 등, 제안) |
| DB 쓰기 | 자기 모듈 표만. 다른 모듈 표는 그 모듈 RPC나 공개 API로. 상태 컬럼은 RPC·전이 트리거로만(`docs/file/03-설계/공용코어/DB_CONVENTIONS.md` 10장) |
| 서버 경계 | service_role 클라이언트(`createAdminClient`)는 `server/`와 워커에서만. `NEXT_PUBLIC_` 접두사에 비밀 금지(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 5장) |
| 라우트 | Route Handler·서버 액션은 얇게(입력 검증 → 모듈 공개 API → 응답). 경로 이름은 04장 2절 정본 |
| 캐시 태그 | 이름은 `apps/web/src/lib/cache/tags.ts` 한 곳(정본 02장 10.3절: `news:<org>:home`, `news:<org>:article:<id>`, `news:<org>:feeds`, `news:<org>:most-read`, `news:<org>:profile` 등). 워커는 `/api/internal/revalidate`로 무효화 |
| 오류 코드 | SQLSTATE `NW###`의 HTTP 매핑은 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 7절 표 하나만. 모듈마다 따로 만들지 않음 |

### 3.2 이벤트

별도 이벤트 버스는 만들지 않습니다(기획 README 3장). 기획서의 이벤트 이름은 아래 수단 중 하나로 구현합니다.

| 수단 | 언제 | 예 |
|---|---|---|
| 같은 요청 안 후처리 | 빠르고 실패해도 재조정되는 일 | 상태 변경 Route Handler가 `revalidateTag` |
| `core.jobs` 잡 | 시간이 걸리거나 재시도가 필요한 일 | `news.article.published` → `news.post_publish`(피드 무효화, 속보 푸시 enqueue, 발신 웹훅, AI 색인) |
| 주기 잡(재조정) | 잡 enqueue 유실·지연 대비 | 예약 게시 pg_cron 1분, `news.stats_rollup` 10분, `news.correction_sla` 1시간 |
| 발신 웹훅 | 신문사 외부 시스템 | `article.published` 등(04장 5절, 개인정보 이벤트는 내보내지 않음) |

| 항목 | 규칙 |
|---|---|
| 이름 | 이벤트 이름과 잡 `job_type` 대응표를 `apps/web/src/lib/events.ts`(제안) 상수로 두고 문자열을 흩뿌리지 않음 |
| 멱등 | 잡 멱등 키 `<event>:<entity_id>:<version>`(예 `job:news:publish:<article_id>:<scheduled_for>`, 02장 4절) |
| 트랜잭션 | RPC 트랜잭션 안에서 외부 호출 금지. 잡 enqueue는 RPC 안(같은 트랜잭션)에서 하거나 RPC 성공 뒤 서버에서 |
| 테스트 | 잡 페이로드가 04장 4절 계약(zod)을 통과하는지 계약 테스트 |

### 3.3 테스트

| 층 | 도구 | 무엇 |
|---|---|---|
| 단위 | Vitest | 판정 함수(게시 게이트, 미터, SLA 기한, 라벨 문구), 직렬화(RSS·사이트맵·JSON-LD) |
| 계약 | Vitest + zod | 공개 API 입출력(`schema.ts`), 잡 페이로드(04장 4절). 추출 때 패키지로 그대로 옮김 |
| RLS | `supabase/tests/rls_smoke.sql` + 페르소나 | 편집국 역할별·독자·다른 신문사·anon 접근(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 15장) |
| E2E | Playwright, 페르소나 `storageState` | 모듈별 핵심 흐름(각 지시서 5장) |
| 외부 | 수동 점검표 | Toss 결제, 실제 메일함 도착, 웹 푸시 수신, Search Console 사이트맵 제출 |

## 4. 환경변수 (모듈별 사용분, 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 8절)

| 변수 | 모듈 | 비고 |
|---|---|---|
| `CREDENTIALS_KEY_V<n>`, `CREDENTIALS_KEY_VERSION` | M2(신문사 Toss 키·빌링키 암호화) | 신문사별 시크릿 키는 환경변수가 아니라 `core.encrypted_credentials` |
| `EMAIL_PROVIDER`, `EMAIL_API_KEY`, `EMAIL_FROM_DOMAIN`, `EMAIL_WEBHOOK_SECRET` | M4, M5·M7(통지 메일) | 서버·워커 |
| `NEWSLETTER_TOKEN_HMAC_KEY` | M4 | 확인·해지 토큰 |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | M4 | 공개키만 브라우저로, 개인키는 워커 전용 |
| `TURNSTILE_SITE_KEY` / `TURNSTILE_SECRET_KEY` | M4, M5, M7 | 공개 폼(구독·제보·정정 청구·댓글) |
| `RATE_LIMIT_IP_SALT` | M3, M5, M8 | IP 해시 솔트(비콘·클릭·폼) |
| `REVALIDATE_SECRET` | 전 모듈 워커 | 워커 → `/api/internal/revalidate` |
| `PREVIEW_TOKEN_SECRET` | M1 | 기사·홈 미리보기 서명 URL |
| `KMA_API_KEY`, `AIRKOREA_API_KEY` | local-life | 공공데이터포털(조건 미확인, D-8) |

## 5. 운영 공통

| 항목 | 내용 |
|---|---|
| 알림 | 모듈 실패 알림은 편집국(신문사)과 운영자(플랫폼)를 나눔. 신문사 업무(정정 기한, 계약 만료)는 신문사로, 인프라 오류(제공자 장애)는 운영자로 |
| 잡 큐 | `news.publish`(M1·M6·발신 웹훅), `news.newsletter`(M4), `news.ingest`(M1 이관·미디어·내보내기), `news.ai`(AI 기능, M5 AI 판정), `news.stats`(M8·M3·M2 갱신·M7 SLA), `news.domain`(Theming). 큐별 동시성은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 4절 |
| 로그 | 토큰·카드·제보 원문·이메일 주소를 로그에 남기지 않음(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 12장) |

## 6. 버전과 추출, 다른 제품 적용

### 6.1 버전

| 버전 | 들어가는 것 | 조건 |
|---|---|---|
| v0.x | local-news 제품 안 `apps/web/src/modules/<모듈>/`(복사·공유 없음) | 그 모듈 P0 수용 기준 녹색 |
| v1.0 | 공용 패키지 `@nomad/<모듈>` 추출(공개 API·이벤트 이름 유지) + 공용 스키마 마이그레이션 + `news` 호환 뷰 | 두 번째 제품이 실제로 쓰기 시작(`D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 2장 "두 번째 사용 때 공용화") |
| v1.x | 기능 추가(하위 호환) | `CHANGELOG.md`에 "제품이 할 일" |
| v2.0 | 공개 API·이벤트·표 계약이 바뀜 | 적용 제품 전체 마이그레이션 계획 |

- semver. 패키지는 정확한 버전으로 고정(`latest` 금지). 에이전트는 PR까지만, 출시는 사람 승인(`D:/WorkSpace/platform/docs/develop/_shared/auth/README.md` 9.1절과 같음).
- 추출 대상·공용 스키마는 기획 README 5장 표. M1 워크플로와 M7은 추출하지 않습니다.

### 6.2 추출 절차 (모듈 하나, 에이전트 작업 1개)

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 공개 API(`server/index.ts`)에 뉴스 전용 개념이 새어 있는지 점검(예: `articleId`를 `contentRef`로 일반화). 바꾸면 local-news 쪽에 어댑터 | 계약 테스트 녹색 |
| 2 | 공용 스키마 마이그레이션(번호는 `D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 3장) + `app_id` 컬럼 + 데이터 이관 SQL + `news` 호환 뷰 | RLS 스모크 녹색 |
| 3 | 패키지 생성, `schema.ts`·`test/`(계약 테스트)를 패키지로 이동 | 패키지 단독 테스트 녹색 |
| 4 | local-news가 패키지로 교체 | 전체 E2E 녹색 |
| 5 | `SHARED_MODULES.md`에 장 추가 요청, 각 제품 06장 공용 모듈 요청 표 갱신 요청 | 문서 PR |

### 6.3 다른 제품에 적용 (후보, 미확인)

| 모듈 | 적용 후보 제품 | 적용할 때 주의 |
|---|---|---|
| M4 notify-newsletter → `notify` | 알림을 각자 적어 둔 제품 전반, flora-publishing 뉴스레터 | 광고성 판단·야간 동의는 제품별 목록 설정으로 |
| M2 → 독자·멤버십 | flora-publishing 멤버십 확장 | 결제 주체(독자 vs 조직) 코어 확장 MQ-1 먼저 |
| M3 → `ads` | 광고 슬롯이 필요한 콘텐츠 제품(미확인) | 라벨 규칙은 제품 법규에 맞게 주입 |
| M5 제보 → `support` | 문의함이 필요한 제품 | 제보자 보호 규칙은 뉴스 어댑터에 남김 |
| M6 RSS·사이트맵 → `cms` | 블로그형 제품 | 뉴스 사이트맵은 뉴스 전용 |
| M8 이벤트 → `analytics` | 랜딩이 있는 제품 | 외부 도구 결정 M-D3 |

### 6.4 적용 현황표 (운영 중 갱신)

| 모듈 | 버전 | 적용 제품 | 메모 |
|---|---|---|---|
| (모듈마다 1행) | v0.x / v1.x | local-news, ... | |

## 7. 점검표

- [ ] 1장 결정(D-4, D-6, D-7, D-9, MD-1, MD-2) 기록
- [ ] 웨이브 0: 캐시 태그 정본, 이벤트-잡 대응표, import 규칙 린트
- [ ] 웨이브 1: M1·M7 게시 경로 E2E 녹색, 매체정보 미완성 차단 확인
- [ ] 웨이브 2: P0 수용 기준(모듈 지시서 5장) 전부 녹색, RLS 스모크 녹색
- [ ] 외부 설정: Resend/SES 도메인 인증, VAPID 키, Turnstile, Search Console 사이트맵 제출(모듈 지시서 4장)
- [ ] 웨이브 3: P1 수용 기준, Toss 자동결제 계약이 있는 시범 신문사 1곳에서 실결제 점검
- [ ] 추출 후보 모듈별로 "두 번째 제품" 여부 분기마다 확인, 6.4절 갱신

## 공용모듈로 전환 (2026-10-15 추가)

M1~M8 중 제품 무관 부분은 공용모듈 7개(compliance, media, editorial, community, search, membership, ads)와 기존 공용모듈 보강(notify, analytics, cms, tenancy)으로 정의됐다. 대응표는 `products/local-news/modules/README.md` 5장, 개발 방법은 `develop/_shared/modules/README.md`.

| 시점 | 할 일 |
|---|---|
| 지금(1차) | 06장 작업대로 `news` 스키마에 만든다. 단 표·함수·이벤트 이름과 공개 API 모양은 공용모듈 기획서와 같은 뜻이 되도록(나중 전환 비용을 줄임) |
| 공용 v1.0 출시 후 | `develop/_shared/modules/README.md` 5.2절 절차로 모듈마다 전환. `news.<표>`는 호환 뷰로 한 릴리스 유지 |
| 확인 | 전환 후 RLS 스모크(314 + 모듈 스모크), local-news E2E 녹색 |
