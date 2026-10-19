# CLAUDE.md: Microweb Studio

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`, 인증 작업이면 `AUTH_ROADMAP.md`(맨 끝 "인증 단계 규칙" 절) |
| 2 | 이 폴더 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md` |
| 1-AI | AI·음성 작업이면 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `SECURITY_BASELINE.md` 16장 |
| 3 | UI 작업이면 `docs/products/_design-guide/DESIGN_SYSTEM.md`(먼저, 스튜디오), `DESIGN_PRINCIPLES.md`(공개 청첩장·쇼룸), `REFERENCES.md` microweb 절, 랜딩이면 `HERO_3D.md` |
| 4 | DB 정본 `docs/products/_supabase-modular/migrations/1500_microweb.sql` |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 `src/server/`와 `worker/`에서만. `NEXT_PUBLIC_` 접두사 금지 |
| 하객 경로 | `/i/*`, `/api/public/*`에서 이미지 생성 AI 호출 금지. 범용 AI 프록시 금지. 하객 공개 AI 라우트는 `greeting`과 `guestbook/voice/transcribe` 2개뿐이고 고정 기능 키·enum 입력만 쓴다. 방문 때 실행되는 AI 호출 0(재생은 저장된 파일) |
| 공개 읽기 | 하객 페이지는 anon 키로 `site_publications`만 읽는다. `sites`를 공개 경로에서 service_role로 읽지 않는다(예외: `/p/[token]` 시안) |
| 하객/문의 쓰기 | `submit_guestbook_entry`, `submit_rsvp`, `create_lead`(service 전용, 리밋 내장)만. 테이블 직접 INSERT 금지 |
| 크레딧 | 셀프 게시만 라우트에서 선차감(`consume:microweb:<request_id>`), 실패 시 잡 환불. 사용자 RPC 안에서 크레딧을 건드리지 않는다 |
| 결제 | PM001이면 별도 호출로 `fail_payment_order`를 부른다(04장 2절) |
| 코어 | 공용 모듈을 다시 만들지 않는다. `_platform-core`, `_supabase-modular`의 다른 파일, core 마이그레이션 수정 금지. 필요하면 06장 6절 요청 |
| 개인정보 | IP 원문 저장·로그 금지, 사진 EXIF 제거, 감사 로그에 이름·연락처·본문 금지 |
| LLM 키 | FastAPI(`apps/api`)에만. Vercel과 `microweb.media` 워커에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`, `/api/public/[slug]/*`만 부른다. Dify, FastAPI, 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑만. Dify 입력에 토큰·org·개인정보를 넣지 않는다 |
| AI 입력 | 실명·전화·계좌·주소·이메일·사진은 어떤 AI 제공자에도 보내지 않는다. 호칭 토큰, enum, 패턴 마스킹한 메모만. 하객 이름은 축하말에 보내지 않는다 |
| AI 크레딧 | 셀프서비스는 제공자 호출 전 선차감 후 정산, 결과 미전달은 전액 환불. 하객 기능은 0 크레딧 + `ai_usage`. 대행 모드는 01장 D-9 결정을 따른다. 선차감·정산은 `src/app/api/ai/`, `src/app/api/voice/`, `ai-copy`, `voice-greeting` 라우트에서만 한다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용을 쓰지 않는다. 하객 음성 STT는 항상 오픈소스, 실패해도 대체하지 않는다 |
| 하객 음성 | 녹음 전 고지 확인(`third_party_notice`, 고지문 버전), 서명된 방문자 쿠키, 엄격 레이트 리밋. 원본은 `voice-audio`에만, 읽기는 서버가 5분 서명 URL로 중계. 방명록 연결은 `attach_guestbook_voice`만 |
| 인사말 음성 | 낭독 텍스트는 DB의 인사말 블록에서만. 한 파일은 제공자 하나로 만들고 실패하면 파일 없이 환불. 타인 음성 복제 금지. 자동 재생 금지 |
| 문구 제안 | 결과를 `sites.content`에 자동 반영하지 않는다(운영자 "적용"만). 적용 시 블록 zod와 템플릿 `allowed_blocks`를 서버가 다시 검증 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 스튜디오·쇼룸 화면 작업은 MW-06-038 뒤. 공개 청첩장은 템플릿 테마 토큰(스튜디오 토큰 사용 안 함) |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `/i/*`와 스튜디오 번들에 0바이트. `HERO_3D.md` 성능 예산과 대체 화면을 지키고 3D 재질 색도 토큰만 |
| 문구 | 01장 6절 금지 문구(미검증 수치, 근거 없는 할인, 가상 후기, 가짜 포트폴리오) 금지 |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 소유 작업 |
|---|---|---|
| `src/engine/{schema,blocks,themes,share}` | 블록 엔진(데이터 소스 모름) | 004, 005, 006, 008 |
| `src/app/i`, `src/app/p` | 하객, 시안 | 007, 017 |
| `src/app/(showroom)`, `src/showroom` | 쇼룸 | 020~025 |
| `src/app/studio`, `src/studio` | 운영자 화면 | 014, 018, 019, 043(wiki, admin), 047(ai-copy), 048(chat), 040(onboarding, settings) |
| `apps/api/` | FastAPI AI 서비스(공용 설치 039, 지식 042, 위키 043, 그래프 044·016, 도구 045, 회귀 053) | 039, 042, 043, 044, 016, 045, 053 |
| `src/app/api/ai`, `internal`, `onboarding`, `src/server/ai` | AI 게이트 | 040 |
| `src/app/api/voice`, `src/components/voice`, `src/server/voice` | 스튜디오 음성 | 049 |
| `.../voice-greeting`, `worker/handlers/voice` | 인사말 음성 | 050 |
| `.../guestbook/voice`, `src/server/guest-voice`, `src/engine/voice` | 하객 음성 방명록 | 051 |
| `src/components/hero3d`, `public/hero` | 쇼룸 3D 히어로 | 052 |
| `src/components/ui`, `src/styles`, `src/app/dev/components` | 디자인 시스템 | 020 |
| `content/copy`, `content/rules`, `infra/dify`, `scripts/knowledge`, `scripts/ai-routing` | 코퍼스 041, 규칙 044, Dify 045, 색인 042, 라우팅 스냅샷 053 | 041, 042, 044, 045, 053 |
| `src/app/api/public`, `src/app/api/studio`, `src/app/api/admin`, `src/app/api/billing` | 라우트 | 009, 010, 013, 015, 016, 025, 026, 027 |
| `src/server` | service_role 서비스 계층 | 작업별 하위 폴더 |
| `worker/` | `microweb.media` 워커 | 011, 012 |
| `supabase/`, `scripts/db/` | DB(정본은 모듈러 조각) | 002, 030 |
| `src/lib/auth`, `src/server/auth`, `src/proxy.ts`, `src/app/api/dev`, `src/app/login`(`providers/` 제외), `src/app/pending`, `src/app/no-access`, `scripts/dev` | 인증 Stage A(모듈 경계, Mock, 시드, 가드) | 003 |
| `src/app/login/providers`, `src/app/login/reset-password`, `src/app/auth/callback`, `src/app/auth/invite`, `src/app/studio/onboarding/terms` | 인증 Stage B(Google, 초대 수락, 약관) | 054 |
| `src/app/login/providers/kakao`, `src/app/studio/settings/login` / `src/app/login/providers/naver`, `src/app/auth/naver`, `src/server/auth-bridge`, `scripts/auth` | 인증 Stage C(P2 선택) | 055 / 056 |

같은 파일을 두 작업이 만지지 않는다. 경계는 `06_AGENT_PLAN.md` 2장 표가 정본이다.

## 4. 코어 사용 규칙

| 용도 | 방법 |
|---|---|
| 세션 | `requireSession('microweb', { roles })` → `ctx.org.id`. 그 뒤 `studio_access` 확인(없으면 `/pending`) |
| 사용자 쓰기 | 사용자 세션 클라이언트 + `supabase.schema('microweb').rpc(...)` 또는 허용된 컬럼 UPDATE |
| 크레딧 | `credits.consume` → `rpc request_publish(site, actor, ledger)` → `jobs.enqueue({ creditLedgerId })` |
| 잡 | 큐 `microweb.media`, job_type `asset.process`, `site.publish`, `site.unpublish_assets`, `site.purge`. 진행률은 `core.jobs` Realtime |
| 레이트 리밋 | DB 함수 내장분 외 라우트는 `core.rate_limit_hit('microweb:<route>:<key>', n, sec)` |
| 감사 | RPC가 기록. 서버 경로(CSV 내보내기, 업로드 삭제, 결제 불일치)는 service INSERT |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC) 턴마다 대화 주인을 다시 확인. 서명 토큰은 `src/server/ai/token.ts`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'microweb', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')`(고지문 버전 기록) |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. 스튜디오 질문은 `store_audio=false`, 하객 음성은 `store_audio=true` + `consent_kind='third_party_notice'`. 스튜디오 첫 녹음 전 `voice.consent` 감사 확인 |
| 그래프 | Next.js가 서명 토큰으로 `POST /graphs/microweb.invitation_copy/runs`(스튜디오), `microweb.guest_greeting`(하객, `sub=visitor`). FastAPI가 `ai_runs`·`ai_run_steps`·`ai_usage`를 기록하고 microweb 표 변경은 Next.js가 한다 |
| 위키·코퍼스 | 지식 조직(`MICROWEB_KNOWLEDGE_ORG_ID`)에만 둔다. 스튜디오는 `published`만 서버에서 읽는다. 쓰기는 FastAPI 경유 |
| 스키마 전환 | `SUPABASE_DB_SCHEMA=core`(모듈러) / `public`(모놀리스). 제품 스키마는 모듈러 `microweb`, 모놀리스 `public` |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16 App Router, React 19, TS strict, Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전, 스튜디오), zod, sharp·ffmpeg(워커), three.js + React Three Fiber + drei(React 19 호환 버전, 히어로만), FastAPI(Python 3.12 제안) + LangChain/LangGraph |
| 버전 | lockfile 커밋, `latest` 금지 |
| 타입 | `supabase gen types typescript --local --schema core,microweb > src/types/supabase.ts`. `any` 캐스팅 금지 |
| 상태 값 | DB CHECK와 같은 `as const` 배열 + zod |
| 디자인 토큰 | `src/styles/tokens.css`(쇼룸·스튜디오, Tailwind CSS v4 `@theme`), `src/engine/themes/<theme>.css`(템플릿). 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안) |
| 아이콘 | lucide 명시 import만 |
| 모놀리스 SQL | 손으로 고치지 않는다. 모듈러 조각 수정 → `scripts/db/to-monolith` 재생성 |

## 6. 테스트와 완료 조건

| 검사 | 명령/기준 |
|---|---|
| SQL | `cd docs/products/_tools-sqlcheck && node check.mjs --vector mod <0000~0009> ../_supabase-modular/seed.sql ../_supabase-modular/migrations/1500_microweb.sql` OK, `--vector mono`도 OK(AI 표가 있어 `--vector` 필수) |
| AI | `pytest apps/api`(토큰·조직 격리·라우팅·그래프·채팅 평가셋), `pnpm test:ai`(선차감·정산·환불, 하객 음성 남용) |
| RLS | `supabase/tests` 스모크 mod/mono 87/87 |
| 앱 | `tsc --noEmit`, `eslint`, `next build` 0오류 |
| E2E | F1~F3(대행, 하객, 문의) 녹색, 출시 체크리스트 12항목, 하객 JS 150KB 이하 |
| 결제 E2E | Phase 2 출시 조건 |
| 위생 | gitleaks 0, 추적 node_modules 0, 앱 아래 중첩 `.git` 0 |

## 7. 금지 패턴

| 패턴 | 대체 |
|---|---|
| 클라이언트가 모델/본문/헤더를 정하는 AI 프록시, 번들 속 시크릿 헤더 | 고정 purpose 서버 엔드포인트 |
| 방문마다 이미지 생성, AI 지도 | 업로드 사진, 카카오맵 임베드/딥링크 |
| `.env*` 커밋 | gitignore + gitleaks, 노출 시 재발급 |
| 하객에게 보이는 삭제 버튼, 검증 없는 insert | 운영자 RPC, service 전용 제출 함수 |
| 실패를 고정 문구로 숨김 | 오류 표시와 대안 안내 |
| 비밀번호 우회('1234'), 역할 직접 선택, 클라이언트만의 권한 판정 | core auth + RLS + `studio_access` |
| constants 하드코딩 커플 데이터 | content JSON + DB |
| 가짜 SRI, placeholder 키 | 공식 SRI, env |
| 미검증 수치, 정가 대비 할인, picsum 포트폴리오 | 실제 결과물, 동의받은 납품작 |
| `latest`, Tailwind CDN, `import * as Icons` | 고정 버전, Tailwind CSS v4 빌드, 명시 import |
| LLM·음성 키를 브라우저·Vercel·워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보 | 키는 FastAPI/Next.js 서버 전용, `/api/ai/*`·`/api/voice/*`, 대화 매핑 |
| 실명·전화·계좌 AI 전송, 하객 이름을 축하말에 전송, 하객 음성의 상용 STT·대체 | 호칭 토큰·enum, 오픈소스 강제 |
| 클라이언트 텍스트 그대로 TTS, 방문마다 TTS/STT, 고인·타인 음성 복제 | DB 본문만, 편집 시 1회 생성 |
| 고지 없는 하객 음성 보관, 쿠키 없는 익명 음성 업로드 | 고지 확인 + 방문자 쿠키 + 레이트 리밋 |
| 토큰 밖 3D 색, 파티클·글로우, 하객·스튜디오 번들의 three.js, "Tailwind"만 적은 지시 | 03장 4.6절 토큰, 번들 격리, "Tailwind CSS v4" |

## 인증 단계 규칙 (2026-10-14, 확정 결정 22)

정본 `docs/products/_platform-core/AUTH_ROADMAP.md`. 이 제품은 초대제(`signup_policy='invite'`)이고 로그인하는 사람은 초대받은 운영자뿐이다. 하객·고객 시안·쇼룸 방문자는 어느 단계에서도 로그인하지 않는다.

| 항목 | 규칙 |
|---|---|
| 지금 단계 | 개발 시작 시 Stage A(Mock). B(Google + 초대 메일)는 G1, C(카카오·네이버, P2 선택)는 G2 판정 뒤에만 시작한다 |
| 단계 전환 | 사람(대표님)이 G1·G2를 판정하고 task `log.md`에 `[DECISION] G1 통과` / `[DECISION] G2 통과`로 기록한다. 에이전트가 스스로 단계를 올리지 않는다 |
| 이 제품의 작업 | A = MW-06-003(인증 모듈·Mock·시드·가드), B = MW-06-054(P0, W6 맨 앞), C1 = MW-06-055(P2 선택), C2 = MW-06-056(P2 선택). 06장 8절 |
| 단계 분기 위치 | `AUTH_MODE`·`AUTH_PROVIDERS`·`NAVER_AUTH_PATH`는 `src/lib/auth/`, `src/app/login/`, `src/app/auth/callback/`, `src/app/auth/invite/`, `src/app/api/dev/`(C2 브리지면 `src/app/auth/naver/`)에서만 읽는다. 기능 코드·워커·`apps/api`에 `if (mock)`, 페르소나 이메일 분기 금지 |
| 권한 판정 | 단계와 무관하게 `requireSession('microweb')` → `studio_access`. 엔타이틀먼트 없음은 `/no-access`(초대받은 이메일로 로그인 안내), 허용 목록 없음은 `/pending` |
| 콜백(invite) | `finishLogin`은 `bootstrap_app_for_org`를 호출하지 않는다. 엔타이틀먼트·`studio_access`는 관리자 초대 라우트(MW-06-026)가 service_role로만 만든다 |
| 로컬 시드 | `supabase start` → `supabase db reset` → `.env.local`에 `AUTH_MODE=mock`, `DEV_SEED_PASSWORD` → `node scripts/dev/seed-users.mjs --app microweb`(제품 훅 `seed-users.microweb.mjs`, 05장 10절) → 출력된 owner 조직 id를 `MICROWEB_STUDIO_ORG_ID`에 → `/login` 개발용 패널 |
| 페르소나 | `owner`(허용), `studio_denied`(엔타이틀먼트만, 허용 목록 없음), `admin`·`member`·`viewer`(owner 조직 역할), `outsider`(다른 조직), `no_app`(초대 안 됨 → `/no-access`), `suspended`, `ops`(platform_admin). `pending`은 없다 |
| E2E | Playwright `globalSetup`이 페르소나마다 `/api/dev/login`을 호출해 `storageState`를 저장하고 테스트는 그 상태로 시작한다(MW-06-032). 실제 Google 로그인은 자동화하지 않고 사람 수동 점검표로 확인한다(B-5) |
| 금지 패턴 | 쿠키·localStorage에 역할·플랜 저장, `mock-auth`, `nomad_role`, `nomad_plan`, `dev-user` 우회, `DEV_SEED_PASSWORD`를 `NEXT_PUBLIC_*`·브라우저 번들에 두기, 원격 Supabase에 시드 실행, 배포 환경에서 `/api/dev/login` 응답(404여야 함), 콜백 `next` 무검증, 이메일 일치만으로 계정 자동 병합, 하객·시안·쇼룸 화면에 로그인 버튼 |
| 배포 env | `AUTH_MODE=live`, `AUTH_PROVIDERS=google,email`(B. `email`은 초대 수락 때 비밀번호를 정한 운영자의 이메일 로그인이며 공개 가입 폼은 없다). `AUTH_MODE=mock`이면 배포 빌드가 실패해야 한다 |
| 초대 메일 | 발송·`studio_access` 부여는 관리자 라우트(MW-06-026, service_role). 수락은 `/auth/invite`(MW-06-054, `verifyOtp` type invite → 비밀번호 설정 → `finishLogin`). 초대 이메일과 다른 Google 계정으로 로그인하면 엔타이틀먼트 없는 새 사용자라 `/no-access` |

## 대시보드 셸·GNB 규칙 (2026-10-19)

정본: 03장 8장, 결정 대기 01장 9장(D-22~D-24). microweb-studio 전용이며 `_design-guide` 공용 패턴과 다른 제품 문서를 고치지 않는다.

| 항목 | 규칙 |
|---|---|
| 셸 범위 | GNB 셸은 `src/app/studio/**`에만 둔다. 쇼룸(`src/app/(showroom)`), 하객 `/i/*`, 시안 `/p/*`, 로그인·초대·온보딩, `/pending`·`/403`·`/no-access`는 셸 밖이다. 하객·시안·쇼룸 번들에 셸 코드를 넣지 않는다 |
| 메뉴 순서 | 03장 8.3절 표가 정본. 메뉴 배열은 `src/studio/shell/nav.ts` 한 곳에 두고(제안) 화면마다 따로 만들지 않는다. 셸 레이아웃(`src/app/studio/layout.tsx`)의 소유 작업은 06장에 없으니(02장 3절 auth 행 `02_ARCHITECTURE.md:98`에만 있음) 착수 전에 06장에서 정한다(미확인) |
| 역할 | 지식 관리 묶음은 platform_admin에게만 렌더한다. owner/admin 전용 행동은 메뉴를 숨기지 않고 버튼만 비활성 + 5장 권한 부족 문구. 판정은 `requireSession('microweb')` + `studio_access`이고 클라이언트 값(쿠키·localStorage 역할)을 믿지 않는다 |
| 단계 배지 | P1·Phase 2 메뉴는 배지로 자리만 보이고 기능 코드를 미리 만들지 않는다. 크레딧 화면은 `self_service` 조직에만 동작하고 대행 조직에는 안내만(D-9) |
| 색 | 토큰만(`src/styles/tokens.css`). 셸에 hex를 하드코딩하지 않는다. 선택 상태는 청자(`--color-accent`), 인주(`--color-cta`)는 셸에 쓰지 않는다(쇼룸 "견적 문의"와 3D 도장 전용, 03장 4.3절) |
| 홈 데이터 | 개수·목록은 서버 집계에서 받는다. 더미 배열·난수 지표 금지, 데이터가 없으면 03장 5장 빈 상태. 검색·알림·최근 활동에 문의자·하객의 이름·연락처·계좌·본문을 보이지 않는다(감사 기록 규칙과 같음) |
| 번들 | 셸·홈에 three.js를 import하지 않는다(스튜디오 번들 0바이트, 03장 4.6절) |
| 미정 자리 | 관리자 초대·포트폴리오 화면(D-22), `/studio/guests`(D-23), 셀프 사용자 전용 GNB(D-24)는 결정 전까지 만들지 않는다 |
