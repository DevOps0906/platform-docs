# CLAUDE.md: 신비로운AI

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/file/03-설계/공용코어/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`(16장 AI·음성), `DB_CONVENTIONS.md`(14장 pgvector), `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 1-AI | AI·음성 작업이면 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md` |
| 2 | 이 폴더 `01_PRD.md` → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` 4절 |
| 3 | UI 작업이면 `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`(먼저), `DESIGN_PRINCIPLES.md`, `REFERENCES.md` astro-ai 절, 랜딩이면 `HERO_3D.md` |

원본 기획(`Astro AI/기획안/`, `FortuneDocs/`)은 참고용이다. 이 폴더와 충돌하면 이 폴더가 이긴다.

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role 키 | 서버 파일(Route Handler, `src/server/`, 워커)에서만. `NEXT_PUBLIC_` 금지. `createAdminClient`는 권한 확인 뒤에만 생성 |
| 크레딧 선차감 | 리딩은 `POST /api/readings`, `POST /api/readings/[id]/renders`에서만 `consume_credits`(잡 생성 전 차감, 이후 실패는 `refund_credits` 또는 `fail_job` 자동 환불). AI·음성은 `POST /api/ai/chat`, `POST /api/voice/stt`·`tts`·`narrations`에서만 선차감·정산(04장 2.1절). 그 밖의 파일에서 차감하지 않는다 |
| LLM 키 | FastAPI(`apps/api`)에만. Vercel과 `astro-worker`에 두지 않는다. ElevenLabs 키와 서명 토큰 개인키(`AI_TOKEN_PRIVATE_KEY`)는 Next.js 서버에만 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다. Dify, FastAPI, LLM·음성 제공자 직접 호출 금지. Next.js → FastAPI·음성 서버는 EdDSA 서명 토큰, Dify 경로는 대화 매핑(`platform_conversation_id`, `dify_user`)만. Dify 입력에 토큰·org·개인정보를 넣지 않는다 |
| AI 입력 | 실명·생년월일시 원문·이메일은 어떤 AI 제공자에도 보내지 않는다. 엔진 수치와 `{{호칭}}` 토큰, 마스킹한 사용자 메시지만 |
| 명리 판정 | 용신·격국을 LLM이 판정하지 않는다(01장 D-10). 수치는 엔진 값만, 그래프 `chart` 노드는 저장된 엔진 결과를 읽기만 한다 |
| AI 크레딧 | 채팅·음성·낭독은 제공자 호출 전에 선차감하고 끝나면 정산, 결과가 전달되지 않으면 전액 환불(01장 4.7절). 리딩 그래프는 리딩 정액 차감에 묶는다 |
| 라우팅 | 기능 키와 기본 체인은 02장 5.1절과 seed가 정본. 코드에 제공자·모델을 하드코딩하지 않고 `resolve_ai_route` 결과만 쓴다. 국외 이전 미동의 조직에 상용 제공자를 쓰지 않는다 |
| 낭독 | `feature='narration'`은 작업 도중 다른 제공자로 대체하지 않는다. 실패하면 파일을 만들지 않고 환불 |
| Tailwind | 반드시 Tailwind CSS v4(4.x 고정). CSS 우선 설정(`@import "tailwindcss"`, `@theme`, `@custom-variant dark`). `tailwind.config.js`, `@tailwind base` 같은 v3 문법 금지. 지시·문서에 "Tailwind"가 아니라 "Tailwind CSS v4"라고 쓴다 |
| 디자인 시스템 | 정답은 코드 하나: `apps/astro-ai/src/styles/tokens.css`(`@theme`)와 `src/components/ui/`. 피그마·문서 hex 표는 정답이 아니다. 컴포넌트 작업은 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 버전, 배리언트, 수치, 금지, 검증)으로 1개씩 맡긴다. 화면 작업은 AS-06-041 뒤 |
| 3D | three.js는 `src/components/hero3d/`에서만 import. `HERO_3D.md` 성능 예산과 대체 화면을 지키고, 3D 재질 색도 토큰만 |
| 개인정보 | 실명·생년월일시·질문·수신 이메일은 `packages/astro-crypto`로 암호화해 `*_ciphertext`에만. 로그와 LLM 요청에 평문 금지(LLM에는 `{{호칭}}` 토큰) |
| 수치 | 오행·십신·대운은 `packages/saju-engine` 값만. LLM 출력 수치는 버린다 |
| 코어 재정의 금지 | 플랜·크레딧·결제·잡·감사 테이블과 함수를 `astro`에 만들지 않는다. `core.*` ALTER 금지 |
| 수정 금지 | `D:/WorkSpace/platform/docs/products/_platform-core/`, `_supabase-modular/`의 다른 파일, 공용 렌더 서비스. 필요하면 06장 6절 요청 |
| 마이그레이션 | `supabase/`는 AS-06-001 담당만 수정 |
| 문구 | 01장 6.4절 금지 문구(가상 후기, 허위 수치, 의료·금융 단정) |

