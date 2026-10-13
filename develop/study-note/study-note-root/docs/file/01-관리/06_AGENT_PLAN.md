# 06 에이전트 작업 계획: Study Note

작성일 2026-10-12. 작업 ID는 `NT-06-###`(약어 NT는 SQLSTATE 접두사와 같음, `DB_CONVENTIONS.md:22`). 리뷰 = `docs/reference/reviews/study-note-organizer-codex-01.md`.

2026-10-13: AI 계층·음성·3D 히어로·디자인 시스템 작업 NT-06-031~052(22개, 사람 작업 1개 포함)를 이어 붙였다. 기존 NT-06-001~030의 ID와 내용은 유지하고, 화면 작업의 선행에 디자인 시스템 4단계(NT-06-034)를 추가하고 `tokens.css` 소유를 NT-06-032로 옮겼다. 웨이브는 W0~W7로 다시 짰다(기존 W5는 W7).

## 1. 원칙과 소유 경계

병렬 에이전트는 디렉토리 단위로만 쓴다. 두 작업이 같은 경로를 소유하지 않는다. 공유 파일(루트 설정, `packages/*`)은 건드리지 않는다.

| 원칙(2026-10-13 추가) | 내용 |
|---|---|
| 디자인 시스템 순서 | 화면 작업(016, 017, 018, 019, 020, 021, 041, 042, 043, 047, 051)은 NT-06-034(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:39-49`). 컴포넌트는 `DESIGN_SYSTEM.md` 8장 템플릿으로 1개씩 맡긴다 |
| 사람 작업 | NT-06-033(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| AI 서비스 경계 | `apps/api/`는 NT-06-035가 공용 ai-service를 설치하고 공용 부분을 소유한다. notes 확장은 작업별로 나눈다(위 표). 공용 AI 패키지(`packages/ai-gateway`, `packages/core-voice`, 공용 ai-service 원본, 공용 Dify·GPU 서버)는 수정하지 않는다. 필요하면 6절 요청(C-6~C-10) |
| 이름 규칙 | 잡 `notes.organize`(일지)와 LangGraph `notes.organize`(노트 정리)를 섞지 않는다. 02장 4.2절 표 |

| 영역 | 소유 경로 | 작업 |
|---|---|---|
| 저장소 위생/CI | `apps/study-note/.gitignore`, `apps/study-note-worker/.gitignore`, `apps/*/.env.example`, `.github/workflows/study-note-*.yml` | 001, 022 |
| DB | `supabase/migrations/2100_notes.sql`, `apps/study-note/supabase/monolith/**`, `apps/study-note/src/types/supabase.ts`, `scripts/study-note/to-monolith.*` | 002, 004 |
| 테스트 | `apps/study-note/tests/rls/**`, `tests/unit/**`, `tests/e2e/**`, `apps/study-note-worker/tests/**` | 003, 008, 011, 024, 027 |
| 플랫폼 연결 | `apps/study-note/src/lib/platform/**`, `src/proxy.ts`, `src/lib/server/**` | 005, 014 |
| pipeline | `apps/study-note/src/lib/pipeline/**` | 007 |
| LLM 어댑터 | `apps/study-note-worker/src/llm/**` | 009 |
| 워커 | `apps/study-note-worker/src/handlers/**`, `src/main.ts`, `src/cron/**` | 010, 025, 028(동기화 잡) |
| API | `apps/study-note/src/app/api/notes/**` | 012, 013 |
| 결제 | `apps/study-note/src/app/api/billing/**`, `src/app/api/webhooks/**`, `src/app/(app)/app/billing/**` | 026 |
| 클라이언트 상태 | `apps/study-note/src/lib/client/**` | 015 |
| 인증 화면 | `apps/study-note/src/app/(auth)/**` | 006 |
| 컴포넌트 이식 | `apps/study-note/src/components/common/**` | 016 |
| 작업실 | `src/components/workspace/**`, `src/app/(app)/app/page.tsx` | 017 |
| 설정 | `src/components/settings/**`, `src/app/(app)/app/settings/**` | 018 |
| 보관함 | `src/components/history/**`, `src/app/(app)/app/history/**` | 019 |
| 랜딩 | `src/app/(marketing)/**`, `src/components/marketing/**` (`tokens.css`는 032 소유, 020은 읽기만) | 020 |
| 디자인 시스템 | `src/styles/tokens.css`, `src/components/ui/**`, `src/app/dev/components/**`, `docs/file/03-설계/디자인/DESIGN.md`(1절은 031, 2절 이후는 034), `COMPONENTS.md`, `review/`(033, 사람) | 031, 032, 033, 034 |
| FastAPI 기반 | `apps/api/`(공용 ai-service 적용, `app/core/`, 라우터, 잡 소비자 `app/ai/jobs/`), `apps/api/tests/platform/` | 035 |
| AI 게이트 | `src/app/api/ai/organize/`, `runs/`, `conversations/`, `chat/`, `src/app/api/internal/`, `src/app/api/onboarding/`, `src/app/onboarding/`, `src/server/ai/`, `src/server/ai-pricing.ts` | 036 |
| 색인(RAG) | `apps/api/app/ai/products/notes/rag.py`, `src/app/api/notes/documents/`, `apps/api/tests/notes/retrieval/` | 037 |
| 과목·위키 백엔드 | `apps/api/app/ai/products/notes/wiki_config.py`, `src/app/api/ai/wiki/`, `src/app/api/notes/subjects/` | 038 |
| 노트 정리 그래프·퀴즈 API | `apps/api/app/ai/graphs/notes_organize.py`, `apps/api/app/ai/compliance/notes.py`, `apps/api/app/ai/products/notes/quiz.py`, `src/app/api/ai/quizzes/`(조회, 세션, 채점), `apps/api/tests/notes/graph/` | 039 |
| 채팅 백엔드 | `infra/dify/`, `apps/api/app/ai/tools/notes/`, `apps/api/tests/notes/chat/` | 040 |
| 채팅 화면 | `src/components/ai-chat/`, `src/app/(app)/app/chat/` | 041 |
| 위키 화면 | `src/components/wiki/`, `src/app/(app)/app/subjects/**` | 042 |
| 노트·퀴즈 화면 | `src/components/notes/`, `src/components/quiz/`, `src/app/(app)/app/notes/**`, `src/app/(app)/app/quiz/**` | 043 |
| 음성 대화 | `src/app/api/voice/`(`lectures/` 제외), `src/components/voice/`, `packages/core-voice` 사용 설정 | 044 |
| 강의 녹음 API | `src/app/api/voice/lectures/`, `src/server/lecture/` | 045 |
| 퀴즈 음성 | `src/components/quiz-voice/` | 046 |
| 3D 히어로 | `src/components/hero3d/`, `public/hero/` | 047 |
| AI 보안 회귀 | `apps/api/tests/notes/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | 048 |
| AI 평가셋 | `apps/api/tests/notes/eval/`, `content/eval-notes/` | 049 |
| AI 정산·정리 크론 | `apps/study-note-worker/src/cron-ai/**` | 050 |
| 강의 녹음 화면 | `src/components/lecture/`, `src/app/(app)/app/lecture/**` | 051 |
| AI 고지문 | `src/components/ai-notice/**`, `src/lib/notices/ai-notices.ts` | 052 |
| 법무 | `src/app/(legal)/**`, `src/components/consent/**` | 021 |
| 관리자 | `src/app/(admin)/admin/models/**` | 028 |
| 문서 | `apps/study-note/README.md` | 023 |
| 운영 리포트 | `apps/study-note-worker/src/reports/**` | 029 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| NT-06-001 | 저장소 위생: `.gitignore`, `.env.example`(변수 이름만), 의존성 고정, lockfile, 비밀 스캔 CI, 번들 키 패턴 검사 | `.gitignore`, `.env.example`, `.github/workflows/study-note-secrets.yml` | 없음 | P0 | S | Haiku | `.env`에 키를 넣고 커밋하면 CI가 실패한다. `.next/static`에 `sk-or-` 문자열이 있으면 CI가 실패한다. `package.json`에 `latest`가 없다 | 리뷰 5장 #1, #2, #7, #2 |
| NT-06-002 | DB 조각 검토와 적용: `2100_notes.sql` 로컬 적용, 타입 생성, `[api].schemas`에 notes 추가 | `supabase/migrations/2100_notes.sql`, `src/types/supabase.ts` | 없음 | P0 | S | Fable | 체커 OK. `supabase db reset` 후 `session_context('notes')`가 entitled=true, 잔액 30. 모놀리스 3파일도 OK | 01장 NT-F-003, 05장 |
| NT-06-003 | RLS/권한 회귀 테스트: PGlite 스모크를 CI 자동화(타 조직 0행, 쓰기 거부, 컬럼 GRANT, 함수 EXECUTE, 상태 전이, 환불 이중 없음, 보존) | `tests/rls/**` | 002 | P0 | M | Fable | 05장 9절 스모크 항목 전부 통과(모놀리스 85, 모듈러 84 이상). 코어 PUBLIC EXECUTE 결함 항목은 코어 수정 전까지 "알려진 결함"으로 분리 표시 | `SECURITY_BASELINE.md` 15장, 리뷰 #3 |
| NT-06-004 | 모듈러 → 모놀리스 변환 스크립트와 동기화 검사(조각을 변환해 0002와 바이트 비교) | `scripts/study-note/to-monolith.*`, `apps/study-note/supabase/monolith/**` | 002 | P1 | S | Haiku | 스크립트 실행 결과가 커밋된 0002와 같다. 불일치 시 CI 실패 | `DB_CONVENTIONS.md:264` |
| NT-06-005 | 플랫폼 연결: env 검증기(NEXT_PUBLIC 접두사 비밀 금지, 필수 변수 누락 시 기동 실패), Supabase 클라이언트 3종, `requireSession('notes')`(이메일 인증 포함), `proxy.ts` | `src/lib/platform/**`, `src/proxy.ts` | 001 | P0 | M | Opus | 누락된 필수 env로 기동하면 실패한다. 미인증 이메일의 실행 요청은 403. 프로필 없음은 로그아웃(기본 admin 금지) | 리뷰 #2, `SHARED_MODULES.md` 2장 |
| NT-06-006 | 가입/로그인/이메일 인증 화면(`signup_app='notes'`, 만 14세 체크) | `src/app/(auth)/**` | 005 | P0 | M | Sonnet | 가입 직후 `/app`에서 잔액 30이 보인다. 체크 없이 가입 불가 | 01장 NT-F-001 |
| NT-06-007 | pipeline 순수 로직: 프롬프트(원본 PRD 4장 + 입력 구분자), KST 날짜(`todayKst`), `getDateParts`, 키워드 추출/제거, 파일명, 출력 형식 검증 | `src/lib/pipeline/**` | 없음 | P0 | M | Opus | KST 00:30에 `todayKst()`가 그날 날짜. 원본 예시가 `260528_데이터분석_UXUI트렌드.txt`. 구분선/헤더 없는 출력은 `bad_format` | 리뷰 #5, 01장 NT-F-005, 017 |
| NT-06-008 | 단위 테스트(Vitest): 날짜, 키워드, 파일명, 형식 검증, 오류 매핑 | `tests/unit/**` | 007 | P0 | M | Opus | 위 함수 전부 정상/경계/빈 값 케이스. 키워드 누락 시 "정리","수업". 커버리지 80% 이상(pipeline 디렉토리) | 리뷰 5장 #12 |
| NT-06-009 | LLM 어댑터: 코어 게이트웨이 호출, 명시 모델, prepaid 옵션, 같은 등급 폴백, 오류 매핑(02장 5절), 데이터 사용 거부 옵션 확인 | `apps/study-note-worker/src/llm/**` | 005, 007 | P0 | M | Opus | 모의 공급사 429/404/빈 응답/타임아웃에서 단계 error_code가 02장 5절 표와 일치. `ai_usage` 행이 생긴다 | 리뷰 5장 #14, `SHARED_MODULES.md` 8장 |
| NT-06-010 | 워커 `notes.organize` 핸들러(02장 4절 9단계): 잡-실행 대조, 병렬 호출, 취소 확인, 하트비트, `finish_run` | `apps/study-note-worker/src/handlers/**`, `src/main.ts` | 002, 007, 009 | P0 | L | Opus | 2모델 성공 → 통합 → succeeded. 한쪽 실패 → partial(통합 skipped, 환불). 워커 강제 종료 후 `reap`이 failed + 환불. 중복 잡 payload 위조 시 `fail_job` | 리뷰 #3, #9, 5장 #14 |
| NT-06-011 | 워커 통합 테스트(모의 게이트웨이 + 로컬 DB): 성공, 부분, 전부 실패, 취소, 늦은 응답(NT003), 이중 환불 없음 | `apps/study-note-worker/tests/**` | 010 | P0 | M | Opus | 위 6 시나리오 통과, 원장 drift 0 | 리뷰 #3 |
| NT-06-012 | API: 실행 생성/재요청/취소/조회 + SQLSTATE → HTTP 매핑 | `src/app/api/notes/runs/**` | 005, 007, 002 | P0 | M | Opus | 같은 `request_id` 2회 → 같은 run, 잔액 1회만 차감. 동시 2요청 → 하나는 409. 402/422/429/503 매핑이 04장 7절과 일치 | 리뷰 #3, #9 |
| NT-06-013 | API: 모델 목록, 설정, 동의, 내보내기, 계정 삭제 | `src/app/api/notes/models/**`, `settings/**`, `consent/**`, `export/**`, `account/**` | 005, 002 | P0 | M | Opus | 비허용 등급 저장 시 422. 내보내기 JSON에 전체 일지와 카드. 삭제 요청이 감사 로그에 남는다 | 01장 NT-F-009, 013 |
| NT-06-014 | 비용 보호 연결: 레이트 리밋(분당 6회), 가입 IP 제한, 일일 상한 알림, 이메일 인증 게이트 | `src/lib/server/**` | 005 | P0 | S | Opus | 1분 내 7번째 요청은 429 + `Retry-After`. 일일 상한 도달 시 운영 알림 1회 | 분석 기획 공백 3 |
| NT-06-015 | 클라이언트 상태: `usePipeline`(runId, AbortController, Realtime 구독, 폴링 폴백), 초안 캐시(try/catch, 300ms 디바운스, 용량 초과 무시) | `src/lib/client/**` | 007 | P0 | M | Opus | 이전 `runId` 이벤트가 새 결과를 덮지 않는다. localStorage를 막아도 동작. 실행 중 모든 진입점이 비활성 | 리뷰 5장 #3, #6, #9 |
| NT-06-016 | 원본 컴포넌트 이식(Vite → Next): Header, ResultCard, ErrorDisplay, LoadingSpinner. 데드 코드 제외 | `src/components/common/**` | 001, 034 | P0 | M | Sonnet | 이식한 컴포넌트에 `useLocalStorage`, `RESET_RESULTS`가 없다. 스토리/스냅샷 렌더 통과 | 리뷰 5장 #10 |
| NT-06-017 | 작업실 화면: 입력부, 결과 3카드, 크레딧 표시, 취소, 무료 모델 배너, 반응형 | `src/components/workspace/**`, `src/app/(app)/app/page.tsx` | 015, 016 | P0 | M | Sonnet | 03장 3.1절 구성. 1024px 이상 2열+통합, 768px 2열, 미만 1열 | 리뷰 5장 #11, #3 |
| NT-06-018 | 설정 화면: 등급 optgroup, 무료 모델 툴팁, 열 때 draft 재초기화, 테마, 데이터 메뉴 | `src/components/settings/**`, `src/app/(app)/app/settings/**` | 013, 016 | P0 | M | Sonnet | 테마를 바꾼 뒤 모델 저장해도 테마가 유지. 취소한 편집이 다음에 열릴 때 남지 않는다 | 리뷰 5장 #4, #11 |
| NT-06-019 | 보관함 화면: 목록, 날짜/키워드 검색, 상세 복원, 휴지통 | `src/components/history/**`, `src/app/(app)/app/history/**` | 015, 016 | P1 | M | Sonnet | 다른 브라우저에서도 같은 목록. 휴지통 복원/영구 삭제 동작 | 01장 NT-F-008 |
| NT-06-020 | 랜딩: 03장 4절 와이어프레임(토큰은 NT-06-032의 `tokens.css`를 쓴다), 정리본 예시와 형광펜 연출 1회(3D 장면은 NT-06-047) | `src/app/(marketing)/**`, `src/components/marketing/**` | 001, 034 | P0 | M | Sonnet | 설계 체크리스트 7단계 통과(NT-06-030). 가상 후기/미검증 수치 0건 | 01장 6.1, 03장 4절 |
| NT-06-021 | 약관/개인정보처리방침 페이지, 첫 실행 동의 모달 | `src/app/(legal)/**`, `src/components/consent/**` | 001, 034 | P0 | S | Sonnet | 동의 없이 실행 불가, 동의가 감사 로그에 남는다. 문구 초안은 법무 확인 표시 | 01장 6장 |
| NT-06-022 | ESLint(typescript-eslint, react-hooks), tsconfig strict, CI(lint, tsc, build, vitest, SQL 체커) | `.github/workflows/study-note-ci.yml`, `eslint.config.*` | 없음 | P1 | S | Haiku | CI가 5단계를 실행하고 `latest` 의존성/`any` Supabase 캐스팅을 거부 | 리뷰 5장 #13 |
| NT-06-023 | 앱 README(설치/실행/빌드/env 변수 이름/보안 주의), 원본 README 사본 폐기 확인 | `apps/study-note/README.md` | 005 | P1 | S | Sonnet | env 키 값 사용 안내가 없다. 신규 개발자가 문서만으로 로컬 기동 | 리뷰 5장 #8 |
| NT-06-024 | E2E(Playwright): 가입 → 인증 → 실행 → TXT 다운로드, 연타 방지(버튼 3종), 크레딧 부족, 재요청 | `tests/e2e/**` | 006, 010, 012, 017, 018 | P0 | M | Opus | 연타해도 run 1개, 차감 1회. 다운로드 파일명 규칙 일치 | 리뷰 #3, 01장 NT-F-003~006 |
| NT-06-025 | 스케줄: `purge_deleted` 일 1회, 보존 정책 호출, 코어 스케줄 확인 | `apps/study-note-worker/src/cron/**` | 010 | P1 | S | Opus | 30일 지난 휴지통 항목이 사라진다. 실행 로그에 삭제 건수 | 05장 |
| NT-06-026 | 결제(Phase 2): 주문 생성, confirm, 웹훅, Pro/크레딧팩 UI, `is_active` 전환 절차 | `src/app/api/billing/**`, `src/app/api/webhooks/**`, `src/app/(app)/app/billing/**` | 002, 005 | P1 | L | Fable | 금액 불일치는 지급 없음. 같은 `paymentKey` 재호출 멱등. 웹훅 서명 실패 401. PM001 시 별도 호출로 `fail_payment_order`를 부른다 | 확정 결정 4, 코어 반영(2026-10-13) |
| NT-06-027 | 결제 E2E(Toss 테스트 키): 성공, 취소, 금액 위조, 중복 confirm | `tests/e2e/billing/**` | 026 | P1 | M | Opus | 4 시나리오 통과, 잔액/원장 일치 | `DOC_TEMPLATE.md` 필수 |
| NT-06-028 | 모델 카탈로그 관리 화면과 동기화 잡 | `src/app/(admin)/admin/models/**`, `apps/study-note-worker/src/handlers/sync*` | 010, 013 | P1 | M | Opus | platform_admin만 접근(일반 사용자 403). 비활성 처리 후 설정 화면에서 사라진다 | 리뷰 5장 #14, 분석 공백 3 |
| NT-06-029 | 운영 리포트: 모델별 크레딧당 원가, 환불률, 상한 도달 일수. 단가 보정안 | `apps/study-note-worker/src/reports/**` | 010 | P1 | S | Opus | 주간 리포트가 01장 7절 지표를 출력 | 01장 4.3, 7장 |
| NT-06-030 | 디자인 출시 체크리스트 7단계 자동 점검(뷰포트 4종, 포커스, reduced-motion, 대비, 이모지 아이콘, 금지 문구 grep) | `tests/e2e/design/**` | 017, 018, 020 | P0 | S | Haiku | 12개 항목 통과 리포트 | `DESIGN_PRINCIPLES.md` 7단계 |
| NT-06-031 | 디자인 시스템 1단계: 레퍼런스 확정(채팅·노트·위키·퀴즈 Astryx 패턴 존재·라이선스 확인, 보조 Primer, 랜딩 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.5절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안(Primer + shadcn/ui) 기록(01장 D-17). 고문(Fable) 검토 기록 | `DESIGN_SYSTEM.md` 4장 1단계, 9절 |
| NT-06-032 | 디자인 시스템 2단계: `tokens.css`(`@theme`, 라이트/다크)와 기본 컴포넌트(Button, Input, Textarea, Select, Checkbox, Switch, Dialog, Sheet, Toast, Table, StatusBadge, Tabs, Tooltip, Progress, Skeleton, Kbd, Tag)와 `/dev/components`, `COMPONENTS.md` 초안 | `src/styles/tokens.css`, `src/components/ui/**`, `src/app/dev/components/**`, `docs/file/03-설계/디자인/COMPONENTS.md` | 005, 031 | P0 | M | Sonnet | 03장 3.5절 의미 기반 토큰 이름과 4.3절 값(라이트/다크)이 정의된다. 기본 컴포넌트가 배리언트·상태 표대로 `/dev/components`에 렌더된다. 컴포넌트 `bg-[#...]` 등 hex 직접 사용 0(린트), `tailwind.config.js`·v3 문법 0, Tailwind CSS v4 CSS 우선 설정. 작업 지시는 `DESIGN_SYSTEM.md` 8장 템플릿(대상, 근거, 스택 버전, 배리언트, 수치, 금지, 검증)으로 컴포넌트 1개씩 | `DESIGN_SYSTEM.md` 4장 2단계, 6장, 8장 |
| NT-06-033 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | 032 | P0 | M | 사람(보조 Sonnet) | 03장 3.5절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | `DESIGN_SYSTEM.md` 4장 3단계 |
| NT-06-034 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | 033 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | `DESIGN_SYSTEM.md` 4장 4단계 |
| NT-06-035 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, notes 설정(app `notes`, 컬렉션 이름 규칙), JWKS 서명 토큰 검증, 라우터·국외 동의 필터 연동, 잡 소비자(큐 `notes.ai`: claim, heartbeat, complete, fail) | `apps/api/`(notes 확장 파일 제외), `apps/api/tests/platform/` | 001, 002 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org의 문서 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux`·`lecture_note` 상용 0, 잡 소비자가 `notes.ai` 큐를 처리하고 최종 실패 시 `fail_job` 자동 환불, 필수 변수 누락 시 기동 실패 | 02장 4.1·5절, `AI_ARCHITECTURE.md:25-56`, `:132-160` |
| NT-06-036 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 노트 정리 시작·조회·취소, 서명 토큰 발급, 입력 마스킹, 정산 엔드포인트, AI 단가, 온보딩 국외 이전 동의 | `src/app/api/ai/organize/`, `runs/`, `conversations/`, `chat/`, `src/app/api/internal/`, `src/app/api/onboarding/`, `src/app/onboarding/`, `src/server/ai/`, `src/server/ai-pricing.ts` | 005, 035, 002 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 동의 시 `ai_org_settings`와 감사 기록 버전 일치, 토큰 `jti` 재사용 거부, 마스킹 규칙 단위 테스트, 정산 후 10분 넘은 `settled_at is null` 0 | 01장 NT-F-019, 024, 028, 04장 1·2.1절 |
| NT-06-037 | RAG 색인과 업로드 API: 서명 업로드 URL, 문서 등록(권한 확인 감사), 색인 요청, 삭제, 컬렉션 `rag:s-<sid>`(임베딩 `notes.knowledge`), 검색 평가 | `apps/api/app/ai/products/notes/rag.py`, `src/app/api/notes/documents/`, `apps/api/tests/notes/retrieval/` | 035, 036, 049 | P0 | M | Opus | 업로드 경로를 서버가 정한다(클라이언트 경로 무시). 권한 확인 누락 403, 같은 내용 409, 한도 초과 422. 10,000자 p95 60초 `ready`. 다른 조직 컬렉션 요청 42501. 컬렉션당 임베딩 모델 1종. 재현율@8 0.8 이상(049 평가셋, 제안). 문서 삭제 후 검색 0건 | 01장 NT-F-020, 031 |
| NT-06-038 | 과목·위키 백엔드: 과목 생성·이름 변경·삭제(index 페이지 + 컬렉션 규칙), 위키 저장(`expected_version`, 사람 소유 블록), 개념 slug 규칙, 점검(lint) 잡, 개인정보 유래 전파 | `apps/api/app/ai/products/notes/wiki_config.py`, `src/app/api/ai/wiki/`, `src/app/api/notes/subjects/` | 035, 036 | P0 | M | Opus | 과목 생성 = index 페이지 1개, 같은 개념 이름은 같은 slug, 사용자 소유 블록을 ingest가 수정하지 않음(제안 개정만), 오래된 `expected_version` 409, 문서 1건당 갱신 5페이지 상한, `contains_pii` 문서 유래 페이지는 오픈소스로만 처리, 과목 삭제 시 페이지·이력·링크·청크 0행, 모든 쓰기 감사 1행 | 01장 NT-F-022, 031, `LLM_WIKI.md:21-47` |
| NT-06-039 | LangGraph 그래프 `notes.organize`(upload → summary → link → quiz → compliance), 체크포인트, 실행 기록, 출력 스키마, 퀴즈 조회·채점 API | `apps/api/app/ai/graphs/notes_organize.py`, `apps/api/app/ai/compliance/notes.py`, `apps/api/app/ai/products/notes/quiz.py`, `src/app/api/ai/quizzes/`, `apps/api/tests/notes/graph/` | 035, 037, 038, 049 | P0 | L | Opus | 실행 1건 = `ai_runs` 1행 + 노드별 `ai_run_steps`. 요약 문단마다 출처 청크 1개 이상, 정답 없는 문항 0, 걸린 항목만 1회 재작성·요약 2회 실패 시 run `failed` + 환불, 사용자 소유 블록 수정 0, 문서당 갱신 5페이지, 체크포인트에서 이어서 재시도, 문제 조회 응답에 정답·해설 0, 평가셋(049)을 오픈소스·상용 두 경로로 통과 | 01장 NT-F-021, 023, 030 |
| NT-06-040 | Dify `notes-chat`(질문 분류, HTTP 노드)과 `/tools/answer` notes 모드(과목 범위, RAG + 위키 검색, 근거 없음 처리, compliance 후처리), 채팅 평가셋 | `infra/dify/`, `apps/api/app/ai/tools/notes/`, `apps/api/tests/notes/chat/` | 036, 037, 038 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직의 `subject_id` 403, 답변 출처 1개 이상 또는 `no_source`, 근거 없을 때 "노트 밖 일반 설명" 구분, 평가셋 금지 문구 0·위기 신호 5문장 안내, DSL에 키 0 | 01장 NT-F-024, 030, 04장 6.2절 |
| NT-06-041 | 채팅 패널과 대화 목록(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 과목 범위) | `src/components/ai-chat/`, `src/app/(app)/app/chat/` | 034, 036 | P0 | M | Sonnet | 03장 3.6절 구성, 375px 전체 화면 시트, `aria-live`, 402 안내, 대체·근거 없음·환불 상태 표시. `/app` 레이아웃 장착은 NT-06-017 파일에 1줄 요청 | 01장 NT-F-024, 03장 5절 |
| NT-06-042 | 위키 화면: 과목 목록·과목 홈·페이지 보기·편집·이력·백링크·제안 개정·점검 결과 | `src/components/wiki/`, `src/app/(app)/app/subjects/**` | 034, 038 | P0 | M | Sonnet | 03장 2.10·3.6절 구성. 사람이 고친 블록 표시와 에이전트 제안 적용/무시, 409 충돌 안내 UI, 출처 칩과 "AI가 정리한 문서" 표시, 키보드로 편집·저장 가능 | 01장 NT-F-022 |
| NT-06-043 | 노트·교재 화면(업로드, 상태, 한도), 정리 시작·진행 화면, 노트 상세(요약, 개념 칩, 퀴즈 카드), 퀴즈 풀이 화면(텍스트) | `src/components/notes/`, `src/components/quiz/`, `src/app/(app)/app/notes/**`, `src/app/(app)/app/quiz/**` | 034, 036, 037 | P0 | M | Sonnet | 03장 2.5·2.9·3.7절. 권한 확인 체크 없이는 올리기 버튼 비활성, 한도 표시, 진행 5단계 표시와 취소, 일부 제외 알림, 서버 채점 결과만 표시(클라이언트에 정답 없음), 키보드로 끝까지 풀이 | 01장 NT-F-020, 021, 023 |
| NT-06-044 | 음성 대화: `/api/voice/*`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기. TTS는 `message_id`와 `quiz_run_id` 두 출처 지원 | `src/app/api/voice/`(`lectures/` 제외), `src/components/voice/` | 036, 041 | P0 | M | Opus | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지·퀴즈에서만 | 01장 NT-F-025 |
| NT-06-045 | 강의 녹음 → 노트 생성 API(핵심): 시작(고지 감사, 세션), 조각 STT(`lecture_note`, 상용 대체 금지), 선차감·정산, 전사 조각 저장·병합, 재개 조회, 원본 보관(동의 3필드) | `src/app/api/voice/lectures/`, `src/server/lecture/` | 037, 044 | P0 | L | Opus | 고지 없이 조각 업로드 403, 허용 시간 초과 413, `lecture_note`의 `ai_usage` 상용 제공자 0(동의 후에도), 같은 `seq` 재전송 멱등, 조각 하나 실패해도 나머지 보존·그 조각 환불, 정산 후 차액 환불, 보관 시 `consent_at`·`consent_kind='third_party_notice'`·`notice_version`·`expires_at` 모두 기록(없으면 DB 23514), 미보관 `store_audio=false` 100%, 병합 전사본이 `seq` 순서 | 01장 NT-F-026 |
| NT-06-046 | 퀴즈 음성: 문제 읽어 주기·말로 답하기 UI, 음성 답 확인·제출, 퀴즈 세션(`POST /api/ai/quizzes/sessions`, NT-06-039 소유) 연결 | `src/components/quiz-voice/` | 039, 043, 044 | P0 | M | Opus | 읽어 주는 텍스트는 서버 퀴즈에서만(임의 텍스트 403), 음성 답 `store_audio=false` 100%, 세션 선차감 후 채점·STT·TTS에서 소진, 마이크 거부 시 텍스트로 끝까지 풀이, 실패 환불 | 01장 NT-F-027 |
| NT-06-047 | 3D 히어로: 흩어진 메모 카드 → 노트(PC·태블릿), 카드 5장(모바일), 정지 이미지 대체, 성능 예산 | `src/components/hero3d/`, `public/hero/` | 020, 034 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 파스텔 스티커·손글씨·별 파티클 0 | 01장 NT-F-029, 03장 4.6절 |
| NT-06-048 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 강제 오픈소스, 선차감·정산·환불, 퀴즈 정답 노출, 라우팅 seed 스냅샷) | `apps/api/tests/notes/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | 036, 039, 040, 044, 045, 046 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 13행 × 동의 유/무)이 02장 5.3절·05장 9.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, `lecture_note` 상용 호출 0, 퀴즈 조회 응답 정답 0, 원장 drift 0, 서명 개인키·제공자 키가 번들에 0, CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 16장 |
| NT-06-049 | AI 평가셋: 가상 수업 노트·교재 샘플(직접 작성), 검색 질의 40문항, 요약 충실도·퀴즈 근거·금지 문구·위기 신호 평가, 오픈소스·상용 격차 리포트 | `apps/api/tests/notes/eval/`, `content/eval-notes/` | 035 | P0 | M | Opus | 샘플 20건(실제 저작물 아님, 출처 표기), 질의 40문항에 정답 청크 표시, 요약 "원문에 없는 문장 0" 판정 규칙과 퀴즈 "정답이 근거 청크에 있음" 판정 규칙, 두 경로 결과를 같은 형식으로 출력해 D-11 판단 근거로 사용 | 01장 NT-F-021, 030, D-11 |
| NT-06-050 | AI 정산·정리 크론: `/api/internal/ai-settle` 5분 호출, 만료 녹음 삭제(`expire_voice_audio` → Storage API), 강의 전사 조각 24시간 정리 | `apps/study-note-worker/src/cron-ai/**` | 036 | P0 | S | Opus | 10분 넘은 `settled_at is null` 0, 만료 녹음 파일 24시간 안에 삭제, 전사 조각 파일 정리, 호출 실패 시 재시도와 알림, 실행 로그에 본문 0 | 01장 NT-F-028, 031 |
| NT-06-051 | 강의 녹음 화면: 고지 모달, 녹음기(조각 자동 업로드, 일시정지, 재개, 남은 시간, 네트워크 끊김 보류·재전송), 전사 확인·수정, 노트로 정리 | `src/components/lecture/`, `src/app/(app)/app/lecture/**` | 034, 045 | P0 | M | Opus | 03장 2.6·3.8절. 고지 확인 전 녹음 시작 불가, 녹음 중 표시등 + 텍스트, 허용 시간 30초 전 경고·자동 종료, 조각 실패 시 해당 조각만 재시도, 페이지 이탈 확인, 마이크 거부 시 텍스트 붙여넣기 경로, 로컬 임시 보관은 try/catch(막혀도 동작) | 01장 NT-F-026 |
| NT-06-052 | AI 고지문: 국외 이전, 음성 처리, 강의 녹음(제3자), 업로드 권한 고지 문구와 버전 상수, 고지 모달 컴포넌트 | `src/components/ai-notice/**`, `src/lib/notices/ai-notices.ts` | 021, 034 | P0 | S | Sonnet | 고지문 4종 한국어 초안과 버전 상수(env `AI_CROSS_BORDER_NOTICE_VERSION` 등과 일치), 법무 확인 표시, 모달 접근성(Esc, 포커스 트랩), 01장 6.1절 금지 문구 검사 통과. 약관·방침 본문의 AI 조항은 NT-06-021 파일에 요청 1건으로 반영 | 01장 6장, 6.2절 |

AI·음성 P0 작업과 대응 테스트(2026-10-13): 035 → 048, 036 → 048, 037 → 049 평가셋·048, 038 → 048, 039 → 049·048, 040 → 049·048, 044·045·046 → 048, 041~043·051 → 024·030 E2E. 디자인 시스템 031~034는 `/dev/components` 스크린샷과 문서·토큰 일치 스크립트로 확인한다.

P0 작업과 대응 테스트: 001(CI 자체 검사), 002 → 003, 005 → 003·024, 006 → 024, 007 → 008, 009·010 → 011, 012·013 → 024·003, 014 → 024, 015 → 024, 016~018·020·021 → 024·030. RLS/권한 회귀 테스트는 003, 결제 E2E는 027.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 022, 031 | 4 | 없음 | 저장소 위생, DB 적용과 타입(AI 기본값 포함), CI 뼈대, 디자인 레퍼런스(1단계) |
| W1 | 003, 004, 005, 007, 035 | 5 | W0 | RLS 회귀 테스트, 변환 스크립트, 플랫폼 연결, pipeline 로직, AI 서비스 설치 |
| W1-D | 032 → 033 → 034(직렬) | 1 | 005, 031 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 006, 008, 009, 013, 015, 016, 020, 021, 036, 049 | 10 | W1, 화면은 034 | 인증 화면, 단위 테스트, LLM 어댑터, 부가 API, 클라이언트 상태, 이식 컴포넌트, 랜딩, 법무, AI 게이트, AI 평가셋 |
| W3 | 010, 012, 014, 017, 018, 019, 037, 038, 041, 050, 052 | 11 | W2 | 워커, 실행 API, 비용 보호, 작업실·설정·보관함 화면, RAG 색인, 과목·위키 백엔드, 채팅 패널, 정산 크론, AI 고지문 |
| W4 | 011, 024, 025, 030, 039, 040, 042, 043, 044, 047 | 10 | W3 | 통합/E2E 테스트, 스케줄, 디자인 점검, 노트 정리 그래프, Dify 채팅, 위키 화면, 노트·퀴즈 화면, 음성 대화, 3D 히어로 |
| W5 | 045, 046 | 2 | W4 | 강의 녹음 API(핵심), 퀴즈 음성 |
| W6 | 048, 051 | 2 | W5 | AI 보안 회귀, 강의 녹음 화면. **공개 베타 출시 조건** |
| W7 | 023, 026, 027, 028, 029 | 5 | W6 | 문서, 결제(Phase 2), 관리자, 운영 리포트 |

공개 베타 출시 조건은 W6 완료(P0 전부, 3D 히어로 047은 P1이라 제외 가능). W7의 결제는 베타 이후다.

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 6 (002, 003, 026, 035, 036, 048) | 11.8% | 13/94 = 13.8% |
| Opus | 26 (005, 007~015, 024, 025, 027~029, 034, 037~040, 044~046, 049~051) | 51.0% | 50/94 = 53.2% |
| Sonnet | 15 (006, 016~021, 023, 031, 032, 041~043, 047, 052) | 29.4% | 27/94 = 28.7% |
| Haiku | 4 (001, 004, 022, 030) | 7.8% | 4/94 = 4.3% |
| 합계 | 51 | 100% | 94 |

비율은 모델 작업 51개 기준이다. 사람 작업 1개(NT-06-033, M)는 비율에서 뺐다(전체 작업 52개). 2026-10-13 이전(30개)은 Fable 10.0%, Opus 50.0%, Sonnet 26.7%, Haiku 13.3%였다.

원본 리뷰 비율(Fable 7%, Opus 29%, Sonnet 64%, `docs/reference/reviews/study-note-organizer-codex-01.md:120`)과 달라진 이유: 서버 전환(워커, 과금, API)과 AI 계층(그래프, 서명 토큰, 정산)이 추가되어 Opus·Fable 몫이 커졌다. 리뷰가 Sonnet으로 둔 `.gitignore`(#1)와 ESLint(#13)는 템플릿 기준(보일러플레이트/린트 정리 = Haiku)에 따라 Haiku로 낮췄다. AI 보안 경계(서명 토큰 검증 035, AI 게이트의 선차감·정산·동의 036, AI 회귀 048)는 Fable, 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅·위키·노트 화면과 3D 히어로, 고지문은 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

리뷰 5장 14개 작업 → 흡수 작업. 중간/낮음 결함 #4~#14도 같은 표에서 위치를 확인한다.

| 리뷰 5장 # | 작업(우선순위) | 흡수한 작업 ID |
|---|---|---|
| 1 | `.gitignore`, 중첩 `.git` 방침 | NT-06-001 (+ 07장 5절 아카이브) |
| 2 | `VITE_OPENROUTER_API_KEY` 폴백 제거, README env 안내 삭제, 키 삭제 버튼 | NT-06-001, 005, 009, 023 (키 입력란과 삭제 버튼 자체가 없어짐) |
| 3 | 동시 실행 방지(disabled, 가드, runId, AbortController) | NT-06-002, 010, 012, 015, 017 |
| 4 | SettingsPanel draft 재설정 | NT-06-018 |
| 5 | `todayIso` 로컬 날짜 | NT-06-007 |
| 6 | localStorage try/catch, 용량 초과 처리, draft 디바운스 | NT-06-015 (히스토리는 DB로 이전되어 용량 문제 제거: 025, 05장 보존 함수) |
| 7 | `latest` 고정, `@vitejs/plugin-react` 위치 | NT-06-001 (Next 전환으로 후자는 해당 없음) |
| 8 | README 교체와 사본 삭제 | NT-06-023 |
| 9 | retryBase/retryFinal 최신 상태, 통합 생략 사유 | NT-06-010, 012, 015 (서버가 부모 실행 결과를 읽음) |
| 10 | 미사용 `useLocalStorage`, `RESET_RESULTS` 삭제 | NT-06-016 (이식 제외) |
| 11 | PRD 미구현 UI(optgroup, 툴팁, 배너, lg 레이아웃) | NT-06-017, 018 |
| 12 | Vitest 단위 테스트 | NT-06-008 |
| 13 | ESLint | NT-06-022 |
| 14 | (공개 배포) 서버 프록시와 사용량 제한 | NT-06-009, 010, 012, 014 (MVP 필수로 승격: 가입 개방) |

행 수 14 = 리뷰 5장 작업 수 14.

## 6. 공용 모듈 요청

코어 변경은 제품이 하지 않는다. `_platform-core`에 아래를 요청한다.

| ID | 요청 | 이유 | 긴급도 |
|---|---|---|---|
| C-1 | 모듈러 코어 `core` 스키마의 함수 PUBLIC EXECUTE 회수. `alter default privileges in schema core revoke execute on functions from public`은 PUBLIC 기본 권한에 효과가 없어 `enqueue_job`, `claim_jobs`, `complete_job`, `fail_job`, `heartbeat_job`, `confirm_payment_order`, `apply_subscription_transition`, `run_monthly_credit_grants`, `purge_organization`, `create_oauth_state` 등이 authenticated/anon에 열려 있다. 이 함수들은 내부 검사를 `is_privileged_session()`에 의존하는데 DEFINER 안에서 항상 true라서 EXECUTE가 유일한 잠금이다(`SECURITY_BASELINE.md:17-25`). 모놀리스는 SECTION 10이 막는다. 확인 방법: 이 문서 작성 중 PGlite에서 `has_function_privilege('authenticated', oid, 'execute')`로 열거함 | 사용자가 결제 확인, 잡 탈취, 월 지급 호출을 시도할 수 있다 | 해결(2026-10-13 `0007_core_function_privileges.sql`로 코어 반영 완료) |
| C-2 | LLM 게이트웨이에 (a) 호출자가 지정하는 명시 모델(화이트리스트 검증), (b) 크레딧이 이미 선차감된 호출을 위한 `prepaid` 옵션(`ai_usage`만 기록) | 제품이 단계별 선택 모델과 일괄 선차감을 쓴다 | 중간 |
| C-3 | 계정(조직) 삭제 요청 RPC 또는 문서화된 service_role 절차 | 30일 유예 삭제 UX 구현에 필요 | 중간 |
| C-4 | 모듈러 `seed.sql`의 notes 행 병합: Free `features`, `pro` 플랜, 크레딧팩 2종(비활성) | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치. 조각의 보충은 안전망으로 유지 | 완료 |
| C-5 | `confirm_payment_order` 금액 불일치 시 `failed` 주문이 롤백되는 알려진 결함 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 별도 호출(지급 없음 + 알림) | 완료 |
| C-6 | `_supabase-modular/seed.sql` | notes free/pro `features`에 AI 키(`ai_chat`, `ai_chat_turns_per_day`, `ai_subjects_max`, `ai_docs_max`, `ai_doc_max_chars`, `lecture_note`, `lecture_max_minutes`, `voice_chat`, `quiz_voice`) 추가 | seed가 `2100_notes.sql`보다 나중에 실행되면 14.2절 병합 UPDATE가 덮어써진다 | 서버가 누락 키를 기본값으로 읽는다(01장 4.2절) |
| C-7 | 공용 ai-service | (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 사람 편집 저장 엔드포인트(`AI_ARCHITECTURE.md` 8장 목록에 없음) (c) 제품 확장 엔드포인트 설치 위치 `app/ai/products/notes/`(문서 삭제, 과목 purge, 단답 채점) (d) 잡 소비자 표준(큐 `<app>.ai`) | Dify 보조 노드 라우팅(`dify.aux`)과 사용자 위키 편집, 삭제·채점 | (a) Dify에 기능별 모델 이름을 따로 등록 (b)(c)(d) notes 확장에 임시 구현(NT-06-035, 038, 039) |
| C-8 | core-voice, `core.voice_jobs` | (a) 기능별 강제 오픈소스일 때 상용 대체 금지 동작과 조각(청크) STT 호출 계약을 `VoiceAdapter`에 명시 (b) 필요해지면 `voice_jobs`에 조각 순번 열 | 강의 녹음 조각 STT가 `lecture_note`(강제 오픈소스)로 나뉘어 들어온다(05장 6절) | (a) 라우팅이 이미 상용을 걸러 낸다. (b) 순번은 Storage 경로에 둔다 |
| C-9 | `_design-guide` 3D 키트 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/file/03-설계/디자인/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `hero3d/` 안에 같은 인터페이스로 두고 키트가 생기면 옮긴다 |
| C-10 | 공용 Dify, `purge_organization` | (a) 공용 Dify에 `notes-chat` 앱 생성, 내부 키 환경 변수, 로그 보존 30일, 대화 삭제 API 확인 (b) 계정 삭제 시 AI 표 연쇄 + Storage(`org-files`, `voice-audio`) + Dify 대화 정리 절차 | 공용 인프라는 코어 소유. 삭제 권리(01장 NT-F-031) | (a) 장애 시 `/tools/answer-direct`. (b) 06장 C-3과 함께 service_role 절차로 문서화 |

## 7. 완료 정의

| 조건 | 기준 |
|---|---|
| 빌드/타입/린트 | `next build`, `tsc --noEmit`, ESLint 오류 0 (NT-06-022) |
| SQL | 체커 OK(모놀리스/모듈러), 모놀리스 변환 동기화(NT-06-004) |
| RLS | NT-06-003 전부 통과 (코어 C-1 해결 후 알려진 결함 항목도 통과로 전환) |
| 동시 실행 | NT-06-011, 024의 연타/동시 시나리오 통과 |
| 비밀 | 번들과 저장소에 키 없음(NT-06-001 CI) |
| 결제(Phase 2) | NT-06-027 통과 후에만 `pro`와 팩 `is_active=true` |
| 디자인 | NT-06-030 12개 항목 통과 |
| AI·음성 | `pytest apps/api` 통과, NT-06-048 녹색, 평가셋(049)을 오픈소스·상용 두 경로로 통과, 채팅 평가셋 금지 문구 0, 강의 STT 상용 호출 0 확인 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준(NT-06-047, P1), 디자인 시스템 4단계(NT-06-034) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | P0 전부 완료(W0~W6) = 공개 베타. 52개 전부 완료 = Phase 2 완료 |
