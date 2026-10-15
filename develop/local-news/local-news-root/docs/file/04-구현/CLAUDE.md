# CLAUDE.md: 로컬뉴스 클라우드(가칭)

개발 에이전트 지침. 이 파일과 01~07장, `modules/` 기획서가 정본이다. 모든 사용자 노출 문구는 한국어다.

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절도) |
| 1-AI | AI·음성 작업이면 `AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |
| 1-MT | 테넌트·브랜딩·도메인 작업이면 `Multi-tenant_Theming/README.md`, `03_CODE_STRUCTURE.md`, `05_RUNTIME_AND_DOMAINS.md` |
| 2 | 이 폴더 `README.md`, `01_PRD.md`(기능 ID, 플랜 features 키) → `02_ARCHITECTURE.md`(경계, 잡, 9·10절) → `04_API.md`(계약) → `05_DATA_MODEL.md`(표, RLS, RPC, SQLSTATE) |
| 3 | 맡은 모듈의 기획서 `modules/M<n>_*.md`와 개발서 `docs/develop/local-news/modules/M<n>_*.md` |
| 4 | 화면 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `03_SCREENS_UX.md`(4절 템플릿 3종), `DASHBOARD_PATTERNS.md`. 독자 사이트에 3D 히어로를 쓰지 않는다(01장 D-11) |
| 5 | 자기 작업 행(`06_AGENT_PLAN.md` 2절)과 복사 금지(`07_SOURCE_MIGRATION.md` 4·6절) |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | 서버 파일에서만. 신문사 승인, 집계 증분, 웹훅 기록, 제보·정정 청구 접수, 구독 등록은 service 경유 Route Handler |
| 쓰기 경로 | 모든 쓰기는 `news.*` DEFINER RPC 또는 service. 사용자 세션으로 표에 직접 INSERT·UPDATE하지 않는다(05장 4절) |
| 공개 읽기 | 독자 사이트 공개 콘텐츠는 anon 키 서버 클라이언트(쿠키 없음)로만 읽는다. 기사 본문은 `news.read_article`만. 로그인 독자의 사용자 세션은 본인 데이터(독자 행, 내 댓글, 멤버십, 구독)에만 쓴다 |
| 사람 승인 | 기사 승인·게시는 사람(DESK)만. 서버·AI가 승인하지 않는다(NW006). AI가 도운 기사는 `ai_assisted`와 `ai_disclosure` 필수 |
| 크레딧 | AI 동작은 `consume_credits` 선차감 → 처리 → 실패 시 환불(`AI_ARCHITECTURE.md` 7장) |
| 코어 재정의 금지 | 인증, 조직, 크레딧, Toss, 웹훅, Storage, 감사, 잡, AI 게이트, 테넌트 해석은 코어·`core-tenancy`를 import만 |
| 수정 금지 | `D:/WorkSpace/platform/docs/products/_platform-core/`, `_supabase-modular/`의 다른 파일, `Multi-tenant_Theming/`. 필요하면 06장 6절 요청 |
| SQL | `2500_news.sql`이 정본, 모놀리스 `0003`은 변환 스크립트 결과(직접 수정 금지). SQL은 NW-06-001만 고친다 |
| 독자 결제 | 신문사 자기 Toss 가맹 키로 받는다. 키는 `core.encrypted_credentials`에만, 평문 저장·로그 금지(01장 D-4) |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정), `@theme`·`@custom-variant dark`. `tailwind.config.js`·v3 문법 금지. 지시에는 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드(`src/styles/tokens.css`, `src/components/ui/`). 테넌트는 의미 토큰 허용 목록만 덮어쓴다. 화면 작업은 NW-06-010 뒤 |

## 3. 디렉토리와 소유 경계

`02_ARCHITECTURE.md` 2절, `06_AGENT_PLAN.md` 1절 요약: 라우트 그룹 `(reader)`(테넌트 도메인, `_t/[host]/`), `(newsroom)`, `(ops)`, `(marketing)`. 공통모듈은 `src/modules/<newsroom-cms|reader-membership|ad-manager|notify-newsletter|community|distribution-seo|compliance-desk|search-analytics|local-life>/`이고 각 모듈은 `server/`, `components/`, `schema.ts`, `cache.ts`를 갖는다. 독자 사이트 하위 경로의 소유 작업은 06장 1절 표를 따른다. 워커는 `worker/src/handlers/<큐>/`, AI는 `apps/api/app/ai/products/news/`·`graphs/`, Dify 정의는 `infra/dify/`. 작업 표에 없는 디렉토리를 만지지 않는다.

## 4. 코어 사용 규칙

| 상황 | 쓰는 것 |
|---|---|
| 요청 진입 | `src/proxy.ts`가 Host로 그룹을 정하고 `resolve_tenant` 결과를 헤더로 넘긴다(클라이언트 헤더 무시). 편집국 Route Handler는 `requireSession('news')` 후 `news.is_newsroom(org, 역할)` |
| 테넌트 | `src/lib/tenancy/`의 `getTenant()`만. 테넌트 slug·org_id를 코드에 쓰지 않는다 |
| 캐시 | 태그는 `src/lib/cache/tags.ts`만(`news:<org>:home`, `news:<org>:article:<id>` 등). 게시·수정·게시 취소는 게시 파이프라인 잡이 무효화한다 |
| 잡 | `jobs.enqueue({ queue: 'news.publish'\|'news.newsletter'\|'news.ingest'\|'news.ai'\|'news.stats'\|'news.domain', idempotencyKey: 'job:news:<request_id>' })`(02장 4절) |
| 조회수 | `/api/r/view` → 서버 묶음 → `news.increment_article_views`(service). 클라이언트가 직접 올리지 않는다 |
| 감사 | 편집국 쓰기는 RPC 안에서 기록. 독자 행위는 감사하지 않는다(독자는 조직 멤버가 아님) |
| Storage | 경로 첫 폴더 = org_id(`public-assets/<org>/news/…`, `org-files/<org>/news/…`). 제보·정정 첨부는 서버 업로드만 |
| AI | 브라우저는 `/api/ai/*`, `/api/voice/*`만(편집국 호스트). Dify에는 대화 매핑만 넘긴다 |

## 5. 코드 규칙

| 항목 | 값 |
|---|---|
| 스택 | Next.js 16.2.x(App Router), React 19.2, TS strict, Tailwind CSS v4, shadcn/ui, Supabase(PostgreSQL 15), FastAPI(apps/api) + LangChain/LangGraph. 버전 고정·lockfile 커밋, `latest` 금지 |
| 렌더 | 독자 사이트는 ISR + 캐시 태그. 광고 슬롯은 크기 예약(CLS 0.1 이하). 팝업·전면광고 컴포넌트 금지 |
| 서체 | 서체 레지스트리 키만(Pretendard, Noto Serif KR, 본명조, 나눔명조). KoPub 기본값 금지(수정 금지 조건, 03장 4.7절) |
| 입력 검증 | 모든 경계 zod. RPC `fields` jsonb는 허용 키만(그 밖 NW015) |
| 타입 생성 | `pnpm db:types`(모놀리스 public) |
| 문구 | 오류 문구는 원인과 다음 행동. 01장 6절 금지 문구 통과 |

## 6. 테스트와 완료 조건

`06_AGENT_PLAN.md` 7절. 명령(저장소 루트 기준, 05장 9절):

```
cd D:/WorkSpace/platform/docs/products/_tools-sqlcheck
node check.mjs --vector mod <0000~0009> ../_supabase-modular/seed.sql ../../Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql ../_supabase-modular/migrations/2500_news.sql ../_supabase-modular/migrations/2500_news.sql
node check.mjs --vector mono ../local-news/supabase/monolith/migrations/0001_core_lite.sql ../local-news/supabase/monolith/migrations/0002_tenant_theming.sql ../local-news/supabase/monolith/migrations/0003_local_news_domain.sql ../local-news/supabase/monolith/seed.sql
node supabase/monolith/tests/run-smoke.mjs --target mono   # PASS=314 FAIL=0
pnpm lint && pnpm -r typecheck && pnpm -r build && pnpm test:e2e && pnpm test:perf
```

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4·6절 요약: `FOR ALL` 정책·브라우저 직접 쓰기, 공개 콘텐츠를 사용자 세션으로 읽기, 라벨 없는 기사형 광고, 필요적 게재사항 없이 공개, AI 단독 기사·AI 표시 누락, 보도자료를 자체기사로 분류, 제보·댓글 개인정보 노출, 계약 없는 타 매체 기사 게재, 조회수 클라이언트 증가, 클라이언트 테넌트 헤더 신뢰, 팝업·전면광고, 광고 없을 때 슬롯 접기, 실키 `.env` 커밋, 쿠키 역할 Mock.

## 인증 단계 규칙 (2026-10-15, 확정 결정 22)

정본 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`, 이 제품 반영은 01장 2·3·8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절, 07장 6절. 로그인 대상이 둘이다.

| 항목 | 편집국(`newsroom.<플랫폼>`) | 독자(신문사 도메인) |
|---|---|---|
| 가입 | 개설 신청 → 운영자 승인, 구성원은 초대 | 공개. 신문사마다 `news.readers` 행(조직 멤버 아님) |
| 지금 단계 | Stage A(Mock). 로컬 `.env.local`: `AUTH_MODE=mock`, `DEV_SEED_PASSWORD`. 배포 환경은 항상 `AUTH_MODE=live` | 같음 |
| 단계 순서 | A(NW-06-004) → G1 → B Google + 이메일·초대 메일(NW-06-052) → G2 → C 카카오·네이버 P2 선택(01장 D-17) | A(NW-06-023) → G1 → B 이메일(D-15) + Google(NW-06-053) → G2 → C1 카카오(NW-06-054)·C2 네이버(NW-06-055) P1 |
| 페르소나 | owner(publisher), admin(editor), member(reporter), viewer, outsider, no_app, suspended, ops, desk, contributor, ad_manager(05장 10절) | reader, reader_member, reader_other, anon |
| 분기 위치 | `AUTH_MODE`·제공자 목록을 읽는 코드는 `src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/`, `src/app/api/dev/login/`, 독자 `login/`에만 | 같음. 호스트 종류별 제공자 허용 검사(`error=provider`) |
| 금지 | 쿠키·localStorage 역할·플랜, `mock-auth`, 가짜 세션, 원격 Supabase에 개발 계정, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·로그에, 인증 모듈 밖 `AUTH_MODE`, 페르소나 이메일로 권한 분기, `next` 무검증, 독자를 조직 멤버로 추가 | 같음 |
| 단계 전환 | 에이전트가 단계를 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과`·`[DECISION] G2 통과`로 기록한 뒤 B·C 작업을 시작한다 | 같음 |

## 테넌트·법정 표기 규칙

| 항목 | 규칙 |
|---|---|
| 테넌트 해석 | `proxy.ts` → `resolve_tenant`만. 해석 실패·비활성 도메인은 오류 화면(플랫폼 브랜드로 기사를 보이지 않는다, 02장 10절) |
| 법정 푸터 | 필요적 게재사항 10개가 모두 있어야 독자 사이트를 연다. 청소년보호책임자 성명은 모든 독자 페이지 첫 화면 푸터에. 숨김 설정 없음 |
| 광고 구분 | 기사형 광고는 유형 `sponsored` + 라벨, 광고 소재는 라벨 필수. 정부·지자체 광고는 직판하지 않는다(NW013) |
| 자체기사 비율 | 보도자료·AI 보도자료 초안은 자체기사가 아니다. 주간 비율 30% 미만이면 대시보드 경고 |
| 정정 청구 | 접수 시 통지 기한(+3일)과 게재 기한(수용+7일)이 고정된다. 기한을 코드로 늦추지 않는다 |
| 선거 모드 | 여론조사 공표 금지 기간에 `is_poll` 기사 게시 거부(NW007) |

## 공통모듈 규칙

| 항목 | 규칙 |
|---|---|
| 경계 | 모듈은 자기 표만 쓴다. 다른 모듈은 `server/index.ts` 공개 함수나 잡으로만 부른다(`modules/README.md`) |
| 이벤트 | 별도 이벤트 버스 없음. 게시 후 처리 등은 잡(`news.post_publish` 등)으로 보낸다 |
| 추출 | 두 번째 제품이 쓰면 공용 스키마로 꺼낸다(`D:/WorkSpace/platform/docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 2·3장). 꺼내기 전에 다른 제품이 이 제품 코드를 복사하지 않는다 |
