# 06 에이전트 작업 계획: Live Poll

작업 ID는 `LP-06-###`(DB_CONVENTIONS 1장 SQLSTATE 접두사 `PL`과 약어 `LP`). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장: Fable(결제, 권한, RLS, 데이터 모델), Opus(기능 구현, API 연동, 테스트 설계), Sonnet(UI, 메인페이지, 컴포넌트, 문서), Haiku(보일러플레이트, 린트/타입, 문구, 반복 체크).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/design-module/_design-guide/DESIGN_SYSTEM.md` 4장) 작업 16개(LP-06-033~048)를 뒤에 붙였다. 기존 ID는 바꾸지 않았고, 내용이 바뀐 기존 작업은 001, 002, 004, 007, 008, 009, 015, 022, 023(디자인 시스템 2단계로 재정의), 024, 025, 026, 027, 030, 031, 032이다. 작업 수 48개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다(2026-10-14 확정 결정 22로 인증 단계 작업 3개 LP-06-049~051을 8절에 더해 51개, LP-06-003은 Stage A로 범위 변경). AI·음성·3D·디자인 시스템이 MVP 필수 범위로 추가돼서 생긴 증가다(astro-ai의 54개와 같은 이유).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 작업마다 디렉토리(또는 파일)를 하나 이상 단독 소유한다. 다른 작업의 디렉토리는 읽기만 한다 |
| 루트 | 앱 `apps/live-poll/`, 워커 `services/poll-broadcaster/`. 아래 경로의 `src/`, `tests/`, `supabase/`는 `apps/live-poll/` 기준 |
| DB 정본 | 스키마 변경은 `docs/products/_supabase-modular/migrations/1800_poll.sql`(이후 변경은 같은 번호대 1810 등)에서만(Fable). 앱의 `supabase/migrations/`는 정본 복사와 변환 스크립트 결과물이다 |
| 공유 파일 | `src/lib/poll/`(도메인 타입, 오류 코드)은 LP-06-004만 쓴다. 다른 작업은 필요하면 004 담당에게 요청한다 |
| 코어 | `_platform-core`, `packages/core-*`는 수정하지 않는다. 필요한 것은 6절 요청 |
| 스타일 토큰 | `src/styles/tokens.css`는 LP-06-023만 쓴다. 스타일은 반드시 Tailwind CSS v4(4.x 고정)이고 `tailwind.config.js`는 만들지 않는다 |
| AI 서비스 경계 | `apps/api/`는 LP-06-036이 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. poll 확장은 작업별로 나눈다: 038 `app/ai/products/poll/knowledge.py`, 039 `app/ai/products/poll/wiki_config.py`, 040 `app/ai/graphs/poll_qna_assist.py`·`app/ai/compliance/poll.py`, 041 `app/ai/tools/poll/` |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청 |
| 투표 경로 격리 | AI·음성 작업은 `src/app/api/p/{join,snapshot,vote,question,upvote}/`, `services/poll-broadcaster/`, `src/lib/realtime/`를 수정하지 않는다. 청중 음성 질문은 새 라우트 `api/p/voice-question/`에만 둔다. 이 경계가 02장 6절 AI 영향 문단의 전제다 |
| 사람 작업 | LP-06-034(디자인 시스템 3단계)는 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(007, 015, 022, 042, 043, 047, 해당 화면)은 LP-06-035(4단계) 뒤에 시작한다(`docs/design-module/_design-guide/DESIGN_SYSTEM.md:48`) |
| 언어 중립 파일 | 금지 문구·compliance 규칙(`apps/api/app/ai/compliance/poll.py`가 읽는 규칙 파일)은 LP-06-040 소유. 앱의 문구 사전(LP-06-024)이 같은 금지 문구를 참조한다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| LP-06-001 | 앱 골격과 스택 ADR: basic-master-module 복제, Next 16.2.9, Tailwind CSS v4, shadcn, `packages/core-db` 연결, ADR(Supabase Realtime 확정, Socket.io/FastAPI WebSocket/Redis 폐기, FastAPI는 AI 서비스 전용) | `apps/live-poll/package.json`, `next.config.ts`, `tsconfig.json`, `components.json`, `src/app/layout.tsx`, `docs/adr/` | 없음 | P0 | S | Sonnet | `pnpm build`, `tsc --noEmit`, `lint` 통과. ADR 1개에 02장 6절 리뷰 #2 결정이 적혀 있다. Tailwind는 4.x로 lockfile 고정, `tailwind.config.js` 0건, three.js·R3F·drei는 `components/hero3d/`에서만 import하는 린트 규칙 | 리뷰 5장 #1, #2, 02장 1절 |
| LP-06-002 | DB 적용: 조각 1800 복사(19절 AI·음성 기본값 포함), 모놀리스 변환 스크립트(`@@modular-only` 제거 + 접두사 치환), 모놀리스 코어 라이트(SECTION 4·7·8 복원본)와 seed 적용, `config.toml`에 `poll` 노출, 타입 생성 | `supabase/migrations/`, `supabase/scripts/`, `src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공(pgvector·`ai_*`·`voice_*` 테이블 생성 확인). 변환 결과가 저장소의 `0002_poll_domain.sql`과 바이트 단위 같다(19절은 `@@modular-only`라 변환본에 없다). 체커 `--vector` mod/mono OK. 제품 파일 2회 반복 적용 뒤 `ai_routing_settings`(org null, app poll) 12행 | 리뷰 5장 #3, #4, 05장 |
| LP-06-003 | 진행자 인증 Stage A(확정 결정 22): 인증 모듈 경계(`getAuthConfig`, `isMockAuthAllowed`, `listLoginOptions`, `finishLogin`, AUTH_ROADMAP 3.1절), Mock 로그인(`POST /api/dev/login`, `/login` 개발용 패널, 상단 배지 `MOCK AUTH · 로컬 전용`), 시드 스크립트 `scripts/dev/seed-users.mjs` + 제품 훅 `seed-users.poll.mjs`(05장 10절 `host`·`cohost`), 가드(기동 env 검증, 배포 404, 빌드 검사, CI 금지 문자열), `proxy.ts`(세션 갱신, 보호 경로), `requireSession('poll')`, `finishLogin`의 `bootstrap_app_for_org`. 이메일 가입·비밀번호 재설정 화면과 Google 버튼·`/auth/callback`은 B(LP-06-049)로 옮겼다. 배지의 `layout.tsx` 장착과 `package.json` 스크립트 `db:seed-users`는 LP-06-001에 1줄 요청 | `src/proxy.ts`, `src/app/(auth)/`(A 구성. B에서 LP-06-049가 이어 받음), `src/lib/auth/`, `src/app/api/dev/login/`, `scripts/dev/` | LP-06-001, LP-06-002 | P0 | M | Opus | `owner`·`host` 페르소나 로그인 직후 `/events`에서 `entitled=true`, `plan_code='free'`. `no_app` 로그인 → `finishLogin`이 부트스트랩 1회 후 entitled=true(크레딧 1회). `outsider`로 host 조직 행사 0행·진행자 RPC 42501. `suspended` 403. 프로필 없는 세션은 로그아웃, 기본 역할 admin 코드 없음. `AUTH_MODE=mock VERCEL_ENV=production npm run build` 실패, `AUTH_MODE=live`에서 `/api/dev/login` 404·개발용 패널 미렌더. 시드 스크립트는 원격 Supabase URL이면 exit 1, 2회 실행해도 원장 행 수 같음. CI 금지 문자열(`nomad_role`, `nomad_plan`, `mock-auth`, 쿠키·localStorage 역할/플랜, 인증 모듈 밖 `AUTH_MODE` 참조) 0건 | LP-F-001, `SECURITY_BASELINE.md` 11장, 17장, `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.1절, 9장 |
| LP-06-004 | 도메인 라이브러리: zod 스키마, 타입, PL 오류 → HTTP/문구 매핑, 참가자 토큰 생성(32바이트), 쿠키 유틸, IP HMAC(`POLL_IP_HMAC_SECRET` + 날짜) | `src/lib/poll/` | LP-06-001 | P0 | S | Opus | 단위 테스트: HMAC이 날짜마다 달라지고 원문 IP가 로그에 없다. PL 오류 코드 15개와 04장 7절의 AI·음성 앱 코드 전부 매핑 | 리뷰 5장 #10, 04장 1, 7절 |
| LP-06-005 | 청중 Route Handler: join, snapshot, vote, question, upvote(service_role RPC, 본문 4KB 상한, no-store, noindex) | `src/app/api/p/join/`, `.../snapshot/`, `.../vote/`, `.../question/`, `.../upvote/` | LP-06-002, LP-06-004 | P0 | M | Opus | 04장 2절 표의 입력/출력/오류 그대로. 쿠키 없는 vote는 401 PL009 | 리뷰 5장 #7, LP-F-007~014 |
| LP-06-006 | 청중 API 통합 테스트(로컬 Supabase): 입장/재입장/정원/잠금/비밀번호/중복 투표/다른 행사 문항/레이트 리밋 | `tests/api/participant/` | LP-06-005 | P0 | M | Opus | 01장 LP-F-007, 008, 013, 017, 018, 019 수용 기준을 각각 테스트 1개 이상으로 검증 | 01장 3절 |
| LP-06-007 | 진행자 행사 목록/생성/편집 화면(문항 카드, 선택지, 결과 공개 규칙, 행사 설정). 설정에 `audience_voice` 토글 자리와 자료 화면 링크 자리 제공 | `src/app/(host)/events/page.tsx`, `src/app/(host)/events/new/`, `src/app/(host)/events/[id]/edit/` | LP-06-003, LP-06-015, LP-06-035 | P0 | M | Sonnet | 열린 문항은 편집 컨트롤이 비활성. 선택지 11개째 추가 버튼이 막힌다. 토글 클릭은 LP-06-045의 `POST /api/host/events/[id]/audience-voice`를 부른다(장착 1줄 요청) | 리뷰 5장 #6, 03장 3.5 |
| LP-06-008 | 진행자 콘솔: 문항 진행(열기/닫기/다음, 단축키), 실시간 집계(`host_poll_results`), 입장 잠금, 비밀번호, 참가자 목록/차단, 행사 종료. 어시스턴트 시트 트리거와 Q&A AI 패널 슬롯 제공 | `src/app/(host)/events/[id]/live/page.tsx`, `src/app/(host)/events/[id]/live/_console/` | LP-06-007, LP-06-013 | P0 | L | Opus | 문항을 열면 1초 안에 청중 화면 전환(E2E). Space/화살표 단축키 동작. 어시스턴트 시트(LP-06-042)와 Q&A AI 패널(LP-06-043)을 장착할 자리가 있고 없어도 콘솔이 동작한다 | 리뷰 5장 #6, LP-F-003, 005, 011 |
| LP-06-009 | 청중 화면: `/join`, `/e/[code]`(입장 시트, 고지, 대기, 투표, 제출, 결과, Q&A 탭), 오류 문구 | `src/app/(participant)/` | LP-06-005, LP-06-013, LP-06-015 | P0 | L | Opus | 375px에서 가로 스크롤 없음. PL005 수신 시 제출 완료 상태로 전환. 종료 행사는 제목만. Q&A 탭 입력창 옆에 음성 입력 컴포넌트(LP-06-045) 장착 자리가 있고, 스냅샷의 `ai.audience_voice`가 false면 보이지 않는다 | 리뷰 5장 #7, LP-F-007, 022 |
| LP-06-010 | 브로드캐스터 워커: 250ms 루프 `collect_broadcasts`, Realtime Broadcast HTTP 배치 전송(private), advisory lock 리더 선출, 진행자 토픽 pending 수, 정리 스케줄, 단위 테스트 | `services/poll-broadcaster/src/`, `services/poll-broadcaster/test/` | LP-06-002 | P0 | M | Opus | 투표 후 300ms 안에 state 메시지 발행(로컬). 워커 2대 동시 기동 시 중복 전송 0. 변경 없는 live 행사는 5초마다 hb | 리뷰 5장 #4, 02장 4, 5-1절 |
| LP-06-011 | Realtime 권한: 청중/오버레이 JWT 발급 라우트, `realtime.messages` 정책 실제 Supabase 검증, 미확인 사항(사용자 정의 JWT 수용) 확인과 대안(Ed25519 서명) 결정 | `src/app/api/p/realtime-token/`, `src/app/api/overlay/realtime-token/`, `src/lib/realtime-auth/` | LP-06-002 | P0 | M | Fable | 청중 JWT로 다른 행사 토픽 구독이 거부된다. 청중 JWT로 broadcast 송신이 거부된다. 결론을 ADR로 남긴다 | 02장 5-1절, 조각 17절 |
| LP-06-012 | 남용 방지 점검: 코드 대입(실패 31회째 PL429), 금칙어 우회(공백/구두점), 닉네임/질문 XSS 렌더 확인, 질문 레이트 리밋 | `tests/abuse/` | LP-06-005 | P1 | S | Opus | 4개 시나리오 자동 테스트 통과. React에서 `dangerouslySetInnerHTML` 사용 0건 | 리뷰 5장 #10, 리뷰 3장 #10 |
| LP-06-013 | `useEventChannel` 훅: 구독, 연결 상태 4종, 지수 백오프(1/2/4/8/15초, 지터), SUBSCRIBED 후 스냅샷, seq 공백 감지, 15초 무수신 재구독, rAF 묶음, 언마운트 정리 | `src/lib/realtime/` | LP-06-004 | P0 | M | Opus | 한 화면에서 훅을 두 번 써도 채널 1개(참조 카운트). `as any` 0건 | 리뷰 5장 #5, 리뷰:74 Hospital 교훈 |
| LP-06-014 | 훅 테스트: 가짜 Realtime 클라이언트로 끊김/재연결/seq 공백/중복 seq/hb 시나리오 | `tests/realtime/` | LP-06-013 | P0 | M | Opus | 10초 단절 후 3초 안에 스냅샷 반영. 오래된 seq 무시 | LP-F-010 |
| LP-06-015 | 공용 UI 컴포넌트: 결과 막대(CSS transition, 재정렬, reduced-motion), 연결 배지, QR, 6자리 코드 입력, 참가자 수 카운터 | `src/components/`(단 `ui/`, `ai-assistant/`, `voice/`, `qna-ai/`, `hero3d/` 제외) | LP-06-035 | P0 | M | Sonnet | 컴포넌트는 props만 받는다(훅 import 0). 스토리/스냅샷 테스트 | 리뷰 5장 #8, #9 |
| LP-06-016 | 발표 화면: 전체화면, 대기 시 큰 코드+QR, 결과 막대 48px 숫자, 단축키 | `src/app/present/` | LP-06-013, LP-06-015 | P0 | S | Sonnet | 1920x1080 스크린샷에서 숫자 48px 이상. noindex | 리뷰 5장 #8, LP-F-011 |
| LP-06-017 | 오버레이 화면: `bg`, `theme`, `scale`, `position` 파라미터, 크롬 없음, 투명 배경 | `src/app/overlay/` | LP-06-015, LP-06-018 | P0 | S | Sonnet | `bg=transparent`에서 body 배경이 투명. 키 오류 시 빈 화면 | 리뷰 5장 #8, LP-F-012 |
| LP-06-018 | 오버레이/진행자 키 API: 오버레이 스냅샷, 오버레이 키 재발급 라우트 | `src/app/api/overlay/snapshot/`, `src/app/api/host/events/[id]/overlay-key/` | LP-06-002, LP-06-004 | P0 | S | Opus | 재발급 후 이전 키 스냅샷이 PL009 | LP-F-012 |
| LP-06-019 | Q&A 모더레이션 패널: 대기 큐, 승인/거절/답변 완료/숨김, 진행자 토픽 수신 시 목록 재조회 | `src/app/(host)/events/[id]/live/_qna/` | LP-06-008 | P1 | M | Sonnet | 승인 후 다음 브로드캐스트에 질문 표시. 차단 참가자 질문이 사라진다 | LP-F-013~015 |
| LP-06-020 | 결과 보존 화면 + CSV 내보내기(UTF-8 BOM, 참가자 식별자 없음, 감사 기록) | `src/app/(host)/events/[id]/results/`, `src/app/api/host/events/[id]/export.csv/` | LP-06-008 | P1 | M | Sonnet | 보존 기간 경과 행사도 집계가 같다. CSV를 엑셀에서 열면 한글이 깨지지 않는다 | 리뷰 5장 #13, LP-F-020 |
| LP-06-021 | 설정 화면: 조직 금칙어 추가/삭제(owner/admin) | `src/app/(host)/settings/` | LP-06-003 | P1 | S | Haiku | member 계정에는 편집 버튼이 없고, API도 0행 | LP-F-016 |
| LP-06-022 | 랜딩, 가격, robots/sitemap(랜딩만 색인), 행사 페이지 noindex 메타. 히어로는 LP-06-047의 `Hero3D` 컴포넌트를 import | `src/app/(marketing)/`, `src/app/robots.ts`, `src/app/sitemap.ts` | LP-06-015, LP-06-047 | P1 | M | Sonnet | 03장 4절 안 A 구현(히어로 = 4.5절 3D 장면). 01장 6절 금지 문구 0건(AI 금지 문구 포함). `/e/*` 응답 헤더 noindex. 3D 로딩 전에도 헤드라인·코드·CTA가 보인다 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/design-module/_design-guide/REFERENCES.md:16-23`). | 리뷰 5장 #12, 분석:1261 |
| LP-06-023 | 디자인 시스템 2단계(가진 것 위에서 시작): 03장 4.3 토큰 + Tailwind CSS v4 `@theme`로 `tokens.css`, 기본 컴포넌트와 배리언트(03장 3.8절 표), 컴포넌트 미리보기 `/dev/components`. UUPM 초안(`MASTER.md`)은 입력 자료이고 정답은 코드 | `design-system/live-poll/`, `src/styles/tokens.css`, `src/components/ui/`, `src/app/dev/components/` | LP-06-001, LP-06-033 | P0 | M | Sonnet | `MASTER.md`에 UUPM 대비 변경점 표. 03장 3.8절 기본 컴포넌트 전부가 라이트/다크로 `/dev/components`에 있다. 하드코딩 hex 0건(린트 규칙), `tailwind.config.js` 0건, v3 문법(`@tailwind base`) 0건 | `DESIGN_SYSTEM.md` 4장 2단계, 8장 템플릿 |
| LP-06-024 | 문구 사전: 청중/진행자 오류 문구, 고지 문구(음성 고지, 국외 이전 고지, AI 생성 표시 포함), 빈 상태(03장 5절) | `src/messages/ko.json` | LP-06-004 | P1 | S | Haiku | PL 오류 코드 15개와 AI·음성 앱 코드 전부 문구 있음. 사과 표현 0건. AI 생성 표시 문구 5종(01장 6.1절) 있음 | `DESIGN_PRINCIPLES.md` 카피 규칙 |
| LP-06-025 | E2E(Playwright, Mock 페르소나 storageState로 실행: `globalSetup`이 `/api/dev/login`으로 `host`·`cohost`·`viewer`·`outsider`·`no_app` 상태 저장, 청중은 페르소나 없이 `/api/p/join`): 첫 진입(`no_app` 부트스트랩, 온보딩 AI 동의 포함) → 행사 생성 → 시작 → 청중 2명(다른 브라우저 컨텍스트) 입장 → 투표 → 발표 화면 반영 → Q&A → 종료. AI 경로는 목 제공자로 LP-06-048이 검증한다 | `tests/e2e/` | LP-06-008, LP-06-009, LP-06-010, LP-06-016, LP-06-017 | P0 | M | Opus | 전 흐름 통과. 청중 화면에서 결과 반영 1초 이내 단언. AI 서비스를 끈 상태에서도 전 흐름 통과(투표 경로 격리). Mock 페르소나 시나리오: `outsider`는 host 행사 콘솔 404·데이터 0행, `viewer`는 편집·진행 버튼 없음, `cohost`가 문항 열기·모더레이션 성공. 이 흐름이 G1 판정 근거(AUTH_ROADMAP 4장 2번) | 03장 2절, `SECURITY_BASELINE.md` 17장 |
| LP-06-026 | RLS/권한 회귀 테스트: 기획 단계 스모크(79항목, 05장 9절)를 저장소로 이식, 모듈러/모놀리스 둘 다, CI 연결 | `supabase/tests/` | LP-06-002 | P0 | M | Fable | B가 A 행사 데이터 0행, 역할/플랜/크레딧 변경 42501, anon 전부 42501, 종료 행사 스냅샷 poll/qna null. 다른 조직의 `ai_runs`·`ai_documents`·`wiki_pages` 0행(코어 RLS가 poll 조직 격리에도 유효한지 확인). CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 15장 |
| LP-06-027 | 부하 테스트: 3,000 구독 + 300 votes/s(k6 + Realtime 클라이언트 시뮬레이터), p95 측정, Realtime 플랜 한도 확인, 인원별 간격과 Redis 필요 여부 결론 | `tests/load/` | LP-06-010, LP-06-005 | P1 | L | Fable | 01장 5절 표의 인원별 p95를 측정해 보고서로 남긴다. 미달이면 원인과 1810 마이그레이션 제안. Q&A AI 정리를 동시에 실행해도 투표 p95·브로드캐스트 간격이 달라지지 않음을 함께 측정 | 리뷰 5장 #11, 리뷰 3장 #1 |
| LP-06-028 | 결제 E2E(Toss 테스트 키): Pro 구독 결제 → 엔타이틀먼트 pro → `max_participants` 1,000 반영, 금액 위조 PM001 시 Toss 취소 호출 | `tests/e2e-billing/` | LP-06-029 | P2 | M | Opus | 테스트 키로 전 흐름 통과. PM001에서 `fail_payment_order` 호출 후 취소 API 호출 | 확정 결정 4, `CORE_SPEC.md` 5장 |
| LP-06-029 | Phase 2 결제 라우트: checkout, confirm, Toss 웹훅(서명 필수), seed 플랜 활성화 요청 | `src/app/api/billing/`, `src/app/api/webhooks/toss/` | LP-06-003 | P2 | M | Fable | 클라이언트 금액 무시, 주문 선저장, 웹훅 서명 실패 401 | `SHARED_MODULES.md` 5, 6장 |
| LP-06-030 | 접근성/반응형 체크(375/768/1024/1440, 포커스, reduced-motion, 대비, aria-live 요약) | `tests/a11y/` | LP-06-009, LP-06-016, LP-06-022 | P1 | S | Haiku | `DESIGN_PRINCIPLES.md` 7단계 12항목 통과 기록. AI 패널·음성 버튼·3D 히어로의 키보드/스크린리더/reduced-motion 항목 포함 | 03장 6절 |
| LP-06-031 | 배포 설정: Vercel(icn1), Railway 워커 2대, env 기동 검증(누락 시 실패), 스케줄 | `src/env.ts`, `vercel.json`, `services/poll-broadcaster/deploy/` | LP-06-010 | P1 | S | Sonnet | 필수 env 하나라도 없으면 기동 실패(AI·음성 변수 포함, 02장 8절). 인증 단계 변수(02장 9절)는 LP-06-003의 `getAuthConfig()`를 호출해 검증하고 배포 env는 `AUTH_MODE=live`, `DEV_SEED_PASSWORD` 없음. 워커 헬스체크 엔드포인트. FastAPI(`apps/api`) Railway 서비스와 정산·정리 호출 스케줄 설정 | 02장 7, 8절 |
| LP-06-032 | 진행자 가이드와 FAQ(소프트 1인 1표 설명, OBS 연결 방법, 개인정보 고지) | `docs/guide/` | LP-06-017 | P2 | S | Haiku | 01장 6절·6.1절 고지와 문구가 일치(청중 원문은 국내 오픈소스로 처리, 음성 질문 고지). 금지 문구 0건 | 리뷰 5장 #12 |
| LP-06-033 | 디자인 시스템 1단계: 레퍼런스 확정(진행자 콘솔 Atlassian 주·Primer 보조, AI 패널 Astryx 패턴 존재·라이선스 확인, 랜딩 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.8절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D17). 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/design-module/_design-guide/REFERENCES.md:183` live-poll 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/design-module/_design-guide/DESIGN_PRINCIPLES.md:29-38`). | `DESIGN_SYSTEM.md` 4장 1단계, 9절 |
| LP-06-034 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | LP-06-023 | P0 | M | 사람(보조 Sonnet) | 03장 3.8절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1(발표 화면 막대 라벨 7:1)·포커스 링 확인. 이 단계는 줄이지 않는다 | `DESIGN_SYSTEM.md` 4장 3단계 |
| LP-06-035 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | LP-06-034 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | `DESIGN_SYSTEM.md` 4장 4단계 |
| LP-06-036 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, poll 설정(app, 컬렉션 이름 규칙), JWKS 검증, 라우터·국외 동의 필터·파생 오픈소스 강제(`contains_pii` 청크) 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/poll/`, `app/ai/compliance/poll.py`, `app/ai/products/poll/` 제외), `apps/api/tests/platform/` | LP-06-001, LP-06-002 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 컬렉션·행사 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux`·`poll.*`·`voice_question` 상용 0, `contains_pii` 근거가 든 `chat` 요청 상용 0, 필수 변수 누락 시 기동 실패 | 02장 5-2절, `AI_ARCHITECTURE.md` 2·4·8장 |
| LP-06-037 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰 발급, 정산 크론(`/api/internal/ai-settle`, 음성 묶음 환불 포함), AI 단가, 온보딩 국외 이전 동의 | `src/app/api/ai/conversations/`, `src/app/api/ai/chat/`, `src/app/api/internal/`, `src/app/api/onboarding/`, `src/app/onboarding/`, `src/server/ai/`, `src/server/ai-pricing.ts` | LP-06-003, LP-06-004, LP-06-036 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 청중 참가자 쿠키로 호출 시 401, 동의 시 `ai_org_settings` 고지문 버전 일치, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 투표·질문 경로의 `consume_credits` 호출 0 | LP-F-025, 034, 035 |
| LP-06-038 | 행사 자료 업로드·RAG 색인과 Q&A 아카이브: 컬렉션 `event-<id>`·`qna-archive`(oss-embed), 업로드 화면·상태, 플랜 한도, 본문 마스킹, 평가셋 30문항 | `src/app/api/ai/materials/`, `src/app/api/ai/qna-archive/`, `src/app/(host)/events/[id]/materials/`, `apps/api/app/ai/products/poll/knowledge.py`, `apps/api/tests/poll/retrieval/` | LP-06-036, LP-06-037 | P0 | M | Opus | 재현율@8 0.8 이상(제안), 다른 조직 컬렉션 요청 42501, 한도 초과 `AI_MATERIALS_LIMIT`, 같은 내용 409, 아카이브 청크에 닉네임 0건·전화/이메일/주민번호 형식 마스킹, 행사 삭제 뒤 고아 정리 잡이 컬렉션·청크·파일 삭제, 컬렉션당 임베딩 모델 1종 | LP-F-026, 027 |
| LP-06-039 | 행사 위키: 자료·아카이브 → 위키 ingest(draft), 게시·편집·이력·lint 화면과 API, 주 1회 lint 잡, Q&A 파생 페이지 `derived_from_pii` | `apps/api/app/ai/products/poll/wiki_config.py`, `src/app/api/ai/wiki/`, `src/app/(host)/wiki/` | LP-06-035, LP-06-038 | P1 | M | Opus | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, 청중 쿠키 조회 401, lint 결과 화면 표시, 모든 쓰기 감사 1행 | LP-F-028 |
| LP-06-040 | LangGraph 그래프 `poll.qna_assist`(load → moderate → cluster → summarize → compliance → output), 체크포인트, 실행 기록, 규칙 파일, SSE 실행 라우트, 평가셋 | `apps/api/app/ai/graphs/poll_qna_assist.py`, `apps/api/app/ai/compliance/poll.py`, `apps/api/tests/poll/graph/`, `src/app/api/ai/qna-assist/` | LP-06-002, LP-06-036, LP-06-037 | P0 | L | Opus | 실행 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`. 결과에 닉네임·전화·이메일 형식 0건. 라벨·군집 평가셋 40문항(제안)에서 라벨 일치율 0.8 이상, 군집 순도 0.8 이상. 대표성 단정·여론조사 오인 문형 0건. 질문 300건 p95 20초, 120초 초과 시 실패 + 환불. 그래프는 질문 상태를 바꾸지 않는다(DB 쓰기 도구 없음). 상용 제공자 호출 0 | LP-F-029, 037 |
| LP-06-041 | Dify `poll-assistant`(질문 분류, HTTP 노드, 외부 지식)와 `/tools/answer` poll 확장(컨텍스트 로더, 모드 assist/howto, 마스킹, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/poll/`, `apps/api/tests/poll/chat/` | LP-06-037, LP-06-038 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `event_id` 403, 답변 출처 1개 이상 또는 `no_source`, 평가셋 닉네임 노출 0·금지 문구 0, DSL에 키 0 | LP-F-025, 037, 04장 6.2절 |
| LP-06-042 | 어시스턴트 패널(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 행사 바인딩) | `src/components/ai-assistant/` | LP-06-008, LP-06-035, LP-06-037 | P0 | M | Sonnet | 03장 3.7절 구성, 375px 전체 화면 시트, 포커스 트랩·Esc, `aria-live`, 402·대체·근거 없음·환불 상태 표시. 콘솔 장착은 LP-06-008 파일에 1줄 요청 | LP-F-025, 03장 5절 |
| LP-06-043 | Q&A AI 정리 패널(실행·진행 SSE·요약/군집/분류 탭·선택 적용) | `src/components/qna-ai/` | LP-06-019, LP-06-035, LP-06-040 | P1 | M | Sonnet | 03장 3.7절 와이어프레임 구성. 적용 전에는 질문 상태가 바뀌지 않는다, viewer는 적용 버튼 없음, 질문이 삭제됐으면 흐리게 표시, "AI가 정리한 내용입니다" 표시. 슬롯 장착은 LP-06-008·019 파일에 1줄 요청 | LP-F-029, 030 |
| LP-06-044 | 진행자 음성 대화: `/api/voice/`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정·읽어 주기 | `src/app/api/voice/consent/`, `.../sessions/`, `.../stt/`, `.../tts/`, `src/components/voice/host/` | LP-06-035, LP-06-037 | P0 | M | Opus | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지만 | LP-F-031 |
| LP-06-045 | 청중 음성 질문: `/api/p/voice-question`, 5중 한도, 묶음 선차감, 행사 `audience_voice` 토글 라우트, 청중 입력 컴포넌트와 음성 고지 | `src/app/api/p/voice-question/`, `src/app/api/host/events/[id]/audience-voice/`, `src/server/audience-voice/`, `src/components/voice/audience/` | LP-06-005, LP-06-009, LP-06-037 | P0 | M | Opus | 참가자 쿠키 없음·차단 401 PL009, 한도 소진 뒤 요청은 STT 호출 0 + 429 `AI_VOICE_LIMIT`, 변환 텍스트·오디오 서버 저장 0(로그 포함), `ai_usage`에 상용 제공자 0, 같은 IP에서 입장·투표 500건이 막히지 않음, 마이크 거부·미지원에서 텍스트 질문 정상, `voice_sessions` visitor_key `pt:<participant_id>` | LP-F-032 |
| LP-06-046 | Q&A 요약 읽어 주기: `/api/voice/qna-summary`(요약 텍스트는 DB에서만, 선차감·정산)와 재생 UI | `src/app/api/voice/qna-summary/`, `src/components/voice/summary/` | LP-06-040, LP-06-044 | P1 | S | Opus | 임의 텍스트 전송 400, 존재하지 않는 `run_id` 404, 미동의 조직의 `ai_usage` 제공자에 elevenlabs 0, "AI가 생성한 음성입니다" 표시, 실패 시 환불 | LP-F-033 |
| LP-06-047 | 3D 히어로: 무대 위 막대·구(PC·태블릿), 막대 3개(모바일), 정지 이미지 대체, 성능 예산, 시연 값 표시 | `src/components/hero3d/`, `public/hero/` | LP-06-035 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 네온·보라/핑크 그라디언트 0 | LP-F-036, 03장 4.5절 |
| LP-06-048 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 청중 원문 오픈소스 강제, 선차감·정산·환불, 청중 음성 남용 시나리오, 라우팅 seed 스냅샷, AI 서비스 정지 시 투표 경로 정상) | `apps/api/tests/poll/security/`, `tests/e2e-ai/`, `scripts/ai-routing/` | LP-06-037, LP-06-040, LP-06-041, LP-06-044, LP-06-045, LP-06-049(통합 작업은 B 완료 뒤) | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 12행 × 동의 유/무)이 02장 5-2절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 청중 쿠키로 `/api/ai/*` 401, 미동의 조직 상용 호출 0, 청중 원문 단계 상용 호출 0, 음성 남용 시나리오(한 참가자 연타, 다중 참가자 같은 IP, 풀 소진, 지갑 0) 통과, 원장 drift 0, 목 AI 서비스 정지 상태에서 투표·브로드캐스트 정상. CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 16장 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | LP-06-001, 002, 033 | 3 | 없음 | 앱 골격, DB 적용과 타입(AI 기본값 포함), 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | LP-06-003, 004, 010, 011, 023, 026, 036 | 7 | W0 완료 | 진행자 인증(Stage A Mock 로그인·시드 페르소나. W0 작업은 시드 없이 SQL·단위 테스트로 검증), 도메인 라이브러리, 브로드캐스터, Realtime 권한, 토큰·기본 컴포넌트(2단계), RLS 회귀, AI 서비스 설치 |
| W1-D | LP-06-034 → 035(직렬) | 1 | 023 | 디자인 시스템 3~4단계(사람 비주얼 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | LP-06-005, 013, 015, 018, 021, 024, 037, 047 | 8 | W1·W1-D 완료 | 청중 API, 실시간 훅, 공용 컴포넌트, 오버레이 API, 설정, 문구, AI 게이트, 3D 히어로 |
| W3 | LP-06-006, 007, 012, 014, 016, 017, 022, 038, 040 | 9 | W2 완료 | API 테스트, 편집 화면, 남용 테스트, 훅 테스트, 발표/오버레이, 랜딩, 자료 RAG, Q&A 정리 그래프 |
| W4 | LP-06-008, 009, 027, 031, 039, 041 | 6 | W3 완료 | 콘솔, 청중 화면, 부하 테스트, 배포, 행사 위키, Dify 어시스턴트 |
| W5 | LP-06-019, 020, 025, 030, 032, 042, 044, 045 | 8 | W4 완료 | Q&A 패널, 결과/CSV, E2E, 접근성, 가이드, 어시스턴트 패널, 진행자 음성 대화, 청중 음성 질문 |
| W6 | LP-06-049(G1 통과 후 먼저), 043, 046, 048 | 4 | W5 완료. 049는 G1 판정(`[DECISION] G1 통과`) 뒤 맨 먼저 시작하고 048은 049 완료 뒤 | Stage B Google·이메일 로그인, Q&A AI 정리 패널, 요약 읽어 주기, AI 보안 회귀 → **MVP 출시 조건**(베타 공개) |
| W7(Phase 2) | LP-06-029, 028 / LP-06-050, 051(G2 통과 후) | 2(순차) + 2(병렬) | 029·028은 베타 8주 후 가격 결정(01장 D4, D11). 050·051은 G2(Google 실사용 2주 안정, AUTH_ROADMAP 6장)로 029·028과 독립 | 유료 플랜, 카카오·네이버 로그인 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 10 (002, 011, 026, 027, 029, 036, 037, 048, 049, 051) | 20.0% | 22/91 = 24.2% |
| Opus | 22 (003, 004, 005, 006, 008, 009, 010, 012, 013, 014, 018, 025, 028, 035, 038, 039, 040, 041, 044, 045, 046, 050) | 44.0% | 41/91 = 45.1% |
| Sonnet | 14 (001, 007, 015, 016, 017, 019, 020, 022, 023, 031, 033, 042, 043, 047) | 28.0% | 24/91 = 26.4% |
| Haiku | 4 (021, 024, 030, 032) | 8.0% | 4/91 = 4.4% |
| 합계 | 50(사람 작업 1개 제외, 전체 51개) | 100% | 91 |

비율은 모델 작업 50개 기준이다(2026-10-14: 인증 B·C 작업 049 Fable M, 050 Opus S, 051 Fable M 추가, 003은 Stage A 범위 확대로 S→M. 직전 47개 기준은 Fable 17.0%, Opus 44.7%, Sonnet 29.8%, Haiku 8.5%, 가중 85). 사람 작업 1개(LP-06-034, M)는 비율에서 뺐다. 2026-10-13 이전(32개)은 Fable 15.6%, Opus 40.6%, Sonnet 31.3%, Haiku 12.5%였다. Fable은 DB 적용과 RLS, Realtime 권한, 부하 측정, 결제 라우트에 더해 AI 보안 경계(서명 토큰 검증 036, AI 게이트의 선차감·정산·동의 037, AI 회귀 048)를 맡는다. 그래프·RAG·위키·Dify·음성 구현은 Opus, 패널·3D 히어로·디자인 레퍼런스는 Sonnet이다(`docs/products/_platform-core/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

| 리뷰 5장 # | 리뷰 작업 | 흡수한 작업 ID |
|---|---|---|
| 1 | PRD 보완(수치, 질문 유형, 코드 규칙, 중복 정책, IP 처리, 스택 ADR) | 이 기획 01~05장(완료) + LP-06-001(ADR), LP-06-011(미확인 확인) |
| 2 | 골격 복제, Supabase 클라이언트/shadcn 이식, proxy.ts | LP-06-001, LP-06-003 |
| 3 | 마이그레이션, unique, RLS, 익명 로그인 활성화 | LP-06-002, LP-06-026 (익명 로그인 대신 참가자 토큰, 05장 7절) |
| 4 | `cast_vote` 함수, 원자적 처리, 300ms throttle, 종료 시 최종 스냅샷 | LP-06-002(조각의 `cast_vote`, `collect_broadcasts`), LP-06-010 |
| 5 | `useRoomChannel` 훅과 테스트 | LP-06-013, LP-06-014 |
| 6 | 호스트 대시보드, 상태 제어 | LP-06-007, LP-06-008 |
| 7 | 참가자 페이지 | LP-06-005, LP-06-009 |
| 8 | 결과 차트 + OBS 라우트 | LP-06-015, LP-06-016, LP-06-017, LP-06-018 |
| 9 | QR, 참가자 수 카운터, 연결 배지 | LP-06-015 |
| 10 | 레이트 리밋, 코드 대입 방지, 닉네임 검증 | LP-06-004, LP-06-012 |
| 11 | 부하 테스트 | LP-06-027 |
| 12 | 랜딩 GEO, 방 페이지 noindex, 가이드 | LP-06-022, LP-06-032 |
| 13 | 결과 보존 + CSV | LP-06-020 |

AI·음성·3D·디자인 시스템 작업(LP-06-033~048)은 리뷰 5장 작업 목록에 없는 확정 결정 13~17의 신규 작업이라 위 표에 행이 없다. 출처는 각 작업의 "출처" 열(LP-F-025~037, `DESIGN_SYSTEM.md`)이다.

## 6. 공용 모듈 요청

| ID | 요청 | 대상 | 이유 | 우선순위 |
|---|---|---|---|---|
| R-1 | `handle_new_user`가 `auth.users.is_anonymous = true`인 사용자에 대해 프로필/조직을 만들지 않게 | `_platform-core` 0001, `MONOLITH_CORE_LITE.sql` SECTION 1 | 익명 로그인을 쓰는 제품이 생기면 조직이 폭증한다. 해결 전까지 live-poll은 참가자 토큰을 쓴다(05장 7절) | P2 |
| R-2 | `core.rate_limit_peek(key, limit, window)`(히트 없이 조회) | 0004 | `join_event`가 사전 차단을 위해 `core.rate_limit_buckets`를 직접 읽는다(읽기만). 함수로 감싸면 코어 내부 구조와의 결합이 사라진다 | P2 |
| R-3 | 모듈러 seed의 `poll` 플랜 features 보강(01장 4장·4.1절 키)과 가입 크레딧(free 100)·월 크레딧(pro 1,000, business 5,000), 금액은 D4 결정 뒤 | `_supabase-modular/seed.sql` | 현재는 `1800_poll.sql` 19.2절 병합 UPDATE와 서버 기본값으로 동작. seed가 조각보다 나중에 실행되면 덮어써진다. 이전 항목(free `max_participants` 보강, pro/business 행)은 2026-10-13 코어 반영 완료 | P1 |
| R-4 | `confirm_payment_order` 금액 불일치 시 failed 상태 보존 | 0003 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. live-poll은 PM001 시 별도 호출(05장 8절) | 완료 |
| R-5 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/design-module/_design-guide/HERO_3D.md:56-68`, 제안) | `_design-guide` | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | P1. 우회: `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| R-6 | ai-service: (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) | `services/ai-service` | Dify 보조 노드 라우팅(`dify.aux`, `wiki.query`)과 진행자 위키 편집 | P1. 우회: (a) Dify에 기능별 모델 이름을 따로 등록 (b) poll 확장(`wiki_config.py`)에 임시 구현 |
| R-7 | core-voice: `VoiceAdapter` 호출 컨텍스트에 비로그인 참가자 식별(`visitorKey`, `voice_sessions.visitor_key`)과 "상용 제공자 금지" 옵션(`voice_question`) 명시 | `packages/core-voice` | 청중 음성 질문이 로그인 없는 사용자 STT이고 상용으로 대체하면 안 된다(`VOICE_ARCHITECTURE.md:40-48`의 일반 규칙을 코드 계약으로 강제) | P1. 우회: 청중 음성 라우트가 체인에서 오픈소스 제공자만 넘겨 호출 |
| R-8 | 공용 Dify: `poll-assistant` 앱 생성, 내부 키 환경 변수, 외부 지식(사용 방법 FAQ) 등록, 로그 보존 30일 | 공용 Dify | 공용 인프라는 코어 소유 | P0. 장애 시 `/tools/answer-direct` |

## 7. 완료 정의

| 항목 | 기준 |
|---|---|
| 빌드 | `pnpm build`(앱), 워커 `pnpm build` 성공 |
| 타입/린트 | `tsc --noEmit`, `eslint` 0 오류, `as any` 0건 |
| SQL | `docs/products/_tools-sqlcheck` mod/mono OK |
| RLS | LP-06-026 전 항목 통과(모듈러, 모놀리스) |
| E2E | LP-06-025 통과(Mock 페르소나 storageState). 공개 베타 전 P0 LP-06-049(Stage B) ↔ 테스트: B-1~B-6(Google 실로그인은 수동 점검표, LP-06-025 Mock E2E 계속 녹색). Phase 2는 LP-06-028(결제 E2E) 통과, C1·C2는 LP-06-050·051 수용 기준 |
| 성능 | LP-06-027 보고서에서 300명 이하 p95 500ms 이내, Q&A AI 정리 동시 실행에도 변화 없음 |
| AI·음성 | `pytest apps/api` 통과, LP-06-048 녹색, 그래프 평가셋(LP-06-040)·대화 평가셋(LP-06-041) 통과, 청중 원문 단계 상용 호출 0, 음성 남용 시나리오 통과 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(LP-06-035) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 06장 | MVP 작업 완료(51개 중 Phase 2 작업 029·028과 G2 후 작업 050·051은 각자 완료 정의) |
| 명령 | `pnpm db:seed-users`(로컬 전용, `supabase db reset` 뒤), `pnpm test`, `pnpm test:e2e`, `pnpm test:rls`, `pytest`(apps/api), `node check.mjs --vector mod ...`, `node check.mjs --vector mono ...` |

## 8. 인증 단계 작업 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 9장(작업 계획 반영 규칙)과 8장(live-poll 행: open, 진행자만 로그인, A 추가 페르소나 행사 진행자·공동 진행자, B Google + 이메일, C1 P1, C2 P1). 기존 인증 작업 LP-06-003은 2절에서 Stage A로 범위를 바꿨다. 아래 3개는 새 작업이고 ID는 기존 최대 048 다음부터다. 로그인하지 않는 청중(코드·QR 입장, 참가자 토큰)과 OBS 오버레이(키)의 흐름은 단계와 무관하므로 이 작업들은 `src/app/(participant)/`, `src/app/overlay/`, `src/app/api/p/`, `src/app/api/overlay/`, `src/lib/realtime-auth/`를 수정하지 않고 그 화면에 로그인 버튼을 넣지 않는다.

### 8.1 작업 목록 (2절과 같은 열)

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| LP-06-049 | Stage B: Google OAuth 전환 + 이메일 가입·로그인·비밀번호 재설정 화면. 로그인 화면 제공자 버튼("Google로 계속하기", `prompt: 'select_account'`), `/auth/callback`(`finishLogin` 전체: 코드 교환 → `session_context` → poll은 open이라 `bootstrap_app_for_org('poll')` 1회 → 상태 분기 → `next` 화이트리스트 → 감사 `auth.login`)과 단위 테스트, `/onboarding` 첫 단계 베타 약관 동의(OAuth 첫 로그인)와 동의 기록 방식 결정, 로컬 `supabase/config.toml` B 설정, 배포 체크리스트 | `src/app/(auth)/`(003에서 이어 받음: login B 구성, signup, reset-password. 직렬이라 동시 쓰기 없음), `src/app/auth/callback/`, `src/app/onboarding/terms/`(037 소유 `src/app/onboarding/` 안에서 이 하위 경로만 단독 소유. `/onboarding` 첫 단계 연결은 037 파일에 1줄 요청), `supabase/config.toml`의 `[auth.external.google]`·`additional_redirect_urls`(002가 만든 파일의 해당 절만), `docs/deploy/auth-checklist.md`. 시드 페르소나의 약관 동의 기록은 003 소유 `scripts/dev/seed-users.poll.mjs`에 1줄 요청 | LP-06-003, LP-06-037, LP-06-025, G1(사람 판정 `[DECISION] G1 통과`) | P0 | M | Fable | AUTH_ROADMAP 5.3절 B-1~B-6 그대로: B-1 새 Google 계정 첫 로그인 → `session_context('poll')` `entitled=true`, `plan_code='free'`, 가입 크레딧 100이 1회만(재로그인 3회 뒤 원장 행 수 같음). B-2 `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` → `/events`. B-3 `code` 없음·재사용·만료 → `/login?error=callback`, 서버 오류 로그에 토큰·코드 없음. B-4 `VERCEL_ENV=production` 빌드에서 `/api/dev/login` 404, 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패. B-5 Mock E2E(LP-06-025) 계속 녹색, Google 실로그인은 사람이 수동 점검표(데스크톱·모바일 각 1회, 신규·기존 계정)로 확인해 task `log.md`에 기록. B-6 운영 대시보드 Google 설정, Redirect URLs, `AUTH_PROVIDERS=google,email`이 배포 체크리스트와 일치. 제품 추가: 청중 입장·투표·오버레이 E2E가 B 전환 전후 같은 결과(로그인 없는 흐름 불변) | LP-F-001, AUTH_ROADMAP 3.2, 5장, 01장 8.1절 |
| LP-06-050 | Stage C1: 카카오 로그인. "카카오로 계속하기" 버튼, 로컬 config C1 설정, 이메일 정책(01장 D19) 반영, (b)면 결제 전 연락 이메일 입력 화면, 설정 → 로그인 방법(연결·해제, `linkIdentity`, 감사 `auth.identity_link`·`auth.identity_unlink`) | `src/lib/auth/providers/kakao.ts`(003 소유 `src/lib/auth/` 안의 이 파일만), `src/app/(host)/settings/login-methods/`(021 소유 `settings/` 안에서 이 하위 경로만 단독 소유. 설정 화면 탭 링크는 021 파일에, 로그인 버튼 목록 장착은 049가 이어 받은 `(auth)` 파일에 1줄 요청), `supabase/config.toml`의 `[auth.external.kakao]`, `docs/deploy/auth-checklist.md` 카카오 절 | LP-06-049, LP-06-021. 진입 조건 G2(사람 판정 `[DECISION] G2 통과`), 01장 D19 확정 | P1 | S | Opus | AUTH_ROADMAP 7.1.3절 C1-1~C1-5 그대로: C1-1 새 카카오 계정 첫 로그인 → B-1과 같은 결과. C1-2 비즈 앱(a)이면 Google로 가입한 같은 이메일 사용자가 카카오로 로그인 → 같은 `user_id`(자동 연결은 제공자가 이메일 인증을 확인한 경우만, 미확인이면 7.3절 수동 연결). C1-3 (b)면 이메일 없는 사용자가 결제 전 연락 이메일 입력 화면을 본다. C1-4 표시 이름은 카카오 닉네임, 없으면 `user` 규칙. C1-5 버튼은 카카오 디자인 가이드 색·문구(미확인: 최신판 확인 후 반영). 계정 연결 해제는 남는 수단 1개 이상일 때만 | 01장 8.1절, AUTH_ROADMAP 7.1, 7.3절 |
| LP-06-051 | Stage C2: 네이버 로그인. 첫 단계 스파이크(0.5일, `custom:naver` 등록 스크립트 `scripts/auth/register-naver-provider.mjs`) → `supabase_custom` 또는 브리지 채택(01장 D20). 브리지면 `/auth/naver/start`·`/auth/naver/callback`과 코어 요청(8.3절 R-9). "네이버로 계속하기" 버튼, 설정 → 로그인 방법에 네이버 연결, 네이버 검수 신청 자료(로그인 버튼부터 가입 완료까지 캡처) | `scripts/auth/`, `src/app/auth/naver/`(브리지만), `src/lib/auth/providers/naver.ts`와 `src/lib/auth/naver/`(003 소유 `src/lib/auth/` 안의 이 경로만), `docs/deploy/naver-review/`(검수 캡처). 로그인 버튼 목록 장착은 049가 이어 받은 `(auth)` 파일에, 설정 → 로그인 방법의 네이버 행은 050 완료 후 050 파일에 1줄 요청 | LP-06-049. 진입 조건 G2, 브리지면 코어 R-9(8.3절) 적용 후 | P1 | M | Fable | AUTH_ROADMAP 7.2.4절 C2-1~C2-6 그대로: C2-1 스파이크 결과가 `[DECISION]`으로 기록되고 `NAVER_AUTH_PATH`가 그 값. C2-2 새 네이버 계정 첫 로그인 → B-1과 같은 결과. C2-3 같은 네이버 계정 재로그인 5회 → 같은 `user_id`, 사용자 수 증가 0. C2-4 (브리지) state 변조·재사용·쿠키 없음 → 거부, 세션 미생성, 다른 브라우저 콜백 URL 재생 거부. C2-5 (브리지) 같은 이메일의 Google 가입자가 네이버로 처음 로그인 → `email_in_use` 안내, 새 사용자 0. C2-6 네이버 검수 통과 전에는 운영 `AUTH_PROVIDERS`에 `naver` 없음 | 01장 8.1절, AUTH_ROADMAP 7.2, 7.3절, `SECURITY_BASELINE.md` 17장 |

### 8.2 게이트와 웨이브 (3절 표에 같은 내용을 줄 안에 적었다)

| 작업 | 게이트 | 웨이브 | 비고 |
|---|---|---|---|
| LP-06-003(Stage A) | 없음 | W1 | 이보다 앞선 W0(001, 002, 033)은 시드 스크립트 없이 SQL·단위 테스트로 검증 |
| LP-06-049(Stage B) | G1(AUTH_ROADMAP 4장): 2절 MVP P0 기능 작업 완료(049·050·051과 공개 베타 직전 통합 작업 048 제외), LP-06-025 핵심 플로우 Mock E2E 녹색, LP-06-026 RLS 스모크 전 항목과 `outsider` 거부, 인증 모듈 밖 단계 분기 0건, 외부 준비(Google Cloud 동의 화면·웹 클라이언트 ID·운영 Supabase). 결제 E2E는 Phase 2라 G1 조건에서 제외 | W6 맨 앞 | 마지막 기능 웨이브 W5 다음, 공개 베타 직전 통합 웨이브. LP-06-048(AI 보안 회귀)은 049 완료 뒤 시작 |
| LP-06-050(C1), LP-06-051(C2) | G2(AUTH_ROADMAP 6장): Google 실사용 공개 베타 2주(제안), 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안), `entitled=false` 잔존 0, 카카오 앱·네이버 등록 준비 | W7(Phase 2 웨이브 행에 병렬로) | MVP 출시 후 웨이브. 결제 작업 029·028과 독립. 050·051은 둘 다 049만 선행이라 병렬(051의 로그인 방법 네이버 행은 050 완료 후 1줄 요청). 네이버 검수 기간 때문에 신청은 G2 직후 |

### 8.3 코어 요청 (6절 표에 이어서)

| ID | 요청 | 대상 | 이유 | 우선순위 |
|---|---|---|---|---|
| R-9 | C2를 브리지 경로로 정하면 `staged/0010_core_auth_identity_links.sql` 적용 | `_platform-core`(코어가 한 번만 적용, 전 제품 공용) | 브리지는 네이버 고유 id로 사용자를 찾아야 하고 `core.oauth_states`는 로그인 전에 쓸 수 없다(AUTH_ROADMAP 7.2.3절) | P1(D20이 bridge일 때만) |
| R-10 | 베타 약관 동의 기록의 코어 표준(감사 이벤트 이름 또는 동의 테이블) | `_platform-core` | OAuth 첫 로그인 약관 동의를 제품마다 다르게 기록하지 않게. 해결 전까지 LP-06-049가 `core.write_audit`(`terms.accept`, 약관 버전)로 기록(제안) | P2 |

### 8.4 기존 문서와 달라진 점

| 항목 | 내용 | 처리 |
|---|---|---|
| 작업 수 | 48개(모델 작업 47, 사람 1) | 51개(모델 작업 50, 사람 1). 머리말, 4절, 7절, README, 개발 문서(`docs/develop/live-poll/`) 작업 수를 같이 바꿨다 |
| `src/app/(auth)/` 소유 | 003 단독(로그인·가입 화면) | 003(A 구성) → 049가 이어 받음(직렬이라 동시 쓰기 없음). 050·051의 버튼은 `src/lib/auth/providers/`의 자기 파일만 소유하고 버튼 목록 장착은 1줄 요청 |
| 온보딩 약관 단계 | 없음(이메일 가입 폼에서 동의) | OAuth 첫 로그인용 약관 단계를 049가 `src/app/onboarding/terms/`로 만들고 037 소유 `/onboarding`에 1줄 요청으로 연결(03장 7.3절) |
| 설정 → 로그인 방법 | 없음 | 050이 021 소유 `settings/` 안의 `login-methods/` 하위 경로만 소유. 로그인한 모든 진행자 본인이 접근(03장 1절, 7.4절) |
| LP-06-003 규모 | Stage A 범위(인증 모듈, Mock 로그인, 시드 스크립트+제품 훅, 가드 4종)가 기존 범위(proxy, 로그인·가입 화면)보다 커졌다 | S → M으로 바꾸고 4절 가중치에 반영. 선행 작업에 LP-06-002(시드가 로컬 DB를 요구) 추가 |
| G1의 결제 E2E 조건 | AUTH_ROADMAP 4장 4번은 결제가 있는 제품에만 적용. live-poll 결제는 Phase 2(029, 028) | G1 조건에서 제외 |
| CI 금지 문자열 | 기존 작업에 "Mock 로그인" 금지 검사가 없었다 | AUTH_ROADMAP 9장 문구로 LP-06-003 수용 기준에 새로 넣었다 |
| 공동 진행자 | 01장 2절에서 Phase 2 기능인데 AUTH_ROADMAP 8장은 A 페르소나로 "공동 진행자"를 요구 | 화면 없이 코어 `invite_member`·`accept_invite`로 `cohost`(member) 페르소나만 만든다(05장 10절). 초대 화면은 계속 Phase 2 |
| `pending` 페르소나 | poll은 open 앱이라 approval 상태가 없다 | 만들지 않는다(05장 10절) |
