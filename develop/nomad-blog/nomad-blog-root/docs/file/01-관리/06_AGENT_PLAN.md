# 06 에이전트 작업 계획: NOMAD Blog

작성일 2026-10-12. 작업 ID 접두사 `BL`은 `DB_CONVENTIONS.md` 1장 SQLSTATE 접두사와 같다. 경로는 `apps/nomad-blog/` 기준(제안), `workers/`와 `packages/blog-render/`는 모노레포 루트 기준이다. 모델 기준은 `docs/file/03-설계/공용코어/DOC_TEMPLATE.md` 1장: Fable(결제, 권한, RLS, 데이터 모델), Opus(기능 구현, API 연동, 테스트 설계), Sonnet(UI, 메인페이지, 컴포넌트, 문서), Haiku(보일러플레이트, 린트/타입, 문구, 반복 체크).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 4장) 작업 16개(BL-06-041~056)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 001·003(수용 기준 보강), 006(FastAPI 경유, 선행 045, `src/app/api/ai/` 소유 분할), 014(승인 확인), 015(그래프 호출), 019(규칙 파일), 021·022·023·024·027(선행에 044 추가), 026(`tokens.css` 소유를 042로 이전, 선행 추가), 028·032·037(수용 기준 보강)이다. 작업 수 56개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘어난 것이고, 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다. 2026-10-14 개정: 확정 결정 22(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md`)로 BL-06-004를 Stage A(Mock) 범위로 바꾸고 인증 단계 작업 3개(BL-06-057 B, 058 C1, 059 C2)를 8절에 더해 작업 수는 59개(모델 작업 58개 + 사람 1개)다. 003(`src/lib/auth/` 제외, 인증 env), 029·037(Mock 페르소나 실행), 032(금지 문자열)도 그 줄 안에서 고쳤다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 디렉토리는 한 작업만 만든다. 다른 작업은 그 디렉토리의 공개 인터페이스(`index.ts`)만 import |
| 공용 인터페이스 선행 | `src/server/*`의 타입 시그니처는 W0의 BL-06-003이 빈 모듈(`index.ts` + 타입)로 먼저 만든다. 이후 작업은 자기 디렉토리 안만 채운다 |
| 코어 불변 | `packages/core-*`, `_platform-core`, `_supabase-modular`의 다른 파일은 수정하지 않는다. 필요하면 6절 요청 |
| DB 변경 | `supabase/`는 BL-06-001만 쓴다. 다른 작업이 스키마 변경이 필요하면 BL-06-001 담당(Fable)에게 요청 |
| 테스트 | 각 테스트 작업은 `tests/<영역>/` 하위 고유 디렉토리를 소유 |
| AI 서비스 경계 | `apps/api/`는 BL-06-045가 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. blog 확장은 작업별로 나눈다: 048 `app/ai/products/blog/knowledge.py`, 049 `app/ai/products/blog/wiki_config.py`, 050 `app/ai/graphs/blog_post_draft.py`·`app/ai/compliance/blog.py`·`app/ai/products/blog/prompts/`, 051 `app/ai/tools/blog/` |
| API 하위 폴더 | `src/app/api/ai/`는 분할 소유: `keywords/`, `outline/`은 006, 그 밖(`chat`, `conversations`)은 046. `src/server/ai/`도 분할: `credits.ts`, `purposes.ts`, `schemas/`는 006·015, `gateway/`, `pricing.ts`는 046 |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(AI-R1~R7) |
| 언어 중립 파일 | `packages/blog-rules/`는 BL-06-047 소유. FastAPI는 빌드 때 복사해 읽기만 하고 TS 컴플라이언스(019)도 같은 파일을 읽는다 |
| 사람 작업 | BL-06-043(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(021~024, 026, 027, 049, 052, 055)은 BL-06-044(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:48`) |
| 비밀의 AI 유입 금지 | 채널 비밀번호·세션 쿠키·제휴 키·`credential_id`는 그래프·채팅 입력과 프롬프트에 넣지 않는다. 입력 스키마에 필드를 두지 않고 BL-06-056이 검사한다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| BL-06-001 | DB 조각 적용, 모놀리스 사본 동기화, 타입 생성 | `supabase/`, `src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, `gen types --schema core,blog` 결과 커밋, `--vector` 체커 OK(AI 코어 0008~0009 포함), `ai_routing_settings`(app blog) 12행과 플랜 AI 키 6개 확인. 이유: RLS·데이터 모델 | 05장, SM 리뷰 5장 #6 |
| BL-06-002 | 모듈러 → 모놀리스 변환 스크립트와 SQL 체커 CI 등록 | `scripts/sql/` | BL-06-001 | P1 | S | Haiku | 스크립트 결과가 `0002_blog_domain.sql`과 diff 0, CI에서 mod/mono 체커 OK. 이유: 반복 작업 | `DB_CONVENTIONS.md` 12장 |
| BL-06-003 | 앱 골격, `lib/env.ts`(zod, 누락 시 기동 실패, AI 변수·인증 단계 변수 포함 02장 8·9절), Supabase 3계층 클라이언트, 응답 봉투, `src/server/*` 인터페이스 뼈대 | `src/lib/`(`src/lib/auth/`는 BL-06-004 소유), `src/server/*/index.ts`(타입만) | 없음 | P0 | M | Opus | 필수 env 1개를 지우면 `next build`와 워커 기동이 실패. 0행 UPDATE를 오류로 던지는 쓰기 래퍼 존재. 이유: 다파일 구성 | SM #3, #8, #10, #12; YSM #10 |
| BL-06-004 | Stage A 인증(확정 결정 22): 인증 모듈 경계 `src/lib/auth/`(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`, AUTH_ROADMAP 3.1·3.2절), Mock 로그인(`POST /api/dev/login`·`logout`, `/login` 개발용 패널, 모든 화면 상단 배지 `MOCK AUTH · 로컬 전용`), `scripts/dev/seed-users.mjs` + 제품 훅 `seed-users.blog.mjs`(05장 10절), 가드(기동 env 검증, 판정 거짓이면 404·패널 미렌더, 배포 빌드 실패), `src/proxy.ts` 가드, `requireSession('blog')`, `finishLogin` 부트스트랩, 프로필 없음 → 로그아웃, `email_confirmed_at` 서버 가드. 이메일 가입·비밀번호 재설정 화면과 Google 버튼·`/auth/callback` 라우트는 B(BL-06-057)로 옮겼다 | `src/proxy.ts`, `src/app/(auth)/`(`signup/`, `reset-password/` 제외), `src/lib/auth/`, `src/app/api/dev/`, `src/server/session/`, `src/components/dev-auth/`, `scripts/dev/` | BL-06-003 | P0 | M | Fable | 비로그인 `/dashboard` → `/login`, 웹훅·`/r` 통과. `owner` 페르소나 로그인 → `session_context('blog')` entitled=true·`plan_code='free'`·크레딧 20. `no_app` 로그인 → `finishLogin` 부트스트랩 1회(재로그인 3회 뒤 원장 행 수 같음, 모듈러). `outsider`로 owner 조직 posts·channel_accounts·post_publications 0행. `suspended` 403. `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404, 원격 Supabase URL이면 시드 스크립트 exit 1, 시드 2회 실행 시 크레딧 지급 1회. 쿠키·localStorage 역할/플랜 코드 0(쿠키 역할 Mock 금지, 허용 Mock은 AUTH_ROADMAP 2장). 이유: 인증·권한 | SM #4, #6; YSM #5, #8; AUTH_ROADMAP 2장 |
| BL-06-005 | features 해석, 월 발행 한도(`monthly_post_usage`), 채널 한도, 예약·자동 삽입·품질 모드 게이팅 | `src/server/entitlements/` | BL-06-001, BL-06-003 | P0 | M | Fable | Free 11번째 발행 402 BL004, Free 3번째 채널 403, seed 구버전 키(`channels`) 호환. 이유: 플랜 권한 | YSM #9, 01장 4.3절 |
| BL-06-006 | AI 크레딧 단가표, purpose 맵, 동기 AI 라우트(keywords, outline, rewrite, tags, bc message) | `src/server/ai/credits.ts`, `src/server/ai/purposes.ts`, `src/app/api/ai/keywords/`, `src/app/api/ai/outline/`, `src/app/api/posts/[id]/rewrite/`, `src/app/api/posts/[id]/tags/` | BL-06-003, BL-06-045 | P0 | M | Opus | LLM 실패 시 환불 행 1개 + 502 AI_FAILED. 요청 바디로 모델 지정 불가. 폴백 데이터 반환 없음. 호출은 FastAPI `/tools/blog/assist` 경유이고 웹·워커에 LLM 키가 없다 | SM #10; YSM #7 |
| BL-06-007 | TipTap 확장: AffiliateCard 노드, DisclosureBlock 잠금 노드, 자동 저장 훅(2초, version 충돌) | `src/features/editor/` | BL-06-003 | P0 | L | Opus | 잠금 블록 삭제 키 입력이 무시됨. 두 탭 동시 편집 시 충돌 안내. 붙여 넣은 `<script>`가 JSON에 남지 않음 | 01장 BL-F-017, SM #14 |
| BL-06-008 | `packages/blog-render`: body_json → 채널별 HTML, sanitize, 대가성 문구 삽입(제공자 집합, 도메인 스캔), `rendered_hash`, AI 활용 표기 | `packages/blog-render/` | BL-06-003 | P0 | M | Opus | 제휴 카드 1개 원고의 출력 첫 블록이 문구. 매핑 없는 `link.coupang.com` 링크만 있어도 문구 삽입. 같은 입력 같은 해시 | 확정 결정 12, BL-F-024 |
| BL-06-009 | 채널 연결 API: 자격증명 vault 저장, 워드프레스 SSRF 차단 fetch, 동의 RPC 연결, 해제 | `src/server/channels/`, `src/app/api/channels/` | BL-06-004, BL-06-005 | P0 | M | Fable | `https://10.0.0.1` 거부, 응답에 비밀 없음, DB에 평문 비밀 없음, 동의 전 naver 연결 409 BL005. 이유: 자격증명 | SM #5, #7; YSM #2, #4, #13 |
| BL-06-010 | 워커 런타임: `runWorker`, 브라우저 풀(4), 채널 잠금, 타임아웃, 간격·일일 상한 재배치, 하트비트 취소 | `workers/blog-worker/src/runtime/` | BL-06-001, BL-06-003 | P0 | M | Opus | 같은 계정 잡 2개가 동시에 브라우저를 열지 않음. 180초 초과 잡은 컨텍스트 종료 후 실패. Next import 없음 | SM #3, #7, #8, #10; YSM #11, #13 |
| BL-06-011 | 네이버 블로그 게시 어댑터(CA + YSM 스마트에디터 절차 이식, 셀렉터 상수 분리, CAPTCHA 정지, unconfirmed 판정) | `workers/blog-worker/src/channels/naver/` | BL-06-010, BL-06-008 | P0 | L | Opus | 녹화 픽스처에서 제목·본문·태그 10개 입력과 URL 파싱 통과. 로그인 페이지 감지 시 needs_reauth, 재시도 없음. 봇 우회 코드 없음 | YSM #12, 07장 2절 |
| BL-06-012 | 티스토리 게시 어댑터 | `workers/blog-worker/src/channels/tistory/` | BL-06-010, BL-06-008 | P0 | M | Opus | 픽스처 통과, 실패 분기는 네이버와 같음 | 07장 2절 |
| BL-06-013 | 워드프레스 REST 어댑터(태그, 대표 이미지, Yoast 메타 선택) | `workers/blog-worker/src/channels/wordpress/` | BL-06-010, BL-06-008 | P0 | S | Opus | 로컬 WordPress 컨테이너에 발행 성공, 401은 채널 error | 07장 2절 |
| BL-06-014 | 발행 오케스트레이션: publish/cancel/retry/resolve 라우트, 멱등, 채널 정책 경고, 잡 연결, 워커 발행 핸들러의 상태 반영 | `src/server/publish/`, `src/app/api/posts/[id]/publish/`, `src/app/api/publications/`, `workers/blog-worker/src/handlers/publish/` | BL-06-005, BL-06-008, BL-06-010, BL-06-046 | P0 | M | Fable | 같은 request_id 2회 → 행·잡 1개. 네이버+쿠팡 경고 미확인 409 BL006. 예약 취소 시 core 잡 canceled. 그래프로 만든 원고는 승인 전 발행·예약 409 `AI_APPROVAL_REQUIRED`. 이유: 상태 머신·권한 | SM #4, #9; YSM #6 |
| BL-06-015 | 생성 잡 핸들러(잡 토큰으로 그래프 `blog.post_draft` 실행, 결과 zod 재검증·저장, 자동 제휴 삽입 호출). 프롬프트는 그래프(BL-06-050)가 소유한다 | `src/server/ai/schemas/`, `src/app/api/posts/[id]/generate/`, `workers/blog-worker/src/handlers/generate/` | BL-06-006, BL-06-016, BL-06-050 | P0 | M | Opus | 체험 메모 없는 원고에 1인칭 사용 경험 문장이 없음(평가 세트 20건). 스키마 불일치 1회 재시도 후 실패·환불. 워커에 LLM 키 0, 그래프 호출은 잡 토큰(running 잡)만 | 01장 6.5절, YSM #7 |
| BL-06-016 | 제휴 API: 계정 연결, 쿠팡 검색, 링크+매핑 생성·삭제, 수동 URL(텐핑·네이버쇼핑 커넥트), 자동 추천, 클릭 통계 | `src/server/affiliate/`, `src/app/api/affiliate/`, `src/app/api/posts/[id]/affiliate-links/` | BL-06-009 | P0 | M | Opus | 카드 삽입 시 매핑 1행·단축 코드 1개. 키가 응답에 없음. 수익 열은 데이터 없으면 숨김 | 확정 결정 12, BL-F-020~027 |
| BL-06-017 | 브랜드커넥트 API: 계정(자격증명 공유), 동의(버전 감사), 철회(잡 취소), 지원 요청(5/시간, 20/일), 스캔 요청(4/일) | `src/server/brandconnect/`, `src/app/api/brandconnect/` | BL-06-009, BL-06-016 | P0 | M | Fable | member 동의 403, 동의 없는 지원 42501, 6번째 지원 429, 철회 후 대기 잡 canceled. 이유: 권한·위험 동의 | 확정 결정 12, 01장 6.4절 |
| BL-06-018 | 브랜드커넥트 워커: scan/apply/sync(Playwright, 셀렉터 상수, 제출 확인, CAPTCHA 정지) | `workers/blog-worker/src/handlers/brandconnect/` | BL-06-010, BL-06-017 | P0 | L | Opus | 픽스처에서 제출 성공 시 submitted + submitted_at, 확인 실패는 failed. 상태 전이 위반 없음 | `NOMAD Shorts Maker/src/skill/playwright-engine/brand-connect.ts` |
| BL-06-019 | 컴플라이언스 연결: blog 규칙 사전(가상 후기·수익 보장 등), core check 호출, 결과 저장, WARN 확인 라우트 | `src/server/compliance/`, `src/app/api/posts/[id]/compliance/` | BL-06-006, BL-06-047 | P0 | S | Opus | "내돈내산" 포함 정보형 원고 → WARN 이상. LLM 오류 → WARN. 한글 경계 매칭 테스트 통과. 규칙 사전은 `packages/blog-rules/banned.json`을 읽는다 | `SHARED_MODULES.md` 13장 |
| BL-06-020 | `/r/[code]` 리다이렉트(레이트 리밋, IP 해시, 봇 UA 표시) | `src/app/r/` | BL-06-003 | P0 | S | Opus | 302 + 클릭 1행, 61번째/분 429, 원문 IP 미저장 | `CORE_SPEC.md` 13.3절 |
| BL-06-021 | 대시보드, 원고 목록, 캘린더 UI(서버 컴포넌트 + 실데이터) | `src/app/(app)/dashboard/`, `src/app/(app)/posts/page.tsx`, `src/app/(app)/calendar/`, `src/components/dashboard/` | BL-06-014, BL-06-044 | P0 | L | Sonnet | 더미 배열 없음, 빈 상태 문구, 375px 레이아웃. 파일 400줄 이하 | SM #9, YSM #14 |
| BL-06-022 | 에디터 화면, 보조 패널 5탭, 발행 시트 UI | `src/app/(app)/posts/[id]/`, `src/app/(app)/posts/new/`, `src/components/editor-shell/` | BL-06-007, BL-06-014, BL-06-044 | P0 | L | Sonnet | AI 버튼마다 예상 크레딧, 잡 진행률 Realtime, 402/409 화면 03장 5절 문구. `/posts/[id]/review`(승인 화면)와 도우미 탭·마이크 장착(BL-06-052, 054 컴포넌트 import)을 포함 | 03장 3.2~3.3절, SM #14 |
| BL-06-023 | 채널 화면과 위험 동의 모달(스크롤 완독, 체크 3개, 입력 확인) | `src/app/(app)/channels/`, `src/components/consent/` | BL-06-009, BL-06-044 | P0 | M | Sonnet | 고지문 끝까지 스크롤 전 체크 비활성, member는 요청 안내만 | 01장 6.4절 |
| BL-06-024 | 제휴 통계 화면, 브랜드커넥트 화면 | `src/app/(app)/affiliate/`, `src/app/(app)/brandconnect/` | BL-06-016, BL-06-017, BL-06-044 | P0 | M | Sonnet | 수익 데이터 없으면 열 숨김, 지원 상태 칩 6종 | 03장 3.6~3.7절 |
| BL-06-025 | 결제: 주문 생성, confirm, 빌링키, billing 화면, PM001 처리(운영 알림 + Toss 취소) | `src/app/api/billing/`, `src/app/(app)/billing/`, `src/server/billing/` | BL-06-004 | P0 | M | Fable | 금액을 클라이언트에서 받지 않음, confirm 2회 → 지급 1회, PM001 시 `fail_payment_order` 호출 후 취소 호출 | SM #1, #2; 01장 4장 |
| BL-06-026 | 랜딩, 가격, 약관, 개인정보처리방침 | `src/app/(marketing)/` | BL-06-003, BL-06-044, BL-06-055 | P0 | M | Sonnet | 03장 4절 토큰·와이어프레임 반영(`tokens.css`는 BL-06-042 소유), 히어로에 BL-06-055 장착, 금지 문구 0건, 체크리스트 12항목 통과 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/file/03-설계/디자인/REFERENCES.md:16-23`). | 03장 4절 |
| BL-06-027 | 설정: 대가성 문구 편집(끄기 없음), 멤버, 활동 기록 | `src/app/(app)/settings/`(`login-methods/`는 BL-06-058) | BL-06-016, BL-06-044 | P1 | S | Sonnet | 이해관계 단어 없는 문구 저장 422, owner/admin 외 접근 403 | BL-F-006, BL-F-024 |
| BL-06-028 | RLS/권한 회귀 테스트(05장 9절 69항목 + 추가, AI 코어 포함) | `supabase/tests/` | BL-06-001 | P0 | M | Fable | 모듈러·모놀리스 모두 0 실패, CI 필수 단계. 추가 항목: 대화·메시지 본인만, `ai_chunks` SELECT 차단, 타 조직 `ai_documents`·`wiki_pages`·`ai_runs` 0행, 사용자 `resolve_ai_route`·`match_ai_chunks` 42501 | `SECURITY_BASELINE.md` 15장, SM #15, YSM #15 |
| BL-06-029 | 결제 E2E(Toss 테스트 키): Pro 구독, 크레딧팩, 중복 confirm, 금액 위조 | `tests/e2e/billing/` | BL-06-025 | P0 | M | Opus | 4개 시나리오 통과, 위조 금액 PM001. Mock 페르소나 `owner` storageState로 실행(AUTH_ROADMAP 2.1절) | SM #2, #3 |
| BL-06-030 | 발행·어댑터 통합 테스트(WordPress 컨테이너, 네이버·티스토리 녹화 픽스처, 중복·취소·unconfirmed) | `tests/integration/publish/`, `workers/blog-worker/test/` | BL-06-011~014 | P0 | M | Opus | 중복 발행 0, unconfirmed 자동 재시도 0, 문구 포함 100% | BL-F-043~047 |
| BL-06-031 | 렌더러·sanitize·대가성 문구 단위 테스트 | `tests/unit/render/` | BL-06-008 | P0 | S | Opus | XSS 벡터 30종 제거, 제공자 조합 문구 중복 없음 | SM #14 |
| BL-06-032 | CI: tsc, lint, build, 금지 문자열 검사(`x-internal-call`, `dangerouslySetInnerHTML`, `Math.random()` 지표, 쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈 밖의 `AUTH_MODE` 참조(쿠키 역할 Mock 금지, 허용 Mock은 AUTH_ROADMAP 2장), `tailwind.config.*`, `@tailwind base`, LLM·음성 키의 `NEXT_PUBLIC_` 접두) | `.github/workflows/`, `eslint.config.mjs` | BL-06-003 | P0 | S | Haiku | 금지 문자열 PR이 실패, 타입 오류 0. `src/lib/auth/`·`src/app/(auth)/`·`src/app/auth/`·`src/app/api/dev/` 밖의 `AUTH_MODE`·`AUTH_PROVIDERS` 참조 PR 실패, 빌드 검사 `AUTH_MODE=mock VERCEL_ENV=production npm run build` 실패 확인 | SM #5, #11, #15; YSM #2(정리) |
| BL-06-033 | 원본 아카이브와 이식 기록(태그, 이식 파일 목록, 잔해 정리 체크리스트) | `docs/migration/` | 없음 | P1 | S | Sonnet | 07장 5절 체크리스트 완료 기록, 태그 생성은 사용자 승인 후 | YSM #1, #2; SM #13 |
| BL-06-034 | 관측: 구조화 로거(비밀 마스킹), 실패 스크린샷 7일, 셀렉터 미발견 운영 알림 | `src/lib/logger/`, `workers/blog-worker/src/observability/` | BL-06-010 | P1 | S | Opus | 로그에 쿠키·비밀번호 0건(테스트), 스크린샷 만료 삭제 | SM #14; YSM #13 |
| BL-06-035 | 키 점검: 원본 `.env` 키 목록 대조, 공유 키 교체, `CREDENTIALS_KEY` 버전 교체 절차 | `ops/secrets/`(문서·스크립트 없음) | 없음 | P0 | S | Opus | 교체 대상 목록과 완료 기록, 원본 키 재사용 0 | YSM #3 |
| BL-06-036 | 문구·금지 표현 체크리스트 반복 점검(UI, 이메일, 프롬프트) | `src/content/copy/` | BL-06-026 | P1 | S | Haiku | 01장 6.5절 목록 대비 위반 0 | 01장 6.5절 |
| BL-06-037 | 생성 흐름 E2E: 키워드 → 그래프 생성 → 승인 → 검사 → 워드프레스 발행, 크레딧·환불 검증 | `tests/e2e/generate/` | BL-06-015, BL-06-019, BL-06-030, BL-06-046 | P0 | M | Opus | 성공 시 크레딧 5(그래프 정액, 빠름), LLM 실패 주입 시 원장 환불 1행, 승인 전 발행 409 `AI_APPROVAL_REQUIRED`. Mock 페르소나 storageState로 실행(`owner` 기본, `viewer` 발행 403, `outsider` 타 조직 원고 0행) | BL-F-003, BL-F-011 |
| BL-06-038 | 데이터 내보내기 잡(Markdown/HTML ZIP, exports 버킷) | `workers/blog-worker/src/handlers/export/`, `src/app/api/exports/` | BL-06-010 | P1 | S | Opus | 100편 60초 이내, 서명 URL 7일 | BL-F-007 |
| BL-06-039 | Phase 2: n8n/Make 브릿지와 발신 웹훅 노드 등록(automation-core) | `src/server/automation/` | BL-06-014 | P2 | M | Opus | 서명 없는 콜백 401, `post.published` 이벤트 HMAC | SM #11 |
| BL-06-040 | Phase 2: 인스타그램 카드 포스팅(sns-uploader 소비, OAuth state) | `workers/blog-worker/src/channels/instagram/` | BL-06-010 | P2 | M | Opus | 캡션 첫 줄 대가성 문구, 토큰은 vault | BL-F-049 |
| BL-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Primer 주·Atlassian 보조, 채팅은 Astryx 패턴 확인 후, 랜딩은 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.10절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D-17). 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/file/03-설계/디자인/REFERENCES.md:101` nomad-blog 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| BL-06-042 | 디자인 시스템 2단계: `tokens.css`(Tailwind CSS v4 `@theme`, 라이트/다크, 03장 4.3절 토큰 플랜) + 기본 컴포넌트·배리언트(03장 3.10절 표) + `/dev/components` 미리보기 | `src/styles/tokens.css`, `src/components/ui/`, `src/app/dev/components/` | BL-06-003, BL-06-041 | P0 | M | Sonnet | `@theme` 토큰 이름이 03장 3.10절과 같고 hex 직접 사용 0(린트), `tailwind.config.js` 0, 기본 컴포넌트 전부 라이트/다크에서 렌더. 컴포넌트마다 `DESIGN_SYSTEM.md` 8장 템플릿으로 1개씩 지시. 프로덕션 빌드에 `/dev/components` 제외 | DESIGN_SYSTEM 4장 2단계 |
| BL-06-043 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | BL-06-042 | P0 | M | 사람(보조 Sonnet) | 03장 3.10절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1(문구 노랑 위 먹 글자 포함)·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| BL-06-044 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | BL-06-043 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| BL-06-045 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, blog 설정(app, 컬렉션 이름), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/blog/`, `app/ai/compliance/blog.py`, `app/ai/products/blog/knowledge.py`·`wiki_config.py`·`prompts/` 제외), `apps/api/tests/platform/` | BL-06-001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 원고 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 필수 변수 누락 시 기동 실패. 이유: 서명 토큰·조직 격리 | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| BL-06-046 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰·잡 토큰 발급, 정산 크론, AI 단가, 온보딩 국외 이전 동의, 발행 전 승인·반려(`ai-approve`, `ai-reject`) | `src/app/api/ai/`(`keywords/`, `outline/` 제외), `src/app/api/internal/`, `src/app/api/onboarding/`, `src/app/onboarding/`(`terms/`는 BL-06-057), `src/app/api/posts/[id]/ai-approve/`, `src/app/api/posts/[id]/ai-reject/`, `src/server/ai/gateway/`, `src/server/ai/pricing.ts` | BL-06-003, BL-06-004, BL-06-045 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 잡 토큰은 running 잡에만(다른 상태 409), 동의 시 `ai_org_settings`와 감사 고지문 버전 일치, `ai-approve`는 FAIL·미검사 409 `BL003`, 정산 크론 뒤 10분 넘은 `settled_at is null` 0. 이유: 크레딧·권한·동의 | 01장 BL-F-052, 055, 058, 059 |
| BL-06-047 | 공용 출력 규칙 파일: 금지 표현·대화 규칙(`banned.json`), 한글 경계 규칙, TS·Python 로더 | `packages/blog-rules/` | 없음 | P0 | S | Sonnet | 01장 6.5·6.7절 목록과 일치(표현 30개 이상, 제안), `\b` 미사용 한글 경계 테스트 20건, 대가성 표기 회피·수익·순위 보장·가상 후기 요청 패턴 포함, TS와 Python 로더 결과 동일 | 01장 BL-F-060 |
| BL-06-048 | RAG 색인: 조직 자료 컬렉션 `blog-materials`(oss-embed), 업로드·삭제 API, 색인 잡 `blog.ai.rag_ingest`, 문서 수 한도, 검색 평가셋 30문항 | `apps/api/app/ai/products/blog/knowledge.py`, `src/app/api/materials/`, `apps/api/tests/blog/retrieval/` | BL-06-045 | P0 | M | Opus | 재현율@8 0.8 이상(제안), 다른 조직 컬렉션 요청 42501, 한도 초과 403 `PLAN_LIMIT`, 같은 `content_hash` 409, `contains_pii` 자료는 위키 대상 제외, 컬렉션당 임베딩 모델 1종, 삭제 시 청크 0, 색인 실패 환불 1행 | 01장 BL-F-053 |
| BL-06-049 | 토픽·키워드 위키: 자료 → 위키 ingest(draft), 편집·게시·이력·lint 화면과 API, 주 1회 lint 잡 | `apps/api/app/ai/products/blog/wiki_config.py`, `src/app/api/wiki/`, `src/app/(app)/wiki/`, `src/components/wiki/` | BL-06-044, BL-06-048 | P0 | M | Opus | 새 페이지 draft, 사람 소유 표시 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, Free 조직 403 `PLAN_REQUIRED`, lint 결과 화면, 쓰기 감사 1행, `contains_pii` 자료에서 만든 페이지 0 | 01장 BL-F-054, LLM_WIKI 3장 |
| BL-06-050 | LangGraph 그래프 `blog.post_draft`(keyword → retrieve → draft → affiliate_check → seo_check → compliance → approve), 체크포인트, 실행 기록, 출력 스키마, 프롬프트 | `apps/api/app/ai/graphs/blog_post_draft.py`, `apps/api/app/ai/compliance/blog.py`, `apps/api/app/ai/products/blog/prompts/`, `apps/api/tests/blog/graph/` | BL-06-045, BL-06-047, BL-06-048 | P0 | L | Opus | 생성 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps` 7행. 체험 메모 없는 원고에 1인칭 경험 문장 0(평가셋 20건을 상용·오픈소스 경로 모두). 매핑 없는 제휴 링크 경고 기록. 출력에 대가성 문구 블록이 없고 LLM이 문구를 쓰거나 지우지 않음. compliance에 걸린 구간만 1회 재작성. `approve`에서 interrupt 후 재개하면 run `succeeded`, 반려하면 `canceled`. 입력 스키마에 비밀 필드 0 | 01장 BL-F-051, 052, 060 |
| BL-06-051 | Dify `blog-chat`(질문 분류, HTTP 노드)과 `/tools/answer` blog 확장(원고 컨텍스트 로더, 모드 write, 마스킹, compliance 후처리), `/tools/blog/assist`, 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/blog/`, `apps/api/tests/blog/chat/` | BL-06-046, BL-06-048 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `post_id` 403, 답변 출처 1개 이상 또는 `no_source`, 평가셋 금지 응답 0(대가성 표기 회피·가상 후기·보장 요청 포함), DSL에 키 0, 외부 지식 노드 0 | 01장 BL-F-055, 060, 04장 6.2절 |
| BL-06-052 | 도우미 채팅 패널과 대화 목록, 자료 화면(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 원고 바인딩, 에디터에 넣기) | `src/components/ai-chat/`, `src/app/(app)/assistant/`, `src/app/(app)/materials/`, `src/components/materials/` | BL-06-044, BL-06-046, BL-06-048 | P0 | L | Sonnet | 03장 3.9절 구성, 에디터 320px 패널·375px 전체 화면, `aria-live`, 402 충전 모달, 대체·근거 없음·환불 상태 표시, "에디터에 넣기" 실행 취소, 자료 표 상태 4종과 한도(7/10) 표시. 에디터 쉘 장착은 BL-06-022 파일에 1줄 요청 | 01장 BL-F-053, 055, 03장 5절 |
| BL-06-053 | 음성 대화: `/api/voice/*`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기 | `src/app/api/voice/`, `src/components/voice/` | BL-06-046, BL-06-052 | P0 | M | Opus | 고지 미확인 STT 403, 채팅 질문 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지만 | 01장 BL-F-057 |
| BL-06-054 | 음성 받아쓰기 초안: 에디터 마이크 바, 변환 텍스트 수정 후 커서 삽입·초안 메모 전달 | `src/components/dictation/` | BL-06-007, BL-06-022, BL-06-053 | P0 | S | Sonnet | 5분 자동 중지, 수정 후 삽입(실행 취소 가능), 오픈소스·ElevenLabs 두 경로 동작, 받아쓴 체험 메모도 50자 규칙(BL-F-012) 적용, 고지 확인 전 마이크 비활성 | 01장 BL-F-056 |
| BL-06-055 | 3D 히어로: 원고 시트 → 채널 카드(PC·태블릿), 시트 1장 접힘(모바일), 정지 이미지 대체, 성능 예산 | `src/components/hero3d/`, `public/hero/` | BL-06-044 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 3D 안 글자 0, 종이비행기·파티클 0 | 01장 BL-F-061, 03장 4.6절 |
| BL-06-056 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 강제 오픈소스, 선차감·정산·환불, 승인 전 발행 409, 라우팅 seed 스냅샷, 비밀의 AI 입력 유입 검사) | `apps/api/tests/blog/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | BL-06-046, BL-06-050, BL-06-051, BL-06-053, BL-06-054 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 12행 × 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, 승인 전 발행 409, 채널 비밀 문자열이 그래프 입력·프롬프트·로그에 0, 원장 drift 0, CI 실패 시 머지 차단. 이유: AI 보안 경계 | SECURITY_BASELINE 16장 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | BL-06-001, 003, 033, 035, 041 | 5 | 없음 | DB 조각 적용(AI 기본값 포함), 타입, 앱 골격, 아카이브·키 점검, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | BL-06-002, 004, 007, 008, 010, 020, 032, 045, 047 | 9 | W0 | 인증, 에디터 확장, 렌더러, 워커 런타임, `/r`, CI, AI 서비스 설치, 공용 출력 규칙 |
| W1-D | BL-06-042 → 043 → 044(직렬) | 1 | 003, 041 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | BL-06-005, 006, 009, 011, 012, 013, 025, 028, 031, 046, 048 | 11 | W1(각 선행) | 게이팅, 단건 AI 라우트(FastAPI 경유), 채널 연결, 어댑터 3종, 결제, RLS·렌더 테스트, AI 게이트, RAG 색인 |
| W3 | BL-06-014, 016, 019, 023, 029, 034, 049, 050, 051, 055 | 10 | W2, 화면은 044 | 발행 오케스트레이션(승인 확인), 제휴, 컴플라이언스, 채널 화면, 결제 E2E, 위키, 그래프, Dify 채팅, 3D 히어로 |
| W4 | BL-06-015, 017, 021, 022, 026, 027, 030, 038, 052 | 9 | W3 | 생성 잡(그래프 연결), 브랜드커넥트 API, 앱 화면, 랜딩, 설정, 발행 통합 테스트, 채팅 패널·자료 화면 |
| W5 | BL-06-018, 024, 036, 037, 053 | 5 | W4 | 브랜드커넥트 워커와 화면, 문구 점검, 생성 E2E, 음성 대화 |
| W6 | BL-06-054 → 057(G1 통과 후) → 056(직렬) | 1 | W5, 057은 G1(054 완료가 G1 조건 1에 들어감). 056과 037·029의 B 구성 재실행은 057 완료를 기다린다 | 음성 받아쓰기, Stage B Google 로그인(공개 베타 필수), AI·음성 보안 회귀. **MVP 완료** |
| W7 | BL-06-039, 040, 058·059(G2 통과 후) | 4 | MVP 출시, 058·059는 G2 | Phase 2, Stage C1 카카오·C2 네이버 로그인 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 13 | 22.4% | 27 / 108 = 25.0% |
| Opus | 29 | 50.0% | 53 / 108 = 49.1% |
| Sonnet | 13 | 22.4% | 25 / 108 = 23.1% |
| Haiku | 3 | 5.2% | 3 / 108 = 2.8% |
| 합계 | 58 | 100% | 108 |

비율은 모델 작업 58개 기준이다(2026-10-14 인증 단계 작업 057 Fable M, 058 Opus S, 059 Fable M 포함, 8절). 사람 작업 1개(BL-06-043, M)는 비율에서 뺐다. 2026-10-14 이전(55개)은 Fable 20.0%, Opus 50.9%, Sonnet 23.6%, Haiku 5.5%였다. 2026-10-13 이전(40개)은 Fable 20.0%, Opus 55.0%, Sonnet 17.5%, Haiku 7.5%였다. Fable은 데이터 모델, RLS, 결제, 인증, 자격증명, 크레딧 차감 경로에 더해 AI 보안 경계(서명 토큰 검증 045, AI 게이트의 선차감·정산·동의·승인 046, AI 회귀 056)를 맡는다. 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 패널·3D 히어로·디자인 시스템 컴포넌트는 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

| 리뷰 5장 작업 | 흡수한 작업 ID | 비고 |
|---|---|---|
| SM #1 크레딧 RPC 봉쇄 | 코어(0003) + BL-06-028, BL-06-025 | blog는 크레딧 함수를 만들지 않음 |
| SM #2 결제 경로 단일화 | BL-06-025, BL-06-029 | |
| SM #3 백그라운드 서비스 클라이언트, `x-internal-call` 제거 | BL-06-003, BL-06-010, BL-06-014 | |
| SM #4 인증 가드, Mock 로그인, OAuth state, 키 폴백 | BL-06-004, BL-06-009 | 쿠키 역할 Mock 금지, 허용 Mock은 AUTH_ROADMAP 2장(BL-06-004 Stage A) |
| SM #5 빌드 복구 | BL-06-032 | 새 저장소, tsc 게이트 |
| SM #6 제품 경계·스키마 통합 | BL-06-001 | 확정 결정 1로 경계 확정 |
| SM #7 파이프라인 재설계 | BL-06-010 | blog 잡은 core.jobs 단일 단계. video 파이프라인은 shortsflow 소관 |
| SM #8 zod 입력 검증, `getCurrentOrg` | BL-06-003, BL-06-004 | 세션 컨텍스트로 대체 |
| SM #9 대시보드 실데이터 | BL-06-021 | |
| SM #10 AI 클라이언트 단일화, env 검증 | BL-06-006, BL-06-003 | |
| SM #11 AIContentGen 내부 호출, 콜백 서명 | BL-06-039 | DistroKid는 video 소관 |
| SM #12 YouTube 스트리밍, Redis lazy | 해당 없음 | video 소관. blog는 Redis를 쓰지 않음 |
| SM #13 루트 문서 정리 | BL-06-033 | 원본은 아카이브만 |
| SM #14 로깅 정리, sanitize | BL-06-034, BL-06-007, BL-06-031 | |
| SM #15 통합 테스트·CI | BL-06-028, BL-06-032 | |
| YSM #1 아카이브 태그와 방향 결정 | BL-06-033 | 방향은 "모듈 이식"으로 결정됨(README 3장) |
| YSM #2 gitignore, 잔해 삭제 | BL-06-033 | 원본 폴더 수정은 사용자 승인 후 |
| YSM #3 키 점검·교체 | BL-06-035 | |
| YSM #4 OAuth state 재구현 | BL-06-009(코어 oauth 사용) | |
| YSM #5 네이버 로그인 `naver_id` 매핑 | BL-06-004, BL-06-059 | MVP 미도입. 확정 결정 22로 C2(G2 후)에서 도입, 이메일 자동 병합 금지(`email_in_use`) |
| YSM #6 태스크 소유권 검증 | BL-06-014, BL-06-028 | core.jobs RLS |
| YSM #7 모델 허용 목록, LLM 단일 모듈 | BL-06-006, BL-06-015 | |
| YSM #8 인증 의존성 블로킹 | BL-06-004 | FastAPI 폐기, `requireSession` |
| YSM #9 role/plan 통합 | BL-06-005 | 코어 org 역할 + 엔타이틀먼트 |
| YSM #10 CORS, 예외 원문 노출 | BL-06-003 | 응답 봉투. CORS는 동일 출처라 해당 없음 |
| YSM #11 하위 프로세스 타임아웃 | BL-06-010 | Playwright 타임아웃 |
| YSM #12 이식 설계 | BL-06-011 | TS로 이식 |
| YSM #13 account_manager 분할, `except: pass` | BL-06-009, BL-06-034 | |
| YSM #14 거대 페이지 분할 | BL-06-021, BL-06-022, BL-06-023 | 파일 400줄 상한 |
| YSM #15 pytest 기본 세트 | BL-06-028, BL-06-030, BL-06-031 | TS 테스트로 대응 |

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 |
|---|---|---|
| `_supabase-modular/seed.sql`의 blog 플랜을 01장 4.1절로 갱신(free 월 20, `max_channel_accounts` 등 키, pro/business 행, 팩 3종) | seed 소유자 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치 |
| `adjust_credits` 함수 | `_platform-core` | 크레딧팩 환불 시 음수 조정(`CORE_SPEC.md` 5.4절) |
| `confirm_payment_order` 금액 불일치 시 주문 failed 기록 | `_platform-core` | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. PM001 시 별도 호출로 운영 대사 가능 |
| 브랜드커넥트 위험 동의 고지문 버전 컬럼(`affiliate_accounts.risk_notice_version`) | `_platform-core` | 지금은 감사 로그 메타데이터로 대체 |
| 브랜드커넥트 동의 철회 함수 | `_platform-core` | 지금은 서버가 service_role로 처리 |
| 브랜드커넥트 지원서 대상 범용화(`target_url`/`target_kind`/`source_app`) | `_platform-core` | 해결(2026-10-13 코어 반영 완료, `CORE_SPEC.md` 16.1절). blog는 BL-06-017·018·024를 새 시그니처와 BL-F-036 넘김으로 구현 |
| compliance 규칙 사전에 blog 추가분(가상 후기, 수익 보장) 등록 경로 | `_platform-core` | 제품별 확장 지점 |

### 6.1 AI 계층 요청 (2026-10-13)

| ID | 대상 | 요청 | 이유 | 그때까지의 우회 |
|---|---|---|---|---|
| AI-R1 | `_design-guide` 3D 키트 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/file/03-설계/디자인/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| AI-R2 | `_supabase-modular/seed.sql` | blog 플랜 3행 `features`에 `ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `dictation`, `rag_documents`, `product_wiki` 추가(01장 4.3절 값) | seed가 1300보다 나중에 실행되면 9.2절 병합 UPDATE가 덮어써진다 | 서버가 누락 키를 기본값으로 읽는다(01장 4.3절) |
| AI-R3 | `_platform-core` AI_ARCHITECTURE, ai-gateway | TS 워커가 그래프를 실행할 때 쓰는 잡 토큰 발급 규칙(Next.js `/api/internal/ai-token`, 워커 키 + running 잡 확인, org·sub는 잡 행에서)을 공용 규칙과 `packages/ai-gateway`에 추가 | 개인키는 Next.js에만 둔다는 규칙과 워커 기반 생성이 함께 필요(astro R-8과 같은 문제) | blog 제품 엔드포인트로 구현(04장 2.1절, 01장 D-15) |
| AI-R4 | ai-service | (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 단건 호출 `POST /tools/blog/assist`의 scope `chat` 사용과 fast/quality 등급 힌트 (c) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | Dify 보조 노드 라우팅(`dify.aux`), 단건 purpose의 FastAPI 이전, 위키 편집 | (a) Dify에 기능별 모델 이름을 따로 등록 (b) blog 확장(`app/ai/tools/blog/`)에 임시 구현 (c) `wiki_config.py`에 임시 구현 |
| AI-R5 | 공용 Dify | `blog-chat` 앱 생성, 내부 키 환경 변수, 로그 보존 30일 | 공용 인프라는 코어 소유 | 없음(필수). 장애 시 `/tools/answer-direct` |
| AI-R6 | core-voice | 대화 없는 음성 세션(`voice_sessions.conversation_id` null, 받아쓰기)과 기능별 길이 상한(5분·20MB)을 `VoiceAdapter` 계약에 명시 | `VOICE_ARCHITECTURE.md` 4절 상한(STT 10분, 50MB) 안이지만 제품별 상한이 필요 | 라우트에서 상한을 검사하고 세션 `conversation_id`를 null로 둔다(스키마 허용) |
| AI-R7 | ai-service, AI_ARCHITECTURE | 그래프 interrupt 재개·취소 엔드포인트(`POST /graphs/runs/{id}/resume`, `/cancel`)와 대기 상태 표현 규약(run `running` + `approve` 스텝 `running`, `ai_runs.status`에 대기 값이 없다) | 사람 승인 노드(`AI_ARCHITECTURE.md:118`)를 재개할 공용 경로가 없다 | blog 확장에서 LangGraph 체크포인트 재개를 감싼 엔드포인트로 구현(04장 6.1절) |

## 7. 완료 정의

| 조건 | 명령/기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -w build`, `pnpm -w tsc --noEmit`, `pnpm -w lint` 0 오류 |
| SQL | `node D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs mod ...`, `... mono ...` OK |
| RLS 스모크 | BL-06-028 모듈러·모놀리스 0 실패 |
| 결제 E2E | BL-06-029 통과(Toss 테스트 키) |
| 발행 | BL-06-030, BL-06-037 통과, 대가성 문구 포함률 100% |
| 디자인 | `DESIGN_PRINCIPLES.md` 7단계 체크리스트 12항목 |
| AI·음성 | `pytest apps/api` 통과, BL-06-056 녹색, 그래프 평가셋 20건을 상용·오픈소스 경로 모두 통과, 채팅 평가셋 30문항 금지 응답 0, 승인 전 발행 409 테스트 통과 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(BL-06-044) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | 2절 P0 작업 전부 완료(W0~W6)와 8절 BL-06-057(Stage B, G1 후, 수용 기준 B-1~B-6, 테스트: Mock E2E는 BL-06-037·029, Google 실로그인은 사람 수동 점검표), P1은 출시 전 완료. W7은 Phase 2(BL-06-058·059는 G2 후) |
| 인증 단계 | A: BL-06-004 수용 기준(Mock 페르소나, 배포 빌드 실패, `/api/dev/login` live 404). G1 판정 `[DECISION] G1 통과` 기록 후 BL-06-057 완료(B-1~B-6)가 공개 베타 조건. C1·C2(BL-06-058, 059)는 G2 후이며 MVP 완료 조건이 아니다(8절) |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(이하 AUTH_ROADMAP) 9장 규칙과 8장 blog 행(open, B Google + 이메일, C1 P1, C2 P1(네이버 블로거 비중))이다. 기존 인증 작업 BL-06-004는 2절 그 줄에서 Stage A 범위로 바꿨다(이메일 가입·비밀번호 재설정 화면, Google 버튼, `/auth/callback` 라우트는 BL-06-057로 이동). 새 ID는 056 다음부터다. 로그인 제공자 작업은 블로그 채널 연결(BL-06-009, 011, 012, 018의 네이버·티스토리 Playwright 로그인)과 무관하며 그 작업들의 소유 경로를 건드리지 않는다.

### 8.1 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| BL-06-057 | Stage B: Google OAuth 전환 + 이메일 가입·메일 인증·비밀번호 재설정 화면. 로그인 화면의 제공자 버튼(Google, 이메일 폼), `/auth/callback`(AUTH_ROADMAP 3.2절 전체 + 단위 테스트), 첫 OAuth 로그인 약관 동의 `/onboarding/terms`(03장 7.3절, `/onboarding/ai` 앞), 배포 env(`AUTH_MODE=live`, `AUTH_PROVIDERS=google,email`)와 배포 체크리스트. `supabase/config.toml`의 `[auth.external.google]`은 BL-06-001 담당에 요청(1절). 로그인 페이지(`src/app/(auth)/login/`)와 `src/lib/auth/`는 BL-06-004 소유이므로 제공자 버튼 장착과 `finishLogin`의 코드 교환 연결은 004 파일에 1줄 요청(`listLoginOptions` 계약은 004가 A단계에 이미 만든다) | `src/app/auth/callback/`, `src/app/(auth)/signup/`, `src/app/(auth)/reset-password/`, `src/components/auth-providers/`, `src/app/onboarding/terms/`, `tests/unit/auth-callback/`, `docs/ops/auth-checklist.md` | BL-06-004, BL-06-026, BL-06-046, G1 | P0(공개 베타 필수) | M | Fable | AUTH_ROADMAP 5.3절 그대로: B-1 새 Google 계정 첫 로그인 → `session_context('blog')` entitled=true, `plan_code='free'`, 가입 크레딧 1회만(재로그인 3회 뒤 원장 행 수 같음). B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → `/dashboard`. B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 서버 오류 로그에 토큰·코드 없음. B-4 배포 빌드(`VERCEL_ENV=production`)에서 `/api/dev/login` 404, 로그인 화면에 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(BL-06-037, 029) 계속 녹색, Google 실로그인은 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인해 task `log.md`에 기록. B-6 운영 대시보드 Google 설정, Redirect URLs, `AUTH_PROVIDERS`가 배포 체크리스트와 일치. 추가: 첫 OAuth 로그인 → `/onboarding/terms` → `/onboarding/ai` 순서, 이메일 가입자는 terms 건너뜀. 이유: 세션 발급·권한 경계 | AUTH_ROADMAP 5장, 01장 BL-F-001, D-24 |
| BL-06-058 | Stage C1: 카카오 로그인(Supabase 기본 제공자 `kakao`) + 설정 → 로그인 방법 화면(연결·해제, `linkIdentity`) | `src/components/auth-providers/kakao.tsx`(BL-06-057 디렉토리에 파일 1개 추가 요청), `src/app/(app)/settings/login-methods/`, `tests/e2e/auth-link/` | BL-06-057, G2 | P1 | S | Opus | AUTH_ROADMAP 7.1.3절 그대로: C1-1 새 카카오 계정 첫 로그인 → B-1과 같은 결과(엔타이틀먼트·크레딧 1회). C1-2 비즈 앱(01장 D-22 (a))이면 Google로 가입한 같은 이메일 사용자가 카카오로 로그인 → 같은 `user_id`(Supabase 자동 연결은 제공자가 이메일 인증을 확인한 경우만, 미확인이면 수동 연결). C1-3 (b)면 이메일 없는 사용자가 결제 전 연락 이메일 입력 화면을 본다. C1-4 표시 이름은 카카오 닉네임, 없으면 `user` 규칙. C1-5 버튼은 카카오 디자인 가이드 색·문구(미확인, 최신판 확인). 로그인 방법 화면: 남는 수단 1개면 해제 비활성, 감사 `auth.identity_link`·`auth.identity_unlink`, 채널 화면과 구분 안내(03장 7.4절) | AUTH_ROADMAP 7.1절, 7.3절 |
| BL-06-059 | Stage C2: 네이버 로그인. 스파이크(0.5일, AUTH_ROADMAP 7.2.2절) → `custom:naver` 또는 서버 브리지(7.2.3절). 등록 스크립트, 브리지면 `/auth/naver/start`·`callback`·로그인 상태 연결 라우트와 코어 요청(8.3절). 네이버 검수 신청 자료(로그인 버튼부터 가입 완료까지 화면 캡처) | `src/components/auth-providers/naver.tsx`(BL-06-057 디렉토리에 파일 1개 추가 요청), `src/app/auth/naver/`, `src/app/auth/link/`, `src/server/auth-bridge/`, `scripts/auth/`, `tests/e2e/auth-naver/` | BL-06-057, G2(BL-06-058과 병렬, 설정 화면의 네이버 행은 058 파일에 1줄 요청) | P1(네이버 블로거 비중으로 C1보다 신청을 먼저 시작, 제안) | M | Fable | AUTH_ROADMAP 7.2.4절 그대로: C2-1 스파이크 결과가 `[DECISION]`으로 기록되고 `NAVER_AUTH_PATH`가 그 값. C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 결과. C2-3 같은 네이버 계정 재로그인 5회 → 같은 `user_id`, 사용자 수 증가 0. C2-4 (브리지) state 변조·재사용·쿠키 없음 → 거부, 세션 미생성, 다른 브라우저에서 받은 콜백 URL 재생 → 거부. C2-5 (브리지) 같은 이메일의 Google 가입자가 네이버로 처음 로그인 → `email_in_use` 안내, 새 사용자 0. C2-6 네이버 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않는다. 추가: 로그인용 네이버 애플리케이션과 블로그 채널 연결(BL-06-009)의 자격증명·코드가 섞이지 않음(채널 `encrypted_credentials`를 읽지 않음). 이유: 세션 발급 경로(브리지) | AUTH_ROADMAP 7.2절, 01장 D-23, YSM #5 |

### 8.2 게이트와 웨이브

| 게이트·웨이브 | 작업 | 진입 조건 | 판정·기록 |
|---|---|---|---|
| A(W1부터) | BL-06-004 | W0 | W0 작업(001, 003 등)은 시드 스크립트 없이 SQL·단위 테스트로 검증한다(AUTH_ROADMAP 9장 A 작업 규칙) |
| G1 | - | 2절 MVP P0 기능 작업 완료(057 제외, 056은 G1 뒤에도 가능), 핵심 플로우 E2E(BL-06-037) Mock storageState 녹색, RLS 스모크(BL-06-028) 0 실패·`outsider` 교차 테넌트 거부, 결제 E2E(BL-06-029) 녹색, 단계 분기 코드가 인증 모듈 밖에 0건(BL-06-032), Google Cloud·동의 화면·운영 Supabase 준비(AUTH_ROADMAP 4장) | 사람(대표님)이 판정하고 task `log.md`에 `[DECISION] G1 통과` |
| W6(054 뒤, 056 앞) | BL-06-057 | G1 | 3절 W6 행 `054 → 057 → 056`. 054는 마지막 P0 기능(받아쓰기)이라 G1 전에 끝나고, 057은 G1 뒤 공개 베타 직전 통합 단계(056)의 맨 앞에 선다. 056(AI·음성 보안 회귀)과 037·029의 B 구성 재실행(B-5)은 057 완료를 기다린다 |
| G2 | - | Google 실로그인 공개 베타 2주, 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만, `entitled=false` 신규 가입자 0(모두 제안 수치, AUTH_ROADMAP 6장), 카카오 비즈 앱(01장 D-22), 네이버 애플리케이션 등록·검수 자료·스파이크 기록 | 사람이 `[DECISION] G2 통과` |
| W7(MVP 출시 후) | BL-06-058, 059(병렬) | G2 | 3절 W7 행. 네이버 검수 기간 때문에 059의 애플리케이션 등록·검수 신청은 G2 직후 먼저 |

### 8.3 공용 모듈 요청 (6절 보충)

| 요청 | 대상 | 이유 | 조건 |
|---|---|---|---|
| 코어: `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql` 적용 | `_platform-core`, `_supabase-modular` 소유자 | C2 브리지 경로의 네이버 고유 id ↔ 사용자 매핑. 코어는 한 번만 적용하고 모든 제품이 쓴다(AUTH_ROADMAP 9장) | BL-06-059 스파이크가 브리지로 결정된 경우만 |
| `supabase/config.toml` 단계별 설정(A: google·kakao `enabled=false`, B: google, C1: kakao) | BL-06-001 담당 | `supabase/`는 001만 쓴다(1절). 예시 `D:/WorkSpace/platform/docs/products/_supabase-modular/config.toml.example` | 057·058 착수 시 |

### 8.4 작업 수와 비율 변화

| 항목 | 2026-10-13 | 2026-10-14 |
|---|---|---|
| 작업 수 | 56(모델 55 + 사람 1) | 59(모델 58 + 사람 1) |
| Fable | 11개 20.0%, 가중 23/103 = 22.3% | 13개 22.4%, 가중 27/108 = 25.0% |
| Opus | 28개 50.9%, 가중 52/103 = 50.5% | 29개 50.0%, 가중 53/108 = 49.1% |
| Sonnet | 13개 23.6%, 가중 25/103 = 24.3% | 13개 22.4%, 가중 25/108 = 23.1% |
| Haiku | 3개 5.5%, 가중 3/103 = 2.9% | 3개 5.2%, 가중 3/108 = 2.8% |
