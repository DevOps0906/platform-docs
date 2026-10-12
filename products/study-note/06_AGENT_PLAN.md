# 06 에이전트 작업 계획: Study Note

작성일 2026-10-12. 작업 ID는 `NT-06-###`(약어 NT는 SQLSTATE 접두사와 같음, `DB_CONVENTIONS.md:22`). 리뷰 = `docs/reviews/study-note-organizer-codex-01.md`.

## 1. 원칙과 소유 경계

병렬 에이전트는 디렉토리 단위로만 쓴다. 두 작업이 같은 경로를 소유하지 않는다. 공유 파일(루트 설정, `packages/*`)은 건드리지 않는다.

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
| 랜딩 | `src/app/(marketing)/**`, `src/components/marketing/**`, `src/styles/tokens.css` | 020 |
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
| NT-06-016 | 원본 컴포넌트 이식(Vite → Next): Header, ResultCard, ErrorDisplay, LoadingSpinner. 데드 코드 제외 | `src/components/common/**` | 001 | P0 | M | Sonnet | 이식한 컴포넌트에 `useLocalStorage`, `RESET_RESULTS`가 없다. 스토리/스냅샷 렌더 통과 | 리뷰 5장 #10 |
| NT-06-017 | 작업실 화면: 입력부, 결과 3카드, 크레딧 표시, 취소, 무료 모델 배너, 반응형 | `src/components/workspace/**`, `src/app/(app)/app/page.tsx` | 015, 016 | P0 | M | Sonnet | 03장 3.1절 구성. 1024px 이상 2열+통합, 768px 2열, 미만 1열 | 리뷰 5장 #11, #3 |
| NT-06-018 | 설정 화면: 등급 optgroup, 무료 모델 툴팁, 열 때 draft 재초기화, 테마, 데이터 메뉴 | `src/components/settings/**`, `src/app/(app)/app/settings/**` | 013, 016 | P0 | M | Sonnet | 테마를 바꾼 뒤 모델 저장해도 테마가 유지. 취소한 편집이 다음에 열릴 때 남지 않는다 | 리뷰 5장 #4, #11 |
| NT-06-019 | 보관함 화면: 목록, 날짜/키워드 검색, 상세 복원, 휴지통 | `src/components/history/**`, `src/app/(app)/app/history/**` | 015, 016 | P1 | M | Sonnet | 다른 브라우저에서도 같은 목록. 휴지통 복원/영구 삭제 동작 | 01장 NT-F-008 |
| NT-06-020 | 랜딩: 03장 4절 토큰/와이어프레임, 형광펜 연출 1회 | `src/app/(marketing)/**`, `src/components/marketing/**`, `src/styles/tokens.css` | 001 | P0 | M | Sonnet | 설계 체크리스트 7단계 통과(NT-06-030). 가상 후기/미검증 수치 0건 | 01장 6.1, 03장 4절 |
| NT-06-021 | 약관/개인정보처리방침 페이지, 첫 실행 동의 모달 | `src/app/(legal)/**`, `src/components/consent/**` | 001 | P0 | S | Sonnet | 동의 없이 실행 불가, 동의가 감사 로그에 남는다. 문구 초안은 법무 확인 표시 | 01장 6장 |
| NT-06-022 | ESLint(typescript-eslint, react-hooks), tsconfig strict, CI(lint, tsc, build, vitest, SQL 체커) | `.github/workflows/study-note-ci.yml`, `eslint.config.*` | 없음 | P1 | S | Haiku | CI가 5단계를 실행하고 `latest` 의존성/`any` Supabase 캐스팅을 거부 | 리뷰 5장 #13 |
| NT-06-023 | 앱 README(설치/실행/빌드/env 변수 이름/보안 주의), 원본 README 사본 폐기 확인 | `apps/study-note/README.md` | 005 | P1 | S | Sonnet | env 키 값 사용 안내가 없다. 신규 개발자가 문서만으로 로컬 기동 | 리뷰 5장 #8 |
| NT-06-024 | E2E(Playwright): 가입 → 인증 → 실행 → TXT 다운로드, 연타 방지(버튼 3종), 크레딧 부족, 재요청 | `tests/e2e/**` | 006, 010, 012, 017, 018 | P0 | M | Opus | 연타해도 run 1개, 차감 1회. 다운로드 파일명 규칙 일치 | 리뷰 #3, 01장 NT-F-003~006 |
| NT-06-025 | 스케줄: `purge_deleted` 일 1회, 보존 정책 호출, 코어 스케줄 확인 | `apps/study-note-worker/src/cron/**` | 010 | P1 | S | Opus | 30일 지난 휴지통 항목이 사라진다. 실행 로그에 삭제 건수 | 05장 |
| NT-06-026 | 결제(Phase 2): 주문 생성, confirm, 웹훅, Pro/크레딧팩 UI, `is_active` 전환 절차 | `src/app/api/billing/**`, `src/app/api/webhooks/**`, `src/app/(app)/app/billing/**` | 002, 005 | P1 | L | Fable | 금액 불일치는 지급 없음. 같은 `paymentKey` 재호출 멱등. 웹훅 서명 실패 401. `failed` 주문 저장에 의존하지 않는다 | 확정 결정 4, 코어 결함 |
| NT-06-027 | 결제 E2E(Toss 테스트 키): 성공, 취소, 금액 위조, 중복 confirm | `tests/e2e/billing/**` | 026 | P1 | M | Opus | 4 시나리오 통과, 잔액/원장 일치 | `DOC_TEMPLATE.md` 필수 |
| NT-06-028 | 모델 카탈로그 관리 화면과 동기화 잡 | `src/app/(admin)/admin/models/**`, `apps/study-note-worker/src/handlers/sync*` | 010, 013 | P1 | M | Opus | platform_admin만 접근(일반 사용자 403). 비활성 처리 후 설정 화면에서 사라진다 | 리뷰 5장 #14, 분석 공백 3 |
| NT-06-029 | 운영 리포트: 모델별 크레딧당 원가, 환불률, 상한 도달 일수. 단가 보정안 | `apps/study-note-worker/src/reports/**` | 010 | P1 | S | Opus | 주간 리포트가 01장 7절 지표를 출력 | 01장 4.3, 7장 |
| NT-06-030 | 디자인 출시 체크리스트 7단계 자동 점검(뷰포트 4종, 포커스, reduced-motion, 대비, 이모지 아이콘, 금지 문구 grep) | `tests/e2e/design/**` | 017, 018, 020 | P0 | S | Haiku | 12개 항목 통과 리포트 | `DESIGN_PRINCIPLES.md` 7단계 |

