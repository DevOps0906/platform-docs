# CLAUDE.md: Live Poll

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 3 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1800_poll.sql`(DB 정본) |
| 4 | UI 작업이면 `D:/WorkSpace/platform/docs/products/_design-guide/` 문서(`DESIGN_PRINCIPLES.md`, `DESIGN_SYSTEM.md`, `HERO_3D.md`, `REFERENCES.md`, `SKILLS.md`) |
| 5 | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `POLL_IP_HMAC_SECRET`은 서버 파일에서만. `NEXT_PUBLIC_` 금지. `createAdminClient`는 `src/app/api/**`와 워커에서만 import |
| 청중 경로 | 청중 브라우저는 DB에 직접 접근하지 않는다. `/api/p/*` → service_role RPC만. anon 키로 `poll` 스키마를 읽는 코드를 만들지 않는다 |
| 크레딧 | 크레딧은 AI·음성 경로(`/api/ai/*`, `/api/voice/*`, `/api/p/voice-question`, `/api/internal/ai-settle`)에서만 선차감·정산한다(01장 4.2절). 투표·질문·입장·오버레이 경로와 RPC는 `consume_credits`를 호출하지 않는다 |
| LLM·음성 키 | LLM·임베딩 제공자 키는 FastAPI(`apps/api`)에만. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만. Vercel 클라이언트 번들과 브로드캐스터에 두지 않는다 |
| AI 경계 | 진행자 브라우저는 `/api/ai/*`, `/api/voice/*`, 청중 브라우저는 `/api/p/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·청중 정보를 넣지 않는다 |
| 청중 원문 | 청중이 쓴 질문·닉네임·음성은 상용 모델·상용 음성 제공자로 보내지 않는다(`force_open_source` 행, 01장 D9). 조직의 국외 이전 동의와 무관하다. 청중에게는 AI 채팅을 제공하지 않는다(음성 질문 STT만) |
| 투표 경로 격리 | `cast_vote`, `collect_broadcasts`, 브로드캐스터, `src/lib/realtime/`, 기존 `/api/p/{join,snapshot,vote,question,upvote}/`에서 AI 서비스·Dify·음성 서버를 호출하지 않는다. AI가 죽어도 투표는 정상이어야 한다(02장 6절) |
| AI는 제안만 | 그래프·도구는 질문 상태를 바꾸지 않는다. 숨김·승인은 진행자가 `moderate_question`으로 적용한다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5-2절과 seed(12행)가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 음성 저장 | 오디오와 변환 텍스트를 저장·로그하지 않는다(`voice_jobs.store_audio=false`). TTS 입력은 DB의 메시지·요약만(임의 텍스트 금지) |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/live-poll/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 주 레퍼런스: 진행자 콘솔 Atlassian, 보조 Primer(라이브러리 설치 금지, 패턴만). 화면 작업은 LP-06-035 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고 3D 재질 색도 토큰만. 3D 장면 값은 시연용이며 운영 수치가 아니다 |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*`를 수정하지 않는다. 필요하면 06장 6절에 요청 |
| DB 변경 | 스키마 변경은 모듈러 조각(18xx)에서 Fable 담당. 모놀리스 파일은 변환 스크립트로만 만든다 |
| 폴링 금지 | 주기적 fetch 금지. 스냅샷은 입장, 재구독, seq 공백, 15초 무수신 때만 |
| IP | 원문 IP를 DB, 로그, 감사에 남기지 않는다. HMAC 값만 레이트 리밋 키로 |

## 3. 디렉토리와 소유 경계

`apps/live-poll/` 아래: `(marketing)` 랜딩, `(auth)` 로그인, `(host)` 진행자, `present` 발표, `overlay` 오버레이, `(participant)` 청중, `api/p` 청중 API, `api/host` 진행자 API, `api/overlay` 오버레이 API, `lib/realtime` 훅, `lib/realtime-auth` JWT, `lib/poll` 도메인, `components` UI, `supabase` DB. 워커는 `services/poll-broadcaster/`. AI·음성·3D(2026-10-13): `api/ai`(대화·채팅 037, 자료·아카이브 038, 위키 039, qna-assist 040), `api/voice`(044, qna-summary 046), `api/p/voice-question`·`api/host/events/[id]/audience-voice`·`server/audience-voice`(045), `api/internal`·`api/onboarding`·`server/ai`(037), `components/ai-assistant`(042), `components/qna-ai`(043), `components/voice`(044 host, 045 audience, 046 summary), `components/hero3d`·`public/hero`(047), `components/ui`·`dev/components`(023), `apps/api/`(FastAPI 036, 확장 038~041), `infra/dify/`(041), `docs/file/03-설계/디자인/`(033, 034, 035). 작업별 소유 디렉토리는 06장 2절 표가 정본이며 남의 디렉토리는 읽기만 한다.

## 4. 코어 사용 규칙

| 항목 | 규칙 |
|---|---|
| 세션 | 진행자 라우트 진입부 `requireSession('poll')`. 역할은 `session_context`의 `org.role`. 프로필 없으면 로그아웃 |
| 가입 | `signUp({ options: { data: { signup_app: 'poll' } } })`. 기존 사용자 첫 진입은 `bootstrap_app_for_org('poll')` |
| 플랜 | 기능 게이팅은 서버에서 `entitled_plan_code` + `plans.features`(01장 4절 키). DB 한도는 RPC가 강제 |
| 잡 | 브로드캐스트는 `core.jobs`를 쓰지 않고 워커가 `poll.collect_broadcasts`. AI 작업 5종(`poll.ai.*`, 02장 4절)만 `jobs.enqueue`. Q&A 정리는 잡이 아니라 SSE 실행 |
| 감사 | 진행자 RPC는 내부에서 `write_audit`. CSV 내보내기는 Route Handler가 service INSERT(`event.export`) |
| 레이트 리밋 | RPC 내부 `core.rate_limit_hit`. 키 규약 `poll:<route>:<id>` |
| 결제(Phase 2) | `CORE_SPEC.md` 5장 시퀀스. PM001이면 별도 호출로 `fail_payment_order` 후 Toss 취소 + 알림 |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인을 다시 확인. 서명 토큰은 `src/server/ai/token.ts`만 발급 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')`. 고지문 버전은 환경변수 상수와 `ai_org_settings`가 같아야 한다 |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. 진행자는 첫 녹음 전 고지 확인(`write_audit` `voice.notice_ack`). 청중은 `voice_question` 오픈소스 전용, 한도 5중(02장 5-4절) |
| 위키·자료 | 행사별 컬렉션 `event-<event_id>`, 조직 컬렉션 `qna-archive`. 위키 slug 접두사 `events/<event_id>/`. 쓰기는 FastAPI 경유 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next 16.2.9, React 19, Tailwind CSS v4(4.x 고정), shadcn/ui(Tailwind v4 지원 버전), supabase-js 2.x, `@supabase/ssr`, zod, Recharts 3(콘솔만), Node 22(워커), three.js + React Three Fiber + drei(React 19 호환 버전, hero3d만), FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 태그 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| Python | `apps/api`: ruff, mypy(제안), pydantic 스키마는 04장 4절 JSON과 같게. 규칙 파일은 LP-06-040 소유 |
| 실시간 | `useEventChannel`만 채널을 만든다. 컴포넌트는 props만. 수신 반영은 rAF로 묶는다. `postgres_changes` 금지 |
| 타입 | `supabase gen types typescript --local --schema core,poll > src/types/supabase.ts`. `as any` 금지 |
| 입력 | Route Handler 입력은 zod. 본문 4KB 상한 |
| 렌더 | 닉네임/질문은 텍스트로만 렌더. `dangerouslySetInnerHTML` 금지 |
| 메타 | `/e/*`, `/present/*`, `/overlay/*`, `/events/*`는 `robots: noindex` + `X-Robots-Tag` |
| 디자인 | 토큰은 `src/styles/tokens.css`(Tailwind CSS v4 `@theme`, 03장 3.8절 의미 기반 이름). `design-system/live-poll/MASTER.md`는 UUPM 초안 입력일 뿐 정답이 아니다. 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안), 이모지 아이콘 금지(Lucide) |
| AI 표시 | 답변·요약·음성·위키에 01장 6.1절 AI 생성 표시를 반드시 붙인다. 요약·답변에 청중 닉네임을 넣지 않는다 |
| 린트 | `pnpm lint`, `pnpm typecheck` |

## 6. 테스트와 완료 조건

06장 7절. 명령: `pnpm test`(단위), `pnpm test:e2e`(Playwright), `pnpm test:rls`(LP-06-026), `pnpm test:load`(LP-06-027, 수동), `pytest apps/api`(토큰·조직 격리·라우팅·그래프·채팅 평가셋: 036, 038, 040, 041, 048), `pnpm test:ai`(AI 게이트 선차감·정산·환불, 청중 음성 남용: 037, 045, 048), SQL 체커 `cd D:/WorkSpace/platform/docs/products/_tools-sqlcheck && node check.mjs --vector mod ...`(AI 표가 있어 `--vector` 필수; 06장 7절과 05장 9절의 파일 순서: 0000~0009, seed, 1800).

## 7. 금지 패턴

07장 4절 요약: 이벤트마다 전체 재조회, 훅 중복 호출로 채널 중복, 연결 상태 미표시, `as any`, RLS 자기참조/`USING(true)`, 프로필 없으면 admin, 실키 `.env` 커밋, `FOR ALL` 정책, 한글 `\b` 금칙어, 공개 채널 메시지 신뢰, 레이트 리밋 히트 뒤 raise, IP 원문 저장, Supabase 익명 로그인 사용(코어 요청 해결 전). AI·디자인(2026-10-13): LLM·음성 키를 브라우저·Vercel·브로드캐스터에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보, 청중 원문 상용 전송, AI 결과만으로 질문 숨김, 클라이언트 텍스트 그대로 TTS, 오디오·변환 텍스트 저장·로그, 투표 경로에서 AI 호출, 한도 없는 청중 음성 경로, 토큰 밖 3D 색, "Tailwind"만 적은 지시(v3 혼입).

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`, 제품 적용 01장 8.1절, 02장 9절, 03장 7절, 04장 8절, 05장 10절, 06장 8절.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 A(Mock 로그인). 로그인하는 사람은 진행자뿐이다 |
| 단계 순서 | A Mock(LP-06-003) → G1 → B Google + 이메일(LP-06-049, P0, 공개 베타 필수) → G2 → C1 카카오(LP-06-050, P1), C2 네이버(LP-06-051, P1) |
| 로그인 없는 흐름 | 청중(코드·QR 입장, 참가자 토큰 쿠키)과 OBS 오버레이(키)는 단계와 무관하다. 단계 전환 때 `/api/p/*`, `/api/overlay/*`, `(participant)`, `overlay`, `lib/realtime-auth`를 바꾸지 않고 로그인 버튼을 추가하지 않는다. Mock 단계에서도 그대로 동작한다 |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH` 참조는 `src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/callback/`(C2 브리지면 `src/app/auth/naver/`), `src/app/api/dev/login/`에만. 기능 코드에 `if (mock)`, 페르소나 이메일 분기 금지. 권한은 `session_context('poll')`만 |
| 페르소나 사용 | `supabase start` → `supabase db reset` → `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD` → `pnpm db:seed-users`(= `node scripts/dev/seed-users.mjs --app poll`, 제품 훅 `seed-users.poll.mjs`) → `/login` 개발용 패널. 진행자 시나리오는 `host`(행사 A live, B draft), 공동 진행자는 `cohost`(host 조직 member), 교차 테넌트는 `outsider`, 읽기 전용은 `viewer`, 첫 진입 부트스트랩은 `no_app`(05장 10절) |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState` 저장. 청중은 페르소나 없이 `/api/p/join`. 실제 Google·카카오·네이버 로그인은 자동화하지 않는다(수동 점검표) |
| 금지 패턴 | 쿠키·localStorage·헤더에 역할·플랜·사용자 id를 적는 Mock(`mock-auth`, `nomad_role`, `nomad_plan`, `dev-user`), 원격 Supabase를 가리키는 Mock, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`나 로그에 두기, 콜백 `next` 무검증, 이메일 일치만으로 외부 계정 합치기, `listUsers` 전체 조회로 사용자 찾기, 네이버 검수 전 운영 `AUTH_PROVIDERS`에 `naver` |
| 가드 | `isMockAuthAllowed()` = `AUTH_MODE=mock` + Supabase 호스트 루프백 + `VERCEL_ENV`·`RAILWAY_ENVIRONMENT` 없음. 거짓이면 `/api/dev/login` 404, 개발용 패널 미렌더, `AUTH_MODE=mock`이면 기동 실패. CI에서 `AUTH_MODE=mock VERCEL_ENV=production` 빌드가 실패해야 한다 |
| 단계 전환 | 에이전트가 스스로 단계를 바꾸지 않는다. 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과` / `[DECISION] G2 통과`로 기록한 뒤에만 LP-06-049 / 050·051을 시작한다. C2 경로도 `[DECISION]`(01장 D20) |
| 소유 경로 | 003: `src/lib/auth/`, `src/app/api/dev/login/`, `src/proxy.ts`, `scripts/dev/`, `src/app/(auth)/`(A 구성). 049: `src/app/(auth)/`(003에서 이어 받음), `src/app/auth/callback/`, `src/app/onboarding/terms/`. 050: `src/lib/auth/providers/kakao.ts`, `src/app/(host)/settings/login-methods/`. 051: `src/lib/auth/providers/naver.ts`, `src/lib/auth/naver/`, `src/app/auth/naver/`(브리지만), `scripts/auth/`. 배지·`db:seed-users`는 001, 약관 단계 연결은 037, 설정 탭 링크는 021 파일에 1줄 요청(06장 8.1, 8.4절) |
| 이 제품 작업 ID | A: LP-06-003(W1). B: LP-06-049(W6 맨 앞). C1: LP-06-050, C2: LP-06-051(W7, G2 후). 남은 결정: 01장 8.1절 D19(카카오 이메일), D20(네이버 경로), D21(이메일 가입 유지) |

## 대시보드 셸·GNB 규칙 (2026-10-19)

정본: 03장 8장, 결정 대기 01장 9장(D22~D25). live-poll 전용이며 `_design-guide` 공용 패턴과 다른 제품 문서를 고치지 않는다. 대상은 진행자 셸(`(host)`)이고 청중·발표·오버레이 화면은 셸 밖이다.

| 항목 | 규칙 |
|---|---|
| 메뉴 순서 | 03장 8.3절 표가 정본. 메뉴 배열·묶음은 `src/components/shell/nav.ts` 한 곳에 두고(제안) 화면마다 따로 만들지 않는다. 셸 레이아웃 소유 작업은 06장 반영 전까지 미정(01장 9장) |
| 경로 | 메뉴 경로는 03장 1절 표에 있는 것만. 홈은 `/events`이고 `/dashboard`를 만들지 않는다. 새 경로 없음 |
| 현재 행사 | "현재 행사" 묶음은 URL `[id]`로만 정한다. localStorage·쿠키에 현재 행사나 역할·플랜을 적지 않는다. 다른 조직 행사 `[id]`는 서버 404, 칩·경로 표시에 그 제목을 렌더하지 않는다 |
| 역할 | 역할 밖 메뉴는 렌더하지 않는다(member는 설정 없음, viewer는 행사 목록·결과·위키 읽기·로그인 방법만). 판정은 서버 `session_context('poll')`의 `org.role` |
| 셸 밖 | `/present/[id]`는 GNB에서 새 창으로만 연다. `/overlay/*`, `/join`, `/e/*`에 셸·GNB·로그인 버튼을 넣지 않는다. 청중 경로 코드(`(participant)`, `api/p`, `lib/realtime-auth`)를 셸 작업에서 import하거나 고치지 않는다 |
| 어시스턴트 | 헤더 전역 버튼을 만들지 않는다. 진행자 콘솔·행사 편집의 오른쪽 시트만(03장 1절) |
| 개수 배지 | 서버 집계 값만, 0이면 숨김. 주기 fetch로 갱신하지 않는다(폴링 금지). 콘솔 배지는 진행자 토픽 수신 때만 |
| 검색 | 메뉴 이름·원본 이름·조직 행사 제목만. 청중 질문·닉네임을 검색 대상에 넣지 않는다 |
| 크레딧 | 헤더는 AI 크레딧 잔액만 보인다(D24 기본값). 셸 코드가 `consume_credits`를 부르지 않는다 |
| 토큰 | 셸은 `src/styles/tokens.css` 의미 기반 이름만. GNB 배경은 객석 남색(03장 4.3절). 셸 코드에 hex를 하드코딩하지 않는다. 응답 주황은 셸에 쓰지 않는다 |
| 금지 | 메뉴 이모지, 하드코딩 개수·KPI, 미검증 수치("0.5초 실시간" 등), 잠금 배지(판매 플랜 모두 기능 키 true) |