## 3. 디렉토리와 소유 경계

| 디렉토리 | 내용 | 소유 작업 |
|---|---|---|
| `packages/saju-engine/` | 만세력 엔진(SPEC, fixtures, src, scripts) | 004, 005, 024(`src/demo/`), 030 |
| `packages/astro-report/` | prompts, schema, rules / theme / templates / eval | 011 / 013 / 014 / 033 |
| `packages/astro-crypto/` | PII 암호화 | 006 |
| `apps/astro-ai/src/app/api/<폴더>/` | Route Handler | subjects·consents 007, billing 008, auth 009, readings 010, deliveries 016, admin 022, demo 024, account 026 |
| `apps/astro-ai/src/app/` 화면 | 화면 | (auth) 003, dashboard/subjects 018, dashboard/readings 020, dashboard 나머지 021, admin 022, (marketing) 023, legal 025 |
| `apps/astro-ai/src/components/` | 컴포넌트 | ui 017, chart 019, subjects 018, reading 020 |
| `apps/astro-worker/src/` | 워커 | index·generate·sweeper 012, render 015, delivery 016, purge 026, observability 034 |
| `supabase/` | migrations·tests | 001, 002 |
| `e2e/` | E2E | flows 028, billing 029, ai 054 |
| `apps/api/` | 공용 ai-service와 설정 042, `app/ai/products/astro/knowledge.py` 045, `wiki_config.py` 046, `app/ai/graphs/astro_reading.py`·`app/ai/compliance/astro.py` 048, `app/ai/tools/astro/` 049, `tests/astro/security/` 054 | 042, 045, 046, 048, 049, 054 |
| `apps/astro-ai/src/app/api/` AI·음성 | ai·internal·onboarding 043, voice 051(narrations 제외), voice/narrations 052, admin/wiki·admin/knowledge 046 | 043, 046, 051, 052 |
| `apps/astro-ai/src/app/` AI 화면 | onboarding 043, dashboard/chat 050, (marketing)/wiki 047, admin/wiki·admin/knowledge 046, dev/components 017 | 017, 043, 046, 047, 050 |
| `apps/astro-ai/src/components/` AI·3D | ai-chat 050, voice 051, narration 052, hero3d 053(`public/hero/` 포함) | 050~053 |
| `apps/astro-ai/src/server/ai/`, `src/server/ai-pricing.ts` | 서명 토큰, HMAC, 마스킹, AI 단가 | 043 |
| `content/knowledge/`, `scripts/knowledge/`, `scripts/ai-routing/`, `infra/dify/` | 해설집 044, 색인 045, 라우팅 스냅샷 054, Dify DSL 049 | 044, 045, 049, 054 |
| `docs/file/03-설계/디자인/` | `DESIGN.md` 1절 039, 2절 이후와 `COMPONENTS.md` 041, `review/` 040(사람) | 039, 040, 041 |

## 4. 코어 사용 규칙

