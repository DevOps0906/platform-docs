# 06 에이전트 작업 계획: FLORA Publishing

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 4장) 작업 17개(PB-06-039~055)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 001·002·005·008(수용 기준 보강), 011·012·013·014·019(LLM 호출 경로를 ai-service로), 021~024(선행에 042 추가, 024의 MASTER.md는 040으로 이동), 025·029·034·036·037·038(수용 기준 보강)이다. 2026-10-14 확정 결정 22(`docs/reference/00_MERGE_ANALYSIS.md:30`)로 PB-06-006의 범위를 인증 Stage A(Mock 로그인)로 바꾸고 인증 단계 작업 3개(PB-06-056 Stage B, 057 C1 카카오, 058 C2 네이버, 8절)를 더했으며 005·034·037(수용 기준)도 함께 고쳤다. 2026-10-14 FLORA 개편(검토용)으로 에이전트·운영 작업 7개(PB-06-059~065, 9절)를 더하고 002·009·022·023·024·027·029·037·039·040·041·044의 범위·수용 기준·소유 경로를 보강했다. 작업 수 65개(모델 작업 64)는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘어난 것이고, 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다.

작성일 2026-10-12. 작업 ID는 `PB-06-###`. 모델 기준은 `docs/file/03-설계/공용코어/DOC_TEMPLATE.md` 1장(Fable: 결제·권한·RLS·데이터 모델, Opus: 기능·API·테스트, Sonnet: UI·문서·설정, Haiku: 보일러플레이트·문구·체크). 경로는 앱 저장소 기준 `apps/flora-publishing/`를 생략해 `web/`, `worker/`, `engine/`, `api/`(FastAPI AI 서비스, 공용 ai-service의 `apps/api`)로 적는다. 개발 폴더에서는 `web/`→`apps/web`, `api/`→`apps/api`로 대응시킨다(`docs/develop/flora-publishing/flora-publishing_develop.md` 5절).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 디렉토리는 한 작업만 쓴다. 공용 파일(`web/package.json`, 레이아웃)은 PB-06-002만 수정하고, 다른 작업은 의존성 추가를 PB-06-002 담당에 요청하거나 같은 웨이브 종료 후 순차 반영 |
| Route Handler 분할 | `web/src/app/api/` 아래는 리소스 디렉토리별로 소유자가 다르다(2절 표). 한 작업이 다른 작업의 route 디렉토리에 파일을 만들지 않는다 |
| 서버 공용 코드 | `web/src/server/<영역>/`도 영역별 단일 소유. 다른 작업은 import만 한다 |
| 코어 불변 | `packages/core-*`, `_platform-core`, `_supabase-modular`의 다른 파일은 수정하지 않는다. 필요하면 6절 코어 요청 |
| SQL | DB 변경은 PB-06-001(Fable)만. 다른 작업이 컬럼이 필요하면 001에 요청 |
| AI 서비스 경계 | `api/`는 PB-06-043이 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. publishing 확장은 작업별로 나눈다: 045 `app/ai/products/publishing/knowledge.py`, 046 `wiki_config.py`, 047 `app/ai/graphs/publishing_draft.py`, 048 `app/ai/graphs/publishing_assist.py`·`app/ai/compliance/publishing.py`·`rules/`, 049 `app/ai/tools/publishing/`. 프롬프트 파일(`app/ai/products/publishing/prompts/`)은 PB-06-011 소유이고 FastAPI는 읽기만 한다 |
| 공용 AI 패키지 | `packages/core-ai`(`ai-gateway`), `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청(R8~R14) |
| 사람 작업 | PB-06-041(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(021~024, 050, 051, 052, 053, 054)은 PB-06-042(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:48`) |
| 장착 지점 | 에디터(PB-06-022)에 채팅 패널·마이크·낭독 버튼을 다는 코드는 050·052·053이 022 파일에 1줄씩 요청한다(022가 장착 지점을 제공) |
| 테스트 | 테스트 디렉토리는 테스트 작업이 소유(`supabase/tests/`, `web/tests/integration/`, `web/e2e/`, `engine/tests/`). 기능 작업은 자기 디렉토리 안 단위 테스트(`*.test.ts`, `test_*.py`)만 쓴다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| PB-06-001 | DB 조각 적용, 모놀리스 변환 스크립트, 타입 생성 | `supabase/migrations/`, `supabase/scripts/to_monolith.sh`, `supabase/seed.sql`, `web/src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, 변환 스크립트 결과가 `0002_publishing_domain.sql`과 diff 0, SQL 체커(`--vector`) OK 2종, AI 라우팅 기본값 12행과 free·basic AI 키 6개 적용(05장 9절) | SellingDocs 5장 #1, #4, 05장 9절 |
| PB-06-002 | web 골격(basic-master-module 기반 Next 16, core-db 연결, `proxy.ts`, env zod 검증, 저장소 CLAUDE.md) | `web/` 루트 설정(package.json, next.config.ts, tsconfig.json, eslint, Tailwind CSS v4 설정(`@import "tailwindcss"`, `tailwind.config.js` 없음)), `web/src/proxy.ts`, `web/src/lib/supabase/`, `web/src/lib/env.ts`, `web/src/app/layout.tsx`, `web/CLAUDE.md` | 없음 | P0 | M | Opus | 필수 env 하나 빠지면 `next dev`가 시작하지 않음. 미로그인 `/dashboard` → `/login`. TS strict, `latest` 의존성 0, `tailwind.config.js`·`@tailwind base` 0. 2026-10-14: 경로 그룹별 `data-surface`(`(marketing)` marketing, `(app)` workspace, `admin` ops) | SellingDocs 5장 #2, #3, flora-publisher 5장 #8, #10 |
| PB-06-003 | 엔진 골격(FastAPI, pydantic Settings, Python 잡 워커 루프, Dockerfile, 내부 토큰) | `engine/pyproject.toml`, `engine/Dockerfile`, `engine/app/main.py`, `engine/app/settings.py`, `engine/app/worker.py`, `engine/app/db.py`, `engine/app/auth.py` | 없음 | P0 | M | Opus | 토큰 없이 `/internal/*` 401, 빈 토큰·빈 JWT secret이면 기동 실패. 워커가 `claim_jobs('publishing.doc')` 루프로 빈 핸들러 잡을 complete | Flora-v2 5장 #1, #10, #11, #12, flora 5장 #1, #4, #6 |
| PB-06-004 | WeasyPrint 렌더 서비스(공용, 이 제품 소유) | `services/render-weasyprint/`(tests 제외) | 없음 | P0 | M | Opus | 한글 200쪽 HTML → 120초 안 PDF, 두부 0. `file://`·사설 IP 이미지 요청 시 렌더 실패. 폰트 없으면 헬스체크 실패 | SellingDocs 5장 #6, flora 5장 #3, #5, 분석:108 |
| PB-06-005 | CI(tsc, lint, build, pytest, SQL 체커, RLS 스모크, actionlint, 금지 문자열 검사) | `.github/workflows/flora-publishing.yml` | PB-06-002, PB-06-003 | P0 | S | Sonnet | PR마다 실행, 하나라도 실패하면 병합 불가. `flora_pro_unlocked`, `PasswordUnlock`, `/auth/v1/token` 문자열이 있으면 실패. 인증 단계 검사(`docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2.4절, 9장): 쿠키·localStorage 역할/플랜, `mock-auth`, `nomad_role`, `nomad_plan`, 인증 모듈 밖의 `AUTH_MODE` 참조(허용: `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/app/auth/`, `web/src/app/api/dev/login/`)가 있으면 실패, `AUTH_MODE=mock VERCEL_ENV=production npm run build`가 실패하는지 확인(PB-06-006 가드가 들어온 뒤 켠다). `api/` pytest·ruff, SQL 체커 `--vector`, `tailwind.config.js` 파일이 있으면 실패, 3D 번들 크기 예산 검사(제안) | Flora-v2 5장 #3, #13, flora 5장 #5, flora-publisher 5장 #4 |
| PB-06-006 | 인증 Stage A(2026-10-14 범위 변경): 인증 모듈 경계(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`), Mock 로그인(`POST /api/dev/login`, `/login` 개발용 패널, 상단 배지 `MOCK AUTH · 로컬 전용`), `scripts/dev/seed-users.mjs` + 제품 훅 `seed-users.publishing.mjs`(05장 10절), 가드(env zod, 404, 빌드 검사), `finishLogin`의 `next` 화이트리스트. 이메일 가입·메일 인증·비밀번호 재설정 화면과 Google·콜백 라우트는 B(PB-06-056)로 옮겼다 | `web/src/lib/auth/`, `web/src/app/api/dev/login/`, `web/src/app/(auth)/login/`(A 구성, 056이 이어 받음), `web/src/components/dev-auth/`, `scripts/dev/` | PB-06-001, PB-06-002 | P0 | M | Fable | `owner` 페르소나 로그인 → `/dashboard`, 새로고침 유지, `session_context('publishing')` `entitled=true`·`plan_code='free'`·잔액 20. `no_app` 로그인 → `finishLogin`이 `bootstrap_app_for_org` 1회(모듈러), 재로그인 3회 뒤 가입 크레딧 원장 1행. `outsider`로 owner 조직 `books` 0행. `finishLogin` 단위 테스트 `next=//evil.com`·`https://evil.com`·`/\evil.com` → `/dashboard`. `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404·개발용 패널 미렌더. 시드 스크립트가 원격 URL이면 exit 1, 2회 실행해도 크레딧 1회. 인증 모듈 밖 `AUTH_MODE` 참조 0 | Flora-v2 5장 #1, SellingDocs 5장 #3, PB-F-001, PB-F-002, AUTH_ROADMAP 2장, 3.1·3.2절 |
| PB-06-007 | API 공통(apiFetch, `requireSession` 래퍼, 응답 봉투, request_id, SQLSTATE → HTTP 매핑, 레이트 리밋) | `web/src/lib/api/`, `web/src/server/http/` | PB-06-002 | P0 | M | Opus | 모든 route가 래퍼를 거치는지 린트 규칙으로 검사. 401/402/403/409 매핑 표대로 응답 | Flora-v2 5장 #1, #11, flora 5장 #1, #10, PB-F-003 |
| PB-06-008 | 크레딧 단가표, features 해석기, 원가 재산정 | `web/src/server/pricing/`, `web/src/server/features/` | PB-06-001 | P0 | M | Fable | `priceOf('publishing', action)`이 01장 4.3절과 같고, 키 없는 features는 Free 기본값(AI 키 6개 포함, 01장 4.4절). AI 단가 상수(4.6절)는 `ai-pricing.ts`(PB-06-044)와 같은 값인지 테스트. 토큰 원가 표로 단가 재검증 보고 1건 | Flora-v2 5장 #2, flora 5장 #8, SellingDocs 5장 #4, PB-F-034 |
| PB-06-009 | Toss 결제(팩 주문, confirm, 빌링키, 구독 해지, Toss 웹훅, 결제 화면) | `web/src/app/api/billing/`, `web/src/app/api/webhooks/toss/`, `web/src/app/(app)/dashboard/billing/`, `web/src/features/billing/` | PB-06-007, PB-06-008 | P0 | L | Fable | 테스트 키로 팩 결제 → grant 1행, 같은 confirm 재호출 → 지급 1회, 금액 조작 → `PM001` + 취소 요청, 위조 웹훅 401. 2026-10-14: 사용량·결제 화면에 에이전트별 사용량(원장 `ref_type='agent_task'` → `agent_tasks.agent_key` 묶음, 대화형은 따로) | Flora-v2 5장 #2, flora 5장 #2, SellingDocs 5장 #13, PB-F-035 |
| PB-06-010 | 책 CRUD, 위저드 영속화(debounce 2초), 휴지통·복구, 시드 복제 | `web/src/app/api/books/route.ts`, `web/src/app/api/books/[id]/route.ts`, `web/src/app/api/books/[id]/restore/`, `web/src/app/api/seeds/`, `web/src/server/books/`, `web/src/data/seeds/` | PB-06-007 | P0 | M | Opus | 새 책마다 고유 id, 7단계에서 닫고 다시 열면 같은 상태. Free 4번째 책 409 `PB001` | Flora-v2 5장 #7, flora 5장 #13, PB-F-006, PB-F-029, PB-F-030 |
| PB-06-011 | 기획 LLM API(제목, 기획안, 목차, 구조 저장)와 프롬프트 이식(v1·v2) | `web/src/app/api/books/[id]/titles/`, `.../plans/`, `.../toc/`, `.../structure/`, `api/app/ai/products/publishing/prompts/`(언어 중립 md·json, FastAPI는 읽기만) | PB-06-007, PB-06-008, PB-06-012, PB-06-044, PB-06-048 | P0 | M | Opus | 각 호출 선차감, JSON 스키마 위반 1회 재시도 후 환불. 구조 저장이 플랜 한도 초과 시 409 + 초과 목록. 호출은 `publishing.assist` 그래프(PB-06-048)를 거치고 web에 LLM 키 0 | SellingDocs 5장 #5, flora 5장 #1, PB-F-013~015 |
| PB-06-012 | 페르소나 60종 JSON 단일 소스, Taste 합성, 페르소나 합성 API | `web/src/data/personas.json`, `web/src/server/personas/`, `web/src/app/api/personas/` | PB-06-007 | P0 | M | Opus | 60종 모두 문체 지시 비어 있지 않음(테스트). Free 41번째 페르소나 사용 시 403. 합성은 Basic만, 3크레딧. 합성 호출은 `publishing.assist`(PB-06-048)에 연결하고 연결 전에는 계약 테스트 더블로 검증 | Flora-v2 5장 #8, PB-F-009, PB-F-011, PB-F-033 |
| PB-06-013 | 섹션 단건 스트리밍 생성, 보조 집필(이어/살/다듬기), 섹션 PATCH, 서버 sanitize | `web/src/app/api/books/[id]/sections/`, `web/src/app/api/books/[id]/assist/`, `web/src/server/sanitize/` | PB-06-011 | P0 | L | Opus | 연결이 끊겨도 본문 저장. `<script>`·`on*` 제거 단위 테스트. 생성 중 PATCH 409 `PB005`. revision 충돌 409. 생성 호출은 `publishing.assist`를 거치고 스트림 첫 토큰 p95 5초(그래프 SSE 미지원 시 01장 D13 대체 동작) | Flora-v2 5장 #5, SellingDocs 5장 #5, #9, flora 5장 #7, PB-F-016, PB-F-018 |
| PB-06-014 | TS 워커: write_all(챕터 순차), write_section(잡 토큰으로 그래프 `publishing.draft` 호출, 재시도 3), refine_all/chunk, 취소 처리, 실행 API | `worker/src/handlers/write-*.ts`, `worker/src/handlers/refine-*.ts`, `worker/src/main.ts`, `web/src/app/api/books/[id]/write-all/`, `.../refine-all/`, `web/src/app/api/generation-runs/` | PB-06-013, PB-06-044, PB-06-047 | P0 | L | Opus | 15섹션 중 2개 강제 실패 → `partial`, 차감 = 성공분(소제목당 2/4). 챕터 자식 잡마다 `ai_runs.job_id`가 일치하고 워커 환경변수에 LLM 키 0. 취소 후 60초 안 신규 섹션 0. 3만 자 다듬기 → 청크 15개 결과 15개 | Flora-v2 5장 #5, #10, flora 5장 #4, #7, SellingDocs 5장 #5, PB-F-017, PB-F-019 |
| PB-06-015 | 원고 업로드(서명 URL, 완료 검증, 파싱 잡, 파서 4종, 책 생성) | `engine/app/parsers/`, `engine/app/jobs/parse_manuscript.py`, `web/src/app/api/uploads/` | PB-06-003, PB-06-007 | P0 | M | Opus | 25MB 413, 위장 확장자 415, md·docx·txt·pdf 샘플 4종의 챕터 수가 기대값과 같음. 원본은 24시간 뒤 삭제 | Flora-v2 5장 #4, flora 5장 #3, SellingDocs 5장 #9, PB-F-027, PB-F-028 |
| PB-06-016 | HTML 조립(v1 템플릿 이식, escape, nh3 재-sanitize), 판형 프리셋 → @page CSS, 미리보기 | `engine/app/html/`, `engine/app/presets/`, `engine/app/routes/preview.py`, `web/src/data/formats.json`, `web/src/app/api/books/[id]/preview/` | PB-06-003 | P0 | L | Opus | 6판형 골든: 미리보기와 PDF 첫 3쪽 줄바꿈 일치. 안쪽 여백 ≥ 바깥 + 3mm. 제목 `<script>` escape | flora 5장 #7, SellingDocs 5장 #8, Flora-v2 5장 #6, PB-F-007, PB-F-023 |
| PB-06-017 | PDF 내보내기(`render.pdf` 잡, 워터마크 강제, 월 한도, content_hash 재사용, 다운로드) | `engine/app/jobs/render_pdf.py`, `web/src/app/api/books/[id]/exports/`, `web/src/app/api/exports/` | PB-06-004, PB-06-016, PB-06-008 | P0 | M | Opus | Free가 워터마크 끄기 요청해도 워터마크. Free 3번째 403. 같은 해시 재요청 0크레딧. 렌더 실패 시 환불 1행 | Flora-v2 5장 #6, SellingDocs 5장 #6, PB-F-024, PB-F-026 |
| PB-06-018 | ePub3 빌더 이식(escape, uuid5, 표지, nav, 폰트) | `engine/app/epub/`, `engine/app/jobs/export_epub.py` | PB-06-016 | P0 | M | Opus | epubcheck 오류 0, 같은 책 2회 `dc:identifier` 동일, `&`·`<` 포함 제목 정상 | Flora-v2 5장 #6, flora 5장 #13, SellingDocs 5장 #7, PB-F-025 |
| PB-06-019 | 표지 3후보(fal 비동기, 웹훅, Storage 복사, 부분 환불) | `worker/src/handlers/cover.ts`, `web/src/app/api/books/[id]/covers/`, `web/src/app/api/webhooks/fal/` | PB-06-007, PB-06-008, PB-06-044, PB-06-048 | P0 | M | Opus | 1장 실패 시 2크레딧 환불, 다른 책 표지 선택 `PB006`. 이미지 URL은 Storage 경로만 | Flora-v2 5장 #9, PB-F-021 |
| PB-06-020 | 책 정보 생성(DB 원고 기반, ISBN 참조용) | `web/src/app/api/books/[id]/metadata/` | PB-06-011 | P1 | S | Opus | 원고 없는 책 409. 생성 프롬프트에 DB 제목·기획안·원고 앞 3,000자가 들어감(로그) | Flora-v2 5장 #8, PB-F-022 |
| PB-06-021 | 위저드 UI 10단계(진행바, 단계 컴포넌트 v2 이식, 판형·장르·페르소나·제목·기획·목차·표지·정보) | `web/src/features/wizard/`, `web/src/app/(app)/books/[id]/wizard/` | PB-06-010, PB-06-011, PB-06-042 | P0 | L | Sonnet | 375/1440px 깨짐 없음, 완료 단계만 이동, 비용 라벨 표시, 402 모달 | Flora-v2 5장 #7, flora 5장 #9, PB-F-006~015 |
| PB-06-022 | 원고 에디터(Tiptap, 플로팅 툴바, `/` 명령, Diff 카드, 섹션 상태 Realtime, 2026-10-14 3단 레이아웃: 목차·원고·AI 패널 슬롯, 1279px 이하 접힘, 03장 8.4절) | `web/src/features/editor/`, `web/src/app/(app)/books/[id]/editor/` | PB-06-013, PB-06-014, PB-06-042 | P0 | L | Opus | 선택 → 다듬기 → Diff 대체 → 저장 후 revision+1. 생성 중 섹션 읽기 전용. 자동 저장 2초. 채팅 패널·마이크·낭독 버튼 장착 지점 제공 | flora 5장 #9, SellingDocs 5장 #9, PB-F-018 |
| PB-06-023 | 대시보드(2026-10-14 사이드바: 홈, 내 책, AI 에이전트, 페르소나, 사용량·결제, 설정, 검수 배지. 03장 8.4절), 책 목록·휴지통, 완성/내보내기 화면(검토 전 AI 초안 수 확인 모달), 페르소나 보관함, 설정(테마) | `web/src/app/(app)/dashboard/`(billing/, settings/webhooks/, chat/, agents/ 제외), `web/src/app/(app)/books/[id]/finish/`, `web/src/features/{books,finish,personas,settings}/`, `web/src/app/api/settings/` | PB-06-010, PB-06-017, PB-06-042 | P0 | M | Sonnet | 빈 상태 문구, Pro 테마 잠금 표시, 사이드바 모바일 드로어, 내보내기 기록 만료 표시 | flora-publisher 5장 #9, #11, SellingDocs 5장 #10, PB-F-010, PB-F-030~032 |
| PB-06-024 | 메인페이지(랜딩, 2026-10-14 섹션 6개: 03장 8.3절), 요금 페이지와 FAQ(디자인 시스템 MASTER.md는 PB-06-040으로 이동) | `web/src/app/(marketing)/`(legal/ 제외), `web/src/features/landing/` | PB-06-016, PB-06-042, PB-06-054 | P0 | M | Sonnet | 03장 4절 토큰·와이어프레임 A안, DP 7단계 체크리스트 12항목 통과, 허위 수치·가상 후기 0, 히어로에 PB-06-054 장착(`HERO_3D.md` 4절 수용 기준 확인) 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/file/03-설계/디자인/REFERENCES.md:16-23`). | SellingDocs 5장 #10, 분석:158, PB-F-037 |
| PB-06-025 | 법무 페이지 5종 문구(약관, 처리방침, 환불, AI 고지, 사업자 정보) | `web/src/app/(marketing)/legal/`, `web/content/legal/` | PB-06-002 | P0 | S | Haiku | 01장 6절 항목 전부 반영, 법무 검토 표시 문구 포함, 국외 이전 표(AI·음성 제공자 포함), 상용 AI 국외 이전 고지문·음성 처리 고지문과 버전 상수, AI 생성 표시 문구, Dify 로그 보존 30일 | PB-F-039, 분석:214 |
| PB-06-026 | 아웃바운드 웹훅(등록, 비밀 vault, HMAC 발송, 재시도, 비활성) | `web/src/app/api/webhook-endpoints/`, `worker/src/handlers/webhook-deliver.ts`, `web/src/app/(app)/dashboard/settings/webhooks/` | PB-06-014, PB-06-017 | P1 | M | Opus | 사설 IP URL 422, 수신 측 서명 검증 성공, 5회 실패 후 failing | 분석:139, PB-F-036 |
| PB-06-027 | 운영 콘솔 기반(2026-10-14 범위 조정): 운영자 레이아웃·가드(`data-surface` 속성은 002가 붙인다), 운영 홈, 사용자·권한(정지·복구), 결제·수동 크레딧 조정 + 감사, 감사 로그 화면, 조회 감사 `admin.view` 미들웨어 | `web/src/app/admin/`(layout, page, `users/`, `billing/`, `audit/`), `web/src/app/api/admin/`(`overview/`, `users/`, `credits/`, `audit/`), `web/src/server/admin/` | PB-06-008 | P1 | M | Fable | 일반 사용자 `/admin/*` 404, 조정 1건 = audit 1행, 사유 10자 미만 422, 운영자 조회마다 `admin.view` 1행, 운영 홈 값이 없으면 숫자 대신 "—"(가짜 숫자 0), 자기 계정 정지 409 | Flora-v2 5장 #2(관리자 하드코딩 제거), PB-F-005 |
| PB-06-028 | 대기자 명단 API(레이트 리밋, 실제 카운트) | `web/src/app/api/waitlist/` | PB-06-007 | P1 | S | Haiku | 같은 이메일 2회 200, IP 6회째 429, 카운트 = 행 수 | flora 5장 #12, PB-F-004 |
| PB-06-029 | RLS/권한 회귀 테스트(05장 9절 57항목 + `SECURITY_BASELINE.md` 15장) | `supabase/tests/` | PB-06-001 | P0 | M | Fable | 모듈러·모놀리스 모두 통과, CI에서 실행. AI 코어 항목 추가: 타인 대화·메시지·`voice_jobs` 0행, `ai_chunks` SELECT 42501, `resolve_ai_route`·`match_ai_chunks` authenticated 호출 42501, 다른 조직 위키·문서 0행. 2026-10-14 `agent_tasks` 항목(05장 9절 끝): 타 조직 0행, 사용자 쓰기 42501, 타 조직·viewer의 `decide_agent_task` 42501, 재시도 규칙 `PB013`·23505 | SellingDocs 5장 #4, Flora-v2 5장 #2, flora 5장 #2, #8 |
| PB-06-030 | 결제 E2E(Toss 테스트 키: 팩, 구독, 정기결제 실패 → past_due, 해지, 환불) | `web/e2e/billing/` | PB-06-009 | P0 | M | Opus | 시나리오 5개 통과, 원장 drift 0 | SellingDocs 5장 #13, flora 5장 #2 |
| PB-06-031 | web 통합 테스트(무토큰 401, 402, 크레딧 동시성 50회, 쿼터, 생성 실패 환불, 내보내기 한도) | `web/tests/integration/` | PB-06-013, PB-06-017 | P0 | M | Opus | 동시 50회 consume 음수 0, drift 0, 실패 경로마다 환불 행 확인 | SellingDocs 5장 #14, Flora-v2 5장 #14 |
| PB-06-032 | 엔진·렌더 테스트(파서, escape, url_fetcher SSRF, 한글 골든 PDF, epubcheck) | `engine/tests/`, `services/render-weasyprint/tests/` | PB-06-004, PB-06-015, PB-06-016, PB-06-018 | P0 | M | Opus | 테스트 30개 이상(제안) 녹색, SSRF 케이스 6종(file, 169.254, 10.x, localhost, 리다이렉트, http) 모두 실패 처리 | Flora-v2 5장 #14, flora 5장 #3 |
| PB-06-033 | 원본 아카이브, 키 재발급 체크리스트, FP·v1 잔재 정리 | `archive/`(이동 대상 4개 폴더), `docs/flora-publishing/ops/key-rotation.md` | PB-06-021 | P1 | S | Haiku | 07장 5절 절차 완료, 재발급 대상 키 목록 4종 처리 기록 | flora 5장 #14, #15, flora-publisher 5장 #1~#7, #12, Flora-v2 5장 #12 |
| PB-06-034 | 배포 설정(Vercel, Railway 서비스(worker, engine, render, api), private network, env 문서) | `infra/flora-publishing/`, `docs/flora-publishing/ops/env.md` | PB-06-003, PB-06-004, PB-06-043 | P0 | S | Sonnet | 배포 환경은 Mock 금지(`AUTH_MODE=live`)이므로 Stage A 동안은 스테이징 헬스체크·로그인 없는 화면까지 확인하고, 스테이징 가입 → PDF 1회 성공은 PB-06-056 완료 후 확인. env 문서 = 02장 8절 + 9.3절(`AUTH_MODE`, `AUTH_PROVIDERS`) | Flora-v2 5장 #13, flora 5장 #5 |
| PB-06-035 | 공개 책 페이지와 Book JSON-LD(Phase 2) | `web/src/app/(public)/b/`, `web/src/app/api/books/[id]/visibility/` | PB-06-023 | P2 | S | Sonnet | 미완성 공개 `PB009`, anon은 공개 컬럼만, JSON-LD 검증 통과 | SellingDocs 5장 #12, PB-F-040 |
| PB-06-036 | 탈퇴·데이터 삭제와 purge 잡(휴지통, 업로드 원본, 만료 내보내기, 조직 30일) | `web/src/app/api/account/`, `worker/src/handlers/purge.ts` | PB-06-014, PB-06-017 | P1 | M | Fable | 삭제 요청 30일 뒤 조직 행 0, Storage 객체 0, 감사 기록 남음. 책 영구 삭제 시 컬렉션 `book-<id>`·설정집 페이지(`purge_wiki_page`)·낭독 파일 0 | 분석:217, PB-F-038 |
| PB-06-037 | E2E 핵심 플로우(가입 → 10단계 → PDF/ePub, 업로드 경로, 전체 생성 취소) | `web/e2e/flows/` | PB-06-021, PB-06-022, PB-06-023, PB-06-050 | P0 | M | Opus | Mock 페르소나 storageState로 실행(Playwright `globalSetup`이 페르소나마다 `/api/dev/login`, 로컬 Supabase). 플로우 3개가 Mock으로 로컬 통과(G1 근거, 가입 단계는 `owner`·`no_app` 첫 로그인으로 대체), 056 완료 후 스테이징에서 다시 통과(이메일 가입 경로 추가, Google 실로그인은 056 수동 점검표), 로그인 새로고침 유지 확인. 가입 플로우에 온보딩 AI 동의 포함, AI 채팅 1턴(목 제공자) 시나리오 1개 추가, 3D 히어로 3종(PC·태블릿·모바일) 렌더 스모크. 2026-10-14: 챕터 초안 → 검수 대기 → 일부 승인(제안 반영 + 빈 소제목 초안 승인·거부) → 내보내기 확인 모달의 "검토 전 AI 초안 N개" 시나리오(목 제공자). 작업 불변식: 01장 4.3·4.6절 유료 작업형 동작을 1번씩 실행해 동작마다 `agent_tasks` 정확히 1행, 원장 `ref_id=<작업 id>` 합계 = `credits_used`, 같은 `request_id` 재전송 새 행 0, 재시도는 재시도 범위만 차감(PB-06-059 수용 기준의 E2E 확인) | Flora-v2 5장 #1, 03장 2절 |
| PB-06-038 | 문구 사전, 금지 문구·접근성 체크리스트 점검 | `web/src/copy/`, `docs/flora-publishing/checklists/` | PB-06-024 | P1 | S | Haiku | 01장 6절 금지 문구 검색 0건, 이모지 아이콘 0, 대비 4.5:1, AI 생성 표시 문구(채팅·음성·제안 카드) 점검 | flora-publisher 5장 #11, 03장 6절 |
| PB-06-039 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Atlassian 주 + Primer 보조, 채팅 Astryx 패턴 확인, 랜딩 HERO_3D), 가져올 것과 안 가져올 것. 2026-10-14: 레이어 3종(marketing, workspace, ops) 브리프(03장 8.2절), 외부 제안서 레퍼런스 후보 원본 URL 확인(03장 8.3절 끝), 01장 D23~D25 비교 자료(두 팔레트·두 서체 시안 1장씩) | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D17). 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/file/03-설계/디자인/REFERENCES.md:39` flora-publishing 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| PB-06-040 | 디자인 시스템 2단계: Tailwind CSS v4 토큰(`tokens.css` `@theme`, 라이트/다크, 화면 테마 7종 `data-theme`, 2026-10-14 레이어 `data-surface` 3종 오버라이드), MASTER.md, 기본 UI 컴포넌트와 배리언트, 미리보기 `/dev/components`(레이어 3종 × 라이트/다크) | `web/src/styles/`, `web/src/components/ui/`, `web/src/app/dev/components/`, `design-system/flora-publishing/` | PB-06-002, PB-06-039 | P0 | M | Sonnet | 03장 4.3절 토큰만 사용(hex 하드코딩 0), 03장 3.2절 기본 컴포넌트 전부 라이트/다크 미리보기, `tailwind.config.js`·v3 문법 0, Tailwind 4.x 고정, `COMPONENTS.md` 배리언트 표 초안, 대비 4.5:1, 화면 테마 7종 중 Pro 4종 잠금은 DB(`PB008`)가 강제함을 확인 | DESIGN_PRINCIPLES 3~5단계, DESIGN_SYSTEM 4장 2단계 |
| PB-06-041 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | PB-06-040 | P0 | M | 사람(보조 Sonnet) | 03장 3.2절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인, 다크 팔레트 확정. 01장 D23(팔레트)·D24(서체) 결정과 근거 스크린샷 기록(2026-10-14). 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| PB-06-042 | 디자인 시스템 4단계: 코드(Tailwind CSS v4의 CSS + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | PB-06-041 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| PB-06-043 | AI 서비스 설치: `api/`에 공용 ai-service 적용, publishing 설정(app, 컬렉션 이름 규칙), JWKS 검증, 라우터·국외 동의 필터·오픈소스 전용 책 필터 연동 테스트 | `api/`(`app/ai/graphs/`, `app/ai/tools/publishing/`, `app/ai/compliance/publishing.py`, `app/ai/products/publishing/` 제외), `api/tests/platform/` | PB-06-001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 책 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 오픈소스 전용 책 호출에 상용 0(R8 전까지 ai-service 체인 필터), 필수 변수 누락 시 기동 실패 | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| PB-06-044 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰·잡 토큰 발급, 정산 크론, AI 단가, 온보딩 국외 이전 동의, 책 오픈소스 전용 스위치 API | `web/src/app/api/ai/`, `web/src/app/api/internal/`(`agent-sync/` 제외, 059 소유), `web/src/app/api/onboarding/`, `web/src/app/onboarding/`, `web/src/app/api/books/[id]/ai-privacy/`, `web/src/server/ai/`, `web/src/server/ai-pricing.ts` | PB-06-007, PB-06-043 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 잡 토큰은 running 잡과 허용 `job_type`에만(다른 상태 409), 동의 시 `ai_org_settings`·감사 버전 일치, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 스위치가 켜진 책의 호출이 오픈소스만 쓰는지 확인 | PB-F-044, 049, 053, 056 |
| PB-06-045 | 책별 RAG: 컬렉션 생성 규칙, 참고 파일 업로드·파싱·색인, 원고 스냅샷 색인, 삭제, 검색 평가셋 40문항 | `api/app/ai/products/publishing/knowledge.py`, `api/scripts/knowledge/`, `api/tests/publishing/retrieval/`, `engine/app/jobs/parse_reference.py`, `web/src/app/api/books/[id]/references/` | PB-06-015, PB-06-043, PB-06-044 | P0 | M | Opus | 책 A 질의가 책 B 컬렉션 청크 0, 다른 컬렉션 id 요청 42501, 재현율@8 0.8 이상(제안), 컬렉션당 임베딩 모델 1종, `rag_files_max` 초과 403, 원문 24시간 뒤 삭제, 색인 실패 문서 `failed` + 환불, 소제목 저장 후 바뀐 것만 재색인 | PB-F-045 |
| PB-06-046 | 책 설정집 위키: 만들기(ingest, draft), 채택·편집(사람 소유 표시, `expected_version`), 점검(lint) Route Handler와 FastAPI 설정 | `api/app/ai/products/publishing/wiki_config.py`, `web/src/app/api/books/[id]/wiki/`, `api/tests/publishing/wiki/` | PB-06-045 | P0 | M | Opus | 새 페이지 draft, 출처 없는 페이지 채택 409, 사람 소유 표시 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, lint 결과 반환, 모든 쓰기 감사 1행, `derived_from_pii` 페이지 처리의 상용 제공자 0, 다른 책 slug 404 | PB-F-046, LLM_WIKI 3장 |
| PB-06-047 | LangGraph 그래프 `publishing.draft`(outline → draft → consistency → proofread → compliance), 체크포인트, 실행 기록, 출력 스키마, 초안 품질 평가셋 20건 | `api/app/ai/graphs/publishing_draft.py`, `api/tests/publishing/graph/`, `api/eval/publishing/` | PB-06-043, PB-06-045, PB-06-048 | P0 | L | Opus | 챕터 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 설정집과 어긋난 이름·시제 시드 충돌 100% 메모 또는 재작성 후 통과, 교정 의미 변경 15% 초과 시 거부, 본문 있는 소제목은 제안으로만 반환, 2회 연속 compliance 실패 시 해당 소제목 실패, 평가셋 20건을 상용·오픈소스 경로 모두 통과 | PB-F-047 |
| PB-06-048 | LangGraph 그래프 `publishing.assist`(compose → generate → compliance), 단건 생성 purpose 어댑터, compliance 규칙 파일 | `api/app/ai/graphs/publishing_assist.py`, `api/app/ai/compliance/publishing.py`, `api/app/ai/products/publishing/rules/`, `api/tests/publishing/assist/` | PB-06-043 | P0 | M | Opus | PB-F-013~022 계약(JSON 스키마, 청크 수 = 결과 수) 회귀 통과, 규칙 단위 테스트(실존 작가 사칭, 보장 표현, 의료·금융·법률 단정, 참고 파일 30어절 일치, 위기 신호 5문장), 규칙 평가셋 30문항 위반 0, 사전에 없는 프롬프트 키는 오류, `personas.json` 사본(api)이 web 원본(`web/src/data/personas.json`)과 해시 일치 | PB-F-048, 054 |
| PB-06-049 | Dify `publishing-chat`(질문 분류, HTTP 노드)와 `/tools/answer` publishing 확장(책 컨텍스트 로더, 모드 book/craft, 마스킹, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `api/app/ai/tools/publishing/`, `api/tests/publishing/chat/` | PB-06-044, PB-06-045, PB-06-046, PB-06-048 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `book_id` 403, 답변 출처 1개 이상 또는 `no_source`, 평가셋 금지 문구 0·위기 신호 5문장 안내, 오픈소스 전용 책 상용 0, DSL에 키 0 | PB-F-049, 054, 04장 6.2절 |
| PB-06-050 | 채팅 패널과 대화 목록(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 책 바인딩, 본문에 넣기 Diff) | `web/src/features/ai-chat/`, `web/src/app/(app)/dashboard/chat/` | PB-06-042, PB-06-044 | P0 | M | Sonnet | 03장 3.1절 구성, 375px 전체 화면 시트, `aria-live`, 402 충전 모달, 대체·근거 없음·환불·오픈소스 전용 상태 표시. 에디터 장착은 PB-06-022 파일에 1줄 요청 | PB-F-049, 03장 5절 |
| PB-06-051 | 설정집·자료 화면(분류 트리, 페이지 편집기, 채택, 변경 이력, 점검 결과, 자료 탭, 일관성 메모) | `web/src/features/wiki/`, `web/src/app/(app)/books/[id]/wiki/` | PB-06-042, PB-06-046 | P0 | M | Sonnet | 03장 3.1절 구성, 상태 배지 draft/published/archived, 출처 없는 페이지 채택 버튼 비활성, 버전 충돌 모달, 개인정보 표시 | PB-F-045, 046, 047 |
| PB-06-052 | 음성: `/api/voice/*`(consent, sessions, stt, tts), 받아쓰기(연속 모드, 받아쓰기 초안), 채팅 마이크·읽어 주기 | `web/src/app/api/voice/`(`narrations/` 제외), `web/src/features/voice/` | PB-06-044, PB-06-050 | P0 | M | Opus | 고지 미확인 STT 403, 구간 120초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 입력 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지만, 오픈소스 전용 책은 오픈소스 음성만. 에디터 장착은 PB-06-022 파일에 1줄 요청 | PB-F-050, 051 |
| PB-06-053 | 원고 낭독·오디오북 미리듣기: `/api/voice/narrations`(선차감, 구간 TTS, 제공자 고정·대체 금지, Storage 저장, 정산)와 플레이어 | `web/src/app/api/voice/narrations/`, `web/src/features/narration/` | PB-06-013, PB-06-044, PB-06-052 | P0 | M | Opus | 한 낭독의 `ai_usage` 제공자 1종·`fallback_from` null, 3구간째 강제 실패 테스트에서 파일 0 + 환불 1행, 같은 본문 재요청 차감 0, 미동의 조직·오픈소스 전용 책은 처음부터 oss-voice, 8,000자 초과 413, Free 403, 소제목·책 삭제 경로에 낭독 파일 포함(036) | PB-F-052 |
| PB-06-054 | 3D 히어로: 원고 낱장 → 제본 → 책장 넘김(PC·태블릿), 책 한 권 회전 + 2D 제본(모바일), 정지 이미지 대체, 성능 예산 | `web/src/features/hero3d/`, `web/public/hero/` | PB-06-042 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 보라 그라디언트·크림 배경 0 | PB-F-055, 03장 4.6절 |
| PB-06-055 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 오픈소스 전용 책, 선차감·정산·환불, 라우팅 seed 스냅샷) | `api/tests/publishing/security/`, `web/e2e/ai/`, `scripts/ai-routing/` | PB-06-044, PB-06-047, PB-06-049, PB-06-052, PB-06-053 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 10개 × 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, 오픈소스 전용 책 상용 0, 원장 drift 0, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 003, 004, 039 | 5 | 없음 | DB 조각 적용(AI 기본값 포함), 타입, web·엔진·렌더 골격, 디자인 레퍼런스(1단계) |
| W1 | 005, 006, 007, 008, 016, 025, 029, 043 | 8 | W0 완료 | CI, 인증, API 공통, 단가·features, HTML/프리셋, 법무 문구·고지문, RLS 테스트, AI 서비스 설치 |
| W1-D | 040 → 041 → 042(직렬) | 1 | 002, 039 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 009, 010, 012, 015, 017, 018, 028, 034, 044, 048, 054, 059 | 12 | W1 완료, 054는 042 | 결제, 책 CRUD, 페르소나, 업로드, PDF, ePub, 대기자, 배포, AI 게이트, 단건 생성 그래프, 3D 히어로, 에이전트 실행 계층 |
| W3 | 011, 013, 019, 020, 024, 027, 045 | 7 | 010, 012, 044, 048 완료, 화면은 042 | 기획 LLM, 섹션 생성, 표지, 책 정보, 랜딩, 운영자, 책별 RAG |
| W4 | 021, 023, 030, 031, 032, 046, 047, 050, 062, 063 | 10 | 013, 017, 045 완료, 062는 027 | 위저드 UI, 대시보드, 결제 E2E, 통합·엔진 테스트, 설정집 위키, 초안 그래프, 채팅 패널, 운영 콘솔 확장, 헤드라인 실험 |
| W5 | 014, 033, 038, 049, 051, 052, 060 | 7 | W4 완료 | 전체 생성 워커(그래프 연결), 아카이브, 문구 점검, Dify 채팅, 설정집 화면, 음성, 에이전트 작업 공간 |
| W6 | 022, 026, 036, 053 | 4 | W5 완료 | 에디터(3단 레이아웃 포함), 웹훅, 탈퇴, 낭독·미리듣기 |
| W7 | 056(G1 통과 후 먼저), 037, 055, 061 | 4 | W6 완료. 056은 G1 통과(`[DECISION] G1 통과`) 후 시작하고 037·055의 공개 베타 마무리(스테이징·B 구성 재실행)는 056 완료를 기다린다. G1 근거인 Mock 핵심 플로우 E2E는 037이 W6 종료 직후 로컬에서 먼저 녹색으로 만든다(8.2절) | Google 로그인 전환(Stage B), E2E, AI 보안 회귀, 에디터 AI 패널(061, P1이라 출시 조건 아님). MVP 출시(공개 베타) 조건 |
| W8 | 035, 057(G2 통과 후), 058(G2 통과 후), 064, 065 | 5 | MVP 출시 후. 057·058은 G2 통과(`[DECISION] G2 통과`) 후, 둘은 병렬 가능(네이버 검수 신청은 G2 직후) | 공개 책 페이지(Phase 2), 카카오 로그인(C1), 네이버 로그인(C2), 워크플로 빌더·콘텐츠 에이전트(Phase 2) |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 13 (001, 006, 008, 009, 027, 029, 036, 043, 044, 055, 056, 058, 062) | 20.3% | 28 / 127 = 22.0% |
| Opus | 33 (기존 30 + 059, 061, 065) | 51.6% | 69 / 127 = 54.3% |
| Sonnet | 13 (005, 021, 023, 024, 034, 035, 039, 040, 050, 051, 054, 060, 064) | 20.3% | 25 / 127 = 19.7% |
| Haiku | 5 (025, 028, 033, 038, 063) | 7.8% | 5 / 127 = 3.9% |
| 합계 | 64 | 100% | 127 |

비율은 모델 작업 64개 기준이다(2026-10-14 FLORA 개편 7개 추가: 059 Opus L, 060 Sonnet M, 061 Opus M, 062 Fable M, 063 Haiku S, 064 Sonnet L, 065 Opus M. 인증 단계 3개 추가 후 57개였다: 056·058 Fable M, 057 Opus S). 사람 작업 1개(PB-06-041, M)는 비율에서 뺐다. 2026-10-14 이전(54개)은 Fable 18.5%, Opus 53.7%, Sonnet 20.4%, Haiku 7.4%였다. 2026-10-13 이전(38개)은 Fable 18.4%, Opus 55.3%, Sonnet 15.8%, Haiku 10.5%였다. Fable은 데이터 모델, RLS, 결제, 크레딧 차감 경로, 개인정보 삭제에 더해 AI 보안 경계(서명 토큰 검증 043, AI 게이트의 선차감·정산·동의 044, AI 회귀 055)를 맡는다. 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 패널·설정집 화면·3D 히어로·디자인 시스템 구현은 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

리뷰 5장 작업 55건(Flora-v2 14, flora 15, flora-publisher 12, SellingDocs 14).

| 리뷰 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| `docs/reference/reviews/Flora-v2.md` 5장 #1 | 인증 체계 복구(브라우저 클라이언트, next 검증, apiFetch, 라우터 인증, JWT secret 기동 검증) | PB-06-006(Stage A, `finishLogin` next 검증), PB-06-056(Stage B 이메일·Google 화면과 콜백), PB-06-007, PB-06-003 |
| Flora-v2 5장 #2 | 플랜/결제 서버 강제, user_plans SELECT 전용, 잠금해제 제거 | PB-06-001, PB-06-008, PB-06-009, PB-06-029 |
| Flora-v2 5장 #3 | 빌드 복구, 죽은 코드 정리 | PB-06-002, PB-06-005(죽은 코드는 이식하지 않음, 07장) |
| Flora-v2 5장 #4 | 업로드 계약 통일, 20MB, 스레드풀, HWP | PB-06-015 |
| Flora-v2 5장 #5 | 전체 집필 수정(SSE → 서버 잡), TOC 상한 | PB-06-014, PB-06-013 |
| Flora-v2 5장 #6 | 내보내기 복구(WeasyPrint, ePub3, escape, DB 조회) | PB-06-016, PB-06-017, PB-06-018 |
| Flora-v2 5장 #7 | 프로젝트 영속화(POST /projects, debounce PATCH) | PB-06-010, PB-06-021 |
| Flora-v2 5장 #8 | 페르소나 JSON, 메타데이터 DB 기반 | PB-06-012, PB-06-020 |
| Flora-v2 5장 #9 | v1 엔진 이식(표지·TTS) | PB-06-019(표지). TTS는 원고 낭독·미리듣기(PB-06-053)로 대체하고 레퍼런스 WAV 보이스 클론은 폐기, 전권 오디오북은 Phase 2(PB-F-042) |
| Flora-v2 5장 #10 | 블로킹 제거 | PB-06-003, PB-06-014 |
| Flora-v2 5장 #11 | 백엔드 오류 처리 | PB-06-007, PB-06-003 |
| Flora-v2 5장 #12 | 의존성·환경 정리, 루트 .env 삭제 | PB-06-003, PB-06-033 |
| Flora-v2 5장 #13 | 배포 설정, CI | PB-06-034, PB-06-004, PB-06-005 |
| Flora-v2 5장 #14 | 백엔드 테스트 | PB-06-031, PB-06-032 |
| `docs/reference/reviews/flora.md` 5장 #1 | 백엔드 인증 통합, `/debug-api-keys` 삭제 | PB-06-007, PB-06-003 |
| flora 5장 #2 | Stripe 서명 검증, user_plans RLS | PB-06-009(Toss로 대체), PB-06-001, PB-06-029 |
| flora 5장 #3 | 파일/URL 하드닝(WAV, cover_url, url_fetcher) | PB-06-015, PB-06-004, PB-06-032(WAV 기능은 폐기) |
| flora 5장 #4 | 동기 호출 비동기화 | PB-06-003, PB-06-014 |
| flora 5장 #5 | 배포 설정 복구(Dockerfile, deploy.yml, Python 3.11) | PB-06-004, PB-06-034, PB-06-005 |
| flora 5장 #6 | requirements 재생성, 로깅, mock은 dev만 | PB-06-003(mock 폴백은 폐기, 07장) |
| flora 5장 #7 | AI 고도화 수정, build-html escape | PB-06-014, PB-06-016 |
| flora 5장 #8 | 플랜 제한 서버 강제 | PB-06-008, PB-06-001 |
| flora 5장 #9 | 4,095줄 페이지 분해 | PB-06-021, PB-06-022 |
| flora 5장 #10 | lib/api.ts 확장 | PB-06-007 |
| flora 5장 #11 | TTS Storage 저장 | 미리듣기 mp3 저장은 PB-06-053(결정적 경로, `exports` 버킷). 전권 오디오북은 Phase 2(PB-F-042) |
| flora 5장 #12 | waitlist 경로·테이블·시드 수치 제거 | PB-06-028 |
| flora 5장 #13 | db.py 오류 처리, ePub uuid5 | PB-06-010, PB-06-018 |
| flora 5장 #14 | f5-tts 벤더링 제거 | PB-06-033 |
| flora 5장 #15 | 문서·잡파일 정리, 프론트 .env 키 제거 | PB-06-033, PB-06-002 |
| `docs/reference/reviews/flora-publisher.md` 5장 #1 | Vertex 프록시 리전 검증 | PB-06-033(프록시 이식 안 함, 아카이브) |
| flora-publisher 5장 #2 | 미사용 프록시·shim 삭제 | PB-06-033 |
| flora-publisher 5장 #3 | PROXY_HEADER 제거, 세션 인증 | PB-06-033, PB-06-002(번들 비밀 금지) |
| flora-publisher 5장 #4 | `latest` 의존성 고정 | PB-06-005(lockfile·latest 금지 검사) |
| flora-publisher 5장 #5 | index.html, vite define 잔재 | PB-06-033 |
| flora-publisher 5장 #6 | WS 파싱 return, 로그 | PB-06-033 |
| flora-publisher 5장 #7 | 검색 훅, AbortController | PB-06-033(Google Books 검색 폐기) |
| flora-publisher 5장 #8 | Tailwind CDN → Tailwind CSS v4 빌드 타임 설정 | PB-06-002 |
| flora-publisher 5장 #9 | 사이드바 반응형 | PB-06-023 |
| flora-publisher 5장 #10 | tsconfig strict, ESLint | PB-06-002 |
| flora-publisher 5장 #11 | 더미 버튼 숨김 | PB-06-023, PB-06-038 |
| flora-publisher 5장 #12 | 아카이브 결정과 이식 판단 | PB-06-033 |
| `docs/reference/reviews/SellingDocs.md` 5장 #1 | PDF 엔진 결정과 데이터 모델 v2 | PB-06-001, PB-06-004 |
| SellingDocs 5장 #2 | Claude.md 작성 | `CLAUDE.md`(이 폴더), PB-06-002 |
| SellingDocs 5장 #3 | 골격 복제와 Supabase 이식 | PB-06-002, PB-06-006 |
| SellingDocs 5장 #4 | 마이그레이션(profiles, books, chapters, credit_logs, exports, RPC) | PB-06-001, PB-06-029(코어 원장 사용) |
| SellingDocs 5장 #5 | 목차 → 챕터별 생성 라우트 | PB-06-011, PB-06-013, PB-06-014 |
| SellingDocs 5장 #6 | WeasyPrint Docker + export/pdf | PB-06-004, PB-06-017 |
| SellingDocs 5장 #7 | ePub 라우트 | PB-06-018 |
| SellingDocs 5장 #8 | 판형 프리셋 + Paged Media CSS | PB-06-016 |
| SellingDocs 5장 #9 | Tiptap, 자동 저장, sanitize | PB-06-022, PB-06-013 |
| SellingDocs 5장 #10 | 대시보드, 크레딧 모달, 랜딩 | PB-06-023, PB-06-024 |
| SellingDocs 5장 #11 | QuickChart 차트 | 폐기(07장 3절 D-06). 작업 없음 |
| SellingDocs 5장 #12 | 공개 서가 + JSON-LD | PB-06-035 |
| SellingDocs 5장 #13 | 결제 + 웹훅 서명 | PB-06-009 |
| SellingDocs 5장 #14 | 크레딧 동시성 테스트, env zod | PB-06-031, PB-06-002 |

## 6. 공용 모듈 요청

| # | 요청 | 이유 | 대상 |
|---|---|---|---|
| R1 | 모듈러 `seed.sql`의 publishing 플랜 features를 01장 4.4절 16키로 갱신 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치(`_supabase-modular/VERIFICATION.md`). 서버 기본값은 키 누락 대비로 유지 | `_supabase-modular/seed.sql:33`, `:95` |
| R2 | `core.adjust_credits` RPC(음수 허용, service_role 전용) | 팩 환불 시 미사용분 회수와 운영자 조정(PB-06-027)에 필요(`CORE_SPEC.md:237` 제안) | `_platform-core` |
| R3 | `confirm_payment_order` 금액 불일치 시 주문 `failed` 영속화 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` RPC 추가. 제품은 PM001 시 별도 호출로 이를 부르고 운영 알림·취소 요청을 한다 | `_platform-core`, `DB_CONVENTIONS.md` 13.2 |
| R4 | `heartbeat_job` 반환값으로 취소 신호 제공 | 실행 중 잡 취소를 제품 테이블(`generation_runs.cancel_requested_at`) 없이도 하려면 필요(`CORE_SPEC.md:307` 제안). 그전까지는 제품 테이블로 처리 | `_platform-core` |
| R5 | fal 웹훅 서명 검증 방식 확인과 verifier 제공 | 미확인 상태(SM 9장). 확인 전에는 request_id 대조만 | `packages/core-ai` |
| R6 | 렌더 서비스를 `services/render-weasyprint`로 이 제품이 소유·운영함을 astro-ai와 계약 확정(요청 본문 상한, 동시성, 장애 연락) | 공용 서비스 운영 책임 명확화 | astro-ai, `_platform-core` |
| R7 | `_supabase-modular/seed.sql`의 publishing free·basic 플랜 `features`에 AI 키 6개(`ai_chat`, `ai_chat_turns_per_day`, `book_wiki`, `rag_files_max`, `voice_dictation`, `narration`) 추가 | seed가 `1000_publishing.sql`보다 나중에 실행되면 15.2절 병합 UPDATE가 덮어써진다 | `_supabase-modular/seed.sql` |
| R8 | ai-service 라우터의 호출 단위 오픈소스 강제(예: 요청 컨텍스트의 `force_open_source`)를 공용 계약에 추가 | 현재 `force_open_source`는 조직·앱·기능 단위 행이다. 책 단위 스위치(01장 PB-F-056)가 필요하다 | `_platform-core` AI_ARCHITECTURE, ai-service |
| R9 | ai-service 그래프 실행의 SSE 중계(`POST /graphs/{name}/runs`의 스트리밍 모드) | 단건 섹션 생성의 스트리밍(PB-F-016)을 그래프 경유로 유지하려면 필요(01장 D13) | ai-service |
| R10 | TS 워커가 그래프를 실행할 때 쓰는 잡 토큰 발급 규칙(Next.js `/api/internal/ai-token`, 워커 키 + running 잡 확인, org·sub는 잡 행에서)을 공용 규칙과 `packages/core-ai`에 추가 | 개인키는 Next.js에만 둔다는 규칙과 워커 기반 생성이 함께 필요. astro-ai R-8과 같은 요청 | `_platform-core` AI_ARCHITECTURE, ai-gateway |
| R11 | core-voice: 기능별 대체 금지 옵션(`feature='narration'`)과 "시작 제공자 고정" 동작을 `VoiceAdapter` 계약에 명시 | `VOICE_ARCHITECTURE.md:47`을 코드 계약으로 강제. astro-ai R-11과 같은 요청 | core-voice |
| R12 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/file/03-설계/디자인/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게. astro-ai R-13과 같은 요청. 그때까지 `hero3d/` 안에 같은 인터페이스로 둔다 | `_design-guide` |
| R13 | 공용 Dify: `publishing-chat` 앱 생성, 내부 키 환경 변수, 로그 보존 30일 | 공용 인프라는 코어 소유. 장애 시 `/tools/answer-direct` | 공용 Dify |
| R14 | ai-service: (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석(`dify.aux`) (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | Dify 보조 노드 라우팅과 이용자 설정집 편집. astro-ai R-10과 같은 요청 | ai-service |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `npm run build`, `npx tsc --noEmit`, `npm run lint`(web, worker) 녹색 |
| Python | `pytest`(engine, render) 녹색, `ruff` 통과 |
| SQL | `node check.mjs mod ... 1000_publishing.sql`, `node check.mjs mono 0001 0002 seed` OK |
| RLS 스모크 | PB-06-029 전 항목 통과(모듈러, 모놀리스) |
| 결제 E2E | PB-06-030 시나리오 5개 통과(Toss 테스트 키) |
| 핵심 플로우 E2E | PB-06-037 통과 |
| AI·음성 | `pytest api` 통과, PB-06-055 녹색, 초안 평가셋 20건을 상용·오픈소스 경로 모두 통과, 채팅 평가셋 30문항 금지 문구 0, 낭독 대체 금지 테스트 통과, 오픈소스 전용 책 상용 호출 0 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(PB-06-042) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | 2절 P0·P1 작업 전부 완료(P2 제외). 8절 인증 단계 작업 중 056(P0)은 MVP 출시 조건이고, 057·058(P1)은 G2 이후 작업이라 MVP 완료 정의에서 제외. 9절 에이전트·운영 작업 중 059·060(P0)은 포함, 062·063(P1)은 공개 베타 전 완료, 061(P1, W7)은 출시 조건에서 제외, 064·065(P2) 제외 |

P0 작업과 대응 테스트:

| P0 작업 | 대응 테스트 작업 |
|---|---|
| 001, 008 | 029, 031 |
| 002, 006(Stage A), 007, 056(Stage B) | 031, 037(Mock 페르소나 storageState, 056 후 스테이징 재실행), 056 수동 점검표(B-5) |
| 003, 004, 015, 016, 017, 018 | 032, 031 |
| 009 | 030 |
| 010, 011, 012, 013, 014, 019 | 031, 037 |
| 021, 022, 023, 024, 025 | 037, 038 |
| 005, 034 | CI 자체 실행 결과, 스테이징 배포 확인(037) |
| 039~042 | 디자인 시스템 4단계 문서-코드 일치 검사, 041은 사람 검토 기록 |
| 043, 044 | 055, 029 |
| 045, 046, 047, 048, 049 | 055, 037 |
| 050, 051, 052, 053, 054 | 037, 055, 038 |
| 059(2026-10-14) | 037, 029 |
| 060 | 037, 038 |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(9장 작업 계획 반영 규칙, 8장 매트릭스의 flora-publishing 행: open, B Google + 이메일, C1 P1(D6 해소), C2 P1)다. Stage A는 기존 PB-06-006이 맡고(2절에서 범위 변경), 아래 3개를 새로 더한다. 작업 ID는 기존 최대 055 다음부터.

### 8.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| PB-06-056 | 인증 Stage B: Google OAuth 전환 + 이메일 가입·메일 인증·비밀번호 재설정 화면, `/auth/callback`(`finishLogin` 연결), 첫 OAuth 로그인 뒤 온보딩 약관 단계, 배포 체크리스트(Google 콘솔·Supabase Providers·Redirect URLs·`AUTH_PROVIDERS`), Google 실로그인 수동 점검표 | `web/src/app/(auth)/`(006에서 이어 받음: login B 구성, signup, reset-password), `web/src/app/auth/callback/`, `web/src/features/onboarding-terms/`(`/onboarding` 장착은 044 파일에 1줄 요청), `web/src/app/api/terms/`, `supabase/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`, `docs/flora-publishing/ops/auth-checklist.md` | PB-06-006, PB-06-025, PB-06-034, PB-06-044. 진입 조건 G1(`[DECISION] G1 통과`) | P0 | M | Fable | AUTH_ROADMAP 5.3절 그대로: B-1 새 Google 계정 첫 로그인 → `session_context('publishing')` `entitled=true`, `plan_code='free'`, 가입·월 크레딧 1회(재로그인 3회 뒤에도 원장 행 수 같음). B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → `/dashboard`. B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 오류 로그에 토큰·코드 없음. B-4 `VERCEL_ENV=production` 빌드에서 `/api/dev/login` 404, 로그인 화면에 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(PB-06-037 핵심 플로우) 계속 녹색, Google 실로그인은 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인하고 task `log.md`에 기록. B-6 운영 대시보드 Google 설정, Redirect URLs, `AUTH_PROVIDERS=google,email`이 배포 체크리스트와 일치. 제품 추가: 이메일 가입 → 메일 인증 → `/dashboard`, 같은 이메일 가입자의 Google 로그인은 같은 `user_id`(Supabase 자동 연결), 약관 동의 없는 첫 OAuth 사용자는 `/onboarding` 약관 단계 → AI 처리 방식 순서(03장 7.3절) | AUTH_ROADMAP 5장, 9장 B 작업, PB-F-001, PB-F-002, 03장 7절 |
| PB-06-057 | 인증 Stage C1: 카카오 로그인(Supabase 기본 제공자 `kakao`), 로그인 버튼, 설정 → 로그인 방법(연결·해제, 03장 7.4절) | `web/src/lib/auth/providers/kakao.ts`, `web/src/features/login-methods/`(설정 화면 장착은 023 파일에 1줄 요청), `supabase/config.toml`의 `[auth.external.kakao]`(056 완료 후 이어 받음), `docs/flora-publishing/ops/auth-checklist.md` 카카오 절 | PB-06-056. 진입 조건 G2(`[DECISION] G2 통과`), 01장 D20 확정 | P1 | S | Opus | AUTH_ROADMAP 7.1.3절 그대로: C1-1 새 카카오 계정 첫 로그인 → B-1과 같은 결과(엔타이틀먼트·크레딧 1회). C1-2 비즈 앱(a)이면 Google로 가입한 같은 이메일 사용자가 카카오로 로그인 → 같은 `user_id`(자동 연결은 제공자 이메일 인증 확인 시에만, 미확인이면 수동 연결 7.3절). C1-3 (b)면 이메일 없는 사용자가 결제 전 연락 이메일 입력 화면을 본다. C1-4 표시 이름은 카카오 닉네임, 없으면 `user` 규칙. C1-5 버튼은 카카오 디자인 가이드의 색·문구(미확인: 최신판 확인 후 반영). 계정 연결 화면(7.3절): 연결·해제, 마지막 수단 해제 거부, 감사 `auth.identity_link`·`auth.identity_unlink` | AUTH_ROADMAP 7.1, 7.3절, 9장 C1 작업, 01장 D6(결정 22로 C1 확정), D20 |
| PB-06-058 | 인증 Stage C2: 네이버 로그인(스파이크 0.5일 → `custom:naver` 또는 서버 브리지), 네이버 검수 자료, 설정 → 로그인 방법의 네이버 행 | `web/src/lib/auth/providers/naver.ts`, `scripts/auth/register-naver-provider.mjs`(제안), `web/src/app/auth/naver/`(브리지 경로일 때만), `docs/flora-publishing/ops/naver-review/`(검수 캡처) | PB-06-056(로그인 방법 화면의 네이버 행은 057 완료 후 057 파일에 요청). 진입 조건 G2. 브리지면 코어 R15(8.3절) 적용 후 | P1 | M | Fable | AUTH_ROADMAP 7.2.4절 그대로: C2-1 스파이크 결과가 `[DECISION]`으로 기록되고 `NAVER_AUTH_PATH`가 그 값이다. C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 결과. C2-3 같은 네이버 계정 재로그인 5회 → 같은 `user_id`, 사용자 수 증가 0. C2-4 (브리지) state 변조·재사용·쿠키 없음 → 거부, 세션 미생성, 다른 브라우저에서 받은 콜백 URL 재생 → 거부. C2-5 (브리지) 같은 이메일의 Google 가입자가 네이버로 처음 로그인 → `email_in_use` 안내, 새 사용자 0. C2-6 네이버 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver`를 넣지 않는다 | AUTH_ROADMAP 7.2절, 9장 C2 작업, 01장 D21 |

### 8.2 게이트와 웨이브

| 게이트·웨이브 | 작업 | 진입 조건 | 판정 |
|---|---|---|---|
| Stage A | PB-06-006(W1) | 없음. W0의 001·002 뒤. 006보다 앞 웨이브(W0) 작업은 시드 스크립트 없이 SQL·단위 테스트로 검증한다 | - |
| G1 | - | AUTH_ROADMAP 4장: 2절 MVP P0 기능 작업 완료(인증 B·C와 공개 베타 직전 통합 작업 037·055 제외), 핵심 플로우 E2E(PB-06-037)가 Mock 페르소나로 로컬 녹색, RLS 스모크(PB-06-029)와 `outsider` 교차 테넌트 거부, 결제 E2E(PB-06-030, Toss 테스트 키), 단계 분기 코드가 인증 모듈 밖 0건(PB-06-005 CI), Google Cloud 프로젝트·OAuth 동의 화면·웹 클라이언트 ID·운영 Supabase 프로젝트 준비(AUTH_ROADMAP 5.1절) | 사람(대표님)이 task `log.md`에 `[DECISION] G1 통과` |
| Stage B | PB-06-056 | W7의 맨 앞(마지막 기능 웨이브 W6 다음, 공개 베타 직전 통합·E2E 웨이브). 037·055의 스테이징·B 구성 재실행은 056 완료를 기다린다 | - |
| G2 | - | AUTH_ROADMAP 6장: Google 실로그인 공개 베타 운영 2주(제안), 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안), open 앱 신규 가입자 중 `entitled=false` 0, 카카오 디벨로퍼스 앱·비즈 앱 전환(01장 D20), 네이버 애플리케이션 등록·검수 자료 준비 | 사람이 `[DECISION] G2 통과` |
| Stage C | PB-06-057, PB-06-058 | W8(MVP 출시 후 웨이브, 035와 같은 웨이브), G2 통과 후. 057·058 병렬 가능 | - |

### 8.3 코어 요청 (6절 표에 이어서)

| # | 요청 | 이유 | 대상 |
|---|---|---|---|
| R15 | C2 스파이크가 실패해 브리지 경로를 택하면 코어 `D:/WorkSpace/platform/docs/products/_platform-core/staged/0010_core_auth_identity_links.sql`(`core.auth_identity_links`) 적용 | 브리지 로그인은 네이버 고유 id로 사용자를 찾는다. 코어는 한 번만 적용하고 모든 제품이 쓴다(AUTH_ROADMAP 9장 공용 모듈 요청). `supabase_custom` 경로면 요청하지 않는다 | `_platform-core` |

### 8.4 기존 문서와 달라진 점

| 항목 | 이전 | 지금 | 반영 |
|---|---|---|---|
| PB-06-006 범위 | 인증 화면과 콜백(이메일 가입, Google, 재설정) | Stage A(Mock 로그인, 시드, 가드, `finishLogin`). 이메일·Google 화면과 콜백은 056 | 2절 006 행 |
| `web/src/app/(auth)/` 소유 | 006 단독 | 006(A 구성) → 056이 이어 받음(직렬이라 동시 쓰기 없음) | 2절 006 행, 8.1절 056 행 |
| 온보딩 약관 단계 | 없음(이메일 가입 폼에서 동의) | OAuth 첫 로그인용 약관 단계를 056이 `web/src/features/onboarding-terms/`로 만들고 044 소유 `/onboarding`에 1줄 요청으로 장착 | 03장 7.3절, 8.1절 |
| PB-06-034 수용 기준 | 스테이징 가입 → PDF | 배포 환경은 Mock 금지라 스테이징 가입 확인은 056 완료 후 | 2절 034 행 |
| PB-06-037 수용 기준 | 스테이징에서 통과 | Mock 페르소나 storageState로 로컬 먼저(G1 근거), 056 후 스테이징 재실행 | 2절 037 행 |
| 01장 D6 카카오 | 열린 결정, (a)로 시작 | 결정 22로 C1 확정(PB-06-057). 카카오 이메일 정책 D20, 네이버 경로 D21, 이메일 가입 유지 D22를 01장 8.1절에 새로 둠 | 01장 8절 D6 행, 8.1절 |
| 공용 파일 요청 | - | 006: 상단 배지 `MOCK AUTH · 로컬 전용`의 레이아웃 장착(`web/src/app/layout.tsx`)과 `package.json` 스크립트 `db:seed-users`는 PB-06-002에 1줄 요청(1절 원칙). 057·058의 설정 화면 장착은 023 파일에 1줄 요청 | 1절 원칙 그대로 |
| 작업 수 | 55개(모델 작업 54) | 58개(모델 작업 57) | 3행, 4절 |

## 9. 에이전트·운영 작업 (2026-10-14 FLORA 개편, 검토용)

요구는 01장 3.1절(PB-F-057~063), 설계는 02장 10절, 화면은 03장 8절, 계약은 04장 9절, 표는 05장 2.5절이다. DB 변경(`1000_publishing.sql` 16절)은 이 문서 개정에서 이미 작성·검사했고(05장 9절), 개발 폴더 적용과 타입 생성은 PB-06-001이 맡는다.

### 9.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| PB-06-059 | 에이전트 실행 계층: 레지스트리(02장 10.1절), `withAgentTask` 기록기, `/api/agents`, `/api/agent-tasks/*`(목록·상세·취소·재시도·결정), 동기화 크론 `/api/internal/agent-sync`, worker·engine·api 공용 갱신 헬퍼, 기존 유료 작업형 Route Handler 장착(각 소유 작업 파일에 1줄 요청) | `web/src/server/agents/`, `web/src/app/api/agents/`, `web/src/app/api/agent-tasks/`, `web/src/app/api/internal/agent-sync/`, `worker/src/lib/agent-tasks.ts`, `engine/app/agent_tasks.py`, `api/app/ai/products/publishing/agent_tasks.py` | PB-06-001, PB-06-007, PB-06-008. 01장 D26 확정 | P0 | L | Opus | 01장 PB-F-057·058 수용 기준. 레지스트리의 모든 동작이 기존 처리 함수를 부르고 새 LLM·렌더 호출 코드 0(코드 검사). 같은 `request_id` 재전송 새 행·차감 0. 잡 완료 후 5분 안에 행 마감(동기화 테스트). 결정 API가 `applied_section_ids` revision 상승을 확인. 재시도 범위는 02장 10.4절(실패분, 취소면 남은 것까지), 원래 작업의 결과 없는 차감에 환불이 없으면 409 `refund_missing`(차감이 없던 작업은 확인 생략). 15분 넘게 `queued`로 멈춘 작업은 동기화가 환불 후 `failed`. `input_summary`·`result_summary`에 본문 0(스키마 테스트) | 01장 3.1절, 02장 10절, 04장 9.1·9.2절 |
| PB-06-060 | 에이전트 작업 공간 화면: `/dashboard/agents`(탭 에이전트·검수 대기·실행 이력·대화), 새 작업 시트(P1), 작업 상세(타임라인, 결과 검수, 실패·환불, 재시도), 사이드바 검수 배지 | `web/src/features/agents/`, `web/src/app/(app)/dashboard/agents/` | PB-06-042, PB-06-059, PB-06-050(대화 탭 재사용) | P0(검수·이력), P1(새 작업 폼) | M | Sonnet | 03장 8.5절 구성. 카드 그리드가 아닌 행 목록. 위저드·에디터에서 시작한 작업도 이력에 보임. 375px에서 표 → 목록 전환, 가로 스크롤 0. 검수 일괄 승인 전 개수 확인. viewer는 결정 버튼 비활성. 사이드바 배지 장착은 023 파일에 1줄 요청 | PB-F-058, PB-F-059 |
| PB-06-061 | 에디터 AI 패널(탭 도우미·제안·실행)과 선택 영역 동작 3종 추가(`examples`, `style_check`, `source_check`). 3단 레이아웃 자체는 022 | `web/src/features/ai-panel/`. 요청(1줄): `/api/books/[id]/assist` action 확장은 013, 프롬프트 3종은 011 `prompts/`, 그래프 purpose 3종은 048 `publishing_assist.py`, 단가 3종(각 1)은 008 `pricing/`, 패널 슬롯 장착은 022 | PB-06-022, PB-06-050, PB-06-059 | P1 | M | Opus | 01장 PB-F-060 수용 기준. 새 동작 결과는 Diff·메모로만 오고 원고 변경 0(승인 전). [제안] 탭에는 잡 작업의 검수 대기만. 패널 탭 키보드 이동 | PB-F-060, 03장 8.4절 |
| PB-06-062 | 운영 콘솔 확장: 출판 프로젝트(본문 제외), 에이전트·AI 운영 통계, 작업 큐·실행 추적 6단계, 재실행(`origin='admin_retry'`), 원가(모델·에이전트·조직·기능별), 설정 열람, 원고 열람(이용자 허용분만) | `web/src/app/admin/{books,agents,jobs,settings}/`, `web/src/app/api/admin/{tasks,trace,costs,books,settings,agents}/`, `web/src/server/admin-trace/` | PB-06-027, PB-06-059. 01장 D27 확정 | P1 | M | Fable | 01장 PB-F-061 수용 기준. 원가 합계 = `ai_usage.cost_usd_micros` 합. 작가용 API·화면 응답에 원가 필드 0(계약 테스트). 추적 화면에 프롬프트·출력 본문·토큰 0. 재실행 이중 차감 0. 이용자 허용 없는 원고 열람 403 + 시도 감사 | PB-F-061, 02장 10.5절 |
| PB-06-063 | 랜딩 헤드라인 실험(01장 D25): 대기자 랜딩에 두 문구를 기간 교대로 걸고 방문·등록 수 기록, 결과 보고 | `docs/flora-publishing/experiments/landing-headline.md`, 문구 상수는 024 파일에 1줄 요청 | PB-06-024, PB-06-028 | P1 | S | Haiku | 각 문구 2주 이상, 방문 1,000 이상(제안). 결과 표와 채택안을 `[DECISION]`으로 기록. 사용자 수·후기 같은 허위 수치 0 | 01장 D25, 린 검증 원칙 |
| PB-06-064 | 워크플로 빌더(Phase 2): React Flow(XYFlow) 노드 캔버스, 레지스트리 동작만 노드로, 승인 지점, 실행 로그. 운영 콘솔 실행 그래프 읽기 전용 보기 | `web/src/features/workflow-builder/`, `web/src/app/admin/graph/` | PB-06-059, PB-06-062 | P2 | L | Sonnet | Phase 2 기획에서 확정. 새 실행 엔진 0 | PB-F-062 |
| PB-06-065 | 콘텐츠 에이전트(Phase 2): 승인 원고 → 소개문·목차 요약·홍보 글, 게시 전 승인 | 레지스트리 `content` 동작, `prompts/content/`(011에 요청) | PB-06-059 | P2 | M | Opus | Phase 2 기획에서 확정 | PB-F-063 |

### 9.2 웨이브

| 작업 | 웨이브 | 이유 |
|---|---|---|
| 059 | W2 | 001(표)·007(API 공통)·008(단가) 뒤. 같은 웨이브에서 먼저 끝난 유료 작업형 Route Handler(012 페르소나 합성, 017 PDF·ePub 내보내기)에는 059가 W2 안에서 1줄 장착을 요청한다(1절 장착 지점 원칙). 이후 웨이브의 011·013·014·019·020·045·046·053은 처음부터 `withAgentTask`로 쓴다 |
| 062, 063 | W4 | 062는 027(W3) 뒤, 063은 024(W3)·028(W2) 뒤 |
| 060 | W5 | 화면은 042 뒤, 대화 탭이 050(W4) 컴포넌트를 재사용 |
| 061 | W7 | 022(W6)의 패널 슬롯 뒤. P1이라 공개 베타 조건이 아니다 |
| 064, 065 | W8 | Phase 2 |

### 9.3 기존 작업과 달라진 점

| 작업 | 이전 | 지금 |
|---|---|---|
| 027 | 운영자 화면 전부(지표, 조정, 렌더 실패) | 운영 콘솔 기반(레이아웃, 홈, 사용자, 결제·조정, 감사). 나머지 메뉴는 062 |
| 023 | 사이드바 5항목 | 6항목(AI 에이전트 추가, "구독 및 결제" → "사용량·결제"), 내보내기 전 검토 전 AI 초안 확인 |
| 024 | 4섹션 | 6섹션(03장 8.3절), FAQ |
| 039~041 | 단일 레이어 | 레이어 3종, D23~D25 비교와 결정 |
| 002 | 루트 레이아웃 | 경로 그룹별 `data-surface` 속성(1줄, 059·027 요청 없이 002가 직접) |
| 022, 029, 037, 009 | - | 022 에디터 3단 레이아웃, 029 `agent_tasks` RLS, 037 작업 불변식·검수 E2E, 009 에이전트별 사용량 |
| 코어 요청 | - | 없음(코어 표 `ai_runs`·`ai_usage`·`jobs`·`credit_ledger`·`audit_log`를 읽기만 한다) |