P0 작업과 대응 테스트: 001(CI 자체 검사), 002 → 003, 005 → 003·024, 006 → 024, 007 → 008, 009·010 → 011, 012·013 → 024·003, 014 → 024, 015 → 024, 016~018·020·021 → 024·030. RLS/권한 회귀 테스트는 003, 결제 E2E는 027.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 022 | 3 | 없음 | 저장소 위생, DB 적용과 타입, CI 뼈대 |
| W1 | 003, 004, 005, 007 | 4 | W0 | RLS 회귀 테스트, 변환 스크립트, 플랫폼 연결, pipeline 로직 |
| W2 | 006, 008, 009, 013, 015, 016, 020, 021 | 8 | W1 | 인증 화면, 단위 테스트, LLM 어댑터, 부가 API, 클라이언트 상태, 이식 컴포넌트, 랜딩, 법무 |
| W3 | 010, 012, 014, 017, 018, 019 | 6 | W2 | 워커, 실행 API, 비용 보호, 작업실/설정/보관함 화면 |
| W4 | 011, 024, 025, 030 | 4 | W3 | 통합/E2E 테스트, 스케줄, 디자인 점검 |
| W5 | 023, 026, 027, 028, 029 | 5 | W4 | 문서, 결제(Phase 2), 관리자, 운영 리포트 |

공개 베타 출시 조건은 W4 완료(P0 전부). W5의 결제는 베타 이후다.

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 3 (002, 003, 026) | 10.0% | 6/52 = 11.5% |
| Opus | 15 (005, 007~015, 024, 025, 027~029) | 50.0% | 28/52 = 53.8% |
| Sonnet | 8 (006, 016~021, 023) | 26.7% | 14/52 = 26.9% |
| Haiku | 4 (001, 004, 022, 030) | 13.3% | 4/52 = 7.7% |
| 합계 | 30 | 100% | 52 |

원본 리뷰 비율(Fable 7%, Opus 29%, Sonnet 64%, `docs/reviews/study-note-organizer-codex-01.md:120`)과 달라진 이유: 서버 전환(워커, 과금, API)이 추가되어 Opus 몫이 커졌다. 리뷰가 Sonnet으로 둔 `.gitignore`(#1)와 ESLint(#13)는 템플릿 기준(보일러플레이트/린트 정리 = Haiku)에 따라 Haiku로 낮췄다.

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
| C-1 | 모듈러 코어 `core` 스키마의 함수 PUBLIC EXECUTE 회수. `alter default privileges in schema core revoke execute on functions from public`은 PUBLIC 기본 권한에 효과가 없어 `enqueue_job`, `claim_jobs`, `complete_job`, `fail_job`, `heartbeat_job`, `confirm_payment_order`, `apply_subscription_transition`, `run_monthly_credit_grants`, `purge_organization`, `create_oauth_state` 등이 authenticated/anon에 열려 있다. 이 함수들은 내부 검사를 `is_privileged_session()`에 의존하는데 DEFINER 안에서 항상 true라서 EXECUTE가 유일한 잠금이다(`SECURITY_BASELINE.md:17-25`). 모놀리스는 SECTION 10이 막는다. 확인 방법: 이 문서 작성 중 PGlite에서 `has_function_privilege('authenticated', oid, 'execute')`로 열거함 | 사용자가 결제 확인, 잡 탈취, 월 지급 호출을 시도할 수 있다 | 높음. 모듈러 출시 전 필수 |
| C-2 | LLM 게이트웨이에 (a) 호출자가 지정하는 명시 모델(화이트리스트 검증), (b) 크레딧이 이미 선차감된 호출을 위한 `prepaid` 옵션(`ai_usage`만 기록) | 제품이 단계별 선택 모델과 일괄 선차감을 쓴다 | 중간 |
| C-3 | 계정(조직) 삭제 요청 RPC 또는 문서화된 service_role 절차 | 30일 유예 삭제 UX 구현에 필요 | 중간 |
| C-4 | 모듈러 `seed.sql`의 notes 행 병합: Free `features`, `pro` 플랜, 크레딧팩 2종(비활성) | 지금은 제품 조각이 대신 넣고 있다 | 낮음 |
| C-5 | `confirm_payment_order` 금액 불일치 시 `failed` 주문이 롤백되는 알려진 결함 | 제품은 의존하지 않음(지급 없음 + 알림으로 처리) | 참고 |

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
| 작업 | P0 전부 완료 = 공개 베타. 30개 전부 완료 = Phase 2 완료 |