| 항목 | 방법 |
|---|---|
| 세션 | 모든 Route Handler 첫 줄 `const ctx = await requireSession('astro')`. 조직은 `ctx.org.id`만 사용, 요청 본문의 `org_id` 무시 |
| 어드민 | `ctx.platform_role === 'platform_admin'` 확인 후 admin 클라이언트. 모든 쓰기 `auditAsService` |
| 크레딧 | `credits.consume({ appId: 'astro', idempotencyKey: 'consume:astro:<request_id>', ref: { type: 'reading', id } })`. 단가는 `src/server/pricing.ts` |
| 잡 | `jobs.enqueue({ queue: 'astro.reading', jobType: 'astro.reading.generate', creditLedgerId, idempotencyKey: 'job:astro:<request_id>', maxAttempts: 2 })` |
| 워커 | `runWorker` + `heartbeat`. 최종 실패는 `fail_job(retryable=false)`. 리딩 상태는 전이 표(05장 3절)대로만 |
| 사용자 RPC | `rpc('cancel_reading')`과 `rpc('set_ai_cross_border_ack')`(owner, 온보딩·설정). `preferences`만 사용자 세션으로 쓴다 |
| 레이트 리밋 | `src/server/ratelimit`(`core.rate_limit_hit`, 키 `astro:<route>:<id>`) |
| Storage | PDF는 `exports/<org_id>/astro/pdf/<uuid>.pdf`, 다운로드는 7일 서명 URL |
| 감사 | `subject.create/update/delete`, `reading.cancel/delete`, `account.export/delete`, `payment.refund`, `credits.admin_grant`, `delivery.retry` |
| 스키마 전환 | `SUPABASE_DB_SCHEMA`(core/public), `ASTRO_DB_SCHEMA`(astro/public) |
| AI 게이트 | `packages/ai-gateway` 사용. 대화는 `ai_conversations` 행을 먼저 만들고(`dify_user`=HMAC), 턴마다 대화 주인을 다시 확인. 서명 토큰은 `src/server/ai/token.ts`만 발급 |
| AI 라우팅 | FastAPI·음성 Route Handler가 `resolve_ai_route(org, 'astro', feature, kind)`(service_role)로 체인을 받는다. 제품 화면에서 `set_ai_routing`을 부르지 않는다 |
| 국외 이전 | 온보딩·설정에서 사용자 세션으로 `rpc('set_ai_cross_border_ack')` + `consents(overseas_transfer)` 같은 고지문 버전 |
| 음성 | `packages/core-voice`의 `VoiceAdapter`. `store_audio=false`. 첫 녹음 전 `consents(voice_processing)` 확인 |
| 그래프 | 워커는 `/api/internal/ai-token`으로 잡 토큰을 받아 `POST /graphs/astro.reading/runs`. FastAPI는 `ai_runs`·`ai_run_steps`·`ai_usage`를 기록하고 astro 표는 워커가 쓴다 |
| 위키·해설 | 운영자 지식 조직(`ASTRO_KNOWLEDGE_ORG_ID`)에만 둔다. 공개 위키는 `published`만 서버에서 읽는다. 쓰기는 FastAPI 경유 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16.2.x, React 19, Tailwind CSS v4(4.x), shadcn/ui(Tailwind v4 지원 버전), Zustand(리딩 스테퍼만), Node 22 워커, three.js + React Three Fiber + drei(React 19 호환 버전), FastAPI(Python 3.12 제안) + LangChain/LangGraph. `latest` 태그 금지, lockfile 커밋(Python은 `uv.lock` 또는 고정 requirements, 제안) |
| Python | `apps/api`: ruff, mypy(제안), pydantic 스키마는 `packages/astro-report/schema/chapter.schema.json`과 같게. 프롬프트·규칙 파일은 복사본을 고치지 않는다(원본 011 소유) |
| 런타임 | Route Handler는 `export const runtime = 'nodejs'`. Edge 금지 |
| 검증 | 모든 입력 zod `strict()`. `any` 금지 |
| 타입 생성 | `supabase gen types typescript --local --schema core,astro > apps/astro-ai/src/types/supabase.ts`(모놀리스는 `--schema public`) |
| 린트 | `pnpm lint`, `pnpm typecheck` |
| 디자인 토큰 | `apps/astro-ai/src/styles/tokens.css`(03장 4.3절, 3.2절 의미 기반 이름). 컴포넌트와 3D 재질에 hex 금지(`bg-[#...]` 린트 차단, 제안), 이모지 아이콘 금지(Lucide) |
| HTML | 리포트 템플릿은 모든 텍스트 escape, 외부 URL 0 |
| 오류 | 장애를 숨기지 않는다. 실패와 환불 여부를 사용자에게 보여 준다(03장 5절) |

## 6. 테스트와 완료 조건

| 명령 | 목적 |
|---|---|
| `pnpm --filter saju-engine test` | 골든 100건 |
| `node D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs --vector mod ...0000~0009 seed 1100_astro.sql` | 모듈러 SQL(AI 표가 있어 `--vector` 필수) |
| `node D:/WorkSpace/platform/docs/products/_tools-sqlcheck/check.mjs --vector mono 0001_core_lite.sql 0002_astro_domain.sql seed.sql` | 모놀리스 SQL |
| `pytest apps/api` | 토큰·조직 격리·라우팅·그래프·채팅 평가셋(042, 045, 048, 049, 054) |
| `pnpm test:ai` | AI 게이트 선차감·정산·환불, 낭독 대체 금지(043, 052, 054) |
| `pnpm test:rls` | RLS 회귀(AS-06-002) |
| `pnpm e2e` / `pnpm e2e:billing` | 핵심 5플로우 / Toss 테스트 키 결제 |
| `pnpm lhci` | 랜딩 Lighthouse |

완료 조건은 `06_AGENT_PLAN.md` 7절.

## 7. 금지 패턴

`07_SOURCE_MIGRATION.md` 4절 요약: 크레딧 RPC를 브라우저에서 호출, 읽고-빼고-쓰는 차감, 웹훅만으로 지급, 클라이언트 금액 신뢰, `FOR ALL` 정책, role 확인 없는 service_role 액션, broadcast 진행률, 업로드 CSS를 렌더러에 투입, QuickChart 같은 외부 렌더러로 개인정보 전송, 생년월일시 평문 저장, 메모리 레이트 리밋, `\b` 한글 금지어 매칭, Edge Function 생성 경로, Puppeteer, 가상 후기·평점·카운터. AI·디자인(2026-10-13): LLM·음성 키를 브라우저·Vercel·워커에 두기, 브라우저에서 Dify·FastAPI·제공자 직접 호출, Dify 입력에 토큰·개인정보, 생년월일 원문·실명 AI 전송, LLM의 격국·용신 판정과 수치 생성, 클라이언트 텍스트 그대로 TTS, 낭독 중 제공자 대체, 토큰 밖 3D 색·별 파티클, "Tailwind"만 적은 지시(v3 혼입).
